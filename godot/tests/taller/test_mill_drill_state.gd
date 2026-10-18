## Estado de la fresadora y del taladro (core/taller/mill_drill_state.gd): los resultados son exactamente los de
## cutting.gd con esos parámetros, la geometría que dibujan los esquemas sale de la salida del modelo (arco de contacto,
## hm, hex, b·h = D·f/4), los barridos dan lo mismo con 1 hilo que con N, las máquinas llevan su ficha y el sonido
## recibe el paso de dientes y la carga reales.
extends "res://tests/case.gd"

const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")


func _state() -> MillDrillState:
	var md := MillDrillState.new()
	md.threaded = false
	md.wait_sweeps()  # los del constructor, si iban en hilos
	return md


func _has(list: Array, text: String) -> bool:
	for w in list:
		if str(w).contains(text):
			return true
	return false


func test_por_defecto_es_el_modelo_de_corte() -> void:
	var md := _state()
	assert_eq(var_to_str(md.mill_result), var_to_str(Cutting.milling(md.mill_request())), "fresado = Cutting.milling")
	assert_eq(var_to_str(md.drill_result), var_to_str(Cutting.drilling(md.drill_request())), "taladrado = Cutting.drilling")
	# El ensayo de partida corta de verdad y cabe en cada máquina
	assert_true(md.mill_result["pc_kw"] != null and float(md.mill_result["pc_kw"]) > 0.0, "la fresa corta")
	assert_false(md.mill_result["overload"], "la Lagun FTV 2 da la potencia del ensayo de partida")
	assert_false(md.drill_result["overload"], "el taladro también")
	assert_near(md.mill_result["rpm"], 180.0 * 1000.0 / (PI * 63.0), 1e-12, 0.0, "n = 1000·vc/(π·D)")
	var req := md.mill_request()
	assert_eq(req["machine"], { "pmax_kw": 3.7, "rpm_max": 4000.0, "eta": 0.8 }, "la máquina de la ficha va al modelo")
	assert_true(bool(req["centered"]), "fresa centrada")
	var md2 := _state()
	assert_eq(var_to_str(md2.mill_result), var_to_str(md.mill_result), "determinista")


func test_fichas_de_las_maquinas() -> void:
	for kind in MillDrillState.KINDS:
		var f := MillDrillState.machine_ficha(kind)
		assert_true(str(f["source"]).length() > 40, "%s: ficha con fuente" % kind)
		assert_true(str(f["quality"]) in WorkMaterials.QUALITIES, "%s: calidad" % kind)
		assert_true(float(f["rpm_min"]) < float(f["rpm_max"]), "%s: giro mínimo < máximo" % kind)
	assert_eq(MillDrillState.machine_ficha("mill")["pmax_kw"], 3.7, "Lagun FTV 2: 3,7 kW")
	assert_eq(MillDrillState.machine_ficha("drill")["rpm_max"], 2010.0, "ERLO TSAR-32: 2010 rpm")


func test_sobrecarga_y_ficha_de_la_maquina() -> void:
	var md := _state()
	md.set_machine_param("mill", "pmax_kw", 0.5)
	assert_false(md.machine_is_ficha("mill"), "máquina cambiada")
	assert_true(md.mill_result["overload"], "0,5 kW no bastan")
	assert_true(_has(md.mill_result["warnings"], "Sobrecarga"), "el modelo lo avisa")
	md.reset_machine("mill")
	assert_true(md.machine_is_ficha("mill"), "otra vez la ficha")
	assert_false(md.mill_result["overload"], "sin sobrecarga")
	md.set_machine_param("drill", "eta", 0.7)
	assert_near(md.drill_result["pmotor_kw"], float(md.drill_result["pc_kw"]) / 0.7, 1e-12, 0.0, "motor = Pc/η")
	md.set_machine_param("drill", "desconocido", 3.0)
	assert_false(md.drill_machine.has("desconocido"), "solo pmax_kw, rpm_max y eta")


func test_tope_de_giro_y_modo_rpm() -> void:
	var md := _state()
	var rpm0 := float(md.mill_result["rpm"])
	md.set_mill("speed_mode", "rpm")
	assert_eq(float(md.mill["rpm"]), rpm0, "al pasar a rpm se conserva el giro")
	assert_near(md.mill_result["vc"], 180.0, 1e-12, 0.0, "y la misma vc")
	md.set_mill("rpm", 6000.0)
	assert_eq(float(md.mill_result["rpm"]), 4000.0, "la Lagun FTV 2 no pasa de 4000 rpm")
	assert_true(bool(md.mill_result["rpm_limited"]), "tope de giro")
	assert_true(_has(md.mill_result["warnings"], "Tope de giro"), "avisado por el modelo")
	md.set_mill("speed_mode", "vc")
	assert_near(md.mill["vc"], Cutting.vc_from_rpm(4000.0, 63.0), 1e-12, 0.0, "al volver a vc, la del giro recortado")
	md.set_mill("speed_mode", "rpm")
	md.set_mill("rpm", 30.0)
	assert_true(_has(md.machine_notes("mill"), "no gira por debajo de 50 rpm"), "giro mínimo de la ficha")


func test_tipo_de_fresa_y_materiales_de_corte() -> void:
	var md := _state()
	md.set_mill("tool_type", "mango")
	assert_eq(md.mill["dc_mm"], 16.0, "ensayo de partida de la fresa de mango")
	assert_eq(md.mill["kappa_deg"], 90.0, "κr 90°")
	assert_eq(md.mill["position"], "concordancia", "lateral en concordancia")
	md.set_mill("tool_id", "cbn")
	assert_eq(md.mill["tool_id"], "hm_coated", "no hay fresas de mango enterizas de CBN en el catálogo")
	md.set_mill("tool_id", "hss_co_m42")
	assert_eq(md.mill["tool_id"], "hss_co_m42", "HSS-Co sí")
	md.set_mill("kappa_deg", 45.0)
	assert_eq(md.mill["kappa_deg"], 90.0, "la de mango solo tiene 90°")
	md.set_mill("tool_type", "planear")
	md.set_mill("kappa_deg", 90.0)
	assert_eq(md.mill["kappa_deg"], 90.0, "la de planear escuadra a 90°")
	md.set_mill("position", "inventada")
	assert_eq(md.mill["position"], "centrada", "posición desconocida: se ignora")
	md.set_drill("tool_id", "pcd")
	assert_eq(md.drill["tool_id"], "hss_m2", "broca de PCD: no está en el catálogo de brocas")
	for id in MillDrillState.DRILL_TOOL_IDS:
		assert_false(ToolMaterials.get_tool(id).is_empty(), "broca de %s en el catálogo" % id)


func test_ae_nunca_pasa_del_diametro() -> void:
	var md := _state()
	md.set_mill("ae_mm", 100.0)
	assert_eq(md.mill["ae_mm"], 63.0, "ae = Dc como mucho")
	md.set_mill("dc_mm", 50.0)
	assert_eq(md.mill["ae_mm"], 50.0, "al bajar el diámetro, ae baja con él")
	assert_false(_has(md.mill_result["warnings"], "supera el diámetro"), "el modelo ya no tiene que limitarlo")


func test_arco_de_contacto_y_espesor_de_viruta() -> void:
	var md := _state()
	var dc := 63.0
	var ae := 40.0
	var eng := md.mill_engagement()
	assert_near(eng["phi_in"], acos(ae / dc), 1e-12, 1e-12, "centrada: entra en acos(ae/Dc)")
	assert_near(eng["phi_out"], PI - acos(ae / dc), 1e-12, 1e-12, "y sale simétrica")
	assert_near(eng["ae_mm"], ae, 1e-9, 1e-9, "el ancho que usó el modelo")
	assert_eq(eng["material_side"], 0, "centrada")
	_check_h(eng, "centrada")
	md.set_mill("position", "oposicion")
	eng = md.mill_engagement()
	var dphi := acos(1.0 - 2.0 * ae / dc)
	assert_near(eng["phi_in"], 0.0, 0.0, 1e-15, "oposición: entra en φ = 0")
	assert_near(eng["phi_out"], dphi, 1e-12, 1e-12, "y sale en acos(1 − 2·ae/Dc)")
	assert_eq(float(eng["entry_h_mm"]), 0.0, "entra con espesor cero")
	assert_near(eng["exit_h_mm"], float(eng["h_scale_mm"]) * sin(dphi), 1e-12, 0.0, "sale con la viruta gruesa")
	assert_eq(eng["climb"], false, "no es concordancia")
	_check_h(eng, "oposición")
	var pc_up := float(md.mill_result["pc_kw"])
	md.set_mill("position", "concordancia")
	eng = md.mill_engagement()
	assert_near(eng["phi_in"], PI - dphi, 1e-12, 1e-12, "concordancia: entra en π − Δφ")
	assert_near(eng["phi_out"], PI, 1e-15, 0.0, "y sale en π")
	assert_near(eng["entry_h_mm"], float(eng["h_scale_mm"]) * sin(dphi), 1e-9, 0.0, "entra con la viruta gruesa")
	assert_true(float(eng["exit_h_mm"]) < 1e-12, "sale con espesor cero")
	assert_eq(eng["material_side"], -1, "la pieza al otro lado")
	_check_h(eng, "concordancia")
	assert_eq(float(md.mill_result["pc_kw"]), pc_up, "el modelo no distingue concordancia de oposición")
	assert_near(eng["ae_mm"], ae, 1e-9, 1e-9, "lateral: el mismo ae")
	# κr = 45°: la viruta es más fina (h = fz·sen κ·sen φ)
	md.set_mill("position", "centrada")
	assert_near(md.mill_engagement()["h_scale_mm"], 0.12 * sin(deg_to_rad(45.0)), 1e-12, 0.0, "fz·sen κ")


## La media de h(φ) en el arco es el hm del modelo y su máximo, el hex.
func _check_h(eng: Dictionary, what: String) -> void:
	var hs := float(eng["h_scale_mm"])
	var a := float(eng["phi_in"])
	var b := float(eng["phi_out"])
	assert_near(hs * (cos(a) - cos(b)) / (b - a), float(eng["hm_mm"]), 1e-9, 0.0, "%s: media de h = hm" % what)
	var hmax := hs if a <= PI / 2.0 and b >= PI / 2.0 else hs * maxf(sin(a), sin(b))
	assert_near(hmax, float(eng["hex_mm"]), 1e-9, 0.0, "%s: máximo de h = hex" % what)
	var s: PackedFloat64Array = eng["h_samples"]
	assert_eq(s.size(), MillDrillState.H_SAMPLES, "%s: muestras de h(φ)" % what)
	assert_near(s[(s.size() - 1) / 2], hs, 1e-12, 0.0, "%s: h(90°) = fz·sen κ" % what)


func test_geometria_de_la_broca() -> void:
	var md := _state()
	var g := md.drill_geometry()
	var d := 10.0
	var f := 0.1
	var sigma := 118.0
	assert_near(float(g["b_mm"]) * float(g["h_mm"]), d * f / 4.0, 1e-12, 0.0, "b·h = D·f/4 por filo")
	assert_near(g["area_mm2"], d * f / 4.0, 1e-12, 0.0, "área por filo")
	assert_near(g["h_mm"], (f / 2.0) * sin(deg_to_rad(sigma / 2.0)), 1e-12, 0.0, "h del modelo")
	assert_near(g["fz_mm"], f / 2.0, 1e-15, 0.0, "cada filo corta la mitad del avance")
	assert_near(g["tip_mm"], (d / 2.0) / tan(deg_to_rad(sigma / 2.0)), 1e-12, 0.0, "largo de la punta")
	var vf := float(md.drill_result["vf_mm_min"])
	assert_near(g["time_s"], (25.0 + float(g["tip_mm"])) / vf * 60.0, 1e-12, 0.0, "tiempo del agujero")
	assert_eq(g["point_rec"]["value"], 118.0, "acero: punta de 118° (tablas del afilado)")
	assert_eq(g["helix"]["type"], "N", "acero: hélice normal")
	md.set_drill("work_id", "al6082_t6")
	g = md.drill_geometry()
	assert_eq(g["point_rec"]["value"], 140.0, "aluminio: 140°")
	assert_eq(g["helix"]["type"], "W", "aluminio: hélice larga")
	md.set_drill("work_id", "ti6al4v")
	assert_true(md.drill_geometry()["point_rec"].is_empty(), "titanio: las fuentes del afilado no lo dan")
	md.set_drill("d_mm", 40.0)
	assert_true(_has(md.machine_notes("drill"), "Ø32 como máximo"), "capacidad del taladro")


func test_barrido_igual_con_uno_y_con_n_hilos() -> void:
	var md := _state()
	for kind in MillDrillState.KINDS:
		for key in MillDrillState.SWEEP_AXES[kind]:
			var base := md.mill_request() if kind == "mill" else md.drill_request()
			var xs := md.sweep_values(kind, key)
			var one := MillDrillState.run_sweep(kind, base, key, xs, 1)
			var many := MillDrillState.run_sweep(kind, base, key, xs, 4)
			assert_eq(one.size(), MillDrillState.SWEEP_POINTS, "%s/%s: puntos" % [kind, key])
			assert_eq(var_to_str(many), var_to_str(one), "%s/%s: 4 hilos = 1 hilo, al bit" % [kind, key])
	# El camino asíncrono del estado (hilos + poll) da el mismo barrido
	var ma := MillDrillState.new()
	ma.set_sweep_x("mill", "fz_mm")
	ma.wait_sweeps()
	assert_true(ma.sweep_is_current("mill"), "barrido al día")
	var want := MillDrillState.run_sweep("mill", ma.mill_request(), "fz_mm", ma.sweep_values("mill", "fz_mm"), 1)
	assert_eq(var_to_str(ma.sweep("mill")["points"]), var_to_str(want), "en hilos, lo mismo que en uno")
	assert_false(bool(ma.sweep("mill")["pending"]), "sin nada pendiente")


func test_el_barrido_pasa_por_el_resultado() -> void:
	var md := _state()
	var xs := md.sweep_values("mill", "ae_mm")
	md.set_mill("ae_mm", xs[20])
	var pts: Array = md.sweep("mill")["points"]
	assert_eq(float(pts[20]["x"]), float(md.mill["ae_mm"]), "punto del barrido en el ae actual")
	assert_eq(pts[20]["pmotor_kw"], md.mill_result["pmotor_kw"], "misma potencia que el resultado")
	# Más ancho de corte, más potencia; más avance, más empuje
	for i in range(1, pts.size()):
		assert_true(float(pts[i]["pmotor_kw"]) > float(pts[i - 1]["pmotor_kw"]), "la potencia crece con ae")
	md.set_sweep_x("drill", "f_mm_rev")
	var dp: Array = md.sweep("drill")["points"]
	for i in range(1, dp.size()):
		assert_true(float(dp[i]["thrust_n"]) > float(dp[i - 1]["thrust_n"]), "el empuje crece con el avance")
	# Con el ensayo fuera del recorrido del barrido, el barrido se alarga hasta él: la curva llega a su punto
	md.set_sweep_x("mill", "ap_mm")
	md.set_mill("ap_mm", 20.0)
	pts = md.sweep("mill")["points"]
	assert_eq(float(pts[pts.size() - 1]["x"]), 20.0, "ap = 20 mm: el barrido de 0,2-10 mm llega a 20")
	assert_eq(pts[pts.size() - 1]["pmotor_kw"], md.mill_result["pmotor_kw"], "y su último punto es el resultado")
	md.set_drill("f_mm_rev", 0.01)
	dp = md.sweep("drill")["points"]
	assert_eq(float(dp[0]["x"]), 0.01, "f = 0,01: el barrido de 0,02-0,5 empieza en 0,01")
	assert_eq(dp[0]["thrust_n"], md.drill_result["thrust_n"], "y su primer punto es el resultado")
	md.set_mill("speed_mode", "rpm")
	md.set_mill("rpm", 6000.0)
	assert_eq(md.sweep_current_x("mill", "vc"), float(md.mill_result["vc"]), "por rpm, la vc del giro recortado")


func test_casos_limite() -> void:
	var md := _state()
	md.set_mill("ap_mm", 0.0)
	assert_eq(md.mill_result["pc_kw"], null, "ap = 0: sin potencia")
	assert_true(_has(md.mill_result["warnings"], "Faltan datos"), "el modelo lo explica")
	assert_true(md.mill_engagement().is_empty(), "sin contacto que dibujar")
	for p in md.sweep("mill")["points"]:
		assert_eq(p["pmotor_kw"], null, "barrido sin datos, sin romperse")
	var snd := md.mill_sound_input(1.0)
	assert_eq(float(snd["pc_kw"]), 0.0, "sin carga en el sonido")
	md.set_mill("ap_mm", 1.5)
	md.set_mill("speed_mode", "rpm")
	md.set_mill("rpm", 0.0)
	assert_true(_has(md.mill_result["warnings"], "Falta la velocidad"), "rpm = 0")
	assert_eq(float(md.mill_sound_input(1.0)["rpm"]), 0.0, "sin giro, sin sonido de husillo")
	# Madera: el modelo no tiene kc, pero sí la geometría del contacto
	var mw := _state()
	mw.set_mill("work_id", "pino")
	assert_eq(mw.mill_result["pc_kw"], null, "madera: sin potencia")
	assert_false(mw.mill_engagement().is_empty(), "pero el arco de contacto sí")
	assert_eq(float(mw.mill_sound_input(1.0)["pc_kw"]), 0.0, "ni carga")
	mw.set_drill("work_id", "pvc")
	assert_true(mw.drill_geometry()["time_s"] != null, "el tiempo del agujero sale del avance")
	mw.set_drill("f_mm_rev", 0.0)
	assert_eq(mw.drill_geometry()["time_s"], null, "sin avance, sin tiempo")


func test_entrada_de_sonido() -> void:
	var md := _state()
	var inp := md.mill_sound_input(1.0)
	assert_eq(inp["process"], "mill", "fresadora")
	assert_eq(int(inp["teeth"]), 5, "5 dientes")
	assert_eq(float(inp["rpm"]), float(md.mill_result["rpm"]), "giro del modelo")
	assert_eq(float(inp["pc_kw"]), float(md.mill_result["pc_kw"]), "potencia de corte del modelo")
	assert_eq(float(inp["pmax_kw"]), 3.7, "potencia de la máquina")
	var fr := MachineSound.frame(inp)
	var tooth_hz := 0.0
	for t in fr["tones"]:
		if t["layer"] == "pass":
			tooth_hz = float(t["hz"])
	assert_near(tooth_hz, 5.0 * float(fr["rpm"]) / 60.0, 1e-12, 0.0, "paso de dientes z·n/60 (con el giro bajo carga)")
	assert_near(fr["load"], float(md.mill_result["pc_kw"]) / 3.7, 1e-12, 0.0, "carga Pc/Pmáx")
	assert_eq(float(md.mill_sound_input(0.0)["pc_kw"]), 0.0, "fuera de la pieza, sin carga")
	md.set_running("mill", false)
	assert_eq(float(md.mill_sound_input(1.0)["rpm"]), 0.0, "parada")
	var dr := md.drill_sound_input(1.0)
	assert_eq(dr["process"], "drill", "taladro")
	assert_eq(int(dr["teeth"]), 2, "dos filos")
	md.set_mill("coolant", true)
	md.set_running("mill", true)
	assert_true(bool(md.mill_sound_input(1.0)["coolant"]), "taladrina")


## La pasada de la fresa: avanza a vf (tiempo real por la velocidad de la animación), entra en la pieza, corta con el arco
## entero, sale, descansa y vuelve a empezar; parada no se mueve.
func test_pasada_de_la_fresa() -> void:
	var md := _state()
	var a := md.mill_anim
	var r := 63.0 / 2.0
	var length: float = md.mill_block()["length_mm"]
	assert_eq(length, 189.0, "pieza de 3 diámetros")
	assert_eq(float(a["x_mm"]), -r - MillDrillState.MILL_CLEAR_MM, "empieza fuera, con holgura")
	assert_false(bool(a["cutting"]), "sin cortar")
	var vf := float(md.mill_result["vf_mm_min"])
	var pass_s := float(a["pass_time_s"])
	assert_near(pass_s, (length + 2.0 * r + 2.0 * MillDrillState.MILL_CLEAR_MM) / vf * 60.0, 1e-12, 0.0, "tiempo de pasada")
	md.advance("mill", 1.0)
	assert_near(md.mill_anim["x_mm"], -r - 5.0 + vf / 60.0, 1e-12, 1e-12, "avanza vf/60 mm cada segundo")
	# Entrada: la fracción que corta sube de 0 a 1 sin saltar hacia atrás
	var prev := 0.0
	var full := false
	var steps := 0
	while steps < 2000 and not full:
		md.advance("mill", 1.0 / 30.0)
		var e := float(md.mill_anim["engaged"])
		assert_true(e >= prev - 1e-12, "la fresa entra poco a poco (%s → %s)" % [prev, e])
		prev = e
		full = e >= 1.0
		steps += 1
	assert_true(full, "con la fresa dentro, el arco entero corta")
	assert_true(bool(md.mill_anim["cutting"]), "cortando")
	var snd := md.mill_sound_input()
	assert_eq(float(snd["pc_kw"]), float(md.mill_result["pc_kw"]), "el sonido oye toda la potencia")
	# Parada: no se mueve ni suena
	md.set_running("mill", false)
	var x := float(md.mill_anim["x_mm"])
	md.advance("mill", 1.0)
	assert_eq(float(md.mill_anim["x_mm"]), x, "parada no avanza")
	assert_false(bool(md.mill_anim["cutting"]), "ni corta")
	assert_eq(float(md.mill_sound_input()["pc_kw"]), 0.0, "ni carga")
	md.set_running("mill", true)
	# ×5: cinco veces más camino
	md.set_anim_speed("mill", 5.0)
	md.advance("mill", 0.1)
	assert_near(md.mill_anim["x_mm"], x + 5.0 * 0.1 * vf / 60.0, 1e-12, 1e-12, "×5")
	md.set_anim_speed("mill", 3.0)
	assert_eq(float(md.anim_speed["mill"]), 5.0, "solo las velocidades de la lista")
	# Sale, descansa y empieza otra pasada
	var guard := 0
	while str(md.mill_anim["phase"]) == "corte" and guard < 5000:
		md.advance("mill", 0.1)
		guard += 1
	assert_eq(md.mill_anim["phase"], "pausa", "al salir, pausa")
	assert_eq(float(md.mill_anim["engaged"]), 0.0, "fuera de la pieza no corta")
	md.advance("mill", MillDrillState.PAUSE_S / 5.0 + 0.01)
	assert_eq(md.mill_anim["phase"], "corte", "otra pasada")
	assert_eq(int(md.mill_anim["passes"]), 1, "una pasada hecha")


func test_fraccion_del_arco_dentro_de_la_pieza() -> void:
	var md := _state()
	var eng := md.mill_engagement()
	var r := 31.5
	assert_eq(MillDrillState.engaged_fraction(eng, -r - 1.0, 100.0), 0.0, "antes de la pieza")
	assert_eq(MillDrillState.engaged_fraction(eng, 50.0, 100.0), 1.0, "en medio")
	assert_eq(MillDrillState.engaged_fraction(eng, 100.0 + 1.0, 100.0), 0.0, "pasada la pieza")
	# Con la fresa 0,5 mm dentro, cortan los dientes con x + R·sen φ ≥ 0: φ = π/2 ± δ, cos δ = (R − 0,5)/R, y la
	# fracción es 2·sen δ / (cos φ_in − cos φ_out) (con 64 muestras, dentro del 5 %)
	var delta := acos((r - 0.5) / r)
	var want := 2.0 * sin(delta) / (cos(float(eng["phi_in"])) - cos(float(eng["phi_out"])))
	var edge := MillDrillState.engaged_fraction(eng, -r + 0.5, 100.0)
	assert_near(edge, want, 0.05, 0.0, "0,5 mm dentro: %s (≈ %s)" % [edge, want])
	var prev := 0.0
	for d in [0.2, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 31.5]:
		var f := MillDrillState.engaged_fraction(eng, -r + d, 100.0)
		assert_true(f >= prev, "más dentro, más arco cortando (%s mm: %s)" % [d, f])
		prev = f
	assert_eq(MillDrillState.engaged_fraction({}, 0.0, 100.0), 0.0, "sin contacto, 0")


## El ciclo del taladro: aproximación en rápido, taladrado a vf hasta profundidad + punta, retirada y pausa.
func test_ciclo_del_taladro() -> void:
	var md := _state()
	var g := md.drill_geometry()
	var tip := float(g["tip_mm"])
	var target := 25.0 + tip
	assert_near(md.drill_anim["target_mm"], target, 1e-12, 0.0, "la punta baja hasta profundidad + punta")
	assert_eq(md.drill_anim["phase"], "aproximacion", "empieza bajando en rápido")
	md.advance("drill", MillDrillState.RAPID_S)
	assert_eq(md.drill_anim["phase"], "taladrando", "tras el rápido, taladra")
	assert_near(md.drill_anim["depth_mm"], -MillDrillState.DRILL_APPROACH_MM, 1e-9, 1e-9, "desde 1 mm por encima")
	var v := float(md.drill_result["vf_mm_min"]) / 60.0
	md.advance("drill", MillDrillState.DRILL_APPROACH_MM / v)
	assert_false(bool(md.drill_anim["cutting"]), "la punta llega a la cara")
	md.advance("drill", tip / 2.0 / v)
	assert_near(md.drill_anim["engaged"], 0.5, 1e-9, 1e-9, "a media punta, medio filo corta")
	assert_near(md.drill_sound_input()["pc_kw"], float(md.drill_result["pc_kw"]) * 0.25, 1e-9, 1e-12, "potencia ∝ r²")
	var prev := 0.0
	var guard := 0
	while str(md.drill_anim["phase"]) == "taladrando" and guard < 10000:
		md.advance("drill", 0.05)
		var e := float(md.drill_anim["engaged"])
		assert_true(e >= prev - 1e-12 or str(md.drill_anim["phase"]) != "taladrando", "el filo entra poco a poco")
		prev = e
		guard += 1
	assert_eq(md.drill_anim["phase"], "retirada", "llega al fondo y sube")
	assert_near(md.drill_anim["t_s"], float(g["time_s"]), 1e-9, 1e-9, "el tiempo del agujero de la geometría")
	assert_near(md.drill_anim["hole_mm"], 25.0, 1e-9, 1e-9, "agujero de 25 mm a diámetro entero")
	md.advance("drill", MillDrillState.RAPID_S / 2.0)
	assert_near(md.drill_anim["hole_mm"], 25.0, 1e-9, 1e-9, "al sacar la broca, el agujero se queda")
	assert_false(bool(md.drill_anim["cutting"]), "subiendo no corta")
	md.advance("drill", -MillDrillState.RAPID_S / 2.0)  # dt negativo: no hace nada
	md.advance("drill", MillDrillState.RAPID_S / 2.0 + MillDrillState.PAUSE_S + 0.01)
	assert_eq(md.drill_anim["phase"], "aproximacion", "y otro agujero")
	assert_eq(int(md.drill_anim["holes"]), 1, "un agujero hecho")
	# Parada: no se mueve
	md.set_running("drill", false)
	var d := float(md.drill_anim["depth_mm"])
	md.advance("drill", 1.0)
	assert_eq(float(md.drill_anim["depth_mm"]), d, "parada no baja")


## Las vistas de las escenas 3D solo leen el estado: los números del modelo, sin nada nuevo, y siempre completas (sin
## contacto, parada o sin datos) para que la escena no tenga que adivinar.
func test_vistas_de_las_escenas_3d() -> void:
	var md := _state()
	var v := md.mill_3d_view()
	for k in ["tool_type", "dc_mm", "z", "kappa_deg", "helix_deg", "ap_mm", "ae_mm", "position", "material_side", "phi_out",
			"length_mm", "width_mm", "x_mm", "rpm", "cutting", "engaged", "coolant", "work_kind", "tool_id", "vc", "pc_kw",
			"chip_color"]:
		assert_true(v.has(k) and v[k] != null, "fresadora 3D: %s" % k)
	assert_eq(float(v["rpm"]), float(md.mill_result["rpm"]), "gira a las rpm del modelo")
	assert_eq(float(v["vc"]), float(md.mill_result["vc"]), "con su vc")
	assert_eq(float(v["phi_out"]), float(md.mill_engagement()["phi_out"]), "la viruta sale por el final del arco")
	assert_eq(float(v["pc_kw"]), 0.0, "antes de la pieza, sin carga")
	var guard := 0
	while not bool(md.mill_anim["cutting"]) and guard < 1000:
		md.advance("mill", 0.1)
		guard += 1
	v = md.mill_3d_view()
	assert_true(bool(v["cutting"]), "entra en la pieza")
	assert_near(v["pc_kw"], float(md.mill_result["pc_kw"]) * float(md.mill_anim["engaged"]), 1e-12, 0.0, "la potencia de la parte del arco que corta")
	assert_true(float(v["pc_kw"]) <= float(md.mill_result["pc_kw"]), "nunca más que la del arco entero")
	# Hélice de la fresa de mango: la de las tablas del afilado; sin dato para el material, la del acero, y se dice
	var al := MillDrillState.mill_helix("aluminio")
	assert_eq(float(al["deg"]), 40.0, "aluminio: 40° (Travers)")
	assert_true(bool(al["own"]) and str(al["quality"]) in WorkMaterials.QUALITIES, "con su fuente")
	var ti := MillDrillState.mill_helix("titanio")
	assert_false(bool(ti["own"]), "titanio: las tablas no lo dan")
	assert_eq(float(ti["deg"]), float(MillDrillState.mill_helix("acero")["deg"]), "se dibuja la del acero")
	# Sin contacto (ap = 0) la vista sigue completa, con ae ≤ Dc y el lado de la posición elegida
	md.set_mill("position", "concordancia")
	md.set_mill("ap_mm", 0.0)
	v = md.mill_3d_view()
	assert_true(md.mill_engagement().is_empty(), "sin contacto")
	assert_eq(int(v["material_side"]), -1, "concordancia: la pieza al lado del operario")
	assert_true(float(v["ae_mm"]) <= float(v["dc_mm"]), "ae ≤ Dc")
	assert_eq(float(v["pc_kw"]), 0.0, "sin potencia")
	md.set_mill("coolant", true)
	md.set_running("mill", false)
	v = md.mill_3d_view()
	assert_eq(float(v["rpm"]), 0.0, "parada no gira")
	assert_false(bool(v["coolant"]), "ni echa taladrina")
	# Taladro
	var dv := md.drill_3d_view()
	for k in ["d_mm", "sigma_deg", "tip_mm", "helix_deg", "depth_mm", "bottom_mm", "hole_mm", "target_mm", "depth_goal_mm",
			"phase", "rpm", "cutting", "engaged", "coolant", "work_kind", "tool_id", "vc", "pc_kw", "chip_color", "chip_form"]:
		assert_true(dv.has(k) and dv[k] != null, "taladro 3D: %s" % k)
	var g := md.drill_geometry()
	assert_eq(float(dv["tip_mm"]), float(g["tip_mm"]), "punta de la geometría")
	assert_eq(float(dv["helix_deg"]), float(g["helix"]["deg"]), "hélice de la broca")
	assert_eq(float(dv["rpm"]), float(md.drill_result["rpm"]), "giro del modelo")
	assert_eq(float(dv["depth_goal_mm"]), 25.0, "profundidad pedida")
	guard = 0
	while float(md.drill_anim["engaged"]) < 1.0 and guard < 10000:
		md.advance("drill", 0.05)
		guard += 1
	dv = md.drill_3d_view()
	assert_eq(float(dv["pc_kw"]), float(md.drill_result["pc_kw"]), "con la punta dentro, toda la potencia")
	assert_true(float(dv["bottom_mm"]) >= float(dv["depth_mm"]), "el fondo sigue a la punta")
	md.set_running("drill", false)
	assert_eq(float(md.drill_3d_view()["rpm"]), 0.0, "parado no gira")


func test_camara_lenta_y_espesor_en_un_angulo() -> void:
	var s := MillDrillState.slow_motion(900.0, 0.25)
	assert_eq(float(s["rev_s"]), 0.25, "se dibuja 1 vuelta cada 4 s")
	assert_near(s["time_scale"], 0.25 / 15.0, 1e-12, 0.0, "×1/60")
	assert_eq(float(MillDrillState.slow_motion(6.0, 0.25)["time_scale"]), 1.0, "despacio: a tiempo real")
	assert_eq(float(MillDrillState.slow_motion(0.0, 0.25)["rev_s"]), 0.0, "parada")
	var md := _state()
	var eng := md.mill_engagement()
	assert_eq(MillDrillState.chip_h(eng, 0.1), 0.0, "fuera del arco no corta")
	assert_near(MillDrillState.chip_h(eng, PI / 2.0), float(md.mill_result["hex_mm"]), 1e-12, 0.0, "en el centro, hex")
	assert_eq(MillDrillState.chip_h({}, 1.0), 0.0, "sin contacto")
