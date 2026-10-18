## La reacción del animal estresado y la lente de la cámara (unidad 5t-A; peticiones 61 y 62 de Eric): las cuatro lentes con
## sus fuentes, lo que deja cada garra con el motor del banco (la tabla del encargo, por lente), las invariantes (más fuerza
## nunca raya menos, una punta más roma nunca raya más hondo, el templado aguanta más que el vidrio, una garra frágil puede
## desconcharse y una de metal no), cuándo salta la reacción (solo por encima del umbral y nunca con la sedación adecuada),
## el estado con su lente y el daño acumulado de la lente (los rayones se quedan, las manchas se limpian, se guarda y se
## recupera). Invariantes donde es física; los números, los de las fichas.
extends "res://tests/case.gd"

const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const Lens = preload("res://core/lab/claw_care_lens.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")

const FRAME := 1.0 / 60.0
const ANIMALS := [["rapaz", "aguila"], ["rapaz", "lechuza"], ["tigre", "tigre"], ["oso", "oso"], ["velociraptor", "velociraptor"]]
const QUALITIES := ["primary", "secondary", "estimate"]


static func _scratches(lens_id: String, animal: Array, inlay: String, intensity: float = 0.5) -> bool:
	var h := Reaction.lens_hit(lens_id, { "animal": animal[0], "claw": animal[1], "inlay": inlay, "intensity": intensity })
	return int(h.scratches) > 0


static func _max_depth(h: Dictionary) -> float:
	var d := 0.0
	for c: Dictionary in h.claws:
		d = maxf(d, float(c.depthUm))
	return d


static func _max_len(h: Dictionary) -> float:
	var d := 0.0
	for c: Dictionary in h.claws:
		d = maxf(d, float(c.lengthMm))
	return d


# ════════ Las lentes ════════

func test_las_cuatro_lentes_con_su_fuente() -> void:
	assert_eq(Reaction.LENS_IDS, ["plastico", "vidrio", "vidrio_templado", "zafiro"], "cuatro lentes")
	var prev_hv := 0.0
	for i in Reaction.LENS_IDS.size():
		var L := Reaction.lens(Reaction.LENS_IDS[i])
		assert_eq(int(L.level), i + 1, "%s: el nivel %d" % [L.id, i + 1])
		assert_true(float(L.hv) >= prev_hv, "%s: de menor a mayor dureza" % L.id)
		prev_hv = float(L.hv)
		for key: String in ["hv", "E", "strength", "nu", "mu", "window"]:
			var d: Dictionary = L.data[key]
			assert_true(String(d.source).length() > 20, "%s/%s: con su fuente" % [L.id, key])
			assert_true(String(d.quality) in QUALITIES, "%s/%s: con su calidad (%s)" % [L.id, key, d.quality])
			assert_false(String(d.source).contains("res://") or String(d.source).contains(".gd"), "%s/%s: legible" % [L.id, key])
		assert_eq(float(L.data.hv.value), float(L.hv), "%s: la dureza de la ficha es la que usa el motor" % L.id)
		assert_eq(float(L.data.strength.value), float(L.pane.fgk), "%s: y la resistencia" % L.id)
		assert_true(String(L.name).length() > 5 and String(L.fact).length() > 20, "%s: nombre y explicación" % L.id)
	# la tienda: quién raya cada una (el criterio del motor, r ≥ 1,25)
	var ids := func(lid: String) -> Array: return Reaction.scratched_by(lid).map(func(e: Dictionary) -> String: return String(e.id))
	assert_true((ids.call("plastico") as Array).has("none"), "la queratina raya el plástico")
	assert_false((ids.call("vidrio") as Array).has("none") or (ids.call("vidrio") as Array).has("acero"), "ni la queratina ni el acero rayan el vidrio")
	assert_true((ids.call("vidrio") as Array).has("cuarzo"), "el cuarzo sí")
	assert_eq(ids.call("zafiro"), ["moissanita", "diamante"], "el zafiro, solo la moissanita y el diamante")


# ════════ La tabla del encargo, lente a lente ════════

func test_la_tabla_de_cada_lente() -> void:
	for a: Array in ANIMALS:
		# plástico: lo raya todo lo que es al menos 1,25 veces más duro (el oro, el acero…). La queratina de las garras (30-33
		# HV) también; la del oso, la más blanda del banco (26 HV, r = 1,18), solo lo marca (dureza parecida: mancha)
		for inl: String in ["oro", "acero", "titanio", "vidrio", "diamante"]:
			assert_true(_scratches("plastico", a, inl), "%s/%s raya el plástico" % [a[1], inl])
		var kh := float(CareData.claw_entry(String(a[1])).hv)
		assert_eq(_scratches("plastico", a, "none"), kh / float(Reaction.lens("plastico").hv) >= Reaction.R_SCRATCH, "%s: la queratina (%s HV) raya el plástico solo si es 1,25 veces más dura" % [a[1], kh])
		# vidrio y templado: la queratina, el oro, el acero y el titanio no; el strass y el Swarovski tampoco (r ≈ 1); del cuarzo
		# para arriba, sí
		for lid: String in ["vidrio", "vidrio_templado"]:
			for inl: String in ["none", "oro", "acero", "titanio", "vidrio", "swarovski"]:
				assert_false(_scratches(lid, a, inl), "%s/%s no raya el %s" % [a[1], inl, lid])
			for inl: String in ["cuarzo", "circonita", "zafiro", "tungsteno", "moissanita", "diamante"]:
				assert_true(_scratches(lid, a, inl), "%s/%s raya el %s" % [a[1], inl, lid])
		# zafiro: solo la moissanita y el diamante (la circonita no; zafiro contra zafiro, r = 1, tampoco)
		for inl: String in ["none", "acero", "cuarzo", "circonita", "zafiro", "tungsteno"]:
			assert_false(_scratches("zafiro", a, inl), "%s/%s no raya el zafiro" % [a[1], inl])
		for inl: String in ["moissanita", "diamante"]:
			assert_true(_scratches("zafiro", a, inl), "%s/%s raya el zafiro" % [a[1], inl])
	# lo que no raya deja una mancha (y el acero, su trazo gris), con el porqué
	var h := Reaction.lens_hit("vidrio", { "animal": "rapaz", "claw": "aguila", "inlay": "acero", "intensity": 0.3 })
	assert_true((h.claws as Array).all(func(c: Dictionary) -> bool: return String(c.outcome) == "mancha" and String(c.transfer) == "acero"), "el acero en el vidrio: mancha y trazo")
	assert_true(String(h.reason).contains("no raya") and String(h.reason).contains("HV"), "y el porqué: %s" % h.reason)
	assert_true(_scratches("plastico", ["rapaz", "aguila"], "none") and not _scratches("plastico", ["oso", "oso"], "none"), "el águila raya el plástico; el oso, no")
	var k := Reaction.lens_hit("vidrio", { "animal": "rapaz", "claw": "lechuza", "inlay": "none", "intensity": 0.5 })
	assert_true(String(k.reason).begins_with("La queratina, a ~30 HV, no raya"), "la queratina: %s" % k.reason)
	# en el plástico, una garra que corta (Dp > 0,2) lo desgarra
	var p := Reaction.lens_hit("plastico", { "animal": "rapaz", "claw": "aguila", "inlay": "none", "intensity": 0.5 })
	for c: Dictionary in p.claws:
		if bool(c.scratched):
			assert_true(String(c.scratch) in ["rayon", "rayon_hondo", "desgarro"] and float(c.widthUm) > 0.0 and float(c.depthUm) > 0.0, "%s: el rayón con su anchura y su hondura" % c.finger)
			if String(c.mode) == "corte":
				assert_eq(String(c.scratch), "desgarro", "%s: corte en el plástico, desgarro" % c.finger)


# ════════ Invariantes ════════

func test_mas_fuerza_nunca_raya_menos() -> void:
	for a: Array in ANIMALS:
		for inl: String in ["none", "acero", "cuarzo", "diamante"]:
			for lid: String in Reaction.LENS_IDS:
				var prev_d := 0.0
				var prev_l := 0.0
				var prev_rank := 0
				var cracked := false
				for i in range(1, 11):
					var h := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": inl, "intensity": 0.1 * float(i) })
					var d := _max_depth(h)
					var l := _max_len(h)
					var rank := Reaction.OUTCOMES.find(String(h.outcome))
					assert_true(d >= prev_d - 1e-9, "%s/%s/%s: más fuerza, nunca menos hondo (%s < %s)" % [a[1], inl, lid, d, prev_d])
					assert_true(l >= prev_l - 1e-9, "%s/%s/%s: ni más corto" % [a[1], inl, lid])
					assert_true(rank >= prev_rank, "%s/%s/%s: ni un resultado menos grave" % [a[1], inl, lid])
					assert_true(bool(h.cracked) or not cracked, "%s/%s/%s: rajada con menos fuerza, rajada con más" % [a[1], inl, lid])
					prev_d = d
					prev_l = l
					prev_rank = rank
					cracked = bool(h.cracked)


func test_una_punta_mas_roma_nunca_raya_mas_hondo() -> void:
	for lid: String in ["plastico", "vidrio", "zafiro"]:
		for inl: String in ["none", "diamante"]:
			var prev := INF
			for r_um: float in [0.5, 2.0, 10.0, 50.0, 113.0, 300.0, 1000.0]:
				var fingers: Array = []
				for f: String in Reaction.FINGERS.rapaz:
					fingers.append({ "finger": f, "inlay": inl, "tip_um": r_um })
				var h := Reaction.lens_hit(lid, { "animal": "rapaz", "claw": "aguila", "inlay": inl, "intensity": 0.6, "fingers": fingers })
				var d := _max_depth(h)
				assert_true(d <= prev + 1e-9, "%s/%s: con %s µm de punta, nunca más hondo (%s > %s)" % [lid, inl, r_um, d, prev])
				prev = d


func test_el_templado_aguanta_mas_que_el_vidrio_y_el_zafiro_todo() -> void:
	assert_true(float(Reaction.lens_break("vidrio_templado").F) > 2.0 * float(Reaction.lens_break("vidrio").F), "el templado aguanta mucho más que el vidrio")
	for a: Array in ANIMALS:
		for i in range(1, 11):
			var it := 0.1 * float(i)
			var t := Reaction.lens_hit("vidrio_templado", { "animal": a[0], "claw": a[1], "intensity": it })
			var v := Reaction.lens_hit("vidrio", { "animal": a[0], "claw": a[1], "intensity": it })
			assert_true(not bool(t.cracked) or bool(v.cracked), "%s a %s: si se raja el templado, también el vidrio" % [a[1], it])
		var z := Reaction.lens_hit("zafiro", { "animal": a[0], "claw": a[1], "intensity": 1.0 })
		assert_false(bool(z.cracked), "%s: ningún zarpazo raja el zafiro (%s de %s N)" % [a[1], z.peakN, z.crackN])
	# la que se raja, en la garra del golpe
	var g := Reaction.lens_hit("vidrio", { "animal": "tigre", "claw": "tigre", "intensity": 1.0 })
	assert_true(bool(g.cracked) and String(g.outcome) == "grieta" and String(g.crackFinger) == "III", "el tigre raja el vidrio con el dedo III")
	assert_true(String(g.reason).contains("se raja"), "y lo dice: %s" % g.reason)


func test_una_garra_fragil_puede_desconcharse_y_una_de_metal_no() -> void:
	var chipped := false
	for a: Array in ANIMALS:
		for lid: String in Reaction.LENS_IDS:
			var h := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": "vidrio", "intensity": 1.0 })
			chipped = chipped or (h.claws as Array).any(func(c: Dictionary) -> bool: return bool(c.chips))
			for inl: String in ClawFracture.DUCTILE + ["none"]:
				var m := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": inl, "intensity": 1.0 })
				assert_false((m.claws as Array).any(func(c: Dictionary) -> bool: return bool(c.chips)), "%s/%s/%s: no se desconcha" % [a[1], inl, lid])
	assert_true(chipped, "el strass puede desconcharse contra la lente")
	var s := Reaction.lens_hit("zafiro", { "animal": "tigre", "claw": "tigre", "inlay": "vidrio", "intensity": 1.0 })
	assert_true(String(s.reason).contains("desconchado"), "y se dice: %s" % s.reason)


func test_las_garras_que_tocan_y_su_orden() -> void:
	var expect := { "rapaz": 4, "nocturna": 4, "felino": 4, "oso": 5 }
	for a: Array in ANIMALS:
		var h := Reaction.lens_hit("plastico", { "animal": a[0], "claw": a[1], "intensity": 1.0 })
		var kind := String(h.kind)
		var fingers: Array = (h.claws as Array).map(func(c: Dictionary) -> String: return String(c.finger))
		assert_eq(fingers, Reaction.FINGERS[kind], "%s: los dedos de su pata, en orden" % a[1])
		if expect.has(kind):
			assert_eq(int(h.marks), int(expect[kind]), "%s: %d garras tocan" % [a[1], expect[kind]])
		assert_true(float(h.spacingMm) > 0.0 and String(h.spacingQuality) == "dibujo", "%s: la separación de los dedos (dibujo)" % a[1])
	assert_eq(String(Reaction.lens_hit("plastico", { "animal": "rapaz", "claw": "buho" }).kind), "nocturna", "el búho: nocturna")
	var low := Reaction.lens_hit("plastico", { "animal": "velociraptor", "claw": "velociraptor", "intensity": 0.3 })
	var high := Reaction.lens_hit("plastico", { "animal": "velociraptor", "claw": "velociraptor", "intensity": 0.9 })
	assert_eq([int(low.marks), int(high.marks)], [1, 3], "el velocirraptor: la hoz sola y, si llegan, el III y el IV")
	# las fuentes: legibles y con su calidad
	for a: Array in ANIMALS:
		for lid: String in Reaction.LENS_IDS:
			var h := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": "zafiro", "intensity": 0.8 })
			for txt: String in [String(h.reason), String(h.source)]:
				assert_false(txt.contains("res://") or txt.contains(".gd") or txt.contains("MovingCar.") or txt.contains("Physics."), "%s/%s: textos legibles" % [a[1], lid])
			assert_true(String(h.quality) in QUALITIES and String(h.source).length() > 100, "%s/%s: con su fuente y su calidad" % [a[1], lid])


# ════════ Cuándo salta la reacción ════════

## Un paciente tocado con ese estrés, que pasa secs con el reloj.
static func _run(pt: Patient, secs: float) -> void:
	var steps := int(round(secs / FRAME))
	for i in steps:
		pt.count_step(pt.k + 1, 0.0, FRAME)


func test_la_reaccion_solo_por_encima_del_umbral_y_nunca_con_la_sedacion_adecuada() -> void:
	var low := float(Reaction.REACTION.low)
	# la rapaz suelta, tocada: por debajo de «inquieto», nada
	var r := Patient.new("rapaz", "libre", "aguila")
	r.note_handling()
	r.stress = low - 0.05
	_run(r, 60.0)
	assert_eq([r.reaction_seq, r.reaction_warning], [0, false], "por debajo de «inquieto», ni amenaza ni zarpazo")
	assert_eq(r.attack_chance(), 0.0, "y probabilidad 0")
	# al límite y suelta: la primera tirada sale (probabilidad 1); primero la amenaza, y el zarpazo después de warn_s
	r.stress = 1.0
	assert_eq(r.attack_chance(), 1.0, "suelta y al límite: probabilidad 1")
	_run(r, 0.5)
	assert_true(r.reaction_warning and r.reaction_seq == 0, "primero la amenaza")
	_run(r, float(Reaction.REACTION.warn_s))
	assert_eq(r.reaction_seq, 1, "y el zarpazo")
	assert_false(r.reaction_warning, "la amenaza se apaga con el zarpazo")
	var v: Dictionary = r.view().reaction
	assert_eq(String(v.kind), "rapaz", "la rapaz")
	assert_true(float(v.intensity) >= Reaction.INTENSITY_MIN and float(v.intensity) <= 1.0, "con su intensidad (0-1)")
	assert_true(v.has("seq") and v.has("warning") and v.has("lens"), "las claves del contrato")
	# como mucho una cada gap_s
	_run(r, float(Reaction.REACTION.gap_s) - 1.0)
	assert_eq(r.reaction_seq, 1, "no otra antes de %s s" % Reaction.REACTION.gap_s)
	_run(r, 1.0 + float(Reaction.REACTION.roll_s) + float(Reaction.REACTION.warn_s) + 0.2)
	assert_eq(r.reaction_seq, 2, "después, sí")
	# calmarse durante la amenaza la apaga sin zarpazo
	var c := Patient.new("rapaz", "libre", "aguila")
	c.note_handling()
	c.stress = 1.0
	_run(c, 0.5)
	assert_true(c.reaction_warning, "amenaza")
	c.set_sedation("sujecion")
	assert_false(c.reaction_warning, "encapuchada a tiempo: la amenaza se apaga en el acto")
	_run(c, 10.0)
	assert_eq(c.reaction_seq, 0, "y no hay zarpazo")
	# con la sedación adecuada, nunca: la rapaz encapuchada, sedada o anestesiada; el tigre, el oso y el velocirraptor anestesiados
	for case: Array in [["rapaz", "sujecion"], ["rapaz", "sedacion"], ["rapaz", "anestesia"], ["tigre", "anestesia"], ["oso", "anestesia"], ["velociraptor", "anestesia"]]:
		var p := Patient.new(case[0], case[1])
		p.note_handling()
		p.stress = 1.0
		_run(p, 120.0)
		assert_eq([p.reaction_seq, p.reaction_warning], [0, false], "%s con %s: nunca" % case)
		assert_eq(p.attack_chance(), 0.0, "%s con %s: probabilidad 0" % case)
		assert_true(Reaction.adequate_for(case[0], case[1]), "%s con %s: la adecuada" % case)
	# sedado sin la anestesia que pide un animal grande, puede (menos a menudo y con poca fuerza)
	var t := Patient.new("tigre", "sedacion")
	t.note_handling()
	t.stress = 1.0
	assert_true(t.attack_chance() > 0.0 and t.attack_chance() < 0.5, "sedado: menos probable (%s)" % t.attack_chance())
	_run(t, 120.0)
	assert_true(t.reaction_seq >= 1, "el tigre solo sedado acaba revolviéndose")
	assert_eq(String(t.view().reaction.kind), "felino", "felino")
	assert_true(float(t.reaction_intensity) < 0.5, "con poca fuerza (sedado)")
	# sin tocarlo, nunca (está en su percha o en su jaula)
	var u := Patient.new("oso", "libre")
	u.stress = 1.0
	_run(u, 60.0)
	assert_eq(u.reaction_seq, 0, "sin tocarlo, nada")
	assert_eq(u.attack_chance(), 0.0, "sin tocarlo, probabilidad 0")
	assert_eq([Reaction.kind_of("rapaz", "lechuza"), Reaction.kind_of("oso", "oso"), Reaction.kind_of("velociraptor", "velociraptor")], ["nocturna", "oso", "dinosaurio"], "los tipos")


## Cuantos más errores (más estrés), más probable: la probabilidad nunca baja con el estrés ni sube con una sujeción mejor, y
## en el mismo ensayo (la misma semilla) el animal más estresado ataca antes o a la vez. Determinista: dos veces, lo mismo.
func test_la_reaccion_es_mas_probable_cuanto_mas_estresado() -> void:
	var prev := -1.0
	for i in 21:
		var s := 0.05 * i
		var ch := Reaction.chance(s, 1.0)
		assert_true(ch >= prev and ch >= 0.0 and ch <= 1.0, "nunca baja con el estrés (%s → %s)" % [s, ch])
		assert_true(Reaction.chance(s, 0.35) <= ch, "sedado, nunca más probable que suelto")
		prev = ch
	assert_eq(Reaction.chance(float(Reaction.REACTION.low) - 1e-6, 1.0), 0.0, "por debajo de «inquieto», 0")
	var first := func(stress: float) -> float:
		var p := Patient.new("rapaz", "libre", "aguila")
		p.note_handling()
		p.stress = stress
		var steps := 0
		while p.reaction_seq == 0 and steps < int(600.0 / FRAME):
			p.count_step(p.k + 1, 0.0, FRAME)
			steps += 1
		return float(steps) * FRAME
	var t_prev := INF
	for s: float in [0.5, 0.6, 0.7, 0.85, 1.0]:
		var t: float = first.call(s)
		assert_true(t <= t_prev, "más estrés, el primer zarpazo antes o a la vez (%s: %s s, antes %s s)" % [s, t, t_prev])
		t_prev = t
	assert_eq(first.call(0.6), first.call(0.6), "determinista: el mismo ensayo, el mismo segundo")


func test_la_reaccion_en_el_estado_con_su_lente() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "r1" })
	st.pick("lima_fina")
	var s0 := st.care.apex_mm() - 1.0
	st.press_on(s0)
	for i in 4:
		st.drag(3.0, 3.0, s0, FRAME)
		st.tick(FRAME)
	st.release()
	var warned := false
	var guard := 0
	# sigue cogiéndole la garra (sin sujetar, el tiempo quieta ya no la estresa: test_claw_care_guiado)
	st.press_on(s0)
	while int(st.view().animal.reaction.seq) == 0 and guard < 4000 and st.halted.is_empty():
		st.tick(0.1)
		warned = warned or bool(st.view().animal.reaction.warning)
		guard += 1
	var rv: Dictionary = st.view().animal.reaction
	assert_true(warned, "amenaza antes")
	assert_eq(int(rv.seq), 1, "la rapaz suelta y estresada se revuelve")
	assert_eq(String(rv.lens.lens), "plastico", "contra la lente puesta (la de plástico, la de serie)")
	assert_eq((rv.lens.claws as Array).size(), 4, "con sus cuatro garras")
	assert_true(int(rv.lens.scratches) > 0, "la queratina raya el plástico")
	assert_true(String(st.view().notice).contains("se ha revuelto"), "y lo explica: %s" % st.view().notice)
	assert_true((st.view().fx as Array).any(func(e: Dictionary) -> bool: return String(e.kind) == "reaction"), "con su efecto para la escena")
	# la escena apunta los trazos: los rayones se quedan en la lente
	var traces := {}
	for c: Dictionary in rv.lens.claws:
		traces[String(c.finger)] = [Vector2(0.2, 0.3), Vector2(0.5, 0.6)]
	assert_eq(st.lens_record(99, traces), [], "un zarpazo que no es el último no se apunta")
	var ids := st.lens_record(int(rv.seq), traces)
	assert_true(ids.size() >= int(rv.lens.scratches), "apuntados")
	var lv: Dictionary = st.view().lens
	assert_true((lv.scratches as Array).size() >= 1 and float(lv.obscuration) > 0.0 and String(lv.obscurationQuality) == "juego", "la lente rayada se ve peor (índice de juego)")
	st.lens_clean()
	assert_eq((st.view().lens.scratches as Array).size(), (lv.scratches as Array).size(), "el paño no quita los rayones")
	# la lente es de la cámara: empezar de nuevo no la cambia
	st.restart()
	assert_eq((st.view().lens.scratches as Array).size(), (lv.scratches as Array).size(), "empezar de nuevo no cambia la lente")
	st.lens_mount("zafiro")
	assert_true(String(st.view().lens.lens) == "zafiro" and (st.view().lens.scratches as Array).is_empty(), "una lente nueva, sin rayones")
	# encapuchada, nunca
	var h := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "r2", "sedation": "sujecion" })
	h.pick("lima_fina")
	h.press_on(h.care.apex_mm() - 1.0)
	h.release()
	h.patient.stress = 1.0
	for i in 600:
		h.tick(0.1)
	assert_eq(int(h.view().animal.reaction.seq), 0, "encapuchada, no se revuelve")


# ════════ El daño acumulado de la lente ════════

func test_la_lente_acumula_los_rayones_y_se_guarda() -> void:
	var L := Lens.new("vidrio")
	assert_eq(L.obscuration(), 0.0, "nueva: se ve entera")
	var prev := 0.0
	for i in 12:
		L.add_scratch("rayon_hondo", [Vector2(0.1, 0.1 + 0.05 * i), Vector2(0.9, 0.2 + 0.05 * i)], 300.0, 60.0, "II", "cuarzo", 1)
		assert_true(L.obscuration() >= prev and L.obscuration() <= 1.0, "cada rayón, nunca se ve mejor")
		prev = L.obscuration()
	L.add_scratch("grieta", [Vector2(0.5, 0.5)], 0.0, 0.0, "III", "none", 2)
	assert_true(L.obscuration() > prev, "una grieta tapa más")
	L.add_smudge([Vector2(0.3, 0.3), Vector2(0.4, 0.4)], "I", "acero", "acero", 3)
	var n_scr := L.scratches.size()
	assert_eq(L.clean(), 1, "el paño quita la mancha")
	assert_eq(L.scratches.size(), n_scr, "y deja los rayones")
	assert_false(L.add_scratch("mancha", [Vector2(0.1, 0.1)], 1.0, 1.0) > 0, "un tipo que no es un rayón no se apunta")
	assert_false(L.add_scratch("rayon", [], 1.0, 1.0) > 0, "ni un trazo vacío")
	for i in 30:
		L.add_scratch("desgarro", [Vector2(0.0, 0.03 * i), Vector2(1.0, 0.03 * i)], 2000.0, 1500.0)
	assert_true(L.warning() != "", "muy rayada, avisa: %s" % L.warning())
	# guardar y recuperar da lo mismo
	L.add_smudge([[0.2, 0.2], [0.25, 0.3]], "IV")
	var d := L.to_dict()
	var M := Lens.new()
	assert_true(M.from_dict(d), "se recupera")
	assert_eq(M.lens_id, "vidrio", "la misma lente")
	assert_eq(M.to_dict(), d, "con los mismos rayones y manchas")
	assert_near(M.obscuration(), L.obscuration(), 1e-12, 0.0, "y lo mismo de rayada")
	var id_next := M.add_scratch("rayon", [Vector2(0.1, 0.1), Vector2(0.2, 0.2)], 10.0, 1.0)
	assert_true(id_next > int(d.next_id) - 1, "los ids siguen después de los guardados")
	# un archivo roto no rompe nada
	var B := Lens.new("zafiro")
	assert_false(B.from_dict("basura"), "basura: no")
	assert_true(B.lens_id == "plastico" and B.scratches.is_empty(), "queda una de plástico nueva")
	assert_true(B.from_dict({ "lens": "lente_rara", "scratches": [{ "kind": "rayon", "trace": "x" }, 7, { "kind": "rayon", "trace": [[0.1, 0.2], [0.3, 0.4]], "widthUm": "w" }], "smudges": "no" }), "un diccionario viejo o roto")
	assert_eq(B.lens_id, "plastico", "una lente desconocida es la de plástico")
	assert_eq(B.scratches.size(), 1, "solo lo que se entiende")


## Cada animal, lo peligroso que es para la lente, de la física de sus garras (no un número nuevo): rank cuenta las lentes que
## daña con toda su fuerza, coincide con lens_hit y el texto lo dice; un tigre, un oso o un velocirraptor nunca son menos
## peligrosos que una rapaz pequeña, y una lente más dura nunca sale peor parada por rayones que una más blanda.
func test_cada_animal_su_peligro_para_la_lente() -> void:
	var small := Reaction.danger_of("rapaz", "halcon")
	for case: Array in [["rapaz", "aguila"], ["rapaz", "halcon"], ["rapaz", "buho"], ["tigre", "tigre"], ["oso", "oso"], ["velociraptor", "velociraptor"]]:
		var d := Reaction.danger_of(case[0], case[1])
		assert_true(int(d.rank) >= 0 and int(d.rank) <= 4, "%s: rank 0-4" % case[1])
		var n := 0
		var prev_scr := 99
		for id: String in Reaction.LENS_IDS:
			var e: Dictionary = d.lenses[id]
			var h := Reaction.lens_hit(id, { "animal": case[0], "claw": case[1], "intensity": 1.0 })
			assert_eq([bool(e.cracked), int(e.scratches)], [bool(h.cracked), int(h.scratches)], "%s contra %s: lo mismo que el zarpazo" % [case[1], id])
			if bool(e.cracked) or int(e.scratches) > 0:
				n += 1
			assert_true(int(e.scratches) <= prev_scr, "%s: la lente %s, más dura, nunca con más rayones" % [case[1], id])
			prev_scr = int(e.scratches)
		assert_eq(int(d.rank), n, "%s: rank, las lentes que daña" % case[1])
		assert_true(String(d.text).contains(String(d.level)), "%s: lo dice (%s)" % [case[1], d.text])
		assert_true(String(d.source) != "" and String(d.quality) != "", "%s: con su fuente" % case[1])
		if case[0] != "rapaz":
			assert_true(int(d.rank) >= int(small.rank), "%s, no menos peligroso que el halcón" % case[1])


## Con la sujeción que pide su especie también puede revolverse, pero solo con mucho estrés y un dolor fuerte, y menos cuanto
## más sedado: encapuchada > sedada > anestesiado (casi nunca). Sin dolor fuerte, nunca.
func test_sedado_solo_con_mucho_dolor_y_anestesiado_casi_nunca() -> void:
	var prev := 1.0
	for sed: String in ["sujecion", "sedacion", "anestesia"]:
		var p := Patient.new("rapaz", sed, "aguila")
		p.note_handling()
		p.stress = 1.0
		p.pain = 0.3
		assert_eq(p.attack_chance(), 0.0, "%s, sin dolor fuerte: nunca" % sed)
		p.pain = 1.0
		var ch := p.attack_chance()
		assert_true(ch > 0.0 and ch < prev, "%s, con mucho dolor: posible y menos que con menos sedación (%s < %s)" % [sed, ch, prev])
		prev = ch
	assert_true(prev <= 0.001 + 1e-12, "anestesiado, casi nunca (%s por tirada)" % prev)
	# el tigre anestesiado con el máximo de estrés y de dolor: casi nunca
	var t := Patient.new("tigre", "anestesia")
	t.note_handling()
	t.stress = 1.0
	t.pain = 1.0
	assert_true(t.attack_chance() <= 0.001 + 1e-12, "el tigre anestesiado, casi nunca (%s)" % t.attack_chance())
	# la rapaz sedada con mucho dolor acaba revolviéndose (rara vez): menos fuerza que suelta
	var r := Patient.new("rapaz", "sedacion", "aguila")
	r.note_handling()
	r.stress = 1.0
	r.pain = 1.0
	_run(r, 900.0)
	assert_true(r.reaction_seq >= 1, "sedada y con mucho dolor, alguna vez se revuelve")
	assert_true(r.reaction_intensity < 0.5, "con poca fuerza (%s)" % r.reaction_intensity)


## La pausa para calmarlo: apaga la amenaza, no se revuelve mientras descansa, el estrés baja (más deprisa encapuchada o
## sedada que suelta) y cualquier acción la acaba. Contar el tiempo de una vez da lo mismo que paso a paso.
func test_la_pausa_le_calma() -> void:
	var r := Patient.new("rapaz", "libre", "aguila")
	r.note_handling()
	r.stress = 1.0
	_run(r, 0.5)
	assert_true(r.reaction_warning, "amenaza")
	r.rest(true)
	assert_false(r.reaction_warning, "en la pausa, la amenaza se apaga")
	assert_eq(r.attack_chance(), 0.0, "y no se revuelve")
	_run(r, 30.0)
	assert_eq(r.reaction_seq, 0, "nada en la pausa")
	assert_near(r.stress, 1.0 - float(Reaction.CALM.libre) * 30.0, 1e-6, 0.0, "el estrés baja con su ritmo (suelta)")
	var free_drop := 1.0 - r.stress
	var h := Patient.new("rapaz", "sujecion", "aguila")
	h.note_handling()
	h.stress = 1.0
	h.rest(true)
	_run(h, 30.0)
	assert_true(1.0 - h.stress > free_drop, "encapuchada se calma antes (%s > %s)" % [1.0 - h.stress, free_drop])
	_run(h, 120.0)
	assert_eq(h.stress, 0.0, "hasta calmarse del todo, nunca por debajo de 0")
	# una acción la acaba
	h.note_handling()
	assert_false(h.resting, "tocarle las garras acaba la pausa")
	var q := Patient.new("rapaz", "sujecion", "aguila")
	q.note_handling()
	q.stress = 0.9
	q.rest(true)
	q.react(0.6)
	assert_false(q.resting, "un dolor también")
	# de una vez = paso a paso
	var a := Patient.new("rapaz", "sujecion", "aguila")
	var b := Patient.new("rapaz", "sujecion", "aguila")
	for x: Patient in [a, b]:
		x.note_handling()
		x.stress = 0.8
		x.rest(true)
	_run(a, 10.0)
	b.count_step(b.k + int(round(10.0 / FRAME)), 0.0, FRAME)
	assert_near(a.stress, b.stress, 1e-9, 0.0, "de una vez, lo mismo que paso a paso")


## El primer ataque mete «Tras un ataque» en el tutorial: parar (la pausa), calmarlo, revisar la sujeción o subir la sedación,
## curar y mirar la lente; acabado, vuelve a donde estaba.
func test_el_primer_ataque_ensenya_a_calmarlo() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "r1" })
	var before := st.process_id()
	st.pick("lima_fina")
	var s0 := st.care.apex_mm() - 1.0
	st.press_on(s0)
	for i in 4:
		st.drag(3.0, 3.0, s0, FRAME)
		st.tick(FRAME)
	st.release()
	var guard := 0
	st.press_on(s0)
	while int(st.view().animal.reaction.seq) == 0 and guard < 4000:
		st.tick(0.1)
		guard += 1
	st.release()
	assert_eq(int(st.view().animal.reaction.seq), 1, "se ha revuelto")
	assert_eq(st.process_id(), "calmar", "el tutorial salta a «Tras un ataque»")
	assert_eq(String(st.current_step().id), "calma_pausa", "primero, parar")
	st.rest(true)
	assert_true(bool(st.view().animal.resting), "la pausa")
	assert_eq(String(st.current_step().id), "calma_capucha", "luego, encapucharla")
	st.set_sedation("sujecion")
	assert_eq(String(st.current_step().id), "calma_espera", "luego, esperar a que se calme")
	guard = 0
	while String(st.current_step().id) == "calma_espera" and guard < 2000:
		st.tick(0.5)
		guard += 1
	assert_true(float(st.view().animal.stress) < float(Reaction.REACTION.low), "calmada (%s)" % st.view().animal.stress)
	assert_eq(String(st.current_step().id), "calma_lente", "sin sangre que curar, a la lente")
	for i in 3:
		st.tutorial_next()
	assert_eq(st.process_id(), before, "acabado, vuelve a donde estaba (%s)" % st.process_id())
	# el segundo ataque ya no lo vuelve a meter
	var n := st.flow().count("calmar")
	assert_eq(n, 1, "una sola vez en el tutorial")


# ════════ Petición del 18-10: la misma lente, varios animales y materiales ════════

const ALL_INLAYS := ["none", "oro", "acero", "titanio", "vidrio", "swarovski", "cuarzo", "circonita", "zafiro", "tungsteno", "moissanita", "diamante"]


## La dureza de la garra con ese material (la queratina de su ficha si no está reforjada).
static func _claw_hv(claw_id: String, inlay: String) -> float:
	if inlay == "none":
		return float(CareData.claw_entry(claw_id).hv)
	return float(Reaction.material_entry(inlay).hv)


## Eric: «si trabajas con lentes de baja calidad y dureza, y estás trabajando con materiales de garra realmente duros, el daño
## podría incluso ser mayor». Con la misma lente, el mismo animal y la misma fuerza, una garra más dura nunca deja un surco
## menos hondo ni menos rayones (por encima de unas veces la dureza de la lente, la garra ya es rígida frente a ella y el
## surco deja de crecer: lo marca la lente, no la garra).
func test_una_garra_mas_dura_nunca_marca_menos_la_misma_lente() -> void:
	for lid: String in Reaction.LENS_IDS:
		for a: Array in ANIMALS:
			var rows: Array = []
			for inl: String in ALL_INLAYS:
				var h := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": inl, "intensity": 0.8 })
				rows.append({ "inl": inl, "hv": _claw_hv(String(a[1]), inl), "d": _max_depth(h), "n": int(h.scratches) })
			rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.hv) < float(y.hv))
			for i in range(1, rows.size()):
				var p: Dictionary = rows[i - 1]
				var q: Dictionary = rows[i]
				if float(q.hv) <= float(p.hv):
					continue
				assert_true(float(q.d) >= float(p.d) - 1e-9, "%s/%s: %s (%s HV) nunca marca menos hondo que %s (%s HV): %s < %s µm" % [lid, a[1], q.inl, q.hv, p.inl, p.hv, q.d, p.d])
				assert_true(int(q.n) >= int(p.n), "%s/%s: %s nunca raya con menos garras que %s" % [lid, a[1], q.inl, p.inl])


## «Cuanto menos de calidad sea, más se tendría que marcar»: el mismo zarpazo (animal, garra, material y fuerza) nunca deja
## menos daño en una lente más blanda: plástico ≥ vidrio ≥ templado ≥ zafiro, en hondura y en garras que rayan.
func test_una_lente_peor_nunca_se_marca_menos_con_el_mismo_zarpazo() -> void:
	var order := ["plastico", "vidrio", "vidrio_templado", "zafiro"]
	for a: Array in ANIMALS:
		for inl: String in ALL_INLAYS:
			var prev_d := INF
			var prev_n := 1 << 30
			for lid: String in order:
				var h := Reaction.lens_hit(lid, { "animal": a[0], "claw": a[1], "inlay": inl, "intensity": 0.8 })
				var d := _max_depth(h)
				assert_true(d <= prev_d + 1e-9, "%s/%s: el %s (más duro) nunca se marca más hondo que la lente anterior: %s > %s µm" % [a[1], inl, lid, d, prev_d])
				assert_true(int(h.scratches) <= prev_n, "%s/%s: ni con más garras en el %s" % [a[1], inl, lid])
				prev_d = d
				prev_n = int(h.scratches)
	# el caso de Eric: lente de plástico y garras de circonita o zafiro, más hondo que con la queratina
	var ker := Reaction.lens_hit("plastico", { "animal": "rapaz", "claw": "aguila", "inlay": "none", "intensity": 0.8 })
	for inl: String in ["circonita", "zafiro"]:
		var hard := Reaction.lens_hit("plastico", { "animal": "rapaz", "claw": "aguila", "inlay": inl, "intensity": 0.8 })
		assert_true(_max_depth(hard) > _max_depth(ker), "plástico: el águila con %s marca más hondo que con queratina (%s > %s µm)" % [inl, _max_depth(hard), _max_depth(ker)])


## La misma lente guarda las marcas de varios zarpazos de animales y materiales distintos, cada una con lo suyo (la garra, su
## material, su anchura y su hondura), y cambiar de animal o de material no la cambia.
func test_la_misma_lente_guarda_las_marcas_de_animales_y_materiales_distintos() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "lente-varios" })
	st.lens_mount("plastico")
	var h1 := Reaction.lens_hit("plastico", { "animal": "rapaz", "claw": "aguila", "inlay": "none", "intensity": 0.8 })
	h1["seq"] = 1
	var traces1 := {}
	for i in (Reaction.FINGERS.rapaz as Array).size():
		traces1[String(Reaction.FINGERS.rapaz[i])] = [Vector2(0.2 + 0.05 * i, 0.2), Vector2(0.3 + 0.05 * i, 0.5)]
	var ids1 := st.lens.record(h1, traces1)
	var after1 := st.lens.obscuration()
	assert_true(ids1.size() > 0, "el águila de queratina marca el plástico")
	# otro animal y otro material: la lente sigue puesta, con sus marcas
	st.set_animal("tigre")
	st.set_inlay("circonita")
	assert_eq(st.lens.lens_id, "plastico", "cambiar de animal no cambia la lente")
	assert_eq(st.lens.scratches.size() + st.lens.smudges.size(), ids1.size(), "ni le quita las marcas")
	var h2 := Reaction.lens_hit("plastico", { "animal": "felino", "claw": "tigre", "inlay": "circonita", "intensity": 0.8 })
	h2["seq"] = 2
	var traces2 := {}
	for i in (Reaction.FINGERS.felino as Array).size():
		traces2[String(Reaction.FINGERS.felino[i])] = [Vector2(0.6, 0.3 + 0.08 * i), Vector2(0.9, 0.35 + 0.08 * i)]
	var ids2 := st.lens.record(h2, traces2)
	assert_true(ids2.size() > 0, "el tigre de circonita también")
	assert_true(st.lens.obscuration() > after1, "y la lente se ve peor que con un solo zarpazo")
	var by_seq := { 1: [], 2: [] }
	for s: Dictionary in st.lens.scratches:
		if by_seq.has(int(s.seq)):
			(by_seq[int(s.seq)] as Array).append(s)
	assert_true((by_seq[1] as Array).all(func(s: Dictionary) -> bool: return String(s.material) == "none"), "las del primero, de queratina")
	assert_true((by_seq[2] as Array).all(func(s: Dictionary) -> bool: return String(s.material) == "circonita"), "las del segundo, de circonita")
	var w1 := (by_seq[1] as Array).filter(func(s: Dictionary) -> bool: return String(s.kind) != "grieta").map(func(s: Dictionary) -> float: return float(s.widthUm))
	var w2 := (by_seq[2] as Array).filter(func(s: Dictionary) -> bool: return String(s.kind) != "grieta").map(func(s: Dictionary) -> float: return float(s.widthUm))
	assert_true(not w1.is_empty() and not w2.is_empty() and w2.max() > w1.max(), "y cada una con su anchura: la del tigre de circonita, más ancha (%s > %s µm)" % [w2.max() if not w2.is_empty() else 0.0, w1.max() if not w1.is_empty() else 0.0])


## Eric (18-10): «cuanto más afilada esté una garra, más peligrosa puede ser para la lente, ya que el arañazo o desgarro puede
## ser mayor». Con el mismo animal, material y lente, unas puntas más finas nunca dan un peligro menor ni un surco menos hondo,
## y el aviso lo dice; el estado lo calcula con las garras de ahora (view().lens_danger).
func test_una_garra_mas_afilada_es_mas_peligrosa_para_la_lente() -> void:
	var prev_rank := 99
	var prev_d := {}
	for r_um: float in [11.0, 57.0, 113.0, 226.0, 517.0]:
		var fingers: Array = []
		for f: String in Reaction.FINGERS.rapaz:
			fingers.append({ "finger": f, "inlay": "diamante", "tip_um": r_um })
		var dg := Reaction.danger_of("rapaz", "aguila", "diamante", fingers)
		assert_true(int(dg.rank) <= prev_rank, "con %s µm, nunca más peligro que con una punta más fina" % r_um)
		prev_rank = int(dg.rank)
		for lid: String in Reaction.LENS_IDS:
			var h := Reaction.lens_hit(lid, { "animal": "rapaz", "claw": "aguila", "inlay": "diamante", "intensity": 1.0, "fingers": fingers })
			var d := _max_depth(h)
			assert_true(d <= float(prev_d.get(lid, INF)) + 1e-9, "%s: con %s µm de punta, nunca más hondo que con una más fina" % [lid, r_um])
			prev_d[lid] = d
	var fine: Array = []
	var blunt: Array = []
	for f: String in Reaction.FINGERS.rapaz:
		fine.append({ "finger": f, "inlay": "none", "tip_um": 11.0 })
		blunt.append({ "finger": f, "inlay": "none", "tip_um": 517.0 })
	assert_true(String(Reaction.danger_of("rapaz", "aguila", "none", fine).text).contains("más afiladas"), "afiladas: lo dice")
	assert_true(String(Reaction.danger_of("rapaz", "aguila", "none", blunt).text).contains("romas"), "romas: también")
	assert_false(String(Reaction.danger_of("rapaz", "aguila").text).contains("afiladas"), "sin garras de ahora, el texto de siempre")
	# en el estado: la pata de ahora con su punta
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "peligro-punta" })
	var v := st.view()
	assert_true(v.has("lens_danger") and int((v.lens_danger as Dictionary).rank) >= 0, "la vista trae el peligro de la pata de ahora")
	st.set_tip_start("aguja")
	var va := st.view()
	assert_true(int((va.lens_danger as Dictionary).rank) >= int((v.lens_danger as Dictionary).rank), "con las puntas de aguja, nunca menos peligro")
	assert_true(String((va.lens_danger as Dictionary).text).contains("más afiladas"), "y lo dice: %s" % (va.lens_danger as Dictionary).text)


## Recoger la rapaz que se ha soltado: un 40 % de las veces (regla del juego, Eric 18-10-2026) suelta un zarpazo que
## puede marcar la lente puesta.
func test_recogerla_tras_soltarse_puede_costar_un_zarpazo() -> void:
	var p := Patient.new("rapaz", "libre", "aguila")
	var hits := 0
	var n := 2000
	for i in n:
		if p.recapture_roll():
			hits += 1
	var f := float(hits) / float(n)
	assert_near(f, float(Reaction.RECAPTURE.chance), 0.0, 0.04, "un %s de las veces (pide 0.4)" % f)
	assert_eq(String(Reaction.RECAPTURE.quality), "juego", "regla del juego, marcada")
	# en la sesión: con zarpazo, su lente calculada y dicho en el aviso; sin él, nada
	var seen := { true: false, false: false }
	for seed: String in ["z1", "z2", "z3", "z4", "z5", "z6", "z7", "z8"]:
		var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": seed })
		st.pick("lima_fina")
		var s0 := st.care.apex_mm() - 1.0
		st.press_on(s0)
		for i in 4:
			st.drag(3.0, 3.0, s0, FRAME)
			st.tick(FRAME)
		st.halted = { "code": "se_suelta", "recoverable": true }
		st.finished = true
		var seq0 := int(st.patient.reaction_seq)
		st.recapture()
		var struck := int(st.patient.reaction_seq) > seq0
		seen[struck] = true
		if struck:
			assert_false(st.patient.reaction_lens.is_empty(), "%s: el zarpazo trae su lente" % seed)
			assert_true(String(st.view().notice).contains("zarpazo"), "%s: y lo dice: %s" % [seed, st.view().notice])
		else:
			assert_false(String(st.view().notice).contains("zarpazo"), "%s: sin zarpazo, no lo dice" % seed)
		assert_eq(st.patient.sedation, "sujecion", "%s: encapuchada después" % seed)
