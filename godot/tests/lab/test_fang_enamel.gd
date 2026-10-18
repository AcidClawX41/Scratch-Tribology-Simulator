## Esmalte en la punta de los colmillos (core/lab/fang_enamel.gd, modelo 2.0).
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")


static func tool_of(claw_id: String, inlay_id := "none") -> Dictionary:
	return Physics.resolve_tool({
		"geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": Data.find_by_id(Data.INLAYS, inlay_id),
		"claw": Data.find_by_id(Data.CLAWS, claw_id), "wet": false,
	})


func test_datos_con_fuente() -> void:
	var e := FangEnamel.ENAMEL
	assert_near(e.hv * Contact.HV_MPA, 3150.0, 2e-4, 0.0, "Enax 2013: esmalte de 3,15 GPa")
	assert_true(e.hv > 5.0 * tool_of("vibora").hv, "el esmalte es >5 veces más duro que la dentina")
	assert_eq(e.quality, "secondary")
	assert_eq(e.thicknessQuality, "estimate")
	assert_true(String(e.source).contains("doi:10.1016/j.jsb.2013.09.018") and String(e.source).contains("doi:10.1016/j.actbio.2026.07.058"))


func test_solo_los_colmillos_naturales() -> void:
	assert_true(FangEnamel.applies(tool_of("vibora")) and FangEnamel.applies(tool_of("gabon")))
	for id in ["gato", "aguila", "casuario"]:
		assert_false(FangEnamel.applies(tool_of(id)), "%s es queratina" % id)
		assert_eq(FangEnamel.tip_hv(tool_of(id), 0.0), tool_of(id).hv)
	var steel := tool_of("vibora", "acero")
	assert_false(FangEnamel.applies(steel), "un colmillo reforjado es entero de su material")
	assert_eq(FangEnamel.tip_hv(steel, 0.0), 200.0)


## Esmalte en la puntita, dentina en cuanto el contacto crece: la dureza baja de forma continua con el radio de contacto.
func test_casquete_sobre_dentina() -> void:
	var v := tool_of("vibora")
	assert_eq(FangEnamel.tip_hv(v, 0.0), FangEnamel.ENAMEL.hv)
	var prev := INF
	for a in [0.0, 0.001, 0.005, 0.01, 0.02, 0.05, 0.1, 1.0]:
		var hv := FangEnamel.tip_hv(v, a)
		assert_true(hv <= prev and hv >= v.hv, "a = %s mm" % a)
		prev = hv
	assert_near(FangEnamel.tip_hv(v, 1.0), v.hv, 1e-12, 1e-9, "con 1 mm de contacto, dentina")
	assert_near(FangEnamel.tip_hardness_mpa(v, 0.0), FangEnamel.ENAMEL.hv * Contact.HV_MPA, 1e-12)


## El esmalte de la punta raya lo que la dentina no puede: el cobre de una moneda y el acero inoxidable, no el vidrio.
func test_el_esmalte_cambia_quien_raya_a_quien() -> void:
	var v := tool_of("vibora")
	var t := func(id: String) -> float: return Data.find_by_id(Data.TARGETS, id).hv
	assert_true(v.hv / t.call("cobre") < 0.8, "la dentina sola cede ante el cobre")
	assert_true(FangEnamel.surface_ratio(v, t.call("cobre")) > 2.0, "el esmalte le gana al cobre")
	assert_true(FangEnamel.surface_ratio(v, t.call("acero")) > 1.25, "y marca el acero inoxidable")
	assert_true(FangEnamel.surface_ratio(v, t.call("vidrio")) < 0.8, "pero no el vidrio")
	# hasta qué contacto conserva r ≥ 0,8: el radio que resuelve tip_hv(a)/HV = 0,8
	var a := FangEnamel.contact_radius_for_ratio(v, t.call("cobre"), 0.8)
	assert_true(a > 0.0 and a < 0.05)
	assert_near(FangEnamel.tip_hv(v, a) / t.call("cobre"), 0.8, 1e-9)
	assert_eq(FangEnamel.contact_radius_for_ratio(v, t.call("vidrio"), 0.8), 0.0, "contra el vidrio, ni con esmalte")
	assert_eq(FangEnamel.contact_radius_for_ratio(v, t.call("madera"), 0.8), INF, "la madera la raya hasta la dentina")


## La eficiencia de la punta en un sólido: la de la 1.x para todo lo que no sea un colmillo natural; en los colmillos,
## decreciente con el contacto y nula en cuanto el contacto sale del esmalte (r = 0,8), así la resistencia se hace
## infinita allí y la profundidad nunca salta.
func test_eficiencia_en_un_solido() -> void:
	for id in ["gato", "aguila", "casuario"]:
		var k := tool_of(id)
		for target_id in ["cobre", "madera", "plastico"]:
			var h: float = Data.find_by_id(Data.TARGETS, target_id).hv * Contact.HV_MPA
			for a in [0.0, 0.01, 0.1]:
				assert_eq(FangEnamel.efficiency(k, a, h), Contact.hardness_efficiency(k.hv * Contact.HV_MPA / h),
					"%s contra %s: la 1.x" % [id, target_id])
	var v := tool_of("vibora")
	var copper: float = Data.find_by_id(Data.TARGETS, "cobre").hv
	var h_cu := copper * Contact.HV_MPA
	var a_off := FangEnamel.contact_radius_for_ratio(v, copper, 0.8)
	var prev := INF
	for k in 60:
		var a := a_off * 1.5 * float(k) / 59.0
		var eta := FangEnamel.efficiency(v, a, h_cu)
		assert_true(eta <= prev and eta >= 0.0, "a = %s mm" % a)
		prev = eta
	assert_eq(FangEnamel.efficiency(v, 0.0, h_cu), 1.0, "la puntita de esmalte es rígida frente al cobre (r = 3,6)")
	assert_eq(FangEnamel.efficiency(v, a_off * 1.001, h_cu), 0.0, "fuera del esmalte, la dentina cede")
