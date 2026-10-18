## Determinismo entre plataformas: la física del laboratorio y la capa compartida usan las funciones de Math de V8
## (core/shared/v8_math.gd), no las de la libm de cada plataforma, que difieren en el último bit.
##   - exp, log, sin, cos, tan y pow dan lo mismo que Node, al bit, en los valores que usa la física (y en otros):
##     vectores de tests/fixtures/js-semantics.json (export-fixtures.mjs).
##   - core/lab/*.gd y core/shared/{contact,abrasion,format}.gd no llaman a ninguna función de la libm ni a las del
##     motor que hacen cuentas en C++ (lerp, ease…): solo a las exactas (sqrt, floor, min, max, abs…).
extends "res://tests/case.gd"

const V8 = preload("res://core/shared/v8_math.gd")

## Archivos de la física que no pueden usar la libm.
const PHYSICS_FILES := ["res://core/shared/contact.gd", "res://core/shared/abrasion.gd", "res://core/shared/format.gd"]
const PHYSICS_DIRS := ["res://core/lab"]
## Funciones globales de GDScript que dependen de la libm o que el motor calcula en C++ (y el compilador puede fundir
## en una FMA en ARM): prohibidas en la física. sqrt, floor, round, min, max, abs y clamp son exactas y se permiten.
const FORBIDDEN := [
	"pow", "exp", "log", "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
	"lerp", "lerpf", "inverse_lerp", "remap", "ease", "smoothstep", "lerp_angle", "cubic_interpolate", "bezier_interpolate",
	"snapped", "snappedf", "db_to_linear", "linear_to_db",
]

var sem: Dictionary


func before_each() -> void:
	if sem.is_empty():
		sem = load_json("res://tests/fixtures/js-semantics.json")


## ¿El mismo double, bit a bit? (los NaN valen todos lo mismo)
static func _same_bits(a: float, b: float) -> bool:
	if is_nan(a) or is_nan(b):
		return is_nan(a) and is_nan(b)
	var x := PackedByteArray()
	x.resize(16)
	x.encode_double(0, a)
	x.encode_double(8, b)
	return x.decode_s64(0) == x.decode_s64(8)


func _check(name: String, rows: Array, fn: Callable, libm: Callable) -> void:
	var bad := 0
	var libm_off := 0
	for row: Array in rows:
		var args := row.slice(0, row.size() - 1)
		var want: float = row[-1]
		var got: float = fn.callv(args)
		if not _same_bits(got, want):
			bad += 1
			if bad <= 6:
				fail("%s(%s) = %s y V8 da %s" % [name, ", ".join(args.map(func(v: float) -> String: return _Js.js_num_str(v))),
					_Js.js_num_str(got), _Js.js_num_str(want)])
		if not _same_bits(libm.callv(args), want):
			libm_off += 1
	assert_true(rows.size() > 100, "%s: vectores (%d)" % [name, rows.size()])
	assert_eq(bad, 0, "%s: valores distintos de los de V8" % name)
	print("    (info) %s: %d valores iguales a V8 al bit (la libm de esta plataforma difiere en %d)" % [name, rows.size(), libm_off])


func test_exp_de_v8_al_bit() -> void:
	_check("exp", sem.exp, V8.js_exp, func(x: float) -> float: return exp(x))


func test_log_de_v8_al_bit() -> void:
	_check("log", sem.log, V8.js_log, func(x: float) -> float: return log(x))


func test_pow_de_la_fisica_al_bit() -> void:
	_check("pow", sem.powPhysics, V8.js_pow, func(x: float, y: float) -> float: return pow(x, y))


func test_sin_cos_tan_de_la_punta_al_bit() -> void:
	var rows: Array = sem.trig
	var sins: Array = rows.map(func(r: Array) -> Array: return [r[0], r[1]])
	var coss: Array = rows.map(func(r: Array) -> Array: return [r[0], r[2]])
	var tans: Array = rows.map(func(r: Array) -> Array: return [r[0], r[3]])
	_check("sin", sins, V8.js_sin, func(x: float) -> float: return sin(x))
	_check("cos", coss, V8.js_cos, func(x: float) -> float: return cos(x))
	_check("tan", tans, V8.js_tan, func(x: float) -> float: return tan(x))


## Llamadas a funciones prohibidas en un código sin comentarios ni textos: [nombre, línea]. Las funciones que el propio
## script define (Contact.smoothstep) no cuentan: se llaman igual, pero son GDScript.
static func libm_calls(code: String) -> Array:
	var own := {}
	for m: RegExMatch in RegEx.create_from_string("(?m)^static\\s+func\\s+(\\w+)").search_all(code):
		own[m.get_string(1)] = true
	var re := RegEx.create_from_string("(?<![\\w.])(%s)\\s*\\(" % "|".join(FORBIDDEN))
	var out: Array = []
	for m: RegExMatch in re.search_all(code):
		var name := m.get_string(1)
		if own.has(name):
			continue
		out.append([name, code.substr(0, m.get_start()).count("\n") + 1])
	return out


func test_la_fisica_no_usa_la_libm() -> void:
	# la vigilancia detecta las llamadas (un caso de prueba) …
	var probe := libm_calls(code_only("static func smoothstep(a: float) -> float:\n\treturn a\n# pow(2, 3) en un comentario\nfunc f(x: float) -> float:\n\tvar s := \"exp(1)\"\n\treturn pow(x, 0.4) + V8.js_pow(x, 2.0) + smoothstep(x) + Math.tan(x) + exp (x)\n"))
	assert_eq(probe, [["pow", 6], ["exp", 6]], "vigilancia de la libm: %s" % [probe])
	# … y en la física no hay ninguna
	var files: Array[String] = []
	for dir: String in PHYSICS_DIRS:
		files.append_array(gd_files(dir))
	for f: String in PHYSICS_FILES:
		files.append(f)
	assert_true(files.size() >= 10, "archivos de la física: %d" % files.size())
	for f in files:
		for hit: Array in libm_calls(code_only(FileAccess.get_file_as_string(f))):
			fail("%s:%d llama a %s() de la libm: usa la de V8 (core/shared/v8_math.gd), que da lo mismo en todas las plataformas" % [f, hit[1], hit[0]])
	assert_true(true)
