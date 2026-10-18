## Física con versión (core/lab/physics.gd → model_of): "2.0" por defecto, "1.x" para el oráculo.
## Hasta los materiales de la 2.0 (unidad 4a), el modelo 2.0 daba EXACTAMENTE lo mismo que el 1.x con las herramientas
## de la 1.x. Con ellos este test se acota, como estaba previsto: en los 40 escenarios del golden, en toda la muestra del
## oráculo y en el modo dual, un ensayo solo puede cambiar si actúa algún mecanismo de la 2.0 (la uña que cede, la
## recuperación, las grietas de Hertz, el astillado, la abolladura o el mellado; docs/fisica/pulido-materiales.md §7.3;
## y, desde la biología de la unidad 4b, la punción por capas, el hueso, el esmalte de los colmillos y el ángulo de
## ataque; docs/fisica/pulido-biologia.md §9), y solo en las claves que ese mecanismo deja cambiar; el resto, al bit. Los
## campos nuevos existen en los dos modelos (a null en la 1.x), las herramientas resueltas no cambian y, en el golden, los
## escenarios que cambian de veredicto o de profundidad son exactamente los de las guías (materiales §7.8, biología §9.4).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")

const SAMPLE := "res://tests/fixtures/generated/lab-sample.json"
const V1 := Physics.MODEL_V1
const V2 := Physics.MODEL_V2
const MAX_REPORTED := 6
## Claves de la 1.x que puede cambiar cada mecanismo de la 2.0 (además de los campos nuevos, que solo tienen valor en la
## 2.0). Con la uña cedida el ensayo se repite con otra fuerza, así que puede cambiar cualquier clave.
const VERDICT_KEYS := ["verdict", "vcol", "vsub", "cede"]
const CLASS_KEYS := ["verdict", "vcol", "vsub", "cede", "scratched", "layer", "sev", "absMode", "fab", "muPlough", "muEff", "Ffric", "wearIdx"]
## Biología de la 2.0 (unidad 4b; docs/fisica/pulido-biologia.md §9): al punzar la piel, la grieta en todas las capas, el
## roce en los flancos y el hueso cambian la profundidad y todo lo que sale de ella; al rayar, solo el hueso (el corte se
## para en él). En la 2.0 la punción de la piel da además su trabajo (workJ) y si el colmillo se rompe (toolBroken).
const SKIN_KEYS := ["verdict", "vcol", "vsub", "cede", "scratched", "depthUm", "layer", "bleeds", "fullReach", "sev",
	"grooveWidthUm", "where"]
## El ángulo de ataque del ensayo (45° en las uñas; attack.gd): gira la cara que avanza y cambia el modo de abrasión, la
## fricción de arado y el desgaste, no la profundidad.
const ATTACK_KEYS := ["absMode", "fab", "muPlough", "muEff", "Ffric", "wearIdx"]
## Los escenarios del golden que cambian de veredicto o de profundidad: los ocho de los materiales
## (docs/fisica/pulido-materiales.md §7.8) y los dos del hueso del brazo (docs/fisica/pulido-biologia.md §9.4): el
## colmillo del Gabón se rompe contra el húmero a 41,4 mm y la garra del casuario topa con él sin marcarlo.
const GOLDEN_CHANGED := [
	"uña almendra 4N sobre pintura", "uña stiletto 30N sobre piel", "uña cuadrada 30N sobre piel",
	"uña + diamante 30N sobre zafiro", "gabón 30N impacto sobre piel", "casuario 500N impacto sobre piel",
	"uña + cuarzo 30N sobre pantalla móvil", "uña almendra 30N ×20 sobre piel",
	"uña stiletto de metal, golpe, coche moderno", "uña stiletto de metal, golpe, coche clásico",
]

var _by_id := {}
var _sample: Dictionary


func before_each() -> void:
	if _by_id.is_empty():
		var catalogs := { "GEOMS": Data.GEOMS, "BASES": Data.BASES, "INLAYS": Data.INLAYS, "CLAWS": Data.CLAWS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES }
		for key: String in catalogs:
			var index := {}
			for x: Dictionary in catalogs[key]:
				index[x.id] = x
			_by_id[key] = index
	if _sample.is_empty():
		_sample = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))


func _find(key: String, id: Variant) -> Variant:
	return null if id == null else _by_id[key][id]


func _params(p: Dictionary, model: String) -> Dictionary:
	return {
		"geom": _find("GEOMS", p.geom), "base": _find("BASES", p.base), "inlay": _find("INLAYS", p.inlay),
		"claw": _find("CLAWS", p.get("claw")), "target": _find("TARGETS", p.target), "type": _find("TYPES", p.type),
		"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike,
		"passes": p.passes, "wet": p.wet, "model": model,
	}


## Primera diferencia entre dos resultados, al bit (same() de case.gd), o "" si son idénticos.
static func _first_diff(a: Variant, b: Variant, path := "") -> String:
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				return "%s.%s: solo en 2.0" % [path, k]
			var d := _first_diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		for k in b:
			if not a.has(k):
				return "%s.%s: solo en 1.x" % [path, k]
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: %d elementos frente a %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _first_diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if not same(a, b):
		return "%s: %s (2.0) ≠ %s (1.x)" % [path, show(a), show(b)]
	if is_num(a) and float(a) == 0.0 and signf(1.0 / float(a)) != signf(1.0 / float(b)):
		return "%s: signo del cero distinto" % path
	return ""


## Mecanismos de la 2.0 que actúan en un resultado del modelo 2.0 y las claves de la 1.x que dejan cambiar:
## { mech: [nombres], any: bool (la uña cedida: cualquier clave), keys: { clave: true } }.
static func _mechanisms(r2: Dictionary) -> Dictionary:
	var mech: Array = []
	var keys := {}
	var nail: Variant = r2.get("nail")
	if nail is Dictionary and nail.broken:
		return { "mech": ["uña"], "any": true, "keys": keys }
	var fr: Variant = r2.get("fracture")
	var rec: Variant = r2.get("recovery")
	if rec is Dictionary and fr == null and float(rec.recoveredUm) > 0.0:
		mech.append("recuperación")
		for k: String in CLASS_KEYS:
			keys[k] = true
	if fr is Dictionary and fr.mode == "hertz":
		mech.append("Hertz")
		for k: String in VERDICT_KEYS:
			keys[k] = true
	if fr is Dictionary and fr.mode == "radial":
		mech.append("astillado")
		keys["vsub"] = true
	var dent: Variant = r2.get("dent")
	if dent is Dictionary and dent.visible:
		mech.append("abolladura")
		for k: String in VERDICT_KEYS:
			keys[k] = true
	var chip: Variant = r2.get("tipChip")
	if chip is Dictionary and chip.chipped:
		mech.append("mellado")
		keys["vsub"] = true
	# biología (unidad 4b): la piel por capas con el hueso, el esmalte de los colmillos y el ángulo de ataque
	var pen: Variant = r2.get("pen")
	if pen is Dictionary:
		if pen.method == "puncion":
			keys["workJ"] = true  # el trabajo de penetración (en la 1.x, null en la piel)
			if pen.pierces:
				mech.append("punción por capas")
				for k: String in SKIN_KEYS:
					keys[k] = true
		elif pen.boneHit:
			mech.append("hueso")
			for k: String in SKIN_KEYS:
				keys[k] = true
	var tip_hv: Variant = r2.get("tipHv")
	if tip_hv != null and float(tip_hv) != float(r2.hvTool):
		# la punta de esmalte cambia la resistencia del sólido: el ensayo entero es otro
		return { "mech": mech + ["esmalte"], "any": true, "keys": keys }
	var att: Variant = r2.get("attackDeg")
	if att != null and float(att) != 90.0 and r2.get("DpEff") != null and r2.DpEff != r2.Dp:
		mech.append("ángulo")
		for k: String in ATTACK_KEYS:
			keys[k] = true
	return { "mech": mech, "any": false, "keys": keys }


## "" si el resultado de la 2.0 solo difiere del de la 1.x donde lo explica un mecanismo de la 2.0 (y los campos nuevos
## existen en los dos, a null en la 1.x); si no, la primera diferencia sin explicar.
static func _unexplained(r2: Dictionary, r1: Dictionary) -> String:
	for k: String in Physics.V2_FIELDS:
		if not r1.has(k) or r1[k] != null:
			return ".%s: en la 1.x tiene que existir a null" % k
		if not r2.has(k):
			return ".%s: falta en la 2.0" % k
	if not is_num(r2.get("residualDepthUm")):
		return ".residualDepthUm: en la 2.0 nunca es null"
	var m := _mechanisms(r2)
	for k in r1:
		if Physics.V2_FIELDS.has(k):
			continue
		if not r2.has(k):
			return ".%s: solo en 1.x" % k
		var d := _first_diff(r2[k], r1[k], "." + String(k))
		if d != "" and not m.any and not m.keys.has(k):
			return "%s (mecanismos de la 2.0: %s)" % [d, m.mech]
	# en la piel, la 2.0 dice si la herramienta cede: la uña que se dobla y, al punzar, el colmillo contra el hueso
	# (docs/fisica/pulido-biologia.md §9.3). Es toolBroken, que la piel de la 1.x no lleva.
	var pen: Variant = r2.get("pen")
	var skin_puncture: bool = pen is Dictionary and pen.method == "puncion"
	for k in r2:
		if not r1.has(k) and not (k == "toolBroken" and (m.any or skin_puncture)):
			return ".%s: solo en 2.0" % k
	return ""


func test_version_del_modelo() -> void:
	assert_eq(Physics.MODEL_DEFAULT, "2.0", "la aplicación usa la física 2.0")
	assert_eq(Physics.model_of({}), "2.0", "sin model: la de la aplicación")
	assert_eq(Physics.model_of({ "model": null }), "2.0")
	assert_eq(Physics.model_of({ "model": "1.x" }), "1.x")
	assert_eq(Physics.model_of({ "model": &"2.0" }), "2.0", "también como StringName")
	assert_true(Physics.is_v2({}) and Physics.is_v2({ "model": "2.0" }) and not Physics.is_v2({ "model": "1.x" }))
	assert_eq(Physics.MODELS, ["1.x", "2.0"])


func test_golden_2_0_igual_que_1_x() -> void:
	# acotado (unidades 4a y 4b): igual salvo donde actúa un mecanismo de la 2.0; y los que cambian de veredicto o de
	# profundidad son exactamente los de las guías de integración (materiales §7.8 y biología §9.4)
	var golden: Array = load_json("res://tests/fixtures/lab-golden.json")
	var bad := 0
	var changed: Array = []
	for g: Dictionary in golden:
		var r2 := Physics.compute(_params(g.params, V2))
		var r1 := Physics.compute(_params(g.params, V1))
		var d := _unexplained(r2, r1)
		if d != "":
			bad += 1
			if bad <= MAX_REPORTED:
				fail("«%s»: %s" % [g.name, d])
		# con la política del oráculo (error relativo ≤ 1e-9 o absoluto ≤ 1e-12: 3·10⁻¹⁹ µm y 0 son «sin surco» los dos)
		if r2.verdict != r1.verdict or not near(r2.depthUm, r1.depthUm):
			changed.append(g.name)
	assert_eq(golden.size(), 40, "escenarios del golden")
	assert_eq(bad, 0, "escenarios del golden en que 2.0 ≠ 1.x sin un mecanismo de la 2.0 que lo explique")
	assert_eq(changed, GOLDEN_CHANGED, "escenarios del golden que cambian de veredicto o de profundidad (§7.8 y §9.4)")


func test_muestra_2_0_igual_que_1_x() -> void:
	# ~38.000 compute(): en todos los núcleos (la física es segura para hilos: tests/lab/test_threads.gd)
	var trials: Array = _sample.trials
	var params: Array = []
	for t: Dictionary in trials:
		params.append([_params(t.params, V2), _params(t.params, V1)])
	var diffs: Array = []
	diffs.resize(trials.size())
	var mechs: Array = []
	mechs.resize(trials.size())
	var lock := Mutex.new()
	var job := func(i: int) -> void:
		var r2 := Physics.compute(params[i][0])
		var r1 := Physics.compute(params[i][1])
		var d := _unexplained(r2, r1)
		var m: Array = _mechanisms(r2).mech if r2.verdict != r1.verdict or not near(r2.depthUm, r1.depthUm) else []
		lock.lock()
		if d != "":
			diffs[i] = d
		mechs[i] = m
		lock.unlock()
	var t0 := Time.get_ticks_msec()
	var task := WorkerThreadPool.add_group_task(job, trials.size(), -1, true, "modelo 2.0 frente a 1.x")
	WorkerThreadPool.wait_for_group_task_completion(task)
	var bad := 0
	var changed := 0
	var by_mech := {}
	for i in trials.size():
		if diffs[i] != null:
			bad += 1
			if bad <= MAX_REPORTED:
				fail("%s: %s" % [JSON.stringify(trials[i].params), diffs[i]])
		if not (mechs[i] as Array).is_empty():
			changed += 1
			for name: String in mechs[i]:
				by_mech[name] = int(by_mech.get(name, 0)) + 1
	assert_true(trials.size() > 19000, "ensayos de la muestra: %d" % trials.size())
	assert_eq(bad, 0, "ensayos de la muestra en que 2.0 ≠ 1.x sin un mecanismo de la 2.0 que lo explique")
	print("    (info) %d ensayos con los dos modelos en %d hilos: %d cambian de veredicto o de profundidad %s, ninguno sin explicar (%s s)" % [
		trials.size(), OS.get_processor_count(), changed, JSON.stringify(by_mech), _Js.to_fixed((Time.get_ticks_msec() - t0) / 1000.0, 1)])


func test_herramientas_y_modo_dual_2_0_igual_que_1_x() -> void:
	var bad := 0
	for row: Dictionary in _sample.resolved:
		var p := { "geom": _find("GEOMS", row.geom), "base": _find("BASES", row.base), "inlay": _find("INLAYS", row.inlay), "claw": _find("CLAWS", row.get("claw")), "wet": row.wet }
		var q := p.duplicate()
		p.model = V2
		q.model = V1
		var d := _first_diff(Physics.resolve_tool(p), Physics.resolve_tool(q))
		if d != "":
			bad += 1
			if bad <= MAX_REPORTED:
				fail("resolve_tool %s: %s" % [JSON.stringify(row), d])
	var done := {}
	for row: Dictionary in _sample.duels:
		var key := "%s|%s|%s|%s" % [row.claw, row.inlay, row.cars[0], row.cars[1]]
		if done.has(key):
			continue
		done[key] = true
		var claw: Dictionary = _find("CLAWS", row.claw)
		var cars: Array = [_find("TARGETS", row.cars[0]), _find("TARGETS", row.cars[1])]
		var params := { "geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": _find("INLAYS", row.inlay), "force": claw.force, "length": 25.0, "type": Data.TYPES[1], "passes": 1.0, "wet": false }
		var p2 := params.duplicate()
		p2.model = V2
		var p1 := params.duplicate()
		p1.model = V1
		var rows2 := Lab.duel(p2, claw, cars)
		var rows1 := Lab.duel(p1, claw, cars)
		# las mismas filas y maneras de atacar; cada resultado, igual salvo donde actúa un mecanismo de la 2.0
		var d := _first_diff(rows2.map(func(r: Dictionary) -> String: return r.id), rows1.map(func(r: Dictionary) -> String: return r.id))
		for i in mini(rows2.size(), rows1.size()):
			for j in 2:
				if d == "":
					d = _unexplained(rows2[i].res[j], rows1[i].res[j])
		if d != "":
			bad += 1
			if bad <= MAX_REPORTED:
				fail("duelo %s: %s" % [key, d])
	assert_true(_sample.resolved.size() > 1500 and done.size() > 100, "herramientas y duelos de la muestra")
	assert_eq(bad, 0, "herramientas iguales y duelos que solo cambian donde actúa un mecanismo de la 2.0")
