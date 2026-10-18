## Flexión y rotura de la uña (core/lab/bending.gd, unidad 1f): datos con fuente, cargas de rotura de referencia y
## las invariantes («más larga, se dobla antes», «mojada, antes», «más gruesa, después»). Comprueba también la
## afirmación de la hoja de ruta: una stiletto de salón cede mucho antes de 30 N.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Bending = preload("res://core/lab/bending.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


func test_datos_con_fuente_y_calidad() -> void:
	for id: String in Bending.NAILS:
		var n: Dictionary = Bending.NAILS[id]
		assert_true(Data.find_by_id(Data.BASES, id) != null, "%s es una base del banco" % id)
		assert_true(QUALITIES.has(n.quality) and String(n.source).length() > 20, "%s: fuente y calidad" % id)
		assert_true(n.t > 0.2 and n.t < 1.5 and n.sigma > 10.0, "%s: espesor y resistencia con sentido" % id)
	assert_eq(Bending.nail_of("diamante"), null, "el diamante no tiene dato: no se calcula su rotura")
	# los metales, con la resistencia a tracción medida de un metal con la dureza del catálogo (unidad 4a: sustituye a la
	# estimación por Tabor, σ = H/2,8, que daba 700 y 525 MPa): el acero de 200 HV, 640 MPa por la DIN EN ISO 18265; el
	# titanio de grado 2 (~150 HV), 483 MPa típicos (ficha de Rolled Alloys)
	assert_eq(Data.find_by_id(Data.BASES, "metal").hv, 200.0, "la conversión de la ISO 18265 es la de 200 HV")
	assert_eq(Bending.NAILS.metal.sigma, 640.0, "acero de 200 HV: Rm 640 MPa (DIN EN ISO 18265)")
	assert_eq(Data.find_by_id(Data.BASES, "titanio").hv, 150.0, "el titanio de grado 2 tiene ~150 HV")
	assert_eq(Bending.NAILS.titanio.sigma, 483.0, "titanio de grado 2: Rm típica 483 MPa")
	for id: String in ["metal", "titanio"]:
		var hv: float = Data.find_by_id(Data.BASES, id).hv
		assert_true(Bending.NAILS[id].sigma < hv * Contact.HV_MPA / 2.8, "%s: la medida queda por debajo de la cota de Tabor" % id)
	assert_eq(Bending.NAILS.natural.t, 0.49, "espesor medido (Baraldi 2015)")
	assert_eq(Bending.NAILS.natural.sigma, 63.7, "resistencia medida (Baraldi 2015)")


func test_cargas_de_referencia() -> void:
	var cases := [
		["natural", 4.0, false, 0.5, true, 27.502071054994893],
		["natural", 8.0, false, 0.5, true, 13.751035527497447],
		["natural", 6.0, true, 0.5, true, 3.6669428073326529],
		["acrilico", 12.0, false, 0.6, true, 12.842844907115909],
		["metal", 8.0, false, 0.5, false, 207.23695614438853],
		["zafiro", 4.0, false, 0.5, false, 492.18777084292276],
	]
	for c: Array in cases:
		var r: Dictionary = Bending.evaluate(c[0], c[1], c[2], 1.0, c[3], c[4])
		assert_near(r.breakN, c[5], 1e-9, 0.0, "%s de %s mm%s" % [c[0], c[1], " (mojada)" if c[2] else ""])
	assert_eq(Bending.evaluate("natural", 8.0, false, 30.0, 0.5, true).mode, "dobla", "la uña natural se dobla")
	assert_eq(Bending.evaluate("acrilico", 8.0, false, 30.0, 0.5, true).mode, "parte", "el acrílico se parte")


func test_una_stiletto_de_salon_cede_antes_de_30N() -> void:
	# La afirmación de FISICA.md («una stiletto real se partiría mucho antes de 30 N»), para las tres bases del salón y
	# con la fricción de cada material del banco: la natural cede a ~14 N y el gel y el acrílico, a 13-28 N (con poca
	# fricción es cuando más aguantan).
	for base: String in ["natural", "gel", "acrilico"]:
		for g: String in ["stiletto", "stilettoxl"]:
			var l: float = Data.find_by_id(Data.GEOMS, g).reach
			for t: Dictionary in Data.TARGETS:
				var r: Dictionary = Bending.evaluate(base, l, false, 30.0, t.mu, true)
				assert_true(r.broken and r.breakN < 30.0, "%s %s sobre %s cede a %s N" % [base, g, t.id, r.breakN])
	assert_true(Bending.evaluate("natural", 8.0, false, 30.0, 0.5, true).breakN < 15.0, "la stiletto natural, a menos de 15 N")


func test_invariantes() -> void:
	for base: String in Bending.NAILS:
		var prev := INF
		for l: float in [2.0, 4.0, 6.0, 8.0, 12.0, 20.0]:
			var r: Dictionary = Bending.evaluate(base, l, false, 1.0, 0.5, true)
			assert_true(r.breakN < prev, "%s: más larga, cede antes (%s mm)" % [base, l])
			prev = r.breakN
	# mojada, antes (solo la queratina: la base natural)
	assert_true(Bending.evaluate("natural", 6.0, true, 1.0, 0.5, true).breakN < Bending.evaluate("natural", 6.0, false, 1.0, 0.5, true).breakN, "mojada")
	# más fricción al arrastrar, más flexión, cede antes; apretando la fricción no cuenta
	assert_true(Bending.evaluate("natural", 6.0, false, 1.0, 0.6, true).breakN < Bending.evaluate("natural", 6.0, false, 1.0, 0.1, true).breakN, "fricción")
	assert_eq(Bending.bend_factor(45.0, 0.9, false), Bending.bend_factor(45.0, 0.1, false), "apretando no cuenta la fricción")
	# más gruesa, aguanta más: cuatro veces con el doble de espesor si es plana; en «C», casi el doble (pared delgada)
	var thin := Bending.tip_break_perp({ "t": 0.4, "sigma": 60.0 }, 6.0, false, Bending.NAIL_WIDTH_MM, INF)
	var thick := Bending.tip_break_perp({ "t": 0.8, "sigma": 60.0 }, 6.0, false, Bending.NAIL_WIDTH_MM, INF)
	assert_near(thick / thin, 4.0, 1e-12, 0.0, "plana: el doble de espesor, cuatro veces más")
	var thin_c := Bending.tip_break_perp({ "t": 0.4, "sigma": 60.0 }, 6.0, false)
	var thick_c := Bending.tip_break_perp({ "t": 0.8, "sigma": 60.0 }, 6.0, false)
	assert_true(thick_c / thin_c > 1.5 and thick_c / thin_c < 4.0, "en «C»: más gruesa, más fuerte")
	# la curvatura en «C» (Jung et al. 2015) la refuerza ~4 veces; sin curvatura es la placa plana (la cota baja)
	assert_near(Bending.section_modulus_arc(11.0, 0.49, INF), Bending.section_modulus(11.0, 0.49), 1e-12, 0.0, "ρ = ∞")
	assert_near(Bending.section_modulus_arc(11.0, 0.49, 7.4), 1.8317332125269536, 1e-9, 0.0, "la «C» del índice")
	assert_near(Bending.section_modulus_arc(11.0, 0.49, 1.0e6), Bending.section_modulus(11.0, 0.49), 1e-3, 0.0, "casi plana")
	var prev_z := INF
	for rho: float in [5.6, 6.0, 7.4, 9.0, 15.0, 50.0]:
		var z := Bending.section_modulus_arc(11.0, 0.49, rho)
		assert_true(z < prev_z, "más curvada (ρ = %s mm), más resistente" % rho)
		prev_z = z
	var r_nat: Dictionary = Bending.evaluate("natural", 8.0, false, 30.0, 0.5, true)
	assert_true(r_nat.flatBreakN < r_nat.breakN, "la placa plana es la cota baja")
	# la forma en planta no importa con la carga en la punta: el máximo está en la raíz
	var l := 8.0
	var f := 1.0
	var b0 := Bending.NAIL_WIDTH_MM
	for tip_w: float in [0.0, 2.0, 5.0, b0]:
		var worst := 0.0
		for i in range(1, 101):
			var x := l * i / 100.0
			var b := tip_w + (b0 - tip_w) * x / l
			worst = maxf(worst, 6.0 * f * x / (b * 0.49 * 0.49))
		assert_near(worst, 6.0 * f * l / (b0 * 0.49 * 0.49), 1e-9, 0.0, "punta de %s mm: el máximo en la raíz" % tip_w)
