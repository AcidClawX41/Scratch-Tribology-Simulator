## Base de los tests (ejecutor propio, sin dependencias): cada archivo tests/**/test_*.gd extiende este script
## (extends "res://tests/case.gd")
## y define métodos test_*. Casi todos son síncronos: el core no usa nodos. Un test que necesite fotogramas de verdad
## (la disposición real de la interfaz, la carga en hilos) es una corrutina: añade sus nodos al árbol con add_to_tree()
## y espera con `await wait_frames(n)` o `await wait_until(cond)`; el ejecutor lo espera y libera esos nodos al acabar.
## Lo que se ve (colores, píxeles) se verifica con capturas de Movie Maker (tools/godot.mjs capture).
##
## GDScript no tiene excepciones: un error de ejecución corta el método y escribe «SCRIPT ERROR». El
## envoltorio (tools/godot.mjs test) da el conjunto por fallido si aparece esa línea.
extends RefCounted

const _Js = preload("res://core/shared/js.gd")

var _failures: Array[String] = []
var _asserts := 0
var _where := ""
var _nodes: Array[Node] = []  # nodos de add_to_tree() que se liberan al acabar el test


func _begin(where: String) -> void:
	_where = where
	_failures = []
	_asserts = 0


## Lo llama el ejecutor al acabar cada test: saca del árbol y libera los nodos de add_to_tree().
func _end() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()


# ── Fotogramas (para los tests que son corrutinas) ──

## El árbol de escena del ejecutor.
static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Añade un nodo a la raíz del árbol (se procesa, se dispone y se dibuja en cada fotograma); se libera al acabar el test.
func add_to_tree(n: Node) -> Node:
	tree().root.add_child(n)
	_nodes.append(n)
	return n


## Espera n fotogramas del árbol: `await wait_frames(2)`.
func wait_frames(n := 1) -> void:
	for i in n:
		await tree().process_frame


## Espera, fotograma a fotograma, hasta que cond() sea verdadero o pasen max_frames: `if await wait_until(f): …`.
## Devuelve si se ha cumplido.
func wait_until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await tree().process_frame
	return bool(cond.call())


func fail(msg: String) -> void:
	_failures.append("%s: %s" % [_where, msg])


func assert_true(cond: bool, msg := "se esperaba verdadero") -> void:
	_asserts += 1
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg := "se esperaba falso") -> void:
	assert_true(not cond, msg)


func assert_eq(got: Variant, want: Variant, msg := "") -> void:
	_asserts += 1
	if not same(got, want):
		fail("%s — obtenido %s, esperado %s" % [msg, show(got), show(want)])


## Igualdad numérica con tolerancia relativa (y absoluta para valores cercanos a cero).
func assert_near(got: float, want: float, rel := 1e-9, abs_tol := 1e-12, msg := "") -> void:
	_asserts += 1
	if not near(got, want, rel, abs_tol):
		fail("%s — obtenido %s, esperado %s (error relativo %s)" % [msg, _Js.js_num_str(got), _Js.js_num_str(want), _Js.js_num_str(rel_err(got, want))])


## Diferencias entre un valor del port y el del oráculo, con la política del plan:
## textos y booleanos idénticos; números con error relativo ≤ rel; undefined del JS ⇔ clave ausente o null.
## Devuelve la lista de discrepancias (vacía si todo coincide).
func oracle_diff(got: Variant, want: Variant, path := "", rel := 1e-9, abs_tol := 1e-12) -> Array[String]:
	var out: Array[String] = []
	_diff(decode(got), decode(want), path, rel, abs_tol, out)
	return out


func _diff(got: Variant, want: Variant, path: String, rel: float, abs_tol: float, out: Array[String]) -> void:
	if out.size() > 20:
		return
	if want == null:
		if got != null:
			out.append("%s: obtenido %s, esperado null/ausente" % [path, show(got)])
		return
	if is_num(want):
		if not is_num(got) or not near(float(got), float(want), rel, abs_tol):
			out.append("%s: obtenido %s, esperado %s" % [path, show(got), show(want)])
		return
	if want is Dictionary:
		if not (got is Dictionary):
			out.append("%s: obtenido %s, esperado un diccionario" % [path, show(got)])
			return
		for k in want:
			_diff(got.get(k), want[k], "%s.%s" % [path, k], rel, abs_tol, out)
		for k in got:
			if not want.has(k) and got[k] != null:
				out.append("%s.%s: sobra (%s)" % [path, k, show(got[k])])
		return
	if want is Array:
		if not (got is Array) or got.size() != want.size():
			out.append("%s: obtenido %s, esperado %s" % [path, show(got), show(want)])
			return
		for i in want.size():
			_diff(got[i], want[i], "%s[%d]" % [path, i], rel, abs_tol, out)
		return
	if typeof(got) != typeof(want) or got != want:
		out.append("%s: obtenido %s, esperado %s" % [path, show(got), show(want)])


static func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func near(got: float, want: float, rel := 1e-9, abs_tol := 1e-12) -> bool:
	if is_nan(want):
		return is_nan(got)
	if is_inf(want):
		return got == want
	return absf(got - want) <= maxf(abs_tol, rel * absf(want))


static func rel_err(got: float, want: float) -> float:
	return absf(got - want) / maxf(absf(want), 1e-300)


static func same(a: Variant, b: Variant) -> bool:
	if is_num(a) and is_num(b):
		return float(a) == float(b) or (is_nan(float(a)) and is_nan(float(b)))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


static func show(v: Variant) -> String:
	var s := JSON.stringify(v) if (v is Dictionary or v is Array) else var_to_str(v)
	return s if s.length() <= 160 else s.substr(0, 157) + "…"


## El código de un script GDScript sin comentarios y con el contenido de los textos en blanco (se conservan las
## comillas y los saltos de línea): para que los tests que vigilan el código fuente no confundan un comentario o un
## mensaje con una llamada.
static func code_only(src: String) -> String:
	var out := PackedStringArray()
	var i := 0
	var n := src.length()
	var quote := ""  # comillas del texto abierto: ", ', """ o ''' ("" fuera de un texto)
	while i < n:
		var ch := src[i]
		if quote == "":
			if ch == "#":
				while i < n and src[i] != "\n":
					i += 1
				continue
			if ch == "\"" or ch == "'":
				quote = ch.repeat(3) if src.substr(i, 3) == ch.repeat(3) else ch
				out.append(quote)
				i += quote.length()
				continue
			out.append(ch)
			i += 1
			continue
		if ch == "\\" and i + 1 < n:
			out.append("  ")
			i += 2
			continue
		if src.substr(i, quote.length()) == quote:
			out.append(quote)
			i += quote.length()
			quote = ""
			continue
		out.append("\n" if ch == "\n" else " ")
		i += 1
	return "".join(out)


## Scripts .gd de una carpeta res:// y sus subcarpetas, ordenados.
static func gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(gd_files(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out


## Lee un JSON de tests/fixtures (o de otra ruta res://) y decodifica los números especiales del oráculo.
static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("no se puede leer %s (¿falta `npm run godot:fixtures`?)" % path)
		return null
	return decode(JSON.parse_string(text))


## { "$num": "NaN" | "Infinity" | "-Infinity" } y { "$f64": "<8 bytes little-endian en hex>" } → float exacto.
## El resto, tal cual (recursivo). Los decimales normales del JSON los lee Godot con un error de hasta ~1e-14
## relativo: bien para comparar con tolerancia, no para comparar al bit (para eso el oráculo usa $f64).
static func decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.size() == 1 and v.has("$f64"):
			return str(v["$f64"]).hex_decode().decode_double(0)
		if v.size() == 1 and v.has("$num"):
			match str(v["$num"]):
				"NaN":
					return NAN
				"Infinity":
					return INF
				"-Infinity":
					return -INF
		var out := {}
		for k in v:
			out[k] = decode(v[k])
		return out
	if v is Array:
		var arr := []
		for x in v:
			arr.append(decode(x))
		return arr
	return v
