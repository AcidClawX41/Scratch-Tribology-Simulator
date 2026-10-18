## La ventanilla templada en el golpe del coche en marcha (unidad 4m; docs/fisica/coche-en-marcha.md §15): la zona «luna»
## con sus fuentes; quién llega a ella (window_reach: volando, saltando o con la cruz de la literatura, nunca con el tamaño del
## dibujo); el golpe, el del parabrisas y el del banco con la hoja del banco (Glazing.SIDE_WINDOW y tempered_result);
## invariantes («más velocidad nunca deja entera una ventanilla que estallaba», «la queratina nunca la revienta por una
## grieta», «una punta dura nunca necesita más fuerza que la queratina», «el laminado se agrieta y sujeta; el templado estalla
## o aguanta entero»); el balance de energía; el contrato de sideWindow; los textos y el estado de la tarjeta.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const Physics = preload("res://core/lab/physics.gd")
const Js = preload("res://core/shared/js.gd")
## El vigilante de los textos del coche en marcha (unidad 4j): sus ensayos, sus textos visibles y lo que no puede salir.
const Watch = preload("res://tests/lab/test_moving_car_textos.gd")

const ZONE := "luna"
const BIRDS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const RAPTORS := ["velociraptor_pelicula", "velociraptor"]
## Los que llegan a la ventanilla: las aves (vuelan), los velocirraptores (saltan) y el oso (su cruz pasa de la cintura).
const REACH := BIRDS + RAPTORS + ["oso"]
## Garras reforjadas al menos tan duras como el vidrio (550 HV; «vidrio» es el strass) y otras más blandas.
const HARD := ["diamante", "zafiro", "tungsteno", "moissanita", "circonita", "cuarzo", "vidrio", "swarovski", "hematites"]
const SOFT := ["none", "acero", "titanio", "oro"]
## Nada de rutas internas ni nombres de código en los textos que se ven.
const INTERNAL := ["docs/", ".gd", "MovingCar", "Physics.", "Glazing", "§"]


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func hit(id: String, over: Dictionary = {}) -> Dictionary:
	var p := { "claw": C(id), "target": T("coche"), "zone": ZONE, "v_kmh": 50.0, "animal_kmh": 20.0, "angle_deg": 90.0 }
	p.merge(over, true)
	return MC.impact(p)


func assert_readable(txt: String, what: String) -> void:
	for bad: String in INTERNAL:
		assert_false(txt.contains(bad), "%s: sin «%s» → %s" % [what, bad, txt])


# ── La zona, sus fuentes y quién llega ──

func test_la_zona_de_la_ventanilla_lleva_fuentes() -> void:
	var iz: Dictionary = MC.IMPACT_ZONES[ZONE]
	assert_eq(iz.name, "Ventanilla", "nombre")
	assert_eq(iz.normal, "lado", "un costado")
	assert_true(iz.glass and iz.tempered, "vidrio templado, no el laminado")
	assert_eq(iz.hold, null, "en un costado no se queda: cae")
	for f: String in ["slope_deg", "slide_m", "clearance_mm", "draw"]:
		var s: Variant = iz.sources.get(f)
		assert_true(s is Dictionary and String(s.source).length() > 20, "fuente de %s" % f)
		assert_true(["primary", "secondary", "estimate", "dibujo"].has(String(s.quality)), "calidad de %s" % f)
	assert_eq(iz.sources.draw.quality, "dibujo", "el punto del golpe es del dibujo")
	assert_eq(MC.WINDOW_SILL_SOURCE.quality, "estimate", "la cintura, estimación con el caso medido más parecido")
	assert_true(String(MC.WINDOW_SILL_SOURCE.source).contains("Cui"), "la berlina de base de Cui et al. (2025)")
	for id: String in MC.WITHERS_M:
		var w: Dictionary = MC.WITHERS_M[id]
		assert_true(float(w.min) <= float(w.value) and float(w.value) <= float(w.max), "%s: la cruz con su banda" % id)
		assert_true(["secondary", "estimate"].has(String(w.quality)) and String(w.source).length() > 40, "%s: con fuente" % id)
	assert_true(String(MC.WITHERS_M.tigre.source).contains("Hunter"), "el tigre: Hunter (2011)")
	assert_true(String(MC.WITHERS_M.oso.source).contains("Animal Diversity Web"), "el oso: Animal Diversity Web")
	# la cintura: el pie del parabrisas, con el borde del capó de Cui et al. (2025) y su banda
	var hood: Dictionary = MC.IMPACT_ZONES.capo
	var rise := float(hood.slide_m) * sin(float(hood.slope_deg) * PI / 180.0)
	assert_near(MC.window_sill_m(), 0.70 + rise, 1e-9, 0.0, "la cintura, al pie del parabrisas")
	assert_true(MC.window_sill_m("min") < MC.window_sill_m() and MC.window_sill_m() < MC.window_sill_m("max"), "con su banda")
	assert_true(MC.window_sill_m() < float(MC.panel_height_m("parabrisas")), "por debajo de la mitad del parabrisas")
	assert_eq(MC.window_top_m(), float(MC.ROOF_M.value), "arriba, el techo")


func test_quien_llega_a_la_ventanilla() -> void:
	var sill := MC.window_sill_m()
	for id: String in BIRDS:
		var wr: Dictionary = MC.window_reach(C(id))
		assert_true(wr.reaches and wr.how == "vuela", "%s: vuela, llega" % id)
		assert_true(MC.impact_zones_for(C(id)).has(ZONE), "%s: se le ofrece" % id)
	for id: String in RAPTORS:
		var wr: Dictionary = MC.window_reach(C(id))
		assert_true(wr.reaches and wr.how == "salta", "%s: saltando" % id)
		assert_near(float(wr.hitM), MC.leap_reach_m(), 1e-12, 0.0, "%s: los pies en lo alto del salto (leap_reach_m)" % id)
		assert_true(float(wr.hitM) > sill and float(wr.hitM) < MC.window_top_m(), "%s: dentro de la luna" % id)
	var bear: Dictionary = MC.window_reach(C("oso"))
	assert_true(bear.reaches and bear.how == "cruz", "el oso: con su cruz")
	assert_near(float(bear.hitM), float(MC.WITHERS_M.oso.value) - float(MC.BODIES.oso.contact_mm) / 1000.0, 1e-12, 0.0,
		"el centro de su apoyo, un radio por debajo de la cruz (de la literatura, no del dibujo)")
	var tiger: Dictionary = MC.window_reach(C("tigre"))
	assert_false(tiger.reaches, "el tigre, a cuatro patas, no llega")
	assert_true(float(tiger.hitM) < sill and float(tiger.hitMaxM) >= sill, "con los datos más favorables, sí")
	assert_true(String(tiger.reason).contains("cruz") and String(tiger.reason).contains("puerta"), tiger.reason)
	assert_false(MC.impact_zones_for(C("tigre")).has(ZONE), "no se le ofrece")
	var rt := hit("tigre")
	assert_false(rt.ok, "y si se pide, no se hace")
	assert_eq(rt.reason, tiger.reason, "y dice por qué")
	var cas: Dictionary = MC.window_reach(C("casuario"))
	assert_false(cas.reaches, "el casuario patea a la altura de las patas")
	assert_true(String(cas.reason).contains("Naish"), "cuenta lo que se sabe: a veces rompe el cristal (Naish 2007)")
	assert_false(MC.impact_zones_for(C("casuario")).has(ZONE), "no se le ofrece")
	assert_false(hit("casuario", { "animal_kmh": 0.0 }).ok, "no se hace")
	for id: String in REACH:
		assert_true(hit(id).ok, "%s: el golpe se hace" % id)


# ── El golpe contra la hoja ──

func test_el_golpe_es_el_del_parabrisas_con_la_hoja_del_banco() -> void:
	var W: Dictionary = Glazing.SIDE_WINDOW
	for id: String in REACH:
		for inl: String in ["none", "diamante", "acero"]:
			for va: float in [5.0, 20.0, 40.0]:
				var r := hit(id, { "animal_kmh": va, "inlay": inl })
				var sw: Dictionary = r.sideWindow
				var body: Dictionary = MC.body_of(C(id))
				var tag := "%s %s %s km/h" % [id, inl, va]
				var pb := Physics.pane_break(W.pane, W.E, float(body.contact_mm))
				assert_near(float(sw.bendN), float(pb.F), 1e-12, 0.0, "%s: la flexión, la de la hoja del banco (Roark)" % tag)
				var vn: float = float(r.vNormalKmh) / 3.6
				var k: float = 1.0 / (2.0 / float(pb.k) + 1.0 / float(Physics.MODEL.limbStiffness))
				assert_near(float(sw.peakN), vn * sqrt(float(r.reducedMassKg) / 2.0 * k * 1000.0), 1e-9, 0.0,
					"%s: F = v_n·√(m·k), la hoja y la pata en serie, como el parabrisas" % tag)
				assert_near(float(sw.perClawN), float(sw.peakN) * 2.0 / float(MC.strike_claws_of(body)), 1e-12, 0.0, "%s: por garra" % tag)
				var tip := MC.claw_tip(MC.ClawsV2.apply(C(id)), MC.inlay_of({ "inlay": inl }))
				var tr := Glazing.tempered_result(W, float(sw.peakN), float(pb.F), float(tip.hv) / float(W.hv) >= 1.0,
					float(sw.perClawN), float(tip.tanA))
				assert_eq(sw.shattered, tr.shattered, "%s: tempered_result" % tag)
				assert_eq(sw.cause, tr.cause, "%s: la causa" % tag)
				assert_near(float(sw.fragmentMm), Glazing.fragment_size_mm(float(W.frac.sigmaS), float(W.E), float(W.frac.nu)), 1e-12, 0.0,
					"%s: los trocitos de Nielsen et al. (2022)" % tag)
				assert_eq(r.windshield, null, "%s: no es el parabrisas" % tag)
				assert_eq(r.dent, null, "%s: el vidrio no se abolla" % tag)
				assert_eq(r.puncture, null, "%s: ni se perfora" % tag)


func test_mas_velocidad_nunca_deja_entera_una_ventanilla_que_estallaba() -> void:
	# la del animal hace el golpe contra la luna (de lado); la del coche, no la cambia (la componente lateral es la del animal)
	for id: String in REACH:
		for inl: String in ["none", "diamante", "zafiro", "acero"]:
			for th: float in [45.0, 90.0, 135.0]:
				var was := false
				var prev_peak := -1.0
				for va: float in [0.0, 5.0, 10.0, 15.0, 20.0, 30.0, 40.0, 55.0, 70.0]:
					var r := hit(id, { "animal_kmh": va, "angle_deg": th, "inlay": inl })
					var sw: Dictionary = r.sideWindow
					var tag := "%s %s a %s° y %s km/h" % [id, inl, th, va]
					assert_true(float(sw.peakN) >= prev_peak - 1e-9, "%s: más velocidad, nunca menos golpe" % tag)
					prev_peak = float(sw.peakN)
					assert_true(not was or Js.truthy(sw.shattered), "%s: si estallaba, sigue estallando" % tag)
					was = was or Js.truthy(sw.shattered)
				var at := hit(id, { "animal_kmh": 30.0, "angle_deg": th, "inlay": inl })
				for vc: float in [0.0, 50.0, 120.0, 230.0]:
					var r2 := hit(id, { "animal_kmh": 30.0, "angle_deg": th, "inlay": inl, "v_kmh": vc })
					assert_eq(r2.sideWindow.shattered, at.sideWindow.shattered, "%s %s: el coche a %s km/h no cambia la luna" % [id, inl, vc])


func test_la_queratina_nunca_la_revienta_por_una_grieta() -> void:
	for id: String in REACH:
		for inl: String in SOFT:
			for va: float in [5.0, 20.0, 40.0, 70.0]:
				var sw: Dictionary = hit(id, { "animal_kmh": va, "inlay": inl }).sideWindow
				var tag := "%s %s %s km/h" % [id, inl, va]
				assert_false(Js.truthy(sw.hardTip), "%s: más blanda que el vidrio" % tag)
				assert_true(sw.cause != "grieta", "%s: nunca por una grieta" % tag)
				assert_eq(sw.pierceN, null, "%s: sin carga de la grieta" % tag)
				assert_eq(Js.truthy(sw.shattered), float(sw.peakN) >= float(sw.bendN), "%s: estalla solo al flexar" % tag)
	# la garra de película (200 HV) tampoco: el vidrio es más duro
	var film: Dictionary = hit("velociraptor_pelicula", { "animal_kmh": 39.0 }).sideWindow
	assert_false(Js.truthy(film.hardTip), "la garra de película, más blanda que el vidrio")
	assert_true(film.cause != "grieta", "no la revienta por una grieta")


func test_una_punta_dura_nunca_necesita_mas_fuerza_que_la_queratina() -> void:
	# con la misma carga: la queratina solo la parte al flexar; una punta dura, también con la grieta, que pide menos
	for id: String in REACH:
		var body: Dictionary = MC.body_of(C(id))
		var claw: Dictionary = MC.ClawsV2.apply(C(id))
		var keratin := MC.claw_tip(claw, MC.inlay_of({}))
		for inl: String in HARD:
			var tip := MC.claw_tip(claw, MC.inlay_of({ "inlay": inl }))
			for vn: float in [0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0]:
				var a := MC.side_window_impact(vn, 50.0, float(body.contact_mm), 2, MC.strike_claws_of(body), keratin)
				var b := MC.side_window_impact(vn, 50.0, float(body.contact_mm), 2, MC.strike_claws_of(body), tip)
				var tag := "%s %s a %s m/s" % [id, inl, vn]
				assert_true(Js.truthy(b.hardTip), "%s: más dura que el vidrio" % tag)
				var need_a := float(a.bendN)
				var need_b := minf(float(b.bendN), float(b.pierceN) * float(MC.strike_claws_of(body)) / 2.0)
				assert_true(need_b <= need_a + 1e-9, "%s: nunca pide más fuerza por apoyo (%s > %s)" % [tag, need_b, need_a])
				assert_true(not Js.truthy(a.shattered) or Js.truthy(b.shattered), "%s: si la queratina la revienta, la punta dura también" % tag)
		# y en el golpe de verdad (la masa de más de las garras reforjadas solo suma)
		for va: float in [5.0, 10.0, 20.0, 40.0]:
			if Js.truthy(hit(id, { "animal_kmh": va }).sideWindow.shattered):
				for inl: String in HARD:
					assert_true(Js.truthy(hit(id, { "animal_kmh": va, "inlay": inl }).sideWindow.shattered), "%s %s a %s km/h: también" % [id, inl, va])


func test_el_laminado_se_agrieta_y_sujeta_y_el_templado_estalla_o_aguanta_entero() -> void:
	# el mismo golpe (la misma masa, la misma velocidad y el mismo apoyo) contra las dos hojas del coche
	var lam_cracked_temp_whole := 0
	for contact: float in [15.0, 30.0, 50.0, 65.0]:
		for mass: float in [0.35, 5.0, 20.0, 100.0, 250.0]:
			for vn: float in [0.5, 1.0, 2.0, 4.0, 8.0, 12.0]:
				var ws := MC.windshield_impact(vn, mass, contact, 2)
				var sw := MC.side_window_impact(vn, mass, contact, 2, 4, MC.claw_tip(C("aguila"), MC.inlay_of({})))
				var tag := "%s mm · %s kg · %s m/s" % [contact, mass, vn]
				assert_false(ws.has("shattered"), "%s: el laminado no se deshace: se agrieta y el PVB lo sujeta" % tag)
				assert_false(sw.has("cracked"), "%s: el templado no se queda agrietado: estalla o aguanta entero" % tag)
				if Js.truthy(sw.shattered):
					assert_true(ws.cracked, "%s: si el templado estalla, el laminado (más débil al flexar) se agrieta" % tag)
					assert_true(float(sw.fragmentMm) < 10.0, "%s: en trocitos" % tag)
				if ws.cracked and not Js.truthy(sw.shattered):
					lam_cracked_temp_whole += 1
				# el templado aguanta más al flexar que el laminado del mismo golpe
				assert_true(float(sw.bendN) > float(ws.bendN), "%s: el templado aguanta más" % tag)
	assert_true(lam_cracked_temp_whole > 0, "hay golpes que agrietan el parabrisas y dejan entera la ventanilla")


# ── Balance de energía, contrato y lo que no cambia ──

func test_el_balance_de_energia_cuenta_el_vidrio() -> void:
	var combos := [[50.0, 40.0, 90.0], [90.0, 60.0, 30.0], [120.0, 30.0, 150.0], [50.0, 5.0, 90.0]]
	for id: String in REACH:
		for inl: String in ["none", "diamante", "acero"]:
			for k: Array in combos:
				var r := hit(id, { "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2], "inlay": inl })
				var e: Dictionary = r.energy
				var tag := "%s %s %s" % [id, inl, k]
				var sum := 0.0
				for t: Dictionary in e.terms:
					assert_true(float(t.j) >= 0.0, "%s: %s no es negativo" % [tag, t.id])
					sum += float(t.j)
				assert_near(sum, e.totalJ, 1e-9, 1e-9, "%s: los términos suman el total" % tag)
				assert_near(e.totalJ, r.energyJ, 1e-9, 1e-9, "%s: el total es ½·m·v_rel²" % tag)
				assert_near(e.punctureJ + e.panelJ + e.animalJ, r.normalJ, 1e-9, 1e-9, "%s: la normal que se disipa" % tag)
				var sw: Dictionary = r.sideWindow
				assert_eq(e.terms[1].id, "vidrio", "%s: el término del vidrio" % tag)
				# unidad 4o: si aguanta no se queda nada, y el nombre lo dice (no «hasta estallar»)
				assert_eq(e.terms[1].name, "Ventanilla (hasta estallar)" if Js.truthy(sw.shattered) else "Ventanilla (aguanta: lo devuelve)",
					"%s: con su nombre" % tag)
				assert_near(e.panelJ, minf(float(sw.glassJ), r.normalJ), 1e-12, 1e-12, "%s: lo que se queda la hoja" % tag)
				if not Js.truthy(sw.shattered):
					assert_eq(float(sw.glassJ), 0.0, "%s: si aguanta, se lo devuelve al animal" % tag)
				elif sw.cause == "flexión":
					var pb := Physics.pane_break(Glazing.SIDE_WINDOW.pane, Glazing.SIDE_WINDOW.E, float(MC.body_of(C(id)).contact_mm))
					assert_near(float(sw.glassJ), float(pb.U) / 1000.0, 1e-12, 0.0, "%s: U = F²/2k al partirse" % tag)
				# la energía del temple no sale del golpe: no está entre los términos
				assert_near(float(sw.temperJ), float(Glazing.strain_energy_density(100.0, 72.0, 0.22)) * PI * 0.25 * 0.25 * 0.004, 1e-9, 0.0,
					"%s: la del temple, U_D·V" % tag)


func test_el_contrato_de_side_window() -> void:
	var keys := ["shattered", "cause", "fragmentMm", "fragments25", "bendN", "pierceN", "peakN", "pane", "quality", "source",
		"perClawN", "shapePierceN", "hardTip", "tipHv", "glassHv", "compressionMm", "glassJ", "temperJ", "energyJ", "paneSource"]
	for id: String in REACH:
		var r := hit(id)
		var sw: Variant = r.get("sideWindow")
		assert_true(sw is Dictionary, "%s: sideWindow" % id)
		for key: String in keys:
			assert_true((sw as Dictionary).has(key), "%s: sideWindow.%s" % [id, key])
		assert_true(["front", "rear"].has(String(sw.pane)), "%s: pane" % id)
		assert_eq(sw.pane, MC.WINDOW_PANE, "%s: la de delante" % id)
		assert_true([null, "flexión", "grieta"].has(sw.cause), "%s: causa" % id)
		assert_eq(sw.quality, "estimate", "%s: estimación" % id)
		assert_readable(String(sw.source), "%s: la fuente" % id)
		assert_readable(String(sw.paneSource), "%s: por qué la de delante" % id)
	# en el resto de zonas, sideWindow existe y es null (el contrato: todo campo que pinta la interfaz existe)
	for zone: String in ["capo", "techo", "parabrisas", "puerta", "aleta"]:
		var r := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": zone, "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
		assert_true(r.has("sideWindow") and r.sideWindow == null, "%s: sideWindow = null" % zone)


## La ventanilla en la banda del golpe (impact().band): solo se mueve la compresión de las caras, con su banda medida (de 150 MPa
## a favor del coche a 80 en contra, Achintha 2020), y side_window_impact se calcula en los dos extremos. La hoja y la pata no
## tienen banda (fixed). Invariantes: si estalla con todo a favor, estalla en el centro y con todo en contra; la grieta nunca
## pide más fuerza con menos compresión; los trocitos, más pequeños con más; la queratina nunca la revienta por una grieta.
func test_la_ventanilla_en_la_banda_del_golpe() -> void:
	var flips := 0
	for id: String in REACH:
		for inl: String in ["none", "diamante", "zafiro", "cuarzo", "acero"]:
			for va: float in [3.0, 6.0, 10.0, 15.0, 20.0, 30.0, 45.0, 70.0]:
				var r := hit(id, { "animal_kmh": va, "inlay": inl })
				var b: Dictionary = r.band
				var tag := "%s %s %s km/h" % [id, inl, va]
				assert_true(b.varies.has("templado"), "%s: se mueve la compresión del templado" % tag)
				assert_false(b.varies.has("pintura"), "%s: no hay barniz en la luna" % tag)
				assert_true(b.fixed.has("pata") and b.fixed.has("ventanilla") and not b.fixed.has("parabrisas"),
					"%s: sin banda, la pata y la hoja de la ventanilla: %s" % [tag, b.fixed])
				var w: Dictionary = b.sideWindow
				assert_eq([w.sigmaS.value, w.sigmaS.lo, w.sigmaS.hi], [float(Glazing.SIDE_WINDOW.frac.sigmaS), 150.0, 80.0],
					"%s: 100 MPa en el centro, 150 a favor y 80 en contra" % tag)
				var sw: Dictionary = r.sideWindow
				assert_eq([w.shattered.value, w.cause.value], [Js.truthy(sw.shattered), sw.cause], "%s: el centro es el golpe" % tag)
				assert_eq(float(w.peakN.value), float(sw.peakN), "%s: con su fuerza de pico" % tag)
				assert_eq(float(w.bendN), float(sw.bendN), "%s: la flexión no tiene banda" % tag)
				# los dos extremos con side_window_impact
				for side: String in ["lo", "hi"]:
					var e: Dictionary = b[side].sideWindow
					assert_true(e.has("shattered") and e.has("peakN") and e.has("cause"), "%s: %s con side_window_impact" % [tag, side])
				var lo: Dictionary = b.lo.sideWindow
				var hi: Dictionary = b.hi.sideWindow
				assert_true(not lo.shattered or Js.truthy(sw.shattered), "%s: si estalla con todo a favor, estalla en el centro" % tag)
				assert_true(not Js.truthy(sw.shattered) or hi.shattered, "%s: y con todo en contra" % tag)
				assert_true(float(lo.peakN) <= float(sw.peakN) + 1e-9 and float(sw.peakN) <= float(hi.peakN) + 1e-9,
					"%s: la fuerza de pico, de menos a más" % tag)
				if not RAPTORS.has(id):
					assert_eq([float(lo.peakN), float(hi.peakN)], [float(sw.peakN), float(sw.peakN)],
						"%s: sin banda de su masa ni de su velocidad, el mismo golpe" % tag)
				assert_true(float(lo.fragmentMm) < float(sw.fragmentMm) and float(sw.fragmentMm) < float(hi.fragmentMm),
					"%s: con más compresión, trocitos más pequeños" % tag)
				if sw.pierceN != null:
					assert_true(float(lo.pierceN) > float(sw.pierceN) and float(sw.pierceN) > float(hi.pierceN),
						"%s: con más compresión, la grieta pide más" % tag)
				else:
					assert_true(lo.pierceN == null and hi.pierceN == null and w.pierceN == null, "%s: sin grieta con una punta blanda" % tag)
					assert_true(lo.cause != "grieta" and hi.cause != "grieta", "%s: ni en los extremos" % tag)
				if not lo.shattered and hi.shattered:
					flips += 1
				var src := String(b.source)
				assert_true(src.contains("Achintha 2020") and src.contains("EN 12150-1"), "%s: la banda dice su fuente: %s" % [tag, src])
				assert_readable(src, "%s: la fuente de la banda" % tag)
	assert_true(flips > 0, "hay golpes que aguantan con todo a favor y estallan con todo en contra: %d" % flips)
	# fuera de la ventanilla, sin la ventanilla en la banda
	var door := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
	assert_eq(door.band.sideWindow, null, "la puerta: sin ventanilla en la banda")
	assert_false(door.band.varies.has("templado") or door.band.fixed.has("ventanilla"), "ni la compresión ni la hoja")
	var ws := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 50.0, "animal_kmh": 40.0 })
	assert_true(ws.band.fixed.has("parabrisas") and not ws.band.fixed.has("ventanilla"), "el parabrisas, con su hoja")


## La banda en las palabras de la tarjeta: la frase de la banda dice si la ventanilla estalla o aguanta y con qué fuerza de
## pico (en lugar de «perfora»); la lectura «Ventanilla», si la banda cambia algo; y la compresión, en las fuentes.
func test_la_banda_de_la_ventanilla_en_palabras() -> void:
	var seen := {}
	for id: String in REACH:
		for inl: String in ["none", "zafiro", "diamante"]:
			for va: float in [3.0, 10.0, 20.0, 45.0]:
				var st := MCS.new(C(id), T("coche"))
				st.threaded = false
				st.set_inlay(inl)
				st.set_mode("impact")
				st.set_impact_zone(ZONE)
				st.set_speed(50.0)
				st.set_impact("animal_kmh", va)
				st.set_impact("angle_deg", 90.0)
				st.finish()
				var tag := "%s %s %s km/h" % [id, inl, va]
				var txt: String = st.impact_band_text()
				var w: Dictionary = st.hit.band.sideWindow
				assert_true(txt.contains("la ventanilla ") and txt.contains("de pico por apoyo"), "%s: %s" % [tag, txt])
				assert_false(txt.contains("perfora"), "%s: la luna no se perfora: estalla o aguanta" % tag)
				var sh: Dictionary = w.shattered
				var key := "%s%s%s" % [int(sh.lo), int(sh.value), int(sh.hi)]
				seen[key] = true
				if not sh.lo and sh.hi:
					assert_true(txt.contains("(con todo en contra, estalla)") or txt.contains("(con todo a favor, aguanta)"), "%s: %s" % [tag, txt])
				var rd: Dictionary = {}
				for x: Dictionary in st.impact_readings():
					if x.id == "ventanilla":
						rd = x
				assert_false(rd.is_empty(), "%s: la lectura de la ventanilla" % tag)
				assert_eq(String(rd.sub).contains("con todo en contra, estalla"), not sh.lo and sh.hi, "%s: la lectura con su banda: %s" % [tag, rd.sub])
				var src: Array = st.sources().filter(func(s: Dictionary) -> bool: return s.label == "Compresión de las caras (banda)")
				assert_eq(src.size(), 1, "%s: la compresión con su banda, en las fuentes" % tag)
				assert_true(String(src[0].source).contains("Achintha"), "%s: con su fuente" % tag)
				st.dispose()
	assert_true(seen.has("000") and seen.has("111") and (seen.has("001") or seen.has("011")),
		"aguanta, estalla y, con la banda, estalla con todo en contra y aguanta con todo a favor: %s" % [seen.keys()])


## La cinemática del golpe a la ventanilla (impact().kinematics): un velocirraptor salta para llegar y golpea en lo alto del
## salto, sin subir ni bajar: vuela lo que tarda en subir (v_salto/g, leap.timeS), no cae nada y llega de lado, con su
## carrera. Las aves la golpean de lado, sin vuelo. Sola o dentro del golpe, la misma.
func test_la_cinematica_del_salto_a_la_ventanilla() -> void:
	for id: String in RAPTORS:
		for k: Array in [[50.0, 20.0, 90.0], [90.0, 39.0, 60.0], [30.0, 10.0, 120.0]]:
			var p := { "claw": C(id), "target": T("coche"), "zone": ZONE, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2] }
			var r := MC.impact(p)
			var kin: Dictionary = r.kinematics
			var lp: Dictionary = r.leap
			var tag := "%s %s" % [id, k]
			assert_true(kin.ok and kin.leap and kin.apex, "%s: salta y golpea en lo alto del salto" % tag)
			assert_true(same(kin, MC.kinematics(p)), "%s: la misma sola que dentro del golpe" % tag)
			assert_near(float(lp.timeS), MC.kick_leap_ms() / MC.G, 1e-12, 0.0, "%s: tarda en subir v/g" % tag)
			assert_eq(float(kin.flightS), float(lp.timeS), "%s: vuela lo de su salto" % tag)
			assert_eq([float(kin.dropM), float(kin.fallKmh), float(kin.relKmh.z)], [0.0, 0.0, 0.0], "%s: en lo alto no baja" % tag)
			assert_eq([float(lp.apexM), float(lp.panelM)], [float(lp.hitM), float(lp.hitM)], "%s: golpea donde llega" % tag)
			assert_near(float(kin.carFlightM), float(k[0]) / MC.KMH * float(lp.timeS), 1e-12, 1e-12, "%s: el coche avanza v·t" % tag)
			assert_eq(float(kin.arrival.z), 0.0, "%s: llega de lado, sin caída" % tag)
			assert_near(float(kin.normalKmh), float(r.vNormalKmh), 1e-12, 0.0, "%s: con la velocidad del golpe" % tag)
			# la banda: su carrera más rápida golpea más (o igual, si ya corre a lo más que pide)
			assert_true(float(r.band.hi.normalJ) >= float(r.normalJ), "%s: con todo en contra, más golpe" % tag)
	for id: String in ["aguila", "buitre"]:
		var kin: Dictionary = hit(id).kinematics
		assert_true(kin.ok and not kin.leap and not kin.apex, "%s: de lado, sin salto" % id)
		assert_eq(float(kin.flightS), 0.0, "%s: sin vuelo antes de tocarla" % id)
	# en la tarjeta: «salta desde la carretera y golpea en lo más alto del salto»
	var st := MCS.new(C("velociraptor"), T("coche"))
	st.threaded = false
	st.set_mode("impact")
	st.set_impact_zone(ZONE)
	st.finish()
	var vuelo: Array = st.impact_readings().filter(func(x: Dictionary) -> bool: return x.id == "vuelo")
	assert_eq(vuelo.size(), 1, "la lectura del vuelo")
	assert_true(String(vuelo[0].sub).begins_with("salta desde la carretera y golpea en lo más alto del salto"), vuelo[0].sub)
	st.dispose()


## Con los ensayos de la ventanilla (los dos experimentos, garras duras y blandas, asustado y el de película), ningún texto que
## se ve lleva rutas ni nombres de código: el vigilante de los textos del coche en marcha.
func test_los_textos_de_la_ventanilla_se_leen() -> void:
	var watch: RefCounted = Watch.new()
	var bad := {}
	var count := 0
	var states: Array = []
	for e: String in ["ventanilla_diamante", "ventanilla_queratina"]:
		var st := MCS.new()
		st.threaded = false
		assert_true(st.load_experiment(e), e)
		states.append(st)
	for id: String in REACH:
		for cfg: Dictionary in [{ "inlay": "diamante", "sharp": 0.8 }, { "inlay": "zafiro" }, { "inlay": "oro" }, { "defense": true },
				{ "v": 120.0 }]:
			var st: RefCounted = Watch.state(id)
			var c := { "mode": "impact", "zone": ZONE }
			c.merge(cfg)
			Watch.apply(st, c)
			states.append(st)
	for st: RefCounted in states:
		st.finish()
		assert_true(Js.truthy(st.hit.get("ok")), "%s: golpea la ventanilla" % st.claw.id)
		for t: Variant in Watch.visible_texts(st):
			count += 1
			for o: Array in watch.offenders(String(t)):
				bad["%s ⟶ %s" % o] = true
		st.dispose()
	assert_true(count > 1000, "textos revisados: %d" % count)
	assert_eq(bad.size(), 0, "sin rutas ni código:\n%s" % "\n".join(PackedStringArray(bad.keys().slice(0, 25))))


func test_sin_la_ventanilla_todo_da_lo_mismo() -> void:
	# la ventanilla no cambia las zonas de siempre (el resto de golpes da lo mismo: lo vigilan los casos de referencia)
	for id: String in BIRDS + ["tigre", "oso"] + RAPTORS + ["casuario"]:
		var zs: Array = MC.impact_zones_for(C(id))
		zs.erase(ZONE)
		var before: Array = MC.KICK_ZONES.duplicate() if id == "casuario" else (
			["capo", "parabrisas", "puerta", "aleta"] if RAPTORS.has(id) else ["capo", "techo", "parabrisas", "puerta", "aleta"])
		assert_eq(zs, before, "%s: las zonas de siempre" % id)
	# las del golpe de siempre siguen sin ventanilla, y la del parabrisas sigue siendo el laminado
	var ws := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 50.0, "animal_kmh": 40.0 })
	assert_true(ws.windshield != null and ws.sideWindow == null, "el parabrisas, el laminado")


# ── Textos ──

func test_los_veredictos_y_el_informe_de_la_ventanilla() -> void:
	var smash := hit("oso", { "animal_kmh": 10.0 })
	assert_eq(smash.verdict, "ESTALLA LA VENTANILLA", "el oso a 10 km/h")
	assert_true(String(smash.vsub).contains("trocitos") and String(smash.vsub).contains("hueco abierto"), smash.vsub)
	assert_true(String(smash.vsub).contains("si el animal entra en el coche, el modelo no lo calcula"), "lo que no calcula")
	var crack := hit("aguila", { "inlay": "diamante" })
	assert_eq(crack.verdict, "ESTALLA LA VENTANILLA", "el águila con garras de diamante")
	assert_eq(crack.sideWindow.cause, "grieta", "por una grieta")
	assert_true(String(crack.vsub).contains("capa comprimida"), crack.vsub)
	var whole := hit("aguila")
	assert_eq(whole.verdict, "LA VENTANILLA AGUANTA", "con sus talones de queratina")
	assert_true(String(whole.vsub).contains("no la agrieta"), whole.vsub)
	for r: Dictionary in [smash, crack, whole]:
		var row: Variant = null
		for pair: Array in r.report:
			if pair[0] == "Ventanilla":
				row = pair[1]
		assert_true(row != null, "%s: la fila Ventanilla del informe" % r.claw)
		assert_readable(String(row), "fila Ventanilla")
		assert_readable(String(r.vsub), "subtítulo")
	# el velocirraptor de película: lo de cine, con el contraste; la física, la de siempre
	var film := hit("velociraptor_pelicula", { "animal_kmh": 39.0 })
	assert_eq(film.verdict, "SE ESTRELLA CONTRA LA VENTANILLA Y LA REVIENTA", "veredicto de cine")
	assert_true(String(film.vsub).ends_with(MC.FILM_NOTE_WINDOW), "con la coletilla de la ventanilla")
	var fr: Variant = null
	for pair: Array in film.report:
		if pair[0] == "Garras de película":
			fr = pair[1]
	assert_eq(fr, MC.FILM_CLAW_WINDOW_TXT, "la fila de película, la de la ventanilla")
	var stopped := hit("velociraptor_pelicula", { "animal_kmh": 5.0 })
	assert_eq(stopped.verdict, "LA VENTANILLA LE PARA LOS PIES", "veredicto de cine cuando aguanta")
	var salto: Variant = null
	for pair: Array in film.report:
		if pair[0] == "Salto":
			salto = pair[1]
	assert_true(String(salto).contains("salta para llegar a la ventanilla"), "el salto hasta la luna: %s" % salto)
	assert_true(Js.truthy(film.leap.window) and film.leap.side, "salta y golpea en lo alto, con su carrera")
	# el parabrisas mantiene su texto de película
	assert_true(MC.FILM_CLAW_GLASS_TXT.contains("parabrisas"), "FILM_CLAW_GLASS_TXT, el del parabrisas")


func test_el_estado_de_la_tarjeta_con_la_ventanilla() -> void:
	var st := MCS.new()
	st.threaded = false
	assert_eq(MCS.ZONE_ARTICLE[ZONE], "la ventanilla", "el artículo")
	assert_eq(MCS.zone_name(ZONE), "Ventanilla", "el nombre (el de la zona del golpe, no el del borde)")
	assert_true(st.load_experiment("ventanilla_diamante"), "experimento de un clic")
	st.finish()
	assert_eq(st.impact_zone, ZONE, "la ventanilla")
	assert_eq(st.hit.verdict, "ESTALLA LA VENTANILLA", "con garras de diamante la revienta")
	assert_eq(st.hit.sideWindow.cause, "grieta", "por una grieta, con poca fuerza")
	assert_true(float(st.hit.sideWindow.peakN) < float(st.hit.sideWindow.bendN), "sin fuerza para partirla al flexar")
	assert_eq(st.impact_sfx(), "shatter", "suena a cristal que estalla")
	assert_eq(st.impact_color(), "coral", "color de rotura")
	var texts: Array = [st.why_text(), st.moral()]
	for f: Dictionary in st.facts():
		texts.append(String(f.text))
	var window_facts := 0
	for f: Dictionary in st.facts():
		if String(f.text).contains("temple") or String(f.text).contains("punzón"):
			window_facts += 1
			assert_readable(String(f.source), "fuente del dato")
	assert_true(window_facts >= 2, "«¿sabías que…?» del temple y del punzón duro")
	assert_true(st.facts()[0].text.contains("MPa de compresión"), "lo primero, el temple")
	for s: Dictionary in st.sources():
		if ["Ventanilla templada", "Altura de la ventanilla", "Hasta dónde llega"].has(s.label):
			texts.append(String(s.value))
			assert_readable(String(s.source), "fuente %s" % s.label)
	for rd: Dictionary in st.impact_readings():
		if rd.id == "ventanilla":
			texts.append(String(rd.value) + " " + String(rd.sub))
	for t: Variant in texts:
		assert_readable(String(t), "texto del estado")
	assert_true(st.why_text().begins_with("Estalla porque"), st.why_text())
	assert_true(st.load_experiment("ventanilla_queratina"), "y con sus talones")
	st.finish()
	assert_eq(st.hit.verdict, "LA VENTANILLA AGUANTA", "con queratina, el mismo golpe no")
	assert_eq(st.impact_sfx(), "press", "sin cristales")
	assert_true(st.why_text().begins_with("Aguanta porque"), st.why_text())
	assert_true(st.moral().contains("gana la ventanilla"), st.moral())
	# el tigre no la tiene entre sus zonas; el oso, sí
	st.set_claw(C("tigre"))
	assert_false(st.impact_zones().has(ZONE), "el tigre no llega")
	st.set_claw(C("oso"))
	assert_true(st.impact_zones().has(ZONE), "el oso sí")
	st.dispose()
