## DSP determinista compartido · port 1:1 de packages/core/src/sfx.js (bloques «DSP» y encodeWav).
##
## Base común del sonido de las dos secciones:
## - El laboratorio puede rehacer con él sus 22 efectos de la 1.x: con las mismas recetas y la misma semilla
##   salen los mismos bytes (los tests comparan el sha256 de los WAV con tests/fixtures/sfx.json).
## - El taller hornea con él sus bucles de máquina (tools/bake_sounds.gd). En tiempo real no se calcula nada
##   muestra a muestra: se reproducen esos bucles y se mueven volumen, tono y filtros del mezclador.
##
## Bloques de sfx.js (misma aritmética y mismo orden de operaciones, para que los bits coincidan):
##   Biquad (RBJ, «Audio EQ Cookbook» de R. Bristow-Johnson: paso bajo, paso alto y paso banda de ganancia 1),
##   env_ar y decay (envolventes), noise_band (ruido filtrado con modulación «stick-slip»), tone (tono con
##   barrido, seno o triangular), modal (resonancias [f, τ, amplitud] excitadas por un golpe), clicks
##   (chasquidos: ráfagas cortas filtradas), finish (normaliza con saturación suave tanh y funde los bordes) y
##   encode_wav (WAV PCM de 16 bits mono).
## Bloques nuevos para bucles: partials (senos exactamente periódicos), pink (ruido rosa de Kellet),
## loop_crossfade (costura sin clic), rms, peak y scale.
##
## Las muestras se acumulan en PackedFloat32Array, como el Float32Array de sfx.js: cada suma se redondea a
## 32 bits igual que en JavaScript. Los arrays empaquetados se pasan por referencia: los bloques escriben en
## el búfer que reciben. El ruido sale de core/shared/rng.gd (mulberry32 con semilla), nunca de randf().
## Uso: const Dsp = preload("res://core/shared/dsp.gd")
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Rng = preload("res://core/shared/rng.gd")

const SFX_RATE := 22050  # Hz, la frecuencia de muestreo de los efectos de la 1.x


## Filtro biquad RBJ (la función filter() de sfx.js). La frecuencia se limita a 0,45·sr, como en sfx.js.
class Biquad:
	extends RefCounted
	var type: String
	var q: float
	var sr: float
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(p_type: String, p_q: float, p_sr: float) -> void:
		type = p_type
		q = p_q
		sr = p_sr

	## Recalcula los coeficientes para la frecuencia f (Hz) sin tocar el estado.
	func set_freq(f: float) -> void:
		var w := (TAU * minf(f, sr * 0.45)) / sr
		var cs := cos(w)
		var a := sin(w) / (2.0 * q)
		var c0 := 0.0
		var c1 := 0.0
		var c2 := 0.0
		if type == "bp":
			c0 = a
			c1 = 0.0
			c2 = -a
		elif type == "lp":
			c0 = (1.0 - cs) / 2.0
			c1 = 1.0 - cs
			c2 = (1.0 - cs) / 2.0
		else:
			c0 = (1.0 + cs) / 2.0
			c1 = -(1.0 + cs)
			c2 = (1.0 + cs) / 2.0
		var a0 := 1.0 + a
		b0 = c0 / a0
		b1 = c1 / a0
		b2 = c2 / a0
		a1 = (-2.0 * cs) / a0
		a2 = (1.0 - a) / a0

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


## Biquad nuevo con coeficientes para f (atajo).
static func biquad(type: String, q: float, sr: float, f: float) -> Biquad:
	var b := Biquad.new(type, q, sr)
	b.set_freq(f)
	return b


## Envolvente ataque-caída: sube en a segundos, baja en los últimos r y vale 0 fuera de [0, dur].
static func env_ar(t: float, a: float, r: float, dur: float) -> float:
	if t < 0.0 or t > dur:
		return 0.0
	return minf(1.0, t / maxf(a, 1e-4)) * minf(1.0, (dur - t) / maxf(r, 1e-4))


## Caída exponencial exp(−t/τ) desde t = 0.
static func decay(t: float, tau: float) -> float:
	return 0.0 if t < 0.0 else exp(-t / tau)


## Banda de ruido filtrado (noiseBand de sfx.js). o: { t0 = 0, dur, fc (Hz o Callable(t)), q = 1, env: Callable(t),
## gain = 1, type = "bp" | "lp" | "hp", am = 0, am_rate = 40 }. am es la modulación «stick-slip»: cada
## 1/am_rate s la ganancia salta a un valor aleatorio. fc y la modulación se actualizan cada 32 muestras.
static func noise_band(out: PackedFloat32Array, sr: int, rng: Rng, o: Dictionary) -> void:
	var srf := float(sr)
	var q: float = o.get("q", 1.0)
	var f := Biquad.new(o.get("type", "bp"), q, srf)
	var i0 := int(floor(float(o.get("t0", 0.0)) * srf))
	var n := int(floor(float(o["dur"]) * srf))
	var fc: Variant = o["fc"]
	var fc_fn: Callable = fc if fc is Callable else Callable()
	var fc_val: float = 0.0 if fc is Callable else float(fc)
	var env: Callable = o["env"]
	var gain: float = o.get("gain", 1.0)
	var am: float = o.get("am", 0.0)
	var am_rate: float = o.get("am_rate", 40.0)
	var amv := 1.0
	var am_phase := 0.0
	var i := 0
	while i < n and i0 + i < out.size():
		var t := float(i) / srf
		if i % 32 == 0:
			f.set_freq(fc_fn.call(t) if fc_fn.is_valid() else fc_val)
			if am != 0.0:
				am_phase += (32.0 * am_rate) / srf
				if am_phase >= 1.0:
					am_phase -= 1.0
					amv = 1.0 - am + am * rng.next() * 1.6
		out[i0 + i] += f.run(rng.next() * 2.0 - 1.0) * env.call(t) * gain * amv
		i += 1


## Tono con frecuencia variable (tone de sfx.js). o: { t0 = 0, dur, f (Hz o Callable(t)), env: Callable(t),
## gain = 1, shape = "sine" | "tri" }. La fase se acumula muestra a muestra, así que admite barridos.
static func tone(out: PackedFloat32Array, sr: int, o: Dictionary) -> void:
	var srf := float(sr)
	var i0 := int(floor(float(o.get("t0", 0.0)) * srf))
	var n := int(floor(float(o["dur"]) * srf))
	var fv: Variant = o["f"]
	var f_fn: Callable = fv if fv is Callable else Callable()
	var f_val: float = 0.0 if fv is Callable else float(fv)
	var env: Callable = o["env"]
	var gain: float = o.get("gain", 1.0)
	var tri: bool = o.get("shape", "sine") == "tri"
	var ph := 0.0
	var i := 0
	while i < n and i0 + i < out.size():
		var t := float(i) / srf
		ph += (f_fn.call(t) if f_fn.is_valid() else f_val) / srf
		var s := (1.0 - 4.0 * absf(fmod(ph, 1.0) - 0.5)) if tri else sin(TAU * ph)
		out[i0 + i] += s * env.call(t) * gain
		i += 1


## Resonancia modal (modal de sfx.js): cada parcial [f (Hz), τ (s), amplitud] suena sin(2π·f·t)·e^(−t/τ)
## durante 6τ desde t0. o: { t0 = 0, partials: Array, gain = 1 }.
static func modal(out: PackedFloat32Array, sr: int, o: Dictionary) -> void:
	var srf := float(sr)
	var i0 := int(floor(float(o.get("t0", 0.0)) * srf))
	var gain: float = o.get("gain", 1.0)
	for p in o["partials"]:
		var fr: float = p[0]
		var tau: float = p[1]
		var amp: float = p[2]
		var n := int(floor(tau * 6.0 * srf))
		var i := 0
		while i < n and i0 + i < out.size():
			var t := float(i) / srf
			out[i0 + i] += sin(TAU * fr * t) * exp(-t / tau) * amp * gain
			i += 1


## Chasquidos (clicks de sfx.js): round(rate·dur) ráfagas de ruido cortas, cada una por su paso banda, en
## instantes aleatorios. o: { t0 = 0, dur, rate (1/s), fc (Hz o Callable(r) con r aleatorio en [0, 1)), q = 2,
## gain = 1, len = 0.004 (s) }.
static func clicks(out: PackedFloat32Array, sr: int, rng: Rng, o: Dictionary) -> void:
	var srf := float(sr)
	var t0: float = o.get("t0", 0.0)
	var dur: float = o["dur"]
	var q: float = o.get("q", 2.0)
	var gain: float = o.get("gain", 1.0)
	var length: float = o.get("len", 0.004)
	var fc: Variant = o["fc"]
	var count := int(Js.js_round(float(o["rate"]) * dur))
	for k in count:
		var f := Biquad.new("bp", q, srf)
		f.set_freq((fc as Callable).call(rng.next()) if fc is Callable else float(fc) * (0.7 + rng.next() * 0.6))
		var i0 := int(floor((t0 + rng.next() * dur) * srf))
		var n := int(floor(length * srf * (0.6 + rng.next())))
		var g := gain * (0.35 + rng.next() * 0.65)
		var i := 0
		while i < n + 400 and i0 + i < out.size():
			out[i0 + i] += f.run((rng.next() * 2.0 - 1.0) * (1.0 - float(i) / n) if i < n else 0.0) * g
			i += 1


## Normaliza el pico a level con saturación suave (tanh) y funde 64 muestras en cada borde (finish de sfx.js).
## Trabaja sobre el propio búfer y lo devuelve. Para bucles no sirve (los fundidos abren un hueco en la
## costura): usa scale() y loop_crossfade().
static func finish(out: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var peak_v := 1e-9
	for i in out.size():
		peak_v = maxf(peak_v, absf(out[i]))
	var g := level / peak_v
	var fade := mini(out.size(), 64)
	for i in out.size():
		out[i] = tanh(out[i] * g * 1.1) / tanh(1.1)
	for i in fade:
		out[i] *= float(i) / fade
		out[out.size() - 1 - i] *= float(i) / fade
	return out


## WAV PCM de 16 bits mono (encodeWav de sfx.js): cabecera RIFF de 44 bytes y muestras redondeadas como
## Math.round(clamp(x, −1, 1)·32767).
static func encode_wav(samples: PackedFloat32Array, sample_rate: int = SFX_RATE) -> PackedByteArray:
	var n := samples.size()
	var b := PackedByteArray()
	b.resize(44 + n * 2)
	_put_ascii(b, 0, "RIFF")
	b.encode_u32(4, 36 + n * 2)
	_put_ascii(b, 8, "WAVE")
	_put_ascii(b, 12, "fmt ")
	b.encode_u32(16, 16)
	b.encode_u16(20, 1)  # PCM
	b.encode_u16(22, 1)  # mono
	b.encode_u32(24, sample_rate)
	b.encode_u32(28, sample_rate * 2)
	b.encode_u16(32, 2)
	b.encode_u16(34, 16)
	_put_ascii(b, 36, "data")
	b.encode_u32(40, n * 2)
	for i in n:
		b.encode_s16(44 + i * 2, int(Js.js_round(maxf(-1.0, minf(1.0, samples[i])) * 32767.0)))
	return b


static func _put_ascii(b: PackedByteArray, at: int, s: String) -> void:
	for i in s.length():
		b[at + i] = s.unicode_at(i)


# ── Bloques para bucles (no están en sfx.js) ──


## Suma de senos exactamente periódicos: x[i0 + i] += a·sin(2π·f·i/sr + φ) para i en [0, n), con cada parcial
## [f (Hz), a, φ (rad)]. La fase se calcula directamente (sin acumular), así que si f·n/sr es entero el bucle
## de n muestras empalma sin salto. mod (opcional) es una ganancia por muestra, también periódica.
static func partials(
		out: PackedFloat32Array, sr: int, parts: Array, i0: int = 0, n: int = -1,
		mod: PackedFloat32Array = PackedFloat32Array()) -> void:
	var srf := float(sr)
	var count := mini(out.size() - i0 if n < 0 else n, out.size() - i0)
	var has_mod := not mod.is_empty()
	for p in parts:
		var w := TAU * float(p[0]) / srf
		var a: float = p[1]
		var ph: float = p[2] if p.size() > 2 else 0.0
		if has_mod:
			for i in count:
				out[i0 + i] += a * sin(w * i + ph) * mod[i]
		else:
			for i in count:
				out[i0 + i] += a * sin(w * i + ph)


## Ruido rosa (−3 dB por octava) de n muestras, por el filtro de Paul Kellet (musicdsp.org, «pink noise
## filter», versión refinada): 7 polos sobre ruido blanco uniforme de rng. Con ruido rosa, un paso banda de Q
## fijo deja pasar la misma potencia en cualquier frecuencia central (la potencia por octava es constante).
static func pink(n: int, rng: Rng) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var c0 := 0.0
	var c1 := 0.0
	var c2 := 0.0
	var c3 := 0.0
	var c4 := 0.0
	var c5 := 0.0
	var c6 := 0.0
	for i in n:
		var white := rng.next() * 2.0 - 1.0
		c0 = 0.99886 * c0 + white * 0.0555179
		c1 = 0.99332 * c1 + white * 0.0750759
		c2 = 0.96900 * c2 + white * 0.1538520
		c3 = 0.86650 * c3 + white * 0.3104856
		c4 = 0.55000 * c4 + white * 0.5329522
		c5 = -0.7616 * c5 - white * 0.0168980
		out[i] = (c0 + c1 + c2 + c3 + c4 + c5 + c6 + white * 0.5362) * 0.11
		c6 = white * 0.115926
	return out


## Filtra un búfer entero con un biquad fijo (sin estado previo).
static func filter_all(x: PackedFloat32Array, type: String, f: float, q: float, sr: int) -> void:
	var b := biquad(type, q, float(sr), f)
	for i in x.size():
		x[i] = b.run(x[i])


## Costura sin clic: de un render de n + x muestras devuelve n, con las x últimas fundidas sobre las x primeras
## (fundido de igual potencia: sen²+cos² = 1, para señales no correlacionadas como el ruido). La muestra 0
## vale exactamente la n del render, que sigue de forma continua a la n−1: el bucle no salta al volver.
static func loop_crossfade(buf: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var x := buf.size() - n
	var out := buf.slice(0, n)
	for i in x:
		var w := float(i) / x
		out[i] = buf[i] * sin(PI * 0.5 * w) + buf[n + i] * cos(PI * 0.5 * w)
	return out


static func rms(x: PackedFloat32Array) -> float:
	var s := 0.0
	for v in x:
		s += v * v
	return sqrt(s / maxf(1.0, x.size()))


static func peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


## Multiplica el búfer por g (en su sitio).
static func scale(x: PackedFloat32Array, g: float) -> void:
	for i in x.size():
		x[i] *= g


## Suma b sobre a (en su sitio), multiplicado por g; a y b del mismo tamaño.
static func mix_into(a: PackedFloat32Array, b: PackedFloat32Array, g: float = 1.0) -> void:
	for i in mini(a.size(), b.size()):
		a[i] += b[i] * g
