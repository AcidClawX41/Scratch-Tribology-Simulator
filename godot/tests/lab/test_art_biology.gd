## Las lupas de la biología de la 2.0 en el banco (core/lab/art_biology.gd): la punción a escala verdadera que llega al
## hueso de la zona (y lo marca, lo atraviesa o rompe el colmillo) o a la cavidad del abdomen. Sale solo cuando el
## resultado lo trae (nunca con la 1.x, ni al rayar, ni si la punta no llega al hueso); la escala es la de verdad (el hueso
## y el fondo de la herida a su profundidad, la barra de escala en el rótulo) y ThorVG la pinta.
extends "res://tests/case.gd"

const ArtBiology = preload("res://core/lab/art_biology.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")
const Zones = preload("res://core/lab/zones.gd")
const Svg = preload("res://core/lab/svg.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")

## Punciones de la demo (casos 17-19) y las de cada cosa que le puede pasar al hueso.
const CASES := {
	"víbora en el pómulo (entra)": { "claw": "vibora", "zone": "cara", "force": 4.0 },
	"casuario de tungsteno en el brazo (atraviesa)": { "claw": "casuario", "inlay": "tungsteno", "zone": "brazo", "strike": true },
	"Gabón en el abdomen (cavidad)": { "claw": "gabon", "zone": "abdomen", "strike": true, "force": 30.0 },
	"Gabón en el brazo (se rompe)": { "claw": "gabon", "strike": true, "force": 30.0 },
	"casuario en el brazo (topa)": { "claw": "casuario", "strike": true },
	"víbora en el dorso de la mano (entra)": { "claw": "vibora", "zone": "dorsomano", "force": 4.0 },
}


## Una punción en la piel con los catálogos de la 2.0 (sin fuerza, la del botón de fuerza máxima).
static func run(o: Dictionary) -> Dictionary:
	var claw: Variant = Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null
	return Physics.compute({
		"geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")), "claw": claw,
		"target": Catalog.find_by_id(Catalog.TARGETS, o.get("target", "piel")), "length": 25.0, "type": Catalog.TYPES[1], "tear": false,
		"method": o.get("method", "puncion"), "strike": o.get("strike", false), "passes": 1.0, "wet": false, "zone": o.get("zone"),
		"force": float(o.get("force", Lab.max_force_hint(claw).get("force", 30.0))), "model": o.get("model", Physics.MODEL_V2),
	})


static func lupa_view() -> Dictionary:
	var r := ArtMaterials.LUPA_R + 2.0
	return { "viewBox": "%s %s %s %s" % [-r, -r, 2.0 * r, 2.0 * r], "width": 2.0 * r, "height": 2.0 * r }


func test_la_lupa_sale_cuando_la_punta_llega_al_hueso_o_a_la_cavidad() -> void:
	var want := {
		"víbora en el pómulo (entra)": "hueso", "casuario de tungsteno en el brazo (atraviesa)": "hueso",
		"Gabón en el abdomen (cavidad)": "cavidad", "Gabón en el brazo (se rompe)": "hueso", "casuario en el brazo (topa)": "hueso",
		"víbora en el dorso de la mano (entra)": "hueso",
	}
	for name: String in want:
		assert_eq(ArtBiology.lupa_kind(run(CASES[name])), want[name], name)
	# nada si la punta no llega al hueso, al rayar, con la 1.x o en un sólido
	assert_eq(ArtBiology.lupa_kind(run({ "claw": "vibora", "force": 4.0 })), "", "la víbora no llega al húmero")
	assert_eq(ArtBiology.lupa_kind(run({ "claw": "tigre", "zone": "dorsomano", "method": "rayado", "force": 30.0 })), "",
		"al rayar sin llegar al hueso")
	assert_eq(ArtBiology.lupa_kind(run({ "claw": "vibora", "zone": "cara", "force": 4.0, "model": Physics.MODEL_V1 })), "", "la 1.x")
	assert_eq(ArtBiology.lupa_kind(run({ "claw": "vibora", "target": "madera", "force": 4.0 })), "", "un sólido")
	assert_eq(ArtBiology.lupa_kind(run({ "claw": "pajaro", "zone": "cara", "force": 0.2 })), "", "sin perforar")
	assert_eq(ArtBiology.lupa_kind(null), "")
	# las de los materiales van antes: con un resultado de la biología, ArtMaterials no tiene nada que enseñar
	for name: String in CASES:
		assert_eq(ArtMaterials.lupa_kind(run(CASES[name])), "", "%s: sin lupa de los materiales" % name)


func test_a_escala_verdadera() -> void:
	for name: String in CASES:
		var res := run(CASES[name])
		var lupa := ArtBiology.lupa_art(Catalog.find_by_id(Catalog.TARGETS, "piel"), res)
		var dyn: Dictionary = lupa.dyn
		var k: float = lupa.scale
		assert_near(float(dyn.k), k, 1e-12, 0.0, "%s: la misma escala" % name)
		assert_near(float(dyn.depth) / k, float(res.depthUm), 1e-9, 1e-9, "%s: el fondo de la herida, a depthUm" % name)
		var zone := String(res.zone)
		if lupa.kind == "hueso":
			var bone: Dictionary = Zones.bone(zone)
			assert_near(float(dyn.bone) / k, float(bone.fromUm), 1e-9, 1e-9, "%s: el hueso, a su profundidad" % name)
			assert_near((float(dyn.boneEnd) - float(dyn.bone)) / k, float(bone.corticalUm), 1e-9, 1e-9, "%s: su cortical" % name)
			assert_true(String(lupa.text).contains(String(bone.name).to_lower()), "%s: el rótulo nombra el hueso: %s" % [name, lupa.text])
		else:
			assert_true(String(lupa.text).contains("cavidad a 26,7 mm"), "%s: %s" % [name, lupa.text])
		# la barra de escala: la longitud «redonda» del rótulo, en la escala de la lupa
		var bar := ArtMaterials.nice_floor(0.55 * float(dyn.r) / k)
		assert_true(String(lupa.text).begins_with(ArtMaterials.len_text(bar) + " · "), "%s: la barra en el rótulo: %s" % [name, lupa.text])
		# lo que pasa, del resultado
		assert_eq(bool(dyn.pierced), res.pen.bonePierced == true, "%s: atraviesa" % name)
		assert_eq(bool(dyn.broken), res.pen.toolBroken == true, "%s: se rompe" % name)
		assert_near(float(dyn.indent), float(res.pen.boneIndentUm), 1e-12, 0.0, "%s: lo que entra" % name)
	assert_true(String(ArtBiology.lupa_art({}, run(CASES["víbora en el pómulo (entra)"])).text).ends_with("entra 15 µm"))
	assert_true(String(ArtBiology.lupa_art({}, run(CASES["Gabón en el brazo (se rompe)"])).text).ends_with("punta rota"))


## Rayados de la demo (casos 16, 21 y 22) para las lupas quietas.
const SCRATCHES := {
	"pájaro en la palma (callo)": { "claw": "pajaro", "zone": "palma", "force": 1.5, "method": "rayado", "want": "callo" },
	"stiletto tumbada a 20° en el pino (ataque)": { "geom": "stiletto", "target": "madera", "attack": 20.0, "force": 10.0, "method": "rayado",
		"want": "ataque" },
	"víbora en el cobre (esmalte)": { "claw": "vibora", "target": "cobre", "force": 4.0, "method": "rayado", "want": "esmalte" },
	"garra de gancho en el pino (ataque)": { "claw": "tigre", "target": "madera", "attack": 150.0, "force": 60.0, "method": "rayado",
		"want": "ataque" },
	"tigre en el dorso de la mano (laceración hasta el hueso)": { "claw": "tigre", "zone": "dorsomano", "force": 260.0, "method": "rayado",
		"want": "laceracion" },
	"velocirraptor de diamante afilado en el acero (afilado)": { "claw": "velociraptor", "inlay": "diamante", "target": "acero",
		"sharpness": 0.5, "force": 30.0, "method": "rayado", "want": "afilado" },
}


static func run_scratch(o: Dictionary) -> Dictionary:
	var claw: Variant = Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null
	return Physics.compute({
		"geom": Catalog.find_by_id(Catalog.GEOMS, o.get("geom", "almendra")), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")), "claw": claw,
		"target": Catalog.find_by_id(Catalog.TARGETS, o.get("target", "piel")), "length": 25.0, "type": Catalog.TYPES[1], "tear": false,
		"method": "rayado", "strike": false, "passes": 1.0, "wet": false, "zone": o.get("zone"), "attack_deg": o.get("attack"),
		"force": float(o.get("force", 30.0)), "model": o.get("model", Physics.MODEL_V2), "sharpness": float(o.get("sharpness", 0.0)),
	})


func test_las_lupas_quietas_del_esmalte_el_ataque_y_el_callo() -> void:
	for name: String in SCRATCHES:
		var o: Dictionary = SCRATCHES[name]
		var res := run_scratch(o)
		assert_eq(ArtBiology.lupa_kind(res), String(o.want), name)
		var lupa := ArtBiology.lupa_art(Catalog.find_by_id(Catalog.TARGETS, o.get("target", "piel")), res)
		assert_true(float(lupa.scale) > 0.0 and String(lupa.text) != "", "%s: escala y rótulo" % name)
		# la barra: horizontal, de la mitad del diámetro; vertical (la laceración, que baja desde la piel), algo más corta
		var f := 0.55 if o.want == "laceracion" else 1.0
		var bar := ArtMaterials.nice_floor(f * ArtMaterials.LUPA_R / float(lupa.scale))
		assert_true(String(lupa.text).begins_with(ArtMaterials.len_text(bar) + " · "), "%s: la barra en el rótulo: %s" % [name, lupa.text])
	# lo que dicen, del resultado
	var enamel := run_scratch(SCRATCHES["víbora en el cobre (esmalte)"])
	assert_eq(String(ArtBiology.lupa_art({ "id": "cobre" }, enamel).text), "100 µm · esmalte de 10 µm · %s HV en la punta" % Js.to_fixed(float(enamel.tipHv), 0))
	var plough := run_scratch(SCRATCHES["stiletto tumbada a 20° en el pino (ataque)"])
	assert_eq(String(plough.absMode), "arado", "tumbada, ara")
	assert_true(String(ArtBiology.lupa_art({ "id": "madera" }, plough).text).contains("arado · cara a 1° · se arranca el 3 %"))
	var callus := run_scratch(SCRATCHES["pájaro en la palma (callo)"])
	assert_true(String(ArtBiology.lupa_art({}, callus).text).ends_with("capa córnea de 173 µm: pule 75 µm"))
	var lace := run_scratch(SCRATCHES["tigre en el dorso de la mano (laceración hasta el hueso)"])
	assert_true(lace.pen.boneHit, "la garra llega al metacarpiano")
	assert_true(String(ArtBiology.lupa_art({}, lace).text).ends_with("tercer metacarpiano a 5,6 mm · hasta el hueso"),
		String(ArtBiology.lupa_art({}, lace).text))
	assert_near(float(ArtBiology.lupa_art({}, lace).scale) * float(Zones.bone("dorsomano").fromUm), (ArtBiology.FLOOR_Y - ArtBiology.SKIN_Y)
		* ArtMaterials.LUPA_R * float(Zones.bone("dorsomano").fromUm) / maxf(float(lace.depthUm) * 1.12, float(Zones.bone("dorsomano").toUm)
		+ 0.35 * float(Zones.bone("dorsomano").corticalUm)), 1e-9, 1e-9, "el hueso, a su profundidad a escala")
	# y cuándo no: el ángulo de siempre, una punta que no es de esmalte o un contacto grande (la dentina manda), el brazo
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "geom": "stiletto", "target": "madera", "force": 10.0 })), "", "la uña a sus 45°")
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "claw": "tigre", "target": "madera", "force": 60.0 })), "", "la garra a sus 90°")
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "claw": "vibora", "inlay": "diamante", "target": "cobre", "force": 4.0 })), "",
		"un colmillo reforjado no tiene esmalte")
	var wood := run_scratch({ "claw": "vibora", "target": "madera", "force": 4.0 })
	assert_true(float(wood.tipHv) <= float(wood.hvTool) * ArtBiology.ENAMEL_SHOWN, "en el pino el contacto es grande: dentina")
	assert_eq(ArtBiology.lupa_kind(wood), "")
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "claw": "pajaro", "force": 1.5 })), "", "el brazo no tiene callo")
	# el afilado (4n): la punta afilada con la natural a trazos; sin afilar, nada
	var sharp := run_scratch(SCRATCHES["velocirraptor de diamante afilado en el acero (afilado)"])
	var sh: Dictionary = sharp.sharpness
	var sl := ArtBiology.lupa_art({ "id": "acero" }, sharp)
	assert_true(String(sl.text).contains("punta de %s (la natural, %s)" % [Format.fmt_tip_um(float(sh.tipRadiusUm)).replace(".", ","),
		Format.fmt_tip_um(float(sh.naturalUm)).replace(".", ",")]), String(sl.text))
	assert_near(float(sl.scale), 0.42 * ArtMaterials.LUPA_R / maxf(float(sh.naturalUm), float(sharp.depthUm)), 1e-12, 0.0, "a la escala de la punta natural")
	assert_eq(String(sl.text).ends_with(" · se mella") or String(sl.text).ends_with(" · se dobla"), not bool(sh.survives), "si se mella, lo dice")
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "claw": "velociraptor", "inlay": "diamante", "target": "acero", "force": 30.0 })), "",
		"sin afilar, la punta de la ficha")
	assert_eq(ArtBiology.lupa_kind(run_scratch({ "claw": "pajaro", "zone": "palma", "force": 1.5, "model": Physics.MODEL_V1 })), "", "la 1.x")


func test_los_rebordes_del_arado_tienen_el_area_de_lo_que_se_aparta() -> void:
	# del volumen del surco, lo que no se arranca va a los dos rebordes: más arado, rebordes más altos; nada, si se arranca todo
	var a := 8.0
	var d := 12.0
	for p: float in [2.0, 1.3]:
		var area := ArtBiology.groove_area(a, d, p)
		var prev := INF
		for fab: float in [0.0, 0.03, 0.3, 0.53, 0.9, 1.0]:
			var h := ArtBiology.ridge_height(a, d, p, fab)
			assert_near(2.0 * (4.0 / 3.0) * h * ArtBiology.RIDGE_SPAN * a, (1.0 - fab) * area, 1e-12, 1e-9, "p %s, fab %s: el área" % [p, fab])
			assert_true(h <= prev, "p %s: menos arrancado, rebordes más altos" % p)
			prev = h
		assert_eq(ArtBiology.ridge_height(a, d, p, 1.0), 0.0, "si se arranca todo, sin rebordes")


func test_thorvg_y_determinismo() -> void:
	var piel: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "piel")
	for name: String in CASES:
		var lupa := ArtBiology.lupa_art(piel, run(CASES[name]))
		var svg := Svg.scene_to_svg(lupa, lupa_view())
		assert_false(svg.contains("NaN") or svg.contains("Infinity") or svg.contains("nan"), "%s: números finitos" % name)
		var img := SvgTexture.rasterize_image(svg, 1.0)
		assert_true(img != null and img.get_used_rect().has_area(), "%s: ThorVG la pinta" % name)
		assert_eq(Svg.scene_to_svg(ArtBiology.lupa_art(piel, run(CASES[name])), lupa_view()), svg, "%s: determinista" % name)
	for name: String in SCRATCHES:
		var o: Dictionary = SCRATCHES[name]
		var t: Dictionary = Catalog.find_by_id(Catalog.TARGETS, o.get("target", "piel"))
		var svg := Svg.scene_to_svg(ArtBiology.lupa_art(t, run_scratch(o)), lupa_view())
		assert_false(svg.contains("NaN") or svg.contains("Infinity") or svg.contains("nan"), "%s: números finitos" % name)
		var img := SvgTexture.rasterize_image(svg, 1.0)
		assert_true(img != null and img.get_used_rect().has_area(), "%s: ThorVG la pinta" % name)
		assert_eq(Svg.scene_to_svg(ArtBiology.lupa_art(t, run_scratch(o)), lupa_view()), svg, "%s: determinista" % name)
	var none := ArtBiology.lupa_art(piel, run({ "claw": "vibora", "force": 4.0 }))
	assert_eq(none.kind, "")
	assert_true((none.body as Array).is_empty(), "sin lupa, sin dibujo")
