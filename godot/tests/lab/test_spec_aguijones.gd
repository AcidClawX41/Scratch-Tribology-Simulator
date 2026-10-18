## Casos de referencia de los aguijones (tests/fixtures/spec/aguijones.json, docs/fisica/aguijones.md §7.10) contra el
## compute() INTEGRADO: Physics.compute con el catálogo de la aplicación (core/lab/catalog.gd) y el modelo 2.0, como los
## calcula el banco. tests/lab/test_sting.gd comprueba los mismos casos contra la referencia de la unidad 1a
## (Sting.sting_report y Sting.solid_params); aquí se comprueba que la integración da lo mismo.
## Formato: `expect` es { ruta con puntos dentro del resultado: { value | min | max, tol } }; `tol` es relativa;
## `value` sin `tol` exige igualdad exacta; `min` y `max` son inclusivos. Un caso que no se cumple no se ajusta: se
## averigua si el fallo es de la integración o de la especificación.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Sting = preload("res://core/lab/sting.gd")

const SPEC := "res://tests/fixtures/spec/aguijones.json"

var cases: Array = []


func before_each() -> void:
	if cases.is_empty():
		cases = load_json(SPEC)


## Parámetros de compute() para la entrada de un caso (ids del catálogo de la aplicación).
static func params_of(inp: Dictionary) -> Dictionary:
	return {
		"geom": Catalog.find_by_id(Catalog.GEOMS, inp.geom), "base": Catalog.find_by_id(Catalog.BASES, inp.base),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, inp.inlay), "claw": Catalog.find_by_id(Catalog.CLAWS, inp.claw),
		"target": Catalog.find_by_id(Catalog.TARGETS, inp.target), "type": Catalog.find_by_id(Catalog.TYPES, inp.type),
		"force": float(inp.force), "length": float(inp.length), "tear": inp.tear, "method": inp.method,
		"strike": inp.strike, "passes": float(inp.passes), "wet": inp.wet, "model": inp.model,
	}


static func at_path(root: Dictionary, path: String) -> Variant:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not cur.has(key):
			return "<falta>"
		cur = cur[key]
	return cur


## Motivo por el que un valor no cumple lo esperado, o "" si lo cumple.
static func mismatch(got: Variant, exp: Dictionary) -> String:
	if exp.has("value"):
		var want: Variant = exp.value
		if want == null or typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
			if not (typeof(got) == typeof(want) and got == want):
				return "%s ≠ %s" % [show(got), show(want)]
		elif not is_num(got):
			return "%s no es un número" % show(got)
		elif exp.has("tol"):
			if absf(float(got) - float(want)) > float(exp.tol) * absf(float(want)):
				return "%s ≠ %s ± %s %%" % [show(got), show(want), float(exp.tol) * 100.0]
		elif float(got) != float(want):
			return "%s ≠ %s" % [show(got), show(want)]
	if exp.has("min") and not (is_num(got) and float(got) >= float(exp.min)):
		return "%s < %s" % [show(got), show(exp.min)]
	if exp.has("max") and not (is_num(got) and float(got) <= float(exp.max)):
		return "%s > %s" % [show(got), show(exp.max)]
	return ""


func test_el_archivo_de_casos() -> void:
	assert_eq(cases.size(), 24, "24 casos de referencia")
	var ids := {}
	for cs: Dictionary in cases:
		assert_false(ids.has(cs.id), "id repetido: %s" % cs.id)
		ids[cs.id] = true
		assert_eq(cs.input.get("model"), "2.0", "%s: caso del modelo 2.0" % cs.id)
		var p := params_of(cs.input)
		for k: String in ["geom", "base", "inlay", "claw", "target", "type"]:
			assert_true(p[k] != null, "%s: «%s» está en el catálogo de la aplicación (%s)" % [cs.id, cs.input.get(k), k])


func test_casos_de_referencia_con_el_compute_integrado() -> void:
	var passed := 0
	var failed: Array[String] = []
	for cs: Dictionary in cases:
		var p := params_of(cs.input)
		if p.claw == null or p.target == null:
			failed.append(cs.id)
			continue
		var r := Physics.compute(p)
		var bad: Array[String] = []
		for field: String in cs.expect:
			var why := mismatch(at_path(r, field), cs.expect[field])
			if why != "":
				bad.append("%s: %s" % [field, why])
		for b in bad:
			fail("%s · %s" % [cs.id, b])
		if bad.is_empty():
			passed += 1
		else:
			failed.append(cs.id)
	assert_eq(passed, cases.size(), "casos que cumple el compute() integrado (fallan: %s)" % ", ".join(failed))
	print("    (info) casos de referencia de los aguijones: %d/%d con el compute() integrado" % [passed, cases.size()])


func test_la_integracion_da_lo_mismo_que_la_referencia_de_la_unidad_1a() -> void:
	# el bloque `sting` es exactamente Sting.sting_report(p) y, en un sólido, los números salen del motor de siempre con
	# Sting.solid_params(p) (lo que usa test_sting.gd)
	for cs: Dictionary in cases:
		var p := params_of(cs.input)
		var r := Physics.compute(p)
		assert_eq(oracle_diff(r.sting, Sting.sting_report(p)).size(), 0, "%s: result.sting = Sting.sting_report" % cs.id)
		if not p.target.get("skin", false):
			var ref := Physics.compute(Sting.solid_params(p))
			for k: String in ["depthUm", "toolBroken", "pierces", "ratio", "tHV", "pressure", "sev", "grooveWidthUm", "workJ"]:
				assert_eq(oracle_diff(r.get(k), ref.get(k), k).size(), 0, "%s: %s como el motor de siempre" % [cs.id, k])
