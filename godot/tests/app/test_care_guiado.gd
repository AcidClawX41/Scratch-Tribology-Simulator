## La cetrería guiada en la página (unidad 5o, petición 51): la barra del estado del animal y de lo que se está haciendo, de lado
## a lado encima de la vista 3D y siempre visible (en el teléfono, fija encima del desplazamiento de la sección aunque se baje por
## las tarjetas, sin tapar la garra); el tutorial con su objetivo, su progreso y el mando que hay que pulsar resaltado (también la
## herramienta, en la bandeja 3D); y la sesión parada, explicada en el informe, sin «Seguir con esta garra».
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const State = preload("res://core/lab/claw_care_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")

const FRAME := 1.0 / 60.0


func _host(size: Vector2) -> Array:
	var host := Control.new()
	host.size = size
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	s.set_page(s.PAGE_CARE, false)
	var p: Control = s.care_page
	p.threaded = false
	await wait_frames(3)
	p.runner.stop_thread()
	return [host, s, p]


func test_la_barra_del_animal_encima_de_la_vista() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.refresh()
	var bar: Control = p.status_bar
	assert_eq(p.bar_slot.get_parent(), p.left, "escritorio: en la columna de la vista")
	assert_true(p.bar_slot.get_index() < p.view_box.get_index(), "encima de la vista 3D")
	assert_false(bar.compact, "con la etiqueta y el valor en una fila")
	# colocarla otra vez (cada cambio de tamaño lo hace) la deja donde estaba, no debajo de la vista
	p._place_status_bar()
	p._place_status_bar()
	assert_true(p.bar_slot.get_index() == p.view_box.get_index() - 1, "colocada dos veces más, sigue justo encima de la vista")
	await wait_frames(2)
	var r := bar.get_global_rect()
	var vr: Rect2 = p.view_box.get_global_rect()
	assert_true(r.end.y <= vr.position.y + 0.5 and absf(r.size.x - vr.size.x) < 1.0, "de lado a lado de la vista, sin taparla (%s · %s)" % [r, vr])
	assert_eq(bar.meters.size(), 3, "el estrés, la sangre y el calor")
	for id: String in bar.meters:
		assert_true(String((bar.meters[id].box as Control).tooltip_text).length() > 40, "%s: con su ayuda emergente" % id)
	# lo que se está haciendo, con su cuenta: el hemostático sobre una herida
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	st.pick("tenaza")
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0))
	for i in int((State.CLIP_CLOSE_S + 0.1) / FRAME):
		st.tick(FRAME)
	st.release()
	st.pick("hemostatico")
	var s0 := st.care.apex_mm() - 0.5
	st.press_on(s0)
	for i in 30:
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	# (el estado se ha manejado a mano: una orden publica su vista)
	p.runner.post("tick", [0.0])
	p.refresh()
	assert_true(bar.act_label.text.contains("de 30 s") and bar.act_bar.visible, "la línea dice los segundos, con su barra: %s" % bar.act_label.text)
	st.release()
	(hs[0] as Control).visible = false


func test_en_el_telefono_la_barra_se_queda_fija() -> void:
	var hs: Array = await _host(Vector2(390, 844))
	var s: Control = hs[1]
	var p: Control = hs[2]
	p.refresh()
	await wait_frames(4)
	var bar: Control = p.status_bar
	var slot: Control = p.bar_slot
	assert_eq(slot.get_parent(), s.scroll.get_parent(), "teléfono: fuera del desplazamiento de la sección")
	assert_true(slot.get_index() == s.scroll.get_index() - 1, "justo encima del desplazamiento")
	assert_true(bar.compact, "compacta: la etiqueta encima del valor")
	# cada cambio de tamaño vuelve a colocarla: sigue encima del desplazamiento, no al pie de la pantalla
	p._place_status_bar()
	p._place_status_bar()
	await wait_frames(2)
	assert_true(slot.get_index() == s.scroll.get_index() - 1, "colocada otra vez, sigue encima del desplazamiento")
	assert_true(bar.visible and bar.is_visible_in_tree(), "y se ve")
	var top0 := bar.get_global_rect().position.y
	assert_true(bar.get_global_rect().position.x >= 8.0, "con el margen de las tarjetas, no a ras del borde (%s)" % bar.get_global_rect())
	for id: String in bar.meters:
		var val: Label = bar.meters[id].value
		assert_true(val.get_theme_font(&"font").get_string_size(val.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, val.get_theme_font_size(&"font_size")).x <= val.size.x + 0.5, "%s: el valor (corto) cabe entero («%s»: %s px en %s; la barra %s)" % [id, val.text, val.get_theme_font(&"font").get_string_size(val.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, val.get_theme_font_size(&"font_size")).x, val.get_global_rect(), bar.get_global_rect()])
		assert_true(String((bar.meters[id].box as Control).tooltip_text).contains(val.text.substr(0, 4)), "%s: el texto entero, en la ayuda" % id)
	s.scroll.scroll_vertical = 900
	await wait_frames(3)
	var r := bar.get_global_rect()
	assert_near(r.position.y, top0, 0.5, 0.0, "bajando por las tarjetas, la barra no se mueve")
	assert_true(r.position.y >= -0.5 and r.end.y <= 844.5 and r.end.x <= 390.5, "dentro de la pantalla (%s)" % r)
	assert_true(r.end.y <= s.scroll.get_global_rect().position.y + 0.5, "sin tapar lo de debajo (la vista y las tarjetas)")
	# otra página de la sección: la barra se esconde; de vuelta, se ve
	s.set_page(s.PAGE_BENCH, false)
	await wait_frames(2)
	assert_false(bar.is_visible_in_tree(), "en el banco no se ve")
	s.set_page(s.PAGE_CARE, false)
	await wait_frames(2)
	assert_true(bar.is_visible_in_tree(), "de vuelta en la cetrería, sí")
	(hs[0] as Control).visible = false


## Con la lima en la mano, de frente («90° (de frente)»), la fila del ángulo con su pista «(A/D)» no cabía en 390 px: la sección
## entera se ensanchaba y la barra del animal y las tarjetas se salían por la derecha (visto en la captura del caso 17).
func test_en_el_telefono_la_seccion_no_se_ensancha_al_limar() -> void:
	var hs: Array = await _host(Vector2(390, 844))
	var s: Control = hs[1]
	var p: Control = hs[2]
	p.refresh()
	await wait_frames(3)
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	st.pick("lima_bastarda")
	st.set_angle(90.0)
	var s0 := st.care.apex_mm() - 0.5
	st.press_on(s0)
	for i in 6:
		st.drag(5.0, 5.0, s0, FRAME)
		st.tick(FRAME)
	p.runner.post("tick", [0.0])
	p.refresh()
	await wait_frames(6)
	var root: Control = s.scroll.get_parent()
	assert_true(root.get_combined_minimum_size().x <= 390.0, "la sección cabe a lo ancho (mínimo %s)" % root.get_combined_minimum_size())
	assert_true(p.status_bar.get_global_rect().end.x <= 390.0, "y la barra del animal, dentro (%s)" % p.status_bar.get_global_rect())
	assert_true(p.status_bar.act_label.text.begins_with("Limando"), "con lo que se está haciendo: %s" % p.status_bar.act_label.text)
	st.release()
	(hs[0] as Control).visible = false


func test_el_tutorial_resalta_lo_que_hay_que_pulsar() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.runner.post("tutorial_goto", ["preparar"])
	p.refresh()
	var tv: Dictionary = p.runner.latest().tutorial
	assert_eq(String(tv.step.id), "capucha", "encapuchar")
	assert_true(p.tut_goal.text.begins_with("Objetivo: ") and p.tut_goal.text.contains("Encapucha"), "con su objetivo: %s" % p.tut_goal.text)
	var target: Control = p.sedation_seg.buttons["sujecion"]
	p.step(120.0)
	assert_true(target.self_modulate != Color.WHITE, "«Capucha y toalla», resaltado")
	assert_true(p.tut_total_bar.visible and p.tut_total_label.text.begins_with("Tutorial: paso"), "el progreso del total: %s" % p.tut_total_label.text)
	(target as BaseButton).pressed.emit()
	p.refresh()
	p.step(16.0)
	assert_eq(target.self_modulate, Color.WHITE, "hecho: deja de resaltarse")
	# la herramienta sugerida, señalada en la bandeja 3D
	p.runner.post("tutorial_goto", ["limar"])
	p.refresh()
	await wait_frames(2)
	var sug := String(p.runner.latest().tutorial.suggest)
	if sug != "" and p.scene != null:
		assert_eq(String(p.scene.call("info").suggested), sug, "la herramienta del paso, señalada en la bandeja 3D")
	(hs[0] as Control).visible = false


func test_la_sesion_parada_se_explica_en_el_informe() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.runner.post("set_animal", ["tigre"])
	var st: State = p.runner.state
	st.pick("lima_fina")
	for k in 2:
		var s0 := st.care.apex_mm() - 1.0
		st.press_on(s0)
		for i in 4:
			st.drag(3.0, 3.0, s0, FRAME)
			st.tick(FRAME)
		st.release()
	assert_eq(String(st.halted.get("code", "")), "ataca", "el tigre sin sedar, al segundo toque")
	p.runner.post("tick", [0.0])
	p.refresh()
	assert_true(p.report_card.visible and p.report_halt.visible and p.report_halt.text.contains("Sesión parada"), "el informe lo explica: %s" % p.report_halt.text)
	assert_false(p.resume_button.visible, "sin «Seguir con esta garra»: se empieza de nuevo")
	assert_true(String(p.status_bar.act_label.text).contains("Sesión parada"), "y la barra lo dice")
	(hs[0] as Control).visible = false


## Los mandos de la amoladora sobre la vista (el interruptor «Encender», más ancho que «Apagar») caben dentro de la vista.
func test_los_mandos_de_la_amoladora_caben_en_la_vista() -> void:
	for size: Vector2 in [Vector2(1240, 880), Vector2(390, 844)]:
		var hs: Array = await _host(size)
		var p: Control = hs[2]
		p.runner.post("pick", ["amoladora"])
		p.refresh()
		await wait_frames(2)
		assert_true(p.touch_box.visible and p.touch_power.text == "Encender", "%s: con la amoladora apagada, «Encender»" % size)
		var box: Rect2 = p.touch_box.get_global_rect()
		var vr: Rect2 = (p.view3d as Control).get_global_rect()
		assert_true(vr.grow(0.5).encloses(box), "%s: los mandos, dentro de la vista (%s en %s)" % [size, box, vr])
		(hs[0] as Control).visible = false
