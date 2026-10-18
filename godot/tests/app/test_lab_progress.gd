## Persistencia del laboratorio (CONTRATOS.md → «Ajustes»): los logros, el cuaderno y el número de ensayos se guardan en
## la sección [lab] del archivo de ajustes y se recuperan al abrir; «Reiniciar logros y cuaderno» los borra. Con un
## archivo temporal (nunca el de verdad).
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const Main = preload("res://app/main.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Lab = preload("res://core/lab/lab.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const CFG := "user://test_lab_progreso.cfg"


func before_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func _section(path := CFG) -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = path
	s.setup()
	s.art.threaded = false
	return s


## Un ensayo pulsando ARAÑAR y dejando correr el reloj.
func _run(s: Control) -> void:
	s.run_button.pressed.emit()
	s.step(0.0)
	s.step(LabState.RUN_MS + 200.0)


func _cfg(key: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return null
	return c.get_value("lab", key, null)


func test_progreso_ida_y_vuelta_en_el_estado() -> void:
	var a := LabState.new()
	a.set_claw(Catalog.find_by_id(Catalog.CLAWS, "gato"))
	for i in 3:
		a.run()
		a.advance(LabState.RUN_MS)
	var p := a.progress()
	assert_eq(p.count, 3)
	assert_true((p.badges as Array).has("depredador"))
	assert_eq((p.notebook as Array).size(), 3)
	var b := LabState.new()
	b.restore_progress(p)
	assert_eq(b.count, 3)
	assert_eq(b.badges.keys(), a.badges.keys(), "logros en el mismo orden")
	assert_true(same(b.notebook, a.notebook), "cuaderno")
	# un archivo viejo o editado a mano no rompe el banco: se descarta lo que no se entiende
	var c := LabState.new()
	var junk: Array = []
	for i in 8:
		junk.append({})
	c.restore_progress({
		"badges": ["depredador", "no-existe", 7, "vidrio"],
		"notebook": [{ "id": 12, "tool": "Garra de gato", "tgt": "Piel", "verdict": "ARAÑAZO", "col": "#E6B450" }, "basura",
			{ "id": 13, "tool": 1 }, { "id": 11.0, "tool": "Uña", "tgt": "Vidrio", "verdict": "NO RAYA", "col": "#5BE0C8" }] + junk,
		"count": -4,
	})
	assert_eq(c.badges.keys(), ["depredador", "vidrio"], "solo los logros que existen")
	assert_eq(c.notebook.size(), 2, "solo las entradas completas")
	assert_eq(c.count, 12, "al menos tantos ensayos como dice el cuaderno")
	var entry := { "id": 5, "tool": "Uña", "tgt": "Vidrio", "verdict": "NO RAYA", "col": "#5BE0C8" }
	var odd: Array = []
	for over: Dictionary in [{ "id": NAN }, { "id": 1e30 }, { "id": 0 }, { "id": -3 }, { "col": "violeta chillón" }]:
		var e := entry.duplicate()
		e.merge(over, true)
		odd.append(e)
	c.restore_progress({ "notebook": odd + [entry] })
	assert_eq(c.notebook, [entry], "números de ensayo imposibles y colores que no son colores: fuera")
	assert_eq(c.count, 5)
	c.restore_progress({ "badges": "x", "notebook": 3, "count": "mucho" })
	assert_eq([c.badges.size(), c.notebook.size(), c.count], [0, 0, 0], "tipos equivocados: nada")
	c.run()
	assert_eq(c.run_seq, 1, "run_seq cuenta los ensayos de la sesión")
	c.reset_progress()
	assert_eq([c.badges.size(), c.notebook.size(), c.count], [0, 0, 0], "reiniciar")
	assert_eq(c.run_seq, 1, "run_seq no se reinicia (identifica los ensayos en la interfaz)")


func test_la_seccion_guarda_y_recupera_el_progreso() -> void:
	var app := ConfigFile.new()
	app.set_value("app", "section", "bio")
	app.set_value("app", "sound", false)
	app.save(CFG)
	var s := _section()
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "gato"))
	for i in 2:
		_run(s)
	assert_eq(_cfg("count"), 2, "se guarda el número de ensayos")
	assert_true((_cfg("badges") as Array).has("depredador"), "y los logros")
	assert_eq((_cfg("notebook") as Array).size(), 2, "y el cuaderno")
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	assert_eq(cfg.get_value("app", "sound", null), false, "sin tocar la sección [app] del programa")
	var badges: Array = s.lab.badges.keys()
	var book: Array = s.lab.notebook
	s.free()
	var s2 := _section()
	assert_eq(s2.lab.count, 2, "al abrir, el número de ensayos")
	assert_eq(s2.lab.badges.keys(), badges, "los logros")
	assert_true(same(s2.lab.notebook, book), "el cuaderno")
	s2.refresh_now()
	# la cabecera cuenta los 15 de la 1.x; los de lo nuevo de la 2.0 llevan su contador (unidad 4p)
	var v1_ids := Lab.BADGES.map(func(b: Dictionary) -> String: return String(b.id))
	var v2_ids := Lab.BADGES_V2.map(func(b: Dictionary) -> String: return String(b.id))
	var got_v1 := badges.filter(func(id: String) -> bool: return v1_ids.has(id)).size()
	var got_v2 := badges.filter(func(id: String) -> bool: return v2_ids.has(id)).size()
	assert_eq(got_v1 + got_v2, badges.size(), "cada logro es de una de las dos listas")
	assert_eq(s2.badges_card.count.text, "%d/%d" % [got_v1, Lab.BADGES.size()], "la tarjeta enseña los logros recuperados")
	assert_eq(s2.badges_card.count_v2.text, "%d/%d" % [got_v2, Lab.BADGES_V2.size()], "y los de la 2.0, con su contador")
	assert_eq((s2.badges_card.book_rows[0][3] as Label).text, book[0].verdict, "y el cuaderno")
	_run(s2)
	assert_eq(_cfg("count"), 3, "sigue contando")
	assert_eq(s2.lab.notebook[0].id, 3, "ids del cuaderno sin repetir")
	s2.free()


func test_reiniciar_logros_y_cuaderno() -> void:
	var s := _section()
	s.refresh_now()
	var btn: Button = s.badges_card.reset_button
	assert_false(btn.visible, "sin nada que borrar, no se ofrece")
	_run(s)
	assert_true(btn.visible and btn.text == s.badges_card.RESET_TEXT, "con ensayos, se ofrece")
	btn.pressed.emit()
	s.step(0.0)
	assert_eq(s.lab.count, 1, "la primera pulsación no borra nada…")
	assert_eq(btn.text, s.badges_card.RESET_CONFIRM, "… pide confirmación")
	_run(s)
	assert_eq(btn.text, s.badges_card.RESET_TEXT, "otro ensayo cancela la confirmación")
	btn.pressed.emit()
	s.step(0.0)
	btn.pressed.emit()
	s.step(0.0)
	assert_eq([s.lab.count, s.lab.badges.size(), s.lab.notebook.size()], [0, 0, 0], "la segunda pulsación lo borra todo")
	assert_eq(_cfg("count"), 0, "y se guarda")
	assert_eq((_cfg("notebook") as Array).size(), 0)
	assert_false(btn.visible, "ya no hay nada que borrar")
	assert_false(s.badges_card.book_box.visible, "cuaderno vacío")
	# el ensayo siguiente se anima y se enseña como uno nuevo (run_seq, no count)
	_run(s)
	assert_true(s.result_card.details.visible, "el resultado del ensayo siguiente se enseña")
	assert_eq(s.result_card.bench.run_id, s.lab.run_seq, "el banco lo anima como uno nuevo")
	s.free()


func test_sin_archivo_de_ajustes_no_se_guarda_nada() -> void:
	var s := _section("")
	_run(s)
	assert_false(FileAccess.file_exists(CFG), "la sección suelta (tests, demo) no escribe nada")
	s.free()


func test_main_pasa_el_archivo_a_la_seccion() -> void:
	var m: Control = Main.instantiate()
	m.settings_path = CFG
	m.setup()
	m.show_section("bio")
	assert_eq(m.pages["bio"].settings_path, CFG, "el laboratorio guarda en el archivo del programa")
	m.free()
	var demo: Control = Main.instantiate()
	demo.settings_path = CFG
	demo.remember = false
	demo.setup()
	demo.show_section("bio")
	assert_eq(demo.pages["bio"].settings_path, "", "la demo (remember = false) no guarda nada")
	demo.free()
	_remove()
