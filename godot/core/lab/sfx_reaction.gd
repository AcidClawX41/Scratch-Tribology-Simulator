## Tribología biológica · sonidos de la reacción del animal estresado y de la lente de la cámara (unidad 5t-B). Todo es
## diseño de sonido, no medidas: las frecuencias son elecciones con un porqué, para que se reconozca cada animal.
##   - «reaccion-rapaz»: el chillido de una rapaz diurna, un «kii-iirr» agudo que baja (un tono de ~2,6 kHz con su segundo
##     armónico y aire, como el del ratonero o el busardo; el águila real chilla más débil, pero se oye del mismo tipo);
##   - «reaccion-buho»: el chasquido del pico (tres o cuatro golpes secos a ~12 por segundo) y el bufido (un siseo);
##   - «reaccion-tigre»: el gruñido con el que enseña los dientes: un tren de pulsos grave (~95 Hz, que baja y tiembla) por
##     tres formantes de la boca, con su carraspeo;
##   - «reaccion-oso»: tres resoplidos por la nariz (ráfagas de ruido grave) y un gruñido corto al final;
##   - «reaccion-raptor»: un siseo con un retumbo grave de boca cerrada (como el de los avestruces y los cocodrilos: lo que
##     se supone de los terópodos, Riede et al. 2016); el de cine es ficción y suena igual;
##   - «lente-plastico» (el chasquido de la garra en el plástico), «lente-vidrio» (el tintineo en el vidrio), «lente-grieta»
##     (el crujido de la lente que se raja), «lente-rasguno» (el rasguño de la garra que arrastra) y «lente-pano» (el paño).
## Se hornean una vez (tools/bake_lab_extra.gd, módulo «reaccion») en res://assets/sfx/lab/: en tiempo real no se
## sintetiza nada. Determinista: el azar sale de rng.gd con una semilla por efecto; los senos y las exponenciales directos
## son los de V8 (v8_math.gd).
## Uso: const SfxReaction = preload("res://core/lab/sfx_reaction.gd"); SfxReaction.wav_bytes("reaccion-tigre").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Sfx = preload("res://core/lab/sfx.gd")

const SR := Sfx.SFX_RATE
## Cada efecto: [duración (s), nivel antes del limitador suave de Dsp.finish (el pico final, tanh(1,1·nivel)/tanh(1,1): ≤ 0,63,
## con margen para que la voz y el golpe sumados no saturen)].
const SPEC := {
	"reaccion-rapaz": [1.0, 0.48], "reaccion-buho": [1.0, 0.48], "reaccion-tigre": [1.2, 0.5], "reaccion-oso": [1.3, 0.5],
	"reaccion-raptor": [1.1, 0.5], "lente-plastico": [0.3, 0.48], "lente-vidrio": [0.7, 0.45], "lente-grieta": [0.8, 0.5],
	"lente-rasguno": [0.45, 0.44], "lente-pano": [0.8, 0.36],
}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in SPEC:
		out.append(k)
	return out


## Ninguno es un bucle: suenan una vez.
static func is_loop(_id: String) -> bool:
	return false


static func wav_bytes(id: String) -> PackedByteArray:
	return Dsp.encode_wav(render(id), SR)


static func render(id: String) -> PackedFloat32Array:
	if not SPEC.has(id):
		push_error("SfxReaction: efecto desconocido «%s»" % id)
		return PackedFloat32Array()
	var dur := float(SPEC[id][0])
	var n := int(Js.js_round(dur * SR))
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := Rng.from_text("lab:" + id)
	match id:
		"reaccion-rapaz":
			_scream(out, rng, 0.02, 0.42, 2700.0, 2100.0)
			_scream(out, rng, 0.5, 0.45, 2600.0, 1750.0)
		"reaccion-buho":
			for k in 4:
				Dsp.modal(out, SR, { "t0": 0.03 + 0.085 * float(k), "partials": [[2300.0, 0.006, 1.0], [3900.0, 0.004, 0.6], [1200.0, 0.008, 0.5]], "gain": 0.9 })
			Dsp.noise_band(out, SR, rng, { "t0": 0.4, "dur": 0.55, "fc": 4200.0, "q": 0.7, "type": "hp", "gain": 0.5,
				"env": func(t: float) -> float: return Dsp.env_ar(t, 0.04, 0.3, 0.55) })
		"reaccion-tigre":
			_growl(out, rng, 0.02, 1.05, 105.0, 82.0, [[650.0, 5.0, 1.0], [1150.0, 6.0, 0.6], [2500.0, 8.0, 0.3]])
		"reaccion-oso":
			for k in 3:
				Dsp.noise_band(out, SR, rng, { "t0": 0.02 + 0.24 * float(k), "dur": 0.16, "fc": 700.0, "q": 0.8, "type": "lp", "gain": 1.0,
					"env": func(t: float) -> float: return Dsp.env_ar(t, 0.01, 0.1, 0.16) })
			_growl(out, rng, 0.78, 0.48, 78.0, 66.0, [[480.0, 4.0, 1.0], [900.0, 5.0, 0.5], [1900.0, 7.0, 0.2]])
		"reaccion-raptor":
			Dsp.noise_band(out, SR, rng, { "t0": 0.0, "dur": 0.7, "fc": 3600.0, "q": 0.6, "type": "hp", "gain": 0.7,
				"env": func(t: float) -> float: return Dsp.env_ar(t, 0.03, 0.35, 0.7) })
			Dsp.tone(out, SR, { "t0": 0.25, "dur": 0.8, "f": func(t: float) -> float: return 92.0 - 10.0 * t, "gain": 0.9,
				"env": func(t: float) -> float: return Dsp.env_ar(t, 0.08, 0.4, 0.8) * (0.75 + 0.25 * V8.js_sin(TAU * 11.0 * t)) })
		"lente-plastico":
			Dsp.modal(out, SR, { "t0": 0.002, "partials": [[1700.0, 0.018, 1.0], [2950.0, 0.012, 0.7], [5100.0, 0.007, 0.45]], "gain": 1.0 })
			Dsp.clicks(out, SR, rng, { "t0": 0.0, "dur": 0.01, "rate": 200.0, "fc": 3500.0, "q": 1.5, "gain": 0.6, "len": 0.002 })
		"lente-vidrio":
			Dsp.modal(out, SR, { "t0": 0.002, "partials": [[3450.0, 0.18, 1.0], [6150.0, 0.11, 0.6], [8900.0, 0.07, 0.4], [2200.0, 0.05, 0.3]], "gain": 0.8 })
			Dsp.clicks(out, SR, rng, { "t0": 0.0, "dur": 0.006, "rate": 300.0, "fc": 6000.0, "q": 1.5, "gain": 0.5, "len": 0.0015 })
		"lente-grieta":
			Dsp.clicks(out, SR, rng, { "t0": 0.0, "dur": 0.012, "rate": 400.0, "fc": 4500.0, "q": 1.2, "gain": 1.0, "len": 0.003 })
			Dsp.clicks(out, SR, rng, { "t0": 0.01, "dur": 0.35, "rate": 70.0, "fc": func(r: float) -> float: return 2500.0 + 5000.0 * r, "q": 2.5, "gain": 0.55, "len": 0.004 })
			Dsp.modal(out, SR, { "t0": 0.004, "partials": [[2800.0, 0.09, 0.6], [5300.0, 0.06, 0.4], [7700.0, 0.04, 0.3]], "gain": 0.7 })
		"lente-rasguno":
			Dsp.noise_band(out, SR, rng, { "t0": 0.0, "dur": 0.42, "fc": func(t: float) -> float: return 2600.0 + 1400.0 * t, "q": 3.0, "type": "bp",
				"gain": 1.0, "am": 0.7, "am_rate": 55.0, "env": func(t: float) -> float: return Dsp.env_ar(t, 0.01, 0.15, 0.42) })
		"lente-pano":
			Dsp.noise_band(out, SR, rng, { "t0": 0.0, "dur": 0.75, "fc": func(t: float) -> float: return 900.0 + 900.0 * V8.js_sin(PI * t / 0.75), "q": 0.8,
				"type": "bp", "gain": 0.8, "am": 0.25, "am_rate": 18.0, "env": func(t: float) -> float: return Dsp.env_ar(t, 0.12, 0.25, 0.75) })
	return Dsp.finish(out, float(SPEC[id][1]))


## Un chillido de rapaz: tono que baja de f0 a f1 en dur s, con su segundo armónico, un temblor rápido y aire.
static func _scream(out: PackedFloat32Array, rng: Rng, t0: float, dur: float, f0: float, f1: float) -> void:
	var fq := func(t: float) -> float: return f0 + (f1 - f0) * minf(t / dur, 1.0) + 60.0 * V8.js_sin(TAU * 28.0 * t)
	var env := func(t: float) -> float: return Dsp.env_ar(t, 0.03, dur * 0.55, dur)
	Dsp.tone(out, SR, { "t0": t0, "dur": dur, "f": fq, "env": env, "gain": 0.7 })
	Dsp.tone(out, SR, { "t0": t0, "dur": dur, "f": func(t: float) -> float: return 2.0 * float(fq.call(t)), "env": env, "gain": 0.22 })
	Dsp.noise_band(out, SR, rng, { "t0": t0, "dur": dur, "fc": func(t: float) -> float: return float(fq.call(t)), "q": 4.0, "gain": 0.35, "env": env })


## Un gruñido: un tren de pulsos (sus armónicos 1/k) de f0 a f1 con temblor, por los formantes [f, q, ganancia], y carraspeo.
static func _growl(out: PackedFloat32Array, rng: Rng, t0: float, dur: float, f0: float, f1: float, formants: Array) -> void:
	var srf := float(SR)
	var i0 := int(floor(t0 * srf))
	var n := int(floor(dur * srf))
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / srf
		var f := f0 + (f1 - f0) * t / dur + 4.0 * V8.js_sin(TAU * 7.0 * t) + 3.0 * (rng.next() - 0.5)
		ph += f / srf
		var s := 0.0
		for k in range(1, 14):
			s += V8.js_sin(TAU * ph * float(k)) / float(k)
		src[i] = s * Dsp.env_ar(t, 0.06, dur * 0.45, dur) * (0.8 + 0.2 * V8.js_sin(TAU * 23.0 * t))
	for fm: Array in formants:
		var b := Dsp.biquad("bp", float(fm[1]), srf, float(fm[0]))
		for i in n:
			if i0 + i < out.size():
				out[i0 + i] += b.run(src[i]) * float(fm[2])
	Dsp.noise_band(out, SR, rng, { "t0": t0, "dur": dur, "fc": 1400.0, "q": 1.2, "gain": 0.25, "am": 0.6, "am_rate": f0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.05, dur * 0.4, dur) })
