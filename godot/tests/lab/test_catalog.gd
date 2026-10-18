## Catálogo de la 2.0 (core/lab/catalog.gd): su parte 1.x es exactamente data.gd (el port de data.js que comparan los
## tests del oráculo), salvo las garras, que llevan las correcciones de la 2.0 (claws_v2.gd: ClawsV2.apply a cada una,
## unidad 4b); los añadidos de la 2.0 van detrás con ids nuevos y las claves de su catálogo, y la interfaz del
## laboratorio y su estado leen Catalog, no Data.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Insects = preload("res://core/lab/insects.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")


func test_la_parte_1x_es_data() -> void:
	var data := {
		"GEOMS": Data.GEOMS, "BASES": Data.BASES, "BASE_GROUPS": Data.BASE_GROUPS, "INLAYS": Data.INLAYS,
		"CLAWS": Data.CLAWS, "CLAW_GROUPS": Data.CLAW_GROUPS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES,
	}
	var app := {
		"GEOMS": Catalog.GEOMS, "BASES": Catalog.BASES, "BASE_GROUPS": Catalog.BASE_GROUPS, "INLAYS": Catalog.INLAYS,
		"CLAWS": Catalog.CLAWS, "CLAW_GROUPS": Catalog.CLAW_GROUPS, "TARGETS": Catalog.TARGETS, "TYPES": Catalog.TYPES,
	}
	assert_eq(Catalog.PARTS.keys(), data.keys(), "catálogos con partes 1.x y 2.0")
	for key: String in data:
		var one: Array = data[key]
		var all: Array = app[key]
		var extra: Array = Catalog.PARTS[key][1]
		# las garras de la 1.x, con las correcciones de la 2.0 (las que no tienen, idénticas)
		var one_app: Array = one.map(func(c: Dictionary) -> Dictionary: return ClawsV2.apply(c)) if key == "CLAWS" else one
		assert_eq(all.size(), one.size() + extra.size(), "%s: 1.x + añadidos de la 2.0" % key)
		assert_true(same(all.slice(0, one.size()), one_app), "%s: la parte 1.x es la de data.gd, en el mismo orden" % key)
		assert_true(same(all.slice(one.size()), extra), "%s: los añadidos de la 2.0 van detrás" % key)
		assert_true(same(Catalog.PARTS[key][0], one), "%s: PARTS (la parte 1.x, tal cual)" % key)
		assert_true(same(Catalog.list(key), all), "%s: list()" % key)
	assert_true(same(Catalog.SKIN_LAYERS, Data.SKIN_LAYERS) and same(Catalog.PAINT_LAYERS, Data.PAINT_LAYERS) and same(Catalog.HUMAN, Data.HUMAN))


## Las rapaces corregidas de la 2.0 (docs/fisica/coche-en-marcha.md §9.7): el agarre del águila, la arpía y el halcón
## cambia, las fichas llevan su texto y su fuente (sources2), y data.gd, el del oráculo, no se toca. Y la ficha del
## casuario (unidad 4b): corre a 50 km/h, pero su patada es un salto a unos 17 km/h (la del coche en marcha, unidad 4d);
## desde la unidad 4i, su golpe del banco también es esa patada (ClawsV2.kick_strike).
func test_las_garras_llevan_las_correcciones_de_la_2_0() -> void:
	var changed := 0
	for c: Dictionary in Data.CLAWS:
		var app: Dictionary = Catalog.find_by_id(Catalog.CLAWS, c.id)
		if ClawsV2.has_overrides(c):
			changed += 1
			assert_true(app.has("sources2"), "%s: con la procedencia de cada campo corregido" % c.id)
			for k: String in ClawsV2.OVERRIDES[c.id]:
				assert_eq(app[k], ClawsV2.value(c, k), "%s.%s: el valor de la 2.0" % [c.id, k])
		else:
			assert_eq(app, c, "%s: sin correcciones, la de la 1.x" % c.id)
	assert_eq(changed, ClawsV2.OVERRIDES.size(), "todas las correcciones llegan al catálogo")
	assert_eq(Catalog.find_by_id(Catalog.CLAWS, "aguila").force, 100.9, "el águila agarra ~100 N (Sustaita & Hertel 2010)")
	assert_eq(Catalog.find_by_id(Catalog.CLAWS, "arpia").force, 178.5)
	assert_eq(Catalog.find_by_id(Catalog.CLAWS, "halcon").force, 15.8)
	assert_eq(Data.find_by_id(Data.CLAWS, "aguila").force, 110.0, "data.gd no cambia: el oráculo 1.x sigue igual")
	var cas: Dictionary = Catalog.find_by_id(Catalog.CLAWS, "casuario")
	assert_true(String(cas.desc).contains("17 km/h") and not String(cas.desc).contains("patada a 50"), cas.desc)
	assert_eq(cas.sources2.desc.quality, "estimate", "la velocidad de la patada es una estimación")
	assert_true(String(Data.find_by_id(Data.CLAWS, "casuario").desc).contains("patada a 50 km/h"), "data.gd no cambia")
	# unidad 4i: el golpe del banco es la patada del coche en marcha (la 1.x, 8 m/s y 5 kg, sigue en data.gd)
	assert_eq(cas.strike, ClawsV2.kick_strike(float(cas.mass)).value, "el golpe del banco es la patada del coche en marcha")
	assert_eq(cas.sources2.strike.quality, "estimate", "estimación con el caso medido más parecido")
	assert_eq(Data.find_by_id(Data.CLAWS, "casuario").strike, { "v": 8.0, "m": 5.0 }, "data.gd no cambia: el oráculo 1.x sigue igual")


## El velocirraptor reconstruido (unidad 4i; docs/fisica/velociraptor.md §10.1): solo en el catálogo 2.0, en su grupo
## «Dinosaurios (reconstrucción)», detrás de los aguijones; data.gd y el oráculo 1.x no lo tienen.
func test_el_velocirraptor_solo_en_el_catalogo_2_0() -> void:
	var raptor: Variant = Catalog.find_by_id(Catalog.CLAWS, "velociraptor")
	assert_true(raptor != null, "está en el catálogo 2.0")
	assert_eq(raptor, Velociraptor.ENTRY, "la entrada de velociraptor.gd, tal cual (no tiene correcciones)")
	assert_eq(Catalog.V2_CLAWS.slice(Insects.STINGERS.size()), Velociraptor.entries() + VelociraptorFilm.entries(),
		"V2_CLAWS: los aguijones y, detrás, Velociraptor.entries() y el de película (unidad 4i-B2)")
	assert_true(Catalog.CLAW_GROUPS.has(Velociraptor.GROUP) and Catalog.V2_CLAW_GROUPS.has(Velociraptor.GROUP), "su grupo, en la 2.0")
	assert_eq(String(raptor.group), Velociraptor.GROUP, "«Dinosaurios (reconstrucción)»")
	assert_true(Catalog.is_v2("CLAWS", "velociraptor"), "es un añadido de la 2.0")
	assert_eq(Data.find_by_id(Data.CLAWS, "velociraptor"), null, "data.gd no lo tiene (el oráculo 1.x)")
	assert_false(Data.CLAW_GROUPS.has(Velociraptor.GROUP), "ni su grupo")
	# lleva todas las claves de una garra de data.gd, para que el motor, el banco y la interfaz la traten como una
	for key: String in Data.find_by_id(Data.CLAWS, "aguila"):
		assert_true((raptor as Dictionary).has(key), "velociraptor.%s" % key)
	assert_true(String(raptor.source).length() > 40 and raptor.quality == "estimate", "fuente y calidad")
	assert_true(same(Catalog.CLAWS, Catalog.list("CLAWS")), "list() da el catálogo corregido")


func test_los_anadidos_tienen_ids_nuevos_y_las_claves_de_su_catalogo() -> void:
	for key: String in ["GEOMS", "BASES", "INLAYS", "CLAWS", "TARGETS", "TYPES"]:
		var one: Array = Catalog.PARTS[key][0]
		var extra: Array = Catalog.PARTS[key][1]
		var ids := {}
		for x: Dictionary in Catalog.list(key):
			assert_false(ids.has(x.id), "%s: id repetido «%s»" % [key, x.id])
			ids[x.id] = true
		# las claves que tienen TODAS las entradas 1.x del catálogo (las de una garra, en CLAWS)
		var common: Array = (one[0] as Dictionary).keys()
		for x: Dictionary in one:
			common = common.filter(func(k: String) -> bool: return x.has(k))
		for x: Dictionary in extra:
			for k: String in common:
				assert_true(x.has(k), "%s: al añadido «%s» le falta la clave «%s»" % [key, x.get("id"), k])
			assert_true(x.has("source") and x.has("quality"), "%s: «%s» lleva source y quality" % [key, x.get("id")])
			assert_true(Catalog.is_v2(key, x.id), "%s: «%s» es de la 2.0" % [key, x.id])
		for x: Dictionary in one:
			assert_false(Catalog.is_v2(key, x.id), "%s: «%s» es de la 1.x" % [key, x.id])
	for c: Dictionary in Catalog.CLAWS:
		assert_true(Catalog.CLAW_GROUPS.has(c.group), "garra %s: grupo «%s» en CLAW_GROUPS" % [c.id, c.group])
	for b: Dictionary in Catalog.BASES:
		assert_true(Catalog.BASE_GROUPS.has(b.group), "material %s: grupo «%s» en BASE_GROUPS" % [b.id, b.group])


func test_funciones_de_data() -> void:
	assert_eq(Catalog.find_by_id(Catalog.CLAWS, "tigre"), Data.find_by_id(Data.CLAWS, "tigre"))
	assert_eq(Catalog.find_by_id(Catalog.TARGETS, "no-existe"), null)
	for c: Dictionary in Catalog.CLAWS:
		assert_eq(Catalog.claw_title(c), Data.claw_title(c))
	for t: Dictionary in Catalog.TARGETS:
		assert_true(same(Catalog.car_layers(t), Data.car_layers(t)), "car_layers(%s)" % t.id)
	# la selección inicial del banco sale del catálogo
	assert_eq(LabState.LAB_DEFAULTS.geom, Catalog.GEOMS[3])
	assert_eq(LabState.LAB_DEFAULTS.target, Catalog.TARGETS[4])


func test_la_interfaz_y_el_banco_leen_catalog_y_no_data() -> void:
	var files := gd_files("res://app/lab")
	files.append("res://app/main.gd")
	files.append("res://core/lab/lab_state.gd")
	for f in files:
		var raw := FileAccess.get_file_as_string(f)
		assert_false(raw.contains("\"res://core/lab/data.gd\""), "%s importa data.gd: tiene que leer core/lab/catalog.gd" % f)
