## Chispas de la radial (core/taller/sparks.gd): determinismo, materiales que no dan chispas, efecto de la
## velocidad periférica, colores y estallidos por material (ensayo de chispas, TC 9-237, tabla 7-5), y que las
## escenas que las dibujan cargan sin ventana.
extends "res://tests/case.gd"

const Sparks = preload("res://core/taller/sparks.gd")
const Radial = preload("res://core/taller/radial.gd")

const DT := 1.0 / 60.0
const EXPOSURE := 1.0 / 60.0
const WIDTH := 0.0005


## Disco de Ø125 mm vertical (plano XY, eje Z) que sale de la chapa (plano y = 0) por el frente del surco.
func _pose() -> Dictionary:
	var r := 0.0625
	var yc := 0.055
	return {
		"center": Vector3(0.0, yc, 0.0), "axis": Vector3(0.0, 0.0, 1.0), "radius": r,
		"contact": Vector3(sqrt(r * r - yc * yc), 0.0, 0.0), "normal": Vector3.UP, "spin": 1.0, "kerf": 0.00115,
	}


func _tangent() -> Vector3:
	var p := _pose()
	var axis: Vector3 = p["axis"]
	var c: Vector3 = p["center"]
	var k: Vector3 = p["contact"]
	return axis.cross(k - c).normalized()


func _run(material: String, sparks: Dictionary, vs: float, seconds := 0.5, seed := "test") -> Sparks:
	var em := Sparks.new(seed)
	em.configure(material, sparks, vs)
	em.set_pose(_pose())
	for k in int(round(seconds / DT)):
		em.step(DT)
	return em


func _stub(panel_id: String, rpm: float, disc_id := "fino_1mm") -> Dictionary:
	return Radial.cut_panel({
		"disc_id": disc_id, "diameter_mm": 125.0, "rpm": rpm, "angle_deg": 0.0, "feed_mm_s": 20.0,
		"panel_id": panel_id, "cut_length_mm": 100.0,
	})


## Longitud media de las estelas de las chispas portadoras vivas (lo que recorren durante la exposición).
func _mean_streak(em: Sparks) -> float:
	var buf := em.buffer(EXPOSURE, WIDTH)
	var total := 0.0
	var n := 0
	for i in em.count():
		var o := i * Sparks.FLOATS_PER_SPARK
		if buf[o + 18] != 0.0:  # solo portadoras (generación 0)
			continue
		total += Vector3(buf[o], buf[o + 4], buf[o + 8]).length()
		n += 1
	return total / float(n) if n > 0 else 0.0


func test_determinista() -> void:
	var desc := {"rate": 800.0, "length_mm": 1200.0, "bursts": 0.6}
	var a := _run("acero-dulce", desc, 72.0, 0.4, "radial:1")
	var b := _run("acero-dulce", desc, 72.0, 0.4, "radial:1")
	var c := _run("acero-dulce", desc, 72.0, 0.4, "radial:2")
	assert_true(a.count() > 20, "hay chispas vivas (%d)" % a.count())
	assert_eq(a.stats(), b.stats(), "misma semilla, mismos contadores")
	assert_true(a.buffer(EXPOSURE, WIDTH) == b.buffer(EXPOSURE, WIDTH), "misma semilla, mismo búfer al bit")
	assert_false(a.buffer(EXPOSURE, WIDTH) == c.buffer(EXPOSURE, WIDTH), "otra semilla, otras chispas")


func test_aluminio_y_plastico_sin_chispas() -> void:
	# Aunque el modelo pidiera chispas, el ensayo de chispas dice que no hay haz (tabla 7-5, fila 15).
	for mat in ["aluminio", "plastico-carroceria", "cobre", "laton"]:
		var em := _run(mat, {"rate": 500.0, "length_mm": 1000.0, "bursts": 0.2}, 72.0)
		var s := em.stats()
		assert_eq(int(s["emitted"]), 0, "%s no emite chispas" % mat)
		assert_eq(em.count(), 0, "%s no tiene chispas vivas" % mat)
		assert_true(bool(s["suppressed"]), "%s avisa de que se ignoran las chispas del modelo" % mat)
	for mat in ["aluminio", "plastico-carroceria"]:
		var res := _stub(mat, 11000.0)
		var em := _run(mat, res["sparks"], float(res["vs_ms"]))
		assert_eq(int(em.stats()["emitted"]), 0, "%s: sin chispas" % mat)
	# Un material desconocido no se inventa chispas.
	assert_eq(Sparks.family_of("titanio"), "", "titanio: sin firma en la tabla")
	assert_eq(int(_run("titanio", {}, 72.0).stats()["emitted"]), 0, "material sin firma: sin chispas")


func test_mas_vs_mas_chispas_y_mas_largas() -> void:
	# Sin datos del modelo, el emisor usa la firma del acero y el arrastre del aire.
	var slow := _run("acero-dulce", {}, 40.0, 0.6)
	var fast := _run("acero-dulce", {}, 80.0, 0.6)
	var s_slow := slow.stats()
	var s_fast := fast.stats()
	assert_true(int(s_fast["emitted"]) > int(s_slow["emitted"]) * 1.6, "más vs, más chispas (%d frente a %d)" % [s_fast["emitted"], s_slow["emitted"]])
	assert_true(float(s_fast["length_mm"]) > float(s_slow["length_mm"]), "más vs, haz más largo")
	assert_true(float(s_fast["mean_travel_m"]) > float(s_slow["mean_travel_m"]), "más vs, cada chispa llega más lejos")
	assert_true(float(s_fast["max_travel_m"]) > float(s_slow["max_travel_m"]), "más vs, la más lejana llega más lejos")
	# Con el modelo de corte, a más rpm, lo mismo.
	var r_slow := _stub("acero-dulce", 6500.0)
	var r_fast := _stub("acero-dulce", 11500.0)
	var a := _run("acero-dulce", r_slow["sparks"], float(r_slow["vs_ms"]), 0.6)
	var b := _run("acero-dulce", r_fast["sparks"], float(r_fast["vs_ms"]), 0.6)
	assert_true(int(b.stats()["emitted"]) > int(a.stats()["emitted"]), "modelo: más rpm, más chispas")
	assert_true(float(b.stats()["mean_travel_m"]) > float(a.stats()["mean_travel_m"]), "modelo: más rpm, más largas")


func test_estela_mas_larga_con_mas_vs_a_igual_haz() -> void:
	# Con el mismo haz del modelo, la chispa que sale más rápida deja una estela más larga en la misma exposición.
	var desc := {"rate": 800.0, "length_mm": 1200.0, "bursts": 0.1}
	var slow := _run("acero-dulce", desc, 40.0, 0.3)
	var fast := _run("acero-dulce", desc, 80.0, 0.3)
	assert_true(_mean_streak(fast) > _mean_streak(slow) * 1.2, "estela media %s m frente a %s m" % [_mean_streak(fast), _mean_streak(slow)])


func test_salen_tangentes_al_disco() -> void:
	var em := Sparks.new("tangente")
	em.configure("acero-dulce", {"rate": 3000.0, "length_mm": 1200.0, "bursts": 0.0}, 72.0)
	em.set_pose(_pose())
	em.step(0.002)
	var buf := em.buffer(1.0, WIDTH)
	var t := _tangent()
	assert_true(em.count() >= 4, "hay chispas recién nacidas")
	for i in em.count():
		var o := i * Sparks.FLOATS_PER_SPARK
		var back := Vector3(buf[o], buf[o + 4], buf[o + 8])  # de la cabeza a la cola: contra la velocidad
		var ang := rad_to_deg((-back).angle_to(t))
		assert_true(ang < Sparks.SPREAD_IN_PLANE_DEG + Sparks.SPREAD_OUT_PLANE_DEG + 0.5, "chispa %d a %s° de la tangente" % [i, ang])


func test_colores_y_estallidos_por_material() -> void:
	var mild := _run("acero-dulce", {}, 72.0, 0.5, "color")
	var inox := _run("inox", {}, 72.0, 0.5, "color")
	var tool := _run("1095", {}, 72.0, 0.5, "color")
	var boro := _run("boro-22mnb5", {}, 72.0, 0.5, "color")
	var c_mild := mild.mean_color()
	var c_inox := inox.mean_color()
	var c_tool := tool.mean_color()
	# Inoxidable: más rojizo (naranja → paja) que el acero dulce (amarillo-naranja → blanco).
	assert_true(c_inox.g / c_inox.r < c_mild.g / c_mild.r, "inox más rojizo: g/r %s frente a %s" % [c_inox.g / c_inox.r, c_mild.g / c_mild.r])
	# Acero de herramientas: blanco junto al disco, más claro que el dulce.
	assert_true(c_tool.b > c_mild.b, "alto carbono más blanco: b %s frente a %s" % [c_tool.b, c_mild.b])
	# Inoxidable: haz más corto (el 18-8, la mitad que el hierro).
	assert_true(float(inox.stats()["mean_travel_m"]) < float(mild.stats()["mean_travel_m"]), "inox más corto")
	# Estallidos por chispa emitida: el acero al boro (Mn) y el de herramientas, muchos más que el dulce.
	var per := func(em: Sparks) -> float: return float(em.stats()["burst_events"]) / maxf(float(em.stats()["emitted"]), 1.0)
	assert_true(per.call(boro) > 2.0 * per.call(mild), "boro: %s estallidos por chispa frente a %s" % [per.call(boro), per.call(mild)])
	assert_true(per.call(tool) > 2.0 * per.call(mild), "alto carbono: más estallidos que el dulce")
	assert_eq(str(boro.stats()["burst_kind"]), "repeating", "boro: estallidos repetidos en estrella")
	assert_eq(str(mild.stats()["burst_kind"]), "forked", "dulce: pocos estallidos, en horquilla")
	# El color de incandescencia sube de rojo a blanco con la temperatura (TM 9-237, tabla V).
	var red := Sparks.heat_color(700.0)
	var white := Sparks.heat_color(1200.0)
	assert_true(red.r > red.g * 3.0 and white.g > 0.9 and white.b > 0.8, "rojo a 700 °C, blanco a 1200 °C")


func test_buffer_para_multimesh() -> void:
	var em := _run("acero-dulce", {"rate": 600.0, "length_mm": 1000.0, "bursts": 0.3}, 72.0, 0.2)
	var n := em.count()
	assert_eq(em.buffer(EXPOSURE, WIDTH).size(), n * Sparks.FLOATS_PER_SPARK, "20 floats por chispa")
	assert_eq(em.buffer(EXPOSURE, WIDTH, Sparks.MAX_SPARKS).size(), Sparks.MAX_SPARKS * Sparks.FLOATS_PER_SPARK, "relleno hasta la capacidad")
	var buf := em.buffer(EXPOSURE, WIDTH)
	for i in n:
		var o := i * Sparks.FLOATS_PER_SPARK
		var a := buf[o + 15]
		assert_true(a >= 0.0 and a <= 1.0, "alfa en [0, 1]")
		assert_true(is_finite(buf[o + 3]) and is_finite(buf[o + 7]) and is_finite(buf[o + 11]), "posición finita")
	assert_true(em.count() <= Sparks.MAX_SPARKS, "nunca más de MAX_SPARKS")


## Los estallidos duran menos que un fotograma: aun así se dibujan (lo que existió durante la exposición).
func test_estallidos_visibles_a_30_fps() -> void:
	var em := Sparks.new("fotograma")
	em.configure("boro-22mnb5", {"rate": 3000.0, "length_mm": 1300.0, "bursts": 0.8}, 72.0)
	em.set_pose(_pose())
	for k in 8:
		em.step(1.0 / 30.0)
	var buf := em.buffer(EXPOSURE, WIDTH)
	var branches := 0
	for i in em.count():
		var o := i * Sparks.FLOATS_PER_SPARK
		if buf[o + 18] > 0.0 and buf[o + 15] > 0.0:
			branches += 1
	assert_true(branches > 20, "ramas de estallidos dibujadas en el fotograma: %d" % branches)


## Una sola fuente (fase 2): stream_for da tamaño, longitud, color y estallidos del haz de cada material (TC 9-237,
## tabla 7-5); radial.gd los copia en cut_panel.
func test_una_sola_fuente_del_haz() -> void:
	var mild := Sparks.stream_for("acero-dulce", 72.0)
	assert_eq(mild["family"], "acero_bajo_c", "chapa de acero dulce: acero de bajo carbono (AISI 1020)")
	assert_true(mild["known"] and float(mild["volume"]) == 1.0, "haz grande")
	for k in ["color", "color_end"]:
		var hex := String(mild[k])
		assert_true(hex.begins_with("#") and hex.length() == 7 and Color.html_is_valid(hex), "%s en #RRGGBB (%s)" % [k, hex])
	assert_eq(mild["color_name"], "amarillo anaranjado", "estelas amarillo-naranja (§7-3)")
	assert_eq(mild["bursts_name"], "pocas, en horquilla", "pocos estallidos, en horquilla")
	assert_eq(Sparks.stream_for("boro-22mnb5", 72.0)["bursts_name"], "muchas, repetidas, en estrella", "el Mn y el C del 22MnB5")
	assert_near(Sparks.stream_length_mm(1778.0, Sparks.VS_REF_MS), 1778.0, 1e-9, 0.0, "a la velocidad de la tabla, la longitud de la tabla")
	var prev := 0.0
	for vs in [20.0, 40.0, 60.0, 80.0]:
		var l: float = Sparks.stream_for("acero-dulce", vs)["length_mm"]
		assert_true(l > prev, "más vs, haz más largo (%s m/s)" % vs)
		prev = l
	for id in ["aluminio", "plastico-carroceria", "perfil-aluminio", "laton"]:
		var none := Sparks.stream_for(id, 72.0)
		assert_eq([none["volume"], none["length_mm"], none["color"], none["bursts"], none["bursts_name"]], [0.0, 0.0, "", 0.0, "ninguna"], "%s no chispea" % id)
	var unknown := Sparks.stream_for("titanio", 72.0)
	assert_false(unknown["known"], "titanio: sin firma en la tabla")
	assert_eq(unknown["length_mm"], 0.0, "no se inventan chispas")
	assert_eq(Sparks.burst_name(0.08, "forked"), "muy pocas, en horquilla", "escala de palabras")
	assert_eq(Sparks.burst_name(1.2, "repeating"), "muchísimas, repetidas, en estrella", "la más alta")


## Contrato con el modelo de corte (core/taller/radial.gd): todo campo de la salida que pinta la escena existe.
func test_modelo_de_corte_cumple_el_contrato() -> void:
	var keys := ["vs_ms", "over_speed", "time_s", "kerf_mm", "burr_um", "haz_mm", "heat_tint", "paint_burn_mm", "sparks",
		"disc_wear_mm3", "disc_loading", "deformation", "cleanliness", "warnings", "quality", "sources"]
	for disc in ["fino_1mm", "grueso_3mm", "diamante", "laminas"]:
		for panel in ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria", "boro-22mnb5", "dp800"]:
			var res := Radial.cut_panel({
				"disc_id": disc, "diameter_mm": 125.0, "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 10.0,
				"panel_id": panel, "cut_length_mm": 100.0,
			})
			for k in keys:
				assert_true(res.has(k), "%s en %s: falta «%s»" % [disc, panel, k])
			var tint: Dictionary = res["heat_tint"]
			assert_true(tint.has("temp_c") and tint.has("color"), "heat_tint completo")
			var c := float(res["cleanliness"])
			assert_true(c >= 0.0 and c <= 10.0, "limpieza entre 0 y 10")
			assert_false(res.has("stub"), "es el modelo, no un sustituto")
	# Tendencias que enseña la demo: el disco fino corta más limpio que el grueso y el aluminio embota el Al₂O₃.
	var base := {"diameter_mm": 125.0, "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 10.0, "cut_length_mm": 100.0}
	var thin := Radial.cut_panel(base.merged({"disc_id": "fino_1mm", "panel_id": "acero-dulce"}))
	var thick := Radial.cut_panel(base.merged({"disc_id": "grueso_3mm", "panel_id": "acero-dulce"}))
	var alu := Radial.cut_panel(base.merged({"disc_id": "fino_1mm", "panel_id": "aluminio"}))
	assert_true(float(thin["cleanliness"]) < float(thick["cleanliness"]), "el fino, más limpio")
	assert_true(float(thin["burr_um"]) < float(thick["burr_um"]), "el fino, menos rebaba")
	assert_true(float(alu["disc_loading"]) > 0.5, "el aluminio embota el disco")


## Las escenas de la radial cargan e instancian sin ventana y exponen la API para la interfaz.
func test_escenas_cargan_sin_ventana() -> void:
	for path in ["res://app/taller/radial_3d.tscn", "res://app/taller/demo_radial.tscn"]:
		var ps := load(path) as PackedScene
		assert_true(ps != null and ps.can_instantiate(), "%s carga" % path)
		if ps != null:
			var node := ps.instantiate()
			assert_true(node != null, "%s se instancia" % path)
			node.free()
	var radial: Node3D = (load("res://app/taller/radial_3d.tscn") as PackedScene).instantiate()
	for m in ["set_params", "set_result", "start_cut", "set_view", "set_rpm", "set_angle", "set_inset", "info"]:
		assert_true(radial.has_method(m), "API: %s" % m)
	var p := {
		"disc_id": "diamante", "diameter_mm": 125.0, "rpm": 9000.0, "angle_deg": 0.0, "feed_mm_s": 3.0,
		"panel_id": "boro-22mnb5", "cut_length_mm": 150.0,
	}
	radial.call("set_params", p)
	radial.call("set_result", Radial.cut_panel(p))
	radial.call("start_cut", 40.0)
	radial.call("set_view", "canto del corte")
	radial.call("set_angle", 15.0)
	assert_eq(str(radial.get("view")), "canto", "alias de vista")
	var stored: Dictionary = radial.get("params")
	assert_eq(float(stored["angle_deg"]), 15.0, "ángulo guardado")
	var inf: Dictionary = radial.call("info")
	assert_true(float(inf["strobe_hz"]) >= 0.0, "info() responde antes de entrar en el árbol")
	radial.free()
