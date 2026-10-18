## Velocirraptor de cine, FICCIÓN (core/lab/velociraptor_film.gd, unidad 4i-B2; docs/fisica/velociraptor.md §11): que lo
## real sea real (el tamaño, la masa por el fémur, la garra, el agarre, la carrera y el salto de Deinonychus, con las mismas
## fórmulas que la reconstrucción y sin números mágicos), que lo de película lleve la calidad «ficcion» y diga qué haría la
## garra de verdad, que esté en su propio grupo del catálogo 2.0 y que el catálogo 1.x (el oráculo) no cambie.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Physics = preload("res://core/lab/physics.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const MC = preload("res://core/lab/moving_car.gd")
const Js = preload("res://core/shared/js.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const E := VelociraptorFilm.ENTRY
const R := Velociraptor.ENTRY


## Un dato real { value?, source, quality } (calidad de dato, nunca «ficcion»).
func _check_datum(where: String, d: Dictionary) -> void:
	assert_true(String(d.get("source", "")).length() > 20, "%s: fuente con cita" % where)
	assert_true(QUALITIES.has(d.get("quality")), "%s: calidad de dato (%s)" % [where, d.get("quality")])
	if d.has("min") and d.has("max") and d.get("value") != null:
		assert_true(float(d.min) <= float(d.value) and float(d.value) <= float(d.max), "%s: min ≤ valor ≤ max" % where)


## Un dato de película: calidad «ficcion» y una fuente que dice que es ficción y qué haría la garra de verdad.
func _check_fiction(where: String, d: Dictionary) -> void:
	assert_eq(d.get("quality"), VelociraptorFilm.FICTION_QUALITY, "%s: calidad «ficcion»" % where)
	var src := String(d.get("source", ""))
	assert_true(src.contains("FICCIÓN") or src.contains("Jurassic Park"), "%s: dice que es de película" % where)


func test_la_entrada_tiene_las_claves_de_una_garra_y_su_propio_grupo() -> void:
	var ref: Dictionary = Data.find_by_id(Data.CLAWS, "aguila")
	for key: String in ref:
		assert_true(E.has(key), "clave %s" % key)
		if E.has(key):
			assert_eq(typeof(E[key]), typeof(ref[key]), "tipo de %s" % key)
	assert_eq(E.id, "velociraptor_pelicula", "id")
	assert_eq(E.group, VelociraptorFilm.GROUP, "su grupo")
	assert_true(E.group != Velociraptor.GROUP, "no va con la reconstrucción: una reconstrucción no lleva ficción dentro")
	assert_eq(E.quality, "ficcion", "la entrada es de ficción")
	assert_true(String(E.desc).begins_with("FICCIÓN"), "la ficha lo dice lo primero")
	assert_true(String(E.name).length() <= 21, "nombre corto: cabe en la comparativa del teléfono (%s)" % E.name)
	assert_true(VelociraptorFilm.is_film(E) and Velociraptor.is_dino(E), "is_film e is_dino")
	assert_false(VelociraptorFilm.is_film(R), "la reconstrucción no es de película")
	assert_true(E.dino.film == true and E.dino.reconstruction == false, "dino.film, no reconstrucción")
	assert_eq(VelociraptorFilm.entries(), [E], "entries()")


func test_esta_en_el_catalogo_2_0_y_no_en_la_1x() -> void:
	assert_eq(Catalog.find_by_id(Catalog.CLAWS, "velociraptor_pelicula"), E, "en el catálogo 2.0, tal cual")
	assert_true(Catalog.is_v2("CLAWS", "velociraptor_pelicula"), "un añadido de la 2.0")
	assert_true(Catalog.V2_CLAW_GROUPS.has(VelociraptorFilm.GROUP), "con su grupo")
	assert_eq(Data.find_by_id(Data.CLAWS, "velociraptor_pelicula"), null, "data.gd (el oráculo 1.x) no lo tiene")
	assert_false(Data.CLAW_GROUPS.has(VelociraptorFilm.GROUP), "ni su grupo")


func test_lo_real_lleva_fuente_y_calidad_de_dato() -> void:
	_check_datum("mass", VelociraptorFilm.MASS)
	for block: String in ["body", "forces", "locomotion"]:
		var b: Dictionary = E.dino[block]
		for key: String in b:
			_check_datum("%s.%s" % [block, key], b[key])
	for key: String in ["keratinMm", "coreMm", "coreHeightMm", "coreWidthMm", "arcDeg", "tipRadiusUm"]:
		_check_datum("sickle.%s" % key, E.dino.sickle[key])
	_check_datum("car.contactMm", E.dino.car.contactMm)
	assert_eq(E.dino.colors.quality, "dibujo", "los colores son dibujo")


func test_lo_de_pelicula_se_marca_como_ficcion() -> void:
	_check_fiction("sickle.hv", E.dino.sickle.hv)
	_check_fiction("sickle.E", E.dino.sickle.E)
	for key: String in E.dino.fiction:
		_check_fiction("fiction.%s" % key, E.dino.fiction[key])
	# la garra de película dice qué haría la de verdad: la queratina de la reconstrucción, que no corta el acero
	var src := String(E.dino.fiction.claw.source)
	assert_true(src.contains("queratina") and src.contains("Manning") and src.contains("Fowler"), "con el contraste: %s" % src)
	assert_eq(DinoLab.QUALITY_TEXT.ficcion, "ficción (película)", "la ficha lo lee «ficción (película)»")


func test_la_garra_de_pelicula_es_la_tachuela_de_acero_del_banco() -> void:
	var steel: Dictionary = Data.find_by_id(Data.INLAYS, "acero")
	var fc: Dictionary = E.dino.fiction.claw
	assert_eq(float(fc.hv), float(steel.hv), "200 HV, como la tachuela")
	assert_eq(float(fc.E), float(steel.E), "200 GPa")
	assert_eq(float(fc.mohs), float(steel.mohs), "Mohs 5,5")
	assert_eq(float(E.hv), float(fc.hv), "la entrada lleva la dureza de película")
	assert_eq(float(E.E), float(fc.E), "y su módulo")
	assert_eq(float(E.mohs), float(fc.mohs), "y su Mohs")
	var body: Dictionary = Data.CAR_BODIES["moderno"]
	assert_true(float(E.hv) / float(body.hv) >= Physics.MODEL.rOff, "la de película corta el acero de un coche (r ≥ 0,8)")
	assert_true(float(R.hv) / float(body.hv) < Physics.MODEL.rOff, "la de verdad, de queratina, no")


func test_la_masa_sale_del_femur_de_deinonychus() -> void:
	var cqe := VelociraptorFilm.femur_mass_kg()
	assert_near(cqe, Velociraptor.cqe_mass_kg(VelociraptorFilm.FEMUR_CIRC_MM, VelociraptorFilm.FEMUR_ALPHA2), 1e-12, 0.0, "el mismo escalado")
	assert_near(VelociraptorFilm.MASS.value, cqe, 0.0, 0.05, "valor: el escalado del fémur (99,8 kg)")
	assert_near(VelociraptorFilm.MASS.max, cqe * (1.0 + Velociraptor.CQE_PPE), 0.0, 0.05, "banda alta: el escalado + 25 %")
	assert_eq(float(VelociraptorFilm.MASS.min), float(VelociraptorFilm.VOLUMETRIC_KG.min()), "banda baja: la volumétrica más ligera")
	for v: float in VelociraptorFilm.VOLUMETRIC_KG:
		assert_true(v < float(VelociraptorFilm.MASS.value), "las volumétricas (%s kg) quedan por debajo del escalado" % v)
	assert_eq(float(E.mass), float(VelociraptorFilm.MASS.value), "la ficha usa la masa del escalado")
	assert_eq(float(VelociraptorFilm.MASS_KG), float(VelociraptorFilm.MASS.value), "MASS_KG")


func test_fuerzas_con_la_masa_de_deinonychus() -> void:
	var m: float = E.mass
	var g: Dictionary = E.dino.forces.grip
	assert_near(g.value, Velociraptor.grip_n(m), 0.0, 0.05, "agarre: el escalado de los gavilanes")
	assert_near(g.min, Velociraptor.grip_n(m, "min"), 0.0, 0.05, "agarre mínimo")
	assert_near(g.max, Velociraptor.grip_n(m, "max"), 0.0, 0.05, "agarre máximo")
	assert_eq(float(E.force), float(g.value), "force de la ficha = agarre de un pie")
	var cm: Dictionary = E.dino.forces.clawMuscle
	assert_near(cm.value, Velociraptor.claw_muscle_n(m), 0.0, 0.5, "la garra sola, escalada (~30 N)")
	assert_near(cm.max, Velociraptor.claw_muscle_n(m, true), 0.0, 0.5, "con el doble de músculo")
	assert_near(E.dino.forces.replica.value, Velociraptor.replica_load_n(m), 0.0, 0.05, "la carga de la réplica, con su masa")


func test_carrera_salto_y_golpe_como_la_reconstruccion() -> void:
	var loc: Dictionary = E.dino.locomotion
	assert_eq(float(loc.runMs.value), float(R.dino.locomotion.runMs.value), "corre como el modelo de su pariente")
	assert_eq(float(loc.runMs.max), float(R.dino.locomotion.runMs.max), "con su banda")
	assert_eq(loc.leapMs, R.dino.locomotion.leapMs, "el mismo salto (los mismos w y f)")
	assert_near(float(loc.leapMs.value), MC.kick_leap_ms(), 0.0, 0.005, "el salto de la patada del casuario")
	assert_eq(float(E.strike.v), float(loc.leapMs.value), "strike.v = el salto")
	assert_near(E.strike.m, float(E.mass) / 2.0, 1e-12, 0.0, "strike.m = la mitad de la masa")


func test_la_garra_y_la_punta() -> void:
	var s: Dictionary = E.dino.sickle
	assert_eq(float(E.reach), float(s.keratinMm.value), "reach = la garra de Deinonychus con su estuche (Ostrom 1969)")
	assert_eq(float(E.area), float(R.area), "la punta de la reconstrucción (pregunta abierta)")
	assert_eq(float(E.alpha), float(R.alpha), "su semiángulo")
	assert_eq(float(E.curve), float(R.curve), "su curva")
	assert_true(s.tipRadiusUm.get("open") == true, "la punta no fosiliza: pregunta abierta")


func test_el_cuerpo_para_el_dibujo_y_el_coche() -> void:
	var b: Dictionary = E.dino.body
	assert_eq(b.model.value, "Deinonychus", "el tamaño de Deinonychus")
	var car: Dictionary = E.dino.car
	var scaled := float(R.dino.car.contactMm.value) * float(b.hipM.value) / float(R.dino.body.hipM.value)
	assert_near(float(car.contactMm.value), scaled, 0.05, 0.0, "el apoyo de la reconstrucción escalado con la cadera (~50 mm)")
	# lo que usa el coche en marcha (BODIES) es lo de su ficha, sin números propios
	var body: Dictionary = MC.BODIES.velociraptor_pelicula
	assert_eq(float(body.contact_mm), float(car.contactMm.value), "BODIES: el apoyo de la ficha")
	assert_eq(float(body.height_m), float(b.hipM.value), "BODIES: la cadera para el dibujo")
	assert_eq(float(body.length_m), float(b.lengthM.value), "BODIES: el largo para el dibujo")
	assert_near(float(body.run_kmh.value), float(E.dino.locomotion.runMs.value) * MC.KMH, 1e-12, 0.0, "BODIES: la carrera de la ficha")
	assert_near(float(body.run_kmh.max), float(E.dino.locomotion.runMs.max) * MC.KMH, 1e-12, 0.0, "BODIES: con su banda")
	var rb: Dictionary = MC.BODIES.velociraptor
	assert_eq(float(rb.contact_mm), float(R.dino.car.contactMm.value), "la reconstrucción: el apoyo de su ficha")
	assert_eq(float(rb.height_m), float(R.dino.body.hipM.value), "su cadera")
	assert_eq(float(rb.length_m), float(R.dino.body.lengthM.value), "su largo")
	assert_near(float(rb.run_kmh.value), float(R.dino.locomotion.runMs.value) * MC.KMH, 1e-12, 0.0, "su carrera")
	assert_near(float(rb.run_kmh.max), float(R.dino.locomotion.runMs.max) * MC.KMH, 1e-12, 0.0, "con su banda")


func test_la_ficha_del_banco_dice_ficcion() -> void:
	var tool := { "tipRadiusUm": Velociraptor.tip_radius_um(E), "alpha": E.alpha, "strikeJ": 0.5 * float(E.strike.m) * pow(float(E.strike.v), 2.0) }
	var rows := DinoLab.spec_rows(E, "Queratina", "200 HV", tool)
	var keys: Array = rows.map(func(r: Array) -> String: return String(r[0]))
	assert_true(keys.has("ficción (película)"), "una fila dice «ficción (película)»: %s" % [keys])
	assert_true(keys.has("garra de película"), "la garra, de película")
	var line := DinoLab.sources_line(E)
	assert_true(line.begins_with("Ficción (película)"), "la línea de fuentes lo dice lo primero: %s" % line)
	assert_true(line.contains("%s HV" % Js.js_num_str(float(R.hv))), "con la queratina de verdad: %s" % line)
	assert_true(line.contains("Jurassic Park 1993 · Crichton 1990 · Paul 1988"), "las fuentes, cortas: %s" % line)
	assert_true(DinoLab.sources_line(R).begins_with("Reconstrucción"), "la reconstrucción sigue diciendo «Reconstrucción»")


func test_la_garra_de_pelicula_raja_la_chapa_en_el_banco() -> void:
	# el golden 2.0 lo guarda; aquí, el sentido: la de película raja el coche moderno, la de verdad solo llega al metal
	var base := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, "none"), "target": Catalog.find_by_id(Catalog.TARGETS, "coche"),
		"type": Catalog.find_by_id(Catalog.TYPES, "aranazo"), "length": 25.0, "tear": false, "method": "rayado",
		"strike": false, "passes": 1.0, "wet": false, "model": Physics.MODEL_V2,
	}
	var film := base.duplicate()
	film.claw = E
	film.force = float(E.force)
	var real := base.duplicate()
	real.claw = R
	real.force = float(E.force)
	var rf := Physics.compute(film)
	var rr := Physics.compute(real)
	assert_eq(String(rf.verdict), "RAJA LA CHAPA", "la de película raja la chapa")
	assert_true(String(rr.verdict) != "RAJA LA CHAPA", "la de verdad, con la misma fuerza, no: %s" % rr.verdict)
	assert_true(float(rf.depthUm) > float(rr.depthUm), "la de película entra más")
