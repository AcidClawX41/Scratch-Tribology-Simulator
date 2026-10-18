## El daño según la velocidad y la fuerza del agarre, y la rotura de cada material de garra (unidad 4s;
## docs/fisica/coche-en-marcha.md §19): MovingCar.marks_at_speed y CarSpeedMarks. Invariantes:
## 1. parado, las marcas son las de antes (scen.scratch); 2. más velocidad nunca da un surco menos hondo (en crucero);
## 3. la queratina nunca atraviesa el acero ni el aluminio encima del coche; 4. con metal duro o diamante el surco entra en
## la chapa (más hondo que con queratina) y el tigre la raja; 5. la aleta de plástico se atraviesa antes que la chapa;
## 6. más fuerza de agarre nunca rompe menos garras (y la banda envuelve el valor); 7. una garra de vidrio se parte a menor
## velocidad que una de acero con la misma punta; 8. una garra rota nunca sube el anclaje; 9. cada material del selector da
## una física distinta de la queratina; 10. los hitos van en orden y la lectura de la curva interpola; 11. los textos.
extends "res://tests/case.gd"

const MC = preload("res://core/lab/moving_car.gd")
const CSM = preload("res://core/lab/car_speed_marks.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const Js = preload("res://core/shared/js.gd")

const TOP := 230.0
## Muestras cortas para los tests (la curva de verdad lleva SAMPLES y BAND_SAMPLES).
const N := 12
const NB := 6
const CARS := ["coche", "cocheclasico", "cochealu"]


static func C(id: String) -> Dictionary:
	return ClawsV2.apply(Catalog.find_by_id(Catalog.CLAWS, id))


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## El material para el motor: su id si es de Data.INLAYS, o la entrada entera (el rubí y la alúmina de la 2.0).
static func I(id: String) -> Variant:
	if MC.inlay_of({ "inlay": id }) != null:
		return id
	return Catalog.find_by_id(Catalog.INLAYS, id)


static func scen_of(claw: String, car: String, zone: String, inlay := "none", extra := {}) -> Dictionary:
	var p := { "claw": C(claw), "target": T(car), "zone": zone, "inlay": I(inlay) }
	p.merge(extra, true)
	return MC.setup(p)


static func curve_of(scen: Dictionary) -> Dictionary:
	return CSM.curve(scen, TOP, N, NB)


static func event(c: Dictionary, id: String) -> Dictionary:
	for e: Dictionary in c.events:
		if e.id == id:
			return e
	return {}


static func nondecreasing(xs: PackedFloat64Array, tol := 1e-6) -> bool:
	for i in range(1, xs.size()):
		if xs[i] < xs[i - 1] - tol:
			return false
	return true


# ── 1. Parado, las marcas de siempre ──


func test_parado_las_marcas_son_las_de_antes() -> void:
	for claw: String in ["aguila", "tigre", "oso", "lechuza"]:
		for mat: String in ["none", "tungsteno", "acero"]:
			var scen := scen_of(claw, "coche", "techo", mat)
			assert_true(scen.ok and scen.has("holdCtx"), "%s/%s: setup con holdCtx" % [claw, mat])
			var m := MC.marks_at_speed(scen, 0.0)
			assert_eq(m.marks.depthUm, scen.scratch.depthUm, "%s/%s: a 0 km/h en el techo, el surco de scen.scratch" % [claw, mat])
			assert_eq(m.marks.layers, scen.scratch.layers, "%s/%s: y sus capas" % [claw, mat])
			assert_eq(m.tangN, 0.0, "%s/%s: parado en el techo no tira nada de la garra" % [claw, mat])
			assert_near(m.tipN, float(scen.holdCtx.perClaw0), 1e-9, 0.0, "%s/%s: la punta solo lleva su parte del peso" % [claw, mat])
	# en un panel inclinado, parado, cada garra aprieta con su parte de la normal (el peso por cos β) y tira con la cuesta
	var capo := scen_of("oso", "coche", "capo")
	var m0 := MC.marks_at_speed(capo, 0.0)
	assert_near(m0.pressN, float(capo.holdCtx.perClaw0) * cos(deg_to_rad(10.0)), 1e-9, 0.0, "capó: la normal con la cuesta")
	assert_true(float(m0.tangN) > 0.0, "capó: la cuesta ya tira de la garra parado")
	assert_near(m0.marks.depthUm, capo.scratch.depthUm, 0.0, 0.03, "capó: las marcas, las de su peso (con la cuesta, un 2 %)")
	# asustado, parado: los desgarros de la defensa
	var scared := scen_of("lechuza", "coche", "techo", "none", { "defense": true })
	var ms := MC.marks_at_speed(scared, 0.0)
	assert_eq(ms.marks.depthUm, scared.defense.tear.depthUm, "asustada y parada: los desgarros de la defensa")
	# hold_report no arrastra el contexto interno
	var rep := MC.hold_report({ "claw": C("aguila"), "target": T("coche"), "zone": "techo" })
	assert_false(rep.setup.has("holdCtx"), "hold_report.setup sin holdCtx (como sin cases)")


# ── 2. Más carga en la punta nunca da un surco menos hondo; en crucero el tirón crece con la velocidad ──


func test_mas_velocidad_nunca_da_un_surco_menos_hondo() -> void:
	var n := 0
	var deeper := 0
	for claw: String in ["aguila", "buitre", "tigre", "oso"]:
		for car: String in CARS:
			for mat: String in ["none", "tungsteno", "acero", "vidrio", "oro"]:
				var scen := scen_of(claw, car, "techo", mat)
				var c := curve_of(scen)
				n += 1
				for which: String in ["value", "lo", "hi"]:
					var s: Dictionary = c if which == "value" else c[which]
					assert_true(nondecreasing(s.tangN), "%s/%s/%s (%s): en crucero, el tirón crece con la velocidad" % [claw, car, mat, which])
					# la sustentación puede descargar la punta (el oso de pie en el techo): lo que no baja es el surco con la carga
					for i in s.vKmh.size():
						for j in s.vKmh.size():
							if float(s.tipN[j]) >= float(s.tipN[i]):
								assert_true(float(s.depthUm[j]) >= float(s.depthUm[i]) - 1e-6, "%s/%s/%s (%s): más carga en la punta nunca da un surco menos hondo" % [claw, car, mat, which])
								assert_true(float(s.punctUm[j]) >= float(s.punctUm[i]) - 1e-6, "%s/%s/%s (%s): ni una punta menos clavada" % [claw, car, mat, which])
				if float(c.depthUm[-1]) > float(c.depthUm[0]) + 1e-6:
					deeper += 1
				# la banda envuelve el valor a cada velocidad (con todo en contra, más carga; con todo a favor, menos)
				assert_true(float(c.lo.tipN[-1]) >= float(c.tipN[-1]) - 1e-9 and float(c.hi.tipN[-1]) <= float(c.tipN[-1]) + 1e-9,
					"%s/%s/%s: la banda de la carga envuelve el valor a 230 km/h" % [claw, car, mat])
	assert_true(n >= 60, "%d curvas" % n)
	assert_true(deeper >= 6, "en %d ensayos el surco es más hondo a 230 km/h que parado (las garras reforjadas que cortan la chapa)" % deeper)
	# el águila con las alas plegadas apenas sustenta: con ella, más velocidad nunca da un surco menos hondo
	for mat: String in ["none", "tungsteno", "acero"]:
		var c := curve_of(scen_of("aguila", "coche", "techo", mat))
		assert_true(nondecreasing(c.depthUm) and nondecreasing(c.punctUm), "águila/%s: más velocidad, nunca menos surco" % mat)


# ── 3. La queratina nunca atraviesa el acero ni el aluminio ──


func test_la_queratina_nunca_atraviesa_el_metal_encima_del_coche() -> void:
	var n := 0
	var paint := float(Data.PAINT_LAYERS[-1].to)
	for claw: Dictionary in Catalog.CLAWS:
		if not MC.supports_hold(claw) or MC.is_film(claw):  # el de cine corta la chapa: ficción
			continue
		for car: String in CARS:
			for zone: String in MC.zones_for(claw):
				if MC.ZONES[zone].surface != "pintura":
					continue
				var scen := scen_of(claw.id, car, zone)
				if not scen.ok:
					continue
				for defense: bool in [false, true]:
					var s := scen if not defense else scen_of(claw.id, car, zone, "none", { "defense": true })
					if not s.ok:
						continue
					var m := MC.marks_at_speed(s, TOP, "lo")
					n += 1
					assert_false(Js.truthy(m.marks.through), "%s/%s/%s%s: la queratina no raja la chapa" % [claw.id, car, zone, " asustado" if defense else ""])
					assert_true(m.puncture == null or not Js.truthy(m.puncture.through), "%s/%s/%s: ni la atraviesa" % [claw.id, car, zone])
					assert_true(float(m.marks.depthUm) <= paint + 1e-6, "%s/%s/%s: el surco se queda en la pintura (%s µm)" % [claw.id, car, zone, m.marks.depthUm])
					assert_true(m.puncture == null or float(m.puncture.depthUm) <= paint + 1e-6, "%s/%s/%s: y la punta también" % [claw.id, car, zone])
	assert_true(n >= 60, "%d ensayos" % n)
	# y lo dice: la nota del porqué
	var c := curve_of(scen_of("oso", "coche", "techo"))
	var note := CSM.no_through_note(c, scen_of("oso", "coche", "techo"))
	assert_true(note.begins_with("La queratina (") and note.contains("más blanda que el acero de horno") and note.contains("101 HV"), note)


# ── 4. Con metal duro o diamante, el surco entra en la chapa; el tigre la raja ──


func test_con_metal_duro_o_diamante_corta_la_chapa() -> void:
	var paint := float(Data.PAINT_LAYERS[-1].to)
	for claw: String in ["aguila", "tigre", "oso", "velociraptor"]:
		var k := CSM.at(curve_of(scen_of(claw, "coche", "techo")), TOP)
		for mat: String in ["tungsteno", "diamante"]:
			var c := curve_of(scen_of(claw, "coche", "techo", mat))
			var m := CSM.at(c, TOP)
			# el águila (12-15 N en la punta) no tiene fuerza para entrar en el acero ni con diamante: se queda en la pintura
			if claw != "aguila":
				assert_true(float(m.depthUm) > paint + 1.0 or Js.truthy(m.through), "%s/%s: a 230 km/h el surco entra en la chapa (%s µm)" % [claw, mat, m.depthUm])
				assert_true(float(m.depthUm) > float(k.depthUm) or Js.truthy(m.through), "%s/%s: más hondo que la queratina" % [claw, mat])
			assert_true(float(m.punctUm) >= float(k.punctUm), "%s/%s: la punta se clava al menos lo que la queratina" % [claw, mat])
			assert_true(not event(c, "carroceria").is_empty() and event(c, "carroceria").kmh != null, "%s/%s: el hito «llega a la chapa»" % [claw, mat])
			if claw == "tigre":
				assert_true(event(c, "raja").kmh != null, "el tigre con garras de %s raja la chapa desde ~%s km/h" % [mat, event(c, "raja").kmh])
				assert_true(Js.truthy(m.through), "y a 230 km/h el surco va de lado a lado")


# ── 5. La aleta de plástico se atraviesa antes que la chapa ──


func test_la_aleta_de_plastico_se_atraviesa_antes_que_la_chapa() -> void:
	for claw: String in ["tigre", "oso"]:
		for mat: String in ["none", "tungsteno"]:
			var plastic := curve_of(scen_of(claw, "cocheplastico", "aleta", mat))
			var metal := curve_of(scen_of(claw, "coche", "aleta", mat))
			var ev := event(plastic, "raja")
			var em := event(metal, "raja")
			if em.kmh != null:
				assert_true(ev.kmh != null and float(ev.kmh) <= float(em.kmh) + 1e-9, "%s/%s: el plástico se raja antes que la chapa" % [claw, mat])
			for v: float in [0.0, 120.0, TOP]:
				var pm := CSM.at(plastic, v)
				var mm := CSM.at(metal, v)
				assert_true(float(pm.depthUm) >= float(mm.depthUm) - 1e-6, "%s/%s a %s km/h: el plástico (13 HV) se raya más hondo que el acero" % [claw, mat, v])
				assert_true(float(pm.punctUm) >= float(mm.punctUm) - 1e-6, "%s/%s a %s km/h: y la punta entra más" % [claw, mat, v])
	# el tigre con sus garras de queratina raja la aleta de plástico ya parado y nunca la chapa
	var tp := curve_of(scen_of("tigre", "cocheplastico", "aleta"))
	assert_true(event(tp, "raja").kmh != null and float(event(tp, "raja").kmh) < MC.REST_KMH, "el tigre raja el plástico desde parado")
	assert_eq(event(curve_of(scen_of("tigre", "coche", "aleta")), "raja").kmh, null, "y la chapa, nunca")


# ── 6. Más fuerza de agarre nunca rompe menos garras ──


func test_mas_fuerza_de_agarre_nunca_rompe_menos_garras() -> void:
	for claw: String in ["aguila", "tigre", "oso"]:
		for mat: String in ["none", "vidrio", "oro", "acero", "tungsteno", "cuarzo"]:
			var c := curve_of(scen_of(claw, "coche", "techo", mat))
			assert_true(nondecreasing(c.breaks), "%s/%s: una vez rotas, rotas: %s" % [claw, mat, c.breaks])
			var broken := 0
			for m: Dictionary in c.samples:
				assert_true(int(m.clawsBroken) >= broken, "%s/%s: nunca menos garras rotas con más velocidad" % [claw, mat])
				broken = m.clawsBroken
				assert_eq(int(m.clawsBroken), int(m.claws) if Js.truthy(m.fracture.fails) else 0, "%s/%s: se rompen todas a la vez (van igual de cargadas)" % [claw, mat])
			var br: Variant = c.breakAt
			if br != null and br.kmh != null:
				if br.minKmh != null:
					assert_true(float(br.minKmh) <= float(br.kmh) + 1e-9, "%s/%s: con todo en contra se rompen antes (%s ≤ %s)" % [claw, mat, br.minKmh, br.kmh])
				if br.maxKmh != null:
					assert_true(float(br.maxKmh) >= float(br.kmh) - 1e-9, "%s/%s: con todo a favor, después" % [claw, mat])
	# la carga de lado de una garra que solo ara la pintura no pasa de lo que resiste la pintura delante de ella (plough_n)
	var s := scen_of("oso", "coche", "techo")
	var m := CSM.sample(s, TOP)
	var fr: Dictionary = m.fracture
	assert_true(float(fr.lateralN) <= float(m.tangN) + 1e-9, "el tirón que llega a la garra no pasa de su parte")
	assert_true(fr.ploughN != null and float(fr.lateralN) <= float(fr.ploughN) + 1e-9, "ni de lo que ara: %s N de %s N" % [fr.lateralN, fr.ploughN])
	# clavada en la chapa, sí recibe toda su parte
	var e := scen_of("aguila", "coche", "techo", "tungsteno", { "embedded": true })
	var me := CSM.sample(e, TOP)
	assert_near(me.fracture.lateralN, me.tangN, 1e-9, 0.0, "clavada, el borde del agujero le pasa todo el tirón")


# ── 7. El vidrio se parte antes que el acero con la misma punta ──


func test_una_garra_de_vidrio_se_parte_antes_que_una_de_acero() -> void:
	for claw: String in ["aguila", "tigre", "oso"]:
		var glass: Variant = curve_of(scen_of(claw, "coche", "techo", "vidrio")).breakAt
		var steel: Variant = curve_of(scen_of(claw, "coche", "techo", "acero")).breakAt
		assert_true(glass != null and glass.kmh != null, "%s: la garra de vidrio se rompe en el deslizador" % claw)
		if steel != null and steel.kmh != null:
			assert_true(float(glass.kmh) < float(steel.kmh), "%s: el vidrio (%s) antes que el acero (%s)" % [claw, glass.kmh, steel.kmh])
		assert_eq(glass.behavior, "fragil", "%s: el vidrio es frágil" % claw)
		assert_true(glass.mode == "mella" or glass.mode == "parte", "%s: se mella o se parte" % claw)
		if steel != null:
			assert_eq(steel.behavior, "ductil", "%s: el acero es dúctil" % claw)
	# cada comportamiento: la queratina natural se astilla, el oro se dobla, la hematites no se predice
	var k: Dictionary = CSM.sample(scen_of("tigre", "coche", "techo"), TOP).fracture
	assert_eq([k.behavior, k.material], ["fragil", "none"], "la queratina natural es frágil")
	assert_true(k.mode == "mella" or k.mode == "parte" or k.mode == "intacta", "se astilla o aguanta")
	var g: Dictionary = CSM.sample(scen_of("tigre", "coche", "techo", "oro"), TOP).fracture
	assert_true(g.behavior == "ductil" and (g.mode == "dobla" or g.mode == "intacta"), "el oro se dobla o aguanta")
	var h: Dictionary = CSM.sample(scen_of("tigre", "coche", "techo", "hematites"), TOP).fracture
	assert_eq([h.mode, h.verdict], ["sin_datos", "SIN DATOS DE ROTURA"], "la hematites, sin medición")


# ── 8. Una garra rota nunca sube el anclaje ──


func test_una_garra_rota_nunca_sube_el_anclaje() -> void:
	for claw: String in ["aguila", "tigre", "oso"]:
		for mat: String in ["none", "vidrio", "tungsteno"]:
			for extra: Dictionary in [{}, { "embedded": true }, { "defense": true }]:
				var scen := scen_of(claw, "coche", "techo", mat, extra)
				if not scen.ok:
					continue
				var c := curve_of(scen)
				for m: Dictionary in c.samples:
					if Js.truthy(m.holdsAfter):
						assert_true(Js.truthy(m.holds), "%s/%s/%s: si aguanta sin las garras, aguantaba con ellas" % [claw, mat, extra])
					if not Js.truthy(m.fracture.fails):
						assert_false(Js.truthy(m.anchorLost), "%s/%s/%s: sin rotura no se pierde nada" % [claw, mat, extra])
				var dk: float = c.detach.kmh if c.detach.atRest else INF
				assert_true(float(c.detachKmh) <= dk + 1e-9, "%s/%s/%s: el despegue contando la rotura nunca llega después" % [claw, mat, extra])
	# el águila con talones de vidrio clavados: se parten enseguida, el anclaje de las garras se pierde y el despegue es el de
	# la rotura (sin ellas, solo la fricción de su peso)
	var e := scen_of("aguila", "coche", "techo", "vidrio", { "embedded": true })
	var c := curve_of(e)
	assert_true(c.breakAt != null and c.breakAt.kmh != null, "los talones de vidrio clavados se parten")
	var first: Dictionary = {}
	for m: Dictionary in c.samples:
		if Js.truthy(m.fracture.fails):
			first = m
			break
	assert_true(Js.truthy(first.anchorLost), "y con ellos se va el anclaje")
	if not Js.truthy(first.holdsAfter):
		assert_near(c.detachKmh, float(c.breakAt.kmh), 1e-9, 0.0, "el despegue llega con la rotura")


# ── 9. Cada material del selector da una física distinta de la queratina ──


func test_cada_material_del_selector_da_una_fisica_distinta() -> void:
	var k := CSM.sample(scen_of("oso", "coche", "techo"), 150.0)
	var n := 0
	for i: Dictionary in Catalog.INLAYS:
		if i.id == "none":
			continue
		n += 1
		var m := CSM.sample(scen_of("oso", "coche", "techo", i.id), 150.0)
		var fk: Dictionary = k.fracture
		var fm: Dictionary = m.fracture
		var differs: bool = float(m.marks.depthUm) != float(k.marks.depthUm) or float(m.puncture.depthUm) != float(k.puncture.depthUm) \
			or fm.mode != fk.mode or fm.limitN != fk.limitN or fm.behavior != fk.behavior or float(m.clawHardnessMPa) != float(k.clawHardnessMPa)
		assert_true(differs, "%s: dureza, perforación o rotura distintas de la queratina" % i.id)
		assert_eq(fm.material, i.id, "%s: la rotura es la de su material" % i.id)
	assert_true(n >= 14, "%d materiales del selector" % n)


# ── 10. Los hitos en orden y la lectura de la curva ──


func test_los_hitos_van_en_orden_y_la_curva_se_lee_a_cualquier_velocidad() -> void:
	var scen := scen_of("oso", "coche", "techo", "tungsteno")
	var c := curve_of(scen)
	var ids := ["barniz", "color", "imprimacion", "anticorrosivo", "carroceria", "atraviesa", "raja", "rompe", "suelta"]
	var seen: Array = []
	for e: Dictionary in c.events:
		seen.append(e.id)
	assert_eq(seen, ids, "los hitos, en su orden")
	var last := -1.0
	for id: String in ["barniz", "color", "imprimacion", "anticorrosivo", "carroceria"]:
		var e := event(c, id)
		if e.kmh != null:
			assert_true(float(e.kmh) >= last, "%s no llega antes que la capa de encima" % id)
			last = e.kmh
	assert_eq(event(c, "suelta").kmh, null, "el oso con tungsteno no se suelta en el deslizador (%s km/h)" % c.detach.kmh)
	# la lectura: en una muestra, sus valores; entre dos, entre las dos
	var vs: PackedFloat64Array = c.vKmh
	for i in vs.size():
		var m := CSM.at(c, vs[i])
		assert_near(m.depthUm, float(c.depthUm[i]), 1e-9, 0.0, "en la muestra %d, su hondura" % i)
		assert_near(m.tipN, float(c.tipN[i]), 1e-9, 0.0, "y su carga")
	var mid := CSM.at(c, 0.5 * (vs[3] + vs[4]))
	assert_true(float(mid.depthUm) >= minf(c.depthUm[3], c.depthUm[4]) and float(mid.depthUm) <= maxf(c.depthUm[3], c.depthUm[4]), "entre dos muestras, entre las dos")
	assert_eq(mid.layers, MC.layers_crossed(T("coche"), mid.depthUm), "las capas, de la hondura interpolada")
	assert_eq(mid.marks.lengthMm, float(scen.holdCtx.slideMm), "el largo del surco, el del panel")
	assert_true(CSM.at({}, 10.0).is_empty(), "sin curva, nada")
	# la banda de todo en contra
	assert_true(c.lo.vKmh.size() == NB and c.hi.vKmh.size() == NB and c.vKmh.size() == N, "las muestras pedidas")


# ── 11. Los textos ──


func test_los_textos() -> void:
	var oso := scen_of("oso", "coche", "techo")
	var c := curve_of(oso)
	var m := CSM.at(c, 120.0)
	var txt := CSM.marks_txt(m, T("coche"))
	assert_true(txt.begins_with("raya hasta a la chapa") or txt.begins_with("raya hasta"), txt)
	assert_true(CSM.load_txt(m).begins_with("~") and CSM.load_txt(m).contains("aprieta") and CSM.load_txt(m).contains("tira"), CSM.load_txt(m))
	var b := CSM.break_txt(c, c.detachKmh)
	assert_true(b != "" and not b.contains("null") and not b.contains("inf"), b)
	for mat: String in ["vidrio", "tungsteno", "hematites", "oro"]:
		var s := scen_of("tigre", "coche", "techo", mat)
		var cm := curve_of(s)
		var bt := CSM.break_txt(cm, cm.detachKmh)
		assert_true(bt != "" and not bt.contains("null"), "%s: %s" % [mat, bt])
		var note := CSM.no_through_note(cm, s)
		assert_false(note.contains("null") or note.contains("_"), "%s: %s" % [mat, note])
	var h := curve_of(scen_of("tigre", "coche", "techo", "hematites"))
	assert_true(CSM.break_txt(h).begins_with("sin medición"), CSM.break_txt(h))
	var g := curve_of(scen_of("tigre", "coche", "techo", "vidrio"))
	assert_true(CSM.break_txt(g, g.detachKmh).contains("strass") and CSM.break_txt(g, g.detachKmh).contains("km/h"), CSM.break_txt(g, g.detachKmh))
	# la alúmina y el rubí de la reforja también tienen nombre
	var r := curve_of(scen_of("tigre", "coche", "techo", "rubi"))
	assert_true(CSM.break_txt(r).contains("rubí"), CSM.break_txt(r))
