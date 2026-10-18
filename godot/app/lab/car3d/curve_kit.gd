## Curvas del dibujo del coche en marcha (solo dibujo): el Catmull-Rom muestreado con que se suaviza la silueta, la y de la
## parte de arriba en una x y la caja de unos puntos. Es el mismo algoritmo de animals/svg_kit.gd (smooth_points, top_y y
## bounds_of), copiado aquí para que car3d/ no dependa de los dibujos de los animales (que son de otra unidad): la silueta,
## y con ella surface_y() de la vista, no cambia ni un punto.
extends RefCounted

## Tramos con que se muestrea cada Bézier.
const STEPS := 10


## Puntos de control de la Bézier cúbica del tramo i → i+1 de un Catmull-Rom abierto (uniforme, tensión 1).
static func _ctrl(pts: PackedVector2Array, i: int) -> Array:
	var m := pts.size()
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p0 := pts[i - 1] if i > 0 else p1
	var p3 := pts[i + 2] if i + 2 < m else p2
	return [p1, p1 + (p2 - p0) / 6.0, p2 - (p3 - p1) / 6.0, p2]


## Curva suave abierta por los puntos (Catmull-Rom convertido a Bézier y muestreado con steps tramos por Bézier).
static func smooth(pts: PackedVector2Array, steps := STEPS) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	if m == 0:
		return out
	out.append(pts[0])
	for i in m - 1:
		var c: Array = _ctrl(pts, i)
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			out.append((c[0] as Vector2).bezier_interpolate(c[1], c[2], c[3], t))
	return out


## Caja de unos puntos.
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


## Punto de la polilínea a la distancia s de su principio (m), y su largo total con total().
static func at_length(line: PackedVector2Array, s: float) -> Vector2:
	var left := maxf(s, 0.0)
	for i in line.size() - 1:
		var d := line[i].distance_to(line[i + 1])
		if left <= d and d > 0.0:
			return line[i].lerp(line[i + 1], left / d)
		left -= d
	return line[line.size() - 1] if not line.is_empty() else Vector2.ZERO


## Largo de una polilínea (m).
static func total(line: PackedVector2Array) -> float:
	var out := 0.0
	for i in line.size() - 1:
		out += line[i].distance_to(line[i + 1])
	return out
