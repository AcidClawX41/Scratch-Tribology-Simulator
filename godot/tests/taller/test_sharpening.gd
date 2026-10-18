## Taller · afiladora (unidad 7): ángulos, abrasivo, velocidad de la muela, granos, riesgo térmico,
## Hollomon–Jaffe e ISO 8442-5. Invariantes y valores de las fuentes (docs/taller/fuentes-u7.md).
extends "res://tests/case.gd"

const S = preload("res://core/taller/sharpening.gd")
const H = preload("res://core/taller/sharpening_heat.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Js = preload("res://core/shared/js.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const LEVELS := ["bajo", "medio", "alto", "quemado"]
const KINDS := ["cuchillo", "broca", "fresa"]
const WORKS := ["acero", "acero_duro", "inox", "aluminio", "laton", "fundicion", "plastico", "titanio"]
## Los cinco casos del e2e de la unidad.
const E2E := [
	{ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15", "style": "occidental", "use": "cocina", "thickness_mm": 0.6 }, "machine_id": "tormek_t8" },
	{ "tool": { "kind": "cuchillo", "steel_id": "vg10", "style": "japones", "use": "cocina", "thickness_mm": 0.5 }, "machine_id": "tormek_t8" },
	{ "tool": { "kind": "cuchillo", "steel_id": "14c28n", "use": "caza", "thickness_mm": 0.8 }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 2980.0 },
	{ "tool": { "kind": "broca", "steel_id": "m2", "diameter_mm": 10.0, "work_material": "inox" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 2980.0 },
	{ "tool": { "kind": "fresa", "steel_id": "metal_duro", "diameter_mm": 10.0, "work_material": "aluminio" }, "machine_id": "afiladora_universal" },
]

var _requests: Array = []


func before_each() -> void:
	if _requests.is_empty():
		_requests = _all_requests()


func test_velocidad_periferica_y_aviso_por_exceso() -> void:
	var v := S.peripheral_speed(200.0, 3450.0)
	assert_eq(Js.to_fixed(v, 1), "36.1", "muela de 200 mm a 3450 rpm")
	assert_true(v > 35.0, "por encima de los 35 m/s de una muela vitrificada")
	var r := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 3450.0 })
	assert_eq(r["abrasive_id"], "al2o3")
	assert_true(r["over_speed"], "avisa del exceso de velocidad")
	assert_eq(r["max_speed_ms"], 35.0)
	assert_true(_has_warning(r, "35 m/s"), "el aviso cita los 35 m/s")
	var ok := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 150.0, "rpm": 2980.0 })
	assert_eq(Js.to_fixed(ok["speed_ms"], 1), "23.4", "muela de 150 mm a 2980 rpm")
	assert_false(ok["over_speed"], "23,4 m/s no pasan del máximo")
	# El aviso depende de la muela montada, no del abrasivo recomendado
	var drill := S.recommend_sharpening({ "tool": { "kind": "broca", "steel_id": "m2" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 3450.0 })
	assert_eq(drill["abrasive_id"], "cbn")
	assert_true(drill["over_speed"], "con la muela vitrificada de serie, 36,1 m/s es un peligro aunque se recomiende CBN")
	var cbn := S.recommend_sharpening({ "tool": { "kind": "broca", "steel_id": "m2" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 3450.0, "wheel_abrasive_id": "cbn" })
	assert_false(cbn["over_speed"], "con una muela de CBN montada manda la velocidad marcada en ella")
	assert_true(_has_warning(cbn, "velocidad máxima marcada"), "y se pide mirarla")
	var universal := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15" }, "machine_id": "afiladora_universal", "rpm": 12000.0 })
	assert_true(universal["over_speed"], "una muela de WA en la afiladora universal también tiene máximo")
	assert_eq(Js.to_fixed(S.rpm_for_speed(S.peripheral_speed(173.0, 3111.0), 173.0), 6), "3111.000000", "rpm ↔ m/s")


func test_tormek_t8_de_90_a_100_rpm() -> void:
	assert_eq(Js.to_fixed(S.peripheral_speed(250.0, 90.0), 2), "1.18")
	assert_eq(Js.to_fixed(S.peripheral_speed(250.0, 100.0), 2), "1.31")
	for rpm in [90.0, 95.0, 100.0]:
		var r := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15" }, "machine_id": "tormek_t8", "rpm": rpm })
		assert_near(r["speed_ms"], S.peripheral_speed(250.0, rpm), 1e-12, 0.0, "velocidad a %d rpm" % int(rpm))
		assert_false(r["over_speed"])
		assert_true(r["machine"]["wet"], "el Tormek afila en húmedo")
		assert_true(r["speed_ms"] >= r["speed_range_ms"]["min"] - 1e-12 and r["speed_ms"] <= r["speed_range_ms"]["max"] + 1e-12, "dentro de su intervalo")
		assert_false(_has_warning(r, "rpm"), "90–100 rpm es lo de serie")
	var span: Dictionary = S.recommend_sharpening({ "tool": { "kind": "cuchillo" }, "machine_id": "tormek_t8" })["speed_range_ms"]
	assert_eq(Js.to_fixed(span["min"], 2), "1.18")
	assert_eq(Js.to_fixed(span["max"], 2), "1.31")
	var fast := S.recommend_sharpening({ "tool": { "kind": "cuchillo" }, "machine_id": "tormek_t8", "rpm": 150.0 })
	assert_true(_has_warning(fast, "rpm"), "fuera de 90–100 rpm avisa")
	assert_true(_has_warning(fast, "de serie de la máquina"), "y compara con la velocidad de serie, no con la de un abrasivo")
	var worn := S.recommend_sharpening({ "tool": { "kind": "cuchillo" }, "machine_id": "tormek_t8", "wheel_diameter_mm": 200.0, "rpm": 90.0 })
	assert_near(worn["rpm_range"]["min"], 90.0, 1e-9, 0.0, "con la muela gastada, el intervalo sigue siendo de 90–100 rpm")
	assert_false(_has_warning(worn, "más despacio"), "y no avisa de ir despacio por tener la muela gastada")


func test_desplazamiento_en_la_afiladora_de_fresas() -> void:
	assert_eq(Js.to_fixed(S.cutter_grinder_offset(7.0, 25.4), 3), "1.565", "7° con una fresa de 25,4 mm")
	assert_near(S.cutter_grinder_offset(5.0, 6.0), 0.264, 1e-12, 1e-15, "ejemplo de TC 9-524: 0,0088 × 5 × 6 = 0,264")
	var rule := S.cutter_grinder_offset(7.0, 25.4)
	var exact := S.cutter_grinder_offset_exact(7.0, 25.4)
	assert_true(exact < rule and rule / exact - 1.0 < 0.02, "la regla aproxima (D/2)·sen α por arriba en menos de un 2 %")
	var m := S.mill_angles({ "work_material": "aluminio", "diameter_mm": 10.0 })
	assert_near(m["offset_mm"]["value"], S.cutter_grinder_offset(m["primary_clearance"]["value"], 10.0), 1e-15, 0.0, "la fresa usa la regla")
	assert_eq(S.mill_angles({ "work_material": "acero" })["offset_mm"], null, "sin diámetro no hay desplazamiento")


func test_angulo_menor_bisel_mas_ancho() -> void:
	var prev := 0.0
	for deg in [25.0, 20.0, 15.0, 10.0, 5.0]:
		var w := S.bevel_width(1.0, deg)
		assert_true(w > prev, "a %d° el bisel es más ancho que con más ángulo" % int(deg))
		prev = w
	assert_near(S.bevel_width(1.0, 30.0), 1.0, 1e-12, 1e-15, "(1/2)/sen 30° = 1 mm")
	var jp := S.knife_angles({ "style": "japones", "use": "cocina", "thickness_mm": 0.6 })
	var oc := S.knife_angles({ "style": "occidental", "use": "cocina", "thickness_mm": 0.6 })
	assert_true(jp["per_side"]["value"] < oc["per_side"]["value"], "el japonés va más agudo")
	assert_true(jp["bevel_width_mm"]["value"] > oc["bevel_width_mm"]["value"], "y su bisel es más ancho")


func test_brocas_118_en_acero_y_135_a_140_en_inoxidable() -> void:
	var steel := S.drill_angles({ "work_material": "acero", "diameter_mm": 8.0 })
	assert_eq(steel["point"]["value"], 118.0, "acero en general")
	var inox := S.drill_angles({ "work_material": "inox", "diameter_mm": 8.0 })
	assert_true(inox["point"]["value"] >= 135.0 and inox["point"]["value"] <= 140.0, "inoxidable entre 135 y 140°")
	assert_eq(inox["point"]["min"], 135.0)
	assert_eq(inox["point"]["max"], 140.0)
	assert_eq(inox["din_1412"]["type"], "C", "afilado en cruz en inoxidable")
	assert_eq(S.drill_angles({ "work_material": "acero_duro" })["point"]["value"], 135.0)
	assert_eq(S.drill_angles({ "work_material": "aluminio" })["point"]["value"], 140.0)
	assert_eq(S.drill_angles({ "work_material": "aluminio" })["helix"]["type"], "W")
	assert_eq(S.drill_angles({ "work_material": "plastico" })["point"]["value"], 90.0)
	assert_eq(S.drill_angles({ "work_material": "fundicion" })["din_1412"]["type"], "D")
	var unknown := S.drill_angles({ "work_material": "titanio" })
	assert_eq(unknown["point"]["value"], 118.0, "sin fuente específica, el de uso general")
	assert_true(unknown["warnings"].size() > 0, "y lo dice")
	assert_eq(steel["chisel_edge"]["min"], 120.0)
	assert_eq(steel["chisel_edge"]["max"], 135.0)
	assert_eq(steel["thinning_pocket"]["min"], 105.0)


func test_incidencia_de_broca_por_diametro() -> void:
	for c in [[3.0, 12.0], [5.0, 12.0], [10.0, 10.0], [13.0, 10.0], [16.0, 8.0], [20.0, 8.0]]:
		var a := S.drill_angles({ "work_material": "acero", "diameter_mm": c[0] })
		assert_eq(a["clearance"]["value"], c[1], "Ø %s mm" % Js.js_num_str(c[0]))
		assert_true(a["clearance"]["value"] >= 8.0 and a["clearance"]["value"] <= 12.0, "dentro de 8–12° (TC 9-524)")
	var big := S.drill_angles({ "work_material": "acero", "diameter_mm": 30.0 })
	assert_eq(big["clearance"]["value"], 8.0)
	assert_true(big["warnings"].size() > 0, "fuera de Ø 2–20 mm avisa")
	assert_eq(S.drill_angles({ "work_material": "acero" })["clearance"]["value"], 10.0, "sin diámetro, el centro de 8–12°")


func test_nunca_diamante_para_amolar_ferrico() -> void:
	var bad := 0
	for steel in S.STEELS:
		for hrc in [0.0, 45.0, 58.0, 62.0, 66.0]:
			var ab := S.choose_abrasive(steel, hrc)
			if ab["abrasive_id"] == "diamante" or ab["alternative_id"] == "diamante":
				bad += 1
			for kind in KINDS:
				for machine in S.SHARPENING_MACHINES:
					var r := S.recommend_sharpening({ "tool": { "kind": kind, "steel_id": steel, "hrc": hrc if hrc > 0.0 else null, "diameter_mm": 10.0 }, "machine_id": machine })
					if r["abrasive_id"] == "diamante":
						bad += 1
					for g in r["grits"]:
						if g["process"] == "amolado" and g["abrasive_id"] == "diamante":
							bad += 1
	assert_eq(bad, 0, "recomendaciones con diamante para amolar acero")
	assert_eq(S.choose_abrasive("metal_duro", 0.0)["abrasive_id"], "diamante", "el metal duro sí va con diamante")
	assert_true(str(S.choose_abrasive("vg10", 61.0)["reason"]).contains("Nunca diamante"), "el motivo lo explica")


func test_cbn_por_encima_de_58_hrc_y_en_acero_rapido() -> void:
	assert_eq(S.choose_abrasive("x50crmov15", 56.0)["abrasive_id"], "al2o3")
	assert_eq(S.choose_abrasive("x50crmov15", 58.0)["abrasive_id"], "al2o3", "58 HRC justos: todavía Al₂O₃")
	assert_eq(S.choose_abrasive("x50crmov15", 58.5)["abrasive_id"], "cbn")
	assert_eq(S.choose_abrasive("1095", 62.0)["abrasive_id"], "cbn")
	assert_eq(S.choose_abrasive("m2", 50.0)["abrasive_id"], "cbn", "el acero rápido va con CBN")
	assert_eq(S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "vg10" } })["abrasive_id"], "cbn", "VG-10 de 61 HRC")
	var drill := S.recommend_sharpening({ "tool": { "kind": "broca", "steel_id": "m2", "diameter_mm": 10.0 } })
	assert_eq(drill["abrasive_id"], "cbn")
	for g in drill["grits"]:
		if g["process"] == "amolado":
			assert_eq(g["abrasive_id"], "cbn", "todos los pasos de amolado con CBN")


func test_indice_termico_baja_en_humedo_y_con_cbn_y_sube_con_potencia_y_tiempo() -> void:
	var base := _heat({})
	var wet := _heat({ "wet": true })
	assert_true(wet["coolant_effective"], "por debajo de 130 °C el agua enfría")
	assert_true(wet["index"] < base["index"], "en húmedo baja")
	assert_true(_heat({ "abrasive_id": "cbn" })["index"] < base["index"], "con CBN baja")
	assert_true(_heat({ "power_w": 40.0 })["index"] > base["index"], "más potencia, más índice")
	assert_true(_heat({ "dwell_s": 20.0 })["index"] > base["index"], "más tiempo, más índice")
	assert_true(_heat({ "speed_ms": 0.0 })["index"] >= base["index"], "quieta nunca calienta menos que barriendo")
	var prev := -1.0
	for pw in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0]:
		var dry := _heat({ "power_w": pw })
		var w := _heat({ "power_w": pw, "wet": true })
		assert_true(w["index"] <= dry["index"], "en húmedo nunca sube (%s W)" % Js.js_num_str(pw))
		assert_true(w["index"] >= prev, "sube con la potencia también en húmedo (%s W)" % Js.js_num_str(pw))
		prev = w["index"]
	prev = -1.0
	for t in [0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 300.0]:
		var h := _heat({ "dwell_s": t, "speed_ms": 0.0 })
		assert_true(h["index"] >= prev, "sube con el tiempo (%s s)" % Js.js_num_str(t))
		prev = h["index"]
	var hot := _heat({ "power_w": 400.0, "wet": true })
	assert_false(hot["coolant_effective"], "por encima de la ebullición el agua ya no enfría")
	assert_eq(hot["partition"], hot["partition_dry"])


func test_niveles_termicos_en_orden() -> void:
	var seen := {}
	var prev := 0
	for pw in [1.0, 10.0, 30.0, 60.0, 100.0, 200.0, 400.0, 800.0]:
		var h := _heat({ "power_w": pw, "steel_id": "vg10" })
		var lv := LEVELS.find(h["level"])
		assert_true(lv >= prev, "el nivel no baja al subir la potencia (%s W)" % Js.js_num_str(pw))
		prev = lv
		seen[h["level"]] = true
	assert_eq(seen.size(), 4, "pasa por bajo, medio, alto y quemado")
	var h := _heat({})
	var th: Dictionary = h["thresholds_c"]
	assert_true(th["burnout"] < th["temper"] and th["temper"] < th["burn"], "130 °C < revenido < 723 °C")
	assert_eq(h["threshold_kind"], "revenido")
	assert_eq(h["quality"], "estimate")
	assert_true(str(h["note"]).contains("no la temperatura del filo"), "la nota dice que no es la temperatura del filo")
	var hss := _heat({ "steel_id": "m2" })
	assert_eq(hss["threshold_kind"], "quemado", "el M2 revenido a 550 °C aguanta 5 s hasta el quemado")
	assert_eq(H.heat_risk({ "steel_id": "adamantio" })["level"], null, "acero sin datos: sin índice")


func test_hollomon_jaffe_coherente() -> void:
	var p := H.hollomon_jaffe(200.0, 3600.0)
	assert_near(p, 473.15 * 15.0, 1e-12, 0.0, "1 h: log10(1) = 0")
	var t2 := H.hj_time(p, 180.0)
	assert_true(t2 > 3600.0, "a menos temperatura hace falta más tiempo")
	assert_near(H.hollomon_jaffe(180.0, t2), p, 1e-12, 0.0, "y da el mismo parámetro")
	assert_true(H.hj_time(p, 250.0) < 3600.0, "a más temperatura, menos tiempo")
	assert_near(H.hj_temperature(p, 3600.0), 200.0, 1e-12, 1e-9)
	assert_near(H.equivalent_temperature(200.0, 3600.0, t2), 180.0, 1e-9, 1e-9)
	assert_near(H.equivalent_time(200.0, 3600.0, 180.0), t2, 1e-9, 0.0)
	for steel in H.STEELS:
		var last := INF
		for t in [0.1, 1.0, 10.0, 100.0, 3600.0, 36000.0]:
			var threshold := H.temper_threshold_c(steel, t)
			assert_true(threshold <= last, "%s: el umbral baja con el tiempo de exposición" % steel)
			assert_true(threshold <= H.BURN_C, "%s: nunca por encima del quemado" % steel)
			last = threshold
		var temper: Dictionary = H.STEELS[steel]["temper"]
		assert_near(H.temper_threshold_c(steel, temper["time_s"]), minf(temper["c"], H.BURN_C), 1e-9, 1e-9, "%s: con su tiempo, su temperatura" % steel)


func test_iso_8442_5_aprueba_y_suspende() -> void:
	assert_true(S.iso8442_verdict(50.0, 150.0)["passed"], "50 / 150 mm justos aprueban")
	var v := S.iso8442_verdict(49.9, 150.0)
	assert_false(v["passed"])
	assert_false(v["icp_ok"])
	assert_true(v["tcc_ok"])
	v = S.iso8442_verdict(50.0, 149.9)
	assert_false(v["passed"])
	assert_false(v["tcc_ok"])
	assert_true(str(S.iso8442_verdict(80.0, 400.0)["message"]).begins_with("Aprueba"))
	assert_true(str(S.iso8442_verdict(20.0, 400.0)["message"]).begins_with("Suspende"))
	assert_false(S.iso8442_verdict(60.0, 1000.0, true)["passed"], "dentado: 1500 mm")
	assert_true(S.iso8442_verdict(60.0, 1500.0, true)["passed"])
	assert_true(str(S.iso8442_verdict(49.97, 400.0)["message"]).contains("ICP 49,97 mm < 50 mm"), "sin «50 mm < 50 mm» al redondear")
	assert_true(str(S.iso8442_verdict(80.0, 149.96)["message"]).contains("TCC 149,96 mm < 150 mm"))
	assert_eq(S.ISO_8442_5["load_n"], 50.0)
	assert_eq(S.ISO_8442_5["cycles"], 60)


func test_toda_recomendacion_dentro_de_su_rango() -> void:
	var bad: Array[String] = []
	for req in _requests:
		var r := S.recommend_sharpening(req)
		var tag := "%s/%s/%s" % [r["tool"]["kind"], r["tool"]["steel_id"], r["machine"]["id"]]
		for e in _entries(r["angles"]):
			_check_in_range(e, tag, bad)
		if r["edge_finish"] != null:
			_check_in_range(r["edge_finish"], tag + " filo", bad)
		var sr: Dictionary = r["speed_range_ms"]
		if not (sr["min"] <= sr["max"]):
			bad.append(tag + ": intervalo de velocidad al revés")
		var d: float = r["machine"]["wheel_diameter_mm"]
		if absf(S.peripheral_speed(d, r["rpm_range"]["min"]) - sr["min"]) > 1e-9:
			bad.append(tag + ": rpm mínimas incoherentes")
		if r["machine"]["id"] == "afiladora_universal" and (r["speed_ms"] < sr["min"] or r["speed_ms"] > sr["max"]):
			bad.append(tag + ": la máquina de velocidad variable queda fuera de lo recomendado")
	for table in [S.SHARPENING_ANGLES, S.EDGE_FINISH, S.NOMINAL_OPERATION, S.SPEED_RANGES, H.ENERGY_PARTITION, H.STEELS]:
		for e in _entries(table):
			_check_in_range(e, "tabla", bad)
	for steel in H.STEELS:
		var temper: Dictionary = H.STEELS[steel]["temper"]
		if temper.has("min_c") and not (temper["min_c"] <= temper["c"] and temper["c"] <= temper["max_c"]):
			bad.append(steel + ": revenido de referencia fuera de su intervalo")
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 5)))


func test_sin_formula_angulo_hrc() -> void:
	for kind in KINDS:
		var soft: Dictionary = S.recommend_sharpening({ "tool": { "kind": kind, "steel_id": "x50crmov15", "hrc": 52.0, "diameter_mm": 10.0 } })["angles"]
		var hard: Dictionary = S.recommend_sharpening({ "tool": { "kind": kind, "steel_id": "x50crmov15", "hrc": 64.0, "diameter_mm": 10.0 } })["angles"]
		assert_true(same(soft, hard), "%s: los ángulos no dependen de la dureza" % kind)
	assert_true(str(S.knife_angles({})["note"]).contains("no se ajusta con la dureza"), "y se dice por qué")


func test_todas_las_entradas_con_fuente_y_calidad() -> void:
	var tables := {
		"SHARPENING_ANGLES": S.SHARPENING_ANGLES,
		"SHARPENING_MACHINES": S.SHARPENING_MACHINES,
		"VITRIFIED_MAX_SPEED": S.VITRIFIED_MAX_SPEED,
		"SPEED_RANGES": S.SPEED_RANGES,
		"GRIT_STEPS": S.GRIT_STEPS,
		"EDGE_FINISH": S.EDGE_FINISH,
		"ISO_8442_5": S.ISO_8442_5,
		"NOMINAL_OPERATION": S.NOMINAL_OPERATION,
		"BURR_WEAR_K": S.BURR_WEAR_K,
		"TOOL_MATERIALS": S.TOOL_MATERIALS,
		"STEELS": S.STEELS,
		"THRESHOLDS": H.THRESHOLDS,
		"ENERGY_PARTITION": H.ENERGY_PARTITION,
		"WET_FACTOR": H.WET_FACTOR,
	}
	var bad: Array[String] = []
	for name in tables:
		_check_sourced(tables[name], name, bad)
	for step_id in S.GRIT_STEPS:
		var step: Dictionary = S.GRIT_STEPS[step_id]
		if str(step.get("source", "")) == "" or not QUALITIES.has(step.get("quality")):
			bad.append("GRIT_STEPS.%s sin fuente" % step_id)
	for req in _requests:
		var r := S.recommend_sharpening(req)
		var tag := "%s/%s/%s" % [r["tool"]["kind"], r["tool"]["steel_id"], r["machine"]["id"]]
		_check_sourced(r["angles"], tag + ".angles", bad)
		_check_sourced(r["grits"], tag + ".grits", bad)
		_check_sourced(r["speed_range_ms"], tag + ".speed_range_ms", bad)
		if r["edge_finish"] != null:
			_check_sourced(r["edge_finish"], tag + ".edge_finish", bad)
		if not QUALITIES.has(r["quality"]) or r["sources"].is_empty():
			bad.append(tag + ": sin calidad o sin fuentes")
		if r["heat"] != null:
			if r["heat"]["quality"] != "estimate" or r["heat"]["sources"].is_empty():
				bad.append(tag + ".heat: debe ser una estimación con fuentes")
			_check_sourced(r["heat"]["inputs"], tag + ".heat.inputs", bad)
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 5)))


func test_rebaba_con_archard() -> void:
	var p := { "burr_height_um": 20.0, "burr_thickness_um": 2.0, "edge_length_mm": 200.0, "load_n": 5.0, "stroke_mm": 200.0, "hardness_mpa": 6500.0 }
	var r := S.burr_removal(p)
	assert_near(r["volume_mm3"], 0.02 * 0.002 * 200.0, 1e-12, 0.0, "volumen de la rebaba")
	assert_near(r["wear_per_stroke_mm3"], Abrasion.archard_wear(5.0, 200.0, 6500.0, S.BURR_WEAR_K["value"]), 1e-15, 0.0, "Archard de la capa compartida")
	assert_eq(r["quality"], "estimate", "k es una estimación")
	assert_true(r["strokes"] > 0)
	assert_true(S.burr_removal(p.merged({ "load_n": 10.0 }, true))["strokes"] < r["strokes"], "más carga, menos pasadas")
	assert_true(S.burr_removal(p.merged({ "hardness_mpa": 9000.0 }, true))["strokes"] > r["strokes"], "más dureza, más pasadas")
	assert_eq(S.burr_removal({})["strokes"], null, "sin carga no hay pasadas que contar")


func test_cuchillos_por_estilo_y_uso() -> void:
	var jp := S.knife_angles({ "style": "japones", "use": "cocina" })
	assert_true(jp["per_side"]["value"] >= 12.5 and jp["per_side"]["value"] <= 15.0, "Tormek 25–30° en total cruzado con los fabricantes (9–16° por lado)")
	assert_near(jp["included"]["value"], 2.0 * jp["per_side"]["value"], 1e-15, 0.0)
	var oc := S.knife_angles({ "style": "occidental", "use": "cocina" })
	assert_true(oc["per_side"]["value"] >= 15.0 and oc["per_side"]["value"] <= 20.0, "Tormek 30–40° cruzado con los fabricantes (14–20°)")
	var razor := S.knife_angles({ "use": "navaja" })
	assert_eq(razor["included"]["min"], 15.0)
	assert_eq(razor["included"]["max"], 19.0)
	assert_eq(razor["maker_per_side"], null, "la tabla de fabricantes solo vale para cocina")
	var axe: float = S.knife_angles({ "use": "hacha" })["included"]["value"]
	assert_true(axe >= 25.0 and axe <= 30.0, "hacha, 25–30° (Gränsfors)")
	assert_eq(S.knife_angles({ "use": "bisturi" })["included"]["value"], 26.0)
	assert_eq(S.knife_angles({ "style": "klingon", "use": "espacial" })["warnings"].size(), 2, "estilo y uso desconocidos")


func test_fresas_incidencia_y_helice() -> void:
	var al := S.mill_angles({ "work_material": "aluminio", "diameter_mm": 10.0 })
	assert_eq(al["primary_clearance"]["value"], 12.0, "blandos: 12° por debajo de 3″ (TC 9-524)")
	assert_eq(al["helix"]["min"], 37.0)
	assert_eq(al["helix"]["max"], 45.0)
	var st := S.mill_angles({ "work_material": "acero", "diameter_mm": 10.0 })
	assert_eq(st["primary_clearance"]["value"], 7.0, "duros: 7° por debajo de 3″")
	var nachi: Dictionary = S.SHARPENING_ANGLES["fresa"]["incidencia_primaria"]
	assert_true(st["primary_clearance"]["value"] >= nachi["min"] and st["primary_clearance"]["value"] <= nachi["max"], "y cae en los 5–9° de Nachi")
	assert_true(st["secondary_clearance"]["value"] > st["primary_clearance"]["value"], "la secundaria es mayor")
	var big: float = S.mill_angles({ "work_material": "acero", "diameter_mm": 100.0 })["primary_clearance"]["value"]
	assert_true(big >= 3.0 and big <= 5.0, "fresa grande en duro: 3–5°")
	assert_eq(S.mill_angles({ "work_material": "laton", "diameter_mm": 10.0 })["helix"]["value"], 0.0)
	var inox: float = S.mill_angles({ "work_material": "inox", "diameter_mm": 10.0 })["helix"]["value"]
	assert_true(inox >= 35.0 and inox <= 40.0)


func test_rpm_recomendadas_en_la_afiladora_universal() -> void:
	var r := S.recommend_sharpening({ "tool": { "kind": "fresa", "steel_id": "metal_duro", "diameter_mm": 10.0, "work_material": "aluminio" }, "machine_id": "afiladora_universal", "wheel_diameter_mm": 100.0 })
	assert_eq(r["abrasive_id"], "diamante")
	assert_eq(r["speed_range_ms"]["min"], 16.0, "diamante en seco: 16–22 m/s (Kraus & Winter)")
	assert_near(r["rpm_range"]["min"], S.rpm_for_speed(16.0, 100.0), 1e-12, 0.0)
	assert_near(r["rpm_range"]["max"], S.rpm_for_speed(22.0, 100.0), 1e-12, 0.0)
	assert_true(r["speed_ms"] >= 16.0 and r["speed_ms"] <= 22.0, "elige unas rpm dentro del intervalo")
	assert_eq(r["heat"], null, "el metal duro no se reviene")
	var wet := S.recommend_sharpening({ "tool": { "kind": "fresa", "steel_id": "metal_duro", "diameter_mm": 10.0 }, "machine_id": "afiladora_universal", "wet": true })
	assert_eq(wet["speed_range_ms"]["min"], 25.0, "en húmedo, 25–30 m/s")
	var hss := S.recommend_sharpening({ "tool": { "kind": "fresa", "steel_id": "m2", "diameter_mm": 12.0 }, "machine_id": "afiladora_universal" })
	assert_eq(hss["abrasive_id"], "cbn")
	assert_eq(hss["speed_range_ms"]["max"], 28.0, "CBN en seco: 16–28 m/s")


func test_casos_de_uso_completos() -> void:
	for req in E2E:
		var r := S.recommend_sharpening(req)
		var tag := str(req["tool"]["kind"]) + "/" + str(req["tool"]["steel_id"])
		assert_true(r["grits"].size() >= 2, tag + ": progresión de granos")
		assert_true(r["speed_ms"] > 0.0, tag + ": velocidad")
		assert_true(r["sources"].size() > 3, tag + ": fuentes")
		assert_true(str(r["abrasive_reason"]) != "", tag + ": motivo del abrasivo")
		if S.STEELS.has(req["tool"]["steel_id"]):
			assert_true(r["heat"] != null and LEVELS.has(r["heat"]["level"]), tag + ": riesgo térmico")
		else:
			assert_eq(r["heat"], null, tag + ": sin riesgo térmico")
		if req["tool"]["kind"] == "cuchillo":
			assert_true(r["edge_width_um"] != null and r["edge_width_um"] < 1.0, tag + ": filo final por debajo de 1 µm")
		else:
			assert_eq(r["edge_width_um"], null, tag + ": Verhoeven solo midió cuchillos")
	assert_eq(S.recommend_sharpening({ "tool": { "kind": "broca" } })["machine"]["id"], "esmeriladora_banco", "máquina por defecto de la broca")
	assert_eq(S.recommend_sharpening({ "tool": { "kind": "fresa" } })["machine"]["id"], "afiladora_universal", "y de la fresa")


func test_entradas_raras_sin_errores() -> void:
	for flag in [1, 1.0, "true", "sí", true]:
		var r := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "14c28n" }, "machine_id": "esmeriladora_banco", "wet": flag })
		assert_true(r["machine"]["wet"], "wet = %s se lee como sí" % str(flag))
		assert_true(H.heat_risk({ "steel_id": "14c28n", "power_w": 5.0, "wet": flag })["coolant_effective"], "y heat_risk también")
	for flag in [0, 0.0, "false", false]:
		assert_false(S.recommend_sharpening({ "tool": { "kind": "cuchillo" }, "machine_id": "tormek_t8", "wet": flag })["machine"]["wet"], "wet = %s se lee como no" % str(flag))
	for d in [0.0, -120.0]:
		var r := S.recommend_sharpening({ "tool": { "kind": "fresa", "steel_id": "metal_duro", "diameter_mm": 10.0 }, "machine_id": "afiladora_universal", "wheel_diameter_mm": d })
		assert_eq(r["machine"]["wheel_diameter_mm"], 125.0, "diámetro no válido: el de serie")
		assert_true(is_finite(r["speed_ms"]) and r["speed_ms"] > 0.0, "velocidad finita")
		assert_true(_has_warning(r, "Diámetro de muela no válido"))
	var neg := S.recommend_sharpening({ "tool": { "kind": "cuchillo" }, "machine_id": "tormek_t8", "rpm": -50.0 })
	assert_eq(neg["machine"]["rpm"], 100.0, "rpm negativas: las de serie")
	assert_true(_has_warning(neg, "Giro no válido"))
	var unknown := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "aus8", "hrc": 62.0 } })
	assert_eq(unknown["abrasive_id"], "cbn", "acero sin datos con 62 HRC indicados")
	assert_eq(unknown["tool"]["hrc"], 62.0, "y la dureza que decidió se devuelve")
	assert_true(_has_warning(unknown, "dureza indicada"))
	assert_eq(unknown["heat"], null)
	var blank := H.heat_risk({ "steel_id": "adamantio" })
	for key in ["threshold_kind", "thresholds_c", "partition", "partition_dry", "coolant_effective", "regime", "peclet", "exposure_s"]:
		assert_true(blank.has(key) and blank[key] == null, "acero desconocido: %s a null" % key)


func test_metal_duro_en_el_tormek_y_nota_termica() -> void:
	var r := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "metal_duro" }, "machine_id": "tormek_t8" })
	assert_eq(r["abrasive_id"], "diamante")
	for g in r["grits"]:
		if g["process"] == "amolado":
			assert_eq(g["abrasive_id"], "diamante", "todos los pasos de amolado con diamante, no con la SG-250")
	assert_eq(r["edge_width_um"], null, "las anchuras de Verhoeven son de filos de acero")
	assert_true(_has_warning(r, "afiladora universal"))
	for id in S.TOOL_MATERIALS:
		assert_eq(S.choose_abrasive(id, 0.0)["abrasive_id"], S.TOOL_MATERIALS[id]["abrasive_id"], "%s: el abrasivo sale de la tabla" % id)
	var dry := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "14c28n", "hrc": 55.0 }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 150.0 })
	assert_eq(dry["heat"]["level"], "medio", "escenario de riesgo medio en seco")
	for w in dry["warnings"]:
		if str(w).begins_with("Riesgo térmico medio"):
			assert_false(str(w).contains("agua"), "en seco el aviso no habla del agua")
	var danger := S.recommend_sharpening({ "tool": { "kind": "cuchillo", "steel_id": "x50crmov15" }, "machine_id": "esmeriladora_banco", "wheel_diameter_mm": 200.0, "rpm": 3345.2 })
	assert_true(danger["over_speed"])
	assert_true(_has_warning(danger, "35,03 m/s"), "35,03 frente a 35 m/s, sin «35 m/s … 35 m/s»")


# --- utilidades ---


func _heat(extra: Dictionary) -> Dictionary:
	var p := { "power_w": 20.0, "contact_area_mm2": 10.0, "speed_ms": 0.025, "wet": false, "abrasive_id": "al2o3", "steel_id": "14c28n", "dwell_s": 5.0 }
	p.merge(extra, true)
	return H.heat_risk(p)


func _has_warning(r: Dictionary, text: String) -> bool:
	for w in r["warnings"]:
		if str(w).contains(text):
			return true
	return false


## Todas las combinaciones razonables de herramienta, material, uso y máquina.
func _all_requests() -> Array:
	var out: Array = []
	var knife: Dictionary = S.SHARPENING_ANGLES["cuchillo"]
	for machine in S.SHARPENING_MACHINES:
		for steel in S.STEELS:
			for style in knife["estilos"]:
				for use in knife["usos"]:
					out.append({ "tool": { "kind": "cuchillo", "steel_id": steel, "style": style, "use": use, "thickness_mm": 0.6 }, "machine_id": machine })
		for steel in ["m2", "1095", "metal_duro"]:
			for work in WORKS:
				for d in [3.0, 10.0, 16.0, 100.0]:
					out.append({ "tool": { "kind": "broca", "steel_id": steel, "work_material": work, "diameter_mm": d }, "machine_id": machine })
					out.append({ "tool": { "kind": "fresa", "steel_id": steel, "work_material": work, "diameter_mm": d }, "machine_id": machine })
	return out


## Diccionarios con fuente dentro de un resultado o tabla.
func _entries(node: Variant) -> Array:
	var out: Array = []
	if node is Dictionary:
		if node.has("source"):
			out.append(node)
		for k in node:
			out.append_array(_entries(node[k]))
	elif node is Array:
		for x in node:
			out.append_array(_entries(x))
	return out


func _check_in_range(e: Dictionary, tag: String, bad: Array[String]) -> void:
	if e.has("value") and e.has("min") and e.has("max"):
		if not (e["min"] <= e["value"] and e["value"] <= e["max"]):
			bad.append("%s: %s fuera de %s–%s (%s)" % [tag, Js.js_num_str(e["value"]), Js.js_num_str(e["min"]), Js.js_num_str(e["max"]), str(e["source"]).substr(0, 60)])


## Todo diccionario con un número propio lleva source (texto no vacío) y quality válida.
func _check_sourced(node: Variant, path: String, bad: Array[String]) -> void:
	if node is Dictionary:
		var numeric := false
		for k in node:
			var v: Variant = node[k]
			if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
				numeric = true
			elif v is Dictionary or v is Array:
				_check_sourced(v, "%s.%s" % [path, k], bad)
		if numeric:
			if str(node.get("source", "")) == "":
				bad.append(path + ": sin fuente")
			if not QUALITIES.has(node.get("quality")):
				bad.append(path + ": calidad no válida")
	elif node is Array:
		for i in node.size():
			_check_sourced(node[i], "%s[%d]" % [path, i], bad)
