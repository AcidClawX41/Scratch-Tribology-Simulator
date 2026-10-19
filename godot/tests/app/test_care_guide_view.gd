## El guiado de la cetrería en la página (unidad 5y): el aviso corto sobre la vista 3D con la acción de ahora y su valor; el mando
## del panel resaltado con su borde que late y su etiqueta, el panel desplazado hasta él y lo demás atenuado; en la escena, la
## cámara en la vista que toca, acercada a la zona, y el contorno que late en la herramienta de la bandeja o en la garra; cada
## objetivo que puede dar el guiado existe en la página o en la escena; con «Guiado» apagado o sin tutorial, nada; y en el
## teléfono, igual, sin tapar la garra.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const State = preload("res://core/lab/claw_care_state.gd")
const Guide = preload("res://core/lab/claw_care_guide.gd")
const GuidePlay = preload("res://tests/lab/test_claw_care_guide.gd")

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
	p.reduce_motion = true
	await wait_frames(3)
	p.runner.stop_thread()
	return [host, s, p]


## Pulsa lo que señala el guiado (en el estado) y pinta la página.
func _press(p: Control) -> Dictionary:
	var st: State = p.runner.state
	GuidePlay.press(st, st.view().guide)
	p.runner.post("tick", [0.0])
	p.refresh()
	p.step(16.0)
	return p.runner.latest().guide


## Pulsa hasta que el guiado señale algo con esta condición (o max veces).
func _until(p: Control, cond: Callable, max_presses := 80) -> Dictionary:
	var g: Dictionary = p.runner.latest().guide
	for i in max_presses:
		if cond.call(g):
			return g
		g = _press(p)
	return g


func test_un_mando_del_panel_se_resalta_con_su_borde() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.refresh()
	p.step(16.0)
	await wait_frames(2)
	p.step(16.0)
	var gi: Dictionary = p.guide_info()
	assert_eq(String(gi.guide.id), "sedacion:sujecion", "la rapaz: capucha y toalla")
	var btn: Control = p.sedation_seg.buttons["sujecion"]
	assert_eq(gi.control, btn, "el mando del panel que lo hace")
	assert_true(btn.self_modulate != Color.WHITE, "resaltado (late)")
	assert_true(bool(gi.frame.visible), "con su borde")
	assert_true(String(gi.frame.label).begins_with("Pulsa aquí") and String(gi.frame.label).contains("Capucha y toalla"), "y su etiqueta: %s" % gi.frame.label)
	var fr: Rect2 = gi.frame.rect
	assert_true(fr.grow(1.0).encloses(btn.get_global_rect()), "el borde rodea el mando (%s · %s)" % [fr, btn.get_global_rect()])
	assert_true(p.right_scroll.get_global_rect().grow(1.0).encloses(btn.get_global_rect()), "el panel se ha desplazado hasta él")
	# lo demás del panel, algo atenuado (la tarjeta del mando, no)
	var card: Control = null
	for c in p.right.get_children():
		if (c as Control).is_ancestor_of(btn):
			card = c
	assert_true(card != null and card.modulate.a > 0.99, "su tarjeta, sin atenuar")
	assert_true(p.head_card.modulate.a < 0.9, "las otras, atenuadas")
	# el aviso corto sobre la vista
	assert_true(bool(gi.view.visible) and String(gi.view.hint) == "Pon la capucha y la toalla", "el aviso sobre la vista: %s" % gi.view.hint)
	var bubble: Control = p.guide_view.bubble
	assert_true((p.view_box as Control).get_global_rect().grow(0.5).encloses(bubble.get_global_rect()), "dentro de la vista")
	(hs[0] as Control).visible = false


func test_en_la_escena_la_camara_va_y_el_contorno_late() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.refresh()
	await wait_frames(2)
	if p.scene == null:
		(hs[0] as Control).visible = false
		return
	# hasta coger una herramienta: la cámara, a la bandeja, y la herramienta con su contorno
	var g := _until(p, func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "herramienta" and String(x.id) != "bandeja")
	await wait_frames(2)
	p.step(16.0)
	assert_eq(String(g.where), "scene", "una herramienta de la bandeja: en la escena")
	assert_eq(p.view, "general", "la cámara, a la vista general (la bandeja)")
	var si: Dictionary = p.scene.call("guide_info")
	assert_true(int(si.meshes) > 0, "la herramienta, con su contorno que late (%d mallas)" % int(si.meshes))
	assert_eq(String(p.scene.call("info").suggested), String(g.tool), "y su marca en la bandeja")
	var pt: Vector2 = p.scene.call("guide_screen_point", g)
	assert_true(pt.x >= 0.0 and pt.x <= p.view3d.size.x and pt.y >= 0.0 and pt.y <= p.view3d.size.y, "se ve en la vista: %s" % pt)
	assert_true(bool(p.guide_view.info().tag), "con su etiqueta junto al aro")
	assert_true(p.tray_pills[String(g.tool)].self_modulate != Color.WHITE, "y su píldora del panel, resaltada")
	# cogida: la garra, de cerca, en la zona
	g = _until(p, func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "garra")
	await wait_frames(2)
	p.step(16.0)
	assert_eq(p.view, "garra", "la cámara, a la garra")
	si = p.scene.call("guide_info")
	assert_true(absf(float(si.focus_s) - float(g.s_mm)) < 0.06, "se acerca a la zona (%s · %s mm)" % [si.focus_s, g.s_mm])
	assert_true(int(si.meshes) >= 1, "la garra, con su contorno")
	assert_eq(String(p.runner.latest().hints.highlight), String(g.zone), "y su zona resaltada")
	(hs[0] as Control).visible = false


func test_cada_objetivo_existe_en_la_pagina_o_en_la_escena() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.refresh()
	await wait_frames(2)
	for aid: String in ["rapaz", "tigre", "oso", "velociraptor"]:
		p.runner.post("set_animal", [aid])
		p.refresh()
		var st: State = p.runner.state
		for id: String in Guide.ids_for(st):
			var kind := id.get_slice(":", 0)
			if kind in ["bandeja", "garra"]:
				if p.scene != null and kind == "bandeja" and id != "bandeja":
					assert_true((p.scene.get("_tools") as Dictionary).has(id.get_slice(":", 1)), "%s: %s en la bandeja 3D" % [aid, id])
				continue
			assert_true(p.call("_ui_target", id) != null, "%s: «%s» es un mando de la página" % [aid, id])
	(hs[0] as Control).visible = false


func test_sin_guiado_o_sin_tutorial_nada_se_resalta() -> void:
	var hs: Array = await _host(Vector2(1240, 880))
	var p: Control = hs[2]
	p.refresh()
	p.step(16.0)
	assert_true(bool(p.guide_info().view.visible), "con el guiado: el aviso")
	assert_true(p.guide_pill.visible and p.guide_pill.button_pressed, "y su interruptor, encendido")
	p.guide_pill.pressed.emit()
	p.refresh()
	p.step(16.0)
	var gi: Dictionary = p.guide_info()
	assert_true((gi.guide as Dictionary).is_empty(), "«Guiado» apagado: sin objetivo")
	assert_false(bool(gi.view.visible), "ni aviso")
	assert_false(bool(gi.frame.visible), "ni borde")
	assert_false(p.guide_pill.button_pressed, "el interruptor, apagado")
	for c in p.right.get_children():
		assert_true((c as Control).modulate.a > 0.99, "nada atenuado: %s" % (c as Control).name)
	p.guide_pill.pressed.emit()
	p.tut_toggle.pressed.emit()
	p.refresh()
	p.step(16.0)
	gi = p.guide_info()
	assert_true((gi.guide as Dictionary).is_empty(), "«Tutorial apagado»: sin objetivo")
	assert_false(bool(gi.view.visible) or bool(gi.frame.visible), "ni aviso ni borde")
	assert_false(p.guide_pill.visible, "y el interruptor del guiado no se ve")
	assert_eq(p.sedation_seg.buttons["sujecion"].self_modulate, Color.WHITE, "nada resaltado")
	(hs[0] as Control).visible = false


func test_en_el_telefono_sin_tapar_la_garra() -> void:
	var hs: Array = await _host(Vector2(390, 844))
	var p: Control = hs[2]
	p.refresh()
	await wait_frames(3)
	# un mando del panel: se trae a la vista y se resalta
	p.step(16.0)
	await wait_frames(20)
	var gi: Dictionary = p.guide_info()
	var btn: Control = gi.control
	assert_true(btn != null and bool(gi.frame.visible), "el mando, con su borde")
	var r := btn.get_global_rect()
	assert_true(r.position.y >= 0.0 and r.end.y <= 844.0, "traído a la pantalla (%s)" % r)
	# la garra: el aviso arriba de la vista, sin tapar el punto que señala; las líneas de la mano, escondidas
	var g := _until(p, func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "garra")
	await wait_frames(20)
	p.step(16.0)
	assert_false(p.hud_tool.visible or p.hud_hand.visible, "las líneas de la mano dejan sitio al aviso")
	var bubble: Rect2 = p.guide_view.bubble.get_global_rect()
	var vr: Rect2 = (p.view_box as Control).get_global_rect()
	assert_true(vr.grow(0.5).encloses(bubble), "el aviso, dentro de la vista (%s en %s)" % [bubble, vr])
	assert_true(bubble.size.x <= vr.size.x, "y a lo ancho de la vista")
	if p.scene != null:
		var pt: Vector2 = p.scene.call("guide_screen_point", g)
		if pt.x >= 0.0:
			assert_false(bubble.has_point(vr.position + pt), "el aviso no tapa lo que señala en la garra (%s · %s)" % [bubble, vr.position + pt])
		assert_true(vr.position.y >= -1.0 and vr.position.y < 844.0, "la vista, a la vista (%s)" % vr)
	(hs[0] as Control).visible = false
