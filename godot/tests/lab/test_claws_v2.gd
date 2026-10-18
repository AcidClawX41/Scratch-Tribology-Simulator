## Correcciones de las rapaces para el modelo 2.0 (core/lab/claws_v2.gd): que cada dato lleve fuente y calidad, que
## los agarres salgan del escalado de Sustaita & Hertel (2010) y no sean números mágicos, que las bandas contengan el
## valor, que apply() no toque el catálogo 1.x (el oráculo) y que la queratina siga sin poder rayar el metal.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Physics = preload("res://core/lab/physics.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")

const RAPTORS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const QUALITIES := ["primary", "secondary", "estimate"]


static func C(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


func test_cada_correccion_lleva_valor_fuente_y_calidad() -> void:
	for id: String in ClawsV2.OVERRIDES:
		assert_true(C(id) != null, "%s existe en el catálogo" % id)
		var o: Dictionary = ClawsV2.OVERRIDES[id]
		for key: String in o:
			var e: Dictionary = o[key]
			assert_true(e.has("value"), "%s.%s: value" % [id, key])
			assert_true(String(e.get("source", "")).length() > 20, "%s.%s: fuente con cita" % [id, key])
			assert_true(QUALITIES.has(e.get("quality")), "%s.%s: calidad válida" % [id, key])
			assert_true(C(id).has(key), "%s.%s: el campo existe en la garra 1.x" % [id, key])


func test_las_seis_rapaces_estan_revisadas() -> void:
	for id: String in RAPTORS:
		assert_true(ClawsV2.has_overrides(id), "%s: revisada" % id)
		assert_true(ClawsV2.override_of(id, "force") != null, "%s: agarre con fuente y banda" % id)


func test_las_bandas_contienen_el_valor() -> void:
	for id: String in ClawsV2.OVERRIDES:
		var f: Variant = ClawsV2.override_of(id, "force")
		if f == null:
			continue
		assert_true(f.min <= f.value and f.value <= f.max, "%s: min ≤ valor ≤ max" % id)
		assert_true(f.min > 0.0, "%s: agarre positivo" % id)


func test_el_agarre_de_las_aguilas_sale_del_escalado_medido() -> void:
	# no son números mágicos: gavilán de Cooper hembra (9,77 N, 450,4 g) con la pendiente RMA de los accipítridos
	var cases := { "aguila": 5.0, "arpia": 9.0 }
	for id: String in cases:
		var m: float = cases[id]
		var f: Dictionary = ClawsV2.override_of(id, "force")
		assert_near(f.value, ClawsV2.accipiter_grip(m), 0.001, 0.06, "%s: valor = escalado con pendiente 0,97" % id)
		assert_near(f.min, ClawsV2.accipiter_grip(m, ClawsV2.ACCIPITER_SLOPE_LO), 0.001, 0.06, "%s: mínimo con pendiente 0,79" % id)
		assert_near(f.max, ClawsV2.accipiter_grip(m) * ClawsV2.TECHNIQUE_FACTOR, 0.001, 0.06, "%s: máximo ×2,96 (técnica)" % id)
		assert_eq(float(C(id).mass), m, "%s: la masa del catálogo es la del escalado" % id)


func test_el_halcon_reproduce_la_medicion_de_sustaita_y_hertel() -> void:
	# a la masa medida, el escalado devuelve exactamente la media medida (12,7 N con 773,8 g)
	assert_near(ClawsV2.falcon_grip(ClawsV2.PEREGRINE_MASS_KG), 12.7, 1e-12, 0.0, "peregrino hembra medido")
	var f: Dictionary = ClawsV2.override_of("halcon", "force")
	assert_near(f.value, ClawsV2.falcon_grip(1.0), 0.001, 0.06, "halcón de 1 kg con pendiente 0,86")
	assert_near(f.min, ClawsV2.falcon_grip(1.0, ClawsV2.FALCON_SLOPE_LO, 12.7 - 2.6), 0.001, 0.06, "mínimo")
	# la 1.x (15 N) queda dentro de la banda: no se corrige, se confirma con fuente
	assert_true(f.min <= float(C("halcon").force) and float(C("halcon").force) <= f.max, "15 N de la 1.x dentro")


func test_el_cooper_medido_da_su_propio_valor() -> void:
	assert_near(ClawsV2.accipiter_grip(ClawsV2.COOPER_MASS_KG), 9.77, 1e-12, 0.0, "a su masa, su medición")


func test_la_banda_alta_es_la_dispersion_entre_tecnicas() -> void:
	# Ward et al. (2002) midieron 7,7 N en cernícalos donde Sustaita & Hertel midieron 2,6 N
	assert_near(ClawsV2.TECHNIQUE_FACTOR, 7.7 / 2.6, 1e-12, 0.0, "factor de técnica")
	assert_true(ClawsV2.TECHNIQUE_FACTOR > 2.9 and ClawsV2.TECHNIQUE_FACTOR < 3.0, "~×3")


func test_las_correcciones_1x_que_cambian_quedan_dentro_de_la_banda() -> void:
	# las fuerzas 1.x eran estimaciones por escalado lineal: todas caen dentro de la banda 2.0 (la corrección es
	# de método y de banda, no un cambio de orden de magnitud)
	for id: String in RAPTORS:
		var f: Dictionary = ClawsV2.override_of(id, "force")
		var old: float = C(id).force
		assert_true(f.min <= old and old <= f.max, "%s: 1.x %s N dentro de %s-%s" % [id, old, f.min, f.max])


func test_apply_no_toca_el_catalogo_1x() -> void:
	var before: Dictionary = C("aguila").duplicate(true)
	var a := ClawsV2.apply(C("aguila"))
	assert_true(same(C("aguila"), before), "Data.CLAWS no cambia")
	assert_eq(a.force, 100.9, "valor 2.0")
	assert_eq(C("aguila").force, 110.0, "valor 1.x intacto")
	assert_true(a.sources2.has("force"), "procedencia del campo corregido")
	for key: String in C("aguila"):
		assert_true(a.has(key), "apply conserva la clave %s" % key)


func test_apply_es_idempotente_y_neutro_sin_correcciones() -> void:
	for c: Dictionary in Data.CLAWS:
		var once := ClawsV2.apply(c)
		var twice := ClawsV2.apply(once)
		assert_true(same(once, twice), "%s: aplicar dos veces da lo mismo" % c.id)
		if not ClawsV2.has_overrides(c):
			assert_true(same(once, c), "%s: sin correcciones, copia igual" % c.id)


func test_el_halcon_corrige_su_picado_con_fuente() -> void:
	var h := ClawsV2.apply(C("halcon"))
	assert_eq(h.strike.v, 40.0, "40 m/s: el orden de los máximos medidos por radar (31-39 m/s)")
	assert_false(String(h.desc).contains(">300"), "la ficha ya no afirma >300 km/h como medido")
	assert_true(String(ClawsV2.override_of("halcon", "strike").source).contains("Alerstam"), "cita el radar")


func test_el_golpe_del_casuario_es_la_patada_del_coche_en_marcha() -> void:
	# unidad 4i: calculado con las funciones de MovingCar (unidad 4d), no con números copiados
	var cas := C("casuario")
	var o: Dictionary = ClawsV2.override_of("casuario", "strike")
	var v := MovingCar.kick_leap_ms()
	var f: float = MovingCar.KICK.muscle_fraction.value
	# unidad 4i-B2: con la masa de la 2.0, la de la hembra del coche en marcha (ClawsV2.casuario_mass)
	var m: float = float(ClawsV2.casuario_mass().value)
	assert_eq(o.value, { "v": v, "m": f * m }, "v del salto y m de los músculos de la pata que patea, al bit")
	assert_eq(o.max, { "v": v, "m": m / 2.0 }, "banda alta: el pie con la mitad del impulso del salto")
	assert_eq(o.min, o.value, "la banda empieza en el valor")
	var e := 0.5 * f * m * v * v
	assert_eq(float(o.energyJ.value), e, "½·m·v²")
	# w·f·M = ½·(M/2)·v², porque v² = 4·w·f (el trabajo de los músculos de una pata)
	assert_near(float(o.energyJ.max), float(MovingCar.KICK.work_j_per_kg.value) * f * m, 1e-12, 0.0, "todo el trabajo de una pata")
	assert_near(e, 88.41, 0.0, 0.01, "~88 J con la hembra de 58 kg (con los 60 kg de la 1.x eran 91,45)")
	assert_near(float(o.energyJ.max), 339.7, 0.0, 0.05, "hasta ~340 J")
	assert_near(0.5 * 5.0 * 8.0 * 8.0, 160.0, 0.0, 1e-12, "la 1.x daba 160 J")
	assert_eq(o.quality, "estimate", "estimación: nadie ha medido la masa eficaz de una patada de casuario")
	for who: String in ["Henry", "Hutchinson", "patada del coche en marcha", "Suposición"]:
		assert_true(String(o.source).contains(who), "la fuente cita %s" % who)
	# unidad 4n: una fuente que se ve dice de dónde sale con palabras, sin nombres de código ni rutas internas
	for code: String in ["MovingCar", "docs/", "§", "unidad 4"]:
		assert_false(String(o.source).contains(code), "la fuente no nombra «%s»" % code)
	# se aplica en la 2.0; la ficha 1.x no cambia
	assert_eq(ClawsV2.apply(cas).strike, o.value, "apply lleva el golpe nuevo")
	assert_eq(ClawsV2.apply(cas).sources2.strike.quality, "estimate", "con su procedencia")
	assert_eq(cas.strike, { "v": 8.0, "m": 5.0 }, "data.gd no cambia")


## Unidad 4i-B2 (coherencia banco ↔ coche): el casuario del banco pesa lo que la hembra del coche en marcha (58 kg, Grzimek
## 2003), con su fuente; la ficha 1.x (60 kg, sin fuente) no cambia.
func test_la_masa_del_casuario_es_la_del_coche_en_marcha() -> void:
	var hembra: Dictionary = MovingCar.BODIES.casuario.mass_kg[MovingCar.SEXES[0]]
	var o: Dictionary = ClawsV2.override_of("casuario", "mass")
	assert_eq([float(o.value), float(o.min), float(o.max)], [float(hembra.value), float(hembra.min), float(hembra.max)], "la de la hembra, con su banda")
	assert_eq(o.quality, hembra.quality, "con su calidad")
	assert_true(String(o.source).contains("Grzimek") and String(o.source).contains("60 kg"), "cita a Grzimek y dice lo que había: %s" % o.source)
	var cas := ClawsV2.apply(C("casuario"))
	assert_eq(float(cas.mass), 58.0, "el catálogo 2.0 pesa 58 kg")
	assert_eq(cas.sources2.mass.quality, "secondary", "con su procedencia")
	assert_eq(cas.strike, ClawsV2.kick_strike(58.0).value, "y patea con esa masa")
	assert_eq(float(C("casuario").mass), 60.0, "data.gd no cambia: el oráculo 1.x sigue igual")


func test_las_correcciones_son_de_solo_lectura() -> void:
	# OVERRIDES se calcula una vez al cargar (el golpe del casuario) y nadie lo vuelve a escribir (seguro para hilos)
	assert_true(ClawsV2.OVERRIDES.is_read_only(), "OVERRIDES")
	assert_true((ClawsV2.OVERRIDES.casuario as Dictionary).is_read_only(), "la entrada del casuario")
	assert_true((ClawsV2.OVERRIDES.casuario.strike as Dictionary).is_read_only(), "y su golpe")
	assert_true((ClawsV2.OVERRIDES.casuario.strike.value as Dictionary).is_read_only(), "hasta el valor")
	assert_true((ClawsV2.OVERRIDES.aguila as Dictionary).is_read_only(), "las fijas, constantes")


func test_la_queratina_corregida_sigue_sin_rayar_el_metal_de_un_coche() -> void:
	# FISICA.md §4: con r = HV_punta/HV_objetivo < 0,8 cede la punta. Las correcciones no tocan la dureza.
	for id: String in RAPTORS:
		var a := ClawsV2.apply(C(id))
		for b: String in ["moderno", "clasico", "aluminio"]:
			var r: float = float(a.hv) / float(Data.CAR_BODIES[b].hv)
			assert_true(r < Physics.MODEL.rOff, "%s contra %s: r = %s < 0,8" % [id, b, r])
