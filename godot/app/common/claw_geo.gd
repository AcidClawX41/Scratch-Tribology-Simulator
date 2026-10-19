## La malla de una garra para la biblioteca de materiales (unidad 5e), con las coordenadas que lee su sombreador: UV.x = s
## (mm desde la base, a lo largo de la línea media), UV.y = vuelta alrededor (0-1, 0 arriba, la cara dorsal) y UV2.x =
## radio (mm). Son las mismas de la garra de la cetrería (lab/cetreria/claw_mesh.gd), así que el mismo material se ve
## igual en las dos, y el material viste la garra sin moverle un vértice. UV2.y = el largo de la garra (mm: dónde acaba,
## para el sombreador, que así sirve a garras de largos distintos con un mismo material).
##
## La forma sale de los datos de cada garra (Catalog.CLAWS: alcance, área y semiángulo de la punta, curvatura), con las
## cuentas del motor: el radio a lo largo es el del cono del motor con su punta esférica (Contact.tip_geometry y
## hole_radius, con la base de 0,15 × alcance de Physics.MODEL), el mismo perfil que la garra natural de ClawCare; la línea
## media gira 35° + 115°·curva a lo largo del largo, como en el dibujo del banco y en la cetrería. No calcula física: la
## pide. Las garras de los animales del coche en marcha (rig3d.gd) usan model_claw: el largo y la curva que da cada
## especie (los del catálogo), la sección de su dibujo y su ahusado, en dos trozos (la base y la punta, que se mella o se
## dobla). Se puede llamar desde un hilo (solo arrays).
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Rng = preload("res://core/shared/rng.gd")
const Physics = preload("res://core/lab/physics.gd")
const Catalog = preload("res://core/lab/catalog.gd")
## El arco de cada garra, con su fuente (CareData.claw_arc, unidad 5g): la misma medida para la cetrería, la galería y el
## coche.
const CareData = preload("res://core/lab/claw_care_data.gd")

## Paso del perfil (mm) y segmentos de cada anillo (escritorio y teléfono).
const STEP_MM := 0.5
const RING := 24
const RING_MOBILE := 14
## Ahusado de las garras de los modelos del coche (dibujo de la 4l): la sección a una fracción f del largo es la de la
## base por (1 − f)^TAPER_EXP.
const TAPER_EXP := 0.8


## Los arrays en construcción (miembros: se amplían sin copiarse).
class Build:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TANGENT] = t
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_INDEX] = idx
		return a


## La garra de un id del catálogo: { length_mm, base_r_mm, tip_r_um, curve, arc_deg, k (1/mm) }.
static func spec_of(claw_id: String) -> Dictionary:
	var c: Variant = Catalog.find_by_id(Catalog.CLAWS, claw_id)
	if c == null:
		return {}
	var cl: Dictionary = c
	var reach := float(cl.get("reach", 30.0))
	var curve := float(cl.get("curve", 0.5))
	# el arco medido de la garra de la ficha (Fowler et al. 2009 en las rapaces…); sin medición, el del dibujo del banco
	var arc := float(CareData.claw_arc(claw_id).arcDeg)
	return {
		"id": claw_id, "length_mm": reach, "base_r_mm": float(Physics.MODEL["clawBase"]) * reach, "area": float(cl.get("area", 0.05)),
		"alpha": float(cl.get("alpha", 15.0)), "curve": curve, "arc_deg": arc, "k": deg_to_rad(arc) / maxf(reach, 1.0),
		"color": String(cl.get("col", "#2e2a26")),
	}


## El perfil (s, r) de una garra de largo length_mm (mm; con crecimiento de más, más larga y con la misma punta): el del
## motor, como ClawCare._build_profile.
static func profile(spec: Dictionary, length_mm := -1.0) -> Array:
	var reach := float(spec.length_mm)
	var L := length_mm if length_mm > 0.0 else reach
	var tip := Contact.tip_geometry(float(spec.area), float(spec.alpha), float(spec.base_r_mm))
	var ss := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var n := int(ceil(L / STEP_MM)) + 1
	for i in n:
		var s := minf(float(i) * STEP_MM, L)
		var d := L - s
		ss.append(s)
		rs.append(Contact.hole_radius(tip, d) if d > 0.0 else 0.0)
	return [ss, rs]


static func _point(s: float, k: float) -> Vector3:
	if absf(k) < 1e-9:
		return Vector3(s, 0.0, 0.0)
	return Vector3(sin(k * s) / k, (cos(k * s) - 1.0) / k, 0.0)


static func _tangent(s: float, k: float) -> Vector3:
	return Vector3(cos(k * s), -sin(k * s), 0.0)


static func _up(s: float, k: float) -> Vector3:
	return Vector3(sin(k * s), cos(k * s), 0.0)


## Un anillo de la garra: centro c, tangente t, «arriba» up, semialto h y semiancho w (mm), en s (mm), con la pendiente
## del radio a lo largo (drds; la normal se inclina con ella) o, en un polo (pole ±1), la normal a lo largo de ±t; apex:
## el largo de la garra (mm, en UV2.y).
static func _ring(b: Build, c: Vector3, t: Vector3, up: Vector3, h: float, w: float, s: float, ring: int, scale: float, drds: float, apex: float,
		pole := 0) -> void:
	var side := Vector3(0.0, 0.0, 1.0)
	var r := sqrt(maxf(h, 0.0) * maxf(w, 0.0))
	for j in ring + 1:
		var a := float(j) / float(ring)
		var ang := a * TAU
		var cu := cos(ang)
		var sz := sin(ang)
		var off := up * (cu * h) + side * (sz * w)
		var nrm: Vector3
		if pole != 0:
			nrm = t * float(pole)
		else:
			# la normal de la elipse (semiejes h y w), inclinada por la pendiente del radio
			nrm = (up * (cu * maxf(w, 1e-6)) + side * (sz * maxf(h, 1e-6))).normalized()
			nrm = (nrm - t * drds).normalized()
		b.v.append((c + off) * scale)
		b.n.append(nrm)
		# la tangente, a lo largo de s (por si un sombreador la pide; los de la biblioteca la sacan de la pantalla)
		var tw := (t - nrm * t.dot(nrm)).normalized()
		b.t.append_array(PackedFloat32Array([tw.x, tw.y, tw.z, 1.0]))
		b.uv.append(Vector2(s, a))
		b.uv2.append(Vector2(r, apex))


## Los triángulos entre las filas de anillos row0 .. row1 (de ring + 1 vértices cada una), desde el vértice base.
static func _quads(b: Build, base: int, rows: int, ring: int) -> void:
	var cols := ring + 1
	for q in rows - 1:
		for j in ring:
			var a0 := base + q * cols + j
			var b0 := base + (q + 1) * cols + j
			b.idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])


## Arrays de un tubo a lo largo de la línea media (curvatura k, 1/mm), con semialto hh y semiancho ww (mm) en las
## estaciones ss (mm), ring segmentos por vuelta. cap_len > 0: la base se cierra con un casquete hacia atrás de ese largo
## (mm; la garra queda cerrada dentro del dedo); si no, queda abierta. La punta acaba en un vértice cuando su radio es 0.
## scale: unidades de la malla por mm (0,1 para centímetros); apex: el largo de la garra entera (mm; por defecto, la
## última estación).
static func tube_hw(ss: PackedFloat64Array, hh: PackedFloat64Array, ww: PackedFloat64Array, k: float, ring: int, cap_len := 0.0, scale := 1.0,
		apex := -1.0) -> Array:
	var b := Build.new()
	var n := mini(ss.size(), mini(hh.size(), ww.size()))
	if n < 2:
		return b.arrays()
	var ap := apex if apex > 0.0 else ss[n - 1]
	var rows := 0
	if cap_len > 0.0:
		var t0 := _tangent(ss[0], k)
		var up0 := _up(ss[0], k)
		var p0 := _point(ss[0], k)
		var r0 := sqrt(maxf(hh[0], 0.0) * maxf(ww[0], 0.0))
		for q: int in [3, 2, 1]:
			var ph := float(q) / 3.0 * PI * 0.5
			var f := cos(ph)
			var back := cap_len * sin(ph)
			# casquete elíptico (semieje cap_len a lo largo y el radio de la base): pendiente (r0/cap_len)·tan φ
			var slope := (r0 / cap_len) * tan(ph) if q < 3 else 0.0
			_ring(b, p0 - t0 * back, t0, up0, hh[0] * f, ww[0] * f, ss[0] - back, ring, scale, slope, ap, -1 if q == 3 else 0)
			rows += 1
	for i in n:
		var s := ss[i]
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, n - 1)
		var ds := ss[i1] - ss[i0]
		var r_a := sqrt(maxf(hh[i0], 0.0) * maxf(ww[i0], 0.0))
		var r_b := sqrt(maxf(hh[i1], 0.0) * maxf(ww[i1], 0.0))
		var drds := (r_b - r_a) / ds if ds > 1e-9 else 0.0
		_ring(b, _point(s, k), _tangent(s, k), _up(s, k), maxf(hh[i], 0.0), maxf(ww[i], 0.0), s, ring, scale, drds, ap)
		rows += 1
	_quads(b, 0, rows, ring)
	return b.arrays()


## Arrays de la garra: un tubo a lo largo de la línea media (curvatura k, 1/mm) con los radios rs en las estaciones ss
## (mm), de s0 a s1 (para partirla en trozos), con ring segmentos por vuelta. La base queda abierta (entra en el dedo); la
## punta acaba en un vértice. aspect: alto/ancho de la sección (1: redonda; la superficie se conserva). scale: unidades de
## la malla por mm (0,1 para centímetros).
static func tube(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, ring: int, s0 := 0.0, s1 := INF, aspect := 1.0, scale := 1.0) -> Array:
	var ha := sqrt(maxf(aspect, 0.05))
	var apex := ss[ss.size() - 1] if not ss.is_empty() else -1.0
	var sel := PackedFloat64Array()
	var hh := PackedFloat64Array()
	var ww := PackedFloat64Array()
	for i in mini(ss.size(), rs.size()):
		if ss[i] >= s0 - 1e-9 and ss[i] <= s1 + 1e-9:
			var r := maxf(rs[i], 0.0)
			sel.append(ss[i])
			hh.append(r * ha)
			ww.append(r / ha)
	return tube_hw(sel, hh, ww, k, ring, 0.0, scale, apex)


## Una garra entera del catálogo en un ArrayMesh (mm, base en el origen, partiendo hacia +X y curvándose hacia −Y).
static func claw_mesh(claw_id: String, ring := RING, length_mm := -1.0, aspect := 1.0) -> ArrayMesh:
	var spec := spec_of(claw_id)
	var mesh := ArrayMesh.new()
	if spec.is_empty():
		return mesh
	var pr := profile(spec, length_mm)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tube(pr[0], pr[1], float(spec.k), ring, 0.0, INF, aspect))
	return mesh


## Dónde está la punta (mm) de una garra de curvatura k y largo L.
static func tip_point(k: float, length_mm: float) -> Vector3:
	return _point(length_mm, k)


## Una garra de los animales del coche en marcha (rig3d.gd), en el marco de su base (mm: parte hacia +X, «arriba» +Y, se
## curva hacia −Y): el largo length_mm y el arco arc_deg (grados) que da la especie (el largo, el del catálogo), la
## sección de la base base_h_mm × base_w_mm (alto × ancho, la del dibujo de cada animal, que encaja en su dedo) y su
## ahusado hasta la punta, en dos trozos: la base (de 0 a cut del largo, con nb tramos y la base cerrada) y la punta (de
## cut al final, nt tramos, más juntos hacia la punta). Devuelve { base, tip (arrays), cut_point, tip_point, tip_dir }.
static func model_claw(length_mm: float, base_h_mm: float, base_w_mm: float, arc_deg: float, nb: int, nt: int, ring: int, cut := 0.6) -> Dictionary:
	var L := maxf(length_mm, 0.1)
	var k := deg_to_rad(arc_deg) / L
	var s_cut := L * clampf(cut, 0.05, 0.95)
	var ss_b := PackedFloat64Array()
	var hh_b := PackedFloat64Array()
	var ww_b := PackedFloat64Array()
	for i in nb + 1:
		var s := s_cut * float(i) / float(maxi(nb, 1))
		var f := pow(maxf(1.0 - s / L, 0.0), TAPER_EXP)
		ss_b.append(s)
		hh_b.append(base_h_mm * 0.5 * f)
		ww_b.append(base_w_mm * 0.5 * f)
	var ss_t := PackedFloat64Array()
	var hh_t := PackedFloat64Array()
	var ww_t := PackedFloat64Array()
	for i in nt + 1:
		var u := float(i) / float(maxi(nt, 1))
		var s := s_cut + (L - s_cut) * (1.0 - pow(1.0 - u, 1.5))
		var f := pow(maxf(1.0 - s / L, 0.0), TAPER_EXP)
		ss_t.append(s)
		hh_t.append(base_h_mm * 0.5 * f)
		ww_t.append(base_w_mm * 0.5 * f)
	var cap := minf(base_h_mm, base_w_mm) * 0.5 * 0.6
	return {
		"base": tube_hw(ss_b, hh_b, ww_b, k, ring, cap, 1.0, L), "tip": tube_hw(ss_t, hh_t, ww_t, k, ring, 0.0, 1.0, L),
		"cut_point": _point(s_cut, k), "tip_point": _point(L, k), "tip_dir": _tangent(L, k), "cut_mm": s_cut, "k": k,
	}


# ════════ Garras dobladas y melladas, de una pieza (unidad 4y) ════════
# «Una garra doblada se ve doblada en la punta y una mellada, desconchada; nunca piezas sueltas» (Eric, 18-10-2026). Antes la
# punta doblada era la pieza de la punta girada sobre el corte (con un hueco abierto entre las dos) y la mellada, la base
# encogida entera: se veían en trozos. Aquí, la misma malla de model_claw, deformada (doblada) o cerrada en el punto de la
# rotura (mellada), en su marco (mm, o lo que diga frame/origin/scale): sigue pegada a la otra pieza en el corte. Dibujo: lo
# que se dobla o se pierde lo dice la física (CarSpeedMarks.fracture: brokenMm); el ángulo de la punta doblada, la forma de la
# rotura y su irregularidad, no (BEND_ANGLE, CHIP_JAG).

## Dibujo: lo que se abre la punta doblada (rad) y lo que mide la charnela (fracción de lo que se dobla) en la que pasa de 0 a
## todo el ángulo; la irregularidad de la rotura de una garra mellada (fracción del radio en el punto de la rotura).
const BEND_ANGLE := 0.6
const BEND_HINGE := 0.35
const CHIP_JAG := 0.45


## Los arrays de un trozo de garra (los de model_claw, en mm en el marco de su base) doblados desde s_bend (mm): cada vértice
## gira alrededor del eje lateral (+Z) que pasa por la línea media en s_bend, con su s (UV.x) y la charnela suave hasta
## s_bend + hinge (mm); en s_bend no se mueve nada, así que la malla sigue pegada a lo de antes. angle > 0: la punta se abre
## (sube hacia +Y). frame/origin/scale: el marco en el que están los vértices (v = origin + frame·(v_mm·scale)), el de rig3d.
static func bend_arrays(arrays: Array, k: float, s_bend: float, hinge: float, angle: float, frame := Basis.IDENTITY,
		origin := Vector3.ZERO, scale := 1.0) -> Array:
	var out := arrays.duplicate()
	var vs: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var ns: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var ts: PackedFloat32Array = (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var inv := frame.inverse()
	var pivot := _point(s_bend, k)
	var h := maxf(hinge, 1e-3)
	for i in vs.size():
		var s := uvs[i].x
		var th := angle * smoothstep(s_bend, s_bend + h, s)
		if is_zero_approx(th):
			continue
		var rot := Basis(Vector3(0.0, 0.0, 1.0), th)
		var v_mm := inv * (vs[i] - origin) / scale
		vs[i] = origin + frame * ((pivot + rot * (v_mm - pivot)) * scale)
		ns[i] = (frame * (rot * (inv * ns[i]))).normalized()
		var tw := frame * (rot * (inv * Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2])))
		ts[i * 4] = tw.x
		ts[i * 4 + 1] = tw.y
		ts[i * 4 + 2] = tw.z
	out[Mesh.ARRAY_VERTEX] = vs
	out[Mesh.ARRAY_NORMAL] = ns
	out[Mesh.ARRAY_TANGENT] = ts
	return out


## Un trozo de garra mellada, de s0 a s_keep (mm), cerrado en la rotura (una cara cóncava e irregular, como la de una
## concha: CHIP_JAG), con la sección y el ahusado de model_claw (base base_h_mm × base_w_mm, arco arc_deg, largo length_mm);
## cap_start: la base cerrada dentro del dedo (el trozo de la base). Las mismas UV que model_claw (UV2.y, el largo entero).
## seed_text: la forma de la rotura (determinista, con rng.gd). frame/origin/scale como bend_arrays.
static func chipped_arrays(length_mm: float, base_h_mm: float, base_w_mm: float, arc_deg: float, s0: float, s_keep: float, rows: int,
		ring: int, seed_text: String, cap_start := false, frame := Basis.IDENTITY, origin := Vector3.ZERO, scale := 1.0) -> Array:
	var L := maxf(length_mm, 0.1)
	var k := deg_to_rad(arc_deg) / L
	var s1 := clampf(s_keep, s0 + 0.05, L)
	var ss := PackedFloat64Array()
	var hh := PackedFloat64Array()
	var ww := PackedFloat64Array()
	var n := maxi(rows, 2)
	for i in n + 1:
		var s := s0 + (s1 - s0) * float(i) / float(n)
		var f := pow(maxf(1.0 - s / L, 0.0), TAPER_EXP)
		ss.append(s)
		hh.append(base_h_mm * 0.5 * f)
		ww.append(base_w_mm * 0.5 * f)
	# la rotura: un anillo más pequeño un poco más allá y el polo, hundido (cóncava)
	var f1 := pow(maxf(1.0 - s1 / L, 0.0), TAPER_EXP)
	var r1 := sqrt(base_h_mm * base_w_mm) * 0.5 * f1
	ss.append(s1 + r1 * 0.12)
	hh.append(base_h_mm * 0.5 * f1 * 0.62)
	ww.append(base_w_mm * 0.5 * f1 * 0.62)
	ss.append(s1 + r1 * 0.13)
	hh.append(0.0)
	ww.append(0.0)
	var cap := minf(base_h_mm, base_w_mm) * 0.5 * 0.6 if cap_start else 0.0
	var a := tube_hw(ss, hh, ww, k, ring, cap, 1.0, L)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var cols := ring + 1
	var total := vs.size() / cols
	var t1 := _tangent(s1, k)
	var rng := Rng.new(Rng.seed_of(seed_text))
	var jag := PackedFloat32Array()
	for j in ring:
		jag.append((rng.next() - 0.5) * 2.0 * CHIP_JAG * r1)
	# el borde de la rotura, irregular a lo largo; el polo, hundido hacia dentro; sus normales miran fuera de la garra
	for q: int in [total - 3, total - 2, total - 1]:
		for j in cols:
			var idx := q * cols + j
			var jj := j % ring
			if q == total - 1:
				vs[idx] -= t1 * r1 * 0.25
			elif q == total - 2:
				vs[idx] += t1 * jag[jj]
			else:
				vs[idx] += t1 * jag[jj] * 0.35
			if q >= total - 2:
				ns[idx] = (t1 * 0.85 + ns[idx] * 0.15).normalized()
	var ts: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
	for i in vs.size():
		vs[i] = origin + frame * (vs[i] * scale)
		ns[i] = (frame * ns[i]).normalized()
		var tw := frame * Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2])
		ts[i * 4] = tw.x
		ts[i * 4 + 1] = tw.y
		ts[i * 4 + 2] = tw.z
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_NORMAL] = ns
	a[Mesh.ARRAY_TANGENT] = ts
	return a
