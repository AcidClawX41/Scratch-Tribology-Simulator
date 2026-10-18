## El coche en curva (unidad 4t, core/lab/car_curve.gd y su bloque de MovingCarState): a = v²/R exacta; más velocidad o
## menos radio nunca dan menos aceleración lateral ni hacen que el animal aguante mejor; en la S la fuerza cambia de signo
## y el pico de carga cae en las garras del lado nuevo; en recta todo sale al bit como antes; si la curva pide más que el
## agarre del coche, «derrapa» y el animal nunca siente más que ese tope; los radios y el tirón son los de la norma 3.1-IC;
## y cada dato nuevo lleva fuente y calidad.
extends "res://tests/case.gd"

const CarCurve = preload("res://core/lab/car_curve.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const QUALITIES := ["primary", "secondary", "estimate", "dibujo"]
## Animales y zonas con los que se recorren los invariantes (quietos encima).
const CASES := [
	["aguila", "techo", "plegadas"], ["halcon", "techo", "plegadas"], ["lechuza", "retrovisor", "plegadas"],
	["tigre", "techo", "tumbado"], ["oso", "techo", "de_pie"], ["velociraptor", "techo", ""], ["buitre", "capo", "plegadas"],
]
const RADII := [15.0, 50.0, 130.0, 265.0, 450.0, 700.0, 1050.0]
const SPEEDS := [0.0, 20.0, 40.0, 60.0, 90.0, 120.0, 160.0, 230.0]


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func scen_of(cfg: Array, car := "coche", cross := 0.0) -> Dictionary:
	var p := { "claw": C(cfg[0]), "target": T(car), "zone": cfg[1], "crosswind_kmh": cross, "model": "2.0" }
	if String(cfg[2]) != "":
		p.posture = cfg[2]
	return MC.setup(p)


func test_aceleracion_lateral_exacta() -> void:
	for v: float in [0.0, 1.0, 36.0, 50.0, 90.0, 123.4, 230.0, 293.0]:
		for r: float in RADII:
			var ms := v / 3.6
			assert_eq(CarCurve.lateral_ms2(v, r), ms * ms / r, "a = v²/R a %s km/h y %s m" % [v, r])
			assert_eq(CarCurve.demand_g(v, r), ms * ms / r / MC.G, "en g, con la g del coche en marcha")
	# a 90 km/h (25 m/s) en 125 m: 5 m/s² exactos
	assert_eq(CarCurve.lateral_ms2(90.0, 125.0), 5.0, "25²/125 = 5")


func test_mas_velocidad_o_menos_radio_nunca_menos_aceleracion() -> void:
	for r: float in RADII:
		var prev := -1.0
		for v: float in SPEEDS:
			var a := CarCurve.lateral_ms2(v, r)
			assert_true(a >= prev, "más velocidad, más aceleración (%s m)" % r)
			prev = a
	for v: float in SPEEDS:
		var prev := INF
		for r: float in RADII:
			var a := CarCurve.lateral_ms2(v, r)
			assert_true(a <= prev, "más radio, menos aceleración (%s km/h)" % v)
			prev = a
	# lo que siente el animal tampoco baja (con el tope del coche, se queda en él)
	for r: float in RADII:
		var prev := -1.0
		for v: float in SPEEDS:
			var a := CarCurve.felt_ms2(v, r, 0.85)
			assert_true(a >= prev and a <= 0.85 * MC.G + 1e-12, "lo sentido crece y no pasa del tope")
			prev = a


func test_menos_radio_o_curva_nunca_aguanta_mejor() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		assert_true(bool(scen.ok), "%s: setup" % [cfg])
		for v: float in SPEEDS:
			var straight := MC.at_speed(scen, v)
			var prev := float(straight.marginN)
			for i in range(RADII.size() - 1, -1, -1):
				var a := CarCurve.at_speed(scen, v, RADII[i], 0.85, 1.0)
				assert_true(float(a.marginN) <= prev + 1e-9, "%s a %s km/h: con %s m no aguanta mejor" % [cfg, v, RADII[i]])
				prev = float(a.marginN)
		# el despegue en la curva nunca es a más velocidad que en recta, ni con menos radio a más
		var det0 := MC.detach(scen)
		var prev_kmh := float(det0.kmh) if bool(det0.atRest) else 0.0
		for i in range(RADII.size() - 1, -1, -1):
			var d := CarCurve.detach(scen, RADII[i], CarCurve.CAR_GRIP.turismo, 1.0)
			var k := float(d.kmh) if bool(d.atRest) else 0.0
			assert_true(k <= prev_kmh + 1e-6, "%s: en %s m no se suelta más tarde (%s frente a %s)" % [cfg, RADII[i], k, prev_kmh])
			prev_kmh = k


func test_con_viento_lateral_el_lado_peor_es_el_del_viento() -> void:
	var scen := scen_of(["aguila", "techo", "plegadas"], "coche", 30.0)
	var right := CarCurve.at_speed(scen, 100.0, 130.0, 0.85, 1.0)
	var left := CarCurve.at_speed(scen, 100.0, 130.0, 0.85, -1.0)
	assert_true(float(right.needN) > float(left.needN), "el viento lateral empuja a la derecha: la curva a la izquierda suma")
	var ds := CarCurve.detach_s(scen, 130.0, CarCurve.CAR_GRIP.turismo)
	assert_eq(float(ds.worst.side), 1.0, "en la S, el peor lado es el del viento")


func test_en_recta_todo_igual_al_bit() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for v: float in SPEEDS:
			var a0 := MC.at_speed(scen, v)
			var a1 := CarCurve.at_lateral(scen, v, 0.0, 130.0, 0.85)
			for k: String in a0:
				assert_true(same(a1[k], a0[k]), "%s a %s km/h: %s igual sin aceleración lateral" % [cfg, v, k])
	# el estado en recta da lo mismo que antes, y tras pasar por la curva y volver, también
	var st: RefCounted = MCS.new(C("aguila"), T("coche"))
	st.threaded = false
	st.set_speed(120.0)
	var at0: Dictionary = st.at.duplicate(true)
	var det0: Dictionary = st.det.duplicate(true)
	var verdict0: Dictionary = st.verdict.duplicate(true)
	var need0: PackedFloat64Array = st.chart.need
	assert_eq(at0, MC.at_speed(st.scen, 120.0), "en recta, at es el de MovingCar")
	assert_eq(det0, MC.detach(st.scen), "en recta, el despegue es el de MovingCar")
	st.set_road(CarCurve.ROAD_S)
	st.set_radius(50.0)
	assert_true(st.at.has("curve"), "en la S, at lleva la curva")
	st.set_road(CarCurve.ROAD_STRAIGHT)
	assert_eq(st.at, at0, "al volver a la recta, at al bit")
	assert_eq(st.det, det0, "y el despegue")
	assert_eq(st.verdict, verdict0, "y el veredicto")
	assert_eq(st.chart.need, need0, "y la gráfica")
	assert_eq(st.curve_text(), "", "en recta no hay texto de curva")
	assert_true(st.meter().is_empty(), "ni medidor")


func test_derrapa_si_pide_mas_que_el_coche() -> void:
	# el águila con talones de tungsteno clavados en el techo (el experimento de la 4d): no se suelta
	var scen := MC.setup({ "claw": C("aguila"), "target": T("coche"), "zone": "techo", "posture": "plegadas", "inlay": "tungsteno",
		"embedded": true, "model": "2.0" })
	var grip: Dictionary = CarCurve.CAR_GRIP.turismo
	var r := 50.0
	var skid := CarCurve.skid_kmh(r, float(grip.value))
	assert_near(CarCurve.lateral_ms2(skid, r), float(grip.value) * MC.G, 1e-12, 1e-12, "a la velocidad de derrape pide justo el tope")
	var a := CarCurve.at_speed(scen, skid + 20.0, r, float(grip.value), 1.0)
	assert_true(bool(a.curve.skids), "más deprisa, derrapa")
	assert_eq(float(a.curve.latMs2), float(grip.value) * MC.G, "el animal no siente más que el tope del coche")
	assert_true(CarCurve.now_txt(a.curve, skid + 20.0).contains("derrapa"), "la frase dice que derrapa")
	# aguanta más que el coche en la curva de 50 m: el veredicto es el derrape, nunca un número imposible
	var d := CarCurve.detach(scen, r, grip, 1.0)
	assert_true(bool(d.skidsFirst), "el coche derrapa antes de que se suelte el águila")
	var v := CarCurve.verdict(scen, d, 230.0)
	assert_true(String(v.verdict).begins_with("EL COCHE DERRAPA ANTES"), "veredicto: %s" % v.verdict)
	assert_true(String(v.vsub).contains("derrapa"), "y lo explica")
	# nunca pasa del tope, en ninguna velocidad ni radio
	for rr: float in RADII:
		for vv: float in SPEEDS:
			var c: Dictionary = CarCurve.at_speed(scen, vv, rr, float(grip.value), 1.0).curve
			assert_true(absf(float(c.latG)) <= float(grip.value) + 1e-12, "nunca más que el agarre del coche")


func test_el_aguila_se_suelta_de_lado_antes_de_que_derrape() -> void:
	# un águila sin nada que agarrar en el techo (fricción) en la glorieta: la curva la saca antes que el derrape
	var scen := scen_of(["aguila", "techo", "plegadas"])
	var d := CarCurve.detach(scen, 15.0, CarCurve.CAR_GRIP.turismo, 1.0)
	var straight := MC.detach(scen)
	assert_true(float(d.kmh) < float(straight.kmh), "en la glorieta se suelta antes que en recta")
	if not bool(d.skidsFirst) and String(d.mode) == "lado":
		var v := CarCurve.verdict(scen, d, 230.0)
		assert_true(String(v.verdict).begins_with("RESBALA HACIA FUERA"), "veredicto: %s" % v.verdict)


func test_curva_en_s_cambia_de_lado() -> void:
	var rd := CarCurve.road(130.0, T("coche"))
	var prof := CarCurve.s_profile(rd, 70.0, 241)
	var a: PackedFloat64Array = prof.aMs2
	var first_pos := -1
	var first_neg := -1
	for i in a.size():
		if a[i] > 1e-9 and first_pos < 0:
			first_pos = i
		if a[i] < -1e-9 and first_neg < 0:
			first_neg = i
	assert_true(first_pos >= 0 and first_neg > first_pos, "primero empuja a la derecha y luego a la izquierda")
	assert_near(float(prof.peakMs2), CarCurve.lateral_ms2(70.0, 130.0), 1e-9, 1e-12, "el pico es v²/R")
	# el cambio de lado, en el centro de la clotoide de cambio
	var flip := CarCurve.s_at(rd, 70.0, float(prof.flipS))
	assert_near(float(flip.aMs2), 0.0, 1e-9, 1e-9, "en el centro del cambio, sin aceleración lateral")
	assert_eq(String(flip.phase), "cambio", "en la clotoide de cambio")
	# las garras: en la primera curva cargan las de la derecha; en la segunda, las de la izquierda (el lado nuevo)
	var scen := scen_of(["tigre", "techo", "tumbado"])
	var t1 := (float(rd.leadM) + float(rd.clothoidM) + 0.5 * float(rd.arcM)) / (70.0 / 3.6)
	var t2 := float(prof.flipS) + (0.5 * float(rd.reverseM) + 0.5 * float(rd.arcM)) / (70.0 / 3.6)
	var p1 := CarCurve.s_at(rd, 70.0, t1)
	var p2 := CarCurve.s_at(rd, 70.0, t2)
	assert_eq(String(p1.phase), "curva1", "en la primera curva")
	assert_eq(String(p2.phase), "curva2", "en la segunda")
	var s1: Dictionary = CarCurve.at_lateral(scen, 70.0, float(p1.aMs2), 130.0, 0.85).curve.shares
	var s2: Dictionary = CarCurve.at_lateral(scen, 70.0, float(p2.aMs2), 130.0, 0.85).curve.shares
	assert_true(float(s1.right) > 0.5 and float(s1.loaded) == 1.0, "primera curva: el pico, en las garras de la derecha")
	assert_true(float(s2.left) > 0.5 and float(s2.loaded) == -1.0, "segunda curva: el pico, en las de la izquierda")
	assert_near(float(s2.left), float(s1.right), 1e-12, 1e-12, "el mismo pico, del otro lado")
	# y el desgarro se tuerce hacia fuera de cada curva
	var m1 := float(CarCurve.at_lateral(scen, 70.0, float(p1.aMs2), 130.0, 0.85).curve.markDeg)
	var m2 := float(CarCurve.at_lateral(scen, 70.0, float(p2.aMs2), 130.0, 0.85).curve.markDeg)
	assert_true(m1 > 0.0 and m2 < 0.0, "las marcas se tuercen hacia fuera: %s y %s grados" % [m1, m2])


func test_s_el_tiron_de_la_norma() -> void:
	for r: float in [50.0, 130.0, 265.0, 450.0, 700.0]:
		var rd := CarCurve.road(r, T("coche"))
		var vp := float(rd.designKmh)
		var j := float(rd.jerkNorm)
		# la clotoide de la norma con peralte 0: L = V³/(46,656·J·R), V en km/h
		assert_near(float(rd.clothoidM), vp * vp * vp / (46.656 * j * r), 1e-12, 1e-9, "clotoide de %s m" % r)
		assert_near(CarCurve.s_jerk_ms3(rd, vp), j, 1e-12, 1e-12, "a la velocidad de proyecto, el tirón de la norma (%s m)" % r)
		assert_near(CarCurve.s_jerk_ms3(rd, 2.0 * vp), 8.0 * j, 1e-12, 1e-12, "al doble, ocho veces")
		# el tirón de la S muestreada no pasa del de pico
		var prof := CarCurve.s_profile(rd, vp, 401)
		for x: float in prof.jerkMs3:
			assert_true(absf(x) <= float(prof.jerkPeakMs3) + 1e-9, "el tirón no pasa del de la clotoide de cambio")


func test_radios_de_la_norma() -> void:
	var want := { 40.0: 50.0, 50.0: 85.0, 60.0: 130.0, 70.0: 190.0, 80.0: 265.0, 90.0: 350.0, 100.0: 450.0, 110.0: 550.0, 120.0: 700.0, 130.0: 850.0, 140.0: 1050.0 }
	for e: Dictionary in CarCurve.NORM_RADII:
		assert_eq(float(e.r_m), float(want[float(e.v_kmh)]), "tabla 4.4 a %s km/h" % e.v_kmh)
		assert_eq(CarCurve.design_kmh(float(e.r_m)), float(e.v_kmh), "velocidad de proyecto de %s m" % e.r_m)
	assert_true(CarCurve.design_kmh(15.0) < 40.0 and CarCurve.design_kmh(15.0) > 15.0, "la glorieta, más despacio que 40 km/h")
	assert_eq(CarCurve.jerk_norm(70.0), 0.5, "J por debajo de 80 km/h")
	assert_eq(CarCurve.jerk_norm(80.0), 0.4, "J desde 80 km/h")
	# el deslizador del radio: de 15 a 1050 m, y vuelve
	assert_eq(CarCurve.radius_at(0.0), CarCurve.R_MIN_M, "abajo, la glorieta")
	assert_eq(CarCurve.radius_at(1.0), CarCurve.R_MAX_M, "arriba, 140 km/h")
	for p: Dictionary in CarCurve.PRESETS:
		assert_eq(CarCurve.radius_at(CarCurve.slider_u(float(p.r_m))), float(p.r_m), "el valor marcado %s vuelve igual" % p.id)
	# el tope: el turismo y el deportivo
	assert_eq(CarCurve.grip_of(T("coche")), CarCurve.CAR_GRIP.turismo, "turismo")
	assert_eq(CarCurve.grip_of(T("deportivo")), CarCurve.CAR_GRIP.deportivo, "deportivo")
	assert_true(float(CarCurve.CAR_GRIP.deportivo.value) > float(CarCurve.CAR_GRIP.turismo.value), "el deportivo agarra más")


func test_cada_dato_con_fuente_y_calidad() -> void:
	var data: Array = [CarCurve.RING_R, CarCurve.LOAD_TRANSFER, CarCurve.DRAW_ONLY, CarCurve.CAR_GRIP.turismo, CarCurve.CAR_GRIP.deportivo]
	data.append_array(CarCurve.PRESETS)
	for d: Dictionary in data:
		assert_true(String(d.get("source", "")).length() > 20, "fuente: %s" % d)
		assert_true(QUALITIES.has(String(d.get("quality", ""))), "calidad: %s" % d)
	for g: Dictionary in [CarCurve.CAR_GRIP.turismo, CarCurve.CAR_GRIP.deportivo, CarCurve.LOAD_TRANSFER, CarCurve.RING_R]:
		assert_true(float(g.min) <= float(g.value) and float(g.value) <= float(g.max), "banda ordenada")
	var rd := CarCurve.road(130.0, T("coche"))
	assert_eq(String(rd.quality), "primary", "un radio de la norma")
	assert_eq(String(CarCurve.road(15.0, T("coche")).quality), "estimate", "la glorieta, estimación")


func test_estado_en_curva() -> void:
	var st: RefCounted = MCS.new(C("aguila"), T("coche"))
	st.threaded = false
	st.set_speed(90.0)
	st.set_road(CarCurve.ROAD_CURVE)
	st.set_radius(130.0)
	var c: Dictionary = st.curve_now()
	assert_near(float(c.demandMs2), 25.0 * 25.0 / 130.0, 1e-12, 1e-12, "a 90 km/h en 130 m")
	assert_eq(float(c.side), 1.0, "la curva a la izquierda empuja a la derecha")
	assert_true(st.curve_text().begins_with("En la curva de 130 m a 90 km/h tira hacia fuera con 0.49 g (4.8 m/s²), hacia la derecha."), st.curve_text())
	assert_true(not st.meter().is_empty(), "medidor")
	var ids: Array = st.hold_readings().map(func(r: Dictionary) -> String: return r.id)
	assert_true(ids.has("curva") and ids.has("lados"), "lecturas de la curva: %s" % [ids])
	var labels: Array = st.sources().map(func(r: Dictionary) -> String: return r.label)
	assert_true(labels.has("Tope de agarre lateral del coche") and labels.has("Aceleración lateral"), "fuentes de la curva")
	for f: Dictionary in st.facts():
		assert_true(String(f.source) != "" or String(f.quality) == "", "dato con fuente")
	# una maniobra con curva vuelve a la recta, y elegir una curva quita la maniobra con curva
	st.set_maneuver("curva_fuerte")
	assert_eq(st.road, CarCurve.ROAD_STRAIGHT, "la maniobra con curva vuelve a la recta")
	st.set_road(CarCurve.ROAD_S)
	assert_eq(st.maneuver, MCS.DEFAULT_MANEUVER, "la curva quita la maniobra con curva")
	assert_eq(float(st.lateral_g), 0.0, "sin curva de la maniobra")
	# la S: un instante de cada lado
	var dur: float = st.s_duration()
	assert_true(is_finite(dur) and dur > 0.0, "la S dura %s s" % dur)
	var rd: Dictionary = st.curve_road()
	var f1: Dictionary = st.s_frame((float(rd.leadM) + float(rd.clothoidM) + 0.5 * float(rd.arcM)) / 25.0)
	var f2: Dictionary = st.s_frame(dur - (float(rd.leadM) + float(rd.clothoidM) + 0.5 * float(rd.arcM)) / 25.0)
	assert_true(float(f1.s.aMs2) > 0.0 and float(f2.s.aMs2) < 0.0, "la S cambia el signo")
	assert_true(float(f1.at.curve.meter.latG) > 0.0 and float(f2.at.curve.meter.latG) < 0.0, "el medidor cambia de lado")
	# los experimentos van en recta
	st.load_experiment("aguila_120")
	assert_eq(st.road, CarCurve.ROAD_STRAIGHT, "el experimento, en recta")
	assert_true(st.experiment_matches("aguila_120"), "y se reconoce")


## Los textos de la curva tampoco enseñan rutas ni nombres de código (las mismas reglas que test_moving_car_textos).
func test_textos_de_la_curva_sin_codigo() -> void:
	var tx: Script = load("res://tests/lab/test_moving_car_textos.gd")
	var res: Array[RegEx] = []
	for p: String in tx.BANNED_RE:
		res.append(RegEx.create_from_string(p))
	var n := 0
	for claw: String in ["aguila", "lechuza", "tigre", "oso", "velociraptor_pelicula"]:
		for car: String in ["coche", "deportivo"]:
			var st: RefCounted = MCS.new(C(claw), T(car))
			st.threaded = false
			for road: String in [CarCurve.ROAD_CURVE, CarCurve.ROAD_S]:
				st.set_road(road)
				for r: float in [15.0, 50.0, 450.0]:
					st.set_radius(r)
					for v: float in [40.0, 130.0]:
						st.set_speed(v)
						st.finish()
						var texts: Array = tx.visible_texts(st)
						texts.append_array([st.curve_text(), st.meter_note(st.curve_now(), 8.0), st.meter_note(st.curve_now(), 8.0, true),
							st.road_note(), st.radius_text()])
						for t: Variant in texts:
							var s := String(t)
							n += 1
							for b: String in tx.BANNED:
								assert_false(s.contains(b), "«%s» en: %s" % [b, s])
							for re: RegEx in res:
								for m: RegExMatch in re.search_all(s):
									assert_true(tx.ALLOWED.has(m.get_string()), "«%s» en: %s" % [m.get_string(), s])
	assert_true(n > 1000, "%d textos" % n)


## Si el coche derrapa antes, el porqué lo dice (no el despegue del animal, que llegaría ya derrapando).
func test_el_porque_cuando_derrapa_antes() -> void:
	var st: RefCounted = MCS.new(C("tigre"), T("coche"))
	st.threaded = false
	st.set_road(CarCurve.ROAD_CURVE)
	st.set_radius(130.0)
	st.set_speed(100.0)
	assert_true(bool(st.det.skidsFirst), "el tigre tumbado aguanta más que el coche en 130 m")
	assert_true(String(st.verdict.verdict).begins_with("EL COCHE DERRAPA ANTES"), String(st.verdict.verdict))
	assert_true(st.why_text().begins_with("El coche llega antes a su tope: a más de ~119 km/h"), st.why_text())
	assert_true(st.why_text().contains("ya con el coche derrapando"), st.why_text())


## El golpe en curva: la fuerza es la de siempre (el mismo impact, al bit) y solo se tuerce el camino del animal visto desde
## el coche; en recta (ω = 0) no se tuerce nada, en el golpe tampoco, y con más giro, más.
func test_el_golpe_en_curva() -> void:
	var st: RefCounted = MCS.new(C("tigre"), T("coche"))
	st.threaded = false
	st.set_mode(MCS.MODE_IMPACT)
	st.set_impact_zone("puerta")
	st.set_speed(60.0)
	st.finish()
	var hit0: Dictionary = st.hit.duplicate(true)
	assert_true(st.impact_approach(2.2).is_empty(), "en recta, sin camino torcido")
	st.set_road(CarCurve.ROAD_CURVE)
	st.set_radius(50.0)
	st.finish()
	assert_true(st.impact_curve_on(), "el golpe en curva")
	assert_eq(st.hit, hit0, "la misma fuerza y el mismo golpe, al bit")
	var path: PackedVector2Array = st.impact_approach(2.2, 16)
	assert_eq(path.size(), 16, "16 puntos")
	assert_true(path[15].length() < 1e-9, "en el golpe, en su sitio")
	assert_true(path[0].length() > 1e-3, "al principio, separado de la recta: %s" % path[0])
	assert_true(st.impact_curve_text().contains("la fuerza del golpe es la de siempre"), st.impact_curve_text())
	# en recta (ω = 0) no se tuerce; con más giro, más
	var straight := CarCurve.approach_offsets(-10.0, -8.0, 0.0, 60.0, 0.0, 2.2, 8)
	for p: Vector2 in straight:
		assert_eq(p, Vector2.ZERO, "sin giro, la recta")
	var w1 := CarCurve.yaw_rate(60.0, 130.0, 0.85, 1.0)
	var w2 := CarCurve.yaw_rate(60.0, 50.0, 0.85, 1.0)
	assert_true(w2 > w1 and w1 > 0.0, "menos radio, más giro")
	var p1 := CarCurve.approach_offsets(-10.0, -8.0, 0.0, 60.0, w1, 2.2, 8)
	var p2 := CarCurve.approach_offsets(-10.0, -8.0, 0.0, 60.0, w2, 2.2, 8)
	assert_true(p2[0].length() > p1[0].length(), "con más giro, se tuerce más")
	assert_near(CarCurve.yaw_rate(60.0, 50.0, 0.85, 1.0), (60.0 / 3.6) / 50.0, 1e-12, 1e-12, "ω = v/R sin derrapar")
