## El progreso del veterinario (core/lab/vet_progress.gd, unidad 5u; petición 62): invariantes, no números mágicos.
##   - el nivel nunca baja, y la experiencia tampoco (comprar lentes no los toca; recuperar un archivo no los baja);
##   - un encargo hecho no se cobra dos veces (ni aceptándolo otra vez, ni con la misma consulta comprobada dos veces);
##   - no se compra una lente sin el nivel o sin los créditos; comprar otra quita los rayones; reponer la misma cuesta menos;
##   - guardar y recuperar da lo mismo; un archivo roto no rompe el programa (se empieza de cero, se avisa y se deja aparte);
##     uno con datos raros recupera lo que vale; uno de una versión más nueva no se toca;
##   - los encargos se comprueban con el informe de los motores (una consulta de verdad con ClawCareState y una pieza de
##     verdad con ClawForgeState): bien hecha se cobra; si sangra, no, y dice por qué; sin anestesia en un tigre, ni práctica;
##   - la nota sube la recompensa y los errores la bajan, nunca por debajo de cero; los números del juego van marcados.
extends "res://tests/case.gd"

const VetProgress = preload("res://core/lab/vet_progress.gd")
const CareState = preload("res://core/lab/claw_care_state.gd")
const ForgeState = preload("res://core/lab/claw_forge_state.gd")

const CFG := "user://test_vet_progress.cfg"
const BAD := "docs/|\\.gd\\b|§|res://|ClawCare|CareData|ClawForge|ForgeData|SRC_|\\bunidad [0-9]|\\b[a-z0-9]+_[a-z0-9_]+\\b"


func before_each() -> void:
	for f: String in [CFG, CFG + ".roto"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## Un resumen de la cetrería a mano (los campos de care_summary), con lo que se quiera cambiar.
static func _care(animal: String, claw: String, over: Dictionary = {}) -> Dictionary:
	var s := {
		"kind": "cetreria", "session": "s-%s-%s" % [animal, claw], "finished": true, "halted": false, "animal": animal, "claw": claw,
		"digit": "II", "sedation": "sujecion" if animal == "rapaz" else "anestesia", "unsafe": false, "verdict": "perfecta",
		"grade": 9.0, "grade_text": "9.0 / 10", "criteria": [], "bled": false, "bleeding": false, "peak_quick_c": 38.0,
		"pain_c": 43.0, "injured": false, "moved": 0, "reforged": false, "bond": {},
	}
	s.merge(over, true)
	return s


## Hace un encargo de la cetrería con un resumen que lo cumple.
static func _do(p: VetProgress, id: String) -> Dictionary:
	var j := VetProgress.job(id)
	p.accept(id)
	if String(j.kind) == "reforja":
		var w := { "ok": true, "defect": "", "text": "" }
		return p.on_forge_finished({ "kind": "reforja", "verdict": "bien", "material": (j.get("materials", ["oro"]) as Array)[0], "ok": true, "weld": w })
	var over := { "session": "s-%s" % id, "verdict": "perfecta_daga" if (j.asks as Array).has("daga") else "perfecta" }
	if (j.asks as Array).has("pieza_colocada"):
		over["bond"] = { "material": "zafiro", "kind": "funda", "method": "adhesivo", "attached": true, "done": true, "tested": true }
	return p.on_care_finished(_care(String(j.animal) if String(j.animal) != "" else "rapaz", String(j.claw), over))


func test_el_nivel_nunca_baja() -> void:
	var p := VetProgress.new()
	assert_eq(p.level(), 1, "se empieza en el nivel 1")
	assert_eq(p.lens_on, "plastico", "con la lente de plástico, la de serie")
	var prev_lv := 1
	var prev_xp := 0
	var order := ["coping_aguila", "punta_halcon", "buho_quieto", "funda_oro", "tigre_anestesia", "oso_quieto", "daga_lechuza", "soldar_punta", "velociraptor_hoz", "zafiro_colocada"]
	for id: String in order:
		_do(p, id)
		# comprar lentes no baja ni la experiencia ni el nivel
		for lid: String in VetProgress.LENS_IDS:
			p.buy_lens(lid)
		assert_true(p.level() >= prev_lv, "%s: el nivel no baja (%d → %d)" % [id, prev_lv, p.level()])
		assert_true(p.xp >= prev_xp, "%s: la experiencia no baja" % id)
		prev_lv = p.level()
		prev_xp = p.xp
	assert_eq(p.level(), VetProgress.MAX_LEVEL, "con todos los encargos, el nivel más alto")
	assert_eq(p.jobs_done(), order.size(), "todos hechos")
	# recuperar un archivo con menos experiencia no baja el nivel alcanzado (best_level)
	var d := p.to_dict()
	d["xp"] = 0
	var q := VetProgress.new()
	q.from_dict(d)
	assert_eq(q.level(), VetProgress.MAX_LEVEL, "el nivel alcanzado se conserva aunque la experiencia del archivo sea menor")
	# los errores restan de la recompensa, pero nunca dejan la experiencia por debajo de lo que había
	var r := VetProgress.new()
	r.accept("coping_aguila")
	var before := r.xp
	r.on_care_finished(_care("rapaz", "aguila", { "criteria": ["sujecion", "sin_desinfectar"], "moved": 3, "peak_quick_c": 60.0, "grade": 6.0 }))
	assert_true(r.xp >= before, "una consulta con errores nunca resta experiencia")


func test_un_encargo_hecho_no_se_cobra_dos_veces() -> void:
	var p := VetProgress.new()
	var r := _do(p, "coping_aguila")
	assert_true(bool(r.ok), "el arreglo de las garras del águila, cumplido: %s" % r.text)
	var xp1 := p.xp
	var cr1 := p.credits
	assert_eq(p.job_state("coping_aguila"), "hecho", "hecho")
	var again := p.accept("coping_aguila")
	assert_false(bool(again.ok), "no se acepta otra vez: %s" % again.text)
	assert_true(String(again.text).contains("no se cobra dos veces"), "y lo dice")
	# la misma consulta comprobada dos veces no paga dos veces (ni la práctica)
	var s := _care("rapaz", "aguila", { "session": "otra" })
	p.on_care_finished(s)
	var xp2 := p.xp
	p.on_care_finished(s)
	assert_eq(p.xp, xp2, "la misma consulta, una sola vez")
	assert_eq(xp2 - xp1, int(VetProgress.PRACTICE.xp), "sin encargo en curso, una consulta da la práctica libre")
	assert_true(p.credits >= cr1, "los créditos no bajan")
	# el registro interno: _complete sobre un encargo hecho no paga
	var rr := { "ok": true, "xp": 999, "credits": 999, "grade": 10.0 }
	p.call("_complete", "coping_aguila", rr)
	assert_eq(p.xp, xp2, "un encargo hecho no se vuelve a cobrar")
	assert_false(bool(rr.ok), "y el resultado lo dice")


func test_no_se_compra_sin_nivel_o_sin_creditos() -> void:
	var p := VetProgress.new()
	var c := p.can_buy("vidrio")
	assert_false(bool(c.ok), "nivel 1: el vidrio pide el nivel 2")
	assert_true(String(c.why).contains("nivel 2"), "y lo dice: %s" % c.why)
	var b := p.buy_lens("vidrio")
	assert_false(bool(b.ok) or p.owns("vidrio"), "no se compra")
	assert_eq(p.lens_on, "plastico", "sigue la de plástico")
	# con el nivel pero sin créditos
	p.xp = 1000
	p.best_level = 4
	p.credits = 10
	var c2 := p.can_buy("zafiro")
	assert_false(bool(c2.ok), "sin créditos, no")
	assert_true(String(c2.why).contains("créditos"), "y lo dice: %s" % c2.why)
	# con los dos: se compra, se pone y quita los rayones; reponer la misma cuesta menos
	p.credits = 1000
	p.set_lens_damage("plastico", { "obscuration": 0.4 })
	assert_near(p.obscuration("plastico"), 0.4, 1e-12, 0.0, "la de plástico, rayada")
	var cb := p.buy_lens("zafiro")
	assert_true(bool(cb.ok) and p.lens_on == "zafiro", "comprada y puesta: %s" % cb.text)
	assert_eq(p.credits, 1000 - int(VetProgress.LENS_SHOP.zafiro.price), "cobrada a su precio")
	assert_eq(p.obscuration("zafiro"), 0.0, "nueva, sin rayones")
	p.set_lens_damage("zafiro", { "obscuration": 0.7 })
	var before := p.credits
	var rp := p.buy_lens("zafiro")
	assert_true(bool(rp.ok), "reponer la misma")
	assert_eq(before - p.credits, int(VetProgress.LENS_SHOP.zafiro.replace), "a su precio de reponer")
	assert_true(int(VetProgress.LENS_SHOP.zafiro.replace) < int(VetProgress.LENS_SHOP.zafiro.price), "más barato que una nueva")
	assert_eq(p.obscuration("zafiro"), 0.0, "otra igual, sin rayones")
	# ponerse una que ya se tiene es gratis; una que no se tiene, no
	var w := p.wear_lens("plastico")
	assert_true(bool(w.ok) and p.lens_on == "plastico", "la de plástico otra vez")
	assert_near(p.obscuration("plastico"), 0.4, 1e-12, 0.0, "con sus rayones (se quedan en esa lente)")
	assert_false(bool(p.wear_lens("vidrio").ok), "el vidrio no es suyo")
	for e: Dictionary in p.shop_view():
		assert_true(String(e.action_text).length() > 3 and String(e.level_text).begins_with("nivel"), "%s: su botón y su nivel" % e.id)


## Con unos pocos rayones se sigue trabajando; con la lente que ya no deja ver, la consulta no cuenta hasta cambiarla (o
## empezar de nuevo, que lo deja todo como la primera vez y se guarda así).
func test_la_lente_que_no_deja_ver_y_empezar_de_nuevo() -> void:
	var p := VetProgress.new()
	p.set_lens_damage("plastico", { "obscuration": float(VetProgress.BLIND.warn) })
	assert_false(p.blind(), "rayada pero aún se ve")
	var ok := p.on_care_finished(_care("rapaz", "aguila", { "session": "b1" }))
	assert_true(bool(ok.ok) and p.xp > 0, "con unos pocos rayones, la práctica cuenta")
	var xp0 := p.xp
	var cr0 := p.credits
	p.set_lens_damage("plastico", { "obscuration": float(VetProgress.BLIND.at) })
	assert_true(p.blind(), "ya no deja ver")
	assert_eq(String(p.lens_view().tone), "mal", "y lo pinta en rojo")
	var r := p.on_care_finished(_care("rapaz", "aguila", { "session": "b2" }))
	assert_false(bool(r.ok), "la consulta no cuenta")
	assert_eq([p.xp, p.credits], [xp0, cr0], "ni experiencia ni créditos")
	assert_true(String(r.text).contains("tienda") or String(r.text).contains("de nuevo"), "y dice qué hacer: %s" % r.text)
	# con créditos para reponerla: una salida en la tienda
	p.credits = int(VetProgress.LENS_SHOP.plastico.replace)
	var bv := p.blind_view()
	assert_true(bool(bv.blind) and not bool(bv.restart_only), "con %s créditos, se puede reponer" % p.credits)
	assert_true((bv.fixes as Array).any(func(f: Dictionary) -> bool: return String(f.id) == "plastico" and String(f.action) == "reponer"), "reponer la de plástico")
	# sin créditos ni otra lente: solo empezar de nuevo
	p.credits = 0
	assert_true(bool(p.blind_view().restart_only), "sin créditos ni otra lente, solo queda empezar de nuevo")
	assert_true(String(p.blind_view().text).contains("de nuevo"), "y lo dice")
	# empezar de nuevo: como la primera vez, y guardado así
	p.restart_game()
	var fresh := VetProgress.new()
	assert_false(p.blind(), "lente nueva")
	assert_eq([p.xp, p.credits, p.level(), p.lens_on, p.active_job], [0, 0, 1, "plastico", ""], "nivel 1, sin experiencia ni créditos")
	assert_eq(var_to_str(p.to_dict()), var_to_str(fresh.to_dict()), "lo guardado, como la primera vez")
	assert_true(p.notice != "", "y lo dice: %s" % p.notice)
	# otra lente tuya que aún deja ver también es una salida
	var q := VetProgress.new()
	q.lenses["vidrio"] = { "owned": true, "damage": {} }
	q.set_lens_damage("plastico", { "obscuration": 0.95 })
	assert_true((q.blind_view().fixes as Array).any(func(f: Dictionary) -> bool: return String(f.id) == "vidrio" and String(f.action) == "poner"), "ponerse el vidrio")


func test_guardar_y_recuperar_da_lo_mismo() -> void:
	var p := VetProgress.new()
	_do(p, "coping_aguila")
	_do(p, "punta_halcon")
	p.accept("buho_quieto")
	p.credits = 200
	p.buy_lens("vidrio")
	p.set_lens_damage("vidrio", { "obscuration": 0.25, "scratches": [{ "from": [0.1, 0.2], "to": [0.3, 0.4], "width": 0.01 }] })
	assert_eq(p.save_to(CFG), OK, "guardado")
	var q := VetProgress.new()
	q.load_file(CFG)
	assert_eq(q.notice, "", "sin avisos")
	assert_eq(var_to_str(q.to_dict()), var_to_str(p.to_dict()), "lo mismo")
	assert_eq(q.level(), p.level(), "el mismo nivel")
	assert_eq(q.active_job, "buho_quieto", "el encargo en curso")
	assert_near(q.obscuration("vidrio"), 0.25, 1e-12, 0.0, "y los rayones de la lente")
	# sin ruta no se guarda nada (tests y demo)
	assert_eq(p.save_to(""), ERR_UNAVAILABLE, "sin ruta, nada")


func test_un_archivo_roto_no_rompe_el_programa() -> void:
	# basura: se empieza de cero, se avisa y el archivo roto se deja aparte
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	f.store_string("[progreso\nxp = = 12 {{{")
	f.close()
	var p := VetProgress.new()
	p.load_file(CFG)
	assert_eq(p.level(), 1, "de cero")
	assert_eq(p.xp, 0, "sin experiencia")
	assert_true(p.notice.contains("dañado"), "y se avisa: %s" % p.notice)
	assert_true(FileAccess.file_exists(CFG + ".roto"), "el de antes, aparte")
	assert_false(FileAccess.file_exists(CFG), "y la ruta queda libre para guardar")
	assert_eq(p.save_to(CFG), OK, "se puede guardar de nuevo")
	# datos raros en un archivo que se lee: lo que vale se recupera y lo demás empieza de cero, avisando
	var cf := ConfigFile.new()
	cf.set_value("formato", "version", VetProgress.FORMAT_VERSION)
	cf.set_value("progreso", "xp", "mucha")
	cf.set_value("progreso", "credits", 55)
	cf.set_value("progreso", "lens_on", "diamante")
	cf.set_value("progreso", "lenses", { "plastico": 7, "vidrio": { "owned": true, "damage": "rayadísima" }, "otra": {} })
	cf.set_value("progreso", "jobs", { "coping_aguila": { "state": "hecho", "xp": 50, "credits": 30 }, "no_existe": { "state": "hecho" }, 3: "x" })
	cf.set_value("progreso", "active_job", "inventado")
	cf.save(CFG)
	var q := VetProgress.new()
	q.load_file(CFG)
	assert_eq(q.xp, 0, "la experiencia rara, de cero")
	assert_eq(q.credits, 55, "los créditos, recuperados")
	assert_eq(q.lens_on, "plastico", "una lente que no existe: la de serie")
	assert_true(q.owns("vidrio") and q.obscuration("vidrio") == 0.0, "el vidrio comprado se conserva (sin los rayones raros)")
	assert_eq(q.job_state("coping_aguila"), "hecho", "el encargo hecho se conserva")
	assert_eq(q.active_job, "", "sin encargo inventado")
	assert_true(q.notice.contains("experiencia"), "y avisa de lo que no ha podido leer: %s" % q.notice)
	# de una versión más nueva: no se toca y no se guarda encima
	var cf2 := ConfigFile.new()
	cf2.set_value("formato", "version", VetProgress.FORMAT_VERSION + 1)
	cf2.set_value("progreso", "xp", 9999)
	cf2.save(CFG)
	var r := VetProgress.new()
	r.load_file(CFG)
	assert_true(r.read_only, "solo lectura")
	assert_eq(r.save_to(CFG), ERR_UNAVAILABLE, "no se guarda encima")
	var check := ConfigFile.new()
	check.load(CFG)
	assert_eq(int(check.get_value("progreso", "xp")), 9999, "el archivo nuevo, intacto")
	# sin archivo: de cero, sin avisos
	var z := VetProgress.new()
	z.load_file("user://no_existe_este_archivo.cfg")
	assert_eq(z.notice, "", "sin archivo, sin avisos")


## Una consulta de verdad con el estado de la cetrería: la rapaz encapuchada y envuelta, el sobrante limado con una faceta
## que sigue la curva y la punta rematada (la sesión bien hecha de tests/lab/test_claw_care.gd).
static func _good_session(st: CareState) -> void:
	st.set_sedation("sujecion")
	var c := st.care
	var alpha := c.tip_alpha_deg()
	var over := c.overgrowth_left_mm()
	var strokes := 0
	while c.overgrowth_left_mm() > 0.05 * over and strokes < 300:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
	var taps := 0
	while float(c.tip_state().ratio) < 0.5 and taps < 50:
		c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
		taps += 1
	c.apply({ "tool": "crema" })


func test_los_encargos_se_comprueban_con_el_informe_del_motor() -> void:
	# bien hecha: el arreglo de las garras del águila se cobra
	var st := CareState.new({ "animal": "rapaz", "claw": "aguila" })
	_good_session(st)
	st.finish()
	var s := VetProgress.care_summary(st.view())
	assert_eq(String(s.animal), "rapaz", "el resumen dice el animal")
	assert_true(float(s.grade) >= 6.0 and not bool(s.bled), "nota %s y sin sangre (%s)" % [s.grade, s.verdict])
	var p := VetProgress.new()
	p.accept("coping_aguila")
	var r := p.on_care_finished(s)
	assert_true(bool(r.ok), "cumplido con el informe del motor: %s" % r.text)
	assert_true(int(r.xp) > 0 and p.xp == int(r.xp), "cobrado: %d de experiencia" % p.xp)
	for it: Dictionary in r.items:
		assert_true(bool(it.ok), "%s: se cumple" % it.id)
	# la misma con la carne viva cortada: no se cumple y dice por qué
	var st2 := CareState.new({ "animal": "rapaz", "claw": "aguila" })
	st2.set_sedation("sujecion")
	st2.care.call("_cut_to", st2.care.apex_mm() - (st2.care.quick_cover_mm() + 0.5))
	st2.care.hemostasis({ "tool": "hemostatico", "pressure_s": 400.0 })
	st2.finish()
	var s2 := VetProgress.care_summary(st2.view())
	assert_true(bool(s2.bled), "ha sangrado")
	var p2 := VetProgress.new()
	p2.accept("coping_aguila")
	var r2 := p2.on_care_finished(s2)
	assert_false(bool(r2.ok), "con sangre, el arreglo no se cumple")
	assert_true(String(r2.text).contains("sangró"), "y dice por qué: %s" % r2.text)
	assert_eq(p2.job_state("coping_aguila"), "en_curso", "sigue en curso: se puede volver a intentar")
	# un tigre tocado sin anestesia: ni el encargo ni la práctica
	var st3 := CareState.new({ "animal": "tigre" })
	st3.care.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 20.0 })
	st3.finish()
	var s3 := VetProgress.care_summary(st3.view())
	assert_true(bool(s3.unsafe), "sin anestesia, peligro")
	var p3 := VetProgress.new()
	p3.xp = 400
	p3.best_level = 3
	p3.accept("tigre_anestesia")
	var r3 := p3.on_care_finished(s3)
	assert_false(bool(r3.ok), "el tigre sin anestesia no se cumple")
	assert_true(String(r3.text).contains("anestesia"), "por la anestesia: %s" % r3.text)
	assert_eq(p3.xp, 400, "y no da ni la práctica")
	# la reforja: una funda de oro terminada con el tutorial de su receta
	var fs := ForgeState.new({ "animal": "rapaz", "claw": "aguila" })
	fs.set_speed(ForgeState.SPEEDS.size() - 1)
	fs.set_tutorial(true)
	fs.tutorial_goto("oro")
	for i in 80:
		if fs.current_step().is_empty():
			break
		fs.do_step()
		var n := 0
		while (fs.running() or (not fs.act.is_empty() and float(fs.act.t) < float(fs.act.dur))) and n < 20000:
			if fs.running():
				fs.skip()
			fs.tick(1.0 / 30.0)
			n += 1
	var fsum := VetProgress.forge_summary(fs.view())
	assert_eq(String(fsum.material), "oro", "una pieza de oro")
	assert_eq(String(fsum.verdict), "bien", "terminada: %s" % fs.view().sheet.verdict_text)
	var p4 := VetProgress.new()
	p4.xp = 120
	p4.best_level = 2
	p4.accept("funda_oro")
	var r4 := p4.on_forge_finished(fsum)
	assert_true(bool(r4.ok), "la funda de oro, cumplida con el informe de la reforja: %s" % r4.text)
	assert_eq(p4.job_state("funda_oro"), "hecho", "hecha")
	# la soldadura, sin la mesa de soldar (null): no se cumple
	var p5 := VetProgress.new()
	p5.best_level = 3
	p5.accept("soldar_punta")
	assert_false(bool(p5.on_forge_finished(fsum).ok), "sin unión soldada, el encargo de soldar no se cumple")
	assert_eq(p5.jobs_view(false).filter(func(e: Dictionary) -> bool: return String(e.id) == "soldar_punta").size(), 0, "y sin la mesa de soldar no sale en la lista")


func test_la_nota_y_los_errores() -> void:
	# más nota nunca da menos recompensa
	var prev := -1
	for g: float in [6.0, 7.0, 8.0, 9.0, 10.0]:
		var p := VetProgress.new()
		p.accept("coping_aguila")
		var r := p.on_care_finished(_care("rapaz", "aguila", { "grade": g, "session": "g%s" % g }))
		assert_true(bool(r.ok), "nota %s: cumplido" % g)
		assert_true(int(r.xp) >= prev, "nota %s: %d de experiencia, antes %d" % [g, r.xp, prev])
		prev = int(r.xp)
	assert_eq(prev, int(VetProgress.job("coping_aguila").xp), "con un 10, toda la recompensa")
	# un error que el encargo no pide evitar resta y se explica; uno que sí pide, lo hace fallar (no resta dos veces)
	var q := VetProgress.new()
	q.accept("coping_aguila")
	var r2 := q.on_care_finished(_care("rapaz", "aguila", { "grade": 10.0, "moved": 2, "peak_quick_c": 50.0, "session": "f" }))
	assert_true(bool(r2.ok), "cumplido con errores")
	var ids: Array = (r2.deductions as Array).map(func(d: Dictionary) -> String: return String(d.id))
	assert_true(ids.has("se_mueve") and ids.has("calor"), "restan el movimiento y el calor: %s" % [ids])
	assert_true(int(r2.xp) < int(VetProgress.job("coping_aguila").xp), "menos que sin errores")
	assert_eq(String(r2.tone), "aviso", "en amarillo")
	for d: Dictionary in r2.deductions:
		assert_true(String(d.why).length() > 10 and String(d.source).length() > 3, "%s: su porqué y su fuente" % d.id)
	var q2 := VetProgress.new()
	q2.accept("buho_quieto")
	q2.best_level = 2
	q2.accept("buho_quieto")
	var r3 := q2.on_care_finished(_care("rapaz", "buho", { "moved": 1, "session": "m" }))
	assert_false(bool(r3.ok), "el búho que se mueve no cumple «sin que se mueva»")
	# muchos errores nunca dan una recompensa negativa
	var all := q.faults(_care("rapaz", "aguila", { "bled": true, "moved": 2, "peak_quick_c": 60.0, "criteria": ["sujecion", "sin_desinfectar"] }), {})
	var lost := 0.0
	for d: Dictionary in all:
		lost += float(d.frac)
	assert_true(lost >= 0.9, "todos los errores juntos restan casi todo (%s)" % lost)
	var z := VetProgress.new()
	z.best_level = 2
	z.accept("buho_quieto")
	z.abandon()
	assert_eq(z.active_job, "", "dejar el encargo")
	assert_eq(z.job_state("buho_quieto"), "disponible", "vuelve a la lista")


func test_los_numeros_del_juego_van_marcados_y_los_textos_se_leen() -> void:
	for e: Dictionary in VetProgress.LEVELS:
		assert_eq(String(e.quality), VetProgress.GAME, "nivel %d: juego" % e.level)
	for id: String in VetProgress.LENS_SHOP:
		assert_eq(String(VetProgress.LENS_SHOP[id].quality), VetProgress.GAME, "%s: precio de juego" % id)
	for id: String in VetProgress.FAULTS:
		assert_eq(String(VetProgress.FAULTS[id].quality), VetProgress.GAME, "%s: lo que resta, juego" % id)
	assert_eq(String(VetProgress.PRACTICE.quality), VetProgress.GAME, "la práctica, juego")
	assert_eq(VetProgress.LENS_IDS.size(), 4, "cuatro lentes")
	# las de la cetrería (5t-A), con el mismo nivel
	var Reaction: GDScript = load("res://core/lab/claw_care_reaction.gd")
	assert_eq(VetProgress.LENS_IDS, Reaction.LENS_IDS, "los mismos ids que la cetrería")
	for id: String in VetProgress.LENS_IDS:
		assert_eq(int(VetProgress.LENS_SHOP[id].level), int(Reaction.LENSES[id].level), "%s: el nivel de la tienda, el de la cetrería" % id)
	assert_eq(VetProgress.LEVELS.size(), VetProgress.LENS_IDS.size(), "un nivel por lente")
	var ids := {}
	var re := RegEx.create_from_string(BAD)
	for j: Dictionary in VetProgress.JOBS:
		assert_eq(String(j.quality), VetProgress.GAME, "%s: la recompensa, juego" % j.id)
		assert_false(ids.has(String(j.id)), "%s: id único" % j.id)
		ids[String(j.id)] = true
		assert_true(int(j.level) >= 1 and int(j.level) <= VetProgress.MAX_LEVEL, "%s: su nivel" % j.id)
		for t: String in [String(j.title), String(j.text)]:
			assert_true(re.search(t) == null, "%s: sin nombres internos en «%s»" % [j.id, t])
		for a: Dictionary in VetProgress.ask_texts(j):
			assert_true(re.search(String(a.text)) == null, "%s: lo que pide, legible: «%s»" % [j.id, a.text])
			if String(a.id) != "animal":
				assert_true(String(a.source).length() > 3, "%s · %s: con su fuente" % [j.id, a.id])
	assert_true(VetProgress.JOBS.size() >= 8 and VetProgress.JOBS.size() <= 12, "8-12 encargos (%d)" % VetProgress.JOBS.size())
	# cada nivel tiene encargos con los que subir al siguiente, y sin caminos cerrados: con la nota mínima de cada uno (y sin
	# la mesa de soldar), lo que dan los encargos hasta un nivel llega a la experiencia del siguiente
	var cum := 0.0
	for n in VetProgress.MAX_LEVEL - 1:
		var lv := n + 1
		var at: Array = VetProgress.JOBS.filter(func(j: Dictionary) -> bool: return int(j.level) == lv)
		assert_true(at.size() >= 2, "nivel %d: al menos dos encargos" % lv)
		for j: Dictionary in at:
			if bool(j.get("needs_weld", false)):
				continue
			var f := 1.0 if String(j.kind) == "reforja" else VetProgress.GRADE_FLOOR + (1.0 - VetProgress.GRADE_FLOOR) * float(j.min_grade) / 10.0
			cum += float(j.xp) * f
		assert_true(cum >= float(VetProgress.LEVELS[lv].xp), "hasta el nivel %d dan como poco %s de experiencia: llega al nivel %d (%d)" % [lv, cum, lv + 1, VetProgress.LEVELS[lv].xp])
	var p := VetProgress.new()
	var lvw := p.level_view()
	assert_true(String(lvw.text).begins_with("Nivel 1") and String(lvw.next_text).contains("nivel 2"), "la barra: %s · %s" % [lvw.text, lvw.next_text])
	for e: Dictionary in p.jobs_view():
		for t: String in [String(e.state_text), String(e.reward_text), String(e.where)]:
			assert_true(re.search(t) == null, "%s: «%s»" % [e.id, t])
