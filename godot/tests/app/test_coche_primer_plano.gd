## El primer plano de las garras del coche en marcha (unidad 4s, petición de Eric del 13-10: app/lab/car3d/claw_closeup.gd,
## claw_swatch.gd y lo suyo en moving_car_view.gd, moving_car_card.gd y moving_car_state.gd). Se comprueba:
##   - que con un animal quieto encima sale la ventana de las garras dentro de la vista, apuntando a las puntas que tocan
##     la chapa, con la cámara fuera de la carrocería; y que «Garras de cerca» la pone en la vista entera (sin el render del
##     coche) y la vista se hace más alta;
##   - que el render va a los píxeles de verdad de la pantalla, con su tope;
##   - que en cada fotograma no se crea nada con el primer plano en marcha;
##   - que las garras de la biblioteca van también en su capa (el golpe las ve sin el cuerpo) y que la lupa del daño no las ve;
##   - que ninguna punta de garra queda dentro del techo y que la cola de una rapaz posada queda sobre la chapa;
##   - el texto del primer plano (material y punta del motor, y la punta afilada más fina) y las muestras del selector.
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const Card = preload("res://app/lab/moving_car_card.gd")
const View = preload("res://app/lab/moving_car_view.gd")
const ClawCloseup = preload("res://app/lab/car3d/claw_closeup.gd")
const ClawSwatch = preload("res://app/lab/car3d/claw_swatch.gd")
const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Js = preload("res://core/shared/js.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


func _card(claw_id: String, width := 900.0) -> Control:
	var host := Control.new()
	host.size = Vector2(width + 20.0, 1400)
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


func _run(card: Control, n := 6) -> void:
	for i in n:
		card.step(16.0)
		await wait_frames(1)


func test_la_ventana_de_las_garras_apunta_a_las_puntas_que_tocan() -> void:
	var card := _card("tigre")
	card.speed.slider.value_changed.emit(90.0)
	card.finish()
	await _run(card)
	var view: View = card.view
	var cu: ClawCloseup = view.get("_closeup")
	assert_true(cu != null and cu.visible, "con el tigre quieto encima, la ventana de las garras se ve")
	assert_false(cu.full, "en la vista del coche, como ventana")
	var r := Rect2(cu.position, cu.size)
	assert_true(Rect2(Vector2.ZERO, view.size).encloses(r), "dentro de la vista (%s en %s)" % [r, view.size])
	assert_true(r.size.y >= View.CLOSEUP_MIN_H - 0.5 and r.size.y <= View.CLOSEUP_MAX_H + 0.5, "de su tamaño (%s px)" % Js.to_fixed(r.size.y, 0))
	# apunta a las garras que tocan: el foco, a menos del largo de una garra de la punta más cercana
	var tips: Array = view.tips_by_gap("techo")
	var at: Vector3 = cu.get("_goal_at")
	var near := INF
	for e: Array in tips:
		near = minf(near, (e[1] as Vector3).distance_to(at))
	var reach := float(C("tigre").reach) / 1000.0
	assert_true(near < reach * 1.2, "el foco, junto a las puntas (%s m; la garra mide %s m)" % [Js.to_fixed(near, 3), Js.to_fixed(reach, 3)])
	var cam: Camera3D = cu.cam
	assert_true(cam.position.y > view.surface_y(cam.position.x), "la cámara, fuera de la chapa")
	assert_true(cam.position.distance_to(at) < 0.5, "de cerca (%s m)" % Js.to_fixed(cam.position.distance_to(at), 2))
	assert_eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "en perspectiva")
	assert_true(cam.cull_mask & CarScene.ANIMAL_LAYER != 0, "quieto encima ve el animal entero (la garra con su dedo)")
	assert_eq(cam.cull_mask & CarScene.AirFlow.WIND_LAYER, 0, "y no el viento")
	assert_true(String(cu.lines[0]).begins_with("Garras de queratina · punta R "), "el texto: el material y la punta (%s)" % cu.lines[0])


func test_garras_de_cerca_en_la_vista_entera() -> void:
	var card := _card("oso")
	card.speed.slider.value_changed.emit(120.0)
	card.finish()
	await _run(card)
	var view: View = card.view
	var h0: float = view.custom_minimum_size.y
	(card.zoom_seg.buttons["garras"] as Button).pressed.emit()
	await _run(card)
	var cu: ClawCloseup = view.get("_closeup")
	assert_true(view.closeup_full_on(), "«Garras de cerca»: el primer plano en la vista entera")
	assert_true(cu.full and cu.size.is_equal_approx(view.size), "del tamaño de la vista")
	assert_true(view.custom_minimum_size.y > h0, "y la vista, más alta (%s > %s px)" % [Js.to_fixed(view.custom_minimum_size.y, 0), Js.to_fixed(h0, 0)])
	var vp: SubViewport = view.get("_vp")
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "el render del coche entero no hace falta")
	(card.zoom_seg.buttons["coche"] as Button).pressed.emit()
	await _run(card)
	assert_false(view.closeup_full_on(), "y vuelve al coche entero")
	assert_false(cu.full, "con la ventana")


func test_el_render_a_los_pixeles_de_verdad() -> void:
	assert_eq(ClawCloseup.render_size(Vector2(390, 180), 3.0), Vector2i(1170, 540), "un teléfono ×3: los píxeles de verdad")
	assert_eq(ClawCloseup.render_size(Vector2(400, 200), 1.0), Vector2i(400, 200), "×1, el tamaño en la interfaz")
	var big := ClawCloseup.render_size(Vector2(1200, 800), 3.0)
	assert_true(float(big.x * big.y) <= ClawCloseup.MAX_PX + 4000.0, "con su tope de píxeles (%s)" % big)
	assert_near(float(big.x) / float(big.y), 1.5, 0.01, 0.0, "sin deformar")


func test_en_cada_fotograma_no_se_crea_nada_con_el_primer_plano() -> void:
	var card := _card("tigre")
	card.speed.slider.value_changed.emit(120.0)
	(card.zoom_seg.buttons["garras"] as Button).pressed.emit()
	card.finish()
	await _run(card, 6)
	var view: View = card.view
	var nodes := view.find_children("*", "", true, false).size()
	var scene: Node3D = view.get("_scene")
	var scene_nodes := scene.find_children("*", "", true, false).size()
	var builds: int = view.builds
	for i in 20:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.find_children("*", "", true, false).size(), nodes, "sin nodos nuevos en la vista")
	assert_eq(scene.find_children("*", "", true, false).size(), scene_nodes, "ni en el mundo 3D")
	assert_eq(view.builds, builds, "sin geometría nueva")


func test_las_garras_en_su_capa_y_la_lupa_sin_ellas() -> void:
	var card := _card("tigre")
	card.inlay_pills["acero"].pressed.emit()
	card.speed.slider.value_changed.emit(90.0)
	card.finish()
	await _run(card)
	var view: View = card.view
	var rig: RefCounted = view.get("_rig")
	var marked := 0
	for mi: MeshInstance3D in rig.get("_claw_slots"):
		if mi.layers & CarScene.CLAW_LAYER != 0:
			marked += 1
	assert_eq(marked, (rig.get("_claw_slots") as Array).size(), "cada malla de garra, también en la capa de las garras")
	var lupa_cam: Camera3D = view.get("_lupa_cam")
	if lupa_cam != null:
		assert_eq(lupa_cam.cull_mask & CarScene.CLAW_LAYER, 0, "la lupa del daño no ve las garras")


func test_las_puntas_y_la_cola_sobre_el_techo() -> void:
	for id: String in ["tigre", "aguila", "buho"]:
		var card := _card(id)
		card.speed.slider.value_changed.emit(90.0)
		card.finish()
		await _run(card)
		var view: View = card.view
		var rig: RefCounted = view.get("_rig")
		var root: Node3D = rig.get("root")
		var deepest := 0.0
		for q: Vector3 in rig.call("claw_points"):
			var w := root.transform * q
			deepest = maxf(deepest, view.surface_y(w.x) - w.y)
		assert_true(deepest < 0.002, "%s: ninguna punta dentro del techo (%s m)" % [id, Js.to_fixed(deepest, 3)])
		if id != "tigre":
			var lean := View.tail_lean(rig.get("fit_box"))
			assert_true(lean > 0.0, "%s: se echa hacia delante para sacar la cola de la chapa (%s rad)" % [id, Js.to_fixed(lean, 2)])
	assert_eq(View.tail_lean(Rect2(-0.5, 0.02, 1.0, 1.0)), 0.0, "sin cola por debajo de los pies, no se inclina")


func test_el_texto_del_primer_plano_y_la_punta_afilada() -> void:
	var st := MCS.new(C("tigre"), Catalog.find_by_id(Catalog.TARGETS, "coche"))
	st.threaded = false
	st.finish()
	var r0 := st.claw_tip_um()
	assert_near(r0, sqrt(float(C("tigre").area) / PI) * 1000.0, 1e-9, 1e-9, "la punta de la ficha: √(área/π)")
	st.set_inlay("acero")
	st.finish()
	assert_near(st.claw_tip_um(), r0, 1e-9, 1e-9, "una garra reforjada conserva su forma: la misma punta")
	st.set_sharpness(0.6)
	st.finish()
	assert_true(st.claw_tip_um() < r0, "afilada, la punta es más fina (%s < %s µm)" % [Js.to_fixed(st.claw_tip_um(), 1), Js.to_fixed(r0, 1)])
	var cap: Array = st.closeup_caption()
	assert_true(String(cap[0]).begins_with("Garras de acero · punta R ") and String(cap[0]).ends_with("(afiladas)"), "el texto lo dice (%s)" % cap[0])
	assert_eq(MCS.new().closeup_caption(), ["", ""], "sin animal, nada")


func test_las_muestras_del_selector() -> void:
	var seen := {}
	for i: Dictionary in Catalog.INLAYS:
		var tex := ClawSwatch.texture(String(i.id))
		assert_true(tex != null and tex.get_width() == ClawSwatch.SIZE, "%s: su muestra" % i.id)
		# el color medio de lo que se ve de la garra
		var img := tex.get_image()
		var sum := Color(0, 0, 0, 0)
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.9:
					sum += c
					n += 1
		assert_true(n > 40, "%s: la garra se ve (%d px)" % [i.id, n])
		seen[i.id] = sum / float(maxi(n, 1))
	assert_true((seen.oro as Color).r > (seen.oro as Color).b + 0.15, "el oro, dorado")
	assert_true(absf((seen.acero as Color).r - (seen.acero as Color).b) < 0.12, "el acero, gris")
	assert_true(not (seen.oro as Color).is_equal_approx(seen.acero as Color), "cada material, su color")
	var first := ClawSwatch.texture("oro")
	assert_true(ClawSwatch.texture("oro") == first, "una vez por material (caché)")
	var card := _card("tigre")
	assert_true((card.inlay_pills["zafiro"] as Button).icon != null, "las píldoras del selector llevan su muestra")


func test_la_linea_de_abajo_cabe_en_el_telefono() -> void:
	var font := ThemeDB.fallback_font
	var s := "a 200 km/h: raja la chapa de lado a lado (0.81 mm con la pintura)"
	var wide := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 4.0
	assert_eq(Array(ClawCloseup.wrap_words(font, s, wide, 10)), [s], "si cabe, en una línea")
	var narrow := wide * 0.55
	var got := ClawCloseup.wrap_words(font, s, narrow, 10)
	assert_eq(got.size(), 2, "en el teléfono, dos líneas: %s" % [got])
	assert_eq(" ".join(got), s, "sin perder nada (la hondura con la pintura incluida)")
	for t: String in got:
		assert_true(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= narrow, "cada línea cabe: %s" % t)


func test_los_rotulos_de_la_grafica_del_dano_no_se_pisan() -> void:
	var chart := load("res://app/lab/moving_car_marks_chart.gd")
	var rows: Array = [-1e9, -1e9, -1e9, -1e9]
	rows[0] = 150.0  # «ya parado: llega a la chapa», arriba a la izquierda
	var r := int(chart.label_row(rows, 3.0))
	assert_eq(r, 1, "el hito del barniz, en el mismo sitio, baja a la fila de debajo")
	rows[1] = 90.0
	assert_eq(int(chart.label_row(rows, 95.0)), 1, "uno que empieza después de que acabe el de la fila 1 vuelve a ella")
	assert_eq(int(chart.label_row([200.0, 210.0, 220.0, 230.0], 10.0)), 0, "todas llenas: la que acaba antes")
