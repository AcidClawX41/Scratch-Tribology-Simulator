## Taller · la radial en modo manual (core/taller/radial_manual.gd) y su paso sin estado (Radial.cut_step y
## Radial.cut_capacity): nada arranca solo, sin contacto no se corta, lo cortado crece con el avance, el motor arranca y
## para como una radial de verdad, la rueda de velocidad no pasa de lo marcado en el disco y los avisos en directo salen
## cuando toca, con su fuente.
extends "res://tests/case.gd"

const Radial = preload("res://core/taller/radial.gd")
const RadialManual = preload("res://core/taller/radial_manual.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Panels = preload("res://core/taller/panels.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")

const DT := 1.0 / 60.0
## Campos numéricos de cut_panel que cut_step tiene que dar igual a profundidad completa.
const SAME_FIELDS := ["vs_ms", "kerf_mm", "kerf_surface_mm", "burr_um", "haz_mm", "paint_burn_mm", "disc_loading",
	"deformation", "cleanliness", "smoke", "melt", "front_temp_c", "feed_mm_s", "power_kw", "q_mm3_s",
	"specific_energy_j_mm3", "heat_j_mm"]
const SAME_DICTS := ["sparks", "heat_tint", "burr_sides_um"]


# ─────────────────────────────── ayudantes ───────────────────────────────

func _run(m: RadialManual, seconds: float) -> Dictionary:
	var f: Dictionary = m.frame
	for i in int(round(seconds / DT)):
		f = m.step(DT)
	return f


## Enciende, espera a que el disco llegue a su giro y lo mete hasta `extra_mm` por debajo de la chapa (a `speed` mm/s
## cerca de ella, como se hace con cuidado).
func _plunge_through(m: RadialManual, extra_mm: float = 3.0, speed: float = 1.0) -> Dictionary:
	m.set_trigger(true)
	_run(m, 2.0)
	m.move_hand(0.0, -m.hand_depth - 1.0)
	_run(m, 0.2)
	var goal: float = float(m.frame["total_mm"]) + extra_mm
	m.set_hand_velocity(0.0, speed)
	var guard := 0
	while m.depth_mm < goal - 1e-3 and guard < 3000:
		if m.hand_depth >= goal:
			m.set_hand_velocity(0.0, 0.0)
		m.step(DT)
		guard += 1
	m.set_hand_velocity(0.0, 0.0)
	return _run(m, 0.3)


static func _codes(f: Dictionary) -> Array:
	var out: Array = []
	for w in f["warnings"]:
		out.append(w["code"])
	return out


# ─────────────────────────────── paso sin estado (radial.gd) ───────────────────────────────

## A profundidad completa, cut_step es cut_panel sin la longitud: mismos números (al bit) para todos los discos y
## chapas del modo manual, con avances que no llegan al límite y con avances limitados por la potencia o el empuje.
func test_cut_step_es_cut_panel_a_profundidad_completa() -> void:
	var n := 0
	for disc in RadialManual.DISCS:
		for panel in RadialManual.PANELS:
			for feed in [3.0, 25.0, 400.0]:
				for ang in [0.0, 15.0, -30.0]:
					var p := { "disc_id": disc, "panel_id": panel, "diameter_mm": 125.0, "rpm": 9000.0, "angle_deg": ang,
						"feed_mm_s": feed, "cut_length_mm": 100.0 }
					var a := Radial.cut_panel(p)
					var b := Radial.cut_step(p)
					for k in SAME_FIELDS:
						assert_true(float(a[k]) == float(b[k]), "%s/%s a %s mm/s y %s°: %s %s ≠ %s" % [disc, panel, feed, ang, k, a[k], b[k]])
					for k in SAME_DICTS:
						assert_true(same(a[k], b[k]), "%s/%s: %s" % [disc, panel, k])
					n += 1
	assert_eq(n, 378, "6 discos × 7 chapas × 3 avances × 3 ángulos")


## Surco que aún no atraviesa: sin rebaba en la cara de salida, calor por mm proporcional a lo que arranca y caudal =
## avance × surco × profundidad. Con avance 0 no corta (no es el «máximo» de cut_panel).
func test_cut_step_parcial() -> void:
	var base := { "disc_id": "fino_1mm", "panel_id": "acero-dulce", "diameter_mm": 125.0, "rpm": 11000.0, "feed_mm_s": 10.0 }
	var full := Radial.cut_step(base)
	var half := Radial.cut_step(base.merged({ "depth_mm": 0.5 }, true))
	assert_true(bool(full["through"]) and not bool(half["through"]), "a profundidad completa atraviesa; a 0,5 mm, no")
	assert_eq(float(half["burr_um"]), 0.0, "un surco sin atravesar no deja rebaba en la cara de salida")
	assert_near(float(half["q_mm3_s"]), 10.0 * float(half["kerf_surface_mm"]) * 0.5, 1e-12, 1e-12, "caudal = avance · surco · profundidad")
	assert_true(float(half["heat_j_mm"]) < float(full["heat_j_mm"]) and float(half["heat_j_mm"]) > 0.0, "menos calor por mm con menos profundidad")
	assert_true(float(half["haz_mm"]) <= float(full["haz_mm"]), "y una zona caliente más estrecha")
	var none := Radial.cut_step(base.merged({ "feed_mm_s": 0.0 }, true))
	assert_false(bool(none["cutting"]), "sin avance no corta")
	assert_eq(float(none["q_mm3_s"]), 0.0, "caudal cero")
	for k in ["time_s", "disc_wear_mm3", "sources"]:
		assert_false(full.has(k), "cut_step no lleva %s (depende de la longitud)" % k)
	assert_near(float(full["wear_mm3_per_mm3"]), 0.2, 1e-12, 0.0, "disco de resina en acero dulce: G = 5 (1/G = 0,2)")


## cut_capacity es el caudal máximo de cut_panel (avance 0 = el máximo que dan la potencia y el empuje), sea cual sea la
## profundidad.
func test_cut_capacity_es_el_maximo() -> void:
	for panel in ["acero-dulce", "boro-22mnb5", "aluminio"]:
		var p := { "disc_id": "fino_1mm", "panel_id": panel, "diameter_mm": 125.0, "rpm": 11000.0, "feed_mm_s": 0.0 }
		var cap := Radial.cut_capacity(p)
		var full := Radial.cut_panel(p)
		assert_near(float(cap["q_cap_mm3_s"]), float(full["q_mm3_s"]), 1e-12, 0.0, "%s: q máximo" % panel)
		assert_eq(cap["limited_by"], full["limited_by"], "%s: lo que limita" % panel)
	assert_eq(Radial.cut_capacity({ "disc_id": "fino_1mm", "panel_id": "boro-22mnb5", "rpm": 11000.0 })["limited_by"], "empuje", "el pilar de boro lo frena el empuje (Archard)")
	var stopped := Radial.cut_capacity({ "disc_id": "fino_1mm", "panel_id": "acero-dulce", "rpm": 0.0 })
	assert_eq(float(stopped["q_cap_mm3_s"]), 0.0, "disco parado: no arranca nada")
	# Los dos límites por separado: el caudal es el menor; el del empuje es proporcional al empuje (Archard) y, cuando lo
	# que limita es la potencia, arrancar lo que da el empuje pediría más potencia de la útil
	var base := { "disc_id": "fino_1mm", "panel_id": "acero-dulce", "rpm": 11500.0, "power_kw": 0.64 }
	var c30 := Radial.cut_capacity(base.merged({ "push_n": 30.0 }, true))
	var c15 := Radial.cut_capacity(base.merged({ "push_n": 15.0 }, true))
	assert_near(float(c30["q_cap_mm3_s"]), minf(float(c30["q_power_mm3_s"]), float(c30["q_push_mm3_s"])), 1e-12, 0.0, "el menor de los dos límites")
	assert_near(2.0 * float(c15["q_push_mm3_s"]), float(c30["q_push_mm3_s"]), 1e-9, 0.0, "el del empuje, proporcional al empuje")
	assert_eq(c30["limited_by"], "potencia", "con 30 N en acero dulce limita la potencia")
	assert_true(float(c30["push_power_kw"]) > 0.64, "y ese empuje pediría más de los 640 W útiles (%s kW)" % c30["push_power_kw"])
	assert_eq(c15["limited_by"], "empuje", "con 15 N, el empuje")
	assert_true(float(c15["push_power_kw"]) < 0.64, "y la potencia alcanza (%s kW)" % c15["push_power_kw"])


# ─────────────────────────────── modo manual ───────────────────────────────

## Nada arranca solo: recién creada, la radial está apagada, parada y apartada de la chapa, y así sigue sin tocar nada.
func test_empieza_apagada_y_apartada() -> void:
	var m := RadialManual.new()
	var f: Dictionary = m.frame
	assert_eq(f["state"], "apagada", "apagada")
	assert_false(bool(f["trigger"]), "sin el dedo en el gatillo")
	assert_eq(float(f["rpm"]), 0.0, "parada")
	assert_true(float(f["depth_mm"]) < 0.0 and float(f["gap_mm"]) > 10.0, "apartada de la chapa (%s mm)" % f["gap_mm"])
	assert_false(bool(f["contact"]), "sin tocar la chapa")
	f = _run(m, 3.0)
	assert_eq(float(f["rpm"]), 0.0, "sin tocar nada no gira")
	assert_eq(float(f["cut_length_mm"]), 0.0, "ni corta")
	assert_eq(float(f["sound"]["rpm"]), 0.0, "ni suena el motor")
	assert_eq(_codes(f), [], "sin avisos")


## Arranque con la corriente limitada (el 95 % del giro en SPINUP_S = 1,5 s, el centro de los «ca. 1-2 s» de un arranque
## suave) y parada por inercia al soltar el gatillo (sin freno: la mediana de 5,9 s medida en 11 radiales), con el aviso
## de que el disco sigue girando.
func test_arranque_y_parada_por_inercia() -> void:
	var m := RadialManual.new()
	m.set_trigger(true)
	var prev := 0.0
	var n_set: float = m.set_rpm()
	assert_eq(n_set, 11500.0, "GWS 12-125 CIE en la posición 6 de la rueda: 11.500 rpm (Bosch)")
	for i in 90:
		var f := m.step(DT)
		assert_true(float(f["rpm"]) >= prev, "el giro solo sube al arrancar")
		if i == 29:
			assert_true(float(f["rpm"]) < 0.7 * n_set, "no de golpe: a los 0,5 s aún no pasa del 70 %% (%s rpm)" % f["rpm"])
		prev = float(f["rpm"])
	assert_true(prev >= 0.949 * n_set and prev < n_set, "en 1,5 s llega al 95 %% del giro (%s rpm)" % prev)
	_run(m, 0.2)
	assert_eq(m.frame["state"], "en_marcha", "en marcha")
	prev = float(m.frame["rpm"])
	m.set_trigger(false)
	var f2 := m.step(DT)
	assert_true(float(f2["rpm"]) > 0.9 * prev, "al soltar el gatillo no se para de golpe")
	assert_true(_codes(f2).has("inercia"), "aviso: sigue girando por inercia")
	assert_eq(f2["state"], "parando", "parando")
	var t := DT
	while float(m.frame["rpm"]) > 0.0 and t < 30.0:
		var r := float(m.frame["rpm"])
		m.step(DT)
		assert_true(float(m.frame["rpm"]) <= r, "solo baja")
		t += DT
	assert_near(t, RadialManual.COAST_STOP_S, 0.0, 0.4, "sin freno, tarda lo que la mediana medida (5,9 s) en pararse (%s s)" % t)
	assert_eq(m.frame["state"], "apagada", "parada")


## Sin contacto no se corta: el disco en marcha, a un milímetro por encima de la chapa, recorre toda la línea sin
## arrancar nada ni echar chispas.
func test_sin_contacto_no_se_corta() -> void:
	var m := RadialManual.new()
	m.set_trigger(true)
	_run(m, 1.5)
	m.move_hand(-40.0, -m.hand_depth - 1.0)
	_run(m, 0.3)
	m.set_hand_velocity(40.0, 0.0)
	var f := _run(m, 6.0)
	assert_true(float(f["u_mm"]) > 200.0, "ha recorrido la línea (u = %s mm)" % f["u_mm"])
	assert_false(bool(f["contact"]), "sin tocar la chapa")
	assert_eq(float(f["cut_length_mm"]), 0.0, "nada cortado")
	assert_eq(float(f["groove_length_mm"]), 0.0, "ni rayado")
	assert_eq(float(m.removed_mm3), 0.0, "nada arrancado")
	assert_eq(float(f["sparks"]["rate"]), 0.0, "sin chispas")
	for i in m.n:
		assert_true(m.depth_at(i) == 0.0, "mapa del surco vacío")


## Lo cortado crece con el avance (y nunca baja): con el disco atravesando la chapa, cada milímetro que avanza es un
## milímetro más de corte; más recorrido nunca da menos longitud cortada.
func test_la_longitud_cortada_crece_con_el_avance() -> void:
	var m := RadialManual.new()
	var f := _plunge_through(m)
	var start_len := float(f["cut_length_mm"])
	assert_true(start_len > 10.0, "al atravesar ya hay corte bajo el disco (%s mm)" % start_len)
	var u0 := float(f["u_mm"])
	m.set_hand_velocity(10.0, 0.0)
	var prev := start_len
	for i in 300:
		f = m.step(DT)
		assert_true(float(f["cut_length_mm"]) >= prev, "la longitud cortada nunca baja")
		prev = float(f["cut_length_mm"])
	m.set_hand_velocity(0.0, 0.0)
	f = _run(m, 0.5)
	var moved := float(f["u_mm"]) - u0
	assert_near(moved, 50.0, 0.0, 1.0, "a 10 mm/s durante 5 s avanza 50 mm (%s)" % moved)
	assert_near(float(f["cut_length_mm"]) - start_len, moved, 0.0, 0.6, "cada mm de avance es un mm más de corte")
	assert_true(float(f["cleanliness"]) >= 0.0 and float(f["cleanliness"]) <= 10.0, "limpieza de 0 a 10")
	assert_true(float(f["disc_wear_mm3"]) > 0.0, "el disco se gasta")
	assert_near(float(f["disc_wear_mm3"]), m.removed_mm3 / 5.0, 1e-9, 1e-9, "desgaste = volumen arrancado / G (G = 5)")


## El avance real es el de la mano mientras el disco puede con él; si la mano va más deprisa de lo que el disco arranca
## empujando a fondo, «demasiado avance». En acero dulce con el disco fino lo que limita es la potencia: ese empuje pide
## algo más de la que da el motor, que pierde vueltas hasta que se equilibran (lo que arranca el empuje baja con el giro)
## y sigue cortando. En el plástico, empujar a fondo pide más del triple: el giro cae de golpe y la desconexión por
## rebote corta la corriente (Bosch). Para volver a arrancar hay que soltar el gatillo; arrancar dentro del corte da su
## propio aviso.
func test_demasiado_avance_y_desconexion_por_rebote() -> void:
	var m := RadialManual.new()
	_plunge_through(m)
	m.set_hand_velocity(12.0, 0.0)
	var f := _run(m, 2.0)
	assert_near(float(f["feed_mm_s"]), 12.0, 0.0, 0.5, "el disco sigue a la mano (%s mm/s)" % f["feed_mm_s"])
	assert_true(float(f["feed_cap_mm_s"]) > 12.0, "por debajo de lo que puede arrancar")
	assert_false(_codes(f).has("demasiado_avance"), "sin aviso de avance")
	assert_true(float(f["power_kw"]) > 0.0 and float(f["power_kw"]) <= float(f["machine_power_kw"]) + 1e-9, "potencia de corte dentro de lo que da la radial")
	assert_near(float(f["rpm"]), float(f["rpm_set"]), 0.0, 1.0, "la electrónica de giro constante lo sostiene")
	m.set_hand_velocity(100.0, 0.0)
	f = _run(m, 0.25)
	assert_true(_codes(f).has("demasiado_avance"), "aviso de demasiado avance: %s" % [_codes(f)])
	assert_near(float(f["push_n"]), Radial.PUSH_N, 1e-9, 1e-9, "empujando a fondo")
	assert_eq(f["limited_by"], "potencia", "lo limita la potencia")
	assert_true(float(f["power_deficit_kw"]) > 0.0, "ese empuje pide más potencia de la que hay")
	assert_true(float(f["rpm"]) < 0.99 * float(f["rpm_set"]), "el motor pierde vueltas (%s rpm)" % f["rpm"])
	assert_true(float(f["feed_mm_s"]) < 30.0, "el disco no va tan deprisa como la mano")
	f = _run(m, 3.0)
	assert_false(bool(f["tripped"]), "no se desconecta: el giro baja poco a poco")
	assert_true(float(f["rpm"]) > 0.75 * float(f["rpm_set"]) and float(f["rpm"]) < 0.98 * float(f["rpm_set"]), "y se queda donde el empuje pide lo que da el motor (%s rpm)" % f["rpm"])
	assert_near(float(f["power_deficit_kw"]), 0.0, 0.0, 0.01, "ya casi sin falta de potencia")
	assert_true(bool(f["cutting"]), "sigue cortando")
	# En el plástico, empujar a fondo pide mucha más potencia de la que hay: el giro cae de golpe
	var mp := RadialManual.new("fino_1mm", "plastico-carroceria")
	_plunge_through(mp, 3.0, 0.3)
	assert_false(bool(mp.frame["tripped"]), "entra en el plástico sin desconectarse")
	mp.set_hand_velocity(100.0, 0.0)
	var t := 0.0
	while not bool(mp.frame["tripped"]) and t < 2.0:
		f = mp.step(DT)
		t += DT
	assert_true(bool(f["tripped"]), "el giro cae de golpe y la radial corta la corriente (a los %s s)" % t)
	assert_true(_codes(f).has("desconexion_rebote"), "con su aviso")
	assert_eq(mp.jams, 1, "un bloqueo")
	m = mp
	f = _run(m, 1.0)
	assert_eq(float(f["rpm"]), 0.0, "disco parado")
	m.set_hand_velocity(0.0, 0.0)
	m.set_trigger(false)
	f = m.step(DT)
	assert_false(bool(f["tripped"]), "al soltar el gatillo se puede volver a arrancar")
	m.set_trigger(true)
	f = m.step(DT)
	assert_true(_codes(f).has("arranque_en_corte"), "arrancar con el disco dentro del corte: aviso")
	var src := ""
	for w in f["warnings"]:
		if w["code"] == "arranque_en_corte":
			src = w["source"]
	assert_true(src.contains("EN 62841-2-3"), "con su fuente: %s" % src)


## El empuje de la mano: sin empuje el disco no arranca nada aunque esté metido en el surco; más avance pide más empuje
## (hasta Radial.PUSH_N) y, mientras la potencia alcanza, la electrónica de giro constante sostiene el giro (Bosch).
func test_el_empuje_de_la_mano() -> void:
	var m := RadialManual.new()
	_plunge_through(m)
	var f := _run(m, 1.0)
	var removed := m.removed_mm3
	f = _run(m, 0.5)
	assert_eq(m.removed_mm3, removed, "con la mano quieta, sin empujar, no arranca nada")
	assert_eq(float(f["push_n"]), 0.0, "sin empuje")
	var pushes: Array = []
	for v in [4.0, 8.0, 12.0]:
		m.set_hand_velocity(v, 0.0)
		f = _run(m, 1.0)
		pushes.append(float(f["push_n"]))
		assert_near(float(f["feed_mm_s"]), v, 0.0, 0.5, "sigue a la mano a %s mm/s" % v)
		assert_near(float(f["rpm"]), float(f["rpm_set"]), 0.0, 1.0, "giro sostenido a %s mm/s" % v)
		assert_eq(float(f["power_deficit_kw"]), 0.0, "la potencia alcanza a %s mm/s" % v)
	assert_true(pushes[0] > 0.0 and pushes[0] < pushes[1] and pushes[1] < pushes[2] and pushes[2] <= Radial.PUSH_N,
		"más avance, más empuje: %s N" % [pushes])


## Cuanto más pide el empuje por encima de la potencia, antes pierde vueltas el motor (balance de energía del rotor); si
## lo que limita es el empuje (Archard: el DP800 es duro), empujar a fondo no frena el motor ni lo desconecta.
func test_la_falta_de_potencia_frena_el_motor() -> void:
	var rpm_after := {}
	var deficit := {}
	for panel in ["acero-dulce", "aluminio"]:
		var m := RadialManual.new("fino_1mm", panel)
		_plunge_through(m, 3.0, 0.3)
		assert_false(bool(m.frame["tripped"]), "%s: entra sin desconectarse" % panel)
		m.set_hand_velocity(100.0, 0.0)
		var f := _run(m, 0.3)
		deficit[panel] = float(f["power_deficit_kw"])
		rpm_after[panel] = float(f["rpm"])
		assert_true(float(deficit[panel]) > 0.0, "%s: falta potencia" % panel)
	assert_true(float(deficit["aluminio"]) > float(deficit["acero-dulce"]), "en el aluminio falta más: %s" % [deficit])
	assert_true(float(rpm_after["aluminio"]) < float(rpm_after["acero-dulce"]), "y el motor pierde más vueltas: %s" % [rpm_after])
	var m2 := RadialManual.new("fino_1mm", "dp800")
	_plunge_through(m2, 3.0, 0.3)
	m2.set_hand_velocity(100.0, 0.0)
	var f2 := _run(m2, 2.0)
	assert_true(_codes(f2).has("demasiado_avance"), "demasiado avance también: %s" % [_codes(f2)])
	assert_eq(f2["limited_by"], "empuje", "pero lo limita el empuje")
	assert_eq(float(f2["power_deficit_kw"]), 0.0, "sin falta de potencia")
	assert_near(float(f2["rpm"]), float(f2["rpm_set"]), 0.0, 1.0, "el giro no cae")
	assert_false(bool(f2["tripped"]), "ni se desconecta")


## La radial de 230 mm no tiene desconexión por rebote (no consta en sus datos) ni electrónica de giro constante: con
## carga cae de vueltas (hasta un 30 % a plena carga) y, si el disco se bloquea en el surco (torcido dentro de él), el
## motor se cala; al sacar el disco se puede volver a arrancar.
func test_la_radial_grande_se_cala() -> void:
	var m := RadialManual.new("grueso_3mm", "acero-dulce", 230.0)
	assert_false(bool(m.machine()["kickback_stop"]), "sin desconexión por rebote")
	_plunge_through(m, 3.0, 0.3)
	m.set_hand_velocity(4.0, 0.0)
	var f := _run(m, 5.0)
	assert_true(bool(f["cutting"]), "corta")
	assert_true(float(f["rpm"]) < float(f["rpm_set"]) - 1.0, "con carga cae de vueltas (%s de %s rpm)" % [f["rpm"], f["rpm_set"]])
	var droop := 1.0 - float(f["rpm"]) / float(f["rpm_set"])
	assert_near(droop, RadialManual.DROOP_FULL_LOAD * float(f["load"]), 0.0, 0.03, "la caída del motor universal (%s)" % droop)
	m.set_hand_velocity(0.0, 0.0)
	_run(m, 0.3)
	m.turn_hand(8.0, 0.0)
	f = m.step(DT)
	assert_true(bool(f["stalled"]), "torcido dentro del surco, se bloquea y se cala")
	assert_eq(f["state"], "calada", "calada")
	assert_true(_codes(f).has("rebote"), "con el aviso del rebote: %s" % [_codes(f)])
	f = _run(m, 0.5)
	assert_eq(float(f["rpm"]), 0.0, "disco parado")
	m.move_hand(0.0, -40.0)
	f = _run(m, 0.5)
	assert_false(bool(f["stalled"]), "al sacar el disco deja de estar calada")


## Un disco parado no corta: al empujarlo contra la chapa se queda en la superficie y el modelo lo dice.
func test_disco_parado_no_entra() -> void:
	var m := RadialManual.new()
	m.move_hand(0.0, -m.hand_depth + 2.0)
	var f := _run(m, 1.0)
	assert_true(float(f["depth_mm"]) <= 1e-6, "se queda en la cara pintada (%s mm)" % f["depth_mm"])
	assert_eq(m.removed_mm3, 0.0, "sin arrancar nada")
	assert_true(_codes(f).has("sin_corte"), "aviso del modelo: el disco no gira (%s)" % [_codes(f)])


## La rueda de velocidad nunca pasa de las rpm marcadas en el disco: con el disco de CBN (50 m/s, 7.639 rpm en 125 mm)
## la radial se queda en su límite y, si se pide más, sale el aviso de EN 12413 (y el de disco para máquina fija).
func test_la_rueda_no_pasa_de_lo_marcado() -> void:
	var m := RadialManual.new("cbn_1mm")
	var limit: float = m.disc_limit_rpm()
	assert_near(limit, 60000.0 * 50.0 / (PI * 125.0), 1e-9, 0.0, "límite del CBN por la fórmula (50 m/s)")
	m.set_dial_rpm(11500.0)
	m.set_trigger(true)
	var f := _run(m, 2.0)
	assert_true(float(f["rpm"]) <= limit + 1e-9, "nunca por encima del límite (%s rpm)" % f["rpm"])
	assert_near(float(f["rpm_set"]), limit, 1e-12, 0.0, "la rueda se queda en el límite")
	assert_true(_codes(f).has("exceso_velocidad"), "aviso de exceso de velocidad")
	assert_true(_codes(f).has("disco_fijo"), "y de disco para tronzadora fija")
	var src := ""
	for w in f["warnings"]:
		if w["code"] == "exceso_velocidad":
			src = w["source"]
			assert_eq(w["level"], "peligro", "es un peligro")
	assert_true(src.contains("EN 12413"), "fuente EN 12413: %s" % src)
	m.set_dial_rpm(6300.0)
	f = _run(m, 1.0)
	assert_false(_codes(f).has("exceso_velocidad"), "a 6.300 rpm (posición 3), sin aviso")
	assert_near(float(f["dial_pos"]), 3.0, 1e-9, 0.0, "posición 3 de la rueda")
	# La rueda de la GWS 12-125 CIE (Bosch): 2.800 … 11.500 rpm en 6 posiciones
	var mach := RadialManual.machine_for(125.0)
	assert_eq(RadialManual.dial_rpm_at(mach, 1.0), 2800.0, "posición 1")
	assert_eq(RadialManual.dial_rpm_at(mach, 6.0), 11500.0, "posición 6")
	assert_eq(RadialManual.dial_step_rpm(mach, 8200.0, 1), 9800.0, "una muesca arriba: de 4 a 5")
	assert_eq(RadialManual.dial_step_rpm(mach, 7000.0, -1), 6300.0, "desde una posición intermedia, a la entera de abajo")


## Radial de 230 mm (disco de diamante de 230): sin rueda de velocidad, gira a sus 6.500 rpm.
func test_radial_grande_sin_rueda() -> void:
	var m := RadialManual.new("diamante", "acero-dulce", 230.0)
	var f: Dictionary = m.frame
	assert_eq(f["machine"], "Bosch GWS 22-230 P", "la radial de 230 mm")
	assert_false(bool(f["dial"]), "sin rueda de velocidad")
	m.set_dial_rpm(3000.0)
	assert_eq(m.set_rpm(), 6500.0, "gira a sus rpm aunque se pida otra cosa")


## Torcer el disco dentro del surco lo pellizca (la holgura es de 0,4 mm) y, torcido de más, lo bloquea.
func test_torcer_el_disco_en_el_surco() -> void:
	var m := RadialManual.new()
	_plunge_through(m)
	m.set_hand_velocity(10.0, 0.0)
	_run(m, 1.0)
	m.set_hand_velocity(0.0, 0.0)
	var f := _run(m, 0.3)
	assert_false(_codes(f).has("pellizco"), "alineado, sin pellizco")
	m.turn_hand(1.0, 0.0)
	f = m.step(DT)
	assert_true(_codes(f).has("pellizco"), "torcido 1°, roza las paredes: %s" % [_codes(f)])
	assert_true(float(f["pinch_mm"]) > 0.0, "se mete en la pared")
	m.turn_hand(5.0, 0.0)
	f = m.step(DT)
	assert_true(bool(f["tripped"]), "torcido 6°, se bloquea")


## Las chispas salen por donde el borde del disco deja el material, en su sentido de giro: avanzando a favor del giro,
## por arriba; en contra y atravesando la chapa, por debajo (hacia dentro del coche y el combustible derramado).
func test_hacia_donde_salen_las_chispas() -> void:
	var m := RadialManual.new()
	m.move_hand(70.0, 0.0)  # en mitad de la chapa (u = 100 mm), lejos de los cantos
	_run(m, 0.5)
	_plunge_through(m)
	m.set_hand_velocity(10.0, 0.0)
	var f := _run(m, 1.0)
	assert_eq(f["spark_exit"]["side"], "arriba", "a favor del giro, por la cara pintada")
	assert_true((f["spark_exit"]["dir"] as Vector3).x > 0.5 and (f["spark_exit"]["dir"] as Vector3).y > 0.0, "hacia delante y arriba")
	assert_false(_codes(f).has("chispas_combustible"), "sin aviso de combustible")
	m.set_hand_velocity(-10.0, 0.0)
	f = _run(m, 1.5)
	assert_true(bool(f["cutting"]), "sigue cortando al volver (el disco atraviesa)")
	assert_eq(f["spark_exit"]["side"], "abajo", "en contra del giro, por debajo")
	assert_true((f["spark_exit"]["dir"] as Vector3).y < 0.0, "hacia abajo")
	assert_true(_codes(f).has("chispas_combustible"), "aviso: chispas hacia el combustible")
	# Dada la vuelta (180°), el giro se invierte respecto al corte: ahora es al revés
	m.flip()
	assert_near(absf(m.yaw_deg), 180.0, 0.0, 1e-9, "dada la vuelta")
	f = _run(m, 1.0)
	assert_eq(f["spark_exit"]["side"], "arriba", "dada la vuelta, yendo hacia −u las chispas salen por arriba")
	assert_true((f["spark_exit"]["dir"] as Vector3).x < 0.0, "hacia −u")


## En una pieza de rescate, las chispas hacia el generador de gas del airbag (el ejemplo, más allá del extremo del
## pilar) dan su aviso; dándole la vuelta a la radial dejan de ir hacia él.
func test_chispas_hacia_el_airbag() -> void:
	var m := RadialManual.new("fino_1mm", "boro-22mnb5")
	m.set_trigger(true)
	_run(m, 1.5)
	m.move_hand(150.0, 0.0)
	_run(m, 1.0)
	m.move_hand(0.0, -m.hand_depth - 1.0)
	_run(m, 0.2)
	m.set_hand_velocity(0.0, 0.5)
	var f: Dictionary = {}
	for i in 600:
		f = m.step(DT)
		if bool(f["cutting"]) and _codes(f).has("chispas_airbag"):
			break
	assert_true(_codes(f).has("chispas_airbag"), "chispas hacia el airbag: %s" % [_codes(f)])
	m.set_hand_velocity(0.0, 0.0)
	m.move_hand(0.0, -40.0)
	_run(m, 1.0)
	m.flip()
	m.move_hand(0.0, 38.0 + 1.0)
	m.set_hand_velocity(0.0, 0.5)
	var seen := false
	for i in 300:
		f = m.step(DT)
		if bool(f["cutting"]) and _codes(f).has("chispas_airbag"):
			seen = true
	assert_false(seen, "dada la vuelta, las chispas ya no van hacia el airbag")


## El disco de láminas no tronza: toca la chapa y no entra (con el aviso del modelo).
func test_el_disco_de_laminas_no_corta() -> void:
	var m := RadialManual.new("laminas")
	m.set_trigger(true)
	_run(m, 1.5)
	m.move_hand(0.0, -m.hand_depth + 2.0)
	var f := _run(m, 1.0)
	assert_true(float(f["depth_mm"]) <= 1e-9, "se queda en la superficie")
	assert_eq(m.removed_mm3, 0.0, "no arranca nada")
	assert_true(_codes(f).has("disco_no_corta"), "aviso del modelo: no es para tronzar (%s)" % [_codes(f)])


## Cambiar de disco o de diámetro no borra el corte; otra chapa (o «Reiniciar chapa») sí empieza sin cortar.
func test_cambios_sin_reiniciar_y_chapa_nueva() -> void:
	var m := RadialManual.new()
	_plunge_through(m)
	m.set_hand_velocity(10.0, 0.0)
	_run(m, 1.0)
	m.set_hand_velocity(0.0, 0.0)
	var cut := float(m.frame["cut_length_mm"])
	assert_true(cut > 0.0, "hay corte")
	m.set_disc("grueso_3mm")
	var f := m.step(DT)
	assert_true(float(f["cut_length_mm"]) >= cut, "otro disco: el corte se queda")
	assert_eq(float(f["disc_wear_mm3"]), 0.0, "el disco nuevo, sin gastar")
	assert_eq(f["state"], "apagada", "para cambiar el disco la radial se para")
	assert_true(float(f["depth_mm"]) < 0.0, "y se saca de la chapa")
	assert_near(float(f["kerf_mm"]), 3.2 + Radial.KERF_EXTRA_MM, 1e-12, 0.0, "el surco del disco grueso")
	var v0 := m.map_version
	m.set_diameter(115.0)
	f = m.step(DT)
	assert_true(float(f["cut_length_mm"]) >= cut, "otro diámetro: el corte se queda")
	m.set_panel("aluminio")
	f = m.step(DT)
	assert_eq(float(f["cut_length_mm"]), 0.0, "otra chapa: sin cortar")
	assert_true(m.map_version > v0, "el mapa cambia de versión (la escena sube su textura)")
	m.set_panel("acero-dulce")
	m.reset_panel()
	assert_eq(float(m.step(DT)["cut_length_mm"]), 0.0, "chapa reiniciada")
	m.park()
	f = m.frame
	assert_eq(f["state"], "apagada", "aparcada: apagada")
	assert_true(float(f["depth_mm"]) < 0.0, "y apartada")


## Determinista: la misma secuencia de entradas da la misma salida, al bit.
func test_determinista() -> void:
	var runs: Array = []
	for r in 2:
		var m := RadialManual.new("fino_1mm", "dp800")
		_plunge_through(m)
		m.set_hand_velocity(14.0, 0.0)
		m.turn_hand(0.0, 8.0)
		_run(m, 1.5)
		runs.append([m.frame["rpm"], m.frame["u_mm"], m.frame["cut_length_mm"], m.frame["cleanliness"], m.removed_mm3,
			m.disc_wear_mm3, m.texture_data()])
	assert_true(same(runs[0], runs[1]), "dos ejecuciones iguales")


## La salida lleva la entrada de sonido de la radial (proceso «grinder», rpm reales y potencia de corte): en vacío suena
## el motor y cortando sube el ruido del corte (MachineSound.frame).
func test_entrada_de_sonido() -> void:
	var m := RadialManual.new()
	m.set_trigger(true)
	var idle := _run(m, 1.5)
	var s_idle: Dictionary = idle["sound"]
	assert_eq(s_idle["process"], "grinder", "proceso de la radial")
	assert_eq(float(s_idle["rpm"]), float(idle["rpm"]), "rpm reales")
	assert_eq(float(s_idle["pc_kw"]), 0.0, "en vacío, sin potencia de corte")
	assert_eq(float(s_idle["speed_droop"]), 0.0, "la caída de vueltas ya va en las rpm (no se aplica dos veces)")
	var cut := _plunge_through(m)
	m.set_hand_velocity(12.0, 0.0)
	cut = _run(m, 1.0)
	var s_cut: Dictionary = cut["sound"]
	assert_near(float(s_cut["pc_kw"]), float(cut["power_kw"]), 1e-12, 0.0, "potencia de corte del modelo")
	var fr_idle := MachineSound.frame(s_idle)
	var fr_cut := MachineSound.frame(s_cut)
	assert_true(float(fr_idle["tones"][0]["gain"]) > 0.0, "en vacío suena el motor")
	assert_eq(float(fr_idle["noise"]["gain"]), 0.0, "sin ruido de corte en vacío")
	assert_true(float(fr_cut["noise"]["gain"]) > 0.0, "cortando, ruido de corte")
	var off := MachineSound.frame(RadialManual.new().frame["sound"])
	assert_eq(float(off["tones"][0]["gain"]), 0.0, "apagada, en silencio")


## El mapa del surco que sube la escena (textura de 2 filas × n muestras × RGBA) y la inclinación con la que se cortó.
func test_mapa_para_la_escena() -> void:
	var m := RadialManual.new()
	assert_eq(m.texture_data().size(), m.n * 8, "2 filas × n × 4 floats")
	assert_eq(m.n, int(round(RadialManual.LINE_MM / RadialManual.DU_MM)) + 1, "una muestra cada 0,25 mm")
	m.turn_hand(0.0, 20.0)
	_plunge_through(m)
	var data := m.texture_data()
	var i := int(round(m.u_mm / RadialManual.DU_MM))
	assert_near(data[i * 4], float(m.frame["total_mm"]), 1e-6, 1e-6, "atravesada bajo el disco")
	assert_near(data[i * 4 + 2], tan(deg_to_rad(20.0)), 1e-6, 1e-6, "surco inclinado 20°")
	assert_true(data[i * 4 + 3] > 0.0 or data[m.n * 4 + i * 4] > 0.0, "con rebaba en la cara de salida")


## Seguro para hilos (CONTRATOS.md, «Rendimiento y multinúcleo»): el módulo no tiene `static var` ni toca nodos.
func test_sin_estado_estatico_ni_nodos() -> void:
	var code := code_only(FileAccess.get_file_as_string("res://core/taller/radial_manual.gd"))
	assert_false(RegEx.create_from_string("(?m)^static\\s+var\\b").search(code) != null, "sin static var")
	for bad in ["Node", "get_tree", "randf", "randi", "Time.", "OS."]:
		assert_false(code.contains(bad), "sin «%s»" % bad)
