## Cetrería · los cuerpos de alta definición (unidad 5i: app/lab/cetreria/care_body.gd y body_*.gd), sin ventana: cada
## animal (las seis rapaces, el tigre, el oso y los dos velocirraptores) tiene su cuerpo hecho desde cero, con sus partes
## (plumas, pelo en capas, escamas, ojos con párpados) y del tamaño de su ficha; se hace una vez por animal y calidad (la
## segunda vez, de la caché: las mismas mallas) y el del teléfono es más ligero; los miembros del cuerpo pasan el anclaje
## de cada pata y la rodean (sin juntura); el atrezo sale con la sujeción, los ojos se cierran con la sedación, y en cada
## fotograma no se crea nada.
extends "res://tests/case.gd"

const CareAnimal = preload("res://app/lab/cetreria/care_animal.gd")
const CareBody = preload("res://app/lab/cetreria/care_body.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const BodyMammal = preload("res://app/lab/cetreria/body_mammal.gd")
const BodyDino = preload("res://app/lab/cetreria/body_dino.gd")
const Js = preload("res://core/shared/js.gd")

## [animal, garra del banco (las rapaces), dibujo del velocirraptor]
const CASES := [["rapaz", "aguila", ""], ["rapaz", "arpia", ""], ["rapaz", "halcon", ""], ["rapaz", "buho", ""], ["rapaz", "lechuza", ""],
	["rapaz", "buitre", ""], ["tigre", "", ""], ["oso", "", ""], ["velociraptor", "", ""], ["velociraptor", "", "pelicula"]]
const FRAME := 1.0 / 30.0


func _build(c: Array, cache: Dictionary, mobile := false) -> Dictionary:
	var host := Node3D.new()
	add_to_tree(host)
	return CareAnimal.build(host, String(c[0]), String(c[1]), { "mobile": mobile, "cache": cache, "model": String(c[2]) })


## Las mallas del cuerpo por nombre de nodo (las de las capas del pelo, con su MultiMesh).
static func _parts(n: Node, out: Dictionary) -> Dictionary:
	if n is MeshInstance3D:
		out[String(n.name)] = (n as MeshInstance3D).mesh
	elif n is MultiMeshInstance3D:
		out[String(n.name)] = (n as MultiMeshInstance3D).multimesh
	for ch in n.get_children():
		_parts(ch, out)
	return out


static func _verts(parts: Dictionary) -> int:
	var v := 0
	for k: String in parts:
		var m: Variant = parts[k]
		if m is ArrayMesh:
			for si in (m as ArrayMesh).get_surface_count():
				v += ((m as ArrayMesh).surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return v


static func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


## Los vértices de una malla de un nodo, en el marco de la raíz del animal.
static func _root_verts(mi: MeshInstance3D, root: Node) -> PackedVector3Array:
	var xf := CareAnimal.rel_xf(mi, root)
	var out := PackedVector3Array()
	var am := mi.mesh as ArrayMesh
	if am == null:
		return out
	for si in am.get_surface_count():
		for v: Vector3 in am.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func test_cada_animal_con_su_cuerpo_de_alta_definicion() -> void:
	var cache := {}
	var sizes := PackedStringArray()
	for c: Array in CASES:
		var rig := _build(c, cache)
		var body: Dictionary = rig.body
		var art := String(rig.art)
		var parts := _parts(body.root as Node, {})
		assert_true(parts.has("Cuerpo") and parts.has("Cabeza"), "%s: el cuerpo y la cabeza" % art)
		assert_true(parts.has("Ojo_d") and parts.has("Parpado_d_sup") and parts.has("Parpado_d_inf"), "%s: los ojos con sus párpados" % art)
		assert_eq((body.lids as Array).size(), 4, "%s: cuatro párpados que se mueven" % art)
		match String(body.kind):
			"ave":
				assert_true(parts.has("Plumas") and parts.has("PlumasCabeza"), "%s: las plumas en capas del cuerpo, las alas, la cola y la cabeza" % art)
				assert_true(parts.has("Muslos_pelo") and parts.has("Pico"), "%s: los calzones con capas y el pico" % art)
			"mamifero":
				assert_true(parts.has("Cuerpo_pelo") and parts.has("Cabeza_pelo") and parts.has("Cola_pelo"), "%s: el pelo en capas" % art)
				# (5t-B: en la cetrería, las orejas y los bigotes de cada lado van en su pivote)
				assert_true((parts.has("Orejas") or parts.has("Oreja_d") and parts.has("Oreja_i")) and parts.has("Trufa") and parts.has("Labios"), "%s: las orejas, la trufa y los labios" % art)
				if art == "tigre":
					assert_true(parts.has("Bigotes") or parts.has("Bigotes_d") and parts.has("Bigotes_i"), "el tigre, con sus bigotes")
			"teropodo":
				assert_true(parts.has("GarrasManos") and parts.has("Boca"), "%s: las garras de las manos y la boca" % art)
				if art == "velociraptor":
					assert_true(parts.has("Plumas") and parts.has("Cuerpo_pelo") and parts.has("Cabeza_pelo"), "la reconstrucción, con plumas (las alas, la cola y las capas)")
				else:
					assert_true(parts.has("Dientes") and not parts.has("Cuerpo_pelo") and not parts.has("Plumas"), "el de película: escamas y dientes, sin plumas")
		# del tamaño de su ficha: lo largo del cuerpo tumbado (a lo largo de la mesa, z) frente al largo de dibujo (en el
		# tigre y el oso, con la cola, que se curva)
		var want := CareAnatomy.draw_length_m(art)
		if String(body.kind) == "mamifero":
			want += CareAnatomy.value(art, "tail_m", 0.0) * 0.85
		var got := (body.box as AABB).size.z
		sizes.append("%s %s m (%s)" % [art, Js.to_fixed(got, 2), Js.to_fixed(want, 2)])
		assert_true(got > want * 0.75 and got < want * 1.3, "%s: %s m de largo tumbado, con %s m de ficha" % [art, Js.to_fixed(got, 2), Js.to_fixed(want, 2)])
	print("    (info) largo de cada cuerpo tumbado (y el de su ficha): %s" % ", ".join(sizes))


func test_una_vez_por_animal_y_calidad_y_mas_ligero_en_el_telefono() -> void:
	var cache := {}
	var line := PackedStringArray()
	for c: Array in CASES:
		var t0 := Time.get_ticks_usec()
		var a := _build(c, cache)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var t1 := Time.get_ticks_usec()
		var b := _build(c, cache)
		var ms_cache := float(Time.get_ticks_usec() - t1) / 1000.0
		var art := String(a.art)
		assert_true(bool((a.body as Dictionary).fresh), "%s: la primera vez se hace" % art)
		assert_false(bool((b.body as Dictionary).fresh), "%s: la segunda, de la caché" % art)
		var pa := _parts((a.body as Dictionary).root as Node, {})
		var pb := _parts((b.body as Dictionary).root as Node, {})
		var same := true
		for k: String in pa:
			if pb.get(k) != pa[k]:
				same = false
		assert_true(same, "%s: la segunda vez, las mismas mallas (los mismos recursos)" % art)
		var t2 := Time.get_ticks_usec()
		var m := _build(c, cache, true)
		var ms_phone := float(Time.get_ticks_usec() - t2) / 1000.0
		var pm := _parts((m.body as Dictionary).root as Node, {})
		var vd := _verts(pa)
		var vm := _verts(pm)
		assert_true(vm < int(vd * 0.7), "%s: el del teléfono, más ligero (%d vértices frente a %d)" % [art, vm, vd])
		for k: String in pa:
			if pa[k] is MultiMesh:
				assert_eq((pa[k] as MultiMesh).instance_count, int(CareBody.FUR_LAYERS.escritorio), "%s: %s capas de pelo en el escritorio" % [art, k])
				assert_eq((pm[k] as MultiMesh).instance_count, int(CareBody.FUR_LAYERS.movil), "%s: menos capas en el teléfono" % art)
		line.append("%s %s ms (caché %s ms, teléfono %s ms; %d/%d vértices)" % [art, Js.to_fixed(ms, 0), Js.to_fixed(ms_cache, 0), Js.to_fixed(ms_phone, 0), vd, vm])
	print("    (info) construir cada animal con su cuerpo: %s" % ", ".join(line))


## El miembro del cuerpo llega al anclaje de cada pata y lo pasa: justo después de la articulación (a lo largo de la pata),
## hay piel del cuerpo alrededor de la de la pata, por los ocho lados (no queda juntura).
func test_los_miembros_pasan_el_anclaje_y_rodean_la_pata() -> void:
	var cache := {}
	for c: Array in CASES:
		var rig := _build(c, cache)
		var art := String(rig.art)
		var root: Node3D = rig.root
		var body_root: Node = (rig.body as Dictionary).root
		var verts := PackedVector3Array()
		# (5t-B: la pata de arriba lleva su muslo o su brazo, y la manga, en sus pivotes)
		for k: String in ["Cuerpo", "Muslos", "MusloGolpe", "BrazoGolpe", "PiernaGolpe", "MangaGolpe"]:
			var mi := body_root.find_child(k, true, false) as MeshInstance3D
			if mi != null:
				verts.append_array(_root_verts(mi, root))
		var anchors: Dictionary = rig.anchors
		for p: String in anchors:
			var an: Transform3D = anchors[p]
			var ax := an.basis.x.normalized()
			var ay := an.basis.y.normalized()
			var az := ax.cross(ay).normalized()
			# el grosor de la pata junto a la articulación (sus vértices justo después: en 1 cm, o en 2 o 4 si no hay)
			var pnode: Node3D = (rig.paw_nodes as Dictionary)[p].node
			var pv := PackedVector3Array()
			for mi: Node in pnode.find_children("*", "MeshInstance3D", true, false):
				pv.append_array(_root_verts(mi as MeshInstance3D, root))
			var r_paw := 0.0
			for w: float in [0.01, 0.02, 0.04]:
				var found := 0
				for v: Vector3 in pv:
					var d := v - an.origin
					var along := d.dot(ax)
					if along > 0.0 and along < w:
						r_paw = maxf(r_paw, (d - ax * along).length())
						found += 1
				if found >= 6:
					break
			var sectors := [false, false, false, false, false, false, false, false]
			for v: Vector3 in verts:
				var d := v - an.origin
				var along := d.dot(ax)
				if along < 0.002 or along > 0.02:
					continue
				var rad := d - ax * along
				var rl := rad.length()
				if rl < r_paw * 0.85 or rl > maxf(r_paw * 3.0, 0.02):
					continue
				var ang := atan2(rad.dot(az), rad.dot(ay))
				sectors[int(floor((ang + PI) / TAU * 8.0)) % 8] = true
			var filled := 0
			for sct: bool in sectors:
				filled += 1 if sct else 0
			assert_eq(filled, 8, "%s, %s: el cuerpo pasa el anclaje y rodea la pata (de %s mm) por los ocho lados" % [art, p, Js.to_fixed(r_paw * 1000.0, 0)])


func test_el_atrezo_sale_con_la_sujecion() -> void:
	var cache := {}
	for c: Array in [["rapaz", "aguila", ""], ["tigre", "", ""], ["velociraptor", "", ""]]:
		var rig := _build(c, cache)
		var art := String(rig.art)
		var props: Dictionary = rig.props
		var bird := String(c[0]) == "rapaz"
		var vis := func(k: String) -> bool: return props.has(k) and (props[k] as Node3D).visible
		CareAnimal.set_sedation(rig, "libre")
		assert_false(vis.call("wrap") or vis.call("hood") or vis.call("mask") or vis.call("clip"), "%s: libre, sin nada encima" % art)
		CareAnimal.set_sedation(rig, "sujecion")
		if bird:
			assert_true(vis.call("wrap") and vis.call("hood"), "la rapaz sujeta: la toalla y la capucha")
			assert_false(((rig.body as Dictionary).head_cards as Node3D).visible, "con la capucha puesta, las plumas de la cabeza van debajo")
		CareAnimal.set_sedation(rig, "anestesia")
		assert_true(vis.call("mask"), "%s anestesiado: la mascarilla del isoflurano" % art)
		if bird:
			assert_true(vis.call("wrap") and not vis.call("hood"), "la rapaz anestesiada: con la toalla y sin la capucha")
		else:
			assert_true(vis.call("clip"), "%s anestesiado: la pinza del pulsioxímetro en la lengua" % art)


func test_los_ojos_se_cierran_con_la_sedacion() -> void:
	var cache := {}
	for c: Array in [["rapaz", "buho", ""], ["tigre", "", ""], ["velociraptor", "", "pelicula"]]:
		var rig := _build(c, cache)
		var art := String(rig.art)
		var body: Dictionary = rig.body
		CareAnimal.set_sedation(rig, "libre")
		var t := 0.0
		for i in 60:
			t += FRAME
			CareAnimal.animate(rig, t, "libre", 0.0, "")
		assert_true(float(body.open) > 0.9, "%s: despierto, los ojos abiertos (%s)" % [art, Js.to_fixed(float(body.open), 2)])
		assert_true(_lid_max_deg(body) > 20.0, "%s: los párpados, girados para abrir (%s°)" % [art, Js.to_fixed(_lid_max_deg(body), 0)])
		CareAnimal.set_sedation(rig, "anestesia")
		for i in 90:
			t += FRAME
			CareAnimal.animate(rig, t, "anestesia", 0.0, "")
		assert_true(float(body.open) < 0.05, "%s: anestesiado, los ojos cerrados (%s)" % [art, Js.to_fixed(float(body.open), 2)])
		assert_true(_lid_max_deg(body) < 3.0, "%s: los párpados, cerrados (%s°)" % [art, Js.to_fixed(_lid_max_deg(body), 1)])
		assert_eq(float((body.eye_mat as ShaderMaterial).get_shader_parameter("pupil_open")), 0.8, "%s: la pupila, dilatada con la anestesia" % art)


static func _lid_max_deg(body: Dictionary) -> float:
	var m := 0.0
	for lid: Dictionary in body.lids:
		m = maxf(m, rad_to_deg((lid.node as Node3D).transform.basis.get_rotation_quaternion().get_angle()))
	return m


func test_en_cada_fotograma_no_se_crea_nada() -> void:
	var cache := {}
	for c: Array in [["rapaz", "aguila", ""], ["oso", "", ""], ["velociraptor", "", ""]]:
		var rig := _build(c, cache)
		var art := String(rig.art)
		var root: Node3D = rig.root
		CareAnimal.set_sedation(rig, "libre")
		CareAnimal.animate(rig, 0.0, "libre", 0.0, "")
		var nodes := _count_nodes(root)
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var t := 0.0
		var seds := ["libre", "sujecion", "sedacion", "anestesia"]
		for i in 120:
			t += FRAME
			var sed := String(seds[(i / 30) % 4])
			if i % 30 == 0:
				CareAnimal.set_sedation(rig, sed)
			CareAnimal.animate(rig, t, sed, 0.8 if i % 30 > 20 else 0.0, String((rig.anchors as Dictionary).keys()[0]))
		assert_eq(_count_nodes(root), nodes, "%s: los fotogramas no crean nodos" % art)
		assert_eq(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "%s: ni objetos (la respiración, los párpados y el respingo solo mueven lo que hay)" % art)


## Lo más alto (x) y el medio ancho (y) de los vértices de una cabeza en una franja de x, en su marco.
static func _band(v: PackedVector3Array, x: float, w: float) -> Vector2:
	var top := -INF
	var half := 0.0
	for p: Vector3 in v:
		if absf(p.x - x) < w:
			top = maxf(top, p.y)
			half = maxf(half, absf(p.z))
	return Vector2(top, half)


static func _max_x(v: PackedVector3Array) -> float:
	var m := -INF
	for p: Vector3 in v:
		m = maxf(m, p.x)
	return m


## Las cabezas de la 5n tienen su forma y sus partes: el hocico del oso y del tigre, más estrecho que los pómulos, con la
## trufa en la punta; el oso, con el perfil cóncavo (la frente, más alta que el escalón del hocico); el velocirraptor de la
## reconstrucción, con el hocico estrecho del cráneo medido, la punta algo levantada, la boca y las narinas, y sin dientes
## a la vista (los labios los tapan).
func test_las_cabezas_tienen_su_forma_y_sus_partes() -> void:
	var claw := { "base_r_mm": 6.0, "length_mm": 40.0 }
	for art: String in ["oso", "tigre"]:
		var m: Dictionary = BodyMammal.model(art, {}, claw, false)
		var parts: Dictionary = m.parts
		for k: String in ["Cabeza", "Trufa", "Labios", "Oreja_d", "Oreja_i", "Ojo_d", "Ojo_i"]:
			assert_true(parts.has(k), "%s: la cabeza, con %s" % [art, k])
		var L := float((m.layout as Dictionary).head_len)
		var v: PackedVector3Array = ((parts.Cabeza as Dictionary).arrays as Array)[Mesh.ARRAY_VERTEX]
		var cheeks := _band(v, -L * 0.06, L * 0.02)
		var stop := _band(v, L * 0.18, L * 0.02)
		var muzzle := _band(v, L * 0.34, L * 0.02)
		assert_true(muzzle.y < cheeks.y * 0.8, "%s: el hocico (%s m de medio ancho), más estrecho que los pómulos (%s m)" % [art, Js.to_fixed(muzzle.y, 3), Js.to_fixed(cheeks.y, 3)])
		if art == "oso":
			assert_true(cheeks.x - stop.x > 0.01, "el oso: la frente (%s m), más alta que el escalón del hocico (%s m): el perfil cóncavo" % [Js.to_fixed(cheeks.x, 3), Js.to_fixed(stop.x, 3)])
		var nose: PackedVector3Array = ((parts.Trufa as Dictionary).arrays as Array)[Mesh.ARRAY_VERTEX]
		assert_true(_max_x(nose) >= _max_x(v) - 0.002, "%s: la trufa, en la punta del hocico" % art)
	assert_true((BodyMammal.model("tigre", {}, claw, false).parts as Dictionary).has("Bigotes_d"), "el tigre, con sus bigotes")
	var d: Dictionary = BodyDino.model("velociraptor", {}, { "base_r_mm": 13.9, "length_mm": 65.0 }, false)
	var dp: Dictionary = d.parts
	for k: String in ["Cabeza", "Boca", "Narinas", "Ojo_d", "Ojo_i"]:
		assert_true(dp.has(k), "el velocirraptor: la cabeza, con %s" % k)
	assert_false(dp.has("Dientes"), "la reconstrucción, sin dientes a la vista: los tapan los labios (Cullen et al. 2023)")
	var Lr := float((d.layout as Dictionary).head_len)
	assert_near(Lr, CareAnatomy.value("velociraptor", "skull_m") * float(CareAnatomy.head_draw("velociraptor", "skin_k", 1.0)), 0.0, 1e-6,
		"la cabeza, del largo del cráneo medido con su piel")
	var vr: PackedVector3Array = ((dp.Cabeza as Dictionary).arrays as Array)[Mesh.ARRAY_VERTEX]
	var back := _band(vr, -Lr * 0.3, Lr * 0.02)
	var snout := _band(vr, Lr * 0.2, Lr * 0.02)
	assert_true(snout.y < back.y * 0.45, "el velocirraptor: el hocico (%s m de medio ancho), estrecho frente al cráneo (%s m)" % [Js.to_fixed(snout.y, 4), Js.to_fixed(back.y, 4)])
	var dip := _band(vr, Lr * 0.3, Lr * 0.02)
	var tip := _band(vr, Lr * 0.4, Lr * 0.02)
	assert_true(tip.x > dip.x, "el velocirraptor: la punta del hocico, algo levantada sobre la narina (%s m frente a %s m)" % [Js.to_fixed(tip.x, 4), Js.to_fixed(dip.x, 4)])


## La mascarilla queda sobre el hocico: la punta del hocico (la trufa o la del velocirraptor) dentro del cono, y el borde del
## cono delante de los ojos (los ojos, fuera).
func test_la_mascarilla_queda_sobre_el_hocico() -> void:
	var cache := {}
	for c: Array in [["oso", "", ""], ["tigre", "", ""], ["velociraptor", "", ""]]:
		var rig := _build(c, cache)
		var art := String(rig.art)
		CareAnimal.set_sedation(rig, "anestesia")
		var body: Dictionary = rig.body
		var head: Node3D = body.head
		var mask: Node3D = (body.props as Dictionary).mask
		var cone := mask.get_node("Cono") as MeshInstance3D
		var box := AABB()
		var first := true
		for p: Vector3 in (cone.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
		var tip_mesh := head.get_node_or_null("Trufa") as MeshInstance3D
		if tip_mesh == null:
			tip_mesh = head.get_node("Cabeza") as MeshInstance3D
		var tip := Vector3(-INF, 0.0, 0.0)
		for p: Vector3 in (tip_mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if p.x > tip.x:
				tip = p
		assert_true(box.grow(0.002).has_point(tip), "%s: la punta del hocico, dentro de la mascarilla" % art)
		var eye := CareAnimal.rel_xf(head.find_child("Ojo_d", true, false) as Node3D, head).origin
		assert_true(box.position.x > eye.x, "%s: el borde de la mascarilla, delante de los ojos" % art)
		assert_true(mask.visible, "%s: anestesiado, con la mascarilla puesta" % art)
