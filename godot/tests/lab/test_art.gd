## Ilustraciones del laboratorio (core/lab/art.gd, svg.gd y looks.gd) contra el oráculo del motor 1.x.
## - Los 372 dibujos de tests/fixtures/generated/art-svg.json salen idénticos, byte a byte, y con los mismos datos
##   (tip, tipAngle, labels, length).
## - ThorVG (el rasterizador de SVG de Godot) los pinta todos sin error y con píxeles visibles.
## - Las tablas de looks.gd, las copias de data.js y las matemáticas de V8 coinciden con las del motor.
extends "res://tests/case.gd"

const Art = preload("res://core/lab/art.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Svg = preload("res://core/lab/svg.gd")
const Looks = preload("res://core/lab/looks.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")

var data: Dictionary
var fx: Array
var _svgs := {}  # id del dibujo → SVG del port (lo reutiliza el test de ThorVG)
var _build_us := 0


func before_each() -> void:
	if data.is_empty():
		data = load_json("res://tests/fixtures/lab-data.json")
	if fx.is_empty():
		fx = load_json("res://tests/fixtures/generated/art-svg.json")


func _by_id(list: String, id: Variant) -> Variant:
	if id == null:
		return null
	for x: Dictionary in data[list]:
		if x["id"] == id:
			return x
	return null


## Llama a la función de art.gd que corresponde a una entrada del oráculo, con los catálogos de lab-data.json.
func build(e: Dictionary) -> Variant:
	var a: Dictionary = e["args"]
	match String(e["fn"]):
		"surfaceArt":
			return Art.surface_art(a["lookId"], { "w": a["w"], "h": a["h"], "detail": a["detail"], "rx": a["rx"], "uid": a["uid"] })
		"nailArt", "nailSideArt":
			var o := {
				"geom": _by_id("GEOMS", a["geom"]), "base": _by_id("BASES", a["base"]), "inlay": _by_id("INLAYS", a["inlay"]),
				"wet": a["wet"], "uid": a["uid"] }
			return Art.nail_art(o) if e["fn"] == "nailArt" else Art.nail_side_art(o)
		"gemArt":
			return Art.gem_art(_by_id("INLAYS", a["inlay"]), a["cx"], a["cy"], a["r"], a["uid"])
		"clawArt":
			return Art.claw_art(_by_id("CLAWS", a["claw"]), {
				"inlay": _by_id("INLAYS", a["inlay"]), "orient": a["orient"], "uid": a["uid"], "tipColor": a["tipColor"],
				"drop": a["drop"] })
		"grooveArt":
			return Art.groove_art(a["targetId"], a["res"], { "x1": a["x1"], "x2": a["x2"], "y": a["y"], "uid": a["uid"] })
		"punctureArt":
			return Art.puncture_art(a["targetId"], a["res"], { "cx": a["cx"], "cy": a["cy"], "uid": a["uid"], "fangs": a["fangs"] })
		"carSectionArt":
			return Art.car_section_art(a["res"], _by_id("TARGETS", a["target"]), { "uid": a["uid"] })
		"skinSectionArt":
			return Art.skin_section_art(a["res"], { "uid": a["uid"] })
		"paneFractureArt":
			return Art.pane_fracture_art(a)
	fail("función desconocida en el oráculo: %s" % e["fn"])
	return []


static func view_of(e: Dictionary) -> Dictionary:
	return { "viewBox": e["viewBox"], "width": e["width"], "height": e["height"] }


## Lo que devuelve la función además del grafo (tip, tipAngle, labels, length…), como `data` en el oráculo.
static func data_of(art: Variant) -> Dictionary:
	var out := {}
	if art is Dictionary:
		for k: String in art:
			if not k in ["defs", "body", "lines", "extras"]:
				out[k] = art[k]
	return out


## Dónde difieren dos textos, con un poco de contexto.
static func first_diff(got: String, want: String) -> String:
	var i := 0
	var n := mini(got.length(), want.length())
	while i < n and got.unicode_at(i) == want.unicode_at(i):
		i += 1
	var a := maxi(0, i - 40)
	return "en el carácter %d (longitudes %d y %d)\n      port:    …%s…\n      oráculo: …%s…" % [
		i, got.length(), want.length(), got.substr(a, 90), want.substr(a, 90)]


func test_tablas_iguales_que_las_de_art_js() -> void:
	var tables := {
		"MATERIAL_LOOK": Looks.MATERIAL_LOOK, "SKIN_LAYER_LOOK": Looks.SKIN_LAYER_LOOK, "PAINT_LAYER_LOOK": Looks.PAINT_LAYER_LOOK,
		"BODY_LOOK": Looks.BODY_LOOK, "CAR_SECTION": Looks.CAR_SECTION, "SKIN_SECTION": Looks.SKIN_SECTION,
	}
	for name: String in tables:
		for d in oracle_diff(tables[name], data[name], name):
			fail(d)
		assert_eq((tables[name] as Dictionary).size(), (data[name] as Dictionary).size(), "%s: número de entradas" % name)
	for base: Dictionary in data["BASES"]:
		assert_eq(Art.nail_swatch(base["id"]), data["nailSwatch"][base["id"]], "nailSwatch(%s)" % base["id"])
	# todo material y toda garra del catálogo tiene aspecto propio (ninguno cae en el de reserva)
	for t: Dictionary in data["TARGETS"]:
		assert_true(Looks.MATERIAL_LOOK.has(t["id"]), "aspecto de %s" % t["id"])
	for c: Dictionary in data["CLAWS"]:
		assert_true(Looks.CLAW_ART.has(c["id"]), "rasgos de %s" % c["id"])
	for id in Looks.SKIN_BAND:
		assert_true(Looks.SKIN_LAYER_LOOK.has(id), "banda de piel %s" % id)


func test_tablas_de_data_js_iguales_que_el_oraculo() -> void:
	# Looks apunta a los catálogos de la física (data.gd): pintura, piel, carrocerías y paleta
	for d in oracle_diff(Looks.PAINT_LAYERS, data["PAINT_LAYERS"], "PAINT_LAYERS"):
		fail(d)
	for d in oracle_diff(Looks.SKIN_LAYERS, data["SKIN_LAYERS"], "SKIN_LAYERS"):
		fail(d)
	# carrocería de cada coche (los materiales con `body`) y ninguna más
	var cars := 0
	for t: Dictionary in data["TARGETS"]:
		var body: Variant = t.get("body")
		if body == null:
			assert_false(Looks.CAR_BODY.has(t["id"]), "%s no es un coche" % t["id"])
			continue
		cars += 1
		for d in oracle_diff(Looks.CAR_BODY.get(t["id"]), body, "CAR_BODY.%s" % t["id"]):
			fail(d)
		for d in oracle_diff(Art._car_layers(t), data["carLayers"][t["id"]], "carLayers(%s)" % t["id"]):
			fail(d)
	assert_eq(cars, Looks.CAR_BODY.size(), "coches")
	for d in oracle_diff(Looks.C, data["C"], "C"):
		fail(d)


func test_colores_como_en_javascript() -> void:
	var sem: Dictionary = load_json("res://tests/fixtures/js-semantics.json")
	for row: Array in sem["mixColor"]:
		assert_eq(Art.mix(row[0], row[1], row[2]), row[3], "mix(%s, %s, %s)" % [row[0], row[1], row[2]])
	assert_eq(Art.lighten("#170E1C", 0.5), "#8B878E")
	assert_eq(Art.darken("#FFFFFF", 0.35), "#A6A6A6")
	assert_eq(Art.rgba("#5BE0C8", 0.25), "rgba(91,224,200,0.25)")
	assert_eq(Art.sparkle(10, 10, 2), "M10 8 Q10 10 12 10 Q10 10 10 12 Q10 10 8 10 Q10 10 10 8 Z")


func test_h_aplana_y_filtra_como_javascript() -> void:
	var leaf := Art.h("rect", { "x": 0 })
	var n := Art.h("g", {}, [leaf, [null, false, 0, "", NAN, [leaf]]], null, leaf)
	assert_eq(n["children"].size(), 3, "children.flat(Infinity).filter(Boolean)")
	assert_eq(Art.h("line")["attrs"], {}, "attrs por defecto")
	assert_eq(Svg.nodes_to_svg([Art.h("text", { "key": 1, "x": 1.5, "fontSize": 8, "hidden": false, "fill": null, "title": "a<b & \"c\">" })]),
		"<text x=\"1.5\" font-size=\"8\" title=\"a&lt;b &amp; &quot;c&quot;&gt;\"/>")
	assert_eq(Svg.nodes_to_svg([Art.h("g", { "clipPath": "url(#c)", "gradientUnits": "userSpaceOnUse" }, leaf)]),
		"<g clip-path=\"url(#c)\" gradientUnits=\"userSpaceOnUse\"><rect x=\"0\"/></g>")


func test_matematicas_de_v8_al_bit() -> void:
	var bad := 0
	for row: String in _V8_TRIG:
		var v := _hexes(row)
		for k in 3:
			var got: float = [V8.js_sin(v[0]), V8.js_cos(v[0]), V8.js_tan(v[0])][k]
			if not same(got, v[k + 1]) or (got == 0.0 and signf(1.0 / got) != signf(1.0 / v[k + 1])):
				bad += 1
				if bad <= 6:
					fail("%s(%s) = %s, V8 %s" % [["sin", "cos", "tan"][k], _Js.js_num_str(v[0]), _Js.js_num_str(got), _Js.js_num_str(v[k + 1])])
	for row: String in _V8_POW:
		var v := _hexes(row)
		if not same(V8.js_pow(v[0], v[1]), v[2]):
			bad += 1
			fail("pow(%s, %s) = %s, V8 %s" % [_Js.js_num_str(v[0]), _Js.js_num_str(v[1]), _Js.js_num_str(V8.js_pow(v[0], v[1])), _Js.js_num_str(v[2])])
	for row: String in _V8_ATAN2:
		var v := _hexes(row)
		if not same(V8.js_atan2(v[0], v[1]), v[2]):
			bad += 1
			fail("atan2(%s, %s) = %s, V8 %s" % [_Js.js_num_str(v[0]), _Js.js_num_str(v[1]), _Js.js_num_str(V8.js_atan2(v[0], v[1])), _Js.js_num_str(v[2])])
	# y los vectores de atan2 y pow del oráculo (js-semantics.json), ahora al bit
	var sem: Dictionary = load_json("res://tests/fixtures/js-semantics.json")
	for row: Array in sem["atan2"]:
		if not same(V8.js_atan2(row[0], row[1]), row[2]):
			bad += 1
			fail("atan2(%s, %s) distinto de V8" % [_Js.js_num_str(row[0]), _Js.js_num_str(row[1])])
	for row: Array in sem["pow"]:
		if not same(V8.js_pow(row[0], row[1]), row[2]):
			bad += 1
			fail("pow(%s, %s) distinto de V8" % [_Js.js_num_str(row[0]), _Js.js_num_str(row[1])])
	assert_eq(bad, 0, "valores de sin/cos/tan/pow/atan2 distintos de V8")


static func _hexes(row: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for h in row.split(" "):
		out.append(h.hex_decode().decode_double(0))
	return out


func test_svg_identico_al_del_oraculo() -> void:
	var identical := 0
	var shown := 0
	var by_fn := {}
	var t0 := Time.get_ticks_usec()
	for e: Dictionary in fx:
		var art: Variant = build(e)
		var svg := Svg.scene_to_svg(art, view_of(e))
		_svgs[e["id"]] = svg
		var fn: String = e["fn"]
		if not by_fn.has(fn):
			by_fn[fn] = [0, 0]
		by_fn[fn][1] += 1
		if svg == e["svg"]:
			identical += 1
			by_fn[fn][0] += 1
		elif shown < 5:
			shown += 1
			fail("%s: SVG distinto %s" % [e["id"], first_diff(svg, e["svg"])])
		for d in oracle_diff(data_of(art), e["data"], e["id"]):
			fail(d)
	_build_us = Time.get_ticks_usec() - t0
	assert_eq(fx.size(), 372, "dibujos del oráculo")
	assert_eq(identical, fx.size(), "dibujos con el SVG idéntico al del oráculo")
	var parts := PackedStringArray()
	for fn in by_fn:
		parts.append("%s %d/%d" % [fn, by_fn[fn][0], by_fn[fn][1]])
	print("    (info) SVG idénticos al del oráculo: %d/%d (%s)" % [identical, fx.size(), ", ".join(parts)])


func test_thorvg_rasteriza_cada_dibujo() -> void:
	var raster_us := 0
	var drawn := 0
	var blank_raw := 0
	var patched := 0
	for e: Dictionary in fx:
		var svg: String = _svgs.get(e["id"], "")
		if svg == "":
			svg = Svg.scene_to_svg(build(e), view_of(e))
		var size := Vector2i(int(e["width"]), int(e["height"]))
		# 1) El SVG canónico, tal cual: ThorVG lo lee sin error y al tamaño del lienzo.
		var raw := Image.new()
		var err := raw.load_svg_from_string(svg, 1.0)
		if err != OK or raw.is_empty():
			fail("%s: ThorVG no lo rasteriza (error %d)" % [e["id"], err])
			continue
		assert_eq(raw.get_size(), size, "%s: tamaño" % e["id"])
		if not raw.get_used_rect().has_area():
			blank_raw += 1
		# 2) Lo que pinta la app (svg_texture.gd, con el arreglo de las máscaras con degradado): píxeles visibles.
		var t0 := Time.get_ticks_usec()
		var img := SvgTexture.rasterize_image(svg, 1.0)
		raster_us += Time.get_ticks_usec() - t0
		if img == null:
			fail("%s: la app no lo rasteriza" % e["id"])
			continue
		if SvgTexture.thorvg_compat(svg) != svg:
			patched += 1
		# un SVG sin elementos (p. ej. un roce en la piel que no deja marca) sale transparente; los demás, no
		var empty := svg.count("<") == 2
		if img.get_used_rect().has_area() == empty:
			fail("%s: %s" % [e["id"], "debería salir transparente" if empty else "no tiene ni un píxel visible"])
		else:
			drawn += 1
	assert_eq(drawn, fx.size(), "dibujos rasterizados como se esperaba")
	var n := float(fx.size())
	print("    (info) ThorVG en crudo deja %d dibujos en blanco (máscaras con degradado); svg_texture.gd arregla %d" % [blank_raw, patched])
	print("    (info) tiempo medio por dibujo: %.1f ms (construcción y serialización %.1f ms · ThorVG %.1f ms)" % [
		(_build_us + raster_us) / n / 1000.0, _build_us / n / 1000.0, raster_us / n / 1000.0])


func test_thorvg_a_doble_escala_para_hidpi() -> void:
	var e: Dictionary = fx[0]
	var svg := Svg.scene_to_svg(build(e), view_of(e))
	var img := SvgTexture.rasterize_image(svg, 2.0)
	assert_true(img != null, "rasteriza a ×2")
	if img != null:
		assert_eq(img.get_size(), Vector2i(int(e["width"]) * 2, int(e["height"]) * 2), "tamaño a ×2")


func test_arreglo_de_mascaras_con_degradado_para_thorvg() -> void:
	# Un cuadrado rojo tras una máscara que va de transparente (izquierda) a opaca (derecha), como el difuminado
	# del dedo en nailSideArt: ThorVG a secas no pinta nada; con el arreglo, la opacidad crece de izquierda a derecha.
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" viewBox=\"-50 -50 100 100\"><defs>" + \
		"<linearGradient id=\"g\" x1=\"-50\" y1=\"0\" x2=\"50\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">" + \
		"<stop offset=\"0\" stop-color=\"#FFFFFF\" stop-opacity=\"0\"/>" + \
		"<stop offset=\"1\" stop-color=\"#FFFFFF\" stop-opacity=\"1\"/></linearGradient>" + \
		"<mask id=\"m\" maskUnits=\"userSpaceOnUse\" x=\"-420\" y=\"-320\" width=\"480\" height=\"380\">" + \
		"<rect x=\"-420\" y=\"-320\" width=\"480\" height=\"380\" fill=\"url(#g)\"/></mask></defs>" + \
		"<g mask=\"url(#m)\"><rect x=\"-50\" y=\"-50\" width=\"100\" height=\"100\" fill=\"#FF0000\"/></g></svg>"
	var raw := SvgTexture.rasterize_image(svg, 1.0, false)
	assert_false(raw.get_used_rect().has_area(), "ThorVG sin arreglo: transparente (si cambia, el arreglo sobra)")
	var img := SvgTexture.rasterize_image(svg, 1.0)
	var alphas: Array[float] = []
	for x in [2, 25, 50, 75, 97]:
		alphas.append(img.get_pixel(x, 50).a)
	assert_near(alphas[2], 0.5, 0.02, 0.015, "a mitad de camino, media opacidad (sin error acumulado)")
	for i in 4:
		assert_true(alphas[i] < alphas[i + 1], "la opacidad crece hacia la derecha: %s" % str(alphas))
	assert_true(alphas[0] < 0.05 and alphas[4] > 0.95, "extremos: %s" % str(alphas))
	# degradado que baja (1 → 0) en la caja del rectángulo (objectBoundingBox) y en vertical
	var down := svg.replace("x1=\"-50\" y1=\"0\" x2=\"50\" y2=\"0\" gradientUnits=\"userSpaceOnUse\"", "x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\"")
	var img2 := SvgTexture.rasterize_image(down, 1.0)
	assert_true(img2.get_pixel(50, 97).a < img2.get_pixel(50, 50).a and img2.get_pixel(50, 50).a < img2.get_pixel(50, 2).a,
		"vertical y en la caja del rectángulo")
	assert_eq(SvgTexture.thorvg_compat("<svg/>"), "<svg/>", "sin máscaras no se toca")
	var grads := SvgTexture._linear_gradients("<linearGradient id=\"a\"/><linearGradient id=\"b\" x1=\"0\" y1=\"0\" x2=\"1\" " + \
		"y2=\"0\"><stop offset=\"0\" stop-color=\"#FFFFFF\"/></linearGradient>")
	assert_eq(grads.keys(), ["b"], "un <linearGradient/> vacío no se come el siguiente")


func test_arreglo_de_la_caja_de_trayectos_con_curvas_para_thorvg() -> void:
	# Degradado vertical rojo → azul en la caja de un trayecto cuya curva de arriba sube hasta y = 0 aunque sus
	# vértices empiezan en y = 10 (como el brillo del barniz de la pintura). En y = 10, un navegador está a 1/3 del
	# degradado; ThorVG a secas, al principio (usa la caja de los vértices).
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"40\" viewBox=\"0 0 40 40\"><defs>" + \
		"<linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#FF0000\" stop-opacity=\"1\"/>" + \
		"<stop offset=\"1\" stop-color=\"#0000FF\" stop-opacity=\"1\"/></linearGradient></defs>" + \
		"<path d=\"M0 10 Q20 -10 40 10 L40 30 Q20 10 0 30 Z\" fill=\"url(#g)\"/></svg>"
	assert_eq(SvgTexture._path_bounds("M0 10 Q20 -10 40 10 L40 30 Q20 10 0 30 Z", false), PackedFloat64Array([0, 0, 40, 30]), "caja exacta")
	assert_eq(SvgTexture._path_bounds("M0 10 Q20 -10 40 10 L40 30 Q20 10 0 30 Z", true), PackedFloat64Array([0, 10, 40, 30]), "caja de los vértices")
	assert_eq(SvgTexture._path_bounds("M5 5 l10 0 q5 5 0 10 z", false), PackedFloat64Array([5, 5, 17.5, 15]), "órdenes relativas")
	assert_true(SvgTexture._path_bounds("M0 0 C1 1 2 2 3 3", false).is_empty(), "órdenes que no se entienden: sin caja")
	var raw := SvgTexture.rasterize_image(svg, 2.0, false)
	var img := SvgTexture.rasterize_image(svg, 2.0)
	assert_true(raw.get_pixel(40, 20).r > 0.9, "ThorVG sin arreglo: aún rojo en y = 10 (si cambia, el arreglo sobra)")
	assert_near(img.get_pixel(40, 20).r, 2.0 / 3.0, 0.05, 0.04, "con el arreglo, a 1/3 del degradado")
	assert_near(img.get_pixel(40, 30).r, 0.5, 0.05, 0.04, "y a la mitad en y = 15")
	# el SVG canónico sigue igual y el degradado original no se toca (lo pueden usar otros elementos)
	var fixed := SvgTexture.thorvg_compat(svg)
	assert_true(fixed.contains("<linearGradient id=\"g\" x1=\"0\""), "el degradado original sigue ahí")
	assert_true(fixed.contains("fill=\"url(#g--caja0)\""), "el trayecto usa el nuevo")


## Suma de |diferencias| (0-255, canal rojo) entre dos imágenes en los píxeles donde la máscara es blanca del todo.
static func _diff_inside(a: Image, b: Image, mask: Image) -> Array:
	var sum := 0
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if mask.get_pixel(x, y).r < 0.999:
				continue
			sum += absi(int(round(a.get_pixel(x, y).r * 255.0)) - int(round(b.get_pixel(x, y).r * 255.0)))
			n += 1
	return [sum, n]


func test_arreglo_de_las_lineas_dentro_de_un_recorte_con_forma_para_thorvg() -> void:
	# Líneas finas y translúcidas sobre un fondo, recortadas por una forma con curvas (como el cepillado de la uña de
	# metal): ThorVG las compone por una máscara de 8 bits y se pierden. Con el arreglo, dentro de la forma se ven
	# igual que sin recorte (como en un navegador).
	var lines := ""
	for i in 6:
		var y := 10.37 + i * 13.0
		lines += "<line x1=\"0\" y1=\"%s\" x2=\"100\" y2=\"%s\" stroke=\"#000000\" stroke-opacity=\"0.1\" stroke-width=\"0.5\"/>" % [y, y + 0.4]
	var head := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" viewBox=\"0 0 100 100\"><defs><clipPath id=\"c\">" + \
		"<path d=\"M10 100 L10 10 Q10 2 18 2 L82 2 Q90 2 90 10 L90 100 Z\"/></clipPath></defs>"
	var bg := "<rect width=\"100\" height=\"100\" fill=\"#C8C8C8\"/>"
	var clipped := head + "<g clip-path=\"url(#c)\">" + bg + lines + "<circle cx=\"50\" cy=\"50\" r=\"5\" fill=\"#FF0000\" fill-opacity=\"0.5\"/></g></svg>"
	var free := head + "<g>" + bg + lines + "<circle cx=\"50\" cy=\"50\" r=\"5\" fill=\"#FF0000\" fill-opacity=\"0.5\"/></g></svg>"
	var mask := Image.new()
	mask.load_svg_from_string(head + "<rect x=\"-5\" y=\"-5\" width=\"110\" height=\"110\" fill=\"#000000\"/><path d=\"M10 100 L10 10 Q10 2 18 2 L82 2 Q90 2 90 10 L90 100 Z\" fill=\"#FFFFFF\"/></svg>", 2.0)
	var want := SvgTexture.rasterize_image(free, 2.0, false)
	var raw: Array = _diff_inside(SvgTexture.rasterize_image(clipped, 2.0, false), want, mask)
	var fixed: Array = _diff_inside(SvgTexture.rasterize_image(clipped, 2.0), want, mask)
	assert_true(raw[1] > 10000, "píxeles dentro de la forma: %d" % raw[1])
	assert_true(raw[0] > 300, "ThorVG sin arreglo pierde las líneas dentro del recorte (Σ|dif| = %d; si deja de pasar, el arreglo sobra)" % raw[0])
	assert_true(fixed[0] <= raw[0] / 20, "con el arreglo, dentro de la forma igual que sin recorte (Σ|dif| = %d)" % fixed[0])
	var fx := SvgTexture.thorvg_compat(clipped)
	assert_eq(fx.count("<line "), 6, "las 6 líneas, recortadas en geometría")
	assert_eq(fx.count("clip-path=\"url(#c)\""), 2, "el grupo se parte en dos (antes y después de las líneas), en su orden")
	assert_true(fx.find("<rect width") < fx.find("<line ") and fx.find("<line ") < fx.find("<circle"), "orden de pintado")
	# un recorte rectangular (sin esquinas redondeadas) no pasa por la máscara: no se toca
	var rect_clip := clipped.replace("<path d=\"M10 100 L10 10 Q10 2 18 2 L82 2 Q90 2 90 10 L90 100 Z\"/>", "<rect x=\"10\" y=\"0\" width=\"80\" height=\"100\"/>")
	assert_eq(SvgTexture.thorvg_compat(rect_clip), rect_clip, "recorte rectangular: sin cambios")
	# geometría del recorte: tramos de un segmento dentro de un cuadrado y de una forma con curvas
	var square := [PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])]
	var segs := SvgTexture._clip_segment(Vector2(-5, 5), Vector2(15, 5), square)
	assert_eq(segs.size(), 1)
	assert_true((segs[0][0] as Vector2).is_equal_approx(Vector2(0, 5)) and (segs[0][1] as Vector2).is_equal_approx(Vector2(10, 5)), "recorte de un segmento: %s" % [segs])
	assert_eq(SvgTexture._clip_segment(Vector2(-5, 20), Vector2(15, 20), square), [], "fuera del todo")
	var u := [PackedVector2Array([Vector2(0, 0), Vector2(3, 0), Vector2(3, 7), Vector2(7, 7), Vector2(7, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])]
	assert_eq(SvgTexture._clip_segment(Vector2(-1, 3), Vector2(11, 3), u).size(), 2, "una forma cóncava parte el segmento en dos")
	var nail := SvgTexture._path_polygons("M28 150 L28 60 Q28 48 40 48 L60 48 Q72 48 72 60 L72 150 Z")
	assert_eq(nail.size(), 1)
	assert_true(SvgTexture._inside(Vector2(50, 100), nail) and not SvgTexture._inside(Vector2(29, 49), nail), "dentro y fuera de la uña cuadrada")
	assert_eq(SvgTexture._path_polygons("M0 0 A5 5 0 0 1 10 0 Z"), [], "órdenes que no se entienden: sin polígono (no se toca)")
	assert_eq(SvgTexture._path_polygons("M0 0 L4 0 L4 4 Z l0 -8 l-4 4 z").size(), 2, "tras una Z sin M, el subtrayecto sigue desde su inicio")
	assert_eq(SvgTexture._clip_polygons("<path d=\"M0 0 L4 0 L4 4 Z\" transform=\"scale(2)\"/>"), [], "forma con transformación: no se toca")
	assert_eq(SvgTexture._top_children("<g id=\"a\"><g><rect/></g><glyph>x</glyph></g><line x1=\"0\"/><text>ab</text>"),
		PackedStringArray(["<g id=\"a\"><g><rect/></g><glyph>x</glyph></g>", "<line x1=\"0\"/>", "<text>ab</text>"]), "hijos de primer nivel")


func test_recortes_de_thorvg_en_los_dibujos_del_laboratorio() -> void:
	# Error de ThorVG dentro de cada recorte con forma (lo recortado frente a lo mismo sin recorte), con el arreglo, en
	# los dibujos del oráculo que tienen líneas dentro de un recorte: la uña de metal (cepillado) y la natural
	# (estrías), y las losas de metal cepillado. Las garras (pelo con extremos redondeados y escamas) siguen con un error
	# pequeño que se mide y se enseña.
	var re_group := RegEx.create_from_string("<g clip-path=\"url\\(#([^)]+)\\)\">")
	var re_clip := RegEx.create_from_string("(?s)<clipPath id=\"([^\"]+)\">(.*?)</clipPath>")
	var worst := { "lineas": 0.0, "garras": 0.0 }
	var checked := 0
	for e: Dictionary in fx:
		var svg: String = _svgs.get(e["id"], e["svg"])
		var fn: String = e["fn"]
		var with_lines: bool = svg.contains("<line ") and (fn == "nailArt" or fn == "surfaceArt")
		if not svg.contains("clip-path=") or not (with_lines or fn == "clawArt"):
			continue
		if fn == "clawArt" and checked % 7 != 0:  # una muestra de las garras (es lento)
			checked += 1
			continue
		checked += 1
		var fixed := SvgTexture.thorvg_compat(svg)
		var clips := {}
		for m: RegExMatch in re_clip.search_all(svg):
			clips[m.get_string(1)] = m.get_string(2)
		var shapes := ""
		for m: RegExMatch in re_group.search_all(svg):
			shapes += String(clips.get(m.get_string(1), "")).replace("/>", " fill=\"#FFFFFF\"/>")
		var head := svg.substr(0, svg.find(">") + 1)
		var mask := Image.new()
		mask.load_svg_from_string(head + "<rect x=\"-10000\" y=\"-10000\" width=\"20000\" height=\"20000\" fill=\"#000000\"/>" + shapes + "</svg>", 2.0)
		var a := SvgTexture.rasterize_image(fixed, 2.0, false)
		var b := SvgTexture.rasterize_image(re_group.sub(fixed, "<g>", true), 2.0, false)
		var d: Array = _diff_inside(a, b, mask)
		var mean := float(d[0]) / maxf(float(d[1]), 1.0)
		var k := "garras" if fn == "clawArt" else "lineas"
		worst[k] = maxf(worst[k], mean)
		if k == "lineas":
			assert_true(mean < 0.5, "%s: con el arreglo, error medio dentro del recorte %.3f niveles" % [e["id"], mean])
	assert_true(checked > 10, "dibujos con recortes comprobados: %d" % checked)
	print("    (info) recortes de ThorVG, error medio dentro de la forma (de 255): con líneas y el arreglo, %.3f como mucho; garras (sin arreglo), %.3f" % [
		worst["lineas"], worst["garras"]])


func test_textura_svg_con_cache_lru() -> void:
	var cache := SvgTexture.new(2, 1_000_000)
	var a := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"10\" viewBox=\"0 0 20 10\">" + \
		"<rect width=\"20\" height=\"10\" fill=\"#F00\"/></svg>"
	var b := a.replace("#F00", "#0F0")
	var c := a.replace("#F00", "#00F")
	var ta := cache.texture(a, 1.0)
	assert_true(ta != null and ta.get_width() == 20 and ta.get_height() == 10, "textura de 20 × 10")
	assert_true(cache.texture(a, 1.0) == ta, "la segunda vez sale de la caché")
	assert_true(cache.texture(a, 1.0004) == ta, "escalas que redondean igual comparten textura (y tamaño)")
	assert_eq(cache.texture(a, 2.0).get_width(), 40, "otra escala es otra textura")
	cache.texture(b, 1.0)  # a@1 es ahora la menos usada y sale
	assert_eq(cache.size(), 2, "límite de texturas")
	cache.texture(c, 1.0)
	assert_eq(cache.stats()["hits"], 2, "aciertos")
	assert_true(cache.texture(a, 1.0) != ta, "la menos usada se ha descartado")
	var small := SvgTexture.new(10, 500)  # 20 × 10 = 200 px por textura: caben dos
	small.texture(a, 1.0)
	small.texture(b, 1.0)
	small.texture(c, 1.0)
	assert_eq(small.size(), 2, "límite de píxeles")
	assert_eq(small.stats()["pixels"], 400, "píxeles guardados")
	small.clear()
	assert_eq(small.size(), 0, "clear()")
	assert_eq(SvgTexture.screen_scale(null), 1.0, "sin nodo: escala 1")


# Math.sin/cos/tan, pow y atan2 de V8 (Node 22) al bit: «x sin cos tan», «x y pow» y «y x atan2», en hexadecimal
# little-endian (generados con Node desde fuera del repositorio).
const _V8_TRIG := [
	"0000000000000000 0000000000000000 000000000000f03f 0000000000000000",
	"0000000000000080 0000000000000080 000000000000f03f 0000000000000080",
	"95d626e80b2e113e 95d626e80b2e113e 000000000000f03f 95d626e80b2e113e",
	"2b69a4292b1b60be 2a69a4292b1b60be fcffffffffffef3f 2c69a4292b1b60be",
	"333333333333d33f 33baba95cde9d23f ba092fd41d92ee3f 9899e2442accd33f",
	"4d840d4faf94e53f f23ca71052fbe33f 90e4ea269ffee83f 370ca04e0595e93f",
	"f6285c8fc2f5e83f e44c2dd74381e63f fa7b81bfcdbfe63f 456c82cf07a8ef3f",
	"182d4454fb21e93f cc3b7f669ea0e63f cd3b7f669ea0e63f ffffffffffffef3f",
	"000000000000f03f ee0c098f54edea3f 8c06b50f284ae13f a6e3be5c24ebf83f",
	"182d4454fb21f93f 000000000000f03f 075c143326a6913c b5cd317c96024d43",
	"182d4454fb21f93f 000000000000f03f 075c143326a6913c b5cd317c96024d43",
	"0000000000000040 46b4d1eaf618ed3f 0572535726a2dabf f850092ef67a01c0",
	"d221337f7cd90240 cd3b7f669ea0e63f cc3b7f669ea0e6bf 010000000000f0bf",
	"0000000000000840 5bd5b66d3810c23f d2e585be04aeefbf 6fb85412f73ec2bf",
	"182d4454fb210940 075c143326a6a13c 000000000000f0bf 075c143326a6a1bc",
	"d221337f7cd91240 000000000000f0bf 0a8a9e4c3979aabc 238976fd0e573343",
	"0000000000002440 524ff3f59e68e1bf 1f6b0c89acd9eabf 8237be345fbfe43f",
	"6666666666a64040 6db19af74871ee3f 21af9ae22fb9d3bf 5d6f4efb10b208c0",
	"cdcccccccc8c47c0 ed81581af97598bf fd0b1295a9fdefbf 96f320aac277983f",
	"0000000000205940 f10f4733f8b39fbf c2ceaead12fcef3f 0d1349abdcb79fbf",
	"0000000000c06240 4108be8844e0e6bf 02d7303a4360e63f c538e6b9875bf0bf",
	"77be9f1a2fdd5ec0 b6ae41dcdab9e93f 58150a98e507e3bf 9148a95dfea0f5bf",
	"00000000004a9340 1b03fd1d539cc23f 7283b7cef2a8efbf 326a8a007fcfc2bf",
	"9a9999990100f040 284b321ebcbae33f 2a06ef61b931e9bf 60677460190fe9bf",
	"00000000fb212941 d08e31cdbaf8c4bf ccfc71cf4c91ef3f 250f99a74542c5bf",
	"f65b8a41358ce33f 78497cf8bc5ae23f 478715597e36ea3f 7abfa0a31968e63f",
	"2493109cbb46cf3f 1db9e4f24bf7ce3f 25ba799fa90cef3f 541f18e1fae9cf3f",
	"8744e74a1857e63f 1c163c52b791e43f 3950cfa26f83e83f 1dbf3f78e7d9ea3f",
	"f9a758024303fcbf c9d39cc4a57befbf 41bc70e970eac6bf b81726d650fb1540",
	"0000784c9df051c0 8c5443852c84debf 516165bec920ecbf 524fddc5c55be13f",
	"0000965b7e816840 d808b532258bee3f 7a7ceabba516d33f 4ff2dfeb069a0940",
	"0000003c841d5340 c263523c35f6eb3f 1687a1d0291fdf3f 41cb982e37c0fc3f",
	"00002231d4216640 72eee6e8cfe9ec3f 9c39288e8d6cdb3f 49fff71f70de0040",
	"000070ca9ac24240 37948bbc8ec2c6bf bf68549f747def3f 4e8ba42ce920c7bf",
	"00008eff16c26140 631aa58a7675e4bf d63c8404099be8bf 2e981962689bea3f",
	"000030fd0ab75a40 68d00aa7807da73f f3acc5ab5ff7ef3f 0368006ed783a73f",
	"00004cbcfab351c0 25235f0bb4beefbf 7dabe1a50821c0bf 834977cbaf7d1f40",
	"0000e881290a5740 1f8b8e937dccebbf 2f92b6ad46b3dfbf 5b16128cc50ffc3f",
	"000018ac87b54c40 9e0a3d22ed72e83f 72cd3d4b54a5e43f 9a1dfb8283f2f23f",
	"000050af058b65c0 6e4f02ee4771dbbf 0382b6c8b0e8ecbf 63c297417360de3f",
	"0000dc3359a955c0 f52577d1b4fcee3f a7fc3afa07f3cf3f 2a2a56da48090f40",
	"0000cc5c915f6840 e503709daf66ca3f 9036a2f7d94fef3f 09d21b5435fbca3f",
	"000020a03e3027c0 6328881a5f6fea3f 0f42be6f7108e23f 568d34877074f73f",
	"000090580cad5240 85a56788ea79e4bf c3c366775497e83f 5f7c132536a5eabf",
	"000050aec1023a40 11f54595949fe83f 3a3a0ce6fd6fe43f 023035bceb46f33f",
	"00009078dfa84440 adbebfd5a879ddbf 2e71a35e7e67ecbf e15e38b96f9ae03f",
	"0000ecf0b3e65940 d8834dac8f59b13f c9254e2e2aedefbf 37984801cc63b1bf",
	"0000004b81423940 1d75add8ca37c03f c550b783fabdef3f 7f79254b8659c03f",
	"0000feb6f90866c0 374c3f77f305d6bf 8ebbae11b30bee3f 026a70c7aa74d7bf",
	"000008c6fddc5fc0 4689c28c3f3defbf 7809d6a78bbecbbf 2cc75d63f8031240",
	"000024eb809c59c0 bcff791c2421eebf 169e5f2d898fd5bf 6184e403db5b0640",
	"000080ff8d9d2840 0aecae57935ed0bf 7b5a8b7882efee3f 918ba33fc3eed0bf",
	"000046a8910863c0 4df0750c83d7efbf db914f9eae6bb93f 57e31693a40a24c0",
	"000054719b0c6540 384bf3344e63eebf 1921699ab10ed43f e0c5258fa23d08c0",
	"0000cc87706b5b40 733b81c28b80d13f abb26f31b9c7eebf 5fc08a9c1c32d2bf",
	"000020d024dc5840 57a84665db63ecbf 8fa71134a987dd3f e9c913a6c9c3febf",
	"00000e660bfa62c0 bda4bede7c39ebbf 6bc466d13dd1e03f 75c95c7fc2e6f9bf",
	"00000035532f0bc0 e47845b2ce3cd03f 8cd0fd1cf5f3eebf 3f0be04a6bc9d0bf",
	"0000bc391e8c5940 ec9befa299e0ef3f 487d39b78a64b6bf 6ad5e2b6e3c626c0",
	"0000b04c0fbe5cc0 605b5297598eeebf 5206c3ba1602d3bf ff912b1b6ab80940",
	"000000d56384fa3f bce595925ae1ef3f 2e281362751fb6bf 5c8e4a6c8f0e27c0",
	"00007cc5e72664c0 36f881852ed5ea3f 9b54fdba8a6fe1bf a7958e4c8d9ff8bf",
	"0000568d46976140 adc629037b38e33f 6f36a7e3a295e9bf dfbdb2a7520ae8bf",
	"000080994f1d5a40 f01a3a64c7a0e6bf 041a7a6875a0e6bf 7d98fdf83900f03f",
	"00003cce430b55c0 223445c6054ae3bf 4bf854bb6b88e9bf aede0f40c02ce83f",
	"0000a420859967c0 9de0ff942f08d3bf d09bb4ae668dee3f a64806060befd3bf",
	"000064e5dea053c0 fd7239a87dd69abf 45a2169b2ffdefbf 1df50c0cdad89a3f",
	"0000b0b2eec75840 b13a97826192efbf 770fa010a2dec43f 9f8ec8b8763418c0",
	"0000348b46bf5c40 4d41b99eb85eee3f fb4f908a642ad4bf f186337db31808c0",
]
const _V8_POW := [
	"000040ddeaefe73f cdcccccccccce43f 00bb942d487fea3f",
	"000060bbef15ef3f cdcccccccccce43f 5aaa62881667ef3f",
	"0000001ee05cd33f cdcccccccccce43f 554b701c616cdd3f",
	"00000080a839413f cdcccccccccce43f 55645381c5417e3f",
	"000080edfddcd33f cdcccccccccce43f f9bf5f975beadd3f",
	"0000e096c3d3ee3f cdcccccccccce43f e7220de8923bef3f",
	"000080848553eb3f cdcccccccccce43f 1cf11bf0fae0ec3f",
	"0000a0713e39ee3f cdcccccccccce43f 696a7b7b76d5ee3f",
	"00004028fbe7e43f cdcccccccccce43f eabeac90d943e83f",
	"0000c054735bdd3f cdcccccccccce43f 216250a52448e33f",
	"000000a47960d53f cdcccccccccce43f 45965c67ca60df3f",
	"00002071e7fdeb3f cdcccccccccce43f f0aa85178755ed3f",
	"0000008e47f6b13f cdcccccccccce43f 52889522bbc2c63f",
	"000000afeb7db53f cdcccccccccce43f ccb99b947393c93f",
	"000000de6d63ce3f cdcccccccccce43f 68150b382f22d93f",
	"000080a28383c33f cdcccccccccce43f 9d6ff88986d8d23f",
	"000040d369d2ec3f cdcccccccccce43f e63837868ae5ed3f",
	"00006079f278ee3f cdcccccccccce43f d830aa33a5ffee3f",
	"000000eafd40dd3f cdcccccccccce43f 1af72d28d73ce33f",
	"00008060e90ace3f cdcccccccccce43f 3a5d6f8f80f2d83f",
	"00000033dde3ce3f cdcccccccccce43f 2fc619730867d93f",
	"000080d3d0dccc3f cdcccccccccce43f eb8d6d744d4ed83f",
	"000080ca9c2ee23f cdcccccccccce43f 522c5747f928e63f",
	"000000f467af973f cdcccccccccce43f ac7196f1ee20b63f",
	"000000798b42cc3f cdcccccccccce43f 94fbc8ce8bf9d73f",
	"0000602896dae93f cdcccccccccce43f 0e170ca58cdbeb3f",
	"00000078826cef3f cdcccccccccce43f bc331aa5d39fef3f",
	"0000201f23c4e13f cdcccccccccce43f 6451ee1e48d4e53f",
	"0000001fd8a4c13f cdcccccccccce43f a1472a4dc5a6d13f",
	"0000e0d3e300e13f cdcccccccccce43f 815fb0f92637e53f",
	"000000f6552bc23f cdcccccccccce43f f5dbbd1dc7fdd13f",
	"0000a07629bae83f cdcccccccccce43f 618383cbf80feb3f",
	"000040499245e03f cdcccccccccce43f b1598e58119ee43f",
	"000060b72019ee3f cdcccccccccce43f 6295ba7d26c0ee3f",
	"0000005b13dfe53f cdcccccccccce43f 76ebef3fcafce83f",
	"000020c6fd42eb3f cdcccccccccce43f 706b1ed29ed5ec3f",
	"0000c0223135ea3f cdcccccccccce43f 9ad5b432db1aec3f",
	"0000e052083fe13f cdcccccccccce43f 5f677cf06c69e53f",
	"000000424664cd3f cdcccccccccce43f a5273ed13698d83f",
	"0000401b0f13d53f cdcccccccccce43f 8dbf1a56be16df3f",
	"0000000000000000 cdcccccccccce43f 0000000000000000",
	"000000000000f03f cdcccccccccce43f 000000000000f03f",
	"000000000000e03f 0000000000000040 000000000000d03f",
	"0000000000000440 0000000000000840 0000000000402f40",
	"2be6708b68120000 000000000000e03f aecbd9727829c11f",
	"0000000000001c40 cdccccccccccf4bf 26b9f50d3066b43f",
	"00000000000020c0 0000000000000840 00000000000080c0",
	"00000000000020c0 555555555555d53f 000000000000fc7f",
	"9bf2d71a0000f03f 000000c00b5ae641 a453676da505fc5a",
	"0000000000002440 0000000000407340 a0c8eb85f3cce17f",
]
const _V8_ATAN2 := [
	"000000000000e83f cdcccccccccce43f 0802ebeb216aeb3f",
	"000000000000e8bf cdcccccccccce43f 0802ebeb216aebbf",
	"000000000000e83f cdcccccccccce4bf 966c49d972470240",
	"000000000000e8bf cdcccccccccce4bf 966c49d9724702c0",
	"0000000000000000 000000000000f0bf 182d4454fb210940",
	"0000000000000080 000000000000f0bf 182d4454fb2109c0",
	"000000000000f03f 0000000000000000 182d4454fb21f93f",
	"0000000000000840 000000000000f03f 60857a6b17fcf33f",
	"2342920ca19cc73b 00000000000014c0 182d4454fb210940",
	"0000000000001440 2342920ca19cc73b 182d4454fb21f93f",
	"00000044415ac03f 000040b3e362f9bf ca61303d6f7d0840",
	"000000c4045ff0bf 0000c065b380ffbf f8dd8381734c05c0",
	"000000775230e23f 000000711285d2bf 7cec7daa65550040",
	"000000f945abf8bf 000000db7352dfbf a3bfff69f10cfebf",
	"0000807e880df53f 000000abd3c2da3f 42febc89ad35f43f",
	"000000f8954bddbf 0000c0970eacfdbf ae83c2d6633207c0",
	"0000800ee7d2ffbf 000080c37f2cea3f e98238c7ede3f2bf",
	"000000ad874af43f 00008091f23ee4bf 88062eb9b6440040",
	"00008094bda0f23f 000000bae587c3bf efd93d02c237fb3f",
	"0000001039d2e73f 00008013bcbaebbf 1d476be174740340",
	"00000031ed64eebf 000080c0d323e6bf e8eb702d4f9a01c0",
	"000000c004e99a3f 000080b59bf6e8bf 9c0b3b3304dd0840",
	"0000806abfd6fb3f 0000c066ffa0ff3f 414606c29618e73f",
	"000000b26669fabf 0000001159a4d03f b7f1db0f05a2f6bf",
	"0000809dd250f73f 000080c49332eebf 29497841eb290140",
	"000000e49cecd93f 000040531d79f73f ff79bc68c13dd13f",
	"000000ff33b7e1bf 0000c044a176f63f 53e572f4dd09d8bf",
	"0000002cd76dfabf 0000c0adf95bf0bf 58fc34e71f0001c0",
	"000000279942e13f 00000010091a9abf abd804f967e3f93f",
	"000000f84839cc3f 00004041000efc3f 943375fe2a03c03f",
]
