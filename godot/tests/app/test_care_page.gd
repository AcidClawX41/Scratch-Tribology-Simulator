## Página «Cetrería» de la tribología biológica (app/lab/cetreria/care_page.gd, unidad 5b): la tercera página de la
## sección, con las mismas reglas que las otras (la que no se ve no calcula ni suena, y se recuerda); cada control lleva
## su nombre para los lectores de pantalla y su ayuda; las teclas mandan las órdenes del estado sin forzar nada; los
## textos con números salen del estado (ClawCareState), y los efectos suenan con los ids del motor.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const CarePage = preload("res://app/lab/cetreria/care_page.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Pill = preload("res://app/common/pill.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const PillChoice = preload("res://app/lab/cetreria/pill_choice.gd")

const CFG := "user://test_cetreria_pagina.cfg"


func before_each() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func _section(path := "") -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = path
	s.setup()
	s.art.threaded = false
	return s


func _key(code: Key, shift := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.shift_pressed = shift
	return k


static func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func test_tercera_pagina_con_sus_reglas() -> void:
	var s := _section()
	assert_true((s.PAGES as Array).any(func(p: Dictionary) -> bool: return p.id == "cetreria"), "la cetrería es una página")
	assert_eq((s.PAGES as Array).size(), 3, "tres páginas")
	assert_false(s.care_page.visible, "en el banco no se ve")
	s.page_bar.buttons[s.PAGE_CARE].pressed.emit()
	assert_eq(s.page, s.PAGE_CARE, "el botón lleva a la cetrería")
	assert_true(s.care_page.visible, "se ve")
	assert_false(s.columns.visible, "sin las tarjetas del banco")
	assert_false(s.moving_car_card.visible, "ni el coche")
	assert_eq(s.headline(), "¿Afilada como una daga?", "su titular")
	# en la cetrería el banco no ensaya ni avanza
	var count: int = s.lab.count
	s.run()
	s.step(400.0)
	assert_eq(s.lab.count, count, "ARAÑAR no ensaya en la cetrería")
	# en el banco, la cetrería no calcula: su reloj no avanza
	var t0 := float(s.care_page.runner.latest().snap.t_s)
	s.set_page(s.PAGE_BENCH)
	for i in 30:
		s.step(16.0)
	s.care_page.runner.post("tick", [0.0])
	assert_eq(float(s.care_page.runner.latest().snap.t_s), t0, "fuera de su página, el reloj de la cetrería está parado")
	s.set_page(s.PAGE_CARE)
	for i in 30:
		s.step(1000.0 / 60.0)
	assert_true(float(s.care_page.runner.latest().snap.t_s) > t0, "en su página, el reloj avanza")
	s.free()


func test_la_pagina_se_recuerda() -> void:
	var s := _section(CFG)
	s.set_page(s.PAGE_CARE)
	s.free()
	var c := ConfigFile.new()
	assert_eq(c.load(CFG), OK, "hay ajustes")
	assert_eq(c.get_value("lab", "page", ""), "cetreria", "guardada en [lab]")
	var t := _section(CFG)
	assert_eq(t.page, t.PAGE_CARE, "al abrir, la cetrería")
	assert_true(t.care_page.visible, "con su página")
	t.free()


func test_cada_control_con_nombre_y_ayuda() -> void:
	var p := CarePage.new()
	p.setup()
	var nodes: Array = []
	_walk(p, nodes)
	var buttons := 0
	for n: Node in nodes:
		if n is BaseButton or n is Range or n is OptionButton:
			buttons += 1
			var c := n as Control
			var named := String(c.accessibility_name) != "" or (n is Button and String((n as Button).text) != "")
			assert_true(named, "%s (%s) tiene nombre" % [n.name, n.get_class()])
	assert_true(buttons > 30, "controles: %d" % buttons)
	for id: String in p.tray_pills:
		var b: Button = p.tray_pills[id]
		assert_true(String(b.accessibility_name).begins_with("Coger"), "%s: nombre" % id)
		assert_true(String(b.tooltip_text).contains("Fuente"), "%s: ayuda con su fuente" % id)
	assert_true(String(p.view3d.accessibility_name) != "" and String(p.view3d.accessibility_description).contains("izquierdo"), "la vista 3D dice cómo se maneja")
	p.dispose()
	p.free()


func test_las_teclas_mandan_ordenes_sin_forzar() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	assert_true(p.handle_key(_key(KEY_1)), "1")
	assert_eq(st.tool, "lima_bastarda", "1: la lima gruesa")
	p.handle_key(_key(KEY_2))
	assert_eq(st.tool, "lima_fina", "2: la lima fina")
	p.handle_key(_key(KEY_4))
	assert_eq(st.tool, "guillotina", "4: el cortaúñas")
	p.handle_key(_key(KEY_3))
	assert_eq(st.tool, "torno", "3: el torno")
	p.handle_key(_key(KEY_E))
	assert_true(st.rotary_on, "E: enciende el torno")
	p.handle_key(_key(KEY_Q))
	assert_eq(st.rpm(), 13000.0, "Q: la otra velocidad")
	var a0 := st.angle_deg
	p.handle_key(_key(KEY_D))
	assert_eq(st.angle_deg, a0 + 1.0, "D: un grado más")
	p.handle_key(_key(KEY_A))
	p.handle_key(_key(KEY_A))
	assert_eq(st.angle_deg, a0 - 1.0, "A: un grado menos")
	for i in 60:
		p.handle_key(_key(KEY_W))
	assert_eq(st.force_n, State.FORCE_MAX, "W no pasa de la presión máxima")
	p.handle_key(_key(KEY_SPACE))
	assert_true(st.paused, "Espacio: pausa")
	p.handle_key(_key(KEY_SPACE))
	assert_false(st.paused, "y sigue")
	p.handle_key(_key(KEY_H))
	assert_true(p.help_panel.visible, "H: la ayuda")
	p.handle_key(_key(KEY_ESCAPE))
	assert_eq(st.tool, "", "Esc: la deja en la bandeja")
	var seed0 := String(st.setup.seed)
	p.handle_key(_key(KEY_R))
	assert_true(String(st.setup.seed) != seed0, "R: empezar de nuevo, con otra garra")
	assert_false(p.handle_key(_key(KEY_K)), "otras teclas, no")
	p.dispose()
	p.free()


func test_los_textos_salen_del_estado_y_suenan_los_efectos() -> void:
	var played: Array = []
	var p := CarePage.new()
	p.setup(func(id: String, vol: float) -> void: played.append([id, vol]))
	p.active = true
	p.refresh()
	var v: Dictionary = p.runner.latest()
	assert_eq(p.hud_tool.text, String(v.texts.tool), "la herramienta, del estado")
	assert_eq(p.hud_hand.text, String(v.texts.hand), "la mano, del estado")
	assert_eq(p.tut_text.text, String(v.tutorial.step.text), "el paso del tutorial, del motor")
	assert_true(p.tut_source.text.contains(String(v.tutorial.step.source_short)), "con su fuente legible")
	for r: Dictionary in v.readouts:
		var tile: Array = p.reading_tiles[String(r.id)]
		assert_eq((tile[1] as Label).text, String(r.value), "lectura %s" % r.id)
	# cortar la carne viva: suena el corte, con el id del motor
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	st.pick("tenaza")
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0))
	for i in 40:
		st.tick(1.0 / 60.0)
	p.runner.post("tick", [0.0])
	p.step(0.0)
	var ids: Array = played.map(func(x: Array) -> String: return String(x[0]))
	assert_true(ids.has("skin-cut"), "suena el corte de la carne viva: %s" % [ids])
	assert_true(String(p.tut_title.text).begins_with("Si sangra"), "el tutorial salta a «Si sangra»: %s" % p.tut_title.text)
	p.runner.post("finish")
	p.step(0.0)
	assert_true(p.report_card.visible, "al terminar, el informe")
	assert_eq(p.report_grade.text, String(p.runner.latest().report.gradeText), "con la nota del motor")
	p.dispose()
	p.free()


## «¿Primera vez? Empieza aquí»: se enseña la primera vez, empieza el tutorial y se recuerda en los ajustes de la sección.
func test_la_primera_vez_invita_al_tutorial_y_se_recuerda() -> void:
	var s := _section(CFG)
	s.set_page(s.PAGE_CARE)
	var p: Control = s.care_page
	assert_true(p.intro_box.visible, "la primera vez, la invitación")
	var go: Button = _find_button(p.intro_box, "Empezar el tutorial")
	assert_true(go != null, "con su botón")
	p.runner.post("set_tutorial", [false])
	go.pressed.emit()
	assert_false(p.intro_box.visible, "al pulsarlo, se cierra")
	var tv: Dictionary = p.runner.latest().tutorial
	assert_true(bool(tv.on) and String(tv.process) == "preparar" and int(tv.index) == 0, "y el tutorial empieza por el primer paso")
	s.free()
	var c := ConfigFile.new()
	assert_eq(c.load(CFG), OK, "hay ajustes")
	assert_eq(c.get_value("lab", "care_intro", false), true, "guardado en [lab]")
	var t := _section(CFG)
	t.set_page(t.PAGE_CARE)
	assert_false(t.care_page.intro_box.visible, "la segunda vez, ya no")
	t.free()


static func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for ch in n.get_children():
		var b := _find_button(ch, text)
		if b != null:
			return b
	return null


## La garra reforjada se elige a la vista (una píldora por material) y lleva su propio flujo del tutorial.
func test_el_material_se_elige_a_la_vista() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	assert_eq(p.inlay_pills.size(), (State.inlay_options() as Array).size(), "una píldora por material")
	assert_true((p.inlay_pills["none"] as Pill).button_pressed, "queratina al empezar")
	(p.inlay_pills["zafiro"] as Pill).pressed.emit()
	p.step(0.0)
	var v: Dictionary = p.runner.latest()
	assert_eq(String(v.setup.inlay), "zafiro", "la píldora pone el material")
	assert_true((p.inlay_pills["zafiro"] as Pill).button_pressed, "y se enciende")
	assert_true((v.tutorial.processes as Array).any(func(x: Dictionary) -> bool: return x.id == "reforjada"), "con el flujo de las reforjadas")
	assert_true(String((p.inlay_pills["zafiro"] as Pill).accessibility_description).contains("HV"), "y su dureza en la ayuda")
	p.dispose()
	p.free()


## Al terminar, la ficha antes → después con los números del motor; un error se explica (qué ha pasado, cómo se arregla,
## con qué control y su fuente); «Valores y fuentes» da cada dato con su calidad.
func test_ficha_errores_y_valores() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("guillotina")
	st.press_on(st.care.apex_mm() - 2.0)
	for i in 40:
		st.tick(1.0 / 60.0)
	p.runner.post("tick", [0.0])
	p.step(0.0)
	assert_true(p.mistake_box.visible, "el error se explica")
	assert_true(p.mistake_what.text.contains("grieta"), "qué ha pasado: %s" % p.mistake_what.text)
	assert_true(p.mistake_fix.text.contains("Limar la cara del corte"), "cómo se arregla: %s" % p.mistake_fix.text)
	assert_true(p.mistake_how.text.contains("Tecla 1"), "con qué control: %s" % p.mistake_how.text)
	p.runner.post("dismiss_mistake")
	p.step(0.0)
	assert_false(p.mistake_box.visible, "«Entendido» la quita")
	p.values_toggle.pressed.emit()
	p.step(0.0)
	assert_true(p.values_list.visible, "los valores se despliegan")
	var shown := 0
	for it: Array in p.values_rows:
		if (it[0] as Control).visible:
			shown += 1
			assert_true((it[2] as Label).text.begins_with("Fuente: ") and (it[2] as Label).text.length() > 10, "cada valor con su fuente")
	assert_true(shown >= 20, "los datos del ensayo: %d" % shown)
	p.runner.post("finish")
	p.step(0.0)
	var sh: Dictionary = p.runner.latest().sheet
	assert_true(p.report_card.visible and not sh.is_empty(), "al terminar, la ficha")
	var labels: Array = sh.rows.map(func(r: Dictionary) -> String: return String(r.label))
	for want in ["Largo", "Sobrante", "Radio de la punta", "Faceta", "Aguanta de lado", "Distancia a la carne viva", "Grietas y roturas", "Calor en la carne viva", "Sangre", "Material y dureza"]:
		assert_true(labels.has(want), "la ficha tiene «%s»" % want)
	assert_eq(p.sheet_grid.get_child_count(), 3 * (1 + (sh.rows as Array).size()), "una fila por dato, antes y después")
	assert_eq(p.report_grade.text, String(sh.grade_text), "la nota del motor")
	p.dispose()
	p.free()


## En los textos visibles (y en las ayudas y las descripciones para lectores de pantalla) no hay rutas ni nombres
## internos: ni docs/, ni .gd, ni §, ni nombres de clases o de fichas del motor. Se recorre la página entera con el
## informe, los valores desplegados, un error explicado y una garra reforjada.
func test_sin_rutas_ni_nombres_internos_en_lo_que_se_ve() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	var bad := RegEx.create_from_string("docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawSharpness|ClawsV2|ClawMass|ClawFracture|MovingCar|\\bData\\.|Physics\\.|SRC_|\\bunidad [0-9]")
	for round in 2:
		if round == 1:
			st.set_inlay("vidrio")
			st.set_sedation("sujecion")
		st.set_humidity("seca")
		st.pick("guillotina" if round == 0 else "lima_diamante_fina")
		if round == 0:
			st.press_on(st.care.apex_mm() - 2.0)
			for i in 40:
				st.tick(1.0 / 60.0)
		else:
			st.set_angle(20.0)
			for k in 6:
				st.press_on(st.care.apex_mm() - 1.5)
				st.drag(6.0, 6.0, st.care.apex_mm() - 1.0, 0.1)
				st.release()
		p.runner.post("tick", [0.0])
		p.step(0.0)
		if not p.values_list.visible:
			p.values_toggle.pressed.emit()
		p.runner.post("finish")
		p.step(0.0)
		var nodes: Array = []
		_walk(p, nodes)
		var checked := 0
		for n: Node in nodes:
			var texts: Array = []
			if n is Label:
				texts.append((n as Label).text)
			if n is Button:
				texts.append((n as Button).text)
			if n is Control:
				texts.append((n as Control).tooltip_text)
				texts.append(String((n as Control).accessibility_name))
				texts.append(String((n as Control).accessibility_description))
			for t: String in texts:
				if t == "":
					continue
				checked += 1
				var m := bad.search(t)
				assert_true(m == null, "%s: «%s» en «%s»" % [n.name, m.get_string() if m != null else "", t.substr(0, 160)])
		assert_true(checked > 200, "textos revisados: %d" % checked)
		p.runner.post("restart")
		p.step(0.0)
	p.dispose()
	p.free()


## La página en un teléfono (390 × 844) y en escritorio (1240 × 880), con fotogramas de verdad: nada más ancho que la
## pantalla (también con el informe, la ficha y los valores abiertos), una columna en el teléfono y, en escritorio, la
## vista 3D a la izquierda con la columna de las tarjetas a su derecha.
func test_cabe_en_el_telefono_y_en_escritorio() -> void:
	for c: Array in [[Vector2(390, 844), false], [Vector2(1240, 880), true]]:
		var size: Vector2 = c[0]
		var wide: bool = c[1]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		s.set_page(s.PAGE_CARE, false)
		var p: Control = s.care_page
		p.threaded = false
		# con lo más ancho a la vista: el oso (cuatro patas y cinco garras) y la amoladora (cuatro velocidades)
		p.runner.post("set_animal", ["oso"])
		p.runner.post("pick", ["amoladora"])
		p.runner.post("set_rotary", [true])
		p.runner.post("finish")
		p.values_toggle.pressed.emit()
		await wait_frames(4)
		var where := "%dx%d" % [size.x, size.y]
		assert_true(s.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
		for card: Control in [p.intro_box, p.tut_card, p.report_card, p.tools_card, p.readings_card, p.values_card]:
			var r := card.get_global_rect()
			assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, card.name, r])
		var view := (p.view_box as Control).get_global_rect()
		if wide:
			assert_true(view.end.x <= p.tut_card.get_global_rect().position.x + 0.5, "escritorio: la vista a la izquierda de las tarjetas")
			assert_true(view.end.y <= size.y + 0.5, "escritorio: la vista cabe en el alto de la ventana (%s)" % view)
		else:
			assert_true(view.end.y <= p.tut_card.get_global_rect().position.y + 0.5, "teléfono: la vista encima de las tarjetas")
		host.visible = false


## «Probar en el banco»: al terminar, la garra (la del banco de ese animal, su material y el afilado que deja la punta,
## ClawSharpness.sharpness_for) pasa al banco de ensayo, que se abre con esos ajustes. Sin física nueva.
func test_probar_en_el_banco() -> void:
	var s := _section()
	s.set_page(s.PAGE_CARE)
	var p: Control = s.care_page
	var st: State = p.runner.state
	st.set_inlay("acero")
	st.set_sedation("sujecion")
	st.pick("lima_fina")
	st.set_angle(22.0)
	st.set_force(5.0)
	for k in 8:
		st.press_on(st.care.apex_mm() - 1.0)
		st.drag(3.0, 3.0, st.care.apex_mm() - 0.5, 0.1)
		st.release()
	p.runner.post("finish")
	p.step(0.0)
	var b: Dictionary = p.runner.latest().bench
	assert_true(p.bench_button.visible, "al terminar, el botón")
	assert_eq(String(b.claw), "aguila", "la garra del banco del animal")
	assert_eq(String(b.inlay), "acero", "con su material")
	var r0 := ClawSharpness.radius_um_of_area(float(CareData.claw_entry("aguila").area))
	assert_near(float(b.sharpness), ClawSharpness.sharpness_for(r0, float(st.care.tip_state().tipRadiusUm)), 1e-12, 0.0, "el afilado, la inversa del deslizador del banco")
	assert_true(float(b.sharpness) > 0.0, "más fina que la natural: afilada (%s)" % b.sharpness)
	p.bench_button.pressed.emit()
	assert_eq(s.page, s.PAGE_BENCH, "se abre el banco")
	assert_eq(String(s.lab.claw.id), "aguila", "con la garra")
	assert_eq(String(s.lab.inlay.id), "acero", "el material")
	assert_near(float(s.lab.sharpness), float(b.sharpness), 1e-12, 0.0, "y el afilado")
	s.free()


## Las patas y la amoladora desde la página (unidad 5c): la pata y la garra de cada animal en su selector (cuatro patas el
## tigre y el oso, dos los demás) y con las teclas P y G; la cabecera de la vista dice de qué pata y de qué garra es; la
## tecla 5 coge la amoladora y sus cuatro velocidades salen en su selector; sobre la vista, el interruptor, la velocidad
## y el deslizador de la presión; y el sitio de la reforja experimental, escondido hasta que se enchufe.
func test_las_patas_y_la_amoladora_desde_la_pagina() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	p.refresh()
	assert_true((p.paw_choices["rapaz"] as Control).visible, "el selector de las patas de la rapaz")
	assert_false((p.paw_choices["tigre"] as Control).visible, "el del tigre, no")
	assert_eq((p.paw_choices["rapaz"] as PillChoice).buttons.size(), 2, "la rapaz, dos patas")
	assert_eq((p.paw_choices["tigre"] as PillChoice).buttons.size(), 4, "el tigre, cuatro")
	assert_eq((p.digit_choices["rapaz"] as PillChoice).buttons.size(), 4, "y la rapaz, cuatro garras en cada una")
	assert_eq(p.hud_claw.text, "Pata derecha · dedo III, el del medio", "la vista dice de qué pata y de qué garra")
	p.handle_key(_key(KEY_P))
	assert_eq(st.paw, "izquierda", "P: la otra pata")
	p.handle_key(_key(KEY_G))
	assert_eq(st.digit, "II", "G: la garra siguiente")
	p.refresh()
	((p.paw_choices["rapaz"] as PillChoice).buttons["derecha"] as Button).pressed.emit()
	((p.digit_choices["rapaz"] as PillChoice).buttons["I"] as Button).pressed.emit()
	p.refresh()
	assert_eq([st.paw, st.digit], ["derecha", "I"], "los selectores eligen la pata y la garra")
	assert_eq(p.hud_claw.text, "Pata derecha · dedo I, el pulgar", "y la vista lo dice")
	(p.animal_seg.buttons["oso"] as Button).pressed.emit()
	p.refresh()
	assert_true((p.paw_choices["oso"] as Control).visible, "con el oso, su selector de cuatro patas")
	((p.paw_choices["oso"] as PillChoice).buttons["trasera_izquierda"] as Button).pressed.emit()
	p.refresh()
	assert_true(p.hud_claw.text.begins_with("Pata trasera izquierda"), "una pata trasera del oso")
	# la amoladora: la tecla 5, su selector de cuatro velocidades y los mandos sobre la vista
	p.handle_key(_key(KEY_5))
	p.refresh()
	assert_eq(st.tool, "amoladora", "5: la amoladora")
	assert_true(p.rpm_seg_grinder.visible and not p.rpm_seg.visible, "sus velocidades, no las del torno")
	assert_eq(p.rpm_seg_grinder.buttons.size(), 4, "cuatro")
	assert_true(p.touch_box.visible and p.touch_power.visible, "sobre la vista, su interruptor")
	p.touch_power.pressed.emit()
	p.refresh()
	assert_true(st.rotary_on, "el interruptor de la vista la enciende")
	p.touch_speed.pressed.emit()
	assert_eq(st.rpm(), 14000.0, "y la velocidad, la siguiente")
	# (fuera del árbol, el deslizador no avisa solo al cambiar desde el código: se emite como lo haría el dedo)
	p.touch_force.value_changed.emit(1.0)
	assert_eq(st.force_n, State.FORCE_MAX, "el deslizador de la vista, la presión")
	assert_false(p.reforge_slot.visible, "la reforja experimental, escondida hasta que se enchufe")
	var panel := Label.new()
	panel.text = "Reforja"
	p.plug_reforge(panel)
	assert_true(p.reforge_slot.visible and panel.get_parent() == p.reforge_slot, "se enchufa junto al material")
	p.dispose()
	p.free()


## La herramienta gastada (unidad 5l): con la de la mano gastada aparece «Una nueva (N)», el texto lo dice, y la tecla N (o el
## botón) la cambia por una nueva de la bandeja.
func test_una_herramienta_gastada_y_una_nueva_con_n() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	p.handle_key(_key(KEY_1))
	p.refresh()
	assert_false(p.renew_pill.visible, "nueva: sin el botón")
	# gastada como si hubiera limado mucho algo más duro que ella (el kit del ensayo); cualquier orden publica la vista
	st.kit.add(CareData.tool("lima_bastarda"), 5.0, 3.0, 0.0, 0.0)
	p.runner.post("set_force", [3.5])
	p.refresh()
	assert_true(bool(st.view().hand.worn), "(gastada)")
	assert_true(p.renew_pill.visible, "aparece «Una nueva (N)»")
	assert_true(st.tool_text().contains("Embotada"), "y el texto lo dice: %s" % st.tool_text())
	assert_true(p.handle_key(_key(KEY_N)), "N")
	p.refresh()
	assert_eq(String(st.view().tools.lima_bastarda.state), "nueva", "N: una nueva de la bandeja")
	assert_false(p.renew_pill.visible, "y el botón se va")
	assert_eq(String(st.history.back()[1]), "renew_tool", "y queda en el ensayo")
	p.dispose()
	p.free()
