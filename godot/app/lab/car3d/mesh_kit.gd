## Mallas procedurales de la vista 3D del coche en marcha (nada descargado): un acumulador con varias superficies (una por
## material), el prisma de perfil con los cantos redondeados (la carrocería y la cabina: el contorno lateral extruido a lo
## ancho, con «tumblehome», la cabina más estrecha arriba), polígonos planos (lunas, pilotos), parches sobre la cara del
## morro, sólidos de revolución alrededor de z (ruedas), cajas y varillas. Todo en metros: x a lo largo del coche (desde la
## zaga), y hacia arriba, z hacia quien mira. Solo dibujo.
##
## Unidad 4k: los costados de la carrocería se teselan en una rejilla (tess > 0) y las franjas del contorno se dividen a lo
## ancho (strips), para que una abolladura hunda la malla de verdad (car_paint.gdshader la desplaza en el vértice); el
## canto puede tener un radio por punto (la cintura, más viva); y del costado se pueden recortar huecos (las ventanillas:
## se ve el interior a través de las lunas) sin polígonos con agujeros, que Godot no sabe triangular.
extends RefCounted

const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")


## Una superficie en construcción: vértices, normales, UV e índices (miembros: se amplían sin copiarse).
class Surf:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()


## Acumulador de una malla con varias superficies, una por id de material.
class Builder:
	extends RefCounted
	var surf := {}  # id → Surf

	func s(id: int) -> Surf:
		if not surf.has(id):
			surf[id] = Surf.new()
		return surf[id]

	func add(id: int, p: Vector3, nn: Vector3, t := Vector2.ZERO) -> int:
		var q := s(id)
		q.v.append(p)
		q.n.append(nn.normalized())
		q.uv.append(t)
		return q.v.size() - 1

	## Triángulo orientado según la media de sus normales (Godot: horario visto desde fuera).
	func tri(id: int, a: int, b: int, c: int) -> void:
		var q := s(id)
		var fn := (q.v[b] - q.v[a]).cross(q.v[c] - q.v[a])
		if fn.dot(q.n[a] + q.n[b] + q.n[c]) > 0.0:
			q.idx.append_array(PackedInt32Array([a, c, b]))
		else:
			q.idx.append_array(PackedInt32Array([a, b, c]))

	func quad(id: int, a: int, b: int, c: int, d: int) -> void:
		tri(id, a, b, c)
		tri(id, a, c, d)

	## Copia en la superficie id los triángulos de otra malla (su superficie 0), movidos off.
	func merge(id: int, m: Mesh, off := Vector3.ZERO) -> void:
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var tuv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var q := s(id)
		var base := q.v.size()
		for k in v.size():
			q.v.append(v[k] + off)
			q.n.append(nn[k])
			q.uv.append((tuv as PackedVector2Array)[k] if tuv != null else Vector2.ZERO)
		for k in ix.size():
			q.idx.append(base + ix[k])

	## Vértices y triángulos de todas las superficies (para las pruebas y las métricas).
	func triangles() -> int:
		var out := 0
		for id: int in surf:
			out += (surf[id] as Surf).idx.size() / 3
		return out

	## La malla, con una superficie por id (en orden creciente de id).
	## Escala todo lo construido (k por eje, alrededor del origen); las normales giran con la escala (unidad 4r: la
	## carrocería del deportivo, más baja y más ancha que la del turismo).
	func scale(k: Vector3) -> void:
		if k.is_equal_approx(Vector3.ONE):
			return
		var inv := Vector3(1.0 / k.x, 1.0 / k.y, 1.0 / k.z)
		for id: int in surf:
			var q: Surf = surf[id]
			for i in q.v.size():
				q.v[i] = q.v[i] * k
				q.n[i] = (q.n[i] * inv).normalized()

	func commit() -> ArrayMesh:
		var m := ArrayMesh.new()
		for id: int in ids():
			var q: Surf = surf[id]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = q.v
			arrays[Mesh.ARRAY_NORMAL] = q.n
			arrays[Mesh.ARRAY_TEX_UV] = q.uv
			arrays[Mesh.ARRAY_INDEX] = q.idx
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

	## Ids de las superficies de commit(), en su orden.
	func ids() -> Array:
		var out: Array = []
		var keys := surf.keys()
		keys.sort()
		for id: int in keys:
			if not (surf[id] as Surf).idx.is_empty():
				out.append(id)
		return out


## Sentido antihorario (con la y hacia arriba) de un contorno.
static func ccw(poly: PackedVector2Array) -> PackedVector2Array:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	if a >= 0.0:
		return poly
	var out := poly.duplicate()
	out.reverse()
	return out


## Normales hacia fuera de un contorno antihorario: [la de cada arista (i → i+1), el vector de inglete de cada vértice
## (su largo lleva el contorno a la distancia justa en las esquinas)].
static func normals(poly: PackedVector2Array) -> Array:
	var n := poly.size()
	var en := PackedVector2Array()
	for i in n:
		var d := poly[(i + 1) % n] - poly[i]
		en.append(Vector2(d.y, -d.x).normalized() if d.length() > 0.0 else Vector2.UP)
	var miter := PackedVector2Array()
	for i in n:
		var a := en[(i - 1 + n) % n]
		var b := en[i]
		var m := (a + b).normalized()
		if m == Vector2.ZERO:
			m = b
		var k := m.dot(b)
		miter.append(m / maxf(k, 0.4))
	return [en, miter]


## Sección de un prisma: su medio ancho hw(y) y su pendiente dhw(y) (la inclinación del costado) a cada altura. Lineal:
## de hw0 en y0 a hw1 en y1.
static func linear_section(hw0: float, hw1: float, y0: float, y1: float) -> Dictionary:
	var dy := y1 - y0
	var slope := (hw1 - hw0) / dy if absf(dy) > 1e-6 else 0.0
	return {
		"hw": func(y: float) -> float: return hw0 + (hw1 - hw0) * clampf((y - y0) / dy, 0.0, 1.0) if absf(dy) > 1e-6 else hw0,
		"dhw": func(_y: float) -> float: return slope,
	}


## Sección de la carrocería de un coche: el costado más ancho en la arista del hombro (y_s); por encima se inclina hacia
## dentro (tan_up por metro) y refleja el cielo; por debajo se recoge en curva hacia el faldón (curve·(y_s − y)²) y refleja
## el suelo. Entre las dos, la línea de horizonte que se ve en la chapa de un coche de verdad.
static func car_section(hw: float, y_s: float, tan_up: float, curve: float, _y0 := 0.0, _y1 := 0.0) -> Dictionary:
	return {
		"hw": func(yy: float) -> float: return hw - tan_up * (yy - y_s) if yy >= y_s else hw - curve * (y_s - yy) * (y_s - yy),
		"dhw": func(yy: float) -> float: return -tan_up if yy >= y_s else 2.0 * curve * (y_s - yy),
	}


## Radios del canto que caben en cada esquina de un contorno antihorario, para que el contorno de dentro no se cruce (un
## lazo, y un hueco en la malla):
##   - en una esquina convexa que gira θ entre tramos de largo l1 y l2, el contorno de dentro se acorta r·tan(θ/2) por
##     cada lado: como mucho 0,45·min(l1, l2)/tan(θ/2);
##   - hacia dentro, como mucho 0,45 veces lo que mide el perfil en esa dirección (encima del paso de rueda delantero la
##     chapa del costado solo tiene ~15 cm entre el paso y el capó).
## Luego se suaviza: ninguno pasa de 1,35 veces el de al lado.
static func safe_radii(poly: PackedVector2Array, radii: PackedFloat32Array) -> PackedFloat32Array:
	var n := poly.size()
	var out := radii.duplicate()
	var miter: PackedVector2Array = normals(poly)[1]
	for i in n:
		var d1 := poly[i] - poly[(i - 1 + n) % n]
		var d2 := poly[(i + 1) % n] - poly[i]
		var l1 := d1.length()
		var l2 := d2.length()
		if l1 > 1e-6 and l2 > 1e-6 and d1.cross(d2) > 0.0:
			var t := tan(acos(clampf(d1.dot(d2) / (l1 * l2), -1.0, 1.0)) * 0.5)
			if t > 1e-4:
				out[i] = minf(out[i], 0.45 * minf(l1, l2) / t)
		# una curva convexa cerrada repartida en varios tramos: el radio del círculo por i−k, i, i+k
		for k: int in [2, 4, 6]:
			var a := poly[(i - k + n) % n]
			var b := poly[i]
			var c := poly[(i + k) % n]
			var cr := (b - a).cross(c - b)
			if cr > 1e-9:
				var rho := (b - a).length() * (c - b).length() * (c - a).length() / (2.0 * absf((b - a).cross(c - a)))
				out[i] = minf(out[i], 0.8 * rho)
		var dir := -miter[i].normalized()
		var p := poly[i] + dir * 1e-4
		var far := p + dir * 3.0
		var best := INF
		for k in n:
			if k == i or (k + 1) % n == i:
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(p, far, poly[k], poly[(k + 1) % n])
			if hit != null:
				best = minf(best, p.distance_to(hit))
		if is_finite(best):
			out[i] = minf(out[i], 0.45 * best)
	for _pass in 8:
		for i in n:
			out[i] = minf(out[i], minf(out[(i - 1 + n) % n], out[(i + 1) % n]) * 1.35 + 0.001)
	# y, si aún se cruza cerca (una curva cerrada repartida en muchos tramos), se encoge el canto de ese trozo
	for _it in 16:
		var inner := PackedVector2Array()
		for i in n:
			inner.append(poly[i] - miter[i] * out[i])
		var bad := false
		for i in n:
			for dj in range(2, 18):
				var j := (i + dj) % n
				if (j + 1) % n == i:
					continue
				if Geometry2D.segment_intersects_segment(inner[i], inner[(i + 1) % n], inner[j], inner[(j + 1) % n]) != null:
					for k in range(i - 1, i + dj + 3):
						out[(k + n) % n] *= 0.85
					bad = true
					break
		if not bad:
			break
	return out


## El polígono sin los huecos, en trozos sin agujeros: se parte con una línea horizontal en y_cut (que tiene que cruzar
## todos los huecos) y a cada mitad se le recortan los huecos, que así quedan como muescas.
static func minus_holes(poly: PackedVector2Array, holes: Array, y_cut: float) -> Array:
	var lo := CurveKit.bounds_of(poly)
	var halves: Array = [
		PackedVector2Array([Vector2(lo.position.x - 1.0, lo.position.y - 1.0), Vector2(lo.end.x + 1.0, lo.position.y - 1.0),
			Vector2(lo.end.x + 1.0, y_cut), Vector2(lo.position.x - 1.0, y_cut)]),
		PackedVector2Array([Vector2(lo.position.x - 1.0, y_cut), Vector2(lo.end.x + 1.0, y_cut), Vector2(lo.end.x + 1.0, lo.end.y + 1.0),
			Vector2(lo.position.x - 1.0, lo.end.y + 1.0)]),
	]
	var out: Array = []
	for half: PackedVector2Array in halves:
		var parts: Array = Geometry2D.intersect_polygons(poly, half)
		for hole: PackedVector2Array in holes:
			var next: Array = []
			for part: PackedVector2Array in parts:
				for piece: PackedVector2Array in Geometry2D.clip_polygons(part, hole):
					if piece.size() >= 3:
						next.append(piece)
			parts = next
		out.append_array(parts)
	return out


## Anillo entre un polígono y el mismo crecido w (el marco de una luna), en trozos sin agujeros (partido en y_cut).
static func ring(poly: PackedVector2Array, w: float, y_cut: float) -> Array:
	var grown: Array = Geometry2D.offset_polygon(poly, w, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		return []
	return minus_holes(grown[0], [poly], y_cut)


## Triángulos de un polígono plano (en su plano, 2D): con tess > 0, una rejilla de ese paso (m) por dentro y el borde
## muestreado más fino (Delaunay, quitando lo que cae fuera); si no, el polígono tal cual. [puntos, índices].
## El borde va a 0,6·tess y la rejilla se queda a 0,45·tess de él: así cada tramo del borde es una arista de Gabriel (su
## círculo diametral no tiene otros puntos), está en la triangulación de Delaunay y la malla cubre el polígono sin huecos.
static func tessellate(poly: PackedVector2Array, tess: float) -> Array:
	var p := ccw(poly)
	if tess <= 0.0:
		return [p, Geometry2D.triangulate_polygon(p)]
	var pts := PackedVector2Array()
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		var n := maxi(1, ceili(a.distance_to(b) / (0.6 * tess)))
		for k in n:
			pts.append(a.lerp(b, float(k) / float(n)))
	var nb := pts.size()  # los del borde van primero
	var inset: Array = Geometry2D.offset_polygon(p, -0.45 * tess)
	var box := CurveKit.bounds_of(p)
	var y := box.position.y + tess * 0.5
	while y < box.end.y:
		var x := box.position.x + tess * 0.5
		while x < box.end.x:
			var q := Vector2(x, y)
			for ins: PackedVector2Array in inset:
				if Geometry2D.is_point_in_polygon(q, ins):
					pts.append(q)
					break
			x += tess
		y += tess
	var raw := Geometry2D.triangulate_delaunay(pts)
	var keep := PackedInt32Array()
	var long2 := (1.6 * tess) * (1.6 * tess)
	for k in range(0, raw.size(), 3):
		var a := pts[raw[k]]
		var b := pts[raw[k + 1]]
		var c := pts[raw[k + 2]]
		var g := (a + b + c) / 3.0
		if absf((b - a).cross(c - a)) < 1e-9 or not Geometry2D.is_point_in_polygon(g, p):
			continue
		# un triángulo de puntos de dentro con los lados cortos no puede cruzar el borde (los huecos del contorno, como los
		# pasos de rueda, son mucho mayores que la rejilla); los demás se miran por los puntos medios de sus lados
		var edge := raw[k] < nb or raw[k + 1] < nb or raw[k + 2] < nb
		if edge or maxf(maxf(a.distance_squared_to(b), b.distance_squared_to(c)), c.distance_squared_to(a)) > long2:
			var ok := true
			for m: Vector2 in [(a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5]:
				if not Geometry2D.is_point_in_polygon(m.lerp(g, 0.05), p):
					ok = false
					break
			if not ok:
				continue
		keep.append_array(PackedInt32Array([raw[k], raw[k + 1], raw[k + 2]]))
	return [pts, keep]


## Prisma de perfil con los cantos redondeados: el contorno lateral (outline, en XY) extruido a lo ancho según su sección
## (linear_section o car_section), con radio de canto r (un número o uno por punto) y seg tramos por canto. edge_mat: el
## material de la franja de cada arista (techo, lunas…); los costados y los cantos llevan side_mat. opts:
##   both: los dos costados (si no, solo el de +z) · tess: paso de la rejilla del costado (m; 0, sin rejilla) ·
##   strips: tramos de cada franja a lo ancho · holes: huecos del costado (polígonos en XY) · y_cut: la línea que los
##   cruza · back_mat: material de la cara de dentro de los huecos (el grosor de la chapa en el borde de la ventanilla).
static func prism(b: Builder, outline: PackedVector2Array, section: Dictionary, r: Variant, seg: int, edge_mat: PackedInt32Array,
		side_mat: int, opts := {}) -> void:
	var both: bool = opts.get("both", true)
	var tess: float = opts.get("tess", 0.0)
	var strips: int = maxi(1, int(opts.get("strips", 1)))
	var poly := ccw(outline)
	var flipped := poly != outline
	var n := poly.size()
	var mats := edge_mat.duplicate()
	var radii := PackedFloat32Array()
	if r is PackedFloat32Array:
		radii = (r as PackedFloat32Array).duplicate()
	else:
		radii.resize(n)
		radii.fill(float(r))
	if flipped:
		# al invertir el contorno, la arista i pasa a ser la n−2−i (la última sigue cerrando) y el punto i, el n−1−i
		if mats.size() == n:
			var m2 := PackedInt32Array()
			m2.resize(n)
			for i in n:
				m2[i] = edge_mat[(n - 2 - i + n) % n]
			mats = m2
		radii.reverse()
	radii = safe_radii(poly, radii)
	var nm: Array = normals(poly)
	var miter: PackedVector2Array = nm[1]
	var hw: Callable = section.hw
	var dhw: Callable = section.dhw
	var inner := PackedVector2Array()
	for i in n:
		inner.append(poly[i] - miter[i] * radii[i])
	# el costado: el contorno de dentro, sin los huecos, teselado
	var pieces: Array = [inner]
	var holes: Array = opts.get("holes", [])
	if not holes.is_empty():
		pieces = minus_holes(inner, holes, float(opts.get("y_cut", 0.0)))
	var sides := [1.0, -1.0] if both else [1.0]
	# la teselación de cada trozo, una vez para los dos costados (es la misma en el plano)
	var tessellated: Array = []
	for pc: PackedVector2Array in pieces:
		tessellated.append(tessellate(pc, tess))
	for side: float in sides:
		for t: Array in tessellated:
			var tp: PackedVector2Array = t[0]
			var tris: PackedInt32Array = t[1]
			if tris.is_empty():
				continue
			var base := -1
			for q in tp:
				var sl: float = dhw.call(q.y)
				var id := b.add(side_mat, Vector3(q.x, q.y, side * (hw.call(q.y) as float)), Vector3(0.0, -sl, side), Vector2(q.x, q.y))
				if base < 0:
					base = id
			for k in range(0, tris.size(), 3):
				b.tri(side_mat, base + tris[k], base + tris[k + 1], base + tris[k + 2])
		# canto redondeado: del costado a la franja
		var rings: Array = []
		for k in seg + 1:
			var th := PI * 0.5 * float(k) / float(seg)
			var ring_ids := PackedInt32Array()
			for i in n:
				var e := miter[i]
				var ri := radii[i]
				var xy := inner[i] + e * (ri * sin(th))
				var z := side * ((hw.call(xy.y) as float) - ri + ri * cos(th))
				var cap_n := Vector3(0.0, -(dhw.call(xy.y) as float), side).normalized()
				var nn := Vector3(e.normalized().x * sin(th), e.normalized().y * sin(th), 0.0) + cap_n * cos(th)
				ring_ids.append(b.add(side_mat, Vector3(xy.x, xy.y, z), nn, Vector2(xy.x, xy.y)))
			rings.append(ring_ids)
		for k in seg:
			var ra: PackedInt32Array = rings[k]
			var rb: PackedInt32Array = rings[k + 1]
			for i in n:
				var j := (i + 1) % n
				b.quad(side_mat, ra[i], ra[j], rb[j], rb[i])
	# franja del contorno (techo, capó, lunas, bajos…), de un costado al otro (o hasta z = 0), en strips tramos
	var en: PackedVector2Array = nm[0]
	for i in n:
		var j := (i + 1) % n
		var mat := mats[i] if i < mats.size() else side_mat
		var e0 := miter[i].normalized()
		var e1 := miter[j].normalized()
		var p0 := poly[i]
		var p1 := poly[j]
		var za0 := (hw.call(p0.y) as float) - radii[i]
		var za1 := (hw.call(p1.y) as float) - radii[j]
		var zb0 := -za0 if both else 0.0
		var zb1 := -za1 if both else 0.0
		# con materiales distintos a cada lado del vértice, la normal de la arista (arista viva: el cristal y la chapa)
		var prev_mat := mats[(i - 1 + n) % n] if mats.size() == n else mat
		var next_mat := mats[j] if mats.size() == n else mat
		var n0v := e0 if prev_mat == mat else en[i]
		var n1v := e1 if next_mat == mat else en[i]
		var col_a := PackedInt32Array()
		var col_b := PackedInt32Array()
		for k in strips + 1:
			var f := float(k) / float(strips)
			var z0 := lerpf(za0, zb0, f)
			var z1 := lerpf(za1, zb1, f)
			col_a.append(b.add(mat, Vector3(p0.x, p0.y, z0), Vector3(n0v.x, n0v.y, 0.0), Vector2(p0.x, z0)))
			col_b.append(b.add(mat, Vector3(p1.x, p1.y, z1), Vector3(n1v.x, n1v.y, 0.0), Vector2(p1.x, z1)))
		for k in strips:
			b.quad(mat, col_a[k], col_b[k], col_b[k + 1], col_a[k + 1])


## Polígono plano (lunas, pilotos, franjas) sobre la superficie z = z_of(y) (Callable) con normal nrm, desplazado lift
## hacia fuera. tess > 0: teselado en rejilla (para que siga una abolladura).
static func flat(b: Builder, mat: int, poly: PackedVector2Array, z_of: Callable, nrm: Vector3, lift := 0.004, tess := 0.0) -> void:
	var t: Array = tessellate(poly, tess)
	var p: PackedVector2Array = t[0]
	var tris: PackedInt32Array = t[1]
	if tris.is_empty():
		return
	var base := -1
	for q in p:
		var id := b.add(mat, Vector3(q.x, q.y, (z_of.call(q.y) as float)) + nrm.normalized() * lift, nrm, Vector2(q.x, q.y))
		if base < 0:
			base = id
	for k in range(0, tris.size(), 3):
		b.tri(mat, base + tris[k], base + tris[k + 1], base + tris[k + 2])


## Parche sobre una cara que va de lado a lado (el morro o la zaga): entre y0 e y1 y entre z0 y z1, apoyado en x = x_of(y)
## (Callable) y levantado lift hacia fuera (sgn: +1 el morro, −1 la zaga), en ny × nz tramos. UV: (z, y).
static func face_patch(b: Builder, mat: int, x_of: Callable, sgn: float, y0: float, y1: float, z0: float, z1: float, lift := 0.004,
		ny := 4, nz := 4) -> void:
	var grid: Array = []
	for i in ny + 1:
		var y := lerpf(y0, y1, float(i) / float(ny))
		var x: float = x_of.call(y)
		var dy := 0.004
		var dx: float = (x_of.call(y + dy) as float) - (x_of.call(y - dy) as float)
		var nrm := Vector3(sgn * 2.0 * dy, -sgn * dx, 0.0).normalized()
		if nrm.x * sgn < 0.0:
			nrm = -nrm
		var row := PackedInt32Array()
		for k in nz + 1:
			var z := lerpf(z0, z1, float(k) / float(nz))
			row.append(b.add(mat, Vector3(x, y, z) + nrm * lift, nrm, Vector2((z - z0) / maxf(z1 - z0, 1e-6), (y - y0) / maxf(y1 - y0, 1e-6))))
		grid.append(row)
	for i in ny:
		for k in nz:
			var ra: PackedInt32Array = grid[i]
			var rb: PackedInt32Array = grid[i + 1]
			b.quad(mat, ra[k], ra[k + 1], rb[k + 1], rb[k])


## Caja entre dos esquinas (a, b), con normales por cara.
static func box(b: Builder, mat: int, lo: Vector3, hi: Vector3) -> void:
	var faces := [
		[Vector3.RIGHT, [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]],
		[Vector3.LEFT, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3.UP, [Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)]],
		[Vector3.DOWN, [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
		[Vector3.BACK, [Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3.FORWARD, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z)]],
	]
	for f: Array in faces:
		var nn: Vector3 = f[0]
		var ids: Array = []
		for p: Vector3 in f[1]:
			ids.append(b.add(mat, p, nn, Vector2(p.x, p.y)))
		b.quad(mat, ids[0], ids[1], ids[2], ids[3])


## Caja girada: centro c, medios lados h y base (sus tres ejes). Para respaldos y cabezales inclinados.
static func obox(b: Builder, mat: int, c: Vector3, h: Vector3, basis: Basis) -> void:
	var ax := [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
	for axis in 3:
		for sgn: float in [1.0, -1.0]:
			var nn: Vector3 = ax[axis] * sgn
			var u: Vector3 = ax[(axis + 1) % 3] * h[(axis + 1) % 3]
			var v: Vector3 = ax[(axis + 2) % 3] * h[(axis + 2) % 3]
			var fc: Vector3 = c + nn * h[axis]
			var ids := [b.add(mat, fc - u - v, nn), b.add(mat, fc + u - v, nn), b.add(mat, fc + u + v, nn), b.add(mat, fc - u + v, nn)]
			b.quad(mat, ids[0], ids[1], ids[2], ids[3])


## Varilla (cilindro) de radio r entre a y c, con sides caras.
static func rod(b: Builder, mat: int, a: Vector3, c: Vector3, r: float, sides := 8) -> void:
	var ax := (c - a).normalized()
	var ref := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	var u := ax.cross(ref).normalized()
	var v := ax.cross(u)
	var ring_a: Array = []
	var ring_c: Array = []
	for k in sides + 1:
		var th := TAU * float(k) / float(sides)
		var nn := u * cos(th) + v * sin(th)
		ring_a.append(b.add(mat, a + nn * r, nn))
		ring_c.append(b.add(mat, c + nn * r, nn))
	for k in sides:
		b.quad(mat, ring_a[k], ring_a[k + 1], ring_c[k + 1], ring_c[k])


## Tubo de radio r por una polilínea 3D (limpiaparabrisas, brazo del retrovisor, volante).
static func tube(b: Builder, mat: int, pts: PackedVector3Array, r: float, sides := 6) -> void:
	for i in pts.size() - 1:
		rod(b, mat, pts[i], pts[i + 1], r, sides)


## Sólido de revolución alrededor del eje z: perfil (z, radio) → malla (una superficie) con UV (u = ángulo/TAU, v = tramo
## del perfil 0-1). smooth: normales suaves.
static func revolve_z(profile: PackedVector2Array, sides := 40, smooth := true) -> ArrayMesh:
	var b := Builder.new()
	var m := profile.size()
	var prof_n := PackedVector2Array()  # normal del perfil en (z, r)
	for i in m:
		var a := profile[maxi(i - 1, 0)]
		var c := profile[mini(i + 1, m - 1)]
		var t := (c - a).normalized()
		prof_n.append(Vector2(-t.y, t.x))
	var rows: Array = []
	for k in sides + 1:
		var th := TAU * float(k) / float(sides)
		var d := Vector3(cos(th), sin(th), 0.0)
		var row := PackedInt32Array()
		for i in m:
			var pz := profile[i].x
			var pr := profile[i].y
			var nn := d * prof_n[i].y + Vector3(0, 0, prof_n[i].x)
			if not smooth and i > 0:
				var e := (profile[i] - profile[i - 1]).normalized()
				nn = d * e.x - Vector3(0, 0, e.y)
			row.append(b.add(0, d * pr + Vector3(0, 0, pz), nn, Vector2(float(k) / float(sides), float(i) / float(maxi(m - 1, 1)))))
		rows.append(row)
	for k in sides:
		var ra: PackedInt32Array = rows[k]
		var rb: PackedInt32Array = rows[k + 1]
		for i in m - 1:
			b.quad(0, ra[i], rb[i], rb[i + 1], ra[i + 1])
	return b.commit()


## Disco plano en z (normal +z) de radio r: malla con UV polares (u = ángulo, v = radio relativo) para texturas radiales.
static func disc_z(r_in: float, r_out: float, z: float, sides := 48) -> ArrayMesh:
	var b := Builder.new()
	var ra: Array = []
	var rb: Array = []
	for k in sides + 1:
		var th := TAU * float(k) / float(sides)
		var d := Vector3(cos(th), sin(th), 0.0)
		ra.append(b.add(0, d * r_in + Vector3(0, 0, z), Vector3.BACK, Vector2(float(k) / float(sides), 0.0)))
		rb.append(b.add(0, d * r_out + Vector3(0, 0, z), Vector3.BACK, Vector2(float(k) / float(sides), 1.0)))
	for k in sides:
		b.quad(0, ra[k], ra[k + 1], rb[k + 1], rb[k])
	return b.commit()
