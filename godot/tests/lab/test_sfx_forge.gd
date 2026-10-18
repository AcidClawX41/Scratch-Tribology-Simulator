## Sonidos de la reforja (core/lab/sfx_forge.gd, horneados con tools/bake_lab_extra.gd en assets/sfx/lab/, unidad 5f):
## son los siete ids de ClawForge.SFX_FORGE; los del repositorio están al día y hornear da siempre los mismos bytes; los
## bucles cierran sin salto y nada satura; cada uno suena como dice su diseño (el horno a 100 Hz, la bobina a 1500 Hz, el
## rizado de la bomba de la prensa a 216 Hz, el roce de la muela late con cada vuelta, la llama ruge en graves y parpadea,
## el temple entra de golpe y se apaga, la colada chisporrotea); los bucles se importan en bucle y sin comprimir; y el
## análisis de cada WAV (valor eficaz, pico y bandas) queda escrito en la salida de los tests.
extends "res://tests/case.gd"

const SfxForge = preload("res://core/lab/sfx_forge.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Bake = preload("res://tools/bake_lab_extra.gd")
const Js = preload("res://core/shared/js.gd")

const SR := SfxForge.SR

var _renders := {}


func _render(id: String) -> PackedFloat32Array:
	if not _renders.has(id):
		_renders[id] = SfxForge.render(id)
	return _renders[id]


## Los bytes que hornea tools/bake_lab_extra.gd: los bucles, con su cola (Sfx.with_loop_tail).
func _baked(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(_render(id)) if SfxForge.is_loop(id) else _render(id), SR)


static func _sha256(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


## Potencia de x a la frecuencia f (Goertzel, con ventana de Hann).
static func _goertzel(x: PackedFloat32Array, f: float) -> float:
	var n := x.size()
	var w := TAU * f / SR
	var coeff := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in n:
		var hann := 0.5 - 0.5 * cos(TAU * i / (n - 1))
		var s := x[i] * hann + coeff * s1 - s2
		s2 = s1
		s1 = s
	return s1 * s1 + s2 * s2 - coeff * s1 * s2


## Potencia de x en una banda [f0, f1]: el cuadrado del valor eficaz después de dos pasos altos en f0 y dos pasos bajos en
## f1 (recoge igual los tonos puros y el ruido).
static func _band(x: PackedFloat32Array, f0: float, f1: float) -> float:
	var y := x.duplicate()
	for k in 2:
		Dsp.filter_all(y, "hp", f0, 0.7071, SR)
		Dsp.filter_all(y, "lp", f1, 0.7071, SR)
	var r := Dsp.rms(y)
	return r * r


## La envolvente (valor absoluto, alisada con un paso bajo de 1 kHz).
static func _env(x: PackedFloat32Array) -> PackedFloat32Array:
	var e := PackedFloat32Array()
	e.resize(x.size())
	for i in x.size():
		e[i] = absf(x[i])
	Dsp.filter_all(e, "lp", 1000.0, 0.7, SR)
	return e


func test_son_los_siete_del_motor() -> void:
	assert_eq(Array(SfxForge.ids()), ClawForge.SFX_FORGE, "los mismos ids que pide el motor, en su orden")
	assert_eq(SfxForge.ids().filter(func(id: String) -> bool: return SfxForge.is_loop(id)), [SfxForge.MUELA, SfxForge.HORNO, SfxForge.LLAMA, SfxForge.INDUCCION, SfxForge.PRENSA], "las máquinas y la muela, en bucle")


func test_cada_uno_suena_como_su_diseno() -> void:
	var horno := _render(SfxForge.HORNO)
	assert_true(_goertzel(horno, 100.0) > 30.0 * _goertzel(horno, 150.0), "el horno zumba a 100 Hz (el doble de la red)")
	var ind := _render(SfxForge.INDUCCION)
	assert_true(_goertzel(ind, 1500.0) > 30.0 * _goertzel(ind, 1250.0), "la bobina silba a 1500 Hz")
	var prensa := _render(SfxForge.PRENSA)
	assert_true(_goertzel(prensa, 216.0) > 30.0 * _goertzel(prensa, 180.0), "la bomba de la prensa: 24 Hz por 9 dientes = 216 Hz")
	var muela := _render(SfxForge.MUELA)
	var em := _env(muela)
	assert_true(_goertzel(em, SfxForge.WHEEL_HZ) > 8.0 * _goertzel(em, SfxForge.WHEEL_HZ * 1.37), "el roce de la muela late con cada vuelta (48,5 Hz)")
	var llama := _render(SfxForge.LLAMA)
	assert_true(_band(llama, 200.0, 800.0) > 3.0 * _band(llama, 3000.0, 6000.0), "la llama ruge en graves")
	var el := _env(llama)
	assert_true(_goertzel(el, 3.0) > 5.0 * _goertzel(el, 4.25), "y parpadea (3 Hz)")
	var temple := _render(SfxForge.TEMPLE)
	var q := int(0.15 * SR)
	assert_true(Dsp.rms(temple.slice(0, q)) > 4.0 * Dsp.rms(temple.slice(temple.size() - q)), "el temple entra de golpe y se apaga")
	assert_true(_band(temple.slice(0, int(0.5 * SR)), 2000.0, 8000.0) > _band(temple.slice(0, int(0.5 * SR)), 100.0, 600.0), "con un siseo agudo")
	var colada := _render(SfxForge.COLADA)
	var c0 := colada.slice(0, int(0.2 * SR))
	var c1 := colada.slice(int(0.3 * SR), int(0.8 * SR))
	assert_true(_band(c1, 2000.0, 8000.0) > 2.0 * _band(c0, 2000.0, 8000.0), "la colada chisporrotea al tocar el molde")


func test_los_bucles_cierran_sin_salto_y_sin_saturar() -> void:
	for id in SfxForge.ids():
		var x := _render(id)
		var pk := Dsp.peak(x)
		assert_true(pk > 0.1 and pk < 0.95, "%s: pico %s (se oye y no satura)" % [id, pk])
		if not SfxForge.is_loop(id):
			assert_eq(x.size(), int(Js.js_round(float(SfxForge.ONE_SHOT_S[id]) * SR)), "%s: su duración" % id)
			continue
		var n := x.size()
		assert_eq(n, int(SfxForge.LOOP_S * SR), "%s: %s s" % [id, SfxForge.LOOP_S])
		assert_near(Dsp.rms(x), float(SfxForge.RMS[id]), 1e-5, 0.0, "%s: su valor eficaz" % id)
		var d := PackedFloat32Array()
		d.resize(n - 1)
		for i in n - 1:
			d[i] = absf(x[i + 1] - x[i])
		d.sort()
		var p999: float = d[int(0.999 * (n - 2))]
		var seam := absf(x[0] - x[n - 1])
		assert_true(seam <= p999, "%s: salto en la costura (%s) mayor que el 99,9 %% de los saltos (%s)" % [id, seam, p999])


func test_hornear_dos_veces_da_los_mismos_bytes() -> void:
	for id in SfxForge.ids():
		assert_eq(_sha256(SfxForge.wav_bytes(id)), _sha256(_baked(id)), "%s: sha256 de dos horneados" % id)


func test_wav_del_repo_al_dia() -> void:
	for id in SfxForge.ids():
		var path := Sfx.path_of(id)
		assert_true(FileAccess.file_exists(path), "%s existe" % path)
		var disk := FileAccess.get_file_as_bytes(path)
		assert_eq(_sha256(disk), _sha256(_baked(id)), "%s al día (vuelve a hornear con tools/bake_lab_extra.gd)" % id)


func test_importados_en_bucle() -> void:
	for id in SfxForge.ids():
		var s := load(Sfx.path_of(id)) as AudioStreamWAV
		assert_true(s != null, "%s se importa como AudioStreamWAV" % id)
		if s == null:
			continue
		assert_eq(s.mix_rate, SR, "%s: 22.050 Hz" % id)
		if SfxForge.is_loop(id):
			assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "%s: sin comprimir (la costura no salta)" % id)
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: bucle hacia delante" % id)
			assert_eq(s.loop_end, s.data.size() / 2 - Sfx.LOOP_TAIL, "%s: el bucle acaba en su última muestra; detrás, la cola" % id)
			for i in Sfx.LOOP_TAIL:
				if s.data.decode_s16((s.loop_end + i) * 2) != s.data.decode_s16(i * 2):
					fail("%s: la muestra %d de la cola no repite la %d del principio" % [id, s.loop_end + i, i])
					break
		else:
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s: una vez" % id)
	assert_eq(Bake.import_params(100, true)["edit/loop_mode"], "2", "los bucles, hacia delante")


## El análisis de cada WAV para el informe: valor eficaz, pico y la energía en cuatro bandas (dB respecto a la mayor).
func test_analisis_de_los_wav() -> void:
	var bands := [[60.0, 250.0], [250.0, 1000.0], [1000.0, 4000.0], [4000.0, 10000.0]]
	for id in SfxForge.ids():
		var x := Dsp.encode_wav(_render(id), SR).slice(44)
		var pcm := PackedFloat32Array()
		pcm.resize(x.size() / 2)
		for i in pcm.size():
			pcm[i] = float(x.decode_s16(i * 2)) / 32767.0
		var e: Array = []
		var top := 0.0
		for b: Array in bands:
			var v := _band(pcm, float(b[0]), float(b[1]))
			e.append(v)
			top = maxf(top, v)
		var db: Array = e.map(func(v: float) -> String: return "%s dB" % Js.to_fixed(10.0 * log(maxf(v, 1e-30) / top) / log(10.0), 1))
		print("    (análisis) %s: %s s · eficaz %s · pico %s · bandas 60-250 / 250-1k / 1-4k / 4-10k Hz: %s" % [id, Js.to_fixed(float(pcm.size()) / SR, 2), Js.to_fixed(Dsp.rms(pcm), 3), Js.to_fixed(Dsp.peak(pcm), 3), ", ".join(db)])
		assert_true(Dsp.rms(pcm) > 0.03, "%s: se oye" % id)
