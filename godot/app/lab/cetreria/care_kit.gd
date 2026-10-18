## Cetrería · el taller de mallas de las patas en alta definición (unidad 5h, petición 37): funciones puras que devuelven
## los arrays de una superficie (sin nodos: se pueden llamar desde un hilo). Solo dibujo.
##
## - limb(): un tubo barrido a lo largo de una espina (un dedo, un tarso, un antebrazo) con su sección en cada estación:
##   el alto de arriba y el de abajo, el ancho y lo redondeada que es cada mitad (superelipse), con los bultos de las
##   almohadillas y los nudillos que se le pongan, tapas redondeadas y normales de la propia superficie;
## - blob(): un elipsoide con bultos (una almohadilla, la planta, una cabeza sencilla);
## - shells(): las capas del pelo (el mismo tubo repetido; el sombreador las separa a lo largo de la normal);
## - merge() y moved(): juntar superficies y moverlas, para dibujar cada pata con pocas llamadas.
## Las coordenadas de las texturas van en milímetros: UV.x a lo largo (mm), UV.y alrededor (mm), UV2.x el radio medio (mm)
## y UV2.y la capa del pelo (0-1). El color del vértice lleva lo que pintan los sombreadores de la pata
## (paw_skin.gdshader, paw_fur.gdshader): R la oclusión horneada (1 al aire, menos en los pliegues), G la zona (0 arriba,
## los escudetes; 0,5 los lados, las escamas; 1 abajo, la almohadilla), B cuánto bulto de almohadilla hay y A, libre (1).
extends RefCounted

const MM := 1000.0


## Marcos a lo largo de una espina (transporte paralelo desde up): [{ t, u, s }] con t la tangente, u «arriba» y s el lado.
static func frames(spine: PackedVector3Array, up: Vector3) -> Array:
	var out: Array = []
	var n := spine.size()
	var prev_u := up.normalized()
	for i in n:
		var a := spine[maxi(i - 1, 0)]
		var b := spine[mini(i + 1, n - 1)]
		var t := (b - a).normalized() if a.distance_squared_to(b) > 1e-16 else Vector3.RIGHT
		var u := prev_u - t * prev_u.dot(t)
		if u.length_squared() < 1e-10:
			u = (Vector3.UP if absf(t.y) < 0.9 else Vector3.BACK)
			u = (u - t * u.dot(t))
		u = u.normalized()
		prev_u = u
		out.append({ "t": t, "u": u, "s": t.cross(u).normalized() })
	return out


## Punto de la superelipse de radio 1 (alto de arriba 1, de abajo b, ancho w) en el ángulo ang (0 arriba, π/2 al lado +s).
static func _sec(ang: float, ry_top: float, ry_bot: float, rz: float, n_top: float, n_bot: float) -> Vector2:
	var c := cos(ang)
	var s := sin(ang)
	var top := c >= 0.0
	var e := 2.0 / maxf(n_top if top else n_bot, 0.5)
	return Vector2(signf(c) * pow(absf(c), e) * (ry_top if top else ry_bot), signf(s) * pow(absf(s), e) * rz)


## Un tubo barrido. spec:
##   spine (PackedVector3Array, m), up (Vector3: «arriba» de la primera estación), ring (segmentos por vuelta);
##   ry_top, ry_bot, rz (PackedFloat32Array por estación, m): el alto de arriba, el de abajo y el ancho;
##   n_top, n_bot (float o PackedFloat32Array): exponentes de la superelipse de cada mitad (2 redonda);
##   ao (PackedFloat32Array por estación, opcional): la oclusión de cada estación (1 sin oclusión);
##   ao_under (float, 0-1): cuánto se oscurece la cara de abajo (la que toca la mesa o mira a la planta);
##   dorsal, ventral (float, fracción de vuelta, opcionales): dónde acaban los escudetes de arriba y empieza la almohadilla;
##   pad (PackedFloat32Array por estación, opcional): cuánto bulto de almohadilla (0-1) hay en esa estación;
##   cap_start, cap_end (bool): tapas redondeadas; cap_k: el largo de la tapa (fracción del radio).
static func limb(spec: Dictionary) -> Array:
	var spine: PackedVector3Array = spec.spine
	var ring := int(spec.get("ring", 24))
	var ry_top: PackedFloat32Array = spec.ry_top
	var ry_bot: PackedFloat32Array = spec.get("ry_bot", ry_top)
	var rz: PackedFloat32Array = spec.get("rz", ry_top)
	var ao_in: PackedFloat32Array = spec.get("ao", PackedFloat32Array())
	var pad_in: PackedFloat32Array = spec.get("pad", PackedFloat32Array())
	var nt_v: Variant = spec.get("n_top", 2.0)
	var nb_v: Variant = spec.get("n_bot", 2.0)
	var ao_under := float(spec.get("ao_under", 0.15))
	var dorsal := float(spec.get("dorsal", 0.14))
	var ventral := float(spec.get("ventral", 0.3))
	var n := spine.size()
	if n < 2:
		return empty()
	# las tapas: estaciones de más, con el radio en coseno (media esfera aplastada)
	var pts := PackedVector3Array(spine)
	var a_top := PackedFloat32Array(ry_top)
	var a_bot := PackedFloat32Array(ry_bot)
	var a_z := PackedFloat32Array(rz)
	var a_ao := PackedFloat32Array()
	var a_pad := PackedFloat32Array()
	var a_nt := PackedFloat32Array()
	var a_nb := PackedFloat32Array()
	for i in n:
		a_ao.append(ao_in[i] if i < ao_in.size() else 1.0)
		a_pad.append(pad_in[i] if i < pad_in.size() else 0.0)
		a_nt.append(float((nt_v as PackedFloat32Array)[i]) if nt_v is PackedFloat32Array else float(nt_v))
		a_nb.append(float((nb_v as PackedFloat32Array)[i]) if nb_v is PackedFloat32Array else float(nb_v))
	var cap_k := float(spec.get("cap_k", 0.9))
	var steps := 5
	if bool(spec.get("cap_end", true)):
		var t_end := (spine[n - 1] - spine[n - 2]).normalized()
		var r_end := maxf(maxf(ry_top[n - 1], ry_bot[n - 1]), rz[n - 1])
		for k in range(1, steps + 1):
			var th := float(k) / float(steps) * PI * 0.5
			var f := cos(th)
			pts.append(spine[n - 1] + t_end * sin(th) * r_end * cap_k)
			a_top.append(ry_top[n - 1] * f)
			a_bot.append(ry_bot[n - 1] * f)
			a_z.append(rz[n - 1] * f)
			a_ao.append(a_ao[n - 1])
			a_pad.append(a_pad[n - 1])
			a_nt.append(a_nt[n - 1])
			a_nb.append(a_nb[n - 1])
	if bool(spec.get("cap_start", false)):
		var t0 := (spine[1] - spine[0]).normalized()
		var r0 := maxf(maxf(ry_top[0], ry_bot[0]), rz[0])
		var pre := PackedVector3Array()
		var p_top := PackedFloat32Array()
		var p_bot := PackedFloat32Array()
		var p_z := PackedFloat32Array()
		var p_ao := PackedFloat32Array()
		var p_pad := PackedFloat32Array()
		var p_nt := PackedFloat32Array()
		var p_nb := PackedFloat32Array()
		for k in range(steps, 0, -1):
			var th := float(k) / float(steps) * PI * 0.5
			var f := cos(th)
			pre.append(spine[0] - t0 * sin(th) * r0 * cap_k)
			p_top.append(ry_top[0] * f)
			p_bot.append(ry_bot[0] * f)
			p_z.append(rz[0] * f)
			p_ao.append(a_ao[0])
			p_pad.append(a_pad[0])
			p_nt.append(a_nt[0])
			p_nb.append(a_nb[0])
		pre.append_array(pts)
		p_top.append_array(a_top)
		p_bot.append_array(a_bot)
		p_z.append_array(a_z)
		p_ao.append_array(a_ao)
		p_pad.append_array(a_pad)
		p_nt.append_array(a_nt)
		p_nb.append_array(a_nb)
		pts = pre
		a_top = p_top
		a_bot = p_bot
		a_z = p_z
		a_ao = p_ao
		a_pad = p_pad
		a_nt = p_nt
		a_nb = p_nb
	var fr := frames(pts, spec.get("up", Vector3.UP))
	var m := pts.size()
	var cols := ring + 1
	var grid := PackedVector3Array()
	grid.resize(m * cols)
	var centers := PackedVector3Array()
	var arc := PackedFloat32Array()
	var acc := 0.0
	for i in m:
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		arc.append(acc)
		var f: Dictionary = fr[i]
		centers.append(pts[i])
		for j in cols:
			var ang := float(j) / float(ring) * TAU
			var yz := _sec(ang, a_top[i], a_bot[i], a_z[i], a_nt[i], a_nb[i])
			grid[i * cols + j] = pts[i] + (f.u as Vector3) * yz.x + (f.s as Vector3) * yz.y
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var idx := PackedInt32Array()
	for i in m:
		var r_mean := (a_top[i] + a_bot[i] + 2.0 * a_z[i]) * 0.25
		var circ := TAU * r_mean
		for j in cols:
			var p := grid[i * cols + j]
			var ts := grid[mini(i + 1, m - 1) * cols + j] - grid[maxi(i - 1, 0) * cols + j]
			var ta := grid[i * cols + (j + 1) % cols if j < ring else i * cols + 1] - grid[i * cols + (j - 1 if j > 0 else ring - 1)]
			var nrm := ta.cross(ts)
			var out_dir := p - centers[i]
			if nrm.length_squared() < 1e-20:
				nrm = out_dir if out_dir.length_squared() > 1e-20 else (fr[i].t as Vector3) * (1.0 if i > m / 2 else -1.0)
			if nrm.dot(out_dir) < 0.0 and out_dir.length_squared() > 1e-20:
				nrm = -nrm
			verts.append(p)
			norms.append(nrm.normalized())
			var a := float(j) / float(ring)
			uvs.append(Vector2(arc[i] * MM, a * circ * MM))
			uv2s.append(Vector2(r_mean * MM, 0.0))
			# la zona: 0 arriba (escudetes), 0,5 los lados, 1 abajo (almohadilla)
			var dv := absf(a - 0.5) * 2.0
			var zone := 0.5
			var up_frac := 1.0 - dv
			if dv > 1.0 - dorsal * 2.0:
				zone = lerpf(0.5, 0.0, smoothstep(1.0 - dorsal * 2.0, 1.0 - dorsal * 1.2, dv))
			elif up_frac > 1.0 - ventral * 2.0:
				zone = lerpf(0.5, 1.0, smoothstep(1.0 - ventral * 2.0, 1.0 - ventral * 1.4, up_frac))
			var under := smoothstep(0.55, 1.0, up_frac)
			var ao := a_ao[i] * (1.0 - ao_under * under)
			cols_c.append(Color(ao, zone, a_pad[i] * smoothstep(0.6, 0.95, up_frac), 1.0))
	# (las caras de delante, en el sentido de las agujas del reloj, como las de claw_mesh.gd)
	for i in m - 1:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return pack(verts, norms, uvs, uv2s, cols_c, idx)


## Un elipsoide de semiejes radii (m) con la orientación basis, en c, con bultos: bumps = [{ dir (en sus ejes), amp
## (fracción), width (rad) }]. zone: el valor de la zona en todo él (o −1: por la altura, como en limb). ao_under: lo que se
## oscurece la cara de abajo.
static func blob(c: Vector3, radii: Vector3, basis: Basis, ring: int, rings: int, opts := {}) -> Array:
	var bumps: Array = opts.get("bumps", [])
	var zone_v := float(opts.get("zone", -1.0))
	var ao_under := float(opts.get("ao_under", 0.25))
	var pad := float(opts.get("pad", 0.0))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var idx := PackedInt32Array()
	var cols := ring + 1
	var r_mean := (radii.x + radii.y + radii.z) / 3.0
	var grid := PackedVector3Array()
	var dirs := PackedVector3Array()
	for i in rings + 1:
		var th := float(i) / float(rings) * PI
		for j in cols:
			var ph := float(j) / float(ring) * TAU
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var k := 1.0
			for b: Dictionary in bumps:
				var bd: Vector3 = (b.dir as Vector3).normalized()
				var ang := acos(clampf(d.dot(bd), -1.0, 1.0))
				k += float(b.amp) * exp(-pow(ang / maxf(float(b.width), 0.05), 2.0))
			dirs.append(d)
			grid.append(c + basis * (d * radii * k))
	for i in rings + 1:
		for j in cols:
			var p := grid[i * cols + j]
			var ip := mini(i + 1, rings)
			var im := maxi(i - 1, 0)
			var ts := grid[ip * cols + j] - grid[im * cols + j]
			var ta := grid[i * cols + (j + 1 if j < ring else 1)] - grid[i * cols + (j - 1 if j > 0 else ring - 1)]
			var nrm := ts.cross(ta)
			var out_dir := p - c
			if nrm.length_squared() < 1e-20:
				nrm = out_dir
			if nrm.dot(out_dir) < 0.0:
				nrm = -nrm
			verts.append(p)
			norms.append(nrm.normalized())
			var d := dirs[i * cols + j]
			uvs.append(Vector2(float(j) / float(ring) * TAU * r_mean * MM, float(i) / float(rings) * PI * r_mean * MM))
			uv2s.append(Vector2(r_mean * MM, 0.0))
			var wd := basis * d
			var under := smoothstep(0.1, 0.9, -wd.y)
			var zone := zone_v if zone_v >= 0.0 else lerpf(0.5, 1.0, under)
			cols_c.append(Color(1.0 - ao_under * under, zone, pad * under, 1.0))
	for i in rings:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return pack(verts, norms, uvs, uv2s, cols_c, idx)


## Las capas del pelo: el mismo tubo repetido layers veces, con UV2.y = altura de la capa (de 1/layers a 1); el sombreador
## del pelo (paw_fur.gdshader) separa cada capa a lo largo de la normal y recorta los pelos.
static func shells(arrays: Array, layers: int) -> Array:
	if layers <= 0 or not has_triangles(arrays):
		return empty()
	var v0: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n0: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv0: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv20: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var c0: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var i0: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var idx := PackedInt32Array()
	var nv := v0.size()
	for l in layers:
		var h := float(l + 1) / float(layers)
		var base := verts.size()
		verts.append_array(v0)
		norms.append_array(n0)
		uvs.append_array(uv0)
		cols_c.append_array(c0)
		for k in nv:
			uv2s.append(Vector2(uv20[k].x, h))
		for k in i0.size():
			idx.append(i0[k] + base)
	return pack(verts, norms, uvs, uv2s, cols_c, idx)


## Junta varias superficies (con los mismos arrays) en una.
static func merge(list: Array) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols_c := PackedColorArray()
	var idx := PackedInt32Array()
	for a: Array in list:
		if not has_triangles(a):
			continue
		var base := verts.size()
		verts.append_array(a[Mesh.ARRAY_VERTEX])
		norms.append_array(a[Mesh.ARRAY_NORMAL])
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		uv2s.append_array(a[Mesh.ARRAY_TEX_UV2])
		cols_c.append_array(a[Mesh.ARRAY_COLOR])
		var ia: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for k in ia.size():
			idx.append(ia[k] + base)
	return pack(verts, norms, uvs, uv2s, cols_c, idx)


## Una superficie movida con xf (posiciones y normales).
static func moved(arrays: Array, xf: Transform3D) -> Array:
	if not has_triangles(arrays):
		return arrays
	var v: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var nr: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var nb := xf.basis.inverse().transposed()
	for k in v.size():
		v[k] = xf * v[k]
		nr[k] = (nb * nr[k]).normalized()
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = nr
	return out


## Multiplica la oclusión (rojo del color) de los vértices que quedan cerca de un punto (un pliegue entre dos piezas).
static func darken_near(arrays: Array, p: Vector3, radius: float, amount: float) -> void:
	if not has_triangles(arrays):
		return
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for k in v.size():
		var d := v[k].distance_to(p)
		if d < radius:
			var col := c[k]
			col.r *= 1.0 - amount * (1.0 - smoothstep(0.0, radius, d))
			c[k] = col
	arrays[Mesh.ARRAY_COLOR] = c


static func pack(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, col: PackedColorArray, idx: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


static func empty() -> Array:
	return pack(PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedVector2Array(), PackedColorArray(), PackedInt32Array())


static func has_triangles(arrays: Array) -> bool:
	return arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >= 3


## Vértices de una superficie.
static func vertex_count(arrays: Array) -> int:
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if has_triangles(arrays) else 0


## Una espina suave por los puntos dados (Catmull-Rom), con n estaciones repartidas por largo.
static func spine(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	var dense := PackedVector3Array()
	var m := pts.size()
	for i in m - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, m - 1)]
		for q in 12:
			var t := float(q) / 12.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(pts[m - 1])
	# remuestreo por largo
	var acc := PackedFloat32Array([0.0])
	for i in range(1, dense.size()):
		acc.append(acc[i - 1] + dense[i].distance_to(dense[i - 1]))
	var total := acc[acc.size() - 1]
	var out := PackedVector3Array()
	var j := 0
	for i in n:
		var want := total * float(i) / float(n - 1)
		while j < acc.size() - 2 and acc[j + 1] < want:
			j += 1
		var u := (want - acc[j]) / maxf(acc[j + 1] - acc[j], 1e-9)
		out.append(dense[j].lerp(dense[j + 1], clampf(u, 0.0, 1.0)))
	return out


## Campana de Gauss de ancho w centrada en c.
static func gauss(t: float, c: float, w: float) -> float:
	return exp(-pow((t - c) / w, 2.0))


## Un array de n valores iguales.
static func filled(n: int, v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(v)
	return a
