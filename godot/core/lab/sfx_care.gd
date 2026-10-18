## Tribología biológica · sonidos de la cetrería (unidad 5b; no existen en la 1.x): dos bucles que la escena no puede
## sacar de los efectos cortos del laboratorio. Son diseño de sonido, no medidas:
##   - «torno-garras»: el motor del torno de uñas de mascota en marcha. El fundamental es el giro del motor a la primera
##     velocidad del Dremel 7300-PT (6500 rpm = 108,3 Hz, CareData.TOOLS.torno.rpm_steps; redondeado a 108,5 Hz para que
##     el bucle cierre), con armónicos que caen y el silbido del colector hacia el armónico 13, más el soplo del aire. La
##     interfaz lo reproduce con pitch_scale = rpm / 6500 (a 13 000 rpm, una octava más alto);
##   - «lima-garra»: el roce de una lima: ruido de banda ancha que late con cada diente que pasa, a 130 dientes por
##     segundo (13 dientes por cm a 10 cm/s: ClawCareState.RASP_REF_TPS) con un golpe de cada diente que se apaga en 1 ms;
##     la interfaz cambia su tono con los dientes que pasan de verdad (ClawCareState.sound_view).
##   - «amoladora-garras» (unidad 5c): el motor de la amoladora de uñas con protector (Dremel 7760-PGK) a su primera
##     velocidad, 8000 rpm = 133,3 Hz (CareData.TOOLS.amoladora.rpm_steps; redondeado a 133,5 Hz para que el bucle
##     cierre): un motor pequeño y rápido, con el gemido del colector hacia el armónico 7, el silbido del aire de la banda y
##     menos cuerpo que el torno. La interfaz lo reproduce con pitch_scale = rpm / 8000 (a 25 000 rpm, 3,1 veces más
##     agudo), y baja algo al apretar (ClawCareState.sound_view: motor_load, diseño de sonido);
##   - «motor-arranque» y «motor-parada» (unidad 5c): el arranque (el clic del interruptor y el giro que sube hasta las
##     8000 rpm con una constante de 0,12 s) y la parada (el clic y el giro que cae con 0,3 s), de una vez. La interfaz
##     los toca con el tono de la velocidad (rpm / 8000), con la amoladora y con el torno.
## Los efectos cortos de cada acción son los de la 1.x (ClawCare.sfx_for: «scratch-*», «snap», «skin-cut»…).
## Todo se hornea una vez (tools/bake_lab_extra.gd) en res://assets/sfx/lab/: en tiempo real no se sintetiza nada.
## Determinista: el azar sale de rng.gd con una semilla por efecto; los senos directos son los de V8 (v8_math.gd).
## Uso: const SfxCare = preload("res://core/lab/sfx_care.gd"); SfxCare.wav_bytes(SfxCare.MOTOR).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")

const SR := Sfx.SFX_RATE
const MOTOR := "torno-garras"
const RASP := "lima-garra"
const GRINDER := "amoladora-garras"
const SPIN_UP := "motor-arranque"
const SPIN_DOWN := "motor-parada"
## El pitido de la lámpara de fotopolimerizar (unidad 5o): las lámparas de dentista pitan en cada intervalo (CareData.LAMPS:
## beep_s). Un zumbador piezoeléctrico de BEEP_HZ durante BEEP_S, con rampas de BEEP_RAMP_S (diseño de sonido, no medida).
const BEEP := "lampara-pitido"
const BEEP_HZ := 2700.0
const BEEP_S := 0.12
const BEEP_RAMP_S := 0.008
const BEEP_RMS := 0.12
## rpm a las que se hornean el arranque y la parada (la primera velocidad de la amoladora).
const SPIN_BASE_RPM := 8000.0
## Duración del arranque y de la parada (s) y sus constantes de tiempo (diseño de sonido).
const SPIN_UP_S := 0.6
const SPIN_UP_TAU := 0.12
const SPIN_DOWN_S := 1.1
const SPIN_DOWN_TAU := 0.3
const GRINDER_RMS := 0.15
## Duración de cada bucle (s) y el paso al que se redondean sus frecuencias (Hz) para que cierre.
const LOOP_S := 2.0
const HZ_STEP := 1.0 / LOOP_S
## Dientes por segundo del roce de referencia (13 dientes por cm a 10 cm/s).
const RASP_TPS := 130.0
## Valor eficaz de cada bucle.
const MOTOR_RMS := 0.16
const RASP_RMS := 0.085
## Muestras de fundido en la costura del ruido.
const XFADE := 3308


static func ids() -> Array[String]:
	var out: Array[String] = [MOTOR, RASP, GRINDER, SPIN_UP, SPIN_DOWN, BEEP]
	return out


## Los motores y el roce son bucles; el arranque y la parada suenan una vez.
static func is_loop(id: String) -> bool:
	return id in [MOTOR, RASP, GRINDER]


## El bucle del motor de una herramienta giratoria (la amoladora o el torno).
static func motor_of(tool_id: String) -> String:
	return GRINDER if tool_id == "amoladora" else MOTOR


## rpm a las que se hornea el bucle de un motor: su primera velocidad (el tono de la interfaz es rpm / base_rpm).
static func base_rpm(id: String) -> float:
	var tid := "amoladora" if id == GRINDER else "torno"
	return float((CareData.TOOLS[tid].rpm_steps as Array)[0])


## Fundamental del bucle de la amoladora (Hz): su primera velocidad, redondeada a HZ_STEP.
static func grinder_hz() -> float:
	return Js.js_round(base_rpm(GRINDER) / 60.0 / HZ_STEP) * HZ_STEP


## Fundamental del motor (Hz): el giro a la primera velocidad del torno, redondeado a HZ_STEP.
static func motor_hz() -> float:
	var rpm := float((CareData.TOOLS.torno.rpm_steps as Array)[0])
	return Js.js_round(rpm / 60.0 / HZ_STEP) * HZ_STEP


## Bytes del WAV (los bucles, con su cola: Sfx.with_loop_tail).
static func wav_bytes(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(render(id)) if is_loop(id) else render(id), SR)


static func render(id: String) -> PackedFloat32Array:
	match id:
		MOTOR:
			return _motor()
		RASP:
			return _rasp()
		GRINDER:
			return _grinder()
		SPIN_UP:
			return _spin(true)
		SPIN_DOWN:
			return _spin(false)
		BEEP:
			return _beep()
	push_error("SfxCare: efecto desconocido «%s»" % id)
	return PackedFloat32Array()


## El pitido: un seno de BEEP_HZ con algo de su tercer armónico (el zumbador no es puro), con rampas para que no chasque.
static func _beep() -> PackedFloat32Array:
	var n := int(Js.js_round(BEEP_S * SR))
	var ramp := maxf(BEEP_RAMP_S * SR, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var env := minf(minf(float(i) / ramp, float(n - 1 - i) / ramp), 1.0)
		out[i] = env * (V8.js_sin(TAU * BEEP_HZ * t) + 0.18 * V8.js_sin(3.0 * TAU * BEEP_HZ * t))
	Dsp.scale(out, BEEP_RMS / maxf(Dsp.rms(out), 1e-12))
	return out


## El motor: armónicos del giro (caen como 1/k, con el silbido del colector hacia k = 13) y un latido leve por vuelta, más
## el soplo del ventilador (ruido rosa entre 600 Hz y 5 kHz).
static func _motor() -> PackedFloat32Array:
	var n := int(Js.js_round(LOOP_S * SR))
	var f0 := motor_hz()
	var rng := Rng.from_text("lab:" + MOTOR)
	var amps: Array = []
	var phases: Array = []
	for k in 16:
		var h := float(k + 1)
		var a := 1.0 / h
		# el silbido del colector: una campana alrededor del armónico 13
		var dh := (h - 13.0) / 1.6
		a += 0.35 * V8.js_exp(-dh * dh)
		amps.append(a)
		phases.append(rng.next() * TAU)
	var tone := PackedFloat32Array()
	tone.resize(n)
	for i in n:
		var t := float(i) / SR
		var ph := TAU * f0 * t
		var am := 1.0 + 0.06 * V8.js_sin(ph + 0.4)
		var x := 0.0
		for k in amps.size():
			x += float(amps[k]) * V8.js_sin((k + 1) * ph + float(phases[k]))
		tone[i] = x * am
	Dsp.scale(tone, MOTOR_RMS / maxf(Dsp.rms(tone), 1e-12))
	var nz := Dsp.pink(n + XFADE, rng)
	Dsp.filter_all(nz, "hp", 600.0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 5000.0, 0.7, SR)
	var air := Dsp.loop_crossfade(nz, n)
	Dsp.scale(air, 0.35 * MOTOR_RMS / maxf(Dsp.rms(air), 1e-12))
	Dsp.mix_into(tone, air)
	return tone


## El roce de la lima: ruido de banda ancha (1,2-6 kHz) con un golpe que se apaga en cada diente que pasa (RASP_TPS por
## segundo, periódico en el bucle) y una fuerza de cada diente algo distinta.
static func _rasp() -> PackedFloat32Array:
	var n := int(Js.js_round(LOOP_S * SR))
	var rng := Rng.from_text("lab:" + RASP)
	var nz := Dsp.pink(n + XFADE, rng)
	Dsp.filter_all(nz, "hp", 1200.0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 6000.0, 0.7, SR)
	var hiss := Dsp.loop_crossfade(nz, n)
	var teeth := int(Js.js_round(RASP_TPS * LOOP_S))
	var per := float(n) / float(teeth)
	var gains := PackedFloat32Array()
	gains.resize(teeth)
	for k in teeth:
		gains[k] = 0.55 + 0.45 * rng.next()
	var tau := 0.001 * SR
	for i in n:
		var kf := float(i) / per
		var k := int(floorf(kf)) % teeth
		var since := (kf - floorf(kf)) * per
		var env := 0.25 + 0.75 * float(gains[k]) * V8.js_exp(-since / tau)
		hiss[i] *= env
	Dsp.scale(hiss, RASP_RMS / maxf(Dsp.rms(hiss), 1e-12))
	return hiss


## Amplitudes de los armónicos del motor de la amoladora: caen como 1/k, con el gemido del colector hacia k = 7 y algo
## más de segundo armónico (el desequilibrio de la banda en su mandril).
static func _grinder_amps() -> Array:
	var amps: Array = []
	for k in 14:
		var h := float(k + 1)
		var a := 0.8 / h
		var dh := (h - 7.0) / 1.2
		a += 0.45 * V8.js_exp(-dh * dh)
		if k == 1:
			a += 0.25
		amps.append(a)
	return amps


## El motor de la amoladora: armónicos del giro a 8000 rpm (133,5 Hz en el bucle), un latido leve por vuelta y el silbido
## del aire de la banda (ruido rosa de 1,5 a 8 kHz), más fuerte que en el torno.
static func _grinder() -> PackedFloat32Array:
	var n := int(Js.js_round(LOOP_S * SR))
	var f0 := grinder_hz()
	var rng := Rng.from_text("lab:" + GRINDER)
	var amps := _grinder_amps()
	var phases: Array = []
	for k in amps.size():
		phases.append(rng.next() * TAU)
	var tone := PackedFloat32Array()
	tone.resize(n)
	for i in n:
		var ph := TAU * f0 * float(i) / SR
		var am := 1.0 + 0.04 * V8.js_sin(ph + 1.1)
		var x := 0.0
		for k in amps.size():
			x += float(amps[k]) * V8.js_sin((k + 1) * ph + float(phases[k]))
		tone[i] = x * am
	Dsp.scale(tone, GRINDER_RMS / maxf(Dsp.rms(tone), 1e-12))
	var nz := Dsp.pink(n + XFADE, rng)
	Dsp.filter_all(nz, "hp", 1500.0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 8000.0, 0.7, SR)
	var air := Dsp.loop_crossfade(nz, n)
	Dsp.scale(air, 0.5 * GRINDER_RMS / maxf(Dsp.rms(air), 1e-12))
	Dsp.mix_into(tone, air)
	return tone


## El arranque (up) o la parada: el clic del interruptor (un golpe de ruido de 6 ms) y el giro del motor de la amoladora
## que sube hasta 8000 rpm, f(t) = f0·(1 − e^(−t/τ)), o cae, f(t) = f0·e^(−t/τ), con la fase integrada muestra a
## muestra al hornear. El nivel sigue al giro y empalma con el del bucle.
static func _spin(up: bool) -> PackedFloat32Array:
	var dur := SPIN_UP_S if up else SPIN_DOWN_S
	var tau := SPIN_UP_TAU if up else SPIN_DOWN_TAU
	var n := int(Js.js_round(dur * SR))
	var f0 := grinder_hz()
	var rng := Rng.from_text("lab:" + (SPIN_UP if up else SPIN_DOWN))
	var amps := _grinder_amps()
	var phases: Array = []
	for k in amps.size():
		phases.append(rng.next() * TAU)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var norm := 0.0
	for a: float in amps:
		norm += a * a
	norm = sqrt(norm * 0.5)
	for i in n:
		var t := float(i) / SR
		var f := f0 * ((1.0 - V8.js_exp(-t / tau)) if up else V8.js_exp(-t / tau))
		ph += TAU * f / SR
		var x := 0.0
		for k in amps.size():
			# los armónicos que pasan de la mitad de la frecuencia de muestreo no suenan
			if f * float(k + 1) < SR * 0.45:
				x += float(amps[k]) * V8.js_sin((k + 1) * ph + float(phases[k]))
		var lvl := f / f0
		var env := minf(t / 0.02, 1.0) if up else minf((dur - t) / 0.15, 1.0)
		out[i] = x / norm * GRINDER_RMS * (0.35 + 0.65 * lvl) * lvl * env
	# el aire de la banda, que sigue al giro
	var nz := Dsp.pink(n, rng)
	Dsp.filter_all(nz, "hp", 1500.0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 8000.0, 0.7, SR)
	var nr := maxf(Dsp.rms(nz), 1e-12)
	for i in n:
		var t := float(i) / SR
		var lvl := (1.0 - V8.js_exp(-t / tau)) if up else V8.js_exp(-t / tau)
		out[i] += nz[i] / nr * 0.5 * GRINDER_RMS * lvl * lvl
	# el clic del interruptor
	var click := int(0.006 * SR)
	for i in click:
		out[i] += (rng.next() * 2.0 - 1.0) * 0.35 * V8.js_exp(-float(i) / (0.0015 * SR))
	return out
