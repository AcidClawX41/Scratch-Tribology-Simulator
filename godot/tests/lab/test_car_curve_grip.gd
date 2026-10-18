## El animal que se agarra, se recoloca y se cae en la curva (unidad 4u, core/lab/car_curve_grip.gd): en recta no hay nada;
## lejos del límite no aparecen marcas nuevas; más velocidad o menos radio nunca dejan menos resbalones ni menos marcas; un
## animal con más agarre nunca se cae antes; unas garras más duras nunca dejan marcas menos hondas; se cae solo si el
## despegue de la curva lo dice; la S es determinista y sus momentos van en orden; y cada dato lleva fuente y calidad.
extends "res://tests/case.gd"

const CarCurve = preload("res://core/lab/car_curve.gd")
const Grip = preload("res://core/lab/car_curve_grip.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const CASES := [
	["aguila", "techo", "plegadas"], ["lechuza", "retrovisor", "plegadas"], ["tigre", "techo", "tumbado"],
	["oso", "techo", "de_pie"], ["velociraptor", "techo", ""], ["buitre", "capo", "plegadas"],
]
const RADII := [1050.0, 450.0, 130.0, 50.0, 15.0]
const SPEEDS := [10.0, 40.0, 60.0, 90.0, 130.0, 180.0, 230.0]
const GRIP := 0.85


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func scen_of(cfg: Array, inlay := "none") -> Dictionary:
	var p := { "claw": C(cfg[0]), "target": T("coche"), "zone": cfg[1], "model": "2.0" }
	if String(cfg[2]) != "":
		p.posture = cfg[2]
	if inlay != "none":
		p.inlay = Catalog.find_by_id(Catalog.INLAYS, inlay)
	return MC.setup(p)


static func grip_at(scen: Dictionary, v: float, r: float, side := 1.0) -> Dictionary:
	return Grip.at(scen, CarCurve.at_speed(scen, v, r, GRIP, side))


func test_en_recta_no_hay_nada() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for v: float in SPEEDS:
			assert_true(Grip.at(scen, MC.at_speed(scen, v)).is_empty(), "%s a %s km/h en recta: nada" % [cfg, v])
			var flat := CarCurve.at_lateral(scen, v, 0.0, 130.0, GRIP)
			assert_true(Grip.at(scen, flat).is_empty(), "%s: sin aceleración lateral, nada" % [cfg])
	assert_true(Grip.s_events(scen_of(CASES[0]), CarCurve.road(130.0, T("coche")), 0.0, GRIP).is_empty(), "la S parado: nada")


func test_lejos_del_limite_no_hay_marcas_nuevas() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		var g := grip_at(scen, 30.0, 1050.0)
		assert_false(g.is_empty(), "%s: en curva hay lectura" % [cfg])
		assert_eq(int(g.slips), 0, "%s a 30 km/h en 1050 m: no resbala" % [cfg])
		assert_true((g.marks as Dictionary).is_empty(), "%s: sin marcas nuevas" % [cfg])
		assert_false(bool(g.falls), "%s: no se cae" % [cfg])
		assert_true(float(g.u) < float(Grip.SLIP_FROM.value), "%s: lejos del umbral (u %s)" % [cfg, g.u])


func test_mas_velocidad_o_menos_radio_nunca_menos_resbalones() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for r: float in RADII:
			var prev := -1
			for v: float in SPEEDS:
				var k := Grip.groove_count(grip_at(scen, v, r))
				assert_true(k >= prev, "%s en %s m: a %s km/h no menos surcos (%s ≥ %s)" % [cfg, r, v, k, prev])
				prev = k
		for v: float in SPEEDS:
			var prev := -1
			var prev_depth := -1.0
			for r: float in RADII:
				var g := grip_at(scen, v, r)
				var k := Grip.groove_count(g)
				assert_true(k >= prev, "%s a %s km/h: con %s m no menos surcos (%s ≥ %s)" % [cfg, v, r, k, prev])
				prev = k
				if not (g.marks as Dictionary).is_empty() and bool(g.holds):
					var d := float(g.marks.depthUm)
					assert_true(d >= prev_depth - 1e-9, "%s a %s km/h: con %s m el resbalón no es menos hondo" % [cfg, v, r])
					prev_depth = d


func test_el_resbalon_raya_al_menos_como_quieto() -> void:
	# la garra que resbala en curva tira con más fuerza que en recta a la misma velocidad: nunca un surco menos hondo
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for v: float in [90.0, 160.0]:
			var g := grip_at(scen, v, 50.0)
			if int(g.slips) <= 0:
				continue
			var still := MC.marks_at_speed(scen, v)
			assert_true(float(g.tipN) >= float(still.tipN) - 1e-9, "%s a %s km/h: la garra que resbala no tira menos" % [cfg, v])
			assert_true(float(g.marks.depthUm) >= float(still.marks.depthUm) - 1e-6, "%s a %s km/h: ni raya menos" % [cfg, v])


func test_mas_agarre_nunca_se_cae_antes() -> void:
	for cfg: Array in CASES:
		var weak := scen_of(cfg)
		var strong := weak.duplicate(true)
		for key: String in ["nom"]:
			var c: Dictionary = strong.cases[key]
			c.A = float(c.A) * 1.5 + 5.0
			c.mu = float(c.mu) * 1.2
		for r: float in RADII:
			for v: float in SPEEDS:
				var gw := grip_at(weak, v, r)
				var gs := grip_at(strong, v, r)
				if bool(gs.falls):
					assert_true(bool(gw.falls), "%s en %s m a %s km/h: con más agarre no se cae si con menos aguanta" % [cfg, r, v])


func test_garras_mas_duras_nunca_marcas_menos_hondas() -> void:
	var chain := ["none", "tungsteno", "diamante"]
	for cfg: Array in [["tigre", "techo", "tumbado"], ["oso", "techo", "de_pie"], ["aguila", "techo", "plegadas"]]:
		for f: float in [20.0, 80.0, 200.0]:
			var prev := -1.0
			for id: String in chain:
				var scen := scen_of(cfg, id)
				var d := float(Grip.slip_marks(scen, f, 15.0).depthUm)
				assert_true(d >= prev - 1e-6, "%s con %s N: %s no raya menos (%s ≥ %s µm)" % [cfg, f, id, d, prev])
				prev = d
	# la queratina no perfora el acero de la chapa ni resbalando al caerse
	var ker := scen_of(["oso", "techo", "de_pie"])
	var fall := Grip.slip_marks(ker, 2000.0, float(Grip.FALL_SLIDE_MM.value))
	assert_false(Js_truthy(fall.get("through")), "la queratina no atraviesa la chapa")


static func Js_truthy(v: Variant) -> bool:
	return v != null and v != false and v != 0 and v != 0.0


func test_se_cae_solo_si_el_despegue_lo_dice() -> void:
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for r: float in RADII:
			var det := CarCurve.detach(scen, r, CarCurve.CAR_GRIP.turismo, 1.0)
			for v: float in SPEEDS:
				var a := CarCurve.at_speed(scen, v, r, GRIP, 1.0)
				var g := Grip.at(scen, a)
				assert_eq(bool(g.falls), not bool(a.holds), "%s en %s m a %s km/h: se cae si no aguanta" % [cfg, r, v])
				var simple: bool = bool(det.atRest) and det.holdFromKmh == null
				if simple and not bool(det.never) and absf(v - float(det.kmh)) > 1.0:
					assert_eq(bool(g.falls), v > float(det.kmh), "%s en %s m a %s km/h: el despegue (%s km/h) dice si se cae" % [cfg, r, v, det.kmh])
				if bool(g.falls):
					assert_eq(int(g.slips), int(scen.holdCtx.nContact), "al caerse arañan todas sus garras")
					assert_false((g.fallMarks as Dictionary).is_empty(), "y dejan su surco")


func test_la_s_en_orden_y_determinista() -> void:
	var rd := CarCurve.road(50.0, T("coche"))
	var seen_flip := false
	var seen_fall := false
	for cfg: Array in CASES:
		var scen := scen_of(cfg)
		for v: float in [40.0, 70.0, 90.0, 120.0]:
			var a := Grip.s_events(scen, rd, v, GRIP)
			var b := Grip.s_events(scen, rd, v, GRIP)
			assert_eq(JSON.stringify(a), JSON.stringify(b), "%s a %s km/h: la S sale igual dos veces" % [cfg, v])
			var prev := -1.0
			var fell := false
			for e: Dictionary in a.events:
				assert_true(float(e.tS) >= prev, "los momentos de la S van en orden")
				prev = float(e.tS)
				assert_false(fell, "después de caerse no hay más")
				fell = String(e.kind) == Grip.KIND_FALL
				seen_fall = seen_fall or fell
				if String(e.kind) == Grip.KIND_FLIP:
					seen_flip = true
					assert_eq(float(e.side), -1.0, "al cambiar de lado se recolocan las del lado nuevo")
					assert_true(int(e.claws) >= 1 and int(e.claws) <= ceili(float(scen.holdCtx.nContact) / 2.0), "de una a las de su lado")
			assert_eq(bool(a.falls), fell, "falls dice si hay caída")
	assert_true(seen_flip, "en alguna S se recoloca al cambiar de lado")
	assert_true(seen_fall, "y en alguna se cae")


func test_conteos_monotonos_y_umbrales() -> void:
	for n: int in [2, 4, 8, 10]:
		var prev := 0
		var prev_f := 0
		var prev_l := 0.0
		for i in 121:
			var u := float(i) / 100.0
			var k := Grip.slip_count(u, n)
			var kf := Grip.flip_count(u, n)
			assert_true(k >= prev and kf >= prev_f, "más u, no menos garras (%s, %s)" % [n, u])
			assert_true(k <= ceili(float(n) / 2.0), "solo las del lado cargado")
			if u < float(Grip.SLIP_FROM.value):
				assert_eq(k, 0, "por debajo del umbral no resbala")
			var l := Grip.slip_len_mm(u)
			assert_true(l >= prev_l and l <= float(Grip.SLIP_MM.value) + 1e-9, "el largo no baja ni pasa de SLIP_MM")
			prev = k
			prev_f = kf
			prev_l = l
	assert_eq(Grip.effort(0.0), 0.0, "sin carga no se le nota")
	assert_eq(Grip.effort(1.0), 1.0, "en su tope, todo")
	assert_eq(Grip.effort(INF), 1.0, "sin agarre, todo")


func test_fuentes_y_calidad() -> void:
	for d: Dictionary in [Grip.SLIP_FROM, Grip.FLIP_FROM, Grip.SLIP_MM, Grip.FALL_SLIDE_MM]:
		assert_eq(String(d.quality), "estimate", "estimación marcada")
		assert_true(String(d.source).length() > 40, "con su fuente escrita")
		assert_true(float(d.min) <= float(d.value) and float(d.value) <= float(d.max), "con su banda")
	assert_eq(String(Grip.REACT_FROM.quality), "dibujo", "la animación es dibujo")


func test_textos() -> void:
	var scen := scen_of(["tigre", "techo", "tumbado"])
	var t := T("coche")
	var found_slip := false
	var found_fall := false
	for r: float in [50.0, 15.0]:
		for v: float in SPEEDS:
			var g := grip_at(scen, v, r)
			var txt := Grip.now_txt(g, "el tigre", t, false)
			if int(g.slips) > 0 and bool(g.holds):
				found_slip = true
				assert_true(txt.contains("vuelve"), "dice que vuelve a clavarse: %s" % txt)
			if bool(g.falls):
				found_fall = true
				assert_true(txt.begins_with("Se cae"), "dice que se cae: %s" % txt)
				var tb := Grip.now_txt(g, "la lechuza común", t, false, true)
				assert_true(tb.contains("intenta despegar") and not tb.contains("Se cae"), "un ave intenta despegar: %s" % tb)
			assert_false(txt.contains("%s") or txt.contains("%d"), "sin formatos sueltos")
			assert_false(txt.contains("nan") or txt.contains("inf"), "sin números rotos: %s" % txt)
	assert_true(found_slip and found_fall, "el tigre resbala y se cae en algún punto")


func test_el_estado_en_recta_y_en_curva() -> void:
	var st: RefCounted = MCS.new(C("tigre"), T("coche"))
	st.threaded = false
	st.set_zone("techo")
	st.set_speed(90.0)
	var rows0: Array = st.hold_rows().duplicate(true)
	var srcs0: Array = st.sources().duplicate(true)
	assert_true(st.grip_now().is_empty(), "en recta no hay agarre en curva")
	assert_eq(st.grip_rows(), [], "ni filas")
	assert_eq(st.grip_text(), "", "ni frase")
	st.set_road(CarCurve.ROAD_CURVE)
	st.set_radius(50.0)
	var g: Dictionary = st.grip_now()
	assert_false(g.is_empty(), "en la curva sí")
	assert_true(int(g.slips) > 0, "a 90 km/h en 50 m el tigre resbala (u %s)" % g.u)
	assert_true(st.curve_text().contains("vuelven a clavarse"), st.curve_text())
	var labels: Array = st.hold_rows().map(func(r: Array) -> String: return String(r[0]))
	assert_true(labels.has("Resbalones en la curva"), "el informe cuenta los resbalones")
	var srcs: Array = st.sources().map(func(r: Dictionary) -> String: return String(r.label))
	assert_true(srcs.has("Desde cuándo resbalan las garras (parte del agarre)"), "con su fuente")
	var ids: Array = st.hold_readings().map(func(r: Dictionary) -> String: return String(r.id))
	assert_true(ids.has("agarre_curva"), "y su lectura")
	st.set_road(CarCurve.ROAD_S)
	var s: Dictionary = st.grip_now()
	assert_true(s.has("events"), "en la S, sus momentos")
	st.set_road(CarCurve.ROAD_STRAIGHT)
	assert_eq(st.hold_rows(), rows0, "al volver a la recta, el informe al bit")
	assert_eq(st.sources(), srcs0, "y las fuentes")
	assert_true(st.grip_now().is_empty(), "y sin agarre en curva")


func test_el_miedo_del_animal() -> void:
	assert_eq(Grip.fear(0.0), 0.0, "tranquilo en recta y parado")
	assert_eq(Grip.fear(1.0), 1.0, "a punto de soltarse")
	assert_eq(Grip.fear(INF), 1.0, "sin agarre")
	assert_eq(Grip.fear(0.1, 50.0), Grip.fear(0.1, 50.0), "determinista")
	var prev := -1.0
	for i in 101:
		var u := float(i) / 100.0
		var f := Grip.fear(u, 1.0)
		assert_true(f >= prev and f >= 0.0 and f <= 1.0, "más carga, no menos miedo (%s)" % u)
		prev = f
		assert_true(Grip.fear(u, 2.0) >= Grip.fear(u, 0.5), "más tirón, no menos miedo")
	assert_true(Grip.fear(0.5, 6.0) > Grip.fear(0.5, 0.0), "el tirón de la S asusta")
	assert_eq(Grip.fear(0.0, 6.0), 0.0, "un tirón sin carga no asusta")
	assert_eq(String(Grip.FEAR.quality), "dibujo", "marcado como dibujo")
