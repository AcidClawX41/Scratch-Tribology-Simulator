## El guiado botón a botón del tutorial de la reforja (unidad 5x; core/lab/claw_forge_guide.gd). Invariantes:
##   - cada paso de cada tutorial (el horno, las diez recetas, la piedra, la garra viva, el acrílico y la soldadura) tiene un
##     objetivo con la forma del contrato (core/shared/guide_target.gd), y todos los pasos salen en la secuencia;
##   - jugar el tutorial pulsando solo lo que señala el guiado llega al final con la pieza bien (en varias garras y formas);
##   - la secuencia de cada receta es la suya: sus polvos, su modo, su temperatura, su tiempo, su presión, su atmósfera, su
##     molde, su enfriado, sus herramientas y su pulido, con el valor exacto; la de cada método de soldadura, con sus mandos;
##   - el objetivo cambia con el estado (falta un polvo → su botón; la mezcla lista → «Cargar el crisol»; un dial que se mueve
##     → otra vez ese dial) y el aviso dice lo que falta de verdad;
##   - sin tutorial, o sin «Guiado», no hay guiado; los números de las etiquetas y los avisos van con punto decimal, como el resto
##     de la reforja (Js.to_fixed): en una misma pantalla, una sola forma.
extends "res://tests/case.gd"

const Play = preload("res://tests/lab/forge_guide_play.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeGuide = preload("res://core/lab/claw_forge_guide.gd")
const Guide = preload("res://core/shared/guide_target.gd")
const Js = preload("res://core/shared/js.gd")

const CASES := [["rapaz", "aguila", "funda"], ["rapaz", "lechuza", "capuchon"], ["tigre", "tigre", "capuchon"], ["oso", "oso", "funda"]]
## Un número con coma decimal en un texto visible del guiado (van con punto, como el panel y la escena de la reforja).
const COMMA_NUMBER := "\\d,\\d"


static func _steps_in(seq: Array) -> Dictionary:
	var out := {}
	for g: Dictionary in seq:
		out[String(g.step)] = true
	return out


static func _with(seq: Array, id: String, step := "") -> Array:
	return seq.filter(func(g: Dictionary) -> bool: return String(g.id) == id and (step == "" or String(g.step) == step))


func _check_seq(tag: String, st: State, tid: String, seq: Array) -> void:
	var re := RegEx.create_from_string(COMMA_NUMBER)
	for g: Dictionary in seq:
		assert_true(Guide.is_valid(g), "%s: el objetivo tiene la forma del contrato (%s)" % [tag, str(g)])
		# el aviso de la vista dice el valor de la receta o lo que falta
		assert_true(String(g.value) == "" or String(g.hint).contains(String(g.value)), "%s: el aviso lleva el valor «%s»: %s" % [tag, String(g.value), String(g.hint)])
		assert_true(re.search(String(g.hint)) == null and re.search(String(g.label)) == null, "%s: con punto decimal, como el resto de la reforja: «%s» · «%s»" % [tag, String(g.hint), String(g.label)])
	var seen := _steps_in(seq)
	var tut := st.forge.tutorial(tid)
	for s: Dictionary in tut:
		# un paso que ya se cumple al llegar se salta solo (5w): no hace falta señalarlo
		if not seen.has(String(s.id)) and String(s.check) != "":
			continue
		assert_true(seen.has(String(s.id)), "%s: el paso «%s» tiene objetivo" % [tag, String(s.id)])


func test_cada_paso_de_cada_tutorial_tiene_su_objetivo_y_se_juega_hasta_el_final() -> void:
	var g0 := Play.new_state("rapaz", "aguila", "zafiro")
	var r0 := Play.play(g0, State.GENERAL)
	assert_true(bool(r0.ok), "el del horno: %s" % String(r0.why))
	_check_seq("horno", g0, State.GENERAL, r0.seq)
	assert_eq((r0.seq as Array).size(), g0.forge.tutorial(State.GENERAL).size(), "el del horno, un «Siguiente» por paso")
	for tid: String in [State.STONE, State.LIVE]:
		var st := Play.new_state("rapaz", "aguila", tid)
		var r := Play.play(st, tid)
		assert_true(bool(r.ok), "%s: %s" % [tid, String(r.why)])
		_check_seq(tid, st, tid, r.seq)
	var stone := Play.new_state("rapaz", "aguila", State.STONE)
	Play.play(stone, State.STONE)
	assert_eq(String(stone.forge.report().verdict), "bien", "la piedra comprada sale bien")
	var broken := State.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "from_care": { "stump_mm": 20.0 } })
	broken.set_process(State.ACRYLIC)
	var ra := Play.play(broken, State.ACRYLIC)
	assert_true(bool(ra.ok), "el acrílico: %s" % String(ra.why))
	_check_seq("acrilico", broken, State.ACRYLIC, ra.seq)
	assert_true(bool(broken.forge.check("pieza_ok")), "el acrílico, mezclado")


func test_jugar_pulsando_solo_el_guiado_llega_al_final_con_la_pieza_bien() -> void:
	var played := 0
	for c: Array in CASES:
		for rid: String in ForgeData.RECIPE_IDS:
			var st := Play.new_state(c[0], c[1], rid, c[2])
			if not bool(st.feasibility().ok):
				continue
			played += 1
			var tag := "%s/%s %s %s" % [c[0], c[1], c[2], rid]
			var r := Play.play(st, rid)
			assert_true(bool(r.ok), "%s: llega al final pulsando solo el guiado (%s)" % [tag, String(r.why)])
			assert_eq(String(st.forge.report().verdict), "bien", "%s: y la funda sale bien (%s)" % [tag, String(st.forge.report().verdictText)])
			_check_seq(tag, st, rid, r.seq)
	assert_true(played >= 38, "se juegan casi todas (%d)" % played)


func test_la_secuencia_de_cada_receta_es_la_suya_con_sus_valores() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := Play.new_state("rapaz", "aguila", rid)
		var steps := st.steps()
		var r := Play.play(st, rid)
		assert_true(bool(r.ok), "%s: %s" % [rid, String(r.why)])
		var seq: Array = r.seq
		var rec: Dictionary = ForgeData.RECIPES[rid]
		# los polvos: los de la receta, y ninguno más
		var want := {}
		for p: Dictionary in rec.powders:
			want[String(p.id)] = true
		var got := {}
		for g: Dictionary in seq:
			if String(g.id).begins_with("dosis:"):
				got[String(g.id).split(":")[1]] = true
		assert_eq(got.keys().size(), want.keys().size(), "%s: un botón de dosis por polvo de la receta (%s)" % [rid, str(got.keys())])
		for k: String in want:
			assert_true(got.has(k), "%s: el botón de dosis de %s" % [rid, k])
		# el modo de la receta, con su nombre en el selector
		var mode := String(rec.mode)
		var mt := _with(seq, "mando:modo:" + mode, "modo")
		assert_true(not mt.is_empty(), "%s: el selector de modo en «%s»" % [rid, mode])
		if not mt.is_empty():
			assert_eq(String(mt[0].value), String(State.value_text("modo", mode)), "%s: con su nombre" % rid)
			assert_true(String(mt[0].label).begins_with("Selector de modo: "), "%s: la etiqueta dice el selector: %s" % [rid, String(mt[0].label)])
		# cada mando de la marcha, a su valor exacto
		for s: Dictionary in steps:
			match String(s.id):
				"parametros":
					var a: Dictionary = s.args
					for cid: String in ["temp_c", "time_s"]:
						var tt := _with(seq, "mando:" + cid, "parametros")
						assert_true(not tt.is_empty(), "%s: el %s se señala" % [rid, cid])
						for g: Dictionary in tt:
							assert_eq(String(g.value), State.value_text(cid, float(a[cid])), "%s: %s a su marca" % [rid, cid])
							assert_true(String(g.hint).contains(String(g.value)), "%s: el aviso lleva el valor: %s" % [rid, String(g.hint)])
					if String(a.atmosphere) != "aire":
						var at := _with(seq, "mando:atmosphere:" + String(a.atmosphere), "parametros")
						assert_true(not at.is_empty(), "%s: la atmósfera «%s»" % [rid, String(a.atmosphere)])
					if absf(float(a.pressure_mpa) - 0.101) > 1e-9:
						var pt := _with(seq, "mando:pressure_mpa", "parametros")
						assert_true(not pt.is_empty() and String(pt[0].value) == State.value_text("pressure_mpa", float(a.pressure_mpa)), "%s: la presión a %s" % [rid, str(a.pressure_mpa)])
					if a.has("methane"):
						var mm := _with(seq, "mando:methane", "parametros")
						assert_true(not mm.is_empty() and String(mm[0].value) == State.value_text("methane", float(a.methane) * 100.0), "%s: el metano" % rid)
					assert_true(not _with(seq, "arrancar", "parametros").is_empty(), "%s: y «Arrancar»" % rid)
				"enfriar":
					if String(s.args) != "aire":
						assert_true(not _with(seq, "mando:cool:" + String(s.args), "enfriar").is_empty(), "%s: enfriar «%s»" % [rid, String(s.args)])
					assert_true(not _with(seq, "enfriar", "enfriar").is_empty(), "%s: «Sacar y enfriar»" % rid)
				"cera":
					if String(s.args.mold) != "yeso":
						assert_true(not _with(seq, "mando:mold:" + String(s.args.mold), "cera").is_empty(), "%s: el molde «%s»" % [rid, String(s.args.mold)])
				"quemar":
					var qt := _with(seq, "mando:temp_c", "quemar")
					assert_true(not qt.is_empty() and String(qt[0].value) == State.value_text("temp_c", float(s.args.temp_c)), "%s: el quemado a %s °C" % [rid, str(s.args.temp_c)])
				"tocho", "cortar_bebedero", "desbastar", "vaciar", "forma", "limar", "repasar":
					var passes := _with(seq, "pasada", String(s.id))
					if not passes.is_empty():
						var tool := String(s.step_args.tool) if s.has("step_args") else String(s.args.tool)
						assert_eq(String(passes[0].value), String(ForgeData.CARVE_TOOLS[tool].get("short", tool)), "%s/%s: la pasada con su herramienta" % [rid, String(s.id)])
				"pulir":
					assert_true(not _with(seq, "pulir", "pulir").is_empty(), "%s: «Pulir»" % rid)


func test_cada_metodo_de_soldadura_con_su_guiado() -> void:
	# el acero, con el láser pulsado; el oro, con el micro-TIG; el metal duro, con la soldadura fuerte de plata
	for e: Array in [["acero", "laser"], ["oro", "tig"], ["metal_duro", "braze"], ["titanio", "laser"]]:
		var mid := String(e[0])
		var st := Play.new_state("rapaz", "aguila", mid)
		assert_true(bool(Play.play(st, mid).ok), "%s: la pieza" % mid)
		var args: Dictionary = st.forge.tutorial(State.WELD)[1].args
		assert_eq(String(args.method), String(e[1]), "%s: el método que recomienda el motor" % mid)
		var r := Play.play(st, State.WELD)
		assert_true(bool(r.ok), "%s: la soldadura llega al final pulsando solo el guiado (%s)" % [mid, String(r.why)])
		assert_true(bool(st.forge.check("soldada")), "%s: y la costura ha salido" % mid)
		var seq: Array = r.seq
		var rec := _with(seq, "soldar_recomendado")
		assert_true(not rec.is_empty(), "%s: «Poner lo recomendado»" % mid)
		if not rec.is_empty():
			var vt := String(rec[0].value)
			assert_eq(vt, ForgeGuide.weld_values_text(args), "%s: con los valores de su método" % mid)
			assert_true(vt.begins_with(String(ClawWeld.METHODS[String(e[1])].name)), "%s: empieza por el método: %s" % [mid, vt])
			for k: String in ["energy_j", "current_a", "temp_c", "gap_mm"]:
				if args.has(k):
					assert_true(vt.contains(Js.js_num_str(float(args[k]))), "%s: %s en el aviso (%s)" % [mid, k, vt])
		for id: String in ["soldar_colocar", "soldar_alinear", "costura", "pasada", "pulir"]:
			assert_true(not _with(seq, id).is_empty(), "%s: señala «%s»" % [mid, id])
		var seam := _with(seq, "costura")
		var us := {}
		for g: Dictionary in seam:
			assert_true(float(g.u) > 0.0 and float(g.u) < 1.0, "%s: el punto de la costura que toca (%s)" % [mid, str(g.u)])
			us[Js.to_fixed(float(g.u), 3)] = true
		assert_true(us.size() > 1, "%s: el punto avanza por la costura" % mid)
		assert_true(String(seam[0].hint).begins_with("Mantén pulsado sobre la costura"), "%s: dice dónde mantener pulsado" % mid)
		_check_seq(mid + "/soldadura", st, State.WELD, seq)


func test_el_objetivo_cambia_con_el_estado() -> void:
	var st := Play.new_state("rapaz", "aguila", "metal_duro")
	st.tutorial_goto("metal_duro")
	var plan := st.forge.mix_plan()
	var wc := 0.0
	var co := 0.0
	for p: Dictionary in plan.powders:
		if String(p.id) == "wc":
			wc = float(p.targetG)
		else:
			co = float(p.targetG)
	var g := st.guide_view()
	assert_true(String(g.id).begins_with("dosis:wc:"), "al empezar, un botón de dosis del WC (%s)" % String(g.id))
	assert_eq(String(g.hint), "Ahora toca añadir %s de WC" % ClawForge.fmt_mass(wc, wc), "el aviso con los gramos del WC")
	assert_eq(String(g.where), "panel", "en el panel")
	assert_eq(String(g.scene), "tarro:wc", "y su tarro en la escena")
	assert_eq(String(g.view), "banco", "con la vista de la balanza")
	# casi todo el WC: lo que falta de verdad
	st.add_powder("wc", wc - 0.01)
	g = st.guide_view()
	assert_eq(String(g.hint), "Añade %s de WC" % ClawForge.fmt_mass(0.01, wc), "lo que falta: %s" % String(g.hint))
	st.add_powder("wc", 0.01)
	g = st.guide_view()
	assert_eq(String(g.id), "tara", "con el WC en su objetivo, la tara para pesar el cobalto")
	st.tare()
	g = st.guide_view()
	assert_true(String(g.id).begins_with("dosis:co:"), "si falta cobalto, su botón de dosis (%s)" % String(g.id))
	assert_true(String(g.label).begins_with("Pulsa aquí: +"), "con «Pulsa aquí»: %s" % String(g.label))
	assert_true(String(g.label).ends_with("de cobalto"), "del cobalto: %s" % String(g.label))
	assert_eq(String(g.hint), "Ahora toca añadir %s de Co" % ClawForge.fmt_mass(co, co), "y sus gramos: %s" % String(g.hint))
	st.add_powder("co", co)
	g = st.guide_view()
	assert_eq(String(g.id), "cargar", "con la mezcla lista, «Cargar el crisol»")
	assert_eq(String(g.scene), "crisol", "y el crisol en la escena")
	# un polvo que no va: vaciar el plato
	st.add_powder("al2o3", 1.0)
	assert_eq(String(st.guide_view().id), "vaciar", "con un polvo que no va, vaciar el plato")
	st.clear_pan()
	assert_true(String(st.guide_view().id).begins_with("dosis:wc:"), "y se vuelve a pesar")
	# en la marcha: el dial que se mueve después de ponerlo vuelve a ser el objetivo
	st.apply_recommended()
	st.load_crucible()
	assert_eq(String(st.current_step().id), "meter", "(el modo ya estaba: meter la carga)")
	st.insert_charge()
	Play.settle(st)
	assert_eq(String(st.current_step().id), "parametros", "(los parámetros)")
	# lo recomendado pone el tiempo que tarda la funda; el paso pide la marca del dial que llega a él
	var fa: Dictionary = st.steps()[3].args
	if absf(float(st.dial.time_s) - float(fa.time_s)) > 1e-9:
		assert_eq(String(st.guide_view().id), "mando:time_s", "el tiempo, a la marca del dial")
	st.set_control("time_s", float(fa.time_s))
	g = st.guide_view()
	assert_eq(String(g.id), "arrancar", "con lo recomendado, «Arrancar»")
	st.turn_control("temp_c", 1)
	g = st.guide_view()
	assert_eq(String(g.id), "mando:temp_c", "con la temperatura movida, otra vez su dial")
	assert_eq(String(g.label), "Dial de temperatura: %s" % State.value_text("temp_c", float(st.steps()[3].args.temp_c)), "con su valor: %s" % String(g.label))
	st.set_control("atmosphere", "aire")
	assert_eq(String(st.guide_view().id), "mando:temp_c", "va por orden: primero la temperatura")
	st.set_control("temp_c", float(st.steps()[3].args.temp_c))
	g = st.guide_view()
	assert_eq(String(g.id), "mando:atmosphere:vacio", "después, la atmósfera de la receta")
	assert_eq(String(g.hint), "Pon la atmósfera en «Vacío»", "dicha con su nombre: %s" % String(g.hint))
	# con la marcha en curso: esperar o «Acabar ya»
	st.set_control("atmosphere", "vacio")
	st.start()
	assert_true(st.running(), "(arranca)")
	assert_eq(String(st.guide_view().id), "acabar", "con la marcha en curso, «Acabar ya»")


func test_sin_tutorial_o_sin_guiado_no_hay_guiado() -> void:
	var st := Play.new_state("rapaz", "aguila", "zafiro")
	st.tutorial_goto("zafiro")
	assert_true(bool(st.guide_view().on), "con el tutorial, guiado")
	assert_true(bool(st.view().guide.on), "también en la vista")
	st.set_tutorial(false)
	assert_false(bool(st.guide_view().on), "sin tutorial, no hay guiado")
	assert_false(bool(st.view().guide.on), "ni en la vista")
	assert_eq(String(st.view().guide.hint), "", "ni aviso")
	assert_eq(String(st.view().guide.panel), "", "ni control del panel")
	assert_eq(String(st.view().guide.scene), "", "ni objeto de la escena")
	st.set_tutorial(true)
	st.set_guide(false)
	assert_false(bool(st.view().guide.on), "con el «Guiado» apagado, solo el texto")
	assert_true(String(st.view().tutorial.step.text) != "", "(el texto del paso sigue)")
	st.set_guide(true)
	for i in 40:
		st.tutorial_next()
	assert_true(st.tutorial_done(), "(terminado)")
	assert_false(bool(st.guide_view().on), "con el tutorial terminado, nada")


func test_sin_pieza_la_soldadura_pide_primero_la_pieza() -> void:
	var st := Play.new_state("rapaz", "aguila", "acero")
	st.tutorial_goto(State.WELD)
	st.tutorial_next()
	var g := st.guide_view()
	assert_eq(String(g.id), "tutorial:acero", "sin pieza, el tutorial de la receta (%s)" % String(g.id))
	st.callv(String(g.op), g.args)
	assert_eq(st.tut_id, "acero", "y lo abre")


func test_el_guiado_es_determinista() -> void:
	var a := Play.play(Play.new_state("rapaz", "aguila", "oro"), "oro")
	var b := Play.play(Play.new_state("rapaz", "aguila", "oro"), "oro")
	assert_eq(var_to_str(a.seq), var_to_str(b.seq), "la misma secuencia dos veces")
