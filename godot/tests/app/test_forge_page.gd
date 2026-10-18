## Página «Laboratorio experimental (reforja)» de la cetrería (app/lab/cetreria/forge_page.gd, unidad 5f; petición 35):
## se enchufa en la cetrería (el interruptor sobre la vista, su entrada junto al material y «Reforjar con material» cuando
## la garra se rompe), se abre con la garra de la cetrería y vuelve; mientras está abierta, la cetrería no calcula; cada
## control lleva su nombre y su ayuda; las teclas mandan las órdenes del estado; los textos con números salen del estado;
## nada visible lleva rutas ni nombres internos; cabe en el teléfono y en escritorio; la garra hecha pasa a la cetrería y
## al banco; suena el bucle de la máquina que trabaja, y la invitación de la primera vez se recuerda.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const ForgePage = preload("res://app/lab/cetreria/forge_page.gd")
const CarePage = preload("res://app/lab/cetreria/care_page.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const CareState = preload("res://core/lab/claw_care_state.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const Card = preload("res://app/common/card.gd")

const CFG := "user://test_reforja_pagina.cfg"
## Rutas, nombres internos e identificadores con guion bajo que no se pueden ver.
const BAD := "docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawForge|ForgeData|ForgeTutorial|ClawSharpness|ClawsV2|ClawMass|ClawFracture|MovingCar|Incandescence|\\bData\\.|Physics\\.|SRC_|\\bunidad [0-9]|\\b[a-z0-9]+_[a-z0-9_]+\\b"


func before_each() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func _section(path := "") -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = path
	s.setup()
	s.art.threaded = false
	s.care_page.threaded = false
	return s


static func _page() -> ForgePage:
	var p := ForgePage.new()
	p.threaded = false
	p.setup()
	p.active = true
	return p


static func _key(code: Key, shift := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.shift_pressed = shift
	return k


static func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


## Hace la pieza entera con las órdenes de la página (lo que recomienda la receta), como los botones de las tarjetas: desde la
## 5m, la carga dentro de su máquina antes de arrancar, y acaba en la funda pulida y probada en la garra, sin pegar.
static func _make(p: ForgePage, pid: String) -> void:
	p.runner.post("set_process", [pid])
	p.runner.post("apply_recommended")
	if pid == State.STONE:
		p.runner.post("choose_stone", [""])
	else:
		p.runner.post("load_crucible")
		p.runner.post("insert_charge")
		p.runner.post("start")
		p.runner.post("skip")
		p.runner.post("cool_piece")
		p.runner.post("skip")
	for op: String in ["carve", "skip", "protect", "skip", "polish", "skip", "fit_test", "skip"]:
		p.runner.post(op)
	p.step(0.0)


## Para la sangre con el hemostático y presión (el reloj a ×10, apretando sobre la herida), como en la cetrería.
static func _stop_bleeding(st: CareState) -> void:
	if not bool(st.care.snapshot().bleeding.active):
		return
	st.pick("hemostatico")
	st.time_scale = 10.0
	var s0 := st.care.apex_mm()
	st.press_on(s0)
	for i in 240:
		st.drag(0.0, 0.0, s0, 1.0 / 60.0)
		st.tick(1.0 / 60.0)
	st.release()
	st.time_scale = 1.0


## Rompe la garra de la cetrería: seca, con la tenaza, un poco por delante de la carne viva (el corte la raja a lo largo
## hasta la carne viva), como en la demo de la cetrería.
static func _break(st: CareState) -> void:
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4))
	for i in int((CareState.CLIP_CLOSE_S + 0.2) * 60.0):
		st.tick(1.0 / 60.0)
	st.release()


func test_se_enchufa_en_la_cetreria_se_abre_y_vuelve() -> void:
	var s := _section()
	s.set_page(s.PAGE_CARE)
	var c: Control = s.care_page
	assert_true(c.lab_switch != null and c.reforge_slot.visible, "enchufado: el interruptor y la entrada junto al material")
	assert_true(c.lab_switch.get_parent() == c.mode_row and c.mode_row.get_parent() == c.left and c.left.get_child(0) == c.mode_row, "el interruptor, sobre la vista de la cetrería (en la fila de arriba, junto a la tienda de lentes)")
	assert_eq(String((c.lab_switch.buttons["reforja"] as Button).text), "Laboratorio experimental (reforja)", "con su nombre")
	assert_true(c.lab_page == null, "la página del laboratorio no existe hasta que se abre")
	assert_false(c.reforge_button.visible, "con la garra sana, sin «Reforjar con material»")
	var us0 := Time.get_ticks_usec()
	(c.lab_switch.buttons["reforja"] as Button).pressed.emit()
	print("    (coste) abrir el laboratorio la primera vez (crear la página, su estado y su primera vista): %s ms" % Js.to_fixed(float(Time.get_ticks_usec() - us0) / 1000.0, 1))
	var lp: ForgePage = c.lab_page
	assert_true(c.lab_open and lp != null and lp.visible, "el interruptor abre el laboratorio")
	assert_false(c.left.visible or c.right.visible, "que ocupa el sitio de la cetrería")
	var cv: Dictionary = c.runner.latest()
	var lv: Dictionary = lp.runner.latest()
	assert_eq(String(lv.setup.claw), String(cv.setup.claw), "con la garra de la cetrería")
	assert_eq([String(lv.setup.paw), String(lv.setup.digit)], [String(cv.paw), String(cv.digit)], "de su pata y su dedo")
	assert_eq(String(lv.claw.label), String(cv.claw_label), "y la vista lo dice")
	# con el laboratorio abierto, la cetrería no avanza y el laboratorio sí
	var t0 := float(cv.snap.t_s)
	lp.runner.post("apply_recommended")
	lp.runner.post("load_crucible")
	lp.runner.post("insert_charge")
	lp.runner.post("start")
	for i in 30:
		s.step(1000.0 / 60.0)
	c.runner.post("tick", [0.0])
	assert_eq(float(c.runner.latest().snap.t_s), t0, "el reloj de la cetrería, parado")
	assert_true(float(lp.runner.latest().run.progress) > 0.0, "la marcha del horno avanza")
	# las teclas van al laboratorio
	assert_true(c.handle_key(_key(KEY_H)), "H")
	assert_true(lp.help_panel.visible, "la ayuda del laboratorio")
	c.handle_key(_key(KEY_H))
	# «Trabajo veterinario» vuelve
	(lp.mode_seg.buttons["cetreria"] as Button).pressed.emit()
	assert_false(c.lab_open, "«Trabajo veterinario» vuelve a la cetrería")
	assert_true(c.left.visible and c.right.visible and not lp.visible, "la cetrería, otra vez a la vista")
	assert_eq(String(lp.mode_seg.value), "reforja", "el interruptor del laboratorio sigue en él")
	assert_eq(String(c.lab_switch.value), "cetreria", "y el de la cetrería, en ella")
	# la entrada junto al material también lo abre (la misma página)
	c.lab_entry.pressed.emit()
	assert_true(c.lab_open and c.lab_page == lp, "la entrada junto al material, la misma página")
	s.free()


func test_cada_control_con_nombre_y_ayuda() -> void:
	var p := _page()
	var nodes: Array = []
	_walk(p, nodes)
	var n := 0
	for x: Node in nodes:
		if x is BaseButton or x is Range:
			n += 1
			var c := x as Control
			var named := String(c.accessibility_name) != "" or (x is Button and String((x as Button).text) != "")
			assert_true(named, "%s (%s) tiene nombre" % [x.name, x.get_class()])
	assert_true(n > 80, "controles: %d" % n)
	for id: String in p.control_rows:
		var note: Label = p.control_rows[id].note
		assert_true(note.tooltip_text.contains("Fuente:"), "%s: qué hace, por qué importa y su fuente" % id)
	var desc := String(p.view3d.accessibility_description)
	assert_true(desc.contains("izquierdo") and desc.contains("dedo"), "la vista 3D dice cómo se maneja con el ratón y con el dedo")
	for id: String in p.recipe_tiles:
		assert_true(String((p.recipe_tiles[id] as Button).accessibility_name).begins_with("Fabricar"), "%s: su nombre" % id)
	for t: String in [ForgePage.HELP_MOUSE, ForgePage.HELP_KEYS, ForgePage.HELP_TOUCH]:
		var found := nodes.any(func(x: Node) -> bool: return x is Label and (x as Label).text == t)
		assert_true(found, "la ayuda (H) lleva «%s…»" % t.substr(0, 24))
	p.dispose()
	p.free()


func test_las_teclas_mandan_ordenes() -> void:
	var p := _page()
	var st: State = p.runner.state
	p.refresh()
	var ids: Array = State.CONTROL_IDS
	var i0 := ids.find(st.selected_control)
	assert_true(p.handle_key(_key(KEY_D)), "D")
	p.refresh()
	assert_eq(st.selected_control, String(ids[(i0 + 1) % ids.size()]), "D: el mando siguiente")
	p.handle_key(_key(KEY_A))
	p.refresh()
	assert_eq(st.selected_control, String(ids[i0]), "A: el anterior")
	while st.selected_control != "temp_c":
		p.handle_key(_key(KEY_D))
		p.refresh()
	p.handle_key(_key(KEY_W))
	assert_eq(float(st.dial.temp_c), State.TEMP_STEP, "W: un paso arriba (de 20 °C a la rejilla de 25)")
	p.handle_key(_key(KEY_W, true))
	assert_eq(float(st.dial.temp_c), State.TEMP_STEP + State.TEMP_FINE, "Mayús + W: un paso fino")
	p.handle_key(_key(KEY_S))
	assert_true(float(st.dial.temp_c) < State.TEMP_STEP + State.TEMP_FINE, "S: abajo")
	p.handle_key(_key(KEY_P))
	assert_true(st.pan_total() > 0.0, "P: lo recomendado en la balanza")
	p.handle_key(_key(KEY_L))
	assert_eq(st.last_action, "mix", "L: carga el crisol")
	p.handle_key(_key(KEY_ENTER))
	assert_false(st.running(), "Intro sin la carga dentro: no arranca")
	assert_true(st.notice.begins_with("No arranca"), "y dice por qué")
	p.handle_key(_key(KEY_M))
	assert_eq(st.last_action, "load_machine", "M: mete la carga en su máquina")
	var sp0 := st.speed_i
	p.handle_key(_key(KEY_X))
	assert_eq(st.speed_i, (sp0 + 1) % State.SPEEDS.size(), "X: la velocidad siguiente")
	p.handle_key(_key(KEY_X, true))
	assert_eq(st.speed_i, sp0, "Mayús + X: la anterior")
	p.handle_key(_key(KEY_ENTER))
	assert_true(st.running(), "Intro: arranca")
	p.handle_key(_key(KEY_SPACE))
	assert_false(st.running(), "Espacio: acaba la marcha")
	p.handle_key(_key(KEY_E))
	assert_eq(st.last_action, "cool", "E: saca y enfría")
	var t0 := st.carve_tool
	p.handle_key(_key(KEY_G))
	assert_true(st.carve_tool != t0, "G: la herramienta siguiente")
	st.set_carve_tool("sierra")
	for k: Array in [[KEY_T, "carve_pass"], [KEY_B, "protect"], [KEY_O, "polish"], [KEY_U, "fit"]]:
		p.handle_key(_key(k[0]))
		assert_eq(st.last_action, String(k[1]), "%s: %s" % [OS.get_keycode_string(k[0]), k[1]])
	p.handle_key(_key(KEY_T, true))
	assert_true(bool(st.calls[-1][1].light), "Mayús + T: una pasada suave")
	assert_false(p.handle_key(_key(KEY_K)), "K ya no prueba con la carga: eso es de la cetrería")
	st.set_process("oro")
	p.handle_key(_key(KEY_C))
	assert_eq(st.last_action, "wax", "C: el modelo de cera")
	p.handle_key(_key(KEY_R))
	assert_eq(st.last_action, "coat", "R: recubre")
	p.handle_key(_key(KEY_BACKSPACE))
	assert_eq(st.pan_total(), 0.0, "Retroceso: vacía la balanza")
	var idx := st.tut_step
	p.handle_key(_key(KEY_N))
	assert_eq(st.tut_step, idx + 1, "N: el paso siguiente del tutorial")
	var v0 := p.view
	p.handle_key(_key(KEY_V))
	assert_true(p.view != v0, "V: otra vista")
	p.handle_key(_key(KEY_H))
	assert_true(p.help_panel.visible, "H: la ayuda")
	p.handle_key(_key(KEY_ESCAPE))
	assert_false(p.help_panel.visible, "Esc: la cierra")
	st.pick_jar("al2o3")
	p.handle_key(_key(KEY_ESCAPE))
	assert_eq(st.held_jar, "", "Esc: suelta el tarro")
	assert_false(p.handle_key(_key(KEY_Z)), "otras teclas, no")
	p.dispose()
	p.free()


func test_los_textos_salen_del_estado() -> void:
	var p := _page()
	p.runner.post("set_process", ["zafiro"])
	p.runner.post("set_tutorial", [true])
	p.runner.post("tutorial_goto", ["zafiro"])
	p.runner.post("apply_recommended")
	p.refresh()
	var v: Dictionary = p.runner.latest()
	for c: Dictionary in v.controls:
		var row: Dictionary = p.control_rows[String(c.id)]
		if bool(c.margin.has):
			assert_eq((row.note as Label).text, String(c.margin.text), "%s: su margen, del estado" % c.id)
		if String(c.kind) == "dial":
			assert_eq((row.widget as ValueSlider).display.text, String(c.value_text), "%s: su valor, del estado" % c.id)
	for j: Dictionary in v.bench.jars:
		if float(j.grams) > 0.0:
			assert_true((p.jar_rows[String(j.id)].line as Label).text.begins_with(String(j.grams_text)), "%s: los gramos, del estado" % j.id)
	for r: Dictionary in v.readouts:
		assert_eq((p.reading_tiles[String(r.id)][1] as Label).text, String(r.value), "lectura %s" % r.id)
	# cada paso del tutorial: el texto, la fuente, el control y lo que pasa si te equivocas
	var with_mistake := 0
	for i in int(v.tutorial.count):
		var tv: Dictionary = p.runner.latest().tutorial
		var stp: Dictionary = tv.step
		assert_eq(p.tut_text.text, String(stp.text), "paso %d: su texto" % i)
		assert_true(p.tut_source.text.contains(String(stp.source_short)), "paso %d: su fuente" % i)
		assert_eq(p.tut_source.tooltip_text, String(stp.source), "paso %d: la fuente legible" % i)
		if String(tv.control) != "":
			assert_eq(p.tut_control.text, "Cómo: " + String(tv.control), "paso %d: cómo se hace" % i)
		if String(stp.mistake) != "":
			with_mistake += 1
			assert_eq(p.tut_mistake.text, "Si te equivocas: " + String(stp.mistake), "paso %d: si te equivocas" % i)
		p.runner.post("tutorial_next")
		p.step(0.0)
	assert_true(with_mistake >= 3, "los pasos dicen qué pasa si te equivocas (%d)" % with_mistake)
	# fuera de margen: qué ha pasado, cómo se arregla y con qué control
	p.runner.post("tutorial_goto", ["zafiro"])
	p.runner.post("load_crucible")
	p.runner.post("insert_charge")
	p.runner.post("set_control", ["temp_c", 1200.0])
	p.runner.post("start")
	p.step(0.0)
	assert_true(p.mistake_box.visible, "el error, explicado")
	assert_true(p.mistake_what.text.begins_with("Qué ha pasado: "), "qué ha pasado: %s" % p.mistake_what.text)
	assert_true(p.mistake_fix.text.begins_with("Cómo se arregla"), "cómo se arregla: %s" % p.mistake_fix.text)
	assert_true(p.mistake_how.text.begins_with("Cómo: "), "con qué control: %s" % p.mistake_how.text)
	# la ficha al terminar
	p.runner.post("restart")
	_make(p, "zafiro")
	v = p.runner.latest()
	assert_eq(p.sheet_verdict.text, String(v.sheet.verdict_text), "el veredicto de la ficha, del estado")
	var grid_texts: Array = p.sheet_grid.get_children().map(func(x: Node) -> String: return (x as Label).text)
	for r: Dictionary in v.sheet.rows:
		assert_true(grid_texts.has("→ " + String(r.after)), "%s: después, del estado" % r.id)
	assert_false(p.care_button.disabled, "la garra hecha puede pasar a la cetrería")
	assert_false(p.bench_button.disabled, "y al banco")
	p.dispose()
	p.free()


func test_sin_rutas_ni_nombres_internos_en_lo_que_se_ve() -> void:
	var p := _page()
	var bad := RegEx.create_from_string(BAD)
	p.values_toggle.pressed.emit()
	var checked := 0
	for pid: String in ["zafiro", "diamante_hpht", State.STONE, State.LIVE, "acero"]:
		p.runner.post("restart")
		p.runner.post("set_tutorial", [true])
		p.runner.post("tutorial_goto", [pid])
		if pid == State.LIVE:
			p.runner.post("set_process", [pid])
			p.runner.post("apply_recommended")
			p.runner.post("protect")
			p.runner.post("coat")
		elif pid == "diamante_hpht":
			# fuera de margen: el error explicado también se revisa
			p.runner.post("set_process", [pid])
			p.runner.post("apply_recommended")
			p.runner.post("load_crucible")
			p.runner.post("insert_charge")
			p.runner.post("set_control", ["pressure_mpa", 100.0])
			p.runner.post("start")
			p.runner.post("skip")
		else:
			_make(p, pid)
		p.step(0.0)
		p.refresh()
		var nodes: Array = []
		_walk(p, nodes)
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
				assert_true(m == null, "%s · %s: «%s» en «%s»" % [pid, n.name, m.get_string() if m != null else "", t.substr(0, 160)])
	assert_true(checked > 1500, "textos revisados: %d" % checked)
	p.dispose()
	p.free()


## En un teléfono (390 × 844) y en escritorio (1240 × 880), con fotogramas de verdad: nada más ancho que la pantalla
## (también con la ficha y los valores abiertos), una columna en el teléfono con la vista encima de las tarjetas y, en
## escritorio, la vista a la izquierda y las tarjetas a su derecha; en el teléfono, el deslizador grande sobre la vista.
func test_cabe_en_el_telefono_y_en_escritorio() -> void:
	for c: Array in [[Vector2(390, 844), false], [Vector2(1240, 880), true]]:
		var size: Vector2 = c[0]
		var wide: bool = c[1]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		s.care_page.threaded = false
		s.set_page(s.PAGE_CARE, false)
		var cp: Control = s.care_page
		cp.open_lab()
		var p: ForgePage = cp.lab_page
		_make(p, "zafiro")
		p.values_toggle.pressed.emit()
		await wait_frames(4)
		var where := "%dx%d" % [size.x, size.y]
		assert_true(s.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
		for card: Control in [p.head_card, p.tut_card, p.make_card, p.bench_card, p.furnace_card, p.shop_card, p.readings_card, p.sheet_card, p.values_card]:
			var r := card.get_global_rect()
			assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, (card as Card).title_label.text, r])
		var view := p.view_box.get_global_rect()
		if wide:
			assert_true(view.end.x <= p.tut_card.get_global_rect().position.x + 0.5, "escritorio: la vista a la izquierda de las tarjetas")
			assert_true(view.end.y <= size.y + 0.5, "escritorio: la vista cabe en el alto de la ventana (%s)" % view)
			assert_false(p.touch_box.visible, "escritorio: sin el deslizador grande (ratón y teclas)")
			assert_eq(p.inset_right(), 0.0, "escritorio: la vista no descuenta nada")
		else:
			assert_true(view.end.y <= p.tut_card.get_global_rect().position.y + 0.5, "teléfono: la vista encima de las tarjetas")
			assert_true(p.touch_box.visible, "teléfono: el deslizador grande sobre la vista")
			assert_true(p.touch_slider.get_global_rect().size.y >= 150.0 and p.touch_start.get_global_rect().size.y >= 44.0, "teléfono: grande, para el dedo")
			# la escena encuadra cada vista en lo que deja el deslizador (5j): lo que tapa, con un poco de aire
			var box := p.touch_box.get_global_rect()
			var covered := (view.end.x - box.position.x + ForgePage.TOUCH_GAP) / view.size.x
			assert_near(p.inset_right(), covered, 1e-6, 1e-6, "teléfono: la vista descuenta lo que tapa el deslizador (%s del ancho)" % p.inset_right())
		# la receta de nombre más largo (su título no se partía y la página se iba a 417 px en el teléfono)
		p.runner.post("set_process", ["diamante_cvd"])
		p.step(0.0)
		await wait_frames(4)
		assert_true(s.content.size.x <= size.x + 0.5, "%s: con el diamante CVD, nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
		host.visible = false


## La garra hecha pasa a la cetrería y al banco de ensayo (el rubí, con su propio material). Desde la 5o (petición 43), la
## funda llega sin pegar: queda en la bandeja de la colocación, en su pata y su dedo, y la garra sigue de queratina hasta que
## el usuario la coloca (eso lo prueban tests/lab/test_claw_care_colocar.gd y tests/app/test_care_colocar.gd).
func test_a_la_cetreria_y_al_banco() -> void:
	var s := _section()
	s.set_page(s.PAGE_CARE)
	var c: Control = s.care_page
	c.runner.post("set_paw", ["izquierda"])
	c.runner.post("set_digit", ["II"])
	c.step(0.0)
	c.open_lab()
	var lp: ForgePage = c.lab_page
	_make(lp, "zafiro")
	var care: Dictionary = lp.runner.latest().care
	assert_true(bool(care.ok), "la garra de zafiro puede pasar a la cetrería: %s" % care.text)
	lp.care_button.pressed.emit()
	assert_false(c.lab_open, "«Pasar a la cetrería» cierra el laboratorio")
	var cv: Dictionary = c.runner.latest()
	var bv: Dictionary = cv.bond
	assert_eq([String(bv.get("kind", "")), String(bv.get("material", ""))], ["funda", "zafiro"], "la funda de zafiro llega a la bandeja de la colocación")
	assert_false(bool(bv.attached), "sin pegar: la coloca el usuario")
	assert_eq([String(cv.paw), String(cv.digit)], ["izquierda", "II"], "en la pata y el dedo de los que vino")
	assert_false(bool(cv.reforged), "y hasta que se coloca, la garra sigue siendo de queratina")
	assert_true(String(bv.get("lab_text", "")).contains("holgura probada"), "con lo que dice el laboratorio de ella (pulida y probada en la garra)")
	# al banco
	c.open_lab()
	_make(lp, "rubi")
	var b: Dictionary = lp.runner.latest().bench_setup
	assert_eq(String(b.inlay), "rubi", "el rubí va al banco como rubí")
	lp.bench_button.pressed.emit()
	assert_eq(s.page, s.PAGE_BENCH, "«Probar en el banco» abre el banco")
	assert_eq(String(s.lab.claw.id), "aguila", "con la garra del animal")
	assert_eq(String(s.lab.inlay.id), "rubi", "y el material")
	assert_near(float(s.lab.sharpness), float(b.sharpness), 1e-12, 0.0, "y el afilado")
	s.free()


## La garra se rompe en la cetrería: aparece «Reforjar con material» (en el aviso del error y en la entrada junto al
## material) y lleva la garra rota al laboratorio, con la forma «Prótesis entera», el perfil que le queda y lo que queda de
## ella (stump_mm); hecha y enfriada la pieza, «Pasar a la cetrería» la devuelve como un bloque en bruto, en su pata y su
## dedo, una vez parada la sangre. Desde la 5o llega sin pegar: la garra sigue rota hasta que el usuario lo coloca.
func test_la_garra_rota_lleva_a_reforjar() -> void:
	var c := CarePage.new()
	c.threaded = false
	c.setup()
	c.plug_reforge_lab()
	c.active = true
	var st: CareState = c.runner.state
	_break(st)
	c.runner.post("tick", [0.0])
	c.step(0.0)
	var v: Dictionary = c.runner.latest()
	assert_true(bool(v.snap.damage.broken), "la garra se ha roto")
	assert_true(c.reforge_button.visible, "aparece «Reforjar con material»")
	assert_eq(c.lab_entry.text, "Reforjar con material", "también en la entrada junto al material")
	c.reforge_button.pressed.emit()
	assert_true(c.lab_open, "lleva al laboratorio")
	var lv: Dictionary = c.lab_page.runner.latest()
	assert_true(bool(lv.setup.broken), "con la garra rota")
	assert_eq(String(lv.shape), "protesis", "para hacerle una prótesis entera")
	assert_true(bool(lv.profile.broken), "y el perfil que le queda (para dibujarla)")
	assert_eq((lv.profile.s as PackedFloat64Array).size(), (v.snap.profile.s as PackedFloat64Array).size(), "el de la cetrería")
	assert_near(float(lv.setup.from_care.stump_mm), st.care.apex_mm(), 1e-9, 0.0, "y lo que queda de ella")
	assert_near(float(lv.setup.from_care.stump_mm), float(v.reforge_request.stump_mm), 1e-12, 0.0, "lo que publica la vista de la cetrería")
	# hecha y enfriada la pieza, vuelve como bloque en bruto (con la sangre ya parada)
	var lp: ForgePage = c.lab_page
	for op: String in ["apply_recommended", "load_crucible", "insert_charge", "start", "skip", "cool_piece", "skip"]:
		lp.runner.post(op)
	lp.step(0.0)
	assert_true(bool(lp.runner.latest().care.ok) and not lp.care_button.disabled, "fría, ya puede volver")
	c.lab_page.call("refresh")
	(lp.mode_seg.buttons["cetreria"] as Button).pressed.emit()
	_stop_bleeding(st)
	c.lab_entry.pressed.emit()
	assert_false(bool(st.care.snapshot().bleeding.active), "(la sangre, parada)")
	lp.care_button.pressed.emit()
	assert_false(c.lab_open, "«Pasar a la cetrería» cierra el laboratorio")
	var bv: Dictionary = st.view().bond
	assert_eq([String(bv.get("kind", "")), String(bv.get("material", ""))], ["bloque", "zafiro"], "el bloque de zafiro, en la bandeja: %s" % [bv.get("label", "")])
	assert_true(st.care.snapshot().claw.block == null and bool(st.care.snapshot().damage.broken), "sin pegar: la garra sigue rota")
	# otra garra sana después: sin el perfil de la rota
	c.close_lab()
	c.runner.post("restart")
	c.step(0.0)
	c.open_lab()
	lv = c.lab_page.runner.latest()
	assert_false(bool(lv.profile.broken), "otra garra sana, con su propio perfil")
	c.dispose()
	c.free()


## La prótesis de verdad (unidad 5j; lo pidió la 5g): con la garra rota, «Reforjar con material» ofrece el acrílico dental
## junto a las recetas de fantasía (con la garra sana no sale); se mezcla con la tecla L y vuelve a la cetrería como un
## bloque de acrílico, sin ficción.
func test_la_garra_rota_con_la_protesis_de_verdad() -> void:
	var healthy := _page()
	healthy.step(0.0)
	healthy.refresh()
	assert_false((healthy.recipe_tiles[State.ACRYLIC] as Button).visible, "con la garra sana, sin el acrílico")
	assert_false((healthy.tut_choice.buttons[State.ACRYLIC] as Button).visible, "ni su tutorial")
	healthy.dispose()
	healthy.free()
	var c := CarePage.new()
	c.threaded = false
	c.setup()
	c.plug_reforge_lab()
	c.active = true
	var st: CareState = c.runner.state
	_break(st)
	c.runner.post("tick", [0.0])
	c.step(0.0)
	c.reforge_button.pressed.emit()
	var lp: ForgePage = c.lab_page
	lp.step(0.0)
	lp.refresh()
	var tile: Button = lp.recipe_tiles[State.ACRYLIC]
	assert_true(tile.visible, "con la garra rota, el acrílico, junto a las de fantasía")
	assert_true(tile.text.contains("la vía real"), "y dice que es la vía real: %s" % tile.text)
	assert_true((lp.tut_choice.buttons[State.ACRYLIC] as Button).visible, "y su tutorial")
	tile.pressed.emit()
	lp.step(0.0)
	lp.refresh()
	assert_eq(String(lp.runner.latest().process), State.ACRYLIC, "elegido")
	assert_eq(lp.load_button.text, "Mezclar el acrílico (L)", "el botón dice qué hace")
	assert_true(lp.handle_key(_key(KEY_L)), "L")
	lp.step(0.0)
	assert_true(bool(lp.runner.latest().care.ok) and not lp.care_button.disabled, "mezclado, ya puede volver")
	lp.refresh()
	(lp.mode_seg.buttons["cetreria"] as Button).pressed.emit()
	_stop_bleeding(st)
	c.lab_entry.pressed.emit()
	lp.care_button.pressed.emit()
	assert_false(c.lab_open, "«Pasar a la cetrería» cierra el laboratorio")
	var bv: Dictionary = st.view().bond
	assert_eq([String(bv.get("kind", "")), String(bv.get("method", ""))], ["protesis", "acrilico"], "la prótesis de verdad: el acrílico se construye a mano sobre el muñón")
	assert_false(bool(bv.fiction), "sin ficción")
	assert_true(st.care.snapshot().claw.block == null, "y hasta la primera capa, nada pegado")
	c.dispose()
	c.free()


## El bucle de la máquina que trabaja (bus «Lab»): la llama del soplete en Verneuil, la prensa en el HPHT, la muela al
## tallar; parado, en silencio.
func test_suena_el_bucle_de_la_maquina() -> void:
	var p := ForgePage.new()
	p.threaded = false
	add_to_tree(p)
	p.setup()
	p.active = true
	assert_eq(p._loop.bus, &"Lab", "por el bus «Lab»")
	p.step(16.0)
	assert_eq(p.loop_playing(), "", "parado, en silencio")
	for c: Array in [["zafiro", "forja-llama"], ["diamante_hpht", "forja-prensa"], ["acero", "forja-induccion"]]:
		p.runner.post("set_process", [String(c[0])])
		p.runner.post("apply_recommended")
		p.runner.post("load_crucible")
		p.runner.post("insert_charge")
		p.runner.post("start")
		p.step(16.0)
		assert_eq(p.loop_playing(), String(c[1]), "%s: %s" % c)
		p.runner.post("skip")
		p.step(16.0)
		assert_eq(p.loop_playing(), "", "%s: al acabar, en silencio" % c[0])
		p.runner.post("restart")
	_make(p, "zafiro")
	p.runner.post("restart")
	p.runner.post("apply_recommended")
	p.runner.post("load_crucible")
	p.runner.post("insert_charge")
	p.runner.post("start")
	p.runner.post("skip")
	p.runner.post("cool_piece")
	p.runner.post("skip")
	p.runner.post("carve")
	p.step(16.0)
	assert_eq(p.loop_playing(), "forja-muela", "al tallar, la muela")
	p.set_active(false)
	assert_eq(p.loop_playing(), "", "fuera de la página, en silencio")
	p.dispose()


## «¿Primera vez? Empieza por el horno»: se enseña la primera vez, empieza el tutorial del horno y se recuerda en los
## ajustes de la sección.
func test_la_primera_vez_invita_al_tutorial_y_se_recuerda() -> void:
	var s := _section(CFG)
	s.set_page(s.PAGE_CARE)
	s.care_page.open_lab()
	var p: ForgePage = s.care_page.lab_page
	assert_true(p.intro_box.visible, "la primera vez, la invitación")
	p.runner.post("set_tutorial", [false])
	var go := _find_button(p.intro_box, "Empezar el tutorial del horno")
	assert_true(go != null, "con su botón")
	go.pressed.emit()
	assert_false(p.intro_box.visible, "al pulsarlo, se cierra")
	var tv: Dictionary = p.runner.latest().tutorial
	assert_true(bool(tv.on) and String(tv.id) == State.GENERAL and int(tv.index) == 0, "y empieza el tutorial del horno por el primer paso")
	s.free()
	var c := ConfigFile.new()
	assert_eq(c.load(CFG), OK, "hay ajustes")
	assert_eq(c.get_value("lab", "forge_intro", false), true, "guardado en [lab]")
	var t := _section(CFG)
	t.set_page(t.PAGE_CARE)
	t.care_page.open_lab()
	assert_false((t.care_page.lab_page as ForgePage).intro_box.visible, "la segunda vez, ya no")
	t.free()


static func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for ch in n.get_children():
		var b := _find_button(ch, text)
		if b != null:
			return b
	return null


## Lo que cuesta repintar la página en el hilo de la interfaz mientras el horno trabaja (la vista cambia en cada
## fotograma): solo se repinta lo que ha cambiado, comparando huellas.
func test_coste_del_repintado() -> void:
	var p := _page()
	p.runner.post("apply_recommended")
	p.runner.post("load_crucible")
	p.runner.post("insert_charge")
	p.runner.post("start")
	p.step(16.0)
	var paints0 := p.paints
	var sum := 0
	var mx := 0
	for i in 120:
		p.step(1000.0 / 30.0)
		sum += p.last_paint_us
		mx = maxi(mx, p.last_paint_us)
	var n := p.paints - paints0
	var avg := float(sum) / 120.0 / 1000.0
	print("    (coste) repintado de la página durante la marcha: %s ms de media en %d repintados, máximo %s ms" % [Js.to_fixed(avg, 3), n, Js.to_fixed(float(mx) / 1000.0, 3)])
	assert_true(n > 60, "la vista cambia con la marcha (%d repintados)" % n)
	assert_true(avg < 3.0, "%s ms de media por repintado" % avg)
	p.dispose()
	p.free()


const Js = preload("res://core/shared/js.gd")
