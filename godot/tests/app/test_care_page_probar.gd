## «Probar la punta» en la página de la cetrería (unidad 5g; lo pidió la 5b): un botón con su nombre y su ayuda y la tecla T
## mandan ClawCareState.probe_tip al estado, sin hacer física en la página; la ayuda de las teclas lo dice. Y el hilo del
## estado acepta la vuelta de la reforja (reforge_with, para el flujo de la garra rota de la 5f).
extends "res://tests/case.gd"

const CarePage = preload("res://app/lab/cetreria/care_page.gd")
const CareRunner = preload("res://app/lab/cetreria/care_runner.gd")
const State = preload("res://core/lab/claw_care_state.gd")


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


static func _probes(st: State) -> int:
	return st.calls.filter(func(c: Array) -> bool: return String(c[0]) == "probe_tip").size()


func test_probar_la_punta_desde_la_pagina() -> void:
	var p := CarePage.new()
	p.setup()
	p.active = true
	var st: State = p.runner.state
	assert_true(p.probe_pill != null and String(p.probe_pill.accessibility_name) == "Probar la punta", "el botón, con su nombre")
	assert_true(String(p.probe_pill.tooltip_text).contains("tecla T") or String(p.probe_pill.accessibility_description).contains("tecla T"), "y su ayuda dice la tecla")
	assert_true(CarePage.HELP_KEYS.contains("T: probar la punta"), "la ayuda de las teclas lo dice")
	p.probe_pill.pressed.emit()
	assert_eq(_probes(st), 1, "el botón manda probe_tip")
	assert_true(String(st.view().texts.action).begins_with("La punta"), "y el estado dice qué ha pasado")
	assert_false(String(st.view().notice).begins_with("La punta"), "una vez, sin repetirlo en el aviso")
	assert_true(p.handle_key(_key(KEY_T)), "T")
	assert_eq(_probes(st), 2, "la tecla T, también")
	p.dispose()
	p.free()


func test_el_hilo_acepta_las_ordenes_nuevas() -> void:
	for op: String in ["probe_tip", "reforge_with"]:
		assert_true(CareRunner.OPS.has(op), "%s: una orden del estado" % op)
		assert_true(State.new().has_method(op), "%s: un método de ClawCareState" % op)
