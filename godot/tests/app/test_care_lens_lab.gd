## La lente de la cámara también en la reforja (unidad 5tc; petición de Eric del 18-10): la lente rayada en la clínica se ve
## igual sobre la vista 3D de la reforja (la misma capa, lens_layer.gd, con la lente guardada del estado de la cetrería); la
## pastilla «Lente» va con la vista que se ve; con la reforja abierta el animal se queda en la clínica (su estrés y su
## reacción no avanzan); y el paño pasado en la reforja deja la misma lente limpia al volver.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const Lens = preload("res://core/lab/claw_care_lens.gd")

const MS := 1000.0 / 30.0


func _section() -> Control:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	s.settings_path = ""
	host.add_child(s)
	s.set_page(s.PAGE_CARE, false)
	var p: Control = s.care_page
	p.threaded = false
	await wait_frames(3)
	p.runner.stop_thread()
	return s


func test_la_lente_en_la_reforja() -> void:
	var s: Control = await _section()
	var p: Control = s.care_page
	# rayar la lente en la clínica: un rayón y una mancha de grasa
	var l := Lens.new("plastico")
	l.add_scratch("rayon", [[0.2, 0.3], [0.5, 0.6]], 30.0, 2.0, "II")
	l.add_smudge([[0.6, 0.6], [0.65, 0.62]], "III")
	p.runner.post("lens_load", [l.to_dict()])
	for i in 3:
		p.step(MS)
	var clinic: Node = (p.scene.call("reaction") as Node).get("lens")
	var ci: Dictionary = clinic.call("info")
	assert_eq([int(ci.scratches), int(ci.smudges)], [1, 1], "en la clínica, el rayón y la mancha")
	var an0: Dictionary = p.runner.latest().animal
	# abrir la reforja: la misma lente sobre su vista
	p.open_lab()
	for i in 3:
		p.step(MS)
	var lab_lens: Node = p.lab_lens
	assert_true(lab_lens != null, "la reforja tiene su capa de la lente")
	var li: Dictionary = lab_lens.call("info")
	assert_eq([int(li.scratches), int(li.smudges)], [1, 1], "con las mismas marcas")
	assert_true(bool(li.visible), "y se ve")
	assert_true(p.lens_box.get_parent() == p.lab_page.left and p.lens_box.get_index() == p.lab_page.view_box.get_index() + 1, "la pastilla de la lente va debajo de la vista de la reforja")
	# con la reforja abierta, el animal se queda en la clínica: ni estrés ni reacción
	for i in 90:
		p.step(MS)
	var an1: Dictionary = p.runner.latest().animal
	assert_eq(float(an1.get("stress", 0.0)), float(an0.get("stress", 0.0)), "su estrés no cambia")
	assert_eq(int((an1.get("reaction", {}) as Dictionary).get("seq", 0)), int((an0.get("reaction", {}) as Dictionary).get("seq", 0)), "y no hay reacciones")
	# el paño en la reforja
	p.clean_lens()
	for i in 40:
		p.step(MS)
	assert_eq((p.runner.latest().lens.smudges as Array).size(), 0, "el paño quita la mancha de la lente guardada")
	li = lab_lens.call("info")
	assert_eq([int(li.scratches), int(li.smudges)], [1, 0], "en la reforja: el rayón se queda y la mancha se va")
	# de vuelta a la clínica: la misma lente, limpia
	p.close_lab()
	for i in 3:
		p.step(MS)
	ci = clinic.call("info")
	assert_eq([int(ci.scratches), int(ci.smudges)], [1, 0], "en la clínica, la misma lente: limpia de manchas, con su rayón")
	assert_true(p.lens_box.get_parent() == p.left and p.lens_box.get_index() == p.view_box.get_index() + 1, "y la pastilla vuelve debajo de la vista de la clínica")


## La tienda desde la reforja (5tc, con el visto bueno del coordinador): el botón «Tienda de lentes» va junto al interruptor de
## la reforja (el mismo botón, con su texto y su accesibilidad), abre la misma hoja de la tienda, y la lente repuesta allí es
## la que se ve en la reforja y, al volver, en la clínica.
func test_la_tienda_desde_la_reforja() -> void:
	var s: Control = await _section()
	var p: Control = s.care_page
	var l := Lens.new("plastico")
	l.add_scratch("rayon_hondo", [[0.2, 0.3], [0.5, 0.6]], 120.0, 15.0, "II")
	l.add_scratch("rayon", [[0.3, 0.3], [0.6, 0.5]], 40.0, 3.0, "III")
	p.runner.post("lens_load", [l.to_dict()])
	for i in 3:
		p.step(MS)
	p.open_lab()
	for i in 3:
		p.step(MS)
	var row: Control = p.lab_page.mode_row
	assert_true(p.shop_button.get_parent() == row, "la tienda va junto al interruptor de la reforja")
	assert_true(p.shop_button.is_visible_in_tree(), "y se ve")
	assert_eq(String(p.shop_button.accessibility_name), "Tienda de lentes", "con su nombre accesible")
	assert_eq([int(p.lab_lens.call("info").scratches)], [2], "la lente rayada, en la reforja")
	p.shop_button.pressed.emit()
	assert_true(bool(p.progress_card.shop_overlay.visible), "abre la misma hoja de la tienda")
	# (repaso de la calle A) los nombres con sus siglas y la frase de la queratina una sola vez
	var glass := String(p._lens_info("vidrio").text)
	assert_true(glass.contains("(CZ)") and not glass.contains("(cz)"), "las siglas en mayúscula: %s" % glass)
	assert_eq(String(p._lens_info("plastico").text).count("queratina"), 1, "la queratina, una vez en la ficha del plástico")
	# reponer la de plástico (los créditos del juego, puestos a mano)
	p.progress.credits = 1000
	p._progress_op("buy", ["plastico"])
	for i in 3:
		p.step(MS)
	assert_eq((p.runner.latest().lens.scratches as Array).size(), 0, "la lente nueva, sin rayones, en el estado")
	assert_eq(int(p.lab_lens.call("info").scratches), 0, "y en la reforja")
	p.progress_card.set_open("shop", false)
	p.close_lab()
	for i in 3:
		p.step(MS)
	var clinic: Node = (p.scene.call("reaction") as Node).get("lens")
	assert_eq(int(clinic.call("info").scratches), 0, "de vuelta en la clínica, la misma lente nueva")
	assert_true(p.shop_button.get_parent() == p.mode_row, "y la tienda vuelve a su fila")
	assert_eq(p.shop_button.get_index(), p.lab_switch.get_index() + 1, "en su sitio, justo después del interruptor")
