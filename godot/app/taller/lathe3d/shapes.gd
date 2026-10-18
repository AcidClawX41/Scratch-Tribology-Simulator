## Mallas procedurales para la máquina y las virutas (nada descargado): cajas con cantos redondeados, sólidos de
## revolución con aristas vivas, prismas extruidos y cintas helicoidales. Todo en metros.
##
## Cada triángulo se orienta solo a partir de la normal que se le pide (add_tri): así no hay que llevar la cuenta
## del sentido de giro (Godot toma como frontales los triángulos en sentido horario vistos desde fuera).
extends RefCounted


## Acumulador de una malla: vértices, normales, UV e índices.
class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func add(p: Vector3, nn: Vector3, t := Vector2.ZERO) -> int:
		v.append(p)
		n.append(nn.normalized())
		uv.append(t)
		return v.size() - 1

	## Triángulo orientado según la media de sus normales de vértice.
	func add_tri(a: int, b: int, c: int) -> void:
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		if fn.dot(n[a] + n[b] + n[c]) > 0.0:  # hacia fuera → al revés para Godot
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	func add_quad(a: int, b: int, c: int, d: int) -> void:
		add_tri(a, b, c)
		add_tri(a, c, d)

	func commit(mesh: ArrayMesh = null) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := mesh if mesh != null else ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## Caja de tamaño `size` centrada en el origen con los cantos redondeados (radio r, `seg` tramos por cuarto de
## canto). Los cantos con brillo son lo que hace que una fundición pintada no parezca un cubo de ordenador.
static func rounded_box(size: Vector3, r: float, seg := 3) -> ArrayMesh:
	var h := size * 0.5
	r = clampf(r, 0.0, minf(h.x, minf(h.y, h.z)) * 0.999)
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var b := Builder.new()
	var inner := h - Vector3(r, r, r)
	for f in faces:
		var nrm: Vector3 = f[0]
		var ua: Vector3 = f[1]
		var va: Vector3 = f[2]
		var us := _axis_coords(absf(ua.dot(h)), r, seg)
		var vs := _axis_coords(absf(va.dot(h)), r, seg)
		var base := b.v.size()
		for j in vs.size():
			for i in us.size():
				var p := nrm * absf(nrm.dot(h)) + ua * us[i] + va * vs[j]
				var q := p.clamp(-inner, inner)
				var d := p - q
				var nn := d.normalized() if d.length_squared() > 1e-18 else nrm
				b.add(q + nn * r if r > 0.0 else p, nn, Vector2(us[i], vs[j]))
		var w := us.size()
		for j in vs.size() - 1:
			for i in w - 1:
				var a := base + j * w + i
				b.add_quad(a, a + 1, a + w + 1, a + w)
	return b.commit()


## Coordenadas de la rejilla de una cara a lo largo de un eje de semilado hh: densas en los cantos para que, al
## proyectarlas sobre el cuarto de cilindro, queden igual repartidas en ángulo.
static func _axis_coords(hh: float, r: float, seg: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if r <= 0.0:
		out.append_array(PackedFloat64Array([-hh, hh]))
		return out
	for k in range(seg, 0, -1):
		out.append(-(hh - r + r * tan(PI / 4.0 * float(k) / float(seg))))
	out.append(-(hh - r))
	out.append(hh - r)
	for k in range(1, seg + 1):
		out.append(hh - r + r * tan(PI / 4.0 * float(k) / float(seg)))
	return out


## Sólido de revolución alrededor del eje X. `profile` son puntos (x, radio) en metros, recorridos con el material
## a la derecha (de izquierda a derecha por fuera; p. ej. empezando y acabando en el eje para un sólido cerrado).
## Cada tramo lleva su normal (aristas vivas, como una pieza torneada) salvo con smooth = true.
static func revolve(profile: PackedVector2Array, sides := 48, smooth := false, arc := TAU) -> ArrayMesh:
	var b := Builder.new()
	var cols := sides + 1
	var seg_n := PackedVector2Array()
	for i in profile.size() - 1:
		var d := profile[i + 1] - profile[i]
		seg_n.append(Vector2(-d.y, d.x).normalized() if d.length() > 0.0 else Vector2(0, 1))
	for i in profile.size() - 1:
		var n0 := seg_n[i]
		var n1 := seg_n[i]
		if smooth:
			if i > 0:
				n0 = (seg_n[i - 1] + seg_n[i]).normalized()
			if i < seg_n.size() - 1:
				n1 = (seg_n[i] + seg_n[i + 1]).normalized()
		var base := b.v.size()
		for end in 2:
			var p := profile[i + end]
			var nn := n0 if end == 0 else n1
			for j in cols:
				var th := arc * float(j) / float(sides)
				var c := cos(th)
				var s := sin(th)
				b.add(Vector3(p.x, p.y * c, p.y * s), Vector3(nn.x, nn.y * c, nn.y * s), Vector2(float(j) / float(sides), float(i)))
		for j in sides:
			var a := base + j
			var d2 := base + cols + j
			if profile[i].y <= 0.0 and profile[i + 1].y <= 0.0:
				continue
			b.add_quad(a, a + 1, d2 + 1, d2)
	return b.commit()


## Prisma recto: polígono convexo `poly` en el plano horizontal (x, z), de y = 0 a y = height.
static func prism(poly: PackedVector2Array, height: float) -> ArrayMesh:
	var b := Builder.new()
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	for cap in 2:
		var y := height if cap == 1 else 0.0
		var nrm := Vector3.UP if cap == 1 else Vector3.DOWN
		var ci := b.add(Vector3(c.x, y, c.y), nrm)
		var first := b.v.size()
		for p in poly:
			b.add(Vector3(p.x, y, p.y), nrm, p)
		for i in poly.size():
			b.add_tri(ci, first + i, first + (i + 1) % poly.size())
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var mid := (p0 + p1) * 0.5 - c
		var e := p1 - p0
		var side := Vector2(e.y, -e.x).normalized()
		if side.dot(mid) < 0.0:
			side = -side
		var nrm := Vector3(side.x, 0.0, side.y)
		var a := b.add(Vector3(p0.x, 0.0, p0.y), nrm)
		var bb := b.add(Vector3(p1.x, 0.0, p1.y), nrm)
		var cc := b.add(Vector3(p1.x, height, p1.y), nrm)
		var d := b.add(Vector3(p0.x, height, p0.y), nrm)
		b.add_quad(a, bb, cc, d)
	return b.commit()


## Cinta helicoidal alrededor del eje Y (la viruta): radio inicial r0 que se cierra hasta r1, `turns` vueltas con
## paso `pitch` por vuelta, ancho `width` a lo largo del eje. Se dibuja por las dos caras (material sin culling).
static func helix_ribbon(r0: float, r1: float, pitch: float, turns: float, width: float, segs: int) -> ArrayMesh:
	var b := Builder.new()
	var total := turns * TAU
	for i in segs + 1:
		var t := float(i) / float(segs)
		var phi := total * t
		var r := lerpf(r0, r1, t)
		var y := pitch * turns * t - pitch * turns * 0.5
		var radial := Vector3(cos(phi), 0.0, sin(phi))
		var w := width * (0.55 + 0.45 * sin(PI * t))  # los extremos de la viruta se estrechan
		b.add(radial * r + Vector3(0.0, y - w * 0.5, 0.0), radial, Vector2(t, 0.0))
		b.add(radial * r + Vector3(0.0, y + w * 0.5, 0.0), radial, Vector2(t, 1.0))
	for i in segs:
		var a := i * 2
		b.add_quad(a, a + 2, a + 3, a + 1)
	return b.commit()


## Viruta con grosor: cinta helicoidal alrededor del eje Y de sección rectangular (ancho × espesor), con las
## cuatro caras (exterior, interior y los dos cantos) para que no desaparezca al verla de canto.
static func chip_curl(r0: float, r1: float, pitch: float, turns: float, width: float, thickness: float, segs: int) -> ArrayMesh:
	var b := Builder.new()
	var total := turns * TAU
	var faces := [[1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0]]  # normal (radial, y): fuera, dentro, arriba, abajo
	for fi in faces.size():
		var f: Array = faces[fi]
		var base := b.v.size()
		for i in segs + 1:
			var t := float(i) / float(segs)
			var phi := total * t
			var r := lerpf(r0, r1, t)
			var y := pitch * turns * (t - 0.5)
			var radial := Vector3(cos(phi), 0.0, sin(phi))
			var w := width * (0.6 + 0.4 * sin(PI * t))  # los extremos se estrechan
			var th := thickness * (0.7 + 0.3 * sin(PI * t))
			var ro := r
			var ri := r - th
			var nrm := radial * float(f[0]) + Vector3(0.0, float(f[1]), 0.0)
			var pa: Vector3
			var pb: Vector3
			match fi:
				0:
					pa = radial * ro + Vector3(0.0, y - w * 0.5, 0.0)
					pb = radial * ro + Vector3(0.0, y + w * 0.5, 0.0)
				1:
					pa = radial * ri + Vector3(0.0, y - w * 0.5, 0.0)
					pb = radial * ri + Vector3(0.0, y + w * 0.5, 0.0)
				2:
					pa = radial * ri + Vector3(0.0, y + w * 0.5, 0.0)
					pb = radial * ro + Vector3(0.0, y + w * 0.5, 0.0)
				_:
					pa = radial * ri + Vector3(0.0, y - w * 0.5, 0.0)
					pb = radial * ro + Vector3(0.0, y - w * 0.5, 0.0)
			b.add(pa, nrm, Vector2(t, 0.0))
			b.add(pb, nrm, Vector2(t, 1.0))
		for i in segs:
			var a := base + i * 2
			b.add_quad(a, a + 2, a + 3, a + 1)
	return b.commit()


## Cilindro a lo largo del eje X (de x0 a x1) con radio r: atajo de revolve con tapas planas.
static func x_cylinder(x0: float, x1: float, r: float, sides := 32) -> ArrayMesh:
	return revolve(PackedVector2Array([Vector2(x0, 0.0), Vector2(x0, r), Vector2(x1, r), Vector2(x1, 0.0)]), sides)


## Prisma a lo largo del eje X (guías de la bancada, perfiles): sección convexa `section` en el plano (z, y),
## extruida de x0 a x1.
static func extrude_x(section: PackedVector2Array, x0: float, x1: float) -> ArrayMesh:
	var b := Builder.new()
	var c := Vector2.ZERO
	for p in section:
		c += p
	c /= float(section.size())
	for cap in 2:
		var x := x1 if cap == 1 else x0
		var nrm := Vector3.RIGHT if cap == 1 else Vector3.LEFT
		var ci := b.add(Vector3(x, c.y, c.x), nrm)
		var first := b.v.size()
		for p in section:
			b.add(Vector3(x, p.y, p.x), nrm)
		for i in section.size():
			b.add_tri(ci, first + i, first + (i + 1) % section.size())
	for i in section.size():
		var p0 := section[i]
		var p1 := section[(i + 1) % section.size()]
		var mid := (p0 + p1) * 0.5 - c
		var e := p1 - p0
		var side := Vector2(e.y, -e.x).normalized()
		if side.dot(mid) < 0.0:
			side = -side
		var nrm := Vector3(0.0, side.y, side.x)
		var a := b.add(Vector3(x0, p0.y, p0.x), nrm, Vector2(x0, float(i)))
		var bb := b.add(Vector3(x0, p1.y, p1.x), nrm, Vector2(x0, float(i + 1)))
		var cc := b.add(Vector3(x1, p1.y, p1.x), nrm, Vector2(x1, float(i + 1)))
		var d := b.add(Vector3(x1, p0.y, p0.x), nrm, Vector2(x1, float(i)))
		b.add_quad(a, bb, cc, d)
	return b.commit()


## Caja con cantos redondeados entre dos esquinas: {"mesh": ArrayMesh centrada en el origen, "center": Vector3}.
static func box_between(a: Vector3, b: Vector3, r := 0.0, seg := 2) -> Dictionary:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return {"mesh": rounded_box(hi - lo, r, seg), "center": (lo + hi) * 0.5}


## Volante (de carro, de charriot o de contrapunto) con su eje a lo largo de X: llanta (toro), cubo, un radio
## (para girarlo 3 veces) y maneta. Mallas por separado para darles materiales distintos.
static func handwheel(radius: float, tube: float) -> Dictionary:
	var rim := TorusMesh.new()
	rim.inner_radius = radius - tube
	rim.outer_radius = radius + tube
	rim.rings = 40
	rim.ring_segments = 10
	return {
		"rim": rim,  # TorusMesh: su eje es Y; quien lo coloque lo gira para dejarlo en X
		"hub": revolve(PackedVector2Array([Vector2(-tube * 2.0, 0.0), Vector2(-tube * 2.0, tube * 2.2), Vector2(tube * 2.0, tube * 2.2), Vector2(tube * 2.0, 0.0)]), 16),
		"spoke": revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, tube * 0.7), Vector2(radius, tube * 0.7), Vector2(radius, 0.0)]), 8),
		"handle": revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, tube * 0.8), Vector2(radius * 0.45, tube * 0.9), Vector2(radius * 0.5, tube * 1.3), Vector2(radius * 0.62, tube * 1.3), Vector2(radius * 0.65, 0.0)]), 12, true),
	}
