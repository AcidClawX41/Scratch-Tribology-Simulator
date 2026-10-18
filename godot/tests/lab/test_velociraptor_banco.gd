## El velocirraptor en el banco (unidad 4i; docs/fisica/velociraptor.md §10.1, §10.2 y §10.4): la ficha, la fuerza
## máxima, el dibujo de su garra (art_dino.gd), el estado del afilado (LabState) y los textos de su deslizador
## (dino_lab.gd), con los números de velociraptor.gd y claw_sharpness.gd, sin copiarlos. Y la patada del casuario, que en
## el banco es la del coche en marcha.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const ArtDino = preload("res://core/lab/art_dino.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const Svg = preload("res://core/lab/svg.gd")
const Js = preload("res://core/shared/js.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")

const ICON := Rect2(0, 0, 100, 132)


static func K(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func view(r: Rect2) -> Dictionary:
	return { "viewBox": "%s %s %s %s" % [r.position.x, r.position.y, r.size.x, r.size.y], "width": r.size.x, "height": r.size.y }


# ── La ficha y la fuerza máxima ──

func test_la_ficha_dice_reconstruccion_con_sus_bandas() -> void:
	var raptor := K("velociraptor")
	var tool := Physics.resolve_tool({ "claw": raptor, "inlay": I("none"), "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0] })
	var spec := Lab.claw_spec(raptor, I("none"), tool)
	var rows := DinoLab.spec_rows(raptor, spec.material, spec.hardness, tool)
	var keys: Array = rows.map(func(r: Array) -> String: return r[0])
	assert_eq(keys, ["queratina", "reconstrucción", "punta", "garra", "hueso fósil", "peso", "agarre de un pie", "golpe"])
	var by := {}
	for r: Array in rows:
		by[r[0]] = r[1]
	var d: Dictionary = raptor.dino
	assert_eq(by["peso"], "%s kg (%s–%s)" % [Js.to_fixed(d.mass.value, 1), Js.to_fixed(d.mass.min, 1), Js.to_fixed(d.mass.max, 1)], "la banda de la masa")
	assert_eq(by["peso"], "19.7 kg (14.1–24.6)")
	assert_eq(by["garra"], "92.7 mm (76.2–95.7)", "el estuche con su banda (Hedrick 2019; Manning 2006)")
	assert_eq(by["hueso fósil"], "64.8 mm", "el hueso medido (Norell & Makovicky 1999)")
	assert_eq(by["punta"], "R 138 µm · α 15° · sin medir", "la punta, pregunta abierta (dino.sickle.tipRadiusUm.open)")
	assert_true(d.sickle.tipRadiusUm.open, "en los datos, abierta")
	assert_eq(by["agarre de un pie"], "~382 N (193–1130)")
	assert_eq(by["golpe"], "~%s J (cae con los dos pies)" % Js.to_fixed(tool.strikeJ, 0))
	var line := DinoLab.sources_line(raptor)
	assert_true(line.begins_with("Reconstrucción (estimación") and line.contains("pregunta abierta") and line.contains("Norell 1999"), line)
	# afilada (reforjada en diamante), la punta de la ficha es la afilada
	var p := { "claw": raptor, "inlay": I("diamante"), "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "sharpness": 0.5 }
	var sharp := Physics.resolve_tool(p)
	var srows := DinoLab.spec_rows(raptor, "diamante", "10000 HV", sharp)
	assert_eq(srows[2][1], "R %s · α 15° · afilada" % DinoLab.fmt_tip_um(sharp.tipRadiusUm))
	assert_eq(DinoLab.fmt_tip_um(sharp.tipRadiusUm), "2.35 µm")


func test_la_fuerza_maxima_es_el_agarre_de_un_pie() -> void:
	var hint := Lab.max_force_hint(K("velociraptor"))
	assert_eq(hint.force, Velociraptor.FORCES.grip.value, "el agarre de un pie (382 N)")
	assert_near(float(hint.force), Velociraptor.grip_n(Velociraptor.MASS.value), 1e-3, 0.0, "el escalado de los gavilanes")
	assert_eq(hint.label, "del velocirraptor")
	assert_true(String(hint.note).contains("la garra sola, ~10 N; la réplica, 483 N"), hint.note)
	assert_true(String(hint.note).contains("193–1130 N"), "con la banda del agarre")
	# el resto, como siempre
	assert_eq(Lab.max_force_hint(K("tigre")).label, "del tigre")


func test_la_patada_del_casuario_en_el_banco() -> void:
	# el golpe del catálogo 2.0 es la patada del coche en marcha: 4,84 m/s y los músculos de la pata (~88 J con la hembra
	# de 58 kg del coche en marcha, unidad 4i-B2)
	var cas := K("casuario")
	var tool := Physics.resolve_tool({ "claw": cas, "inlay": I("none"), "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0] })
	assert_eq(float(tool.strike.v), MovingCar.kick_leap_ms(), "la velocidad del salto (MovingCar.kick_leap_ms)")
	assert_eq(float(tool.strikeJ), float(ClawsV2.kick_strike(float(cas.mass)).energyJ.value), "½·m·v²")
	var skin := Physics.compute({ "claw": cas, "inlay": I("none"), "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "target": T("piel"),
		"type": Catalog.TYPES[1], "force": 500.0, "length": 25.0, "method": "puncion", "strike": true, "passes": 1.0 })
	assert_eq(skin.verdict, "PUNCIÓN HASTA EL HUESO", "con ~88 J la daga sigue topando con el húmero")
	# la puerta de roble: con su fuerza de ficha y ~88 J se queda dentro; con la banda alta (~340 J), la atraviesa
	var door := { "claw": cas, "inlay": I("none"), "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "target": T("puertamadera"),
		"type": Catalog.TYPES[1], "force": 500.0, "length": 25.0, "method": "puncion", "strike": true, "passes": 1.0 }
	var r := Physics.compute(door)
	assert_eq(r.verdict, "CLAVADA EN LA MADERA", "~88 J no atraviesan los 35 mm de roble")
	assert_eq(Js.to_fixed(float(r.depthUm) / 1000.0, 0), "31", "se queda a ~31 mm (Lab.FUNDAMENTOS_V2)")
	var hi := cas.duplicate(true)
	hi.strike = ClawsV2.kick_strike(float(cas.mass)).max
	door.claw = hi
	assert_eq(Physics.compute(door).verdict, "ATRAVIESA LA PUERTA", "con todo el trabajo de la pata (~340 J), sí")
	# el fundamento de la 2.0 dice esos números
	var text := ""
	for f: Array in Lab.FUNDAMENTOS_V2:
		if String(f[0]).begins_with("Patada del casuario"):
			text = f[1]
	var k := ClawsV2.kick_strike(float(cas.mass))
	for want: String in ["~%s J" % Js.to_fixed(k.energyJ.value, 0), "~%s J" % Js.to_fixed(k.energyJ.max, 0), "~31 mm",
			"%s mm" % Js.js_num_str(float(T("puertamadera").thickness))]:
		assert_true(text.contains(want), "el fundamento dice «%s»: %s" % [want, text])


# ── El estado del afilado ──

func test_el_estado_del_afilado() -> void:
	var lab := LabState.new()
	lab.set_claw(K("velociraptor"))
	assert_false(lab.sharpenable(), "sin reforjar no se afila")
	assert_eq(lab.sharpness_view(), {}, "sin deslizador")
	lab.set_inlay(I("diamante"))
	assert_true(lab.sharpenable(), "reforjada en diamante, sí")
	lab.set_sharpness(0.5)
	assert_eq(lab.sharpness, 0.5)
	assert_eq(lab.params().sharpness, 0.5, "params() lo lleva a compute()")
	assert_eq(lab.phase, "idle", "mover el deslizador resetea el banco")
	assert_near(float(lab.tool().tipRadiusUm), ClawSharpness.radius_at(Velociraptor.tip_radius_um(), 0.5), 1e-12, 0.0, "la herramienta, afilada")
	lab.set_sharpness(3.0)
	assert_eq(lab.sharpness, 1.0, "se acota a [0, 1]")
	lab.set_sharpness(0.5)
	# el ensayo lleva el afilado; el informe sin ensayar es el mismo campo
	lab.set_target(T("acero"))
	lab.set_force(381.5)
	lab.run()
	var p := lab.params()
	p.claw = lab.claw
	p.tear = lab.tear_mode
	assert_eq(oracle_diff(lab.res, Physics.compute(p)).size(), 0, "el banco no hace física propia")
	assert_eq(oracle_diff(lab.sharpness_report(), lab.res.sharpness).size(), 0, "el deslizador ve lo que dará el ensayo")
	lab.set_inlay(I("none"))
	assert_eq(lab.sharpness, 0.5, "se conserva al cambiar de material, como la fuerza")
	assert_false(lab.sharpenable())
	lab.set_model(Physics.MODEL_V1)
	lab.set_inlay(I("diamante"))
	assert_false(lab.sharpenable(), "en la 1.x no hay afilado")


func test_los_textos_del_deslizador() -> void:
	var lab := LabState.new()
	lab.set_claw(K("velociraptor"))
	lab.set_inlay(I("diamante"))
	lab.set_target(T("acero"))
	lab.set_force(381.5)
	lab.set_sharpness(0.0)
	var v0: Dictionary = lab.sharpness_view()
	assert_eq(v0.display, "R 138 µm", "sin afilar, la punta de la ficha")
	assert_eq(v0.pressure.level, 0.0)
	assert_eq(v0.lateral.level, 1.0)
	assert_true(String(v0.note).begins_with("Afilar la punta (ahora, la de la ficha: R 138 µm)"), v0.note)
	# las marcas: la punta de la ficha y las seis referencias medidas, de la más roma a la más fina
	var marks: Array = v0.marks
	assert_eq(marks.map(func(m: Dictionary) -> String: return m.id), ["ficha", "rockwell", "microaguja", "aguijon_abeja", "filo_grano_1000", "filo_diamante", "cuchilla"].filter(
		func(id: String) -> bool: return id != "rockwell"), "el Rockwell (200 µm) es más romo que la punta de 138 µm: no se alcanza afilando")
	var prev := -1.0
	for m: Dictionary in marks:
		assert_true(float(m.t) > prev, "%s: más a la derecha que la anterior" % m.id)
		prev = m.t
	assert_eq(float(marks[-1].t), 1.0, "la hoja de afeitar, al final")
	assert_eq(marks[-1].text, "hoja de afeitar · 40 nm")
	lab.set_sharpness(0.5)
	var v: Dictionary = lab.sharpness_view()
	var rep: Dictionary = lab.sharpness_report()
	assert_eq(v.display, "R %s" % DinoLab.fmt_tip_um(rep.tipRadiusUm))
	assert_eq(v.pressure.level, rep.sharpness, "la barra de la presión, en la escala del deslizador")
	assert_near(float(v.lateral.level), 1.0 - float(rep.sharpness), 1e-12, 0.0, "la de la carga lateral baja")
	assert_true(String(v.pressure.text).begins_with("×%s" % Js.to_fixed(rep.pressureGain, 1)), v.pressure.text)
	assert_eq(v.lateral.color, "coral", "el diamante afilado se mella con la fricción del acero")
	assert_true(String(v.lateral.text).contains(DinoLab.fmt_small_force(rep.chipN)) and String(v.lateral.text).contains("se mella"), v.lateral.text)
	assert_true(String(v.note).contains("R²") and String(v.note).contains("Pattrick"), v.note)
	assert_true(String(v.note).begins_with("Afilar la punta (de R 138 µm a R %s)" % DinoLab.fmt_tip_um(rep.tipRadiusUm)), v.note)
	# al punzar no hay carga lateral: aguanta
	lab.set_method("puncion")
	assert_eq(lab.sharpness_view().lateral.color, "mint")
	# un metal se dobla (dorado) y la hematites no tiene resistencia medida
	lab.set_method("rayado")
	lab.set_inlay(I("acero"))
	assert_eq(lab.sharpness_view().lateral.color, "gold", "el acero afilado se dobla")
	lab.set_inlay(I("hematites"))
	var vh: Dictionary = lab.sharpness_view()
	assert_eq([vh.lateral.level, vh.lateral.color], [0.0, "dimmer"], "sin datos, no se predice")
	# la fila del resultado, solo afilada
	lab.set_inlay(I("diamante"))
	lab.run()
	var row: Variant = DinoLab.sharpness_row(lab.res)
	assert_true(row is Array and String(row[2]).contains("se mella"), "fila del resultado: %s" % [row])
	# en la comparativa, la punta afilada se da por su radio (su área saldría «0.000 mm²»)
	assert_eq(DinoLab.tip_size(lab.res), "R %s" % DinoLab.fmt_tip_um(float(lab.res.sharpness.tipRadiusUm)))
	lab.set_sharpness(0.0)
	lab.run()
	assert_eq(DinoLab.sharpness_row(lab.res), null, "sin afilar, sin fila")
	assert_eq(DinoLab.tip_size(lab.res), "%s mm²" % Js.to_fixed(float(lab.res.area), 3), "sin afilar, el área de siempre")


func test_formatos() -> void:
	assert_eq([DinoLab.fmt_tip_um(138.2), DinoLab.fmt_tip_um(18.03), DinoLab.fmt_tip_um(2.351), DinoLab.fmt_tip_um(0.155), DinoLab.fmt_tip_um(0.04)],
		["138 µm", "18.0 µm", "2.35 µm", "155 nm", "40 nm"])
	assert_eq([DinoLab.fmt_small_force(44.57), DinoLab.fmt_small_force(0.0129), DinoLab.fmt_small_force(0.0023), DinoLab.fmt_small_force(3.7e-6),
		DinoLab.fmt_small_force(3.6e-10)], ["45 N", "13 mN", "2.3 mN", "3.7 µN", "0.36 nN"])


# ── El dibujo de la garra ──

func test_la_garra_se_dibuja_a_escala() -> void:
	var raptor := K("velociraptor")
	var g := ArtDino.sickle_geometry(raptor)
	var sk: Dictionary = raptor.dino.sickle
	# el lomo del estuche mide keratinMm; el del hueso, coreMm; la sombra, la banda alta
	assert_near(_back(g.outline), float(sk.keratinMm.value), 0.01, 0.0, "estuche: 92,7 mm por el lomo")
	assert_near(_back(g.bone), float(sk.coreMm.value), 0.01, 0.0, "hueso: 64,8 mm por el lomo")
	assert_near(_back(g.shadow), float(sk.keratinMm.max), 0.01, 0.0, "banda alta: 95,7 mm")
	assert_near(float(g.span) * 180.0 / PI, float(sk.arcDeg.value), 1e-9, 0.0, "arco de 160°")
	# el hueso va dentro del estuche: su semialto en la base es la mitad de los 18,7 mm medidos, más fino que el estuche
	assert_true(float(g.w0) > float(sk.coreHeightMm.value) / 2.0, "el estuche envuelve la base del hueso")
	# la raya de la banda baja está en la garra de siempre, más cerca de la base que la punta
	var low: Array = g.low
	assert_true((low[0] as Vector2).distance_to(g.tip) > 5.0, "la banda baja acaba antes que la punta")
	for o: Dictionary in [{ "uid": "t" }, { "uid": "t", "labels": true }, { "uid": "t", "inlay": I("diamante") },
			{ "uid": "t", "orient": "down", "bone": false }, { "uid": "t", "tipColor": "#FF6B7A" }]:
		var art := ArtDino.claw_icon_art(raptor, o)
		var svg := Svg.scene_to_svg(art, view(ICON))
		assert_true(svg.begins_with("<svg") and not svg.contains("NaN") and not svg.contains("Infinity"), "%s: SVG válido" % [o])
		var img := SvgTexture.rasterize_image(svg, 1.0)
		assert_true(img != null and img.get_used_rect().has_area(), "%s: ThorVG la pinta" % [o])
		assert_eq(Svg.scene_to_svg(ArtDino.claw_icon_art(raptor, o), view(ICON)), svg, "%s: determinista" % [o])
		var tip := Vector2(float(art.tip.x), float(art.tip.y))
		assert_true(ICON.grow(0.5).has_point(tip), "%s: la punta dentro del lienzo (%s)" % [o, tip])
	var up := ArtDino.claw_icon_art(raptor, { "uid": "t" })
	var down := ArtDino.claw_icon_art(raptor, { "uid": "t", "orient": "down" })
	assert_true(float(up.base.y) > float(up.tip.y), "en la ficha, la base abajo")
	assert_true(float(down.base.y) < float(down.tip.y), "colgando (el banco), la base arriba")
	var texts: Array = (ArtDino.claw_icon_art(raptor, { "uid": "t", "labels": true }).labels as Array).map(func(l: Dictionary) -> String: return l.text)
	assert_eq(texts, ["18.7 × 7.1", "?"], "la sección de la base y la punta sin medir")
	assert_eq(up.labels, [], "sin rótulos en las fichas pequeñas")


static func _back(outline: Array) -> float:
	# el lomo es la primera mitad del contorno (de la base a la punta)
	var n := outline.size() / 2
	var s := 0.0
	for i in range(1, n):
		s += (outline[i] as Vector2).distance_to(outline[i - 1])
	return s
