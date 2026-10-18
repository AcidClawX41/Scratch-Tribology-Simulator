## La física del laboratorio (core/lab/physics.gd y lab.gd) contra el motor 1.x, que es el oráculo:
##   - los 40 escenarios del golden (tests/fixtures/lab-golden.json): resultado completo de compute(), etiqueta
##     del cuaderno, informe y etapa de daños, y logros acumulados a lo largo de la serie;
##   - la muestra del barrido de audit.js (tests/fixtures/generated/lab-sample.json, uno de cada 31 ensayos):
##     ~19.000 ensayos, las fichas de las garras, resolveTool de todas las herramientas y el modo dual.
## Política (case.gd → oracle_diff): textos, veredictos, capas y booleanos idénticos; números con error relativo
## ≤ 1e-9. Se exige 0 discrepancias. Todo se calcula con el modelo "1.x" (Physics.MODEL_V1), el del motor 1.x.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")

const SAMPLE := "res://tests/fixtures/generated/lab-sample.json"
## El oráculo es el motor 1.x: todos los ensayos de este archivo usan su modelo.
const V1 := Physics.MODEL_V1
const MAX_REPORTED := 8  # discrepancias que se escriben en detalle (se cuentan todas)

var golden: Array
var sample: Dictionary
var _by_id := {}  # catálogo → { id → entrada }
var _compute_usec := 0
var _compute_runs := 0


func before_each() -> void:
	if golden.is_empty():
		golden = load_json("res://tests/fixtures/lab-golden.json")
		var catalogs := { "GEOMS": Data.GEOMS, "BASES": Data.BASES, "INLAYS": Data.INLAYS, "CLAWS": Data.CLAWS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES }
		for key: String in catalogs:
			var index := {}
			for x: Dictionary in catalogs[key]:
				index[x.id] = x
			_by_id[key] = index
	if sample.is_empty():
		# sin decode() de todo el archivo (28 MB): oracle_diff decodifica cada valor esperado al compararlo
		sample = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))


func _find(key: String, id: Variant) -> Variant:
	return null if id == null else _by_id[key][id]


## Los parámetros de compute() a partir de los ids del oráculo (trial() de export-fixtures.mjs).
func _params(p: Dictionary) -> Dictionary:
	return {
		"geom": _find("GEOMS", p.geom), "base": _find("BASES", p.base), "inlay": _find("INLAYS", p.inlay),
		"claw": _find("CLAWS", p.get("claw")), "target": _find("TARGETS", p.target), "type": _find("TYPES", p.type),
		"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike,
		"passes": p.passes, "wet": p.wet, "model": V1,
	}


func _compute(p: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var r := Physics.compute(p)
	_compute_usec += Time.get_ticks_usec() - t0
	_compute_runs += 1
	return r


## Compara un ensayo con el del oráculo: resultado, etiqueta del cuaderno e informe y etapa de daños.
## Devuelve las discrepancias (vacío si todo coincide).
func _check_trial(want: Dictionary, where: String) -> Array[String]:
	var p := _params(want.params)
	var r := _compute(p)
	var out := oracle_diff(r, want.result, where + " result")
	var label := Lab.tool_label({ "claw": p.claw, "geom": p.geom, "inlay": p.inlay, "res": r })
	if label != want.toolLabel:
		out.append("%s toolLabel: «%s» ≠ «%s»" % [where, label, want.toolLabel])
	var target: Dictionary = p.target
	var reports := target.get("body") != null or target.get("pane") != null or target.get("thickness") != null
	if reports != want.has("damage"):
		out.append("%s: informe de daños %s" % [where, "de más" if reports else "que falta"])
	if want.has("damage"):
		out.append_array(oracle_diff(Lab.damage_report(r, target, p.length), want.damage, where + " damage"))
	if want.has("damageStage"):
		out.append_array(oracle_diff(Lab.damage_stage(r), want.damageStage, where + " damageStage"))
	return out


func _report(diffs: Array[String], bad: int, what: String) -> void:
	if bad > 0 and bad <= MAX_REPORTED:
		for d in diffs.slice(0, 4):
			fail("%s: %s" % [what, d])


func test_golden_40_escenarios_identicos() -> void:
	var badges := {}
	var bad := 0
	for i in golden.size():
		var g: Dictionary = golden[i]
		var diffs := _check_trial(g, "«%s»" % g.name)
		var p := _params(g.params)
		var r: Dictionary = Physics.compute(p)
		# logros acumulados a lo largo de la serie (y en el mismo orden de inserción que el Set del JS)
		badges = Lab.earn_badges(badges, { "res": r, "target": p.target, "inlay": p.inlay, "claw": p.claw, "method": p.method, "strike": p.strike, "runs": i + 1 })
		diffs.append_array(oracle_diff(badges.keys(), g.badgesAfter, "«%s» badgesAfter" % g.name))
		if diffs.size() > 0:
			bad += 1
			_report(diffs, bad, "golden")
	assert_eq(golden.size(), 40, "escenarios del golden")
	assert_eq(bad, 0, "escenarios del golden con alguna discrepancia")


func test_muestra_del_barrido_identica() -> void:
	var trials: Array = sample.trials
	var bad := 0
	_compute_usec = 0
	_compute_runs = 0
	var t0 := Time.get_ticks_msec()
	for i in trials.size():
		var diffs := _check_trial(trials[i], "ensayo %d %s" % [i, JSON.stringify(trials[i].params)])
		if diffs.size() > 0:
			bad += 1
			_report(diffs, bad, "muestra")
	assert_true(trials.size() > 19000, "la muestra tiene ~19.000 ensayos (hay %d)" % trials.size())
	assert_eq(bad, 0, "ensayos de la muestra con alguna discrepancia (de %d)" % trials.size())
	print("    compute() en GDScript: %d ensayos, media %s µs por ensayo (%s s en total con las comparaciones)" % [
		_compute_runs, _fmt1(float(_compute_usec) / maxi(_compute_runs, 1)), _fmt1((Time.get_ticks_msec() - t0) / 1000.0)])


func test_fichas_de_las_garras_identicas() -> void:
	var bad := 0
	for row: Dictionary in sample.clawSpecs:
		var claw: Dictionary = _find("CLAWS", row.claw)
		var inlay: Dictionary = _find("INLAYS", row.inlay)
		var tool := Physics.resolve_tool({ "geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": inlay, "claw": claw, "wet": row.wet, "model": V1 })
		var diffs := oracle_diff(Lab.claw_spec(claw, inlay, tool), row.spec, "clawSpec %s/%s%s" % [row.claw, row.inlay, " húmeda" if row.wet else ""])
		if diffs.size() > 0:
			bad += 1
			_report(diffs, bad, "fichas")
	assert_true(sample.clawSpecs.size() > 400, "fichas de garras en la muestra")
	assert_eq(bad, 0, "fichas de garras distintas")


func test_resolve_tool_de_todas_las_herramientas() -> void:
	var bad := 0
	for row: Dictionary in sample.resolved:
		var p := { "geom": _find("GEOMS", row.geom), "base": _find("BASES", row.base), "inlay": _find("INLAYS", row.inlay), "claw": _find("CLAWS", row.get("claw")), "wet": row.wet, "model": V1 }
		var where := "resolveTool %s/%s/%s/%s%s" % [row.geom, row.base, row.inlay, row.get("claw"), " húmeda" if row.wet else ""]
		var diffs := oracle_diff(Physics.resolve_tool(p), row.tool, where)
		if diffs.size() > 0:
			bad += 1
			_report(diffs, bad, "resolveTool")
	assert_true(sample.resolved.size() > 1500, "herramientas resueltas en la muestra")
	assert_eq(bad, 0, "herramientas resueltas distintas")


func test_modo_dual_identico() -> void:
	var cache := {}  # garra/incrustación/coches → filas de duel()
	var bad := 0
	for row: Dictionary in sample.duels:
		var claw: Dictionary = _find("CLAWS", row.claw)
		var inlay: Dictionary = _find("INLAYS", row.inlay)
		var cars: Array = [_find("TARGETS", row.cars[0]), _find("TARGETS", row.cars[1])]
		var key := "%s|%s|%s|%s" % [row.claw, row.inlay, row.cars[0], row.cars[1]]
		if not cache.has(key):
			var params := { "geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": inlay, "force": claw.force, "length": 25.0, "type": Data.TYPES[1], "passes": 1.0, "wet": false, "model": V1 }
			cache[key] = Lab.duel(params, claw, cars)
		var ours: Variant = null
		for r: Dictionary in cache[key]:
			if r.id == row.row:
				ours = r
		var where := "duelo %s · %s" % [key, row.row]
		var diffs: Array[String] = []
		if ours == null:
			diffs.append("%s: falta la fila" % where)
		else:
			diffs.append_array(oracle_diff(ours.res, row.res, where + " res"))
			diffs.append_array(oracle_diff(Lab.duel_verdict(ours.res[0], ours.res[1], cars), row.verdict, where + " verdict"))
			var lens: Array = []
			for r: Dictionary in ours.res:
				lens.append({ "depth": Lab.fmt_len(r.depthUm), "groove": Lab.fmt_len(r.grooveWidthUm) })
			diffs.append_array(oracle_diff(lens, row.lens, where + " lens"))
		if diffs.size() > 0:
			bad += 1
			_report(diffs, bad, "modo dual")
	assert_true(sample.duels.size() > 1000, "filas del modo dual en la muestra")
	assert_eq(bad, 0, "filas del modo dual distintas")


func test_duel_filas_por_herramienta() -> void:
	# una uña no desgarra: sus filas son rayar, punzar y golpear; una garra, las cuatro
	var cars: Array = []
	for id: String in Lab.DUEL_DEFAULT:
		cars.append(_find("TARGETS", id))
	var params := { "geom": _find("GEOMS", "almendra"), "base": _find("BASES", "natural"), "inlay": _find("INLAYS", "none"), "force": 30.0, "length": 25.0, "type": Data.TYPES[1], "passes": 1.0, "wet": false, "model": V1 }
	var ids := Lab.duel(params, null, cars).map(func(r: Dictionary) -> String: return r.id)
	assert_eq(ids, ["rayado", "puncion", "golpe"])
	var aguila: Dictionary = _find("CLAWS", "aguila")
	var rows := Lab.duel(params, aguila, cars)
	assert_eq(rows.map(func(r: Dictionary) -> String: return r.id), Lab.DUEL_MODES.map(func(m: Dictionary) -> String: return m.id))
	for row: Dictionary in rows:
		for i in 2:
			assert_eq(row.res[i].tName, cars[i].name)
		var p := params.duplicate()
		p.claw = aguila
		p.merge(row.p, true)
		p.target = cars[0]
		assert_eq(oracle_diff(row.res[0], Physics.compute(p)).size(), 0, "el duelo no hace física propia")


static func _fmt1(x: float) -> String:
	return preload("res://core/shared/js.gd").to_fixed(x, 1)
