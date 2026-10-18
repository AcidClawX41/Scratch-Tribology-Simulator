## Cetrería · la reacción del animal (unidad 5t-B): la geometría del mapa de daños de la lente de la cámara. Solo dibujo.
##
## Convierte el daño de la lente (los rayones con su trazo en coordenadas normalizadas de la pantalla, las grietas y las
## manchas) en una malla 2D cuyos colores son datos; lens_layer.gd la pinta con mezcla aditiva en un SubViewport y el
## sombreador de la lente (lens.gdshader) lee ese mapa. El mapa tiene tres partes del ancho de la vista, una al lado de otra:
##   A (0 → W):   R el surco (lo hondo), G el borde levantado (blanquecino) o astillado y el polvo, B las líneas de grieta;
##   B (W → 2W):  R la grasa de las manchas, G lo lechoso (grieta, desgarro), B la veladura de alrededor de los rayones;
##   C (2W → 3W): RGB, el color de lo que se queda pegado (metal transferido, grasa, polvo), premultiplicado.
## Cada rayón es más ancho en el centro y afilado en los extremos (sin(π·s)^0,7), con el borde a los lados; el desgarro, más
## ancho y desigual; la grieta, una estrella de rayos quebrados con trozos de arco y la zona lechosa del impacto; la mancha,
## la huella de las almohadillas con sus crestas, o el polvo en motas.
## Puras (solo arrays) y deterministas: el azar de rng.gd con la semilla de cada daño.
## Unidades: el trazo, normalizado (0-1, y hacia abajo); los anchos, en píxeles de una vista de REF_W de ancho.
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")


## La malla que se va llenando (los Packed*Array guardados en un diccionario se copian al leerlos: aquí son miembros).
class G:
	extends RefCounted
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

## Ancho de la vista de referencia de los anchos en píxeles (los de una vista de escritorio).
const REF_W := 1280.0
## La veladura de alrededor de un rayón: su ancho (veces el del surco, más un margen en px de REF_W).
const HAZE_K := 6.0
const HAZE_PAD_PX := 10.0
## El borde levantado: hasta dónde llega a cada lado (veces el medio ancho del surco).
const LIP_K := 2.3


## La malla del mapa (arrays de una superficie 2D) para un mapa de tres partes de w×h píxeles cada una. damage: el de
## lens_layer.gd ({ scratches, cracks, smudges }); live: rayones que se están dibujando ahora (los mismos campos).
static func build(damage: Dictionary, live: Array, w: float, h: float) -> Array:
	var g := G.new()
	var k := w / REF_W
	for sm: Dictionary in damage.get("smudges", []):
		_smudge(g, sm, w, h, k)
	for cr: Dictionary in damage.get("cracks", []):
		_crack(g, cr, w, h, k)
	for sc: Dictionary in damage.get("scratches", []):
		_scratch(g, sc, w, h, k)
	for sc: Dictionary in live:
		_scratch(g, sc, w, h, k)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = g.v
	a[Mesh.ARRAY_COLOR] = g.c
	a[Mesh.ARRAY_INDEX] = g.i
	return a


static func has_triangles(a: Array) -> bool:
	return a.size() == Mesh.ARRAY_MAX and a[Mesh.ARRAY_INDEX] is PackedInt32Array and (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >= 3


# ─────────────────────────────── primitivas ───────────────────────────────

static func _vert(g: G, p: Vector2, c: Color) -> int:
	g.v.append(p)
	g.c.append(c)
	return g.v.size() - 1


static func _tri(g: G, a: int, b: int, c: int) -> void:
	g.i.append_array([a, b, c])


## Una tira a lo largo de pts (px) con sus anchos (px, el total) y una sección de varios vértices de través: offs (fracciones
## del medio ancho, de −1 a 1) con su color cada uno (cols). shift: lo que se mueve la tira entera (a la parte B o C del mapa).
static func _strip(g: G, pts: PackedVector2Array, widths: PackedFloat32Array, offs: Array, cols: Array, shift := Vector2.ZERO) -> void:
	var n := pts.size()
	if n < 2:
		return
	var m := offs.size()
	var base := g.v.size()
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		t = t.normalized() if t.length_squared() > 1e-12 else Vector2.RIGHT
		var nrm := Vector2(-t.y, t.x)
		var hw := widths[i] * 0.5
		for j in m:
			_vert(g, pts[i] + nrm * (hw * float(offs[j])) + shift, cols[j])
	for i in n - 1:
		for j in m - 1:
			var a := base + i * m + j
			var b := base + (i + 1) * m + j
			_tri(g, a, b, a + 1)
			_tri(g, a + 1, b, b + 1)


## Un abanico (mancha, zona lechosa): el centro con su color y un borde de n puntos a radios r(θ) con el suyo.
static func _fan(g: G, c: Vector2, radii: PackedFloat32Array, center_col: Color, rim_col: Color, rot := 0.0, squash := 1.0) -> void:
	var n := radii.size()
	if n < 3:
		return
	var ci := _vert(g, c, center_col)
	var first := g.v.size()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		_vert(g, c + Vector2(cos(a), sin(a) * squash) * radii[i], rim_col)
	for i in n:
		_tri(g, ci, first + i, first + (i + 1) % n)


## Un punto (mota) de lado s px.
static func _dot(g: G, p: Vector2, s: float, col: Color) -> void:
	var a := _vert(g, p + Vector2(-s, 0.0), Color(0, 0, 0))
	var b := _vert(g, p + Vector2(0.0, -s), Color(0, 0, 0))
	var c := _vert(g, p + Vector2(s, 0.0), Color(0, 0, 0))
	var d := _vert(g, p + Vector2(0.0, s), Color(0, 0, 0))
	var m := _vert(g, p, col)
	_tri(g, m, a, b)
	_tri(g, m, b, c)
	_tri(g, m, c, d)
	_tri(g, m, d, a)


# ─────────────────────────────── el rayón ───────────────────────────────

## El trazo de un rayón en px del mapa A, remuestreado a pasos de ~step px y hasta progress (0-1) de su largo.
static func stroke_px(points: Array, w: float, h: float, progress := 1.0, step := 3.0) -> PackedVector2Array:
	var raw := PackedVector2Array()
	for p: Variant in points:
		var q := _v2(p)
		raw.append(Vector2(q.x * w, q.y * h))
	if raw.size() < 2:
		return raw
	var total := 0.0
	for i in range(1, raw.size()):
		total += raw[i].distance_to(raw[i - 1])
	var stop := total * clampf(progress, 0.0, 1.0)
	var out := PackedVector2Array([raw[0]])
	var acc := 0.0
	var next := step
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var b := raw[i]
		var seg := a.distance_to(b)
		while next <= acc + seg and next <= stop:
			out.append(a.lerp(b, (next - acc) / maxf(seg, 1e-6)))
			next += step
		acc += seg
		if acc >= stop:
			break
	var end_p := raw[raw.size() - 1] if progress >= 1.0 else out[out.size() - 1]
	if out[out.size() - 1].distance_to(end_p) > 0.25:
		out.append(end_p)
	return out


static func _v2(p: Variant) -> Vector2:
	if p is Vector2:
		return p
	if p is Array and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	if p is Dictionary:
		return Vector2(float((p as Dictionary).get("x", 0.0)), float((p as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


## Un rayón: { points, w_px, depth (0-1), edge (0-1), chips (bool: borde astillado, el vidrio), tear (bool: desgarro),
## deposit (Color o null: lo transferido), progress (0-1), seed }.
static func _scratch(g: G, sc: Dictionary, w: float, h: float, k: float) -> void:
	var pts := stroke_px(sc.get("points", []), w, h, float(sc.get("progress", 1.0)))
	var n := pts.size()
	if n < 2:
		return
	var rng := Rng.new(int(sc.get("seed", 1)))
	var tear := bool(sc.get("tear", false))
	var wmax := maxf(float(sc.get("w_px", 2.0)) * k, 0.8)
	var depth := clampf(float(sc.get("depth", 0.5)), 0.0, 1.0)
	var edge := clampf(float(sc.get("edge", 0.3)), 0.0, 1.0)
	var chips := bool(sc.get("chips", false))
	# el ancho a lo largo: afilado en los extremos y más ancho en el centro; el desgarro, desigual y romo donde se clavó
	var total := 0.0
	var cum := PackedFloat32Array([0.0])
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
		cum.append(total)
	var full := float(sc.get("length_px", 0.0)) * k
	var span := maxf(full, total) if full > 0.0 else total
	var widths := PackedFloat32Array()
	var lips := PackedFloat32Array()
	var haze := PackedFloat32Array()
	for i in n:
		var s := cum[i] / maxf(span, 1e-6)
		var taper := pow(maxf(sin(PI * clampf(s, 0.0, 1.0)), 0.0), 0.7)
		if tear:
			taper = clampf(1.6 * pow(maxf(sin(PI * clampf(s * 0.8 + 0.2, 0.0, 1.0)), 0.0), 0.45), 0.0, 1.0) * (0.75 + 0.5 * rng.next())
		var wi := wmax * (0.1 + 0.9 * taper)
		widths.append(wi)
		lips.append(wi * LIP_K)
		haze.append(wi * HAZE_K + HAZE_PAD_PX * k)
	# el surco (R) con el borde a los lados (G); en el vidrio el borde va en esquirlas (abajo), no en labio
	var lip_g := 0.0 if chips else edge
	var offs := [-1.0, -1.0 / LIP_K, 0.0, 1.0 / LIP_K, 1.0]
	var cols := [Color(0, 0, 0), Color(0, lip_g, 0), Color(depth, 0, 0), Color(0, lip_g, 0), Color(0, 0, 0)]
	_strip(g, pts, lips, offs, cols)
	# la veladura de alrededor (B del mapa B) y, en el desgarro, lo lechoso del plástico rasgado (G del mapa B)
	var hz := clampf(0.35 + 0.65 * depth, 0.0, 1.0)
	_strip(g, pts, haze, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(0, 0.55 if tear else 0.0, hz), Color(0, 0, 0)], Vector2(w, 0.0))
	# lo transferido (el metal de la garra que se queda pegado): un trazo fino de su color en el mapa C
	var dep: Variant = sc.get("deposit")
	if dep is Color:
		var dc := dep as Color
		var a := clampf(dc.a, 0.0, 1.0)
		_strip(g, pts, widths, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(dc.r * a, dc.g * a, dc.b * a), Color(0, 0, 0)], Vector2(w * 2.0, 0.0))
	# las esquirlas del borde (vidrio): triángulos pequeños a los dos lados, cada 1,5-4 anchos
	if chips:
		var at := 0.0
		while at < total:
			at += wmax * (1.5 + 2.5 * rng.next())
			var p := _point_at(pts, cum, at)
			if p.is_empty():
				break
			var c: Vector2 = p[0]
			var t: Vector2 = p[1]
			var nrm := Vector2(-t.y, t.x) * (1.0 if rng.next() < 0.5 else -1.0)
			var wl := wmax * (0.5 + 0.5 * sin(PI * clampf(at / maxf(span, 1e-6), 0.0, 1.0)))
			var root := c + nrm * wl * 0.5
			var len := wmax * (0.8 + 2.2 * rng.next())
			var half := wmax * (0.4 + 0.8 * rng.next())
			var i0 := _vert(g, root - t * half, Color(0, edge, 0))
			var i1 := _vert(g, root + t * half, Color(0, edge, 0))
			var i2 := _vert(g, root + nrm * len + t * (rng.next() - 0.5) * half, Color(0, 0, 0))
			_tri(g, i0, i1, i2)
	# el polvo del material levantado junto a los rayones hondos
	var specks := int(depth * edge * total / maxf(wmax * 1.5, 2.0))
	for j in mini(specks, 80):
		var p := _point_at(pts, cum, rng.next() * total)
		if p.is_empty():
			continue
		var c: Vector2 = p[0]
		var t: Vector2 = p[1]
		var off := Vector2(-t.y, t.x) * (rng.next() - 0.5) * wmax * LIP_K * 2.4
		_dot(g, c + off, (0.5 + 0.9 * rng.next()) * maxf(k, 0.5), Color(0, 0.4 + 0.4 * rng.next(), 0))


## El punto y la tangente a la distancia at (px) a lo largo de pts; [] fuera.
static func _point_at(pts: PackedVector2Array, cum: PackedFloat32Array, at: float) -> Array:
	if at < 0.0 or at > cum[cum.size() - 1]:
		return []
	for i in range(1, pts.size()):
		if cum[i] >= at:
			var seg := cum[i] - cum[i - 1]
			var f := (at - cum[i - 1]) / maxf(seg, 1e-6)
			var t := (pts[i] - pts[i - 1]).normalized()
			return [pts[i - 1].lerp(pts[i], f), t]
	return []


# ─────────────────────────────── la grieta ───────────────────────────────

## Una grieta en estrella: { at (normalizado), radius (fracción del ancho), rays (n), seed }: rayos quebrados desde el impacto
## con alguna rama, trozos de arco alrededor y la zona lechosa del centro. La grieta no crece sola: su forma la fija la semilla.
static func _crack(g: G, cr: Dictionary, w: float, h: float, k: float) -> void:
	var rng := Rng.new(int(cr.get("seed", 7)))
	var c := _v2(cr.get("at", Vector2(0.5, 0.5)))
	var center := Vector2(c.x * w, c.y * h)
	var r := clampf(float(cr.get("radius", 0.18)), 0.03, 0.6) * w
	var rays := clampi(int(cr.get("rays", 7)), 3, 14)
	var lw := maxf(2.2 * k, 1.1)
	var a0 := rng.next() * TAU
	for i in rays:
		var ang := a0 + TAU * (float(i) + (rng.next() - 0.5) * 0.6) / float(rays)
		var len := r * (0.45 + 0.55 * rng.next())
		var pts := _jagged(center, ang, len, 6 + int(rng.next() * 4.0), rng)
		_crack_line(g, pts, lw, rng)
		# una rama a veces
		if rng.next() < 0.45 and pts.size() > 3:
			var j := 1 + int(rng.next() * float(pts.size() - 2))
			var bang := ang + (0.5 + 0.5 * rng.next()) * (1.0 if rng.next() < 0.5 else -1.0)
			_crack_line(g, _jagged(pts[j], bang, len * (0.25 + 0.3 * rng.next()), 4, rng), lw * 0.8, rng)
	# trozos de arco (las grietas concéntricas del vidrio que flexa)
	for j in 2 + int(rng.next() * 3.0):
		var rr := r * (0.22 + 0.4 * rng.next())
		var from := rng.next() * TAU
		var arc := (0.25 + 0.5 * rng.next())
		var pts := PackedVector2Array()
		for q in 7:
			var a := from + arc * float(q) / 6.0
			pts.append(center + Vector2(cos(a), sin(a)) * rr * (1.0 + (rng.next() - 0.5) * 0.08))
		_crack_line(g, pts, lw * 0.75, rng)
	# la zona lechosa del impacto (G del mapa B) y el polvo de vidrio (G del mapa A)
	var radii := PackedFloat32Array()
	for q in 18:
		radii.append(r * (0.16 + 0.1 * rng.next()))
	_fan(g, center + Vector2(w, 0.0), radii, Color(0, 1.0, 0.35), Color(0, 0, 0))
	for q in 40:
		var a := rng.next() * TAU
		_dot(g, center + Vector2(cos(a), sin(a)) * r * 0.3 * sqrt(rng.next()), (0.6 + rng.next()) * maxf(k, 0.5), Color(0, 0.7, 0))


## Una línea quebrada desde p en la dirección ang, de largo len, en n tramos.
static func _jagged(p: Vector2, ang: float, len: float, n: int, rng: Rng) -> PackedVector2Array:
	var pts := PackedVector2Array([p])
	var a := ang
	var q := p
	for i in n:
		a += (rng.next() - 0.5) * 0.5
		q += Vector2(cos(a), sin(a)) * len / float(n)
		pts.append(q)
	return pts


## La línea de una grieta: el trazo (B del mapa A), con su lado brillante (G) a un píxel.
static func _crack_line(g: G, pts: PackedVector2Array, lw: float, rng: Rng) -> void:
	var widths := PackedFloat32Array()
	var n := pts.size()
	for i in n:
		widths.append(lw * (1.0 - 0.7 * float(i) / float(maxi(n - 1, 1))) * (0.8 + 0.4 * rng.next()))
	_strip(g, pts, widths, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(0, 0, 0.95), Color(0, 0, 0)])
	_strip(g, pts, widths, [-0.2, 0.9, 2.0], [Color(0, 0, 0), Color(0, 0.45, 0), Color(0, 0, 0)])


# ─────────────────────────────── la mancha ───────────────────────────────

## Una mancha: { at (normalizado), size (fracción del ancho), kind: «grasa» | «polvo», pads: [[dx, dy, r], …] (las
## almohadillas, en fracciones de size; vacío: una), seed }. Solo en R del mapa B: es lo único que limpia el paño.
static func _smudge(g: G, sm: Dictionary, w: float, h: float, k: float) -> void:
	var rng := Rng.new(int(sm.get("seed", 3)))
	var c := _v2(sm.get("at", Vector2(0.5, 0.5)))
	var size := clampf(float(sm.get("size", 0.05)), 0.005, 0.4) * w
	var pads: Array = sm.get("pads", [])
	if pads.is_empty():
		pads = [[0.0, 0.0, 1.0]]
	var dust := String(sm.get("kind", "grasa")) == "polvo"
	var shift := Vector2(w, 0.0)
	if String(sm.get("kind", "")) == "metal":
		# la garra de metal que resbala sin rayar deja un trazo de su color (points, normalizados; color)
		var pts := stroke_px(sm.get("points", []), w, h)
		if pts.size() >= 2:
			var col: Color = sm.get("color", Color(0.45, 0.47, 0.5, 0.55))
			var widths := PackedFloat32Array()
			for i in pts.size():
				widths.append(maxf(2.2 * k, 1.0) * (0.4 + 0.6 * sin(PI * float(i) / float(pts.size() - 1))))
			var a := clampf(col.a, 0.0, 1.0)
			_strip(g, pts, widths, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(col.r * a, col.g * a, col.b * a), Color(0, 0, 0)], Vector2(w * 2.0, 0.0))
			_strip(g, pts, widths, [-1.6, 0.0, 1.6], [Color(0, 0, 0), Color(0.22, 0, 0), Color(0, 0, 0)], shift)
		return
	# la grasa de la almohadilla que arrastra: un rastro a lo largo de su trazo (que se vea dónde pasó la garra sin rayar)
	if not dust and (sm.get("points", []) as Array).size() >= 2:
		var tp := stroke_px(sm.get("points", []), w, h)
		if tp.size() >= 2:
			var tw := PackedFloat32Array()
			for i in tp.size():
				tw.append(size * 0.22 * (0.55 + 0.45 * sin(PI * float(i) / float(tp.size() - 1))))
			_strip(g, tp, tw, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(0.62, 0, 0), Color(0, 0, 0)], shift)
	for pd: Array in pads:
		var pc := Vector2(c.x * w, c.y * h) + Vector2(float(pd[0]), float(pd[1])) * size
		var pr := float(pd[2]) * size * 0.5
		if dust:
			# motas de polvo (las claras, por encima de 0,8 en el sombreador) sobre un velo muy tenue
			var veil := PackedFloat32Array()
			for q in 16:
				veil.append(pr * (0.9 + 0.2 * rng.next()))
			_fan(g, pc + shift, veil, Color(0.18, 0, 0), Color(0, 0, 0))
			for q in int(18.0 + 30.0 * float(pd[2])):
				var a := rng.next() * TAU
				var p := pc + Vector2(cos(a), sin(a)) * pr * sqrt(rng.next())
				_dot(g, p + shift, (0.5 + 1.1 * rng.next()) * maxf(k, 0.5), Color(0.75 + 0.25 * rng.next(), 0, 0))
			continue
		var radii := PackedFloat32Array()
		var lobes := 2.0 + floorf(rng.next() * 3.0)
		var ph := rng.next() * TAU
		for q in 24:
			var a := TAU * float(q) / 24.0
			radii.append(pr * (0.85 + 0.15 * sin(a * lobes + ph) + 0.08 * (rng.next() - 0.5)))
		var rot := rng.next() * TAU
		# la grasa (R del mapa B)
		_fan(g, pc + shift, radii, Color(0.55, 0, 0), Color(0, 0, 0), rot, 0.8)
		# las crestas de la piel de la almohadilla (arcos más marcados dentro de la mancha)
		for q in 4:
			var rr := pr * (0.25 + 0.17 * float(q))
			var pts := PackedVector2Array()
			var from := rot + rng.next() * 0.6
			for s in 9:
				var a := from + 2.2 * float(s) / 8.0
				pts.append(pc + Vector2(cos(a), sin(a) * 0.8) * rr)
			var widths := PackedFloat32Array()
			widths.resize(pts.size())
			widths.fill(maxf(1.2 * k, 0.8))
			_strip(g, pts, widths, [-1.0, 0.0, 1.0], [Color(0, 0, 0), Color(0.18, 0, 0), Color(0, 0, 0)], shift)
