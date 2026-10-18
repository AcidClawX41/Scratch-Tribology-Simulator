## La mesa de soldar del estado (core/lab/claw_forge_state.gd, unidad 5r; petición 44): cada gesto es una llamada de
## ClawForge; los mandos del método con sus topes; colocar las piezas las deja desalineadas y hay que alinearlas; el pedal
## apretado sobre la costura da un pulso por periodo (más deprisa, no) y recorrerla entera cierra la unión; sin argón el
## titanio sale contaminado y se explica con el paso que lo arregla; el cordón se lima y la funda soldada pasa a la cetrería
## con su unión; el tutorial de la soldadura no cambia el proceso y «Hazlo como dice el paso» lo hace entero; los textos sin
## rutas ni nombres internos; y las lecturas y el sonido que pide.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")

const FRAME := 1.0 / 30.0
const BAD := "docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawForge|ForgeData|ForgeTutorial|ClawWeld|SRC_|\\bunidad [0-9]"


## Una pieza de metal hecha, fría y tallada (lo recomendado), con la velocidad al máximo.
static func _metal(process := "acero") -> State:
	var st := State.new({ "animal": "rapaz", "claw": "aguila" })
	st.set_process(process)
	st.set_speed(State.SPEEDS.size() - 1)
	st.set_tutorial(false)
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	_settle(st)
	st.cool_piece()
	_settle(st)
	st.carve()
	_settle(st)
	return st


static func _settle(st: State) -> void:
	var n := 0
	while (st.running() or (not st.act.is_empty() and float(st.act.t) < float(st.act.dur))) and n < 20000:
		if st.running():
			st.skip()
		st.tick(FRAME)
		n += 1


## Recorre la costura con el pedal apretado, despacio (un fotograma por punto a su periodo), como el ratón.
static func _sweep(st: State, turns := 1.0) -> void:
	var period := st.weld_period_s()
	var n := int(st.forge.weld_state().pulsesNeed)
	var steps := int(ceil(float(n) * turns)) + 2
	st.weld_set_hold(true)
	for i in steps:
		st.weld_aim(fmod((float(i) + 0.5) / float(n), 1.0))
		var t := 0.0
		while t < period + 1e-6:
			st.tick(FRAME)
			t += FRAME
	st.weld_set_hold(false)


func test_colocar_alinear_y_soldar_con_el_pedal() -> void:
	var st := _metal("acero")
	assert_true(bool(st.snap().piece.carved), "la funda de acero, tallada")
	var v0: Dictionary = st.view().weld
	assert_false(bool(v0.on), "sin piezas en la mesa")
	assert_eq(String(v0.next), "colocar", "toca colocar")
	assert_true(bool(v0.can.ok), "el acero con el acero se puede")
	st.set_weld("method", "laser")
	st.set_weld("energy_j", 30.0)
	st.set_weld("pulse_ms", 4.0)
	st.set_weld("spot_mm", 0.6)
	st.set_weld("overlap", "resistencia")
	st.weld_prepare()
	var v1: Dictionary = st.view().weld
	assert_true(bool(v1.on) and bool(v1.ready), "piezas en la mesa: %s" % v1.text)
	assert_false(bool(v1.aligned), "a ojo quedan desalineadas")
	assert_eq(String(v1.next), "alinear", "toca alinear")
	assert_near(float(v1.offset_mm), State.WELD_PLACE_MM, 1e-9, 0.0, "lo que se desalinean al colocar")
	assert_eq(String(st.view().piece.at), "soldadura", "la pieza, en la mesa de soldar")
	# con las piezas desalineadas los pulsos no cuentan y se explica
	st.weld_aim(0.1)
	st.weld_set_hold(true)
	assert_eq(int(st.forge.weld_state().pulses), 0, "sin alinear no cuenta")
	assert_eq(String(st.mistake_view().get("fix_title", "")).contains("Alinear"), true, "y se explica con el paso de alinear: %s" % st.mistake_view())
	st.weld_set_hold(false)
	# arrastrar la punta hasta dentro de lo que admite la junta
	st.weld_nudge(-0.15)
	assert_false(bool(st.view().weld.aligned), "a 0,15 mm aún no")
	st.weld_nudge(-0.1)
	assert_true(bool(st.view().weld.aligned), "a 0,05 mm, dentro (%s)" % st.view().weld.align_text)
	assert_eq(String(st.view().weld.next), "soldar", "toca soldar")
	assert_true(st.mistake_view().is_empty(), "lo arreglado deja de explicarse")
	# el pedal: un pulso al apretar y luego uno por periodo, no más deprisa
	st.weld_aim(0.02)
	st.weld_set_hold(true)
	assert_eq(int(st.forge.weld_state().pulses), 1, "el primer pulso sale al apretar")
	for i in 3:
		st.tick(FRAME)
	assert_eq(int(st.forge.weld_state().pulses), 1, "antes del periodo no hay otro")
	st.weld_aim(0.1)
	var t := 0.0
	while t < st.weld_period_s() + 1e-6:
		st.tick(FRAME)
		t += FRAME
	assert_eq(int(st.forge.weld_state().pulses), 2, "al cumplirse el periodo, otro")
	st.weld_set_hold(false)
	var fx_n := int(st.view().fx_n)
	assert_true(fx_n >= 2, "cada pulso deja su efecto")
	var kinds: Array = (st.view().fx as Array).map(func(e: Dictionary) -> String: return String(e.kind))
	assert_true(kinds.has("pulso") and (st.view().fx as Array).any(func(e: Dictionary) -> bool: return String(e.kind) == "sfx" and String(e.id) == "forja-pulso"), "el destello y el clic del láser: %s" % [kinds])
	# la barra dice cuántos lleva de los que hacen falta
	var v2: Dictionary = st.view().weld
	assert_true(String(v2.bar_text).begins_with("Puntos: 2 de %d" % int(v2.pulses_need)), "la barra: %s" % v2.bar_text)
	assert_true(float(v2.progress) > 0.0 and float(v2.progress) < 1.0, "la barra se llena")
	# con la costura empezada, los mandos no se tocan
	st.set_weld("energy_j", 60.0)
	assert_eq(float(st.weld_p.energy_j), 30.0, "el mando no se mueve")
	assert_true(st.notice.contains("costura empezada"), "y lo dice")
	# la vuelta entera con el pedal, despacio: la unión sale y se avisa
	_sweep(st)
	var v3: Dictionary = st.view().weld
	assert_true(bool(v3.done), "la costura entera")
	assert_true(bool(v3.joint.ok), "la unión sale: %s" % v3.joint.text)
	assert_eq(String(v3.verdict_tone), "bien", "en verde")
	assert_true(st.notice.begins_with("Costura entera"), "el aviso al terminar: %s" % st.notice)
	assert_eq(String(v3.next), "limar", "toca limar el cordón")
	assert_true(float(v3.joint.jointMPa) <= float(v3.joint.baseMPa), "nunca más que el metal base")
	assert_true(st.forge.check("soldada"), "la condición del tutorial")
	# el cordón se lima con la muela fina y la funda se pule: pasa a la cetrería con su unión
	st.set_carve_tool("muela_fina")
	for i in 30:
		if st.forge.check("costura_limada"):
			break
		st.carve_pass(false)
		_settle(st)
	assert_true(st.forge.check("costura_limada"), "el cordón limado")
	assert_eq(String(st.view().weld.next), "pulir", "toca pulir")
	st.protect()
	st.polish()
	st.fit_test()
	_settle(st)
	assert_eq(String(st.view().weld.next), "hecho", "lista")
	var care: Dictionary = st.view().care
	assert_true(bool(care.ok), "pasa a la cetrería: %s" % care.text)
	var w: Variant = care.setup.piece.weld
	assert_true(w != null and float(w.jointMPa) > 0.0, "con su unión")
	# cada gesto es una llamada de ClawForge
	var calls: Array = st.calls.filter(func(c: Array) -> bool: return String(c[0]).begins_with("weld"))
	assert_true(calls.size() >= int(v3.pulses_need) + 2, "%d llamadas de la soldadura" % calls.size())


func test_ir_deprisa_deja_huecos_y_se_vuelve_sobre_ellos() -> void:
	var st := _metal("acero")
	st.set_weld("method", "laser")
	st.set_weld("energy_j", 30.0)
	st.weld_prepare()
	st.weld_align_pieces()
	var n := int(st.forge.weld_state().pulsesNeed)
	# la vuelta en la mitad de pulsos: quedan huecos
	st.weld_set_hold(true)
	for i in int(n / 2):
		st.weld_aim(float(i) / float(n / 2))
		var t := 0.0
		while t < st.weld_period_s() + 1e-6:
			st.tick(FRAME)
			t += FRAME
	st.weld_set_hold(false)
	var ws := st.forge.weld_state()
	assert_false(bool(ws.done), "con huecos no cierra")
	assert_true(int(ws.covered) < n and int(ws.covered) > n / 4, "%d de %d tramos" % [ws.covered, n])
	# el teclado da un pulso en el primer tramo sin soldar, hasta cerrarla
	for i in n + 2:
		st._weld_since = 1.0e9
		st.weld_pulse_next()
	assert_true(bool(st.forge.weld_state().done), "cerrada con J")


func test_el_titanio_sin_argon_falla_y_se_explica() -> void:
	var st := _metal("titanio")
	st.set_weld("method", "laser")
	st.set_weld_params({ "energy_j": 25.0, "pulse_ms": 5.0, "spot_mm": 0.8, "gas": "aire", "overlap": 0.65, "part": "reparar" })
	assert_eq(String(st.weld_p.overlap), "resistencia", "el solape por su valor")
	st.weld_prepare()
	st.weld_align_pieces()
	st.weld_all()
	var v: Dictionary = st.view().weld
	assert_true(bool(v.done), "entera")
	assert_false(bool(v.joint.ok), "la unión falla")
	assert_eq(String(v.joint.defect), "contaminada", "contaminada")
	assert_eq(String(v.verdict_tone), "mal", "en rojo")
	assert_true(String(v.what).begins_with("La soldadura ha fallado"), "y dice por qué: %s" % v.what)
	assert_true(String(v.color.name).begins_with("azul"), "la zona soldada azul")
	var m := st.mistake_view()
	assert_false(m.is_empty(), "el error se explica")
	assert_true(String(m.fix_title).contains("costura") or String(m.fix_title).contains("puntos"), "con el paso de soldar: %s" % m.fix_title)
	assert_false(bool(st.view().care.ok), "no pasa a la cetrería")
	# la misma pieza con argón sale plateada
	var g := _metal("titanio")
	g.set_weld("method", "laser")
	g.set_weld_params({ "energy_j": 25.0, "pulse_ms": 5.0, "spot_mm": 0.8, "gas": "argon", "overlap": 0.65, "part": "reparar" })
	g.weld_prepare()
	g.weld_align_pieces()
	g.weld_all()
	assert_true(bool(g.view().weld.joint.ok), "con argón, bien")
	assert_eq(String(g.view().weld.color.name), "plateado", "plateada")


func test_el_metal_duro_con_plata_y_el_soplete_suena() -> void:
	var st := _metal("acero")
	st.set_weld("material", "tungsteno")
	st.set_weld("method", "laser")
	st.weld_prepare()
	var v: Dictionary = st.view().weld
	assert_true(bool(v.on) and not bool(v.ready), "el láser no une el metal duro")
	assert_eq(String(v.defect), "metal_duro", "y dice por qué")
	assert_false(bool(v.can.ok), "lo que se puede unir lo dice antes")
	st.cycle_weld_method(1)
	assert_eq(String(st.weld_p.method), "tig", "F: el método siguiente")
	st.cycle_weld_method(1)
	assert_eq(String(st.weld_p.method), "braze", "y la soldadura fuerte")
	var v2: Dictionary = st.view().weld
	assert_true(bool(v2.ready), "con plata, sí: %s" % v2.text)
	assert_eq(String(v2.unit), "tramos", "el soplete, por tramos")
	st.weld_align_pieces()
	st.weld_aim(0.1)
	st.weld_set_hold(true)
	assert_eq(String(st.sound_view().loop), "forja-llama", "el soplete suena como la llama")
	assert_true(st.weld_period_s() >= State.ACT_MIN_S - 1e-9, "cada tramo tarda lo de la velocidad")
	st.weld_set_hold(false)
	assert_eq(String(st.sound_view().loop), "", "y calla al soltar")
	st.weld_all()
	var j: Dictionary = st.view().weld.joint
	assert_true(bool(j.ok), "la unión de plata: %s" % j.text)
	assert_true(float(j.jointMPa) <= float(j.baseMPa) + 1e-9, "nunca más que el metal base")


func test_los_mandos_con_sus_topes() -> void:
	var st := _metal("acero")
	st.set_weld("energy_j", 500.0)
	assert_eq(float(st.weld_p.energy_j), float(ClawWeld.METHODS.laser.controls.energy_j.max), "la energía, hasta el tope de la ficha")
	st.set_weld("energy_j", -3.0)
	assert_eq(float(st.weld_p.energy_j), float(ClawWeld.METHODS.laser.controls.energy_j.min), "y no menos del mínimo")
	st.set_weld("gas", "helio")
	assert_eq(String(st.weld_p.gas), "argon", "un gas que no existe no entra")
	st.set_weld("method", "plasma")
	assert_eq(String(st.weld_p.method), "laser", "ni un método")
	st.set_weld("tig_ms", 100.0)
	assert_eq(float(st.weld_p.tig_ms), float(ClawWeld.METHODS.tig.controls.pulse_ms.max), "el tiempo del micro-TIG, el suyo")
	var v: Dictionary = st.view().weld
	assert_eq((v.controls as Array).size(), 3, "el láser enseña sus tres mandos")
	for c: Dictionary in v.controls:
		assert_true(float(c.t) >= 0.0 and float(c.t) <= 1.0, "%s entre 0 y 1" % c.id)
	st.set_weld("method", "tig")
	assert_eq((st.view().weld.controls as Array).size(), 2, "el micro-TIG, dos")
	assert_true(bool(st.view().weld.has_gas), "con gas")
	st.set_weld("method", "braze")
	assert_false(bool(st.view().weld.has_gas), "el soplete, sin gas")
	# una gema no se suelda y lo dice antes de colocar nada
	var g := State.new({ "animal": "rapaz", "claw": "aguila" })
	g.set_process(State.STONE)
	g.choose_stone("cuarzo")
	assert_false(bool(g.view().weld.can.ok), "el cuarzo no se suelda")
	g.weld_prepare()
	assert_eq(String(g.view().weld.defect), "no_metal", "y la mesa lo dice")


func test_el_tutorial_de_la_soldadura() -> void:
	var st := _metal("oro")
	st.set_tutorial(true)
	st.tutorial_goto(State.WELD)
	assert_eq(st.process, "oro", "no cambia el proceso")
	assert_eq(String(st.current_step().id), "ojos", "empieza por la protección de los ojos")
	var tv: Dictionary = st.tutorial_view()
	assert_eq(String(tv.highlight), "soldadura", "se ilumina la mesa de soldar")
	assert_true(String(tv.control).length() > 10, "y dice cómo")
	st.tutorial_next()
	assert_eq(String(st.current_step().id), "preparar", "el método y las piezas")
	st.do_step()
	assert_eq(String(st.weld_p.method), "tig", "el oro refleja el láser: lo recomendado es el micro-TIG")
	assert_true(bool(st.view().weld.ready), "piezas en la mesa")
	assert_eq(String(st.current_step().id), "alinear", "sigue solo")
	st.do_step()
	assert_true(bool(st.view().weld.aligned), "alineadas")
	assert_eq(String(st.current_step().id), "soldar", "a soldar")
	st.do_step()
	assert_true(bool(st.view().weld.done) and bool(st.view().weld.joint.ok), "la vuelta entera: %s" % st.view().weld.joint.text)
	assert_near(float(st.view().weld.joint.efficiency), 0.5, 1e-9, 0.0, "el oro soldado, la mitad")
	assert_eq(String(st.current_step().id), "limar_costura", "a limar el cordón")
	st.do_step()
	_settle(st)
	for i in 20:
		if st.forge.check("costura_limada"):
			break
		st.do_step()
		_settle(st)
	assert_true(st.forge.check("costura_limada"), "limada")
	assert_eq(String(st.current_step().id), "pulir_soldada", "a pulir")
	st.do_step()
	_settle(st)
	assert_eq(String(st.current_step().id), "pasar", "y a la cetrería")
	# los textos del tutorial y de la mesa, sin rutas ni nombres internos
	var re := RegEx.new()
	re.compile(BAD)
	var texts: Array = []
	for s2: Dictionary in st.steps():
		texts.append(String(s2.title) + " " + String(s2.text) + " " + String(s2.mistake))
	var v: Dictionary = st.view().weld
	for k: String in ["what", "text", "align_text", "bar_text", "verdict", "safety", "method_name", "machine"]:
		texts.append(String(v[k]))
	for r: Dictionary in st.readouts():
		texts.append(String(r.label) + " " + String(r.value) + " " + String(r.note))
	for t: String in texts:
		assert_true(re.search(t) == null, "sin nombres internos: «%s»" % t)
	var found := false
	for r: Dictionary in st.readouts():
		if String(r.id) == "soldadura":
			found = true
			assert_true(String(r.value).contains("MPa"), "la lectura de la unión: %s" % r.value)
	assert_true(found, "hay lectura de la soldadura")
	var vals := st.values_table()
	assert_true(vals.any(func(x: Dictionary) -> bool: return String(x.label).contains("Micro-TIG")), "los valores y fuentes del método")


## «Poner lo recomendado» (P) también pone los mandos de la mesa de soldar: con los de serie, la primera costura del acero,
## el oro y el titanio salía con falta de fusión; con lo recomendado, sale bien en cada metal (y el metal duro, con plata).
func test_poner_lo_recomendado_tambien_suelda_bien() -> void:
	for p: String in ["acero", "oro", "titanio", "metal_duro"]:
		var st := _metal(p)
		st.apply_recommended()
		st.weld_prepare()
		assert_true(bool(st.view().weld.ready), "%s: piezas en la mesa" % p)
		st.weld_align_pieces()
		_sweep(st)
		var w: Dictionary = st.view().weld
		assert_true(bool(w.done) and bool(w.joint.ok), "%s: la costura sale bien con lo recomendado: %s" % [p, w.joint.get("text", "")])
	# a mitad de una costura no cambia los mandos
	var st2 := _metal("acero")
	st2.weld_prepare()
	st2.weld_align_pieces()
	st2.weld_set_hold(true)
	st2.weld_aim(0.05)
	for i in 12:
		st2.tick(FRAME)
	st2.weld_set_hold(false)
	assert_true(st2.weld_in_progress(), "costura a medias")
	var before: Dictionary = st2.weld_p.duplicate()
	st2.apply_recommended()
	assert_eq(st2.weld_p, before, "lo recomendado no toca los mandos a mitad de la vuelta")


## Cambiar de receta con una pieza empezada pide un segundo clic (la de ahora se pierde); sin nada empezado, a la primera.
func test_otra_receta_con_la_pieza_empezada_pide_confirmar() -> void:
	var fresh := State.new({ "animal": "rapaz", "claw": "aguila" })
	fresh.set_process("acero")
	fresh.choose_process("oro")
	assert_eq(fresh.process, "oro", "sin nada empezado, a la primera")
	var st := _metal("acero")
	st.choose_process("oro")
	assert_eq(st.process, "acero", "el primer clic no la cambia")
	assert_true(st.notice.contains("Pulsa otra vez") and st.notice.contains("se pierde"), "avisa: %s" % st.notice)
	st.choose_process("titanio")
	assert_eq(st.process, "acero", "otro clic en otra receta tampoco: avisa de esa")
	st.choose_process("titanio")
	assert_eq(st.process, "titanio", "el segundo clic en la misma, sí")
	assert_eq(st.notice, "", "y el aviso se va")
