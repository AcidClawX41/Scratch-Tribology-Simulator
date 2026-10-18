## Malla de revolución de la pieza del torno (unidad 9).
##
## Parte del perfil que publica el torno (CONTRATOS.md → «Perfil de la pieza»): anillos equiespaciados en z
## (dz = 0,02 mm en el núcleo), cada uno con su radio, su Ra y su tipo de pasada. De ahí salen los arrays de una
## malla de revolución (posiciones en mm, normales, tangentes, UV, CUSTOM0 e índices) y, sobre todo, la
## actualización por rango: cuando el torno marca `dirty`, solo se reescriben esos anillos, ya empaquetados en
## bytes con el mismo formato que usa Godot, listos para ArrayMesh.surface_update_vertex_region y
## surface_update_attribute_region. Así la pieza puede ir perdiendo material fotograma a fotograma sin
## reconstruir 130 000 vértices cada vez.
##
## Nivel de detalle:
## - anillos: el núcleo tiene miles (85 mm / 0,02 mm = 4250); la malla toma uno de cada `ring_step` (muestreo
##   puntual, siempre incluye el último) para no pasar de `max_rings`;
## - lados: `sides` por anillo (64 en escritorio, 32 en móvil), más una columna repetida en la costura para
##   que la UV no se vuelva del revés.
##
## Disposición de los vértices (cualquier rango de anillos es un bloque contiguo):
##   [tapa del plato: centro + borde] [anillo 0] … [anillo N−1] [tapa del contrapunto: borde + centro]
##
## Flujos de bytes por vértice (Godot 4.7, formato sin comprimir; los tests lo comparan con RenderingServer):
## - posiciones: 3 × float32 (12 B), todas seguidas al principio del búfer de vértices;
## - normal + tangente: 2 × (2 × uint16) octaédricas (8 B), después de todas las posiciones;
## - atributos: UV (2 × float32) + CUSTOM0 (4 × float32) = 24 B, en su propio búfer.
##
## CUSTOM0 por vértice (RGBA_FLOAT), lo interpreta app/taller/acabado.gdshader:
## - x: Ra del anillo (µm);
## - y: tipo de pasada (0 bruto, 1 desbaste, 2 acabado, 3 pulido, 4 roscado);
## - z: desviación del diámetro respecto al centro de la zona de tolerancia del plano (µm);
## - w: la componente «reservada» del contrato de la unidad; aquí lleva el semiancho de esa zona (µm), o −1
##   si el plano no acota el anillo (la capa de desviación lo pinta neutro).
##
## Uso:
##   const LatheMesh = preload("res://core/taller/lathe_mesh.gd")
##   var lm := LatheMesh.new(64, 2000)
##   var full := lm.build(profile, plan)            # arrays + bytes de toda la malla
##   var upd := lm.update(profile, plan, a, b)      # solo los anillos del núcleo [a, b] (y sus vecinos)
extends RefCounted

const POS_STRIDE := 12  ## bytes por vértice en el flujo de posiciones
const NT_STRIDE := 8  ## bytes por vértice en el flujo de normal + tangente
const ATTR_STRIDE := 24  ## bytes por vértice en el búfer de atributos (UV + CUSTOM0)
## Formato que hay que pasar a add_surface_from_arrays para que CUSTOM0 sean 4 float32.
const CUSTOM_FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
const NO_PLAN := -1.0  ## semiancho de tolerancia de un anillo que el plano no acota
## Pasos por vuelta con los que se cuantiza la inclinación del perfil antes de calcular las normales. La normal
## codificada depende solo del ángulo cuantizado, así que la caché no cambia el resultado y reescribir un
## rango da exactamente los mismos bytes que reconstruir la malla entera.
const ANGLE_STEPS := 16384
const PASS_NAMES := ["bruto", "desbaste", "acabado", "pulido", "roscado"]

var sides: int  ## lados de cada anillo
var max_rings: int  ## tope de anillos de la malla
var ring_step := 1  ## anillos del núcleo por anillo de la malla
var n_core := 0  ## anillos del perfil del núcleo
var n_rings := 0  ## anillos de la malla
var z0 := 0.0  ## z del primer anillo del núcleo (mm)
var dz := 0.02  ## paso del núcleo (mm)
var vertex_count := 0
var index_count := 0

var _cols := 0  # vértices por anillo: sides + 1 (costura)
var _ring_base := 0  # primer vértice del anillo 0
var _circle := PackedVector3Array()  # (0, cos θ, sin θ) por columna
var _uv_tpl := PackedVector2Array()  # (1, j/sides) por columna
var _attr_tpl := PackedVector3Array()  # [(1, j/sides, 0), (0, 0, 1)] por columna: ver _pack()
var _tan_col := PackedFloat32Array()  # tangente (0, −sin θ, cos θ, +1) por columna
var _t_codes := PackedInt32Array()  # tangente codificada por columna
var _cap_nt := [PackedInt32Array(), PackedInt32Array()]  # normal ∓x + tangente, por columna, de las dos tapas
var _cap_normals := [PackedVector3Array(), PackedVector3Array()]
var _nt_cache := {}  # ángulo cuantizado → [normales (PackedVector3Array), normal+tangente (PackedInt32Array)]
var _index_cache := PackedInt32Array()
var _index_key := Vector2i(-1, -1)



func _init(p_sides := 64, p_max_rings := 2000) -> void:
	sides = maxi(3, p_sides)
	max_rings = maxi(2, p_max_rings)
	_cols = sides + 1
	_ring_base = 1 + _cols
	for j in _cols:
		var jj := j % sides  # la columna de la costura repite exactamente la primera
		var th := TAU * float(jj) / float(sides)
		var c := cos(th)
		var s := sin(th)
		var v := float(j) / float(sides)
		_circle.append(Vector3(0.0, c, s))
		_uv_tpl.append(Vector2(1.0, v))
		_attr_tpl.append(Vector3(1.0, v, 0.0))
		_attr_tpl.append(Vector3(0.0, 0.0, 1.0))
		_tan_col.append_array(PackedFloat32Array([0.0, -s, c, 1.0]))
		_t_codes.append(tangent_code(Vector3(0.0, -s, c), 1.0))
	for side in 2:
		var n := Vector3(-1.0 if side == 0 else 1.0, 0.0, 0.0)
		var code := oct_code(n)
		var nt := PackedInt32Array()
		var normals := PackedVector3Array()
		for j in _cols:
			nt.append(code)
			nt.append(_t_codes[j])
			normals.append(n)
		_cap_nt[side] = nt
		_cap_normals[side] = normals


## Anillos del núcleo por anillo de la malla para no pasar de `limit` anillos.
static func ring_step_for(core_rings: int, limit: int) -> int:
	if core_rings <= limit:
		return 1
	return int(ceil(float(core_rings - 1) / float(maxi(limit - 1, 1))))


## Ajusta el nivel de detalle a un perfil (número de anillos, z0 y dz). No calcula nada más.
func configure(profile: Dictionary) -> void:
	var rr: PackedFloat64Array = profile["r"]
	n_core = rr.size()
	z0 = float(profile["z0"])
	dz = float(profile["dz"])
	ring_step = ring_step_for(n_core, max_rings)
	n_rings = 1 if n_core <= 1 else (n_core - 1 + ring_step - 1) / ring_step + 1
	vertex_count = _ring_base + n_rings * _cols + _cols + 1
	index_count = ((n_rings - 1) * sides * 2 + 2 * sides) * 3


## ¿La malla configurada sirve para este perfil? Si no (otra pieza, otra rejilla), hay que reconstruir.
func matches(profile: Dictionary) -> bool:
	var rr: PackedFloat64Array = profile.get("r", PackedFloat64Array())
	return rr.size() == n_core and float(profile.get("z0", NAN)) == z0 and float(profile.get("dz", NAN)) == dz


## Índice del anillo del núcleo que muestrea el anillo m de la malla.
func core_index(m: int) -> int:
	return mini(m * ring_step, n_core - 1)


## z (mm) del anillo m de la malla.
func ring_z(m: int) -> float:
	return z0 + float(core_index(m)) * dz


## Primer vértice del anillo m de la malla (sin contar las tapas).
func ring_vertex(m: int) -> int:
	return _ring_base + m * _cols


## Malla entera. Devuelve:
## - arrays: para ArrayMesh.add_surface_from_arrays(PRIMITIVE_TRIANGLES, arrays, [], {}, CUSTOM_FORMAT);
## - pos, nt, attr: los tres flujos en bytes (lo que Godot guardará en la GPU) para sobrescribirlos tal cual;
## - aabb (mm), vertex_count, index_count, rings.
func build(profile: Dictionary, plan: Dictionary = {}) -> Dictionary:
	configure(profile)
	var out := _pack(profile, plan, 0, n_rings - 1, true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out["positions"]
	arrays[Mesh.ARRAY_NORMAL] = out["normals"]
	arrays[Mesh.ARRAY_TANGENT] = out["tangents"]
	arrays[Mesh.ARRAY_TEX_UV] = out["uv"]
	arrays[Mesh.ARRAY_CUSTOM0] = out["custom0"]
	arrays[Mesh.ARRAY_INDEX] = indices()
	var rr: PackedFloat64Array = profile["r"]
	var rmax := 0.0
	for v in rr:
		rmax = maxf(rmax, v)
	rmax = maxf(rmax, 0.001)
	var z_end := ring_z(n_rings - 1)
	return {
		"arrays": arrays,
		"pos": out["pos"], "nt": out["nt"], "attr": out["attr"],
		"aabb": AABB(Vector3(z0, -rmax, -rmax), Vector3(maxf(z_end - z0, 0.001), 2.0 * rmax, 2.0 * rmax)),
		"vertex_count": vertex_count, "index_count": index_count, "rings": Vector2i(0, n_rings - 1),
	}


## Reescritura de los anillos del núcleo [first, last] (el `dirty` del contrato). Devuelve {} si ningún anillo
## de la malla muestrea ese rango; si no:
## - first_vertex, vertices: bloque contiguo de vértices afectado (incluye las tapas si toca los extremos);
## - pos, nt, attr: sus bytes, y pos_offset, nt_offset, attr_offset: dónde van dentro de cada búfer;
## - rings: anillos de la malla reescritos (los muestreados y un vecino a cada lado, cuyas normales cambian).
func update(profile: Dictionary, plan: Dictionary, first: int, last: int) -> Dictionary:
	if n_core == 0 or first < 0 or last < first:
		return {}
	first = clampi(first, 0, n_core - 1)
	last = clampi(last, 0, n_core - 1)
	var m_lo := mini((first + ring_step - 1) / ring_step, n_rings - 1)
	var m_hi := last / ring_step
	if last >= core_index(n_rings - 1):
		m_hi = n_rings - 1
	m_hi = mini(m_hi, n_rings - 1)
	if m_lo > m_hi or core_index(m_lo) > last:
		return {}
	# Las normales de un anillo salen de los radios de sus vecinos: si cambia el anillo m, cambian m − 1 y m + 1.
	m_lo = maxi(m_lo - 1, 0)
	m_hi = mini(m_hi + 1, n_rings - 1)
	return _pack(profile, plan, m_lo, m_hi, false)


## Índices (triángulos en sentido horario vistos desde fuera, el convenio de caras frontales de Godot).
## Solo dependen de n_rings y sides: se guardan para no rehacerlos.
func indices() -> PackedInt32Array:
	var key := Vector2i(n_rings, sides)
	if key == _index_key:
		return _index_cache
	var idx := PackedInt32Array()
	idx.resize(index_count)
	var k := 0
	for j in sides:  # tapa del plato (normal −x): centro, borde j, borde j + 1
		idx[k] = 0
		idx[k + 1] = 1 + j
		idx[k + 2] = 2 + j
		k += 3
	# Bloque de un par de anillos; se desplaza para cada par (menos trabajo por índice en GDScript).
	var block := PackedInt32Array()
	block.resize(sides * 6)
	for j in sides:
		var a := j
		var d := _cols + j
		block[j * 6] = a
		block[j * 6 + 1] = d
		block[j * 6 + 2] = a + 1
		block[j * 6 + 3] = a + 1
		block[j * 6 + 4] = d
		block[j * 6 + 5] = d + 1
	var bl := block.size()
	for m in n_rings - 1:
		var off := _ring_base + m * _cols
		for i in bl:
			idx[k + i] = block[i] + off
		k += bl
	var rim := _ring_base + n_rings * _cols
	var ctr := rim + _cols
	for j in sides:  # tapa del contrapunto (normal +x): centro, borde j + 1, borde j
		idx[k] = ctr
		idx[k + 1] = rim + j + 1
		idx[k + 2] = rim + j
		k += 3
	_index_cache = idx
	_index_key = key
	return idx


## Empaqueta los anillos [m0, m1] de la malla (y las tapas si tocan un extremo).
func _pack(profile: Dictionary, plan: Dictionary, m0: int, m1: int, with_arrays: bool) -> Dictionary:
	var rr: PackedFloat64Array = profile["r"]
	var ra_arr: PackedFloat32Array = profile.get("ring_ra", PackedFloat32Array())
	var pass_arr: PackedByteArray = profile.get("ring_pass", PackedByteArray())
	var has_ra := ra_arr.size() == n_core
	var has_pass := pass_arr.size() == n_core
	var has_plan := not plan.is_empty()
	var p_rmin := PackedFloat64Array()
	var p_rmax := PackedFloat64Array()
	var p_z0 := 0.0
	var p_dz := 1.0
	if has_plan:
		p_rmin = plan["r_min"]
		p_rmax = plan["r_max"]
		p_z0 = float(plan["z0"])
		p_dz = float(plan["dz"])
	var pos := PackedVector3Array()
	var nt := PackedInt32Array()
	var attr := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uv := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var first_vertex := ring_vertex(m0)
	for m in range(m0, m1 + 1):
		var ci := core_index(m)
		var x := z0 + float(ci) * dz
		var r := maxf(rr[ci], 0.0)
		var ra := float(ra_arr[ci]) if has_ra else 0.0
		var ps := float(pass_arr[ci]) if has_pass else 0.0
		var dev := 0.0
		var tol := NO_PLAN
		if has_plan:
			var pi := int(round((x - p_z0) / p_dz))
			if pi >= 0 and pi < p_rmin.size():
				var lo := p_rmin[pi]
				var hi := p_rmax[pi]
				if hi >= lo and hi >= 0.0:
					dev = clampf((2.0 * r - (lo + hi)) * 1000.0, -1.0e6, 1.0e6)
					tol = minf((hi - lo) * 1000.0, 1.0e6)
		# Tres productos nativos por anillo en lugar de un bucle por vértice:
		# - posiciones: escala (1, r, r) y traslación x sobre el círculo unidad (0, cos θ, sin θ);
		# - atributos: una base cuyas columnas son (x, 0, Ra), (0, 1, 0) y (pasada, desviación, tolerancia)
		#   aplicada a la plantilla [(1, v, 0), (0, 0, 1)] da, por vértice, (x, v, Ra) y (pasada, desv., tol.):
		#   justo los 6 float32 de UV + CUSTOM0. Los productos por 0 y 1 son exactos en float32.
		var ring_t := Transform3D(Basis.from_scale(Vector3(1.0, r, r)), Vector3(x, 0.0, 0.0))
		var ring_pos: PackedVector3Array = ring_t * _circle
		var ring_attr: PackedVector3Array = Transform3D(Basis(Vector3(x, 0.0, ra), Vector3(0.0, 1.0, 0.0), Vector3(ps, dev, tol)), Vector3.ZERO) * _attr_tpl
		var ncol: Array = _normal_column(_normal_key(m, rr))
		if m == 0:  # tapa del plato: centro + borde, con la normal hacia el plato
			first_vertex = 0
			pos.append(Vector3(x, 0.0, 0.0))
			pos.append_array(ring_pos)
			nt.append((_cap_nt[0] as PackedInt32Array)[0])
			nt.append(_t_codes[0])
			nt.append_array(_cap_nt[0])
			attr.append_array(ring_attr.slice(0, 2))
			attr.append_array(ring_attr)
			if with_arrays:
				normals.append(Vector3(-1.0, 0.0, 0.0))
				normals.append_array(_cap_normals[0])
				tangents.append_array(_tan_col.slice(0, 4))
				tangents.append_array(_tan_col)
				uv.append(Vector2(x, 0.0))
				uv.append_array(Transform2D(Vector2(x, 0.0), Vector2(0.0, 1.0), Vector2.ZERO) * _uv_tpl)
				custom0.append_array(_repeat4(PackedFloat32Array([ra, ps, dev, tol]), _cols + 1))
		pos.append_array(ring_pos)
		nt.append_array(ncol[1])
		attr.append_array(ring_attr)
		if with_arrays:
			normals.append_array(ncol[0])
			tangents.append_array(_tan_col)
			uv.append_array(Transform2D(Vector2(x, 0.0), Vector2(0.0, 1.0), Vector2.ZERO) * _uv_tpl)
			custom0.append_array(_repeat4(PackedFloat32Array([ra, ps, dev, tol]), _cols))
		if m == n_rings - 1:  # tapa del contrapunto: borde + centro, con la normal hacia el contrapunto
			pos.append_array(ring_pos)
			pos.append(Vector3(x, 0.0, 0.0))
			nt.append_array(_cap_nt[1])
			nt.append((_cap_nt[1] as PackedInt32Array)[0])
			nt.append(_t_codes[0])
			attr.append_array(ring_attr)
			attr.append_array(ring_attr.slice(0, 2))
			if with_arrays:
				normals.append_array(_cap_normals[1])
				normals.append(Vector3(1.0, 0.0, 0.0))
				tangents.append_array(_tan_col)
				tangents.append_array(_tan_col.slice(0, 4))
				uv.append_array(Transform2D(Vector2(x, 0.0), Vector2(0.0, 1.0), Vector2.ZERO) * _uv_tpl)
				uv.append(Vector2(x, 0.0))
				custom0.append_array(_repeat4(PackedFloat32Array([ra, ps, dev, tol]), _cols + 1))
	var count := pos.size()
	var out := {
		"first_vertex": first_vertex, "vertices": count, "rings": Vector2i(m0, m1),
		"pos": pos.to_byte_array(), "nt": nt.to_byte_array(), "attr": attr.to_byte_array(),
		"pos_offset": first_vertex * POS_STRIDE,
		"nt_offset": vertex_count * POS_STRIDE + first_vertex * NT_STRIDE,
		"attr_offset": first_vertex * ATTR_STRIDE,
	}
	if with_arrays:
		out["positions"] = pos
		out["normals"] = normals
		out["tangents"] = tangents
		out["uv"] = uv
		out["custom0"] = custom0
	return out


## Ángulo cuantizado de la normal del anillo m: diferencia centrada con sus vecinos en la malla.
## φ = 0 es radial (cilindro); φ > 0 inclina la normal hacia +z (hacia el contrapunto).
func _normal_key(m: int, rr: PackedFloat64Array) -> int:
	var ma := maxi(m - 1, 0)
	var mb := mini(m + 1, n_rings - 1)
	if ma == mb:
		return 0
	var ia := core_index(ma)
	var ib := core_index(mb)
	var d_r := maxf(rr[ib], 0.0) - maxf(rr[ia], 0.0)
	var d_z := float(ib - ia) * dz
	return int(round(atan2(-d_r, d_z) / TAU * float(ANGLE_STEPS)))


## Normales (y su código normal + tangente) de un anillo con la inclinación cuantizada `key`. Memoizado: casi
## todos los anillos son cilíndricos (key = 0) o de conos con la misma pendiente.
func _normal_column(key: int) -> Array:
	var hit: Variant = _nt_cache.get(key)
	if hit != null:
		return hit
	var phi := float(key) * TAU / float(ANGLE_STEPS)
	var nx := sin(phi)
	var nr := cos(phi)
	var normals: PackedVector3Array = Transform3D(Basis.from_scale(Vector3(1.0, nr, nr)), Vector3(nx, 0.0, 0.0)) * _circle
	var nt := PackedInt32Array()
	nt.resize(_cols * 2)
	for j in _cols:
		nt[2 * j] = oct_code(normals[j])
		nt[2 * j + 1] = _t_codes[j]
	var entry := [normals, nt]
	if _nt_cache.size() >= 4096:
		_nt_cache.clear()
	_nt_cache[key] = entry
	return entry


## Normal codificada como la guarda Godot (octaédrica, 2 × uint16 truncados). Las operaciones con Vector2 se
## hacen en float32, igual que en el motor, así que el resultado coincide bit a bit.
static func oct_code(n: Vector3) -> int:
	var q := n.octahedron_encode() * 65535.0
	var ux := clampi(int(q.x), 0, 65535)
	var uy := clampi(int(q.y), 0, 65535)
	if ux == 0 and uy == 65535:  # (0, 1) y (1, 1) son la misma normal; Godot se queda con la segunda
		ux = 65535
	return ux | (uy << 16)


## Tangente codificada como Vector3::octahedron_tangent_encode de Godot (el signo de la binormal va en y).
static func tangent_code(t: Vector3, binormal_sign: float) -> int:
	var o := t.octahedron_encode()
	var y := Vector2(maxf(o.y, _bias32()), 0.0) * 0.5 + Vector2(0.5, 0.0)
	if binormal_sign < 0.0:
		y = Vector2(1.0, 0.0) - y
	var q := Vector2(o.x, y.x) * 65535.0
	return clampi(int(q.x), 0, 65535) | (clampi(int(q.y), 0, 65535) << 16)


## 1/32767 redondeado a float32, el sesgo de Vector3::octahedron_tangent_encode de Godot. Sin estado (antes era una
## `static var` perezosa): la malla se puede construir desde varios hilos a la vez sin carreras.
static func _bias32() -> float:
	return PackedFloat32Array([1.0 / 32767.0])[0]


## Un bloque de 4 floats repetido `times` veces (por duplicación: pocas llamadas nativas).
static func _repeat4(v4: PackedFloat32Array, times: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var chunk := v4
	var n := times
	while n > 0:
		if n & 1:
			out.append_array(chunk)
		n >>= 1
		if n > 0:
			chunk.append_array(chunk)
	return out


## Aplica una actualización a los flujos completos (los de build o los de una aplicación anterior). Sirve para
## los tests y para quien quiera guardar la malla sin GPU; la escena usa surface_update_*_region.
static func apply_update(streams: Dictionary, upd: Dictionary) -> Dictionary:
	var out := streams.duplicate()
	for pair in [["pos", "pos_offset"], ["nt", "nt_offset"], ["attr", "attr_offset"]]:
		var full: PackedByteArray = streams[pair[0]]
		var part: PackedByteArray = upd[pair[0]]
		var off: int = upd[pair[1]] - (streams.get("vertex_count", 0) * POS_STRIDE if pair[0] == "nt" else 0)
		out[pair[0]] = full.slice(0, off) + part + full.slice(off + part.size())
	return out


## Banda de tolerancia del plano sobre una rejilla de anillos, a partir de tramos rectos (cilindros, conos y
## chaflanes) con diámetros en mm y diferencias de cota en µm sobre el diámetro:
##   [{ "z_from": −20.0, "z_to": 0.0, "d_from": 30.0, "d_to": 30.0, "es_um": 0.0, "ei_um": −52.0 }, …]
## Devuelve { z0, dz, r_min, r_max } (radios en mm; −1 donde el plano no dice nada). En los cambios de tramo
## (hombros), los anillos a menos de `blend_mm` aceptan la unión de las dos bandas: la cota axial del hombro no
## es un diámetro y un anillo de más o de menos no debe salir en rojo.
static func band_from_segments(segments: Array, p_z0: float, p_dz: float, n: int, blend_mm := 0.1) -> Dictionary:
	var r_min := PackedFloat64Array()
	var r_max := PackedFloat64Array()
	r_min.resize(n)
	r_max.resize(n)
	for i in n:
		var z := p_z0 + float(i) * p_dz
		var lo := INF
		var hi := -INF
		for s in segments:
			var za := float(s["z_from"])
			var zb := float(s["z_to"])
			if z < za - blend_mm or z > zb + blend_mm:
				continue
			var t := 0.0 if zb <= za else clampf((z - za) / (zb - za), 0.0, 1.0)
			var d := lerpf(float(s["d_from"]), float(s["d_to"]), t)
			lo = minf(lo, maxf(d + float(s.get("ei_um", 0.0)) / 1000.0, 0.0) * 0.5)
			hi = maxf(hi, maxf(d + float(s.get("es_um", 0.0)) / 1000.0, 0.0) * 0.5)
		if lo == INF:
			r_min[i] = NO_PLAN
			r_max[i] = NO_PLAN
		else:
			r_min[i] = lo
			r_max[i] = hi
	return {"z0": p_z0, "dz": p_dz, "r_min": r_min, "r_max": r_max}
