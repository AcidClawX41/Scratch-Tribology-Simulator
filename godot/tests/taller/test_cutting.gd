## Taller · modelo de corte y catálogos (unidad 5): los casos publicados, las tablas del Tabellenbuch, los
## invariantes físicos y que todo el catálogo lleve fuente y calidad.
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")

## Tabellenbuch Zerspantechnik (2015), valor de tabla k = kc1.1/h^mc a h = 0,2 mm, tal como lo imprime el libro
## (N/mm², entero): tablas de las pp. 209-210 y diagrama de la p. 205 (C45E). Comprueba la transcripción.
const TZ_K_AT_02 := {
	"s235jr": 2340.0, "c45e": 2756.0, "c16mncr5": 3191.0, "c42crmo4": 3799.0, "x5crni18_10": 3295.0,
	"gjl250": 1763.0, "ti6al4v": 1921.0, "cuzn39pb3": 1042.0,
}
## Fila completa del 42CrMo4 (TZ, p. 209): [h (mm), k (N/mm²)]
const TZ_ROW_42CRMO4 := [
	[0.06, 5195.0], [0.08, 4821.0], [0.1, 4549.0], [0.2, 3799.0], [0.25, 3585.0], [0.4, 3173.0], [0.6, 2855.0],
	[0.8, 2649.0], [1.0, 2500.0], [1.6, 2212.0],
]
const METALS_REQUIRED := [
	"c45e", "c42crmo4", "s235jr", "c16mncr5", "x5crni18_10", "gjl250", "al6082_t6", "cuzn39pb3", "ti6al4v",
	"inconel718",
]
const NON_METALS_REQUIRED := ["pino", "pvc", "abs", "vidrio", "granito"]
const TOOLS_REQUIRED := [
	"hss_m2", "hss_co_m42", "hss_tin", "hm", "hm_coated", "cermet", "ceramica_al2o3", "ceramica_si3n4", "cbn", "pcd",
]


func _turn(work_id: String, extra: Dictionary = {}) -> Dictionary:
	var p := { "work_id": work_id, "tool_id": "hm", "d_mm": 50.0, "vc": 150.0, "f_mm_rev": 0.2, "ap_mm": 2.0 }
	p.merge(extra, true)
	return Cutting.turning(p)


# --- casos publicados ---------------------------------------------------------------------------------------


func test_kc_42crmo4_del_tabellenbuch() -> void:
	# TZ, p. 208: torneado exterior de 42CrMo4 (kc1.1 = 2500, mc = 0,26), h = 0,2 mm, metal duro, γ = 18° y
	# desgaste ligero: kc = 2500/0,2^0,26 · 0,88 · 1,0 · 1,2 · 1,0 = 4011 N/mm²
	var r := Cutting.specific_cutting_force({
		"kc11": 2500.0, "mc": 0.26, "h_mm": 0.2, "gamma_deg": 18.0, "gamma0_deg": 6.0, "tool_factor": 1.0,
		"wear_factor": 1.2,
	})
	assert_near(r["kc"], 4011.0, 1e-3, 0.0, "kc del ejemplo (±0,1 %)")
	assert_near(r["Kgamma"], 0.88, 1e-12, 0.0, "Kγ = 1 − (18 − 6)/100")
	assert_near(r["k"], 3799.0, 0.5 / 3799.0, 0.0, "valor de tabla a h = 0,2 (TZ: 3799)")
	assert_eq(r["Ksp"], 1.0, "Ksp de torneado exterior")
	# el mismo caso desde el catálogo: material, herramienta y desgaste por nombre
	var t := _turn("c42crmo4", { "vc": 180.0, "gamma_deg": 18.0, "wear": "ligero" })
	assert_near(t["kc"], 4011.0, 1e-3, 0.0, "kc desde el catálogo")
	assert_near(t["h_mm"], 0.2, 1e-12, 0.0, "h = f·sen 90°")
	assert_eq(t["quality"], "primary", "kc del 42CrMo4 y Kvc del metal duro son de la fuente principal")


func test_potencia_publicada_8_4_kw() -> void:
	# TZ, p. 212: Pc = Fc·vc = 2800 N · 180 m/min / 60 s/min = 8400 W
	assert_near(Cutting.cutting_power_kw(2800.0, 180.0), 8.4, 1e-12, 0.0, "Pc (kW)")
	var t := _turn("c45e", { "vc": 180.0 })
	assert_near(t["pc_kw"], t["fc_n"] * t["vc"] / 60000.0, 1e-12, 0.0, "el torneado usa Pc = Fc·vc")
	assert_near(t["pmotor_kw"], t["pc_kw"] / Cutting.ETA_DEFAULT, 1e-12, 0.0, "motor = Pc/η")


func test_fresado_publicado_sandvik() -> void:
	# Sandvik, Metalcutting Technical Guide (D) Milling (2005), p. D25: planeado a 45° de acero CMC 01.3 con
	# Dc 125, ap 5, ae 100, fz 0,2 y vf 1000 → Pc = ap·ae·vf·K/100 000 = 27,0 kW (K = 5,4, tabla calculada con
	# η = 0,8, así que kc = 600·0,8·K = 2592 N/mm² y 27,0 kW es la potencia en el motor); con +21° de
	# desprendimiento, ×0,79 → 21,3 kW.
	var base := {
		"work_id": "", "tool_id": "hm_coated", "dc_mm": 125.0, "z": 8, "ap_mm": 5.0, "ae_mm": 100.0,
		"fz_mm": 0.2, "vf_mm_min": 1000.0, "kappa_deg": 45.0, "centered": true,
		"kc_n_mm2": 600.0 * 0.8 * 5.4, "gamma0_deg": 0.0, "gamma_deg": 0.0, "kc_quality": "primary",
		"machine": { "eta": 0.8 },
	}
	var m0 := Cutting.milling(base)
	assert_near(m0["pmotor_kw"], 27.0, 1e-12, 0.0, "27,0 kW en el motor")
	assert_near(m0["pc_kw"], 21.6, 1e-12, 0.0, "21,6 kW netos en el filo")
	assert_eq(Js.to_fixed(m0["pmotor_kw"], 1), "27.0", "como lo imprime Sandvik")
	var g21 := base.duplicate(true)
	g21["gamma_deg"] = 21.0
	var m21 := Cutting.milling(g21)
	assert_near(m21["kc_parts"]["Kgamma"], 0.79, 1e-12, 0.0, "Mγ = 0,79 con +21°")
	assert_eq(Js.to_fixed(m21["pmotor_kw"], 1), "21.3", "27,0 × 0,79 = 21,3 kW")
	# geometría: n = vf/(z·fz) y el espesor medio de una fresa centrada (fórmula de Sandvik)
	assert_near(m0["rpm"], 625.0, 1e-12, 0.0, "n = 1000/(8·0,2)")
	var hm := 0.2 * sin(deg_to_rad(45.0)) * 0.8 / asin(0.8)
	assert_near(m0["hm_mm"], hm, 1e-12, 0.0, "hm = fz·sen κ·(ae/Dc)/asen(ae/Dc)")
	assert_near(m0["torque_nm"], m0["pc_kw"] * 30000.0 / (PI * m0["rpm"]), 1e-12, 0.0, "par = Pc·30 000/(π·n)")
	assert_near(m0["q_cm3_min"], 500.0, 1e-12, 0.0, "Q = ap·ae·vf/1000")


# --- tablas y catálogo --------------------------------------------------------------------------------------


func test_tablas_de_kc_del_tabellenbuch() -> void:
	for id in TZ_K_AT_02:
		var kc: Dictionary = WorkMaterials.get_material(id)["kc"]
		var k := float(kc["kc11"]) * pow(0.2, -float(kc["mc"]))
		assert_near(k, TZ_K_AT_02[id], 0.6 / float(TZ_K_AT_02[id]), 0.0, "k(0,2) de %s" % id)
	for row in TZ_ROW_42CRMO4:
		var r := Cutting.specific_cutting_force({ "kc11": 2500.0, "mc": 0.26, "h_mm": row[0] })
		assert_near(r["k"], row[1], 0.6 / float(row[1]), 0.0, "42CrMo4 a h = %s" % Js.js_num_str(row[0]))


func test_catalogo_con_fuente_y_calidad() -> void:
	var qualities: Array = WorkMaterials.QUALITIES
	for m in WorkMaterials.WORK_MATERIALS:
		_assert_sourced(m, "material %s" % m["id"], qualities)
		for k in m["props_quality"]:
			assert_true(qualities.has(m["props_quality"][k]), "%s: calidad de %s" % [m["id"], k])
		if m["kc"] == null:
			assert_true(str(m.get("kc_reason", "")).length() > 20, "%s: kc null con su motivo" % m["id"])
			continue
		_assert_sourced(m["kc"], "kc de %s" % m["id"], qualities)
		assert_eq(m["kc"]["family"], WorkMaterials.FAMILY_TZ, "%s: una sola familia de kc (TZ)" % m["id"])
		for a in m["kc"]["alt"]:
			_assert_sourced(a, "alternativa de %s" % m["id"], qualities)
		var fc := WorkMaterials.force_components(m)
		_assert_sourced(fc, "kf/kp de %s" % m["id"], qualities)
	for t in ToolMaterials.TOOL_MATERIALS:
		_assert_sourced(t, "herramienta %s" % t["id"], qualities)
		for g in t["iso_groups"]:
			assert_true(t["vc_range"].has(g) and qualities.has(t["vc_quality"][g]), "%s: vc y su calidad en %s" % [t["id"], g])
		var q_ok: bool = qualities.has(t["kvc_quality"]) and qualities.has(t["taylor"]["quality"])
		assert_true(q_ok, "%s: calidad de Kvc y Taylor" % t["id"])
		if t["coating"] != null:
			assert_true(ToolMaterials.COATINGS.has(t["coating"]), "%s: recubrimiento conocido" % t["id"])
	for id in ToolMaterials.COATINGS:
		_assert_sourced(ToolMaterials.COATINGS[id], "recubrimiento %s" % id, qualities)
	for g in ToolMaterials.ISO_GROUPS:
		_assert_sourced(ToolMaterials.ISO_GROUPS[g], "grupo %s" % g, qualities)


func _assert_sourced(d: Dictionary, what: String, qualities: Array) -> void:
	assert_true(str(d.get("source", "")).length() > 10, "%s: lleva fuente" % what)
	assert_true(qualities.has(d.get("quality")), "%s: calidad válida (%s)" % [what, str(d.get("quality"))])


func test_contrato_material_de_pieza() -> void:
	var ids := WorkMaterials.ids()
	for id in METALS_REQUIRED + NON_METALS_REQUIRED:
		assert_true(ids.has(id), "falta el material %s" % id)
	assert_true(WorkMaterials.machinable_ids().size() >= 10, "al menos 10 metales con kc")
	for m in WorkMaterials.WORK_MATERIALS:
		for k in ["id", "name", "iso", "kind", "density", "hv", "rm", "kc", "source", "quality"]:
			assert_true(m.has(k), "%s: falta la clave %s" % [m["id"], k])
		assert_true(WorkMaterials.ISO_LETTERS.has(m["iso"]), "%s: grupo ISO" % m["id"])
		assert_true(WorkMaterials.KINDS.has(m["kind"]), "%s: kind del contrato" % m["id"])
		assert_true(float(m["density"]) > 0.0 and float(m["hv"]) > 0.0, "%s: densidad y dureza positivas" % m["id"])
		assert_true(m["rm"] == null or float(m["rm"]) > 0.0, "%s: Rm positiva o null" % m["id"])
		if m["kc"] != null:
			for k in ["kc11", "mc", "gamma0", "family"]:
				assert_true(m["kc"].has(k), "%s: kc.%s" % [m["id"], k])
	for id in NON_METALS_REQUIRED:
		assert_eq(WorkMaterials.get_material(id)["kc"], null, "%s no tiene kc" % id)
	for id in TOOLS_REQUIRED:
		assert_true(ToolMaterials.ids().has(id), "falta la herramienta %s" % id)
	for id in ["tin", "ticn", "tialn", "alcrn", "dlc"]:
		assert_true(ToolMaterials.COATINGS.has(id), "falta el recubrimiento %s" % id)


func test_grupos_iso_513_y_recubrimientos() -> void:
	var colors := { "P": "azul", "M": "amarillo", "K": "rojo", "N": "verde", "S": "marrón", "H": "gris" }
	for g in colors:
		assert_eq(ToolMaterials.ISO_GROUPS[g]["color_name"], colors[g], "color ISO 513 de %s" % g)
		assert_true(ToolMaterials.ISO_GROUPS[g]["iso513"], "%s es de ISO 513" % g)
	assert_false(ToolMaterials.ISO_GROUPS["O"]["iso513"], "O no es de ISO 513")
	var tin := ToolMaterials.get_coating("tin")
	assert_eq(tin["hv"], 2300.0, "TiN: 2300 HV 0,05 (Balzers)")
	assert_eq(tin["max_temp_c"], 600.0, "TiN: 600 °C")
	assert_eq(ToolMaterials.get_coating("alcrn")["max_temp_c"], 1100.0, "AlCrN: 1100 °C")
	assert_eq(ToolMaterials.get_coating("tialn")["hv"], 3300.0, "TiAlN: 3300 HV")
	var tin_drill := ToolMaterials.get_tool("hss_tin")
	assert_eq(ToolMaterials.surface_hv(tin_drill), 2300.0, "la broca «de titanio» trabaja con su capa de TiN")
	assert_eq(ToolMaterials.get_tool("hss_tin")["hv"], 832.0, "…sobre un sustrato de HSS")


func test_exponentes_de_taylor_del_tabellenbuch() -> void:
	# TZ, p. 215: k = −7 (HSS en acero), −4 (metal duro en acero), −3,5 (en fundición), −2,5 (en aluminio),
	# −2 (cerámica en acero); n = −1/k
	var cases := [
		["hss_m2", "P", 1.0 / 7.0], ["hm", "P", 0.25], ["hm", "K", 1.0 / 3.5], ["hm", "N", 0.4],
		["ceramica_al2o3", "P", 0.5],
	]
	for c in cases:
		var tp := ToolMaterials.taylor_params(ToolMaterials.get_tool(c[0]), c[1])
		assert_near(tp["n"], c[2], 1e-12, 0.0, "n de %s en %s" % [c[0], c[1]])
		assert_eq(tp["n_quality"], "primary", "n de %s en %s sale del TZ" % [c[0], c[1]])
		# en vcT15 la vida es 15 min
		assert_near(Cutting.taylor_life(tp["vc_ref"], tp["n"], tp["C"]), 15.0, 1e-9, 0.0, "T(vcT15) = 15 min")


# --- invariantes --------------------------------------------------------------------------------------------


func test_fc_crece_con_f_y_con_ap() -> void:
	for id in WorkMaterials.machinable_ids():
		var prev := 0.0
		for f in [0.05, 0.1, 0.2, 0.3, 0.5, 0.8]:
			var fc: float = _turn(id, { "f_mm_rev": f })["fc_n"]
			assert_true(fc > prev, "%s: Fc crece con f (f = %s)" % [id, Js.js_num_str(f)])
			prev = fc
		prev = 0.0
		for ap in [0.25, 0.5, 1.0, 2.0, 4.0]:
			var fc: float = _turn(id, { "ap_mm": ap })["fc_n"]
			assert_true(fc > prev, "%s: Fc crece con ap (ap = %s)" % [id, Js.js_num_str(ap)])
			prev = fc


func test_kc_baja_al_crecer_h() -> void:
	for m in WorkMaterials.WORK_MATERIALS:
		for fam in WorkMaterials.kc_families(m):
			var prev := INF
			for h in [0.02, 0.06, 0.1, 0.2, 0.4, 0.8, 1.6]:
				var kc: float = Cutting.specific_cutting_force({ "kc11": fam["kc11"], "mc": fam["mc"], "h_mm": h })["kc"]
				assert_true(kc < prev, "%s (%s): kc baja con h" % [m["id"], fam["source"]])
				prev = kc


func test_rugosidad_proporcional_a_f2_entre_r() -> void:
	var base := Cutting.roughness(0.2, 0.8)
	assert_near(base["rt_um"], 6.25, 1e-12, 0.0, "Rt = 0,2²/(8·0,8) mm = 6,25 µm")
	assert_near(base["ra_um"], 0.04 / (18.0 * sqrt(3.0) * 0.8) * 1000.0, 1e-12, 0.0, "Ra = f²/(18√3·rε)")
	assert_near(base["ra_um"], 0.04 / (32.0 * 0.8) * 1000.0, 0.03, 0.0, "≈ f²/(32·rε) de la bibliografía")
	assert_true(base["ideal"] and base["valid"], "cota ideal y válida con f < rε")
	assert_near(Cutting.roughness(0.4, 0.8)["ra_um"], 4.0 * base["ra_um"], 1e-12, 0.0, "doble avance → Ra ×4")
	assert_near(Cutting.roughness(0.2, 1.6)["ra_um"], base["ra_um"] / 2.0, 1e-12, 0.0, "doble radio → Ra /2")
	assert_false(Cutting.roughness(1.0, 0.4)["valid"], "con f > rε la fórmula deja de valer")
	var t := _turn("c45e", { "f_mm_rev": 0.2, "nose_r_mm": 0.8 })
	assert_near(t["ra_um"], base["ra_um"], 1e-12, 0.0, "el torneado da la misma Ra")


func test_la_vida_baja_al_subir_vc() -> void:
	var prev := INF
	for vc in [60.0, 100.0, 150.0, 200.0, 280.0]:
		var t := _turn("c45e", { "vc": vc })
		assert_true(t["life_min"] < prev, "vida decreciente (vc = %s)" % Js.js_num_str(vc))
		assert_eq(t["life_quality"], "estimate", "la vida es una estimación")
		prev = t["life_min"]
	assert_true(Cutting.taylor_life(100.0, 0.25, 400.0) > Cutting.taylor_life(200.0, 0.25, 400.0), "Taylor directo")


func test_avisos_de_sobrecarga_y_tope_de_giro() -> void:
	var machine := { "pmax_kw": 3.0, "rpm_max": 800.0, "eta": 0.8 }
	var t := _turn("c42crmo4", { "vc": 200.0, "ap_mm": 4.0, "f_mm_rev": 0.4, "machine": machine })
	assert_true(t["rpm_limited"], "1273 rpm pedidas y la máquina llega a 800")
	assert_near(t["rpm"], 800.0, 1e-12, 0.0, "giro recortado")
	assert_near(t["vc"], PI * 50.0 * 800.0 / 1000.0, 1e-12, 0.0, "vc real con el tope")
	assert_true(t["overload"], "más potencia que la máquina")
	assert_true(_has_warning(t, "Tope de giro"), "aviso del tope de giro")
	assert_true(_has_warning(t, "Sobrecarga"), "aviso de sobrecarga")
	var ok := _turn("c45e", { "machine": { "pmax_kw": 50.0, "rpm_max": 4000.0 } })
	assert_false(ok["overload"] or ok["rpm_limited"], "sin avisos en una máquina holgada")


func _has_warning(res: Dictionary, text: String) -> bool:
	for w in res["warnings"]:
		if str(w).contains(text):
			return true
	return false


func test_banda_de_incertidumbre() -> void:
	# familia de Sandvik (solo para la banda): CMC 01.2 (C 0,25-0,55 %), K = 6,1 / 5,1 / 4,3 → mc ≈ 0,25, y el
	# ajuste reproduce K a fz = 0,2
	var fam := WorkMaterials.sandvik_family([6.1, 5.1, 4.3])
	assert_near(fam["mc"], 0.2523, 2e-3, 0.0, "mc de la tabla de K")
	var hm := 0.2 * sin(deg_to_rad(45.0)) * 0.8 / asin(0.8)
	var k_back := float(fam["kc11"]) * pow(hm, -float(fam["mc"])) / (600.0 * 0.8)
	assert_near(k_back, 5.1, 0.02, 0.0, "K(fz = 0,2) recuperado")
	assert_eq(fam["gamma0"], 0.0, "la base de Sandvik es 0°")
	for id in WorkMaterials.machinable_ids():
		var t := _turn(id)
		var band: Array = t["band"]
		assert_true(band[0] <= t["kc"] and t["kc"] <= band[1], "%s: la banda contiene kc" % id)
		assert_true(band[1] > band[0], "%s: la banda tiene anchura (hay más de una fuente)" % id)


func test_modelo_inyectable_del_torno() -> void:
	var model := Cutting.model_callable()
	assert_true(model.is_valid(), "Callable válido")
	var r: Dictionary = model.call("c42crmo4", "hm", 0.2, 2.0, 180.0)
	assert_true(r["ok"], "42CrMo4 con metal duro")
	assert_near(r["kc"], 3799.0, 0.5 / 3799.0, 0.0, "filo nuevo, γ0 y torneado exterior: el valor de tabla")
	assert_near(r["fc_n"], r["kc"] * 0.2 * 2.0, 1e-12, 0.0, "Fc = kc·b·h")
	assert_true(r["vc_ok"], "180 m/min está en el intervalo del metal duro en acero")
	var zero: Dictionary = model.call("c42crmo4", "hm", 0.0, 2.0, 180.0)
	assert_eq(zero["fc_n"], 0.0, "sin viruta no hay fuerza")
	assert_true(is_finite(zero["kc"]), "kc finito aunque h = 0")
	var glass: Dictionary = model.call("vidrio", "hm", 0.2, 2.0, 180.0)
	assert_false(glass["ok"], "el vidrio no se corta con filo definido")
	assert_eq([glass["kc"], glass["fc_n"], glass["ff_n"]], [0.0, 0.0, 0.0], "fuerzas finitas: nada de NaN al torno")
	assert_true(str(glass["reason"]).length() > 20, "con el motivo para enseñarlo")
	var again: Dictionary = model.call("c42crmo4", "hm", 0.2, 2.0, 180.0)
	assert_eq(again["kc"], r["kc"], "la memoria da el mismo resultado")


# --- avisos y calidad (revisión de código) -------------------------------------------------------------------


func test_calidad_baja_con_datos_estimados() -> void:
	assert_eq(_turn("c42crmo4", { "wear": "medio" })["quality"], "estimate", "Kver «medio» es una interpolación")
	assert_eq(_turn("c42crmo4", { "wear": "fuerte", "gamma_deg": 18.0 })["quality"], "primary", "acero: γ0 del TZ")
	assert_eq(_turn("ti6al4v", { "gamma_deg": 15.0 })["quality"], "estimate", "titanio: γ0 = 6° es un supuesto")
	assert_eq(_turn("ti6al4v")["quality"], "primary", "sin cambiar γ, γ0 no interviene")


func test_entradas_raras_avisan_y_no_rompen() -> void:
	var t := _turn("c45e", { "machine": null })
	assert_true(t["fc_n"] > 0.0, "machine = null es como no dar máquina")
	var up := _turn("c45e", { "wear": "Fuerte", "process": "Tronzado" })
	assert_near(up["kc_parts"]["Kver"], 1.5, 1e-12, 0.0, "nombres sin distinguir mayúsculas")
	assert_near(up["kc_parts"]["Ksp"], 1.3, 1e-12, 0.0, "tronzado")
	var bad := _turn("c45e", { "wear": "gastadísimo", "process": "mágico" })
	assert_true(_has_warning(bad, "gastadísimo") and _has_warning(bad, "mágico"), "avisa de lo que no conoce")
	var still := _turn("c45e", { "vc": null })
	assert_eq(still["fc_n"], null, "sin velocidad no hay fuerzas ni potencia")
	assert_true(_has_warning(still, "Falta la velocidad"), "y lo dice")
	var zero := _turn("c45e", { "vc": null, "rpm": 0.0 })
	assert_true(_has_warning(zero, "Falta la velocidad") and zero["pc_kw"] == null, "rpm = 0 tampoco")
	var d0 := Cutting.drilling({ "work_id": "c45e", "tool_id": "hss_m2", "d_mm": 10.0, "f_mm_rev": 0.2 })
	assert_eq(d0["torque_nm"], null, "taladrado sin velocidad")
	var m := Cutting.milling({
		"work_id": "c45e", "tool_id": "pcd", "dc_mm": 63.0, "z": 5, "vc": 200.0, "fz_mm": 0.1, "ap_mm": 2.0,
		"ae_mm": 40.0, "kc_n_mm2": 2000.0,
	})
	assert_true(_has_warning(m, "no es un material de corte indicado"), "con kc propio también revisa la herramienta")


func test_ff_y_fp_crecen_con_el_avance() -> void:
	# Salvo el 6082, cuyo mf = 1,08 del TZ (AlMg4SiMn) hace Ff casi independiente de f: ver fuentes-u5.md
	for id in WorkMaterials.machinable_ids():
		var fcomp := WorkMaterials.force_components(WorkMaterials.get_material(id))
		if float(fcomp["mf"]) >= 1.0:
			continue
		var prev := Vector2.ZERO
		for f in [0.05, 0.1, 0.2, 0.4, 0.8]:
			var t := _turn(id, { "f_mm_rev": f })
			assert_true(t["ff_n"] > prev.x and t["fp_n"] > prev.y, "%s: Ff y Fp crecen con f" % id)
			prev = Vector2(t["ff_n"], t["fp_n"])
		assert_true(_turn(id)["sources"].has(str(fcomp["source"])), "%s: cita la fuente de Ff y Fp" % id)


func test_materiales_sin_kc() -> void:
	for id in NON_METALS_REQUIRED:
		var t := _turn(id)
		assert_eq(t["fc_n"], null, "%s: sin Fc" % id)
		assert_eq(t["pc_kw"], null, "%s: sin potencia" % id)
		assert_true(_has_warning(t, "Sin fuerza de corte"), "%s: explica por qué" % id)
		assert_near(t["ra_um"], Cutting.roughness(0.2, 0.8)["ra_um"], 1e-12, 0.0, "%s: la rugosidad teórica sí" % id)


func test_taladrado_y_fresado_coherentes() -> void:
	var d := Cutting.drilling({ "work_id": "c45e", "tool_id": "hss_m2", "d_mm": 10.0, "vc": 25.0, "f_mm_rev": 0.2 })
	var kc: float = d["kc"]
	assert_near(d["pc_kw"], 0.2 * 25.0 * 10.0 * kc / 240000.0, 1e-12, 0.0, "Pc = fn·vc·Dc·kc/240 000 (Sandvik)")
	assert_near(d["torque_nm"], d["pc_kw"] * 30000.0 / (PI * d["rpm"]), 1e-9, 0.0, "Mc = Pc·30 000/(π·n)")
	var thrust := 0.5 * kc * 5.0 * 0.2 * sin(deg_to_rad(59.0))
	assert_near(d["thrust_n"], thrust, 1e-12, 0.0, "empuje de Sandvik con σ = 118°")
	assert_near(d["kc_parts"]["Ksp"], 1.2, 1e-12, 0.0, "Ksp del taladrado")
	assert_near(d["kc_parts"]["Kvc"], 1.2, 1e-12, 0.0, "Kvc del HSS")
	var prev := 0.0
	for f in [0.05, 0.1, 0.2, 0.3]:
		var drill := { "work_id": "c45e", "tool_id": "hss_m2", "d_mm": 10.0, "vc": 25.0, "f_mm_rev": f }
		var th: float = Cutting.drilling(drill)["thrust_n"]
		assert_true(th > prev, "el empuje crece con el avance")
		prev = th
	var mill := {
		"work_id": "c42crmo4", "tool_id": "hm_coated", "dc_mm": 63.0, "z": 5, "vc": 200.0, "fz_mm": 0.15,
		"ap_mm": 3.0, "ae_mm": 20.0, "centered": false,
	}
	var m := Cutting.milling(mill)
	assert_near(m["kc_parts"]["Ksp"], 1.2, 1e-12, 0.0, "Ksp del fresado")
	assert_near(m["tooth_hz"], 5.0 * m["rpm"] / 60.0, 1e-12, 0.0, "frecuencia de paso de diente")
	var x := 20.0 / 63.0
	var phi := acos(1.0 - 2.0 * x)
	assert_near(m["hm_mm"], 0.15 * 2.0 * x / phi, 1e-12, 0.0, "hm del fresado lateral (geometría exacta)")
	mill["ae_mm"] = 30.0
	var wider := Cutting.milling(mill)
	assert_true(wider["pc_kw"] > m["pc_kw"], "más ancho de corte, más potencia")


# --- fresado y taladrado para la interfaz (fase 2, unidad 1e) -------------------------------------------------


## Sandvik Coromant, Metalcutting Technical Guide (D) Milling (2005), pp. D22 y D27-D28: ejemplos resueltos de giro,
## avance de mesa y espesor máximo de viruta, con los números como los imprime Sandvik (redondeados).
func test_ejemplos_resueltos_de_fresado_sandvik() -> void:
	var face := {
		"work_id": "c45e", "tool_id": "hm_coated", "dc_mm": 125.0, "z": 8, "vc": 283.0, "fz_mm": 0.24, "ap_mm": 4.0,
		"ae_mm": 85.0, "kappa_deg": 45.0, "centered": true,
	}
	var a := Cutting.milling(face)
	assert_near(a["rpm"], 721.0, 0.5 / 721.0, 0.0, "planeado R245-125Q40-12M: n ≈ 721 rpm")
	assert_near(a["vf_mm_min"], 1384.0, 0.5 / 1384.0, 0.0, "vf ≈ 1384 mm/min")
	assert_near(a["hex_mm"], 0.17, 0.003, 0.0, "hex = fz·sen 45° ≈ 0,17 mm")
	face["vc"] = 262.0  # «Selecting cutting data»: HB 180, vc compensada 0,925 × 283 ≈ 262 m/min
	var b := Cutting.milling(face)
	assert_near(b["rpm"], 667.0, 0.5 / 667.0, 0.0, "n = 667 rpm (p. D22)")
	assert_near(b["vf_mm_min"], 1281.0, 0.5 / 1281.0, 0.0, "vf = 8 × 667 × 0,24 ≈ 1281 mm/min")
	var slot := Cutting.milling({
		"work_id": "c45e", "tool_id": "hm_coated", "dc_mm": 63.0, "z": 5, "vc": 250.0, "fz_mm": 0.15, "ap_mm": 5.0,
		"ae_mm": 50.0, "kappa_deg": 90.0, "centered": true,
	})
	assert_near(slot["rpm"], 1263.0, 0.5 / 1263.0, 0.0, "ranurado R390-063Q22-17M: n ≈ 1263 rpm")
	assert_near(slot["vf_mm_min"], 947.0, 0.5 / 947.0, 0.0, "vf = 1263 × 0,15 × 5 ≈ 947 mm/min")
	assert_near(slot["hex_mm"], 0.15, 1e-12, 0.0, "κ 90° con ae/Dc > 0,5: hex = fz")
	# Planeado lateral con ae = 5 mm: Sandvik sube fz con el factor k1 = 1,82 de su tabla (Dc/ae = 12,6) para que hex
	# siga siendo 0,15; la geometría exacta del contacto da k1 = 1,85, así que con el fz de Sandvik hex sale un 1,6 %
	# menor (docs/taller/pulido-taller.md)
	var side := Cutting.milling({
		"work_id": "c45e", "tool_id": "hm_coated", "dc_mm": 63.0, "z": 5, "vc": 318.0, "fz_mm": 0.15 * 1.82, "ap_mm": 5.0,
		"ae_mm": 5.0, "kappa_deg": 90.0, "centered": false,
	})
	assert_near(side["rpm"], 1607.0, 0.5 / 1607.0, 0.0, "planeado lateral: n ≈ 1607 rpm")
	assert_near(side["vf_mm_min"], 2193.0, 0.5 / 2193.0, 0.0, "vf = 1,82 × 5 × 1607 × 0,15 ≈ 2193 mm/min")
	assert_near(side["hex_mm"], 0.15, 0.02, 0.0, "hex ≈ 0,15 mm (tabla de k1 frente a geometría exacta)")
	var k1_exact := 1.0 / sin(acos(1.0 - 2.0 * 5.0 / 63.0))
	assert_near(k1_exact, 1.82, 0.02, 0.0, "k1 exacto frente a la tabla de Sandvik")


## Sandvik Coromant, fórmulas de taladrado (web): Dc 20 mm a 200 m/min → 3184 rpm (Sandvik redondea hacia arriba);
## vf = fn·n; Q = Dc·fn·vc/4. El TZ (p. 204) calcula Q = A·vc con A = D·f/2, que es el doble del volumen que se arranca
## (el filo corta, de media, a vc/2): el modelo sigue a Sandvik.
func test_taladrado_sandvik_y_caudal() -> void:
	var d := Cutting.drilling({ "work_id": "c45e", "tool_id": "hm", "d_mm": 20.0, "vc": 200.0, "f_mm_rev": 0.2 })
	assert_near(d["rpm"], 3184.0, 1.0 / 3184.0, 0.0, "n ≈ 3184 rpm")
	assert_near(d["vf_mm_min"], 0.2 * d["rpm"], 1e-12, 0.0, "vf = fn·n")
	var tz := Cutting.drilling({ "work_id": "c45e", "tool_id": "hm", "d_mm": 40.0, "vc": 100.0, "f_mm_rev": 0.16 })
	var true_q: float = PI * 40.0 * 40.0 / 4.0 * 0.16 * float(tz["rpm"]) / 1000.0
	assert_near(tz["q_cm3_min"], true_q, 1e-12, 0.0, "Q = volumen del agujero por minuto (π·D²/4·f·n)")
	assert_near(tz["q_cm3_min"], 40.0 * 0.16 * 100.0 / 4.0, 1e-12, 0.0, "= Dc·fn·vc/4 (Sandvik)")
	assert_near(3.2 * 100.0, 2.0 * tz["q_cm3_min"], 1e-12, 0.0, "el A·vc del TZ es el doble")


## Tablas orientativas de potencia del TZ (p. 212, «acero de resistencia media», metal duro). No siguen el Kienzle del
## propio TZ (en torneado Fc = 36·d sin depender de f; en taladrado Fc/(D·f) va de 720 a 1680 N/mm²), así que solo
## sirven como orden de magnitud contra errores de unidades: el modelo con C45E queda dentro de un factor 2.
func test_tablas_orientativas_del_tabellenbuch() -> void:
	for row in [[2.0, 0.1, 144.0, 0.2], [6.0, 0.1, 864.0, 1.2], [10.0, 0.2, 2160.0, 2.9], [16.0, 0.2, 4608.0, 6.1], [20.0, 0.3, 7200.0, 9.6]]:
		var r := Cutting.drilling({ "work_id": "c45e", "tool_id": "hm", "d_mm": row[0], "vc": 80.0, "f_mm_rev": row[1] })
		var k: float = row[2] / r["fc_edge_n"]
		assert_true(k > 0.5 and k < 2.0, "taladrado Ø%s: TZ %s N, modelo %s N por filo" % [row[0], row[2], Js.to_fixed(r["fc_edge_n"], 0)])
		assert_near(r["pc_kw"], r["fc_edge_n"] * 80.0 / 60000.0, 1e-12, 0.0, "P = Fc·vc como en el TZ")
	for row in [[50.0, 6, 0.08, 842.9], [100.0, 10, 0.2, 3512.1], [160.0, 14, 0.23, 5654.4]]:
		var r := Cutting.milling({
			"work_id": "c45e", "tool_id": "hm_coated", "dc_mm": row[0], "z": row[1], "vc": 220.0, "fz_mm": row[2],
			"ap_mm": 3.5, "ae_mm": row[0] * 2.0 / 3.0, "kappa_deg": 45.0, "gamma_deg": 12.0, "centered": false,
		})
		var k: float = row[3] / r["fc_mean_n"]
		assert_true(k > 0.5 and k < 2.0, "planeado Ø%s: TZ %s N, modelo %s N" % [row[0], row[3], Js.to_fixed(r["fc_mean_n"], 0)])
	for row in [[20.0, 0.1, 720.0], [50.0, 0.3, 1800.0], [100.0, 0.5, 3600.0]]:
		var r := _turn("c45e", { "d_mm": row[0], "vc": 220.0, "f_mm_rev": row[1], "ap_mm": 3.0, "kappa_deg": 45.0, "gamma_deg": 18.0 })
		var k: float = row[2] / r["fc_n"]
		assert_true(k > 0.5 and k < 2.0, "torneado Ø%s: TZ %s N, modelo %s N" % [row[0], row[2], Js.to_fixed(r["fc_n"], 0)])


## Lo que enseñan las páginas de fresado y taladrado (unidad 1e): todos los campos existen y, con datos válidos, son
## números finitos (docs/taller/pulido-taller.md → guía de integración).
func test_campos_para_la_interfaz_de_fresado_y_taladrado() -> void:
	var m := Cutting.milling({
		"work_id": "c42crmo4", "tool_id": "hm_coated", "dc_mm": 63.0, "z": 5, "vc": 200.0, "fz_mm": 0.15, "ap_mm": 3.0,
		"ae_mm": 20.0, "centered": false, "machine": { "pmax_kw": 11.0, "rpm_max": 6000.0 },
	})
	for k in ["rpm", "vc", "vf_mm_min", "fz_mm", "hm_mm", "hex_mm", "zc", "kc", "fc_mean_n", "pc_kw", "pmotor_kw",
			"torque_nm", "q_cm3_min", "tooth_hz", "life_min"]:
		assert_true(m[k] != null and is_finite(float(m[k])) and float(m[k]) > 0.0, "fresado: %s" % k)
	for k in ["band", "kc_parts", "quality", "life_quality", "overload", "rpm_limited", "sources", "warnings"]:
		assert_true(m.has(k), "fresado: %s" % k)
	var d := Cutting.drilling({
		"work_id": "c45e", "tool_id": "hss_m2", "d_mm": 10.0, "vc": 25.0, "f_mm_rev": 0.2,
		"machine": { "pmax_kw": 1.5, "rpm_max": 3000.0 },
	})
	for k in ["rpm", "vc", "vf_mm_min", "h_mm", "kc", "fc_edge_n", "thrust_n", "torque_nm", "pc_kw", "pmotor_kw",
			"q_cm3_min", "life_min"]:
		assert_true(d[k] != null and is_finite(float(d[k])) and float(d[k]) > 0.0, "taladrado: %s" % k)
	for k in ["band", "kc_parts", "quality", "life_quality", "overload", "rpm_limited", "sources", "warnings"]:
		assert_true(d.has(k), "taladrado: %s" % k)
	for key in Cutting.MILLING_KEYS:
		assert_true(m.has(key), "MILLING_KEYS: %s" % key)
	for key in Cutting.DRILLING_KEYS:
		assert_true(d.has(key), "DRILLING_KEYS: %s" % key)


# --- multinúcleo (CONTRATOS.md → «Rendimiento y multinúcleo») ------------------------------------------------


## Ejecuta fn(i) para i en [0, n) en `threads` tareas de WorkerThreadPool (el patrón de tools/bench.gd) y devuelve los
## resultados en orden.
func _parallel(fn: Callable, n: int, threads: int) -> Array:
	var out: Array = []
	out.resize(n)
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var r: Variant = fn.call(i)
		mutex.lock()
		out[i] = r
		mutex.unlock()
	var id := WorkerThreadPool.add_group_task(task, n, threads, true, "test_cutting")
	WorkerThreadPool.wait_for_group_task_completion(id)
	return out


## El modelo que se inyecta en el torno se consulta a la vez desde varios hilos (simulación rápida y barridos) y da,
## al bit, lo mismo que en un solo hilo; también con parejas que no están en los catálogos.
func test_modelo_del_torno_seguro_entre_hilos() -> void:
	var queries: Array = []
	for w in WorkMaterials.ids() + ["no-existe"]:
		for t in ToolMaterials.ids() + ["tampoco"]:
			for h in [0.0, 0.004, 0.12, 0.4]:
				queries.append([w, t, h, 2.0, 150.0])
	var run := func(i: int) -> Dictionary:
		var q: Array = queries[i]
		return Cutting.cutting_model(q[0], q[1], q[2], q[3], q[4])
	var seq: Array = []
	for i in queries.size():
		seq.append(run.call(i))
	for threads in [2, 4, 8]:
		var par := _parallel(run, queries.size(), threads)
		assert_true(same(par, seq), "cutting_model con %d hilos = secuencial (%d consultas)" % [threads, queries.size()])
	# Las funciones completas tampoco comparten estado: torneado, fresado y taladrado en paralelo
	var calls: Array[Callable] = []
	for id in WorkMaterials.ids():
		calls.append(func() -> Dictionary: return _turn(id, { "wear": "ligero" }))
		calls.append(func() -> Dictionary: return Cutting.milling({
			"work_id": id, "tool_id": "hm_coated", "dc_mm": 63.0, "z": 5, "vc": 200.0, "fz_mm": 0.15, "ap_mm": 3.0,
			"ae_mm": 20.0, "centered": false }))
		calls.append(func() -> Dictionary: return Cutting.drilling({
			"work_id": id, "tool_id": "hss_m2", "d_mm": 10.0, "vc": 25.0, "f_mm_rev": 0.2 }))
	var full_seq: Array = []
	for c in calls:
		full_seq.append(c.call())
	var full_par := _parallel(func(i: int) -> Dictionary: return calls[i].call(), calls.size(), 4)
	assert_true(same(full_par, full_seq), "turning, milling y drilling en 4 hilos = secuencial")


## La tabla precalculada de cutting_model da lo mismo que calcular cada pareja en el momento, y es de solo lectura.
func test_tabla_del_modelo_de_solo_lectura() -> void:
	var table: Dictionary = Cutting._model_table
	assert_true(table.is_read_only(), "tabla congelada: nadie la puede escribir")
	assert_eq(table.size(), WorkMaterials.ids().size() * ToolMaterials.ids().size(), "todas las parejas de los catálogos")
	for w in WorkMaterials.ids():
		for t in ToolMaterials.ids():
			var e: Dictionary = table[w + "|" + t]
			assert_true(e.is_read_only(), "%s|%s congelada" % [w, t])
			assert_true(same(e, Cutting._model_entry(w, t)), "%s|%s: igual que calcularla en el momento" % [w, t])


## Kver numérico: 1 y el intervalo 1,2-1,5 del TZ son «secondary»; entre 1 y 1,2 es el filo que se va gastando
## (core/taller/wear.gd), una interpolación sin aviso; fuera de 1-1,5, aviso.
func test_kver_numerico_del_desgaste() -> void:
	var mid := _turn("c45e", { "wear": 1.1 })
	assert_near(mid["kc_parts"]["Kver"], 1.1, 1e-12, 0.0, "Kver = 1,1 aplicado")
	assert_false(_has_warning(mid, "fuera del intervalo"), "1,1 no avisa: es la interpolación del desgaste")
	assert_eq(mid["quality"], "estimate", "pero es una estimación")
	var tz := _turn("c45e", { "wear": 1.3 })
	assert_false(_has_warning(tz, "fuera del intervalo"), "1,3 está en el intervalo del TZ")
	for k in [0.9, 1.6]:
		assert_true(_has_warning(_turn("c45e", { "wear": k }), "fuera del intervalo"), "Kver = %s avisa" % Js.js_num_str(k))
	var new_fc: float = _turn("c45e")["fc_n"]
	assert_near(mid["fc_n"], 1.1 * new_fc, 1e-12, 0.0, "Fc proporcional a Kver")
