## El coche en curva en la tarjeta y en la vista (unidad 4t): el selector de la carretera, el deslizador del radio con los
## valores de la norma y la frase de la curva (todo del estado); el medidor de fuerza G, el plano y la carretera en curva de
## la vista, que vuelven a la carretera de siempre en recta; en la S el medidor cambia de lado sin crear nada en cada
## fotograma; y que lo nuevo de la interfaz no calcula física.
extends "res://tests/case.gd"

const Card = preload("res://app/lab/moving_car_card.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")

const NEW_UI := ["res://app/lab/car3d/g_meter.gd", "res://app/lab/car3d/road_map.gd", "res://app/lab/car3d/road_curve.gd"]


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


## Una tarjeta con su banco, en el árbol, con un animal y lo caro sin hilos.
func _card(claw_id: String, width := 680.0) -> Control:
	var host := Control.new()
	host.size = Vector2(width + 20.0, 1600)
	add_to_tree(host)
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = false
	lab.set_claw(C(claw_id))
	card.refresh()
	card.finish()
	card.size = Vector2(width, 0)
	host.add_child(card)
	return card


func test_controles_de_la_carretera() -> void:
	var card := _card("tigre")
	await wait_frames(2)
	assert_true(card.road_box.visible, "con el animal encima, el selector de la carretera")
	assert_false(card.radius.visible, "en recta, sin radio")
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.finish()
	assert_eq(card.st.road, CarCurve.ROAD_CURVE, "la curva elegida")
	assert_true(card.radius.visible and card.preset_flow.visible and card.curve_label.visible, "radio, valores de la norma y frase")
	assert_eq(card.radius.display.text, card.st.radius_text(), "el radio, del estado")
	assert_eq(card.curve_label.text, Card.nb(card.st.curve_text()), "la frase de la curva, del estado")
	assert_eq(card.radius_marks.marks.size(), CarCurve.PRESETS.size(), "los valores de la norma marcados bajo la pista")
	card.preset_pills["v40"].pressed.emit()
	assert_eq(card.st.radius_m, 50.0, "la píldora de 40 km/h pone 50 m")
	assert_true(card.preset_pills["v40"].button_pressed, "y queda marcada")
	card.radius.slider.value = CarCurve.slider_u(450.0)
	assert_eq(card.st.radius_m, 450.0, "el deslizador del radio, en escala logarítmica")
	card.radius.slider.value = CarCurve.slider_u(333.0)
	assert_eq(fmod(card.st.radius_m, 10.0), 0.0, "un radio redondo: %s" % card.st.radius_m)
	card.speed.slider.value = 120.0
	card.step(16.0)
	assert_true(card.curve_label.text.contains("120"), "la frase sigue a la velocidad: %s" % card.curve_label.text)
	# en el golpe, la curva también (el camino del animal se tuerce), pero no la S, que es del animal quieto encima
	card.mode_seg.buttons[MCS.MODE_IMPACT].pressed.emit()
	card.step(16.0)
	assert_true(card.road_box.visible, "en el golpe, la carretera en curva")
	assert_true(card.road_seg.buttons[CarCurve.ROAD_S].disabled, "sin la S en el golpe")
	assert_eq(card.curve_label.text, Card.nb(card.st.impact_curve_text()), "la frase del golpe en curva, del estado")


func test_la_vista_en_curva_y_en_recta() -> void:
	var card := _card("tigre")
	card.speed.slider.value = 90.0
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	var view: Control = card.view
	var scene: Node3D = view.get("_scene")
	assert_true(view.curve_on, "la vista en curva")
	assert_true(view.meter_ctl.visible and view.map_ctl.visible, "medidor y plano")
	assert_eq(view.meter_ctl.data, card.st.meter(), "el medidor, del estado")
	assert_true(float(view.meter_ctl.data.latG) > 0.0, "la curva a la izquierda empuja a la derecha")
	assert_true(view.map_ctl.pts.size() > 10, "el plano con su recorrido")
	if scene != null:
		# por defecto, la vista de persecución: la carretera larga, la cámara detrás del coche y las ruedas giradas
		assert_true(scene.curved and scene.chasing, "en curva, la vista de persecución")
		assert_true(scene.road_chase != null and scene.road_chase.visible, "la carretera larga en curva")
		assert_true(scene.chase_cam.current and not scene.camera.current, "la cámara de persecución")
		assert_true(scene.road_curve == null or not scene.road_curve.visible, "sin la carretera corta")
		assert_true(scene.car.far_wheels and scene.car.wheels.size() == 4, "las cuatro ruedas")
		assert_true(float(scene.car.steer) > 0.0, "las delanteras giradas hacia la izquierda: %s" % scene.car.steer)
		assert_true(absf(float(scene.car.root.rotation.x)) > 0.0, "la carrocería se balancea")
		var heads: PackedFloat32Array = scene.road_chase.heads
		assert_true(float(heads[heads.size() - 1]) > 1.0, "la carretera gira por delante: %s rad" % heads[heads.size() - 1])
		# la vista de lado, para las garras
		card.view_seg.buttons["lado"].pressed.emit()
		for i in 2:
			card.step(16.0)
			await wait_frames(1)
		assert_true(not scene.chasing and scene.camera.current, "de lado, la cámara de siempre")
		assert_true(scene.road_curve != null and scene.road_curve.visible and not scene.road_chase.visible, "la carretera corta en curva")
		card.view_seg.buttons["persecucion"].pressed.emit()
	card.road_seg.buttons[CarCurve.ROAD_STRAIGHT].pressed.emit()
	card.finish()
	card.step(16.0)
	await wait_frames(1)
	assert_false(view.curve_on or view.meter_ctl.visible or view.map_ctl.visible, "en recta, ni medidor ni plano")
	if scene != null:
		assert_false(scene.curved, "la carretera de siempre")
		assert_false(scene.road_curve.visible or scene.road_chase.visible, "la curva escondida")
		assert_true(scene.camera.current and not scene.chasing, "la cámara de siempre")
		assert_eq(float(scene.car.root.rotation.x), 0.0, "sin balanceo")
		assert_eq(float(scene.car.steer), 0.0, "las ruedas rectas")


func test_en_la_s_el_medidor_cambia_de_lado_sin_crear_nada() -> void:
	var card := _card("tigre")
	card.speed.slider.value = 95.0
	card.road_seg.buttons[CarCurve.ROAD_S].pressed.emit()
	card.preset_pills["v60"].pressed.emit()
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	var view: Control = card.view
	var scene: Node3D = view.get("_scene")
	var nodes := scene.find_children("*", "", true, false).size() if scene != null else 0
	var builds: int = view.builds
	var right := false
	var left := false
	var flashed := 0
	var flash_sides := {}
	# la S se enseña en RoadCurve.S_LOOP_S segundos: una vuelta entera en pasos de 100 ms
	for i in 90:
		card.step(100.0)
		if i % 6 == 0:
			await wait_frames(1)
		var lat := float(view.meter_ctl.data.get("latG", 0.0))
		right = right or lat > 0.1
		left = left or lat < -0.1
		if view.flash > 0.0:
			flashed += 1
			flash_sides[view.flash_side] = true
	assert_true(right and left, "en la S el medidor pasa por la derecha y por la izquierda")
	assert_true(flashed > 0 and flashed < 30, "el cambio de lado destella, y solo un rato (%d pasos)" % flashed)
	assert_true(flash_sides.has(-1.0), "al pasar a la izquierda")
	if scene != null:
		assert_eq(scene.find_children("*", "", true, false).size(), nodes, "sin nodos nuevos")
	assert_eq(view.builds, builds, "sin geometría nueva")


func test_lo_nuevo_de_la_interfaz_no_calcula_fisica() -> void:
	for f: String in NEW_UI:
		var code := code_only(FileAccess.get_file_as_string(f))
		for bad: String in ["MovingCar.", "CarCurve.at_", "CarCurve.detach", "Physics.", "9.807", "3.6"]:
			assert_false(code.contains(bad), "%s no puede usar %s" % [f.get_file(), bad])
		assert_eq(RegEx.create_from_string("(?<![\\w.])(str|round)\\(").search_all(code).size(), 0, "%s: sin str() ni round()" % f.get_file())
	# la vista y la tarjeta piden a CarCurve solo geometría y formatos; la física de la curva, al estado
	for f: String in ["res://app/lab/moving_car_view.gd", "res://app/lab/moving_car_card.gd"]:
		var code := code_only(FileAccess.get_file_as_string(f))
		for bad: String in ["CarCurve.at_speed", "CarCurve.at_lateral", "CarCurve.detach", "CarCurve.lateral_ms2", "CarCurve.felt_ms2"]:
			assert_false(code.contains(bad), "%s no puede usar %s" % [f.get_file(), bad])


## En un teléfono, en curva, la vista 3D crece (el coche que gira y la curva llenan la imagen) y vuelve en recta.
func test_en_el_telefono_la_vista_crece_en_curva() -> void:
	var card := _card("tigre", 360.0)
	card.speed.slider.value = 90.0
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	var view: Control = card.view
	var base: float = view.custom_minimum_size.y
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	var want: float = view.get_viewport_rect().size.y * view.CURVE_PHONE_H
	assert_true(view.custom_minimum_size.y >= minf(want, 9999.0) - 1.0 and view.custom_minimum_size.y > base,
		"en curva, más alta: %s px (antes %s)" % [view.custom_minimum_size.y, base])
	assert_true(view.meter_ctl.size.x < 0.5 * view.size.x, "el medidor no se come la vista")
	card.road_seg.buttons[CarCurve.ROAD_STRAIGHT].pressed.emit()
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.custom_minimum_size.y, base, "en recta, la de siempre")
