## Dibujos de los insectos y de sus aguijones (core/lab/art_insects.gd, 2.0): todas las especies se dibujan y ThorVG las
## pinta con píxeles visibles, son deterministas, las proporciones salen de los datos (insects.gd) y el corte de la piel
## enseña lo que dice el resultado. art.gd no cambia: sus 372 SVG del oráculo los vigila test_art.gd.
extends "res://tests/case.gd"

const ArtInsects = preload("res://core/lab/art_insects.gd")
const Art = preload("res://core/lab/art.gd")
const Svg = preload("res://core/lab/svg.gd")
const Looks = preload("res://core/lab/looks.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")

const ICON := Rect2(0, 0, 100, 132)


static func S(id: String) -> Dictionary:
	return Insects.find_by_id(id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func params(claw: Dictionary, target: Dictionary, force: float) -> Dictionary:
	return {
		"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": claw, "target": target,
		"force": force, "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": "puncion", "strike": false,
		"passes": 1.0, "wet": false,
	}


static func view(r: Rect2) -> Dictionary:
	return { "viewBox": "%s %s %s %s" % [r.position.x, r.position.y, r.size.x, r.size.y], "width": r.size.x, "height": r.size.y }


## SVG del dibujo y si ThorVG lo pinta con píxeles visibles. [svg, pintado]
static func draw(art: Dictionary, r: Rect2) -> Array:
	var svg := Svg.scene_to_svg(art, view(r))
	var img := SvgTexture.rasterize_image(svg, 1.0)
	return [svg, img != null and img.get_used_rect().has_area()]


static func label_texts(art: Dictionary) -> Array:
	return (art.get("labels", []) as Array).map(func(l: Dictionary) -> String: return String(l.text))


func test_cada_especie_se_dibuja_y_thorvg_la_pinta() -> void:
	assert_eq(Insects.STINGERS.size(), 8, "los ocho aguijones del catálogo")
	for c: Dictionary in Insects.STINGERS:
		var icon := ArtInsects.insect_icon_art(c, { "uid": "t" })
		var d := draw(icon, ICON)
		var svg: String = d[0]
		assert_true(svg.begins_with("<svg") and d[1], "%s: la ficha se dibuja y se pinta" % c.id)
		assert_false(svg.contains("NaN") or svg.contains("Infinity"), "%s: números finitos en el SVG" % c.id)
		assert_eq(Svg.scene_to_svg(ArtInsects.insect_icon_art(c, { "uid": "t" }), view(ICON)), svg, "%s: determinista" % c.id)
		var lupa := ArtInsects.insect_icon_art(c, { "uid": "t", "lupa": true })
		assert_true(label_texts(lupa).has("700 µm"), "%s: la lupa lleva su escala" % c.id)
		assert_true(draw(lupa, ICON)[1], "%s: la ficha con lupa se pinta" % c.id)
		# el cuerpo, con la base del aguijón donde se pide y su caja
		var k := 4.0
		var body := ArtInsects.insect_body_art(c, { "k": k, "x": 0.0, "y": 0.0, "uid": "b" })
		assert_true(is_finite(float(body.stingAngle)), "%s: dirección del aguijón" % c.id)
		assert_near(float(body.S), float(Sting.sval(c.stinger, "bodyMm")) * k, 1e-12, 0.0, "%s: el cuerpo mide bodyMm a esa escala" % c.id)
		assert_true(float(body.box.w) > 0.0 and float(body.box.h) > 0.0, "%s: caja del dibujo" % c.id)
		var box := Rect2(float(body.box.x), float(body.box.y), float(body.box.w), float(body.box.h))
		assert_true(box.grow(0.01).has_point(Vector2.ZERO), "%s: la base del aguijón, dentro de la caja" % c.id)
	# las alas: la hormiga bala no tiene
	assert_true((ArtInsects.insect_wings_art(S("hormigabala"), { "k": 4.0 }).body as Array).is_empty(), "la hormiga bala, sin alas")
	assert_false((ArtInsects.insect_wings_art(S("abeja"), { "k": 4.0 }).body as Array).is_empty(), "la abeja, con alas")


func test_el_aguijon_con_las_proporciones_de_los_datos() -> void:
	var bee := S("abeja")
	# púas de la abeja (Ramirez-Esquivel & Ravi 2023): 10, la primera a 52,6 µm de la punta, cada vez más separadas
	var b := ArtInsects.barbs(bee)
	assert_eq(b.size(), 10, "10 púas por lanceta")
	assert_eq(b[0][0], 52.6, "la primera, a 52,6 µm de la punta")
	for i in range(1, b.size()):
		assert_true(float(b[i][0]) > float(b[i - 1][0]), "púa %d más lejos de la punta que la anterior" % i)
	# semiancho: la esfera de la punta (1,25 µm) y el estilete (86/2 µm)
	assert_near(ArtInsects.half_width_um(bee, 0.0), 1.25, 1e-12, 0.0, "punta: R")
	assert_near(ArtInsects.half_width_um(bee, 900.0), 43.0, 1e-12, 0.0, "a media longitud: el diámetro del estilete")
	# contorno para el banco: de la base (0, 0) hacia +y
	var pts := ArtInsects.stinger_outline(bee, 12.0, 2.0, 0.0)
	assert_eq(pts.size(), 38, "18 tramos por lado")
	var ymin := INF
	var ymax := -INF
	for p: Vector2 in pts:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	assert_near(ymin, 0.0, 0.0, 1e-9, "empieza en la base")
	assert_near(ymax, 12.0, 1e-12, 0.0, "y mide lo que se pide")
	assert_true(absf(pts[18].x - pts[19].x) < 0.1, "la punta, afilada")
	var kept := ArtInsects.stinger_outline(bee, 12.0, 2.0, 0.0, 5.0)
	for p: Vector2 in kept:
		assert_true(p.y <= 5.0 + 1e-9, "con keep = 5 solo se ve lo que asoma")
	var bent := ArtInsects.stinger_outline(bee, 12.0, 2.0, 3.0)
	assert_near((bent[18].x + bent[19].x) / 2.0, 3.0, 0.0, 0.2, "doblado: la punta se aparta la flecha pedida")
	assert_near((bent[0].x + bent[37].x) / 2.0, 0.0, 0.0, 1e-9, "y la base no se mueve")


func test_el_corte_de_la_piel_ensena_el_resultado() -> void:
	var bee := S("abeja")
	var stuck := Physics.compute(params(bee, T("piel"), 0.00575))
	var art := ArtInsects.sting_section_art(stuck, bee, { "uid": "t" })
	assert_true(label_texts(art).has("se queda clavado"), "la abeja se queda clavada: %s" % [label_texts(art)])
	assert_true(String(art.aria).contains(String(stuck.layer)), "la descripción dice la capa: %s" % art.aria)
	assert_true(draw(art, Rect2(0, 0, 300, 184))[1], "el corte se pinta")
	var wasp := S("avispa")
	var out := Physics.compute(params(wasp, T("piel"), float(wasp.force)))
	assert_true(label_texts(ArtInsects.sting_section_art(out, wasp)).has("lo saca"), "la avispa lo saca")
	var soft := Physics.compute(params(bee, T("piel"), 0.002))
	var soft_art := ArtInsects.sting_section_art(soft, bee)
	assert_true(label_texts(soft_art).has("no perfora"), "con 2 mN la piel solo se hunde")
	assert_eq(soft_art.aria, "Corte de la piel: el aguijón no la perfora")
	# una piel tres veces más tenaz (docs/fisica/aguijones.md §2.3): la abeja de quitina se dobla antes de perforarla
	var tough := T("piel").duplicate(true)
	var stack: Array = Catalog.SKIN_LAYERS.duplicate(true)
	stack[0].jC = float(stack[0].jC) * 3.0
	tough.tissue = stack
	var bent := Physics.compute(params(bee, tough, 0.01))
	assert_eq(bent.verdict, "SE DOBLA EL AGUIJÓN", "piel tres veces más tenaz")
	assert_true(label_texts(ArtInsects.sting_section_art(bent, bee)).has("se dobla"), "el corte lo enseña doblado")


func test_aparato_saco_y_cuticula() -> void:
	var bee := S("abeja")
	var ap := ArtInsects.apparatus_art(bee, { "k": 13.0, "x": 0.0, "y": 0.0 })
	assert_true(float(ap.sac.r) > 0.0, "el saco del veneno tiene sitio")
	var box := Rect2(float(ap.box.x), float(ap.box.y), float(ap.box.w), float(ap.box.h))
	assert_true(box.has_point(Vector2(0.0, -0.5)) and box.has_point(Vector2(float(ap.sac.x), float(ap.sac.y))), "caja del aparato con la entrada y el saco")
	var full: Dictionary = ArtInsects.venom_sac_art({ "r": 5.0, "fill": 1.0 }).body[0]
	var empty: Dictionary = ArtInsects.venom_sac_art({ "r": 5.0, "fill": 0.0 }).body[0]
	assert_true(float(empty.attrs.rx) < float(full.attrs.rx), "el saco vacío, más pequeño")
	# la cutícula como material: su propio aspecto; los demás materiales, los de art.gd tal cual
	var o := { "x": 0.0, "y": 0.0, "w": 120.0, "h": 34.0, "uid": "t", "detail": 0.7, "rx": 7.0 }
	assert_eq(ArtInsects.look("cuticula"), ArtInsects.CUTICLE_LOOK)
	assert_eq(ArtInsects.look("madera"), Looks.MATERIAL_LOOK["madera"])
	assert_true(draw(ArtInsects.surface_art("cuticula", o), Rect2(0, 0, 120, 34))[1], "la cutícula se pinta")
	for id: String in ["madera", "vidrio", "piel", "acero"]:
		assert_eq(Svg.scene_to_svg(ArtInsects.surface_art(id, o), view(Rect2(0, 0, 120, 34))),
			Svg.scene_to_svg(Art.surface_art(id, o), view(Rect2(0, 0, 120, 34))), "%s: la superficie de art.gd" % id)
	assert_eq(ArtInsects.sting_color(bee), "#6B4A2B", "color del aguijón de la abeja (stinger.colors.sting)")
	assert_eq(ArtInsects.sting_color(bee, Catalog.find_by_id(Catalog.INLAYS, "acero")), String(Catalog.find_by_id(Catalog.INLAYS, "acero").col),
		"reforjado, el de su material")
