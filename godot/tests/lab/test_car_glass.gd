## Las garras en los cristales del coche (unidad 4v, petición de Eric del 18-10: core/lab/car_glass.gd y su uso en
## MovingCar). Se comprueba:
##   - rayar el vidrio pide r ≥ 1,25 (el criterio de la lente de la cetrería): la queratina, el oro, el acero y el titanio
##     nunca lo rayan (mancha o trazo de metal); el cuarzo y lo más duro, sí;
##   - una garra más dura nunca raya menos hondo; más fuerza nunca agrieta menos;
##   - el templado (la luneta, las ventanillas) o entero o estallado, nunca a medias, y si estalla pierde el apoyo y caen
##     trocitos dentro; el laminado agrietado nunca cae;
##   - determinismo.
extends "res://tests/case.gd"

const CarGlass = preload("res://core/lab/car_glass.gd")
const MC = preload("res://core/lab/moving_car.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")

const SOFT := ["none", "oro", "acero", "titanio"]
const HARD := ["cuarzo", "circonita", "zafiro", "tungsteno", "moissanita", "diamante"]


static func _claw(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func _hold(id: String, zone: String, inlay: String) -> Dictionary:
	return MC.setup({ "claw": _claw(id), "target": Catalog.find_by_id(Catalog.TARGETS, "coche"), "zone": zone, "inlay": inlay })


func test_rayar_pide_r_de_1_25() -> void:
	var glass_hv := float(Glazing.WINDSCREEN.hv)
	for id: String in SOFT:
		var hv := 30.0 if id == "none" else float(Catalog.find_by_id(Catalog.INLAYS, id).hv)
		assert_false(CarGlass.scratches(hv, glass_hv), "%s (%s HV) no raya el vidrio" % [id, hv])
		assert_eq(CarGlass.trace_kind(id, hv, glass_hv), "mancha" if id == "none" else "trazo", "lo que deja %s" % id)
	for id: String in HARD:
		var hv := float(Catalog.find_by_id(Catalog.INLAYS, id).hv)
		assert_true(CarGlass.scratches(hv, glass_hv), "%s (%s HV) raya el vidrio" % [id, hv])
		assert_eq(CarGlass.trace_kind(id, hv, glass_hv), "raya")
	# justo por debajo y por encima del umbral
	assert_false(CarGlass.scratches(glass_hv * 1.2499, glass_hv))
	assert_true(CarGlass.scratches(glass_hv * 1.25, glass_hv))


func test_la_queratina_nunca_raya_el_parabrisas() -> void:
	for id: String in ["aguila", "arpia", "halcon", "buho", "tigre", "oso", "velociraptor", "velociraptor_pelicula"]:
		var s := _hold(id, "parabrisas", "none")
		if not bool(s.get("ok", false)):
			continue
		assert_eq(float(s.scratch.depthUm), 0.0, "%s: la queratina no raya el vidrio" % id)
		assert_eq(String(s.scratch.get("trace", "")), "mancha", "%s: deja una mancha" % id)


func test_lo_blando_deja_trazo_y_lo_duro_raya() -> void:
	for id: String in SOFT.slice(1) + ["vidrio", "swarovski"]:
		var s := _hold("tigre", "parabrisas", id)
		assert_eq(float(s.scratch.depthUm), 0.0, "%s no raya el parabrisas (r < 1,25)" % id)
	for id: String in HARD:
		var s := _hold("tigre", "parabrisas", id)
		assert_true(float(s.scratch.depthUm) > 0.0, "%s raya el parabrisas" % id)
		assert_eq(String(s.scratch.trace), "raya")


func test_una_garra_mas_dura_nunca_raya_menos_hondo() -> void:
	var order: Array = HARD.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return float(Catalog.find_by_id(Catalog.INLAYS, a).hv) < float(Catalog.find_by_id(Catalog.INLAYS, b).hv))
	for animal: String in ["aguila", "tigre", "oso"]:
		var last := -1.0
		for id: String in order:
			var d := float(_hold(animal, "parabrisas", id).scratch.depthUm)
			assert_true(d >= last - 1e-9, "%s: %s raya %s µm, no menos que la anterior (%s)" % [animal, id, d, last])
			last = d


func test_mas_fuerza_nunca_agrieta_menos() -> void:
	var tip := { "hv": 10000.0, "tanA": 0.25 }
	for w: Dictionary in [CarGlass.rear_window(), Glazing.SIDE_WINDOW]:
		var was := false
		for k in 40:
			var f := 20.0 * float(k)
			var r := CarGlass.tempered_hold(w, f, f, 30.0, tip)
			assert_true(not was or bool(r.shattered), "%s: con %s N no deja de estallar" % [w.id, f])
			was = bool(r.shattered)
	var cracked := false
	for k in 40:
		var f := 50.0 * float(k)
		var sh := MC.windshield_load(f, 30.0, false)
		assert_true(not cracked or bool(sh.cracked), "parabrisas: con %s N no deja de agrietarse" % f)
		cracked = bool(sh.cracked)
	var a := CarGlass.view_loss(true, false, 2, 4, 0.5)
	var b := CarGlass.view_loss(true, false, 4, 4, 0.5)
	assert_true(float(b.frac) >= float(a.frac), "más apoyos que lo parten nunca tapan menos")


func test_el_templado_entero_o_estallado() -> void:
	for w: Dictionary in [CarGlass.rear_window(), Glazing.SIDE_WINDOW]:
		for hv: float in [30.0, 200.0, 1100.0, 10000.0]:
			for f: float in [10.0, 300.0, 3000.0]:
				var r := CarGlass.tempered_hold(w, f, f, 25.0, { "hv": hv, "tanA": 0.3 })
				assert_true(r.shattered is bool, "estalla o no, sin término medio")
				assert_eq(bool(r.losesSupport), bool(r.shattered), "si estalla, pierde el apoyo")
				assert_eq(bool(r.shardsInside), bool(r.shattered), "si estalla, caen trocitos dentro")
				if hv < float(w.hv):
					assert_true(r.cause != "grieta", "una punta más blanda que el vidrio no abre la grieta del temple")
	var rw := CarGlass.rear_window()
	assert_eq(String(rw.id), "luneta")
	assert_true(String(rw.source).contains("ESTIMACIÓN"), "la luneta, marcada como estimación")


func test_el_laminado_agrietado_no_cae() -> void:
	var s := _hold("oso", "parabrisas", "diamante")
	assert_true(s.windshield != null, "el oso sobre el parabrisas")
	assert_false(s.windshield.has("falls"), "el laminado no tiene caída: el PVB lo sujeta")
	var vl := CarGlass.view_loss(false, false, 4, 4, 0.9)
	assert_eq(float(vl.frac), 0.0, "sin grieta no tapa nada")
	var vc := CarGlass.view_loss(true, true, 4, 4, 0.9)
	assert_true(float(vc.frac) > 0.0 and float(vc.frac) <= 1.0, "agrietado, tapa algo y nunca más que todo")
	assert_eq(String(vc.quality), "estimate")


func test_determinismo() -> void:
	var a := _hold("tigre", "parabrisas", "zafiro")
	var b := _hold("tigre", "parabrisas", "zafiro")
	assert_eq(var_to_str(a.scratch), var_to_str(b.scratch), "las mismas marcas")
	var w := CarGlass.rear_window()
	assert_eq(var_to_str(CarGlass.tempered_hold(w, 400.0, 400.0, 30.0, { "hv": 2000.0, "tanA": 0.3 })),
		var_to_str(CarGlass.tempered_hold(w, 400.0, 400.0, 30.0, { "hv": 2000.0, "tanA": 0.3 })))


# ════════ La integración (unidad 4v, calle G) ════════

const MCS = preload("res://core/lab/moving_car_state.gd")
const CSM = preload("res://core/lab/car_speed_marks.gd")
const ALL_INLAYS := ["none", "oro", "acero", "titanio", "vidrio", "swarovski", "cuarzo", "circonita", "zafiro", "tungsteno", "moissanita", "diamante"]


## Los animales que se quedan encima (los de MovingCar.BODIES salvo el casuario, que solo patea).
static func _holders() -> Array:
	var out: Array = []
	for id: String in MC.BODIES:
		if MC.supports_hold(_claw(id)):
			out.append(id)
	return out


static func _scen(id: String, zone: String, inlay: String, defense := false) -> Dictionary:
	return MC.setup({ "claw": _claw(id), "target": Catalog.find_by_id(Catalog.TARGETS, "coche"), "zone": zone, "inlay": inlay,
		"defense": defense })


static func _hit(id: String, zone: String, inlay := "none") -> Dictionary:
	return MC.impact({ "claw": _claw(id), "target": Catalog.find_by_id(Catalog.TARGETS, "coche"), "zone": zone, "inlay": inlay,
		"v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5 })


static func _st(id: String, zone: String, inlay: String, v: float, defense := false) -> MCS:
	var st := MCS.new(_claw(id), Catalog.find_by_id(Catalog.TARGETS, "coche"))
	st.threaded = false
	st.set_zone(zone)
	st.set_inlay(inlay)
	st.set_defense(defense)
	st.set_speed(v)
	st.finish()
	return st


static func _hv(id: String) -> float:
	return 30.0 if id == "none" else float(Catalog.find_by_id(Catalog.INLAYS, id).hv)


static func _rows(st: MCS) -> Dictionary:
	var out := {}
	for r: Array in st.hold_rows():
		out[String(r[0])] = String(r[1])
	return out


func test_la_luneta_es_un_sitio_donde_quedarse() -> void:
	var z: Dictionary = MC.ZONES.luneta
	assert_eq(String(z.surface), "vidrio", "la luneta es de vidrio")
	assert_true(bool(z.tempered), "templado, como las ventanillas")
	for k: String in ["slope_deg", "slide_m", "draw"]:
		assert_true(String(z.sources[k].quality) in ["primary", "secondary", "estimate", "dibujo"], "%s con su calidad" % k)
		assert_true(String(z.sources[k].source) != "", "%s con su fuente" % k)
	for id: String in _holders():
		assert_true(MC.zones_for(_claw(id)).has("luneta"), "%s puede ponerse en la luneta" % id)
	var rw := CarGlass.rear_window()
	assert_eq(float(rw.pane.fgk), float(Glazing.SIDE_WINDOW.pane.fgk), "la resistencia del templado de las ventanillas")


func test_la_queratina_nunca_raya_ningun_cristal() -> void:
	for id: String in _holders():
		if MC.is_film(_claw(id)):
			continue  # la garra de película es ficción (y lo dice)
		for zone: String in ["parabrisas", "luneta"]:
			for dfn: bool in [false, true]:
				var s := _scen(id, zone, "none", dfn)
				if not bool(s.get("ok", false)):
					continue
				assert_eq(float(s.scratch.depthUm), 0.0, "%s en %s: la queratina no raya el vidrio" % [id, zone])
				if s.defense != null:
					assert_eq(float(s.defense.tear.depthUm), 0.0, "%s asustado en %s: tampoco" % [id, zone])
				var rw: Variant = s.get("rearWindow")
				if rw != null:
					assert_true(rw.cause != "grieta", "%s: la queratina no abre la grieta del temple" % id)
					# y ningún peso del catálogo la parte al flexar (lo dice la guía, §24.4)
					assert_false(bool(rw.shattered), "%s%s: con queratina la luneta aguanta entera" % [id, " asustado" if dfn else ""])
	for id: String in ["aguila", "tigre", "oso", "velociraptor"]:
		for zone: String in ["parabrisas", "luna"]:
			var hit := _hit(id, zone)
			if not bool(hit.get("ok", false)):
				continue
			assert_eq(float(hit.marks.depthUm), 0.0, "%s contra %s: la queratina no raya el vidrio" % [id, zone])


func test_una_garra_mas_dura_nunca_raya_menos_la_luneta() -> void:
	var order: Array = ALL_INLAYS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return _hv(a) < _hv(b))
	for animal: String in ["aguila", "tigre", "oso", "velociraptor"]:
		var last := -1.0
		for id: String in order:
			var d := float(_scen(animal, "luneta", id).scratch.depthUm)
			assert_true(d >= last - 1e-9, "%s: %s raya la luneta %s µm, no menos que la anterior (%s)" % [animal, id, d, last])
			last = d


func test_la_luneta_entera_o_estallada_bajo_el_animal() -> void:
	for id: String in _holders():
		for inlay: String in ALL_INLAYS:
			for dfn: bool in [false, true]:
				var s := _scen(id, "luneta", inlay, dfn)
				if not bool(s.get("ok", false)):
					continue
				var rw: Dictionary = s.rearWindow
				assert_true(rw.shattered is bool, "%s %s: estalla o no" % [id, inlay])
				assert_eq(bool(rw.losesSupport), bool(rw.shattered), "si estalla, pierde el apoyo")
				assert_eq(bool(rw.shardsInside), bool(rw.shattered), "y caen trocitos dentro")
				assert_true(s.windshield == null, "la luneta no es el parabrisas laminado")
				var det := MC.detach(s)
				var v := MC.detach_verdict(s, det)
				if bool(rw.shattered):
					assert_true(String(v.verdict).begins_with("ESTALLA LA LUNETA"), "%s %s: el veredicto lo dice (%s)" % [id, inlay, v.verdict])
					assert_eq(float(s.anchorN.value), 0.0, "sin luneta no hay anclaje")
					assert_false(bool(det.atRest), "%s %s: sin apoyo, ni parado se sostiene" % [id, inlay])
				else:
					assert_false(String(v.verdict).begins_with("ESTALLA"), "%s %s: entera, el veredicto de siempre" % [id, inlay])
				if _hv(inlay) < float(Glazing.SIDE_WINDOW.hv) and not MC.is_film(_claw(id)):
					assert_true(rw.cause != "grieta", "%s %s: más blanda que el vidrio, no la revienta por una grieta" % [id, inlay])


func test_la_luneta_no_se_recompone_con_la_velocidad() -> void:
	for c: Array in [["tigre", "cuarzo", false], ["oso", "diamante", false], ["oso", "diamante", true], ["aguila", "diamante", true],
			["velociraptor", "zafiro", true], ["tigre", "none", false]]:
		var s := _scen(c[0], "luneta", c[1], c[2])
		var curve := CSM.curve(s, 230.0, 12, 4)
		var was := bool(s.rearWindow.shattered)
		for m: Dictionary in curve.samples:
			var now := bool(m.get("rearShattered", false))
			assert_true(not was or now, "%s %s: estallada a %s km/h, sigue estallada" % [c[0], c[1], m.vKmh])
			if now:
				assert_false(bool(m.holdsAfter), "sin luneta no aguanta")
			was = now
		var ev: Variant = curve.get("rearAt")
		assert_true(ev != null, "el hito de la luneta está en la curva")
		if bool(s.rearWindow.shattered):
			assert_eq(float(ev.kmh), 0.0, "%s %s: estalla ya parado" % [c[0], c[1]])
			assert_eq(float(curve.detachKmh), 0.0, "y se suelta ahí")
	var roof := CSM.curve(_scen("tigre", "techo", "cuarzo"), 230.0, 6, 3)
	assert_true(roof.get("rearAt") == null, "en el techo no hay luneta")


func test_el_parabrisas_agrietado_tapa_y_no_cae() -> void:
	for id: String in _holders():
		for inlay: String in ["none", "acero", "zafiro", "diamante"]:
			var s := _scen(id, "parabrisas", inlay)
			if not bool(s.get("ok", false)):
				continue
			var sh: Dictionary = s.windshield
			assert_false(sh.has("falls"), "el laminado no cae")
			var vl: Dictionary = sh.viewLoss
			assert_true(float(vl.frac) >= 0.0 and float(vl.frac) <= 1.0, "lo que tapa, entre nada y todo")
			assert_eq(bool(sh.cracked), float(vl.frac) > 0.0, "%s %s: tapa algo si y solo si se agrieta" % [id, inlay])
			assert_eq(String(vl.quality), "estimate", "marcado como estimación")
			assert_true(String(vl.source).contains("ESTIMACIÓN"), "y la fuente lo dice")
	var hit := _hit("tigre", "parabrisas")
	assert_true(bool(hit.windshield.cracked), "el tigre agrieta el parabrisas")
	assert_true(float(hit.windshield.viewLoss.frac) > 0.0, "y tapa al conductor")
	for n in 5:
		assert_true(float(CarGlass.view_loss(true, false, n + 1, 4, 0.5).frac) >= float(CarGlass.view_loss(true, false, n, 4, 0.5).frac))
		assert_true(float(CarGlass.view_loss(true, true, 2, n + 1, 0.5).frac) >= float(CarGlass.view_loss(true, true, 2, n, 0.5).frac))


func test_lo_de_siempre_no_cambia() -> void:
	for zone: String in ["capo", "techo", "maletero"]:
		var s := _scen("tigre", zone, "zafiro")
		assert_true(s.rearWindow == null, "%s: sin luneta" % zone)
		assert_false(s.scratch.has("trace"), "%s: las marcas de la chapa no llevan el trazo del vidrio" % zone)
		assert_true(s.windshield == null)
	var side := _hit("oso", "luna")
	assert_true(side.windshield == null and side.sideWindow != null, "la ventanilla templada, como en la 4m")


func test_los_textos_de_los_cristales() -> void:
	var st := _st("tigre", "luneta", "cuarzo", 0.0)
	var rows := _rows(st)
	assert_true(rows.has("Luneta") and String(rows.Luneta).begins_with("estalla"), "la fila de la luneta dice que estalla")
	assert_true(st.why_text().begins_with("No lo tira el viento"), "el porqué: se queda sin nada debajo (%s)" % st.why_text())
	assert_true(st.glass_view_note().begins_with("Estalla la luneta"), "el rótulo de la vista")
	var t := st.tear_now()
	assert_true(bool(t.glass) and String(t.id) == "estalla", "el corte es el del vidrio, estallado")
	for l: Dictionary in t.layers:
		assert_eq(String(l.state), "estallada", "todas las capas del templado")
	var w := _st("oso", "parabrisas", "none", 30.0)
	var wrows := _rows(w)
	assert_true(wrows.has("Vista del conductor") and String(wrows["Vista del conductor"]).contains("estimación"), "lo que tapa, marcado")
	assert_eq(String(w.tear_now().id), "agrieta", "el corte: el laminado agrietado")
	var k := _st("aguila", "parabrisas", "acero", 60.0)
	assert_true(String(k.closeup_caption()[1]).contains("trazo de su metal"), "el acero deja un trazo, no una raya")
	assert_eq(String(k.tear_now().id), "mancha", "y no raya el vidrio")


func test_el_primer_plano_dice_lo_mismo_que_el_corte() -> void:
	# el fallo de la revisión: el corte decía «perfora» y el texto «raja la chapa de lado a lado»
	var st := _st("tigre", "techo", "tungsteno", 200.0)
	var t := st.tear_now()
	assert_eq(String(t.id), "perfora", "el tigre de carburo a 200 km/h perfora el techo (la raja no corre)")
	var cap := String(st.closeup_caption()[1])
	assert_true(cap.contains(String(t.text)), "el texto del primer plano lleva el veredicto del corte (%s)" % cap)
	assert_false(cap.contains("raja la chapa"), "y no dice que raja")


func test_la_luneta_estalla_solo_con_el_animal_encima() -> void:
	# CarSpeedMarks.rear_cumulative con muestras de ejemplo: estalla a la primera velocidad en la que el animal sigue encima
	# y su carga la revienta; más allá del despegue (holds false) las cargas son hipotéticas y no la rompen; y no se recompone
	var whole := { "shattered": false }
	var burst := { "shattered": true, "cause": "grieta" }
	var scen := { "rearWindow": whole }
	var samples := [
		{ "holds": true, "holdsAfter": true, "rearWindow": whole }, { "holds": true, "holdsAfter": true, "rearWindow": burst },
		{ "holds": true, "holdsAfter": true, "rearWindow": whole }, { "holds": false, "holdsAfter": false, "rearWindow": burst },
	]
	CSM.rear_cumulative(scen, samples)
	assert_false(bool(samples[0].rearShattered), "a la primera velocidad, entera")
	for k in [1, 2, 3]:
		assert_true(bool(samples[k].rearShattered), "desde que estalla, estallada (%d)" % k)
		assert_false(bool(samples[k].holdsAfter), "y sin apoyo")
		assert_true(bool(samples[k].rearWindow.shattered), "con la luneta que estalló")
	var gone := [{ "holds": false, "holdsAfter": false, "rearWindow": burst }]
	CSM.rear_cumulative(scen, gone)
	assert_false(bool(gone[0].rearShattered), "si ya se ha ido, su carga hipotética no la rompe")
	var at_rest := [{ "holds": false, "holdsAfter": false, "rearWindow": whole }]
	CSM.rear_cumulative({ "rearWindow": burst }, at_rest)
	assert_true(bool(at_rest[0].rearShattered), "estallada parada, estallada a todas las velocidades")


func test_el_umbral_es_el_mismo_que_el_de_la_lente() -> void:
	var reaction: GDScript = load("res://core/lab/claw_care_reaction.gd")
	assert_eq(CarGlass.R_SCRATCH, float(reaction.R_SCRATCH), "el umbral del cristal es el de la lente de la cetrería")
