## Controlador del taller (core/taller/workshop_state.gd): la interfaz solo pinta lo que sale de aquí, y aquí todo
## sale de los módulos de core/taller. Se comprueba que la reproducción no cambia la pieza (×50 da el mismo informe
## que el test de integración), la pausa, el bloque a bloque y el reinicio, los errores didácticos del programa, el
## mando manual, que radial, afiladora y calculadoras devuelven lo del core y que el sonido va en metros.
extends "res://tests/case.gd"

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const Gcode = preload("res://core/taller/gcode.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const Drawing = preload("res://core/taller/drawing.gd")
const Inspection = preload("res://core/taller/inspection.gd")
const Radial = preload("res://core/taller/radial.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")

const FRAME := 1.0 / 30.0


## Corre el programa en marcha con fotogramas de 1/30 s hasta que para (fin o alarma).
func _run_frames(ws: WorkshopState, max_frames: int = 20000) -> int:
	var frames := 0
	while ws.playing and frames < max_frames:
		ws.advance(FRAME)
		frames += 1
	return frames


## El informe de referencia: el mismo cableado que tests/integration/test_taller_pipeline.gd (pasos de 0,05 s).
func _pipeline_report(program: String, stock: String) -> Dictionary:
	var prog: Dictionary = Programs.EXAMPLE_PROGRAMS[program]
	var it := Gcode.interpret_program(prog.text)
	var lathe = Lathe.new(Lathe.STOCKS[stock], "cnc", Cutting.model_callable())
	lathe.set_tool_table(prog.turret)
	lathe.load_moves(it.moves)
	var guard := 0
	while not lathe.is_done() and not lathe.is_halted() and guard < 200000:
		lathe.step(0.05)
		guard += 1
	return Inspection.inspect_part(lathe.profile(), Drawing.get_drawing(stock))


func test_pieza_a_a_x50_da_el_mismo_informe_que_la_integracion() -> void:
	var ws := WorkshopState.new()
	assert_eq(ws.program_id, "pieza_a", "empieza con la pieza A")
	assert_eq(ws.errors().size(), 0, "el programa A no tiene errores")
	ws.set_speed(50.0)
	ws.play()
	assert_true(ws.playing, "en marcha")
	var frames := _run_frames(ws)
	assert_false(ws.playing, "se para solo al terminar")
	assert_true(ws.lathe.is_done() and not ws.lathe.is_halted(), "termina sin alarma grave")
	assert_true(ws.report is Dictionary, "hay informe de inspección")
	# 83 s de ciclo a ×50 con fotogramas de 1/30 s: unos 50 fotogramas
	assert_true(frames > 40 and frames < 70, "fotogramas hasta el final: %d" % frames)
	var want := _pipeline_report("pieza_a", "A")
	var rep: Dictionary = ws.report
	assert_eq(rep.score, want.score, "misma nota que la integración")
	assert_eq(rep.features.size(), want.features.size(), "mismas cotas")
	for i in want.features.size():
		assert_eq(rep.features[i].id, want.features[i].id, "cota %d" % i)
		assert_eq(rep.features[i].measured, want.features[i].measured, "medida de %s" % want.features[i].id)
		assert_eq(rep.features[i].ok, want.features[i].ok, "veredicto de %s" % want.features[i].id)
	for i in want.ra.size():
		assert_eq(rep.ra[i].measured, want.ra[i].measured, "Ra de %s" % want.ra[i].zone)
	assert_true(rep.score >= 9.0, "nota %s" % rep.score)
	assert_true(ws.status.contains("terminado"), "noticia de fin: %s" % ws.status)
	var rd := ws.lathe_readings()
	# Ø50 → Ø30, Ø40 y Ø46 más la cara: unos 45,8 cm³ (el volumen lo cuadra test_taller_pipeline.gd)
	assert_true(rd.done and float(rd.removed_mm3) > 4.0e4, "volumen arrancado %s mm³" % rd.removed_mm3)
	assert_eq(rd.rpm, 0.0, "M30 para el cabezal")


func test_pausa_bloque_a_bloque_y_reinicio() -> void:
	var ws := WorkshopState.new()
	var emitted := [0]
	ws.changed.connect(func() -> void: emitted[0] += 1)
	ws.advance(1.0)
	assert_eq(ws.lathe_state().t_s, 0.0, "sin marcha, el CNC no avanza")
	ws.play()
	ws.advance(0.5)
	var t1 := float(ws.lathe_state().t_s)
	assert_near(t1, 0.5, 0.0, 1e-9, "a ×1, medio segundo")
	ws.pause()
	ws.advance(2.0)
	assert_eq(float(ws.lathe_state().t_s), t1, "en pausa no avanza")
	# Bloque a bloque: se para al empezar otro bloque N
	var n0 := int(ws.lathe_state().block_n)
	ws.step_block()
	var n1 := int(ws.lathe_state().block_n)
	assert_false(ws.playing, "bloque a bloque no deja la marcha puesta")
	assert_true(n1 != n0 and n1 > 0, "otro bloque: N%d → N%d" % [n0, n1])
	ws.step_block()
	assert_true(int(ws.lathe_state().block_n) != n1, "y otro más")
	assert_true(float(ws.lathe_state().t_s) > t1, "el tiempo ha corrido")
	# Velocidad: acotada a la tabla
	ws.set_speed(1000.0)
	assert_eq(ws.speed, WorkshopState.SPEEDS[-1], "×50 como máximo")
	ws.set_speed(0.01)
	assert_eq(ws.speed, WorkshopState.SPEEDS[0], "×0,25 como mínimo")
	# Reinicio: bruto nuevo
	var serial := ws.lathe_serial
	ws.restart()
	assert_eq(float(ws.lathe_state().t_s), 0.0, "reinicio: tiempo a cero")
	assert_eq(float(ws.lathe_state().removed_mm3), 0.0, "reinicio: bruto entero")
	assert_eq(ws.report, null, "reinicio: sin informe")
	assert_eq(ws.lathe_serial, serial + 1, "otro torno para la escena 3D")
	assert_true(emitted[0] >= 5, "cada cambio emite changed (%d)" % emitted[0])


func test_errores_didacticos_del_programa() -> void:
	var ws := WorkshopState.new()
	ws.set_program("errores")
	var errs := ws.errors()
	var want: Array = Programs.EXAMPLE_PROGRAMS["errores"]["errors"]
	assert_eq(errs.size(), want.size(), "tres errores")
	var lines := ws.program_text.split("\n")
	for i in want.size():
		assert_eq(int(errs[i].n), int(want[i].n), "N del error %d" % i)
		assert_eq(str(errs[i].code), str(want[i].code), "código del error %d" % i)
		var line := int(errs[i].line)
		assert_true(line >= 1 and line <= lines.size(), "línea %d dentro del texto" % line)
		assert_true(lines[line - 1].begins_with("N%d " % int(want[i].n)), "la línea %d es la del bloque N%d" % [line, int(want[i].n)])
		assert_true(str(errs[i].message).begins_with("Línea %d (N%d)" % [line, int(want[i].n)]), "mensaje con línea y N: %s" % errs[i].message)
	ws.play()
	assert_false(ws.playing, "con errores no arranca")
	assert_true(ws.status.contains("errores"), "dice por qué: %s" % ws.status)
	# Corregido el primer error (G92 S en vez de G50 S), quedan dos
	ws.set_program_text(ws.program_text.replace("N20 G50 S2500", "N20 G92 S2500"))
	assert_eq(ws.errors().size(), 2, "quedan dos errores")
	# El programa B se interpreta con sus avisos (sin compensación de radio en G68)
	ws.set_program("pieza_b")
	assert_eq(ws.piece, "B", "pieza B")
	assert_eq(ws.errors().size(), 0, "B sin errores")
	assert_true(ws.warnings().any(func(w: Dictionary) -> bool: return str(w.message).contains("G41/G42")), "aviso de G41/G42")
	assert_eq(str(ws.stock().work_id), "al6082_t6", "bruto de aluminio")


## Fase 2: los programas con G42 y la pieza C. El intérprete recibe las tablas de la torreta (la compensación actúa),
## la pieza C trae su bruto y su plano, y las lecturas del torno dicen la pasada de roscado en curso.
func test_programas_de_la_fase_2() -> void:
	var ws := WorkshopState.new()
	for id in WorkshopState.PROGRAM_IDS:
		ws.set_program(id)
		assert_eq(ws.piece, WorkshopState.PROGRAM_PIECE[id], "%s: pieza" % id)
		assert_eq(str(ws.drawing.id), ws.piece, "%s: plano" % id)
		if id != "errores":
			assert_eq(ws.errors().size(), 0, "%s sin errores: %s" % [id, ws.errors()])
	ws.set_program("pieza_a_g42")
	var comp: Array = (ws.interp.moves as Array).filter(func(m: Dictionary) -> bool: return m.has("comp"))
	assert_true(comp.size() > 5, "con la torreta, G42 compensa (%d movimientos)" % comp.size())
	if not comp.is_empty():
		assert_eq(float(comp[0].comp.r), 0.4, "R del corrector D3: el rε de la VNMG 16 04 04")
	ws.set_program("pieza_c")
	assert_eq(str(ws.stock().work_id), "c45e", "bruto C de C45E")
	ws.set_speed(5.0)
	ws.play()
	var seen := {}
	var frames := 0
	while ws.playing and frames < 20000:
		ws.advance(FRAME)
		frames += 1
		var th: Variant = ws.lathe_readings().thread
		if th is Dictionary:
			seen[int(th.pass)] = int(th.passes)
	assert_true(ws.lathe.is_done() and not ws.lathe.is_halted(), "la pieza C termina sin alarma grave")
	assert_true(seen.size() >= 12, "lecturas de roscado de casi todas las pasadas: %s" % [seen.keys()])
	assert_true(seen.values().all(func(v: int) -> bool: return v == 14), "de 14 pasadas")
	assert_true(ws.report is Dictionary, "informe de la pieza C")
	if ws.report is Dictionary:
		assert_true(float(ws.report.score) >= 9.5, "nota %s" % ws.report.score)
	assert_eq(ws.lathe_readings().thread, null, "al acabar ya no hay roscado en curso")


func test_alarma_reset_y_reinicio() -> void:
	var ws := WorkshopState.new()
	# El programa con errores, corregido, acaba con la plaquita de acabado en el bruto: rompe (AP_EXCEEDED)
	ws.set_program("errores")
	var fixed := ws.program_text.replace("N20 G50 S2500", "N20 G92 S2500").replace("R0.5", "R1").replace("G04 X1.5", "G04 K150")
	ws.set_program_text(fixed)
	assert_eq(ws.errors().size(), 0, "corregido")
	ws.set_speed(10.0)
	ws.play()
	_run_frames(ws, 2000)
	assert_true(ws.lathe.is_halted(), "la máquina se detiene")
	assert_false(ws.playing, "y la marcha se quita")
	var al := ws.lathe_alarms()
	assert_true(al.any(func(a: Dictionary) -> bool: return a.code == "AP_EXCEEDED" and a.halt), "alarma AP_EXCEEDED: %s" % [al])
	assert_true(ws.status.begins_with("Alarma"), "noticia de alarma")
	ws.play()
	assert_false(ws.playing, "en alarma no arranca")
	ws.reset_alarm()
	assert_false(ws.lathe.is_halted(), "RESET borra la alarma")
	ws.restart()
	assert_eq(ws.lathe_alarms().size(), 0, "bruto nuevo sin alarmas")


func test_mando_manual() -> void:
	var ws := WorkshopState.new()
	ws.set_lathe_mode("manual")
	assert_eq(str(ws.lathe.machine().name).contains("paralelo"), true, "torno paralelo")
	assert_eq(ws.manual_speeds(), Lathe.MACHINES.manual.speeds, "la caja de velocidades de la ficha")
	ws.set_manual_rpm(745.0)
	ws.manual_spindle("cw")
	ws.advance(1.0)
	var rd := ws.lathe_readings()
	assert_near(float(rd.rpm), 745.0, 0.0, 1e-9, "el cabezal llega a 745 rpm")
	assert_near(float(rd.vc), Cutting.vc_from_rpm(745.0, float(rd.x_diam)), 1e-12, 0.0, "vc en la punta del core")
	# Manivelas: la punta se mueve el paso elegido (X en diámetro)
	var tip0: Vector2 = ws.tool_pose()
	# en manual la punta empieza cerca del bruto (a 5 mm en radio y delante de la cara), no a 40 mm
	var st0: Dictionary = ws.stock()
	assert_near(tip0.x, float(st0.d) / 2.0 + WorkshopState.MANUAL_START_GAP_MM, 1e-6, 0.0, "punta a 5 mm del bruto en X")
	assert_near(tip0.y, float(st0.face_z) + WorkshopState.MANUAL_START_GAP_MM, 1e-6, 0.0, "y a 5 mm de la cara en Z")
	ws.set_jog_step(1.0)
	ws.jog("x", -2)
	ws.advance(1.0)
	assert_near(ws.tool_pose().x, tip0.x - 1.0, 1e-6, 0.0, "dos clics de 1 mm en X (diámetro): 1 mm de radio")
	ws.jog("x", 2)
	ws.advance(1.0)
	ws.set_jog_step(0.1)
	ws.jog("z", -3)
	ws.advance(1.0)
	# (tool_pose es un Vector2, de precisión simple: 1e-6 relativo)
	assert_near(ws.tool_pose().y, tip0.y - 0.3, 1e-6, 0.0, "tres clics de 0,1 mm en Z")
	ws.set_jog_step(0.01)
	ws.jog("x", -10)
	ws.advance(1.0)
	assert_near(ws.tool_pose().x, tip0.x - 0.05, 1e-6, 0.0, "diez clics de 0,01 en X (diámetro): 0,05 de radio")
	# Acercar a la cara con la manivela y cilindrar con el avance automático
	var st: Dictionary = ws.stock()
	ws.lathe.place_tool(float(st.d) / 2.0 - 1.0, float(st.face_z) + 1.0)
	ws.set_manual_feed(0.2)
	ws.manual_auto_feed("z", -1.0)
	ws.advance(3.0)
	var cut := ws.lathe_readings()
	assert_true(float(cut.removed_mm3) > 0.0, "cilindrando arranca material (%s mm³)" % cut.removed_mm3)
	assert_eq(cut.feed, 0.2, "avance de 0,2 mm/vuelta")
	ws.manual_feed_stop()
	# El transversal va a la relación de la caja de su ficha (lo que enseña la interfaz, sin calcularlo ella)
	var mm: Dictionary = Lathe.MACHINES["manual"]
	assert_near(ws.manual_feed_x(), 0.2 * float(mm.feeds_x[1]) / float(mm.feeds_z[1]), 1e-12, 0.0, "avance transversal")
	ws.manual_auto_feed("x", -1.0)
	ws.advance(0.1)
	assert_near(absf(float(ws.lathe_readings().feed)), ws.manual_feed_x(), 1e-12, 0.0, "el avance automático en X lo usa")
	ws.manual_feed_stop()
	ws.set_coolant(true)
	assert_true(ws.lathe_state().coolant, "taladrina")
	ws.set_manual_tool("PDJNR2525M15/DNMG150404-PF")
	assert_eq(ws.lathe_state().tool_id, "PDJNR2525M15/DNMG150404-PF", "otra herramienta")
	ws.measure()
	assert_true(ws.report is Dictionary and ws.report.features.size() > 0, "medir la pieza en manual")
	# Otro material del bruto: bruto nuevo con su tipo (el aspecto 3D y las virutas lo usan)
	ws.set_manual_work("x5crni18_10")
	assert_eq(str(ws.stock().work_kind), "inox", "inoxidable")
	assert_eq(float(ws.lathe_readings().removed_mm3), 0.0, "bruto nuevo")
	# En manual no hay programa que ejecutar
	ws.play()
	assert_false(ws.playing, "play no hace nada en manual")


func test_perfil_para_la_escena_3d_acumula_el_rango_sucio() -> void:
	var ws := WorkshopState.new()
	ws.set_speed(20.0)
	ws.play()
	var lo := 1 << 30
	var hi := -1
	for k in 60:  # varios pasos sin que la escena lea el perfil
		ws.advance(FRAME)
	var p := ws.profile()
	var d: Vector2i = p.dirty
	assert_true(d.x >= 0 and d.y >= d.x, "hay anillos cambiados: %s" % d)
	lo = d.x
	hi = d.y
	var again := ws.profile()
	assert_eq(again.dirty, Vector2i(-1, -1), "leído, el rango se vacía")
	assert_eq(ws.peek_profile().r, p.r, "peek_profile da el mismo perfil")
	assert_true(hi - lo > 10, "el refrentado y el desbaste tocan muchos anillos (%d-%d)" % [lo, hi])
	var band: Dictionary = ws.band
	assert_eq((band.r_min as PackedFloat64Array).size(), (p.r as PackedFloat64Array).size(), "banda del plano en la rejilla del torno")
	var tp: Vector2 = ws.tool_pose()
	assert_eq(tp, Vector2(ws.lathe_state().tip.r, ws.lathe_state().tip.z), "pose de la punta")
	# Un bruto nuevo con la misma rejilla (reinicio) marca todos los anillos: la escena 3D no se queda con la pieza vieja
	ws.restart()
	var n := (ws.peek_profile().r as PackedFloat64Array).size()
	assert_eq(ws.profile().dirty, Vector2i(0, n - 1), "reinicio: todo el perfil sucio para la escena 3D")


func test_entrada_de_sonido_en_metros() -> void:
	var ws := WorkshopState.new()
	ws.set_speed(10.0)
	ws.play()
	var cutting_seen := false
	for k in 300:
		ws.advance(FRAME)
		var raw: Dictionary = ws.lathe.sound_input()
		var inp := ws.lathe_sound_input()
		var mm: Vector3 = raw.tool_pos
		var pos: Vector3 = inp.tool_pos
		# Vector3 es de precisión simple: 1e-6 relativo
		assert_near(pos.x, mm.x / 1000.0, 1e-6, 1e-12, "x = Z/1000")
		assert_eq(pos.y, 0.0, "y = 0 (eje)")
		assert_near(pos.z, mm.y / 1000.0, 1e-6, 1e-12, "z = r/1000")
		assert_true(absf(pos.x) < 1.0 and absf(pos.z) < 1.0, "en metros: %s" % pos)
		assert_eq(inp.speed_droop, 0.0, "el CNC regula el giro")
		if ws.lathe_state().cutting:
			cutting_seen = true
			assert_eq(inp.pc_kw, raw.pc_kw, "cortando, la potencia del torno")
			break
	assert_true(cutting_seen, "llega a cortar")
	ws.pause()
	assert_eq(ws.lathe_sound_input().pc_kw, 0.0, "en pausa los ejes no avanzan: sin corte")
	assert_eq(ws.lathe_chuck_pos_m(), Vector3(-0.059, 0.0, 0.0), "cara de las garras de la pieza A (Z−59)")


func test_radial_devuelve_lo_del_core() -> void:
	var ws := WorkshopState.new()
	assert_eq(ws.radial_result, Radial.cut_panel(ws.radial), "cut_panel del core")
	assert_eq(ws.radial_diameters(), [115.0, 125.0] as Array[float], "el disco fino se hace en 115 y 125 mm")
	ws.set_radial("disc_id", "diamante")
	assert_true(ws.radial_diameters().has(230.0), "el de diamante también en 230 mm")
	ws.set_radial("diameter_mm", 230.0)
	assert_eq(float(ws.radial.rpm), float(Radial.grinder_for(230.0).rpm), "radial de 230 a sus rpm")
	ws.set_radial("disc_id", "fino_1mm")
	assert_eq(float(ws.radial.diameter_mm), 125.0, "el fino no se hace en 230: vuelve a 125")
	ws.set_radial("rpm", 13000.0)
	assert_true(ws.radial_check.over_speed, "13.000 rpm pasan de las marcadas en el disco")
	assert_eq(ws.radial_check, Radial.disc_check({ "disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 13000.0 }), "disc_check del core")
	ws.set_radial("rpm", 11000.0)
	ws.set_radial("panel_id", "boro-22mnb5")
	ws.set_radial("angle_deg", 20.0)
	assert_eq(ws.radial_result, Radial.cut_panel(ws.radial), "cut_panel del core con el pilar de boro inclinado")
	var codes: Array = ws.radial_result.warnings.map(func(w: Dictionary) -> String: return w.code)
	for c in ["pilar_boro", "rescate_airbag", "rescate_alta_tension", "educativo"]:
		assert_true(c in codes, "aviso %s" % c)
	var s1 := ws.radial_sound_input(true)
	assert_eq(s1.process, "grinder", "sonido de radial")
	assert_eq(s1.pc_kw, ws.radial_result.power_kw, "cortando, la potencia del corte")
	assert_eq(ws.radial_sound_input(false).pc_kw, 0.0, "sin cortar, en vacío")
	for id in WorkshopState.RADIAL_PANELS:
		assert_false(Radial.cut_panel({ "panel_id": id }).warnings.any(func(w: Dictionary) -> bool: return w.code == "sin_datos"), "panel %s con datos" % id)


func test_afiladora_devuelve_lo_del_core() -> void:
	var ws := WorkshopState.new()
	assert_eq(ws.sharpen_result, Sharpening.recommend_sharpening(ws.sharpen_request()), "recommend_sharpening del core")
	ws.set_sharpen("kind", "broca")
	assert_eq(ws.sharpen.machine_id, "esmeriladora_banco", "la broca va a la esmeriladora")
	assert_eq(ws.sharpen.steel_id, "m2", "broca de HSS M2")
	assert_eq(ws.sharpen_result, Sharpening.recommend_sharpening(ws.sharpen_request()), "del core también con broca")
	ws.set_sharpen("machine_id", "afiladora_universal")
	assert_eq(float(ws.sharpen.rpm), 0.0, "universal: rpm recomendadas")
	assert_false(ws.sharpen_request().has("rpm"), "sin rpm, el core elige el centro del intervalo")
	ws.set_sharpen("machine_id", "esmeriladora_banco")
	ws.set_sharpen("rpm", 3450.0)
	assert_true(ws.sharpen_result.over_speed, "muela de 200 mm a 3450 rpm: pasa de 35 m/s")
	var inp := ws.sharpen_sound_input()
	assert_eq(inp.process, "sharpener", "sonido de afiladora")
	assert_eq(float(inp.rpm), 3450.0, "a sus rpm")


func test_calculadoras_devuelven_lo_del_core() -> void:
	var ws := WorkshopState.new()
	assert_eq(ws.calc_result, Cutting.turning(ws.calc_request()), "torneado del core")
	assert_true(ws.calc_request().has("machine"), "con la máquina del torno CNC")
	ws.set_calc("f_mm_rev", 0.3)
	assert_eq(ws.calc_result, Cutting.turning(ws.calc_request()), "torneado del core con otro avance")
	ws.set_calc_kind("fresado")
	assert_eq(ws.calc_result, Cutting.milling(ws.calc_request()), "fresado del core")
	ws.set_calc_kind("taladrado")
	assert_eq(ws.calc_result, Cutting.drilling(ws.calc_request()), "taladrado del core")
	ws.set_calc("work_id", "pino")
	assert_eq(ws.calc_result.pc_kw, null, "madera: sin kc no hay potencia")
	assert_true(ws.calc_result.warnings.size() > 0, "y lo dice")


func test_cambiar_de_maquina_para_el_torno() -> void:
	var ws := WorkshopState.new()
	ws.play()
	ws.set_machine("radial")
	assert_eq(ws.machine, "radial", "radial")
	assert_false(ws.playing, "el programa del torno se para al salir")
	ws.set_machine("nada")
	assert_eq(ws.machine, "radial", "máquina desconocida: no cambia")
