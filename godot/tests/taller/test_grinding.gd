## Taller · física del amolado a mano (grinding.gd): velocidad, fuerzas, potencia, reparto del calor, energía
## específica, motor, abrasivo contra material, contacto del bisel, chispas, sonido y la geometría de los errores de
## afilado de brocas y fresas. Invariantes y valores de las fuentes (docs/taller/afilado-simulador.md).
extends "res://tests/case.gd"

const G = preload("res://core/taller/grinding.gd")
const S = preload("res://core/taller/sharpening.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")
const Js = preload("res://core/shared/js.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


func _grind(extra: Dictionary) -> Dictionary:
	var p := { "machine_id": "einhell_tc_bg_150", "wheel": "fino", "force_n": 10.0, "contact_area_mm2": 16.0, "steel_id": "x50crmov15" }
	p.merge(extra, true)
	return G.grind(p)


func test_velocidad_periferica() -> void:
	assert_near(G.peripheral_speed(150.0, 2980.0), 23.4049, 1e-5, 0.0, "150 mm a 2980 rpm (Einhell: 23,4 m/s)")
	assert_eq(G.peripheral_speed(200.0, 3450.0), S.peripheral_speed(200.0, 3450.0), "la misma fórmula que sharpening.gd")
	var r := _grind({ "force_n": 1e-6 })
	assert_near(r["vs_ms"], 23.4049, 1e-4, 0.0, "casi sin fuerza, la muela va a su velocidad de vacío")


func test_fuerzas_y_potencia() -> void:
	var f := G.forces(10.0)
	assert_near(f["ft_n"], 3.25, 1e-12, 0.0, "Ft = 0,325·Fn (Biro et al. 2019)")
	assert_near(f["ft_min_n"], 2.5, 1e-12, 0.0)
	assert_near(f["ft_max_n"], 4.0, 1e-12, 0.0)
	var r := _grind({})
	assert_near(r["power_w"], float(r["ft_n"]) * float(r["vs_ms"]), 1e-12, 0.0, "P = Ft·v")
	assert_true(float(r["power_min_w"]) < float(r["power_w"]) and float(r["power_w"]) < float(r["power_max_w"]), "la potencia central dentro de su banda")
	assert_near(r["heat_w"], float(r["partition"]) * float(r["power_w"]), 1e-12, 0.0, "calor = ε·P")
	assert_near(r["heat_flux_w_m2"], float(r["heat_w"]) / 16e-6, 1e-12, 0.0, "q = ε·P/A")
	assert_near(r["removal_mm3_s"], float(r["power_w"]) / 90.0, 1e-12, 0.0, "Q = P/u con u = 90 J/mm³ en acero templado")
	assert_near(G.forces(10.0, 0.5)["ft_n"], 5.0, 1e-12, 0.0, "μ del usuario")
	assert_eq(G.forces(NAN)["fn_n"], 0.0, "una fuerza que no es un número cuenta como 0")


func test_mas_fuerza_y_mas_velocidad_mas_calor() -> void:
	var prev_q := -1.0
	var prev_rem := -1.0
	for f in [1.0, 3.0, 5.0, 10.0, 15.0, 20.0]:
		var r := _grind({ "force_n": f })
		assert_true(float(r["heat_flux_w_m2"]) > prev_q, "más fuerza, más calor (%s N)" % Js.js_num_str(f))
		assert_true(float(r["removal_mm3_s"]) > prev_rem, "y más arranque")
		prev_q = float(r["heat_flux_w_m2"])
		prev_rem = float(r["removal_mm3_s"])
	var slow := _grind({ "machine_id": "vevor_md150_4", "wheel": "fino" })
	var fast := _grind({ "machine_id": "vevor_md150g_450", "wheel": "fino" })
	assert_true(float(fast["heat_flux_w_m2"]) > 1.8 * float(slow["heat_flux_w_m2"]), "a 3450 rpm, casi el doble de calor que a 1750")
	var te_slow := _grind({ "machine_id": "einhell_te_ag_125_ce", "wheel": "laminas", "rpm": 3000.0 })
	var te_fast := _grind({ "machine_id": "einhell_te_ag_125_ce", "wheel": "laminas", "rpm": 12000.0 })
	assert_near(float(te_fast["heat_flux_w_m2"]) / float(te_slow["heat_flux_w_m2"]), 4.0, 1e-9, 0.0, "velocidad constante: 4 veces las rpm, 4 veces el calor")


func test_reparto_del_calor() -> void:
	var dry := G.partition("al2o3")
	assert_near(dry["value"], 0.725, 1e-12, 0.0, "corindón en seco: 72,5 % (Malkin y Guo 2007)")
	assert_near(dry["min"], 0.60, 1e-12, 0.0)
	assert_near(dry["max"], 0.85, 1e-12, 0.0)
	var wet := G.partition("al2o3", true, 40.0)
	assert_near(wet["value"], 0.725 * 0.42, 1e-12, 0.0, "en húmedo y por debajo de la ebullición, × 0,42")
	assert_true(wet["coolant_effective"])
	var boiling := G.partition("al2o3", true, 131.0)
	assert_false(boiling["coolant_effective"], "por encima de 130 °C el agua ya no enfría")
	assert_near(boiling["value"], 0.725, 1e-12, 0.0)
	var cbn := G.partition("cbn")
	assert_near(cbn["value"], 0.20, 1e-12, 0.0, "CBN: ≈20 %")
	assert_true(float(cbn["max"]) <= 0.5 + 1e-12 and float(cbn["min"]) < float(cbn["value"]), "con su banda hasta el 50 % de Rowe")
	assert_eq(G.partition("")["abrasive_id"], "al2o3", "una muela sin grano declarado se toma como corindón")
	assert_true(float(G.partition("cbn")["value"]) < float(G.partition("al2o3")["value"]), "el CBN mete menos calor en la herramienta")


func test_energia_especifica() -> void:
	var hard := G.specific_energy("x50crmov15")
	assert_eq(hard["regime"], "templado")
	assert_eq(hard["value"], 90.0)
	assert_true(float(hard["min"]) <= 62.0 and float(hard["max"]) >= 200.0, "banda de Rowe et al. (62–200 J/mm³)")
	var soft := G.specific_energy("", 40.0)
	assert_eq(soft["regime"], "blando", "una cuchilla de cortacésped de 40 HRC")
	assert_true(float(soft["value"]) < float(hard["value"]), "el acero blando cuesta menos energía por mm³")
	assert_eq(G.specific_energy("metal_duro")["regime"], "templado")


func test_motor_se_frena_y_se_cala() -> void:
	var prev := INF
	for f in [1.0, 5.0, 10.0, 15.0, 20.0, 25.0]:
		var r := _grind({ "force_n": f })
		assert_true(float(r["rpm"]) < prev, "más fuerza, menos rpm (%s N)" % Js.js_num_str(f))
		prev = float(r["rpm"])
	var light := _grind({ "force_n": 5.0 })
	assert_false(light["overloaded"])
	var heavy := _grind({ "force_n": 20.0 })
	assert_true(heavy["overloaded"] and not heavy["stalled"], "con 20 N la TC-BG 150 de 150 W se frena")
	assert_true(_codes(heavy).has("se_frena"))
	var stall := _grind({ "force_n": 40.0 })
	assert_true(stall["stalled"], "con 40 N se cala")
	assert_eq(stall["power_w"], 0.0, "y parada no amuela")
	assert_true(_codes(stall).has("se_cala"))
	for mid in ["tormek_t8", "einhell_tc_wg_200", "vevor_scm8082"]:
		var slow := G.grind({ "machine_id": mid, "force_n": 100.0, "contact_area_mm2": 40.0, "steel_id": "x50crmov15" })
		assert_false(slow["stalled"] or slow["overloaded"], "%s: con reductora, la mano no la para" % mid)
	var cte := G.motor_state(Machines.MACHINES["einhell_te_ag_125_ce"]["motor"], 12000.0, 0.1)
	assert_eq(cte["rpm"], 12000.0, "con electrónica constante no cae el giro con poca carga")


func test_nunca_diamante_para_acero() -> void:
	var bad := 0
	for mid in Machines.MACHINES:
		for w in Machines.MACHINES[mid]["wheels"]:
			for steel in Heat.STEELS:
				var r := G.grind({ "machine_id": mid, "wheel": w["id"], "force_n": 5.0, "contact_area_mm2": 10.0, "steel_id": steel })
				if str(w["abrasive_id"]) == "diamante" and not _codes(r).has("diamante_acero"):
					bad += 1
				if str(w["abrasive_id"]) != "diamante" and _codes(r).has("diamante_acero"):
					bad += 1
	assert_eq(bad, 0, "toda muela de diamante con acero avisa, y ninguna otra")
	var carbide := G.grind({ "machine_id": "mrcm_mr_x3", "wheel": "sdc", "force_n": 5.0, "contact_area_mm2": 10.0, "steel_id": "metal_duro" })
	assert_eq(_codes(carbide).size(), 0, "el metal duro con diamante, sin avisos")
	var cbn_carbide := G.grind({ "machine_id": "mrcm_mr_x3", "wheel": "cbn", "force_n": 5.0, "contact_area_mm2": 10.0, "steel_id": "metal_duro" })
	assert_true(_codes(cbn_carbide).has("abrasivo_metal_duro"), "el metal duro no se amola con CBN")


func test_contacto_del_bisel() -> void:
	var c := G.knife_contact({ "per_side_deg": 17.5, "thickness_mm": 0.6, "contact_len_mm": 16.0, "wheel_diameter_mm": 150.0 })
	assert_near(c["face_width_mm"], S.bevel_width(0.6, 17.5), 1e-12, 0.0, "la cara del bisel de sharpening.gd: (t/2)/sen β")
	assert_near(c["area_mm2"], float(c["face_width_mm"]) * 16.0, 1e-12, 0.0)
	var r := 75.0
	var half := float(c["face_width_mm"]) / 2.0
	assert_near(c["hollow_um"], (r - sqrt(r * r - half * half)) * 1000.0, 1e-9, 0.0, "flecha del vaciado cóncavo de la periferia")
	assert_true(float(c["hollow_um"]) < 5.0, "con una muela de 150 mm el vaciado es de micras")
	var single := G.edge_contact({ "side_a_deg": 30.0, "side_b_deg": 0.0, "shoulder_mm": 3.0 })
	assert_near(single["face_width_mm"], 3.0 / sin(deg_to_rad(30.0)), 1e-9, 0.0, "bisel de un lado: t/sen a")
	assert_eq(G.knife_contact({ "mode": "cara" })["hollow_um"], 0.0, "en la cara de la muela no hay vaciado")
	assert_near(G.bevel_recession_um_s(0.8, 16.0), 50.0, 1e-9, 0.0, "0,8 mm³/s en 16 mm²: la cara retrocede 50 µm/s")


func test_costado_de_la_muela() -> void:
	assert_true(_codes(_grind({ "mode": "cara" })).has("costado_muela"), "no amolar con el costado de una muela recta (ANSI B7.1)")
	assert_false(_codes(_grind({})).has("costado_muela"))


func test_giro_regulable_y_fijo() -> void:
	var r := _grind({ "machine_id": "einhell_te_ag_125_ce", "wheel": "laminas", "rpm": 7000.0 })
	assert_true(float(r["rpm_no_load"]) in [6000.0, 8000.0], "la amoladora va a la posición más cercana de su rueda (6000 u 8000)")
	var fixed := _grind({ "rpm": 1500.0 })
	assert_eq(fixed["rpm_no_load"], 2980.0, "la TC-BG 150 no se regula")
	assert_true(_codes(fixed).has("giro_fijo"))
	var worn := _grind({ "diameter_mm": 130.0, "force_n": 1e-6 })
	assert_near(worn["vs_ms"], S.peripheral_speed(130.0, 2980.0), 1e-6, 0.0, "muela gastada: el mismo giro y menos velocidad")
	assert_true(_codes(_grind({ "diameter_mm": 120.0 })).has("muela_gastada"), "por debajo de 127 mm hay que cambiarla")
	assert_true(_codes(_grind({ "diameter_mm": 170.0 })).has("diametro"), "no se monta una muela mayor")


func test_chispas() -> void:
	var dry := _grind({ "steel_id": "1095" })
	assert_true(float(dry["sparks"]["sparks"]["rate"]) > 0.0, "el acero al carbono chispea en el banco")
	var wet := G.grind({ "machine_id": "tormek_t8", "force_n": 10.0, "contact_area_mm2": 40.0, "steel_id": "1095" })
	assert_eq(wet["sparks"]["sparks"]["rate"], 0.0, "en la muela húmeda lenta no hay chispas")
	assert_true(float(_grind({ "steel_id": "1095", "force_n": 15.0 })["sparks"]["sparks"]["rate"]) > float(dry["sparks"]["sparks"]["rate"]), "más arranque, más chispas")
	assert_eq(G.spark_input("aluminio", 1.0, 20.0, false)["sparks"]["rate"], 0.0, "el aluminio no chispea")
	assert_eq(dry["sparks"]["family"], "acero_alto_c")


func test_entrada_de_sonido() -> void:
	var r := _grind({})
	var s: Dictionary = r["sound"]
	for key in ["process", "rpm", "teeth", "jaws", "pc_kw", "pmax_kw", "work_kind", "chatter", "coolant", "tool_pos"]:
		assert_true(s.has(key), "la entrada de sonido trae %s (CONTRATOS.md)" % key)
	assert_eq(s["process"], "sharpener")
	assert_eq(G.sound_input("einhell_te_ag_125_ce", 12000.0, 100.0, false)["process"], "grinder", "la amoladora suena como la radial")
	assert_eq(G.sound_input("einhell_te_ag_125_ce", 12000.0, 100.0, false)["disc_id"], "laminas")
	var frame: Dictionary = MachineSound.frame(s)
	assert_true(frame.has("tones") and float(frame["rpm"]) > 0.0, "machine_sound.gd acepta la entrada")
	assert_eq(s["rpm"], 2980.0, "la entrada lleva el giro sin carga: la caída la pone machine_sound.gd")
	assert_near(frame["rpm"], r["rpm"], 0.01, 0.0, "y suena al giro que da el modelo de motor (sin caída doble)")
	var stalled := _grind({ "force_n": 40.0 })
	assert_eq(stalled["sound"]["rpm"], 0.0, "calada, la muela no gira")


func test_broca_labios_desiguales() -> void:
	var o := G.drill_point_offset({ "diameter_mm": 10.0, "point_deg": 118.0, "lip_height_diff_mm": 0.1 })
	assert_near(o["offset_mm"], 0.1 * tan(deg_to_rad(59.0)) / 2.0, 1e-12, 0.0, "e = Δh·tan p/2")
	assert_near(o["oversize_mm"], 2.0 * float(o["offset_mm"]), 1e-15, 0.0, "agujero D + 2e")
	assert_near(o["lip_length_diff_mm"], 2.0 * float(o["offset_mm"]) / sin(deg_to_rad(59.0)), 1e-12, 0.0, "ΔL = 2e/sen p")
	var by_len := G.drill_point_offset({ "diameter_mm": 10.0, "point_deg": 118.0, "lip_length_diff_mm": o["lip_length_diff_mm"] })
	assert_near(by_len["offset_mm"], o["offset_mm"], 1e-12, 0.0, "por la longitud de los labios da lo mismo")
	assert_true(o["within_tolerance"], "0,1 mm cumple hasta 1/2″ (0,004″, US 4031672)")
	assert_false(G.drill_point_offset({ "diameter_mm": 5.0, "lip_height_diff_mm": 0.1 })["within_tolerance"], "hasta 1/4″ la tolerancia es 0,003″")
	assert_eq(G.lip_height_tolerance_mm(20.0), null, "sin dato por encima de 1/2″")
	var prev := -1.0
	for dh in [0.0, 0.02, 0.05, 0.1, 0.2]:
		var ov: float = G.drill_point_offset({ "diameter_mm": 8.0, "lip_height_diff_mm": dh })["oversize_mm"]
		assert_true(ov > prev, "más diferencia, más agujero (%s mm)" % Js.js_num_str(dh))
		prev = ov
	assert_eq(G.drill_point_offset({ "diameter_mm": 8.0 })["oversize_mm"], 0.0, "labios iguales, agujero justo")


func test_broca_incidencia_efectiva_y_arista() -> void:
	assert_near(G.effective_clearance(8.0, 0.2, 0.5), 8.0 - rad_to_deg(atan(0.2 / (TAU * 0.5))), 1e-12, 0.0)
	assert_true(G.effective_clearance(8.0, 0.2, 0.5) < G.effective_clearance(8.0, 0.2, 5.0), "hacia el centro queda menos incidencia (US 4561813)")
	assert_true(G.effective_clearance(8.0, 0.1, 5.0) > 7.6, "en la periferia de una broca de 10 mm el avance casi no cuenta")
	assert_eq(G.chisel_angle_deg(5.0), 110.0, "Mazoff: 110° ≈ 5°")
	assert_near(G.chisel_angle_deg(8.0), 120.0, 1e-12, 0.0, "120° ≈ 8°")
	assert_near(G.chisel_angle_deg(11.0), 130.0, 1e-12, 0.0, "130° ≈ 11°")
	assert_near(G.clearance_from_chisel_deg(G.chisel_angle_deg(9.3)), 9.3, 1e-12, 0.0, "ida y vuelta")
	assert_eq(G.lip_wedge_deg(10.0), 50.0, "cuña del labio = 90° − 10° − 30°")
	assert_true(G.lip_wedge_deg(20.0) < G.lip_wedge_deg(8.0), "más incidencia, cuña más débil")


func test_broca_revision() -> void:
	var good := G.drill_check({ "diameter_mm": 10.0, "point_deg": 118.0, "clearance_deg": 10.0, "work_material": "acero" })
	assert_true(good["ok"])
	assert_eq(good["findings"][0]["code"], "bien")
	var low := G.drill_check({ "diameter_mm": 10.0, "clearance_deg": 4.0 })
	assert_false(low["ok"])
	assert_true(_fcodes(low).has("poca_incidencia"))
	var high := G.drill_check({ "diameter_mm": 10.0, "clearance_deg": 18.0 })
	assert_true(_fcodes(high).has("mucha_incidencia"))
	var lips := G.drill_check({ "diameter_mm": 10.0, "clearance_deg": 10.0, "lip_height_diff_mm": 0.2 })
	assert_true(_fcodes(lips).has("labios_desiguales"))
	var flat := G.drill_check({ "diameter_mm": 10.0, "point_deg": 140.0, "clearance_deg": 10.0, "work_material": "acero" })
	assert_true(_fcodes(flat).has("punta_plana"), "140° en acero: demasiado plana")
	var inox := G.drill_check({ "diameter_mm": 10.0, "point_deg": 135.0, "clearance_deg": 10.0, "work_material": "inox" })
	assert_false(_fcodes(inox).has("punta_plana"), "135° es lo recomendado en inox")
	var fed := G.drill_check({ "diameter_mm": 3.0, "clearance_deg": 8.0, "feed_mm_rev": 0.2 })
	var eff: Dictionary = fed["effective_clearance_deg"]
	assert_near(eff["inner"], 8.0 - rad_to_deg(atan(0.2 / (TAU * 0.3))), 1e-12, 0.0, "la incidencia efectiva se mide a 0,1·D del eje")
	assert_true(float(eff["inner"]) < float(eff["outer"]) and float(eff["inner"]) > 0.0, "con 0,2 mm/v todavía queda algo junto al centro")
	var small := G.drill_check({ "diameter_mm": 3.0, "clearance_deg": 8.0, "feed_mm_rev": 0.3 })
	assert_true(float(small["effective_clearance_deg"]["inner"]) < 0.0, "con 0,3 mm/v se come toda la incidencia junto al centro")
	assert_true(_fcodes(small).has("poca_incidencia"), "8° en una broca de 3 mm con un avance exagerado: el talón roza junto al centro")
	assert_false(small["ok"])


func test_fresa_revision_y_desplazamiento() -> void:
	var m := G.mill_check({ "diameter_mm": 10.0, "work_material": "acero" })
	assert_eq(m["findings"][0]["code"], "bien", "con los ángulos recomendados")
	assert_near(m["offset_mm"], S.cutter_grinder_offset(7.0, 10.0), 1e-15, 0.0, "desplazamiento de TC 9-524 con muela de copa")
	var straight := G.mill_check({ "diameter_mm": 10.0, "wheel": "recta", "wheel_diameter_mm": 150.0 })
	assert_near(straight["offset_mm"], S.cutter_grinder_offset(7.0, 150.0), 1e-15, 0.0, "con muela recta manda el diámetro de la muela")
	assert_true(_fcodes(G.mill_check({ "diameter_mm": 10.0, "primary_deg": 2.0 })).has("poca_incidencia"))
	assert_true(_fcodes(G.mill_check({ "diameter_mm": 10.0, "primary_deg": 15.0, "secondary_deg": 20.0 })).has("mucha_incidencia"))
	assert_true(_fcodes(G.mill_check({ "diameter_mm": 10.0, "primary_deg": 7.0, "secondary_deg": 6.0 })).has("secundaria"))


func test_entradas_raras() -> void:
	var unknown := G.grind({ "machine_id": "piedra_filosofal" })
	assert_eq(unknown["vs_ms"], 0.0)
	assert_true(_codes(unknown).has("sin_datos"))
	assert_eq(unknown["sparks"]["sparks"]["rate"], 0.0, "máquina desconocida: los campos existen, sin chispas")
	var ref := _grind({})
	for key in ref:
		assert_true(unknown.has(key), "la salida vacía trae también «%s»" % key)
	var odd := _grind({ "force_n": -5.0, "contact_area_mm2": -1.0, "wet": "sí", "wheel": "inexistente" })
	assert_true(is_finite(float(odd["heat_flux_w_m2"])), "entradas absurdas no rompen el cálculo")
	assert_eq(odd["power_w"], 0.0, "fuerza negativa: nada")
	assert_true(odd["wet"], "«sí» se lee como sí")
	assert_true(_codes(odd).has("muela"))


func test_todas_las_tablas_con_fuente_y_calidad() -> void:
	var bad: Array[String] = []
	for name in ["FORCE_RATIO"]:
		_check_entry(G.FORCE_RATIO, name, bad)
	for table in [G.HAND_FORCE, G.SPECIFIC_ENERGY, G.PARTITION_BAND, G.MOTORS]:
		for key in table:
			_check_entry(table[key], str(key), bad)
	assert_eq(bad.size(), 0, "; ".join(bad))
	for key in G.HAND_FORCE:
		assert_eq(G.HAND_FORCE[key]["quality"], "estimate", "%s: no hay medida de la fuerza de la mano" % key)
	var r := _grind({})
	assert_true(r["sources"].size() >= 4 and r["quality"] == "estimate", "el paso de amolado cita sus fuentes y es una estimación")


# --- utilidades ---


func _codes(r: Dictionary) -> Array:
	var out: Array = []
	for w in r.get("warnings", []):
		out.append(str(w["code"]))
	return out


func _fcodes(r: Dictionary) -> Array:
	var out: Array = []
	for f in r.get("findings", []):
		out.append(str(f["code"]))
	return out


func _check_entry(e: Dictionary, name: String, bad: Array[String]) -> void:
	if str(e.get("source", "")) == "":
		bad.append(name + ": sin fuente")
	if not QUALITIES.has(e.get("quality")):
		bad.append(name + ": calidad no válida")
	if e.has("value") and e.has("min") and e.has("max") and not (float(e["min"]) <= float(e["value"]) and float(e["value"]) <= float(e["max"])):
		bad.append(name + ": valor fuera de su intervalo")
