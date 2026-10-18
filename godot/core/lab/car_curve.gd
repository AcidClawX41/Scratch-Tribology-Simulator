## Tribología biológica · coche en marcha en curva (modelo 2.0, unidad 4t, petición 63 de Eric: «añadir un coche que gira
## en curvas, y cambia radicalmente el lado de la fuerza G»).
##
## En una curva de radio R a la velocidad v aparece la aceleración lateral a = v²/R (cinemática, exacta), que empuja al
## animal del techo hacia fuera de la curva. Se suma como vector al viento (hacia atrás) y al peso con el modelo de agarre
## de siempre (MovingCar: la componente lateral ty = D_lat + m·a_lat de _eval), sin tocar nada de la recta: con la carretera
## recta no se llama a nada de aquí y todo sale al bit como antes.
##   1. Radios: los mínimos de la norma española de trazado (3.1-IC, tabla 4.4) por velocidad de proyecto, y el de una
##      glorieta urbana (3.1-IC, 10.6). La curva va sin peralte, el peor caso para el animal (se dice en el documento).
##   2. Tope del coche: lo que dan los neumáticos de lado antes de derrapar (CAR_GRIP). Si la curva pide más, el coche no
##      gira: derrapa, y el animal no siente más que ese tope (nunca un número imposible).
##   3. Curva en S: dos curvas de sentido contrario unidas por una clotoide (3.1-IC, 4.4), con la longitud que pide la norma
##      a la velocidad de proyecto para su variación de la aceleración centrífuga J (tabla 4.6, con peralte 0). A otra
##      velocidad, el tirón es J·(v/v_p)³.
##   4. Garras de cada lado: la fuerza lateral a la altura del centro de masas carga más las garras del lado de fuera
##      (estática de un sólido sobre dos apoyos, con la relación altura/base LOAD_TRANSFER, estimación). En la S, el pico
##      cae en las del lado nuevo.
## Funciones puras, estáticas y deterministas; sin nodos (CONTRATOS.md). Guía: docs/fisica/coche-en-marcha.md §20.
## Convenio: el eje lateral del modelo (+y, el del viento lateral) es la derecha del coche. side = +1: la curva gira a la
## izquierda y empuja hacia la derecha; side = −1, al revés. La «Curva» gira a la izquierda; la «Curva en S», primero a la
## izquierda y luego a la derecha.
## Uso: const CarCurve = preload("res://core/lab/car_curve.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const SportsCar = preload("res://core/lab/sports_car.gd")

const G := MovingCar.G
const KMH := MovingCar.KMH

const ROAD_STRAIGHT := "recta"
const ROAD_CURVE := "curva"
const ROAD_S := "s"
const ROADS := [
	{ "id": ROAD_STRAIGHT, "name": "Recta", "title": "Carretera recta: sin aceleración lateral" },
	{ "id": ROAD_CURVE, "name": "Curva", "title": "Una curva a la izquierda: la fuerza tira hacia fuera, a la derecha" },
	{ "id": ROAD_S, "name": "Curva en S", "title": "Una curva a la izquierda y otra a la derecha, unidas por una clotoide: la fuerza cambia de lado" },
]

# ── Fuentes ──
const SRC_31IC := "Ministerio de Fomento (2016). Norma 3.1-IC Trazado, de la Instrucción de Carreteras (Orden FOM/273/2016, BOE núm. 55, de 4 de marzo de 2016)"
const SRC_RADII := SRC_31IC + ", tabla 4.4: radio mínimo por velocidad de proyecto (40 km/h, 50 m; 50, 85; 60, 130; 70, 190; 80, 265; 90, 350; 100, 450; 110, 550; 120, 700; 130, 850; 140, 1050), calculado con V² = 127·R·(f_t + p/100), el rozamiento transversal de la tabla 4.3 y el peralte máximo (7 u 8 %)"
const SRC_JERK := SRC_31IC + ", 4.4.3.1 y tabla 4.6: la variación de la aceleración centrífuga J en la curva de acuerdo (clotoide) se limita a 0,5 m/s³ por debajo de 80 km/h y a 0,4 m/s³ desde 80 km/h; con peralte 0, la clotoide mide L = V³/(46,656·J·R)"
const SRC_RING := SRC_31IC + ", 10.6: el diámetro exterior de la calzada anular de una glorieta urbana de un carril se procura de 30 a 40 m (no menos de 28 m)"
const SRC_WONG := "Wong JY (2008). Theory of Ground Vehicles, 4.ª ed., Wiley: adherencia de pico del neumático en asfalto seco de 0,8 a 0,9"
const SRC_GT3 := "Car and Driver (2021), prueba del Porsche 911 GT3 (992): 1,16 g en la pista circular de 300 pies, vía Stuttcars (2022), «Porsche of the Day: 2022 Porsche 911 GT3»"
const SRC_KINEMATICS := "cinemática del movimiento circular: a = v²/R hacia el centro de la curva; en el coche, el animal la siente como una fuerza de inercia m·a hacia fuera"

## Radios mínimos de la norma (tabla 4.4): velocidad de proyecto (km/h), radio (m), peralte máximo (%) y grupo de carretera.
## Hasta 90 km/h, el grupo 3 (carreteras convencionales, 7 %); de 100 a 120, el 2 (8 %); 130 y 140, el 1 (autopistas, 8 %).
const NORM_RADII := [
	{ "v_kmh": 40.0, "r_m": 50.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 50.0, "r_m": 85.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 60.0, "r_m": 130.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 70.0, "r_m": 190.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 80.0, "r_m": 265.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 90.0, "r_m": 350.0, "p": 7.0, "group": 3 },
	{ "v_kmh": 100.0, "r_m": 450.0, "p": 8.0, "group": 2 },
	{ "v_kmh": 110.0, "r_m": 550.0, "p": 8.0, "group": 2 },
	{ "v_kmh": 120.0, "r_m": 700.0, "p": 8.0, "group": 2 },
	{ "v_kmh": 130.0, "r_m": 850.0, "p": 8.0, "group": 1 },
	{ "v_kmh": 140.0, "r_m": 1050.0, "p": 8.0, "group": 1 },
]
## Rozamiento transversal máximo movilizado a 40 km/h (tabla 4.3) y peralte del grupo 3: con ellos se extrapola la velocidad
## de proyecto por debajo del radio mínimo de la tabla (la glorieta).
const FT_40 := 0.180
const P_GROUP3 := 7.0
## J de la norma (m/s³, tabla 4.6): por debajo de 80 km/h y desde 80 km/h.
const JERK_LOW := 0.5
const JERK_HIGH := 0.4
const JERK_FROM_KMH := 80.0

## Glorieta urbana de un carril: 30-40 m de diámetro exterior (3.1-IC, 10.6), 15-20 m de radio exterior; el coche va por el
## centro de su carril, unos 2-3 m más adentro (medio carril con su resguardo: estimación). 15 m.
const RING_R := { "value": 15.0, "min": 12.0, "max": 18.0, "quality": "estimate", "source": SRC_RING + "; el coche va por el centro del carril, unos 2-3 m por dentro del borde exterior (estimación)" }

## Valores marcados en el deslizador del radio: la glorieta y los radios mínimos de la norma de 40 a 120 km/h.
const PRESETS := [
	{ "id": "glorieta", "name": "Glorieta", "r_m": 15.0, "quality": "estimate", "source": SRC_RING },
	{ "id": "v40", "name": "40 km/h", "r_m": 50.0, "quality": "primary", "source": SRC_RADII },
	{ "id": "v60", "name": "60 km/h", "r_m": 130.0, "quality": "primary", "source": SRC_RADII },
	{ "id": "v80", "name": "80 km/h", "r_m": 265.0, "quality": "primary", "source": SRC_RADII },
	{ "id": "v100", "name": "100 km/h", "r_m": 450.0, "quality": "primary", "source": SRC_RADII },
	{ "id": "v120", "name": "120 km/h", "r_m": 700.0, "quality": "primary", "source": SRC_RADII },
]
## Recorrido del deslizador del radio (m): de la glorieta al radio mínimo de 140 km/h, en escala logarítmica.
const R_MIN_M := 15.0
const R_MAX_M := 1050.0
const DEFAULT_R := 130.0

## Lo que dan los neumáticos de lado antes de derrapar (g), en asfalto seco. El turismo: la adherencia de pico de Wong; el
## deportivo: sin una prueba de patinaje publicada del Carrera, el caso medido más parecido es su versión de circuito (el
## GT3, con neumáticos semislick, 1,16 g), y el de serie queda por debajo.
const CAR_GRIP := {
	"turismo": { "value": 0.85, "min": 0.8, "max": 0.9, "quality": "estimate", "source": SRC_WONG + "; de lado, en un turismo de serie, se toma lo mismo (estimación)" },
	"deportivo": { "value": 1.0, "min": 0.9, "max": 1.1, "quality": "estimate", "source": "deportivo de serie con neumáticos de altas prestaciones: el caso medido más parecido es " + SRC_GT3 + "; el Carrera, con neumáticos de calle, por debajo (estimación)" },
}

## Reparto de la carga entre las garras de los dos lados: la fuerza lateral F_lat a la altura h del centro de masas, con los
## apoyos a ±b del centro, pasa ΔN = F_lat·h/(2·b) del lado de dentro al de fuera (estática de un sólido rígido). La relación
## h/b, sin medición publicada para un animal agarrado a un coche: agazapado, el centro de masas a la altura de media base de
## apoyo (h/b ≈ 1). El veredicto de agarre no depende de este reparto mientras las garras de dentro sigan apoyadas.
const LOAD_TRANSFER := { "value": 1.0, "min": 0.5, "max": 1.5, "quality": "estimate", "source": "estática de un sólido sobre dos apoyos (ΔN = F_lat·h/2b); la relación altura del centro de masas / media base de apoyo, h/b ≈ 1 agazapado, es una suposición: no hay medición publicada de un animal agarrado a un coche en curva" }

## Solo dibujo: lo que dura el tramo circular de cada curva de la S a la velocidad de proyecto y las rectas de antes y de
## después (s). La aceleración de pico y el tirón no dependen de ellos.
const ARC_S := 2.0
const LEAD_S := 1.0
const DRAW_ONLY := { "quality": "dibujo", "source": "solo dibujo: lo que duran los tramos circulares de la S y las rectas de antes y de después; la aceleración de pico y el tirón no dependen de ellos" }
## Por debajo de esta velocidad (km/h) el coche se da por parado en la S (MovingCar.REST_KMH).
const REST_KMH := MovingCar.REST_KMH


# ════════ Radios y velocidad de proyecto ════════

## Radio (m) de la posición u (0-1) del deslizador: escala logarítmica de R_MIN_M a R_MAX_M, redondeado a un número
## redondo (al metro por debajo de 100 m, a 5 m hasta 300 y a 10 m después) y, a menos de un 3 % de un valor marcado, ese.
static func radius_at(u: float) -> float:
	var k := clampf(u, 0.0, 1.0)
	var r := R_MIN_M * V8.js_pow(R_MAX_M / R_MIN_M, k)
	for p: Dictionary in PRESETS:
		if absf(r - float(p.r_m)) <= 0.03 * float(p.r_m):
			return float(p.r_m)
	var step := 1.0 if r < 100.0 else (5.0 if r < 300.0 else 10.0)
	return clampf(Js.js_round(r / step) * step, R_MIN_M, R_MAX_M)


## Posición del deslizador (0-1) de un radio (m).
static func slider_u(r_m: float) -> float:
	var r := clampf(r_m, R_MIN_M, R_MAX_M)
	return V8.js_log(r / R_MIN_M) / V8.js_log(R_MAX_M / R_MIN_M)


## Velocidad de proyecto (km/h) de una curva de radio r_m: la mayor de la tabla 4.4 cuyo radio mínimo cabe en ella; por
## debajo de 50 m (la glorieta), la de la expresión de 4.3.2 con el rozamiento de 40 km/h y el 7 % (extrapolación).
static func design_kmh(r_m: float) -> float:
	var v := 0.0
	for e: Dictionary in NORM_RADII:
		if r_m >= float(e.r_m) - 1e-9:
			v = float(e.v_kmh)
	if v > 0.0:
		return v
	return sqrt(127.0 * r_m * (FT_40 + P_GROUP3 / 100.0))


## J de la norma (m/s³) a una velocidad de proyecto (tabla 4.6).
static func jerk_norm(design: float) -> float:
	return JERK_LOW if design < JERK_FROM_KMH else JERK_HIGH


## Tope de agarre lateral del coche del catálogo (CAR_GRIP): el deportivo o un turismo.
static func grip_of(target: Variant) -> Dictionary:
	if target is Dictionary and String((target as Dictionary).get("id", "")) == SportsCar.ID:
		return CAR_GRIP.deportivo
	return CAR_GRIP.turismo


# ════════ Cinemática ════════

## Aceleración lateral que pide la curva (m/s²): a = v²/R, exacta.
static func lateral_ms2(v_kmh: float, r_m: float) -> float:
	var v := maxf(v_kmh, 0.0) / KMH
	return v * v / r_m


## La misma en g.
static func demand_g(v_kmh: float, r_m: float) -> float:
	return lateral_ms2(v_kmh, r_m) / G


## Velocidad (km/h) a la que la curva pide todo lo que dan los neumáticos: más deprisa, el coche derrapa.
static func skid_kmh(r_m: float, grip_g: float) -> float:
	return sqrt(grip_g * G * r_m) * KMH


## Lo que siente el animal (m/s², sin signo): lo que pide la curva, sin pasar del tope del coche (si derrapa, los
## neumáticos ya no dan más).
static func felt_ms2(v_kmh: float, r_m: float, grip_g: float) -> float:
	return minf(lateral_ms2(v_kmh, r_m), grip_g * G)


## La carretera de una curva de radio r_m con el coche del catálogo: su velocidad de proyecto, el J de la norma, las
## clotoides (de la recta a la curva y de una curva a la contraria), los tramos de la S y el tope del coche.
## { rM, designKmh, jerkNorm, clothoidM, reverseM, arcM, leadM, lengthM, grip, skidKmh, skidMinKmh, skidMaxKmh, quality,
##   source }.
static func road(r_m: float, target: Variant) -> Dictionary:
	var design := design_kmh(r_m)
	var j := jerk_norm(design)
	var vp := design / KMH
	var l_in := vp * vp * vp / (j * r_m)
	var l_arc := vp * ARC_S
	var lead := vp * LEAD_S
	var grip := grip_of(target)
	return {
		"rM": r_m, "designKmh": design, "jerkNorm": j, "clothoidM": l_in, "reverseM": 2.0 * l_in, "arcM": l_arc, "leadM": lead,
		"lengthM": 2.0 * lead + 2.0 * l_in + 2.0 * l_arc + 2.0 * l_in, "grip": grip,
		"skidKmh": skid_kmh(r_m, float(grip.value)), "skidMinKmh": skid_kmh(r_m, float(grip.min)), "skidMaxKmh": skid_kmh(r_m, float(grip.max)),
		"quality": "primary" if r_m >= float(NORM_RADII[0].r_m) else "estimate",
		"source": SRC_RADII if r_m >= float(NORM_RADII[0].r_m) else RING_R.source,
	}


## Curvatura (1/m, + a la izquierda) de la S a s_m metros de su principio: recta, clotoide de entrada, curva a la
## izquierda, clotoide de cambio (de +1/R a −1/R), curva a la derecha, clotoide de salida y recta.
static func s_kappa(rd: Dictionary, s_m: float) -> float:
	var k := 1.0 / float(rd.rM)
	var lead: float = rd.leadM
	var l_in: float = rd.clothoidM
	var l_arc: float = rd.arcM
	var l_rev: float = rd.reverseM
	var s := s_m
	if s < lead:
		return 0.0
	s -= lead
	if s < l_in:
		return k * s / l_in
	s -= l_in
	if s < l_arc:
		return k
	s -= l_arc
	if s < l_rev:
		return k - 2.0 * k * s / l_rev
	s -= l_rev
	if s < l_arc:
		return -k
	s -= l_arc
	if s < l_in:
		return -k + k * s / l_in
	return 0.0


## Ritmo de cambio de la curvatura (1/m²) de la S en s_m (el de la clotoide en la que esté; 0 en las curvas y las rectas).
static func s_dkappa(rd: Dictionary, s_m: float) -> float:
	var k := 1.0 / float(rd.rM)
	var lead: float = rd.leadM
	var l_in: float = rd.clothoidM
	var l_arc: float = rd.arcM
	var l_rev: float = rd.reverseM
	var s := s_m - lead
	if s < 0.0:
		return 0.0
	if s < l_in:
		return k / l_in
	s -= l_in + l_arc
	if s < 0.0:
		return 0.0
	if s < l_rev:
		return -2.0 * k / l_rev
	s -= l_rev + l_arc
	if s < 0.0:
		return 0.0
	if s < l_in:
		return k / l_in
	return 0.0


## Lo que dura la S (s) con el coche a v_kmh (INF parado).
static func s_duration(rd: Dictionary, v_kmh: float) -> float:
	if v_kmh < REST_KMH:
		return INF
	return float(rd.lengthM) / (v_kmh / KMH)


## La S en el instante t_s (desde su principio) con el coche a v_kmh: { aMs2 (con signo: + hacia la derecha), gLat,
## demandMs2 (lo que pide, con signo), jerkMs3 (el tirón de ahora, con signo), side (+1, −1 o 0), phase, sM, skids }.
## phase: «recta», «entrada», «curva1», «cambio», «curva2», «salida».
static func s_at(rd: Dictionary, v_kmh: float, t_s: float) -> Dictionary:
	var v := maxf(v_kmh, 0.0) / KMH
	var s := v * maxf(t_s, 0.0)
	var amax := float(rd.grip.value) * G
	var kap := s_kappa(rd, s)
	var demand := v * v * kap
	var a := clampf(demand, -amax, amax)
	var jerk := 0.0
	if absf(demand) < amax:
		jerk = v * v * v * s_dkappa(rd, s)
	return {
		"aMs2": a, "gLat": a / G, "demandMs2": demand, "jerkMs3": jerk, "side": signf(a), "phase": _phase(rd, s), "sM": s,
		"skids": absf(demand) > amax,
	}


static func _phase(rd: Dictionary, s_m: float) -> String:
	var marks := [
		float(rd.leadM), float(rd.clothoidM), float(rd.arcM), float(rd.reverseM), float(rd.arcM), float(rd.clothoidM),
	]
	var names := ["recta", "entrada", "curva1", "cambio", "curva2", "salida"]
	var s := s_m
	for i in marks.size():
		if s < float(marks[i]):
			return names[i]
		s -= float(marks[i])
	return "recta"


## La S entera con el coche a v_kmh, en n muestras: { tS, aMs2, jerkMs3 (PackedFloat64Array), durationS, peakMs2, peakG,
## jerkPeakMs3 (el del cambio de lado: J·(v/v_p)³ por 2 en la clotoide de cambio, que es el doble de larga y cambia el
## doble), flipS (el instante en que la fuerza cambia de lado), skids }.
static func s_profile(rd: Dictionary, v_kmh: float, n := 121) -> Dictionary:
	var ts := PackedFloat64Array()
	var aa := PackedFloat64Array()
	var jj := PackedFloat64Array()
	var dur := s_duration(rd, v_kmh)
	var count := maxi(n, 2)
	var peak := 0.0
	var skids := false
	for i in count:
		var t := 0.0 if is_inf(dur) else dur * float(i) / float(count - 1)
		var p := s_at(rd, v_kmh, t)
		ts.append(t)
		aa.append(float(p.aMs2))
		jj.append(float(p.jerkMs3))
		peak = maxf(peak, absf(float(p.aMs2)))
		skids = skids or bool(p.skids)
	var v := maxf(v_kmh, 0.0) / KMH
	var flip := INF
	if v > 0.0:
		flip = (float(rd.leadM) + float(rd.clothoidM) + float(rd.arcM) + 0.5 * float(rd.reverseM)) / v
	var jpk := v * v * v * 2.0 / (float(rd.rM) * float(rd.reverseM))
	return {
		"tS": ts, "aMs2": aa, "jerkMs3": jj, "durationS": dur, "peakMs2": peak, "peakG": peak / G, "jerkPeakMs3": jpk,
		"flipS": flip, "skids": skids,
	}


## El tirón (m/s³) en la clotoide de cambio de la S a v_kmh: el de la norma a la velocidad de proyecto (J) por (v/v_p)³.
static func s_jerk_ms3(rd: Dictionary, v_kmh: float) -> float:
	var v := maxf(v_kmh, 0.0) / KMH
	return v * v * v * 2.0 / (float(rd.rM) * float(rd.reverseM))


# ════════ El animal en la curva ════════

## El escenario de MovingCar.setup con otra aceleración lateral (m/s², con signo): una copia superficial (el de partida no
## se toca). En curva, la aceleración lateral la pone la curva (la de la maniobra no se suma: la tarjeta no deja elegir las
## dos).
static func scen_at(scen: Dictionary, ay_ms2: float) -> Dictionary:
	var s := scen.duplicate()
	s.ay = ay_ms2
	return s


## Las fuerzas con el coche a v_kmh en la curva de radio r_m (side: +1 empuja a la derecha, −1 a la izquierda): las de
## MovingCar.at_speed con a = v²/R (sin pasar del tope del coche, grip_g) y, en curve, lo propio de la curva:
## { rM, side, demandMs2, demandG, latMs2 (con signo), latG, skids, gripG, skidKmh, tyN, ttN, shares, markDeg, meter }.
static func at_speed(scen: Dictionary, v_kmh: float, r_m: float, grip_g: float, side: float) -> Dictionary:
	var a := side * felt_ms2(v_kmh, r_m, grip_g)
	return at_lateral(scen, v_kmh, a, r_m, grip_g)


## Lo mismo con una aceleración lateral dada (m/s², con signo): la de un instante de la S (s_at).
static func at_lateral(scen: Dictionary, v_kmh: float, a_ms2: float, r_m: float, grip_g: float) -> Dictionary:
	var sc := scen_at(scen, a_ms2)
	var out := MovingCar.at_speed(sc, v_kmh)
	var c: Dictionary = scen.cases.nom
	var v := maxf(v_kmh, 0.0) / KMH
	var f := MovingCar._eval(c, v, scen.wh, scen.wc, scen.ax, a_ms2)
	var m: float = c.m
	var demand := lateral_ms2(v_kmh, r_m)
	out["curve"] = {
		"rM": r_m, "side": signf(a_ms2), "demandMs2": demand, "demandG": demand / G, "latMs2": a_ms2, "latG": a_ms2 / G,
		"skids": demand > grip_g * G, "gripG": grip_g, "skidKmh": skid_kmh(r_m, grip_g),
		"tyN": f.ty, "ttN": f.tt, "shares": side_shares(float(f.ty), float(f.rn)), "markDeg": mark_deg(float(f.tt), float(f.ty)),
		"meter": {
			"latG": float(f.ty) / (m * G), "backG": float(f.tt) / (m * G), "needG": float(f.need) / (m * G),
			"availG": float(f.avail) / (m * G), "gripG": grip_g, "holds": float(f.margin) >= 0.0,
		},
	}
	return out


## Reparto de la normal entre las garras de los dos lados: { right, left (0-1, suman 1), lo, hi (la parte del lado
## cargado con h/b de la banda), loaded (+1 derecha, −1 izquierda, 0 igual), lifts (las de dentro ya no apoyan) }.
## ty: la fuerza lateral (N, + a la derecha); rn: la normal contra el panel (N).
static func side_shares(ty: float, rn: float) -> Dictionary:
	if rn <= 0.0:
		return { "right": 0.5, "left": 0.5, "lo": 0.5, "hi": 0.5, "loaded": 0.0, "lifts": false }
	var x := ty / rn
	var right := clampf(0.5 + 0.5 * x * float(LOAD_TRANSFER.value), 0.0, 1.0)
	var lo := clampf(0.5 + 0.5 * absf(x) * float(LOAD_TRANSFER.min), 0.0, 1.0)
	var hi := clampf(0.5 + 0.5 * absf(x) * float(LOAD_TRANSFER.max), 0.0, 1.0)
	return {
		"right": right, "left": 1.0 - right, "lo": lo, "hi": hi, "loaded": signf(x),
		"lifts": right >= 1.0 or right <= 0.0,
	}


## Hacia dónde tira la fuerza en el contacto (grados desde «hacia atrás», + hacia la derecha): la dirección en la que se
## tuercen los desgarros de las garras en la curva. tt: la tangencial a lo largo (N, + hacia atrás); ty: la lateral.
static func mark_deg(tt: float, ty: float) -> float:
	if tt == 0.0 and ty == 0.0:
		return 0.0
	return V8.js_atan2(ty, tt) * 180.0 / PI


# ════════ El golpe en la curva ════════

## La velocidad de giro del coche (rad/s, + girando a la izquierda) en la curva: la aceleración lateral que de verdad tiene
## (v²/R, sin pasar del tope) entre la velocidad: ω = a/v. side: +1, la curva a la izquierda (empuja a la derecha).
static func yaw_rate(v_kmh: float, r_m: float, grip_g: float, side: float) -> float:
	var v := maxf(v_kmh, 0.0) / KMH
	if v <= 0.0:
		return 0.0
	return side * felt_ms2(v_kmh, r_m, grip_g) / v


## Lo que pide y lo que tiene la curva sin animal (el golpe): { demandMs2, latMs2 (sin pasar del tope), skids }.
static func at_lateral_kin(v_kmh: float, r_m: float, grip_g: float) -> Dictionary:
	var d := lateral_ms2(v_kmh, r_m)
	return { "demandMs2": d, "latMs2": minf(d, grip_g * G), "skids": d > grip_g * G }


## El camino del animal que se abalanza, visto desde el coche que gira: lo que se separa de la recta en los últimos
## dist_m metros antes del golpe, en n puntos (del principio, a = 0, al golpe, a = 1), en metros del coche (x hacia delante,
## y hacia la derecha). Cinemática exacta: el animal corre en línea recta por la carretera y el coche sigue su círculo
## girando a ω; visto desde el coche (que gira con él), el camino se tuerce. rel_x: la velocidad del animal respecto al
## coche a lo largo (m/s, + hacia delante); rel_y: hacia la derecha (+); rel_z: la vertical (solo cuenta para el tiempo).
## La fuerza del golpe no cambia (la da MovingCar.impact, en recta): esto es solo el camino.
static func approach_offsets(rel_x: float, rel_y: float, rel_z: float, v_kmh: float, omega: float, dist_m: float, n := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := maxi(n, 2)
	var v := maxf(v_kmh, 0.0) / KMH
	var w3 := sqrt(rel_x * rel_x + rel_y * rel_y + rel_z * rel_z)
	var span := dist_m / w3 if w3 > 0.0 else 0.0
	if absf(omega) <= 1e-9:
		# sin giro, la recta: nada que torcer (sin el polvo de redondeo de restar dos rectas)
		for i in count:
			out.append(Vector2.ZERO)
		return out
	for i in count:
		var a := float(i) / float(count - 1)
		var t := -(1.0 - a) * span
		var th := omega * t
		var pcx := v * V8.js_sin(th) / omega
		var pcy := -v * (1.0 - V8.js_cos(th)) / omega
		# el animal, en línea recta por la carretera: su velocidad respecto al suelo es la relativa más la del coche
		var dx := (rel_x + v) * t - pcx
		var dy := rel_y * t - pcy
		var c := V8.js_cos(th)
		var sn := V8.js_sin(th)
		var fx := dx * c - dy * sn
		var fy := dx * sn + dy * c
		out.append(Vector2(fx - rel_x * t, fy - rel_y * t))
	return out


# ════════ Despegue en la curva ════════

## La velocidad (km/h) a la que el animal se suelta en la curva de radio r_m (side ±1), con la aceleración lateral de cada
## velocidad (v²/R, sin pasar del tope del coche): lo mismo que MovingCar.detach (kmh, minKmh, maxKmh, mode, atRest,
## beyond, never, holdFromKmh, holdToKmh, holdToMode) y, además, rM, side, gripG, skidKmh (el coche derrapa), skidMinKmh,
## skidMaxKmh y skidsFirst (el coche llega a su tope antes de que el animal se suelte).
static func detach(scen: Dictionary, r_m: float, grip: Dictionary, side: float) -> Dictionary:
	var g := float(grip.value)
	var nom := _detach_case(scen.cases.nom, scen.wh, scen.wc, scen.ax, r_m, g, side)
	var lo := INF
	for c: Dictionary in scen.cases.lo:
		lo = minf(lo, float(_detach_case(c, scen.wh, scen.wc, scen.ax, r_m, g, side).kmh))
	var hi := 0.0
	for c: Dictionary in scen.cases.hi:
		hi = maxf(hi, float(_detach_case(c, scen.wh, scen.wc, scen.ax, r_m, g, side).kmh))
	var kmh: float = nom.kmh
	var skid := skid_kmh(r_m, g)
	return {
		"kmh": kmh, "minKmh": minf(lo, kmh), "maxKmh": maxf(hi, kmh), "mode": nom.mode, "atRest": nom.atRest,
		"beyond": kmh > float(scen.get("vmaxKmh", MovingCar.SLIDER_MAX_KMH)), "never": is_inf(kmh),
		"holdFromKmh": nom.holdFromKmh, "holdToKmh": nom.holdToKmh, "holdToMode": nom.holdToMode,
		"rM": r_m, "side": side, "gripG": g, "skidKmh": skid, "skidMinKmh": skid_kmh(r_m, float(grip.min)),
		"skidMaxKmh": skid_kmh(r_m, float(grip.max)),
		"skidsFirst": bool(nom.atRest) and kmh >= skid,
	}


## En la curva en S: el despegue de los dos lados y el peor (el de menos velocidad; con viento lateral, el lado al que
## empuja el viento). { worst (el detach del peor lado), right, left }.
static func detach_s(scen: Dictionary, r_m: float, grip: Dictionary) -> Dictionary:
	var right := detach(scen, r_m, grip, 1.0)
	var left := detach(scen, r_m, grip, -1.0)
	var worst := right if _earlier(right, left) else left
	return { "worst": worst, "right": right, "left": left }


## ¿El despegue a se suelta antes (o igual) que b? (sin ventana: el de menos km/h; ni parado, antes que todo)
static func _earlier(a: Dictionary, b: Dictionary) -> bool:
	var ka := float(a.kmh) if bool(a.atRest) else -1.0
	var kb := float(b.kmh) if bool(b.atRest) else -1.0
	return ka <= kb


## La aceleración lateral (m/s², con signo) con el coche a v (m/s) en la curva.
static func _ay(v: float, r_m: float, grip_g: float, side: float) -> float:
	return side * minf(v * v / r_m, grip_g * G)


## El despegue de un caso: la búsqueda de MovingCar._detach_case (pasos de SCAN_STEP_KMH hasta SCAN_MAX_KMH y bisección
## en cada cambio), con la aceleración lateral de cada velocidad.
static func _detach_case(c: Dictionary, wh: float, wc: float, ax: float, r_m: float, grip_g: float, side: float) -> Dictionary:
	var step := MovingCar.SCAN_STEP_KMH / KMH
	var vmax := MovingCar.SCAN_MAX_KMH / KMH
	var rest_mode := ""
	var start := -1.0
	if MovingCar._margin(c, 0.0, wh, wc, ax, 0.0) >= 0.0:
		start = 0.0
	else:
		rest_mode = MovingCar._mode_of(MovingCar._eval(c, 0.0, wh, wc, ax, 0.0), c, ax)
	var prev := 0.0
	var v := step
	while v <= vmax + 1e-9:
		var holds := MovingCar._margin(c, v, wh, wc, ax, _ay(v, r_m, grip_g, side)) >= 0.0
		if holds and start < 0.0:
			var e := _bisect(c, prev, v, wh, wc, ax, r_m, grip_g, side)
			start = 0.0 if e * KMH < MovingCar.REST_KMH else e
		elif not holds and start >= 0.0:
			var b := _bisect(c, prev, v, wh, wc, ax, r_m, grip_g, side)
			var mode := MovingCar._mode_of(MovingCar._eval(c, b, wh, wc, ax, _ay(b, r_m, grip_g, side)), c, ax)
			if start > 0.0:
				return MovingCar._window(rest_mode, start, b * KMH, mode)
			if b * KMH >= MovingCar.REST_KMH:
				return { "kmh": b * KMH, "atRest": true, "mode": mode, "holdFromKmh": null, "holdToKmh": null, "holdToMode": "" }
			rest_mode = mode
			start = -1.0
		prev = v
		v += step
	if start > 0.0:
		return MovingCar._window(rest_mode, start, INF, "")
	if start == 0.0:
		return { "kmh": INF, "atRest": true, "mode": "", "holdFromKmh": null, "holdToKmh": null, "holdToMode": "" }
	return MovingCar._no_window(rest_mode)


static func _bisect(c: Dictionary, a: float, b: float, wh: float, wc: float, ax: float, r_m: float, grip_g: float, side: float) -> float:
	var hb := MovingCar._margin(c, b, wh, wc, ax, _ay(b, r_m, grip_g, side)) >= 0.0
	for i in 40:
		var mid := 0.5 * (a + b)
		if (MovingCar._margin(c, mid, wh, wc, ax, _ay(mid, r_m, grip_g, side)) >= 0.0) == hb:
			b = mid
		else:
			a = mid
	return b


## La gráfica en la curva: fuerza necesaria frente a la disponible (N) de 0 al tope del coche en n puntos, con las bandas
## (lo mismo que MovingCar.curve) y el despegue en la curva (detach).
static func chart(scen: Dictionary, r_m: float, grip: Dictionary, side: float, det: Dictionary, n := 61) -> Dictionary:
	var v_max := float(scen.get("vmaxKmh", MovingCar.SLIDER_MAX_KMH))
	var vs := PackedFloat64Array()
	var need := PackedFloat64Array()
	var avail := PackedFloat64Array()
	var need_max := PackedFloat64Array()
	var avail_min := PackedFloat64Array()
	var need_min := PackedFloat64Array()
	var avail_max := PackedFloat64Array()
	var count := maxi(n, 2)
	var g := float(grip.value)
	for i in count:
		var v := v_max * float(i) / float(count - 1)
		var s := MovingCar.at_speed(scen_at(scen, side * felt_ms2(v, r_m, g)), v)
		vs.append(v)
		need.append(s.needN)
		avail.append(s.availN)
		need_max.append(s.needMaxN)
		avail_min.append(s.availMinN)
		need_min.append(s.needMinN)
		avail_max.append(s.availMaxN)
	return {
		"vKmh": vs, "need": need, "avail": avail, "needMax": need_max, "availMin": avail_min, "needMin": need_min,
		"availMax": avail_max, "detach": det,
	}


# ════════ Textos ════════

## «hacia la derecha» o «hacia la izquierda» (side: +1 o −1; "" sin lado).
static func side_txt(side: float) -> String:
	if side > 0.0:
		return "hacia la derecha"
	if side < 0.0:
		return "hacia la izquierda"
	return ""


## «derecha» o «izquierda».
static func side_name(side: float) -> String:
	return "derecha" if side > 0.0 else ("izquierda" if side < 0.0 else "")


## Una aceleración lateral en g y en m/s²: «0.49 g (4.8 m/s²)».
static func g_ms2_txt(a_ms2: float) -> String:
	return "%s (%s m/s²)" % [CarFormat.fmt_g(absf(a_ms2) / G), Js.to_fixed(absf(a_ms2), 1)]


## Un radio en metros, entero: «130 m».
static func r_txt(r_m: float) -> String:
	return "%s m" % Js.js_num_str(Js.js_round(r_m))


## La curva a esa velocidad en una frase (c: el campo curve de at_speed): «En la curva de 130 m a 90 km/h tira hacia fuera
## con 0.49 g (4.8 m/s²), hacia la derecha.» o, si pide más que los neumáticos, que el coche derrapa.
static func now_txt(c: Dictionary, v_kmh: float) -> String:
	if v_kmh < REST_KMH:
		return "Parado, la curva de %s no tira hacia ningún lado." % r_txt(float(c.rM))
	var head := "En la curva de %s a %s" % [r_txt(float(c.rM)), CarFormat.fmt_kmh(v_kmh)]
	if bool(c.skids):
		return "%s el coche no gira: derrapa. La curva pediría %s y los neumáticos dan %s; el animal siente ese tope, %s." % [
			head, g_ms2_txt(float(c.demandMs2)), CarFormat.fmt_g(float(c.gripG)), side_txt(float(c.side))]
	return "%s tira hacia fuera con %s, %s." % [head, g_ms2_txt(float(c.demandMs2)), side_txt(float(c.side))]


## Veredicto del despegue en la curva: { verdict, vsub }. Si el coche derrapa antes de que se suelte, se dice eso; si se
## suelta de lado antes de que el coche derrape, a qué velocidad y con cuántos g; en lo demás, el de MovingCar con la
## aceleración lateral del despegue.
static func verdict(scen: Dictionary, det: Dictionary, c_kmh_max: float) -> Dictionary:
	var r: float = det.rM
	var skid: float = det.skidKmh
	var band := MovingCar._band_txt(det)
	var o := MovingCar._ending(scen)
	if bool(det.skidsFirst) and skid <= c_kmh_max:
		var g := float(skid_g(det))
		return {
			"verdict": "EL COCHE DERRAPA ANTES: A ~%s km/h" % CarFormat.kmh_txt(skid),
			"vsub": "en la curva de %s, a más de ~%s km/h los neumáticos ya no dan más de %s (de ~%s a ~%s km/h según el agarre): el coche no gira, derrapa; hasta ahí, bien agarrad%s, aguanta" % [
				r_txt(r), CarFormat.kmh_txt(skid), CarFormat.fmt_g(g), CarFormat.kmh_txt(float(det.skidMinKmh)), CarFormat.kmh_txt(float(det.skidMaxKmh)), o],
		}
	if bool(det.atRest) and not bool(det.never) and String(det.mode) == "lado" and float(det.kmh) <= c_kmh_max:
		var a := felt_ms2(float(det.kmh), r, float(skid_g(det)))
		return {
			"verdict": "RESBALA HACIA FUERA A ~%s km/h" % CarFormat.kmh_txt(float(det.kmh)),
			"vsub": "en la curva de %s, a ~%s km/h tira %s con %s: más de lo que aguantan sus garras; el coche aún giraría hasta ~%s km/h%s" % [
				r_txt(r), CarFormat.kmh_txt(float(det.kmh)), side_txt(float(det.side)), g_ms2_txt(a), CarFormat.kmh_txt(skid), band],
		}
	var v := MovingCar.detach_verdict(scen_at(scen, 0.0), det)
	v.vsub += "; en la curva de %s" % r_txt(r)
	return v


## El tope del coche (g) con el que se calculó un despegue en la curva.
static func skid_g(det: Dictionary) -> float:
	return float(det.gripG)


## Por qué aguanta o se suelta a esa velocidad en la curva, en una frase (a: at_speed con curve; animal: «el águila»). La
## frase de now_txt ya dice cuánto tira y hacia dónde: esta dice qué pide, qué dan sus garras y qué garras cargan.
static func why_txt(a: Dictionary, animal: String) -> String:
	var c: Dictionary = a.curve
	if absf(float(c.latMs2)) <= 0.0:
		return ""
	var sh: Dictionary = c.shares
	var loaded := "las garras de la %s cargan el %s del peso" % [side_name(float(sh.loaded)), CarFormat.fmt_pct(maxf(float(sh.right), float(sh.left)))]
	if bool(sh.lifts):
		loaded = "las garras de la %s cargan todo el peso: las de la otra ya no apoyan" % side_name(float(sh.loaded))
	if bool(a.holds):
		return "Sumada al viento, para sujetarse hacen falta %s y sus garras dan %s: %s aguanta, y %s (estimación)." % [
			CarFormat.fmt_n(float(a.needN)), CarFormat.fmt_n(float(a.availN)), animal, loaded]
	return "Sumada al viento, hacen falta %s y sus garras solo dan %s: más que el agarre de sus garras, y sale %s." % [
		CarFormat.fmt_n(float(a.needN)), CarFormat.fmt_n(float(a.availN)), side_txt(float(c.side))]


## Recorrido de la carretera visto desde arriba (m; x a la derecha, y hacia delante), en n puntos: la curva (un cuarto de
## vuelta a la izquierda tras una recta) o la S entera, con el coche al principio mirando hacia delante. Solo geometría,
## para el plano de la vista. { pts (PackedVector2Array), s (PackedFloat64Array: los metros de carretera de cada punto) }.
static func path(rd: Dictionary, road_id: String, n := 96) -> Dictionary:
	var pts := PackedVector2Array()
	var ss := PackedFloat64Array()
	var total := float(rd.lengthM)
	var curve := road_id != ROAD_S
	if curve:
		total = float(rd.leadM) + float(rd.clothoidM) + 0.5 * PI * float(rd.rM)
	var count := maxi(n, 2)
	var ds := total / float(count - 1)
	var head := 0.0
	var p := Vector2.ZERO
	for i in count:
		var s := ds * float(i)
		pts.append(p)
		ss.append(s)
		var k := _curve_kappa(rd, s + 0.5 * ds) if curve else s_kappa(rd, s + 0.5 * ds)
		var h2 := head + k * ds * 0.5
		p += Vector2(-V8.js_sin(h2), V8.js_cos(h2)) * ds
		head += k * ds
	return { "pts": pts, "s": ss }


## Curvatura (1/m) de la curva sola a s_m de su principio: recta, clotoide de entrada y la curva a la izquierda.
static func _curve_kappa(rd: Dictionary, s_m: float) -> float:
	var k := 1.0 / float(rd.rM)
	var s := s_m - float(rd.leadM)
	if s < 0.0:
		return 0.0
	if s < float(rd.clothoidM):
		return k * s / float(rd.clothoidM)
	return k
