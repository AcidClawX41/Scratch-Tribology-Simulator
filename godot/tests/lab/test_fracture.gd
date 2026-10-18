## Fractura de frágiles (core/lab/fracture.gd, unidad 1f): datos con fuente, valores publicados reproducidos e
## invariantes («más fuerza nunca desagrieta», «más tenaz nunca se agrieta antes», «una punta más blanda nunca
## agrieta»…). Los valores de referencia salen de las fórmulas de docs/fisica/pulido-materiales.md, calculadas aparte
## con un prototipo en JavaScript (mismas operaciones, V8): se exigen con error relativo ≤ 1e-9.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const SAPPHIRE := { "hv": 2000.0, "E": 400.0 }
const DIAMOND := { "hv": 10000.0, "E": 1050.0 }
const KERATIN := { "hv": 25.0, "E": 2.9 }
const STEEL := { "hv": 200.0, "E": 200.0 }


func _target(id: String) -> Dictionary:
	return Data.find_by_id(Data.TARGETS, id)


func _square_tip() -> Dictionary:
	var g: Dictionary = Data.find_by_id(Data.GEOMS, "cuadrada")
	return Contact.tip_geometry(g.area, g.alpha)


func test_datos_con_fuente_calidad_y_objetivo() -> void:
	for id: String in Fracture.BRITTLE:
		var fp: Dictionary = Fracture.BRITTLE[id]
		assert_true(Data.find_by_id(Data.TARGETS, id) != null, "%s es un material del banco" % id)
		assert_true(String(fp.get("source", "")).length() > 20, "%s lleva fuente" % id)
		assert_true(QUALITIES.has(fp.get("quality")), "%s lleva calidad" % id)
		assert_true(fp.Kc > 0.0 and fp.nu > 0.0 and fp.nu < 0.5, "%s: K_c y ν con sentido físico" % id)
	# todo material frágil del banco tiene datos de fractura
	for t: Dictionary in Data.TARGETS:
		if Physics.truthy(t.get("brittle")):
			assert_true(Fracture.props(t) != null, "%s (frágil) tiene datos de fractura" % t.id)
	assert_eq(Fracture.props(_target("acero")), null, "el acero no es frágil")
	assert_eq(Fracture.REF_HV, _target(Fracture.REF_ID).hv, "la dureza del vidrio de referencia es la del catálogo")
	for id: String in Fracture.TOOL_STRENGTH:
		var s: Dictionary = Fracture.TOOL_STRENGTH[id]
		assert_true(Catalog.find_by_id(Catalog.INLAYS, id) != null, "%s es un material de las incrustaciones (del catálogo 2.0: el rubí es de la 5g)" % id)
		assert_true(QUALITIES.has(s.quality) and String(s.source).length() > 20, "%s lleva fuente y calidad" % id)


func test_modulo_efectivo_y_auerbach_de_ren_zhang() -> void:
	# Ren & Zhang 2014: esfera de WC (640 GPa, ν 0,26) de 1,5 mm sobre porcelana LAVA (80 GPa, ν 0,21, 1,10 MPa·√m)
	var es := Fracture.effective_modulus(640.0, 0.26, 80.0, 0.21)
	assert_near(es, 74.595552240197676, 1e-12, 0.0, "E* de la porcelana")
	var p0 := Fracture.auerbach_load(1.1, es, 1.5)
	assert_near(p0, 209.97833690625001, 1e-12, 0.0, "carga de Auerbach")
	# Sesgo conocido: la fórmula sobrestima las cargas medidas sin fricción entre 1,7 y 2,6 veces: 80 N medidos en la
	# LAVA en agua (Ren & Zhang 2014, tabla 1) y 210 N en Pyrex con bola de acero de 5 mm (Conrad et al. 1979, vía
	# Marulli et al. 2023). Se deja documentado (docs/fisica/pulido-materiales.md): apretando, el vidrio real se
	# agrieta antes que en el modelo.
	var ratio_lava := p0 / 80.0
	assert_true(ratio_lava > 1.0 and ratio_lava < 3.0, "LAVA: modelo/medido = %s" % ratio_lava)
	var kc_pyrex := sqrt(63.4e9 / (1.0 - 0.04) * 9.0) / 1.0e6  # G = 0,009 N/mm (Mouginot & Maugis 1985)
	var p_pyrex := Fracture.auerbach_load(kc_pyrex, Fracture.effective_modulus(210.0, 0.3, 63.4, 0.2), 5.0)
	assert_near(p_pyrex, 499.48821874999993, 1e-9, 0.0, "Pyrex con bola de acero de 5 mm")
	assert_true(p_pyrex / 210.0 > 1.0 and p_pyrex / 210.0 < 3.0, "Pyrex: modelo/medido en superficie tal cual")
	assert_true(p_pyrex / 300.0 > 1.0 and p_pyrex / 300.0 < 3.0, "Pyrex: modelo/medido en superficie abrasionada")


func test_factor_de_deslizamiento() -> void:
	assert_near(Fracture.sliding_k(0.22), 8.8778042398318693, 1e-12, 0.0, "k del vidrio (ν 0,22)")
	assert_near(Fracture.sliding_factor(0.0, 0.22), 1.0, 0.0, 0.0, "sin fricción no cambia")
	# fuera de su validez (μ > 0,5) la fórmula no se extrapola
	assert_eq(Fracture.sliding_factor(0.9, 0.22), Fracture.sliding_factor(0.5, 0.22), "μ se limita a 0,5")
	var prev := 0.0
	for i in 51:
		var f := Fracture.sliding_factor(i / 50.0, 0.22)
		assert_true(f >= prev, "más fricción nunca sube la carga crítica (μ = %s)" % (i / 50.0))
		prev = f


func test_zafiro_cuadrado_agrieta_el_vidrio_al_deslizar() -> void:
	# El caso de la hoja de ruta: una uña maciza de zafiro cuadrada «roza sin marcar» en el 1.x.
	var tip := _square_tip()
	assert_near(tip.R, 1.6925687506432689, 1e-12, 0.0, "radio de la punta cuadrada")
	var vidrio := _target("vidrio")
	var fp: Dictionary = Fracture.props(vidrio)
	var h := Fracture.hertz_threshold(SAPPHIRE.E, SAPPHIRE.hv * Contact.HV_MPA, fp, vidrio.E, tip.R, vidrio.mu, true)
	assert_near(h.freeN, 127.28516345276988, 1e-9, 0.0, "Auerbach apretando")
	assert_near(h.loadN, 0.79112308060361214, 1e-9, 0.0, "deslizando (μ 0,6 → 0,5)")
	assert_near(h.ringUm, 31.205173853394442, 1e-9, 0.0, "radio del anillo al iniciarse")
	assert_true(h.toolElastic, "el zafiro sigue elástico")
	assert_true(h.valid, "R < 5 mm")
	var res := Physics.compute({
		"geom": Data.find_by_id(Data.GEOMS, "cuadrada"), "base": Data.find_by_id(Data.BASES, "zafiro"),
		"inlay": Data.INLAYS[0], "claw": null, "target": vidrio, "type": Data.TYPES[1], "force": 30.0, "length": 25.0,
		"tear": false, "method": "rayado", "strike": false, "passes": 1, "wet": false, "model": "1.x",
	})
	assert_eq(res.verdict, "ROZA SIN MARCAR", "el 1.x no ve grietas")
	var ev: Dictionary = Fracture.evaluate(SAPPHIRE, tip, vidrio, 30.0, true, vidrio.mu, res.depthUm, res.grooveWidthUm / 2.0)
	assert_true(ev.cracks, "la 2.0 sí")
	assert_eq(ev.mode, "hertz", "grietas de Hertz (sin surco)")
	assert_eq(ev.pattern, "herradura", "conos parciales en herradura al deslizar")
	assert_true(ev.crackUm > ev.ringUm, "el cono crece por encima de la carga crítica")
	# apretando sin deslizar hacen falta los 127 N
	var ev_static: Dictionary = Fracture.evaluate(SAPPHIRE, tip, vidrio, 30.0, false, vidrio.mu, 0.0, 0.0)
	assert_false(ev_static.cracks, "30 N apretando no bastan")
	assert_eq(Fracture.evaluate(SAPPHIRE, tip, vidrio, 130.0, false, vidrio.mu, 0.0, 0.0).pattern, "cono", "130 N sí: cono")


func test_pantalla_reforzada_aguanta_mas_que_el_vidrio() -> void:
	var tip := _square_tip()
	var movil := _target("movil")
	var h := Fracture.hertz_threshold(SAPPHIRE.E, SAPPHIRE.hv * Contact.HV_MPA, Fracture.props(movil), movil.E, tip.R, movil.mu, true)
	assert_near(h.staticN, 2015.2572026336279, 1e-9, 0.0, "apretando, con 1000 MPa de compresión")
	assert_near(h.loadN, 13.724452174395308, 1e-9, 0.0, "deslizando")
	var vidrio := _target("vidrio")
	var hv := Fracture.hertz_threshold(SAPPHIRE.E, SAPPHIRE.hv * Contact.HV_MPA, Fracture.props(vidrio), vidrio.E, tip.R, 0.5, true)
	assert_true(h.loadN > 10.0 * hv.loadN, "la compresión superficial multiplica la carga crítica")


func test_otros_pares_de_referencia() -> void:
	var tip := _square_tip()
	var cases := [
		[SAPPHIRE, "zafiro", 1.9548479397171710, 384.05780441179303],
		[DIAMOND, "cuarzo", 1.4844312599885345, 199.62720034670261],
		[DIAMOND, "diamante", 81.082037432582069, 306.36801739641930],
	]
	for c: Array in cases:
		var t := _target(c[1])
		var hs := Fracture.hertz_threshold(c[0].E, c[0].hv * Contact.HV_MPA, Fracture.props(t), t.E, tip.R, t.mu, true)
		var hst := Fracture.hertz_threshold(c[0].E, c[0].hv * Contact.HV_MPA, Fracture.props(t), t.E, tip.R, t.mu, false)
		assert_near(hs.loadN, c[2], 1e-9, 0.0, "%s deslizando" % t.id)
		assert_near(hst.loadN, c[3], 1e-9, 0.0, "%s apretando" % t.id)


func test_umbral_radial_de_lawn_evans() -> void:
	var expect := {
		"vidrio": [0.18, 3.9333132382051059], "movil": [4.5, 18.090609725672753],
		"cuarzo": [0.071111111111111097, 1.7481392169800472], "zafiro": [0.39252787200000000, 3.0459577716660342],
		"diamante": [0.012648271758222222, 0.24452272111430109],
	}
	for id: String in expect:
		var t := _target(id)
		var fp: Dictionary = Fracture.props(t)
		assert_near(Fracture.radial_threshold_n(fp, t.hv), expect[id][0], 1e-12, 0.0, "P* de %s" % id)
		assert_near(Fracture.radial_contact_um(fp, t.hv), expect[id][1], 1e-12, 0.0, "a* de %s" % id)
	# el vidrio de referencia reproduce su umbral medido (Mikowski et al. 2006): 0,18 N
	var vidrio := _target("vidrio")
	var a := Fracture.radial_contact_um(Fracture.props(vidrio), vidrio.hv) / 1000.0
	assert_near(Fracture.VICKERS_K * vidrio.hv * Contact.HV_MPA * a * a, 0.18, 1e-12, 0.0, "huella Vickers en el umbral")


func test_grieta_radial_de_anstis_y_afilado() -> void:
	assert_near(Fracture.radial_crack_um(30.0, 72.0, 550.0, 0.75), 176.16969124776941, 1e-9, 0.0, "Vickers, 30 N")
	var t22 := Contact.tip_geometry(0.15, 22.0)
	assert_near(Fracture.radial_crack_um(30.0, 72.0, 550.0, 0.75, t22.tanA), 394.26603478779873, 1e-9, 0.0, "stiletto")
	assert_near(Fracture.sharpness_factor(Contact.tip_geometry(0.1, 50.0).tanA), 1.6278060154660594, 1e-12, 0.0, "gema de 50°")
	assert_near(Fracture.sharpness_factor(Contact.tip_geometry(0.04, 15.0).tanA), 4.4024252829796238, 1e-12, 0.0, "garra de 15°")
	assert_near(Fracture.sharpness_factor(tan(Fracture.VICKERS_PSI_DEG * Contact.DEG)), 1.0, 1e-12, 0.0, "el Vickers es la referencia")
	var prev := 0.0
	for f: float in [0.5, 1.0, 4.0, 30.0, 300.0, 2000.0]:
		var c := Fracture.radial_crack_um(f, 72.0, 550.0, 0.75)
		assert_true(c > prev, "más fuerza, grieta más larga (%s N)" % f)
		prev = c
	assert_true(Fracture.radial_crack_um(30.0, 72.0, 550.0, 1.5) < Fracture.radial_crack_um(30.0, 72.0, 550.0, 0.75), "más tenaz, grieta más corta")


func test_mas_fuerza_nunca_desagrieta() -> void:
	var forces := [0.5, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0, 60.0, 120.0, 300.0, 1000.0, 2000.0]
	for tool: Dictionary in [SAPPHIRE, DIAMOND]:
		for g: Dictionary in Data.GEOMS:
			var tip := Contact.tip_geometry(g.area, g.alpha)
			for t: Dictionary in Data.TARGETS:
				if Fracture.props(t) == null:
					continue
				for sliding: bool in [true, false]:
					var was := false
					for f: float in forces:
						var ev: Dictionary = Fracture.evaluate(tool, tip, t, f, sliding, t.mu, 0.0, 0.0)
						assert_true(ev.cracks or not was, "%s en %s con %s N (%s)" % [g.id, t.id, f, "rayando" if sliding else "apretando"])
						was = ev.cracks


func test_mas_tenaz_o_mas_comprimido_nunca_se_agrieta_antes() -> void:
	var tip := _square_tip()
	var base := { "Kc": 0.75, "nu": 0.22, "sigmaS": 0.0, "vickersN": null, "quality": "estimate", "source": "prueba" }
	var prev_h := 0.0
	var prev_a := 0.0
	for kc: float in [0.5, 0.75, 1.0, 2.0, 3.4, 5.0]:
		var fp := base.duplicate()
		fp.Kc = kc
		var h := Fracture.hertz_threshold(400.0, 19614.0, fp, 72.0, tip.R, 0.5, true)
		var a := Fracture.radial_contact_um(fp, 550.0)
		assert_true(h.loadN > prev_h, "Hertz: K_c = %s nunca antes" % kc)
		assert_true(a > prev_a, "radial: K_c = %s nunca antes" % kc)
		prev_h = h.loadN
		prev_a = a
	var prev := 0.0
	for s: float in [0.0, 50.0, 100.0, 500.0, 1000.0]:
		var fp := base.duplicate()
		fp.sigmaS = s
		var h := Fracture.hertz_threshold(400.0, 19614.0, fp, 72.0, tip.R, 0.5, false)
		assert_true(h.loadN >= prev, "compresión de %s MPa nunca lo debilita" % s)
		prev = h.loadN


func test_punta_mas_roma_pide_mas_carga_apretando() -> void:
	# Auerbach: la carga crítica crece con el radio de la punta.
	var vidrio := _target("vidrio")
	var prev := 0.0
	for area: float in [0.04, 0.08, 0.15, 0.9, 2.8, 3.5, 9.0]:
		var tip := Contact.tip_geometry(area, 50.0)
		var h := Fracture.hertz_threshold(SAPPHIRE.E, SAPPHIRE.hv * Contact.HV_MPA, Fracture.props(vidrio), vidrio.E, tip.R, 0.0, false)
		assert_true(h.loadN > prev, "área %s mm²" % area)
		prev = h.loadN


func test_una_punta_mas_blanda_nunca_agrieta() -> void:
	# La queratina, el acero o el oro no imponen la presión que agrieta el vidrio: se aplastan antes.
	for tool: Dictionary in [KERATIN, STEEL, { "hv": 30.0, "E": 79.0 }]:
		for g: Dictionary in Data.GEOMS:
			var tip := Contact.tip_geometry(g.area, g.alpha)
			for t: Dictionary in Data.TARGETS:
				if Fracture.props(t) == null:
					continue
				for sliding: bool in [true, false]:
					var ev: Dictionary = Fracture.evaluate(tool, tip, t, 2000.0, sliding, t.mu, 10.0, 500.0)
					assert_false(ev.cracks, "%s HV en %s (%s)" % [tool.hv, t.id, g.id])
	# y una punta dura pero que se aplastaría antes de la carga crítica tampoco: el oro (30 HV) contra un frágil ficticio
	# más blando que él
	var soft := { "id": "prueba", "hv": 20.0, "E": 70.0, "frac": { "Kc": 0.75, "nu": 0.22, "sigmaS": 0.0, "vickersN": 0.18, "quality": "estimate", "source": "prueba" } }
	var h := Fracture.hertz_threshold(79.0, 30.0 * Contact.HV_MPA, soft.frac, 70.0, _square_tip().R, 0.0, false)
	assert_false(h.toolElastic, "el oro plastifica antes de agrietar")
	assert_false(Fracture.evaluate({ "hv": 30.0, "E": 79.0 }, _square_tip(), soft, 2000.0, false, 0.0, 0.0, 0.0).cracks, "sin grietas")


func test_mellado_de_la_punta_informativo() -> void:
	var eagle: Dictionary = Data.find_by_id(Data.CLAWS, "aguila")
	var tip := Contact.tip_geometry(eagle.area, eagle.alpha)
	assert_near(Fracture.tip_chip_load(tip, 760.0, eagle.reach), 8.0934787728633886, 1e-9, 0.0, "talón de zafiro")
	# unidad 4i-B2: una sola resistencia del cuarzo, la de claw_fracture.gd (52,4 MPa, Corning HPFS 7980 con la superficie
	# desgastada); la carga es proporcional a σ_f: con los 67 MPa de antes, 0,7135 N
	assert_eq(float(Fracture.TOOL_STRENGTH.cuarzo.sigmaF), float(ClawFracture.BRITTLE.cuarzo.value), "la misma resistencia en los dos módulos")
	assert_near(Fracture.tip_chip_load(tip, float(Fracture.TOOL_STRENGTH.cuarzo.sigmaF), eagle.reach), 0.71350404971295656 * 52.4 / 67.0, 1e-9, 0.0, "talón de cuarzo")
	var bear: Dictionary = Data.find_by_id(Data.CLAWS, "oso")
	var tip_b := Contact.tip_geometry(bear.area, bear.alpha)
	assert_near(Fracture.tip_chip_load(tip_b, 760.0, bear.reach), 122.12157750789972, 1e-9, 0.0, "garra de oso de zafiro")
	# una punta más roma o más resistente aguanta más
	assert_true(Fracture.tip_chip_load(tip_b, 760.0, bear.reach) > Fracture.tip_chip_load(tip, 760.0, eagle.reach), "más roma, más fuerte")
	assert_true(Fracture.tip_chip_load(tip, 760.0, eagle.reach) > Fracture.tip_chip_load(tip, 67.0, eagle.reach), "zafiro > cuarzo")
	var chip: Dictionary = Fracture.tip_chip("zafiro", tip, eagle.reach, 110.0, 0.5)
	assert_true(chip.chipped, "arrastrando con 110 N la fricción la mella")
	assert_false(Fracture.tip_chip("zafiro", tip, eagle.reach, 110.0, 0.0).chipped, "de frente (sin carga lateral), no")
	assert_eq(Fracture.tip_chip("diamante", tip, eagle.reach, 110.0, 0.5), null, "sin dato del diamante: no se calcula")
