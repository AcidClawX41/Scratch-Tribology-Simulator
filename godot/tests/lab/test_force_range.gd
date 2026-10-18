## Escala de fuerza por herramienta (Lab.force_range): la de la 1.x (0,5-2000 N) no cambia; una herramienta con la clave
## `stinger` (un aguijón) va de 0,01 a 1000 mN, siempre en N por dentro. Se prueba con un aguijón falso (el mecanismo) y
## con los de verdad (core/lab/insects.gd, en el catálogo de la 2.0). El otro añadido de la 2.0, el velocirraptor, va en N,
## como las garras.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Insects = preload("res://core/lab/insects.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Format = preload("res://core/shared/format.gd")
const ParamsCard = preload("res://app/lab/params_card.gd")


## Un aguijón de prueba: una garra del catálogo con la clave `stinger` y la fuerza de una abeja (~2,5 mN).
static func fake_stinger(force := 0.0025) -> Dictionary:
	var s: Dictionary = Catalog.find_by_id(Catalog.CLAWS, "gato").duplicate(true)
	s.id = "aguijon-prueba"
	s.name = "Aguijón de prueba"
	s.force = force
	s.stinger = { "length_mm": 2.5 }
	return s


func test_escala_de_la_1x_sin_cambios() -> void:
	var want := { "min": 0.5, "max": 2000.0, "default": 4.0, "unit": "N", "log": true }
	assert_eq(Lab.force_range(null), want, "uña")
	var one: Array = Catalog.PARTS["CLAWS"][0]
	assert_eq(one.size(), 17, "las garras y colmillos de la 1.x")
	for c: Dictionary in one:
		assert_eq(Lab.force_range(c), want, "garra %s" % c.id)
	# los añadidos de la 2.0: los aguijones, todos en mN, con su empuje típico por defecto; y el velocirraptor (unidad 4i),
	# en N, como las garras
	var extra: Array = Catalog.PARTS["CLAWS"][1]
	assert_true(extra.filter(func(c: Dictionary) -> bool: return Insects.is_stinger(c)).size() >= 7, "aguijones en el catálogo de la 2.0")
	assert_true(extra.any(func(c: Dictionary) -> bool: return c.id == "velociraptor"), "y el velocirraptor")
	for s: Dictionary in extra:
		var r := Lab.force_range(s)
		if Insects.is_stinger(s):
			assert_eq([r.unit, r.min, r.max, r.default], ["mN", 1.0 / 100000.0, 1.0, s.force], "aguijón %s en mN" % s.id)
		else:
			assert_eq(r, want, "%s en N, como las garras" % s.id)
	assert_eq(Lab.FORCE_DEFAULT, LabState.LAB_DEFAULTS.force, "la fuerza por defecto es la inicial del banco")
	assert_eq(Format.FMIN, want.min)
	assert_eq(Format.FMAX, want.max)


func test_escala_de_un_aguijon_en_mn() -> void:
	var r := Lab.force_range(fake_stinger())
	assert_eq(r.unit, "mN")
	assert_true(r.log, "logarítmica")
	assert_eq(r.min, 1.0 / 100000.0, "0,01 mN")
	assert_eq(r.max, 1.0, "1000 mN")
	assert_eq(r.default, 0.0025, "por defecto, su fuerza (N)")
	assert_eq(Lab.force_range(fake_stinger(5.0)).default, 1.0, "una fuerza fuera de escala se recorta")
	var no_force := fake_stinger()
	no_force.erase("force")
	assert_eq(Lab.force_range(no_force).default, r.min, "sin fuerza en la ficha: el mínimo de la escala")
	# reforjado en otro material (inlay distinto de "none"): hasta 5000 mN (la abeja de diamante pandea hacia 3,8 N)
	var diamond: Dictionary = Catalog.find_by_id(Catalog.INLAYS, "diamante")
	var forged := Lab.force_range(fake_stinger(), diamond)
	assert_eq(forged.max, 5.0, "aguijón reforjado: hasta 5 N")
	assert_eq([forged.min, forged.unit, forged.default], [r.min, "mN", 0.0025], "lo demás, igual")
	assert_eq(Lab.force_range(fake_stinger(), "diamante").max, 5.0, "el material también por su id")
	assert_eq(Lab.force_range(fake_stinger(), Catalog.INLAYS[0]).max, 1.0, "sin reforjar (none): hasta 1000 mN")
	assert_eq(Lab.force_range(fake_stinger(), "none").max, 1.0)
	assert_eq(Lab.force_range(Catalog.find_by_id(Catalog.CLAWS, "tigre"), diamond).max, 2000.0, "una garra reforjada sigue en la escala de la 1.x")
	assert_eq(ParamsCard.tick_texts(forged), ["0,01 mN", "1 mN", "100 mN", "5000 mN"], "marcas de la escala reforjada")
	assert_eq(Format.fmt_force(0.0025, "mN"), "2.5 mN")
	assert_eq(Format.fmt_force(4.0, "N"), "4.0 N", "en N, lo de siempre (fmt_f)")
	assert_eq(Format.fmt_mn(0.00001), "0.01")
	assert_eq(Format.fmt_mn(0.00025), "0.25")
	assert_eq(Format.fmt_mn(0.03), "30")
	assert_eq(Format.fmt_mn(1.0), "1000")


func test_deslizador_con_la_escala_como_parametro() -> void:
	# con FMIN y FMAX, al bit lo mismo que f_to_t y t_to_f (las que usa la 1.x)
	for i in 1001:
		var t := i / 1000.0
		var f := Format.t_to_f(t)
		assert_eq(Format.t_to_f_in(t, Format.FMIN, Format.FMAX), f, "t_to_f(%s)" % t)
		assert_eq(Format.f_to_t_in(f, Format.FMIN, Format.FMAX), Format.f_to_t(f), "f_to_t(%s)" % f)
		assert_eq(ParamsCard.force_from_slider_in(t, Lab.force_range(null)), ParamsCard.force_from_slider(t), "deslizador de la 1.x en %s" % t)
	# en mN: extremos, ida y vuelta y redondeo a valores legibles
	var r := Lab.force_range(fake_stinger())
	assert_eq(Format.f_to_t_in(r.min, r.min, r.max), 0.0)
	assert_near(Format.f_to_t_in(r.max, r.min, r.max), 1.0, 1e-15, 0.0)
	assert_near(Format.t_to_f_in(0.0, r.min, r.max), r.min, 1e-12, 0.0)
	assert_near(Format.t_to_f_in(1.0, r.min, r.max), r.max, 1e-12, 0.0)
	for f in [0.00001, 0.0001, 0.0025, 0.03, 0.5, 1.0]:
		assert_near(Format.t_to_f_in(Format.f_to_t_in(f, r.min, r.max), r.min, r.max), f, 1e-9, 0.0, "ida y vuelta %s N" % f)
	assert_eq(ParamsCard.force_from_slider_in(0.0, r), r.min, "0,01 mN")
	assert_eq(ParamsCard.force_from_slider_in(1.0, r), r.max, "1000 mN")
	assert_eq(ParamsCard.force_from_slider_in(Format.f_to_t_in(0.0025, r.min, r.max), r), 0.0025, "2,5 mN")
	var prev := 0.0
	for i in 251:
		var f := ParamsCard.force_from_slider_in(i * 0.004, r)
		assert_true(f >= prev and f >= r.min and f <= r.max, "monótona y dentro de la escala")
		prev = f
		# en la rejilla de valores legibles: centésimas de mN por debajo de 1 mN, décimas hasta 10 y unidades
		var mn := f * 1000.0
		var grid := 100.0 if mn < 1.0 else (10.0 if mn < 10.0 else 1.0)
		assert_near(mn * grid, roundf(mn * grid), 1e-9, 1e-6, "legible: %s mN" % Format.fmt_mn(f))


func test_el_banco_cambia_de_escala_con_la_herramienta() -> void:
	var lab := LabState.new()
	lab.set_force(30.0)
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
	assert_eq(lab.force, 30.0, "entre herramientas de la 1.x la fuerza se conserva")
	lab.set_claw(fake_stinger())
	assert_eq(lab.force_range().unit, "mN")
	assert_eq(lab.force, 0.0025, "30 N no caben en la escala de un aguijón: su fuerza")
	lab.set_force(0.001)
	lab.set_claw(fake_stinger(0.004))
	assert_eq(lab.force, 0.001, "entre aguijones, se conserva")
	lab.set_inlay(Catalog.find_by_id(Catalog.INLAYS, "diamante"))
	assert_eq(lab.force_range().max, 5.0, "reforjado en diamante: hasta 5 N")
	lab.set_force(3.8)
	lab.set_inlay(Catalog.INLAYS[0])
	assert_eq(lab.force, 0.004, "sin reforjar, 3,8 N no caben: la fuerza del aguijón")
	lab.set_claw(null)
	assert_eq(lab.force, Lab.FORCE_DEFAULT, "de vuelta a una uña: la fuerza inicial")
	assert_eq(lab.force_range().unit, "N")
