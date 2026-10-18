## La tarjeta «Tu consulta de veterinario» de la cetrería (app/lab/cetreria/care_progress_card.gd y su bloque de care_page.gd,
## unidad 5u; petición 62): se ve en la página después del informe, con el nivel, la experiencia, los créditos y la lente de
## serie; aceptar un encargo y traer al animal mandan las órdenes; al terminar la consulta, el encargo se comprueba con el
## informe del motor (cumplido o por qué no) y se guarda; lo guardado se recupera en otra página; la tienda no vende sin nivel
## o sin créditos; un archivo roto no rompe la página (lo avisa); la sección guarda el progreso junto a los ajustes; los textos
## se leen (sin nombres internos) y la tarjeta cabe en el teléfono.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const CarePage = preload("res://app/lab/cetreria/care_page.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const VetProgress = preload("res://core/lab/vet_progress.gd")
const Card = preload("res://app/common/card.gd")

const CFG := "user://test_care_progress.cfg"
const SETTINGS := "user://test_care_progress_ajustes.cfg"
const BAD := "docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawForge|ForgeData|SRC_|\\bunidad [0-9]|\\b[a-z0-9]+_[a-z0-9_]+\\b"


func before_each() -> void:
	for f: String in [CFG, CFG + ".roto", SETTINGS, "user://cetreria.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


static func _page(path := "") -> CarePage:
	var p := CarePage.new()
	p.threaded = false
	p.setup()
	if path != "":
		p.set_progress_path(path)
	return p


static func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


## Una consulta bien hecha con la rapaz (encapuchada y envuelta, el sobrante limado con una faceta que sigue la curva y la
## punta rematada) y «Terminar»: como en tests/lab/test_claw_care.gd, sobre el estado de la página.
static func _good_session(p: CarePage) -> void:
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	var c := st.care
	var alpha := c.tip_alpha_deg()
	var over := c.overgrowth_left_mm()
	var strokes := 0
	while c.overgrowth_left_mm() > 0.05 * over and strokes < 300:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
	var taps := 0
	while float(c.tip_state().ratio) < 0.5 and taps < 50:
		c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
		taps += 1
	c.apply({ "tool": "crema" })
	p.runner.post("finish")
	p.refresh()


func test_la_tarjeta_en_la_pagina() -> void:
	var p := _page()
	var c := p.progress_card
	assert_true(c != null and c.get_parent() == p.right, "la tarjeta, en la columna de las tarjetas")
	assert_eq(c.get_index(), p.report_card.get_index() + 1, "justo después del informe")
	assert_true(c.level_label.text.begins_with("Nivel 1"), "nivel 1: %s" % c.level_label.text)
	assert_eq(c.credits_label.text, "0 créditos", "sin créditos")
	assert_true(c.lens_label.text.contains("Plástico") and c.lens_label.text.contains("sin rayones"), "la lente de serie: %s" % c.lens_label.text)
	assert_false(c.jobs_box.visible or c.shop_box.visible, "la lista y la tienda, plegadas")
	assert_false(c.active_box.visible, "sin encargo en curso")
	c.jobs_toggle.pressed.emit()
	assert_true(c.jobs_box.visible, "se abre la lista")
	assert_true(c.jobs_toggle.text.begins_with("Encargos (0 de "), "cuántos hay hechos: %s" % c.jobs_toggle.text)
	assert_true(c.buttons.has("encargo:coping_aguila"), "el coping del águila se puede aceptar")
	assert_false(c.buttons.has("encargo:tigre_anestesia"), "el tigre pide el nivel 3: sin botón")
	p.dispose()
	p.free()


func test_aceptar_traer_terminar_y_cobrar() -> void:
	var p := _page(CFG)
	var c := p.progress_card
	c.set_open("jobs", true)
	(c.buttons["encargo:coping_aguila"] as Button).pressed.emit()
	assert_eq(p.progress.active_job, "coping_aguila", "aceptado")
	assert_true(c.active_box.visible and c.active_title.text.contains("El arreglo de las garras del águila"), "en curso: %s" % c.active_title.text)
	assert_true(c.active_asks.get_child_count() >= 3, "con lo que pide")
	# traer al animal: una consulta nueva con el águila
	p.runner.post("configure", [{ "animal": "tigre" }])
	p.refresh()
	c.bring_button.pressed.emit()
	p.refresh()
	assert_eq(String(p.runner.latest().setup.animal), "rapaz", "trae la rapaz")
	assert_eq(String(p.runner.latest().setup.claw), "aguila", "el águila del encargo")
	_good_session(p)
	assert_eq(p.progress.job_state("coping_aguila"), "hecho", "cumplido con el informe de la consulta")
	assert_true(c.result_box.visible and c.result_title.text.begins_with("Encargo cumplido"), "y lo dice: %s" % c.result_title.text)
	assert_true(p.progress.xp > 0 and p.progress.credits > 0, "cobrado: %d de experiencia y %d créditos" % [p.progress.xp, p.progress.credits])
	assert_true(c.xp_meter.value > 0.0, "la barra de la experiencia se llena")
	assert_false(c.active_box.visible, "sin encargo en curso")
	# otra vez la misma vista: no se cobra dos veces
	var xp1 := p.progress.xp
	p.refresh()
	p.refresh()
	assert_eq(p.progress.xp, xp1, "la misma consulta, una vez")
	# guardado: otra página con la misma ruta lo recupera
	assert_true(FileAccess.file_exists(CFG), "guardado en su archivo")
	var q := _page(CFG)
	assert_eq(q.progress.xp, xp1, "la experiencia, recuperada")
	assert_eq(q.progress.job_state("coping_aguila"), "hecho", "el encargo hecho, también")
	assert_eq(q.progress_card.level_label.text, c.level_label.text, "el mismo nivel en la tarjeta")
	for x: CarePage in [p, q]:
		x.dispose()
		x.free()


func test_si_sale_mal_dice_por_que() -> void:
	var p := _page()
	p.progress.accept("coping_aguila")
	p.refresh()
	var st: State = p.runner.state
	st.set_sedation("sujecion")
	st.care.call("_cut_to", st.care.apex_mm() - (st.care.quick_cover_mm() + 0.5))
	st.care.hemostasis({ "tool": "hemostatico", "pressure_s": 400.0 })
	p.runner.post("finish")
	p.refresh()
	var c := p.progress_card
	assert_eq(p.progress.job_state("coping_aguila"), "en_curso", "no se cumple: sigue en curso")
	assert_true(c.result_title.text.begins_with("Aún no"), "lo dice: %s" % c.result_title.text)
	var why := false
	for l: Node in c.result_items.get_children():
		if l is Label and (l as Label).text.begins_with("✗") and (l as Label).text.contains("sangró"):
			why = true
	assert_true(why, "y el porqué de lo que no se cumple")
	p.dispose()
	p.free()


func test_la_tienda_no_vende_sin_nivel_ni_creditos() -> void:
	var p := _page()
	var c := p.progress_card
	c.set_open("shop", true)
	var b: Button = c.buttons["lente:vidrio"]
	assert_true(b.disabled, "el vidrio, sin el nivel 2: el botón apagado")
	var shown := false
	for n: Node in c.shop_box.find_children("*", "Label", true, false):
		if (n as Label).text.contains("Pide el nivel 2"):
			shown = true
	assert_true(shown, "y dice por qué")
	# con el nivel y los créditos: se compra, se pone y la tarjeta lo dice
	p.progress.best_level = 2
	p.progress.credits = 200
	p.progress.serial += 1
	p.refresh()
	b = c.buttons["lente:vidrio"]
	assert_false(b.disabled, "ahora sí")
	b.pressed.emit()
	assert_eq(p.progress.lens_on, "vidrio", "comprada y puesta")
	assert_true(c.lens_label.text.contains("Vidrio"), "la tarjeta: %s" % c.lens_label.text)
	assert_eq(p.progress.credits, 200 - int(VetProgress.LENS_SHOP.vidrio.price), "cobrada")
	(c.buttons["lente:plastico"] as Button).pressed.emit()
	assert_eq(p.progress.lens_on, "plastico", "volver a la de plástico, sin pagar")
	p.dispose()
	p.free()


## La lente comprada se monta en la cetrería (5t-A) y sus rayones se guardan con el progreso y vuelven al recuperarlo; la tienda
## enseña la ficha de cada lente de la cetrería (qué es, su dureza y qué la raya) con su fuente.
func test_la_lente_va_a_la_cetreria_y_sus_rayones_se_guardan() -> void:
	var p := _page(CFG)
	p.progress.best_level = 2
	p.progress.credits = 200
	p.progress.serial += 1
	p.refresh()
	p.progress_card.set_open("shop", true)
	(p.progress_card.buttons["lente:vidrio"] as Button).pressed.emit()
	p.refresh()
	assert_eq(String(p.runner.latest().lens.lens), "vidrio", "la cetrería lleva puesta la de vidrio")
	var st: State = p.runner.state
	st.lens.add_scratch("rayon", [[0.2, 0.3], [0.5, 0.6]], 40.0, 4.0, "III", "zafiro")
	st.lens.serial += 1
	p.runner.post("tick", [0.0])
	p.runner.post("lens_clean")
	p.refresh()
	assert_true(p.progress.obscuration("vidrio") > 0.0, "el rayón se guarda en el progreso (%s)" % p.progress.obscuration("vidrio"))
	assert_true(p.progress_card.lens_label.text.contains("rayada"), "y la tarjeta lo dice: %s" % p.progress_card.lens_label.text)
	var q := _page(CFG)
	assert_eq(String(q.runner.latest().lens.lens), "vidrio", "otra página: la misma lente")
	assert_eq((q.runner.latest().lens.scratches as Array).size(), 1, "con su rayón")
	var info := false
	for n: Node in q.progress_card.shop_box.find_children("*", "Label", true, false):
		if (n as Label).text.contains("La rayan:") or (n as Label).text.contains("No la raya"):
			info = true
	q.progress_card.set_open("shop", true)
	assert_true(info, "la tienda con la ficha de cada lente")
	for x: CarePage in [p, q]:
		x.dispose()
		x.free()


## La tienda tiene su propio botón arriba de la vista, junto al de la reforja (fuera de la tarjeta y del panel de las
## herramientas y las garras); con la lente que ya no deja ver, el botón se pone en rojo, la tienda se abre sola una vez y lo
## dice, y «Empezar el juego de nuevo» pide confirmación antes de dejarlo todo como la primera vez.
func test_la_tienda_tiene_su_boton_y_se_puede_empezar_de_nuevo() -> void:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var p := _page(CFG)
	host.add_child(p)
	p.plug_reforge_lab()
	assert_true(p.mode_row.get_parent() == p.left and p.left.get_child(0) == p.mode_row, "arriba de la vista")
	assert_true(p.shop_button.get_parent() == p.mode_row and p.lab_switch.get_parent() == p.mode_row, "junto al de la reforja")
	assert_false(p.progress_card.is_ancestor_of(p.shop_button), "fuera de la tarjeta")
	assert_true(p.shop_button.text.contains("créditos"), "con los créditos: %s" % p.shop_button.text)
	p.shop_button.pressed.emit()
	assert_true(p.progress_card.shop_overlay.visible and p.progress_card.shop_box.visible, "abre la hoja de la tienda")
	p.progress_card.shop_overlay.close()
	# la lente que ya no deja ver
	p.progress.xp = 30
	p.progress.credits = 3
	var st: State = p.runner.state
	for i in 80:
		st.lens.add_scratch("desgarro", [[0.0, 0.0125 * i], [1.0, 0.0125 * i]], 2000.0, 1500.0)
	st.lens.serial += 1
	p.runner.post("tick", [0.0])
	p.runner.post("lens_clean")
	p.refresh()
	assert_true(p.progress.blind(), "la lente rayada de la cetrería ya no deja ver (%s)" % p.progress.obscuration("plastico"))
	assert_true(p.shop_button.text.contains("rayada"), "el botón lo dice: %s" % p.shop_button.text)
	assert_true(p.progress_card.shop_overlay.visible, "y la tienda se abre sola")
	assert_true(p.progress_card.blind_box.visible and p.progress_card.blind_label.text.contains("de nuevo"), "con el aviso arriba: %s" % p.progress_card.blind_label.text)
	p.progress_card.shop_overlay.close()
	p.progress.serial += 1
	p.refresh()
	assert_false(p.progress_card.shop_overlay.visible, "solo una vez (cerrada, no vuelve a abrirse sola)")
	# empezar de nuevo, con confirmación
	p.shop_button.pressed.emit()
	p.progress_card.restart_button.pressed.emit()
	assert_eq(p.progress.xp, 30, "la primera pulsación solo pide confirmación")
	assert_true(p.progress_card.restart_warn.visible and p.progress_card.restart_button.text.begins_with("Sí"), "y lo pregunta: %s" % p.progress_card.restart_warn.text)
	p.progress_card.restart_button.pressed.emit()
	assert_eq([p.progress.xp, p.progress.credits, p.progress.lens_on], [0, 0, "plastico"], "la segunda, juego nuevo")
	assert_false(p.progress.blind(), "con la lente nueva")
	assert_false(p.shop_button.text.contains("rayada"), "el botón vuelve a la tienda: %s" % p.shop_button.text)
	assert_eq((p.runner.latest().lens.scratches as Array).size(), 0, "la cetrería, con la lente sin rayones")
	var q := _page(CFG)
	assert_eq(q.progress.xp, 0, "y se ha guardado así")
	q.dispose()
	q.free()
	# al salir de la página, la hoja se cierra (va en su propia capa)
	p.shop_button.pressed.emit()
	p.set_active(false)
	assert_false(p.progress_card.shop_overlay.visible, "al salir, cerrada")
	p.dispose()
	host.free()


func test_un_archivo_roto_se_avisa() -> void:
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	f.store_string("esto no es un archivo de progreso [[[")
	f.close()
	var p := _page(CFG)
	var c := p.progress_card
	assert_true(c.notice_label.visible and c.notice_label.text.contains("dañado"), "la tarjeta lo avisa: %s" % c.notice_label.text)
	assert_true(c.level_label.text.begins_with("Nivel 1"), "y se empieza de cero")
	p.dispose()
	p.free()


func test_la_seccion_guarda_el_progreso_junto_a_los_ajustes() -> void:
	var s: Control = LabSection.instantiate()
	s.settings_path = SETTINGS
	s.setup()
	s.art.threaded = false
	assert_eq(String(s.care_page.progress_path), "user://cetreria.cfg", "junto a los ajustes: user://cetreria.cfg")
	s.free()
	var t: Control = LabSection.instantiate()
	t.setup()
	t.art.threaded = false
	assert_eq(String(t.care_page.progress_path), "", "sin ajustes (tests y demo), no se guarda")
	t.free()


func test_los_textos_se_leen() -> void:
	var p := _page()
	var c := p.progress_card
	c.set_open("jobs", true)
	c.set_open("shop", true)
	p.progress.accept("coping_aguila")
	p.progress.serial += 1
	p.refresh()
	_good_session(p)
	var re := RegEx.create_from_string(BAD)
	var nodes: Array = []
	_walk(c, nodes)
	var n := 0
	for x: Node in nodes:
		var texts: Array = []
		if x is Label:
			texts.append((x as Label).text)
		if x is Button:
			texts.append((x as Button).text)
		if x is Control:
			texts.append((x as Control).tooltip_text)
			texts.append(String((x as Control).accessibility_name))
		for t: String in texts:
			if t == "":
				continue
			n += 1
			var m := re.search(t)
			assert_true(m == null, "«%s» en «%s»" % [m.get_string() if m != null else "", t.substr(0, 140)])
		if x is BaseButton:
			assert_true(String((x as Control).accessibility_name) != "" or String((x as Button).text) != "", "%s con nombre" % x.name)
	assert_true(n > 60, "textos revisados: %d" % n)
	p.dispose()
	p.free()


func test_cabe_en_el_telefono() -> void:
	for size: Vector2 in [Vector2(390, 844), Vector2(1240, 880)]:
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		s.care_page.threaded = false
		s.set_page(s.PAGE_CARE, false)
		var p: CarePage = s.care_page
		p.progress_card.set_open("jobs", true)
		p.progress_card.set_open("shop", true)
		await wait_frames(4)
		var r := p.progress_card.get_global_rect()
		assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: la tarjeta dentro de la pantalla (%s)" % [size, r])
		assert_true(s.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [size, s.content.size.x])
		host.visible = false
