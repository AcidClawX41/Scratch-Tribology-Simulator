## El animal que se agarra, se recoloca y se cae en la vista del coche en curva (unidad 4u): en la curva al límite las garras
## de fuera dejan sus surcos (las medidas, del estado) torcidos hacia fuera; en la S aparecen al pasar cada momento, sin crear
## nada en cada fotograma; en la curva cerrada demasiado rápida resbala hacia fuera, se cae por el lado de fuera y se queda
## atrás en la carretera; y en recta no cambia nada.
extends "res://tests/case.gd"

const Card = preload("res://app/lab/moving_car_card.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


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


func _run(card: Control, steps: int, ms := 16.0) -> void:
	for i in steps:
		card.step(ms)
		await wait_frames(1)


func test_al_limite_las_garras_de_fuera_dejan_su_surco() -> void:
	var card := _card("tigre")
	card.st.set_zone("techo")
	card.speed.slider.value = 90.0
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.preset_pills["v40"].pressed.emit()
	card.finish()
	await _run(card, 6)
	var view: Control = card.view
	var g: Dictionary = card.st.grip_now()
	assert_true(int(g.slips) > 0 and bool(g.holds), "el tigre a 90 km/h en 50 m resbala sin caerse (u %s)" % g.get("u"))
	var grooves: Array = view._dmg_grip.get("grooves", [])
	assert_eq(grooves.size(), int(g.slips), "un surco por garra que resbala")
	for s: Dictionary in grooves:
		assert_true(float((s.b as Vector2).y) > float((s.a as Vector2).y), "hacia fuera de la curva (a la derecha)")
		var len_m := ((s.b as Vector2) - (s.a as Vector2)).length()
		assert_true(absf(len_m - float(g.lenMm) / 1000.0) < 0.002, "del largo del estado: %s m" % len_m)
		assert_eq(float(s.depth_um), float(g.marks.depthUm), "de la hondura del motor")
	await _run(card, 12, 100.0)  # el miedo se suaviza (FEAR_TAU): en algo más de un segundo ya se le nota entero
	var all: Array = view.damage().get("grooves", [])
	assert_true(all.size() >= grooves.size(), "se ven en el coche")
	assert_true(absf(float(view._pose.get("curve_fear", 0.0))) > 0.3, "se le nota el miedo: %s" % view._pose.get("curve_fear"))
	card.road_seg.buttons[CarCurve.ROAD_STRAIGHT].pressed.emit()
	card.finish()
	await _run(card, 3)
	assert_true(view._dmg_grip.is_empty(), "en recta, sin surcos de la curva")
	assert_false(bool(view._pose.get("curve_on", false)), "ni la pose de la curva")


func test_en_la_s_se_recoloca_sin_crear_nada() -> void:
	var card := _card("tigre")
	card.st.set_zone("techo")
	card.speed.slider.value = 90.0
	card.road_seg.buttons[CarCurve.ROAD_S].pressed.emit()
	card.preset_pills["v40"].pressed.emit()
	card.finish()
	await _run(card, 4)
	var view: Control = card.view
	var g: Dictionary = card.st.grip_now()
	assert_true((g.events as Array).size() >= 2, "la S del tigre tiene sus momentos: %s" % (g.events as Array).size())
	var scene: Node3D = view.get("_scene")
	var nodes := scene.find_children("*", "", true, false).size() if scene != null else 0
	var builds: int = view.builds
	var pulsed := 0
	var counts: Array = []
	for i in 95:
		card.step(100.0)
		if i % 6 == 0:
			await wait_frames(1)
		if view._grip_pulse > 0.0:
			pulsed += 1
		counts.append((view._dmg_grip.get("grooves", []) as Array).size())
	assert_true(pulsed > 0, "al recolocarse da el tirón")
	assert_true(int(counts[0]) < int(counts[-1]), "los surcos aparecen a medida que pasa la S (%s → %s)" % [counts[0], counts[-1]])
	var total := 0
	for e: Dictionary in g.events:
		total += int(e.claws)
	assert_true(int(counts[-1]) <= total and int(counts[-1]) > 0, "como mucho los de sus momentos (%s de %s)" % [counts[-1], total])
	for i in range(1, counts.size()):
		assert_true(int(counts[i]) >= int(counts[i - 1]), "se acumulan: no desaparecen")
	if scene != null:
		assert_eq(scene.find_children("*", "", true, false).size(), nodes, "sin nodos nuevos")
	assert_eq(view.builds, builds, "sin geometría nueva")


func test_en_la_curva_cerrada_demasiado_rapida_se_cae() -> void:
	var card := _card("oso")
	card.st.set_zone("techo")
	card.speed.slider.value = 130.0
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.preset_pills["v40"].pressed.emit()
	card.finish()
	await _run(card, 2)
	var view: Control = card.view
	var g: Dictionary = card.st.grip_now()
	assert_true(bool(g.falls) and bool(g.sideways), "el oso a 130 km/h en 50 m no aguanta: se cae de lado")
	assert_false(bool(card.st.at.holds), "lo dice el equilibrio de siempre")
	var rig: RefCounted = view.get("_rig")
	var max_z := 0.0
	var min_y := INF
	var min_x := INF
	# más deprisa a media caída: sigue sin aguantar, así que la caída sigue donde iba (no vuelve a empezar)
	await _run(card, 4, 100.0)
	var t_mid: float = view._grip_fall_t
	assert_true(t_mid > 0.0, "ya se está cayendo")
	var sig0: String = view._grip_sig
	card.speed.slider.value = 135.0
	card.finish()
	await _run(card, 1)
	assert_true(view._grip_sig != sig0, "la vista ha recibido la velocidad nueva")
	assert_true(view._grip_fall_t >= t_mid, "la caída no vuelve a empezar (%s → %s)" % [t_mid, view._grip_fall_t])
	for i in 40:
		card.step(100.0)
		if i % 4 == 0:
			await wait_frames(1)
		if rig != null:
			var root: Node3D = rig.get("root")
			if root.visible:
				max_z = maxf(max_z, root.position.z)
				min_y = minf(min_y, root.position.y)
				min_x = minf(min_x, root.position.x)
	assert_true(view._grip_fall_t >= view._fall_total() - 1e-6, "la caída llega a su final")
	var grooves: Array = view._dmg_grip.get("grooves", [])
	assert_true(grooves.size() >= 2, "arañando con sus garras: %s surcos" % grooves.size())
	for s: Dictionary in grooves:
		assert_true(float((s.b as Vector2).y) >= float((s.a as Vector2).y), "hacia fuera")
		assert_true(absf(float((s.b as Vector2).y)) <= view.half_w(), "hasta el borde del panel, no más")
	if rig != null:
		assert_true(max_z > view.half_w(), "cae por el lado de fuera (z %s)" % max_z)
		assert_true(min_y < 0.5, "hasta la carretera (y %s)" % min_y)


func test_lo_nuevo_de_la_vista_no_calcula_fisica() -> void:
	var raw := FileAccess.get_file_as_string("res://app/lab/moving_car_view.gd")
	var at := raw.find("# ════════ Agarre en curva (unidad 4u)")
	assert_true(at > 0, "el bloque de la 4u")
	var end := raw.find("# ════════", at + 10)  # hasta el bloque siguiente (el de otra unidad), si lo hay
	var blk := code_only(raw.substr(at, (end - at) if end > 0 else -1))
	for bad: String in ["MovingCar.", "CarCurve.at_", "CarCurveGrip.at(", "CarCurveGrip.s_events", "CarCurveGrip.slip_marks", "Physics."]:
		assert_false(blk.contains(bad), "la vista no puede usar %s" % bad)
