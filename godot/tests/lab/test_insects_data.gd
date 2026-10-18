## Catálogo de aguijones (core/lab/insects.gd): que cada entrada sea una garra completa para el motor, que cada dato
## lleve su fuente y su calidad, que los números estén en rangos plausibles y que la ficha sea coherente consigo misma
## (la punta, el alcance, la masa y el golpe que usa el motor salen de los datos con fuente del bloque `stinger`).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Insects = preload("res://core/lab/insects.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
## Datos con fuente del bloque `stinger`, cada uno { value, source, quality }.
const DATA_KEYS := [
	"shaftMm", "insertMm", "diameterUm", "canalUm", "tipRadiusUm", "tipAngleDeg", "insertionN", "extractionN",
	"bucklingN", "angleDeg", "twistDeg", "insertionS", "schmidt", "massKg", "bodyMm", "forewingMm",
]
## Grupos con sus campos y un source/quality del grupo.
const GROUP_KEYS := ["barbs", "material", "autotomy", "venom", "wingbeat"]
## Las siete especies que pide la fase 2 como mínimo (y las opcionales que tienen datos).
const REQUIRED_SPECIES := [
	"Apis mellifera", "Vespula vulgaris / V. germanica", "Polistes dominula", "Vespa crabro", "Vespa velutina",
	"Bombus terrestris", "Paraponera clavata",
]


static func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


func _has_source(d: Variant, where: String) -> void:
	assert_true(d is Dictionary, "%s: es un diccionario" % where)
	if not (d is Dictionary):
		return
	assert_true(d.get("source") is String and String(d.source).length() > 8, "%s: tiene fuente" % where)
	assert_true(QUALITIES.has(d.get("quality")), "%s: quality es primary, secondary o estimate (%s)" % [where, d.get("quality")])


func test_cada_aguijon_es_una_garra_completa() -> void:
	# todas las claves de una garra de Data.CLAWS, con el mismo tipo, para que resolve_tool, el banco y la interfaz la
	# traten como una garra
	var claw_keys := {}
	for c: Dictionary in Data.CLAWS:
		for k: String in c:
			if k != "fang" and k != "title":
				claw_keys[k] = typeof(c[k])
	assert_true(claw_keys.size() >= 14, "una garra tiene al menos 14 claves")
	for s: Dictionary in Insects.STINGERS:
		for k: String in claw_keys:
			assert_true(s.has(k), "%s: falta la clave de garra «%s»" % [s.id, k])
			if s.has(k) and s[k] != null:
				var t: int = claw_keys[k]
				var ok := typeof(s[k]) == t or (t == TYPE_FLOAT and typeof(s[k]) == TYPE_INT)
				assert_true(ok, "%s.%s: mismo tipo que en las garras" % [s.id, k])
		assert_eq(s.group, Insects.GROUP, "%s: grupo Insectos" % s.id)
		assert_true(String(s.get("title", "")).begins_with("Aguijón de "), "%s: título «Aguijón de …»" % s.id)
		assert_false(s.get("fang", false), "%s: no es un colmillo (no inyecta por dos punciones)" % s.id)
		assert_true(s.strike.has("v") and s.strike.has("m"), "%s: strike { v, m }" % s.id)
		assert_true(Insects.is_stinger(s), "%s: is_stinger" % s.id)


func test_ids_unicos_y_sin_chocar_con_las_garras() -> void:
	var seen := {}
	for c: Dictionary in Data.CLAWS:
		seen[c.id] = "garra"
	for s: Dictionary in Insects.STINGERS:
		assert_false(seen.has(s.id), "id repetido: %s" % s.id)
		seen[s.id] = "aguijón"
	assert_eq(Insects.ids().size(), Insects.STINGERS.size(), "ids() devuelve uno por aguijón")
	assert_eq(Insects.find_by_id("abeja").stinger.species, "Apis mellifera", "find_by_id")
	assert_eq(Insects.find_by_id("no-existe"), null, "find_by_id de un id que no existe")
	assert_false(Insects.is_stinger(Data.CLAWS[0]), "una garra no es un aguijón")


func test_estan_las_especies_que_pide_la_fase_2() -> void:
	var species := []
	for s: Dictionary in Insects.STINGERS:
		species.append(s.stinger.species)
	for sp: String in REQUIRED_SPECIES:
		assert_true(species.has(sp), "falta %s" % sp)


func test_cada_dato_lleva_fuente_y_calidad() -> void:
	for s: Dictionary in Insects.STINGERS:
		_has_source(s, "%s (entrada)" % s.id)
		var st: Dictionary = s.stinger
		for k: String in DATA_KEYS:
			assert_true(st.has(k), "%s.stinger: falta %s" % [s.id, k])
			if st.has(k):
				_has_source(st[k], "%s.stinger.%s" % [s.id, k])
				assert_true(st[k].has("value"), "%s.stinger.%s: tiene value (aunque sea null)" % [s.id, k])
		for g: String in GROUP_KEYS:
			assert_true(st.has(g), "%s.stinger: falta el grupo %s" % [s.id, g])
			if st.has(g):
				_has_source(st[g], "%s.stinger.%s" % [s.id, g])
		for k2: String in ["species", "family", "caste"]:
			assert_true(String(st.get(k2, "")).length() > 2, "%s.stinger.%s" % [s.id, k2])


func test_la_ficha_del_motor_sale_de_los_datos_con_fuente() -> void:
	for s: Dictionary in Insects.STINGERS:
		var st: Dictionary = s.stinger
		# punta: tipRadiusUm = √(area/π)·1000, como en las garras
		var r_um: float = Contact.tip_geometry(s.area, s.alpha)["R"] * 1000.0
		assert_near(r_um, st.tipRadiusUm.value, 1e-9, 0.0, "%s: radio de la punta desde area" % s.id)
		assert_near(s.alpha, st.tipAngleDeg.value / 2.0, 1e-12, 0.0, "%s: semiángulo = ángulo del ápice / 2" % s.id)
		assert_eq(s.reach, st.insertMm.value, "%s: reach = longitud que entra" % s.id)
		assert_true(s.reach < st.shaftMm.value, "%s: entra menos que el eje entero (el bulbo no entra)" % s.id)
		assert_eq(s.mass, st.massKg.value, "%s: masa" % s.id)
		assert_eq(s.strike.m, s.mass, "%s: la masa del «golpe» es la del insecto" % s.id)
		assert_near(s.strike.v, s.reach / 1000.0 / st.insertionS.value, 0.05, 0.0, "%s: v = alcance / tiempo de inserción" % s.id)
		# la punta es lo que toca: hv y E del catálogo = los de la punta del material
		assert_near(s.hv, st.material.tip.H * 1000.0 / Contact.HV_MPA, 0.02, 0.0, "%s: hv de la punta" % s.id)
		assert_eq(s.E, st.material.tip.E, "%s: E de la punta" % s.id)
		# gradiente: la punta es más blanda que la base (Das 2018: ~6 veces en dureza)
		assert_true(st.material.tip.H < st.material.mid.H and st.material.mid.H < st.material.base.H, "%s: dureza base > medio > punta" % s.id)
		assert_true(st.material.base.H / st.material.tip.H > 4.0, "%s: la base es más de 4 veces más dura que la punta" % s.id)


func test_rangos_plausibles() -> void:
	for s: Dictionary in Insects.STINGERS:
		var st: Dictionary = s.stinger
		assert_true(s.mass > 1e-5 and s.mass < 2e-3, "%s: masa de un insecto (10 mg-2 g): %s" % [s.id, s.mass])
		assert_true(s.area > 1e-7 and s.area < 1e-4, "%s: área de la punta de un aguijón (µm²): %s" % [s.id, s.area])
		assert_true(st.tipRadiusUm.value >= 0.5 and st.tipRadiusUm.value <= 10.0, "%s: radio de la punta 0,5-10 µm" % s.id)
		assert_true(s.reach >= 0.5 and s.reach <= 8.0, "%s: longitud útil 0,5-8 mm" % s.id)
		assert_true(s.force >= 1e-4 and s.force <= 0.05, "%s: empuje de 0,1 a 50 mN: %s" % [s.id, s.force])
		assert_true(s.E >= 0.1 and s.E <= 10.0, "%s: E de cutícula (GPa)" % s.id)
		assert_true(s.hv >= 1.0 and s.hv <= 100.0, "%s: dureza de cutícula (HV)" % s.id)
		assert_true(s.curve >= 0.0 and s.curve <= 1.0, "%s: curvatura 0-1" % s.id)
		assert_true(st.canalUm.value < st.diameterUm.value, "%s: el canal cabe en el aguijón" % s.id)
		assert_true(st.diameterUm.value / 1000.0 < s.reach / 5.0, "%s: aguijón esbelto (L/D > 5)" % s.id)
		var sch: Variant = st.schmidt.value
		assert_true(sch == null or (sch >= 0.0 and sch <= 4.0), "%s: índice de Schmidt 0-4" % s.id)
		var hz: Variant = st.wingbeat.hz
		assert_true(hz == null or (hz >= 50.0 and hz <= 400.0), "%s: aleteo de himenóptero 50-400 Hz" % s.id)
		var harm: Array = st.wingbeat.harmonicsHz
		for i in harm.size():
			assert_near(harm[i], hz * (i + 1), 0.03, 0.0, "%s: armónico %d ≈ %d × F1" % [s.id, i + 1, i + 1])
		assert_eq(harm.size(), st.wingbeat.powersDb.size(), "%s: un nivel por armónico" % s.id)
		assert_true(["+", "±", "−"].has(st.autotomy.get("class")), "%s: clase de autotomía +, ± o −" % s.id)
		assert_true(String(s.col).begins_with("#"), "%s: color" % s.id)
		for ck: String in ["body", "bands", "wings", "sting"]:
			assert_true(String(st.colors.get(ck, "")).begins_with("#"), "%s: color %s" % [s.id, ck])


func test_valores_de_referencia_de_fisica_md() -> void:
	# docs/FISICA.md → «Datos investigados pendientes de integrar», contrastados con las fuentes primarias
	var bee: Dictionary = Insects.find_by_id("abeja").stinger
	assert_eq(bee.schmidt.value, 2.0, "Schmidt abeja 2")
	assert_eq(Insects.find_by_id("avispa").stinger.schmidt.value, 2.0, "Schmidt avispa común 2")
	assert_eq(Insects.find_by_id("hormigabala").stinger.schmidt.value, 4.0, "Schmidt hormiga bala 4")
	assert_eq(Insects.find_by_id("pepsis").stinger.schmidt.value, 4.0, "Schmidt Pepsis 4")
	# abeja 2-3 mN en piel de cerdo (Zhao 2015): dentro del rango medido 1,34-5,75 mN
	assert_true(bee.insertionN.range[0] <= 0.002 and bee.insertionN.range[1] >= 0.003, "abeja: 2-3 mN dentro del rango medido")
	var wasp: Dictionary = Insects.find_by_id("papelera").stinger
	assert_eq(wasp.insertionN.range, [0.006, 0.008], "avispa papelera 6-8 mN (Zhao 2015; FISICA.md dice «avispa»)")
	# ángulos óptimos (Das 2018): −6° la abeja y +10° la avispa (Vespula vulgaris)
	assert_eq(bee.angleDeg.value, -6.0, "abeja −6°")
	assert_eq(Insects.find_by_id("avispa").stinger.angleDeg.value, 10.0, "avispa +10°")
	# punta ~5-6 veces más blanda que la base (Das 2018: 0,42/0,07 y 0,56/0,09 GPa)
	assert_near(bee.material.base.H / bee.material.tip.H, 6.0, 0.01, 0.0, "abeja: base 6 veces más dura")


func test_honestidad_si_hay_estimaciones_la_ficha_lo_dice() -> void:
	# si la punta, el alcance, la masa o la fuerza son estimaciones, la descripción lo dice
	for s: Dictionary in Insects.STINGERS:
		var st: Dictionary = s.stinger
		var estimated := false
		for k: String in ["tipRadiusUm", "insertMm", "massKg"]:
			if st[k].quality == "estimate":
				estimated = true
		if st.insertionN.value == null:
			estimated = true  # la fuerza de perforación sale del modelo, no de una medición
		if estimated:
			assert_true(String(s.desc).to_lower().contains("estim"), "%s: la descripción avisa de las estimaciones" % s.id)
			assert_true(s.quality != "primary", "%s: una ficha con estimaciones no es «primary»" % s.id)
