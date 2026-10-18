## Estado de la tarjeta «Coche en marcha» (core/lab/moving_car_state.gd): da los mismos números que llamar a MovingCar
## a mano (setup, at_speed, detach, detach_verdict, curve, with_air, hold_report e impact, con los mismos parámetros);
## lo caro (hold_report e impact) sale igual con hilo que sin hilo, espera a soltar el deslizador y descarta lo que llega
## de unos parámetros que ya han cambiado; la zona y la postura siempre valen para el animal y el coche; los textos
## llevan los formatos de siempre, la banda del despegue y la calidad y la fuente de cada dato. Y la parte educativa y
## experimental: el porqué con los números de MovingCar, el «¿sabías que…?» con su fuente, la moraleja, los
## experimentos de un clic (los de la unidad 4d son sus casos de referencia), el sonido del golpe y la unidad 4d (el
## casuario que solo patea, el material de las garras, el animal asustado y las garras clavadas en la chapa).
extends "res://tests/case.gd"

const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const CF = preload("res://core/lab/claw_fracture.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Un estado sin hilos (lo caro, en el acto) con un animal y un coche.
static func state(claw_id: String, car := "coche", threaded := false) -> RefCounted:
	var st: RefCounted = MCS.new(C(claw_id), T(car))
	st.threaded = threaded
	return st


func test_sin_animal_con_datos_no_calcula() -> void:
	var st: RefCounted = MCS.new()
	assert_false(st.supported(), "con una uña no hay coche en marcha")
	assert_true(st.scen.is_empty() and st.at.is_empty() and st.chart.is_empty(), "ni setup ni fuerzas")
	st.set_claw(C("gato"))
	assert_false(st.supported(), "el gato no tiene datos aerodinámicos")
	assert_true(st.zones().is_empty() and st.postures().is_empty(), "sin zonas ni posturas")
	assert_false(st.heavy_pending(), "nada caro que lanzar")
	assert_false(st.finish(), "finish() no calcula nada")
	var names: Array = MCS.supported_animals().map(func(a: Dictionary) -> String: return a.id)
	# un animal con variantes sale una vez, con la de por defecto (el velocirraptor de película; unidad 4i-B2)
	var others: Array = MC.BODIES.keys().filter(func(k: String) -> bool: return MCS.animal_entry_id(k) != k)
	assert_eq(others, ["velociraptor"], "la reconstrucción del velocirraptor, a un clic de la de película")
	assert_eq(names, MC.BODIES.keys().filter(func(k: String) -> bool: return not others.has(k)),
		"los animales con datos, en el orden de MovingCar")
	assert_eq(String(MCS.supported_animals()[0].name), "Águila real", "nombre de la especie sin el latín")
	for id: String in names:
		st.set_claw(C(id))
		assert_true(st.supported(), "%s tiene datos" % id)
		# quieto encima, todos menos el que solo patea (el casuario: MovingCar.supports_hold)
		assert_eq(Js.truthy(st.scen.ok), MC.supports_hold(C(id)), "%s: setup solo si se queda encima" % id)


func test_mismos_numeros_que_movingcar_a_mano() -> void:
	for cfg: Array in [["aguila", "techo", "plegadas"], ["aguila", "retrovisor", "abiertas"], ["tigre", "ventanilla", "tumbado"], ["oso", "parabrisas", "de_pie"]]:
		var st := state(cfg[0])
		st.set_zone(cfg[1])
		st.set_posture(cfg[2])
		st.set_maneuver("frenada")
		st.set_wind(15.0, 10.0)
		st.set_speed(110.0)
		var tag := "%s %s %s" % cfg
		var p: Dictionary = st.hold_params()
		assert_eq(p.zone, cfg[1], "%s: zona" % tag)
		assert_eq(p.posture, cfg[2], "%s: postura" % tag)
		assert_eq(p.accel_g, -0.35, "%s: la frenada normal de MANEUVERS" % tag)
		var s := MC.setup(p)
		assert_true(same(st.at, MC.at_speed(s, 110.0)), "%s: at_speed" % tag)
		var cv := MC.curve(s)
		assert_true(same(st.chart, cv), "%s: la gráfica es curve(setup)" % tag)
		assert_true(same(st.det, MC.detach(s)), "%s: detach" % tag)
		assert_true(same(st.verdict, MC.detach_verdict(s, MC.detach(s))), "%s: veredicto" % tag)
		assert_eq(st.air_txt, MC.air_txt(s.air), "%s: el aire en palabras" % tag)
		assert_true(st.finish(), "%s: el informe llega" % tag)
		assert_true(same(st.report, MC.hold_report(p)), "%s: hold_report" % tag)
	var st := state("tigre")
	st.set_mode("impact")
	st.set_impact_zone("puerta")
	st.set_speed(50.0)
	st.set_impact("angle_deg", 90.0)
	st.set_impact("animal_kmh", 40.0)
	st.finish()
	assert_true(same(st.hit, MC.impact(st.impact_params())), "impact con los mismos parámetros")
	assert_eq(st.hit.verdict, "ABOLLA Y RAYA", "el tigre contra la puerta (caso tigre-puerta-coche-cruza)")


func test_el_aire_mueve_la_grafica_sin_repetir_el_ensayo() -> void:
	var st := state("aguila")
	var before: int = st.setup_version
	st.set_air(35.0, 2000.0)
	assert_eq(st.setup_version, before + 1, "la gráfica se recalcula")
	var p: Dictionary = st.hold_params()
	assert_eq([p.temp_c, p.altitude_m], [35.0, 2000.0], "el aire va en los parámetros")
	var s := MC.setup(p)
	assert_true(same(st.at, MC.at_speed(s, st.v_kmh)), "with_air da las fuerzas de setup con ese aire")
	assert_true(same(st.det, MC.detach(s)), "y el mismo despegue")
	assert_true(same(st.chart.need, MC.curve(s).need), "y la misma gráfica")
	assert_near(st.scen.rho, MC.air_density(35.0, 2000.0), 1e-12, 0.0, "densidad del aire elegido")
	assert_true(st.air_txt.contains("menos denso"), st.air_txt)
	st.finish()
	assert_true(same(st.report.detachRef, MC.detach(MC.setup(st.hold_params().merged({ "temp_c": 20.0, "altitude_m": 0.0 }, true)))),
		"el despegue de referencia es el de 20 °C al nivel del mar")
	var rows: Array = st.hold_rows()
	var ref_row: Array = rows.filter(func(r: Array) -> bool: return r[0] == "Con el aire de referencia")
	assert_eq(ref_row.size(), 1, "con otro aire, el informe da el despegue de referencia")


func test_con_hilo_da_lo_mismo_que_sin_hilo() -> void:
	var a := state("oso", "cochealu", false)
	var b := state("oso", "cochealu", true)
	for st: RefCounted in [a, b]:
		st.set_zone("techo")
		st.set_posture("de_pie")
		st.set_maneuver("emergencia")
		st.set_air(-5.0, 1200.0)
		st.set_speed(80.0)
		st.finish()
	assert_true(not b.report.is_empty() and same(a.report, b.report), "hold_report igual con hilo")
	for st: RefCounted in [a, b]:
		st.set_mode("impact")
		st.set_impact_zone("capo")
		st.set_impact("angle_deg", 180.0)
		st.set_impact("drop_m", 0.0)
		st.finish()
	assert_true(not b.hit.is_empty() and same(a.hit, b.hit), "impact igual con hilo")
	assert_eq(a.heavy_version, b.heavy_version, "los mismos resultados aplicados")


func test_lo_caro_espera_a_soltar_el_deslizador() -> void:
	var st := state("aguila")
	st.step(16.0)
	assert_true(st.heavy_fresh(), "sin arrastrar, el informe llega en el siguiente paso")
	st.set_dragging(true)
	for v: float in [100.0, 110.0, 120.0]:
		st.set_speed(v)
		st.step(16.0)
		assert_false(st.heavy_fresh(), "a %s km/h, arrastrando: el informe espera" % v)
	assert_near(st.at.vKmh, 120.0, 1e-12, 0.0, "las fuerzas sí van en directo")
	st.set_dragging(false)
	st.step(16.0)
	assert_true(st.heavy_fresh(), "al soltar, el informe llega")
	assert_near(st.report.at.vKmh, 120.0, 1e-12, 0.0, "y es el de 120 km/h")
	# el golpe se recalcula mientras se arrastra, como mucho cada DRAG_HEAVY_MS
	st.set_mode("impact")
	st.step(16.0)
	var n: int = st.heavy_version
	st.set_dragging(true)
	var launched := 0
	for i in 30:
		st.set_speed(60.0 + i)
		if st.step(16.0):
			launched += 1
	var want := int(30.0 * 16.0 / MCS.DRAG_HEAVY_MS)
	assert_true(launched >= want - 1 and launched <= want + 1, "unos pocos golpes mientras se arrastra: %d (≈ %d)" % [launched, want])
	assert_eq(st.heavy_version, n + launched, "cada uno, aplicado")
	st.set_dragging(false)
	st.step(16.0)
	assert_true(st.heavy_fresh() and st.hit.vRelKmh > 0.0, "al soltar, el golpe de la última velocidad")


func test_lo_que_llega_tarde() -> void:
	var st := state("halcon", "coche", true)
	st.step(0.0)  # lanza el informe de 90 km/h en un hilo
	st.set_speed(130.0)  # el mismo ensayo con el deslizador movido: el de 90 se enseña mientras llega el de 130
	var v0: int = st.heavy_version
	st.finish()
	assert_eq(st.heavy_version, v0 + 2, "los dos llegan, en orden")
	assert_true(st.heavy_fresh(), "al día")
	assert_near(st.report.at.vKmh, 130.0, 1e-12, 0.0, "el último es el de ahora")
	st.set_zone("capo")
	st.step(0.0)  # lanza el del capó…
	st.set_zone("maletero")  # … pero ya es otro ensayo: se descarta
	var v1: int = st.heavy_version
	st.finish()
	assert_eq(st.heavy_version, v1 + 1, "solo llega el del maletero")
	assert_eq(st.report.setup.zone, "maletero", "el informe es el de la zona de ahora")
	st.dispose()
	assert_false(st.heavy_pending(), "nada pendiente")


func test_la_zona_y_la_postura_siempre_valen() -> void:
	var st := state("aguila")
	st.set_zone("antena")
	st.set_posture("abiertas")
	assert_eq([st.zone, st.posture], ["antena", "abiertas"], "el águila en la antena, con las alas abiertas")
	st.set_claw(C("tigre"))
	assert_eq([st.zone, st.posture], [MCS.DEFAULT_ZONE, "tumbado"], "el tigre no se agarra a la antena: techo y agazapado")
	st.set_zone("retrovisor")
	assert_eq(st.zone, MCS.DEFAULT_ZONE, "ni al retrovisor")
	st.set_target(T("cocheplastico"))
	assert_eq([st.zone, st.impact_zone], ["aleta", "aleta"], "la aleta de plástico solo tiene sentido en la aleta")
	assert_eq(st.zones(), ["aleta"], "zonas con la aleta de plástico")
	assert_eq(st.impact_zones(), ["aleta"], "zonas del golpe con la aleta de plástico")
	st.set_embedded(true)
	assert_true(st.embedded and st.scen.anchor == "gancho", "garras clavadas en el plástico: gancho")
	st.set_target(T("coche"))
	assert_false(st.embedded, "en el metal no se clavan")
	st.set_target(T("piel"))
	assert_eq(st.target.id, "coche", "solo coches")
	st.set_maneuver("curva_fuerte")
	assert_eq([st.accel_g, st.lateral_g], [0.0, 0.8], "la curva al límite de MANEUVERS")
	st.set_maneuver("no-existe")
	assert_eq(st.maneuver, "curva_fuerte", "una maniobra desconocida no cambia nada")


func test_la_senal_changed_y_las_versiones() -> void:
	var st := state("aguila")
	var hits := [0]
	st.changed.connect(func() -> void: hits[0] += 1)
	var sv: int = st.setup_version
	var lv: int = st.live_version
	st.set_speed(40.0)
	assert_eq(hits[0], 1, "cambiar la velocidad avisa")
	assert_eq([st.setup_version, st.live_version], [sv, lv + 1], "solo cambian las fuerzas")
	st.set_speed(40.0)
	assert_eq(hits[0], 1, "la misma velocidad no avisa")
	st.set_zone("capo")
	assert_eq(st.setup_version, sv + 1, "otra zona: otro setup")
	st.step(16.0)
	assert_true(hits[0] >= 3, "el informe también avisa al llegar")


func test_formatos_de_siempre() -> void:
	assert_eq(MCS.fmt_n(7.77397), "7.8 N", "N con un decimal por debajo de 10")
	assert_eq(MCS.fmt_n(2647.89), "2648 N", "sin decimales desde 10 N")
	assert_eq(MCS.fmt_n(-2647.89), "-2648 N", "con su signo")
	assert_eq(MCS.fmt_n(-0.01), "0.0 N", "sin «-0.0»")
	assert_eq(MCS.fmt_n(71548.08), "71.5 kN", "kN desde 10 kN, como MovingCar")
	assert_eq(MCS.fmt_n(3.032e6), "3.0 MN", "MN desde 1 MN, no «3032.0 kN» (unidad 4o)")
	assert_eq(MCS.fmt_n(-3.032e6), "-3.0 MN", "con su signo")
	assert_eq(MCS.fmt_n(999000.0), "999.0 kN", "por debajo de 1 MN, kN")
	assert_eq(MCS.fmt_kmh(195.75), "196 km/h", "km/h sin decimales")
	assert_eq(MCS.fmt_kmh(INF), "∞ km/h", "sin despegue: ∞")
	assert_eq(MCS.fmt_w(194.35), "194 W", "W")
	assert_eq(MCS.fmt_w(6138.18), "6.1 kW", "kW")
	assert_eq(MCS.fmt_pct(0.1674), "17 %", "tanto por ciento")
	assert_eq(MCS.fmt_pct(INF), "∞ %", "sin fuerza disponible: ∞")
	assert_eq(MCS.fmt_band({ "value": -0.45, "min": -0.64, "max": -0.3 }), "-0.45 (-0.64…-0.3)", "banda de un dato")
	assert_eq(MCS.fmt_band({ "value": 0.685, "min": 0.597, "max": 0.75 }, "m²"), "0.685 m² (0.597…0.75 m²)", "banda con unidad")
	assert_eq(MCS.fmt_band({ "value": 1.0, "min": 1.0, "max": 1.0 }), "1", "sin banda, el valor solo")
	var st := state("aguila")
	st.set_speed(90.0)
	var rows := {}
	for r: Dictionary in st.hold_readings():
		rows[r.id] = r
	assert_eq(rows.resistencia.value, MCS.fmt_n(st.at.dragN), "resistencia")
	assert_eq(rows.resistencia.value, "7.8 N", "el águila plegada en el techo a 90 km/h (coche-en-marcha.md §2.2)")
	assert_eq(rows.sustentacion.value, "2.6 N", "sustentación")
	assert_eq(rows.peso.value, "49 N", "peso")
	assert_eq(rows.aire.value, MCS.fmt_kmh(st.at.localKmh), "aire en el animal")
	assert_eq(rows.carga.value, MCS.fmt_pct(st.at.loadRatio), "carga")
	assert_eq(rows.necesaria.sub, "banda de %s a %s" % [MCS.fmt_n(st.at.needMinN), MCS.fmt_n(st.at.needMaxN)], "con su banda")
	assert_eq(rows.potencia.value, MCS.fmt_w(st.at.powerW), "potencia")
	assert_eq(rows.reparto.value, MCS.fmt_pct(st.at.dragShare), "reparto frente al coche")


## Unidad 4j: los formatos del coche en marcha viven en un solo sitio (core/lab/car_format.gd). Los nombres de antes, en
## MovingCar y en MovingCarState, delegan allí y dan los mismos textos; en el código de esos dos archivos no queda ninguna
## otra forma de escribir kN, kW, kJ, metros ni milisegundos.
func test_los_formatos_viven_en_un_solo_sitio() -> void:
	var vals := [-20000.0, -2647.89, -0.04, 0.0, 0.004, 0.049, 0.05, 0.3, 7.77397, 9.99, 10.0, 112.5, 999.5, 1000.0, 2647.89, 9999.4,
		10000.0, 71548.08, 2.5e6, INF]
	for v: float in vals:
		assert_eq(MCS.fmt_n(v), CarFormat.fmt_n(v), "fuerza %s" % v)
		assert_eq(MCS.fmt_kmh(v), CarFormat.fmt_kmh(v), "velocidad %s" % v)
		assert_eq(MCS.fmt_w(v), CarFormat.fmt_w(v), "potencia %s" % v)
		assert_eq(MCS.fmt_pct(v / 1000.0), CarFormat.fmt_pct(v / 1000.0), "tanto por ciento %s" % v)
		assert_eq(MCS.fmt_share(v / 1000.0), CarFormat.fmt_share(v / 1000.0), "parte %s" % v)
		assert_eq(MCS.fmt_g(v / 1000.0), CarFormat.fmt_g(v / 1000.0), "aceleración %s" % v)
		assert_eq(MCS.num(v), CarFormat.num(v), "número %s" % v)
		assert_eq(MC._kmh_txt(v), CarFormat.kmh_txt(v), "velocidad sin unidad %s" % v)
		if v >= 0.0:
			# MovingCar solo escribe fuerzas, longitudes y energías que no son negativas
			assert_eq(MC._fmt_n(v), CarFormat.fmt_n(v), "fuerza de MovingCar %s" % v)
			assert_eq(MC.fmt_long(v), CarFormat.fmt_long(v), "longitud %s µm" % v)
			assert_eq(MC.fmt_energy(v), CarFormat.fmt_energy(v), "energía %s J" % v)
	assert_eq(MCS.fmt_n_band(2.8, 17.6), CarFormat.fmt_n_band(2.8, 17.6), "banda de fuerzas")
	assert_eq(MCS.fmt_band({ "value": -0.45, "min": -0.64, "max": -0.3 }), CarFormat.fmt_band({ "value": -0.45, "min": -0.64, "max": -0.3 }), "banda")
	# la rotura de las garras (ClawFracture) también escribe sus fuerzas con CarFormat: en mN por debajo de 0,05 N (4i-B2)
	for f: float in [0.0, 3.7e-6, 0.0023, 0.013, 0.049, 0.05, 0.4, 48.0, 390.0, 12000.0]:
		assert_eq(CF._fmt_n(f), CarFormat.fmt_n_small(f), "fuerza de la rotura %s" % f)
	assert_eq(CarFormat.fmt_n_small(0.013), "13 mN", "una punta afilada aguanta milinewtons")
	assert_eq(CarFormat.fmt_n_small(390.0), "390 N", "y lo de siempre, en N")
	# los textos de siempre
	assert_eq(CarFormat.fmt_long(1.6e6), "1.6 m", "metros desde 1 m")
	assert_eq(CarFormat.fmt_long(245000.0), "245 mm (24.5 cm)", "mm con cm")
	assert_eq(CarFormat.fmt_energy(34812.0), "34.8 kJ", "kJ desde 1000 J")
	assert_eq(CarFormat.fmt_energy(720.0), "720 J", "J")
	assert_eq(CarFormat.fmt_ms(0.2071), "207 ms", "milisegundos")
	assert_eq(CarFormat.fmt_share(0.0004), "<0.1 %", "una parte que no llega al 0,1 %")
	assert_eq(CarFormat.fmt_share(0.004), "0.4 %", "con su decimal por debajo del 1 %")
	assert_eq(CarFormat.fmt_mps(4.8407, 2), "4.84 m/s", "el salto en m/s")
	assert_eq(CarFormat.fmt_m(1.19456, 2), "1.19 m", "lo que sube, en m")
	assert_eq(CarFormat.fmt_kmh1(0.2349), "0.2 km/h", "lo que le quita el aire, con un decimal")
	for f: String in ["res://core/lab/moving_car.gd", "res://core/lab/moving_car_state.gd", "res://core/lab/claw_fracture.gd"]:
		var raw := FileAccess.get_file_as_string(f)
		for pat: String in ['+ " kN"', '+ " kW"', '+ " kJ"', '+ " m"', '+ " ms"', '+ " km/h"', '+ " %"', '+ " g"', '+ " J"', '+ " N"', '+ " W"']:
			assert_false(raw.contains(pat), "%s: «%s» solo en car_format.gd" % [f.get_file(), pat])


func test_la_banda_siempre_va_con_el_valor_central() -> void:
	var st := state("aguila")
	var b: Dictionary = st.band()
	assert_eq([b.lo, b.hi], [st.det.minKmh, st.det.maxKmh], "la banda de detach")
	assert_true(String(b.text).contains("79 km/h") and String(b.text).contains("296 km/h"), b.text)
	assert_true(String(b.central).contains("196 km/h"), b.central)
	assert_eq(st.verdict_color(), "coral", "se suelta hacia 196 km/h: dentro del deslizador (hasta 230)")
	var tiger := state("tigre")
	assert_true(tiger.det.beyond, "el tigre agazapado se soltaría hacia 340 km/h")
	assert_eq(tiger.verdict_color(), "mint", "aguanta en todo el deslizador")
	st.set_posture("abiertas")
	assert_true(String(st.band().text).contains("14 km/h") and String(st.band().text).contains("35 km/h"), st.band().text)
	assert_eq(st.verdict_color(), "gold", "con las alas abiertas despega: vuela")
	st.set_speed(40.0)
	assert_eq(st.now_color(), "gold", "y a 40 km/h, lo mismo: %s" % st.now_text())
	st.set_zone("retrovisor")
	st.set_posture("plegadas")
	assert_true(String(st.band().hi_txt).contains("no se suelta"), "con todo a favor no se suelta: %s" % st.band().hi_txt)
	assert_true(String(st.band().text).ends_with("; con todo a favor, no se suelta ni a 400 km/h"),
		"un extremo que no es una velocidad va en una frase: %s" % st.band().text)
	var bear := state("oso")
	bear.set_posture("de_pie")
	bear.set_maneuver("emergencia")
	assert_eq(bear.band().lo_txt, "ni parado", "con todo en contra, ni parado")
	assert_true(String(bear.band().text).begins_with("Banda de los datos: con todo en contra, ni parado se sostiene; "),
		"y no «de ni parado»: %s" % bear.band().text)
	# parado, la frenada lo tira; más deprisa, el viento de cara compensa la inercia: aguanta en una ventana
	var from: float = bear.det.holdFromKmh
	assert_true(from > 55.0 and from < 70.0, "de pie en el techo aguanta desde ~62 km/h: %s" % from)
	assert_eq(bear.band().central, "solo aguanta por encima de ~%s" % MCS.fmt_kmh(from), "frenada de emergencia: el central")
	assert_eq(bear.verdict_color(), "coral", "no aguanta")
	bear.set_speed(90.0)
	assert_true(bear.now_text().begins_with("A 90 km/h: aguanta"), "a 90 km/h el viento compensa la frenada: %s" % bear.now_text())
	assert_eq(bear.now_color(), "mint", "aguanta: menta")
	bear.set_speed(20.0)
	assert_eq(bear.now_color(), "coral", "a 20 km/h lo tira la frenada: %s" % bear.now_text())
	assert_true(bear.now_band_text().contains("en contra se suelta"), bear.now_band_text())


func test_cada_estimacion_va_marcada_con_su_fuente() -> void:
	for id: String in ["tigre", "aguila"]:
		var st := state(id)
		var src: Array = st.sources()
		assert_true(src.size() >= 6, "%s: fuentes del ensayo (%d)" % [id, src.size()])
		for r: Dictionary in src:
			assert_true(String(r.source).length() > 10, "%s: «%s» tiene fuente" % [id, r.label])
			assert_true(["", "primary", "secondary", "estimate"].has(r.quality), "%s: calidad de «%s»" % [id, r.label])
		var est := src.filter(func(r: Dictionary) -> bool: return r.quality == "estimate")
		assert_true(est.size() >= 3, "%s: hay estimaciones marcadas (%d)" % [id, est.size()])
		for r: Dictionary in st.hold_readings():
			if r.id == "resistencia":
				assert_eq(r.quality, "estimate", "%s: la resistencia es una estimación" % id)
	var tiger := state("tigre")
	var cd: Array = tiger.sources().filter(func(r: Dictionary) -> bool: return String(r.label).begins_with("Cd"))
	assert_eq(cd.size(), 1, "Cd del tigre")
	assert_eq(cd[0].quality, "estimate", "sin túnel: estimación")
	assert_true(String(cd[0].source).contains("Hoerner"), "cuerpo romo de Hoerner 1965: %s" % cd[0].source)
	assert_eq(cd[0].value, "0.7 (0.5…0.9)", "con su banda")
	tiger.set_mode("impact")
	tiger.finish()
	var terms: Array = tiger.sources().filter(func(r: Dictionary) -> bool: return String(r.label).begins_with("Energía"))
	assert_eq(terms.size(), 6, "los seis términos del balance con su fuente")
	var animal: Array = terms.filter(func(r: Dictionary) -> bool: return String(r.label).contains("animal"))
	assert_eq(animal[0].quality, "estimate", "lo que se queda el animal: estimación")
	# con las alas abiertas y el aire por detrás (viento de cola más fuerte que la velocidad del coche), la sustentación es
	# la del ala al revés: una estimación, con su fuente (unidad 4g); de cara, el CL máximo medido
	var eagle := state("aguila")
	eagle.set_posture("abiertas")
	eagle.set_wind(-60.0, 0.0)
	eagle.set_speed(10.0)
	var lift: Dictionary = eagle.hold_readings().filter(func(r: Dictionary) -> bool: return r.id == "sustentacion")[0]
	assert_eq(lift.quality, "estimate", "con el aire por detrás, el CL al revés es una estimación")
	assert_true(String(lift.source).contains("Sheldahl"), lift.source)
	eagle.set_speed(90.0)
	lift = eagle.hold_readings().filter(func(r: Dictionary) -> bool: return r.id == "sustentacion")[0]
	assert_eq(lift.quality, "secondary", "de cara, el CL máximo medido")


func test_capas_y_color_de_los_surcos() -> void:
	var st := state("aguila")
	var L: Array = st.layers_view()
	assert_eq(L.size(), 5, "cuatro capas de pintura y la chapa")
	assert_eq(L.map(func(l: Dictionary) -> String: return l.state), ["rayada", "rayada", "rayada", "rayada", "intacta"],
		"el águila raya las cuatro capas y no corta la chapa")
	assert_eq(st.groove_color(), String(Catalog.car_layers(st.target)[3].col), "fondo del surco: el anticorrosivo")
	var rows: Array = st.hold_rows()
	assert_true(rows.any(func(r: Array) -> bool: return r[0] == "Perforación" and String(r[1]).begins_with("no: la queratina")), "no perfora")
	assert_true(rows.any(func(r: Array) -> bool: return r[0] == "Capas que raya" and String(r[1]).contains("llega a la chapa sin cortarla")),
		"llega a la chapa sin cortarla")
	var tiger := state("tigre", "cocheplastico")
	tiger.set_mode("impact")
	tiger.finish()
	assert_true(tiger.hit.puncture.through, "el tigre atraviesa la aleta")
	assert_true(tiger.layers_view().all(func(l: Dictionary) -> bool: return l.state == "atravesada"), "todas atravesadas")
	assert_eq(tiger.groove_color(), String(Catalog.car_layers(tiger.target)[4].col), "fondo: el plástico")
	assert_eq(tiger.energy_terms(), tiger.hit.energy.terms, "la barra de energía son los términos de impact")


func test_por_donde_llega_el_golpe() -> void:
	var st := state("tigre")
	st.set_mode("impact")
	st.set_impact_zone("puerta")
	st.set_speed(50.0)
	st.set_impact("animal_kmh", 40.0)
	st.set_impact("angle_deg", 90.0)
	var a: Dictionary = st.arrival()
	assert_near(a.x, -1.0, 1e-12, 1e-12, "cruzando, en el costado viene del frente del coche")
	assert_near(a.lateral, 40.0 / sqrt(40.0 * 40.0 + 50.0 * 50.0), 1e-9, 1e-12, "y de lado")
	st.set_impact_zone("techo")
	st.set_impact("angle_deg", 0.0)
	st.set_impact("animal_kmh", 56.0)
	assert_true(st.arrival().x > 0.0 and st.arrival().z < 0.0, "persiguiendo, cae sobre el techo desde atrás")
	st.set_impact("drop_m", 0.0)
	assert_eq(st.arrival().z, 0.0, "sin caída, a ras del panel")


## La unidad 4d en el estado: el casuario solo patea (no se queda encima), con su sexo; el material de las garras y el
## animal asustado van a MovingCar con sus nombres de la guía (§9.1) y dan lo mismo que llamarlo a mano.
func test_el_casuario_solo_patea() -> void:
	var st := state("casuario")
	assert_true(st.supported() and not st.supports_hold(), "tiene datos, pero no se queda encima")
	assert_eq(st.mode, "impact", "empieza en el golpe")
	assert_eq(String(st.scen.reason), MC.HOLD_NO_REASON, "y dice por qué, con el texto de MovingCar")
	st.set_mode("hold")
	assert_eq(st.mode, "impact", "no se puede poner encima")
	assert_eq(st.postures(), [], "sin posturas de quedarse encima")
	assert_eq(st.impact_zones(), MC.KICK_ZONES, "patea lo que tiene a la altura de las patas")
	assert_eq(st.impact_zone, "puerta", "la puerta, por defecto")
	assert_eq(st.sexes(), MC.SEXES, "hembra o macho")
	st.set_speed(50.0)
	st.set_impact("animal_kmh", 0.0)
	st.finish()
	var p: Dictionary = st.impact_params()
	assert_eq(p.sex, "hembra", "la hembra, por defecto")
	assert_eq(st.hit, MC.impact(p), "el golpe, igual que a mano")
	assert_eq(st.hit.attack, "patada", "patea")
	assert_eq(float(st.hit.kick.massKg), float(MC.BODIES.casuario.mass_kg.hembra.value), "la masa de la hembra")
	st.set_sex("macho")
	st.finish()
	assert_eq(float(st.hit.kick.massKg), float(MC.BODIES.casuario.mass_kg.macho.value), "el macho, más ligero")
	var why: String = st.why_text()
	assert_true(why.begins_with("Patea: salta con los pies por delante a ~%s" % MCS.fmt_kmh(st.hit.kick.leapKmh)), "el porqué de la patada: %s" % why)
	assert_true(why.contains(MCS.fmt_n(st.hit.kick.forceCapN)), "con la fuerza máxima de su pata: %s" % why)
	var facts: Array = st.facts()
	assert_true(facts.any(func(f: Dictionary) -> bool: return f.source == MC.SRC_KOFRON_CHAPMAN), "¿sabías que…? los coches y el casuario")
	assert_true(st.moral().begins_with("El casuario no se sube al coche"), "moraleja de la patada: %s" % st.moral())
	assert_eq(float(st.draw_size().heightM), float(MC.BODIES.casuario.height_m), "su tamaño para el dibujo, de BODIES")
	st.set_impact_zone("techo")
	assert_eq(st.impact_zone, "puerta", "el techo no le llega")
	# el modo elegido se recuerda: encima → casuario (solo el golpe) → águila, otra vez encima
	var eagle := state("aguila")
	assert_eq(eagle.mode, "hold", "el águila, encima")
	eagle.set_claw(C("casuario"))
	assert_eq(eagle.mode, "impact", "el casuario, en el golpe")
	eagle.set_claw(C("aguila"))
	assert_eq(eagle.mode, "hold", "de vuelta al águila, otra vez encima")
	# el golpe de otro animal no se enseña mientras llega el suyo (sus textos mezclarían dos animales)
	var t := state("tigre")
	t.set_mode("impact")
	t.set_claw(C("casuario"))
	t.finish()
	assert_eq(String(t.hit.attack), "patada", "la patada del casuario")
	t.set_claw(C("tigre"))
	assert_eq(t.mode, "impact", "el tigre, en el golpe que se eligió")
	assert_true(t.hit.is_empty(), "sin la patada del casuario")
	assert_eq(t.facts(), [], "ni sus datos")
	assert_eq(t.why_text(), "", "ni su porqué")
	t.finish()
	assert_eq(String(t.hit.attack), "golpe", "hasta que llega el del tigre")


func test_material_de_las_garras_y_defensa_van_a_movingcar() -> void:
	var st := state("tigre")
	st.set_inlay("zafiro")
	st.set_mode("impact")
	st.set_impact_zone("puerta")
	st.set_speed(50.0)
	st.set_impact("animal_kmh", 40.0)
	st.set_impact("angle_deg", 90.0)
	st.finish()
	var p: Dictionary = st.impact_params()
	assert_eq(p.inlay, "zafiro", "el material, por su id de Data.INLAYS")
	assert_eq(st.hit, MC.impact(p), "el golpe con garras de zafiro, igual que a mano")
	assert_eq(String(st.hit.clawFracture.mode), "mella", "el zafiro se mella (el caso tigre-zafiro-puerta)")
	assert_eq(st.impact_sfx(), "snap", "suena la garra que se rompe")
	assert_true(st.why_text().contains("sí cortan"), "el porqué: el zafiro sí corta el acero: %s" % st.why_text())
	assert_true(st.why_text().contains(String(st.hit.clawFracture.vsub)), "y lo que le pasa, con el texto de ClawFracture")
	assert_true(st.moral().begins_with("Duro no es lo mismo que tenaz"), "moraleja: %s" % st.moral())
	var tiles: Array = st.impact_readings().filter(func(r: Dictionary) -> bool: return r.id == "garras")
	assert_eq(tiles.size(), 1, "una ficha de la rotura")
	assert_true(String(tiles[0].sub).contains(MCS.fmt_n(st.hit.clawFracture.limitMinN)), "con su banda: %s" % tiles[0].sub)
	# garras más blandas que la chapa: ceden como la queratina
	st.set_inlay("oro")
	st.finish()
	assert_true(st.why_text().begins_with("No perfora porque sus garras de oro"), "el oro no corta el acero: %s" % st.why_text())
	# asustado, en el golpe: la fuerza de defensa con su banda
	st.set_inlay("none")
	st.set_defense(true)
	st.finish()
	assert_true(st.impact_params().defense, "defense a MovingCar")
	var d: Array = st.impact_readings().filter(func(r: Dictionary) -> bool: return r.id == "defensa")
	assert_eq(d.size(), 1, "la ficha de la defensa")
	var f: Dictionary = st.hit.defense.forceN
	assert_eq(d[0].value, MCS.fmt_n(f.value), "fuerza por mano")
	assert_true(String(d[0].sub).contains(MCS.fmt_n_band(f.min, f.max)), "con su banda: %s" % d[0].sub)
	assert_eq(d[0].quality, "estimate", "estimación, marcada")


func test_asustada_la_lechuza_aguanta_mas() -> void:
	var st := state("lechuza")
	st.set_zone("techo")
	st.set_speed(90.0)
	var rest: Dictionary = st.det.duplicate()
	st.set_defense(true)
	st.finish()
	var p: Dictionary = st.hold_params()
	assert_true(p.defense, "defense a MovingCar")
	var s := MC.setup(p)
	assert_eq(st.det, MC.detach(s), "el despegue asustada, el de MovingCar")
	assert_eq(st.det_rest, rest, "y el de sin asustarse, para comparar")
	assert_true(float(st.det.kmh) > float(rest.kmh), "asustada aguanta más (arado de la pintura)")
	var why: String = st.why_text()
	assert_true(why.contains("Asustada, se suelta a ~%s (sin asustarse, se suelta a ~%s)" % [MCS.fmt_kmh(st.det.kmh), MCS.fmt_kmh(rest.kmh)]),
		"el porqué compara: %s" % why)
	assert_true(st.moral().begins_with("El miedo agarra"), "moraleja: %s" % st.moral())
	var rows: Array = st.hold_rows()
	var dfn: Dictionary = st.scen.defense
	assert_true(rows.any(func(r: Array) -> bool: return r[0] == "Defensa" and String(r[1]).contains(String(dfn.vsub))), "la fila Defensa, con el texto de MovingCar")
	assert_true(rows.any(func(r: Array) -> bool: return String(r[0]).begins_with("Desgarros")), "y sus desgarros")
	var tiles: Array = st.hold_readings().filter(func(r: Dictionary) -> bool: return r.id == "defensa" or r.id == "arado")
	assert_eq(tiles.size(), 2, "fuerza de defensa y arado de más")
	assert_true(String(tiles[1].sub).contains(MCS.fmt_n_band(dfn.rakeN.min, dfn.rakeN.max)), "el arado con su banda: %s" % tiles[1].sub)
	assert_eq(st.hold_marks(), dfn.tear, "las marcas encima son los desgarros")


func test_talones_de_tungsteno_clavados() -> void:
	var st := state("aguila")
	st.set_embedded(true)
	assert_false(st.embedded, "con queratina no se clava en la chapa")
	st.set_inlay("tungsteno")
	st.set_embedded(true)
	assert_true(st.embedded, "el tungsteno corta la chapa: puede quedar clavado")
	st.set_speed(150.0)
	st.finish()
	assert_true(st.det.never, "no se suelta ni a 400 km/h (el caso aguila-tungsteno-techo-clavada)")
	assert_true(st.why_text().contains("sus garras clavadas en la chapa"), "el porqué: %s" % st.why_text())
	assert_true(st.moral().contains("parte de la carrocería"), "moraleja: %s" % st.moral())
	assert_true(st.hold_readings().any(func(r: Dictionary) -> bool: return r.id == "clavadas"), "lo que aguantan de lado, con su banda")
	st.set_inlay("oro")
	assert_false(st.embedded, "el oro no corta la chapa: deja de estar clavado")


func test_experimentos_de_un_clic() -> void:
	var st := state("aguila")
	for e: Dictionary in MCS.EXPERIMENTS:
		if e.has("air"):
			continue
		var v0: int = st.setup_version
		assert_true(st.load_experiment(e.id), "%s se carga" % e.id)
		assert_eq(st.setup_version, v0 + 1, "%s: un solo setup" % e.id)
		assert_true(st.experiment_matches(e.id), "%s: lo que se ve es el experimento" % e.id)
		assert_eq(String(st.claw.id), String(e.claw), "%s: su animal" % e.id)
		assert_eq(st.mode, String(e.mode), "%s: su modo" % e.id)
		assert_eq(st.inlay, String(e.get("inlay", "none")), "%s: sus garras" % e.id)
		assert_eq(st.defense, bool(e.get("defense", false)), "%s: asustado o no" % e.id)
		assert_false(st.custom_air(), "%s: con el aire de referencia" % e.id)
		assert_true(MCS.experiment_tip(e.id).begins_with(MCS.species_name(String(e.claw))), "%s: su ayuda" % e.id)
	# los de la unidad 4d son sus casos de referencia: lo mismo que MovingCar con esos datos
	st.load_experiment("lechuza_asustada")
	var s := MC.setup({ "claw": C("lechuza"), "target": T("coche"), "zone": "techo", "posture": "plegadas", "defense": true, "model": "2.0" })
	assert_eq(st.det, MC.detach(s), "la lechuza asustada")
	st.load_experiment("casuario_puerta")
	st.finish()
	assert_eq(st.hit, MC.impact({ "claw": C("casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 0.0,
		"angle_deg": 90.0, "car_mass_kg": 1400.0, "sex": "hembra", "inlay": "none", "defense": false, "drop_m": 0.5, "temp_c": 20.0,
		"altitude_m": 0.0, "model": "2.0" }), "la patada del casuario hembra")
	# «aire»: el mismo experimento a 35 °C y 2000 m, y otra vez al de referencia
	st.load_experiment("aguila_120")
	assert_false(st.experiment_matches("aire"), "sin el aire de montaña")
	st.load_experiment("aire")
	assert_eq([st.temp_c, st.altitude_m], [35.0, 2000.0], "35 °C y 2000 m")
	assert_true(st.experiment_matches("aguila_120") and st.experiment_matches("aire"), "los dos a la vez")
	st.load_experiment("aire")
	assert_false(st.custom_air(), "otra vez: vuelve al aire de referencia")
	st.set_speed(100.0)
	assert_false(st.experiment_matches("aguila_120"), "al mover la velocidad ya es otro ensayo")
	assert_true(st.experiment_shown("aire"), "«aire», con el animal encima")
	st.set_mode("impact")
	assert_false(st.experiment_shown("aire"), "en el golpe no se enseña")
	assert_false(st.load_experiment("no_existe"), "uno que no existe no carga nada")


func test_el_porque_con_los_numeros_de_movingcar() -> void:
	# el viento: águila plegada en el techo (se suelta hacia 196 km/h, dentro del deslizador, que llega a 230)
	var st := state("aguila")
	var a := MC.at_speed(st.scen, st.det.kmh)
	var why: String = st.why_text()
	assert_true(why.begins_with("La suelta el viento: a ~196 km/h"), "lo suelta el viento: %s" % why)
	assert_true(why.contains(MCS.fmt_n(a.dragN)) and why.contains(MCS.fmt_kmh(a.localKmh)), "con la resistencia y el aire local donde se suelta")
	# la sustentación: alas abiertas
	st.set_posture("abiertas")
	a = MC.at_speed(st.scen, st.det.kmh)
	why = st.why_text()
	# unidad 4o: no se suelta, vuela (como su veredicto): la levanta su propia sustentación
	assert_true(why.begins_with("La levanta su propia sustentación") and why.contains(MCS.fmt_n(a.liftN)), "las alas: %s" % why)
	assert_true(st.moral().contains("no está agarrada: está volando"), "la moraleja de la guía (§9.4): %s" % st.moral())
	# la frenada: el oso tumbado en el capó, en una de emergencia (ni parado ni a 400 km/h se sostiene)
	var oso := state("oso")
	oso.set_zone("capo")
	oso.set_maneuver("emergencia")
	var a0 := MC.at_speed(oso.scen, 0.0)
	why = oso.why_text()
	assert_true(why.begins_with("Lo tira la frenada, aun con el coche parado"), "la frenada: %s" % why)
	assert_true(why.contains(MCS.fmt_n(absf(a0.inertiaN))) and why.contains(MCS.fmt_n(a0.availN)), "con la inercia y lo que da el roce: %s" % why)
	# tumbado en el techo aguantaría desde ~270 km/h, fuera del deslizador: se explica como «ni parado» y se dice desde dónde
	oso.set_zone("techo")
	assert_true(float(oso.det.holdFromKmh) > MC.SLIDER_MAX_KMH, "la ventana empieza fuera del deslizador")
	why = oso.why_text()
	assert_true(why.begins_with("Lo tira la frenada, aun con el coche parado"), "tumbado en el techo: %s" % why)
	assert_true(why.contains(" Solo por encima de ~%s aguantaría: el viento de cara compensa la inercia y lo sujeta." % MCS.fmt_kmh(oso.det.holdFromKmh)), why)
	# de pie en el techo, más deprisa el viento de cara compensa la frenada: aguanta desde ~62 km/h (una ventana)
	oso.set_zone("techo")
	oso.set_posture("de_pie")
	oso.set_speed(90.0)
	assert_true(oso.at.holds, "de pie, a 90 km/h, aguanta")
	var edge := MC.at_speed(oso.scen, float(oso.det.holdFromKmh))
	why = oso.why_text()
	assert_true(why.begins_with("Lo suelta la frenada al bajar de ~%s: " % MCS.fmt_kmh(oso.det.holdFromKmh)), "la ventana: %s" % why)
	assert_true(why.contains(MCS.fmt_n(edge.dragN)) and why.contains(MCS.fmt_n(edge.availN)), "con el aire y el roce donde empieza: %s" % why)
	assert_true(why.ends_with(" Más deprisa, el viento de cara compensa la inercia y lo sujeta: no se suelta ni a 400 km/h."), why)
	assert_true(oso.moral().begins_with("Al frenar, lo peligroso es el final: el oso pardo aguanta mientras el coche va deprisa"), oso.moral())
	# la queratina y el acero, en el golpe
	var tigre := state("tigre")
	tigre.set_mode("impact")
	tigre.set_impact_zone("puerta")
	tigre.finish()
	why = tigre.why_text()
	assert_true(why.begins_with("No perfora porque la queratina de sus garras (30 HV) es más blanda que el acero de horno"), "queratina contra acero: %s" % why)
	assert_true(why.contains("(101 HV)") and why.contains(MCS.num(0.8)), "con las durezas y el criterio del motor")
	assert_eq(tigre.impact_sfx(), "scratch-metal", "suenan los surcos hasta el metal")


## Unidad 4o: un ave con las alas abiertas que despega no «se suelta»: vuela. El despegue de la banda, la frase de la banda
## de ahora y el porqué lo dicen como su veredicto («despega», «la levanta»); plegada, se suelta como siempre.
func test_un_ave_que_despega_no_se_suelta() -> void:
	var st := state("aguila")
	st.set_posture("abiertas")
	assert_eq(String(st.det.mode), "despega", "con las alas abiertas despega")
	assert_eq(String(st.band().central), "despega a ~%s" % MCS.fmt_kmh(st.det.kmh), "el despegue de la banda")
	st.set_speed(150.0)
	assert_false(st.at.holds or st.at.holdsLo or st.at.holdsHi, "a 150 km/h vuela con todos los datos")
	assert_eq(st.now_band_text(), "Con todos los datos, en contra o a favor, despega", "la banda de ahora, sin repetir")
	assert_true(String(st.why_text()).begins_with("La levanta su propia sustentación"), st.why_text())
	st.set_posture("plegadas")
	assert_eq(String(st.band().central), "se suelta a ~%s" % MCS.fmt_kmh(st.det.kmh), "plegada, se suelta")
	# un mamífero nunca despega: se suelta
	var oso := state("oso")
	oso.set_zone("capo")
	oso.set_maneuver("emergencia")
	assert_eq(oso.now_band_text(), "Con todos los datos, en contra o a favor, se suelta", "el oso en la frenada")


## Unidad 4o: las lecturas del animal quieto encima sin números vacíos. Parado y sin viento no hay aire: la fuerza necesaria
## es la misma con todos los datos («igual con todos los datos», no «banda de 3119 N a 3119 N») y no hay resistencia del
## coche con la que comparar («sin aire», no «0 % de los 0.0 N»). Con aire, cada banda sale de los dos lados: en la frenada,
## el aire que más empuja hacia atrás pide menos fuerza, así que la banda de la necesaria rodea al valor central.
func test_las_lecturas_sin_aire_y_con_las_dos_bandas() -> void:
	var oso := state("oso")
	oso.set_zone("capo")
	oso.set_posture("tumbado")
	oso.set_maneuver("emergencia")
	oso.set_speed(0.0)
	var rows := {}
	for r: Dictionary in oso.hold_readings():
		rows[r.id] = r
	assert_eq(oso.at.needMinN, oso.at.needMaxN, "parado, la misma fuerza con todos los datos")
	assert_eq(rows.necesaria.sub, "igual con todos los datos", "sin «banda de %s a %s»" % [MCS.fmt_n(oso.at.needMinN), MCS.fmt_n(oso.at.needMaxN)])
	assert_eq(rows.disponible.sub, "banda %s" % CarFormat.fmt_n_band(oso.at.availMinN, oso.at.availMaxN), "el roce sí tiene banda")
	assert_eq([rows.reparto.value, rows.reparto.sub], ["sin aire", "el coche tampoco tiene resistencia que comparar"], "sin aire")
	oso.set_speed(60.0)
	rows.clear()
	for r: Dictionary in oso.hold_readings():
		rows[r.id] = r
	assert_true(oso.at.needMinN < oso.at.needN and oso.at.needN < oso.at.needMaxN, "la banda rodea al valor central: %s" % [oso.at])
	assert_eq(rows.necesaria.sub, "banda %s" % CarFormat.fmt_n_band(oso.at.needMinN, oso.at.needMaxN), "con su banda")
	assert_eq(rows.reparto.value, MCS.fmt_pct(oso.at.dragShare), "con aire, el reparto")


## Unidad 4o: la frenada máxima que aguanta se escribe redondeada hacia abajo. A 60 km/h, el oso de pie en el techo aguanta
## ~0.897 g, menos que la de emergencia, y no puede leerse «0.90 g a 60 km/h (…; la de emergencia es de 0.90 g)» mientras el
## veredicto dice que sale despedido.
func test_la_frenada_maxima_se_redondea_hacia_abajo() -> void:
	for g: float in [0.0, 0.29, 0.8966, 0.9, 1.1057, 1.999]:
		var txt := CarFormat.fmt_g_max(g)
		var shown := float(txt.trim_suffix(" g"))
		assert_true(shown <= g + 1e-12 and shown > g - 0.01, "%s → %s" % [g, txt])
	assert_eq(CarFormat.fmt_g_max(0.29), "0.29 g", "sin bajar por la coma flotante")
	var oso := state("oso")
	oso.set_zone("techo")
	oso.set_posture("de_pie")
	oso.set_maneuver("emergencia")
	oso.set_speed(60.0)
	oso.finish()
	var g := float(oso.report.brakingG)
	assert_true(g < 0.9 and Js.to_fixed(g, 2) == "0.90", "el caso: aguanta %s g, que con dos decimales parece la de emergencia" % g)
	assert_false(oso.at.holds, "y no aguanta la de emergencia")
	assert_true(oso.braking_text().begins_with("0.89 g a 60 km/h"), oso.braking_text())
	var f: Array = oso.facts().filter(func(x: Dictionary) -> bool: return String(x.text).contains("aguanta hasta"))
	assert_true(f.size() == 1 and String(f[0].text).ends_with("aguanta hasta 0.89 g (caso central)."), "el dato: %s" % [f])
	oso.dispose()


func test_sabias_que_con_fuente_y_moraleja() -> void:
	for cfg: Array in [["aguila", "hold"], ["oso", "hold"], ["tigre", "impact"], ["lechuza", "impact"], ["casuario", "impact"]]:
		var st := state(cfg[0])
		st.set_mode(cfg[1])
		st.finish()
		var facts: Array = st.facts()
		assert_true(facts.size() >= 3, "%s: varios datos (%d)" % [cfg[0], facts.size()])
		for f: Dictionary in facts:
			assert_true(String(f.text) != "" and String(f.source) != "", "%s: cada dato con su fuente: %s" % [cfg[0], f.text])
			assert_true(MCS.QUALITY_TEXT.has(f.quality) or f.quality == "", "%s: con su calidad" % cfg[0])
		assert_true(st.moral() != "", "%s: con su moraleja" % cfg[0])
	# el aire local y la parte de la energía, con los números de MovingCar
	var st := state("aguila")
	var local: Array = st.facts().filter(func(f: Dictionary) -> bool: return String(f.text).begins_with("En el techo el aire va más deprisa"))
	assert_eq(local.size(), 1, "el aire sobre el techo")
	assert_true(String(local[0].text).contains(MCS.fmt_kmh(st.at.localKmh)), "a la velocidad local de at_speed: %s" % local[0].text)
	assert_eq(local[0].source, MC.ZONES.techo.cp.source, "con la fuente del Cp (DrivAer)")
	var tigre := state("tigre")
	tigre.set_mode("impact")
	tigre.set_impact_zone("puerta")
	tigre.finish()
	var energy: Array = tigre.facts().filter(func(f: Dictionary) -> bool: return String(f.text).begins_with("¿A dónde va la energía"))
	var heat: Dictionary = tigre.hit.energy.terms.filter(func(t: Dictionary) -> bool: return t.id == "rozamiento")[0]
	assert_true(String(energy[0].text).contains(MCS.fmt_share(heat.share)), "el calor del rozamiento: %s" % energy[0].text)
	# en un experimento, primero su dato: el material de las garras que corta la chapa, o el animal asustado
	tigre.load_experiment("tigre_zafiro")
	tigre.finish()
	assert_true(String(tigre.facts()[0].text).begins_with("El zafiro es frágil"), "garras de zafiro: %s" % tigre.facts()[0].text)
	tigre.set_inlay(MCS.KERATIN)
	tigre.set_defense(true)
	tigre.finish()
	assert_true(String(tigre.facts()[0].text).begins_with("Asustado, cada"), "tigre asustado: %s" % tigre.facts()[0].text)


## Todos los materiales que ofrece la tarjeta (Catalog.INLAYS, con los de la reforja de la 2.0: el rubí y la alúmina) los
## entiende el motor del coche, que no puede buscarlos por su id (MovingCar.inlay_of): el estado se los pasa enteros.
func test_cada_material_del_catalogo_llega_al_motor_del_coche() -> void:
	for e: Dictionary in Catalog.INLAYS:
		var id := String(e.id)
		var st := state("tigre")
		st.set_inlay(id)
		assert_eq(st.inlay, id, "%s: elegido" % id)
		var known: Variant = MC.inlay_of({ "inlay": st.inlay_param() })
		assert_true(known is Dictionary and String((known as Dictionary).id) == id, "%s: el motor lo encuentra" % id)
		st.set_mode(MCS.MODE_IMPACT)
		st.finish()
		var why := String(st.report.get("reason", ""))
		assert_false(why.contains("desconocido"), "%s: el golpe sale sin «material desconocido» (%s)" % [id, why])
		st.dispose()
	var ruby: Variant = MC.inlay_of({ "inlay": "rubi" })
	assert_true(ruby == null, "por su id solo, el rubí no está en Data.INLAYS (llega entero desde el estado)")
