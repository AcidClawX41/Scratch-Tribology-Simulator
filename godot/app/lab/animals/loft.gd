## Mallas de los animales del coche en marcha hechas en código (unidad 4l): cilindros generalizados («lofts»).
##
## Un loft es una superficie barrida a lo largo de una curva (la columna, un hueso, un dedo, una garra): unas pocas
## estaciones de control (centro y radios de la sección) se interpolan con Catmull-Rom y en cada anillo se pone una
## sección superelíptica con cuatro radios (arriba, abajo y a los lados). Así un tronco, un cuello, un tarso o una garra
## se describen con cinco o seis números por estación, en centímetros de la anatomía.
##   - Marco de cada anillo: la tangente T de la curva, «arriba» = side × T (con side = +z, el lado de quien mira, en una
##     curva del plano sagital «arriba» es el dorso) y el lateral L = T × arriba.
##   - Normales suaves: las derivadas de la superficie (a lo largo del anillo y de la curva), orientadas hacia fuera; en
##     los polos (puntas y casquetes), la de la curva.
##   - Extremos: «round» (casquete, una unión suave con la pieza de al lado), «point» (acaba en punta: garras, picos) o
##     «none» (abierto: queda dentro de otra pieza).
##   - UV: x alrededor (0 y 1 en la costura, que va por el vientre, fuera de la vista; 0,5 el dorso y 0,25 el lado de L),
##     y a lo largo (0 → 1), dentro de uv_rect (un trozo del mapa de color de la pieza). UV2: en centímetros entre el
##     lado de la tesela del detalle (plumas, pelo, escamas), con un número entero de teselas alrededor (sin costura).
##   - Color de vértice: paint(s, u, p) → Color; su alfa es lo que se mueve con el viento (plumas y pelo sueltos).
##   - Tangentes para los mapas de normales: a lo largo de UV.x, con el signo que lleva la bitangente hacia +UV.y.
## Acc junta varias piezas (una superficie por material) de un mismo hueso: una sola malla y pocas llamadas de dibujo.
## Solo dibujo: nada de física.
extends RefCounted

## Signo de la bitangente frente a la convención de los mapas de normales de Godot (comprobado con luz rasante).
const BITANGENT_SIGN := 1.0


## Una superficie en construcción (miembros: se amplían sin copiarse).
class Surf:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()


## Acumulador de una malla con varias superficies, una por material (su id, un texto).
class Acc:
	extends RefCounted
	var surf := {}
	## Transformación que se aplica a lo que se añade (p. ej., del cuerpo al marco del hueso).
	var xf := Transform3D.IDENTITY

	func s(mat: String) -> Surf:
		if not surf.has(mat):
			surf[mat] = Surf.new()
		return surf[mat]

	func vertex_count() -> int:
		var k := 0
		for m: String in surf:
			k += (surf[m] as Surf).v.size()
		return k

	## La malla (una superficie por material, en orden alfabético de su id) y los ids en ese orden.
	func commit() -> Array:
		var mesh := ArrayMesh.new()
		var mats: Array = []
		var keys: Array = surf.keys()
		keys.sort()
		for m: String in keys:
			var q: Surf = surf[m]
			if q.idx.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = q.v
			arrays[Mesh.ARRAY_NORMAL] = q.n
			arrays[Mesh.ARRAY_TANGENT] = q.t
			arrays[Mesh.ARRAY_COLOR] = q.c
			arrays[Mesh.ARRAY_TEX_UV] = q.uv
			arrays[Mesh.ARRAY_TEX_UV2] = q.uv2
			arrays[Mesh.ARRAY_INDEX] = q.idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mats.append(m)
		return [mesh, mats]


## Interpolación de Catmull-Rom (uniforme) entre b y c.
static func _cr(a: Variant, b: Variant, c: Variant, d: Variant, t: float) -> Variant:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (3.0 * b - a - 3.0 * c + d) * t3)


## Remuestrea las estaciones de control en n + 1 anillos: [centros, radios (Vector4: arriba, abajo, lado, exponente)].
static func resample(pts: PackedVector3Array, rad: Array, n: int) -> Array:
	var k := pts.size()
	var cum := PackedFloat32Array([0.0])
	for i in range(1, k):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := cum[k - 1]
	var cs := PackedVector3Array()
	var rs: Array = []
	var seg := 0
	for j in n + 1:
		var s := total * float(j) / float(n)
		while seg < k - 2 and s > cum[seg + 1]:
			seg += 1
		var span := maxf(cum[seg + 1] - cum[seg], 1e-6)
		var t := clampf((s - cum[seg]) / span, 0.0, 1.0)
		var i0 := maxi(seg - 1, 0)
		var i3 := mini(seg + 2, k - 1)
		cs.append(_cr(pts[i0], pts[seg], pts[seg + 1], pts[i3], t))
		var r: Vector4 = _cr(rad[i0], rad[seg], rad[seg + 1], rad[i3], t)
		rs.append(Vector4(maxf(r.x, 0.0), maxf(r.y, 0.0), maxf(r.z, 0.0), clampf(r.w, 0.6, 8.0)))
	return [cs, rs]


## Un loft. st: estaciones [Vector3 centro, arriba, abajo, lado (radios, cm), exponente (opcional: 2 elipse, > 2 más
## cuadrada, < 2 en quilla)]. o: side, segs (alrededor, par), rings (tramos a lo largo), cap0 y cap1, paint (Callable:
## s, u, p → Color), col (Color, sin paint), tile (cm), uv_rect, loose (alfa del color de vértice sin paint).
static func loft(acc: Acc, mat: String, st: Array, o := {}) -> void:
	var pts := PackedVector3Array()
	var rad: Array = []
	for e: Array in st:
		pts.append(e[0])
		rad.append(Vector4(float(e[1]), float(e[2]), float(e[3]), float(e[4]) if e.size() > 4 else 2.0))
	if pts.size() < 2:
		return
	var n := maxi(int(o.get("rings", 8)), 1)
	var rs0: Array = resample(pts, rad, n) if pts.size() > 2 or n > 1 else [pts, rad]
	var cs: PackedVector3Array = rs0[0]
	var rr: Array = rs0[1]
	var side: Vector3 = o.get("side", Vector3.BACK)
	# casquetes: anillos de más, en cuarto de círculo, hasta un polo
	var cap0 := String(o.get("cap0", "round"))
	var cap1 := String(o.get("cap1", "round"))
	var cq := int(o.get("cap_rings", 4))
	var t0 := (cs[1] - cs[0]).normalized()
	var t1 := (cs[cs.size() - 1] - cs[cs.size() - 2]).normalized()
	var pre_c := PackedVector3Array()
	var pre_r: Array = []
	var post_c := PackedVector3Array()
	var post_r: Array = []
	if cap0 == "round":
		var r0: Vector4 = rr[0]
		var len0 := float(o.get("cap_len0", -1.0))
		if len0 < 0.0:
			len0 = minf(r0.z, (r0.x + r0.y) * 0.5)
		for q in range(cq, 0, -1):
			var ph := float(q) / float(cq) * PI * 0.5
			pre_c.append(cs[0] - t0 * len0 * sin(ph))
			var f := cos(ph)
			pre_r.append(Vector4(r0.x * f, r0.y * f, r0.z * f, r0.w))
	if cap1 == "round":
		var r1: Vector4 = rr[rr.size() - 1]
		var len1 := float(o.get("cap_len1", -1.0))
		if len1 < 0.0:
			len1 = minf(r1.z, (r1.x + r1.y) * 0.5)
		for q in range(1, cq + 1):
			var ph := float(q) / float(cq) * PI * 0.5
			post_c.append(cs[cs.size() - 1] + t1 * len1 * sin(ph))
			var f := cos(ph)
			post_r.append(Vector4(r1.x * f, r1.y * f, r1.z * f, r1.w))
	var cc := PackedVector3Array()
	cc.append_array(pre_c)
	cc.append_array(cs)
	cc.append_array(post_c)
	var rad_all: Array = pre_r + rr + post_r
	var tube := {
		"side": side, "segs": int(o.get("segs", 16)), "paint": o.get("paint", Callable()), "col": o.get("col", Color(1, 1, 1, 0)),
		"tile": float(o.get("tile", 4.0)), "uv_rect": o.get("uv_rect", Rect2(0, 0, 1, 1)), "loose": float(o.get("loose", 0.0)),
		"pole0": cap0 == "round" or cap0 == "point", "pole1": cap1 == "round" or cap1 == "point", "flip_v": bool(o.get("flip_v", false)),
	}
	tube_rings(acc, mat, cc, rad_all, tube)


## Los anillos ya muestreados (centros y radios) como superficie: el corazón de loft().
static func tube_rings(acc: Acc, mat: String, cc: PackedVector3Array, rad_all: Array, o: Dictionary) -> void:
	var m := cc.size()
	if m < 2:
		return
	var segs := maxi(int(o.segs), 3)
	var side: Vector3 = o.side
	var paint: Callable = o.paint
	var col: Color = o.col
	var tile := maxf(float(o.tile), 0.01)
	var uvr: Rect2 = o.uv_rect
	var loose := float(o.loose)
	var q := acc.s(mat)
	var base := q.v.size()
	var xf := acc.xf
	var nb := xf.basis.orthonormalized()
	# marcos, largo recorrido y perímetro medio
	var ups := PackedVector3Array()
	var lats := PackedVector3Array()
	var tans := PackedVector3Array()
	var arc := PackedFloat32Array()
	var up_prev := Vector3.ZERO
	var acc_len := 0.0
	var per := 0.0
	for j in m:
		var tg := (cc[mini(j + 1, m - 1)] - cc[maxi(j - 1, 0)])
		if tg.length_squared() < 1e-12:
			tg = tans[j - 1] if j > 0 else Vector3.RIGHT
		tg = tg.normalized()
		var up := side.cross(tg)
		if up.length_squared() < 1e-8:
			up = up_prev if up_prev != Vector3.ZERO else tg.cross(Vector3.RIGHT if absf(tg.x) < 0.9 else Vector3.UP)
		up = up.normalized()
		if up_prev != Vector3.ZERO and up.dot(up_prev) < 0.0 and side.cross(tg).length_squared() < 1e-4:
			up = -up
		up_prev = up
		ups.append(up)
		lats.append(tg.cross(up).normalized())
		tans.append(tg)
		if j > 0:
			acc_len += cc[j].distance_to(cc[j - 1])
		arc.append(acc_len)
		var r: Vector4 = rad_all[j]
		per += PI * ((r.x + r.y) * 0.5 + r.z)
	per /= float(m)
	var around := maxf(1.0, roundf(per / tile))
	var total := maxf(acc_len, 1e-6)
	# vértices (una columna de más en la costura)
	var cols := segs + 1
	var pos := PackedVector3Array()
	pos.resize(m * cols)
	var cosv := PackedFloat32Array()
	var sinv := PackedFloat32Array()
	for i in cols:
		var a := TAU * float(i) / float(segs)
		cosv.append(cos(a))
		sinv.append(sin(a))
	for j in m:
		var r: Vector4 = rad_all[j]
		var e := 2.0 / r.w
		for i in cols:
			var c := cosv[i]
			var sn := sinv[i]
			if absf(r.w - 2.0) > 0.01:
				c = signf(c) * pow(absf(c), e)
				sn = signf(sn) * pow(absf(sn), e)
			# costura por el vientre: a = 0 abajo, π/2 el lateral L, π el dorso
			var dv := -c * (r.y if c > 0.0 else r.x)
			pos[j * cols + i] = cc[j] + ups[j] * dv + lats[j] * (sn * r.z)
	var pole0 := bool(o.get("pole0", false))
	var flip_v := bool(o.get("flip_v", false))
	for j in m:
		var s01 := arc[j] / total
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, m - 1)
		var r: Vector4 = rad_all[j]
		var tiny := r.x + r.y + r.z < 1e-4
		for i in cols:
			var p := pos[j * cols + i]
			var ia := (i + 1) % cols if i < segs else 1
			var ib := i - 1 if i > 0 else segs - 1
			var du := pos[j * cols + ia] - pos[j * cols + ib]
			var dvv := pos[j1 * cols + i] - pos[j0 * cols + i]
			var nn := du.cross(dvv)
			if tiny or nn.length_squared() < 1e-10:
				nn = tans[j] * (-1.0 if (j == 0 and pole0) or (j < m / 2 and tiny) else 1.0)
			else:
				var out := p - cc[j]
				if out.length_squared() < 1e-10:
					out = tans[j] * (1.0 if j > m / 2 else -1.0)
				if nn.dot(out) < 0.0:
					nn = -nn
			nn = nn.normalized()
			var tu := du.normalized() if du.length_squared() > 1e-12 else lats[j]
			var w := BITANGENT_SIGN if nn.cross(tu).dot(dvv) >= 0.0 else -BITANGENT_SIGN
			var u := float(i) / float(segs)
			var cl := col
			if paint.is_valid():
				cl = paint.call(s01, u, p)
			elif cl.a <= 0.0:
				cl = Color(1, 1, 1, loose)
			q.v.append(xf * p)
			q.n.append((nb * nn).normalized())
			var tw := (nb * tu).normalized()
			q.t.append_array(PackedFloat32Array([tw.x, tw.y, tw.z, w]))
			q.c.append(cl)
			q.uv.append(uvr.position + Vector2(u, s01) * uvr.size)
			q.uv2.append(Vector2(u * around, (acc_len - arc[j] if flip_v else arc[j]) / tile))
	# triángulos: se orientan una vez con un cuadrilátero del medio (horario visto desde fuera, como quiere Godot)
	var jm := m / 2
	var flip := false
	if m >= 2:
		var ja := mini(jm, m - 2)
		var pa := pos[ja * cols]
		var pb := pos[ja * cols + 1]
		var pc := pos[(ja + 1) * cols]
		var fn := (pb - pa).cross(pc - pa)
		var out := (pa + pb + pc) / 3.0 - (cc[ja] + cc[ja + 1]) * 0.5
		flip = fn.dot(out) > 0.0
	if xf.basis.determinant() < 0.0:
		flip = not flip
	for j in m - 1:
		for i in segs:
			var a := base + j * cols + i
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if flip:
				q.idx.append_array(PackedInt32Array([a, c, b, b, c, d]))
			else:
				q.idx.append_array(PackedInt32Array([a, b, c, b, d, c]))


## Un elipsoide: centro, eje (su dirección y su semilargo) y radios arriba, abajo y a los lados (con side para el marco).
static func blob(acc: Acc, mat: String, c: Vector3, axis: Vector3, half: float, hu: float, hd: float, w: float, o := {}) -> void:
	var d := axis.normalized()
	var oo := o.duplicate()
	oo["cap_len0"] = half * 0.5
	oo["cap_len1"] = half * 0.5
	if not oo.has("rings"):
		oo["rings"] = 4
	loft(acc, mat, [[c - d * half * 0.5, hu * 0.87, hd * 0.87, w * 0.87], [c, hu, hd, w], [c + d * half * 0.5, hu * 0.87, hd * 0.87, w * 0.87]], oo)


## Una garra o una uña de queratina: un cono curvo de base (base_h alto, base_w ancho) que sale de base hacia dir y se
## curva hacia -up curve_deg grados a lo largo de len, afilado hasta la punta. Devuelve la punta.
static func claw(acc: Acc, mat: String, base: Vector3, dir: Vector3, up: Vector3, len: float, base_h: float, base_w: float, curve_deg: float,
		o := {}) -> Vector3:
	var d := dir.normalized()
	var u := (up - d * up.dot(d)).normalized()
	var k := int(o.get("stations", 6))
	var st: Array = []
	var total := deg_to_rad(curve_deg)
	var p := base
	var step := len / float(k - 1)
	var ang := 0.0
	for i in k:
		var f := float(i) / float(k - 1)
		var taper := pow(1.0 - f, 0.85)
		var hh := base_h * 0.5 * taper
		st.append([p, hh * 1.05, hh * 0.95, base_w * 0.5 * taper, 2.0])
		ang = total * (f + 0.5 / float(k - 1))
		var dd := d * cos(ang) - u * sin(ang)
		p += dd * step
	var tip: Vector3 = st[k - 1][0]
	var oo := o.duplicate()
	oo["side"] = d.cross(u).normalized() if not oo.has("side") else oo.side
	oo["cap0"] = String(o.get("cap0", "round"))
	oo["cap1"] = "point"
	if not oo.has("rings"):
		oo["rings"] = 8
	loft(acc, mat, st, oo)
	return tip


## Una tarjeta (un cuadrilátero de dos caras para plumas o mechones): esquina de la base en o, a lo largo de ax (su largo)
## y de ancho aw centrado en o. uv_rect: su trozo de textura (x a lo ancho, y de la base a la punta).
static func card(acc: Acc, mat: String, o: Vector3, ax: Vector3, aw: Vector3, uvr := Rect2(0, 0, 1, 1), col := Color(1, 1, 1, 1)) -> void:
	var q := acc.s(mat)
	var b := q.v.size()
	var nn := aw.cross(ax).normalized()
	var xf := acc.xf
	var nb := xf.basis.orthonormalized()
	var corners := [o - aw * 0.5, o + aw * 0.5, o + aw * 0.5 + ax, o - aw * 0.5 + ax]
	var uvs := [uvr.position, uvr.position + Vector2(uvr.size.x, 0), uvr.end, uvr.position + Vector2(0, uvr.size.y)]
	var tw := (nb * aw).normalized()
	for k in 4:
		q.v.append(xf * (corners[k] as Vector3))
		q.n.append((nb * nn).normalized())
		q.t.append_array(PackedFloat32Array([tw.x, tw.y, tw.z, 1.0]))
		q.c.append(col)
		q.uv.append(uvs[k])
		q.uv2.append(uvs[k])
	q.idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))


## Caja de los vértices de una malla (su superficie 0 y las demás), transformados por xf: [mín, máx].
static func bounds(mesh: Mesh, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var first := true
	for s in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			var w := xf * p
			if first:
				out = AABB(w, Vector3.ZERO)
				first = false
			else:
				out = out.expand(w)
	return out
