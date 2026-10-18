## Casos de referencia del pulido de materiales (tests/fixtures/spec/pulido-materiales.json, unidad 1f).
##
## 1. El archivo tiene el formato de CONTRATOS.md («Especificaciones y casos de referencia») y los ids del oráculo.
## 2. Referencia ejecutable: los campos nuevos de la 2.0 que no dependen de la integración (fracture, nail, dent,
##    glazing, recovery, residualDepthUm, tipChip y la profundidad con la fuerza que llega de verdad a la punta) se
##    reconstruyen aquí con los módulos de la 1f y el motor 1.x, como lo describe la guía de integración de
##    docs/fisica/pulido-materiales.md. Así los números del archivo no pueden ser erratas. Los veredictos nuevos
##    («GRIETAS DE HERTZ», «SE DOBLA LA UÑA»…) los comprueba el test de la integración con su compute().
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Recovery = preload("res://core/lab/recovery.gd")
const Bending = preload("res://core/lab/bending.gd")
const Dent = preload("res://core/lab/dent.gd")
const Glazing = preload("res://core/lab/glazing.gd")

const SPEC := "res://tests/fixtures/spec/pulido-materiales.json"
const INPUT_KEYS := ["geom", "base", "inlay", "claw", "target", "type", "force", "length", "tear", "method", "strike", "passes", "wet", "model"]
## Campos que reconstruye la referencia (el resto, como verdict, lo comprueba la integración).
const OWN := ["fracture", "nail", "dent", "glazing", "recovery", "residualDepthUm", "tipChip", "depthUm"]


func _target(id: String) -> Variant:
	var t: Variant = Data.find_by_id(Data.TARGETS, id)
	return t if t != null else Data.find_by_id(Glazing.TARGETS, id)


func _params(inp: Dictionary, force: float, strike: bool) -> Dictionary:
	return {
		"geom": Data.find_by_id(Data.GEOMS, inp.geom), "base": Data.find_by_id(Data.BASES, inp.base),
		"inlay": Data.find_by_id(Data.INLAYS, inp.inlay), "claw": Data.find_by_id(Data.CLAWS, inp.claw) if inp.claw != null else null,
		"target": _target(inp.target), "type": Data.find_by_id(Data.TYPES, inp.type), "force": force, "length": float(inp.length),
		"tear": inp.tear, "method": inp.method, "strike": strike, "passes": inp.passes, "wet": inp.wet, "model": "1.x",
	}


## Los campos de la 1f para un caso, con el motor 1.x como base (la receta de la guía de integración).
func _reference(inp: Dictionary) -> Dictionary:
	var p := _params(inp, float(inp.force), inp.strike)
	var target: Dictionary = p.target
	var tool := Physics.resolve_tool(p)
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	var sliding: bool = inp.method == "rayado"
	var puncture := not sliding
	var res := Physics.compute(p)
	# 1. la uña cede antes de transmitir la fuerza pedida: la fuerza que llega a la punta es la de rotura
	var nail: Variant = null
	var f_tip := float(inp.force)
	if not Physics.truthy(p.claw):
		nail = Bending.evaluate(inp.base, p.geom.reach, tool.wet, f_tip, target.mu, sliding)
		if nail != null:
			if puncture and inp.strike:
				# en un golpe cuenta la resistencia en el camino: como la rotura del colmillo, cede si la profundidad
				# del golpe pide más que su carga de rotura
				var at_break := Physics.compute(_params(inp, nail.breakN, false))
				if at_break.depthUm < res.depthUm - 1e-9:
					nail.broken = true
					res = at_break
					f_tip = nail.breakN
			elif nail.broken:
				f_tip = nail.breakN
				res = Physics.compute(_params(inp, f_tip, inp.strike))
	var fracture: Variant = Fracture.evaluate(tool, tip, target, f_tip, sliding, target.mu, res.depthUm, res.grooveWidthUm / 2.0)
	var rec: Variant = Recovery.evaluate(target, res.depthUm, res.grooveWidthUm / 2.0, res.through)
	var dent: Variant
	if puncture and inp.strike:
		dent = Dent.evaluate(target, 0.0, true, res.energyJ - res.workJ, Physics.MODEL.limbStiffness, res.through)
	else:
		dent = Dent.evaluate(target, f_tip, false, 0.0, Physics.MODEL.limbStiffness, res.through)
	var glazing: Variant = null
	if Physics.truthy(target.get("tempered")):
		glazing = Glazing.tempered_result(target, res.peakN, res.paneN, tool.hv / target.hv >= 1.0, f_tip, tip.tanA)
	elif Physics.truthy(target.get("laminated")):
		glazing = Glazing.laminated_result(target, res.peakN, res.paneN, fracture != null and fracture.cracks, res.energyJ)
	var chip: Variant = null
	if Physics.truthy(p.claw) and tool.hasGem:
		chip = Fracture.tip_chip(inp.inlay, tip, tool.reach, f_tip, target.mu if sliding else 0.0)
	return {
		"fracture": fracture, "nail": nail, "dent": dent, "glazing": glazing, "recovery": rec,
		"residualDepthUm": rec.residualDepthUm if rec != null else null, "tipChip": chip, "depthUm": res.depthUm,
	}


func _at(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if not (cur is Dictionary):
			return null
		cur = cur.get(part)
	return cur


func test_formato_de_los_casos() -> void:
	var cases: Variant = load_json(SPEC)
	assert_true(cases is Array and cases.size() >= 30, "hay casos")
	var seen := {}
	for c: Dictionary in cases:
		var id: String = c.get("id", "")
		assert_true(id != "" and not seen.has(id), "id único: %s" % id)
		seen[id] = true
		for k: String in ["id", "note", "input", "expect", "source"]:
			assert_true(c.has(k), "%s lleva %s" % [id, k])
		assert_true(String(c.source).length() > 10 and String(c.note).length() > 10, "%s: fuente y nota" % id)
		var inp: Dictionary = c.input
		for k: String in INPUT_KEYS:
			assert_true(inp.has(k), "%s: input.%s" % [id, k])
		assert_eq(inp.model, "2.0", "%s: modelo 2.0" % id)
		assert_true(Data.find_by_id(Data.GEOMS, inp.geom) != null, "%s: geom" % id)
		assert_true(Data.find_by_id(Data.BASES, inp.base) != null, "%s: base" % id)
		assert_true(Data.find_by_id(Data.INLAYS, inp.inlay) != null, "%s: inlay" % id)
		assert_true(inp.claw == null or Data.find_by_id(Data.CLAWS, inp.claw) != null, "%s: claw" % id)
		assert_true(_target(inp.target) != null, "%s: target (del 1.x o de glazing.gd)" % id)
		assert_true(Data.find_by_id(Data.TYPES, inp.type) != null, "%s: type" % id)
		assert_true(inp.method == "rayado" or inp.method == "puncion", "%s: method" % id)
		assert_true(is_num(inp.force) and inp.force > 0.0, "%s: fuerza" % id)
		var expect: Dictionary = c.expect
		assert_true(expect.size() > 0, "%s: espera algo" % id)
		for k: String in expect:
			var e: Dictionary = expect[k]
			assert_true(e.has("value") or e.has("min") or e.has("max"), "%s.%s: value, min o max" % [id, k])
			if e.has("tol"):
				assert_true(is_num(e.get("value")) and e.tol > 0.0, "%s.%s: tol con un valor numérico" % [id, k])
			if is_num(e.get("value")) and not e.has("tol"):
				fail("%s.%s: un número sin tol (la tolerancia es relativa)" % [id, k])


func test_referencia_ejecutable() -> void:
	var cases: Array = load_json(SPEC)
	var checked := 0
	for c: Dictionary in cases:
		var ref := _reference(c.input)
		for k: String in c.expect:
			if not OWN.has(k.split(".")[0]):
				continue
			var e: Dictionary = c.expect[k]
			var got: Variant = _at(ref, k)
			var where := "%s · %s" % [c.id, k]
			checked += 1
			if e.has("value"):
				if e.has("tol"):
					assert_true(is_num(got) and absf(float(got) - float(e.value)) <= float(e.tol) * absf(float(e.value)), "%s: %s frente a %s" % [where, show(got), show(e.value)])
				else:
					assert_true(same(got, e.value), "%s: %s frente a %s" % [where, show(got), show(e.value)])
			if e.has("min"):
				assert_true(is_num(got) and float(got) >= float(e.min), "%s: %s < %s" % [where, show(got), show(e.min)])
			if e.has("max"):
				assert_true(is_num(got) and float(got) <= float(e.max), "%s: %s > %s" % [where, show(got), show(e.max)])
	assert_true(checked >= 100, "comprueba %d campos" % checked)
