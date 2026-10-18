## Afilado de las garras experimentales (core/lab/claw_sharpness.gd, unidad 4e): los límites son los medidos, más afilado
## nunca da menos presión ni menos hondura con la misma fuerza, una punta frágil más afilada nunca aguanta más carga (la
## carga crece con R²), la fórmula cerrada y el mellado de la unidad 1f (Fracture.tip_chip_load) coinciden, y la
## tenacidad solo marca cuándo el modelo se queda del lado seguro.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Sharp = preload("res://core/lab/claw_sharpness.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
## Resistencias de la unidad 4d (claw_fracture.gd, §11.3 de coche-en-marcha.md), con la forma de ClawFracture.strength().
const DIAMOND := { "value": 2790.0, "min": 1740.0, "max": 3840.0, "kind": "flexion", "kic": 3.4 }
const SAPPHIRE := { "value": 760.0, "min": 760.0, "max": 1035.0, "kind": "flexion", "kic": 2.4 }
const GLASS := { "value": 45.0, "min": 45.0, "max": 45.0, "kind": "flexion", "kic": 0.75 }
## Acero del banco (200 HV): fluye a H/2,8 (Tabor), como en claw_fracture.gd.
const STEEL := { "value": 200.0 * 9.807 / 2.8, "min": 200.0 * 9.807 / 2.8, "max": 200.0 * 9.807 / 2.8, "kind": "fluencia", "kic": null }
## Semiángulos de las garras del banco (13-32°) y uno de más de 30°.
const ALPHAS := [13.0, 15.0, 22.0, 30.0, 32.0]


func test_los_limites_son_los_medidos() -> void:
	assert_eq(Sharp.SHARPEST_UM, 0.04, "hoja de afeitar: 40 nm (Roscioli et al. 2020)")
	assert_eq(Sharp.radius_at(138.2, 0.0), 138.2, "s = 0: la punta de la garra")
	assert_near(Sharp.radius_at(138.2, 1.0), Sharp.SHARPEST_UM, 1e-12, 0.0, "s = 1: la hoja de afeitar")
	assert_eq(Sharp.radius_at(138.2, -1.0), 138.2, "s se acota a [0, 1]")
	assert_near(Sharp.radius_at(138.2, 2.0), Sharp.SHARPEST_UM, 1e-12, 0.0, "s se acota a [0, 1]")
	assert_eq(Sharp.radius_at(0.02, 0.7), 0.02, "una punta ya más fina que el extremo no se afila más")
	var prev := 0.0
	for ref: Dictionary in Sharp.REFERENCES:
		assert_true(String(ref.source).length() > 20 and QUALITIES.has(ref.quality), "%s: fuente y calidad" % ref.id)
		assert_true(float(ref.min) <= float(ref.tipRadiusUm) and float(ref.tipRadiusUm) <= float(ref.max), "%s: banda" % ref.id)
		assert_true(float(ref.tipRadiusUm) >= prev, "%s: ordenadas de la más fina a la más roma" % ref.id)
		assert_true(["filo", "punta"].has(ref.kind), "%s: filo o punta" % ref.id)
		prev = ref.tipRadiusUm
	assert_eq(float(Sharp.REFERENCES[0].tipRadiusUm), Sharp.SHARPEST_UM, "la marca más fina es el extremo del afilado")


func test_el_afilado_es_logaritmico_y_reversible() -> void:
	for s: float in [0.0, 0.1, 0.25, 0.5, 0.8, 1.0]:
		var r := Sharp.radius_at(138.2, s)
		assert_near(Sharp.sharpness_for(138.2, r), s, 1e-9, 1e-12, "sharpness_for invierte radius_at en s = %s" % s)
	# a medio camino, la media geométrica
	assert_near(Sharp.radius_at(100.0, 0.5), sqrt(100.0 * Sharp.SHARPEST_UM), 1e-9, 0.0, "media geométrica")


func test_sharpen_cambia_la_punta_y_no_el_catalogo() -> void:
	var tiger: Dictionary = Data.find_by_id(Data.CLAWS, "tigre")
	var before := tiger.duplicate(true)
	var s := Sharp.sharpen(tiger, 0.5)
	assert_true(same(tiger, before), "Data.CLAWS no cambia")
	assert_true(float(s.area) < float(tiger.area), "área de la punta menor")
	assert_eq(float(s.alpha), float(tiger.alpha), "el semiángulo no cambia")
	assert_near(s.naturalTipRadiusUm, sqrt(0.06 / PI) * 1000.0, 1e-12, 0.0, "radio natural del tigre")
	assert_near(Sharp.radius_um_of_area(s.area), s.tipRadiusUm, 1e-9, 0.0, "área y radio coherentes")
	assert_eq(float(s.sharpness), 0.5, "afilado")
	assert_eq(float(Sharp.sharpen(tiger, 0.0).area), float(tiger.area), "sin afilar, la misma área")


func test_mas_afilado_nunca_da_menos_presion_ni_menos_hondura() -> void:
	# con la misma fuerza: presión de pico elástica, fuerza para empezar a marcar y hondura plástica
	var cases := [
		{ "e_tool": 1050.0, "e_target": 193.0, "h": 200.0 * 9.807, "f": 1.0 },  # diamante contra acero inoxidable
		{ "e_tool": 400.0, "e_target": 72.0, "h": 550.0 * 9.807, "f": 20.0 },  # zafiro contra vidrio
		{ "e_tool": 200.0, "e_target": 3.2, "h": 20.0 * 9.807, "f": 381.5 },  # acero contra la pintura
	]
	for c: Dictionary in cases:
		for alpha: float in ALPHAS:
			var prev_p := 0.0
			var prev_h := 0.0
			var prev_y := INF
			for i in range(0, 21):
				var r := Sharp.radius_at(400.0, float(i) / 20.0)
				var p := Sharp.hertz_peak_mpa(c.f, r, c.e_tool, c.e_target)
				var h := Sharp.plastic_depth_um(r, alpha, c.f, c.h)
				var y := Sharp.yield_onset_n(r, c.e_tool, c.e_target, c.h)
				assert_true(p >= prev_p * (1.0 - 1e-12), "presión de pico (α %s, R %s µm)" % [alpha, r])
				assert_true(h >= prev_h * (1.0 - 1e-12), "hondura plástica (α %s, R %s µm)" % [alpha, r])
				assert_true(y <= prev_y * (1.0 + 1e-12), "fuerza para marcar (α %s, R %s µm)" % [alpha, r])
				prev_p = p
				prev_h = h
				prev_y = y


func test_la_presion_de_hertz_es_la_del_motor() -> void:
	var r := 138.2
	var pf := Contact.plastic_fraction(10.0, r / 1000.0, 1050.0, 193.0, 2000.0)
	assert_near(Sharp.hertz_peak_mpa(10.0, r, 1050.0, 193.0), pf.p0, 1e-12, 0.0, "Contact.plastic_fraction")
	# (R0/R)^(2/3) con la misma fuerza
	var p1 := Sharp.hertz_peak_mpa(10.0, r, 1050.0, 193.0)
	var p2 := Sharp.hertz_peak_mpa(10.0, 1.0, 1050.0, 193.0)
	assert_near(p2 / p1, Sharp.pressure_gain(r, 1.0), 1e-9, 0.0, "ganancia de presión")
	# en la carga de cesión, p0 = 1,6·H/2,8
	var y := Sharp.yield_onset_n(r, 1050.0, 193.0, 2000.0)
	assert_near(Sharp.hertz_peak_mpa(y, r, 1050.0, 193.0), 1.6 * 2000.0 / 2.8, 1e-9, 0.0, "p0 = 1,6·Y")


func test_una_punta_fragil_mas_afilada_nunca_aguanta_mas_carga() -> void:
	for alpha: float in ALPHAS:
		for x0: float in [0.0, 0.005, 0.05]:
			var prev := INF
			for i in range(0, 41):
				var r := Sharp.radius_at(400.0, float(i) / 40.0)
				var f := Sharp.chip_load_n(Sharp.tip_of(r, alpha), DIAMOND.value, x0)
				assert_true(f <= prev * (1.0 + 1e-12), "α %s, x0 %s mm, R %s µm: %s N ≤ %s N" % [alpha, x0, r, f, prev])
				prev = f


func test_la_carga_que_aguanta_crece_con_el_cuadrado_del_radio() -> void:
	for alpha: float in ALPHAS:
		var f1 := Sharp.chip_load_n(Sharp.tip_of(10.0, alpha), 760.0)
		var f2 := Sharp.chip_load_n(Sharp.tip_of(20.0, alpha), 760.0)
		assert_near(f2 / f1, 4.0, 1e-9, 0.0, "α %s: el doble de radio aguanta el cuádruple" % alpha)


func test_la_formula_cerrada() -> void:
	for alpha: float in [13.0, 15.0, 22.0, 30.0]:
		for r: float in [0.04, 1.0, 138.2]:
			assert_near(Sharp.chip_load_n(Sharp.tip_of(r, alpha), 760.0), Sharp.chip_load_closed_n(r, alpha, 760.0), 1e-9, 0.0,
				"α %s, R %s µm" % [alpha, r])


func test_coincide_con_el_mellado_de_la_unidad_1f() -> void:
	# Fracture.tip_chip_load busca el máximo con 400 muestras desde h_t hasta el alcance; aquí se calcula exacto
	for alpha: float in [13.0, 15.0, 22.0]:
		for r: float in [1.0, 50.0, 138.2]:
			var tip := Sharp.tip_of(r, alpha)
			var sampled := Fracture.tip_chip_load(tip, 760.0, 40.0)
			var exact := Sharp.chip_load_n(tip, 760.0)
			assert_true(exact <= sampled * (1.0 + 1e-12), "el máximo exacto nunca queda por encima del muestreado")
			assert_near(sampled, exact, 2e-3, 0.0, "α %s, R %s µm" % [alpha, r])


func test_la_resistencia_es_la_de_claw_fracture() -> void:
	for inlay: Dictionary in Data.INLAYS:
		assert_true(same(Sharp.strength_of(inlay), ClawFracture.strength(inlay)), "%s: ClawFracture.strength" % inlay.id)
	assert_eq(Sharp.strength_of("none"), null, "queratina: sin resistencia de mellado")
	assert_eq(Sharp.strength_of("hematites"), null, "hematites: sin datos (pregunta abierta de la 4d)")
	# las constantes de estos tests son las de la 4d
	var pairs := { "diamante": DIAMOND, "zafiro": SAPPHIRE, "vidrio": GLASS, "acero": STEEL }
	for id: String in pairs:
		var s: Dictionary = ClawFracture.strength(id)
		var mine: Dictionary = pairs[id]
		for key: String in ["value", "min", "max"]:
			assert_near(float(mine[key]), float(s[key]), 1e-12, 0.0, "%s.%s" % [id, key])
		assert_eq(mine.kind, s.kind, "%s: kind" % id)
		assert_eq(mine.kic, s.kic, "%s: kic" % id)
	var tip := Sharp.tip_of(5.0, 15.0)
	var direct := Sharp.evaluate(tip, ClawFracture.strength("zafiro"), 0.01)
	assert_true(same(Sharp.evaluate_inlay(tip, "zafiro", 0.01), direct), "evaluate_inlay")
	assert_eq(direct.chipN, Sharp.evaluate(tip, SAPPHIRE, 0.01).chipN, "la misma carga que con los valores de la 4d")
	assert_eq(Sharp.evaluate_inlay(tip, "none", 0.01).mode, "sin_datos", "la queratina no se evalúa aquí")


func test_coincide_con_claw_fracture() -> void:
	# la viga de la 4d (con la base lejos) da la misma carga que la de aquí cuando el máximo cae en el cono
	for alpha: float in [13.0, 15.0, 22.0, 30.0]:
		for r: float in [1.0, 50.0, 138.2]:
			for x0: float in [0.0, 0.005]:
				var tip := Sharp.tip_of(r, alpha)
				assert_near(ClawFracture.lateral_limit_n(tip, 1000.0, 760.0, x0), Sharp.chip_load_n(tip, 760.0, x0), 1e-12, 0.0,
					"α %s, R %s µm, x0 %s mm" % [alpha, r, x0])


func test_la_punta_mas_fina_que_aguanta() -> void:
	for alpha: float in ALPHAS:
		for lateral: float in [0.01, 1.0, 10.0]:
			var r := Sharp.sharpest_surviving_um(alpha, 760.0, lateral)
			var f := Sharp.chip_load_n(Sharp.tip_of(r, alpha), 760.0)
			assert_near(f, lateral, 1e-9, 0.0, "α %s: la punta de %s µm aguanta justo %s N" % [alpha, r, lateral])
	assert_eq(Sharp.sharpest_surviving_um(15.0, 760.0, 0.0), 0.0, "sin carga lateral, cualquier punta aguanta")


func test_fragil_se_mella_ductil_se_dobla() -> void:
	var tip := Sharp.tip_of(20.0, 15.0)
	var chip := Sharp.chip_load_n(tip, SAPPHIRE.value)
	var brittle := Sharp.evaluate(tip, SAPPHIRE, 2.0 * chip)
	assert_eq(brittle.mode, "mella", "zafiro por encima de su carga: se mella")
	assert_true(brittle.breaks and not brittle.bends, "frágil: breaks")
	assert_near(brittle.chipN, chip, 1e-12, 0.0, "chipN")
	var ok := Sharp.evaluate(tip, SAPPHIRE, 0.5 * chip)
	assert_eq(ok.mode, "intacta", "por debajo: intacta")
	var steel := Sharp.evaluate(tip, STEEL, 2.0 * Sharp.chip_load_n(tip, STEEL.value))
	assert_eq(steel.mode, "dobla", "acero: se dobla")
	assert_true(steel.bends and not steel.breaks, "dúctil: bends")
	assert_eq(steel.criticalUm, null, "sin tenacidad en los dúctiles")
	var none := Sharp.evaluate(tip, null, 5.0)
	assert_eq(none.mode, "sin_datos", "sin resistencia medida: no se predice")
	assert_eq(none.chipN, null, "sin carga de mellado")
	# la banda: con la resistencia mínima falla antes que con la máxima
	var mid := Sharp.evaluate(tip, SAPPHIRE, 0.5 * (chip + Sharp.chip_load_n(tip, SAPPHIRE.max)))
	assert_true(mid.failsLo and not mid.failsHi, "entre las dos cargas: falla solo con la resistencia mínima")


func test_de_frente_no_hay_carga_lateral() -> void:
	var t := Sharp.tradeoff(138.2, 15.0, 1.0, 1050.0, DIAMOND, 381.5, 0.0, 193.0, 200.0 * 9.807)
	assert_eq(t.lateralN, 0.0, "μ = 0: sin carga lateral")
	assert_true(t.survives, "de frente, ni la punta más fina se mella (unidad 4d)")


func test_la_tenacidad_marca_el_efecto_de_escala() -> void:
	assert_near(Sharp.critical_distance_um(3.4, 2790.0), 0.4727, 1e-3, 0.0, "diamante: ~0,5 µm")
	assert_near(Sharp.critical_distance_um(0.75, 45.0), 88.42, 1e-3, 0.0, "vidrio: ~88 µm")
	assert_eq(Sharp.critical_distance_um(null, 700.0), null, "sin tenacidad")
	var d := Sharp.evaluate(Sharp.tip_of(1.0, 15.0), DIAMOND, 1e-6)
	assert_false(d.sizeEffect, "diamante a 1 µm: la punta es mayor que sus defectos, σ_f manda")
	var g := Sharp.evaluate(Sharp.tip_of(1.0, 15.0), GLASS, 1e-6)
	assert_true(g.sizeEffect, "vidrio a 1 µm: la punta es menor que su defecto, el modelo es del lado seguro")
	var g2 := Sharp.evaluate(Sharp.tip_of(1000.0, 15.0), GLASS, 1e-6)
	assert_false(g2.sizeEffect, "vidrio con punta de 1 mm: σ_f manda")


func test_el_compromiso_completo() -> void:
	# garra de diamante del velocirraptor apretando el acero con el agarre de un pie y μ = 0,1
	var nat := Sharp.tradeoff(138.2, 15.0, 0.0, 1050.0, DIAMOND, 381.5, 0.1, 193.0, 200.0 * 9.807)
	var sharp := Sharp.tradeoff(138.2, 15.0, 0.5, 1050.0, DIAMOND, 381.5, 0.1, 193.0, 200.0 * 9.807)
	assert_near(nat.pressureGain, 1.0, 1e-12, 0.0, "sin afilar, la misma presión")
	assert_true(sharp.pressureGain > 1.0 and sharp.p0MPa > nat.p0MPa, "afilada: más presión")
	assert_true(sharp.depthUm >= nat.depthUm, "afilada: al menos igual de honda")
	assert_true(float(sharp.chipN) < float(nat.chipN), "afilada: aguanta menos de lado")
	assert_near(sharp.chipNaturalN, nat.chipN, 1e-12, 0.0, "la natural de referencia")
	assert_near(sharp.lateralN, 38.15, 1e-9, 0.0, "μ·F")
	assert_eq(sharp.survives, not bool(sharp.fracture.fails), "survives")
