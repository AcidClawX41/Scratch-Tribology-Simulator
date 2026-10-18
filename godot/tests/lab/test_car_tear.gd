## Hasta dónde llega cada marca y si raja o abre el panel (unidad 4s, petición de Eric del 17-10: core/lab/car_tear.gd y
## MovingCarState.tear_now). Se comprueba:
##   - la tenacidad de la chapa (R = σ0·t, con su banda) y la del plástico (la de MovingCar.PLASTIC_TEAR);
##   - las capas de cada marca (cortada, marcada, atravesada) y sus textos;
##   - el orden del veredicto: marca < perfora < raja < abre; la raja quieto encima solo corre si el viento puede con las
##     garras; «abre la puerta» solo si la raja llega al canto; el techo entero, nunca;
##   - invariantes: más velocidad (más fuerza) o unas garras más duras nunca dan un escalón más bajo; la queratina nunca
##     perfora el acero;
##   - que cada número lleva su fuente y su calidad.
extends "res://tests/case.gd"

const CarTear = preload("res://core/lab/car_tear.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Js = preload("res://core/shared/js.gd")

const LEVEL := { "nada": 0, "marca": 1, "perfora": 2, "raja": 3, "abre": 4 }


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func _hold(id: String, inlay: String, v: float, car := "coche") -> MCS:
	var st := MCS.new(Catalog.find_by_id(Catalog.CLAWS, id), T(car))
	st.threaded = false
	st.set_zone("techo")
	st.set_inlay(inlay)
	st.set_speed(v)
	st.finish()
	return st


static func _hit(id: String, inlay: String, zone: String, v: float, va: float, car := "coche") -> MCS:
	var st := MCS.new(Catalog.find_by_id(Catalog.CLAWS, id), T(car))
	st.threaded = false
	st.set_mode(MCS.MODE_IMPACT)
	st.set_impact_zone(zone)
	st.set_inlay(inlay)
	st.set_speed(v)
	st.set_impact("animal_kmh", va)
	st.set_impact("angle_deg", 90.0)
	st.finish()
	return st


func test_la_tenacidad_de_la_chapa_y_del_plastico() -> void:
	var steel: Dictionary = CarTear.tear_toughness(T("coche"))
	var body: Dictionary = T("coche").body
	assert_near(float(steel.value), float(body.sigma0) * float(body.t) / 1000.0, 1e-12, 1e-12, "R = σ0·t (MPa·mm = kJ/m²)")
	assert_true(float(steel.min) < float(steel.value) and float(steel.value) < float(steel.max), "con su banda")
	assert_eq(String(steel.quality), "estimate", "estimación, marcada")
	assert_true(String(steel.source).contains("Cotterell"), "con el caso medido más parecido")
	var pl: Dictionary = CarTear.tear_toughness(T("cocheplastico"))
	assert_eq(float(pl.value), float(MC.PLASTIC_TEAR["plastico-carroceria"].value), "el plástico, el de su desgarro (4g)")
	assert_eq(CarTear.tear_toughness(T("vidrio")), null, "sin carrocería, nada")
	for c: Dictionary in [CarTear.LATCH, CarTear.NPS_BEAR, CarTear.ROOF, CarTear.SHEET_TEAR]:
		assert_true(String(c.source) != "" and String(c.quality) != "", "cada dato con su fuente y su calidad")


func test_las_capas_de_cada_marca() -> void:
	var car := T("coche")
	var cut := CarTear.cutaway(car, 70.0, false)
	assert_eq(cut.map(func(l: Dictionary) -> String: return l.state), ["cortada", "cortada", "marcada", "intacta", "intacta"],
		"70 µm: barniz y color cortados, la imprimación marcada, el anticorrosivo y la chapa intactos")
	assert_true(CarTear.cutaway(car, 70.0, true).all(func(l: Dictionary) -> bool: return l.state == "atravesada"), "atravesado: todas")
	assert_eq(CarTear.layers_txt(car, 70.0, false), "corta el barniz y el color y raya la imprimación (70 µm): no llega a la chapa", "en palabras")
	assert_true(CarTear.layers_txt(car, 300.0, false).contains("marca el acero de horno (HC180B) sin perforarlo (190 µm de 0.7 mm)"),
		"la chapa marcada, con lo que se hunde (%s)" % CarTear.layers_txt(car, 300.0, false))
	assert_eq(CarTear.layers_txt(car, 810.0, true), "atraviesa la pintura y la chapa de 0.7 mm", "atravesada")


func test_el_orden_del_veredicto() -> void:
	var car := T("coche")
	var base := { "target": car, "zone": "techo", "hold": true, "nClaws": 8, "cuts": true }
	var a := CarTear.assess(base.merged({ "depthUm": 50.0 }))
	assert_eq(a.id, "marca", "no atraviesa: marca")
	a = CarTear.assess(base.merged({ "depthUm": 300.0, "punctThrough": true, "holeUm": 900.0 }))
	assert_eq(a.id, "perfora", "la punta asoma por detrás: perfora")
	var r := float(CarTear.tear_toughness(car).value) * 0.7
	a = CarTear.assess(base.merged({ "depthUm": 810.0, "through": true, "pullN": r * 8.0 - 1.0 }))
	assert_eq(a.id, "perfora", "quieto encima, si el viento no puede con las 8 garras (n·R·t) la raja no corre")
	a = CarTear.assess(base.merged({ "depthUm": 810.0, "through": true, "pullN": r * 8.0 + 1.0 }))
	assert_eq(a.id, "raja", "si puede, raja")
	assert_near(float(a.lengthMm), float(MC.IMPACT_ZONES.techo.slide_m) * 1000.0, 1e-9, 1e-9, "hasta el borde del panel")
	assert_true(String(a.roof).begins_with("no abre el techo entero"), "y el techo entero, nunca: %s" % a.roof)
	var door := { "target": car, "zone": "puerta", "hold": false, "nClaws": 8, "cuts": true, "depthUm": 810.0, "through": true }
	a = CarTear.assess(door.merged({ "cutMm": 300.0 }))
	assert_eq(a.id, "raja", "en la puerta, una raja corta no la abre")
	assert_true(String(a.door).begins_with("no la abre"), "y lo dice: %s" % a.door)
	a = CarTear.assess(door.merged({ "cutMm": float(MC.IMPACT_ZONES.puerta.slide_m) * 1000.0 }))
	assert_eq(a.id, "abre", "la raja que llega al canto de la cerradura abre la puerta")
	assert_eq(a.opens, "puerta", "la puerta")
	assert_eq(a.quality, "estimate", "estimación")
	a = CarTear.assess({ "target": car, "zone": "capo", "hold": false, "nClaws": 2, "cuts": true, "depthUm": 810.0, "through": true,
		"cutMm": 500.0, "film": true })
	assert_true(String(a.text).ends_with("(ficción: garras de película)") and a.quality == "ficcion", "el velocirraptor de cine, ficción")


func test_mas_velocidad_nunca_menos_dano() -> void:
	for combo: Array in [["tigre", "none"], ["oso", "none"], ["tigre", "tungsteno"], ["aguila", "diamante"]]:
		var last := -1
		for v: float in [0.0, 60.0, 120.0, 200.0]:
			var t := _hold(String(combo[0]), String(combo[1]), v).tear_now()
			var lv := int(t.get("level", 0))
			assert_true(lv >= last, "%s %s: a %s km/h, escalón %d (antes %d)" % [combo[0], combo[1], v, lv, last])
			last = lv
	var prev := -1
	for va: float in [10.0, 25.0, 40.0]:
		var t := _hit("tigre", "tungsteno", "puerta", 50.0, va).tear_now()
		var lv := int(t.get("level", 0))
		assert_true(lv >= prev, "el golpe más rápido nunca deja menos (%s km/h: %d)" % [va, lv])
		prev = lv


func test_garras_mas_duras_nunca_menos_dano_y_la_queratina_no_perfora() -> void:
	var soft := _hit("tigre", "none", "puerta", 50.0, 40.0).tear_now()
	var hard := _hit("tigre", "tungsteno", "puerta", 50.0, 40.0).tear_now()
	assert_true(int(hard.level) >= int(soft.level), "el carburo de tungsteno nunca menos que la queratina (%s ≥ %s)" % [hard.id, soft.id])
	assert_true(int(soft.level) <= 1, "la queratina no perfora el acero (%s)" % soft.id)
	for id: String in ["tigre", "oso", "aguila"]:
		for v: float in [60.0, 200.0]:
			var t := _hold(id, "none", v).tear_now()
			assert_true(int(t.get("level", 0)) <= 1, "%s de queratina a %s km/h: solo marca (%s)" % [id, v, t.get("id")])
	var pl := _hit("tigre", "none", "aleta", 50.0, 40.0, "cocheplastico").tear_now()
	assert_eq(pl.id, "raja", "el plástico de la aleta sí se raja (4g)")


func test_la_ficha_en_la_tarjeta() -> void:
	var st := _hit("tigre", "tungsteno", "puerta", 50.0, 40.0)
	var r := st.tear_reading()
	assert_eq(r.id, "desgarro", "una ficha más en el golpe")
	assert_true(String(r.value).begins_with("Raja "), "con el escalón (%s)" % r.value)
	assert_true(String(r.sub).contains("no la abre"), "y por qué no abre la puerta")
	assert_true(st.impact_readings().any(func(x: Dictionary) -> bool: return x.id == "desgarro"), "entre las del golpe")
	var h := _hold("oso", "none", 120.0)
	assert_true(h.hold_readings().any(func(x: Dictionary) -> bool: return x.id == "desgarro"), "y quieto encima")
