## La colocación a mano de la pieza de la reforja en la página «Cetrería» (unidad 5o): «Pasar a la cetrería» deja la pieza en
## la bandeja sin pegar; la tarjeta «Colocar la pieza de la reforja» manda las órdenes del estado (sin física en la interfaz);
## la tecla K aprieta y sujeta mientras se mantiene; la escena enseña la pieza en la bandeja, la coge con el ratón y la acopla al
## muñón; y la tarjeta cabe en el teléfono.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const State = preload("res://core/lab/claw_care_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")

const SHEATH := { "animal": "rapaz", "claw": "aguila", "inlay": "acero", "paw": "derecha", "digit": "III" }


func _section() -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = ""
	s.setup()
	s.art.threaded = false
	return s


func _key(code: Key, pressed := true) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = pressed
	return k


func test_la_pieza_llega_y_la_tarjeta_manda_las_ordenes() -> void:
	var s := _section()
	s.set_page(s.PAGE_CARE)
	var p: Control = s.care_page
	var st: State = p.runner.state
	assert_false(p.bond_card.visible, "sin pieza, sin tarjeta")
	p.receive_forged(SHEATH)
	p.refresh()
	assert_true(st.bond() != null, "la pieza ha llegado")
	assert_false(st.is_reforged(), "sin pegar: la garra sigue de queratina")
	assert_true(p.bond_card.visible, "la tarjeta se enseña")
	# los botones mandan las órdenes del estado
	var bs: Dictionary = p.bond_card.buttons
	(bs.alcohol as BaseButton).pressed.emit()
	assert_eq(st.bond().cleaner, "alcohol", "limpiar con alcohol")
	(bs.purgar as BaseButton).pressed.emit()
	assert_true(st.bond().purged, "purgar la cánula")
	(bs.aplicar as BaseButton).pressed.emit()
	assert_true(st.bond().applied_t >= 0.0, "poner el adhesivo")
	(bs.coger as BaseButton).pressed.emit()
	assert_true(st.bond().held, "coger la pieza")
	p.refresh()
	# A/D giran la pieza en la mano, no la herramienta
	var a0 := st.angle_deg
	var t0 := st.bond().tilt_deg
	p.handle_key(_key(KEY_A))
	assert_eq(st.angle_deg, a0, "el ángulo de la herramienta no cambia")
	assert_true(st.bond().tilt_deg < t0, "la pieza gira")
	for i in 10:
		p.handle_key(_key(KEY_A))
	# K mantenida: aprieta y sujeta; al soltarla, la suelta (antes de que fije: suelta o torcida)
	p.handle_key(_key(KEY_K))
	assert_true(st.bond().holding and not st.bond().placed.is_empty(), "K: colocada y sujeta")
	p.handle_key(_key(KEY_K, false))
	assert_false(st.bond().holding, "al soltar K, la suelta")
	assert_true(st.bond().failure != "", "antes de que fije: %s" % st.bond().failure)
	(bs.quitar as BaseButton).pressed.emit()
	assert_eq(st.bond().failure, "", "quitada: a empezar de nuevo")
	p.refresh()
	assert_true(String(p.bond_card.stage_label.text).contains("Limpia"), "y la tarjeta dice el paso que toca: %s" % p.bond_card.stage_label.text)


func test_la_escena_coge_la_pieza_y_la_acopla() -> void:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	s.set_page(s.PAGE_CARE, false)
	var p: Control = s.care_page
	p.threaded = false
	await wait_frames(3)
	p.receive_forged(SHEATH)
	p.set_view("general")
	# el estado va en su hilo y la cámara llega a su vista con el tiempo: se espera a cada cosa (con margen de sobra para una
	# máquina cargada), no un número fijo de fotogramas
	await wait_until(func() -> bool: return p.scene != null and bool(p.scene.call("info").bond_piece) and String(p.scene.call("info").view) == "general", 900)
	var sc: Node3D = p.scene
	assert_true(bool(sc.call("info").bond_piece), "la pieza, en la bandeja de la colocación")
	var pt: Vector2 = await _settled(func() -> Vector2: return sc.call("bond_piece_screen_point"))
	var mm := InputEventMouseMotion.new()
	mm.position = pt
	sc.call("handle_pointer", mm)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pt
	sc.call("handle_pointer", mb)
	mb = mb.duplicate()
	mb.pressed = false
	sc.call("handle_pointer", mb)
	await wait_until(func() -> bool: return p.runner.state.bond().held, 900)
	assert_true(p.runner.state.bond().held, "un clic sobre la pieza la coge")
	p.set_view("garra")
	await wait_until(func() -> bool: return String(sc.call("info").view) == "garra", 900)
	var j := float(p.runner.state.view().bond.jointMm)
	mm = InputEventMouseMotion.new()
	mm.position = await _settled(func() -> Vector2: return sc.call("claw_screen_point", j, 0.0, 0.0))
	sc.call("handle_pointer", mm)
	await wait_until(func() -> bool: return bool(sc.call("info").bond_docked) and float(p.runner.state.bond().aim_mm) < 2.0, 900)
	assert_true(bool(sc.call("info").bond_docked), "al llevarla a la garra, se acopla al muñón")
	assert_true(float(p.runner.state.bond().aim_mm) < 2.0, "apuntando al muñón (%s mm)" % p.runner.state.bond().aim_mm)
	host.visible = false


## El punto de la pantalla que da f() cuando la cámara ya no se mueve: el mismo (± 0,5 px) cuatro fotogramas seguidos, o el
## último si no se para en max_frames.
func _settled(f: Callable, max_frames := 900) -> Vector2:
	var last: Vector2 = f.call()
	var still := 0
	for i in max_frames:
		await wait_frames(1)
		var now: Vector2 = f.call()
		still = still + 1 if now.distance_to(last) <= 0.5 else 0
		last = now
		if still >= 4:
			break
	return last


## El gesto del teléfono (punto 8): apretar sobre la pieza de la bandeja y arrastrarla sin soltar hasta el muñón; quieta ahí un
## momento, se coloca y queda sujeta mientras siga pulsado; al levantar el dedo (o el botón) después de que fije, sigue pegada.
## Con el ratón, igual (un toque de pantalla llega como el botón izquierdo).
func test_arrastrar_la_pieza_al_munon_y_mantener_pulsado() -> void:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	s.set_page(s.PAGE_CARE, false)
	var p: Control = s.care_page
	p.threaded = false
	await wait_frames(3)
	# las órdenes, al momento (sin el hilo del estado): el test mira el estado justo después de cada gesto
	p.runner.stop_thread()
	p.receive_forged(SHEATH)
	p.set_view("general")
	# la cámara, quieta en la vista general (la transición va con el tiempo de la escena)
	p.scene.call("set_view", "general", true)
	for i in 5:
		p.step(16.0)
	var st: State = p.runner.state
	p.runner.post("bond_adhesive", ["cianoacrilato"])
	p.runner.post("bond_apply")
	p.step(0.0)
	var sc: Node3D = p.scene
	var from: Vector2 = sc.call("bond_piece_screen_point")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = from
	var mm := InputEventMouseMotion.new()
	mm.position = from
	sc.call("handle_pointer", mm)
	sc.call("handle_pointer", mb)
	p.step(0.0)
	assert_true(st.bond().held and bool(sc.call("info").bond_dragging), "apretar sobre la pieza la coge y la arrastra")
	# la gira al eje antes de llegar (como con A/D), y la lleva al muñón sin soltar
	p.runner.post("bond_turn", [-float(CareData.BOND_ALIGN.start_tilt_deg)])
	var j := float(st.view().bond.jointMm)
	var to: Vector2 = sc.call("claw_screen_point", j, 0.0, 0.0)
	for i in range(1, 11):
		mm = InputEventMouseMotion.new()
		mm.position = from.lerp(to, float(i) / 10.0)
		mm.relative = (to - from) / 10.0
		sc.call("handle_pointer", mm)
		p.step(16.0)
	assert_true(st.bond().placed.is_empty(), "mientras se mueve, aún no se coloca")
	for i in 8:
		p.step(100.0)
	assert_true(bool(sc.call("info").bond_holding), "quieta sobre el muñón: se coloca y se sujeta")
	assert_true(not st.bond().placed.is_empty() and st.bond().holding, "colocada y sujeta con el dedo pulsado")
	assert_eq(st.bond().failure, "", "alineada y a tiempo: %s (%s)" % [st.bond().notice, st.bond().placed])
	# sujeta hasta que fija (el reloj ×10) y se levanta el dedo
	p.runner.post("set_time_scale", [10.0])
	for i in 30:
		p.step(100.0)
	assert_true(st.bond().attached(), "ha fijado mientras se mantenía pulsado")
	mb = mb.duplicate()
	mb.pressed = false
	sc.call("handle_pointer", mb)
	p.step(0.0)
	assert_false(st.bond().holding, "al levantar el dedo, se suelta")
	assert_true(st.bond().attached() and st.bond().failure == "", "y sigue pegada: ya había fijado")
	# la funda de acero, solo en su dedo: las demás garras y las del modelo siguen siendo de queratina
	assert_true(String(st.view().snap.inlay) == "acero", "la garra elegida, de acero")
	assert_true(String(sc.get("_look_key")).ends_with("|none"), "las demás, de queratina: %s" % sc.get("_look_key"))
	host.visible = false


func test_la_tarjeta_cabe_en_el_telefono() -> void:
	var host := Control.new()
	host.size = Vector2(390, 844)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	s.set_page(s.PAGE_CARE, false)
	var p: Control = s.care_page
	p.threaded = false
	for fs: Dictionary in [SHEATH, { "careSupported": true, "block": { "material": "acrilico", "stump_mm": 20.0, "wall_mm": 1.0, "fiction": false, "note": "", "source": "" } }]:
		p.receive_forged(fs)
		p.runner.post("bond_method", ["resina"])
		await wait_frames(4)
		assert_true(s.content.size.x <= 390.5, "nada más ancho que la pantalla (%s px)" % s.content.size.x)
		var r: Rect2 = (p.bond_card as Control).get_global_rect()
		assert_true(r.position.x >= -0.5 and r.end.x <= 390.5, "la tarjeta, dentro de la pantalla (%s)" % r)
	host.visible = false

