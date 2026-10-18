## Los animales de la cetrería en el coche en marcha (unidad 4r: app/lab/animals/hd3d.gd y moving_car_view.uses_hd).
## Se comprueba:
##   - que cada animal del coche con cuerpo de cetrería (el tigre, el oso, las seis rapaces y los dos velocirraptores) se
##     construye con él en todas sus posturas del coche, y que el casuario se queda con el suyo (el de la 4l);
##   - que en el coche no salen la tela, la toalla, la capucha, la mascarilla ni el pulsioxímetro de la clínica;
##   - que las garras quedan en el suelo del animal (la zona de agarre: a la altura de los pies, dentro de su caja), con
##     una garra de la biblioteca por dedo;
##   - que el animal se construye una vez por especie, postura y calidad (la segunda vez, todo de la caché), con menos
##     vértices en el teléfono;
##   - que las garras de metal en la carretera llevan el reflejo dibujado subido (METAL_ENV_ROAD) y las demás, no;
##   - y qué modos usan el cuerpo de la cetrería en la vista (quietos encima; las alas abiertas y el salto, con los de la 4l).
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const HdAnimal = preload("res://app/lab/animals/hd3d.gd")
const Animal3D = preload("res://app/lab/animals/animal3d.gd")
const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const Demo = preload("res://app/lab/demo_animales.gd")
const View = preload("res://app/lab/moving_car_view.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const Js = preload("res://core/shared/js.gd")

const HD_IDS := ["tigre", "oso", "aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "velociraptor", "velociraptor_pelicula"]
## Dónde pueden quedar las puntas de las garras respecto al suelo del animal (m): clavadas, hasta CLAW_DOWN_M por debajo
## del plano de apoyo (dibujo: se ven entrar en la chapa), y como mucho CLAW_UP_M por encima en las que apoyan de lado.
const CLAW_DOWN_M := 0.06
const CLAW_UP_M := 0.08
## Lo que cuelga la cola de una rapaz posada por debajo de sus pies (m): el cuerpo de la cetrería es rígido y levanta el
## pecho desde los talones; en el coche la punta de la cola se mete en el techo (pendiente: una cola que se levante).
const TAIL_DROP_M := 0.25


static func _build(id: String, posture: String, quality := "escritorio", cache := {}) -> RefCounted:
	return HdAnimal.build(id, posture, Demo.size_of(id), { "quality": quality, "cache": cache })


func test_cada_animal_del_coche_con_su_cuerpo_de_cetreria_y_el_casuario_con_el_suyo() -> void:
	var cache := {}
	for id: String in HD_IDS:
		for posture: String in HdAnimal.POSTURES[AnimalArt.kind_of(id)]:
			assert_true(HdAnimal.supports(id, posture), "%s %s: tiene cuerpo de cetrería" % [id, posture])
			var a := _build(id, posture, "escritorio", cache)
			assert_eq(a.get("kind"), AnimalArt.kind_of(id), "%s: su tipo" % id)
			var body: Dictionary = a.get("body")
			assert_true(body.has("root") and body.root != null, "%s %s: el cuerpo de care_body.gd" % [id, posture])
			var root: Node3D = a.get("root")
			var parts := {}
			for n: Node in root.find_children("*", "MeshInstance3D", true, false):
				parts[n.name] = true
			assert_true(parts.has("Cuerpo") and parts.has("Cabeza"), "%s %s: el cuerpo y la cabeza de alta definición" % [id, posture])
			var fit: Rect2 = a.get("fit_box")
			assert_true(fit.size.x > 0.2 and fit.size.y > 0.2, "%s %s: una caja con tamaño (%s)" % [id, posture, fit])
			if AnimalArt.kind_of(id) == "ave":
				# posada, la cola cuelga por detrás de los talones (el cuerpo de la cetrería es rígido): hasta TAIL_DROP_M por debajo
				assert_true(fit.position.y > -TAIL_DROP_M and fit.position.y < 0.02, "%s: la cola cuelga como mucho %s m (%s)" % [id, Js.to_fixed(TAIL_DROP_M, 2), Js.to_fixed(fit.position.y, 3)])
			else:
				assert_true(absf(fit.position.y) < 0.02, "%s %s: la caja empieza en el suelo (%s)" % [id, posture, Js.to_fixed(fit.position.y, 3)])
			var want := Demo.size_of(id)
			assert_true(fit.size.y > want.x * 0.5 and fit.size.y < want.x * 1.6, "%s %s: su alto (%s m frente a %s m del estado)" % [id, posture, Js.to_fixed(fit.size.y, 2), Js.to_fixed(want.x, 2)])
			a.call("free_nodes")
	# el casuario no tiene cuerpo de cetrería: la vista usa el de la 4l
	assert_false(HdAnimal.supports("casuario", "de_pie"), "el casuario, sin cuerpo de cetrería")
	var c := _build("casuario", "de_pie")
	assert_eq(c.get("kind"), "", "el adaptador no lo construye")
	c.call("free_nodes")
	# las alas abiertas y el salto, con los modelos de la 4l (los cuerpos de la cetrería son rígidos)
	assert_false(HdAnimal.supports("aguila", "abiertas"), "las alas abiertas, sin cuerpo de cetrería")
	assert_true(View.uses_hd("tigre", "de_pie", MCS.MODE_HOLD) and View.uses_hd("tigre", "tumbado", MCS.MODE_HOLD), "el tigre encima, con el de la cetrería")
	assert_false(View.uses_hd("tigre", "tumbado", MCS.MODE_IMPACT), "el tigre que salta contra el coche, con el de la 4l (el de la cetrería es rígido)")
	assert_true(View.uses_hd("aguila", "plegadas", MCS.MODE_HOLD), "la rapaz quieta encima, con el de la cetrería")
	assert_false(View.uses_hd("aguila", "plegadas", MCS.MODE_IMPACT), "la rapaz que se abalanza vuela con el de la 4l")
	assert_true(View.uses_hd("velociraptor", "tumbado", MCS.MODE_HOLD) and not View.uses_hd("velociraptor", "tumbado", MCS.MODE_IMPACT), "el velocirraptor: quieto, sí; el salto, no")
	assert_false(View.uses_hd("casuario", "de_pie", MCS.MODE_IMPACT), "el casuario, nunca")


func test_sin_lo_de_la_clinica_y_con_los_ojos_abiertos() -> void:
	for id: String in ["tigre", "aguila", "velociraptor"]:
		var a := _build(id, HdAnimal.POSTURES[AnimalArt.kind_of(id)][0])
		var body: Dictionary = a.get("body")
		assert_true((body.props as Dictionary).is_empty(), "%s: ni toalla, ni capucha, ni mascarilla, ni pulsioxímetro" % id)
		assert_true(body.get("under") == null, "%s: sin la tela de debajo" % id)
		var root: Node3D = a.get("root")
		for n: Node in root.find_children("*", "", true, false):
			var low := n.name.to_lower()
			for bad: String in ["toalla", "capucha", "mascarilla", "pulsi", "tela"]:
				assert_false(low.contains(bad), "%s: sin «%s» (%s)" % [id, bad, n.name])
		# los ojos abiertos: la sujeción «libre» (parpadea y respira) y la pose del fotograma los deja abiertos
		a.call("pose", { "t": 0.4, "live": true, "alpha": 1.0 })
		assert_eq(String(body.sed), "libre", "%s: sujeción libre, sin sedar" % id)
		a.call("free_nodes")


func test_las_garras_en_la_zona_de_agarre_una_por_dedo() -> void:
	for id: String in HD_IDS:
		var posture: String = HdAnimal.POSTURES[AnimalArt.kind_of(id)][0]
		var a := _build(id, posture)
		var claws: Array = a.get("claws")
		var want := int((MC.BODIES.get(id, {}) as Dictionary).get("contact", 0))
		# una garra de la biblioteca por dedo que apoya (contact de la física); la pata de la cetrería trae además los
		# espolones del tigre y del oso. En los velocirraptores la biblioteca pone las dos hoces (las que trabaja la cetrería)
		# y los dedos que apoyan (III y IV, dos por pie) llevan garras de dibujo con el mismo material (GarraDibujo)
		var root: Node3D = a.get("root")
		var drawn := root.find_children("GarraDibujo", "MeshInstance3D", true, false).size()
		if id.begins_with("velociraptor"):
			assert_eq(claws.size(), 2, "%s: las dos hoces de la biblioteca" % id)
			assert_eq(drawn, 2, "%s: las garras de dibujo de los dedos que apoyan, una malla por pie" % id)
		else:
			# el tigre y el oso: cuatro o cinco dedos por pata (contact cuenta los que se clavan: la mitad)
			assert_true(claws.size() >= want and claws.size() <= 2 * want, "%s: %d garras de la biblioteca para %d dedos que se clavan" % [id, claws.size(), want])
		var fit: Rect2 = a.get("fit_box")
		a.call("pose", { "t": 0.0, "live": false, "alpha": 1.0, "claws_out": 1.0 })
		var pts: Array = a.call("claw_points")
		assert_eq(pts.size(), claws.size(), "%s: una punta por garra" % id)
		for p: Vector3 in pts:
			assert_true(p.y > -CLAW_DOWN_M and p.y < CLAW_UP_M, "%s: la punta clavada a la altura de la chapa (y = %s m)" % [id, Js.to_fixed(p.y, 3)])
			assert_true(p.x > fit.position.x - 0.15 and p.x < fit.end.x + 0.15, "%s: la punta bajo el animal (x = %s m)" % [id, Js.to_fixed(p.x, 2)])
		# las garras recogidas del tigre entran en su vaina (las del oso no se retraen)
		if id == "tigre":
			a.call("pose", { "t": 0.0, "live": false, "alpha": 1.0, "claws_out": 0.0 })
			var inside: Array = a.call("claw_points")
			var moved := false
			for k in pts.size():
				moved = moved or (inside[k] as Vector3).distance_to(pts[k] as Vector3) > 0.005
			assert_true(moved, "el tigre recoge las garras")
		a.call("free_nodes")


func test_una_vez_por_animal_y_calidad_y_mas_ligero_en_el_telefono() -> void:
	var cache := {}
	var line: Array = []
	for id: String in HD_IDS:
		var posture: String = HdAnimal.POSTURES[AnimalArt.kind_of(id)][0]
		var a := _build(id, posture, "escritorio", cache)
		var b := _build(id, posture, "escritorio", cache)
		assert_true(int(a.get("meshes_built")) > 0, "%s: la primera vez se hace" % id)
		assert_eq(int(b.get("meshes_built")), 0, "%s: la segunda, todo de la caché" % id)
		assert_eq(int(b.get("verts")), int(a.get("verts")), "%s: los mismos vértices" % id)
		var m := _build(id, posture, "movil", cache)
		assert_true(int(m.get("verts")) < int(int(a.get("verts")) * 0.7), "%s: el del teléfono, más ligero (%d frente a %d)" % [id, int(m.get("verts")), int(a.get("verts"))])
		line.append("%s %s ms (caché %s ms, teléfono %s ms; %d/%d vértices)" % [id, Js.to_fixed(float(a.get("build_us")) / 1000.0, 0),
			Js.to_fixed(float(b.get("build_us")) / 1000.0, 0), Js.to_fixed(float(m.get("build_us")) / 1000.0, 0), int(a.get("verts")), int(m.get("verts"))])
		for r: RefCounted in [a, b, m]:
			r.call("free_nodes")
	print("    (info) construir cada animal de la cetrería para el coche: %s" % ", ".join(line))


func test_los_metales_reflejan_la_carretera_y_la_queratina_no() -> void:
	var a := _build("tigre", "de_pie")
	a.call("set_claws", true, "none", Color.WHITE)
	var keratin: ShaderMaterial = a.get("claw_mat")
	assert_eq(float(keratin.get_shader_parameter("claw_env_energy")), 1.0, "la queratina, con el entorno de serie")
	assert_eq(float(keratin.get_shader_parameter("claw_env")), 1.0, "y el entorno de la carretera")
	a.call("set_claws", false, "acero", Color.WHITE)
	var steel: ShaderMaterial = a.get("claw_mat")
	assert_eq(float(steel.get_shader_parameter("claw_env_energy")), HdAnimal.METAL_ENV_ROAD, "el acero, con el reflejo dibujado subido")
	assert_eq(int(steel.get_shader_parameter("claw_kind")), 1, "y como metal")
	a.call("set_claws", false, "zafiro", Color.WHITE)
	var gem: ShaderMaterial = a.get("claw_mat")
	assert_eq(float(gem.get_shader_parameter("claw_env_energy")), HdAnimal.GEM_ENV_ROAD, "la gema, con el entorno subido (unidad 4s: de cerca, delante de un hueco oscuro, se veía negra)")
	assert_true(steel != keratin and gem != steel, "una copia por material")
	# el mismo criterio en los modelos de la 4l (el casuario, las alas abiertas)
	assert_eq(Animal3D.METAL_ENV_ROAD, HdAnimal.METAL_ENV_ROAD, "los dos modelos, el mismo reflejo")
	a.call("free_nodes")
