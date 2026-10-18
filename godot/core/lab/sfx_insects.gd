## Tribología biológica · sonidos de los aguijones (modelo 2.0; no existen en la 1.x).
##
## - El zumbido de cada especie a su frecuencia de aleteo (stinger.wingbeat de insects.gd: Herrera et al. 2023, sensor
##   óptico; ~230 Hz en la abeja también en Altshuler et al. 2005). Es un bucle de LOOP_S s con el fundamental y sus
##   armónicos: los niveles relativos de los armónicos son los del sensor (luz que cortan las alas, no presión sonora:
##   una guía para el timbre, docs/fisica/aguijones.md §7.8). Para que el bucle cierre sin salto, el fundamental se
##   redondea a múltiplos de 1/LOOP_S Hz (0,5 Hz: menos de un 0,3 % de error, muy por debajo de la dispersión medida, de
##   ±10 a ±30 Hz); el vibrato (±0,8 %) y el latido de la amplitud también son periódicos en el bucle. Un poco de soplo
##   (ruido rosa filtrado que late con cada aletazo) le quita el aire de órgano. La hormiga bala no tiene alas y de
##   Pepsis no hay medida: no zumban.
## - Efectos cortos: el picotazo (la punta rompe la piel), el desgarro del aparato del aguijón cuando la abeja se va
##   (autotomía) y el pandeo de un aguijón que se dobla. Son diseño de sonido, no medidas.
## - sfx_for_result: el efecto de un resultado en la 2.0: el de los aguijones y, para todo lo demás, el de la 1.x
##   (sfx.gd, el oráculo).
## Todo se hornea una vez (tools/bake_lab_extra.gd) en res://assets/sfx/lab/, junto a los 22 WAV de la 1.x: en tiempo
## real no se sintetiza nada; la interfaz reproduce el bucle y mueve su volumen y su tono. Determinista: el azar sale de
## rng.gd con una semilla por efecto, los senos directos son los de V8 (v8_math.gd) y el resto, los bloques de dsp.gd.
## Uso: const SfxInsects = preload("res://core/lab/sfx_insects.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Insects = preload("res://core/lab/insects.gd")

const SR := Sfx.SFX_RATE
const STING := "picotazo"
const TEAR := "desgarro-aguijon"
const BEND := "pandeo-aguijon"
const BUZZ_PREFIX := "zumbido-"
## Duración de cada bucle de zumbido (s) y paso al que se redondea su fundamental (Hz) para que cierre.
const LOOP_S := 2.0
const HZ_STEP := 1.0 / LOOP_S
## Vibrato del aleteo: ±0,8 % a 1,5 Hz (periódico en el bucle; con más, las bandas laterales se comen el fundamental);
## latido de la amplitud: ±8 % a 2,5 Hz.
const VIBRATO := 0.008
const VIBRATO_HZ := 1.5
const TREMOLO := 0.08
const TREMOLO_HZ := 2.5
## Valor eficaz del bucle y del soplo frente a los armónicos.
const BUZZ_RMS := 0.14
const BREATH := 0.22
## Muestras de fundido en la costura del soplo.
const XFADE := 3308
## Los vidrios de coche de la 2.0 (glazing.gd) suenan como el vidrio de ventana (su aspecto en Looks.MATERIAL_LOOK).
const GLASS := { "id": "vidrio" }


## Ids de los zumbidos: uno por especie con frecuencia de aleteo medida, en el orden del catálogo.
static func buzz_ids() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in Insects.STINGERS:
		if s.stinger.wingbeat.get("hz") != null:
			out.append(BUZZ_PREFIX + String(s.id))
	return out


## Todos los efectos que se hornean: los zumbidos y los tres efectos cortos.
static func ids() -> Array[String]:
	var out := buzz_ids()
	out.append_array([STING, TEAR, BEND])
	return out


## ¿Es un bucle (el zumbido) o un efecto de una vez?
static func is_loop(id: String) -> bool:
	return id.begins_with(BUZZ_PREFIX)


## Zumbido de un aguijón del catálogo ("" si la especie no zumba: sin alas o sin medida).
static func buzz_id(claw: Variant) -> String:
	if not Insects.is_stinger(claw) or claw.stinger.wingbeat.get("hz") == null:
		return ""
	return BUZZ_PREFIX + String(claw.id)


## Especie de un zumbido ("zumbido-abeja" → la entrada de insects.gd).
static func species_of(id: String) -> Dictionary:
	return Insects.find_by_id(id.trim_prefix(BUZZ_PREFIX))


## Fundamental del bucle (Hz): el aleteo medido redondeado a HZ_STEP (231,5 → 231,5; 165,8 → 166).
static func loop_hz(claw: Dictionary) -> float:
	return Js.js_round(float(claw.stinger.wingbeat.hz) / HZ_STEP) * HZ_STEP


## El efecto de un resultado en la 2.0: con un aguijón, el picotazo, el pandeo o el roce de la punta que cede; con todo
## lo demás, el de la 1.x (Sfx.sfx_for_result, igual que el oráculo), salvo los materiales de la 2.0
## (docs/fisica/pulido-materiales.md §7.7): la uña que se dobla («SE DOBLA LA UÑA») cruje como una aguja que se dobla (el
## pandeo); la que se parte suena a punta rota (el de la 1.x, por toolBroken); los vidrios de coche suenan a vidrio y el
## parabrisas que se agrieta sin caer, a vidrio que cruje. Y los de la biología (pulido-biologia.md §9.7), con los efectos
## que ya había: la punta que marca el hueso o lo atraviesa suena a punción en un sólido («pierce-solid») y la que el hueso
## detiene sin marcarla, a una pared que la para («press»); el colmillo que se rompe contra él, a punta rota («snap», el de
## la 1.x por toolBroken).
static func sfx_for_result(res: Dictionary, target: Dictionary) -> String:
	var s: Variant = res.get("sting")
	if s is Dictionary:
		if Js.truthy(res.get("toolBroken")):
			return BEND
		if Js.truthy(res.get("skin")):
			return STING if s.get("pierces") == true else "press"
		if s.get("tipCrushed") == true:
			return "press"
	var nail: Variant = res.get("nail")
	if nail is Dictionary and Js.truthy(res.get("toolBroken")) and nail.get("mode") == "dobla":
		return BEND
	var glazing: Variant = res.get("glazing")
	if glazing is Dictionary:
		if glazing.get("kind") == "laminado" and glazing.get("cracked") == true and Js.truthy(res.get("puncture")):
			return "pierce-brittle"
		return Sfx.sfx_for_result(res, GLASS)
	var bone := bone_sfx(res)
	if bone != "":
		return bone
	return Sfx.sfx_for_result(res, target)


## El efecto de la punta contra el hueso al punzar la piel ("" si no llega a él o si el colmillo se rompe, que suena a punta
## rota): «pierce-solid» si lo marca (pen.boneIndentUm > 0) o lo atraviesa; «press» si el hueso la detiene sin marcarla.
static func bone_sfx(res: Dictionary) -> String:
	var pen: Variant = res.get("pen")
	if not (pen is Dictionary) or not Js.truthy(res.get("puncture")) or pen.get("boneHit") != true or Js.truthy(res.get("toolBroken")):
		return ""
	var indent := float(pen.boneIndentUm) if pen.get("boneIndentUm") != null else 0.0
	return "pierce-solid" if indent > 0.0 or pen.get("bonePierced") == true else "press"


## Bytes del WAV de un efecto (PCM de 16 bits, mono, SR Hz; los zumbidos, con su cola: Sfx.with_loop_tail).
static func wav_bytes(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(render(id)) if is_loop(id) else render(id), SR)


## Muestras de un efecto, en [−1, 1].
static func render(id: String) -> PackedFloat32Array:
	if is_loop(id):
		return _buzz(species_of(id))
	match id:
		STING:
			return _sting()
		TEAR:
			return _tear()
		BEND:
			return _bend()
	push_error("SfxInsects: efecto desconocido «%s»" % id)
	return PackedFloat32Array()


# ── Recetas ──

## Zumbido: armónicos del aleteo con vibrato y latido periódicos, más el soplo de las alas.
static func _buzz(claw: Dictionary) -> PackedFloat32Array:
	var wb: Dictionary = claw.stinger.wingbeat
	var n := int(Js.js_round(LOOP_S * SR))
	var f0 := loop_hz(claw)
	var rng := Rng.from_text("lab:zumbido:" + String(claw.id))
	var db: Array = wb.powersDb
	var amps: Array = []
	for k in db.size():
		amps.append(V8.js_pow(10.0, (float(db[k]) - float(db[0])) / 20.0))
	var phases: Array = []
	for k in amps.size():
		phases.append(rng.next() * TAU)
	# fase del fundamental con vibrato: 2π·f0·t + β·sin(2π·fv·t), β = Δf/fv; en t = LOOP_S vuelve a un múltiplo de 2π
	var beta := VIBRATO * f0 / VIBRATO_HZ
	var tone := PackedFloat32Array()
	tone.resize(n)
	for i in n:
		var t := float(i) / SR
		var ph := TAU * f0 * t + beta * V8.js_sin(TAU * VIBRATO_HZ * t)
		var am := 1.0 + TREMOLO * V8.js_sin(TAU * TREMOLO_HZ * t + 0.7)
		var x := 0.0
		for k in amps.size():
			x += float(amps[k]) * V8.js_sin((k + 1) * ph + float(phases[k]))
		tone[i] = x * am
	Dsp.scale(tone, BUZZ_RMS / maxf(Dsp.rms(tone), 1e-12))
	# soplo: ruido rosa entre 1,5·f0 y 8·f0 que late con cada aletazo (envolvente periódica en f0)
	var nz := Dsp.pink(n + XFADE, rng)
	Dsp.filter_all(nz, "hp", 1.5 * f0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 8.0 * f0, 0.7, SR)
	for i in nz.size():
		var w := 0.5 - 0.5 * V8.js_cos(TAU * f0 * float(i) / SR)
		nz[i] *= 0.35 + 0.65 * w * w
	var breath := Dsp.loop_crossfade(nz, n)
	Dsp.scale(breath, BREATH * BUZZ_RMS / maxf(Dsp.rms(breath), 1e-12))
	Dsp.mix_into(tone, breath)
	return tone


## Picotazo: un chasquido agudo y breve (la punta rompe la capa córnea) y un golpecito sordo de la piel.
static func _sting() -> PackedFloat32Array:
	var rng := Rng.from_text("lab:" + STING)
	var out := _zeros(0.22)
	Dsp.clicks(out, SR, rng, { "t0": 0.004, "dur": 0.006, "rate": 170.0, "q": 2.5, "gain": 1.0, "len": 0.0016,
		"fc": func(r: float) -> float: return 5200.0 + r * 1800.0 })
	Dsp.noise_band(out, SR, rng, { "t0": 0.004, "dur": 0.09, "fc": 4200.0, "q": 0.9, "type": "hp", "gain": 0.28,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.022) })
	Dsp.modal(out, SR, { "t0": 0.005, "partials": [[260.0, 0.014, 0.55], [610.0, 0.007, 0.25]], "gain": 0.9 })
	return Dsp.finish(out, 0.78)


## Desgarro del aparato del aguijón: crujidos húmedos que se aceleran, un ruido que baja de tono y un «plop» final.
static func _tear() -> PackedFloat32Array:
	var rng := Rng.from_text("lab:" + TEAR)
	var out := _zeros(0.46)
	Dsp.clicks(out, SR, rng, { "t0": 0.01, "dur": 0.28, "rate": 95.0, "q": 3.0, "gain": 0.8, "len": 0.003,
		"fc": func(r: float) -> float: return 700.0 + r * 1900.0 })
	Dsp.noise_band(out, SR, rng, { "t0": 0.02, "dur": 0.32, "q": 1.6, "gain": 0.55, "am": 0.5, "am_rate": 45.0,
		"fc": func(t: float) -> float: return 2400.0 - 5500.0 * t,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.03, 0.2, 0.32) })
	Dsp.modal(out, SR, { "t0": 0.3, "partials": [[170.0, 0.03, 0.5], [340.0, 0.015, 0.2]], "gain": 0.8 })
	return Dsp.finish(out, 0.72)


## Pandeo: el crujido de una aguja que se dobla (un tono que baja con rozamiento a saltos) y un clic al empezar.
static func _bend() -> PackedFloat32Array:
	var rng := Rng.from_text("lab:" + BEND)
	var out := _zeros(0.4)
	Dsp.clicks(out, SR, rng, { "t0": 0.004, "dur": 0.004, "rate": 250.0, "q": 3.0, "gain": 0.7, "len": 0.002,
		"fc": func(r: float) -> float: return 3000.0 + r * 1000.0 })
	Dsp.tone(out, SR, { "t0": 0.01, "dur": 0.34, "shape": "tri", "gain": 0.3,
		"f": func(t: float) -> float: return 560.0 - 480.0 * t,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.02, 0.18, 0.34) })
	Dsp.noise_band(out, SR, rng, { "t0": 0.01, "dur": 0.34, "fc": 1300.0, "q": 5.0, "gain": 0.5, "am": 0.7,
		"am_rate": 32.0, "env": func(t: float) -> float: return Dsp.env_ar(t, 0.02, 0.18, 0.34) })
	return Dsp.finish(out, 0.7)


static func _zeros(dur_s: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(Js.js_round(dur_s * SR)))
	return a
