## Ventanilla templada y parabrisas laminado (core/lab/glazing.gd, unidad 1f): el perfil de tensiones del temple,
## los trozos (Nielsen, Schneider & Kraus 2022) frente a los límites de la CEPE R43, la grieta que atraviesa la capa
## comprimida y el laminado que se agrieta sin caer. La flexión de la hoja es la de physics.gd (pane_break, Roark).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Glazing = preload("res://core/lab/glazing.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


func test_objetivos_nuevos_completos() -> void:
	var ids := {}
	for t: Dictionary in Data.TARGETS:
		ids[t.id] = true
	for t: Dictionary in Glazing.TARGETS:
		assert_false(ids.has(t.id), "%s no choca con un id del 1.x" % t.id)
		for k: String in ["id", "name", "hv", "E", "mohs", "col", "mu", "W", "pane", "frac", "fact", "source", "quality"]:
			assert_true(t.has(k), "%s lleva %s" % [t.id, k])
		assert_true(QUALITIES.has(t.quality) and QUALITIES.has(t.frac.quality), "%s: calidad" % t.id)
		assert_true(Physics.truthy(t.get("brittle")), "%s es frágil" % t.id)
		assert_true(Fracture.props(t) != null, "%s tiene datos de fractura" % t.id)
	var side: Dictionary = Glazing.SIDE_WINDOW
	assert_near(side.frac.dolUm, Glazing.compression_depth_mm(side.pane.t) * 1000.0, 1e-12, 0.0, "capa comprimida del 21 %")
	assert_eq(side.pane.fgk, 120.0, "resistencia del templado (EN 12150-1)")
	assert_eq(Glazing.WINDSCREEN.pane.fgk, 45.0, "el laminado es de vidrio recocido (EN 572-1)")


func test_perfil_parabolico() -> void:
	# σ(ζ) ∝ ½(3ζ² − 1) en compresión: se anula en ζ = 1/√3, a (1 − 1/√3)/2 del espesor desde la cara
	assert_near(Glazing.COMPRESSION_DEPTH_FRAC, 0.5 * (1.0 - 1.0 / sqrt(3.0)), 1e-15, 0.0, "profundidad de compresión")
	assert_true(absf(Glazing.COMPRESSION_DEPTH_FRAC - 0.21) < 0.005, "~21 % (Nielsen et al. 2022)")
	# compresión media de esa capa por integración numérica del perfil
	var n := 20000
	var z0 := 1.0 / sqrt(3.0)
	var acc := 0.0
	for i in n:
		var z := z0 + (1.0 - z0) * (i + 0.5) / n
		acc += 0.5 * (3.0 * z * z - 1.0)
	assert_near(acc / n, Glazing.MEAN_COMPRESSION_FRAC, 1e-6, 0.0, "compresión media")
	assert_near(Glazing.SURFACE_CRACK_Y, 1.12 * 2.0 / PI, 1e-15, 0.0, "factor de grieta de superficie")


func test_trozos_del_templado() -> void:
	assert_near(Glazing.strain_energy_density(100.0, 72.0, 0.22), 21666.666666666668, 1e-12, 0.0, "U_D con 100 MPa")
	var d := Glazing.fragment_size_mm(100.0, 72.0, 0.22)
	assert_near(d, 5.6353846153846154, 1e-12, 0.0, "tamaño de trozo")
	assert_near(Glazing.fragments_per_25cm2(d), 90.899658772992666, 1e-12, 0.0, "trozos en 5 × 5 cm")
	# la compresión estimada (100 MPa) cae dentro de lo que exige la CEPE R43 (40-400 trozos) y los extremos de ese
	# intervalo corresponden a ~81 y ~144 MPa
	var n100 := Glazing.fragments_per_25cm2(d)
	assert_true(n100 >= Glazing.R43_FRAGMENTS_MIN and n100 <= Glazing.R43_FRAGMENTS_MAX, "100 MPa cumple la R43")
	assert_true(Glazing.fragments_per_25cm2(Glazing.fragment_size_mm(81.0, 72.0, 0.22)) < 40.5, "81 MPa, en el mínimo")
	assert_true(Glazing.fragments_per_25cm2(Glazing.fragment_size_mm(144.0, 72.0, 0.22)) < 400.0, "144 MPa, en el máximo")
	var prev := 0.0
	for s: float in [60.0, 80.0, 100.0, 120.0, 150.0]:
		var nf := Glazing.fragments_per_25cm2(Glazing.fragment_size_mm(s, 72.0, 0.22))
		assert_true(nf > prev, "más temple, trozos más pequeños (%s MPa)" % s)
		prev = nf


func test_grieta_que_atraviesa_la_capa_comprimida() -> void:
	var side: Dictionary = Glazing.SIDE_WINDOW
	var cases := [[68.0, 1018.6999502200678], [16.0, 242.09377066474397], [14.0, 220.54642795680414], [75.0, 1339.5256095633410]]
	for c: Array in cases:
		var p := Glazing.pierce_load(side.pane, side.frac, side.E, side.hv, tan(c[0] * Contact.DEG))
		assert_near(p, c[1], 1e-9, 0.0, "punta de %s°" % c[0])
	# más temple, más espesor o una punta más roma piden más carga
	var ta := tan(16.0 * Contact.DEG)
	var base := Glazing.pierce_load(side.pane, side.frac, side.E, side.hv, ta)
	var frac2: Dictionary = side.frac.duplicate()
	frac2.sigmaS = 150.0
	assert_true(Glazing.pierce_load(side.pane, frac2, side.E, side.hv, ta) > base, "más compresión")
	var pane2: Dictionary = side.pane.duplicate()
	pane2.t = 6.0
	assert_true(Glazing.pierce_load(pane2, side.frac, side.E, side.hv, ta) > base, "más espesor")
	assert_true(Glazing.pierce_load(side.pane, side.frac, side.E, side.hv, tan(40.0 * Contact.DEG)) > base, "más roma")


func test_ventanilla_estalla_o_aguanta() -> void:
	var side: Dictionary = Glazing.SIDE_WINDOW
	var pb: Dictionary = Physics.pane_break(side.pane, side.E, 0.0)
	assert_near(pb.F, 542.23105486515033, 1e-9, 0.0, "se parte por flexión desde ~540 N (120 MPa)")
	var annealed := Physics.pane_break({ "t": 4.0, "a": 250.0, "fgk": 45.0, "nu": 0.22 }, side.E, 0.0)
	assert_true(pb.F > 2.5 * annealed.F, "el templado aguanta ~2,7 veces más que el recocido")
	# pico de un golpe como en la ventana del 1.x: la masa contra la hoja y la pata (10 N/mm) en serie
	var k_eff: float = 1.0 / (1.0 / pb.k + 1.0 / Physics.MODEL.limbStiffness)
	var bear := 7.0 * sqrt(4.0 * k_eff * 1000.0)
	var cat := 4.0 * sqrt(0.15 * k_eff * 1000.0)
	assert_near(bear, 1346.3243880749696, 1e-9, 0.0, "pico del oso")
	var r_bear: Dictionary = Glazing.tempered_result(side, bear, pb.F, false, bear, tan(26.0 * Contact.DEG))
	assert_true(r_bear.shattered, "el oso la hace estallar")
	assert_eq(r_bear.cause, "flexión", "por flexión")
	assert_near(r_bear.fragments25, 90.899658772992666, 1e-12, 0.0, "~91 trozos por 5 × 5 cm")
	assert_false(Glazing.tempered_result(side, cat, pb.F, false, cat, tan(14.0 * Contact.DEG)).shattered, "el gato no")
	# la garra de tigre de diamante apretada con 260 N: sin flexión suficiente, pero su grieta atraviesa la capa
	var r_tiger: Dictionary = Glazing.tempered_result(side, 260.0, pb.F, true, 260.0, tan(16.0 * Contact.DEG))
	assert_true(r_tiger.shattered, "la punta dura y afilada la hace estallar")
	assert_eq(r_tiger.cause, "grieta", "por la grieta")
	assert_false(Glazing.tempered_result(side, 260.0, pb.F, false, 260.0, tan(16.0 * Contact.DEG)).shattered, "la misma fuerza con queratina, no")
	assert_false(Glazing.tempered_result(side, 15.0, pb.F, true, 15.0, tan(14.0 * Contact.DEG)).shattered, "el gato de diamante (15 N), no")


func test_parabrisas_se_agrieta_pero_no_cae() -> void:
	var ws: Dictionary = Glazing.WINDSCREEN
	var pb: Dictionary = Physics.pane_break(ws.pane, ws.E, 0.0)
	assert_near(pb.F, 209.65137104384758, 1e-9, 0.0, "se agrieta por flexión desde ~210 N")
	assert_near(Glazing.LAMINATED_BALL_J, 2.26 * 9.81 * 4.0, 1e-12, 0.0, "bola de 2260 g desde 4 m")
	var k_eff: float = 1.0 / (1.0 / pb.k + 1.0 / Physics.MODEL.limbStiffness)
	var bear := 7.0 * sqrt(4.0 * k_eff * 1000.0)
	var r: Dictionary = Glazing.laminated_result(ws, bear, pb.F, false, 98.0)
	assert_true(r.cracked, "el oso lo agrieta")
	assert_true(r.penetrationRisk, "y con 98 J pasa de lo que garantiza la homologación")
	var cat := 4.0 * sqrt(0.15 * k_eff * 1000.0)
	var rc: Dictionary = Glazing.laminated_result(ws, cat, pb.F, false, 1.2)
	assert_false(rc.cracked, "el gato no lo agrieta")
	assert_false(rc.penetrationRisk, "ni hay riesgo")
	var rp: Dictionary = Glazing.laminated_result(ws, 50.0, pb.F, true, 0.0)
	assert_true(rp.cracked, "una grieta de contacto también lo agrieta")
	assert_false(rp.penetrationRisk, "pero empujando no se atraviesa")
