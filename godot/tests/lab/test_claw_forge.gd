## Reforja experimental de garras (unidad 5d, core/lab/claw_forge.gd): datos con fuente, invariantes de la física,
## determinismo, la garra resultante y los textos.
##   - Un abrasivo más blando que la pieza nunca la talla ni la pule.
##   - Más temperatura nunca funde (ni degrada) menos.
##   - El diamante al aire por encima de su temperatura de oxidación siempre se degrada.
##   - Una funda con más superficie pegada nunca se despega antes.
##   - Nada caliente toca la garra viva sin quemarla; y una barrera más gruesa nunca la deja más caliente.
extends "res://tests/case.gd"

const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const Data = preload("res://core/lab/data.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const Contact = preload("res://core/shared/contact.gd")

const QUALITIES := ["primary", "secondary", "estimate", "ficcion", "dibujo"]
const ATMS := ["aire", "argon", "vacio", "h2_ch4"]


static func _forge(rid: String, animal := "rapaz", claw := "aguila") -> RefCounted:
	return ClawForge.new({ "animal": animal, "claw": claw, "recipe": rid })


## Sigue la receta al pie de la letra (los pasos con acción del tutorial).
static func _follow(f: RefCounted) -> void:
	for st: Dictionary in f.tutorial():
		if String(st.action) != "":
			f.do_step(st)


func _sourced(where: String, d: Variant) -> void:
	assert_true(d is Dictionary, "%s: es un dato" % where)
	if not (d is Dictionary):
		return
	assert_true(QUALITIES.has(String(d.get("quality", ""))), "%s: calidad conocida (%s)" % [where, d.get("quality")])
	assert_true(String(d.get("source", "")).length() > 15, "%s: fuente" % where)


# ════════ Datos ════════

func test_cada_dato_lleva_fuente_y_calidad() -> void:
	for mid: String in ForgeData.MATERIALS:
		var m: Dictionary = ForgeData.MATERIALS[mid]
		for key: String in ["melt_c", "soften_c", "air_c", "inert_c", "inversion_c", "alpha", "k", "cp", "anneal_c"]:
			if m.get(key) != null:
				_sourced("%s.%s" % [mid, key], m[key])
		assert_true(String(m.route_text).length() > 20, "%s: cómo se hace" % mid)
	for rid: String in ForgeData.RECIPE_IDS:
		var r: Dictionary = ForgeData.RECIPES[rid]
		_sourced(rid, r)
		for key: String in ["temp_c", "time_s", "pressure_mpa"]:
			_sourced("%s.%s" % [rid, key], r[key])
		assert_true(String(r.atmosphere.source).length() > 15, "%s: fuente de la atmósfera" % rid)
		assert_true(String(r.cool.source).length() > 15, "%s: fuente del enfriamiento" % rid)
		if r.has("growth"):
			_sourced("%s.growth" % rid, r.growth)
		for p: Dictionary in r.powders:
			assert_true(ForgeData.POWDERS.has(p.id), "%s: polvo %s conocido" % [rid, p.id])
			assert_true(float(p.min) <= float(p.value) and float(p.value) <= float(p.max), "%s: %s dentro de su margen" % [rid, p.id])
		assert_true(float(r.temp_c.min) <= float(r.temp_c.value) and float(r.temp_c.value) <= float(r.temp_c.max), "%s: temperatura dentro de su margen" % rid)
		assert_true(r.atmosphere.ok.has(r.atmosphere.value), "%s: atmósfera recomendada buena" % rid)
	for group: Dictionary in [ForgeData.COOLING, ForgeData.ABRASIVES, ForgeData.BARRIERS, ForgeData.COATINGS, ForgeData.ADHESIVES, ForgeData.POWDERS]:
		for id: String in group:
			if group == ForgeData.POWDERS:
				assert_true(String(group[id].source).length() > 15, "polvo %s: fuente" % id)
			else:
				_sourced(id, group[id])
	_sourced("FURNACE", ForgeData.FURNACE)
	for c: Dictionary in ForgeData.CONTROLS:
		_sourced("mando " + String(c.id), c)
		assert_true(String(c.what).length() > 20 and String(c.why).length() > 20, "mando %s: qué hace y por qué" % c.id)
	var extra := { "EDGE_CHIP_BETA": ForgeData.EDGE_CHIP_BETA, "DUCTILE_REGIME_K": ForgeData.DUCTILE_REGIME_K, "FINISH_SKIN_MM": ForgeData.FINISH_SKIN_MM, "KERATIN_SHEAR": ForgeData.KERATIN_SHEAR, "SHEATH": ForgeData.SHEATH, "CARVE_DEFAULTS": ForgeData.CARVE_DEFAULTS }
	for k: String in extra:
		_sourced(k, extra[k])
	_sourced("alumina", ForgeData.NEW_MATERIALS.alumina)
	# la prótesis de verdad (unidad 5j): el material y su uso en una garra (estimación: la técnica del pico)
	var pe: Dictionary = ForgeData.PROSTHESIS.acrilico
	_sourced("acrilico", pe)
	_sourced("acrilico.use", { "quality": pe.use_quality, "source": pe.use_source })
	# el calor específico, con k y la densidad (el calor de limar el bloque en la cetrería): todos los que tienen k
	for mid: String in ForgeData.MATERIALS:
		var m: Dictionary = ForgeData.MATERIALS[mid]
		assert_eq(m.get("k") != null, m.get("cp") != null, "%s: k y cp van juntos" % mid)
		if m.get("cp") != null:
			assert_true(ForgeData.density_of(mid) != null, "%s: y su densidad" % mid)
			assert_true(float(m.cp.value) > 100.0 and float(m.cp.value) < 2000.0, "%s: un calor específico de sólido (%s J/(kg·K))" % [mid, m.cp.value])


func test_lo_que_no_se_hace_va_como_ficcion() -> void:
	assert_eq(ForgeData.FURNACE.quality, "ficcion", "el horno que lo junta todo es ficción")
	assert_eq(ForgeData.COATINGS.fundido.quality, "ficcion", "verter material fundido sobre la garra es ficción")
	var f := _forge("zafiro")
	_follow(f)
	f.protect({ "barrier": "aerogel", "thickness_mm": 5.0 })
	var c: Dictionary = f.coat({ "method": "ald_alumina", "target": "garra_viva", "time_s": 600.0 })
	assert_true(bool(c.fiction), "recubrir la garra viva es ficción")
	assert_true((c.fictionWhy as Array).size() >= 2, "y dice por qué: nadie lo hace y en vacío no entra un animal")
	assert_eq(f.result_claw().quality, "ficcion", "la garra resultante va marcada")
	assert_eq(f.report().quality, "ficcion")


func test_los_materiales_del_banco_tienen_su_ficha_de_horno() -> void:
	for e: Dictionary in Data.INLAYS:
		if e.id != "none":
			assert_true(ForgeData.MATERIALS.has(e.id), "%s: ficha de horno" % e.id)
	assert_true(Data.find_by_id(Data.INLAYS, "alumina") == null, "la alúmina nueva no toca el catálogo 1.x")
	var a: Variant = ForgeData.inlay_entry("alumina")
	assert_true(a != null and float(a.hv) > 0.0 and float(a.E) > 0.0, "la alúmina lleva dureza y módulo")
	assert_eq(ForgeData.density_of("alumina"), 3900.0)
	assert_true(ForgeData.strength_of("alumina") != null, "y resistencia para el afilado")


func test_las_durezas_de_los_abrasivos_son_las_del_taller() -> void:
	for id: String in ["corindon", "sic", "cbn", "diamante"]:
		var key: String = { "corindon": "al2o3", "sic": "sic", "cbn": "cbn", "diamante": "diamante" }[id]
		assert_eq(float(ForgeData.ABRASIVES[id].hv), float(Abrasives.ABRASIVES[key].hv), "%s: la misma dureza que en el taller" % id)
	assert_eq(float(ForgeData.ABRASIVES.lima_acero.hv), float(CareData.TOOLS.lima_fina.tool_hv), "la lima, la de la cetrería")
	assert_eq(float(ForgeData.COOLING.aire.h), float(CareData.THERMAL.h_air.value), "el aire, el de la cetrería")


# ════════ Invariantes ════════

func test_un_abrasivo_mas_blando_nunca_talla_ni_pule() -> void:
	var checked := 0
	for mid: String in ForgeData.MATERIALS:
		var e: Variant = ForgeData.inlay_entry(mid)
		for aid: String in ForgeData.ABRASIVES:
			var ab: Dictionary = ForgeData.ABRASIVES[aid]
			assert_true(ClawForge.bite_efficiency(float(ab.hv) * 0.999, float(ab.hv)) == 0.0, "un pelo más blando ya no muerde")
			var piece := { "ok": true, "material": mid, "form": "bloque" }
			var r := ClawForge.evaluate_carve(piece, { "abrasive": aid }, ClawForge.sheath_geometry(CareData.claw_entry("aguila"), 14.0, 1.0))
			if float(ab.hv) < float(e.hv):
				checked += 1
				assert_false(bool(r.bites), "%s no talla %s" % [aid, mid])
				assert_eq(float(r.removedMm3), 0.0, "%s sobre %s: no arranca nada" % [aid, mid])
				assert_eq(r.defect, "no_muerde")
			else:
				assert_true(bool(r.bites), "%s talla %s (igual o más duro)" % [aid, mid])
	assert_true(checked > 10, "casos más blandos: %d" % checked)
	# pulir: la lima de acero resbala sobre el zafiro; la pasta de diamante lo pule
	var f := _forge("zafiro")
	_follow(f)
	var p: Dictionary = f.polish({ "abrasive": "lima_acero" })
	assert_false(bool(p.bites), "la lima de acero no pule el zafiro")
	assert_eq(p.defect, "no_muerde")
	assert_true(bool(f.polish({ "abrasive": "diamante", "grain_um": 9.0 }).bites), "el diamante sí")


func test_mas_temperatura_nunca_funde_ni_degrada_menos() -> void:
	for mid: String in ForgeData.MATERIALS:
		for atm: String in ATMS:
			var prev := {}
			var t := 20.0
			while t <= 3000.0:
				var st := ClawForge.heat_state(mid, t, atm)
				for k: String in ["melted", "softened", "oxidized", "graphitized", "inversion"]:
					if prev.get(k, false):
						assert_true(bool(st[k]), "%s en %s: %s a %s °C y no más arriba" % [mid, atm, k, t])
				prev = st
				t += 7.0


func test_el_diamante_al_aire_siempre_se_degrada_por_encima_de_su_oxidacion() -> void:
	var ox := float(ForgeData.MATERIALS.diamante.air_c.value)
	var t := ox
	while t <= 3000.0:
		assert_true(bool(ClawForge.heat_state("diamante", t, "aire").oxidized), "a %s °C al aire se oxida" % t)
		var f := _forge("")
		f.choose("diamante")
		var r: Dictionary = f.heat({ "temp_c": t, "atmosphere": "aire" })
		assert_false(bool(r.ok), "a %s °C la pieza se pierde" % t)
		assert_true(String(r.defect) in ["quemado", "grafitiza"], "a %s °C: %s" % [t, r.defect])
		t += 50.0
	assert_false(bool(ClawForge.heat_state("diamante", ox - 1.0, "aire").oxidized), "por debajo, no")
	assert_false(bool(ClawForge.heat_state("diamante", 1200.0, "vacio").oxidized), "en vacío no se quema…")
	assert_true(bool(ClawForge.heat_state("diamante", 1600.0, "vacio").graphitized), "…pero por encima de ~1500 °C se grafitiza")


func test_mas_superficie_pegada_nunca_se_despega_antes() -> void:
	for aid: String in ForgeData.ADHESIVE_IDS:
		for hum: String in CareData.HUMIDITY_IDS:
			var prev := -1.0
			var a := 1.0
			while a <= 400.0:
				var cap := float(ClawForge.bond_capacity(aid, float(ForgeData.ADHESIVES[aid].gap_ideal), a, hum).capacityN)
				assert_true(cap >= prev, "%s %s: más área, más carga (%s mm²)" % [aid, hum, a])
				prev = cap
				a += 7.5
	# en el proceso: cubrir más garra da más superficie y la misma carga no la despega antes
	var prev_area := 0.0
	var prev_ok := false
	for cover: float in [2.0, 4.0, 8.0, 14.0]:
		var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "oro", "cover_mm": cover, "humidity": "empapada" })
		_follow(f)
		# pegarla ya no es del laboratorio (petición 43; la cetrería usará bond y check_load): aquí se pega a mano
		f.bond(f.recommended().bond)
		f.check_load({ "load_n": 110.0 })
		var area := float(f.snapshot().sheath.innerAreaMm2)
		assert_true(area > prev_area, "cubrir %s mm da más superficie" % cover)
		var ok := bool(f.snapshot().check.ok)
		assert_true(ok or not prev_ok, "con %s mm no se despega si ya aguantaba con menos" % cover)
		prev_area = area
		prev_ok = ok
	assert_true(prev_ok, "cubriendo 14 mm aguanta la fuerza del águila")


func test_nada_caliente_toca_la_garra_viva_sin_quemarla() -> void:
	var char_c: float = CareData.THERMAL.char_c.value
	for t: float in [char_c, 300.0, 500.0, 1064.18, 2053.0]:
		for secs: float in [0.5, 10.0, 600.0]:
			var th := ClawForge.barrier_heating(t, secs, "", 0.0, 2.8)
			assert_true(bool(th.charred), "%s °C durante %s s sin barrera: se quema" % [t, secs])
	var f := _forge("zafiro")
	for cid: String in ForgeData.COATING_IDS:
		var c: Dictionary = ForgeData.COATINGS[cid]
		var r: Dictionary = f.coat({ "method": cid, "target": "garra_viva", "time_s": 30.0 })
		if float(r.tC) >= char_c:
			assert_eq(r.defect, "garra_quemada", "%s a %s °C sobre la garra viva sin barrera" % [cid, r.tC])
		assert_true(bool(r.fiction), "%s sobre la garra viva: ficción" % cid)
		assert_true(c.quality in QUALITIES)


func test_una_barrera_mas_gruesa_nunca_la_deja_mas_caliente() -> void:
	for bid: String in ForgeData.BARRIER_IDS:
		var prev_face := INF
		var prev_quick := INF
		for mm: float in [0.0, 0.5, 1.0, 2.0, 4.0, 8.0]:
			var th := ClawForge.barrier_heating(150.0, 120.0, bid if mm > 0.0 else "", mm, 2.8)
			assert_true(float(th.keratinPeakC) <= prev_face + 1e-9, "%s %s mm: la queratina no se calienta más" % [bid, mm])
			assert_true(float(th.quickPeakC) <= prev_quick + 1e-9, "%s %s mm: la carne viva no se calienta más" % [bid, mm])
			prev_face = float(th.keratinPeakC)
			prev_quick = float(th.quickPeakC)
	# más tiempo o más temperatura nunca la dejan más fría
	var a := ClawForge.barrier_heating(150.0, 60.0, "silicona", 1.0, 2.8)
	var b := ClawForge.barrier_heating(150.0, 120.0, "silicona", 1.0, 2.8)
	var c := ClawForge.barrier_heating(180.0, 120.0, "silicona", 1.0, 2.8)
	assert_true(float(b.quickPeakC) >= float(a.quickPeakC) and float(c.quickPeakC) >= float(b.quickPeakC), "más tiempo y más calor, más caliente")
	# el gel se queda a 100 °C mientras le queda agua
	var g := ClawForge.barrier_heating(400.0, 5.0, "gel", 3.0, 2.8)
	assert_true(float(g.keratinPeakC) <= 100.0 + 1e-6 and float(g.waterLeft) > 0.0, "con agua en el gel, la queratina no pasa de 100 °C: %s" % g.keratinPeakC)
	# una barrera que no aguanta la temperatura deja de proteger
	var hot := ClawForge.barrier_heating(2053.0, 10.0, "aerogel", 5.0, 2.8)
	assert_true(bool(hot.barrierFails) and bool(hot.charred), "el aerogel no aguanta 2053 °C: la garra se quema")


func test_choque_termico_de_manson() -> void:
	var prev := 0.0
	var beta := 0.001
	while beta < 1000.0:
		var psi := ClawForge.manson_psi(beta)
		assert_true(psi >= prev and psi <= 1.0 + 1e-12, "ψ crece con β y no pasa de 1 (β = %s)" % beta)
		prev = psi
		beta *= 1.5
	assert_near(ClawForge.manson_psi(1.0e9), 1.0, 1e-6, 1e-6, "salto brusco: ψ → 1")
	for mid: String in ["zafiro", "vidrio", "cuarzo", "tungsteno", "diamante", "alumina", "circonita", "moissanita"]:
		var last := INF
		for med: String in ["aire", "aceite", "agua"]:
			var lim := ClawForge.shock_limit_c(mid, med, 1.0)
			assert_true(lim <= last, "%s: un medio que enfría más aguanta menos salto (%s)" % [mid, med])
			last = lim
		assert_eq(ClawForge.shock_limit_c(mid, "horno", 1.0), INF, "%s: dentro del horno no hay choque" % mid)
	assert_eq(ClawForge.shock_limit_c("oro", "agua", 1.0), INF, "un metal dúctil no se agrieta por choque")
	# la bola de zafiro de Verneuil: al aire bien, en agua se agrieta
	var f := _forge("zafiro")
	for st: Dictionary in f.tutorial():
		if String(st.action) in ["mix", "fire"]:
			f.do_step(st)
	var w: Dictionary = ClawForge.evaluate_cool(f.snapshot().piece, "agua", f.snapshot().sheath)
	assert_eq(w.defect, "choque", "zafiro a 2100 °C en agua: %s °C contra %s" % [w.deltaC, w.limitC])
	assert_true(bool(ClawForge.evaluate_cool(f.snapshot().piece, "aire", f.snapshot().sheath).ok), "al aire, bien")


func test_el_cuarzo_y_el_vidrio_se_enfrian_en_el_horno() -> void:
	var f := _forge("")
	f.choose("cuarzo")
	assert_true(bool(f.heat({ "temp_c": 600.0, "atmosphere": "aire" }).ok), "el cuarzo aguanta 600 °C…")
	assert_eq(f.cool("aire").defect, "inversion", "…pero enfriado al aire cruza 573 °C deprisa y se agrieta")
	var g := _forge("")
	g.choose("cuarzo")
	g.heat({ "temp_c": 600.0, "atmosphere": "aire" })
	assert_true(bool(g.cool("horno").ok), "dentro del horno, no")
	var v := _forge("vidrio")
	for st: Dictionary in v.tutorial():
		if String(st.action) in ["mix", "fire"]:
			v.do_step(st)
	assert_eq(v.cool("aire").defect, "sin_recocer", "el vidrio colado sin recocer")


func test_kennedy_y_el_diamante_hpht() -> void:
	assert_near(ClawForge.kennedy_mpa(1345.0), 5302.5, 1e-12, 1e-9)
	assert_near(ClawForge.kennedy_t_max(5500.0), 1424.0, 1e-12, 1e-9)
	var f := _forge("diamante_hpht")
	var rec: Dictionary = f.recommended()
	f.mix(rec.mix)
	var hot := (rec.fire as Dictionary).duplicate()
	hot["temp_c"] = 1424.5
	assert_eq(f.fire(hot).defect, "caliente", "pasada la línea de Kennedy a 5,5 GPa sale grafito")
	hot["temp_c"] = 1423.5
	assert_true(bool(f.fire(hot).ok), "justo debajo, diamante")


func test_desconchado_del_borde_al_tallar() -> void:
	# el borde fino de una pieza frágil se desconcha; con más pared aguanta más
	var sh := ClawForge.sheath_geometry(CareData.claw_entry("aguila"), 14.0, 0.3)
	var piece := { "ok": true, "material": "vidrio", "form": "bloque" }
	var soft := ClawForge.evaluate_carve(piece, { "abrasive": "diamante", "force_n": 10.0 }, sh)
	assert_true(bool(soft.ok), "10 N en un borde de vidrio de 0,3 mm: aguanta (%s N)" % soft.edgeChipN)
	var hard := ClawForge.evaluate_carve(piece, { "abrasive": "diamante", "force_n": 60.0 }, sh)
	assert_eq(hard.defect, "astilla", "60 N: se desconcha")
	var dry := ClawForge.evaluate_carve(piece, { "abrasive": "diamante", "coolant": false }, sh)
	assert_eq(dry.defect, "grieta_calor", "el vidrio en seco se agrieta")
	assert_true(bool(dry.wheelBurn), "y la muela de diamante se quema")
	var metal := ClawForge.evaluate_carve({ "ok": true, "material": "acero", "form": "bloque" }, { "abrasive": "diamante", "force_n": 500.0 }, sh)
	assert_false(bool(metal.chipped), "un metal no se desconcha")
	var prev := 0.0
	for d: float in [0.1, 0.3, 1.0, 3.0]:
		var fc := ClawForge.edge_chip_n(0.75, d)
		assert_true(fc > prev, "más pared, más fuerza para desconcharla")
		prev = fc


# ════════ Determinismo y lecturas ════════

func test_determinista() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var a := _forge(rid)
		var b := _forge(rid)
		_follow(a)
		_follow(b)
		assert_true(same(a.snapshot(), b.snapshot()), "%s: el mismo proceso da lo mismo" % rid)
		assert_true(same(a.result_claw(), b.result_claw()), "%s: la misma garra" % rid)
	var x := ClawForge.barrier_heating(150.0, 300.0, "gel", 2.0, 2.8)
	var y := ClawForge.barrier_heating(150.0, 300.0, "gel", 2.0, 2.8)
	assert_true(same(x, y), "el modelo térmico es determinista")


func test_la_garra_resultante_pasa_al_banco() -> void:
	var f := _forge("zafiro")
	_follow(f)
	var rc: Dictionary = f.result_claw()
	assert_true(bool(rc.ok), "garra reforjada")
	assert_eq(rc.inlay, "zafiro")
	assert_true(bool(rc.inBench), "con un material del banco")
	assert_eq(rc.benchTwin, "zafiro")
	assert_eq(float(rc.hv), 2000.0)
	assert_eq(float(rc.E), 400.0)
	assert_eq(float(rc.strengthMPa), 760.0, "la resistencia de ClawFracture")
	assert_near(float(rc.sheathMassKg), 3980.0 * float(f.snapshot().sheath.volumeMm3) * 1.0e-9, 1e-12, 1e-15, "masa de la funda: ρ·V")
	assert_true(float(rc.clawMassKg) > float(rc.sheathMassKg), "la garra entera pesa la queratina y la funda")
	assert_eq(float(rc.sharpness), 0.0, "pulir no afila: la punta sigue con su radio natural")
	var nat: float = ClawSharpness.radius_um_of_area(float(CareData.claw_entry("aguila").area))
	assert_eq(float(rc.tipRadiusUm), nat)
	var sharp: Dictionary = f.polish({ "abrasive": "diamante", "grain_um": 9.0, "sharpen": true })
	assert_true(float(sharp.sharpness) > 0.0 and float(sharp.sharpness) <= 1.0, "afilado de ClawSharpness")
	var blunt := _forge("zafiro")
	_follow(blunt)
	assert_true(float(sharp.chipLoadN) < float(blunt.snapshot().polish.chipLoadN), "una punta más fina aguanta menos de lado (Pattrick)")
	assert_true(float(f.result_claw().sharpness) > 0.0, "la garra resultante lleva el afilado")
	var cs: Dictionary = f.care_setup()
	assert_eq([cs.animal, cs.claw, cs.inlay, cs.careSupported], ["rapaz", "aguila", "zafiro", true], "la cetrería sigue con la garra de zafiro")
	var care := ClawCare.new(cs)
	assert_true(bool(care.snapshot().reforged), "ClawCare la toma como reforjada")
	# la alúmina nueva: no está en el banco de la 1.x (Data.INLAYS) ni tiene gemelo; desde la 5g está en el catálogo 2.0 (el
	# banco la tiene: in_bench mira Catalog.INLAYS) y la cetrería la lima con su propio id
	var al := _forge("alumina")
	_follow(al)
	assert_eq(al.result_claw().inlay, "alumina")
	assert_true(Data.find_by_id(Data.INLAYS, "alumina") == null, "(no está en el banco de la 1.x)")
	assert_true(bool(al.result_claw().inBench), "la alúmina nueva está en el banco de la 2.0")
	assert_eq(al.result_claw().benchTwin, "alumina", "y va como ella misma")
	var cs2: Dictionary = al.care_setup()
	assert_true(bool(cs2.careSupported), "la cetrería la conoce (catálogo 2.0)")
	assert_eq(cs2.inlay, "alumina", "con su propio id")
	assert_eq(String(ClawCare.new(cs2).setup().inlay), "alumina", "y ClawCare la toma así")


func test_el_rubi_es_corindon_como_el_zafiro() -> void:
	var ru: Dictionary = ForgeData.inlay_entry("rubi")
	var za: Dictionary = ForgeData.inlay_entry("zafiro")
	for k: String in ["hv", "E", "mohs"]:
		assert_eq(float(ru[k]), float(za[k]), "rubí y zafiro: el mismo %s" % k)
	assert_eq(ForgeData.density_of("rubi"), ForgeData.density_of("zafiro"), "la misma densidad")
	var s1: Dictionary = ForgeData.strength_of("rubi")
	var s2: Dictionary = ForgeData.strength_of("zafiro")
	for k: String in ["value", "min", "max", "kic"]:
		assert_eq(float(s1[k]), float(s2[k]), "la misma resistencia (%s)" % k)
	assert_eq(String(ForgeData.NEW_MATERIALS.rubi.bench_twin), "zafiro", "su gemelo con la misma mecánica es el zafiro")
	assert_eq(ForgeData.bench_twin("rubi"), "rubi", "y en el banco de la 2.0 ya está él mismo")
	for k: String in ["melt_c", "alpha", "k"]:
		assert_eq(float(ForgeData.MATERIALS.rubi[k].value), float(ForgeData.MATERIALS.zafiro[k].value), "la misma ficha térmica (%s)" % k)
	# las entradas nuevas tienen la forma de Data.INLAYS (para el catálogo 2.0)
	for id: String in ForgeData.NEW_MATERIALS:
		var e: Dictionary = ForgeData.NEW_MATERIALS[id]
		for k: String in ["id", "name", "short", "hv", "mohs", "E", "area", "alpha", "col", "density", "strength_mpa", "kic"]:
			assert_true(e.has(k), "%s: tiene %s" % [id, k])
		assert_eq(String(e.id), id)
		assert_true(ForgeData.in_bench(id), "%s está en el banco de la 2.0" % id)
	var f := _forge("rubi")
	_follow(f)
	assert_eq(f.result_claw().inlay, "rubi", "el horno hace rubí con su id")
	assert_eq(f.care_setup().inlay, "rubi", "y la cetrería lo lima con su propio id (unidad 5g), con la mecánica del zafiro")


func test_el_acabado_de_la_pieza() -> void:
	# bien hecha: en bruto al salir, tallada, pulida
	var f := _forge("metal_duro")
	var rec: Dictionary = f.recommended()
	f.mix(rec.mix)
	assert_eq(f.fire(rec.fire).piece.finish, "bruto", "sale del horno en bruto")
	f.cool(rec.cool)
	f.carve(rec.carve)
	assert_eq(f.snapshot().piece.finish, "tallado")
	f.protect(rec.protect)
	f.bond(rec.bond)
	f.polish(rec.polish)
	f.check_load({})
	assert_eq(f.result_claw().finish, "pulido")
	assert_true(ForgeData.FINISH_IDS.has(String(f.result_claw().finish)))
	# porosa: el metal duro frío o al poco tiempo; quemada: al aire
	var cold: Dictionary = rec.fire.duplicate()
	cold["temp_c"] = 1300.0
	var g := _forge("metal_duro")
	g.mix(rec.mix)
	assert_eq(g.fire(cold).piece.finish, "poroso", "sin fase líquida queda porosa")
	var air: Dictionary = rec.fire.duplicate()
	air["atmosphere"] = "aire"
	assert_eq(g.fire(air).piece.finish, "quemado", "al aire se oxida")
	# agrietada al enfriar y astillada al tallar
	var z := _forge("zafiro")
	var rz: Dictionary = z.recommended()
	z.mix(rz.mix)
	z.fire(rz.fire)
	z.cool("agua")
	assert_eq(z.snapshot().piece.finish, "agrietado", "la bola de zafiro en agua")
	var v := _forge("vidrio")
	var rv: Dictionary = v.recommended()
	v.mix(rv.mix)
	v.fire(rv.fire)
	v.cool(rv.cool)
	v.carve({ "abrasive": "diamante", "force_n": 500.0 })
	assert_eq(v.snapshot().piece.finish, "astillado", "el vidrio apretado contra la muela")
	# el diamante comprado y calentado al aire se quema; el acero, cascarilla
	var d := _forge("")
	d.choose("diamante")
	d.heat({ "temp_c": 800.0, "atmosphere": "aire" })
	assert_eq(d.snapshot().piece.finish, "quemado")
	var a := _forge("")
	a.choose("acero")
	assert_true(bool(a.heat({ "temp_c": 950.0, "atmosphere": "aire" }).ok), "el acero aguanta")
	assert_eq(a.snapshot().piece.finish, "oxidado", "pero con cascarilla")
	# la capa: la proyección por plasma sale porosa y, pulida, pulida (la porosidad sigue)
	var w := _forge("acero")
	_follow(w)
	var c: Dictionary = w.coat({ "method": "plasma_alumina", "target": "funda" })
	assert_true(bool(c.ok), "alúmina por plasma sobre la funda de acero: %s" % c.text)
	assert_eq(c.finish, "poroso")
	w.polish({ "abrasive": "diamante", "grain_um": 9.0 })
	assert_eq(w.result_claw().finish, "pulido")
	assert_eq(float(w.result_claw().coating.porosity), 0.04, "la porosidad se queda")
	# la lima de acero no pule la alúmina por plasma (~950 HV): la dureza de la capa, no la de la alúmina maciza
	var w2 := _forge("acero")
	_follow(w2)
	w2.coat({ "method": "plasma_alumina", "target": "funda" })
	var pl: Dictionary = w2.polish({ "abrasive": "lima_acero" })
	assert_false(bool(pl.bites), "700 HV contra 950 HV")
	assert_eq(float(pl.surfaceHv), 950.0)


func test_el_calor_de_la_capa_llega_por_la_punta() -> void:
	# la barrera solo tapa la parte viva: una capa caliente sobre la punta la quema igual
	var f := _forge("zafiro")
	f.protect({ "barrier": "aerogel", "thickness_mm": 10.0 })
	var hot: Dictionary = f.live_coat_heating(400.0, 5.0)
	assert_true(bool(hot.tipCharred), "400 °C en la punta: se quema aunque la carne viva esté tapada")
	var lp: Dictionary = f.live_paths()
	assert_true(float(lp.liveWallMm) > 0.0 and float(lp.tipDistanceMm) > 0.0, "la funda de serie cubre punta muerta y parte viva")
	# cubrir menos garra (solo la punta muerta) nunca calienta más la carne viva
	var prev := INF
	for cover: float in [14.0, 10.0, 6.0, 3.0]:
		var g := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "cover_mm": cover })
		g.protect({ "barrier": "aerogel", "thickness_mm": 3.0 })
		var th: Dictionary = g.live_coat_heating(150.0, 120.0)
		assert_true(float(th.quickPeakC) <= prev + 1e-9, "cubrir %s mm: la carne viva no se calienta más" % cover)
		prev = float(th.quickPeakC)
		if cover < float(g.live_paths().quickCoverMm):
			assert_eq(float(g.live_paths().liveWallMm), -1.0, "con %s mm la capa no llega a la parte viva" % cover)
	# más tiempo nunca enfría
	var h := _forge("zafiro")
	var t30: Dictionary = h.live_coat_heating(150.0, 30.0)
	var t600: Dictionary = h.live_coat_heating(150.0, 600.0)
	assert_true(float(t600.quickPeakC) >= float(t30.quickPeakC), "más tiempo, más caliente")
	assert_true(bool(t600.injured), "10 min a 150 °C lesionan la carne viva por dentro de la punta")


func test_el_tutorial_de_la_garra_viva_es_ficcion() -> void:
	var f := _forge("zafiro")
	var steps: Array = f.tutorial("garra_viva")
	assert_true(steps.size() >= 5, "pasos")
	for st: Dictionary in steps:
		if String(st.action) != "":
			f.do_step(st)
	assert_eq(f.report().verdict, "ficcion", f.report().verdictText)
	var rc: Dictionary = f.result_claw()
	assert_eq(rc.quality, "ficcion")
	assert_eq(rc.inlay, "none", "la garra sigue siendo de queratina, con la capa encima")
	assert_eq(String(rc.coating.material), "alumina", "una capa de alúmina, no de zafiro")
	assert_eq(rc.finish, "pulido")
	for st: Dictionary in f.tutorial("garra_viva"):
		if String(st.check) != "":
			assert_true(st.done == true, "%s: hecho" % st.id)
	assert_true((f.report().fiction as Array).size() > 0, "dice por qué es ficción")
func test_los_sonidos_son_ids_conocidos() -> void:
	var known: Array = ClawForge.SFX_FORGE + ClawForge.SFX_LAB
	for rid: String in ForgeData.RECIPE_IDS:
		var f := _forge(rid)
		var results := {}
		for st: Dictionary in f.tutorial():
			if String(st.action) != "":
				results[st.action] = f.do_step(st)
		for act: String in ["fire", "pour", "cool", "carve", "polish", "coat"]:
			var res: Variant = results.get({ "pour": "fire" }.get(act, act), {})
			var id: String = f.sfx_for(act, res if res is Dictionary else {})
			assert_true(known.has(id), "%s %s: «%s»" % [rid, act, id])
	var g := _forge("zafiro")
	assert_eq(g.sfx_for("fire", {}), "forja-llama")
	assert_eq(_forge("diamante_hpht").sfx_for("fire", {}), "forja-prensa")
	assert_eq(_forge("acero").sfx_for("fire", {}), "forja-induccion")
	assert_eq(g.sfx_for("cool", { "medium": "agua" }), "forja-temple")
	assert_eq(g.sfx_for("cool", { "defect": "choque" }), "shatter")


## La superficie de la pieza (lo pidió la 5f; unidad 5j): la que deja la última muela o el último grano, con la regla de la
## cetrería (Ra = h/4 con la hondura del surco de cada grano), igual a lo largo de la pieza. Un grano más fino nunca deja más
## rugosidad; una pieza frágil tallada en régimen frágil se desconcha, y pulida en régimen dúctil ya no; lo que no muerde no
## la cambia; sin tallar, o con una capa sin pulir, no hay superficie (la de su acabado).
func test_la_superficie_de_la_pieza() -> void:
	var ps: Dictionary = ForgeData.PIECE_SURFACE
	var f := _forge("zafiro")
	f.choose("zafiro")
	assert_false(bool(f.surface().ok), "en bruto: la superficie es la del acabado")
	var c: Dictionary = f.carve({ "abrasive": "diamante" })
	var s1: Dictionary = f.surface()
	assert_true(bool(s1.ok) and String(s1.by) == "talla", "tallada: la de la muela")
	var wheel := { "element": "grano", "grain_um": 45.0, "teeth_cm": 22.0, "tool_hv": 10000.0 }
	var h := 2000.0 * Contact.HV_MPA
	assert_near(float(s1.raUm), ClawCare.pass_ra_um(ClawCare.groove_um(wheel, 10.0, 3.0, 3.0, h)), 1e-12, 0.0, "Ra = h/4 con el surco del grano de la muela de serie")
	assert_eq(float(s1.chip), 1.0 if String(c.regime) == "fragil" else 0.0, "desconchada si talla en régimen frágil (%s)" % c.regime)
	assert_eq(float(s1.chip), 1.0, "el zafiro con la muela de 45 µm, en régimen frágil")
	assert_eq((s1.stations as Array).size(), int(ps.stations), "por estación, a lo largo de la pieza")
	for st: Dictionary in s1.stations:
		assert_eq([float(st.ra_um), float(st.burn), float(st.chip), float(st.scratch_deg)], [float(s1.raUm), 0.0, float(s1.chip), float(ps.scratch_deg)], "cada estación, con la forma de la biblioteca")
	assert_eq(var_to_str(f.snapshot().surface), var_to_str(s1), "en la instantánea")
	f.protect({ "barrier": "aerogel", "thickness_mm": 3.0 })
	f.bond({ "adhesive": "epoxi", "gap_mm": 0.15 })
	var prev := INF
	var last: Dictionary = {}
	for g: float in ForgeData.POLISH_GRITS:
		f.polish({ "abrasive": "diamante", "grain_um": g })
		last = f.surface()
		assert_eq(String(last.by), "pulido", "%s µm: la del grano" % g)
		assert_true(float(last.raUm) <= prev + 1e-15, "%s µm: un grano más fino nunca deja más rugosidad (%s ≤ %s)" % [g, last.raUm, prev])
		prev = float(last.raUm)
	assert_eq(float(last.chip), 0.0, "con el grano fino, en régimen dúctil: sin desconchones")
	var before := var_to_str(f.surface())
	assert_false(bool(f.polish({ "abrasive": "lima_acero" }).bites), "(la lima de acero no muerde el zafiro)")
	assert_eq(var_to_str(f.surface()), before, "y no cambia la superficie")
	# un metal: la muela de CBN lo deja más basto que la pasta de diamante, sin desconchones (se lima en régimen dúctil)
	var st2 := _forge("acero")
	st2.choose("acero")
	st2.carve({ "abrasive": "cbn" })
	var rough := float(st2.surface().raUm)
	assert_eq(float(st2.surface().chip), 0.0, "el acero no se desconcha")
	# una capa sobre la funda: hasta que se pule, la de su acabado; pulida, la del grano sobre la capa
	st2.coat({ "method": "plasma_alumina", "target": "funda" })
	assert_false(bool(st2.surface().ok), "con la capa de plasma sin pulir: la de su acabado (porosa)")
	st2.polish({ "abrasive": "diamante", "grain_um": 9.0 })
	var sc: Dictionary = st2.surface()
	assert_true(bool(sc.ok) and String(sc.material) == "alumina", "pulida la capa: la de la capa (%s)" % sc.material)
	assert_true(float(sc.raUm) < rough, "más lisa que la que dejó la muela en el acero")


## La prótesis de una garra rota se hace con lo que queda de ella (stump_mm; lo pidió la 5f, unidad 5j): maciza donde falta
## la garra (no hay queratina dentro) y pegada solo sobre el muñón. Cuanto menos queda, más prótesis maciza, menos queratina
## y menos superficie para pegarla; con la garra entera, la funda de siempre; y para la garra de su dedo.
func test_la_protesis_de_una_garra_rota_usa_lo_que_queda() -> void:
	var base := { "animal": "rapaz", "claw": "aguila", "recipe": "zafiro", "cover_frac": 1.0 }
	var sound := ClawForge.new(base)
	var whole := ClawForge.new(base.merged({ "stump_mm": 35.0 }, true))
	assert_eq(var_to_str(whole.snapshot().sheath), var_to_str(sound.snapshot().sheath), "con la garra entera (lo que queda es todo su largo), la funda de siempre")
	var sh0: Dictionary = sound.snapshot().sheath
	var ker0 := float(sh0.keratinVolumeMm3)
	var prev_area := INF
	var prev_vol := float(sh0.volumeMm3)
	var prev_ker := ker0
	for stump: float in [30.0, 24.0, 18.0, 12.0, 6.0]:
		var f := ClawForge.new(base.merged({ "stump_mm": stump }, true))
		var sh: Dictionary = f.snapshot().sheath
		assert_near(float(sh.goneMm), 35.0 - stump, 1e-9, 0.0, "%s mm: falta lo de más allá" % stump)
		assert_near(float(sh.stumpCoverMm), stump, 1e-9, 0.0, "%s mm: la prótesis entera se pega sobre todo el muñón" % stump)
		assert_true(float(sh.innerAreaMm2) < prev_area, "%s mm: menos muñón, menos superficie para pegar" % stump)
		assert_true(float(sh.volumeMm3) > prev_vol, "%s mm: más prótesis maciza" % stump)
		assert_true(float(sh.keratinVolumeMm3) < prev_ker, "%s mm: y menos queratina" % stump)
		# lo que se pega es lo de la funda sana sobre el muñón; lo que falta se rellena (la queratina que ya no está)
		var tip_only := ClawForge.sheath_geometry(CareData.claw_entry("aguila"), 35.0 - stump, float(sh.wallMm))
		assert_near(float(sh.innerAreaMm2), float(sh0.innerAreaMm2) - float(tip_only.innerAreaMm2), 2e-3, 0.0, "%s mm: la superficie pegada, la del muñón" % stump)
		assert_true(float(sh.solidVolumeMm3) >= float(sh.volumeMm3) - float(sh0.volumeMm3) - 1e-9, "%s mm: lo que se añade es la parte maciza (la queratina que falta, rellena)" % stump)
		prev_area = float(sh.innerAreaMm2)
		prev_vol = float(sh.volumeMm3)
		prev_ker = float(sh.keratinVolumeMm3)
	# una funda corta que no llega a lo que queda no tiene dónde pegarse
	var short := ClawForge.new(base.merged({ "cover_frac": 0.2, "stump_mm": 12.0 }, true))
	assert_eq(float(short.snapshot().sheath.innerAreaMm2), 0.0, "un capuchón de 7 mm no llega a un muñón de 12 mm (faltan 23)")
	short.choose("zafiro")
	short.carve({ "abrasive": "diamante" })
	var b := short.bond({ "adhesive": "epoxi", "gap_mm": 0.15 })
	assert_eq(String(b.defect), "sin_superficie", "y no se pega: %s" % b.text)
	assert_true(String(b.text).contains("prótesis entera"), "y dice qué hacer")
	# para la garra de su dedo: la del dedo II del águila es ~1,39 veces más larga y más gruesa que la del III (la del banco)
	var d2 := ClawForge.new(base.merged({ "digit": "II", "paw": "izquierda" }, true))
	var shape2 := CareData.claw_shape("aguila", "II")
	assert_near(d2.natural_mm(), 35.0 * float(shape2.lengthRatio), 1e-12, 0.0, "el largo de la garra del dedo II")
	assert_near(float(d2.snapshot().sheath.coverMm), d2.natural_mm(), 1e-12, 0.0, "la prótesis entera la cubre toda")
	assert_true(float(d2.snapshot().sheath.rawDiameterMm) > float(sh0.rawDiameterMm), "y pide un cristal más gordo (su base es más alta)")
	assert_eq(String(d2.setup().digit), "II", "con su dedo")


## El sonido de la marcha sigue a la máquina de verdad (lo pidió la 5f; unidad 5j): la del modo con que ha trabajado el
## horno, aunque no sea el de la receta (cada modo es una máquina real); sin marcha aún, la de la receta.
func test_el_sonido_de_la_marcha_sigue_a_la_maquina() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var r := ForgeData.recipe(rid)
		assert_eq(_forge(rid).sfx_for("fire", {}), ClawForge.machine_sfx(ClawForge.machine_for(String(r.mode), r)), "%s: sin marcha, la máquina de la receta" % rid)
		for mode: String in ForgeData.FURNACE.modes:
			var f := _forge(rid)
			var res: Dictionary = f.fire({ "mode": mode, "temp_c": float(r.temp_c.value), "time_s": float(r.time_s.value), "atmosphere": String(r.atmosphere.value), "pressure_mpa": float(r.pressure_mpa.value) })
			var want := ClawForge.machine_sfx(ClawForge.machine_for(mode, r))
			assert_eq(f.sfx_for("fire", res), want, "%s en «%s»: la máquina de ese modo" % [rid, mode])
			assert_eq(f.sfx_for("fire", {}), want, "%s en «%s»: también sin pasarle el resultado (la última marcha)" % [rid, mode])
			assert_true(ClawForge.SFX_FORGE.has(want), "%s: un sonido de la reforja" % want)
	# lo que fallaba: con la receta del zafiro y el horno en inducción suena la bobina, no la llama del soplete
	var z := _forge("zafiro")
	assert_eq(z.sfx_for("fire", z.fire({ "mode": "induccion", "temp_c": 2100.0 })), "forja-induccion", "el zafiro en inducción: la bobina")
	assert_eq(z.sfx_for("fire", z.fire({ "mode": "sinterizar", "temp_c": 2100.0 })), "forja-horno", "y al sinterizar, el horno")
	assert_eq(z.sfx_for("heat", {}), "forja-horno", "calentar una pieza: el horno")
	# la máquina de cada modo
	assert_eq([ClawForge.machine_for("sintetizar", ForgeData.recipe("diamante_hpht")), ClawForge.machine_for("sintetizar", ForgeData.recipe("oro")), ClawForge.machine_for("fundir_colar"), ClawForge.machine_for("calentar")], ["hpht", "verneuil", "colada", "calentar"], "sintetizar con la receta de síntesis o el soplete; colar; calentar")


## La prótesis de verdad (unidad 5j; lo pidió la 5g): con el acrílico dental, la garra rota vuelve a la cetrería como un
## bloque que NO es ficción (la técnica del pico de las aves; en una garra, la misma: estimación), y la cetrería lo conoce;
## con un material de fantasía, el bloque sigue marcado como ficción. El tutorial lo cuenta paso a paso y lo recomendado lo
## hace. El acrílico no va al horno: pasado su reblandecimiento, se ablanda.
func test_la_protesis_de_verdad_es_de_acrilico() -> void:
	var req := { "stump_mm": 18.0, "digit": "II", "paw": "izquierda", "seed": "x" }
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0, "digit": "II", "paw": "izquierda" })
	var piece: Dictionary = f.choose(ForgeTutorial.ACRYLIC)
	assert_true(bool(piece.ok), "el acrílico se mezcla (sin horno)")
	var cs := f.care_setup(req)
	assert_true(bool(cs.careSupported), "y vuelve a la cetrería")
	var b: Dictionary = cs.block
	assert_eq([String(b.material), bool(b.fiction), String(b.quality)], ["acrilico", false, "estimate"], "un bloque de acrílico que no es ficción (en una garra, estimación)")
	assert_false(String(b.note).contains("FICCIÓN"), "sin marca de ficción: %s" % b.note)
	assert_true(String(b.note).begins_with("Así se repara de verdad"), "dice que es lo que se hace de verdad")
	assert_true(String(b.source).contains("Samour") and String(b.source).contains("Matta"), "con sus fuentes")
	assert_true(ClawCare.supports_block("acrilico") and not ClawCare.supports_inlay("acrilico"), "la cetrería lo lima como bloque (no está en el banco)")
	assert_false(ClawCare.supports_block("none"), "la queratina no es un bloque")
	for id: String in ["zafiro", "titanio", "alumina", "rubi"]:
		assert_true(ClawCare.supports_block(id), "%s: también" % id)
	# un material de fantasía: ficción, como siempre
	var z := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0 })
	z.choose("zafiro")
	var zb: Dictionary = z.care_setup(req).block
	assert_eq([bool(zb.fiction), String(zb.quality)], [true, "ficcion"], "el bloque de zafiro sigue siendo ficción")
	assert_true(String(zb.note).contains("acrílico"), "y dice cuál es la vía real")
	# los datos del acrílico, los del PMMA de las prótesis dentales: más blando que la garra y frágil, pero tenaz
	var e: Dictionary = ForgeData.inlay_entry("acrilico")
	assert_true(float(e.hv) < float(CareData.claw_entry("aguila").hv), "más blando que la queratina de la garra")
	var st: Variant = ForgeData.strength_of("acrilico")
	assert_eq([float(st.value), String(st.kind), float(st.kic)], [84.4, "flexion", 1.63], "resistencia y tenacidad del autopolimerizable")
	assert_true(float(st.min) <= float(st.value) and float(st.value) <= float(st.max), "dentro de su banda")
	assert_eq(float(ForgeData.density_of("acrilico")), 1180.0, "densidad")
	# el tutorial: parar la sangre, mezclar, limar en la cetrería y rehacer; lo recomendado lo mezcla
	var ids: Array = ForgeTutorial.steps(ForgeTutorial.ACRYLIC).map(func(x: Dictionary) -> String: return String(x.id))
	assert_eq(ids, ["real", "sangre", "mezclar", "pasar", "rehacer"], "los pasos")
	var g := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0 })
	for s2: Dictionary in g.tutorial(ForgeTutorial.ACRYLIC):
		if String(s2.action) != "":
			g.do_step(s2)
	assert_true(bool(g.care_setup(req).careSupported) and String(g.care_setup(req).block.material) == "acrilico", "siguiendo el tutorial, vuelve con el acrílico")
	# no va al horno: pasado su reblandecimiento (la transición vítrea del PMMA), se ablanda
	var soft := float(ForgeData.MATERIALS.acrilico.soften_c.value)
	var h := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	h.choose("acrilico")
	assert_true(bool(h.heat({ "temp_c": soft - 1.0, "atmosphere": "aire" }).ok), "por debajo, nada")
	var r: Dictionary = h.heat({ "temp_c": soft + 5.0, "atmosphere": "aire" })
	assert_eq(String(r.defect), "reblandece", "por encima, se ablanda")
	assert_true(String(r.text).contains("acrílico") and not String(r.text).contains("vidrio"), "y lo dice del acrílico: %s" % r.text)


func test_textos_sin_rutas_ni_nombres_de_codigo() -> void:
	var texts: Array = []
	for tid: String in ["horno", "garra_viva", ForgeTutorial.ACRYLIC]:
		for st: Dictionary in ForgeTutorial.steps(tid):
			texts.append_array([st.title, st.text, st.source, st.mistake])
	var live := _forge("zafiro")
	for st: Dictionary in live.tutorial("garra_viva"):
		if String(st.action) != "":
			live.do_step(st)
	for cid: String in ForgeData.COATING_IDS:
		var c: Dictionary = live.coat({ "method": cid, "target": "garra_viva", "time_s": 30.0 })
		texts.append_array([c.text] + c.fictionWhy)
	for e: Dictionary in live.events():
		texts.append_array([e.message, e.source])
	for rid: String in ForgeData.RECIPE_IDS:
		for st: Dictionary in ForgeTutorial.steps(rid):
			texts.append_array([st.title, st.text, st.source, st.mistake])
		var f := _forge(rid)
		_follow(f)
		for e: Dictionary in f.events():
			texts.append_array([e.message, e.source])
		texts.append(f.report().verdictText)
	var acr := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "stump_mm": 20.0 })
	acr.choose(ForgeTutorial.ACRYLIC)
	var acs: Dictionary = acr.care_setup({ "stump_mm": 20.0 })
	texts.append_array([acs.block.note, acs.block.source, acr.heat({ "temp_c": 200.0, "atmosphere": "aire" }).text])
	for group: Variant in [ForgeData.MATERIALS, ForgeData.NEW_MATERIALS, ForgeData.PROSTHESIS, ForgeData.RECIPES, ForgeData.CONTROLS, ForgeData.POWDERS, ForgeData.COOLING, ForgeData.ABRASIVES, ForgeData.BARRIERS, ForgeData.COATINGS, ForgeData.ADHESIVES, ForgeData.KERATIN_SHEAR, ForgeData.SHEATH, ForgeData.FURNACE, ForgeData.FINISH_NAMES, ClawForge.VERDICTS]:
		_strings(group, texts)
	for s: String in texts:
		for bad: String in [".gd", "docs/", "res://", "§", "ForgeData", "ClawForge", "CareData", "Contact.", "Data.", "Physics.", "INLAYS", "core/"]:
			assert_false(s.contains(bad), "texto con «%s»: %s" % [bad, s.left(120)])
		assert_false(s.contains("%s") or s.contains("%d"), "texto sin formatear: %s" % s.left(120))


## Las frases (textos de más de 25 letras) de una tabla de datos, recursivamente: lo que la interfaz puede enseñar.
static func _strings(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k: Variant in v:
			_strings(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_strings(x, out)
	elif v is String and String(v).length() > 25:
		out.append(String(v))


func test_la_muela_contra_el_acero() -> void:
	var sh := ClawForge.sheath_geometry(CareData.claw_entry("aguila"), 14.0, 1.0)
	var steel := { "ok": true, "material": "acero", "form": "bloque" }
	assert_eq(ClawForge.evaluate_carve(steel, { "abrasive": "diamante" }, sh).wheelWear, "quimico", "el diamante reacciona con el hierro")
	assert_eq(ClawForge.evaluate_carve(steel, { "abrasive": "sic" }, sh).wheelWear, "quimico", "el carburo de silicio también")
	assert_eq(ClawForge.evaluate_carve(steel, { "abrasive": "cbn" }, sh).wheelWear, "normal", "el CBN no")
	assert_eq(ClawForge.evaluate_carve(steel, { "abrasive": "corindon" }, sh).wheelWear, "normal", "ni el corindón")
	var sapphire := { "ok": true, "material": "zafiro", "form": "bloque" }
	assert_eq(ClawForge.evaluate_carve(sapphire, { "abrasive": "diamante" }, sh).wheelWear, "normal", "el diamante contra el zafiro, normal")
	assert_eq(ClawForge.evaluate_carve(sapphire, { "abrasive": "diamante", "coolant": false }, sh).wheelWear, "quemada", "en seco se quema")
	var f := _forge("acero")
	assert_eq(String(f.recommended().carve.abrasive), "cbn", "la receta del acero recomienda CBN")


func test_cromo_duro_y_soldadura_fuerte() -> void:
	_sourced("BRAZE", ForgeData.BRAZE)
	# el cromo duro sobre la funda de acero: a 55 °C, real; sobre una de zafiro, con pintura conductora antes
	var f := _forge("acero")
	_follow(f)
	var c: Dictionary = f.coat({ "method": "cromo_duro", "target": "funda" })
	assert_true(bool(c.ok), c.text)
	assert_eq(float(c.thicknessUm), 30.0)
	var z := _forge("zafiro")
	_follow(z)
	var cz: Dictionary = z.coat({ "method": "cromo_duro", "target": "funda" })
	assert_true(bool(cz.ok) and String(cz.text).contains("pintura conductora"), cz.text)
	# en la garra viva: ficción; el calor del baño (55 °C, ~1 h) no la quema: la sangre a 32 °C a 2 mm se lleva el calor y la
	# carne viva se queda por debajo del umbral del dolor (el peligro real es el ácido crómico, que el modelo no calcula)
	var g := _forge("zafiro")
	var cl: Dictionary = g.coat({ "method": "cromo_duro", "target": "garra_viva" })
	assert_true(bool(cl.fiction))
	assert_true(bool(cl.ok), "%s" % cl.text)
	assert_true(float(cl.thermal.quickPeakC) < 43.0, "carne viva a %s °C" % cl.thermal.quickPeakC)
	assert_true((cl.fictionWhy as Array).any(func(w: String) -> bool: return w.contains("cromo hexavalente")), "dice lo del baño")
	# la soldadura fuerte no pega una funda a una garra
	var b: Dictionary = f.bond({ "adhesive": "soldadura_fuerte" })
	assert_false(bool(b.ok))
	assert_eq(b.defect, "garra_quemada")
	assert_true(String(b.text).contains("618"), b.text)


## ForgeData.in_bench mira el catálogo de la 2.0 (Catalog.INLAYS: la 1.x y los nuevos de la reforja) y la alúmina nueva lee
## su densidad, su resistencia y su tenacidad de ClawMass y ClawFracture (unidad 5g).
func test_el_banco_de_la_2_0_y_la_alumina_de_claw_mass_y_claw_fracture() -> void:
	var ids: Array = ["none", "vidrio", "zafiro", "diamante", "rubi", "alumina", "tin", "cromo", "nada"]
	for e: Dictionary in Catalog.INLAYS:
		ids.append(String(e.id))
	for id: String in ids:
		var cat: bool = id != "none" and Catalog.find_by_id(Catalog.INLAYS, id) != null
		assert_eq(ForgeData.in_bench(id), cat, "%s: lo mismo que Catalog.INLAYS" % id)
	var al: Dictionary = ForgeData.NEW_MATERIALS.alumina
	assert_eq(float(al.density), float(ClawMass.DENSITY.alumina.value), "la densidad de la alúmina, la de ClawMass")
	for k: Array in [["strength_mpa", "value"], ["strength_min", "min"], ["strength_max", "max"], ["kic", "kic"]]:
		assert_eq(float(al[k[0]]), float(ClawFracture.BRITTLE.alumina[k[1]]), "su %s, el de ClawFracture" % k[0])
	assert_eq(ForgeData.density_of("alumina"), float(ClawMass.DENSITY.alumina.value), "y density_of lo da")
