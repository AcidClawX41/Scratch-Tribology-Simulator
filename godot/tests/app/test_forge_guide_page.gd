## El guiado botón a botón en la página y en la escena de la reforja (unidad 5x; app/common/guide_overlay.gd,
## forge_page.gd y forge_3d.gd). Invariantes:
##   - cada objetivo que señala el guiado en las diez recetas, la piedra, la garra viva, el acrílico y la soldadura existe: su
##     control en la página y su objeto en la escena 3D;
##   - con el tutorial, el control del panel se resalta con su etiqueta, el aviso sale sobre la vista y la cámara va a la vista
##     que toca; el panel se desplaza solo hasta el control y lo deja a la vista (en escritorio y en el teléfono);
##   - sin tutorial (o sin «Guiado»), nada: ni aviso, ni resaltado, ni la vista cambia sola.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const ForgePage = preload("res://app/lab/cetreria/forge_page.gd")
const Play = preload("res://tests/lab/forge_guide_play.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

const SCENE := "res://app/lab/cetreria/forge_3d.tscn"


## Todos los objetivos de los tutoriales jugados con el guiado (los de la página y los de la escena).
static func _all_targets() -> Array:
	var out: Array = []
	for rid: String in ForgeData.RECIPE_IDS:
		var st := Play.new_state("rapaz", "aguila", rid)
		out.append_array(Play.play(st, rid).seq)
		if rid in ["acero", "oro", "metal_duro"]:
			out.append_array(Play.play(st, State.WELD).seq)
	for tid: String in [State.GENERAL, State.STONE, State.LIVE]:
		var st2 := Play.new_state("rapaz", "aguila", "zafiro" if tid == State.GENERAL else tid)
		out.append_array(Play.play(st2, tid).seq)
	var broken := State.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "from_care": { "stump_mm": 20.0 } })
	broken.set_process(State.ACRYLIC)
	out.append_array(Play.play(broken, State.ACRYLIC).seq)
	return out


static func _page() -> ForgePage:
	var p := ForgePage.new()
	p.threaded = false
	p.setup()
	p.active = true
	return p


func test_cada_objetivo_existe_en_la_pagina_y_en_la_escena() -> void:
	var targets := _all_targets()
	assert_true(targets.size() > 500, "objetivos jugados: %d" % targets.size())
	var p := _page()
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	var scene_ids := {}
	for t: Dictionary in s.get("_targets"):
		scene_ids[String(t.id)] = true
	var panel_seen := {}
	var scene_seen := {}
	for g: Dictionary in targets:
		var pid := String(g.panel)
		if pid != "" and not panel_seen.has(pid):
			panel_seen[pid] = true
			assert_true(p.guide_node(pid) != null, "el control «%s» existe en la página (%s)" % [pid, String(g.label)])
		var sid := String(g.scene)
		if sid != "" and not scene_seen.has(sid):
			scene_seen[sid] = true
			assert_true(scene_ids.has(sid), "el objeto «%s» existe en la escena" % sid)
		assert_true(String(g.view) == "" or s.get("VIEWS").has(String(g.view)), "la vista «%s» existe" % String(g.view))
	# las acciones con su botón: cada orden del guiado es la que manda su control (los botones de la página)
	assert_true(p.guide_node("acabar") != null, "«Acabar ya», con la marcha en curso")
	for id: String in ["cargar", "meter", "arrancar", "enfriar", "pasada", "proteger", "pulir", "ajuste", "siguiente", "tara", "soldar_colocar", "soldar_recomendado"]:
		assert_true(panel_seen.has(id), "el guiado ha señalado «%s»" % id)
	assert_true(panel_seen.size() > 40, "controles distintos: %d" % panel_seen.size())
	p.dispose()
	p.free()


func test_sin_tutorial_no_hay_resaltado_ni_aviso_ni_la_vista_se_mueve() -> void:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var p := _page()
	host.add_child(p)
	p.size = host.size
	p.runner.post("set_process", ["metal_duro"])
	p.runner.post("set_tutorial", [true])
	p.runner.post("tutorial_goto", ["metal_duro"])
	await wait_frames(2)
	for i in 30:
		p.step(16.0)
	var inf: Dictionary = p.guide.info()
	assert_true(bool(inf.on), "con el tutorial, el guiado")
	assert_true(String(inf.label).begins_with("Pulsa aquí: +"), "la etiqueta del botón de dosis: %s" % String(inf.label))
	assert_true(String(inf.hint).begins_with("Ahora toca añadir"), "el aviso de la vista: %s" % String(inf.hint))
	assert_eq(p.view, "banco", "la vista va a la balanza")
	assert_eq(p.guide.panel_node, p.guide_node(String(p.runner.latest().guide.panel)), "el control resaltado es el del objetivo")
	p.runner.post("set_guide", [false])
	p.step(16.0)
	assert_false(bool(p.guide.info().on), "sin «Guiado», nada que pintar")
	assert_true(p.tut_text.visible and p.tut_text.text != "", "(el texto del paso sigue)")
	p.runner.post("set_guide", [true])
	p.runner.post("set_tutorial", [false])
	p.set_view("taller")
	p.step(16.0)
	for i in 10:
		p.runner.post("tick", [0.1])
		p.step(100.0)
	assert_false(bool(p.guide.info().on), "sin tutorial, nada")
	assert_eq(String(p.guide.info().hint), "", "ni aviso")
	assert_true(p.guide.panel_node == null, "ni resaltado")
	assert_eq(p.view, "taller", "ni la vista se mueve sola")
	assert_false(p.guide_toggle.visible, "(y el interruptor «Guiado» va dentro del tutorial)")
	p.dispose()


## Con fotogramas de verdad, en escritorio (1240 × 880) y en el teléfono (390 × 844): el panel baja solo hasta el control que
## toca y lo deja dentro de lo que se ve; el aviso, dentro de la vista.
func test_el_panel_se_desplaza_hasta_el_control_y_lo_deja_a_la_vista() -> void:
	for size: Vector2 in [Vector2(1240, 880), Vector2(390, 844)]:
		var where := "%dx%d" % [size.x, size.y]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		s.care_page.threaded = false
		s.set_page(s.PAGE_CARE, false)
		var cp: Control = s.care_page
		cp.open_lab()
		var p: ForgePage = cp.lab_page
		p.guide.reduce_motion = false
		p.runner.post("set_process", ["metal_duro"])
		p.runner.post("set_tutorial", [true])
		p.runner.post("set_speed", [State.SPEEDS.size() - 1])
		p.runner.post("tutorial_goto", ["metal_duro"])
		await wait_frames(3)
		# hasta los parámetros de la marcha, pulsando lo que señala: el dial del horno queda lejos de la balanza
		for n in 200:
			var g: Dictionary = p.runner.latest().guide
			if String(g.step) == "parametros":
				break
			p.runner.post(String(g.op), g.args)
			p.runner.post("skip")
			p.step(16.0)
		for id: String in ["mando:temp_c", "pulir"]:
			if id == "pulir":
				for n in 200:
					var g2: Dictionary = p.runner.latest().guide
					if String(g2.id) == "pulir" or not bool(g2.on):
						break
					p.runner.post(String(g2.op), g2.args)
					p.runner.post("skip")
					p.step(16.0)
			var g3: Dictionary = p.runner.latest().guide
			assert_eq(String(g3.id), id, "%s: el guiado señala «%s»" % [where, id])
			for f in 90:
				p.step(16.0)
				await wait_frames(1)
			var node: Control = p.guide_node(id)
			var nr := node.get_global_rect()
			var shown: Rect2 = p.guide.info().clip
			assert_true(shown.encloses(nr), "%s: «%s» queda a la vista (%s en %s)" % [where, id, nr, shown])
			assert_true(Rect2(p.guide.info().panel_rect).encloses(nr), "%s: y resaltado" % where)
			var tag: Rect2 = p.guide.info().tag_rect
			assert_true(tag.size.x > 0.0 and tag.position.x >= -0.5 and tag.end.x <= size.x + 0.5, "%s: la etiqueta, dentro de la pantalla (%s)" % [where, tag])
			assert_false(tag.intersects(nr.grow(-2.0)), "%s: la etiqueta no tapa el control" % where)
		# el aviso: dentro de la vista o, si no se ve (el teléfono con el panel bajado), en lo que se ve, sin tapar el control
		var hr: Rect2 = p.guide.info().hint_rect
		assert_true(hr.size.x > 0.0, "%s: hay aviso" % where)
		var seen: Rect2 = p.guide.info().clip
		assert_true(p.view_box.get_global_rect().grow(1.0).encloses(hr) or seen.grow(1.0).encloses(hr), "%s: el aviso, en la vista o en lo que se ve (%s)" % [where, hr])
		assert_false(hr.intersects(p.guide_node("pulir").get_global_rect()), "%s: el aviso no tapa el control" % where)
		host.visible = false
