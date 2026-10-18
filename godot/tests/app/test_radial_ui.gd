## La radial en modo manual en la interfaz (app/taller/ui/radial_page.gd y app/taller/radial_3d.tscn): la pestaña no
## arranca nada al mostrarse, sin contacto no se corta, los números en pantalla son los del core
## (core/taller/radial_manual.gd), el ratón mueve la radial y la cámara por separado, nada crea nodos en cada fotograma
## y la escena carga sin ventana. Los tests síncronos van sin ventana (la sección se construye con build() y avanza con
## tick()); los que necesitan la escena 3D la meten en el árbol (el ejecutor corre sin ventana: renderizador vacío).
extends "res://tests/case.gd"

const SECTION := "res://app/taller/taller_section.tscn"
const RADIAL_SCENE := "res://app/taller/radial_3d.tscn"
const WorkshopState = preload("res://core/taller/workshop_state.gd")
const RadialPage = preload("res://app/taller/ui/radial_page.gd")
const RadialManual = preload("res://core/taller/radial_manual.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const FRAME := 1.0 / 30.0


func _section() -> Control:
	var s: Control = (load(SECTION) as PackedScene).instantiate()
	s.call("build")
	(s.get("tab_chips").radial as Button).pressed.emit()
	return s


func _ticks(s: Node, n: int) -> void:
	for k in n:
		s.call("tick", FRAME)


## Arrastre de un deslizador. Fuera del árbol, Godot cambia el valor sin emitir value_changed: se emite a mano.
func _drag(slider: HSlider, v: float) -> void:
	slider.value = v
	if not slider.is_inside_tree():
		slider.value_changed.emit(slider.value)


## Mantiene pulsado un botón de la tarjeta durante n fotogramas de la sección.
func _hold(s: Node, b: Button, n: int) -> void:
	b.button_down.emit()
	_ticks(s, n)
	b.button_up.emit()


## Enciende con el botón del gatillo, espera a que llegue a su giro y mete el disco hasta atravesar la chapa con el botón
## «Acercar» (deprisa lejos de la chapa y a 1 mm/s cerca).
func _start_and_plunge(s: Node, rp: Control) -> Dictionary:
	(rp.get("trigger_button") as Button).toggled.emit(true)
	_ticks(s, 45)
	var down: Button = rp.get("hold_buttons").acercar
	down.button_down.emit()
	var guard := 0
	while float(rp.get("frame")["depth_mm"]) < float(rp.get("frame")["total_mm"]) + 2.0 and guard < 600:
		s.call("tick", FRAME)
		guard += 1
	down.button_up.emit()
	_ticks(s, 3)
	return rp.get("frame")


static func _codes(f: Dictionary) -> Array:
	var out: Array = []
	for w in f["warnings"]:
		out.append(w["code"])
	return out


## Nada arranca solo: al abrir la pestaña la radial está apagada, parada y apartada, no suena y no corta; tampoco al
## volver a la pestaña después de haberla dejado en marcha.
func test_la_pestana_no_arranca_nada_al_mostrarse() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	_ticks(s, 60)
	var f: Dictionary = rp.get("frame")
	assert_eq(f["state"], "apagada", "apagada")
	assert_eq(float(f["rpm"]), 0.0, "parada")
	assert_true(float(f["depth_mm"]) < 0.0, "apartada de la chapa")
	assert_false(bool(rp.call("cutting_now")), "sin cortar")
	assert_false(bool(rp.get("demo")), "sin la demostración")
	var snd: Dictionary = rp.call("sound_input")
	assert_eq(float(snd["rpm"]), 0.0, "la entrada de sonido está parada")
	assert_eq(float(MachineSound.frame(snd)["tones"][0]["gain"]), 0.0, "y en silencio")
	assert_true((rp.get("reads").rpm as Label).text.begins_with("0"), "0 rpm en pantalla: %s" % (rp.get("reads").rpm as Label).text)
	assert_eq((rp.get("trigger_button") as Button).text, "Encender (Espacio)", "botón del gatillo para encender")
	# Se enciende, se cambia de máquina y se vuelve: otra vez apagada y apartada
	(rp.get("trigger_button") as Button).toggled.emit(true)
	_ticks(s, 30)
	assert_true(float(rp.get("frame")["rpm"]) > 1000.0, "encendida gira")
	s.call("select_machine", "torno")
	s.call("select_machine", "radial")
	f = rp.get("frame")
	assert_eq(f["state"], "apagada", "al volver a la pestaña, apagada")
	assert_eq(float(f["rpm"]), 0.0, "y parada")
	assert_true(float(f["depth_mm"]) < 0.0, "y apartada")
	s.free()


## El gatillo y las lecturas: lo que se ve bajo la vista son los números del core, con el formato de la interfaz.
func test_los_numeros_en_pantalla_son_los_del_core() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	var f := _start_and_plunge(s, rp)
	(rp.get("hold_buttons").adelante as Button).button_down.emit()
	_ticks(s, 60)
	f = rp.get("frame")
	var reads: Dictionary = rp.get("reads")
	assert_true(bool(f["cutting"]), "está cortando")
	assert_true((reads.rpm as Label).text.begins_with(Fmt.unit(f["rpm"], 0, "rpm")), "rpm: %s" % (reads.rpm as Label).text)
	assert_eq((reads.vs as Label).text, Fmt.unit(f["vs_ms"], 1, "m/s"), "velocidad periférica")
	assert_true((reads.feed as Label).text.begins_with(Fmt.unit(f["feed_mm_s"], 1, "mm/s")), "avance: %s" % (reads.feed as Label).text)
	assert_true((reads.depth as Label).text.begins_with(Fmt.unit(f["depth_mm"], 2, "mm")) and (reads.depth as Label).text.contains("atraviesa"), "profundidad: %s" % (reads.depth as Label).text)
	assert_eq((reads.tilt as Label).text, Fmt.unit(f["tilt_deg"], 0, "°"), "ángulo")
	assert_eq((reads.yaw as Label).text, Fmt.unit(f["yaw_deg"], 0, "°"), "giro")
	assert_true((reads.cut as Label).text.begins_with(Fmt.unit(f["cut_length_mm"], 1, "mm")), "longitud cortada: %s" % (reads.cut as Label).text)
	assert_true(float(f["cut_length_mm"]) > 0.0, "ha cortado")
	assert_true((reads.clean as Label).text.begins_with(Fmt.num(f["cleanliness"], 1) + "/10"), "calidad del corte: %s" % (reads.clean as Label).text)
	assert_true((rp.get("state_label") as Label).text.contains("en marcha"), "estado en marcha")
	assert_eq((rp.get("trigger_button") as Button).text, "Apagar (Espacio)", "botón del gatillo para apagar")
	var snd: Dictionary = rp.call("sound_input")
	assert_eq(float(snd["rpm"]), float(f["rpm"]), "sonido con las rpm reales")
	assert_eq(float(snd["pc_kw"]), float(f["power_kw"]), "y la potencia de corte del core")
	assert_true(float(snd["pc_kw"]) > 0.0, "cortando, con carga")
	assert_true(bool(rp.call("cutting_now")), "cutting_now() para la sección")
	(rp.get("hold_buttons").adelante as Button).button_up.emit()
	s.free()


## Sin contacto no se corta: encendida y apartada, con los botones «Adelante» y «Atrás», no raya la chapa.
func test_sin_contacto_no_se_corta() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	(rp.get("trigger_button") as Button).toggled.emit(true)
	_ticks(s, 30)
	_hold(s, rp.get("hold_buttons").adelante, 90)
	_hold(s, rp.get("hold_buttons").atras, 45)
	var f: Dictionary = rp.get("frame")
	assert_true(float(f["rpm"]) > 1000.0, "en marcha")
	assert_eq(float(f["cut_length_mm"]), 0.0, "sin cortar")
	assert_eq(float(f["groove_length_mm"]), 0.0, "ni rayar")
	assert_eq((rp.get("reads").cut as Label).text, Fmt.unit(0.0, 1, "mm"), "0 mm cortados en pantalla")
	s.free()


## Se cambia de disco (incluidos el de metal duro y el de CBN), de chapa y de diámetro sin reiniciar la escena; otra
## chapa, o «Reiniciar chapa», empieza sin cortar. Cambiar de disco para la radial y la saca (como en la realidad).
func test_cambios_de_disco_chapa_y_diametro() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	var ws = s.get("state")
	_start_and_plunge(s, rp)
	_hold(s, rp.get("hold_buttons").adelante, 45)
	var cut := float(rp.get("frame")["cut_length_mm"])
	assert_true(cut > 0.0, "hay corte")
	var discs: Dictionary = rp.get("disc_chips")
	assert_eq(discs.keys(), RadialManual.DISCS, "los seis discos, con el de metal duro y el de CBN")
	(discs["metal_duro"] as Button).pressed.emit()
	var m: RadialManual = rp.get("manual")
	assert_eq(ws.radial.disc_id, "metal_duro", "disco de metal duro en el estado")
	assert_eq(m.disc_id, "metal_duro", "y en la radial")
	assert_eq(rp.get("frame")["state"], "apagada", "para cambiar el disco la radial se para")
	assert_true(float(rp.get("frame")["cut_length_mm"]) >= cut, "el corte se queda")
	(discs["cbn_1mm"] as Button).pressed.emit()
	_ticks(s, 2)
	var codes := _codes(rp.get("frame"))
	assert_true(codes.has("disco_fijo"), "CBN: disco para tronzadora fija (%s)" % [codes])
	assert_true(codes.has("exceso_velocidad"), "y la rueda pide más de lo marcado")
	var live: Array = rp.get("live_warns")
	assert_true(live[0].visible and live[0].text != "", "avisos en directo en pantalla")
	assert_true((rp.get("live_srcs")[0] as Label).text.begins_with("Fuente:"), "con su fuente")
	var panels: Dictionary = rp.get("panel_chips")
	assert_true(panels.has("perfil-aluminio"), "las tres piezas de rescate")
	(panels["perfil-aluminio"] as Button).pressed.emit()
	_ticks(s, 2)
	assert_eq(float(rp.get("frame")["cut_length_mm"]), 0.0, "otra chapa: sin cortar")
	assert_eq(m.panel_id, "perfil-aluminio", "chapa nueva en la radial")
	(discs["diamante"] as Button).pressed.emit()
	var diam: Dictionary = rp.get("diam_chips")
	(diam[230.0] as Button).pressed.emit()
	assert_eq(m.diameter_mm, 230.0, "diámetro de 230 mm")
	assert_eq(rp.get("frame")["machine"], "Bosch GWS 22-230 P", "con la radial grande")
	_start_and_plunge(s, rp)
	assert_true(float(rp.get("frame")["cut_length_mm"]) > 0.0 or float(rp.get("frame")["groove_length_mm"]) > 0.0, "corta con el disco grande")
	(rp.get("reset_button") as Button).pressed.emit()
	_ticks(s, 2)
	assert_eq(float(rp.get("frame")["cut_length_mm"]), 0.0, "chapa reiniciada")
	assert_true(float(rp.get("frame")["depth_mm"]) < 0.0, "y la radial apartada")
	s.free()


## Cambiar de disco no cambia las rpm elegidas en la rueda (el deslizador cambia de recorrido sin mandar su valor
## recortado al estado); la radial solo se queda en el tope real del disco.
func test_cambiar_de_disco_no_cambia_las_rpm_elegidas() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	var ws = s.get("state")
	var rpm: HSlider = rp.get("rpm_slider").slider
	_drag(rpm, 16000.0)
	assert_eq(float(ws.radial.rpm), 16000.0, "16.000 rpm pedidas")
	(rp.get("disc_chips")["cbn_1mm"] as Button).pressed.emit()
	assert_true(rpm.max_value < 16000.0, "con el CBN el deslizador llega menos lejos (%s)" % rpm.max_value)
	assert_eq(float(ws.radial.rpm), 16000.0, "las rpm elegidas no cambian al cambiar de disco")
	var m: RadialManual = rp.get("manual")
	assert_true(m.set_rpm() <= m.disc_limit_rpm() + 1e-9, "la radial se queda en el tope del disco")
	(rp.get("disc_chips")["grueso_3mm"] as Button).pressed.emit()
	assert_eq(float(ws.radial.rpm), 16000.0, "ni al volver a otro disco del mismo diámetro")
	assert_eq(rpm.value, 16000.0, "y el deslizador las vuelve a enseñar")
	s.free()


## «Ver demostración» pone el corte automático (sin la mano) y el mismo botón vuelve al mando manual, apagada.
func test_ver_demostracion() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	var b: Button = rp.get("demo_button")
	assert_eq(b.text, "Ver demostración", "botón de la demostración")
	b.toggled.emit(true)
	assert_true(bool(rp.get("demo")), "demostración en marcha")
	assert_eq(b.text, "Volver al mando manual", "y el botón para volver")
	_ticks(s, 10)
	b.toggled.emit(false)
	assert_false(bool(rp.get("demo")), "de vuelta al mando manual")
	assert_eq(rp.get("frame")["state"], "apagada", "apagada")
	b.toggled.emit(true)
	(rp.get("trigger_button") as Button).toggled.emit(true)
	assert_false(bool(rp.get("demo")), "pulsar el gatillo deja la demostración")
	assert_true(bool(rp.get("manual").trigger), "y enciende la radial")
	s.free()


## En teléfono (una columna), los botones de la tarjeta son más grandes y la ayuda es la del tacto.
func test_modo_telefono() -> void:
	var s := _section()
	var rp: Control = s.get("pages").radial
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	s.size = Vector2(390, 844)
	s.call("_update_layout")
	assert_true(bool(rp.get("compact")), "una columna")
	assert_true((rp.get("hold_buttons").acercar as Button).custom_minimum_size.y >= 48.0, "botones grandes")
	assert_true((rp.get("help_label") as Label).text.contains("dedo"), "ayuda para el tacto")
	for k in ["atras", "adelante", "acercar", "apartar"]:
		var btn: Button = rp.get("hold_buttons")[k]
		assert_true(btn.accessibility_name != "" and btn.tooltip_text != "", "%s con etiqueta de accesibilidad" % k)
	assert_true((rp.get("trigger_button") as Button).accessibility_name != "", "gatillo con etiqueta de accesibilidad")
	assert_true((rp.get("rpm_slider").slider as HSlider).accessibility_name != "", "rueda de velocidad con etiqueta")
	s.free()


# ───────────────────────────── con la escena 3D en el árbol ─────────────────────────────

## La escena carga sin ventana en los dos modos y expone su API; la demo del modo manual también se instancia.
func test_la_escena_carga_sin_ventana() -> void:
	var scene: Node3D = (load(RADIAL_SCENE) as PackedScene).instantiate()
	for mth in ["set_mode", "show_frame", "stats", "reset_camera", "input_geometry", "start_cut", "set_view"]:
		assert_true(scene.has_method(mth), "API: %s" % mth)
	assert_false(bool(scene.get("auto_start")), "sin arranque automático por defecto")
	var m := RadialManual.new()
	scene.set("mode", "manual")
	scene.set("manual", m)
	add_to_tree(scene)
	await wait_frames(2)
	m.set_trigger(true)
	for i in 30:
		scene.call("show_frame", m.step(FRAME))
		await wait_frames(1)
	var st: Dictionary = scene.call("stats")
	assert_eq(st["mode"], "manual", "en el modo manual")
	assert_true(int(st["manual_mesh_builds"]) >= 2, "con las mallas del surco hechas")
	scene.call("set_mode", "auto")
	scene.call("start_cut", 40.0, 0.1)
	await wait_frames(3)
	assert_eq(scene.call("stats")["mode"], "auto", "y en el automático")
	scene.call("set_mode", "manual")
	await wait_frames(2)
	var demo := (load("res://app/taller/demo_radial_manual.tscn") as PackedScene)
	assert_true(demo != null and demo.can_instantiate(), "la demo del modo manual carga")
	var inst := demo.instantiate()
	inst.free()


## Nada crea nodos (ni rehace mallas) en cada fotograma: con la radial cortando a lo largo, el número de nodos no crece y
## solo se sube la textura del mapa del surco.
func test_nada_crea_nodos_en_cada_fotograma() -> void:
	var ws := WorkshopState.new()
	var rp: Control = RadialPage.new()
	rp.call("build", ws)
	add_to_tree(rp)
	rp.call("on_shown")
	await wait_frames(3)
	var scene: Node3D = rp.get("radial3d")
	assert_true(scene != null, "la página crea su escena 3D en el árbol")
	if scene == null:
		return
	var m: RadialManual = rp.get("manual")
	(rp.get("trigger_button") as Button).toggled.emit(true)
	for i in 45:
		rp.call("tick", FRAME)
		await wait_frames(1)
	var down: Button = rp.get("hold_buttons").acercar
	down.button_down.emit()
	var guard := 0
	while m.depth_mm < float(m.frame["total_mm"]) + 2.0 and guard < 600:
		rp.call("tick", FRAME)
		await wait_frames(1)
		guard += 1
	down.button_up.emit()
	(rp.get("hold_buttons").adelante as Button).button_down.emit()
	for i in 20:
		rp.call("tick", FRAME)
		await wait_frames(1)
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var st0: Dictionary = scene.call("stats")
	for i in 90:
		rp.call("tick", FRAME)
		await wait_frames(1)
	var st1: Dictionary = scene.call("stats")
	var fr: Dictionary = rp.get("frame")
	assert_true(bool(fr["cutting"]), "cortando todo el rato")
	# El avance pedido por defecto (20 mm/s) pasa de lo que corta el disco: los botones no fuerzan la radial
	assert_false(bool(fr["tripped"]), "los botones no fuerzan la radial: no se desconecta")
	assert_true(float(fr["rpm"]) > 0.98 * float(fr["rpm_set"]), "ni pierde vueltas (%s rpm)" % fr["rpm"])
	assert_true(float(fr["feed_mm_s"]) <= float(fr["feed_cap_mm_s"]) + 0.5, "va a lo que corta el disco (%s mm/s)" % fr["feed_mm_s"])
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes0, "los mismos nodos tras 90 fotogramas cortando")
	for k in ["grinder_builds", "legacy_mesh_builds", "manual_mesh_builds"]:
		assert_eq(st1[k], st0[k], "sin rehacer mallas (%s)" % k)
	assert_true(int(st1["map_uploads"]) > int(st0["map_uploads"]), "solo se sube la textura del surco")
	(rp.get("hold_buttons").adelante as Button).button_up.emit()


## El ratón sobre la vista: el botón izquierdo lleva la radial a lo largo del corte (en mm, con la escala de la vista),
## la rueda la acerca o la aparta, Mayús + arrastre la inclina, y el botón derecho gira la cámara sin tocar la radial.
func test_el_raton_mueve_la_radial_y_la_camara() -> void:
	var scene: Node3D = (load(RADIAL_SCENE) as PackedScene).instantiate()
	var m := RadialManual.new()
	scene.set("mode", "manual")
	scene.set("manual", m)
	add_to_tree(scene)
	await wait_frames(2)
	scene.call("show_frame", m.step(FRAME))
	await wait_frames(1)
	var vp := scene.get_viewport()
	var geo: Dictionary = scene.call("input_geometry")
	var u0 := m.hand_u
	vp.push_input(_button(MOUSE_BUTTON_LEFT, true), true)
	vp.push_input(_motion((geo["px_u"] as Vector2) * 10.0, false), true)
	vp.push_input(_button(MOUSE_BUTTON_LEFT, false), true)
	assert_near(m.hand_u - u0, 10.0, 1e-3, 1e-3, "arrastre ← →: 10 mm a lo largo de la línea (%s)" % (m.hand_u - u0))
	var d0 := m.hand_depth
	vp.push_input(_button(MOUSE_BUTTON_WHEEL_DOWN, true), true)
	assert_true(m.hand_depth > d0, "la rueda hacia abajo acerca la radial a la chapa")
	var d1 := m.hand_depth
	vp.push_input(_button(MOUSE_BUTTON_WHEEL_UP, true), true)
	assert_true(m.hand_depth < d1, "y hacia arriba la aparta")
	vp.push_input(_button(MOUSE_BUTTON_LEFT, true), true)
	vp.push_input(_motion(Vector2(0.0, 50.0), true), true)
	vp.push_input(_button(MOUSE_BUTTON_LEFT, false), true)
	assert_near(m.tilt_deg, 7.5, 1e-9, 1e-9, "Mayús + arrastre ↓ 50 px: inclina 7,5°")
	var u1 := m.hand_u
	var yaw0 := float(scene.get("_orbit_yaw"))
	vp.push_input(_button(MOUSE_BUTTON_RIGHT, true), true)
	vp.push_input(_motion(Vector2(40.0, 0.0), false), true)
	vp.push_input(_button(MOUSE_BUTTON_RIGHT, false), true)
	assert_eq(m.hand_u, u1, "el botón derecho no mueve la radial")
	assert_true(float(scene.get("_orbit_yaw")) != yaw0, "gira la cámara")


func _button(b: MouseButton, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = b
	ev.pressed = pressed
	return ev


func _motion(rel: Vector2, shift: bool) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.shift_pressed = shift
	return ev
