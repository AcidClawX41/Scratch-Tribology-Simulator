## Cetrería · lo que añade la pasada de física de la 5g al motor (core/lab/claw_care.gd; docs/fisica/cetreria.md §11): dónde
## está el calor, el consejo del calor según la herramienta giratoria usada, probar la punta, el animal compartido entre sus
## garras, la forma en directo, la rotura con su sitio y la superficie que se degrada o se pule con cada pasada.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 60.0


static func _fx(x: float, d := 3) -> String:
	return Js.to_fixed(x, d)


# ════════ Dónde está el calor (lo pidió la 5b) ════════

func test_la_instantanea_dice_donde_esta_el_calor() -> void:
	# en la punta: los nodos van a lo largo de la garra, del extremo vivo a la cara (en el vértice)
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	c.file({ "tool": "torno", "zone": "punta", "angle_deg": 45.0, "force_n": 2.0, "dwell_s": 1.0 })
	var th: Dictionary = c.snapshot().thermal
	assert_eq(String(th.zone), "punta", "la zona: la punta")
	assert_eq(String(th.axis), "largo", "los nodos van a lo largo de la garra")
	assert_near(float(th.sZone), c.apex_mm(), 1e-12, 0.0, "el calor entra por el vértice")
	assert_eq(float(th.dxMm), ClawCare.THERMAL_DX_MM, "cada nodo, a THERMAL_DX_MM")
	var span: PackedFloat64Array = th.spanMm
	var n := (th.cells as PackedFloat64Array).size()
	assert_near(span[1], float(th.sZone), 1e-12, 0.0, "el tramo acaba en la cara")
	assert_near(span[1] - span[0], float(n - 1) * ClawCare.THERMAL_DX_MM, 1e-9, 1e-12, "y empieza n − 1 nodos atrás")
	# en el flanco: los nodos atraviesan la pared y el tramo es el del contacto
	var f := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var at := 12.0
	f.file({ "tool": "torno", "zone": "flanco", "at_mm": at, "length_mm": 3.0, "force_n": 1.0, "dwell_s": 0.5 })
	var tf: Dictionary = f.snapshot().thermal
	assert_eq([String(tf.zone), String(tf.axis)], ["flanco", "pared"], "el flanco, a través de la pared")
	var s_mid := f.apex_mm() - at
	assert_near(float(tf.sZone), s_mid, 1e-9, 1e-9, "el centro del contacto")
	var sp: PackedFloat64Array = tf.spanMm
	assert_near(sp[0], s_mid - 1.5, 1e-9, 1e-9, "el contacto empieza 1,5 mm antes")
	assert_near(sp[1], s_mid + 1.5, 1e-9, 1e-9, "y acaba 1,5 mm después")
	# sin tocar la garra, el calor se queda donde estaba (la escena ya no lo deduce de la última acción)
	f.advance(2.0)
	assert_eq(String(f.snapshot().thermal.zone), "flanco", "al enfriarse, sigue en el flanco")


# ════════ El consejo del calor, con la herramienta giratoria usada (lo pidió la 5c) ════════

## La punta, cortada a 1 mm de la carne viva (si aún no lo está), y la herramienta giratoria apretada contra ella 6 s: el
## calor llega a la carne viva.
static func _overheat(c: ClawCare, tool: String, rpm: float) -> void:
	if c.quick_cover_mm() > 1.1:
		c._cut_to(c.apex_mm() - (c.quick_cover_mm() - 1.0))
	for i in 30:
		c.file({ "tool": tool, "zone": "punta", "angle_deg": 45.0, "force_n": 3.0, "dwell_s": 0.2, "rpm": rpm })


static func _heat_advice(c: ClawCare) -> Variant:
	for a: Dictionary in c.report().advice:
		if String(a.id) == "torno":
			return a
	return null


func test_el_consejo_del_calor_habla_de_la_herramienta_usada() -> void:
	var t := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_overheat(t, "torno", 6500.0)
	var at: Variant = _heat_advice(t)
	assert_true(at != null, "el torno calienta la carne viva: hay consejo del calor (pico %s °C)" % _fx(float(t.snapshot().thermal.peakQuickC), 1))
	if at != null:
		assert_eq(String(at.title), "El torno", "solo el torno")
		assert_true(String(at.text).contains("6500") and not String(at.text).contains("8000"), "a su velocidad más baja: %s" % at.text)
		assert_true(String(at.source).contains("7300-PT"), "con la ficha del torno")
	var g := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_overheat(g, "amoladora", 25000.0)
	var ag: Variant = _heat_advice(g)
	assert_true(ag != null, "la amoladora también")
	if ag != null:
		assert_eq(String(ag.title), "La amoladora", "solo la amoladora")
		assert_true(String(ag.text).contains("8000") and not String(ag.text).contains("6500"), "su velocidad más baja: %s" % ag.text)
		assert_true(String(ag.text).contains(ClawCare.grouped(25000.0)) and String(ag.text).contains("3.1 veces"),
			"a 25 000 rpm corre 3,1 veces más deprisa y calienta otro tanto: %s" % ag.text)
		assert_true(String(ag.source).contains("Lite 7760"), "con su manual")
	var b := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_overheat(b, "torno", 13000.0)
	_overheat(b, "amoladora", 8000.0)
	var ab: Variant = _heat_advice(b)
	if ab != null:
		assert_eq(String(ab.title), "El torno y la amoladora", "las dos")
		assert_true(String(ab.text).contains("6500") and String(ab.text).contains("8000"), "con las dos velocidades más bajas")
		assert_true(String(ab.text).contains("2.0 veces"), "el torno a 13 000 rpm, el doble: %s" % ab.text)
	assert_true(ab != null, "y con las dos")


# ════════ El animal es uno (lo pidió la 5c) ════════

static func _hold(st: State, s0: float, secs: float) -> void:
	st.press_on(s0)
	for i in int(round(secs / FRAME)):
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


static func _crit_ids(rep: Dictionary) -> Array:
	return (rep.criteria as Array).map(func(c: Dictionary) -> String: return String(c.id))


func test_trabajar_otra_garra_no_borra_el_estres_del_animal() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "animal" })
	st.set_sedation("sujecion")
	# un corte en la carne viva duele: el animal se mueve y se estresa
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 0.5), State.CLIP_CLOSE_S + 0.1)
	var a: Dictionary = st.care.snapshot().animal
	assert_true(int(a.moved) >= 1 and float(a.stress) > 0.1, "el corte duele: se mueve (%d) y se estresa (%s)" % [int(a.moved), _fx(float(a.stress))])
	assert_eq(int(a.movedHere), int(a.moved), "por esta garra")
	st.select_claw("izquierda", "II")
	var b: Dictionary = st.care.snapshot().animal
	assert_true(float(b.stress) >= float(a.stress) - 1e-12, "la otra garra ve el estrés del animal (%s ≥ %s)" % [_fx(float(b.stress)), _fx(float(a.stress))])
	assert_eq(int(b.moved), int(a.moved), "y lo que se ha movido")
	assert_eq(int(b.movedHere), 0, "pero no por esta garra")
	assert_false(_crit_ids(st.care.report()).has("se_mueve"), "el informe de esta garra no cuenta lo que dolió la otra")
	st.select_claw("derecha", "III")
	assert_true(_crit_ids(st.care.report()).has("se_mueve"), "el de la que dolió, sí")
	# la sujeción es una: cambiarla desde una garra la cambia en todas
	st.set_sedation("anestesia")
	st.select_claw("izquierda", "II")
	assert_eq(String(st.care.setup().sedation), "anestesia", "la otra garra, con la anestesia del animal")
	assert_eq(String(st.care.snapshot().animal.sedation), "anestesia")


func test_el_reloj_de_la_sujecion_cuenta_una_sola_vez() -> void:
	# el animal que se está manejando (cogida la garra: gripped) suma su estrés con el tiempo; con ocho garras, cada una con
	# su propio reloj de ClawCare, el tiempo cuenta una sola vez
	var patient := Patient.new("rapaz", "sujecion", "aguila")
	patient.handled = true
	patient.gripped = true
	var cares: Array[ClawCare] = []
	for i in 8:
		cares.append(ClawCare.new({ "animal": "rapaz", "sedation": "sujecion" }, patient))
	for c: ClawCare in cares:
		c.advance(5.0)
	var t := cares[0].time_s()
	var rate := float(CareData.SEDATION.sujecion.stress_rate)
	assert_near(float(patient.stress), rate * t, 1e-9, 1e-12,
		"%s s manejado: estrés %s, una sola vez (%s/s); contado en cada garra serían %s" % [_fx(t, 1), _fx(float(patient.stress), 4), _fx(rate, 3), _fx(8.0 * rate * t, 4)])
	# una garra que se pone al día no suma el estrés de un tiempo que el animal ya ha contado
	var before := float(patient.stress)
	cares[3].advance(0.0)
	assert_eq(float(patient.stress), before, "ponerse al día no suma estrés")
	# y si nadie lo toca, el tiempo no le estresa, con cualquier sujeción (Eric, 18-10-2026: «no tan hardcore»)
	for sed: String in ["libre", "sujecion", "sedacion"]:
		var st := State.new({ "animal": "rapaz", "seed": "reloj", "sedation": sed })
		st.pick("lima_fina")
		var s0 := st.care.apex_mm() - 1.0
		st.press_on(s0)
		for i in 4:
			st.drag(3.0, 3.0, s0, FRAME)
			st.tick(FRAME)
		st.release()
		var s1 := float(st.patient.stress)
		for i in 600:
			st.tick(FRAME)
		assert_near(float(st.patient.stress), s1, 0.0, 1e-12, "%s: diez segundos sin tocarlo no le suben el estrés" % sed)


## history repite el ensayo entero: unas ClawCare nuevas, con un animal nuevo compartido, llegan al mismo animal y a las
## mismas garras (la página no hace física por su cuenta).
func test_history_repite_el_ensayo_entero() -> void:
	var st := State.new({ "animal": "tigre", "seed": "historia" })
	st.set_sedation("sedacion")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 1.0), State.CLIP_CLOSE_S + 0.1)
	st.select_claw("trasera_izquierda", "V")
	st.pick("lima_bastarda")
	st.set_angle(24.0)
	for k in 3:
		st.press_on(st.care.apex_mm() - 1.0)
		for i in 12:
			st.drag(2.0, 2.0, 0.0, FRAME)
			st.tick(FRAME)
		st.release()
	st.set_sedation("anestesia")
	st.select_claw("delantera_izquierda", "II")
	st.pick("amoladora")
	st.set_rotary(true)
	_hold(st, st.care.apex_mm() - 0.5, 1.0)
	for i in 120:
		st.tick(FRAME)
	var p0 := Patient.new(String(st.setup.animal), String(st.setup.sedation))
	var cares := {}
	for e: Array in st.history:
		var key := String(e[0])
		if not cares.has(key):
			var parts := key.split("|")
			cares[key] = ClawCare.new(st.care_setup(parts[0], parts[1]), p0)
		_apply_call(cares[key], String(e[1]), e[2])
	assert_true(cares.size() >= 3, "tres garras trabajadas (%d)" % cares.size())
	for key: String in cares:
		var mine: ClawCare = st.care if key == State.slot_key(st.paw, st.digit) else st._slots[key].care
		var a: Dictionary = (cares[key] as ClawCare).snapshot()
		var b: Dictionary = mine.snapshot()
		a.erase("serial")
		b.erase("serial")
		assert_eq(var_to_str(a), var_to_str(b), "%s: la misma garra y el mismo animal" % key)
	assert_eq(var_to_str(p0.view()), var_to_str(st.patient.view()), "el mismo animal")


static func _apply_call(c: ClawCare, method: String, args: Variant) -> void:
	match method:
		"file":
			c.file(args)
		"clip":
			c.clip(args)
		"hemostasis":
			c.hemostasis(args)
		"apply":
			c.apply(args)
		"advance":
			c.advance(float(args))
		"advance_held":
			c.advance_held(float(args))
		"set_sedation":
			c.set_sedation(String(args))
		"set_humidity":
			c.set_humidity(String(args))
		"probe_tip":
			c.probe_tip(args)


# ════════ Probar la punta (lo pidió la 5b) ════════

## Una garra limada con la lima gruesa, de la base a la punta, con una faceta 7° más abierta que la garra (como en la sesión
## bien hecha de test_claw_care.gd): k pasadas, o hasta quitar el sobrante. La faceta deja la punta del radio de la arista:
## una aguja, «afilada como una daga pero frágil».
static func _sharpened(setup: Dictionary, k: int = 300) -> ClawCare:
	var c := ClawCare.new(setup)
	var angle := c.tip_alpha_deg() + 7.0
	var over := c.overgrowth_left_mm()
	for i in k:
		if c.overgrowth_left_mm() <= 0.05 * over:
			break
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": angle, "force_n": 5.0, "travel_mm": 40.0 })
	return c


func test_probar_la_punta_mella_una_aguja_y_no_la_natural() -> void:
	# la natural del águila: prende en la uña y aguanta
	var n := ClawCare.new({ "animal": "rapaz" })
	var rn := n.probe_tip()
	assert_eq(String(rn.verdict), "prende", "la punta natural prende en la uña: %s" % rn.text)
	assert_false(bool(rn.chipped), "y no se mella")
	assert_near(float(rn.lateralN), 0.3 * ClawCare.PROBE_FORCE_N, 1e-12, 0.0, "carga de lado μ·F, con la uña del banco")
	# una aguja de queratina («daga frágil»): al probarla, se mella
	var a := _sharpened({ "animal": "rapaz" })
	assert_eq(String(a.report().verdict), "daga_fragil", "una aguja: daga frágil")
	var apex := a.apex_mm()
	var ra := a.probe_tip()
	assert_true(bool(ra.chipped) and String(ra.verdict) == "mella", "la aguja se mella al probarla: %s" % ra.text)
	assert_true(a.apex_mm() < apex, "y pierde la punta")
	assert_eq(int(a.snapshot().damage.chips), 1, "una mella")
	assert_true(bool(ra.sizeEffect) and float(ra.criticalUm) > 500.0, "la queratina, por debajo de su distancia crítica (%s µm): cota del lado seguro" % _fx(float(ra.criticalUm), 0))
	assert_true(a.events().any(func(e: Dictionary) -> bool: return e.code == "mella"), "con su aviso (el error que explica la página)")
	assert_eq(a.sfx_for("probe", ra), "snap", "suena a mella")
	# roma: resbala
	var b := ClawCare.new({ "animal": "rapaz" })
	for i in 12:
		b.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
	var rb := b.probe_tip()
	assert_eq(String(rb.verdict), "resbala", "la punta roma resbala por la uña: %s" % rb.text)
	assert_eq(b.sfx_for("probe", rb), "slide", "y suena a resbalar")
	# mojada, la queratina es dúctil: la aguja se aplasta en vez de mellarse
	var w := _sharpened({ "animal": "rapaz", "humidity": "humeda" })
	var rw := w.probe_tip()
	assert_true(bool(rw.flattened) and not bool(rw.chipped), "mojada, se aplasta: %s" % rw.text)


## Una punta más afilada nunca aguanta más en la prueba: si una se mella, todas las más finas también (Pattrick et al. 2018).
func test_una_punta_mas_afilada_nunca_aguanta_mas_la_prueba() -> void:
	var prev_r := INF
	var prev_cap := INF
	var chipped_before := false
	for k in [0, 2, 4, 8, 12, 16, 24, 32, 48]:
		var c := _sharpened({ "animal": "rapaz" }, k)
		var r := c.tip_radius_um()
		var res := c.probe_tip()
		assert_true(r <= prev_r + 1e-9, "%d pasadas: la punta nunca engorda (%s µm)" % [k, _fx(r, 1)])
		assert_true(float(res.chipN) <= prev_cap + 1e-12, "%d pasadas: más fina, aguanta lo mismo o menos (%s N)" % [k, _fx(float(res.chipN), 4)])
		if chipped_before:
			assert_true(bool(res.chipped), "%d pasadas: si una más roma se melló, esta también" % k)
		chipped_before = chipped_before or bool(res.chipped)
		prev_r = r
		prev_cap = float(res.chipN)
	assert_true(chipped_before, "la más fina se mella")
	# lo mismo con la fórmula, punta a punta, para cada humedad y cada ángulo
	for hum: String in CareData.HUMIDITY_IDS:
		for alpha: float in [12.0, 15.0, 22.0, 28.0]:
			var last := -INF
			var r_um := 2.0
			while r_um <= 600.0:
				var ev := ClawSharpness.evaluate(ClawSharpness.tip_of(r_um, alpha), ClawCare.keratin_strength_k(hum), 0.15, 0.0)
				assert_true(float(ev.chipN) >= last, "%s, %s°: R = %s µm" % [hum, _fx(alpha, 0), _fx(r_um, 1)])
				last = float(ev.chipN)
				r_um *= 1.3


func test_probar_la_punta_en_la_pagina() -> void:
	var st := State.new({ "animal": "rapaz", "seed": "prueba" })
	st.set_sedation("sujecion")
	st.probe_tip()
	assert_eq(String(st.calls.back()[0]), "probe_tip", "la página llama a ClawCare.probe_tip")
	var v := st.view()
	assert_true(String(v.texts.action).begins_with("La punta prende"), "y lo dice: %s" % v.texts.action)
	assert_true((v.fx as Array).any(func(e: Dictionary) -> bool: return e.kind == "probe"), "con su efecto para la escena")
	var ref := ClawCare.new(st.care_setup(st.paw, st.digit))
	for c: Array in st.calls:
		_apply_call(ref, String(c[0]), c[1])
	var a := ref.snapshot()
	var b := st.care.snapshot()
	a.erase("serial")
	b.erase("serial")
	assert_eq(var_to_str(a), var_to_str(b), "sus llamadas dan la misma garra")
	var tut := Tutorial.steps("rapaz", "afilar")
	assert_true(tut.any(func(s: Dictionary) -> bool: return String(s.id) == "probar"), "el tutorial de dar la punta enseña a probarla")
	assert_true(State.STEP_CONTROLS.has("probar") and State.STEP_HINTS.has("probar"), "con su mando y su zona")


# ════════ La rotura, con su sitio (petición 35) ════════

func test_cada_rotura_dice_donde_y_que_trozo_se_va() -> void:
	# el cortaúñas: el trozo que corta se va, con su forma; y la grieta que raja, a lo largo
	var c := ClawCare.new({ "animal": "rapaz", "humidity": "seca" })
	var apex := c.apex_mm()
	var cut := c.clip({ "tool": "guillotina", "remove_mm": 2.0 })
	var brs: Array = c.snapshot().damage.breaks
	assert_true(brs.size() >= 1, "apuntado")
	var b0: Dictionary = brs[0]
	assert_eq(String(b0.kind), "corte", "el trozo del cortaúñas")
	assert_near(float(b0.sMm), apex - 2.0, 1e-9, 1e-9, "donde se corta, desde la base")
	assert_near(float(b0.pieceMm), 2.0, 1e-9, 1e-9, "el trozo de 2 mm")
	assert_true(bool(b0.falls) and (b0.profile.s as PackedFloat64Array).size() >= 2, "que cae, con su forma")
	assert_near((b0.profile.s as PackedFloat64Array)[0], apex - 2.0, 1e-12, 0.0, "la forma empieza en el corte")
	assert_eq(String(b0.tool), "guillotina", "con la herramienta")
	if float(cut.splitMm) > 0.0:
		var b1: Dictionary = brs[1]
		assert_eq(String(b1.kind), "raja", "la grieta que raja a lo largo")
		assert_near(float(b1.toS) - float(b1.fromS), float(cut.splitMm), 1e-9, 1e-9, "de su largo")
		assert_false(bool(b1.falls), "no se va ningún trozo")
	assert_eq(String(c.snapshot().damage.lastBreak.kind), String((brs.back() as Dictionary).kind), "la última, aparte")
	# rajada hasta la carne viva
	var q := ClawCare.new({ "animal": "rapaz", "humidity": "seca" })
	q.clip({ "tool": "tenaza", "remove_mm": q.quick_cover_mm() - 0.4 })
	assert_true((q.snapshot().damage.breaks as Array).any(func(b: Dictionary) -> bool: return b.kind == "raja_carne" and bool(b.reachesQuick)),
		"la grieta que llega a la carne viva: garra rota")
	# la punta que se mella al probarla
	var a := _sharpened({ "animal": "rapaz" })
	var ap := a.apex_mm()
	a.probe_tip()
	var bm: Dictionary = a.snapshot().damage.lastBreak
	assert_eq(String(bm.kind), "mella", "la mella")
	assert_near(float(bm.toS), ap, 1e-12, 0.0, "el trozo llega hasta la punta de antes")
	assert_near(float(bm.sMm), a.apex_mm(), 1e-12, 0.0, "y se rompe donde queda la punta")
	assert_eq(String(bm.tool), ClawCare.PROBE_TARGET, "al probarla en la uña")
	# el flanco limado hasta la carne viva
	var f := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var at := f.apex_mm() - (float(f.snapshot().claw.quickMm) - 3.0)
	for i in 400:
		f.file({ "tool": "lima_diamante_gruesa", "zone": "flanco", "at_mm": at, "length_mm": 3.0, "force_n": 10.0, "travel_mm": 150.0 })
		if bool(f.snapshot().damage.wallThrough):
			break
	assert_true((f.snapshot().damage.breaks as Array).any(func(b: Dictionary) -> bool: return b.kind == "pared"), "la pared atravesada, con su sitio")
	# una garra de vidrio con una carga enorme de lado: se parte entera por la base
	var g := ClawCare.new({ "animal": "rapaz", "inlay": "vidrio" })
	g.probe_tip({ "force_n": 1.0e6 })
	var bg: Dictionary = g.snapshot().damage.lastBreak
	assert_eq(String(bg.kind), "parte", "partida por la base")
	assert_eq(float(bg.sMm), 0.0, "en la base")


# ════════ La forma en directo (petición 35) ════════

func test_la_forma_en_directo() -> void:
	var c := ClawCare.new({ "animal": "rapaz" })
	assert_eq(String(c.shape().verdict), "larga", "sin tocar: aún larga")
	assert_eq(String(c.snapshot().shape.verdict), "larga", "y la instantánea lo lleva")
	var a := _sharpened({ "animal": "rapaz" })
	assert_eq(String(a.shape().verdict), "fina", "una aguja: demasiado fina")
	assert_eq(String(a.shape().tone), "mal")
	var r := ClawCare.new({ "animal": "rapaz" })
	for i in 12:
		r.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
	assert_eq(String(r.shape().verdict), "roma", "de frente: roma")
	var f := ClawCare.new({ "animal": "rapaz" })
	f.clip({ "tool": "tenaza", "remove_mm": f.overgrowth_left_mm() })
	for i in 2:
		f.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": f.tip_alpha_deg() + 25.0, "force_n": 1.0, "travel_mm": 10.0 })
	var vf := String(f.shape().verdict)
	assert_true(vf in ["facetada", "roma", "fina"], "una faceta muy abierta: %s" % vf)
	if float(f.tip_state().ratio) <= 2.0 and float(f.tip_state().strengthRatio) >= 0.25:
		assert_eq(vf, "facetada", "si la punta va bien, lo que falla es la faceta")
	var q := ClawCare.new({ "animal": "rapaz" })
	q.clip({ "tool": "tenaza", "remove_mm": q.quick_cover_mm() + 0.5 })
	assert_true(String(q.shape().verdict) in ["carne_viva", "rota"], "pasada de la carne viva")
	# en una garra oscura no dice dónde está la carne viva; en una clara, sí
	assert_eq(c.shape().quickCoverMm, null, "la rapaz, oscura: sin la distancia")
	assert_true(ClawCare.new({ "animal": "tigre" }).shape().quickCoverMm != null, "el tigre, clara: con la distancia")
	for v: String in ClawCare.SHAPE_VERDICTS:
		assert_true(String(ClawCare.SHAPE_VERDICTS[v][1]) in ["bien", "aviso", "mal"], "%s: con su tono" % v)


## La forma en directo y el veredicto del informe dicen lo mismo de la forma.
func test_la_forma_y_el_informe_coinciden() -> void:
	var want := { "daga_fragil": "fina", "roma": "roma", "larga": "larga", "perfecta": "correcta", "perfecta_daga": "afilada",
		"corta": "cerca", "corta_sangra": "carne_viva", "rota": "rota" }
	var cases: Array = [ClawCare.new({ "animal": "rapaz" }), _sharpened({ "animal": "rapaz" }), _sharpened({ "animal": "tigre", "sedation": "anestesia" }, 6)]
	var r := ClawCare.new({ "animal": "oso" })
	for i in 30:
		r.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 8.0, "travel_mm": 40.0 })
	cases.append(r)
	var q := ClawCare.new({ "animal": "rapaz" })
	q.clip({ "tool": "tenaza", "remove_mm": q.quick_cover_mm() + 0.5 })
	cases.append(q)
	var seen := 0
	for c: ClawCare in cases:
		var rv := String(c.report().verdict)
		if want.has(rv):
			seen += 1
			assert_eq(String(c.shape().verdict), String(want[rv]), "informe «%s» → forma «%s»" % [rv, want[rv]])
	assert_true(seen >= 4, "casos comparados: %d" % seen)


## Más material quitado de la punta nunca la hace más resistente: ninguna sección de la garra gana radio con ninguna
## acción (su momento resistente, π·σ·r³/4, nunca sube), y afilar la punta (la faceta o los flancos de la punta) nunca
## sube lo que aguanta de lado. Acortarla de frente deja una cara más ancha: más roma (la forma lo dice), no más fina.
func test_quitar_material_nunca_la_hace_mas_resistente() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for aid: String in CareData.ANIMAL_IDS:
		var c := ClawCare.new({ "animal": aid, "sedation": "anestesia" })
		var prof: PackedFloat64Array = c.snapshot().profile.r.duplicate()
		for k in 60:
			match rng.randi() % 5:
				0:
					c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": rng.randf_range(10.0, 90.0), "force_n": rng.randf_range(1.0, 8.0), "travel_mm": 40.0 })
				1:
					c.file({ "tool": "lima_fina", "zone": "flanco", "at_mm": rng.randf_range(0.0, c.apex_mm()), "force_n": rng.randf_range(1.0, 8.0), "travel_mm": 40.0 })
				2:
					c.file({ "tool": "torno", "zone": "punta", "angle_deg": 45.0, "force_n": 2.0, "dwell_s": 0.3 })
				3:
					c.clip({ "tool": "tenaza", "remove_mm": rng.randf_range(0.0, 1.0) })
				4:
					c.probe_tip()
			var now: PackedFloat64Array = c.snapshot().profile.r
			var ps: PackedFloat64Array = c.snapshot().profile.s
			for i in mini(now.size() - 1, prof.size() - 1):
				# las estaciones del perfil (cada 0,5 mm) que siguen existiendo
				assert_true(now[i] <= prof[i] + 1e-12, "%s, paso %d: la sección a %s mm no gana radio" % [aid, k, _fx(ps[i], 1)])
			prof = now.duplicate()
	# afilar la punta nunca sube lo que aguanta de lado
	for aid: String in ["rapaz", "tigre", "oso"]:
		var c2 := ClawCare.new({ "animal": aid, "sedation": "anestesia" })
		c2.clip({ "tool": "tenaza", "remove_mm": c2.overgrowth_left_mm() })
		var prev := INF
		for k in 40:
			if k % 2 == 0:
				c2.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": c2.tip_alpha_deg() + 6.0 if k == 0 else _facet_angle(c2), "force_n": 3.0, "travel_mm": 40.0 })
			else:
				c2.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 5.0, "force_n": 2.0, "travel_mm": 20.0 })
			var cap := float(c2.tip_state().lateralN)
			assert_true(cap <= prev + 1e-12, "%s, pasada %d: afilada, no aguanta más (%s N)" % [aid, k, _fx(cap, 5)])
			prev = cap


## El ángulo de la faceta que ya tiene la garra (para seguir tallándola igual).
static func _facet_angle(c: ClawCare) -> float:
	var f := float(c.tip_state().facetDeg)
	return f if f > 0.0 else c.tip_alpha_deg() + 6.0


# ════════ La superficie de la garra (petición 37) ════════

## Una pasada en el flanco del tigre, a 10 mm de la punta (las rotatorias, 0,5 s; las limas, 40 mm de recorrido).
static func _flank_pass(c: ClawCare, tool: String, force: float = 4.0) -> Dictionary:
	if String(CareData.TOOLS[tool].kind) == "torno":
		return c.file({ "tool": tool, "zone": "flanco", "at_mm": 10.0, "length_mm": 3.0, "force_n": force, "dwell_s": 0.5, "angle_deg": 45.0 })
	return c.file({ "tool": tool, "zone": "flanco", "at_mm": 10.0, "length_mm": 3.0, "force_n": force, "travel_mm": 40.0 })


## Las estaciones del contacto de _flank_pass (mm desde la base): las del centro, lejos de los bordes.
static func _contact(c: ClawCare) -> Array:
	var s_mid := c.apex_mm() - 10.0
	var i0 := int(ceil((s_mid - 1.2) / ClawCare.STATION_MM))
	var i1 := int(floor((s_mid + 1.2) / ClawCare.STATION_MM))
	return range(i0, i1 + 1)


static func _max_in(a: PackedFloat64Array, idx: Array) -> float:
	var m := -INF
	for i: int in idx:
		m = maxf(m, a[i])
	return m


func test_la_superficie_empieza_natural_y_se_raya_donde_se_lima() -> void:
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var sf: Dictionary = c.snapshot().surface
	var n := int(floor(c.apex_mm() / ClawCare.STATION_MM)) + 1
	assert_eq(int(sf.n), n, "una estación cada %s mm hasta la punta" % ClawCare.STATION_MM)
	for k: String in ["ra_um", "burn", "chip", "scratch_deg"]:
		assert_eq((sf[k] as PackedFloat64Array).size(), n, "%s: una columna por estación" % k)
	var ra0 := float(CareData.SURFACE.natural_ra_um.value)
	for x: float in sf.ra_um:
		assert_eq(x, ra0, "la garra natural, con su rugosidad")
	assert_eq(float(sf.raStartUm), ra0)
	_flank_pass(c, "lima_bastarda")
	var sf2: Dictionary = c.snapshot().surface
	var idx := _contact(c)
	for i: int in idx:
		assert_true(float(sf2.ra_um[i]) > ra0, "estación %d: la lima gruesa la raya (%s µm)" % [i, _fx(float(sf2.ra_um[i]), 2)])
		assert_eq(float(sf2.scratch_deg[i]), 0.0, "rayada a lo largo de la garra")
	# lejos del contacto no ha pasado nada
	for i in range(0, 20):
		assert_eq(float(sf2.ra_um[i]), ra0, "estación %d, en la base: igual" % i)
	# el tambor raya al ángulo de la mano
	var t := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_flank_pass(t, "torno", 2.0)
	assert_eq(float(t.snapshot().surface.scratch_deg[_contact(t)[3]]), 45.0, "el torno, a 45°")
	# de frente, la cara nueva de la punta queda rayada de través
	var f := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	f.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 4.0, "travel_mm": 40.0 })
	var sff: Dictionary = f.snapshot().surface
	assert_eq(float(sff.scratch_deg[int(sff.n) - 1]), 90.0, "la cara de la punta, de través")



## Más fina nunca deja más rugosidad: la que deja cada herramienta donde trabaja (raUm), la misma pasada con una más fina de
## su familia; y con la fórmula, a la misma fuerza y en el mismo contacto.
func test_mas_fina_nunca_deja_mas_rugosidad() -> void:
	for family: Array in [["lima_bastarda", "lima_entrefina", "lima_fina"], ["torno", "lija_p180", "lija_p240", "lima_diamante_gruesa", "lima_diamante_fina"]]:
		for force: float in [1.0, 4.0, 9.0]:
			var prev := INF
			for tool: String in family:
				var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
				var ra := float(_flank_pass(c, tool, force).raUm)
				assert_true(ra > 0.0 and ra <= prev + 1e-12, "%s a %s N: %s µm, no más que la anterior de su familia" % [tool, _fx(force, 0), _fx(ra, 2)])
				prev = ra
	# una lima gruesa raya la garra natural (más que los 0,31 µm de una uña); una de diamante fina, no
	var ra0 := float(CareData.SURFACE.natural_ra_um.value)
	assert_true(float(_flank_pass(ClawCare.new({ "animal": "tigre" }), "lima_bastarda").raUm) > 3.0 * ra0, "la bastarda raya")
	assert_true(float(_flank_pass(ClawCare.new({ "animal": "tigre" }), "lima_diamante_fina").raUm) < ra0, "la de diamante fina pule")
	# con la fórmula: el surco crece con el grano y con el diente (menos dientes por cm, más hondo)
	var h := ClawCare.hardness_mpa(30.0, "natural")
	for w: float in [0.2, 0.6, 2.0, 6.0]:
		for f: float in [0.5, 3.0, 10.0]:
			var last := -INF
			for g: float in [9.0, 25.0, 45.0, 57.9, 77.2, 258.0]:
				var ra := ClawCare.pass_ra_um(ClawCare.groove_um({ "element": "grano", "grain_um": g }, f, w, 3.0, h))
				assert_true(ra >= last - 1e-12, "grano de %s µm, %s mm, %s N: %s µm" % [_fx(g, 1), _fx(w, 1), _fx(f, 1), _fx(ra, 3)])
				last = ra
			last = -INF
			for teeth: float in [30.0, 22.0, 18.0, 13.0, 8.0]:
				var ra := ClawCare.pass_ra_um(ClawCare.groove_um({ "element": "diente", "teeth_cm": teeth }, f, w, 3.0, h))
				assert_true(ra >= last - 1e-12, "%s dientes por cm, %s mm, %s N: %s µm" % [_fx(teeth, 0), _fx(w, 1), _fx(f, 1), _fx(ra, 3)])
				last = ra
	# el surco de los granos, el mismo que da el arranque
	var gd := { "element": "grano", "grain_um": 45.0 }
	assert_eq(ClawCare.groove_um(gd, 3.0, 2.0, 3.0, h), float(ClawCare.element_cut(gd, 3.0, 2.0, 3.0, h).depthUm), "grano: la hondura de element_cut")


## La regla de la superficie, sola: next_ra(ra, ra_t, dz) (la rugosidad de antes, la de la herramienta y lo quitado).
func test_la_regla_de_pulir_y_rayar() -> void:
	var levels := [0.02, 0.05, 0.31, 1.0, 3.2, 12.0]
	for ra: float in levels:
		for ra_t: float in levels:
			assert_eq(ClawCare.next_ra(ra, ra_t, 0.0), ra, "%s → %s µm sin quitar nada: igual" % [_fx(ra, 2), _fx(ra_t, 2)])
			var last := ra
			for dz: float in [0.01, 0.1, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 64.0]:
				var got := ClawCare.next_ra(ra, ra_t, dz)
				assert_true(got >= minf(ra, ra_t) - 1e-12 and got <= maxf(ra, ra_t) + 1e-12, "entre las dos (%s µm)" % _fx(got, 3))
				if ra_t >= ra:
					assert_eq(got, ra_t, "una más gruesa la raya enseguida")
				else:
					assert_true(got <= last + 1e-12, "una más fina, cuanto más quita, más lisa")
				last = got
			if ra_t < ra:
				assert_eq(ClawCare.next_ra(ra, ra_t, float(CareData.SURFACE.clear_per_ra.value) * ra), ra_t, "quitada la hondura de los surcos (4·Ra), la de la herramienta")
			# más fina nunca deja más, quite lo que quite
			for ra_t2: float in levels:
				if ra_t2 < ra_t:
					continue
				for dz: float in [0.0, 0.3, 3.0, 50.0]:
					assert_true(ClawCare.next_ra(ra, ra_t, dz) <= ClawCare.next_ra(ra, ra_t2, dz) + 1e-12, "%s µm, con %s o con %s: la más fina, no más" % [_fx(ra, 2), _fx(ra_t, 2), _fx(ra_t2, 2)])


## En la garra: una más fina pule hacia su propia rugosidad a medida que quita; una más gruesa la vuelve a rayar enseguida;
## sin quitar material, la rugosidad no cambia.
func test_pulir_rayar_y_sin_quitar_nada_no_cambia() -> void:
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var rc := _flank_pass(c, "lima_bastarda", 6.0)
	var idx := _contact(c)
	for i: int in idx:
		assert_eq(float(c.snapshot().surface.ra_um[i]), float(rc.raUm), "estación %d: la gruesa la deja con la suya" % i)
	var coarse := float(rc.raUm)
	# la de diamante fina: cada pasada la deja entre la de antes y la suya, y acaba con la suya
	var prev: PackedFloat64Array = c.snapshot().surface.ra_um.duplicate()
	var passes := 0
	var rf := {}
	var done := false
	while passes < 400 and not done:
		rf = _flank_pass(c, "lima_diamante_fina", 2.0)
		passes += 1
		var now: PackedFloat64Array = c.snapshot().surface.ra_um
		done = true
		for i: int in idx:
			var t := float(rf.raUm)
			assert_true(now[i] >= minf(prev[i], t) - 1e-12 and now[i] <= maxf(prev[i], t) + 1e-12, "pasada %d, estación %d: entre la de antes y la de la lima (%s µm)" % [passes, i, _fx(now[i], 3)])
			if absf(now[i] - t) > 1e-9:
				done = false
		prev = now.duplicate()
	assert_true(done, "la fina acaba dejándola con la suya (%d pasadas)" % passes)
	assert_true(passes > 1, "pero no de una pasada: tiene que quitar la hondura de los surcos de la gruesa")
	assert_true(float(rf.raUm) < coarse / 10.0, "y mucho más lisa (%s → %s µm)" % [_fx(coarse, 2), _fx(float(rf.raUm), 3)])
	# la gruesa otra vez: la raya enseguida, de una pasada
	var rc2 := _flank_pass(c, "lima_bastarda", 6.0)
	for i: int in idx:
		assert_eq(float(c.snapshot().surface.ra_um[i]), float(rc2.raUm), "estación %d: una pasada de la gruesa y vuelve a estar rayada" % i)
	# sin quitar material, nada cambia: el tiempo, la crema, el agua, la presión y la prueba de la punta
	var before: Dictionary = c.snapshot().surface.duplicate(true)
	c.advance(20.0)
	c.apply({ "tool": "crema" })
	c.set_humidity("humeda")
	c.set_humidity("natural")
	c.hemostasis({ "tool": "", "pressure_s": 5.0 })
	var pr := c.probe_tip()
	assert_false(bool(pr.chipped), "(la prueba de la punta no la ha mellado)")
	var after: Dictionary = c.snapshot().surface
	for k: String in ["ra_um", "burn", "chip", "scratch_deg"]:
		assert_eq(var_to_str(after[k]), var_to_str(before[k]), "%s: sin quitar nada, igual" % k)
	# una lima que no muerde tampoco: la de acero resbala sobre el zafiro
	var z := ClawCare.new({ "animal": "rapaz", "inlay": "zafiro" })
	var zb: Dictionary = z.snapshot().surface.duplicate(true)
	var rz := z.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 8.0, "travel_mm": 40.0 })
	assert_true(bool(rz.noBite), "(no muerde)")
	assert_eq(var_to_str(z.snapshot().surface), var_to_str(zb), "la superficie del zafiro no cambia")
	assert_eq(float(zb.ra_um[0]), float(CareData.SURFACE.polished_ra_um.value), "una reforjada empieza pulida")


static func _top(a: PackedFloat64Array) -> Array:
	var top := 0.0
	var at := -1
	for i in a.size():
		if a[i] > top:
			top = a[i]
			at = i
	return [top, at]


## El calor quema: el torno apretado en la punta llega al tope del modelo y la superficie se ve quemada allí, no en la base;
## limar a mano, sin calor, quita lo quemado con su capa.
func test_el_calor_quema_y_limar_lo_quita() -> void:
	var t := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var k := 0
	while k < 300 and not bool(t.snapshot().thermal.charred):
		t.file({ "tool": "torno", "zone": "punta", "angle_deg": 45.0, "force_n": 3.0, "dwell_s": 0.1, "rpm": 13000.0 })
		k += 1
	var sn := t.snapshot()
	assert_true(bool(sn.thermal.charred), "apretando el torno en la punta, se quema (%d pasadas de 0,1 s)" % k)
	var burn: PackedFloat64Array = sn.surface.burn
	var top := _top(burn)
	assert_eq(float(top[0]), 1.0, "la superficie, quemada del todo donde llegó al tope")
	assert_true(float(sn.surface.lengthMm) - float(top[1]) * ClawCare.STATION_MM < 5.0, "cerca de la punta (%s mm)" % _fx(float(sn.surface.lengthMm) - float(top[1]) * ClawCare.STATION_MM, 2))
	assert_eq(float(burn[0]), 0.0, "la base, no")
	# sin calor, el quemado no sube; limando a mano encima, baja
	var i_b := int(top[1])
	var at := t.apex_mm() - float(i_b) * ClawCare.STATION_MM
	var prev := burn
	for i in 3:
		var r := t.file({ "tool": "lima_fina", "zone": "flanco", "at_mm": at, "length_mm": 2.0, "force_n": 1.0, "travel_mm": 40.0 })
		assert_eq(float(r.heatW), 0.0, "(a mano, sin calor)")
		assert_true(float(r.removedMm3) > 0.0, "(quita)")
		var now: PackedFloat64Array = t.snapshot().surface.burn
		assert_true(i_b < now.size(), "(la estación sigue ahí)")
		if i_b >= now.size():
			return
		assert_true(now[i_b] < prev[i_b], "pasada %d: limando, lo quemado se va (%s)" % [i, _fx(now[i_b], 3)])
		for j in now.size():
			assert_true(now[j] <= prev[j] + 1e-12, "estación %d: sin calor, no se quema más" % j)
		prev = now


## La herramienta equivocada desconcha: en régimen frágil (más hondo que la hondura crítica de Bifano) la garra de vidrio se
## desconcha y, en dúctil, se pule hasta quitar los desconchones; el acero no desconcha; la queratina limada en contra de las
## capas se deshoja.
func test_la_herramienta_equivocada_desconcha() -> void:
	var g := ClawCare.new({ "animal": "rapaz", "inlay": "vidrio" })
	var rg := g.file({ "tool": "lima_fina", "zone": "flanco", "at_mm": 6.0, "force_n": 4.0, "travel_mm": 40.0 })
	var i_mid := int(round((g.apex_mm() - 6.0) / ClawCare.STATION_MM))
	var e: Dictionary = Catalog.find_by_id(Catalog.INLAYS, "vidrio")
	var dc := ClawCare.ductile_depth_um(float(e.E), float(e.hv), float(ClawFracture.strength("vidrio").kic))
	assert_true(float(rg.raUm) / float(CareData.SURFACE.ra_per_depth.value) > dc, "(el surco de la lima, más hondo que d_c = %s µm)" % _fx(dc, 3))
	assert_eq(float(g.snapshot().surface.chip[i_mid]), 1.0, "el vidrio se desconcha")
	# la de diamante fina, suave: en régimen dúctil, no desconcha y pule hasta quitar los desconchones
	var polished := false
	for k in 300:
		var rp := g.file({ "tool": "lima_diamante_fina", "zone": "flanco", "at_mm": 6.0, "force_n": 2.0, "travel_mm": 40.0 })
		assert_true(float(rp.raUm) / float(CareData.SURFACE.ra_per_depth.value) < dc, "(en régimen dúctil)")
		if float(g.snapshot().surface.chip[i_mid]) == 0.0:
			polished = true
			break
	assert_true(polished, "puliendo en régimen dúctil, los desconchones se van")
	var fresh := ClawCare.new({ "animal": "rapaz", "inlay": "vidrio" })
	fresh.file({ "tool": "lima_diamante_fina", "zone": "flanco", "at_mm": 6.0, "force_n": 2.0, "travel_mm": 40.0 })
	for x: float in fresh.snapshot().surface.chip:
		assert_eq(x, 0.0, "la de diamante fina, sola, no desconcha el vidrio")
	# una garra de acero, con la lima de diamante: dúctil, sin desconchar
	var m := ClawCare.new({ "animal": "rapaz", "inlay": "acero" })
	var rm := m.file({ "tool": "lima_diamante_gruesa", "zone": "flanco", "at_mm": 6.0, "force_n": 4.0, "travel_mm": 40.0 })
	assert_true(float(rm.removedMm3) > 0.0, "(la diamante muerde el acero)")
	for x: float in m.snapshot().surface.chip:
		assert_eq(x, 0.0, "el acero no desconcha")
	# la queratina limada en contra de las capas se deshoja: escamas, que se ven como desconchones
	var kc := ClawCare.new({ "animal": "rapaz" })
	var rk := kc.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 30.0, "travel_mm": 20.0, "direction": "en_contra" })
	assert_true(bool(rk.peeled), "en contra, se deshoja")
	var chips: PackedFloat64Array = kc.snapshot().surface.chip
	assert_eq(float(chips[chips.size() - 1]), 1.0, "y se ve como un desconchón en la punta")
	assert_eq(float(chips[0]), 0.0, "la base, no")
	# Bifano: la misma fórmula que la reforja
	for id: String in ["vidrio", "zafiro", "diamante", "alumina"]:
		var en: Dictionary = Catalog.find_by_id(Catalog.INLAYS, id)
		var st: Dictionary = ClawFracture.strength(id)
		assert_near(ClawCare.ductile_depth_um(float(en.E), float(en.hv), float(st.kic)), ClawForge.ductile_depth_um(float(en.E), float(en.hv), float(st.kic)), 1e-12, 0.0, "%s: d_c de Bifano, el mismo" % id)


## La misma superficie como lista de estaciones (la forma de ClawMaterial.surface_image, de la 5e).
func test_la_superficie_como_lista_de_estaciones() -> void:
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_flank_pass(c, "lima_bastarda")
	var sf: Dictionary = c.snapshot().surface
	var st := c.surface_stations()
	assert_eq(st.size(), int(sf.n), "una por estación")
	for i in st.size():
		var e: Dictionary = st[i]
		for k: String in ["ra_um", "burn", "chip", "scratch_deg"]:
			assert_eq(float(e[k]), float((sf[k] as PackedFloat64Array)[i]), "estación %d: %s" % [i, k])
