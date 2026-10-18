## Tribología biológica · sonidos del laboratorio experimental de la reforja (unidad 5f): los siete ids nuevos de
## ClawForge.SFX_FORGE. Todo es diseño de sonido, no medidas: las frecuencias son elecciones con un porqué, redondeadas a
## 0,5 Hz para que cada bucle de 2 s cierre sin salto.
##   - «forja-horno» (bucle): el horno eléctrico. El zumbido de red a 100 Hz (el doble de los 50 Hz de la red: los núcleos
##     de los transformadores vibran dos veces por ciclo) con sus armónicos, y el ventilador (ruido rosa grave).
##   - «forja-llama» (bucle): el soplete de oxígeno e hidrógeno de Verneuil. El rugido de la combustión turbulenta (ruido
##     rosa por un paso banda hacia 420 Hz), el silbido del chorro de gas (agudo) y un parpadeo lento de la llama.
##   - «forja-induccion» (bucle): el horno de inducción. El silbido de la bobina a 1500 Hz (los hornos de fusión de media
##     frecuencia trabajan en kHz y se oyen; el tono exacto es una elección), con un latido lento, el zumbido de la fuente a
##     100 Hz y la bomba del agua de refrigeración (rosa muy grave).
##   - «forja-prensa» (bucle): la prensa hidráulica del diamante HPHT. La bomba de engranajes de 9 dientes movida por un
##     motor de 4 polos a 1440 rpm (24 Hz): su rizado a 216 Hz con armónicos, el motor y el siseo del aceite.
##   - «forja-muela» (bucle): la muela de lapidario con su agua. El motor de 2 polos (2910 rpm = 48,5 Hz), el roce del grano
##     (ruido agudo que late con cada vuelta de la muela) y el agua que salpica. La interfaz cambia su tono con la velocidad
##     de la muela (ClawForgeState.sound_view: v / la de serie).
##   - «forja-colada» (una vez): el metal fundido que cae en el molde. Borbotones graves, el chisporroteo al tocar el molde
##     y crujidos.
##   - «forja-temple» (una vez): la pieza caliente que entra en el agua o el aceite (y la garra que se quema). Un siseo de
##     vapor con un ataque muy rápido y burbujas que se apagan.
##   - «forja-pulso» (una vez; unidad 5r): un pulso de la soldadora láser. El láser no suena: lo que se oye es el chasquido
##     del vapor del metal al salir del punto (un clic corto hacia 3 kHz) y un soplo breve que se apaga en unas decenas de
##     milisegundos.
##   - «forja-arco» (una vez; unidad 5r): un pulso del micro-TIG. El arco salta con un chasquido ancho, crepita mientras
##     dura el pulso (unos milisegundos) y deja un soplo de argón.
## Se hornean una vez (tools/bake_lab_extra.gd) en res://assets/sfx/lab/: en tiempo real no se sintetiza nada.
## Determinista: el azar sale de rng.gd con una semilla por efecto; los senos y las exponenciales directos son los de V8
## (v8_math.gd).
## Uso: const SfxForge = preload("res://core/lab/sfx_forge.gd"); SfxForge.wav_bytes(SfxForge.HORNO).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Sfx = preload("res://core/lab/sfx.gd")

const SR := Sfx.SFX_RATE
const MUELA := "forja-muela"
const HORNO := "forja-horno"
const LLAMA := "forja-llama"
const INDUCCION := "forja-induccion"
const PRENSA := "forja-prensa"
const COLADA := "forja-colada"
const TEMPLE := "forja-temple"
const PULSO := "forja-pulso"
const ARCO := "forja-arco"
## Duración de cada bucle (s) y el paso al que se redondean sus frecuencias (Hz) para que cierre.
const LOOP_S := 2.0
const HZ_STEP := 1.0 / LOOP_S
## Muestras de fundido en la costura del ruido.
const XFADE := 3308
## Las frecuencias del diseño (Hz).
const MAINS_HUM_HZ := 100.0
const COIL_HZ := 1500.0
const PUMP_HZ := 24.0
const PUMP_TEETH := 9
const WHEEL_HZ := 48.5
const ROAR_HZ := 420.0
## El valor eficaz de cada bucle (el nivel de cada uno frente a los demás: diseño).
const RMS := { MUELA: 0.14, HORNO: 0.11, LLAMA: 0.15, INDUCCION: 0.10, PRENSA: 0.13 }
## Duración de los que suenan una vez (s) y su pico.
const ONE_SHOT_S := { COLADA: 1.8, TEMPLE: 2.4, PULSO: 0.16, ARCO: 0.22 }
const ONE_SHOT_PEAK := 0.85


static func ids() -> Array[String]:
	var out: Array[String] = [MUELA, HORNO, LLAMA, INDUCCION, PRENSA, COLADA, TEMPLE, PULSO, ARCO]
	return out


## Los de las máquinas y la muela son bucles; la colada y el temple suenan una vez.
static func is_loop(id: String) -> bool:
	return id in [MUELA, HORNO, LLAMA, INDUCCION, PRENSA]


## Bytes del WAV (los bucles, con su cola: Sfx.with_loop_tail).
static func wav_bytes(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(render(id)) if is_loop(id) else render(id), SR)


static func render(id: String) -> PackedFloat32Array:
	match id:
		MUELA:
			return _muela()
		HORNO:
			return _horno()
		LLAMA:
			return _llama()
		INDUCCION:
			return _induccion()
		PRENSA:
			return _prensa()
		COLADA:
			return _colada()
		TEMPLE:
			return _temple()
		PULSO:
			return _pulso()
		ARCO:
			return _arco()
	push_error("SfxForge: efecto desconocido «%s»" % id)
	return PackedFloat32Array()


static func _n_loop() -> int:
	return int(Js.js_round(LOOP_S * SR))


## Senos exactamente periódicos con V8: [f (Hz), a, φ] por parcial, por una ganancia por muestra (también periódica) si
## se da.
static func _tones(n: int, parts: Array, mod: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for p: Array in parts:
		var w := TAU * float(p[0]) / SR
		var a := float(p[1])
		var ph := float(p[2]) if p.size() > 2 else 0.0
		for i in n:
			var g := mod[i] if not mod.is_empty() else 1.0
			out[i] += a * V8.js_sin(w * float(i) + ph) * g
	return out


## Ruido rosa de un bucle de n muestras por uno o dos filtros, con la costura fundida.
static func _noise(n: int, rng: Rng, filters: Array) -> PackedFloat32Array:
	var nz := Dsp.pink(n + XFADE, rng)
	for f: Array in filters:
		Dsp.filter_all(nz, String(f[0]), float(f[1]), float(f[2]), SR)
	return Dsp.loop_crossfade(nz, n)


## Una ganancia periódica en el bucle: 1 + Σ a·sen(2π·f·t + φ) (las f, múltiplos de HZ_STEP).
static func _am(n: int, parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var g := 1.0
		for p: Array in parts:
			g += float(p[1]) * V8.js_sin(TAU * float(p[0]) * t + float(p[2]))
		out[i] = g
	return out


## Pone el valor eficaz de x en rms.
static func _level(x: PackedFloat32Array, rms: float) -> void:
	Dsp.scale(x, rms / maxf(Dsp.rms(x), 1e-12))


## El horno eléctrico: el zumbido de 100 Hz con sus armónicos y el ventilador.
static func _horno() -> PackedFloat32Array:
	var n := _n_loop()
	var rng := Rng.from_text("lab:" + HORNO)
	var parts: Array = []
	for h: Array in [[1.0, 1.0], [2.0, 0.55], [3.0, 0.3], [4.0, 0.18], [6.0, 0.08]]:
		parts.append([MAINS_HUM_HZ * float(h[0]), float(h[1]), rng.next() * TAU])
	var tone := _tones(n, parts)
	_level(tone, float(RMS[HORNO]))
	var fan := _noise(n, rng, [["hp", 60.0, 0.7], ["lp", 700.0, 0.7]])
	_level(fan, 0.6 * float(RMS[HORNO]))
	Dsp.mix_into(tone, fan)
	_level(tone, float(RMS[HORNO]))
	return tone


## El soplete de Verneuil: el rugido, el silbido del gas y el parpadeo de la llama.
static func _llama() -> PackedFloat32Array:
	var n := _n_loop()
	var rng := Rng.from_text("lab:" + LLAMA)
	var roar := _noise(n, rng, [["bp", ROAR_HZ, 0.6], ["lp", 2500.0, 0.7]])
	var flick := _am(n, [[3.0, 0.18, 0.0], [5.5, 0.12, 1.0], [9.0, 0.08, 2.0]])
	for i in n:
		roar[i] *= flick[i]
	_level(roar, float(RMS[LLAMA]))
	var hiss := _noise(n, rng, [["hp", 2500.0, 0.7], ["lp", 7000.0, 0.7]])
	_level(hiss, 0.35 * float(RMS[LLAMA]))
	Dsp.mix_into(roar, hiss)
	_level(roar, float(RMS[LLAMA]))
	return roar


## El horno de inducción: el silbido de la bobina, su latido, el zumbido de la fuente y la bomba del agua.
static func _induccion() -> PackedFloat32Array:
	var n := _n_loop()
	var rng := Rng.from_text("lab:" + INDUCCION)
	var beat := _am(n, [[HZ_STEP, 0.25, 0.0]])
	var whine := _tones(n, [[COIL_HZ, 1.0, rng.next() * TAU], [2.0 * COIL_HZ, 0.35, rng.next() * TAU]], beat)
	_level(whine, float(RMS[INDUCCION]))
	var hum := _tones(n, [[MAINS_HUM_HZ, 1.0, rng.next() * TAU], [2.0 * MAINS_HUM_HZ, 0.4, rng.next() * TAU]])
	_level(hum, 0.45 * float(RMS[INDUCCION]))
	Dsp.mix_into(whine, hum)
	var pump := _noise(n, rng, [["lp", 250.0, 0.7]])
	_level(pump, 0.5 * float(RMS[INDUCCION]))
	Dsp.mix_into(whine, pump)
	_level(whine, float(RMS[INDUCCION]))
	return whine


## La prensa hidráulica: el rizado de la bomba de engranajes, el motor y el siseo del aceite.
static func _prensa() -> PackedFloat32Array:
	var n := _n_loop()
	var rng := Rng.from_text("lab:" + PRENSA)
	var ripple := PUMP_HZ * float(PUMP_TEETH)
	var tone := _tones(n, [
		[ripple, 1.0, rng.next() * TAU], [2.0 * ripple, 0.45, rng.next() * TAU], [3.0 * ripple, 0.2, rng.next() * TAU],
		[PUMP_HZ, 0.35, rng.next() * TAU], [2.0 * PUMP_HZ, 0.3, rng.next() * TAU],
	], _am(n, [[PUMP_HZ, 0.15, 0.0]]))
	_level(tone, float(RMS[PRENSA]))
	var hiss := _noise(n, rng, [["bp", 2200.0, 0.8]])
	_level(hiss, 0.3 * float(RMS[PRENSA]))
	Dsp.mix_into(tone, hiss)
	_level(tone, float(RMS[PRENSA]))
	return tone


## La muela de lapidario: el motor, el roce del grano que late con cada vuelta y el agua.
static func _muela() -> PackedFloat32Array:
	var n := _n_loop()
	var rng := Rng.from_text("lab:" + MUELA)
	var motor := _tones(n, [[WHEEL_HZ, 1.0, rng.next() * TAU], [2.0 * WHEEL_HZ, 0.5, rng.next() * TAU], [3.0 * WHEEL_HZ, 0.25, rng.next() * TAU]])
	_level(motor, 0.5 * float(RMS[MUELA]))
	var grind := _noise(n, rng, [["hp", 1500.0, 0.7], ["lp", 8000.0, 0.7]])
	var turn := _am(n, [[WHEEL_HZ, 0.35, 0.0]])
	for i in n:
		grind[i] *= turn[i]
	_level(grind, float(RMS[MUELA]))
	var water := _noise(n, rng, [["bp", 900.0, 0.7]])
	var gurgle := _am(n, [[6.0, 0.4, 0.5]])
	for i in n:
		water[i] *= gurgle[i]
	_level(water, 0.45 * float(RMS[MUELA]))
	Dsp.mix_into(grind, motor)
	Dsp.mix_into(grind, water)
	_level(grind, float(RMS[MUELA]))
	return grind


## La colada: borbotones graves, el chisporroteo al tocar el molde y crujidos.
static func _colada() -> PackedFloat32Array:
	var dur := float(ONE_SHOT_S[COLADA])
	var n := int(Js.js_round(dur * SR))
	var rng := Rng.from_text("lab:" + COLADA)
	var out := PackedFloat32Array()
	out.resize(n)
	# los borbotones del chorro (ráfagas graves y largas)
	Dsp.clicks(out, SR, rng, { "t0": 0.05, "dur": 1.35, "rate": 16.0, "fc": func(r: float) -> float: return 180.0 + 320.0 * r, "q": 3.0, "gain": 0.9, "len": 0.035 })
	# el chisporroteo al tocar el molde
	var sizzle := Dsp.pink(n, rng)
	Dsp.filter_all(sizzle, "hp", 2000.0, 0.7, SR)
	for i in n:
		var t := float(i) / SR - 0.25
		var env := 0.0 if t < 0.0 else minf(t / 0.05, 1.0) * V8.js_exp(-t / 0.6)
		out[i] += sizzle[i] * env * 1.6
	# crujidos
	Dsp.clicks(out, SR, rng, { "t0": 0.3, "dur": 1.2, "rate": 30.0, "fc": 4200.0, "q": 2.0, "gain": 0.35, "len": 0.003 })
	return Dsp.finish(out, ONE_SHOT_PEAK)


## El temple: un siseo de vapor que entra de golpe y burbujas que se apagan.
static func _temple() -> PackedFloat32Array:
	var dur := float(ONE_SHOT_S[TEMPLE])
	var n := int(Js.js_round(dur * SR))
	var rng := Rng.from_text("lab:" + TEMPLE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hiss := Dsp.pink(n, rng)
	Dsp.filter_all(hiss, "hp", 1800.0, 0.7, SR)
	var steam := Dsp.pink(n, rng)
	Dsp.filter_all(steam, "bp", 5000.0, 0.7, SR)
	for i in n:
		var t := float(i) / SR
		var env := minf(t / 0.004, 1.0) * (V8.js_exp(-t / 0.35) + 0.25 * V8.js_exp(-t / 1.2))
		out[i] = (hiss[i] + 0.8 * steam[i]) * env
	# las burbujas
	var bubbles := PackedFloat32Array()
	bubbles.resize(n)
	Dsp.clicks(bubbles, SR, rng, { "t0": 0.05, "dur": dur - 0.3, "rate": 40.0, "fc": func(r: float) -> float: return 250.0 + 650.0 * r, "q": 4.0, "gain": 0.5, "len": 0.012 })
	for i in n:
		out[i] += bubbles[i] * V8.js_exp(-float(i) / SR / 0.9)
	return Dsp.finish(out, ONE_SHOT_PEAK)


## Un pulso del láser (5r): el chasquido del vapor del metal (un clic corto hacia 3 kHz) y un soplo breve que se apaga.
static func _pulso() -> PackedFloat32Array:
	var dur := float(ONE_SHOT_S[PULSO])
	var n := int(Js.js_round(dur * SR))
	var rng := Rng.from_text("lab:" + PULSO)
	var out := PackedFloat32Array()
	out.resize(n)
	# el chasquido: un solo clic al principio
	Dsp.clicks(out, SR, rng, { "t0": 0.0, "dur": 0.002, "rate": 500.0, "fc": 3000.0, "q": 2.5, "gain": 1.6, "len": 0.003 })
	# el soplo del vapor: ruido agudo que entra de golpe y se apaga en ~40 ms
	var puff := Dsp.pink(n, rng)
	Dsp.filter_all(puff, "hp", 2500.0, 0.7, SR)
	for i in n:
		var t := float(i) / SR
		out[i] += puff[i] * minf(t / 0.002, 1.0) * V8.js_exp(-t / 0.04) * 0.9
	return Dsp.finish(out, 0.7)


## Un pulso del micro-TIG (5r): el arco salta con un chasquido ancho, crepita mientras dura el pulso y deja un soplo de argón.
static func _arco() -> PackedFloat32Array:
	var dur := float(ONE_SHOT_S[ARCO])
	var n := int(Js.js_round(dur * SR))
	var rng := Rng.from_text("lab:" + ARCO)
	var out := PackedFloat32Array()
	out.resize(n)
	# el chasquido del cebado: un clic grave y ancho
	Dsp.clicks(out, SR, rng, { "t0": 0.0, "dur": 0.002, "rate": 500.0, "fc": 900.0, "q": 1.2, "gain": 1.8, "len": 0.004 })
	# el crepitar del arco durante el pulso (~12 ms): muchos clics agudos
	Dsp.clicks(out, SR, rng, { "t0": 0.002, "dur": 0.012, "rate": 2500.0, "fc": func(r: float) -> float: return 2500.0 + 3500.0 * r, "q": 3.0, "gain": 0.5, "len": 0.0015 })
	# el soplo del argón que queda
	var puff := Dsp.pink(n, rng)
	Dsp.filter_all(puff, "bp", 4000.0, 0.8, SR)
	for i in n:
		var t := float(i) / SR - 0.01
		if t > 0.0:
			out[i] += puff[i] * minf(t / 0.004, 1.0) * V8.js_exp(-t / 0.05) * 0.6
	return Dsp.finish(out, ONE_SHOT_PEAK)
