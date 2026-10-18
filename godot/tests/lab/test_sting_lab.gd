## Integración de los aguijones en el banco (core/lab/sting_lab.gd y los cambios localizados de physics.gd, lab.gd y
## lab_state.gd): el ensayo del modelo 2.0 tiene las claves que pintan las tarjetas, la herramienta sigue el §7.1 de
## docs/fisica/aguijones.md, los textos van en mN, el guion de la animación es coherente con RUN_MS, el banco solo pica
## con un aguijón y el modo dual y la comparativa en hilos dan lo mismo que en serie.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")


static func S(id: String) -> Dictionary:
	return Insects.find_by_id(id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


static func params(claw: Variant, target: Dictionary, force: float, over: Dictionary = {}) -> Dictionary:
	var p := {
		"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": claw, "target": target,
		"force": force, "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": "puncion", "strike": false,
		"passes": 1.0, "wet": false,
	}
	p.merge(over, true)
	return p


## ¿Hay en el texto un número con más de 4 decimales? (el 1.x escribía «0.7283136065038798 N»)
static func long_number(text: String) -> bool:
	return RegEx.create_from_string("\\d\\.\\d{5,}").search(text) != null


# ── El ensayo ──

func test_las_claves_de_siempre_mas_sting() -> void:
	# las mismas claves que un ensayo 1.x de su clase (punción de la piel o sólido) con una garra, más `sting`
	var gato: Dictionary = Catalog.find_by_id(Catalog.CLAWS, "gato")
	for t: Dictionary in Catalog.TARGETS:
		var ref := Physics.compute(params(gato, t, 4.0, { "model": "1.x" }))
		for s: Dictionary in Insects.STINGERS:
			for inlay: Dictionary in [Catalog.INLAYS[0], I("acero")]:
				var r := Physics.compute(params(s, t, s.force, { "inlay": inlay }))
				for k: String in ref:
					assert_true(r.has(k), "%s de %s contra %s: falta la clave «%s»" % [s.id, inlay.id, t.id, k])
				assert_true(r.get("sting") is Dictionary, "%s contra %s: bloque sting" % [s.id, t.id])
				assert_true(r.has("toolBroken"), "%s contra %s: toolBroken" % [s.id, t.id])
				assert_eq(r.sting.isStinger, true)
				assert_false(long_number(String(r.vsub)), "%s contra %s: «%s» sin números de 16 cifras" % [s.id, t.id, r.vsub])


func test_el_modelo_1x_no_despacha_a_los_aguijones() -> void:
	var r := Physics.compute(params(S("abeja"), T("piel"), 0.00575, { "model": "1.x" }))
	assert_false(r.has("sting"), "con el modelo 1.x, el motor de siempre (Davis): sin bloque sting")
	assert_false(bool(r.pierces), "Davis pide 80 mN a una punta de 1 µm: con el 1.x no perfora (por eso la 2.0)")
	var v2 := Physics.compute(params(S("abeja"), T("piel"), 0.00575))
	assert_true(bool(v2.pierces), "con la 2.0, sí")


func test_en_la_piel_un_aguijon_siempre_pica() -> void:
	# sin rayado, desgarro ni golpe (§7.2): el mismo resultado con cualquier método
	var bee := S("abeja")
	var base := Physics.compute(params(bee, T("piel"), bee.force))
	for over: Dictionary in [{ "method": "rayado" }, { "method": "rayado", "tear": true }, { "strike": true }, { "wet": true }]:
		var r := Physics.compute(params(bee, T("piel"), bee.force, over))
		assert_eq(oracle_diff(r, base).size(), 0, "abeja en la piel con %s: la misma picadura" % [over])
	assert_true(bool(base.puncture) and bool(base.inject), "punción que inyecta")
	assert_eq(base.cede, "la piel y el aparato del aguijón (autotomía)")
	assert_eq(base.grooveWidthUm, 86.0, "anchura de la herida: el diámetro del aguijón")
	assert_false(String(base.cede).contains("2 punciones"), "un aguijón no muerde como un colmillo")


func test_mas_fuerza_nunca_da_menos_profundidad() -> void:
	for s: Dictionary in Insects.STINGERS:
		for tid: String in ["piel", "madera", "plastico", "vidrio", "cuticula"]:
			for inlay: Dictionary in [Catalog.INLAYS[0], I("acero"), I("diamante")]:
				var prev := -1.0
				var f := 1e-5
				while f <= 5.0:
					var r := Physics.compute(params(s, T(tid), f, { "inlay": inlay }))
					assert_true(r.depthUm >= prev - 1e-9, "%s de %s contra %s: %s N no da menos profundidad" % [s.id, inlay.id, tid, f])
					prev = r.depthUm
					f *= 1.6


func test_veredictos_de_los_aguijones() -> void:
	var bee := S("abeja")
	var r := Physics.compute(params(bee, T("piel"), 0.001))
	assert_eq([r.verdict, r.vsub], ["NO PERFORA", "la piel se hunde pero no se rompe (hace falta ~4.3 mN)"])
	r = Physics.compute(params(S("avispa"), T("piel"), 0.0099))
	assert_eq(r.verdict, "PICA Y SE VA")
	assert_true(String(r.vsub).ends_with("(a veces lo deja si se la aparta a la fuerza)"), r.vsub)
	r = Physics.compute(params(bee, T("madera"), bee.force))
	assert_eq([r.verdict, r.vsub], ["LA PUNTA SE APLASTA", "la punta (7.1 HV) cede frente a las paredes celulares del pino (45.9 HV)"])
	r = Physics.compute(params(bee, T("madera"), 1.0, { "inlay": I("acero") }))
	assert_eq([r.verdict, r.vsub], ["SE DOBLA EL AGUIJÓN", "el aguijón de acero pandea a ~728 mN tras entrar 73 µm"], "§7.4")
	r = Physics.compute(params(bee, T("madera"), 0.02))
	assert_eq(r.verdict, "SE DOBLA EL AGUIJÓN", "una abeja natural empujada de más contra el pino")
	assert_true(String(r.vsub).contains("sin llegar a entrar") and String(r.vsub).contains("45.9 HV"), r.vsub)
	r = Physics.compute(params(bee, T("vidrio"), 5.0, { "inlay": I("diamante") }))
	assert_true(String(r.vsub).contains("~3.82 N"), "por encima de 1 N, en N: %s" % r.vsub)
	# piel tres veces más tenaz: la abeja de quitina pandea antes de perforar (§2.3)
	var tough := T("piel").duplicate(true)
	var stack: Array = Catalog.SKIN_LAYERS.duplicate(true)
	stack[0].jC = 5.1
	tough.tissue = stack
	r = Physics.compute(params(bee, tough, 0.02))
	assert_eq(r.verdict, "SE DOBLA EL AGUIJÓN")
	assert_true(bool(r.toolBroken) and not bool(r.pierces), "pandea sin perforar")
	assert_eq(r.vsub, "el aguijón de quitina pandea a ~8.6 mN antes de romper la piel (hace falta ~13 mN)")
	# la cutícula de otro insecto: la punta natural cede; la de acero entra, pero no se queda
	r = Physics.compute(params(bee, T("cuticula"), 0.5, { "inlay": I("acero") }))
	assert_false(bool(r.sting.engaged) or bool(r.sting.stuck), "no se engancha en la cutícula")
	assert_true(String(r.vsub).contains("no se queda clavado: la cutícula no se cierra tras las púas"), r.vsub)


func test_la_herramienta_de_un_aguijon() -> void:
	var bee := S("abeja")
	for wet: bool in [false, true]:
		var t := Physics.resolve_tool({ "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": bee, "wet": wet })
		assert_false(t.keratin, "la cutícula no es queratina")
		assert_false(t.wet, "el modo «húmeda» no la ablanda")
		assert_eq(t.hv, bee.hv, "dureza de la punta, sin ablandar")
		assert_eq(t.E, bee.E)
		assert_eq(t.baseR, 0.043, "radio de la base = diámetro/2 (86 µm)")
		assert_near(t.fBreak, Sting.buckling(bee).F, 1e-12, 0.0, "fBreak = carga de pandeo")
	var steel := Physics.resolve_tool({ "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": I("acero"), "claw": bee, "wet": true })
	assert_eq([steel.hv, steel.E, steel.hasGem], [200.0, 200.0, true], "reforjada en acero")
	assert_near(steel.fBreak, Sting.buckling(bee, I("acero")).F, 1e-12, 0.0, "fBreak = pandeo del acero (una garra 1.x reforjada no tiene)")
	# el modelo 1.x trata al aguijón como una garra más (no es parte de la 1.x): sin tocar su camino
	var one := Physics.resolve_tool({ "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": bee, "wet": false, "model": "1.x" })
	assert_true(one.keratin, "1.x: la regla de las garras")
	assert_near(one.baseR, 0.15 * bee.reach, 1e-12, 0.0)


# ── Textos ──

func test_textos_de_la_herramienta_en_mn_y_mg() -> void:
	var bee := S("abeja")
	var hint := Lab.max_force_hint(bee)
	assert_eq(hint.label, "de la abeja melífera")
	assert_eq(hint.force, bee.force)
	assert_true(String(hint.note).contains("~70 mg"), "masa en mg: %s" % hint.note)
	assert_true(String(hint.note).contains("medido: 1,34-5,75 mN"), hint.note)
	assert_eq(Lab.max_force_hint(S("avispon")).label, "del avispón europeo")
	assert_true(String(Lab.max_force_hint(S("avispon")).note).contains("estimado"), "fuerza estimada")
	var tool := Physics.resolve_tool({ "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": bee })
	assert_eq(Lab.claw_spec(bee, Catalog.INLAYS[0], tool).material, "quitina")
	var rows := StingLab.spec_rows(bee, Catalog.INLAYS[0], tool)
	var by := {}
	for r: Array in rows:
		by[r[0]] = r[1]
	assert_eq(by["peso"], "~70 mg")
	assert_eq(by["púas"], "10 por lanceta · no se enfundan")
	assert_eq(by["Schmidt"], "2")
	assert_eq(by["aleteo"], "231.5 Hz")
	assert_eq(by["pandea a"], "~8.6 mN")
	assert_eq(by["empuje"], "~5.8 mN")
	assert_eq(by["datos"], StingLab.QUALITY_TEXT["primary"])
	assert_eq(by["quitina"], "7.1 HV en la punta (base 43 HV)")
	var ant := {}
	for r: Array in StingLab.spec_rows(S("hormigabala"), Catalog.INLAYS[0], tool):
		ant[r[0]] = r[1]
	assert_eq([ant["aleteo"], ant["Schmidt"], ant["púas"]], ["sin alas", "4", "sin datos"])
	var pepsis := {}
	for r: Array in StingLab.spec_rows(S("pepsis"), Catalog.INLAYS[0], tool):
		pepsis[r[0]] = r[1]
	assert_eq([pepsis["aleteo"], pepsis["púas"]], ["sin medida", "sin púas (lancetas lisas)"])
	assert_eq(StingLab.short_sources(String(bee.source)), "Ramirez-Esquivel 2023 · Zhao 2015 · Ling 2017 · Das 2018")
	assert_eq(StingLab.fmt_force(0.00864), "8.6 mN")
	assert_eq(StingLab.fmt_force(3.8236), "3.82 N")


func test_etiqueta_del_cuaderno_y_modo_dual() -> void:
	var bee := S("abeja")
	var cars: Array = [T("cocheclasico"), T("coche")]
	var p := params(bee, cars[0], 1.0, { "inlay": I("acero") })
	var r := Physics.compute(p)
	assert_eq(Lab.tool_label({ "claw": bee, "geom": p.geom, "inlay": p.inlay, "res": r }), "Aguijón de abeja melífera de acero")
	var rows := Lab.duel(p, bee, cars)
	assert_eq(rows.map(func(x: Dictionary) -> String: return x.id), ["puncion"], "un aguijón solo pica: una fila")
	for k in 2:
		var res: Dictionary = rows[0].res[k]
		assert_true(res.sting is Dictionary, "el duelo usa la física de los aguijones")
	# si el aguijón pandea sin dejar marca, el informe lo dice
	var bent := Physics.compute(params(bee, T("coche"), 0.05))
	assert_true(bool(bent.toolBroken) and not bool(bent.scratched), "la abeja de quitina contra la pintura, con 50 mN")
	assert_eq(Lab.damage_report(bent, T("coche")), [["Daño", "ninguno: se dobla el aguijón"]])
	assert_eq(Lab.damage_report({ "scratched": false, "toolBroken": true }, T("coche")), [["Daño", "ninguno: se rompe la punta"]], "una garra, como en la 1.x")


func test_moraleja() -> void:
	var bee := S("abeja")
	assert_true(StingLab.moral(Physics.compute(params(bee, T("piel"), bee.force, { "inlay": I("acero") })), T("piel")).begins_with("La abeja de acero muere igual"))
	assert_true(StingLab.moral(Physics.compute(params(bee, T("piel"), bee.force)), T("piel")).contains("181 veces"))
	assert_true(StingLab.moral(Physics.compute(params(bee, T("madera"), bee.force)), T("madera")).begins_with("El pino es blando por fuera"))
	assert_eq(StingLab.moral(Physics.compute(params(Catalog.find_by_id(Catalog.CLAWS, "gato"), T("piel"), 4.0)), T("piel")), "", "una garra no tiene moraleja")


# ── Guion de la animación y de los sonidos ──

func test_guion_coherente_con_run_ms() -> void:
	assert_eq(StingLab.RUN_MS, LabState.RUN_MS, "la misma duración del ensayo que LabState")
	for s: Dictionary in Insects.STINGERS:
		for tid: String in ["piel", "madera"]:
			for f: float in [0.001, s.force, 0.05]:
				var r := Physics.compute(params(s, T(tid), f))
				var tl := StingLab.timeline(r)
				var where := "%s contra %s con %s N" % [s.id, tid, f]
				assert_near(tl.pierce, 0.78 * LabState.RUN_MS, 1e-12, 0.0, "%s: perfora cuando suena la punción" % where)
				assert_true(tl.contact < tl.pierce and tl.pierce < tl.insertEnd and tl.insertEnd < tl.pullStart, "%s: orden" % where)
				assert_true(tl.pullStart < tl.leave and tl.leave < tl.leaveEnd and tl.leaveEnd <= tl.end, "%s: orden" % where)
				assert_eq(tl.tear >= 0.0, bool(r.sting.autotomy), "%s: se desgarra solo si hay autotomía" % where)
				if tl.tear >= 0.0:
					assert_true(tl.tear > tl.insertEnd and tl.tear <= tl.leave, "%s: se desgarra al irse" % where)
	var bee := S("abeja")
	var tl := StingLab.timeline(Physics.compute(params(bee, T("piel"), bee.force)))
	assert_near(tl.insertEnd - tl.pierce, 1500.0 * StingLab.ANIM.insertScale, 1e-9, 0.0, "la abeja tarda 1,5 s en entrar (Zhao 2015), a escala")
	assert_near(tl.pumpEnd - tl.pierce, 60000.0 / StingLab.ANIM.pumpSpeedup, 1e-9, 0.0, "el saco se vacía en 1 min (Schumacher 1994), ×10")
	var wasp := StingLab.timeline(Physics.compute(params(S("avispa"), T("piel"), 0.0099)))
	assert_eq(wasp.pumpEnd, -1.0, "la avispa se lleva el aguijón: no queda nada bombeando")


func test_veneno_durante_el_guion() -> void:
	var bee := S("abeja")
	var r := Physics.compute(params(bee, T("piel"), bee.force))
	var tl := StingLab.timeline(r)
	assert_eq(StingLab.venom_state(bee, r, tl.pierce - 1.0).fraction, 0.0, "nada antes de perforar")
	var at_t90: float = tl.pierce + 20000.0 / StingLab.ANIM.pumpSpeedup
	assert_near(StingLab.venom_state(bee, r, at_t90).fraction, 0.9, 1e-9, 0.0, "90 % a los 20 s reales (2 s en pantalla)")
	var prev := 0.0
	var ms: float = tl.pierce
	while ms < tl.end + 500.0:
		var v := StingLab.venom_state(bee, r, ms)
		assert_true(v.fraction >= prev and v.ug <= 147.0 + 1e-9, "el saco solo se vacía (%s ms)" % ms)
		prev = v.fraction
		ms += 97.0
	var wasp := S("avispa")
	var rw := Physics.compute(params(wasp, T("piel"), 0.0099))
	var tw := StingLab.timeline(rw)
	assert_near(StingLab.venom_state(wasp, rw, tw.leaveEnd).ug, 3.0, 1e-9, 0.0, "la avispa deja sus ~3 µg durante la picadura")
	var nop := Physics.compute(params(bee, T("piel"), 0.001))
	assert_eq(StingLab.venom_state(bee, nop, 5000.0).fraction, 0.0, "sin perforar no hay veneno")


# ── Estado del banco ──

func test_el_banco_solo_pica_con_un_aguijon() -> void:
	var sounds: Array = []
	var lab := LabState.new(func(id: String, _v: float) -> void: sounds.append(id), SfxInsects.sfx_for_result)
	lab.set_method("rayado")
	lab.set_tear_mode(true)
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
	lab.set_tear_mode(true)
	lab.set_claw(S("abeja"))
	assert_eq([lab.method, lab.strike, lab.tear_mode], ["puncion", false, false], "un aguijón: punción, sin golpe ni desgarro")
	assert_eq(lab.force, S("abeja").force, "y su fuerza, en mN")
	lab.set_method("rayado")
	lab.set_strike(true)
	lab.set_tear_mode(true)
	assert_eq([lab.method, lab.strike, lab.tear_mode], ["puncion", false, false], "no se puede cambiar mientras sea un aguijón")
	lab.set_claw(S("avispa"))
	assert_eq(lab.method, "puncion", "entre aguijones, lo mismo")
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
	assert_eq([lab.method, lab.tear_mode], ["rayado", true], "al volver a una garra, lo que había")
	lab.set_claw(S("abeja"))
	lab.set_target(T("piel"))
	var m := lab.sting_marks()
	assert_near(m.puncture, 0.00425, 1e-9, 0.0, "marca: perfora a 4,25 mN")
	assert_near(m.buckle, Sting.buckling(S("abeja")).F, 1e-12, 0.0, "marca: pandea")
	lab.set_target(T("madera"))
	assert_eq(lab.sting_marks().puncture, null, "en un sólido no hay fuerza de perforación de la piel")
	lab.set_claw(null)
	assert_eq(lab.sting_marks(), {}, "sin aguijón, sin marcas")
	# los sonidos del ensayo: el picotazo al perforar y el desgarro al irse la abeja
	lab.set_claw(S("abeja"))
	lab.set_target(T("piel"))
	sounds.clear()
	lab.run()
	var tl := StingLab.timeline(lab.res)
	lab.advance(0.78 * LabState.RUN_MS - 1.0)
	assert_false(sounds.has(SfxInsects.STING), "aún no ha perforado")
	lab.advance(1.0)
	assert_true(sounds.has(SfxInsects.STING), "el picotazo al perforar")
	assert_false(sounds.has(LabState.SFX_TEAR))
	lab.advance(tl.tear - 0.78 * LabState.RUN_MS)
	assert_true(sounds.has(LabState.SFX_TEAR), "el desgarro cuando la abeja se va")
	assert_eq(lab.phase, "done")
	lab.set_claw(S("avispa"))
	sounds.clear()
	lab.run()
	lab.advance(10000.0)
	assert_false(sounds.has(LabState.SFX_TEAR), "la avispa no se desgarra")


# ── Hilos ──

func test_en_paralelo_igual_que_en_serie() -> void:
	var list: Array = []
	for s: Dictionary in Insects.STINGERS:
		for t: Dictionary in Catalog.TARGETS:
			for inlay: Dictionary in [Catalog.INLAYS[0], I("acero"), I("oro")]:
				list.append(params(s, t, s.force * 3.0, { "inlay": inlay }))
	var serial: Array = list.map(func(p: Dictionary) -> Dictionary: return Physics.compute(p))
	var parallel: Array = []
	parallel.resize(list.size())
	var lock := Mutex.new()
	var job := func(i: int) -> void:
		var r := Physics.compute(list[i])
		lock.lock()
		parallel[i] = r
		lock.unlock()
	var task := WorkerThreadPool.add_group_task(job, list.size(), -1, true, "aguijones en paralelo")
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in list.size():
		assert_true(same(parallel[i], serial[i]), "ensayo %d: igual en paralelo" % i)
	assert_true(list.size() > 400, "ensayos: %d" % list.size())
