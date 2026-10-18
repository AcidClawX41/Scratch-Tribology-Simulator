## Cetrería · el limado según la dureza y la abrasión de cada material y herramienta (unidad 5l, petición 38;
## docs/fisica/cetreria.md §11.12): lo que se gasta cada herramienta (Archard con la razón de durezas al revés, Pintaude 2009),
## lo que calienta una giratoria que roza sin morder, la fuerza de los cortaúñas, el arranque de los frágiles por encima de la
## hondura crítica, la rugosidad de una pasada que no muerde, lo que sale de cada pasada y las chispas de cada metal.
## Invariantes antes que números: una herramienta más dura nunca quita menos; con la misma herramienta, lo más duro nunca se
## lima más deprisa; lo que no muerde no arranca, pero calienta si gira; una gastada nunca quita más que una nueva; un
## cortaúñas nunca corta lo que pide más fuerza de la que da.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Kit = preload("res://core/lab/claw_care_kit.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const Sparks = preload("res://core/taller/sparks.gd")

const FRAME := 1.0 / 60.0
const FILING := ["lima_bastarda", "lima_entrefina", "lima_fina", "lima_diamante_gruesa", "lima_diamante_fina", "lija_p180", "lija_p240", "torno", "amoladora"]
const CLIPPERS := ["guillotina", "tijera", "tenaza"]
## Lo que es más blando que ~0,38 veces la herramienta no la gasta (CareData.TOOL_WEAR.onset)
const SOFT := ["none", "oro", "acero", "titanio"]


static func _fx(x: float, d := 3) -> String:
	return Js.to_fixed(x, d)


## Los materiales de la garra: la queratina y los del catálogo (los de la 1.x y los nuevos de la 2.0).
static func _materials() -> Array:
	var out := ["none"]
	for e: Dictionary in Catalog.INLAYS:
		if String(e.id) != "none":
			out.append(String(e.id))
	return out


static func _care(mat: String, kit: Variant = null) -> ClawCare:
	var s := { "animal": "rapaz", "claw": "aguila", "overgrowth_days": 60.0, "sedation": "sedacion", "seed": "limado" }
	if mat != "none":
		s["inlay"] = mat
	return ClawCare.new(s, null, kit)


## Una pasada de frente a la punta: 30 mm a mano a 3 N, o 1 s con la giratoria.
static func _pass(c: ClawCare, tid: String, force := 3.0) -> Dictionary:
	var p := { "tool": tid, "force_n": force, "zone": "punta", "angle_deg": 90.0 }
	if String(CareData.tool(tid).kind) == "torno":
		p["dwell_s"] = 1.0
	else:
		p["travel_mm"] = 30.0
	return c.file(p)


static func _hv(mat: String) -> float:
	if mat == "none":
		return float(CareData.claw_entry("aguila").hv)
	return float(Catalog.find_by_id(Catalog.INLAYS, mat).hv)


# ════════ El desgaste de la herramienta ════════

## K(ρ): 0 por debajo de onset, el suave medido en ρ = 0,8 y el severo desde ρ = 2; nunca baja al subir ρ.
func test_el_coeficiente_de_desgaste_sube_con_la_dureza_relativa() -> void:
	var on := ClawCare.wear_onset_ratio()
	assert_near(on, 1.6 / 2.8 / 1.5, 1e-12, 0.0, "onset: la cesión de Johnson con H = 2,8·Y y el pico de Hertz")
	assert_eq(ClawCare.tool_wear_k(on * 0.99), 0.0, "por debajo de onset, nada")
	assert_eq(ClawCare.tool_wear_k(0.05), 0.0, "la queratina contra una lima de acero, nada")
	assert_near(ClawCare.tool_wear_k(0.8), float(CareData.TOOL_WEAR.k_mild.value), 1e-12, 0.0, "en ρ = 0,8, el suave de Pintaude")
	assert_near(ClawCare.tool_wear_k(2.0), float(CareData.TOOL_WEAR.k_severe.value), 1e-12, 0.0, "desde ρ = 2, el severo")
	assert_near(ClawCare.tool_wear_k(14.0), float(CareData.TOOL_WEAR.k_severe.value), 1e-12, 0.0, "y no pasa de ahí")
	var prev := -1.0
	for i in 501:
		var rho := float(i) * 0.01
		var k := ClawCare.tool_wear_k(rho)
		assert_true(k >= prev, "ρ = %s: el desgaste no baja (%s ≥ %s)" % [_fx(rho, 2), k, prev])
		prev = k
	assert_true(float(CareData.TOOL_WEAR.k_severe.value) / float(CareData.TOOL_WEAR.k_mild.value) > 300.0, "el severo, unas 330 veces el suave")
	for e: Dictionary in [CareData.TOOL_WEAR.k_mild, CareData.TOOL_WEAR.k_severe, CareData.TOOL_WEAR.onset, CareData.TOOL_WEAR.dull_ratio]:
		assert_true(String(e.source).length() > 40 and String(e.quality) in ["primary", "secondary", "estimate"], "cada dato con su fuente")


## Lo blando no gasta la herramienta: la queratina, el oro, el acero y el titanio, con cualquier herramienta de limar.
func test_lo_blando_no_gasta_la_herramienta() -> void:
	for mat: String in SOFT:
		for tid: String in FILING:
			var c := _care(mat)
			for k in 10:
				var r := _pass(c, tid)
				assert_eq(float(r.toolWearMm3), 0.0, "%s con %s: la herramienta no se gasta" % [mat, tid])
			assert_eq(String(c.tools()[tid].state), "nueva", "%s con %s: sigue nueva" % [mat, tid])


## La lima de acero contra el vidrio: el régimen suave que midió Pintaude con vidrio sobre un acero de 706 HV; en un ensayo no se
## embota. Contra lo más duro que ella, sí: se embota y se avisa una vez.
func test_la_lima_de_acero_se_embota_contra_lo_mas_duro() -> void:
	var g := _care("vidrio")
	for k in 60:
		_pass(g, "lima_fina")
	var tg: Dictionary = g.tools().lima_fina
	assert_true(float(tg.wornMm3) > 0.0, "contra el vidrio se gasta algo (%s mm³)" % tg.wornMm3)
	assert_eq(String(tg.state), "nueva", "pero no se embota: el régimen suave (%s µm)" % _fx(float(tg.edgeUm), 2))
	var z := _care("zafiro")
	var k := 0
	while k < 400 and String(z.tools().lima_fina.state) != "gastada":
		var r := _pass(z, "lima_fina")
		assert_true(bool(r.noBite) and bool(r.rubbing), "(resbala sobre el zafiro)")
		k += 1
	var tz: Dictionary = z.tools().lima_fina
	assert_eq(String(tz.state), "gastada", "contra el zafiro se embota (%d pasadas)" % k)
	assert_eq(String(tz.word), "embotada", "y se dice embotada")
	assert_true(k > 20, "pero no de golpe (%d pasadas)" % k)
	print("    (info) la lima fina contra el vidrio, 60 pasadas: filos de %s µm (nueva); contra el zafiro, embotada en %d pasadas de 30 mm a 3 N" % [_fx(float(tg.edgeUm), 2), k])
	var warned := z.events().filter(func(e: Dictionary) -> bool: return e.code == "herramienta_gastada")
	assert_eq(warned.size(), 1, "se avisa una vez")
	assert_true(String(warned[0].message).contains("embotado"), "embotada: %s" % warned[0].message)


## El corindón se gasta y se vidria contra lo que es tan duro como él (el zafiro) o más (la moissanita, el diamante); el
## diamante casi no se gasta (solo contra el diamante).
func test_el_corindon_se_vidria_y_el_diamante_casi_no_se_gasta() -> void:
	for mat: String in ["zafiro", "rubi", "tungsteno", "moissanita", "diamante"]:
		var c := _care(mat)
		for k in 5:
			_pass(c, "torno")
		var t: Dictionary = c.tools().torno
		assert_eq(String(t.state), "gastada", "%s: el tambor de corindón se vidria en 5 s (%s µm)" % [mat, _fx(float(t.edgeUm), 1)])
		assert_eq(String(t.word), "vidriada", "%s: vidriada" % mat)
	for mat: String in ["vidrio", "cuarzo", "zafiro", "moissanita"]:
		var d := _care(mat)
		for k in 100:
			_pass(d, "lima_diamante_gruesa")
		assert_eq(float(d.tools().lima_diamante_gruesa.wornMm3), 0.0, "%s: el diamante no se gasta" % mat)
	var dd := _care("diamante")
	for k in 100:
		_pass(dd, "lima_diamante_gruesa")
	assert_true(float(dd.tools().lima_diamante_gruesa.wornMm3) > 0.0, "contra el diamante, sí")


## Una herramienta gastada nunca quita más que una nueva (con la misma garra y la misma pasada), y una nueva de la bandeja quita
## lo mismo que la primera vez.
func test_una_herramienta_gastada_nunca_quita_mas_que_una_nueva() -> void:
	for tid: String in FILING:
		var t := CareData.tool(tid)
		for mat: String in _materials():
			var fresh := _pass(_care(mat), tid)
			var kit := Kit.new()
			# gastada a propósito: lo que perdería rozando un rato contra algo más duro
			kit.add(t, 0.05 if String(t.kind) == "torno" else 0.005, 1.0, 100.0)
			var worn := _pass(_care(mat, kit), tid)
			assert_true(float(worn.toolEdgeUm) > float(fresh.toolEdgeUm), "%s: los filos gastados son más redondos" % tid)
			assert_true(float(worn.removedMm3) <= float(fresh.removedMm3) * (1.0 + 1e-9) + 1e-15,
				"%s en %s: gastada (%s) nunca quita más que nueva (%s)" % [tid, mat, worn.removedMm3, fresh.removedMm3])
			kit.renew(tid)
			var again := _pass(_care(mat, kit), tid)
			assert_eq(float(again.removedMm3), float(fresh.removedMm3), "%s en %s: una nueva vuelve a quitar lo mismo" % [tid, mat])


## Con los filos más redondos, el tambor que se vidría contra el zafiro arranca menos a cada segundo.
func test_el_tambor_vidriado_arranca_cada_vez_menos() -> void:
	var c := _care("zafiro")
	var prev := INF
	for k in 6:
		var r := _pass(c, "torno")
		assert_true(float(r.removedMm3) <= prev, "segundo %d: %s ≤ %s mm³" % [k + 1, r.removedMm3, prev])
		prev = float(r.removedMm3)
	var first := float(_pass(_care("zafiro"), "torno").removedMm3)
	assert_true(prev < 0.5 * first, "al sexto segundo, menos de la mitad (%s frente a %s)" % [prev, first])
	print("    (info) el tambor contra el zafiro: %s mm³ el primer segundo, %s el sexto (filos de %s µm)" % [_fx(first, 5), _fx(prev, 5), _fx(float(c.tools().torno.edgeUm), 0)])
	assert_true(c.renew_tool("torno"), "una nueva de la bandeja")
	assert_true(c.events().any(func(e: Dictionary) -> bool: return e.code == "herramienta_nueva"), "se apunta")
	assert_eq(String(c.tools().torno.state), "nueva", "vuelve a estar nueva")
	assert_false(c.renew_tool("guillotina"), "un cortaúñas no se cambia por gastado")


## El kit es del ensayo: lo que se gasta en una garra cuenta en las demás del animal; history lo repite con un kit compartido.
func test_el_kit_es_del_ensayo_y_history_lo_repite() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "inlay": "zafiro", "seed": "kit" })
	st.set_sedation("sujecion")
	st.pick("torno")
	st.set_rotary(true)
	st.press_on(st.care.apex_mm() - 0.3)
	for i in 120:
		st.drag(0.0, 0.0, st.care.apex_mm() - 0.3, FRAME)
		st.tick(FRAME)
	st.release()
	var worn: Dictionary = st.view().tools.torno
	assert_true(String(worn.state) != "nueva", "el tambor se ha gastado contra el zafiro (%s)" % worn.state)
	assert_eq(String(st.view().hand.wear.state), String(worn.state), "la mano dice cómo va la herramienta")
	assert_eq(String(st.tray_view()[2].state), String(worn.state), "y la bandeja")
	st.select_claw("derecha", "II")
	assert_eq(var_to_str(st.view().tools.torno), var_to_str(worn), "la otra garra usa el mismo tambor")
	st.renew_tool()
	assert_eq(String(st.view().tools.torno.state), "nueva", "una nueva (tecla N)")
	assert_true(String(st.view().notice).contains("nueva"), "con su aviso")
	st.press_on(st.care.apex_mm() - 0.3)
	for i in 30:
		st.drag(0.0, 0.0, st.care.apex_mm() - 0.3, FRAME)
		st.tick(FRAME)
	st.release()
	# la repetición: un animal y un kit compartidos por todas las garras
	var p0 := Patient.new(String(st.setup.animal), String(st.setup.sedation))
	var k0 := Kit.new()
	var cares := {}
	for e: Array in st.history:
		var key := String(e[0])
		if not cares.has(key):
			var parts := key.split("|")
			cares[key] = ClawCare.new(st.care_setup(parts[0], parts[1]), p0, k0)
		var c: ClawCare = cares[key]
		match String(e[1]):
			"file":
				c.file(e[2])
			"advance":
				c.advance(float(e[2]))
			"set_sedation":
				c.set_sedation(String(e[2]))
			"renew_tool":
				c.renew_tool(String(e[2]))
	for key: String in cares:
		var mine: ClawCare = st.care if key == State.slot_key(st.paw, st.digit) else st._slots[key].care
		var a: Dictionary = (cares[key] as ClawCare).snapshot()
		var b: Dictionary = mine.snapshot()
		a.erase("serial")
		b.erase("serial")
		assert_eq(var_to_str(a), var_to_str(b), "%s: la misma garra" % key)
	assert_eq(var_to_str(k0.view()), var_to_str(st.kit.view()), "y las mismas herramientas")


# ════════ Qué muerde y cuánto quita ════════

## Una herramienta más dura nunca quita menos (la misma geometría, solo cambia su dureza), en régimen dúctil y en frágil.
func test_una_herramienta_mas_dura_nunca_quita_menos() -> void:
	for tid: String in ["lima_fina", "lija_p180", "torno"]:
		var base := CareData.tool(tid)
		for mat: String in _materials():
			var hv := _hv(mat)
			var h := hv * Contact.HV_MPA
			for brittle: bool in [false, true]:
				var prev := -1.0
				for thv: float in [300.0, 700.0, 1000.0, 1500.0, 2000.0, 3000.0, 6000.0, 10000.0]:
					var t := base.duplicate()
					t["tool_hv"] = thv
					var v := ClawCare.removal_mm3(t, 3.0, 30.0, 0.8, 0.8, hv, h, brittle)
					assert_true(v >= prev, "%s de %s HV en %s: %s ≥ %s" % [tid, thv, mat, v, prev])
					prev = v


## Con la misma herramienta y la misma garra, un material más duro nunca se lima más deprisa.
func test_con_la_misma_herramienta_lo_mas_duro_nunca_se_lima_mas_deprisa() -> void:
	var mats := _materials()
	for tid: String in FILING:
		var rem := {}
		for mat: String in mats:
			rem[mat] = float(_pass(_care(mat), tid).removedMm3)
		for a: String in mats:
			for b: String in mats:
				if _hv(b) > _hv(a):
					assert_true(float(rem[b]) <= float(rem[a]) * (1.0 + 1e-9) + 1e-15,
						"%s: %s (%s HV) no se lima más que %s (%s HV): %s ≤ %s" % [tid, b, _hv(b), a, _hv(a), rem[b], rem[a]])


## Lo que no muerde no arranca, pero calienta si gira: con el rozamiento de la pareja (P = ε·μ·F·v), y a mano no.
func test_lo_que_no_muerde_no_arranca_pero_calienta_si_gira() -> void:
	for mat: String in ["moissanita", "diamante"]:
		for tid: String in ["torno", "amoladora"]:
			var c := _care(mat)
			var r := _pass(c, tid)
			var t := CareData.tool(tid)
			var v := ClawCare.surface_speed_ms(float(t.drum_mm), float(t.rpm))
			assert_eq(float(r.removedMm3), 0.0, "%s con %s: no arranca" % [mat, tid])
			assert_true(bool(r.noBite) and bool(r.rubbing), "%s con %s: roza sin morder" % [mat, tid])
			var mu := ClawCare.rub_mu(t, _hv(mat))
			assert_near(float(r.heatW), ClawCare.heat_power_w(3.0, v, -1.0, mu), 1e-12, 0.0, "%s con %s: calienta con μ = %s" % [mat, tid, mu])
			assert_true(float(r.heatW) > 0.0, "%s con %s: %s W" % [mat, tid, _fx(float(r.heatW), 2)])
			assert_true(c.events().any(func(e: Dictionary) -> bool: return e.code == "roce"), "%s con %s: se avisa del roce" % [mat, tid])
			assert_true(String(c.sfx_for("file", r)) == "slide", "y suena a resbalar")
		var h := _pass(_care(mat), "lima_fina")
		assert_true(bool(h.noBite) and float(h.heatW) == 0.0, "%s: la lima a mano resbala sin calor" % mat)
	assert_near(ClawCare.rub_mu(CareData.tool("torno"), 10000.0), 0.1, 1e-12, 0.0, "con el diamante, 0,1")
	assert_near(ClawCare.rub_mu(CareData.tool("torno"), 2800.0), 0.2, 1e-12, 0.0, "corindón sobre moissanita, 0,2")
	assert_near(ClawCare.rub_mu(CareData.tool("lima_fina"), 2000.0), 0.5, 1e-12, 0.0, "la lima de acero sobre el zafiro, 0,5")
	# sobre un bloque de diamante en el muñón (el modelo térmico del bloque, unidad 5j), la cara se calienta sin quitar nada
	var b := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "sedation": "sedacion", "block": { "material": "diamante", "stump_mm": 12.0 } })
	var rb := b.file({ "tool": "torno", "zone": "punta", "angle_deg": 90.0, "force_n": 3.0, "dwell_s": 2.0, "rpm": 13000.0 })
	assert_eq(float(rb.removedMm3), 0.0, "el bloque de diamante: nada")
	assert_true(float(b.snapshot().thermal.faceC) > float(CareData.THERMAL.bed_c.value) + 0.1, "pero la cara se calienta (%s °C)" % _fx(float(b.snapshot().thermal.faceC), 2))


## Mientras muerde la queratina, el calor es el de siempre (el rozamiento del amolado): la 5l no cambia la garra viva.
func test_en_la_queratina_el_calor_es_el_de_siempre() -> void:
	for tid: String in ["torno", "amoladora"]:
		var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
		var r := c.file({ "tool": tid, "zone": "punta", "angle_deg": 45.0, "force_n": 2.0, "dwell_s": 0.5 })
		var t := CareData.tool(tid)
		var v := ClawCare.surface_speed_ms(float(t.drum_mm), float(t.rpm))
		assert_eq(float(r.heatW), ClawCare.heat_power_w(2.0, v), "%s: P = ε·μ·F·v con el μ del amolado" % tid)
		assert_eq(float(r.mu), float(CareData.THERMAL.friction.value), "%s: μ = %s" % [tid, CareData.THERMAL.friction.value])


## Entre morder y no morder, el μ del calor va del amolado al de la pareja según lo que muerde (η), sin saltos.
func test_el_rozamiento_del_calor_va_de_cortar_a_rozar() -> void:
	var t := CareData.tool("torno")
	var prev := INF
	for hv: float in [30.0, 500.0, 1000.0, 1300.0, 1600.0, 2000.0, 2400.0, 2800.0, 10000.0]:
		var mu := ClawCare.friction_mu(t, hv)
		var eta := Contact.hardness_efficiency(float(t.tool_hv) / hv)
		assert_near(mu, eta * float(CareData.THERMAL.friction.value) + (1.0 - eta) * ClawCare.rub_mu(t, hv), 1e-12, 0.0, "%s HV" % hv)
		assert_true(mu <= prev + 1e-12, "%s HV: el μ no sube al morder menos (%s ≤ %s)" % [hv, mu, prev])
		prev = mu


# ════════ Los cortaúñas: la fuerza ════════

## Un cortaúñas nunca corta lo que pide más fuerza de la que da (la mano por su palanca), y si no corta por eso, lo dice.
func test_un_cortaunas_nunca_corta_lo_que_pide_mas_fuerza_de_la_que_da() -> void:
	var cuts := 0
	var refused := 0
	for mat: String in _materials():
		for tid: String in CLIPPERS:
			for rm: float in [0.5, 1.0, 2.0, 4.0, 6.0, 9.0]:
				for hum: String in (["seca", "natural", "humeda"] if mat == "none" else ["natural"]):
					var c := _care(mat)
					c.set_humidity(hum)
					var r := c.clip({ "tool": tid, "remove_mm": rm })
					if bool(r.cut):
						cuts += 1
						assert_true(float(r.forceN) <= float(r.capacityN), "%s/%s/%s mm: cortó con %s ≤ %s N" % [mat, tid, rm, r.forceN, r.capacityN])
					elif float(r.forceN) > float(r.capacityN):
						refused += 1
						assert_true(String(r.reason).contains("pide"), "%s/%s/%s mm: dice por qué (%s)" % [mat, tid, rm, r.reason])
						assert_true(c.events().any(func(e: Dictionary) -> bool: return e.code == "no_corta_fuerza"), "%s/%s/%s mm: y lo avisa" % [mat, tid, rm])
	assert_true(cuts > 0 and refused > 0, "corta unas (%d) y otras no (%d)" % [cuts, refused])
	print("    (info) cortaúñas: %d cortes y %d sin fuerza bastante" % [cuts, refused])


## El acero macizo solo se corta cerca de la punta (donde es fino); el oro, mucho más atrás. La fuerza crece con la sección.
func test_el_acero_macizo_solo_se_corta_en_la_punta() -> void:
	assert_true(bool(_care("acero").clip({ "tool": "guillotina", "remove_mm": 1.0 }).cut), "1 mm de acero, sí")
	var deep := _care("acero").clip({ "tool": "guillotina", "remove_mm": 8.0 })
	assert_false(bool(deep.cut), "8 mm de acero, no: %s" % deep.reason)
	assert_true(float(deep.forceN) > 1000.0, "pide kilonewtons (%s N)" % _fx(float(deep.forceN), 0))
	assert_true(bool(_care("oro").clip({ "tool": "guillotina", "remove_mm": 8.0 }).cut), "el oro, blando, sí")
	assert_false(bool(_care("titanio").clip({ "tool": "guillotina", "remove_mm": 9.0 }).cut), "el titanio, a 9 mm, no")
	# la fuerza que pide crece con la sección y con la dureza del metal
	for hum: String in CareData.HUMIDITY_IDS:
		var prev := -1.0
		for r: float in [0.1, 0.3, 0.6, 1.0, 2.0, 4.0]:
			var f := ClawCare.clip_force_n({ "reforged": false }, hum, r)
			assert_true(f > prev, "queratina %s, r = %s mm: %s N" % [hum, r, _fx(f, 1)])
			prev = f
	var m := func(id: String) -> Dictionary:
		var e: Dictionary = Catalog.find_by_id(Catalog.INLAYS, id)
		return { "reforged": true, "hv": float(e.hv), "e": float(e.E), "inlay": e }
	assert_true(ClawCare.clip_force_n(m.call("oro"), "natural", 1.0) < ClawCare.clip_force_n(m.call("titanio"), "natural", 1.0), "el oro pide menos que el titanio")
	assert_true(ClawCare.clip_force_n(m.call("titanio"), "natural", 1.0) < ClawCare.clip_force_n(m.call("acero"), "natural", 1.0), "y el titanio, menos que el acero")
	# remojada, la queratina pide menos: así se cortan las garras grandes
	assert_true(ClawCare.clip_force_n({ "reforged": false }, "humeda", 2.0) < ClawCare.clip_force_n({ "reforged": false }, "natural", 2.0), "remojada, menos fuerza")
	assert_near(ClawCare.clip_capacity_n(CareData.tool("tenaza")), float(CareData.CLIP_FORCE.hand_n.value) * 10.0, 1e-9, 0.0, "las tenazas: la mano por 10")


# ════════ Los frágiles por encima de la hondura crítica ════════

## En régimen frágil el surco se arranca entero: nunca menos que cortando; el grano gastado, con su punta redonda, menos.
func test_los_fragiles_se_arrancan_enteros_por_encima_de_la_hondura_critica() -> void:
	var r := _pass(_care("vidrio"), "lima_diamante_gruesa")
	assert_eq(String(r.regime), "frágil", "el vidrio con la lima de diamante: régimen frágil")
	assert_eq(String(_pass(_care("acero"), "lima_diamante_gruesa").regime), "dúctil", "el acero, dúctil")
	assert_eq(String(_pass(_care("none"), "lima_diamante_gruesa").regime), "dúctil", "la queratina, dúctil")
	for tid: String in ["lima_fina", "lija_p180", "lima_diamante_fina", "torno"]:
		var t := CareData.tool(tid)
		for mat: String in ["vidrio", "cuarzo", "zafiro", "circonita", "alumina"]:
			var hv := _hv(mat)
			for f: float in [0.5, 3.0, 9.0]:
				var duct := ClawCare.removal_mm3(t, f, 30.0, 0.8, 0.8, hv, hv * Contact.HV_MPA, false)
				var frag := ClawCare.removal_mm3(t, f, 30.0, 0.8, 0.8, hv, hv * Contact.HV_MPA, true)
				assert_true(frag >= duct, "%s en %s a %s N: frágil (%s) ≥ dúctil (%s)" % [tid, mat, f, frag, duct])
	# la sección del surco del grano: entera con la punta afilada, menos con la gastada
	var tip := Contact.tip_geometry(PI * 0.005 * 0.005, 60.0)
	var a := 0.013
	var h := Contact.depth_for_radius(tip, a)
	assert_true(ClawCare.groove_area_ratio(tip, a, h) > 0.95, "afilado: casi el cono entero")
	var prev := INF
	for r_um: float in [5.0, 10.0, 20.0, 40.0, 80.0]:
		var g := Contact.tip_geometry(PI * r_um * r_um * 1e-6, 60.0)
		var q := ClawCare.groove_area_ratio(g, a, Contact.depth_for_radius(g, a))
		assert_true(q <= prev, "punta de %s µm: %s" % [r_um, _fx(q, 3)])
		prev = q
	assert_true(prev < 0.5, "con 80 µm de radio, menos de la mitad (%s)" % _fx(prev, 3))


# ════════ La superficie, lo que sale y las chispas ════════

## Una pasada que no quita nada deja la superficie como estaba, y su rugosidad es la de antes.
func test_el_ra_de_una_pasada_que_no_muerde_es_el_de_antes() -> void:
	var z := _care("zafiro")
	var before := float(z.snapshot().surface.ra_um[0])
	var r := _pass(z, "lima_bastarda")
	assert_true(bool(r.noBite), "(no muerde)")
	assert_eq(float(r.raUm), before, "la de antes: %s µm, la del zafiro pulido" % before)
	# la que muerde deja la suya: la hondura del surco de cada filo entre cuatro (la misma que da lo que sale)
	var k := _pass(_care("none"), "lima_bastarda")
	assert_true(float(k.removedMm3) > 0.0, "(la queratina, sí)")
	assert_near(float(k.raUm), ClawCare.pass_ra_um(float(k.debris.sizeUm)), 1e-12, 0.0, "la de la lima: Ra = h/4")
	assert_true(float(k.raUm) > float(CareData.SURFACE.natural_ra_um.value), "y raya más que la natural")


## Lo poco que arranca la lima de diamante del zafiro (~0,0006 mm³ en una pasada) se lee con dos cifras significativas:
## «0.000» parecería que no muerde.
func test_lo_poco_que_se_arranca_se_lee() -> void:
	assert_eq(State.fmt_mm3(0.0), "0.000", "nada: cero")
	assert_eq(State.fmt_mm3(0.287), "0.287", "lo de siempre, con tres decimales")
	assert_eq(State.fmt_mm3(0.00057), "0.00057", "lo poco, con dos cifras")
	assert_eq(State.fmt_mm3(0.000012), "0.000012", "y aún menos")
	assert_eq(State.fmt_vol(0.287), "0.287 mm³", "con su unidad: lo de siempre, en mm³")
	assert_eq(State.fmt_vol(0.00057), "0.00057 mm³", "lo poco, en mm³ con dos cifras")
	assert_eq(State.fmt_vol(0.0000083), "8300 µm³", "y por debajo de una diezmilésima, en µm³ enteros (la lima fina en el zafiro)")
	assert_eq(State.fmt_vol(0.0), "0.000 mm³", "nada: cero, en mm³")
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "inlay": "zafiro", "seed": "texto" })
	st.set_sedation("sujecion")
	st.pick("lima_diamante_gruesa")
	st.set_force(6.0)
	st.set_angle(90.0)
	var s := st.care.apex_mm() - 0.5
	st.press_on(s)
	st.drag(10.0, 10.0, s, 0.1)
	st.release()
	var t := st.action_text()
	assert_true(t.contains("mm³ fuera") and not t.contains(" 0.000 mm³"), "muerde y se lee: «%s»" % t)


## Lo que sale de cada pasada: polvo de queratina del color de su garra, limaduras de los metales, polvo de los frágiles,
## virutas del acrílico; las chispas, solo de los metales que las dan.
func test_lo_que_sale_de_cada_pasada() -> void:
	var col := String(CareData.claw_entry("aguila").get("col", ""))
	var kd: Dictionary = _pass(_care("none"), "lima_fina").debris
	assert_eq(String(kd.kind), "polvo", "la queratina: polvo")
	assert_eq(String(kd.color), col, "del color de su garra")
	assert_true(float(kd.mm3) > 0.0 and float(kd.sizeUm) > 0.0, "con su volumen y su tamaño")
	for mat: String in ["oro", "acero", "titanio"]:
		var d: Dictionary = _pass(_care(mat), "lima_bastarda").debris
		assert_eq(String(d.kind), "limaduras", "%s: limaduras" % mat)
		assert_eq(String(d.color), String(CareData.DEBRIS_COLOR[mat][0]), "%s: su color" % mat)
	for mat: String in ["vidrio", "cuarzo", "zafiro", "rubi", "alumina", "hematites", "moissanita", "diamante", "tungsteno"]:
		var d: Dictionary = _pass(_care(mat), "lima_diamante_gruesa").debris
		assert_eq(String(d.kind), "polvo", "%s: polvo" % mat)
		assert_eq(String(d.color), String(CareData.DEBRIS_COLOR[mat][0]), "%s: su color" % mat)
		assert_eq(String(d.colorQuality), "dibujo", "%s: el color es dibujo" % mat)
	assert_true(String(CareData.DEBRIS_COLOR.hematites[1]).contains("Handbook of Mineralogy"), "la hematites, con su raya")
	var b := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "sedation": "sedacion", "block": { "material": "acrilico", "stump_mm": 12.0 } })
	assert_eq(String(_pass(b, "lima_fina").debris.kind), "virutas", "el acrílico: virutas")
	# las chispas: el acero, el titanio y el metal duro; el oro, no; los no metales, no
	var want := { "acero": "acero", "titanio": "titanio-cp", "tungsteno": "metal-duro", "oro": "oro", "vidrio": "", "zafiro": "", "none": "" }
	for mat: String in want:
		assert_eq(String(_pass(_care(mat), "lima_diamante_gruesa").debris.sparks), String(want[mat]), "%s: chispas «%s»" % [mat, want[mat]])
	# sin morder no sale nada
	var nb := _pass(_care("zafiro"), "lima_fina")
	assert_eq(float(nb.debris.mm3), 0.0, "sin morder, nada")
	# cómo cae (Stokes): v = ρ·g·d²/(18·μ) con el grueso de la viruta; el polvo de zafiro, de micras, flota más que el de queratina
	var zd: Dictionary = _pass(_care("zafiro"), "lima_diamante_gruesa").debris
	var d_m := float(zd.sizeUm) * 1.0e-6
	assert_near(float(zd.settleMs), float(zd.density) * 9.81 * d_m * d_m / (18.0 * float(CareData.AIR_VISCOSITY.value)), 1e-9, 1e-12, "Stokes")
	assert_eq(float(zd.density), float(CareData.ClawMass.DENSITY.zafiro.value), "con la densidad del corindón")
	assert_true(float(zd.settleMs) < float(kd.settleMs), "el polvo de zafiro (%s mm/s) cae más despacio que el de queratina (%s mm/s)" % [
		_fx(float(zd.settleMs) * 1000.0, 2), _fx(float(kd.settleMs) * 1000.0, 1)])
	assert_true(String(zd.settleSource).contains("Stokes"), "con su fuente")


## Las firmas nuevas de chispas: el metal duro (pocas, cortas y anaranjadas, TC 9-237) y el titanio (blanco, RI 7902); el oro, sin
## chispas; las de antes, igual (el «titanio» del taller sigue sin firma).
func test_las_chispas_de_los_otros_metales() -> void:
	assert_eq(Sparks.family_of("metal-duro"), "metal_duro", "el metal duro")
	assert_eq(Sparks.family_of("titanio-cp"), "titanio_cp", "el titanio de las garras")
	assert_eq(Sparks.family_of("oro"), "sin_chispas", "el oro no chispea")
	assert_eq(Sparks.family_of("titanio"), "", "el titanio del taller, como estaba")
	var wc := Sparks.stream_for("metal-duro", 35.0)
	var ti := Sparks.stream_for("titanio-cp", 35.0)
	var fe := Sparks.stream_for("acero", 35.0)
	assert_true(float(wc.length_mm) < 0.1 * float(fe.length_mm), "el metal duro, un haz muy corto (%s mm)" % _fx(float(wc.length_mm), 0))
	assert_true(float(wc.volume) < float(fe.volume), "y pequeño")
	assert_eq(String(wc.bursts_name), "ninguna", "sin estallidos")
	assert_eq(String(ti.color_name), "blanco", "el titanio, blanco")
	assert_true(String(ti.source).contains("RI 7902") and String(wc.source).contains("fila 13"), "con su fuente")
	assert_eq(float(Sparks.stream_for("oro", 35.0).volume), 0.0, "el oro, nada")
	for id: String in CareData.SPARK_MATERIAL.values():
		assert_true(Sparks.family_of(id) != "", "%s tiene firma" % id)
