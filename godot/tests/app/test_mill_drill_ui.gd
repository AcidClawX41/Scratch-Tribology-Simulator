## Páginas de la fresadora y del taladro (app/taller/ui/{mill_page,drill_page}.gd) sin ventana: la sección se construye con
## build() y avanza con tick(), como haría _process. Se pulsan los controles de verdad (señales de los botones, los
## deslizadores y los desplegables) y se comprueba que cada número que enseñan es exactamente el de cutting.gd con esos
## parámetros (calculado aparte en el test) y que los esquemas dibujan los del core. Las escenas 3D y el sonido solo se
## crean dentro del árbol: aquí no.
extends "res://tests/case.gd"

const SECTION := "res://app/taller/taller_section.tscn"
const FRAME := 1.0 / 30.0
const Cutting = preload("res://core/taller/cutting.gd")
const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Mill3D = preload("res://app/taller/mill3d/mill_3d.gd")
const Drill3D = preload("res://app/taller/mill3d/drill_3d.gd")


func _section() -> Control:
	var s: Control = (load(SECTION) as PackedScene).instantiate()
	s.call("build")
	var md: MillDrillState = s.get("md")
	md.threaded = false  # barridos al momento: el test no espera a los hilos
	md.wait_sweeps()
	return s


func _ticks(s: Control, n: int) -> void:
	for k in n:
		s.call("tick", FRAME)


## Arrastre de un deslizador (fuera del árbol, Godot no emite value_changed: se emite a mano).
func _drag(slider: HSlider, v: float) -> void:
	slider.value = v
	if not slider.is_inside_tree():
		slider.value_changed.emit(slider.value)


## Elige en un desplegable el elemento con ese id (como si lo pulsara el usuario).
func _pick(o: OptionButton, id: Variant) -> void:
	var ids: Array = o.get_meta("ids", [])
	var i := ids.find(id)
	assert_true(i >= 0, "el desplegable tiene %s" % str(id))
	o.select(i)
	o.item_selected.emit(i)


func _text(page: Control, key: String) -> String:
	return ((page.get("out") as Dictionary)[key] as Label).text


func _warnings_text(page: Control) -> String:
	var t := ""
	for ch in (page.get("warn_list") as VBoxContainer).get_children():
		t += (ch as Label).text + "\n"
	return t


## Lo que enseña la tarjeta de resultado del fresado, con los números del core.
func _check_mill_numbers(page: Control, r: Dictionary, pmax: float, what: String) -> void:
	assert_true(_text(page, "rpm").begins_with(Fmt.unit(r["rpm"], 0, "rpm")), "%s: giro %s" % [what, _text(page, "rpm")])
	assert_eq(_text(page, "vc"), Fmt.unit(r["vc"], 0, "m/min"), "%s: vc" % what)
	assert_eq(_text(page, "vf"), "vf %s · fz %s" % [Fmt.unit(r["vf_mm_min"], 0, "mm/min"), Fmt.unit(r["fz_mm"], 3, "mm")], "%s: vf" % what)
	assert_eq(_text(page, "h"), "hm %s · hex %s · %s dientes en corte" % [Fmt.unit(r["hm_mm"], 3, "mm"), Fmt.unit(r["hex_mm"], 3, "mm"), Fmt.num(r["zc"], 2)], "%s: hm y hex" % what)
	assert_eq(_text(page, "kc"), Fmt.unit(r["kc"], 0, "N/mm²"), "%s: kc" % what)
	assert_eq(_text(page, "fc"), Fmt.unit(r["fc_mean_n"], 0, "N"), "%s: Fc media" % what)
	assert_true(_text(page, "pc").begins_with("%s en el filo · %s en el motor de %s" % [Fmt.unit(r["pc_kw"], 2, "kW"), Fmt.unit(r["pmotor_kw"], 2, "kW"), Fmt.unit(pmax, 1, "kW")]), "%s: potencia %s" % [what, _text(page, "pc")])
	assert_eq(_text(page, "torque"), Fmt.unit(r["torque_nm"], 1, "N·m"), "%s: par" % what)
	assert_eq(_text(page, "q"), Fmt.unit(r["q_cm3_min"], 1, "cm³/min"), "%s: caudal" % what)
	assert_true(_text(page, "tooth").begins_with(Fmt.unit(r["tooth_hz"], 0, "Hz")), "%s: paso de dientes" % what)
	if r["life_min"] != null:
		assert_eq(_text(page, "life"), "%s (%s)" % [Fmt.unit(r["life_min"], 1, "min"), Fmt.quality(r["life_quality"])], "%s: vida" % what)


func test_pestanas_de_fresadora_y_taladro() -> void:
	var s := _section()
	var tabs: Dictionary = s.get("tab_chips")
	var md_pages: Dictionary = s.get("md_pages")
	var pages: Dictionary = s.get("pages")
	assert_eq(md_pages.keys(), ["fresadora", "taladro"], "dos máquinas nuevas")
	assert_true(tabs.has("fresadora") and tabs.has("taladro"), "con su pestaña")
	var ws = s.get("state")
	ws.play()
	assert_true(ws.playing, "el torno en marcha")
	for id in ["fresadora", "taladro"]:
		(tabs[id] as Button).pressed.emit()
		assert_eq(s.call("current_page"), id, "se ve %s" % id)
		assert_true((md_pages[id] as Control).visible, "%s visible" % id)
		assert_eq((md_pages[id] as Control).process_mode, Node.PROCESS_MODE_INHERIT, "%s procesa" % id)
		for k in pages:
			assert_false((pages[k] as Control).visible, "%s escondida" % k)
		assert_false(ws.playing, "una máquina a la vez: el torno se para")
		_ticks(s, 3)
	(tabs["torno"] as Button).pressed.emit()
	assert_true((pages["torno"] as Control).visible, "vuelve al torno")
	for id in md_pages:
		assert_false((md_pages[id] as Control).visible, "%s escondida" % id)
		assert_eq((md_pages[id] as Control).process_mode, Node.PROCESS_MODE_DISABLED, "%s sin procesar" % id)
	(tabs["radial"] as Button).pressed.emit()
	(tabs["taladro"] as Button).pressed.emit()
	(tabs["radial"] as Button).pressed.emit()
	assert_true((pages["radial"] as Control).visible, "y a la radial, aunque WorkshopState ya estaba en ella")
	assert_eq(s.call("page", "fresadora"), md_pages["fresadora"], "page() encuentra las dos clases de página")
	var fund: Array = s.call("fundamentos")
	var titles := ""
	for f: Array in fund:
		titles += str(f[0]) + "|"
	assert_true(titles.contains("Fresado") and titles.contains("Taladrado"), "fundamentos de la fresadora y del taladro")
	s.free()


func test_la_fresadora_ensena_los_numeros_del_core() -> void:
	var s := _section()
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var md: MillDrillState = s.get("md")
	var r := Cutting.milling(md.mill_request())
	assert_eq(var_to_str(md.mill_result), var_to_str(r), "el estado es el modelo")
	_check_mill_numbers(mp, r, 3.7, "de partida")
	var band: Array = r["band"]
	assert_true((mp.get("band_label") as Label).text.contains(Fmt.span(band[0], band[1], 0)), "banda de kc")
	assert_true((mp.get("quality_label") as Label).text.ends_with(Fmt.quality(r["quality"])), "calidad de los datos")
	assert_true((mp.get("sources_label") as Label).text.contains("Sandvik"), "fuentes")
	# El esquema dibuja el arco y los espesores del core
	var view: Control = mp.get("view")
	var labels: Dictionary = view.get("labels")
	var eng := md.mill_engagement()
	assert_eq(labels["hm"], "hm = %s (media)" % Fmt.unit(r["hm_mm"], 3, "mm"), "hm en el esquema")
	assert_eq(labels["hex"], "hex = %s (máxima)" % Fmt.unit(r["hex_mm"], 3, "mm"), "hex en el esquema")
	assert_eq(labels["arc"], "arco de contacto %s°" % Fmt.num(eng["contact_deg"], 0), "arco de contacto")
	assert_eq(labels["vf"], "vf = %s" % Fmt.unit(r["vf_mm_min"], 0, "mm/min"), "vf en el esquema")
	assert_eq(labels["ae"], "ae = %s" % Fmt.unit(40.0, 0, "mm"), "ae en el esquema")
	# Controles: ancho de corte, avance y posición
	var sliders: Dictionary = mp.get("sliders")
	assert_eq((sliders["ae_mm"].slider as HSlider).max_value, 63.0, "ae llega al diámetro")
	_drag(sliders["ae_mm"].slider as HSlider, 20.0)
	assert_eq(float(md.mill["ae_mm"]), 20.0, "ae del deslizador")
	_drag(sliders["fz_mm"].slider as HSlider, 0.2)
	assert_eq(float(md.mill["fz_mm"]), 0.2, "fz del deslizador")
	r = Cutting.milling(md.mill_request())
	_check_mill_numbers(mp, r, 3.7, "ae 20 y fz 0,2")
	((mp.get("position_chips") as Dictionary)["oposicion"] as Button).pressed.emit()
	assert_eq(md.mill["position"], "oposicion", "oposición")
	labels = view.get("labels")
	assert_eq(labels["entry"], "entra con h = %s" % Fmt.unit(0.0, 3, "mm"), "en oposición entra con espesor cero")
	assert_true((mp.get("position_note") as Label).text.contains("roza"), "y se explica por qué")
	((mp.get("position_chips") as Dictionary)["concordancia"] as Button).pressed.emit()
	labels = view.get("labels")
	assert_eq(labels["exit"], "sale con h = %s" % Fmt.unit(0.0, 3, "mm"), "en concordancia sale con espesor cero")
	r = Cutting.milling(md.mill_request())
	_check_mill_numbers(mp, r, 3.7, "concordancia")
	s.free()


func test_herramienta_pieza_y_giro() -> void:
	var s := _section()
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var md: MillDrillState = s.get("md")
	((mp.get("type_chips") as Dictionary)["mango"] as Button).pressed.emit()
	assert_eq(md.mill["tool_type"], "mango", "fresa de mango")
	var opt: OptionButton = mp.get("tool_opt")
	assert_eq(opt.get_meta("ids"), MillDrillState.MILL_TOOLS["mango"]["tool_ids"], "sus materiales de corte")
	assert_eq((mp.get("kappa_chips") as Dictionary).keys(), [90.0], "solo κr 90°")
	_pick(opt, "hss_co_m42")
	assert_eq(md.mill["tool_id"], "hss_co_m42", "HSS-Co")
	assert_true((mp.get("tool_info") as Label).text.contains("940 HV"), "dureza del catálogo")
	_pick(mp.get("work_opt") as OptionButton, "al6082_t6")
	assert_eq(md.mill["work_id"], "al6082_t6", "aluminio")
	assert_true((mp.get("work_info") as Label).text.begins_with("ISO N"), "grupo ISO")
	var r := Cutting.milling(md.mill_request())
	_check_mill_numbers(mp, r, 3.7, "mango de HSS-Co en aluminio")
	# Por rpm: más allá del tope de la máquina, el modelo lo recorta y la página lo dice
	((mp.get("speed_chips") as Dictionary)["rpm"] as Button).pressed.emit()
	var sliders: Dictionary = mp.get("sliders")
	assert_true((sliders["rpm"].row as Control).visible and not (sliders["vc"].row as Control).visible, "deslizador de rpm")
	_drag(sliders["rpm"].slider as HSlider, 5000.0)
	assert_true(_text(mp, "rpm").contains("limitado por la máquina"), "tope de giro: %s" % _text(mp, "rpm"))
	assert_true(_warnings_text(mp).contains("Tope de giro"), "y el aviso del modelo")
	r = Cutting.milling(md.mill_request())
	_check_mill_numbers(mp, r, 3.7, "tope de giro")
	# Madera: sin fuerzas, pero con el esquema del contacto
	_pick(mp.get("work_opt") as OptionButton, "pino")
	assert_eq(_text(mp, "pc"), "— en el filo · — en el motor de %s" % Fmt.unit(3.7, 1, "kW"), "madera: sin potencia")
	assert_true(_warnings_text(mp).contains("Sin fuerza de corte"), "el modelo explica por qué")
	assert_false(((mp.get("view") as Control).get("labels") as Dictionary).has("empty"), "el contacto sí se dibuja")
	s.free()


func test_sobrecarga_y_ficha_de_la_maquina() -> void:
	var s := _section()
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var md: MillDrillState = s.get("md")
	assert_true((mp.get("machine_info") as Label).text.contains("Lagun FTV 2"), "ficha de la máquina")
	assert_true((mp.get("btn_ficha") as Button).disabled, "ya es la ficha")
	var msl: Dictionary = mp.get("machine_sliders")
	_drag(msl["pmax_kw"].slider as HSlider, 1.0)
	assert_eq(float(md.mill_machine["pmax_kw"]), 1.0, "motor de 1 kW")
	assert_true(_text(mp, "pc").ends_with("SOBRECARGA"), "sobrecarga: %s" % _text(mp, "pc"))
	assert_true(_warnings_text(mp).contains("Sobrecarga"), "con el aviso del modelo")
	_check_mill_numbers(mp, Cutting.milling(md.mill_request()), 1.0, "motor de 1 kW")
	(mp.get("btn_ficha") as Button).pressed.emit()
	assert_eq(float(md.mill_machine["pmax_kw"]), 3.7, "vuelve a la ficha")
	assert_false(_text(mp, "pc").ends_with("SOBRECARGA"), "sin sobrecarga")
	# Parar la máquina: la pasada no avanza
	(mp.get("btn_run") as Button).pressed.emit()
	assert_false(bool(md.running["mill"]), "parada")
	assert_eq((mp.get("btn_run") as Button).text, "Marcha", "el botón pasa a marcha")
	var x := float(md.mill_anim["x_mm"])
	_ticks(s, 10)
	assert_eq(float(md.mill_anim["x_mm"]), x, "parada no avanza")
	(mp.get("btn_run") as Button).pressed.emit()
	_ticks(s, 10)
	assert_near(md.mill_anim["x_mm"], x + 10.0 * FRAME * float(md.mill_result["vf_mm_min"]) / 60.0, 1e-9, 1e-9, "en marcha avanza a vf")
	s.free()


## Con la máquina parada y sin virutas en el aire, los esquemas no se redibujan (pantallas quietas sin gastar CPU:
## CONTRATOS, rendimiento); en marcha, sí.
func test_pantalla_quieta_con_la_maquina_parada() -> void:
	var s := _section()
	for id in ["fresadora", "taladro"]:
		s.call("select_machine", id)
		var p: Control = s.call("page", id)
		var view: Control = p.get("view")
		_ticks(s, 30)
		assert_false(bool(view.call("idle")), "%s en marcha: se anima" % id)
		(p.get("btn_run") as Button).pressed.emit()
		_ticks(s, 150)  # las virutas que quedaban salen y se van
		assert_true(bool(view.call("idle")), "%s parada: pantalla quieta" % id)
		(p.get("btn_run") as Button).pressed.emit()
		_ticks(s, 1)
		assert_false(bool(view.call("idle")), "%s otra vez en marcha" % id)
	s.free()


func test_la_animacion_solo_avanza_en_su_pagina() -> void:
	var s := _section()
	var md: MillDrillState = s.get("md")
	var x0 := float(md.mill_anim["x_mm"])
	var d0 := float(md.drill_anim["depth_mm"])
	_ticks(s, 5)  # en el torno
	assert_eq(float(md.mill_anim["x_mm"]), x0, "la fresa quieta mientras se ve el torno")
	s.call("select_machine", "fresadora")
	_ticks(s, 5)
	assert_true(float(md.mill_anim["x_mm"]) > x0, "la fresa avanza en su página")
	assert_eq(float(md.drill_anim["depth_mm"]), d0, "el taladro quieto")
	s.call("select_machine", "taladro")
	_ticks(s, 5)
	assert_true(float(md.drill_anim["depth_mm"]) > d0, "la broca baja en su página")
	var dv: Control = (s.call("page", "taladro") as Control).get("view")
	assert_true(float(dv.get("theta")) > 0.0, "y gira (en cámara lenta)")
	s.free()


func test_el_taladro_ensena_los_numeros_del_core() -> void:
	var s := _section()
	s.call("select_machine", "taladro")
	var dp: Control = s.call("page", "taladro")
	var md: MillDrillState = s.get("md")
	var r := Cutting.drilling(md.drill_request())
	var g := md.drill_geometry()
	_check_drill(dp, r, g, "de partida")
	var labels: Dictionary = (dp.get("view") as Control).get("labels")
	assert_eq(labels["h"], "h = (f/2)·sen(σ/2) = %s" % Fmt.unit(r["h_mm"], 3, "mm"), "h en el detalle del filo")
	assert_eq(labels["b"], "b = %s (largo del filo)" % Fmt.unit(g["b_mm"], 2, "mm"), "b en el detalle")
	assert_eq(labels["thrust"], "empuje %s" % Fmt.unit(r["thrust_n"], 0, "N"), "empuje en la sección")
	assert_eq(labels["torque"], "par %s" % Fmt.unit(r["torque_nm"], 1, "N·m"), "par en la sección")
	# Avances automáticos de la máquina
	((dp.get("feed_chips") as Dictionary)[0.2] as Button).pressed.emit()
	assert_eq(float(md.drill["f_mm_rev"]), 0.2, "avance de 0,20 de la máquina")
	r = Cutting.drilling(md.drill_request())
	_check_drill(dp, r, md.drill_geometry(), "f = 0,20")
	# Ángulo de punta recomendado para el aluminio (140°)
	_pick(dp.get("work_opt") as OptionButton, "al6082_t6")
	var btn: Button = dp.get("btn_point")
	assert_true(btn.visible and btn.text.contains("140°"), "botón del ángulo recomendado: %s" % btn.text)
	btn.pressed.emit()
	assert_eq(float(md.drill["point_angle_deg"]), 140.0, "punta de 140°")
	assert_false(btn.visible, "ya lo usa")
	_check_drill(dp, Cutting.drilling(md.drill_request()), md.drill_geometry(), "aluminio a 140°")
	# Profundidad y diámetro
	var sliders: Dictionary = dp.get("sliders")
	_drag(sliders["depth_mm"].slider as HSlider, 40.0)
	_drag(sliders["d_mm"].slider as HSlider, 36.0)
	assert_eq(float(md.drill["d_mm"]), 36.0, "Ø36")
	assert_true(_warnings_text(dp).contains("Ø32 como máximo"), "más que la capacidad de la máquina")
	_check_drill(dp, Cutting.drilling(md.drill_request()), md.drill_geometry(), "Ø36 × 40")
	s.free()


func _check_drill(page: Control, r: Dictionary, g: Dictionary, what: String) -> void:
	assert_true(_text(page, "rpm").begins_with(Fmt.unit(r["rpm"], 0, "rpm")), "%s: giro" % what)
	assert_eq(_text(page, "vc"), Fmt.unit(r["vc"], 0, "m/min"), "%s: vc" % what)
	assert_true(_text(page, "vf").begins_with("vf %s" % Fmt.unit(r["vf_mm_min"], 0, "mm/min")), "%s: vf" % what)
	assert_eq(_text(page, "h"), "h %s · b %s · A %s por filo" % [Fmt.unit(r["h_mm"], 3, "mm"), Fmt.unit(g["b_mm"], 2, "mm"), Fmt.unit(g["area_mm2"], 3, "mm²")], "%s: h, b y A" % what)
	assert_eq(_text(page, "kc"), Fmt.unit(r["kc"], 0, "N/mm²"), "%s: kc" % what)
	assert_eq(_text(page, "fc"), "%s por filo" % Fmt.unit(r["fc_edge_n"], 0, "N"), "%s: Fc" % what)
	assert_eq(_text(page, "thrust"), Fmt.unit(r["thrust_n"], 0, "N"), "%s: empuje" % what)
	assert_eq(_text(page, "torque"), Fmt.unit(r["torque_nm"], 1, "N·m"), "%s: par" % what)
	assert_true(_text(page, "pc").begins_with("%s en el filo · %s en el motor" % [Fmt.unit(r["pc_kw"], 2, "kW"), Fmt.unit(r["pmotor_kw"], 2, "kW")]), "%s: potencia" % what)
	assert_eq(_text(page, "q"), Fmt.unit(r["q_cm3_min"], 1, "cm³/min"), "%s: caudal" % what)
	assert_true(_text(page, "time").begins_with(Fmt.seconds(g["time_s"])), "%s: tiempo del agujero" % what)
	if r["life_min"] != null:
		assert_eq(_text(page, "life"), "%s (%s)" % [Fmt.unit(r["life_min"], 1, "min"), Fmt.quality(r["life_quality"])], "%s: vida" % what)


func test_barrido_en_la_grafica() -> void:
	var s := _section()
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var md: MillDrillState = s.get("md")
	var chart: Control = mp.get("chart")
	assert_eq(int(chart.call("valid_points")), MillDrillState.SWEEP_POINTS, "41 puntos de potencia frente a ae")
	var cur: Vector2 = chart.get("current")
	assert_near(cur.x, float(md.mill["ae_mm"]), 1e-6, 0.0, "el punto actual en el ae del ensayo (Vector2 es de 32 bits)")
	assert_near(cur.y, float(md.mill_result["pmotor_kw"]), 1e-6, 0.0, "con la potencia del resultado")
	assert_eq(float(chart.get("limit")), 3.7, "la línea del motor de la máquina")
	((mp.get("sweep_x_chips") as Dictionary)["fz_mm"] as Button).pressed.emit()
	assert_eq(md.sweep_x["mill"], "fz_mm", "barrido del avance")
	var want := MillDrillState.run_sweep("mill", md.mill_request(), "fz_mm", md.sweep_values("mill", "fz_mm"), 1)
	var ys: Array = chart.get("ys")
	for i in want.size():
		assert_eq(ys[i], want[i]["pmotor_kw"], "punto %d del barrido = el del core" % i)
	((mp.get("sweep_y_chips") as Dictionary)["torque_nm"] as Button).pressed.emit()
	assert_true(is_nan(float(chart.get("limit"))), "el par no tiene línea de la máquina")
	assert_near((chart.get("current") as Vector2).y, float(md.mill_result["torque_nm"]), 1e-6, 0.0, "par del resultado")
	# Taladro: empuje frente al avance
	s.call("select_machine", "taladro")
	var dp: Control = s.call("page", "taladro")
	var dchart: Control = dp.get("chart")
	assert_eq(int(dchart.call("valid_points")), MillDrillState.SWEEP_POINTS, "empuje frente al avance")
	assert_near((dchart.get("current") as Vector2).y, float(md.drill_result["thrust_n"]), 1e-6, 0.0, "empuje del resultado")
	s.free()


func test_barridos_en_hilos_sin_bloquear() -> void:
	var s: Control = (load(SECTION) as PackedScene).instantiate()
	s.call("build")
	var md: MillDrillState = s.get("md")
	assert_true(md.threaded, "en la aplicación, los barridos van en hilos")
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var sliders: Dictionary = mp.get("sliders")
	_drag(sliders["ap_mm"].slider as HSlider, 3.0)
	var guard := 0
	while not md.sweep_is_current("mill") and guard < 2000:
		s.call("tick", FRAME)  # poll() recoge el barrido cuando termina, sin esperar
		OS.delay_msec(1)
		guard += 1
	assert_true(md.sweep_is_current("mill"), "el barrido llega (%d fotogramas)" % guard)
	var want := MillDrillState.run_sweep("mill", md.mill_request(), "ae_mm", md.sweep_values("mill", "ae_mm"), 1)
	assert_eq(var_to_str(md.sweep("mill")["points"]), var_to_str(want), "igual que en un hilo")
	s.free()


## Al cambiar de fresa, los recorridos de los deslizadores cambian sin tocar el estado (refresh pone recorrido y valor con
## las señales bloqueadas: dentro del árbol, recortar el valor al nuevo recorrido emitiría value_changed; eso lo vigila
## la demo, que sí corre dentro del árbol).
func test_recorridos_de_los_deslizadores() -> void:
	var s := _section()
	s.call("select_machine", "fresadora")
	var mp: Control = s.call("page", "fresadora")
	var md: MillDrillState = s.get("md")
	((mp.get("type_chips") as Dictionary)["mango"] as Button).pressed.emit()
	var ae: HSlider = (mp.get("sliders") as Dictionary)["ae_mm"].slider
	assert_eq(ae.max_value, 16.0, "ae llega al Ø16 de la fresa de mango")
	assert_eq(ae.value, 4.0, "y enseña el ae de su ensayo")
	assert_false(ae.is_blocking_signals(), "las señales vuelven a estar activas")
	assert_eq(float(md.mill["ae_mm"]), 4.0, "el estado no cambia")
	var rpm: HSlider = (mp.get("sliders") as Dictionary)["rpm"].slider
	md.set_machine_param("mill", "rpm_max", 1000.0)
	assert_eq(rpm.max_value, 1500.0, "el giro llega a 1,5 veces el tope de la máquina")
	assert_false(rpm.is_blocking_signals(), "sin señales bloqueadas")
	s.free()


## Vista 3D: las fichas de la cámara salen con la máquina y se esconden con el esquema. La escena solo se crea dentro del
## árbol (aquí no); lo demás se comprueba con sus funciones puras.
func test_vista_3d_y_camaras() -> void:
	var s := _section()
	for id in ["fresadora", "taladro"]:
		s.call("select_machine", id)
		var p: Control = s.call("page", id)
		var cam_box: Control = p.get("cam_box")
		assert_false(cam_box.visible, "%s: con el esquema, sin cámaras" % id)
		((p.get("view_chips") as Dictionary)["maquina"] as Button).pressed.emit()
		assert_eq(p.get("view_mode"), "maquina", "%s: máquina 3D" % id)
		assert_true(cam_box.visible, "%s: con sus cámaras" % id)
		assert_false((p.get("view") as Control).visible, "%s: el esquema se esconde" % id)
		var cams: Dictionary = p.get("cam_chips")
		assert_eq(cams.keys(), ["detalle", "frontal", "superior", "general"], "%s: cuatro cámaras" % id)
		(cams["frontal"] as Button).pressed.emit()
		assert_eq(p.get("cam_view"), "frontal", "%s: cámara frontal" % id)
		assert_true((cams["frontal"] as Button).button_pressed and not (cams["detalle"] as Button).button_pressed, "%s: ficha marcada" % id)
		_ticks(s, 3)  # sin escena, el 3D no hace nada
		((p.get("view_chips") as Dictionary)["esquema"] as Button).pressed.emit()
		assert_false(cam_box.visible, "%s: vuelta al esquema, sin cámaras" % id)
	s.free()


## La pieza de la fresadora 3D sale de la vista del estado: la franja que se fresa mide ae, cae dentro de la pieza y del
## diámetro de la fresa, baja ap y lo fresado llega hasta la fresa. La del taladro, más gruesa que el agujero.
func test_geometria_de_las_escenas_3d() -> void:
	var md := MillDrillState.new()
	md.threaded = false
	for tool in ["planear", "mango"]:
		md.set_mill("tool_type", tool)
		for pos in ["centrada", "oposicion", "concordancia"]:
			md.set_mill("position", pos)
			md.reset_anim("mill")
			var v := md.mill_3d_view()
			var g := Mill3D.block_geometry(v)
			var what := "%s %s" % [tool, pos]
			var r := float(v["dc_mm"]) / 2000.0
			assert_near(float(g["sz1"]) - float(g["sz0"]), float(v["ae_mm"]) / 1000.0, 1e-12, 0.0, "%s: la franja mide ae" % what)
			assert_true(float(g["sz0"]) >= -r - 1e-12 and float(g["sz1"]) <= r + 1e-12, "%s: dentro de la fresa" % what)
			assert_true(float(g["z0"]) <= float(g["sz0"]) + 1e-12 and float(g["sz1"]) <= float(g["z1"]) + 1e-12, "%s: dentro de la pieza" % what)
			if pos == "oposicion":
				assert_near(g["sz0"], -r, 1e-12, 0.0, "%s: la franja empieza en el borde de la fresa (hacia la columna)" % what)
			elif pos == "concordancia":
				assert_near(g["sz1"], r, 1e-12, 0.0, "%s: y en concordancia, hacia el operario" % what)
			assert_near(g["cut_y"], Mill3D.TABLE_Y + float(g["height"]) - float(v["ap_mm"]) / 1000.0, 1e-12, 0.0, "%s: la fresa baja ap" % what)
			assert_true(float(g["height"]) >= float(v["ap_mm"]) / 1000.0 + 0.025 - 1e-12, "%s: la pieza es más alta que ap" % what)
			assert_near(g["x_cut"], -float(g["length"]) / 2.0, 1e-12, 0.0, "%s: al empezar, nada fresado" % what)
			assert_near(float(g["table_x"]) + float(v["x_mm"]) / 1000.0, float(g["length"]) / 2.0, 1e-12, 0.0, "%s: la mesa lleva la pieza" % what)
	var guard := 0
	while str(md.mill_anim["phase"]) == "corte" and guard < 100000:
		md.advance("mill", 0.1)
		guard += 1
	var gend := Mill3D.block_geometry(md.mill_3d_view())
	assert_near(gend["x_cut"], float(gend["length"]) / 2.0, 1e-12, 0.0, "al acabar la pasada, fresada entera")
	# La consola lleva la pieza hasta la fresa (con la caña casi recogida) sin salirse de su carrera de la ficha, también en
	# los extremos de los deslizadores
	for tool in ["planear", "mango"]:
		for dc: float in [6.0, 160.0]:
			for ap: float in [0.1, 20.0]:
				var mv := { "tool_type": tool, "dc_mm": dc, "ap_mm": ap, "ae_mm": dc / 2.0, "length_mm": 100.0,
					"width_mm": dc / 2.0, "material_side": 0, "x_mm": 0.0 }
				var rise := Mill3D.knee_rise(mv)
				assert_true(absf(rise) <= Mill3D.KNEE_TRAVEL / 2.0, "%s Ø%s, ap %s: la consola se mueve %s m" % [tool, dc, ap, rise])
	assert_true(Mill3D.QUILL_EXT < Mill3D.QUILL_STROKE, "la caña fuera menos que su carrera")
	# El taladro: la pieza tiene la profundidad pedida, la punta y 10 mm más, y 25 mm como poco; la mesa queda donde la
	# nariz del husillo está a una distancia de la ficha y la caña baja hasta el fondo sin pasar de su carrera
	for d: float in [1.0, 10.0, 40.0]:
		for depth: float in [2.0, 25.0, 100.0]:
			for sigma: float in [80.0, 150.0]:
				md.set_drill("d_mm", d)
				md.set_drill("depth_mm", depth)
				md.set_drill("point_angle_deg", sigma)
				var dv := md.drill_3d_view()
				var what := "Ø%s × %s mm a %s°" % [d, depth, sigma]
				var t := Drill3D.plate_thickness(dv)
				assert_true(t >= (depth + float(dv["tip_mm"]) + 10.0) / 1000.0 - 1e-12 and t >= 0.025, "%s: pieza de %s m" % [what, t])
				var top := Drill3D.table_top(dv)
				var gap := Drill3D.HEAD_BOTTOM - Drill3D.QUILL_REST - top
				assert_true(gap >= Drill3D.SPINDLE_TABLE.x and gap <= Drill3D.SPINDLE_TABLE.y, "%s: husillo a %s m de la mesa" % [what, gap])
				assert_true(top - 0.12 > Drill3D.BASE_TOP, "%s: la mesa por encima de la base" % what)
				var travel := Drill3D.QUILL_REST + (MillDrillState.DRILL_CLEAR_MM + depth + float(dv["tip_mm"])) / 1000.0
				assert_true(travel <= Drill3D.QUILL_STROKE, "%s: la caña baja %s m" % [what, travel])
	# Fuera del árbol, las escenas guardan la vista para cuando se construyan (no pintan nada ni fallan)
	for pair in [["res://app/taller/mill3d/mill_3d.tscn", md.mill_3d_view()], ["res://app/taller/mill3d/drill_3d.tscn", md.drill_3d_view()]]:
		var scene: Node3D = (load(pair[0]) as PackedScene).instantiate()
		scene.call("set_state", pair[1])
		assert_eq(scene.get("state"), pair[1], "%s: vista guardada" % pair[0])
		scene.free()


func test_modo_telefono_de_las_paginas_nuevas() -> void:
	var s := _section()
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	s.size = Vector2(390, 844)
	s.call("_update_layout")
	assert_true(s.get("compact"), "a 390 px, una columna")
	for id in ["fresadora", "taladro"]:
		var p: Control = s.call("page", id)
		assert_true((p.get("pane") as Control).get("compact"), "%s en una columna" % id)
		assert_true((p.get("view") as Control).custom_minimum_size.x <= 366.0, "%s: el esquema cabe en 390 px" % id)
	s.size = Vector2(1240, 880)
	s.call("_update_layout")
	for id in ["fresadora", "taladro"]:
		assert_false(((s.call("page", id) as Control).get("pane") as Control).get("compact"), "%s en dos columnas" % id)
	s.free()
