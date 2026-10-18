## Laboratorio experimental de la reforja · piezas de la escena hechas en código (solo dibujo, sin descargas): materiales,
## mallas básicas, rótulos y las mallas propias (la escala y el margen de un dial, la bobina de inducción, el cristal
## octaédrico del diamante, la bola de Verneuil y la llama). Funciones estáticas sin estado; lo que devuelven se usa una
## vez al construir la escena (forge_3d.gd), nunca en cada fotograma.
## Unidades: metros.
extends RefCounted

const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## El arco de un dial: de 225° (abajo a la izquierda, el mínimo) a −45° (abajo a la derecha, el máximo), 270° en total.
const DIAL_A0 := 225.0
const DIAL_SPAN := 270.0


## Ángulo (rad, desde +X en el plano del dial) de la posición t (0-1) de un dial.
static func dial_angle(t: float) -> float:
	return deg_to_rad(DIAL_A0 - DIAL_SPAN * clampf(t, 0.0, 1.0))


static func mat(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func glass_mat(tint := Color(0.85, 0.92, 1.0, 0.16)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Material que brilla (sin luz propia del entorno): la llama, el plasma, el chorro de metal, los resaltados.
static func glow_mat(color: Color, energy: float, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = false
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## La capa del brillo del calor que va encima del material de una pieza (material_overlay): negra y aditiva, solo su
## emisión (el color y la energía los pone la escena con la rampa de core), sin escribir profundidad. Así el material de
## la biblioteca de las garras, que se comparte, no se toca.
static func heat_overlay() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0)
	m.metallic_specular = 0.0
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


static func mi(parent: Node, mesh: Mesh, m: Material, n: String, pos := Vector3.ZERO) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.name = n
	x.mesh = mesh
	x.material_override = m
	x.position = pos
	parent.add_child(x)
	return x


static func node(parent: Node, n: String, pos := Vector3.ZERO) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	parent.add_child(x)
	return x


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, seg := 24, caps := true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return c


static func sphere(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = 2.0 * r
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	return s


static func torus(inner: float, outer: float, seg := 32) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = seg
	t.ring_segments = 8
	return t


static func label(parent: Node, text: String, pos: Vector3, px := 0.0006, color := Color(0.95, 0.93, 0.9), size := 32) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	l.position = pos
	l.double_sided = false
	l.no_depth_test = false
	parent.add_child(l)
	return l


## Una banda de anillo en el plano XY (la cara de un dial, mirando a +Z): de r0 a r1 y de a0 a a1 (rad), en z.
static func arc_arrays(r0: float, r1: float, a0: float, a1: float, z: float, seg := 32) -> Array:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := maxi(seg, 2)
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		var d := Vector3(cos(a), sin(a), 0.0)
		v.append(d * r0 + Vector3(0, 0, z))
		v.append(d * r1 + Vector3(0, 0, z))
		nrm.append(Vector3.BACK)
		nrm.append(Vector3.BACK)
	for i in n:
		var o := i * 2
		idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	return _pack(v, nrm, idx)


## Las marcas de la escala de un dial: count marcas de r0 a r1 (las de cada major, más largas), en z.
static func ticks_arrays(r0: float, r1: float, count: int, major: int, z: float, width: float) -> Array:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var a := dial_angle(t)
		var d := Vector3(cos(a), sin(a), 0.0)
		var side := Vector3(-d.y, d.x, 0.0) * (width * (1.6 if i % major == 0 else 1.0) * 0.5)
		var rin := r0 - (r1 - r0) * (0.6 if i % major == 0 else 0.0)
		var o := v.size()
		v.append_array([d * rin - side + Vector3(0, 0, z), d * rin + side + Vector3(0, 0, z), d * r1 - side + Vector3(0, 0, z), d * r1 + side + Vector3(0, 0, z)])
		for k in 4:
			nrm.append(Vector3.BACK)
		idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	return _pack(v, nrm, idx)


## Un tubo enrollado en hélice (la bobina de inducción) alrededor de Y: radio, radio del tubo, vueltas y alto.
static func helix_arrays(radius: float, tube_r: float, turns: float, height: float, seg_per_turn := 32, ring := 8) -> Array:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := int(turns * float(seg_per_turn))
	for i in n + 1:
		var u := float(i) / float(n)
		var a := u * turns * TAU
		var c := Vector3(cos(a) * radius, -height * 0.5 + height * u, sin(a) * radius)
		var t := Vector3(-sin(a) * radius * turns * TAU, height, cos(a) * radius * turns * TAU).normalized()
		var nr := Vector3(cos(a), 0.0, sin(a))
		var bn := t.cross(nr).normalized()
		for j in ring:
			var b := float(j) / float(ring) * TAU
			var d := nr * cos(b) + bn * sin(b)
			v.append(c + d * tube_r)
			nrm.append(d)
	for i in n:
		for j in ring:
			var a0 := i * ring + j
			var a1 := i * ring + (j + 1) % ring
			var b0 := (i + 1) * ring + j
			var b1 := (i + 1) * ring + (j + 1) % ring
			idx.append_array([a0, b0, a1, a1, b0, b1])
	return _pack(v, nrm, idx)


## Un octaedro (el hábito del cristal de diamante) de semieje r, con las caras planas.
static func octahedron_arrays(r: float) -> Array:
	var p := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4], [3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	for f: Array in faces:
		var a: Vector3 = p[f[0]]
		var b: Vector3 = p[f[1]]
		var c: Vector3 = p[f[2]]
		var n := (b - a).cross(c - a).normalized()
		var o := v.size()
		v.append_array([a, b, c])
		nrm.append_array([n, n, n])
		idx.append_array([o, o + 2, o + 1])
	return _pack(v, nrm, idx)


static func _pack(v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


static func array_mesh(arrays: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Cambia la malla de un ArrayMesh por otra (al cambiar de forma, no en cada fotograma).
static func set_arrays(m: ArrayMesh, arrays: Array) -> void:
	m.clear_surfaces()
	if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
