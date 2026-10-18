## Tribología biológica · el color de un cuerpo caliente (reforja, unidad 5f): la física del brillo de la pieza, del crisol
## y de la cámara del horno, para que la escena solo lo pinte.
##
## - El color es el de la radiación de cuerpo negro (Planck) a esa temperatura, visto con el observador patrón de la CIE
##   (1931, 2°; el ajuste analítico de Wyman, Sloan y Shirley 2013) y pasado a sRGB con el blanco D65 (IEC 61966-2-1):
##   un cuerpo gris (la emisividad no depende de la longitud de onda) tiene el mismo color; el de verdad cambia algo con su
##   emisividad, que no se modela.
## - El brillo relativo es la luminancia Y de esa radiación frente a la de otra temperatura: crece muchísimo (de ~400 °C,
##   cuando empieza a verse en la oscuridad, a 2500 °C, varios órdenes de magnitud). Lo que pinta la escena es un brillo
##   comprimido en logaritmo (strength, 0-1): eso ya es dibujo, no física.
## - Las palabras del color son las de la tabla V del TM 9-237 (1967), los colores de calor del acero en la forja: lo que
##   ve el herrero (de «rojo tenue» a 399 °C a «blanco» desde 1204 °C).
## La integral sobre el espectro (380-780 nm cada 5 nm) cuesta unas décimas de milisegundo: la escena no la llama en cada
## fotograma, sino que pinta con la rampa (ramp(), una vez) y glow_at() interpola en ella.
## Sin nodos, determinista y sin la libm (v8_math.gd). Unidades: temperatura °C (K por dentro), longitud de onda nm.
## Uso: const Incandescence = preload("res://core/lab/incandescence.gd"); Incandescence.glow(2100.0).color
extends RefCounted

const V8 = preload("res://core/shared/v8_math.gd")
const Js = preload("res://core/shared/js.gd")

const SRC_PLANCK := "Ley de Planck de la radiación del cuerpo negro, con la segunda constante de radiación c₂ = hc/k = 1,438776877·10⁻² m·K (CODATA 2018)"
const SRC_CIE := "Funciones de igualación del color del observador patrón CIE 1931 de 2° (CIE 015:2004), con el ajuste analítico de Wyman C, Sloan P-P, Shirley P (2013), Simple analytic approximations to the CIE XYZ color matching functions, Journal of Computer Graphics Techniques 2(2):1-11"
const SRC_SRGB := "IEC 61966-2-1:1999 (sRGB): matriz de XYZ a RGB lineal con el blanco D65 y la curva de transferencia"
const SRC_TM9237 := "TM 9-237 (1967), apéndice, tabla V «Heat colors with approximate temperature»: los colores de calor del acero en la forja, de 750 °F (399 °C, rojo tenue que se ve en la oscuridad) a 2200 °F (1204 °C, blanco)"
const SRC_DRAPER := "Draper JW (1847). On the production of light by heat. Philosophical Magazine 30:345-360: todos los sólidos empiezan a verse al rojo a la misma temperatura, ~525 °C (el punto de Draper)"
## El color y su fuente, como un dato del motor: la física (Planck y la CIE) es exacta; el ajuste de las funciones de la
## CIE, publicado.
const SOURCE := SRC_PLANCK + "; " + SRC_CIE + "; " + SRC_SRGB
const QUALITY := "primary"

const KELVIN := 273.15
## Segunda constante de radiación (m·K), CODATA 2018.
const C2 := 1.438776877e-2
## Constante de Wien (m·K), CODATA 2018: el máximo de la radiación está en b/T.
const WIEN_B := 2.897771955e-3
## Intervalo y paso de la integral sobre el espectro visible (nm).
const LAMBDA_MIN_NM := 380.0
const LAMBDA_MAX_NM := 780.0
const LAMBDA_STEP_NM := 5.0
## Por debajo de esta temperatura no se ve brillar ni en la oscuridad (TM 9-237, tabla V: 750 °F).
const DARK_C := 399.0
## El punto de Draper: desde aquí se ve al rojo con luz normal.
const DRAPER_C := 525.0
## Temperatura a la que el brillo dibujado llega al máximo (strength = 1): dibujo.
const BRIGHT_C := 2500.0
## Los colores de calor del acero (TM 9-237, tabla V; °F pasados a °C): [desde °C, palabra].
const HEAT_WORDS := [
	[399.0, "rojo tenue (se ve en la oscuridad)"],
	[482.0, "rojo tenue"],
	[566.0, "rojo sangre"],
	[635.0, "cereza oscuro"],
	[677.0, "cereza medio"],
	[746.0, "rojo cereza"],
	[788.0, "cereza brillante"],
	[843.0, "rojo brillante"],
	[899.0, "salmón"],
	[941.0, "naranja"],
	[996.0, "limón"],
	[1079.0, "amarillo claro"],
	[1204.0, "blanco"],
]
## Matriz de XYZ a sRGB lineal (IEC 61966-2-1, D65), por filas.
const XYZ_TO_RGB := [
	[3.2406, -1.5372, -0.4986],
	[-0.9689, 1.8758, 0.0415],
	[0.0557, -0.2040, 1.0570],
]


## Radiancia espectral del cuerpo negro, salvo una constante: 1 / (λ⁵ · (e^(c₂/λT) − 1)), con λ en m.
static func planck_rel(lambda_nm: float, t_k: float) -> float:
	var l := lambda_nm * 1.0e-9
	var x := C2 / (l * t_k)
	if x > 700.0:
		return 0.0
	return 1.0 / (l * l * l * l * l * (V8.js_exp(x) - 1.0))


## Longitud de onda del máximo de la radiación (nm), ley de Wien: b/T.
static func wien_peak_nm(t_k: float) -> float:
	return WIEN_B / t_k * 1.0e9


## Un lóbulo gaussiano con dos anchos (el ajuste de Wyman et al. 2013): e^(−½·((λ − μ)·k)²), k = 1/σ a cada lado.
static func _lobe(lambda_nm: float, mu: float, k_lo: float, k_hi: float) -> float:
	var t := (lambda_nm - mu) * (k_lo if lambda_nm < mu else k_hi)
	return V8.js_exp(-0.5 * t * t)


## Las funciones de igualación del color CIE 1931 (2°) en λ (nm), con el ajuste de varios lóbulos de Wyman et al. (2013).
static func cmf(lambda_nm: float) -> Vector3:
	var x := 0.362 * _lobe(lambda_nm, 442.0, 0.0624, 0.0374) + 1.056 * _lobe(lambda_nm, 599.8, 0.0264, 0.0323) - 0.065 * _lobe(lambda_nm, 501.1, 0.0490, 0.0382)
	var y := 0.821 * _lobe(lambda_nm, 568.8, 0.0213, 0.0247) + 0.286 * _lobe(lambda_nm, 530.9, 0.0613, 0.0322)
	var z := 1.217 * _lobe(lambda_nm, 437.0, 0.0845, 0.0278) + 0.681 * _lobe(lambda_nm, 459.0, 0.0385, 0.0725)
	return Vector3(x, y, z)


## Número de muestras del espectro.
static func samples() -> int:
	return int((LAMBDA_MAX_NM - LAMBDA_MIN_NM) / LAMBDA_STEP_NM + 0.5) + 1


## Las funciones de la CIE en cada muestra, con el peso de los trapecios y el paso ya puestos: [x0, y0, z0, x1, …].
static func cmf_table() -> PackedFloat64Array:
	var n := samples()
	var out := PackedFloat64Array()
	out.resize(3 * n)
	for i in n:
		var c := cmf(LAMBDA_MIN_NM + float(i) * LAMBDA_STEP_NM)
		var w := (0.5 if i == 0 or i == n - 1 else 1.0) * LAMBDA_STEP_NM
		out[3 * i] = c.x * w
		out[3 * i + 1] = c.y * w
		out[3 * i + 2] = c.z * w
	return out


## Triestímulo XYZ de un cuerpo negro a t_c (°C), salvo una constante (la misma para todas las temperaturas), con las
## funciones de la CIE de cmf_table() (si no se da, se calcula).
static func xyz(t_c: float, table: PackedFloat64Array = PackedFloat64Array()) -> Vector3:
	var tb := table if not table.is_empty() else cmf_table()
	var t_k := t_c + KELVIN
	var x := 0.0
	var y := 0.0
	var z := 0.0
	for i in samples():
		var b := planck_rel(LAMBDA_MIN_NM + float(i) * LAMBDA_STEP_NM, t_k)
		x += tb[3 * i] * b
		y += tb[3 * i + 1] * b
		z += tb[3 * i + 2] * b
	return Vector3(x, y, z)


## Curva de transferencia de sRGB (de lineal a codificado).
static func srgb_encode(v: float) -> float:
	if v <= 0.0031308:
		return 12.92 * maxf(v, 0.0)
	return 1.055 * V8.js_pow(v, 1.0 / 2.4) - 0.055


## El color sRGB (codificado, con el canal mayor a 1) de un triestímulo. Lo que se sale de la gama de sRGB (el azul de las
## temperaturas bajas) se recorta a 0.
static func color_of(v: Vector3) -> Color:
	var rgb := PackedFloat64Array([0.0, 0.0, 0.0])
	for i in 3:
		var row: Array = XYZ_TO_RGB[i]
		rgb[i] = maxf(float(row[0]) * v.x + float(row[1]) * v.y + float(row[2]) * v.z, 0.0)
	var top := maxf(rgb[0], maxf(rgb[1], rgb[2]))
	if top <= 0.0:
		return Color(0.0, 0.0, 0.0)
	return Color(srgb_encode(rgb[0] / top), srgb_encode(rgb[1] / top), srgb_encode(rgb[2] / top))


## Color de un cuerpo caliente a t_c (°C), en sRGB codificado y con el canal mayor a 1 (el brillo va aparte).
static func color(t_c: float) -> Color:
	return color_of(xyz(t_c))


## Luminancia de la radiación a t_c frente a la de ref_c (Y(T)/Y(ref)).
static func luminance_rel(t_c: float, ref_c: float = DRAPER_C) -> float:
	var tb := cmf_table()
	var y0 := xyz(ref_c, tb).y
	return xyz(t_c, tb).y / y0 if y0 > 0.0 else 0.0


## Brillo para dibujar (0-1) de una luminancia y, con y_dark la de DARK_C y top el logaritmo de la de BRIGHT_C frente a
## ella: el logaritmo de la luminancia entre las dos. Dibujo.
static func _strength_of(y: float, y_dark: float, top: float) -> float:
	if y <= y_dark or top <= 0.0:
		return 0.0
	return clampf(V8.js_log10(y / y_dark) / top, 0.0, 1.0)


## Brillo para dibujar (0-1): el logaritmo de la luminancia entre DARK_C (0) y BRIGHT_C (1). Dibujo.
static func strength(t_c: float) -> float:
	if t_c <= DARK_C:
		return 0.0
	var tb := cmf_table()
	var y0 := xyz(DARK_C, tb).y
	return _strength_of(xyz(t_c, tb).y, y0, V8.js_log10(xyz(BRIGHT_C, tb).y / y0))


## La palabra del color de calor a t_c (TM 9-237, tabla V) o «» si aún no se ve brillar.
static func word(t_c: float) -> String:
	var out := ""
	for row: Array in HEAT_WORDS:
		if t_c >= float(row[0]):
			out = String(row[1])
	return out


## Todo lo del brillo a t_c: { tempC, kelvin, color (sRGB), hex, strength (dibujo), visible (desde el punto de Draper),
## glowsInDark (desde DARK_C), word (TM 9-237), peakNm (Wien), source, quality, wordSource, visibleSource,
## strengthQuality }. Cuesta una integral: para pintar, glow_at() con la rampa.
static func glow(t_c: float) -> Dictionary:
	var tb := cmf_table()
	var v := xyz(t_c, tb)
	var y0 := xyz(DARK_C, tb).y
	var c := color_of(v)
	return {
		"tempC": t_c, "kelvin": t_c + KELVIN, "color": c, "hex": "#" + c.to_html(false),
		"strength": _strength_of(v.y, y0, V8.js_log10(xyz(BRIGHT_C, tb).y / y0)) if t_c > DARK_C else 0.0,
		"visible": t_c >= DRAPER_C, "glowsInDark": t_c > DARK_C, "word": word(t_c), "peakNm": wien_peak_nm(t_c + KELVIN),
		"source": SOURCE, "quality": QUALITY, "wordSource": SRC_TM9237, "visibleSource": SRC_DRAPER, "strengthQuality": "dibujo",
	}


## La rampa para pintar: [[°C, Color, strength], …] de t0 a t1 cada step °C (una integral por fila).
static func ramp(t0: float = 350.0, t1: float = 3000.0, step: float = 25.0) -> Array:
	var out: Array = []
	var tb := cmf_table()
	var y0 := xyz(DARK_C, tb).y
	var top := V8.js_log10(xyz(BRIGHT_C, tb).y / y0)
	var t := t0
	while t <= t1 + 1e-9:
		var v := xyz(t, tb)
		out.append([t, color_of(v), _strength_of(v.y, y0, top) if t > DARK_C else 0.0])
		t += step
	return out


## El brillo a t_c interpolado en una rampa (ramp()): { color, strength }. Negro y 0 por debajo de la primera fila.
static func glow_at(rows: Array, t_c: float) -> Dictionary:
	if rows.is_empty() or t_c <= float(rows[0][0]):
		return { "color": Color(0.0, 0.0, 0.0), "strength": 0.0 }
	var last: Array = rows[rows.size() - 1]
	if t_c >= float(last[0]):
		return { "color": last[1], "strength": float(last[2]) }
	var step := float(rows[1][0]) - float(rows[0][0])
	var i := clampi(int(floor((t_c - float(rows[0][0])) / step)), 0, rows.size() - 2)
	var a: Array = rows[i]
	var b: Array = rows[i + 1]
	var k := (t_c - float(a[0])) / (float(b[0]) - float(a[0]))
	var ca: Color = a[1]
	var cb: Color = b[1]
	return {
		"color": Color(ca.r + (cb.r - ca.r) * k, ca.g + (cb.g - ca.g) * k, ca.b + (cb.b - ca.b) * k),
		"strength": float(a[2]) + (float(b[2]) - float(a[2])) * k,
	}


## Texto del brillo para las lecturas: «blanco · 2373 K» (la palabra del TM 9-237 y la temperatura absoluta) o «no brilla».
static func glow_text(t_c: float) -> String:
	var w := word(t_c)
	if w == "":
		return "no brilla (por debajo de %s °C)" % Js.to_fixed(DARK_C, 0)
	return "%s · %s K" % [w, Js.to_fixed(t_c + KELVIN, 0)]
