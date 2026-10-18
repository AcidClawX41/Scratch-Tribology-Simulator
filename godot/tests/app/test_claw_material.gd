## La biblioteca de materiales de las garras (app/common/claw_material.gd, unidad 5e), su malla (claw_geo.gd) y el
## aspecto de la cetrería que la usa (lab/cetreria/claw_look.gd). Se comprueba:
##   - que cada material se construye una vez por clave (material, acabado, calidad, entorno, color…) y se reutiliza, y
##     que pedirlo en cada fotograma no crea nada;
##   - que todos los materiales se construyen en el escritorio y en el teléfono (este, con el sombreador opaco: sin leer
##     la pantalla) y llevan sus números de core/lab/claw_optics.gd (el F0 medido de cada metal, el índice por canal y la
##     absorción de cada gema);
##   - que el acabado cambia la superficie (pulido frente a limado, facetas, mellas) y la superficie de la cetrería se
##     codifica como dice el contrato (R = log₁₀(Ra/0,01 µm)/log₁₀(5000), G = quemado, B = desconchón, A = rayado/180°,
##     surface_range);
##   - el material de una garra de la reforja con una sola llamada (for_forge);
##   - la malla de la garra: s, la vuelta, el radio y el largo en mm, en dos trozos para el coche, sin deformarla;
##   - el aspecto de la cetrería: la queratina translúcida de las garras claras, los metales opacos, las gemas.
extends "res://tests/case.gd"

const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawGeo = preload("res://app/common/claw_geo.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const ClawLook = preload("res://app/lab/cetreria/claw_look.gd")
const KERATIN = preload("res://app/lab/cetreria/keratin.gdshader")
const Mammals3D = preload("res://app/lab/animals/mammals3d.gd")
const Theropod3D = preload("res://app/lab/animals/theropod3d.gd")


func test_una_vez_por_clave_y_nada_en_cada_fotograma() -> void:
	ClawMaterial.clear_cache()
	var b0 := ClawMaterial.built
	var a := ClawMaterial.material("oro")
	var b := ClawMaterial.material("oro")
	assert_true(a == b, "el mismo material de la caché (no una copia)")
	assert_eq(ClawMaterial.built, b0 + 1, "construido una sola vez")
	var c := ClawMaterial.material("oro", ClawOptics.finish("limado", 200.0))
	assert_false(c == a, "otro acabado, otro material")
	var d := ClawMaterial.material("oro", {}, { "quality": "movil" })
	assert_false(d == a, "otra calidad, otro material")
	var e := ClawMaterial.material("none", {}, { "color": Color("#D9C49E") })
	var f := ClawMaterial.material("none", {}, { "color": Color("#2E2A26") })
	assert_false(e == f, "la queratina de otra especie, otro material")
	var built := ClawMaterial.built
	var size := ClawMaterial.cache_size()
	# lo que haría una escena en cada fotograma: pedir otra vez los mismos
	for i in 300:
		ClawMaterial.material("oro")
		ClawMaterial.material("none", {}, { "color": Color("#D9C49E") })
		ClawMaterial.material("oro", ClawOptics.finish("limado", 200.0))
	assert_eq(ClawMaterial.built, built, "en cada fotograma no se construye nada")
	assert_eq(ClawMaterial.cache_size(), size, "ni crece la caché")


func test_todos_los_materiales_en_escritorio_y_movil() -> void:
	var ids: Array = ClawOptics.MATERIAL_IDS + ["tin", "cromo", "zafiro_incoloro"]
	for id: String in ids:
		var lk := ClawOptics.look(id)
		for q: String in ["escritorio", "movil"]:
			var m := ClawMaterial.material(id, {}, { "quality": q })
			assert_true(m != null and m.shader != null, "%s (%s): se construye" % [id, q])
			var transparent := bool(lk.get("transparent", false))
			var want: Shader = ClawMaterial.GEM if transparent and q == "escritorio" else ClawMaterial.SOLID
			assert_true(m.shader == want, "%s (%s): %s" % [id, q, "lee la pantalla" if want == ClawMaterial.GEM else "opaco"])
			assert_eq(int(m.get_shader_parameter("claw_quality")), 1 if q == "movil" else 0, "%s (%s): la calidad" % [id, q])
		var p := ClawMaterial.params(id)
		var f0: Vector3 = p.claw_f0
		var lf0: Array = lk.f0
		assert_near(f0.x, float(lf0[0]), 1e-6, 1e-6, "%s: F0 de claw_optics (rojo)" % id)
		assert_near(f0.z, float(lf0[2]), 1e-6, 1e-6, "%s: F0 de claw_optics (azul)" % id)
		match String(lk.family):
			"metal", "mineral":
				assert_eq(int(p.claw_kind), 1, "%s: metálico" % id)
			"gema", "vidrio":
				assert_eq(int(p.claw_kind), 2, "%s: gema o vidrio" % id)
				var ior: Vector3 = p.claw_ior
				var lior: Array = lk.ior
				assert_near(ior.y, float(lior[1]), 1e-6, 1e-6, "%s: el índice de claw_optics" % id)
				assert_true(ior.z > ior.x, "%s: dispersión normal (azul más que rojo)" % id)


func test_metales_con_su_reflejo_y_gemas_con_su_color() -> void:
	var gold: Vector3 = ClawMaterial.params("oro").claw_f0
	assert_true(gold.x > gold.z * 1.8, "el oro, amarillo: refleja más rojo que azul (%s)" % gold)
	for id: String in ["acero", "titanio"]:
		var g: Vector3 = ClawMaterial.params(id).claw_f0
		var hi := maxf(g.x, maxf(g.y, g.z))
		var lo := minf(g.x, minf(g.y, g.z))
		assert_true(hi / lo < 1.25, "%s: gris, con su matiz (%s)" % [id, g])
	var ruby: Vector3 = ClawMaterial.params("rubi").claw_absorb
	assert_true(ruby.y > ruby.x * 3.0, "el rubí absorbe el verde y deja pasar el rojo (%s)" % ruby)
	var sapphire: Vector3 = ClawMaterial.params("zafiro").claw_absorb
	assert_true(sapphire.x > sapphire.z, "el zafiro absorbe el rojo y deja pasar el azul (%s)" % sapphire)
	var dia := ClawOptics.look("diamante")
	var mois := ClawOptics.look("moissanita")
	assert_true(float(mois.dispersion_bg) > float(dia.dispersion_bg) * 2.0, "la moissanita tiene más fuego que el diamante")


func test_el_acabado_cambia_la_superficie() -> void:
	var pol := ClawMaterial.params("acero", ClawOptics.finish("pulido"))
	var fil := ClawMaterial.params("acero", ClawOptics.finish("limado", 770.0))
	assert_true(float(pol.claw_rough) < float(fil.claw_rough), "pulido espejo, menos rugoso que limado (%s < %s)" % [pol.claw_rough, fil.claw_rough])
	assert_true(float(fil.claw_scratch) > 0.0, "limado: con rayas")
	var cut := ClawMaterial.params("zafiro", ClawOptics.finish("tallado"))
	assert_true(float(cut.claw_facets) > 2.0, "tallado: con facetas")
	var chip := ClawMaterial.params("vidrio", ClawOptics.finish("mellado"))
	assert_true(float(chip.claw_chips) > 0.0, "mellado: con mellas")
	var frost := ClawMaterial.params("cuarzo", ClawOptics.finish("limado", 770.0))
	assert_true(float(frost.claw_frost) > float(ClawMaterial.params("cuarzo").claw_frost), "una gema limada se vuelve lechosa")
	# más rugosa nunca brilla más (la cuenta de la rugosidad, monótona)
	var prev := -1.0
	for sigma: float in [0.002, 0.01, 0.05, 0.2, 1.0, 5.0, 20.0]:
		var r := ClawMaterial.roughness_of(sigma)
		assert_true(r >= prev, "rugosidad de Godot monótona con σ (%s µm → %s)" % [sigma, r])
		prev = r


func test_la_superficie_de_la_cetreria_como_dice_el_contrato() -> void:
	var st := [{ "ra_um": 0.0, "burn": 0.0, "chip": 0.0, "scratch_deg": 0.0 }, { "ra_um": 25.0, "burn": 0.5, "chip": 1.0, "scratch_deg": 90.0 },
		{ "ra_um": 80.0, "burn": 2.0, "chip": 0.0, "scratch_deg": 270.0 }]
	var img := ClawMaterial.surface_image(st)
	assert_eq(img.get_width(), 3, "una columna por estación")
	assert_eq(img.get_height(), 1, "una fila")
	assert_eq(img.get_format(), Image.FORMAT_RGBA8, "RGBA8")
	assert_near(img.get_pixel(0, 0).r, 0.0, 0.0, 1.0 / 255.0, "Ra = 0: R = 0 (pulido espejo)")
	var p1 := img.get_pixel(1, 0)
	assert_near(p1.r, log(2500.0) / log(5000.0), 0.0, 1.0 / 255.0, "R = log₁₀(Ra/0,01 µm)/log₁₀(5000)")
	assert_near(p1.g, 0.5, 0.0, 1.0 / 255.0, "G = quemado")
	assert_near(p1.b, 1.0, 0.0, 1.0 / 255.0, "B = desconchón")
	assert_near(p1.a, 0.5, 0.0, 1.0 / 255.0, "A = rayado/180°")
	var p2 := img.get_pixel(2, 0)
	assert_near(p2.r, 1.0, 0.0, 1.0 / 255.0, "Ra de más de 50 µm, recortada a 1")
	# en 8 bits se distinguen los pulidos finos (con R = Ra/50, todo lo que bajaba de 0,2 µm era 0)
	var fine := ClawMaterial.surface_image([{ "ra_um": 0.05 }, { "ra_um": 0.2 }, { "ra_um": 1.0 }])
	assert_true(fine.get_pixel(1, 0).r - fine.get_pixel(0, 0).r > 10.0 / 255.0, "0,05 µm y 0,2 µm, distintas en la textura")
	assert_true(fine.get_pixel(2, 0).r - fine.get_pixel(1, 0).r > 10.0 / 255.0, "0,2 µm y 1 µm, distintas en la textura")
	for ra: float in [0.01, 0.05, 0.3, 2.0, 12.0, 50.0]:
		var back := ClawMaterial.surface_ra(roundf(ClawMaterial.surface_r(ra) * 255.0) / 255.0)
		assert_near(back, ra, 0.035, 0.0, "Ra %s µm vuelve igual de la textura (±3,5 %%)" % ra)
	assert_near(p2.g, 1.0, 0.0, 1.0 / 255.0, "quemado recortado a 1")
	assert_near(p2.a, 0.5, 0.0, 1.0 / 255.0, "270° es la misma dirección que 90°")
	var tex := ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = ClawMaterial.SOLID
	ClawMaterial.set_surface(m, tex, 38.5)
	assert_eq(m.get_shader_parameter("surface_range"), Vector2(0.0, 38.5), "surface_range = (0, largo en mm)")
	assert_true(m.get_shader_parameter("surface_tex") == tex, "y la textura")
	ClawMaterial.clear_surface(m)
	assert_eq(m.get_shader_parameter("surface_range"), Vector2.ZERO, "(0, 0): sin superficie, la del acabado")
	var built := ClawMaterial.built
	var a := ClawMaterial.material("titanio", {}, { "surface": { "id": "muestra", "tex": tex, "length_mm": 30.0 } })
	var b := ClawMaterial.material("titanio", {}, { "surface": { "id": "muestra", "tex": tex, "length_mm": 30.0 } })
	assert_true(a == b and ClawMaterial.built == built + 1, "con superficie, también una vez por clave")
	assert_eq(a.get_shader_parameter("surface_range"), Vector2(0.0, 30.0), "con su largo")


func test_la_reforja_con_una_sola_llamada() -> void:
	var rc := { "inlay": "zafiro", "finish": "pulido", "coating": null }
	var m := ClawMaterial.for_forge(rc)
	assert_eq(int(m.get_shader_parameter("claw_kind")), 2, "la funda de zafiro pulida: una gema")
	var tin := ClawMaterial.for_forge({ "inlay": "acero", "finish": "pulido", "coating": { "material": "tin", "thicknessUm": 3.0 } })
	var gold_like: Vector3 = tin.get_shader_parameter("claw_f0")
	assert_eq(int(tin.get_shader_parameter("claw_kind")), 1, "con una capa de nitruro de titanio que se ve: metálica")
	assert_true(gold_like.x > gold_like.z, "y dorada (%s)" % gold_like)
	var alu := ClawMaterial.for_forge({ "inlay": "acero", "finish": "pulido", "coating": { "material": "alumina", "thicknessUm": 5.0, "porosity": 0.0 } })
	assert_eq(float(alu.get_shader_parameter("claw_clear")), 1.0, "la alúmina densa y fina es transparente: se ve lo de debajo con un barniz")


func test_la_malla_de_la_garra_en_mm_sin_deformarla() -> void:
	var g := ClawGeo.model_claw(40.0, 12.0, 8.0, 120.0, 8, 6, 10)
	var base: Array = g.base
	var tip: Array = g.tip
	var uv_b: PackedVector2Array = base[Mesh.ARRAY_TEX_UV]
	var uv_t: PackedVector2Array = tip[Mesh.ARRAY_TEX_UV]
	var uv2_t: PackedVector2Array = tip[Mesh.ARRAY_TEX_UV2]
	var lo := INF
	var hi := -INF
	for v: Vector2 in uv_b:
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	assert_true(lo < 0.0, "la base, cerrada con un casquete hacia atrás (s < 0)")
	assert_near(hi, float(g.cut_mm), 1e-9, 1e-6, "la base llega hasta el corte (s en mm)")
	var t_lo := INF
	var t_hi := -INF
	for v: Vector2 in uv_t:
		t_lo = minf(t_lo, v.x)
		t_hi = maxf(t_hi, v.x)
	assert_near(t_lo, float(g.cut_mm), 1e-9, 1e-6, "la punta empieza en el corte")
	assert_near(t_hi, 40.0, 1e-9, 1e-6, "y acaba en el largo")
	for v: Vector2 in uv2_t:
		assert_near(v.y, 40.0, 1e-9, 1e-6, "UV2.y, el largo de la garra (mm)")
	# la línea media es un arco de 120° de 40 mm: la punta, a la cuerda 2R·sen(θ/2), con R = L/θ
	var th := deg_to_rad(120.0)
	var chord := 2.0 * (40.0 / th) * sin(th * 0.5)
	assert_near((g.tip_point as Vector3).length(), chord, 1e-6, 1e-6, "la punta, donde la pone el arco")
	# el material no mueve vértices: la misma malla para cualquier material (la geometría solo sale de los datos)
	var g2 := ClawGeo.model_claw(40.0, 12.0, 8.0, 120.0, 8, 6, 10)
	assert_eq((g2.base as Array)[Mesh.ARRAY_VERTEX], base[Mesh.ARRAY_VERTEX], "determinista")
	var mesh := ClawGeo.claw_mesh("aguila")
	assert_true(mesh.get_surface_count() == 1, "la garra del catálogo, en una malla")
	var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_near(uv2[0].y, float(ClawGeo.spec_of("aguila").length_mm), 1e-9, 1e-6, "con su largo del catálogo")


func test_el_aspecto_de_la_cetreria() -> void:
	var light := ClawLook.params("none", Color("#D9C49E"), { "light": true })
	assert_eq(int(light.claw_kind), 0, "queratina")
	assert_true(float(light.opacity) < 0.7, "una garra clara deja ver la carne viva a trasluz (%s)" % light.opacity)
	assert_eq((light.claw_base as Color).to_html(false), Color("#D9C49E").to_html(false), "con el color de su especie")
	var dark := ClawLook.params("none", Color("#2E2A26"), {})
	assert_true(float(dark.opacity) > 0.9, "una oscura, casi opaca")
	var gold := ClawLook.params("oro", Color.WHITE, { "light": true })
	assert_eq(int(gold.claw_kind), 1, "el oro, metálico")
	assert_eq(float(gold.opacity), 1.0, "y opaco")
	var dia := ClawLook.params("diamante", Color.WHITE, {})
	assert_eq(int(dia.claw_kind), 2, "el diamante, una gema")
	assert_true(float(dia.opacity) < 1.0, "que deja ver algo de lo de detrás")
	var m := ShaderMaterial.new()
	m.shader = KERATIN
	m.set_shader_parameter("heat_on", 1.0)
	ClawLook.apply(m, gold)
	assert_eq(int(m.get_shader_parameter("claw_kind")), 1, "apply pone el material")
	assert_eq(float(m.get_shader_parameter("heat_on")), 1.0, "y no toca lo del estado")
	assert_true(m.get_shader_parameter("natural") == null and m.get_shader_parameter("material") == null, "ni las claves que no son del sombreador")
	var src := KERATIN.code
	assert_true(src.contains("claw_material.gdshaderinc"), "el sombreador de la cetrería incluye el modelo de la biblioteca")
	for k: String in ["surface_tex", "surface_range"]:
		assert_true(FileAccess.get_file_as_string("res://app/common/claw_material.gdshaderinc").contains(k), "y lee la superficie (%s)" % k)


## Lo que cuesta en la CPU: pedir un material ya hecho (la caché), poner el aspecto de la cetrería al cambiar de garra o
## de material y hacer la malla de una garra del coche (al construir el modelo, que se guarda en la caché). En cada
## fotograma la biblioteca no hace nada.
func test_coste() -> void:
	ClawMaterial.material("acero")
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		ClawMaterial.material("acero")
	var lookup := float(Time.get_ticks_usec() - t0) / 1000.0
	var m := ShaderMaterial.new()
	m.shader = KERATIN
	t0 = Time.get_ticks_usec()
	for i in 100:
		ClawLook.apply(m, ClawLook.params("none" if i % 2 == 0 else "diamante", Color("#2E2A26"), { "light": i % 3 == 0 }))
	var look := float(Time.get_ticks_usec() - t0) / 100.0
	t0 = Time.get_ticks_usec()
	for i in 20:
		ClawGeo.model_claw(40.0, 18.0, 11.0, 126.0, 8, 6, 10)
	var geo := float(Time.get_ticks_usec() - t0) / 20.0
	print("    (info) biblioteca de materiales: material de la caché %s µs · aspecto de la cetrería (params + apply) %s µs · malla de una garra del coche %s µs" % [
		"%.1f" % lookup, "%.0f" % look, "%.0f" % geo])
	assert_true(lookup < 200.0, "pedir un material hecho cuesta poco (%s µs)" % lookup)
	assert_true(look < 3000.0, "poner el aspecto de una garra cabe de sobra en un fotograma (%s µs)" % look)
	assert_true(geo < 5000.0, "la malla de una garra, también (%s µs)" % geo)


## La garra de la galería (ClawGeo.spec_of) gira el arco medido de cada especie (CareData.claw_arc, unidad 5g), el mismo
## que la cetrería: el águila ~124°, el casuario 41° (Pike y Maitland 2004), no las fórmulas de antes (64° el casuario).
func test_la_galeria_usa_el_arco_medido_de_cada_garra() -> void:
	for id: String in ["aguila", "halcon", "tigre", "oso", "casuario", "velociraptor"]:
		var sp := ClawGeo.spec_of(id)
		if sp.is_empty():
			continue
		var arc := float(CareData.claw_arc(id).arcDeg)
		assert_near(float(sp.arc_deg), arc, 1e-9, 1e-9, "%s: el arco de CareData.claw_arc (%s°)" % [id, arc])
		assert_near(float(sp.k), deg_to_rad(arc) / maxf(float(sp.length_mm), 1.0), 1e-9, 1e-12, "%s: la curvatura sale de ese arco" % id)


## Las garras de los animales del coche en marcha giran el mismo arco medido que la cetrería y la galería
## (CareData.claw_arc; unidad 5p), no la fórmula de antes (180°·curva^1,6).
func test_el_coche_usa_el_arco_medido_de_cada_garra() -> void:
	for id: String in ["aguila", "halcon", "buho", "tigre", "oso", "velociraptor"]:
		var cl: Vector2 = Mammals3D.claw_of(id)
		assert_near(cl.y, float(CareData.claw_arc(id).arcDeg), 1e-6, 1e-4, "%s: el arco de CareData.claw_arc (Vector2, en float32)" % id)
	assert_near(Theropod3D.sickle_of("reconstruccion").y, float(CareData.claw_arc("velociraptor").arcDeg), 1e-6, 1e-4, "la hoz del velocirraptor")


## El acrílico dental y la resina (unidad 5p): el sombreado del polímero, con el índice y el cuerpo de claw_optics.gd.
func test_el_acrilico_y_la_resina() -> void:
	for id: String in ["acrilico", "resina"]:
		var p := ClawMaterial.params(id)
		assert_eq(int(p.claw_kind), 4, "%s: un polímero" % id)
		assert_near(float(p.claw_scatter), float(ClawOptics.look(id).scatter), 1e-9, 1e-9, "%s: lo que difunde su cuerpo" % id)
		assert_true((p.claw_ior as Vector3).z > (p.claw_ior as Vector3).x, "%s: dispersión normal" % id)
		assert_true(ClawMaterial.material(id).shader == ClawMaterial.SOLID, "%s: el sombreador opaco (cuerpo translúcido)" % id)
		var look := ClawLook.params(id, Color.WHITE, {})
		assert_eq(float(look.opacity), 1.0, "%s: en la cetrería, opaco" % id)
	var sanded := ClawMaterial.params("acrilico", ClawOptics.finish("limado", 270.0))
	assert_true(float(sanded.claw_frost) > float(ClawMaterial.params("acrilico").claw_frost), "limado, blanquecino como el metacrilato esmerilado")

## Con sonda de reflexión en la sala (Forward+), el entorno dibujado baja en los metales para no sumar dos veces la sala;
## sin sonda, o en una gema (su entorno es lo que refracta), queda entero (unidad 5q).
func test_el_reflejo_dibujado_de_los_metales_con_sonda() -> void:
	var steel := ClawLook.params("acero", Color.WHITE, {})
	assert_eq(float(steel.claw_env_energy), 1.0, "sin sonda, el entorno dibujado entero")
	var steel_probe := ClawLook.params("acero", Color.WHITE, { "probe": true })
	assert_near(float(steel_probe.claw_env_energy), ClawLook.METAL_ENV_WITH_PROBE, 1e-9, 1e-12, "con sonda, el metal baja el entorno dibujado")
	assert_true(float(steel_probe.claw_env_energy) > 0.0 and float(steel_probe.claw_env_energy) < 1.0, "pero no lo apaga (las lámparas no van en la sonda)")
	var dia_probe := ClawLook.params("diamante", Color.WHITE, { "probe": true })
	assert_eq(float(dia_probe.claw_env_energy), 1.0, "una gema con sonda sigue refractando el entorno entero")
	var ker_probe := ClawLook.params("none", Color("#2E2A26"), { "probe": true })
	assert_eq(float(ker_probe.claw_env_energy), 1.0, "y la queratina no cambia")


## Las facetas de una talla en la cetrería: hasta 30 mm de garra, las de la biblioteca (un 20 % del largo); en la hoz del
## velocirraptor, como mucho de ClawLook.FACET_MAX_MM (con ~16 mm salían franjas oscuras en vez de una gema tallada).
func test_las_facetas_de_una_garra_larga() -> void:
	var eagle := ClawLook.params("zafiro", Color.WHITE, { "length_mm": 28.0 })
	assert_eq(float(eagle.claw_facet_mm), -1.0, "una garra de 28 mm, como antes")
	var sickle := ClawLook.params("zafiro", Color.WHITE, { "length_mm": 80.0 })
	assert_eq(float(sickle.claw_facet_mm), ClawLook.FACET_MAX_MM, "la hoz, con facetas de como mucho %s mm" % ClawLook.FACET_MAX_MM)
	assert_eq(float(ClawLook.params("zafiro", Color.WHITE, {}).claw_facet_mm), -1.0, "sin largo, el de la biblioteca")


## La sección comprimida de lado (claw_section_k, unidad del repaso de la calle H): por defecto 1 en la biblioteca, que no
## lo pone nadie más (todas las garras se ven igual al bit: con 1 el sombreador ni toca el radio); la cetrería lo pone en
## la hoz del velocirraptor, y nunca por debajo de 1.
func test_la_seccion_comprimida_solo_en_la_hoz() -> void:
	var inc := FileAccess.get_file_as_string("res://app/common/claw_material.gdshaderinc")
	assert_true(inc.contains("uniform float claw_section_k = 1.0;"), "por defecto, 1")
	assert_true(inc.contains("claw_section_k > 1.0 ? r_mm / sqrt(claw_section_k) : r_mm"), "con 1, el radio de siempre (sin dividir)")
	for id: String in ["zafiro", "diamante", "acero", "none"]:
		assert_false(ClawMaterial.params(id, {}, {}).has("claw_section_k"), "%s: la biblioteca no lo pone" % id)
		assert_false(ClawLook.params(id, Color.WHITE, {}).has("claw_section_k"), "%s: la cetrería, solo si se lo piden" % id)
	assert_eq(float(ClawLook.params("zafiro", Color.WHITE, { "section_k": 2.63 }).claw_section_k), 2.63, "la hoz, con su alto/ancho")
	assert_eq(float(ClawLook.params("zafiro", Color.WHITE, { "section_k": 1.0 }).claw_section_k), 1.0, "las demás, 1 (lo de siempre)")
	assert_eq(float(ClawLook.params("zafiro", Color.WHITE, { "section_k": 0.5 }).claw_section_k), 1.0, "nunca por debajo de 1")
