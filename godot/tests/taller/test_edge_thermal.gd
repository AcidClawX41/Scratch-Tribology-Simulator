## Taller · temperatura del filo (edge_thermal.gd): validación con soluciones exactas (sólido semiinfinito, cuña
## estacionaria, aleta, cuerpo concentrado), conservación de la energía, convergencia de malla y de paso,
## determinismo, secciones en paralelo, rendimiento, revenido y color, y los casos de referencia de
## tests/fixtures/spec/afilado.json (docs/taller/afilado-simulador.md).
extends "res://tests/case.gd"

const ET = preload("res://core/taller/edge_thermal.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Grinding = preload("res://core/taller/grinding.gd")
const Spec = preload("res://tests/taller/spec_afilado.gd")
const Js = preload("res://core/shared/js.gd")

const K := 30.0  # W/(m·K), 1.4116 (SIJ)
const RHO_C := 7700.0 * 460.0
const ALPHA := K / RHO_C
const Q_BENCH := 3.3e6  # W/m²: ≈ la muela fina de la TC-BG 150 con 10 N en un bisel de 16 mm²

var _par: Array = []


func test_solido_semiinfinito_con_flujo_constante() -> void:
	# Barra larga calentada por su extremo y sin pérdidas por las caras: T(0,t) − T0 = 2q·√(αt/π)/k (Carslaw y
	# Jaeger). Con aire en las caras se pierde un poco: el extremo queda algo por debajo.
	var prof := ET.bar_profile({ "thickness_mm": 1.0, "length_mm": 50.0, "n": 120, "h0_um": 1.0 })
	var sec := ET.new(prof, "x50crmov15")
	var air := ET.new(prof, "x50crmov15")
	sec.set_end_flux(1.0e6)
	air.set_end_flux(1.0e6)
	var t := 0.0
	for _i in 5000:
		sec.step(1e-4, 0.0, 0.0, { "h": 0.0 }, 20.0)
		air.step(1e-4, 0.0, 0.0, "aire", 20.0)
		t += 1e-4
	var exact := 2.0 * 1.0e6 / K * sqrt(ALPHA * t / PI)
	var got := sec.edge_c() - 20.0
	assert_near(got, exact, 0.0005, 0.0, "extremo tras 0,5 s (%s K exactos)" % Js.to_fixed(exact, 2))
	var lost := 1.0 - (air.edge_c() - 20.0) / got
	assert_true(lost > 0.0 and lost < 0.005, "el aire en las caras le quita menos del 0,5 %% (%s %%)" % Js.to_fixed(lost * 100.0, 2))


func test_cuna_estacionaria_con_flujo_en_la_cara() -> void:
	# Cuña t(x) = a + b·x calentada por una cara con q, sin otras pérdidas y a temperatura fija en el hombro del
	# bisel: T(x) − T(L) = q/(k·cos β)·[(L − x)/b − (a/b²)·ln((a + b·L)/(a + b·x))].
	var beta := 17.5
	var apex_um := 1.0
	var prof := ET.edge_profile({ "side_a_deg": beta, "side_b_deg": beta, "shoulder_mm": 0.6, "apex_um": apex_um, "body": false, "n_bevel": 40, "h0_um": 5.0 })
	var sec := ET.new(prof, "x50crmov15", 20.0, {}, { "far_fixed_c": 20.0 })
	for _i in 4000:
		sec.step(1e-3, 1.0e6, 1.0, { "h": 0.0 }, 20.0)
	var a := apex_um * 1e-6
	var b := 2.0 * tan(deg_to_rad(beta))
	var length := float(prof["x_shoulder_mm"]) * 1e-3
	var x0 := float(sec.x_mm()[0]) * 1e-3
	var exact := 1.0e6 / (K * cos(deg_to_rad(beta))) * ((length - x0) / b - a / (b * b) * log((a + b * length) / (a + b * x0)))
	assert_near(sec.edge_c() - 20.0, exact, 0.0005, 0.0, "vértice de la cuña en estado estacionario")
	# Sin vértice (a → 0) la subida es q·L/(2k·sen β): el gradiente es constante en toda la cuña. Con 1 µm de
	# vértice queda un 1 % por debajo (el término a/b²·ln).
	var sharp := 1.0e6 * length / (2.0 * K * sin(deg_to_rad(beta)))
	var at_apex := 1.0e6 / (K * cos(deg_to_rad(beta))) * (length / b - a / (b * b) * log((a + b * length) / a))
	assert_near(at_apex, sharp, 0.02, 0.0, "con 1 µm de vértice, casi la cuña perfecta")
	assert_true(at_apex < sharp, "y el vértice romo se calienta algo menos")


func test_aleta_estacionaria() -> void:
	# Barra con convección en las dos caras, base fija en x = L y punta adiabática en x = 0:
	# θ(x) = θb·cosh(m·x)/cosh(m·L), m = √(2h/(k·t)).
	var t := 0.5e-3
	var length := 0.01
	var h := 200.0
	var prof := ET.bar_profile({ "thickness_mm": 0.5, "length_mm": 10.0, "n": 100, "h0_um": 20.0 })
	var sec := ET.new(prof, "x50crmov15", 20.0, {}, { "far_fixed_c": 120.0 })
	for _i in 3000:
		sec.step(0.05, 0.0, 0.0, { "h": h }, 20.0)
	var m := sqrt(2.0 * h / (K * t))
	var x0 := float(sec.x_mm()[0]) * 1e-3
	var exact := 20.0 + 100.0 * cosh(m * x0) / cosh(m * length)
	assert_near(sec.edge_c(), exact, 0.0005, 0.0, "punta de la aleta")
	var xm := float(sec.x_mm()[50]) * 1e-3
	assert_near(sec.temps()[50], 20.0 + 100.0 * cosh(m * xm) / cosh(m * length), 0.0005, 0.0, "y a media aleta")


func test_cuerpo_concentrado() -> void:
	# Placa uniforme a 300 °C con convección en las dos caras: T − T∞ = (T0 − T∞)·e^(−t/τ), τ = ρc·t/(2h).
	var prof := ET.bar_profile({ "thickness_mm": 1.0, "length_mm": 20.0, "n": 10, "h0_um": 2000.0 })
	var h := float(ET.COOLING["aire"]["h"])
	var tau := RHO_C * 1e-3 / (2.0 * h)
	var prev_err := INF
	for dt in [1.0, 0.1, 0.01]:
		var sec := ET.new(prof, "x50crmov15", 300.0)
		var n := int(round(60.0 / dt))
		for _i in n:
			sec.step(dt, 0.0, 0.0, "aire", 20.0)
		var exact := 20.0 + 280.0 * exp(-60.0 / tau)
		var discrete := 20.0 + 280.0 * pow(1.0 + dt / tau, -n)
		assert_near(sec.temps()[5], discrete, 1e-9, 1e-9, "Euler implícito exacto en discreto (dt %s s)" % Js.js_num_str(dt))
		var err := absf(sec.temps()[5] - exact)
		assert_true(err < prev_err, "el error baja con el paso (dt %s s)" % Js.js_num_str(dt))
		prev_err = err
	assert_true(prev_err / 280.0 < 1e-4, "con 10 ms, a menos de 0,01 % de la exponencial")


func test_conservacion_de_la_energia() -> void:
	for cooling in ["aire", "pelicula_agua", "inmersion"]:
		var sec := ET.new(ET.knife_profile({}), "x50crmov15")
		for i in 600:
			sec.step(0.002, Q_BENCH if (i / 50) % 2 == 0 else 0.0, 1.0 if (i / 50) % 2 == 0 else 0.0, cooling, 20.0)
		var e: Dictionary = sec.energy_balance()
		assert_true(float(e["relative"]) < 1e-9, "%s: energía que entra = almacenada + perdida (error relativo %s)" % [cooling, Js.js_num_str(float(e["relative"]))])
		assert_true(float(e["in_j"]) > 0.0 and float(e["stored_j"]) > 0.0, "%s: entra y se guarda calor" % cooling)
	var fixed := ET.new(ET.edge_profile({ "body": false }), "x50crmov15", 20.0, {}, { "far_fixed_c": 20.0 })
	for _i in 500:
		fixed.step(0.002, Q_BENCH, 1.0, "aire", 20.0)
	var ef: Dictionary = fixed.energy_balance()
	assert_true(float(ef["relative"]) < 1e-9, "también con el extremo a temperatura fija")
	assert_true(float(ef["end_j"]) > 0.0, "y el calor sale por el hombro")


func test_convergencia_de_malla_y_de_paso() -> void:
	var ref := _hold(ET.knife_profile({ "n_bevel": 64, "n_body": 32, "h0_um": 2.0 }), 0.0005, 0.3)
	var std := _hold(ET.knife_profile({}), 0.002, 0.3)
	var coarse := _hold(ET.knife_profile({ "n_bevel": 16, "n_body": 8, "h0_um": 10.0 }), 0.002, 0.3)
	var slow := _hold(ET.knife_profile({}), 0.005, 0.3)
	assert_true(absf(std - ref) / (ref - 20.0) < 0.01, "malla por defecto y dt 2 ms a menos del 1 %% de la fina (%s frente a %s °C)" % [Js.to_fixed(std, 1), Js.to_fixed(ref, 1)])
	assert_true(absf(coarse - ref) > absf(std - ref), "la malla gruesa se aleja más")
	assert_true(absf(slow - std) / (std - 20.0) < 0.005, "dt de 5 ms a menos del 0,5 % del de 2 ms")


func test_determinismo() -> void:
	var a := ET.new(ET.knife_profile({}), "14c28n")
	var b := ET.new(ET.knife_profile({}), "14c28n")
	for i in 300:
		var q := Q_BENCH * (0.5 + 0.5 * sin(float(i) * 0.1))
		a.step(0.002, q, 0.7, "pelicula_agua", 20.0)
		b.step(0.002, q, 0.7, "pelicula_agua", 20.0)
	assert_true(a.temps() == b.temps(), "las mismas entradas dan las mismas temperaturas, al bit")
	assert_true(a.temper_params() == b.temper_params(), "y el mismo revenido")
	assert_eq(a.summary()["t_over_temper_s"], b.summary()["t_over_temper_s"])


func test_secciones_independientes_en_paralelo() -> void:
	# 8 secciones: en serie y con WorkerThreadPool deben dar lo mismo, al bit, y combine() en orden fijo también.
	var prof := ET.knife_profile({})
	var serial: Array = []
	for i in 8:
		serial.append(ET.new(prof, "x50crmov15"))
	for i in 8:
		_advance(serial[i], i)
	_par.clear()
	for i in 8:
		_par.append(ET.new(prof, "x50crmov15"))
	# Prioridad alta: las tareas de prioridad baja solo usan una parte de los hilos
	# (threading/worker_pool/low_priority_thread_ratio) y apenas aceleran.
	var task := WorkerThreadPool.add_group_task(_par_task, 8, -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var same := true
	for i in 8:
		same = same and (serial[i] as RefCounted).call("temps") == (_par[i] as RefCounted).call("temps")
		same = same and (serial[i] as RefCounted).call("temper_params") == (_par[i] as RefCounted).call("temper_params")
	assert_true(same, "las secciones avanzadas en hilos dan lo mismo que en serie")
	assert_true(same(ET.combine(serial), ET.combine(_par)), "y la hoja combinada es idéntica")
	var comb: Dictionary = ET.combine(serial)
	assert_eq(comb["sections"], 8)
	assert_eq(comb["hottest_section"], 7, "la sección con más contacto es la más caliente")


func test_rendimiento() -> void:
	# Coste por paso (sin ventana, con otros procesos en la máquina): se apunta en la especificación.
	var prof := ET.knife_profile({})
	var sec := ET.new(prof, "x50crmov15")
	var t0 := Time.get_ticks_usec()
	for _i in 500:
		sec.step(0.005, Q_BENCH, 1.0, "aire", 20.0)
	var one := float(Time.get_ticks_usec() - t0) / 500.0
	var blade: Array = []
	for _i in 8:
		blade.append(ET.new(prof, "x50crmov15"))
	var t1 := Time.get_ticks_usec()
	for k in 100:
		for i in 8:
			(blade[i] as RefCounted).call("step", 0.005, Q_BENCH if i == k % 8 else 0.0, 1.0, "aire", 20.0)
	var eight := float(Time.get_ticks_usec() - t1) / 100.0
	print("    edge_thermal: %s µs por paso y sección (%d celdas); hoja de 8 secciones: %s µs por paso; 1 s de proceso con dt 5 ms: %s ms" % [Js.to_fixed(one, 1), sec.cell_count(), Js.to_fixed(eight, 1), Js.to_fixed(eight * 200.0 / 1000.0, 1)])
	assert_true(one < 2000.0, "una sección, por debajo de 2 ms por paso (%s µs)" % Js.to_fixed(one, 1))
	assert_true(eight < 16000.0, "la hoja de 8 secciones cabe en un fotograma (%s µs)" % Js.to_fixed(eight, 1))


func test_humeda_lenta_no_calienta_y_banco_seco_si() -> void:
	var prof := ET.knife_profile({})
	var area := float(prof["face_width_mm"]) * 50.0
	var g := Grinding.grind({ "machine_id": "tormek_t8", "force_n": 10.0, "contact_area_mm2": area, "steel_id": "x50crmov15" })
	var wet := ET.new(prof, "x50crmov15")
	wet.run(60.0, 0.005, float(g["heat_flux_w_m2"]), 1.0, "pelicula_agua")
	assert_true(float(wet.summary()["peak_edge_c"]) < 40.0, "Tormek, 60 s con 10 N: por debajo de 40 °C")
	var gb := Grinding.grind({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "force_n": 10.0, "contact_area_mm2": float(prof["face_width_mm"]) * 16.0, "steel_id": "x50crmov15" })
	var dry := ET.new(prof, "x50crmov15")
	dry.run(1.0, 0.002, float(gb["heat_flux_w_m2"]), 1.0, "aire")
	var r: Dictionary = dry.summary()
	assert_true(float(r["t_over_temper_s"]) > 0.0 and float(r["t_over_temper_s"]) < 0.5, "banco seco: pasa el revenido en menos de medio segundo")
	assert_true(r["tint"] != null, "y el filo toma color")


func test_mas_calor_mas_temperatura_y_mas_revenido() -> void:
	var prof := ET.knife_profile({})
	var prev_peak := -INF
	var prev_loss := -1.0
	for q in [0.5e6, 1e6, 2e6, 3e6, 4e6]:
		var sec := ET.new(prof, "x50crmov15")
		sec.run(0.5, 0.002, q, 1.0, "aire")
		var r: Dictionary = sec.summary()
		assert_true(float(r["peak_edge_c"]) > prev_peak, "más flujo, más pico (%s W/m²)" % Js.js_num_str(q))
		assert_true(float(r["hardness"]["loss_hrc"]) >= prev_loss, "y nunca menos pérdida de dureza")
		prev_peak = float(r["peak_edge_c"])
		prev_loss = float(r["hardness"]["loss_hrc"])
	# Más fino el filo (menos ángulo), más se calienta con el mismo flujo
	var fine := ET.new(ET.knife_profile({ "per_side_deg": 10.0 }), "x50crmov15")
	var thick := ET.new(ET.knife_profile({ "per_side_deg": 25.0 }), "x50crmov15")
	fine.run(0.3, 0.002, 2e6, 1.0, "aire")
	thick.run(0.3, 0.002, 2e6, 1.0, "aire")
	assert_true(fine.edge_c() > thick.edge_c(), "un filo de 10° por lado se calienta más que uno de 25°")


func test_agua_entre_pasadas_ayuda_pero_no_evita_el_pico() -> void:
	var prof := ET.knife_profile({})
	var dry := ET.new(prof, "x50crmov15")
	var dip := ET.new(prof, "x50crmov15")
	var first_dry := 0.0
	var first_dip := 0.0
	for k in 5:
		for _i in 80:
			dry.step(0.002, Q_BENCH, 1.0, "aire", 20.0)
			dip.step(0.002, Q_BENCH, 1.0, "aire", 20.0)
		if k == 0:
			first_dry = dry.edge_c()
			first_dip = dip.edge_c()
		for _i in 920:
			dry.step(0.002, 0.0, 0.0, "aire", 20.0)
			dip.step(0.002, 0.0, 0.0, "inmersion", 20.0)
	assert_near(first_dip, first_dry, 1e-12, 0.0, "la primera pasada calienta igual: el agua llega tarde")
	assert_true(float(dip.summary()["peak_edge_c"]) < float(dry.summary()["peak_edge_c"]), "mojar entre pasadas baja el pico acumulado")
	assert_true(dip.edge_c() < dry.edge_c(), "y deja la hoja más fría")


func test_hss_aguanta_y_el_acero_al_carbono_no() -> void:
	var prof := ET.knife_profile({})
	var losses := {}
	for steel in ["m2", "x50crmov15", "14c28n", "1095", "vg10"]:
		var sec := ET.new(prof, steel)
		for _k in 3:
			sec.run(0.16, 0.002, 4.5e6, 1.0, "aire")
			sec.run(1.84, 0.002, 0.0, 0.0, "aire")
		losses[steel] = float(sec.summary()["hardness"]["loss_hrc"])
	assert_near(losses["m2"], 0.0, 0.0, 1e-9, "el M2 revenido a 550 °C no pierde dureza")
	for steel in ["x50crmov15", "14c28n", "vg10"]:
		assert_true(losses[steel] > 0.3, "%s pierde dureza con las mismas pasadas (%s HRC)" % [steel, Js.to_fixed(losses[steel], 2)])


func test_broca_pequena_se_calienta_mas() -> void:
	var peaks := []
	for d in [3.0, 5.0, 8.0, 12.0]:
		var prof := ET.drill_profile({ "diameter_mm": d })
		var q := 0.725 * 0.325 * 5.0 * 23.4 / (float(prof["heated_area_mm2"]) * 1e-6)
		var sec := ET.new(prof, "m2")
		sec.run(1.0, 0.002, q, 1.0, "aire")
		peaks.append(float(sec.summary()["peak_max_c"]))
	for i in range(1, peaks.size()):
		assert_true(peaks[i] < peaks[i - 1], "con la misma fuerza, la broca más gruesa se calienta menos (%s °C)" % Js.to_fixed(peaks[i], 0))
	var e: Dictionary = ET.new(ET.drill_profile({ "diameter_mm": 6.0 }), "m2").energy_balance()
	assert_eq(e["per_meter"], false, "la broca va en magnitudes absolutas")


func test_revenido_acumulado_y_curvas() -> void:
	# Pasos isotermos seguidos equivalen a un solo revenido con el tiempo total (regla del tiempo equivalente)
	var c := Heat.curve_hj_c("x50crmov15")
	var p0 := Heat.factory_temper_p("x50crmov15")
	var p := p0
	for _i in 1000:
		p = Heat.accumulate_temper(p, 400.0, 0.01, c)
	var t_eq0 := Heat.hj_time(p0, 400.0, c)
	assert_near(p, Heat.hollomon_jaffe(400.0, t_eq0 + 10.0, c), 1e-9, 0.0, "1000 pasos de 10 ms a 400 °C = 10 s más a 400 °C")
	assert_eq(Heat.accumulate_temper(p, 20.0, 0.01, c), p, "a 20 °C no cambia nada")
	assert_true(Heat.accumulate_temper(p, 500.0, 1.0, c) > p, "y más caliente, crece")
	# Curvas: la del 1.4116 cae desde el revenido de fábrica; la del M2 no cae por debajo de su revenido
	assert_near(float(Heat.curve_hardness("x50crmov15", Heat.hollomon_jaffe(150.0, 3600.0))["hrc"]), 56.25, 1e-12, 0.0, "1.4116 a 150 °C × 1 h: 56,25 HRC")
	assert_near(float(Heat.temper_loss("x50crmov15", Heat.hollomon_jaffe(400.0, 3600.0))["loss_hrc"]), 2.35, 1e-9, 0.0, "a 400 °C × 1 h pierde 2,35 HRC")
	assert_eq(float(Heat.temper_loss("m2", Heat.hollomon_jaffe(540.0, 7200.0))["loss_hrc"]), 0.0, "el M2 a 540 °C no pierde")
	assert_true(bool(Heat.temper_loss("x50crmov15", Heat.hollomon_jaffe(700.0, 3600.0))["beyond"]), "más allá de la curva lo dice")
	for steel in Heat.TEMPER_CURVES:
		var curve: Dictionary = Heat.TEMPER_CURVES[steel]
		assert_true(str(curve["source"]) != "" and ["primary", "secondary", "estimate"].has(curve["quality"]), "%s: curva con fuente y calidad" % steel)
		var key := "points_p" if curve.has("points_p") else "points"
		var pts: Array = curve[key]
		for i in range(1, pts.size()):
			assert_true(float(pts[i][0]) > float(pts[i - 1][0]), "%s: la curva va en orden" % steel)
	assert_eq(Heat.TEMPER_CURVES["vg10"]["quality"], "estimate", "el VG-10 no tiene curva publicada")


func test_cortes_de_perdida_de_dureza() -> void:
	# loss_ranges (calculado una vez) dice lo mismo que temper_loss celda a celda, en todos los aceros y umbrales
	var bad: Array[String] = []
	for steel in Heat.TEMPER_CURVES:
		var p0 := Heat.factory_temper_p(steel)
		for need in [0.5, 1.0, 3.0]:
			var ranges := Heat.loss_ranges(steel, need)
			assert_true(ranges.size() % 2 == 0, "%s: pares desde–hasta" % steel)
			for j in 1201:
				var p := p0 * (0.95 + 0.6 * float(j) / 1200.0) + 0.37  # rejilla que no cae justo en los vértices
				var brute: bool = float(Heat.temper_loss(steel, p)["loss_hrc"]) >= need
				var fast := false
				var i := 0
				while i + 1 < ranges.size():
					fast = fast or (p >= ranges[i] and p <= ranges[i + 1])
					i += 2
				if brute != fast:
					var loss := float(Heat.temper_loss(steel, p)["loss_hrc"])
					if absf(loss - need) > 1e-9:
						bad.append("%s ≥ %s HRC en P = %s: %s frente a %s" % [steel, Js.js_num_str(need), Js.to_fixed(p, 1), str(fast), str(brute)])
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 5)))
	assert_eq(Heat.loss_ranges("m2", 1.0)[0] > Heat.factory_temper_p("m2"), true, "el M2 empieza a perder bastante después de su revenido")
	assert_eq(Heat.loss_ranges("adamantio").size(), 0, "sin curva, sin cortes")
	var x50 := Heat.loss_ranges("x50crmov15", 1.0)
	assert_eq(x50[x50.size() - 1], INF, "más allá de la curva la pérdida sigue")


func test_color_de_revenido() -> void:
	assert_eq(ET.tint("1095", 200.0), {}, "a 200 °C todavía sin color")
	assert_eq(ET.tint("1095", 230.0)["name"], "paja")
	assert_eq(ET.tint("1095", 300.0)["name"], "azul oscuro")
	assert_eq(ET.tint("x50crmov15", 300.0)["name"], "amarillo pálido", "el inox toma color a más temperatura")
	assert_eq(ET.tint_table("vg10"), "inox")
	assert_eq(ET.tint_table("m2"), "acero")
	assert_true(ET.first_tint_c("x50crmov15") > ET.first_tint_c("1095"))
	var sec := ET.new(ET.knife_profile({}), "1095")
	sec.run(0.3, 0.002, Q_BENCH, 1.0, "aire")
	var r: Dictionary = sec.summary()
	assert_true(r["tint"] != null and float(r["tint_width_mm"]) > 0.0, "el bisel caliente se colorea desde el filo")


func test_validez_y_resumen() -> void:
	var sec := ET.new(ET.knife_profile({}), "x50crmov15")
	sec.run(0.2, 0.002, Q_BENCH, 1.0, "aire")
	var r: Dictionary = sec.summary()
	for key in ["time_s", "edge_c", "max_c", "peak_edge_c", "peak_max_c", "edge_surface_peak_c", "tint", "tint_width_mm", "hardness", "temper_equiv_c", "softened_width_mm", "t_over_temper_s", "t_loss_1hrc_s", "burned", "burn_width_mm", "energy", "validity", "quality", "sources"]:
		assert_true(r.has(key), "el resumen trae %s" % key)
	assert_true(float(r["validity"]["through_thickness_ms"]) < 100.0, "en el bisel el calor cruza el espesor en menos de 0,1 s")
	assert_true(float(r["edge_surface_peak_c"]) >= float(r["peak_edge_c"]), "la cara calentada nunca va más fría que la media")
	assert_eq(r["quality"], "estimate")
	var drill := ET.new(ET.drill_profile({ "diameter_mm": 12.0 }), "m2")
	drill.run(0.2, 0.002, 1e6, 1.0, "aire")
	assert_true(float(drill.summary()["validity"]["through_thickness_ms"]) > float(r["validity"]["through_thickness_ms"]), "en una broca gruesa el modelo es menos fiable")


func test_barrido_por_la_muela() -> void:
	assert_near(ET.sweep_coverage(100.0, 100.0, 16.0, 0.0, 0.01), 1.0, 0.0, 0.0, "quieta dentro del contacto")
	assert_near(ET.sweep_coverage(100.0, 80.0, 16.0, 0.0, 0.01), 0.0, 0.0, 0.0, "quieta fuera")
	# El contacto de 16 mm pasa a 100 mm/s: la sección está 0,16 s dentro
	var total := 0.0
	var c0 := 0.0
	for _i in 400:
		total += ET.sweep_coverage(100.0, c0, 16.0, 100.0, 0.005) * 0.005
		c0 += 100.0 * 0.005
	assert_near(total, 0.16, 1e-9, 1e-12, "tiempo de contacto = ancho / velocidad")


func test_entradas_raras() -> void:
	var sec := ET.new(ET.knife_profile({ "per_side_deg": -5.0, "thickness_mm": -1.0 }), "adamantio")
	sec.step(0.0, 1e6)
	sec.step(NAN, 1e6)
	sec.step(0.002, NAN, NAN, "lava", NAN)
	sec.step(0.002, -5e6, 2.0)
	assert_true(is_finite(sec.edge_c()), "entradas absurdas no rompen el modelo")
	assert_eq(sec.summary()["hardness"], null, "acero sin curva: sin dureza")
	assert_near(sec.edge_c(), 20.0, 0.0, 1e-9, "y sin calor no se calienta")


func test_casos_de_referencia_de_la_especificacion() -> void:
	var cases := Spec.load_cases()
	assert_true(cases.size() >= 40, "la especificación trae los casos (%d)" % cases.size())
	var ids := {}
	var bad: Array[String] = []
	for c in cases:
		assert_false(ids.has(c["id"]), "id repetido: %s" % c["id"])
		ids[c["id"]] = true
		assert_true(str(c.get("source", "")) != "" and not (c.get("expect", {}) as Dictionary).is_empty(), "%s: con fuente y lo esperado" % c["id"])
		bad.append_array(Spec.check(c, Spec.run_case(c)))
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 5)))


# --- utilidades ---


func _par_task(i: int) -> void:
	_advance(_par[i], i)


## Avanza la sección i con i+1 pulsos de calor (cada una distinta, para que se note si se cruzan).
func _advance(sec: Variant, i: int) -> void:
	for k in 8:
		var on := k <= i
		for _s in 40:
			sec.step(0.002, Q_BENCH if on else 0.0, 1.0 if on else 0.0, "aire", 20.0)


## Pico del vértice tras dur segundos quieto con Q_BENCH.
func _hold(prof: Dictionary, dt: float, dur: float) -> float:
	var sec := ET.new(prof, "x50crmov15")
	sec.run(dur, dt, Q_BENCH, 1.0, "aire")
	return sec.edge_c()
