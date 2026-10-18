## Taller · afiladora: geometría del bisel que se amuela (sección del filo) y de la rebaba. Funciones puras, sin
## estado ni variables estáticas: se pueden llamar desde cualquier hilo. Detalle en docs/taller/afilado-simulador.md
## → «Integración, oleada 2».
##
## Modelo (en la sección de la hoja, perpendicular al filo):
## - La hoja llega con su bisel de antes: una cuña con las caras A y B a β0a y β0b de la línea de referencia (la del
##   vértice ideal; en una cuchilla de cortacésped la cara B es plana, β0b = 0), su hombro donde el espesor llega a
##   t_sh y el cuerpo que engorda hasta el lomo (t_sp a h mm del filo).
## - El filo está romo: el vértice es un plano de t_flat de ancho (lo elige el usuario: cuánto se ha gastado). Está en
##   x0 = t_flat/(tan β0a + tan β0b) del vértice ideal.
## - La muela deja en cada cara una recta al ángulo β con el que se afila. Entra en el metal por donde lo toca primero
##   (el hombro si β < β0: hay que rehacer el bisel entero; el filo romo si β > β0: sale un microbisel) y retrocede d
##   (retroceso de la cara: el metal arrancado entre el área de contacto, Q/A de grinding.gd). Su distancia a la línea
##   de referencia es y = x·tan β + c, con c = c_toque − d/cos β.
## - Se llega al filo cuando las dos caras se cortan dentro del metal, por detrás del plano romo: el espesor en x0 es
##   ≤ 0. Desde ese momento, cada pasada deja una rebaba en el lado contrario al que se amuela (la de la otra cara la
##   da la vuelta) hasta que se quita en el cuero (el número de pasadas lo da sharpening_sim.gd).
## Todo en mm y grados; los µm, donde se dice.
extends RefCounted

## Iteraciones de la bisección (sobre [x0, h]: con h = 100 mm, 60 iteraciones dejan el vértice a menos de 1e-16 mm).
const BISECT := 60


## Geometría de la hoja. p = { side_a_deg (β0 de la cara A), side_b_deg (β0 de la cara B; 0 en un bisel de un
## lado), flat_um (ancho del filo romo), shoulder_mm (espesor donde acaba el bisel), spine_mm (espesor en el lomo),
## height_mm (del filo al lomo) }. Devuelve { ta0, tb0, x0, x_sh, h, slope_a, slope_b, t_flat, t_sh } (mm y tangentes).
static func blade(p: Dictionary) -> Dictionary:
	var a0 := clampf(_num(p, "side_a_deg", 17.5), 1.0, 60.0)
	var b0 := clampf(_num(p, "side_b_deg", a0), 0.0, 60.0)
	var ta0 := tan(deg_to_rad(a0))
	var tb0 := tan(deg_to_rad(b0))
	var sum0 := ta0 + tb0
	var t_sh := maxf(_num(p, "shoulder_mm", 0.6), 0.01)
	var t_flat := clampf(_num(p, "flat_um", 30.0) * 1e-3, 0.0, t_sh * 0.9)
	var t_sp := maxf(_num(p, "spine_mm", t_sh), t_sh)
	var x_sh := t_sh / sum0
	var h := maxf(_num(p, "height_mm", 40.0), x_sh * 1.5)
	# El cuerpo, del hombro al lomo, engorda repartido entre las dos caras como el bisel
	var slope := (t_sp - t_sh) / maxf(h - x_sh, 1e-9)
	return {
		"ta0": ta0, "tb0": tb0, "x0": t_flat / sum0, "x_sh": x_sh, "h": h,
		"slope_a": slope * ta0 / sum0, "slope_b": slope * tb0 / sum0, "t_flat": t_flat, "t_sh": t_sh,
		"side_a_deg": a0, "side_b_deg": b0,
	}


## Altura de la cara de antes (side 0 = A, 1 = B) a x mm del vértice ideal: la distancia a la línea de referencia.
static func surface(g: Dictionary, side: int, x: float) -> float:
	var t0: float = g["ta0"] if side == 0 else g["tb0"]
	var x_sh: float = g["x_sh"]
	if x <= x_sh:
		return x * t0
	return x_sh * t0 + (x - x_sh) * float(g["slope_a"] if side == 0 else g["slope_b"])


## c de la recta de la muela al ángulo beta_deg cuando toca por primera vez la cara de antes: el máximo de
## (altura − x·tan β) en el perfil, que es cóncavo (basta mirar el filo romo, el hombro y el lomo).
static func touch_offset(g: Dictionary, side: int, beta_deg: float) -> float:
	var tb := tan(deg_to_rad(beta_deg))
	var best := -INF
	for x: float in [float(g["x0"]), float(g["x_sh"]), float(g["h"])]:
		best = maxf(best, surface(g, side, x) - x * tb)
	return best


## c de la cara amolada (mm) con el ángulo beta_deg y un retroceso depth_mm (medido perpendicular a la cara).
static func face_offset(g: Dictionary, side: int, beta_deg: float, depth_mm: float) -> float:
	return touch_offset(g, side, beta_deg) - maxf(depth_mm, 0.0) / cos(deg_to_rad(beta_deg))


## Cara efectiva (mm): la de antes o la recta de la muela, la que esté más dentro. faces = [ { beta_deg, c } | null
## (sin amolar), … ] para A y B.
static func face_y(g: Dictionary, faces: Array, side: int, x: float) -> float:
	var y := surface(g, side, x)
	var f: Variant = faces[side]
	if f is Dictionary:
		y = minf(y, x * tan(deg_to_rad(float(f["beta_deg"]))) + float(f["c"]))
	return y


## Espesor (mm) a x del vértice ideal con las caras amoladas.
static func thickness(g: Dictionary, faces: Array, x: float) -> float:
	return face_y(g, faces, 0, x) + face_y(g, faces, 1, x)


## Caras amoladas a partir de los retrocesos: beta_a/beta_b en grados y depth_a/depth_b en mm (0 = sin amolar).
static func faces_for(g: Dictionary, beta_a: float, depth_a_mm: float, beta_b: float, depth_b_mm: float) -> Array:
	var fa: Variant = { "beta_deg": beta_a, "c": face_offset(g, 0, beta_a, depth_a_mm) } if depth_a_mm > 0.0 else null
	var fb: Variant = { "beta_deg": beta_b, "c": face_offset(g, 1, beta_b, depth_b_mm) } if depth_b_mm > 0.0 else null
	return [fa, fb]


## Estado del filo: { gap_um (espesor que queda en el plano romo; 0 si ya hay filo), sharp, tip_x_mm (dónde se
## cortan las caras, o x0 si aún está romo), flat_um }.
static func edge_state(g: Dictionary, faces: Array) -> Dictionary:
	var x0: float = g["x0"]
	var t0 := thickness(g, faces, x0)
	var sharp := t0 <= 0.0
	var tip := x0
	if sharp:
		# el espesor crece con x (todas las caras tienen pendiente ≥ 0): una sola raíz entre x0 y el lomo
		var lo := x0
		var hi: float = g["h"]
		if thickness(g, faces, hi) <= 0.0:
			tip = hi
		else:
			for _i in BISECT:
				var mid := 0.5 * (lo + hi)
				if thickness(g, faces, mid) <= 0.0:
					lo = mid
				else:
					hi = mid
			tip = lo
	return { "gap_um": maxf(t0, 0.0) * 1000.0, "sharp": sharp, "tip_x_mm": tip, "flat_um": float(g["t_flat"]) * 1000.0 }


## Retroceso que falta (mm, el mismo en cada cara de `sides`: [true/false para A, true/false para B]) para llegar al
## filo con las caras a beta_a y beta_b. 0 si ya hay filo. Para el avance del bisel en la interfaz.
static func depth_to_edge(g: Dictionary, beta_a: float, depth_a_mm: float, beta_b: float, depth_b_mm: float, sides: Array) -> float:
	var use_a := bool(sides[0])
	var use_b := bool(sides[1])
	if not use_a and not use_b:
		return INF
	if thickness(g, faces_for(g, beta_a, depth_a_mm, beta_b, depth_b_mm), float(g["x0"])) <= 0.0:
		return 0.0
	var lo := 0.0
	var hi := float(g["t_sh"]) + float(g["h"])  # más que de sobra: la cara cruza toda la hoja
	for _i in BISECT:
		var mid := 0.5 * (lo + hi)
		var f := faces_for(g, beta_a, depth_a_mm + (mid if use_a else 0.0), beta_b, depth_b_mm + (mid if use_b else 0.0))
		if thickness(g, f, float(g["x0"])) <= 0.0:
			hi = mid
		else:
			lo = mid
	return hi


## Contorno de la sección para dibujarla (mm, x desde el vértice ideal, y hacia la cara A): { a, b (polilíneas de cada
## cara desde el filo hasta x_max; y de B en negativo), tip (Vector2), sharp, flat: [arriba, abajo] si está romo,
## new_a, new_b (tramos de la cara nueva: [desde, hasta] en x, o []), x_max }.
static func outline(g: Dictionary, faces: Array, x_max: float = -1.0) -> Dictionary:
	var st := edge_state(g, faces)
	var x_start: float = st["tip_x_mm"]
	var xm := x_max if x_max > 0.0 else minf(float(g["h"]), maxf(float(g["x_sh"]) * 2.5, x_start + 0.5))
	var x_sh: float = g["x_sh"]
	# Vértices del contorno: el filo, el hombro de antes y los cortes de cada recta de la muela con la cara de antes
	var xs: Array[float] = [x_start, xm, x_sh]
	var news: Array = [[], []]
	for side in 2:
		var f: Variant = faces[side]
		if not (f is Dictionary):
			continue
		var cuts := _cuts(g, side, float(f["beta_deg"]), float(f["c"]))
		xs.append_array(cuts)
		# La cara nueva va por dentro de la de antes entre sus dos cortes (la diferencia es convexa: un solo tramo)
		var lo := x_start
		var hi := xm
		for x in cuts:
			var probe_lo := x - 1e-6
			var line := probe_lo * tan(deg_to_rad(float(f["beta_deg"]))) + float(f["c"])
			if line > surface(g, side, probe_lo):
				lo = maxf(lo, x)  # por delante del corte la recta va por fuera: el tramo empieza aquí
			else:
				hi = minf(hi, x)
		# comprobación en el medio del tramo: si la recta va por fuera, la cara nueva cae fuera de la ventana
		var mid := 0.5 * (lo + hi)
		if lo < hi and mid * tan(deg_to_rad(float(f["beta_deg"]))) + float(f["c"]) <= surface(g, side, mid) + 1e-12:
			news[side] = [lo, hi]
	var pts: Array[float] = []
	for x in xs:
		if x >= x_start - 1e-12 and x <= xm + 1e-12 and not pts.has(x):
			pts.append(x)
	pts.sort()
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for x in pts:
		a.append(Vector2(x, face_y(g, faces, 0, x)))
		b.append(Vector2(x, -face_y(g, faces, 1, x)))
	var tip := Vector2(x_start, face_y(g, faces, 0, x_start))
	var out := {
		"a": a, "b": b, "tip": tip, "sharp": st["sharp"], "x_max": xm, "new_a": news[0], "new_b": news[1],
		"gap_um": st["gap_um"],
	}
	if not bool(st["sharp"]):
		out["flat"] = [Vector2(x_start, face_y(g, faces, 0, x_start)), Vector2(x_start, -face_y(g, faces, 1, x_start))]
	return out


## x (mm) donde la recta de la muela (y = x·tan β + c) corta la cara de antes: con el bisel y con el cuerpo, solo
## los que caen en su tramo.
static func _cuts(g: Dictionary, side: int, beta_deg: float, c: float) -> Array[float]:
	var out: Array[float] = []
	var tb := tan(deg_to_rad(beta_deg))
	var t0: float = g["ta0"] if side == 0 else g["tb0"]
	var sl: float = g["slope_a"] if side == 0 else g["slope_b"]
	var x_sh: float = g["x_sh"]
	if absf(tb - t0) > 1e-12:
		var x1 := -c / (tb - t0)
		if x1 >= 0.0 and x1 <= x_sh:
			out.append(x1)
	if absf(tb - sl) > 1e-12:
		var x2 := (x_sh * (t0 - sl) - c) / (tb - sl)
		if x2 > x_sh and x2 <= float(g["h"]):
			out.append(x2)
	return out


static func _num(p: Dictionary, key: String, def: float) -> float:
	var v: Variant = p.get(key)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return def
	var f := float(v)
	return f if is_finite(f) else def
