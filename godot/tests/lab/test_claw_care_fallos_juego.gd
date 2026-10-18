## Cetrería · fallos de jugabilidad que vio Eric en la Beta 9 (04-10-2026):
## - la garra cortada «volvía a crecer sola» tras el hemostático: era la rueda del ratón, que al bajar por el panel movía el
##   deslizador «Días sin desgaste» y empezaba otra garra sin avisar. Los deslizadores ya no responden a la rueda, un mismo
##   valor no empieza otra garra y cambiarlo a propósito lo avisa;
## - el hemostático no decía cuánto faltaba, y un temblor del ratón fuera de la silueta de la garra paraba el tiempo.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_care_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")

const FRAME := 1.0 / 60.0


## Corta con la tenaza 1 mm por dentro de la carne viva (sangra) y devuelve el estado.
static func _bleeding_claw() -> State:
	var st := State.new({ "animal": "rapaz" })
	st.set_sedation("capucha")
	st.pick("tenaza")
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0))
	for i in 30:
		st.tick(0.05)
	st.release()
	return st


## La rueda del ratón desplaza el panel y no el deslizador (el de los días sin desgaste empezaba otra garra).
func test_la_rueda_no_mueve_los_deslizadores() -> void:
	var vs := ValueSlider.new("Días sin desgaste", "", 0.0, 365.0, 5.0)
	assert_false(vs.slider.scrollable, "la rueda del ratón no cambia el deslizador")
	vs.free()


## Cortada hasta sangrar, la garra se queda cortada después del hemostático y del tiempo: no vuelve a crecer sola.
func test_la_garra_cortada_no_vuelve_a_crecer() -> void:
	var st := _bleeding_claw()
	var cut_mm := st.care.apex_mm()
	assert_true(bool(st.care.snapshot().bleeding.active), "cortada por dentro de la carne viva, sangra")
	st.set_time_scale(10.0)
	st.pick("hemostatico")
	st.press_on(cut_mm - 0.3)
	for i in 80:
		st.tick(0.05)
	st.release()
	assert_false(bool(st.care.snapshot().bleeding.active), "con el polvo y presión, para")
	st.set_time_scale(1.0)
	for i in 100:
		st.tick(0.05)
	assert_near(st.care.apex_mm(), cut_mm, 1e-9, 1e-12, "la garra sigue cortada")
	# soltar el deslizador sin moverlo (el mismo valor) no empieza otra garra
	st.set_overgrowth_days(float(st.setup.overgrowth_days))
	assert_near(st.care.apex_mm(), cut_mm, 1e-9, 1e-12, "el mismo valor de días no cambia la garra")
	# cambiarlo a propósito sí, y lo avisa
	st.set_overgrowth_days(float(st.setup.overgrowth_days) + 5.0)
	assert_true(st.care.apex_mm() > cut_mm, "otros días: otra garra, entera")
	assert_true(String(st.view().get("notice", "")).contains("Garra nueva"), "y el aviso lo dice: %s" % String(st.view().get("notice", "")))


## El texto del hemostático dice cuánto lleva y cuánto hace falta (30 s con el polvo; 300 s con la gasa sola).
func test_el_hemostatico_dice_cuanto_falta() -> void:
	var st := _bleeding_claw()
	st.pick("hemostatico")
	st.press_on(st.care.apex_mm() - 0.3)
	for i in int(round(5.0 / FRAME)):
		st.drag(0.0, 0.0, st.care.apex_mm() - 0.3, FRAME)
		st.tick(FRAME)
	st.release()
	var txt := st.action_text()
	var goal := int(CareData.HEMOSTASIS.agent_s.value)
	assert_true(txt.contains("con el polvo") and txt.contains("de %d s" % goal), "cuánto hace falta con el polvo: %s" % txt)
	var st2 := _bleeding_claw()
	st2.pick("presion")
	st2.press_on(st2.care.apex_mm() - 0.3)
	for i in 60:
		st2.tick(FRAME)
	st2.release()
	assert_true(st2.action_text().contains("de %d s" % int(CareData.HEMOSTASIS.pressure_s.value)), "y con la gasa sola: %s" % st2.action_text())


## Un temblor del ratón fuera de la silueta de la garra no aparta la gasa: el tiempo de presión sigue contando.
func test_un_temblor_no_aparta_la_gasa() -> void:
	var st := _bleeding_claw()
	st.pick("hemostatico")
	var s0 := st.care.apex_mm() - 0.3
	st.press_on(s0)
	for i in 60:
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	var need_a := float(st.care.snapshot().bleeding.needS)
	# el puntero se sale de la garra (s = −1) con el botón aún pulsado
	for i in 120:
		st.drag(0.3, 0.3, -1.0, FRAME)
		st.tick(FRAME)
	var need_b := float(st.care.snapshot().bleeding.needS)
	st.release()
	assert_true(need_b < need_a - 1.5, "fuera de la silueta sigue apretando: faltaban %s s y ahora %s s" % [need_a, need_b])


## Una garra reforjada es materia inerte: no crece (Eric, 12-10-2026). Sin crecimiento de más con ningún número de días;
## cambiar los días no empieza otra garra; y los textos y la tabla de valores lo dicen.
func test_una_garra_reforjada_no_crece() -> void:
	for inlay: String in ["oro", "acero", "zafiro", "diamante"]:
		var st := State.new({ "animal": "rapaz", "inlay": inlay, "overgrowth_days": 180.0 })
		var c: Dictionary = st.care.snapshot().claw
		assert_near(float(c.startMm), float(c.naturalMm), 1e-9, 1e-12, "%s: empieza con su largo natural, sin crecimiento de más" % inlay)
		var apex := st.care.apex_mm()
		st.set_overgrowth_days(365.0)
		assert_near(st.care.apex_mm(), apex, 1e-9, 1e-12, "%s: más días no la alargan" % inlay)
		var sn: Dictionary = st.care.snapshot()
		var txt: Dictionary = st.texts(sn, st.care.report(), false)
		assert_true(String(txt.overgrowth).contains("no crece"), "%s: el texto lo dice: %s" % [inlay, String(txt.overgrowth)])
		var rows := State.values_for(st.setup)
		var growth_row: Dictionary = rows.filter(func(r: Dictionary) -> bool: return String(r.get("label", r.get("name", ""))).begins_with("Crecimiento"))[0]
		assert_true(str(growth_row).contains("no crece"), "%s: la tabla de valores lo dice: %s" % [inlay, str(growth_row)])
		assert_true(rows.filter(func(r: Dictionary) -> bool: return str(r).contains("Días sin desgaste")).is_empty(), "%s: sin la fila de los días sin desgaste" % inlay)
	# la queratina sí crece
	var k := State.new({ "animal": "rapaz", "overgrowth_days": 90.0 })
	var kc: Dictionary = k.care.snapshot().claw
	assert_true(float(kc.startMm) > float(kc.naturalMm), "la queratina, con 90 días, sí trae crecimiento de más")
