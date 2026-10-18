## Ángulo de ataque explícito (core/lab/attack.gd, modelo 2.0): por defecto es la 1.x al bit; la esfera no cambia al
## inclinarla; clavar nunca ara más que arrastrar.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Attack = preload("res://core/lab/attack.gd")


## Unidad 4b: el modelo va explícito (la 1.x). Desde la integración, el 2.0 por defecto ya lleva el ángulo de cada
## herramienta (45° en las uñas), y estos tests comparan attack.gd con el rayado de la 1.x, de frente.
static func _p(over: Dictionary) -> Dictionary:
	var p := {
		"geom": Data.find_by_id(Data.GEOMS, "almendra"), "base": Data.BASES[0], "inlay": Data.INLAYS[0],
		"target": Data.find_by_id(Data.TARGETS, "coche"), "force": 4.0, "length": 25.0, "type": Data.TYPES[1],
		"claw": null, "tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false, "model": "1.x",
	}
	p.merge(over, true)
	return p


## Un rayado de la 1.x con lo que attack.gd necesita: { r (resultado), tip, alpha, m }.
static func scratch(over: Dictionary) -> Dictionary:
	var p := _p(over)
	var r := Physics.compute(p)
	var tool := Physics.resolve_tool(p)
	var m: float = r.phi * float(p.type.k) * Physics.pass_depth_factor(p.passes)
	return { "r": r, "tip": Contact.tip_geometry(tool.area, tool.alpha, tool.baseR), "alpha": tool.alpha, "m": m }


static func cases() -> Array:
	var out: Array = []
	for over in [
		{ "force": 4.0 }, { "force": 30.0 }, { "geom": Data.find_by_id(Data.GEOMS, "stiletto"), "force": 30.0, "target": Data.find_by_id(Data.TARGETS, "madera") },
		{ "geom": Data.find_by_id(Data.GEOMS, "cuadrada"), "force": 30.0, "target": Data.find_by_id(Data.TARGETS, "madera") },
		{ "claw": Data.find_by_id(Data.CLAWS, "gato"), "force": 15.0 }, { "claw": Data.find_by_id(Data.CLAWS, "gato"), "force": 15.0, "target": Data.find_by_id(Data.TARGETS, "plastico") },
		{ "claw": Data.find_by_id(Data.CLAWS, "oso"), "force": 300.0, "target": Data.find_by_id(Data.TARGETS, "madera") },
		{ "inlay": Data.find_by_id(Data.INLAYS, "diamante"), "force": 30.0, "target": Data.find_by_id(Data.TARGETS, "acero") },
		{ "claw": Data.find_by_id(Data.CLAWS, "aguila"), "inlay": Data.find_by_id(Data.INLAYS, "acero"), "force": 110.0, "target": Data.find_by_id(Data.TARGETS, "cobre") },
		{ "inlay": Data.find_by_id(Data.INLAYS, "diamante"), "force": 30.0, "target": Data.find_by_id(Data.TARGETS, "zafiro") },
	]:
		var s := scratch(over)
		if s.r.absMode != null:
			out.append(s)
	return out


func test_por_defecto_es_la_1x_al_bit() -> void:
	assert_eq(Attack.DEFAULT_DEG, 90.0)
	for s: Dictionary in cases():
		var r: Dictionary = s.r
		for att in [null, 90.0]:
			var ab := Attack.abrasion(r.Dp, r.depthUm, s.m, s.tip, s.alpha, att)
			assert_eq(ab.DpEff, r.Dp, "Dp")
			assert_eq(ab.absMode, r.absMode, "modo")
			assert_eq(ab.fab, r.fab, "fracción arrancada")
			assert_eq(ab.muPlough, r.muPlough, "fricción de arado")
			assert_eq(ab.faceDeg, 90.0 - s.alpha, "la cara con la punta de frente: 90° − α")


## Casi de frente, casi igual: el Dp efectivo es continuo en 90°.
func test_continuo_alrededor_de_90() -> void:
	for s: Dictionary in cases():
		var r: Dictionary = s.r
		for att in [89.999, 90.001]:
			assert_near(Attack.effective_dp(r.Dp, r.depthUm, s.m, s.tip, s.alpha, att), r.Dp, 1e-3, 1e-9, "%s°" % att)


## Una punta que trabaja en su casquete esférico es igual la inclines como la inclines.
func test_la_esfera_no_cambia() -> void:
	for s: Dictionary in cases():
		var r: Dictionary = s.r
		if r.depthUm / 1000.0 / s.m > s.tip.ht:
			continue
		for att in [Attack.MIN_DEG, 30.0, 135.0, Attack.MAX_DEG]:
			assert_eq(Attack.effective_dp(r.Dp, r.depthUm, s.m, s.tip, s.alpha, att), r.Dp, "%s°" % att)


## Clavar (más ángulo) nunca da un Dp menor que arrastrar: el modo nunca retrocede de corte a arado al levantar la punta.
func test_mas_ataque_nunca_ara_mas() -> void:
	var order := ["arado", "cuña", "corte"]
	for s: Dictionary in cases():
		var r: Dictionary = s.r
		var prev := -1.0
		var prev_mode := -1
		for att in [10.0, 20.0, 35.0, 50.0, 70.0, 90.0, 110.0, 135.0, 170.0]:
			var ab := Attack.abrasion(r.Dp, r.depthUm, s.m, s.tip, s.alpha, att)
			assert_true(ab.DpEff >= prev - 1e-12, "Dp baja a %s°" % att)
			assert_true(order.find(ab.absMode) >= prev_mode, "el modo retrocede a %s°" % att)
			prev = ab.DpEff
			prev_mode = order.find(ab.absMode)
			assert_true(ab.faceDeg >= Attack.FACE_MIN_DEG and ab.faceDeg <= 90.0)


## Una garra afilada que se arrastra tumbada ara; clavada de gancho, corta.
func test_arrastrar_tumbada_ara_y_clavar_corta() -> void:
	var s := scratch({ "claw": Data.find_by_id(Data.CLAWS, "gato"), "force": 15.0, "target": Data.find_by_id(Data.TARGETS, "plastico") })
	var r: Dictionary = s.r
	assert_eq(r.absMode, "corte", "de frente, la 1.x: corte")
	assert_true(Attack.abrasion(r.Dp, r.depthUm, s.m, s.tip, s.alpha, 20.0).absMode != "corte", "tumbada a 20°: arado o cuña")
	assert_eq(Attack.abrasion(r.Dp, r.depthUm, s.m, s.tip, s.alpha, 150.0).absMode, "corte")
	var st := scratch({ "geom": Data.find_by_id(Data.GEOMS, "stiletto"), "force": 30.0, "target": Data.find_by_id(Data.TARGETS, "madera") })
	assert_eq(Attack.abrasion(st.r.Dp, st.r.depthUm, st.m, st.tip, st.alpha, 15.0).absMode, "arado", "una stiletto de plano")


func test_angulos_de_referencia() -> void:
	# Hokkirigawa-Kato: Dp = tan(θ/2) en una esfera; los umbrales de la 1.x (0,1 y 0,2) son 11,4° y 22,6°
	assert_near(Attack.sphere_edge_angle_deg(0.1), 2.0 * rad_to_deg(atan(0.1)), 1e-12, 1e-12)
	assert_near(Attack.sphere_edge_angle_deg(Abrasion.DP_WEDGE), 11.42118627, 1e-8)
	assert_near(Attack.sphere_edge_angle_deg(Abrasion.DP_CUT), 22.61986495, 1e-8)
	assert_near(Attack.mean_front_angle_deg(0.2), 11.30993247, 1e-8)
	# la cara de frente: 90° − α; tumbada más allá de α, se apoya en el flanco (1°); de gancho, vertical (90°)
	assert_eq(Attack.natural_face_angle_deg(15.0), 75.0)
	assert_eq(Attack.face_angle_deg(15.0, 10.0), Attack.FACE_MIN_DEG)
	assert_eq(Attack.face_angle_deg(15.0, 170.0), 90.0)
	assert_true(Attack.is_default(null) and Attack.is_default(90.0) and not Attack.is_default(89.0))
