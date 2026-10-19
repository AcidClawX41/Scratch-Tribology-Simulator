## El guiado del tutorial de la cetrería (unidad 5y, core/lab/claw_care_guide.gd): cada paso del tutorial de cada animal apunta a
## un objetivo que existe (la herramienta de la bandeja, una zona de la garra o un mando del panel), con el formato común de la
## reforja; jugar pulsando solo lo señalado llega al final con la garra bien (una rapaz, el tigre y el velocirraptor); el
## objetivo cambia con el estado (sangra, se estresa, se suelta, hay que corregir); y sin tutorial o con «Guiado» apagado no
## hay guiado ni avisos.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_care_state.gd")
const Guide = preload("res://core/lab/claw_care_guide.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 60.0
## Velocidad de una pasada de la persona que juega (mm/s): la de un arrastre normal del ratón.
const STROKE_MM_S := 150.0


## «Pulsa» el objetivo del guiado como lo haría una persona: la orden del mando, la herramienta de la bandeja o el gesto sobre la
## garra donde señala (con el reloj corriendo). Devuelve false si el objetivo no se sabe pulsar.
static func press(st: State, g: Dictionary) -> bool:
	var act: Dictionary = g.get("act", {})
	var op := String(act.get("op", ""))
	var args: Array = act.get("args", [])
	match op:
		"":
			return false
		"esperar":
			_wait(st, float(args[0]) if not args.is_empty() else 1.0)
		"gesto":
			_gesture(st, act)
		"pieza":
			return false
		_:
			if not st.has_method(op):
				return false
			st.callv(op, args)
			st.tick(FRAME)
	return true


static func _wait(st: State, secs: float) -> void:
	var left := secs
	while left > 1e-9:
		var dt := minf(left, 0.25)
		st.tick(dt)
		left -= dt


static func _gesture(st: State, act: Dictionary) -> void:
	var s0 := float(act.s_mm)
	match String(act.kind):
		"lima":
			var along := float(act.along_mm)
			var n := maxi(int(ceilf(along / STROKE_MM_S / FRAME)), 3)
			st.press_on(s0)
			for i in n:
				st.drag(along / float(n), along / float(n), s0, FRAME)
				st.tick(FRAME)
			st.release()
		"corte":
			_hold(st, s0, State.CLIP_CLOSE_S + 0.1)
		"presion", "torno":
			_hold(st, s0, float(act.secs))
		_:
			st.press_on(s0)
			st.tick(FRAME)
			st.release()


static func _hold(st: State, s0: float, secs: float) -> void:
	st.press_on(s0)
	for i in int(ceilf(secs / FRAME)):
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


## Juega pulsando solo lo que señala el guiado hasta que se termina (o hasta max_presses). Devuelve los objetivos pulsados.
static func play(st: State, max_presses: int = 1500) -> Array:
	var seen: Array = []
	for i in max_presses:
		var g: Dictionary = st.view().guide
		if g.is_empty() or st.finished:
			break
		seen.append(g)
		if not press(st, g):
			break
	return seen


static func _trace(seen: Array, n := 12) -> String:
	var out: Array = []
	for g: Dictionary in seen.slice(maxi(seen.size() - n, 0)):
		out.append("%s [%s] %s · %s" % [String(g.step), String(g.id), String(g.hint), String(g.value)])
	return "\n".join(out)


# ════════ El formato ════════

func test_el_formato_comun_de_la_reforja() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "g-formato" })
	var g: Dictionary = st.view().guide
	for k: String in ["id", "where", "view", "label", "hint", "value"]:
		assert_true(g.has(k), "lleva %s (el formato común)" % k)
	assert_true(String(g.where) in ["scene", "panel"], "dónde: la escena o el panel")
	assert_eq(String(g.id), "sedacion:sujecion", "la rapaz, lo primero: capucha y toalla")
	assert_true(String(g.hint).length() > 5 and String(g.hint).length() <= 60, "un aviso corto: «%s»" % g.hint)
	assert_eq(Guide.make("a", "scene", "garra", "b", "c", "d"), { "id": "a", "where": "scene", "view": "garra", "label": "b", "hint": "c", "value": "d" },
		"make da el formato común")
	assert_eq(String(Guide.GAME.quality), "juego", "los números del guiado que no son física, marcados «juego»")


# ════════ Cada paso de cada animal tiene un objetivo que existe ════════

func test_cada_paso_de_cada_animal_tiene_su_objetivo() -> void:
	var cases: Array = []
	for cid: String in CareData.RAPTOR_IDS:
		cases.append({ "animal": "rapaz", "claw": cid })
	cases.append({ "animal": "tigre" })
	cases.append({ "animal": "oso" })
	cases.append({ "animal": "velociraptor", "model": "reconstruccion" })
	cases.append({ "animal": "velociraptor", "model": "pelicula" })
	assert_eq(cases.size(), 10, "las seis rapaces, el tigre, el oso y los dos velocirraptores")
	# y una garra reforjada (sus pasos son otros: la lima que muerde su material)
	cases.append({ "animal": "tigre", "inlay": "zafiro" })
	for c: Dictionary in cases:
		var st := State.new({ "animal": String(c.animal), "claw": String(c.get("claw", "")), "inlay": String(c.get("inlay", "none")),
			"seed": "g-paso-%s" % String(c.get("claw", c.animal)) })
		if c.has("model"):
			st.set_model(String(c.model))
		var ids := Guide.ids_for(st)
		var what := "%s/%s" % [String(c.animal), String(c.get("claw", c.get("model", c.get("inlay", ""))))]
		# cada proceso del recorrido y los que entran si hace falta, paso a paso
		for pid: String in st.flow() + ["sangrado", "reconstruir", Tutorial.ATTACK_PROCESS]:
			var steps: Array = st.care.tutorial(pid) if pid != Tutorial.ATTACK_PROCESS else Tutorial.steps(String(c.animal), pid)
			for i in steps.size():
				if not st.flow().has(pid):
					st._flow.append(pid)
				st._proc = st.flow().find(pid)
				st._step = i
				var g: Dictionary = st.view().guide
				var sid := String(steps[i].id)
				assert_false(g.is_empty(), "%s %s/%s: con objetivo" % [what, pid, sid])
				if g.is_empty():
					continue
				assert_true(ids.has(String(g.id)), "%s %s/%s: «%s» existe en la escena o en la página" % [what, pid, sid, g.id])
				assert_true(String(g.hint) != "", "%s %s/%s: con su aviso" % [what, pid, sid])
				assert_false(String(g.hint).contains("%"), "%s %s/%s: sin formato a medias: %s" % [what, pid, sid, g.hint])
				assert_false((g.act as Dictionary).is_empty() and String(g.id) != "boton:informe", "%s %s/%s: se sabe qué es pulsarlo" % [what, pid, sid])
				if String(g.where) == "scene" and String(g.kind) == "garra":
					assert_true(float(g.s_mm) >= 0.0 and float(g.s_mm) <= st.care.apex_mm() + 0.5, "%s %s/%s: el punto de la garra, sobre la garra" % [what, pid, sid])
				if String(g.kind) == "herramienta" and String(g.id) != "bandeja":
					assert_true(State.tray_ids().has(String(g.tool)), "%s %s/%s: la herramienta está en la bandeja" % [what, pid, sid])


# ════════ Jugar pulsando solo lo señalado ════════

func _play_case(setup: Dictionary) -> void:
	var st := State.new(setup)
	var seen := play(st)
	var what := String(setup.get("claw", setup.animal))
	var rp := st.care.report()
	assert_true(st.finished, "%s: llega al final pulsando solo lo señalado (%d pulsaciones)\n%s" % [what, seen.size(), _trace(seen)])
	var last := st.process_id() == "terminar" and st._step == st._steps_of("terminar").size() - 1
	assert_true(st.tutorial_done() or last, "%s: el tutorial, entero (%s/%s)" % [what, st.process_id(), str(st.current_step().get("id", ""))])
	assert_true(String(rp.verdict) in ["perfecta", "perfecta_daga"], "%s: la garra, bien: %s (%s)\n%s" % [what, rp.verdict, rp.gradeText, _trace(seen)])
	assert_true(st.halted.is_empty(), "%s: sin sesión parada" % what)
	assert_false(bool(st.care.snapshot().bleeding.active), "%s: no sangra" % what)
	assert_true(float(rp.grade) >= 8.0, "%s: buena nota: %s · %s" % [what, rp.gradeText, str((rp.criteria as Array).map(func(cr: Dictionary) -> String: return String(cr.id)))])
	# cada objetivo pulsado lleva su aviso y su valor con números de js.gd (sin «%» suelto)
	for g: Dictionary in seen:
		assert_false(String(g.value).contains("%s"), "%s: valor bien formado: %s" % [what, g.value])


func test_jugar_lo_senalado_rapaz() -> void:
	_play_case({ "animal": "rapaz", "claw": "halcon", "seed": "g-juega-halcon" })


func test_jugar_lo_senalado_tigre() -> void:
	# el tigre, con un mes sin desgaste: con 90 días le sobran casi 12 mm y afilar la cara del corte lleva cientos de pasadas
	_play_case({ "animal": "tigre", "seed": "g-juega-tigre", "overgrowth_days": 30.0 })


func test_jugar_lo_senalado_velociraptor() -> void:
	_play_case({ "animal": "velociraptor", "seed": "g-juega-raptor" })


# ════════ El objetivo cambia con el estado ════════

func test_si_sangra_el_objetivo_es_parar_la_sangre() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "g-sangra" })
	st.set_sedation("sujecion")
	st.pick("guillotina")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 0.5), State.CLIP_CLOSE_S + 0.1)
	assert_true(bool(st.care.snapshot().bleeding.active), "sangra")
	var g: Dictionary = st.view().guide
	assert_eq(String(g.id), "bandeja:hemostatico", "lo primero: coger el polvo hemostático")
	assert_eq(String(g.reason), "sangra", "porque sangra")
	assert_eq(String(g.view), "general", "la cámara, a la bandeja")
	press(st, g)
	g = st.view().guide
	assert_eq(String(g.id), "garra:herida", "luego, apretar sobre la herida")
	assert_eq(String(g.hint), "Pon el polvo hemostático y aprieta", "con su aviso")
	assert_true(String(g.value).begins_with("faltan ") and String(g.value).ends_with(" s"), "y cuánto falta: %s" % g.value)
	press(st, g)
	assert_false(bool(st.care.snapshot().bleeding.active), "apretando lo que dice, para")
	g = st.view().guide
	assert_eq(String(g.tool), "clorhexidina", "después, desinfectar: %s" % g.id)


func test_si_se_estresa_el_objetivo_es_la_pausa() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "g-estres" })
	st.set_sedation("sujecion")
	st.patient.handled = true
	st.patient.stress = 0.75
	st.tick(FRAME)
	var g: Dictionary = st.view().guide
	assert_eq(String(g.id), "boton:calmar", "estresada: la pausa para calmarla")
	assert_eq(String(g.reason), "estres", "porque se estresa")
	assert_true(String(g.value).begins_with("estrés "), "con su estrés: %s" % g.value)
	press(st, g)
	assert_true(st.patient.resting, "pulsada: en la pausa")
	g = st.view().guide
	assert_eq(String(g.id), "reloj:10", "en la pausa: el reloj ×10 mientras se calma")
	press(st, g)
	for i in 400:
		g = st.view().guide
		if String(g.id) != "boton:calmar" or String(g.act.op) != "esperar":
			break
		press(st, g)
	assert_eq(String(g.id), "boton:calmar", "calmada: seguir trabajando")
	assert_eq(String(g.act.op), "rest", "con «Seguir trabajando»")
	# una rapaz sin sujetar que se estresa: capucha y toalla
	var b := State.new({ "animal": "rapaz", "seed": "g-estres-2" })
	b.patient.handled = true
	b.patient.stress = 0.5
	assert_eq(String(b.view().guide.id), "sedacion:sujecion", "sin sujetar: capucha y toalla")


func test_si_se_suelta_el_objetivo_es_recogerla() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "g-suelta" })
	st.pick("lima_bastarda")
	for k in 400:
		if not st.halted.is_empty():
			break
		var s0 := st.care.apex_mm() - 1.0
		st.press_on(s0)
		for i in 30:
			st.drag(2.0, 2.0, s0, FRAME)
			st.tick(FRAME)
		st.release()
	assert_eq(String(st.halted.get("code", "")), "se_suelta", "sin capucha, se suelta")
	var g: Dictionary = st.view().guide
	assert_eq(String(g.id), "boton:recoger", "se ha soltado: «Recogerla y encapucharla»")
	assert_eq(String(g.reason), "suelta", "porque se ha soltado")
	assert_true(String(g.value).contains("40 %") and String(g.value).contains("juego"), "con el zarpazo del juego: %s" % g.value)
	press(st, g)
	assert_true(st.halted.is_empty() and not st.finished, "recogida: sigue con esta garra")
	assert_eq(String(st.patient.sedation), "sujecion", "encapuchada")
	# un tigre que ataca no se recoge: de nuevo
	var t := State.new({ "animal": "tigre", "seed": "g-ataca" })
	t.pick("lima_fina")
	for k in 2:
		var s1 := t.care.apex_mm() - 1.0
		t.press_on(s1)
		for i in 4:
			t.drag(3.0, 3.0, s1, FRAME)
			t.tick(FRAME)
		t.release()
	assert_eq(String(t.halted.get("code", "")), "ataca", "el tigre sin sedar ataca")
	assert_eq(String(t.view().guide.id), "boton:empezar", "y se empieza de nuevo")


func test_si_hay_que_corregir_lo_dice_y_senala_lo_que_lo_arregla() -> void:
	# una grieta del cortaúñas: la lima gruesa de frente
	var st := State.new({ "animal": "rapaz", "seed": "g-grieta" })
	st.set_sedation("sujecion")
	st.pick("guillotina")
	_hold(st, st.care.apex_mm() - 2.0, State.CLIP_CLOSE_S + 0.1)
	assert_false((st.care.snapshot().damage.splits as Array).is_empty(), "el corte deja una grieta")
	var g: Dictionary = st.view().guide
	assert_eq(String(g.reason), "corrige", "hay que corregir")
	assert_true(String(g.hint).begins_with("Grieta"), "el aviso lo dice: %s" % g.hint)
	assert_eq(String(g.id), "bandeja:lima_bastarda", "y señala la herramienta que lo arregla")
	press(st, g)
	g = st.view().guide
	assert_eq(String(g.id), "mano:angulo", "de frente: el ángulo")
	assert_eq(String(g.value), "90° (de frente)", "a 90°")
	press(st, g)
	g = st.view().guide
	assert_eq(String(g.id), "garra:punta", "y la cara del corte")
	for i in 80:
		g = st.view().guide
		if String(g.reason) != "corrige":
			break
		press(st, g)
	assert_true((st.care.snapshot().damage.splits as Array).is_empty(), "limando lo que dice, la grieta se va")
	# una punta demasiado fina: un toque ligero de frente
	var f := State.new({ "animal": "rapaz", "seed": "g-fina", "tip_start": "aguja" })
	f.set_sedation("sujecion")
	assert_eq(String(f.care.snapshot().shape.verdict), "fina", "la de aguja, demasiado fina")
	g = f.view().guide
	assert_true(String(g.hint).begins_with("Demasiado fina"), "el aviso lo dice: %s" % g.hint)
	assert_eq(String(g.tool), "lima_fina", "con la lima fina")
	for i in 20:
		g = f.view().guide
		if String(g.reason) != "corrige":
			break
		press(f, g)
	assert_true(String(f.care.snapshot().shape.verdict) != "fina", "un toque ligero de frente y deja de ser una aguja")
	# la carne viva cerca en una garra clara (el tigre), cortando de más en «Recortar»: «Para» con su distancia
	var t := State.new({ "animal": "tigre", "seed": "g-cerca" })
	t.set_sedation("anestesia")
	t.tutorial_goto("recortar")
	t.set_humidity("humeda")
	t.pick("tenaza")
	assert_eq(String(t.current_step().id), "poco", "en «Corta un trozo pequeño»")
	# remojada, la grieta del corte no llega a la carne viva si se dejan 5 mm (menos que el grosor de la garra ahí: «cerca»)
	_hold(t, t.care.apex_mm() - (t.care.quick_cover_mm() - 5.0), State.CLIP_CLOSE_S + 0.1)
	var sn := t.care.snapshot()
	assert_true(bool(sn.shape.sign) and not bool(sn.bleeding.active), "el corte deja la carne viva cerca, sin sangrar")
	assert_eq(String(t.process_id()), "recortar", "aún en «Recortar»")
	g = t.view().guide
	assert_true(String(g.hint).begins_with("Para: la carne viva está a "), "el tigre (se ve): «Para» con la distancia: %s" % g.hint)
	assert_true(String(g.value).ends_with(" mm"), "en mm: %s" % g.value)
	assert_eq(String(g.id), "boton:siguiente", "no se quita más largo (ni la grieta de frente): se sigue")
	press(t, g)
	assert_true(String(t.view().guide.hint).begins_with("Para"), "en el paso siguiente de recortar o limar, lo mismo")


func test_la_carne_viva_oculta_no_se_dice() -> void:
	# una garra oscura: el guiado no da la distancia a la carne viva (ni el punto)
	var st := State.new({ "animal": "oso", "seed": "g-oculta" })
	st.set_sedation("anestesia")
	st.tutorial_goto("limar")
	while String(st.current_step().id) != "largo" and String(st.process_id()) == "limar":
		st.tutorial_next()
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() - 1.0), State.CLIP_CLOSE_S + 0.1)
	for i in 30:
		var g: Dictionary = st.view().guide
		var q := Js.to_fixed(st.care.quick_cover_mm(), 1)
		assert_false(String(g.hint).contains(q + " mm") or String(g.value).contains(q + " mm"), "sin la distancia oculta: %s · %s" % [g.hint, g.value])
		if not press(st, g) or st.finished:
			break


# ════════ Sin tutorial, o con «Guiado» apagado ════════

func test_sin_tutorial_o_sin_guiado_no_hay_guiado() -> void:
	var st := State.new({ "animal": "tigre", "seed": "g-apagado" })
	assert_false((st.view().guide as Dictionary).is_empty(), "con el tutorial y el guiado: hay objetivo")
	st.set_guide(false)
	var v := st.view()
	assert_true((v.guide as Dictionary).is_empty(), "«Guiado» apagado: nada")
	assert_false(bool(v.guide_on), "y la vista lo dice")
	st.set_guide(true)
	st.set_tutorial(false)
	v = st.view()
	assert_true((v.guide as Dictionary).is_empty(), "«Tutorial apagado»: nada")
	assert_eq(String(v.hints.highlight), "", "ni zona resaltada en la garra")
	st.set_tutorial(true)
	assert_false((st.view().guide as Dictionary).is_empty(), "y vuelve al activarlo")


## El guiado no cambia nada por sí mismo: pedir la vista no toca el ensayo (solo la pinta).
func test_el_guiado_solo_mira() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "g-mira" })
	st.set_sedation("sujecion")
	var before := st.history.size()
	var s0 := st.serial()
	for i in 5:
		st.view()
	assert_eq(st.history.size(), before, "sin llamadas nuevas al motor")
	assert_eq(st.serial(), s0, "ni cambios en el estado")
