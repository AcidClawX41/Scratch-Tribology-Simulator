## El paisaje del coche en marcha (unidad 4x, petición de Eric del 18-10-2026): el campo verde, los árboles y las montañas
## de fondo de la cámara de persecución, y una carretera sin fin. Solo dibujo: no cambia ningún número de la física ni del
## viento.
##   - El campo: dos tiras a los lados de la carretera larga (road_curve.gd, la de la persecución), desde su arcén hasta
##     FIELD_W m, que siguen su trazado en el sombreador (scenery_path.gdshaderinc: el mismo eje y lo recorrido que el asfalto).
##     Más allá, un suelo grande del mismo verde bajo la cámara; la niebla del entorno (car_scene.gd) funde la lejanía.
##   - Los árboles: tres especies (conífera, frondosa y chopo) hechas aquí con volumen (tronco y copa), un MultiMesh por
##     especie con su sitio en la carretera (a lo largo y de lado) en INSTANCE_CUSTOM, repartidos con la semilla de rng.gd,
##     más densos lejos que junto al arcén y a veces en grupos; menos en el teléfono. Corren con lo recorrido y vuelven a
##     entrar por delante (a = x0 + (a0 − recorrido) mód. largo), siempre fuera del asfalto.
##   - Las montañas: dos anillos de siluetas alrededor de la cámara con el color de la lejanía (scenery_mountain.gdshader),
##     que giran con el rumbo del coche (car_scene.car_heading, el de la 4w) y van donde está la cámara (sin paralaje).
## En cada fotograma no se crea nada: set_path() y follow() solo cambian parámetros y una posición.
## Coordenadas: las de car_scene.gd (m; x a lo largo hacia el morro, y arriba, z a la derecha del coche).
extends Node3D

const Rng = preload("res://core/shared/rng.gd")
const GROUND_SHADER = preload("res://app/lab/car3d/scenery_ground.gdshader")
const TREE_SHADER = preload("res://app/lab/car3d/scenery_tree.gdshader")
const MOUNTAIN_SHADER = preload("res://app/lab/car3d/scenery_mountain.gdshader")

## Lo ancho del campo a cada lado (m, desde el eje de la carretera) y lo lejos que se ponen los árboles.
const FIELD_W := 180.0
const TREE_FAR := 150.0
## Árboles de cada especie: [escritorio, teléfono].
const TREES := { "conifera": [240, 80], "frondosa": [340, 110], "chopo": [150, 50] }
## Alto de cada especie (m): [mínimo, máximo].
const HEIGHT := { "conifera": [8.0, 15.0], "frondosa": [6.0, 11.0], "chopo": [10.0, 17.0] }
## Las montañas: radio de cada capa (m), alto de lo más bajo y de lo más alto (m) y vueltas de la silueta.
const MOUNTAINS := [{ "r": 560.0, "lo": 25.0, "hi": 95.0 }, { "r": 820.0, "lo": 55.0, "hi": 165.0 }]
const MOUNTAIN_SEGS := [256, 128]

var built := false
var mobile := false
var _ground_mat: ShaderMaterial
var _tree_mat: ShaderMaterial
var _mountain_mat: ShaderMaterial
var _mountains: MeshInstance3D
var _far: MeshInstance3D
var _trees: Array = []
## Cuántos árboles hay de cada especie y dónde está cada uno (a0, z, alto, giro): lo leen los tests (el servidor de render
## de los tests sin ventana no guarda los datos de las instancias).
var tree_counts := {}
var placements: Array[Color] = []


## Construye el paisaje (una vez) para la carretera larga de x0 a x1 m a lo largo, con su eje a axis_z y su arcén hasta
## edge_z m de lado desde el eje. p_mobile: menos árboles y mallas más ligeras.
func build(x0: float, x1: float, axis_z: float, edge_z: float, p_mobile: bool) -> void:
	if built:
		return
	built = true
	mobile = p_mobile
	name = "Paisaje"
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_SHADER
	_ground_mat.set_shader_parameter("edge_z", edge_z)
	_ground_mat.set_shader_parameter("axis_z", axis_z)
	_tree_mat = ShaderMaterial.new()
	_tree_mat.shader = TREE_SHADER
	for m: ShaderMaterial in [_ground_mat, _tree_mat]:
		m.set_shader_parameter("x0", x0)
		m.set_shader_parameter("x1", x1)
	_build_ground(x0, x1, axis_z, edge_z)
	_build_trees(x0, x1, axis_z, edge_z)
	_build_mountains()


func _build_ground(x0: float, x1: float, axis_z: float, edge_z: float) -> void:
	var start := edge_z - 0.6
	for s: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "Campo" + ("Izquierda" if s < 0.0 else "Derecha")
		var pm := PlaneMesh.new()
		pm.size = Vector2(x1 - x0, FIELD_W - start)
		pm.subdivide_width = 47 if mobile else 95
		pm.subdivide_depth = 11 if mobile else 23
		pm.center_offset = Vector3((x0 + x1) * 0.5, 0.0, axis_z + s * (start + FIELD_W) * 0.5)
		mi.mesh = pm
		mi.material_override = _ground_mat
		mi.extra_cull_margin = 16384.0  # el sombreador lo saca de su caja al doblarlo con la curva
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_far = MeshInstance3D.new()
	_far.name = "SueloLejano"
	var fm := PlaneMesh.new()
	fm.size = Vector2(4000.0, 4000.0)
	_far.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.32, 0.13)
	mat.roughness = 1.0
	_far.material_override = mat
	_far.position.y = -1.2
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_far)


func _build_trees(x0: float, x1: float, axis_z: float, edge_z: float) -> void:
	var rng := Rng.new(Rng.seed_of("paisaje:arboles"))
	var len := x1 - x0
	for sp: String in TREES:
		var n := int(TREES[sp][1 if mobile else 0])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = tree_mesh(sp, mobile)
		mm.instance_count = n
		var last := Vector2.ZERO
		for i in n:
			var a := x0 + rng.next() * len
			var side := -1.0 if rng.next() < 0.5 else 1.0
			# más lejos, más árboles: la distancia al arcén con densidad que crece con ella (√u)
			var d := 3.0 + (TREE_FAR - 3.0) * sqrt(rng.next())
			var z := axis_z + side * (edge_z + d)
			if i > 0 and rng.next() < 0.3:
				# en grupo, junto al anterior (sin acercarse al arcén)
				a = last.x + (rng.next() - 0.5) * 14.0
				var zd := absf(last.y - axis_z) + (rng.next() - 0.5) * 10.0
				z = axis_z + signf(last.y - axis_z) * maxf(zd, edge_z + 3.0)
			last = Vector2(a, z)
			var hr: Array = HEIGHT[sp]
			var h := lerpf(float(hr[0]), float(hr[1]), rng.next())
			mm.set_instance_transform(i, Transform3D.IDENTITY)
			var cd := Color(a, z, h, rng.next() * TAU)
			mm.set_instance_custom_data(i, cd)
			placements.append(cd)
			var tint := 0.85 + 0.3 * rng.next()
			mm.set_instance_color(i, Color(tint * (0.95 + 0.1 * rng.next()), tint, tint * (0.9 + 0.1 * rng.next())))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Arboles_" + sp
		mmi.multimesh = mm
		mmi.material_override = _tree_mat
		mmi.custom_aabb = AABB(Vector3(-2000.0, -10.0, -2000.0), Vector3(4000.0, 220.0, 4000.0))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_trees.append(mmi)
		tree_counts[sp] = n


func _build_mountains() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := int(MOUNTAIN_SEGS[1 if mobile else 0])
	for li in MOUNTAINS.size():
		var m: Dictionary = MOUNTAINS[li]
		var rng := Rng.new(Rng.seed_of("paisaje:montanas:%d" % li))
		# la silueta: una suma de ondas de alto y fase al azar (fijas), cerrada en la vuelta
		var waves: Array = []
		for k in 6:
			waves.append([float(2 + k * (2 + li)) + float(k), rng.next() * TAU, (0.55 / float(k + 1)) * (0.6 + 0.8 * rng.next())])
		var hs := PackedFloat32Array()
		for i in segs + 1:
			var phi := TAU * float(i) / float(segs)
			var v := 0.0
			for w: Array in waves:
				v += float(w[2]) * sin(phi * float(w[0]) + float(w[1]))
			hs.append(0.5 + 0.5 * tanh(v * 1.4))  # sin mesetas: las crestas se acercan al alto máximo sin aplanarse
		for i in segs:
			var p0 := TAU * float(i) / float(segs)
			var p1 := TAU * float(i + 1) / float(segs)
			var h0 := lerpf(float(m.lo), float(m.hi), hs[i])
			var h1 := lerpf(float(m.lo), float(m.hi), hs[i + 1])
			var r := float(m.r)
			var b0 := Vector3(cos(p0) * r, -30.0, sin(p0) * r)
			var b1 := Vector3(cos(p1) * r, -30.0, sin(p1) * r)
			var t0 := Vector3(cos(p0) * r, h0, sin(p0) * r)
			var t1 := Vector3(cos(p1) * r, h1, sin(p1) * r)
			# la pendiente en cada vértice (central: el lado al sol se sombrea sin franjas)
			var s0 := clampf((hs[(i + 1) % segs] - hs[(i - 1 + segs) % segs]) * float(segs) * 0.08, -1.0, 1.0)
			var s1 := clampf((hs[(i + 2) % segs] - hs[i % segs]) * float(segs) * 0.08, -1.0, 1.0)
			var tri := [[b0, p0, 0.0, s0], [t0, p0, hs[i], s0], [t1, p1, hs[i + 1], s1], [b0, p0, 0.0, s0], [t1, p1, hs[i + 1], s1], [b1, p1, 0.0, s1]]
			for v: Array in tri:
				st.set_uv(Vector2(float(v[1]), float(v[2])))
				st.set_uv2(Vector2(float(li), float(v[3])))
				st.add_vertex(v[0] as Vector3)
	_mountains = MeshInstance3D.new()
	_mountains.name = "Montanas"
	_mountains.mesh = st.commit()
	_mountain_mat = ShaderMaterial.new()
	_mountain_mat.shader = MOUNTAIN_SHADER
	_mountains.material_override = _mountain_mat
	_mountains.extra_cull_margin = 16384.0
	_mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mountains)


## El trazado de la carretera de ahora (los de road_curve.gd) y lo recorrido (m).
func set_path(pts: PackedVector2Array, heads: PackedFloat32Array, road_m: float) -> void:
	for m: ShaderMaterial in [_ground_mat, _tree_mat]:
		m.set_shader_parameter("path_p", pts)
		m.set_shader_parameter("path_h", heads)
		m.set_shader_parameter("road_m", road_m)


## Las montañas y el suelo lejano, donde está la cámara (pos), con el rumbo del coche (rad).
func follow(pos: Vector3, heading: float) -> void:
	_mountains.position = Vector3(pos.x, 0.0, pos.z)
	_far.position = Vector3(pos.x, -1.2, pos.z)
	_mountain_mat.set_shader_parameter("heading", heading)


## Los colores de la luz de ahora: la neblina del horizonte (la del cielo), el sol (hacia dónde, su color) y lo que se
## aclaran las montañas lejanas.
func set_light(haze: Color, sun_dir: Vector3, sun_col: Color) -> void:
	_mountain_mat.set_shader_parameter("haze_color", haze)
	_mountain_mat.set_shader_parameter("sun_dir", sun_dir)
	_mountain_mat.set_shader_parameter("sun_color", sun_col)
	# la capa lejana, más oscura que el cielo de detrás de sus cumbres (el de ~10° ya no es el del horizonte)
	_mountain_mat.set_shader_parameter("far_color", Color(0.27, 0.31, 0.4).lerp(haze, 0.12))
	_mountain_mat.set_shader_parameter("near_color", Color(0.2, 0.29, 0.22).lerp(haze, 0.1))


# ════════ Las mallas de los árboles ════════

## La malla de una especie, de 1 m de alto (la escala es su altura): el tronco (alfa 0 en el color) y la copa (alfa 1).
static func tree_mesh(sp: String, p_mobile := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 6 if p_mobile else 9
	var bark := Color(0.29, 0.21, 0.14, 0.0)
	match sp:
		"conifera":
			_frustum(st, 0.0, 0.26, 0.028, 0.02, seg, bark)
			var green := Color(0.13, 0.25, 0.13, 1.0)
			_frustum(st, 0.12, 0.52, 0.23, 0.02, seg, green)
			_frustum(st, 0.34, 0.76, 0.18, 0.015, seg, green.lightened(0.04))
			_frustum(st, 0.56, 1.0, 0.12, 0.0, seg, green.lightened(0.08))
		"chopo":
			_frustum(st, 0.0, 0.2, 0.03, 0.025, seg, bark)
			_blob(st, Vector3(0.0, 0.58, 0.0), Vector3(0.13, 0.42, 0.13), seg, Color(0.25, 0.39, 0.15, 1.0))
		_:
			_frustum(st, 0.0, 0.48, 0.04, 0.03, seg, bark)
			var leaf := Color(0.21, 0.35, 0.14, 1.0)
			_blob(st, Vector3(0.0, 0.66, 0.0), Vector3(0.3, 0.24, 0.3), seg, leaf)
			_blob(st, Vector3(0.14, 0.76, 0.06), Vector3(0.21, 0.19, 0.21), seg, leaf.lightened(0.05))
			_blob(st, Vector3(-0.12, 0.74, -0.09), Vector3(0.22, 0.2, 0.22), seg, leaf.darkened(0.06))
	st.generate_normals()
	return st.commit()


## Un tronco de cono de y0 a y1 con los radios r0 y r1 (con su base cerrada si r0 > 0).
static func _frustum(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, seg: int, col: Color) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
			st.set_color(col)
			st.add_vertex(v)
		if r0 > 0.0:
			for v: Vector3 in [Vector3(0.0, y0, 0.0), p00, p01]:
				st.set_color(col)
				st.add_vertex(v)


## Un elipsoide de semiejes rad en c, de pocas caras (la copa de una frondosa o de un chopo).
static func _blob(st: SurfaceTool, c: Vector3, rad: Vector3, seg: int, col: Color) -> void:
	var rings := maxi(seg - 3, 4)
	for j in rings:
		var t0 := PI * float(j) / float(rings)
		var t1 := PI * float(j + 1) / float(rings)
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var q := func(t: float, a: float) -> Vector3: return c + Vector3(sin(t) * cos(a) * rad.x, cos(t) * rad.y, sin(t) * sin(a) * rad.z)
			var v00: Vector3 = q.call(t0, a0)
			var v01: Vector3 = q.call(t0, a1)
			var v10: Vector3 = q.call(t1, a0)
			var v11: Vector3 = q.call(t1, a1)
			for v: Vector3 in [v00, v11, v10, v00, v01, v11]:
				st.set_color(col)
				st.add_vertex(v)
