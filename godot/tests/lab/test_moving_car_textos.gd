## Unidad 4j en el estado del coche en marcha (core/lab/moving_car_state.gd): los textos que se ven. Se comprueba:
##   - que ningún texto visible (veredictos, porqués, datos, fuentes, informe, lecturas, moraleja, banda, ayudas, afilado…)
##     enseña rutas internas ni nombres de código, en una batería de ensayos con todos los animales (los velocirraptores
##     de cine y de verdad incluidos), coches, zonas, materiales, miedo y viento de cola;
##   - el desgarro del plástico en las lecturas («Raja» en lugar de «Resbala», «el desgarro» en el contacto, por qué se le
##     sueltan las garras) y en el «¿sabías que…?» (los ~113 N por garra de R·t, con su fuente y su calidad);
##   - las componentes de la velocidad y el vuelo en las lecturas, y la dirección de llegada del dibujo, de kinematics;
##   - la banda del golpe en una frase y en las lecturas que la tienen, y el resumen de «Fuentes y estimaciones»;
##   - (unidad 4o) sin lecturas vacías («Contacto: 0 ms», «Resbala: 0.0 µm»), el parabrisas en la banda del golpe como en su
##     veredicto y en el informe con la energía de su dato (88.7 J), y el dato del hueco con lo que limita de verdad.
extends "res://tests/case.gd"

const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Js = preload("res://core/shared/js.gd")

## Lo que no puede aparecer en un texto visible: rutas, archivos, módulos y constantes del código, apartados de documentos
## internos y nombres de unidades del equipo.
const BANNED := ["docs/", ".gd", "MovingCar", "Physics.", "§", "Data.", "ClawsV2", "Glazing", "res://", "FISICA"]
const BANNED_RE := [
	"\\bunidad \\d+[a-z]?\\b",  # unidad 1f, unidad 4d…
	"\\b[A-Z]{2,}_[A-Z0-9_]+\\b",  # IMPACT_ZONES, BIRD_AERO…
	"\\b[a-z]{2,}_[a-z]{2,}\\w*",  # run_kmh, clearance_mm…
	"\\b[A-Z][A-Za-z0-9]*\\.[a-z_]\\w*",  # Dent.strike, Velociraptor.grip_n…
	"\\b[a-z]+[A-Z][a-z]+\\w*",  # limbStiffness, perClaw…
	"\\bDent\\b",
]
## Nombres propios que parecen código y no lo son: el conjunto de datos de un paquete de R publicado (MASSTIMATE) y dos
## revistas.
const ALLOWED := ["dino_comparisons", "eLife", "arXiv"]

var _res: Array[RegEx] = []


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func state(claw_id: String, car := "coche") -> RefCounted:
	var st: RefCounted = MCS.new(C(claw_id), T(car))
	st.threaded = false
	return st


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


## Todos los textos que enseña la tarjeta con el estado de ahora (y las ayudas emergentes que salen de los datos).
static func visible_texts(st: RefCounted) -> Array:
	var out: Array = []
	if not st.supported():
		return out
	if st.mode == MCS.MODE_HOLD and not st.verdict.is_empty():
		out.append_array([st.verdict.verdict, st.verdict.vsub, st.now_text(), st.now_band_text(), st.air_legend(), st.air_txt])
		var b: Dictionary = st.band()
		if not b.is_empty():
			out.append_array([b.text, b.central])
		for r: Dictionary in st.hold_readings():
			out.append_array([r.label, r.value, r.sub, r.source])
		for row: Array in st.hold_rows():
			out.append_array(row)
	if st.mode == MCS.MODE_IMPACT and Js.truthy(st.hit.get("ok")):
		out.append_array([st.hit.verdict, st.hit.vsub, st.hit.safety, st.impact_band_text()])
		for r: Dictionary in st.impact_readings():
			out.append_array([r.label, r.value, r.sub, r.source])
		for row: Array in st.hit.report:
			out.append_array(row)
		for t: Dictionary in st.energy_terms():
			out.append_array([t.name, t.short, t.source])
	out.append_array([st.why_text(), st.moral(), st.inlay_note(), st.sources_summary()])
	for f: Dictionary in st.facts():
		out.append_array([f.text, f.source])
	for s: Dictionary in st.sources():
		out.append_array([s.label, s.value, s.source])
	for l: Dictionary in st.layers_view():
		out.append(String(l.name))
	var sv: Dictionary = st.sharpness_view()
	if not sv.is_empty():
		out.append_array([sv.display, sv.spoken, sv.pressure.title, sv.pressure.text, sv.lateral.title, sv.lateral.text, sv.note])
		for m: Dictionary in sv.marks:
			out.append(String(m.text))
	for v: Dictionary in st.variants():
		out.append(String(v.name))
	var body: Variant = MC.body_of(st.claw)
	if body != null and body.has("run_kmh"):
		out.append(String(body.run_kmh.source))
	return out


## Las ayudas y los textos fijos de la tarjeta que salen del core.
static func fixed_texts() -> Array:
	var out: Array = [MCS.DEFENSE_TIP, MC.HOLD_NO_REASON, MC.SAFETY_NOTE]
	for i: Dictionary in Catalog.INLAYS:
		out.append(MCS.inlay_tip(String(i.id)))
	for e: Dictionary in MCS.EXPERIMENTS:
		out.append(MCS.experiment_tip(String(e.id)))
	for id: String in MC.ZONES:
		out.append(String(MC.ZONES[id].cp.source))
	for m: Dictionary in MC.MANEUVERS:
		out.append(String(m.source))
	for a: Dictionary in MCS.supported_animals():
		out.append(String(a.name))
	return out


## Ensayos: cada animal en cada zona del coche moderno (quieto encima, con su primera postura, y el golpe), la aleta de
## plástico, asustado, con viento de cola y las alas abiertas, y con garras reforjadas de varios materiales (afiladas).
static func battery() -> Array:
	var out: Array = []
	for id: String in MC.BODIES:
		var c := C(id)
		if MC.supports_hold(c):
			for z: String in MC.zones_for(c):
				out.append({ "claw": id, "car": "coche", "mode": "hold", "zone": z })
			out.append({ "claw": id, "car": "cocheplastico", "mode": "hold", "zone": "aleta", "defense": true })
			out.append({ "claw": id, "car": "coche", "mode": "hold", "zone": "techo", "posture": MC.postures_of(c)[-1], "wind": -60.0, "v": 10.0 })
		for z: String in MC.impact_zones_for(c):
			out.append({ "claw": id, "car": "coche", "mode": "impact", "zone": z })
		if MC.impact_zones_for(c).has("aleta"):
			out.append({ "claw": id, "car": "cocheplastico", "mode": "impact", "zone": "aleta" })
			out.append({ "claw": id, "car": "cocheplastico", "mode": "impact", "zone": "aleta", "defense": true, "v": 90.0 })
		var z0: String = MC.impact_zones_for(c)[0]
		for inl: String in ["zafiro", "hematites", "vidrio", "oro"]:
			out.append({ "claw": id, "car": "coche", "mode": "impact", "zone": z0, "inlay": inl, "sharp": 0.5 })
		if MC.supports_hold(c):
			out.append({ "claw": id, "car": "coche", "mode": "hold", "zone": "techo", "inlay": "tungsteno", "sharp": 0.5, "embedded": true })
	return out


static func apply(st: RefCounted, cfg: Dictionary) -> void:
	st.set_inlay(String(cfg.get("inlay", "none")))
	if cfg.has("sharp"):
		st.set_sharpness(float(cfg.sharp))
	st.set_defense(bool(cfg.get("defense", false)))
	st.set_mode(String(cfg.mode))
	if cfg.mode == "hold":
		st.set_zone(String(cfg.zone))
		if cfg.has("posture"):
			st.set_posture(String(cfg.posture))
		st.set_wind(float(cfg.get("wind", 0.0)), 0.0)
		st.set_embedded(bool(cfg.get("embedded", false)))
		st.set_speed(float(cfg.get("v", 90.0)))
	else:
		st.set_impact_zone(String(cfg.zone))
		st.set_speed(float(cfg.get("v", 50.0)))
		st.set_impact("animal_kmh", 40.0)
		st.set_impact("angle_deg", 90.0)
		st.set_impact("drop_m", 0.5)


func test_ningun_texto_visible_tiene_rutas_ni_codigo() -> void:
	var bad := {}
	var count := 0
	for t: String in fixed_texts():
		count += 1
		for o: Array in offenders(t):
			bad["%s ⟶ %s" % o] = true
	var films := 0
	for cfg: Dictionary in battery():
		var st := state(String(cfg.claw), String(cfg.car))
		apply(st, cfg)
		st.finish()
		if st.film():
			films += 1
		for t: Variant in visible_texts(st):
			count += 1
			for o: Array in offenders(String(t)):
				bad["%s ⟶ %s" % o] = true
		st.dispose()
	assert_true(count > 5000, "textos revisados: %d" % count)
	assert_true(films >= 5, "con el velocirraptor de cine: %d ensayos" % films)
	assert_eq(bad.size(), 0, "sin rutas ni código en lo que se ve:\n%s" % "\n".join(PackedStringArray(bad.keys().slice(0, 25))))


## El vigilante pilla lo que tiene que pillar (y deja pasar los nombres propios que lo parecen).
func test_el_vigilante_de_los_textos() -> void:
	for t: String in ["docs/fisica/coche-en-marcha.md", "core/lab/dent.gd", "MovingCar.BODIES", "Physics.compute", "§2.8", "Data.INLAYS",
			"ClawsV2", "Glazing.WINDSCREEN", "la unidad 1f", "BIRD_AERO", "run_kmh", "Dent.strike", "limbStiffness", "Velociraptor.grip_n"]:
		assert_false(offenders(t).is_empty(), "«%s» no puede salir" % t)
	for t: String in ["Sustaita D, Hertel F (2010). J. Exp. Biol. 213:2617-2628. doi:10.1242/jeb.041731", "eLife 8:e46415",
			"arXiv:2408.11969", "datos dinosbip y dino_comparisons", "Dentro del coche", "EN 572-1", "JIS R 3212 / CEPE R43",
			"½·μ_red·v_n² con μ_red = 5.0 kg", "Área frontal del cuerpo (S_b)", "NORYL GTX™ resin GTX964", "ISO 179/1eA"]:
		assert_eq(offenders(t), [], "«%s» se puede leer" % t)


## El desgarro de la 4g en las lecturas: con las garras trabadas en la aleta de plástico, «Raja» en lugar de «Resbala»,
## con el largo y la banda; el contacto dura la abolladura (o el golpe) y el desgarro; si no aguanta lo que pide rajarla,
## «Raja: no» con el porqué.
func test_el_desgarro_en_las_lecturas() -> void:
	var tiger := state("tigre", "cocheplastico")
	apply(tiger, { "mode": "impact", "zone": "aleta" })
	tiger.finish()
	var tear: Dictionary = tiger.hit.tear
	assert_true(tear.holds and float(tear.lengthMm) > 0.0, "el tigre raja la aleta")
	var rd := _by_id(tiger.impact_readings())
	assert_false(rd.has("resbala"), "no resbala: raja")
	assert_eq(rd.raja.label, "Raja", "«Raja»")
	assert_eq(rd.raja.value, MC.fmt_long(float(tear.lengthMm) * 1000.0), "con el largo del desgarro")
	assert_eq([rd.raja.quality, rd.raja.source], [String(tear.quality), String(tear.source)], "con su calidad y su fuente")
	assert_true(String(rd.contacto.sub).ends_with("el desgarro"), "el contacto: %s" % rd.contacto.sub)
	assert_false(String(rd.contacto.sub).contains("resbalón"), "no el resbalón")
	# el águila no aguanta lo que pide rajarla: se le sueltan las garras
	var eagle := state("aguila", "cocheplastico")
	apply(eagle, { "mode": "impact", "zone": "aleta", "v": 60.0 })
	eagle.finish()
	var t2: Dictionary = eagle.hit.tear
	assert_false(t2.holds, "el águila no la raja")
	var r2 := _by_id(eagle.impact_readings())
	assert_true(r2.has("resbala") and r2.has("raja"), "resbala, y la ficha de «Raja» dice por qué no")
	assert_eq(r2.raja.value, "no", "no la raja")
	assert_true(String(r2.raja.sub).begins_with("rajarla pide ~%s y solo aguanta ~%s" % [MCS.fmt_n(float(t2.forceN)), MCS.fmt_n(float(t2.anchorN.value))]),
		"rajarla pide ~… y solo aguanta ~…: %s" % r2.raja.sub)
	# unidad 4o: de lado, sin abolladura (el plástico perforado no se abolla), sin resbalón y sin desgarro, el modelo no tiene
	# un tiempo de contacto que dar: la lectura no sale (antes, «0 ms»); y no resbala «nada» (antes, «0.0 µm»)
	assert_eq(float(eagle.hit.contactS), 0.0, "sin tiempo de contacto")
	assert_false(r2.has("contacto"), "sin «Contacto: 0 ms»")
	assert_eq(r2.resbala.value, "nada", "no resbala: %s" % r2.resbala.value)
	assert_true(String(r2.resbala.sub).begins_with("golpea de lado y sale a "), "de lado: %s" % r2.resbala.sub)
	assert_true(String(r2.resbala.sub).contains("banda: hasta"), "con la banda (con todo en contra, raja): %s" % r2.resbala.sub)
	# en la chapa no hay desgarro
	var steel := state("tigre")
	apply(steel, { "mode": "impact", "zone": "puerta" })
	steel.finish()
	var r3 := _by_id(steel.impact_readings())
	assert_true(r3.has("resbala") and not r3.has("raja"), "en la chapa, resbala")
	assert_eq(String(r3.contacto.sub), "la abolladura y el resbalón", "con la abolladura")
	for st: RefCounted in [tiger, eagle, steel]:
		st.dispose()


## Unidad 4o: contra el parabrisas, la banda del golpe dice lo mismo que el veredicto (si la hoja se agrieta y si puede
## atravesarlo), no «no perfora» (las garras no perforan el vidrio); y el informe da la energía de la homologación con el
## decimal de su «¿sabías que…?» (88.7 J, no «89 J»).
func test_el_parabrisas_en_la_banda_y_el_informe() -> void:
	var risky := 0
	for cfg: Array in [["tigre", 50.0], ["aguila", 50.0], ["lechuza", 20.0]]:
		var st := state(cfg[0])
		apply(st, { "mode": "impact", "zone": "parabrisas", "v": cfg[1] })
		st.finish()
		assert_eq(st.impact_zone, "parabrisas", "%s: contra el parabrisas" % cfg[0])
		var sh: Dictionary = st.hit.windshield
		var want := "aguanta"
		if sh.cracked:
			want = "se agrieta y puede atravesarlo" if sh.penetrationRisk else "se agrieta"
		var band: String = st.impact_band_text()
		assert_true(band.contains("el parabrisas %s;" % want), "%s: la banda dice «%s»: %s" % [cfg[0], want, band])
		assert_false(band.contains("perfora"), "%s: no «no perfora»: %s" % [cfg[0], band])
		if sh.penetrationRisk:
			risky += 1
			var j := Js.to_fixed(float(sh.penetrationJ), 1)
			var row: Array = (st.hit.report as Array).filter(func(x: Array) -> bool: return x[0] == "Parabrisas")
			assert_true(row.size() == 1 and String(row[0][1]).contains("(y puede atravesarlo: más de %s J)" % j), "el informe: %s" % [row])
			var fact: Array = st.facts().filter(func(x: Dictionary) -> bool: return String(x.text).contains("homologación"))
			assert_true(fact.size() == 1 and String(fact[0].text).contains("un golpe de %s J;" % j), "el dato: %s" % [fact])
		st.dispose()
	assert_true(risky > 0, "el tigre puede atravesarlo")


## Unidad 4o: la lectura de la ventanilla que aguanta dice los trocitos que haría si estallara, no como si los hubiera hecho
## (los dos ensayos de un clic de la ventanilla: la queratina aguanta, el diamante la revienta).
func test_la_lectura_de_la_ventanilla_que_aguanta() -> void:
	var seen := {}
	for id: String in ["ventanilla_queratina", "ventanilla_diamante"]:
		var st: RefCounted = MCS.new()
		st.threaded = false
		st.load_experiment(id)
		st.finish()
		var sw: Dictionary = st.hit.sideWindow
		seen[Js.truthy(sw.shattered)] = true
		var sub := String(_by_id(st.impact_readings()).ventanilla.sub)
		assert_true(sub.contains("trocitos de ~"), "%s: con los trocitos: %s" % [id, sub])
		assert_eq(sub.contains("si estalla, trocitos de ~"), not Js.truthy(sw.shattered), "%s: %s" % [id, sub])
		# y su término de la energía: lo que se queda hasta estallar o, si aguanta, nada (lo devuelve)
		var et: Dictionary = st.energy_terms()[1]
		assert_eq(String(et.name), "Ventanilla (hasta estallar)" if Js.truthy(sw.shattered) else "Ventanilla (aguanta: lo devuelve)", id)
		if not Js.truthy(sw.shattered):
			assert_eq(float(et.j), 0.0, "%s: si aguanta, no se queda nada" % id)
		st.dispose()
	assert_eq(seen.size(), 2, "una aguanta y otra estalla")


## Unidad 4o: el «¿sabías que…?» del hueco detrás del panel habla de lo que el hueco limita de verdad: en la chapa, la
## abolladura; en la aleta de plástico perforada, que no se abolla (se hunde y recupera), solo la punta de las garras. Y en
## la energía del golpe, el término del panel de plástico no se llama «Chapa (abolladura)».
func test_el_dato_del_hueco_dice_lo_que_limita() -> void:
	var tiger := state("tigre", "cocheplastico")
	apply(tiger, { "mode": "impact", "zone": "aleta" })
	tiger.finish()
	assert_false(tiger.hit.dent != null and Js.truthy(tiger.hit.dent.applies), "el plástico perforado no se abolla")
	var pt: Dictionary = tiger.energy_terms()[1]
	assert_eq([pt.id, pt.name, pt.short, float(pt.j)], ["chapa", "Plástico (no se abolla)", "plástico", 0.0], "el término del panel")
	var f: Array = tiger.facts().filter(func(x: Dictionary) -> bool: return String(x.text).contains("de hueco"))
	assert_eq(f.size(), 1, "un dato del hueco")
	assert_false(String(f[0].text).contains("abolladura"), "sin abolladura: %s" % f[0].text)
	assert_true(String(f[0].text).contains(": la punta de unas garras que") and String(f[0].text).ends_with("atraviesan no puede entrar más."),
		"la punta: %s" % f[0].text)
	var steel := state("tigre")
	apply(steel, { "mode": "impact", "zone": "puerta" })
	steel.finish()
	var g: Array = steel.facts().filter(func(x: Dictionary) -> bool: return String(x.text).contains("de hueco"))
	assert_true(g.size() == 1 and String(g[0].text).ends_with(": la abolladura no puede ser más honda."), "la chapa: %s" % [g])
	assert_eq(String(steel.energy_terms()[1].name), "Chapa (abolladura)", "en la chapa, su abolladura")
	for st: RefCounted in [tiger, steel]:
		st.dispose()


## El «¿sabías que…?» del desgarro: cada garra pide R·t (45 kJ/m² × 2,5 mm ≈ 113 N), con la fuente y la calidad de la 4g.
func test_el_dato_del_desgarro() -> void:
	var tiger := state("tigre", "cocheplastico")
	apply(tiger, { "mode": "impact", "zone": "aleta" })
	tiger.finish()
	var tear: Dictionary = tiger.hit.tear
	var f: Array = tiger.facts().filter(func(x: Dictionary) -> bool: return String(x.text).contains("R·t"))
	assert_eq(f.size(), 1, "un dato del desgarro")
	var r: Dictionary = MC.PLASTIC_TEAR["plastico-carroceria"]
	var per := float(r.value) * float(tear.thicknessMm)
	assert_near(float(tear.perClawN), per, 1e-12, 1e-12, "R·t por garra")
	assert_true(String(f[0].text).contains("%s kJ/m² × 2.5 mm ≈ %s" % [MCS.num(float(r.value)), MCS.fmt_n(per)]), f[0].text)
	assert_eq([f[0].quality, f[0].source], [String(tear.quality), String(tear.source)], "con su calidad y su fuente")
	assert_true(String(f[0].source).contains("SABIC"), "la ficha del plástico")
	tiger.dispose()


## Las componentes de la velocidad y el vuelo, de MovingCar.kinematics; la dirección de llegada del dibujo, también.
func test_las_velocidades_y_el_vuelo() -> void:
	var st := state("tigre")
	apply(st, { "mode": "impact", "zone": "techo" })
	st.finish()
	var k: Dictionary = st.hit.kinematics
	var rd := _by_id(st.impact_readings())
	assert_eq(rd.componentes.value, "%s · %s · %s km/h" % [CarFormat.kmh_txt(absf(k.relKmh.x)), CarFormat.kmh_txt(absf(k.relKmh.y)),
		CarFormat.kmh_txt(absf(k.relKmh.z))], "las tres componentes")
	assert_eq(rd.componentes.sub, "hacia atrás · de lado · hacia abajo", "con palabras")
	assert_eq(rd.vuelo.value, CarFormat.fmt_s(float(k.flightS)), "el vuelo")
	assert_true(String(rd.vuelo.sub).contains("el coche avanza %s" % CarFormat.fmt_m(float(k.carFlightM), 1)), rd.vuelo.sub)
	assert_true(same(st.arrival(), k.arrival), "el dibujo llega por donde dice la cinemática")
	# en un costado no vuela; el velocirraptor, con su salto
	st.set_impact_zone("puerta")
	st.finish()
	assert_false(_by_id(st.impact_readings()).has("vuelo"), "contra la puerta no hay vuelo")
	st.dispose()
	var raptor := state("velociraptor_pelicula")
	apply(raptor, { "mode": "impact", "zone": "capo" })
	raptor.finish()
	var lp: Dictionary = raptor.hit.leap
	var rv := _by_id(raptor.impact_readings())
	assert_eq(rv.vuelo.value, CarFormat.fmt_s(float(lp.timeS)), "el tiempo de su salto")
	assert_true(String(rv.vuelo.sub).begins_with("salta desde la carretera"), rv.vuelo.sub)
	assert_true(float(raptor.arrival().z) < 0.0, "llega de bajada")
	raptor.dispose()
	# sin golpe, la dirección sale de los datos de ahora
	var cold := state("tigre")
	cold.threaded = true
	cold.set_mode("impact")
	cold.set_impact_zone("techo")
	assert_true(same(cold.arrival(), MC.kinematics(cold.impact_params()).arrival), "sin golpe todavía, la de los datos de ahora")
	cold.dispose()


## La banda del golpe: en una frase (como la del despegue) y en las lecturas que cambian con los datos.
func test_la_banda_del_golpe_en_palabras() -> void:
	var st := state("casuario")
	apply(st, { "mode": "impact", "zone": "puerta" })
	st.finish()
	var b: Dictionary = st.hit.band
	var txt: String = st.impact_band_text()
	assert_true(txt.begins_with("Banda de los datos, de todo a favor del coche a todo en contra: "), txt)
	assert_true(txt.contains("de %s a %s contra el panel" % [MC.fmt_energy(float(b.normalJ.min)), MC.fmt_energy(float(b.normalJ.max))]), txt)
	assert_true(txt.contains("no perfora") and txt.ends_with("."), txt)
	var rd := _by_id(st.impact_readings())
	assert_true(String(rd.normal.sub).contains("banda de %s a %s" % [MC.fmt_energy(float(b.normalJ.min)), MC.fmt_energy(float(b.normalJ.max))]),
		"la energía contra el panel, con su banda: %s" % rd.normal.sub)
	assert_true(String(rd.abolladura.sub).contains("banda de "), "y la abolladura: %s" % rd.abolladura.sub)
	assert_true(rd.has("marcas"), "y las marcas")
	# sin nada que mover (un tigre), la energía contra el panel no lleva banda
	var tiger := state("tigre")
	apply(tiger, { "mode": "impact", "zone": "puerta" })
	tiger.finish()
	assert_false(String(_by_id(tiger.impact_readings()).normal.sub).contains("banda"), "el tigre: sin banda de su masa ni de su velocidad")
	assert_true(tiger.sources().any(func(s: Dictionary) -> bool: return s.label == "Banda del golpe" and s.quality == "estimate"),
		"la banda, en «Fuentes y estimaciones»")
	for s: RefCounted in [st, tiger]:
		s.dispose()


## El resumen de «Fuentes y estimaciones» (la lista empieza plegada): cuántos datos y de qué calidad.
func test_el_resumen_de_las_fuentes() -> void:
	var st := state("velociraptor_pelicula")
	apply(st, { "mode": "impact", "zone": "capo" })
	st.finish()
	var rows: Array = st.sources()
	var sum: String = st.sources_summary(rows)
	assert_eq(sum, st.sources_summary(), "con las filas o sin ellas")
	assert_true(sum.begins_with("%d datos" % rows.size()), sum)
	var est := rows.filter(func(r: Dictionary) -> bool: return r.quality == "estimate").size()
	var fic := rows.filter(func(r: Dictionary) -> bool: return r.quality == "ficcion").size()
	assert_true(sum.contains("%d estimaciones" % est) and sum.contains("%d de ficción" % fic), sum)
	st.dispose()


## La fuente del hueco bajo el panel sale de la zona (IMPACT_ZONES.sources, de la 4g); una zona que no la trae (una nueva,
## como la ventanilla) no rompe nada: queda como estimación del modelo, en palabras.
func test_el_hueco_de_una_zona_sin_fuente() -> void:
	for id: String in MC.IMPACT_ZONES:
		var iz: Dictionary = MC.IMPACT_ZONES[id]
		var want: Variant = iz.get("sources", {}).get("clearance_mm")
		if want != null:
			assert_eq(MCS._clearance_source(iz), want, "%s: la de su zona" % id)
	var none: Dictionary = MCS._clearance_source({ "name": "Ventanilla", "normal": "lado" })
	assert_eq(String(none.quality), "estimate", "sin fuente, una estimación")
	assert_eq(offenders(String(none.source)), [], "y dicha en palabras: %s" % none.source)


static func _by_id(rows: Array) -> Dictionary:
	var out := {}
	for r: Dictionary in rows:
		out[r.id] = r
	return out
