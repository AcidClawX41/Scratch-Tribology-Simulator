## Unidad 4o en el coche en marcha (docs/fisica/coche-en-marcha.md §16): la hondura de las marcas de una garra que atraviesa
## el panel. Se comprueba:
##   - la invariante: la hondura de una marca nunca pasa del hueco bajo el panel más el espesor del panel, ni del largo de la
##     garra; si atraviesa el panel, es la del panel; y la punta de la garra (en las marcas, los desgarros y la punción) no
##     pasa del hueco ni de su largo, en todos los animales, coches, zonas, materiales y con miedo, en el golpe y quieto encima;
##   - el velocirraptor de cine contra el capó (el fallo de la Beta 2): marcas de lado a lado de 0,81 mm, la punta al fondo de
##     los 80 mm del hueco y los textos (el informe, la lectura y la banda) sin los 120 mm de su garra; la energía, la de antes;
##   - una garra que topa con el fondo antes de que su agujero tenga su ancho: agujero más estrecho y menos trabajo, el de la
##     chapa hasta ahí, y el balance de energía que sigue sumando;
##   - quieto encima: un desgarro que raja la chapa se dice «de lado a lado»;
##   - lo que no atraviesa no cambia: la punta es la marca;
##   - unidad 4p (§17): la punta y la abolladura comparten el hueco bajo el panel: juntas nunca pasan del panel más su hueco,
##     en el golpe central y en los dos extremos de la banda, y el balance de energía sigue sumando.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Contact = preload("res://core/shared/contact.gd")
const Data = preload("res://core/lab/data.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Physics = preload("res://core/lab/physics.gd")

const CARS := ["coche", "cocheclasico", "cochealu", "cocheplastico"]
const INLAYS := ["none", "zafiro", "acero"]


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## El largo de la garra (µm): el alcance del motor.
static func reach_um(id: String) -> float:
	return float(Physics.resolve_tool(MC._lab_params(C(id), MC._glass(), {})).reach) * 1000.0


## Lo que falla de unas marcas (o de un desgarro): [] si cumplen. panel y room, del panel (µm); reach, de la garra (µm).
static func marks_offenses(m: Dictionary, panel: float, room: float, reach: float) -> Array:
	var out: Array = []
	var d := float(m.depthUm)
	var tip := float(m.get("tipUm", d))
	if d > room + 1e-6 or d > reach + 1e-6:
		out.append("hondura de %s µm (hueco hasta %s, garra %s)" % [d, room, reach])
	if Js_truthy(m.get("through")) and absf(d - panel) > 1e-6:
		out.append("atraviesa con %s µm, no con los %s del panel" % [d, panel])
	if not Js_truthy(m.get("through")) and absf(tip - d) > 1e-9:
		out.append("sin atravesar, la punta (%s) no es la marca (%s)" % [tip, d])
	if tip > minf(room, reach) + 1e-6:
		out.append("la punta a %s µm (como mucho %s)" % [tip, minf(room, reach)])
	return out


static func Js_truthy(v: Variant) -> bool:
	return v != null and v != false


func test_la_hondura_nunca_pasa_del_hueco_ni_de_la_garra() -> void:
	var bad: Array = []
	var n := 0
	var through := 0
	var capped := 0
	for id: String in MC.BODIES:
		var reach := reach_um(id)
		for car: String in CARS:
			var target := T(car)
			var panel := MC.panel_um(target)
			assert_near(panel, float(target.thickness) * 1000.0, 1e-12, 0.0, "%s: el panel es la pintura y la carrocería" % car)
			for z: String in MC.impact_zones_for(C(id)):
				var iz: Dictionary = MC.IMPACT_ZONES[z]
				if iz.glass:
					continue
				var room := panel + float(iz.clearance_mm) * 1000.0
				assert_near(MC.room_um(target, float(iz.clearance_mm)), room, 1e-12, 0.0, "%s en %s: el panel y su hueco" % [car, z])
				for inl: String in INLAYS:
					for dfn: bool in [false, true]:
						var r := MC.impact({ "claw": C(id), "target": target, "zone": z, "v_kmh": 50.0, "animal_kmh": 40.0,
							"angle_deg": 90.0, "drop_m": 0.5, "inlay": inl, "defense": dfn })
						if not r.ok:
							continue
						n += 1
						var tag := "golpe de %s contra %s (%s) con %s%s" % [id, z, car, inl, ", asustado" if dfn else ""]
						if int(r.marks.count) > 0:
							for o: String in marks_offenses(r.marks, panel, room, reach):
								bad.append("%s, marcas: %s" % [tag, o])
							if r.marks.through:
								through += 1
						var pn: Variant = r.puncture
						if pn != null:
							if float(pn.depthUm) > minf(room, reach) + 1e-6:
								bad.append("%s, punción: la punta a %s µm" % [tag, pn.depthUm])
							# unidad 4p: la punta y la abolladura comparten el hueco: juntas no pasan del panel más su hueco
							var dn: Variant = r.dent
							var dent_mm := float(dn.depthMm) if dn != null and dn.applies else 0.0
							if pn.through and float(pn.depthUm) + dent_mm * 1000.0 > room + 1e-2:
								bad.append("%s, punción: la punta (%s µm) y la abolladura (%s mm) no caben en %s µm" % [tag, pn.depthUm, dent_mm, room])
							if pn.bottoms:
								capped += 1
								assert_near(float(pn.depthUm), MC.shared_room_um(target, float(iz.clearance_mm), dent_mm), 0.0, 1e-2,
									"%s: la punta, al fondo del hueco que le deja la abolladura" % tag)
		if not MC.supports_hold(C(id)):
			continue
		for car: String in CARS:
			var target := T(car)
			var panel := MC.panel_um(target)
			for z: String in MC.zones_for(C(id)):
				if MC.ZONES[z].surface == "vidrio":
					continue
				var room := MC.room_um(target, MC.hold_clearance_mm(z))
				for inl: String in INLAYS:
					var s := MC.setup({ "claw": C(id), "target": target, "zone": z, "inlay": inl, "defense": true })
					if not s.ok:
						continue
					n += 1
					var tag := "%s quieto en %s (%s) con %s" % [id, z, car, inl]
					for o: String in marks_offenses(s.scratch, panel, room, reach):
						bad.append("%s, marcas: %s" % [tag, o])
					if s.defense != null:
						for o: String in marks_offenses(s.defense.tear, panel, room, reach):
							bad.append("%s, desgarro asustado: %s" % [tag, o])
	assert_true(n > 1500, "ensayos: %d" % n)
	assert_true(through > 100, "golpes con marcas de lado a lado: %d" % through)
	assert_true(capped > 50, "punciones que topan con el fondo del hueco: %d" % capped)
	assert_eq(bad.size(), 0, "la invariante:\n%s" % "\n".join(PackedStringArray(bad.slice(0, 20))))


func test_el_velocirraptor_de_cine_en_el_capo() -> void:
	var st: RefCounted = MCS.new()
	st.threaded = false
	assert_true(st.load_experiment("velocirraptor_pelicula"), "el experimento del caso 13 de la demo")
	st.finish()
	var h: Dictionary = st.hit
	assert_true(h.ok, "golpe")
	var m: Dictionary = h.marks
	assert_true(m.through, "las marcas atraviesan la chapa")
	assert_near(float(m.depthUm), 810.0, 1e-12, 0.0, "hondura: la pintura (110 µm) y el acero (700 µm)")
	assert_near(float(m.tipUm), 80810.0, 1e-12, 0.0, "la punta, al fondo de los 80 mm de hueco bajo el capó (no a los 120 mm de su garra)")
	assert_near(float(m.belowMm), 80.0, 1e-12, 0.0, "asoma todo el hueco")
	assert_true(m.bottoms, "llega al fondo")
	# unidad 4p: en la punción, las garras están en el pie que abolla el capó: la punta y la abolladura comparten el hueco
	# (las marcas, al resbalar fuera de la abolladura, tienen el hueco entero)
	var pn: Dictionary = h.puncture
	var dent_mm: float = h.dent.depthMm
	assert_true(pn.bottoms and dent_mm > 40.0, "topa con el fondo del hueco que le deja la abolladura de ~46 mm (%s mm)" % dent_mm)
	assert_near(float(pn.depthUm) + dent_mm * 1000.0, 80810.0, 0.0, 1e-2, "la punta y la abolladura llenan juntas el panel y su hueco")
	assert_true(float(pn.depthUm) < 40000.0, "la punta entra ~35 mm, no los 80 del hueco entero: %s µm" % pn.depthUm)
	# topa antes de que el agujero tenga el ancho de la garra (su base, 0,15 × 120 mm, a 66,8 mm de la punta): agujero más
	# estrecho y el trabajo de la chapa hasta ahí, y lo que no se quedan las garras abolla más el capó
	var tip := MC.claw_tip(ClawsV2.apply(C("velociraptor_pelicula")), Catalog.INLAYS[0])
	assert_near(float(pn.holeUm), 2.0 * Contact.hole_radius(tip, float(pn.depthUm) / 1000.0) * 1000.0, 1e-12, 0.0, "el agujero, de la garra a esa profundidad")
	assert_true(float(pn.holeUm) < 36000.0 - 1.0, "más estrecho que la base de la garra: %s µm" % pn.holeUm)
	assert_near(float(pn.workJ), MC.sheet_work_j(tip, T("coche"), float(pn.depthUm) / 1000.0), 1e-12, 0.0, "el trabajo de la chapa hasta ahí")
	var motor := Physics.compute(MC._lab_params(_strike(ClawsV2.apply(C("velociraptor_pelicula")), h), T("coche"),
		{ "method": "puncion", "strike": true, "force": float(h.massKg) * MC.G / 2.0, "model": "2.0" }))
	assert_near(float(motor.depthUm), 120000.0, 1e-12, 0.0, "el motor la lleva hasta su largo")
	assert_true(float(pn.workJ) < float(motor.workJ), "las garras se quedan menos que en el motor, que la lleva hasta su largo")
	var report := {}
	for row: Array in h.report:
		report[row[0]] = row[1]
	var depth := String(report.get("Profundidad", ""))
	assert_true(depth.begins_with("atraviesan la chapa (0.81 mm con la pintura)"), "informe: %s" % depth)
	assert_true(depth.contains("hasta el fondo del hueco bajo el capó") and depth.contains("80 mm"), "informe, la punta: %s" % depth)
	var band := String(st.impact_band_text())
	assert_true(band.contains("marcas que atraviesan la chapa (0.81 mm con la pintura)"), "banda: %s" % band)
	assert_false(band.contains("120 mm"), "la banda ya no dice los 120 mm de la garra: %s" % band)
	var marks_reading := {}
	for r: Dictionary in st.impact_readings():
		if r.id == "marcas":
			marks_reading = r
	assert_eq(marks_reading.get("value"), "de lado a lado", "lectura de las marcas")
	assert_true(String(marks_reading.get("sub", "")).contains("0.81 mm"), "lectura: %s" % marks_reading.get("sub"))
	var said_gap := false
	for f: Dictionary in st.facts():
		if String(f.text).begins_with("Bajo el capó hay ~80 mm de hueco"):
			said_gap = String(f.text).contains(": lo comparten la abolladura, que no puede ser más honda, y la punta de unas garras que atraviesan la chapa; donde se apoya, con la chapa hundida ~")
	assert_true(said_gap, "el «¿sabías que…?» del hueco dice que la punta lo comparte con la abolladura (unidad 4p)")
	st.dispose()


## La garra del golpe de impact(): su masa reducida por garra y la velocidad contra el panel (como en impact).
static func _strike(claw: Dictionary, h: Dictionary) -> Dictionary:
	var sc := claw.duplicate(true)
	sc.strike = { "v": float(h.vNormalKmh) / MC.KMH, "m": float(h.reducedMassKg) / 2.0 }
	return sc


func test_una_garra_que_topa_antes_de_tener_su_ancho() -> void:
	# la daga de diamante del casuario contra la aleta de acero: 110 mm de daga y 60 mm de hueco; su base (Ø 33 mm) llega a
	# los ~66 mm, así que topa antes: el agujero es más estrecho y la chapa se queda menos energía
	var p := { "claw": C("casuario"), "target": T("coche"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 0.0, "angle_deg": 90.0,
		"inlay": "diamante" }
	var r := MC.impact(p)
	var pn: Dictionary = r.puncture
	# unidad 4p: el pie abolla la aleta y la daga comparte el hueco con la abolladura
	var room_full := 810.0 + 60000.0
	var room := MC.shared_room_um(T("coche"), 60.0, float(r.dent.depthMm))
	assert_true(float(r.dent.depthMm) > 0.1 and room < room_full, "la patada abolla la aleta (%s mm)" % r.dent.depthMm)
	assert_true(pn.through and pn.bottoms, "la atraviesa y topa con el fondo")
	assert_near(float(pn.depthUm), room, 0.0, 1e-2, "la punta, al fondo del hueco que le deja la abolladura")
	var inlay: Dictionary = Data.find_by_id(Data.INLAYS, "diamante")
	var tip := MC.claw_tip(C("casuario"), inlay)
	assert_true(room / 1000.0 < Contact.depth_for_radius(tip, float(tip.amax)), "topa antes de que el agujero tenga su ancho")
	assert_near(float(pn.holeUm), 2.0 * Contact.hole_radius(tip, room / 1000.0) * 1000.0, 1e-12, 0.0, "el agujero de la daga a esa profundidad")
	assert_true(float(pn.holeUm) < 2.0 * float(tip.amax) * 1000.0 - 1.0, "más estrecho que la base")
	assert_near(float(pn.workJ), MC.sheet_work_j(tip, T("coche"), room / 1000.0), 1e-12, 0.0, "el trabajo de la chapa hasta ahí")
	var free := MC.impact(p.merged({ "zone": "puerta" }, true))
	assert_false(free.puncture.bottoms, "en la puerta (150 mm de hueco) entra entera")
	assert_true(float(pn.workJ) < float(free.puncture.workJ), "topando antes, la chapa se queda menos")
	var e: Dictionary = r.energy
	var sum := 0.0
	for t: Dictionary in e.terms:
		sum += float(t.j)
	assert_near(sum, float(e.totalJ), 1e-9, 1e-9, "el balance sigue sumando el total")
	# y el surco de la daga, al rayar, de lado a lado con la punta al fondo del hueco entero (resbala fuera de la abolladura)
	assert_true(r.marks.through, "el surco atraviesa la aleta")
	assert_near(float(r.marks.tipUm), room_full, 1e-12, 0.0, "la punta del surco, al fondo del hueco")
	assert_true(float(r.marks.widthUm) <= 2.0 * Contact.hole_radius(tip, room_full / 1000.0) * 1000.0 + 1e-9,
		"el surco no es más ancho que la daga a la profundidad de su punta")


func test_quieto_encima_raja_de_lado_a_lado() -> void:
	var st: RefCounted = MCS.new(C("velociraptor_pelicula"), T("coche"))
	st.threaded = false
	st.set_mode(MCS.MODE_HOLD)
	st.set_zone("techo")
	st.set_defense(true)
	st.finish()
	var tear: Dictionary = st.scen.defense.tear
	assert_true(tear.through, "asustado, sus garras de película rajan la chapa de lado a lado")
	assert_near(float(tear.depthUm), 810.0, 1e-12, 0.0, "tan hondo como el panel")
	assert_true(float(tear.tipUm) <= 810.0 + 100000.0 + 1e-6, "la punta no pasa de los 100 mm de hueco bajo el techo")
	assert_true(String(st.scen.defense.vsub).contains("rajan la chapa de lado a lado (0.81 mm con la pintura)"), "defensa: %s" % st.scen.defense.vsub)
	assert_false(String(st.scen.defense.vsub).contains("120 mm"), "sin los 120 mm de la garra: %s" % st.scen.defense.vsub)
	var rows := {}
	for row: Array in st.hold_rows():
		rows[row[0]] = row[1]
	assert_true(String(rows.get("Desgarros (asustado)", "")).begins_with("raja la chapa de lado a lado (0.81 mm con la pintura)"),
		"fila de los desgarros: %s" % rows.get("Desgarros (asustado)"))
	st.dispose()


func test_la_punta_y_la_abolladura_comparten_el_hueco() -> void:
	# el velocirraptor de cine sobre el capó (el caso 13 de la demo): el pie abolla el capó y sus garras topan con el fondo del
	# hueco que le queda debajo de la chapa hundida
	var st: RefCounted = MCS.new()
	st.threaded = false
	assert_true(st.load_experiment("velocirraptor_pelicula"), "el experimento del caso 13")
	st.finish()
	var h: Dictionary = st.hit
	var pn: Dictionary = h.puncture
	var dent_mm: float = h.dent.depthMm
	var panel := MC.panel_um(T("coche"))
	assert_near(float(pn.depthUm), panel + (80.0 - dent_mm) * 1000.0, 0.0, 1e-2, "la punta, al fondo de lo que deja la abolladura")
	assert_near(float(pn.belowMm), 80.0 - dent_mm, 0.0, 1e-5, "lo que asoma por detrás: el hueco menos la abolladura")
	# lo que no se quedan las garras abolla más la chapa: más que con el hueco entero para la punta (43,5 mm, unidad 4o)
	assert_true(dent_mm > 43.6 and dent_mm < 80.0, "abolladura de %s mm" % dent_mm)
	var sum := 0.0
	for t: Dictionary in h.energy.terms:
		sum += float(t.j)
	assert_near(sum, float(h.energy.totalJ), 1e-9, 1e-9, "el balance sigue sumando el total")
	assert_near(float(h.energy.clawsJ), 2.0 * float(pn.workJ), 1e-12, 0.0, "las dos garras, con el trabajo de la chapa hasta su punta")
	# en los dos extremos de la banda (el hueco bajo el capó va de 20 a 100 mm), lo mismo; y con más hueco la punta entra más
	var band: Dictionary = h.band
	for which: String in ["lo", "hi"]:
		var e: Dictionary = band[which]
		var gap: float = float(MC.CLEARANCE_BAND.capo.min if which == "lo" else MC.CLEARANCE_BAND.capo.max)
		assert_true(float(e.punctureDepthUm) + float(e.dentMm) * 1000.0 <= panel + gap * 1000.0 + 1e-2,
			"banda %s: la punta (%s µm) y la abolladura (%s mm) caben en %s mm de hueco" % [which, e.punctureDepthUm, e.dentMm, gap])
	assert_true(float(band.lo.punctureDepthUm) <= float(pn.depthUm) + 1e-6 and float(pn.depthUm) <= float(band.hi.punctureDepthUm) + 1e-6,
		"con más hueco, la punta entra más: %s ≤ %s ≤ %s µm" % [band.lo.punctureDepthUm, pn.depthUm, band.hi.punctureDepthUm])
	# el «¿sabías que…?» lo dice con sus números
	var said := ""
	for f: Dictionary in st.facts():
		if String(f.text).begins_with("Bajo el capó hay ~80 mm de hueco"):
			said = String(f.text)
	assert_true(said.contains("con la chapa hundida ~%s, a la punta le quedan ~%s por debajo" % [MC.fmt_long(dent_mm * 1000.0),
		MC.fmt_long((80.0 - dent_mm) * 1000.0)]), said)
	# y el informe: la punción, donde se apoya, con lo que le deja la abolladura; las marcas, que resbalan fuera de ella, con
	# el hueco entero (hasta el fondo, 80 mm por detrás)
	var report := {}
	for row: Array in h.report:
		report[row[0]] = row[1]
	assert_true(String(report.get("Perforación", "")).ends_with("; donde se apoya, con la chapa hundida ~%s, la punta entra ~%s por debajo" % [
		MC.fmt_long(dent_mm * 1000.0), MC.fmt_long(float(pn.belowMm) * 1000.0)]), report.get("Perforación"))
	assert_true(String(report.get("Profundidad", "")).contains("la punta entra ~80 mm (8.0 cm) por detrás, hasta el fondo del hueco"),
		report.get("Profundidad"))
	st.dispose()
	# si la abolladura llena el hueco (el tigre con zafiro contra la puerta), la punta no asoma por debajo
	var tz: Dictionary = MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0,
		"angle_deg": 90.0, "inlay": "zafiro" })
	assert_true(MC.shared_gap_txt(tz.puncture, tz.dent, T("coche")).ends_with("la punta no asoma por debajo"),
		MC.shared_gap_txt(tz.puncture, tz.dent, T("coche")))
	# y sin abolladura o sin topar, nada que decir
	assert_eq(MC.shared_gap_txt(tz.puncture, null, T("coche")), "", "sin abolladura")
	var loose: Dictionary = tz.puncture.duplicate()
	loose["bottoms"] = false
	assert_eq(MC.shared_gap_txt(loose, tz.dent, T("coche")), "", "sin topar")
	# y donde no hay abolladura (la aleta de plástico, que se hunde y recupera), la punta tiene el hueco entero
	var r := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 40.0,
		"angle_deg": 90.0, "drop_m": 0.0 })
	assert_false(r.dent.applies, "el plástico no se abolla")
	assert_near(float(r.puncture.depthUm), minf(reach_um("tigre"), MC.room_um(T("cocheplastico"), 60.0)), 1e-12, 0.0, "la punta, como siempre")


func test_lo_que_no_atraviesa_no_cambia() -> void:
	# el águila con sus talones en el techo: raya la pintura hasta el metal, sin atravesar nada
	var r := MC.impact({ "claw": C("aguila"), "target": T("coche"), "zone": "techo", "v_kmh": 90.0, "animal_kmh": 60.0,
		"angle_deg": 0.0, "drop_m": 0.2 })
	var m: Dictionary = r.marks
	assert_false(m.through, "no atraviesa")
	assert_near(float(m.tipUm), float(m.depthUm), 0.0, 0.0, "la punta es la marca")
	assert_eq(float(m.belowMm), 0.0, "nada por detrás")
	assert_false(m.bottoms, "ni llega al fondo")
	var report := {}
	for row: Array in r.report:
		report[row[0]] = row[1]
	assert_eq(report.get("Profundidad"), MC.marks_depth_txt(m, T("coche")), "el informe, como siempre")
	assert_false(String(report.get("Profundidad", "")).contains("atraviesa"), "sin «atraviesa»")
