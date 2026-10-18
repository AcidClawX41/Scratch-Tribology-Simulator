## Cetrería · el taller de mallas de los cuerpos en alta definición (unidad 5i, petición 37): funciones puras que devuelven
## los arrays de una superficie (sin nodos: se pueden llamar desde un hilo). Solo dibujo. Lo que hace:
##   - loft(): un cuerpo barrido a lo largo de una espina (el tronco con el cuello, una pata, la cola, una cabeza) con su
##     sección en cada estación (superelipse con alto de arriba y de abajo, ancho de cada lado y lo redondeada que es cada
##     mitad), deformado después con bultos y hundimientos (el modelado: la frente, los pómulos, la joroba del oso) y
##     aplastado contra la mesa (el peso del animal tumbado); devuelve los arrays y la rejilla, para poner encima plumas o
##     mechones (surface_point);
##   - cards(): tarjetas de plumas o de mechones (una tira curvada con su raquis a lo largo, de la raíz a la punta);
##   - ellipsoid(), tube(), merge(), moved() y normals().
## Convención de los arrays de una superficie (los sombreadores body_*.gdshader la leen):
##   UV = (a lo largo, alrededor) en mm · UV2 = (s: dónde está en el cuerpo, 0 morro → 1 punta de la cola; la vuelta: 0 el
##   lomo, 0,25 el costado derecho, 0,5 la tripa, 0,75 el izquierdo) · COLOR = (oclusión horneada, zona, largo del pelo
##   (0-1), cuánto respira (0-1)) · TANGENT = hacia dónde va el pelo o la pluma (a lo largo de la espina).
## Y la de una tarjeta: UV = (de través, −1 a 1; a lo largo, 0 la raíz → 1 la punta) · UV2 = (semilla, cuánto respira) ·
##   COLOR = (el color de la pluma, la sombra) · CUSTOM0 = (tipo, dibujo, parámetro del dibujo, largo en mm) · TANGENT = la
##   normal del cuerpo en la raíz (hacia donde respira).
extends RefCounted

const MM := 1000.0
## Formato de los arrays con CUSTOM0 (cuatro float por vértice).
const CUSTOM_FLAGS := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT


# ─────────────────────────────── arrays ───────────────────────────────

static func pack(v: PackedVector3Array, n: PackedVector3Array, t: PackedFloat32Array, uv: PackedVector2Array, uv2: PackedVector2Array,
		col: PackedColorArray, idx: PackedInt32Array, custom := PackedFloat32Array()) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TANGENT] = t
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_TEX_UV2] = uv2
	a[Mesh.ARRAY_COLOR] = col
	a[Mesh.ARRAY_INDEX] = idx
	if not custom.is_empty():
		a[Mesh.ARRAY_CUSTOM0] = custom
	return a


static func empty() -> Array:
	return pack(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedVector2Array(), PackedVector2Array(),
		PackedColorArray(), PackedInt32Array())


static func has_triangles(a: Array) -> bool:
	return a.size() == Mesh.ARRAY_MAX and a[Mesh.ARRAY_INDEX] is PackedInt32Array and (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >= 3


static func vertex_count(a: Array) -> int:
	return (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if has_triangles(a) else 0


## Junta varias superficies del mismo tipo (todas con CUSTOM0 o ninguna).
static func merge(list: Array) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var cu := PackedFloat32Array()
	for a: Array in list:
		if not has_triangles(a):
			continue
		var base := v.size()
		v.append_array(a[Mesh.ARRAY_VERTEX])
		n.append_array(a[Mesh.ARRAY_NORMAL])
		t.append_array(a[Mesh.ARRAY_TANGENT])
		uv.append_array(a[Mesh.ARRAY_TEX_UV])
		uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		col.append_array(a[Mesh.ARRAY_COLOR])
		if a[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array:
			cu.append_array(a[Mesh.ARRAY_CUSTOM0])
		var ia: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if base == 0:
			idx.append_array(ia)
		else:
			var off := PackedInt32Array(ia)
			for k in off.size():
				off[k] += base
			idx.append_array(off)
	return pack(v, n, t, uv, uv2, col, idx, cu)


## Una superficie movida con xf (posiciones, normales y tangentes).
static func moved(a: Array, xf: Transform3D) -> Array:
	if not has_triangles(a):
		return a
	var v: PackedVector3Array = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var t: PackedFloat32Array = (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
	var nb := xf.basis.inverse().transposed()
	for k in v.size():
		v[k] = xf * v[k]
		n[k] = (nb * n[k]).normalized()
		var tv := (xf.basis * Vector3(t[k * 4], t[k * 4 + 1], t[k * 4 + 2])).normalized()
		t[k * 4] = tv.x
		t[k * 4 + 1] = tv.y
		t[k * 4 + 2] = tv.z
	var out := a.duplicate()
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = n
	out[Mesh.ARRAY_TANGENT] = t
	return out


## La caja de una o varias superficies.
static func aabb_of(list: Array) -> AABB:
	var out := AABB()
	var first := true
	for a: Array in list:
		if not has_triangles(a):
			continue
		for p: Vector3 in a[Mesh.ARRAY_VERTEX]:
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out


## Un ArrayMesh con la superficie (con CUSTOM0 si la trae). Vacío si no hay triángulos.
static func to_mesh(a: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	if has_triangles(a):
		var flags := CUSTOM_FLAGS if a[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array else 0
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, flags)
	return am


# ─────────────────────────────── espinas y marcos ───────────────────────────────

## Una espina suave por los puntos dados (Catmull-Rom centrípeta aproximada), con n estaciones repartidas por largo.
static func spine(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	var dense := PackedVector3Array()
	var m := pts.size()
	if m < 2:
		return PackedVector3Array(pts)
	for i in m - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, m - 1)]
		if i == 0:
			p0 = p1 - (p2 - p1)
		if i + 2 > m - 1:
			p3 = p2 + (p2 - p1)
		for q in 16:
			var t := float(q) / 16.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(pts[m - 1])
	var acc := PackedFloat32Array([0.0])
	for i in range(1, dense.size()):
		acc.append(acc[i - 1] + dense[i].distance_to(dense[i - 1]))
	var total := acc[acc.size() - 1]
	var out := PackedVector3Array()
	var j := 0
	for i in n:
		var want := total * float(i) / float(maxi(n - 1, 1))
		while j < acc.size() - 2 and acc[j + 1] < want:
			j += 1
		var u := (want - acc[j]) / maxf(acc[j + 1] - acc[j], 1e-9)
		out.append(dense[j].lerp(dense[j + 1], clampf(u, 0.0, 1.0)))
	return out


## Marcos a lo largo de una espina (transporte paralelo desde up): [{ t, u, s }], t la tangente, u «arriba» (el lomo) y s
## el lado (+s, el derecho del animal si u es el lomo y t va hacia la cola... según cómo se mire: s = t × u).
static func frames(sp: PackedVector3Array, up: Vector3) -> Array:
	var out: Array = []
	var n := sp.size()
	var prev := up.normalized()
	for i in n:
		var a := sp[maxi(i - 1, 0)]
		var b := sp[mini(i + 1, n - 1)]
		var t := (b - a).normalized() if a.distance_squared_to(b) > 1e-16 else Vector3.BACK
		var u := prev - t * prev.dot(t)
		if u.length_squared() < 1e-10:
			u = Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
			u = u - t * u.dot(t)
		u = u.normalized()
		prev = u
		out.append({ "t": t, "u": u, "s": t.cross(u).normalized() })
	return out


## Campana de Gauss.
static func gauss(x: float, c: float, w: float) -> float:
	return exp(-pow((x - c) / maxf(w, 1e-6), 2.0))


## Un array de n valores iguales.
static func filled(n: int, v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(v)
	return a


## Un perfil por estaciones: n valores interpolados (con suavizado) por los nudos [[u, valor], …], u de 0 a 1.
static func profile(n: int, knots: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var u := float(i) / float(maxi(n - 1, 1))
		out[i] = sample(knots, u)
	return out


## Un perfil por estaciones que pasa por los nudos con una curva suave y sin rizos (cúbica monótona de Fritsch y Carlson):
## a diferencia de profile(), no se aplana en cada nudo, así que un perfil con muchos nudos (el de una cabeza: la frente,
## el escalón de la nariz, el caballete) sale como una línea continua y no a escalones (unidad 5n).
static func profile_smooth(n: int, knots: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sample_smooth(knots, float(i) / float(maxi(n - 1, 1)))
	return out


## El valor de un perfil [[u, valor], …] en u, por la cúbica monótona (ver profile_smooth).
static func sample_smooth(knots: Array, u: float) -> float:
	var m := knots.size()
	if m == 0:
		return 0.0
	if m == 1 or u <= float(knots[0][0]):
		return float(knots[0][1])
	if u >= float(knots[m - 1][0]):
		return float(knots[m - 1][1])
	var k := 1
	while k < m - 1 and u > float(knots[k][0]):
		k += 1
	var x0 := float(knots[k - 1][0])
	var x1 := float(knots[k][0])
	var y0 := float(knots[k - 1][1])
	var y1 := float(knots[k][1])
	var h := maxf(x1 - x0, 1e-9)
	var t0 := _slope_at(knots, k - 1)
	var t1 := _slope_at(knots, k)
	var t := (u - x0) / h
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * t0 + (-2.0 * t3 + 3.0 * t2) * y1 + (t3 - t2) * h * t1


## La pendiente de la cúbica monótona en el nudo i: la media de las de sus dos tramos, cero en un máximo o un mínimo y
## recortada para que la curva no se pase del nudo (Fritsch y Carlson).
static func _slope_at(knots: Array, i: int) -> float:
	var m := knots.size()
	var d_prev := 0.0
	var d_next := 0.0
	if i > 0:
		d_prev = (float(knots[i][1]) - float(knots[i - 1][1])) / maxf(float(knots[i][0]) - float(knots[i - 1][0]), 1e-9)
	if i < m - 1:
		d_next = (float(knots[i + 1][1]) - float(knots[i][1])) / maxf(float(knots[i + 1][0]) - float(knots[i][0]), 1e-9)
	if i == 0:
		return d_next
	if i == m - 1:
		return d_prev
	if d_prev * d_next <= 0.0:
		return 0.0
	var s := 0.5 * (d_prev + d_next)
	return signf(s) * minf(absf(s), 3.0 * minf(absf(d_prev), absf(d_next)))


## El valor de un perfil [[u, valor], …] en u (interpolación suave entre nudos).
static func sample(knots: Array, u: float) -> float:
	if knots.is_empty():
		return 0.0
	if u <= float(knots[0][0]):
		return float(knots[0][1])
	for k in range(1, knots.size()):
		var a: Array = knots[k - 1]
		var b: Array = knots[k]
		if u <= float(b[0]):
			var f := (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-9)
			f = f * f * (3.0 - 2.0 * f)
			return lerpf(float(a[1]), float(b[1]), f)
	return float(knots[knots.size() - 1][1])


# ─────────────────────────────── el cuerpo barrido ───────────────────────────────

## Punto de la superelipse en el ángulo ang (0 arriba, π/2 el lado +s): alto de arriba top y de abajo bot, ancho de cada
## lado (sr hacia +s, sl hacia −s) y lo redondeada que es cada mitad (2 redonda, más: más cuadrada).
static func section_point(ang: float, top: float, bot: float, sr: float, sl: float, nt: float, nb: float) -> Vector2:
	var c := cos(ang)
	var s := sin(ang)
	var e := 2.0 / maxf(nt if c >= 0.0 else nb, 0.5)
	return Vector2(signf(c) * pow(absf(c), e) * (top if c >= 0.0 else bot), signf(s) * pow(absf(s), e) * (sr if s >= 0.0 else sl))


## Un cuerpo barrido. spec:
##   spine (PackedVector3Array, m: ya repartida), up (Vector3: el lomo de la primera estación), ring (segmentos);
##   top, bot, sr, sl (PackedFloat32Array por estación, m): alto de arriba y de abajo, ancho del lado +s y del −s;
##   nt, nb (float o PackedFloat32Array): exponentes de cada mitad; ao, fur, breath, zone (PackedFloat32Array o float);
##   s0, s1 (float): dónde va en el cuerpo (UV2.x, de s0 en la primera estación a s1 en la última);
##   flow (1: el pelo va hacia el final de la espina; −1: hacia el principio);
##   cap_start, cap_end (bool) y cap_k (el largo de la tapa en radios);
##   bumps (Array de { c, r (Vector3 o float), amt (m), dir (opcional, Vector3: si no, a lo largo de la normal) }): el
##   modelado, aplicado a la rejilla;
##   warp (Callable(p: Vector3) -> Vector3, opcional): una deformación de cada punto de la rejilla después de los bultos y
##   antes de las normales (la 5n la usa en las cabezas: el caballete del hocico más estrecho que el labio);
##   floor ({ y0, band }, opcional): lo que baja de y0 + band se aplasta contra la mesa (el peso del animal tumbado);
##   ao_under (float, 0-1): cuánto se oscurece lo que mira hacia la mesa.
## → { arrays, grid (PackedVector3Array, m × cols), norms, m, cols, arc (largo acumulado por estación, m), frames, pts, i0 e
##     i1 (la primera y la última estación de la espina, sin las tapas) }
static func loft(spec: Dictionary) -> Dictionary:
	var sp: PackedVector3Array = spec.spine
	var ring := int(spec.get("ring", 32))
	var n := sp.size()
	if n < 2:
		return { "arrays": empty(), "grid": PackedVector3Array(), "norms": PackedVector3Array(), "m": 0, "cols": 0, "arc": PackedFloat32Array() }
	var top: PackedFloat32Array = spec.top
	var bot: PackedFloat32Array = spec.get("bot", top)
	var sr: PackedFloat32Array = spec.get("sr", top)
	var sl: PackedFloat32Array = spec.get("sl", sr)
	var nt := _per_station(spec.get("nt", 2.0), n)
	var nb := _per_station(spec.get("nb", 2.0), n)
	var ao_s := _per_station(spec.get("ao", 1.0), n)
	var fur_s := _per_station(spec.get("fur", 1.0), n)
	var br_s := _per_station(spec.get("breath", 0.0), n)
	var zone_s := _per_station(spec.get("zone", 0.0), n)
	var s0 := float(spec.get("s0", 0.0))
	var s1 := float(spec.get("s1", 1.0))
	var flow_k := float(spec.get("flow", 1.0))
	var ao_under := float(spec.get("ao_under", 0.0))
	# las tapas: estaciones de más con el radio en coseno (los Packed*Array se copian en cada paso: GDScript no escribe en
	# un temporal como (x as PackedFloat32Array).append())
	var pts := PackedVector3Array(sp)
	var a_top := PackedFloat32Array(top)
	var a_bot := PackedFloat32Array(bot)
	var a_sr := PackedFloat32Array(sr)
	var a_sl := PackedFloat32Array(sl)
	var a_u := PackedFloat32Array()
	for i in n:
		a_u.append(float(i) / float(n - 1))
	var steps := 6
	var cap_k := float(spec.get("cap_k", 0.8))
	if bool(spec.get("cap_end", true)):
		var t_end := (sp[n - 1] - sp[n - 2]).normalized()
		var r_end := maxf(maxf(top[n - 1], bot[n - 1]), maxf(sr[n - 1], sl[n - 1]))
		for k in range(1, steps + 1):
			var th := float(k) / float(steps) * PI * 0.5
			var f := maxf(cos(th), 0.0)
			pts.append(sp[n - 1] + t_end * sin(th) * r_end * cap_k)
			a_top.append(top[n - 1] * f)
			a_bot.append(bot[n - 1] * f)
			a_sr.append(sr[n - 1] * f)
			a_sl.append(sl[n - 1] * f)
			a_u.append(1.0)
		nt = _extend(nt, 0, steps)
		nb = _extend(nb, 0, steps)
		ao_s = _extend(ao_s, 0, steps)
		fur_s = _extend(fur_s, 0, steps)
		br_s = _extend(br_s, 0, steps)
		zone_s = _extend(zone_s, 0, steps)
	if bool(spec.get("cap_start", false)):
		var t0 := (sp[1] - sp[0]).normalized()
		var r0 := maxf(maxf(top[0], bot[0]), maxf(sr[0], sl[0]))
		var pre := PackedVector3Array()
		var p_top := PackedFloat32Array()
		var p_bot := PackedFloat32Array()
		var p_sr := PackedFloat32Array()
		var p_sl := PackedFloat32Array()
		var p_u := PackedFloat32Array()
		for k in range(steps, 0, -1):
			var th := float(k) / float(steps) * PI * 0.5
			var f := maxf(cos(th), 0.0)
			pre.append(sp[0] - t0 * sin(th) * r0 * cap_k)
			p_top.append(top[0] * f)
			p_bot.append(bot[0] * f)
			p_sr.append(sr[0] * f)
			p_sl.append(sl[0] * f)
			p_u.append(0.0)
		pre.append_array(pts)
		pts = pre
		p_top.append_array(a_top)
		p_bot.append_array(a_bot)
		p_sr.append_array(a_sr)
		p_sl.append_array(a_sl)
		p_u.append_array(a_u)
		a_top = p_top
		a_bot = p_bot
		a_sr = p_sr
		a_sl = p_sl
		a_u = p_u
		nt = _extend(nt, steps, 0)
		nb = _extend(nb, steps, 0)
		ao_s = _extend(ao_s, steps, 0)
		fur_s = _extend(fur_s, steps, 0)
		br_s = _extend(br_s, steps, 0)
		zone_s = _extend(zone_s, steps, 0)
	var fr := frames(pts, spec.get("up", Vector3.UP))
	var m := pts.size()
	var cols := ring + 1
	var grid := PackedVector3Array()
	grid.resize(m * cols)
	var arc := PackedFloat32Array()
	var acc := 0.0
	for i in m:
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		arc.append(acc)
		var f: Dictionary = fr[i]
		for j in cols:
			var ang := float(j) / float(ring) * TAU
			var yz := section_point(ang, a_top[i], a_bot[i], a_sr[i], a_sl[i], nt[i], nb[i])
			grid[i * cols + j] = pts[i] + (f.u as Vector3) * yz.x + (f.s as Vector3) * yz.y
	# el modelado (bultos y hundimientos) y el peso contra la mesa
	var bumps: Array = spec.get("bumps", [])
	if not bumps.is_empty():
		var g_n := _grid_normals(grid, m, cols, pts)
		for k in grid.size():
			grid[k] = displaced(grid[k], g_n[k], bumps)
	var warp: Variant = spec.get("warp")
	if warp is Callable:
		for k in grid.size():
			grid[k] = (warp as Callable).call(grid[k])
	var fl: Dictionary = spec.get("floor", {})
	if not fl.is_empty():
		for k in grid.size():
			grid[k] = floor_squash(grid[k], float(fl.y0), float(fl.band))
	var norms := _grid_normals(grid, m, cols, pts)
	# los arrays
	var verts := PackedVector3Array(grid)
	var tans := PackedFloat32Array()
	tans.resize(m * cols * 4)
	var uvs := PackedVector2Array()
	uvs.resize(m * cols)
	var uv2s := PackedVector2Array()
	uv2s.resize(m * cols)
	var cols_c := PackedColorArray()
	cols_c.resize(m * cols)
	for i in m:
		var f: Dictionary = fr[i]
		var circ := TAU * (a_top[i] + a_bot[i] + a_sr[i] + a_sl[i]) * 0.25
		var t_i: Vector3 = (f.t as Vector3) * flow_k
		var s_body := lerpf(s0, s1, a_u[i])
		for j in cols:
			var k := i * cols + j
			var nrm := norms[k]
			var tv := (t_i - nrm * t_i.dot(nrm))
			tv = tv.normalized() if tv.length_squared() > 1e-12 else t_i
			tans[k * 4] = tv.x
			tans[k * 4 + 1] = tv.y
			tans[k * 4 + 2] = tv.z
			tans[k * 4 + 3] = 1.0
			var a := float(j) / float(ring)
			uvs[k] = Vector2(arc[i] * MM, a * circ * MM)
			uv2s[k] = Vector2(s_body, a)
			var under := smoothstep(0.2, 0.9, -nrm.y)
			cols_c[k] = Color(ao_s[i] * (1.0 - ao_under * under), zone_s[i], fur_s[i], br_s[i])
	var idx := PackedInt32Array()
	idx.resize((m - 1) * ring * 6)
	var w := 0
	for i in m - 1:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx[w] = a0
			idx[w + 1] = b0
			idx[w + 2] = a0 + 1
			idx[w + 3] = a0 + 1
			idx[w + 4] = b0
			idx[w + 5] = b0 + 1
			w += 6
	var arrays := pack(verts, norms, tans, uvs, uv2s, cols_c, idx)
	# i0 e i1: la primera y la última estación de la espina (sin las de las tapas)
	var i0 := steps if bool(spec.get("cap_start", false)) else 0
	return { "arrays": arrays, "grid": grid, "norms": norms, "m": m, "cols": cols, "arc": arc, "frames": fr, "pts": pts, "i0": i0, "i1": i0 + n - 1 }


## Una copia del array con before valores iguales al primero delante y after iguales al último detrás.
static func _extend(a: PackedFloat32Array, before: int, after: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in before:
		out.append(a[0])
	out.append_array(a)
	var last := a[a.size() - 1]
	for k in after:
		out.append(last)
	return out


static func _per_station(v: Variant, n: int) -> PackedFloat32Array:
	if v is PackedFloat32Array:
		var a := PackedFloat32Array(v as PackedFloat32Array)
		while a.size() < n:
			a.append(a[a.size() - 1] if a.size() > 0 else 0.0)
		return a
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(float(v))
	return out


## Normales de la rejilla por diferencias (alrededor × a lo largo), hacia fuera del eje.
static func _grid_normals(grid: PackedVector3Array, m: int, cols: int, pts: PackedVector3Array) -> PackedVector3Array:
	var ring := cols - 1
	var out := PackedVector3Array()
	out.resize(grid.size())
	for i in m:
		var ip := mini(i + 1, m - 1)
		var im := maxi(i - 1, 0)
		for j in cols:
			var jp := (j + 1) if j < ring else 1
			var jm := (j - 1) if j > 0 else ring - 1
			var ts := grid[ip * cols + j] - grid[im * cols + j]
			var ta := grid[i * cols + jp] - grid[i * cols + jm]
			var nrm := ta.cross(ts)
			var p := grid[i * cols + j]
			var out_dir := p - pts[i]
			if nrm.length_squared() < 1e-24:
				nrm = out_dir if out_dir.length_squared() > 1e-24 else (pts[mini(i + 1, m - 1)] - pts[maxi(i - 1, 0)]) * (1.0 if i > m / 2 else -1.0)
			if nrm.dot(out_dir) < 0.0 and out_dir.length_squared() > 1e-20:
				nrm = -nrm
			out[i * cols + j] = nrm.normalized() if nrm.length_squared() > 1e-24 else Vector3.UP
	return out


## Un punto movido por los bultos: cada uno con su centro c, su radio r (Vector3: elipsoide alineado con los ejes; o
## float) y su cantidad amt (m: + hacia fuera, − hacia dentro), a lo largo de la normal n o de dir.
static func displaced(p: Vector3, n: Vector3, bumps: Array) -> Vector3:
	var out := p
	for b: Dictionary in bumps:
		var r: Variant = b.r
		var rv: Vector3 = r if r is Vector3 else Vector3.ONE * float(r)
		var d := (p - (b.c as Vector3)) / rv
		var q := d.length_squared()
		if q >= 4.0:
			continue
		var w := exp(-q * 1.6)
		var dir: Vector3 = b.get("dir", n)
		out += dir * float(b.amt) * w
	return out


## Aplasta contra la mesa lo que baja de y0 + band: lo más bajo se queda justo encima de y0 (el peso del cuerpo tumbado).
static func floor_squash(p: Vector3, y0: float, band: float) -> Vector3:
	var d := p.y - y0
	if d >= band:
		return p
	# de (−∞, band] a (0, band]: suave y con la misma pendiente en band
	var u := (band - d) / band
	var y := band * exp(-u)
	return Vector3(p.x, y0 + maxf(y, 0.0008), p.z)


## El punto de la superficie (y su normal) en la estación fraccionaria fi (0 → m−1) y el ángulo a (0-1) de un loft.
static func surface_point(lo: Dictionary, fi: float, a: float) -> Array:
	var m := int(lo.m)
	var cols := int(lo.cols)
	var grid: PackedVector3Array = lo.grid
	var norms: PackedVector3Array = lo.norms
	var x := clampf(fi, 0.0, float(m - 1) - 1e-4)
	var i := int(floor(x))
	var fx := x - float(i)
	var ring := cols - 1
	var y := fposmod(a, 1.0) * float(ring)
	var j := int(floor(y))
	var fy := y - float(j)
	var j2 := (j + 1) % cols
	var p00 := grid[i * cols + j]
	var p01 := grid[i * cols + j2]
	var p10 := grid[(i + 1) * cols + j]
	var p11 := grid[(i + 1) * cols + j2]
	var n00 := norms[i * cols + j]
	var n01 := norms[i * cols + j2]
	var n10 := norms[(i + 1) * cols + j]
	var n11 := norms[(i + 1) * cols + j2]
	var p := p00.lerp(p01, fy).lerp(p10.lerp(p11, fy), fx)
	var nn := n00.lerp(n01, fy).lerp(n10.lerp(n11, fy), fx).normalized()
	var t: Vector3 = ((lo.pts as PackedVector3Array)[mini(i + 1, m - 1)] - (lo.pts as PackedVector3Array)[i])
	if t.length_squared() < 1e-14:
		t = ((lo.frames as Array)[i] as Dictionary).t
	t = (t - nn * t.dot(nn)).normalized()
	return [p, nn, t]


## La vuelta (0-1, del lado derecho: de lo alto, 0, a lo de abajo, 0,5) en la que la superficie de un barrido pasa por el
## ancho z (la más alta que llega), en la estación fraccionaria fi.
static func angle_at_z(lo: Dictionary, fi: float, z: float) -> float:
	var best := INF
	var a_best := 0.15
	for k in 41:
		var a := 0.01 + 0.3 * float(k) / 40.0
		var dz := absf(((surface_point(lo, fi, a) as Array)[0] as Vector3).z - z)
		if dz < best:
			best = dz
			a_best = a
	return a_best


## La vuelta (0-1, del lado derecho, de a0 a a1: por defecto, entre el costado y lo de abajo) en la que la superficie pasa
## por el alto y.
static func angle_at_y(lo: Dictionary, fi: float, y: float, a0 := 0.18, a1 := 0.5) -> float:
	var best := INF
	var a_best := 0.5 * (a0 + a1)
	for k in 41:
		var a := a0 + (a1 - a0) * float(k) / 40.0
		var dy := absf(((surface_point(lo, fi, a) as Array)[0] as Vector3).y - y)
		if dy < best:
			best = dy
			a_best = a
	return a_best


## La línea de la boca en el barrido de la cabeza: [estación fraccionaria, vuelta] de la comisura (el primer nudo de lip) hacia
## delante, a la altura de cada nudo, y al final, por la tapa de la nariz, hasta el surco del labio en medio (bajo la trufa).
static func lip_line(lo: Dictionary, i0: int, lip: Array, hh: float) -> Array:
	var out: Array = []
	for e: Array in lip:
		var fi := float(i0) + clampf(float(e[0]), 0.0, 1.0) * float(int(lo.i1) - i0)
		out.append([fi, angle_at_y(lo, fi, float(e[1]) * hh)])
	var i1 := float(lo.i1)
	var last: Array = lip[lip.size() - 1]
	out.append([i1 + 1.6, angle_at_y(lo, i1 + 1.6, float(last[1]) * hh * 0.85)])
	out.append([i1 + 3.2, 0.5])
	return out


## Una pluma o un mechón que sigue la superficie de un loft: desde la estación fi y la vuelta a, a lo largo del loft (dir
## 1: hacia el final de la espina; −1: hacia el principio) length metros, separado de la piel de h0 (la raíz) a h1 (la
## punta) y torcido de lado (curl: cuánto se va de vuelta, fracción de la vuelta, a lo largo). → [puntos, normales]
static func surface_path(lo: Dictionary, fi: float, a: float, dir: float, length: float, h0: float, h1: float, n: int, curl := 0.0) -> Array:
	var arc: PackedFloat32Array = lo.arc
	var x0 := float(arc[clampi(int(floor(fi)), 0, arc.size() - 1)])
	var i0 := clampi(int(floor(fi)), 0, arc.size() - 2)
	x0 = lerpf(arc[i0], arc[i0 + 1], fi - float(i0))
	var path := PackedVector3Array()
	var pn := PackedVector3Array()
	for k in n:
		var t := float(k) / float(maxi(n - 1, 1))
		var f2 := station_at(lo, clampf(x0 + dir * length * t, 0.0, arc[arc.size() - 1]))
		var sp: Array = surface_point(lo, f2, a + curl * t)
		path.append((sp[0] as Vector3) + (sp[1] as Vector3) * lerpf(h0, h1, t))
		pn.append(sp[1])
	return [path, pn]


## La estación fraccionaria de un loft más cerca de un largo acumulado (m desde la primera estación).
static func station_at(lo: Dictionary, along_m: float) -> float:
	var arc: PackedFloat32Array = lo.arc
	if arc.is_empty():
		return 0.0
	if along_m <= arc[0]:
		return 0.0
	for i in range(1, arc.size()):
		if arc[i] >= along_m:
			return float(i - 1) + (along_m - arc[i - 1]) / maxf(arc[i] - arc[i - 1], 1e-9)
	return float(arc.size() - 1)


# ─────────────────────────────── piezas sencillas ───────────────────────────────

## Un tubo redondo por los puntos dados (radio por estación): bigotes, el tubo de la mascarilla, el cable.
static func tube(pts: PackedVector3Array, radii: PackedFloat32Array, ring: int, opts := {}) -> Dictionary:
	var n := pts.size()
	var spec := {
		"spine": pts, "up": opts.get("up", Vector3.UP), "ring": ring, "top": radii, "bot": radii, "sr": radii, "sl": radii,
		"cap_start": bool(opts.get("cap_start", true)), "cap_end": bool(opts.get("cap_end", true)), "cap_k": float(opts.get("cap_k", 0.8)),
		"s0": float(opts.get("s0", 0.0)), "s1": float(opts.get("s1", 1.0)), "zone": float(opts.get("zone", 0.0)),
		"ao": float(opts.get("ao", 1.0)), "fur": float(opts.get("fur", 0.0)), "breath": float(opts.get("breath", 0.0)),
	}
	if n < 2:
		return loft({ "spine": PackedVector3Array() })
	return loft(spec)


## Un elipsoide de semiejes radii con la orientación basis, en c (UV2 = (0,5, la vuelta)); bultos como en loft.
static func ellipsoid(c: Vector3, radii: Vector3, basis: Basis, ring: int, rings: int, opts := {}) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var idx := PackedInt32Array()
	var cols := ring + 1
	var r_mean := (radii.x + radii.y + radii.z) / 3.0
	var bumps: Array = opts.get("bumps", [])
	var zone := float(opts.get("zone", 0.0))
	var ao_under := float(opts.get("ao_under", 0.2))
	var fur := float(opts.get("fur", 0.0))
	var br := float(opts.get("breath", 0.0))
	var s_body := float(opts.get("s", 0.5))
	var grid := PackedVector3Array()
	for i in rings + 1:
		var th := float(i) / float(rings) * PI
		for j in cols:
			var ph := float(j) / float(ring) * TAU
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var p := c + basis * (d * radii)
			if not bumps.is_empty():
				p = displaced(p, (basis * (d / radii)).normalized(), bumps)
			grid.append(p)
	for i in rings + 1:
		for j in cols:
			var ip := mini(i + 1, rings)
			var im := maxi(i - 1, 0)
			var jp := (j + 1) if j < ring else 1
			var jm := (j - 1) if j > 0 else ring - 1
			var ts := grid[ip * cols + j] - grid[im * cols + j]
			var ta := grid[i * cols + jp] - grid[i * cols + jm]
			var p := grid[i * cols + j]
			var nrm := ts.cross(ta)
			var out_dir := p - c
			if nrm.length_squared() < 1e-24:
				nrm = out_dir
			if nrm.dot(out_dir) < 0.0:
				nrm = -nrm
			nrm = nrm.normalized()
			verts.append(p)
			norms.append(nrm)
			var tv := (basis.y - nrm * basis.y.dot(nrm))
			tv = tv.normalized() if tv.length_squared() > 1e-10 else basis.x
			tans.append_array([-tv.x, -tv.y, -tv.z, 1.0])
			uvs.append(Vector2(float(i) / float(rings) * PI * r_mean * MM, float(j) / float(ring) * TAU * r_mean * MM))
			uv2s.append(Vector2(s_body, float(j) / float(ring)))
			var under := smoothstep(0.2, 0.9, -nrm.y)
			cols_c.append(Color(1.0 - ao_under * under, zone, fur, br))
	for i in rings:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return pack(verts, norms, tans, uvs, uv2s, cols_c, idx)


# ─────────────────────────────── tarjetas: plumas y mechones ───────────────────────────────

## Tarjetas (plumas o mechones). Cada una: { p (raíz), axis (hacia la punta), nrm (la normal del cuerpo en la raíz),
## len, wid (m), bend (rad: cuánto se curva hacia el cuerpo a lo largo), cup (cuánto se abomba de través, fracción del
## ancho), lift (rad: cuánto se levanta de la piel en la raíz), twist (rad), col (Color), kind, pattern, param (floats),
## seed, breath, shade (0-1), segs (filas, 2-6), lat (columnas de través, 1 o 2), smooth (0-1: cuánto se lleva la
## normal hacia la del cuerpo), path y path_n (opcionales: la línea del raquis y sus normales, para una pluma larga que
## sigue el cuerpo) }.
## La tarjeta se dobla para seguir el cuerpo: empieza levantada lift y se va acostando con bend. floor_y: nada por debajo
## (la mesa, si las tarjetas van en el marco de la raíz).
static func cards(list: Array, floor_y := -INF) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var cust := PackedFloat32Array()
	var idx := PackedInt32Array()
	for c: Dictionary in list:
		var segs := clampi(int(c.get("segs", 3)), 1, 10)
		var lat := clampi(int(c.get("lat", 2)), 1, 4)
		var nb: Vector3 = (c.nrm as Vector3).normalized()
		var L := float(c.len)
		var W := float(c.wid)
		var cup := float(c.get("cup", 0.12))
		var col: Color = c.get("col", Color(0.4, 0.3, 0.2))
		var shade := float(c.get("shade", 1.0))
		var kind := float(c.get("kind", 0.0))
		var pat := float(c.get("pattern", 0.0))
		var par := float(c.get("param", 0.0))
		var seed := float(c.get("seed", 0.0))
		var br := float(c.get("breath", 0.0))
		var smooth := float(c.get("smooth", 0.55))
		var tw := float(c.get("twist", 0.0))
		# la línea del raquis (rp), su tangente (rt), la normal de la pluma (rn) y su lado (rs), fila a fila
		var rp := PackedVector3Array()
		var rt := PackedVector3Array()
		var rn := PackedVector3Array()
		var path: Variant = c.get("path")
		if path is PackedVector3Array and (path as PackedVector3Array).size() >= 2:
			# una pluma larga que sigue el cuerpo (las rémiges del ala plegada): por los puntos dados, con sus normales
			var pp := spine(path as PackedVector3Array, segs + 1)
			var pn: PackedVector3Array = c.get("path_n", PackedVector3Array())
			for k in segs + 1:
				var t := (pp[mini(k + 1, segs)] - pp[maxi(k - 1, 0)]).normalized()
				var nk := nb
				if pn.size() >= 2:
					nk = pn[clampi(int(round(float(k) / float(segs) * float(pn.size() - 1))), 0, pn.size() - 1)]
				nk = (nk - t * nk.dot(t)).normalized()
				rp.append(pp[k])
				rt.append(t)
				rn.append(nk)
			L = 0.0
			for k in range(1, pp.size()):
				L += pp[k].distance_to(pp[k - 1])
		else:
			var ax: Vector3 = c.axis
			ax = (ax - nb * ax.dot(nb))
			ax = ax.normalized() if ax.length_squared() > 1e-12 else nb.cross(Vector3.UP).normalized()
			var side0 := ax.cross(nb).normalized()
			if absf(tw) > 1e-5:
				side0 = side0.rotated(ax, tw)
			var up := side0.cross(ax).normalized()
			if up.dot(nb) < 0.0:
				up = -up
			# arranca levantada lift y se acuesta hacia el cuerpo (bend), a pasos iguales
			var ang := float(c.get("lift", 0.15))
			var bend := float(c.get("bend", 0.2))
			var dl := L / float(segs)
			var q: Vector3 = c.p
			for k in segs + 1:
				var t := (ax * cos(ang) + up * sin(ang)).normalized()
				rp.append(q)
				rt.append(t)
				var nk := t.cross(side0).normalized()
				if nk.dot(up) < 0.0:
					nk = -nk
				rn.append(nk)
				q += t * dl
				ang -= bend / float(segs)
		var base := verts.size()
		var cols := lat * 2 + 1
		for k in segs + 1:
			var y := float(k) / float(segs)
			var t := rt[k]
			var nn := rn[k]
			var side := t.cross(nn).normalized()
			for l in cols:
				var x := float(l - lat) / float(lat)
				# el abombado de través: los lados bajan hacia el cuerpo; nada por debajo de la mesa (floor_y, en el marco de
				# la raíz)
				var pos := rp[k] + side * x * W * 0.5 - nn * cup * W * x * x
				pos.y = maxf(pos.y, floor_y)
				verts.append(pos)
				# la normal, llevada hacia la del cuerpo (smooth): la luz pasa de una pluma a otra como sobre una superficie
				# y no se ve cada tarjeta como una teja suelta
				var nrm := (nn + side * x * cup * 2.0).normalized().lerp(nb, smooth).normalized()
				norms.append(nrm)
				tans.append_array([nb.x, nb.y, nb.z, 1.0])
				uvs.append(Vector2(x, y))
				uv2s.append(Vector2(seed, br))
				cols_c.append(Color(col.r, col.g, col.b, shade))
				cust.append_array([kind, pat, par, L * MM])
		for k in segs:
			for l in cols - 1:
				var a0 := base + k * cols + l
				var b0 := base + (k + 1) * cols + l
				idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return pack(verts, norms, tans, uvs, uv2s, cols_c, idx, cust)


## Normales por cara sumadas en cada vértice (para una malla deformada), del mismo lado que las de antes.
static func normals(a: Array) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var acc := PackedVector3Array()
	acc.resize(v.size())
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var fn := (p2 - p0).cross(p1 - p0)
		acc[idx[t]] += fn
		acc[idx[t + 1]] += fn
		acc[idx[t + 2]] += fn
	var old: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	for k in acc.size():
		var nn := acc[k]
		if nn.length_squared() < 1e-24:
			acc[k] = old[k]
			continue
		nn = nn.normalized()
		acc[k] = nn if nn.dot(old[k]) >= 0.0 else -nn
	a[Mesh.ARRAY_NORMAL] = acc


# ─────────────────────────────── el párpado ───────────────────────────────

## Un párpado cerrado en el marco del ojo (+Z hacia donde mira, +Y arriba): un casquete de esfera de radio r, el de arriba
## (upper) desde lo alto hasta su borde, a edge_deg grados del polo de arriba, o el de abajo desde su borde hasta abajo;
## el borde, con un canto hacia dentro (el grosor del párpado, con las dos caras). Se abre girándolo sobre el eje X del
## ojo (hacia arriba el de arriba, hacia abajo el de abajo). corner_deg: cuánto baja (o sube) el borde hacia los lados del
## ojo; con él, los párpados se juntan en las comisuras y la abertura queda en forma de almendra (los mamíferos; 0, la
## redonda de las aves). UV.x: mm desde el borde (el borde oscuro del sombreador).
static func eyelid(r: float, upper: bool, edge_deg: float, mobile: bool, corner_deg := 0.0) -> Array:
	var n_t := 6 if mobile else 10
	var n_p := 14 if mobile else 26
	var th_far := deg_to_rad(6.0) if upper else deg_to_rad(174.0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var row_n := n_p + 1
	var n_rows := n_t + 2
	for i in n_rows:
		for j in row_n:
			var ph := deg_to_rad(lerpf(-14.0, 194.0, float(j) / float(n_p)))
			var side := 1.0 - clampf(sin(ph), 0.0, 1.0)
			var th_e := deg_to_rad(edge_deg + (corner_deg if upper else -corner_deg) * side * side)
			var th := th_e
			var rr := r
			var rim := false
			if upper:
				if i <= n_t:
					th = lerpf(th_far, th_e, float(i) / float(n_t))
				else:
					rr = r * 0.84
					rim = true
			else:
				if i == 0:
					rr = r * 0.84
					rim = true
				else:
					th = lerpf(th_e, th_far, float(i - 1) / float(n_t))
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			verts.append(d * rr)
			norms.append(d)
			tans.append_array([1.0, 0.0, 0.0, 1.0])
			uvs.append(Vector2(0.0 if rim else absf(th - th_e) * r * MM, float(j) / float(n_p) * PI * r * MM))
			uv2s.append(Vector2(0.5, 0.0))
			cols.append(Color(1.0, 0.75, 0.0, 0.0))
	var rim_i := n_t if upper else 0
	for i in n_rows - 1:
		for j in n_p:
			var a0 := i * row_n + j
			var b0 := (i + 1) * row_n + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
			if i == rim_i:
				idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
	return pack(verts, norms, tans, uvs, uv2s, cols, idx)
