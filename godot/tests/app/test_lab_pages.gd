## Páginas de la tribología biológica (app/lab/lab_section.gd): el banco de ensayo y el coche en marcha, cada una con su
## botón en la barra de arriba. Antes iban en la misma página y se amontonaban tarjetas y sonidos (Eric). Se comprueba
## qué se ve en cada una, que la que no se ve no calcula ni suena, el titular, el selector de animal del coche y que la
## página se recuerda en los ajustes (con un archivo temporal, nunca el de verdad).
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const CFG := "user://test_lab_paginas.cfg"


func before_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func _section(path := "") -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = path
	s.setup()
	s.art.threaded = false
	return s


func test_por_defecto_el_banco_y_el_coche_en_su_pagina() -> void:
	var s := _section()
	assert_eq(s.page, s.PAGE_BENCH, "abre en el banco de ensayo")
	assert_eq(s.page_bar.value, s.PAGE_BENCH, "la barra lo marca")
	for c: Control in [s.left_col, s.run_button, s.result_card, s.dual_card, s.compare_card, s.badges_card]:
		assert_true(c.visible, "en el banco se ve %s" % c.get_class())
	assert_false(s.moving_car_card.visible, "el coche en marcha, no: tiene su página")
	s.page_bar.buttons[s.PAGE_CAR].pressed.emit()
	assert_eq(s.page, s.PAGE_CAR, "el botón lleva al coche en marcha")
	assert_true(s.moving_car_card.visible, "se ve el coche")
	for c: Control in [s.left_col, s.run_button, s.result_card, s.dual_card, s.compare_card, s.badges_card]:
		assert_false(c.visible, "en el coche no se ve %s" % c.get_class())
	s.page_bar.buttons[s.PAGE_BENCH].pressed.emit()
	assert_true(s.result_card.visible and not s.moving_car_card.visible, "y se vuelve al banco")
	s.free()


func test_la_pagina_que_no_se_ve_no_calcula_ni_ensaya() -> void:
	var s := _section()
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "aguila"))
	s.step(16.0)
	# en el banco, el coche no se pinta aunque cambie el animal
	var paints: int = s.moving_car_card.paints
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
	s.step(16.0)
	s.step(16.0)
	assert_eq(s.moving_car_card.paints, paints, "en el banco, el coche en marcha no se repinta")
	# en el coche, ARAÑAR (y su atajo) no ensaya: el banco no suena ni avanza por detrás
	s.set_page(s.PAGE_CAR)
	s.step(16.0)
	assert_true(s.moving_car_card.paints > paints, "al abrir su página, el coche se pinta con el animal de ahora")
	var count: int = s.lab.count
	s.run()
	s.step(LabState.RUN_MS + 200.0)
	assert_eq(s.lab.phase, "idle", "en la página del coche no se lanza el ensayo del banco")
	assert_eq(s.lab.count, count, "ni cuenta un ensayo")
	# de vuelta en el banco, se pone al día y ensaya
	s.set_page(s.PAGE_BENCH)
	s.run()
	s.step(0.0)
	s.step(LabState.RUN_MS + 200.0)
	assert_eq(s.lab.count, count + 1, "en el banco sí ensaya")
	s.free()


func test_el_titular_sigue_a_la_pagina() -> void:
	var s := _section()
	var seen: Array = []
	s.headline_changed.connect(func(t: String) -> void: seen.append(t))
	assert_eq(s.headline(), "¿Qué raya a qué?", "el del banco")
	s.set_page(s.PAGE_CAR)
	assert_eq(s.headline(), "¿Aguanta encima del coche?", "el del coche en marcha")
	assert_eq(seen, ["¿Aguanta encima del coche?"], "y avisa a la barra del programa")
	s.set_page(s.PAGE_CAR)
	assert_eq(seen.size(), 1, "sin cambio de página, sin aviso")
	s.free()


## 4q: al entrar en el coche en marcha con la uña del arranque, la página salía vacía; ahora se elige el primer animal con
## datos (el águila), como al pulsar su píldora, y el banco pasa a esa garra.
func test_el_coche_se_abre_con_un_animal() -> void:
	var s := _section()
	assert_true(s.lab.claw == null, "al arrancar, una uña")
	s.set_page(s.PAGE_CAR)
	s.refresh_now()
	var card: Control = s.moving_car_card
	assert_eq(String(s.lab.claw.id), "aguila", "el primer animal con datos")
	assert_true(card.main_box.visible and not card.off_box.visible, "la tarjeta entera, no el aviso")
	s.set_page(s.PAGE_BENCH)
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "oso"))
	s.set_page(s.PAGE_CAR)
	assert_eq(String(s.lab.claw.id), "oso", "con un animal con datos, se respeta")
	s.free()


func test_el_coche_tiene_su_propio_selector_de_animal() -> void:
	var s := _section()
	s.set_page(s.PAGE_CAR)
	var card: Control = s.moving_car_card
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "oso"))
	s.refresh_now()
	assert_true(card.animal_box.visible, "el selector de animal se ve siempre")
	assert_true(card.main_box.visible, "con el oso, la tarjeta entera")
	for id: String in card.animal_pills:
		assert_eq((card.animal_pills[id] as Button).button_pressed, id == "oso", "%s marcado solo si es el elegido" % id)
	(card.animal_pills["aguila"] as Button).pressed.emit()
	s.refresh_now()
	assert_eq(String(s.lab.claw.id), "aguila", "el botón cambia de animal")
	assert_true((card.animal_pills["aguila"] as Button).button_pressed, "y lo marca")
	# con una uña (sin datos), el selector sigue arriba y el aviso dice que se elija ahí
	s.lab.set_claw(null)
	s.refresh_now()
	assert_true(card.animal_box.visible and card.off_box.visible and not card.main_box.visible, "sin animal: el aviso y el selector")
	assert_true(String(card.off_text.text).ends_with("Elige uno arriba, en «Animal»."), card.off_text.text)
	s.free()


func test_la_pagina_se_recuerda() -> void:
	var s := _section(CFG)
	s.set_page(s.PAGE_CAR)
	s.free()
	var c := ConfigFile.new()
	assert_eq(c.load(CFG), OK, "hay archivo de ajustes")
	assert_eq(c.get_value("lab", "page", ""), "coche", "guardada en [lab]")
	var t := _section(CFG)
	assert_eq(t.page, t.PAGE_CAR, "al abrir, la última página")
	assert_true(t.moving_car_card.visible and not t.result_card.visible, "con sus tarjetas")
	assert_eq(t.headline(), "¿Aguanta encima del coche?", "y su titular")
	t.free()
	_remove()
