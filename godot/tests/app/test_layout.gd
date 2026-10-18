## Disposición real de la interfaz, con fotogramas de verdad (los tests son corrutinas: case.gd → wait_frames): el
## ejecutor espera a cada test y libera sus nodos al acabar. La sección del laboratorio en un teléfono (390 × 844) va en
## una columna y en escritorio (1240 × 880) en dos, sin desbordar el ancho (en el teléfono, también con el interruptor
## de la vibración, la confirmación de «Reiniciar logros y cuaderno» y, con la piel, las píldoras de la zona del cuerpo).
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const HapticsSpy = preload("res://tests/app/haptics_spy.gd")
const SkinTable = preload("res://app/lab/skin_table.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")


func test_el_ejecutor_espera_fotogramas() -> void:
	var frames := [0]
	var count := func() -> void: frames[0] += 1
	tree().process_frame.connect(count)
	await wait_frames(3)
	tree().process_frame.disconnect(count)
	assert_eq(frames[0], 3, "han pasado 3 fotogramas")
	var box := VBoxContainer.new()
	for i in 3:
		var c := Control.new()
		c.custom_minimum_size = Vector2(10, 20)
		box.add_child(c)
	add_to_tree(box)
	assert_true(box.is_inside_tree(), "add_to_tree lo mete en el árbol")
	var sorted := await wait_until(func() -> bool: return (box.get_child(2) as Control).position.y > 0.0, 10)
	assert_true(sorted, "el contenedor dispone a sus hijos en un fotograma")
	assert_eq((box.get_child(2) as Control).position.y, 2.0 * (20.0 + box.get_theme_constant("separation")))


func test_el_laboratorio_en_telefono_y_en_escritorio() -> void:
	for c: Array in [[Vector2(390, 844), false], [Vector2(1240, 880), true]]:
		var size: Vector2 = c[0]
		var wide: bool = c[1]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		if not wide:
			s.haptics = HapticsSpy.new()  # un teléfono: con vibración
		host.add_child(s)
		await wait_frames(4)
		var where := "%dx%d" % [size.x, size.y]
		assert_eq(s.size, size, "%s: la sección ocupa todo" % where)
		assert_eq(s.columns.vertical, not wide, "%s: %s" % [where, "dos columnas" if wide else "una columna"])
		assert_true(s.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
		for card: Control in [s.tool_card, s.target_card, s.params_card, s.result_card, s.compare_card, s.badges_card]:
			var r := card.get_global_rect()
			assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, card.title_label.text, r])
		if wide:
			assert_true(s.tool_card.get_global_rect().end.x <= s.result_card.get_global_rect().position.x, "escritorio: herramienta a la izquierda del banco")
		else:
			assert_true(s.tool_card.get_global_rect().end.y <= s.run_button.get_global_rect().position.y, "teléfono: el botón debajo de las tarjetas de configuración")
			# el pie de los logros con la vibración y la confirmación de reiniciar (el texto más largo)
			s.run()
			s.step(LabState.RUN_MS + 200.0)
			s.badges_card.reset_button.pressed.emit()
			await wait_frames(3)
			assert_eq(s.badges_card.reset_button.text, s.badges_card.RESET_CONFIRM)
			for ctl: Control in [s.badges_card, s.badges_card.haptics_button, s.badges_card.reset_button]:
				var r := ctl.get_global_rect()
				assert_true(ctl.visible and r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, ctl.name, r])
			assert_true(s.content.size.x <= size.x + 0.5, "%s: con el pie de los logros, nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
			# 2.0: con la piel, las cinco píldoras de la zona del cuerpo (en varias filas si no caben) y su ficha
			s.lab.set_target(Catalog.find_by_id(Catalog.TARGETS, "piel"))
			s.step(0.0)
			await wait_frames(3)
			var zb: Control = s.target_card.zone_box
			var zr := zb.get_global_rect()
			assert_true(zb.visible and zr.position.x >= -0.5 and zr.end.x <= size.x + 0.5, "%s: la zona del cuerpo dentro de la pantalla (%s)" % [where, zr])
			assert_true(s.params_card.attack_box.visible, "%s: el ángulo de ataque de la uña" % where)
			assert_true(s.content.size.x <= size.x + 0.5, "%s: con la zona y el ángulo, nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
		host.remove_child(s)
		s.free()


## 4q: el nombre de una ficha no rebasa la ficha: si su palabra más larga no cabe («Velocirraptor», «Guacamayo»), se
## encoge hasta 10 px (antes se salía por los lados, sobre todo en el teléfono).
func test_los_nombres_de_las_fichas_caben_en_su_ficha() -> void:
	for size: Vector2 in [Vector2(390, 844), Vector2(1240, 880)]:
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		await wait_frames(3)
		var base: int = (s.theme as Theme).get_font_size(&"font_size", &"TileLabel")
		for id: String in s.tool_card.geom_tiles:  # en escritorio, las formas de uña caben: al tamaño del tema
			var gl: Label = s.tool_card.geom_tiles[id].main_labels[0]
			var gfs := gl.get_theme_font_size(&"font_size")
			if size.x >= 1000.0:
				assert_eq(gfs, base, "%dx%d · «%s», al tamaño del tema" % [size.x, size.y, gl.text])
			else:  # en el teléfono, «Cuadrada» (68 px en 66) baja un punto
				assert_true(gfs <= base and gfs >= 10, "%dx%d · «%s» entre 10 px y el tamaño del tema (%d)" % [size.x, size.y, gl.text, gfs])
		s.tool_card.kind_seg.buttons["garras"].pressed.emit()
		s.step(0.0)
		await wait_frames(4)
		var checked := 0
		for id: String in s.tool_card.claw_tiles:
			var b: Control = s.tool_card.claw_tiles[id]
			if not b.is_visible_in_tree():
				continue
			var l: Label = b.main_labels[0]
			var fs := l.get_theme_font_size(&"font_size")
			var longest := 0.0
			for word in l.text.split(" ", false):
				longest = maxf(longest, l.get_theme_font(&"font").get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			var room := b.size.x - 2.0  # dentro del borde de la ficha (1 px a cada lado)
			assert_true(longest <= room, "%dx%d · «%s»: su palabra más larga cabe en la ficha (%d de %d px, a %d px)" % [
				size.x, size.y, l.text, longest, room, fs])
			assert_true(fs <= base, "%dx%d · «%s»: nunca más grande que en el tema (%d px)" % [size.x, size.y, l.text, fs])
			checked += 1
		assert_true(checked >= 15, "se han mirado las fichas de las garras (%d)" % checked)
		host.remove_child(s)
		s.free()


## 4q: en el teléfono, con el velocirraptor de cine, el título de la tarjeta del coche («Coche en marcha · Velocirraptor de
## cine») salta de línea: antes ensanchaba la página a 394 px en una pantalla de 390.
func test_el_coche_en_marcha_cabe_en_el_telefono() -> void:
	var host := Control.new()
	host.size = Vector2(390, 844)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	await wait_frames(3)
	s.set_page(s.PAGE_CAR, false)
	await wait_frames(3)
	var card: Control = s.moving_car_card
	card.animal_pills["velociraptor_pelicula"].pressed.emit()
	await wait_frames(4)
	s.refresh_now()
	await wait_frames(4)
	var scroll: ScrollContainer = s.scroll
	var page: Control = scroll.get_child(0)
	assert_true(card.title_label.text.ends_with("Velocirraptor de cine"), "el título lleva el animal")
	assert_true(page.size.x <= scroll.size.x + 0.5, "la página no es más ancha que la pantalla (%s de %s px)" % [page.size.x, scroll.size.x])
	var r: Rect2 = card.get_global_rect()
	assert_true(r.end.x <= host.size.x + 0.5, "la tarjeta dentro de la pantalla (%s)" % r)
	host.remove_child(s)
	s.free()


## 4q: en el teléfono, una entrada larga del cuaderno salta de línea en lugar de cortarse con puntos suspensivos (se
## perdía el material: «Garra falciforme de velocirraptor de …»).
func test_el_cuaderno_no_corta_las_entradas_en_el_telefono() -> void:
	var host := Control.new()
	host.size = Vector2(390, 844)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	await wait_frames(3)
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "velociraptor"))
	s.lab.set_inlay(Catalog.find_by_id(Catalog.INLAYS, "diamante"))
	s.lab.set_target(Catalog.find_by_id(Catalog.TARGETS, "acero"))
	s.run()
	s.step(LabState.RUN_MS + 200.0)
	s.refresh_now()
	await wait_frames(4)
	# y la ficha del velocirraptor de cine (con «~382 N (193–1130)» en su agarre) no ensancha la página (4q)
	var scroll2: ScrollContainer = s.scroll
	var page2: Control = scroll2.get_child(0)
	assert_true(page2.size.x <= scroll2.size.x + 0.5, "con el velocirraptor, la página no es más ancha que la pantalla (%s de %s px)" % [page2.size.x, scroll2.size.x])
	var what: Label = s.badges_card.book_rows[0][2]
	assert_true(what.text.ends_with("→ Acero inox."), "la entrada, con el material (%s)" % what.text)
	assert_false(what.clip_text, "sin recortar")
	assert_true(what.get_line_count() >= 2, "en el teléfono, en dos líneas (%d)" % what.get_line_count())
	assert_eq(what.get_visible_line_count(), what.get_line_count(), "todas a la vista")
	host.remove_child(s)
	s.free()


## 4q: en la columna estrecha del teléfono, la tabla de la piel no parte una palabra («Tercer metacarpiano») ni separa un
## número de su unidad («18 µm», «4.1 kJ/m²»), y sigue alineada.
func test_la_tabla_de_la_piel_no_parte_palabras_ni_unidades() -> void:
	assert_eq(SkinTable.glue("0 µm – 18 µm"), "0 µm – 18 µm", "el número, pegado a su unidad")
	assert_eq(SkinTable.glue("4.1 kJ/m²"), "4.1 kJ/⁠m²", "y la unidad, sin partir por la barra")
	assert_eq(SkinTable.glue("dureza 43 HV"), "dureza 43 HV")
	var host := Control.new()
	host.theme = AppTheme.get_theme()
	host.size = Vector2(300, 600)
	add_to_tree(host)
	var t: Control = SkinTable.new()
	t.size = Vector2(300, 10)
	host.add_child(t)
	t.set_zone("dorsomano")
	await wait_frames(4)
	var starts: Array = []  # dónde empieza cada columna en la primera fila
	for r: Node in t.get_children():
		if not r.has_meta("cells"):
			continue
		var cells: Array = r.get_meta("cells")
		var labels: Array = r.get_meta("labels")
		for i in labels.size():
			var l: Label = labels[i]
			# los trozos entre espacios normales (el número y su unidad van unidos por un espacio duro)
			for chunk in l.text.split(" ", false):
				var w := l.get_theme_font(&"font").get_string_size(chunk, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x
				assert_true(w <= l.size.x + 0.5, "«%s»: «%s» cabe en su columna sin partirse (%d de %d px)" % [l.text, chunk, w, l.size.x])
			var x: float = (cells[i] as Control).global_position.x
			if starts.size() <= i:
				starts.append(x)
			assert_near(x, float(starts[i]), 0.0, 0.5, "«%s»: la columna %d empieza donde en las demás filas" % [l.text, i + 1])
		assert_true((r as Control).size.x <= t.size.x + 0.5, "la fila no rebasa la tabla (%s de %s px)" % [(r as Control).size.x, t.size.x])


## 4q: con la página casi tan alta como lo que se ve, la barra de desplazamiento que aparecía y desaparecía cambiaba el
## ancho, el dibujo del banco (que guarda su proporción) cambiaba de alto y la barra volvía a cambiar, sin fin: la cola de
## mensajes se llenaba y Godot se cerraba. Con el hueco de la barra reservado, el ancho de la página no depende de ella.
func test_la_pagina_no_entra_en_bucle_cuando_cabe_justa() -> void:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	await wait_frames(4)
	assert_eq(s.scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_RESERVE, "el hueco de la barra, siempre reservado")
	s.run()
	s.step(LabState.RUN_MS + 200.0)
	s.refresh_now()
	await wait_frames(4)
	var scroll: ScrollContainer = s.scroll
	var page: Control = scroll.get_child(0)
	var chrome: float = host.size.y - scroll.size.y
	var widths: Array[float] = []
	for extra: float in [-2.0, 0.0, 2.0]:  # justo en el umbral en que la barra aparece o desaparece
		host.size.y = ceilf(chrome + page.size.y + extra)
		await wait_frames(3)
		widths.append(page.size.x)
	assert_true(widths.max() - widths.min() < 0.5, "el ancho de la página no cambia con la barra (%s)" % [widths])
	host.remove_child(s)
	s.free()
