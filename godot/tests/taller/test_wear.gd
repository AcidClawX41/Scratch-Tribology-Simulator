## Taller · desgaste de la herramienta (core/taller/wear.gd): la curva publicada, el fin de vida de ISO 3685, la vida
## de Taylor, Kver del TZ, la rugosidad y el estado paso a paso (también entre hilos).
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const Wear = preload("res://core/taller/wear.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")


## La curva de Equeter et al. (2020, fig. 8): cruza 0,3 mm en τ = 1, no baja nunca y pasa por los puntos medidos.
func test_curva_publicada() -> void:
	assert_near(Wear.vb_at_fraction(1.0), Wear.VB_END_MM, 1e-9, 0.0, "τ = 1 → VB_B = 0,3 mm (fin de vida)")
	# El texto del artículo: 0,3 mm a los 25,35 min (la curva digitalizada lo cruza a 25,378 min)
	assert_near(Wear.vb_at_fraction(25.35 / Wear.CURVE_T_END_MIN), 0.3, 0.01, 0.0, "a 25,35 min, ~0,3 mm")
	var prev := -1.0
	for i in 1301:
		var vb := Wear.vb_at_fraction(i / 1000.0)
		assert_true(vb >= prev, "el desgaste no retrocede (τ = %s)" % Js.js_num_str(i / 1000.0))
		prev = vb
	assert_eq(Wear.vb_at_fraction(0.0), 0.0, "filo nuevo: VB = 0")
	for i in Wear.CURVE_T_MIN.size():
		var tau := float(Wear.CURVE_T_MIN[i]) / Wear.CURVE_T_END_MIN
		assert_near(Wear.vb_at_fraction(tau), Wear.CURVE_VB_MM[i], 1e-9, 1e-12, "punto %d de la figura" % i)
	# Inversa donde la curva sube de verdad (fuera de las dos mesetas de la media de puntos)
	for tau in [0.05, 0.15, 0.3, 0.45, 0.62, 0.8, 0.95, 1.0, 1.1]:
		assert_near(Wear.fraction_at_vb(Wear.vb_at_fraction(tau)), tau, 1e-9, 1e-12, "inversa en τ = %s" % Js.js_num_str(tau))
	assert_near(Wear.fraction_at_vb(0.3), 1.0, 1e-9, 0.0, "0,3 mm → τ = 1")
	# Sin extrapolar más allá de lo medido: VB se queda en 0,684 mm por mucho que se corte
	var last: float = Wear.CURVE_VB_MM[Wear.CURVE_VB_MM.size() - 1]
	for tau in [1.2, 2.0, 10.0, 1000.0]:
		assert_eq(Wear.vb_at_fraction(tau), last, "τ = %s: el último VB medido" % Js.js_num_str(tau))
	assert_eq(Wear.fraction_at_vb(0.7), INF, "0,7 mm no se alcanza en el modelo")
	assert_eq(Wear.minutes_to_vb(0.7, 180.0, "hm_coated", "c45e"), INF, "ni en minutos")
	# Tres etapas: rodaje rápido, tramo estable lento y desgaste acelerado
	var run_in := Wear.vb_at_fraction(Wear.STAGE_RUN_IN_END) / Wear.STAGE_RUN_IN_END
	var steady := (Wear.vb_at_fraction(Wear.STAGE_STEADY_END) - Wear.vb_at_fraction(Wear.STAGE_RUN_IN_END)) / (Wear.STAGE_STEADY_END - Wear.STAGE_RUN_IN_END)
	var accel := (Wear.vb_at_fraction(1.15) - Wear.vb_at_fraction(Wear.STAGE_STEADY_END)) / (1.15 - Wear.STAGE_STEADY_END)
	assert_true(run_in > 2.0 * steady and accel > 5.0 * steady, "rodaje %s, estable %s, acelerado %s mm por vida" % [run_in, steady, accel])
	assert_eq([Wear.stage(0.1), Wear.stage(0.5), Wear.stage(0.95)], ["rodaje", "estable", "acelerado"], "etapas")


## ISO 3685:1993: VB_B = 0,3 mm (regular) o VB_Bmax = 0,6 mm (irregular).
func test_fin_de_vida_iso3685() -> void:
	assert_false(Wear.effects(0.29)["end_of_life"], "0,29 mm: todavía sirve")
	assert_true(Wear.effects(0.3)["end_of_life"], "0,30 mm: fin de vida")
	assert_false(Wear.effects(0.5)["end_of_life_max"], "0,5 mm por debajo de VB_Bmax")
	assert_true(Wear.effects(0.6)["end_of_life_max"], "0,6 mm: VB_Bmax")
	assert_true(Wear.effects(Wear.vb_at_fraction(1.0))["end_of_life"], "justo en τ = 1 (0,29999999999999993 en coma flotante)")
	assert_true(Wear.after(15.0, 180.0, "hm_coated", "c45e")["end_of_life"], "15 min exactos a vcT15: fin de vida")
	var s := Wear.after(20.0, 180.0, "hm_coated", "c45e")
	var dead := Wear.after(16.0, 180.0, "hm_coated", "c45e")
	assert_true(dead["end_of_life"], "c45e con metal duro a su vcT15 (180 m/min): muerta pasados 15 min")
	assert_true(_has(dead["warnings"], "Fin de vida"), "y lo avisa")
	assert_true(s["vb_mm"] > dead["vb_mm"], "más tiempo, más desgaste")
	for e in [Wear.effects(0.1), Wear.effects(0.4)]:
		assert_true(e["sources"].size() >= 3 and e["quality"] == "estimate", "efectos con fuentes y marcados como estimación")


## Vida de Taylor: a vcT15 (el centro del intervalo de vc) son 15 min; más vc, menos vida y más desgaste en el mismo
## tiempo (nunca menos).
func test_vida_de_taylor() -> void:
	var tp := ToolMaterials.taylor_params(ToolMaterials.get_tool("hm_coated"), "P")
	var l := Wear.life("hm_coated", "c45e", tp["vc_ref"])
	assert_near(l["life_min"], 15.0, 1e-9, 0.0, "T(vcT15) = 15 min")
	assert_near(Wear.minutes_to_vb(0.3, tp["vc_ref"], "hm_coated", "c45e"), 15.0, 1e-9, 0.0, "15 min hasta 0,3 mm")
	assert_eq(Wear.life("hm_coated", "c45e", 0.0)["life_min"], INF, "parado no se gasta")
	var prev_life := INF
	var prev_vb := 0.0
	for vc in [60.0, 120.0, 180.0, 240.0, 300.0]:
		var s := Wear.after(5.0, vc, "hm_coated", "c45e")
		assert_true(float(s["life_min"]) < prev_life, "vida decreciente con vc (%s m/min)" % Js.js_num_str(vc))
		assert_true(float(s["vb_mm"]) >= prev_vb, "5 min a %s m/min: no menos desgaste" % Js.js_num_str(vc))
		prev_life = s["life_min"]
		prev_vb = s["vb_mm"]
	# Sin datos: no se inventa una vida
	assert_eq(Wear.life("hm_coated", "vidrio", 150.0)["life_min"], null, "vidrio: sin modelo de corte")
	assert_eq(Wear.life("pcd", "c45e", 150.0)["life_min"], null, "PCD en acero: sin datos de vida")
	assert_eq(Wear.life("nada", "c45e", 150.0)["life_min"], null, "herramienta desconocida")


## Kver del TZ (1,2-1,5, p. 208) sobre el VB admisible del TZ (0,2-0,8 mm, p. 214), y la banda del caso medido.
func test_kver_del_tabellenbuch() -> void:
	assert_eq(Wear.kver_for_vb(0.0), 1.0, "filo nuevo: Kver = 1 (las tablas de kc son de filo sin desgaste)")
	assert_near(Wear.kver_for_vb(0.2), 1.2, 1e-12, 0.0, "VBzul mínimo del TZ → Kver 1,2")
	assert_near(Wear.kver_for_vb(0.8), 1.5, 1e-12, 0.0, "VBzul máximo del TZ → Kver 1,5")
	assert_near(Wear.kver_for_vb(0.3), 1.25, 1e-12, 0.0, "fin de vida de ISO 3685 → 1,25")
	assert_eq(Wear.kver_for_vb(2.0), 1.5, "no pasa de 1,5")
	var prev := 0.0
	for i in 101:
		var k := Wear.kver_for_vb(i / 100.0)
		assert_true(k >= prev and k >= 1.0 and k <= 1.5, "Kver creciente entre 1 y 1,5")
		prev = k
		var band: Array = Wear.effects(i / 100.0)["kver_band"]
		assert_true(band[0] <= band[1] and band[0] >= 1.0, "banda ordenada (VB %s)" % Js.js_num_str(i / 100.0))
	# El caso medido (Equeter 2019): Fc +9 % de VB 0,075 a 0,684 mm
	var e0 := Wear.effects(0.075)
	var e1 := Wear.effects(0.684)
	assert_near(float(e1["kver_band"][0]) / float(e0["kver_band"][0]), 1.09, 0.001, 0.0, "banda baja: +9 % en Fc")
	assert_near(e1["ff_factor"] / e0["ff_factor"], 1.40, 0.001, 0.0, "Ff +40 %")
	assert_near(e1["fp_factor"] / e0["fp_factor"], 1.10, 0.001, 0.0, "Fp +10 %")
	# Se pasa tal cual a Cutting como `wear`
	var p := { "work_id": "c45e", "tool_id": "hm_coated", "d_mm": 50.0, "vc": 180.0, "f_mm_rev": 0.2, "ap_mm": 2.0 }
	var new_fc: float = Cutting.turning(p)["fc_n"]
	var worn := p.duplicate()
	worn["wear"] = Wear.kver_for_vb(0.1)
	var r := Cutting.turning(worn)
	assert_near(r["fc_n"], new_fc * 1.1, 1e-12, 0.0, "VB 0,1 mm: Fc × 1,1")
	assert_true(r["warnings"].is_empty(), "sin avisos de Kver fuera de intervalo")


## El modelo del torno con el filo gastado: kc y Fc por Kver, la misma firma que el inyectado (Kver ligado).
func test_modelo_del_torno_con_desgaste() -> void:
	var fresh := Cutting.cutting_model("c42crmo4", "hm", 0.2, 2.0, 180.0)
	var default_k := Cutting.cutting_model_worn("c42crmo4", "hm", 0.2, 2.0, 180.0)
	assert_eq(default_k["kver"], 1.0, "Kver por defecto = 1")
	for key in fresh:
		assert_eq(default_k[key], fresh[key], "con Kver = 1, %s igual que cutting_model" % key)
	var k := Wear.kver_for_vb(0.3)
	var worn: Dictionary = Cutting.model_callable_worn(k).call("c42crmo4", "hm", 0.2, 2.0, 180.0)
	assert_near(worn["kc"], fresh["kc"] * 1.25, 1e-12, 0.0, "VB 0,3 mm: kc × 1,25")
	assert_near(worn["fc_n"], fresh["fc_n"] * 1.25, 1e-12, 0.0, "y Fc")
	assert_eq([worn["ff_n"], worn["fp_n"]], [fresh["ff_n"], fresh["fp_n"]], "Ff y Fp sin corregir (el TZ no los corrige)")
	assert_eq(worn["quality"], "estimate", "con desgaste, estimación")
	assert_eq(worn["kver"], 1.25, "devuelve el Kver aplicado")
	assert_eq(Cutting.cutting_model_worn("c42crmo4", "hm", 0.2, 2.0, 180.0, 3.0)["kver"], 1.5, "Kver hasta 1,5 (TZ)")
	assert_eq(Cutting.cutting_model_worn("c42crmo4", "hm", 0.2, 2.0, 180.0, 0.5)["kver"], 1.0, "y desde 1")
	assert_eq(Cutting.cutting_model_worn("c42crmo4", "hm", 0.2, 2.0, 180.0, NAN)["kver"], 1.0, "NaN → filo nuevo")
	var glass: Dictionary = Cutting.cutting_model_worn("vidrio", "hm", 0.2, 2.0, 180.0, 1.3)
	assert_false(glass["ok"], "sin kc sigue sin kc")
	assert_eq(glass["fc_n"], 0.0, "y sin fuerzas")


## Rugosidad: la recta de la fig. 10 de Equeter et al. (2020); del primer al último punto medido, +48 % en el artículo.
func test_rugosidad_con_el_desgaste() -> void:
	assert_eq(Wear.ra_factor_for_vb(0.0), 1.0, "filo nuevo: la Ra teórica")
	assert_near(Wear.ra_factor_for_vb(0.3), 1.0 + 0.3 * 2.674 / 2.716, 1e-12, 0.0, "fin de vida: +30 %")
	var first := Wear.ra_factor_for_vb(0.0736)
	var last := Wear.ra_factor_for_vb(0.685)
	assert_near(last / first, 1.48, 0.07, 0.0, "del primer al último punto: +48 %% publicado (la recta da %s)" %Js.js_num_str(last / first))
	var prev := 0.0
	for i in 81:
		var f := Wear.ra_factor_for_vb(i / 100.0)
		assert_true(f > prev, "más desgaste, peor acabado")
		prev = f


## Paso a paso: pasos pequeños = de una vez a vc constante; con vc variable, D = Σ Δt/T(vc); sin corte no se gasta; el
## estado de entrada no cambia.
func test_estado_paso_a_paso() -> void:
	var s := Wear.new_state()
	for i in 600:
		s = Wear.step(s, 1.0, 200.0, "hm_coated", "c45e")
	var once := Wear.after(10.0, 200.0, "hm_coated", "c45e")
	assert_near(s["used"], once["used"], 1e-9, 0.0, "600 pasos de 1 s = 10 min de golpe")
	assert_near(s["vb_mm"], once["vb_mm"], 1e-9, 0.0, "mismo VB")
	assert_near(s["cut_s"], 600.0, 1e-12, 0.0, "segundos de corte")
	# Media vida a 120 m/min y media vida a 240 m/min: fin de vida
	var t120: float = Wear.life("hm_coated", "c45e", 120.0)["life_min"]
	var t240: float = Wear.life("hm_coated", "c45e", 240.0)["life_min"]
	var mixed := Wear.step(Wear.step(Wear.new_state(), t120 * 30.0, 120.0, "hm_coated", "c45e"), t240 * 30.0, 240.0, "hm_coated", "c45e")
	assert_near(mixed["used"], 1.0, 1e-9, 0.0, "½ + ½ de vida = vida entera")
	assert_near(mixed["vb_mm"], 0.3, 1e-6, 0.0, "y VB = 0,3 mm")
	# Sin corte, nada
	var base := Wear.after(3.0, 180.0, "hm_coated", "c45e")
	var copy := base.duplicate(true)
	for args in [[0.0, 180.0], [-5.0, 180.0], [10.0, 0.0], [10.0, -50.0]]:
		var r := Wear.step(base, args[0], args[1], "hm_coated", "c45e")
		assert_eq(r["used"], base["used"], "dt %s, vc %s: no se gasta" % [args[0], args[1]])
	assert_true(same(base, copy), "step no modifica el estado que recibe")
	var unknown := Wear.step(Wear.new_state(), 60.0, 150.0, "hm_coated", "granito")
	assert_eq(unknown["used"], 0.0, "sin datos de vida no se inventa desgaste")
	assert_true(unknown["warnings"].size() > 0, "y se avisa")
	assert_eq(unknown["cut_s"], 60.0, "pero el tiempo de corte sí cuenta")
	var late := Wear.after(0.95 * 15.0, 180.0, "hm_coated", "c45e")
	assert_eq(late["stage"], "acelerado", "al 95 % de la vida, desgaste acelerado")
	assert_true(_has(late["warnings"], "acelerado"), "con aviso")
	assert_near(late["remaining_min"], 0.05 * 15.0, 1e-9, 0.0, "queda el 5 % de 15 min")


## Funciones puras: el mismo resultado desde varios hilos (CONTRATOS.md → «Rendimiento y multinúcleo»).
func test_desgaste_seguro_entre_hilos() -> void:
	var cases: Array = []
	for tool in ["hss_m2", "hm", "hm_coated", "ceramica_al2o3"]:
		for work in ["s235jr", "c45e", "c42crmo4", "gjl250", "al6082_t6"]:
			for t in [0.5, 5.0, 14.0, 30.0]:
				cases.append([tool, work, t])
	var run := func(i: int) -> Dictionary:
		var c: Array = cases[i]
		var s := Wear.after(c[2], 150.0, c[0], c[1])
		s["effects"] = Wear.effects(s["vb_mm"])
		return s
	var seq: Array = []
	for i in cases.size():
		seq.append(run.call(i))
	var par: Array = []
	par.resize(cases.size())
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var r: Dictionary = run.call(i)
		mutex.lock()
		par[i] = r
		mutex.unlock()
	var id := WorkerThreadPool.add_group_task(task, cases.size(), 4, true, "test_wear")
	WorkerThreadPool.wait_for_group_task_completion(id)
	assert_true(same(par, seq), "4 hilos = secuencial (%d casos)" % cases.size())


static func _has(warnings: Array, text: String) -> bool:
	for w in warnings:
		if String(w).contains(text):
			return true
	return false
