## Núcleo del torno (core/taller/lathe.gd y lathe_tools.gd): volumen arrancado, crestas de avance, determinismo,
## alarmas y rendimiento. El modelo de corte es un Kienzle simple (kc1.1 = 1700 N/mm², mc = 0,25), como pide el
## contrato para los tests del torno. Los programas se escriben aquí en el IR del intérprete, con X en diámetro.
extends "res://tests/case.gd"

const Lathe = preload("res://core/taller/lathe.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")

const D55_04 := "PDJNR2525M15/DNMG150404-PF"
const D55_08 := "PDJNR2525M15/DNMG150408-PM"
const C80_04 := "PCLNR2525M12/CNMG120404-PF"
const C80_04_PM := "PCLNR2525M12/CNMG120404-PM"
const C80_08 := "PCLNR2525M12/CNMG120408-PM"
const V35_04 := "PVJNR2525M16HP/VNMG160404-PF"

var kienzle := Lathe.kienzle_model(1700.0, 0.25)


# ─── ayudas: bloques IR con X en diámetro ───

static func sp(n: int, rpm: float, dir := "cw") -> Dictionary:
	return { "n": n, "type": "spindle", "spindle": { "dir": dir, "rpm": rpm } }


static func css(n: int, vc: float, rpm_max: float) -> Dictionary:
	return { "n": n, "type": "spindle", "spindle": { "dir": "cw", "rpm": 0.0, "css": { "vc": vc, "rpm_max": rpm_max } } }


static func g0(n: int, x: float, z: float) -> Dictionary:
	return { "n": n, "type": "rapid", "to": { "r": x / 2.0, "z": z } }


static func g1(n: int, x: float, z: float, f: float) -> Dictionary:
	return { "n": n, "type": "feed", "to": { "r": x / 2.0, "z": z }, "feed": { "mode": "mmrev", "value": f } }


static func arc(n: int, x: float, z: float, cx: float, cz: float, cw: bool, f: float) -> Dictionary:
	return { "n": n, "type": "arc", "to": { "r": x / 2.0, "z": z }, "arc": { "cw": cw, "center": { "r": cx / 2.0, "z": cz } }, "feed": { "mode": "mmrev", "value": f } }


static func dwell(n: int, s: float) -> Dictionary:
	return { "n": n, "type": "dwell", "dwell_s": s }


static func tool(n: int, id: String) -> Dictionary:
	return { "n": n, "type": "tool", "tool": { "id": id, "offset": 1 } }


static func end(n: int) -> Dictionary:
	return { "n": n, "type": "end" }


## Torno con bruto Ø50 × 85 (25 dentro del plato) y la cara en Z0, sin creces, para medir pasadas limpias.
func lathe(tool_id: String, extra := {}) -> RefCounted:
	var st := { "d": 50.0, "length": 85.0, "clamp": 25.0, "face_z": 0.0 }
	st.merge(extra, true)
	var l: RefCounted = Lathe.new(st, "cnc", kienzle)
	l.set_tool(tool_id)
	return l


## Una pasada de cilindrado de Ø50 a x_to entre Z2 y z_end y retirada en X.
static func pass_program(x_to: float, z_end: float, f: float, rpm := 1000.0) -> Array:
	return [sp(10, rpm), g0(20, x_to, 2.0), g1(30, x_to, z_end, f), g0(40, 60.0, z_end), end(50)]


func ring(l: RefCounted, z: float) -> int:
	var p: Dictionary = l.profile()
	return roundi((z - float(p["z0"])) / float(p["dz"]))


# ─── volumen ───

func test_pasada_de_50_a_46_arranca_el_volumen_del_cilindro() -> void:
	# rε 0,4 y avance fino: el redondeo de la punta en el hombro y las crestas quedan por debajo del 0,1 %
	var l := lathe(C80_04_PM)
	l.load_moves(pass_program(46.0, -30.0, 0.05))
	var res: Dictionary = l.run_to_end(600.0)
	assert_true(res["done"] and not res["halted"], "la pasada termina sin alarmas: %s" % str(res["alarms"]))
	var want := PI / 4.0 * (50.0 * 50.0 - 46.0 * 46.0) * 30.0
	var got: float = l.removed_mm3()
	assert_near(got, want, 1e-3, 0.0, "volumen arrancado de Ø50 a Ø46 en 30 mm")
	print("    volumen Ø50→Ø46 × 30 mm: %s mm³ simulados, %s teóricos (%s %%)" % [js_fixed(got, 2), js_fixed(want, 2), js_fixed(100.0 * (got - want) / want, 3)])


func test_el_volumen_coincide_con_la_geometria_real_del_desbaste() -> void:
	# desbaste real (rε 0,8, f 0,3): cilindro − redondeo de la punta en el hombro (Pappus) − crestas de avance
	var re := 0.8
	var f := 0.3
	var l := lathe(D55_08)
	l.load_moves(pass_program(46.0, -30.0, f, 800.0))
	l.run_to_end(600.0)
	var r := 23.0
	var cyl := PI / 4.0 * (50.0 * 50.0 - 46.0 * 46.0) * 30.0
	var fillet := 2.0 * PI * (r + re * (10.0 - 3.0 * PI) / (12.0 - 3.0 * PI)) * re * re * (1.0 - PI / 4.0)
	var hf := f / 2.0
	var mean_h := re - (hf * sqrt(re * re - hf * hf) + re * re * asin(hf / re)) / f  # altura media de las crestas
	var crests := 2.0 * PI * (r + mean_h / 2.0) * mean_h * (30.0 - re)
	var want := cyl - fillet - crests
	assert_near(l.removed_mm3(), want, 1e-3, 0.0, "volumen = cilindro − redondeo del hombro − crestas")
	assert_true(l.removed_mm3() < cyl, "las crestas y el redondeo dejan material: menos que el cilindro ideal")


func test_el_volumen_se_conserva_el_radio_nunca_crece_y_dirty_lo_cubre() -> void:
	var l := lathe(C80_08, { "face_z": 1.0 })
	l.load_moves(demo_program())
	var v0: float = l.initial_volume_mm3()
	var prev: PackedFloat64Array = (l.profile()["r"] as PackedFloat64Array).duplicate()
	var sum := 0.0
	var grew := 0
	var outside := 0
	for k in 400:
		var st: Dictionary = l.step(0.15)
		sum += float(st["removed_mm3"])
		var p: Dictionary = l.profile()
		var cur: PackedFloat64Array = p["r"]
		var d: Vector2i = p["dirty"]
		if d.x >= 0:
			for i in range(d.x, d.y + 1):
				if cur[i] > prev[i]:
					grew += 1
				prev[i] = cur[i]
		# cada 25 pasos, toda la pieza: lo que ha cambiado fuera de los rangos sucios no se habría redibujado
		if k % 25 == 24 or l.is_done():
			for i in cur.size():
				if cur[i] != prev[i]:
					outside += 1
					prev[i] = cur[i]
		if l.is_done():
			break
	assert_eq(grew, 0, "anillos cuyo radio ha crecido")
	assert_eq(outside, 0, "anillos cambiados fuera del rango dirty")
	assert_true(l.removed_mm3() > 1000.0, "el programa arranca material")
	assert_near(v0 - l.volume_mm3(), l.removed_mm3(), 1e-9, 1e-9, "V0 − V = Σ ΔV")
	assert_near(sum, l.removed_mm3(), 1e-9, 1e-9, "la suma de los pasos es el total")


# ─── crestas de avance ───

func test_las_crestas_miden_rt_de_f2_entre_8_re() -> void:
	for re in [0.4, 0.8]:
		for f in [0.2, 0.3]:
			var l := lathe(D55_04 if re == 0.4 else D55_08)
			l.load_moves(pass_program(48.0, -25.0, f))
			l.run_to_end(600.0)
			var m: Dictionary = l.measure_roughness(-20.0, -5.0)
			var rt_th: float = 1000.0 * f * f / (8.0 * re)
			var ra_th: float = 1000.0 * f * f / (32.0 * re)
			var ra_ring: float = (l.profile()["ring_ra"] as PackedFloat32Array)[ring(l, -12.0)]
			assert_near(m["rt_um"], rt_th, 0.10, 0.0, "Rt con f = %s y rε = %s" % [f, re])
			assert_near(m["ra_um"], ra_th, 0.10, 0.0, "Ra con f = %s y rε = %s" % [f, re])
			assert_near(ra_ring, ra_th, 0.10, 0.0, "ring_ra con f = %s y rε = %s" % [f, re])
			print("    f %s · rε %s: Rt %s µm (f²/8rε = %s) · Ra %s µm (f²/32rε = %s) · ring_ra %s" % [f, re, js_fixed(m["rt_um"], 2), js_fixed(rt_th, 2), js_fixed(m["ra_um"], 3), js_fixed(ra_th, 3), js_fixed(ra_ring, 3)])


func test_con_filo_secundario_poco_inclinado_las_crestas_bajan() -> void:
	# C 80° en 95°: κr' = 5°. Con f > 2·rε·sen κr' el filo secundario recorta la cresta (Boothroyd): Rt < f²/8rε
	var re := 0.4
	var f := 0.3
	var l := lathe(C80_04)
	l.load_moves(pass_program(48.0, -25.0, f))
	l.run_to_end(600.0)
	var m: Dictionary = l.measure_roughness(-20.0, -5.0)
	var want := 1000.0 * rt_minor_edge(f, re, 5.0)
	assert_near(m["rt_um"], want, 0.03, 0.0, "Rt con el filo secundario (fórmula de Boothroyd)")
	assert_true(m["rt_um"] < 0.7 * 1000.0 * f * f / (8.0 * re), "mucho menos que f²/8rε")


## Rt (mm) cuando la cresta la forman el arco de una vuelta y el filo secundario de la siguiente (f > 2·rε·sen κr').
static func rt_minor_edge(f: float, re: float, krm_deg: float) -> float:
	var t := tan(deg_to_rad(krm_deg))
	var c := cos(deg_to_rad(krm_deg))
	if f <= 2.0 * re * sin(deg_to_rad(krm_deg)):
		return re - sqrt(re * re - f * f / 4.0)
	var a := re / c - f * t
	var v := c * c * (-a * t + sqrt(re * re / (c * c) - a * a))
	return re - sqrt(re * re - v * v)


# ─── tiempo y determinismo ───

func test_un_paso_da_el_mismo_perfil_que_mil_pasos() -> void:
	var a := lathe(C80_08, { "face_z": 1.0 })
	var b := lathe(C80_08, { "face_z": 1.0 })
	a.load_moves(demo_program())
	b.load_moves(demo_program())
	a.step(40.0)
	for k in 1000:
		b.step(0.04)
	var pa: Dictionary = a.profile()
	var pb: Dictionary = b.profile()
	var ra: PackedFloat64Array = pa["r"]
	var rb: PackedFloat64Array = pb["r"]
	var worst := 0.0
	for i in ra.size():
		worst = maxf(worst, absf(ra[i] - rb[i]))
	assert_true(a.removed_mm3() > 1000.0, "en 40 s se ha arrancado material")
	assert_true(worst <= 1e-9, "máxima diferencia de radio %s mm" % str(worst))
	assert_near(a.removed_mm3(), b.removed_mm3(), 1e-12, 1e-12, "mismo volumen")
	assert_eq(a.state()["ticks"], b.state()["ticks"], "mismos ticks")


func test_dos_ejecuciones_son_identicas() -> void:
	var runs: Array = []
	for k in 2:
		var l := lathe(C80_08, { "face_z": 1.0 })
		l.load_moves(demo_program())
		l.run_to_end(600.0)
		runs.append([l.profile(), l.state(), l.alarms()])
	for key in ["r", "ring_ra", "ring_pass"]:
		assert_true(runs[0][0][key] == runs[1][0][key], "perfil.%s idéntico" % key)
	for key in ["ticks", "removed_mm3", "energy_kj", "pc_peak_kw", "stamps"]:
		assert_eq(runs[0][1][key], runs[1][1][key], "state.%s idéntico" % key)
	assert_eq(runs[0][2], runs[1][2], "mismas alarmas")


func test_rendimiento_diez_mil_pasos_en_menos_de_dos_segundos() -> void:
	var l := lathe(C80_08, { "face_z": 1.0 })
	l.load_moves(long_program())
	var t0 := Time.get_ticks_usec()
	for k in 10000:
		l.step(1.0 / 60.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var st: Dictionary = l.state()
	print("    rendimiento: 10.000 pasos de 1/60 s (%s s simulados, %d estampados, %s mm³) en %s ms" % [js_fixed(st["t_s"], 1), st["stamps"], js_fixed(st["removed_mm3"], 0), js_fixed(ms, 0)])
	assert_true(int(st["stamps"]) > 3000, "el programa corta de verdad durante la prueba")
	assert_true(ms < 2000.0, "10.000 pasos en %s ms" % js_fixed(ms, 0))


# ─── alarmas ───

func test_g00_que_cruza_la_pieza_en_un_solo_paso_enorme_da_la_alarma() -> void:
	var l := lathe(C80_08)
	l.load_moves([sp(10, 800.0), g0(20, 30.0, 5.0), g0(30, 30.0, -40.0), end(40)])
	l.step(100.0)
	var al: Array = l.alarms()
	assert_eq(al.size(), 1, "una alarma")
	assert_eq(al[0]["code"], "RAPID_IN_MATERIAL")
	assert_eq(al[0]["n"], 30, "la alarma lleva el número de bloque del G00")
	assert_true(l.is_halted(), "la máquina queda detenida")
	# el primer anillo está a dz/2 de la cara: la rejilla fija esa resolución del contacto
	var z: float = l.state()["tip"]["z"]
	assert_true(z >= -0.5 * Lathe.DZ - 0.002 and z < 0.05, "se para al tocar la cara (Z%s)" % str(z))
	assert_near(l.volume_mm3(), l.initial_volume_mm3(), 1e-12, 0.0, "un rápido no arranca material")
	# en diagonal por la esquina, también de un solo paso
	var d := lathe(C80_08)
	d.load_moves([sp(10, 800.0), g0(20, 60.0, 10.0), g0(30, 20.0, -30.0), end(40)])
	d.step(100.0)
	assert_eq(d.alarms().size(), 1, "diagonal: una alarma")
	assert_eq(d.alarms()[0]["code"], "RAPID_IN_MATERIAL")


func test_cada_alarma_lleva_su_n() -> void:
	var cases := {
		"RAPID_IN_MATERIAL": [C80_08, {}, [sp(10, 800.0), g0(20, 30.0, 5.0), g0(37, 30.0, -20.0), end(90)], 37],
		"AP_EXCEEDED": [C80_08, {}, [sp(10, 800.0), g0(20, 36.0, 2.0), g1(41, 36.0, -10.0, 0.2), end(90)], 41],
		"FLANK_RUB": [C80_08, {}, [sp(10, 800.0), g0(20, 50.0, 2.0), g1(30, 50.0, 0.0, 0.2), g1(43, 44.0, -5.0, 0.2), g0(50, 60.0, -5.0), end(90)], 43],
		# una sola vuelta por encima de la ap máxima (como al llegar a un hombro): la plaquita V de acabado (ap máx. 1,5 mm)
		# entra 0,3 mm en la cara a Ø44 (3 mm de altura): una sola vuelta completa de contacto y se retira
		"AP_PEAK": [V35_04, {}, [sp(10, 800.0), g0(20, 44.0, 2.0), g1(42, 44.0, -0.3, 0.2), g0(43, 46.0, 2.0), end(90)], 42],
		"CHUCK_COLLISION": [C80_08, {}, [sp(10, 800.0), g0(20, 46.0, 2.0), g1(44, 46.0, -70.0, 0.3), end(90)], 44],
		"TAILSTOCK_COLLISION": [C80_08, { "tailstock": true }, [sp(10, 800.0), g0(20, 54.0, 0.0), g1(45, 0.0, 0.0, 0.2), end(90)], 45],
		"HOLDER_COLLISION": [holder_test_tool(), {}, [sp(10, 800.0), g0(20, 54.0, -20.0), g1(46, 30.0, -20.0, 0.1), end(90)], 46],
		"X_NEGATIVE": [C80_08, {}, [sp(10, 800.0), g0(20, 54.0, 0.0), g1(47, -3.0, 0.0, 0.2), end(90)], 47],
		"FEED_SPINDLE_STOPPED": [C80_08, {}, [g0(20, 54.0, 2.0), g1(48, 46.0, -10.0, 0.2), end(90)], 48],
		"OVERLOAD": [C80_08, {}, [css(10, 250.0, 3000.0), g0(20, 40.0, 2.0), g1(49, 40.0, -30.0, 0.5), end(90)], 49],
		"TOOL_UNKNOWN": [C80_08, {}, [sp(10, 800.0), { "n": 51, "line": 51, "type": "tool", "tool": { "id": "T9", "offset": 9 } }, g0(60, 60.0, 5.0), end(90)], 51],
		"RPM_LIMIT": [C80_08, {}, [sp(51, 5000.0), g0(20, 60.0, 10.0), end(90)], 51],
	}
	for code in Lathe.ALARMS:
		assert_true(cases.has(code), "hay un caso para %s" % code)
	for code in cases:
		var c: Array = cases[code]
		var l := lathe("") if c[0] is Dictionary else lathe(c[0], c[1])
		if c[0] is Dictionary:
			l = lathe(C80_08, c[1])
			l.set_tool(c[0])
		l.load_moves(c[2])
		l.run_to_end(600.0)
		var found: Array = l.alarms().filter(func(a: Dictionary) -> bool: return a["code"] == code)
		assert_eq(found.size(), 1, "%s aparece una vez" % code)
		if found.size() == 1:
			assert_eq(found[0]["n"], c[3], "%s lleva el N del bloque" % code)
			assert_true(str(found[0]["message"]).length() > 20 and str(found[0]["message"]).begins_with("N%d" % c[3]), "%s explica en español con su N: %s" % [code, found[0]["message"]])
			assert_eq(l.is_halted(), Lathe.ALARMS[code]["halt"], "%s detiene la máquina solo si es grave" % code)


## Herramienta de prueba: la C 80° de desbaste con ap ilimitado, para que al profundizar en radial choque la cabeza del
## portaherramientas contra el resto de la pieza antes de que se rompa la plaquita.
static func holder_test_tool() -> Dictionary:
	var t := LatheTools.tool(C80_08)
	t["ap_max_mm"] = 1000.0
	t["id"] = "prueba/sin-limite-de-ap"
	return t


func test_talonar_es_un_aviso_y_la_rampa_permitida_no_avisa() -> void:
	# D 55° en 93°: κr' = 32°, rampa máxima 30°; 25° no talona y 40° sí
	for ramp in [25.0, 40.0]:
		var l := lathe(D55_08)
		var dz := 2.0 / tan(deg_to_rad(ramp))
		l.load_moves([sp(10, 800.0), g0(20, 50.0, 2.0), g1(30, 50.0, 0.0, 0.2), g1(40, 46.0, -dz, 0.2), g0(50, 60.0, -dz), end(90)])
		l.run_to_end(600.0)
		var rub: Array = l.alarms().filter(func(a: Dictionary) -> bool: return a["code"] == "FLANK_RUB")
		assert_eq(rub.size(), 0 if ramp < 30.0 else 1, "rampa de %s°" % ramp)
		assert_false(l.is_halted(), "talonar no detiene la máquina")


# ─── cabezal, potencia y herramientas ───

func test_velocidad_de_corte_constante() -> void:
	var l := lathe(C80_08)
	l.load_moves([css(10, 200.0, 2500.0), g0(20, 40.0, 5.0), dwell(30, 3.0)])
	l.run_to_end(60.0)
	assert_near(l.state()["spindle"]["rpm"], 1000.0 * 200.0 / (PI * 40.0), 1e-9, 0.0, "n = 1000·vc/(π·D) en Ø40")
	var small := lathe(C80_08)
	small.load_moves([css(10, 200.0, 2500.0), g0(20, 10.0, 5.0), dwell(30, 3.0)])
	small.run_to_end(60.0)
	assert_near(small.state()["spindle"]["rpm"], 2500.0, 1e-12, 0.0, "tope G92 en diámetros pequeños")
	assert_eq(small.alarms().size(), 0, "el tope G92 no es una alarma")
	var nolimit := lathe(C80_08)
	nolimit.load_moves([css(12, 200.0, 0.0), g0(20, 10.0, 5.0), dwell(30, 3.0)])
	nolimit.run_to_end(60.0)
	assert_near(nolimit.state()["spindle"]["rpm"], 3000.0, 1e-12, 0.0, "sin G92 manda el máximo de la máquina")
	assert_eq(nolimit.alarms().size(), 1, "y avisa")


func test_la_potencia_sale_del_volumen_arrancado_en_cada_vuelta() -> void:
	# Pc = kc·ΔV/Δt con ΔV = π/4·(D² − d²)·f por vuelta. La fórmula de Sandvik, vc·ap·f·kc/60000 con vc en el
	# diámetro mecanizado, da lo mismo salvo el factor d/((D + d)/2) (toma el diámetro final, no el medio).
	var l := lathe(C80_08)
	var f := 0.3
	var ap := 2.0
	var n := 1000.0
	l.load_moves([sp(10, n), g0(20, 46.0, 2.0), g1(30, 46.0, -40.0, f)])
	l.step(8.0)
	var st: Dictionary = l.state()
	assert_true(st["cutting"], "está cortando")
	var h := f * sin(deg_to_rad(95.0))
	var kc := 1700.0 * pow(h, -0.25)
	var exact := kc * PI / 4.0 * (50.0 * 50.0 - 46.0 * 46.0) * f * n / 60.0 * 1e-6
	var sandvik := PI * 46.0 * n / 1000.0 * ap * f * kc / 60000.0
	assert_near(st["pc_kw"], exact, 0.01, 0.0, "Pc = kc·ΔV/Δt")
	assert_near(st["pc_kw"] / sandvik, 48.0 / 46.0, 0.01, 0.0, "relación con la fórmula de Sandvik: diámetro medio / mecanizado")
	# ap equivalente por volumen: la programada menos la altura media de las crestas que quedan (≈ f²/24rε)
	var re := 0.8
	var hf := f / 2.0
	var mean_h := re - (hf * sqrt(re * re - hf * hf) + re * re * asin(hf / re)) / f
	assert_near(st["ap_mm"], ap - mean_h, 1e-3, 0.0, "ap equivalente de la vuelta")
	assert_near(st["contact_mm"], ap, 1e-4, 0.0, "extensión del contacto = ap en régimen")
	assert_near(st["kc"], kc, 1e-9, 0.0, "kc del modelo inyectado con h = f·sen κr")


## Sin estado compartido (CONTRATOS.md, rendimiento): cuatro tornos con el mismo programa, a la vez en el
## WorkerThreadPool, dejan exactamente la misma pieza que uno en serie (sin static var mutables en lathe.gd).
func test_tornos_en_varios_hilos_iguales_que_en_serie() -> void:
	var moves := [
		{ "n": 10, "type": "tool", "tool": { "id": "T1" } },
		{ "n": 20, "type": "spindle", "spindle": { "dir": "cw", "rpm": 1200.0, "css": null } },
		{ "n": 30, "type": "rapid", "to": { "r": 24.0, "z": 2.0 } },
		{ "n": 40, "type": "feed", "to": { "r": 24.0, "z": -15.0 }, "feed": { "mode": "mmrev", "value": 0.25 } },
		{ "n": 50, "type": "feed", "to": { "r": 26.0, "z": -15.0 }, "feed": { "mode": "mmrev", "value": 0.25 } },
		{ "n": 60, "type": "rapid", "to": { "r": 26.0, "z": 2.0 } },
		{ "n": 70, "type": "thread", "to": { "r": 23.0, "z": -10.0 }, "feed": { "mode": "mmrev", "value": 2.5 },
			"thread": { "pitch": 2.5, "start_deg": 0.0, "sync": true, "pass": 1, "passes": 1, "depth": 1.0, "total": 1.0, "kind": "G33", "infeed_deg": 0.0 }, "pass": 4 },
		{ "n": 80, "type": "rapid", "to": { "r": 30.0, "z": -10.0 } },
		{ "n": 90, "type": "end" },
	]
	var run := func() -> Dictionary:
		var l := Lathe.new(Lathe.STOCKS["A"], "cnc", Lathe.kienzle_model(1700.0, 0.25))
		l.set_tool_table({ "1": C80_08 })
		l.load_moves(moves)
		l.run_to_end(120.0)
		var prof: Dictionary = l.profile()
		return { "r": prof.r, "ra": prof.ring_ra, "pass": prof.ring_pass, "t": l.state().t_s, "removed": l.removed_mm3() }
	var ref: Dictionary = run.call()
	assert_true(float(ref.removed) > 0.0 and (ref.pass as PackedByteArray).has(4), "corta y rosca")
	var outs: Array = [null, null, null, null]
	var lock := Mutex.new()
	var task := func(i: int) -> void:
		var got: Dictionary = run.call()
		lock.lock()
		outs[i] = got
		lock.unlock()
	var gid := WorkerThreadPool.add_group_task(task, outs.size())
	WorkerThreadPool.wait_for_group_task_completion(gid)
	for i in outs.size():
		assert_true(same(outs[i], ref), "hilo %d: la misma pieza, la misma rugosidad y el mismo tiempo" % i)


func test_catalogo_de_herramientas() -> void:
	for id in LatheTools.ids():
		var t := LatheTools.tool(id)
		assert_false(t.is_empty(), "%s existe" % id)
		assert_true(str(t["source"]).length() > 20 and ["primary", "secondary", "estimate"].has(t["quality"]), "%s tiene fuente y calidad" % id)
		for k in t["qualities"]:
			assert_true(["primary", "secondary", "estimate"].has(t["qualities"][k]), "%s.%s calidad válida" % [id, k])
		if t["shape"] != "R":
			assert_near(t["kr_minor_deg"], 180.0 - float(t["kr_deg"]) - float(t["eps_deg"]), 1e-12, 1e-12, "%s: κr' = 180° − κr − εr" % id)
			assert_near(t["copy_angle_max_deg"], maxf(float(t["kr_minor_deg"]) - 2.0, 0.0), 1e-12, 1e-12, "%s: rampa máxima = κr' − 2°" % id)
		var ap: Array = t["ap_mm"]
		assert_true(ap[0] <= ap[1] and ap[1] <= ap[2] and t["ap_max_mm"] == ap[2], "%s: ap mín ≤ rec ≤ máx" % id)
		# la cabeza del portaherramientas queda por encima de la envolvente de corte
		var g := LatheTools.cut_geometry(t)
		var poly: PackedFloat64Array = t["holder_poly"]
		var c: Array = t["center"]  # centro de la punta respecto a la punta teórica: (rε, rε), o (0, rε) al roscar
		for k in range(0, poly.size(), 2):
			var u: float = poly[k] - float(c[0])
			var e := LatheTools.env(g, u)
			if is_finite(e):
				assert_true(poly[k + 1] - float(c[1]) >= e - 1e-9, "%s: vértice de la cabeza por encima del filo" % id)
	for s in LatheTools.SHAPES:
		assert_true(LatheTools.SHAPES[s].has("source") and LatheTools.SHAPES[s]["quality"] == "primary", "forma %s con fuente" % s)
	var c80 := LatheTools.tool(C80_08)
	assert_eq(c80["kr_minor_deg"], 5.0, "C 80° en 95°: κr' = 5°")
	assert_eq(LatheTools.tool(D55_08)["copy_angle_max_deg"], 30.0, "D 55° en 93°: rampa máxima 30°")
	assert_eq(LatheTools.tool("PVJNR2525M16HP/VNMG160408-PM")["copy_angle_max_deg"], 50.0, "V 35° en 93°: rampa máxima 50°")
	assert_eq(LatheTools.tool("PDJNR2525M15/DNMG150408-PM")["ap_max_mm"], 6.0, "DNMG 15 04 08-PM: ap máx. 6 mm (Sandvik)")
	for re in [0.2, 0.4, 0.8, 1.2]:
		assert_false(LatheTools.find("D", re).is_empty(), "hay rómbica 55° con rε %s" % re)


func test_riesgo_de_vibracion_es_una_estimacion() -> void:
	var short := Lathe.chatter_risk(60.0, 50.0, 2.0, 0.8)
	var long := Lathe.chatter_risk(200.0, 40.0, 2.0, 0.8)
	var held := Lathe.chatter_risk(200.0, 40.0, 2.0, 0.8, 95.0, true)
	var nose := Lathe.chatter_risk(120.0, 40.0, 0.3, 1.2)
	var deep := Lathe.chatter_risk(120.0, 40.0, 3.0, 1.2)
	assert_eq(short["quality"], "estimate")
	assert_eq(short["level"], "bajo", "pieza corta (L/D 1,2)")
	assert_eq(long["level"], "alto", "L/D 5 sin contrapunto")
	assert_true(held["risk"] < long["risk"], "el contrapunto lo reduce")
	assert_true(nose["risk"] > deep["risk"], "ap menor que rε: más fuerza radial")
	assert_true(held["mode_hz"] > long["mode_hz"], "con contrapunto el modo sube")
	assert_true(str(long["explanation"]).length() > 20 and str(long["source"]).length() > 20, "explica y cita")


# ─── manual, arcos y refrentado ───

func test_torno_manual() -> void:
	var l: RefCounted = Lathe.new({ "d": 50.0, "length": 85.0, "clamp": 25.0, "face_z": 0.0 }, "manual", kienzle)
	l.set_tool(C80_08)
	l.place_tool(30.0, 3.0)
	l.jog("x", -14.0)  # X en diámetro: baja 7 mm de radio, hasta r = 23
	l.run_to_end(60.0)
	assert_near(l.state()["tip"]["r"], 23.0, 1e-12, 0.0, "la manivela de X va en diámetro")
	l.set_spindle(1000.0, "cw")
	assert_near(l.state()["spindle"]["rpm_goal"], 1074.0, 0.0, 0.0, "la caja da la velocidad más cercana")
	l.step(2.0)
	l.set_feed("z", -0.2, true)
	l.step(30.0)
	l.set_feed("z", 0.0, false)
	var zt: float = l.state()["tip"]["z"]
	assert_true(zt < -20.0, "el carro ha avanzado hacia el plato (Z%s)" % str(zt))
	assert_near(l.radius_at(-10.0), 23.0, 0.0, 0.01, "el avance automático cilindra")
	l.step(1.0)
	var stopped: Dictionary = l.state()
	assert_eq(stopped["motion"], "", "desembragado, el carro se para")
	# con el cabezal parado la manivela se detiene al tocar la pieza, sin alarma
	var t: RefCounted = Lathe.new({ "d": 50.0, "length": 85.0, "clamp": 25.0, "face_z": 0.0 }, "manual", kienzle)
	t.set_tool(C80_08)
	t.place_tool(23.0, 5.0)
	t.jog("z", -20.0)
	t.run_to_end(60.0)
	assert_eq(t.alarms().size(), 0, "tocar la cara es el toque de referencia")
	assert_true(absf(float(t.state()["tip"]["z"])) < 0.01, "se para en la cara")
	# avance automático con el cabezal parado
	t.set_feed("z", -0.2, true)
	assert_eq(t.alarms().size(), 1, "avance con el cabezal parado")
	assert_eq(t.alarms()[0]["code"], "FEED_SPINDLE_STOPPED")


func manual_lathe() -> RefCounted:
	var l: RefCounted = Lathe.new({ "d": 50.0, "length": 85.0, "clamp": 25.0, "face_z": 0.0 }, "manual", kienzle)
	l.set_tool(C80_08)
	return l


func test_parar_el_cabezal_a_mitad_de_la_manivela_no_atraviesa_la_pieza() -> void:
	# la manivela corta mientras el cabezal gira (también frenando) y, parado, se queda al tocar: nunca pasa sin cortar
	# a 300 mm/min y 1074 rpm la manivela da 0,28 mm/rev; al frenar el cabezal el avance por vuelta crece y, pasado el
	# doble del máximo de la plaquita, deja de cortar y se para al tocar
	var l := manual_lathe()
	l.set_spindle(1074.0, "cw")
	l.place_tool(24.5, 5.0)
	l.step(2.0)
	l.jog("z", -20.0)
	l.step(2.0)
	l.set_spindle(0.0, "stop")
	l.step(8.0)
	var zt: float = l.state()["tip"]["z"]
	assert_true(zt > -15.0 + 1e-6, "no llega al final de la manivela a través del material (Z%s)" % str(zt))
	assert_eq(l.alarms().size(), 0, "sin alarmas")
	var worst := 0.0
	for k in 40:
		var z := zt + 1.0 + (-1.0 - (zt + 1.0)) * k / 39.0
		worst = maxf(worst, l.radius_at(z) - 24.5)
	# lo que queda son las crestas del frenado: como mucho las de f = 2·fn máx = 1 mm/rev con rε 0,8 (0,175 mm)
	var crest := 0.8 - sqrt(0.64 - 0.25)
	assert_true(worst <= crest + 1e-9, "todo lo que ha recorrido la punta está cortado (exceso %s mm, cresta máx. %s)" % [str(worst), str(crest)])
	assert_near(l.radius_at(zt - 1.0), 25.0, 0.0, 1e-12, "delante de la herramienta la pieza sigue entera")


func test_clics_de_manivela_seguidos_se_suman() -> void:
	var l := manual_lathe()
	l.place_tool(30.0, 5.0)
	l.jog("x", -2.0)
	l.jog("x", -2.0)
	l.run_to_end(60.0)
	assert_near(l.state()["tip"]["r"], 28.0, 1e-12, 0.0, "dos clics de −2 en X (diámetro) bajan 2 mm de radio")
	l.jog("z", -1.0)
	l.step(0.05)
	l.jog("z", -1.0)
	l.run_to_end(60.0)
	assert_near(l.state()["tip"]["z"], 3.0, 1e-12, 0.0, "un clic durante otro parte del destino del primero")


func test_tras_un_choque_a_mitad_de_corte_se_puede_retirar() -> void:
	# la pasada choca con las garras: la herramienta queda tocando las garras y metida hasta una vuelta en el material
	# sin cortar. Tras RESET, retirarse no cuenta como choque: solo penetrar más allá de ese solape
	var l := lathe(C80_08)
	l.load_moves([sp(10, 800.0), g0(20, 46.0, 2.0), g1(44, 46.0, -70.0, 0.3), end(90)])
	l.run_to_end(600.0)
	assert_true(l.is_halted() and l.alarms()[0]["code"] == "CHUCK_COLLISION", "choca con las garras")
	var st: Dictionary = l.state()
	var d0: PackedFloat64Array = l._static_depth(st["tip"]["r"], st["tip"]["z"])
	assert_true(d0[0] > 0.0 or d0[1] > 0.0, "queda solapada (material %s, garras %s)" % [str(d0[0]), str(d0[1])])
	l.reset()
	l.load_moves([g0(100, 120.0, float(st["tip"]["z"])), g0(110, 120.0, 10.0), end(120)])
	l.run_to_end(60.0)
	assert_eq(l.alarms().size(), 1, "retirar en X y luego en Z no da alarma: %s" % str(l.alarms()))
	assert_near(l.state()["tip"]["z"], 10.0, 1e-12, 0.0, "se ha retirado")
	# pero seguir hacia el plato sí es un choque
	l.load_moves([g0(130, 46.0, 2.0), g0(140, 46.0, -70.0), end(150)])
	l.run_to_end(60.0)
	assert_eq(l.alarms()[-1]["code"], "RAPID_IN_MATERIAL", "volver a entrar en rápido sí es un choque")


func test_alarma_manual_repetida_tras_reset() -> void:
	var l := manual_lathe()
	l.place_tool(30.0, 5.0)
	l.set_feed("z", -0.2, true)
	assert_eq(l.alarms().size(), 1, "avance con el cabezal parado")
	l.reset()
	l.set_feed("z", -0.2, true)
	assert_eq(l.alarms().size(), 2, "tras RESET, el mismo error vuelve a dar la alarma")
	assert_true(l.is_halted(), "y detiene")


func test_arcos_g02_y_g03_siguen_su_centro() -> void:
	# redondeo cóncavo R2 (G02) entre Ø30 y la cara del hombro en Z−20, en un bruto de Ø36
	var l := lathe(D55_08, { "d": 36.0 })
	l.load_moves([sp(10, 1200.0), g0(20, 34.0, 2.0), g1(30, 34.0, -24.0, 0.1), g0(40, 40.0, -24.0), g0(45, 40.0, 2.0), g0(50, 30.0, 2.0), g1(60, 30.0, -18.0, 0.05), arc(70, 34.0, -20.0, 34.0, -18.0, true, 0.05), g1(80, 40.0, -20.0, 0.05), g0(90, 44.0, 5.0), end(99)])
	var res: Dictionary = l.run_to_end(600.0)
	assert_eq(res["alarms"].size(), 0, "sin alarmas: %s" % str(res["alarms"]))
	# la punta recorre el arco de centro (r 17, z −18) y radio 2; el material queda en el círculo de radio 2 + rε
	# centrado en el centro del arco desplazado (rε, rε)
	var re := 0.8
	var worst := 0.0
	var p: Dictionary = l.profile()
	for zz in [-19.6, -19.2, -18.8, -18.4]:
		var z: float = float(p["z0"]) + ring(l, zz) * float(p["dz"])  # z real del anillo (la pendiente aquí llega a 1,7)
		var r_want := (17.0 + re) - sqrt(pow(2.0 + re, 2.0) - pow(z - (-18.0 + re), 2.0))
		worst = maxf(worst, absf(l.radius_at(z) - r_want))
	assert_true(worst < 0.002, "el perfil del radio sigue el arco (error %s mm)" % str(worst))


func test_refrentar_hasta_x0_deja_pezon_y_hasta_menos_2re_no() -> void:
	for x_end in [0.0, -1.6]:
		var l := lathe(C80_08, { "face_z": 1.0 })
		# se retira primero en X (con pezón, retirar en Z lo arrastraría) y luego en Z
		l.load_moves([sp(10, 1000.0), g0(20, 54.0, 0.0), g1(30, x_end, 0.0, 0.2), g0(40, x_end + 4.0, 0.0), g0(45, x_end + 4.0, 2.0), end(50)])
		var res: Dictionary = l.run_to_end(600.0)
		assert_eq(res["alarms"].size(), 0, "refrentado sin alarmas: %s" % str(res["alarms"]))
		var pip := 0.0
		for z in [0.3, 0.6, 0.9]:
			pip = maxf(pip, l.radius_at(z))
		if x_end == 0.0:
			assert_true(pip > 0.0, "hasta X0 queda un pezón en el centro (r %s mm)" % str(pip))
		else:
			assert_eq(pip, 0.0, "hasta X−2·rε la cara queda limpia")
		assert_near(l.radius_at(-0.5), 25.0, 0.0, 1e-12, "la pieza bajo la cara no se toca")
	# con el pezón, retirar en rápido en Z lo arrastra: es un rápido contra material
	var d := lathe(C80_08, { "face_z": 1.0 })
	d.load_moves([sp(10, 1000.0), g0(20, 54.0, 0.0), g1(30, 0.0, 0.0, 0.2), g0(40, 0.0, 2.0), end(50)])
	d.run_to_end(600.0)
	assert_eq(d.alarms().size(), 1, "retirar en Z sobre el pezón")
	assert_eq(d.alarms()[0]["code"], "RAPID_IN_MATERIAL")


# ─── contrato del perfil ───

func test_perfil_del_contrato_y_rango_sucio() -> void:
	var l := lathe(C80_08)
	var p0: Dictionary = l.profile()
	for k in ["z0", "dz", "r", "ring_ra", "ring_pass", "dirty"]:
		assert_true(p0.has(k), "clave %s" % k)
	assert_true(p0["r"] is PackedFloat64Array and p0["ring_ra"] is PackedFloat32Array and p0["ring_pass"] is PackedByteArray and p0["dirty"] is Vector2i, "tipos del contrato")
	assert_eq(p0["dz"], 0.02)
	assert_eq(p0["r"].size(), 4250, "85 mm en anillos de 0,02 mm")
	assert_near(p0["z0"], -85.0 + 0.01, 1e-12, 1e-12, "z del primer anillo (su centro)")
	assert_eq(p0["dirty"], Vector2i(-1, -1), "nada cambiado al principio")
	l.load_moves(pass_program(46.0, -10.0, 0.3))
	l.run_to_end(600.0)
	var p1: Dictionary = l.profile()
	var d: Vector2i = p1["dirty"]
	assert_true(d.x >= 0 and d.x <= ring(l, -10.0) - 20 and d.y == 4249, "rango sucio que cubre la pasada: %s" % str(d))
	assert_eq(l.profile()["dirty"], Vector2i(-1, -1), "leído, queda limpio")
	var pass_kind: int = (p1["ring_pass"] as PackedByteArray)[ring(l, -5.0)]
	assert_eq(pass_kind, Lathe.PASS_ROUGH, "ap 2 y f 0,3: desbaste")
	assert_eq((p1["ring_pass"] as PackedByteArray)[ring(l, -30.0)], Lathe.PASS_RAW, "fuera de la pasada: bruto")
	assert_near((p1["ring_ra"] as PackedFloat32Array)[ring(l, -30.0)], 12.5, 1e-6, 0.0, "Ra del bruto laminado")


# ─── programas de prueba ───

## Refrentado, tres pasadas de desbaste, acabado con chaflán y hombro (pieza A simplificada).
static func demo_program() -> Array:
	return [
		tool(5, "1"), css(10, 200.0, 2500.0), g0(20, 54.0, 0.0), g1(30, -1.6, 0.0, 0.2), g0(40, 54.0, 2.0),
		g0(50, 47.0, 2.0), g1(60, 47.0, -40.0, 0.3), g0(70, 48.0, -40.0), g0(80, 48.0, 2.0),
		g0(90, 44.0, 2.0), g1(100, 44.0, -40.0, 0.3), g0(110, 45.0, -40.0), g0(120, 45.0, 2.0),
		g0(130, 41.0, 2.0), g1(140, 41.0, -40.0, 0.3), g0(150, 42.0, -40.0), g0(160, 60.0, 5.0),
		tool(170, "2"), css(180, 250.0, 2500.0), g0(190, 36.0, 2.0), g1(200, 38.0, 0.0, 0.1), g1(210, 40.0, -1.0, 0.1),
		g1(220, 40.0, -40.0, 0.1), g1(230, 52.0, -40.0, 0.1), g0(240, 60.0, 5.0), end(250),
	]


## Programa largo (unos 160 s): refrentado y doce pasadas de desbaste de 0,75 mm y acabado, para el rendimiento.
static func long_program() -> Array:
	var p: Array = [tool(5, "1"), css(10, 150.0, 2000.0), g0(20, 54.0, 0.0), g1(30, -1.6, 0.0, 0.2), g0(40, 54.0, 2.0)]
	var x := 50.0
	var n := 50
	for k in 12:
		x -= 1.5
		p.append_array([g0(n, x, 2.0), g1(n + 1, x, -50.0, 0.2), g0(n + 2, x + 1.0, -50.0), g0(n + 3, x + 1.0, 2.0)])
		n += 10
	p.append_array([tool(n, "2"), css(n + 1, 200.0, 2500.0), g0(n + 2, x - 1.0, 2.0), g1(n + 3, x - 1.0, -50.0, 0.1), g0(n + 4, 60.0, 5.0), end(n + 5)])
	return p


static func js_fixed(x: float, d: int) -> String:
	return preload("res://core/shared/js.gd").to_fixed(x, d)
