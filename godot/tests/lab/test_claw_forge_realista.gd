## La reforja realista (unidad 5m; petición 42): la carga dentro de su máquina, el tiempo de verdad a la velocidad elegida, la
## cera perdida con el molde de la garra, el tallado por pasadas y el laboratorio que acaba en la funda sin pegar (petición 43).
## Invariantes, no números mágicos:
##   - sin la carga dentro de la máquina del modo, «Arrancar» no arranca y dice por qué;
##   - más deprisa, la marcha dura menos (o lo mismo, con los topes) y sale lo mismo; cambiar la velocidad en marcha, también;
##   - el reloj llega al tiempo programado (el del dial; el del ciclo del quemado; el del enfriado que da el motor);
##   - un mineral duro no se cuela, y lo dice;
##   - la pieza colada tiene la forma de la garra elegida, con su contracción (compensada, la escala es 1);
##   - una herramienta más blanda no talla; la fina sigue la línea y la gruesa se pasa; en seco y apretando, los errores de §5;
##   - el laboratorio acaba en la funda terminada y sin pegar, con la prueba del ajuste, lista para la cetrería.
extends "res://tests/case.gd"

const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")

const FRAME := 1.0 / 30.0
const CAST_IDS := ["oro", "acero", "titanio", "vidrio"]


static func _state(process := "zafiro", p := {}) -> State:
	var setup := { "animal": "rapaz", "claw": "aguila" }
	setup.merge(p, true)
	var st := State.new(setup)
	st.set_process(process)
	return st


static func _run(st: State) -> void:
	var n := 0
	while st.running() and n < int((State.RUN_MAX_S + 5.0) / FRAME):
		st.tick(FRAME)
		n += 1


static func _settle(st: State) -> void:
	for i in int((State.ACT_MAX_S + 2.0) / FRAME):
		if st.act.is_empty() or float(st.act.t) >= float(st.act.dur):
			return
		st.tick(FRAME)


## Sigue el tutorial del proceso con «Hazlo como dice el paso», dejando correr cada marcha y cada animación.
static func _follow(st: State) -> void:
	st.tutorial_goto(st.process)
	var n := 0
	while not st.tutorial_done() and n < 80:
		st.do_step()
		_run(st)
		_settle(st)
		n += 1


## El motor, hasta la colada de la cera perdida de una receta (con o sin la cera a la medida de la contracción).
static func _cast(rid: String, animal := "rapaz", claw := "aguila", compensate := true) -> ClawForge:
	var f := ClawForge.new({ "animal": animal, "claw": claw, "recipe": rid })
	var rec := f.recommended()
	f.wax({ "compensate": compensate, "mold": String(rec.wax.mold) })
	f.invest(rec.invest)
	f.load_machine({ "machine": "calentar", "what": "molde" })
	f.burnout(rec.burnout)
	f.mix(rec.mix)
	f.load_machine(rec.load_machine)
	f.fire(rec.fire)
	return f


func test_sin_la_carga_dentro_no_arranca() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _state(rid)
		st.apply_recommended()
		st.load_crucible()
		st.start()
		assert_false(st.running(), "%s: sin la carga dentro, no arranca" % rid)
		assert_true(st.notice.begins_with("No arranca"), "%s: y dice por qué: %s" % [rid, st.notice])
		assert_false(st.calls.any(func(c: Array) -> bool: return String(c[0]) in ["fire", "heat", "burnout"]), "%s: el horno no ha trabajado" % rid)
		var m := st.mistake_view()
		assert_true(String(m.fix_title).contains("Meter la carga"), "%s: el error se arregla con el paso de meter la carga (%s)" % [rid, m.fix_title])
		assert_true(String(m.control).contains("tecla M"), "%s: y dice cómo" % rid)
		st.insert_charge()
		assert_eq(st.charge_inside(), ClawForge.charge_for(ClawForge.machine_for(String(ForgeData.RECIPES[rid].mode), ForgeData.RECIPES[rid])), "%s: dentro, lo de su máquina" % rid)
		st.start()
		assert_true(st.running(), "%s: con la carga dentro, arranca" % rid)
		assert_eq(st.notice, "", "%s: sin aviso" % rid)
	# metida en una máquina y con el modo de otra: tampoco, y dice dónde está
	var other := _state("zafiro")
	other.apply_recommended()
	other.load_crucible()
	other.insert_charge()
	other.set_control("modo", "sinterizar")
	other.start()
	assert_false(other.running(), "con el modo de otra máquina, no arranca")
	assert_true(other.notice.contains("la carga está en"), "y dice dónde está la carga: %s" % other.notice)
	# el crisol vacío: lo dice el motor, y se arregla pesando
	var empty := _state("rubi")
	empty.apply_recommended()
	empty.insert_charge()
	assert_true(empty.notice.contains("vacío"), "sin cargar lo pesado, no hay nada que meter: %s" % empty.notice)
	assert_true(String(empty.mistake_view().fix_title).to_lower().contains("pesar"), "y se arregla pesando")
	# la piedra comprada se mete en el horno de calentar para ver qué le hace el calor
	var stone := _state(State.STONE)
	stone.choose_stone("cuarzo")
	stone.set_control("modo", "calentar")
	stone.start()
	assert_false(stone.running(), "la piedra fuera del horno: no arranca")
	stone.insert_charge()
	assert_eq(stone.charge_inside(), "pieza", "la piedra, dentro")
	stone.set_control("temp_c", 700.0)
	stone.start()
	assert_true(stone.running() and bool(stone.run.heat), "y el horno de calentar la calienta")


func test_mas_deprisa_dura_menos_y_sale_lo_mismo() -> void:
	for rid: String in ["zafiro", "diamante_hpht", "alumina", "oro"]:
		var holds: Array = []
		var results: Array = []
		for i in State.SPEEDS.size():
			var st := _state(rid)
			st.set_speed(i)
			st.apply_recommended()
			st.load_crucible()
			st.insert_charge()
			st.start()
			holds.append(float(st.run.hold))
			_run(st)
			results.append(var_to_str([st.forge.snapshot().fire, st.forge.snapshot().piece]))
			assert_near(float(st.run.hold), st.play_s(float(st.dial.time_s), State.RUN_MIN_S, State.RUN_MAX_S), 1e-12, 0.0, "%s a %s: el tiempo de verdad entre la velocidad, con sus topes" % [rid, State.SPEED_NAMES[i]])
		for i in range(1, State.SPEEDS.size() - 1):
			assert_true(float(holds[i]) <= float(holds[i - 1]) + 1e-12, "%s: %s no dura más que %s (%s s, %s s)" % [rid, State.SPEED_NAMES[i], State.SPEED_NAMES[i - 1], holds[i], holds[i - 1]])
		assert_eq(float(holds[State.SPEEDS.size() - 1]), State.RUN_MIN_S, "%s: lo más rápido, lo menos" % rid)
		for i in range(1, results.size()):
			assert_eq(results[i], results[0], "%s: a %s sale lo mismo que a %s" % [rid, State.SPEED_NAMES[i], State.SPEED_NAMES[0]])
	# cambiar la velocidad con la marcha en curso: la misma fracción de lo hecho, el mismo resultado
	var a := _state("diamante_hpht")
	var b := _state("diamante_hpht")
	for st: State in [a, b]:
		st.set_speed(0)
		st.apply_recommended()
		st.load_crucible()
		st.insert_charge()
		st.start()
		for i in 60:
			st.tick(FRAME)
	var p0 := float(b.run_view().progress)
	var proc0 := float(b.run_view().proc_s)
	b.set_speed(3)
	assert_near(float(b.run_view().progress), p0, 1e-9, 1e-9, "al cambiar la velocidad, la marcha sigue por donde iba")
	assert_near(float(b.run_view().proc_s), proc0, 1e-6, 1e-9, "y el reloj de verdad marca lo mismo")
	assert_true(float(b.run.hold) < float(a.run.hold), "más deprisa, lo que falta dura menos")
	_run(a)
	_run(b)
	assert_eq(var_to_str(b.forge.snapshot().piece), var_to_str(a.forge.snapshot().piece), "y sale la misma pieza")


func test_el_reloj_llega_al_tiempo_programado() -> void:
	for rid: String in ["zafiro", "diamante_cvd", "metal_duro"]:
		var st := _state(rid)
		st.apply_recommended()
		st.load_crucible()
		st.insert_charge()
		st.start()
		var c0 := st.clock_view()
		assert_true(bool(c0.on) and bool(c0.active), "%s: el reloj corre con la marcha" % rid)
		var last := -1.0
		while st.running():
			var c := st.clock_view()
			assert_true(float(c.done_s) >= last - 1e-9, "%s: el reloj nunca va hacia atrás" % rid)
			last = float(c.done_s)
			st.tick(FRAME)
		var end := st.clock_view()
		var want := float(st.dial.time_s)
		assert_near(float(end.done_s), want, 1e-9, 1e-9, "%s: llega al tiempo del dial" % rid)
		assert_eq(String(end.text), "%s de %s" % [State.fmt_time(want), State.fmt_time(want)], "%s: «%s»" % [rid, end.text])
		assert_true(String(end.life).begins_with("En la vida real tardaría %s" % State.fmt_time(want)), "%s: y lo que tardaría de verdad: %s" % [rid, end.life])
	# el quemado de la cera: el reloj cuenta el ciclo entero (las subidas y los mantenimientos), y el horno sigue el ciclo
	var lw := _state("oro")
	lw.apply_recommended()
	lw.make_wax()
	lw.invest()
	_settle(lw)
	lw.apply_recommended()
	assert_eq(String(lw.dial.modo), "calentar", "lo recomendado, con el molde revestido: el quemado")
	lw.insert_charge()
	assert_eq(lw.charge_inside(), "molde", "el molde, dentro del horno")
	lw.start()
	var plan: Dictionary = lw.last.burnout.plan
	assert_near(float(lw.run.real_s), float(plan.realS), 1e-9, 0.0, "el reloj del quemado: el ciclo entero de verdad")
	var peak := 0.0
	while lw.running():
		peak = maxf(peak, float(lw.run_view().temp_c))
		lw.tick(FRAME)
	assert_near(peak, float(plan.topC) if float(lw.dial.temp_c) <= 0.0 else float(lw.dial.temp_c), 1.0, 0.0, "el horno sube hasta lo de arriba del ciclo")
	assert_near(float(lw.run_view().temp_c), float(plan.moldC), 1e-9, 0.0, "y deja el molde a la temperatura de colar (%s °C)" % plan.moldC)
	assert_near(float(lw.clock_view().done_s), float(plan.realS), 1e-6, 0.0, "el reloj llega al final del ciclo")
	# el enfriado: lo que tarda de verdad en poder cogerse, el del motor
	var cool := _state("zafiro")
	cool.apply_recommended()
	cool.load_crucible()
	cool.insert_charge()
	cool.start()
	_run(cool)
	cool.cool_piece()
	var real := float(cool.last.cool.realS)
	assert_true(real > 0.0, "el motor dice lo que tarda en enfriarse (%s s)" % real)
	assert_near(float(cool.act.real_s), real, 1e-9, 0.0, "y el reloj lo enseña")
	_settle(cool)
	assert_near(float(cool.clock_view().done_s), real, 1e-6, 0.0, "hasta el final")


func test_los_minerales_duros_no_se_cuelan() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var rec: Dictionary = ForgeData.RECIPES[rid]
		var c := ClawForge.castable(rec)
		assert_eq(bool(c.ok), String(rec.form) == "colada", "%s: se cuela solo si es de colada (los metales y el vidrio)" % rid)
		if bool(c.ok):
			continue
		assert_true(String(c.text).length() > 30, "%s: dice por qué no: %s" % [rid, c.text])
		assert_true(String(c.source) != "", "%s: con su fuente" % rid)
		var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": rid })
		var w := f.wax({})
		assert_eq([bool(w.ok), String(w.defect)], [false, "no_se_cuela"], "%s: no hay modelo de cera que valga" % rid)
		var st := _state(rid)
		var lw := st.lost_wax_view()
		assert_false(bool(lw.on), "%s: la página no ofrece la cera perdida" % rid)
	for sid: String in State.STONES:
		var c2 := ClawForge.castable({}, sid)
		assert_false(bool(c2.ok), "%s: una piedra comprada no se cuela" % sid)
		assert_true(String(c2.text).length() > 20, "%s: y dice por qué: %s" % [sid, c2.text])
	for id: String in ["zafiro", "rubi", "alumina", "diamante"]:
		assert_true(String(ForgeData.NO_CAST.get(id, "")).contains("talla") or String(ForgeData.NO_CAST.get(id, "")).contains("sinteriz"), "%s: se talla o se sinteriza" % id)


func test_la_colada_tiene_la_forma_de_la_garra_con_su_contraccion() -> void:
	for rid: String in CAST_IDS:
		for aid: String in CareData.ANIMAL_IDS:
			var claw := String(CareData.ANIMALS[aid].claw)
			var f := _cast(rid, aid, claw, true)
			var sn := f.snapshot()
			var piece: Dictionary = sn.piece
			assert_true(bool(sn.fire.ok), "%s en %s: la colada sale bien (%s)" % [rid, aid, sn.fire.text])
			assert_eq([String(piece.form), bool(piece.sprue)], ["colada", true], "%s en %s: colada con su bebedero" % [rid, aid])
			# la forma de la garra de ese animal (la misma funda que sheath_geometry con su forma de CareData.claw_shape)
			var shape := CareData.claw_shape(claw, "", false)
			var L := float(CareData.claw_entry(claw).reach) * float(shape.lengthRatio)
			var want := ClawForge.sheath_geometry(CareData.claw_entry(claw), clampf(float(ForgeData.SHEATH.cover_frac) * L, 0.5, L), float(ForgeData.SHEATH.wall_mm), 0.0, shape)
			assert_eq(var_to_str(sn.sheath), var_to_str(want), "%s en %s: la funda de la garra de su animal" % [rid, aid])
			var care := ClawCare.new({ "animal": aid, "claw": claw, "overgrowth_days": 0.0 })
			var prof: Dictionary = sn.cut.profile
			var ss: PackedFloat64Array = prof.s
			var tg: PackedFloat64Array = prof.target
			for i in range(0, 24, 6):
				assert_near(tg[i], float(care.radius_at(ss[i])) + float(ForgeData.SHEATH.wall_mm), 1e-9, 0.0, "%s en %s: la silueta, la de la garra más la pared" % [rid, aid])
			# compensada, la pieza sale a la medida; sin compensar, encoge lo que no compensa el revestimiento
			assert_near(float(piece.cast.scale), 1.0, 1e-12, 0.0, "%s en %s: con la cera a la medida, al 100 %%" % [rid, aid])
			var g := _cast(rid, aid, claw, false)
			var cast: Dictionary = g.snapshot().piece.cast
			assert_near(float(cast.scale), (1.0 + float(cast.expansion)) * (1.0 - float(cast.shrink)), 1e-12, 0.0, "%s en %s: sin compensar, la contracción y la dilatación del molde" % [rid, aid])
			assert_true(float(cast.shrink) > 0.0, "%s: encoge al colarse" % rid)
	# lo que encoge cada material, con su fuente; el oro, medido
	assert_near(float(ForgeData.CAST.oro.shrink.value), 0.0167, 1e-12, 0.0, "el oro encoge un 1,67 %")
	for id: String in ForgeData.CAST:
		assert_true(String(ForgeData.CAST[id].shrink.quality) in ["primary", "secondary", "estimate"] and String(ForgeData.CAST[id].shrink.source) != "", "%s: su contracción con calidad y fuente" % id)
	# sin la cera perdida, el metal va a una lingotera y la funda se talla del lingote
	var ingot := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "oro" })
	var rec := ingot.recommended()
	ingot.mix(rec.mix)
	ingot.fire(rec.fire)
	assert_eq(String(ingot.snapshot().piece.form), "lingote", "sin la cera perdida, un lingote")
	# la cera sin quemar: la colada sale con poros y no llena
	var raw := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "oro" })
	var rr := raw.recommended()
	raw.wax(rr.wax)
	raw.invest(rr.invest)
	raw.mix(rr.mix)
	var out := raw.fire(rr.fire)
	assert_eq([bool(out.ok), String(out.defect)], [false, "cera_sin_quemar"], "sin quemar la cera, no llena")
	assert_true(float(raw.snapshot().piece.cast.filled) < 1.0, "y el molde se ve a medio llenar")


func test_una_herramienta_mas_blanda_no_talla() -> void:
	var softer := { "zafiro": ["lima_acero"], "diamante_hpht": ["lima_acero", "corindon", "sic"] }
	for pid: String in softer:
		var st := _state(pid)
		st.apply_recommended()
		st.load_crucible()
		st.insert_charge()
		st.start()
		_run(st)
		st.cool_piece()
		_settle(st)
		st.set_carve_tool("sierra")
		var before := _cut_key(st.forge.carve_state())
		for abr: String in softer[pid]:
			st.set_carve("abrasive", abr)
			st.carve_pass()
			var r: Dictionary = st.last.carve_pass
			assert_eq([bool(r.ok), String(r.defect)], [false, "no_muerde"], "%s con %s: no muerde" % [pid, abr])
			assert_eq(_cut_key(st.forge.carve_state()), before, "%s con %s: no quita nada ni suma tiempo" % [pid, abr])
		var m := st.mistake_view()
		assert_true(String(m.get("what", "")).contains("más dura"), "%s: se explica: %s" % [pid, m])
		st.set_carve("abrasive", "diamante")
		st.carve_pass()
		assert_true(bool(st.last.carve_pass.ok), "%s: el diamante, sí" % pid)


## Lo que cambia una pasada que talla: los cortes, lo que sobra, el hueco, las pasadas y el tiempo.
static func _cut_key(cs: Dictionary) -> Array:
	return [int(cs.cuts), float(cs.excessMm), float(cs.hollowFrac), int(cs.passes), float(cs.timeS)]


func test_las_pasadas_llegan_a_la_silueta() -> void:
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "zafiro" })
	var rec := f.recommended()
	f.mix(rec.mix)
	f.fire(rec.fire)
	f.cool(String(rec.cool))
	# antes del tocho, las muelas no
	var early := f.carve_pass({ "tool": "muela_fina" })
	assert_eq(String(early.defect), "sin_tocho", "primero el tocho con la sierra")
	var total := 0.0
	for tool: String in ["sierra", "muela_gruesa", "fresa", "muela_fina"]:
		var n := 0
		while n < 300:
			var cs := f.carve_state()
			var left := { "sierra": int(cs.cuts) < int(cs.cutsNeed), "muela_gruesa": float(cs.excessMm) > float(ForgeData.CARVE_TOOLS.muela_gruesa.layer_mm), "fresa": float(cs.hollowFrac) < 1.0, "muela_fina": float(cs.excessMm) > float(ForgeData.SHAPE_TOL.value) }
			if not bool(left[tool]):
				break
			var e0 := float(cs.excessMm)
			var r := f.carve_pass({ "tool": tool })
			assert_true(bool(r.ok), "%s: la pasada sale (%s)" % [tool, r.text])
			assert_near(float(r.timeS), float(r.removedMm3) / float(r.rateMm3s), 1e-9, 1e-12, "%s: el tiempo, lo quitado entre la tasa de Archard del motor" % tool)
			if tool in ["muela_gruesa", "muela_fina"]:
				assert_true(float(r.excessMm) < e0, "%s: cada pasada acerca la pieza a la silueta" % tool)
			total += float(r.timeS)
			n += 1
		assert_true(n > 0, "%s: hace falta al menos una pasada" % tool)
	var end := f.carve_state()
	assert_eq(String(end.verdict), "correcta", "con la muela fina, la forma de la garra: %s" % end.text)
	assert_true(bool(f.snapshot().piece.carved), "y la funda queda tallada")
	assert_near(float(end.timeS), total, 1e-6, 1e-9, "el tiempo de todas las pasadas")
	# la gruesa no sigue la línea: con poco de sobra, se pasa de la silueta
	var g := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "zafiro" })
	g.mix(rec.mix)
	g.fire(rec.fire)
	g.cool(String(rec.cool))
	g.carve_to({ "tool": "sierra" })
	g.carve_to({ "tool": "muela_gruesa" })
	var e1 := float(g.carve_state().excessMm)
	assert_true(e1 > 0.0 and e1 <= float(ForgeData.CARVE_TOOLS.muela_gruesa.layer_mm), "la gruesa para cuando sobra menos de una capa suya (%s mm)" % e1)
	g.carve_pass({ "tool": "muela_gruesa" })
	assert_true(float(g.carve_state().excessMm) < -float(ForgeData.SHAPE_TOL.value), "una pasada más con la gruesa se pasa de la silueta")
	assert_true(String(g.carve_state().verdict) in ["fina", "rota"], "y lo dice: %s" % g.carve_state().text)


func test_en_seco_se_agrieta_y_apretando_se_desconcha() -> void:
	# en seco: el vidrio (conduce mal el calor) se agrieta; con agua, no
	var dry := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	dry.choose("cuarzo")
	var r := dry.carve_pass({ "tool": "sierra", "coolant": false })
	assert_eq([String(r.defect), bool(r.ruins)], ["grieta_calor", true], "el cuarzo tallado en seco se agrieta")
	assert_eq(String(dry.report().verdict), "astillada", "y se estropea")
	var wet := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	wet.choose("cuarzo")
	assert_true(bool(wet.carve_pass({ "tool": "sierra", "coolant": true }).ok), "con agua, no")
	# apretando de más un borde frágil, se desconcha (Chai y Lawn, con el borde que queda)
	var hard := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "wall_mm": 0.5 })
	hard.choose("moissanita")
	hard.carve_to({ "tool": "sierra" })
	hard.carve_to({ "tool": "muela_gruesa" })
	var chip := hard.carve_pass({ "tool": "muela_fina", "force_n": 2000.0 })
	assert_eq(String(chip.defect), "astilla", "con 2000 N en el borde fino, se desconcha")
	assert_true(float(chip.edgeChipN) < 2000.0, "aguanta menos de lo que se aprieta (%s N)" % chip.edgeChipN)
	var soft := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "wall_mm": 0.5 })
	soft.choose("moissanita")
	soft.carve_to({ "tool": "sierra" })
	soft.carve_to({ "tool": "muela_gruesa" })
	assert_true(bool(soft.carve_pass({ "tool": "muela_fina", "force_n": 5.0 }).ok), "con poca fuerza, no")


func test_el_laboratorio_acaba_en_la_funda_sin_pegar() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := _state(rid)
		_follow(st)
		assert_true(st.tutorial_done(), "%s: el tutorial se recorre entero" % rid)
		var steps := ForgeTutorial.steps(rid)
		assert_eq(String(steps[steps.size() - 1].id), "pasar", "%s: acaba en «Pasar a la cetrería»" % rid)
		assert_true(String(steps[steps.size() - 1].text).contains("a mano"), "%s: con lo que se hace a mano allí" % rid)
		var kinds := {}
		for c: Array in st.calls:
			kinds[String(c[0])] = true
		assert_false(kinds.has("bond") or kinds.has("check_load"), "%s: el laboratorio no pega ni prueba con la carga" % rid)
		assert_true(kinds.has("load_machine") and kinds.has("fit"), "%s: mete la carga en su máquina y prueba el ajuste" % rid)
		var rep := st.forge.report()
		assert_eq(String(rep.verdict), "bien", "%s: %s" % [rid, rep.verdictText])
		var rc := st.forge.result_claw()
		assert_true(rc.bond == null, "%s: sin pegar" % rid)
		var cv := st.care_view()
		assert_true(bool(cv.ok), "%s: lista para la cetrería: %s" % [rid, cv.text])
		assert_true(String(cv.text).contains("sin pegar"), "%s: y lo dice" % rid)
		var pc: Dictionary = st.forge.care_setup().piece
		assert_true(bool(pc.fitTested) and bool(pc.polished) and bool(pc.carved), "%s: la pieza para la cetrería, tallada, pulida y probada en la garra" % rid)
		if String(ForgeData.RECIPES[rid].form) == "colada":
			assert_true(kinds.has("wax") and kinds.has("invest") and kinds.has("burnout") and kinds.has("divest"), "%s: por la cera perdida" % rid)
			assert_eq(String(st.forge.snapshot().piece.form), "colada", "%s: colada con la forma de la garra" % rid)
	# el acrílico: el laboratorio no lo mezcla ni lo aplica; el tutorial lleva a la cetrería
	var acr := ForgeTutorial.steps(State.ACRYLIC)
	assert_eq(String(acr[acr.size() - 2].id), "pasar", "el acrílico se aplica y se lima en la cetrería")
	assert_true(String(acr[2].text).contains("no lo mezcla ni lo aplica"), "y lo dice: %s" % acr[2].text)


func test_la_pagina_de_la_cera_perdida_y_del_tallado() -> void:
	var st := _state("oro")
	var lw := st.lost_wax_view()
	assert_true(bool(lw.on) and String(lw.next) == "cera", "el oro va a la cera perdida, empezando por la cera")
	st.lost_wax_next()
	assert_eq(String(st.lost_wax_view().next), "revestir", "C: el modelo de cera; luego, revestir")
	st.lost_wax_next()
	assert_eq(String(st.lost_wax_view().next), "quemar", "C: revestido; luego, quemar la cera en el horno")
	st.lost_wax_next()
	assert_true(st.notice.contains("Calentar"), "lo de quemar se hace en el horno, y lo dice: %s" % st.notice)
	# el tallado: las herramientas en su orden y G las recorre
	assert_eq(State.CARVE_TOOLS, ["sierra", "muela_gruesa", "fresa", "muela_fina", "pulidora"], "las herramientas del lapidario, en orden")
	var t0 := st.carve_tool
	st.cycle_carve_tool(1)
	assert_eq(st.carve_tool, String(State.CARVE_TOOLS[(State.CARVE_TOOLS.find(t0) + 1) % State.CARVE_TOOLS.size()]), "G: la herramienta siguiente")
	var cv := st.carving_view()
	assert_eq((cv.tools as Array).size(), State.CARVE_TOOLS.size(), "cada herramienta con su nombre")
	for t: Dictionary in cv.tools:
		assert_true(String(t.label) != "" and String(t.title).contains("·"), "%s: con su máquina" % t.id)


func test_determinista() -> void:
	var a := _state("titanio")
	var b := _state("titanio")
	for st: State in [a, b]:
		_follow(st)
	assert_eq(var_to_str(a.view()), var_to_str(b.view()), "los mismos pasos, la misma vista")
	# las llamadas del estado, en otra ClawForge, dan la misma pieza (el estado no hace física)
	var f := ClawForge.new(a.forge.setup())
	for c: Array in a.calls:
		f.callv(String(c[0]), [c[1]])
	assert_eq(var_to_str(f.result_claw()), var_to_str(a.forge.result_claw()), "la misma garra")
	assert_eq(var_to_str(f.carve_state()), var_to_str(a.forge.carve_state()), "y el mismo tallado")
