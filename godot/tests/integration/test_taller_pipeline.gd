## Integración del taller: el programa Fagor (gcode.gd) mueve el torno (lathe.gd) con el modelo de corte de verdad
## (cutting.gd), y la pieza que sale se mide contra su plano (drawing.gd + inspection.gd). La malla 3D (lathe_mesh.gd)
## y el sonido (machine_sound.gd) se alimentan del mismo torno. Es la cadena que usará la interfaz del taller.
##
## Lo que se espera, y por qué:
##   - Pieza A (C45E): cilindros y longitudes en tolerancia y Ra en el plano. El chaflán 1×45° sale corto: el
##     simulador no compensa el radio de la punta (G41/G42, fase 2) y en una arista a 45° el error es
##     rε·(√2 − 1)·√2 en cada cateto (0,234 mm con rε 0,4): se espera 0,766 mm.
##   - Pieza B (6082-T6): Ø24, Ø36 y cono en tolerancia. El acabado de G68 sin compensación deja el R2 cóncavo con
##     R + rε (2,8 con rε 0,8) y el inicio del cono adelantado: el propio intérprete lo avisa.
##   - Fase 2: las mismas piezas con el acabado compensado con G42 (pieza_a_g42, pieza_b_g42): el chaflán sale de
##     1 mm y el R2 de 2 mm (con la resolución de la rejilla, 0,02 mm), con todas las cotas en tolerancia.
extends "res://tests/case.gd"

const Gcode = preload("res://core/taller/gcode.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const Drawing = preload("res://core/taller/drawing.gd")
const Inspection = preload("res://core/taller/inspection.gd")
const LatheMesh = preload("res://core/taller/lathe_mesh.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")

const STEP_S := 0.05


## Torno con el bruto, la torreta y el programa de una pieza de ejemplo, listo para correr. options: las del
## intérprete (Programs.options(id) para que G41/G42 tengan la tabla de correctores).
func _setup(piece: String, stock: String, options: Dictionary = {}) -> Dictionary:
	var prog: Dictionary = Programs.EXAMPLE_PROGRAMS[piece]
	var it := Gcode.interpret_program(prog.text, options)
	var lathe = Lathe.new(Lathe.STOCKS[stock], "cnc", Cutting.model_callable())
	lathe.set_tool_table(prog.turret)
	lathe.load_moves(it.moves)
	return { "it": it, "lathe": lathe }


## Corre el programa hasta el final; devuelve el pico de potencia y si el modelo de corte tuvo datos siempre.
func _run(lathe) -> Dictionary:
	var pk := 0.0
	var cut_ok := true
	var guard := 0
	while not lathe.is_done() and not lathe.is_halted() and guard < 200000:
		lathe.step(STEP_S)
		var st: Dictionary = lathe.state()
		pk = maxf(pk, float(st.pc_kw))
		cut_ok = cut_ok and bool(st.cut_ok)
		guard += 1
	return { "pc_peak": pk, "cut_ok": cut_ok }


func _feature(rep: Dictionary, id: String) -> Dictionary:
	for f in rep.features:
		if f.id == id:
			return f
	fail("el informe no tiene la cota %s" % id)
	return {}


func _halting(lathe) -> Array:
	return lathe.alarms().filter(func(a: Dictionary) -> bool: return Lathe.ALARMS[a.code]["halt"])


func test_pieza_a_del_programa_fagor_al_plano() -> void:
	var s := _setup("pieza_a", "A")
	var lathe = s.lathe
	assert_eq(s.it.errors.size(), 0, "el programa A se interpreta sin errores")
	var run := _run(lathe)
	assert_true(lathe.is_done() and not lathe.is_halted(), "el programa A termina sin detener la máquina")
	assert_eq(_halting(lathe).size(), 0, "sin alarmas graves: %s" % [lathe.alarms()])
	for a in lathe.alarms():
		assert_eq(a.code, "AP_PEAK", "solo avisos de llegada a un hombro: %s" % a.message)
	assert_true(run.cut_ok, "el modelo de corte tiene datos del C45E con metal duro recubierto")
	assert_true(run.pc_peak > 1.0 and run.pc_peak < float(lathe.machine()["power_kw"]), "potencia de pico %s kW" % run.pc_peak)
	assert_near(lathe.removed_mm3(), lathe.initial_volume_mm3() - lathe.volume_mm3(), 1e-9, 1e-6, "volumen conservado")
	var rep := Inspection.inspect_part(lathe.profile(), Drawing.get_drawing("A"))
	for id in ["A-D30", "A-D40", "A-D46", "A-L20", "A-L40", "A-L55"]:
		var f := _feature(rep, id)
		assert_true(f.get("ok", false), "%s en tolerancia: %s" % [id, f.get("measured")])
	for z in rep.ra:
		assert_true(z.ok, "Ra de %s: %s µm (pide %s)" % [z.zone, z.measured, z.required])
	var ch := _feature(rep, "A-CH1")
	var expected := 1.0 - 0.4 * (sqrt(2.0) - 1.0) * sqrt(2.0)
	assert_near(float(ch.measured), expected, 0.0, 0.03, "chaflán sin compensación de radio")
	assert_true(rep.score >= 9.0, "nota %s" % rep.score)
	# G82 refrenta con la punta teórica hasta X0: el centro de la punta (rε 0,8) se queda a 0,8 del eje y deja un
	# pezón de unos rε de alto (lo mismo que comprueba test_lathe.gd en el torno)
	assert_true(rep.center_nipple != null, "hasta X0 la punta redonda deja pezón")
	if rep.center_nipple != null:
		assert_near(float(rep.center_nipple.height_mm), 0.8, 0.0, 0.2, "pezón de unos rε de alto")


func test_pieza_b_del_programa_fagor_al_plano() -> void:
	var s := _setup("pieza_b", "B")
	var lathe = s.lathe
	assert_eq(s.it.errors.size(), 0, "el programa B se interpreta sin errores")
	assert_true(s.it.warnings.any(func(w: Dictionary) -> bool: return String(w.message).contains("G41/G42")), "el intérprete avisa de que G68 no compensa el radio")
	var run := _run(lathe)
	assert_true(lathe.is_done() and not lathe.is_halted(), "el programa B termina sin detener la máquina")
	assert_eq(lathe.alarms().size(), 0, "sin alarmas: %s" % [lathe.alarms()])
	assert_true(run.cut_ok, "el modelo de corte tiene datos del 6082-T6")
	var rep := Inspection.inspect_part(lathe.profile(), Drawing.get_drawing("B"))
	for id in ["B-D24", "B-D36", "B-CONE", "B-L15", "B-L45"]:
		var f := _feature(rep, id)
		assert_true(f.get("ok", false), "%s en tolerancia: %s" % [id, f.get("measured")])
	var r2 := _feature(rep, "B-R2")
	assert_near(float(r2.measured), 2.0 + 0.8, 0.0, 0.1, "R2 cóncavo sin compensación: R + rε")
	# el programa refrenta hasta X-0.8 contando con rε 0,4, pero la T2 (DNMG 15 04 08) tiene rε 0,8: el centro de la
	# punta se queda a 0,4 del eje y deja un pezón de 0,8 − √(0,8² − 0,4²) = 0,107 mm (pieza_b_g42 refrenta hasta X-1.6)
	assert_true(rep.center_nipple != null, "con rε 0,8, X-0.8 no pasa lo bastante el eje")
	if rep.center_nipple != null:
		assert_near(float(rep.center_nipple.height_mm), 0.8 - sqrt(0.8 * 0.8 - 0.4 * 0.4), 0.0, 0.03, "pezón de 0,107 mm")


func test_pieza_a_con_g42_chaflan_a_cota() -> void:
	var s := _setup("pieza_a_g42", "A", Programs.options("pieza_a_g42"))
	var lathe = s.lathe
	assert_eq(s.it.errors.size(), 0, "el programa A con G42 se interpreta sin errores: %s" % [s.it.errors])
	var run := _run(lathe)
	assert_true(lathe.is_done() and not lathe.is_halted(), "el programa termina sin detener la máquina")
	assert_eq(_halting(lathe).size(), 0, "sin alarmas graves: %s" % [lathe.alarms()])
	assert_true(run.cut_ok)
	var rep := Inspection.inspect_part(lathe.profile(), Drawing.get_drawing("A"))
	for f in rep.features:
		assert_true(f.ok, "%s en tolerancia: %s" % [f.id, f.measured])
	for z in rep.ra:
		assert_true(z.ok, "Ra de %s: %s µm (pide %s)" % [z.zone, z.measured, z.required])
	var ch := _feature(rep, "A-CH1")
	assert_near(float(ch.measured), 1.0, 0.0, 0.02, "chaflán 1×45° con G42: a cota con la resolución de la rejilla")
	assert_true(rep.score >= 9.5, "nota %s" % rep.score)
	assert_eq(rep.center_nipple, null, "sin pezón: G82 refrenta hasta X-2·rε")
	var plain := _setup("pieza_a", "A")
	_run(plain.lathe)
	var rep0 := Inspection.inspect_part(plain.lathe.profile(), Drawing.get_drawing("A"))
	print("    pieza A: chaflán %s mm y nota %s sin G42 · %s mm y nota %s con G42" % [_Js.to_fixed(float(_feature(rep0, "A-CH1").measured), 3), _Js.js_num_str(rep0.score), _Js.to_fixed(float(ch.measured), 3), _Js.js_num_str(rep.score)])


func test_pieza_b_con_g42_y_rpt_radio_y_cono_a_cota() -> void:
	var s := _setup("pieza_b_g42", "B", Programs.options("pieza_b_g42"))
	var lathe = s.lathe
	assert_eq(s.it.errors.size(), 0, "el programa B con G42 se interpreta sin errores: %s" % [s.it.errors])
	assert_false(s.it.warnings.any(func(w: Dictionary) -> bool: return w.code == "no_nose_comp"), "G68 sin H: no hay acabado sin compensar")
	var run := _run(lathe)
	assert_true(lathe.is_done() and not lathe.is_halted(), "el programa termina sin detener la máquina")
	assert_eq(lathe.alarms().size(), 0, "sin alarmas: %s" % [lathe.alarms()])
	assert_true(run.cut_ok)
	var rep := Inspection.inspect_part(lathe.profile(), Drawing.get_drawing("B"))
	for f in rep.features:
		assert_true(f.ok, "%s en tolerancia: %s" % [f.id, f.measured])
	var r2 := _feature(rep, "B-R2")
	assert_near(float(r2.measured), 2.0, 0.0, 0.1, "R2 cóncavo con G42: a cota")
	var l35 := _feature(rep, "B-L35")
	assert_near(float(l35.measured), 35.0, 0.0, 0.05, "el cono empieza en Z-35")
	var ch := _feature(rep, "B-CH05")
	assert_near(float(ch.measured), 0.5, 0.0, 0.02, "chaflán 0,5×45° con G42")
	assert_true(rep.score >= 9.5, "nota %s" % rep.score)
	assert_eq(rep.center_nipple, null, "sin pezón: refrenta hasta X-2·rε con rε 0,8")
	var plain := _setup("pieza_b", "B")
	_run(plain.lathe)
	var rep0 := Inspection.inspect_part(plain.lathe.profile(), Drawing.get_drawing("B"))
	print("    pieza B: R2 %s, inicio del cono %s y nota %s sin G42 · R2 %s, cono %s y nota %s con G42" % [_Js.to_fixed(float(_feature(rep0, "B-R2").measured), 3), _Js.to_fixed(float(_feature(rep0, "B-L35").measured), 3), _Js.js_num_str(rep0.score), _Js.to_fixed(float(r2.measured), 3), _Js.to_fixed(float(l35.measured), 3), _Js.js_num_str(rep.score)])


## Pieza C: tornillo M20×2,5-6g. El acabado va en una subrutina con G42 y la rosca, con G86: el perfil del torno es
## la sección axial de la rosca y la inspección mide Ø exterior, Ø medio, Ø de fondo, paso y rosca completa.
func test_pieza_c_rosca_m20_del_programa_al_plano() -> void:
	var s := _setup("pieza_c", "C", Programs.options("pieza_c"))
	var lathe = s.lathe
	assert_eq(s.it.errors.size(), 0, "el programa C se interpreta sin errores: %s" % [s.it.errors])
	var passes := {}
	var sync := 0
	for m in s.it.moves:
		if m.type == "thread":
			passes[int(m.thread.pass)] = true
			if m.thread.sync:
				sync += 1
	assert_eq(passes.size(), 14, "14 pasadas de roscado (B0.4 E0.05 hasta I − L y el acabado)")
	assert_eq(sync, 14, "cada pasada espera a la misma posición del cabezal")
	var run := _run(lathe)
	assert_true(lathe.is_done() and not lathe.is_halted(), "el programa C termina sin detener la máquina")
	assert_eq(_halting(lathe).size(), 0, "sin alarmas graves: %s" % [lathe.alarms()])
	for a in lathe.alarms():
		assert_eq(a.code, "AP_PEAK", "solo avisos de llegada a un hombro o a un chaflán: %s" % a.message)
	assert_true(run.cut_ok, "el modelo de corte tiene datos del C45E")
	var prof: Dictionary = lathe.profile()
	var passes_seen := {}
	for v in prof.ring_pass:
		passes_seen[int(v)] = true
	assert_true(passes_seen.has(4), "ring_pass 4 en los anillos roscados")
	var rep := Inspection.inspect_part(prof, Drawing.get_drawing("C"))
	for f in rep.features:
		assert_true(f.ok, "%s en tolerancia: %s (de %s a %s)" % [f.id, f.measured, f.lower, f.upper])
	for z in rep.ra:
		assert_true(z.ok, "Ra de %s: %s µm (pide %s)" % [z.zone, z.measured, z.required])
	assert_near(float(_feature(rep, "C-M20-P").measured), 2.5, 0.0, 1e-3, "paso 2,5 mm")
	assert_near(float(_feature(rep, "C-M20-D").measured), 19.79, 0.0, 0.01, "Ø exterior: el torneado a X19.79")
	assert_near(float(_feature(rep, "C-M20-D3").measured), 19.79 - 2.0 * 1.49, 0.0, 0.02, "Ø de fondo = X − 2·I")
	assert_true(rep.score >= 9.5, "nota %s" % rep.score)
	assert_eq(rep.center_nipple, null, "sin pezón: G82 refrenta hasta X-2·rε")
	print("    pieza C: d %s · d2 %s · d3 %s · P %s · rosca completa %s mm · %d surcos · nota %s" % [
		_Js.to_fixed(float(_feature(rep, "C-M20-D").measured), 3), _Js.to_fixed(float(_feature(rep, "C-M20-D2").measured), 3),
		_Js.to_fixed(float(_feature(rep, "C-M20-D3").measured), 3), _Js.to_fixed(float(_feature(rep, "C-M20-P").measured), 4),
		_Js.to_fixed(float(_feature(rep, "C-M20-L").measured), 2), int(rep.thread.full), _Js.js_num_str(rep.score)])


func test_malla_3d_con_el_torno_real() -> void:
	var s := _setup("pieza_a", "A")
	var lathe = s.lathe
	var plan := {}
	var p0: Dictionary = lathe.profile()
	plan = Drawing.tolerance_band(Drawing.get_drawing("A"), p0.z0, p0.dz, p0.r.size())
	var mesh = LatheMesh.new()
	var built: Dictionary = mesh.build(p0, plan)
	var streams := built.duplicate()  # pos, nt y attr, más vertex_count (apply_update lo necesita para las normales)
	var updates := 0
	var guard := 0
	while not lathe.is_done() and not lathe.is_halted() and guard < 200000:
		lathe.step(STEP_S * 4.0)
		guard += 1
		var p: Dictionary = lathe.profile()
		var dirty: Vector2i = p.dirty
		if dirty.x >= 0:
			var upd: Dictionary = mesh.update(p, plan, dirty.x, dirty.y)
			if not upd.is_empty():
				streams = LatheMesh.apply_update(streams, upd)
				updates += 1
	var fresh: Dictionary = LatheMesh.new().build(lathe.profile(), plan)
	assert_true(updates > 10, "la malla se actualiza por rangos mientras corta (%d)" % updates)
	assert_eq(streams.pos, fresh.pos, "posiciones iguales que una malla nueva")
	assert_eq(streams.nt, fresh.nt, "normales y tangentes iguales que una malla nueva")
	assert_eq(streams.attr, fresh.attr, "Ra, pasada y desviación iguales que una malla nueva")


func test_sonido_con_el_torno_real() -> void:
	var s := _setup("pieza_a", "A")
	var lathe = s.lathe
	var cutting_gain := 0.0
	var idle_gain := -1.0
	var guard := 0
	while not lathe.is_done() and not lathe.is_halted() and guard < 200000:
		lathe.step(STEP_S)
		guard += 1
		var inp: Dictionary = lathe.sound_input()
		var pos: Vector3 = inp.tool_pos
		inp.tool_pos = Vector3(pos.x / 1000.0, pos.y / 1000.0, 0.0)  # mm de la pieza → m de la escena
		var fr := MachineSound.frame(inp)
		assert_true(is_finite(float(fr.master_gain)) and is_finite(float(fr.noise.gain)), "marco finito")
		if lathe.state().cutting:
			cutting_gain = maxf(cutting_gain, float(fr.noise.gain))
		elif float(inp.rpm) > 0.0 and idle_gain < 0.0:
			idle_gain = float(fr.noise.gain)
	assert_true(cutting_gain > 0.0, "el corte suena (ruido de banda %s)" % cutting_gain)
	assert_true(idle_gain >= 0.0 and idle_gain < cutting_gain, "girando sin cortar suena menos (%s < %s)" % [idle_gain, cutting_gain])


func test_banda_de_tolerancia_del_plano() -> void:
	var d := Drawing.get_drawing("A")
	var band := Drawing.tolerance_band(d, -60.0, 0.02, int(62.0 / 0.02))
	var at := func(z: float) -> Array:  # [r_min, r_max] (Vector2 es de precisión simple)
		var i := int(round((z + 60.0) / 0.02))
		return [band.r_min[i], band.r_max[i]]
	assert_near(at.call(-10.0)[0], 15.0 - 0.026, 0.0, 1e-9, "Ø30 h9: radio mínimo")
	assert_near(at.call(-10.0)[1], 15.0, 0.0, 1e-9, "Ø30 h9: radio máximo")
	assert_near(at.call(-30.0)[0], 20.0 - 0.031, 0.0, 1e-9, "Ø40 h9")
	assert_near(at.call(-50.0)[1], 23.05, 0.0, 1e-9, "Ø46 ±0,1")
	assert_eq(at.call(1.0)[0], Drawing.NO_PLAN, "delante de la cara no hay plano")
	assert_eq(at.call(-58.0)[0], Drawing.NO_PLAN, "el bruto sin mecanizar no se acota")
