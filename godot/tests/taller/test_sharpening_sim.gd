## Taller · simulador de afilado (sharpening_sim.gd, con sharpening_bevel.gd y sharpening_report.gd): los casos de
## referencia de tests/fixtures/spec/afilado.json que le tocan al simulador integrado (docs/taller/afilado-simulador.md,
## §4.4 y §7), determinismo, 1 hilo = N hilos, reparto del tiempo, invariantes físicos (más fuerza nunca enfría, el
## agua nunca calienta, el CBN calienta menos que el corindón), bisel y rebaba, filo final, informe, casos límite y
## los diccionarios de la escena 3D y del sonido.
extends "res://tests/case.gd"

const Sim = preload("res://core/taller/sharpening_sim.gd")
const Spec = preload("res://tests/taller/spec_afilado.gd")
const Bevel = preload("res://core/taller/sharpening_bevel.gd")
const Report = preload("res://core/taller/sharpening_report.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const G = preload("res://core/taller/grinding.gd")
const ET = preload("res://core/taller/edge_thermal.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")
const Js = preload("res://core/shared/js.gd")

const INCH_MM := 25.4
## Casos de afilado.json que no son del simulador: curvas de revenido y colores del acero (datos del material).
const NOT_SIM_KINDS := ["revenido", "color"]


# ─────────────────────────────── Casos de referencia ───────────────────────────────

## El tipo de herramienta con el que se prueba una máquina en los casos de velocidad y amolado.
static func _kind_for(machine_id: String) -> String:
	var mk := str(Machines.MACHINES[machine_id]["kind"])
	if mk == "afiladora_brocas":
		return "broca"
	if mk == "afiladora_fresas":
		return "fresa"
	return "cuchillo"


## Un caso de afilado.json con el simulador integrado: sus salidas con los nombres del caso, o {} si el caso no es
## del simulador.
static func sim_case(c: Dictionary) -> Dictionary:
	var input: Dictionary = c.get("input", {})
	var kind := str(c.get("kind", ""))
	match kind:
		"velocidad":
			var mid := str(input["machine_id"])
			var p := { "machine_id": mid, "wheel": input.get("wheel", ""), "tool": { "kind": _kind_for(mid) } }
			if input.has("rpm"):
				p["rpm"] = input["rpm"]
			if input.has("diameter_mm"):
				p["diameter_mm"] = input["diameter_mm"]
			var snap := Sim.new(p).snapshot()
			return { "speed_ms": snap["vs_no_load_ms"], "max_speed_ms": snap["max_speed_ms"], "over_speed": snap["over_speed"] }
		"amolado":
			var mid2 := str(input["machine_id"])
			var p2 := {
				"machine_id": mid2, "wheel": input.get("wheel", ""),
				"tool": { "kind": _kind_for(mid2), "steel_id": input.get("steel_id", "") },
				"hand": { "force_n": input.get("force_n", 10.0) },
			}
			if input.has("rpm"):
				p2["rpm"] = input["rpm"]
			var sim := Sim.new(p2)
			var r := sim.grind_at(Heat.input_num(input, "surface_c", Heat.AMBIENT_C))
			var out := r.duplicate()
			for w in r.get("warnings", []):
				out["aviso_" + str(w["code"])] = true
			return out
		"termico":
			var sim3 := thermal_sim(input)
			sim3.run_program()
			var out3 := sim3.hottest_summary().duplicate()
			var g := sim3.grind_at(Heat.AMBIENT_C)
			for key in ["vs_ms", "rpm", "stalled", "power_w", "heat_flux_w_m2"]:
				out3[key] = g[key]
			return out3
		"broca_labios", "broca_revision":
			var t := {
				"kind": "broca", "diameter_mm": input.get("diameter_mm", 8.0), "point_deg": input.get("point_deg", 118.0),
				"lip_diff_mm": input.get("lip_height_diff_mm", 0.0), "work_material": input.get("work_material", "acero"),
			}
			if input.has("clearance_deg"):
				t["clearance_deg"] = input["clearance_deg"]
			var chk := Sim.new({ "machine_id": "einhell_tc_bg_150", "tool": t }).tool_check()
			if kind == "broca_labios":
				return chk["offset"]
			var o := { "ok": chk["ok"] }
			for fd in chk["findings"]:
				o["aviso_" + str(fd["code"])] = true
			return o
		"broca_incidencia":
			# drill_check mira la incidencia efectiva a 0,1·D del eje: una broca de D = 10·r
			var clr := Heat.input_num(input, "clearance_deg", 10.0)
			var t2 := { "kind": "broca", "diameter_mm": 10.0 * Heat.input_num(input, "r_mm", 1.0), "clearance_deg": clr, "feed_mm_rev": input.get("feed_mm_rev", 0.1) }
			var chk2 := Sim.new({ "machine_id": "einhell_tc_bg_150", "tool": t2 }).tool_check()
			var inner := float(chk2["effective_clearance_deg"]["inner"])
			return { "effective_clearance_deg": inner, "feed_helix_deg": clr - inner, "chisel_deg": chk2["chisel_deg"], "wedge_deg": chk2["wedge_deg"] }
		"fresa_desplazamiento":
			var dmm := Heat.input_num(input, "diameter_mm", 0.0)
			if dmm <= 0.0:
				dmm = Heat.input_num(input, "diameter_in", 0.0) * INCH_MM
			var chk3 := Sim.new({ "machine_id": "mrcm_mr_x3", "tool": { "kind": "fresa", "diameter_mm": dmm, "primary_deg": input.get("angle_deg", 7.0) } }).tool_check()
			return { "offset_mm": chk3["offset_mm"], "offset_in": float(chk3["offset_mm"]) / INCH_MM, "offset_exact_mm": chk3["offset_exact_mm"] }
	return {}


## Simulador para un caso térmico: la herramienta del caso, quieta contra la muela on_s segundos, off_s de descanso
## (en agua si cooling_off es «inmersion») y count veces. Con una sola sección y el filo tan largo como el contacto,
## esa sección está entera bajo la muela, como en el ejecutor de referencia (spec_afilado.gd).
static func thermal_sim(input: Dictionary) -> Sim:
	var tool: Dictionary = input.get("tool", {})
	var kind := str(tool.get("kind", "cuchillo"))
	var t := { "kind": kind, "steel_id": tool.get("steel_id", "x50crmov15") }
	var hand := { "force_n": input.get("force_n", 10.0), "motion": "quieto" }
	if kind == "broca":
		t["diameter_mm"] = tool.get("diameter_mm", 8.0)
		t["point_deg"] = tool.get("point_deg", 118.0)
	else:
		var beta := Heat.input_num(tool, "per_side_deg", Heat.input_num(tool, "side_a_deg", 17.5))
		t["bevel_deg"] = beta
		for key in ["thickness_mm", "spine_mm", "height_mm", "apex_um"]:
			if tool.has(key):
				t[key] = tool[key]
		t["length_mm"] = Heat.input_num(input, "contact_len_mm", 16.0)
		t["sections"] = 1
		hand["angle_deg"] = beta
	var contact: Dictionary = input.get("contact", {})
	hand["hold_s"] = Heat.input_num(contact, "on_s", 1.0)
	hand["rest_s"] = Heat.input_num(contact, "off_s", 0.0)
	hand["passes"] = int(Heat.input_num(contact, "count", 1))
	hand["dip"] = str(input.get("cooling_off", "aire")) == "inmersion"
	var p := { "machine_id": input["machine_id"], "wheel": input.get("wheel", ""), "tool": t, "hand": hand }
	if input.has("rpm"):
		p["rpm"] = input["rpm"]
	var sim := Sim.new(p)
	sim.threads = 1
	return sim


func test_casos_de_referencia_del_simulador() -> void:
	var cases := Spec.load_cases()
	assert_true(cases.size() >= 60, "la especificación trae los casos (%d)" % cases.size())
	var bad: Array[String] = []
	var ran := 0
	var skipped := 0
	for c in cases:
		if str(c["kind"]) in NOT_SIM_KINDS:
			skipped += 1
			continue
		var out := sim_case(c)
		assert_false(out.is_empty(), "%s: el simulador da salidas" % c["id"])
		bad.append_array(Spec.check(c, out))
		ran += 1
	print("    casos de afilado.json con el simulador: %d de %d (%d de curvas y colores del acero, fuera del simulador) · %d fallos" % [ran, cases.size(), skipped, bad.size()])
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 6)))
	assert_eq(ran + skipped, cases.size(), "todos los casos, repartidos")


func test_largo_del_contacto_como_en_los_casos() -> void:
	# El simulador toma el largo del contacto del ancho de la muela; sin dato, la estimación de los casos
	var want := {
		"einhell_tc_bg_150": 16.0, "tormek_t8": 50.0, "einhell_tc_wg_200": 40.0, "vevor_scm8082": 40.0,
		"vevor_md150_4": 16.0, "einhell_te_ag_125_ce": 20.0, "einhell_tc_ag_125_850": 20.0,
	}
	for mid in want:
		var snap := Sim.new({ "machine_id": mid, "tool": { "kind": "cuchillo" } }).snapshot()
		assert_eq(float(snap["contact_len_mm"]), float(want[mid]), "%s: %s mm de contacto" % [mid, Js.js_num_str(want[mid])])
	var wd := Sim.new({ "machine_id": "einhell_tc_wd_200_150", "wheel": "humeda", "tool": { "kind": "cuchillo" } }).snapshot()
	assert_eq(float(wd["contact_len_mm"]), 40.0, "TC-WD húmeda: 40 mm")
	var short := Sim.new({ "machine_id": "tormek_t8", "tool": { "kind": "cuchillo", "length_mm": 30.0 } }).snapshot()
	assert_eq(float(short["contact_len_mm"]), 30.0, "nunca más largo que el filo")


# ─────────────────────────────── Determinismo e hilos ───────────────────────────────

## Cuchillo en la TC-BG 150 barriendo a 100 mm/s, con agua entre pasadas: 8 secciones, 3 pasadas.
static func _knife(threads: int) -> Sim:
	var sim := Sim.new({
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "length_mm": 120.0, "sections": 8, "flat_um": 10.0 },
		"hand": { "sweep_mm_s": 100.0, "passes": 3, "rest_s": 0.5, "dip": true },
	})
	sim.threads = threads
	return sim


## Todo el estado de las secciones (temperaturas, revenido y bisel) para comparar al bit.
static func _state(sim: Sim) -> Array:
	var out: Array = []
	for i in sim.section_count():
		out.append([sim.section_temps(i), sim.section_temper(i), sim.section_bevel(i)])
	return out


func test_determinismo() -> void:
	var a := _knife(1)
	var b := _knife(1)
	a.run_program()
	b.run_program()
	assert_true(same(_state(a), _state(b)), "las mismas entradas dan el mismo estado, al bit")
	var sa := a.snapshot()
	var sb := b.snapshot()
	assert_true(sa["history"]["c"] == sb["history"]["c"] and sa["history"]["t"] == sb["history"]["t"], "y la misma gráfica")
	assert_eq(sa["report"]["grade"], sb["report"]["grade"], "y la misma nota")
	assert_true(bool(sa["finished"]) and not bool(sa["running"]), "el programa termina")


func test_un_hilo_igual_a_n_hilos() -> void:
	var serial := _knife(1)
	serial.run_program()
	var ref := _state(serial)
	for n in [-1, 3, 2]:
		var par := _knife(n)
		par.run_program()
		assert_true(same(_state(par), ref), "con %d hilos, lo mismo que en serie, al bit" % n)
		assert_true(same(par.combined(), serial.combined()), "y la hoja combinada (%d hilos)" % n)
		assert_true(par.snapshot()["history"]["c"] == serial.snapshot()["history"]["c"], "y la gráfica (%d hilos)" % n)


func test_el_reparto_del_tiempo_no_cambia_el_resultado() -> void:
	var one := _knife(1)
	one.run_program()
	var frames := _knife(1)
	frames.start()
	var deltas := [0.013, 0.0071, 0.05, 0.0009, 0.021, 1.0 / 60.0, 0.1]
	var i := 0
	var guard := 0
	while frames.is_running() and guard < 100000:
		frames.advance(deltas[i % deltas.size()])
		i += 1
		guard += 1
	assert_true(frames.is_finished(), "termina avanzando a trozos desiguales")
	assert_true(same(_state(frames), _state(one)), "y acaba igual que de una vez, al bit")
	assert_eq(frames.snapshot()["passes_done"], one.snapshot()["passes_done"], "las mismas pasadas")


# ─────────────────────────────── Invariantes físicos ───────────────────────────────

## Pico del vértice tras sostener la herramienta hold_s contra la muela con force_n (una sola sección).
static func _hold_peak(p: Dictionary, force_n: float, hold_s: float = 0.5) -> float:
	var q := p.duplicate(true)
	var tool: Dictionary = q.get("tool", { "kind": "cuchillo" })
	if str(tool.get("kind", "cuchillo")) != "broca":
		tool["sections"] = 1
		tool["length_mm"] = 10.0
	q["tool"] = tool
	q["hand"] = { "force_n": force_n, "motion": "quieto", "hold_s": hold_s, "passes": 1, "rest_s": 0.0 }
	var sim := Sim.new(q)
	sim.threads = 1
	sim.run_program()
	return float(sim.combined()["peak_edge_c"])


func test_mas_fuerza_nunca_enfria() -> void:
	# Mientras el motor no pasa de su par nominal, más fuerza es más potencia y más calor. (Más allá, un motor universal
	# se frena tanto que la potencia baja, y calado no calienta: lo dicen los avisos «se_frena» y «se_cala».)
	var setups := [
		{ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo" } },
		{ "machine_id": "tormek_t8", "tool": { "kind": "cuchillo" } },
		{ "machine_id": "vevor_md150_4", "wheel": "fino", "tool": { "kind": "cuchillo" } },
		{ "machine_id": "einhell_te_ag_125_ce", "rpm": 3000.0, "tool": { "kind": "cortacesped" } },
		{ "machine_id": "mrcm_mr_13a", "tool": { "kind": "broca", "diameter_mm": 6.0 } },
	]
	for p in setups:
		var prev := -INF
		var checked := 0
		for f in [0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0, 30.0, 40.0]:
			var q: Dictionary = (p as Dictionary).duplicate(true)
			q["hand"] = { "force_n": f }
			if bool(Sim.new(q).grind_at()["overloaded"]):
				break
			var peak := _hold_peak(p, f)
			assert_true(peak >= prev - 1e-9, "%s: con %s N no se enfría (%s °C)" % [p["machine_id"], Js.js_num_str(f), Js.to_fixed(peak, 1)])
			prev = peak
			checked += 1
		assert_true(checked >= 3, "%s: se comprueban varias fuerzas (%d)" % [p["machine_id"], checked])
	assert_near(_hold_peak(setups[0], 0.0), Heat.AMBIENT_C, 0.0, 1e-9, "sin fuerza no se calienta")


func test_el_agua_nunca_calienta() -> void:
	var base := {
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "sections": 1, "length_mm": 16.0 },
		"hand": { "motion": "quieto", "hold_s": 0.3, "rest_s": 1.5, "passes": 4 },
	}
	var dry := Sim.new(base)
	var wet_q := base.duplicate(true)
	wet_q["hand"]["dip"] = true
	var wet := Sim.new(wet_q)
	dry.threads = 1
	wet.threads = 1
	dry.run_program()
	wet.run_program()
	var hd: Dictionary = dry.snapshot()["history"]
	var hw: Dictionary = wet.snapshot()["history"]
	assert_eq(hd["t"], hw["t"], "las dos gráficas con los mismos instantes")
	var worse := 0
	for i in (hd["c"] as PackedFloat32Array).size():
		if float(hw["c"][i]) > float(hd["c"][i]) + 1e-6:
			worse += 1
	assert_eq(worse, 0, "mojar la hoja entre pasadas nunca la deja más caliente en ningún momento")
	assert_true(float(wet.combined()["peak_edge_c"]) < float(dry.combined()["peak_edge_c"]), "baja el pico acumulado")
	var same_first := true
	var n_first := 0
	for i in (hd["t"] as PackedFloat32Array).size():
		if float(hd["t"][i]) <= 0.3 + 1e-6:
			same_first = same_first and float(hw["c"][i]) == float(hd["c"][i])
			n_first += 1
	assert_true(same_first and n_first > 0, "la primera pasada calienta igual: el agua llega después")
	var t_dry := dry.section_temps(0)
	var t_wet := wet.section_temps(0)
	var cooler := true
	for i in t_dry.size():
		cooler = cooler and t_wet[i] <= t_dry[i] + 1e-9
	assert_true(cooler, "y al final la hoja mojada está más fría en toda la sección")


func test_el_cbn_calienta_menos_que_el_corindon() -> void:
	var drill := { "kind": "broca", "diameter_mm": 8.0, "steel_id": "m2" }
	var cbn := Sim.new({ "machine_id": "mrcm_mr_13a", "wheel": "cbn", "tool": drill })
	var al := Sim.new({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": drill })
	var peak_cbn := _hold_peak({ "machine_id": "mrcm_mr_13a", "wheel": "cbn", "tool": drill }, 10.0, 2.0)
	var peak_al := _hold_peak({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": drill }, 10.0, 2.0)
	assert_true(peak_cbn < peak_al, "broca de 8 mm, 2 s con 10 N: CBN %s °C frente a corindón %s °C" % [Js.to_fixed(peak_cbn, 0), Js.to_fixed(peak_al, 0)])
	var per_w_cbn := (peak_cbn - Heat.AMBIENT_C) / float(cbn.grind_at()["power_w"])
	var per_w_al := (peak_al - Heat.AMBIENT_C) / float(al.grind_at()["power_w"])
	assert_true(per_w_cbn < 0.5 * per_w_al, "y por vatio de amolado, menos de la mitad (ε = 0,20 frente a 0,725)")
	assert_true(float(cbn.grind_at()["partition"]) < float(al.grind_at()["partition"]), "el reparto lo explica")


func test_barrer_es_como_contactos_cortos() -> void:
	# Barriendo a 100 mm/s un contacto de 16 mm, cada punto del filo toca 0,16 s: con un filo de 184 mm y sin descanso,
	# cada sección toca 0,16 s cada 2 s, como banco_barrido_x50crmov15 (quieto 0,16 s y 1,84 s de descanso).
	var sweep := Sim.new({
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "length_mm": 184.0, "sections": 4 },
		"hand": { "motion": "barrido", "sweep_mm_s": 100.0, "passes": 5, "rest_s": 0.0, "sides": "a" },
	})
	var hold := Sim.new({
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "length_mm": 16.0, "sections": 1 },
		"hand": { "motion": "quieto", "hold_s": 0.16, "rest_s": 1.84, "passes": 5, "sides": "a" },
	})
	sweep.run_program()
	hold.run_program()
	var ps := float(sweep.combined()["peak_edge_c"])
	var ph := float(hold.combined()["peak_edge_c"])
	assert_near(ps, ph, 0.04, 0.0, "barriendo, el mismo pico que con contactos quietos de 0,16 s (%s frente a %s °C)" % [Js.to_fixed(ps, 1), Js.to_fixed(ph, 1)])
	var b := sweep.section_bevel(1)
	assert_near(float(b["contact_s"]), 5.0 * 0.16, 0.02, 0.0, "cada sección, 0,16 s de contacto por pasada")


# ─────────────────────────────── Bisel, rebaba y filo final ───────────────────────────────

func test_el_bisel_avanza_hasta_el_filo_y_sale_la_rebaba() -> void:
	var sim := Sim.new({
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "length_mm": 40.0, "sections": 2, "flat_um": 20.0 },
		"hand": { "sweep_mm_s": 100.0, "passes": 6, "rest_s": 0.2, "sides": "a", "force_n": 5.0 },
	})
	sim.threads = 1
	sim.start()
	var prev := -1.0
	var mono := true
	var burr_before_edge := false
	while sim.is_running():
		sim.advance(1.0 / 60.0)
		var b: Dictionary = sim.snapshot()["bevel"]
		mono = mono and float(b["progress_mean"]) >= prev - 1e-12
		prev = float(b["progress_mean"])
		burr_before_edge = burr_before_edge or (float(b["burr"]) > 0.0 and float(b["reached"]) <= 0.0)
	assert_true(mono, "el bisel nunca retrocede")
	assert_false(burr_before_edge, "no hay rebaba antes de llegar al filo")
	var b2: Dictionary = sim.snapshot()["bevel"]
	assert_eq(float(b2["reached"]), 1.0, "con 6 pasadas por la cara A el bisel llega al filo en toda la hoja")
	assert_eq(float(b2["burr"]), 1.0, "y sale la rebaba en todo el filo")
	assert_eq(b2["burr_side"], "B", "en la cara contraria a la que se amuela")
	assert_true(float(sim.section_bevel(0)["depth_b_um"]) == 0.0, "la cara B no se ha tocado")
	# Una pasada por la otra cara da la vuelta a la rebaba
	sim.configure({ "hand": { "sides": "b", "passes": 1 } })
	sim.run_program()
	assert_eq(sim.snapshot()["bevel"]["burr_side"], "A", "al amolar la cara B, la rebaba pasa a la A")


func test_el_cuero_quita_la_rebaba_solo_a_favor_del_filo() -> void:
	var p := {
		"machine_id": "einhell_tc_bg_150", "wheel": "fino",
		"tool": { "kind": "cuchillo", "length_mm": 40.0, "sections": 2, "flat_um": 10.0 },
		"hand": { "sweep_mm_s": 100.0, "passes": 4, "rest_s": 0.2 },
	}
	var contra := Sim.new(p)
	var favor := Sim.new(p)
	for sim: Sim in [contra, favor]:
		sim.threads = 1
		sim.run_program()
		assert_eq(float(sim.snapshot()["bevel"]["burr"]), 1.0, "rebaba antes del cuero")
	var hand := { "sweep_mm_s": 50.0, "passes": 13, "rest_s": 0.0 }
	contra.configure({ "machine_id": "tormek_t8", "wheel": "la220", "hand": hand.merged({ "direction": "contra" }) })
	favor.configure({ "machine_id": "tormek_t8", "wheel": "la220", "hand": hand.merged({ "direction": "a_favor" }) })
	var codes := []
	for w in contra.warnings():
		codes.append(w["code"])
	assert_true(codes.has("cuero_contra"), "contra el filo, en el cuero: aviso")
	contra.run_program()
	favor.run_program()
	assert_eq(float(contra.snapshot()["bevel"]["burr"]), 1.0, "contra el filo el cuero no quita la rebaba")
	var bf: Dictionary = favor.snapshot()["bevel"]
	assert_eq(float(bf["burr"]), 0.0, "a favor, 13 pasadas por el cuero quitan la rebaba")
	assert_eq(float(bf["burr_removed"]), 1.0, "en todo el filo")
	assert_eq(float(favor.section_bevel(0)["depth_a_um"]), float(contra.section_bevel(0)["depth_a_um"]), "el cuero no arranca metal")


func test_angulo_mas_bajo_rehace_el_bisel_y_mas_alto_hace_un_microbisel() -> void:
	var g := Bevel.blade({ "side_a_deg": 17.5, "side_b_deg": 17.5, "flat_um": 30.0, "shoulder_mm": 0.6, "spine_mm": 2.0, "height_mm": 40.0 })
	var both := [true, true]
	var same_a := Bevel.depth_to_edge(g, 17.5, 0.0, 17.5, 0.0, both)
	var lower := Bevel.depth_to_edge(g, 15.0, 0.0, 15.0, 0.0, both)
	var higher := Bevel.depth_to_edge(g, 20.0, 0.0, 20.0, 0.0, both)
	assert_near(2.0 * same_a, 0.030 * cos(deg_to_rad(17.5)), 1e-6, 0.0, "al mismo ángulo, las dos caras quitan el romo: 2d = t·cos β")
	assert_true(lower > 2.0 * same_a, "más bajo que el bisel: hay que rehacerlo entero (%s frente a %s µm)" % [Js.to_fixed(lower * 1000.0, 1), Js.to_fixed(same_a * 1000.0, 1)])
	assert_true(higher < same_a, "más alto: un microbisel llega antes (%s µm)" % Js.to_fixed(higher * 1000.0, 1))
	# El avance que enseña el simulador sale de la misma geometría
	var sim := Sim.new({ "machine_id": "tormek_t8", "tool": { "kind": "cuchillo", "length_mm": 60.0, "sections": 2, "flat_um": 30.0 }, "hand": { "passes": 3 } })
	sim.threads = 1
	sim.run_program()
	var sb := sim.section_bevel(0)
	var da := float(sb["depth_a_um"]) / 1000.0
	var db := float(sb["depth_b_um"]) / 1000.0
	var left := Bevel.depth_to_edge(g, 17.5, da, 17.5, db, both)
	var want := (da + db) / (da + db + 2.0 * left)
	var got := float(sim.snapshot()["bevel"]["progress"])
	assert_near(got, want, 1e-6, 1e-9, "avance del bisel = retrocedido / (retrocedido + lo que falta)")
	var ol: Dictionary = Bevel.outline(g, Bevel.faces_for(g, 17.5, 0.01, 17.5, 0.0))
	assert_false(bool(ol["sharp"]), "con 10 µm por una cara aún está romo")
	assert_eq((ol["new_a"] as Array).size(), 2, "la cara nueva A se dibuja")
	assert_true((ol["new_b"] as Array).is_empty(), "la B, sin tocar")


func test_filo_final_segun_el_ultimo_grano() -> void:
	var p := {
		"machine_id": "tormek_t8", "tool": { "kind": "cuchillo", "length_mm": 50.0, "sections": 2, "flat_um": 4.0 },
		"hand": { "sweep_mm_s": 25.0, "passes": 6 },
	}
	var sim := Sim.new(p)
	sim.threads = 1
	sim.run_program()
	var ef: Dictionary = sim.report()["edge_finish"]
	assert_eq(float(sim.snapshot()["bevel"]["reached"]), 1.0, "la piedra del Tormek llega al filo")
	assert_eq(ef["key"], "muela_200", "piedra de 220 sin cuero: el filo de la muela de 200 (Verhoeven)")
	assert_eq(float(ef["min_um"]), float(Sharpening.EDGE_FINISH["muela_200"]["min"]))
	sim.configure({ "wheel": "la220", "hand": { "direction": "a_favor", "passes": 13, "sweep_mm_s": 50.0 } })
	sim.run_program()
	var ef2: Dictionary = sim.report()["edge_finish"]
	assert_eq(ef2["key"], "muela_220_cuero", "y con el cuero, el de la muela de 220 y cuero")
	assert_eq(float(ef2["value_um"]), 0.8, "0,8 µm (Verhoeven 2004, fig. 32)")
	var bench := Sim.new({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo", "length_mm": 40.0, "sections": 2, "flat_um": 5.0 }, "hand": { "passes": 2, "sweep_mm_s": 100.0 } })
	bench.threads = 1
	bench.run_program()
	var ef3: Dictionary = bench.report()["edge_finish"]
	assert_eq(ef3["value_um"], null, "grano 60: Verhoeven no lo midió")
	assert_eq(float(ef3["min_um"]), float(Sharpening.EDGE_FINISH["muela_200"]["min"]), "como poco, el de la de 200")
	assert_true(Report.edge_finish({ "edge_tool": false }).is_empty(), "las brocas no tienen filo de Verhoeven")


# ─────────────────────────────── Quemado, informe y casos límite ───────────────────────────────

func test_quemado_por_encima_de_723() -> void:
	var sim := Sim.new({
		"machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo", "sections": 1, "length_mm": 16.0 },
		"hand": { "motion": "quieto", "hold_s": 3.0, "passes": 1 },
	})
	sim.threads = 1
	sim.run_program()
	var s := sim.snapshot()
	assert_true(bool(s["burned"]), "3 s quieto en la TC-BG 150: quemado")
	assert_true(float(s["peak_edge_c"]) >= Heat.BURN_C, "por encima de 723 °C")
	var codes := []
	for w in s["warnings"]:
		codes.append(w["code"])
	assert_true(codes.has("quemado") and codes.has("revenido"), "avisos de quemado y revenido")
	var ids := []
	for c in s["report"]["criteria"]:
		ids.append(c["id"])
	assert_true(ids.has("quemado"), "el informe lo cuenta")
	assert_true(float(s["report"]["grade"]) <= 5.0, "y suspende o casi (%s)" % s["report"]["grade_text"])


func test_informe_con_fuentes() -> void:
	var good := Sim.new({
		"machine_id": "tormek_t8", "tool": { "kind": "cuchillo", "length_mm": 50.0, "sections": 2, "flat_um": 4.0 },
		"hand": { "passes": 6 },
	})
	good.threads = 1
	var before: Dictionary = good.report()
	assert_eq(before["grade"], null, "sin ensayo no hay nota")
	assert_eq(before["grade_text"], "—")
	good.run_program()
	good.configure({ "wheel": "la220", "hand": { "direction": "a_favor", "passes": 13, "sweep_mm_s": 50.0 } })
	good.run_program()
	var r: Dictionary = good.report()
	assert_true(float(r["grade"]) >= 9.0, "Tormek, piedra y cuero: muy bien (%s)" % r["grade_text"])
	assert_eq(r["verdict"], "Muy bien afilado.")
	var ids := []
	for a in r["advice"]:
		ids.append(a["id"])
		assert_true(str(a["text"]) != "" and str(a["source"]) != "", "consejo %s con texto y fuente" % a["id"])
	for id in ["angulo", "velocidad", "abrasivo", "presion", "maquina", "rebaba", "filo_final", "seguridad"]:
		assert_true(ids.has(id), "consejo de %s" % id)
	var bad := Sim.new({ "machine_id": "einhell_te_ag_125_ce", "rpm": 12000.0, "tool": { "kind": "cuchillo", "sections": 2, "length_mm": 40.0 }, "hand": { "passes": 2 } })
	bad.threads = 1
	bad.run_program()
	var rb: Dictionary = bad.report()
	var cids := []
	for c in rb["criteria"]:
		cids.append(c["id"])
		assert_true(str(c["text"]) != "" and str(c["source"]) != "", "criterio %s con texto y fuente" % c["id"])
	assert_true(cids.has("maquina_no"), "la amoladora nunca para un cuchillo de cocina")
	assert_true(float(rb["grade"]) <= 2.0, "nota muy baja (%s)" % rb["grade_text"])
	# Exceso de velocidad: nota 0, sea lo que sea lo demás (ninguna máquina del catálogo lo permite: se prueba la rúbrica)
	var danger := Report.evaluate({ "ran": true, "kind": "cuchillo", "kind_name": "Cuchillo", "edge_tool": true, "idle": { "over_speed": true }, "bevel": { "reached": 1.0 }, "machine": { "name": "x" }, "warnings": [{ "code": "exceso_velocidad", "message": "¡Peligro!", "source": "EN 12413" }] })
	assert_eq(float(danger["grade"]), 0.0, "exceso de velocidad: 0")
	assert_true(str(danger["verdict"]).begins_with("¡Peligro!"))


func test_casos_limite() -> void:
	# Fuerza 0: la muela gira en vacío, ni calienta ni arranca
	var zero := Sim.new({ "machine_id": "einhell_tc_bg_150", "tool": { "kind": "cuchillo", "sections": 2, "length_mm": 40.0 }, "hand": { "force_n": 0.0, "passes": 2 } })
	zero.threads = 1
	zero.run_program()
	var sz := zero.snapshot()
	assert_near(float(sz["peak_edge_c"]), Heat.AMBIENT_C, 0.0, 1e-9, "sin fuerza no calienta")
	assert_eq(float(sz["bevel"]["depth_a_um"]), 0.0, "ni arranca")
	# Muela calada: gira a 0 mientras aprieta, ni calienta ni arranca, y el informe lo dice
	var stall := Sim.new({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo", "sections": 1, "length_mm": 16.0 }, "hand": { "force_n": 40.0, "motion": "quieto", "hold_s": 1.0, "passes": 1 } })
	stall.threads = 1
	stall.start()
	stall.advance(0.2)
	var mid := stall.snapshot()
	assert_true(bool(mid["stalled"]) and bool(mid["touching"]), "con 40 N se cala")
	assert_eq(float(mid["state3d"]["rpm_actual"]), 0.0, "la muela, parada")
	assert_eq(float(mid["sound"]["rpm"]), 0.0, "y suena parada")
	stall.run_program()
	assert_near(float(stall.combined()["peak_edge_c"]), Heat.AMBIENT_C, 0.0, 1e-9, "calada no calienta")
	var cids := []
	for c in stall.report()["criteria"]:
		cids.append(c["id"])
	assert_true(cids.has("se_cala"), "el informe lo cuenta")
	# Máquina desconocida, giro de más, muela mayor que la de serie y números absurdos
	var unknown := Sim.new({ "machine_id": "no_existe", "tool": { "kind": "cuchillo" } })
	assert_true(Machines.MACHINES.has(str(unknown.setup()["machine_id"])), "una máquina que no existe se cambia por una del catálogo")
	var fast := Sim.new({ "machine_id": "einhell_te_ag_125_ce", "rpm": 15000.0, "tool": { "kind": "hacha" } })
	assert_eq(float(fast.snapshot()["rpm_no_load"]), 12000.0, "la TE-AG no pasa de su posición de 12 000 rpm")
	assert_false(bool(fast.snapshot()["over_speed"]), "y así no pasa del disco (12 200 rpm)")
	var slowest := Sim.new({ "machine_id": "einhell_te_ag_125_ce", "rpm": 100.0, "tool": { "kind": "hacha" } })
	assert_eq(float(slowest.snapshot()["rpm_no_load"]), 3000.0, "ni baja de la de 3000")
	var big := Sim.new({ "machine_id": "einhell_tc_bg_150", "diameter_mm": 200.0, "tool": { "kind": "cuchillo" } })
	var bcodes := []
	for w in big.warnings():
		bcodes.append(w["code"])
	assert_true(bcodes.has("diametro"), "una muela mayor que la de serie no se monta")
	var worn := Sim.new({ "machine_id": "einhell_tc_bg_150", "diameter_mm": 100.0, "tool": { "kind": "cuchillo" } })
	var wcodes := []
	for w in worn.warnings():
		wcodes.append(w["code"])
	assert_true(wcodes.has("muela_gastada"), "por debajo del mínimo: muela gastada")
	assert_true(float(worn.snapshot()["vs_no_load_ms"]) < float(big.snapshot()["vs_no_load_ms"]), "gastada, va más despacio")
	var odd := Sim.new({ "machine_id": "einhell_tc_bg_150", "tool": { "kind": "cuchillo", "length_mm": NAN, "flat_um": -5.0, "bevel_deg": INF }, "hand": { "force_n": NAN, "passes": -3, "sweep_mm_s": 0.0, "rest_s": -1.0 } })
	var hs: Dictionary = odd.setup()["hand"]
	assert_true(int(hs["passes"]) >= 1 and float(hs["sweep_mm_s"]) > 0.0 and float(hs["rest_s"]) >= 0.0, "la mano se acota")
	odd.threads = 1
	odd.configure({ "hand": { "passes": 1, "sweep_mm_s": 200.0 } })
	odd.run_program()
	assert_true(is_finite(float(odd.snapshot()["peak_edge_c"])), "números absurdos no rompen nada")
	# Pausa, parada y cambios en marcha
	var run := _knife(1)
	run.start()
	run.advance(0.1)
	run.pause(true)
	assert_eq(run.advance(0.5), 0, "en pausa no avanza")
	assert_true(float(run.snapshot()["sound"]["pc_kw"]) == 0.0, "y en pausa no corta")
	run.pause(false)
	assert_true(run.advance(0.1) > 0, "y sigue")
	run.configure({ "hand": { "force_n": 5.0 } })
	assert_true(run.is_running(), "la fuerza cambia en marcha")
	run.configure({ "machine_id": "tormek_t8" })
	assert_false(run.is_running(), "otra máquina levanta la herramienta")
	assert_true((run.snapshot()["sound"] as Dictionary).is_empty(), "y la máquina parada no suena")


# ─────────────────────────────── Escena 3D, sonido y contratos ───────────────────────────────

func test_instantanea_escena_3d_y_sonido() -> void:
	var sim := Sim.new({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo", "steel_id": "1095" }, "hand": { "sweep_mm_s": 50.0, "passes": 2 } })
	sim.start()
	sim.advance(0.4)
	var s := sim.snapshot()
	for key in ["t_s", "running", "phase", "pass", "passes", "vs_ms", "rpm", "rpm_no_load", "max_speed_ms", "over_speed",
			"force_n", "power_w", "heat_flux_w_m2", "edge_temp_c", "max_temp_c", "peak_edge_c", "temp_band", "burned",
			"tint", "hardness", "bevel", "burr", "sparks", "sound", "warnings", "state3d", "section", "history",
			"chart_lines", "report"]:
		assert_true(s.has(key), "la instantánea trae %s" % key)
	var st: Dictionary = s["state3d"]
	for key in ["angle_deg", "force_n", "contact", "contact_pos", "edge_temp_c", "max_temp_c", "sparks", "water", "rpm_actual", "burr"]:
		assert_true(st.has(key), "set_state trae %s (CONTRATOS.md)" % key)
	assert_true(st["edge_temp_c"] is PackedFloat32Array and (st["edge_temp_c"] as PackedFloat32Array).size() == 16, "16 secciones en un cuchillo")
	assert_true(float(st["contact_pos"]) >= 0.0 and float(st["contact_pos"]) <= 1.0, "posición del contacto, de 0 a 1")
	var sp: Dictionary = st["sparks"]
	assert_true(sp.has("rate") and sp.has("color") and sp.has("length_mm"), "chispas con ritmo, color y largo")
	assert_true(bool(st["contact"]), "a los 0,4 s está tocando la muela")
	assert_true(float(sp["rate"]) > 0.0, "y salen chispas del 1095 en seco")
	assert_eq(sim.view_machine(), Machines.view("einhell_tc_bg_150", "fino", -1.0), "set_machine: el de sharpening_machines.gd")
	var vt := sim.view_tool()
	assert_true(vt["kind"] == "cuchillo" and vt.has("length_mm") and vt.has("width_mm") and vt.has("spine_mm") and vt["steel_id"] == "1095", "set_tool")
	var snd: Dictionary = s["sound"]
	for key in ["process", "rpm", "pc_kw", "pmax_kw", "coolant", "mains_hz", "speed_droop", "diameter_mm", "tool_pos"]:
		assert_true(snd.has(key), "entrada de sonido con %s" % key)
	assert_eq(snd["process"], "sharpener", "la esmeriladora suena como sharpener")
	var fr := MachineSound.frame(snd)
	assert_near(float(fr["rpm"]), float(s["rpm"]), 0.02, 0.0, "el giro que suena es el de grind() (%s rpm)" % Js.to_fixed(float(fr["rpm"]), 0))
	var grinder := Sim.new({ "machine_id": "einhell_te_ag_125_ce", "rpm": 3000.0, "tool": { "kind": "hacha" } })
	grinder.start()
	var gs: Dictionary = grinder.snapshot()["sound"]
	assert_true(gs["process"] == "grinder" and gs.get("disc_id") == "laminas", "la amoladora suena como grinder con su disco")
	var wet := Sim.new({ "machine_id": "tormek_t8", "tool": { "kind": "cuchillo" } })
	wet.start()
	assert_true(bool(wet.snapshot()["sound"]["coolant"]) and bool(wet.snapshot()["state3d"]["water"]), "la húmeda, con agua")
	var drill := Sim.new({ "machine_id": "mrcm_mr_13a", "tool": { "kind": "broca" } })
	assert_eq((drill.snapshot()["state3d"]["edge_temp_c"] as PackedFloat32Array).size(), 2, "una sección por labio")


func test_metal_duro_y_fresa_sin_temperatura() -> void:
	for p in [{ "machine_id": "mrcm_mr_x3", "tool": { "kind": "fresa" } }, { "machine_id": "mrcm_mr_13a", "wheel": "sdc", "tool": { "kind": "broca", "steel_id": "metal_duro" } }]:
		var sim := Sim.new(p)
		sim.threads = 1
		sim.run_program()
		var s := sim.snapshot()
		assert_false(bool(s["thermal"]), "%s: sin temperatura" % p["tool"]["kind"])
		assert_eq((s["edge_temp_c"] as PackedFloat32Array).size(), 0, "sin temperaturas que pintar")
		var codes := []
		for w in s["warnings"]:
			codes.append(w["code"])
		assert_true(codes.has("sin_temperatura"), "y lo dice")
		assert_true(float(s["removed_mm3"]) > 0.0, "pero sí arranca metal")
		assert_true(s["report"]["grade"] != null, "y tiene nota")


func test_sin_variables_estaticas_ni_nodos() -> void:
	for path in ["res://core/taller/sharpening_sim.gd", "res://core/taller/sharpening_bevel.gd", "res://core/taller/sharpening_report.gd"]:
		var code := code_only(FileAccess.get_file_as_string(path))
		assert_false(code.contains("static var"), "%s: sin variables estáticas (seguro para hilos)" % path)
		for bad in ["Node", "get_tree", "randf", "randi", "Time.", "OS."]:
			assert_false(code.contains(bad), "%s: sin %s (determinista y sin nodos)" % [path, bad])


func test_rendimiento() -> void:
	# Coste de un fotograma a ×1 (4 subpasos de DT) con las 16 secciones de un cuchillo, en serie y en paralelo
	var costs := {}
	for n in [1, -1]:
		var sim := Sim.new({ "machine_id": "einhell_tc_bg_150", "wheel": "fino", "tool": { "kind": "cuchillo" }, "hand": { "sweep_mm_s": 50.0, "passes": 3, "rest_s": 0.0 } })
		sim.threads = n
		sim.start()
		sim.advance(4.0 * Sim.DT)
		var t0 := Time.get_ticks_usec()
		var frames := 60
		for _i in frames:
			sim.advance(4.0 * Sim.DT)
			sim.snapshot()
		costs[n] = float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	print("    simulador de afilado, cuchillo de 16 secciones a ×1: %s ms por fotograma en serie y %s ms en paralelo (con la instantánea)" % [Js.to_fixed(costs[1], 2), Js.to_fixed(costs[-1], 2)])
	assert_true(float(costs[-1]) < 16.7, "cabe de sobra en un fotograma de 60 fps (%s ms)" % Js.to_fixed(costs[-1], 2))
