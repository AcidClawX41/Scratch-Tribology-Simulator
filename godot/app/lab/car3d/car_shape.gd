## La silueta del turismo del coche en marcha (solo dibujo: la física no la usa): una berlina media de ~4,5 m, como el
## DrivAer de las medidas de túnel (docs/fisica/coche-en-marcha.md §9.6: 2,786 m de batalla y ~1,42 m de alto; aquí
## 2,745 m y 1,395 m hasta el techo), en metros con x desde la zaga hacia el morro, y desde el suelo y z hacia quien
## mira (el costado derecho del coche). La comparten la vista (moving_car_view.gd: dónde se apoya el animal, los paneles
## del golpe) y el modelo 3D (car_model.gd), para que el dibujo y lo que se calcula encima coincidan.
##
## Pasa por los puntos draw de MovingCar.ZONES (x desde el morro y alto sobre el suelo, 0-1 de CAR_L y CAR_H): capó
## (0,14; 0,58), limpiaparabrisas (0,30; 0,64), parabrisas (0,36; 0,76), techo (0,55; 0,96), barras (0,55; 1,0), antena
## (0,72; 1,0), retrovisor (0,33; 0,70), borde de la ventanilla (0,50; 0,78), maletero (0,88; 0,70) y aleta (0,12; 0,52);
## tests/app/test_car3d.gd lo comprueba. La parte de arriba (TOP, con la que la vista apoya el animal: surface_y) y los
## paneles del golpe (PANELS de la vista) no se mueven: los detalles de la unidad 4k (juntas, tapa del depósito, frontal,
## pilares, lunas de verdad, interior) se añaden sin cambiar la silueta.
## La cabina (lunas, techo) es más estrecha que la carrocería y se estrecha hacia arriba («tumblehome»).
extends RefCounted

const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const MeshKit = preload("res://app/lab/car3d/mesh_kit.gd")

const CAR_L := 4.5
const CAR_H := 1.45
const WHEEL_R := 0.31
const WHEEL_X := [0.99, 3.735]
## Radio del paso de rueda.
const ARCH_R := 0.37
## Medio ancho de la carrocería (el DrivAer mide ~1,8 m de ancho) y de la cabina en la cintura y en el techo.
const HALF_W := 0.9
const CABIN_HW_BELT := 0.78
const CABIN_HW_ROOF := 0.64
## Radios de los cantos redondeados: el general, el de la cintura (la chapa se dobla hacia la luna con un radio pequeño,
## como en una berlina de ahora) y el de la cabina.
const BODY_R := 0.13
const BELT_R := 0.045
const CABIN_R := 0.07
## Sección de la carrocería: el costado es más ancho en la arista del hombro (SHOULDER_Y); por encima se inclina hacia
## dentro (SHOULDER_TAN m por m: ~12°) y por debajo se recoge en curva hacia el faldón (SILL_CURVE·Δy²: ~5 cm).
const SHOULDER_Y := 0.84
const SHOULDER_TAN := 0.21
const SILL_CURVE := 0.18

## Parte de arriba, de la parte baja del morro, por encima, hasta la zaga (los puntos de siempre del dibujo).
const TOP := [
	Vector2(4.500, 0.435), Vector2(4.487, 0.580), Vector2(4.455, 0.680), Vector2(4.390, 0.755), Vector2(4.230, 0.800),
	Vector2(3.870, 0.848), Vector2(3.510, 0.887), Vector2(3.195, 0.921), Vector2(3.150, 0.928), Vector2(2.520, 1.378),
	Vector2(2.340, 1.392), Vector2(2.025, 1.395), Vector2(1.710, 1.385), Vector2(1.440, 1.356), Vector2(0.990, 1.204),
	Vector2(0.630, 1.066), Vector2(0.450, 1.037), Vector2(0.225, 1.015), Vector2(0.113, 1.000), Vector2(0.045, 0.928),
	Vector2(0.000, 0.812), Vector2(0.000, 0.551), Vector2(0.036, 0.435), Vector2(0.113, 0.377), Vector2(0.180, 0.290),
]
## Tramos de la parte de arriba (índices de TOP): morro y capó, parabrisas, techo, luneta, maletero y zaga.
const NOSE := [0, 8]
const WINDSHIELD_SEG := [8, 9]
const ROOF_SEG := [9, 13]
const REAR_WINDOW_SEG := [13, 15]
const TAIL_SEG := [15, 24]
## Línea de cintura: donde la cabina (lunas) se apoya en la carrocería, del pie del parabrisas al de la luneta.
const BELT := [Vector2(3.150, 0.928), Vector2(3.060, 0.957), Vector2(2.700, 0.964), Vector2(2.200, 0.970), Vector2(1.600, 0.976),
	Vector2(1.200, 0.984), Vector2(0.950, 1.012), Vector2(0.760, 1.043), Vector2(0.630, 1.066)]
## Lunas laterales (delantera y trasera, con el pilar B entre las dos): se calculan del costado de la cabina
## (side_windows), dejando el pilar A y el marco del techo (PILLAR_W más el canto), el pilar B entre B_X.x y B_X.y y el C
## por detrás de la recta C_LINE, por encima de la cintura (BELT_GAP: la goma). FRAME_W: el marco que las rodea (m).
const PILLAR_W := 0.035
const B_X := Vector2(2.195, 2.265)
const C_LINE := [Vector2(1.12, 0.98), Vector2(1.40, 1.30)]
const BELT_GAP := 0.012
const FRAME_W := 0.022
## Retrovisor: la carcasa en el perfil (x, y) y de dónde a dónde sale del costado (z).
const MIRROR := [Vector2(3.020, 1.000), Vector2(3.150, 1.020), Vector2(3.140, 1.085), Vector2(3.030, 1.075)]
const MIRROR_Z := Vector2(0.885, 1.085)
const HEADLIGHT := [Vector2(4.465, 0.700), Vector2(4.405, 0.748), Vector2(4.205, 0.778), Vector2(4.170, 0.760), Vector2(4.300, 0.718),
	Vector2(4.425, 0.668)]
const TAILLIGHT := [Vector2(0.020, 0.905), Vector2(0.215, 0.935), Vector2(0.225, 0.875), Vector2(0.012, 0.842)]
## Juntas de las puertas (x, de abajo a la cintura) y tiradores ([x0, x1, y]). 3,10 y 1,36 son los bordes de la puerta
## del golpe (PANELS.puerta de la vista) y 3,10, el de la aleta.
const SEAMS_X := [3.10, 2.20, 1.36]
const HANDLES := [[2.36, 2.49, 0.875], [1.48, 1.61, 0.875]]
## El cupé de dos puertas (unidad 4r: el deportivo; dibujo): una puerta larga, de la aleta delantera a 1,80 m de la zaga, y
## su tirador atrás, junto a la ventanilla de detrás.
const COUPE_SEAMS_X := [3.10, 1.80]
const COUPE_HANDLES := [[1.90, 2.03, 0.875]]
## Juntas de arriba: el capó (de la base del parabrisas a su borde delantero) y la tapa del maletero, a HOOD_Z del eje.
const HOOD_X := Vector2(3.13, 4.40)
const TRUNK_X := Vector2(0.10, 0.99)
const LID_Z := 0.78
## Tapa del depósito (en el costado derecho, sobre la rueda de atrás): centro (x, y) y radio (m).
const FUEL_FLAP := Vector3(0.74, 0.86, 0.082)
## Barras del techo (dos largueros a ±BAR_Z) y antena (donde se agarran las aves: la zona «antena» está en su punta).
const BAR_X := [1.55, 2.55]
const BAR_FEET := [1.62, 2.48]
const BAR_Y := 1.44
const BAR_Z := 0.50
const ANTENNA := [Vector2(1.33, 1.30), Vector2(1.26, 1.45)]
## Frontal (en la cara del morro, de y0 a y1 y hasta z de medio ancho): calandra, toma de aire baja, matrícula en blanco
## (520 × 110 mm, la europea) y la parte de delante de los faros. Zaga: los pilotos de la tapa del maletero.
const GRILLE := Rect2(0.0, 0.50, 0.42, 0.14)
const INTAKE := Rect2(0.0, 0.305, 0.56, 0.05)
const PLATE := Rect2(0.0, 0.385, 0.26, 0.11)
const HEAD_FRONT := Rect2(0.44, 0.662, 0.42, 0.09)
const FOG := Rect2(0.62, 0.37, 0.16, 0.045)
const TAIL_BACK := Rect2(0.36, 0.842, 0.52, 0.085)
## Neumático y llanta (m): 225/45 R17, la medida de una berlina media (radio de 0,31 m con la llanta de 17").
const TIRE_W := 0.225
const RIM_R := 0.216
const WHEEL_Z := HALF_W - 0.13
## Asientos (interior, apenas insinuados detrás de las lunas): delanteros y banqueta trasera ([x del respaldo, z]).
const SEATS := [[2.18, 0.37], [2.18, -0.37], [1.22, 0.37], [1.22, -0.37]]
## Dónde está cada zona de MovingCar.ZONES en z (m): arriba, en el eje del coche; en un costado, en su cara (y lo que
## sobresale el retrovisor). Solo dibujo: para poner el animal y las marcas del golpe en su sitio en 3D.
const ZONE_Z := { "capo": 0.0, "limpiaparabrisas": 0.25, "parabrisas": 0.0, "techo": 0.0, "barras": BAR_Z, "antena": 0.0,
	"retrovisor": 0.98, "ventanilla": HALF_W, "maletero": 0.0, "aleta": HALF_W, "puerta": HALF_W, "luneta": 0.0 }
## El golpe en la puerta: MovingCar.IMPACT_ZONES no tiene dibujo; el centro de la puerta delantera en esta silueta.
const DOOR_DRAW := Vector2(0.48, 0.42)
## Dónde empieza y acaba cada panel del golpe en esta silueta (m, x desde la zaga). Las marcas de un golpe no pasan de su
## panel (el dibujo es más corto que el panel de MovingCar en el techo: slide_m 1,6 m frente a 1,08 m). La ventanilla («luna»,
## unidad 4m): la delantera (side_windows()[0]), del pilar B (B_X) a su esquina de delante, en la cintura.
const PANELS := { "capo": Vector2(3.15, 4.40), "techo": Vector2(1.44, 2.52), "parabrisas": Vector2(2.52, 3.15),
	"puerta": Vector2(1.36, 3.10), "aleta": Vector2(3.10, 4.30), "maletero": Vector2(0.10, 1.00), "luna": Vector2(2.27, 2.90) }
## Chapa lisa donde un animal asustado desgarra la pintura quieto encima (docs/fisica/coche-en-marcha.md §12.2: capó,
## techo y maletero; la aleta, como el capó): los desgarros miden todo el panel (defense.tear.lengthMm = slide_m).
const TEAR_ZONES := ["capo", "techo", "maletero", "aleta"]


## La parte de arriba (top_curve) de una carrocería escalada (shape: por eje, la del deportivo de la unidad 4r: x largo, y
## alto, z ancho); la del turismo con Vector3.ONE.
static func scaled_top(shape: Vector3) -> PackedVector2Array:
	var out := top_curve()
	if shape.is_equal_approx(Vector3.ONE):
		return out
	for i in out.size():
		out[i] = Vector2(out[i].x * shape.x, out[i].y * shape.y)
	return out


## Puntos de un tramo de TOP (de i0 a i1, ambos incluidos).
static func top_seg(seg: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(int(seg[0]), int(seg[1]) + 1):
		out.append(TOP[i])
	return out


## Una curva suave por los puntos (Catmull-Rom muestreado), abierta.
static func smooth(pts: PackedVector2Array, steps := 6) -> PackedVector2Array:
	return CurveKit.smooth(pts, steps)


## Añade una curva a otra sin repetir el punto de unión.
static func _join(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var out := a.duplicate()
	for i in b.size():
		if i == 0 and not out.is_empty() and out[out.size() - 1].distance_to(b[0]) < 1e-5:
			continue
		out.append(b[i])
	return out


## Paso de rueda: semicírculo de radio ARCH_R alrededor de la rueda cx, de delante a atrás (de x mayor a menor) o al revés.
static func _arch(cx: float, forward: bool, steps := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps + 1:
		var a := PI * float(k) / float(steps) if forward else PI - PI * float(k) / float(steps)
		out.append(Vector2(cx + ARCH_R * cos(a), WHEEL_R + ARCH_R * sin(a)))
	return out


## Alto (m) de lo de arriba del paso de rueda en x (0 fuera de los pasos): por encima de él empieza la chapa del costado.
static func arch_top(x: float) -> float:
	var out := 0.0
	for cx: float in WHEEL_X:
		var dx := x - cx
		if absf(dx) < ARCH_R:
			out = maxf(out, WHEEL_R + sqrt(ARCH_R * ARCH_R - dx * dx))
	return out


## Los bajos, de la zaga al morro, con los dos pasos de rueda.
static func underside() -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(0.180, 0.290), Vector2(0.560, 0.300)])
	out = _join(out, _arch(float(WHEEL_X[0]), false))
	out = _join(out, PackedVector2Array([Vector2(1.410, 0.255), Vector2(3.315, 0.255)]))
	out = _join(out, _arch(float(WHEEL_X[1]), false))
	out = _join(out, PackedVector2Array([Vector2(4.300, 0.290), Vector2(4.460, 0.330), Vector2(4.500, 0.435)]))
	return out


## Contorno de la carrocería (sin la cabina): morro y capó, cintura, maletero y zaga, y bajos. [puntos, tramo de cada
## arista (0 chapa · 1 bajos · 3 cintura, la parte de arriba de la carrocería bajo las lunas), radio del canto de cada
## punto].
static func body_outline() -> Array:
	var nose := smooth(top_seg(NOSE))
	var belt := smooth(PackedVector2Array(BELT))
	var tail := smooth(top_seg(TAIL_SEG))
	var pts := nose.duplicate()
	var mats := PackedInt32Array()
	for i in nose.size() - 1:
		mats.append(0)
	var n0 := pts.size()
	pts = _join(pts, belt)
	for i in range(n0 - 1, pts.size() - 1):
		mats.append(3)
	n0 = pts.size()
	pts = _join(pts, tail)
	for i in range(n0 - 1, pts.size() - 1):
		mats.append(0)
	pts = _join(pts, underside())
	# el último punto (el morro) cierra con el primero: se quita si coincide
	if pts[pts.size() - 1].distance_to(pts[0]) < 1e-5:
		pts.remove_at(pts.size() - 1)
	while mats.size() < pts.size():
		mats.append(1)
	# el canto: pequeño a lo largo de la cintura (donde la chapa se dobla hacia la luna), el general en el resto, con una
	# transición suave de ~15 cm en cada extremo
	var radii := PackedFloat32Array()
	var b0: Vector2 = BELT[0]
	var b1: Vector2 = BELT[BELT.size() - 1]
	for p in pts:
		var inside := p.x <= b0.x and p.x >= b1.x and p.y >= 0.9
		var d := minf(absf(p.x - b0.x), absf(p.x - b1.x)) if inside else 0.0
		radii.append(lerpf(BODY_R, BELT_R, clampf(d / 0.15, 0.0, 1.0)) if inside else BODY_R)
	return [pts, mats, radii]


## Contorno de la cabina: parabrisas (luna), techo (chapa), luneta (luna) y la cintura por debajo (metida en la
## carrocería). [puntos, tramo de cada arista: 0 chapa · 2 luna · 3 cintura, radio del canto de cada punto: CABIN_R arriba y
## CABIN_BELT_R en la cintura, que va dentro de la carrocería y no se ve].
const CABIN_BELT_R := 0.01
static func cabin_outline() -> Array:
	var ws := smooth(top_seg(WINDSHIELD_SEG), 3)
	var roof := smooth(top_seg(ROOF_SEG))
	var rear := smooth(top_seg(REAR_WINDOW_SEG))
	var belt := PackedVector2Array()
	for i in range(BELT.size() - 1, -1, -1):
		belt.append((BELT[i] as Vector2) + Vector2(0.0, -0.035))
	var pts := ws.duplicate()
	var mats := PackedInt32Array()
	for i in ws.size() - 1:
		mats.append(2)
	var n0 := pts.size()
	pts = _join(pts, roof)
	for i in range(n0 - 1, pts.size() - 1):
		mats.append(0)
	n0 = pts.size()
	pts = _join(pts, rear)
	for i in range(n0 - 1, pts.size() - 1):
		mats.append(2)
	var n_up := pts.size()
	pts = _join(pts, smooth(belt))
	while mats.size() < pts.size():
		mats.append(3)
	var radii := PackedFloat32Array()
	for i in pts.size():
		radii.append(CABIN_R if i < n_up - 1 and i > 0 else CABIN_BELT_R)
	return [pts, mats, radii]


## La parte de arriba entera (morro, capó, parabrisas, techo, luneta, maletero y zaga), suave: la superficie en el eje del
## coche sobre la que se apoya el animal y resbalan las marcas.
static func top_curve() -> PackedVector2Array:
	var pts := smooth(top_seg(NOSE))
	pts = _join(pts, smooth(top_seg(WINDSHIELD_SEG), 3))
	pts = _join(pts, smooth(top_seg(ROOF_SEG)))
	pts = _join(pts, smooth(top_seg(REAR_WINDOW_SEG)))
	pts = _join(pts, smooth(top_seg(TAIL_SEG)))
	return pts


## Las dos ventanillas (lunas laterales) en el perfil (XY, m): [delantera, trasera]. El costado de la cabina hasta abajo,
## encogido lo que ocupan su canto y los pilares, por encima de la cintura, partido por el pilar B y cortado por el C.
static func side_windows() -> Array:
	var ws := smooth(top_seg(WINDSHIELD_SEG), 3)
	var roof := smooth(top_seg(ROOF_SEG))
	var rear := smooth(top_seg(REAR_WINDOW_SEG))
	var up := _join(_join(ws, roof), rear)
	# cerrado muy abajo: el encogido no toca la parte de abajo, que corta la cintura
	up.append(Vector2(up[up.size() - 1].x, 0.0))
	up.append(Vector2(up[0].x, 0.0))
	var shrunk: Array = Geometry2D.offset_polygon(MeshKit.ccw(up), -(CABIN_R + PILLAR_W), Geometry2D.JOIN_MITER)
	if shrunk.is_empty():
		return [PackedVector2Array(), PackedVector2Array()]
	# por encima de la cintura (y de su goma)
	var above := PackedVector2Array()
	for p: Vector2 in BELT:
		above.append(p + Vector2(0.0, BELT_GAP))
	above.append(Vector2((BELT[BELT.size() - 1] as Vector2).x - 1.0, (BELT[BELT.size() - 1] as Vector2).y + BELT_GAP))
	above.append(Vector2((BELT[BELT.size() - 1] as Vector2).x - 1.0, 3.0))
	above.append(Vector2((BELT[0] as Vector2).x + 1.0, 3.0))
	above.append(Vector2((BELT[0] as Vector2).x + 1.0, (BELT[0] as Vector2).y + BELT_GAP))
	var dlo: Array = Geometry2D.intersect_polygons(shrunk[0], MeshKit.ccw(above))
	if dlo.is_empty():
		return [PackedVector2Array(), PackedVector2Array()]
	var front_box := PackedVector2Array([Vector2(B_X.y, 0.0), Vector2(5.0, 0.0), Vector2(5.0, 3.0), Vector2(B_X.y, 3.0)])
	# la trasera: por delante de la recta del pilar C (entre y = 0,8 y 1,5 m) y por detrás del pilar B
	var c0: Vector2 = C_LINE[0]
	var c1: Vector2 = C_LINE[1]
	var c_at := func(y: float) -> float: return c0.x + (y - c0.y) / (c1.y - c0.y) * (c1.x - c0.x)
	var rear_box := PackedVector2Array([Vector2(c_at.call(0.8), 0.8), Vector2(B_X.x, 0.8), Vector2(B_X.x, 1.5), Vector2(c_at.call(1.5), 1.5)])
	var out: Array = []
	for box: PackedVector2Array in [front_box, rear_box]:
		var parts: Array = Geometry2D.intersect_polygons(dlo[0], MeshKit.ccw(box))
		var best := PackedVector2Array()
		for part: PackedVector2Array in parts:
			if part.size() > best.size():
				best = part
		out.append(MeshKit.ccw(best))
	return out


## Medio ancho de la cabina a la altura y (m).
static func cabin_hw(y: float) -> float:
	return lerpf(CABIN_HW_BELT, CABIN_HW_ROOF, clampf((y - 0.95) / (1.395 - 0.95), 0.0, 1.0))


## Medio ancho de la carrocería a la altura y (m): dónde está su costado.
static func body_hw(y: float) -> float:
	if y >= SHOULDER_Y:
		return HALF_W - SHOULDER_TAN * (y - SHOULDER_Y)
	return HALF_W - SILL_CURVE * (SHOULDER_Y - y) * (SHOULDER_Y - y)


## Normal del costado de la carrocería a la altura y (hacia +z): inclinada hacia arriba sobre el hombro y hacia abajo bajo él.
static func body_normal(y: float) -> Vector3:
	var slope := -SHOULDER_TAN if y >= SHOULDER_Y else 2.0 * SILL_CURVE * (SHOULDER_Y - y)
	return Vector3(0.0, -slope, 1.0).normalized()


## Sección del prisma de la carrocería (mesh_kit.gd).
static func body_section() -> Dictionary:
	return MeshKit.car_section(HALF_W, SHOULDER_Y, SHOULDER_TAN, SILL_CURVE, 0.2, 1.1)


## x de la cara del morro a la altura y (m): la curva de delante (de la parte baja del morro a la arista del capó) y, por
## debajo, la del paragolpes hacia los bajos. Para apoyar en ella la calandra, la matrícula y los faros.
static func nose_x(y: float) -> float:
	var best := -INF
	var line := smooth(top_seg([0, 4]))
	line = _join(PackedVector2Array([Vector2(4.300, 0.290), Vector2(4.460, 0.330)]), line)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if y < minf(a.y, b.y) or y > maxf(a.y, b.y) or a.y == b.y:
			continue
		best = maxf(best, lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
	return best if is_finite(best) else CAR_L


## x de la cara de la zaga a la altura y (m).
static func tail_x(y: float) -> float:
	var best := INF
	var line := smooth(top_seg([17, 24]))
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if y < minf(a.y, b.y) or y > maxf(a.y, b.y) or a.y == b.y:
			continue
		best = minf(best, lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
	return best if is_finite(best) else 0.0


# ════════ Cristales (unidad 4v) ════════
# La luneta, donde puede quedarse el animal (MovingCar.ZONES.luneta), y los paneles de los cristales donde se agarra (los del
# golpe siguen en PANELS). Dibujo.

## El panel de la luneta (m, x desde la zaga): del pie de la luneta, junto a la tapa del maletero (BELT[-1], 0,63 m), al borde
## del techo (TOP[13], 1,44 m), con un margen para el marco.
const LUNETA_PANEL := Vector2(0.65, 1.42)
## El medio ancho de la luneta en su centro (m): la cabina a esa altura menos el canto redondeado y el marco.
const LUNETA_HW := 0.56


## El panel de una zona en la que se agarra (m): el de la luneta o el de siempre (PANELS, o fallback).
static func hold_panel(zone: String, fallback: Vector2) -> Vector2:
	if zone == "luneta":
		return LUNETA_PANEL
	return PANELS.get(zone, fallback)
