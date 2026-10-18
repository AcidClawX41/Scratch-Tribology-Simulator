## El golpe del animal que se revuelve (core/lab/care_strike.gd, unidad 5t-B): trabajo y energía con la fuerza de la garra
## y la masa del golpe del catálogo. Invariantes: más recorrido nunca da un golpe más lento al llegar ni más corto en
## tiempo; el tigre y el oso, ~7 m/s (los de su ficha); una garra reforjada más pesada nunca llega antes, y ni el oro ni el
## carburo de tungsteno se notan (ClawMass); sin ficha, no hay golpe.
extends "res://tests/case.gd"

const CareStrike = preload("res://core/lab/care_strike.gd")


func test_mas_recorrido_mas_velocidad_y_mas_tiempo() -> void:
	for claw: String in ["aguila", "buho", "tigre", "oso", "velociraptor"]:
		var prev := {}
		for d: float in [0.05, 0.1, 0.2, 0.3, 0.5]:
			var s := CareStrike.strike(claw, "none", d)
			assert_true(bool(s.ok), "%s: tiene ficha" % claw)
			if not prev.is_empty():
				assert_true(float(s.vMs) >= float(prev.vMs) and float(s.tS) >= float(prev.tS), "%s: más recorrido, más velocidad y más tiempo" % claw)
			assert_near(float(s.tS), 2.0 * d / float(s.vMs), 1e-9, 1e-12, "%s: t = 2·d/v (aceleración constante desde el reposo)" % claw)
			prev = s


func test_tigre_y_oso_como_su_ficha() -> void:
	var t := CareStrike.strike("tigre", "none", 0.28)
	var o := CareStrike.strike("oso", "none", 0.32)
	assert_true(absf(float(t.vMs) - 7.0) < 0.6, "el tigre llega a ~7 m/s (%s)" % str(t.vMs))
	assert_true(absf(float(o.vMs) - 7.0) < 0.6, "el oso llega a ~7 m/s (%s)" % str(o.vMs))
	assert_eq(String(t.quality), "estimate", "estimación")


func test_la_garra_mas_pesada_no_llega_antes_y_no_se_nota() -> void:
	for inlay: String in ["oro", "tungsteno", "acero", "diamante"]:
		var k := CareStrike.strike("aguila", "none", 0.12)
		var r := CareStrike.strike("aguila", inlay, 0.12)
		assert_true(float(r.tClawS) >= float(k.tClawS) - 1e-12 or float(r.addedKg) < 0.0, "%s: no llega antes que la queratina" % inlay)
		assert_false(bool(r.appreciable), "%s: no se nota en el golpe de un águila (ClawMass)" % inlay)
	assert_false(bool(CareStrike.strike("no-existe", "none", 0.1).ok), "sin ficha, no hay golpe")
