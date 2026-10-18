## Velociraptor, reconstrucción (core/lab/velociraptor.gd, unidad 4e): que cada dato lleve fuente y calidad, que los
## números derivados salgan de sus fórmulas y no sean mágicos (masa por el fémur, agarre de los gavilanes, carga de la
## réplica, garra sola, carrera, salto y estuche de queratina), que lo que no está medido no se presente como dato y que
## el catálogo 1.x (el oráculo) no cambie.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Physics = preload("res://core/lab/physics.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const E := Velociraptor.ENTRY


static func claw(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


## Comprueba un dato { value?, source, quality } de un bloque.
func _check_datum(where: String, d: Dictionary) -> void:
	assert_true(String(d.get("source", "")).length() > 20, "%s: fuente con cita" % where)
	assert_true(QUALITIES.has(d.get("quality")), "%s: calidad válida (%s)" % [where, d.get("quality")])
	if d.has("min") and d.has("max") and d.get("value") != null:
		assert_true(float(d.min) <= float(d.value) and float(d.value) <= float(d.max), "%s: min ≤ valor ≤ max" % where)


func test_la_entrada_tiene_las_claves_de_una_garra() -> void:
	# el banco, resolve_tool y la interfaz la tratan como una garra: las mismas claves y tipos que el águila
	var ref := claw("aguila")
	for key: String in ref:
		assert_true(E.has(key), "clave %s" % key)
		if E.has(key):
			assert_eq(typeof(E[key]), typeof(ref[key]), "tipo de %s" % key)
	assert_eq(E.id, "velociraptor", "id")
	assert_eq(E.group, Velociraptor.GROUP, "grupo nuevo de la 2.0")
	assert_true(E.strike.has("v") and E.strike.has("m"), "golpe { v, m }")
	assert_true(QUALITIES.has(E.quality) and String(E.source).length() > 50, "fuente y calidad de la entrada")
	assert_true(Velociraptor.is_dino(E), "is_dino")
	assert_false(Velociraptor.is_dino(claw("aguila")), "una rapaz no es un dinosaurio reconstruido")
	assert_eq(Velociraptor.find_by_id("velociraptor").id, "velociraptor", "find_by_id")
	assert_eq(Velociraptor.find_by_id("tiranosaurio"), null, "find_by_id sin datos")


func test_cada_dato_lleva_fuente_y_calidad() -> void:
	_check_datum("mass", Velociraptor.MASS)
	for block: String in ["body", "sickle", "forces", "locomotion"]:
		var b: Dictionary = E.dino[block]
		for key: String in b:
			_check_datum("%s.%s" % [block, key], b[key])
	for key: String in E.dino.function:
		_check_datum("function.%s" % key, E.dino.function[key])
	var car: Dictionary = E.dino.car
	_check_datum("car.contactMm", car.contactMm)
	_check_datum("car.grasp", car.grasp)
	assert_true(String(car.frontalSource).length() > 20, "car: fuente del área frontal")
	# los colores son dibujo, no física
	assert_eq(E.dino.colors.quality, "dibujo", "colores: dibujo")


func test_la_masa_sale_del_escalado_del_femur() -> void:
	var r := Velociraptor.mass_report()
	# 64 mm de circunferencia y α² = 2,008 (Campione et al. 2014) con la recta PGLS de Campione & Evans (2012)
	assert_near(r.cqeKg, 19.6845, 1e-4, 0.0, "escalado del fémur: 19,68 kg")
	assert_near(Velociraptor.MASS.value, r.cqeKg, 0.0, 0.05, "el valor es el del escalado (19,7 kg)")
	assert_near(Velociraptor.MASS.max, r.cqeMaxKg, 0.0, 0.05, "banda alta: el escalado + 25 %")
	assert_true(Velociraptor.VOLUMETRIC_KG.has(Velociraptor.MASS.min), "banda baja: una reconstrucción volumétrica (14,1 kg)")
	for v: float in Velociraptor.VOLUMETRIC_KG:
		assert_true(v < Velociraptor.MASS.value, "las volumétricas (%s kg) quedan por debajo del escalado" % v)
	assert_eq(float(E.mass), float(Velociraptor.MASS.value), "la ficha usa la masa del escalado")
	# con α² = 2 (la corrección por defecto) apenas cambia
	assert_near(Velociraptor.cqe_mass_kg(64.0), r.cqeKg, 0.01, 0.0, "α² = 2 frente a 2,008")


func test_el_agarre_sale_del_escalado_de_los_gavilanes() -> void:
	var g: Dictionary = E.dino.forces.grip
	var m: float = E.mass
	assert_near(g.value, ClawsV2.accipiter_grip(m), 0.0, 0.05, "valor: pendiente 0,97 (Sustaita & Hertel 2010)")
	assert_near(g.min, ClawsV2.accipiter_grip(m, ClawsV2.ACCIPITER_SLOPE_LO), 0.0, 0.05, "mínimo: pendiente 0,79")
	assert_near(g.max, ClawsV2.accipiter_grip(m) * ClawsV2.TECHNIQUE_FACTOR, 0.0, 0.05, "máximo: ×2,96 (técnica)")
	assert_near(Velociraptor.grip_n(m), ClawsV2.accipiter_grip(m), 1e-12, 0.0, "grip_n")
	assert_near(Velociraptor.grip_n(m, "min"), ClawsV2.accipiter_grip(m, ClawsV2.ACCIPITER_SLOPE_LO), 1e-12, 0.0, "grip_n min")
	assert_near(Velociraptor.grip_n(m, "max"), ClawsV2.accipiter_grip(m) * ClawsV2.TECHNIQUE_FACTOR, 1e-12, 0.0, "grip_n max")
	assert_eq(float(E.force), float(g.value), "force de la ficha = agarre de un pie, como las rapaces de claws_v2")


func test_la_carga_de_la_replica_es_la_publicada() -> void:
	# Manning et al. (2006): 981 N = 2,5 × 40 kg × 9,81
	assert_near(Velociraptor.REPLICA_BW * Velociraptor.REPLICA_MASS_KG * 9.81, Velociraptor.REPLICA_N, 1e-12, 0.0, "981 N")
	assert_near(E.dino.forces.replica.value, Velociraptor.replica_load_n(E.mass), 0.0, 0.05, "con la masa de Velociraptor")


func test_la_garra_sola_aprieta_poco() -> void:
	# Bishop (2019): 18,9 N con 490 N de peso; escalado con m^(2/3)
	var ref := Velociraptor.BISHOP_WEIGHT_N / Velociraptor.G
	assert_near(Velociraptor.claw_muscle_n(ref), Velociraptor.BISHOP_TIP_N, 1e-12, 0.0, "a su masa, su resultado")
	var c: Dictionary = E.dino.forces.clawMuscle
	assert_near(c.value, Velociraptor.claw_muscle_n(E.mass), 0.0, 0.05, "escalada a 19,7 kg")
	assert_near(c.max, Velociraptor.claw_muscle_n(E.mass, true), 0.0, 0.05, "con el doble de músculo")
	# en el Deinonychus de 50 kg, el 3,9 % del peso; escalada a 19,7 kg (∝ m^(2/3)), ~5 %: la fuerza la pone el peso
	var weight := float(E.mass) * Velociraptor.G
	assert_near(Velociraptor.BISHOP_TIP_N / Velociraptor.BISHOP_WEIGHT_N, 0.0386, 0.01, 0.0, "18,9/490")
	assert_true(c.value < 0.06 * weight, "la garra sola: ~5 % del peso")
	assert_true(c.max < float(E.dino.forces.grip.min), "ni con el doble de músculo aprieta como el pie entero")


func test_carrera_y_salto() -> void:
	var loc: Dictionary = E.dino.locomotion
	assert_eq(Velociraptor.run_speed_ms(), 10.8, "Sellers & Manning (2007)")
	assert_near(Velociraptor.run_speed_ms(true), 10.8 / 0.79, 1e-12, 0.0, "banda alta: la subestimación de la persona")
	assert_near(loc.runMs.max, Velociraptor.run_speed_ms(true), 0.0, 0.005, "runMs.max")
	assert_near(loc.leapMs.value, Velociraptor.leap_speed_ms(), 0.0, 0.005, "salto: √(4·45·0,130)")
	assert_near(loc.leapMs.max, Velociraptor.leap_speed_ms(true), 0.0, 0.005, "salto con 67,5 J/kg")
	assert_near(Velociraptor.LEAP_MUSCLE_FRACTION, 0.13014, 1e-3, 0.0, "13,0 % por pata (avestruz)")
	assert_true(Velociraptor.leap_speed_ms(true) > Velociraptor.leap_speed_ms(), "la banda alta salta más")
	assert_near(Velociraptor.leap_height_m(), 1.1943, 1e-3, 0.0, "sube el centro de masas ~1,2 m")
	# el golpe de la ficha: cae con los dos pies a la velocidad del salto
	assert_eq(float(E.strike.v), float(loc.leapMs.value), "strike.v = salto")
	assert_near(E.strike.m, float(E.mass) / 2.0, 1e-12, 0.0, "strike.m = la mitad de la masa")


func test_la_garra_de_queratina_sale_del_hueso_y_de_las_aves() -> void:
	var s: Dictionary = E.dino.sickle
	var band := Velociraptor.keratin_band_mm()
	assert_near(s.keratinMm.value, band.value, 0.0, 0.05, "64,8/0,699")
	assert_near(s.keratinMm.min, band.min, 0.0, 0.05, "con el 15 % de Manning et al. (2006)")
	assert_near(s.keratinMm.max, band.max, 0.0, 0.05, "núcleo de 66,3 mm y proporción 0,693")
	assert_eq(float(E.reach), float(s.keratinMm.value), "reach = la garra de queratina")
	assert_true(float(E.reach) > float(s.coreMm.value), "la queratina alarga el hueso")
	var r: float = Velociraptor.CORE_TO_SHEATH
	assert_true(Velociraptor.CORE_TO_SHEATH_LO <= r and r <= Velociraptor.CORE_TO_SHEATH_HI, "proporción dentro del IC")
	# la garra es una hoja estrecha: más alta que ancha en la base
	assert_true(float(s.coreHeightMm.value) > 2.0 * float(s.coreWidthMm.value), "alto > 2 × ancho")


func test_la_punta_no_se_presenta_como_dato() -> void:
	var harpy := claw("arpia")
	var s: Dictionary = E.dino.sickle
	assert_eq(float(E.area), float(harpy.area), "la punta del talón de la arpía (análogo funcional)")
	assert_eq(float(E.alpha), float(harpy.alpha), "su semiángulo")
	assert_true(s.tipRadiusUm.get("open") == true and s.tipRadiusUm.quality == "estimate", "pregunta abierta")
	assert_true(s.alphaDeg.get("open") == true, "semiángulo: pregunta abierta")
	assert_near(Velociraptor.tip_radius_um(), float(s.tipRadiusUm.value), 0.0, 0.05, "√(0,06/π) = 138,2 µm")


func test_la_queratina_es_la_del_banco_y_no_raya_el_metal() -> void:
	assert_eq(float(E.hv), float(claw("aguila").hv), "32 HV, como el águila")
	assert_eq(float(E.E), Data.KERATIN_E, "2,0 GPa")
	var body: Dictionary = Data.CAR_BODIES["moderno"]
	assert_true(float(E.hv) / float(body.hv) < Physics.MODEL.rOff, "la queratina no corta el acero del coche (r < 0,8)")


func test_lo_que_no_esta_medido_no_entra() -> void:
	assert_eq(E.dino.body.wingAreaM2.value, null, "sin superficie alar publicada")
	assert_eq(E.dino.car.wingM2, null, "sin alas en la aerodinámica")
	assert_true(E.dino.sickle.arcDeg.quality == "estimate", "el arco es el de Deinonychus (caso parecido)")


func test_no_toca_el_catalogo_1x() -> void:
	assert_eq(Data.find_by_id(Data.CLAWS, "velociraptor"), null, "Data.CLAWS sin cambios (el oráculo)")
	assert_false(Data.CLAW_GROUPS.has(Velociraptor.GROUP), "grupos 1.x sin cambios")


func test_area_frontal_de_ave() -> void:
	assert_near(Velociraptor.frontal_area_m2(float(E.mass)), 0.0591841, 1e-4, 0.0, "Pennycuick (1988) con 19,7 kg")
	assert_true(Velociraptor.frontal_area_m2(24.6) > Velociraptor.frontal_area_m2(14.1), "crece con la masa")


func test_los_numeros_del_cuerpo_cuadran_con_los_huesos() -> void:
	var b: Dictionary = E.dino.body
	var leg_m := (float(b.femurMm.value) + float(b.tibiaMm.value) + float(b.metatarsalIIIMm.value)) / 1000.0
	assert_true(leg_m > float(b.hipM.value), "la pata estirada (%s m) es más larga que la cadera de pie" % leg_m)
	assert_true(float(b.lengthM.min) <= float(b.lengthM.value) and float(b.lengthM.value) <= float(b.lengthM.max), "largo")
