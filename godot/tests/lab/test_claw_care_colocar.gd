## Colocar a mano la pieza de la reforja (unidad 5o, petición 43): la pieza llega sin pegar, se prepara la garra, se pega
## (adhesivo, acrílico dental o resina con la lámpara), se coloca y se sujeta, se quita lo que rebosa, se lima y se prueba.
## Nada se hace solo: cada paso es del usuario. Invariantes de la física (ClawCareBond) y del estado (ClawCareState).
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Bond = preload("res://core/lab/claw_care_bond.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const ForgeState = preload("res://core/lab/claw_forge_state.gd")

const FRAME := 1.0 / 60.0
const FORGE_FRAME := 1.0 / 30.0


static func _fresh_state() -> State:
	return State.new({ "animal": "rapaz", "claw": "aguila", "seed": "colocar", "overgrowth_days": 0.0, "sedation": "sujecion" })


## La funda entera de la reforja (sin block): la del acero de una garra de águila.
static func _sheath_fs(mat: String = "acero") -> Dictionary:
	return { "animal": "rapaz", "claw": "aguila", "inlay": mat }


## El bloque de una garra rota (con block), sobre el muñón a stump mm.
static func _block_fs(_st: State, mat: String, stump: float) -> Dictionary:
	return { "careSupported": true, "block": { "material": mat, "stump_mm": stump, "wall_mm": 1.0, "fiction": not ForgeData.PROSTHESIS.has(mat), "note": "prueba", "source": "test" } }


## Pasa secs segundos del ensayo con el reloj a ×scale.
static func _wait(st: State, secs: float, scale: float = 1.0) -> void:
	st.set_time_scale(scale)
	var left := secs / scale
	while left > 1e-9:
		var dt := minf(left, 0.25)
		st.tick(dt)
		left -= dt
	st.set_time_scale(1.0)


## Prepara la garra: alcohol, que se evapore, y una pasada suave de lija donde va a pegar (s: dónde, mm desde la base).
static func _prepare(st: State, s: float) -> void:
	st.pick("alcohol")
	st.press_on(s)
	st.release()
	_wait(st, 40.0)
	st.pick("lija_p180")
	st.press_on(s)
	for i in 10:
		st.drag(3.0, 3.0, s, FRAME)
		st.tick(FRAME)
	st.release()
	st.drop()


## El laboratorio de la reforja (5m) siguiendo su tutorial con «Hazlo como dice el paso», dejando correr cada marcha y cada
## animación, hasta «Pasar a la cetrería para colocarla».
static func _forge_follow(fs: ForgeState) -> void:
	fs.tutorial_goto(fs.process)
	var n := 0
	while not fs.tutorial_done() and n < 80:
		fs.do_step()
		var m := 0
		while fs.running() and m < int((ForgeState.RUN_MAX_S + 5.0) / FORGE_FRAME):
			fs.tick(FORGE_FRAME)
			m += 1
		for i in int((ForgeState.ACT_MAX_S + 2.0) / FORGE_FRAME):
			if fs.act.is_empty() or float(fs.act.t) >= float(fs.act.dur):
				break
			fs.tick(FORGE_FRAME)
		n += 1


## Rompe la garra elegida: seca, con la tenaza, un poco por delante de la carne viva (como en la demo de la cetrería), y para
## la sangre con el hemostático (el reloj a ×10).
static func _break_and_stop(st: State) -> void:
	st.set_humidity("seca")
	st.pick("tenaza")
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4))
	for i in int((State.CLIP_CLOSE_S + 0.2) / FRAME):
		st.tick(FRAME)
	st.release()
	st.set_humidity("natural")
	if bool(st.care.snapshot().bleeding.active):
		st.pick("hemostatico")
		var s0 := st.care.apex_mm()
		st.set_time_scale(10.0)
		st.press_on(s0)
		for i in 240:
			st.drag(0.0, 0.0, s0, FRAME)
			st.tick(FRAME)
		st.release()
		st.set_time_scale(1.0)
	st.drop()


## Lima la unión (lo que rebosa ya duro y el escalón) con pasadas de la herramienta de la mano sobre ella; con una giratoria,
## toques de dwell s encendida y una pausa para que se enfríe. Devuelve las pasadas.
static func _file_joint(st: State, tool: String, j: float, dwell := 0.6) -> int:
	st.pick(tool)
	var rotary := State.is_rotary(tool)
	if rotary:
		st.set_rotary(true)
	var guard := 0
	while (st.bond().flash_mm3 > 0.0 or st.joint_step_mm() > float(CareData.BOND_JOINT.step_ok_mm)) and guard < 300:
		var s := j + (1.0 if rotary else 0.0)
		st.press_on(s)
		var frames := int(dwell / FRAME) if rotary else 4
		for i in frames:
			st.drag(0.0 if rotary else 8.0, 0.0 if rotary else 8.0, s, FRAME)
			st.tick(FRAME)
		st.release()
		if rotary:
			_wait(st, 4.0)
		guard += 1
	if rotary:
		st.set_rotary(false)
	st.drop()
	return guard


# ════════ El camino entero: del laboratorio de la reforja a la garra colocada, limada y probada ════════

func test_el_camino_entero_con_la_funda_del_laboratorio() -> void:
	# el laboratorio (5m): el acero fundido por inducción, colado con la forma de la garra, limado, pulido y probado en la garra
	var fs := ForgeState.new({ "animal": "rapaz", "claw": "aguila", "paw": "derecha", "digit": "III" })
	fs.set_process("acero")
	_forge_follow(fs)
	var cv := fs.care_view()
	assert_true(bool(cv.ok), "lista para la cetrería: %s" % cv.text)
	var lab: Dictionary = cv.setup.piece
	assert_true(bool(lab.carved) and bool(lab.polished) and bool(lab.fitTested), "terminada y probada en el laboratorio, sin pegar")
	# llega a la bandeja, sin pegar, con lo que dice el laboratorio
	var st := _fresh_state()
	assert_true(st.receive_piece(cv.setup), "llega a la cetrería")
	var bv: Dictionary = st.view().bond
	assert_eq([String(bv.kind), String(bv.material), bool(bv.attached)], ["funda", "acero", false], "en la bandeja, sin pegar")
	assert_near(float(bv.areaMm2), float(lab.bondAreaMm2), 1e-9, 0.0, "con la superficie pegada de la funda del laboratorio")
	assert_near(float(bv.gapMm), float(lab.gapMm), 1e-12, 0.0, "y la holgura de su prueba del ajuste")
	assert_near(float(bv.jointMm), st.care.natural_mm() - float(lab.coverMm), 1e-9, 0.0, "el borde, donde acaba lo que cubre")
	assert_true(String(bv.lab_text).contains("holgura probada"), "la tarjeta lo dice: %s" % bv.lab_text)
	assert_false(st.is_reforged(), "la garra sigue de queratina")
	# a mano: preparar, el epoxi purgado, colocarla alineada, sujetarla con la venda hasta que fija (reloj ×3600)
	var j := float(bv.jointMm)
	_prepare(st, j + 2.0)
	st.bond_adhesive("epoxi")
	st.bond_purge()
	st.bond_apply()
	st.bond_grab(true)
	st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st.bond_hold(true, 0.0)
	assert_eq(st.bond().failure, "", "colocada a tiempo y alineada")
	for i in 3:
		st.bond_scrape()
	st.bond_wrap()
	st.bond_hold(false)
	assert_eq(st.bond().failure, "", "vendada: se puede soltar la mano")
	_wait(st, float(CareData.BOND_TIMES.epoxi.full_s) + 600.0, 3600.0)
	st.bond_unwrap()
	assert_true(st.bond().attached() and st.is_reforged(), "ha fijado: la garra lleva la funda")
	assert_eq(String(st.care.snapshot().inlay), "acero", "de acero")
	# acabar a mano: lo que rebosa ya duro y el escalón, con la lima sobre la unión; la prueba
	var passes := _file_joint(st, "lima_fina", j)
	assert_eq(st.bond().flash_mm3, 0.0, "sin rebaba (%d pasadas)" % passes)
	assert_true(st.joint_step_mm() <= float(CareData.BOND_JOINT.step_ok_mm), "y sin escalón")
	st.bond_test()
	assert_true(bool(st.bond().test.ok), "aguanta el tirón: %s" % String(st.bond().test.text))
	assert_true(bool(st.view().bond.done), "colocada, limada y probada: %s" % st.view().bond.stage_text)
	print("    (info) funda del laboratorio: %s mm² y %s mm de holgura; %d pasadas de lima; %s" % [snapped(float(bv.areaMm2), 0.1), snapped(float(bv.gapMm), 0.001), passes, st.bond().test.text])


func test_el_camino_entero_con_la_protesis_de_acrilico() -> void:
	# la garra se rompe en la cetrería, se para la sangre y va al laboratorio («Reforjar con material»)
	var st := _fresh_state()
	_break_and_stop(st)
	assert_true(bool(st.care.snapshot().damage.broken) and not bool(st.care.snapshot().bleeding.active), "rota y sin sangrar")
	# la prótesis se hace con el ave anestesiada (isoflurano), como la reparación del pico: limar cerca del muñón calienta
	st.set_sedation("anestesia")
	var fc := st.reforge_request()
	var fs := ForgeState.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "paw": st.paw, "digit": st.digit, "from_care": fc })
	fs.set_process(ForgeState.ACRYLIC)
	_forge_follow(fs)
	var cv := fs.care_view()
	assert_true(bool(cv.ok) and bool(cv.block), "el acrílico, a la cetrería: %s" % cv.text)
	assert_true(st.receive_piece(cv.setup), "llega")
	var bv: Dictionary = st.view().bond
	assert_eq([String(bv.kind), String(bv.method), bool(bv.attached), bool(bv.fiction)], ["protesis", "acrilico", false, false], "la prótesis de verdad, sin pegar")
	assert_true(st.care.snapshot().claw.block == null, "nada pegado aún: la garra, rota")
	# a mano: limpiar y lijar lo que queda, mezclar y aplicar en capas, dejar que fragüe
	var j := float(bv.jointMm)
	_prepare(st, j - 0.5)
	var guard := 0
	while not st.bond().done_building() and guard < 20:
		st.bond_mix(2.0)
		_wait(st, float(CareData.ACRYLIC_MIX.dough_s) + 5.0)
		st.set_layer_kind("gruesa")
		st.bond_layer()
		st.bond_scrape()
		guard += 1
	assert_true(st.bond().done_building(), "a capas hasta el largo (%d capas)" % st.bond().layers.size())
	var peak := float(st.care.snapshot().thermal.peakQuickC)
	_wait(st, float(CareData.ACRYLIC_MIX.set_s) + 5.0, 60.0)
	assert_true(st.bond().set_all(st.care.time_s()), "fraguado")
	assert_true(String(st.view().notice).begins_with("Ha fraguado"), "y lo avisa al fraguar: «%s»" % st.view().notice)
	_wait(st, float(CareData.ACRYLIC_MIX.full_s), 3600.0)
	assert_true(float(st.care.snapshot().thermal.peakQuickC) > float(CareData.THERMAL.bed_c.value), "el fraguado ha calentado la carne viva")
	# acabar a mano: ya fraguado, se le da forma con la amoladora (Matta et al. 2022), toques cortos; la prueba
	var passes := _file_joint(st, "amoladora", j)
	assert_true(st.halted.is_empty(), "la sesión sigue: %s" % [st.halted])
	assert_eq(st.bond().flash_mm3, 0.0, "sin rebaba (%d toques)" % passes)
	assert_true(st.joint_step_mm() <= float(CareData.BOND_JOINT.step_ok_mm), "y sin escalón (%s mm)" % st.joint_step_mm())
	st.bond_test()
	assert_true(bool(st.bond().test.ok), "aguanta el tirón: %s" % String(st.bond().test.text))
	assert_true(bool(st.view().bond.done), "colocada, limada y probada: %s" % st.view().bond.stage_text)
	print("    (info) prótesis de acrílico: %d capas, carne viva a %s °C de pico; %d toques de amoladora; %s" % [st.bond().layers.size(), snapped(peak, 0.1), passes, st.bond().test.text])


## La resina (80 HV) es más dura que la queratina: al limar la unión, la herramienta se apoya en la pieza, que sobresale, y no
## en la queratina de debajo del escalón. Así el escalón baja hasta no notarse sin limar el muñón hasta la carne viva.
func test_limar_la_union_no_lima_el_munon_de_debajo() -> void:
	var st := _fresh_state()
	_break_and_stop(st)
	st.set_sedation("anestesia")
	var fs := ForgeState.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "paw": st.paw, "digit": st.digit, "from_care": st.reforge_request() })
	fs.set_process(ForgeState.ACRYLIC)
	_forge_follow(fs)
	assert_true(st.receive_piece(fs.care_view().setup), "llega")
	st.bond_method("resina")
	assert_eq(String(st.view().bond.name), String(CareData.RESIN.name), "con la resina, la prótesis se llama por su material")
	var j := float(st.view().bond.jointMm)
	_prepare(st, j - 0.5)
	st.bond_eyes(true)
	var guard := 0
	while not st.bond().done_building() and guard < 20:
		st.set_layer_kind("gruesa")
		st.bond_layer()
		st.bond_lamp("azul", 0.0, 40.0)
		st.bond_lamp_on()
		_wait(st, 45.0)
		guard += 1
	assert_true(st.bond().set_all(st.care.time_s()), "curada")
	var below := st.care.radius_at(j - 0.5)
	var step0 := st.joint_step_mm()
	assert_true(step0 > float(CareData.BOND_JOINT.step_ok_mm), "sobresale: escalón de %s mm" % step0)
	var passes := _file_joint(st, "amoladora", j)
	assert_true(st.joint_step_mm() <= float(CareData.BOND_JOINT.step_ok_mm), "el escalón baja hasta no notarse (%d toques, %s mm)" % [passes, st.joint_step_mm()])
	assert_near(st.care.radius_at(j - 0.5), below, 1e-9, 1e-9, "la queratina de debajo de la unión, igual")
	assert_false(bool(st.care.snapshot().bleeding.active) or String(st.care.shape().verdict) == "rota", "sin limar el muñón hasta la carne viva")


## En la cara ancha de una rotura, una pasada suave de lija pule en vez de rayar: no queda lijada y el aviso dice por qué y qué
## hacer; apretando más con la P180, sí.
func test_lijar_la_rotura_pide_apretar_y_lo_dice() -> void:
	var st := _fresh_state()
	_break_and_stop(st)
	var fs := { "careSupported": true, "paw": String(st.paw), "digit": String(st.digit),
		"block": { "material": "acrilico", "stump_mm": st.care.apex_mm(), "wall_mm": 1.0, "fiction": false, "note": "prueba", "source": "test" } }
	assert_true(st.receive_piece(fs), "llega")
	for combo: Array in [["lija_p240", 2.0, false], ["lija_p180", 8.0, true]]:
		st.pick(String(combo[0]))
		st.set_angle(45.0)
		st.set_force(float(combo[1]))
		var s0 := st.care.apex_mm() - 0.4
		st.press_on(s0)
		for i in 9:
			st.drag(4.0, 4.0, s0, FRAME)
			st.tick(FRAME)
		st.release()
		assert_eq(st.bond().sanded(), bool(combo[2]), "%s a %s N: lijada %s" % combo)
		if not bool(combo[2]):
			assert_true(String(st.view().notice).begins_with("Aún sin lijar") and String(st.view().notice).contains("Aprieta más"), "y dice por qué: %s" % st.view().notice)


# ════════ Los datos de la colocación ════════

## Cada dato nuevo de la colocación y de la barra del animal lleva su fuente y su calidad (lo estimado, marcado «estimate»): la
## entrada entera, o cada parte con su «*_source» y su «*_quality», o cada sub-entrada (por adhesivo, por lámpara…).
func test_los_datos_de_la_colocacion_llevan_fuente_y_calidad() -> void:
	var data := {
		"VELOCIRAPTOR_BASE": CareData.VELOCIRAPTOR_BASE, "BOND_TIMES": CareData.BOND_TIMES, "BOND_PREP": CareData.BOND_PREP,
		"BOND_JOINT": CareData.BOND_JOINT, "PUTTY": CareData.PUTTY, "PUTTY_TIMES": CareData.PUTTY_TIMES, "BOND_PURGE": CareData.BOND_PURGE,
		"BOND_ALIGN": CareData.BOND_ALIGN, "BOND_WRAP": CareData.BOND_WRAP, "BOND_TEST": CareData.BOND_TEST, "BOND_FLASH": CareData.BOND_FLASH,
		"ACRYLIC_MIX": CareData.ACRYLIC_MIX, "ACRYLIC_RATIO": CareData.ACRYLIC_RATIO, "ACRYLIC_HEAT": CareData.ACRYLIC_HEAT,
		"LAYER_MM": CareData.LAYER_MM, "RESIN": CareData.RESIN, "LAMPS": CareData.LAMPS, "CURE_DEPTH": CareData.CURE_DEPTH,
		"WELD": CareData.WELD, "BLOOD": CareData.BLOOD, "ANIMAL_RISK": CareData.ANIMAL_RISK, "ROTARY_TOUCH": CareData.ROTARY_TOUCH,
	}
	for name: String in data:
		assert_true(_sourced(name, data[name]) > 0, "%s: con su fuente" % name)


const QUALITIES := ["primary", "secondary", "estimate"]


## Cuenta las fuentes de una entrada y comprueba cada una con su calidad.
func _sourced(name: String, d: Dictionary) -> int:
	var n := 0
	if d.has("source"):
		assert_true(String(d.source).length() > 20, "%s: fuente" % name)
		assert_true(String(d.get("quality", "")) in QUALITIES, "%s: calidad «%s»" % [name, d.get("quality", "")])
		n += 1
	for k: String in d.keys():
		if k.ends_with("_source"):
			var q := k.trim_suffix("_source") + "_quality"
			assert_true(String(d[k]).length() > 20, "%s.%s: fuente" % [name, k])
			assert_true(String(d.get(q, d.get("quality", ""))) in QUALITIES, "%s.%s: calidad" % [name, q])
			n += 1
	if n == 0:
		for k: Variant in d.keys():
			if d[k] is Dictionary:
				var m := _sourced("%s.%s" % [name, k], d[k])
				assert_true(m > 0, "%s.%s: con su fuente" % [name, k])
				n += m
	return n


# ════════ Física pura ════════

func test_la_fisica_de_la_union_es_monotona() -> void:
	# lo curado nunca baja con el tiempo, y llega a 1
	for adh: String in Bond.ADHESIVE_IDS:
		var prev := 0.0
		for t: float in [0.0, 1.0, 10.0, 20.0, 60.0, 600.0, 3600.0, 10800.0, 21600.0, 86400.0, 200000.0]:
			var f := Bond.cure_fraction(adh, t)
			assert_true(f >= prev - 1e-12 and f <= 1.0 + 1e-12, "%s: lo curado no baja (%s s)" % [adh, t])
			prev = f
		assert_near(prev, 1.0, 1e-9, 0.0, "%s: acaba curado del todo" % adh)
		# en la fijación, 0,1 N/mm²
		var fix := float(Bond.adhesive_times(adh).fix_s)
		assert_near(Bond.cure_fraction(adh, fix) * float(Bond.adhesive_data(adh).tau), 0.1, 1e-9, 0.0, "%s: la fijación es 0,1 N/mm²" % adh)
		# lijar nunca debilita
		var r_prev := 0.0
		for ra: float in [0.1, 0.229, 0.31, 0.6, 1.0, 1.73, 5.0]:
			var r := Bond.rough_factor(adh, ra)
			assert_true(r >= r_prev - 1e-12, "%s: más rugosa, nunca menos" % adh)
			r_prev = r
	# la luz: más lejos, nunca más irradiancia; más dosis, nunca menos profundidad de curado
	for l: String in CareData.LAMPS:
		var i_prev := INF
		for d: float in [0.0, 1.0, 5.0, 10.0, 20.0, 40.0]:
			var i := Bond.irradiance_at(l, d)
			assert_true(i <= i_prev + 1e-12, "%s: más lejos, menos luz" % l)
			i_prev = i
	var c_prev := 0.0
	for e: float in [0.0, 0.1, 1.0, 4.0, 8.0, 16.0, 30.0, 100.0]:
		var c := Bond.cure_depth_mm(e)
		assert_true(c >= c_prev - 1e-12, "más dosis, nunca menos profundidad")
		c_prev = c
	assert_near(Bond.cure_depth_mm(float(CareData.CURE_DEPTH.ref_j_cm2)), float(CareData.CURE_DEPTH.ref_mm), 1e-9, 0.0, "la ficha: 2,5 mm con 8 J/cm²")
	# la lámpara azul a 1 mm y 20 s cura más que la norma; la UV de uñas, no
	assert_true(Bond.cure_depth_mm(Bond.irradiance_at("azul", 1.0) * 20.0 / 1000.0) >= float(CareData.CURE_DEPTH.iso_min_mm), "la azul cura")
	assert_true(Bond.cure_depth_mm(Bond.irradiance_at("uv", 1.0) * 20.0 / 1000.0) < float(CareData.CURE_DEPTH.iso_min_mm), "la UV de uñas apenas")
	# el acrílico: más grueso, nunca menos calor; el calor sale todo (el triángulo acaba en 1)
	var q_prev := 0.0
	for h: float in [0.5, 1.0, 2.0, 3.0]:
		var q := Bond.acrylic_heat_j(h, 3.0, 2.0)
		assert_true(q >= q_prev, "más gruesa, más calor")
		q_prev = q
	assert_near(Bond.acrylic_heat_cdf(float(CareData.ACRYLIC_MIX.set_s)), 1.0, 1e-12, 0.0, "todo el calor al fraguar")
	assert_true(Bond.acrylic_heat_j(1.0, 3.0, 1.5) > Bond.acrylic_heat_j(1.0, 3.0, 2.5), "con más líquido, más calor")
	# a mano: 1 mm de capa sobre 3 mm de radio, con 2:1 → J del orden de 5 (56 kJ/mol × 1/3 de monómero)
	var vol := PI * 9.0 * 1.0e-9
	assert_near(Bond.acrylic_heat_j(1.0, 3.0, 2.0), 1180.0 * vol / 3.0 * 56000.0 / 0.10012 * 0.96, 1e-9, 0.0, "a mano")


func test_la_soldadura_sobre_la_garra_no_se_puede() -> void:
	var r := Bond.weld_report("oro", 5.0)
	assert_near(float(r.meltC), 1064.18, 1e-6, 0.0, "el baño del oro, a su fusión")
	assert_true(float(r.burnMm) > 0.0 and float(r.burnMm) < 2.0, "en un segundo quema menos de 2 mm de garra")
	assert_true(float(r.painS) > 1.0, "a 5 mm, la carne viva tarda más de un segundo en doler")
	assert_true(String(r.text).contains("no conduce") and String(r.text).contains("masilla"), "lo explica y dice lo real que se le parece")
	# más caliente el baño, más hondo quema; más cerca la carne viva, antes duele
	assert_true(float(Bond.weld_report("titanio", 5.0).burnMm) > float(r.burnMm), "el titanio, más caliente, quema más hondo")
	assert_true(float(Bond.weld_report("oro", 2.0).painS) < float(r.painS), "más cerca, antes")
	# a mano: la hondura de 230 °C con la cara a 1064 °C en 1 s (erfc⁻¹ de 198/1032,18) con α = 1e-7 m²/s
	var x := 2.0 * sqrt(1.0e-7) * Bond.erfc_inv((230.0 - 32.0) / (1064.18 - 32.0)) * 1000.0
	assert_near(float(r.burnMm), x, 1e-9, 0.0, "a mano")
	assert_near(Bond.erfc(Bond.erfc_inv(0.3)), 0.3, 1e-6, 0.0, "erfc y su inversa")
	# la carne viva al cabo de un segundo: a 5 mm el calor aún no ha llegado (2·√(α·t) = 0,63 mm); a 0,5 mm, sí
	assert_near(float(r.quickC1s), 32.0, 0.01, 0.0, "a 5 mm, en un segundo, la carne viva sigue a la temperatura del cuerpo")
	assert_true(float(Bond.weld_report("oro", 0.5).quickC1s) > float(CareData.THERMAL.pain_c.value), "a 0,5 mm, en un segundo, ya duele")
	assert_true(String(r.text).contains("en ese segundo la carne viva"), "y lo dice")


# ════════ La pieza llega sin pegar ════════

func test_la_pieza_llega_sin_pegar() -> void:
	var st := _fresh_state()
	assert_true(st.receive_piece(_sheath_fs()), "llega la funda")
	var v := st.view()
	var bv: Dictionary = v.bond
	assert_eq([String(bv.kind), String(bv.material), bool(bv.attached)], ["funda", "acero", false], "en la bandeja, sin pegar")
	assert_false(st.is_reforged(), "la garra sigue siendo de queratina")
	assert_true(float(bv.areaMm2) > 10.0, "con su área pegada (la de la reforja)")
	assert_true(bool(bv.fiction) and String(bv.note).contains("FICCIÓN"), "la funda dura, marcada como ficción")
	assert_eq(String(v.tutorial.process), Tutorial.BOND_PROCESS, "el tutorial salta a «Colocar la pieza»")
	# pasa el tiempo, se lima, y la pieza sigue en la bandeja
	_wait(st, 7200.0, 600.0)
	assert_false(bool(st.view().bond.attached), "sin colocarla, no se pega sola")
	# el bloque de una garra rota: la garra sigue rota
	var st2 := _fresh_state()
	var stump := st2.care.apex_mm() - 6.0
	assert_true(st2.receive_piece(_block_fs(st2, "zafiro", stump)), "llega el bloque")
	assert_true(st2.care.snapshot().claw.block == null, "sin pegar, la garra no lleva el bloque")
	assert_eq(String(st2.view().bond.kind), "bloque", "un bloque")
	# sin pieza, nada
	var st3 := _fresh_state()
	assert_false(st3.receive_piece({ "careSupported": false, "reason": "Aún no hay pieza." }), "sin pieza, no llega nada")
	assert_true((st3.view().bond as Dictionary).is_empty(), "y la vista no la enseña")


# ════════ Preparar, colocar y sujetar ════════

func test_sin_colocarla_y_sujetarla_no_queda_pegada() -> void:
	var st := _fresh_state()
	st.receive_piece(_sheath_fs())
	var j := float(st.view().bond.jointMm)
	_prepare(st, j + 2.0)
	st.bond_adhesive("cianoacrilato")
	st.bond_apply()
	_wait(st, 60.0)
	assert_false(st.bond().attached(), "con el adhesivo puesto, sin colocarla, nada")
	# en la mano pero lejos del muñón (lo dice la escena): apretar no la coloca, y lo dice
	var far := _fresh_state()
	far.receive_piece(_sheath_fs())
	far.bond_adhesive("cianoacrilato")
	far.bond_apply()
	far.bond_grab(true)
	far.bond_aim(30.0, false)
	far.bond_hold(true, -1.0)
	assert_true(far.bond().placed.is_empty() and far.bond().failure == "", "lejos del muñón, no se coloca")
	assert_true(String(far.view().notice).contains("no está sobre el muñón"), "y lo dice: %s" % far.view().notice)
	# tarde: el cianoacrilato ya ha empezado a curar
	st.bond_grab(true)
	st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st.bond_hold(true, 0.0)
	assert_eq(st.bond().failure, "pasada", "colocada tarde: el adhesivo ya no pega")
	st.bond_remove()
	assert_false(st.bond().attached(), "quitada")
	assert_eq(st.bond().cleaner, "", "y hay que volver a preparar")


func test_soltarla_antes_de_que_fije_la_deja_suelta_o_torcida() -> void:
	for secs: float in [3.0, 12.0]:
		var st := _fresh_state()
		st.receive_piece(_sheath_fs())
		_prepare(st, float(st.view().bond.jointMm) + 2.0)
		st.bond_adhesive("cianoacrilato")
		st.bond_apply()
		st.bond_grab(true)
		st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
		st.bond_hold(true, 0.0)
		assert_eq(st.bond().failure, "", "colocada a tiempo y alineada")
		_wait(st, secs)
		st.bond_hold(false)
		assert_true(st.bond().failure in ["suelta", "torcida"], "soltada a los %s s: suelta o torcida (%s)" % [secs, st.bond().failure])
		assert_false(st.bond().attached(), "y no se pega")
		assert_false(st.is_reforged(), "la garra sigue como estaba")
	# torcida al colocarla
	var st2 := _fresh_state()
	st2.receive_piece(_sheath_fs())
	_prepare(st2, float(st2.view().bond.jointMm) + 2.0)
	st2.bond_adhesive("cianoacrilato")
	st2.bond_apply()
	st2.bond_grab(true)
	st2.bond_hold(true, 0.0)
	assert_eq(st2.bond().failure, "torcida", "sin girarla al eje, torcida")
	# movida mientras fija
	var st3 := _fresh_state()
	st3.receive_piece(_sheath_fs())
	_prepare(st3, float(st3.view().bond.jointMm) + 2.0)
	st3.bond_adhesive("cianoacrilato")
	st3.bond_apply()
	st3.bond_grab(true)
	st3.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st3.bond_hold(true, 0.0)
	_wait(st3, 5.0)
	st3.bond_move(1.0)
	assert_eq(st3.bond().failure, "movida", "movida mientras fija")


func test_sujeta_hasta_que_fija_queda_pegada() -> void:
	var st := _fresh_state()
	st.receive_piece(_sheath_fs())
	_prepare(st, float(st.view().bond.jointMm) + 2.0)
	print("    (info) la lija P180 deja Ra %s µm donde va a pegar" % st.bond().ra_um)
	assert_true(st.bond().sanded(), "la lija ha dejado la queratina rugosa")
	assert_false(st.bond().is_wet(st.care.time_s()), "el alcohol se ha evaporado")
	st.bond_adhesive("cianoacrilato")
	st.bond_apply()
	st.bond_grab(true)
	st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st.bond_hold(true, 0.0)
	_wait(st, float(CareData.BOND_TIMES.cianoacrilato.fix_s) + 1.0)
	assert_true(st.bond().attached(), "ha fijado")
	st.bond_hold(false)
	assert_eq(st.bond().failure, "", "y ya se puede soltar")
	assert_true(st.is_reforged(), "la garra lleva la funda")
	assert_eq(String(st.care.snapshot().inlay), "acero", "de acero")
	assert_true(st.history.any(func(e: Array) -> bool: return String(e[1]) == "sheath"), "history lo apunta")


func test_una_garra_sin_preparar_aguanta_menos() -> void:
	var piece := { "kind": "funda", "material": "acero", "name": "Acero", "fiction": true, "note": "", "source": "", "gapMm": 0.1,
		"areaMm2": 30.0, "jointMm": 20.0, "stumpRadiusMm": 0.0, "wallMm": 1.0, "needMm": 0.0, "methods": ["adhesivo"], "fs": {} }
	for adh: String in ["cianoacrilato", "epoxi", "metacrilato", "masilla"]:
		var caps := {}
		for prep: String in ["nada", "mojada", "seca", "lijada"]:
			var b := Bond.new(piece)
			b.set_adhesive(adh)
			var t := 0.0
			if prep != "nada":
				b.clean("clorhexidina", t)
				if prep != "mojada":
					b.dry(10.0, t)
				if prep == "lijada":
					b.sand(2.0)
			b.purge()
			b.apply_adhesive(t)
			b.grab(true)
			b.turn(-b.tilt_deg)
			b.place(t, 0.0)
			b.update(t + 200000.0)
			caps[prep] = float(b.capacity(t + 200000.0, "natural").capN)
		assert_true(float(caps.seca) >= float(caps.mojada), "%s: seca, nunca menos que mojada" % adh)
		assert_true(float(caps.seca) >= float(caps.nada), "%s: limpia y seca, nunca menos que sucia" % adh)
		assert_true(float(caps.lijada) >= float(caps.seca), "%s: lijada, nunca menos" % adh)
		assert_true(float(caps.lijada) >= float(caps.nada), "%s: preparada, nunca menos" % adh)
		print("    (info) %s: sucia %s N, mojada %s, seca %s, lijada %s" % [adh, snapped(float(caps.nada), 0.1), snapped(float(caps.mojada), 0.1), snapped(float(caps.seca), 0.1), snapped(float(caps.lijada), 0.1)])
	# la holgura de más: el cianoacrilato no la llena y no cura
	var wide := piece.duplicate()
	wide["gapMm"] = 0.5
	var bw := Bond.new(wide)
	bw.set_adhesive("cianoacrilato")
	bw.apply_adhesive(0.0)
	bw.grab(true)
	bw.turn(-bw.tilt_deg)
	bw.place(0.0, 0.0)
	var cw := bw.capacity(100000.0, "natural")
	assert_eq(float(cw.capN), 0.0, "holgura de más: no aguanta nada")
	assert_true((cw.reasons as Array).has("holgura"), "y dice por qué")


# ════════ El acrílico y la resina ════════

func test_una_capa_de_acrilico_mas_gruesa_nunca_calienta_menos() -> void:
	var peaks := {}
	for kind: String in ["fina", "gruesa"]:
		var st := _fresh_state()
		var stump := st.care.apex_mm() - 8.0
		st.receive_piece(_block_fs(st, "acrilico", stump))
		assert_eq(st.bond().method, "acrilico", "la prótesis de verdad, con acrílico")
		st.bond_clean("alcohol")
		_wait(st, 40.0)
		st.bond_mix(2.0)
		_wait(st, float(CareData.ACRYLIC_MIX.dough_s) + 5.0)
		st.set_layer_kind(kind)
		st.bond_layer()
		assert_true(st.bond().attached(), "con la primera capa, la garra lleva el acrílico")
		assert_true(st.care.snapshot().claw.block != null, "el bloque, en la garra")
		_wait(st, float(CareData.ACRYLIC_MIX.set_s), 10.0)
		peaks[kind] = float(st.care.snapshot().thermal.peakQuickC)
	assert_true(float(peaks.gruesa) >= float(peaks.fina), "más gruesa, nunca menos calor en la carne viva (%s frente a %s °C)" % [peaks.gruesa, peaks.fina])
	assert_true(float(peaks.gruesa) > float(CareData.THERMAL.bed_c.value), "el fraguado calienta")
	print("    (info) carne viva con una capa fina: %s °C; gruesa: %s °C" % [snapped(float(peaks.fina), 0.01), snapped(float(peaks.gruesa), 0.01)])


func test_el_acrilico_se_aplica_en_masa_y_se_construye_a_capas() -> void:
	var st := _fresh_state()
	var stump := st.care.apex_mm() - 6.0
	st.receive_piece(_block_fs(st, "acrilico", stump))
	st.bond_clean("alcohol")
	_wait(st, 40.0)
	st.bond_mix(2.0)
	st.bond_layer()
	assert_eq(st.bond().layers.size(), 0, "líquida: chorrea")
	_wait(st, float(CareData.ACRYLIC_MIX.work_s) + 5.0)
	st.bond_layer()
	assert_eq(st.bond().layers.size(), 0, "pasado el tiempo de trabajo: ya no se pega")
	var guard := 0
	while not st.bond().done_building() and guard < 20:
		st.bond_mix(2.0)
		_wait(st, float(CareData.ACRYLIC_MIX.dough_s) + 5.0)
		st.set_layer_kind("gruesa")
		st.bond_layer()
		guard += 1
	assert_true(st.bond().done_building(), "a capas hasta el largo")
	var b: Dictionary = st.care.snapshot().claw.block
	assert_near(float(b.builtMm), st.bond().built_mm, 1e-9, 0.0, "la garra lleva lo construido")
	assert_near(st.care.apex_mm(), stump + st.bond().built_mm, 1e-6, 0.0, "y su punta, arriba de la última capa")
	# en fresco no se lima
	st.pick("lima_fina")
	var removed := float(st.care.snapshot().claw.removedMm3)
	st.press_on(st.care.apex_mm() - 0.5)
	st.drag(5.0, 5.0, st.care.apex_mm() - 0.5, FRAME)
	st.release()
	assert_eq(float(st.care.snapshot().claw.removedMm3), removed, "en fresco no se lima")


func test_una_capa_de_resina_con_menos_luz_nunca_queda_mas_curada() -> void:
	var cured := []
	for d: float in [1.0, 10.0, 20.0]:
		var st := _fresh_state()
		var stump := st.care.apex_mm() - 6.0
		st.receive_piece(_block_fs(st, "acrilico", stump))
		st.bond_method("resina")
		st.bond_clean("alcohol")
		_wait(st, 40.0)
		st.set_layer_kind("gruesa")
		st.bond_layer()
		st.bond_lamp("azul", d, 5.0)
		st.bond_lamp_on()
		assert_false(st.bond().lamp_on, "sin los ojos tapados, la lámpara no se enciende")
		st.bond_eyes(true)
		st.bond_lamp_on()
		_wait(st, 6.0)
		assert_false(st.bond().lamp_on, "se apaga sola al acabar su intervalo")
		cured.append(float(st.bond().resin[0].cured))
	for i in range(1, cured.size()):
		assert_true(float(cured[i]) <= float(cured[i - 1]) + 1e-12, "más lejos, nunca más curada")
	# la UV de uñas apenas cura
	var su := _fresh_state()
	su.receive_piece(_block_fs(su, "acrilico", su.care.apex_mm() - 6.0))
	su.bond_method("resina")
	su.bond_layer()
	su.bond_lamp("uv", 1.0, 40.0)
	su.bond_eyes(true)
	su.bond_lamp_on()
	_wait(su, 41.0)
	assert_true(float(su.bond().resin[0].cured) < 0.5, "la UV de uñas deja la resina blanda")


# ════════ Lo que rebosa, el escalón y la prueba ════════

func test_las_rebabas_no_desaparecen_sin_limarlas() -> void:
	var st := _fresh_state()
	st.receive_piece(_sheath_fs())
	var j := float(st.view().bond.jointMm)
	_prepare(st, j + 2.0)
	st.bond_adhesive("cianoacrilato")
	st.bond_apply()
	st.bond_grab(true)
	st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st.bond_hold(true, 0.0)
	_wait(st, 25.0)
	st.bond_hold(false)
	var flash := st.bond().flash_mm3
	assert_true(flash > 0.0, "al apretar, rebosa")
	_wait(st, 86400.0, 3600.0)
	assert_near(st.bond().flash_mm3, flash, 1e-12, 0.0, "con el tiempo no se va")
	st.bond_scrape()
	assert_near(st.bond().flash_mm3, flash, 1e-12, 0.0, "duro, la espátula no lo quita")
	assert_true(float(st.view().bond.stepMm) > float(CareData.BOND_JOINT.step_ok_mm), "y el escalón de la funda se nota")
	# con la lima, sobre la unión, sí
	st.pick("lima_diamante_fina")
	var guard := 0
	while (st.bond().flash_mm3 > 0.0 or float(st.view().bond.stepMm) > float(CareData.BOND_JOINT.step_ok_mm)) and guard < 400:
		st.press_on(j)
		for i in 4:
			st.drag(8.0, 8.0, j, FRAME)
			st.tick(FRAME)
		st.release()
		guard += 1
	print("    (info) %s pasadas; rebaba %s mm³, escalón %s mm" % [guard, st.bond().flash_mm3, st.view().bond.stepMm])
	assert_eq(st.bond().flash_mm3, 0.0, "limada, sin rebaba")
	assert_true(float(st.view().bond.stepMm) <= float(CareData.BOND_JOINT.step_ok_mm), "y sin escalón (%s pasadas)" % guard)
	# la prueba: aguanta
	st.bond_test()
	assert_true(bool(st.bond().test.ok), "aguanta el tirón: %s" % String(st.bond().test.text))


func test_si_no_aguanta_se_despega_y_dice_por_que() -> void:
	var st := _fresh_state()
	st.receive_piece(_sheath_fs())
	# sin preparar, cianoacrilato, y a probar en cuanto fija
	st.bond_adhesive("cianoacrilato")
	st.bond_apply()
	st.bond_grab(true)
	st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
	st.bond_hold(true, 0.0)
	_wait(st, 25.0)
	st.bond_hold(false)
	st.bond_test()
	var t: Dictionary = st.bond().test
	assert_false(bool(t.ok), "no aguanta")
	assert_true((t.reasons as Array).has("sucia") and (t.reasons as Array).has("sin_curar"), "sucia y sin curar: %s" % [t.reasons])
	assert_true(String(t.text).contains("sucia"), "lo dice")
	assert_false(st.is_reforged(), "se ha despegado: la garra, como estaba")


# ════════ El tutorial ════════

func test_con_el_tutorial_apagado_se_llega_al_mismo_resultado() -> void:
	var views := []
	for on: bool in [true, false]:
		var st := _fresh_state()
		st.set_tutorial(on)
		st.receive_piece(_sheath_fs())
		_prepare(st, float(st.view().bond.jointMm) + 2.0)
		st.bond_adhesive("cianoacrilato")
		st.bond_apply()
		st.bond_grab(true)
		st.bond_turn(-float(CareData.BOND_ALIGN.start_tilt_deg))
		st.bond_hold(true, 0.0)
		_wait(st, 25.0)
		st.bond_hold(false)
		_wait(st, 3600.0, 600.0)
		st.bond_test()
		var bv: Dictionary = st.view().bond
		bv.erase("serial")
		views.append(var_to_str(bv) + var_to_str(st.care.snapshot().profile))
	assert_eq(views[0], views[1], "con el tutorial o sin él, lo mismo")


func test_los_pasos_del_tutorial_de_colocar() -> void:
	for m: String in ["adhesivo", "acrilico", "resina"]:
		for kind: String in ["funda", "bloque", "protesis"]:
			for adh: String in Bond.ADHESIVE_IDS:
				var steps := Tutorial.bond_steps("rapaz", m, kind, adh, kind != "funda")
				var ids := {}
				for s: Dictionary in steps:
					assert_false(ids.has(s.id), "%s/%s: id único (%s)" % [m, kind, s.id])
					ids[s.id] = true
					assert_true(String(s.text).length() > 30 and String(s.source).length() > 20, "%s/%s/%s: texto y fuente" % [m, kind, s.id])
					var chk := String(s.check)
					assert_true(chk == "" or Tutorial.BOND_CHECKS.has(chk) or ClawCare.CHECK_KEYS.has(chk), "%s: condición conocida (%s)" % [s.id, chk])
					assert_true(State.short_source(String(s.source)).length() > 3, "%s: fuente legible" % s.id)
	# el paso de limpiar se cumple al limpiar, y el tutorial sigue solo
	var st := _fresh_state()
	st.receive_piece(_sheath_fs())
	var tv: Dictionary = st.view().tutorial
	assert_eq(String(tv.step.id), "pieza", "empieza por la pieza")
	st.tutorial_next()
	assert_eq(String(st.view().tutorial.step.id), "limpiar", "limpiar")
	st.bond_clean("alcohol")
	assert_eq(String(st.view().tutorial.step.id), "secar", "limpia: sigue solo a secar")


# ════════ Los dos arreglos de la cetrería (5k) ════════

func test_cada_garra_del_animal_con_su_forma() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "dedos" })
	var slots := st.slots_view()
	var arcs := {}
	for e: Dictionary in slots:
		var dims := ClawCare.shape_dims("aguila", String(e.digit), false)
		assert_eq(float(e.arcDeg), float(dims.arcDeg), "%s: su arco" % e.key)
		assert_true(float(e.naturalMm) > 0.0 and float(e.baseRadiusMm) > 0.0 and float(e.sectionRatio) > 0.0, "%s: su largo, su base y su sección" % e.key)
		arcs[String(e.digit)] = float(e.arcDeg)
	assert_true(arcs.size() > 1, "las garras de la rapaz no son todas iguales")
	# la de la garra elegida, la misma que su ClawCare
	var sn := st.care.snapshot()
	for e: Dictionary in slots:
		if bool(e.selected):
			assert_near(float(e.naturalMm), float(sn.claw.naturalMm), 1e-9, 0.0, "la elegida, como su ClawCare")
			assert_near(float(e.baseRadiusMm), float(sn.claw.baseRadiusMm), 1e-9, 0.0, "su base, como su ClawCare")
	# lo que aguanta de lado: un bloque romo aguanta miles de veces la natural, y se dice con «×», no con «188327 %»
	assert_eq(State.strength_words(1883.27), "×1883 la natural", "×1883")
	assert_eq(State.strength_words(0.5), "50 % de la natural", "50 %")


# ════════ La base de la hoz del velocirraptor (petición 48) ════════

func test_la_base_de_la_hoz_es_la_del_nucleo_medido_mas_el_estuche() -> void:
	var c := ClawCare.new({ "animal": "velociraptor", "seed": "hoz" })
	var sn := c.snapshot()
	var h := float(Velociraptor.SICKLE.coreHeightMm.value)
	var w := float(Velociraptor.SICKLE.coreWidthMm.value)
	var k := float(sn.claw.sectionRatio)
	var r := float(sn.claw.baseRadiusMm)
	# el alto y el ancho del dibujo (2·r·√k y 2·r/√k) son los del núcleo medido más el estuche (núcleo/estuche de las aves)
	assert_near(2.0 * r * sqrt(k), h / Velociraptor.CORE_TO_SHEATH, 1e-9, 0.0, "el alto de la base: el núcleo más el estuche")
	assert_near(2.0 * r / sqrt(k), w / Velociraptor.CORE_TO_SHEATH, 1e-9, 0.0, "el ancho de la base")
	# nunca más fina que el núcleo óseo ni tan gruesa como la base genérica (45 × 17 mm)
	assert_true(2.0 * r * sqrt(k) > h and 2.0 * r / sqrt(k) > w, "el estuche envuelve el núcleo")
	assert_true(r < 0.15 * float(Velociraptor.ENTRY.reach), "más fina que la base genérica")
	# la física la lee: el perfil empieza en esa base, y la escena (slots_view) también
	assert_near(c.radius_at(0.0), r, 0.05, 0.0, "el perfil de la garra, en la base")
	var st := State.new({ "animal": "velociraptor", "seed": "hoz" })
	assert_near(float(st.slots_view()[0].baseRadiusMm), r, 1e-9, 0.0, "y la escena")
	print("    (info) la hoz: base de %s × %s mm (radio equivalente %s mm; antes, %s mm)" % [snapped(2.0 * r * sqrt(k), 0.1), snapped(2.0 * r / sqrt(k), 0.1), snapped(r, 0.01), snapped(0.15 * float(Velociraptor.ENTRY.reach), 0.1)])
