## Casos de referencia de la unidad 5a (tests/fixtures/spec/cetreria.json, docs/fisica/cetreria.md §7) contra
## core/lab/claw_care.gd: cada caso lleva su cálculo a mano en la nota.
## Formato: `expect` es { ruta con puntos dentro del resultado: { value | min | max, tol } }; `tol` es relativa; `value`
## sin `tol` exige igualdad exacta; `min` y `max` son inclusivos. Un caso que no se cumple no se ajusta: se averigua si el
## fallo es del código o de la especificación.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Spec = preload("res://tests/lab/test_velociraptor_spec.gd")

const SPEC := "res://tests/fixtures/spec/cetreria.json"
const KINDS := [
	"torno", "lesion", "dureza", "conductividad", "raja", "recorte", "pelado", "arranque", "muerde", "animal",
	"carga_lateral", "rebrote", "hemostasia", "calor_regimen",
]

var cases: Array = []


func before_each() -> void:
	if cases.is_empty():
		cases = load_json(SPEC)


## El resultado de un caso, con los nombres de campo del JSON.
static func run_case(inp: Dictionary) -> Dictionary:
	match String(inp.kind):
		"torno":
			var v := ClawCare.surface_speed_ms(float(CareData.TOOLS.torno.drum_mm), float(inp.rpm))
			return { "speedMs": v, "powerW": ClawCare.heat_power_w(float(inp.forceN), v) }
		"lesion":
			var out := {}
			for t: float in inp.temps:
				var s := ClawCare.injury_time_s(t)
				var key := "t" + _Js.js_num_str(t).replace(".", "_")
				if is_finite(s):
					out[key] = s
				else:
					out[key + "Finite"] = false
			return out
		"dureza":
			var out := {}
			for hum: String in CareData.HUMIDITY_IDS:
				out[hum] = ClawCare.hardness_mpa(float(inp.hv), hum)
			out["reforjada"] = ClawCare.hardness_mpa(float(inp.inlayHv), "empapada", true)
			return out
		"conductividad":
			return { "kWmK": ClawCare.keratin_conductivity() }
		"raja":
			var h := float(inp.halfMm)
			var g: Dictionary = CareData.TOOLS.guillotina
			var t: Dictionary = CareData.TOOLS.tijera
			var out := {}
			for hum: String in ["seca", "natural", "empapada"]:
				var k: Dictionary = CareData.keratin(hum)
				out[hum] = ClawCare.split_length_mm(float(k.e_gpa), h, float(g.wedge_mm), float(k.j_long))
			var kn: Dictionary = CareData.keratin("natural")
			out["tijera"] = ClawCare.split_length_mm(float(kn.e_gpa), h, float(t.wedge_mm), float(kn.j_long))
			return out
		"recorte":
			var c := ClawCare.new({ "animal": String(inp.animal) })
			var remove: float = c.overgrowth_left_mm() if typeof(inp.remove) == TYPE_STRING else float(inp.remove)
			var r := c.clip({ "tool": String(inp.tool), "remove_mm": remove })
			var sn := c.snapshot()
			r["flatMm"] = sn.tip.flatMm
			r["quickCoverMm"] = sn.claw.quickCoverMm
			r["maxPain"] = sn.animal.maxPain
			r["verdict"] = c.report().verdict
			return r
		"pelado":
			var out := { "gKJm2": ClawCare.peel_energy_kj_m2(float(inp.mu), float(inp.forceN), float(inp.widthMm)) }
			for hum: String in ["seca", "natural", "empapada"]:
				out[hum] = ClawCare.interlaminar_kj_m2(hum)
			return out
		"arranque":
			var tool_d := CareData.tool(String(inp.tool))
			var h := ClawCare.hardness_mpa(float(inp.clawHv), String(inp.humidity))
			var w := float(inp.widthMm)
			var l := float(inp.lengthMm)
			var out := ClawCare.element_cut(tool_d, float(inp.forceN), w, l, h)
			out["removalMm3"] = ClawCare.removal_mm3(tool_d, float(inp.forceN), float(inp.travelMm), w, l, float(inp.clawHv), h)
			return out
		"muerde":
			var out := {}
			var i := 0
			for pr: Array in inp.pairs:
				out["eta%d" % i] = Contact.hardness_efficiency(float(pr[0]) / float(pr[1]))
				i += 1
			return out
		"animal":
			var out := {}
			for aid: String in inp.animals:
				var sn := ClawCare.new({ "animal": aid }).snapshot()
				out[aid] = {
					"startMm": sn.claw.startMm, "quickMm": sn.claw.quickMm, "baseRadiusMm": sn.claw.baseRadiusMm,
					"tipRadiusUm": sn.tip.tipRadiusUm, "naturalMm": sn.claw.naturalMm,
				}
			return out
		"carga_lateral":
			var st := ClawCare.keratin_strength("natural")
			var out := {}
			var i := 0
			for pr: Array in inp.cases:
				out["n%d" % i] = ClawCare.lateral_capacity_n(float(pr[0]), float(pr[1]), st)
				i += 1
			out["ratio"] = float(out.n1) / float(out.n0)
			return out
		"rebrote":
			var c := ClawCare.new({ "animal": String(inp.animal) })
			c.clip({ "tool": "guillotina", "remove_mm": c.overgrowth_left_mm() + float(inp.belowNaturalMm) })
			var rg: Variant = c.report().regrow
			return {
				"days": rg.days if rg != null else null,
				"brokenDays": CareData.ANIMALS[String(inp.animal)].regrow_days.value,
			}
		"hemostasia":
			var a := ClawCare.new({ "animal": "rapaz" })
			a._cut_to(a.apex_mm() - a.quick_cover_mm() - 0.5)
			var b := ClawCare.new({ "animal": "rapaz" })
			b._cut_to(b.apex_mm() - b.quick_cover_mm() - 0.5)
			var c := ClawCare.new({ "animal": "rapaz" })
			c._cut_to(c.apex_mm() - c.quick_cover_mm() - 0.5)
			c.advance(599.0)
			var still := bool(c.snapshot().bleeding.active)
			c.advance(2.0)
			return {
				"agentNeedS": a.hemostasis({ "tool": "hemostatico", "pressure_s": 0.0 }).needS,
				"pressureNeedS": b.hemostasis({ "tool": "", "pressure_s": 0.0 }).needS,
				"stillBleedingAt599": still, "stoppedAt601": not bool(c.snapshot().bleeding.active),
			}
		"calor_regimen":
			var c := ClawCare.new({ "animal": "rapaz" })
			c._flank_contact_mm2 = float(inp.areaMm2)
			c._run(float(inp.seconds), float(inp.powerW), "flanco", float(inp.sMm), 0.5)
			var sn := c.snapshot()
			return { "faceC": sn.thermal.faceC, "quickC": sn.thermal.quickC, "cells": (sn.thermal.cells as PackedFloat64Array).size() }
	return {}


func test_el_formato_de_los_casos() -> void:
	assert_true(cases.size() >= 15, "casos: %d" % cases.size())
	var ids := {}
	for c: Dictionary in cases:
		assert_false(ids.has(c.id), "%s: id único" % c.id)
		ids[c.id] = true
		assert_true(KINDS.has(String(c.input.get("kind", ""))), "%s: tipo de caso conocido" % c.id)
		assert_true(String(c.get("note", "")).length() > 40, "%s: nota que explica el caso" % c.id)
		assert_true(String(c.get("source", "")).length() > 20, "%s: fuente" % c.id)
		assert_true(c.expect.size() > 0, "%s: algo que comprobar" % c.id)


func test_los_casos_de_referencia() -> void:
	for c: Dictionary in cases:
		var got := run_case(c.input)
		assert_true(not got.is_empty(), "%s: el caso se calcula" % c.id)
		for path: String in c.expect:
			var why := Spec.mismatch(Spec.at_path(got, path), c.expect[path])
			assert_true(why == "", "%s · %s: %s" % [c.id, path, why])


func test_los_datos_del_caso_coinciden_con_el_catalogo() -> void:
	# los cálculos a mano usan estos números: si cambian los datos, hay que rehacer los casos
	assert_eq(float(CareData.TOOLS.torno.drum_mm), 12.7, "tambor de 12,7 mm")
	assert_eq(float(CareData.THERMAL.partition.value), 0.5, "ε = 0,5")
	assert_eq(float(CareData.THERMAL.friction.value), 0.325, "μ = 0,325")
	assert_eq(float(CareData.THERMAL.h_air.value), 15.0, "h = 15 W/(m²·K)")
	assert_eq(float(CareData.TOOLS.guillotina.wedge_mm), 0.3, "cuña de la guillotina")
	assert_eq(float(CareData.TOOLS.tijera.wedge_mm), 0.6, "cuña de la tijera")
	assert_eq(float(CareData.TOOLS.lima_bastarda.teeth_cm), 13.0, "bastarda: 13 dientes/cm")
	assert_eq(float(CareData.TOOLS.lija_p180.grain_um), 77.2, "P180")
	assert_eq(float(CareData.TOOLS.torno.grain_um), 258.0, "grano 60")
	assert_eq(float(CareData.INTERLAMINAR.value), 0.25, "entre capas, un cuarto")
	assert_eq(float(CareData.ANIMALS.rapaz.growth_mm_day.value), 0.04, "0,04 mm/día")
	assert_eq(float(CareData.ANIMALS.tigre.growth_mm_day.value), 0.13, "0,13 mm/día")
	assert_eq(float(CareData.ANIMALS.oso.growth_mm_day.value), 0.27, "0,27 mm/día")
	assert_eq(float(CareData.CORE_RATIO.value), 0.699, "0,699 del estuche")
	assert_eq(CareData.DEFAULT_OVERGROWTH_DAYS, 90.0, "90 días")
	var eagle := CareData.claw_entry("aguila")
	assert_eq([float(eagle.hv), float(eagle.area), float(eagle.alpha), float(eagle.reach)], [32.0, 0.04, 15.0, 35.0], "la garra del águila del banco")
