## Kit de dibujo vectorial para la vista del coche en marcha (animales y coche): SVG escrito en código y rasterizado con
## ThorVG (Image.load_svg_from_string, como app/common/svg_texture.gd). Solo dibujo: nada de física.
##
## - Coordenadas del dibujo: unidades propias (cm en los animales, m en el coche) con la y hacia ARRIBA y el origen en los
##   pies (o en el suelo). El SVG que sale lleva la y hacia abajo: cada número se invierte al escribirlo.
## - Trayectos suaves: Catmull-Rom convertido a Bézier cúbicas (smooth_d) y la misma curva muestreada (smooth_points) para
##   la caja de lo dibujado, las pruebas y las superficies donde se apoya algo.
## - Una pieza (Part) junta sus definiciones (degradados, recortes, desenfoques) y sus elementos, y sabe qué ocupa
##   (outline) para rasterizarse en una textura del tamaño justo (raster).
## - ThorVG: un trazo abierto sin fill="none" no se pinta (se usa siempre stroke()); los degradados van en
##   userSpaceOnUse (ThorVG calcula mal la caja de un trayecto con curvas); el desenfoque (feGaussianBlur) sí funciona.
## Uso: const Kit = preload("res://app/lab/animals/svg_kit.gd"); var p := Kit.Part.new("cuerpo"); p.fill(d, color)…
extends RefCounted

const SvgTexture = preload("res://app/common/svg_texture.gd")
## Una pieza del dibujo (una textura): svg_part.gd.
const Part = preload("res://app/lab/animals/svg_part.gd")

## Tramos con que se muestrea cada Bézier para la caja y las superficies.
const STEPS := 10


## Número para el SVG (datos del dibujo, no un número visible): dos decimales.
static func n(v: float) -> String:
	return String.num(snappedf(v, 0.01))


## Punto del dibujo (y hacia arriba) en el SVG (y hacia abajo).
static func pt(p: Vector2) -> String:
	return n(p.x) + " " + n(-p.y)


## Color como atributos: fill="#rrggbb" y, si es translúcido, fill-opacity (o stroke con what = "stroke").
static func paint(c: Color, what := "fill") -> String:
	var s := "%s=\"#%s\"" % [what, c.to_html(false)]
	if c.a < 0.999:
		s += " %s-opacity=\"%s\"" % [what, n(c.a)]
	return s


# ════════ Trayectos ════════

## Puntos de control de la Bézier cúbica del tramo i → i+1 de un Catmull-Rom (uniforme, k = tensión). En una esquina
## (corners) la tangente es nula: el trazo llega y sale en punta.
static func _ctrl(pts: PackedVector2Array, i: int, closed: bool, corners: PackedInt32Array, k: float) -> Array:
	var m := pts.size()
	var p1 := pts[i]
	var p2 := pts[(i + 1) % m]
	var p0: Vector2
	var p3: Vector2
	if closed:
		p0 = pts[(i - 1 + m) % m]
		p3 = pts[(i + 2) % m]
	else:
		p0 = pts[i - 1] if i > 0 else p1
		p3 = pts[i + 2] if i + 2 < m else p2
	var c1 := p1 if corners.has(i) else p1 + (p2 - p0) * (k / 6.0)
	var c2 := p2 if corners.has((i + 1) % m) else p2 - (p3 - p1) * (k / 6.0)
	return [p1, c1, c2, p2]


## Trayecto SVG suave por los puntos (Catmull-Rom). closed: cerrado; corners: índices de los puntos en punta.
static func smooth_d(pts: PackedVector2Array, closed := true, corners := PackedInt32Array(), k := 1.0) -> String:
	var m := pts.size()
	if m < 2:
		return ""
	var out := PackedStringArray(["M" + pt(pts[0])])
	var segs := m if closed else m - 1
	for i in segs:
		var c: Array = _ctrl(pts, i, closed, corners, k)
		out.append("C%s %s %s" % [pt(c[1]), pt(c[2]), pt(c[3])])
	if closed:
		out.append("Z")
	return " ".join(out)


## La misma curva de smooth_d, muestreada (STEPS tramos por Bézier): para la caja y para apoyar cosas en ella.
static func smooth_points(pts: PackedVector2Array, closed := true, corners := PackedInt32Array(), k := 1.0, steps := STEPS) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	if m == 0:
		return out
	out.append(pts[0])
	var segs := m if closed else m - 1
	for i in segs:
		var c: Array = _ctrl(pts, i, closed, corners, k)
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			out.append((c[0] as Vector2).bezier_interpolate(c[1], c[2], c[3], t))
	return out


## Trayecto de segmentos rectos.
static func poly_d(pts: PackedVector2Array, closed := true) -> String:
	var out := PackedStringArray()
	for i in pts.size():
		out.append(("M" if i == 0 else "L") + pt(pts[i]))
	if closed:
		out.append("Z")
	return " ".join(out)


## Puntos de una elipse de centro c, semiejes rx y ry, girada rot (rad, antihoraria con la y hacia arriba).
static func ellipse_pts(c: Vector2, rx: float, ry: float, rot := 0.0, count := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		out.append(c + Vector2(rx * cos(a), ry * sin(a)).rotated(rot))
	return out


## Trayecto de una elipse (suave, por 8 puntos: prácticamente exacta).
static func ellipse_d(c: Vector2, rx: float, ry: float, rot := 0.0) -> String:
	return smooth_d(ellipse_pts(c, rx, ry, rot, 8), true, PackedInt32Array(), 1.1)


## Huso afilado de a a b (una raya, una pluma, un dedo): ancho w en el centro, curvado bend (fracción del largo, hacia la
## izquierda de a → b) y con las puntas en punta. Devuelve los puntos de control (para smooth_d con corners [0, 3]).
static func spindle(a: Vector2, b: Vector2, w: float, bend := 0.0, bias := 0.5) -> PackedVector2Array:
	var d := b - a
	var l := d.length()
	if l <= 0.0:
		return PackedVector2Array([a, a, a, a])
	var t := d / l
	var nrm := Vector2(-t.y, t.x)
	var mid := a + d * bias + nrm * (bend * l)
	return PackedVector2Array([a, mid + nrm * (w * 0.5), b, mid - nrm * (w * 0.5)])


## Trayecto de un huso (spindle).
static func spindle_d(a: Vector2, b: Vector2, w: float, bend := 0.0, bias := 0.5) -> String:
	return smooth_d(spindle(a, b, w, bend, bias), true, PackedInt32Array([0, 2]))


## Caja (Rect2, y hacia arriba) de unos puntos.
static func bounds_of(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


## Y de la curva (muestreada) en x: la más alta si la corta varias veces (la superficie de arriba). NAN si no la corta.
static func top_y(curve: PackedVector2Array, x: float) -> float:
	var best := NAN
	for i in curve.size() - 1:
		var a := curve[i]
		var b := curve[i + 1]
		if (x < minf(a.x, b.x)) or (x > maxf(a.x, b.x)) or a.x == b.x:
			continue
		var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		if is_nan(best) or y > best:
			best = y
	return best


# ════════ Pinturas ════════

## Paradas de un degradado: [[desplazamiento 0-1, Color], …].
static func _stops(stops: Array) -> String:
	var out := PackedStringArray()
	for s: Array in stops:
		var c: Color = s[1]
		var op := " stop-opacity=\"%s\"" % n(c.a) if c.a < 0.999 else ""
		out.append("<stop offset=\"%s\" stop-color=\"#%s\"%s/>" % [n(float(s[0])), c.to_html(false), op])
	return "".join(out)


## Degradado lineal de a a b (coordenadas del dibujo, en userSpaceOnUse).
static func lin_def(id: String, a: Vector2, b: Vector2, stops: Array) -> String:
	return "<linearGradient id=\"%s\" x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" gradientUnits=\"userSpaceOnUse\">%s</linearGradient>" % [
		id, n(a.x), n(-a.y), n(b.x), n(-b.y), _stops(stops)]


## Degradado radial de centro c y radio r, con el foco en f (por defecto, el centro).
static func rad_def(id: String, c: Vector2, r: float, stops: Array, f: Variant = null) -> String:
	var ff: Vector2 = f if f is Vector2 else c
	return "<radialGradient id=\"%s\" cx=\"%s\" cy=\"%s\" r=\"%s\" fx=\"%s\" fy=\"%s\" gradientUnits=\"userSpaceOnUse\">%s</radialGradient>" % [
		id, n(c.x), n(-c.y), n(r), n(ff.x), n(-ff.y), _stops(stops)]


# ════════ Pieza ════════

## Rasteriza una pieza: { tex: Texture2D (null si ThorVG no la entiende), rect: Rect2 en px lógicos (y hacia abajo, origen
## del dibujo) }. cache: un SvgTexture (caché LRU por texto y escala) o null.
static func raster(part: Part, s: float, rs := 1.0, cache: SvgTexture = null) -> Dictionary:
	var out: Array = part.svg(s, rs)
	var tex: Texture2D = cache.texture(out[0], 1.0) if cache != null else SvgTexture.rasterize(out[0], 1.0)
	return { "tex": tex, "rect": out[1] }
