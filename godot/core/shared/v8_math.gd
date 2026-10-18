## Math.sin, cos, tan, atan2, exp, pow, log, log1p, log10 y cbrt tal como los calcula V8 12.4, el de Node 22 que
## exporta el oráculo (src/base/ieee754.cc, derivado de fdlibm 5.3), al bit.
##
## Las usan los dibujos del laboratorio (art.gd) y toda la física del laboratorio y de la capa compartida (physics.gd,
## contact.gd, format.gd, y js.gd): las garras escriben coordenadas sin redondear, la severidad de una huella sale de
## log1p y la punta de sin, cos y tan; la libm de cada plataforma difiere de V8 en el último bit en un 3-18 % de los
## casos, así que sin esto el SVG no saldría idéntico al del oráculo y la física no daría lo mismo, bit a bit, en
## Windows, macOS, Linux, Android e iOS (tests/shared/test_v8_math.gd lo vigila). Están en la capa compartida porque
## son semántica de JavaScript, como js.gd.
## pow no es el de fdlibm: V8 divide por (t1 − 2) − (w + z·w) donde fdlibm resta fuera de la división. Las constantes
## se construyen desde sus bits porque el lector de literales de Godot no redondea bien los decimales largos. La
## reducción de argumentos cubre |x| < 2^19·π/2; más allá se usa la libm de la plataforma.
## Uso: const V8 = preload("res://core/shared/v8_math.gd"), y después V8.js_sin(x).
extends RefCounted

static var _S1: float = -_fb(0x3FC5555555555549)
static var _S2: float = _fb(0x3F8111111110F8A6)
static var _S3: float = -_fb(0x3F2A01A019C161D5)
static var _S4: float = _fb(0x3EC71DE357B1FE7D)
static var _S5: float = -_fb(0x3E5AE5E68A2B9CEB)
static var _S6: float = _fb(0x3DE5D93A5ACFD57C)
static var _C1: float = _fb(0x3FA555555555554C)
static var _C2: float = -_fb(0x3F56C16C16C15177)
static var _C3: float = _fb(0x3EFA01A019CB1590)
static var _C4: float = -_fb(0x3E927E4F809C52AD)
static var _C5: float = _fb(0x3E21EE9EBDB4B1C4)
static var _C6: float = -_fb(0x3DA8FAE9BE8838D4)
static var _INVPIO2: float = _fb(0x3FE45F306DC9C883)
static var _PIO2_1: float = _fb(0x3FF921FB54400000)
static var _PIO2_1T: float = _fb(0x3DD0B4611A626331)
static var _PIO2_2: float = _fb(0x3DD0B4611A600000)
static var _PIO2_2T: float = _fb(0x3BA3198A2E037073)
static var _PIO2_3: float = _fb(0x3BA3198A2E000000)
static var _PIO2_3T: float = _fb(0x397B839A252049C1)
static var _PI_O_4: float = _fb(0x3FE921FB54442D18)
static var _PI_O_2: float = _fb(0x3FF921FB54442D18)
static var _PI_LO: float = _fb(0x3CA1A62633145C07)
static var _TINY: float = _fb(0x01A56E1FC2F8F359)  # 1e-300
static var _HUGE: float = _fb(0x7E37E43C8800759C)  # 1e300
static var _PIO4: float = _fb(0x3FE921FB54442D18)
static var _PIO4LO: float = _fb(0x3C81A62633145C07)
static var _DP_H1: float = _fb(0x3FE2B80340000000)
static var _DP_L1: float = _fb(0x3E4CFDEB43CFD006)
static var _L1: float = _fb(0x3FE3333333333303)
static var _L2: float = _fb(0x3FDB6DB6DB6FABFF)
static var _L3: float = _fb(0x3FD55555518F264D)
static var _L4: float = _fb(0x3FD17460A91D4101)
static var _L5: float = _fb(0x3FCD864A93C9DB65)
static var _L6: float = _fb(0x3FCA7E284A454EEF)
static var _P1: float = _fb(0x3FC555555555553E)
static var _P2: float = -_fb(0x3F66C16C16BEBD93)
static var _P3: float = _fb(0x3F11566AAF25DE2C)
static var _P4: float = -_fb(0x3EBBBD41C5D26BF1)
static var _P5: float = _fb(0x3E66376972BEA4D0)
static var _LG2: float = _fb(0x3FE62E42FEFA39EF)
static var _LG2_H: float = _fb(0x3FE62E4300000000)
static var _LG2_L: float = -_fb(0x3E205C610CA86C39)
static var _OVT: float = _fb(0x3C971547652B82FE)
static var _CP: float = _fb(0x3FEEC709DC3A03FD)
static var _CP_H: float = _fb(0x3FEEC709E0000000)
static var _CP_L: float = -_fb(0x3E3E2FE0145B01F5)
static var _IVLN2: float = _fb(0x3FF71547652B82FE)
static var _IVLN2_H: float = _fb(0x3FF7154760000000)
static var _IVLN2_L: float = _fb(0x3E54AE0BF85DDF44)
static var _THIRD: float = _fb(0x3FD5555555555555)
static var _T: PackedFloat64Array = _fba([
	0x3FD5555555555563, 0x3FC111111110FE7A, 0x3FABA1BA1BB341FE, 0x3F9664F48406D637, 0x3F8226E3E96E8493, 0x3F6D6D22C9560328,
	0x3F57DBC8FEE08315, 0x3F4344D8F2F26501, 0x3F3026F71A8D1068, 0x3F147E88A03792A6, 0x3F12B80F32F0A7E9, -0x3EF375CBDB605373,
	0x3EFB2A7074BF7AD4])
static var _ATANHI: PackedFloat64Array = _fba([0x3FDDAC670561BB4F, 0x3FE921FB54442D18, 0x3FEF730BD281F69B, 0x3FF921FB54442D18])
static var _ATANLO: PackedFloat64Array = _fba([0x3C7A2B7F222F65E2, 0x3C81A62633145C07, 0x3C7007887AF0CBBD, 0x3C91A62633145C07])
static var _AT: PackedFloat64Array = _fba([
	0x3FD555555555550D, -0x3FC999999998EBC4, 0x3FC24924920083FF, -0x3FBC71C6FE231671, 0x3FB745CDC54C206E,
	-0x3FB3B0F2AF749A6D, 0x3FB10D66A0D03D51, -0x3FADDE2D52DEFD9A, 0x3FA97B4B24760DEB, -0x3FA2B4442C6A6C2F,
	0x3F90AD3AE322DA11])
## Palabras altas de n·π/2 (n = 1…32): si |x| cae en una de ellas, la reducción rápida pierde bits.
const _NPIO2_HW := [
	0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C, 0x4025FDBB, 0x402921FB, 0x402C463A, 0x402F6A7A,
	0x4031475C, 0x4032D97C, 0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB, 0x403AB41B, 0x403C463A, 0x403DD85A, 0x403F6A7A,
	0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C, 0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB,
	0x404858EB, 0x404921FB,
]
const _TWO_M27 := 1.0 / 134217728.0  # 2^-27
const _TWO_M28 := 1.0 / 268435456.0  # 2^-28
const _TWO53 := 9007199254740992.0


## Double a partir de sus 64 bits (bits ≥ 0).
static func _fb(bits: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, bits)
	return b.decode_double(0)


## Lista de doubles desde sus bits; un valor negativo es −double(|bits|).
static func _fba(list: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for v: int in list:
		out.append(-_fb(-v) if v < 0 else _fb(v))
	return out


## GET_HIGH_WORD: palabra alta con signo (32 bits).
static func _hi(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s32(4)


## GET_LOW_WORD: palabra baja sin signo.
static func _lo(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_u32(0)


## INSERT_WORDS(hi, lo).
static func _words(hi: int, lo: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(0, lo & 0xFFFFFFFF)
	b.encode_u32(4, hi & 0xFFFFFFFF)
	return b.decode_double(0)


## SET_LOW_WORD(x, 0): los 32 bits bajos a cero.
static func _lo0(x: float) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	b.encode_u32(0, 0)
	return b.decode_double(0)


## SET_HIGH_WORD(x, hi): cambia la palabra alta y conserva la baja.
static func _set_hi(x: float, hi: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	b.encode_u32(4, hi & 0xFFFFFFFF)
	return b.decode_double(0)


## x·2^n con un solo redondeo (scalbn).
static func _scalbn(x: float, n: int) -> float:
	if n < -1000:
		return (x * _words(0x3FF - 1000 << 20, 0)) * _scalbn(1.0, n + 1000)
	if n > 1000:
		return (x * _words(0x3FF + 1000 << 20, 0)) * _scalbn(1.0, n - 1000)
	return x * _words((0x3FF + n) << 20, 0)


## __kernel_sin: seno en [−π/4, π/4]; y es la cola de x.
static func _k_sin(x: float, y: float, iy: int) -> float:
	if absf(x) < _TWO_M27:
		return x
	var z := x * x
	var v := z * x
	var r := _S2 + z * (_S3 + z * (_S4 + z * (_S5 + z * _S6)))
	if iy == 0:
		return x + v * (_S1 + z * r)
	return x - ((z * (0.5 * y - v * r) - y) - v * _S1)


## __kernel_cos: coseno en [−π/4, π/4].
static func _k_cos(x: float, y: float) -> float:
	var ix := _hi(x) & 0x7FFFFFFF
	if ix < 0x3E400000:
		return 1.0
	var z := x * x
	var r := z * (_C1 + z * (_C2 + z * (_C3 + z * (_C4 + z * (_C5 + z * _C6)))))
	if ix < 0x3FD33333:
		return 1.0 - (0.5 * z - (z * r - x * y))
	var qx := 0.28125 if ix > 0x3FE90000 else _words(ix - 0x00200000, 0)
	var hz := 0.5 * z - qx
	var a := 1.0 - qx
	return a - (hz - (z * r - x * y))


## __ieee754_rem_pio2 (caso medio): [n, y0, y1] con x = n·π/2 + y0 + y1 y |y0 + y1| ≤ π/4.
static func _rem_pio2(x: float) -> PackedFloat64Array:
	var hx := _hi(x)
	var ix := hx & 0x7FFFFFFF
	var z := 0.0
	var y0 := 0.0
	var y1 := 0.0
	if ix < 0x4002D97C:  # |x| < 3π/4: n = ±1
		if hx > 0:
			z = x - _PIO2_1
			if ix != 0x3FF921FB:  # 33 + 53 bits de π bastan
				y0 = z - _PIO2_1T
				y1 = (z - y0) - _PIO2_1T
			else:  # cerca de π/2: 33 + 33 + 53 bits
				z -= _PIO2_2
				y0 = z - _PIO2_2T
				y1 = (z - y0) - _PIO2_2T
			return PackedFloat64Array([1.0, y0, y1])
		z = x + _PIO2_1
		if ix != 0x3FF921FB:
			y0 = z + _PIO2_1T
			y1 = (z - y0) + _PIO2_1T
		else:
			z += _PIO2_2
			y0 = z + _PIO2_2T
			y1 = (z - y0) + _PIO2_2T
		return PackedFloat64Array([-1.0, y0, y1])
	var t := absf(x)
	var n := int(t * _INVPIO2 + 0.5)
	var fn := float(n)
	var r := t - fn * _PIO2_1
	var w := fn * _PIO2_1T  # primera vuelta, buena hasta 85 bits
	if n < 32 and ix != _NPIO2_HW[n - 1]:
		y0 = r - w  # sin cancelación
	else:
		var j := ix >> 20
		y0 = r - w
		var i := j - ((_hi(y0) & 0x7FFFFFFF) >> 20)
		if i > 16:  # segunda vuelta, buena hasta 118 bits
			t = r
			w = fn * _PIO2_2
			r = t - w
			w = fn * _PIO2_2T - ((t - r) - w)
			y0 = r - w
			i = j - ((_hi(y0) & 0x7FFFFFFF) >> 20)
			if i > 49:  # tercera vuelta, 151 bits
				t = r
				w = fn * _PIO2_3
				r = t - w
				w = fn * _PIO2_3T - ((t - r) - w)
				y0 = r - w
	y1 = (r - y0) - w
	if hx < 0:
		return PackedFloat64Array([-fn, -y0, -y1])
	return PackedFloat64Array([fn, y0, y1])


## Math.sin de V8.
static func js_sin(x: float) -> float:
	var ix := _hi(x) & 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _k_sin(x, 0.0, 0)
	if ix >= 0x7FF00000:
		return x - x  # NaN
	if ix > 0x413921FB:
		return sin(x)
	var y := _rem_pio2(x)
	match int(y[0]) & 3:
		0:
			return _k_sin(y[1], y[2], 1)
		1:
			return _k_cos(y[1], y[2])
		2:
			return -_k_sin(y[1], y[2], 1)
	return -_k_cos(y[1], y[2])


## Math.cos de V8.
static func js_cos(x: float) -> float:
	var ix := _hi(x) & 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _k_cos(x, 0.0)
	if ix >= 0x7FF00000:
		return x - x
	if ix > 0x413921FB:
		return cos(x)
	var y := _rem_pio2(x)
	match int(y[0]) & 3:
		0:
			return _k_cos(y[1], y[2])
		1:
			return -_k_sin(y[1], y[2], 1)
		2:
			return -_k_cos(y[1], y[2])
	return _k_sin(y[1], y[2], 1)


## __kernel_tan: tangente (iy = 1) o −1/tangente (iy = −1) en [−π/4, π/4].
static func _k_tan(x: float, y: float, iy: int) -> float:
	var hx := _hi(x)
	var ix := hx & 0x7FFFFFFF
	var z := 0.0
	var w := 0.0
	var v := 0.0
	var s := 0.0
	var a := 0.0
	var t := 0.0
	if ix < 0x3E300000:  # |x| < 2^-28
		if ((ix | _lo(x)) | (iy + 1)) == 0:
			return 1.0 / absf(x)
		if iy == 1:
			return x
		w = x + y  # −1/(x + y) con cuidado
		z = _lo0(w)
		v = y - (z - x)
		a = -1.0 / w
		t = _lo0(a)
		s = 1.0 + t * z
		return t + a * (s + t * v)
	if ix >= 0x3FE59428:  # |x| ≥ 0,6744
		if hx < 0:
			x = -x
			y = -y
		z = _PIO4 - x
		w = _PIO4LO - y
		x = z + w
		y = 0.0
	z = x * x
	w = z * z
	var r := _T[1] + w * (_T[3] + w * (_T[5] + w * (_T[7] + w * (_T[9] + w * _T[11]))))
	v = z * (_T[2] + w * (_T[4] + w * (_T[6] + w * (_T[8] + w * (_T[10] + w * _T[12])))))
	s = z * x
	r = y + z * (s * (r + v) + y)
	r += _T[0] * s
	w = x + r
	if ix >= 0x3FE59428:
		v = float(iy)
		return (-1.0 if hx < 0 else 1.0) * (v - 2.0 * (x - (w * w / (w + v) - r)))
	if iy == 1:
		return w
	z = _lo0(w)  # −1/(x + r) con precisión
	v = r - (z - x)
	a = -1.0 / w
	t = _lo0(a)
	s = 1.0 + t * z
	return t + a * (s + t * v)


## Math.tan de V8.
static func js_tan(x: float) -> float:
	var ix := _hi(x) & 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _k_tan(x, 0.0, 1)
	if ix >= 0x7FF00000:
		return x - x
	if ix > 0x413921FB:
		return tan(x)
	var y := _rem_pio2(x)
	return _k_tan(y[1], y[2], 1 - ((int(y[0]) & 1) << 1))


static func _atan(x: float) -> float:
	var hx := _hi(x)
	var ix := hx & 0x7FFFFFFF
	var id := -1
	if ix >= 0x44100000:  # |x| ≥ 2^66
		if is_nan(x):
			return x + x
		return _ATANHI[3] + _ATANLO[3] if hx > 0 else -_ATANHI[3] - _ATANLO[3]
	if ix < 0x3FDC0000:  # |x| < 0,4375
		if ix < 0x3E400000:  # |x| < 2^-27
			return x
	else:
		x = absf(x)
		if ix < 0x3FF30000:  # |x| < 1,1875
			if ix < 0x3FE60000:  # 7/16 ≤ |x| < 11/16
				id = 0
				x = (2.0 * x - 1.0) / (2.0 + x)
			else:  # 11/16 ≤ |x| < 19/16
				id = 1
				x = (x - 1.0) / (x + 1.0)
		elif ix < 0x40038000:  # |x| < 2,4375
			id = 2
			x = (x - 1.5) / (1.0 + 1.5 * x)
		else:  # 2,4375 ≤ |x| < 2^66
			id = 3
			x = -1.0 / x
	var z := x * x
	var w := z * z
	var s1 := z * (_AT[0] + w * (_AT[2] + w * (_AT[4] + w * (_AT[6] + w * (_AT[8] + w * _AT[10])))))
	var s2 := w * (_AT[1] + w * (_AT[3] + w * (_AT[5] + w * (_AT[7] + w * _AT[9]))))
	if id < 0:
		return x - x * (s1 + s2)
	z = _ATANHI[id] - ((x * (s1 + s2) - _ATANLO[id]) - x)
	return -z if hx < 0 else z


## Math.atan2 de V8.
static func js_atan2(y: float, x: float) -> float:
	if is_nan(x) or is_nan(y):
		return x + y
	var hx := _hi(x)
	var ix := hx & 0x7FFFFFFF
	var lx := _lo(x)
	var hy := _hi(y)
	var iy := hy & 0x7FFFFFFF
	var ly := _lo(y)
	if hx == 0x3FF00000 and lx == 0:  # x = 1
		return _atan(y)
	var m := (1 if hy < 0 else 0) | (2 if hx < 0 else 0)  # 2·signo(x) + signo(y)
	if (iy | ly) == 0:  # y = 0
		match m:
			0, 1:
				return y
			2:
				return PI + _TINY
		return -PI - _TINY
	if (ix | lx) == 0:  # x = 0
		return -_PI_O_2 - _TINY if hy < 0 else _PI_O_2 + _TINY
	if ix == 0x7FF00000:  # x infinito
		if iy == 0x7FF00000:
			match m:
				0:
					return _PI_O_4 + _TINY
				1:
					return -_PI_O_4 - _TINY
				2:
					return 3.0 * _PI_O_4 + _TINY
			return -3.0 * _PI_O_4 - _TINY
		match m:
			0:
				return 0.0
			1:
				return -0.0
			2:
				return PI + _TINY
		return -PI - _TINY
	if iy == 0x7FF00000:  # y infinito
		return -_PI_O_2 - _TINY if hy < 0 else _PI_O_2 + _TINY
	var k := floori((iy - ix) / 1048576.0)  # (iy − ix) >> 20, desplazamiento aritmético
	var z := 0.0
	if k > 60:  # |y/x| > 2^60
		z = _PI_O_2 + 0.5 * _PI_LO
		m &= 1
	elif hx < 0 and k < -60:  # 0 > |y|/x > −2^-60
		z = 0.0
	else:
		z = _atan(absf(y / x))
	match m:
		0:
			return z
		1:
			return -z
		2:
			return PI - (z - _PI_LO)
	return (z - _PI_LO) - PI


## Math.pow de V8 (y el operador **). Las palabras de los doubles se leen y escriben con un solo búfer b (en GDScript,
## crear uno en cada _hi, _lo0 o _set_hi es lo que más cuesta): mismas operaciones que _hi, _lo, _lo0, _words y _set_hi.
static func js_pow(x: float, y: float) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	var hx := b.decode_s32(4)
	var lx := b.decode_u32(0)
	b.encode_double(0, y)
	var hy := b.decode_s32(4)
	var ly := b.decode_u32(0)
	var ix := hx & 0x7FFFFFFF
	var iy := hy & 0x7FFFFFFF
	var z := 0.0
	var ax := 0.0
	var t := 0.0
	var t1 := 0.0
	var t2 := 0.0
	var u := 0.0
	var v := 0.0
	var w := 0.0
	var j := 0
	var k := 0
	if (iy | ly) == 0:  # x**0 = 1
		return 1.0
	if is_nan(x) or is_nan(y):
		return x + y
	# yisint = 0: y no es entero · 1: impar · 2: par (solo importa si x < 0)
	var yisint := 0
	if hx < 0:
		if iy >= 0x43400000:
			yisint = 2
		elif iy >= 0x3FF00000:
			k = (iy >> 20) - 0x3FF
			if k > 20:
				j = ly >> (52 - k)
				if (j << (52 - k)) == ly:
					yisint = 2 - (j & 1)
			elif ly == 0:
				j = iy >> (20 - k)
				if (j << (20 - k)) == iy:
					yisint = 2 - (j & 1)
	if ly == 0:  # valores especiales de y
		if iy == 0x7FF00000:  # y = ±∞
			if ((ix - 0x3FF00000) | lx) == 0:
				return y - y  # (±1)**±∞ = NaN
			if ix >= 0x3FF00000:
				return y if hy >= 0 else 0.0
			return -y if hy < 0 else 0.0
		if iy == 0x3FF00000:  # y = ±1
			return 1.0 / x if hy < 0 else x
		if hy == 0x40000000:  # y = 2
			return x * x
		if hy == 0x3FE00000 and hx >= 0:  # y = 0,5
			return sqrt(x)
	ax = absf(x)
	if lx == 0 and (ix == 0x7FF00000 or ix == 0 or ix == 0x3FF00000):  # x = ±0, ±∞, ±1
		z = ax
		if hy < 0:
			z = 1.0 / z
		if hx < 0:
			if ((ix - 0x3FF00000) | yisint) == 0:
				z = NAN  # (−1)**no entero
			elif yisint == 1:
				z = -z
		return z
	var n := 0 if hx < 0 else 1  # (hx >> 31) + 1
	if (n | yisint) == 0:  # (x < 0)**no entero
		return NAN
	var s := 1.0  # signo del resultado
	if (n | (yisint - 1)) == 0:
		s = -1.0
	if iy > 0x41E00000:  # |y| > 2^31
		if iy > 0x43F00000:  # |y| > 2^64: desborda seguro
			if ix <= 0x3FEFFFFF:
				return _HUGE * _HUGE if hy < 0 else _TINY * _TINY
			if ix >= 0x3FF00000:
				return _HUGE * _HUGE if hy > 0 else _TINY * _TINY
		if ix < 0x3FEFFFFF:
			return s * _HUGE * _HUGE if hy < 0 else s * _TINY * _TINY
		if ix > 0x3FF00000:
			return s * _HUGE * _HUGE if hy > 0 else s * _TINY * _TINY
		t = ax - 1.0  # |1 − x| ≤ 2^-20: log(x) por su serie
		w = (t * t) * (0.5 - t * (_THIRD - t * 0.25))
		u = _IVLN2_H * t
		v = t * _IVLN2_L - w * _IVLN2
		b.encode_double(0, u + v)  # t1 = _lo0(u + v)
		b.encode_u32(0, 0)
		t1 = b.decode_double(0)
		t2 = v - (t1 - u)
	else:
		n = 0
		if ix < 0x00100000:  # subnormal
			ax *= _TWO53
			n -= 53
			b.encode_double(0, ax)  # ix = _hi(ax)
			ix = b.decode_s32(4)
		n += (ix >> 20) - 0x3FF
		j = ix & 0x000FFFFF
		ix = j | 0x3FF00000  # normaliza ix
		if j <= 0x3988E:  # |x| < √(3/2)
			k = 0
		elif j < 0xBB67A:  # |x| < √3
			k = 1
		else:
			k = 0
			n += 1
			ix -= 0x00100000
		b.encode_double(0, ax)  # ax = _set_hi(ax, ix)
		b.encode_u32(4, ix & 0xFFFFFFFF)
		ax = b.decode_double(0)
		var bp := 1.5 if k == 1 else 1.0
		var dp_h := _DP_H1 if k == 1 else 0.0
		var dp_l := _DP_L1 if k == 1 else 0.0
		# ss = s_h + s_l = (x − 1)/(x + 1) o (x − 1,5)/(x + 1,5)
		u = ax - bp
		v = 1.0 / (ax + bp)
		var ss := u * v
		b.encode_double(0, ss)  # s_h = _lo0(ss)
		b.encode_u32(0, 0)
		var s_h := b.decode_double(0)
		b.encode_u32(4, (((ix >> 1) | 0x20000000) + 0x00080000 + (k << 18)) & 0xFFFFFFFF)  # t_h: parte alta de ax + bp
		var t_h := b.decode_double(0)
		var t_l := ax - (t_h - bp)
		var s_l := v * ((u - s_h * t_h) - s_h * t_l)
		# log(ax)
		var s2 := ss * ss
		var r := s2 * s2 * (_L1 + s2 * (_L2 + s2 * (_L3 + s2 * (_L4 + s2 * (_L5 + s2 * _L6)))))
		r += s_l * (s_h + ss)
		s2 = s_h * s_h
		b.encode_double(0, 3.0 + s2 + r)  # t_h = _lo0(3 + s2 + r)
		b.encode_u32(0, 0)
		t_h = b.decode_double(0)
		t_l = r - ((t_h - 3.0) - s2)
		u = s_h * t_h  # u + v = ss·(1 + …)
		v = s_l * t_h + t_l * ss
		b.encode_double(0, u + v)  # p_h = _lo0(u + v): 2/(3·log 2)·(ss + …)
		b.encode_u32(0, 0)
		var p_h := b.decode_double(0)
		var p_l := v - (p_h - u)
		var z_h := _CP_H * p_h
		var z_l := _CP_L * p_h + p_l * _CP + dp_l
		t = float(n)  # log2(ax) = (ss + …)·2/(3·log 2) = n + dp_h + z_h + z_l
		b.encode_double(0, ((z_h + z_l) + dp_h) + t)  # t1 = _lo0(…)
		b.encode_u32(0, 0)
		t1 = b.decode_double(0)
		t2 = z_l - (((t1 - t) - dp_h) - z_h)
	# (y1 + y2)·(t1 + t2), con y partido en y1 + y2
	b.encode_double(0, y)  # y1 = _lo0(y)
	b.encode_u32(0, 0)
	var y1 := b.decode_double(0)
	var pl := (y - y1) * t1 + y * t2
	var ph := y1 * t1
	z = pl + ph
	b.encode_double(0, z)
	j = b.decode_s32(4)
	var i := b.decode_u32(0)
	if j >= 0x40900000:  # z ≥ 1024
		if j != 0x40900000 or i != 0:
			return s * _HUGE * _HUGE  # desborda
		if pl + _OVT > z - ph:
			return s * _HUGE * _HUGE
	elif (j & 0x7FFFFFFF) >= 0x4090CC00:  # z ≤ −1075
		if j != -0x3F6F3400 or i != 0:  # 0xC090CC00 como entero con signo
			return s * _TINY * _TINY  # subdesborda
		if pl <= z - ph:
			return s * _TINY * _TINY
	# 2**(ph + pl)
	i = j & 0x7FFFFFFF
	k = (i >> 20) - 0x3FF
	n = 0
	if i > 0x3FE00000:  # |z| > 0,5: n = [z + 0,5]
		n = j + (0x00100000 >> (k + 1))
		k = ((n & 0x7FFFFFFF) >> 20) - 0x3FF  # nuevo k para n
		b.encode_u32(0, 0)  # t = _words(n & ~(0x000FFFFF >> k), 0)
		b.encode_u32(4, (n & ~(0x000FFFFF >> k)) & 0xFFFFFFFF)
		t = b.decode_double(0)
		n = ((n & 0x000FFFFF) | 0x00100000) >> (20 - k)
		if j < 0:
			n = -n
		ph -= t
	b.encode_double(0, pl + ph)  # t = _lo0(pl + ph)
	b.encode_u32(0, 0)
	t = b.decode_double(0)
	u = t * _LG2_H
	v = (pl - (t - ph)) * _LG2 + t * _LG2_L
	z = u + v
	w = v - (z - u)
	t = z * z
	t1 = z - t * (_P1 + t * (_P2 + t * (_P3 + t * (_P4 + t * _P5))))
	var rr := (z * t1) / ((t1 - 2.0) - (w + z * w))  # así en V8 (fdlibm: z·t1/(t1 − 2) − (w + z·w))
	z = 1.0 - (rr - z)
	b.encode_double(0, z)
	j = b.decode_s32(4) + n * 1048576  # _hi(z) + (n << 20)
	if j < 0x00100000:
		z = _scalbn(z, n)  # resultado subnormal
	else:
		b.encode_u32(4, j & 0xFFFFFFFF)  # z = _set_hi(z, j): b aún tiene z
		z = b.decode_double(0)
	return s * z


# ── Exponencial (ieee754.cc de V8 12.4: exp) ──

static var _EXP_O_THRESHOLD: float = _fb(0x40862E42FEFA39EF)  # 709,78…: por encima, desborda
static var _EXP_U_THRESHOLD: float = -_fb(0x40874910D52D3051)  # −745,13…: por debajo, subdesborda
static var _EXP_E: float = _fb(0x4005BF0A8B145769)  # e: exp(1) es un caso aparte en V8
static var _TWOM1000: float = _fb(0x0170000000000000)  # 2^-1000
static var _TWO1023: float = _fb(0x7FE0000000000000)  # 2^1023


## Math.exp. Reduce x = k·ln 2 + r con |r| ≤ ln 2 / 2 y aproxima exp(r) con el polinomio P1…P5 (los mismos que pow).
## Un solo búfer b para las palabras de los doubles (como en js_pow).
static func js_exp(x: float) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	var hx := b.decode_s32(4)
	var xsb := 1 if hx < 0 else 0  # signo de x
	hx &= 0x7FFFFFFF  # palabra alta de |x|
	var k := 0
	var hi := 0.0
	var lo := 0.0
	if hx >= 0x40862E42:  # |x| ≥ 709,78…
		if hx >= 0x7FF00000:
			if ((hx & 0xFFFFF) | b.decode_u32(0)) != 0:
				return x + x  # NaN
			return x if xsb == 0 else 0.0  # exp(+∞) = +∞, exp(−∞) = 0
		if x > _EXP_O_THRESHOLD:
			return _HUGE * _HUGE  # desborda
		if x < _EXP_U_THRESHOLD:
			return _TWOM1000 * _TWOM1000  # subdesborda
	if hx > 0x3FD62E42:  # |x| > 0,5·ln 2
		if hx < 0x3FF0A2B2:  # y |x| < 1,5·ln 2
			if x == 1.0:
				return _EXP_E
			hi = x - (_LN2_HI if xsb == 0 else -_LN2_HI)
			lo = _LN2_LO if xsb == 0 else -_LN2_LO
			k = 1 - xsb - xsb
		else:
			k = int(_IVLN2 * x + (0.5 if xsb == 0 else -0.5))  # static_cast<int>: trunca hacia el cero
			var t := float(k)
			hi = x - t * _LN2_HI  # t·ln2HI es exacto aquí
			lo = t * _LN2_LO
		x = hi - lo
	elif hx < 0x3E300000:  # |x| < 2^-28
		if _HUGE + x > 1.0:
			return 1.0 + x
	# x ya está en el intervalo principal
	var tt := x * x
	b.encode_u32(0, 0)  # twopk = 2^k (o 2^(k + 1000) si k < −1021) = _words(0x3FF00000 + (k << 20), 0)
	b.encode_u32(4, (0x3FF00000 + (k if k >= -1021 else k + 1000) * 1048576) & 0xFFFFFFFF)
	var twopk := b.decode_double(0)
	var c := x - tt * (_P1 + tt * (_P2 + tt * (_P3 + tt * (_P4 + tt * _P5))))
	if k == 0:
		return 1.0 - ((x * c) / (c - 2.0) - x)
	var y := 1.0 - ((lo - (x * c) / (2.0 - c)) - hi)
	if k >= -1021:
		if k == 1024:
			return y * 2.0 * _TWO1023
		return y * twopk
	return y * twopk * _TWOM1000


# ── Logaritmos y raíz cúbica (ieee754.cc de V8 12.4: log, log1p, log10 y cbrt) ──

static var _LN2_HI: float = _fb(0x3FE62E42FEE00000)
static var _LN2_LO: float = _fb(0x3DEA39EF35793C76)
static var _TWO54: float = _fb(0x4350000000000000)
static var _TWO_THIRDS: float = _fb(0x3FE5555555555555)
## Lg1…Lg7 de log (los mismos valores que Lp1…Lp7 de log1p).
static var _LG: PackedFloat64Array = _fba([
	0x3FE5555555555593, 0x3FD999999997FA04, 0x3FD2492494229359, 0x3FCC71C51D8E78AF, 0x3FC7466496CB03DE,
	0x3FC39A09D078C69F, 0x3FC2F112DF3E5244])
static var _IVLN10: float = _fb(0x3FDBCB7B1526E50E)
static var _LOG10_2HI: float = _fb(0x3FD34413509F6000)
static var _LOG10_2LO: float = _fb(0x3D59FEF311F12B36)
static var _CBRT_P: PackedFloat64Array = _fba([
	0x3FFE03E60F61E692, -0x3FFE28E092F02420, 0x3FF9F1604A49D6C2, -0x3FE844CBBEE751D9, 0x3FC2B000D4E4EDD7])
const _CBRT_B1 := 715094163  # (1023 − 1023/3 − 0,03306235651)·2^20
const _CBRT_B2 := 696219795  # (1023 − 1023/3 − 54/3 − 0,03306235651)·2^20
const _INT32_BFD2BEC4 := -1076707644  # (int32_t) 0xBFD2BEC4: 1 + x ≈ √2/2


## Math.log.
static func js_log(x: float) -> float:
	var hx := _hi(x)
	var lx := _lo(x)
	var k := 0
	if hx < 0x00100000:  # x < 2^-1022
		if ((hx & 0x7FFFFFFF) | lx) == 0:
			return -INF
		if hx < 0:
			return NAN
		k -= 54
		x *= _TWO54  # subnormal: se escala
		hx = _hi(x)
	if hx >= 0x7FF00000:
		return x + x
	k += (hx >> 20) - 1023
	hx &= 0x000FFFFF
	var i := (hx + 0x95F64) & 0x100000
	x = _set_hi(x, hx | (i ^ 0x3FF00000))  # normaliza x o x/2
	k += i >> 20
	var f := x - 1.0
	var dk := float(k)
	if (0x000FFFFF & (2 + hx)) < 3:  # −2^-20 ≤ f < 2^-20
		if f == 0.0:
			return 0.0 if k == 0 else dk * _LN2_HI + dk * _LN2_LO
		var r0 := f * f * (0.5 - _THIRD * f)
		return f - r0 if k == 0 else dk * _LN2_HI - ((r0 - dk * _LN2_LO) - f)
	var s := f / (2.0 + f)
	var z := s * s
	i = hx - 0x6147A
	var w := z * z
	var j := 0x6B851 - hx
	var t1 := w * (_LG[1] + w * (_LG[3] + w * _LG[5]))
	var t2 := z * (_LG[0] + w * (_LG[2] + w * (_LG[4] + w * _LG[6])))
	i |= j
	var r := t2 + t1
	if i > 0:
		var hfsq := 0.5 * f * f
		if k == 0:
			return f - (hfsq - s * (hfsq + r))
		return dk * _LN2_HI - ((hfsq - (s * (hfsq + r) + dk * _LN2_LO)) - f)
	if k == 0:
		return f - s * (f - r)
	return dk * _LN2_HI - ((s * (f - r) - dk * _LN2_LO) - f)


## Math.log1p: ln(1 + x) con precisión también para x pequeño.
static func js_log1p(x: float) -> float:
	var hx := _hi(x)
	var ax := hx & 0x7FFFFFFF
	var k := 1
	var f := 0.0
	var c := 0.0
	var hu := 0
	if hx < 0x3FDA827A:  # 1 + x < √2
		if ax >= 0x3FF00000:  # x ≤ −1
			return -INF if x == -1.0 else NAN
		if ax < 0x3E200000:  # |x| < 2^-29
			if _TWO54 + x > 0.0 and ax < 0x3C900000:  # |x| < 2^-54
				return x
			return x - x * x * 0.5
		if hx > 0 or hx <= _INT32_BFD2BEC4:  # √2/2 ≤ 1 + x < √2
			k = 0
			f = x
			hu = 1
	if hx >= 0x7FF00000:
		return x + x
	if k != 0:
		var u := x
		if hx < 0x43400000:
			u = 1.0 + x
			hu = _hi(u)
			k = (hu >> 20) - 1023
			c = 1.0 - (u - x) if k > 0 else x - (u - 1.0)  # término de corrección
			c /= u
		else:
			hu = _hi(u)
			k = (hu >> 20) - 1023
			c = 0.0
		hu &= 0x000FFFFF
		if hu < 0x6A09E:  # u ≲ √2
			u = _set_hi(u, hu | 0x3FF00000)  # normaliza u
		else:
			k += 1
			u = _set_hi(u, hu | 0x3FE00000)  # normaliza u/2
			hu = (0x00100000 - hu) >> 2
		f = u - 1.0
	var hfsq := 0.5 * f * f
	if hu == 0:  # |f| < 2^-20
		if f == 0.0:
			if k == 0:
				return 0.0
			c += k * _LN2_LO
			return k * _LN2_HI + c
		var r0 := hfsq * (1.0 - _TWO_THIRDS * f)
		if k == 0:
			return f - r0
		return k * _LN2_HI - ((r0 - (k * _LN2_LO + c)) - f)
	var s := f / (2.0 + f)
	var z := s * s
	var r := z * (_LG[0] + z * (_LG[1] + z * (_LG[2] + z * (_LG[3] + z * (_LG[4] + z * (_LG[5] + z * _LG[6]))))))
	if k == 0:
		return f - (hfsq - s * (hfsq + r))
	return k * _LN2_HI - ((hfsq - (s * (hfsq + r) + (k * _LN2_LO + c))) - f)


## Math.log10.
static func js_log10(x: float) -> float:
	var hx := _hi(x)
	var lx := _lo(x)
	var k := 0
	if hx < 0x00100000:  # x < 2^-1022
		if ((hx & 0x7FFFFFFF) | lx) == 0:
			return -INF
		if hx < 0:
			return NAN
		k -= 54
		x *= _TWO54
		hx = _hi(x)
		lx = _lo(x)
	if hx >= 0x7FF00000:
		return x + x
	if hx == 0x3FF00000 and lx == 0:
		return 0.0  # log10(1) = +0
	k += (hx >> 20) - 1023
	var i := 1 if k < 0 else 0
	hx = (hx & 0x000FFFFF) | ((0x3FF - i) << 20)
	var y := float(k + i)
	x = _words(hx, lx)
	var z := y * _LOG10_2LO + _IVLN10 * js_log(x)
	return z + y * _LOG10_2HI


## Math.cbrt: raíz cúbica real, también de negativos (versión de FreeBSD que usa V8).
static func js_cbrt(x: float) -> float:
	var hx := _hi(x)
	var low := _lo(x)
	var sign := hx & 0x80000000
	hx &= 0x7FFFFFFF  # hx ^= sign en 32 bits
	if hx >= 0x7FF00000:
		return x + x  # NaN e infinito
	var t := 0.0
	if hx < 0x00100000:  # cero o subnormal
		if (hx | low) == 0:
			return x
		t = _words(0x43500000, 0) * x  # t = 2^54·x
		t = _words(sign | ((_hi(t) & 0x7FFFFFFF) / 3 + _CBRT_B2), 0)
	else:
		t = _words(sign | (hx / 3 + _CBRT_B1), 0)
	# a 23 bits con un polinomio de 1/cbrt(r)
	var r := (t * t) * (t / x)
	t = t * ((_CBRT_P[0] + r * (_CBRT_P[1] + r * _CBRT_P[2])) + ((r * r) * r) * (_CBRT_P[3] + r * _CBRT_P[4]))
	# redondeo de t a 23 bits, alejándose del cero
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, t)
	b.encode_s64(0, (b.decode_s64(0) + 0x80000000) & ~0x3FFFFFFF)
	t = b.decode_double(0)
	# un paso de Newton hasta 53 bits (error < 0,667 ulp)
	var s := t * t
	r = x / s
	var w := t + t
	r = (r - t) / (w + r)
	return t + t * r
