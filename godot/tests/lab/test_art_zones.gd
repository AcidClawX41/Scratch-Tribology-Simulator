## El corte de la piel por zonas del cuerpo (core/lab/art_zones.gd, lo que dejó pendiente la 4b): Art.skin_section_art lo
## usa con un resultado de la 2.0 de otra zona o que llega al hueso, y con cualquier otro sigue dibujando el brazo de la
## 1.x (sus SVG del oráculo los vigila test_art.gd). Las bandas son las capas de la zona con su hueso (o la cavidad), la
## herida acaba en la capa que dice el resultado, la médula sale solo si la punta atraviesa la cortical, los rótulos dicen
## los espesores de la zona y lo que le pasa al hueso, y ThorVG lo pinta.
extends "res://tests/case.gd"

const Art = preload("res://core/lab/art.gd")
const ArtZones = preload("res://core/lab/art_zones.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const Zones = preload("res://core/lab/zones.gd")
const Looks = preload("res://core/lab/looks.gd")
const Svg = preload("res://core/lab/svg.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")

const VIEW := { "viewBox": "0 0 300 164", "width": 300.0, "height": 164.0 }

## Los ensayos de biología de la demo del laboratorio (casos 16-20) y otros que tocan cada caso del hueso.
const CASES := {
	"pájaro en la palma (callo)": { "claw": "pajaro", "target": "piel", "zone": "palma", "force": 1.5 },
	"víbora en el pómulo (entra)": { "claw": "vibora", "target": "piel", "zone": "cara", "method": "puncion", "force": 4.0 },
	"casuario de tungsteno en el brazo (atraviesa)": { "claw": "casuario", "inlay": "tungsteno", "target": "piel", "zone": "brazo",
		"method": "puncion", "strike": true },
	"Gabón en el abdomen (cavidad)": { "claw": "gabon", "target": "piel", "zone": "abdomen", "method": "puncion", "strike": true, "force": 30.0 },
	"tigre en el dorso de la mano (hasta el hueso)": { "claw": "tigre", "target": "piel", "zone": "dorsomano" },
	"Gabón en el brazo (se rompe)": { "claw": "gabon", "target": "piel", "method": "puncion", "strike": true, "force": 30.0 },
	"casuario en el brazo (topa)": { "claw": "casuario", "target": "piel", "method": "puncion", "strike": true },
	"víbora en el dorso de la mano": { "claw": "vibora", "target": "piel", "zone": "dorsomano", "method": "puncion", "force": 4.0 },
	"uña en la cara": { "target": "piel", "zone": "cara", "force": 4.0 },
}


## Un ensayo con los catálogos de la 2.0: sin fuerza, la del botón de fuerza máxima (la de la demo).
static func run(o: Dictionary) -> Dictionary:
	var claw: Variant = Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null
	var p := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, o.get("geom", "almendra")), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")), "claw": claw,
		"target": Catalog.find_by_id(Catalog.TARGETS, o.target), "length": 25.0, "type": Catalog.TYPES[1], "tear": false,
		"method": o.get("method", "rayado"), "strike": o.get("strike", false), "passes": 1.0, "wet": false, "zone": o.get("zone"),
		"force": float(o.get("force", Lab.max_force_hint(claw).get("force", 30.0))),
	}
	if o.has("model"):
		p["model"] = o.model
	return Physics.compute(p)


static func svg_of(art: Dictionary) -> String:
	return Svg.scene_to_svg(art, VIEW)


static func texts(art: Dictionary) -> Array:
	return (art.labels as Array).map(func(l: Dictionary) -> String: return String(l.text))


func test_el_brazo_de_la_1x_sigue_igual() -> void:
	# la 1.x (sin pen) y el brazo de la 2.0 que no llega al hueso: el corte de siempre
	var v1 := run({ "claw": "vibora", "target": "piel", "method": "puncion", "force": 4.0, "model": Physics.MODEL_V1 })
	assert_eq(v1.pen, null, "la 1.x no trae el informe de la punción")
	assert_false(ArtZones.applies(v1), "la 1.x: el corte de la 1.x")
	var v2 := run({ "claw": "vibora", "target": "piel", "method": "puncion", "force": 4.0 })
	assert_eq(String(v2.zone), "brazo")
	assert_false(v2.pen.boneHit, "la víbora no llega al húmero")
	assert_false(ArtZones.applies(v2), "el brazo sin hueso: el corte de la 1.x")
	var no_pen := v2.duplicate()
	no_pen["pen"] = null
	assert_eq(svg_of(Art.skin_section_art(v2, { "uid": "sks" })), svg_of(Art.skin_section_art(no_pen, { "uid": "sks" })),
		"el mismo SVG que con el corte de la 1.x")
	for o: Dictionary in [{ "target": "piel", "force": 4.0 }, { "claw": "gato", "target": "piel" }]:
		assert_false(ArtZones.applies(run(o)), "%s en el brazo: el corte de la 1.x" % o)
	# otra zona o el hueso del brazo: el corte nuevo; nunca un sólido ni el aguijón (que tiene su corte)
	assert_true(ArtZones.applies(run(CASES["pájaro en la palma (callo)"])), "otra zona")
	assert_true(ArtZones.applies(run(CASES["Gabón en el brazo (se rompe)"])), "el brazo, si llega al húmero")
	assert_false(ArtZones.applies(run({ "target": "madera" })), "un sólido")
	var sting := run({ "claw": "abeja", "target": "piel", "zone": "palma", "force": 0.02 })
	assert_true(sting.get("sting") is Dictionary, "un aguijón")
	assert_false(ArtZones.applies(sting), "el aguijón tiene su propio corte")
	assert_false(ArtZones.applies(null))


func test_bandas_de_cada_zona_con_su_hueso_o_la_cavidad() -> void:
	for zone: String in Zones.ids():
		var res := run({ "claw": "gato", "target": "piel", "zone": zone, "force": 3.0 })
		var bs := ArtZones.bands(res)
		var want: Array = Zones.section_layers(zone).map(func(l: Dictionary) -> String: return String(l.id))
		assert_eq(bs.map(func(b: Dictionary) -> String: return String(b.id)), want, "%s: las capas de la zona y su hueso" % zone)
		assert_eq(float(bs[0].y0), ArtZones.TOP, "%s: desde arriba del bloque" % zone)
		assert_eq(float(bs[-1].y1), ArtZones.BOTTOM, "%s: hasta abajo" % zone)
		for i in bs.size():
			var b: Dictionary = bs[i]
			assert_true(float(b.y1) > float(b.y0) + 3.0, "%s · %s: la banda se ve" % [zone, b.id])
			if i > 0:
				assert_eq(float(b.y0), float(bs[i - 1].y1), "%s · %s: sin huecos" % [zone, b.id])
		var last: Dictionary = bs[-1]
		var deep_min: float = Zones.SECTION_BAND.get(String(last.id), 14.0)
		assert_true(float(last.y1) - float(last.y0) >= deep_min - 1e-9, "%s: el hueso o la cavidad, al menos su alto" % zone)
	# el callo de la palma, más grueso que la capa córnea del brazo; la dermis de la cara, más fina
	var h := func(zone: String, id: String) -> float:
		var b: Dictionary = ArtZones.band(ArtZones.bands(run({ "claw": "gato", "target": "piel", "zone": zone, "force": 3.0 })), id)
		return float(b.y1) - float(b.y0)
	assert_true(h.call("palma", "cornea") > 1.8 * h.call("brazo", "cornea"), "el callo de serie se ve")
	assert_true(h.call("cara", "dermis") < h.call("brazo", "dermis"), "la dermis de la cara, más fina que la del brazo")
	# cuanto menos tejido blando hay encima, más grande se ve el hueso
	var bone_h := func(zone: String) -> float: return h.call(zone, "hueso")
	assert_true(bone_h.call("dorsomano") > bone_h.call("cara") and bone_h.call("cara") > bone_h.call("palma")
		and bone_h.call("palma") > bone_h.call("brazo"), "el hueso de la mano y el del pómulo, cerca")


func test_la_herida_acaba_en_la_capa_del_resultado() -> void:
	for name: String in CASES:
		var res := run(CASES[name])
		assert_true(ArtZones.applies(res), "%s: corte por zonas" % name)
		var bs := ArtZones.bands(res)
		var pen: Dictionary = res.pen
		var d: float = res.depthUm
		var y := ArtZones.y_at(bs, d)
		var want := String(pen.layerId)
		if pen.get("boneHit") == true and want == "musculo":
			want = "hueso"  # justo en la superficie del hueso: la frontera entre las dos bandas
		var got := ""
		for b: Dictionary in bs:
			if y >= float(b.y0) - 1e-6 and y <= float(b.y1) + 1e-6:
				got = String(b.id)
				if got == want:
					break
		assert_eq(got, want, "%s: la herida acaba en «%s»" % [name, pen.layer])
		# la médula solo si atraviesa la cortical
		assert_eq(ArtZones.band(bs, "medula") != null, pen.get("bonePierced") == true, "%s: médula solo si la atraviesa" % name)
	# más hondo, más abajo en el corte (en una misma zona)
	var bs := ArtZones.bands(run(CASES["víbora en el pómulo (entra)"]))
	var prev := -1.0
	for um: float in [0.0, 10.0, 74.0, 500.0, 1074.0, 4000.0, 8700.0, 9000.0, 10200.0]:
		var y := ArtZones.y_at(bs, um)
		assert_true(y >= prev, "%s µm: más abajo" % um)
		prev = y


func test_lo_que_le_pasa_al_hueso() -> void:
	var want := {
		"víbora en el pómulo (entra)": "entra 15 µm", "Gabón en el brazo (se rompe)": "punta rota",
		"casuario de tungsteno en el brazo (atraviesa)": "la atraviesa", "casuario en el brazo (topa)": "no lo marca",
		"tigre en el dorso de la mano (hasta el hueso)": "hasta el hueso", "pájaro en la palma (callo)": "",
		"Gabón en el abdomen (cavidad)": "",
	}
	for name: String in want:
		var res := run(CASES[name])
		assert_eq(ArtZones.bone_tag(res), want[name], name)
		var art := Art.skin_section_art(res, { "uid": "sks" })
		if want[name] != "":
			assert_true(texts(art).has(want[name]), "%s: el corte lo dice" % name)
	# la punta rota se queda clavada: un trozo de marfil en el hueso
	var broken := svg_of(Art.skin_section_art(run(CASES["Gabón en el brazo (se rompe)"]), { "uid": "sks" }))
	assert_true(broken.contains(ArtZones.TIP_IVORY), "el trozo de la punta")
	assert_false(svg_of(Art.skin_section_art(run(CASES["víbora en el pómulo (entra)"]), { "uid": "sks" })).contains(ArtZones.TIP_IVORY),
		"sin romperse, no hay trozo")


func test_rotulos_con_los_espesores_de_la_zona() -> void:
	var palm := texts(Art.skin_section_art(run(CASES["pájaro en la palma (callo)"]), { "uid": "sks" }))
	assert_true(palm.has("Capa córnea · 173 µm"), "el callo de la palma: %s" % [palm])
	assert_true(palm.has("Hueso a 17,8 mm"), "el primer metacarpiano, a 17,8 mm")
	assert_true(palm.has("≈ 75 µm"), "lo que pule")
	var face := texts(Art.skin_section_art(run(CASES["víbora en el pómulo (entra)"]), { "uid": "sks" }))
	assert_true(face.has("Hueso a 8,7 mm") and face.has("Músculo · 1,6 mm"), "el pómulo: %s" % [face])
	var belly := texts(Art.skin_section_art(run(CASES["Gabón en el abdomen (cavidad)"]), { "uid": "sks" }))
	assert_true(belly.has("Cavidad a 26,7 mm") and belly.has("≈ 50.0 mm"), "el abdomen: %s" % [belly])
	var arm := texts(Art.skin_section_art(run(CASES["casuario de tungsteno en el brazo (atraviesa)"]), { "uid": "sks" }))
	assert_true(arm.has("Hueso a 41,4 mm") and arm.has("Médula"), "el húmero atravesado: %s" % [arm])


func test_el_corte_del_aguijon_tambien_va_por_zonas() -> void:
	# sting_lab.gd pica con las capas de la zona: el corte del aguijón las enseña (en el brazo, el de siempre)
	var bee: Dictionary = Catalog.find_by_id(Catalog.CLAWS, "abeja")
	for zone: String in Zones.ids():
		var res := run({ "claw": "abeja", "target": "piel", "zone": zone, "force": float(bee.force) })
		var s: Dictionary = res.sting
		var zb := ArtInsects.zone_bands(res, ArtInsects.SECTION.air)
		if zone == Zones.DEFAULT_ID:
			assert_true(zb.is_empty(), "el brazo: el corte de siempre")
			continue
		assert_eq(zb.map(func(b: Dictionary) -> String: return String(b.id)),
			Zones.section_layers(zone).map(func(l: Dictionary) -> String: return String(l.id)), "%s: las capas de la zona" % zone)
		assert_eq(float(zb[0].y0), float(ArtInsects.SECTION.air), "%s: bajo el aire del corte" % zone)
		var art := ArtInsects.sting_section_art(res, bee, { "uid": "t" })
		var want := "%s · %s" % [zb[0].short, Art._thick_label(float(zb[0].to))]
		assert_true(texts(art).has(want), "%s: %s en %s" % [zone, want, texts(art)])
		if s.get("pierces") == true:
			var y := ArtZones.y_at(zb, float(res.depthUm))
			var b: Dictionary = ArtZones.band(zb, String(s.layerId))
			assert_true(y >= float(b.y0) - 1e-6 and y <= float(b.y1) + 1e-6, "%s: el aguijón acaba en «%s»" % [zone, s.layerId])
	# la abeja deja el veneno en la grasa de la palma y en la dermis del brazo (pulido-biologia.md §9.9)
	var palm := run({ "claw": "abeja", "target": "piel", "zone": "palma", "force": float(bee.force) })
	assert_eq(String(palm.sting.layerId), "grasa", "en la palma, en la grasa")


func test_thorvg_y_determinismo() -> void:
	for name: String in CASES:
		var res := run(CASES[name])
		var art := Art.skin_section_art(res, { "uid": "sks" })
		var svg := svg_of(art)
		assert_false(svg.contains("NaN") or svg.contains("Infinity") or svg.contains("nan"), "%s: números finitos" % name)
		var img := SvgTexture.rasterize_image(svg, 1.0)
		assert_true(img != null and img.get_used_rect().has_area(), "%s: ThorVG lo pinta" % name)
		assert_eq(svg_of(Art.skin_section_art(run(CASES[name]), { "uid": "sks" })), svg, "%s: determinista" % name)
	# los tejidos nuevos, también sueltos
	for id: String in Zones.SECTION_LOOK:
		var a := ArtZones.tissue_surface(id, { "x": 0.0, "y": 0.0, "w": 150.0, "h": 30.0, "uid": "t", "detail": 0.8 })
		var img := SvgTexture.rasterize_image(Svg.scene_to_svg(a, { "viewBox": "0 0 150 30", "width": 150.0, "height": 30.0 }), 1.0)
		assert_true(img != null and img.get_used_rect().has_area(), "%s: ThorVG lo pinta" % id)
