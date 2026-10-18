## La reacción del animal y la lente de la cámara en la escena de la cetrería (unidad 5t-B: app/lab/cetreria/reaction/), sin
## ventana, con la fuente de demostración (reaction_demo.gd: el motor de verdad, ClawCareReaction.lens_hit y ClawCareLens):
## una reacción vieja no se repite al abrir la página; con una reacción floja (la sedación que casi basta) el animal solo se
## estremece, sin zarpazo ni rayones; las marcas que se dibujan son las de las garras que tocan la lente (y solo esas), en
## coordenadas de pantalla normalizadas; el paño quita las manchas y no los rayones; las dos opciones de accesibilidad
## (quitar el efecto de la lente y el temblor de la cámara); poner una lente con su daño guardado; el mismo zarpazo da las
## mismas marcas; y el plano entero no crea nodos.
extends "res://tests/case.gd"

const SCENE := "res://app/lab/cetreria/care_3d.tscn"
const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const ReactionDemo = preload("res://app/lab/cetreria/reaction/reaction_demo.gd")
const Keys = preload("res://app/lab/cetreria/reaction/reaction_keys.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const LabSection = preload("res://app/lab/lab_section.tscn")
const Js = preload("res://core/shared/js.gd")
## Presupuesto de un fotograma de la escena durante el zarpazo (ms, el mismo holgado de test_care3d.gd).
const BUDGET_MS := 4.0

const FRAME := 1.0 / 30.0
const VIEWPORT := Vector2i(640, 400)


## La escena en un SubViewport en el árbol, con el animal suelto en la vista del animal; [vp, escena, runner, reacción].
func _host(animal := "tigre", claw := "tigre") -> Array:
	var vp := SubViewport.new()
	vp.size = VIEWPORT
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	var r := Runner.new({ "animal": animal, "claw": claw, "seed": "test-reaccion" })
	r.post("set_sedation", ["libre"])
	r.post("tick", [FRAME])
	s.call("show_view", r.latest())
	s.call("set_view", "animal", true)
	s.call("advance", FRAME)
	var rc: Node = s.call("reaction")
	rc.set("external_lens", true)
	return [vp, s, r, rc]


## Avanza la escena hasta que el plano acaba (o max_s): devuelve los lens_record emitidos [[seq, traces]].
static func _run(s: Node3D, rc: Node, max_s := 6.0) -> Array:
	var recs: Array = []
	var cb := func(seq: int, traces: Dictionary) -> void: recs.append([seq, traces])
	rc.connect("lens_record", cb)
	var t := 0.0
	while t < max_s:
		s.call("advance", FRAME)
		t += FRAME
		if not bool(rc.call("is_playing")) and t > 0.5:
			break
	rc.disconnect("lens_record", cb)
	return recs


func test_una_reaccion_vieja_no_se_repite_y_una_nueva_si() -> void:
	var h := _host()
	var rc: Node = h[3]
	var v: Dictionary = (h[2] as Runner).latest()
	var an: Dictionary = v.get("animal", {})
	assert_true(an.has("reaction"), "el estado da la reacción del animal (view().animal.reaction, contrato 5t-A)")
	var seq0 := int((an.get("reaction", {}) as Dictionary).get("seq", 0))
	assert_eq(int((rc.call("info") as Dictionary).seq), seq0, "la escena toma el seq del estado como punto de partida")
	var demo := ReactionDemo.new()
	demo.seq = seq0 - 1
	var ev := demo.event("tigre", "tigre", "none", 0.9)
	rc.call("trigger_event", ev)
	assert_false(bool(rc.call("is_playing")), "una reacción vieja (el mismo seq) no se repite al abrir la página")
	var ev2 := demo.event("tigre", "tigre", "none", 0.9)
	rc.call("trigger_event", ev2)
	assert_true(bool(rc.call("is_playing")), "una nueva (el seq sube) lanza el zarpazo")
	assert_eq(String((rc.call("info") as Dictionary).kind), "felino", "el del tigre")


## El paciente de verdad (core, claw_care_patient.gd) con mucho dolor durante 30 s, y la escena leyendo su reacción en cada
## paso: con la sujeción que basta para su especie (la anestesia del tigre, la sujeción de la rapaz) nunca hay zarpazo; con
## la que no basta del todo (movilidad 1: el tigre con toalla, la rapaz suelta), sí (tras el aviso). Con el estrés al máximo
## vale también con el disparo por probabilidad de la 5t-A (con movilidad 1 y estrés 1, la probabilidad es 1).
func test_con_la_sujecion_que_basta_no_hay_zarpazo() -> void:
	for c: Array in [["tigre", "tigre", "anestesia", false], ["rapaz", "aguila", "sujecion", false], ["tigre", "tigre", "sujecion", true], ["rapaz", "aguila", "libre", true]]:
		var h := _host(String(c[0]), String(c[1]))
		var s: Node3D = h[1]
		var rc: Node = h[3]
		var pt := Patient.new(String(c[0]), String(c[2]), String(c[1]))
		pt.note_handling()
		rc.call("trigger_event", pt.reaction_view())
		var played := false
		var warned := false
		for k in 900:
			if k % 30 == 0:
				pt.react(0.9)
			pt.count_step(k + 1, pt.stress_rate(), FRAME)
			var rv := pt.reaction_view()
			warned = warned or bool(rv.warning)
			rc.call("trigger_event", rv)
			s.call("advance", FRAME)
			played = played or bool(rc.call("is_playing")) or bool((rc.call("info") as Dictionary).twitch)
		assert_eq(played, bool(c[3]), "%s con %s: %s" % [c[0], c[2], "se revuelve" if c[3] else "ni se revuelve ni se estremece"])
		if bool(c[3]):
			assert_true(warned, "%s con %s: antes, la postura de amenaza" % [c[0], c[2]])


## La pausa para calmarlo (view().animal.resting, 5t-A): entra despacio con la penumbra y la respiración más lenta (más en
## las rapaces), y sale al acabar la pausa, con el animal en su pose de siempre.
func test_la_pausa_para_calmarlo() -> void:
	for c: Array in [["rapaz", "aguila"], ["tigre", "tigre"]]:
		var h := _host(String(c[0]), String(c[1]))
		var s: Node3D = h[1]
		var rc: Node = h[3]
		var v: Dictionary = (h[2] as Runner).latest().duplicate(true)
		(v.animal as Dictionary)["resting"] = true
		v["serial"] = int(v.serial) + 1
		s.call("show_view", v)
		for i in 60:
			s.call("advance", FRAME)
		var info: Dictionary = rc.call("info")
		assert_eq(float(info.rest), 1.0, "%s: en la pausa, la postura tranquila del todo" % c[0])
		assert_true(float(info.dim) > 0.0, "%s: con la luz más baja" % c[0])
		assert_true(float(rc.call("breath_rate")) < 1.0, "%s: y la respiración más lenta" % c[0])
		assert_false(bool(rc.call("is_playing")), "%s: sin zarpazo" % c[0])
		(v.animal as Dictionary)["resting"] = false
		v["serial"] = int(v.serial) + 1
		s.call("show_view", v)
		for i in 60:
			s.call("advance", FRAME)
		info = rc.call("info")
		assert_eq(float(info.rest), 0.0, "%s: al acabar la pausa, vuelve" % c[0])
		assert_eq(float(rc.call("breath_rate")), 1.0, "%s: y respira como siempre" % c[0])


func test_reaccion_floja_solo_un_estremecimiento() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var rc: Node = h[3]
	var demo := ReactionDemo.new()
	var ev := demo.event("tigre", "tigre", "none", Keys.TWITCH_INTENSITY * 0.5)
	var cam: Camera3D = s.call("camera")
	var cam0 := cam.global_transform
	rc.call("play", ev)
	var info: Dictionary = rc.call("info")
	assert_true(bool(info.twitch), "por debajo de la intensidad mínima, se estremece")
	assert_eq(String(info.phase), "idle", "sin plano de zarpazo")
	var recs := _run(s, rc, 1.0)
	info = rc.call("info")
	assert_true(recs.is_empty(), "no apunta rayones en la lente")
	assert_false(bool(info.impacted), "no golpea la lente")
	assert_eq(int((info.lens as Dictionary).scratches), 0, "la lente sigue sin rayones")
	assert_true(cam.global_transform.origin.distance_to(cam0.origin) < 0.05, "la cámara no se va al plano del zarpazo")


func test_las_marcas_son_las_de_las_garras_que_tocan() -> void:
	for c: Array in [["tigre", "tigre", "none", "plastico"], ["rapaz", "aguila", "acero", "plastico"], ["oso", "oso", "diamante", "vidrio"]]:
		var h := _host(String(c[0]), String(c[1]))
		var s: Node3D = h[1]
		var rc: Node = h[3]
		var demo := ReactionDemo.new()
		demo.mount(String(c[3]))
		(rc.get("lens") as Node).call("set_lens", String(c[3]), {})
		var ev := demo.event(String(c[0]), String(c[1]), String(c[2]), 0.9)
		rc.call("play", ev)
		var touching: Array = []
		for cl: Dictionary in ev.lens.claws:
			if String(cl.get("outcome", "nada")) != "nada":
				touching.append(String(cl.finger))
		touching.sort()
		var recs := _run(s, rc)
		assert_eq(recs.size(), 1, "%s: apunta el zarpazo una vez" % c[1])
		if recs.is_empty():
			continue
		assert_eq(int(recs[0][0]), int(ev.seq), "%s: con el seq del evento" % c[1])
		var traces: Dictionary = recs[0][1]
		var keys: Array = traces.keys()
		keys.sort()
		assert_eq(keys, touching, "%s: un trazo por cada garra que toca la lente, y solo esas" % c[1])
		for f: String in traces:
			var tr: Array = traces[f]
			assert_true(tr.size() >= 2, "%s %s: el trazo tiene al menos dos puntos" % [c[1], f])
			for p: Array in tr:
				assert_true(float(p[0]) >= 0.0 and float(p[0]) <= 1.0 and float(p[1]) >= 0.0 and float(p[1]) <= 1.0, "%s %s: en la pantalla (normalizado)" % [c[1], f])
		# lo que el motor apunta vuelve a la lente de la escena
		demo.record(ev, traces)
		var lens: Node = rc.get("lens")
		lens.call("apply_damage", demo.lens.view())
		var li: Dictionary = lens.call("info")
		var v: Dictionary = demo.lens.view()
		var n_cracks := 0
		for sc: Dictionary in v.scratches:
			if String(sc.kind) == "grieta":
				n_cracks += 1
		assert_eq(int(li.scratches) + int(li.cracks), (v.scratches as Array).size(), "%s: la lente pinta lo que guarda el motor" % c[1])
		assert_eq(int(li.cracks), n_cracks, "%s: y las grietas como grietas" % c[1])


## Cada garra que raya dibuja su tramo: tan largo como la parte del zarpazo en que aprieta lo bastante (lengthMm del motor),
## nunca más largo si lengthMm es menor, y la del golpe (Reaction.IMPACT_FINGER) empieza antes; las que no rayan, sin tramo.
func test_cada_garra_su_tramo() -> void:
	var Ctl: GDScript = load("res://app/lab/cetreria/reaction/reaction_controller.gd")
	var fingers := [
		{ "finger": "I", "scratched": true, "lengthMm": 30.0 }, { "finger": "II", "scratched": true, "lengthMm": 12.0 },
		{ "finger": "III", "scratched": true, "lengthMm": 30.0 }, { "finger": "IV", "scratched": false, "outcome": "mancha" },
	]
	var w: Dictionary = Ctl.call("_mark_windows", fingers, "I")
	assert_false(w.has("IV"), "la que solo mancha no tiene tramo de rayón")
	var len_i := float(w.I[1]) - float(w.I[0])
	var len_ii := float(w.II[1]) - float(w.II[0])
	assert_true(len_ii < len_i, "la que aprieta menos tiempo, un tramo más corto")
	assert_true(float(w.I[0]) < float(w.III[0]), "la del golpe empieza antes que las demás")
	for f: String in w:
		assert_true(float(w[f][0]) >= 0.0 and float(w[f][1]) <= 1.0 + 1e-9, "%s: dentro del contacto" % f)


func test_el_pano_quita_las_manchas_y_no_los_rayones() -> void:
	var h := _host()
	var lens: Node = (h[3] as Node).get("lens")
	var saved := {
		"lens": "plastico", "serial": 3, "obscuration": 0.2,
		"scratches": [{ "id": 1, "kind": "rayon", "trace": [[0.2, 0.3], [0.4, 0.5]], "widthUm": 30.0, "depthUm": 2.0, "finger": "II" }],
		"smudges": [{ "id": 2, "trace": [[0.6, 0.6]], "finger": "III" }, { "id": 3, "trace": [[0.3, 0.7]], "finger": "IV" }],
	}
	lens.call("set_lens", "plastico", saved)
	var li: Dictionary = lens.call("info")
	assert_eq([int(li.scratches), int(li.smudges)], [1, 2], "la lente con su daño guardado")
	assert_eq(int(lens.call("clean")), 2, "el paño pasa por dos manchas")
	for i in 40:
		lens.call("advance", FRAME)
	li = lens.call("info")
	assert_eq(int(li.smudges), 0, "las manchas se van")
	assert_eq(int(li.scratches), 1, "el rayón se queda")
	assert_false(bool(li.cleaning), "y el paño acaba")
	lens.call("set_lens", "zafiro", {})
	li = lens.call("info")
	assert_eq([String(li.lens), int(li.scratches)], ["zafiro", 0], "otra lente, nueva")


func test_opciones_de_accesibilidad() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var rc: Node = h[3]
	var lens: Node = rc.get("lens")
	lens.call("set_lens", "plastico", { "lens": "plastico", "serial": 1, "scratches": [{ "id": 1, "kind": "rayon", "trace": [[0.2, 0.3], [0.4, 0.5]] }] })
	lens.call("advance", FRAME)
	assert_true(bool((lens.call("info") as Dictionary).visible), "con daño, el efecto de la lente se ve")
	lens.call("set_effect_enabled", false)
	assert_false(bool((lens.call("info") as Dictionary).visible), "quitar el efecto de la lente lo esconde")
	lens.call("set_effect_enabled", true)
	# sin temblor: la cámara del plano es exactamente la planificada, también justo después del impacto
	rc.set("shake_enabled", false)
	var demo := ReactionDemo.new()
	rc.call("play", demo.event("tigre", "tigre", "none", 1.0))
	var cam: Camera3D = s.call("camera")
	var max_dev := 0.0
	var impacted := false
	for i in 120:
		s.call("advance", FRAME)
		var info: Dictionary = rc.call("info")
		if bool(info.impacted) and String(info.phase) in ["contacto", "recuperacion"]:
			impacted = true
			var want: Transform3D = rc.get("_cam_xf")
			max_dev = maxf(max_dev, (cam.global_transform.basis.z - want.basis.z).length())
	assert_true(impacted, "el zarpazo llega a la lente")
	assert_true(max_dev < 1e-5, "sin temblor de cámara (desviación %s)" % str(max_dev))


func test_el_mismo_zarpazo_da_las_mismas_marcas() -> void:
	var out: Array = []
	for k in 2:
		var h := _host("rapaz", "aguila")
		var demo := ReactionDemo.new()
		var ev := demo.event("rapaz", "aguila", "none", 0.9)
		(h[3] as Node).call("play", ev)
		out.append(_run(h[1], h[3]))
		(h[0] as Node).get_parent().remove_child(h[0])
	assert_eq(str(out[0]), str(out[1]), "determinista: el mismo evento, los mismos trazos")


## Lo que cuesta un fotograma de la escena (advance(), sin el dibujo) en reposo y durante el zarpazo, con la lente rayada.
func test_coste_por_fotograma() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var rc: Node = h[3]
	var idle_us := 0
	for i in 60:
		var t0 := Time.get_ticks_usec()
		s.call("advance", FRAME)
		idle_us += Time.get_ticks_usec() - t0
	var demo := ReactionDemo.new()
	rc.call("play", demo.event("tigre", "tigre", "none", 0.9))
	var n := 0
	var us := 0
	var mx := 0
	while bool(rc.call("is_playing")) and n < 300:
		var t0 := Time.get_ticks_usec()
		s.call("advance", FRAME)
		var d := Time.get_ticks_usec() - t0
		us += d
		mx = maxi(mx, d)
		n += 1
	var idle := float(idle_us) / 60.0 / 1000.0
	var avg := float(us) / float(maxi(n, 1)) / 1000.0
	assert_true(avg < BUDGET_MS, "un fotograma del zarpazo cuesta %s ms de media (presupuesto %s ms)" % [Js.to_fixed(avg, 2), Js.to_fixed(BUDGET_MS, 1)])
	print("    (info) reacción del animal: %s ms de media por fotograma durante el zarpazo (máximo %s ms; en reposo %s ms)" % [Js.to_fixed(avg, 2), Js.to_fixed(float(mx) / 1000.0, 2), Js.to_fixed(idle, 2)])


## Las opciones de accesibilidad de la reacción (quitar el efecto de la lente y el temblor) se guardan en [lab] de los
## ajustes y se recuperan al abrir otra vez la sección.
func test_las_opciones_de_accesibilidad_se_guardan() -> void:
	var cfg := "user://test_cetreria_reaccion.cfg"
	if FileAccess.file_exists(cfg):
		DirAccess.remove_absolute(cfg)
	var s: Control = LabSection.instantiate()
	s.settings_path = cfg
	s.setup()
	var p: Control = s.get("care_page")
	p.call("set_reaction_options", { "lens_fx": false })
	p.emit_signal("reaction_options_changed", (p.get("reaction_options") as Dictionary).duplicate())
	s.free()
	var c := ConfigFile.new()
	assert_eq(c.load(cfg), OK, "hay ajustes")
	assert_eq(c.get_value("lab", "reaction_lens_fx", true), false, "sin el efecto de la lente, guardado en [lab]")
	assert_eq(c.get_value("lab", "reaction_shake", false), true, "con el temblor")
	var t: Control = LabSection.instantiate()
	t.settings_path = cfg
	t.setup()
	var tp: Control = t.get("care_page")
	var o: Dictionary = tp.get("reaction_options")
	assert_eq([bool(o.lens_fx), bool(o.shake)], [false, true], "la vez siguiente, como se dejaron")
	# la probabilidad de que se revuelva (juego), discreta junto a la lente; con 0, no se enseña
	var v: Dictionary = (tp.get("runner") as Runner).latest().duplicate(true)
	(v.animal as Dictionary)["attackChance"] = 0.35
	tp.call("_paint_lens", v)
	var risk: Label = tp.get("lens_risk")
	assert_true(risk.visible and risk.text == "Probabilidad de que se revuelva: 35 % (juego)", "la probabilidad, marcada «juego»: %s" % risk.text)
	(v.animal as Dictionary)["attackChance"] = 0.0
	tp.call("_paint_lens", v)
	assert_false(risk.visible, "sin probabilidad, no se enseña")
	t.free()
	DirAccess.remove_absolute(cfg)


func test_el_plano_no_crea_nodos() -> void:
	var h := _host("velociraptor", "velociraptor")
	var s: Node3D = h[1]
	var rc: Node = h[3]
	var demo := ReactionDemo.new()
	rc.call("play", demo.event("velociraptor", "velociraptor", "none", 0.9))
	s.call("advance", FRAME)
	var n0 := int(s.call("node_count"))
	var recs := _run(s, rc)
	assert_eq(recs.size(), 1, "el zarpazo se apunta")
	assert_eq(int(s.call("node_count")), n0, "los fotogramas del plano no crean nodos")
	var info: Dictionary = rc.call("info")
	assert_true(float(info.slowmo) >= Keys.SLOWMO_MIN and float(info.slowmo) <= 1.0, "la cámara lenta, acotada")
	assert_true(float(info.strike_real_s) > 0.0 and float(info.strike_s) >= float(info.strike_real_s), "el golpe en pantalla dura lo mismo o más que el real")
