## La física del laboratorio es segura para hilos (requisito de rendimiento multinúcleo): core/lab y core/shared no
## guardan estado mutable entre llamadas, así que Physics.compute() puede correr a la vez en varios hilos de
## WorkerThreadPool y da lo mismo, al bit, que en serie.
##   - Los únicos `static var` de core/lab y core/shared son constantes que se calculan una vez al cargar el script
##     (las de v8_math.gd, construidas desde sus bits): nadie los vuelve a escribir.
##   - Los 40 escenarios del golden, con los dos modelos, en paralelo (add_group_task) y en serie: resultados idénticos.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")

const DIRS := ["res://core/lab", "res://core/shared"]


func _params(p: Dictionary, model: String) -> Dictionary:
	var f := func(key: String, id: Variant) -> Variant: return null if id == null else Catalog.find_by_id(Catalog.list(key), id)
	return {
		"geom": f.call("GEOMS", p.geom), "base": f.call("BASES", p.base), "inlay": f.call("INLAYS", p.inlay),
		"claw": f.call("CLAWS", p.get("claw")), "target": f.call("TARGETS", p.target), "type": f.call("TYPES", p.type),
		"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike,
		"passes": p.passes, "wet": p.wet, "model": model,
	}


## ¿Idénticos al bit? (same() de case.gd, y además el signo de los ceros)
static func _identical(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _identical(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _identical(a[i], b[i]):
				return false
		return true
	if is_num(a) and is_num(b) and float(a) == 0.0 and float(b) == 0.0:
		return signf(1.0 / float(a)) == signf(1.0 / float(b))
	return same(a, b)


## Escrituras de cada `static var` del código fuera de su declaración: { nombre: veces } (name = …, name += …,
## name[i] = …, name.append(…)…).
static func _static_writes(code: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^static\\s+var\\s+(\\w+)")
	for m: RegExMatch in re.search_all(code):
		var name := m.get_string(1)
		var rest := RegEx.create_from_string("(?m)^static\\s+var\\s+%s\\b.*$" % name).sub(code, "")
		var writes := RegEx.create_from_string(
			"(?<![\\w.])%s\\s*(\\[[^\\]]*\\])?\\s*(([-+*/%%&|^]|<<|>>)?=(?!=)|\\.(append|push_back|insert|resize|fill|set|merge|erase|clear)\\()" % name)
		out[name] = writes.search_all(rest).size()
	return out


func test_sin_estado_estatico_mutable() -> void:
	# la vigilancia detecta las escrituras (un caso de prueba) …
	var probe := _static_writes(code_only("static var _a := 1\nstatic var _b: float = 2.0\nstatic var _c := {}\nfunc f() -> void:\n\t_a = 2\n\tif _b == 2.0:\n\t\t_c[1] = 3\n"))
	assert_eq(probe, { "_a": 1, "_b": 0, "_c": 1 }, "vigilancia de static var")
	# … y en core/lab y core/shared no hay ninguna
	var found := 0
	for dir: String in DIRS:
		for f in gd_files(dir):
			var writes := _static_writes(code_only(FileAccess.get_file_as_string(f)))
			for name: String in writes:
				found += 1
				assert_eq(writes[name], 0, "%s: el static var %s se escribe fuera de su declaración (estado compartido entre hilos)" % [f, name])
	assert_true(found > 0, "los de v8_math.gd")


func test_compute_en_paralelo_igual_que_en_serie() -> void:
	var golden: Array = load_json("res://tests/fixtures/lab-golden.json")
	var params: Array = []
	for model: String in Physics.MODELS:
		for g: Dictionary in golden:
			params.append(_params(g.params, model))
	var serial: Array = params.map(func(p: Dictionary) -> Dictionary: return Physics.compute(p))
	var parallel: Array = []
	parallel.resize(params.size())
	var lock := Mutex.new()
	var job := func(i: int) -> void:
		var r := Physics.compute(params[i])
		lock.lock()
		parallel[i] = r
		lock.unlock()
	for round_i in 3:  # varias rondas: el reparto entre hilos cambia de una a otra
		var t0 := Time.get_ticks_usec()
		var task := WorkerThreadPool.add_group_task(job, params.size(), -1, true, "compute() en paralelo")
		WorkerThreadPool.wait_for_group_task_completion(task)
		var bad := 0
		for i in params.size():
			if not _identical(parallel[i], serial[i]):
				bad += 1
				if bad <= 4:
					fail("escenario %d (%s): distinto en paralelo" % [i % golden.size(), params[i].model])
		assert_eq(bad, 0, "ronda %d: resultados en paralelo idénticos a los de la serie" % round_i)
		if round_i == 0:
			print("    (info) %d compute() en %d hilos: %s ms" % [params.size(), OS.get_processor_count(),
				_Js.to_fixed((Time.get_ticks_usec() - t0) / 1000.0, 1)])
		parallel.fill(null)
	assert_eq(params.size(), 80, "los 40 escenarios con los dos modelos")


func test_duelo_y_herramienta_en_paralelo() -> void:
	# el modo dual y resolve_tool también son puros (lo que calcula la interfaz en otros hilos, si hace falta)
	var cars: Array = Lab.DUEL_CARS
	var claws: Array = Catalog.CLAWS
	var serial: Array = []
	for c: Dictionary in claws:
		var p := { "geom": Catalog.GEOMS[0], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "force": c.force, "length": 25.0,
			"type": Catalog.TYPES[1], "passes": 1.0, "wet": false }
		serial.append([Lab.duel(p, c, [cars[0], cars[1]]), Physics.resolve_tool({ "geom": p.geom, "base": p.base, "inlay": p.inlay, "claw": c })])
	var parallel: Array = []
	parallel.resize(claws.size())
	var lock := Mutex.new()
	var job := func(i: int) -> void:
		var c: Dictionary = claws[i]
		var p := { "geom": Catalog.GEOMS[0], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "force": c.force, "length": 25.0,
			"type": Catalog.TYPES[1], "passes": 1.0, "wet": false }
		var r := [Lab.duel(p, c, [cars[0], cars[1]]), Physics.resolve_tool({ "geom": p.geom, "base": p.base, "inlay": p.inlay, "claw": c })]
		lock.lock()
		parallel[i] = r
		lock.unlock()
	var task := WorkerThreadPool.add_group_task(job, claws.size(), -1, true, "duelos en paralelo")
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in claws.size():
		assert_true(_identical(parallel[i], serial[i]), "%s: duelo y herramienta iguales en paralelo" % claws[i].id)
