## La garra rota que se reforja (petición 35, unidad 5g): el muñón de queratina con un bloque en bruto del material de la
## reforja (ClawForge.care_setup con stump_mm), que se lima en la cetrería con herramientas más duras que el material; la
## forma final se juzga como la de una garra natural, y lo que no se hace de verdad va marcado como ficción.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")

const FRAME := 1.0 / 60.0


static func _hold(st: State, s0: float, secs: float) -> void:
	st.press_on(s0)
	for i in int(round(secs / FRAME)):
		st.drag(0.0, 0.0, s0, FRAME)
		st.tick(FRAME)
	st.release()


static func _block_care(material: String, stump: float, wall: float = 1.0) -> ClawCare:
	return ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "bloque", "overgrowth_days": 0.0,
		"block": { "material": material, "stump_mm": stump, "wall_mm": wall, "fiction": true, "note": "FICCIÓN: prueba", "source": "test" } })


func test_el_bloque_en_bruto_sobre_el_munon() -> void:
	var nat := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "bloque", "overgrowth_days": 0.0 })
	var c := _block_care("zafiro", 20.0, 1.0)
	var sn := c.snapshot()
	var L := c.natural_mm()
	assert_near(c.apex_mm(), L + 1.0, 1e-9, 0.0, "el bloque sobra la pared por delante del largo natural")
	# el muñón, con el perfil que tenía; el bloque, un cilindro con la pared de sobra alrededor
	for s: float in [2.0, 10.0, 19.0]:
		assert_near(c.radius_at(s), nat.radius_at(s), 1e-9, 0.0, "a %s mm, el muñón de queratina" % s)
	var rb := nat.radius_at(20.0) + 1.0
	for s: float in [21.0, 28.0, L]:
		assert_near(c.radius_at(s), rb, 1e-6, 0.0, "a %s mm, el bloque en bruto" % s)
	assert_true(float(sn.tip.flatMm) > 1.0, "de cara plana: sin tallar")
	assert_eq(String(sn.shape.verdict), "roma", "sin tallar, la forma no es la de una garra")
	# la carne viva se queda en el muñón
	assert_true(float(sn.claw.quickMm) <= 20.0 + 1e-9, "la carne viva, en el muñón")
	assert_eq(float(c.core_at(25.0)), 0.0, "en el bloque no hay carne viva")
	# la instantánea lo dice, con la ficción
	var b: Dictionary = sn.claw.block
	assert_eq([String(b.material), float(b.fromMm), bool(b.fiction)], ["zafiro", 20.0, true], "el bloque, en la instantánea")
	assert_eq(String((sn.events as Array)[0].code), "bloque", "y en los sucesos, con su nota")
	assert_true(String((sn.events as Array)[0].message).contains("FICCIÓN"), "la ficción, dicha")
	# la superficie del bloque, en bruto; la del muñón, la natural
	var sf: Dictionary = sn.surface
	assert_eq(float(sf.ra_um[int(25.0 / ClawCare.STATION_MM)]), float(CareData.SURFACE.raw_ra_um.value), "el bloque, en bruto")
	assert_eq(float(sf.ra_um[int(10.0 / ClawCare.STATION_MM)]), float(CareData.SURFACE.natural_ra_um.value), "el muñón, natural")
	# sin bloque, nada cambia
	assert_true(nat.snapshot().claw.block == null, "sin bloque: null")


## Se lima con herramientas más duras que el material: la lima de acero resbala sobre el zafiro y muerde la queratina del
## muñón; la de diamante talla el bloque.
func test_se_lima_con_herramientas_mas_duras_que_el_bloque() -> void:
	var c := _block_care("zafiro", 20.0, 1.0)
	var at_block := c.apex_mm() - 5.0
	var r_steel := c.file({ "tool": "lima_fina", "zone": "flanco", "at_mm": c.apex_mm() - at_block, "force_n": 4.0, "travel_mm": 40.0 })
	assert_true(bool(r_steel.noBite), "la lima de acero no muerde el bloque de zafiro")
	assert_eq(float(r_steel.removedMm3), 0.0, "y no quita nada")
	var r_stump := c.file({ "tool": "lima_fina", "zone": "flanco", "at_mm": c.apex_mm() - 8.0, "length_mm": 2.0, "force_n": 4.0, "travel_mm": 40.0 })
	assert_false(bool(r_stump.noBite), "la queratina del muñón, sí")
	assert_true(float(r_stump.removedMm3) > 0.0, "y la lima")
	var r_dia := c.file({ "tool": "lima_diamante_gruesa", "zone": "punta", "angle_deg": 20.0, "force_n": 6.0, "travel_mm": 40.0 })
	assert_false(bool(r_dia.noBite), "la de diamante muerde el zafiro")
	assert_true(float(r_dia.removedMm3) > 0.0, "y talla el bloque")
	# el diamante: solo lo talla el diamante, y despacio (como en la talla de gemas)
	var d := _block_care("diamante", 20.0, 1.0)
	for tid: String in ["lima_bastarda", "lija_p180", "torno"]:
		var p := { "tool": tid, "zone": "punta", "angle_deg": 30.0, "force_n": 6.0, "travel_mm": 40.0, "dwell_s": 0.5 }
		assert_true(bool(d.file(p).noBite), "%s no muerde el bloque de diamante" % tid)
	var z := _block_care("zafiro", 20.0, 1.0)
	var pd := { "tool": "lima_diamante_gruesa", "zone": "punta", "angle_deg": 30.0, "force_n": 6.0, "travel_mm": 40.0 }
	var v_d := float(d.file(pd).removedMm3)
	var v_z := float(z.file(pd).removedMm3)
	assert_true(v_d > 0.0 and v_d < 0.5 * v_z, "la lima de diamante talla el diamante mucho más despacio que el zafiro (%s frente a %s mm³)" % [v_d, v_z])


## La forma final se juzga como la de una garra natural: tallar el bloque lo acerca (menos sobra, punta más fina), y nunca
## lo deja más resistente que antes de quitarle material de la punta.
func test_la_forma_se_juzga_como_la_natural() -> void:
	var c := _block_care("zafiro", 20.0, 1.0)
	var sh0: Dictionary = c.shape()
	var r_prev := float(sh0.tipRadiusUm)
	var left_prev := float(sh0.overgrowthLeftMm)
	for k in 40:
		c.file({ "tool": "lima_diamante_gruesa", "zone": "punta", "angle_deg": 30.0, "force_n": 8.0, "travel_mm": 60.0 })
		var sh: Dictionary = c.shape()
		assert_true(float(sh.tipRadiusUm) <= r_prev + 1e-9, "pasada %d: la punta no se embota al tallarla" % k)
		assert_true(float(sh.overgrowthLeftMm) <= left_prev + 1e-9, "ni crece")
		r_prev = float(sh.tipRadiusUm)
		left_prev = float(sh.overgrowthLeftMm)
	assert_true(r_prev < float(sh0.tipRadiusUm), "tallada, la punta se afila (%s → %s µm)" % [sh0.tipRadiusUm, r_prev])
	assert_true(String(c.shape().verdict) != "roma" or r_prev < float(sh0.tipRadiusUm), "y la forma cambia")
	# los mismos márgenes que la natural: con la misma punta, el mismo veredicto de punta
	assert_eq(float(c.shape().naturalUm), float(ClawCare.new({ "animal": "rapaz", "claw": "aguila" }).tip_state().naturalUm), "la punta natural de referencia, la de la garra")


## ClawForge.care_setup con stump_mm: sin pieza, no; con la pieza fría y sin tallar, el bloque, marcado como ficción.
func test_la_reforja_devuelve_el_bloque() -> void:
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	var req := { "stump_mm": 18.0, "digit": "II", "paw": "izquierda", "seed": "x", "overgrowth_days": 30.0 }
	var none := f.care_setup(req)
	assert_false(bool(none.careSupported), "sin pieza, no hay bloque")
	assert_true(String(none.reason).length() > 10, "y dice por qué")
	f.choose("zafiro")
	var cs := f.care_setup(req)
	assert_true(bool(cs.careSupported), "con la pieza comprada (fría, sin tallar), sí")
	assert_eq(String(cs.inlay), "none", "la garra sigue siendo de queratina")
	var b: Dictionary = cs.block
	assert_eq([String(b.material), float(b.stump_mm), bool(b.fiction)], ["zafiro", 18.0, true], "el bloque de zafiro sobre el muñón")
	assert_eq(float(b.wall_mm), float(ForgeData.SHEATH.wall_mm), "con la pared de la funda de sobra")
	assert_true(String(b.note).begins_with("FICCIÓN") and String(b.note).contains("acrílico"), "lo que en la realidad se hace")
	for key: String in ["digit", "paw", "seed", "overgrowth_days"]:
		assert_eq(cs[key], req[key], "conserva %s de la garra rota" % key)
	var c := ClawCare.new(cs)
	assert_eq(String(c.snapshot().claw.block.material), "zafiro", "ClawCare lo toma")
	assert_eq(String(c.snapshot().claw.digit), "II", "en su dedo")
	# sin stump_mm, como siempre (la garra reforjada entera, si el proceso ha terminado)
	assert_false(f.care_setup().has("block"), "sin garra rota, sin bloque")


## ClawCareState: la garra rota vuelve de la reforja con el bloque; el animal es el mismo, el reloj sigue y sus llamadas
## empiezan aquí (otra ClawCare con ellas llega a la misma garra).
func test_el_estado_vuelve_de_la_reforja() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "reforja" })
	st.set_sedation("anestesia")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() + 2.0), State.CLIP_CLOSE_S + 0.1)
	var req := st.reforge_request()
	var f0 := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	f0.choose("titanio")
	assert_true(bool(st.care.snapshot().bleeding.active), "(el corte llega a la carne viva: sangra)")
	if bool(st.care.snapshot().bleeding.active):
		assert_false(st.reforge_with(f0.care_setup(req)), "sangrando, no se pega el bloque")
		assert_true(String(st.view().notice).contains("sangre"), "primero, parar la sangre")
		st.pick("hemostatico")
		st.time_scale = 10.0
		_hold(st, st.care.apex_mm(), 4.0)
		st.time_scale = 1.0
	assert_false(bool(st.care.snapshot().bleeding.active), "(ya no sangra)")
	var t := st.care.time_s()
	var stress := float(st.patient.stress)
	assert_near(float(req.stump_mm), st.care.apex_mm(), 1e-9, 0.0, "lo que queda de la garra")
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	assert_false(st.reforge_with(f.care_setup(req)), "sin pieza, no vuelve")
	f.choose("titanio")
	assert_true(st.reforge_with(f.care_setup(req)), "con la pieza, vuelve con el bloque")
	var sn := st.care.snapshot()
	assert_eq(String(sn.claw.block.material), "titanio", "el bloque de titanio")
	assert_near(float(sn.claw.block.fromMm), float(req.stump_mm), 1e-9, 0.0, "sobre el muñón")
	assert_near(st.care.time_s(), t, ClawCare.DT, 0.0, "al día con el reloj")
	assert_true(float(st.patient.stress) >= stress - 1e-12, "el animal es el mismo")
	assert_true(String(st.view().notice).contains("FICCIÓN"), "el aviso dice lo que en la realidad no se hace")
	var last: Array = st.history[st.history.size() - 1] if String(st.history[st.history.size() - 1][1]) == "reforge" else st.history[st.history.size() - 2]
	assert_eq(String(last[1]), "reforge", "history lo apunta")
	# las llamadas de la garra nueva dan la misma garra
	st.pick("lima_diamante_gruesa")
	_hold(st, st.care.apex_mm() - 0.5, 1.0)
	var c := ClawCare.new(st.care_setup(st.paw, st.digit))
	for call: Array in st.calls:
		_apply(c, String(call[0]), call[1])
	assert_eq(var_to_str(c.snapshot().profile), var_to_str(st.care.snapshot().profile), "sus llamadas dan la misma garra")
	# y history repite el ensayo entero, con la vuelta de la reforja: la garra de antes y, desde «reforge», la del bloque
	var p0 := Patient.new(String(st.setup.animal), String(st.setup.sedation))
	var cares := {}
	for e: Array in st.history:
		var key := String(e[0])
		var parts := key.split("|")
		var base := st.care_setup(parts[0], parts[1])
		base.erase("block")
		if String(e[1]) == "reforge":
			cares[key] = ClawCare.new(base.merged({ "block": e[2] }), p0)
			continue
		if not cares.has(key):
			cares[key] = ClawCare.new(base, p0)
		_apply(cares[key], String(e[1]), e[2])
	var a: Dictionary = (cares[State.slot_key(st.paw, st.digit)] as ClawCare).snapshot()
	var b: Dictionary = st.care.snapshot()
	a.erase("serial")
	b.erase("serial")
	assert_eq(var_to_str(a), var_to_str(b), "la misma garra con su bloque")
	assert_eq(var_to_str(p0.view()), var_to_str(st.patient.view()), "y el mismo animal")


## La vista publica lo que pide la reforja (lo pidió la 5f; unidad 5j): con la garra rota, reforge_request(), lo mismo que
## lleva la página al laboratorio; con la garra sana, o ya con su bloque, nada.
func test_la_vista_publica_lo_que_pide_la_reforja() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "vista-reforja" })
	assert_true((st.view().reforge_request as Dictionary).is_empty(), "sana: nada que reforjar")
	# seca, la tenaza un poco por delante de la carne viva raja la garra hasta ella (como en la página)
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4), State.CLIP_CLOSE_S + 0.2)
	var v := st.view()
	assert_true(bool(v.snap.damage.broken), "(la garra se ha roto)")
	var req: Dictionary = v.reforge_request
	assert_eq(var_to_str(req), var_to_str(st.reforge_request()), "rota: la vista publica reforge_request()")
	assert_near(float(req.stump_mm), st.care.apex_mm(), 1e-9, 0.0, "con lo que queda de ella")
	assert_eq([String(req.digit), String(req.paw)], [st.digit, st.paw], "de su dedo y su pata")
	# con eso, la reforja devuelve el bloque sobre ese muñón
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	f.choose("titanio")
	var cs := f.care_setup(req)
	assert_near(float(cs.block.stump_mm), float(req.stump_mm), 1e-12, 0.0, "y la reforja hace el bloque sobre ese muñón")
	# parada la sangre y pegado el bloque, la garra ya no está rota: nada que publicar
	if bool(st.care.snapshot().bleeding.active):
		st.pick("hemostatico")
		st.time_scale = 10.0
		_hold(st, st.care.apex_mm(), 4.0)
		st.time_scale = 1.0
	assert_true(st.reforge_with(cs), "(vuelve con el bloque)")
	assert_true((st.view().reforge_request as Dictionary).is_empty(), "con su bloque, nada que reforjar")


## La prótesis de verdad (unidad 5j; lo pidió la 5g): el acrílico dental vuelve de la reforja como un bloque sin ficción
## sobre el muñón; la lima de acero, más dura, lo muerde; la punta aguanta con la resistencia del acrílico (antes, sin datos);
## y el estado lo pega con un aviso que dice que así se hace de verdad.
func test_la_protesis_de_acrilico_se_lima_en_la_cetreria() -> void:
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	f.choose("acrilico")
	var cs := f.care_setup({ "animal": "rapaz", "claw": "aguila", "stump_mm": 20.0, "seed": "bloque", "overgrowth_days": 0.0 })
	var c := ClawCare.new(cs)
	var sn := c.snapshot()
	assert_eq([String(sn.claw.block.material), bool(sn.claw.block.fiction)], ["acrilico", false], "el bloque de acrílico, sin ficción")
	assert_eq(float(sn.claw.block.hv), float(ForgeData.PROSTHESIS.acrilico.hv), "con la dureza del acrílico")
	var ev: Dictionary = (sn.events as Array)[0]
	assert_true(String(ev.code) == "bloque" and not String(ev.message).contains("FICCIÓN"), "el suceso no dice ficción: %s" % ev.message)
	assert_true(c.tip_state().lateralN != null, "la punta de acrílico aguanta con su resistencia (no «sin datos»)")
	var r := c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 30.0, "force_n": 4.0, "travel_mm": 40.0 })
	assert_false(bool(r.noBite), "la lima de acero (700 HV) muerde el acrílico (~20 HV)")
	assert_true(float(r.removedMm3) > 0.0, "y lo lima")
	# el estado lo pega (parada la sangre) y avisa de que así se hace de verdad
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "acrilico" })
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	_hold(st, st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4), State.CLIP_CLOSE_S + 0.2)
	if bool(st.care.snapshot().bleeding.active):
		st.pick("hemostatico")
		st.time_scale = 10.0
		_hold(st, st.care.apex_mm(), 4.0)
		st.time_scale = 1.0
	var g := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	g.choose("acrilico")
	assert_true(st.reforge_with(g.care_setup(st.view().reforge_request)), "vuelve con el acrílico")
	var notice := String(st.view().notice)
	assert_true(notice.contains("Así se repara de verdad") and not notice.contains("FICCIÓN"), "el aviso: %s" % notice)


## El calor de limar el bloque (unidad 5j; lo dejó la 5g) va por su material: la conducción, la densidad y el calor
## específico de su ficha de la reforja (block_thermal). En régimen, el calor cruza el bloque y la queratina en serie; con el
## mismo calor, un bloque que conduce y difunde más nunca deja la carne viva más fría ni la cara más caliente; el acrílico
## calienta como la queratina; sin datos (la hematites), como la queratina; y el bloque no pasa de su tope.
func test_el_calor_de_limar_el_bloque_va_por_su_material() -> void:
	# los datos, los de la ficha de la reforja
	for mid: String in ForgeData.MATERIALS:
		var bt := ClawCare.block_thermal(mid)
		var m: Dictionary = ForgeData.MATERIALS[mid]
		if m.get("k") == null:
			assert_true(bt.is_empty(), "%s: sin conducción, se cuenta como la queratina" % mid)
			continue
		assert_eq(float(bt.k), float(m.k.value), "%s: su conducción" % mid)
		assert_near(float(bt.rhoC), float(ForgeData.density_of(mid)) * float(m.cp.value), 1e-12, 0.0, "%s: ρ·c" % mid)
		assert_true(String(bt.source).length() > 20 and String(bt.quality) in ["primary", "secondary", "estimate"], "%s: con su fuente" % mid)
	assert_eq(float(ClawCare.block_thermal("acrilico").capC), 125.0, "el acrílico se ablanda a 125 °C")
	assert_eq(float(ClawCare.block_thermal("diamante").capC), float(ForgeData.MATERIALS.diamante.air_c.value), "el diamante se quema al aire")
	var bed: float = CareData.THERMAL.bed_c.value
	# en régimen, por el flanco del bloque más allá de la carne viva: el calor cruza el bloque y la queratina en serie,
	# θ_cara = P/(1/R + h·A), con R = (dx/A)·Σ 1/k (el extremo vivo y la cara, medio nodo)
	var st := _block_care("acero", 20.0, 1.0)
	st._flank_contact_mm2 = 10.0
	var p := 0.05
	st._run(3000.0, p, "flanco", 21.0, 0.5)
	var n: int = st._th.size()
	var isb: PackedByteArray = st._th_isblk
	assert_true(isb.size() == n and isb[n - 1] == 1 and isb[0] == 0, "(la cara, en el bloque; el extremo vivo, en la carne)")
	var a := 10.0e-6
	var dx := ClawCare.THERMAL_DX_MM / 1000.0
	var k_k := ClawCare.keratin_conductivity()
	var k_b := float(ClawCare.block_thermal("acero").k)
	var sum := 0.0
	var sum_q := 0.0
	var n_live: int = st._th_live
	for i in n:
		var w := 0.5 if i == 0 or i == n - 1 else 1.0
		sum += w / (k_b if isb[i] == 1 else k_k)
		if i <= n_live:
			sum_q += (0.5 if i == 0 or i == n_live else 1.0) / (k_b if isb[i] == 1 else k_k)
	var r_tot := dx / a * sum
	var face := p / (1.0 / r_tot + float(CareData.THERMAL.h_air.value) * a)
	var th0: Dictionary = st.snapshot().thermal
	assert_near(float(th0.faceC) - bed, face, 1e-6, 0.0, "la cara en régimen, con el bloque y la carne en serie")
	assert_near(float(th0.quickC) - bed, face * sum_q / sum, 1e-6, 0.0, "y la carne viva, en proporción")
	# el mismo calor (0,5 W en la punta, 20 s) en bloques que conducen y difunden cada vez más
	var prev_q := -INF
	var prev_f := INF
	var prev_k := 0.0
	var prev_a := 0.0
	for mid: String in ["acrilico", "vidrio", "circonita", "cuarzo", "titanio", "oro"]:
		var bt := ClawCare.block_thermal(mid)
		assert_true(float(bt.k) > prev_k and float(bt.alpha) > prev_a, "(%s conduce y difunde más que el anterior)" % mid)
		prev_k = float(bt.k)
		prev_a = float(bt.alpha)
		var c := _block_care(mid, 20.0, 1.0)
		c._run(20.0, 0.5, "punta", c.apex_mm(), 0.5)
		var th: Dictionary = c.snapshot().thermal
		print("    (info) bloque de %s: carne viva hasta %s °C, cara %s °C" % [mid, _Js.to_fixed(float(th.peakQuickC), 2), _Js.to_fixed(float(th.faceC), 1)])
		assert_true(float(th.peakQuickC) >= prev_q - 1e-9, "%s: la carne viva nunca más fría (%s °C)" % [mid, th.peakQuickC])
		assert_true(float(th.faceC) <= prev_f + 1e-9, "%s: la cara nunca más caliente (%s °C)" % [mid, th.faceC])
		prev_q = float(th.peakQuickC)
		prev_f = float(th.faceC)
	assert_true(prev_q > bed + 1.0, "por el oro, el calor llega antes a la carne viva (%s °C)" % prev_q)
	# el acrílico conduce como la queratina; la hematites, sin datos, se cuenta como ella
	var acr := _block_care("acrilico", 20.0, 1.0)
	var hem := _block_care("hematites", 20.0, 1.0)
	assert_true(hem.snapshot().claw.block.thermal == null and acr.snapshot().claw.block.thermal != null, "la hematites, sin datos de calor")
	for c: ClawCare in [acr, hem]:
		c._run(20.0, 0.1, "punta", c.apex_mm(), 0.5)
	var fa := float(acr.snapshot().thermal.faceC) - bed
	var fh := float(hem.snapshot().thermal.faceC) - bed
	assert_true(absf(fa - fh) < 0.25 * fh, "el acrílico calienta como la queratina (%s frente a %s K)" % [_Js.to_fixed(fa, 1), _Js.to_fixed(fh, 1)])
	# el bloque no pasa de su tope: el acrílico, de su reblandecimiento
	var hot := _block_care("acrilico", 20.0, 1.0)
	hot._run(20.0, 2.0, "punta", hot.apex_mm(), 0.5)
	var ht: Dictionary = hot.snapshot().thermal
	assert_true(float(ht.faceC) <= 125.0 + 1e-9 and bool(ht.blockHot), "el acrílico no pasa de 125 °C: se ablanda (%s °C)" % ht.faceC)
	assert_true((hot.snapshot().events as Array).any(func(e: Dictionary) -> bool: return String(e.code) == "bloque_calor"), "y lo dice")
	assert_false(bool(ht.charred), "(la queratina del muñón no se quema)")
	# la nota de la ficción: el calor del bloque, con su material (o como la queratina, sin datos)
	var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
	f.choose("zafiro")
	assert_true(String(f.care_setup({ "stump_mm": 18.0 }).block.note).contains("conducción de su material"), "la nota lo cuenta")
	f.choose("hematites")
	assert_true(String(f.care_setup({ "stump_mm": 18.0 }).block.note).contains("como en la queratina"), "y sin datos, también")


static func _apply(c: ClawCare, method: String, args: Variant) -> void:
	match method:
		"file":
			c.file(args)
		"clip":
			c.clip(args)
		"advance":
			c.advance(float(args))
		"advance_held":
			c.advance_held(float(args))
		"set_sedation":
			c.set_sedation(String(args))
		"set_humidity":
			c.set_humidity(String(args))
		"hemostasis":
			c.hemostasis(args)
		"apply":
			c.apply(args)
		"probe_tip":
			c.probe_tip(args)
