## El tutorial de la reforja jugado como alguien que juega por primera vez (unidad 5w): cada paso se hace con los gestos de la
## página (los tarros y los botones de la balanza, los mandos, la puerta, «Arrancar», las herramientas…), con los valores que
## dice su texto, nunca con «Hazlo como dice el paso»; «Siguiente» solo en los pasos informativos. Invariantes:
##   - siguiendo el tutorial al pie de la letra, cada una de las diez recetas llega al final y sale bien (en varias garras y
##     formas), y también la piedra comprada, la garra viva (ficción) y la soldadura;
##   - el texto de cada paso dice el valor que hay que buscar (los gramos de cada polvo, el tiempo del dial, el molde);
##   - un paso que ya se cumple al llegar se salta solo y lo dice (con menos de una pasada de sobra, «Desbastar» ya no pide la
##     pasada de la muela gruesa que agujereaba la funda de una garra pequeña);
##   - la cera y el revestimiento piden el molde de la receta (con el de serie, el yeso, el acero y el titanio no salían);
##   - la receta que no sale con esa garra y esa forma lo dice al empezar, no al final de la marcha.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 30.0
## Las garras y formas en que se juega cada receta (las que salen con ella: feasibility).
const CASES := [["rapaz", "aguila", "funda"], ["rapaz", "lechuza", "capuchon"], ["tigre", "tigre", "capuchon"], ["oso", "oso", "funda"]]


static func _settle(st: State) -> void:
	for i in 9000:
		if not st.running() and (st.act.is_empty() or float(st.act.t) >= float(st.act.dur)):
			return
		st.tick(FRAME)


static func _new(animal: String, claw: String, process: String, shape := "funda") -> State:
	var st := State.new({ "animal": animal, "claw": claw })
	st.set_speed(State.SPEEDS.size() - 1)
	st.set_process(process)
	st.set_shape(shape)
	return st


## Los botones de dosis de cada polvo de la receta (los que pinta la tarjeta «La balanza y el crisol»), de la dosis grande a la
## fina, sin pasarse del objetivo que dice la balanza (5w: como lo haría una mano; nada de gramos exactos con decimales largos).
static func _weigh_with_buttons(st: State) -> void:
	for j: Dictionary in st.bench_view().jars:
		if float(j.target_g) <= 0.0:
			continue
		var id := String(j.id)
		for d: Dictionary in j.doses:
			var g := float(d.g)
			for n in 40:
				if float(st.pan.get(id, 0.0)) + g > float(j.target_g) + 1e-12:
					break
				st.add_powder(id, g)
	# y lo que diga la balanza que falta («Falta: echa…»), con la dosis más fina de cada polvo
	for attempt in 3:
		var fix: Dictionary = st.forge.mix_status(st.pan).fix
		if not String(fix.kind) in ["echar", "compensar"]:
			return
		for k: String in fix.add:
			var fine := float(st.doses_for(k)[2])
			for n in int(ceilf(float(fix.add[k]) / fine - 1e-6)):
				st.add_powder(k, fine)


## Gira un mando con sus pasos, como W/S o un clic en el selector (Mayús: el paso fino), hasta el valor; el tiempo, hasta la marca
## del dial que llega a él. Devuelve «» o por qué el dial no llega.
static func _turn_to(st: State, id: String, value: Variant) -> String:
	var c := State.control_data(id)
	if c.has("options"):
		for i in (c.options as Array).size():
			if String(st.dial[id]) == String(value):
				return ""
			st.turn_control(id, 1)
		return "" if String(st.dial[id]) == String(value) else "el selector %s no tiene «%s»" % [id, String(value)]
	var goal := State.time_mark(float(value)) if id == "time_s" else float(value)
	var coarse := { "temp_c": State.TEMP_STEP, "methane": State.METHANE_STEP }
	for n in 400:
		var now := float(st.dial[id])
		if absf(now - goal) < 1e-9:
			return ""
		var fine := coarse.has(id) and absf(goal - now) < float(coarse.get(id, 0.0)) - 1e-9
		st.turn_control(id, 1 if goal > now else -1, fine)
	return "el dial %s no llega a %s (se queda en %s)" % [id, str(goal), str(st.dial[id])]


## Lo que hace una persona en cada paso, con los valores que dice el texto (los args del paso son los mismos que el texto
## escribe; un test aparte comprueba que el texto los dice), con los botones y los pasos de los mandos que tiene la página.
## Devuelve «» o por qué no ha podido.
static func _gesture(st: State, step: Dictionary) -> String:
	var id := String(step.id)
	var args: Variant = step.get("args")
	var why := ""
	match id:
		"pesar":
			# los botones de dosis de cada polvo, hasta el objetivo que dice la balanza; después, «Cargar el crisol»
			_weigh_with_buttons(st)
			if String(st.bench_view().status_text) != "Listo: carga el crisol (L).":
				return "la balanza no dice «Listo» con los botones: %s" % String(st.bench_view().status_text)
			st.load_crucible()
		"modo":
			why = _turn_to(st, "modo", String(ForgeData.RECIPES[st.process].mode))
		"meter":
			st.insert_charge()
		"parametros":
			var fp: Dictionary = args
			for k: String in ["modo", "temp_c", "time_s", "pressure_mpa", "atmosphere", "mold", "methane"]:
				var key := "mode" if k == "modo" else k
				if fp.has(key) and why == "":
					why = _turn_to(st, k, float(fp[key]) * 100.0 if k == "methane" else fp[key])
			if why == "":
				st.start()
		"enfriar":
			why = _turn_to(st, "cool", String(args))
			st.cool_piece()
		"cera":
			why = _turn_to(st, "mold", String(args.mold))
			st.make_wax()
		"revestir":
			why = _turn_to(st, "mold", String(args.mold))
			st.invest()
		"quemar":
			for k: String in ["modo", "temp_c", "time_s"]:
				if why == "":
					why = _turn_to(st, k, "calentar" if k == "modo" else float(args[k]))
			st.insert_charge()
			st.start()
		"romper":
			st.divest()
		"tocho", "cortar_bebedero", "desbastar", "vaciar", "forma", "limar", "repasar", "limar_costura":
			st.set_carve_tool(String(args.tool))
			if args.has("abrasive"):
				st.set_carve("abrasive", String(args.abrasive))
			for i in 40:
				st.carve_pass()
				_settle(st)
				if st.current_step().is_empty() or String(st.current_step().id) != id:
					break
		"proteger":
			st.protect()
		"recubrir":
			if String(step.check) != "":
				st.coat()
		"pulir", "pulir_soldada":
			st.polish()
		"ajuste":
			st.fit_test()
		"elegir", "mezclar":
			st.load_crucible()
		"preparar":
			st.set_weld_params(args)
			st.weld_prepare()
		"alinear":
			st.weld_align_pieces()
		"soldar":
			st.weld_all()
	_settle(st)
	return why


## Juega el tutorial tid. Devuelve [] si llega al final, o lo que le ha atascado.
static func _play(st: State, tid: String) -> Array:
	var stuck: Array = []
	if st.tut_id != tid:
		st.tutorial_goto(tid)
	for n in 90:
		var step: Dictionary = st.current_step()
		if step.is_empty():
			return stuck
		var at := st.tut_step
		var why := _gesture(st, step)
		if why != "":
			stuck.append("%s: %s" % [String(step.id), why])
			return stuck
		if st.tut_step != at:
			continue
		var now: Dictionary = st.current_step()
		if String(now.check) == "":
			st.tutorial_next()
		else:
			stuck.append("%s: %s · %s" % [String(step.id), String(st.view().mistake.get("what", "")), st.notice])
			return stuck
	stuck.append("no acaba")
	return stuck


func test_siguiendo_el_tutorial_al_pie_de_la_letra_cada_receta_llega_al_final() -> void:
	var played := 0
	var skipped: Array = []
	for c: Array in CASES:
		for rid: String in ForgeData.RECIPE_IDS:
			var st := _new(c[0], c[1], rid, c[2])
			if not bool(st.feasibility().ok):
				skipped.append("%s/%s %s" % [c[1], c[2], rid])
				continue
			played += 1
			var stuck := _play(st, rid)
			var tag := "%s/%s %s %s" % [c[0], c[1], c[2], rid]
			assert_true(stuck.is_empty(), "%s: el tutorial llega al final (%s)" % [tag, " | ".join(stuck)])
			assert_true(st.tutorial_done(), "%s: terminado" % tag)
			assert_eq(String(st.forge.report().verdict), "bien", "%s: y la funda sale bien (%s)" % [tag, String(st.forge.report().verdictText)])
			assert_false(st.calls.any(func(k: Array) -> bool: return String(k[0]) == "carve_to"), "%s: a mano, pasada a pasada" % tag)
	# solo no salen los cristales que no caben en su máquina (el HPHT del oso); lo demás se juega entero
	assert_true(played >= 38, "se juegan casi todas (%d; no salen: %s)" % [played, ", ".join(skipped)])
	for k: String in skipped:
		assert_true(k.contains("diamante_hpht") or k.contains("zafiro") or k.contains("rubi"), "solo no sale un cristal que no cabe: %s" % k)


func test_cada_receta_sale_en_alguna_forma_de_cada_garra() -> void:
	# la receta que no sale con una forma tiene que salir con la más pequeña (el capuchón) en las garras de la cetrería
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _new("rapaz", "aguila", rid, "capuchon")
		assert_true(bool(st.feasibility().ok), "%s: con el capuchón del águila, sale (%s)" % [rid, String(st.feasibility().text)])


func test_la_piedra_la_garra_viva_y_la_soldadura_tambien() -> void:
	var stone := _new("rapaz", "aguila", State.STONE)
	assert_true(_play(stone, State.STONE).is_empty(), "la piedra comprada llega al final")
	assert_eq(String(stone.forge.report().verdict), "bien", "y sale bien")
	var live := _new("rapaz", "aguila", State.LIVE)
	var sl := _play(live, State.LIVE)
	assert_true(sl.is_empty(), "la garra viva (ficción) llega al final: %s" % " | ".join(sl))
	assert_eq(String(live.forge.report().verdict), "ficcion", "y es ficción")
	var broken := State.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "from_care": { "stump_mm": 20.0 } })
	broken.set_process(State.ACRYLIC)
	var sa := _play(broken, State.ACRYLIC)
	assert_true(sa.is_empty(), "el acrílico de la garra rota llega al final: %s" % " | ".join(sa))
	assert_true(bool(broken.forge.check("pieza_ok")), "con su bloque mezclado")
	for mid: String in ["acero", "oro", "titanio", "metal_duro"]:
		var st := _new("rapaz", "aguila", mid)
		assert_true(_play(st, mid).is_empty(), "%s: la pieza" % mid)
		var sw := _play(st, State.WELD)
		assert_true(sw.is_empty(), "%s: la soldadura llega al final (%s)" % [mid, " | ".join(sw)])
		assert_true(bool(st.forge.check("soldada")), "%s: y la costura ha salido" % mid)


func test_el_texto_dice_el_valor_que_hay_que_buscar() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _new("rapaz", "aguila", rid)
		var plan := st.forge.mix_plan()
		for s: Dictionary in st.forge.tutorial(rid):
			match String(s.id):
				"pesar":
					assert_true(String(s.text).contains(ClawForge.fmt_mass(float(plan.targetG), float(plan.targetG))), "%s: el total que se pesa" % rid)
					for p: Dictionary in plan.powders:
						assert_true(String(s.text).contains(ClawForge.fmt_mass(float(p.targetG), float(p.targetG))), "%s: los gramos de %s" % [rid, String(p.id)])
				"parametros":
					assert_true(String(s.text).contains(ClawForge.fmt_time(float(s.args.time_s))), "%s: el tiempo del dial" % rid)
					assert_true(String(s.text).contains(_fixed0(float(s.args.temp_c))), "%s: la temperatura" % rid)
				"cera", "revestir":
					var mold_name := ""
					for cd: Dictionary in ForgeData.CONTROLS:
						if String(cd.id) == "mold":
							mold_name = String(cd.option_names[String(s.args.mold)])
					assert_true(String(s.text).contains("«%s»" % mold_name), "%s/%s: el molde del selector" % [rid, String(s.id)])
	# las proporciones de cada receta, como se escriben, suman el 100 % (el metal duro decía 95 % + 5.5 %)
	for rid: String in ForgeData.RECIPE_IDS:
		var sum := 0.0
		for p: Dictionary in ForgeData.RECIPES[rid].powders:
			sum += ForgeTutorial._pct(float(p.value)).trim_suffix(" %").to_float()
		assert_near(sum, 100.0, 1e-9, 0.0, "%s: las proporciones escritas suman el 100 %%" % rid)
	assert_true(String(ForgeTutorial.steps("metal_duro")[0].text).contains("94.5 %"), "el WC del metal duro, el 94.5 %")


static func _fixed0(x: float) -> String:
	return Js.to_fixed(x, 0)


func test_un_paso_que_ya_se_cumple_se_salta_y_lo_dice() -> void:
	# con lo recomendado, el modo ya está puesto: después de cargar, el tutorial pasa al de meter la carga
	var st := _new("rapaz", "aguila", "metal_duro")
	st.tutorial_goto("metal_duro")
	st.apply_recommended()
	st.load_crucible()
	assert_eq(String(st.current_step().id), "meter", "el modo ya estaba puesto: sigue en meter la carga")
	assert_true(String(st.tutorial_view().step.status_text).contains("Ya estaba hecho: «Poner el modo»"), "y lo dice: %s" % String(st.tutorial_view().step.status_text))
	# la garra pequeña: menos de una pasada de la muela gruesa de sobra después del tocho; «Desbastar» se salta y no agujerea
	var small := _new("rapaz", "lechuza", "zafiro", "capuchon")
	small.tutorial_goto("zafiro")
	while not small.current_step().is_empty() and String(small.current_step().id) != "tocho":
		_gesture(small, small.current_step())
		if String(small.current_step().check) == "":
			small.tutorial_next()
	_gesture(small, small.current_step())
	assert_eq(String(small.current_step().id), "vaciar", "con el tocho cortado, «Desbastar» ya se cumple y se salta")
	assert_true(String(small.tutorial_view().step.status_text).contains("Desbastar"), "y lo dice")
	assert_true(bool(small.snap().piece.ok), "la funda sigue entera")
	# Anterior vuelve al paso hecho y no se salta solo
	small.tutorial_prev()
	assert_eq(String(small.current_step().id), "desbastar", "«Anterior» vuelve al paso que se saltó")


func test_la_cera_y_el_revestimiento_piden_el_molde_de_la_receta() -> void:
	for rid: String in ["acero", "titanio"]:
		var st := _new("rapaz", "aguila", rid)
		st.tutorial_goto(rid)
		assert_eq(String(st.dial.mold), "yeso", "%s: el selector empieza en el yeso" % rid)
		st.make_wax()
		assert_eq(String(st.current_step().id), "cera", "%s: la cera para el yeso no da el paso por hecho" % rid)
		assert_true(String(st.mistake_view().what) != "", "%s: y explica por qué: %s" % [rid, String(st.mistake_view().what)])
		assert_true(String(st.mistake_view().fix_text).contains("«Molde»"), "%s: el arreglo dice el selector del molde" % rid)
		st.set_control("mold", String(ForgeData.RECIPES[rid].mold.value))
		st.make_wax()
		assert_eq(String(st.current_step().id), "revestir", "%s: con el molde de la receta, sigue" % rid)
		assert_true(st.mistake_view().is_empty(), "%s: y el error deja de explicarse" % rid)


func test_la_receta_que_no_sale_lo_dice_al_empezar() -> void:
	var big := _new("oso", "oso", "diamante_hpht", "funda")
	var fz := big.feasibility()
	assert_false(bool(fz.ok), "el cristal HPHT de la funda del oso no sale")
	assert_true(String(fz.text).contains("Capuchón"), "y dice qué probar: %s" % String(fz.text))
	assert_eq(big.view().feasible, fz, "la vista lo lleva")
	var ok := _new("rapaz", "aguila", "diamante_hpht", "funda")
	assert_true(bool(ok.feasibility().ok), "la del águila, sí")
	# y lo que dice es lo que pasa: con lo recomendado, la marcha sale mal
	big.apply_recommended()
	big.load_crucible()
	big.insert_charge()
	big.start()
	_settle(big)
	assert_false(bool(big.forge.check("parametros_ok")), "sin salida de verdad: con lo recomendado, no sale")


## Juega el tutorial que se sigue hasta llegar al paso sid (sin hacerlo). Devuelve si ha llegado.
static func _play_until(st: State, sid: String) -> bool:
	for n in 90:
		var step: Dictionary = st.current_step()
		if step.is_empty():
			return false
		if String(step.id) == sid:
			return true
		var at := st.tut_step
		if _gesture(st, step) != "":
			return false
		if st.tut_step == at:
			if String(st.current_step().check) != "":
				return false
			st.tutorial_next()
	return false


func test_los_valores_de_cada_paso_se_pueden_poner_con_los_mandos() -> void:
	# el dial del tiempo va por marcas y el de la temperatura de 5 en 5 °C: el paso pide lo que el dial marca (antes, «1 h 6 min o
	# más» o «871 °C», que no se podían poner), y lo dice
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _new("rapaz", "aguila", rid)
		for s: Dictionary in st.steps():
			match String(s.id):
				"parametros":
					assert_true(State.TIME_STEPS.has(float(s.args.time_s)), "%s: el tiempo, una marca del dial (%s)" % [rid, str(s.args.time_s)])
					assert_true(float(s.args.time_s) >= float(st.forge.recommended().fire.time_s), "%s: que llega a lo que tarda la funda" % rid)
					assert_true(String(s.text).contains(State.fmt_time(float(s.args.time_s))), "%s: y el paso la dice" % rid)
					assert_near(fmod(float(s.args.temp_c), State.TEMP_FINE), 0.0, 1e-9, 0.0, "%s: la temperatura, de 5 en 5 °C" % rid)
					assert_true(State.PRESSURE_STEPS.has(float(s.args.pressure_mpa)), "%s: la presión, una marca del dial" % rid)
				"quemar":
					var tc := float(s.args.temp_c)
					assert_near(fmod(tc, State.TEMP_FINE), 0.0, 1e-9, 0.0, "%s: el quemado, de 5 en 5 °C (%s)" % [rid, str(tc)])
					assert_true(String(s.text).contains("%s °C" % Js.to_fixed(tc, 0)), "%s: y el paso la dice" % rid)
					assert_true(State.TIME_STEPS.has(float(s.args.time_s)), "%s: el tiempo del quemado, una marca del dial" % rid)


func test_otra_pieza_vuelve_al_primer_paso_y_llega_al_final() -> void:
	# a medias, «Otra pieza»: antes el tutorial se quedaba en «Repasar la piel», que con la pieza nueva no se cumplía nunca
	var st := _new("rapaz", "aguila", "metal_duro")
	st.tutorial_goto("metal_duro")
	assert_true(_play_until(st, "repasar"), "llega a repasar")
	st.restart()
	assert_eq(String(st.current_step().id), "pesar", "con otra pieza, el tutorial vuelve a pesar")
	assert_true(st.notice.contains("primer paso"), "y lo dice: %s" % st.notice)
	var sr := _play(st, "metal_duro")
	assert_true(sr.is_empty(), "y llega al final: %s" % " | ".join(sr))
	# otra forma de funda a medias, igual
	var sh := _new("rapaz", "aguila", "zafiro")
	sh.tutorial_goto("zafiro")
	assert_true(_play_until(sh, "parametros"), "llega a los parámetros")
	sh.set_shape("capuchon")
	assert_eq(String(sh.current_step().id), "pesar", "con otra forma, vuelve a pesar (la carga de antes ya no es la de esta funda)")
	assert_true(_play(sh, "zafiro").is_empty(), "y llega al final")
	# la soldadura pide una pieza hecha: con otra pieza, vuelve al tutorial de la receta
	var w := _new("rapaz", "aguila", "acero")
	assert_true(_play(w, "acero").is_empty(), "el acero, hecho")
	w.tutorial_goto(State.WELD)
	w.restart()
	assert_eq(w.tut_id, "acero", "otra pieza desde la soldadura: el tutorial del acero")
	assert_eq(w.tut_step, 0, "desde el primer paso")
	# el tutorial del horno no depende de la pieza: no se mueve
	var g := _new("rapaz", "aguila", "oro")
	g.tutorial_goto(State.GENERAL)
	g.tutorial_next()
	g.tutorial_next()
	g.restart()
	assert_eq(g.tut_step, 2, "el del horno sigue donde estaba")


func test_la_pieza_que_ya_no_se_arregla_pide_otra_pieza() -> void:
	var st := _new("rapaz", "aguila", "zafiro")
	st.tutorial_goto("zafiro")
	assert_true(_play_until(st, "enfriar"), "llega a enfriar")
	assert_eq(_turn_to(st, "cool", "agua"), "", "el selector en el agua")
	st.cool_piece()
	_settle(st)
	assert_false(bool(st.snap().piece.ok), "el zafiro templado en agua se agrieta")
	assert_eq(String(st.current_step().id), "enfriar", "y el paso no se cumple")
	assert_true(String(st.tutorial_view().step.status_text).contains("«Otra pieza»"), "el tutorial dice cómo seguir: %s" % String(st.tutorial_view().step.status_text))
	var mv := st.mistake_view()
	assert_eq(String(mv.fix_title), "Otra pieza", "el arreglo es otra pieza (antes, «Enfría: al aire», que ya no servía)")
	assert_true(String(mv.fix_text).contains("La próxima vez, «Enfriar»"), "y cómo hacerlo bien: %s" % String(mv.fix_text))
	st.restart()
	assert_true(st.mistake_view().is_empty(), "con otra pieza, el error se va")
	var sr := _play(st, "zafiro")
	assert_true(sr.is_empty(), "y el tutorial llega al final: %s" % " | ".join(sr))
	assert_eq(String(st.forge.report().verdict), "bien", "con la funda bien")
	# la marcha mal sí se arregla con los mandos: no pide otra pieza
	var bad := _new("rapaz", "aguila", "metal_duro")
	bad.tutorial_goto("metal_duro")
	assert_true(_play_until(bad, "parametros"), "llega a los parámetros")
	_turn_to(bad, "temp_c", 1000.0)
	bad.start()
	_settle(bad)
	assert_eq(bad.restart_hint(), "", "con la marcha mal, se vuelve a arrancar: no pide otra pieza")


func test_al_terminar_el_del_horno_dice_que_sigue() -> void:
	var st := _new("rapaz", "aguila", "zafiro")
	st.tutorial_goto(State.GENERAL)
	for i in 40:
		if st.tutorial_done():
			break
		st.tutorial_next()
	assert_true(st.tutorial_done(), "el del horno se recorre con «Siguiente»")
	assert_true(String(st.tutorial_view().done_text).contains("elige arriba una receta"), "y al terminar dice que sigue: %s" % String(st.tutorial_view().done_text))
