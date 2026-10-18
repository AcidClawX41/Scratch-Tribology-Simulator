## Página de la afiladora (app/taller/ui/sharpener_page.gd) sin ventana: se construye con build() y avanza con tick(),
## como hace la sección. Fuera del árbol el simulador trabaja en el hilo del test (sin hilo aparte), así que cada
## fotograma publica su instantánea al momento. Se comprueba:
##   - que lo que pinta la página son los números del core (sharpening_sim.gd) con el formato de fmt.gd, y que un
##     simulador aparte con los mismos ajustes y el mismo tiempo da lo mismo;
##   - que el quemado, la nota, los consejos y los avisos (con su fuente) salen en pantalla;
##   - el aviso educativo y de seguridad, el catálogo agrupado, el cambio de herramienta y el modo teléfono;
##   - que sin la escena 3D queda la vista 2D, y que con el simulador en su hilo sale lo mismo que sin hilo;
##   - que la interfaz no calcula física (vigilancia del código).
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const Page = preload("res://app/taller/ui/sharpener_page.gd")
const Runner = preload("res://app/taller/ui/sharpen_runner.gd")
const WorkshopState = preload("res://core/taller/workshop_state.gd")
const SharpeningSim = preload("res://core/taller/sharpening_sim.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")

const FRAME := 1.0 / 30.0
const SCENE_3D := "res://app/taller/sharpen3d/sharpen_3d.tscn"
const UI_FILES := ["res://app/taller/ui/sharpener_page.gd", "res://app/taller/ui/sharpen_view.gd",
	"res://app/taller/ui/sharpen_chart.gd", "res://app/taller/ui/sharpen_runner.gd"]
## Cuchillo de cocina en la Einhell TC-BG 150 en seco, despacio y apretando: se quema.
const DRY_SLOW := { "machine_id": "einhell_tc_bg_150", "tool": { "kind": "cuchillo" }, "hand": { "force_n": 20.0, "sweep_mm_s": 8.0, "passes": 2, "rest_s": 0.0 } }


func _page() -> Control:
	var p: Control = Page.new()
	p.call("build", WorkshopState.new())
	return p


## Corre el programa entero a ×spd, fotograma a fotograma, como la sección. Devuelve los fotogramas.
func _run(p: Control, spd: float = 10.0, max_frames: int = 20000) -> int:
	p.call("set_speed", spd)
	p.call("start_program")
	var n := 0
	while bool(p.call("latest").get("running", false)) and n < max_frames:
		p.call("tick", FRAME)
		n += 1
	p.call("tick", FRAME)
	return n


func _texts(box: Node) -> String:
	var out := ""
	for ch in box.get_children():
		if ch is Label:
			out += (ch as Label).text + "\n"
	return out


func _read(p: Control, key: String) -> String:
	return ((p.get("reads") as Dictionary)[key] as Label).text


func test_carga_con_el_aviso_y_el_catalogo() -> void:
	var p := _page()
	var band := p.find_child("AvisoAfiladora", true, false) as PanelContainer
	assert_true(band != null, "aviso de la afiladora")
	var notice := (band.get_child(0) as Label).text
	for part in ["orientativos", "±40 %", "estimación", "Nunca por encima de la velocidad máxima marcada", "nunca para un cuchillo de cocina"]:
		assert_true(notice.contains(part), "el aviso dice «%s»" % part)
	var ids: Array = []
	for g in SharpeningSim.MACHINE_GROUPS:
		ids.append_array(g["machines"])
	assert_eq((p.get("machine_chips") as Dictionary).keys(), ids, "todas las máquinas del catálogo, en sus grupos")
	for g in SharpeningSim.MACHINE_GROUPS:
		assert_true(_has_label(p, str(g["name"])), "grupo «%s»" % g["name"])
	var card: Dictionary = p.get("card")
	for k in ["motor", "giro", "muelas", "fuente"]:
		assert_true((card[k] as Label).text != "—" and (card[k] as Label).text != "", "ficha: %s = %s" % [k, (card[k] as Label).text])
	assert_true((card["fuente"] as Label).text.contains("calidad"), "fuente y calidad")
	# La velocidad frente a la máxima marcada sale en las muelas que la tienen: la esmeriladora de banco sí; la afiladora
	# lenta al agua de partida (≈1 m/s) no la marca
	p.call("apply", { "machine_id": "einhell_tc_bg_150" })
	p.call("tick", FRAME)
	assert_true((card["muelas"] as Label).text.contains("máx. marcada"), "velocidad frente a la máxima marcada: %s" % (card["muelas"] as Label).text)
	# La vista 2D siempre; la 3D solo si su escena existe (y fuera del árbol no se instancia)
	assert_true(p.get("view") != null and (p.get("view") as Control).get_parent() != null, "vista 2D")
	assert_eq(p.get("view3d") != null, ResourceLoader.exists(SCENE_3D), "3D solo si está app/taller/sharpen3d/sharpen_3d.tscn")
	assert_eq(p.get("sharpen3d"), null, "sin ventana no se crea la escena 3D")
	p.free()


func _has_label(root: Node, text: String) -> bool:
	for ch in root.find_children("*", "Label", true, false):
		if (ch as Label).text == text:
			return true
	return false


## Unos fotogramas a ×1 en mitad del programa: las lecturas son las de la instantánea con el formato de fmt.gd, y un
## simulador aparte con los mismos ajustes y el mismo tiempo de proceso da la misma instantánea.
func test_los_numeros_son_los_del_core() -> void:
	var p := _page()
	p.call("apply", DRY_SLOW)
	(p.get("btn_reset") as Button).pressed.emit()
	p.call("set_speed", 1.0)
	p.call("start_program")
	for i in 45:
		p.call("tick", FRAME)
	var s: Dictionary = p.call("latest")
	assert_true(bool(s["running"]) and bool(s["touching"]), "en contacto a los 1,5 s")
	assert_true(_read(p, "vel").begins_with(Fmt.unit(s["vs_ms"], 1, "m/s")), "velocidad periférica: %s" % _read(p, "vel"))
	assert_true(_read(p, "rpm").begins_with(Fmt.unit(s["rpm"], 0, "rpm")), "giro: %s" % _read(p, "rpm"))
	assert_true(_read(p, "fuerza").begins_with(Fmt.unit(s["force_n"], 1, "N")), "fuerza: %s" % _read(p, "fuerza"))
	assert_true(_read(p, "potencia").begins_with(Fmt.unit(s["power_w"], 1, "W")), "potencia: %s" % _read(p, "potencia"))
	var c := float(s["max_temp_c"])
	if c < Heat.BURN_C:
		assert_true(_read(p, "temp").begins_with(Fmt.unit(c, 0, "°C")), "temperatura: %s" % _read(p, "temp"))
	assert_true(_read(p, "arranque").begins_with(Fmt.unit(s["removed_mm3"], 2, "mm³")), "arranque: %s" % _read(p, "arranque"))
	assert_true(_read(p, "pasada").begins_with("1/2"), "pasada: %s" % _read(p, "pasada"))
	# El mismo ensayo en un simulador aparte, avanzado de una vez
	var sim := SharpeningSim.new(s["setup"])
	sim.start()
	sim.advance(45.0 * FRAME)
	var o := sim.snapshot()
	for k in ["t_s", "max_temp_c", "peak_edge_c", "removed_mm3", "vs_ms", "rpm", "power_w", "burr"]:
		assert_eq(s[k], o[k], "%s igual que el core" % k)
	assert_eq(s["edge_temp_c"], o["edge_temp_c"], "temperaturas de las secciones iguales que el core")
	assert_eq(var_to_str(s["bevel"]), var_to_str(o["bevel"]), "bisel igual que el core")
	# La vista y la gráfica reciben la instantánea tal cual
	assert_true(is_same((p.get("view") as Control).get("snap"), s), "la vista pinta la instantánea")
	var chart: Control = p.get("chart")
	assert_eq(chart.get("lines"), s["chart_lines"], "líneas de la gráfica del core")
	assert_eq(chart.get("history"), s["history"], "historia de la gráfica del core")
	# El sonido de la página es el del simulador
	var snd: Dictionary = p.call("sound_input")
	assert_eq(snd, s["sound"], "entrada de sonido del simulador")
	assert_true(str(snd.get("process", "")) in ["grinder", "sharpener"], "proceso de sonido de una amoladora o afiladora: %s" % snd.get("process", ""))
	p.free()


func test_quemado_nota_consejos_y_avisos() -> void:
	var p := _page()
	p.call("apply", DRY_SLOW)
	(p.get("btn_reset") as Button).pressed.emit()
	var frames := _run(p)
	var s: Dictionary = p.call("latest")
	assert_true(bool(s["finished"]), "el programa termina (%d fotogramas)" % frames)
	assert_true(bool(s["burned"]), "despacio, apretando y en seco, el filo se quema")
	assert_eq(_read(p, "pico"), "quemado (> 723 °C)", "el pico no da una cifra por encima de 723 °C")
	assert_true(_read(p, "temp").ends_with(" al acabar"), "sin programa, la temperatura es la del final: %s" % _read(p, "temp"))
	var r: Dictionary = s["report"]
	assert_eq((p.get("report_grade") as Label).text, str(r["grade_text"]), "nota del core")
	assert_eq((p.get("report_verdict") as Label).text, str(r["verdict"]), "veredicto del core")
	var crit := _texts(p.get("criteria_list"))
	assert_true(crit.contains("Temperatura"), "criterio de la temperatura: %s" % crit)
	var adv := _texts(p.get("advice_list"))
	assert_eq((p.get("advice_list") as VBoxContainer).get_child_count(), 2 * (r["advice"] as Array).size(), "cada consejo con su fuente")
	for a in r["advice"]:
		assert_true(adv.contains(str(a["title"])) and adv.contains("Fuente: " + str(a["source"])), "consejo «%s» con su fuente" % a["title"])
	var warns := _texts(p.get("warn_list"))
	assert_true(warns.contains("723 °C") and warns.contains("Fuente:"), "aviso del quemado con su fuente")
	for w in s["warnings"]:
		assert_true(warns.contains(str(w["message"])), "aviso «%s» en pantalla" % w["code"])
	assert_true((p.get("status_label") as Label).text.begins_with("Pasada 2 de 2 · programa terminado"), "estado: %s" % (p.get("status_label") as Label).text)
	assert_eq((p.get("btn_start") as Button).text, "Afilar", "listo para otro programa")
	# Hoja nueva: fría, sin programa y sin informe de nota
	(p.get("btn_reset") as Button).pressed.emit()
	var n: Dictionary = p.call("latest")
	assert_false(bool(n["burned"]), "hoja nueva sin quemar")
	assert_true((p.get("status_label") as Label).text.begins_with("Pasada 0 de 2 · lista para afilar"), "hoja nueva: %s" % (p.get("status_label") as Label).text)
	p.free()


func test_en_humedo_no_pasa_de_130() -> void:
	var p := _page()
	p.call("apply", { "machine_id": "einhell_tc_wg_200", "tool": { "kind": "cuchillo" }, "hand": { "passes": 2 } })
	(p.get("btn_reset") as Button).pressed.emit()
	_run(p)
	var s: Dictionary = p.call("latest")
	assert_true(bool(s["finished"]) and bool(s["water"]), "programa en húmedo terminado")
	assert_true(float(s["peak_edge_c"]) < Heat.BURNOUT_WATER_C, "lenta y en agua, el filo no pasa de 130 °C: %s" % s["peak_edge_c"])
	assert_false(_read(p, "pico").contains("quemado"), "sin quemado")
	assert_true(_read(p, "arranque").ends_with("en húmedo"), "en húmedo: %s" % _read(p, "arranque"))
	assert_true((p.get("out")["speed"] as Label).text.contains("lenta y en agua"), "velocidad de serie, lenta y en agua")
	p.free()


func test_cambiar_de_herramienta_y_de_maquina() -> void:
	var p := _page()
	var kinds: Dictionary = p.get("kind_chips")
	var out: Dictionary = p.get("out")
	var hs: Dictionary = p.get("hand_sliders")
	(kinds["broca"] as Button).pressed.emit()
	assert_true((out["angles"] as Label).text.begins_with("punta 118°"), "broca: %s" % (out["angles"] as Label).text)
	assert_true((p.get("drill_box") as Control).visible and not (p.get("edge_box") as Control).visible, "controles de la broca")
	((p.get("machine_chips") as Dictionary)["mrcm_mr_13a"] as Button).pressed.emit()
	assert_true((p.get("fit_label") as Label).text.contains("ideal"), "la MR-13A es ideal para brocas: %s" % (p.get("fit_label") as Label).text)
	assert_eq(str(p.call("latest")["setup"]["hand"]["motion"]), "quieto", "la broca se apoya quieta")
	(kinds["hacha"] as Button).pressed.emit()
	var hacha: Dictionary = p.call("latest")
	assert_eq(float(hacha["setup"]["hand"]["angle_deg"]), float(hacha["setup"]["tool"]["bevel_deg"]), "el ángulo de la mano pasa al del hacha")
	assert_eq((hs["angle_deg"].value as Label).text, Fmt.unit(hacha["setup"]["hand"]["angle_deg"], 1, "°"), "deslizador del ángulo")
	assert_eq(str(hacha["setup"]["hand"]["motion"]), "barrido", "el hacha se barre")
	(kinds["cortacesped"] as Button).pressed.emit()
	assert_false(((p.get("sides_chips") as Dictionary)["b"] as Button).visible, "la cuchilla de cortacésped se amuela por una cara")
	assert_true((out["angles"] as Label).text.contains("un solo lado"), "cortacésped: %s" % (out["angles"] as Label).text)
	(kinds["fresa"] as Button).pressed.emit()
	_run(p)
	assert_eq(_read(p, "temp"), "no se calcula", "la fresa no tiene perfil térmico")
	assert_true(_texts(p.get("warn_list")).contains("No se calcula la temperatura"), "y lo dice en los avisos")
	# Compatibilidad: el tipo sigue llegando a WorkshopState (lo que hoy suena en la sección)
	assert_eq(str((p.get("state") as WorkshopState).sharpen["kind"]), "fresa", "WorkshopState sabe que es una fresa")
	p.free()


func test_fuerza_en_marcha_y_pausa() -> void:
	var p := _page()
	p.call("apply", DRY_SLOW)
	p.call("set_speed", 1.0)
	p.call("start_program")
	for i in 30:
		p.call("tick", FRAME)
	var force: HSlider = (p.get("hand_sliders") as Dictionary)["force_n"].slider
	force.value = 5.0
	if not force.is_inside_tree():
		force.value_changed.emit(force.value)
	var s: Dictionary = p.call("latest")
	assert_true(bool(s["running"]), "la fuerza cambia en marcha sin parar el programa")
	assert_eq(float(s["force_set_n"]), 5.0, "5 N")
	(p.get("btn_pause") as Button).pressed.emit()
	var t0 := float(p.call("latest")["t_s"])
	for i in 10:
		p.call("tick", FRAME)
	assert_eq(float(p.call("latest")["t_s"]), t0, "en pausa no avanza")
	assert_eq((p.get("btn_pause") as Button).text, "Sigue", "botón de seguir")
	(p.get("btn_pause") as Button).pressed.emit()
	p.call("tick", FRAME)
	assert_true(float(p.call("latest")["t_s"]) > t0, "sigue")
	(p.get("btn_start") as Button).pressed.emit()
	assert_false(bool(p.call("latest")["running"]), "«Parar» levanta la herramienta")
	p.free()


func test_modo_telefono() -> void:
	var p := _page()
	p.call("set_compact", true)
	assert_true(p.get("pane").compact, "una columna")
	var grid := p.find_child("Lecturas", true, false) as GridContainer
	assert_eq(grid.columns, 2, "lecturas en dos columnas en el teléfono")
	p.call("set_compact", false)
	assert_false(p.get("pane").compact, "dos columnas")
	assert_eq(grid.columns, 3, "lecturas en tres columnas")
	p.free()


## El simulador en su hilo (doble búfer) da lo mismo que sin hilo con las mismas órdenes y el mismo tiempo pedido.
func test_con_hilo_da_lo_mismo() -> void:
	var setup := { "machine_id": "einhell_tc_bg_150", "tool": { "kind": "cuchillo", "sections": 8 }, "hand": { "passes": 1, "sweep_mm_s": 100.0, "force_n": 15.0 } }
	var a := Runner.new(setup)
	var b := Runner.new(setup)
	b.start_thread()
	assert_true(b.is_threaded() and not a.is_threaded(), "uno con hilo y otro sin")
	a.post("start")
	b.post("start")
	for i in 20:
		a.request(FRAME)
		b.request(FRAME)
	var sa := a.latest()
	var guard := 0
	while (not b.in_sync() or float(b.latest()["t_s"]) < float(sa["t_s"])) and guard < 5000:
		OS.delay_msec(2)
		guard += 1
	b.stop_thread()
	var sb := b.latest()
	assert_true(float(sa["t_s"]) > 0.5, "ha avanzado: %s s" % sa["t_s"])
	for k in ["t_s", "max_temp_c", "peak_edge_c", "removed_mm3", "burr", "pass"]:
		assert_eq(sb[k], sa[k], "%s igual con hilo" % k)
	assert_eq(sb["edge_temp_c"], sa["edge_temp_c"], "temperaturas de las secciones iguales con hilo")
	assert_eq(b.dropped_s(), 0.0, "sin tiempo descartado")
	assert_false(b.is_threaded(), "hilo parado")


## Dentro del árbol la página arranca el hilo del simulador y lo para al salir.
func test_hilo_dentro_del_arbol() -> void:
	var p := _page()
	add_to_tree(p)
	p.call("apply", { "machine_id": "tormek_t8", "tool": { "kind": "cuchillo", "sections": 4 }, "hand": { "passes": 1 } })
	p.call("tick", FRAME)
	var runner: RefCounted = p.get("runner")
	assert_true(bool(runner.call("is_threaded")), "el simulador va en su hilo")
	p.call("start_program")
	var advanced := func() -> bool:
		p.call("tick", FRAME)
		return float((p.call("latest") as Dictionary).get("t_s", 0.0)) > 0.2
	var ok: bool = await wait_until(advanced, 300)
	assert_true(ok, "avanza en su hilo")
	p.get_parent().remove_child(p)
	assert_false(bool(runner.call("is_threaded")), "al salir del árbol se para el hilo")


## La interfaz no calcula física: ni amolado, ni temperatura, ni velocidades; solo da formato (fmt.gd).
func test_la_interfaz_no_calcula_fisica() -> void:
	for f: String in UI_FILES:
		var code := code_only(FileAccess.get_file_as_string(f))
		for call: String in ["grind(", "edge_contact(", "knife_contact(", "wheel_speed(", "motor_state(", "partition(",
				"specific_energy(", "spark_input(", "resolve_stream(", "accumulate_temper(", "temper_threshold_c(",
				"hardness_after(", "EdgeThermal", "edge_thermal.gd", "grinding.gd", "MachineSound", ".frame(", "snapped(",
				"str(round(", "9.81", "PI *"]:
			assert_false(code.contains(call), "%s no puede usar %s" % [f.get_file(), call])
	var runner := code_only(FileAccess.get_file_as_string("res://app/taller/ui/sharpen_runner.gd"))
	assert_true(runner.contains("extends RefCounted"), "el hilo del simulador no es un nodo")
	for bad: String in ["get_tree(", "add_child(", "get_node(", "queue_redraw("]:
		assert_false(runner.contains(bad), "el hilo del simulador no toca nodos: %s" % bad)


## Cambiar de máquina no arrastra el diámetro de la muela anterior. El deslizador «Diámetro de la muela» cambia de
## recorrido (Ø153–207 en la piedra al agua) y, dentro del árbol, Godot recorta su valor y emite value_changed: sin
## bloquear las señales, los Ø150 de la esmeriladora se recortaban a Ø153 y la piedra quedaba «gastada» (0,88 m/s en
## lugar de 1,15 m/s). Fuera del árbol Godot no emite al recortar, así que este test mete la página en el árbol.
func test_cambiar_de_maquina_no_gasta_la_muela() -> void:
	var p := _page()
	add_to_tree(p)
	p.call("apply", { "machine_id": "einhell_tc_bg_150" })
	p.call("apply", { "machine_id": "einhell_tc_wg_200" })
	var setup: Dictionary = p.call("latest").get("setup", {})
	assert_true(float(setup.get("diameter_mm", -1.0)) <= 0.0, "diámetro de serie, sin recortar: %s" % [setup.get("diameter_mm")])
	var wheels := ((p.get("card") as Dictionary)["muelas"] as Label).text
	assert_true(wheels.contains("Ø200") and wheels.contains("1,15"), "piedra al agua de serie: %s" % wheels)
