## Coche en marcha (core/lab/moving_car.gd): datos de referencia reproducidos (densidad del aire, área frontal de
## Pennycuick, Cd de Tucker, CL de Tucker & Heine, superficies alares medidas, Cp del DrivAer), invariantes («la
## resistencia crece con v²», «con las alas abiertas se suelta antes», «más agarre nunca se suelta antes», «frenar
## fuerte nunca ayuda a quedarse delante», «la queratina nunca perfora el acero del coche»…), el golpe al abalanzarse
## (con la abolladura y el parabrisas de la unidad 1f) y los casos de referencia de la integración
## (tests/fixtures/spec/coche-en-marcha.json), comprobados contra MovingCar.hold_report y MovingCar.impact.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Dent = preload("res://core/lab/dent.gd")
const MC = preload("res://core/lab/moving_car.gd")
const CF = preload("res://core/lab/claw_fracture.gd")
const Contact = preload("res://core/shared/contact.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Js = preload("res://core/shared/js.gd")

const SPEC := "res://tests/fixtures/spec/coche-en-marcha.json"
const RAPTORS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const MAMMALS := ["tigre", "oso"]
const METAL_CARS := ["coche", "cocheclasico", "cochealu"]
const PAINT_UM := 110.0


static func C(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Data.find_by_id(Data.TARGETS, id)


static func scen(claw_id: String, zone: String, posture: String, over: Dictionary = {}) -> Dictionary:
	var p := { "claw": C(claw_id), "target": T("coche"), "zone": zone, "posture": posture }
	p.merge(over, true)
	return MC.setup(p)


static func animals() -> Array:
	return RAPTORS + MAMMALS


# ── Datos de referencia ──

func test_densidad_del_aire_de_la_ley_de_los_gases() -> void:
	# ρ = p/(R·T): 101 325 Pa, aire seco 287,05 J/(kg·K), 20 °C
	assert_near(MC.RHO_AIR, 101325.0 / (287.05 * 293.15), 0.001, 0.0, "1,204 kg/m³")


func test_atmosfera_tipo_y_densidad_con_la_temperatura_y_la_altitud() -> void:
	# presiones de la atmósfera tipo (ISO 2533): 89 875 Pa a 1000 m, 79 495 a 2000 y 70 108 a 3000
	assert_eq(MC.air_pressure_pa(0.0), 101325.0, "nivel del mar")
	assert_near(MC.air_pressure_pa(1000.0), 89875.0, 0.0005, 0.0, "1000 m")
	assert_near(MC.air_pressure_pa(2000.0), 79495.0, 0.0005, 0.0, "2000 m")
	assert_near(MC.air_pressure_pa(3000.0), 70108.0, 0.0005, 0.0, "3000 m")
	assert_eq(MC.air_density(20.0, 0.0), MC.RHO_AIR, "20 °C al nivel del mar: la densidad de referencia")
	assert_near(MC.air_density(0.0, 0.0), 101325.0 / (287.05 * 273.15), 1e-12, 0.0, "0 °C: ρ = p/(R·T)")
	# más calor o más altura, aire menos denso
	var prev := INF
	for t: float in [-20.0, 0.0, 20.0, 35.0, 45.0]:
		var r := MC.air_density(t, 0.0)
		assert_true(r < prev, "a %s °C, menos denso que con menos calor" % t)
		prev = r
	prev = INF
	for h: float in [0.0, 500.0, 1000.0, 2000.0, 3000.0]:
		var r := MC.air_density(20.0, h)
		assert_true(r < prev, "a %s m, menos denso que más abajo" % h)
		prev = r
	var air := MC.air_of(35.0, 0.0)
	assert_near(air.speedFactor, sqrt(MC.RHO_AIR / air.rho), 1e-12, 0.0, "factor de velocidad")
	assert_true(String(MC.air_txt(air)).contains("menos denso"), MC.air_txt(air))
	assert_true(String(MC.air_txt(MC.air_of(20.0, 0.0))).contains("como a 20 °C"), "la referencia")


func test_mas_calor_o_mas_altura_despega_a_mas_velocidad() -> void:
	# sin viento, el aire solo entra como ρ·v²: la velocidad de despegue escala exactamente con √(ρ_ref/ρ)
	var hot := MC.air_density(35.0, 0.0)
	var cold := MC.air_density(0.0, 0.0)
	var high := MC.air_density(20.0, 2000.0)
	for id: String in animals():
		for zone: String in MC.zones_for(C(id)):
			for post: String in MC.POSTURES[MC.BODIES[id].kind]:
				var tag := "%s %s %s" % [id, zone, post]
				var d20: float = MC.detach(scen(id, zone, post)).kmh
				var d0: float = MC.detach(scen(id, zone, post, { "temp_c": 0.0 })).kmh
				var d35: float = MC.detach(scen(id, zone, post, { "temp_c": 35.0 })).kmh
				var dh: float = MC.detach(scen(id, zone, post, { "altitude_m": 2000.0 })).kmh
				assert_true(d0 <= d20 + 1e-6 and d20 <= d35 + 1e-6, "%s: con más calor, nunca antes (%s ≤ %s ≤ %s)" % [tag, d0, d20, d35])
				assert_true(d20 <= dh + 1e-6, "%s: a 2000 m, nunca antes" % tag)
				for pair: Array in [[d35, hot], [d0, cold], [dh, high]]:
					var want := d20 * sqrt(MC.RHO_AIR / float(pair[1]))
					if is_finite(d20) and d20 > 0.0 and want < MC.SCAN_MAX_KMH - 5.0:
						assert_near(float(pair[0]), want, 1e-6, 1e-6, "%s: v ∝ 1/√ρ" % tag)


func test_cambiar_el_aire_sin_repetir_el_ensayo() -> void:
	# with_air da lo mismo que preparar el ensayo con ese aire (sin volver a llamar a compute)
	for id: String in ["aguila", "tigre"]:
		var base := scen(id, "techo", MC.POSTURES[MC.BODIES[id].kind][0], { "crosswind_kmh": 20.0, "accel_g": -0.2 })
		var direct := scen(id, "techo", MC.POSTURES[MC.BODIES[id].kind][0], { "crosswind_kmh": 20.0, "accel_g": -0.2, "temp_c": 35.0, "altitude_m": 2000.0 })
		var moved := MC.with_air(base, 35.0, 2000.0)
		assert_true(same(MC.at_speed(moved, 110.0), MC.at_speed(direct, 110.0)), "%s: mismas fuerzas" % id)
		assert_true(same(MC.detach(moved), MC.detach(direct)), "%s: mismo despegue" % id)
		assert_eq(float(base.rho), MC.RHO_AIR, "%s: el ensayo de partida no cambia" % id)
	var r := MC.hold_report({ "claw": C("aguila"), "target": T("coche"), "zone": "techo", "posture": "plegadas", "altitude_m": 2000.0 })
	assert_true(r.detach.kmh > r.detachRef.kmh, "a 2000 m se suelta más tarde que al nivel del mar")


func test_area_frontal_de_pennycuick() -> void:
	# S_b = 0,00813·m^0,666 (Pennycuick et al. 1988): águila de 5 kg ≈ 0,0237 m²
	assert_near(MC.bird_frontal_m2(5.0), 0.00813 * pow(5.0, 0.666), 1e-12, 0.0, "fórmula")
	assert_near(MC.bird_frontal_m2(5.0), 0.02375, 0.001, 0.0, "águila de 5 kg")
	assert_near(MC.bird_frontal_m2(1.0), 0.00813, 1e-12, 0.0, "1 kg: el coeficiente")


func test_cd_del_cuerpo_y_cl_de_las_fuentes() -> void:
	var a: Dictionary = MC.BIRD_AERO
	assert_eq(a.cd_body.min, 0.24, "Cd mínimo: el cuerpo de halcón peregrino de Tucker (1990)")
	assert_true(a.cd_body.value >= 0.25 and a.cd_body.value <= 0.4, "Cd central del orden de Pennycuick (0,25-0,39)")
	assert_eq(a.wing.sustenta.cl, 1.6, "CL máximo del busardo de Harris (Tucker & Heine 1990)")
	assert_true(a.wing.frena.cd > a.wing.sustenta.cd, "el ala en pérdida frena más que la que sustenta")


func test_superficies_alares_de_las_fuentes() -> void:
	# medidas (Alerstam 2007; Johnson 1997; Harel 2016) y escaladas isométricamente a la masa del catálogo
	var want := {
		"aguila": 0.597 * pow(5.0 / 4.069, 2.0 / 3.0), "halcon": 0.1257 * pow(1.0 / 0.789, 2.0 / 3.0),
		"buho": 0.3161 * pow(2.0 / 1.345, 2.0 / 3.0), "buitre": 8.0 / 9.0,
	}
	for id: String in want:
		assert_near(MC.BODIES[id].wing_m2.value, want[id], 0.005, 0.0, "%s: superficie alar" % id)
	var owl: Dictionary = MC.BODIES.lechuza.wing_m2
	assert_true(owl.value >= 0.1979 * pow(0.35 / 0.529, 2.0 / 3.0) - 1e-3 and owl.value <= 0.1698 * pow(0.35 / 0.38, 2.0 / 3.0) + 1e-3, "lechuza entre hembras y macho escalados")
	for id: String in MC.BODIES:
		var b: Dictionary = MC.BODIES[id]
		if b.kind == "ave":
			assert_true(b.wing_m2.min <= b.wing_m2.value and b.wing_m2.value <= b.wing_m2.max, "%s: banda alar" % id)
			assert_true(["primary", "secondary", "estimate"].has(b.wing_m2.quality), "%s: calidad" % id)


func test_cp_del_techo_contiene_las_tomas_medidas_del_drivaer() -> void:
	var cp: Dictionary = MC.ZONES.techo.cp
	# tomas del techo (fuera del eje): fastback −0,64…−0,40; notchback −0,61…−0,36; estate −0,58…−0,30
	for measured: float in [-0.643, -0.401, -0.613, -0.358, -0.583, -0.298]:
		assert_true(cp.min <= measured + 0.005 and measured - 0.005 <= cp.max, "Cp %s dentro de la banda" % measured)
	assert_near(cp.value, (-0.47 - 0.50 - 0.38) / 3.0, 0.02, 0.0, "media de las tres carrocerías")
	for id: String in MC.ZONES:
		var z: Dictionary = MC.ZONES[id]
		assert_true(z.cp.min <= z.cp.value and z.cp.value <= z.cp.max, "%s: banda de Cp" % id)
		assert_true(String(z.cp.source).length() > 20, "%s: fuente del Cp" % id)


func test_la_velocidad_local_no_es_la_del_coche() -> void:
	assert_near(MC.local_factor(-0.45), sqrt(1.45), 1e-12, 0.0, "techo: √(1 − Cp)")
	assert_true(MC.local_factor(MC.ZONES.techo.cp.value) > 1.15, "en el techo el aire va ~20 % más rápido")
	assert_true(MC.local_factor(MC.ZONES.limpiaparabrisas.cp.value) < 1.0, "al pie del parabrisas, más despacio")
	var s := scen("aguila", "techo", "plegadas")
	var a := MC.at_speed(s, 100.0)
	assert_near(a.localKmh, 100.0 * sqrt(1.45), 1e-9, 0.0, "velocidad local a 100 km/h")


func test_coche_de_referencia_drivaer() -> void:
	assert_eq(MC.CAR_REF.cd, 0.309, "Cd del DrivAer fastback medido en Loughborough")
	assert_near(MC.CAR_REF.area_m2, 0.136 * 16.0, 1e-3, 0.0, "área frontal a escala real (×4²)")


## «ficcion» (unidad 4i-B2): lo de película del velocirraptor de ficción, con su fuente (qué es de película y qué haría la
## garra de verdad).
static func has_source(d: Variant) -> bool:
	return d is Dictionary and d.has("quality") and d.has("source") and String(d.source).length() > 20 and (
		["primary", "secondary", "estimate", "dibujo", "ficcion"].has(String(d.quality)))


func test_cada_dato_del_coche_en_marcha_lleva_fuente_y_calidad() -> void:
	# unidad 4g: los datos que no llevaban fuente ni calidad (la geometría de las zonas, los cuerpos campo a campo, el ala
	# y la rigidez de la pata) la llevan ahora; una estimación dice el caso medido más parecido o la suposición
	for id: String in MC.IMPACT_ZONES:
		for f: String in ["slope_deg", "slide_m", "clearance_mm"]:
			assert_true(has_source(MC.IMPACT_ZONES[id].sources.get(f)), "zona del golpe %s: %s" % [id, f])
	for id: String in MC.ZONES:
		for f: String in ["slope_deg", "slide_m", "draw"]:
			assert_true(has_source(MC.ZONES[id].sources.get(f)), "zona %s: %s" % [id, f])
		assert_true(has_source(MC.ZONES[id].cp), "zona %s: Cp" % id)
	assert_true(String(MC.IMPACT_ZONES.capo.sources.slide_m.source).contains("Cui"), "el capó: medido en 452 frontales")
	assert_true(String(MC.IMPACT_ZONES.capo.sources.clearance_mm.source).contains("Fredriksson"), "el hueco del capó")
	assert_true(String(MC.IMPACT_ZONES.puerta.sources.clearance_mm.source).contains("FMVSS 214"), "la puerta")
	assert_true(String(MC.IMPACT_ZONES.techo.sources.clearance_mm.source).contains("FMVSS 216"), "el techo")
	# los cuerpos, campo a campo: o el campo lleva su fuente, o la lleva en sources, o cada una de sus entradas la lleva
	var skip := ["kind", "species", "attack", "hold", "quality", "source", "sources"]
	for id: String in MC.BODIES:
		var b: Dictionary = MC.BODIES[id]
		for f: String in b:
			if skip.has(f):
				continue
			var v: Variant = b[f]
			var ok := has_source(v) or has_source(b.get("sources", {}).get(f))
			if not ok and v is Dictionary:
				ok = (v as Dictionary).values().all(func(x: Variant) -> bool: return has_source(x))
			assert_true(ok, "%s.%s: con fuente y calidad" % [id, f])
		for f: String in ["height_m", "length_m"]:
			assert_eq(b.sources[f].quality, "dibujo", "%s.%s: solo para el dibujo" % [id, f])
	# el ala: la fuente del CL, del Cd y del CL con el aire por detrás, con su calidad
	for st: String in MC.BIRD_AERO.wing:
		var w: Dictionary = MC.BIRD_AERO.wing[st]
		assert_true(has_source({ "quality": w.quality, "source": w.source }), "ala %s: CL" % st)
		assert_true(has_source({ "quality": w.cd_quality, "source": w.source }), "ala %s: Cd" % st)
		assert_true(has_source({ "quality": w.cl_rev_quality, "source": w.cl_rev_source }), "ala %s: CL al revés" % st)
	assert_eq(MC.BIRD_AERO.wing.sustenta.quality, "secondary", "el CL máximo, medido")
	assert_eq(MC.BIRD_AERO.wing.sustenta.cd_quality, "estimate", "el Cd del ala, estimación")
	# la rigidez de la pata (el valor, en el motor) y el desgarro del plástico
	assert_true(has_source(MC.LIMB_STIFFNESS) and String(MC.LIMB_STIFFNESS.source).contains("Farley"), "rigidez de la pata")
	assert_eq(MC.LIMB_STIFFNESS.quality, "estimate", "estimación")
	for body_id: String in MC.PLASTIC_TEAR:
		var r: Dictionary = MC.PLASTIC_TEAR[body_id]
		assert_true(has_source(r) and String(r.source).contains("SABIC") and String(r.source).contains("Suposiciones"), "%s: tenacidad" % body_id)
		assert_true(float(r.min) <= float(r.value) and float(r.value) <= float(r.max), "%s: banda" % body_id)
	assert_eq(String(Data.CAR_BODIES.plastico.id), "plastico-carroceria", "la tenacidad es la de la aleta del catálogo")


# ── Invariantes del equilibrio ──

func test_la_resistencia_crece_con_v2() -> void:
	for id: String in animals():
		var s := scen(id, "techo", MC.POSTURES[MC.BODIES[id].kind][0])
		var d50: float = MC.at_speed(s, 50.0).dragN
		var d100: float = MC.at_speed(s, 100.0).dragN
		assert_near(d100, 4.0 * d50, 1e-9, 1e-12, "%s: el doble de velocidad, cuatro veces la resistencia" % id)
		assert_true(d50 > 0.0, "%s: hay resistencia" % id)


func test_el_viento_de_frente_suma_velocidad_relativa() -> void:
	var calm := scen("aguila", "techo", "plegadas")
	var wind := scen("aguila", "techo", "plegadas", { "wind_kmh": 20.0 })
	assert_near(MC.at_speed(wind, 80.0).dragN, MC.at_speed(calm, 100.0).dragN, 1e-9, 1e-12, "80 km/h con 20 de frente = 100 en calma")
	var tail := scen("aguila", "techo", "plegadas", { "wind_kmh": -20.0 })
	assert_true(MC.detach(wind).kmh <= MC.detach(calm).kmh + 1e-6, "con viento de frente se suelta antes")
	assert_true(MC.detach(tail).kmh >= MC.detach(calm).kmh - 1e-6, "con viento de cola, después")


func test_en_un_panel_inclinado_el_viento_aprieta_y_empuja() -> void:
	# la resistencia es horizontal: en el parabrisas (30°) aprieta al animal contra el vidrio con D·sen β y lo empuja
	# cuesta arriba con D·cos β (un tigre de pie, sin sustentación)
	var s := scen("tigre", "parabrisas", "de_pie")
	var a0 := MC.at_speed(s, 0.0)
	var a := MC.at_speed(s, 100.0)
	assert_eq(a.liftN, 0.0, "de pie, sin sustentación")
	assert_near(a.normalN - a0.normalN, a.dragN * sin(PI / 6.0), 1e-9, 1e-9, "el viento lo aprieta contra el parabrisas")
	var c: Dictionary = s.cases.nom
	var f0 := MC._eval(c, 0.0, 0.0, 0.0, 0.0, 0.0)
	var f := MC._eval(c, 100.0 / MC.KMH, 0.0, 0.0, 0.0, 0.0)
	assert_near(f.tt - f0.tt, a.dragN * cos(PI / 6.0), 1e-9, 1e-9, "y lo empuja hacia el techo")
	# la sustentación es vertical: en el capó (10°) quita apoyo con L·cos β y empuja cuesta arriba con L·sen β
	var b := scen("aguila", "capo", "abiertas")
	var fb := MC._eval(b.cases.nom, 60.0 / MC.KMH, 0.0, 0.0, 0.0, 0.0)
	var cb := cos(10.0 * PI / 180.0)
	var sb := sin(10.0 * PI / 180.0)
	assert_near(fb.rn, 5.0 * MC.G * cb + fb.dx * sb - fb.lift * cb, 1e-6, 1e-9, "normal")
	assert_near(fb.tt, fb.dx * cb + fb.lift * sb - 5.0 * MC.G * sb, 1e-6, 1e-9, "tangencial")


func test_mas_viento_lateral_nunca_retrasa_el_despegue() -> void:
	for id: String in ["aguila", "lechuza", "tigre"]:
		var post: String = MC.POSTURES[MC.BODIES[id].kind][0]
		var prev := INF
		for cw: float in [0.0, 15.0, 30.0, 45.0, 60.0]:
			var k: float = MC.detach(scen(id, "techo", post, { "crosswind_kmh": cw })).kmh
			assert_true(k <= prev + 1e-6, "%s: %s km/h de viento lateral no retrasa el despegue" % [id, cw])
			prev = k


func test_a_cero_no_hay_viento_ni_numeros_raros() -> void:
	for id: String in animals():
		for post: String in MC.POSTURES[MC.BODIES[id].kind]:
			var a := MC.at_speed(scen(id, "techo", post), 0.0)
			assert_eq(a.dragN, 0.0, "%s %s: sin aire, sin resistencia" % [id, post])
			assert_eq(a.liftN, 0.0, "%s %s: sin sustentación" % [id, post])
			assert_true(is_finite(a.needN) and is_finite(a.availN) and is_finite(a.loadRatio), "%s %s: sin NaN" % [id, post])
			assert_true(a.holds, "%s %s: parado, en el techo, se sostiene" % [id, post])
	var w := MC.at_speed(scen("aguila", "techo", "plegadas", { "wind_kmh": 30.0 }), 0.0)
	assert_true(w.dragN > 0.0, "con el coche parado, el viento sí empuja")


func test_con_las_alas_abiertas_se_suelta_antes() -> void:
	for id: String in RAPTORS:
		for zone: String in MC.zones_for(C(id)):
			var folded := MC.detach(scen(id, zone, "plegadas"))
			var open := MC.detach(scen(id, zone, "abiertas"))
			assert_true(open.kmh <= folded.kmh + 1e-6, "%s en %s: abiertas %s ≤ plegadas %s km/h" % [id, zone, open.kmh, folded.kmh])
			assert_true(open.minKmh <= folded.minKmh + 1e-6, "%s en %s: también en la banda" % [id, zone])


func test_con_las_alas_abiertas_la_rapaz_despega_como_en_vuelo() -> void:
	# sobre el techo, sin nada que agarrar: el aire la levanta cerca de su velocidad mínima de vuelo
	for id: String in RAPTORS:
		var s := scen(id, "techo", "abiertas")
		var d := MC.detach(s)
		assert_eq(d.mode, "despega", "%s: con las alas abiertas despega" % id)
		var m: float = C(id).mass
		var wing: float = MC.BODIES[id].wing_m2.value
		var v_stall := sqrt(2.0 * m * MC.G / (MC.RHO_AIR * 1.6 * wing)) * MC.KMH / MC.local_factor(s.cp)
		assert_true(d.kmh <= v_stall * 1.05, "%s: despega antes de que el ala sola lo sostenga (%s ≤ %s km/h)" % [id, d.kmh, v_stall])
		assert_true(d.kmh >= v_stall * 0.5, "%s: y no mucho antes (%s km/h)" % [id, d.kmh])


func test_con_viento_de_cola_las_alas_nunca_sustentan_mas_que_de_cara() -> void:
	# con el aire por detrás (viento de cola más fuerte que la velocidad del coche) el ala abierta recibe el aire por el
	# borde de salida y sustenta como un perfil al revés (Sheldahl & Klimas 1981): nunca más que con el mismo viento de
	# cara. El cuerpo, las alas plegadas y los mamíferos sustentan igual por los dos lados
	for id: String in animals():
		for zone: String in MC.zones_for(C(id)):
			for post: String in MC.POSTURES[MC.BODIES[id].kind]:
				for u: float in [5.0, 20.0, 40.0, 60.0]:
					var tail := scen(id, zone, post, { "wind_kmh": -u })
					var head := scen(id, zone, post, { "wind_kmh": u })
					var cases_t: Array = [tail.cases.nom] + tail.cases.lo + tail.cases.hi
					var cases_h: Array = [head.cases.nom] + head.cases.lo + head.cases.hi
					var tag := "%s %s %s, %s km/h" % [id, zone, post, u]
					for i in cases_t.size():
						var lt: float = MC._eval(cases_t[i], 0.0, tail.wh, 0.0, 0.0, 0.0).lift
						var lh: float = MC._eval(cases_h[i], 0.0, head.wh, 0.0, 0.0, 0.0).lift
						assert_true(lt <= lh + 1e-12, "%s (caso %d): de cola %s N ≤ de cara %s N" % [tag, i, lt, lh])
						if post != "abiertas":
							assert_eq(lt, lh, "%s (caso %d): sin alas abiertas, igual por los dos lados" % [tag, i])
					assert_eq(MC.at_speed(tail, 0.0).liftN, MC._eval(tail.cases.nom, 0.0, tail.wh, 0.0, 0.0, 0.0).lift, "%s: at_speed igual" % tag)
	# el coeficiente: el |CL| máximo medido con el aire entrando por el borde de salida, 0,85 (tabla 2 de Sheldahl &
	# Klimas: −0,85 a 170°), frente al 1,6 de un ala de ave de cara; la placa en pérdida, igual; el ala plana, 0
	var w: Dictionary = MC.BIRD_AERO.wing
	assert_eq(w.sustenta.cl_rev, 0.85, "sustenta: el perfil al revés")
	assert_eq(w.frena.cl_rev, w.frena.cl, "frena: una placa en pérdida, igual por los dos bordes")
	assert_eq(w.suave.cl_rev, 0.0, "suave: el ala plana, como el perfil a 180°")
	for st: String in w:
		assert_true(float(w[st].cl_rev) <= float(w[st].cl), "%s: nunca más que de cara" % st)
		assert_true(String(w[st].cl_rev_source).contains("Sheldahl") or st == "frena", "%s: con su fuente" % st)
	# a mano: el águila con las alas abiertas en el techo, parada, con 60 km/h de cola o de cara
	var t := scen("aguila", "techo", "abiertas", { "wind_kmh": -60.0 })
	var h := scen("aguila", "techo", "abiertas", { "wind_kmh": 60.0 })
	var sb := MC.bird_frontal_m2(5.0)
	var s_w: float = MC.BODIES.aguila.wing_m2.value
	var want := (0.2 * sb + 0.85 * s_w) / (0.2 * sb + 1.6 * s_w)
	assert_near(MC.at_speed(t, 0.0).liftN / MC.at_speed(h, 0.0).liftN, want, 1e-9, 0.0, "la sustentación, en la proporción de los CL")
	# más deprisa que el viento de cola, el aire vuelve a venir de cara: como sin viento a la velocidad relativa
	assert_near(MC.at_speed(t, 100.0).liftN, MC.at_speed(scen("aguila", "techo", "abiertas"), 40.0).liftN, 1e-9, 1e-12, "de cara otra vez")
	# el texto de «despega con el coche parado» dice de dónde le viene el aire
	var vr := MC._rest_verdict(t, { "mode": "despega" })
	assert_true(String(vr.vsub).begins_with("con ese viento de cola, aunque le llega por detrás"), vr.vsub)
	assert_true(String(MC._rest_verdict(h, { "mode": "despega" }).vsub).begins_with("con ese viento de cara"), "de cara")
	assert_true(String(MC._rest_verdict(scen("aguila", "techo", "abiertas", { "crosswind_kmh": 60.0 }), { "mode": "despega" }).vsub).begins_with("con ese viento lateral"), "de lado")


func test_mas_agarre_o_mas_friccion_nunca_se_suelta_antes() -> void:
	for id: String in ["aguila", "halcon", "tigre", "oso"]:
		for zone: String in MC.zones_for(C(id)):
			var s := scen(id, zone, MC.POSTURES[MC.BODIES[id].kind][0])
			var base: Dictionary = s.cases.nom
			var prev := -1.0
			for k: float in [0.5, 1.0, 2.0, 4.0]:
				var c := base.duplicate()
				c.A = float(base.A) * k + 10.0 * (k - 1.0)
				var s2 := s.duplicate()
				s2.cases = { "nom": c, "lo": [c], "hi": [c] }
				var kmh: float = MC.detach(s2).kmh
				assert_true(kmh >= prev - 1e-6, "%s en %s: anclaje ×%s no se suelta antes" % [id, zone, k])
				prev = kmh
			prev = -1.0
			for mu: float in [0.3, 0.6, 1.0]:
				var c := base.duplicate()
				c.mu = mu
				var s3 := s.duplicate()
				s3.cases = { "nom": c, "lo": [c], "hi": [c] }
				var kmh: float = MC.detach(s3).kmh
				assert_true(kmh >= prev - 1e-6, "%s en %s: μ = %s no se suelta antes" % [id, zone, mu])
				prev = kmh


func test_frenar_fuerte_nunca_ayuda_a_quedarse_delante() -> void:
	# si la frenada ya empuja al animal hacia delante (T ≤ 0), frenar más fuerte nunca aumenta el margen
	for id: String in animals():
		var kind: String = MC.BODIES[id].kind
		for zone: String in ["capo", "limpiaparabrisas", "parabrisas", "aleta"]:
			for post: String in MC.POSTURES[kind]:
				var c: Dictionary = scen(id, zone, post).cases.nom
				for v_kmh: float in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]:
					var v := v_kmh / MC.KMH
					var soft := MC._eval(c, v, 0.0, 0.0, -0.5 * MC.G, 0.0)
					var hard := MC._eval(c, v, 0.0, 0.0, -1.0 * MC.G, 0.0)
					if soft.tt <= 0.0:
						assert_true(hard.margin <= soft.margin + 1e-9, "%s %s %s a %s km/h: frenar más no ayuda" % [id, zone, post, v_kmh])
	# y sin nada que agarrar, una frenada de emergencia más fuerte que su fricción lo lanza hacia delante
	var tiger := scen("tigre", "capo", "tumbado", { "accel_g": -1.0 })
	var det := MC.detach(tiger)
	if tiger.mu < 1.0 - 1e-9:
		assert_false(det.atRest, "con 1 g de frenada el tigre sale despedido")
	var a := MC.at_speed(scen("aguila", "capo", "plegadas", { "accel_g": -0.9 }), 10.0)
	assert_true(a.needN > 0.0, "la frenada pide fuerza")


func test_por_donde_se_va_segun_lo_que_lo_empuja() -> void:
	# en un panel plano, lo que empuja hacia delante es la frenada o el viento de cola, nunca una cuesta
	var flat := { "m": 1.0, "cb": 1.0, "sb": 0.0 }
	assert_eq(MC._mode_of({ "rn": 9.0, "lift": 0.0, "tt": -5.0, "ty": 0.0, "at": -5.0 }, flat, 0.0), "delante", "viento de cola")
	assert_eq(MC._mode_of({ "rn": 9.0, "lift": 0.0, "tt": -5.0, "ty": 0.0, "at": 0.0 }, flat, -5.0), "delante", "frenada")
	var ramp := { "m": 1.0, "cb": cos(PI / 6.0), "sb": sin(PI / 6.0) }
	assert_eq(MC._mode_of({ "rn": 8.0, "lift": 0.0, "tt": -4.9, "ty": 0.0, "at": 0.0 }, ramp, 0.0), "abajo", "la cuesta del panel")
	assert_eq(MC._mode_of({ "rn": 8.0, "lift": 0.0, "tt": 3.0, "ty": 0.0, "at": 3.0 }, ramp, 0.0), "atras", "viento de cara")
	assert_eq(MC._mode_of({ "rn": 8.0, "lift": 0.0, "tt": 1.0, "ty": 4.0, "at": 1.0 }, flat, 0.0), "lado", "curva")
	assert_eq(MC._mode_of({ "rn": -1.0, "lift": 20.0, "tt": 1.0, "ty": 0.0, "at": 1.0 }, flat, 0.0), "despega", "sin apoyo")
	# con el coche parado, el texto dice qué lo echa: el viento de cara con las alas abiertas, o la frenada
	var gust := scen("aguila", "techo", "abiertas", { "wind_kmh": 60.0 })
	var vg := MC.detach_verdict(gust, MC.detach(gust))
	assert_eq(vg.verdict, "DESPEGA CON EL COCHE PARADO", "60 km/h de viento de cara con las alas abiertas")
	var brake := scen("tigre", "capo", "tumbado", { "accel_g": -1.0 })
	var vb := MC.detach_verdict(brake, MC.detach(brake))
	assert_eq(vb.verdict, "SALE DESPEDIDO HACIA DELANTE", "frenada de 1 g en el capó")
	assert_true(String(vb.vsub).contains("frenada"), "y dice que es la frenada")
	for v: Dictionary in [vg, vb]:
		assert_false(String(v.vsub).contains("~0 km/h"), "sin bandas de cero: %s" % v.vsub)


func test_aguantar_es_una_ventana_de_velocidades() -> void:
	# el oso de pie en el techo con una frenada de emergencia: parado, la inercia lo lanza hacia delante; más deprisa, el
	# viento de cara la compensa y aguanta. No es «ni a paso de hombre aguanta»: es una ventana
	var bear := scen("oso", "techo", "de_pie", { "accel_g": -0.9 })
	var d := MC.detach(bear)
	assert_false(d.atRest, "parado no aguanta")
	assert_eq(d.mode, "delante", "parado, la frenada lo lanza hacia delante")
	var from: float = d.holdFromKmh
	assert_true(from > 55.0 and from < 70.0, "aguanta desde ~62 km/h: %s" % from)
	assert_true(is_inf(float(d.holdToKmh)) and d.holdToMode == "", "y no se suelta ni a 400 km/h")
	assert_eq(d.kmh, 0.0, "kmh sigue siendo 0: la banda es la del despegue desde parado")
	assert_true(MC.at_speed(bear, from).holds, "en el borde, aguanta")
	assert_false(MC.at_speed(bear, from - 0.01).holds, "justo por debajo, no")
	assert_true(MC.at_speed(bear, 90.0).holds, "a 90 km/h aguanta")
	var v := MC.detach_verdict(bear, d)
	assert_eq(v.verdict, "SALE DESPEDIDO HACIA DELANTE AL BAJAR DE ~%s km/h" % Js.to_fixed(from, 0), "el veredicto: %s" % v.verdict)
	assert_false(String(v.vsub).contains("paso de hombre"), "más deprisa sí aguanta: %s" % v.vsub)
	assert_true(String(v.vsub).begins_with("despacio, la frenada lo empuja más de lo que aguanta; más deprisa, el viento de cara compensa la inercia y lo sujeta"), v.vsub)
	# una ventana con los dos bordes: el águila con las alas plegadas en el capó y 1 g de frenada; arriba, ya vuela
	var eagle := scen("aguila", "capo", "plegadas", { "accel_g": -1.0 })
	var de := MC.detach(eagle)
	assert_true(de.holdFromKmh != null and is_finite(float(de.holdToKmh)), "ventana cerrada: %s" % [de])
	assert_true(float(de.holdToKmh) > float(de.holdFromKmh), "de menos a más")
	assert_true(MC.at_speed(eagle, float(de.holdToKmh) - 0.01).holds and not MC.at_speed(eagle, float(de.holdToKmh)).holds, "el borde de arriba")
	assert_true(String(MC.detach_verdict(eagle, de).vsub).contains("hasta ~%s km/h, donde " % Js.to_fixed(float(de.holdToKmh), 0)), "y dónde se suelta")
	# una ventana que empieza fuera del deslizador (el oso tumbado en el techo, desde ~270 km/h): en todo el deslizador
	# sale despedido, y se dice desde dónde aguantaría
	var lying := scen("oso", "techo", "tumbado", { "accel_g": -0.9 })
	var dl := MC.detach(lying)
	assert_true(dl.holdFromKmh != null and float(dl.holdFromKmh) > MC.SLIDER_MAX_KMH, "desde más de 150 km/h: %s" % [dl])
	var vl := MC.detach_verdict(lying, dl)
	assert_eq(vl.verdict, "SALE DESPEDIDO HACIA DELANTE", "en todo el deslizador")
	assert_true(String(vl.vsub).begins_with("con esa frenada, ni a paso de hombre aguanta encima; solo por encima de ~%s km/h aguantaría: " % Js.to_fixed(float(dl.holdFromKmh), 0)), vl.vsub)
	# sin ventana, todo sigue igual: el tigre tumbado en el capó con 1 g ni parado ni a 400 km/h aguanta
	var tiger := MC.detach(scen("tigre", "capo", "tumbado", { "accel_g": -1.0 }))
	assert_true(not tiger.atRest and tiger.holdFromKmh == null and tiger.holdToKmh == null, "sin ventana: %s" % [tiger])
	# aguanta parado: sin ventana
	var calm := MC.detach(scen("aguila", "techo", "plegadas"))
	assert_true(calm.atRest and calm.holdFromKmh == null, "aguanta parado")


func test_la_ventana_es_la_de_at_speed_y_ningun_veredicto_dice_cero() -> void:
	# en la rejilla de la búsqueda (cada 5 km/h), at_speed aguanta justo dentro de la ventana; si aguanta parado, hasta
	# kmh. Y ningún veredicto dice «~0 km/h» (un agarre justo en el límite con el coche parado no «se suelta a 0»)
	var overs := [{ "accel_g": -0.9 }, { "accel_g": -1.0 }, { "wind_kmh": -60.0 }, { "lateral_g": 0.5 }]
	var windows := 0
	for id: String in animals():
		var kind: String = MC.BODIES[id].kind
		for zone: String in MC.ZONES:
			if not MC.ZONES[zone].animals.has(kind):
				continue
			for post: String in MC.POSTURES[kind]:
				for over: Dictionary in overs:
					var s := scen(id, zone, post, over)
					var d := MC.detach(s)
					var tag := "%s %s %s %s" % [id, zone, post, over]
					var vd := MC.detach_verdict(s, d)
					assert_false(String(vd.verdict + vd.vsub).contains("~0 km/h"), "%s: %s / %s" % [tag, vd.verdict, vd.vsub])
					if d.holdFromKmh != null:
						windows += 1
						assert_true(float(d.holdFromKmh) >= MC.REST_KMH, "%s: la ventana no empieza parado" % tag)
					for i in 81:
						var vk := 5.0 * i
						var at := MC.at_speed(s, vk)
						if absf(float(at.marginN)) <= 1e-9 * float(at.weightN):
							continue  # justo en el límite (margen nulo): vale leerlo de las dos maneras
						var holds: bool = at.holds
						var inside: bool
						if d.holdFromKmh != null:
							inside = vk >= float(d.holdFromKmh) and vk < float(d.holdToKmh)
						elif d.atRest:
							inside = vk < float(d.kmh)
							if not inside:
								break  # por encima del despegue la búsqueda ya no mira
						else:
							inside = false
						if holds != inside:
							fail("%s: a %s km/h aguanta = %s y la ventana dice %s (%s)" % [tag, vk, holds, inside, d])
							break
	assert_true(windows > 20, "hay ventanas que comprobar: %d" % windows)
	# el agarre justo en el límite con el coche parado (μ = 1 frente a 1 g, solo fricción): ni parado se sostiene
	var edge := scen("aguila", "techo", "abiertas", { "accel_g": -1.0 })
	assert_near(MC._margin(edge.cases.nom, 0.0, edge.wh, edge.wc, edge.ax, edge.ay), 0.0, 0.0, 1e-9, "margen nulo parado")
	var de := MC.detach(edge)
	assert_false(de.atRest, "ni parado se sostiene")
	assert_eq(MC.detach_verdict(edge, de).verdict, "SALE DESPEDIDA HACIA DELANTE", "el águila sale despedida")


func test_los_textos_concuerdan_con_el_animal() -> void:
	# el águila, la arpía y la lechuza son femeninos; el halcón, el búho y el buitre, masculinos
	var eagle := scen("aguila", "retrovisor", "plegadas")
	var de := MC.detach(eagle)
	if de.never:
		assert_true(String(MC.detach_verdict(eagle, de).vsub).begins_with("bien agarrada, el viento no puede con ella"), MC.detach_verdict(eagle, de).vsub)
	var owl := scen("buho", "retrovisor", "plegadas")
	var do := MC.detach(owl)
	if do.never:
		assert_true(String(MC.detach_verdict(owl, do).vsub).begins_with("bien agarrado, el viento no puede con él"), MC.detach_verdict(owl, do).vsub)
	var gust := scen("halcon", "techo", "abiertas", { "wind_kmh": 60.0 })
	var vg := MC.detach_verdict(gust, MC.detach(gust))
	assert_true(String(vg.vsub).contains("ya lo sostienen"), "el halcón: %s" % vg.vsub)
	var gust2 := scen("lechuza", "techo", "abiertas", { "wind_kmh": 60.0 })
	assert_true(String(MC.detach_verdict(gust2, MC.detach(gust2)).vsub).contains("ya la sostienen"), "la lechuza")


func test_la_frenada_maxima_es_la_friccion_a_poca_velocidad() -> void:
	# en el techo (plano), parado: aguanta frenadas de hasta μ·g
	for id: String in ["tigre", "oso", "aguila"]:
		var s := scen(id, "techo", MC.POSTURES[MC.BODIES[id].kind][0])
		assert_near(MC.max_braking_g(s, 0.0), s.mu, 1e-4, 1e-6, "%s: a_max = μ·g" % id)


func test_en_los_animales_pesados_manda_la_inercia() -> void:
	# a 150 km/h el aire empuja al tigre o al oso agazapados menos que una frenada normal (0,35 g)
	for id: String in MAMMALS:
		var s := scen(id, "techo", "tumbado")
		var a := MC.at_speed(s, 150.0)
		assert_true(a.dragN < 0.35 * a.weightN, "%s: resistencia %s N < 0,35 × peso" % [id, a.dragN])
	# y el oso de pie en el techo casi dobla la resistencia del coche a 100 km/h
	var bear := MC.at_speed(scen("oso", "techo", "de_pie"), 100.0)
	assert_true(bear.dragShare > 0.5, "oso de pie: %s de la resistencia del coche" % bear.dragShare)


func test_la_banda_contiene_al_valor_central() -> void:
	for id: String in animals():
		for zone: String in MC.zones_for(C(id)):
			for post: String in MC.POSTURES[MC.BODIES[id].kind]:
				var d := MC.detach(scen(id, zone, post))
				assert_true(d.minKmh <= d.kmh + 1e-9 and d.kmh <= d.maxKmh + 1e-9, "%s %s %s: banda ordenada" % [id, zone, post])


## Unidad 4o: la banda de cada fuerza sale de todos los casos, los de los datos en contra y los de a favor. Con una frenada
## (o un viento de cola), el aire que más empuja hacia atrás es el que menos fuerza pide, y tomando solo un lado la banda de
## la necesaria se quedaba en el valor central. Si aguanta con todo en contra o a favor sigue siendo lo de cada lado.
func test_la_banda_de_las_fuerzas_toma_los_dos_lados() -> void:
	var scens := [scen("oso", "techo", "de_pie", { "accel_g": -0.9 }), scen("oso", "capo", "tumbado", { "accel_g": -0.9 }),
		scen("tigre", "techo", "de_pie"), scen("aguila", "capo", "abiertas", { "wind_kmh": -30.0 })]
	for s: Dictionary in scens:
		for vk: float in [0.0, 30.0, 60.0, 120.0]:
			var a := MC.at_speed(s, vk)
			var need: Array = [a.needN]
			var avail: Array = [a.availN]
			var holds_lo := true
			var holds_hi := false
			for side: String in ["lo", "hi"]:
				for c: Dictionary in s.cases[side]:
					var f := MC._eval(c, vk / MC.KMH, s.wh, s.wc, s.ax, s.ay)
					need.append(f.need)
					avail.append(f.avail)
					if side == "lo":
						holds_lo = holds_lo and f.margin >= 0.0
					else:
						holds_hi = holds_hi or f.margin >= 0.0
			var tag := "%s %s a %s km/h" % [s.claw, s.zone, vk]
			assert_eq([a.needMinN, a.needMaxN], [need.min(), need.max()], "%s: la necesaria, de todos los casos" % tag)
			assert_eq([a.availMinN, a.availMaxN], [avail.min(), avail.max()], "%s: la disponible, de todos los casos" % tag)
			assert_eq([a.holdsLo, a.holdsHi], [holds_lo, holds_hi], "%s: aguanta con todo en contra o a favor, de cada lado" % tag)
	# el oso de pie en el techo en una frenada de emergencia, a 60 km/h: con 109 N de aire, la banda ya no es un punto
	var bear := MC.at_speed(scens[0], 60.0)
	assert_true(bear.dragN > 100.0, "con aire: %s N" % bear.dragN)
	assert_true(bear.needMinN < bear.needN - 10.0 and bear.needN + 10.0 < bear.needMaxN, "la banda rodea al valor central: %s" % [bear])


func test_la_grafica_crece_y_cae_como_debe() -> void:
	for id: String in ["aguila", "tigre"]:
		for post: String in MC.POSTURES[MC.BODIES[id].kind]:
			var cv := MC.curve(scen(id, "techo", post), 31)
			assert_eq(cv.vKmh.size(), 31, "31 puntos")
			for i in range(1, 31):
				assert_true(cv.need[i] >= cv.need[i - 1] - 1e-9, "%s %s: la fuerza necesaria no baja" % [id, post])
				assert_true(cv.avail[i] <= cv.avail[i - 1] + 1e-9, "%s %s: la disponible no sube" % [id, post])
				assert_true(cv.needMin[i] <= cv.need[i] + 1e-9 and cv.need[i] <= cv.needMax[i] + 1e-9, "%s %s: banda de la necesaria" % [id, post])
				assert_true(cv.availMin[i] <= cv.avail[i] + 1e-9 and cv.avail[i] <= cv.availMax[i] + 1e-9, "%s %s: banda de la disponible" % [id, post])


func test_zonas_y_posturas_por_animal() -> void:
	assert_true(MC.zones_for(C("aguila")).has("retrovisor"), "un ave se agarra al retrovisor")
	assert_false(MC.zones_for(C("tigre")).has("antena"), "un tigre no se agarra a la antena")
	assert_eq(MC.postures_of(C("buho")), ["plegadas", "abiertas"], "aves")
	assert_eq(MC.postures_of(C("oso")), ["tumbado", "de_pie"], "mamíferos")
	var none := MC.setup({ "claw": C("gato"), "target": T("coche"), "zone": "techo" })
	assert_false(none.ok, "sin datos aerodinámicos, no se ensaya")
	assert_true(String(none.reason).length() > 0, "y lo dice")
	assert_false(MC.setup({ "claw": C("tigre"), "target": T("coche"), "zone": "retrovisor" }).ok, "zona no disponible")


func test_at_speed_es_barato_y_determinista() -> void:
	var s := scen("aguila", "retrovisor", "abiertas", { "crosswind_kmh": 10.0, "accel_g": -0.2 })
	var t0 := Time.get_ticks_msec()
	for i in 2000:
		MC.at_speed(s, float(i % 151))
	var ms := Time.get_ticks_msec() - t0
	assert_true(ms < 2000, "2000 fotogramas en %s ms (< 1 ms cada uno)" % ms)
	assert_true(same(MC.at_speed(s, 87.0), MC.at_speed(s, 87.0)), "mismo resultado cada vez")
	assert_true(same(MC.hold_report({ "claw": C("buho"), "target": T("cochealu"), "zone": "techo", "posture": "plegadas" }).detach,
		MC.hold_report({ "claw": C("buho"), "target": T("cochealu"), "zone": "techo", "posture": "plegadas" }).detach), "detach determinista")


# ── Garras y capas ──

func test_la_queratina_nunca_perfora_el_acero_ni_el_aluminio_del_coche() -> void:
	var combos := [[150.0, 60.0, 180.0], [0.0, 60.0, 90.0], [100.0, 0.0, 0.0]]
	for id: String in animals():
		for tid: String in METAL_CARS:
			for zone: String in ["capo", "techo", "puerta"]:
				for k: Array in combos:
					var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2], "drop_m": 1.0 })
					var tag := "%s contra %s (%s, %s/%s/%s)" % [id, tid, zone, k[0], k[1], k[2]]
					assert_true(r.marks.depthUm <= PAINT_UM + 1e-6, "%s: los surcos se quedan en la pintura" % tag)
					if r.puncture != null:
						assert_true(r.puncture.depthUm <= PAINT_UM + 1e-6, "%s: la punción no entra en el metal" % tag)
						assert_false(r.puncture.through, "%s: no perfora" % tag)
	# en reposo, rayando con su peso: tampoco
	for id: String in animals():
		for tid: String in METAL_CARS:
			var s := MC.setup({ "claw": C(id), "target": T(tid), "zone": "techo" })
			assert_true(s.scratch.depthUm <= PAINT_UM + 1e-6, "%s sobre %s: hasta el metal como mucho" % [id, tid])


func test_en_la_aleta_de_plastico_si_perfora() -> void:
	var r := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
	assert_true(r.puncture.through, "el tigre atraviesa el plástico")
	assert_true(r.embedded, "y las garras quedan clavadas")
	assert_eq(r.verdict, "PERFORA EL PLÁSTICO", "veredicto")
	assert_false(r.dent.applies, "el plástico no se abolla: recupera")


## La aleta de plástico con otro espesor de plástico (µm): la misma PPE/PA, para las invariantes del desgarro.
static func plastic_of(t_um: float) -> Dictionary:
	var tgt: Dictionary = T("cocheplastico").duplicate(true)
	tgt.body.t = t_um
	tgt.layers.sub.t = t_um
	tgt.thickness = (PAINT_UM + t_um) / 1000.0
	return tgt


func test_las_garras_trabadas_rajan_la_aleta() -> void:
	# el tigre que cruza a 40 km/h contra la aleta de plástico de un coche a 50: sus garras la atraviesan y, como sigue a lo
	# largo del panel, quedan trabadas y la rajan. Cada garra pide R·t = 45 kJ/m² × 2,5 mm = 112,5 N (la resiliencia con
	# entalla de la ficha de SABIC por el espesor): las ocho frenan al tigre con 900 N, menos de lo que aguanta (su anclaje)
	var r := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.0 })
	var t: Dictionary = r.tear
	var tough: Dictionary = MC.PLASTIC_TEAR["plastico-carroceria"]
	assert_near(t.perClawN, float(tough.value) * 2.5, 1e-12, 0.0, "R·t por garra")
	assert_near(t.forceN, 8.0 * float(tough.value) * 2.5, 1e-12, 0.0, "las ocho garras")
	assert_near(t.anchorN.value, 2.0 * 0.5 * 220.0 * MC.G, 1e-9, 0.0, "su anclaje: media vez su peso por mano")
	assert_true(t.holds, "el tigre aguanta lo que pide rajarla")
	# a mano: tras el golpe le quedan v_t1 = v_t − μ·(μ_red/m)·v_n a lo largo del panel; frena con a = F/m y, como la aleta
	# se acaba antes de que se pare, la raja entera (0,8 m) y sale por el final con √(v_t1² − 2·a·0,8)
	var m := 220.0
	var vn := 40.0 / 3.6
	var mu_red := m * 1400.0 / (m + 1400.0)
	var vt1: float = 50.0 / 3.6 - float(r.mu) * (mu_red / m) * vn
	var a := float(t.forceN) / m
	assert_true(vt1 * vt1 / (2.0 * a) > 0.8, "no le da tiempo a pararse")
	var ve := sqrt(vt1 * vt1 - 2.0 * a * 0.8)
	assert_near(t.lengthMm, 800.0, 1e-9, 0.0, "raja la aleta entera")
	assert_true(t.reachesEnd and not t.stopped, "llega al final del panel")
	assert_near(r.exitKmh, ve * 3.6, 1e-9, 1e-9, "sale por el final")
	assert_near(t.energyJ, float(t.forceN) * 0.8, 1e-9, 0.0, "E = n·R·t·L")
	assert_near(r.energy.tearJ, t.energyJ, 1e-12, 0.0, "el desgarro, en el balance")
	assert_near(t.timeS, (vt1 - ve) / a, 1e-9, 0.0, "lo que tarda")
	assert_near(r.contactS, t.timeS, 1e-12, 0.0, "el contacto es el desgarro (el plástico no se abolla)")
	assert_true(float(t.minMm) <= float(t.lengthMm) and float(t.lengthMm) <= float(t.maxMm), "banda ordenada")
	# las marcas son las ranuras del desgarro: ocho, a lo largo de la aleta, de lado a lado y del ancho de la garra
	assert_eq(r.marks.count, 8, "ocho ranuras")
	assert_near(r.marks.lengthMm, 800.0, 1e-9, 0.0, "a lo largo de la aleta")
	assert_eq(r.marks.verdict, "RAJA EL PLÁSTICO", "de lado a lado")
	assert_near(float(r.marks.depthUm), PAINT_UM + 2500.0, 1e-12, 0.0, "todo el espesor, de lado a lado")
	var scared := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "defense": true })
	assert_near(float(scared.marks.depthUm), PAINT_UM + 2500.0, 1e-12, 0.0, "asustado, la misma ranura (lo de más allá es aire)")
	assert_eq(r.marks.residualUm, r.marks.depthUm, "lo rajado no se recupera")
	assert_near(r.marks.widthUm, r.puncture.holeUm, 1e-12, 0.0, "del ancho de la garra en la aleta")
	assert_eq(r.verdict, "PERFORA EL PLÁSTICO", "veredicto")
	assert_true(String(r.vsub).contains("y lo rajan ~") and String(r.vsub).contains("se desengancha"), r.vsub)
	var rows := {}
	for row: Array in r.report:
		rows[row[0]] = row[1]
	assert_true(String(rows.get("Desgarro", "")).begins_with("raja "), "fila Desgarro: %s" % rows.get("Desgarro"))
	assert_eq(r.energy.terms[0].name, "Garras (punción y desgarro del plástico)", "el término de las garras")
	assert_eq(r.energy.terms[0].quality, "estimate", "con el desgarro, estimación")
	# con el coche a 40, se para a mitad de la aleta: el coche se lo lleva y cae a su velocidad
	var slow := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 40.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.0 })
	var vt1s: float = 40.0 / 3.6 - float(slow.mu) * (mu_red / m) * vn
	assert_true(slow.tear.stopped and not slow.tear.reachesEnd, "se para respecto al coche")
	assert_near(slow.tear.lengthMm, vt1s * vt1s / (2.0 * a) * 1000.0, 1e-9, 0.0, "L = m·v²/(2·n·R·t)")
	assert_near(slow.groundKmh, 40.0, 1e-9, 1e-9, "cae a la velocidad del coche")
	assert_near(slow.energy.tearJ, 0.5 * m * vt1s * vt1s, 1e-9, 0.0, "se lleva todo lo que le quedaba a lo largo del panel")
	assert_true(String(slow.vsub).contains("hasta que va a la velocidad del coche"), slow.vsub)


func test_si_no_aguanta_lo_que_pide_rajarla_se_le_sueltan() -> void:
	# el águila: sus cuatro talones pedirían 450 N y su agarre medido solo sujeta ~202 N (2 pies × ~101 N): los dedos
	# ceden y los talones salen del plástico sin rajarlo
	var r := MC.impact({ "claw": C("aguila"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 90.0, "animal_kmh": 50.0, "angle_deg": 90.0, "drop_m": 0.0 })
	assert_true(r.puncture.through, "los talones la atraviesan")
	assert_false(r.tear.holds, "pero no aguanta lo que pide rajarla")
	assert_eq(r.tear.lengthMm, 0.0, "no la raja")
	assert_eq(r.marks.count, 0, "sin ranuras")
	assert_eq(r.energy.tearJ, 0.0, "sin desgarro en el balance")
	assert_near(r.tear.anchorN.value, 2.0 * float(ClawsV2.band(ClawsV2.apply(C("aguila")), "force").value), 1e-9, 0.0, "su agarre")
	assert_true(String(r.vsub).contains(", pero rajarlo pide ~"), r.vsub)
	assert_true(float(r.tear.maxMm) > 0.0, "con los datos más favorables (plástico frío, agarre alto) sí la rajaría")
	# el casuario patea: su daga no queda colgada del plástico (no hay desgarro aparte del surco de la patada)
	var cas := MC.impact({ "claw": C("casuario"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 0.0 })
	assert_eq(cas.tear, null, "la patada rebota")


func test_el_desgarro_nunca_es_mas_corto_con_mas_velocidad_ni_pasa_del_panel() -> void:
	# cuanta más velocidad le quede a lo largo del panel, más largo (o igual) el desgarro; nunca más largo que el panel
	for id: String in animals():
		for zone: String in ["aleta", "puerta"]:
			var slide: float = MC.IMPACT_ZONES[zone].slide_m
			for defense: bool in [false, true]:
				var prev := -1.0
				for v: float in [0.0, 20.0, 40.0, 55.0, 70.0, 90.0, 120.0, 150.0]:
					var r := MC.impact({ "claw": C(id), "target": T("cocheplastico"), "zone": zone, "v_kmh": v, "animal_kmh": 40.0, "angle_deg": 90.0, "defense": defense })
					var tag := "%s en %s a %s km/h%s" % [id, zone, v, " asustado" if defense else ""]
					var len_mm := 0.0 if r.tear == null else float(r.tear.lengthMm)
					assert_true(len_mm >= prev - 1e-9, "%s: más velocidad nunca da un desgarro más corto (%s < %s)" % [tag, len_mm, prev])
					prev = len_mm
					assert_true(len_mm <= slide * 1000.0 + 1e-9, "%s: el desgarro no pasa del panel" % tag)
					assert_true(float(r.slideM) <= slide + 1e-12, "%s: ni las marcas" % tag)
					if r.tear != null:
						assert_true(float(r.tear.minMm) <= len_mm + 1e-9 and len_mm <= float(r.tear.maxMm) + 1e-9, "%s: banda" % tag)
						assert_true(float(r.tear.maxMm) <= slide * 1000.0 + 1e-9, "%s: banda dentro del panel" % tag)
	# la función pura, con cualquier velocidad
	var prev_l := -1.0
	for vt1: float in [0.0, 0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 13.0, 20.0]:
		var run := MC.tear_run(220.0, vt1, 0.8, 8, 2.5, 45.0, 2157.5)
		assert_true(float(run.lengthM) >= prev_l - 1e-12 and float(run.lengthM) <= 0.8 + 1e-12, "a %s m/s" % vt1)
		assert_near(float(run.energyJ), 0.5 * 220.0 * (vt1 * vt1 - float(run.vExitMs) * float(run.vExitMs)), 1e-9, 1e-12, "balance a %s m/s" % vt1)
		assert_near(float(run.energyJ), float(run.forceN) * float(run.lengthM), 1e-9, 1e-12, "E = F·L a %s m/s" % vt1)
		prev_l = run.lengthM


func test_una_aleta_mas_gruesa_o_mas_tenaz_nunca_se_raja_mas() -> void:
	# la función pura: con más tenacidad o más espesor, nunca un desgarro más largo (y si pasa de lo que aguanta, se suelta)
	for vt1: float in [1.0, 3.0, 6.0, 12.0]:
		var prev := INF
		for r_kj: float in [5.0, 10.0, 20.0, 45.0, 50.0, 80.0, 120.0]:
			var len_r: float = MC.tear_run(220.0, vt1, 0.8, 8, 2.5, r_kj, 2157.5).lengthM
			assert_true(len_r <= prev + 1e-12, "a %s m/s, con %s kJ/m²: %s" % [vt1, r_kj, len_r])
			prev = len_r
		prev = INF
		for t_mm: float in [0.5, 1.0, 2.0, 2.5, 3.0, 4.0, 6.0]:
			var len_t: float = MC.tear_run(220.0, vt1, 0.8, 8, t_mm, 45.0, 2157.5).lengthM
			assert_true(len_t <= prev + 1e-12, "a %s m/s, con %s mm: %s" % [vt1, t_mm, len_t])
			prev = len_t
	# en el golpe, con la misma PPE/PA de otros espesores
	for id: String in ["tigre", "oso", "aguila", "halcon"]:
		for zone: String in ["aleta", "puerta"]:
			var prev := INF
			for t_um: float in [1000.0, 1500.0, 2000.0, 2500.0, 3000.0, 4000.0, 6000.0]:
				var r := MC.impact({ "claw": C(id), "target": plastic_of(t_um), "zone": zone, "v_kmh": 70.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
				var len_mm := 0.0 if r.tear == null else float(r.tear.lengthMm)
				assert_true(len_mm <= prev + 1e-9, "%s en %s con %s µm de plástico: %s mm" % [id, zone, t_um, len_mm])
				prev = len_mm
				if r.tear != null:
					assert_near(float(r.tear.thicknessMm), t_um / 1000.0, 1e-12, 0.0, "%s: el espesor del objetivo" % id)


func test_la_chapa_de_metal_y_los_paneles_de_arriba_no_cambian() -> void:
	# el desgarro solo es de unas garras trabadas en el plástico de un costado: en la chapa (queratina o garras reforjadas) y
	# en los paneles de arriba (donde ya corta el motor con la fricción de su peso) no hay desgarro aparte
	for id: String in animals():
		for inl: String in ["none", "zafiro", "acero"]:
			for tid: String in METAL_CARS:
				for zone: String in ["puerta", "aleta", "techo"]:
					var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": 70.0, "animal_kmh": 40.0, "angle_deg": 90.0, "inlay": inl })
					var tag := "%s de %s contra %s (%s)" % [id, inl, tid, zone]
					assert_eq(r.tear, null, "%s: sin desgarro del plástico" % tag)
					assert_eq(r.energy.tearJ, 0.0, "%s: nada en el balance" % tag)
					assert_eq(r.energy.clawsJ, r.energy.punctureJ, "%s: las garras, solo la punción" % tag)
		for zone: String in ["capo", "techo"]:
			var top := MC.impact({ "claw": C(id), "target": T("cocheplastico"), "zone": zone, "v_kmh": 70.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5 })
			assert_eq(top.tear, null, "%s en %s de plástico: lo corta la fricción de su peso" % [id, zone])


func test_las_capas_cortadas_salen_de_la_pintura_del_coche() -> void:
	assert_eq(MC.layers_crossed(T("coche"), 50.0), ["barniz", "color"], "50 µm: barniz y color")
	assert_eq(MC.layers_crossed(T("coche"), 110.0), ["barniz", "color", "imprimación", "anticorrosivo"], "toda la pintura")
	assert_eq(MC.layers_crossed(T("cocheplastico"), 200.0).back(), "plástico PPE/PA", "en la aleta, el plástico")
	assert_eq(MC.layers_crossed(T("vidrio"), 50.0), [], "el vidrio no tiene capas de pintura")


# ── El golpe ──

func test_la_energia_del_golpe_es_la_de_la_velocidad_relativa() -> void:
	var r := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "car_mass_kg": 1400.0 })
	var vrel := sqrt(pow(50.0 / 3.6, 2.0) + pow(40.0 / 3.6, 2.0))
	assert_near(r.vRelKmh, vrel * 3.6, 1e-9, 0.0, "velocidad relativa vectorial")
	var mu_red := 220.0 * 1400.0 / 1620.0
	assert_near(r.normalJ, 0.5 * mu_red * pow(40.0 / 3.6, 2.0), 1e-9, 0.0, "la puerta recibe la componente lateral con la masa reducida")
	assert_true(r.normalJ <= r.energyJ, "nunca más que la energía relativa")


func test_la_energia_del_golpe_se_conserva() -> void:
	# primer principio: garras + chapa (o vidrio) + animal + empujón al coche + calor del rozamiento + lo que se lleva al
	# salir = ½·m·v_rel², la energía cinética del animal respecto al coche
	var combos := [[50.0, 40.0, 90.0, 0.5], [90.0, 60.0, 0.0, 0.2], [120.0, 30.0, 180.0, 0.0]]
	for id: String in animals():
		for tid: String in ["coche", "cochealu", "cocheplastico"]:
			# los golpes que puede dar (unidad 4m: a la ventanilla no llegan todos: window_reach)
			for zone: String in MC.impact_zones_for(C(id)):
				for k: Array in combos:
					var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2], "drop_m": k[3] })
					var tag := "%s contra %s (%s, %s/%s/%s)" % [id, tid, zone, k[0], k[1], k[2]]
					var e: Dictionary = r.energy
					var sum := 0.0
					for t: Dictionary in e.terms:
						assert_true(float(t.j) >= 0.0, "%s: %s no es negativo" % [tag, t.id])
						sum += float(t.j)
					assert_near(sum, e.totalJ, 1e-9, 1e-9, "%s: los términos suman el total" % tag)
					assert_near(e.totalJ, r.energyJ, 1e-9, 1e-9, "%s: el total es ½·m·v_rel²" % tag)
					var vn: float = r.vNormalKmh / 3.6
					# la normal que se disipa es la punción, la chapa y el animal; el desgarro del plástico (unidad 4g) sale del
					# tramo a lo largo del panel y va, con la punción, al término de las garras
					assert_near(e.punctureJ + e.panelJ + e.animalJ, r.normalJ, 1e-9, 1e-9, "%s: la normal que se disipa, ½·μ_red·v_n²" % tag)
					assert_near(e.clawsJ, e.punctureJ + e.tearJ, 1e-12, 1e-12, "%s: las garras, punción y desgarro" % tag)
					assert_near(e.terms[0].j, e.clawsJ, 1e-12, 1e-12, "%s: un campo por término" % tag)
					var vt: float = r.vTangKmh / 3.6
					var ve: float = r.exitKmh / 3.6
					assert_near(e.frictionJ + e.tearJ, 0.5 * r.massKg * maxf(vt * vt - ve * ve, 0.0), 1e-9, 1e-9, "%s: lo que se queda a lo largo del panel" % tag)
					assert_near(e.carJ, 0.5 * (r.massKg - r.reducedMassKg) * vn * vn, 1e-9, 1e-9, "%s: el resto empuja al coche" % tag)
					assert_eq(e.terms[1].id, "vidrio" if MC.IMPACT_ZONES[zone].glass else "chapa", "%s: vidrio o chapa" % tag)
					if r.stays:
						assert_near(e.frictionJ, r.tangJ, 1e-9, 1e-9, "%s: si se queda encima, el rozamiento se lo come todo" % tag)
	# la chapa se lleva el trabajo plástico de la abolladura de la unidad 1f
	var roof := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "techo", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5 })
	assert_near(roof.energy.panelJ, roof.dent.panelJ, 1e-12, 0.0, "chapa = Dent")
	assert_true(roof.energy.animalJ > 0.0, "y el resto, el animal")


func test_mas_velocidad_nunca_da_menos_golpe_ni_menos_abolladura() -> void:
	var prev_e := -1.0
	var prev_d := -1.0
	for v: float in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]:
		var r := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "capo", "v_kmh": v, "animal_kmh": 30.0, "angle_deg": 180.0, "drop_m": 0.0 })
		assert_true(r.normalJ >= prev_e - 1e-9, "a %s km/h de frente, más energía" % v)
		assert_true(r.dent.depthMm >= prev_d - 1e-9, "a %s km/h, más abolladura" % v)
		prev_e = r.normalJ
		prev_d = r.dent.depthMm


func test_la_abolladura_es_la_de_la_unidad_1f() -> void:
	# con un solo apoyo y poca energía (sin llegar al tope de la pata) da lo mismo que Dent.strike
	var d := MC.dent_of(T("coche"), 5.0, 0.0, 1, 1000.0, false)
	var ref := Dent.strike(264.0, 0.7, 5000.0, Physics.MODEL.limbStiffness)
	assert_false(d.limbSaturated, "5 J no agotan la pata")
	assert_near(d.depthMm, ref.depthMm, 1e-12, 0.0, "la misma abolladura")
	assert_near(d.collapseN, Dent.collapse_load(264.0, 0.7), 1e-12, 0.0, "el mismo colapso")
	# un cuerpo de cientos de kilos no cabe en el muelle de la pata: la chapa se lleva el resto, hasta su hueco
	var big := MC.dent_of(T("coche"), 5000.0, 0.0, 2, 60.0, false)
	assert_true(big.limbSaturated, "la pata hace tope")
	assert_true(big.bottomsOut and big.depthMm == 60.0, "llega al fondo del hueco (60 mm)")
	var deep := MC.dent_of(T("coche"), 5000.0, 0.0, 2, 1000.0, false)
	var e_panel := 2500.0 * 1000.0 - 0.5 * Physics.MODEL.limbStiffness * MC.LIMB_STROKE_MM * MC.LIMB_STROKE_MM
	assert_near(deep.depthMm, Dent.depth_for_energy(264.0, 0.7, e_panel), 1e-12, 0.0, "sin tope: la energía que no cabe en la pata")
	assert_false(MC.dent_of(T("cocheplastico"), 500.0, 0.0, 2, 60.0, false).applies, "el plástico no se abolla")
	assert_false(MC.dent_of(T("coche"), 500.0, 0.0, 2, 60.0, true).applies, "lo perforado no cuenta")


func test_el_parabrisas_se_agrieta_con_un_cuerpo_pesado_y_con_un_ave_rapida() -> void:
	var tiger := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
	assert_true(tiger.windshield.cracked, "el tigre agrieta el laminado")
	assert_true(tiger.windshield.penetrationRisk, "y pasa de los 88,7 J de la homologación")
	var owl := MC.impact({ "claw": C("lechuza"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 90.0, "animal_kmh": 40.0, "angle_deg": 180.0, "drop_m": 0.0 })
	assert_true(owl.windshield.cracked, "una lechuza de frente a 130 km/h relativos lo agrieta")
	var slow := MC.impact({ "claw": C("lechuza"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 0.0, "animal_kmh": 5.0, "angle_deg": 0.0, "drop_m": 0.1 })
	assert_false(slow.windshield.cracked, "posándose despacio, no")
	# un oso quieto encima también lo agrieta con su peso; un águila no
	assert_true(MC.setup({ "claw": C("oso"), "target": T("coche"), "zone": "parabrisas" }).windshield.cracked, "oso encima")
	assert_false(MC.setup({ "claw": C("aguila"), "target": T("coche"), "zone": "parabrisas" }).windshield.cracked, "águila encima")


func test_si_persigue_al_coche_se_queda_encima_y_si_cruza_resbala() -> void:
	var chase := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "techo", "v_kmh": 50.0, "animal_kmh": 56.0, "angle_deg": 0.0, "drop_m": 0.5 })
	assert_true(chase.stays, "a casi la misma velocidad, se queda en el techo")
	assert_eq(chase.groundKmh, 0.0, "no cae")
	var cross := MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "techo", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5 })
	assert_false(cross.stays, "cruzando, el techo se le escapa por debajo")
	assert_true(cross.groundKmh > 0.0 and cross.groundKmh <= cross.vRelKmh + 1e-9, "cae con parte de la velocidad")
	var door := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
	assert_false(door.stays, "de una puerta siempre cae")


func test_informe_de_danos_y_textos() -> void:
	var r := MC.impact({ "claw": C("oso"), "target": T("coche"), "zone": "techo", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5 })
	var labels: Array = []
	for row: Array in r.report:
		labels.append(row[0])
		assert_true(String(row[1]).length() > 0, "%s: con texto" % row[0])
	for want: String in ["Golpe", "Marcas", "Profundidad", "Capas", "Perforación", "Abolladura", "Energía", "Animal"]:
		assert_true(labels.has(want), "el informe dice %s" % want)
	assert_true(String(r.vsub).contains("km/h"), "el veredicto dice a qué velocidad cae")
	assert_false(String(r.report[-1][1]).contains("0.0 µm"), "sin longitudes de cero")
	var bird := MC.impact({ "claw": C("aguila"), "target": T("coche"), "zone": "techo", "v_kmh": 90.0, "animal_kmh": 60.0, "angle_deg": 0.0, "drop_m": 0.2 })
	assert_true(bird.landing, "posarse cayendo 20 cm es aterrizar")
	assert_true(String(bird.report[-1][1]).contains("volando"), "un ave no cae: sale volando")
	var strike := MC.impact({ "claw": C("aguila"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 90.0, "animal_kmh": 40.0, "angle_deg": 180.0, "drop_m": 0.0 })
	assert_false(strike.landing, "chocar de frente contra el parabrisas no es aterrizar")
	assert_true(String(strike.report[-1][1]).contains("despedida"), "tras el choque no sale volando: sale despedida")
	var hooked := MC.impact({ "claw": C("tigre"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 })
	assert_true(String(hooked.vsub).contains("se desengancha"), "con las garras clavadas en el plástico, se desengancha")
	assert_true(MC.SAFETY_NOTE.contains("112"), "nota de seguridad vial")


# ── Casuario (unidad 4d) ──

func test_el_casuario_se_ensaya_solo_al_abalanzarse() -> void:
	var cas := C("casuario")
	assert_true(MC.supports(cas), "tiene datos para el coche en marcha")
	assert_true(MC.supports_impact(cas), "se abalanza")
	assert_false(MC.supports_hold(cas), "no se queda encima")
	for id: String in animals():
		assert_true(MC.supports_hold(C(id)) and MC.supports_impact(C(id)), "%s: los dos modos" % id)
	assert_false(MC.supports_hold(C("gato")) or MC.supports_impact(C("gato")), "sin datos, ninguno")
	var s := MC.setup({ "claw": cas, "target": T("coche"), "zone": "techo" })
	assert_false(s.ok, "quieto encima: no")
	assert_eq(s.reason, MC.HOLD_NO_REASON, "con la razón")
	assert_true(String(s.reason).contains("no se agarra") and String(s.reason).contains("vuelco"), s.reason)
	assert_false(MC.hold_report({ "claw": cas, "target": T("coche"), "zone": "capo" }).ok, "hold_report tampoco")
	assert_eq(MC.zones_for(cas), [], "sin zonas donde quedarse")
	assert_eq(MC.impact_zones_for(cas), ["capo", "puerta", "aleta"], "patea el capó, la puerta y la aleta")
	# el resto, todas; a la ventanilla (unidad 4m) solo llega quien la alcanza: el tigre, a cuatro patas, no (window_reach)
	assert_eq(MC.impact_zones_for(C("tigre")), MC.IMPACT_ZONES.keys().filter(func(z: String) -> bool: return z != MC.WINDOW_ZONE), "el resto, todas menos la ventanilla")
	assert_eq(MC.impact_zones_for(C("oso")), MC.IMPACT_ZONES.keys(), "el oso, todas")
	assert_eq(MC.impact_zones_for(C("gato")), [], "sin datos, ninguna")
	for zone: String in ["techo", "parabrisas"]:
		var r := MC.impact({ "claw": cas, "target": T("coche"), "zone": zone })
		assert_false(r.ok, "%s: fuera del alcance de sus patas" % zone)
		assert_true(String(r.reason).contains("patea"), r.reason)


func test_masa_del_casuario_por_sexo() -> void:
	var cas := C("casuario")
	assert_eq(MC.sexes_of(cas), ["hembra", "macho"], "dos sexos")
	assert_eq(MC.sexes_of(C("tigre")), [], "el resto, sin masa por sexo")
	var mk: Dictionary = MC.BODIES.casuario.mass_kg
	assert_eq(MC.mass_of(cas, "hembra"), 58.0, "hembra típica: 58 kg (Grzimek 2003)")
	assert_eq(MC.mass_of(cas, "macho"), 31.5, "macho: centro de 29-34 kg (Grzimek 2003)")
	assert_eq(MC.mass_of(cas), 58.0, "por defecto, la hembra")
	assert_eq(MC.mass_of(cas, "otro"), 58.0, "un sexo desconocido: la de por defecto")
	assert_eq(MC.mass_of(C("tigre")), 220.0, "el resto, la del catálogo")
	for sex: String in mk:
		var b: Dictionary = mk[sex]
		assert_true(b.min <= b.value and b.value <= b.max, "%s: banda" % sex)
		assert_true(String(b.source).length() > 40, "%s: fuente" % sex)
	assert_true(mk.hembra.value > mk.macho.value and mk.hembra.max > mk.macho.max, "la hembra pesa más (Latch 2007)")
	# los once adultos de Westcott & Reid (2002), 40-66 kg, caen dentro de las bandas de los dos sexos
	assert_true(mk.macho.min <= 40.0 and 66.0 <= mk.hembra.max, "las mediciones de Westcott & Reid dentro")
	var r := MC.impact({ "claw": cas, "target": T("coche"), "zone": "puerta", "sex": "macho" })
	assert_eq(r.massKg, 31.5, "el golpe usa la masa del sexo")
	assert_eq(r.sex, "macho", "y lo dice")
	assert_eq(MC.impact({ "claw": C("tigre"), "target": T("coche"), "zone": "puerta" }).sex, null, "el resto, sin sexo")


func test_la_patada_sale_de_los_casos_medidos() -> void:
	# salto: v = √(4·w·f) con w = 45 J por kg de músculo (Henry et al. 2005) y f = 8,498/65,3 de la masa en cada pata
	# (Hutchinson et al. 2015); la misma para cualquier masa
	var v := MC.kick_leap_ms()
	assert_near(v, sqrt(4.0 * 45.0 * 8.498 / 65.3), 1e-12, 0.0, "velocidad del salto")
	assert_near(v, 4.84, 0.002, 0.0, "~4,84 m/s")
	assert_near(MC.kick_leap_ms(true), sqrt(4.0 * 67.5 * 8.498 / 65.3), 1e-12, 0.0, "con el trabajo máximo esperable")
	# fuerza de la pata: 5,1 pesos corporales (4,2-6,0), la patada medida del secretario (Portugal et al. 2016)
	assert_near(MC.kick_force_n(58.0), 5.1 * 58.0 * MC.G, 1e-12, 0.0, "5,1 pesos")
	assert_true(MC.kick_force_n(58.0, "min") < MC.kick_force_n(58.0) and MC.kick_force_n(58.0) < MC.kick_force_n(58.0, "max"), "banda")
	assert_true(String(MC.KICK.force_bw.source).contains("Portugal"), "fuente de la fuerza")
	assert_true(String(MC.KICK.work_j_per_kg.source).contains("Henry"), "fuente del salto")
	assert_true(String(MC.KICK.muscle_fraction.source).contains("Hutchinson"), "fuente de la masa muscular")
	# en el golpe: la normal es la del salto, sea cual sea la carrera; la abolladura, la de la fuerza máxima de la pata
	for k: Array in [[50.0, 0.0, 90.0], [50.0, 40.0, 90.0], [90.0, 30.0, 0.0], [0.0, 20.0, 180.0]]:
		for zone: String in MC.KICK_ZONES:
			var r := MC.impact({ "claw": C("casuario"), "target": T("coche"), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2] })
			var tag := "%s %s" % [zone, k]
			assert_true(r.ok, "%s: se ensaya" % tag)
			assert_near(r.vNormalKmh, v * MC.KMH, 1e-12, 0.0, "%s: la normal es la del salto" % tag)
			assert_eq(r.attack, "patada", "%s: ataque" % tag)
			assert_near(r.dent.peakN, MC.kick_force_n(58.0), 1e-9, 0.0, "%s: la pata llega a su fuerza máxima" % tag)
			assert_true(r.dent.capped and r.kick.capped, "%s: con tope" % tag)
			assert_near(r.dent.depthMm, Dent.depth_for_load(264.0, 0.7, r.dent.peakN), 1e-9, 1e-12, "%s: la abolladura de esa fuerza (unidad 1f)" % tag)
			assert_false(r.stays, "%s: no se queda encima" % tag)
			assert_eq(r.hold, null, "%s: sin hold" % tag)
			assert_false(r.landing, "%s: una patada no es aterrizar" % tag)
			assert_eq(r.marks.count, 1 if r.vTangKmh > 0.0 else 0, "%s: un surco, el de la daga, si el coche se mueve respecto a él" % tag)
			# el contacto dura lo que tarda la pata en frenar la normal de todo el cuerpo: t = μ_red·v/F
			assert_near(r.kick.contactS, r.reducedMassKg * v / r.dent.peakN, 1e-12, 0.0, "%s: duración" % tag)


func test_la_hembra_abolla_mas_y_la_queratina_no_corta_la_chapa() -> void:
	for zone: String in MC.KICK_ZONES:
		for tid: String in METAL_CARS:
			var p := { "claw": C("casuario"), "target": T(tid), "zone": zone, "v_kmh": 50.0, "animal_kmh": 0.0, "angle_deg": 90.0 }
			var f := MC.impact(p)
			p["sex"] = "macho"
			var m := MC.impact(p)
			var tag := "%s en %s" % [zone, tid]
			assert_true(f.dent.depthMm > m.dent.depthMm, "%s: la hembra abolla más" % tag)
			assert_true(m.dent.visible, "%s: el macho también abolla" % tag)
			for r: Dictionary in [f, m]:
				assert_true(r.marks.depthUm <= PAINT_UM + 1e-6, "%s: la daga raya hasta el metal, sin cortarlo" % tag)
				assert_false(r.puncture.through, "%s: no perfora" % tag)
				assert_eq(r.clawFracture, null, "%s: la queratina no se evalúa en la rotura" % tag)
	var plastic := MC.impact({ "claw": C("casuario"), "target": T("cocheplastico"), "zone": "aleta", "v_kmh": 50.0, "animal_kmh": 0.0 })
	assert_true(plastic.puncture.through and plastic.embedded, "la daga atraviesa la aleta de plástico")
	assert_eq(plastic.verdict, "PERFORA EL PLÁSTICO", "veredicto")
	assert_true(String(plastic.vsub).begins_with("la daga atraviesa"), plastic.vsub)


func test_informe_de_la_patada() -> void:
	var r := MC.impact({ "claw": C("casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 0.0 })
	var rows := {}
	for row: Array in r.report:
		rows[row[0]] = row[1]
	assert_true(rows.has("Patada") and String(rows.Patada).contains("5.1 veces su peso"), "fila de la patada: %s" % rows.get("Patada"))
	assert_true(String(rows.Marcas).begins_with("1 surco de"), "un surco: %s" % rows.Marcas)
	assert_true(String(rows.Abolladura).contains("bajo el pie"), rows.Abolladura)
	assert_true(String(rows.Animal).begins_with("rebota"), rows.Animal)
	assert_true(String(r.vsub).contains("un surco hasta el metal"), r.vsub)
	var still := MC.impact({ "claw": C("casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 0.0, "animal_kmh": 0.0 })
	assert_true(String(still.vsub).contains("se queda junto al coche"), "con el coche parado, no lo arrastra: %s" % still.vsub)


# ── Garras experimentales (unidad 4d) ──

func test_con_la_misma_forma_y_fuerza_una_garra_mas_dura_nunca_raya_menos_hondo() -> void:
	# solo cambia la dureza (el mismo módulo): la punta cede menos (Contact.hardness_efficiency) y el surco nunca es menos
	# hondo
	var hvs := [30.0, 80.0, 150.0, 200.0, 550.0, 1100.0, 2000.0, 10000.0]
	for id: String in animals() + ["casuario"]:
		for tid: String in ["coche", "cocheclasico", "cochealu", "cocheplastico", "vidrio"]:
			for f: float in [1.0, 10.0, 100.0, 1000.0]:
				var prev := -1.0
				for hv: float in hvs:
					var inl := { "id": "prueba", "name": "Prueba", "short": "Prueba", "hv": hv, "mohs": 5.0, "E": 400.0, "area": 0.1, "alpha": 50.0 }
					var d: float = Physics.compute(MC._lab_params(C(id), T(tid), { "force": f, "length": 1000.0, "inlay": inl })).depthUm
					assert_true(d >= prev - 1e-9, "%s en %s con %s N: %s HV raya %s µm, menos que el anterior (%s)" % [id, tid, f, hv, d, prev])
					prev = d
	# y entre los materiales del catálogo, cuando uno es a la vez más duro y más rígido. (Con distinto módulo, el más
	# rígido plastifica antes el contacto, Hertz: el cuarzo, 1100 HV y 95 GPa, raya algo menos que la hematites, 1000 HV
	# y 200 GPa, con poca fuerza.)
	var inls: Array = []
	for i: Dictionary in Data.INLAYS:
		if i.id != "none":
			inls.append(i)
	for id: String in ["aguila", "tigre", "oso", "casuario"]:
		for tid: String in ["coche", "cocheplastico", "vidrio"]:
			for f: float in [1.0, 30.0, 1000.0]:
				var depth := {}
				for i: Dictionary in inls:
					depth[i.id] = Physics.compute(MC._lab_params(C(id), T(tid), { "force": f, "length": 1000.0, "inlay": i })).depthUm
				for a: Dictionary in inls:
					for b: Dictionary in inls:
						if float(a.hv) >= float(b.hv) and float(a.E) >= float(b.E):
							assert_true(float(depth[a.id]) >= float(depth[b.id]) - 1e-9, "%s en %s con %s N: %s raya menos que %s" % [id, tid, f, a.id, b.id])


func test_las_garras_duras_perforan_la_chapa_y_quedan_clavadas() -> void:
	var land := { "claw": C("aguila"), "target": T("coche"), "zone": "techo", "v_kmh": 90.0, "animal_kmh": 60.0, "angle_deg": 0.0, "drop_m": 0.2 }
	var ker := MC.impact(land)
	land["inlay"] = "diamante"
	var dia := MC.impact(land)
	assert_false(ker.puncture.through or ker.embedded, "la queratina no perfora el techo")
	assert_true(dia.puncture.through, "el diamante lo perfora")
	assert_true(dia.embedded, "y queda clavado")
	assert_eq(dia.verdict, "PERFORA LA CHAPA", "veredicto")
	assert_eq(dia.inlay, "diamante", "material en el resultado")
	# quieto encima con las garras clavadas en la chapa: el anclaje pasa a ser el agarre (ave) o el gancho (mamífero),
	# como en el plástico, y nunca se suelta antes que sin clavarlas
	for id: String in animals():
		for tid: String in METAL_CARS:
			var post: String = MC.POSTURES[MC.BODIES[id].kind][0]
			var free := MC.setup({ "claw": C(id), "target": T(tid), "zone": "techo", "posture": post, "inlay": "tungsteno" })
			var stuck := MC.setup({ "claw": C(id), "target": T(tid), "zone": "techo", "posture": post, "inlay": "tungsteno", "embedded": true })
			var tag := "%s en %s" % [id, tid]
			assert_eq(free.anchor, "friccion", "%s: sin clavar, fricción" % tag)
			assert_true(stuck.embedded, "%s: el tungsteno corta el metal" % tag)
			assert_eq(stuck.anchor, "agarre" if MC.BODIES[id].kind == "ave" else "gancho", "%s: clavado, anclaje" % tag)
			assert_true(MC.detach(stuck).kmh >= MC.detach(free).kmh - 1e-6, "%s: clavado nunca se suelta antes" % tag)
			assert_eq(stuck.inlay, "tungsteno", "%s: material en el ensayo" % tag)
			# la queratina y el oro (30 HV) no cortan el metal: aunque se pida, no se clavan
			for soft: String in ["none", "oro"]:
				var s := MC.setup({ "claw": C(id), "target": T(tid), "zone": "techo", "posture": post, "inlay": soft, "embedded": true })
				assert_false(s.embedded, "%s: %s no se clava en el metal" % [tag, soft])
				assert_eq(s.anchor, "friccion", "%s: %s, fricción" % [tag, soft])


func test_la_rotura_de_las_garras_reforjadas_en_el_golpe() -> void:
	var door := { "claw": C("tigre"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 }
	var res := {}
	for inl: String in ["none", "zafiro", "diamante", "acero", "vidrio"]:
		var p := door.duplicate()
		p["inlay"] = inl
		res[inl] = MC.impact(p)
	assert_eq(res.none.clawFracture, null, "la queratina no entra en la rotura")
	var sap: Dictionary = res.zafiro.clawFracture
	assert_true(sap.breaks, "el zafiro se rompe contra la puerta")
	# la carga es la del instante que más la flexa (claw_load): la resistencia del motor con la punta a esa profundidad,
	# aplicada donde empuja la chapa
	var tip := MC.claw_tip(C("tigre"), Data.find_by_id(Data.INLAYS, "zafiro"))
	var sheet: Dictionary = Physics.sheet_of(T("coche"))
	assert_true(["pintura", "indentacion", "perforacion", "marcas"].has(sap.forceBasis), "fase: %s" % sap.forceBasis)
	if sap.forceBasis != "marcas":
		assert_near(sap.normalN, MC.sheet_resistance_n(tip, T("coche"), sap.depthMm), 1e-12, 0.0, "la resistencia del motor en ese punto")
	assert_near(sap.loadXmm, MC.load_point_mm(sheet, sap.depthMm), 1e-12, 0.0, "donde empuja la chapa")
	assert_true(float(sap.depthMm) <= float(res.zafiro.puncture.depthUm) / 1000.0 + 1e-12, "en el camino de la punta")
	assert_near(sap.lateralN, res.zafiro.mu * sap.normalN, 1e-12, 0.0, "carga lateral: la fricción al resbalar")
	assert_true(float(res.diamante.clawFracture.brokenMm) < float(sap.brokenMm), "el diamante pierde menos punta que el zafiro")
	assert_true(res.acero.clawFracture.bends and not res.acero.clawFracture.breaks, "el acero se dobla, no estalla")
	assert_eq(res.vidrio.clawFracture.mode, "parte", "el vidrio se parte por la base")
	assert_true(String(res.zafiro.vsub).contains("las garras de zafiro se mellan"), res.zafiro.vsub)
	var rows := {}
	for row: Array in res.zafiro.report:
		rows[row[0]] = row[1]
	assert_true(rows.has("Garras"), "el informe dice qué les pasa a las garras")
	# fuera del metal no se evalúa (el plástico cede mucho antes; el parabrisas es otro modelo)
	for tz: Array in [["cocheplastico", "aleta"], ["coche", "parabrisas"]]:
		var p := door.duplicate()
		p.merge({ "target": T(tz[0]), "zone": tz[1], "inlay": "zafiro" }, true)
		var r := MC.impact(p)
		assert_true(r.ok and r.zone == tz[1] and r.target == tz[0], "%s: el ensayo pedido" % [tz])
		assert_eq(r.clawFracture, null, "%s: sin rotura" % [tz])
	# de frente, sin nada que resbalar (el coche parado y el casuario pateando la puerta), la daga no se dobla ni se rompe
	var still := MC.impact({ "claw": C("casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 0.0, "animal_kmh": 0.0, "inlay": "vidrio" })
	assert_eq(still.clawFracture.lateralN, 0.0, "sin carga lateral")
	assert_eq(still.clawFracture.mode, "intacta", "de frente no se rompe")
	assert_eq(still.verdict, "PERFORA LA CHAPA", "pero la perfora")
	# el oro (30 HV), más blando que la chapa, no la corta: cede por la punta, como la queratina, y no se evalúa su rotura
	var gp := door.duplicate()
	gp["inlay"] = "oro"
	var gold := MC.impact(gp)
	assert_eq(gold.clawFracture, null, "el oro no entra en la rotura")
	assert_false(gold.puncture.through or gold.embedded, "ni perfora ni se clava")
	var grows := {}
	for row: Array in gold.report:
		grows[row[0]] = row[1]
	assert_true(String(grows.get("Perforación", "")).contains("más blandas que la chapa"), "el informe dice por qué: %s" % grows.get("Perforación"))


func test_la_resistencia_de_la_chapa_es_la_del_motor() -> void:
	# sheet_resistance_n rehace la resistencia del motor en la punción con golpe: su trabajo hasta la profundidad final,
	# con el mismo integrador y los mismos tramos (Contact.absorbed_work), es el que dio la punción
	var n := 0
	for id: String in ["aguila", "halcon", "tigre", "oso"]:
		for inl: String in ["zafiro", "acero", "diamante", "vidrio"]:
			for tid: String in METAL_CARS:
				for k: Array in [["puerta", 50.0, 40.0, 90.0, 0.5], ["techo", 90.0, 60.0, 0.0, 0.2], ["capo", 30.0, 30.0, 180.0, 0.5]]:
					var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": k[0], "v_kmh": k[1], "animal_kmh": k[2], "angle_deg": k[3], "drop_m": k[4], "inlay": inl })
					if r.puncture == null:
						continue
					var tip := MC.claw_tip(C(id), Data.find_by_id(Data.INLAYS, inl))
					var sheet: Dictionary = Physics.sheet_of(T(tid))
					var breaks := [float(sheet.from), float(sheet.to)]
					var h_cap := Contact.depth_for_radius(tip, float(tip.amax))
					if h_cap > float(sheet.to):
						breaks.append(h_cap)
					var target := T(tid)
					var res := func(h: float) -> float: return MC.sheet_resistance_n(tip, target, h)
					# unidad 4p: si la punta topa con el fondo del hueco (el que le deja la abolladura) cuando la garra ya tiene su
					# ancho, el trabajo es el del motor, que la lleva hasta su largo (la chapa ya no la frena; unidad 4o)
					var h_end := float(r.puncture.depthUm) / 1000.0
					if r.puncture.bottoms and h_end >= h_cap:
						h_end = float(tip.reach)
					var w := Contact.absorbed_work(res, h_end, breaks)
					assert_near(w, float(r.puncture.workJ), 1e-12, 1e-15, "%s de %s contra %s (%s): el trabajo de la punción" % [id, inl, tid, k[0]])
					n += 1
	assert_true(n > 100, "casos comprobados: %d" % n)


func test_la_carga_de_la_garra_es_la_del_instante_mas_cargado() -> void:
	# claw_load recorre el camino de la punta: ningún punto del camino (muestreo denso de 4000 puntos) flexa más la garra
	# que el elegido; la carga se aplica donde empuja la chapa (load_point_mm) y su valor es la resistencia del motor
	for id: String in ["aguila", "tigre", "oso", "casuario"]:
		for inl: String in ["zafiro", "tungsteno", "acero"]:
			for zone: String in ["puerta", "capo"]:
				var r := MC.impact({ "claw": C(id), "target": T("coche"), "zone": zone, "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "drop_m": 0.5, "inlay": inl })
				var entry: Dictionary = Data.find_by_id(Data.INLAYS, inl)
				var ld: Dictionary = MC.claw_load(C(id), entry, T("coche"), r.puncture)
				var tip := MC.claw_tip(C(id), entry)
				var reach: float = tip.reach
				var sheet: Dictionary = Physics.sheet_of(T("coche"))
				var tag := "%s de %s en %s" % [id, inl, zone]
				assert_near(ld.n, MC.sheet_resistance_n(tip, T("coche"), ld.depthMm), 1e-12, 0.0, "%s: la resistencia del motor" % tag)
				assert_near(ld.xLoadMm, MC.load_point_mm(sheet, ld.depthMm), 1e-12, 0.0, "%s: donde empuja la chapa" % tag)
				var best: float = float(ld.n) * float(CF.peak(tip, reach, ld.xLoadMm).factor)
				var h_end := minf(float(r.puncture.depthUm) / 1000.0, reach)
				for i in 4000:
					var h := h_end * float(i + 1) / 4000.0
					var key: float = MC.sheet_resistance_n(tip, T("coche"), h) * float(CF.peak(tip, reach, MC.load_point_mm(sheet, h)).factor)
					assert_true(key <= best * (1.0 + 1e-3), "%s: a %s mm flexa más (%s) que el instante elegido (%s)" % [tag, h, key, best])
				# y el golpe usa esa carga
				if r.clawFracture != null and r.clawFracture.forceBasis != "marcas":
					assert_near(r.clawFracture.normalN, ld.n, 1e-12, 0.0, "%s: la del golpe" % tag)


func test_las_garras_clavadas_no_sujetan_mas_de_lo_que_aguantan_de_lado() -> void:
	var base := { "claw": C("aguila"), "target": T("coche"), "zone": "techo", "posture": "plegadas", "embedded": true }
	var sheet: Dictionary = Physics.sheet_of(T("coche"))
	for inl: String in ["tungsteno", "zafiro", "diamante", "vidrio", "acero", "titanio"]:
		var p := base.duplicate()
		p["inlay"] = inl
		var s := MC.setup(p)
		var ch: Dictionary = s.clawHoldN
		var tip := MC.claw_tip(C("aguila"), Data.find_by_id(Data.INLAYS, inl))
		var st: Dictionary = CF.strength(inl)
		# la banda desfavorable: las cuatro garras con la punta recién asomada por detrás de la chapa y la resistencia mínima;
		# manda lo menor de la flexión (la carga a media chapa), el cortante de la garra (en la cara de fuera del metal, por
		# donde ya ha pasado toda la carga: a una chapa entera del vértice) y la chapa alrededor del agujero (unidad 4p)
		var x_min := MC.load_point_mm(sheet, float(sheet.to))
		var x_face := float(sheet.to) - float(sheet.from)
		var f_min: float = CF.peak(tip, tip.reach, x_min).factor
		var lo := minf(float(st.min) / f_min, minf(CF.shear_limit_n(tip, x_face, float(st.min), String(st.kind)),
			MC.sheet_bearing_n(T("coche"), 2.0 * CF.section_radius(tip, x_min), "min")))
		assert_near(ch.min, 4.0 * lo, 1e-12, 0.0, "%s: lo que aguantan recién asomadas" % inl)
		for key: String in ["value", "min", "max"]:
			assert_true(float(s.anchorN[key]) <= float(ch[key]) + 1e-9, "%s: el anclaje (%s) no pasa de lo que aguantan" % [inl, key])
		# más clavadas, más aguantan: el borde del agujero queda más arriba, donde la garra es más gruesa
		var prev := 0.0
		for e: float in [1.0, 2.0, 5.0, 10.0, 20.0, 35.0]:
			var c2: Dictionary = MC.claws_hold_n(C("aguila"), Data.find_by_id(Data.INLAYS, inl), T("coche"), 4, e)
			assert_true(float(c2.value) >= prev * (1.0 - 1e-12), "%s: clavadas %s mm no aguantan menos" % [inl, e])
			prev = c2.value
	# el vidrio, frágil, recién asomado aguanta poco: la banda desfavorable baja hasta lo que da la fricción, pero nunca
	# se suelta antes que sin clavar
	var gl := base.duplicate()
	gl["inlay"] = "vidrio"
	var glass := MC.setup(gl)
	gl["embedded"] = false
	var loose := MC.setup(gl)
	assert_true(float(glass.anchorN.min) < 10.0, "el vidrio recién asomado sujeta menos de 10 N: %s" % glass.anchorN.min)
	assert_true(MC.detach(glass).minKmh >= MC.detach(loose).minKmh - 1e-6, "clavado nunca se suelta antes")
	# sin resistencia medida (hematites), queratina o plástico: no hay tope que calcular
	var hp := base.duplicate()
	hp["inlay"] = "hematites"
	assert_eq(MC.setup(hp).clawHoldN, null, "hematites: sin datos, sin tope")
	assert_eq(MC.setup(base).clawHoldN, null, "queratina: sin tope")
	hp["inlay"] = "zafiro"
	hp["target"] = T("cocheplastico")
	hp["zone"] = "capo"
	assert_eq(MC.setup(hp).clawHoldN, null, "en el plástico: sin tope")


func test_material_de_garra_desconocido() -> void:
	var p := { "claw": C("aguila"), "target": T("coche"), "zone": "techo", "inlay": "kriptonita" }
	for r: Dictionary in [MC.impact(p), MC.setup(p), MC.hold_report(p)]:
		assert_false(r.ok, "no se ensaya")
		assert_true(String(r.reason).contains("kriptonita"), r.reason)


func test_sin_material_da_exactamente_lo_de_siempre() -> void:
	# inlay «none» (la queratina) es el camino de siempre: pedirlo o no pedirlo da lo mismo, al bit
	var cases: Variant = load_json(SPEC)
	for c: Dictionary in cases:
		if String(c.input.get("inlay", "none")) != "none" or c.input.claw == "casuario":
			continue
		var p := _input(c.input)
		var q := p.duplicate()
		q["inlay"] = "none"
		var kind: String = c.input.get("kind", "hold")
		var a: Dictionary = MC.impact(p) if kind == "impact" else MC.hold_report(p)
		var b: Dictionary = MC.impact(q) if kind == "impact" else MC.hold_report(q)
		assert_true(same(a, b), "%s: sin material = con «none»" % c.id)
		assert_eq(String((a.setup if kind == "hold" else a).inlay), "none", "%s: queratina" % c.id)


func test_la_energia_se_conserva_con_garras_reforjadas_y_patadas() -> void:
	var combos := [[50.0, 40.0, 90.0, 0.5], [90.0, 60.0, 0.0, 0.2], [0.0, 0.0, 90.0, 0.0]]
	for id: String in animals() + ["casuario"]:
		for inl: String in ["none", "zafiro", "acero"]:
			for tid: String in ["coche", "cochealu", "cocheplastico"]:
				for zone: String in MC.impact_zones_for(C(id)):
					for k: Array in combos:
						var r := MC.impact({ "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2], "drop_m": k[3], "inlay": inl })
						var tag := "%s de %s contra %s (%s, %s)" % [id, inl, tid, zone, k]
						var e: Dictionary = r.energy
						var sum := 0.0
						for t: Dictionary in e.terms:
							assert_true(float(t.j) >= 0.0, "%s: %s no es negativo" % [tag, t.id])
							sum += float(t.j)
						assert_near(sum, e.totalJ, 1e-9, 1e-9, "%s: los términos suman el total" % tag)
						assert_near(e.totalJ, r.energyJ, 1e-9, 1e-9, "%s: el total es ½·m·v_rel²" % tag)
						assert_near(e.punctureJ + e.panelJ + e.animalJ, r.normalJ, 1e-9, 1e-9, "%s: la normal que se disipa" % tag)
						assert_near(e.clawsJ, e.punctureJ + e.tearJ, 1e-12, 1e-12, "%s: las garras, punción y desgarro" % tag)
						var vn: float = r.vNormalKmh / 3.6
						assert_near(e.carJ, 0.5 * (r.massKg - r.reducedMassKg) * vn * vn, 1e-9, 1e-9, "%s: el resto empuja al coche" % tag)


# ── Defensa (unidad 4d): el animal asustado aprieta con toda su fuerza ──

func test_la_fuerza_de_defensa_sale_de_las_mediciones() -> void:
	# aves: el agarre máximo medido de un pie (claws_v2.gd, Sustaita & Hertel 2010), el mismo del anclaje; cada talón
	# aprieta con él contra el del lado contrario
	for id: String in RAPTORS:
		var d: Dictionary = MC.defense_force(C(id))
		var g := ClawsV2.band(ClawsV2.apply(C(id)), "force")
		assert_eq(d.value, float(g.value), "%s: el agarre medido" % id)
		assert_eq(d.min, float(g.min), "%s: banda baja" % id)
		assert_eq(d.max, float(g.max), "%s: banda alta" % id)
		assert_eq(d.perClaw.value, d.value, "%s: la pinza, en cada talón" % id)
		assert_eq(d.per, "pie", "%s: por pie" % id)
		assert_true(String(d.source).length() > 40, "%s: fuente" % id)
	# tigre y oso: la sección fisiológica del flexor profundo de los dedos (Martens et al. 2023) por la tensión específica
	# (Powell et al. 1984), repartida entre los cinco dedos
	for id: String in MAMMALS:
		var d: Dictionary = MC.defense_force(C(id))
		var m: float = C(id).mass
		var root := V8.js_pow(10.0, -1.34 + 1.34 * V8.js_log10(m * 1000.0) / 3.0)
		assert_near(d.pcsaCm2, root * root, 1e-12, 0.0, "%s: la recta de Martens et al." % id)
		assert_near(d.value, root * root * 22.5, 1e-12, 0.0, "%s: 22,5 N/cm²" % id)
		assert_near(d.min, root * root * 15.4, 1e-12, 0.0, "%s: 15,4 N/cm² (músculo lento)" % id)
		assert_near(d.perClaw.value, d.value / 5.0, 1e-12, 0.0, "%s: entre los cinco dedos" % id)
		assert_eq(d.per, "mano", "%s: por mano" % id)
		# del orden de su peso por mano: la recta crece algo menos que la masa (PCSA ∝ M^0,89)
		var bw: float = float(d.value) / (m * MC.G)
		assert_true(bw > 1.0 and bw < 1.5, "%s: %s veces su peso por mano" % [id, bw])
		assert_eq(d.quality, "estimate", "%s: estimación" % id)
		assert_true(String(d.source).contains("Caso medido más parecido") and String(d.source).contains("Suposición"), "%s: caso medido y suposición" % id)
		assert_true(String(d.source).contains("Martens") and String(d.source).contains("Powell"), "%s: fuentes" % id)
	assert_near(MC.defense_force(C("tigre")).value, 2784.5, 0.001, 0.0, "tigre de 220 kg: ~2,8 kN por mano")
	# casuario: su patada, toda en la daga
	var dc: Dictionary = MC.defense_force(C("casuario"))
	assert_near(dc.value, MC.kick_force_n(58.0), 1e-12, 0.0, "casuario: la patada")
	assert_near(MC.defense_force(C("casuario"), "macho").value, MC.kick_force_n(31.5), 1e-12, 0.0, "el macho, con su masa")
	assert_eq(dc.perClaw.value, dc.value, "toda en la daga")
	assert_eq(MC.defense_force(C("gato")), null, "sin datos: null")


func test_la_defensa_nunca_da_menos_fuerza_ni_menos_marca_ni_menos_anclaje_que_el_reposo() -> void:
	for id: String in animals():
		var kind: String = MC.BODIES[id].kind
		var post: String = MC.POSTURES[kind][0]
		var rest_claw: float = float(C(id).mass) * MC.G / float(MC.BODIES[id].contact)
		for tid: String in ["coche", "cocheclasico", "cochealu", "cocheplastico"]:
			for zone: String in MC.zones_for(C(id)):
				var p := { "claw": C(id), "target": T(tid), "zone": zone, "posture": post, "v_kmh": 90.0 }
				var a := MC.hold_report(p)
				p["defense"] = true
				var b := MC.hold_report(p)
				var tag := "%s en %s (%s)" % [id, tid, zone]
				assert_eq(a.defense, null, "%s: en reposo, sin defensa" % tag)
				var d: Dictionary = b.defense
				assert_true(float(d.perClawN) >= rest_claw - 1e-9, "%s: cada garra aprieta al menos con su peso" % tag)
				assert_true(float(b.marks.depthUm) >= float(a.marks.depthUm) - 1e-9, "%s: el desgarro nunca es menos hondo que la marca en reposo" % tag)
				for key: String in ["value", "min", "max"]:
					assert_true(float(b.setup.anchorN[key]) >= float(a.setup.anchorN[key]) - 1e-9, "%s: anclaje (%s)" % [tag, key])
				assert_true(b.detach.kmh >= a.detach.kmh - 1e-6, "%s: asustado nunca se suelta antes" % tag)
				assert_eq(b.setup.mu, a.setup.mu, "%s: la fricción es la de su peso" % tag)
				# clavado implica anclaje
				if d.stuck:
					assert_true(b.setup.anchor != "friccion" and float(b.setup.anchorN.value) > 0.0 and b.setup.embedded, "%s: clavado, anclaje" % tag)
				# sin nada que agarrar ni donde clavarse, solo el arado de unas garras hundidas más que en reposo (rake_n) puede
				# sujetarlo más; si no, el mismo despegue. Con los datos más desfavorables (el arado es 0), siempre el mismo.
				if b.setup.anchor == "friccion":
					var rk: Variant = d.rakeN
					if rk == null or float(rk.value) == 0.0:
						assert_eq(b.detach.kmh, a.detach.kmh, "%s: sin arado de más, el mismo despegue" % tag)
					assert_eq(b.detach.minKmh, a.detach.minKmh, "%s: con los datos más desfavorables, el mismo despegue" % tag)
					assert_eq(rk == null, MC.ZONES[zone].surface == "vidrio", "%s: arado en la pintura, no en el vidrio" % tag)


func test_en_defensa_la_queratina_no_raya_ni_agrieta_el_vidrio_por_contacto() -> void:
	for id: String in animals():
		var post: String = MC.POSTURES[MC.BODIES[id].kind][0]
		var p := { "claw": C(id), "target": T("coche"), "zone": "parabrisas", "posture": post }
		var a := MC.hold_report(p)
		p["defense"] = true
		var d: Dictionary = MC.hold_report(p).defense
		assert_eq(d.tear.depthUm, 0.0, "%s: la queratina no raya el vidrio" % id)
		assert_false(d.windshield.contactCracks, "%s: ni lo agrieta por contacto" % id)
		assert_eq(d.windshield.cracked, a.setup.windshield.cracked, "%s: solo su peso lo flexa" % id)
		assert_eq(d.verdict, "AGRIETA EL PARABRISAS" if d.windshield.cracked else "NO RAYA EL VIDRIO", "%s: veredicto" % id)
	# el oso agrieta el laminado con su peso (~637 N por pata contra ~517 N), asustado o no
	var bear := MC.hold_report({ "claw": C("oso"), "target": T("coche"), "zone": "parabrisas", "posture": "tumbado", "defense": true })
	assert_true(bear.defense.windshield.cracked and not bear.defense.windshield.contactCracks, "el oso lo agrieta con su peso")
	# unas garras reforjadas más duras que el vidrio sí lo rayan y lo agrietan por contacto (Fracture, unidad 1f)
	var dia := MC.hold_report({ "claw": C("aguila"), "target": T("coche"), "zone": "parabrisas", "posture": "plegadas", "inlay": "diamante", "defense": true })
	assert_true(float(dia.defense.tear.depthUm) > 0.0, "el diamante raya el vidrio")
	assert_true(dia.defense.windshield.contactCracks and dia.defense.windshield.cracked, "y lo agrieta al rayarlo")
	var hit := MC.impact({ "claw": C("aguila"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 60.0, "animal_kmh": 58.0, "angle_deg": 0.0, "drop_m": 0.02, "inlay": "diamante" })
	var soft := MC.impact({ "claw": C("aguila"), "target": T("coche"), "zone": "parabrisas", "v_kmh": 60.0, "animal_kmh": 58.0, "angle_deg": 0.0, "drop_m": 0.02 })
	assert_true(hit.windshield.cracked, "en el golpe, las garras de diamante lo agrietan por contacto")
	assert_false(soft.windshield.cracked, "el mismo golpe con queratina no lo agrieta")


func test_en_defensa_se_clava_en_el_plastico_y_en_la_chapa_lisa_no() -> void:
	# el águila asustada sobre el capó de plástico: el desgarro pasa de la pintura, se queda clavada y se sujeta con su
	# agarre medido, como con las garras clavadas en un golpe
	var p := { "claw": C("aguila"), "target": T("cocheplastico"), "zone": "capo", "posture": "plegadas" }
	var a := MC.hold_report(p)
	p["defense"] = true
	var b := MC.hold_report(p)
	assert_eq(a.setup.anchor, "friccion", "en reposo, fricción")
	assert_true(b.defense.stuck and b.defense.stuckIn == "plastico", "asustada, se clava en el plástico")
	assert_eq(b.defense.verdict, "SE QUEDA CLAVADA", "veredicto (el águila, femenino)")
	assert_eq(b.setup.anchor, "agarre", "anclaje: su agarre")
	assert_near(b.setup.anchorN.value, 2.0 * float(ClawsV2.band(ClawsV2.apply(C("aguila")), "force").value), 1e-9, 0.0, "2 pies × el agarre")
	assert_true(b.detach.kmh > a.detach.kmh, "se suelta más tarde")
	# en la chapa de acero la queratina no se clava: desgarra hasta el metal. Con su peso ya araba la pintura hasta el
	# metal, así que asustada no la ara más hondo: la fricción es la de su peso y se suelta igual
	var q := { "claw": C("aguila"), "target": T("coche"), "zone": "techo", "posture": "plegadas", "defense": true }
	var steel := MC.hold_report(q)
	assert_false(steel.defense.stuck, "no se clava en el acero")
	assert_eq(steel.defense.verdict, "DESGARRA HASTA EL METAL", "desgarra hasta el metal")
	assert_eq(steel.setup.anchor, "friccion", "sin anclaje")
	assert_eq(steel.defense.rakeN.value, 0.0, "no ara más hondo que en reposo")
	assert_true(String(steel.defense.vsub).contains("la fricción es la de su peso"), steel.defense.vsub)
	q.erase("defense")
	assert_eq(steel.detach.kmh, MC.hold_report(q).detach.kmh, "el mismo despegue")
	# la lechuza, que en reposo solo araña el barniz, asustada lo desgarra hasta el metal: para arrastrarla, sus dos garras
	# que tiran hacia atrás tienen que arar la pintura (Bowden & Tabor: F = H·A, con la sección de un surco en V)
	var owl_p := { "claw": C("lechuza"), "target": T("coche"), "zone": "techo", "posture": "plegadas" }
	var owl_a := MC.hold_report(owl_p)
	owl_p["defense"] = true
	var owl_b := MC.hold_report(owl_p)
	assert_true(float(owl_a.marks.depthUm) < 20.0 and float(owl_b.marks.depthUm) >= PAINT_UM - 1e-9, "de %s µm a %s µm" % [owl_a.marks.depthUm, owl_b.marks.depthUm])
	var rk: Dictionary = owl_b.defense.rakeN
	var hf: float = Physics.hardness_profile(T("coche")).Hf
	var tear: Dictionary = owl_b.defense.tear
	var rest: Dictionary = owl_a.marks
	# los dos surcos están dentro de la pintura: la sección es la mitad de la anchura por la profundidad
	assert_near(rk.perClawN, hf * 0.5 * float(tear.widthUm) / 1000.0 * float(tear.depthUm) / 1000.0, 1e-12, 0.0, "el surco del desgarro")
	assert_near(rk.restPerClawN, hf * 0.5 * float(rest.widthUm) / 1000.0 * float(rest.depthUm) / 1000.0, 1e-12, 0.0, "el surco de reposo")
	# aran las dos garras que tiran hacia atrás; en reposo araban las cuatro su surco, y eso ya va en la fricción
	assert_eq(rk.claws, 2, "las dos garras que tiran hacia atrás")
	var extra := 2.0 * float(rk.perClawN) - 4.0 * float(rk.restPerClawN)
	assert_near(rk.value, extra, 1e-12, 0.0, "lo que piden de más")
	assert_eq(rk.min, 0.0, "banda baja: la garra se sale del surco")
	assert_near(rk.max, 425.0 / hf * extra, 1e-12, 0.0, "banda alta: la pintura más dura medida")
	assert_false(rk.limited, "la queratina, sin tope de rotura")
	assert_eq(owl_b.setup.anchorN.value, rk.value, "es su anclaje")
	assert_true(float(rk.value) > float(owl_a.setup.mu) * float(C("lechuza").mass) * MC.G, "más que la fricción de su peso")
	assert_true(owl_b.detach.kmh > owl_a.detach.kmh + 30.0, "se suelta bastante más tarde: %s frente a %s km/h" % [owl_b.detach.kmh, owl_a.detach.kmh])
	assert_eq(owl_b.detach.minKmh, owl_a.detach.minKmh, "con los datos más desfavorables, igual")
	assert_true(String(owl_b.defense.vsub).contains("hacerlas arar"), owl_b.defense.vsub)
	# el tigre enganchado en las barras aprieta con sus flexores: más anclaje; en el borde de la ventanilla manda el borde
	# de chapa (edge_hold_n) y la defensa no lo cambia
	var t := { "claw": C("tigre"), "target": T("coche"), "zone": "barras", "posture": "tumbado" }
	var ta := MC.hold_report(t)
	t["defense"] = true
	var tb := MC.hold_report(t)
	assert_near(tb.setup.anchorN.value, 2.0 * float(MC.defense_force(C("tigre")).value), 1e-9, 0.0, "2 manos × sus flexores")
	assert_true(float(tb.setup.anchorN.value) > float(ta.setup.anchorN.value), "más que en reposo")
	var w := { "claw": C("tigre"), "target": T("coche"), "zone": "ventanilla", "posture": "tumbado" }
	var wa := MC.hold_report(w)
	w["defense"] = true
	assert_eq(MC.hold_report(w).setup.anchorN.value, wa.setup.anchorN.value, "el borde de la ventanilla manda")


func test_el_arado_de_las_garras_hundidas_no_pasa_de_lo_que_aprietan_ni_de_lo_que_aguantan() -> void:
	# plough_n: Bowden & Tabor (F = H·A) con la sección de un surco en V y la dureza de cada capa del motor
	var car := T("coche")
	var prof := Physics.hardness_profile(car)
	assert_eq(MC.plough_n(car, 0.0, 100.0), 0.0, "sin surco, nada")
	assert_eq(MC.plough_n(T("vidrio"), 50.0, 100.0), 0.0, "fuera de un coche pintado, nada")
	assert_near(MC.plough_n(car, 80.0, 200.0), float(prof.Hf) * 0.5 * 0.2 * 0.08, 1e-12, 0.0, "en la pintura, H·w·d/2")
	var ap := 0.3 * (0.11 - 0.11 * 0.11 / (2.0 * 0.3))
	assert_near(MC.plough_n(car, 300.0, 300.0), float(prof.Hf) * ap + float(prof.Hs) * (0.5 * 0.3 * 0.3 - ap), 1e-12, 0.0, "en la pintura y en la chapa")
	assert_near(MC.plough_n(car, 80.0, 200.0, 425.0), 425.0 * 0.5 * 0.2 * 0.08, 1e-12, 0.0, "con otra pintura")
	var prev := 0.0
	for um: float in [5.0, 20.0, 60.0, 110.0, 150.0, 400.0, 1000.0]:
		var f := MC.plough_n(car, um, 200.0)
		assert_true(f > prev, "más hondo, más arado (%s µm)" % um)
		prev = f
	# en todos los animales, coches, zonas y materiales: el arado de más va de 0 a su máximo, no pasa de lo que ara cada
	# garra por encima del reposo, de lo que aprieta ni de lo que aguanta de lado una garra reforjada, y es el anclaje
	for id: String in animals():
		var post: String = MC.POSTURES[MC.BODIES[id].kind][0]
		var n: int = MC.BODIES[id].contact
		var weight_claw: float = float(C(id).mass) * MC.G / float(n)
		for tid: String in ["coche", "cochealu", "cocheplastico"]:
			for zone: String in MC.zones_for(C(id)):
				for inl: String in ["none", "oro", "acero", "zafiro", "vidrio", "hematites"]:
					var s := MC.setup({ "claw": C(id), "target": T(tid), "zone": zone, "posture": post, "inlay": inl, "defense": true })
					var tag := "%s de %s en %s (%s)" % [id, inl, tid, zone]
					var rk: Variant = s.defense.rakeN
					if rk == null:
						assert_true(s.anchor != "friccion" or MC.ZONES[zone].surface == "vidrio", "%s: sin arado, anclado o en el vidrio" % tag)
						continue
					assert_eq(s.anchor, "friccion", "%s: el arado, solo en un panel liso" % tag)
					assert_eq(rk.claws, floori(float(n) / 2.0), "%s: las garras que tiran hacia atrás" % tag)
					assert_true(float(rk.value) >= 0.0 and float(rk.min) == 0.0 and float(rk.max) >= float(rk.value), "%s: banda" % tag)
					var per: float = maxf(float(s.defense.perClawBand.value), weight_claw)
					var rest_all := float(n) * float(rk.restPerClawN)
					var most := maxf(float(rk.claws) * minf(float(rk.perClawN), per) - rest_all, 0.0)
					assert_true(float(rk.value) <= most + 1e-9, "%s: %s N, no más de lo que ara de más ni de lo que aprieta" % [tag, rk.value])
					if rk.limitN != null:
						var lat := maxf(float(rk.claws) * float(rk.limitN) - rest_all, 0.0)
						assert_true(float(rk.value) <= lat + 1e-9, "%s: ni de lo que aguanta de lado" % tag)
					else:
						assert_true(inl == "none" or inl == "hematites", "%s: sin tope, solo sin resistencia medida" % tag)
						assert_false(rk.limited, "%s: sin tope, no manda" % tag)
					for key: String in ["value", "min", "max"]:
						assert_eq(s.anchorN[key], rk[key], "%s: es el anclaje (%s)" % [tag, key])
	# unas garras de vidrio no aguantan de lado lo que pide arar la chapa: se romperían antes, y queda la fricción
	var gl := MC.setup({ "claw": C("halcon"), "target": T("coche"), "zone": "techo", "inlay": "vidrio", "defense": true })
	assert_eq(gl.defense.rakeN.value, 0.0, "el halcón con garras de vidrio no ara")
	assert_true(String(gl.defense.vsub).contains("se romperían"), gl.defense.vsub)


func test_el_golpe_en_defensa() -> void:
	var combos := [[50.0, 40.0, 90.0, 0.5], [90.0, 60.0, 0.0, 0.2]]
	for id: String in animals() + ["casuario"]:
		for tid: String in ["coche", "cocheplastico"]:
			for zone: String in MC.impact_zones_for(C(id)):
				for k: Array in combos:
					var p := { "claw": C(id), "target": T(tid), "zone": zone, "v_kmh": k[0], "animal_kmh": k[1], "angle_deg": k[2], "drop_m": k[3] }
					var a := MC.impact(p)
					p["defense"] = true
					var b := MC.impact(p)
					var tag := "%s contra %s (%s, %s)" % [id, tid, zone, k]
					assert_eq(a.defense, null, "%s: sin defensa" % tag)
					assert_true(b.defense != null, "%s: con defensa" % tag)
					assert_true(float(b.marks.depthUm) >= float(a.marks.depthUm) - 1e-9, "%s: las marcas nunca son menos hondas" % tag)
					if a.embedded:
						assert_true(b.embedded, "%s: si se clavaba, se sigue clavando" % tag)
					assert_eq(b.mu, a.mu, "%s: la fricción es la de su peso" % tag)
					# la misma energía, salvo que asustado aguante lo que pide rajar el plástico y en reposo no (unidad 4g)
					var ta: Variant = a.get("tear")
					var tb: Variant = b.get("tear")
					assert_eq(ta == null, tb == null, "%s: las mismas garras trabadas" % tag)
					if ta != null and tb != null:
						assert_true(not ta.holds or tb.holds, "%s: asustado, no se le sueltan antes que en reposo" % tag)
					if ta == null or ta.holds == tb.holds:
						assert_true(same(a.energy, b.energy), "%s: la misma energía" % tag)
					var rows := {}
					for row: Array in b.report:
						rows[row[0]] = row[1]
					assert_true(rows.has("Defensa"), "%s: el informe dice con cuánta fuerza aprieta" % tag)
	# el casuario ya patea con toda su fuerza: su defensa es la patada y no cambia nada más
	var c := { "claw": C("casuario"), "target": T("coche"), "zone": "puerta", "v_kmh": 50.0, "animal_kmh": 0.0 }
	var ca := MC.impact(c)
	c["defense"] = true
	var cb := MC.impact(c)
	assert_near(cb.defense.forceN.value, MC.kick_force_n(58.0), 1e-12, 0.0, "su defensa es la patada")
	assert_true(same(ca.marks, cb.marks) and same(ca.dent, cb.dent), "la misma patada")


# ── Casos de referencia de la integración ──

func test_casos_de_referencia_de_la_especificacion() -> void:
	var cases: Variant = load_json(SPEC)
	assert_true(cases is Array and cases.size() >= 12, "casos cargados")
	if not (cases is Array):
		return
	for c: Dictionary in cases:
		var p := _input(c.input)
		var r: Dictionary = MC.impact(p) if c.input.get("kind") == "impact" else MC.hold_report(p)
		assert_true(r.ok, "%s: el ensayo se puede hacer" % c.id)
		for path: String in c.expect:
			_check(c.id, path, _get_path(r, path), c.expect[path])


static func _input(inp: Dictionary) -> Dictionary:
	var p := inp.duplicate(true)
	p.claw = Data.find_by_id(Data.CLAWS, inp.claw)
	if p.claw == null:
		# los velocirraptores (unidad 4i-B2) solo están en el catálogo 2.0
		p.claw = Catalog.find_by_id(Catalog.CLAWS, inp.claw)
	p.target = Data.find_by_id(Data.TARGETS, inp.target)
	return p


static func _get_path(r: Variant, path: String) -> Variant:
	var cur: Variant = r
	for key: String in path.split("."):
		if cur is Dictionary:
			cur = cur.get(key)
		elif cur is Array and key.is_valid_int():
			cur = cur[int(key)]
		else:
			return null
	return cur


func _check(id: String, path: String, got: Variant, e: Dictionary) -> void:
	var where := "%s · %s" % [id, path]
	if e.has("value"):
		var want: Variant = e.value
		if e.has("tol") and is_num(want):
			assert_true(is_num(got), "%s: número" % where)
			if is_num(got):
				assert_near(float(got), float(want), float(e.tol), 1e-12, where)
		elif is_num(want):
			assert_true(is_num(got) and float(got) == float(want), "%s: obtenido %s, esperado %s" % [where, got, want])
		else:
			assert_eq(got, want, where)
	if e.has("min"):
		assert_true(is_num(got) and float(got) >= float(e.min) - 1e-12, "%s: %s ≥ %s" % [where, got, e.min])
	if e.has("max"):
		assert_true(is_num(got) and float(got) <= float(e.max) + 1e-12, "%s: %s ≤ %s" % [where, got, e.max])
