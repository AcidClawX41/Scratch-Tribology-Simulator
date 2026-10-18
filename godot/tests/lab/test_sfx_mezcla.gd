## La mezcla de la Tribología biológica (core/lab/sfx.gd: KIND y TRIM_DB; app/common/sfx_player.gd; docs/fase2/qa-sonido.md):
## cada WAV de assets/sfx/lab/ tiene su clase; con el volumen con que lo pide el programa y su ajuste, su sonoridad (LUFS
## momentáneos máximos, ponderación K de ITU-R BS.1770, medida aquí sobre el archivo) cae en la banda de su clase y su pico
## no pasa de 0,70; y el reproductor baja un efecto que se apila consigo mismo. Medida aquí sobre el WAV a 22 050 Hz, que
## da lo mismo que Movie Maker después del limitador ± 0,5 dB (docs/fase2/qa-sonido.md), así que la banda lleva ± 1 dB.
extends "res://tests/case.gd"

const Sfx = preload("res://core/lab/sfx.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const SfxPlayer = preload("res://app/common/sfx_player.gd")
const Reaction = preload("res://app/lab/cetreria/reaction/reaction_controller.gd")

## Banda de cada clase (LUFS-M máximos, un canal).
const BAND := {
	"ui": [-30.0, -26.0], "logro": [-24.0, -20.0], "resultado": [-21.0, -17.0], "impacto": [-21.0, -17.0],
	"herramienta": [-26.0, -22.0], "ambiente": [-30.0, -26.0],
}
const TOL_DB := 1.0
const PEAK_MAX := 0.71

## Lo que tarda en calcularse cada archivo: se mide una vez.
var _measured := {}


## [id, volumen] de cada sitio que lo toca (el más fuerte de cada uno). Los de la cetrería y la reforja son los literales de
## care_page.gd (_update_loops), claw_forge_state.gd (sound_view, al máximo de la temperatura) y lab_section.gd (el zumbido,
## BenchInsect.buzz_volume ≤ 0,5).
func _sites() -> Array:
	var v := LabState.DEFAULT_VOLUME
	var out: Array = []
	for id: String in Sfx.SFX_IDS:
		out.append([id, 0.5 if id == "badge" else v])
	out.append_array([["on", 0.6], ["off", 0.6], ["picotazo", v], ["desgarro-aguijon", v], ["pandeo-aguijon", v],
		["lampara-pitido", v], ["forja-colada", v], ["forja-temple", v], ["forja-pulso", v], ["forja-arco", v],
		["torno-garras", 0.5], ["amoladora-garras", 0.5], ["lima-garra", 0.55], ["motor-arranque", 0.6], ["motor-parada", 0.6],
		["forja-horno", 0.8], ["forja-llama", 0.8], ["forja-induccion", 0.8], ["forja-prensa", 0.8], ["forja-muela", 0.6],
		["lente-pano", 0.7], ["lente-plastico", Reaction.VOL_IMPACT], ["lente-vidrio", Reaction.VOL_IMPACT],
		["lente-grieta", Reaction.VOL_IMPACT], ["lente-rasguno", Reaction.VOL_IMPACT]])
	for k: String in ["rapaz", "buho", "tigre", "oso", "raptor"]:
		out.append(["reaccion-" + k, Reaction.VOL_VOICE])
	for f: String in DirAccess.get_files_at(Sfx.SFX_DIR):
		if f.begins_with("zumbido-") and f.ends_with(".wav"):
			out.append([f.get_basename(), 0.5])
	return out


func test_cada_wav_tiene_su_clase_y_su_ajuste_es_moderado() -> void:
	var wavs := Array(DirAccess.get_files_at(Sfx.SFX_DIR)).filter(func(f: String) -> bool: return f.ends_with(".wav"))
	for f: String in wavs:
		assert_true(Sfx.KIND.has(f.get_basename()), "%s tiene clase en Sfx.KIND" % f)
	assert_eq(Sfx.KIND.size(), wavs.size(), "ni sobran ni faltan clases")
	for id: String in Sfx.KIND:
		assert_true(BAND.has(String(Sfx.KIND[id])), "%s: clase conocida (%s)" % [id, Sfx.KIND[id]])
	for id: String in Sfx.TRIM_DB:
		assert_true(Sfx.KIND.has(id), "%s: el ajuste es de un efecto que existe" % id)
		assert_true(absf(float(Sfx.TRIM_DB[id])) <= 8.0, "%s: ajuste moderado (%s dB)" % [id, Sfx.TRIM_DB[id]])
	assert_near(Sfx.gain("breakthrough"), 1.0, 1e-12, 0.0, "sin ajuste, ganancia 1")
	assert_near(Sfx.gain("scratch-metal"), pow(10.0, -5.0 / 20.0), 1e-12, 0.0, "−5 dB")


func test_cada_sonido_cae_en_la_banda_de_su_clase_sin_pasar_el_pico() -> void:
	var rows: Array = []
	for s: Array in _sites():
		var id: String = s[0]
		var m := _measure(id)
		var g := float(s[1]) * Sfx.gain(id)
		var lufs: float = float(m.lufs) + 20.0 * log(g) / log(10.0)
		var peak: float = float(m.peak) * g
		var band: Array = BAND[String(Sfx.KIND[id])]
		rows.append("%s %s · %s LUFS · pico %s" % [id, s[1], String.num(lufs, 1), String.num(peak, 3)])
		assert_true(peak <= PEAK_MAX, "%s a %s: pico %s (≤ %s)" % [id, s[1], peak, PEAK_MAX])
		assert_true(lufs <= float(band[1]) + TOL_DB, "%s a %s: %s LUFS, más fuerte que su clase (%s)" % [id, s[1], lufs, band])
		# por debajo de la banda solo si el pico no deja subirlo más (un chasquido seco, como el picotazo)
		if lufs < float(band[0]) - TOL_DB:
			assert_true(peak >= 0.6, "%s a %s: %s LUFS, más flojo que su clase (%s) y aún con margen de pico (%s)" % [id, s[1], lufs, band, peak])
	print("    (mezcla) ", " | ".join(rows))


func test_el_reproductor_aplica_el_ajuste_y_baja_lo_que_se_apila() -> void:
	var v := LabState.DEFAULT_VOLUME
	assert_near(SfxPlayer.volume_db_for("scratch-metal", v), linear_to_db(v) - 5.0, 1e-9, 1e-9, "el ajuste de la mezcla")
	assert_near(SfxPlayer.volume_db_for("tap", v, 2), linear_to_db(v) + 3.5 + 2.0 * SfxPlayer.STACK_DB, 1e-9, 1e-9,
		"dos copias sonando: 12 dB más bajo")
	assert_true(SfxPlayer.STACK_DB <= -6.0, "cada copia que se apila, al menos 6 dB más baja (la suma no crece)")


## LUFS momentáneos máximos (ventanas de 400 ms cada 50 ms; las que pasan del final, con ceros) y pico del archivo.
func _measure(id: String) -> Dictionary:
	if _measured.has(id):
		return _measured[id]
	var b := FileAccess.get_file_as_bytes(Sfx.path_of(id))
	var sr := b.decode_u32(24)
	var n := (b.size() - 44) / 2
	var x := PackedFloat64Array()
	x.resize(n)
	var peak := 0.0
	for i in n:
		x[i] = float(b.decode_s16(44 + i * 2)) / 32768.0
		peak = maxf(peak, absf(x[i]))
	for c: Array in _k_weighting(float(sr)):
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i in n:
			var y: float = c[0] * x[i] + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = x[i]
			y2 = y1
			y1 = y
			x[i] = y
	var acc := PackedFloat64Array()
	acc.resize(n + 1)
	for i in n:
		acc[i + 1] = acc[i] + x[i] * x[i]
	var w := int(round(0.4 * sr))
	var hop := int(round(0.05 * sr))
	var best := -INF
	var s := 0
	while s < n:
		var q := acc[mini(n, s + w)] - acc[s]
		best = maxf(best, -0.691 + 10.0 * log(q / w + 1e-12) / log(10.0))
		if s + w >= n:
			break
		s += hop
	_measured[id] = { "lufs": best, "peak": peak }
	return _measured[id]


## Los dos filtros de la ponderación K (estante de +4 dB a 1682 Hz y paso alto a 38 Hz) a la frecuencia fs, por la
## transformada bilineal: [b0, b1, b2, a1, a2] normalizados.
static func _k_weighting(fs: float) -> Array:
	var g := 3.999843853973347
	var a := pow(10.0, g / 40.0)
	var w := TAU * 1681.974450955533 / fs
	var al := sin(w) / (2.0 * 0.7071752369554196)
	var c := cos(w)
	var sa := sqrt(a)
	var a0 := (a + 1.0) - (a - 1.0) * c + 2.0 * sa * al
	var shelf := [a * ((a + 1.0) + (a - 1.0) * c + 2.0 * sa * al) / a0, -2.0 * a * ((a - 1.0) + (a + 1.0) * c) / a0,
		a * ((a + 1.0) + (a - 1.0) * c - 2.0 * sa * al) / a0, 2.0 * ((a - 1.0) - (a + 1.0) * c) / a0,
		((a + 1.0) - (a - 1.0) * c - 2.0 * sa * al) / a0]
	var w2 := TAU * 38.13547087602444 / fs
	var al2 := sin(w2) / (2.0 * 0.5003270373238773)
	var c2 := cos(w2)
	var b0 := 1.0 + al2
	var hp := [1.0 / b0, -2.0 / b0, 1.0 / b0, -2.0 * c2 / b0, (1.0 - al2) / b0]
	return [shelf, hp]
