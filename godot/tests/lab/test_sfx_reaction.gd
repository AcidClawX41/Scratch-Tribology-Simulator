## Sonidos de la reacción del animal y de la lente (core/lab/sfx_reaction.gd, unidad 5t-B, horneados con
## tools/bake_lab_extra.gd en assets/sfx/lab/): los del repositorio están al día y hornear da siempre los mismos bytes; nada
## satura ni queda mudo; la voz de cada animal tiene su registro (la rapaz aguda, el tigre y el oso graves) y el vidrio
## suena más agudo y más largo que el plástico.
extends "res://tests/case.gd"

const SfxReaction = preload("res://core/lab/sfx_reaction.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Dsp = preload("res://core/shared/dsp.gd")

const SR := SfxReaction.SR


static func _band(x: PackedFloat32Array, f0: float, f1: float) -> float:
	var y := x.duplicate()
	for k in 2:
		Dsp.filter_all(y, "hp", f0, 0.7071, SR)
		Dsp.filter_all(y, "lp", f1, 0.7071, SR)
	var r := Dsp.rms(y)
	return r * r


func test_los_del_repositorio_estan_al_dia_y_son_deterministas() -> void:
	for id: String in SfxReaction.ids():
		var b := SfxReaction.wav_bytes(id)
		assert_eq(b, SfxReaction.wav_bytes(id), "%s: hornear dos veces da los mismos bytes" % id)
		var path := Sfx.path_of(id)
		assert_true(FileAccess.file_exists(path), "%s: está en assets/sfx/lab" % id)
		if FileAccess.file_exists(path):
			assert_true(FileAccess.get_file_as_bytes(path) == b, "%s: el WAV del repositorio está al día (hornea con tools/bake_lab_extra.gd)" % id)


func test_ni_saturan_ni_quedan_mudos() -> void:
	for id: String in SfxReaction.ids():
		var x := SfxReaction.render(id)
		assert_true(Dsp.peak(x) <= 0.7 and Dsp.peak(x) > 0.3, "%s: el pico (%s) entre 0,3 y 0,7 (margen)" % [id, str(Dsp.peak(x))])
		assert_true(Dsp.rms(x) > 0.01, "%s: suena (valor eficaz %s)" % [id, str(Dsp.rms(x))])
		assert_false(SfxReaction.is_loop(id), "%s: suena una vez" % id)


func test_cada_voz_en_su_registro() -> void:
	var rapaz := SfxReaction.render("reaccion-rapaz")
	var tigre := SfxReaction.render("reaccion-tigre")
	var oso := SfxReaction.render("reaccion-oso")
	assert_true(_band(rapaz, 1500.0, 4000.0) > _band(rapaz, 60.0, 500.0) * 4.0, "la rapaz chilla agudo")
	assert_true(_band(tigre, 60.0, 800.0) > _band(tigre, 3000.0, 8000.0), "el tigre gruñe grave")
	assert_true(_band(oso, 60.0, 900.0) > _band(oso, 3000.0, 8000.0), "el oso resopla y gruñe grave")
	var vidrio := SfxReaction.render("lente-vidrio")
	var plastico := SfxReaction.render("lente-plastico")
	assert_true(_band(vidrio, 3000.0, 10000.0) / maxf(Dsp.rms(vidrio) * Dsp.rms(vidrio), 1e-12) > _band(plastico, 3000.0, 10000.0) / maxf(Dsp.rms(plastico) * Dsp.rms(plastico), 1e-12), "el vidrio tintinea más agudo que el plástico")
	assert_true(vidrio.size() > plastico.size(), "y más largo")


## La voz del animal y el golpe en la lente suenan a la vez: con los volúmenes de la escena (reaction_controller.gd), su suma
## en el peor caso (los dos picos juntos) no pasa de ~0,8: no satura.
func test_la_voz_y_el_golpe_juntos_no_saturan() -> void:
	var ctl: GDScript = load("res://app/lab/cetreria/reaction/reaction_controller.gd")
	var consts := ctl.get_script_constant_map()
	var vol_voice := float(consts.VOL_VOICE)
	var vol_impact := float(consts.VOL_IMPACT)
	var voice := 0.0
	var hit := 0.0
	for id: String in SfxReaction.ids():
		var p := Dsp.peak(SfxReaction.render(id))
		if id.begins_with("reaccion-"):
			voice = maxf(voice, p)
		elif id != "lente-pano":
			hit = maxf(hit, p)
	assert_true(voice * vol_voice + hit * vol_impact <= 0.82, "la suma de los picos (%s), con margen" % str(voice * vol_voice + hit * vol_impact))
