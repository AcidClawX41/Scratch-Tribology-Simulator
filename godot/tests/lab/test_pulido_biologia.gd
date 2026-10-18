## Casos de referencia de la integración del modelo 2.0 de la biología (tests/fixtures/spec/pulido-biologia.json),
## comprobados contra la referencia: el motor 1.x (Physics.compute) con lo que cambia en el modelo 2.0, compuesto con los
## módulos nuevos (zones.gd, penetration.gd, attack.gd, fang_enamel.gd) sin copiar su física. La integración los cumple
## con su compute() (test_biologia_v2.gd; docs/fisica/pulido-biologia.md, guía de integración).
## Unidad 4b: cinco casos de uñas se recalcularon con la 2.0 completa (la uña que cede y la recuperación de los materiales,
## unidad 4a), que esta referencia no incluye: su `expect` es el del compute() integrado y lo de siempre de la 1g queda en
## `expect1g`, que es lo que se comprueba aquí (el mismo control que antes, caso por caso). Unidad 4i: igual con dos del
## casuario, cuyo golpe en el catálogo 2.0 es la patada del coche en marcha (~88 J); esta referencia usa data.gd (160 J).
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Zones = preload("res://core/lab/zones.gd")
const Pen = preload("res://core/lab/penetration.gd")
const Attack = preload("res://core/lab/attack.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")

const SPEC := "res://tests/fixtures/spec/pulido-biologia.json"


# ── Referencia ──

## Parámetros de compute() a partir de los ids del oráculo de un caso. La referencia es el motor 1.x: el modelo va
## explícito (unidad 4a: desde los materiales de la 2.0, el modelo por defecto ya no da lo mismo que la 1.x).
static func params_of(inp: Dictionary) -> Dictionary:
	return {
		"geom": Data.find_by_id(Data.GEOMS, inp.geom), "base": Data.find_by_id(Data.BASES, inp.base),
		"inlay": Data.find_by_id(Data.INLAYS, inp.inlay),
		"claw": Data.find_by_id(Data.CLAWS, inp.claw) if inp.get("claw") != null else null,
		"target": Data.find_by_id(Data.TARGETS, inp.target), "type": Data.find_by_id(Data.TYPES, inp.type),
		"force": float(inp.force), "length": float(inp.length), "tear": inp.tear, "method": inp.method,
		"strike": inp.strike, "passes": inp.passes, "wet": inp.wet, "model": Physics.MODEL_V1,
	}


## Lo que tiene que devolver compute() con model "2.0" para un caso (solo los campos que fija la especificación y los
## que dependen de ellos).
static func expected_result(inp: Dictionary) -> Dictionary:
	var p := params_of(inp)
	if Js.truthy(p.target.get("skin")):
		return _skin_reference(p, inp.get("zone"))
	return _solid_reference(p, inp.get("attack_deg"))


## Piel: lo que no depende de la zona sale de la 1.x (r1); lo que sí, de Penetration.skin_report.
static func _skin_reference(p: Dictionary, zone: Variant) -> Dictionary:
	var r1 := Physics.compute(p)
	var tool := Physics.resolve_tool(p)
	var rep := Pen.skin_report({
		"tool": tool, "tip": Contact.tip_geometry(tool.area, tool.alpha, tool.baseR), "zone": zone,
		"puncture": p.method == "puncion", "strike": p.strike, "Neff": float(p.force) + float(r1.Fadh_mN) / 1000.0,
		"energyJ": r1.energyJ, "passes": p.passes, "stress": r1.stress, "tearForce": r1.get("tearForce", 0.0),
		"ruptures": r1.get("ruptures", false),
	})
	var out := {
		"zone": rep.zone, "depthUm": rep.depthUm, "layer": rep.layer, "bleeds": rep.bleeds, "fullReach": rep.fullReach,
		"fPuncture": r1.fPuncture, "pen": rep,
	}
	if rep.method == "puncion":
		out.merge({
			"pierces": rep.pierces, "inject": tool.fang, "toolBroken": rep.toolBroken, "workJ": rep.workJ,
			"sev": maxf(0.3, Zones.severity(rep.zone, rep.depthUm)) if rep.pierces else 0.08,
		}, true)
	else:
		out.merge({ "ruptures": rep.ruptures, "tearForce": r1.tearForce, "stress": r1.stress }, true)
	return out


## Sólidos: el motor 1.x con el esmalte del colmillo y el ángulo de ataque.
static func _solid_reference(p: Dictionary, attack: Variant) -> Dictionary:
	var tool := Physics.resolve_tool(p)
	var r: Dictionary = _with_enamel(p) if FangEnamel.applies(tool) else Physics.compute(p)
	if r.has("referenceError"):
		return r
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	var a_mm: float = r.depthUm / r.Dp / 1000.0 if float(r.Dp) > 0.0 else 0.0
	r["tipHv"] = FangEnamel.tip_hv(tool, a_mm)
	var att: float = Attack.DEFAULT_DEG if attack == null else float(attack)
	r.merge({ "DpEff": r.Dp, "faceDeg": Attack.face_angle_deg(tool.alpha, att), "attackDeg": att }, true)
	if r.absMode != null:
		var puncture: bool = p.method == "puncion"
		var m: float = float(r.phi) * (1.0 if puncture else float(p.type.k) * Physics.pass_depth_factor(p.passes))
		var ab := Attack.abrasion(r.Dp, r.depthUm, m, tip, tool.alpha, attack)
		var mu_eff: float = float(r.muAdh) + float(ab.muPlough)
		var over := { "absMode": ab.absMode, "fab": ab.fab, "muPlough": ab.muPlough, "muEff": mu_eff, "DpEff": ab.DpEff }
		# con otro ataque, la fricción y el índice de desgaste escalan con lo nuevo (el índice de la 1.x está redondeado:
		# la referencia es aproximada, ±1)
		if not Attack.is_default(attack):
			over.merge({
				"Ffric": mu_eff * float(r.Ffric) / float(r.muEff), "wearIdx1x": r.wearIdx,
				"wearIdx": float(r.wearIdx) * float(ab.fab) / float(r.fab),
			}, true)
		r.merge(over, true)
	return r


## Esmalte en un sólido homogéneo (sin capas ni chapa; el vidrio de ventana vale), empujando o rayando (sin golpe): la
## resistencia 2.0 usa en cada contacto la dureza de la punta, FangEnamel.tip_hv(a). Como la resistencia es monótona, la
## profundidad es la de la 1.x con una garra de dureza constante igual a la de la punta en el contacto final (punto fijo
## hv* = tip_hv(a(h(hv*))), por bisección): así todo lo demás (alcance, rotura, presión, veredicto, Dp, abrasión, la
## hoja de vidrio) sale del motor de siempre sin copiarlo.
static func _with_enamel(p: Dictionary) -> Dictionary:
	var homogeneous: bool = not Js.truthy(p.target.get("layers")) and Physics.sheet_of(p.target) == null
	if not homogeneous or Js.truthy(p.get("strike")):
		return { "referenceError": "la referencia del esmalte solo cubre sólidos homogéneos sin golpe" }
	var tool := Physics.resolve_tool(p)
	var lo: float = tool.hv
	var hi: float = FangEnamel.ENAMEL.hv
	var best := {}
	for k in 100:
		var mid := (lo + hi) / 2.0
		var r := _compute_with_hv(p, mid)
		var a_mm: float = r.depthUm / r.Dp / 1000.0 if float(r.Dp) > 0.0 else 0.0
		var g := FangEnamel.tip_hv(tool, a_mm)
		best = r
		if g > mid:
			lo = mid
		else:
			hi = mid
		if hi - lo <= 1e-13 * hi:
			break
	return best


static func _compute_with_hv(p: Dictionary, hv: float) -> Dictionary:
	var q := p.duplicate()
	var claw: Dictionary = p.claw.duplicate()
	claw.hv = hv
	q.claw = claw
	return Physics.compute(q)


# ── Comprobación ──

static func _at(root: Dictionary, path: String) -> Variant:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not cur.has(key):
			return "<falta>"
		cur = cur[key]
	return cur


func _check(got: Variant, exp: Dictionary, where: String) -> void:
	if exp.has("value"):
		var want: Variant = exp.value
		if want == null or typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
			assert_eq(got, want, where)
		elif exp.has("tol"):
			assert_true(is_num(got), "%s: número (%s)" % [where, got])
			if is_num(got):
				assert_near(float(got), float(want), float(exp.tol), 0.0, where)
		else:
			assert_true(is_num(got) and float(got) == float(want), "%s: %s ≠ %s" % [where, got, want])
	if exp.has("min"):
		assert_true(is_num(got) and float(got) >= float(exp.min), "%s: %s ≥ %s" % [where, got, exp.min])
	if exp.has("max"):
		assert_true(is_num(got) and float(got) <= float(exp.max), "%s: %s ≤ %s" % [where, got, exp.max])


func test_casos_de_referencia_de_la_integracion() -> void:
	var cases: Variant = load_json(SPEC)
	assert_true(cases is Array and cases.size() >= 30, "el archivo de casos tiene al menos 30 casos")
	if not (cases is Array):
		return
	var ids := {}
	for cs: Dictionary in cases:
		assert_false(ids.has(cs.id), "id de caso repetido: %s" % cs.id)
		ids[cs.id] = true
		assert_true(String(cs.get("source", "")).length() > 5, "%s: tiene fuente" % cs.id)
		assert_true(String(cs.get("note", "")).length() > 10, "%s: tiene nota" % cs.id)
		var inp: Dictionary = cs.input
		assert_eq(inp.get("model"), "2.0", "%s: caso del modelo 2.0" % cs.id)
		var p := params_of(inp)
		for k: String in ["geom", "base", "inlay", "target", "type"]:
			assert_true(p[k] != null, "%s: id válido en %s (%s)" % [cs.id, k, inp.get(k)])
		if inp.get("claw") != null:
			assert_true(p.claw != null, "%s: garra %s" % [cs.id, inp.claw])
		if inp.has("zone"):
			assert_true(Zones.find(inp.zone) != null, "%s: zona %s" % [cs.id, inp.zone])
		if inp.get("attack_deg") != null:
			var att: float = inp.attack_deg
			assert_true(att >= Attack.MIN_DEG and att <= Attack.MAX_DEG, "%s: ataque en su rango" % cs.id)
		assert_true(cs.expect is Dictionary and cs.expect.size() > 0, "%s: sin expectativas" % cs.id)
		# la referencia de la 1g (sin los materiales de la 2.0): expect1g si el caso se recalculó con la 2.0 completa
		var want: Dictionary = cs.get("expect1g", cs.expect)
		assert_true(want.size() > 0, "%s: sin expectativas de la 1g" % cs.id)
		var r := expected_result(inp)
		for field: String in want:
			_check(_at(r, field), want[field], "%s · %s" % [cs.id, field])


## Con el ataque por defecto (ausente o 90°), Attack.abrasion da en los sólidos exactamente la abrasión de la 1.x, y sin
## colmillo (sin esmalte) todo lo demás también: la 2.0 por defecto solo cambia donde hay hueso o esmalte.
func test_por_defecto_los_solidos_son_la_1x() -> void:
	for target_id in ["cobre", "acero", "madera", "plastico", "vidrio", "coche", "puertamadera", "puertametal"]:
		for over in [{ "geom": "stiletto", "force": 30.0 }, { "claw": "gato", "force": 15.0 },
				{ "claw": "aguila", "inlay": "acero", "force": 110.0 }, { "geom": "almendra", "inlay": "diamante", "force": 30.0 },
				{ "geom": "cuadrada", "force": 30.0, "passes": 20.0 }]:
			for attack in [null, 90.0]:
				var inp := {
					"geom": over.get("geom", "almendra"), "base": "natural", "inlay": over.get("inlay", "none"),
					"claw": over.get("claw"), "target": target_id, "type": "aranazo", "force": over.force, "length": 25.0,
					"tear": false, "method": "rayado", "strike": false, "passes": over.get("passes", 1.0), "wet": false,
					"model": "2.0", "attack_deg": attack,
				}
				var r := expected_result(inp)
				var r1 := Physics.compute(params_of(inp))
				var where := "%s sobre %s a %s" % [JSON.stringify(over), target_id, attack]
				for k in ["verdict", "depthUm", "ratio", "absMode", "fab", "muPlough", "muEff", "wearIdx", "pressure", "Ffric"]:
					assert_eq(r[k], r1[k], "%s: %s" % [where, k])
				assert_eq(r.tipHv, r1.hvTool, "%s: sin esmalte, la punta es la herramienta" % where)
				assert_eq(r.DpEff, r1.Dp, "%s: ataque por defecto" % where)
