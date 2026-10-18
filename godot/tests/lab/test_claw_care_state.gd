## Estado de la página «Cetrería» (core/lab/claw_care_state.gd, unidad 5b): convierte los gestos de la escena 3D en las
## llamadas de ClawCare y da los textos. Se comprueba que no hace física por su cuenta (sus llamadas, repetidas en otra
## ClawCare, dan la misma garra), que el reloj no se separa del tiempo real, que las teclas no fuerzan nada, que la
## carne viva oculta no se revela antes de terminar, el tutorial (pasos que se cumplen al hacerlos y el salto a «Si
## sangra») y que cada texto y cada fuente legible sale de los datos.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_care_state.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 60.0


## Una pasada: aprieta en s0, arrastra along mm en n fotogramas (con el reloj) y levanta.
static func _stroke(st: State, s0: float, along: float, n: int) -> void:
	st.press_on(s0)
	for i in n:
		st.drag(along / float(n), absf(along) / float(n), s0, FRAME)
		st.tick(FRAME)
	st.release()


static func _hold(st: State, s0: float, secs: float) -> void:
	st.press_on(s0)
	var n := int(round(secs / FRAME))
	for i in n:
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


## Repite las llamadas del estado en una ClawCare nueva con los mismos ajustes.
static func _replay(st: State) -> ClawCare:
	var s := st.setup
	var c := ClawCare.new({ "animal": String(s.animal), "claw": String(s.claw), "inlay": String(s.inlay), "quick": "oculta",
		"seed": String(s.seed), "overgrowth_days": float(s.overgrowth_days), "sedation": String(s.sedation),
		"humidity": String(s.humidity) })
	for call: Array in st.calls:
		match String(call[0]):
			"file":
				c.file(call[1])
			"clip":
				c.clip(call[1])
			"hemostasis":
				c.hemostasis(call[1])
			"apply":
				c.apply(call[1])
			"advance":
				c.advance(float(call[1]))
			"advance_held":
				c.advance_held(float(call[1]))
			"set_sedation":
				c.set_sedation(String(call[1]))
			"set_humidity":
				c.set_humidity(String(call[1]))
			"probe_tip":
				c.probe_tip(call[1])
	return c


## ¿Sale el número num (con «mm» detrás) en el texto, sin ser parte de otro número?
static func _mentions(text: String, num: String) -> bool:
	var re := RegEx.create_from_string("(?<![0-9.])%s mm" % num.replace(".", "\\."))
	return re.search(text) != null


static func _no_serial(d: Dictionary) -> Dictionary:
	var x := d.duplicate(true)
	x.erase("serial")
	return x


## La garra sin el animal: lo que repiten sus propias llamadas cuando el animal también se ha trabajado con otras garras (el
## animal, compartido, lo repite history: test_claw_care_pulido.gd).
static func _claw_only(d: Dictionary) -> Dictionary:
	var x := _no_serial(d)
	x.erase("animal")
	return x


# ════════ Bandeja ════════

func test_la_bandeja_y_sus_teclas() -> void:
	var ids := {}
	for t: Dictionary in State.TRAY:
		assert_false(ids.has(t.id), "%s una sola vez" % t.id)
		ids[t.id] = true
		var d := State.tool_data(String(t.id))
		assert_false(d.is_empty(), "%s: datos en CareData.TOOLS o en la bandeja" % t.id)
		assert_true(String(d.get("source", "")).length() > 10, "%s: con fuente" % t.id)
		assert_true(String(t.gesture) in ["lima", "torno", "corte", "presion", "aplicar", "remojar"], "%s: gesto conocido" % t.id)
	for id: String in CareData.TOOLS:
		assert_true(ids.has(id), "la herramienta %s de CareData está en la bandeja" % id)
	assert_eq([State.tool_for_key(1), State.tool_for_key(2), State.tool_for_key(3), State.tool_for_key(4)],
		["lima_bastarda", "lima_fina", "torno", "guillotina"], "1-4: lima gruesa, lima fina, torno y cortaúñas")
	assert_eq(String(CareData.TOOLS.lima_bastarda.kind), "lima", "la gruesa es una lima")
	assert_true(float(CareData.TOOLS.lima_bastarda.teeth_cm) < float(CareData.TOOLS.lima_fina.teeth_cm), "la gruesa, con menos dientes por cm")


func test_la_mano_no_pasa_de_sus_topes() -> void:
	var st := State.new()
	st.set_force(1000.0)
	assert_eq(st.force_n, State.FORCE_MAX, "presión máxima")
	for i in 100:
		st.nudge_force(-1)
	assert_eq(st.force_n, State.FORCE_MIN, "presión mínima")
	st.set_angle(-40.0)
	assert_eq(st.angle_deg, State.ANGLE_MIN, "ángulo mínimo")
	st.nudge_angle(500.0)
	assert_eq(st.angle_deg, State.ANGLE_MAX, "ángulo máximo")
	# el interruptor del torno solo con el torno en la mano; al dejarlo, se apaga
	st.set_rotary(true)
	assert_false(st.rotary_on, "sin el torno en la mano no se enciende")
	st.pick("torno")
	st.toggle_rotary()
	assert_true(st.rotary_on, "encendido")
	st.pick("lima_fina")
	assert_false(st.rotary_on, "al dejar el torno, se apaga")
	st.pick("torno")
	st.cycle_rpm()
	assert_eq(st.rpm(), 13000.0, "la segunda velocidad del Dremel 7300-PT")
	assert_near(st.drum_speed_ms(), ClawCare.surface_speed_ms(12.7, 13000.0), 1e-12, 0.0, "la velocidad del tambor, la de ClawCare")


# ════════ Gestos → ClawCare ════════

func test_la_pagina_solo_llama_a_clawcare() -> void:
	var st := State.new({ "seed": "prueba" })
	st.set_sedation("sujecion")
	var L := st.care.apex_mm()
	st.pick("guillotina")
	_hold(st, L - 1.5, State.CLIP_CLOSE_S + 0.2)
	st.pick("lima_bastarda")
	st.set_angle(22.0)
	for k in 6:
		_stroke(st, st.care.apex_mm() - 1.0, 40.0, 24)
	_stroke(st, st.care.apex_mm() - 8.0, -30.0, 20)
	st.pick("torno")
	st.set_rotary(true)
	_hold(st, st.care.apex_mm() - 0.5, 0.8)
	st.pick("crema")
	st.press_on(st.care.apex_mm() - 2.0)
	for i in 30:
		st.tick(FRAME)
	var kinds := {}
	for c: Array in st.calls:
		kinds[String(c[0])] = true
	for k: String in ["set_sedation", "clip", "file", "apply", "advance"]:
		assert_true(kinds.has(k), "ha llamado a %s" % k)
	var ref := _replay(st)
	assert_eq(var_to_str(_no_serial(ref.snapshot())), var_to_str(_no_serial(st.care.snapshot())), "las mismas llamadas dan la misma garra")
	assert_eq(var_to_str(ref.report()), var_to_str(st.care.report()), "y el mismo informe")


func test_el_reloj_sigue_al_tiempo_real() -> void:
	var st := State.new()
	var real := 0.0
	st.pick("lima_bastarda")
	for k in 5:
		st.press_on(st.care.apex_mm() - 1.0)
		for i in 23:
			st.drag(1.7, 1.7, 0.0, FRAME)
			st.tick(FRAME)
			real += FRAME
		st.release()
		for i in 11:
			st.tick(1.0 / 30.0)
			real += 1.0 / 30.0
	var c := st.clock()
	assert_near(float(c.t_s) + float(c.debt_s), real, 1e-9, 1e-9, "tiempo del ensayo + lo que se debe = tiempo real")
	assert_true(absf(float(c.debt_s)) < 0.35, "el reloj del ensayo no se separa: debe %s s" % Js.to_fixed(float(c.debt_s), 3))
	# en pausa no pasa el tiempo
	st.set_paused(true)
	var t0 := st.care.time_s()
	for i in 60:
		st.tick(FRAME)
	assert_eq(st.care.time_s(), t0, "en pausa, el ensayo no avanza")
	st.press_on(st.care.apex_mm() - 1.0)
	assert_true(st.hand_view().active == false, "ni se puede limar")


func test_direccion_zona_y_largo_de_la_pasada() -> void:
	var st := State.new()
	st.pick("lima_fina")
	var L := st.care.apex_mm()
	_stroke(st, L - 1.0, 20.0, 10)
	var p: Dictionary = st.calls.filter(func(c: Array) -> bool: return c[0] == "file").back()[1]
	assert_eq(String(p.zone), "punta", "cerca del vértice: la punta")
	assert_eq(String(p.direction), "a_favor", "hacia la punta: a favor")
	_stroke(st, L - 15.0, -20.0, 10)
	p = st.calls.filter(func(c: Array) -> bool: return c[0] == "file").back()[1]
	assert_eq(String(p.zone), "flanco", "lejos del vértice: el flanco")
	assert_near(float(p.at_mm), st.care.apex_mm() - (L - 15.0), 1e-9, 1e-9, "a esa distancia de la punta")
	assert_eq(String(p.direction), "en_contra", "hacia la base: en contra de las capas")
	# ir y volver en la misma pasada es vaivén
	st.press_on(L - 1.0)
	for i in 10:
		st.drag(2.0, 2.0, 0.0, FRAME)
		st.tick(FRAME)
	for i in 10:
		st.drag(-2.0, 2.0, 0.0, FRAME)
		st.tick(FRAME)
	st.release()
	p = st.calls.filter(func(c: Array) -> bool: return c[0] == "file").back()[1]
	assert_eq(String(p.direction), "vaiven", "ida y vuelta: vaivén")
	# la pasada acaba donde acaba la lima
	var before := st.calls.size()
	st.press_on(L - 1.0)
	for i in 100:
		st.drag(5.0, 5.0, 0.0, FRAME)
	var total := 0.0
	for i in range(before, st.calls.size()):
		if st.calls[i][0] == "file":
			total += float(st.calls[i][1].travel_mm)
	assert_false(st.hand_view().active, "más allá de %s mm la lima ya no toca" % Js.to_fixed(State.FILE_LENGTH_MM, 0))
	assert_near(total, State.FILE_LENGTH_MM, 1e-9, 1e-9, "la pasada entera, %s mm" % Js.to_fixed(total, 1))


func test_el_cortaunas_se_cierra_manteniendo_pulsado() -> void:
	var st := State.new()
	st.pick("guillotina")
	var L := st.care.apex_mm()
	st.press_on(L - 2.0)
	for i in 10:
		st.tick(FRAME)
	st.release()
	assert_eq(st.care.apex_mm(), L, "soltado antes de cerrarse, no corta")
	assert_eq(st.calls.filter(func(c: Array) -> bool: return c[0] == "clip").size(), 0, "ni llama a clip()")
	st.press_on(L - 2.0)
	var frames := int(ceil(State.CLIP_CLOSE_S / FRAME)) + 1
	var seen_closing := 0.0
	for i in frames:
		seen_closing = maxf(seen_closing, float(st.hand_view().closing))
		st.tick(FRAME)
	st.release()
	assert_true(seen_closing > 0.5, "se ve cerrarse (%s)" % Js.to_fixed(seen_closing, 2))
	var clips := st.calls.filter(func(c: Array) -> bool: return c[0] == "clip")
	assert_eq(clips.size(), 1, "cerrado del todo: un corte")
	assert_near(float(clips[0][1].remove_mm), 2.0, 1e-9, 1e-9, "de lo que había entre el cortaúñas y la punta")
	assert_near(st.care.apex_mm(), L - 2.0, 1e-9, 1e-6, "la garra, más corta")
	# el tigre no cabe en un cortaúñas de guillotina: la física lo dice y la página no lo fuerza
	var t := State.new({ "animal": "tigre" })
	t.set_sedation("anestesia")
	t.pick("guillotina")
	var Lt := t.care.apex_mm()
	_hold(t, Lt - 20.0, State.CLIP_CLOSE_S + 0.1)
	assert_eq(t.care.apex_mm(), Lt, "no cabe: no corta")
	assert_true(String(t.view().notice).begins_with("No corta"), "y lo dice: %s" % t.view().notice)


func test_el_torno_solo_lima_encendido() -> void:
	var st := State.new()
	st.pick("torno")
	var L := st.care.apex_mm()
	_hold(st, L - 3.0, 0.5)
	assert_eq(st.care.apex_mm(), L, "apagado, el tambor no arranca nada")
	assert_true(String(st.view().notice).contains("apagado"), "y avisa de que está apagado")
	st.set_rotary(true)
	_hold(st, L - 3.0, 0.5)
	var files := st.calls.filter(func(c: Array) -> bool: return c[0] == "file")
	assert_true(files.size() >= 4, "encendido, file() a trozos de %s s" % Js.to_fixed(State.ROTARY_CHUNK_S, 1))
	var dwell := 0.0
	for c: Array in files:
		assert_eq(String(c[1].tool), "torno", "con el torno")
		assert_eq(float(c[1].rpm), 6500.0, "a sus rpm")
		dwell += float(c[1].dwell_s)
	assert_near(dwell, 0.5, 1e-9, ClawCare.DT + 1e-9, "el tiempo de contacto")
	assert_true(float(st.view().snap.thermal.faceC) > 32.0, "y calienta")


func test_hemostasis_y_aplicar() -> void:
	var st := State.new({ "animal": "rapaz" })
	st.set_sedation("sujecion")
	# cortar de más: sangra
	st.pick("guillotina")
	var cover := st.care.quick_cover_mm()
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (cover + 1.0), State.CLIP_CLOSE_S + 0.1)
	assert_true(bool(st.care.snapshot().bleeding.active), "sangra")
	var fx: Array = st.view().fx
	assert_true(fx.any(func(e: Dictionary) -> bool: return e.kind == "bleed"), "efecto de sangre")
	assert_true(fx.any(func(e: Dictionary) -> bool: return e.kind == "sfx" and e.id == "skin-cut"), "suena el corte de la carne viva")
	# la crema… el metacrilato no se pone sangrando
	st.pick("metacrilato")
	st.press_on(st.care.apex_mm() - 1.0)
	assert_true(String(st.view().notice).begins_with("Aún no"), "no se reconstruye sangrando: %s" % st.view().notice)
	st.pick("hemostatico")
	_hold(st, st.care.apex_mm() - 0.5, float(CareData.HEMOSTASIS.agent_s.value) + 1.0)
	assert_false(bool(st.care.snapshot().bleeding.active), "hemostático y presión: para")
	var hs := st.calls.filter(func(c: Array) -> bool: return c[0] == "hemostasis")
	assert_true(hs.size() > 10 and String(hs[0][1].tool) == "hemostatico", "hemostasis() a trozos, con el hemostático")
	st.pick("clorhexidina")
	st.press_on(st.care.apex_mm() - 1.0)
	assert_true(st.care.check("desinfectada"), "desinfectada")
	# la gasa sola es presión sin hemostático
	var g := State.new()
	g.pick("presion")
	_hold(g, g.care.apex_mm() - 1.0, 0.5)
	var gs := g.calls.filter(func(c: Array) -> bool: return c[0] == "hemostasis")
	assert_true(gs.size() > 0 and String(gs[0][1].tool) == "", "la gasa: hemostasis() sin hemostático")


func test_remojar() -> void:
	var st := State.new()
	st.pick("agua")
	st.press_on(st.care.apex_mm() - 3.0)
	assert_eq(String(st.care.setup().humidity), "humeda", "el agua tibia la remoja")
	assert_true(st.care.check("remojada"), "remojada")
	st.set_humidity("natural")
	assert_eq(String(st.care.setup().humidity), "natural", "y se deja orear")


# ════════ La carne viva oculta ════════

func test_la_carne_viva_oculta_no_se_revela_antes_de_terminar() -> void:
	for aid: String in ["rapaz", "oso", "velociraptor"]:
		var st := State.new({ "animal": aid })
		var v := st.view()
		assert_false(bool(v.hints.revealed), "%s: garra oscura, no se ve" % aid)
		assert_true(v.snap.claw.quickMm == null and v.snap.claw.quickCoverMm == null, "%s: sin su posición" % aid)
		for x: float in v.snap.profile.core:
			assert_eq(x, 0.0, "%s: sin su perfil" % aid)
		assert_false((v.initial_profile as Dictionary).has("core"), "%s: tampoco en el perfil de partida" % aid)
		assert_true(v.report.facts.quickCoverMm == null and v.report.facts.safeMarginMm == null, "%s: ni en el informe" % aid)
		var q := Js.to_fixed(float(st.care.snapshot().claw.quickMm), 1)
		var cov := Js.to_fixed(st.care.quick_cover_mm(), 1)
		var all := var_to_str(v.readouts) + var_to_str(v.texts)
		assert_false(_mentions(all, q) or _mentions(all, cov), "%s: ningún texto dice dónde está (%s, %s)" % [aid, q, cov])
		var band: Array = v.hints.quick_band
		assert_true(band.size() == 2 and float(band[0]) < float(band[1]), "%s: la banda de la población, sí" % aid)
		var a: Dictionary = CareData.ANIMALS[aid]
		assert_near(float(band[0]), float(a.core_ratio.min) * float(st.care.snapshot().claw.naturalMm), 1e-12, 0.0, "%s: del dato" % aid)
		st.finish()
		v = st.view()
		assert_true(bool(v.hints.revealed) and v.snap.claw.quickMm != null, "%s: al terminar, se revela" % aid)
		assert_true(String(v.texts.quick).contains(q), "%s: y se dice dónde estaba" % aid)
	var t := State.new({ "animal": "tigre" })
	assert_true(bool(t.view().hints.revealed), "el tigre: garra clara, la carne viva se ve a trasluz")
	var z := State.new({ "inlay": "zafiro" })
	assert_false(bool(z.view().hints.revealed), "una reforjada no tiene carne viva")
	assert_true((z.view().hints.quick_band as Array).is_empty(), "ni banda")


# ════════ Tutorial ════════

func test_el_tutorial_sigue_al_hacer_cada_paso() -> void:
	var st := State.new({ "animal": "rapaz" })
	var tv: Dictionary = st.view().tutorial
	assert_eq(String(tv.process), "preparar", "empieza preparando al animal")
	assert_eq(String(tv.step.id), "capucha", "encapuchar")
	assert_eq(String(tv.step.status), "pendiente", "pendiente: el ave no está encapuchada (petición 51: un paso que se cumple)")
	assert_eq(String(tv.goal), "Encapucha al ave", "con su objetivo en pocas palabras")
	assert_eq(String(tv.ui), "sedacion:sujecion", "y el mando que hay que pulsar")
	st.set_sedation("sujecion")
	tv = st.view().tutorial
	# «Capucha y toalla» cumple los dos pasos: el de la toalla, ya hecho al llegar, sigue solo
	assert_eq(String(tv.step.id), "isoflurano", "al sujetarla, el tutorial sigue solo")
	assert_eq(String(tv.step.status), "info", "un paso informativo")
	# el informativo sigue solo cuando ha dado tiempo a leerlo
	var rs := State.read_s(st.current_step())
	for i in int(ceilf(rs / FRAME)) + 2:
		st.tick(FRAME)
	assert_eq(String(st.view().tutorial.step.id), "material", "leído (%s s), sigue solo sin «Siguiente»" % Js.to_fixed(rs, 1))
	# cada paso trae su texto y su fuente legible
	for pid: String in Tutorial.PROCESS_IDS:
		for s: Dictionary in st.care.tutorial(pid):
			var short := State.short_source(String(s.source))
			assert_true(short.length() > 3 and short.length() <= String(s.source).length(), "%s/%s: fuente legible" % [pid, s.id])
	# remojar cumple su paso
	st.tutorial_goto("recortar")
	tv = st.view().tutorial
	assert_eq(String(tv.step.id), "remojar", "recortar empieza remojando")
	assert_eq(String(tv.suggest), "agua", "y sugiere el agua")
	st.pick("agua")
	st.press_on(st.care.apex_mm() - 3.0)
	tv = st.view().tutorial
	assert_eq(String(tv.step.id), "guillotina", "remojada: el siguiente paso")
	assert_eq(String(tv.hint), "sobrante", "resalta el sobrante")


func test_si_sangra_el_tutorial_salta_y_vuelve() -> void:
	var st := State.new({ "animal": "rapaz" })
	st.set_sedation("sujecion")
	st.tutorial_goto("limar")
	var at_step := String(st.view().tutorial.step.id)
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 0.5), State.CLIP_CLOSE_S + 0.1)
	var tv: Dictionary = st.view().tutorial
	assert_eq(String(tv.process), "sangrado", "sangra: «Si sangra»")
	assert_eq(String(tv.step.id), "coger", "primero, coger el polvo hemostático (en el orden en que se hace)")
	assert_eq(String(tv.suggest), "hemostatico", "sugiere el hemostático")
	st.pick("hemostatico")
	assert_eq(String(st.view().tutorial.step.id), "hemostatico", "cogido: apretar sobre la herida")
	_hold(st, st.care.apex_mm() - 0.5, float(CareData.HEMOSTASIS.agent_s.value) + 1.0)
	tv = st.view().tutorial
	assert_eq(String(tv.step.id), "desinfectar", "parada: desinfectar")
	st.tutorial_next()
	tv = st.view().tutorial
	if bool(st.care.snapshot().damage.broken):
		assert_eq(String(tv.process), "reconstruir", "rota: «Garra rota»")
		st.pick("metacrilato")
		st.press_on(st.care.apex_mm() - 0.5)
		while String(st.view().tutorial.process) == "reconstruir":
			st.tutorial_next()
		tv = st.view().tutorial
	assert_eq(String(tv.process), "limar", "y vuelve a limar")
	assert_eq(String(tv.step.id), at_step, "al mismo paso")


# ════════ Textos ════════

func test_textos_y_fuentes_legibles() -> void:
	for sid: Array in State.SOURCE_NAMES:
		assert_true(String(sid[0]).length() > String(sid[1]).length(), "%s: más corto que la cita" % sid[1])
	# cada fuente de CareData tiene nombre legible
	for name: String in ["SRC_SAMOUR", "SRC_ARENT", "SRC_MSD", "SRC_SAKAS", "SRC_HEDRICK", "SRC_MANNING", "SRC_AAD",
			"SRC_FARRAN", "SRC_DREMEL_GUIDE", "SRC_DREMEL_7300", "SRC_VCA", "SRC_CATTALES", "SRC_ANIMALS_ASIA", "SRC_LOZIER"]:
		var full := String((CareData as Script).get_script_constant_map()[name])
		assert_true(State.short_source(full) != full, "%s tiene nombre legible" % name)
	assert_eq(State.short_source(CareData.SRC_SAMOUR + ", p. 916"), "Samour 2006 (Clinical Avian Medicine), p. 916", "con su página")
	for aid: String in CareData.ANIMAL_IDS:
		for inl: String in ["none", "acero"]:
			var st := State.new({ "animal": aid, "inlay": inl })
			var v := st.view()
			for r: Dictionary in v.readouts:
				assert_true(String(r.label) != "" and String(r.value) != "", "%s/%s: lectura %s" % [aid, inl, r.id])
			for k: String in ["tool", "hand", "status", "verdict", "grade"]:
				assert_true(v.texts.has(k), "%s: texto %s" % [aid, k])
			for t: Dictionary in v.tray:
				assert_true(String(t.name) != "" and String(t.short) != "", "%s: bandeja %s" % [aid, t.id])
	# la mano: la presión y el ángulo con los formatos del laboratorio
	var st2 := State.new()
	st2.set_force(0.5)
	st2.set_angle(90.0)
	assert_eq(st2.hand_text(), "Presión 0.5 N · ángulo 90° (de frente)", "de frente")
	st2.set_angle(22.0)
	assert_eq(st2.hand_text(), "Presión 0.5 N · ángulo 22° (faceta de 22°)", "faceta")


func test_empezar_de_nuevo_y_otra_garra() -> void:
	var st := State.new()
	var q1 := float(st.care.snapshot().claw.quickMm)
	st.pick("lima_fina")
	_stroke(st, st.care.apex_mm() - 1.0, 20.0, 10)
	st.restart()
	assert_true(st.calls.is_empty(), "empezar de nuevo: sin llamadas")
	assert_eq(st.care.apex_mm(), float(st.care.snapshot().claw.startMm), "la garra entera otra vez")
	assert_true(float(st.care.snapshot().claw.quickMm) != q1, "con la carne viva en otro sitio de la banda")
	assert_eq(String(st.care.setup().sedation), "libre", "sin sujetar")
	st.set_animal("oso")
	assert_eq(String(st.setup.claw), "oso", "el oso, con su garra")
	st.set_inlay("titanio")
	assert_true(st.is_reforged() and String(st.care.setup().inlay) == "titanio", "reforjada de titanio")
	assert_eq(st.flow(), State.FLOW_REFORGED, "con su tutorial")
	# lo mismo dos veces da lo mismo
	var a := State.new({ "seed": "x" })
	var b := State.new({ "seed": "x" })
	for x: State in [a, b]:
		x.pick("lima_bastarda")
		_stroke(x, x.care.apex_mm() - 1.0, 30.0, 12)
	assert_eq(var_to_str(a.view()), var_to_str(b.view()), "determinista")


## Ninguna fuente que se enseña lleva rutas ni nombres internos: todas las de CareData y las de los pasos del tutorial
## pasan por readable_source() (sin docs/, .gd, §, fichas del motor ni unidades de trabajo) y no se quedan vacías.
func test_fuentes_sin_rutas_ni_nombres_internos() -> void:
	var bad := RegEx.create_from_string("docs/|\\.gd\\b|§|res://|\\b(Data|Physics|CareData|ClawCare|ClawsV2|MovingCar)\\.|\\bunidad [0-9]|[A-Z]+_[A-Z_]+\\b")
	var sources: Array = []
	for t: String in CareData.TOOLS:
		sources.append(String(CareData.TOOLS[t].source))
	for a: String in CareData.ANIMALS:
		var an: Dictionary = CareData.ANIMALS[a]
		for k: String in ["growth_mm_day", "core_ratio", "layers", "regrow_days"]:
			if an.has(k):
				sources.append(String(an[k].source))
		for p: String in Tutorial.PROCESS_IDS:
			for st: Dictionary in Tutorial.steps(a, p):
				sources.append(String(st.source))
	for k: String in CareData.THERMAL:
		sources.append(String(CareData.THERMAL[k].source))
	for k: String in CareData.KERATIN:
		sources.append(String(CareData.KERATIN[k].source))
	for k: String in CareData.HEMOSTASIS:
		sources.append(String(CareData.HEMOSTASIS[k].source))
	sources.append_array([CareData.SRC_RUBRIC, CareData.SRC_ENGINE_GEOMETRY, CareData.SRC_ENGINE_KERATIN, String(CareData.MARGINS.source)])
	for src: String in sources:
		var r := State.short_source(src)
		var m := bad.search(r)
		assert_true(m == null, "«%s» en la fuente legible «%s»" % [m.get_string() if m != null else "", r.substr(0, 120)])
		assert_true(r.length() >= 4, "la fuente no se queda vacía: «%s» → «%s»" % [src.substr(0, 60), r])
	assert_eq(State.readable_source("Rúbrica pedagógica del simulador (docs/fisica/cetreria.md, §6.8): cuánto pesa cada fallo"),
		"Rúbrica pedagógica del simulador: cuánto pesa cada fallo", "la ruta y el apartado se van; el resto, igual")


## «Valores y fuentes»: cada dato del ensayo con su valor, su calidad en palabras y su fuente legible, para cada animal
## y para las reforjadas (con la resistencia de su material, sin carne viva).
func test_valores_y_fuentes() -> void:
	for setup: Dictionary in [{ "animal": "rapaz" }, { "animal": "tigre" }, { "animal": "oso" }, { "animal": "velociraptor" },
			{ "animal": "tigre", "inlay": "vidrio" }, { "animal": "rapaz", "inlay": "acero" }]:
		var st := State.new(setup)
		var rows := st.values_table()
		var what := "%s/%s" % [String(st.setup.animal), String(st.setup.inlay)]
		assert_true(rows.size() >= 20, "%s: %d datos" % [what, rows.size()])
		var labels: Array = rows.map(func(r: Dictionary) -> String: return String(r.label))
		for want in ["Crecimiento de la garra", "Umbral del dolor por calor", "Hemostasia con polvo y presión", "Material y dureza"]:
			assert_true(labels.has(want), "%s: «%s»" % [what, want])
		assert_eq(labels.has("Dónde acaba la carne viva"), not st.is_reforged(), "%s: la carne viva, solo en la queratina" % what)
		assert_eq(labels.has("Resistencia del material"), st.is_reforged(), "%s: la resistencia, en las reforjadas" % what)
		for r: Dictionary in rows:
			assert_true(String(r.value) != "" and String(r.source) != "", "%s · %s: valor y fuente" % [what, r.label])
			assert_true(String(r.quality) == "" or String(r.quality_text) != "", "%s · %s: la calidad en palabras" % [what, r.label])
	var g: Dictionary = CareData.ANIMALS.tigre.growth_mm_day
	var t := State.new({ "animal": "tigre" })
	var row: Dictionary = t.values_table().filter(func(r: Dictionary) -> bool: return r.label == "Crecimiento de la garra")[0]
	assert_true(String(row.value).begins_with(Js.to_fixed(float(g.value), 2)), "el valor es el de CareData: %s" % row.value)
	assert_eq(String(row.quality_text), "estimación", "y su calidad")


## La ficha del final, antes → después: vacía antes de terminar; al terminar, los números de la garra que da el motor.
func test_ficha_antes_y_despues() -> void:
	var st := State.new({ "animal": "rapaz" })
	assert_true(st.result_sheet().is_empty(), "antes de terminar no hay ficha (la carne viva aún no se revela)")
	st.set_sedation("sujecion")
	st.pick("lima_bastarda")
	st.set_angle(22.0)
	st.set_force(8.0)
	for k in 6:
		_stroke(st, st.care.apex_mm() - 3.0, 8.0, 6)
	st.finish()
	var sh := st.result_sheet()
	var by := {}
	for r: Dictionary in sh.rows:
		by[String(r.id)] = r
	var sn := st.care.snapshot()
	assert_eq(String(by.largo.after), "%s mm" % Js.to_fixed(float(sn.claw.lengthMm), 1), "el largo de después, el del motor")
	assert_true(float(sn.claw.lengthMm) < float(sn.claw.startMm), "más corta que al empezar")
	assert_eq(String(by.largo.before), "%s mm" % Js.to_fixed(float(sn.claw.startMm), 1), "y el de antes, el de partida")
	assert_true(String(by.punta.after).begins_with(Js.to_fixed(float(st.care.tip_geometry().R) * 1000.0, 0)), "el radio de la punta, de tip_geometry()")
	assert_eq(String(by.carne.after), "%s mm" % Js.to_fixed(float(sn.claw.quickCoverMm), 1), "la distancia a la carne viva, revelada al terminar")
	assert_eq(String(sh.verdict), String(st.care.report().verdict), "el veredicto del motor")
	assert_eq(String(sh.grade_text), String(st.care.report().gradeText), "y la nota")


## Un error se explica: qué ha pasado (el aviso del motor) y cómo se arregla (el paso del tutorial, con su mando y su
## fuente); «Entendido» lo quita hasta el siguiente.
func test_los_errores_se_explican() -> void:
	var st := State.new({ "animal": "rapaz" })
	assert_true(st.mistake_view().is_empty(), "sin errores, nada")
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("guillotina")
	_hold(st, st.care.apex_mm() - 2.0, 0.6)
	var m := st.mistake_view()
	assert_eq(String(m.code), "grieta", "el cortaúñas en seco raja: %s" % m)
	assert_true(String(m.fix_title).ends_with("Limar la cara del corte"), "se arregla limando la cara del corte")
	assert_true(String(m.control).contains("Tecla 1"), "con su mando")
	assert_true(String(m.fix_source).contains("Farran"), "y su fuente legible")
	# arreglado (la cara del corte limada de frente hasta que no queda grieta), deja de explicarse solo
	st.pick("lima_bastarda")
	st.set_angle(90.0)
	st.set_force(8.0)
	var n := 0
	while not st.care.check("sin_grieta") and n < 20:
		_stroke(st, st.care.apex_mm() - 1.0, 6.0, 4)
		n += 1
	assert_true(st.care.check("sin_grieta"), "la grieta, limada")
	assert_true(st.mistake_view().is_empty(), "y la explicación se va sola")
	st.set_humidity("seca")
	st.pick("guillotina")
	_hold(st, st.care.apex_mm() - 1.5, 0.6)
	assert_false(st.mistake_view().is_empty(), "otro corte en seco, otra grieta")
	st.dismiss_mistake()
	assert_true(st.mistake_view().is_empty(), "«Entendido»: se quita")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0), 0.6)
	assert_true(String(st.mistake_view().fix_title).begins_with("Si sangra"), "cortar la carne viva: «Si sangra»")
	for pid: String in st.flow():
		for s: Dictionary in Tutorial.steps("rapaz", pid):
			assert_true(State.STEP_CONTROLS.has(String(s.id)), "el paso %s/%s dice qué control usar" % [pid, s.id])


# ════════ Las patas y sus garras (unidad 5c) ════════

## Repite las llamadas de una garra cualquiera (no la de partida) en una ClawCare nueva con sus ajustes.
static func _replay_slot(st: State) -> ClawCare:
	var c := ClawCare.new(st.care_setup(st.paw, st.digit))
	for call: Array in st.calls:
		match String(call[0]):
			"file":
				c.file(call[1])
			"clip":
				c.clip(call[1])
			"hemostasis":
				c.hemostasis(call[1])
			"apply":
				c.apply(call[1])
			"advance":
				c.advance(float(call[1]))
			"advance_held":
				c.advance_held(float(call[1]))
			"set_sedation":
				c.set_sedation(String(call[1]))
			"set_humidity":
				c.set_humidity(String(call[1]))
			"probe_tip":
				c.probe_tip(call[1])
	return c


## Dos patas la rapaz y el velocirraptor, cuatro el tigre y el oso (petición 31); cada garra de cada pata, su ClawCare:
## lo que se hace en una no toca a las demás, cada una con su carne viva, y la nueva se pone al día con el reloj.
func test_cada_garra_de_cada_pata_es_su_propio_ensayo() -> void:
	assert_eq(State.paws_of("rapaz").size(), 2, "la rapaz, dos patas")
	assert_eq(State.paws_of("velociraptor").size(), 2, "el velocirraptor, dos")
	assert_eq(State.paws_of("tigre").size(), 4, "el tigre, cuatro")
	assert_eq(State.paws_of("oso").size(), 4, "el oso, cuatro")
	for aid: String in CareData.ANIMAL_IDS:
		assert_true(State.DIGITS.has(aid) and not (State.DIGITS[aid] as Array).is_empty(), "%s: sus garras" % aid)
	var st := State.new({ "animal": "rapaz", "seed": "patas" })
	assert_eq(st.paw, "derecha", "empieza por la pata derecha")
	assert_eq(st.digit, "III", "y el dedo III")
	st.set_sedation("sujecion")
	var first := st.care
	var L := first.apex_mm()
	st.pick("lima_bastarda")
	st.set_angle(90.0)
	_stroke(st, L - 1.0, 30.0, 20)
	var after := first.apex_mm()
	assert_true(after < L, "la lima acorta la garra de partida")
	var t := st.care.time_s()
	st.select_claw("izquierda", "I")
	assert_true(st.care != first, "otra garra, otra ClawCare")
	assert_eq(st.care.apex_mm(), float(st.care.snapshot().claw.startMm), "la otra garra está como empezó")
	assert_true(st.care.apex_mm() > L, "con el largo de la suya: el talón del águila es la garra mayor (petición 36)")
	assert_near(st.care.time_s(), t, 0.0, ClawCare.DT, "y al día con el reloj")
	assert_eq(String(st.care.setup().sedation), "sujecion", "la sujeción es del animal")
	assert_true(String(st.care.setup().seed) != String(first.setup().seed), "con su propia semilla (su carne viva)")
	_stroke(st, st.care.apex_mm() - 1.0, 30.0, 20)
	var ref := _replay_slot(st)
	assert_eq(var_to_str(_claw_only(ref.snapshot())), var_to_str(_claw_only(st.care.snapshot())), "sus llamadas dan la misma garra")
	assert_true(float(st.care.snapshot().animal.stress) >= float(first.snapshot().animal.stress) - 1e-12, "el animal es el mismo: su estrés no se borra")
	st.set_sedation("anestesia")
	st.select_claw("derecha", "III")
	assert_true(st.care == first, "volver a la de partida")
	assert_eq(st.care.apex_mm(), after, "con lo que se le hizo")
	assert_eq(String(st.care.setup().sedation), "anestesia", "y la sujeción de ahora")
	var v := st.view()
	assert_eq(String(v.claw_label), "Pata derecha · dedo III, el del medio", "la vista dice de qué pata y de qué garra")
	assert_eq((v.slots as Array).size(), 8, "dos patas de cuatro garras")
	var worked: Array = (v.slots as Array).filter(func(e: Dictionary) -> bool: return bool(e.worked))
	assert_eq(worked.size(), 2, "dos garras trabajadas")
	var other: Array = (v.slots as Array).filter(func(e: Dictionary) -> bool: return String(e.key) == "izquierda|I")
	assert_false((other[0].profile as Dictionary).is_empty(), "la otra, con su forma para dibujarla")
	st.finish()
	var sh := st.result_sheet()
	assert_eq(String(sh.claw_label), "Pata derecha · dedo III, el del medio", "la ficha dice la pata y la garra")
	assert_eq((sh.others as Array).size(), 1, "y las demás garras trabajadas, con su nota")
	assert_true(String(sh.others[0].label).begins_with("Pata izquierda"), "de qué pata")
	# P y G: la pata siguiente y la garra siguiente
	st.resume()
	st.cycle_paw()
	assert_eq(st.paw, "izquierda", "P: la otra pata")
	st.cycle_digit()
	assert_eq(st.digit, "II", "G: la garra siguiente")
	# empezar de nuevo conserva la pata y la garra; otro animal vuelve a las de partida
	st.restart()
	assert_eq([st.paw, st.digit], ["izquierda", "II"], "empezar de nuevo, la misma garra")
	st.set_animal("tigre")
	assert_eq([st.paw, st.digit], ["delantera_derecha", "III"], "otro animal, la de partida")
	st.select_claw("trasera_izquierda", "V")
	assert_eq(String(st.view().claw_label), "Pata trasera izquierda · dedo V", "las patas traseras del tigre")
	var vals: Array = State.values_for({ "animal": "tigre", "claw": "tigre", "inlay": "none", "paw": "trasera_izquierda" })
	var hind: Array = vals.filter(func(r: Dictionary) -> bool: return String(r.label) == "Garras de las patas traseras")
	assert_eq(hind.size(), 1, "«Valores y fuentes» avisa de las patas traseras")
	assert_eq(String(hind[0].quality), "estimate", "como estimación: llevan los datos de la mano")
	var bird_vals: Array = State.values_for({ "animal": "rapaz", "claw": "aguila", "inlay": "none" })
	assert_eq(bird_vals.filter(func(r: Dictionary) -> bool: return String(r.label) == "Garras de las patas traseras").size(), 0, "la rapaz no tiene patas traseras")


## Una garra que sangra sigue su reloj aunque se trabaje otra.
func test_la_que_sangra_sigue_aunque_no_se_vea() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "sangra" })
	st.set_sedation("sujecion")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0), State.CLIP_CLOSE_S + 0.1)
	assert_true(bool(st.care.snapshot().bleeding.active), "sangra")
	var bleeding := st.care
	st.select_claw("derecha", "II")
	for i in 60:
		st.tick(FRAME)
	assert_near(bleeding.time_s(), st.care.time_s(), 0.0, ClawCare.DT, "la que sangra va al día")
	var s: Array = (st.view().slots as Array).filter(func(e: Dictionary) -> bool: return String(e.key) == "derecha|III")
	assert_true(bool(s[0].bleeding), "y la vista sabe que sangra")


# ════════ La amoladora (unidad 5c) ════════

## La amoladora con protector: el modelo del torno (file con dwell_s y sus rpm), sus cuatro velocidades de la ficha, el
## ángulo de su protector y su interruptor.
func test_la_amoladora_es_el_torno_con_sus_datos() -> void:
	var d := CareData.tool("amoladora")
	assert_eq(String(d.kind), "torno", "el modelo de siempre: el del torno")
	assert_eq(d.rpm_steps, [8000.0, 14000.0, 21000.0, 25000.0], "cuatro velocidades de 8000 a 25 000 rpm")
	assert_eq(float(d.drum_mm), 12.7, "banda de 1/2″")
	assert_true(String(d.source).contains("7760") and String(d.quality) == "secondary", "con su fuente")
	assert_eq(State.tool_for_key(5), "amoladora", "tecla 5")
	var st := State.new({ "animal": "tigre", "seed": "amoladora" })
	st.set_sedation("anestesia")
	st.set_angle(20.0)
	st.pick("amoladora")
	assert_eq(st.angle_deg, 45.0, "su protector la apoya a 45°")
	assert_eq(st.rpm(), 8000.0, "arranca en la más baja")
	assert_false(st.rotary_on, "apagada")
	var L := st.care.apex_mm()
	_hold(st, L - 0.5, 0.5)
	assert_eq(st.care.apex_mm(), L, "apagada no arranca nada")
	st.toggle_rotary()
	assert_true(st.rotary_on, "E la enciende")
	st.cycle_rpm()
	assert_eq(st.rpm(), 14000.0, "Q: la segunda")
	assert_eq(State.rpm_options("amoladora").size(), 4, "cuatro velocidades en el selector")
	assert_near(st.drum_speed_ms(), ClawCare.surface_speed_ms(12.7, 14000.0), 1e-12, 0.0, "la banda a π·D·n")
	_hold(st, st.care.apex_mm() - 0.5, 0.6)
	var files := st.calls.filter(func(c: Array) -> bool: return c[0] == "file")
	assert_true(files.size() >= 1, "toca la garra (%d trozos)" % files.size())
	for c: Array in files:
		assert_eq(String(c[1].tool), "amoladora", "con la amoladora")
		assert_eq(float(c[1].rpm), 14000.0, "a sus rpm")
		assert_true(c[1].has("dwell_s"), "por tiempo de contacto, como el torno")
	assert_true(st.care.apex_mm() < L, "y arranca")
	var ref := _replay(st)
	assert_eq(var_to_str(_no_serial(ref.snapshot())), var_to_str(_no_serial(st.care.snapshot())), "las mismas llamadas dan la misma garra")
	st.pick("torno")
	assert_false(st.rotary_on, "al cambiar al torno, la amoladora se apaga")
	assert_eq(st.rpm(), 6500.0, "y el torno empieza en su primera velocidad")
	assert_eq(String(st.hand_view().get("rotary_tool", "")), "torno", "la mano lo sabe")


## Empezar de nuevo con otra garra elegida: la garra nueva empieza libre (la sujeción de los ajustes), no con la del
## ensayo anterior; y el consejo del calor, si se ha usado la amoladora, habla de su velocidad más baja.
func test_empezar_de_nuevo_y_el_consejo_de_la_amoladora() -> void:
	var st := State.new({ "animal": "tigre", "seed": "nuevo" })
	st.set_sedation("anestesia")
	st.select_claw("trasera_derecha", "IV")
	assert_eq(String(st.care.setup().sedation), "anestesia", "la garra nueva, con la anestesia del animal")
	st.restart()
	assert_eq([st.paw, st.digit], ["trasera_derecha", "IV"], "empezar de nuevo conserva la garra elegida")
	assert_eq(String(st.care.setup().sedation), "libre", "pero el ensayo nuevo empieza sin sujetar")
	assert_eq(String(st.view().snap.animal.sedation), "libre", "y la vista lo dice")
	# el calor de la amoladora apretada en el flanco, cerca de la carne viva: el consejo, con su velocidad
	st.set_sedation("anestesia")
	st.pick("amoladora")
	st.set_rotary(true)
	for i in 3:
		st.cycle_rpm()
	st.set_force(State.FORCE_MAX)
	var at := st.care.apex_mm() - (float(st.care.snapshot().claw.quickMm) - 1.0)
	_hold(st, at, 6.0)
	st.finish()
	var sh := st.result_sheet()
	var adv: Array = (sh.advice as Array).filter(func(a: Dictionary) -> bool: return String(a.get("id", "")) == "torno")
	var peak := float(st.care.snapshot().thermal.peakQuickC)
	assert_true(peak >= float(CareData.THERMAL.pain_c.value), "a 25 000 rpm y 10 N, la carne viva se calienta (%s °C)" % Js.to_fixed(peak, 1))
	assert_eq(adv.size(), 1, "el consejo del calor")
	if adv.size() == 1:
		# lo da el motor (unidad 5g): habla de la amoladora, la única giratoria usada, y no de los 6500 rpm del torno
		assert_eq(String(adv[0].title), "La amoladora", "con la amoladora")
		assert_true(String(adv[0].text).contains("8000"), "y su velocidad más baja")
		assert_false(String(adv[0].text).contains("6500"), "sin hablar del torno, que no se ha usado")
		assert_true(String(adv[0].text).contains(State.grouped(25000.0)), "y la velocidad a la que se ha usado")
		assert_true(String(adv[0].source).contains("Dremel Lite"), "con su fuente")
	assert_eq(st.care.report().advice.filter(func(a: Dictionary) -> bool: return String(a.id) == "torno")[0].title, "La amoladora",
		"el consejo sale así del motor: la página no lo cambia")
