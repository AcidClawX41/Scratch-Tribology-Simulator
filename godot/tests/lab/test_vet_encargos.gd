## Unidad 5v (petición de Eric del 17-10): los encargos de veterinario con su tutorial de iniciación, los minijuegos de pulir,
## transformar y reforjar, y los animales que llegan con una garra rota de serie o la rompen durante la operación.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const VetProgress = preload("res://core/lab/vet_progress.gd")
const VetMinigames = preload("res://core/lab/vet_minigames.gd")


## La garra rota de serie: recién partida (sangra, con la carne viva al aire) o un muñón (ya no sangra); sin broken_start, la de
## siempre al bit; y la que falta no está (no se puede limar lo que no existe).
func test_la_garra_rota_de_serie() -> void:
	var base := { "animal": "rapaz", "claw": "aguila", "seed": "rota" }
	var sana := ClawCare.new(base)
	var s0 := sana.snapshot()
	var same := ClawCare.new(base.merged({ "broken_start": "" })).snapshot()
	assert_eq(var_to_str(same.profile), var_to_str(s0.profile), "sin broken_start, la garra de siempre")
	assert_false(bool(s0.damage.broken), "sana")
	var fresca := ClawCare.new(base.merged({ "broken_start": "fresca" }))
	var sf := fresca.snapshot()
	assert_true(bool(sf.damage.broken), "fresca: rota")
	assert_true(bool(sf.bleeding.active), "fresca: sangra")
	assert_eq(String(sf.damage.brokenStart), "fresca", "la instantánea dice cómo llegó")
	assert_true(fresca.apex_mm() < float(sf.claw.quickMm), "fresca: partida por dentro de la carne viva")
	var munon := ClawCare.new(base.merged({ "broken_start": "muñon" }))
	var sm := munon.snapshot()
	assert_true(bool(sm.damage.broken), "muñón: rota")
	assert_false(bool(sm.bleeding.active), "muñón: ya no sangra")
	assert_true(munon.apex_mm() < sana.apex_mm() - 1.0, "muñón: le falta la punta")
	# lo que falta no está: más allá del muñón no hay garra que limar
	assert_eq(munon.radius_at(munon.apex_mm() + 1.0), 0.0, "más allá del muñón, nada")
	# y una garra reforjada no llega rota de serie (es una pieza entera de su material)
	var ref := ClawCare.new(base.merged({ "broken_start": "fresca", "inlay": "acero" })).snapshot()
	assert_false(bool(ref.damage.broken), "la reforjada, entera")


## En el ensayo: empieza en la garra rota, el tutorial pasa por «Si sangra» y «Garra rota», y sangrar al empezar no es un
## suceso del ensayo (no salta otra vez a «Si sangra»).
func test_el_ensayo_empieza_en_la_garra_rota() -> void:
	var st := State.new({ "animal": "tigre", "claw": "tigre", "seed": "rota",
		"broken_start": { "paw": "trasera_izquierda", "digit": "IV", "kind": "fresca" } })
	assert_eq(st.paw, "trasera_izquierda", "en la pata de la garra rota")
	assert_eq(st.digit, "IV", "y en su dedo")
	assert_true(bool(st.care.snapshot().damage.broken), "la elegida, rota")
	var fl := st.flow()
	assert_true(fl.has("sangrado") and fl.has("reconstruir"), "el tutorial pasa por «Si sangra» y «Garra rota» (%s)" % [fl])
	assert_true(fl.find("sangrado") < fl.find("reconstruir"), "primero la sangre")
	assert_false(st.care_setup("delantera_derecha", "III").has("broken_start"), "las demás garras, sanas")
	st.tick(1.0 / 30.0)
	assert_eq(st.flow().count("sangrado"), 1, "no se mete otra vez «Si sangra»")
	# otro ensayo sin la garra rota
	st.configure({ "broken_start": {} })
	assert_false(bool(st.care.snapshot().damage.broken), "otro ensayo, sana")


## Un resumen de la cetrería a mano (care_summary con los campos de la 5v), con lo que se quiera cambiar.
static func _sum(animal: String, claw: String, over: Dictionary = {}) -> Dictionary:
	var s := {
		"kind": "cetreria", "session": "s-%s-%s" % [animal, claw], "finished": true, "halted": false, "animal": animal, "claw": claw,
		"digit": "III", "sedation": "sujecion" if animal == "rapaz" else "anestesia", "unsafe": false, "verdict": "perfecta",
		"grade": 9.0, "grade_text": "9.0 / 10", "criteria": [], "bled": false, "bleeding": false, "peak_quick_c": 38.0,
		"pain_c": 43.0, "injured": false, "moved": 0, "reforged": false, "bond": {}, "tut_done": [], "tip_ratio": 1.0,
		"tip_strength": 1.0, "ra_tip_um": 0.31, "burned_tip": false, "broken": false, "broken_start": "", "repaired": false,
		"overgrowth_left_mm": 0.0, "over_mm": 3.6,
	}
	s.merge(over, true)
	return s


## Un encargo de iniciación abre su tutorial y se cumple al acabarlo bien (con una consulta de verdad); va detrás del de antes.
func test_la_iniciacion_sigue_su_tutorial() -> void:
	var p := VetProgress.new()
	assert_eq(p.job_state("inic_carne"), "bloqueado", "la segunda, después de la primera")
	assert_false(bool(p.accept("inic_carne").ok), "no se acepta antes")
	assert_true(bool(p.accept("inic_preparar").ok), "la primera, sí")
	var j := VetProgress.job("inic_preparar")
	assert_eq(String(j.tutorial), "preparar", "abre el tutorial «Preparar al animal»")
	# la consulta de verdad: el tutorial de preparar, siguiendo sus pasos (los informativos, con «Siguiente»)
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "iniciacion" })
	st.set_tutorial(true)
	st.tutorial_goto("preparar")
	st.set_sedation("sujecion")
	for i in 12:
		if st.process_id() != "preparar":
			break
		st.tutorial_next()
	# sin acabar la consulta, no
	var r0 := p.evaluate("inic_preparar", VetProgress.care_summary(st.view()))
	assert_false(bool(r0.ok), "sin terminar la consulta, no")
	st.finish()
	var s := VetProgress.care_summary(st.view())
	assert_true((s.tut_done as Array).has("preparar"), "el tutorial de preparar, hecho (%s)" % [s.tut_done])
	var r := p.on_care_finished(s)
	assert_true(bool(r.ok), "cumplido: %s" % r.text)
	assert_eq(p.job_state("inic_carne"), "disponible", "y abre la siguiente")
	# sin seguir el tutorial, la siguiente no se cumple
	p.accept("inic_carne")
	var r2 := p.evaluate("inic_carne", _sum("rapaz", "aguila", { "session": "otra" }))
	assert_false(bool(r2.ok), "sin el tutorial, no")
	assert_true(String(r2.text).contains("tutorial"), "y dice por qué: %s" % r2.text)


## Los minijuegos no se cumplen fuera de la tolerancia: pulir (el Ra de la punta) y transformar (la banda de la punta).
func test_los_minijuegos_y_su_tolerancia() -> void:
	var p := VetProgress.new()
	var pul := VetProgress.job("pulir_halcon")
	var bad := p.evaluate("pulir_halcon", _sum("rapaz", "halcon", { "ra_tip_um": 4.2 }))
	assert_false(bool(bad.ok), "Ra de 4,2 µm, sin pulir")
	assert_true(bool(p.evaluate("pulir_halcon", _sum("rapaz", "halcon", { "ra_tip_um": float(pul.ra_max_um) * 0.9 })).ok), "pulida")
	assert_false(bool(p.evaluate("pulir_halcon", _sum("rapaz", "halcon", { "ra_tip_um": 0.5, "burned_tip": true })).ok), "quemada, no")
	# transformar: roma para el búho; la punta natural (×1) no vale, ×4 sí
	p.best_level = 2
	assert_false(bool(p.evaluate("roma_buho", _sum("rapaz", "buho", { "tip_ratio": 1.0 })).ok), "×1 no es roma")
	assert_true(bool(p.evaluate("roma_buho", _sum("rapaz", "buho", { "tip_ratio": 4.0 })).ok), "×4, roma")
	# afilada: más fina que la natural, sin pasar a aguja
	assert_true(bool(p.evaluate("afilar_aguila", _sum("rapaz", "aguila", { "tip_ratio": 0.75, "tip_strength": 0.5 })).ok), "×0,75, afilada")
	assert_false(bool(p.evaluate("afilar_aguila", _sum("rapaz", "aguila", { "tip_ratio": 0.1, "tip_strength": 0.01 })).ok), "aguja, no")
	# el minijuego en la vista: objetivo, barra y lo que falta
	var st := State.new({ "animal": "rapaz", "claw": "buho", "seed": "mini", "tip_start": "natural" })
	var mv := VetMinigames.view(VetProgress.job("roma_buho"), st.view())
	assert_eq(String(mv.kind), "transformar", "el minijuego de transformar")
	assert_false(bool(mv.ok), "aún no")
	assert_true(float(mv.progress) >= 0.0 and float(mv.progress) < 1.0, "con su barra (%s)" % mv.progress)
	assert_true(String(mv.goal).contains("roma"), "y su objetivo: %s" % mv.goal)
	st.configure({ "tip_start": "roma" })
	assert_true(bool(VetMinigames.view(VetProgress.job("roma_buho"), st.view()).ok), "con la punta roma, hecho")
	# pulir se puede de verdad con el motor: la lima gruesa raya (no basta) y la lija fina en la punta la deja lisa
	var h := ClawCare.new({ "animal": "rapaz", "claw": "halcon", "seed": "mini", "sedation": "sujecion" })
	var al := h.tip_alpha_deg()
	var ov := h.overgrowth_left_mm()
	var guard := 0
	while h.overgrowth_left_mm() > 0.5 * ov and guard < 300:
		h.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": al + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		guard += 1
	var rough := float(VetMinigames.tip_surface(h.surface()).ra_um)
	assert_true(rough > float(pul.ra_max_um), "la lima gruesa la deja rayada (Ra %s)" % rough)
	while h.overgrowth_left_mm() > 0.05 * ov and guard < 600:
		h.file({ "tool": "lija_p240", "zone": "punta", "angle_deg": al + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		guard += 1
	var smooth := float(VetMinigames.tip_surface(h.surface()).ra_um)
	assert_true(smooth <= float(pul.ra_max_um), "la lija fina la deja lisa (Ra %s)" % smooth)
	# devolverle la punta a la roma se puede de verdad con el motor: la lima fina en ángulo (se pasa a aguja) y un toque de frente
	var c := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "mini", "tip_start": "roma", "sedation": "sujecion" })
	for k in 60:
		c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 22.0, "force_n": 3.0, "travel_mm": 10.0 })
	assert_false(VetMinigames.in_band(float(c.tip_state().ratio), c.tip_state().strengthRatio, "natural"), "en ángulo, aguja")
	c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
	assert_true(VetMinigames.in_band(float(c.tip_state().ratio), c.tip_state().strengthRatio, "natural"),
		"y un toque de frente la deja en la natural (×%s)" % c.tip_state().ratio)


## La garra que se rompe durante el encargo lo cambia a «repararla» y paga menos; reparada, se cobra (una vez).
func test_romperla_lo_cambia_a_repararla() -> void:
	var p := VetProgress.new()
	p.accept("coping_aguila")
	var good := p.evaluate("coping_aguila", _sum("rapaz", "aguila"))
	var rota := p.evaluate("coping_aguila", _sum("rapaz", "aguila", { "broken": true, "verdict": "rota" }))
	assert_false(bool(rota.ok), "rota y sin reparar, no se cumple")
	assert_true(bool(rota.get("repair", false)), "el encargo pasa a «repararla»")
	assert_true(String(rota.text).contains("reconstruir") or String(rota.text).contains("garra rota"), "y dice qué falta: %s" % rota.text)
	var rep := p.evaluate("coping_aguila", _sum("rapaz", "aguila", { "broken": true, "repaired": true, "verdict": "reconstruida", "bled": true,
		"criteria": [] }))
	assert_true(bool(rep.ok), "reparada, cumplido: %s" % rep.text)
	assert_true(int(rep.xp) < int(good.xp), "paga menos que sin romperla (%s < %s)" % [rep.xp, good.xp])
	assert_true(String(rep.text).contains("repararla"), "y lo explica")
	# el de la garra rota de serie no cambia a «repararla»: es su encargo
	p.best_level = 2
	p.accept("rota_aguila")
	var rs := p.evaluate("rota_aguila", _sum("rapaz", "aguila", { "broken": true, "broken_start": "fresca", "repaired": true, "bled": true }))
	assert_true(bool(rs.ok), "el de la garra partida, reparada: %s" % rs.text)
	assert_false(bool(rs.get("repair", false)), "sin pasar a repararla")
	var r1 := p.on_care_finished(_sum("rapaz", "aguila", { "session": "rota-1", "broken": true, "broken_start": "fresca", "repaired": true, "bled": true }))
	assert_true(bool(r1.ok), "cobrado")
	var xp1 := p.xp
	assert_false(bool(p.accept("rota_aguila").ok), "un encargo hecho no se acepta otra vez")
	p.on_care_finished(_sum("rapaz", "aguila", { "session": "rota-2", "broken": true, "broken_start": "fresca", "repaired": true, "bled": true }))
	assert_eq(p.xp - xp1, int(VetProgress.PRACTICE.xp), "ni se cobra dos veces (solo la práctica libre)")


## Reconstruida con metacrilato, la forma en directo lo dice (no «Rota») y el medidor no manda afilar el muñón.
func test_reconstruida_lo_dice() -> void:
	const Help = preload("res://core/lab/claw_care_sharpen_help.gd")
	var c := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "rec", "broken_start": "fresca", "sedation": "sujecion" })
	assert_eq(String(c.shape().verdict), "rota", "partida: rota")
	assert_false(bool(Help.advice(c, { "tool": "guillotina" }).show), "rota: no manda afilar")
	assert_true(String(Help.passes(c, { "tool": "lima_fina" }).text).contains("repararla"), "el medidor dice que primero repararla")
	c.hemostasis({ "tool": "hemostatico", "pressure_s": 400.0 })
	c.apply({ "tool": "clorhexidina" })
	c.apply({ "tool": "metacrilato" })
	var sh := c.shape()
	assert_eq(String(sh.verdict), "reconstruida", "reconstruida: %s" % sh.title)
	assert_true(String(sh.text).contains("metacrilato"), "y lo explica")
	assert_true(String(Help.passes(c, { "tool": "lima_fina" }).text).contains("muñón"), "el medidor lee el muñón y lo dice")


## El minijuego de reforjar: la pieza de la reforja del material pedido, colocada, curada y probada (la de la 5o).
func test_el_minijuego_de_reforjar() -> void:
	var p := VetProgress.new()
	p.best_level = 3
	var j := VetProgress.job("funda_titanio_aguila")
	assert_eq(String(j.minigame), "reforjar", "el minijuego de reforjar")
	var no := p.evaluate("funda_titanio_aguila", _sum("rapaz", "aguila", { "broken": true, "broken_start": "muñon",
		"bond": { "material": "oro", "attached": true, "done": true, "tested": true } }))
	assert_false(bool(no.ok), "de oro, no: %s" % no.text)
	var ok := p.evaluate("funda_titanio_aguila", _sum("rapaz", "aguila", { "broken": true, "broken_start": "muñon",
		"bond": { "material": "titanio", "attached": true, "done": true, "tested": true } }))
	assert_true(bool(ok.ok), "de titanio, colocada y probada: %s" % ok.text)
	# la barra en la vista: sin pieza, el primer paso; con la pieza colocada y curada, casi
	var v0 := { "snap": { "damage": {}, "claw": {}, "tip": {}, "surface": {}, "bleeding": {} }, "bond": {} }
	var m0 := VetMinigames.view(j, v0)
	assert_eq(float(m0.progress), 0.0, "sin pieza, nada")
	assert_true(String(m0.text).contains("reforja"), "lo siguiente: la pieza de la reforja (%s)" % m0.text)
	var v1 := v0.duplicate(true)
	v1["bond"] = { "material": "titanio", "attached": true, "done": true, "test": {} }
	var m1 := VetMinigames.view(j, v1)
	assert_true(float(m1.progress) > 0.7 and not bool(m1.ok), "colocada y curada, falta probarla (%s)" % m1.text)


## La ficha del encargo dice con qué llega el animal, el tutorial, el minijuego y por qué.
func test_la_ficha_del_encargo() -> void:
	var p := VetProgress.new()
	var by := {}
	for e: Dictionary in p.jobs_view():
		by[String(e.id)] = e
	assert_eq(String(by.inic_preparar.tutorial_name), "Preparar al animal", "la iniciación, con su tutorial")
	assert_true(String(by.rota_aguila.arrives).contains("partida"), "la garra rota, en la ficha: %s" % by.rota_aguila.arrives)
	assert_true(String(by.afilar_aguila.arrives).contains("roma"), "la punta con la que llega: %s" % by.afilar_aguila.arrives)
	assert_eq(String(by.pulir_halcon.minigame_name), "Pulir", "el minijuego")
	assert_eq(String(by.roma_buho.why), "juego", "un objetivo de juego lo dice")
	assert_true(String(by.rota_aguila.why).contains("Samour"), "y uno veterinario, su fuente: %s" % by.rota_aguila.why)
