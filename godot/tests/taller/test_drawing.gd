## Taller · planos, tolerancias ISO e inspección (unidad 5).
extends "res://tests/case.gd"

const Drawing = preload("res://core/taller/drawing.gd")
const Inspection = preload("res://core/taller/inspection.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")

const DZ := 0.02


## Perfil de la pieza al nominal (Ra de 0,8 µm en lo mecanizado) y copia editable de sus radios.
func _ideal(id: String) -> Dictionary:
	return Drawing.make_profile(Drawing.get_drawing(id), DZ, 0.8)


func _z(p: Dictionary, i: int) -> float:
	return float(p["z0"]) + i * float(p["dz"])


## Aplica f(z, r) -> r a los anillos con z en [za, zb].
func _edit(p: Dictionary, za: float, zb: float, f: Callable) -> void:
	var r: PackedFloat64Array = p["r"]
	for i in r.size():
		var z := _z(p, i)
		if z >= za - 1e-9 and z <= zb + 1e-9:
			r[i] = f.call(z, r[i])
	p["r"] = r


func _feature(res: Dictionary, id: String) -> Dictionary:
	for f in res["features"]:
		if f["id"] == id:
			return f
	fail("no aparece la cota %s" % id)
	return {}


func _ra_zone(res: Dictionary, zone: String) -> Dictionary:
	for z in res["ra"]:
		if z["zone"] == zone:
			return z
	fail("no aparece la zona de Ra %s" % zone)
	return {}


# --- ISO 286 e ISO 2768 -------------------------------------------------------------------------------------


func test_iso286_del_contrato() -> void:
	var h9a := Drawing.shaft_tolerance("h9", 30.0)
	assert_eq([h9a["upper_um"], h9a["lower_um"]], [0.0, -52.0], "h9 de 18 a 30 mm")
	var h9b := Drawing.shaft_tolerance("h9", 40.0)
	assert_eq([h9b["upper_um"], h9b["lower_um"]], [0.0, -62.0], "h9 de 30 a 50 mm")
	var h8 := Drawing.shaft_tolerance("h8", 24.0)
	assert_eq([h8["upper_um"], h8["lower_um"]], [0.0, -33.0], "h8 de 18 a 30 mm")
	var js9 := Drawing.shaft_tolerance("js9", 36.0)
	assert_eq([js9["upper_um"], js9["lower_um"]], [31.0, -31.0], "js9 de 30 a 50 mm")


func test_tabla_it_de_iso_286() -> void:
	# ISO 286-1:2010, tabla 1 (grupos «de más de … hasta … incluido»)
	var rows := {
		6: [6, 8, 9, 11, 13, 16, 19, 22], 7: [10, 12, 15, 18, 21, 25, 30, 35], 8: [14, 18, 22, 27, 33, 39, 46, 54],
		9: [25, 30, 36, 43, 52, 62, 74, 87], 10: [40, 48, 58, 70, 84, 100, 120, 140],
		11: [60, 75, 90, 110, 130, 160, 190, 220],
	}
	var sizes := [2.0, 5.0, 8.0, 15.0, 25.0, 40.0, 60.0, 100.0]
	for grade in rows:
		for i in sizes.size():
			assert_eq(Drawing.it_um(grade, sizes[i]), float(rows[grade][i]), "IT%d a %s mm" % [grade, sizes[i]])
	assert_eq(Drawing.it_um(9, 30.0), 52.0, "30 mm cae en el grupo 18-30")
	assert_eq(Drawing.it_um(9, 30.001), 62.0, "un pelo más cae en 30-50")
	assert_eq(Drawing.it_um(6, 3.0), 6.0, "3 mm cae en el primer grupo")
	assert_eq(Drawing.it_um(11, 120.0), 220.0, "120 mm es el último de la tabla")
	assert_true(is_nan(Drawing.it_um(9, 121.0)), "fuera de la tabla")
	assert_true(is_nan(Drawing.it_um(12, 50.0)), "grado fuera de la tabla")
	assert_true(Drawing.shaft_tolerance("g6", 30.0).is_empty(), "solo h y js")
	var js7 := Drawing.shaft_tolerance("js7", 25.0)
	assert_eq([js7["upper_um"], js7["lower_um"]], [10.5, -10.5], "js7 de 18-30: ±IT/2 sin redondeo")


func test_tolerancias_generales_iso_2768_m() -> void:
	var cases := [
		["linear", 2.0, 100.0], ["linear", 5.0, 100.0], ["linear", 20.0, 200.0], ["linear", 30.0, 200.0],
		["linear", 40.0, 300.0], ["linear", 150.0, 500.0], ["edge", 0.5, 200.0], ["edge", 1.0, 200.0],
		["edge", 5.0, 500.0], ["edge", 10.0, 1000.0],
	]
	for c in cases:
		var t := Drawing.general_tolerance(c[0], c[1])
		assert_eq([t["upper_um"], t["lower_um"]], [c[2], -float(c[2])], "ISO 2768-m %s de %s mm" % [c[0], c[1]])
	assert_true(Drawing.general_tolerance("linear", 0.3).is_empty(), "por debajo de 0,5 mm no hay tolerancia general")
	assert_eq(Drawing.general_tolerance("linear", 20.0, "f")["upper_um"], 100.0, "clase fina")


# --- planos ---------------------------------------------------------------------------------------------------


func test_planos_coherentes_con_el_contrato() -> void:
	for d in Drawing.drawings():
		assert_false(WorkMaterials.get_material(d["material"]).is_empty(), "%s: material del catálogo" % d["id"])
		var contour: Array = d["contour"]
		assert_eq(float(contour[0]["z_hi"]), 0.0, "%s: el contorno empieza en la cara" % d["id"])
		var length_mm: float = d["stock"]["length_mm"]
		assert_eq(float(contour[contour.size() - 1]["z_lo"]), -length_mm, "%s: y acaba en el extremo del bruto" % d["id"])
		for i in range(1, contour.size()):
			assert_eq(contour[i]["z_hi"], contour[i - 1]["z_lo"], "%s: contorno continuo" % d["id"])
		var stock_r: float = float(d["stock"]["d_mm"]) / 2.0
		assert_eq(Drawing.nominal_radius(d, -length_mm + 1.0), stock_r, "%s: el bruto en el plato" % d["id"])
		for f in d["features"]:
			assert_true(is_finite(f["tol"]["upper_um"]) and is_finite(f["tol"]["lower_um"]), "%s: tolerancia" % f["id"])
			assert_true(f["iso"] != "", "%s: norma de la tolerancia" % f["id"])
			var zm := (float(f["z_from"]) + float(f["z_to"])) / 2.0
			match str(f["kind"]):
				"diameter":
					var dia := 2.0 * Drawing.nominal_radius(d, zm)
					assert_near(dia, f["nominal"], 1e-12, 0.0, "%s: el contorno tiene ese diámetro" % f["id"])
				"cone":
					var d_to := 2.0 * Drawing.nominal_radius(d, f["z_to"] + 1e-6)
					var d_from := 2.0 * Drawing.nominal_radius(d, f["z_from"] - 1e-6)
					assert_near(d_to, f["nominal"], 1e-5, 0.0, "%s: diámetro final" % f["id"])
					assert_near(d_from, f["nominal_from"], 1e-5, 0.0, "%s: diámetro inicial" % f["id"])
				"length":
					var span := float(f["z_from"]) - float(f["z_to"])
					assert_near(f["nominal"], span, 1e-12, 0.0, "%s: longitud desde la cara" % f["id"])
	var a := Drawing.get_drawing("A")
	assert_eq(_tol_of(a, "A-D30"), [0.0, -52.0], "A: Ø30 h9")
	assert_eq(_tol_of(a, "A-D40"), [0.0, -62.0], "A: Ø40 h9")
	assert_eq(_tol_of(a, "A-D46"), [100.0, -100.0], "A: Ø46 ±0,1")
	var b := Drawing.get_drawing("B")
	assert_eq(_tol_of(b, "B-D24"), [0.0, -33.0], "B: Ø24 h8")
	assert_eq(_tol_of(b, "B-D36"), [31.0, -31.0], "B: Ø36 js9")
	assert_eq(a["material"], "c45e", "A es de C45E")
	assert_eq(b["material"], "al6082_t6", "B es de EN AW-6082 T6")


func _tol_of(d: Dictionary, id: String) -> Array:
	for f in d["features"]:
		if f["id"] == id:
			return [f["tol"]["upper_um"], f["tol"]["lower_um"]]
	return []


func test_target_profile_en_la_rejilla_del_contrato() -> void:
	var a := Drawing.get_drawing("A")
	var g := Drawing.profile_grid(a, DZ)
	assert_eq(g["z0"], -84.0, "A: la rejilla empieza en el extremo del bruto (cara del bruto en Z+1, CONTRATOS.md)")
	assert_eq(g["count"], 4251, "85 mm cada 0,02 mm, con los dos extremos")
	var r := Drawing.target_profile(a, DZ)
	assert_eq(r.size(), 4251, "un radio por anillo")
	var at := func(z: float) -> float: return r[int(roundf((z + 84.0) / DZ))]
	assert_eq(at.call(0.5), 0.0, "delante de la cara: la creces de refrentado, que se quita")
	assert_eq(at.call(0.0), 14.0, "cara: chaflán 1×45° sobre el Ø30")
	assert_near(at.call(-0.5), 14.5, 1e-9, 0.0, "a media altura del chaflán")
	assert_eq(at.call(-10.0), 15.0, "Ø30")
	assert_eq(at.call(-20.0), 20.0, "en el hombro manda la cara del Ø40")
	assert_eq(at.call(-30.0), 20.0, "Ø40")
	assert_eq(at.call(-50.0), 23.0, "Ø46")
	assert_eq(at.call(-58.0), 25.0, "collar de bruto antes del plato")
	assert_eq(at.call(-80.0), 25.0, "bruto dentro del plato")
	var b := Drawing.get_drawing("B")
	var rb := Drawing.target_profile(b, DZ)
	var atb := func(z: float) -> float: return rb[int(roundf((z + 69.0) / DZ))]
	assert_near(atb.call(-14.0), 14.0 - sqrt(3.0), 1e-9, 0.0, "B: redondeo R2 a 1 mm del hombro")
	assert_eq(atb.call(-15.0), 18.0, "B: hombro del Ø36")
	assert_near(atb.call(-40.0), 18.5, 1e-9, 0.0, "B: mitad del cono")
	assert_eq(atb.call(-45.0), 20.0, "B: fin del cono contra el bruto Ø40")
	var custom := Drawing.target_profile(a, 0.05, -60.0, 200)
	assert_eq(custom.size(), 200, "rejilla a medida")
	assert_eq(custom[0], 25.0, "z0 = −60: el collar de bruto")
	assert_eq(custom[199], 23.0, "z = −60 + 199·0,05 = −50,05: el Ø46")


# --- inspección -----------------------------------------------------------------------------------------------


func test_perfil_ideal_aprueba() -> void:
	for id in ["A", "B"]:
		var d := Drawing.get_drawing(id)
		var res := Inspection.inspect_part(_ideal(id), d)
		assert_true(res["passed"], "%s: la pieza al nominal aprueba" % id)
		assert_eq(res["score"], 10.0, "%s: nota 10" % id)
		for f in res["features"]:
			assert_true(f["ok"], "%s: %s dentro de tolerancia (medido %s)" % [id, f["id"], str(f["measured"])])
			assert_true(absf(f["deviation_um"]) < 20.0, "%s: %s casi exacto" % [id, f["id"]])
		for z in res["ra"]:
			assert_true(z["ok"], "%s: Ra de %s" % [id, z["zone"]])
		var worst := 0.0
		for v in res["deviation_map"]:
			worst = maxf(worst, absf(v))
		assert_true(worst < 1e-3, "%s: mapa de desviación a cero (máx. %s µm)" % [id, str(worst)])
		assert_eq(res["face_z"], 0.0, "%s: la cara en Z0" % id)


func test_pasado_en_el_d40_suspende_esa_cota() -> void:
	var p := _ideal("A")
	_edit(p, -39.99, -20.0, func(_z: float, _r: float) -> float: return 19.95)  # Ø39,9: 0,1 mm pasado
	var res := Inspection.inspect_part(p, Drawing.get_drawing("A"))
	var d40 := _feature(res, "A-D40")
	assert_false(d40["ok"], "Ø40 h9 suspende")
	assert_near(d40["measured"], 39.9, 1e-9, 0.0, "mide Ø39,9")
	assert_near(d40["deviation_um"], -100.0, 1e-6, 0.0, "−100 µm")
	for f in res["features"]:
		if f["id"] != "A-D40":
			assert_true(f["ok"], "el resto sigue bien: %s" % f["id"])
	assert_false(res["passed"], "la pieza no pasa")
	assert_true(res["score"] < 10.0 and res["score"] > 7.0, "nota %s: pierde la cota doble" % str(res["score"]))
	var dev: PackedFloat32Array = res["deviation_map"]
	var state: PackedByteArray = res["ring_state"]
	for i in dev.size():
		var z := _z(p, i)
		if z > -39.97 and z < -20.03:
			assert_near(dev[i], -50.0, 1e-3, 0.0, "anillo z = %s: −50 µm de radio" % str(z))
		elif z > -19.97 or z < -40.03:
			assert_near(dev[i], 0.0, 0.0, 1e-3, "anillo z = %s: sin desviación" % str(z))
		if z >= -39.9 and z <= -20.1:
			assert_eq(state[i], 2, "anillo z = %s: pasado" % str(z))
		elif z > -19.9 or z < -40.1:
			assert_eq(state[i], 0, "anillo z = %s: bien" % str(z))


func test_sobra_material_se_puede_repasar() -> void:
	var p := _ideal("A")
	_edit(p, -19.99, -1.0, func(_z: float, _r: float) -> float: return 15.1)  # Ø30,2
	var res := Inspection.inspect_part(p, Drawing.get_drawing("A"))
	var d30 := _feature(res, "A-D30")
	assert_false(d30["ok"], "Ø30,2 no cumple h9")
	assert_near(d30["deviation_um"], 200.0, 1e-6, 0.0, "+200 µm")
	var dev: PackedFloat32Array = res["deviation_map"]
	var i := int(roundf((-10.0 + 85.0) / DZ))
	assert_near(dev[i], 100.0, 1e-3, 0.0, "+100 µm de radio: sobra material")
	assert_eq(res["ring_state"][i], 1, "estado: sobra material")


func test_rugosidad_regla_del_16_por_ciento() -> void:
	var d := Drawing.get_drawing("A")
	for share in [[10, true], [20, false]]:
		var p := _ideal("A")
		var ra: PackedFloat32Array = p["ring_ra"]
		var k := 0
		var every := int(100.0 / float(share[0]))
		for i in ra.size():
			var z := _z(p, i)
			if z >= -39.9 and z <= -20.1:
				if k % every == 0:
					ra[i] = 2.0
				k += 1
		p["ring_ra"] = ra
		var z40 := _ra_zone(Inspection.inspect_part(p, d), "A-D40")
		assert_eq(z40["ok"], share[1], "%d %% de anillos con Ra 2,0 > 1,6" % share[0])
		assert_eq(z40["measured"] <= z40["required"], share[1], "el percentil 84 decide igual que la regla")
	var none := _ideal("A")
	none.erase("ring_ra")
	var res := Inspection.inspect_part(none, d)
	assert_false(_ra_zone(res, "A-D40")["ok"], "sin Ra medida no se da por buena")


func test_longitud_y_chaflan() -> void:
	var d := Drawing.get_drawing("A")
	var p := _ideal("A")
	_edit(p, -20.6, -20.0, func(_z: float, _r: float) -> float: return 15.0)  # el hombro se va 0,6 mm hacia el plato
	var res := Inspection.inspect_part(p, d)
	var l20 := _feature(res, "A-L20")
	assert_false(l20["ok"], "20 ± 0,2 no se cumple")
	assert_near(l20["measured"], 20.62, 1e-9, 0.0, "mide 20,62 (primer anillo con el Ø40)")
	assert_true(_feature(res, "A-L40")["ok"], "la cota absoluta del siguiente hombro sigue bien")
	var p2 := _ideal("A")
	_edit(p2, -2.0, 0.0, func(z: float, _r: float) -> float: return 13.0 - z)  # chaflán 2×45°
	var res2 := Inspection.inspect_part(p2, d)
	var ch := _feature(res2, "A-CH1")
	assert_false(ch["ok"], "chaflán 2×45° fuera de 1 ± 0,2")
	assert_near(ch["measured"], 2.0, 1e-9, 0.0, "mide 2 mm")
	assert_true(_feature(res2, "A-L20")["ok"], "la longitud no depende del chaflán")


func test_pieza_b_radio_cono_y_quiebro() -> void:
	var d := Drawing.get_drawing("B")
	var res := Inspection.inspect_part(_ideal("B"), d)
	assert_near(_feature(res, "B-R2")["measured"], 2.0, 0.01, 0.0, "R2 medido")
	var cone := _feature(res, "B-CONE")
	assert_near(cone["measured"], 38.0, 1e-9, 0.0, "cono: Ø38 al final")
	assert_near(cone["measured_from"], 36.0, 1e-9, 0.0, "cono: Ø36 al principio")
	assert_near(_feature(res, "B-L35")["measured"], 35.0, 1e-9, 0.0, "inicio del cono por el quiebro")
	var sharp := _ideal("B")
	_edit(sharp, -14.99, -13.0, func(_z: float, _r: float) -> float: return 12.0)  # rincón vivo
	var rs := Inspection.inspect_part(sharp, d)
	assert_false(_feature(rs, "B-R2")["ok"], "sin redondeo no hay R2")
	assert_true(_feature(rs, "B-R2")["measured"] < 0.5, "mide casi 0")
	var cyl := _ideal("B")
	_edit(cyl, -44.99, -35.0, func(_z: float, _r: float) -> float: return 18.0)  # el cono se quedó en Ø36
	var rc := Inspection.inspect_part(cyl, d)
	assert_false(_feature(rc, "B-CONE")["ok"], "sin cono no hay Ø38")
	assert_near(_feature(rc, "B-CONE")["deviation_um"], -2000.0, 1e-6, 0.0, "−2 mm en el extremo grande")


func test_rejilla_desplazada_medio_anillo() -> void:
	# El torno puede poner sus anillos en otra rejilla: la pieza al nominal tiene que seguir aprobando.
	var d := Drawing.get_drawing("A")
	var p := Drawing.make_profile(d, DZ, 0.8, -84.99, 4250)
	var res := Inspection.inspect_part(p, d)
	for f in res["features"]:
		assert_true(f["ok"], "%s con la rejilla desplazada (medido %s)" % [f["id"], str(f["measured"])])
	var worst := 0.0
	for v in res["deviation_map"]:
		worst = maxf(worst, absf(v))
	assert_true(worst < 1e-3, "el mapa no pinta falsos escalones (máx. %s µm)" % str(worst))


func test_perfil_vacio_no_rompe() -> void:
	var d := Drawing.get_drawing("A")
	var p := Drawing.make_profile(d, DZ)
	var r: PackedFloat64Array = p["r"]
	r.fill(0.0)
	p["r"] = r
	var res := Inspection.inspect_part(p, d)
	assert_false(res["passed"], "sin pieza no se aprueba")
	assert_eq(res["score"], 0.0, "nota 0")
	assert_true(is_nan(res["face_z"]), "no hay cara")


# --- casos de la revisión de código ------------------------------------------------------------------------


func test_escalon_con_niveles_medidos() -> void:
	# Ø46 sin terminar (queda Ø48): el escalón de Z−55 sigue ahí y la longitud se mide bien
	var d := Drawing.get_drawing("A")
	var p := _ideal("A")
	_edit(p, -54.99, -40.0, func(_z: float, _r: float) -> float: return 24.0)
	var res := Inspection.inspect_part(p, d)
	assert_false(_feature(res, "A-D46")["ok"], "el Ø48 no es Ø46 ±0,1")
	var l55 := _feature(res, "A-L55")
	assert_true(l55["ok"], "pero el escalón está en su sitio")
	assert_near(l55["measured"], 55.0, 1e-9, 0.0, "55 mm")
	# Ø40 torneado a Ø34: el hombro de Z−20 se mide aunque el diámetro no se parezca al del plano
	var p2 := _ideal("A")
	_edit(p2, -39.99, -20.0, func(_z: float, _r: float) -> float: return 17.0)
	assert_near(_feature(Inspection.inspect_part(p2, d), "A-L20")["measured"], 20.0, 1e-9, 0.0, "L20 con Ø34")


func test_barra_en_bruto_suspende_todo() -> void:
	var d := Drawing.get_drawing("A")
	var p := _ideal("A")
	var r: PackedFloat64Array = p["r"]
	var ring_pass: PackedByteArray = p["ring_pass"]
	var ring_ra: PackedFloat32Array = p["ring_ra"]
	r.fill(25.0)
	ring_pass.fill(0)
	ring_ra.fill(0.0)
	p["r"] = r
	p["ring_pass"] = ring_pass
	p["ring_ra"] = ring_ra
	var res := Inspection.inspect_part(p, d)
	for f in res["features"]:
		assert_false(f["ok"], "%s no se cumple en bruto" % f["id"])
	for f in ["A-L20", "A-L40", "A-L55"]:
		assert_true(is_nan(_feature(res, f)["measured"]), "%s: sin escalón no hay longitud" % f)
	for z in res["ra"]:
		assert_false(z["ok"], "%s: una superficie sin mecanizar no cumple su Ra" % z["zone"])
		assert_eq(z["machined_rings"], 0, "%s: ningún anillo mecanizado" % z["zone"])
	assert_eq(res["score"], 0.0, "nota 0")


func test_ranura_se_detecta_este_donde_este() -> void:
	# Ranura de 1,9 mm de ancho y 0,5 mm de profundidad en el Ø40 h9, en dos posiciones distintas
	var d := Drawing.get_drawing("A")
	for start in [-39.85, -38.95]:
		var p := _ideal("A")
		_edit(p, start, start + 1.9, func(_z: float, _r: float) -> float: return 19.5)
		var res := Inspection.inspect_part(p, d)
		var d40 := _feature(res, "A-D40")
		assert_false(d40["ok"], "ranura desde z = %s: Ø40 suspende" % str(start))
		assert_near(d40["measured"], 39.0, 1e-9, 0.0, "mide Ø39 en la ranura")
		assert_false(res["passed"], "la pieza no pasa")
	# una ranura más estrecha que el palpador (0,5 mm) no cambia el tamaño medido: es un límite del método
	var narrow := _ideal("A")
	_edit(narrow, -30.25, -29.75, func(_z: float, _r: float) -> float: return 19.5)
	assert_true(_feature(Inspection.inspect_part(narrow, d), "A-D40")["ok"], "el palpador de 1 mm la puentea")


func test_rugosidad_justo_en_el_limite() -> void:
	var d := Drawing.get_drawing("A")
	var at_32 := Inspection.inspect_part(Drawing.make_profile(d, DZ, 3.2), d)
	assert_true(_ra_zone(at_32, "A-D30")["ok"], "Ra 3,2 en una zona de Ra 3,2 cumple (float32)")
	assert_false(_ra_zone(at_32, "A-D40")["ok"], "pero no en la de Ra 1,6")
	var at_16 := Inspection.inspect_part(Drawing.make_profile(d, DZ, 1.6), d)
	assert_true(at_16["passed"], "Ra 1,6 en todas partes aprueba")


## Rosca M20×2,5 de la pieza C: un perfil sintético con el perfil básico de ISO 68-1 (surcos en V de 60° con fondo
## redondeado de radio H/6) cada paso, a la profundidad I desde el Ø torneado, se mide con los valores de la norma.
func test_rosca_de_la_pieza_c() -> void:
	var d := Drawing.get_drawing("C")
	assert_false(d.is_empty(), "hay plano C")
	var th: Dictionary = d["thread"]
	assert_near(th["d2_mm"], 18.376, 0.0, 5e-4, "d2 básico de M20×2,5 (ISO 724)")
	assert_near(th["d3_mm"], 16.933, 0.0, 5e-4, "d3 básico")
	assert_near(th["h3_mm"], 0.6134 * 2.5, 0.0, 5e-4, "h3 = 0,6134·P")
	for depth in [1.49, 1.45]:
		var p := Drawing.make_profile(d, DZ, 1.6)
		var r_top := 19.79 / 2.0
		var r_root: float = r_top - float(depth)
		var pitch := 2.5
		var re := 0.8660254037844386 * pitch / 6.0
		var t30 := tan(deg_to_rad(30.0))
		# V de 60° con el fondo redondeado: surcos centrados en z = −1,25 − k·P hasta Z−22
		_edit(p, -24.0, -1.5, func(z: float, _r: float) -> float:
			var best := r_top
			for k in 10:
				var zc := -1.25 - k * pitch
				if zc < -22.0:
					break
				var u := absf(z - zc)
				var y: float
				if u <= re * cos(deg_to_rad(30.0)):
					y = r_root + re - sqrt(re * re - u * u)
				else:
					y = r_root + re - re / sin(deg_to_rad(30.0)) + u / t30
				best = minf(best, y)
			return minf(best, r_top))
		var res := Inspection.inspect_part(p, d)
		var want_d2: float = 2.0 * (r_root + re - re / sin(deg_to_rad(30.0)) + 0.25 * pitch / t30)
		assert_near(_feature(res, "C-M20-D")["measured"], 19.79, 0.0, 1e-9, "Ø exterior sobre las crestas")
		assert_near(_feature(res, "C-M20-D3")["measured"], 2.0 * r_root, 0.0, 1e-3, "Ø de fondo (I = %s)" % depth)
		assert_near(_feature(res, "C-M20-P")["measured"], pitch, 0.0, 1e-6, "paso")
		assert_near(_feature(res, "C-M20-D2")["measured"], want_d2, 0.0, 2e-3, "Ø medio: el surco mide P/2 (I = %s)" % depth)
		assert_near(_feature(res, "C-M20-L")["measured"], 1.25 + 8.0 * pitch, 0.0, 1e-6, "rosca completa hasta el último surco")
	# sin rosca (el cilindro torneado, sin roscar) no hay nada que medir: la rosca suspende
	var blank := Inspection.inspect_part(Drawing.make_profile(d, DZ, 1.6), d)
	assert_false(_feature(blank, "C-M20-D2")["ok"], "sin roscar no hay Ø medio")
	assert_false(blank["passed"])


func test_refrentado_sin_superficie_fantasma() -> void:
	var d := Drawing.get_drawing("A")
	d["stock"]["face_allowance_mm"] = 1.0
	var p := Drawing.make_profile(d, DZ, 0.8)
	var r: PackedFloat64Array = p["r"]
	var ring_ra: PackedFloat32Array = p["ring_ra"]
	var last := r.size() - 1
	assert_eq(float(p["z0"]) + last * DZ, 1.0, "la rejilla llega a la cara del bruto")
	assert_eq(r[last], 0.0, "el milímetro refrentado ya no tiene material")
	assert_eq(ring_ra[last], 0.0, "ni rugosidad")
	assert_true(Inspection.inspect_part(p, d)["passed"], "y la pieza al nominal sigue aprobando")
