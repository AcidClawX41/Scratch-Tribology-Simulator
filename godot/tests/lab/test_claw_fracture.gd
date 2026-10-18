## Rotura de las garras reforjadas al golpear el metal (core/lab/claw_fracture.gd): que cada material lleve su resistencia
## medida con fuente, que una garra frágil solo se rompa por encima de esa resistencia (y nunca por debajo), que las
## dúctiles se doblen y no estallen, que cerca de la punta el modelo sea el de mellado de la unidad 1f
## (Fracture.tip_chip_load), que con la carga más lejos del vértice (el borde del agujero) la garra aguante más y que las
## formas de romperse (mellarse, partirse por la base) salgan de la geometría.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const CF = preload("res://core/lab/claw_fracture.gd")

const CLAWS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "tigre", "oso", "casuario"]
const QUALITIES := ["primary", "secondary", "estimate"]


## Geometría de una garra reforjada (la del motor: Physics.resolve_tool) con el radio de la base como tope. El material,
## del catálogo 2.0 (los de la 1.x y, desde la 5g, el rubí y la alúmina de la reforja).
static func geom(claw_id: String, inlay_id: String = "zafiro", capped: bool = true) -> Dictionary:
	var claw: Dictionary = Data.find_by_id(Data.CLAWS, claw_id)
	var tool := Physics.resolve_tool({
		"geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": Catalog.find_by_id(Catalog.INLAYS, inlay_id), "claw": claw,
		"model": "2.0",
	})
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR) if capped else Contact.tip_geometry(tool.area, tool.alpha)
	return { "tip": tip, "reach": float(tool.reach) }


func test_cada_material_del_catalogo_tiene_su_comportamiento() -> void:
	for inlay: Dictionary in Data.INLAYS:
		if inlay.id == "none":
			assert_false(CF.is_reforged(inlay), "la queratina no es una garra reforjada")
			assert_eq(CF.behavior(inlay), "", "sin comportamiento de rotura propio")
			continue
		assert_true(CF.is_reforged(inlay), "%s: reforjada" % inlay.id)
		assert_true(["fragil", "ductil", "sin_datos"].has(CF.behavior(inlay)), "%s: frágil, dúctil o sin datos" % inlay.id)
		assert_true(CF.NOUNS.has(inlay.id), "%s: nombre para los textos" % inlay.id)
	# los de la petición de Eric, frágiles y con su resistencia medida
	for id: String in ["tungsteno", "vidrio", "cuarzo", "circonita", "zafiro", "moissanita", "diamante"]:
		assert_eq(CF.behavior(id), "fragil", "%s: frágil" % id)
	for id: String in ["acero", "titanio", "oro"]:
		assert_eq(CF.behavior(id), "ductil", "%s: dúctil" % id)


func test_resistencias_con_fuente_y_banda() -> void:
	for id: String in CF.BRITTLE:
		var b: Dictionary = CF.BRITTLE[id]
		assert_true(Catalog.find_by_id(Catalog.INLAYS, id) != null, "%s existe en el catálogo (Catalog.INLAYS)" % id)
		assert_true(b.min <= b.value and b.value <= b.max, "%s: min ≤ valor ≤ max" % id)
		assert_true(b.min > 0.0 and b.kic > 0.0, "%s: resistencia y tenacidad positivas" % id)
		assert_true(QUALITIES.has(b.quality), "%s: calidad válida" % id)
		assert_true(String(b.source).length() > 60, "%s: fuente con cita" % id)
		# una estimación solo vale con el caso medido más parecido y la suposición escrita
		if b.quality == "estimate":
			assert_true(String(b.source).contains("Caso medido más parecido"), "%s: estimación con su caso medido" % id)
			assert_true(String(b.source).contains("Suposición") or String(b.source).contains("Banda"), "%s: con la suposición escrita" % id)
	for id: String in CF.UNKNOWN:
		assert_true(String(CF.UNKNOWN[id]).length() > 30, "%s: dice por qué no se predice" % id)
		assert_eq(CF.strength(id), null, "%s: sin resistencia inventada" % id)


func test_valores_medidos_de_las_fuentes() -> void:
	# ficha de Saint-Gobain: zafiro 760 MPa ⊥ c y 1035 MPa ∥ c; placas de diamante natural IIa: 2790 ± 1050 MPa
	# (Balmer et al. 2009); metal duro GC-005: 445 000 psi; vidrio recocido: 45 MPa (EN 572-1, la hoja del motor)
	assert_eq(CF.BRITTLE.zafiro.value, 760.0, "zafiro perpendicular al eje c")
	assert_eq(CF.BRITTLE.zafiro.max, 1035.0, "zafiro paralelo al eje c")
	assert_eq(CF.BRITTLE.diamante.value, 2790.0, "diamante natural IIa")
	assert_near(CF.BRITTLE.diamante.min, 2790.0 - 1050.0, 1e-12, 0.0, "banda: menos una desviación")
	assert_near(CF.BRITTLE.diamante.max, 2790.0 + 1050.0, 1e-12, 0.0, "banda: más una desviación")
	assert_near(CF.BRITTLE.tungsteno.value, 445000.0 * 0.006894757, 1e-4, 0.0, "GC-005: 445 000 psi en MPa")
	assert_eq(CF.BRITTLE.vidrio.value, float(Data.find_by_id(Data.TARGETS, "vidrio").pane.fgk), "el vidrio de la norma, el mismo del motor")
	assert_near(CF.BRITTLE.moissanita.min, 380.0 * 1.8 / 4.6, 1e-3, 0.0, "Griffith: σ ∝ K_IC con los mismos defectos")
	# la tenacidad es la misma que usa la fractura de la unidad 1f para esos materiales
	assert_eq(CF.BRITTLE.zafiro.kic, float(Fracture.BRITTLE.zafiro.Kc), "K_c del zafiro de fracture.gd")
	assert_eq(CF.BRITTLE.diamante.kic, float(Fracture.BRITTLE.diamante.Kc), "K_c del diamante de fracture.gd")
	assert_eq(CF.BRITTLE.cuarzo.kic, float(Fracture.BRITTLE.cuarzo.Kc), "K_c del cuarzo de fracture.gd")


func test_los_ductiles_fluyen_con_la_dureza_de_tabor() -> void:
	# σ = H/2,8 con la dureza del catálogo y la constante del motor (Contact.CONTACT.tabor)
	for id: String in CF.DUCTILE:
		var s: Dictionary = CF.strength(id)
		var hv: float = Data.find_by_id(Data.INLAYS, id).hv
		assert_near(s.value, hv * Contact.HV_MPA / float(Contact.CONTACT.tabor), 1e-12, 0.0, "%s: Tabor" % id)
		assert_eq(s.kind, "fluencia", "%s: fluye" % id)


func test_cerca_de_la_punta_es_el_mellado_de_la_unidad_1f() -> void:
	# sin el tope de la base, la carga lateral que empieza a romper la punta es la de Fracture.tip_chip_load (que
	# muestrea 400 secciones; aquí el máximo del cono es analítico, x* = (a_t − h_t·tan α)/(2·tan α))
	for id: String in CLAWS:
		var g := geom(id, "zafiro", false)
		var mine := CF.lateral_limit_n(g.tip, g.reach, 760.0)
		var ref := Fracture.tip_chip_load(g.tip, 760.0, g.reach)
		assert_near(mine, ref, 1e-3, 0.0, "%s: %s N frente a %s N de la 1f" % [id, mine, ref])
		assert_true(mine <= ref + 1e-9, "%s: el máximo analítico nunca es menor que el muestreado" % id)
	# y el talón de águila de zafiro de pulido-materiales.md (tema 4): 8,1 N
	var ag := geom("aguila", "zafiro")
	assert_near(CF.lateral_limit_n(ag.tip, ag.reach, 760.0), 8.1, 0.01, 0.0, "talón de águila de zafiro")


func test_la_seccion_mas_cargada_es_la_del_maximo_de_la_viga() -> void:
	for id: String in CLAWS:
		var g := geom(id)
		var reach: float = g.reach
		var pk := CF.peak(g.tip, reach)
		# nada en la garra está más cargado que la sección del pico (muestreo denso de 2000 secciones)
		var x0: float = maxf(float(g.tip.ht), 1e-6)
		for i in range(0, 2001):
			var x: float = x0 + (reach - x0) * float(i) / 2000.0
			assert_true(CF.bending_per_n(g.tip, x) <= float(pk.factor) * (1.0 + 1e-9), "%s: sección %s mm" % [id, x])
		assert_true(float(pk.xMm) >= x0 and float(pk.xMm) <= reach, "%s: dentro de la garra" % id)


func test_con_la_carga_mas_lejos_del_vertice_la_garra_aguanta_mas() -> void:
	# la chapa ya perforada empuja en el borde del agujero, más arriba, donde la garra es más gruesa: el límite nunca baja
	# al alejar la carga del vértice; con la carga en el vértice (x0 = 0) es el de siempre, al bit
	for id: String in CLAWS:
		var g := geom(id, "zafiro")
		var reach: float = g.reach
		assert_eq(CF.lateral_limit_n(g.tip, reach, 760.0, 0.0), CF.lateral_limit_n(g.tip, reach, 760.0), "%s: x0 = 0 es la punta" % id)
		var prev := 0.0
		var loads: Array[float] = [0.0, 0.05, 0.2, 0.35, 1.0, 3.0, 10.0, reach * 0.5, reach * 0.9]
		loads.sort()
		for x0: float in loads:
			var lim := CF.lateral_limit_n(g.tip, reach, 760.0, x0)
			assert_true(lim >= prev * (1.0 - 1e-12), "%s: con la carga a %s mm aguanta %s N, menos que más cerca (%s N)" % [id, x0, lim, prev])
			prev = lim
			assert_eq(CF.bending_per_n(g.tip, 0.5 * x0, x0), 0.0, "%s: entre el vértice y la carga no hay flexión" % id)


func test_la_seccion_mas_cargada_con_la_carga_lejos_del_vertice() -> void:
	for id: String in CLAWS:
		var g := geom(id)
		var reach: float = g.reach
		for x0: float in [0.1, 0.35, 2.0, reach * 0.3]:
			var pk := CF.peak(g.tip, reach, x0)
			# nada en la garra está más cargado que la sección del pico (muestreo denso de 2000 secciones)
			var lo: float = maxf(maxf(float(g.tip.ht), 1e-6), x0)
			for i in range(0, 2001):
				var x: float = lo + (reach - lo) * float(i) / 2000.0
				assert_true(CF.bending_per_n(g.tip, x, x0) <= float(pk.factor) * (1.0 + 1e-9), "%s, carga a %s mm: sección %s mm" % [id, x0, x])
			assert_true(float(pk.xMm) > x0, "%s: la sección más cargada está más allá de la carga" % id)
			# y lo que se rompe llega más allá de la carga
			var r: Dictionary = CF.evaluate("zafiro", g.tip, reach, 1.001 * CF.lateral_limit_n(g.tip, reach, 760.0, x0), 1.0, x0)
			assert_true(r.breaks and float(r.brokenMm) > x0, "%s, carga a %s mm: se rompe más allá de la carga" % [id, x0])
			assert_eq(r.loadXmm, x0, "%s: la carga en el resultado" % id)


func test_una_garra_fragil_solo_se_rompe_por_encima_de_su_resistencia_medida() -> void:
	for id: String in CLAWS:
		for mat: String in CF.BRITTLE:
			var g := geom(id, mat)
			var s: float = CF.BRITTLE[mat].value
			var limit := CF.lateral_limit_n(g.tip, g.reach, s)
			var tag := "%s de %s" % [id, mat]
			# por debajo de su resistencia, aguanta; por encima, se rompe (μ = 1: la carga lateral es la normal)
			var below: Dictionary = CF.evaluate(mat, g.tip, g.reach, limit * 0.999, 1.0)
			var above: Dictionary = CF.evaluate(mat, g.tip, g.reach, limit * 1.001, 1.0)
			assert_false(below.breaks, "%s: a 0,999 del límite no se rompe" % tag)
			assert_eq(below.mode, "intacta", "%s: intacta" % tag)
			assert_true(float(below.stressMPa) < s, "%s: tensión por debajo de la resistencia" % tag)
			assert_true(above.breaks, "%s: a 1,001 del límite se rompe" % tag)
			assert_true(["mella", "parte"].has(above.mode), "%s: se mella o se parte" % tag)
			assert_true(float(above.stressMPa) >= s, "%s: solo con la tensión por encima de %s MPa" % [tag, s])
			assert_false(above.bends, "%s: un frágil no se dobla" % tag)
			assert_near(float(above.limitN), limit, 1e-12, 0.0, "%s: el mismo límite" % tag)
			# la banda: con la resistencia mínima se rompe antes; con la máxima, después
			assert_true(float(above.limitMinN) <= limit and limit <= float(above.limitMaxN), "%s: banda del límite" % tag)
			if above.breaksHi:
				assert_true(above.breaks, "%s: si se rompe con la resistencia máxima, también con la central" % tag)
			if above.breaks:
				assert_true(above.breaksLo, "%s: y con la mínima" % tag)


func test_los_ductiles_se_doblan_y_nunca_estallan() -> void:
	for id: String in CLAWS:
		for mat: String in CF.DUCTILE:
			var g := geom(id, mat)
			for f: float in [1.0, 10.0, 100.0, 1000.0, 10000.0]:
				var r: Dictionary = CF.evaluate(mat, g.tip, g.reach, f, 1.0)
				assert_false(r.breaks, "%s de %s a %s N: no estalla" % [id, mat, f])
				assert_true(["intacta", "dobla"].has(r.mode), "%s de %s: aguanta o se dobla" % [id, mat])
				assert_eq(r.bends, r.mode == "dobla", "%s de %s: bends coherente" % [id, mat])


func test_mas_fuerza_rompe_un_trozo_mas_largo_hasta_partirla_entera() -> void:
	for id: String in CLAWS:
		var g := geom(id, "zafiro")
		var prev := 0.0
		var whole := false
		for f: float in [5.0, 20.0, 50.0, 200.0, 1000.0, 5000.0, 20000.0, 80000.0]:
			var r: Dictionary = CF.evaluate("zafiro", g.tip, g.reach, f, 1.0)
			assert_true(float(r.brokenMm) >= prev - 1e-9, "%s: a %s N no se rompe menos" % [id, f])
			assert_true(float(r.brokenMm) <= g.reach + 1e-9, "%s: nunca más que la garra" % id)
			if r.mode == "parte":
				assert_true(r.atBase and float(r.brokenMm) == g.reach, "%s: partida por la base, entera" % id)
				whole = true
			elif whole:
				fail("%s: tras partirse entera no puede volver a mellarse" % id)
			prev = r.brokenMm
		assert_true(whole, "%s: con fuerza de sobra se parte por la base" % id)


func test_un_material_mas_resistente_nunca_pierde_un_trozo_mas_largo() -> void:
	var mats: Array = CF.BRITTLE.keys()
	mats.sort_custom(func(a: String, b: String) -> bool: return float(CF.BRITTLE[a].value) < float(CF.BRITTLE[b].value))
	for id: String in CLAWS:
		for f: float in [50.0, 500.0, 5000.0]:
			var prev := INF
			for mat: String in mats:
				var g := geom(id, mat)
				var r: Dictionary = CF.evaluate(mat, g.tip, g.reach, f, 1.0)
				assert_true(float(r.brokenMm) <= prev + 1e-9, "%s a %s N: %s no pierde más que uno menos resistente" % [id, f, mat])
				prev = r.brokenMm


func test_sin_carga_lateral_no_se_rompe() -> void:
	# de frente (μ = 0 o sin fuerza) no hay flexión: el metal cede antes que la punta
	var g := geom("tigre", "vidrio")
	for mat: String in ["vidrio", "diamante", "acero"]:
		var r: Dictionary = CF.evaluate(mat, g.tip, g.reach, 5000.0, 0.0)
		assert_eq(r.lateralN, 0.0, "%s: sin carga lateral" % mat)
		assert_eq(r.mode, "intacta", "%s: aguanta de frente" % mat)
		assert_true(String(r.vsub).contains("de frente"), "%s: lo dice" % mat)


func test_queratina_y_desconocidos() -> void:
	var g := geom("aguila")
	assert_eq(CF.evaluate("none", g.tip, g.reach, 100.0, 1.0), null, "la queratina no se evalúa aquí")
	assert_eq(CF.evaluate("kriptonita", g.tip, g.reach, 100.0, 1.0), null, "material desconocido")
	var hem: Dictionary = CF.evaluate("hematites", g.tip, g.reach, 100.0, 1.0)
	assert_eq(hem.mode, "sin_datos", "hematites: sin datos")
	assert_false(hem.breaks, "sin datos no se inventa la rotura")
	assert_eq(hem.verdict, "SIN DATOS DE ROTURA", "y lo dice")


func test_textos_y_numeros_como_javascript() -> void:
	var g := geom("tigre", "zafiro")
	var r: Dictionary = CF.evaluate("zafiro", g.tip, g.reach, 1137.0, 1.0)
	assert_eq(r.verdict, "SE MELLA LA PUNTA", "veredicto")
	assert_true(String(r.vsub).contains("zafiro") and String(r.vsub).contains("760 MPa"), r.vsub)
	var d: Dictionary = CF.evaluate("acero", g.tip, g.reach, 1137.0, 1.0)
	assert_eq(d.verdict, "SE DOBLA LA GARRA", "el acero se dobla")
	assert_true(String(d.vsub).contains("no estalla"), d.vsub)
	var p: Dictionary = CF.evaluate("vidrio", g.tip, g.reach, 1137.0, 1.0)
	assert_eq(p.verdict, "SE PARTE LA GARRA", "el vidrio se parte por la base")
