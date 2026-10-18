## Taller · catálogo de afiladoras (sharpening_machines.gd): esquema completo con fuente y calidad, velocidades
## declaradas por el fabricante, velocidad máxima marcada, abrasivo contra material, para qué sirve cada máquina,
## coherencia con sharpening.gd y el diccionario de la vista 3D (CONTRATOS.md → «Vista 3D de la afiladora»).
extends "res://tests/case.gd"

const Machines = preload("res://core/taller/sharpening_machines.gd")
const S = preload("res://core/taller/sharpening.gd")
const G = preload("res://core/taller/grinding.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Js = preload("res://core/shared/js.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const KINDS := ["banco", "banco_lenta", "combinada", "lenta_humeda", "amoladora", "afiladora_brocas", "afiladora_fresas"]
const TOOL_KINDS := ["cuchillo", "broca", "fresa", "hacha", "cortacesped"]
const ABRASIVE_IDS := ["al2o3", "cbn", "diamante", "sic", ""]
# La vista 3D de la afiladora (CONTRATOS.md).
const VIEW_KINDS := ["banco", "humeda_lenta", "amoladora", "afilabrocas", "afilafresas"]
const VIEW_POSITIONS := ["izquierda", "derecha", "piedra", "cuero", "disco"]


func test_esquema_completo() -> void:
	var bad: Array[String] = []
	assert_true(Machines.MACHINES.size() >= 10, "al menos diez máquinas")
	for id in Machines.MACHINES:
		var m: Dictionary = Machines.MACHINES[id]
		var tag := str(id)
		if str(m.get("id", "")) != tag:
			bad.append(tag + ": id distinto de la clave")
		for key in ["name", "brand", "model", "market", "source"]:
			if str(m.get(key, "")) == "":
				bad.append(tag + ": falta " + key)
		if not KINDS.has(m.get("kind")):
			bad.append(tag + ": kind no válido")
		if not Machines.VIEW_KIND.has(m.get("kind")):
			bad.append(tag + ": kind sin vista 3D")
		if not (float(m.get("mains_hz", 0.0)) in [50.0, 60.0]):
			bad.append(tag + ": red de 50 o 60 Hz")
		if not QUALITIES.has(m.get("quality")):
			bad.append(tag + ": calidad no válida")
		var motor: Dictionary = m["motor"]
		if not G.MOTORS.has(motor.get("type")):
			bad.append(tag + ": motor sin modelo en grinding.gd")
		for key in ["input_w", "rpm_no_load"]:
			var e: Dictionary = motor[key]
			if not (float(e["value"]) > 0.0) or str(e.get("source", "")) == "" or not QUALITIES.has(e.get("quality")):
				bad.append(tag + ": motor." + key)
		var iw: Dictionary = motor["input_w"]
		if iw.has("s1") and iw.has("s2_30min") and float(iw["s1"]) > float(iw["s2_30min"]):
			bad.append(tag + ": S1 mayor que S2")
		var layout: Dictionary = m["layout"]
		if str(layout.get("source", "")) == "" or not QUALITIES.has(layout.get("quality")):
			bad.append(tag + ": layout sin fuente o calidad")
		if typeof(m.get("water_trough")) != TYPE_BOOL or typeof(m.get("quench_pot")) != TYPE_BOOL:
			bad.append(tag + ": water_trough y quench_pot son booleanos")
		for opt in ["rest_gap_max_mm", "noise", "weight_kg"]:
			var e2: Variant = m.get(opt)
			if e2 != null and (str((e2 as Dictionary).get("source", "")) == "" or not QUALITIES.has((e2 as Dictionary).get("quality"))):
				bad.append(tag + ": " + opt + " sin fuente o calidad")
		var ft: Dictionary = m["for_tools"]
		for tk in TOOL_KINDS:
			var f: Dictionary = ft.get(tk, {})
			if not Machines.FITS.has(f.get("fit")) or str(f.get("why", "")) == "" or str(f.get("source", "")) == "":
				bad.append(tag + ": for_tools." + tk)
		_check_wheels(tag, m["wheels"], bad)
	assert_eq(bad.size(), 0, "; ".join(bad))


func _check_wheels(tag: String, wheels: Array, bad: Array[String]) -> void:
	if wheels.is_empty():
		bad.append(tag + ": sin muelas")
		return
	var ids: Array = []
	var mounted_pos: Array = []
	for w in wheels:
		var wt := tag + "/" + str(w.get("id", "?"))
		if ids.has(w["id"]):
			bad.append(wt + ": id repetido")
		ids.append(w["id"])
		for key in ["role", "grit", "source"]:
			if not w.has(key):
				bad.append(wt + ": falta " + key)
		if not VIEW_POSITIONS.has(w.get("position")):
			bad.append(wt + ": posición no válida")
		if typeof(w.get("mounted")) != TYPE_BOOL:
			bad.append(wt + ": mounted")
		elif bool(w["mounted"]):
			if mounted_pos.has(w["position"]):
				bad.append(wt + ": dos muelas montadas en la misma posición")
			mounted_pos.append(w["position"])
		if not ABRASIVE_IDS.has(w.get("abrasive_id")) or not QUALITIES.has(w.get("abrasive_quality")):
			bad.append(wt + ": abrasivo")
		if not (float(w["diameter_mm"]) > 0.0 and float(w["rpm"]) > 0.0):
			bad.append(wt + ": diámetro y giro")
		if w["width_mm"] != null and not (float(w["width_mm"]) > 0.0):
			bad.append(wt + ": ancho")
		if w["diameter_min_mm"] != null and not (float(w["diameter_min_mm"]) < float(w["diameter_mm"])):
			bad.append(wt + ": diámetro mínimo")
		if typeof(w.get("wet")) != TYPE_BOOL or typeof(w.get("honing")) != TYPE_BOOL:
			bad.append(wt + ": wet y honing son booleanos")
		if str(w.get("source", "")) == "" or not QUALITIES.has(w.get("quality")):
			bad.append(wt + ": sin fuente o calidad")
	if mounted_pos.is_empty():
		bad.append(tag + ": ninguna muela montada")


func test_velocidades_declaradas() -> void:
	var n := 0
	for id in Machines.MACHINES:
		for w in Machines.MACHINES[id]["wheels"]:
			if w["speed_ms"] == null:
				continue
			var v := S.peripheral_speed(float(w["diameter_mm"]), float(w["rpm"]))
			assert_near(v, float(w["speed_ms"]), 0.005, 0.0, "%s/%s: la velocidad que declara el fabricante sale de π·D·n" % [id, w["id"]])
			n += 1
	assert_true(n >= 5, "hay velocidades declaradas con las que comparar (%d)" % n)
	var r := Machines.wheel_speed("einhell_tc_bg_150", "fino")
	assert_near(r["speed_ms"], 23.4049, 1e-5, 0.0, "150 mm a 2980 rpm")
	assert_eq(r["declared_ms"], 23.4)


func test_velocidad_maxima_marcada() -> void:
	for id in Machines.MACHINES:
		var m: Dictionary = Machines.MACHINES[id]
		for w in m["wheels"]:
			if w["max_rpm"] != null:
				assert_true(float(w["rpm"]) <= float(w["max_rpm"]), "%s/%s gira por debajo de su máximo marcado" % [id, w["id"]])
				var rpm_max: float = m["motor"]["rpm_no_load"].get("max", m["motor"]["rpm_no_load"]["value"])
				assert_true(rpm_max <= float(w["max_rpm"]), "%s/%s: ni en la posición más rápida se pasa" % [id, w["id"]])
			var conventional: bool = str(w["abrasive_id"]) in ["al2o3", "sic", ""] and not bool(w["honing"]) and not w.has("disc_id")
			if conventional:
				var v := S.peripheral_speed(float(w["diameter_mm"]), float(w["rpm"]))
				assert_true(v <= float(S.VITRIFIED_MAX_SPEED["value"]), "%s/%s: una muela vitrificada no pasa de 35 m/s (EN 12413)" % [id, w["id"]])
	var e := Machines.wheel_speed("einhell_tc_bg_150", "grueso")
	assert_near(e["max_speed_ms"], 35.0, 0.002, 0.0, "4456 rpm en 150 mm son los 35 m/s marcados en la muela de Einhell")
	assert_false(e["over_speed"])
	assert_true(Machines.wheel_speed("einhell_tc_bg_150", "grueso", 5000.0)["over_speed"], "a 5000 rpm se pasaría del máximo marcado")
	for w in Machines.MACHINES["einhell_te_ag_125_ce"]["wheels"]:
		var d := Machines.wheel_speed("einhell_te_ag_125_ce", w["id"])
		assert_true(float(w["max_rpm"]) >= 12000.0 and float(d["max_speed_ms"]) >= 79.5, "la TE-AG pide discos de ≥ 12 000 rpm y 80 m/s (%s)" % w["id"])
	assert_eq(Machines.wheel_speed("vevor_md150g_450", "fino")["max_speed_ms"], null, "sin máximo marcado, null")


func test_giro_por_debajo_del_sincronismo() -> void:
	# Motor de inducción de una esmeriladora de banco: la muela va en el eje del motor, así que su giro en vacío
	# queda justo por debajo del de sincronismo 120·f/p (2 polos: 3000 rpm a 50 Hz, 3600 a 60 Hz; 4 polos: 1800).
	var n := 0
	for id in Machines.MACHINES:
		var m: Dictionary = Machines.MACHINES[id]
		if not (str(m["kind"]) in ["banco", "banco_lenta", "combinada"]) or str(m["motor"]["type"]) != "induccion":
			continue
		var rpm: float = m["motor"]["rpm_no_load"]["value"]
		var sync := 0.0  # el sincronismo más bajo que sigue por encima del giro en vacío
		for p in [2, 4, 6, 8]:
			if 120.0 * float(m["mains_hz"]) / float(p) > rpm:
				sync = 120.0 * float(m["mains_hz"]) / float(p)
		var slip := 1.0 - rpm / sync
		assert_true(slip > 0.0 and slip < 0.06, "%s: %s rpm con red de %s Hz → deslizamiento del %s %%" % [id, Js.js_num_str(rpm), Js.js_num_str(float(m["mains_hz"])), Js.to_fixed(slip * 100.0, 1)])
		n += 1
	assert_true(n >= 4, "se comprueban las cuatro de banco")


func test_granos() -> void:
	for id in Machines.MACHINES:
		for w in Machines.MACHINES[id]["wheels"]:
			var sys := str(w["grit_system"])
			if sys == "":
				continue
			assert_true(Abrasives.GRIT_SYSTEMS.has(sys), "%s/%s: sistema de grano conocido" % [id, w["id"]])
			assert_true(Abrasives.grit_microns(sys, w["grit_number"]) > 0.0, "%s/%s: el grano %s existe en %s" % [id, w["id"], w["grit"], sys])
	for id in ["einhell_tc_bg_150", "vevor_md150g_450", "vevor_md150_4"]:
		var coarse := Machines.wheel(id, "grueso")
		var fine := Machines.wheel(id, "fino")
		assert_true(Abrasives.grit_microns(coarse["grit_system"], coarse["grit_number"]) > Abrasives.grit_microns(fine["grit_system"], fine["grit_number"]), "%s: la gruesa tiene el grano mayor" % id)


func test_abrasivo_contra_material() -> void:
	for steel in Heat.STEELS:
		assert_false(Machines.abrasive_suits("diamante", steel), "nunca diamante para acero (%s)" % steel)
		assert_false(Machines.abrasive_suits("sic", steel), "ni SiC (%s)" % steel)
		assert_true(Machines.abrasive_suits("al2o3", steel))
		assert_true(Machines.abrasive_suits("cbn", steel))
	assert_true(Machines.abrasive_suits("diamante", "metal_duro"), "el metal duro, con diamante")
	assert_false(Machines.abrasive_suits("cbn", "metal_duro"))
	assert_false(Machines.abrasive_suits("al2o3", "metal_duro"))
	var x3 := Machines.suitability("mrcm_mr_x3", "fresa", "m2")
	assert_eq(x3["wheels_bad"], ["sdc"], "una fresa de HSS en la MR-X3: la muela SDC de serie no vale")
	assert_eq(x3["wheels_ok"], ["cbn"], "hay que montar la de CBN")
	var hm := Machines.suitability("mrcm_mr_13a", "broca", "metal_duro")
	assert_eq(hm["wheels_ok"], ["sdc"], "una broca de metal duro en la MR-13A: la SDC")
	var knife := Machines.suitability("tormek_t8", "cuchillo", "vg10")
	assert_eq(knife["wheels_ok"], ["sg250"], "la rueda de cuero no cuenta como muela")
	assert_true(knife["abrasive_ok"])


func test_para_que_sirve_cada_maquina() -> void:
	for id in Machines.MACHINES:
		var m: Dictionary = Machines.MACHINES[id]
		var ft: Dictionary = m["for_tools"]
		match str(m["kind"]):
			"amoladora":
				assert_eq(ft["cuchillo"]["fit"], "no", "%s: una amoladora no es para un cuchillo de cocina" % id)
				assert_eq(ft["broca"]["fit"], "no", id)
			"lenta_humeda":
				assert_true(str(ft["cuchillo"]["fit"]) in ["ideal", "buena"], "%s: la lenta en agua es la del cuchillo" % id)
			"banco", "banco_lenta":
				assert_eq(ft["cuchillo"]["fit"], "con_cuidado", "%s: seca y rápida, solo con cuidado" % id)
				assert_eq(ft["broca"]["fit"], "buena", "%s: la esmeriladora es la clásica de las brocas" % id)
		if id != "mrcm_mr_x3":
			assert_eq(ft["fresa"]["fit"], "no", "%s: las fresas, en la afiladora de fresas" % id)
	assert_eq(Machines.suitability("mrcm_mr_13a", "broca")["fit"], "ideal")
	assert_eq(Machines.suitability("mrcm_mr_x3", "fresa")["fit"], "ideal")
	assert_eq(Machines.suitability("mrcm_mr_13a", "cuchillo")["fit"], "no")
	assert_eq(Machines.suitability("piedra_filosofal", "cuchillo")["fit"], "no")
	assert_eq(Machines.suitability("tormek_t8", "sierra")["fit"], "no", "herramienta sin datos")
	var rows := Machines.machines_for("cuchillo")
	assert_eq(rows.size(), Machines.MACHINES.size())
	for i in range(1, rows.size()):
		var a: Dictionary = rows[i - 1]
		var b: Dictionary = rows[i]
		assert_true(int(a["rank"]) < int(b["rank"]) or (int(a["rank"]) == int(b["rank"]) and str(a["id"]) < str(b["id"])), "ordenadas por adecuación y luego por id")
	assert_eq(rows[0]["fit"], "ideal")
	assert_eq(rows[rows.size() - 1]["fit"], "no")


func test_tormek_igual_que_sharpening() -> void:
	var mine: Dictionary = Machines.MACHINES["tormek_t8"]
	var ref: Dictionary = S.SHARPENING_MACHINES["tormek_t8"]
	var w: Dictionary = mine["wheels"][0]
	assert_eq(w["diameter_mm"], ref["wheel_diameter_mm"]["value"])
	assert_eq(w["rpm"], ref["rpm"]["value"])
	assert_eq(mine["motor"]["rpm_no_load"]["min"], ref["rpm"]["min"])
	assert_eq(w["abrasive_id"], ref["wheel_abrasive_id"])
	assert_eq(w["wet"], ref["wet"])
	assert_eq(mine["kind"], ref["kind"])


func test_copias_y_solo_lectura() -> void:
	assert_true(Machines.MACHINES.is_read_only(), "el catálogo es constante: se puede leer desde varios hilos")
	var m := Machines.machine("tormek_t8")
	m["name"] = "otra"
	(m["wheels"][0] as Dictionary)["rpm"] = 1.0
	assert_eq(Machines.MACHINES["tormek_t8"]["name"], "Tormek T-8 (referencia)", "machine() da una copia")
	assert_eq(Machines.MACHINES["tormek_t8"]["wheels"][0]["rpm"], 100.0, "copia profunda")
	var w := Machines.wheel("tormek_t8", 0)
	w["rpm"] = 2.0
	assert_eq(Machines.wheel("tormek_t8", "sg250")["rpm"], 100.0)
	assert_eq(Machines.machine("piedra_filosofal"), {})
	assert_eq(Machines.wheel("tormek_t8", 7), {})
	assert_eq(Machines.wheel("tormek_t8", "inexistente"), {})
	assert_eq(Machines.wheel_speed("piedra_filosofal"), {})


func test_muela_gastada_y_giro_regulable() -> void:
	var worn := Machines.wheel_speed("einhell_tc_bg_150", "fino", -1.0, 130.0)
	assert_near(worn["speed_ms"], S.peripheral_speed(130.0, 2980.0), 1e-12, 0.0, "muela gastada: el mismo giro, menos velocidad")
	assert_eq(worn["diameter_mm"], 130.0)
	var slow := Machines.wheel_speed("einhell_te_ag_125_ce", "laminas", 3000.0)
	assert_near(slow["speed_ms"], 19.635, 1e-4, 0.0, "la TE-AG en la posición 1: 19,6 m/s")
	assert_eq(Machines.MACHINES["einhell_te_ag_125_ce"]["motor"]["rpm_no_load"]["steps"].size(), 6, "seis posiciones de la rueda")


func test_vista_3d() -> void:
	for id in Machines.MACHINES:
		var v := Machines.view(id)
		assert_true(VIEW_KINDS.has(v["kind"]), "%s: kind de la vista" % id)
		assert_true(float(v["rpm"]) > 0.0, id)
		assert_true(typeof(v["wet"]) == TYPE_BOOL and typeof(v["water_trough"]) == TYPE_BOOL, id)
		var positions: Array = []
		var selected := 0
		for w in v["wheels"]:
			assert_true(VIEW_POSITIONS.has(w["position"]), "%s: posición de la vista" % id)
			assert_false(positions.has(w["position"]), "%s: una muela por posición" % id)
			positions.append(w["position"])
			assert_true(float(w["d_mm"]) > 0.0 and (w["width_mm"] == null or float(w["width_mm"]) > 0.0), id)
			assert_true(typeof(w["abrasive_id"]) == TYPE_STRING and typeof(w["grit"]) == TYPE_STRING, id)
			if w["selected"]:
				selected += 1
		assert_eq(selected, 1, "%s: una muela en uso" % id)
	var bg := Machines.view("einhell_tc_bg_150")
	assert_eq(bg["kind"], "banco")
	assert_eq(bg["wheels"][0]["position"], "izquierda", "la gruesa a la izquierda (fig. 1 del manual)")
	assert_eq(bg["wheels"][0]["grit"], "K36")
	assert_eq(bg["wheels"][1]["position"], "derecha")
	assert_false(bg["wet"])
	var wd := Machines.view("einhell_tc_wd_200_150", "humeda")
	assert_eq(wd["rpm"], 134.0, "la combinada: manda el giro de la muela en uso")
	assert_true(wd["wet"] and wd["water_trough"])
	assert_eq(wd["wheels"].size(), 2)
	var hm := Machines.view("mrcm_mr_13a", "sdc")
	assert_eq(hm["kind"], "afilabrocas")
	assert_eq(hm["wheels"].size(), 1, "el recambio sustituye a la muela de serie")
	assert_eq(hm["wheels"][0]["abrasive_id"], "diamante")
	assert_eq(Machines.view("mrcm_mr_13a")["wheels"][0]["abrasive_id"], "cbn", "de serie, CBN")
	assert_eq(Machines.view("mrcm_mr_x3")["kind"], "afilafresas")
	assert_eq(Machines.view("tormek_t8")["kind"], "humeda_lenta")
	assert_eq(Machines.view("einhell_te_ag_125_ce", "desbaste")["wheels"][0]["width_mm"], 7.2)
	var worn := Machines.view("einhell_tc_bg_150", "fino", 130.0)
	assert_eq(worn["wheels"][1]["d_mm"], 130.0, "la muela gastada se dibuja más pequeña")
	assert_eq(worn["wheels"][0]["d_mm"], 150.0, "la otra no")
	assert_true(Machines.view("vevor_md150g_450")["quench_pot"], "la VEVOR trae baño de enfriamiento")
	assert_eq(Machines.view("piedra_filosofal"), {})
	assert_eq(Machines.view("tormek_t8", "inexistente")["wheels"][0]["id"], "sg250", "una muela desconocida: la de serie")
