## Abolladura de la chapa (core/lab/dent.gd, unidad 1f): la calibración con las abolladuras medidas por Nippon Steel
## (2013, fig. 6), la coherencia fuerza-energía del mecanismo y las invariantes («más energía, más honda», «más
## gruesa o más resistente, menos honda», «por debajo del colapso no abolla»).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Dent = preload("res://core/lab/dent.gd")


func test_calibracion_con_nippon_steel() -> void:
	# Bola de 25 mm, 200 N, chapa de 0,7 mm estirada un 2 % y horneada (fig. 6). Lecturas de la figura: 270D
	# (~205 MPa → ~0,20 mm), 340H (~245 → ~0,115), BH (~270 → ~0,09), 440P (~300 → ~0,06).
	assert_near(Dent.depth_for_load(270.0, 0.7, 200.0), 0.089733496599929186, 1e-9, 0.0, "BH: el punto de calibración")
	assert_true(absf(Dent.depth_for_load(270.0, 0.7, 200.0) - 0.09) < 0.005, "BH ≈ 0,09 mm")
	var readings := [[205.0, 0.20], [245.0, 0.115], [300.0, 0.06]]
	for r: Array in readings:
		var d := Dent.depth_for_load(r[0], 0.7, 200.0)
		assert_true(absf(d - r[1]) / r[1] < 0.35, "%s MPa: %s mm (medido ~%s)" % [r[0], d, r[1]])
	# y el orden de la figura: más límite elástico, menos abolladura
	assert_true(Dent.depth_for_load(205.0, 0.7, 200.0) > Dent.depth_for_load(245.0, 0.7, 200.0), "270D > 340H")
	assert_true(Dent.depth_for_load(245.0, 0.7, 200.0) > Dent.depth_for_load(300.0, 0.7, 200.0), "340H > 440P")


func test_cargas_de_colapso_del_banco() -> void:
	var expect := { "coche": 155.64983103098785, "cocheclasico": 208.56788582955659, "cochealu": 253.88152711455194, "puertametal": 425.04099266926772 }
	for id: String in expect:
		var p: Dictionary = Dent.panel_of(Data.find_by_id(Data.TARGETS, id))
		assert_near(Dent.collapse_load(p.sigma, p.t), expect[id], 1e-12, 0.0, id)
	assert_eq(Dent.panel_of(Data.find_by_id(Data.TARGETS, "cocheplastico")), null, "el plástico no se abolla en el modelo")
	assert_eq(Dent.panel_of(Data.find_by_id(Data.TARGETS, "vidrio")), null, "el vidrio no es chapa")


func test_coherencia_fuerza_energia() -> void:
	for d: float in [0.0, 0.1, 0.5, 2.0, 10.0]:
		var h := 1e-6
		var dw := (Dent.energy_mj(264.0, 0.7, d + h) - Dent.energy_mj(264.0, 0.7, maxf(d - h, 0.0))) / (d + h - maxf(d - h, 0.0))
		assert_near(dw, Dent.load_at(264.0, 0.7, d), 1e-5, 1e-6, "F = dW/dδ con δ = %s (diferencia finita)" % d)
		assert_near(Dent.depth_for_energy(264.0, 0.7, Dent.energy_mj(264.0, 0.7, d)), d, 1e-9, 1e-12, "inversa de la energía")
		if d > 0.0:
			assert_near(Dent.depth_for_load(264.0, 0.7, Dent.load_at(264.0, 0.7, d)), d, 1e-9, 1e-12, "inversa de la fuerza")


func test_zarpazo_de_oso() -> void:
	var k: float = Physics.MODEL.limbStiffness
	var e := (98.0 - 0.0071807111095520118) * 1000.0  # energía del golpe menos la que se queda la punta (1.x)
	var s: Dictionary = Dent.strike(264.0, 0.7, e, k)
	assert_near(s.depthMm, 2.7636020323474226, 1e-9, 0.0, "coche moderno")
	assert_near(s.panelJ * 1000.0 + s.limbJ * 1000.0, e, 1e-6, 0.0, "la energía se reparte entre chapa y pata")
	assert_near(Dent.strike(211.0, 1.0, e, k).depthMm, 2.2312197755501857, 1e-9, 0.0, "aluminio")
	assert_near(Dent.strike(214.0, 0.9, e, k).depthMm, 2.5391374444320158, 1e-9, 0.0, "clásico")
	# el gato (1,2 J) se queda por debajo del colapso
	assert_eq(Dent.strike(264.0, 0.7, 1200.0, k).depthMm, 0.0, "el gato no abolla")
	# si la herramienta se rompe antes, no transmite más fuerza
	var capped: Dictionary = Dent.strike(264.0, 0.7, e, k, 500.0)
	assert_near(capped.peakN, 500.0, 1e-9, 0.0, "fuerza limitada")
	assert_true(capped.depthMm < s.depthMm, "abolladura menor")


func test_evaluate_para_compute() -> void:
	var coche: Dictionary = Data.find_by_id(Data.TARGETS, "coche")
	var push: Dictionary = Dent.evaluate(coche, 900.0, false, 0.0, 10.0, false)
	assert_near(push.depthMm, 1.6737734786701282, 1e-9, 0.0, "900 N empujando o rayando")
	assert_true(push.visible, "se ve")
	assert_false(Dent.evaluate(coche, 100.0, false, 0.0, 10.0, false).visible, "100 N no abollan")
	assert_eq(Dent.evaluate(coche, 900.0, false, 0.0, 10.0, true), null, "perforada: no hay abolladura que contar")
	assert_eq(Dent.evaluate(Data.find_by_id(Data.TARGETS, "cocheplastico"), 900.0, false, 0.0, 10.0, false), null, "plástico")


func test_invariantes() -> void:
	var prev := -1.0
	for w: float in [0.0, 100.0, 1000.0, 5000.0, 20000.0, 100000.0, 500000.0]:
		var d: float = Dent.strike(264.0, 0.7, w, 10.0).depthMm
		assert_true(d >= prev, "más energía, más honda (%s mJ)" % w)
		prev = d
	var e := 98000.0
	assert_true(Dent.strike(264.0, 1.0, e, 10.0).depthMm < Dent.strike(264.0, 0.7, e, 10.0).depthMm, "más gruesa, menos")
	assert_true(Dent.strike(400.0, 0.7, e, 10.0).depthMm < Dent.strike(264.0, 0.7, e, 10.0).depthMm, "más resistente, menos")
	assert_eq(Dent.depth_for_load(264.0, 0.7, Dent.collapse_load(264.0, 0.7) * 0.99), 0.0, "por debajo del colapso, nada")
	prev = -1.0
	for f: float in [0.0, 100.0, 156.0, 200.0, 500.0, 2000.0]:
		var d := Dent.depth_for_load(264.0, 0.7, f)
		assert_true(d >= prev, "más fuerza, más honda (%s N)" % f)
		prev = d
