## Recuperación elástica (core/lab/recovery.gd, unidad 1f): la profundidad residual tras descargar (Oliver & Pharr
## 1992), sus casos con el motor de siempre y las invariantes («nunca más honda que bajo carga», «un polímero recupera
## más que un metal», «una punta roma recupera más que una afilada»).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Recovery = preload("res://core/lab/recovery.gd")


func _run(geom: String, base: String, claw: Variant, target: String, force: float, passes: int = 1) -> Dictionary:
	var t: Dictionary = Data.find_by_id(Data.TARGETS, target)
	var res := Physics.compute({
		"geom": Data.find_by_id(Data.GEOMS, geom), "base": Data.find_by_id(Data.BASES, base), "inlay": Data.INLAYS[0],
		"claw": Data.find_by_id(Data.CLAWS, claw) if claw != null else null, "target": t, "type": Data.TYPES[1],
		"force": force, "length": 25.0, "tear": false, "method": "rayado", "strike": false, "passes": passes, "wet": false,
		"model": "1.x",
	})
	return { "res": res, "target": t, "rec": Recovery.evaluate(t, res.depthUm, res.grooveWidthUm / 2.0, res.through) }


func test_formula_de_oliver_pharr() -> void:
	assert_near(Recovery.plane_strain_modulus(3.2), 3200.0 / 0.91, 1e-15, 0.0, "E' del barniz")
	# 1,5·π·a·H/(2E'): 64,09 µm de contacto en el barniz (20 HV, 3,2 GPa)
	assert_near(Recovery.recovered_um(64.093645707391701, 20.0 * Contact.HV_MPA, 3.2), 8.4233276935230776, 1e-9, 0.0, "barniz")
	assert_eq(Recovery.recovered_um(0.0, 196.0, 3.2), 0.0, "sin contacto no hay nada que recuperar")
	assert_eq(Recovery.residual_um(3.0, 64.0, 196.0, 3.2), 0.0, "un contacto casi elástico no deja huella")


func test_casos_del_golden() -> void:
	# «uña almendra 4N sobre pintura»: 3,49 µm bajo carga, se recupera entero
	var g1 := _run("almendra", "natural", null, "coche", 4.0)
	assert_near(g1.res.depthUm, 3.4857664928608507, 1e-9, 0.0, "profundidad bajo carga (1.x)")
	assert_eq(g1.rec.residualDepthUm, 0.0, "no queda surco")
	assert_near(g1.rec.fraction, 1.0, 1e-12, 0.0, "recupera el 100 %")
	# «uña almendra 20 pasadas sobre pintura»: 11,6 µm bajo carga, ~3,1 µm después
	var g21 := _run("almendra", "natural", null, "coche", 4.0, 20)
	assert_near(g21.rec.residualDepthUm, 3.1300850622486838, 1e-9, 0.0, "surco residual")
	# garra de gato en ABS: afilada, recupera poco
	var abs_cat := _run("almendra", "natural", "gato", "plastico", 15.0)
	assert_near(abs_cat.rec.residualDepthUm, 648.29046887872005, 1e-9, 0.0, "ABS")
	assert_true(abs_cat.rec.fraction < 0.1, "una garra afilada recupera menos del 10 %")
	# acero: casi nada
	var steel := _run("stiletto", "zafiro", null, "acero", 30.0)
	assert_near(steel.rec.residualDepthUm, 21.399870388865711, 1e-9, 0.0, "acero")


func test_capa_del_fondo() -> void:
	var coche: Dictionary = Data.find_by_id(Data.TARGETS, "coche")
	assert_eq(Recovery.layer_at(coche, 50.0).hv, 20.0, "en la pintura manda la pintura")
	assert_eq(Recovery.layer_at(coche, 110.0).hv, 101.0, "en la interfaz ya es la chapa (la pintura está cortada)")
	assert_eq(Recovery.layer_at(Data.find_by_id(Data.TARGETS, "vidrio"), 5.0).hv, 550.0, "un sólido homogéneo")
	# la garra de gato corta los 110 µm de pintura y llega al metal: lo cortado no vuelve, el metal queda al aire
	var claw := _run("almendra", "natural", "gato", "coche", 15.0)
	assert_eq(claw.res.verdict, "HASTA EL METAL", "1.x")
	assert_near(claw.rec.residualDepthUm, 110.0, 1e-9, 0.0, "el fondo no sube por encima de la chapa")
	# y dentro de la chapa solo recupera la chapa
	var deep: Dictionary = Recovery.evaluate(coche, 400.0, 150.0, false)
	assert_true(deep.residualDepthUm >= 110.0 and deep.residualDepthUm < 400.0, "surco en la chapa")
	assert_true(deep.recoveredUm < 5.0, "el acero apenas recupera")


func test_donde_no_se_aplica() -> void:
	for id: String in ["piel", "madera", "puertamadera"]:
		var t: Dictionary = Data.find_by_id(Data.TARGETS, id)
		assert_false(Recovery.applies(t), id)
		assert_eq(Recovery.evaluate(t, 100.0, 50.0, false), null, "%s: null" % id)
	assert_eq(Recovery.evaluate(Data.find_by_id(Data.TARGETS, "coche"), 810.0, 300.0, true), null, "perforada: el agujero no se cierra")


func test_invariantes() -> void:
	var targets: Array = []
	for t: Dictionary in Data.TARGETS:
		if Recovery.applies(t):
			targets.append(t)
	for t: Dictionary in targets:
		for depth: float in [0.0, 0.5, 3.0, 20.0, 200.0, 2000.0]:
			for a: float in [0.0, 1.0, 10.0, 100.0, 1000.0]:
				var r: Dictionary = Recovery.evaluate(t, depth, a, false)
				assert_true(r.residualDepthUm >= 0.0 and r.residualDepthUm <= depth, "%s: 0 ≤ residual ≤ bajo carga" % t.id)
	# a igual contacto, un polímero recupera más que un metal y que un vidrio duro-rígido no (H/E' manda)
	var abs_t: Dictionary = Data.find_by_id(Data.TARGETS, "plastico")
	var steel: Dictionary = Data.find_by_id(Data.TARGETS, "acero")
	var cu: Dictionary = Data.find_by_id(Data.TARGETS, "cobre")
	var r_abs := Recovery.recovered_um(50.0, abs_t.hv * Contact.HV_MPA, abs_t.E)
	var r_steel := Recovery.recovered_um(50.0, steel.hv * Contact.HV_MPA, steel.E)
	var r_cu := Recovery.recovered_um(50.0, cu.hv * Contact.HV_MPA, cu.E)
	assert_true(r_abs > r_steel and r_abs > r_cu, "el ABS recupera más que los metales")
	# a igual profundidad, la punta roma (más contacto) recupera más: más fuerza de contacto que devolver
	assert_true(Recovery.residual_um(10.0, 80.0, 196.0, 3.2) < Recovery.residual_um(10.0, 20.0, 196.0, 3.2), "roma < afilada")
