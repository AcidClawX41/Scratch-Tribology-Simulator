## Taller · la radial contra chapa y carrocería (cut_panel): coches del laboratorio y piezas de rescate.
extends "res://tests/case.gd"

const Panels = preload("res://core/taller/panels.gd")
const Radial = preload("res://core/taller/radial.gd")
const Sparks = preload("res://core/taller/sparks.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Chips = preload("res://core/taller/chips.gd")

const QUALITIES := ["primary", "secondary", "estimate"]
const BASE := { "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 0.0,
	"panel_id": "acero-dulce", "cut_length_mm": 100.0 }

var lab: Dictionary


func before_each() -> void:
	if lab.is_empty():
		lab = load_json("res://tests/fixtures/lab-data.json")


func test_paneles_de_coche_iguales_que_el_motor_1x() -> void:
	var d1 := oracle_diff(Panels.PAINT_LAYERS, lab["PAINT_LAYERS"], "PAINT_LAYERS")
	assert_eq(d1, [], "capas de pintura de data.js")
	var d2 := oracle_diff(Panels.CAR_BODIES, lab["CAR_BODIES"], "CAR_BODIES")
	assert_eq(d2, [], "carrocerías de data.js")
	# Cada carrocería del laboratorio es un panel con el mismo id, espesor, dureza y módulo
	for key in lab["CAR_BODIES"]:
		var body: Dictionary = lab["CAR_BODIES"][key]
		var p := Panels.get_panel(body["id"])
		assert_false(p.is_empty(), "panel «%s»" % body["id"])
		assert_eq(p["lab_body"], key, "%s sale de CAR_BODIES.%s" % [body["id"], key])
		assert_near(p["t_mm"], float(body["t"]) / 1000.0, 1e-12, 0.0, "%s: espesor" % body["id"])
		assert_eq(p["hv"], float(body["hv"]), "%s: dureza" % body["id"])
		assert_eq(p["e_gpa"], float(body["E"]), "%s: módulo" % body["id"])
		assert_eq(p["paint_um"], float(lab["PAINT_LAYERS"][-1]["to"]), "%s: lleva la pintura OEM entera" % body["id"])
	assert_near(Panels.get_panel("acero-dulce")["t_mm"], 0.9, 1e-12, 0.0, "acero dulce de 0,9 mm")
	assert_near(Panels.get_panel("acero-bh")["t_mm"], 0.7, 1e-12, 0.0, "acero BH de 0,7 mm")
	assert_near(Panels.get_panel("aluminio")["t_mm"], 1.0, 1e-12, 0.0, "aluminio de 1,0 mm")
	assert_near(Panels.get_panel("plastico-carroceria")["t_mm"], 2.5, 1e-12, 0.0, "plástico de ~2,5 mm")


func test_paneles_de_rescate() -> void:
	for id in ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria", "boro-22mnb5", "dp800"]:
		assert_true(Panels.PANELS.has(id), "panel «%s» del contrato (CONTRATOS.md)" % id)
	var boro := Panels.get_panel("boro-22mnb5")
	assert_eq(boro["rm_mpa"], 1500.0, "Usibor 1500: Rm 1.500 MPa (ArcelorMittal)")
	assert_true(boro["hv"] >= 460.0 and boro["hv"] <= 500.0, "~470-500 HV")
	assert_true(boro["t_mm"] >= 1.2 and boro["t_mm"] <= 1.8, "pilar de 1,2-1,8 mm")
	assert_true(String(boro["source"]).contains("ArcelorMittal"), "fuente de fabricante")
	assert_true(boro["press_hardened"], "estampado en caliente")
	var dp := Panels.get_panel("dp800")
	assert_true(String(dp["source"]).contains("SSAB") and dp["rm_mpa"] == 800.0, "DP800 de SSAB")
	var alu := Panels.get_panel("perfil-aluminio")
	assert_true(String(alu["source"]).contains("Hydro") and alu["kind"] == "aluminio", "perfil de aluminio de Hydro")
	for id in Panels.PANELS:
		var p := Panels.get_panel(id)
		assert_true(String(p["source"]).length() > 40 and QUALITIES.has(p["quality"]), "panel %s con fuente y calidad" % id)
		assert_true(String(p["cite"]).length() > 10, "panel %s con cita corta" % id)
		assert_true(Panels.THERMAL.has(p["thermal"]) and Panels.SPARK_CLASSES.has(p["spark"]), "panel %s: datos térmicos y de chispa" % id)
		assert_true(p["t_mm"] > 0.0 and p["hv"] > 0.0 and p["burr_factor"] > 0.0, "panel %s: espesor, dureza y rebaba" % id)
		assert_eq(p["press_hardened"], id == "boro-22mnb5", "panel %s: estampado en caliente o no" % id)
	for fam in Panels.THERMAL:
		var th: Dictionary = Panels.THERMAL[fam]
		assert_true(String(th["source"]).length() > 20 and QUALITIES.has(th["quality"]), "térmica %s con fuente" % fam)
		assert_true(th["t_soft_c"] < th["t_edge_c"] and Radial.HAZ_T_C < th["t_edge_c"], "térmica %s: umbrales por debajo del borde" % fam)
		assert_true(float(th["alpha_k"]) > 0.0 and String(th["cite"]).length() > 5, "térmica %s: dilatación y cita" % fam)
	for id in Panels.SPARK_CLASSES:
		var sc: Dictionary = Panels.SPARK_CLASSES[id]
		assert_true(String(sc["source"]).length() > 20 and QUALITIES.has(sc["quality"]), "chispa %s con fuente" % id)
		assert_true(String(sc["cite"]).length() > 5, "chispa %s con cita corta" % id)
	assert_true(Panels.TEMPER_SOURCE.contains("BSSA"), "fuente de los colores de revenido")


func test_contrato_de_salida() -> void:
	var r := Radial.cut_panel(BASE)
	var types := {
		"vs_ms": TYPE_FLOAT, "over_speed": TYPE_BOOL, "time_s": TYPE_FLOAT, "kerf_mm": TYPE_FLOAT, "burr_um": TYPE_FLOAT,
		"haz_mm": TYPE_FLOAT, "heat_tint": TYPE_DICTIONARY, "paint_burn_mm": TYPE_FLOAT, "sparks": TYPE_DICTIONARY,
		"disc_wear_mm3": TYPE_FLOAT, "disc_loading": TYPE_FLOAT, "deformation": TYPE_FLOAT, "cleanliness": TYPE_FLOAT,
		"warnings": TYPE_ARRAY, "quality": TYPE_STRING, "sources": TYPE_ARRAY,
		"smoke": TYPE_FLOAT, "melt": TYPE_FLOAT, "burr_sides_um": TYPE_DICTIONARY, "front_temp_c": TYPE_FLOAT,
	}
	for k in types:
		assert_true(r.has(k), "campo «%s» del contrato" % k)
		assert_eq(typeof(r[k]), types[k], "tipo de «%s»" % k)
	for k in ["temp_c", "color"]:
		assert_true(r["heat_tint"].has(k), "heat_tint.%s" % k)
	for k in ["rate", "color", "length_mm", "bursts"]:
		assert_true(r["sparks"].has(k), "sparks.%s" % k)
	for k in ["lado_menos", "lado_mas"]:
		assert_true(r["burr_sides_um"].has(k), "burr_sides_um.%s" % k)
	for w in r["warnings"]:
		assert_true(w.has("code") and w.has("message") and w.has("source"), "aviso con código, texto y fuente")
	assert_true(r["cleanliness"] >= 0.0 and r["cleanliness"] <= 10.0, "limpieza entre 0 y 10")
	assert_true(r["disc_loading"] >= 0.0 and r["disc_loading"] <= 1.0, "embotamiento entre 0 y 1")
	assert_true(r["smoke"] >= 0.0 and r["smoke"] <= 1.0 and r["melt"] >= 0.0 and r["melt"] <= 1.0, "humo y fundido entre 0 y 1")
	assert_eq(r["quality"], "estimate", "el modelo del corte es una estimación")
	assert_true(r["sources"].size() >= 3, "cita sus fuentes")
	assert_true(same(r, Radial.cut_panel(BASE)), "determinista: la misma entrada da la misma salida")
	var none := Radial.cut_panel(_with({ "panel_id": "no-existe" }))
	assert_eq(none["warnings"][0]["code"], "sin_datos", "panel desconocido: aviso y salida vacía")
	for k in r:
		assert_true(none.has(k), "la salida vacía conserva el campo «%s»" % k)


## Las citas cortas de cada panel, su familia térmica y su clase de chispa, enteras (sin cortar por un punto).
func test_fuentes_enteras() -> void:
	for id in Panels.PANELS:
		var r := Radial.cut_panel(_with({ "panel_id": id }))
		var p := Panels.get_panel(id)
		var sources: Array = r["sources"]
		assert_true(sources.has(p["cite"]), "%s: cita su panel" % id)
		assert_true(sources.has(Panels.THERMAL[p["thermal"]]["cite"]), "%s: cita sus datos térmicos" % id)
		# Fase 2: las chispas salen de una sola fuente, el ensayo de chispas del TC 9-237 de core/taller/sparks.gd
		assert_true(sources.has(Sparks.CITE), "%s: cita el ensayo de chispas" % id)
		for s in sources:
			assert_eq(String(s).count("("), String(s).count(")"), "%s: cita sin cortar «%s»" % [id, s])
			assert_eq(String(s).count("«"), String(s).count("»"), "%s: comillas cerradas en «%s»" % [id, s])


func test_disco_fino_menos_rebaba_menos_zona_afectada_y_mas_rapido() -> void:
	for id in ["acero-dulce", "acero-bh", "dp800", "boro-22mnb5", "aluminio"]:
		var fine := Radial.cut_panel(_with({ "panel_id": id, "disc_id": "fino_1mm" }))
		var thick := Radial.cut_panel(_with({ "panel_id": id, "disc_id": "grueso_3mm" }))
		assert_true(fine["kerf_mm"] < thick["kerf_mm"], "%s: surco más estrecho" % id)
		assert_true(fine["burr_um"] < thick["burr_um"], "%s: menos rebaba con el disco fino" % id)
		assert_true(fine["haz_mm"] < thick["haz_mm"], "%s: menos zona afectada" % id)
		assert_true(fine["heat_j_mm"] < thick["heat_j_mm"], "%s: menos calor por mm de corte" % id)
		assert_true(fine["deformation"] < thick["deformation"], "%s: menos deformación" % id)
		assert_true(fine["time_s"] < thick["time_s"], "%s: corta antes" % id)
		assert_true(fine["cleanliness"] <= thick["cleanliness"], "%s: corte igual o más limpio" % id)
	var dc := Radial.cut_panel(_with({ "disc_id": "fino_1mm" }))
	assert_near(dc["kerf_mm"], 1.4, 1e-12, 0.0, "un disco de 1 mm abre ~1,4 mm (Awan et al. 2022: 1,3-1,5)")


## haz_mm llega hasta 200 °C: más ancha que la pintura quemada (250 °C) y que el primer color de revenido (216 °C).
func test_zona_afectada_hasta_200_grados() -> void:
	for id in ["acero-dulce", "boro-22mnb5", "aluminio", "plastico-carroceria"]:
		var r := Radial.cut_panel(_with({ "panel_id": id }))
		assert_true(r["haz_mm"] > 0.0, "%s: zona afectada" % id)
		assert_true(r["haz_mm"] >= r["heat_tint"]["width_mm"], "%s: 200 °C llega más lejos que 216 °C" % id)
		if r["paint_burn_mm"] > 0.0:
			assert_true(r["haz_mm"] > r["paint_burn_mm"], "%s: y más lejos que la pintura quemada a 250 °C" % id)
		var th: Dictionary = Panels.THERMAL[Panels.get_panel(id)["thermal"]]
		assert_eq(r["heat_tint"]["temp_c"], th["t_edge_c"], "%s: temp_c es el pico en el borde del surco" % id)
		assert_eq(r["front_temp_c"], th["t_edge_c"], "%s: el frente del corte, a la temperatura de la pared" % id)


func test_mas_angulo_surco_mas_ancho_y_mas_rebaba() -> void:
	var prev := Radial.cut_panel(_with({ "angle_deg": 0.0 }))
	assert_eq(prev["burr_side"], "ambos", "perpendicular: rebaba a los dos lados")
	assert_eq(prev["burr_sides_um"]["lado_menos"], prev["burr_sides_um"]["lado_mas"], "perpendicular: la misma a cada lado")
	assert_false(_codes(prev["warnings"]).has("acunamiento"), "perpendicular: sin aviso de acuñamiento")
	for ang in [5.0, 15.0, 30.0]:
		var r := Radial.cut_panel(_with({ "angle_deg": ang }))
		assert_eq(r["kerf_mm"], prev["kerf_mm"], "a %s° el surco medido en perpendicular al disco no cambia" % ang)
		assert_true(r["kerf_surface_mm"] > prev["kerf_surface_mm"], "a %s° el surco es más ancho en la chapa" % ang)
		assert_near(r["kerf_surface_mm"], r["kerf_mm"] / cos(deg_to_rad(ang)), 1e-12, 0.0, "kerf / cos θ")
		assert_true(r["burr_um"] > prev["burr_um"], "a %s° hay más rebaba" % ang)
		assert_true(r["burr_sides_um"]["lado_menos"] > r["burr_sides_um"]["lado_mas"], "a %s° la rebaba de más, del lado de la arista aguda (−)" % ang)
		assert_near(r["burr_um"], 0.5 * (r["burr_sides_um"]["lado_menos"] + r["burr_sides_um"]["lado_mas"]), 1e-9, 0.0, "burr_um es la media")
		assert_eq(r["burr_side"], "un_lado", "a %s° la rebaba sale a un lado" % ang)
		assert_true(_codes(r["warnings"]).has("acunamiento"), "a %s° aviso de acuñamiento y rebote" % ang)
		prev = r
	var neg := Radial.cut_panel(_with({ "angle_deg": -15.0 }))
	var pos := Radial.cut_panel(_with({ "angle_deg": 15.0 }))
	assert_near(neg["kerf_surface_mm"], pos["kerf_surface_mm"], 1e-12, 0.0, "el signo del ángulo solo cambia el lado")
	assert_eq(neg["burr_sides_um"]["lado_mas"], pos["burr_sides_um"]["lado_menos"], "con el ángulo negativo, la rebaba mayor pasa al lado +")


func test_aluminio_con_corindon_se_embota() -> void:
	var std := Radial.cut_panel(_with({ "panel_id": "aluminio", "disc_id": "fino_1mm" }))
	assert_true(std["disc_loading"] >= 0.4, "disco de corindón en aluminio: se embota")
	assert_true(_codes(std["warnings"]).has("embotamiento"), "aviso de embotamiento")
	assert_true(_codes(std["warnings"]).has("disco_inadecuado"), "y de disco inadecuado")
	assert_true(_codes(std["warnings"]).has("polvo_aluminio"), "y del polvo de aluminio")
	var alu := Radial.cut_panel(_with({ "panel_id": "aluminio", "disc_id": "corte_alu" }))
	assert_true(alu["disc_loading"] < std["disc_loading"], "el disco para aluminio se embota menos")
	assert_false(_codes(alu["warnings"]).has("embotamiento"), "sin aviso de embotamiento")
	assert_false(_codes(alu["warnings"]).has("disco_inadecuado"), "es su disco")
	assert_true(alu["cleanliness"] < std["cleanliness"], "corte más limpio con el disco adecuado")
	assert_true(std["specific_energy_j_mm3"] > alu["specific_energy_j_mm3"], "embotado pide más energía (Rowe: +40 %)")
	var steel := Radial.cut_panel(_with({ "disc_id": "fino_1mm" }))
	assert_eq(steel["disc_loading"], 0.0, "en acero el corindón no se embota")


func test_diamante_sobre_acero_avisa_y_se_gasta() -> void:
	var dia := Radial.cut_panel(_with({ "disc_id": "diamante" }))
	var al := Radial.cut_panel(_with({ "disc_id": "fino_1mm" }))
	assert_true(_codes(dia["warnings"]).has("diamante_ferrico"), "aviso de diamante sobre acero")
	assert_true(dia["glazing"], "el disco se vidria")
	assert_true(dia["disc_wear_mm3"] > 5.0 * al["disc_wear_mm3"], "se gasta mucho más que el corindón")
	var warn: Dictionary = dia["warnings"][_codes(dia["warnings"]).find("diamante_ferrico")]
	assert_true(String(warn["source"]).contains("Komanduri"), "cita a Komanduri y Shaw")
	for id in ["dp800", "boro-22mnb5"]:
		assert_true(_codes(Radial.cut_panel(_with({ "panel_id": id, "disc_id": "diamante_turbo" }))["warnings"]).has("diamante_ferrico"), "%s: aviso" % id)
	assert_false(_codes(Radial.cut_panel(_with({ "panel_id": "perfil-aluminio", "disc_id": "diamante_turbo" }))["warnings"]).has("diamante_ferrico"), "en aluminio no es el aviso del hierro")
	# El SiC también reacciona con el hierro: en acero se gasta más que el corindón (por mm³ de surco)
	var sic := Radial.cut_panel(_with({ "disc_id": "corte_sic" }))
	assert_true(_codes(sic["warnings"]).has("sic_ferrico"), "aviso del SiC sobre acero")
	assert_true(sic["disc_wear_mm3"] / sic["kerf_surface_mm"] > al["disc_wear_mm3"] / al["kerf_surface_mm"], "el SiC se gasta más en acero")


func test_plastico_se_funde_sin_chispas() -> void:
	for disc in ["fino_1mm", "corte_sic", "grueso_3mm"]:
		var r := Radial.cut_panel(_with({ "panel_id": "plastico-carroceria", "disc_id": disc }))
		assert_eq(r["sparks"]["rate"], 0.0, "%s: el plástico no da chispas" % disc)
		assert_eq(r["sparks"]["length_mm"], 0.0, "%s: ni chorro" % disc)
		assert_true(r["melt"] > 0.0, "%s: se funde" % disc)
		assert_true(r["smoke"] > 0.0 and (r["smoke_from"] as Array).has("plástico"), "%s: humo del plástico" % disc)
		assert_true(_codes(r["warnings"]).has("plastico_fundido"), "%s: aviso" % disc)
		assert_true(r["burr_um"] > 0.0, "%s: bordes con hilos" % disc)
	for id in ["acero-dulce", "aluminio", "boro-22mnb5"]:
		assert_eq(Radial.cut_panel(_with({ "panel_id": id }))["melt"], 0.0, "%s: el metal no se funde en hilos" % id)


func test_boro_es_el_corte_mas_lento() -> void:
	for disc in ["fino_1mm", "corte_ceramico"]:
		var boro := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": disc }))
		for id in Panels.PANELS:
			if id == "boro-22mnb5":
				continue
			var r := Radial.cut_panel(_with({ "panel_id": id, "disc_id": disc }))
			assert_true(boro["time_s"] > r["time_s"], "%s: el boro (%s s) más lento que %s (%s s)" % [disc, boro["time_s"], id, r["time_s"]])
		assert_true(_codes(boro["warnings"]).has("pilar_boro"), "%s: aviso del pilar de boro" % disc)
	var dulce := Radial.cut_panel(_with({ "panel_id": "acero-dulce" }))
	var boro := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5" }))
	assert_false(_codes(dulce["warnings"]).has("pilar_boro"), "el aviso sale del dato press_hardened, no de todos")
	assert_true(_message(boro["warnings"], "pilar_boro").contains("1.500 MPa"), "con la resistencia del panel")
	assert_true(boro["heat_tint"]["width_mm"] > dulce["heat_tint"]["width_mm"], "más calor: banda de revenido más ancha")
	assert_true(boro["disc_wear_mm3"] > 5.0 * dulce["disc_wear_mm3"], "mucho más desgaste del disco")
	assert_eq(boro["limited_by"], "empuje", "lo frena la dureza (Archard), no la potencia")
	var ceramic := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": "corte_ceramico" }))
	var corundum := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": "fino_1mm" }))
	assert_true(ceramic["q_mm3_s"] > corundum["q_mm3_s"], "el grano cerámico arranca más con el mismo empuje")
	assert_true(ceramic["disc_wear_mm3"] / ceramic["kerf_mm"] < corundum["disc_wear_mm3"] / corundum["kerf_mm"], "y se gasta menos")


func test_exceso_de_velocidad() -> void:
	# El disco fino de PFERD lleva marcadas 12.200 rpm en Ø125 (la tabla de EN 12413 dice 12.250): manda el disco
	var ok := Radial.cut_panel(_with({ "rpm": 12200.0 }))
	assert_false(ok["over_speed"], "en las rpm marcadas en el disco no hay exceso")
	var just := Radial.cut_panel(_with({ "rpm": 12240.0 }))
	assert_true(just["over_speed"], "12.240 rpm pasan de las 12.200 del disco")
	var r := Radial.cut_panel(_with({ "rpm": 13000.0 }))
	assert_true(r["over_speed"], "13.000 rpm con un disco de 125 mm")
	assert_true(_codes(r["warnings"]).has("exceso_velocidad"), "aviso de exceso de velocidad")
	var big := Radial.cut_panel(_with({ "diameter_mm": 230.0, "rpm": 6500.0 }))
	assert_true(big["disc_id"] == "fino_1mm" and not big["over_speed"], "230 mm a 6.500 rpm (GWS 22-230) sin exceso")


func test_pintura_quemada_y_humo() -> void:
	for id in ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria"]:
		var r := Radial.cut_panel(_with({ "panel_id": id }))
		assert_true(r["paint_burn_mm"] > 0.0, "%s: pintura quemada a cada lado" % id)
		assert_true(r["smoke"] > 0.0 and (r["smoke_from"] as Array).has("pintura"), "%s: humo de pintura" % id)
		assert_true(_codes(r["warnings"]).has("pintura_humo"), "%s: aviso" % id)
	for id in ["boro-22mnb5", "dp800", "perfil-aluminio"]:
		var r := Radial.cut_panel(_with({ "panel_id": id }))
		assert_eq(r["paint_burn_mm"], 0.0, "%s: sin pintura" % id)
		assert_eq(r["smoke"], 0.0, "%s: sin humo" % id)
	var fine := Radial.cut_panel(_with({ "disc_id": "fino_1mm" }))
	var thick := Radial.cut_panel(_with({ "disc_id": "grueso_3mm" }))
	assert_true(thick["paint_burn_mm"] > fine["paint_burn_mm"], "el disco grueso quema más pintura")
	assert_true(thick["smoke"] > fine["smoke"] and fine["smoke"] < 1.0, "y humea más (sin saturar con el fino)")


func test_chispas_segun_el_material() -> void:
	var dulce := Radial.cut_panel(_with({ "panel_id": "acero-dulce" }))
	var boro := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5" }))
	var alu := Radial.cut_panel(_with({ "panel_id": "perfil-aluminio", "disc_id": "corte_alu" }))
	assert_true(dulce["sparks"]["rate"] >= 1000.0 and dulce["sparks"]["rate"] <= 10000.0, "miles de chispas visibles por segundo (%s)" % dulce["sparks"]["rate"])
	assert_near(dulce["sparks"]["rate"], Radial.SPARKS_PER_MM3 * dulce["q_mm3_s"], 1e-9, 0.0, "proporcionales al caudal")
	assert_true(dulce["sparks"]["length_mm"] > 1000.0, "acero de bajo carbono: chorro largo")
	# Fase 2 (una sola fuente): el TC 9-237 (§7-3 y tabla 7-5, AISI 1020) describe estelas largas amarillo-naranja que
	# acaban en horquillas blancas; antes, «amarillo paja» de la tabla de Steel Elements de panels.gd
	assert_eq(dulce["sparks"]["color_name"], "amarillo anaranjado", "estelas amarillo-naranja")
	assert_eq(dulce["sparks"]["color_end_name"], "blanco", "que acaban en blanco")
	# El modelo y el emisor de la escena dan el mismo haz (misma longitud, color y estallidos)
	for id in ["acero-dulce", "boro-22mnb5", "dp800"]:
		var r := Radial.cut_panel(_with({ "panel_id": id }))
		var st := Sparks.stream_for(id, r["vs_ms"])
		for k in ["length_mm", "color", "color_name", "color_end", "bursts", "bursts_name"]:
			assert_eq(r["sparks"][k], st[k], "%s: sparks.%s de Sparks.stream_for" % [id, k])
		var drawn := Sparks.resolve_stream(id, {}, r["vs_ms"])
		assert_near(drawn["length_mm"], r["sparks"]["length_mm"], 1e-12, 0.0, "%s: el emisor sin datos del modelo da la misma longitud" % id)
	assert_true(dulce["sparks"]["bursts"] < boro["sparks"]["bursts"], "más carbono (22MnB5), más estallidos por chispa")
	assert_true(boro["sparks"]["rate"] < dulce["sparks"]["rate"], "el boro, que avanza despacio, da menos chispas por segundo")
	assert_eq(alu["sparks"]["rate"], 0.0, "el aluminio no da chispas")
	var hi := Panels.SPARK_CLASSES["acero_alto_c"]
	var inox := Panels.SPARK_CLASSES["inox"]
	var low := Panels.SPARK_CLASSES["hierro_bajo_c"]
	assert_true(hi["bursts"] > low["bursts"], "alto carbono: muchos estallidos")
	assert_true(inox["length_in"] < low["length_in"] and inox["color_name"] == "rojizo", "inox: más cortas y rojizas")
	# Más rpm: el chorro llega más lejos
	var slow := Radial.cut_panel(_with({ "rpm": 8000.0 }))
	assert_true(dulce["sparks"]["length_mm"] > slow["sparks"]["length_mm"], "a más velocidad, chispas más largas")


func test_rpm_y_ritmo_de_corte() -> void:
	# En acero duro manda el empuje (Archard: Q ∝ v): a menos rpm, más lento
	var fast := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "rpm": 11000.0 }))
	var slow := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "rpm": 7000.0 }))
	assert_true(slow["time_s"] > fast["time_s"], "a menos rpm el boro se corta más despacio")
	# Si se pide un avance imposible, se queda en el máximo y se avisa
	var pushed := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "feed_mm_s": 50.0 }))
	assert_true(pushed["feed_mm_s"] < 50.0 and _codes(pushed["warnings"]).has("empuje"), "avance limitado por el empuje")
	assert_true(pushed["power_kw"] <= 0.690 + 1e-9, "sin pasar de la potencia útil")


## Sin corte no hay calor, ni chispas, ni rebaba, ni desgaste: disco parado, sin empuje o disco de láminas.
func test_sin_corte_no_hay_nada() -> void:
	for extra in [{ "rpm": 0.0 }, { "push_n": 0.0 }, { "push_n": -10.0 }, { "disc_id": "laminas" }]:
		var r := Radial.cut_panel(_with(extra))
		var what := str(extra)
		assert_eq(r["time_s"], INF, "%s: no termina" % what)
		assert_eq(r["q_mm3_s"], 0.0, "%s: no arranca nada" % what)
		for k in ["haz_mm", "paint_burn_mm", "burr_um", "disc_wear_mm3", "deformation", "melt", "smoke", "cleanliness", "heat_j_mm", "disc_loading"]:
			assert_eq(r[k], 0.0, "%s: %s = 0" % [what, k])
		assert_eq(r["sparks"]["rate"], 0.0, "%s: sin chispas" % what)
		assert_eq(r["sparks"]["length_mm"], 0.0, "%s: ni chorro" % what)
		assert_eq(r["heat_tint"]["temp_c"], Radial.T_AMBIENT, "%s: la chapa sigue fría" % what)
		assert_eq(r["front_temp_c"], Radial.T_AMBIENT, "%s: sin frente incandescente" % what)
		assert_true(r["feed_mm_s"] >= 0.0 and r["power_kw"] >= 0.0, "%s: sin números negativos" % what)
	assert_true(_codes(Radial.cut_panel(_with({ "rpm": 0.0 }))["warnings"]).has("sin_corte"), "disco parado: aviso")
	assert_true(_codes(Radial.cut_panel(_with({ "disc_id": "laminas" }))["warnings"]).has("disco_no_corta"), "láminas: no es para tronzar")


## Deformación (mm): la dilatación transversal α·H/(ρ·c·t) del calor del corte.
func test_deformacion_en_mm() -> void:
	var r := Radial.cut_panel(BASE)
	var th: Dictionary = Panels.THERMAL["acero"]
	var rho_c := float(th["rho"]) * 1e-9 * float(th["c"])
	assert_near(r["deformation"], float(th["alpha_k"]) * r["heat_j_mm"] / (rho_c * 0.9), 1e-12, 0.0, "α·H/(ρ·c·t)")
	assert_true(r["deformation"] > 0.01 and r["deformation"] < 1.0, "décimas de milímetro en chapa de acero (%s mm)" % r["deformation"])
	var plastic := Radial.cut_panel(_with({ "panel_id": "plastico-carroceria" }))
	assert_true(plastic["deformation"] > r["deformation"], "el plástico dilata mucho más que el acero")


func test_colores_de_revenido() -> void:
	var r := Radial.cut_panel(_with({ "disc_id": "grueso_3mm" }))
	var tint: Dictionary = r["heat_tint"]
	assert_true(tint["width_mm"] > 0.0 and String(tint["color"]).begins_with("#"), "el acero toma color junto al corte")
	var bands: Array = tint["bands"]
	assert_true(bands.size() >= 5, "varias bandas de color")
	for i in bands.size():
		assert_true(bands[i]["to_mm"] > bands[i]["from_mm"], "banda %d con anchura" % i)
		if i > 0:
			assert_near(bands[i]["from_mm"], bands[i - 1]["to_mm"], 1e-9, 1e-12, "bandas contiguas, del corte hacia fuera")
	assert_near(bands[-1]["to_mm"], tint["width_mm"], 1e-9, 1e-12, "la última banda acaba donde acaba el color")
	assert_eq(bands[-1]["name"], "amarillo pálido", "lo último en verse es el amarillo pálido (216 °C)")
	var alu := Radial.cut_panel(_with({ "panel_id": "aluminio", "disc_id": "corte_alu" }))
	assert_eq(alu["heat_tint"]["width_mm"], 0.0, "el aluminio no toma colores de revenido")


## Fase 2: el disco de metal duro corta las chapas de aluminio y de plástico sin embotarse y se gasta poco; el de CBN
## (de tronzadora fija) avisa siempre y, por debajo de sus 50 m/s, en el pilar de boro se gasta y calienta menos que el
## corindón.
func test_discos_de_metal_duro_y_de_cbn_contra_la_chapa() -> void:
	for id in ["aluminio", "plastico-carroceria", "perfil-aluminio"]:
		var wc := Radial.cut_panel(_with({ "panel_id": id, "disc_id": "metal_duro", "rpm": 12000.0 }))
		var std := Radial.cut_panel(_with({ "panel_id": id, "disc_id": "fino_1mm", "rpm": 12000.0 }))
		assert_true(wc["q_mm3_s"] > 0.0 and is_finite(wc["time_s"]), "%s: el de metal duro corta" % id)
		assert_false(_codes(wc["warnings"]).has("disco_inadecuado"), "%s: es su disco" % id)
		assert_true(wc["disc_loading"] < 0.4, "%s: no se embota" % id)
		if Panels.get_panel(id)["kind"] == "aluminio":
			assert_true(wc["disc_wear_mm3"] / wc["kerf_surface_mm"] < std["disc_wear_mm3"] / std["kerf_surface_mm"], "%s: se gasta menos por mm³ de surco" % id)
	assert_true(_codes(Radial.cut_panel(_with({ "disc_id": "metal_duro" }))["warnings"]).has("disco_inadecuado"), "en acero no")
	var fast := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": "cbn_1mm", "rpm": 11000.0 }))
	assert_true(fast["over_speed"] and _codes(fast["warnings"]).has("disco_fijo"), "CBN a 11.000 rpm: exceso y disco de tronzadora fija")
	var cbn := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": "cbn_1mm", "rpm": 7000.0 }))
	var al := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5", "disc_id": "fino_1mm", "rpm": 7000.0 }))
	assert_false(cbn["over_speed"], "a 7.000 rpm, dentro de sus 50 m/s")
	assert_true(_codes(cbn["warnings"]).has("disco_fijo"), "pero sigue sin ser un disco de radial")
	assert_true(cbn["disc_wear_mm3"] < 0.1 * al["disc_wear_mm3"], "el CBN apenas se gasta en el acero templado")
	assert_true(cbn["haz_mm"] < al["haz_mm"], "y calienta menos la chapa (R_ws 0,5 frente a 0,9, Rowe)")
	assert_true((cbn["sources"] as Array).has(Radial.CITE_AWAN_2021), "acero: cita la banda de energía de Awan 2021")


## Funciones puras (CONTRATOS.md → «Rendimiento y multinúcleo»): cut_panel, el haz de chispas y la viruta dan lo mismo
## desde varios hilos que en uno.
func test_corte_seguro_entre_hilos() -> void:
	var jobs: Array = []
	for disc in Abrasives.DISCS:
		for id in Panels.PANELS:
			for rpm in [7000.0, 11000.0, 13000.0]:
				jobs.append(_with({ "panel_id": id, "disc_id": disc, "rpm": rpm, "angle_deg": 10.0 }))
	var run := func(i: int) -> Dictionary:
		var r := Radial.cut_panel(jobs[i])
		r["stream"] = Sparks.stream_for(str(jobs[i]["panel_id"]), r["vs_ms"])
		r["chip"] = Chips.chip_breaking({ "work_id": "c45e", "f_mm": 0.05 + 0.01 * (i % 60), "ap_mm": 0.5 + 0.1 * (i % 55) })
		return r
	var seq: Array = []
	for i in jobs.size():
		seq.append(run.call(i))
	var par: Array = []
	par.resize(jobs.size())
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var r: Dictionary = run.call(i)
		mutex.lock()
		par[i] = r
		mutex.unlock()
	var gid := WorkerThreadPool.add_group_task(task, jobs.size(), 4, true, "test_cut_panel")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	assert_true(same(par, seq), "4 hilos = secuencial (%d cortes)" % jobs.size())


func test_avisos_de_rescate() -> void:
	for id in Panels.PANELS:
		var codes := _codes(Radial.cut_panel(_with({ "panel_id": id }))["warnings"])
		for c in ["rescate_herramientas", "rescate_airbag", "rescate_alta_tension", "educativo"]:
			assert_true(codes.has(c), "%s: aviso «%s»" % [id, c])
	var r := Radial.cut_panel(_with({ "panel_id": "boro-22mnb5" }))
	var by_code := {}
	for w in r["warnings"]:
		by_code[w["code"]] = w
	assert_true(String(by_code["rescate_herramientas"]["source"]).contains("DHS"), "cizallas y separadores: DHS SAVER")
	assert_true(String(by_code["rescate_alta_tension"]["source"]).contains("100"), "cables naranja: Reglamento n.º 100")
	assert_true(String(by_code["rescate_alta_tension"]["source"]).contains("17840"), "y la hoja de rescate ISO 17840")
	assert_true(String(by_code["educativo"]["message"]).contains("no es un procedimiento de rescate"), "simulador educativo")


static func _codes(warnings: Array) -> Array:
	var out: Array = []
	for w in warnings:
		out.append(w["code"])
	return out


static func _message(warnings: Array, code: String) -> String:
	for w in warnings:
		if w["code"] == code:
			return String(w["message"])
	return ""


static func _with(extra: Dictionary) -> Dictionary:
	var d := BASE.duplicate()
	d.merge(extra, true)
	return d
