## Semántica numérica de JavaScript en GDScript.
##
## El motor 1.x (JavaScript) es el oráculo del port: los textos del laboratorio y los SVG de las ilustraciones
## tienen que salir idénticos. GDScript redondea y escribe los números de otra forma, así que todo el core usa
## estas funciones en lugar de round(), str() o "%.2f" % x:
## - to_fixed(x, d): Number.prototype.toFixed. En un empate elige el entero mayor; printf redondea al par
##   ("%.2f" % 0.125 da "0.12" y JavaScript "0.13").
## - js_round(x): Math.round. Los empates van hacia +∞; round() de GDScript los aleja del cero (−2,5 → −3).
## - js_num_str(x): String(n), el decimal más corto que se relee igual (0.1 + 0.2 → "0.30000000000000004").
## - log10, log1p, cbrt: los de V8, al bit (v8_math.gd); los de la libm de cada plataforma difieren en el último bit.
## - imul32, u32, ushr, hex2: aritmética de enteros de 32 bits (Math.imul, >>>, toString(16)).
## - truthy, is_true, template_str: la verdad de JavaScript (!!v, v === true) y `${v}` en una plantilla.
##
## Ojo: el lector de números de Godot (String.to_float, JSON.parse, float("…")) no redondea bien los decimales
## largos ("0.9999999999999999" lo lee como 1.0). Por eso aquí nada depende de él: los candidatos se generan
## con un toFixed exacto (producto de Dekker) y el «¿se relee igual?» se comprueba en doble-doble.
## Uso: const Js = preload("res://core/shared/js.gd"), y después Js.to_fixed(x, 1).
extends RefCounted

const V8 = preload("res://core/shared/v8_math.gd")

const _SPLIT := 134217729.0  # 2^27 + 1: partición de Veltkamp para el producto exacto
const _TWO52 := 4503599627370496.0
const _TWO53 := 9007199254740992.0
const _TWO63 := 9223372036854775808.0


## Producto exacto a·b = p + e (Dekker). e es lo que el redondeo de p ha perdido.
static func _two_prod(a: float, b: float) -> PackedFloat64Array:
	var p := a * b
	var c := _SPLIT * a
	var ah := c - (c - a)
	var al := a - ah
	var d := _SPLIT * b
	var bh := d - (d - b)
	var bl := b - bh
	var e := ((ah * bh - p) + ah * bl + al * bh) + al * bl
	return PackedFloat64Array([p, e])


## El entero más cercano a x·10^digits (x ≥ 0), con los empates hacia el mayor, como toFixed.
## Devuelve -1 si x·10^digits no cabe en un entero de 63 bits.
static func _scaled_int(ax: float, digits: int) -> int:
	var pe := _two_prod(ax, pow(10.0, mini(digits, 22)))  # ax·10^d = p + e exactamente (10^d es exacto hasta d = 22)
	var p := pe[0]
	var e := pe[1]
	if digits > 22:  # números muy pequeños: segundo producto exacto; el resto e se escala aparte
		var k := pow(10.0, digits - 22)
		var pe2 := _two_prod(p, k)
		p = pe2[0]
		e = pe2[1] + e * k
	if p >= _TWO63 * 0.5:
		return -1
	if p >= _TWO52:  # p ya es entero: el resto e decide (y puede valer más de 0,5)
		return int(p) + int(floorf(e + 0.5))
	var n := floorf(p)
	var diff := (p - n) - 0.5  # exacto: p − n es un múltiplo de ulp(p)
	return int(n) + (1 if (diff > 0.0 or (diff == 0.0 and e >= 0.0)) else 0)


static func _place_point(s: String, digits: int) -> String:
	if digits <= 0:
		return s
	if s.length() <= digits:
		s = "0".repeat(digits - s.length() + 1) + s
	return s.substr(0, s.length() - digits) + "." + s.substr(s.length() - digits)


## Number.prototype.toFixed(digits), con 0 ≤ digits ≤ 20.
static func to_fixed(x: float, digits: int) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x) or absf(x) >= 1e21:
		return js_num_str(x)
	var neg := x < 0.0  # −0 no cuenta como negativo, igual que en JavaScript
	var ax := -x if neg else x
	var n := _scaled_int(ax, digits)
	var s := _place_point(str(n), digits) if n >= 0 else ("%." + str(digits) + "f") % ax
	return ("-" + s) if neg else s


## Math.round: el entero más cercano; en un empate, hacia +∞.
static func js_round(x: float) -> float:
	if is_nan(x) or is_inf(x):
		return x
	var r := roundf(x)  # empates lejos del cero
	if x - r == 0.5:  # empate negativo: JavaScript sube (−2,5 → −2)
		r += 1.0
	return r


## Bits de un double (entero de 64 bits).
static func _bits(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s64(0)


## Diferencia (m·10^q − ax), calculada en doble-doble (≈106 bits): basta para decidir sin error si el decimal
## m·10^q se lee como el double ax.
static func _dd_diff(m: int, q: int, ax: float) -> float:
	var hi := float(m)
	var lo := float(m - int(hi))  # resto exacto
	if q > 0:
		var p10 := pow(10.0, q)
		var pe := _two_prod(hi, p10)
		hi = pe[0]
		lo = pe[1] + lo * p10
	var k := -q
	while k > 0:  # divisiones en doble-doble por 10^min(k, 22), que es exacto
		var step := mini(k, 22)
		var b := pow(10.0, step)
		var q1 := hi / b
		var t := _two_prod(q1, b)
		var r := ((hi - t[0]) - t[1]) + lo
		var q2 := r / b
		hi = q1 + q2
		lo = q2 - (hi - q1)
		k -= step
	return (hi - ax) + lo


## ¿Un decimal a distancia diff de ax se lee como ax? (redondeo al más cercano, empates al par, como IEEE)
static func _accepts(diff: float, ax: float) -> bool:
	var bits := _bits(ax)
	var biased := (bits >> 52) & 0x7FF
	var mant := bits & 0xFFFFFFFFFFFFF
	var ulp := pow(2.0, maxi(biased, 1) - 1075)
	var half := ulp * 0.5
	if diff < 0.0 and mant == 0 and biased > 1:
		half = ulp * 0.25  # por debajo de una potencia de 2 los doubles están el doble de juntos
	return absf(diff) < half or (absf(diff) == half and (mant & 1) == 0)


## Entre los candidatos m (valor m·10^q) que se leen como ax, el más cercano; si empatan, el par (ECMAScript
## Number::toString). Devuelve -1 si ninguno sirve.
static func _pick(cands: Array, q: int, ax: float) -> int:
	var best := -1
	var best_d := INF
	for m in cands:
		if m <= 0:
			continue
		var diff := _dd_diff(m, q, ax)
		if not _accepts(diff, ax):
			continue
		var ad := absf(diff)
		if ad < best_d or (ad == best_d and m % 2 == 0):
			best = m
			best_d = ad
	return best


## String(n) de JavaScript: el decimal más corto que al leerse da el mismo double.
static func js_num_str(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x):
		return "Infinity" if x > 0.0 else "-Infinity"
	if x == 0.0:
		return "0"  # también −0
	var sign := "-" if x < 0.0 else ""
	var ax := absf(x)
	if ax < _TWO53 and ax == floorf(ax):
		return sign + str(int(ax))
	if ax < 1e9:
		# vía rápida para los valores con pocos decimales (coordenadas redondeadas a 0,01 en art.js): si la
		# división correctamente redondeada k/10^d da ax, ese decimal se relee como ax y es el más corto
		for d in range(1, 4):
			var p10 := pow(10.0, d)
			var k := roundf(ax * p10)
			if k / p10 == ax:
				return sign + _trim_zeros(_place_point(str(int(k)), d))
	var fixed := _shortest(ax)  # [dígitos sin punto, decimales]
	if fixed.is_empty():
		return sign + str(ax)
	var digits: String = fixed[0]
	var dec: int = fixed[1]
	if ax >= 1e-6 and ax < 1e21:
		return sign + _trim_zeros(_place_point(digits, dec))
	# notación exponencial: el valor es digits·10^-dec, y digits no empieza por cero
	var exp10 := digits.length() - 1 - dec
	var sig := digits.rstrip("0")
	var mant := sig.substr(0, 1) + ("." + sig.substr(1) if sig.length() > 1 else "")
	return sign + mant + "e" + ("+" if exp10 >= 0 else "-") + str(absi(exp10))


## El decimal más corto que se lee como ax > 0. Devuelve [dígitos, decimales] o [] si no lo encuentra.
static func _shortest(ax: float) -> Array:
	if ax >= _TWO53:
		# enteros grandes: cifras significativas crecientes (m·10^scale)
		var e10 := int(floor(log(ax) / log(10.0)))
		for p in range(1, 18):
			var scale := e10 - p + 1
			var m := int(roundf(ax / pow(10.0, scale)))
			var best := _pick([m - 1, m, m + 1], scale, ax)
			if best > 0:
				return [str(best) + "0".repeat(scale), 0] if scale >= 0 else [str(best), -scale]
		return []
	# Casi todos los doubles «largos» necesitan 15-17 cifras significativas: se empieza en 15. Que un decimal con d
	# decimales se lea como ax es monótono en d (el más cercano con d + 1 decimales está igual o más cerca), así que
	# si 15 cifras bastan se busca hacia abajo por bisección y, si no, hacia arriba.
	var e10 := int(floor(log(ax) / log(10.0)))  # orden de magnitud (aproximado: la búsqueda lo corrige)
	var d0 := clampi(14 - e10, 0, 44)
	var r0 := _try_d(ax, d0)
	if r0.size() == 1:
		return []  # el entero escalado no cabe en 63 bits
	if r0.is_empty():  # 15 cifras no bastan: 16 o 17
		for d in range(d0 + 1, 45):
			var r := _try_d(ax, d)
			if r.size() == 1:
				return []
			if not r.is_empty():
				return r
		return []
	var lo := 0
	var hi := d0  # con hi decimales siempre vale
	var best := r0
	while lo < hi:
		var mid := (lo + hi) >> 1
		var r := _try_d(ax, mid)
		if r.size() == 2:
			hi = mid
			best = r
		else:
			lo = mid + 1
	return best


## [dígitos, d] si algún decimal con d decimales se lee como ax; [] si ninguno; [0] si ax·10^d no cabe en 63 bits.
static func _try_d(ax: float, d: int) -> Array:
	var n := _scaled_int(ax, d)  # el d-decimal más cercano (empates hacia el mayor)
	if n < 0:
		return [0]
	var best := _pick([n, n - 1], -d, ax)  # n − 1 solo cuenta si empata con n
	return [str(best), d] if best > 0 else []


static func _trim_zeros(s: String) -> String:
	if s.find(".") < 0:
		return s
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## Math.log10, Math.log1p y Math.cbrt de V8, al bit (core/shared/v8_math.gd).
static func log10(x: float) -> float:
	return V8.js_log10(x)


static func log1p(x: float) -> float:
	return V8.js_log1p(x)


static func cbrt(x: float) -> float:
	return V8.js_cbrt(x)


## Math.imul: producto de enteros de 32 bits con signo (sin desbordar el int64 de GDScript).
static func imul32(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	var lo := (a & 0xFFFF) * b
	var hi := ((a >> 16) & 0xFFFF) * b
	var r := (lo + ((hi & 0xFFFF) << 16)) & 0xFFFFFFFF
	return r - 0x100000000 if r >= 0x80000000 else r


## ToUint32: el entero como sin signo de 32 bits (lo que da `x >>> 0`).
static func u32(x: int) -> int:
	return x & 0xFFFFFFFF


## x >>> n de JavaScript. GDScript no admite desplazar negativos, así que primero se pasa a sin signo.
static func ushr(x: int, n: int) -> int:
	return (x & 0xFFFFFFFF) >> n


## n.toString(16).padStart(2, "0") para un canal de color 0–255.
static func hex2(n: int) -> String:
	return "%02x" % n


## Verdad de JavaScript: false para null, false, 0, NaN y ""; true para el resto (objetos y listas vacíos incluidos).
static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return v != ""
	return true


## `x === true` de JavaScript (en el laboratorio, scratched vale true, false o "faint", y "faint" no cuenta).
static func is_true(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and v


## Un valor dentro de una plantilla de JavaScript (`${v}`): String(v) para números y textos; «undefined» para lo que
## falta (null aquí).
static func template_str(v: Variant) -> String:
	if v == null:
		return "undefined"
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return js_num_str(v)
	return str(v)
