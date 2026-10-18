## Taller · abrasivos, marcado de discos (EN 12413), tronzado y el grano como punta.
extends "res://tests/case.gd"

const Abrasives = preload("res://core/taller/abrasives.gd")
const Radial = preload("res://core/taller/radial.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


## 125 mm a 80 m/s y 230 mm a 80 m/s. La fórmula n = 60000·v/(π·D) da 12.223 y 6.643 rpm; lo que se marca en el
## disco sale de la tabla de conversión (anexo E de EN 12413), que redondea a 50 rpm: 12.250 y 6.650 (Klingspor,
## Andre). PFERD redondea a la centena (12.200 y 6.600). Por eso se admite ±0,5 % frente a 12.200 y a la fórmula.
func test_rpm_marcadas_125_y_230_a_80_ms() -> void:
	var m125 := Abrasives.marked_rpm(125.0, 80.0)
	var m230 := Abrasives.marked_rpm(230.0, 80.0)
	assert_near(m125, 12200.0, 0.005, 0.0, "125 mm a 80 m/s: marcado ≈ 12.200 rpm (±0,5 %)")
	assert_eq(m125, 12250.0, "125 mm: 12.250 rpm, el valor de la tabla de marcado")
	assert_near(m230, 6650.0, 0.005, 0.0, "230 mm a 80 m/s: marcado ≈ 6.650 rpm (±0,5 %)")
	var f125 := Abrasives.formula_rpm(125.0, 80.0)
	var f230 := Abrasives.formula_rpm(230.0, 80.0)
	assert_near(f125, 12223.0, 1e-4, 0.0, "fórmula a 125 mm")
	assert_near(f230, 6643.0, 1e-4, 0.0, "fórmula a 230 mm")
	assert_near(m125, f125, 0.005, 0.0, "125 mm: el marcado difiere de la fórmula solo por el redondeo")
	assert_near(m230, f230, 0.005, 0.0, "230 mm: el marcado difiere de la fórmula solo por el redondeo")
	assert_near(Abrasives.MARKED_RPM_PFERD_80[125], f125, 0.005, 0.0, "PFERD (12.200) también dentro del ±0,5 %")


## Toda la tabla de marcado: a menos de 50 rpm de la fórmula (redondeo a 50 rpm) y, a 80 m/s, dentro del ±0,5 %.
func test_tabla_de_rpm_marcadas_cerca_de_la_formula() -> void:
	for v in Abrasives.MARKED_RPM:
		assert_true(QUALITIES.has(Abrasives.MARKED_RPM_QUALITY[v]), "calidad de la fila de %d m/s" % v)
		var row: Dictionary = Abrasives.MARKED_RPM[v]
		for d in row:
			var f := Abrasives.formula_rpm(float(d), float(v))
			assert_true(absf(float(row[d]) - f) < 50.0, "Ø%d a %d m/s: %s rpm frente a %s por fórmula" % [d, v, row[d], f])
			if v == 80:
				assert_near(float(row[d]), f, 0.005, 0.0, "Ø%d a 80 m/s dentro del ±0,5 %%" % d)
	assert_true(Abrasives.MARKED_RPM_SOURCE.length() > 40, "la tabla de marcado cita su fuente")
	assert_eq(Abrasives.marked_rpm(140.0, 80.0), -1.0, "un diámetro que no está en la tabla")


## Franjas de color de EN 12413 (anexo D): comprobadas en Klingspor, Andre y la tabla de la norma de las mutuas de
## bomberos alemanas (HFUK Nord 2020).
func test_franjas_de_color_en_12413() -> void:
	var want := {
		50.0: ["azul"], 63.0: ["amarillo"], 80.0: ["rojo"], 100.0: ["verde"], 125.0: ["azul", "amarillo"],
		140.0: ["azul", "rojo"], 160.0: ["azul", "verde"], 180.0: ["amarillo", "rojo"], 200.0: ["amarillo", "verde"],
		225.0: ["rojo", "verde"], 250.0: ["azul", "azul"], 280.0: ["amarillo", "amarillo"], 320.0: ["rojo", "rojo"],
	}
	for v in want:
		assert_eq(Abrasives.stripe_for(v), want[v], "franja de %s m/s" % v)
	assert_eq(Abrasives.stripe_for(40.0), [], "hasta 45 m/s no hay franja")
	assert_eq(Abrasives.stripe_for(45.0), [], "45 m/s tampoco")
	for row in Abrasives.STRIPES:
		assert_true(QUALITIES.has(row["quality"]), "calidad de la franja de %s m/s" % row["max_speed_ms"])
		for c in row["colors"]:
			assert_true(Abrasives.STRIPE_HEX.has(c), "color de pintado para «%s»" % c)
	assert_true(Abrasives.STRIPES_SOURCE.contains("EN 12413") and Abrasives.STRIPES_SOURCE.contains("Klingspor"), "fuente de las franjas")
	assert_eq(Abrasives.disc_stripe("fino_1mm"), ["rojo"], "un disco de corte de 80 m/s lleva franja roja")
	assert_eq(Abrasives.disc_stripe("diamante"), [], "los de diamante (EN 13236) no llevan franja de EN 12413")


func test_disc_check_y_exceso_de_velocidad() -> void:
	# Bosch GWS 12-125: 11.000 rpm en vacío con un disco de 125 mm (80 m/s): dentro
	var ok := Radial.disc_check({ "diameter_mm": 125.0, "rpm": 11000.0, "max_speed_ms": 80.0 })
	assert_false(ok["over_speed"], "11.000 rpm con un disco de 125 mm no es exceso")
	assert_near(ok["speed_ms"], PI * 125.0 * 11000.0 / 60000.0, 1e-12, 0.0, "velocidad periférica π·D·n/60000")
	assert_eq(ok["marked_rpm"], 12250.0, "rpm marcadas")
	assert_eq(ok["warning"], "", "sin aviso")
	assert_eq(ok["stripe"], ["rojo"], "franja roja de 80 m/s")
	# Un disco de 125 mm en una radial de 115 mm (13.300 rpm): exceso
	var bad := Radial.disc_check({ "diameter_mm": 125.0, "rpm": 13300.0, "max_speed_ms": 80.0 })
	assert_true(bad["over_speed"], "13.300 rpm con un disco de 125 mm es exceso de velocidad")
	assert_true(bad["speed_ms"] > 80.0, "el borde pasa de 80 m/s")
	assert_true(String(bad["warning"]).contains("Exceso de velocidad"), "aviso en español")
	# Un disco de 230 mm gastado hasta 125 mm en una radial de 125 mm: va lento, pero pasa de sus rpm marcadas
	var worn := Radial.disc_check({ "diameter_mm": 125.0, "rpm": 11000.0, "max_speed_ms": 80.0, "nominal_diameter_mm": 230.0 })
	assert_true(worn["speed_ms"] < 80.0, "el borde va por debajo de 80 m/s")
	assert_true(worn["over_speed"], "pero 11.000 rpm superan las 6.650 marcadas en el disco de 230 mm")
	assert_true(String(worn["warning"]).contains("gastados"), "aviso de los discos gastados")
	# Justo en las rpm marcadas no hay exceso (aunque la fórmula dé un poco menos)
	assert_false(Radial.disc_check({ "diameter_mm": 125.0, "rpm": 12250.0, "max_speed_ms": 80.0 })["over_speed"], "en las rpm marcadas")
	assert_true(Radial.disc_check({ "diameter_mm": 125.0, "rpm": 12251.0, "max_speed_ms": 80.0 })["over_speed"], "una rpm por encima")
	# Sin tabla para ese diámetro: manda la fórmula, marked_rpm es null y el aviso no la llama «marcada»
	var odd := Radial.disc_check({ "diameter_mm": 140.0, "rpm": 11000.0, "max_speed_ms": 80.0 })
	assert_eq(odd["marked_rpm"], null, "Ø140 no está en la tabla")
	assert_eq(odd["over_speed"], 11000.0 > Abrasives.formula_rpm(140.0, 80.0), "sin tabla, la fórmula")
	var odd_fast := Radial.disc_check({ "diameter_mm": 140.0, "rpm": 11500.0, "max_speed_ms": 80.0 })
	assert_true(odd_fast["over_speed"] and String(odd_fast["warning"]).contains("máximas"), "por fórmula: rpm máximas, no marcadas")


## Manda lo marcado en el propio disco: PFERD marca 12.200 rpm en el de 125 mm (la tabla de EN 12413, 12.250).
func test_disc_check_con_las_rpm_del_disco() -> void:
	var own := Radial.disc_check({ "diameter_mm": 125.0, "rpm": 12240.0, "disc_id": "fino_1mm" })
	assert_eq(own["disc_rpm"], 12200.0, "rpm marcadas en el disco (PFERD)")
	assert_eq(own["limit_rpm"], 12200.0, "el límite es el del disco")
	assert_true(own["over_speed"], "12.240 rpm pasan de las 12.200 del disco aunque no de las 12.250 de la tabla")
	assert_true(String(own["warning"]).contains("marcadas en el disco"), "el aviso dice de dónde sale el límite")
	assert_false(Radial.disc_check({ "diameter_mm": 125.0, "rpm": 12200.0, "disc_id": "fino_1mm" })["over_speed"], "en las del disco, sin exceso")
	# Diamante de 178 mm: PFERD marca 8.600 rpm (la fórmula da 8.584); ese diámetro no está en la tabla
	var dia := Radial.disc_check({ "diameter_mm": 178.0, "rpm": 8600.0, "disc_id": "diamante" })
	assert_false(dia["over_speed"], "8.600 rpm, las marcadas en el disco de diamante de 178 mm")
	assert_true(Radial.disc_check({ "diameter_mm": 178.0, "rpm": 8650.0, "disc_id": "diamante" })["over_speed"], "8.650 rpm, exceso")
	assert_eq(dia["stripe"], [], "un disco de diamante (EN 13236) no lleva franja de EN 12413")
	# Un diámetro en el que el fabricante no hace ese disco: la tabla de EN 12413
	var big := Radial.disc_check({ "diameter_mm": 230.0, "rpm": 6600.0, "disc_id": "fino_1mm" })
	assert_eq(big["disc_rpm"], null, "PFERD no hace ese disco en Ø230")
	assert_eq(big["limit_rpm"], 6650.0, "manda la tabla")
	assert_eq(Abrasives.disc_rpm("fino_1mm", 115.0), 13300.0, "rpm del disco por diámetro")
	assert_eq(Abrasives.disc_rpm("no-existe", 125.0), -1.0, "disco desconocido")
	# Un disco que se gira al revés o con rpm negativas no va «deprisa»
	assert_false(Radial.disc_check({ "diameter_mm": 125.0, "rpm": -20000.0, "disc_id": "fino_1mm" })["over_speed"], "rpm negativas: parado")


func test_granos_fepa_y_jis() -> void:
	assert_near(Abrasives.grit_microns("jis_r6001", 1000), 11.5, 1e-12, 0.0, "JIS #1000 ≈ 11,5 µm")
	assert_eq(Abrasives.grit_microns("fepa_f", 1000), 4.5, "F1000 = 4,5 µm")
	assert_near(Abrasives.grit_microns("fepa_p", 1000), 18.3, 1e-12, 0.0, "P1000 ≈ 18,3 µm")
	assert_eq(Abrasives.grit_microns("fepa_f", "F1000"), 4.5, "grado como texto con prefijo")
	assert_eq(Abrasives.grit_microns("jis_r6001", "#1000"), 11.5, "grado JIS como texto")
	assert_eq(Abrasives.grit_microns("fepa_p", "P1000"), 18.3, "grado P como texto")
	assert_eq(Abrasives.grit_microns("fepa_p", "p1000"), 18.3, "sin distinguir mayúsculas")
	assert_eq(Abrasives.grit_microns("fepa_f", "1000"), 4.5, "solo las cifras")
	assert_eq(Abrasives.grit_microns("fepa_f", 60), 260.0, "F60 (macro, tamizado)")
	assert_eq(Abrasives.grit_microns("fepa_f", 1001), -1.0, "grado inexistente")
	assert_eq(Abrasives.grit_microns("ansi", 60), -1.0, "sistema inexistente")
	# El prefijo de otro sistema no se cambia en silencio: P1000 (18,3 µm) no es F1000 (4,5 µm)
	assert_eq(Abrasives.grit_microns("fepa_f", "P1000"), -1.0, "P1000 no es un grado FEPA F")
	assert_eq(Abrasives.grit_microns("jis_r6001", "F240"), -1.0, "F240 no es un grado JIS")
	assert_eq(Abrasives.grit_microns("fepa_p", "#1000"), -1.0, "#1000 no es un grado P")
	assert_eq(Abrasives.grit_microns("fepa_f", "F10x0"), -1.0, "texto que no es un grado")
	# JIS dentro de su rango de ds-50
	var jis: Dictionary = Abrasives.GRIT_SYSTEMS["jis_r6001"]
	for g in jis["sizes"]:
		var r: Array = jis["ranges"][g]
		assert_true(float(jis["sizes"][g]) >= r[0] and float(jis["sizes"][g]) <= r[1], "JIS #%d dentro de su rango" % g)
	# Cuanto más alto el grado, más fino el grano, en los tres sistemas
	for sys_id in Abrasives.GRIT_SYSTEMS:
		var sys: Dictionary = Abrasives.GRIT_SYSTEMS[sys_id]
		var grades: Array = sys["sizes"].keys()
		grades.sort()
		for i in range(1, grades.size()):
			assert_true(float(sys["sizes"][grades[i]]) < float(sys["sizes"][grades[i - 1]]), "%s: %d más fino que %d" % [sys_id, grades[i], grades[i - 1]])
		assert_true(String(sys["source"]).length() > 20 and QUALITIES.has(sys["quality"]), "%s con fuente y calidad" % sys_id)


func test_abrasivos_temperatura_y_hierro() -> void:
	for id in ["al2o3", "sic", "cbn", "diamante"]:
		assert_true(Abrasives.ABRASIVES.has(id), "clave de unión «%s» (CONTRATOS.md)" % id)
	var dia: Dictionary = Abrasives.ABRASIVES["diamante"]
	assert_eq(dia["max_temp_c"], 600.0, "el diamante se oxida por encima de ~600 °C (KAPP 2006)")
	assert_eq(dia["iron_reaction_c"], 700.0, "y reacciona con el hierro por encima de ~700 °C")
	assert_true(dia["iron_reactive"], "el diamante se gasta contra el hierro (Komanduri y Shaw 1975)")
	assert_true(String(dia["source"]).contains("Komanduri"), "cita a Komanduri y Shaw")
	assert_false(Abrasives.ABRASIVES["cbn"]["iron_reactive"], "el CBN no: es el superabrasivo del acero")
	assert_eq(Abrasives.ABRASIVES["cbn"]["max_temp_c"], 1000.0, "CBN hasta 1.000 °C")
	assert_false(Abrasives.ABRASIVES["al2o3"]["iron_reactive"], "el corindón no reacciona con el acero")
	assert_true(Abrasives.ABRASIVES["sic"]["iron_reactive"], "el SiC sí (patente US 4.505.720)")
	# Más duro que el acero templado del laboratorio (y el diamante, el más duro). La Knoop, si se publica: el grano de
	# metal duro de la fase 2 no la tiene (hk = null), no se inventa
	for id in Abrasives.ABRASIVES:
		var ab: Dictionary = Abrasives.ABRASIVES[id]
		var hk_ok: bool = ab["hk"] == null or float(ab["hk"]) > 1500.0
		assert_true(float(ab["hv"]) > 1500.0 and hk_ok and float(ab["e_gpa"]) > 300.0, "%s: dureza y módulo de un abrasivo" % id)
		assert_true(float(ab["hv"]) <= float(dia["hv"]), "%s no es más duro que el diamante" % id)


func test_recomendaciones_por_material() -> void:
	assert_eq(Abrasives.abrasives_for("fundicion")[0], "sic", "SiC para fundición")
	assert_true(Abrasives.abrasives_for("piedra").has("sic"), "SiC recomendado para piedra")
	assert_eq(Abrasives.abrasives_for("piedra")[0], "diamante", "y el diamante, el primero en piedra")
	assert_eq(Abrasives.abrasives_for("acero", "H")[0], "cbn", "CBN para acero templado (ISO 513 H)")
	assert_eq(Abrasives.abrasives_for("inox", "H")[0], "cbn", "también en inox templado")
	assert_eq(Abrasives.abrasives_for("acero")[0], "al2o3", "corindón para acero normal")
	assert_false(Abrasives.abrasives_for("acero").has("diamante"), "nunca diamante en acero")
	assert_false(Abrasives.abrasives_for("acero", "H").has("diamante"), "ni en acero templado")
	# RECOMMEND y best_for dicen lo mismo
	for kind in Abrasives.RECOMMEND:
		for ab_id in Abrasives.RECOMMEND[kind]:
			assert_true((Abrasives.ABRASIVES[ab_id]["best_for"] as Array).has(kind), "%s.best_for incluye %s" % [ab_id, kind])
	for ab_id in Abrasives.ABRASIVES:
		for kind in Abrasives.ABRASIVES[ab_id]["best_for"]:
			assert_true((Abrasives.RECOMMEND[kind] as Array).has(ab_id), "RECOMMEND[%s] incluye %s" % [kind, ab_id])


func test_todos_los_datos_con_fuente_y_calidad() -> void:
	for id in Abrasives.ABRASIVES:
		var ab: Dictionary = Abrasives.ABRASIVES[id]
		assert_eq(ab["id"], id, "id de %s" % id)
		assert_true(String(ab["source"]).length() > 40 and QUALITIES.has(ab["quality"]), "abrasivo %s con fuente y calidad" % id)
	for id in ["fino_1mm", "grueso_3mm", "diamante", "laminas"]:
		assert_true(Abrasives.DISCS.has(id), "disco «%s» del contrato de cut_panel" % id)
	for id in Abrasives.DISCS:
		var disc: Dictionary = Abrasives.DISCS[id]
		assert_eq(disc["id"], id, "id del disco %s" % id)
		assert_true(String(disc["source"]).length() > 40 and QUALITIES.has(disc["quality"]), "disco %s con fuente y calidad" % id)
		assert_true(Abrasives.ABRASIVES.has(disc["abrasive"]), "disco %s: abrasivo conocido" % id)
		assert_true((disc["abrasives"] as Array).has(disc["abrasive"]), "disco %s: su abrasivo está en la lista" % id)
		assert_true(float(disc["max_speed_ms"]) > 0.0 and not (disc["rpm_by_diameter"] as Dictionary).is_empty(), "disco %s: velocidad y rpm" % id)
		for dia in disc["rpm_by_diameter"]:
			var f := Abrasives.formula_rpm(float(dia), float(disc["max_speed_ms"]))
			assert_near(float(disc["rpm_by_diameter"][dia]), f, 0.01, 0.0, "disco %s: rpm de Ø%d coherentes con %s m/s" % [id, dia, disc["max_speed_ms"]])
	for kind in Radial.WORK_KINDS:
		var w: Dictionary = Radial.WORK_KINDS[kind]
		assert_true(String(w["source"]).length() > 10 and QUALITIES.has(w["quality"]), "pieza %s con fuente y calidad" % kind)
		if float(w["loading"]) > 0.0:
			assert_true(String(w["source"]).contains("ESTIMACIÓN"), "pieza %s: su tendencia a embotar es una estimación" % kind)
	for g in Radial.GRINDERS:
		assert_true(QUALITIES.has(g["quality"]), "radial %s con calidad" % g["name"])
		assert_true(float(g["power_kw"]) > 0.0 and float(g["power_kw"]) < float(g["input_kw"]), "radial %s: potencia útil en kW" % g["name"])


func test_tronzado_potencia_crece_con_el_caudal() -> void:
	var prev_q := 0.0
	var prev_p := 0.0
	for feed in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		var r := Radial.cut_off({ "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "work_kind": "acero",
			"thickness_mm": 3.0, "feed_mm_s": feed })
		assert_eq(r["limited_by"], "", "a %s mm/s ni la potencia ni el empuje limitan" % feed)
		assert_near(r["q_mm3_s"], r["kerf_surface_mm"] * 3.0 * feed, 1e-12, 0.0, "Q = surco × espesor × avance")
		assert_near(r["power_kw"] * 1000.0, r["specific_energy_j_mm3"] * r["q_mm3_s"], 1e-9, 0.0, "P = SEC·Q")
		assert_true(r["q_mm3_s"] > prev_q and r["power_kw"] > prev_p, "más caudal, más potencia (%s mm/s)" % feed)
		prev_q = r["q_mm3_s"]
		prev_p = r["power_kw"]
	# Acero de 3 mm con disco de 125 mm a caudal normal: ~25 J/mm³, el valor típico de Rowe et al. (2003)
	var ex := Radial.cut_off({ "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "work_kind": "acero", "thickness_mm": 3.0, "feed_mm_s": 5.0 })
	assert_true(ex["specific_energy_j_mm3"] > 20.0 and ex["specific_energy_j_mm3"] < 30.0, "energía específica del acero ≈ 25 J/mm³")
	assert_true(ex["warnings"].is_empty(), "el corte de ejemplo no tiene avisos")
	# Si se pide más de lo que da la radial, el avance baja y se avisa
	var fast := Radial.cut_off({ "disc_id": "grueso_3mm", "diameter_mm": 125.0, "rpm": 11000.0, "work_kind": "acero", "thickness_mm": 3.0, "feed_mm_s": 20.0 })
	assert_true(fast["feed_mm_s"] < 20.0 and fast["limited_by"] != "", "no se puede cortar a 20 mm/s con un disco de 3,2 mm")
	assert_true(_codes(fast["warnings"]).has("potencia") or _codes(fast["warnings"]).has("empuje"), "aviso de potencia o empuje")
	assert_true(fast["power_kw"] <= 0.690 + 1e-9, "nunca más de los 690 W útiles de la radial")
	# Con otra radial (power_kw), otro tope
	var strong := Radial.cut_off({ "disc_id": "grueso_3mm", "diameter_mm": 125.0, "rpm": 11000.0, "work_kind": "acero", "thickness_mm": 3.0, "feed_mm_s": 20.0, "power_kw": 1.5 })
	assert_true(strong["feed_mm_s"] > fast["feed_mm_s"] and strong["power_kw"] <= 1.5 + 1e-9, "más potencia, más avance")


func test_tronzado_avisos() -> void:
	var base := { "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 3.0 }
	var dia := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "acero" }))
	assert_true(_codes(dia["warnings"]).has("diamante_ferrico"), "diamante sobre acero: aviso")
	assert_true(_codes(dia["warnings"]).has("disco_inadecuado"), "y disco inadecuado")
	var dia_inox := Radial.cut_off(_with(base, { "disc_id": "diamante_turbo", "work_kind": "inox" }))
	assert_true(_codes(dia_inox["warnings"]).has("diamante_ferrico"), "diamante sobre inox: aviso")
	var stone := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "piedra" }))
	assert_false(_codes(stone["warnings"]).has("diamante_ferrico"), "diamante en piedra: sin aviso")
	assert_false(_codes(stone["warnings"]).has("disco_inadecuado"), "y es su disco")
	var cast := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "fundicion" }))
	assert_false(_codes(cast["warnings"]).has("diamante_ferrico"), "fundición: no es el aviso del acero")
	assert_true(_codes(cast["warnings"]).has("diamante_fundicion"), "sino la nota del diamante galvánico")
	var alu_on_steel := Radial.cut_off(_with(base, { "disc_id": "corte_alu", "work_kind": "acero" }))
	assert_true(_codes(alu_on_steel["warnings"]).has("disco_inadecuado"), "disco de aluminio en acero: inadecuado")
	var grinding := Radial.cut_off(_with(base, { "disc_id": "desbaste", "work_kind": "acero" }))
	assert_true(_codes(grinding["warnings"]).has("disco_no_corta"), "un disco de desbaste no es para tronzar")
	var fast := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "acero", "rpm": 13300.0 }))
	assert_true(fast["over_speed"] and _codes(fast["warnings"]).has("exceso_velocidad"), "exceso de velocidad en el tronzado")
	var alu := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "aluminio" }))
	assert_true(_codes(alu["warnings"]).has("embotamiento"), "aluminio con disco de corindón: se embota")
	var titan := Radial.cut_off(_with(base, { "disc_id": "corte_sic", "work_kind": "titanio" }))
	assert_true(_codes(titan["warnings"]).has("sin_datos"), "titanio: sin energía publicada, se avisa")
	for w in dia["warnings"]:
		assert_true(String(w["message"]).length() > 20, "aviso «%s» con texto" % w["code"])


## El aviso de disco inadecuado no recomienda el grano que ya lleva el disco y escribe los materiales con tildes.
func test_aviso_de_disco_inadecuado() -> void:
	var base := { "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 3.0 }
	var alu := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "aluminio" }))
	var msg := _message(alu["warnings"], "disco_inadecuado")
	assert_true(msg.contains("carburo de silicio"), "recomienda SiC para aluminio: %s" % msg)
	assert_false(msg.contains("corindón (alúmina fundida)"), "no recomienda el corindón que ya lleva el disco")
	var sic_steel := Radial.cut_off(_with(base, { "disc_id": "corte_sic", "work_kind": "acero" }))
	var msg2 := _message(sic_steel["warnings"], "disco_inadecuado")
	assert_true(msg2.contains("latón") and msg2.contains("fundición"), "materiales con tildes: %s" % msg2)
	assert_false(msg2.contains("laton") or msg2.contains("fundicion,"), "sin ids internos")
	var sic_plastic := Radial.cut_off(_with(base, { "disc_id": "corte_sic", "work_kind": "plastico" }))
	var msg3 := _message(sic_plastic["warnings"], "disco_inadecuado")
	assert_false(msg3.contains("Para esta pieza: carburo"), "no recomienda su propio grano")
	assert_true(msg3.contains("Su grano sí sirve"), "dice que el grano es el adecuado y el disco no")


## Un grano que reacciona con el hierro (ABRASIVES.iron_reactive): el SiC en acero se gasta; el diamante, además, se
## vidria porque se sabe a qué temperatura reacciona y la pared del surco pasa de ella.
func test_granos_que_reaccionan_con_el_hierro() -> void:
	var base := { "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 0.0 }
	var sic := Radial.cut_off(_with(base, { "disc_id": "corte_sic", "work_kind": "acero" }))
	assert_true(_codes(sic["warnings"]).has("sic_ferrico"), "SiC sobre acero: aviso")
	assert_false(_codes(Radial.cut_off(_with(base, { "disc_id": "corte_sic", "work_kind": "fundicion" }))["warnings"]).has("sic_ferrico"), "en fundición es su sitio")
	assert_false(_codes(Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "acero" }))["warnings"]).has("al2o3_ferrico"), "el corindón no reacciona")
	var dia := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "acero" }))
	var msg := _message(dia["warnings"], "diamante_ferrico")
	assert_true(msg.contains("600") and msg.contains("700") and msg.contains("1.250"), "temperaturas de los datos: %s" % msg)


## Casos sin corte: disco parado, sin empuje, grano más blando que la pieza, tipo desconocido.
func test_tronzado_sin_corte_y_tipos_desconocidos() -> void:
	var base := { "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 3.0 }
	# Parado no corta ni la piedra (en las frágiles no hay límite de Archard, pero la potencia sin giro no arranca nada)
	var still := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "piedra", "rpm": 0.0 }))
	assert_eq(still["q_mm3_s"], 0.0, "disco parado: no arranca nada")
	assert_eq(still["time_s"], INF, "ni termina nunca")
	assert_true(_codes(still["warnings"]).has("sin_corte"), "aviso de que no hay corte")
	var no_push := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "acero", "push_n": 0.0 }))
	assert_eq(no_push["q_mm3_s"], 0.0, "sin empuje no entra")
	var neg := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "acero", "push_n": -10.0, "feed_mm_s": 0.0 }))
	assert_true(neg["q_mm3_s"] >= 0.0 and neg["feed_mm_s"] >= 0.0 and neg["power_kw"] >= 0.0, "un empuje negativo no da números negativos")
	var hard := Radial.cut_off(_with(base, { "disc_id": "fino_1mm", "work_kind": "acero", "work_hv": 2600.0 }))
	assert_eq(hard["q_mm3_s"], 0.0, "el corindón (2.000 HV) no raya una pieza de 2.600 HV")
	assert_true(_message(hard["warnings"], "sin_corte").contains("más blando"), "y lo explica")
	# Un tipo desconocido conserva su nombre y no se da por acero
	var copper := Radial.cut_off(_with(base, { "disc_id": "diamante", "work_kind": "cobre" }))
	assert_true(_message(copper["warnings"], "sin_datos").contains("cobre"), "el aviso habla del cobre")
	assert_false(_codes(copper["warnings"]).has("diamante_ferrico"), "el cobre no es férrico")


## Acero templado (ISO 513 H) y dureza de la pieza: cuanto más dura, nunca más deprisa.
func test_acero_templado_y_dureza_de_la_pieza() -> void:
	var base := { "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "work_kind": "acero", "thickness_mm": 3.0, "feed_mm_s": 0.0 }
	var mild := Radial.cut_off(base)
	var hardened := Radial.cut_off(_with(base, { "work_iso": "H" }))
	assert_eq(hardened["work_hv"], Radial.HARDENED_HV, "templado sin dureza: 700 HV (60 HRC)")
	assert_true(hardened["time_s"] > 2.0 * mild["time_s"], "el templado se corta mucho más despacio")
	assert_eq(hardened["limited_by"], "empuje", "lo frena la dureza (Archard)")
	assert_eq(Radial.cut_off(_with(base, { "work_iso": "H", "work_hv": 500.0 }))["work_hv"], 500.0, "work_hv manda")
	var prev := 0.0
	for hv in [100.0, 200.0, 400.0, 700.0, 900.0]:
		var r := Radial.cut_off(_with(base, { "work_hv": hv }))
		assert_true(r["time_s"] >= prev, "a %s HV no se corta más deprisa que con menos dureza" % hv)
		prev = r["time_s"]


## El grano abrasivo como punta: el modo cambia en Dp = 0,1 y 0,2, con la misma función que el laboratorio.
func test_grano_cambia_de_modo_como_el_laboratorio() -> void:
	var grain := { "grit_microns": Abrasives.grit_microns("fepa_f", 60), "abrasive_id": "al2o3", "work_hv": 200.0, "work_e_gpa": 193.0 }
	# El modo sale siempre de Abrasion.abrasion_mode(Dp) cuando hay surco (> 0,5 µm) y la profundidad crece con la carga
	var prev := 0.0
	for load in [0.05, 0.2, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0]:
		var r := Radial.grain_contact(_with(grain, { "load_n": load }))
		if r["depth_um"] > Radial.GROOVE_MIN_UM:
			var want := Abrasion.abrasion_mode(r["Dp"])
			assert_eq(r["absMode"], want["absMode"], "modo de Hokkirigawa-Kato a %s N" % load)
			assert_eq(r["fab"], want["fab"], "fracción arrancada a %s N" % load)
		else:
			assert_eq(r["absMode"], null, "a %s N no hay surco" % load)
		assert_true(r["depth_um"] >= prev, "más carga, más profundidad (%s N)" % load)
		prev = r["depth_um"]
	# Umbrales: se busca la carga a la que Dp cruza 0,1 y 0,2 y se mira a cada lado
	for th in [Abrasion.DP_WEDGE, Abrasion.DP_CUT]:
		var lo := 0.01
		var hi := 100.0
		for i in 60:
			var mid := sqrt(lo * hi)
			if float(Radial.grain_contact(_with(grain, { "load_n": mid }))["Dp"]) < th:
				lo = mid
			else:
				hi = mid
		var below := Radial.grain_contact(_with(grain, { "load_n": lo }))
		var above := Radial.grain_contact(_with(grain, { "load_n": hi }))
		assert_true(float(below["Dp"]) < th and float(above["Dp"]) >= th, "Dp cruza %s" % th)
		assert_true(float(below["depth_um"]) > Radial.GROOVE_MIN_UM, "en el umbral ya hay surco")
		assert_eq(below["absMode"], "arado" if th == Abrasion.DP_WEDGE else "cuña", "por debajo de Dp = %s" % th)
		assert_eq(above["absMode"], "cuña" if th == Abrasion.DP_WEDGE else "corte", "por encima de Dp = %s" % th)
	# El laboratorio (oráculo V1): en los escenarios del golden con surco, el modo y la fracción que da la función
	# compartida para su Dp son los mismos que calculó physics.js
	var golden: Array = load_json("res://tests/fixtures/lab-golden.json")
	var checked := 0
	for sc in golden:
		var res: Dictionary = sc["result"]
		if res.get("absMode") == null:
			continue
		var mode := Abrasion.abrasion_mode(float(res["Dp"]))
		assert_eq(mode["absMode"], res["absMode"], "%s: modo del laboratorio" % sc["name"])
		assert_near(mode["fab"], float(res["fab"]), 1e-9, 1e-12, "%s: fracción arrancada" % sc["name"])
		checked += 1
	assert_true(checked >= 10, "escenarios del golden con surco comprobados: %d" % checked)


func test_grano_mas_duro_que_la_pieza() -> void:
	# Un grano de corindón (2000 HV) contra una pieza igual de dura no raya (r = 1: eficiencia casi nula)
	var soft := Radial.grain_contact({ "grit_microns": 260.0, "abrasive_id": "al2o3", "work_hv": 2600.0, "work_e_gpa": 400.0, "load_n": 5.0 })
	assert_eq(soft["depth_um"], 0.0, "r < 0,8: el grano no raya")
	assert_eq(soft["absMode"], null, "sin surco no hay modo")
	# Con una carga mínima entra algo, pero menos de 0,5 µm: sin surco, como en el laboratorio
	var faint := Radial.grain_contact({ "grit_microns": 260.0, "abrasive_id": "al2o3", "work_hv": 200.0, "work_e_gpa": 193.0, "load_n": 0.01 })
	assert_true(faint["depth_um"] > 0.0 and faint["depth_um"] < Radial.GROOVE_MIN_UM, "roce de %s µm" % faint["depth_um"])
	assert_eq(faint["absMode"], null, "sin surco no hay modo")
	assert_eq(faint["fab"], 0.0, "ni arranca nada")
	# El mismo grano en acero raya; el diamante, a igual carga, no raya menos
	var al := Radial.grain_contact({ "grit_microns": 260.0, "abrasive_id": "al2o3", "work_hv": 200.0, "work_e_gpa": 193.0, "load_n": 5.0 })
	var dia := Radial.grain_contact({ "grit_microns": 260.0, "abrasive_id": "diamante", "work_hv": 200.0, "work_e_gpa": 193.0, "load_n": 5.0 })
	assert_true(al["depth_um"] > 0.0 and al["eta"] == 1.0, "corindón en acero: raya con eficiencia plena")
	assert_true(dia["depth_um"] >= al["depth_um"] - 1e-9, "el diamante no raya menos que el corindón")
	# Un grano más fino, a igual carga, entra más (más presión)
	var fine := Radial.grain_contact({ "grit_microns": Abrasives.grit_microns("fepa_f", 120), "abrasive_id": "al2o3", "work_hv": 200.0, "work_e_gpa": 193.0, "load_n": 5.0 })
	assert_true(fine["Dp"] > al["Dp"], "F120 corta antes que F60 con la misma carga")


## Fase 2: disco de grano de metal duro (PFERD DS Multi Power Carbide) y de CBN (Tyrolit 1A1R, de tronzadora fija).
func test_discos_de_metal_duro_y_de_cbn() -> void:
	var wc: Dictionary = Abrasives.DISCS["metal_duro"]
	assert_eq(wc["abrasive"], "carburo_w", "grano de carburo de tungsteno")
	assert_near(wc["thickness_mm"], 0.075 * 25.4, 1e-12, 0.0, "corta con el borde de grano: X = 0,075 in")
	assert_true(float(wc["body_thickness_mm"]) < float(wc["thickness_mm"]), "el cuerpo de acero es más fino que el borde")
	assert_eq(Abrasives.disc_rpm("metal_duro", 125.0), 12200.0, "12.200 rpm marcadas (PFERD)")
	assert_true(String(wc["source"]).contains("DS Multi Power Carbide") and wc["quality"] == "primary", "ficha del fabricante")
	var base := { "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 0.0 }
	assert_true(_codes(Radial.cut_off(_with(base, { "disc_id": "metal_duro", "work_kind": "acero" }))["warnings"]).has("disco_inadecuado"), "el de metal duro no es para acero")
	var alu := Radial.cut_off(_with(base, { "disc_id": "metal_duro", "work_kind": "aluminio" }))
	assert_false(_codes(alu["warnings"]).has("disco_inadecuado"), "sí para no férricos")
	assert_true(alu["q_mm3_s"] > 0.0, "y corta")
	# CBN: Tyrolit solo marca la velocidad (50 m/s); manda la fórmula, no la tabla de EN 12413 (es de EN 13236)
	var cbn: Dictionary = Abrasives.DISCS["cbn_1mm"]
	assert_eq(cbn["abrasive"], "cbn", "grano de CBN")
	assert_true(cbn["stationary_only"] and not cbn["rpm_marked"], "de tronzadora fija y sin rpm marcadas")
	assert_eq(Abrasives.disc_rpm("cbn_1mm", 125.0), -1.0, "sin rpm marcadas")
	var chk := Radial.disc_check({ "diameter_mm": 125.0, "rpm": 11000.0, "disc_id": "cbn_1mm" })
	assert_true(chk["over_speed"], "a 11.000 rpm un disco de 50 m/s va con exceso (72 m/s)")
	assert_near(chk["limit_rpm"], Abrasives.formula_rpm(125.0, 50.0), 1e-12, 0.0, "límite: 60.000·50/(π·125)")
	assert_eq(chk["marked_rpm"], null, "sin tabla de EN 12413")
	assert_true(String(chk["warning"]).contains("máximas"), "el aviso dice que son las máximas de la fórmula")
	assert_eq(chk["stripe"], [], "sin franja de EN 12413")
	var slow := Radial.cut_off(_with(base, { "disc_id": "cbn_1mm", "work_kind": "acero", "work_iso": "H", "rpm": 7000.0 }))
	assert_false(slow["over_speed"], "a 7.000 rpm, dentro de sus 50 m/s")
	assert_true(_codes(slow["warnings"]).has("disco_fijo"), "pero no se monta en una radial")
	assert_true(String(_message(slow["warnings"], "disco_fijo")).contains("20 mm"), "ni entra en la brida")
	# La tabla de EN 12413 sigue mandando en los discos de EN 12413 sin rpm propias (Ø230 del disco fino)
	assert_eq(Radial.disc_check({ "diameter_mm": 230.0, "rpm": 6600.0, "disc_id": "fino_1mm" })["limit_rpm"], 6650.0, "disco de EN 12413: la tabla")


## Fase 2: banda de la energía del acero al carbono con las medidas de Awan et al. (2021) y holgura medida del surco.
func test_banda_de_energia_y_de_surco() -> void:
	var base := { "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "thickness_mm": 3.0, "feed_mm_s": 5.0 }
	var steel := Radial.cut_off(_with(base, { "work_kind": "acero" }))
	var q: float = steel["q_mm3_s"]
	var band: Array = steel["specific_energy_band_j_mm3"]
	assert_true(band[0] <= steel["specific_energy_j_mm3"] and steel["specific_energy_j_mm3"] <= band[1], "la banda contiene la energía del modelo")
	var s235: Dictionary = Radial.CUT_ENERGY_2021["s235jr"]
	var c45k: Dictionary = Radial.CUT_ENERGY_2021["c45k"]
	assert_near(band[1], s235["sce"] + (s235["psl_w"] + s235["ppl_w"]) / q, 1e-12, 0.0, "arriba, el S235JR (barras de 3 mm)")
	assert_near(band[0], c45k["sce"] + (c45k["psl_w"] + c45k["ppl_w"]) / q, 1e-12, 0.0, "abajo, el C45K")
	assert_true(band[1] > 1.5 * band[0], "dispersión grande entre medidas: %s-%s J/mm³" % [band[0], band[1]])
	var inox := Radial.cut_off(_with(base, { "work_kind": "inox" }))
	assert_eq(inox["specific_energy_band_j_mm3"], [inox["specific_energy_j_mm3"], inox["specific_energy_j_mm3"]], "inox: una sola medida")
	var alu: Array = Radial.cut_off(_with(base, { "work_kind": "aluminio", "disc_id": "corte_alu" }))["specific_energy_band_j_mm3"]
	assert_true(alu[1] > alu[0], "aluminio: entre el 1100 y el 7075")
	# Surco: 1 mm de disco → 1,3-1,5 mm (Sensors 2022) y 1,8 mm (Adv. Manuf. 2021); el modelo usa 1,4
	var kb: Array = steel["kerf_band_mm"]
	assert_near(kb[0], 1.3, 1e-12, 0.0, "surco mínimo medido")
	assert_near(kb[1], 1.8, 1e-12, 0.0, "surco máximo medido")
	assert_true(kb[0] <= steel["kerf_mm"] and steel["kerf_mm"] <= kb[1], "el surco del modelo, dentro")
	var none := Radial.cut_off(_with(base, { "rpm": 0.0 }))
	assert_eq(none["specific_energy_band_j_mm3"], [0.0, 0.0], "sin corte, sin energía")


func test_numeros_en_espanol() -> void:
	assert_eq(Radial._fmt(12250.0), "12.250", "punto de miles")
	assert_eq(Radial._fmt(1.5, 1), "1,5", "coma decimal")
	assert_eq(Radial._fmt(-1234.5, 1), "-1.234,5", "negativos")
	assert_eq(Radial._fmt(INF), "∞", "infinito")


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


static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var d := base.duplicate()
	d.merge(extra, true)
	return d
