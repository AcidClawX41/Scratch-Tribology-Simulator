## Óptica de los materiales de las garras (core/lab/claw_optics.gd, unidad 5e). Se comprueba:
##   - que cada material de una garra (Data.INLAYS, la queratina y los de la reforja) tiene sus datos ópticos con fuente;
##   - que los números derivados (DERIVED) salen de los datos medidos con las funciones del módulo (CIE 1931, Planck,
##     IEC 61966-2-1, Beer–Lambert);
##   - la gemología que dan las fuentes: índices, dispersión B–G (diamante 0,044, moissanita 0,104), birrefringencia y
##     ángulo crítico;
##   - el color: el oro amarillo, el acero y el titanio grises con su matiz, el carburo más oscuro, la hematites gris
##     azulada; el rubí rojo, el zafiro azul, el vidrio con su canto verdoso y la moissanita casi incolora; lo incoloro
##     no absorbe;
##   - invariantes: más espesor nunca deja pasar más luz, más índice da más reflejo, más rugosidad nunca da más brillo, un
##     grano más fino nunca pule peor;
##   - los acabados de la reforja y de la cetrería, y qué superficie se ve con cada recubrimiento.
extends "res://tests/case.gd"

const ClawOptics = preload("res://core/lab/claw_optics.gd")
const Data = preload("res://core/lab/data.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

const QUALITIES := ["primary", "secondary", "estimate", "dibujo"]

var _w: Dictionary = {}


func before_each() -> void:
	if _w.is_empty():
		_w = ClawOptics.spectral_weights()


func _mean(v: Variant) -> float:
	var s := 0.0
	for x: Variant in v:
		s += float(x)
	return s / 3.0


func test_cada_material_tiene_sus_datos_con_fuente() -> void:
	var ids: Array = []
	for e: Dictionary in Data.INLAYS:
		ids.append(String(e.id))
	for id: String in ForgeData.NEW_MATERIALS:
		ids.append(id)
	for id: String in ids:
		assert_true(ClawOptics.MATERIALS.has(id), "%s: tiene datos ópticos" % id)
		assert_true(ClawOptics.MATERIAL_IDS.has(id), "%s: está en MATERIAL_IDS" % id)
		assert_true(ClawOptics.DERIVED.has(id), "%s: tiene sus números derivados" % id)
	for id: String in ClawOptics.MATERIAL_IDS + ClawOptics.EXTRA_IDS:
		var m: Dictionary = ClawOptics.MATERIALS[id]
		var fields := 0
		for key: String in ["nk", "reflectance", "index", "absorption", "albedo", "scatter", "color"]:
			if not m.has(key):
				continue
			fields += 1
			var e: Dictionary = m[key]
			assert_true(String(e.get("source", "")).length() > 20, "%s.%s: con fuente" % [id, key])
			assert_true(QUALITIES.has(String(e.get("quality", ""))), "%s.%s: calidad válida (%s)" % [id, key, e.get("quality")])
		assert_true(fields >= 1, "%s: al menos un dato óptico" % id)
		var lk := ClawOptics.look(id)
		assert_eq(String(lk.id), id, "%s: look() lo devuelve" % id)
		assert_true(QUALITIES.has(String(lk.quality)), "%s: calidad del aspecto" % id)
		assert_true(not (lk.sources as Dictionary).is_empty(), "%s: el aspecto lleva sus fuentes" % id)
	assert_true(ClawOptics.look("no_existe").is_empty(), "un id que no existe no tiene aspecto")
	assert_eq(ClawOptics.looks().size(), ClawOptics.MATERIAL_IDS.size(), "looks(): uno por material")


func test_los_numeros_derivados_salen_de_los_datos_medidos() -> void:
	var ch := ClawOptics.channel_wavelengths()
	for i in 3:
		assert_near(ch[i], float(ClawOptics.CHANNEL_NM[i]), 0.0, 0.05, "longitud de onda del canal %d" % i)
	for id: String in ClawOptics.MATERIAL_IDS + ClawOptics.EXTRA_IDS:
		var got := ClawOptics.derive(id, _w)
		var want: Dictionary = ClawOptics.DERIVED[id]
		for key: String in want:
			var wv: Variant = want[key]
			if wv is Array:
				var gv: Variant = got[key]
				assert_eq((gv as Array).size() if gv is Array else (gv as PackedFloat64Array).size(), (wv as Array).size(), "%s.%s: tamaño" % [id, key])
				for i in (wv as Array).size():
					assert_near(float(gv[i]), float(wv[i]), 0.0, 6e-4, "%s.%s[%d]" % [id, key, i])
			else:
				assert_near(float(got[key]), float(wv), 0.0, 0.06 if key == "abbe" else 6e-4, "%s.%s" % [id, key])


func test_la_gemologia_de_las_fuentes() -> void:
	# diamante (Peter 1923; GIA: 2,417 y 0,044) y su ángulo crítico de 24,4°
	assert_near(ClawOptics.refractive_index("diamante", ClawOptics.LAMBDA_D), 2.417, 0.0, 0.001, "n del diamante")
	assert_near(ClawOptics.dispersion_bg("diamante"), 0.044, 0.0, 0.001, "fuego del diamante")
	assert_near(ClawOptics.look("diamante").critical_deg, 24.4, 0.0, 0.1, "ángulo crítico del diamante")
	# Handbook of Mineralogy: n = 2,4354 (486 nm) y 2,4076 (687 nm)
	assert_near(ClawOptics.refractive_index("diamante", 486.0), 2.4354, 0.0, 0.0015, "n del diamante a 486 nm")
	assert_near(ClawOptics.refractive_index("diamante", 687.0), 2.4076, 0.0, 0.0015, "n del diamante a 687 nm")
	# moissanita (Nassau et al. 1997): 2,648 y 2,691, birrefringencia 0,043, dispersión 0,104
	assert_near(ClawOptics.refractive_index("moissanita", ClawOptics.LAMBDA_D), 2.648, 0.0, 1e-6, "n_o de la moissanita")
	assert_near(ClawOptics.refractive_index("moissanita", ClawOptics.LAMBDA_D, "e"), 2.691, 0.0, 1e-6, "n_e de la moissanita")
	assert_near(ClawOptics.birefringence("moissanita"), 0.043, 0.0, 1e-6, "birrefringencia de la moissanita")
	assert_near(ClawOptics.dispersion_bg("moissanita"), 0.104, 0.0, 1e-6, "fuego de la moissanita")
	assert_true(ClawOptics.dispersion_bg("moissanita") > 2.0 * ClawOptics.dispersion_bg("diamante"), "la moissanita tiene más del doble de fuego que el diamante")
	# corindón (Malitson & Dodge 1972; HoM: ω 1,767-1,772, ε 1,759-1,763; GIA: dispersión 0,018)
	for id: String in ["zafiro", "rubi", "zafiro_incoloro"]:
		var no := ClawOptics.refractive_index(id, ClawOptics.LAMBDA_D)
		var ne := ClawOptics.refractive_index(id, ClawOptics.LAMBDA_D, "e")
		assert_true(no >= 1.767 and no <= 1.772, "%s: n_o en la banda del HoM (%s)" % [id, no])
		assert_true(ne >= 1.759 and ne <= 1.763, "%s: n_e en la banda del HoM (%s)" % [id, ne])
		assert_true(ClawOptics.birefringence(id) < 0.0, "%s: uniáxico negativo" % id)
		assert_near(ClawOptics.dispersion_bg(id), 0.018, 0.0, 0.001, "%s: dispersión" % id)
	# cuarzo (Ghosh 1999; HoM: ω 1,544, ε 1,553; dispersión 0,013) y circonita (Nassau 1981: 0,058-0,066)
	assert_near(ClawOptics.refractive_index("cuarzo", ClawOptics.LAMBDA_D), 1.544, 0.0, 0.001, "n_o del cuarzo")
	assert_near(ClawOptics.refractive_index("cuarzo", ClawOptics.LAMBDA_D, "e"), 1.553, 0.0, 0.001, "n_e del cuarzo")
	assert_true(ClawOptics.birefringence("cuarzo") > 0.0, "el cuarzo es uniáxico positivo")
	assert_near(ClawOptics.dispersion_bg("cuarzo"), 0.013, 0.0, 0.001, "dispersión del cuarzo")
	var cz := ClawOptics.dispersion_bg("circonita")
	assert_true(cz >= 0.058 and cz <= 0.066, "dispersión de la circonita en la banda de Nassau (%s)" % cz)
	# el cristal al plomo: n_D ≥ 1,545 (directiva 69/493/CEE)
	assert_true(ClawOptics.refractive_index("swarovski", ClawOptics.LAMBDA_D) >= 1.545, "el cristal Swarovski cumple el índice del cristal al plomo")
	# la queratina de ave (Leertouwer et al. 2011): 1,569, 1,556 y 1,548 a 400, 500 y 600 nm
	assert_near(ClawOptics.refractive_index("none", 400.0), 1.569, 0.0, 0.002, "queratina a 400 nm")
	assert_near(ClawOptics.refractive_index("none", 500.0), 1.556, 0.0, 0.002, "queratina a 500 nm")
	assert_near(ClawOptics.refractive_index("none", 600.0), 1.548, 0.0, 0.002, "queratina a 600 nm")
	# los isótropos no tienen rayo extraordinario
	for id: String in ["diamante", "circonita", "vidrio", "swarovski", "none"]:
		assert_eq(ClawOptics.birefringence(id), 0.0, "%s: isótropo" % id)
		assert_true(ClawOptics.channel_indices(id, "e").is_empty(), "%s: sin rayo e" % id)
	# el índice crece hacia el azul (dispersión normal) en todos los transparentes
	for id: String in ClawOptics.MATERIAL_IDS:
		var ior: Array = ClawOptics.look(id).ior
		if ior.is_empty():
			continue
		assert_true(float(ior[0]) < float(ior[1]) and float(ior[1]) < float(ior[2]), "%s: n(rojo) < n(verde) < n(azul)" % id)


func test_el_color_de_los_metales_y_la_hematites() -> void:
	var gold: Array = ClawOptics.DERIVED.oro.f0
	assert_true(float(gold[0]) > 0.95 and float(gold[2]) < 0.45 and float(gold[0]) > float(gold[1]) and float(gold[1]) > float(gold[2]), "el oro es amarillo: %s" % [gold])
	var steel: Array = ClawOptics.DERIVED.acero.f0
	var ti: Array = ClawOptics.DERIVED.titanio.f0
	var wc: Array = ClawOptics.DERIVED.tungsteno.f0
	for c: Array in [steel, ti]:
		assert_true(float(c[0]) / float(c[2]) < 1.2 and float(c[0]) / float(c[2]) > 1.0, "acero y titanio: grises con un matiz cálido leve (%s)" % [c])
	assert_true(_mean(wc) < _mean(steel) - 0.1 and _mean(wc) < _mean(ti) - 0.1, "el carburo de tungsteno es más oscuro que el acero y el titanio")
	var hem: Array = ClawOptics.DERIVED.hematites.f0
	assert_true(_mean(hem) < 0.35 and float(hem[2]) > float(hem[0]), "la hematites refleja poco y con un tinte azulado (%s)" % [hem])
	var tin: Array = ClawOptics.DERIVED.tin.f0
	assert_true(float(tin[0]) > float(tin[1]) and float(tin[1]) > float(tin[2]) and float(tin[2]) < 0.25, "el nitruro de titanio es dorado (%s)" % [tin])
	var cr: Array = ClawOptics.DERIVED.cromo.f0
	assert_true(absf(float(cr[0]) - float(cr[2])) < 0.02, "el cromo es neutro (%s)" % [cr])
	# un metal refleja mucho más que cualquier gema
	for id: String in ["oro", "acero", "titanio", "tungsteno"]:
		assert_true(ClawOptics.look(id).metallic, "%s: metálico" % id)
		assert_true(_mean(ClawOptics.look(id).f0) > _mean(ClawOptics.look("moissanita").f0), "%s refleja más que la moissanita" % id)
	# recortado a 1 para la escena (el oro pasa de 1 en el rojo antes de recortar)
	assert_eq(float(ClawOptics.look("oro").f0[0]), 1.0, "el F0 del oro se recorta a 1")


func test_el_color_de_lo_transparente() -> void:
	var ruby: Array = ClawOptics.look("rubi").absorption
	assert_true(float(ruby[1]) > float(ruby[2]) and float(ruby[2]) > float(ruby[0]), "rubí: absorbe sobre todo el verde y deja pasar el rojo (%s)" % [ruby])
	var sap: Array = ClawOptics.look("zafiro").absorption
	assert_true(float(sap[0]) > float(sap[1]) and float(sap[1]) > float(sap[2]), "zafiro: absorbe el rojo y el amarillo, deja pasar el azul (%s)" % [sap])
	var glass: Array = ClawOptics.look("vidrio").absorption
	assert_true(float(glass[1]) < float(glass[0]) and float(glass[1]) < float(glass[2]), "vidrio: el canto verdoso del hierro (%s)" % [glass])
	var tint: Array = ClawOptics.look("moissanita").tint
	assert_true(float(tint[2]) < float(tint[0]) and float(tint[0]) <= 1.0 and float(tint[1]) <= 1.0, "moissanita: sin el violeta, un matiz amarillento leve (%s)" % [tint])
	assert_true(float(tint[2]) > 0.85, "moissanita: casi incolora")
	for id: String in ["diamante", "circonita", "cuarzo", "swarovski", "zafiro_incoloro", "alumina"]:
		assert_eq(_mean(ClawOptics.look(id).absorption), 0.0, "%s: incoloro" % id)
	# el rubí: el ajuste de 1 y 10 mm predice el color medido a 5 mm (Yuan et al. 2022)
	for ray: String in ["o", "e"]:
		var rows: Array = ClawOptics.RUBY_LAB[ray]
		var t1 := ClawOptics.lab_to_linear_rgb(rows[0][1], rows[0][2], rows[0][3])
		var t5 := ClawOptics.lab_to_linear_rgb(rows[1][1], rows[1][2], rows[1][3])
		var t10 := ClawOptics.lab_to_linear_rgb(rows[2][1], rows[2][2], rows[2][3])
		var a := ClawOptics.fit_absorption(t1, 1.0, t10, 10.0)
		for i in 3:
			var pred := t1[i] * exp(-a[i] * 4.0)
			assert_near(pred, t5[i], 0.0, maxf(0.02, 0.15 * t5[i]), "rubí, rayo %s, canal %d a 5 mm" % [ray, i])
	# el zafiro: con los pares de la ficha, 10 mm dejan pasar sobre todo el azul
	var f := func(nm: float) -> float: return ClawOptics.sapphire_alpha_mm(nm, float(ClawOptics.SAPPHIRE_FETI_PPMA.value))
	var t := ClawOptics.transmittance_rgb(f, 10.0, _w)
	assert_true(t[2] > 0.6 and t[0] < 0.4, "zafiro de 10 mm: azul (%s)" % [t])
	# su pico E⊥c digitalizado, dentro del ±25 % del texto (1,94·10⁻¹⁸ cm² a 580 nm)
	assert_near(float(ClawOptics.FETI_PERP[24]) * 1e-18, 1.94e-18, 0.25, 0.0, "pico del par Fe-Ti a 580 nm")


func test_mas_espesor_nunca_deja_pasar_mas_luz() -> void:
	var cases: Array = [
		func(nm: float) -> float: return ClawOptics.sapphire_alpha_mm(nm, 6.0),
		func(nm: float) -> float: return 4.0 * PI * ClawOptics.table_at(ClawOptics.K_SODA_LIME, nm) / (nm * 1.0e-6),
	]
	for f: Callable in cases:
		var prev := ClawOptics.transmittance_rgb(f, 0.0, _w)
		for i in 3:
			assert_near(prev[i], 1.0, 0.0, 1e-9, "sin espesor no se absorbe nada")
		for d: float in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 40.0]:
			var t := ClawOptics.transmittance_rgb(f, d, _w)
			for i in 3:
				assert_true(t[i] <= prev[i] + 1e-12, "más espesor (%s mm) no deja pasar más luz en el canal %d" % [d, i])
			prev = t
	# y más pares Fe-Ti, más azul y más oscuro
	var lo := ClawOptics.transmittance_rgb(func(nm: float) -> float: return ClawOptics.sapphire_alpha_mm(nm, 3.0), 10.0, _w)
	var hi := ClawOptics.transmittance_rgb(func(nm: float) -> float: return ClawOptics.sapphire_alpha_mm(nm, 9.0), 10.0, _w)
	for i in 3:
		assert_true(hi[i] < lo[i], "más pares absorben más (canal %d)" % i)


func test_el_reflejo_de_fresnel() -> void:
	for n: float in [1.33, 1.5, 1.77, 2.17, 2.42, 2.65]:
		assert_near(ClawOptics.fresnel(1.0, n), ClawOptics.normal_reflectance(n), 1e-12, 1e-15, "Fresnel a incidencia normal (n %s)" % n)
		var prev := ClawOptics.fresnel(1.0, n)
		for k in range(1, 10):
			var c := 1.0 - float(k) / 10.0
			var fr := ClawOptics.fresnel(c, n)
			assert_true(fr >= 0.0 and fr <= 1.0, "Fresnel entre 0 y 1")
			assert_true(fr >= prev - 0.02, "el reflejo sube hacia el roce (n %s, cos %s)" % [n, c])
			prev = maxf(prev, fr)
		assert_near(ClawOptics.fresnel(0.0, n), 1.0, 0.0, 1e-9, "en el roce se refleja todo")
	# más índice, más reflejo: diamante > circonita > zafiro > vidrio > queratina
	var order := ["moissanita", "diamante", "circonita", "zafiro", "swarovski", "vidrio"]
	for i in range(1, order.size()):
		assert_true(_mean(ClawOptics.look(order[i - 1]).f0) > _mean(ClawOptics.look(order[i]).f0), "%s refleja más que %s" % [order[i - 1], order[i]])
	assert_near(_mean(ClawOptics.look("diamante").f0), 0.172, 0.0, 0.002, "el diamante refleja un 17 % de frente")


func test_los_acabados() -> void:
	# más rugosidad nunca da más brillo (Bennett & Porteus)
	var prev := 2.0
	for s: float in [0.0, 0.001, 0.005, 0.02, 0.05, 0.1, 0.3, 1.0, 3.0]:
		var g := ClawOptics.specular_fraction(s)
		assert_true(g <= prev, "más rugosidad (%s µm), menos brillo" % s)
		prev = g
	assert_near(ClawOptics.specular_fraction(0.0), 1.0, 0.0, 1e-12, "una superficie ideal es un espejo")
	# un grano más fino nunca pule peor (los de pulir de la reforja, de grueso a fino)
	var last := -1.0
	for g: float in ForgeData.POLISH_GRITS:
		var f := ClawOptics.finish("pulido", g)
		assert_true(float(f.gloss) >= last, "pulir con %s µm no deja menos brillo que con el anterior" % g)
		last = float(f.gloss)
	assert_true(float(ClawOptics.finish("pulido").gloss) > 0.98, "el pulido de espejo es especular")
	assert_true(float(ClawOptics.finish("tallado").gloss) < 0.01, "tallado con la muela de 91 µm: mate")
	assert_true(bool(ClawOptics.finish("tallado").facets), "lo tallado lleva facetas")
	# los acabados de la reforja: todos conocidos
	for id: String in ForgeData.FINISH_IDS:
		var f := ClawOptics.finish_from_forge(id)
		assert_eq(String(f.id), id, "acabado de la reforja %s" % id)
		assert_true(float(f.sigma_um) > 0.0 and String(f.source) != "", "%s: con su rugosidad y su fuente" % id)
	assert_eq(String(ClawOptics.finish("no_existe").id), "pulido", "un acabado desconocido es el pulido")
	# los metales pulidos o en bruto no tienen facetas; las gemas talladas sí
	assert_false(bool(ClawOptics.finish_from_forge("pulido", null, "acero").facets), "acero pulido: sin facetas")
	assert_true(bool(ClawOptics.finish_from_forge("pulido", null, "diamante").facets), "diamante pulido: facetado")
	assert_false(bool(ClawOptics.default_finish("oro").facets), "oro por defecto: sin facetas")
	assert_true(bool(ClawOptics.default_finish("rubi").facets), "rubí por defecto: tallado y pulido")


func test_el_acabado_de_la_cetreria() -> void:
	var snap := { "inlay": "zafiro", "claw": { "removedMm3": 0.0 }, "damage": { "chips": 0 } }
	assert_eq(String(ClawOptics.finish_from_care(snap).id), "pulido", "sin trabajar: el pulido por defecto")
	snap.claw.removedMm3 = 2.5
	var f := ClawOptics.finish_from_care(snap, 25.0)
	assert_eq(String(f.id), "limado", "limado con la lima de diamante de 25 µm")
	assert_near(float(f.sigma_um), 25.0 * float(ClawOptics.GRAIN_SIGMA_RATIO.value), 1e-12, 0.0, "su rugosidad")
	assert_true(bool(f.facets), "conserva las facetas de la talla")
	snap.claw.removedMm3 = 0.0
	snap.damage.chips = 2
	f = ClawOptics.finish_from_care(snap)
	assert_eq(String(f.id), "mellado", "la punta mellada")
	assert_eq(int(f.chips), 2, "con sus mellas")
	var base := ClawOptics.finish_from_forge("tallado")
	snap.damage.chips = 0
	assert_eq(String(ClawOptics.finish_from_care(snap, null, base).id), "tallado", "la garra que viene de la reforja conserva su acabado")


func test_que_se_ve_de_una_garra_de_la_reforja() -> void:
	var rc := { "inlay": "zafiro", "finish": "pulido", "coating": null }
	assert_eq(String(ClawOptics.forge_surface(rc).material), "zafiro", "sin capa, la funda")
	assert_eq(String(ClawOptics.forge_surface(rc, "zafiro sintético incoloro").material), "zafiro_incoloro", "el zafiro de Verneuil es incoloro")
	assert_eq(String(ClawOptics.optical_id("rubi", "rubí")), "rubi", "el rubí, rubí")
	rc.coating = { "material": "tin", "thicknessUm": 2.0, "porosity": 0.0 }
	var s := ClawOptics.forge_surface(rc)
	assert_eq(String(s.material), "tin", "una capa de TiN de 2 µm tapa la funda")
	assert_true(float(s.coat.opaqueUm) < 0.2, "3δ del TiN, por debajo de 0,2 µm (%s)" % s.coat.opaqueUm)
	rc.coating = { "material": "alumina", "thicknessUm": 0.0332, "porosity": 0.0 }
	s = ClawOptics.forge_surface(rc)
	assert_eq(String(s.material), "zafiro", "la alúmina de capas atómicas no se ve")
	assert_false(bool(s.coat.clear), "ni añade brillo")
	rc.coating = { "material": "alumina", "thicknessUm": 2.0, "porosity": 0.0 }
	s = ClawOptics.forge_surface(rc)
	assert_eq(String(s.material), "zafiro", "la alúmina densa de 2 µm deja ver la funda")
	assert_true(bool(s.coat.clear), "y añade su brillo")
	rc.coating = { "material": "alumina", "thicknessUm": 300.0, "porosity": 0.04 }
	assert_eq(String(ClawOptics.forge_surface(rc).material), "alumina", "la alúmina porosa de plasma tapa la funda")
	assert_true(ClawOptics.skin_depth_um(0.0) == INF, "sin absorción la luz no se apaga")


## El acrílico dental y la resina (unidad 5p): el índice del PMMA medido (Sultanova et al. 2009), un cuerpo translúcido
## de su color (dibujo) y sin facetas, ni de serie ni al salir de la reforja.
func test_el_acrilico_y_la_resina() -> void:
	var ac := ClawOptics.look("acrilico")
	var rs := ClawOptics.look("resina")
	assert_eq(String(ac.family), "polimero", "el acrílico, un polímero")
	assert_eq(String(rs.family), "polimero", "la resina, también")
	assert_near(float(ac.n_d), 1.4905, 0.0, 0.0005, "el índice del PMMA a 589 nm (Sultanova et al. 2009)")
	assert_near(float(ac.critical_deg), 42.1, 0.0, 0.1, "su ángulo crítico")
	assert_false(bool(ac.transparent) or bool(ac.metallic), "ni transparente como una gema ni metálico")
	assert_true(_mean(ac.f0) < _mean(ClawOptics.look("none").f0), "refleja algo menos que la queratina (1,49 frente a 1,55)")
	assert_true(float(rs.scatter) < float(ac.scatter) and float(rs.scatter) > 0.0, "la resina, más translúcida que el acrílico de color diente")
	assert_eq((ac.albedo as Array).size(), 3, "el acrílico, con el color de su cuerpo")
	assert_false(bool(ClawOptics.default_finish("acrilico").facets), "de serie, sin facetas")
	for f: String in ["pulido", "tallado", "bruto"]:
		assert_false(bool(ClawOptics.finish_from_forge(f, null, "acrilico").facets), "%s en la reforja: sin facetas (se moldea y se lima)" % f)


func test_determinista() -> void:
	assert_eq(ClawOptics.look("rubi"), ClawOptics.look("rubi"), "el aspecto no cambia de una llamada a otra")
	assert_eq(ClawOptics.derive("oro", _w), ClawOptics.derive("oro", ClawOptics.spectral_weights()), "derivar es determinista")
	assert_eq(ClawOptics.finish_from_forge("tallado"), ClawOptics.finish_from_forge("tallado"), "los acabados también")
