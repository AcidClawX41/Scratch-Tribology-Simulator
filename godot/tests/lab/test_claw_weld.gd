## La soldadura de piezas de metal de una funda (unidad 5r; petición 44): invariantes, no números mágicos.
##   - más energía por pulso nunca da menos hondura (con lo demás igual); un punto más estrecho, nunca menos;
##   - el titanio sin argón sale contaminado (y aguanta menos que con argón); con argón, plateado;
##   - el metal duro no se funde con el láser ni con el arco: solo con soldadura fuerte;
##   - la unión nunca aguanta más que el metal base; el oro soldado, la mitad (medido);
##   - el oro y el titanio (o el acero) no se sueldan entre sí por fusión; las gemas y la queratina, nunca;
##   - la costura: más solape, más puntos y más hondura efectiva; una pared más gruesa que la hondura, falta de fusión; un ojo
##     de cerradura muy hondo en una pared fina, perforada;
##   - la soldadura fuerte: fría no moja, pastosa a medias, bien entre 652 y 870 °C, el fundente se agota por encima; la holgura
##     tiene que estar entre 0,025 y ~0,25 mm;
##   - las fichas: 80 J en 2 ms sobre 0,5 mm en el acero, ~3 mm (la W150G); el titanio dentro de lo medido por Baba y Watanabe.
extends "res://tests/case.gd"

const ClawWeld = preload("res://core/lab/claw_weld.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

const METALS := ["oro", "acero", "titanio"]


func test_mas_energia_nunca_menos_hondura() -> void:
	for mid: String in METALS:
		for spot: float in [0.3, 0.6, 1.0, 1.6]:
			for t: float in [0.5, 2.0, 5.0, 10.0, 20.0]:
				var prev := -1.0
				var e := 1.0
				while e <= 80.0:
					var s := ClawWeld.laser_spot(mid, e, t, spot, "argon")
					assert_true(bool(s.ok), "%s: el punto sale" % mid)
					assert_true(float(s.depthMm) >= prev - 1e-12, "%s: %s J en %s ms sobre %s mm: %s mm, antes %s" % [mid, e, t, spot, s.depthMm, prev])
					assert_true(float(s.depthMm) > 0.0 and float(s.widthMm) > 0.0, "hondura y anchura positivas")
					prev = float(s.depthMm)
					e += 1.0
		# un punto más estrecho con la misma energía y el mismo pulso nunca da menos hondura
		for t2: float in [1.0, 5.0, 20.0]:
			var prev2 := INF
			for spot2: float in [0.2, 0.3, 0.5, 0.8, 1.2, 1.6, 2.0]:
				var d := float(ClawWeld.laser_spot(mid, 40.0, t2, spot2, "argon").depthMm)
				assert_true(d <= prev2 + 1e-12, "%s: punto de %s mm: %s mm, el más estrecho %s" % [mid, spot2, d, prev2])
				prev2 = d
	# el micro-TIG: más corriente, nunca menos hondura; más tiempo, tampoco
	for mid2: String in METALS:
		var prev3 := -1.0
		for i: float in [9.0, 50.0, 100.0, 200.0, 400.0, 630.0]:
			var d3 := float(ClawWeld.tig_spot(mid2, i, 10.0, "argon").depthMm)
			assert_true(d3 >= prev3, "%s: %s A, %s mm" % [mid2, i, d3])
			prev3 = d3
		var prev4 := -1.0
		for t4: float in [0.1, 1.0, 8.0, 20.0, 34.0]:
			var d4 := float(ClawWeld.tig_spot(mid2, 200.0, t4, "argon").depthMm)
			assert_true(d4 >= prev4, "%s: %s ms, %s mm" % [mid2, t4, d4])
			prev4 = d4


func test_los_modos_y_las_fichas() -> void:
	# la W150G: hasta 80 J, pulsos de 0,1 a 20 ms, 9 kW de pico; la penetración máxima ~3 mm (acero, ojo de cerradura)
	var s := ClawWeld.laser_spot("acero", 80.0, 2.0, 0.5, "argon")
	assert_eq(String(s.mode), "ojo", "80 J en 2 ms sobre 0,5 mm es ojo de cerradura")
	assert_true(float(s.densityMWcm2) > 1.5, "densidad por encima del umbral del ojo: %s MW/cm²" % s.densityMWcm2)
	assert_near(float(s.depthMm), 3.0, 0.1, 0.0, "el acero a tope: ~3 mm (la ficha de la W150G)")
	assert_true(float(s.aspect) > 1.5, "en ojo de cerradura, más hondo que ancho: %s" % s.aspect)
	# un pulso largo y ancho con poca energía: conducción, ancho y poco hondo
	var c := ClawWeld.laser_spot("acero", 10.0, 10.0, 1.2, "argon")
	assert_eq(String(c.mode), "conduccion", "10 J en 10 ms sobre 1,2 mm es conducción")
	assert_true(float(c.aspect) <= 0.5 + 1e-9, "en conducción, un baño semiesférico")
	assert_true(float(c.depthMm) < float(s.depthMm), "conducción, menos hondo")
	# el titanio, dentro de lo medido por Baba y Watanabe (0,29-6,45 mm con puntos de 0,4 a 1,6 mm)
	var lo := INF
	var hi := 0.0
	for e: float in [5.0, 20.0, 40.0, 80.0]:
		for spot: float in [0.4, 0.8, 1.6]:
			var d := float(ClawWeld.laser_spot("titanio", e, 10.0, spot, "argon").depthMm)
			lo = minf(lo, d)
			hi = maxf(hi, d)
	assert_true(hi <= 6.45 + 1e-9 and hi > 1.0, "el titanio a tope, %s mm, dentro de los 6,45 mm medidos" % hi)
	assert_true(lo >= 0.05 and lo < 1.0, "el titanio con poco, %s mm" % lo)
	# el oro refleja: con el mismo pulso en conducción funde menos que el acero
	var au := ClawWeld.laser_spot("oro", 10.0, 10.0, 1.2, "argon")
	assert_true(float(au.meltedMm3) < float(c.meltedMm3), "el oro frío refleja casi todo el 1064 nm")
	# la zona afectada por el calor: el oro, que conduce 20 veces más, la tiene mayor
	assert_true(float(au.hazMm) > float(c.hazMm), "la zona afectada por el calor del oro, mayor")
	# la continuidad entre modos: 1 a 1,5 MW/cm², sin saltos
	var prev := 0.0
	var e2 := 1.0
	while e2 <= 30.0:
		var d2 := float(ClawWeld.laser_spot("acero", e2, 4.0, 0.8, "argon").depthMm)
		assert_true(d2 - prev < 0.6, "sin saltos de hondura: %s J, %s → %s" % [e2, prev, d2])
		prev = d2
		e2 += 0.5
	# el micro-TIG: siempre en conducción y la energía I·V·t
	var tg := ClawWeld.tig_spot("acero", 300.0, 10.0, "argon")
	assert_eq(String(tg.mode), "conduccion", "el arco, conducción")
	assert_near(float(tg.energyJ), 300.0 * 15.0 * 0.01, 1e-9, 0.0, "I·V·t")
	assert_true(float(tg.depthMm) > 0.3 and float(tg.depthMm) < 2.0, "el PUK a 300 A y 10 ms, %s mm" % tg.depthMm)


func test_el_titanio_sin_argon_sale_contaminado() -> void:
	var sm_wall := 0.5
	for method: String in ["laser", "tig"]:
		var good := _spot(method, "titanio", "argon")
		var poor := _spot(method, "titanio", "argon_escaso")
		var bad := _spot(method, "titanio", "aire")
		assert_false(bool(good.contaminated), "con argón, sin contaminar")
		assert_true(bool(bad.contaminated), "sin gas, contaminado")
		assert_eq(String(good.color.name), "plateado", "con argón, plateado")
		assert_eq(String(poor.color.name), "pajizo", "con el argón escaso, pajizo (aún bien)")
		assert_true(String(bad.color.name).begins_with("azul"), "al aire, azul")
		assert_true(bool(good.color.ok) and bool(poor.color.ok) and not bool(bad.color.ok), "el color lo delata")
		var jg := ClawWeld.joint(method, "titanio", "titanio", good, ClawWeld.seam(good, sm_wall, 10.0, 0.65), "argon")
		var jp := ClawWeld.joint(method, "titanio", "titanio", poor, ClawWeld.seam(poor, sm_wall, 10.0, 0.65), "argon_escaso")
		var jb := ClawWeld.joint(method, "titanio", "titanio", bad, ClawWeld.seam(bad, sm_wall, 10.0, 0.65), "aire")
		assert_true(bool(jg.ok), "%s con argón: bien (%s)" % [method, jg.text])
		assert_eq(String(jb.defect), "contaminada", "%s al aire: contaminada" % method)
		assert_true(float(jb.jointMPa) < float(jp.jointMPa) and float(jp.jointMPa) < float(jg.jointMPa), "cuanto más oxígeno, menos aguanta: %s < %s < %s" % [jb.jointMPa, jp.jointMPa, jg.jointMPa])
		assert_true(bool(jb.contaminated), "la unión lo dice")
	# el oro y el acero no necesitan el argón (Watanabe y Topham): al aire aguantan lo mismo
	for mid: String in ["oro", "acero"]:
		var a := _spot("laser", mid, "argon")
		var b := _spot("laser", mid, "aire")
		var ja := ClawWeld.joint("laser", mid, mid, a, ClawWeld.seam(a, 0.5, 10.0, 0.65), "argon")
		var jb2 := ClawWeld.joint("laser", mid, mid, b, ClawWeld.seam(b, 0.5, 10.0, 0.65), "aire")
		assert_near(float(ja.jointMPa), float(jb2.jointMPa), 1e-9, 0.0, "%s: con o sin argón, igual" % mid)
		assert_false(bool(jb2.contaminated), "%s no se contamina" % mid)
	# el acero al aire queda azul (óxido), el oro de su color
	assert_true(String(_spot("laser", "acero", "aire").color.name).begins_with("azul"), "el acero al aire, azul")


static func _spot(method: String, mid: String, gas: String) -> Dictionary:
	return ClawWeld.laser_spot(mid, 25.0, 5.0, 0.6, gas) if method == "laser" else ClawWeld.tig_spot(mid, 400.0, 20.0, gas)


func test_el_metal_duro_solo_con_soldadura_fuerte() -> void:
	for method: String in ["laser", "tig"]:
		var cj := ClawWeld.can_join("acero", "tungsteno", method)
		assert_false(bool(cj.ok), "%s: el metal duro no se funde" % method)
		assert_eq(String(cj.code), "metal_duro", "el código")
		var cj2 := ClawWeld.can_join("tungsteno", "tungsteno", method)
		assert_false(bool(cj2.ok), "%s: ni con metal duro" % method)
	var s := ClawWeld.laser_spot("tungsteno", 80.0, 1.0, 0.3, "argon")
	assert_false(bool(s.ok), "el láser no funde el carburo")
	assert_eq(String(s.defect), "no_funde", "no funde")
	assert_eq(float(s.depthMm), 0.0, "sin hondura")
	assert_false(bool(ClawWeld.tig_spot("tungsteno", 630.0, 34.0, "argon").ok), "ni el arco")
	var bz := ClawWeld.braze("acero", "tungsteno", 700.0, 0.04)
	assert_true(bool(bz.ok) and bool(bz.flows), "con plata a 700 °C, sí: %s" % bz.text)
	var j := ClawWeld.joint("braze", "acero", "tungsteno", {}, {}, "argon", bz)
	assert_true(bool(j.ok), "la unión de plata del metal duro al acero")
	assert_true(float(j.jointMPa) <= float(j.baseMPa) + 1e-9, "nunca más que el metal base")


## Ni más que el metal base ni menos de cero (el texto la escribe «~N MPa»: la tilde no es un signo menos).
func test_la_union_nunca_aguanta_mas_que_el_metal_base() -> void:
	var n := 0
	for mid: String in METALS:
		var base := ClawWeld.base_strength_mpa(mid)
		assert_true(base > 0.0, "%s tiene resistencia" % mid)
		for gas: String in ClawWeld.GAS_IDS:
			for e: float in [2.0, 10.0, 30.0, 80.0]:
				for t: float in [0.5, 4.0, 15.0]:
					for spot: float in [0.3, 0.8, 1.5]:
						var s := ClawWeld.laser_spot(mid, e, t, spot, gas)
						for wall: float in [0.3, 1.0, 2.0]:
							for ov: float in [0.65, 0.85]:
								var j := ClawWeld.joint("laser", mid, mid, s, ClawWeld.seam(s, wall, 12.0, ov), gas)
								assert_true(float(j.jointMPa) <= base + 1e-9, "%s: %s MPa > %s" % [mid, j.jointMPa, base])
								assert_true(float(j.jointMPa) >= 0.0, "%s: nunca negativa (%s MPa)" % [mid, j.jointMPa])
								assert_true(float(j.efficiency) <= 1.0 + 1e-12 and float(j.efficiency) >= 0.0, "eficiencia entre 0 y 1")
								n += 1
			for i: float in [20.0, 200.0, 630.0]:
				var s2 := ClawWeld.tig_spot(mid, i, 10.0, gas)
				var j2 := ClawWeld.joint("tig", mid, mid, s2, ClawWeld.seam(s2, 1.0, 12.0, 0.65), gas)
				assert_true(float(j2.jointMPa) <= base + 1e-9, "%s TIG: %s MPa > %s" % [mid, j2.jointMPa, base])
				assert_true(float(j2.jointMPa) >= 0.0, "%s TIG: nunca negativa (%s MPa)" % [mid, j2.jointMPa])
				n += 1
		for other: String in METALS + ["tungsteno"]:
			for t_c: float in [600.0, 700.0, 850.0]:
				for gap: float in [0.03, 0.06, 0.15]:
					var bz := ClawWeld.braze(mid, other, t_c, gap)
					var jb := ClawWeld.joint("braze", mid, other, {}, {}, "argon", bz)
					assert_true(float(jb.jointMPa) <= float(jb.baseMPa) + 1e-9, "plata %s-%s: %s > %s" % [mid, other, jb.jointMPa, jb.baseMPa])
					assert_true(float(jb.jointMPa) >= 0.0, "plata %s-%s: nunca negativa (%s MPa)" % [mid, other, jb.jointMPa])
					n += 1
	assert_true(n > 1000, "%d uniones" % n)
	# el oro soldado aguanta la mitad (Watanabe y Topham 2006), con la pared atravesada (el arco: el oro refleja el láser)
	var au := ClawWeld.tig_spot("oro", 300.0, 10.0, "argon")
	var sm := ClawWeld.seam(au, 0.5, 10.0, 0.85)
	assert_true(bool(sm.through), "atraviesa la pared de 0,5 mm (%s mm)" % sm.effDepthMm)
	var ja := ClawWeld.joint("tig", "oro", "oro", au, sm, "argon")
	assert_near(float(ja.efficiency), 0.5, 1e-9, 0.0, "el oro, la mitad")


func test_lo_que_no_se_suelda_entre_si() -> void:
	for pair: Array in [["oro", "titanio"], ["titanio", "acero"], ["oro", "acero"]]:
		for method: String in ["laser", "tig"]:
			var cj := ClawWeld.can_join(String(pair[0]), String(pair[1]), method)
			assert_false(bool(cj.ok), "%s con %s por fusión, no" % [pair[0], pair[1]])
			assert_eq(String(cj.code), "distintos", "intermetálicos")
			var s := _spot(method, String(pair[0]), "argon")
			var j := ClawWeld.joint(method, String(pair[0]), String(pair[1]), s, ClawWeld.seam(s, 1.0, 10.0, 0.65), "argon")
			assert_false(bool(j.ok), "la unión no sale")
			assert_true(bool(j.cracks), "se agrieta")
		assert_true(bool(ClawWeld.can_join(String(pair[0]), String(pair[1]), "braze").ok), "%s con %s, con plata sí" % [pair[0], pair[1]])
	for mid: String in ["zafiro", "diamante", "vidrio", "cuarzo", "alumina", "rubi"]:
		for method: String in ClawWeld.METHOD_IDS:
			var cj := ClawWeld.can_join("acero", mid, method)
			assert_false(bool(cj.ok), "%s con %s: nunca" % [mid, method])
			assert_eq(String(cj.code), "gema", "se engasta o se pega")
	for method: String in ClawWeld.METHOD_IDS:
		var cj := ClawWeld.can_join("acero", "none", method)
		assert_false(bool(cj.ok), "la queratina, nunca (%s)" % method)
		assert_eq(String(cj.code), "queratina", "la queratina")
		assert_true(String(cj.text).contains("230"), "dice a cuánto se quema")
		assert_eq(String(ClawWeld.can_join("oro", "acrilico", method).code), "polimero", "el acrílico se pega")
	for mid2: String in METALS:
		assert_true(bool(ClawWeld.can_join(mid2, mid2, "laser").ok) and bool(ClawWeld.can_join(mid2, mid2, "tig").ok), "%s con %s, sí" % [mid2, mid2])


func test_la_costura() -> void:
	var s := ClawWeld.laser_spot("acero", 30.0, 4.0, 0.6, "argon")
	var a := ClawWeld.seam(s, 1.0, 12.0, 0.65)
	var b := ClawWeld.seam(s, 1.0, 12.0, 0.85)
	assert_true(int(b.pulsesNeed) > int(a.pulsesNeed), "más solape, más puntos: %d > %d" % [b.pulsesNeed, a.pulsesNeed])
	assert_true(float(b.effDepthMm) > float(a.effDepthMm), "más solape, más hondura efectiva")
	assert_true(float(b.effDepthMm) <= float(s.depthMm) + 1e-12, "nunca más que el punto")
	assert_near(float(a.pitchMm), float(s.widthMm) * 0.35, 1e-9, 0.0, "el paso, el ancho por lo que no se solapa")
	assert_true(int(ClawWeld.seam(s, 1.0, 24.0, 0.65).pulsesNeed) >= 2 * int(a.pulsesNeed) - 1, "el doble de costura, el doble de puntos")
	# una pared más gruesa que la hondura: falta de fusión; una fina con un ojo de cerradura muy hondo: perforada
	var thick := ClawWeld.seam(s, 5.0, 12.0, 0.85)
	assert_false(bool(thick.through), "5 mm de pared, no la atraviesa")
	var j := ClawWeld.joint("laser", "acero", "acero", s, thick, "argon")
	assert_eq(String(j.defect), "falta_fusion", "falta de fusión")
	assert_true(float(j.jointMPa) < float(j.baseMPa) * 0.9, "aguanta menos")
	var deep := ClawWeld.laser_spot("acero", 80.0, 1.0, 0.3, "argon")
	var thin := ClawWeld.seam(deep, 0.3, 12.0, 0.65)
	assert_true(bool(thin.perforated), "80 J en 1 ms en 0,3 mm de pared: perforada (%s mm)" % deep.depthMm)
	var jp := ClawWeld.joint("laser", "acero", "acero", deep, thin, "argon")
	assert_eq(String(jp.defect), "perforada", "la unión lo dice")
	assert_eq(float(jp.jointMPa), 0.0, "y no aguanta")
	# un pulso suave en conducción no perfora una pared fina aunque la atraviese
	var soft := ClawWeld.laser_spot("acero", 12.0, 10.0, 1.0, "argon")
	assert_false(bool(ClawWeld.seam(soft, 0.3, 12.0, 0.65).perforated), "en conducción no se perfora")
	assert_true(float(a.beadMm) > 0.0 and float(a.beadMm) < float(s.widthMm), "la sobremonta del cordón")
	# sin punto (el carburo), sin costura
	assert_eq(int(ClawWeld.seam(ClawWeld.laser_spot("tungsteno", 10.0, 1.0, 0.5), 1.0, 12.0, 0.65).pulsesNeed), 0, "sin punto no hay puntos")


func test_la_soldadura_fuerte() -> void:
	assert_eq(String(ClawWeld.braze("acero", "acero", 500.0, 0.04).defect), "fria", "a 500 °C la plata no funde")
	assert_eq(String(ClawWeld.braze("acero", "acero", 630.0, 0.04).defect), "pastosa", "entre 618 y 652, pastosa")
	var ok := ClawWeld.braze("acero", "acero", 700.0, 0.04)
	assert_true(bool(ok.ok) and absf(float(ok.factor) - 1.0) < 1e-9, "a 700 °C con 0,04 mm, perfecta")
	assert_eq(String(ClawWeld.braze("acero", "acero", 900.0, 0.04).defect), "fundente_agotado", "a 900 °C el fundente se agota")
	assert_eq(String(ClawWeld.braze("oro", "oro", 1070.0, 0.04).defect), "funde_base", "a 1070 °C se funde el oro")
	assert_eq(String(ClawWeld.braze("acero", "acero", 700.0, 0.01).defect), "sin_holgura", "sin holgura no entra")
	assert_eq(String(ClawWeld.braze("acero", "acero", 700.0, 0.3).defect), "holgura", "con 0,3 mm se cae")
	var wide := ClawWeld.braze("acero", "acero", 700.0, 0.15)
	assert_true(bool(wide.ok) and float(wide.factor) < 1.0 and float(wide.factor) > 0.0, "con 0,15 mm aguanta menos: %s" % wide.factor)
	# más holgura por encima de la buena nunca aguanta más
	var prev := 2.0
	var g := 0.04
	while g <= 0.25:
		var f := float(ClawWeld.braze("acero", "acero", 700.0, g).get("factor", 0.0))
		assert_true(f <= prev + 1e-12, "holgura %s: %s" % [g, f])
		prev = f
		g += 0.01
	var j := ClawWeld.joint("braze", "oro", "oro", {}, {}, "argon", ok)
	assert_true(bool(j.ok), "la unión")
	assert_true(float(j.jointMPa) <= float(j.baseMPa) + 1e-9, "nunca más que el oro")
	assert_eq(String(ClawWeld.joint("braze", "oro", "oro", {}, {}, "argon", ClawWeld.braze("oro", "oro", 700.0, 0.04)).limitedBy), "el metal base", "en el oro manda el oro (105 MPa frente a la plata)")
	assert_eq(String(ClawWeld.joint("braze", "titanio", "titanio", {}, {}, "argon", ClawWeld.braze("titanio", "titanio", 700.0, 0.04)).limitedBy), "la plata", "en el titanio manda la plata")


func test_datos_con_fuente() -> void:
	for id: String in ClawWeld.METHOD_IDS:
		var m: Dictionary = ClawWeld.METHODS[id]
		assert_true(String(m.source).length() > 40 and m.quality in ["primary", "secondary", "estimate"], "%s con fuente y calidad" % id)
		assert_true(String(m.safety).length() > 20, "%s con su seguridad" % id)
		for c: String in m.controls:
			var cd: Dictionary = m.controls[c]
			assert_true(float(cd.value) >= float(cd.min) and float(cd.value) <= float(cd.max), "%s.%s de serie en su rango" % [id, c])
	for tbl: Dictionary in [ClawWeld.FUSION_J_KG, ClawWeld.ABSORPTIVITY, ClawWeld.JOINT_FACTOR]:
		for k: String in tbl:
			assert_true(tbl[k].quality in ["primary", "secondary", "estimate"] and String(tbl[k].source).length() > 20, "%s con fuente" % k)
	for d: Dictionary in [ClawWeld.DENSITY, ClawWeld.MELT_EFF_CONDUCTION, ClawWeld.KEYHOLE_COUPLING, ClawWeld.KEYHOLE_WIDTH_FACTOR, ClawWeld.ARC, ClawWeld.BRAZE, ClawWeld.BEAD_FRAC]:
		assert_true(d.quality in ["primary", "secondary", "estimate"] and String(d.source).length() > 20, "con fuente y calidad")
	assert_true(ForgeData.BRAZE.t_min < ForgeData.BRAZE.t_max and float(ForgeData.BRAZE.t_max) < float(ClawWeld.BRAZE.flux_max_c), "la plata funde antes de que el fundente se agote")
	# el periodo de cada pulso: el micro-TIG, el de su ficha
	assert_near(ClawWeld.pulse_period_s("tig"), 1.0 / 3.3, 1e-9, 0.0, "3,3 puntos por segundo")
	assert_true(ClawWeld.pulse_period_s("braze") > ClawWeld.pulse_period_s("laser"), "el soplete tarda más por tramo")


# ════════════════════════════════ El motor: la soldadura en el proceso ════════════════════════════════

const ClawForge = preload("res://core/lab/claw_forge.gd")


## Una pieza de metal del horno, fría y con su forma (la cera perdida y el tallado con lo recomendado).
static func _metal_piece(rid: String, carve := true) -> ClawForge:
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": rid })
	var rec := f.recommended()
	f.wax({ "compensate": true, "mold": String(rec.wax.mold) })
	f.invest(rec.invest)
	f.load_machine({ "machine": "calentar", "what": "molde" })
	f.burnout(rec.burnout)
	f.mix(rec.mix)
	f.load_machine(rec.load_machine)
	f.fire(rec.fire)
	f.cool(String(rec.cool))
	f.divest()
	if carve:
		var a: Dictionary = rec.carve_to
		for tool: String in ["sierra", "muela_fina"]:
			var p := a.duplicate()
			p["tool"] = tool
			f.carve_to(p)
	return f


static func _seam_all(f: ClawForge) -> Dictionary:
	var ws := f.weld_state()
	var n := int(ws.pulsesNeed)
	var last := {}
	for i in n:
		last = f.weld_pulse({ "u": (float(i) + 0.5) / float(n) })
	return last


func test_el_motor_suelda_la_punta_de_oro_y_la_costura_se_lima() -> void:
	var f := _metal_piece("oro")
	assert_true(bool(f.snapshot().piece.carved), "la funda de oro, tallada")
	var geo := f.weld_seam_geometry()
	assert_true(float(geo.lengthMm) > 3.0 and float(geo.radiusMm) > 0.5, "la costura va alrededor de la funda: %s mm" % geo.lengthMm)
	# el oro refleja el láser: con el micro-TIG, que no depende de la absorción
	var st := f.weld_setup({ "method": "tig", "part": "punta", "material": "oro", "current_a": 400.0, "pulse_ms": 12.0, "gas": "argon", "overlap": 0.85, "align_mm": 0.3 })
	assert_true(bool(st.ok), "la soldadura preparada: %s" % st.text)
	assert_false(bool(st.aligned), "desalineada 0,3 mm (la junta admite el 10 % de 1 mm)")
	assert_true(int(st.pulsesNeed) > 3, "%d puntos a lo largo de la costura" % st.pulsesNeed)
	var bad := f.weld_pulse({ "u": 0.1 })
	assert_eq(String(bad.defect), "desalineada", "sin alinear no se suelda")
	assert_eq(int(f.weld_state().pulses), 0, "y no cuenta")
	var al := f.weld_align(0.05)
	assert_true(bool(al.ok) and bool(al.aligned), "alineadas a 0,05 mm: %s" % al.text)
	var first := f.weld_pulse({ "u": 0.1 })
	assert_true(bool(first.ok) and int(first.covered) == 1 and not bool(first.done), "el primer punto: %s" % first.text)
	var again := f.weld_pulse({ "u": 0.1 })
	assert_true(bool(again.remelt) and int(again.covered) == 1 and int(again.pulses) == 2, "el mismo tramo otra vez: refundido")
	var early := f.weld_finish()
	assert_eq(String(early.defect), "incompleta", "sin acabar la costura no hay unión")
	var last := _seam_all(f)
	assert_true(bool(last.done), "la costura entera: %s" % last.text)
	var ws := f.weld_state()
	assert_true(bool(ws.done) and bool(ws.joint.ok), "la unión sale: %s" % ws.joint.text)
	assert_near(float(ws.joint.efficiency), 0.5, 1e-9, 0.0, "el oro soldado, la mitad")
	assert_true(float(ws.joint.jointMPa) <= float(ws.joint.baseMPa), "nunca más que el oro")
	assert_eq(int(ws.covered), int(ws.pulsesNeed), "todos los tramos")
	assert_true(f.check("soldada"), "la condición del tutorial")
	assert_false(f.check("costura_limada"), "la costura aún sin limar")
	# el cordón sobresale: la pieza ya no está lista hasta limarlo con la muela fina y pulirla
	var cs := f.carve_state()
	assert_true(float(cs.excessMm) > float(ForgeData.SHAPE_TOL.value), "el cordón sobresale %s mm" % cs.excessMm)
	assert_true(String(cs.text).contains("cordón"), "y lo dice: %s" % cs.text)
	assert_true(f.snapshot().polish.is_empty(), "lo pulido, a rehacer")
	var filed := f.carve_to({ "tool": "muela_fina", "abrasive": "diamante", "coolant": true, "force_n": 10.0 })
	assert_true(bool(filed.ok) and int(filed.passes) >= 1, "limada en %d pasadas" % filed.passes)
	assert_true(f.check("costura_limada"), "la costura limada")
	assert_eq(String(f.carve_state().verdict), "correcta", "con la forma de la garra")
	f.protect({ "barrier": "aerogel", "thickness_mm": 3.0 })
	var pol := f.polish({ "abrasive": "diamante", "grain_um": 9.0 })
	assert_true(bool(pol.ok), "pulida")
	var rc := f.result_claw()
	assert_true(bool(rc.ok) and rc.weld != null, "la garra sale con su unión")
	assert_eq(String(rc.weld.method), "tig", "el método")
	assert_eq(String(f.report().verdict), "bien", "terminada")
	# lo que llega a la cetrería: todos los campos de antes y la unión
	var cs2 := f.care_setup()
	for k: String in ["animal", "claw", "inlay", "careSupported", "reason", "piece"]:
		assert_true(cs2.has(k), "care_setup sigue teniendo %s" % k)
	for k: String in ["material", "ok", "finish", "carved", "polished", "coverMm", "wallMm", "wallLeftMm", "lengthMm", "bondAreaMm2", "gapMm", "fitTested", "massKg", "raUm", "castScale", "weld"]:
		assert_true((cs2.piece as Dictionary).has(k), "piece tiene %s" % k)
	var w: Dictionary = cs2.piece.weld
	assert_true(float(w.jointMPa) > 0.0 and float(w.jointMPa) <= float(w.baseMPa), "la unión con lo que aguanta")
	assert_eq(String(w.tipMaterial), "oro", "la punta de oro")
	# sin soldar, el campo existe y es null
	assert_true(not _metal_piece("acero").snapshot().piece.has("weld") and _metal_piece("acero").result_claw().weld == null, "sin soldar, null")


func test_el_motor_titanio_sin_argon_y_el_metal_duro_con_plata() -> void:
	var f := _metal_piece("titanio")
	var st := f.weld_setup({ "method": "laser", "part": "reparar", "energy_j": 25.0, "pulse_ms": 5.0, "spot_mm": 0.8, "gas": "aire", "overlap": 0.65, "align_mm": 0.0 })
	assert_true(bool(st.ok), "preparada (el motor deja soldar al aire: lo que sale lo dice la unión)")
	assert_true(bool(st.spot.contaminated), "el punto ya avisa")
	_seam_all(f)
	var ws := f.weld_state()
	assert_eq(String(ws.joint.defect), "contaminada", "contaminada")
	assert_false(bool(f.snapshot().piece.ok), "la pieza, estropeada")
	assert_eq(String(f.snapshot().piece.finish), "oxidado", "azul: oxidada")
	assert_eq(String(f.report().verdict), "soldadura_mala", "el veredicto")
	assert_true(String(f.report().verdictText).length() > 10 and not (f.report().advice as Array).is_empty(), "con su consejo")
	# la misma pieza con argón sale bien
	var g := _metal_piece("titanio")
	g.weld_setup({ "method": "laser", "part": "reparar", "energy_j": 25.0, "pulse_ms": 5.0, "spot_mm": 0.8, "gas": "argon", "overlap": 0.65, "align_mm": 0.0 })
	_seam_all(g)
	assert_true(bool(g.weld_state().joint.ok), "con argón, bien: %s" % g.weld_state().joint.text)
	assert_eq(String(g.weld_state().joint.color.name), "plateado", "plateado")
	# el metal duro: una punta de carburo sobre una funda de acero, solo con soldadura fuerte
	var h := _metal_piece("acero")
	var no := h.weld_setup({ "method": "laser", "part": "punta", "material": "tungsteno", "energy_j": 30.0, "pulse_ms": 4.0, "spot_mm": 0.6, "gas": "argon" })
	assert_false(bool(no.ok), "el láser no une el metal duro")
	assert_eq(String(no.defect), "metal_duro", "y dice por qué")
	assert_eq(String(h.weld_pulse({ "u": 0.5 }).defect), "metal_duro", "los pulsos no cuentan")
	var bz := h.weld_setup({ "method": "braze", "part": "punta", "material": "tungsteno", "temp_c": 700.0, "gap_mm": 0.04 })
	assert_true(bool(bz.ok), "con plata a 700 °C, sí: %s" % bz.text)
	assert_true(int(bz.pulsesNeed) >= 2, "el soplete, por tramos")
	_seam_all(h)
	var j: Dictionary = h.weld_state().joint
	assert_true(bool(j.ok), "la unión de plata: %s" % j.text)
	assert_true(float(j.jointMPa) <= float(j.baseMPa) + 1e-9, "nunca más que el metal base")
	assert_eq(String(h.snapshot().piece.weld.tipMaterial), "tungsteno", "la punta de carburo va con la pieza")
	# una gema o la queratina, nunca
	var k := _metal_piece("acero")
	assert_eq(String(k.weld_setup({ "method": "tig", "part": "punta", "material": "zafiro" }).defect), "gema", "el zafiro no se suelda")
	assert_eq(String(k.weld_setup({ "method": "tig", "part": "punta", "material": "none" }).defect), "queratina", "la queratina, nunca")
	# una pieza que no es de metal no se suelda
	var z := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "" })
	z.choose("cuarzo")
	assert_eq(String(z.weld_setup({ "method": "laser" }).defect), "no_metal", "el cuarzo no se suelda")


func test_el_motor_perfora_con_demasiada_energia_y_lo_dice() -> void:
	var f := _metal_piece("acero")
	f.weld_setup({ "method": "laser", "part": "reparar", "energy_j": 80.0, "pulse_ms": 1.0, "spot_mm": 0.3, "gas": "argon", "overlap": 0.65 })
	_seam_all(f)
	var j: Dictionary = f.weld_state().joint
	assert_eq(String(j.defect), "perforada", "80 J en 1 ms sobre 0,3 mm perfora 1 mm de pared")
	assert_true(String(j.text).contains("Menos energía"), "y dice qué cambiar")
	assert_false(bool(f.snapshot().piece.ok), "la pieza, agujereada")
	# la misma costura con menos energía y un pulso más largo, bien
	var g := _metal_piece("acero")
	g.weld_setup({ "method": "laser", "part": "reparar", "energy_j": 30.0, "pulse_ms": 4.0, "spot_mm": 0.6, "gas": "argon", "overlap": 0.85 })
	_seam_all(g)
	assert_true(bool(g.weld_state().joint.ok), "30 J en 4 ms sobre 0,6 mm: bien (%s)" % g.weld_state().joint.text)
	# y con muy poca, falta de fusión: aguanta menos
	var h := _metal_piece("acero")
	h.weld_setup({ "method": "laser", "part": "reparar", "energy_j": 3.0, "pulse_ms": 10.0, "spot_mm": 1.5, "gas": "argon", "overlap": 0.65 })
	_seam_all(h)
	var jh: Dictionary = h.weld_state().joint
	assert_eq(String(jh.defect), "falta_fusion", "3 J no atraviesan la pared")
	assert_true(float(jh.jointMPa) < float(g.weld_state().joint.jointMPa), "aguanta menos que la buena")
