## Qué deja cada garra del animal quieto encima según lo que hace (unidad 4y, core/lab/car_hold_marks.gd y su uso en
## MovingCarState). Invariantes, en todos los animales que se quedan encima y en los cinco coches:
##   - sin moverse no hay surcos: si aguanta y ni la raja corre ni las garras se doblan, solo la huella de cada garra;
##   - sin resbalón no hay surcos de resbalón (el águila con garras de oro en la curva de 130 m a 94 km/h, el caso de Eric);
##   - el número de marcas es el de garras que agarran (MovingCar.BODIES[…].contact);
##   - los surcos van en la dirección del resbalón (atrás, de lado o delante, la del despegue);
##   - una garra que no llega a 1,25 veces la dureza del vidrio no lo raya, ni resbalando;
##   - el texto dice lo mismo que el dibujo; determinismo.
extends "res://tests/case.gd"

const CarHoldMarks = preload("res://core/lab/car_hold_marks.gd")
const CarGlass = preload("res://core/lab/car_glass.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const HOLDERS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "tigre", "oso", "velociraptor_pelicula", "velociraptor"]


static func _st(id: String, car: String, zone: String, inlay: String, v: float) -> MCS:
	var st := MCS.new(Catalog.find_by_id(Catalog.CLAWS, id), Catalog.find_by_id(Catalog.TARGETS, car))
	st.threaded = false
	st.set_zone(zone)
	st.set_inlay(inlay)
	st.set_speed(v)
	st.finish()
	return st


func test_sin_moverse_no_hay_surcos_y_una_marca_por_garra() -> void:
	var n := 0
	for id: String in HOLDERS:
		if not MC.BODIES.has(id):
			continue
		for car: String in MCS.CARS:
			var zone := "aleta" if car == "cocheplastico" else "techo"
			if not (MC.ZONES.get(zone, {}) as Dictionary).get("animals", []).has(String(MC.BODIES[id].kind)):
				continue
			for inlay: String in ["none", "oro", "diamante"]:
				var st := _st(id, car, zone, inlay, 0.0)
				if not st.supported() or not _ok(st):
					continue
				for v: float in [0.0, 60.0, 120.0, 200.0]:
					if v > st.top_kmh():
						continue
					st.set_speed(v)
					st.finish()
					var p := st.hold_plan()
					if p.is_empty():
						continue
					n += 1
					var who := "%s/%s/%s a %s km/h" % [id, car, inlay, v]
					var claws := int(MC.BODIES[id].contact)
					assert_eq(int(p.claws), claws, "%s: las garras que agarran" % who)
					assert_true(int(p.marks) == 0 or int(p.marks) == claws, "%s: una marca por garra (%s)" % [who, p.marks])
					var still := bool(st.at.holds) and String(p.cause) != CarHoldMarks.CAUSE_TEAR and String(p.cause) != CarHoldMarks.CAUSE_BEND
					if still:
						assert_eq(int(p.rakes.n), 0, "%s: sin moverse, ningún surco" % who)
						assert_true(st.hold_plan_txt().begins_with("sin resbalar") or st.hold_plan_txt() == "", "%s: el texto lo dice: %s" % [who, st.hold_plan_txt()])
					if bool(st.at.holds):
						assert_true(String(p.cause) != CarHoldMarks.CAUSE_SLIDE, "%s: sin resbalón no hay surcos de resbalón" % who)
					if int(p.rakes.n) > 0:
						assert_eq(int(p.rakes.n), claws, "%s: un surco por garra" % who)
						assert_false(st.hold_plan_txt().begins_with("sin resbalar"), "%s: el texto dice que se mueve" % who)
	assert_true(n > 200, "ensayos comprobados: %d" % n)


static func _ok(st: MCS) -> bool:
	return not st.scen.is_empty() and bool(st.scen.get("ok", false))


func test_el_aguila_de_oro_en_la_curva_no_resbala_ni_raya_el_techo() -> void:
	# el caso de Eric: «se agarra con más fuerza (usa el 61 % de su agarre), sin resbalar», y el techo salía rayado
	var st := MCS.new(Catalog.find_by_id(Catalog.CLAWS, "aguila"), Catalog.find_by_id(Catalog.TARGETS, "coche"))
	st.threaded = false
	st.set_zone("techo")
	st.set_inlay("oro")
	st.set_road(CarCurve.ROAD_CURVE)
	st.set_radius(130.0)
	st.set_speed(94.0)
	st.finish()
	assert_true(bool(st.at.holds), "aguanta")
	var p := st.hold_plan()
	assert_true(String(p.cause) != CarHoldMarks.CAUSE_SLIDE, "no resbala")
	assert_eq(int(p.prints.n), int(MC.BODIES.aguila.contact), "la huella de cada garra")
	# el oro se dobla: su punta rasca lo que se dobla (menos de un milímetro), nunca todo el techo
	if String(p.cause) == CarHoldMarks.CAUSE_BEND:
		assert_true(float(p.rakes.lengthMm) < 5.0, "solo lo que se dobla la punta: %s mm" % p.rakes.lengthMm)
		assert_true(st.hold_plan_txt().contains("se doblan"), st.hold_plan_txt())
	assert_true(float(p.rakes.lengthMm) < float(MC.ZONES.techo.slide_m) * 1000.0 * 0.01, "nada de surcos de todo el techo")


func test_los_surcos_van_en_la_direccion_del_resbalon() -> void:
	var m := { "marks": { "depthUm": 50.0, "widthUm": 200.0, "scratched": true }, "puncture": { "holeUm": 100.0, "depthUm": 20.0 }, "punctUm": 20.0 }
	for c: Array in [["atras", 1.0, 0.0], ["lado", 1.0, 90.0], ["lado", -1.0, -90.0], ["delante", 1.0, 180.0], ["abajo", 1.0, 180.0]]:
		var p := CarHoldMarks.plan(m, { "claws": 4, "holds": false, "mode": c[0], "side": c[1], "slideMm": 800.0 })
		assert_eq(String(p.cause), CarHoldMarks.CAUSE_SLIDE, "%s: resbala" % c[0])
		assert_near(float(p.rakes.deg), float(c[2]), 1e-9, 0.0, "%s: hacia donde lo lleva la fuerza" % c[0])
		assert_eq(int(p.rakes.n), 4, "un surco por garra")
	var up := CarHoldMarks.plan(m, { "claws": 4, "holds": false, "mode": "despega", "slideMm": 800.0 })
	assert_eq(int(up.rakes.n), 0, "si despega no araña")
	var curve := CarHoldMarks.plan(m, { "claws": 4, "holds": false, "mode": "lado", "slideMm": 800.0, "curve": true })
	assert_eq(int(curve.rakes.n), 0, "en curva, la caída de lado la dibuja el agarre en curva (4u)")
	var held := CarHoldMarks.plan(m, { "claws": 4, "holds": true, "slideMm": 800.0 })
	assert_eq(int(held.rakes.n), 0, "si aguanta, ninguno")
	assert_eq(int(held.prints.n), 4, "y la huella de cada garra")
	assert_eq(CarHoldMarks.plan(m, { "claws": 4, "holds": true }), CarHoldMarks.plan(m, { "claws": 4, "holds": true }), "determinista")
	assert_eq(CarHoldMarks.plan({}, {}), {}, "sin datos, nada")


func test_lo_mas_blando_que_1_25_veces_el_vidrio_no_lo_raya_ni_resbalando() -> void:
	var glass_hv := float(Glazing.WINDSCREEN.hv)
	var hard_seen := false
	for inl: Dictionary in Catalog.INLAYS:
		var id := String(inl.id)
		var hv := 30.0 if id == "none" else float(inl.hv)
		for zone: String in ["parabrisas", "luneta"]:
			var st := _st("lechuza", "coche", zone, id, 0.0)
			if not _ok(st):
				continue
			var off := float(st.det.kmh) + 10.0
			st.set_speed(minf(off, st.top_kmh()) if is_finite(off) else st.top_kmh())
			st.finish()
			var p := st.hold_plan()
			if p.is_empty():
				continue
			if not CarGlass.scratches(hv, glass_hv):
				assert_eq(int(p.rakes.n), 0, "%s (%s HV) no raya %s ni resbalando" % [id, hv, zone])
			elif not bool(st.at.holds) and String(p.cause) == CarHoldMarks.CAUSE_SLIDE:
				hard_seen = true
				assert_eq(int(p.rakes.n), int(MC.BODIES.lechuza.contact), "%s raya %s al resbalar: un surco por garra" % [id, zone])
			assert_eq(int(p.prints.n), 0, "%s: en el vidrio no hay huella (sus grietas son las del parabrisas)" % id)
	assert_true(hard_seen, "alguna garra dura raya el vidrio al resbalar")


func test_la_luneta_que_estalla_ya_no_se_raya() -> void:
	# el tigre con garras de cuarzo en la luneta (la demo de la 4v): estalla bajo él y se le va el apoyo; en un vidrio que ya
	# no está no hay surcos ni huellas, y el texto no dice que lo raye
	var st := _st("tigre", "coche", "luneta", "cuarzo", 0.0)
	var rear: Variant = st.rear_now()
	assert_true(rear != null and bool(rear.shattered), "la luneta estalla")
	var p := st.hold_plan()
	assert_eq(String(p.cause), CarHoldMarks.CAUSE_SHATTER, "estalla")
	assert_eq(int(p.marks), 0, "ninguna marca")
	assert_eq(int(p.rakes.n) + int(p.prints.n), 0, "ni surcos ni huellas")
	assert_false(st.hold_plan_txt().contains("raya el vidrio"), st.hold_plan_txt())
	assert_false(st.closeup_marks_txt(st.marks_now()).contains("raya el vidrio"), st.closeup_marks_txt(st.marks_now()))
	assert_true(String(p.quality) != "" and String(p.source) != "", "con su fuente")
