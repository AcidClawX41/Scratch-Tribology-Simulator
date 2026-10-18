## Taller · física de la viruta (core/taller/chips.gd, fase 2): rotura según el Spanformdiagramm del Tabellenbuch
## (p. 204), formas y Spanraumzahl (p. 203) y filo recrecido. La emisión y el vuelo de las virutas los prueba
## tests/taller/test_lathe_mesh.gd.
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const Chips = preload("res://core/taller/chips.gd")


func _brk(f: float, ap: float, extra: Dictionary = {}) -> Dictionary:
	var p := { "work_id": "c45e", "f_mm": f, "ap_mm": ap, "vc": 200.0 }
	p.merge(extra, true)
	return Chips.chip_breaking(p)


## Zonas del diagrama del TZ (C45 a 200 m/min): desbaste típico, acabado fino, sin datos por arriba.
func test_diagrama_de_rotura_del_tabellenbuch() -> void:
	var rough := _brk(0.3, 3.0)
	assert_eq(rough["zone"], "favorable", "ap 3, f 0,3: viruta favorable")
	assert_eq(rough["tz_class"], "favorable", "clase del TZ")
	assert_eq(rough["form"], "rizada", "se dibuja rizada (rota)")
	assert_eq(rough["quality"], "secondary", "C45 a 200 m/min: la figura del TZ")
	assert_true(_brk(0.3, 2.0)["surface_ok"], "ap 2, f 0,3: también cumple el criterio de superficie")
	var heavy := _brk(0.5, 5.0)
	assert_eq(heavy["zone"], "favorable", "ap 5, f 0,5: rompe")
	assert_false(heavy["surface_ok"], "pero fuera del criterio de superficie")
	for c in [[0.1, 0.5], [0.1, 3.0], [0.14, 3.55], [0.3, 0.8]]:
		var r := _brk(c[0], c[1])
		assert_eq(r["zone"], "viruta_larga", "f %s, ap %s: viruta larga" % [Js.js_num_str(c[0]), Js.js_num_str(c[1])])
		assert_eq(r["tz_form"], "enredada", "enredada (desfavorable)")
		assert_eq(r["form"], "espiral", "se dibuja larga")
	for c in [[0.4, 7.0], [0.75, 3.0], [0.8, 0.5]]:
		assert_eq(_brk(c[0], c[1])["zone"], "fuera_del_diagrama", "f %s, ap %s: por encima del diagrama" % [Js.js_num_str(c[0]), Js.js_num_str(c[1])])
	assert_true(String(rough["source"]).contains("p. 204") and String(rough["source"]).contains("p. 203"), "cita el diagrama y la Spanraumzahl")
	# Vértices digitalizados, dentro de la cuadrícula de la figura
	for poly in [Chips.TZ_BREAK_ZONE_C45, Chips.TZ_SURFACE_ZONE_C45]:
		for v in poly:
			assert_true(v[0] >= 1.0 and v[0] <= 6.0 and v[1] >= 0.15 and v[1] <= 0.71, "vértice %s dentro de la figura" % str(v))
	# El borde cuenta como dentro: la esquina inferior izquierda (ap 1, f 0,2) es favorable
	assert_eq(_brk(0.2, 1.0)["zone"], "favorable", "esquina de la zona")


## A ap fija, al subir el avance se pasa de viruta larga a favorable y después a sin datos, sin volver atrás.
func test_mas_avance_rompe_la_viruta() -> void:
	for ap in [1.5, 3.0, 5.5]:
		var order := ["viruta_larga", "favorable", "fuera_del_diagrama"]
		var last := 0
		for i in range(1, 80):
			var f := i * 0.01
			var z := order.find(_brk(f, ap)["zone"])
			assert_true(z >= last, "ap %s, f %s: la zona no retrocede" % [Js.js_num_str(ap), Js.js_num_str(f)])
			last = z
		assert_eq(last, 2, "ap %s: acaba por encima del diagrama" % Js.js_num_str(ap))


## Spanraumzahl del TZ (p. 203): la viruta enredada ocupa mucho más que la rota.
func test_spanraumzahl() -> void:
	assert_eq(Chips.TZ_CHIP_FORMS["enredada"]["r_min"], 90.0, "enredada ≥ 90")
	assert_eq(Chips.TZ_CHIP_FORMS["helicoidal_corta"]["r_min"], 25.0, "helicoidal corta ≥ 25")
	assert_eq(Chips.TZ_CHIP_FORMS["fragmentos"]["r_min"], 3.0, "fragmentos ≥ 3")
	assert_true(_brk(0.1, 3.0)["chip_ratio_min"] > _brk(0.3, 3.0)["chip_ratio_min"], "la viruta larga llena antes la bandeja")
	var classes := {}
	for k in Chips.TZ_CHIP_FORMS:
		classes[Chips.TZ_CHIP_FORMS[k]["class"]] = true
	assert_eq(classes.keys().size(), 3, "tres clases del TZ: desfavorable, aceptable y favorable")


## Otros materiales: sin diagrama, la forma de su grupo; otro acero u otra vc, estimación.
func test_otros_materiales_y_calidad() -> void:
	var alu := Chips.chip_breaking({ "work_id": "al6082_t6", "f_mm": 0.2, "ap_mm": 2.0, "vc": 400.0 })
	assert_eq(alu["zone"], "sin_datos", "aluminio: sin diagrama del TZ")
	assert_eq(alu["form"], "espiral", "forma típica del aluminio")
	assert_eq(Chips.chip_breaking({ "kind": "fundicion", "f_mm": 0.2, "ap_mm": 2.0 })["form"], "astillada", "fundición")
	assert_eq(_brk(0.3, 3.0, { "vc": 100.0 })["quality"], "estimate", "C45 a 100 m/min: la figura es de 200")
	assert_eq(_brk(0.3, 3.0, { "work_id": "s235jr" })["quality"], "estimate", "otro acero: estimación")
	assert_eq(_brk(0.0, 3.0)["zone"], "sin_datos", "sin avance no hay viruta")
	assert_eq(Chips.form_for_cut("acero", 0.3, 3.0, 200.0), "rizada", "acero favorable → rizada")
	assert_eq(Chips.form_for_cut("acero", 0.08, 0.5, 200.0), "espiral", "acero de acabado fino → larga")
	assert_eq(Chips.form_for_cut("laton", 0.08, 0.5, 200.0), Chips.form_for("laton"), "latón: la de su grupo")
	# La API que ya usaban la escena y test_lathe_mesh.gd no cambia
	assert_eq(Chips.form_for("acero"), "rizada", "form_for del acero")


## Filo recrecido: materiales pegajosos a vc baja (Sandvik); umbral: el mínimo del intervalo de vc de la herramienta.
func test_filo_recrecido() -> void:
	var low := Chips.bue_risk({ "work_id": "c45e", "tool_id": "hm", "vc": 50.0 })
	assert_true(low["risk"], "C45E con metal duro a 50 m/min (mínimo del TZ: 60)")
	assert_eq(low["vc_limit"], 60.0, "umbral: 60 m/min (TZ, p. 208)")
	assert_true(String(low["message"]).contains("filo recrecido"), "aviso en español")
	assert_false(Chips.bue_risk({ "work_id": "c45e", "tool_id": "hm", "vc": 150.0 })["risk"], "a 150 m/min, no")
	# Ahmed et al. (2017): AISI 304 con metal duro sin recubrir, filo recrecido a 60 m/min
	assert_true(Chips.bue_risk({ "work_id": "x5crni18_10", "tool_id": "hm", "vc": 60.0 })["risk"], "304 a 60 m/min")
	assert_false(Chips.bue_risk({ "work_id": "x5crni18_10", "tool_id": "hm", "vc": 140.0 })["risk"], "304 a 140 m/min, no")
	assert_true(Chips.bue_risk({ "work_id": "al6082_t6", "tool_id": "hm", "vc": 150.0 })["risk"], "aluminio con metal duro a 150 m/min")
	assert_true(Chips.bue_risk({ "work_id": "c45e", "tool_id": "hss_m2", "vc": 20.0 })["risk"], "HSS a 20 m/min en acero")
	assert_false(Chips.bue_risk({ "work_id": "c45e", "tool_id": "hss_m2", "vc": 45.0 })["risk"], "HSS a 45 m/min, no")
	for id in ["gjl250", "cuzn39pb3"]:
		var r := Chips.bue_risk({ "work_id": id, "tool_id": "hm", "vc": 20.0 })
		assert_false(r["risk"], "%s no es pegajoso" % id)
		assert_true(String(r["message"]).contains("no es un material pegajoso"), "%s: lo explica" % id)
	var none := Chips.bue_risk({ "work_id": "c45e", "tool_id": "pcd", "vc": 20.0 })
	assert_false(none["risk"], "PCD en acero: sin intervalo de vc, no se evalúa")
	assert_eq(none["vc_limit"], null, "sin umbral")
	assert_eq(Chips.bue_risk({ "work_id": "c45e", "tool_id": "hm", "vc": 0.0 })["risk"], false, "parado no hay viruta")
	assert_true(String(low["source"]).contains("Sandvik") and String(low["source"]).contains("10.3390/ma10111230"), "fuentes")
