## Casos de referencia del pulido del taller (tests/fixtures/spec/pulido-taller.json): el núcleo los cumple todos.
## Formato (CONTRATOS.md → «Especificaciones y casos de referencia»): { id, input: { fn, args }, expect: { campo:
## { value | min | max, tol } }, source }. `tol` es relativa; sin `tol`, igualdad exacta. Un campo con puntos
## ("sparks.length_mm", "kerf_band_mm.0") entra en diccionarios y listas. La guía está en docs/taller/pulido-taller.md.
extends "res://tests/case.gd"

const Cutting = preload("res://core/taller/cutting.gd")
const Wear = preload("res://core/taller/wear.gd")
const Chips = preload("res://core/taller/chips.gd")
const Radial = preload("res://core/taller/radial.gd")
const Sparks = preload("res://core/taller/sparks.gd")

const SPEC := "res://tests/fixtures/spec/pulido-taller.json"
const FNS := [
	"Cutting.specific_cutting_force", "Cutting.cutting_power_kw", "Cutting.turning", "Cutting.milling",
	"Cutting.drilling", "Cutting.cutting_model", "Wear.life", "Wear.after", "Wear.effects", "Wear.vb_at_fraction",
	"Chips.chip_breaking", "Chips.bue_risk", "Radial.disc_check", "Radial.cut_off", "Radial.cut_panel",
	"Sparks.stream_for",
]


## Llama a la función del núcleo de un caso. Las funciones que devuelven un número se envuelven en un diccionario.
static func run_case(input: Dictionary) -> Dictionary:
	var a: Dictionary = input.get("args", {})
	match str(input.get("fn", "")):
		"Cutting.specific_cutting_force":
			return Cutting.specific_cutting_force(a)
		"Cutting.cutting_power_kw":
			return { "pc_kw": Cutting.cutting_power_kw(a["fc_n"], a["vc"]) }
		"Cutting.turning":
			return Cutting.turning(a)
		"Cutting.milling":
			return Cutting.milling(a)
		"Cutting.drilling":
			return Cutting.drilling(a)
		"Cutting.cutting_model":
			return Cutting.cutting_model(a["work_id"], a["tool_id"], a["h_mm"], a["b_mm"], a["vc"])
		"Wear.life":
			return Wear.life(a["tool_id"], a["work_id"], a["vc"])
		"Wear.after":
			return Wear.after(a["t_min"], a["vc"], a["tool_id"], a["work_id"])
		"Wear.effects":
			return Wear.effects(a["vb_mm"])
		"Wear.vb_at_fraction":
			return { "vb_mm": Wear.vb_at_fraction(a["tau"]) }
		"Chips.chip_breaking":
			return Chips.chip_breaking(a)
		"Chips.bue_risk":
			return Chips.bue_risk(a)
		"Radial.disc_check":
			return Radial.disc_check(a)
		"Radial.cut_off":
			return Radial.cut_off(a)
		"Radial.cut_panel":
			return Radial.cut_panel(a)
		"Sparks.stream_for":
			return Sparks.stream_for(a["material_id"], a["vs_ms"])
	return {}


## Valor de un campo con puntos; { "missing": true } si no existe.
static func field(d: Variant, path: String) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		elif cur is Array and part.is_valid_int() and int(part) < (cur as Array).size():
			cur = cur[int(part)]
		else:
			return { "missing": true }
	return cur


func test_formato_de_los_casos() -> void:
	var cases: Array = load_json(SPEC)
	assert_true(cases.size() >= 30, "al menos 30 casos (%d)" % cases.size())
	var ids := {}
	for c in cases:
		for k in ["id", "input", "expect", "source"]:
			assert_true((c as Dictionary).has(k), "%s: clave «%s»" % [c.get("id", "?"), k])
		assert_false(ids.has(c["id"]), "id repetido: %s" % c["id"])
		ids[c["id"]] = true
		assert_true(FNS.has(str(c["input"].get("fn", ""))), "%s: función conocida" % c["id"])
		assert_true(str(c["source"]).length() > 20, "%s: con fuente" % c["id"])
		assert_false((c["expect"] as Dictionary).is_empty(), "%s: espera algo" % c["id"])
		for f in c["expect"]:
			var e: Dictionary = c["expect"][f]
			assert_true(e.has("value") or e.has("min") or e.has("max"), "%s.%s: value, min o max" % [c["id"], f])


func test_el_nucleo_cumple_los_casos() -> void:
	var cases: Array = load_json(SPEC)
	for c in cases:
		var got := run_case(c["input"])
		assert_false(got.is_empty(), "%s: la función devuelve algo" % c["id"])
		for f in c["expect"]:
			var e: Dictionary = c["expect"][f]
			var v: Variant = field(got, f)
			var what := "%s → %s" % [c["id"], f]
			if v is Dictionary and (v as Dictionary).has("missing"):
				fail("%s: no existe" % what)
				continue
			if e.has("value"):
				var want: Variant = e["value"]
				if is_num(want) and is_num(v):
					assert_near(float(v), float(want), float(e.get("tol", 0.0)), 0.0 if e.has("tol") else 1e-12, what)
				else:
					assert_eq(v, want, what)
			if e.has("min"):
				assert_true(is_num(v) and float(v) >= float(e["min"]), "%s ≥ %s (%s)" % [what, e["min"], v])
			if e.has("max"):
				assert_true(is_num(v) and float(v) <= float(e["max"]), "%s ≤ %s (%s)" % [what, e["max"], v])
