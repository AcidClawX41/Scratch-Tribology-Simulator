## Vibración del teléfono (app/common/haptics.gd): un pulso por efecto de sonido, con el estilo de los hápticos de la 1.x
## móvil (apps/mobile/src/sound.js); solo en móvil y si el usuario no la apaga ([lab] haptics en ajustes.cfg, con un
## archivo temporal). En escritorio se prueba con una vibración de mentira que apunta los pulsos (haptics_spy.gd).
extends "res://tests/case.gd"

const Haptics = preload("res://app/common/haptics.gd")
const HapticsSpy = preload("res://tests/app/haptics_spy.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const CFG := "user://test_lab_vibracion.cfg"
## Estilo de cada efecto en la 1.x (sound.js → HAPTIC): selectionAsync, impactAsync(estilo) o notificationAsync(tipo).
const STYLE_1X := {
	"tap": "selection", "on": "selection", "off": "selection", "drip": "selection",
	"slide": "soft", "squeak": "soft", "skin-rub": "soft", "press": "soft",
	"scratch-soft": "light", "scratch-wood": "light", "skin-cut": "medium",
	"scratch-metal": "rigid", "scratch-glass": "rigid", "scratch-deep": "heavy",
	"pierce": "medium", "inject": "medium", "pierce-solid": "heavy",
	"pierce-brittle": "rigid", "breakthrough": "heavy",
	"shatter": "warning", "snap": "error", "badge": "success",
}


func before_each() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func _section(spy: Variant = null) -> Control:
	var s: Control = LabSection.instantiate()
	s.settings_path = CFG
	if spy != null:
		s.haptics = spy
	s.setup()
	s.art.threaded = false
	return s


func _cfg(key: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return null
	return c.get_value("lab", key, null)


func test_un_pulso_por_efecto_con_el_estilo_de_la_1x() -> void:
	var style := { "selection": Haptics.SELECTION, "soft": Haptics.SOFT, "light": Haptics.LIGHT, "medium": Haptics.MEDIUM,
		"rigid": Haptics.RIGID, "heavy": Haptics.HEAVY, "success": Haptics.SUCCESS, "warning": Haptics.WARNING,
		"error": Haptics.ERROR }
	# los 22 efectos de la 1.x y los tres efectos cortos de los aguijones de la 2.0 (el zumbido, un bucle, no vibra)
	var extra: Array = []
	for id: String in SfxInsects.ids():
		if not SfxInsects.is_loop(id):
			extra.append(id)
	assert_eq(extra, [SfxInsects.STING, SfxInsects.TEAR, SfxInsects.BEND], "efectos cortos de la 2.0")
	assert_eq(Haptics.PULSES.size(), Sfx.SFX_IDS.size() + extra.size(), "un pulso por efecto, ni más ni menos")
	assert_eq(Haptics.pulse_for(SfxInsects.STING), Haptics.LIGHT, "el picotazo: un toque ligero")
	assert_eq(Haptics.pulse_for(SfxInsects.TEAR), Haptics.MEDIUM, "el desgarro del aguijón: medio")
	assert_eq(Haptics.pulse_for(SfxInsects.BEND), Haptics.RIGID, "el pandeo: seco")
	for id: String in SfxInsects.buzz_ids():
		assert_eq(Haptics.pulse_for(id), [], "%s: el zumbido no vibra" % id)
	for id: String in Sfx.SFX_IDS:
		var p := Haptics.pulse_for(id)
		assert_eq(p, style[STYLE_1X[id]], "%s: %s, como en la 1.x" % [id, STYLE_1X[id]])
		assert_true(p[0] is int and p[0] >= 5 and p[0] <= 150, "%s: un pulso corto (%s ms)" % [id, p[0]])
		assert_true(p[1] > 0.0 and p[1] <= 1.0, "%s: intensidad de 0 a 1" % id)
	var order := [Haptics.SELECTION, Haptics.SOFT, Haptics.LIGHT, Haptics.MEDIUM, Haptics.HEAVY]
	for i in range(1, order.size()):
		assert_true(order[i][0] * order[i][1] > order[i - 1][0] * order[i - 1][1], "de más suave a más fuerte (%s)" % [order[i]])
	assert_eq(Haptics.pulse_for("no-existe"), [], "un efecto desconocido no vibra")


func test_solo_vibra_en_movil_y_encendida() -> void:
	var real := Haptics.new()
	assert_eq(real.available, OS.has_feature("mobile"), "puede vibrar solo en móvil")
	if not OS.has_feature("mobile"):
		assert_false(real.play("scratch-deep"), "en escritorio no vibra")
	var spy := HapticsSpy.new()
	assert_true(spy.play("scratch-metal"), "en un teléfono, vibra")
	assert_eq(spy.pulses, [Haptics.RIGID])
	spy.enabled = false
	assert_false(spy.play("scratch-metal"), "apagada, no")
	spy.enabled = true
	assert_false(spy.play("no-existe"))
	assert_eq(spy.pulses.size(), 1)


func test_vibra_con_el_resultado_aunque_el_sonido_este_silenciado() -> void:
	var spy := HapticsSpy.new()
	var s := _section(spy)
	# rayado: el efecto (y su pulso) llega al arrancar
	s.run_button.pressed.emit()
	s.step(0.0)
	var sfx := Sfx.sfx_for_result(s.lab.res, s.lab.target)
	assert_eq(spy.pulses, [Haptics.pulse_for(sfx)], "rayado: el pulso de su efecto (%s), al arrancar" % sfx)
	var badges: int = s.lab.badges.size()
	s.step(LabState.RUN_MS + 200.0)
	if badges > 0:
		assert_eq(spy.pulses[-1], Haptics.SUCCESS, "un logro nuevo: el pulso de la fanfarria")
	# punción: al impactar, con el sonido silenciado
	s.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "vibora"))
	s.lab.set_target(Catalog.find_by_id(Catalog.TARGETS, "piel"))
	s.lab.set_method("puncion")
	assert_eq(spy.pulses[-1], Haptics.SELECTION, "cada selección, un toque suave (el clic de la interfaz)")
	spy.pulses.clear()
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, true)
	s.run()
	assert_true(bool(s.lab.res.puncture), "es una punción")
	s.step(LabState.RUN_MS * 0.5)
	assert_eq(spy.pulses, [], "todavía no ha llegado al impacto")
	s.step(LabState.RUN_MS * 0.3)
	AudioServer.set_bus_mute(master, false)
	assert_eq(spy.pulses.size(), 1, "vibra al impactar, aunque no suene")
	assert_eq(spy.pulses[0], Haptics.pulse_for(Sfx.sfx_for_result(s.lab.res, s.lab.target)))
	s.free()


func test_interruptor_de_la_vibracion_y_ajuste() -> void:
	var app := ConfigFile.new()
	app.set_value("app", "sound", false)
	app.save(CFG)
	var desk := _section()
	desk.refresh_now()
	if not OS.has_feature("mobile"):
		assert_false(desk.badges_card.haptics_button.visible, "en escritorio no hay interruptor de vibración")
		assert_false(desk.badges_card.footer.visible, "ni pie, sin nada que reiniciar")
	desk.free()
	var spy := HapticsSpy.new()
	var s := _section(spy)
	s.refresh_now()
	var btn: Button = s.badges_card.haptics_button
	assert_true(btn.visible and s.badges_card.footer.visible, "en el teléfono, sí")
	assert_eq(btn.text, "Vibración: sí", "encendida por defecto")
	s.run()
	s.step(LabState.RUN_MS + 200.0)
	btn.pressed.emit()
	assert_false(spy.enabled, "apagada")
	assert_eq(btn.text, "Vibración: no")
	assert_eq(_cfg("haptics"), false, "se guarda en [lab]")
	assert_eq(_cfg("count"), 1, "junto al progreso, sin borrarlo")
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	assert_eq(cfg.get_value("app", "sound", null), false, "sin tocar [app]")
	spy.pulses.clear()
	s.lab.set_target(Catalog.find_by_id(Catalog.TARGETS, "vidrio"))
	s.run()
	s.step(LabState.RUN_MS + 200.0)
	assert_eq(spy.pulses, [], "apagada, no vibra")
	s.free()
	var spy2 := HapticsSpy.new()
	var t := _section(spy2)
	t.refresh_now()
	assert_false(spy2.enabled, "al abrir, apagada como se dejó")
	assert_eq(t.badges_card.haptics_button.text, "Vibración: no")
	t.badges_card.haptics_button.pressed.emit()
	assert_true(spy2.enabled, "encendida otra vez")
	assert_eq(spy2.pulses, [Haptics.SELECTION], "con un pulso que lo confirma")
	assert_eq(_cfg("haptics"), true)
	# reiniciar logros y cuaderno no toca la vibración
	t.badges_card.reset_button.pressed.emit()
	t.badges_card.reset_button.pressed.emit()
	t.step(0.0)
	assert_eq([t.lab.count, _cfg("count"), _cfg("haptics")], [0, 0, true], "reiniciar borra el progreso, no el ajuste")
	t.free()
	# un archivo editado a mano con un valor raro: encendida
	var odd := ConfigFile.new()
	odd.set_value("lab", "haptics", "quizá")
	odd.save(CFG)
	var spy3 := HapticsSpy.new()
	var u := _section(spy3)
	assert_true(spy3.enabled, "valor que no se entiende: encendida")
	u.free()
