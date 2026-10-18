## Interfaz del Taller industrial (app/taller/taller_section.tscn) sin ventana: la sección se construye con build()
## y avanza con tick(), como haría _process. Se pulsan los controles de verdad (señales de los botones y los
## deslizadores) y se leen los textos que pinta. Las escenas 3D y el sonido solo se crean dentro del árbol: aquí no.
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const SECTION := "res://app/taller/taller_section.tscn"
const FRAME := 1.0 / 30.0


func _section() -> Control:
	var s: Control = (load(SECTION) as PackedScene).instantiate()
	s.call("build")
	return s


func _ticks(s: Control, n: int) -> void:
	for k in n:
		s.call("tick", FRAME)


## Arrastre de un deslizador. Fuera del árbol, Godot 4.7 cambia el valor de un Range sin emitir value_changed
## (comprobado): se emite a mano, como lo haría el deslizador en la ventana.
func _drag(slider: HSlider, v: float) -> void:
	slider.value = v
	if not slider.is_inside_tree():
		slider.value_changed.emit(slider.value)


func test_la_seccion_carga_sin_ventana() -> void:
	var s := _section()
	assert_true(s.get("state") != null, "hay estado del taller")
	var pages: Dictionary = s.get("pages")
	assert_eq(pages.keys(), ["torno", "radial", "afiladora", "calculadoras"], "cuatro máquinas")
	assert_true(pages.torno.visible, "empieza en el torno")
	for id in ["radial", "afiladora", "calculadoras"]:
		assert_false(pages[id].visible, "%s escondida" % id)
		assert_eq(pages[id].process_mode, Node.PROCESS_MODE_DISABLED, "%s sin procesar" % id)
	var notice := s.find_child("AvisoOrientativo", true, false) as Label
	assert_true(notice != null and notice.text.contains("orientativos"), "aviso de valores orientativos")
	# petición 40: el taller está en desarrollo, y lo dice
	var wip := s.find_child("AvisoWIP", true, false) as Label
	assert_true(wip != null and wip.text.begins_with("WIP"), "aviso de que el taller está en desarrollo (WIP)")
	assert_true(s.theme != null, "tema local de la sección (no el global)")
	assert_eq(pages.torno.get("lathe3d"), null, "sin ventana no se crea la escena 3D")
	_ticks(s, 3)
	s.free()


func test_cambia_de_maquina() -> void:
	var s := _section()
	var tabs: Dictionary = s.get("tab_chips")
	var pages: Dictionary = s.get("pages")
	for id in ["radial", "afiladora", "calculadoras", "torno"]:
		(tabs[id] as Button).pressed.emit()
		assert_eq(s.get("state").machine, id, "máquina %s" % id)
		for k in pages:
			assert_eq(pages[k].visible, k == id, "solo se ve %s (%s)" % [id, k])
		assert_eq(pages[id].process_mode, Node.PROCESS_MODE_INHERIT, "%s procesa" % id)
		_ticks(s, 2)
	s.free()


func test_reproducir_avanza_el_torno() -> void:
	var s := _section()
	var lp: Control = s.get("pages").torno
	var ws = s.get("state")
	var play: Button = lp.get("btn_play")
	assert_eq(play.text, "Marcha", "botón de marcha")
	_ticks(s, 10)
	assert_eq(float(ws.lathe_state().t_s), 0.0, "sin marcha no avanza")
	play.pressed.emit()
	assert_true(ws.playing, "en marcha")
	assert_eq(play.text, "Pausa", "el botón pasa a pausa")
	_ticks(s, 30)
	var t := float(ws.lathe_state().t_s)
	assert_near(t, 1.0, 0.0, 0.002, "un segundo a ×1 (%s s)" % t)
	var reads: Dictionary = lp.get("reads")
	# (número y unidad con espacio de no separación, para que la unidad no se parta de su número)
	assert_true((reads.t as Label).text.begins_with("1,0\u00a0s"), "tiempo en pantalla: %s" % (reads.t as Label).text)
	assert_true((reads.n as Label).text.begins_with("N"), "bloque en pantalla: %s" % (reads.n as Label).text)
	play.pressed.emit()
	assert_false(ws.playing, "pausa")
	_ticks(s, 10)
	assert_eq(float(ws.lathe_state().t_s), t, "en pausa no avanza")
	var step: Button = lp.get("btn_step")
	var n0 := int(ws.lathe_state().block_n)
	step.pressed.emit()
	assert_true(int(ws.lathe_state().block_n) != n0, "bloque a bloque")
	s.free()


func test_el_informe_aparece_al_terminar() -> void:
	var s := _section()
	var lp: Control = s.get("pages").torno
	var ws = s.get("state")
	var speeds: Dictionary = lp.get("speed_chips")
	(speeds[50.0] as Button).pressed.emit()
	assert_eq(ws.speed, 50.0, "×50")
	var card: Control = lp.get("report_card")
	assert_false(card.visible, "sin informe al empezar")
	(lp.get("btn_play") as Button).pressed.emit()
	var guard := 0
	while ws.report == null and guard < 400:
		s.call("tick", FRAME)
		guard += 1
	assert_true(ws.report != null, "el programa termina (%d fotogramas)" % guard)
	assert_true(card.visible, "el informe se ve")
	var score: Label = lp.get("report_score")
	assert_true(score.text.ends_with("/ 10") and score.text.begins_with("9,"), "nota en pantalla: %s" % score.text)
	var grid: GridContainer = lp.get("report_grid")
	var feats: Array = ws.report.features
	assert_eq(grid.get_child_count(), 5 * (feats.size() + 1), "tabla cota · medida · nominal · tolerancia · apto")
	var first_row := (grid.get_child(5) as Label).text
	assert_eq(first_row, str(feats[0].label).get_slice(" (", 0), "primera cota")
	assert_eq(lp.get("overlay"), "desviacion", "la capa 3D pasa a la desviación del plano")
	s.call("tick", FRAME)
	(lp.get("btn_restart") as Button).pressed.emit()
	assert_false(card.visible, "bruto nuevo: sin informe")
	assert_eq(lp.get("overlay"), "acabado", "y vuelve la capa del acabado")
	s.free()


func test_programa_con_errores_en_el_editor() -> void:
	var s := _section()
	var lp: Control = s.get("pages").torno
	var ws = s.get("state")
	(lp.get("program_chips").errores as Button).pressed.emit()
	var editor: TextEdit = lp.get("editor")
	assert_eq(editor.text, ws.program_text, "el editor enseña el programa")
	var errs: VBoxContainer = lp.get("error_list")
	assert_eq(errs.get_child_count(), 4, "cabecera y tres errores")
	assert_true((errs.get_child(1) as Label).text.begins_with("Línea 6 (N20)"), "error con línea y N")
	var line := int(ws.errors()[0].line) - 1
	assert_true(editor.get_line_background_color(line).a > 0.1, "la línea errónea se marca")
	(lp.get("btn_play") as Button).pressed.emit()
	assert_false(ws.playing, "con errores no arranca")
	var status: Label = lp.get("status_label")
	assert_true(status.visible and status.text.contains("errores"), "y lo dice")
	editor.text = ws.program_text.replace("G50 S2500", "G92 S2500").replace("R0.5", "R1").replace("G04 X1.5", "G04 K150")
	lp.call("apply_editor_text")
	assert_eq(ws.errors().size(), 0, "corregido en el editor")
	assert_eq(errs.get_child_count(), 1, "sin errores")
	s.free()


## Fase 2: los programas nuevos en el selector, la trayectoria compensada en la vista 2D y la lectura de roscado.
func test_programas_de_la_fase_2_en_pantalla() -> void:
	var s := _section()
	var lp: Control = s.get("pages").torno
	var ws = s.get("state")
	var chips: Dictionary = lp.get("program_chips")
	for id in ["pieza_a_g42", "pieza_b_g42", "pieza_c"]:
		assert_true(chips.has(id), "botón del programa %s" % id)
	(chips.pieza_a_g42 as Button).pressed.emit()
	assert_eq(ws.program_id, "pieza_a_g42")
	var pv: Control = lp.get("profile_view")
	var path: Array = pv.get("path")
	assert_true(path.size() > 5 and path.all(func(m: Dictionary) -> bool: return m.has("comp")), "la vista 2D tiene la trayectoria compensada (%d tramos)" % path.size())
	(chips.pieza_c as Button).pressed.emit()
	assert_eq(ws.piece, "C", "la pieza C")
	path = pv.get("path")
	assert_true(path.any(func(m: Dictionary) -> bool: return m.type == "thread"), "y las pasadas de roscado")
	var reads: Dictionary = lp.get("reads")
	_ticks(s, 1)
	assert_eq((reads.thread as Label).text, "—", "sin roscar, la lectura de roscado está vacía")
	(lp.get("speed_chips")[5.0] as Button).pressed.emit()
	(lp.get("btn_play") as Button).pressed.emit()
	var shown := ""
	var guard := 0
	while ws.playing and guard < 2000 and shown == "":
		s.call("tick", FRAME)
		guard += 1
		var txt := (reads.thread as Label).text
		if txt.contains("pasada"):
			shown = txt
	assert_true(shown.begins_with("paso 2,5") and shown.contains("de 14"), "lectura de roscado: %s" % shown)
	s.free()


func test_mando_manual_en_pantalla() -> void:
	var s := _section()
	var lp: Control = s.get("pages").torno
	var ws = s.get("state")
	(lp.get("mode_chips").manual as Button).pressed.emit()
	assert_eq(ws.lathe_mode, "manual", "manual")
	assert_true((lp.get("manual_card") as Control).visible, "tarjeta de mando manual")
	assert_false((lp.get("program_card") as Control).visible, "sin programa")
	ws.manual_spindle("cw")
	_ticks(s, 30)
	var reads: Dictionary = lp.get("reads")
	assert_true((reads.rpm as Label).text.contains("M3"), "cabezal a derechas: %s" % (reads.rpm as Label).text)
	s.free()


func test_controles_de_la_radial_cambian_el_resultado() -> void:
	var s := _section()
	(s.get("tab_chips").radial as Button).pressed.emit()
	var rp: Control = s.get("pages").radial
	var ws = s.get("state")
	var res: Dictionary = rp.get("res")
	var kerf0 := (res.kerf as Label).text
	var clean0 := (rp.get("clean_value") as Label).text
	(rp.get("disc_chips").grueso_3mm as Button).pressed.emit()
	assert_eq(ws.radial.disc_id, "grueso_3mm", "disco grueso")
	assert_true((res.kerf as Label).text != kerf0, "el surco cambia: %s → %s" % [kerf0, (res.kerf as Label).text])
	assert_true((rp.get("clean_value") as Label).text != clean0, "la limpieza cambia")
	var rpm: HSlider = rp.get("rpm_slider").slider
	_drag(rpm, 13000.0)
	assert_eq(float(ws.radial.rpm), 13000.0, "13.000 rpm")
	var warn: Label = rp.get("check_warn")
	assert_true(warn.visible and warn.text.contains("Exceso de velocidad"), "aviso de exceso de velocidad")
	(rp.get("panel_chips")["boro-22mnb5"] as Button).pressed.emit()
	var list: VBoxContainer = rp.get("warn_list")
	var texts := ""
	for ch in list.get_children():
		texts += (ch as Label).text + "\n"
	assert_true(texts.contains("ISO 17840"), "avisos de rescate con la hoja ISO 17840")
	assert_true(texts.contains("Fuente:"), "con su fuente")
	assert_eq((res.paint as Label).text, "sin pintura", "el pilar de boro va sin pintura")
	var diam: Dictionary = rp.get("diam_chips")
	assert_eq(diam.keys(), [115.0, 125.0], "solo los diámetros que hace el fabricante")
	var ang: HSlider = rp.get("angle_slider").slider
	_drag(ang, 20.0)
	assert_eq(float(ws.radial.angle_deg), 20.0, "ángulo")
	_ticks(s, 2)
	s.free()


## La escena de la radial toma la pintura de panels.gd: las piezas de rescate son acero desnudo (sin capas ni color
## de coche ni rótulo de pintura en el canto); las carrocerías llevan sus 110 µm.
func test_aspecto_de_las_chapas_de_la_radial() -> void:
	var Looks = load("res://app/taller/radial3d/looks.gd")
	var Panels = load("res://core/taller/panels.gd")
	for id in ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria", "boro-22mnb5", "dp800"]:
		assert_eq(float(Looks.panel(id).paint_um), float(Panels.get_panel(id).paint_um), "pintura de %s" % id)
	assert_eq(float(Looks.panel("boro-22mnb5").paint_um), 0.0, "pilar de boro sin pintura")
	assert_eq(float(Looks.panel("acero-dulce").paint_um), 110.0, "carrocería pintada")


func test_afiladora_y_calculadoras() -> void:
	var s := _section()
	var ws = s.get("state")
	s.call("select_machine", "afiladora")
	var sp: Control = s.get("pages").afiladora
	var out: Dictionary = sp.get("out")
	assert_true((out.angles as Label).text.contains("por lado"), "cuchillo: ángulo por lado")
	(sp.get("kind_chips").broca as Button).pressed.emit()
	assert_true((out.angles as Label).text.begins_with("punta 118°"), "broca: %s" % (out.angles as Label).text)
	assert_true((sp.get("grit_list") as VBoxContainer).get_child_count() >= 2, "progresión de granos")
	(sp.get("kind_chips").fresa as Button).pressed.emit()
	assert_true((out.angles as Label).text.begins_with("incidencia 1.ª"), "fresa: %s" % (out.angles as Label).text)
	assert_eq(ws.sharpen.machine_id, "afiladora_universal", "la fresa va a la afiladora universal")
	s.call("select_machine", "calculadoras")
	var cp: Control = s.get("pages").calculadoras
	var cout: Dictionary = cp.get("out")
	assert_true((cout.kc as Label).text.ends_with("N/mm²"), "kc: %s" % (cout.kc as Label).text)
	assert_true((cp.get("band_label") as Label).text.contains("Banda"), "banda de incertidumbre")
	(cp.get("kind_chips").fresado as Button).pressed.emit()
	assert_eq(ws.calc_kind, "fresado", "fresado")
	assert_true((cout.h as Label).text.begins_with("hm"), "espesor medio de viruta")
	var sliders: Dictionary = cp.get("sliders")
	assert_true(sliders.has("fz_mm") and not sliders.has("f_mm_rev"), "deslizadores del fresado")
	_drag(sliders.fz_mm.slider as HSlider, 0.25)
	assert_eq(float(ws.calc.fresado.fz_mm), 0.25, "fz del deslizador")
	(cp.get("kind_chips").taladrado as Button).pressed.emit()
	assert_true((cout.fc as Label).text.contains("por filo") and (cout.fc as Label).text.contains("empuje"), "taladrado: %s" % (cout.fc as Label).text)
	s.free()


func test_contrato_con_la_barra_del_programa() -> void:
	var s := _section()
	assert_true(s.has_method("headline") and str(s.call("headline")) != "", "titular para app/main.gd")
	var fund: Array = s.call("fundamentos")
	assert_true(fund.size() >= 5, "fundamentos del taller")
	for item: Array in fund:
		assert_eq(item.size(), 2, "[título, texto]")
		assert_true(str(item[0]) != "" and str(item[1]).length() > 40, "fundamento con texto: %s" % item[0])
	assert_true(str(s.call("fundamentos_note")).contains("estimación"), "nota de los fundamentos")
	s.free()


func test_modo_telefono() -> void:
	var s := _section()
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)  # sin anclas opuestas, el tamaño se puede fijar a mano
	s.size = Vector2(390, 844)
	s.call("_update_layout")
	assert_true(s.get("compact"), "a 390 px, una columna")
	for id in ["torno", "radial", "afiladora", "calculadoras"]:
		assert_true(s.get("pages")[id].get("pane").compact, "%s en una columna" % id)
	s.size = Vector2(1240, 880)
	s.call("_update_layout")
	assert_false(s.get("compact"), "a 1240 px, dos columnas")
	s.free()
