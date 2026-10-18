## Cetrería 3D de cerca (unidad 5h, peticiones 35 a 37), sin ventana: la luz y los efectos de cada renderizador (los de
## Forward+ encendidos en el escritorio), la garra de cerca como vista de partida y la cámara que la sigue con suavidad
## y llega a la punta al milímetro; las patas en alta definición hechas para la cetrería (sin los modelos del coche), con
## sus dos niveles de detalle y sus anclajes; la sección de cada garra; la silueta de la forma sana; la superficie del
## motor en su textura; el trozo que cae al cortar; la garra del tigre que sale de su vaina; nada se crea en cada
## fotograma y el coste de un fotograma de la escena.
extends "res://tests/case.gd"

const SCENE := "res://app/lab/cetreria/care_3d.tscn"
const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CareStage = preload("res://app/lab/cetreria/care_stage.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const Js = preload("res://core/shared/js.gd")
const LabSection = preload("res://app/lab/lab_section.tscn")

const FRAME := 1.0 / 30.0
const VIEWPORT := Vector2i(800, 600)
## Presupuesto de un fotograma de la escena en el escritorio (ms de media de advance(), sin el dibujo): el del encargo.
const BUDGET_MS := 3.0


func _host(method := "", quality := "") -> Array:
	var vp := SubViewport.new()
	vp.size = VIEWPORT
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	s.set("render_method", method)
	s.set("quality", quality)
	vp.add_child(s)
	return [vp, s]


static func _runner(setup: Dictionary = {}) -> Runner:
	var r := Runner.new(setup)
	r.post("tick", [FRAME])
	return r


func _frame(s: Node3D, r: Runner, n := 1) -> void:
	for i in n:
		s.call("advance", FRAME)
		r.post("tick", [FRAME])
		s.call("show_view", r.latest())


func _mouse(s: Node3D, p: Vector2, button := -1, pressed := false) -> void:
	if button < 0:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		s.call("handle_pointer", mm)
		return
	var mb := InputEventMouseButton.new()
	mb.button_index = button as MouseButton
	mb.pressed = pressed
	mb.position = p
	s.call("handle_pointer", mb)


## Lo que se enciende en cada renderizador: en Forward+ (escritorio), SSAO, SSIL, el desenfoque del fondo, el brillo y la
## sonda de reflexión; en Mobile y Compatibility, los sustitutos baratos (la niebla que apaga el fondo y el viñeteado);
## el teléfono, sin sombras ni sonda.
func test_efectos_de_cada_renderizador() -> void:
	var fwd := CareStage.settings_for("forward_plus", false)
	for k in ["ssao", "ssil", "dof", "glow", "probe", "soft_shadows", "shadows", "fog", "three_point"]:
		assert_true(bool(fwd[k]), "Forward+ en el escritorio: %s" % k)
	for m: String in ["mobile", "gl_compatibility"]:
		var st := CareStage.settings_for(m, false)
		assert_false(bool(st.ssao) or bool(st.ssil) or bool(st.dof), "%s: sin SSAO, SSIL ni desenfoque" % m)
		assert_true(bool(st.fog) and float(st.vignette) > float(fwd.vignette), "%s: la niebla y más viñeteado" % m)
	var phone := CareStage.settings_for("mobile", true)
	assert_false(bool(phone.shadows) or bool(phone.probe), "el teléfono, sin sombras ni sonda")
	# la escena del escritorio con Forward+ los tiene encendidos de verdad (en el entorno y en la cámara)
	var h := _host("forward_plus")
	var s: Node3D = h[1]
	var r := _runner()
	s.call("show_view", r.latest())
	_frame(s, r, 2)
	var info: Dictionary = s.call("stage_info")
	for k in ["ssao", "ssil", "dof", "glow", "probe", "soft_shadows", "fog"]:
		assert_true(bool(info[k]), "la escena en Forward+: %s encendido" % k)
	assert_true(bool(info.probe_on_focus), "la sonda de la sala se refleja en la garra (5q: un metal pulido refleja la mesa)")
	assert_true(float(info.dof_far) > 0.0 and float(info.dof_far) < 0.6, "el desenfoque empieza detrás de la garra (%s m)" % Js.to_fixed(float(info.dof_far), 3))
	var h2 := _host("gl_compatibility")
	var s2: Node3D = h2[1]
	s2.call("show_view", r.latest())
	_frame(s2, r)
	var info2: Dictionary = s2.call("stage_info")
	assert_false(bool(info2.ssao) or bool(info2.dof), "en Compatibility, sin SSAO ni desenfoque")
	assert_true(bool(info2.fog) and float(info2.vignette) > 0.4, "y con la niebla y el viñeteado")
	var vig: TextureRect = s2.get("_vignette")
	assert_true(vig != null and vig.visible and vig.texture != null, "el viñeteado, encima de la vista")


## La vista de partida es la garra que se trabaja, de cerca: la garra ocupa buena parte de la vista; la cámara mira desde
## algo por encima.
func test_la_garra_de_cerca_es_la_vista_de_partida() -> void:
	for setup: Dictionary in [{ "animal": "rapaz" }, { "animal": "tigre" }, { "animal": "oso" }, { "animal": "velociraptor" }]:
		var h := _host()
		var s: Node3D = h[1]
		var r := _runner(setup)
		s.call("show_view", r.latest())
		_frame(s, r, 2)
		assert_eq(String(s.call("info").view), "garra", "%s: la vista de partida es la garra" % setup.animal)
		var apex: float = r.state.care.apex_mm()
		var a: Vector2 = s.call("claw_screen_point", apex * 0.05, 0.0, 0.0)
		var b: Vector2 = s.call("claw_screen_point", apex, 0.0, 0.0)
		var frac := a.distance_to(b) / float(VIEWPORT.y)
		assert_true(frac > 0.3, "%s: la garra de cerca (%s de la altura de la vista)" % [setup.animal, Js.to_fixed(frac, 2)])
		var cam := s.call("camera") as Camera3D
		var mid: Vector3 = s.call("_claw_mid_world")
		assert_true(cam.global_position.y > mid.y, "%s: la cámara, por encima de la garra" % setup.animal)
		(h[0] as Node).queue_free()


## La página crea la escena 3D antes de colocarse, cuando aún es estrecha: en el escritorio, la escena tiene que salir con
## la calidad del escritorio (antes salía la del teléfono: sin el primer plano, sin sombras ni sonda) y en el teléfono,
## con la suya; al cambiar el ancho, la calidad lo sigue.
func test_la_pagina_crea_la_escena_con_la_calidad_de_su_ancho() -> void:
	for c: Array in [[Vector2i(1240, 880), ""], [Vector2i(390, 844), "movil"]]:
		var vp := SubViewport.new()
		vp.size = c[0]
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_to_tree(vp)
		var host := Control.new()
		host.size = Vector2(c[0] as Vector2i)
		vp.add_child(host)
		var sec: Control = LabSection.instantiate()
		host.add_child(sec)
		await wait_frames(2)
		var page: Control = sec.care_page
		page.threaded = false
		sec.set_page(sec.PAGE_CARE, false)
		var where := "%dx%d" % [(c[0] as Vector2i).x, (c[0] as Vector2i).y]
		assert_true(page.scene != null, "%s: la escena se crea al enseñar la página" % where)
		assert_eq(String(page.scene.get("quality")), String(c[1]), "%s: con la calidad de su ancho desde el principio" % where)
		await wait_frames(3)
		assert_eq(String(page.scene.get("quality")), String(c[1]), "%s: y ya colocada, la misma" % where)
		assert_eq(bool(page.scene.call("is_mobile")), String(c[1]) == "movil", "%s: el teléfono, solo en el estrecho" % where)
		vp.queue_free()


## Al cambiar de garra, la cámara va a la nueva con una transición suave (no de golpe); la rueda sobre la punta acerca
## hasta unos milímetros y lo que se enfoca va hacia la punta.
func test_la_camara_sigue_a_la_garra_y_llega_a_la_punta() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "rapaz", "seed": "camara" })
	s.call("show_view", r.latest())
	_frame(s, r, 30)
	var rig: Node = s.get("_rig")
	r.post("select_claw", ["izquierda", "II"])
	_frame(s, r, 2)
	var mid: Vector3 = s.call("_claw_mid_world")
	var t0: Vector3 = rig.get("target")
	assert_true(t0.distance_to(mid) > 0.01, "justo después, la cámara aún va de camino (%s m)" % Js.to_fixed(t0.distance_to(mid), 3))
	_frame(s, r, 60)
	var t1: Vector3 = rig.get("target")
	assert_true(t1.distance_to(s.call("_claw_mid_world")) < 0.006, "y llega a la garra nueva (%s m)" % Js.to_fixed(t1.distance_to(s.call("_claw_mid_world")), 4))
	# la rueda sobre la punta
	var apex: float = r.state.care.apex_mm()
	for i in 40:
		var p: Vector2 = s.call("claw_screen_point", apex - 0.6, 0.0, 0.0)
		_mouse(s, p)
		_frame(s, r)
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = p
		s.call("handle_pointer", wheel)
		_frame(s, r)
	var cam := s.call("camera") as Camera3D
	var tip: Vector3 = s.call("_tip_world")
	var dist := cam.global_position.distance_to(rig.get("target"))
	assert_true(dist <= 0.0101, "la rueda acerca hasta unos milímetros (%s m)" % Js.to_fixed(dist, 4))
	assert_true((rig.get("target") as Vector3).distance_to(tip) < 0.004, "mirando a la punta (%s m)" % Js.to_fixed((rig.get("target") as Vector3).distance_to(tip), 4))
	assert_true(cam.near < 0.001, "el plano cercano se acerca con la cámara (%s m)" % Js.to_fixed(cam.near, 4))


## Las patas son las de la cetrería (sin el modelo del coche): una por pata de cada animal, con su nodo para cada garra,
## su anclaje (donde se engancha el cuerpo) y dos niveles de detalle en el escritorio (uno en el teléfono).
func test_patas_propias_con_anclajes_y_niveles_de_detalle() -> void:
	for q: String in ["", "movil"]:
		var h := _host("", q)
		var s: Node3D = h[1]
		for a: String in ["rapaz", "tigre", "oso", "velociraptor"]:
			var r := _runner({ "animal": a })
			s.call("show_view", r.latest())
			_frame(s, r)
			var rig: Dictionary = s.get("_paw")
			var what := "%s %s" % [a, "teléfono" if q == "movil" else "escritorio"]
			assert_true(rig.a3d == null, "%s: sin el modelo del coche en marcha" % what)
			var paws := State.paws_of(a)
			assert_eq((rig.anchors as Dictionary).size(), paws.size(), "%s: un anclaje por pata" % what)
			for p: String in paws:
				var an: Transform3D = rig.anchors[p]
				var c: Vector3 = rig.paws[p]
				assert_true(an.origin.distance_to(c) > 0.02, "%s: el anclaje de %s, separado de la pata" % [what, p])
				assert_true(an.basis.x.dot(c - an.origin) > 0.0, "%s: el anclaje de %s mira hacia la pata" % [what, p])
				var pn: Node3D = rig.paw_nodes[p].node
				var hi := 0
				var lo := 0
				for ch in pn.get_children():
					if ch is MeshInstance3D:
						var mi := ch as MeshInstance3D
						if String(mi.name).ends_with("_hi"):
							hi += 1
							assert_true(mi.visibility_range_end > 0.0, "%s: el nivel de primer plano solo de cerca" % what)
						elif String(mi.name).ends_with("_lo"):
							lo += 1
						# el pelo y las plumas: con pocas capas (el teléfono, el nivel ligero), en mechones
						var sm := mi.material_override as ShaderMaterial
						if sm != null and sm.get_shader_parameter("mass") != null:
							var lod := "movil" if q == "movil" else ("hi" if String(mi.name).ends_with("_hi") else "lo")
							assert_near(float(sm.get_shader_parameter("mass")), float(CarePaw.FUR_MASS[lod]), 0.0, 1e-6,
								"%s: el pelo de %s, en mechones según sus capas" % [what, mi.name])
				assert_true(lo > 0, "%s: el nivel ligero de %s" % [what, p])
				assert_true((hi > 0) == (q == ""), "%s: el de primer plano solo en el escritorio (%d)" % [what, hi])
			for d: String in State.digit_ids(a):
				for p: String in paws:
					assert_true((rig.slots as Dictionary).has(State.slot_key(p, d)), "%s: el sitio de la garra %s|%s" % [what, p, d])
		# la página pone la calidad antes de añadir la escena: el indicador de la forma, compacto en el teléfono desde el
		# principio
		assert_eq(bool((s.get("_gauge") as Control).get("compact")), q == "movil", "el indicador, compacto solo en el teléfono")
		(h[0] as Node).queue_free()


## La sección de cada garra (petición 36): la del felino, comprimida de lado (más alta que ancha); la de la rapaz, con la
## cara de abajo más baja que la de arriba; el rayo toca la superficie que se dibuja.
func test_la_seccion_de_cada_garra() -> void:
	var felid := ClawMesh.section_of({ "snap": { "animal_id": "tigre", "claw": {} } })
	var raptor := ClawMesh.section_of({ "snap": { "animal_id": "rapaz", "claw": {} } })
	var dino := ClawMesh.section_of({ "snap": { "animal_id": "velociraptor", "claw": {} } })
	assert_true(float(felid.w) < 0.7 and float(dino.w) < 0.6, "el felino y la hoz, comprimidos de lado")
	assert_true(float(raptor.b) < 1.0 and float(raptor.n_bot) > 2.5, "la rapaz, con la cara de abajo plana")
	assert_true(float(felid.n_bot) < 2.0, "el felino, con el filo abajo")
	# el rayo de lado toca la garra a w·r del eje (no a r)
	var ss := PackedFloat64Array([0.0, 10.0, 20.0])
	var rs := PackedFloat64Array([4.0, 4.0, 0.0])
	var h := ClawMesh.ray_hit(ss, rs, 0.0, Vector3(5.0, 0.0, 30.0), Vector3(0.0, 0.0, -1.0), 0.0, felid)
	assert_true(bool(h.hit), "el rayo de lado toca la garra")
	assert_near(float((h.point as Vector3).z), 4.0 * float(felid.w), 0.0, 0.02, "a w·r del eje")
	assert_true((h.normal as Vector3).z > 0.95, "con la normal de su cara")
	# la malla tiene esa misma sección
	var arr := ClawMesh.tube_arrays(ss, rs, 0.0, 40, 0.0, felid)
	var zmax := 0.0
	var ymax := 0.0
	for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
		zmax = maxf(zmax, absf(v.z))
		ymax = maxf(ymax, absf(v.y))
	assert_near(zmax, 4.0 * float(felid.w), 0.0, 0.03, "la malla, igual de ancha")
	assert_near(ymax, 4.0, 0.0, 0.03, "y su alto, el radio del motor")
	# la medida de cada garra que da el motor (la 5g: snapshot().claw.sectionRatio, ventralFlat y arcDeg), con el área de la
	# física: alto = 2·r·√k y ancho = 2·r/√k; la cara de abajo plana; el arco medido
	var hoz := ClawMesh.section_of({ "snap": { "animal_id": "velociraptor", "claw": { "sectionRatio": 2.6 } } })
	var hoz_arr := ClawMesh.tube_arrays(ss, rs, 0.0, 40, 0.0, hoz)
	var hz := 0.0
	var hy_top := 0.0
	var hy_bot := 0.0
	for v: Vector3 in hoz_arr[Mesh.ARRAY_VERTEX]:
		hz = maxf(hz, absf(v.z))
		hy_top = maxf(hy_top, v.y)
		hy_bot = minf(hy_bot, v.y)
	assert_near(hy_top - hy_bot, 2.0 * 4.0 * sqrt(2.6), 0.0, 0.03, "la hoz: alto = 2·r·√k")
	assert_near(2.0 * hz, 2.0 * 4.0 / sqrt(2.6), 0.0, 0.03, "y ancho = 2·r/√k")
	# el rayo toca esa misma superficie, aunque pase del radio del motor
	var hh := ClawMesh.ray_hit(ss, rs, 0.0, Vector3(5.0, 30.0, 0.0), Vector3(0.0, -1.0, 0.0), 0.0, hoz)
	assert_true(bool(hh.hit), "el rayo desde arriba toca la hoz")
	assert_near(float((hh.point as Vector3).y), hy_top, 0.0, 0.05, "en lo alto de su sección")
	var flat := ClawMesh.section_of({ "snap": { "animal_id": "oso", "claw": { "ventralFlat": true } } })
	assert_true(float(flat.n_bot) >= float(ClawMesh.SECTIONS.ave.n_bot), "la cara de abajo plana")
	var nat := 40.0
	assert_near(ClawMesh.claw_curvature({ "naturalMm": nat, "arcDeg": 98.4, "curve": 0.1 }) * nat, deg_to_rad(98.4), 0.0, 1e-9,
		"el arco medido, a lo largo del largo natural")
	assert_near(ClawMesh.claw_curvature({ "naturalMm": nat, "curve": 0.5 }), ClawMesh.curvature(nat, 0.5), 0.0, 1e-12,
		"sin él, el del dibujo del banco")


## La silueta de la forma sana (la de la ficha): se enciende y se apaga, tiene el largo natural y sale del perfil de
## partida del motor.
func test_la_forma_sana_se_enciende_y_se_apaga() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "tigre" })
	s.call("show_view", r.latest())
	_frame(s, r)
	assert_false(bool(s.call("info").ghost), "apagada al empezar")
	s.call("toggle_ghost")
	assert_true(bool(s.call("info").ghost), "la tecla la enciende")
	var v := r.latest()
	var nat := ClawMesh.natural_profile(v)
	var ns: PackedFloat64Array = nat.s
	assert_near(ns[ns.size() - 1], float(v.snap.claw.naturalMm), 0.0, 1e-6, "la forma sana mide el largo natural")
	assert_true(float(v.snap.claw.startMm) > float(v.snap.claw.naturalMm) + 1.0, "(la garra de partida es más larga: ha crecido)")
	s.call("set_view", "seccion", true)
	assert_false(bool(s.call("info").ghost), "en el corte no se ve")
	s.call("set_view", "garra", true)
	s.call("set_ghost", false)
	assert_false(bool(s.call("info").ghost), "y se apaga")


## La superficie del motor (petición 37, la 5g) pasa a la textura del material, codificada por la biblioteca de
## materiales (ClawMaterial.surface_image con la lista de ClawCare.surface_stations) y hecha solo cuando cambia; sin ella,
## la del acabado.
func test_la_superficie_del_motor_en_su_textura() -> void:
	var b := (load(SCENE) as PackedScene).instantiate()
	var st: Array = b.call("surface_stations", { "ra_um": PackedFloat64Array([0.0, 25.0, 100.0]), "burn": PackedFloat64Array([0.0, 0.5, 1.0]),
		"chip": PackedFloat64Array([0.0, 0.0, 1.0]), "scratch_deg": PackedFloat64Array([0.0, 90.0, 180.0]) })
	assert_eq(st.size(), 3, "una estación por cada valor del motor")
	assert_eq(st[1], { "ra_um": 25.0, "burn": 0.5, "chip": 0.0, "scratch_deg": 90.0 }, "con sus cuatro campos")
	var lst: Array = [{ "ra_um": 50.0 }]
	assert_eq(b.call("surface_stations", lst), lst, "también como lista de estaciones")
	b.free()
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "rapaz", "seed": "superficie" })
	s.call("show_view", r.latest())
	_frame(s, r)
	var mat: ShaderMaterial = s.get("_sheath_mat")
	var v := r.latest()
	# la del motor (la 5g): la lista de ClawCare.surface_stations, codificada por la biblioteca, hecha en el hilo del estado
	var want := ClawMaterial.surface_image(r.state.care.surface_stations())
	assert_true(v.get("surface_img") is Image, "la vista trae la textura de la superficie")
	assert_eq(int(s.call("info").surface_px), want.get_width(), "una columna por estación")
	assert_eq(mat.get_shader_parameter("surface_range"), Vector2(0.0, float(v.snap.claw.lengthMm)), "surface_range = (0, largo)")
	assert_true(mat.get_shader_parameter("surface_tex") == s.get("_surface_tex"), "la textura de la escena, en el material")
	assert_eq((s.get("_surface_img") as Image).get_data(), want.get_data(), "con el código de la biblioteca de materiales")
	# en cada tic cambia la instantánea, no la superficie: la imagen es la misma (no se rehace en cada fotograma)
	var img0: Image = r.latest().surface_img
	_frame(s, r, 3)
	assert_true(r.latest().surface_img == img0, "sin limar, la misma imagen")
	# una vista sin superficie (hecha a mano): la del acabado
	var bare := r.latest().duplicate()
	var sn: Dictionary = (bare.snap as Dictionary).duplicate()
	sn.erase("surface")
	bare["snap"] = sn
	bare.erase("surface_img")
	bare["serial"] = int(bare.serial) + 1000
	s.call("show_view", bare)
	assert_eq(mat.get_shader_parameter("surface_range"), Vector2.ZERO, "sin datos del motor: la del acabado")


## Al cortar la garra, el trozo que se va salta y cae, y luego desaparece; ningún nodo nuevo.
func test_el_trozo_que_se_corta_cae() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "rapaz", "seed": "trozo" })
	s.call("show_view", r.latest())
	r.post("pick", ["guillotina"])
	_frame(s, r, 3)
	var nodes := int(s.call("node_count"))
	var apex: float = r.state.care.apex_mm()
	r.post("press_on", [apex - 2.0])
	_frame(s, r, 16)
	r.post("release")
	_frame(s, r)
	var info: Dictionary = s.call("info")
	assert_true(r.state.care.apex_mm() < apex - 1.0, "(el cortaúñas ha cortado)")
	assert_eq(int(info.pieces), 1, "el trozo se separa")
	assert_true(bool(info.piece_falling), "y cae")
	# el trozo es el que apunta el motor (la 5g: damage.breaks, con su sitio y su perfil; el último que se va): mide lo
	# que se ha ido
	var lb := {}
	for b: Dictionary in r.latest().snap.damage.breaks:
		if bool(b.falls):
			lb = b
	assert_eq(String(lb.get("kind", "")), "corte", "(el motor apunta el corte)")
	var span: Vector2 = info.piece_span
	assert_near(span.x, float(lb.fromS), 0.0, 1e-4, "desde donde se corta (fromS)")
	assert_near(span.y, float(lb.toS), 0.0, 0.05, "hasta la punta de antes (toS)")
	assert_true(float(lb.pieceMm) >= 1.0, "(el trozo del motor mide %s mm)" % Js.to_fixed(float(lb.pieceMm), 1))
	var piece: MeshInstance3D = s.get("_piece")
	var y0 := piece.global_position.y
	_frame(s, r, 12)
	assert_true(piece.global_position.y < y0 - 0.01, "más abajo después (%s → %s m)" % [Js.to_fixed(y0, 3), Js.to_fixed(piece.global_position.y, 3)])
	_frame(s, r, 120)
	assert_false(piece.visible, "y desaparece")
	assert_eq(int(s.call("node_count")), nodes, "sin nodos nuevos")


## La garra rota que vuelve de la reforja (la 5g: claw.block): el muñón de queratina y el bloque en bruto encima, cada uno
## con su material (la superficie y el estado, en los dos); el bloque empieza donde acaba el muñón.
func test_el_bloque_en_bruto_con_su_material() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "rapaz", "seed": "bloque" })
	s.call("show_view", r.latest())
	_frame(s, r)
	assert_false(bool(s.call("info").block), "sin bloque: solo el estuche")
	var fs := { "careSupported": true, "block": { "material": "zafiro", "stump_mm": 20.0, "wall_mm": 1.0, "fiction": true,
		"note": "FICCIÓN: prueba", "source": "test" } }
	r.post("reforge_with", [fs])
	_frame(s, r, 2)
	var b: Dictionary = r.latest().snap.claw.block
	assert_true(bool(s.call("info").block), "el bloque, con su malla")
	assert_eq((s.get("_block_mesh") as ArrayMesh).get_surface_count(), 1, "(una superficie)")
	var sheath: Array = r.latest().mesh.sheath
	var block: Array = r.latest().mesh.block
	var s_max := 0.0
	for uv: Vector2 in sheath[Mesh.ARRAY_TEX_UV]:
		s_max = maxf(s_max, uv.x)
	var s_min := INF
	for uv: Vector2 in block[Mesh.ARRAY_TEX_UV]:
		s_min = minf(s_min, uv.x)
	assert_near(s_max, float(b.fromMm), 0.0, 1e-3, "el estuche acaba en el muñón")
	assert_near(s_min, float(b.fromMm), 0.0, 1e-3, "y ahí empieza el bloque")
	var bm: ShaderMaterial = s.get("_block_mat")
	var km: ShaderMaterial = s.get("_sheath_mat")
	assert_true(int(bm.get_shader_parameter("claw_kind")) != int(km.get_shader_parameter("claw_kind")), "cada uno con su material")
	assert_eq(bm.get_shader_parameter("surface_range"), km.get_shader_parameter("surface_range"), "la superficie, en los dos")
	assert_eq(bm.get_shader_parameter("apex_mm"), km.get_shader_parameter("apex_mm"), "y lo del estado")


## El tigre: la garra que se trabaja sale de su vaina y las demás (sin trabajar) van recogidas; al elegir otra, la nueva
## sale con una transición y la de antes se recoge. Sin nodos nuevos.
func test_la_garra_del_tigre_sale_de_su_vaina() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "tigre", "seed": "vaina" })
	r.post("set_sedation", ["anestesia"])
	s.call("show_view", r.latest())
	_frame(s, r, 3)
	var nodes := int(s.call("node_count"))
	var pr: Dictionary = (s.get("_paw") as Dictionary).protract
	var sel := "%s|%s" % [r.state.paw, r.state.digit]
	assert_true(pr.has(sel), "cada garra del tigre tiene su vaina")
	assert_near(float(pr[sel].k), 1.0, 0.0, 1e-3, "la que se trabaja, fuera")
	var other := State.slot_key(r.state.paw, "IV" if r.state.digit != "IV" else "III")
	assert_near(float(pr[other].k), 0.0, 0.0, 1e-3, "las demás, recogidas")
	r.post("select_claw", [r.state.paw, other.split("|")[1]])
	_frame(s, r, 2)
	var mid_k := float(pr[other].k)
	assert_true(mid_k > 0.0 and mid_k < 0.98, "sale poco a poco (%s)" % Js.to_fixed(mid_k, 2))
	_frame(s, r, 30)
	assert_near(float(pr[other].k), 1.0, 0.0, 1e-3, "y queda fuera")
	assert_near(float(pr[sel].k), 0.0, 0.0, 1e-3, "y la de antes, recogida")
	var node: Node3D = pr[other].node
	assert_true(node.transform.is_equal_approx(pr[other].out), "en su sitio de fuera")
	assert_eq(int(s.call("node_count")), nodes, "sin nodos nuevos")


## Lo que cuesta un fotograma de la escena (advance() y show_view(), sin el dibujo ni el estado, que en la página va en su
## hilo: los gestos se mandan al estado fuera de la medida) con cada animal en alta definición y la lima pasando por la
## garra, en el escritorio y en el teléfono; el del escritorio, en el presupuesto del encargo.
func test_coste_por_fotograma_con_las_patas_de_alta_definicion() -> void:
	var line := PackedStringArray()
	for q: String in ["", "movil"]:
		var h := _host("", q)
		var s: Node3D = h[1]
		for a: String in ["rapaz", "tigre", "oso", "velociraptor"]:
			var r := _runner({ "animal": a, "seed": "coste" })
			var queue: Array = []
			s.connect("gesture", func(op: String, args: Array) -> void: queue.append([op, args]))
			r.post("set_sedation", ["anestesia" if a != "rapaz" else "sujecion"])
			r.post("pick", ["lima_bastarda"])
			s.call("show_view", r.latest())
			_frame(s, r, 40)
			var apex: float = r.state.care.apex_mm()
			var us := 0
			var worst := 0
			var n := 0
			for i in 150:
				var k := float(i % 50) / 50.0
				var p0: Vector2 = s.call("claw_screen_point", apex - 4.0, 0.0, 0.0)
				var p1: Vector2 = s.call("claw_screen_point", apex - 0.5, 0.0, 0.0)
				var t0 := Time.get_ticks_usec()
				if i % 50 == 0:
					_mouse(s, p0)
					_mouse(s, p0, MOUSE_BUTTON_LEFT, true)
				_mouse(s, p0.lerp(p1, k))
				if i % 50 == 49:
					_mouse(s, p1, MOUSE_BUTTON_LEFT, false)
				s.call("advance", FRAME)
				var t1 := Time.get_ticks_usec()
				# el estado (en la página, en su hilo): fuera de la medida
				for g: Array in queue:
					r.post(String(g[0]), g[1])
				queue.clear()
				r.post("tick", [FRAME])
				var v := r.latest()
				var t2 := Time.get_ticks_usec()
				s.call("show_view", v)
				var frame_us := (t1 - t0) + (Time.get_ticks_usec() - t2)
				us += frame_us
				worst = maxi(worst, frame_us)
				n += 1
			var avg := float(us) / float(n) / 1000.0
			var tag := "%s %s" % ["móvil" if q == "movil" else "escritorio", a]
			line.append("%s %s ms (máx. %s)" % [tag, Js.to_fixed(avg, 2), Js.to_fixed(float(worst) / 1000.0, 2)])
			if q == "":
				assert_true(avg < BUDGET_MS, "%s: un fotograma de la escena cuesta %s ms de media (presupuesto %s ms)" % [tag, Js.to_fixed(avg, 2), Js.to_fixed(BUDGET_MS, 1)])
			assert_true(r.state.calls.filter(func(c: Array) -> bool: return String(c[0]) == "file").size() > 0, "%s: (la lima ha limado)" % tag)
			for c in s.get_signal_connection_list("gesture"):
				s.disconnect("gesture", c.callable)
		(h[0] as Node).queue_free()
	print("    (info) escena 3D de la cetrería en alta definición, limando (advance + show_view): %s" % ", ".join(line))
