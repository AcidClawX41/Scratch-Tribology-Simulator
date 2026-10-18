## Unidad 4n en el banco de ensayo: ningún texto que se ve enseña rutas internas ni nombres de código. Se recorre una
## batería de ensayos con el modelo 2.0 (todas las herramientas del catálogo, uñas, garras, colmillos, aguijones y los dos
## velocirraptores, contra todos los materiales, rayando, punzando y golpeando; las zonas del cuerpo; garras reforjadas y
## afiladas; el ángulo de ataque) y se juntan los textos que pinta la interfaz: veredicto, subtítulo, métricas del
## resultado, informe de daños, ficha de la herramienta, fuerza máxima, afilado, comparativa, zonas y capas, rótulos de las
## lupas y de los cortes, fundamentos y catálogo. Modelo: tests/lab/test_moving_car_textos.gd de la 4j.
extends "res://tests/case.gd"

const LabState = preload("res://core/lab/lab_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Lab = preload("res://core/lab/lab.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const Zones = preload("res://core/lab/zones.gd")
const Attack = preload("res://core/lab/attack.gd")
const Art = preload("res://core/lab/art.gd")
const ArtZones = preload("res://core/lab/art_zones.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const Js = preload("res://core/shared/js.gd")
const BenchTexts = preload("res://core/lab/bench_texts.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Bending = preload("res://core/lab/bending.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")
const ArtDino = preload("res://core/lab/art_dino.gd")
const ResultCard = preload("res://app/lab/result_card.gd")
const CompareCard = preload("res://app/lab/compare_card.gd")
const LabArt = preload("res://app/lab/lab_art.gd")

## Lo que no puede aparecer en un texto visible: rutas, archivos, módulos y constantes del código, apartados de documentos
## internos y nombres de unidades del equipo (las listas de la 4j, más los módulos del banco).
const BANNED := ["docs/", ".gd", "MovingCar", "Physics.", "§", "Data.", "ClawsV2", "Glazing", "res://", "FISICA", "Contact.",
	"ClawFracture", "ClawSharpness", "StingLab", "DinoLab", "Zones.", "Catalog."]
const BANNED_RE := [
	"\\bunidad \\d+[a-z]?\\b",  # unidad 1f, unidad 4d…
	"\\b[A-Z]{2,}_[A-Z0-9_]+\\b",  # IMPACT_ZONES, BIRD_AERO…
	"\\b[a-z]{2,}_[a-z]{2,}\\w*",  # run_kmh, clearance_mm…
	"\\b[A-Z][A-Za-z0-9]*\\.[a-z_]\\w*",  # Dent.strike, Velociraptor.grip_n…
	"\\b[a-z]+[A-Z][a-z]+\\w*",  # limbStiffness, perClaw…
]
## Nombres propios que parecen código y no lo son: el conjunto de datos de un paquete de R publicado (MASSTIMATE) y tres
## revistas.
const ALLOWED := ["dino_comparisons", "eLife", "arXiv", "iScience"]

var _res: Array[RegEx] = []


## Lo que falla de un texto: [lo que no puede aparecer, el trozo donde aparece].
func offenders(text: String) -> Array:
	if _res.is_empty():
		for p: String in BANNED_RE:
			_res.append(RegEx.create_from_string(p))
	var out: Array = []
	for b: String in BANNED:
		var at := text.find(b)
		if at >= 0:
			out.append([b, text.substr(maxi(at - 60, 0), 120)])
	for r: RegEx in _res:
		for m: RegExMatch in r.search_all(text):
			if not ALLOWED.has(m.get_string()):
				out.append([m.get_string(), text.substr(maxi(m.get_start() - 60, 0), 120)])
	return out


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


## Un banco con la herramienta (id de garra, o null y la uña geom/base), el material y el ensayo de cfg.
static func bench(cfg: Dictionary) -> LabState:
	var lab := LabState.new()
	if cfg.has("claw"):
		lab.set_claw(C(String(cfg.claw)))
	else:
		lab.set_claw(null)
		lab.set_geom(Catalog.find_by_id(Catalog.GEOMS, String(cfg.get("geom", "almendra"))))
		lab.set_base(Catalog.find_by_id(Catalog.BASES, String(cfg.get("base", "natural"))))
	lab.set_inlay(I(String(cfg.get("inlay", "none"))))
	lab.set_target(T(String(cfg.target)))
	if cfg.has("zone"):
		lab.set_zone(String(cfg.zone))
	lab.set_method(String(cfg.get("method", "rayado")))
	lab.set_strike(bool(cfg.get("strike", false)))
	if cfg.get("max", true):
		lab.set_force(float(lab.max_f().force))
	if cfg.has("force"):
		lab.set_force(float(cfg.force))
	if cfg.has("attack"):
		lab.set_attack_deg(float(cfg.attack))
	if cfg.has("sharp"):
		lab.set_sharpness(float(cfg.sharp))
	if cfg.get("tear", false):
		lab.set_tear_mode(true)
	return lab


## Los textos del ensayo que se ven: el resultado (veredicto, subtítulo, qué cede, capa, métricas, informe de daños) y,
## con full, los rótulos de la lupa y del corte (los dibujos son caros: solo en parte de la batería).
static func result_texts(lab: LabState, full: bool) -> Array:
	var r: Dictionary = lab.res
	var out: Array = [r.verdict, r.vsub, r.get("cede", "")]
	if r.get("layer") is String:
		out.append(r.layer)
	for row: Array in ResultCard.metric_rows(r, lab.length):
		out.append_array([row[0], row[1], row[2]])
	for row: Array in Lab.damage_report(r, lab.target, lab.length):
		out.append_array(row)
	out.append(StingLab.moral(r, lab.target))
	for row: Array in BenchTexts.pressure_rows(r):
		out.append_array([row[0], row[1], row[2]])
	out.append(BenchTexts.compare_pressure(r))
	var fic: Dictionary = BenchTexts.fiction(lab.claw, lab.inlay)
	if not fic.is_empty():
		out.append_array([fic.tag, fic.note])
	var rows: Array = BenchTexts.sources(r, { "claw": lab.claw, "inlay": lab.inlay, "target": lab.target })
	for row: Dictionary in rows:
		out.append_array([row.label, row.value, row.source, String(BenchTexts.QUALITY_TEXT.get(row.quality, ""))])
	out.append(BenchTexts.sources_summary(rows))
	if r.get("sting") is Dictionary:
		out.append(CompareCard.sting_meta(r))
	else:
		out.append(DinoLab.tip_size(r))
	if full:
		var lupa: Dictionary = LabArt.mat_lupa(lab.target, r)
		out.append(String(lupa.get("text", "")))
		for l: Dictionary in _section_labels(lab, r):
			out.append(String(l.text))
	return out


## Los rótulos del corte del resultado (los de la tarjeta: piel por zonas, aguijón, coche, puerta o perfil).
static func _section_labels(lab: LabState, r: Dictionary) -> Array:
	var target: Dictionary = lab.target
	var sc: Variant = StingLab.claw_of(r)
	if Js.truthy(r.get("skin")) and sc != null:
		var s: Dictionary = r.sting
		var inlay: Dictionary = I(String(s.material)) if s.reforged else Catalog.INLAYS[0]
		return LabArt.sting_section(r, sc, inlay).get("labels", [])
	if Js.truthy(r.get("skin")):
		return Art.skin_section_art(r, { "uid": "sks" }).get("labels", [])
	if Js.truthy(r.get("paint")):
		return Art.car_section_art(r, target, { "uid": "cars" }).get("labels", [])
	if Js.truthy(r.get("woodDoor")):
		return LabArt.door_section(r.depthUm, r.vcol, target.layers.film.t, target.thickness).get("labels", [])
	return LabArt.cross_section(r, target).get("labels", [])


## Los textos de la herramienta elegida: la ficha (título, material, dureza y filas), la línea de las fuentes, la
## descripción, la fuerza máxima y el afilado.
static func tool_texts(lab: LabState) -> Array:
	var out: Array = []
	var tool: Dictionary = lab.tool()
	var mf: Dictionary = lab.max_f()
	out.append_array([mf.label, mf.note])
	var claw: Variant = lab.claw
	if claw != null:
		var spec := Lab.claw_spec(claw, lab.inlay, tool)
		out.append_array([spec.title, spec.material, spec.hardness, claw.desc])
		var rows: Array = []
		if Insects.is_stinger(claw):
			rows = StingLab.spec_rows(claw, lab.inlay, tool)
			out.append(StingLab.short_sources(String(claw.get("source", ""))))
		elif DinoLab.is_dino(claw):
			rows = DinoLab.spec_rows(claw, spec.material, spec.hardness, tool)
			out.append(DinoLab.sources_line(claw))
		for row: Array in rows:
			out.append_array(row)
	var sv: Dictionary = lab.sharpness_view()
	if not sv.is_empty():
		out.append_array([sv.display, sv.spoken, sv.pressure.title, sv.pressure.text, sv.lateral.title, sv.lateral.text, sv.note])
		for m: Dictionary in sv.marks:
			out.append(String(m.text))
	return out


## Los textos fijos del banco que salen del core: el catálogo (descripciones, fichas de los materiales y sus subtítulos,
## nombres), las zonas del cuerpo con sus capas, el ángulo de ataque por defecto y los fundamentos de la 2.0.
static func fixed_texts() -> Array:
	var out: Array = []
	for c: Dictionary in Catalog.CLAWS:
		out.append_array([c.name, c.desc, Catalog.claw_title(c)])
	for g: String in Catalog.CLAW_GROUPS:
		out.append(g)
	for t: Dictionary in Catalog.TARGETS:
		out.append_array([t.name, t.fact, Lab.target_sub(t)])
	for b: Dictionary in Catalog.BASES:
		out.append(String(b.get("desc", "")))
	for z: Dictionary in Zones.ZONES:
		out.append_array([z.name, z.short, z.site, z.fact])
		for l: Dictionary in Zones.section_layers(String(z.id)):
			out.append_array([l.name, String(l.get("note", ""))])
		var bone: Variant = Zones.bone(String(z.id))
		if bone != null:
			out.append(String(bone.note))
	# la hoja «Fundamentos», su nota y el pie del banco con cada física (4n)
	for f: Array in Lab.fundamentos():
		out.append_array(f)
	out.append_array([Lab.FUNDAMENTOS_NOTE_V2, Lab.model_note("1.x"), Lab.model_note("2.0")])
	out.append(BenchTexts.COMPARE_PRESSURE_NOTE)
	# de dónde salen la velocidad y la masa del golpe (la nota del golpe de los parámetros)
	out.append(BenchTexts.strike_origin(null))
	for c: Dictionary in Catalog.CLAWS:
		out.append(BenchTexts.strike_origin(c))
	# las fuentes de los datos de la 2.0 que puede enseñar el banco («Fuentes y estimaciones», fichas y ayudas)
	for id: String in ClawsV2.OVERRIDES:
		for k: String in ClawsV2.OVERRIDES[id]:
			out.append(String(ClawsV2.OVERRIDES[id][k].get("source", "")))
	out.append(String(ClawsV2.KERATIN_SOURCE.source))
	for ref: Dictionary in ClawSharpness.REFERENCES:
		out.append_array([ref.name, ref.source])
	out.append_array([ClawSharpness.SRC_TABOR, ClawSharpness.SRC_JOHNSON, ClawSharpness.SRC_PATTRICK])
	for id: String in ClawMass.DENSITY:
		out.append(String(ClawMass.DENSITY[id].source))
	for id: String in ClawFracture.BRITTLE:
		out.append(String(ClawFracture.BRITTLE[id].source))
	for t: Dictionary in [Fracture.BRITTLE, Fracture.TOOL_STRENGTH, Bending.NAILS, Attack.DEFAULTS]:
		for id: Variant in t:
			out.append(String(t[id].get("source", "")))
	for g: Dictionary in [Glazing.SIDE_WINDOW, Glazing.WINDSCREEN]:
		out.append_array([g.source, g.frac.source])
	out.append(String(FangEnamel.ENAMEL.source))
	for z: Dictionary in Zones.ZONES:
		for l: Dictionary in Zones.section_layers(String(z.id)):
			out.append(String(l.get("source", "")))
	for c: Dictionary in [Velociraptor.ENTRY, VelociraptorFilm.ENTRY]:
		var d: Dictionary = c.dino
		out.append_array([c.source, d.mass.source, d.sickle.tipRadiusUm.source, d.locomotion.leapMs.source])
		for k: String in d.forces:
			out.append(String(d.forces[k].source))
	for k: String in VelociraptorFilm.FICTION:
		out.append(String(VelociraptorFilm.FICTION[k].source))
	out.append_array([VelociraptorFilm.SRC_REAL_CLAW, BenchTexts.SRC_DENT, BenchTexts.SRC_OLIVER_PHARR])
	return out


## Ensayos: cada herramienta (garras, colmillos, aguijones, velocirraptores y las seis formas de uña) contra cada material,
## rayando, punzando y golpeando; las cinco zonas del cuerpo; garras reforjadas y afiladas; el ángulo de ataque.
static func battery() -> Array:
	var out: Array = []
	var tools: Array = []
	for c: Dictionary in Catalog.CLAWS:
		tools.append({ "claw": c.id })
	for g: Dictionary in Catalog.GEOMS:
		tools.append({ "geom": g.id, "base": "natural" })
	var k := 0
	for t: Dictionary in tools:
		for tg: Dictionary in Catalog.TARGETS:
			for m: Array in [["rayado", false], ["puncion", false], ["puncion", true]]:
				var cfg: Dictionary = t.duplicate()
				cfg.merge({ "target": tg.id, "method": m[0], "strike": m[1], "full": k % 7 == 0 })
				out.append(cfg)
				k += 1
	for z: Dictionary in Zones.ZONES:
		for id: String in ["tigre", "vibora", "gabon", "casuario", "velociraptor", "velociraptor_pelicula", "abeja", "pajaro"]:
			for m: Array in [["rayado", false], ["puncion", false], ["puncion", true]]:
				out.append({ "claw": id, "target": "piel", "zone": z.id, "method": m[0], "strike": m[1], "full": true })
		out.append({ "geom": "stiletto", "base": "natural", "target": "piel", "zone": z.id, "force": 30.0, "full": true })
	for id: String in ["tigre", "oso", "vibora", "casuario", "velociraptor", "velociraptor_pelicula"]:
		for inl: String in ["acero", "tungsteno", "zafiro", "cuarzo", "diamante", "hematites", "vidrio"]:
			for tg: String in ["acero", "coche", "vidrio", "piel", "ventanilla"]:
				out.append({ "claw": id, "inlay": inl, "target": tg, "sharp": 0.6, "full": tg != "piel" })
				out.append({ "claw": id, "inlay": inl, "target": tg, "method": "puncion", "strike": true, "sharp": 1.0 })
	for b: Dictionary in Catalog.BASES:
		for tg: String in ["vidrio", "coche", "piel", "madera", "parabrisas"]:
			out.append({ "geom": "stiletto", "base": b.id, "target": tg, "force": 30.0, "attack": 20.0, "full": true })
			out.append({ "geom": "cuadrada", "base": b.id, "target": tg, "force": 30.0, "attack": 150.0 })
	out.append({ "claw": "tigre", "target": "coche", "tear": true, "full": true })
	out.append({ "claw": "oso", "target": "piel", "tear": true, "zone": "palma", "full": true })
	out.append({ "claw": "abeja", "inlay": "acero", "target": "madera", "force": 1.0, "full": true })
	return out


func test_ningun_texto_visible_del_banco_tiene_rutas_ni_codigo() -> void:
	var bad := {}
	var count := 0
	for t: Variant in fixed_texts():
		count += 1
		for o: Array in offenders(String(t)):
			bad["%s ⟶ %s" % o] = true
	var seen_tools := {}
	var trials := 0
	var unsourced := {}  # filas de «Fuentes y estimaciones» sin fuente o sin calidad conocida
	for cfg: Dictionary in battery():
		var lab := bench(cfg)
		lab.run()
		trials += 1
		for row: Dictionary in lab.trial_sources():
			if String(row.source) == "" or not BenchTexts.QUALITY_TEXT.has(row.quality):
				unsourced["%s (calidad «%s»)" % [row.label, row.quality]] = true
		var texts := result_texts(lab, bool(cfg.get("full", false)))
		var tk := "%s|%s|%s|%s" % [cfg.get("claw", cfg.get("geom", "")), cfg.get("base", ""), cfg.get("inlay", "none"), cfg.get("sharp", 0.0)]
		if not seen_tools.has(tk):
			seen_tools[tk] = true
			texts.append_array(tool_texts(lab))
		for t: Variant in texts:
			count += 1
			for o: Array in offenders(String(t)):
				bad["%s ⟶ %s" % o] = true
		lab.dispose()
	assert_true(trials > 2000, "ensayos: %d" % trials)
	assert_true(count > 50000, "textos revisados: %d" % count)
	assert_eq(bad.size(), 0, "sin rutas ni código en lo que se ve:\n%s" % "\n".join(PackedStringArray(bad.keys().slice(0, 30))))
	assert_eq(unsourced.keys(), [], "cada dato de «Fuentes y estimaciones», con su fuente y su calidad")


## El vigilante pilla lo que tiene que pillar (y deja pasar los nombres propios y las normas que lo parecen).
func test_el_vigilante_de_los_textos() -> void:
	for t: String in ["docs/fisica/velociraptor.md", "core/lab/claw_fracture.gd", "MovingCar.BODIES", "Contact.CONTACT.tabor",
			"§10.3", "ClawSharpness.REFERENCES", "la unidad 4d", "KICK_LEAP", "kick_leap_ms", "Zones.bone", "yieldOnset"]:
		assert_false(offenders(t).is_empty(), "«%s» no puede salir" % t)
	for t: String in ["Sustaita D, Hertel F (2010). J. Exp. Biol. 213:2617-2628. doi:10.1242/jeb.041731", "EN 572-1", "DIN EN ISO 18265",
			"Oliver & Pharr 1992", "IGM 100/986", "H ≈ 2,8·σ", "datos dinosbip y dino_comparisons", "JIS R 3212 / CEPE R43"]:
		assert_eq(offenders(t), [], "«%s» se puede leer" % t)


## Las cotas del dibujo de la garra del velocirraptor, con un decimal (la de película salía con quince: «24.20711974418832 ×
## 9.190938511326862»).
func test_cotas_de_la_garra_del_velocirraptor() -> void:
	for id: String in ["velociraptor", "velociraptor_pelicula"]:
		var claw: Dictionary = C(id)
		var texts: Array = (ArtDino.claw_icon_art(claw, { "uid": "t", "labels": true }).labels as Array).map(
			func(l: Dictionary) -> String: return l.text)
		var sk: Dictionary = claw.dino.sickle
		assert_eq(texts, ["%s × %s" % [Js.to_fixed(float(sk.coreHeightMm.value), 1), Js.to_fixed(float(sk.coreWidthMm.value), 1)], "?"], id)
	assert_eq((ArtDino.claw_icon_art(C("velociraptor_pelicula"), { "uid": "t", "labels": true }).labels as Array)[0].text, "24.2 × 9.2")


func test_fundamentos_de_la_2_0() -> void:
	var all: Array = Lab.fundamentos()
	assert_eq(all.size(), Lab.FUNDAMENTOS.size() + Lab.FUNDAMENTOS_V2.size() + Lab.FUNDAMENTOS_BIO_V2.size() + StingLab.FUNDAMENTOS.size(),
		"los de la 1.x, los de los materiales y la biología de la 2.0 y el de los aguijones")
	for i in Lab.FUNDAMENTOS.size():
		assert_eq(all[i][0], Lab.FUNDAMENTOS[i][0], "en el orden de la 1.x: %s" % Lab.FUNDAMENTOS[i][0])
		if all[i][0] == "Impacto":
			assert_eq(all[i], Lab.FUNDAMENTO_IMPACTO_V2, "«Impacto» vale para las dos físicas")
			assert_true(String(all[i][1]).contains("1.x") and String(all[i][1]).contains("2.0"))
		else:
			assert_eq(all[i], Lab.FUNDAMENTOS[i], "%s, el de la 1.x" % all[i][0])
	var titles: Array = all.map(func(f: Array) -> String: return f[0])
	for t: String in ["Zonas del cuerpo y hueso (2.0)", "Punción por capas (2.0)", "Ángulo de ataque (2.0)", "Esmalte de los colmillos (2.0)",
			"Velocirraptor (2.0)", "Aguijones (2.0)", "Patada del casuario (2.0)"]:
		assert_true(titles.has(t), "fundamento «%s»" % t)
	assert_eq(Lab.model_note("1.x"), Lab.MODEL_NOTE_V1, "el pie de la 1.x")
	assert_eq(Lab.model_note("2.0"), Lab.MODEL_NOTE_V2, "el pie de la 2.0")
	for txt: String in [Lab.FUNDAMENTOS_NOTE_V2, Lab.MODEL_NOTE_V1, Lab.MODEL_NOTE_V2]:
		assert_eq(offenders(txt), [], "sin rutas ni nombres de código: %s" % txt)
