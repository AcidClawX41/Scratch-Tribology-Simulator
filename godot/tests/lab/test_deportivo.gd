## El deportivo del coche en marcha (unidad 4r: core/lab/sports_car.gd, MovingCar.slider_max_kmh y MovingCarState.CARS).
## Se comprueba:
##   - que sus datos llevan fuente y calidad (la velocidad máxima, la masa, el Cd y las medidas de la ficha del
##     fabricante; el área frontal y el Cp por zona, estimaciones marcadas) y que su chapa es la del coche de aluminio;
##   - que está en el catálogo 2.0 con un id que no es de la 1.x y en los coches del coche en marcha;
##   - que el deslizador llega a su velocidad máxima con él y sigue en 230 km/h con el turismo (y los demás de la 1.x), que
##     la curva de la gráfica acaba en ese tope y que el veredicto «aguanta a» usa el tope del coche elegido;
##   - invariantes: más velocidad nunca da menos fuerza del aire ni menos resistencia del coche, y la resistencia del
##     deportivo (Cd·A menor) es menor que la del turismo a la misma velocidad;
##   - que los coches de antes no cambian: el despegue del águila en el turismo es el mismo que sin el deportivo (el
##     escenario solo añade sus claves).
extends "res://tests/case.gd"

const SportsCar = preload("res://core/lab/sports_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func _hold(claw: String, car: String, zone := "techo", posture := "") -> MCS:
	var st := MCS.new(C(claw), T(car))
	st.threaded = false
	st.set_mode(MCS.MODE_HOLD)
	st.set_zone(zone)
	if posture != "":
		st.set_posture(posture)
	return st


func test_los_datos_del_deportivo_con_su_fuente() -> void:
	var e: Dictionary = SportsCar.ENTRY
	assert_eq(String(e.id), "deportivo")
	assert_true(float(e.vmax_kmh) > MC.SLIDER_MAX_KMH, "pasa de 230 km/h")
	assert_eq(String(e.quality), "primary")
	assert_true(String(e.source).contains("Porsche"), "la ficha del fabricante")
	for k: String in ["vmax_kmh", "mass_kg", "cd", "area_m2", "size_m", "body", "cp"]:
		var s: Dictionary = e.sources[k]
		assert_true(["primary", "secondary", "estimate"].has(String(s.quality)), "%s: calidad conocida (%s)" % [k, s.quality])
		assert_true(String(s.source).length() > 20, "%s: con fuente" % k)
	assert_eq(String(e.sources.area_m2.quality), "estimate", "el área frontal, estimación marcada")
	assert_eq(String(e.sources.cp.quality), "estimate", "el Cp por zona, estimación marcada")
	assert_eq(String(e.sources.vmax_kmh.quality), "primary", "la velocidad máxima, de la ficha")
	assert_eq(float(e.vmax_kmh), float(SportsCar.VMAX_KMH.value))
	assert_eq(float(e.mass_kg), float(SportsCar.MASS_KG.value))
	assert_eq(float(e.aero.cd), float(SportsCar.CD.value))
	assert_eq(float(e.aero.area_m2), float(SportsCar.AREA_M2.value))
	# la chapa: la del coche de aluminio (el caso medido más parecido), con su pintura encima
	assert_eq(e.body, Data.CAR_BODIES["aluminio"], "la chapa de aluminio AA6016")
	assert_eq(String(e.layers.kind), "paint-on-body")
	assert_near(float(e.thickness), float(T("cochealu").thickness), 1e-12, 1e-12, "el mismo espesor que el coche de aluminio")
	assert_true(String(e.fact).contains("estimación"), "la ficha dice qué es estimación")
	# el dibujo: el mismo largo, más bajo y más ancho que el turismo
	assert_eq(float(e.draw_scale.length), 1.0)
	assert_true(float(e.draw_scale.height) < 1.0 and float(e.draw_scale.width) > 1.0, "más bajo y más ancho")
	assert_eq(int(e.draw_doors), 2, "un cupé de dos puertas (dibujo)")
	# en el banco se dibuja como el coche de aluminio (su pintura y su chapa), no con el aspecto de reserva del plástico
	assert_eq(ArtMaterials.look("deportivo"), ArtMaterials.look("cochealu"), "el aspecto del coche de aluminio")
	assert_eq(ArtMaterials.marks_look_id("deportivo"), "cochealu", "y sus marcas")


func test_en_el_catalogo_2_0_y_en_los_coches_del_coche_en_marcha() -> void:
	assert_true(T("deportivo") != null, "en Catalog.TARGETS")
	assert_true(Catalog.V2_TARGETS.has(SportsCar.ENTRY), "entre los añadidos de la 2.0")
	for t: Dictionary in Data.TARGETS:
		assert_true(String(t.id) != "deportivo", "un id que no está en la 1.x")
	assert_true(MCS.CARS.has("deportivo"), "en MovingCarState.CARS")
	assert_eq(MCS.CARS.slice(0, 4), ["coche", "cocheclasico", "cochealu", "cocheplastico"], "los de antes, en su orden")


func test_el_tope_del_deslizador_por_coche() -> void:
	assert_eq(MC.slider_max_kmh(T("coche")), 230.0, "el turismo sigue en 230 km/h")
	for id: String in ["cocheclasico", "cochealu", "cocheplastico"]:
		assert_eq(MC.slider_max_kmh(T(id)), MC.SLIDER_MAX_KMH, "%s: 230 km/h" % id)
	assert_eq(MC.slider_max_kmh(T("deportivo")), 293.0, "el deportivo llega a su velocidad máxima")
	assert_eq(MC.slider_max_kmh(null), MC.SLIDER_MAX_KMH, "sin coche, el turismo")
	# el estado: el deslizador y la velocidad siguen al coche
	var st := _hold("aguila", "coche")
	assert_eq(st.slider_max_kmh(), 230.0)
	st.set_speed(280.0)
	assert_eq(st.v_kmh, 230.0, "el turismo no pasa de 230")
	st.set_target(T("deportivo"))
	assert_eq(st.slider_max_kmh(), 293.0)
	st.set_speed(280.0)
	assert_eq(st.v_kmh, 280.0, "el deportivo sí")
	var vs: PackedFloat64Array = st.chart.vKmh
	assert_eq(vs[-1], 293.0, "la curva de la gráfica acaba en el tope del deportivo")
	assert_eq(vs.size(), 61, "con sus 61 puntos")
	st.set_target(T("coche"))
	assert_eq(st.v_kmh, 230.0, "al volver al turismo, la velocidad baja a su tope")
	assert_eq((st.chart.vKmh as PackedFloat64Array)[-1], 230.0, "y la gráfica, a 230")


func test_el_veredicto_aguanta_a_usa_el_tope_del_coche() -> void:
	# tres que se sueltan entre los 230 km/h del turismo y los 293 del deportivo (con el aire de referencia): la arpía en
	# el capó (~254), el oso de pie en el techo (~289, el caso 21 de demo_coche) y el velocirraptor de verdad en el techo (~246)
	for c: Array in [["arpia", "capo", ""], ["oso", "techo", "de_pie"], ["velociraptor", "techo", "tumbado"]]:
		var st := _hold(String(c[0]), "coche", String(c[1]), String(c[2]))
		var det: Dictionary = st.det
		var kmh := float(det.kmh)
		assert_true(kmh > 230.0 and kmh < 293.0, "%s: se suelta entre 230 y 293 km/h (%s)" % [c[0], kmh])
		assert_true(bool(det.beyond), "%s: en el turismo, fuera del deslizador" % c[0])
		assert_true(String(st.verdict.verdict).begins_with("AGUANTA A 230"), "%s: «aguanta a 230 km/h» (%s)" % [c[0], st.verdict.verdict])
		st.set_target(T("deportivo"))
		assert_eq(float(st.det.kmh), kmh, "%s: el mismo despegue (el aire sobre el animal no cambia)" % c[0])
		assert_false(bool(st.det.beyond), "%s: en el deportivo, dentro del deslizador" % c[0])
		assert_false(String(st.verdict.verdict).begins_with("AGUANTA A"), "%s: y se ve cómo se suelta (%s)" % [c[0], st.verdict.verdict])
		assert_true(String(st.verdict.verdict).contains("A ~"), "%s: con su velocidad (%s)" % [c[0], st.verdict.verdict])
		assert_eq(float(st.scen.vmaxKmh), MC.slider_max_kmh(st.target), "%s: el escenario lleva el tope de su coche" % c[0])


func test_mas_velocidad_nunca_da_menos_fuerza_del_aire() -> void:
	for car: String in ["coche", "deportivo"]:
		var st := _hold("oso", car, "techo", "de_pie")
		var prev_drag := -1.0
		var prev_car := -1.0
		for v in range(0, 300, 10):
			var s: Dictionary = MC.at_speed(st.scen, float(v))
			assert_true(float(s.dragN) >= prev_drag, "%s: a %d km/h el aire no empuja menos que a menos velocidad" % [car, v])
			assert_true(float(s.carDragN) >= prev_car, "%s: ni el coche resiste menos" % car)
			prev_drag = float(s.dragN)
			prev_car = float(s.carDragN)
	# el deportivo tiene menos Cd·A que el coche de referencia: a la misma velocidad resiste menos que el turismo
	var a := _hold("oso", "coche", "techo", "de_pie")
	var b := _hold("oso", "deportivo", "techo", "de_pie")
	var sa: Dictionary = MC.at_speed(a.scen, 120.0)
	var sb: Dictionary = MC.at_speed(b.scen, 120.0)
	assert_true(float(sb.carDragN) < float(sa.carDragN), "el deportivo resiste menos (%s N frente a %s N)" % [sb.carDragN, sa.carDragN])
	assert_near(float(sb.carDragN) / float(sa.carDragN), MC.car_cda(T("deportivo")) / MC.car_cda(T("coche")), 1e-9, 1e-9, "en la razón de sus Cd·A")
	assert_eq(float(sa.dragN), float(sb.dragN), "el animal, el mismo aire: la misma fuerza sobre él")


func test_los_coches_de_antes_no_cambian() -> void:
	var st := _hold("aguila", "coche", "techo", "plegadas")
	var scen: Dictionary = st.scen
	assert_eq(float(scen.carCdA), MC.CAR_REF.cd * MC.CAR_REF.area_m2, "el turismo, con el coche de referencia")
	assert_eq(float(scen.vmaxKmh), MC.SLIDER_MAX_KMH)
	var bare := scen.duplicate()
	bare.erase("vmaxKmh")
	bare.erase("carCdA")
	var d0: Dictionary = MC.detach(bare)
	var d1: Dictionary = MC.detach(scen)
	assert_eq(d1.kmh, d0.kmh, "el mismo despegue con y sin las claves nuevas")
	assert_eq(d1.beyond, d0.beyond)
	var s0: Dictionary = MC.at_speed(bare, 120.0)
	var s1: Dictionary = MC.at_speed(scen, 120.0)
	assert_eq(s1.carDragN, s0.carDragN, "la misma resistencia del coche")
	assert_eq(s1.needN, s0.needN)
	var c0: Dictionary = MC.curve(bare)
	var c1: Dictionary = MC.curve(scen)
	assert_eq((c1.vKmh as PackedFloat64Array)[-1], (c0.vKmh as PackedFloat64Array)[-1], "la misma gráfica")
