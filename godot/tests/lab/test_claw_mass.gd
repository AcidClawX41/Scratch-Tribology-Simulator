## Densidad de las garras experimentales (core/lab/claw_mass.gd, unidad 4e): cada material de Data.INLAYS (y la
## queratina) tiene su densidad con fuente, el volumen es el de la garra del motor, y el efecto de la masa sale del primer
## principio sin inventar nada: con el mismo trabajo muscular la energía no cambia; con la misma velocidad sube lo que pesa
## de más. En el velocirraptor apenas cambia; en una daga de oro de casuario, algo sí.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


## Volumen medido de la garra falciforme: el largo de la queratina con la base del núcleo óseo (alto y ancho).
static func raptor_volume() -> float:
	var s: Dictionary = Velociraptor.SICKLE
	return ClawMass.elliptic_cone_volume_mm3(float(s.keratinMm.value), float(s.coreHeightMm.value), float(s.coreWidthMm.value))


func test_cada_material_tiene_densidad_con_fuente() -> void:
	for inlay: Dictionary in Data.INLAYS:
		var d: Variant = ClawMass.density_of(inlay)
		assert_true(d != null, "%s: densidad" % inlay.id)
		if d == null:
			continue
		assert_true(String(d.source).length() > 20 and QUALITIES.has(d.quality), "%s: fuente y calidad" % inlay.id)
		assert_true(float(d.min) <= float(d.value) and float(d.value) <= float(d.max), "%s: banda" % inlay.id)
		assert_true(float(d.value) > 1000.0 and float(d.value) < 25000.0, "%s: en kg/m³" % inlay.id)
	assert_eq(ClawMass.density_of(null), ClawMass.density_of("none"), "sin reforjar: queratina")
	assert_eq(ClawMass.density_of("plutonio"), null, "sin dato: null")


func test_el_orden_de_las_densidades() -> void:
	# lo que se sabe de la tabla periódica y de los minerales: el oro es lo más denso y la queratina lo menos
	var keratin: float = ClawMass.density_of("none").value
	var gold: float = ClawMass.density_of("oro").value
	for inlay: Dictionary in Data.INLAYS:
		var d: float = ClawMass.density_of(inlay).value
		assert_true(d >= keratin and d <= gold, "%s entre la queratina y el oro" % inlay.id)
	assert_true(ClawMass.density_of("tungsteno").value > ClawMass.density_of("acero").value, "carburo de tungsteno > acero")
	assert_true(ClawMass.density_of("diamante").value < ClawMass.density_of("zafiro").value, "diamante < zafiro")


func test_la_base_es_la_del_motor() -> void:
	assert_eq(ClawMass.CLAW_BASE, float(Physics.MODEL.clawBase), "0,15 × alcance, como Physics.MODEL.clawBase")
	var l := 40.0
	assert_near(ClawMass.cone_volume_mm3(l), PI * (0.15 * l) * (0.15 * l) * l / 3.0, 1e-12, 0.0, "cono del motor")
	assert_near(ClawMass.elliptic_cone_volume_mm3(90.0, 20.0, 8.0), PI * 20.0 * 8.0 * 90.0 / 12.0, 1e-12, 0.0, "cono elíptico")
	# la garra medida del velocirraptor es mucho más fina que el cono del motor (una hoja estrecha)
	assert_true(raptor_volume() < ClawMass.cone_volume_mm3(float(Velociraptor.ENTRY.reach)), "medida < cono del motor")


func test_con_el_mismo_trabajo_la_misma_energia() -> void:
	for inlay: Dictionary in Data.INLAYS:
		var e: Variant = ClawMass.energy_effect(inlay, 5000.0, 2, 19.7, 9.85, 4.84)
		assert_eq(e.sameWorkEnergy, 1.0, "%s: el trabajo muscular es la energía" % inlay.id)
		var heavier: bool = float(e.clawKg) > float(e.keratinKg)
		if heavier:
			assert_true(e.sameWorkSpeed < 1.0, "%s: más pesada, más lenta" % inlay.id)
			assert_true(e.sameSpeedEnergy > 1.0 and e.extraJ > 0.0, "%s: a la misma velocidad, más energía" % inlay.id)
	var none: Dictionary = ClawMass.energy_effect("none", 5000.0, 2, 19.7, 9.85, 4.84)
	assert_eq(none.addedKg, 0.0, "la queratina no añade nada")
	assert_eq(none.sameWorkSpeed, 1.0, "ni cambia la velocidad")


func test_en_el_velocirraptor_apenas_cambia() -> void:
	var e: Dictionary = Velociraptor.ENTRY
	for inlay: Dictionary in Data.INLAYS:
		# con la garra medida
		var m: Dictionary = ClawMass.energy_effect(inlay, raptor_volume(), 2, e.mass, e.strike.m, e.strike.v)
		assert_false(m.noticeable, "%s: apenas cambia (%s %% del animal)" % [inlay.id, float(m.bodyShare) * 100.0])
		# y aun con el cono generoso del motor
		var g: Dictionary = ClawMass.energy_effect(inlay, ClawMass.cone_volume_mm3(float(e.reach)), 2, e.mass, e.strike.m, e.strike.v)
		assert_false(g.noticeable, "%s: ni con el cono del motor (%s %%)" % [inlay.id, float(g.bodyShare) * 100.0])


func test_una_daga_de_oro_si_se_nota_algo() -> void:
	# casuario: daga de 110 mm, golpe de 5 kg a 8 m/s (catálogo 1.x); con el cono del motor, ~0,6 kg de oro
	var c: Dictionary = Data.find_by_id(Data.CLAWS, "casuario")
	var g: Dictionary = ClawMass.energy_effect("oro", ClawMass.cone_volume_mm3(float(c.reach)), 1, c.mass, c.strike.m, c.strike.v)
	assert_true(g.noticeable, "el oro pesa ~%s %% de la masa del golpe" % (float(g.strikeShare) * 100.0))
	assert_true(g.sameWorkSpeed > 0.9 and g.sameWorkSpeed < 1.0, "con el mismo trabajo, algo más lenta")
	var d: Dictionary = ClawMass.energy_effect("diamante", ClawMass.cone_volume_mm3(float(c.reach)), 1, c.mass, c.strike.m, c.strike.v)
	assert_false(d.noticeable, "de diamante (3,5 g/cm³), apenas")


func test_la_masa_de_una_garra() -> void:
	var v := 1000.0  # 1 cm³
	assert_near(ClawMass.claw_mass_kg("oro", v), 0.0193, 1e-12, 0.0, "1 cm³ de oro: 19,3 g")
	assert_near(ClawMass.claw_mass_kg("none", v), 0.00131, 1e-12, 0.0, "1 cm³ de queratina: 1,31 g")
	assert_near(ClawMass.claw_mass_kg("tungsteno", v, "max"), 0.01504, 1e-12, 0.0, "banda alta")
	assert_eq(ClawMass.claw_mass_kg("plutonio", v), null, "sin densidad: null")
