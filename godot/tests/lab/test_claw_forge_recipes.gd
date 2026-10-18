## Recetas del horno de la reforja (unidad 5d): siguiendo el tutorial al pie de la letra, cada receta da su material bien
## hecho; y desviar cada parámetro fuera de su margen da el defecto que dice la receta.
extends "res://tests/case.gd"

const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")

## Los pasos de cada receta según lo que sale del horno (5m): de una bola o un cristal se saca el tocho, se desbasta, se vacía y
## se da la forma; lo sinterizado o crecido sobre su molde solo se repasa; lo colado va antes a la cera perdida y después se le
## corta el bebedero y se lima. Todas acaban en el pulido, la prueba del ajuste y el paso a la cetrería (petición 43: sin pegar).
const STEPS_BLOCK := ["pesar", "modo", "meter", "parametros", "vigilar", "enfriar", "comprobar_pieza", "tocho", "desbastar", "vaciar", "forma", "proteger", "recubrir", "pulir", "ajuste", "pasar"]
const STEPS_NEAR := ["pesar", "modo", "meter", "parametros", "vigilar", "enfriar", "comprobar_pieza", "repasar", "proteger", "recubrir", "pulir", "ajuste", "pasar"]
const STEPS_CAST := ["cera", "revestir", "quemar", "pesar", "modo", "meter", "parametros", "vigilar", "enfriar", "romper", "comprobar_pieza", "cortar_bebedero", "limar", "proteger", "recubrir", "pulir", "ajuste", "pasar"]


static func _step_ids(rid: String) -> Array:
	match String(ForgeData.RECIPES[rid].form):
		"colada":
			return STEPS_CAST
		"sinterizada", "capa":
			return STEPS_NEAR
	return STEPS_BLOCK


static func _forge(rid: String, animal := "rapaz", claw := "aguila") -> RefCounted:
	return ClawForge.new({ "animal": animal, "claw": claw, "recipe": rid })


## Carga la mezcla de la receta y enciende con los parámetros p.
static func _fire_with(f: RefCounted, p: Dictionary, grams: Variant = null) -> Dictionary:
	var rec: Dictionary = f.recommended()
	f.mix(grams if grams != null else rec.mix)
	return f.fire(p)


func test_cada_receta_tiene_su_tutorial_completo() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var steps := ForgeTutorial.steps(rid)
		var ids: Array = steps.map(func(s: Dictionary) -> String: return s.id)
		assert_eq(ids, _step_ids(rid), "%s: los pasos de la receta" % rid)
		for st: Dictionary in steps:
			assert_true(String(st.text).length() > 30, "%s/%s: texto" % [rid, st.id])
			assert_true(String(st.source).length() > 15, "%s/%s: fuente" % [rid, st.id])
			assert_true(String(st.check) == "" or ClawForge.CHECK_KEYS.has(String(st.check)), "%s/%s: condición conocida" % [rid, st.id])
			assert_true(String(st.mistake).length() > 15, "%s/%s: qué pasa si te equivocas" % [rid, st.id])
	var gen := ForgeTutorial.steps("horno")
	assert_eq(gen.size(), ForgeData.CONTROLS.size() + 4, "el general explica el horno, cada mando, las cargas, el reloj y la regla de oro")
	for sid: String in ["maquinas", "reloj"]:
		assert_true(gen.any(func(s: Dictionary) -> bool: return s.id == sid), "explica %s" % sid)
	for c: Dictionary in ForgeData.CONTROLS:
		assert_true(gen.any(func(s: Dictionary) -> bool: return s.id == "mando_" + String(c.id)), "explica el mando %s" % c.id)
	assert_eq(ForgeTutorial.steps("no_existe"), [])


func test_siguiendo_el_tutorial_sale_bien() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var f := _forge(rid)
		for st: Dictionary in f.tutorial():
			if String(st.action) != "":
				f.do_step(st)
		for st: Dictionary in f.tutorial():
			if String(st.check) != "":
				assert_true(st.done == true, "%s/%s: hecho" % [rid, st.id])
		var rep: Dictionary = f.report()
		assert_eq(rep.verdict, "bien", "%s: %s" % [rid, rep.verdictText])
		var rc: Dictionary = f.result_claw()
		assert_eq(rc.inlay, String(ForgeData.RECIPES[rid].product), "%s: el material de la receta" % rid)
		assert_true(rc.quality in ["primary", "secondary", "estimate"], "%s: es un proceso real" % rid)


func test_en_las_otras_garras_tambien_o_dice_por_que_no() -> void:
	for pair: Array in [["tigre", "tigre"], ["oso", "oso"], ["velociraptor", "velociraptor"], ["rapaz", "halcon"]]:
		for rid: String in ForgeData.RECIPE_IDS:
			var f := _forge(rid, pair[0], pair[1])
			for st: Dictionary in f.tutorial():
				if String(st.action) != "":
					f.do_step(st)
			var v: String = f.report().verdict
			var fd := String(f.snapshot().fire.defect)
			assert_true(v == "bien" or fd == "tamano", "%s %s: %s (%s)" % [pair[1], rid, v, f.snapshot().fire.text])
	# la garra del oso no cabe en un cristal HPHT (~12 mm)
	var b := _forge("diamante_hpht", "oso", "oso")
	b.mix(b.recommended().mix)
	assert_eq(b.fire(b.recommended().fire).defect, "tamano", "la funda del oso no cabe en un cristal HPHT")


func test_desviar_cada_parametro_da_su_defecto() -> void:
	var n := 0
	for rid: String in ForgeData.RECIPE_IDS:
		var r: Dictionary = ForgeData.RECIPES[rid]
		var base: Dictionary = _forge(rid).recommended().fire
		# temperatura corta y pasada
		var p := base.duplicate()
		p["temp_c"] = float(r.temp_c.min) - 10.0
		assert_eq(_fire_with(_forge(rid), p).defect, String(r.temp_c.low.code), "%s: frío" % rid)
		p = base.duplicate()
		p["temp_c"] = float(r.temp_c.max) + 10.0
		assert_eq(_fire_with(_forge(rid), p).defect, String(r.temp_c.high.code), "%s: caliente" % rid)
		# poco tiempo
		var f := _forge(rid)
		var probe := _fire_with(f, base)
		p = base.duplicate()
		p["time_s"] = maxf(float(probe.timeNeedS), float(r.time_s.min)) * 0.5
		assert_eq(_fire_with(_forge(rid), p).defect, String(r.time_s.low.code), "%s: poco tiempo" % rid)
		# otro modo
		for mode: String in ForgeData.FURNACE.modes:
			if mode != String(r.mode):
				p = base.duplicate()
				p["mode"] = mode
				assert_eq(_fire_with(_forge(rid), p).defect, "modo", "%s en modo %s" % [rid, mode])
		# atmósfera
		for atm: String in ["aire", "argon", "vacio", "h2_ch4"]:
			if not (r.atmosphere.ok as Array).has(atm):
				p = base.duplicate()
				p["atmosphere"] = atm
				var want: String = (r.atmosphere.bad as Dictionary).get(atm, { "code": "atmosfera" }).code
				assert_eq(_fire_with(_forge(rid), p).defect, want, "%s en %s" % [rid, atm])
				n += 1
		# presión
		var pd: Dictionary = r.pressure_mpa
		if pd.has("low"):
			p = base.duplicate()
			p["pressure_mpa"] = 4000.0
			assert_eq(_fire_with(_forge(rid), p).defect, String(pd.low.code), "%s: poca presión" % rid)
		if pd.has("high"):
			p = base.duplicate()
			p["pressure_mpa"] = float(pd.max) + 1.0
			assert_eq(_fire_with(_forge(rid), p).defect, String(pd.high.code), "%s: presión de más" % rid)
		# molde
		if r.has("mold"):
			for mold: String in r.mold.bad:
				p = base.duplicate()
				p["mold"] = mold
				assert_eq(_fire_with(_forge(rid), p).defect, String(r.mold.bad[mold].code), "%s en molde de %s" % [rid, mold])
		# metano de la CVD
		if r.has("methane"):
			for pair: Array in [[float(r.methane.min) * 0.5, String(r.methane.low.code)], [float(r.methane.max) * 1.5, String(r.methane.high.code)]]:
				p = base.duplicate()
				p["methane"] = pair[0]
				assert_eq(_fire_with(_forge(rid), p).defect, pair[1], "%s: metano %s" % [rid, pair[0]])
		# mezcla: cada polvo con su defecto, fuera por abajo y por arriba
		for pw: Dictionary in r.powders:
			for side: String in ["low", "high"]:
				if not pw.has(side):
					continue
				var grams: Dictionary = _forge(rid).recommended().mix.duplicate()
				var others := 0.0
				for k: String in grams:
					if k != pw.id:
						others += float(grams[k])
				var target := (float(pw.min) * 0.5) if side == "low" else minf(float(pw.max) * 1.5 + 0.01, 0.999)
				grams[pw.id] = target * others / (1.0 - target) if others > 0.0 else 0.0
				if others <= 0.0 and side == "low":
					grams[pw.id] = 0.0
					grams["cr2o3"] = 1.0
				assert_eq(_fire_with(_forge(rid), base, grams).defect, String(pw[side].code), "%s: %s por %s" % [rid, pw.id, side])
				n += 1
		# un polvo que no va en la receta
		var dirty: Dictionary = _forge(rid).recommended().mix.duplicate()
		dirty["grafito" if rid != "diamante_hpht" else "mgo"] = 5.0
		assert_eq(_fire_with(_forge(rid), base, dirty).defect, "mezcla", "%s: contaminada" % rid)
	assert_true(n > 20, "desviaciones de atmósfera y mezcla: %d" % n)


func test_lo_que_sale_mal_se_explica() -> void:
	# cada defecto lleva su texto con la razón física
	var f := _forge("metal_duro")
	var p: Dictionary = f.recommended().fire.duplicate()
	p["atmosphere"] = "aire"
	var r := _fire_with(f, p)
	assert_eq(r.defect, "atmosfera")
	assert_true(String(r.text).contains("oxida"), "el carburo al aire se oxida: %s" % r.text)
	assert_eq(f.report().verdict, "quemada")
	var g := _forge("oro")
	var q: Dictionary = g.recommended().fire.duplicate()
	q["temp_c"] = 1000.0
	assert_true(String(_fire_with(g, q).text).contains("1064"), "el oro no llega a fundir")
	assert_eq(g.report().verdict, "no_funde")


func test_la_piedra_comprada_se_talla_y_se_pega() -> void:
	var f := _forge("")
	var steps: Array = f.tutorial("piedra")
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.id), ["elegir", "no_calentar", "tocho", "desbastar", "vaciar", "forma", "proteger", "recubrir", "pulir", "ajuste", "pasar"])
	for st: Dictionary in steps:
		if String(st.action) != "":
			f.do_step(st)
	assert_eq(f.report().verdict, "bien", f.report().verdictText)
	assert_eq(f.result_claw().inlay, ForgeTutorial.STONE_DEFAULT)
	for st: Dictionary in f.tutorial("piedra"):
		if String(st.check) != "":
			assert_true(st.done == true, "piedra/%s: hecho" % st.id)


func test_los_veredictos_dicen_que_salio_mal() -> void:
	var b := _forge("diamante_hpht", "oso", "oso")
	b.mix(b.recommended().mix)
	b.fire(b.recommended().fire)
	assert_eq(b.report().verdict, "no_cabe", "la funda del oso no cabe en un cristal HPHT")
	var a := _forge("alumina")
	var p: Dictionary = a.recommended().fire.duplicate()
	p["temp_c"] = 1600.0
	a.mix(a.recommended().mix)
	a.fire(p)
	assert_eq(a.report().verdict, "defectuosa", "la alúmina fría queda porosa")
	assert_eq(a.report().finish, "poroso")
	var g := _forge("diamante_cvd")
	var q: Dictionary = g.recommended().fire.duplicate()
	q["atmosphere"] = "aire"
	g.mix(g.recommended().mix)
	g.fire(q)
	assert_eq(g.report().verdict, "quemada", "el diamante CVD al aire se quema")
	# la ficción no se repite en la lista aunque se recubra dos veces
	var f := _forge("zafiro")
	f.coat({ "method": "ald_alumina", "target": "garra_viva", "time_s": 60.0 })
	f.coat({ "method": "ald_alumina", "target": "garra_viva", "time_s": 60.0 })
	var fic: Array = f.report().fiction
	for i in fic.size():
		assert_eq(fic.count(fic[i]), 1, "sin repetir: %s" % fic[i])
