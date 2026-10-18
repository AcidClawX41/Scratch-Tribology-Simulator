## Dibujos de los materiales de la 2.0 (core/lab/art_materials.gd): cada fenómeno se dibuja cuando su campo del resultado
## existe y no se dibuja cuando es null (con la 1.x, nada); el tamaño y la cantidad de lo dibujado salen del resultado
## (radio de Hertz, longitud de las grietas, trozos del templado, profundidad de la abolladura, huella que queda); ThorVG
## lo rasteriza sin error y con píxeles pintados, y los dibujos son deterministas. art.gd no cambia: sus 372 SVG del
## oráculo los vigila test_art.gd, y la tabla de aspectos del oráculo (Looks.MATERIAL_LOOK) no gana entradas.
extends "res://tests/case.gd"

const ArtMaterials = preload("res://core/lab/art_materials.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const Looks = preload("res://core/lab/looks.gd")
const Svg = preload("res://core/lab/svg.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")
const Js = preload("res://core/shared/js.gd")

## La geometría del banco (app/lab/bench.gd): la cara de arriba de la losa, el surco de 25 mm y el punto de punción.
const GY := 104.0 + 38.0 * 0.46
const X1 := 46.0
const X2 := 46.0 + 70.0 + 25.0 / 60.0 * 222.0
const BENCH := Rect2(0, 0, 360, 170)


static func geo(scratch: bool) -> Dictionary:
	return { "x1": X1, "x2": X2, "y": GY, "cx": 180.0, "cy": GY, "face": { "x": 12.0, "y": 104.0, "w": 336.0, "h": 38.0, "rx": 5.0 },
		"uid": "t", "scratch": scratch }


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Un ensayo con los catálogos de la 2.0: { geom, base, inlay, claw, target, force, method, strike, model }.
static func run(o: Dictionary) -> Dictionary:
	var p := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, o.get("geom", "almendra")), "base": Catalog.find_by_id(Catalog.BASES, o.get("base", "natural")),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")),
		"claw": Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null, "target": T(o.target),
		"force": o.get("force", 30.0), "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": o.get("method", "rayado"),
		"strike": o.get("strike", false), "passes": 1.0, "wet": false,
	}
	if o.has("model"):
		p["model"] = o.model
	return Physics.compute(p)


## Los ensayos de la demo del laboratorio (casos 10-15) y otros que tocan cada fenómeno.
const CASES := {
	"uña que se dobla": { "geom": "stiletto", "target": "piel" },
	"barniz que recupera": { "geom": "almendra", "target": "coche", "force": 4.0 },
	"zarpazo que abolla": { "claw": "oso", "target": "coche", "method": "puncion", "strike": true, "force": 900.0 },
	"herraduras de Hertz": { "geom": "cuadrada", "base": "zafiro", "target": "vidrio" },
	"ventanilla que estalla (grieta)": { "claw": "tigre", "inlay": "diamante", "target": "ventanilla", "method": "puncion", "force": 260.0 },
	"parabrisas que se agrieta": { "claw": "oso", "target": "parabrisas", "method": "puncion", "strike": true, "force": 900.0 },
	"ventanilla que estalla (flexión)": { "claw": "oso", "target": "ventanilla", "method": "puncion", "strike": true, "force": 900.0 },
	"astillado": { "geom": "stiletto", "base": "diamante", "target": "zafiro" },
	"radiales": { "geom": "cuadrada", "base": "zafiro", "target": "vidrio", "method": "puncion", "force": 200.0 },
	"cono de Hertz": { "geom": "cuadrada", "base": "diamante", "target": "cuarzo", "method": "puncion", "force": 400.0 },
	"surco abollado": { "claw": "oso", "target": "coche", "force": 300.0 },
	"puerta abollada": { "claw": "oso", "target": "puertametal", "method": "puncion", "force": 900.0 },
}


## SVG del dibujo y si ThorVG lo pinta con píxeles visibles. [svg, pintado]
static func draw(art: Dictionary, r: Rect2) -> Array:
	var view := { "viewBox": "%s %s %s %s" % [r.position.x, r.position.y, r.size.x, r.size.y], "width": r.size.x, "height": r.size.y }
	var svg := Svg.scene_to_svg(art, view)
	var img := SvgTexture.rasterize_image(svg, 1.0)
	return [svg, img != null and img.get_used_rect().has_area()]


static func lupa_view() -> Rect2:
	var r := ArtMaterials.LUPA_R + 2.0
	return Rect2(-r, -r, 2.0 * r, 2.0 * r)


func test_aspecto_de_vidrio_de_los_vidrios_de_coche() -> void:
	var o := { "x": 0.0, "y": 0.0, "w": 120.0, "h": 34.0, "uid": "t", "detail": 0.7, "rx": 7.0 }
	for id: String in ["ventanilla", "parabrisas"]:
		assert_eq(String(ArtMaterials.look(id).kind), "glass", "%s: aspecto de vidrio" % id)
		assert_false(Looks.MATERIAL_LOOK.has(id), "%s: en un mapa aparte, no en la tabla del oráculo" % id)
		var d := draw(ArtMaterials.surface_art(id, o), Rect2(0, 0, 120, 34))
		assert_true(d[1], "%s: ThorVG la pinta" % id)
		assert_ne_svg(String(d[0]), draw(ArtInsects.surface_art(id, o), Rect2(0, 0, 120, 34))[0], "%s: ya no es el plástico de reserva" % id)
	# los demás materiales, igual que antes (ArtInsects: art.gd y la cutícula)
	for id: String in ["madera", "vidrio", "piel", "acero", "coche", "cuticula"]:
		assert_eq(draw(ArtMaterials.surface_art(id, o), Rect2(0, 0, 120, 34))[0], draw(ArtInsects.surface_art(id, o), Rect2(0, 0, 120, 34))[0],
			"%s: la superficie de siempre" % id)
		assert_eq(ArtMaterials.look(id), ArtInsects.look(id), "%s: el aspecto de siempre" % id)
	# ningún material del catálogo de la 2.0 cae en el aspecto de reserva (el del plástico), salvo el propio plástico
	for t: Dictionary in Catalog.TARGETS:
		if t.id != "plastico":
			assert_true(ArtMaterials.look(t.id) != Looks.MATERIAL_LOOK["plastico"], "aspecto propio de %s" % t.id)
	# el canto del parabrisas: vidrio + PVB + vidrio con sus espesores; el de la ventanilla, sus caras comprimidas
	var e := { "x": 12.0, "y": 136.0, "w": 336.0, "h": 22.0, "rx": 5.0, "top": 142.0, "uid": "t" }
	var lam := ArtMaterials.edge_art("parabrisas", e)
	var bands: Array = lam.body[0].children
	assert_eq(bands.size(), 3, "dos hojas y la lámina")
	var pvb_h := float(bands[1].attrs.height)
	assert_near(pvb_h / 16.0, 0.76 / 4.96, 1e-9, 0.0, "la lámina, con su espesor de Glazing.WINDSCREEN")
	assert_eq((ArtMaterials.edge_art("ventanilla", e).body[0].children as Array).size(), 2, "las dos caras comprimidas")
	assert_true((ArtMaterials.edge_art("vidrio", e).body as Array).is_empty(), "el vidrio de la 1.x, sin canto nuevo")


func assert_ne_svg(a: String, b: String, msg: String) -> void:
	assert_true(a != b, msg)


func test_con_la_1x_no_dibuja_nada() -> void:
	for name: String in CASES:
		var o: Dictionary = CASES[name].duplicate()
		o["model"] = "1.x"
		var res := run(o)
		assert_false(ArtMaterials.is_v2(res), "%s (1.x): sin campos de la 2.0" % name)
		assert_true(ArtMaterials.res_for_1x_marks(res) == res, "%s (1.x): las marcas de la 1.x, con el mismo resultado" % name)
		assert_eq(ArtMaterials.lupa_kind(res), "", "%s (1.x): sin lupa" % name)
		assert_true((ArtMaterials.dent_art(res, geo(not res.puncture)).body as Array).is_empty(), "%s (1.x): sin abolladura" % name)
		assert_true((ArtMaterials.track_art(res, geo(true)).body as Array).is_empty(), "%s (1.x): sin grietas en el surco" % name)
		assert_true((ArtMaterials.burst_art(T(o.target), res, geo(false)).body as Array).is_empty(), "%s (1.x): sin grietas en el punto" % name)
		assert_true((ArtMaterials.lupa_art(T(o.target), res).body as Array).is_empty(), "%s (1.x): lupa vacía" % name)
	assert_eq(ArtMaterials.marks_look_id("ventanilla"), "vidrio", "las marcas de la 1.x de un vidrio de coche, como el vidrio")
	assert_eq(ArtMaterials.marks_look_id("madera"), "madera")


func test_grietas_de_hertz_con_el_radio_del_resultado() -> void:
	var res := run(CASES["herraduras de Hertz"])
	var fr: Dictionary = res.fracture
	assert_eq(String(fr.pattern), "herradura", "rayando con la punta roma: herraduras")
	assert_eq(ArtMaterials.lupa_kind(res), "herradura")
	# el contacto bajo carga, del anillo y de la base del cono: a = (ringUm/1,25)·√(crackUm/ringUm)
	var a := ArtMaterials.hertz_contact_um(fr)
	assert_near(a, float(fr.ringUm) / Fracture.RING_RATIO * sqrt(float(fr.crackUm) / float(fr.ringUm)), 1e-12, 0.0)
	assert_near(ArtMaterials.hertz_contact_um({ "ringUm": 50.0, "crackUm": 50.0 }), 40.0, 1e-12, 0.0, "en la carga crítica, el anillo es 1,25 veces el contacto")
	# a lo largo del surco: separadas dos radios de contacto (a la escala del banco), desde donde la carga pasa del umbral
	var trk := ArtMaterials.track_art(res, geo(true))
	var step := 2.0 * a * ArtMaterials.MM / 1000.0
	assert_near(float(trk.spacing), step, 1e-9, 0.0, "separación: dos radios de contacto")
	assert_true(absi(int(trk.count) - int((X2 - X1) / step)) <= 2, "herraduras en el surco: %d" % trk.count)
	assert_near(float(trk.size), float(fr.crackUm) * ArtMaterials.MM / 1000.0, 1e-9, 0.0, "la base del cono, de crackUm")
	var later := geo(true)
	later["x_from"] = X1 + 60.0
	assert_true(int(ArtMaterials.track_art(res, later).count) < int(trk.count), "empiezan donde la carga llega al umbral")
	# más carga: la base del cono y la lupa crecen con el resultado
	var lupa := ArtMaterials.lupa_art(T("vidrio"), res)
	assert_true(String(lupa.text).ends_with("µm") or String(lupa.text).ends_with("mm"), "barra de escala: %s" % lupa.text)
	assert_true(draw(lupa, lupa_view())[1], "la lupa se pinta")
	# el cono al apretar: anillo y base, que crece con la carga
	var c1 := run(CASES["cono de Hertz"])
	var o2: Dictionary = CASES["cono de Hertz"].duplicate()
	o2.force = 320.0
	var c2 := run(o2)
	assert_eq(String(c1.fracture.pattern), "cono")
	assert_true(float(c1.fracture.crackUm) > float(c2.fracture.crackUm), "más carga, más cono")
	assert_eq(ArtMaterials.lupa_kind(c1), "cono")
	assert_true(draw(ArtMaterials.burst_art(T("cuarzo"), c1, geo(false)), BENCH)[1], "el anillo y el cono se pintan")
	assert_true(draw(ArtMaterials.lupa_art(T("cuarzo"), c1), lupa_view())[1], "la lupa del cono se pinta")
	# sin fractura: nada
	var none := res.duplicate()
	none["fracture"] = null
	assert_true((ArtMaterials.track_art(none, geo(true)).body as Array).is_empty(), "sin fracture, sin herraduras")
	assert_eq(ArtMaterials.lupa_kind(none), "", "sin fracture (y sin recuperación: frágil), sin lupa")


func test_astillado_y_grietas_radiales_de_la_longitud_del_resultado() -> void:
	var res := run(CASES["astillado"])
	assert_eq(String(res.fracture.pattern), "astillado")
	var trk := ArtMaterials.track_art(res, geo(true))
	assert_true(int(trk.count) > 0, "grietas laterales a lo largo del surco")
	assert_near(float(trk.size), float(res.fracture.crackUm) * ArtMaterials.MM / 1000.0, 1e-9, 0.0, "de crackUm")
	var longer := res.duplicate(true)
	longer.fracture.crackUm = float(res.fracture.crackUm) * 2.0
	assert_true(float(ArtMaterials.track_art(longer, geo(true)).size) > float(trk.size), "más grieta, más larga en el dibujo")
	assert_eq(ArtMaterials.lupa_kind(res), "astillado")
	assert_true(draw(ArtMaterials.lupa_art(T("zafiro"), res), lupa_view())[1], "la lupa del astillado se pinta")
	var rad := run(CASES["radiales"])
	assert_eq(String(rad.fracture.pattern), "radiales")
	var b := ArtMaterials.burst_art(T("vidrio"), rad, geo(false))
	assert_eq(int(b.radials), 6, "estrella de seis radiales (la punta es un cono)")
	assert_eq(ArtMaterials.lupa_kind(rad), "radiales")
	assert_true(draw(ArtMaterials.lupa_art(T("vidrio"), rad), lupa_view())[1], "la lupa de las radiales se pinta")
	# al rayar, las radiales no van en el punto (son las del surco)
	assert_eq(int(ArtMaterials.burst_art(T("vidrio"), rad, geo(true)).radials), 0)


func test_ventanilla_templada_que_estalla_en_trozos_del_resultado() -> void:
	var res := run(CASES["ventanilla que estalla (grieta)"])
	var gl: Dictionary = res.glazing
	assert_true(gl.shattered == true and gl.cause == "grieta", "el martillo de emergencia")
	assert_eq(ArtMaterials.glazing_burst(res), "templado")
	var b := ArtMaterials.burst_art(T("ventanilla"), res, geo(false))
	assert_true(int(b.cells) > 20, "toda la cara en trozos: %d" % b.cells)
	assert_eq((b.pieces as Array).size(), ArtMaterials.TEMPERED_PIECES, "los trozos del hueco, para que el banco los deje caer")
	for pc: Dictionary in b.pieces:
		assert_eq((pc.loop as PackedVector2Array).size(), (pc.poly as PackedVector2Array).size() + 1, "contorno cerrado")
	assert_true(draw(b, BENCH)[1], "el panal se pinta")
	assert_eq(ArtMaterials.lupa_kind(res), "templado-grieta", "la lupa enseña la grieta que atraviesa la capa comprimida")
	var lupa := ArtMaterials.lupa_art(T("ventanilla"), res)
	assert_true(String(lupa.text).contains(ArtMaterials.mm_text(float(gl.compressionMm))), "rótulo con la capa comprimida: %s" % lupa.text)
	assert_true(draw(lupa, lupa_view())[1])
	# más trozos (más compresión): más polígonos en la cara y en el cuadrado de 5 × 5 cm
	var small := res.duplicate(true)
	small.glazing.fragmentMm = float(gl.fragmentMm) / 2.0
	small.glazing.fragments25 = float(gl.fragments25) * 4.0
	assert_true(int(ArtMaterials.burst_art(T("ventanilla"), small, geo(false)).cells) > 3 * int(b.cells), "trozos de la mitad: unas cuatro veces más")
	# el cuadrado de la homologación: tantos trozos como dice el resultado (panal de lado fragmentMm)
	for delta: float in [float(gl.fragmentMm), 4.0, 8.0]:
		var cells := ArtMaterials.honeycomb(delta, Vector2(25.0, 25.0), Rect2(0, 0, 50, 50), "t")
		var inside := 0
		for c: Dictionary in cells:
			if Rect2(0, 0, 50, 50).has_point(c.c):
				inside += 1
		var want := Glazing.fragments_per_25cm2(delta)
		assert_near(float(inside), want, 0.15, 0.0, "trozos en 5 × 5 cm con δ = %s mm: %d (el modelo dice %s)" % [delta, inside, want])
	var flex := run(CASES["ventanilla que estalla (flexión)"])
	assert_eq(ArtMaterials.lupa_kind(flex), "templado-trozos", "por flexión, la lupa cuenta los trozos")
	var lf := ArtMaterials.lupa_art(T("ventanilla"), flex)
	assert_true(String(lf.text).contains(Js.js_num_str(Js.js_round(float(flex.glazing.fragments25)))), "cuenta del resultado: %s" % lf.text)
	assert_true(draw(lf, lupa_view())[1])
	# las marcas de la 1.x no dibujan la ventana recocida rota encima del panal, y el resultado no se toca
	var r1: Dictionary = ArtMaterials.res_for_1x_marks(res)
	assert_false(r1.shattered, "sin las grietas de la ventana de la 1.x")
	assert_true(res.shattered, "el resultado sigue igual")
	# sin glazing: nada
	var none := res.duplicate()
	none["glazing"] = null
	assert_eq(int(ArtMaterials.burst_art(T("ventanilla"), none, geo(false)).cells), 0, "sin glazing, sin panal")


func test_parabrisas_laminado_se_agrieta_y_no_cae() -> void:
	var res := run(CASES["parabrisas que se agrieta"])
	var gl: Dictionary = res.glazing
	assert_true(gl.cracked == true and gl.cause == "flexión" and gl.penetrationRisk == true, "el golpe de oso: se agrieta y podría atravesarlo")
	var b := ArtMaterials.burst_art(T("parabrisas"), res, geo(false))
	assert_eq(int(b.radials), ArtMaterials.laminated_radials(float(res.peakN), float(gl.bendN)))
	assert_true(int(b.radials) >= 6 and int(b.radials) <= 12, "de 6 a 12 radiales: %d" % b.radials)
	assert_eq(int(b.rings), 4, "con riesgo de atravesarlo, un anillo más y abombado")
	assert_true((b.pieces as Array).is_empty(), "la lámina sujeta los trozos: no cae ninguno")
	assert_true(draw(b, BENCH)[1])
	var calm := res.duplicate(true)
	calm.glazing.penetrationRisk = false
	assert_eq(int(ArtMaterials.burst_art(T("parabrisas"), calm, geo(false)).rings), 3, "sin riesgo, sin abombar")
	# más golpe, más radiales (nunca menos)
	var prev := 0
	for k: float in [1.0, 1.3, 2.0, 3.0, 4.0, 8.0, 50.0]:
		var n := ArtMaterials.laminated_radials(100.0 * k, 100.0)
		assert_true(n >= prev and n >= 6 and n <= 12, "radiales con el pico %s veces la carga: %d" % [k, n])
		prev = n
	assert_eq(ArtMaterials.lupa_kind(res), "laminado")
	var lupa := ArtMaterials.lupa_art(T("parabrisas"), res)
	assert_true(String(lupa.text).contains("PVB") and String(lupa.text).contains("0,76"), "las capas del resultado: %s" % lupa.text)
	assert_true(draw(lupa, lupa_view())[1])
	# agrietado por las grietas de contacto (no por flexión): sin la estrella grande (las grietas son las del surco)
	var contact := res.duplicate(true)
	contact.glazing.cause = "grieta"
	assert_eq(ArtMaterials.glazing_burst(contact), "", "sin estrella de flexión")


func test_abolladura_con_la_profundidad_del_resultado() -> void:
	var res := run(CASES["zarpazo que abolla"])
	var dent: Dictionary = res.dent
	assert_true(dent.visible == true, "el zarpazo de oso abolla la chapa")
	var a := ArtMaterials.dent_art(res, geo(false))
	assert_near(float(a.radius), ArtMaterials.DENT_SPAN * float(dent.depthMm) / 2.0 * ArtMaterials.MM, 1e-9, 0.0, "diámetro: 30 veces la profundidad")
	assert_near(float(a.sag), float(dent.depthMm) * ArtMaterials.MM * ArtMaterials.SAG, 1e-9, 0.0, "los reflejos bajan lo que se hunde")
	assert_true(draw(a, BENCH)[1], "la abolladura se pinta")
	# más abolladura: hoyuelo más hondo y más ancho
	var deeper := res.duplicate(true)
	deeper.dent.depthMm = float(dent.depthMm) * 2.0
	var ad := ArtMaterials.dent_art(deeper, geo(false))
	assert_true(float(ad.radius) > float(a.radius) and float(ad.sag) > float(a.sag), "más honda, más grande")
	# se ve desde 0,1 mm (dent.visible); por debajo, o sin chapa, nada
	var faint := res.duplicate(true)
	faint.dent.depthMm = 0.05
	faint.dent.visible = false
	assert_true((ArtMaterials.dent_art(faint, geo(false)).body as Array).is_empty(), "0,05 mm no se ve")
	var none := res.duplicate()
	none["dent"] = null
	assert_true((ArtMaterials.dent_art(none, geo(false)).body as Array).is_empty(), "sin dent, sin hoyuelo")
	# al rayar: una artesa a lo largo del surco
	var scr := run(CASES["surco abollado"])
	assert_true(scr.dent.visible == true)
	assert_true(draw(ArtMaterials.dent_art(scr, geo(true)), BENCH)[1], "la artesa se pinta")
	# la lupa: la chapa hundida, con la profundidad en el rótulo
	for pair: Array in [[res, "coche"], [scr, "coche"], [run(CASES["puerta abollada"]), "puertametal"]]:
		var r: Dictionary = pair[0]
		assert_eq(ArtMaterials.lupa_kind(r), "abolladura")
		var lupa := ArtMaterials.lupa_art(T(pair[1]), r)
		assert_true(String(lupa.text).contains(ArtMaterials.mm_text(float(r.dent.depthMm))), "rótulo con la profundidad: %s" % lupa.text)
		assert_true(draw(lupa, lupa_view())[1])


func test_huella_que_queda_al_levantar_la_punta() -> void:
	var res := run(CASES["barniz que recupera"])
	assert_eq(ArtMaterials.lupa_kind(res), "recuperacion", "el barniz recupera todo")
	var lupa := ArtMaterials.lupa_art(T("coche"), res)
	var dyn: Dictionary = lupa.dyn
	assert_true(float(dyn.dLoad) > 0.0, "bajo carga, hundido")
	assert_near(float(dyn.dRes) / float(dyn.dLoad), float(res.residualDepthUm) / float(res.depthUm), 1e-9, 1e-12, "sube lo que dice el resultado")
	var e := float(lupa.exaggeration)
	assert_true(e >= 1.0 and ArtMaterials.nice_floor(e) == e, "exageración vertical de la serie 1-2-5: ×%s" % e)
	assert_true(String(lupa.text).contains(Js.js_num_str(e)), "y escrita en el rótulo: %s" % lupa.text)
	assert_true(draw(lupa, lupa_view())[1])
	# con recuperación a medias (acero con una punta de zafiro: 9 %) o de un material que no la tiene (piel), sin lupa
	assert_eq(ArtMaterials.lupa_kind(run({ "geom": "stiletto", "base": "zafiro", "target": "acero" })), "")
	assert_eq(ArtMaterials.lupa_kind(run(CASES["uña que se dobla"])), "", "la uña que se dobla sobre la piel: sin lupa")
	assert_eq(ArtMaterials.RECOVERY_SHOWN, Physics.RECOVERY_TEXT_FRACTION, "el mismo umbral que el subtítulo")
	# perfil de la huella: el fondo en el centro, el borde del contacto a cero y la punta por encima fuera de él
	assert_near(ArtMaterials.groove_profile(0.0, 10.0, 4.0, 2.0), 4.0, 1e-12, 0.0)
	assert_near(ArtMaterials.groove_profile(10.0, 10.0, 4.0, 2.0), 0.0, 0.0, 1e-12)
	assert_true(ArtMaterials.groove_profile(15.0, 10.0, 4.0, 1.3) < 0.0, "fuera del contacto, la punta sube")


func test_la_una_se_parte_por_la_raiz_del_borde_libre() -> void:
	for g: Dictionary in Catalog.GEOMS:
		var geom := ArtMaterials.nail_geometry(g)
		var edge: PackedVector2Array = geom.edge_clip
		var finger: PackedVector2Array = geom.finger_clip
		assert_true(Geometry2D.is_point_in_polygon(Vector2(-0.5, -0.3), edge), "%s: la punta va con el borde libre" % g.id)
		assert_false(Geometry2D.is_point_in_polygon(Vector2(-0.5, -0.3), finger), "%s: y no con el dedo" % g.id)
		var pivot: Vector2 = geom.pivot
		assert_true(pivot.x < 0.0 and pivot.y < 0.0 and pivot.length() > float(geom.free) * 0.9, "%s: la raíz, a una uña libre de la punta" % g.id)
		# el pulpejo (debajo del borde libre) se queda en el dedo
		assert_true(Geometry2D.is_point_in_polygon(geom.pad, finger), "%s: el pulpejo, en el dedo" % g.id)
		assert_false(Geometry2D.is_point_in_polygon(geom.pad, edge), "%s: y no se dobla con la uña" % g.id)
		var o := { "geom": g, "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "wet": false, "uid": "t" }
		var view := Rect2(-151, -115, 156, 121)
		assert_true(draw(ArtMaterials.nail_part_art(o, "finger"), view)[1], "%s: el dedo se pinta" % g.id)
		assert_true(draw(ArtMaterials.nail_part_art(o, "edge"), view)[1], "%s: el borde libre se pinta" % g.id)


func test_thorvg_y_determinismo_en_todos_los_casos() -> void:
	for name: String in CASES:
		var o: Dictionary = CASES[name]
		var res := run(o)
		var t := T(o.target)
		var scratch: bool = not res.puncture
		var arts := {
			"abolladura": ArtMaterials.dent_art(res, geo(scratch)), "surco": ArtMaterials.track_art(res, geo(scratch)),
			"punto": ArtMaterials.burst_art(t, res, geo(scratch)),
		}
		for k: String in arts:
			var a: Dictionary = arts[k]
			if (a.body as Array).is_empty():
				continue
			var d := draw(a, BENCH)
			assert_true(d[1], "%s · %s: ThorVG lo pinta" % [name, k])
			var svg: String = d[0]
			assert_false(svg.contains("NaN") or svg.contains("Infinity") or svg.contains("nan"), "%s · %s: números finitos" % [name, k])
		var lupa := ArtMaterials.lupa_art(t, res)
		if not (lupa.body as Array).is_empty():
			var d := draw(lupa, lupa_view())
			assert_true(d[1], "%s · lupa: ThorVG la pinta" % name)
			assert_eq(Svg.scene_to_svg(ArtMaterials.lupa_art(t, run(o)), { "viewBox": "0 0 1 1", "width": 1.0, "height": 1.0 }),
				Svg.scene_to_svg(lupa, { "viewBox": "0 0 1 1", "width": 1.0, "height": 1.0 }), "%s · lupa: determinista" % name)
		assert_eq(Svg.scene_to_svg(ArtMaterials.burst_art(t, run(o), geo(scratch)), { "viewBox": "0 0 1 1", "width": 1.0, "height": 1.0 }),
			Svg.scene_to_svg(arts["punto"], { "viewBox": "0 0 1 1", "width": 1.0, "height": 1.0 }), "%s: determinista" % name)


func test_numeros_y_rotulos() -> void:
	assert_eq(ArtMaterials.nice_floor(1000.0), 1000.0)
	assert_eq(ArtMaterials.nice_floor(999.0), 500.0)
	assert_eq(ArtMaterials.nice_floor(0.0042), 0.002)
	assert_eq(ArtMaterials.nice_floor(7.0), 5.0)
	assert_eq(ArtMaterials.nice_floor(2.0), 2.0)
	assert_eq(ArtMaterials.nice_floor(0.0), 0.0)
	assert_eq(ArtMaterials.len_text(500.0), "500 µm")
	assert_eq(ArtMaterials.len_text(1000.0), "1 mm")
	assert_eq(ArtMaterials.len_text(2500.0), "2,5 mm")
	assert_eq(ArtMaterials.len_text(20000.0), "2 cm")
	assert_eq(ArtMaterials.mm_text(0.32459), "0,32")
	assert_eq(ArtMaterials.mm_text(2.7636), "2,8")
