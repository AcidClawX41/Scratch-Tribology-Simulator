## Los animales del coche en marcha en 3D (app/lab/animals/, unidad 4l). Se comprueba:
##   - que todas las especies se construyen en todas sus posturas, en el escritorio y en el teléfono (este, con menos
##     vértices), con su raíz, sus garras y sus anclas;
##   - que su cuerpo cabe en el tamaño del estado (MovingCar.BODIES) tocando el alto o el largo, sin deformarse;
##   - que la caché sirve el mismo modelo (sin rehacer mallas ni texturas) y que la pose de cada fotograma no crea nada;
##   - la anatomía que pide el encargo: los tres dedos del casuario que apoyan en el suelo y su daga; las garras, del largo
##     del catálogo (como la física); las alas abiertas, con la envergadura del estado;
##   - las garras con el material de la biblioteca (unidad 5e: la queratina de la especie o el reforjado, compartido, con el
##     desvanecido y el largo en cada malla), melladas, partidas y dobladas, con sus trozos;
##   - las dos variantes del velocirraptor (por el id o por opts.variant), la reconstrucción con plumas y el de película
##     con escamas y dientes;
##   - que la pose cabe de sobra en un fotograma, y que en los animales no hay física (vigilancia del código).
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const Animal3D = preload("res://app/lab/animals/animal3d.gd")
const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Loft = preload("res://app/lab/animals/loft.gd")
const Mammals3D = preload("res://app/lab/animals/mammals3d.gd")
const Theropod3D = preload("res://app/lab/animals/theropod3d.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")

const RAPTORS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]


## Tamaño del estado (alto, largo, envergadura; m): el de MovingCar.BODIES, como MovingCarState.draw_size().
static func size_of(id: String) -> Vector3:
	var b: Dictionary = MovingCar.body_of(id)
	return Vector3(float(b.height_m), float(b.length_m), float(b.span_m.value) if b.has("span_m") else 0.0)


static func build(id: String, posture: String, cache: Dictionary, opts := {}) -> RefCounted:
	var o := opts.duplicate()
	o["cache"] = cache
	return Animal3D.build(id, posture, size_of(id), o)


static func free_rig(rig: RefCounted) -> void:
	var root: Node3D = rig.get("root")
	if root != null and is_instance_valid(root):
		root.free()


static func count_nodes(n: Node) -> int:
	var k := 1
	for c: Node in n.get_children():
		k += count_nodes(c)
	return k


func test_todas_las_especies_y_posturas() -> void:
	var cache := {}
	assert_eq(AnimalArt.KINDS.size(), 11, "las once especies con dibujo")
	for id: String in AnimalArt.KINDS:
		assert_true(MovingCar.body_of(id) != null, "%s tiene cuerpo en MovingCar.BODIES" % id)
		assert_true(Animal3D.MODELS.has(id), "%s está modelado en 3D" % id)
		for post: String in AnimalArt.postures_of(id):
			for q: String in ["escritorio", "movil"]:
				var rig := build(id, post, cache, { "quality": q })
				var root: Node3D = rig.get("root")
				assert_true(root.get_child_count() > 0, "%s %s %s: tiene nodos" % [id, post, q])
				assert_true(int(rig.get("verts")) > 1000, "%s %s %s: tiene malla (%d vértices)" % [id, post, q, int(rig.get("verts"))])
				var claws: Array = rig.get("claws")
				var anchors: Dictionary = rig.get("anchors")
				assert_true(not claws.is_empty(), "%s: tiene garras" % id)
				assert_eq((anchors.get("claws", []) as Array).size(), claws.size(), "%s: un ancla por garra" % id)
				assert_eq(rig.claw_points().size(), claws.size(), "%s: claw_points, una por garra" % id)
				for k: String in ["eye", "neck", "hip"]:
					assert_true(anchors.has(k), "%s: ancla %s" % [id, k])
				var fb: Rect2 = rig.get("fit_box")
				assert_true(fb.size.x > 0.0 and fb.size.y > 0.0, "%s %s: caja del cuerpo" % [id, post])
				assert_true(fb.position.y > -0.02, "%s %s %s: nada se hunde en el suelo (%s m)" % [id, post, q, fb.position.y])
				free_rig(rig)


## La caja de referencia (el cuerpo de pie o con las alas plegadas; en los terópodos, el largo con la cola y el alto a la
## cadera) cabe en largo × alto tocando uno de los dos: la escala no deforma.
func test_cabe_en_el_tamano_del_estado() -> void:
	var cache := {}
	for id: String in AnimalArt.KINDS:
		var rig := build(id, AnimalArt.postures_of(id)[0], cache)
		var data: Dictionary = rig.get("_data")
		var fit: AABB = data.fit
		var mpc: float = rig.get("mpc")
		var sz := size_of(id)
		var h := fit.size.y * mpc
		var l := fit.size.x * mpc
		assert_true(h <= sz.x * 1.0001 and l <= sz.y * 1.0001, "%s: cabe (%s × %s m en %s × %s)" % [id, h, l, sz.x, sz.y])
		assert_true(absf(h - sz.x) < 1e-4 or absf(l - sz.y) < 1e-4, "%s: toca el alto o el largo" % id)
		free_rig(rig)


func test_movil_con_menos_vertices() -> void:
	var cache := {}
	for id: String in AnimalArt.KINDS:
		var post: String = AnimalArt.postures_of(id)[0]
		var desk := build(id, post, cache, { "quality": "escritorio" })
		var mob := build(id, post, cache, { "quality": "movil" })
		assert_true(int(mob.get("verts")) < int(desk.get("verts")) * 0.62, "%s: el teléfono, con menos vértices (%d frente a %d)" % [id,
			int(mob.get("verts")), int(desk.get("verts"))])
		free_rig(desk)
		free_rig(mob)


## Con la misma caché, el segundo animal reutiliza las mallas y las texturas (y cambiar de postura o de tamaño, también).
func test_la_cache_reutiliza_el_modelo() -> void:
	var cache := {}
	var a := build("tigre", "de_pie", cache)
	assert_true(int(a.get("meshes_built")) > 0 and int(a.get("rasterized")) > 0, "el primero construye mallas y texturas")
	var b := build("tigre", "tumbado", cache)
	var c := Animal3D.build("tigre", "de_pie", Vector3(0.5, 0.9, 0.0), { "cache": cache })
	for r: RefCounted in [b, c]:
		assert_eq(int(r.get("meshes_built")), 0, "sin mallas nuevas")
		assert_eq(int(r.get("rasterized")), 0, "sin texturas nuevas")
	var ma: Array = (a.get("_data") as Dictionary).meshes.values()
	var mb: Array = (b.get("_data") as Dictionary).meshes.values()
	assert_true((ma[0] as Array)[0] == (mb[0] as Array)[0], "la misma malla (no una copia)")
	var fit: AABB = (a.get("_data") as Dictionary).fit
	var sz := size_of("tigre")
	var want := minf(0.9 / fit.size.x, 0.5 / fit.size.y) / minf(sz.y / fit.size.x, sz.x / fit.size.y)
	assert_near(float(c.get("mpc")) / float(a.get("mpc")), want, 1e-5, 0.0, "otro tamaño: solo otra escala")
	var d := build("tigre", "de_pie", cache, { "quality": "movil" })
	assert_true(int(d.get("meshes_built")) > 0, "el teléfono tiene su propio modelo (otra calidad)")
	for r: RefCounted in [a, b, c, d]:
		free_rig(r)


## La pose de cada fotograma solo gira, escala y enseña nodos: ni nodos ni mallas nuevas.
func test_la_pose_no_crea_nada() -> void:
	var cache := {}
	var states := [{ "scared": 1.0, "bristle": 0.6 }, { "wind_local_ms": 30.0, "flutter": 1.0, "lean": 0.1 }, { "leap": 1.0 }, { "kick": 1.0 },
		{ "wing_open": 1.0, "wing_lift": 0.8 }, { "claw_len": 0.5 }, { "claw_gone": true }, { "claw_bend": 1.0 }, { "claws_out": 0.0 }, {}]
	for id: String in AnimalArt.KINDS:
		var rig := build(id, AnimalArt.postures_of(id)[AnimalArt.postures_of(id).size() - 1], cache)
		var root: Node3D = rig.get("root")
		var n0 := count_nodes(root)
		var meshes := {}
		for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
			meshes[(mi as MeshInstance3D).mesh] = true
		for i in 60:
			var p: Dictionary = (states[i % states.size()] as Dictionary).duplicate()
			p["t"] = float(i) / 60.0
			p["live"] = true
			rig.pose(p)
		assert_eq(count_nodes(root), n0, "%s: la pose no crea nodos" % id)
		assert_true(root.position == Vector3.ZERO and root.rotation == Vector3.ZERO, "%s: la pose no mueve la raíz (es de la vista)" % id)
		var same := true
		for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
			same = same and meshes.has((mi as MeshInstance3D).mesh)
		assert_true(same, "%s: ni mallas nuevas" % id)
		free_rig(rig)


## El casuario: los tres dedos (II, III y IV) apoyan en el suelo con sus almohadillas (nada de suela plana) y la daga del
## dedo II mide lo que la garra del catálogo.
func test_casuario_apoya_tres_dedos_y_lleva_la_daga() -> void:
	var rig := build("casuario", "de_pie", {})
	var data: Dictionary = rig.get("_data")
	var xf := Rig3D.globals(data, {})
	for side: String in ["_n", "_f"]:
		for toe: String in ["II", "III", "IV"]:
			var low := INF
			for name: String in data.meshes:
				if name.begins_with("dedo%s%s" % [toe, side]):
					low = minf(low, Loft.bounds((data.meshes[name] as Array)[0], xf[name]).position.y)
			assert_true(low > -0.3 and low < 0.6, "dedo %s%s: apoya en el suelo (%s cm)" % [toe, side, low])
	var longest := 0.0
	for c: Dictionary in data.claws:
		longest = maxf(longest, float(c.len))
	assert_near(longest, Mammals3D.claw_of("casuario").x, 1e-6, 0.0, "la daga, del largo del catálogo")
	free_rig(rig)


## Las garras miden lo que el catálogo (reach): el mismo dato que usa la física.
func test_garras_del_largo_del_catalogo() -> void:
	var cache := {}
	for id: String in RAPTORS + ["oso", "tigre", "velociraptor", "velociraptor_pelicula"]:
		var rig := build(id, AnimalArt.postures_of(id)[0], cache)
		var longest := 0.0
		for c: Dictionary in (rig.get("_data") as Dictionary).claws:
			longest = maxf(longest, float(c.len))
		var want := Mammals3D.claw_of(id).x if not id.begins_with("velociraptor") else Theropod3D.sickle_of(String(rig.get("variant"))).x
		assert_true(longest <= want * 1.0001 and longest >= want * 0.9, "%s: garra de %s cm (catálogo %s)" % [id, longest, want])
		free_rig(rig)
	assert_near(Theropod3D.sickle_of("reconstruccion").x, 9.27, 1e-6, 0.0, "la hoz de la reconstrucción: 92,7 mm de queratina")


## Las alas abiertas tienen la envergadura del estado (de punta a punta, con las alas casi horizontales).
func test_alas_con_la_envergadura_del_estado() -> void:
	var cache := {}
	for id: String in RAPTORS:
		var rig := build(id, "abiertas", cache)
		rig.pose({ "t": 0.0, "wing_open": 1.0, "wing_lift": 0.0 })
		var root: Node3D = rig.get("root")
		var zmin := INF
		var zmax := -INF
		for bone: String in ["ala_n", "ala_f"]:
			var b: Node3D = (rig.get("bones") as Dictionary)[bone]
			for mi: Node in b.find_children("*", "MeshInstance3D", true, false):
				var m3 := mi as MeshInstance3D
				var xf := Transform3D.IDENTITY
				var n: Node = m3
				while n != null and n != root:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				var box := Loft.bounds(m3.mesh, xf)
				zmin = minf(zmin, box.position.z)
				zmax = maxf(zmax, box.end.z)
		var span := zmax - zmin
		var want := size_of(id).z
		assert_true(absf(span - want) / want < 0.06, "%s: envergadura %s m (estado %s m)" % [id, span, want])
		free_rig(rig)


func test_garras_reforjadas_melladas_partidas_y_dobladas() -> void:
	var rig := build("aguila", "plegadas", {})
	var claws: Array = rig.get("claws")
	var malla := (claws[0].node as Node3D).get_node("Malla") as MeshInstance3D
	# el material, el de la biblioteca (unidad 5e): el oro, metálico y amarillo (su reflectancia medida, más roja que azul)
	rig.set_claws(false, "oro", Color("#E2B13C"))
	var mat: ShaderMaterial = rig.get("claw_mat")
	assert_eq(int(mat.get_shader_parameter("claw_kind")), 1, "reforjadas: el oro, metálico")
	var f0: Vector3 = mat.get_shader_parameter("claw_f0")
	assert_true(f0.x > f0.z * 1.8, "el oro, amarillo (F0 %s)" % f0)
	assert_true(malla.get_surface_override_material(0) == mat, "la garra lleva el material de la biblioteca")
	var lib := ClawMaterial.material("oro", {}, { "quality": "escritorio", "env": "carretera" })
	assert_true(mat.shader == lib.shader and mat.get_shader_parameter("claw_f0") == lib.get_shader_parameter("claw_f0"),
		"una copia del de la biblioteca (el desvanecido es del animal)")
	var built := ClawMaterial.built
	rig.set_claws(true, "none", Color.WHITE)
	rig.set_claws(false, "oro", Color("#E2B13C"))
	assert_true(rig.get("claw_mat") == mat, "volver al oro reutiliza la copia")
	rig.set_claws(true, "none", Color.WHITE)
	mat = rig.get("claw_mat")
	assert_eq(int(mat.get_shader_parameter("claw_kind")), 0, "naturales: queratina")
	assert_eq((mat.get_shader_parameter("claw_base") as Color).to_html(false), (rig.get("claw_natural") as Color).to_html(false), "con el color de la especie")
	assert_eq((rig.get("claw_natural") as Color).to_html(false), ClawOptics.keratin_color("aguila").to_html(false), "el de KERATIN_COLORS (con su fuente)")
	assert_true(malla.get_surface_override_material(0) == mat, "y en la malla")
	assert_eq(ClawMaterial.built, built, "volver a un material ya usado no construye nada (ni la biblioteca ni el animal)")
	# el desvanecido, en la copia del animal; el largo de cada garra (dónde acaba), en su malla (UV2.y, mm)
	rig.set_alpha(0.5)
	assert_near(float(mat.get_shader_parameter("claw_fade")), 0.5, 1e-6, 0.0, "el desvanecido, en el material del animal")
	rig.set_alpha(1.0)
	var uv2: PackedVector2Array = malla.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_near(uv2[0].y, float((rig.get("_data") as Dictionary).claws[0].len) * 10.0, 1e-3, 0.0, "la punta, al largo de la garra (mm)")
	rig.pose({ "t": 0.1, "live": true, "claw_len": 0.55 })
	assert_false((claws[0].tip as Node3D).visible, "mellada: pierde la punta")
	assert_true((claws[0].node as Node3D).visible, "mellada: le queda la base")
	rig.pose({ "t": 0.3, "live": true, "claw_len": 0.55 })
	var shards := 0
	for n: Node in (rig.get("root") as Node).find_children("Trozos", "Node3D", true, false):
		shards += 1 if (n as Node3D).visible else 0
	assert_true(shards > 0, "al romperse saltan trozos")
	rig.pose({ "t": 2.0, "live": true, "claw_len": 0.55 })
	shards = 0
	for n: Node in (rig.get("root") as Node).find_children("Trozos", "Node3D", true, false):
		shards += 1 if (n as Node3D).visible else 0
	assert_eq(shards, 0, "y caen y desaparecen")
	rig.pose({ "t": 2.1, "live": true, "claw_gone": true })
	assert_false((claws[0].node as Node3D).visible, "partida: sin garra")
	var rest_tip: Mesh = Animal3D._claw_mesh_node(claws[0].tip).mesh
	rig.pose({ "t": 2.2, "live": true, "claw_bend": 1.0 })
	# unidad 4y: la punta doblada es la malla de la punta torcida desde su final, de una pieza (no la pieza girada sobre el corte)
	var bent_tip: Mesh = Animal3D._claw_mesh_node(claws[0].tip).mesh
	assert_true((claws[0].node as Node3D).visible and (claws[0].tip as Node3D).visible and bent_tip != rest_tip, "doblada: la punta torcida")
	var va: PackedVector3Array = rest_tip.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = bent_tip.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := 0.0
	for i in mini(va.size(), vb.size()):
		moved = maxf(moved, va[i].distance_to(vb[i]))
	assert_true(va.size() == vb.size() and moved > 0.0, "la misma malla, con la punta movida (%s)" % moved)
	assert_true((claws[0].tip as Node3D).quaternion.is_equal_approx(Quaternion.IDENTITY), "sin girar la pieza sobre el corte")
	free_rig(rig)


func test_velocirraptor_dos_variantes() -> void:
	var cache := {}
	var rec := build("velociraptor", "tumbado", cache)
	var film := build("velociraptor_pelicula", "tumbado", cache)
	var by_opt := Animal3D.build("velociraptor", "tumbado", size_of("velociraptor_pelicula"), { "cache": cache, "variant": "pelicula" })
	assert_eq(String(rec.get("variant")), "reconstruccion", "el id «velociraptor»: la reconstrucción")
	assert_eq(String(film.get("variant")), "pelicula", "el id «velociraptor_pelicula»: el de película")
	assert_eq(String(by_opt.get("variant")), "pelicula", "o la variante de opts (la de BODIES)")
	assert_eq(String(MovingCar.body_of("velociraptor_pelicula").variant), "pelicula", "BODIES y el dibujo, de acuerdo")
	assert_eq(AnimalArt.Theropod.variant_of({}), "pelicula", "variant_of(opts), como en la 4h")
	assert_eq(AnimalArt.Theropod.variant_of({}, "velociraptor"), "reconstruccion", "con el id, la reconstrucción")
	var mr: Dictionary = (rec.get("_data") as Dictionary).mats
	var mf: Dictionary = (film.get("_data") as Dictionary).mats
	for k: String in ["pluma", "remera", "rectriz"]:
		assert_true(mr.has(k), "la reconstrucción, con plumas (%s)" % k)
		assert_false(mf.has(k), "el de película, sin plumas (%s)" % k)
	assert_true(mf.has("diente") and not mr.has("diente"), "dientes a la vista solo en el de película (la reconstrucción, con labios)")
	var dr: Dictionary = rec.get("_data")
	assert_eq((dr.claws as Array).size(), 2, "dos garras en hoz, las que golpean (strike_claws)")
	assert_eq(int(MovingCar.body_of("velociraptor").strike_claws), 2, "como BODIES")
	# la hoz va levantada: su punta, por encima del suelo
	var xf := Rig3D.globals(dr, {})
	for c: Dictionary in dr.claws:
		var tip: Vector3 = (xf[c.tip_bone] as Transform3D) * ((c.tip as Vector3) - Rig3D._pivot_of(dr, c.tip_bone))
		assert_true(tip.y > 2.0, "la hoz, levantada (punta a %s cm del suelo)" % tip.y)
	# fit_box, como en la 4h: hasta la cadera (el alto del estado), sin la cabeza; full_box, entero
	for r: RefCounted in [rec, film]:
		var fb: Rect2 = r.get("fit_box")
		var full: Rect2 = r.get("full_box")
		var hip: Vector2 = (r.get("anchors") as Dictionary).hip
		assert_near(fb.end.y, hip.y, 1e-4, 1e-4, "fit_box llega a la cadera")
		assert_true(full.end.y > fb.end.y + 0.05, "la cabeza sobresale (full_box)")
	assert_near((rec.get("fit_box") as Rect2).size.y / (film.get("fit_box") as Rect2).size.y, 0.5 / 0.87, 0.03, 0.0, "las dos, a su cadera")
	# el salto llega como pose.leap o como pose.kick (la vista, en el golpe): la misma postura
	var bones: Dictionary = rec.get("bones")
	rec.pose({ "t": 0.0, "leap": 1.0 })
	var q_leap: Quaternion = (bones["dedoII_n_1"] as Node3D).quaternion
	var y_leap: float = (bones["cuerpo"] as Node3D).position.y
	rec.pose({ "t": 0.0 })
	assert_false((bones["dedoII_n_1"] as Node3D).quaternion.is_equal_approx(q_leap), "agazapado, la hoz levantada")
	rec.pose({ "t": 0.0, "kick": 1.0 })
	assert_true((bones["dedoII_n_1"] as Node3D).quaternion.is_equal_approx(q_leap), "con kick, la hoz baja como en el salto")
	assert_near((bones["cuerpo"] as Node3D).position.y, y_leap, 1e-5, 1e-5, "y el cuerpo se levanta igual")
	for r: RefCounted in [rec, film, by_opt]:
		free_rig(r)


## La pose de un animal cuesta poco (solo nodos y parámetros): cabe de sobra en un fotograma.
func test_coste_de_la_pose() -> void:
	var cache := {}
	var worst := 0.0
	var line := PackedStringArray()
	for id: String in AnimalArt.KINDS:
		var rig := build(id, AnimalArt.postures_of(id)[0], cache)
		var t0 := Time.get_ticks_usec()
		for i in 120:
			rig.pose({ "t": float(i) / 60.0, "live": true, "scared": 0.5, "leap": 0.3, "flutter": 0.5, "wing_open": 0.5, "kick": 0.3,
				"wind_local_ms": 20.0 })
		var us := float(Time.get_ticks_usec() - t0) / 120.0
		worst = maxf(worst, us)
		line.append("%s %d" % [id, int(us)])
		free_rig(rig)
	print("    (info) pose de los animales 3D, µs por fotograma: %s" % ", ".join(line))
	assert_true(worst < 2000.0, "la pose más cara, %s µs, cabe en un fotograma" % worst)


## Solo dibujo: en app/lab/animals/ no se calcula física (ni se llama al motor del coche en marcha); los tamaños y las
## garras salen del estado y del catálogo.
func test_sin_fisica_en_los_animales() -> void:
	var dir := DirAccess.open("res://app/lab/animals")
	var files := 0
	for f: String in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		files += 1
		# el código, sin los comentarios (que sí citan de dónde salen los datos)
		var code := PackedStringArray()
		for line: String in FileAccess.get_file_as_string("res://app/lab/animals/" + f).split("\n"):
			code.append(line.get_slice("#", 0))
		var src := "\n".join(code)
		for bad: String in ["moving_car.gd", "moving_car_state.gd", "physics.gd", "MovingCar.", "Physics."]:
			assert_false(src.contains(bad), "%s no usa %s" % [f, bad])
	assert_true(files >= 10, "se han revisado los archivos de los animales (%d)" % files)


## La postura «dormido» de la cetrería (unidad 5c): se construye en las especies de la cetrería, en el escritorio y en el
## teléfono, sin tocar las posturas del coche en marcha (AnimalArt.POSTURES); dormido, los ojos cerrados y la pose no
## crea nada; y la API de las garras para colgar ahí las de la cetrería (claw_index, claw_base, show_claw_mesh,
## posed_aabb).
func test_dormido_para_la_cetreria() -> void:
	var cache := {}
	for kind: String in AnimalArt.POSTURES:
		assert_false((AnimalArt.POSTURES[kind] as Array).has("dormido"), "%s: el coche en marcha no la usa" % kind)
	for id: String in RAPTORS + ["tigre", "oso", "velociraptor", "velociraptor_pelicula"]:
		for q: String in ["escritorio", "movil"]:
			var rig := build(id, "dormido", cache, { "quality": q })
			var root: Node3D = rig.get("root")
			var data: Dictionary = rig.get("_data")
			assert_true((data.postures as Dictionary).has("dormido"), "%s %s: tiene la postura" % [id, q])
			var leg := "hombro_n"
			if AnimalArt.kind_of(id) == "ave":
				leg = "tibia_n"
			elif AnimalArt.kind_of(id) == "teropodo":
				leg = "muslo_n"
			var n0 := count_nodes(root)
			for i in 30:
				rig.pose({ "t": float(i) / 30.0, "live": true, "asleep": true, "breath_hz": 0.25, "flinch": 1.0 if i < 10 else 0.0,
					"flinch_leg": leg })
			assert_eq(count_nodes(root), n0, "%s %s: dormido, la pose no crea nodos" % [id, q])
			for s: String in ["_n", "_f"]:
				var lid: Node3D = (rig.get("bones") as Dictionary).get("parpado" + s)
				if lid != null:
					assert_true(lid.visible, "%s: los ojos cerrados" % id)
			var claws: Array = rig.get("claws")
			for i in claws.size():
				var nm := String(claws[i].name)
				assert_eq(int(rig.call("claw_index", nm)), i, "%s: la garra %s por su nombre" % [id, nm])
			var nb: Array = rig.call("claw_base", 0)
			assert_true(nb[0] is Node3D and nb[1] is Transform3D, "%s: el marco de la base de una garra" % id)
			var b: Basis = (nb[1] as Transform3D).basis
			assert_near(b.x.dot(b.y), 0.0, 0.0, 1e-5, "%s: el marco de la base es ortogonal" % id)
			rig.call("show_claw_mesh", 0, false)
			var mi := (nb[0] as Node3D).get_node_or_null("Malla") as MeshInstance3D
			assert_true(mi == null or not mi.visible, "%s: la garra del modelo se esconde" % id)
			var box: AABB = rig.call("posed_aabb")
			assert_true(box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0, "%s: su caja entera" % id)
			free_rig(rig)
	# el coche en marcha no cambia: el tigre tumbado sale igual con la caché que ya tiene «dormido»
	var a := build("tigre", "tumbado", cache)
	var a2 := build("tigre", "tumbado", {})
	assert_eq(var_to_str(a.get("fit_box")), var_to_str(a2.get("fit_box")), "el tigre tumbado del coche, igual")
	free_rig(a)
	free_rig(a2)
