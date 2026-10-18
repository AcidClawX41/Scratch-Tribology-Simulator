## Zonas del cuerpo (core/lab/zones.gd, modelo 2.0): datos con fuente, pilas con el esquema de SKIN_LAYERS, la zona por
## defecto igual a la 1.x y los umbrales de la 1.x llevados a cada zona.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Sting = preload("res://core/lab/sting.gd")
const Zones = preload("res://core/lab/zones.gd")
const Pen = preload("res://core/lab/penetration.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
## Orden anatómico de los tejidos: una zona puede saltarse alguno (el dorso de la mano no tiene músculo encima del
## metacarpiano), pero nunca desordenarlos.
const TISSUE_ORDER := ["cornea", "epidermis", "dermis", "grasa", "fascia", "musculo", "cavidad"]
const SCHEMA := ["id", "name", "short", "from", "to", "jT", "jC", "E", "col", "note"]


## Parámetros de compute() con el motor 1.x (unidad 4b: el modelo va explícito; el 2.0 por defecto ya usa las zonas por
## su id, p.zone, y no las capas del objetivo): estos tests prueban las funciones de piel de la 1.x con las pilas de las
## zonas.
static func _p(over: Dictionary) -> Dictionary:
	var p := {
		"geom": Data.find_by_id(Data.GEOMS, "almendra"), "base": Data.BASES[0], "inlay": Data.INLAYS[0],
		"target": Data.TARGETS[0], "force": 4.0, "length": 25.0, "type": Data.TYPES[1], "claw": null, "tear": false,
		"method": "rayado", "strike": false, "passes": 1.0, "wet": false, "model": "1.x",
	}
	p.merge(over, true)
	return p


## La piel con las capas de una zona en el objetivo (target.tissue), para el motor 1.x. En el 2.0, compute() usa p.zone.
static func _skin_in(zone: String) -> Dictionary:
	var t: Dictionary = Data.TARGETS[0].duplicate()
	t.tissue = Zones.stack(zone)
	return t


func test_ids_y_zona_por_defecto() -> void:
	assert_eq(Zones.DEFAULT_ID, "brazo")
	assert_eq(Zones.ids(), ["brazo", "palma", "dorsomano", "cara", "abdomen"])
	assert_eq(Zones.resolve(null).id, "brazo", "sin zona: la de la 1.x")
	assert_eq(Zones.resolve("inventada").id, "brazo", "zona desconocida: la de la 1.x")
	var defaults := 0
	for z: Dictionary in Zones.ZONES:
		if z.get("default", false):
			defaults += 1
		assert_true(String(z.name).length() > 3 and String(z.short).length() > 2, "%s: nombres" % z.id)
		assert_true(String(z.fact).length() > 40 and String(z.site).length() > 10, "%s: ficha" % z.id)
	assert_eq(defaults, 1, "una sola zona por defecto")


## La zona por defecto reproduce SKIN_LAYERS: mismas claves y valores; solo el músculo acaba en el húmero (41,4 mm) en
## vez de en los 60 mm simbólicos de la 1.x, que las funciones de piel tratan como «no acaba».
func test_el_brazo_es_la_piel_de_la_1x() -> void:
	var s := Zones.stack("brazo")
	assert_eq(s.size(), Data.SKIN_LAYERS.size())
	for i in s.size():
		var got: Dictionary = s[i]
		var want: Dictionary = Data.SKIN_LAYERS[i]
		for k in SCHEMA:
			if k == "to" and i == s.size() - 1:
				continue
			assert_eq(got.get(k), want.get(k), "%s.%s" % [want.id, k])
	assert_eq(s[-1].to, 41400.0, "el músculo acaba en el húmero")


func test_cada_pila_tiene_el_esquema_y_es_contigua() -> void:
	for id: String in Zones.ids():
		var s := Zones.stack(id)
		assert_eq(s[0].from, 0.0, "%s: empieza en la superficie" % id)
		var last_order := -1
		for i in s.size():
			var l: Dictionary = s[i]
			for k in SCHEMA + ["source", "quality"]:
				assert_true(l.has(k), "%s.%s: falta %s" % [id, l.get("id"), k])
			assert_true(l.to > l.from, "%s.%s: sin espesor" % [id, l.id])
			assert_true(l.jT > 0.0 and l.jC > 0.0 and l.jC <= l.jT, "%s.%s: tenacidades" % [id, l.id])
			assert_true(QUALITIES.has(l.quality), "%s.%s: calidad «%s»" % [id, l.id, l.quality])
			assert_true(String(l.source).length() > 20, "%s.%s: sin fuente" % [id, l.id])
			var order := TISSUE_ORDER.find(l.id)
			assert_true(order > last_order, "%s: %s fuera de orden" % [id, l.id])
			last_order = order
			if i > 0:
				assert_eq(l.from, s[i - 1].to, "%s.%s: hueco o solape" % [id, l.id])
		assert_eq(s[0].id, "cornea", "%s: arriba, la capa córnea" % id)
		assert_eq(s[1].id, "epidermis", "%s: después, la epidermis" % id)


func test_copias_nuevas_en_cada_llamada() -> void:
	var a := Zones.stack("palma")
	a[0].to = 1.0
	assert_eq(Zones.stack("palma")[0].to, 173.0, "modificar una pila no toca el catálogo")


## Los espesores publicados, tal cual (o su derivación sencilla, dicha en la fuente de cada capa).
func test_espesores_con_fuente() -> void:
	var ends := func(id: String) -> Dictionary:
		var out := {}
		for l: Dictionary in Zones.stack(id):
			out[l.id] = [l.from, l.to]
		return out
	var palma: Dictionary = ends.call("palma")
	assert_eq(palma.cornea, [0.0, 173.0], "Egawa 2007: palma 173 µm")
	assert_eq(palma.epidermis[1], 265.0, "Baumann 2024: epidermis entera de la eminencia tenar 265 µm")
	assert_eq(palma.musculo[1] - palma.musculo[0], 13890.0, "Çetiner Şeker 2026: 13,89 mm hasta el metacarpiano")
	var dorso: Dictionary = ends.call("dorsomano")
	assert_eq(dorso.cornea[1], 29.0, "Egawa 2007: dorso de la mano 29,3 µm")
	assert_eq(dorso.grasa[1] - dorso.grasa[0], 4340.0, "Hung 2022: láminas grasas a los 20 años")
	assert_false(dorso.has("musculo"), "sobre el metacarpiano no hay músculo")
	var cara: Dictionary = ends.call("cara")
	assert_eq(cara.cornea[1], 17.0, "Egawa 2007: mejilla 16,8 µm")
	assert_eq(cara.dermis[1] - cara.dermis[0], 1000.0, "Meng 2022: dermis sobre el cigoma ~1 mm")
	assert_eq(Zones.bone_depth_um("cara"), 8700.0, "De Greef 2006: pómulo a (7,4 + 10,0)/2 mm")
	var abd: Dictionary = ends.call("abdomen")
	assert_eq(abd.dermis[1], 2200.0, "Gibney 2010: piel del abdomen 2,2 mm")
	assert_eq(abd.grasa[1] - abd.grasa[0], 13900.0, "Gibney 2010: grasa del abdomen 13,9 mm")
	assert_eq(abd.musculo[1] - abd.musculo[0], 10260.0, "Kim 2012: recto del abdomen 10,26 mm")
	assert_eq(Zones.stack("abdomen")[-1].id, "cavidad", "detrás del músculo, la cavidad abdominal")
	assert_eq(Zones.bone("abdomen"), null, "el abdomen no tiene hueso debajo")
	assert_eq(Zones.bone_depth_um("abdomen"), INF)
	var brazo: Dictionary = ends.call("brazo")
	assert_eq(Zones.bone_depth_um("brazo") - brazo.grasa[1], 28400.0, "Homer 2025: 2,84 cm de la grasa al húmero")


func test_la_palma_tiene_la_capa_cornea_mas_gruesa() -> void:
	var palma: float = Zones.stack("palma")[0].to
	for id: String in Zones.ids():
		if id != "palma":
			assert_true(palma > 5.0 * float(Zones.stack(id)[0].to), "la palma no es un callo frente a %s" % id)
	# y la capa córnea de la mejilla es la más fina (Egawa 2007)
	for id: String in Zones.ids():
		assert_true(float(Zones.stack("cara")[0].to) <= float(Zones.stack(id)[0].to), "mejilla frente a %s" % id)


func test_huesos_con_fuente_y_mas_duros_que_la_queratina() -> void:
	var keratin_max := 0.0
	for c: Dictionary in Data.CLAWS:
		if not c.get("fang", false):
			keratin_max = maxf(keratin_max, c.hv)
	for id: String in Zones.ids():
		var b: Variant = Zones.bone(id)
		if b == null:
			continue
		assert_eq(b.fromUm, Zones.stack(id)[-1].to, "%s: el hueso empieza donde acaban las partes blandas" % id)
		assert_eq(b.toUm, b.fromUm + b.corticalUm, "%s: cortical" % id)
		assert_true(b.corticalUm >= 1000.0 and b.corticalUm <= 6000.0, "%s: cortical de 1-6 mm" % id)
		assert_true(b.hv >= 40.0 and b.hv <= 55.0, "%s: Vickers de cortical humana (Li 2021: 42,5-51,2 HV)" % id)
		assert_true(b.E > 10.0 and b.E < 25.0, "%s: módulo del hueso cortical" % id)
		assert_true(QUALITIES.has(b.quality) and String(b.source).contains("doi:"), "%s: fuente" % id)
		# la queratina seca más dura del banco no llega a 0,85 veces la cortical: el hueso la para (FISICA §4)
		assert_true(keratin_max / b.hv < 0.85, "%s: una garra de %s HV indentaría el hueso" % [id, keratin_max])
	assert_eq(Zones.bone("brazo").hv, 47.25, "Li 2021: húmero 47,25 HV")
	assert_eq(Zones.bone("brazo").corticalUm, 4400.0, "Tingart 2003: 4,4 mm")


func test_capas_del_corte_con_el_hueso() -> void:
	for id: String in Zones.ids():
		var sec := Zones.section_layers(id)
		var soft := Zones.stack(id)
		var has_bone := Zones.bone(id) != null
		assert_eq(sec.size(), soft.size() + (1 if has_bone else 0), id)
		for band: Dictionary in sec:
			assert_true(String(band.look).begins_with("tejido-"), "%s.%s: aspecto" % [id, band.id])
			assert_true(String(band.col).begins_with("#"), "%s.%s: color" % [id, band.id])
		if has_bone:
			assert_eq(sec[-1].id, "hueso")
			assert_true(Zones.SECTION_LOOK.has("tejido-hueso") and Zones.SECTION_BAND.has("hueso"))
	assert_true(Zones.SECTION_LOOK.has("tejido-cavidad") and Zones.SECTION_BAND.has("cavidad"))


## Los umbrales de la abrasión sin romper la piel: en el brazo, exactamente los de la 1.x.
func test_abrasion_por_zona() -> void:
	var brazo := Zones.abrasion_limits("brazo")
	assert_eq([brazo.whiteUm, brazo.excoriateUm, brazo.bleedPasses], [18.0, 75.0, 5.0], "la 1.x")
	var palma := Zones.abrasion_limits("palma")
	assert_eq(palma.excoriateLayer, "cornea", "en la palma, excoriar se queda en el callo")
	assert_true(palma.excoriateUm < palma.corneaUm)
	# una capa córnea (y una epidermis) más gruesa nunca hace sangrar antes
	var rows: Array = []
	for id: String in Zones.ids():
		rows.append(Zones.abrasion_limits(id))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.epiUm < b.epiUm)
	for i in range(1, rows.size()):
		assert_true(rows[i].bleedPasses >= rows[i - 1].bleedPasses - 1e-12, "más epidermis, menos pasadas para sangrar")
	for r: Dictionary in rows:
		assert_true(r.whiteUm <= r.corneaUm and r.excoriateUm <= r.epiUm, "la abrasión no sale de la epidermis")


## Donde la epidermis pasa de los 75 µm de la 1.x (palma, dorso de la mano), la excoriación ahonda con las pasadas y
## llega al final de la epidermis justo cuando empieza a sangrar: nunca «sangra» con la herida dentro del callo. En el
## brazo, siempre los 75 µm de la 1.x (la epidermis entera desde la primera pasada; sangra a partir de la quinta).
func test_excoriacion_con_las_pasadas() -> void:
	for n in [1.0, 2.0, 4.0, 4.999, 5.0, 20.0, 100.0]:
		assert_eq(Zones.excoriation_depth_um("brazo", n), 75.0, "brazo, %s pasadas: la 1.x" % n)
	for id: String in Zones.ids():
		var lim := Zones.abrasion_limits(id)
		var last := 0.0
		for n in [1.0, 2.0, 3.0, 5.0, 7.0, 10.0, 20.0, 50.0, 100.0, 117.0, 118.0, 150.0, 500.0]:
			var d := Zones.excoriation_depth_um(id, n)
			assert_true(d >= last, "%s: más pasadas nunca excorian menos (%s)" % [id, n])
			assert_true(d >= float(lim.excoriateUm) and d <= float(lim.epiUm), "%s: entre la 1.ª pasada y la epidermis" % id)
			var bleeds: bool = n >= float(lim.bleedPasses)
			assert_eq(d == float(lim.epiUm), bleeds or float(lim.excoriateUm) == float(lim.epiUm),
				"%s, %s pasadas: llega a las papilas solo cuando sangra" % [id, n])
			last = d
		# sin salto al empezar a sangrar
		var just_before := Zones.excoriation_depth_um(id, float(lim.bleedPasses) * (1.0 - 1e-9))
		assert_near(just_before, float(lim.epiUm), 1e-6, 0.0, "%s: continuidad en bleedPasses" % id)
	var palma := Zones.abrasion_limits("palma")
	assert_near(palma.bleedPasses, 117.34, 1e-3, 0.0, "palma: 5·(265/75)^2,5 pasadas")
	assert_true(Zones.excoriation_depth_um("palma", 20.0) < palma.corneaUm, "palma, 20 pasadas: aún en el callo")


## Los hitos de severidad: en el brazo, Physics.SKIN_SEV; en todas, crecientes en profundidad y en severidad.
func test_severidad_por_zona() -> void:
	assert_eq(Zones.severity_anchors("brazo"), Physics.SKIN_SEV, "la zona por defecto es la 1.x")
	for id: String in Zones.ids():
		var a := Zones.severity_anchors(id)
		assert_eq(a[0], [0.0, 0.25], id)
		assert_eq(a[-1][1], 0.97, "%s: el hito profundo" % id)
		for i in range(1, a.size()):
			assert_true(a[i][0] > a[i - 1][0] and a[i][1] > a[i - 1][1], "%s: hitos no crecientes" % id)
		var b: Variant = Zones.bone(id)
		if b != null and id != "brazo":
			assert_eq(a[-1][0], b.fromUm, "%s: la herida más grave llega al hueso" % id)
	assert_eq(Zones.severity_anchors("abdomen")[-1][0], 26660.0, "abdomen: la cavidad")


## La severidad por zona: en el brazo, bit a bit la de la 1.x; en todas, creciente y 0,97 desde el hueso o la cavidad.
func test_severidad_interpolada_por_zona() -> void:
	for um in [0.0, 1.0, 18.0, 74.9, 75.0, 200.0, 375.0, 1000.0, 2200.0, 13000.0, 13300.0, 20000.0, 40000.0, 41400.0, 90000.0]:
		assert_eq(Zones.severity("brazo", um), Physics._skin_severity(um), "brazo a %s µm" % um)
	for id: String in Zones.ids():
		var deep: float = Zones.severity_anchors(id)[-1][0]
		var prev := 0.0
		for k in 200:
			var um := 0.5 * pow(1.07, k)
			var s := Zones.severity(id, um)
			assert_true(s >= prev and s <= 0.97, "%s a %s µm: %s" % [id, um, s])
			prev = s
		assert_eq(Zones.severity(id, deep), 0.97, "%s: gravísima en el hito profundo" % id)
		assert_eq(Zones.severity(id, deep * 2.0), 0.97, id)
	# la misma herida es más grave donde el hueso está cerca
	assert_true(Zones.severity("dorsomano", 5000.0) > Zones.severity("brazo", 5000.0), "5 mm en el dorso de la mano")


## Las funciones de piel de la 1.x aceptan las pilas tal cual. Con la del brazo, el rayado de la 1.x da lo mismo.
func test_physics_usa_las_pilas_de_las_zonas() -> void:
	var gato: Dictionary = Data.find_by_id(Data.CLAWS, "gato")
	var tigre: Dictionary = Data.find_by_id(Data.CLAWS, "tigre")
	for over in [{}, { "force": 30.0 }, { "force": 30.0, "passes": 20.0 }, { "claw": gato, "force": 3.0 },
			{ "claw": gato, "force": 15.0, "tear": true }, { "claw": tigre, "force": 260.0 },
			{ "geom": Data.find_by_id(Data.GEOMS, "stiletto"), "force": 30.0 }]:
		var a := Physics.compute(_p(over))
		var b := Physics.compute(_p(over.merged({ "target": _skin_in("brazo") }, true)))
		for k in ["verdict", "vsub", "depthUm", "layer", "bleeds", "sev", "ruptures"]:
			assert_eq(b.get(k), a.get(k), "%s: %s" % [JSON.stringify(over.keys()), k])
	for id: String in Zones.ids():
		var s := Zones.stack(id)
		assert_eq(Physics.skin_layer_at(0.0, s).id, "cornea", id)
		assert_true(is_finite(Physics.skin_tear_depth(5.0, s)), "%s: el desgarro acaba" % id)
		# la ley de perforación 2.0 de los aguijones usa la capa de arriba de cada zona
		assert_true(Sting.puncture_force(PI * 0.00125 * 0.00125, s) > 0.0, "%s: Sting.puncture_force" % id)


## En la palma, el mismo arañazo de gato que sangra en el brazo se queda en el callo. Ojo: con las capas de la palma, la
## heurística de abrasión de la 1.x «arrancaría la epidermis entera» (265 µm) porque usa el fin de la epidermis de la
## pila; el modelo 2.0 usa Zones.abrasion_limits (75 µm, en el callo). Este test fija lo que tiene que dar la
## integración: la herida es el corte (el mismo en µm que en el brazo) y no sangra.
func test_la_palma_protege_de_un_aranazo_de_mimo() -> void:
	var gato: Dictionary = Data.find_by_id(Data.CLAWS, "gato")
	var arm := Physics.compute(_p({ "claw": gato, "force": 3.0 }))
	assert_eq(arm.bleeds, true, "en el brazo sangra")
	var palm_1x := Physics.compute(_p({ "claw": gato, "force": 3.0, "target": _skin_in("palma") }))
	assert_eq(palm_1x.depthUm, 265.0, "la heurística 1.x arranca toda la epidermis de la palma: por eso la 2.0 la cambia")
	var ft: float = palm_1x.tearForce  # la misma fuerza de desgarro (N): el corte no depende de la zona hasta la grasa
	var tear := Pen.tear(ft, "palma", gato.reach)
	var lim := Zones.abrasion_limits("palma")
	var depth := maxf(lim.excoriateUm, tear.depthUm)
	assert_eq(depth, arm.depthUm, "la misma herida en µm que en el brazo")
	assert_true(depth < Zones.epidermis_end_um(Zones.stack("palma")), "en la palma no llega a la epidermis viva: no sangra")
	assert_eq(tear.layerId, "cornea", "se queda en el callo")
