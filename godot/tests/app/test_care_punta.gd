## El afilado que se ve (unidad 5s, petición 60): la malla de la garra con la punta de verdad (se estrecha cuando baja el radio,
## y mellada se ve mellada), las garras de cada dedo y de cada pata con su forma y su tono (no son copias), y en la página, el
## medidor y la lupa de la punta bajo la vista y para qué sirve cada herramienta.
extends "res://tests/case.gd"

const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const LabSection = preload("res://app/lab/lab_section.tscn")
const State = preload("res://core/lab/claw_care_state.gd")
const SharpenHelp = preload("res://core/lab/claw_care_sharpen_help.gd")
const SCENE := "res://app/lab/cetreria/care_3d.tscn"
const CareAnimal = preload("res://app/lab/cetreria/care_animal.gd")


## Un águila con la garra recortada 2 mm (remojada), lista para afilar con la lima fina a 22°.
static func _clipped() -> Runner:
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila", "seed": "punta" })
	r.post("set_sedation", ["sujecion"])
	r.post("set_humidity", ["humeda"])
	r.post("pick", ["guillotina"])
	r.post("press_on", [r.state.care.apex_mm() - 2.0])
	for i in 20:
		r.post("tick", [1.0 / 30.0])
	r.post("release")
	r.post("set_humidity", ["natural"])
	r.post("pick", ["lima_fina"])
	r.post("set_angle", [22.0])
	return r


static func _pass(r: Runner) -> void:
	var s: float = r.state.care.apex_mm() - 0.8
	r.post("press_on", [s])
	for j in 5:
		r.post("drag", [2.0, 2.0, s, 1.0 / 30.0])
	r.post("release")


## El radio de la malla junto al vértice (mm): el mayor de los anillos (UV2.x) a menos de d mm de la punta (UV.x).
static func _tip_width(v: Dictionary, d: float) -> float:
	var sh: Array = v.mesh.sheath
	var uv: PackedVector2Array = sh[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = sh[Mesh.ARRAY_TEX_UV2]
	var apex := float(v.snap.claw.lengthMm)
	var w := 0.0
	for i in uv.size():
		if uv[i].x >= apex - d - 1e-6 and uv2[i].y == 0.0:
			w = maxf(w, uv2[i].x)
	return w


func test_la_malla_se_estrecha_cuando_baja_el_radio() -> void:
	var r := _clipped()
	var prev_r := float(r.latest().snap.tip.tipRadiusUm)
	var prev_w := _tip_width(r.latest(), 1e-5)
	assert_near(prev_w, float(r.latest().snap.tip.flatMm), 1e-6, 1e-6, "recortada: la cara de la malla, la del motor")
	var narrowed := 0
	for i in 160:
		_pass(r)
		var v := r.latest()
		var now_r := float(v.snap.tip.tipRadiusUm)
		var now_w := _tip_width(v, 1e-5)
		if now_r < prev_r - 1e-6:
			assert_true(now_w <= prev_w + 1e-9, "pasada %d: el radio baja de %s a %s µm y la malla no se ensancha (%s → %s mm)" % [i, prev_r, now_r, prev_w, now_w])
			narrowed += 1
		prev_r = now_r
		prev_w = now_w
		if float(v.snap.tip.flatMm) <= 0.0:
			break
	assert_true(narrowed >= 3, "la punta se ha afilado varias veces (%d)" % narrowed)
	# cerrada la cara: la punta de la malla, una esfera de radio de los filos (la lupa del motor)
	var v2 := r.latest()
	var lp: Dictionary = v2.tip_help.lupa
	assert_eq(String(lp.kind), "punta", "una aguja")
	assert_true(_tip_width(v2, float(lp.startMm) + 0.002) < 0.02, "a 2 µm de la esfera la malla mide micras, no décimas")


func test_la_punta_mellada_se_ve_mellada() -> void:
	var r := _clipped()
	for i in 160:
		_pass(r)
		if float(r.latest().snap.tip.flatMm) <= 0.0:
			break
	r.post("probe_tip")
	var v := r.latest()
	assert_true(bool(v.tip_help.lupa.chipped), "probada de lado, se mella")
	var sh: Array = v.mesh.sheath
	var verts: PackedVector3Array = sh[Mesh.ARRAY_VERTEX]
	var apex := float(v.snap.claw.lengthMm)
	var k := float(v.mesh.k)
	var t := ClawMesh.tangent_at(apex, k)
	var p := ClawMesh.point_at(apex, k)
	# la tapa (los últimos ring + 2 vértices) no es plana: unos más hundidos que otros
	var lo := INF
	var hi := -INF
	for i in range(verts.size() - (int(v.mesh.ring) + 2), verts.size()):
		var dd := (verts[i] - p).dot(t)
		lo = minf(lo, dd)
		hi = maxf(hi, dd)
	assert_true(hi - lo > 0.1 * float(v.snap.tip.flatMm), "la cara de la mella, desigual (%s mm de hondura)" % (hi - lo))


func test_cada_garra_con_la_forma_de_su_dedo_y_su_tono() -> void:
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila", "seed": "dedos" })
	var v := r.latest()
	var om: Dictionary = v.others_mesh
	var slots: Array = v.slots
	assert_eq(om.size(), slots.size() - 1, "todas las garras menos la elegida llevan su propia malla")
	var a: Array = om["derecha|I"].arrays
	var b: Array = om["derecha|II"].arrays
	assert_true(var_to_str(a[Mesh.ARRAY_VERTEX]) != var_to_str(b[Mesh.ARRAY_VERTEX]), "el dedo I y el II, distintos")
	assert_true(float(om["derecha|I"].lengthMm) > float(om["derecha|IV"].lengthMm), "el talón (I), más largo que el IV (Fowler et al. 2009)")
	# el dedo II, más curvo que el III (su arco medido, en la malla: la curvatura)
	var by_d := {}
	for e: Dictionary in slots:
		by_d[String(e.key)] = e
	assert_true(float(by_d["derecha|II"].arcDeg) > float(by_d["derecha|III"].arcDeg), "el dedo II, más curvo")
	# las de la otra pata: la misma forma de su dedo, pero cada una con su tono de queratina
	var base := Color("#2E2A26")
	var t1 := CarePaw.claw_tone(base, "aguila", "derecha|II")
	var t2 := CarePaw.claw_tone(base, "aguila", "izquierda|II")
	assert_true(not t1.is_equal_approx(t2), "la del II de cada pata, con su tono")
	assert_true(CarePaw.claw_tone(base, "aguila", "derecha|II").is_equal_approx(t1), "determinista")
	assert_true(absf(t1.v - base.v) <= base.v * float(CarePaw.CLAW_TONE_VARIATION.v) + 1e-6, "dentro de la variación")


func test_la_pagina_ensena_el_medidor_la_lupa_y_para_que_sirve() -> void:
	var s: Control = LabSection.instantiate()
	s.settings_path = ""
	s.setup()
	s.page_bar.buttons[s.PAGE_CARE].pressed.emit()
	var page: Control = s.care_page
	page.runner.post("pick", ["guillotina"])
	page.runner.post("set_humidity", ["humeda"])
	page.runner.post("press_on", [page.runner.state.care.apex_mm() - 2.0])
	for i in 20:
		page.runner.post("tick", [1.0 / 30.0])
	page.runner.post("release")
	page.call("refresh")
	assert_true(page.tip_meter.visible and page.tip_lupa.visible, "el medidor y la lupa se ven")
	assert_true(page.tip_box.get_parent() == page.left, "bajo la vista, sin taparla")
	var mt: String = page.tip_meter._text.text
	assert_true(mt.contains("cortaúñas") or mt.contains("lima fina"), "con el cortaúñas: para afilar, la lima fina (%s)" % mt)
	assert_true(page.tools_advice.visible and String(page.tools_advice.text).begins_with("Para afilar:"), "el aviso para afilar, en la tarjeta")
	var lines: Array = []
	for c in page.tools_purpose.get_children():
		lines.append(String((c as Label).text))
	assert_true(lines.any(func(t: String) -> bool: return t.begins_with("AFILA · Lima fina")), "la lima fina, marcada: afila")
	assert_true(lines.any(func(t: String) -> bool: return t.begins_with("AFILA, SE PASA · Amoladora")), "la amoladora, marcada: se pasa")
	assert_true(lines.any(func(t: String) -> bool: return t.begins_with("Cortaúñas: acorta")), "el cortaúñas acorta")
	s.free()


## En «La garra», ninguna de las otras garras tapa la elegida (el dedo IV del águila, que desde fuera de la pata queda
## detrás del III), ni el tablero de la mesa (el I en el teléfono): la cámara busca el lado desde el que se ve entera, en
## escritorio y en una vista estrecha.
func test_en_la_garra_no_la_tapan_las_demas() -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(352, 440)]:
		_no_la_tapan(size)


func _no_la_tapan(size: Vector2i) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila", "seed": "encuadre" })
	r.post("set_sedation", ["sujecion"])
	r.post("tick", [1.0 / 30.0])
	s.call("show_view", r.latest())
	s.call("set_view", "garra", true)
	for e: Dictionary in r.latest().slots:
		if String(e.paw) != "derecha":
			continue
		r.post("select_claw", [String(e.paw), String(e.digit)])
		r.post("tick", [1.0 / 30.0])
		s.call("show_view", r.latest())
		s.call("set_view", "garra", true)
		s.call("advance", 1.0 / 30.0)
		var cam: Camera3D = s.call("camera")
		var rig: Node3D = s.get("_rig")
		var tgt: Vector3 = rig.get("target")
		var off := cam.global_position - tgt
		var occ := float(s.call("_occlusion", off.normalized(), off.length()))
		assert_true(occ == 0.0, "%s: el dedo %s se ve entero (tapado %s)" % [size, String(e.digit), occ])


## El oso y el tigre, sin medición dedo a dedo: las que no se trabajan, con su forma de dibujo (estimación), no copias; la que
## se trabaja, la del motor.
func test_el_oso_y_el_tigre_sin_copias() -> void:
	for a: Array in [["oso", "oso"], ["tigre", "tigre"]]:
		var r := Runner.new({ "animal": a[0], "claw": a[1], "seed": "copias" })
		var om: Dictionary = r.latest().others_mesh
		var lens := {}
		for key: String in om:
			lens[var_to_str(snappedf(float(om[key].lengthMm), 0.01))] = true
		assert_true(lens.size() >= om.size() - 1, "%s: cada garra con su largo (%d largos en %d garras)" % [a[0], lens.size(), om.size()])
		var d0 := CarePaw.claw_shape_drawing(String(a[1]), "x|III")
		assert_true(absf(float(d0.length) - 1.0) <= float(CarePaw.CLAW_SHAPE_JITTER.length) + 1e-9, "la del III, como la del banco (± lo de garra a garra)")
	assert_eq(String(CarePaw.CLAW_SHAPE_JITTER.quality), "dibujo", "marcada como dibujo")
	# el águila, medida dedo a dedo: su forma sale de la ficha, sin dibujo encima
	assert_eq(CarePaw.claw_shape_drawing("aguila", "derecha|I"), { "length": 1.0, "arc": 1.0 }, "el águila, de su ficha")


## La faceta, con caras planas: en su tramo, la mitad de arriba de la sección son dos planos (de arriba al lado, en línea
## recta); en el resto de la garra, redonda.
func test_la_faceta_con_caras_planas() -> void:
	var ss := PackedFloat64Array([0.0, 1.0, 2.0])
	var rs := PackedFloat64Array([1.0, 0.6, 0.2])
	var ring := 16
	var flat: Array = ClawMesh.facet_arrays(ss, rs, 0.02, ring, ClawMesh.ROUND, 0.1)
	var round: Array = ClawMesh.tube_arrays(ss, rs, 0.02, ring, 0.0, ClawMesh.ROUND)
	for pair: Array in [[flat, true], [round, false]]:
		var v: PackedVector3Array = (pair[0] as Array)[Mesh.ARRAY_VERTEX]
		var base := 2 * (ring + 1)
		var top := v[base]
		var side := v[base + ring / 4]
		var mid := v[base + ring / 8]
		var t := (mid - top).dot(side - top) / (side - top).length_squared()
		var off := (top + (side - top) * t).distance_to(mid)
		if bool(pair[1]):
			assert_true(off < 1e-6, "en la faceta, de arriba al lado en línea recta (%s mm)" % off)
		else:
			assert_true(off > 0.01, "fuera de la faceta, redonda (%s mm)" % off)


## El dedo IV de las nocturnas (búho y lechuza) se gira hacia atrás (lo pidió la calle B para el ataque): tiene su pivote,
## en la identidad en reposo; de él cuelgan su piel y la base de su garra; girarlo back_deg sobre la vertical en torno a su
## base lo vuelve hacia atrás y no mueve los demás dedos. Las diurnas, sin pivote.
func test_el_dedo_iv_de_las_nocturnas_se_gira() -> void:
	for art: String in ["buho", "lechuza", "aguila"]:
		var holder := Node3D.new()
		add_to_tree(holder)
		var rig := CareAnimal.build(holder, "rapaz", art, { "mobile": true, "cache": {} })
		var tp: Dictionary = rig.get("toe_pivots", {})
		if art == "aguila":
			assert_true(tp.is_empty(), "el águila, sin dedo reversible")
			holder.free()
			continue
		var paws: Array = (rig.paw_nodes as Dictionary).keys()
		assert_eq(tp.size(), paws.size(), "%s: un pivote por pata" % art)
		for p: String in paws:
			var key := "%s|IV" % p
			assert_true(tp.has(key), "%s: el IV de %s, con pivote" % [art, p])
			var e: Dictionary = tp[key]
			var pn: Node3D = e.node
			assert_true(pn.transform.is_equal_approx(Transform3D.IDENTITY), "en reposo, en la identidad")
			assert_true((rig.body.pivots as Dictionary).get("toe|" + key) == pn, "también entre los pivotes del cuerpo")
			var slot: Node3D = (rig.slots as Dictionary)[key].node
			assert_true(pn.is_ancestor_of(slot), "la base de su garra cuelga del pivote")
			var has_mesh := pn.get_children().any(func(c: Node) -> bool: return c is MeshInstance3D)
			assert_true(has_mesh, "y su piel")
			var other: Node3D = (rig.slots as Dictionary)["%s|III" % p].node
			var paw_root: Node3D = pn.get_parent()
			var before := paw_root.global_transform.affine_inverse() * slot.global_position
			var other_before := other.global_position
			var b := Basis(e.axis as Vector3, deg_to_rad(float(e.back_deg)))
			var pt: Vector3 = e.point
			pn.transform = Transform3D(b, pt - b * pt)
			var after := paw_root.global_transform.affine_inverse() * slot.global_position
			assert_true(after.x < before.x - 1e-4, "%s %s: girado, la base de la garra va hacia atrás (x %s → %s)" % [art, p, before.x, after.x])
			assert_true(other.global_position.is_equal_approx(other_before), "el III no se mueve")
			var d_after := b * (e.dir as Vector3)
			assert_true(d_after.x < -0.5, "el dedo apunta hacia atrás (%s)" % d_after)
		holder.free()


## Las garras que no se trabajan siguen lo que ha crecido cada una (care_setup): las de las patas del tigre, más cortas.
func test_las_otras_garras_con_su_crecimiento() -> void:
	var r := Runner.new({ "animal": "tigre", "claw": "tigre", "seed": "crece", "overgrowth_days": 90.0 })
	var front: Dictionary = r.call("_natural_profile", "delantera_izquierda", "III")
	var hind: Dictionary = r.call("_natural_profile", "trasera_izquierda", "III")
	var lf := float((front.s as PackedFloat64Array)[(front.s as PackedFloat64Array).size() - 1])
	var lh := float((hind.s as PackedFloat64Array)[(hind.s as PackedFloat64Array).size() - 1])
	assert_near(lf - lh, 90.0 * (0.13 - 0.08), 0.06, 0.0, "la de la pata, 4,5 mm más corta (%s frente a %s mm)" % [lh, lf])


## En «Animal y garra», el selector de la punta al empezar: empieza otro ensayo con esa punta y la tarjeta dice lo que cambia.
func test_el_selector_de_la_punta_al_empezar() -> void:
	var s: Control = LabSection.instantiate()
	s.settings_path = ""
	s.setup()
	s.page_bar.buttons[s.PAGE_CARE].pressed.emit()
	var page: Control = s.care_page
	assert_true(page.tip_start_choice != null, "el selector está")
	page.tip_start_choice.selected.emit("aguja")
	page.call("refresh")
	assert_eq(String(page.runner.latest().setup.tip_start), "aguja", "empieza con la punta de aguja")
	assert_true(String(page.tip_start_note.text).contains("se mella"), "la tarjeta lo dice (%s)" % page.tip_start_note.text)
	assert_eq(String(page.runner.latest().tip_help.meter.zone), "aguja", "y el medidor también")
	s.free()
