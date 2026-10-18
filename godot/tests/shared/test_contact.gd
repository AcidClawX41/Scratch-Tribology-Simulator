## Capa física compartida (contact.gd y abrasion.gd) contra el motor 1.x (tests/fixtures/shared.json).
extends "res://tests/case.gd"

const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")

var fx: Dictionary
## Las mismas resistencias de prueba que export-fixtures.mjs (RES)
var res := {
	"suave": func(h: float) -> float: return 1500.0 * h * h,
	"capas": func(h: float) -> float: return 2000.0 * h if h < 0.3 else 400.0 * (h - 0.3) + 50.0,
	"pared": func(h: float) -> float: return 800.0 * h if h < 0.2 else INF,
}


func before_each() -> void:
	if fx.is_empty():
		fx = load_json("res://tests/fixtures/shared.json")


func test_constantes_iguales_que_model() -> void:
	assert_eq(Contact.HV_MPA, fx["HV_MPA"])
	for k in fx["MODEL_CONTACT"]:
		assert_eq(Contact.CONTACT[k], fx["MODEL_CONTACT"][k], "MODEL.%s" % k)


func test_geometria_de_la_punta_y_contacto() -> void:
	var hs: Array = fx["hs"]
	for t in fx["tips"]:
		var tip := Contact.tip_geometry(t["area"], t["alpha"], t["amax"])
		for k in ["R", "tanA", "at", "ht"]:
			assert_near(tip[k], t["tip"][k], 1e-15, 0.0, "tip.%s (área %s, α %s)" % [k, t["area"], t["alpha"]])
		for i in hs.size():
			assert_near(Contact.contact_radius(tip, hs[i]), t["contact"][i], 1e-14, 1e-300, "contactRadius")
			assert_near(Contact.hole_radius(tip, hs[i]), t["hole"][i], 1e-14, 1e-300, "holeRadius")
			assert_near(Contact.depth_for_radius(tip, hs[i]), t["depth"][i], 1e-14, 1e-300, "depthForRadius")


func test_eficiencia_por_ratio_de_dureza() -> void:
	for row in fx["hardness"]:
		assert_eq(Contact.hardness_efficiency(row[0]), row[1], "hardnessEfficiency(%s)" % row[0])


func test_fraccion_plastica_de_hertz() -> void:
	for row in fx["plastic"]:
		var got := Contact.plastic_fraction(row[0], row[1], row[2], row[3], row[4], row[5])
		for k in ["phi", "p0", "aH"]:
			assert_near(got[k], row[6][k], 1e-14, 1e-300, "plasticFraction.%s F=%s R=%s" % [k, row[0], row[1]])


func test_solvers_estatico_por_capas_y_por_energia() -> void:
	for row in fx["solve"]:
		var r: Callable = res[row["name"]]
		var F: float = row["F"]
		assert_near(Contact.solve_static(F, r), row["static"], 1e-12, 1e-300, "solveStatic %s F=%s" % [row["name"], F])
		assert_near(Contact.solve_layered(F, r, [0.3]), row["layered"], 1e-12, 1e-300, "solveLayered %s F=%s" % [row["name"], F])
		var Es := [0.0, 1.0, 10.0, 100.0, 1e4]
		for i in Es.size():
			assert_near(Contact.solve_energy(Es[i], F, r), row["energy"][i], 1e-9, 1e-300, "solveEnergy %s F=%s E=%s" % [row["name"], F, Es[i]])


func test_modo_de_abrasion_identico_al_bit() -> void:
	var bad := 0
	for row in fx["abrasion"]:
		var got := Abrasion.abrasion_mode(row[0])
		var want: Dictionary = row[1]
		if got["absMode"] != want["absMode"] or got["fab"] != want["fab"] or got["muPlough"] != want["muPlough"]:
			bad += 1
			if bad <= 5:
				fail("Dp=%s: %s ≠ %s" % [row[0], got, want])
	assert_eq(bad, 0, "valores de Dp con otro modo o fracción")


func test_archard() -> void:
	assert_eq(Abrasion.archard_wear(10.0, 100.0, 1000.0, 1e-3), 1e-3 * 10.0 * 100.0 / 1000.0)
	assert_true(Abrasion.archard_wear(20.0, 100.0, 1000.0, 1e-3) > Abrasion.archard_wear(10.0, 100.0, 1000.0, 1e-3), "más carga, más desgaste")
	assert_true(Abrasion.archard_wear(10.0, 100.0, 2000.0, 1e-3) < Abrasion.archard_wear(10.0, 100.0, 1000.0, 1e-3), "más dureza, menos desgaste")
	assert_eq(Abrasion.archard_wear(10.0, 100.0, 0.0, 1e-3), 0.0)
