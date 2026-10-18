## El velocirraptor y el afilado en la tarjeta de la herramienta (unidad 4i): la ficha de la reconstrucción, el
## deslizador «Afilado» (solo con una garra o un colmillo reforjados), sus marcas, sus dos barras y la nota, todo con los
## textos del estado (LabState.sharpness_view); el recorrido del deslizador se pone con las señales bloqueadas; y la fila de
## la punta afilada en el resultado. La disposición en el teléfono y en el escritorio, con fotogramas de verdad.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const Palette = preload("res://app/theme/palette.gd")
const ResultCard = preload("res://app/lab/result_card.gd")

var s: Control


func before_each() -> void:
	if s == null:
		s = LabSection.instantiate()
		s.setup()
		s.art.threaded = false


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


func _click(b: BaseButton) -> void:
	b.pressed.emit()
	s.step(0.0)


func _slide(r: Range, v: float) -> void:
	var before := r.value
	r.value = v
	if r.value != before:
		r.value_changed.emit(r.value)
	s.step(0.0)


func _raptor(inlay: String) -> void:
	var tc: Control = s.tool_card
	_click(tc.kind_seg.buttons["garras"])
	_click(tc.claw_tiles["velociraptor"])
	_click(tc.inlay_pills[inlay])


func test_la_ficha_del_velocirraptor() -> void:
	_raptor("none")
	var tc: Control = s.tool_card
	assert_true(tc.claw_tiles.has("velociraptor"), "su ficha entre las garras")
	var grid: Control = (tc.claw_tiles["velociraptor"] as Control).get_parent()
	assert_true(grid.visible, "su grupo se ve con las garras")
	var label: Label = tc.claw_groups["Dinosaurios (reconstrucción)"][0]
	assert_true(label.visible, "el rótulo del grupo: «Dinosaurios (reconstrucción)»")
	var tool: Dictionary = s.lab.tool()
	var spec := Lab.claw_spec(s.lab.claw, s.lab.inlay, tool)
	var rows := DinoLab.spec_rows(s.lab.claw, spec.material, spec.hardness, tool)
	for i in rows.size():
		var st: HBoxContainer = tc.claw_stats[i]
		assert_true(st.visible, "fila %d a la vista" % i)
		assert_eq([st.get_child(0).text, st.get_child(1).text], rows[i], "fila %d: el texto del estado" % i)
	for i in range(rows.size(), tc.claw_stats.size()):
		assert_false(tc.claw_stats[i].visible, "fila %d oculta" % i)
	assert_true(tc.claw_source.visible and tc.claw_source.text == DinoLab.sources_line(s.lab.claw), "la línea de fuentes")
	assert_true(String(tc.claw_desc.text).begins_with("Reconstrucción"), "la descripción dice «reconstrucción»")
	assert_false(tc.sharp_box.visible, "sin reforjar, sin afilado")
	# la fuerza máxima
	var pc: Control = s.params_card
	assert_true(String(pc.max_note.text).contains("la garra sola, ~10 N; la réplica, 483 N"), pc.max_note.text)
	_click(pc.max_button)
	assert_eq(s.lab.force, 381.5, "el agarre de un pie")


func test_el_deslizador_del_afilado() -> void:
	_raptor("diamante")
	_click(s.target_card.tiles["acero"])
	var tc: Control = s.tool_card
	assert_true(tc.sharp_box.visible, "reforjada: el deslizador se ve")
	# moverlo cambia el estado (en centésimas) y los textos son los del estado
	_slide(tc.sharp.slider, 0.5)
	assert_eq(s.lab.sharpness, 0.5, "el afilado del banco")
	var view: Dictionary = s.lab.sharpness_view()
	assert_eq(tc.sharp.display.text, view.display, "el valor del deslizador (el radio de la punta)")
	assert_eq(tc.sharp.slider.accessibility_description, view.spoken)
	var marks: Array = view.marks
	assert_eq(tc.sharp_marks.marks.size(), marks.size(), "una marca por referencia")
	for i in tc.sharp_items.size():
		var item: Array = tc.sharp_items[i]
		assert_eq((item[0] as Control).visible, i < marks.size(), "leyenda %d" % i)
		if i < marks.size():
			assert_eq((item[2] as Label).text, marks[i].text)
	for key: String in ["pressure", "lateral"]:
		var parts: Array = tc.sharp_bar_parts[key]
		assert_eq((parts[0] as Label).text, view[key].title, "%s: el título" % key)
		assert_eq((parts[1] as Control).level, float(view[key].level), "%s: la barra" % key)
		assert_eq((parts[1] as Control).color, Palette.color(view[key].color), "%s: su color" % key)
		assert_eq((parts[2] as Label).text, view[key].text, "%s: su texto" % key)
	assert_eq(tc.sharp_note.text, view.note)
	assert_true((tc.sharp_bar_parts.pressure[1] as Control).level > 0.0 and (tc.sharp_bar_parts.lateral[1] as Control).level < 1.0,
		"afilada: sube la presión y baja la carga de lado")
	# el ensayo usa la punta afilada y el resultado lleva su fila
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	var p: Dictionary = s.lab.params()
	p.claw = s.lab.claw
	p.tear = s.lab.tear_mode
	assert_eq(oracle_diff(s.lab.res, Physics.compute(p)).size(), 0, "el ensayo del banco, con el afilado")
	assert_true(s.lab.res.sharpness is Dictionary and float(s.lab.res.sharpness.sharpness) > 0.4, "el resultado lleva el afilado")
	var row: Variant = DinoLab.sharpness_row(s.lab.res)
	assert_true(row is Array, "fila de la punta afilada")
	s.refresh_now()
	var found := false
	for m: Control in s.result_card.metrics:
		if m.visible and m.key == row[0]:
			found = true
			assert_eq(m.value.text, row[2], "el texto de la fila, del core")
	assert_true(found, "la tarjeta del resultado enseña «%s»" % row[0])
	# volver a la queratina oculta el deslizador (y el afilado se conserva, como la fuerza)
	_click(tc.inlay_pills["none"])
	assert_false(tc.sharp_box.visible, "sin reforjar, oculto")
	assert_eq(s.lab.sharpness, 0.5)
	# los aguijones no se afilan (su punta está medida)
	_click(tc.kind_seg.buttons["insectos"])
	_click(tc.inlay_pills["acero"])
	assert_false(tc.sharp_box.visible, "un aguijón reforjado no se afila")
	_click(tc.inlay_pills["none"])


func test_el_recorrido_se_pone_con_las_senales_bloqueadas() -> void:
	_raptor("zafiro")
	var tc: Control = s.tool_card
	var seen: Array = []
	var spy := func(v: float) -> void: seen.append(v)
	tc.sharp.slider.value_changed.connect(spy)
	s.lab.set_sharpness(0.73)
	s.step(0.0)
	s.refresh_now()
	assert_eq(tc.sharp.slider.value, 0.73, "el deslizador sigue al estado")
	assert_eq(seen, [], "poner el recorrido y el valor no emite value_changed (no vuelve al estado)")
	tc.set_slider(tc.sharp.slider, 0.2, 0.4, 0.9)
	assert_eq([tc.sharp.slider.min_value, tc.sharp.slider.max_value, tc.sharp.slider.value], [0.2, 0.4, 0.4], "Godot recorta el valor…")
	assert_eq(seen, [], "… sin avisar")
	tc.sharp.slider.value_changed.disconnect(spy)
	s.refresh_now()
	assert_eq([tc.sharp.slider.min_value, tc.sharp.slider.max_value, tc.sharp.slider.value], [0.0, 1.0, 0.73], "el recorrido de siempre")
	s.lab.set_sharpness(0.0)
	_click(tc.inlay_pills["none"])


func test_el_afilado_en_telefono_y_en_escritorio() -> void:
	for c: Array in [[Vector2(390, 844), false], [Vector2(1240, 880), true]]:
		var size: Vector2 = c[0]
		var wide: bool = c[1]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var sec: Control = LabSection.instantiate()
		host.add_child(sec)
		await wait_frames(3)
		sec.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "velociraptor"))
		sec.lab.set_inlay(Catalog.find_by_id(Catalog.INLAYS, "diamante"))
		sec.lab.set_target(T("acero"))
		sec.lab.set_sharpness(0.5)
		sec.step(0.0)
		await wait_frames(4)
		var where := "%dx%d" % [size.x, size.y]
		var tc: Control = sec.tool_card
		assert_true(tc.sharp_box.visible, "%s: el afilado se ve" % where)
		for ctl: Control in [tc.sharp_box, tc.sharp.slider, tc.sharp_bars, tc.sharp_note, tc.claw_source]:
			var r := ctl.get_global_rect()
			assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, ctl.get_class(), r])
		for st: Control in tc.claw_stats:
			if st.visible:
				var r := st.get_global_rect()
				assert_true(r.end.x <= size.x + 0.5, "%s: la fila «%s» de la ficha cabe (%s)" % [where, st.get_child(0).text, r])
		assert_true(sec.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [where, sec.content.size.x])
		# las dos barras: en fila en el escritorio y una debajo de otra en el teléfono
		assert_eq(tc.sharp_bars.is_row, wide, "%s: las barras %s" % [where, "en fila" if wide else "en columna"])
		var a: Control = tc.sharp_bars.get_child(0)
		var b: Control = tc.sharp_bars.get_child(1)
		if wide:
			assert_true(a.get_global_rect().end.x <= b.get_global_rect().position.x + 0.5, "%s: la presión a la izquierda" % where)
		else:
			assert_true(a.get_global_rect().end.y <= b.get_global_rect().position.y + 0.5, "%s: la presión encima" % where)
		host.remove_child(sec)
		sec.free()


func test_afilada_la_fila_de_la_punta_sustituye_a_la_del_mellado() -> void:
	# el zafiro se mella también en el módulo de la 1f (tipChip): afilada, el resultado lo cuenta una sola vez
	var lab := LabState.new()
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "velociraptor"))
	lab.set_inlay(Catalog.find_by_id(Catalog.INLAYS, "zafiro"))
	lab.set_target(T("acero"))
	lab.set_force(381.5)
	for s: float in [0.0, 0.5]:
		lab.set_sharpness(s)
		lab.run()
		assert_true(lab.res.tipChip is Dictionary, "s = %s: el zafiro arrastrado se mella (1f)" % s)
		var keys: Array = ResultCard.materials_rows(lab.res).map(func(r: Array) -> String: return r[0])
		assert_eq(keys.has("La punta se mella con"), s == 0.0, "s = %s: la fila de la 1f, solo sin afilar" % s)
		assert_eq(keys.has("Punta afilada"), s > 0.0, "s = %s: la de la punta afilada, solo afilada" % s)


func test_ultimo_libera_la_seccion() -> void:
	assert_true(s.art.pending() == 0, "sin hilos pendientes")
	s.free()
	s = null
	assert_true(s == null)
