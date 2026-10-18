## Unidad 4j en el motor del coche en marcha (core/lab/moving_car.gd): la cinemática del golpe (kinematics: las componentes
## de la velocidad del animal respecto al coche y el vuelo antes de tocar el panel) y la banda del golpe (impact_band: el
## mismo golpe con todos los datos a favor del coche y con todos en contra). Se comprueba:
##   - que kinematics() da las velocidades de impact() (y lo mismo sola que dentro del golpe), con el vuelo de la caída
##     libre, √(2·h/g), y el del salto de un velocirraptor tal cual (leap.timeS, leap.ux/uy/uz: no se recalcula);
##   - invariantes del vuelo: más caída, más tiempo en el aire y más velocidad al llegar;
##   - que el caso central de la banda reproduce impact() exactamente (las mismas cuentas, sin copiar números);
##   - el orden de la banda: la pintura más dura no deja marcas más hondas; con menos fricción resbala y raja más; lo que no
##     tiene banda (la masa y la velocidad de un tigre o un águila) no cambia entre los extremos, salvo la abolladura del capó,
##     que se mueve con su hueco (unidad 4o: 20-100 mm) y no pasa de él; perforar con todo a favor implica perforar con todo
##     en contra;
##   - que su fuente se lee: los datos que se mueven, con autor y año, y los que no tienen banda.
extends "res://tests/case.gd"

const MC = preload("res://core/lab/moving_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Js = preload("res://core/shared/js.gd")

var _cache: Array = []


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Golpes de todos los animales en todas sus zonas del coche moderno y en la aleta de plástico, con dos saltos distintos, de
## queratina, asustados y con garras de zafiro afiladas: [[p, impact(p)]] de los que llegan (ok), calculados una vez.
func battery() -> Array:
	if not _cache.is_empty():
		return _cache
	var combos := [[50.0, 40.0, 90.0, 0.5], [90.0, 60.0, 0.0, 0.2]]
	var extras := [{}, { "defense": true }, { "inlay": "zafiro", "sharpness": 0.6 }]
	for id: String in MC.BODIES:
		var places: Array = []
		for z: String in MC.impact_zones_for(C(id)):
			places.append(["coche", z])
		if MC.impact_zones_for(C(id)).has("aleta"):
			places.append(["cocheplastico", "aleta"])
		for pl: Array in places:
			for k: Array in combos:
				for ex: Dictionary in extras:
					var p := { "claw": C(id), "target": T(pl[0]), "zone": pl[1], "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2],
						"drop_m": k[3] }
					p.merge(ex)
					var r := MC.impact(p)
					if Js.truthy(r.get("ok")):
						_cache.append([p, r])
	return _cache


static func tag(p: Dictionary) -> String:
	return "%s %s %s %s/%s/%s/%s %s" % [p.claw.id, p.target.id, p.zone, p.v_kmh, p.animal_kmh, p.angle_deg, p.drop_m,
		"asustado" if p.get("defense", false) else String(p.get("inlay", "queratina"))]


func test_la_bateria_cubre_lo_que_hay() -> void:
	var b := battery()
	assert_true(b.size() > 200, "golpes de la batería: %d" % b.size())
	for id: String in MC.BODIES:
		assert_true(b.any(func(x: Array) -> bool: return x[0].claw.id == id), "%s golpea en la batería" % id)
	assert_true(b.any(func(x: Array) -> bool: return x[1].get("tear") != null), "con desgarro del plástico")
	assert_true(b.any(func(x: Array) -> bool: return x[1].get("leap") != null), "con el salto de un velocirraptor")
	assert_true(b.any(func(x: Array) -> bool: return x[1].get("kick") != null), "con la patada del casuario")


func test_la_cinematica_es_la_del_golpe() -> void:
	for x: Array in battery():
		var p: Dictionary = x[0]
		var r: Dictionary = x[1]
		var k: Dictionary = r.kinematics
		var t := tag(p)
		assert_true(k.ok, "%s: con cinemática" % t)
		assert_true(same(k, MC.kinematics(p)), "%s: la misma sola que dentro del golpe" % t)
		assert_near(float(k.relAbsKmh), float(r.vRelKmh), 1e-12, 1e-9, "%s: el módulo es la velocidad relativa del golpe" % t)
		assert_near(float(k.normalKmh), float(r.vNormalKmh), 1e-12, 1e-9, "%s: contra el panel" % t)
		assert_near(float(k.tangKmh), float(r.vTangKmh), 1e-12, 1e-9, "%s: a lo largo" % t)
		var rel: Dictionary = k.relKmh
		var mod := sqrt(float(rel.x) * float(rel.x) + float(rel.y) * float(rel.y) + float(rel.z) * float(rel.z))
		assert_near(mod, float(k.relAbsKmh), 1e-9, 1e-9, "%s: las componentes suman el módulo" % t)
		assert_eq(String(k.quality), "", "%s: es una cuenta, no un dato" % t)
		var vc := float(p.v_kmh) / MC.KMH
		var lp: Variant = r.get("leap")
		var side: bool = MC.IMPACT_ZONES[p.zone].normal == "lado"
		if lp != null:
			# el velocirraptor: su salto tal cual (leap_block), sin recalcularlo
			assert_eq(float(k.flightS), float(lp.timeS), "%s: el tiempo de su salto" % t)
			assert_eq([float(rel.x), float(rel.y), float(rel.z)], [(float(lp.ux) - vc) * MC.KMH, float(lp.uy) * MC.KMH, float(lp.uz) * MC.KMH],
				"%s: las componentes de su salto" % t)
		elif side or r.get("kick") != null:
			assert_eq([float(k.flightS), float(k.dropM), float(k.carFlightM)], [0.0, 0.0, 0.0], "%s: en un costado o en la patada no vuela" % t)
		else:
			var h := float(p.drop_m)
			assert_near(float(k.flightS), sqrt(2.0 * h / MC.G), 1e-12, 1e-12, "%s: cae desde %s m en √(2·h/g)" % [t, h])
			assert_near(float(k.fallKmh), sqrt(2.0 * MC.G * h) * MC.KMH, 1e-12, 1e-12, "%s: y llega a √(2·g·h)" % t)
			assert_near(float(k.carFlightM), vc * float(k.flightS), 1e-12, 1e-12, "%s: el coche avanza v·t" % t)
			assert_near(float(rel.z), -float(k.fallKmh), 1e-12, 1e-12, "%s: la componente vertical es la de la caída" % t)


## Más caída, más vuelo y más velocidad de bajada; sin caída, sin vuelo.
func test_mas_caida_mas_vuelo() -> void:
	var prev := -1.0
	var prev_v := -1.0
	for h: float in [0.0, 0.1, 0.3, 0.5, 1.0, 2.0]:
		var k := MC.kinematics({ "claw": C("tigre"), "target": T("coche"), "zone": "techo", "v_kmh": 50.0, "animal_kmh": 40.0,
			"angle_deg": 90.0, "drop_m": h })
		assert_true(float(k.flightS) > prev or (h == 0.0 and float(k.flightS) == 0.0), "a %s m, más vuelo (%s s)" % [h, k.flightS])
		assert_true(float(k.fallKmh) > prev_v or h == 0.0, "y más velocidad de bajada")
		prev = float(k.flightS)
		prev_v = float(k.fallKmh)
	var side := MC.kinematics({ "claw": C("tigre"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0,
		"angle_deg": 90.0, "drop_m": 2.0 })
	assert_eq(float(side.flightS), 0.0, "contra la puerta no cae")
	var no := MC.kinematics({ "claw": C("gato"), "target": T("coche"), "zone": "techo" })
	assert_false(no.ok, "sin datos del animal, sin cinemática")


func test_el_caso_central_de_la_banda_es_el_golpe() -> void:
	for x: Array in battery():
		var p: Dictionary = x[0]
		var r: Dictionary = x[1]
		var ctx := MC._band_ctx(p, r)
		var k := MC._band_knobs(ctx, "value")
		k.mu = float(r.mu)
		var got := MC._band_case(ctx, k, null, null)
		var d := oracle_diff(got, MC.band_point(r), tag(p))
		assert_eq(d.size(), 0, "%s: las cuentas de la banda reproducen impact() %s" % [tag(p), d])


func test_el_orden_de_la_banda() -> void:
	for x: Array in battery():
		var p: Dictionary = x[0]
		var r: Dictionary = x[1]
		var b: Dictionary = r.band
		var mid := MC.band_point(r)
		var lo: Dictionary = b.lo
		var hi: Dictionary = b.hi
		var t := tag(p)
		var kick: bool = r.get("kick") != null
		var leap: bool = r.get("leap") != null
		assert_eq(String(b.quality), "estimate", "%s: la banda es una estimación" % t)
		for key: String in ["marksDepthUm", "marksLengthMm", "normalJ", "slideM"]:
			var v: Dictionary = b[key]
			assert_true(float(v.min) <= float(v.value) and float(v.value) <= float(v.max), "%s: %s contiene el central" % [t, key])
		if kick:
			continue  # la patada: la pata más débil empuja menos pero dura más (t = μ_red·v/F), y su surco no va en orden
		# la pintura más dura nunca deja marcas más hondas
		assert_true(float(lo.marksDepthUm) <= float(mid.marksDepthUm) + 1e-9, "%s: con la pintura más dura, no más hondas" % t)
		# con menos fricción (y, en un salto, más velocidad) resbala y raja más; con más, menos
		assert_true(float(lo.slideM) <= float(mid.slideM) + 1e-12 and float(mid.slideM) <= float(hi.slideM) + 1e-12,
			"%s: resbala %s ≤ %s ≤ %s" % [t, lo.slideM, mid.slideM, hi.slideM])
		if mid.tearMm != null and lo.tearMm != null and hi.tearMm != null:
			assert_true(float(lo.tearMm) <= float(mid.tearMm) + 1e-9 and float(mid.tearMm) <= float(hi.tearMm) + 1e-9, "%s: raja más con todo en contra" % t)
		# perforar con todo a favor del coche implica perforar con todo en contra
		assert_true(not lo.through or hi.through, "%s: perfora con todo a favor y no en contra" % t)
		var gap: Variant = MC.CLEARANCE_BAND.get(String(p.zone))
		if gap != null and mid.dentMm != null:
			# unidad 4o: el hueco bajo el capó tiene banda (20-100 mm): cada extremo no pasa de su hueco
			assert_true(float(lo.dentMm) <= float(gap.min) + 1e-9, "%s: con el hueco más pequeño, como mucho su hueco" % t)
			assert_true(float(hi.dentMm) <= float(gap.max) + 1e-9, "%s: con el mayor, como mucho su hueco" % t)
		if not leap:
			# sin banda de su masa ni de su velocidad, la energía contra el panel, la punción y la abolladura no cambian (la
			# abolladura sí en el capó, con su hueco: unidad 4o)
			assert_eq([float(lo.normalJ), float(hi.normalJ)], [float(mid.normalJ), float(mid.normalJ)], "%s: la energía normal" % t)
			assert_eq([lo.through, hi.through], [mid.through, mid.through], "%s: la punción" % t)
			if gap == null:
				assert_eq([lo.dentMm, hi.dentMm], [mid.dentMm, mid.dentMm], "%s: la abolladura" % t)
		else:
			# el salto más favorable llega más deprisa: más energía contra el panel
			assert_true(float(hi.normalJ) >= float(mid.normalJ), "%s: el salto más fuerte golpea más" % t)


## La pintura más dura de la banda (425 MPa, Vodnick 2006) solo cambia la pintura: la queratina, que raya el barniz del motor
## (20 HV), ya no llega a 0,8 veces la dureza del más duro y no lo raya.
func test_la_pintura_mas_dura() -> void:
	var car := T("coche")
	var hard := MC._harder_paint(car)
	assert_near(float(hard.hv) * MC.Contact.HV_MPA, float(MC.PLOUGH.paint_h_max_mpa), 1e-12, 1e-9, "la dureza del barniz más duro")
	assert_eq(hard.body, car.body, "la chapa no cambia")
	assert_eq(float(car.hv) * MC.Contact.HV_MPA < float(MC.PLOUGH.paint_h_max_mpa), true, "el barniz del motor es más blando")
	var r := MC.impact({ "claw": C("tigre"), "target": car, "zone": "techo", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 0.0, "drop_m": 0.5 })
	assert_true(int(r.marks.count) > 0, "la queratina raya el barniz del motor")
	assert_eq(float(r.band.lo.marksDepthUm), 0.0, "y no el más duro")
	assert_eq(float(r.band.marksDepthUm.min), 0.0, "la banda de las marcas empieza en cero")


func test_la_fuente_de_la_banda_se_lee() -> void:
	var seen := {}
	for x: Array in battery():
		var r: Dictionary = x[1]
		var b: Dictionary = r.band
		var src := String(b.source)
		assert_true(src.begins_with("Todo a favor del coche y todo en contra"), src)
		assert_true(src.contains("Roderick et al. 2019") and src.contains("Derler & Gerhardt 2012"), "la fricción, con sus fuentes: %s" % src)
		for bad: String in ["docs/", ".gd", "MovingCar", "Physics.", "§", "FRICTION", "PLOUGH", "KICK"]:
			assert_false(src.contains(bad), "sin «%s»: %s" % [bad, src])
		for v: String in b.varies:
			seen[v] = true
		if r.get("kick") != null:
			assert_true(b.varies.has("casuario") and src.contains("Portugal et al. 2016"), "el casuario: su masa y su pata")
		if r.get("leap") != null:
			assert_true(b.varies.has("salto") and src.contains("Sellers & Manning 2007"), "el velocirraptor: su salto y su carrera")
		if r.get("tear") != null:
			assert_true(b.varies.has("plastico") and src.contains("SABIC 2024"), "el plástico: su tenacidad")
		if r.get("dent") != null and r.dent.applies:
			assert_true(b.fixed.has("pata") and src.contains("Sin banda: la rigidez de la pata"), "lo que no tiene banda, dicho")
			# unidad 4o: el hueco, con banda en el capó (Fredriksson et al. 2007) y, en el resto, dicho por qué no
			if MC.CLEARANCE_BAND.has(String(x[0].zone)):
				assert_true(b.varies.has("hueco") and src.contains("Fredriksson et al. 2007"), "el hueco bajo el capó, con su banda: %s" % src)
			else:
				assert_true(b.fixed.has("hueco") and src.contains("sin medición"), "el hueco sin banda, y por qué: %s" % src)
	assert_eq(seen.keys().size(), 8, "se mueven la fricción, la pintura, el plástico, la defensa, el casuario, el salto, el templado de la ventanilla (unidad 4m) y el hueco bajo el capó (unidad 4o): %s" % [seen.keys()])
