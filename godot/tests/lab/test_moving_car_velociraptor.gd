## Los velocirraptores en el coche en marcha (unidad 4i-B2; docs/fisica/coche-en-marcha.md §14 y velociraptor.md §10.7 y
## §11): el de cine (FICCIÓN en su garra, que corta la chapa) y la reconstrucción. Cuerpo, zonas y agarre; el salto (el de la
## patada del casuario, con el vuelo frenado por el aire y la altura de los paneles); el golpe de cada uno con su veredicto;
## que la física del de cine sea la del motor (solo cambian las palabras); el balance de energía exacto con la masa de más
## de unas garras reforjadas; invariantes («más agarre nunca da menos margen», «una garra reforjada más afilada nunca entra
## menos con la misma carga» (desde la unidad 4p, contando la abolladura: la punta comparte su hueco), «sin afilar, lo de
## siempre al bit») y el estado de la tarjeta (las dos variantes, la calidad «ficcion», los experimentos y los
## textos).
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const Js = preload("res://core/shared/js.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const V8 = preload("res://core/shared/v8_math.gd")

const RAPTORS := ["velociraptor_pelicula", "velociraptor"]
const FILM := "velociraptor_pelicula"
const REAL := "velociraptor"


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## El golpe del experimento: el coche a 50 km/h y el animal que cruza a 39 (lo más que corre: 38,88).
static func hit(id: String, zone: String, over: Dictionary = {}) -> Dictionary:
	var p := { "claw": C(id), "target": T("coche"), "zone": zone, "v_kmh": 50.0, "animal_kmh": 39.0, "angle_deg": 90.0 }
	p.merge(over, true)
	return MC.impact(p)


static func perched(id: String, zone: String, over: Dictionary = {}) -> Dictionary:
	var p := { "claw": C(id), "target": T("coche"), "zone": zone, "posture": "tumbado" }
	p.merge(over, true)
	return MC.setup(p)


# ── Cuerpo, zonas y agarre ──

func test_el_cuerpo_de_los_velocirraptores() -> void:
	for id: String in RAPTORS:
		var b: Variant = MC.body_of(C(id))
		assert_true(b != null, "%s: con datos" % id)
		assert_eq(b.kind, "teropodo", "%s: terópodo" % id)
		assert_true(MC.is_leaper(b), "%s: se abalanza saltando" % id)
		assert_eq(MC.strike_claws_of(b), 2, "%s: golpean las dos garras falciformes" % id)
		assert_eq(int(b.contact), 4, "%s: quieto, apoya los dedos III y IV" % id)
		assert_true(MC.supports_hold(C(id)), "%s: se puede quedar encima" % id)
		assert_eq(MC.GRAMMAR[id], ["el", "o"], "%s: «el velocirraptor»" % id)
	assert_eq(MC.POSTURES.teropodo, ["tumbado"], "solo agazapado: sin alas medidas")
	assert_true(MC.is_film(C(FILM)) and not MC.is_film(C(REAL)), "is_film")
	assert_eq(MC.BODIES[FILM].variant, "pelicula", "variante del dibujo")
	assert_eq(MC.BODIES[REAL].variant, "reconstruccion", "variante del dibujo")


func test_zonas_y_anclajes() -> void:
	var zones := MC.zones_for(C(REAL))
	assert_false(zones.has("antena") or zones.has("retrovisor"), "no cabe en la antena ni en el retrovisor: %s" % [zones])
	for z: String in ["capo", "limpiaparabrisas", "parabrisas", "techo", "barras", "ventanilla", "maletero", "aleta"]:
		assert_true(zones.has(z), "puede quedarse en %s" % z)
	assert_eq(MC.zones_for(C(FILM)), zones, "las mismas para los dos")
	for z: String in ["limpiaparabrisas", "barras", "ventanilla"]:
		assert_eq(String(perched(REAL, z).anchor), "agarre", "%s: agarra con los pies, como las rapaces" % z)
	assert_eq(String(perched(REAL, "techo").anchor), "friccion", "en el techo no hay nada que agarrar")


func test_el_agarre_es_el_de_su_ficha() -> void:
	for id: String in RAPTORS:
		var g: Dictionary = C(id).dino.forces.grip
		var gb := MC.grip_band(C(id))
		assert_eq([gb.value, gb.min, gb.max], [float(g.value), float(g.min), float(g.max)], "%s: la banda de su ficha" % id)
		assert_eq(MC.grip_source(C(id)).quality, g.quality, "%s: su calidad" % id)
		var s := perched(id, "barras")
		assert_near(float(s.anchorN.value), 2.0 * float(g.value) * float(MC.GRASP_K.value), 1e-12, 0.0, "%s: dos pies con su agarre" % id)
		var d: Variant = MC.defense_force(C(id))
		assert_eq(float(d.value), float(g.value), "%s: asustado aprieta con su agarre máximo" % id)
	# las rapaces siguen con el suyo (ClawsV2)
	var eagle: Dictionary = Data.find_by_id(Data.CLAWS, "aguila")
	assert_eq(MC.grip_band(eagle), MC.ClawsV2.band(eagle, "force"), "el águila, el de ClawsV2")


func test_mas_agarre_nunca_da_menos_margen() -> void:
	for id: String in RAPTORS:
		var strong: Dictionary = C(id).duplicate(true)
		for k: String in ["value", "min", "max"]:
			strong.dino.forces.grip[k] = float(strong.dino.forces.grip[k]) * 1.5
		for zone: String in ["limpiaparabrisas", "barras", "ventanilla", "techo", "capo"]:
			for man: Array in [[0.0, 0.0], [-0.9, 0.0], [0.0, 0.5], [0.3, 0.3]]:
				var over := { "accel_g": man[0], "lateral_g": man[1] }
				var a := perched(id, zone, over)
				var p := { "claw": strong, "target": T("coche"), "zone": zone, "posture": "tumbado" }
				p.merge(over, true)
				var b := MC.setup(p)
				for v: float in [0.0, 60.0, 120.0, 200.0]:
					var aa := MC.at_speed(a, v)
					var bb := MC.at_speed(b, v)
					var tag := "%s %s %s a %s km/h" % [id, zone, man, v]
					assert_true(float(bb.availN) - float(bb.needN) >= float(aa.availN) - float(aa.needN) - 1e-9, "%s: más agarre, no menos margen" % tag)
				var da := MC.detach(a)
				var db := MC.detach(b)
				assert_true(float(db.kmh) >= float(da.kmh) - 1e-6, "%s %s %s: más agarre no se suelta antes" % [id, zone, man])


# ── El salto ──

func test_el_salto_es_el_de_la_patada_del_casuario() -> void:
	assert_near(MC.kick_leap_ms(), Velociraptor.leap_speed_ms(), 1e-15, 0.0, "los mismos w y f")
	assert_near(MC.kick_leap_ms(), sqrt(4.0 * 45.0 * 8.498 / 65.3), 1e-12, 0.0, "v = √(4·w·f) = 4,84 m/s")
	var v := MC.kick_leap_ms()
	assert_near(MC.leap_reach_m(), v * v / (2.0 * MC.G), 1e-15, 0.0, "sube v²/2g")
	assert_near(MC.leap_reach_m(), 1.1943, 1e-4, 0.0, "~1,19 m")
	assert_near(MC.leap_reach_m(true), 1.7914, 1e-4, 0.0, "con los datos más favorables, ~1,79 m")


func test_la_altura_de_los_paneles_y_a_donde_llega() -> void:
	var hood: Dictionary = MC.IMPACT_ZONES.capo
	var rise := float(hood.slide_m) * V8.js_sin(float(hood.slope_deg) * PI / 180.0)
	assert_near(float(MC.panel_height_m("capo")), 0.70 + 0.5 * rise, 1e-12, 0.0, "la mitad del capó, desde su borde a 70 cm")
	assert_true(float(MC.panel_height_m("parabrisas")) > float(MC.panel_height_m("capo")), "el parabrisas, más alto")
	assert_eq(float(MC.panel_height_m("techo")), 1.475, "el techo: el alto de la berlina de Cui et al. (2025)")
	assert_eq(MC.panel_height_m("puerta"), null, "un costado no tiene altura de salto")
	assert_true(float(MC.panel_height_m("capo", "max")) > float(MC.panel_height_m("capo", "min")), "la banda del borde del capó")
	assert_true(MC.leap_reaches("capo") and MC.leap_reaches("parabrisas") and MC.leap_reaches("puerta"), "llega al capó, al parabrisas y a los costados")
	assert_false(MC.leap_reaches("techo"), "al techo no llega saltando (1,19 m < 1,475 m)")
	assert_true(MC.leap_reach_m(true) > float(MC.panel_height_m("techo")), "con los datos más favorables llegaría: lo dice el texto")
	for id: String in RAPTORS:
		# y a la ventanilla (unidad 4m), saltando: sus pies suben ~1,19 m y la ventanilla empieza a ~0,89 m
		assert_eq(MC.impact_zones_for(C(id)), ["capo", "parabrisas", "puerta", "aleta", "luna"], "%s: las zonas del golpe" % id)
		var r := hit(id, "techo")
		assert_false(r.ok, "%s: el techo, no" % id)
		assert_true(String(r.reason).contains("no llega saltando"), "%s: y dice por qué: %s" % [id, r.reason])


func test_el_vuelo_sin_aire_es_el_de_los_libros() -> void:
	var g := MC.G
	for c: Array in [[0.0, 10.8, 4.84, 0.7955], [5.0, 3.0, 4.84, 1.12], [-3.0, 0.0, 5.93, 1.5], [0.0, 0.0, 4.84, 0.0]]:
		var uz0: float = c[2]
		var h: float = c[3]
		var fl := MC.leap_flight(20.0, 0.0, 1.2, c[0], c[1], uz0, h)
		var disc := uz0 * uz0 - 2.0 * g * h
		if h <= 0.0:
			continue
		assert_true(fl.reaches, "%s: llega" % [c])
		assert_near(float(fl.timeS), (uz0 + sqrt(disc)) / g, 1e-9, 1e-12, "%s: t = (u + √(u² − 2gh))/g" % [c])
		assert_near(float(fl.uz), -sqrt(disc), 1e-9, 1e-12, "%s: baja a √(u² − 2gh)" % [c])
		assert_near(float(fl.ux), c[0], 1e-12, 1e-12, "%s: sin aire, la horizontal no cambia" % [c])
		assert_near(float(fl.uy), c[1], 1e-12, 1e-12, "%s: ni la lateral" % [c])
		assert_near(float(fl.apexM), uz0 * uz0 / (2.0 * g), 0.0, 2e-4, "%s: el punto más alto, u²/2g (muestreado cada 10 ms)" % [c])
		assert_near(float(fl.lossMs), 0.0, 0.0, 1e-9, "%s: el aire no le quita nada" % [c])
	# por encima de lo que sube, no llega
	assert_false(MC.leap_flight(20.0, 0.0, 1.2, 0.0, 10.8, 4.84, 1.475).reaches, "el techo, no")


func test_el_aire_nunca_acelera_el_salto() -> void:
	var prev_loss := -1.0
	var prev_apex := INF
	for cda: float in [0.0, 0.01, 0.035, 0.1, 0.3]:
		var fl := MC.leap_flight(19.7, cda, 1.204, 0.0, 10.8, MC.kick_leap_ms(), float(MC.panel_height_m("capo")))
		assert_true(fl.reaches, "CdA %s: llega al capó" % cda)
		var got := sqrt(float(fl.ux) * float(fl.ux) + float(fl.uy) * float(fl.uy) + float(fl.uz) * float(fl.uz))
		var free := sqrt(10.8 * 10.8 + MC.kick_leap_ms() * MC.kick_leap_ms() - 2.0 * MC.G * float(MC.panel_height_m("capo")))
		assert_true(got <= free + 1e-9, "CdA %s: nunca más deprisa que sin aire" % cda)
		assert_true(float(fl.lossMs) >= prev_loss - 1e-12, "CdA %s: más área, más pérdida" % cda)
		assert_true(float(fl.apexM) <= prev_apex + 1e-12, "CdA %s: más área, menos altura" % cda)
		prev_loss = fl.lossMs
		prev_apex = fl.apexM


func test_el_bloque_del_salto_en_el_golpe() -> void:
	for id: String in RAPTORS:
		var r := hit(id, "capo")
		var lp: Dictionary = r.leap
		assert_eq(String(r.attack), "salto", "%s: el ataque es un salto" % id)
		assert_true(lp.runCapped, "%s: pidió 39 km/h y corre como mucho a 38,88" % id)
		assert_near(float(lp.runKmh), 10.8 * MC.KMH, 1e-12, 0.0, "%s: la carrera de su ficha" % id)
		assert_near(float(lp.leapMs), MC.kick_leap_ms(), 1e-15, 0.0, "%s: el salto" % id)
		assert_false(lp.side, "%s: el capó es un panel de arriba" % id)
		assert_true(float(lp.uz) < 0.0, "%s: llega de bajada" % id)
		assert_true(float(lp.airLossKmh) > 0.0 and float(lp.airLossKmh) < 1.0, "%s: el aire le quita poco (%s km/h)" % [id, lp.airLossKmh])
		# la velocidad relativa al coche sale del vuelo: (ux − v_coche, uy, uz)
		var vc := 50.0 / MC.KMH
		var rx := float(lp.ux) - vc
		var vrel := sqrt(rx * rx + float(lp.uy) * float(lp.uy) + float(lp.uz) * float(lp.uz))
		assert_near(float(r.vRelKmh), vrel * MC.KMH, 1e-12, 0.0, "%s: la velocidad relativa, la del vuelo" % id)
		var side := hit(id, "puerta")
		assert_true(side.leap.side, "%s: contra la puerta golpea con la carrera" % id)
		assert_near(float(side.vNormalKmh), 10.8 * MC.KMH, 1e-12, 0.0, "%s: de lado, a 38,88 km/h" % id)
		# más despacio de lo que corre, la carrera pedida
		var slow := hit(id, "capo", { "animal_kmh": 20.0 })
		assert_false(slow.leap.runCapped, "%s: a 20 km/h no llega al tope" % id)
		assert_near(float(slow.leap.runKmh), 20.0, 1e-12, 0.0, "%s: corre a lo pedido" % id)


# ── El golpe de cada uno ──

func test_el_de_cine_raja_la_chapa_y_el_de_verdad_no() -> void:
	var film := hit(FILM, "capo")
	var real := hit(REAL, "capo")
	assert_eq(String(film.verdict), "SALTA SOBRE EL CAPÓ Y LO RAJA", "el de cine: %s" % film.verdict)
	assert_true(film.film and film.cutsBody, "ficción: su garra corta la chapa")
	assert_eq(String(film.marks.verdict), "RAJA LA CHAPA", "raja la chapa")
	assert_true(String(film.vsub).contains("ficción") and String(film.vsub).contains("queratina"), "con el contraste: %s" % film.vsub)
	assert_false(real.film or real.cutsBody, "el de verdad: su queratina no corta el acero")
	assert_false(String(real.verdict).contains("RAJA") or String(real.vsub).contains("ficción"), "ni raja ni es ficción: %s" % real.verdict)
	assert_eq(String(real.marks.verdict), "HASTA EL METAL", "raya la pintura hasta el metal")
	assert_eq(String(hit(FILM, "puerta").verdict), "SE ABALANZA Y RAJA LA PUERTA", "contra la puerta")
	assert_eq(String(hit(FILM, "aleta").verdict), "SE ABALANZA Y RAJA LA ALETA", "contra la aleta")
	var glass := hit(FILM, "parabrisas")
	assert_true(String(glass.verdict).contains("PARABRISAS"), "el parabrisas: %s" % glass.verdict)
	assert_true(String(glass.vsub).contains("vidrio"), "ni la garra de película raya el vidrio: %s" % glass.vsub)
	# en el plástico, el de verdad también lo atraviesa: la ficción está en el acero
	var plastic_film := hit(FILM, "aleta", { "target": T("cocheplastico") })
	var plastic_real := hit(REAL, "aleta", { "target": T("cocheplastico") })
	assert_true(plastic_real.puncture.through and plastic_film.puncture.through, "el plástico lo atraviesan los dos")
	var rows := {}
	for row: Array in plastic_film.report:
		rows[row[0]] = row[1]
	assert_true(String(rows["Garras de película"]).contains("también lo atraviesa"), "el informe lo dice: %s" % rows["Garras de película"])


func test_la_fisica_del_de_cine_es_la_del_motor() -> void:
	# sin la marca de película, la misma garra da los mismos números: solo cambian las palabras
	var plain: Dictionary = C(FILM).duplicate(true)
	plain.dino.film = false
	for zone: String in MC.impact_zones_for(C(FILM)):
		for tid: String in ["coche", "cochealu", "cocheplastico"]:
			var p := { "claw": C(FILM), "target": T(tid), "zone": zone, "v_kmh": 70.0, "animal_kmh": 30.0, "angle_deg": 45.0 }
			var q := p.duplicate()
			q.claw = plain
			var a := MC.impact(p)
			var b := MC.impact(q)
			for k: String in a:
				if k in ["verdict", "vsub", "report", "film"]:
					continue
				assert_true(same(a[k], b[k]), "%s %s: %s igual" % [zone, tid, k])


func test_la_energia_del_golpe_cuadra_con_garras_reforjadas_y_afiladas() -> void:
	var combos := [[50.0, 39.0, 90.0], [90.0, 20.0, 0.0], [0.0, 39.0, 45.0], [120.0, 39.0, 180.0]]
	for id: String in RAPTORS:
		for inl: String in ["none", "zafiro", "tungsteno", "oro"]:
			for s: float in [0.0, 0.6]:
				for tid: String in ["coche", "cochealu", "cocheplastico"]:
					for zone: String in MC.impact_zones_for(C(id)):
						for k: Array in combos:
							var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1],
								"angle_deg": k[2], "inlay": inl, "sharpness": s })
							var tag := "%s de %s (s %s) contra %s (%s, %s)" % [id, inl, s, tid, zone, k]
							assert_true(r.ok, "%s: se hace" % tag)
							var e: Dictionary = r.energy
							var sum := 0.0
							for t: Dictionary in e.terms:
								assert_true(float(t.j) >= 0.0, "%s: %s no es negativo" % [tag, t.id])
								sum += float(t.j)
							assert_near(sum, e.totalJ, 1e-9, 1e-9, "%s: los términos suman el total" % tag)
							var vr := float(r.vRelKmh) / MC.KMH
							assert_near(e.totalJ, 0.5 * float(r.massKg) * vr * vr, 1e-9, 1e-9, "%s: el total es ½·m·v_rel²" % tag)
							assert_near(e.punctureJ + e.panelJ + e.animalJ, r.normalJ, 1e-9, 1e-9, "%s: la normal que se disipa" % tag)
							var vn := float(r.vNormalKmh) / MC.KMH
							assert_near(e.carJ, 0.5 * (float(r.massKg) - float(r.reducedMassKg)) * vn * vn, 1e-9, 1e-9, "%s: el empujón al coche" % tag)
							var cm: Variant = r.clawMass
							var added := 0.0 if cm == null else float(cm.addedKg)
							assert_near(float(r.massKg), float(C(id).mass) + added, 1e-12, 0.0, "%s: la masa, la del animal y sus garras" % tag)
							if cm != null:
								assert_near(float(cm.extraJ), 0.5 * added * vr * vr, 1e-12, 1e-12, "%s: la masa de más suma ½·Δm·v²" % tag)


func test_la_masa_de_las_garras_reforjadas() -> void:
	var none := hit(REAL, "capo")
	assert_eq(none.clawMass, null, "con queratina, nada de más")
	var vol := ClawMass.cone_volume_mm3(float(C(REAL).reach))
	var prev := -INF
	# de menos a más densa (ClawMass.DENSITY): zafiro, acero, carburo de tungsteno y oro
	for inl: String in ["zafiro", "acero", "tungsteno", "oro"]:
		var r := hit(REAL, "capo", { "inlay": inl })
		var e: Variant = ClawMass.energy_effect(Data.find_by_id(Data.INLAYS, inl), vol, 2, 19.7, 9.85, 0.0)
		assert_near(float(r.clawMass.addedKg), float(e.addedKg), 1e-12, 0.0, "%s: el cono del motor en las dos garras que golpean" % inl)
		assert_eq(int(r.clawMass.claws), 2, "%s: las dos falciformes" % inl)
		# más densa, más energía: la velocidad la impone el coche
		assert_true(float(r.energyJ) > prev, "%s: más densa, más energía (%s J)" % [inl, r.energyJ])
		prev = r.energyJ
	# el casuario patea con su daga: el tope de la pata es el de su cuerpo, sin la daga
	var cas := MC.impact({ "claw": Data.find_by_id(Data.CLAWS, "casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0,
		"animal_kmh": 0.0, "inlay": "tungsteno" })
	var m_body: float = cas.kick.massKg
	assert_near(float(cas.kick.forceCapN), MC.kick_force_n(m_body), 1e-12, 0.0, "el tope, con la masa del cuerpo")
	assert_near(float(cas.kick.forceCapMinN), MC.kick_force_n(m_body, "min"), 1e-12, 0.0, "su banda baja, también")
	assert_near(float(cas.kick.forceCapMaxN), MC.kick_force_n(m_body, "max"), 1e-12, 0.0, "y la alta")
	assert_near(float(cas.massKg), m_body + float(cas.clawMass.addedKg), 1e-12, 0.0, "el golpe, con la daga de tungsteno")


# ── El afilado ──

func test_sin_afilar_da_lo_de_siempre_al_bit() -> void:
	for cfg: Array in [[REAL, "tungsteno"], [FILM, "zafiro"], [REAL, "none"], [FILM, "none"]]:
		var base := { "claw": C(cfg[0]), "target": T("coche"), "inlay": cfg[1] }
		for zone: String in ["capo", "puerta"]:
			var p := base.duplicate()
			p.merge({ "zone": zone, "v_kmh": 60.0, "animal_kmh": 30.0, "angle_deg": 90.0 })
			var q := p.duplicate()
			q["sharpness"] = 0.0
			assert_true(same(MC.impact(p), MC.impact(q)), "%s %s %s: s = 0, al bit" % [cfg[0], cfg[1], zone])
		var h := base.duplicate()
		h.merge({ "zone": "barras", "posture": "tumbado", "v_kmh": 90.0 })
		var h0 := h.duplicate()
		h0["sharpness"] = 0.0
		assert_true(same(MC.hold_report(h), MC.hold_report(h0)), "%s %s quieto: s = 0, al bit" % cfg)
	# el águila de tungsteno de la unidad 4d, igual
	var eagle := { "claw": Data.find_by_id(Data.CLAWS, "aguila"), "target": T("coche"), "zone": "techo", "v_kmh": 90.0,
		"animal_kmh": 60.0, "angle_deg": 0.0, "drop_m": 0.2, "inlay": "tungsteno" }
	var e0 := eagle.duplicate()
	e0["sharpness"] = 0.0
	assert_true(same(MC.impact(eagle), MC.impact(e0)), "el águila de tungsteno: s = 0, al bit")


func test_la_queratina_y_la_garra_de_pelicula_no_se_afilan() -> void:
	for id: String in RAPTORS:
		var a := hit(id, "capo")
		var b := hit(id, "capo", { "sharpness": 0.8 })
		assert_true(same(a, b), "%s: sin material, el afilado no hace nada" % id)
		assert_eq(b.sharpness, null, "%s: sin punta afilada" % id)
		assert_eq(MC.sharpness_report({ "claw": C(id), "target": T("coche"), "zone": "techo", "sharpness": 0.8 }), null, "%s: sin deslizador" % id)


func test_una_garra_reforjada_mas_afilada_nunca_entra_menos() -> void:
	for id: String in RAPTORS:
		for inl: String in ["acero", "zafiro", "tungsteno", "diamante"]:
			var prev_hold := -INF
			var prev_marks := -INF
			var prev_punct := -INF
			for s: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var tag := "%s de %s afilada a %s" % [id, inl, s]
				var sc := perched(id, "techo", { "inlay": inl, "sharpness": s })
				assert_true(float(sc.scratch.depthUm) >= prev_hold - 1e-9, "%s: quieto encima, el surco no es menos hondo" % tag)
				prev_hold = sc.scratch.depthUm
				var r := hit(id, "capo", { "inlay": inl, "sharpness": s })
				assert_true(float(r.marks.depthUm) >= prev_marks - 1e-9, "%s: en el golpe, las marcas no son menos hondas" % tag)
				prev_marks = r.marks.depthUm
				if r.puncture != null:
					# unidad 4p: la punta comparte el hueco con la abolladura (coche-en-marcha.md §17.4), y una garra más afilada
					# se queda menos energía y deja abollar más la chapa, así que, al fondo, le queda menos hueco por debajo de la
					# chapa hundida; lo que no baja es hasta dónde llega desde donde estaba la chapa antes del golpe (la punta y
					# la abolladura juntas: al fondo, el hueco entero, con lo que da por igual la iteración del hueco compartido)
					var reach_um := float(r.puncture.depthUm)
					if r.dent != null and Js.truthy(r.dent.applies):
						reach_um += float(r.dent.depthMm) * 1000.0
					assert_true(reach_um >= prev_punct - MC.SHARED_GAP_TOL_UM, "%s: la punción no llega menos lejos (%s µm)" % [tag, reach_um])
					prev_punct = reach_um
				if s > 0.0:
					assert_true(r.sharpness != null and float(r.sharpness.tipRadiusUm) < float(r.sharpness.naturalTipRadiusUm), "%s: la punta, más fina" % tag)


# ── El informe ──

func test_el_informe_del_golpe() -> void:
	var rows := func(r: Dictionary) -> Dictionary:
		var out := {}
		for row: Array in r.report:
			out[row[0]] = row[1]
		return out
	var film: Dictionary = rows.call(hit(FILM, "capo"))
	assert_true(film.has("Salto") and film.has("Garras de película"), "el salto y la garra de película: %s" % [film.keys()])
	assert_true(String(film["Garras de película"]).begins_with("ficción (película)"), film["Garras de película"])
	var real: Dictionary = rows.call(hit(REAL, "capo"))
	assert_true(real.has("Salto") and not real.has("Garras de película"), "la reconstrucción, sin ficción")
	assert_true(String(real["Perforación"]).contains("queratina"), real["Perforación"])
	var sharp: Dictionary = rows.call(hit(REAL, "capo", { "inlay": "tungsteno", "sharpness": 0.5 }))
	assert_true(sharp.has("Masa de las garras") and sharp.has("Punta afilada"), "la masa y la punta: %s" % [sharp.keys()])
	assert_true(String(sharp["Punta afilada"]).begins_with("R 2.35 µm"), sharp["Punta afilada"])
	var side: Dictionary = rows.call(hit(REAL, "puerta"))
	assert_true(String(side["Salto"]).contains("no le hace falta saltar"), side["Salto"])


# ── El estado de la tarjeta ──

func test_un_velocirraptor_con_dos_variantes() -> void:
	var names := {}
	for a: Dictionary in MCS.supported_animals():
		names[a.id] = a.name
	assert_eq(names.get(FILM), "Velocirraptor", "uno en el selector, con el de cine")
	assert_false(names.has(REAL), "la reconstrucción, a un clic")
	assert_eq(MCS.animal_entry_id(REAL), FILM, "su entrada del selector")
	assert_eq(MCS.animal_entry_id("tigre"), "tigre", "los demás, la suya")
	var st := MCS.new()
	st.set_claw(C(FILM))
	assert_true(st.film(), "por defecto, el de cine")
	assert_true(st.is_leaper() and not st.is_kicker(), "salta (la caída del deslizador no cuenta)")
	assert_eq(st.variants().map(func(v: Dictionary) -> String: return v.id), [FILM, REAL], "las dos variantes")
	assert_eq(st.variants()[0].name, "De cine (ficción)", "dice que es ficción")
	st.set_variant(REAL)
	assert_eq(String(st.claw.id), REAL, "la reconstrucción")
	assert_false(st.film(), "ya no es de cine")
	assert_eq(st.variants().size(), 2, "sigue teniendo las dos")
	st.set_variant("tigre")
	assert_eq(String(st.claw.id), REAL, "una variante que no es suya no cambia nada")
	st.set_claw(C("tigre"))
	assert_true(st.variants().is_empty(), "el tigre no tiene variantes")
	assert_false(st.is_leaper(), "el tigre no salta así")
	assert_eq(st.draw_size().variant, "", "ni aspecto")
	st.dispose()


func test_la_calidad_ficcion_en_la_tarjeta() -> void:
	assert_eq(MCS.QUALITY_TEXT.ficcion, "ficción (película)", "«ficción (película)»")
	assert_eq(MCS._worst(["estimate", "ficcion", "primary"]), "ficcion", "manda sobre una estimación")
	var st := MCS.new()
	st.load_experiment("velocirraptor_pelicula")
	st.finish()
	var fiction: Array = st.sources().filter(func(s: Dictionary) -> bool: return s.quality == "ficcion")
	assert_true(fiction.any(func(s: Dictionary) -> bool: return s.label == "Garra de película"), "la garra de película, como ficción")
	assert_true(st.facts().any(func(f: Dictionary) -> bool: return f.quality == "ficcion"), "y un «¿sabías que…?» de ficción")
	for s: Dictionary in st.sources():
		assert_true(s.quality == "" or MCS.QUALITY_TEXT.has(s.quality), "calidad conocida: %s" % s.quality)
	st.load_experiment("velocirraptor_real")
	st.finish()
	assert_false(st.sources().any(func(s: Dictionary) -> bool: return s.quality == "ficcion"), "la reconstrucción no tiene ficción")
	assert_false(st.facts().any(func(f: Dictionary) -> bool: return f.quality == "ficcion"), "ni en sus datos")
	st.dispose()


func test_los_experimentos_de_un_clic() -> void:
	var st := MCS.new()
	var got := {}
	for id: String in ["velocirraptor_pelicula", "velocirraptor_real"]:
		assert_true(st.load_experiment(id), "%s: se carga" % id)
		st.finish()
		assert_true(st.experiment_matches(id), "%s: lo que se ve es el experimento" % id)
		assert_eq(st.mode, MCS.MODE_IMPACT, "%s: el golpe" % id)
		got[id] = { "verdict": String(st.hit.verdict), "why": st.why_text(), "moral": st.moral(), "zone": st.impact_zone, "v": st.v_kmh,
			"a": st.animal_kmh, "arrival": st.arrival(), "draw": st.draw_size() }
		assert_true(st.moral() != "" and st.why_text() != "", "%s: con porqué y moraleja" % id)
		st.set_sharpness(0.5)
		assert_true(st.experiment_matches(id), "%s: con queratina el afilado no cuenta" % id)
	var f: Dictionary = got.velocirraptor_pelicula
	var r: Dictionary = got.velocirraptor_real
	assert_eq([f.zone, f.v, f.a], [r.zone, r.v, r.a], "el mismo salto para los dos")
	assert_true(f.verdict.contains("RAJA"), "el de cine raja: %s" % f.verdict)
	assert_false(r.verdict.contains("RAJA"), "el de verdad no: %s" % r.verdict)
	assert_true(String(f.why).contains("En la película") and String(f.why).contains("Salta desde la carretera"), f.why)
	assert_true(String(r.why).contains("pinchan y sujetan"), r.why)
	assert_true(float(f.arrival.z) < 0.0, "llega de bajada al capó")
	assert_eq([f.draw.variant, r.draw.variant], ["pelicula", "reconstruccion"], "el aspecto del dibujo")
	assert_near(float(f.draw.heightM), 0.87, 1e-12, 0.0, "la cadera de Deinonychus")
	assert_near(float(r.draw.lengthM), 2.07, 1e-12, 0.0, "el largo de Velociraptor")
	st.dispose()


func test_el_afilado_en_la_tarjeta() -> void:
	var st := MCS.new()
	st.set_claw(C(REAL))
	st.set_mode(MCS.MODE_HOLD)
	st.set_zone("techo")
	assert_false(st.sharpenable(), "la queratina no se afila")
	assert_true(st.sharpness_view().is_empty(), "sin deslizador")
	st.set_inlay("tungsteno")
	assert_true(st.sharpenable(), "unas garras reforjadas, sí")
	st.set_sharpness(0.5)
	st.finish()
	assert_eq(st.sharpness, 0.5, "el afilado")
	var view := st.sharpness_view()
	assert_eq(String(view.display), "R 2.35 µm", "el deslizador, como el del banco: %s" % view.display)
	var rows := {}
	for row: Array in st.hold_rows():
		rows[row[0]] = row[1]
	assert_true(String(rows.get("Punta afilada", "")).begins_with("R 2.35 µm"), "la fila de la punta: %s" % [rows.keys()])
	st.set_sharpness(3.0)
	assert_eq(st.sharpness, 1.0, "como mucho, el filo más fino")
	st.set_variant(FILM)
	st.set_inlay("none")
	assert_false(st.sharpenable(), "la garra de película no se afila")
	st.dispose()


func test_los_textos_quieto_encima() -> void:
	var st := MCS.new()
	for id: String in RAPTORS:
		st.set_claw(C(id))
		st.set_mode(MCS.MODE_HOLD)
		for zone: String in ["techo", "barras", "parabrisas"]:
			st.set_zone(zone)
			st.finish()
			var tag := "%s %s" % [id, zone]
			assert_true(st.why_text() != "" and st.moral() != "", "%s: porqué y moraleja" % tag)
			assert_true(String(st.why_text()).contains("dedos") or String(st.why_text()).contains("agarre"), "%s: con los dedos: %s" % [tag, st.why_text()])
			var peso: Array = st.hold_readings().filter(func(r: Dictionary) -> bool: return r.id == "peso")
			assert_eq(String(peso[0].quality), String(C(id).dino.mass.quality), "%s: el peso, con la calidad de su masa" % tag)
	st.dispose()
