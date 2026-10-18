## Programa (app/main.gd): selector de sección con el contrato de las secciones (la oculta, desactivada; la visible,
## heredando el proceso), el aviso del taller mientras no exista su escena, la barra superior y el interruptor de
## sonido (bus Master) recordado en el archivo de ajustes junto a la sección.
extends "res://tests/case.gd"

const Main = preload("res://app/main.tscn")
const Lab = preload("res://core/lab/lab.gd")
const AppInfo = preload("res://core/shared/app_info.gd")
const RendererChoice = preload("res://app/common/renderer_choice.gd")
const Overlay = preload("res://app/common/overlay.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")

const CFG := "user://test_ajustes_u12.cfg"


func _new_main() -> Control:
	var m: Control = Main.instantiate()
	m.settings_path = CFG
	m.setup()
	return m


func _cfg(key: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return null
	return c.get_value("app", key, null)


func before_each() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)
	AudioServer.set_bus_mute(0, false)


func test_cambiar_de_seccion_desactiva_el_proceso_de_la_oculta() -> void:
	var m := _new_main()
	m.show_section("bio")
	var bio: Control = m.pages["bio"]
	assert_eq(bio.process_mode, Node.PROCESS_MODE_INHERIT, "la visible hereda el proceso")
	assert_true(bio.visible)
	assert_eq(m.headline.text, "¿Qué raya a qué?", "titular de la sección del laboratorio")
	assert_true(m.fund_button.visible, "el laboratorio tiene fundamentos")
	m.show_section("taller")
	var taller: Control = m.pages["taller"]
	assert_eq(bio.process_mode, Node.PROCESS_MODE_DISABLED, "la oculta queda desactivada: se paran su reloj y sus sonidos")
	assert_false(bio.visible)
	assert_eq(taller.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(taller.visible)
	assert_eq(m.selector.value, "taller")
	if ResourceLoader.exists(m.TALLER_SCENE):
		assert_true(taller is Control, "la raíz del taller es un Control")
	else:
		assert_true(taller.has_meta("placeholder"), "sin escena del taller, un aviso «en construcción»")
		assert_false(m.fund_button.visible, "el aviso no tiene fundamentos: el botón se oculta")
	assert_eq(_cfg("section"), "taller", "la sección se recuerda")
	m.show_section("bio")
	assert_eq(taller.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(bio.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(m.pages.size(), 2, "cada sección se instancia una sola vez")
	m.show_section("no-existe")
	assert_eq(m.current, "bio", "una sección desconocida vuelve al laboratorio")
	m.free()


func test_el_interruptor_de_sonido_silencia_master_y_se_recuerda() -> void:
	var m := _new_main()
	assert_true(m.sound_on, "sin ajustes, con sonido")
	assert_false(AudioServer.is_bus_mute(0))
	m.toggle_sound()
	assert_false(m.sound_on)
	assert_true(AudioServer.is_bus_mute(0), "silencia el bus Master")
	assert_eq(_cfg("sound"), false, "se guarda en [app] sound")
	assert_eq(m.sound_button.text, "Silencio")
	assert_eq(m.ui_sound.played[-1][0], "off", "confirmación al silenciar, como en la 1.x")
	m.show_section("taller")
	m.free()
	var m2 := _new_main()
	assert_false(m2.sound_on, "al volver a abrir, sigue en silencio")
	assert_true(AudioServer.is_bus_mute(0))
	assert_eq(String(m2._setting("section", "")), "taller", "sección y sonido conviven en el mismo archivo")
	m2.toggle_sound()
	assert_true(m2.sound_on)
	assert_false(AudioServer.is_bus_mute(0))
	assert_eq(_cfg("sound"), true)
	assert_eq(m2.ui_sound.played[-1][0], "on")
	m2.free()


func test_la_demo_no_guarda_ajustes() -> void:
	var m := _new_main()
	m.remember = false
	m.show_section("taller")
	m.toggle_sound()
	assert_false(FileAccess.file_exists(CFG), "remember = false no escribe nada")
	m.toggle_sound()
	m.free()


func test_pie_y_creditos() -> void:
	var m := _new_main()
	var version := String(ProjectSettings.get_setting("application/config/version"))
	assert_eq(m.footer_label.text, m.footer_note(version), "pie con el nombre y la versión del programa")
	assert_true(AppInfo.license_note(version).begins_with(m.footer_label.text) and m.footer_label.text.ends_with("Licencia MIT"),
		"el pie es el principio de la nota de la licencia (la de las tipografías, en los créditos)")
	m.show_credits()
	var texts := PackedStringArray()
	for l in m.credits_overlay.content.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var all := "\n".join(texts)
	assert_true(all.contains(AppInfo.license_note(version)), "créditos: licencia del programa")
	assert_true(all.contains(AppInfo.PREVIOUS_NAME), "créditos: el nombre de la 1.x")
	assert_true(all.contains(Engine.get_license_text().substr(0, 40)), "créditos: licencia de Godot")
	var comps: Array = Engine.get_copyright_info()
	assert_true(comps.size() > 0 and all.contains(String(comps[0].name)), "créditos: componentes de Godot")
	for k: String in Engine.get_license_info():
		assert_true(all.contains(k), "créditos: licencia %s" % k)
	m.show_section("bio")
	m.toggle_fundamentos()
	var rich: Array = m.fund_overlay.content.find_children("*", "RichTextLabel", true, false)
	assert_eq(rich.size(), Lab.fundamentos().size(),
		"un párrafo por fundamento (los de la 1.x, los de los materiales y la biología de la 2.0 y el de los aguijones)")
	assert_true((rich[-1] as RichTextLabel).text.contains("Shergold"), "el último, el de los aguijones de la 2.0")
	assert_true(m.fund_overlay.visible)
	m.toggle_fundamentos()
	assert_false(m.fund_overlay.visible)
	m.free()
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)
	AudioServer.set_bus_mute(0, false)


## Petición 39: el botón «Dona o invítame» va con Fundamentos y Sonido, así que está en las dos secciones (y en el
## teléfono, en el pie); su hoja lleva el texto de Eric y un botón por enlace con url, que se abre fuera del programa.
func test_el_boton_de_donar_esta_en_las_dos_secciones() -> void:
	var m := _new_main()
	for id: String in ["bio", "taller"]:
		m.show_section(id)
		assert_true(m.donate_button.visible, "el botón de donar se ve en «%s»" % id)
		assert_true(m.actions.is_ancestor_of(m.donate_button), "va con Fundamentos y Sonido")
	assert_eq(m.donate_button.text, AppInfo.DONATE_BUTTON)
	assert_true(m.donate_button.icon != null, "con su icono de la taza")
	m.free()


func test_la_hoja_de_donar_lleva_el_texto_y_los_enlaces() -> void:
	var m := _new_main()
	var opened: Array = []
	m.link_opener = func(url: String) -> void: opened.append(url)
	m.show_donate()
	assert_true(m.donate_overlay.visible)
	var texts := PackedStringArray()
	for n: Node in m.donate_overlay.content.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var all := "\n".join(texts)
	assert_true(all.contains("Eric Valls Gramunt"), "el texto es el de Eric")
	assert_true(all.contains("FP Superior"), "con sus estudios")
	var row: Node = m.donate_overlay.content.find_child("Enlaces", true, false)
	assert_true(row != null, "la fila de los enlaces")
	var urls := PackedStringArray()
	for b: Node in row.get_children():
		urls.append(String(b.get_meta("url", "")))
	assert_eq(urls.size(), AppInfo.donate_links().size(), "un botón por enlace con url")
	for l: Dictionary in AppInfo.DONATE_LINKS:
		assert_true(String(l.url).begins_with("https://"), "%s: enlace seguro" % String(l.label))
	(row.get_child(0) as Button).pressed.emit()
	assert_eq(opened, [String(AppInfo.donate_links()[0].url)], "al pulsarlo se abre su enlace, fuera del programa")
	m.free()


func test_los_enlaces_de_donar_vacios_no_salen() -> void:
	var links := [{ "id": "a", "label": "A", "url": "https://a.example" }, { "id": "b", "label": "B", "url": "  " },
		{ "id": "c", "label": "C", "url": "" }]
	assert_eq(AppInfo.donate_links(links).size(), 1, "solo los que tienen url")
	var m := _new_main()
	m.fill_donate([])
	assert_true(m.donate_overlay.content.find_child("Enlaces", true, false) == null, "sin enlaces, solo el texto")
	m.free()


## Petición 40: el Taller industrial se marca como WIP en el selector (en el teléfono, con el nombre corto), con su aviso
## en la ayuda emergente; el laboratorio no.
func test_el_taller_va_marcado_como_wip() -> void:
	var m := _new_main()
	var taller: Button = m.selector.buttons["taller"]
	var bio: Button = m.selector.buttons["bio"]
	assert_eq(taller.text, "Taller industrial · WIP")
	assert_eq(taller.tooltip_text, AppInfo.WIP_NOTE)
	assert_false(bio.text.contains("WIP"), "la tribología no es WIP")
	m._label_sections(true)
	assert_eq(taller.text, "Taller · WIP", "en el teléfono, el nombre corto")
	m.free()


## Petición 41: la edad de Eric en el texto de las donaciones sale de su fecha de nacimiento (13-05-1994) y de la fecha
## del sistema: sube un año cada 13 de mayo, sin tocar nada.
func test_la_edad_de_eric_se_calcula_sola() -> void:
	assert_eq(AppInfo.age_on({ "year": 2026, "month": 10, "day": 4 }), 32, "el 04-10-2026 tiene 32 años")
	assert_eq(AppInfo.age_on({ "year": 2026, "month": 5, "day": 12 }), 31, "la víspera de su cumpleaños, uno menos")
	assert_eq(AppInfo.age_on({ "year": 2026, "month": 5, "day": 13 }), 32, "el día de su cumpleaños, uno más")
	assert_eq(AppInfo.age_on({ "year": 2027, "month": 5, "day": 12 }), 32)
	assert_eq(AppInfo.age_on({ "year": 2027, "month": 5, "day": 13 }), 33)
	assert_eq(AppInfo.age_on({ "year": 2028, "month": 1, "day": 1 }), 33)
	var text: Array = AppInfo.donate_text({ "year": 2026, "month": 10, "day": 4 })
	assert_true(String(text[0]).contains("tengo 32 años"), "la edad en el primer párrafo")
	var all := "\n".join(PackedStringArray(text))
	assert_false(all.contains("{edad}"), "sin la marca sin rellenar")
	assert_true(all.contains("aves") and all.contains("felinos") and all.contains("cursos de cetrería") and all.contains("montaña"),
		"sus aficiones: los animales, la cetrería y la montaña")
	var m := _new_main()
	m.today_override = { "year": 2030, "month": 6, "day": 1 }
	m.show_donate()
	var labels := PackedStringArray()
	for n: Node in m.donate_overlay.content.find_children("*", "Label", true, false):
		labels.append((n as Label).text)
	assert_true("\n".join(labels).contains("tengo 36 años"), "la hoja usa la fecha del día")
	m.free()


## Petición 50: el botón «Gráficos» del pie (en escritorio) abre una hoja con el renderizador de ahora y las dos
## opciones; elegir la otra la guarda para el próximo arranque y enciende «Reiniciar ahora».
func test_elegir_el_renderizador() -> void:
	const GFX := "user://test_graficos_p50.cfg"
	if FileAccess.file_exists(GFX):
		DirAccess.remove_absolute(GFX)
	var m := _new_main()
	m.renderer_path = GFX
	var restarts := [0]
	m.restarter = func() -> void: restarts[0] += 1
	assert_true(m.graphics_button != null and m.graphics_button.get_parent() == m.foot, "el botón, en el pie del escritorio")
	m.show_graphics()
	assert_true(m.graphics_overlay.visible, "la hoja se abre")
	var now := RendererChoice.current()
	assert_eq(m.graphics_picker.value, now, "sin nada guardado, marca el de ahora")
	assert_false(m.restart_button.visible, "con el de ahora no hace falta reiniciar")
	var other := "opengl" if now == "vulkan" else "vulkan"
	(m.graphics_picker.buttons[other] as Button).emit_signal("pressed")
	assert_eq(RendererChoice.saved(GFX), other, "la elección se guarda para el arranque")
	assert_true(m.restart_button.visible and m.graphics_note.text.contains("reiniciar"), "y pide reiniciar")
	m.restart_button.emit_signal("pressed")
	assert_eq(restarts[0], 1, "«Reiniciar ahora» reinicia")
	var cfg := ConfigFile.new()
	cfg.load(GFX)
	assert_eq(String(cfg.get_value("rendering", RendererChoice.METHOD_KEY)), "gl_compatibility" if other == "opengl" else "forward_plus",
		"en la clave que lee Godot (rendering/renderer/rendering_method)")
	m.free()
	DirAccess.remove_absolute(GFX)
	# el archivo es el que lee Godot al arrancar
	assert_eq(String(ProjectSettings.get_setting("application/config/project_settings_override")), RendererChoice.OVERRIDE_PATH,
		"project.godot lee la elección al arrancar")


## 4q: la barra de arriba no corta el nombre del programa ni el titular de ninguna página, ni en escritorio (de 1000 a
## 1600 px de ancho) ni en el teléfono (360 y 390 px); en escritorio va en una sola fila desde 1240 px, con el pie en una
## línea; en el teléfono, lo que se pulsa en el pie mide al menos 44 px de alto; y la hoja de créditos cabe en la pantalla,
## con «Cerrar» a la vista.
func test_la_barra_no_corta_el_nombre_ni_el_titular() -> void:
	for w: int in [1600, 1240, 1000, 390, 360]:
		var vp := SubViewport.new()
		vp.size = Vector2i(w, 880)
		add_to_tree(vp)
		var m: Control = Main.instantiate()
		m.remember = false
		m.settings_path = CFG
		vp.add_child(m)
		await wait_frames(3)
		var lab: Control = m.pages["bio"]
		for id: String in lab.HEADLINES:
			lab.set_page(id, false)
			await wait_frames(3)
			_assert_bar_fits(m, "%d px · %s" % [w, id])
		var phone := w < int(m.NARROW)
		if w >= 1240:
			assert_true(m.topbar.is_row, "%d px: la barra en una fila" % w)
			assert_eq(m.footer_label.get_line_count(), 1, "%d px: el pie en una línea" % w)
		if phone:
			for b: Control in [m.fund_button, m.sound_button, m.donate_button, m.credits_button]:
				assert_true(b.size.y >= m.TOUCH_MIN - 0.5, "%d px: «%s» se pulsa con el dedo (%s px de alto)" % [w, b.tooltip_text if b.tooltip_text != "" else (b as Button).text, b.size.y])
		m.show_credits()
		await wait_frames(3)
		var sheet: Rect2 = m.credits_overlay.sheet.get_global_rect()
		var close: Rect2 = m.credits_overlay.close_button.get_global_rect()
		assert_true(sheet.position.x >= -0.5 and sheet.end.x <= w + 0.5, "%d px: la hoja de créditos cabe (%s)" % [w, sheet])
		assert_true(close.end.x <= w + 0.5, "%d px: «Cerrar» a la vista (%s)" % [w, close])
		m.credits_overlay.close()
		if m.graphics_button != null:  # la hoja de gráficos (en el teléfono, con «Vulkan» y «OpenGL» a secas) cabe
			m.renderer_path = "user://test_graficos_barra.cfg"
			m.show_graphics()
			await wait_frames(3)
			var gs: Rect2 = m.graphics_overlay.sheet.get_global_rect()
			assert_true(gs.position.x >= -0.5 and gs.end.x <= w + 0.5, "%d px: la hoja de gráficos cabe (%s)" % [w, gs])
			assert_eq((m.graphics_picker.buttons["opengl"] as Button).text, "OpenGL" if phone else "OpenGL · Compatibility")
			m.graphics_overlay.close()
		vp.remove_child(m)
		m.free()


func _assert_bar_fits(m: Control, where: String) -> void:
	var k: Label = m.kicker
	var h: Label = m.headline
	var kw := _text_w(k, k.text.to_upper())
	assert_true(kw <= k.size.x + 1.0, "%s: el nombre del programa entero (%d de %d px)" % [where, kw, k.size.x])
	if h.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var hw := _text_w(h, h.text)
		assert_true(hw <= h.size.x + 1.0, "%s: el titular «%s» entero (%d de %d px)" % [where, h.text, hw, h.size.x])
	else:
		assert_true(h.get_line_count() <= 2, "%s: el titular «%s» en una o dos líneas (%d)" % [where, h.text, h.get_line_count()])
		assert_true(h.size.y >= h.get_line_count() * 20.0, "%s: el titular se ve entero (%s px de alto)" % [where, h.size.y])
	var r: Rect2 = m.topbar.get_global_rect()
	assert_true(r.end.x <= m.size.x + 0.5, "%s: la barra no se sale de la pantalla (%s)" % [where, r])


static func _text_w(l: Label, text: String) -> float:
	return l.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x


## 4q: con una hoja abierta, Tab y Mayús + Tab dan la vuelta dentro de ella (antes se iban a los controles de la página
## de detrás), al cerrarla el foco vuelve a donde estaba, y una hoja corta (como «Gráficos») mide lo que su contenido.
func test_la_hoja_retiene_el_foco_y_mide_lo_que_su_contenido() -> void:
	var host := Control.new()
	host.theme = AppTheme.get_theme()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var behind := Button.new()
	behind.text = "Detrás"
	host.add_child(behind)
	var o := Overlay.new("Prueba")
	host.add_child(o)
	var inside: Array[Button] = []
	for t: String in ["Uno", "Dos"]:
		var b := Button.new()
		b.text = t
		o.content.add_child(b)
		inside.append(b)
	await wait_frames(2)
	behind.grab_focus()
	o.open()
	await wait_frames(3)
	var vp := host.get_viewport()
	assert_eq(vp.gui_get_focus_owner(), o.close_button, "al abrirse, el foco va a «Cerrar»")
	var order: Array = []
	for i in 6:
		_tab(false)
		await wait_frames(1)
		order.append(vp.gui_get_focus_owner())
	for f: Variant in order:
		assert_true(f is Control and o.sheet.is_ancestor_of(f), "Tab no sale de la hoja (%s)" % [f])
	assert_eq(order.slice(0, 3), [inside[0], inside[1], o.close_button], "da la vuelta en el orden de la hoja")
	_tab(true)
	await wait_frames(1)
	assert_eq(vp.gui_get_focus_owner(), inside[1], "Mayús + Tab, hacia atrás")
	assert_true(o.sheet.size.y < 300.0, "una hoja corta no se estira hasta abajo (%s px)" % o.sheet.size.y)
	o.close()
	await wait_frames(1)
	assert_eq(vp.gui_get_focus_owner(), behind, "al cerrarla, el foco vuelve a donde estaba")


func _tab(back: bool) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_TAB
		e.physical_keycode = KEY_TAB
		e.shift_pressed = back
		e.pressed = pressed
		tree().root.push_input(e)


## Al reiniciar se quitan los argumentos que forzarían otro renderizador (con su valor), y nada más.
func test_reiniciar_sin_forzar_el_renderizador() -> void:
	var args := PackedStringArray(["--path", "godot", "--rendering-driver", "opengl3", "--rendering-method=forward_plus", "--", "--escala=2"])
	assert_eq(Array(RendererChoice.restart_args(args)), ["--path", "godot", "--", "--escala=2"])
	assert_eq(RendererChoice.save("directx", "user://no.cfg"), ERR_INVALID_PARAMETER, "solo vulkan u opengl")
