## Estado del laboratorio experimental de la reforja (core/lab/claw_forge_state.gd, unidad 5f): cada gesto es una llamada
## de ClawForge (las mismas llamadas en otra ClawForge dan la misma pieza: el estado no hace física); las diez recetas,
## la piedra comprada y la garra viva salen por los gestos; fuera de margen sale el defecto del motor y se explica con el
## paso del tutorial que lo arregla; los mandos tienen sus pasos y sus topes y no se mueven con el horno en marcha; la
## balanza vierte a su ritmo; la marcha a cámara rápida enseña lo que el motor ya ha decidido (lo que crece no pasa de lo
## crecido); el color del calor sale de core; el tutorial sigue al hacer cada paso y cada paso dice qué mando se ilumina y
## cómo se usa; la forma de la funda cambia la funda del motor; la garra pasa a la cetrería y al banco; el sonido que pide;
## y ningún texto visible lleva rutas ni nombres internos.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Incandescence = preload("res://core/lab/incandescence.gd")

const FRAME := 1.0 / 30.0
## Rutas y nombres internos que no se pueden ver (los de la página de la cetrería y los de la reforja).
const BAD := "docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawForge|ForgeData|ForgeTutorial|ClawSharpness|ClawsV2|ClawMass|ClawFracture|MovingCar|Incandescence|\\bData\\.|Physics\\.|SRC_|\\bunidad [0-9]"


static func _state(process := "zafiro", p := {}) -> State:
	var setup := { "animal": "rapaz", "claw": "aguila" }
	setup.merge(p, true)
	var st := State.new(setup)
	st.set_process(process)
	return st


## Hace el proceso entero con los gestos de la página, con lo que recomienda la receta: desde la 5m, la carga dentro de su
## máquina antes de arrancar, y el laboratorio acaba en la funda pulida y probada en la garra, sin pegarla (petición 43).
static func _make(st: State) -> void:
	st.apply_recommended()
	if st.process == State.STONE:
		st.choose_stone()
	elif st.process == State.ACRYLIC:
		st.load_crucible()
	else:
		st.load_crucible()
		st.insert_charge()
		st.start()
		_run(st)
		st.cool_piece()
		_settle(st)
	st.carve()
	_settle(st)
	st.protect()
	st.polish()
	st.fit_test()
	_settle(st)


## La marcha entera, fotograma a fotograma (como mucho dura RUN_MAX_S más la colada).
static func _run(st: State) -> void:
	var n := 0
	while st.running() and n < int((State.RUN_MAX_S + 5.0) / FRAME):
		st.tick(FRAME)
		n += 1


static func _settle(st: State) -> void:
	for i in 300:
		if st.act.is_empty() or float(st.act.t) >= float(st.act.dur):
			return
		st.tick(FRAME)


## Las mismas llamadas en otra ClawForge (con la configuración del estado).
static func _replay(st: State) -> ClawForge:
	var f := ClawForge.new(st.forge.setup())
	for c: Array in st.calls:
		f.callv(String(c[0]), [c[1]])
	return f


static func _strings(v: Variant, out: Array) -> void:
	if v is String:
		if String(v) != "":
			out.append(v)
	elif v is Dictionary:
		for k: Variant in v:
			# las fuentes completas van a la ayuda: también se revisan
			_strings(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_strings(x, out)


func test_cada_gesto_es_una_llamada_de_clawforge() -> void:
	var st := _state("zafiro")
	_make(st)
	var kinds := {}
	for c: Array in st.calls:
		kinds[String(c[0])] = true
	for k: String in ["mix", "load_machine", "fire", "cool", "carve", "protect", "polish", "fit"]:
		assert_true(kinds.has(k), "ha llamado a %s" % k)
	assert_false(kinds.has("bond") or kinds.has("check_load"), "y no pega ni prueba con la carga: eso es de la cetrería (petición 43)")
	var ref := _replay(st)
	assert_eq(var_to_str(ref.result_claw()), var_to_str(st.forge.result_claw()), "las mismas llamadas dan la misma garra")
	assert_eq(var_to_str(ref.report()), var_to_str(st.forge.report()), "y el mismo informe")
	assert_eq(String(st.forge.report().verdict), "bien", "con lo recomendado, la funda sale bien")


func test_las_diez_recetas_la_piedra_y_la_garra_viva_por_los_gestos() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _state(rid)
		_make(st)
		var rep := st.forge.report()
		assert_eq(String(rep.verdict), "bien", "%s: sale bien siguiendo la receta por los gestos (%s)" % [rid, String(rep.verdictText)])
		assert_eq(String(st.forge.stage()), "hecho", "%s: terminada" % rid)
	var stone := _state(State.STONE)
	stone.set_stone("circonita")
	_make(stone)
	assert_eq(String(stone.forge.result_claw().inlay), "circonita", "la piedra comprada")
	assert_eq(String(stone.forge.report().verdict), "bien", "y sale bien")
	var live := _state(State.LIVE)
	live.apply_recommended()
	live.protect()
	live.coat()
	live.polish()
	assert_eq(String(live.forge.report().verdict), "ficcion", "la garra viva recubierta es ficción")
	assert_true(bool(live.view().fiction), "y la vista lo dice")


func test_fuera_de_margen_sale_el_defecto_y_se_explica() -> void:
	var st := _state("zafiro")
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.set_control("temp_c", 1900.0)
	assert_false(bool(st.margin("temp_c").ok), "1900 °C queda fuera del margen pintado")
	st.start()
	assert_true(st.running(), "arranca")
	st.skip()
	assert_false(st.running(), "Espacio acaba la marcha")
	var rv := st.run_view()
	assert_eq(String(rv.defect), "frio", "el defecto del motor")
	assert_eq(String(rv.visual), "costra", "se ve la costra porosa, sin cristal")
	assert_eq(float(rv.grown), 0.0, "sin crecer")
	var m := st.mistake_view()
	assert_false(m.is_empty(), "el error se explica")
	assert_true(String(m.what).contains("2053"), "qué ha pasado, con el texto del motor")
	assert_true(String(m.fix_title).contains("parámetros"), "el paso que lo arregla")
	assert_true(String(m.control) != "" and String(m.fix_source) != "", "con su mando y su fuente")
	st.dismiss_mistake()
	assert_true(st.mistake_view().is_empty(), "«Entendido» lo quita")
	# el modo equivocado: el paso del modo
	var md := _state("oro")
	md.apply_recommended()
	md.load_crucible()
	md.set_control("modo", "sinterizar")
	md.insert_charge()
	md.start()
	md.skip()
	assert_true(String(md.mistake_view().fix_title).contains("modo"), "con otro modo, el paso del modo")
	# la mezcla que no es la de la receta
	var mx := _state("rubi")
	mx.add_powder("al2o3", 100.0)
	mx.load_crucible()
	assert_false(bool(mx.bench_view().mix_ok), "sin cromo no es la mezcla del rubí")
	assert_false(mx.calls.any(func(c: Array) -> bool: return String(c[0]) == "mix"), "fuera de la receta, el crisol no se carga (5w)")
	assert_eq(String(mx.mistake_view().what), String(mx.forge.mix_status(mx.pan).eval.text), "y se explica con el texto del motor")
	var jars := {}
	for j: Dictionary in mx.bench_view().jars:
		jars[String(j.id)] = j
	assert_false(bool(jars.cr2o3.ok), "el tarro del óxido de cromo, fuera de su proporción")
	assert_true(String(jars.cr2o3.frac_text).contains("la receta"), "con la proporción de la receta al lado")


func test_los_mandos_tienen_sus_pasos_y_sus_topes() -> void:
	var st := _state("zafiro")
	assert_eq(float(st.dial.temp_c), 20.0, "el horno empieza frío")
	st.turn_control("temp_c", 1)
	assert_eq(float(st.dial.temp_c), 25.0, "W: a la rejilla de 25 °C")
	st.turn_control("temp_c", 3)
	assert_eq(float(st.dial.temp_c), 100.0, "de 25 en 25")
	st.turn_control("temp_c", 1, true)
	assert_eq(float(st.dial.temp_c), 105.0, "con Mayús, de 5 en 5")
	st.turn_control("temp_c", -1000)
	assert_eq(float(st.dial.temp_c), 20.0, "no baja de 20 °C")
	st.turn_control("temp_c", 1000)
	assert_eq(float(st.dial.temp_c), 3000.0, "ni sube de 3000 °C")
	st.turn_control("time_s", 1)
	assert_eq(float(st.dial.time_s), 60.0, "el tiempo, de valor redondo en valor redondo")
	st.turn_control("time_s", 100)
	assert_eq(float(st.dial.time_s), float(State.TIME_STEPS[-1]), "hasta 1000 h")
	st.turn_control("pressure_mpa", 100)
	assert_eq(float(st.dial.pressure_mpa), 6000.0, "la presión hasta 6 GPa")
	st.turn_control("modo", 1)
	assert_eq(String(st.dial.modo), "induccion", "el selector pasa a la opción siguiente")
	st.turn_control("modo", -1)
	assert_eq(String(st.dial.modo), "calentar", "y vuelve")
	st.cycle_control(1)
	assert_eq(st.selected_control, "temp_c", "D: el mando siguiente del panel")
	# deslizador ↔ valor
	for id: String in State.CONTROL_IDS:
		for t in [0.0, 0.37, 1.0]:
			var v: Variant = State.control_value_at(id, t)
			st.set_control(id, v)
			assert_eq(st.dial[id], v, "%s: el deslizador pone su valor" % id)
	# con el horno en marcha no se mueven
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	var before := st.dial.duplicate()
	st.turn_control("temp_c", 4)
	st.set_control("atmosphere", "vacio")
	assert_eq(st.dial, before, "con el horno en marcha, los mandos no se mueven")


func test_la_balanza_vierte_a_su_ritmo() -> void:
	var st := _state("rubi")
	st.pick_jar("al2o3")
	assert_eq(st.held_jar, "al2o3", "coge el tarro")
	st.set_pouring(true)
	for i in 30:
		st.tick(FRAME)
	# 5w · el tarro de la receta vierte a un ritmo que llena su objetivo en POUR_FILL_S; gota a gota, POUR_FINE_DIV veces menos
	var plan := st.forge.mix_plan()
	var tg := float(plan.powders[0].targetG)
	assert_near(st.pour_rate("al2o3"), tg / State.POUR_FILL_S, 1e-12, 1e-12, "el ritmo, el de su objetivo")
	assert_near(float(st.pan.al2o3), st.pour_rate("al2o3") * 30.0 * FRAME, 1e-6, 1e-6, "vierte a su ritmo")
	st.set_pouring(true, true)
	var g0 := float(st.pan.al2o3)
	for i in 30:
		st.tick(FRAME)
	assert_near(float(st.pan.al2o3) - g0, st.pour_rate("al2o3") / State.POUR_FINE_DIV * 30.0 * FRAME, 1e-6, 1e-6, "con Mayús, gota a gota")
	assert_near(st.pour_rate("mgo"), State.POUR_G_S, 1e-12, 1e-12, "un tarro que no va en la receta, al de siempre")
	st.set_pouring(false)
	st.drop_jar()
	st.add_powder("al2o3", 1000.0)
	assert_eq(st.pan_total(), State.PAN_MAX_G, "no cabe más que en el plato")
	st.add_powder("al2o3", -5000.0)
	assert_false(st.pan.has("al2o3"), "quitar no deja gramos negativos")
	# lo que pide la pieza de esta garra, en la proporción de la receta
	for p: Dictionary in plan.powders:
		st.add_powder(String(p.id), float(p.targetG))
	st.load_crucible()
	var bv := st.bench_view()
	assert_true(bool(bv.mix_ok), "lo que pide la pieza, en la proporción del rubí: %s" % String(bv.status_text))
	assert_eq(String(st.calls[-1][0]), "mix", "cargar el crisol es mix()")
	assert_eq(st.calls[-1][1], st.pan, "con los gramos del plato")
	# mezclados, no se separan: quitar uno no deja
	var before := st.pan.duplicate()
	st.add_powder("cr2o3", -0.001)
	assert_eq(st.pan, before, "con dos polvos en el plato, quitar uno no deja: ya están mezclados")
	assert_true(st.notice.contains("mezclado"), "y lo dice: %s" % st.notice)
	# la tara pone la pantalla a cero
	st.tare()
	assert_eq(st.scale_text(), "T 0.0000 g", "con la tara, la pantalla a cero")
	st.add_powder("al2o3", 0.5)
	assert_eq(st.scale_text(), "T 0.5000 g", "y pesa lo de encima")
	st.clear_pan()
	assert_true(st.pan.is_empty(), "vaciar el plato")
	assert_eq(st.scale_text(), "0.0000 g", "y quita la tara")


func test_la_marcha_a_camara_rapida() -> void:
	var st := _state("zafiro")
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	var fire: Dictionary = st.last.fire
	var last_grown := -1.0
	var phases := {}
	var t_hold := 0.0
	while st.running():
		var rv := st.run_view()
		phases[String(rv.phase)] = true
		assert_true(float(rv.grown) >= last_grown - 1e-12, "lo crecido nunca baja")
		assert_true(float(rv.grown) <= float(fire.grown) + 1e-9, "ni pasa de lo que da el motor")
		assert_true(float(rv.temp_c) <= float(rv.set_c) + 1e-9, "la temperatura sube hasta la del mando")
		last_grown = float(rv.grown)
		t_hold = float(rv.lapse)
		st.tick(FRAME)
	assert_true(phases.has("calentar") and phases.has("mantener"), "sube y mantiene")
	var end := st.run_view()
	assert_eq(String(end.phase), "listo", "termina")
	assert_near(float(end.grown), float(fire.grown), 1e-9, 1e-9, "al final, lo crecido es lo del motor")
	assert_near(float(end.proc_s), float(st.dial.time_s), 1e-9, 1e-9, "y el tiempo del proceso, el del mando")
	var hold := float(st.run.hold)
	assert_near(hold, st.play_s(float(st.dial.time_s), State.RUN_MIN_S, State.RUN_MAX_S), 1e-12, 0.0, "la marcha dura el tiempo de verdad a la velocidad elegida (con sus topes)")
	assert_near(t_hold, float(st.dial.time_s) / (hold * (1.0 - State.RAMP_FRAC)), 1e-9, 1e-9, "a cámara rápida: el tiempo del mando en lo que dura la animación")
	assert_eq(String(st.run.loop), String(st.forge.sfx_for("fire", fire)), "con el modo de la receta, el bucle es el que da el motor")
	# la colada: el chorro al final y su sonido
	var gold := _state("oro")
	gold.apply_recommended()
	gold.load_crucible()
	gold.insert_charge()
	gold.start()
	var fx0 := int(gold.view().fx_n)
	_run(gold)
	var ids: Array = gold.view().fx.map(func(e: Dictionary) -> String: return String(e.id))
	assert_true(ids.has("forja-colada"), "la colada suena al colar")
	assert_true(int(gold.view().fx_n) > fx0, "un efecto nuevo")
	# el sinterizado encoge
	var wc := _state("metal_duro")
	wc.apply_recommended()
	wc.load_crucible()
	wc.insert_charge()
	wc.start()
	wc.skip()
	assert_near(float(wc.run_view().shrink), float(ForgeData.RECIPES.metal_duro.shrink.value), 1e-12, 0.0, "el metal duro encoge lo que dice la receta")


func test_el_color_del_calor_sale_de_core() -> void:
	var st := _state("zafiro")
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	_run(st)
	var pv := st.piece_view()
	var g := Incandescence.glow_at(Incandescence.ramp(), float(pv.temp_c))
	assert_eq(float(pv.temp_c), 2100.0, "la bola, a la temperatura del horno")
	assert_eq(pv.glow.color, g.color, "su color, el del cuerpo negro de core")
	assert_near(float(pv.glow.strength), float(g.strength), 1e-12, 0.0, "y su brillo")
	assert_eq(String(pv.glow.word), "blanco", "la palabra de los herreros")
	st.cool_piece()
	var t_prev := float(st.piece_view().temp_c)
	while not st.act.is_empty() and float(st.act.t) < float(st.act.dur):
		st.tick(FRAME)
		var t := float(st.piece_view().temp_c)
		assert_true(t <= t_prev + 1e-9, "al enfriar, la temperatura solo baja")
		t_prev = t
	assert_eq(float(st.piece_view().temp_c), 20.0, "y acaba a la del taller")
	assert_true(st.piece_view().glow.is_empty(), "fría, no brilla")


func test_el_tutorial_sigue_al_hacer_cada_paso() -> void:
	var st := _state("zafiro")
	st.tutorial_goto("zafiro")
	var tv := st.tutorial_view()
	assert_eq(String(tv.step.id), "pesar", "empieza por pesar")
	assert_eq(String(tv.highlight), "balanza", "se ilumina la balanza")
	assert_true(String(tv.control).contains("tarro"), "y dice cómo")
	st.add_powder("al2o3", float(st.forge.mix_plan().targetG))
	st.load_crucible()
	assert_eq(String(st.tutorial_view().step.id), "modo", "con la mezcla buena, sigue solo")
	st.set_control("modo", "sintetizar")
	assert_eq(String(st.tutorial_view().step.id), "meter", "con el modo de la receta, sigue solo: meter la carga en su máquina")
	assert_eq(String(st.tutorial_view().highlight), "puerta", "se ilumina la puerta del horno")
	st.insert_charge()
	assert_eq(String(st.tutorial_view().step.id), "parametros", "con la carga dentro, sigue solo")
	st.do_step()
	_run(st)
	assert_eq(String(st.tutorial_view().step.id), "vigilar", "al salir bien la pieza, sigue")
	# cada paso de cada tutorial dice qué se ilumina, cómo se usa, su fuente y qué pasa si te equivocas
	for tid: String in State.TUTORIALS:
		for s: Dictionary in ForgeTutorial.steps(tid):
			var sid := String(s.id)
			assert_true(State.STEP_HIGHLIGHT.has(sid), "%s/%s: qué se ilumina" % [tid, sid])
			assert_true(State.STEP_CONTROLS.has(sid), "%s/%s: cómo se usa" % [tid, sid])
			assert_true(String(s.source) != "", "%s/%s: su fuente" % [tid, sid])
			if String(s.action) != "":
				assert_true(String(s.mistake) != "", "%s/%s: qué pasa si te equivocas" % [tid, sid])
	# el general: un paso por mando
	st.tutorial_goto(State.GENERAL)
	var seen := {}
	while not st.tutorial_done():
		seen[String(st.tutorial_view().highlight)] = true
		st.tutorial_next()
	for id: String in State.CONTROL_IDS:
		assert_true(seen.has(id), "el tutorial general ilumina %s" % id)


func test_hazlo_como_dice_el_tutorial() -> void:
	for tid: String in ["zafiro", "diamante_hpht", "oro", State.STONE]:
		var st := _state(tid)
		st.tutorial_goto(tid)
		var n := 0
		while not st.tutorial_done() and n < 60:
			st.do_step()
			_run(st)
			_settle(st)
			n += 1
		assert_eq(String(st.forge.report().verdict), "bien", "%s: siguiendo el tutorial paso a paso sale bien" % tid)


func test_la_forma_de_la_funda_es_la_del_motor() -> void:
	var reach := float(CareData.claw_entry("aguila").reach)
	var prev := 0.0
	for e: Dictionary in State.SHAPES:
		var st := _state("zafiro")
		st.set_shape(String(e.id))
		var sh := st.sheath_view()
		assert_near(float(sh.cover_mm), clampf(float(e.cover_frac) * reach, 0.5, reach), 1e-12, 0.0, "%s: cubre su parte de la garra" % e.id)
		assert_true(float(sh.area_mm2) > prev, "%s: más garra cubierta, más superficie para pegar" % e.id)
		prev = float(sh.area_mm2)
		assert_eq(float(st.forge.setup().cover_mm), float(sh.cover_mm), "%s: es la funda del motor" % e.id)
	var thin := _state("zafiro")
	thin.set_wall("fina")
	assert_eq(float(thin.forge.setup().wall_mm), 0.5, "la pared fina")
	# una garra rota llega con la prótesis entera
	var broken := State.new({ "animal": "tigre", "claw": String(CareData.ANIMALS.tigre.claw), "broken": true, "paw": "delantera_derecha", "digit": "II" })
	assert_eq(broken.shape, "protesis", "la garra rota se reforja con una prótesis entera")
	assert_eq(String(broken.care_view().setup.get("paw", "")), "delantera_derecha", "y vuelve a su pata")


func test_a_la_cetreria_y_al_banco() -> void:
	var st := _state("zafiro")
	assert_false(bool(st.care_view().ok), "sin terminar, no pasa a la cetrería")
	assert_true(st.bench_setup().is_empty(), "ni al banco")
	_make(st)
	var cv := st.care_view()
	assert_true(bool(cv.ok), "terminada, a la cetrería")
	assert_eq(String(cv.setup.inlay), String(st.forge.care_setup().inlay), "con lo que da el motor")
	var b := st.bench_setup()
	assert_eq([String(b.claw), String(b.inlay)], ["aguila", "zafiro"], "y al banco, con su material")
	# el rubí y la alúmina ya están en el banco y en la cetrería (5g): van con su propio material
	var ruby := _state("rubi")
	_make(ruby)
	assert_eq(String(ruby.bench_setup().inlay), "rubi", "el rubí va al banco como rubí")
	assert_eq(String(ruby.care_view().setup.inlay), "rubi", "y a la cetrería")
	var alu := _state("alumina")
	_make(alu)
	assert_eq(String(alu.bench_setup().inlay), "alumina", "la alúmina, también")
	assert_eq(bool(alu.care_view().ok), bool(alu.forge.care_setup().get("careSupported", true)) and String(alu.forge.care_setup().inlay) != "none", "la cetrería, lo que diga el motor")


## La garra rota (petición 35): llega con lo que queda de ella (from_care con stump_mm) y, en cuanto la pieza sale bien y
## se enfría (sin tallar), vuelve a la cetrería como un bloque en bruto pegado al muñón (ClawForge.care_setup(from_care)),
## marcado como ficción; otra garra sana después, sin lo de la rota.
func test_la_garra_rota_vuelve_como_bloque() -> void:
	var fc := { "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0, "paw": "izquierda", "digit": "II", "seed": "x" }
	var st := _state("zafiro", { "broken": true, "paw": "izquierda", "digit": "II", "from_care": fc })
	assert_eq(st.shape, "protesis", "la garra rota, con la prótesis entera")
	# la prótesis, con lo que queda de ella y la garra de su dedo (5j): rehace lo que falta y se pega sobre el muñón
	var L2 := 35.0 * float(CareData.claw_shape("aguila", "II").lengthRatio)
	assert_near(st.forge.natural_mm(), L2, 1e-12, 0.0, "la garra del dedo II")
	var sv := st.sheath_view()
	assert_near(float(sv.gone_mm), L2 - 18.0, 1e-9, 0.0, "falta lo de más allá del muñón")
	assert_near(float(sv.stump_cover_mm), 18.0, 1e-9, 0.0, "y se pega sobre todo él")
	assert_true(String(sv.text).contains("que faltan"), "y lo dice: %s" % sv.text)
	assert_eq(var_to_str(st.snap().sheath), var_to_str(ClawForge.sheath_geometry(CareData.claw_entry("aguila"), L2, 1.0, L2 - 18.0, CareData.claw_shape("aguila", "II", false))), "la del motor")
	var nat_s: PackedFloat64Array = st.claw_profile().nat_s
	assert_near(nat_s[nat_s.size() - 1], st.forge.natural_mm(), 1e-9, 0.0, "el dibujo de la prótesis sigue la garra sana hasta su punta")
	var cv := st.care_view()
	assert_false(bool(cv.ok), "sin pieza, aún no vuelve")
	assert_true(String(cv.text).length() > 10, "y dice por qué: %s" % cv.text)
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	_run(st)
	st.cool_piece()
	_settle(st)
	cv = st.care_view()
	assert_true(bool(cv.ok) and bool(cv.block), "fría y sin tallar, vuelve como bloque")
	var b: Dictionary = cv.setup.block
	assert_eq([String(b.material), float(b.stump_mm), bool(b.fiction)], ["zafiro", 18.0, true], "el bloque de zafiro sobre el muñón, ficción")
	assert_eq([String(cv.setup.paw), String(cv.setup.digit)], ["izquierda", "II"], "en su pata y su dedo")
	assert_eq(var_to_str(cv.setup), var_to_str(_with_paw(st.forge.care_setup(fc), "izquierda", "II")), "lo que da el motor")
	assert_true(String(cv.text).contains("FICCIÓN"), "y la nota de lo que en la realidad no se hace")
	st.open({ "animal": "rapaz", "claw": "aguila", "broken": false })
	assert_false(st.setup.has("from_care"), "otra garra sana, sin lo de la rota")
	assert_false(bool(st.care_view().get("block", false)), "y sin bloque")


## La prótesis de verdad (unidad 5j): con la garra rota, «Acrílico dental» se mezcla sin horno (la tecla L, el estuche o el
## paso del tutorial) y vuelve a la cetrería como un bloque de acrílico sin ficción; sus tarjeta, sus valores y sus textos
## lo dicen; con la piedra, la caja de las piedras sigue comprando la piedra.
func test_la_garra_rota_con_el_acrilico_de_verdad() -> void:
	var fc := { "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0, "paw": "izquierda", "digit": "II", "seed": "x" }
	var st := _state(State.ACRYLIC, { "broken": true, "paw": "izquierda", "digit": "II", "from_care": fc })
	var cv := st.care_view()
	assert_false(bool(cv.ok), "sin mezclar, aún no vuelve")
	st.tutorial_goto(State.ACRYLIC)
	var n := 0
	while not st.tutorial_done() and n < 20:
		st.do_step()
		_settle(st)
		n += 1
	assert_true(st.tutorial_done(), "el tutorial se recorre (%d pasos)" % n)
	cv = st.care_view()
	assert_true(bool(cv.ok) and bool(cv.block), "mezclado, vuelve como bloque")
	var b: Dictionary = cv.setup.block
	assert_eq([String(b.material), float(b.stump_mm), bool(b.fiction)], ["acrilico", 18.0, false], "el bloque de acrílico sobre el muñón, de verdad")
	assert_false(String(cv.text).contains("FICCIÓN"), "sin ficción: %s" % cv.text)
	assert_eq(var_to_str(cv.setup), var_to_str(_with_paw(st.forge.care_setup(fc), "izquierda", "II")), "lo que da el motor")
	var pv := st.piece_view()
	assert_eq(String(pv.form_name), "acrílico recién mezclado", "la pieza: el acrílico")
	var lk := st.look_view(st.snap())
	assert_eq([String(lk.optical), String(lk.tint)], ["acrilico", ""], "(su aspecto: los datos ópticos del acrílico de la biblioteca, unidad 5p; sin tinte)")
	assert_eq(String(_state("zafiro").look_view(_state("zafiro").snap()).tint), "", "(los que la biblioteca tiene, sin tinte)")
	assert_eq(st.short_source(String(ForgeData.PROSTHESIS.acrilico.use_source)), "Samour 2006 (las reparaciones del pico); Matta et al. 2022 (prótesis de acrílico del pico). En una garra: la misma técnica (suposición con el caso documentado más parecido, el pico)", "la fuente, corta")
	# la tarjeta, los valores y el bloque de la funda dicen que es la vía real y de qué está hecho
	var card: Dictionary = st.recipe_cards().filter(func(c: Dictionary) -> bool: return String(c.id) == State.ACRYLIC)[0]
	assert_false(bool(card.fiction), "la tarjeta: no es ficción")
	assert_eq(String(card.tag), "la vía real", "es la vía real")
	var labels: Array = st.values_table().map(func(r: Dictionary) -> String: return String(r.label))
	assert_true(labels.has("Acrílico dental") and labels.has("La prótesis en una garra"), "los valores del acrílico: %s" % [labels])
	assert_true(String(st.sheath_view().mass_text).contains("acrílico"), "la masa de la prótesis, de acrílico")
	# la tecla L y el estuche: el acrílico; la caja de las piedras, la piedra
	var k := _state(State.ACRYLIC, { "broken": true, "from_care": fc })
	k.load_crucible()
	assert_eq(String(k.snap().piece.material), "acrilico", "L mezcla el acrílico")
	k.choose_stone("")
	assert_eq(String(k.snap().piece.material), k.stone, "la caja de las piedras compra la piedra")
	k.choose_stone(State.ACRYLIC)
	assert_eq(String(k.snap().piece.material), "acrilico", "y el estuche, el acrílico")
	# con una receta de fantasía, la vista de la cetrería apunta a la vía real
	var z := _state("zafiro", { "broken": true, "from_care": fc })
	assert_true(String(z.care_view().text).contains("acrílico dental"), "la vía real: %s" % z.care_view().text)


static func _with_paw(cs: Dictionary, paw: String, digit: String) -> Dictionary:
	var s := cs.duplicate(true)
	s.erase("reason")
	s["paw"] = paw
	s["digit"] = digit
	return s


func test_el_sonido_que_pide_el_estado() -> void:
	var st := _state("zafiro")
	assert_eq(String(st.sound_view().loop), "", "en silencio al empezar")
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	st.tick(FRAME)
	var snd := st.sound_view()
	assert_eq(String(snd.loop), "forja-llama", "la llama del soplete de Verneuil")
	assert_true(float(snd.volume) > 0.0, "con su volumen")
	_run(st)
	assert_eq(String(st.sound_view().loop), "", "al terminar, en silencio")
	st.cool_piece()
	_settle(st)
	st.set_carve("speed_ms", 30.0)
	st.carve()
	st.tick(FRAME)
	assert_eq(String(st.sound_view().loop), "forja-muela", "la muela mientras talla")
	assert_near(float(st.sound_view().pitch), 30.0 / float(ForgeData.CARVE_DEFAULTS.speed_ms), 1e-12, 0.0, "con el tono de su velocidad")
	var hp := _state("diamante_hpht")
	hp.apply_recommended()
	hp.load_crucible()
	hp.insert_charge()
	hp.start()
	assert_eq(String(hp.sound_view().loop), "forja-prensa", "la prensa del diamante HPHT")
	var ind := _state("acero")
	ind.apply_recommended()
	ind.load_crucible()
	ind.insert_charge()
	ind.start()
	assert_eq(String(ind.sound_view().loop), "forja-induccion", "la bobina de inducción")
	var sin := _state("alumina")
	sin.apply_recommended()
	sin.load_crucible()
	sin.insert_charge()
	sin.start()
	assert_eq(String(sin.sound_view().loop), "forja-horno", "el horno eléctrico")
	for id: String in ["forja-llama", "forja-prensa", "forja-induccion", "forja-horno", "forja-muela"]:
		assert_true(ClawForge.SFX_FORGE.has(id), "%s es de los del motor" % id)
	# con el modo del dial distinto del de la receta, suena la máquina que trabaja (la del dial), y es la del motor (5j)
	for mode: String in ForgeData.FURNACE.modes:
		var other := _state("zafiro")
		other.apply_recommended()
		other.load_crucible()
		other.set_control("modo", mode)
		other.insert_charge()
		other.start()
		var want := String(other.forge.sfx_for("heat" if bool(other.run.heat) else "fire", other.last.get("heat" if bool(other.run.heat) else "fire", {})))
		assert_eq(String(other.run.loop), want, "zafiro en «%s»: el bucle es el del motor" % mode)
		assert_eq(String(other.run.loop), State.loop_for(String(other.run.kind)), "zafiro en «%s»: y el de su máquina (%s)" % [mode, other.run.kind])
	var coil := _state("zafiro")
	coil.apply_recommended()
	coil.load_crucible()
	coil.set_control("modo", "induccion")
	coil.insert_charge()
	coil.start()
	assert_eq(String(coil.sound_view().loop), "forja-induccion", "el zafiro con el horno en inducción: suena la bobina, no la llama")


## La pieza lleva la superficie del motor (lo pidió la 5f; unidad 5j): la que deja la última muela o el último grano, para la
## biblioteca de materiales; sin tallar, ninguna (la de su acabado).
func test_la_pieza_lleva_la_superficie_del_motor() -> void:
	var st := _state("zafiro")
	assert_false(bool((st.piece_view().look.surface as Dictionary).get("ok", false)), "sin hacer, sin superficie")
	_make(st)
	var lk: Dictionary = st.piece_view().look
	assert_eq(var_to_str(lk.surface), var_to_str(st.forge.surface()), "la del motor")
	assert_eq(String(lk.surface.by), "pulido", "pulida al final, la del grano")


func test_determinista() -> void:
	var a := _state("diamante_cvd")
	var b := _state("diamante_cvd")
	for st: State in [a, b]:
		_make(st)
	assert_eq(var_to_str(a.view()), var_to_str(b.view()), "los mismos gestos, la misma vista")


func test_textos_sin_rutas_ni_nombres_internos() -> void:
	var bad := RegEx.create_from_string(BAD)
	var checked := 0
	for pid: String in State.PROCESSES:
		var st := _state(pid)
		if pid == State.LIVE:
			st.apply_recommended()
			st.protect()
			st.coat()
		else:
			_make(st)
		var texts: Array = []
		var v := st.view()
		v.erase("snap")  # la instantánea del motor no se enseña tal cual: sus textos salen por las lecturas
		_strings(v, texts)
		_strings(st.values_table(), texts)
		_strings(st.recipe_cards(), texts)
		for t: String in texts:
			checked += 1
			var m := bad.search(t)
			assert_true(m == null, "%s: «%s» en «%s»" % [pid, m.get_string() if m != null else "", t.substr(0, 160)])
	assert_true(checked > 2000, "textos revisados: %d" % checked)


func test_valores_y_fuentes() -> void:
	var st := _state("diamante_hpht")
	var rows := st.values_table()
	assert_true(rows.size() >= 15, "los datos de lo que se fabrica: %d" % rows.size())
	for r: Dictionary in rows:
		assert_true(String(r.quality) in ["primary", "secondary", "estimate", "ficcion", "dibujo"], "%s: con su calidad" % r.label)
		assert_true(String(r.source) != "", "%s: con su fuente" % r.label)
	var cards := st.recipe_cards()
	assert_eq(cards.size(), State.PROCESSES.size(), "una tarjeta por proceso")
	for c: Dictionary in cards:
		assert_true(String(c.bench) != "", "%s: dice si el banco tiene el material" % c.id)
		if ForgeData.RECIPES.has(String(c.id)):
			assert_true((c.powders as Array).size() >= 1, "%s: sus polvos" % c.id)
			assert_true(String(c.temp).contains("bien de"), "%s: su margen" % c.id)


func test_lecturas_con_numeros_del_motor() -> void:
	var st := _state("diamante_hpht")
	st.apply_recommended()
	st.load_crucible()
	st.insert_charge()
	st.start()
	for i in 90:
		st.tick(FRAME)
	var rows := {}
	for r: Dictionary in st.readouts():
		rows[String(r.id)] = r
	assert_true(rows.has("horno") and rows.has("brillo") and rows.has("crece"), "el horno, el color del calor y lo que crece")
	assert_true(String(rows.crece.value).contains("mg"), "el diamante HPHT crece en mg (%s)" % rows.crece.value)
	var m := st.margin("temp_c")
	assert_near(float(m.hi), minf(float(ForgeData.RECIPES.diamante_hpht.temp_c.max), ClawForge.kennedy_t_max(5500.0)), 1e-12, 0.0, "el margen acaba en la línea de Kennedy")
	assert_near(float(st.margin("pressure_mpa").lo), ClawForge.kennedy_mpa(float(st.dial.temp_c)), 1e-12, 0.0, "y la presión empieza en ella")
	assert_eq(State.fmt_time(7200.0), "2 h", "un tiempo legible")
	assert_eq(State.fmt_time(5400.0), "1 h 30 min", "con los minutos")
	assert_eq(State.fmt_mpa(5500.0), "5.5 GPa", "una presión legible")
	assert_eq(State.fmt_pct(0.0025), "0.25 %", "una fracción legible")


## El termómetro de la carne viva (ficción): la temperatura de pico y el tono que dice el motor (sin dolor, duele, se
## lesiona: pain e injured de ClawForge), sin umbrales propios.
func test_el_termometro_de_la_carne_viva() -> void:
	for t: float in [60.0, 3600.0]:
		var st := _state(State.LIVE)
		st.apply_recommended()
		st.protect()
		st.set_coat("time_s", t)
		st.coat()
		var th: Variant = (st.snap().coat as Dictionary).get("thermal")
		assert_true(th is Dictionary, "%s s: el motor da el calor de la carne viva" % t)
		if not (th is Dictionary):
			continue
		var lb := st.labels_view(st.snap())
		assert_near(float(lb.thermo_c), float(th.quickPeakC), 1e-12, 0.0, "%s s: la temperatura del motor" % t)
		var want := "mal" if bool(th.injured) else ("aviso" if bool(th.pain) else "bien")
		assert_eq(String(lb.thermo_tone), want, "%s s: y su tono (%s)" % [t, want])


func test_los_nombres_en_una_frase_conservan_las_siglas() -> void:
	assert_eq(State.lower_first("Circonita (CZ)"), "circonita (CZ)", "la sigla, en mayúsculas")
	assert_eq(State.lower_first("Zafiro (Verneuil)"), "zafiro (Verneuil)", "el nombre propio, con su mayúscula")
	assert_eq(State.lower_first("Hidrógeno con metano (CVD)"), "hidrógeno con metano (CVD)")
	assert_eq(State.lower_first(""), "")
	var st := State.new()
	var words: Dictionary = st._bench_words("moissanita")
	assert_true(String(words.text).contains("la moissanita (SiC)"), "la moissanita, con «la» y su sigla: %s" % words.text)
	assert_true(String(st._bench_words("zafiro").text).contains("el zafiro"), "el zafiro, con «el»: %s" % st._bench_words("zafiro").text)
