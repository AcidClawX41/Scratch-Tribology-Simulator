## Unidad 5v en la página: aceptar un encargo de iniciación trae al animal y abre su tutorial; uno de minijuego enseña su
## objetivo, su barra y lo que falta; el animal que llega con la garra rota empieza roto; la garra que se rompe durante el
## encargo avisa de que pasa a «repararla».
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")


func _page() -> Array:
	var s: Control = LabSection.instantiate()
	s.settings_path = ""
	s.setup()
	s.page_bar.buttons[s.PAGE_CARE].pressed.emit()
	var page: Control = s.care_page
	page.progress = (load("res://core/lab/vet_progress.gd") as GDScript).new()
	return [s, page]


func _sync(page: Control) -> Dictionary:
	if page.runner.is_threaded():
		for i in 200:
			if page.runner.in_sync():
				break
			OS.delay_msec(5)
	page.call("refresh")
	page.call("_progress_check", page.runner.latest())
	return page.runner.latest()


func test_la_iniciacion_abre_su_tutorial() -> void:
	var h := _page()
	var page: Control = h[1]
	page.call("_progress_op", "accept", ["inic_preparar"])
	var v := _sync(page)
	assert_eq(String(v.setup.animal), "rapaz", "trae al águila")
	assert_true(bool(v.tutorial.on), "con el tutorial abierto")
	assert_eq(String(v.tutorial.process), "preparar", "en «Preparar al animal»")
	var card: Control = page.progress_card
	assert_true(String(card.active_card.text).contains("Preparar al animal"), "la ficha dice el tutorial: %s" % card.active_card.text)
	(h[0] as Node).free()


func test_el_minijuego_y_la_garra_rota() -> void:
	var h := _page()
	var page: Control = h[1]
	page.progress.best_level = 2
	page.call("_progress_op", "accept", ["rota_aguila"])
	var v := _sync(page)
	assert_true(bool(v.snap.damage.broken), "el águila llega con la garra rota")
	assert_eq(String(v.digit), "I", "y se trabaja la del talón")
	var card: Control = page.progress_card
	assert_true(card.mini_box.visible, "el minijuego, en la tarjeta")
	assert_true(String(card.mini_title.text).contains("Reparar"), "reparar: %s" % card.mini_title.text)
	assert_true(String(card.mini_text.text).begins_with("Falta"), "con lo que falta: %s" % card.mini_text.text)
	assert_true(String(card.active_card.text).contains("partida"), "la ficha dice cómo llega: %s" % card.active_card.text)
	# otro encargo sin la garra rota: el animal llega sano
	page.call("_progress_op", "accept", ["afilar_aguila"])
	var v2 := _sync(page)
	assert_false(bool(v2.snap.damage.broken), "el siguiente, sano")
	assert_eq(String(v2.setup.tip_start), "roma", "y con la punta roma con la que llega")
	assert_true(String(card.mini_title.text).contains("Transformar"), "transformar: %s" % card.mini_title.text)
	(h[0] as Node).free()


func test_romperla_avisa_de_repararla() -> void:
	var h := _page()
	var page: Control = h[1]
	page.call("_progress_op", "accept", ["coping_aguila"])
	page.call("_progress_op", "bring", ["coping_aguila"])
	_sync(page)
	# se rompe durante la operación: la garra seca, cortada justo por delante de la carne viva (oculta en el águila: la del
	# motor), se raja hasta ella
	var st: RefCounted = page.runner.state
	var quick := float(st.care.get("_s_quick"))
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	# (ahí la garra ya no cabe en el cortaúñas de guillotina: las tenazas)
	st.pick("tenaza")
	st.press_on(quick + 0.4)
	for i in 40:
		st.tick(1.0 / 30.0)
	st.release()
	page.runner.post("tick", [0.0])
	var v := _sync(page)
	if bool(v.snap.damage.broken):
		assert_true(page.progress_card.repair_label.visible, "la tarjeta avisa de «repararla»")
		assert_true(String(page.progress_card.repair_label.text).contains("repararla"), "y lo dice")
	else:
		var evs: Array = (v.snap.events as Array).map(func(e: Dictionary) -> String: return String(e.get("text", "")))
		assert_true(false, "el corte debía romperla (largo %s, carne viva %s, terminada %s, parada %s, avisos %s · %s)" % [v.snap.claw.lengthMm, quick, v.finished, v.halted, v.notice, evs])
	(h[0] as Node).free()
