## La cetrería guiada (unidad 5o, petición 51): el estado del animal (el estrés, la sangre y el calor) con sus avisos y la sesión
## que se para si se pasa de los límites, la infección si sangró y no se desinfectó, lo que se está haciendo con su cuenta (los
## segundos que lleva y los que hacen falta, y «Has soltado antes de tiempo»), las limas claras (para qué sirve cada una, qué ha
## hecho cada pasada y por qué no muerde) y el tutorial mejor guiado (un objetivo por paso, el mando que hay que pulsar, sigue solo
## y su progreso). Invariantes donde es física; nada de números mágicos salvo los de las fichas.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 60.0


static func _wait(st: State, secs: float, scale: float = 1.0) -> void:
	st.set_time_scale(scale)
	var left := secs / scale
	while left > 1e-9:
		var dt := minf(left, 0.25)
		st.tick(dt)
		left -= dt
	st.set_time_scale(1.0)


## Aprieta la herramienta de la mano en s (mm desde la base) durante secs (s reales), sin moverla.
static func _hold(st: State, s0: float, secs: float) -> void:
	st.press_on(s0)
	for i in int(round(secs / FRAME)):
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


## Una pasada de verdad con la herramienta de la mano en la punta (arrastrando): eso es tocarle las garras.
static func _stroke(st: State) -> void:
	var s0 := st.care.apex_mm() - 1.0
	st.press_on(s0)
	for i in 4:
		st.drag(3.0, 3.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


## Corta con la tenaza hasta la carne viva (sangra).
static func _cut_quick(st: State) -> void:
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0), State.CLIP_CLOSE_S + 0.1)


# ════════ El estrés del animal ════════

## La barra del animal: cada límite (el estrés, la sangre y el calor) con su fuente legible y su calidad, en cada animal.
func test_los_limites_de_la_barra_llevan_fuente() -> void:
	for aid: String in CareData.ANIMAL_IDS:
		var st := State.new({ "animal": aid, "seed": "f-" + aid })
		var ids: Array = []
		for m: Dictionary in st.animal_view():
			ids.append(String(m.id))
			assert_true(String(m.get("source", "")).length() > 20, "%s/%s: el límite con su fuente" % [aid, m.id])
			assert_true(String(m.get("quality_text", "")) in State.QUALITY_TEXT.values(), "%s/%s: y su calidad («%s»)" % [aid, m.id, m.get("quality_text", "")])
			assert_false(String(m.source).contains("res://") or String(m.source).contains(".gd"), "%s/%s: legible" % [aid, m.id])
		assert_eq(ids, ["estres", "sangre", "calor"], "%s: las tres medidas" % aid)

func test_el_estres_sube_con_el_tiempo_y_la_capucha_lo_frena() -> void:
	# sin tocarla, sin sujetar, el tiempo no la estresa (está en su percha)
	var idle := State.new({ "animal": "rapaz", "seed": "e1" })
	_wait(idle, 30.0)
	assert_eq(idle.patient.stress, 0.0, "sin tocarla, el tiempo no estresa a la rapaz suelta")
	# tocada sin sujetar: más tiempo nunca da menos estrés
	var free := State.new({ "animal": "rapaz", "seed": "e2" })
	free.pick("lima_fina")
	_stroke(free)
	var prev := free.patient.stress
	for i in 4:
		_wait(free, 5.0)
		assert_true(free.patient.stress >= prev - 1e-12, "más tiempo sin sujetar, nunca menos estrés")
		prev = free.patient.stress
	# tocada una vez y dejada (sin sujetar, la herramienta parada): el tiempo que pasa no la estresa más (fallo de Eric,
	# 18-10-2026: subía un 2 % por segundo sin tocarla)
	var left := State.new({ "animal": "rapaz", "seed": "e3" })
	left.pick("lima_fina")
	_stroke(left)
	var s_left := left.patient.stress
	_wait(left, 60.0)
	assert_near(left.patient.stress, s_left, 0.0, 1e-12, "sin sujetar y sin tocarla, un minuto no le sube el estrés")
	# cortada la punta con el cortaúñas y dejada: tampoco (fallo de Eric, 18-10-2026: subía sin parar)
	var cut := State.new({ "animal": "rapaz", "seed": "e5" })
	cut.pick("guillotina")
	var L := cut.care.apex_mm()
	cut.press_on(L - 2.0)
	_wait(cut, State.CLIP_CLOSE_S + 0.2)
	cut.release()
	assert_true(cut.care.apex_mm() < L, "el cortaúñas corta")
	var s_cut := cut.patient.stress
	_wait(cut, 60.0)
	assert_near(cut.patient.stress, s_cut, 0.0, 1e-12, "tras el corte, un minuto sin tocarla no le sube el estrés")
	# encapuchada, tampoco: lo que estresa es manejarla, no el tiempo que pasa (Eric, 18-10-2026: «no tan hardcore»)
	var held := State.new({ "animal": "rapaz", "seed": "e3" })
	held.set_sedation("sujecion")
	held.pick("lima_fina")
	_stroke(held)
	var s_held := held.patient.stress
	_wait(held, 60.0)
	assert_near(held.patient.stress, s_held, 0.0, 1e-12, "encapuchada y sin tocarla, un minuto no le sube el estrés")
	# encapuchada y envuelta, el mismo trabajo, menos estrés
	var bare := State.new({ "animal": "rapaz", "seed": "e4" })
	var hooded := State.new({ "animal": "rapaz", "seed": "e4" })
	hooded.set_sedation("sujecion")
	for st: State in [bare, hooded]:
		st.pick("lima_fina")
		for i in 6:
			_stroke(st)
	assert_true(hooded.patient.stress < bare.patient.stress, "encapuchada: menos estrés que sin capucha con el mismo trabajo (%s < %s)" % [hooded.patient.stress, bare.patient.stress])
	# anestesiada, ni el dolor la estresa (no lo siente)
	var an := State.new({ "animal": "rapaz", "seed": "e9", "sedation": "anestesia" })
	var s_before := an.patient.stress
	an.patient.react(1.0)
	assert_eq(an.patient.stress, s_before, "con anestesia general, el dolor no sube el estrés")
	var aw := State.new({ "animal": "rapaz", "seed": "e9", "sedation": "sujecion" })
	aw.patient.react(1.0)
	assert_true(aw.patient.stress > 0.0, "despierta, sí")
	# anestesiada, el tiempo no la estresa
	var asleep := State.new({ "animal": "rapaz", "seed": "e2" })
	asleep.set_sedation("anestesia")
	_wait(asleep, 200.0, 10.0)
	assert_eq(asleep.patient.stress, 0.0, "anestesiada, nada")
	# las palabras de la barra
	assert_eq([State.stress_word(0.1), State.stress_word(0.5), State.stress_word(0.75), State.stress_word(0.95)], ["calma", "inquieto", "estresado", "peligro"], "de la calma al peligro")
	var bar: Array = free.view().animal.meters
	assert_eq(bar.map(func(e: Dictionary) -> String: return String(e.id)), ["estres", "sangre", "calor"], "la barra: el estrés, la sangre y el calor")
	for e: Dictionary in bar:
		assert_true(float(e.value) >= 0.0 and float(e.value) <= 1.0 and float(e.limit) > 0.0 and float(e.limit) < 1.0, "%s: dentro de la barra, con su límite marcado" % e.id)
		assert_true(String(e.tip).length() > 40, "%s: con el porqué y qué hacer" % e.id)
		assert_true(String(e.short).length() <= 15 and String(e.short).length() > 0, "%s: el texto corto del teléfono cabe («%s»)" % [e.id, e.short])
	assert_true(String(bar[0].text).contains("sin sujetar") and String(bar[0].short).contains("suelta"), "la rapaz sin sujetar: entero y corto")


func test_la_sesion_se_para_con_un_aviso_antes() -> void:
	# el tigre sin sedar: el primer toque avisa; el segundo, ataca
	var t := State.new({ "animal": "tigre", "seed": "t1" })
	t.pick("lima_fina")
	t.press_on(t.care.apex_mm() - 1.0)
	t.release()
	assert_true(t.halted.is_empty(), "el primer toque no para la sesión")
	assert_true(String(t.view().notice).begins_with("¡Cuidado!"), "avisa: %s" % t.view().notice)
	t.press_on(t.care.apex_mm() - 1.0)
	t.release()
	assert_eq(String(t.halted.get("code", "")), "ataca", "el segundo, ataca: la sesión se para")
	assert_true(t.finished and String(t.halted.text).length() > 40 and String(t.halted.todo).contains("Anestesia"), "con la explicación y qué hacer")
	# parada: nada más se puede hacer, ni volver; empezar de nuevo, sí
	var removed := float(t.care.snapshot().claw.removedMm3)
	t.press_on(t.care.apex_mm() - 1.0)
	t.release()
	assert_eq(float(t.care.snapshot().claw.removedMm3), removed, "parada: la herramienta no hace nada")
	t.resume()
	assert_true(t.finished, "ni se vuelve al ensayo")
	t.restart()
	assert_true(t.halted.is_empty() and not t.finished, "se empieza de nuevo enseguida")
	# anestesiado, se le tocan las garras sin peligro
	var ok := State.new({ "animal": "tigre", "seed": "t2" })
	ok.set_sedation("anestesia")
	for i in 3:
		ok.pick("lima_fina")
		ok.press_on(ok.care.apex_mm() - 1.0)
		ok.release()
	assert_true(ok.halted.is_empty(), "anestesiado, sin peligro")
	# la rapaz sin sujetar: se estresa, avisa y, al máximo, se suelta
	var r := State.new({ "animal": "rapaz", "seed": "r1" })
	r.pick("lima_fina")
	var warned := false
	var guard := 0
	# cogiéndole la garra sin capucha (dejarla quieta ya no la estresa: test_el_estres_sube_con_el_tiempo_y_la_capucha_lo_frena)
	_stroke(r)
	r.press_on(r.care.apex_mm() - 1.0)
	while r.halted.is_empty() and guard < 400:
		r.tick(0.25)
		warned = warned or String(r.view().notice).contains("muy estresada")
		guard += 1
	assert_true(warned, "avisa antes de soltarse")
	assert_eq(String(r.halted.get("code", "")), "se_suelta", "sin capucha, al estrés máximo se suelta")
	# se recoge con la toalla y se encapucha: sigue con la misma garra y lo hecho, y el informe lo cuenta
	var removed_r := float(r.care.snapshot().claw.removedMm3)
	assert_true(bool(r.halted.get("recoverable", false)), "la rapaz que se suelta se puede recoger")
	r.recapture()
	assert_true(r.halted.is_empty() and not r.finished, "recogida: la sesión sigue")
	assert_eq(r.patient.sedation, "sujecion", "encapuchada y envuelta")
	assert_true(r.patient.resting, "y en la pausa, calmándose")
	assert_eq(float(r.care.snapshot().claw.removedMm3), removed_r, "con lo que ya se había hecho")
	assert_eq(r.escapes, 1, "se ha soltado una vez")
	var s_r := r.patient.stress
	_wait(r, 30.0)
	assert_true(r.patient.stress < s_r, "a oscuras y quieta, el estrés baja (%s < %s)" % [r.patient.stress, s_r])
	r.finish()
	assert_true((r.result_sheet().get("advice", []) as Array).any(func(ad: Dictionary) -> bool: return String(ad.id) == "se_solto"), "el informe dice que se soltó")
	# un tigre que ataca no se recoge así
	var tg := State.new({ "animal": "tigre", "seed": "t3" })
	tg.pick("lima_fina")
	for i in 2:
		tg.press_on(tg.care.apex_mm() - 1.0)
		tg.release()
	assert_eq(String(tg.halted.get("code", "")), "ataca", "el tigre ataca")
	tg.recapture()
	assert_false(tg.halted.is_empty(), "y eso no se arregla con una toalla")
	# encapuchada, el estrés del tiempo solo avisa: no para la sesión
	var h := State.new({ "animal": "rapaz", "seed": "r2" })
	h.set_sedation("sujecion")
	h.pick("lima_fina")
	_stroke(h)
	h.press_on(h.care.apex_mm() - 1.0)
	_wait(h, 400.0, 10.0)
	h.release()
	assert_true(h.patient.stress >= 1.0 - 1e-9 and h.halted.is_empty(), "encapuchada, manejada mucho rato: estrés al máximo, pero sigue")


# ════════ La sangre y la infección ════════

func test_la_sangre_que_pierde_el_animal() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "s1", "sedation": "sujecion" })
	var b0 := st.blood_state()
	var mass := CareAnatomy.value("aguila", "mass_kg")
	assert_near(float(b0.volumeMl), mass * 1000.0 * float(CareData.BLOOD.volume_frac.rapaz.value), 1e-9, 0.0, "el volumen: la masa por el 10 % de las aves")
	assert_eq(float(b0.lostMl), 0.0, "sin sangrar, nada perdido")
	_cut_quick(st)
	assert_true(bool(st.care.snapshot().bleeding.active), "sangra")
	var prev := 0.0
	for i in 5:
		_wait(st, 20.0)
		var lost := float(st.blood_state().lostMl)
		assert_true(lost >= prev, "sangrando más tiempo, nunca pierde menos")
		prev = lost
	assert_near(prev, float(st.blood_state().bleedingS) * float(CareData.BLOOD.bleed_ml_s), 1e-9, 0.0, "lo perdido: el tiempo sangrando por lo que sale")
	# el águila (5 kg) sin tratar, hasta que para sola: no llega al peligro
	_wait(st, float(CareData.HEMOSTASIS.none_s.value), 10.0)
	assert_true(st.halted.is_empty(), "el águila aguanta la pérdida de una garra sin tratar (%s %%)" % Js.to_fixed(float(st.blood_state().frac) * 100.0, 1))
	# una lechuza (0,35 kg, ~35 mL): avisa y, si no se para, la sesión se para
	var o := State.new({ "animal": "rapaz", "claw": "lechuza", "seed": "s2", "sedation": "sujecion" })
	_cut_quick(o)
	var warned := false
	var guard := 0
	while o.halted.is_empty() and guard < 200 and bool(o.care.snapshot().bleeding.active):
		_wait(o, 5.0)
		warned = warned or String(o.view().notice).contains("de su sangre")
		guard += 1
	assert_true(warned, "avisa antes")
	assert_eq(String(o.halted.get("code", "")), "sangre", "la lechuza pierde demasiada sangre: la sesión se para")
	assert_true(float(o.blood_state().frac) >= float(CareData.BLOOD.stop_frac) - 1e-9, "al 30 %")
	# con el hemostático a tiempo, no
	var q := State.new({ "animal": "rapaz", "claw": "lechuza", "seed": "s3", "sedation": "sujecion" })
	_cut_quick(q)
	q.pick("hemostatico")
	q.set_time_scale(10.0)
	_hold(q, q.care.apex_mm() - 0.5, 3.4)
	q.set_time_scale(1.0)
	assert_false(bool(q.care.snapshot().bleeding.active), "parada a tiempo")
	assert_true(q.halted.is_empty() and float(q.blood_state().frac) < float(CareData.BLOOD.safe_frac), "dentro de lo permitido")


func test_si_sangro_y_no_se_desinfecta_riesgo_de_infeccion() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "i1", "sedation": "sujecion" })
	_cut_quick(st)
	st.pick("hemostatico")
	st.set_time_scale(10.0)
	_hold(st, st.care.apex_mm() - 0.5, 3.4)
	st.set_time_scale(1.0)
	st.finish()
	var crit: Array = st.care.report().criteria
	var inf := crit.filter(func(c: Dictionary) -> bool: return String(c.id) == "sin_desinfectar")
	assert_eq(inf.size(), 1, "el informe lo dice")
	assert_true(String(inf[0].title).contains("infección") and String(inf[0].source).length() > 20, "como riesgo de infección, con su fuente")
	var clean := State.new({ "animal": "rapaz", "seed": "i1", "sedation": "sujecion" })
	_cut_quick(clean)
	clean.pick("hemostatico")
	clean.set_time_scale(10.0)
	_hold(clean, clean.care.apex_mm() - 0.5, 3.4)
	clean.set_time_scale(1.0)
	clean.pick("clorhexidina")
	clean.press_on(clean.care.apex_mm() - 0.5)
	assert_false(clean.care.report().criteria.any(func(c: Dictionary) -> bool: return String(c.id) == "sin_desinfectar"), "desinfectada, no")


# ════════ Lo que se está haciendo, con su cuenta ════════

func test_cada_accion_que_lleva_tiempo_tiene_su_cuenta() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "a1", "sedation": "sujecion" })
	_cut_quick(st)
	st.pick("hemostatico")
	var s0 := st.care.apex_mm() - 0.5
	st.press_on(s0)
	var goal := float(CareData.HEMOSTASIS.agent_s.value)
	var last := -1.0
	var stopped_at := -1.0
	for i in int((goal + 2.0) / FRAME):
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
		var av: Dictionary = st.view().activity
		if bool(st.care.snapshot().bleeding.active):
			assert_true(String(av.text).contains("de %s s" % Js.to_fixed(goal, 0)) and bool(av.hold), "dice los segundos y que se mantenga pulsado: %s" % av.text)
			assert_true(float(av.frac) >= last - 1e-12 and float(av.frac) < 1.0, "la barra sube y no llega al final antes de tiempo")
			last = float(av.frac)
		elif stopped_at < 0.0:
			stopped_at = i
			assert_eq(float(av.frac), 1.0, "llega al 100 % justo cuando para")
			assert_true(String(av.text).begins_with("Listo") and bool(av.ready), "y dice que ya se puede soltar: %s" % av.text)
	st.release()
	assert_true(stopped_at > 0.0, "ha parado")
	# soltar antes de tiempo lo dice, con lo que faltaba
	var e := State.new({ "animal": "rapaz", "seed": "a2", "sedation": "sujecion" })
	_cut_quick(e)
	e.pick("hemostatico")
	_hold(e, e.care.apex_mm() - 0.5, 5.0)
	var tx := String(e.view().activity.text)
	assert_true(tx.begins_with("Has soltado antes de tiempo") and tx.contains("faltaban"), "soltada antes: %s" % tx)
	# el cortaúñas: mantener pulsado hasta que se cierre
	var c := State.new({ "animal": "rapaz", "seed": "a3", "sedation": "sujecion" })
	c.pick("guillotina")
	c.press_on(c.care.apex_mm() - 1.0)
	c.tick(FRAME * 6.0)
	var cv: Dictionary = c.view().activity
	assert_true(String(cv.text).contains("mantén pulsado") and float(cv.frac) > 0.0 and float(cv.frac) < 1.0, "cerrando: %s" % cv.text)
	c.release()
	assert_true(String(c.view().activity.text).contains("Has soltado antes de que se cierre"), "soltado antes: no corta")
	# el torno: unos segundos por toque
	var r := State.new({ "animal": "rapaz", "seed": "a4", "sedation": "sujecion" })
	r.pick("torno")
	r.set_rotary(true)
	r.press_on(r.care.apex_mm() - 0.5)
	for i in 30:
		r.drag(0.0, 0.0, r.care.apex_mm() - 0.5, FRAME)
		r.tick(FRAME)
	assert_true(String(r.view().activity.text).contains("por toque"), "el torno: %s" % r.view().activity.text)
	for i in int(float(CareData.ROTARY_TOUCH.value) / FRAME) + 5:
		r.drag(0.0, 0.0, r.care.apex_mm() - 0.5, FRAME)
		r.tick(FRAME)
	assert_true(String(r.view().activity.text).begins_with("Suelta ya"), "pasado el toque, que suelte: %s" % r.view().activity.text)
	r.release()


# ════════ Las limas, claras ════════

func test_las_limas_claras() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "l1", "sedation": "sujecion", "overgrowth_days": 120.0 })
	for t: Dictionary in st.view().tray:
		if State.TOOL_GUIDE.has(String(t.id)):
			assert_true(String(t.role) in ["desbastar", "afinar", "pulir"] and int(t.order) >= 1, "%s: para qué sirve y en qué orden" % t.id)
			assert_true(String(t.guide).contains("Arrastra") or String(t.guide).contains("Enciéndela"), "%s: cómo se usa" % t.id)
	# de grueso a fino: la de desbastar arranca más que la de pulir con la misma pasada (la física de la 5l)
	assert_true(int(State.TOOL_GUIDE.lima_bastarda[1]) < int(State.TOOL_GUIDE.lija_p240[1]), "primero la gruesa, al final la de pulir")
	# lo que ha hecho una pasada, en una línea
	st.pick("lima_bastarda")
	st.set_angle(90.0)
	var s := st.care.apex_mm() - 0.5
	st.press_on(s)
	for i in 6:
		st.drag(5.0, 5.0, s, FRAME)
		st.tick(FRAME)
	st.release()
	var line := st.action_text()
	assert_true(line.contains("mm³ fuera") and line.contains("superficie") and line.contains("Ra"), "lo que ha quitado y cómo queda: %s" % line)
	assert_true(line.contains("para su largo") and line.contains("pasadas así"), "y cuánto falta: %s" % line)
	assert_true(line.begins_with("La lima gruesa"), "con su nombre: %s" % line)
	# por qué no muerde, y qué coger
	var z := State.new({ "animal": "rapaz", "claw": "aguila", "inlay": "zafiro", "seed": "l2", "sedation": "sujecion" })
	z.pick("lima_bastarda")
	z.set_angle(90.0)
	var sz := z.care.apex_mm() - 0.5
	z.press_on(sz)
	for i in 6:
		z.drag(5.0, 5.0, sz, FRAME)
		z.tick(FRAME)
	z.release()
	var nb := z.action_text()
	assert_true(nb.contains("no muerde") and nb.contains("HV") and nb.contains("diamante"), "no muerde, por qué y qué coger: %s" % nb)


# ════════ El tutorial, mejor guiado ════════

func test_el_tutorial_guiado() -> void:
	# cada paso, con su objetivo en pocas palabras
	for aid: String in CareData.ANIMAL_IDS:
		for pid: String in Tutorial.PROCESS_IDS:
			for stp: Dictionary in Tutorial.steps(aid, pid):
				var g := String(State.STEP_GOALS.get(String(stp.id), ""))
				assert_true(g != "" and g.length() <= 40, "%s/%s: objetivo corto («%s»)" % [aid, stp.id, g])
	# el paso de cortar poco a poco no se da por hecho sin cortar
	var st := State.new({ "animal": "rapaz", "seed": "g1", "sedation": "sujecion", "humidity": "humeda" })
	st.tutorial_goto("recortar")
	assert_eq(String(st.view().tutorial.step.id), "remojar", "saltar a un proceso empieza por su primer paso (para leerlo)")
	st.tutorial_next()
	assert_eq(String(st.view().tutorial.step.id), "guillotina", "coger el cortaúñas")
	st.pick("guillotina")
	var tv: Dictionary = st.view().tutorial
	assert_eq(String(tv.step.id), "poco", "remojada y con el cortaúñas: cortar poco a poco")
	assert_eq(String(tv.step.status), "pendiente", "sin cortar, pendiente aunque no sangre")
	assert_true(String(tv.step.status_text).contains("has cortado"), "dice lo que pide: %s" % tv.step.status_text)
	st.press_on(st.care.apex_mm() - 1.0)
	for i in int((State.CLIP_CLOSE_S + 0.1) / FRAME):
		st.tick(FRAME)
	st.release()
	assert_eq(String(st.view().tutorial.step.id), "cara", "cortado sin sangrar: sigue solo")
	# el progreso: del paso, del proceso y del total, entre 0 y 1, y el total sube
	var p: Dictionary = st.view().tutorial.progress
	for k: String in ["step", "process", "total"]:
		assert_true(float(p[k]) >= 0.0 and float(p[k]) <= 1.0, "%s: entre 0 y 1" % k)
	var t0 := float(p.total)
	st.tutorial_next()
	assert_true(float(st.view().tutorial.progress.total) > t0, "el total sube")
	assert_true(String(st.view().tutorial.progress.total_text).begins_with("paso "), "y se cuenta")
	# si sangra: en el orden en que se hace
	var b := State.new({ "animal": "rapaz", "seed": "g2", "sedation": "sujecion" })
	_cut_quick(b)
	var ids: Array = (b.view().tutorial.processes as Array).map(func(x: Dictionary) -> String: return String(x.id))
	assert_true(ids.has("sangrado"), "sangra: «Si sangra»")
	assert_eq(Tutorial.steps("rapaz", "sangrado").map(func(x: Dictionary) -> String: return String(x.id)), ["coger", "hemostatico", "desinfectar"], "coger, apretar y desinfectar")
	assert_eq(String(b.view().tutorial.ui), "", "(coger: la herramienta resaltada en la bandeja)")
	assert_eq(String(b.view().tutorial.suggest), "hemostatico", "el polvo hemostático, resaltado")
	b.pick("hemostatico")
	var hv: Dictionary = b.view().tutorial
	assert_eq(String(hv.step.id), "hemostatico", "cogido: apretar")
	assert_eq(String(hv.ui), "reloj:10", "con el reloj ×10 resaltado (3 s en vez de 30)")
	b.press_on(b.care.apex_mm() - 0.5)
	for i in 60:
		b.drag(0.0, 0.0, b.care.apex_mm() - 0.5, FRAME)
		b.tick(FRAME)
	var pr: Dictionary = b.view().tutorial.progress
	assert_true(float(pr.step) > 0.0 and String(pr.step_text).contains("de 30 s"), "el progreso del paso, en segundos: %s" % pr.step_text)
	b.release()
