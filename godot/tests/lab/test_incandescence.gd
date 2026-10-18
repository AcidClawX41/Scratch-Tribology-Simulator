## El color de un cuerpo caliente (core/lab/incandescence.gd, unidad 5f): la ley de Planck tiene su máximo donde dice Wien;
## el ajuste de las funciones de la CIE tiene sus picos donde las tablas de la CIE 1931; un cuerpo negro a 6500 K es casi
## blanco en sRGB y a 600 °C es rojo; al calentar, el color va del rojo al blanco (el verde y el azul crecen frente al
## rojo) y el brillo sube; la rampa para la escena da lo mismo que el cálculo; y las palabras son las de los herreros.
extends "res://tests/case.gd"

const Incandescence = preload("res://core/lab/incandescence.gd")


func test_planck_tiene_su_maximo_donde_dice_wien() -> void:
	for t_k in [1500.0, 3000.0, 5000.0]:
		var best := 0.0
		var best_l := 0.0
		var l := 200.0
		while l < 5000.0:
			var b := Incandescence.planck_rel(l, t_k)
			if b > best:
				best = b
				best_l = l
			l += 1.0
		assert_near(best_l, Incandescence.wien_peak_nm(t_k), 0.002, 1.0, "a %s K, el máximo en b/T" % t_k)


func test_las_funciones_de_la_cie_tienen_sus_picos() -> void:
	# CIE 1931 2°: ȳ = 1 a 555 nm; x̄ = 1,062 a 595 nm; z̄ = 1,782 a 445 nm (tablas de la CIE)
	var y_max := 0.0
	var y_at := 0.0
	var x_max := 0.0
	var z_max := 0.0
	var l := 380.0
	while l <= 780.0:
		var c := Incandescence.cmf(l)
		if c.y > y_max:
			y_max = c.y
			y_at = l
		x_max = maxf(x_max, c.x)
		z_max = maxf(z_max, c.z)
		l += 1.0
	assert_near(y_max, 1.0, 0.03, 0.0, "ȳ llega a 1")
	assert_near(y_at, 555.0, 0.01, 0.0, "hacia 555 nm")
	assert_near(x_max, 1.062, 0.03, 0.0, "x̄ llega a ~1,06")
	assert_near(z_max, 1.782, 0.04, 0.0, "z̄ llega a ~1,78")


func test_del_rojo_al_blanco() -> void:
	var red := Incandescence.color(600.0)
	assert_eq(red.r, 1.0, "a 600 °C manda el rojo")
	assert_true(red.g < 0.35 and red.b == 0.0, "sin azul y con poco verde (%s)" % red)
	var white := Incandescence.color(6500.0 - 273.15)
	assert_true(white.r > 0.9 and white.g > 0.9 and white.b > 0.9, "a 6500 K, casi blanco (%s)" % white)
	var prev := Incandescence.color(500.0)
	var t := 600.0
	while t <= 3000.0:
		var c := Incandescence.color(t)
		assert_true(c.g >= prev.g - 1e-9 and c.b >= prev.b - 1e-9, "a %s °C, el verde y el azul no bajan" % t)
		prev = c
		t += 100.0


func test_el_brillo_sube_con_la_temperatura() -> void:
	assert_eq(Incandescence.strength(Incandescence.DARK_C), 0.0, "no brilla por debajo de lo que se ve en la oscuridad")
	assert_eq(Incandescence.strength(Incandescence.BRIGHT_C), 1.0, "y el dibujo llega al máximo")
	var prev := -1.0
	var t := 400.0
	while t <= 2500.0:
		var s := Incandescence.strength(t)
		assert_true(s > prev, "a %s °C brilla más" % t)
		prev = s
		t += 50.0
	assert_true(Incandescence.luminance_rel(1000.0) > 100.0, "a 1000 °C, cientos de veces la luminancia del punto de Draper")


func test_la_rampa_da_lo_mismo_que_el_calculo() -> void:
	var rows := Incandescence.ramp()
	for r: Array in rows:
		if float(r[0]) <= Incandescence.DARK_C:
			continue
		var g := Incandescence.glow(float(r[0]))
		assert_eq(r[1], g.color, "%s °C: el mismo color" % r[0])
		assert_near(float(r[2]), float(g.strength), 1e-12, 1e-12, "%s °C: el mismo brillo" % r[0])
	var mid := Incandescence.glow_at(rows, 1312.5)
	var exact := Incandescence.glow(1312.5)
	assert_near(mid.color.g, exact.color.g, 0.01, 0.0, "entre filas, casi lo mismo")
	assert_eq(Incandescence.glow_at(rows, 20.0).strength, 0.0, "frío, negro")


func test_las_palabras_de_los_herreros() -> void:
	assert_eq(Incandescence.word(300.0), "", "a 300 °C no se ve brillar")
	assert_eq(Incandescence.word(399.0), "rojo tenue (se ve en la oscuridad)", "TM 9-237: 750 °F")
	assert_eq(Incandescence.word(850.0), "rojo brillante", "1550 °F")
	assert_eq(Incandescence.word(2100.0), "blanco", "desde 2200 °F, blanco")
	var g := Incandescence.glow(2100.0)
	assert_eq(String(g.quality), "primary", "la física, con su calidad")
	assert_true(String(g.source).contains("Planck") and String(g.source).contains("CIE"), "y su fuente")
	assert_eq(String(g.strengthQuality), "dibujo", "el brillo comprimido es dibujo")
