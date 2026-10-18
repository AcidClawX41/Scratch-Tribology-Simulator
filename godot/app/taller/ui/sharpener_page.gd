## Taller industrial · página de la afiladora: el simulador de afilado (core/taller/sharpening_sim.gd) con las máquinas
## reales del catálogo (Einhell, VEVOR, amoladoras, afiladoras de brocas y fresas de MRCM y la Tormek de referencia).
## - Tarjetas: aviso educativo y de seguridad; máquina (agrupada, con su ficha: motor, giro, muelas, velocidad
##   periférica frente a la máxima marcada, fuente y calidad) y muela; herramienta (tipo, acero y geometría); la mano
##   (fuerza, ángulo con plantilla o a pulso, pasadas, barrido o quieto, descanso, agua, cara, sentido, apoyo);
##   recomendación del core (ángulos, abrasivo, velocidad, granos); informe final (nota y consejos) y avisos.
## - Vista: «Afilar», pausa, hoja nueva y velocidad de simulación; la escena 3D (app/taller/sharpen3d/, si está) o la
##   vista 2D (sharpen_view.gd) con la sección del filo; lecturas en directo; gráfica de la temperatura del filo.
## El simulador corre en un hilo aparte con doble búfer (sharpen_runner.gd): la página solo manda órdenes y pinta la
## última instantánea. Aquí no se calcula nada: todos los números salen del core y solo se les da formato (fmt.gd).
## Compatibilidad: el tipo de herramienta y la máquina genérica se siguen pasando a WorkshopState (set_sharpen), que es
## lo que hoy hace sonar taller_section.gd; sound_input() da ya la entrada de sonido del simulador.
extends Control

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const SharpeningSim = preload("res://core/taller/sharpening_sim.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Report = preload("res://core/taller/sharpening_report.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const SharpenView = preload("res://app/taller/ui/sharpen_view.gd")
const SharpenChart = preload("res://app/taller/ui/sharpen_chart.gd")
const SharpenRunner = preload("res://app/taller/ui/sharpen_runner.gd")

const SCENE_3D := "res://app/taller/sharpen3d/sharpen_3d.tscn"
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 5.0, 10.0]
const KINDS := [["cuchillo", "Cuchillo"], ["broca", "Broca"], ["fresa", "Fresa"], ["hacha", "Hacha"], ["cortacesped", "Cortacésped"]]
const STYLES := [["occidental", "Occidental"], ["japones", "Japonés"]]
const VIEWS_3D := [["general", "General"], ["filo", "Filo"], ["seccion", "Sección"]]
const FIT_TEXT := { "ideal": "ideal", "buena": "buena", "con_cuidado": "con cuidado", "no": "no sirve" }
const FIT_STYLE := { "ideal": "TallerBien", "buena": "TallerBien", "con_cuidado": "TallerAviso", "no": "TallerMal" }
const PHASE_TEXT := { "contacto": "apoyada en la muela", "descanso": "descansando", "listo": "lista para afilar", "fin": "programa terminado" }
## Máquina genérica de WorkshopState (sharpening.gd) para cada tipo de máquina del catálogo (compatibilidad).
const GENERIC_KIND := { "cuchillo": "cuchillo", "hacha": "cuchillo", "cortacesped": "cuchillo", "broca": "broca", "fresa": "fresa" }
const BANNER := "Simulador educativo: valores orientativos con fuentes (docs/taller/afilado-simulador.md); las temperaturas llevan ±40 % y lo que no tiene medición publicada va marcado como estimación. No sustituye al manual de la máquina. Nunca por encima de la velocidad máxima marcada en la muela o el disco. La amoladora, solo para hachas y cuchillas de cortacésped: nunca para un cuchillo de cocina."
## Mano que se conserva al cambiar de máquina (el resto toma lo de partida de la máquina nueva).
const KEEP_HAND := ["force_n", "angle_deg", "angle_mode", "wobble_deg", "sides", "direction", "rest_gap_mm"]

var state: WorkshopState
var runner: SharpenRunner
var pane: TwoPane
var view: SharpenView
var chart: SharpenChart
var view3d: View3D = null
var sharpen3d: Node = null
var compact := false
var speed := 1.0

# Controles
var btn_start: Button
var btn_pause: Button
var btn_reset: Button
var speed_chips := {}
var view_chips := {}
var status_label: Label
var perf_label: Label
var machine_chips := {}
var wheel_box: HFlowContainer
var wheel_chips := {}
var rpm_box: HFlowContainer
var rpm_chips := {}
var diam_slider: Dictionary
var fit_label: Label
var card_grid: GridContainer
var card := {}  # nombre → Label de la ficha
var kind_chips := {}
var steel_opt: OptionButton
var knife_box: VBoxContainer
var style_chips := {}
var use_opt: OptionButton
var edge_box: VBoxContainer
var drill_box: VBoxContainer
var mill_box: VBoxContainer
var tool_sliders := {}  # clave de la herramienta → { row, slider, value }
var hand_sliders := {}  # clave de la mano → { row, slider, value }
var force_name: Label
var angle_mode_chips := {}
var motion_chips := {}
var sides_chips := {}
var direction_chips := {}
var mode_chips := {}
var dip_check: CheckButton
var edge_hand_box: VBoxContainer
var bench_box: VBoxContainer
var reads := {}  # nombre → Label de las lecturas en directo
var tint_swatch: ColorRect
var out := {}  # recomendación: nombre → Label
var grit_list: VBoxContainer
var result_card: Card
var report_card: Card
var report_grade: Label
var report_verdict: Label
var criteria_list: VBoxContainer
var advice_list: VBoxContainer
var warn_list: VBoxContainer
var machine_card_node: Card

var _built := false
var _snap: Dictionary = {}
var _seen := -1  # instantáneas del simulador ya pintadas
var _report_ref: Dictionary = {}
var _warn_key := ""
var _setup_key := ""
var _view3d_key := ""
var _wheel_key := ""


func build(ws: WorkshopState) -> void:
	if _built:
		return
	_built = true
	state = ws
	name = "Afiladora"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	runner = SharpenRunner.new({ "tool": { "kind": "cuchillo" } })
	pane = TwoPane.new()
	add_child(pane)
	_build_visual()
	_build_banner()
	_build_machine_card()
	_build_tool_card()
	_build_hand_card()
	_build_result_card()
	_build_report_card()
	_build_warn_card()
	_apply_snapshot(runner.latest(), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and runner != null:
		runner.stop_thread()


func _exit_tree() -> void:
	if runner != null:
		runner.stop_thread()


# ─────────────────────────────── Construcción ───────────────────────────────

func _build_visual() -> void:
	var bar := HFlowContainer.new()
	btn_start = Style.button("Afilar", "TallerAccion")
	btn_start.pressed.connect(_on_start)
	bar.add_child(btn_start)
	btn_pause = Style.button("Pausa")
	btn_pause.pressed.connect(_on_pause)
	bar.add_child(btn_pause)
	btn_reset = Style.button("Hoja nueva")
	btn_reset.tooltip_text = "Herramienta fría y con el filo romo del principio"
	btn_reset.pressed.connect(_on_reset)
	bar.add_child(btn_reset)
	var items: Array = []
	for s: float in SPEEDS:
		items.append([s, "×" + Fmt.num(s, 2 if s < 1.0 else 0)])
	speed_chips = Style.chips(items, set_speed, bar).buttons
	pane.visual.add_child(bar)
	status_label = Style.label("", "TallerTenue", true)
	pane.visual.add_child(status_label)
	if ResourceLoader.exists(SCENE_3D):
		var vbar := HFlowContainer.new()
		view_chips = Style.chips(VIEWS_3D, set_view, vbar).buttons
		pane.visual.add_child(vbar)
		view3d = View3D.new(SCENE_3D)
		view3d.name = "Afiladora3D"
		view3d.custom_minimum_size = Vector2(300, 300)
		view3d.scene_ready.connect(_on_scene_ready)
		pane.visual.add_child(view3d)
		Style.pick_chip(view_chips, "general")
	view = SharpenView.new()
	view.name = "Vista2D"
	view.custom_minimum_size = Vector2(300, 250 if view3d != null else 340)
	view.size_flags_vertical = Control.SIZE_FILL if view3d != null else Control.SIZE_EXPAND_FILL
	pane.visual.add_child(view)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.name = "Lecturas"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for k in [["vel", "Velocidad periférica"], ["rpm", "Giro de la muela"], ["fuerza", "Fuerza de la mano"],
			["potencia", "Potencia de amolado"], ["temp", "Temperatura del filo"], ["pico", "Pico del filo"],
			["color", "Color de revenido"], ["hrc", "Dureza del filo"], ["bisel", "Bisel"], ["rebaba", "Rebaba"],
			["pasada", "Pasada"], ["arranque", "Metal arrancado"]]:
		reads[k[0]] = _tile(grid, k[1], k[0] == "color")
	pane.visual.add_child(grid)
	chart = SharpenChart.new()
	chart.name = "Grafica"
	chart.custom_minimum_size = Vector2(260, 170)
	pane.visual.add_child(chart)
	perf_label = Style.label("", "TallerNota", true)
	pane.visual.add_child(perf_label)


## Una lectura: recuadro con el nombre y el valor (y una muestra de color si hace falta). Devuelve la etiqueta del valor.
func _tile(grid: GridContainer, title: String, with_swatch: bool = false) -> Label:
	var box := PanelContainer.new()
	box.theme_type_variation = "TallerRecuadro"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	col.add_child(Style.label(title, "TallerNota"))
	var row := HBoxContainer.new()
	col.add_child(row)
	if with_swatch:
		tint_swatch = Style.swatch(Style.c("panel3"), 14.0)
		row.add_child(tint_swatch)
	var v := Style.label("—", "TallerDato", true)
	v.custom_minimum_size.x = 60.0
	row.add_child(v)
	grid.add_child(box)
	return v


func _build_banner() -> void:
	var band := PanelContainer.new()
	band.theme_type_variation = "TallerBanda"
	band.name = "AvisoAfiladora"
	band.add_child(Style.label(BANNER, "TallerAviso", true))
	pane.side.add_child(band)


func _build_machine_card() -> void:
	machine_card_node = Card.new("Máquina y muela")
	var group := ButtonGroup.new()
	for g in SharpeningSim.MACHINE_GROUPS:
		machine_card_node.body.add_child(Style.label(str(g["name"]), "TallerTenue", true))
		var items: Array = []
		for id in g["machines"]:
			items.append([id, str(Machines.MACHINES[id]["name"]).get_slice(" (", 0)])
		var mc := Style.chips(items, _on_machine)
		for id in mc.buttons:
			(mc.buttons[id] as Button).button_group = group
			machine_chips[id] = mc.buttons[id]
		machine_card_node.body.add_child(mc.box)
	fit_label = Style.label("", "TallerAviso", true)
	machine_card_node.body.add_child(fit_label)
	card_grid = Style.grid()
	for k in [["motor", "Motor"], ["giro", "Giro en vacío"], ["red", "Mercado"], ["muelas", "Muelas"], ["apoyo", "Apoyo"],
			["ruido", "Ruido · peso"], ["fuente", "Fuente"]]:
		card[k[0]] = Style.grid_row(card_grid, k[1], "TallerTenue")
	machine_card_node.body.add_child(card_grid)
	machine_card_node.body.add_child(Style.label("Muela en uso", "TallerTenue"))
	wheel_box = HFlowContainer.new()
	machine_card_node.body.add_child(wheel_box)
	rpm_box = HFlowContainer.new()
	machine_card_node.body.add_child(rpm_box)
	diam_slider = Style.slider("Diámetro de la muela (gastada)", 100.0, 250.0, 1.0, func(v: float) -> void: _post({ "diameter_mm": v }))
	machine_card_node.body.add_child(diam_slider.row)
	pane.side.add_child(machine_card_node)


func _build_tool_card() -> void:
	var c := Card.new("Herramienta")
	var kc := Style.chips(KINDS, _on_kind)
	kind_chips = kc.buttons
	c.body.add_child(kc.box)
	c.body.add_child(Style.label("Material", "TallerTenue", true))
	steel_opt = Style.options([], func(id: String) -> void: _set_tool("steel_id", id))
	c.body.add_child(steel_opt)
	knife_box = VBoxContainer.new()
	var sc := Style.chips(STYLES, func(id: String) -> void: _set_tool("style", id))
	style_chips = sc.buttons
	knife_box.add_child(sc.box)
	var uses: Array = []
	var knife: Dictionary = Sharpening.SHARPENING_ANGLES["cuchillo"]
	for id in knife["usos"]:
		if id != "hacha":
			uses.append([id, str(knife["usos"][id]["name"])])
	knife_box.add_child(Style.label("Uso (decide el ángulo recomendado)", "TallerTenue", true))
	use_opt = Style.options(uses, func(id: String) -> void: _set_tool("use", id))
	knife_box.add_child(use_opt)
	c.body.add_child(knife_box)
	edge_box = VBoxContainer.new()
	for s in [["bevel_deg", "Ángulo que tenía el bisel (por lado)", 5.0, 45.0, 0.5], ["thickness_mm", "Espesor donde acaba el bisel", 0.1, 5.0, 0.05],
			["length_mm", "Largo del filo", 20.0, 350.0, 5.0], ["flat_um", "Filo romo (ancho del plano gastado)", 2.0, 500.0, 1.0]]:
		tool_sliders[s[0]] = Style.slider(s[1], s[2], s[3], s[4], _set_tool.bind(s[0]))
		edge_box.add_child(tool_sliders[s[0]].row)
	c.body.add_child(edge_box)
	drill_box = VBoxContainer.new()
	for s in [["diameter_mm", "Diámetro de la broca", 1.0, 20.0, 0.5], ["point_deg", "Ángulo de punta", 90.0, 150.0, 1.0],
			["clearance_deg", "Incidencia", 0.0, 25.0, 0.5], ["lip_diff_mm", "Diferencia de altura de los labios", 0.0, 0.5, 0.01],
			["feed_mm_rev", "Avance al taladrar", 0.02, 0.5, 0.01], ["wear_um", "Desgaste del flanco a quitar", 10.0, 1000.0, 10.0]]:
		tool_sliders["broca:" + s[0]] = Style.slider(s[1], s[2], s[3], s[4], _set_tool.bind(s[0]))
		drill_box.add_child(tool_sliders["broca:" + s[0]].row)
	c.body.add_child(drill_box)
	mill_box = VBoxContainer.new()
	for s in [["diameter_mm", "Diámetro de la fresa", 4.0, 20.0, 0.5], ["primary_deg", "Incidencia primaria", 0.0, 20.0, 0.5],
			["secondary_deg", "Incidencia secundaria", 0.0, 30.0, 0.5], ["teeth", "Dientes", 2.0, 6.0, 1.0]]:
		tool_sliders["fresa:" + s[0]] = Style.slider(s[1], s[2], s[3], s[4], _set_tool.bind(s[0]))
		mill_box.add_child(tool_sliders["fresa:" + s[0]].row)
	c.body.add_child(mill_box)
	c.body.add_child(Style.label("Cambiar la herramienta empieza con una hoja nueva (fría y con el filo romo).", "TallerNota", true))
	pane.side.add_child(c)


func _build_hand_card() -> void:
	var c := Card.new("La mano y las pasadas")
	hand_sliders["force_n"] = Style.slider("Fuerza contra la muela", 0.0, 50.0, 0.5, _set_hand.bind("force_n"))
	c.body.add_child(hand_sliders["force_n"].row)
	force_name = Style.label("", "TallerNota", true)
	c.body.add_child(force_name)
	edge_hand_box = VBoxContainer.new()
	hand_sliders["angle_deg"] = Style.slider("Ángulo de afilado (por lado)", 5.0, 45.0, 0.5, _set_hand.bind("angle_deg"))
	edge_hand_box.add_child(hand_sliders["angle_deg"].row)
	angle_mode_chips = Style.chips([["plantilla", "Con plantilla"], ["pulso", "A pulso"]], _set_hand.bind("angle_mode")).buttons
	edge_hand_box.add_child((angle_mode_chips.values()[0] as Control).get_parent())
	hand_sliders["wobble_deg"] = Style.slider("A pulso, el ángulo varía ±", 0.5, 10.0, 0.5, _set_hand.bind("wobble_deg"))
	edge_hand_box.add_child(hand_sliders["wobble_deg"].row)
	motion_chips = Style.chips([["barrido", "Barriendo el filo"], ["quieto", "Quieto"]], _set_hand.bind("motion")).buttons
	edge_hand_box.add_child((motion_chips.values()[0] as Control).get_parent())
	sides_chips = Style.chips([["alternar", "Alternar caras"], ["a", "Solo cara A"], ["b", "Solo cara B"]], _set_hand.bind("sides")).buttons
	edge_hand_box.add_child((sides_chips.values()[0] as Control).get_parent())
	c.body.add_child(edge_hand_box)
	hand_sliders["sweep_mm_s"] = Style.slider("Velocidad de la pasada (barrido)", 5.0, 200.0, 1.0, _set_hand.bind("sweep_mm_s"))
	c.body.add_child(hand_sliders["sweep_mm_s"].row)
	hand_sliders["hold_s"] = Style.slider("Duración del contacto (quieto)", 0.1, 10.0, 0.1, _set_hand.bind("hold_s"))
	c.body.add_child(hand_sliders["hold_s"].row)
	hand_sliders["passes"] = Style.slider("Pasadas", 1.0, 60.0, 1.0, _set_hand.bind("passes"))
	c.body.add_child(hand_sliders["passes"].row)
	hand_sliders["rest_s"] = Style.slider("Descanso entre pasadas", 0.0, 10.0, 0.1, _set_hand.bind("rest_s"))
	c.body.add_child(hand_sliders["rest_s"].row)
	dip_check = CheckButton.new()
	dip_check.text = "Meter en agua entre pasadas"
	dip_check.focus_mode = Control.FOCUS_NONE
	dip_check.toggled.connect(func(on: bool) -> void: _set_hand(on, "dip"))
	c.body.add_child(dip_check)
	direction_chips = Style.chips([["contra", "Filo contra la muela"], ["a_favor", "Muela alejándose del filo"]], _set_hand.bind("direction")).buttons
	c.body.add_child((direction_chips.values()[0] as Control).get_parent())
	bench_box = VBoxContainer.new()
	mode_chips = Style.chips([["periferia", "Con la periferia"], ["cara", "Con el costado"]], _set_hand.bind("mode")).buttons
	bench_box.add_child((mode_chips.values()[0] as Control).get_parent())
	hand_sliders["rest_gap_mm"] = Style.slider("Distancia del apoyo a la muela", 0.0, 8.0, 0.5, _set_hand.bind("rest_gap_mm"))
	bench_box.add_child(hand_sliders["rest_gap_mm"].row)
	c.body.add_child(bench_box)
	c.body.add_child(Style.label("La fuerza, el agua, el sentido, el costado y el apoyo cambian en marcha; lo demás, en el siguiente «Afilar».", "TallerNota", true))
	pane.side.add_child(c)


func _build_result_card() -> void:
	result_card = Card.new("Recomendación del core", "sharpening.gd")
	var g := Style.grid()
	for k in [["angles", "Ángulos"], ["abrasive", "Abrasivo"], ["speed", "Velocidad"], ["edge", "Filo esperado"]]:
		out[k[0]] = Style.grid_row(g, k[1], "TallerTenue")
	result_card.body.add_child(g)
	out["why"] = Style.label("", "TallerNota", true)
	result_card.body.add_child(out["why"])
	result_card.body.add_child(Style.label("Progresión de granos", "TallerTenue"))
	grit_list = VBoxContainer.new()
	grit_list.add_theme_constant_override("separation", 2)
	result_card.body.add_child(grit_list)
	pane.side.add_child(result_card)


func _build_report_card() -> void:
	report_card = Card.new("Informe del afilado", "nota de 0 a 10")
	var head := HBoxContainer.new()
	report_grade = Style.label("—", "TallerGrande")
	head.add_child(report_grade)
	report_verdict = Style.label("", "TallerDato", true)
	report_verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(report_verdict)
	report_card.body.add_child(head)
	criteria_list = VBoxContainer.new()
	criteria_list.add_theme_constant_override("separation", 3)
	report_card.body.add_child(criteria_list)
	report_card.body.add_child(Style.label("Consejos", "TallerTarjeta"))
	advice_list = VBoxContainer.new()
	advice_list.add_theme_constant_override("separation", 4)
	report_card.body.add_child(advice_list)
	pane.side.add_child(report_card)


func _build_warn_card() -> void:
	var c := Card.new("Avisos", "con su fuente")
	warn_list = VBoxContainer.new()
	c.body.add_child(warn_list)
	pane.side.add_child(c)


# ─────────────────────────────── Órdenes ───────────────────────────────

## Ajustes completos o parciales para el simulador (se mezclan con los que tiene).
func apply(setup: Dictionary) -> void:
	_post(setup)


func _post(p: Dictionary) -> void:
	runner.post("configure", p)
	_poll()


func _set_tool(value: Variant, key: String) -> void:
	_post({ "tool": { key: value } })


func _set_hand(value: Variant, key: String) -> void:
	_post({ "hand": { key: value } })


func _on_kind(kind: String) -> void:
	var s: Dictionary = _snap.get("setup", {})
	var mid := str(s.get("machine_id", ""))
	if str(Machines.suitability(mid, kind)["fit"]) == "no":
		mid = SharpeningSim.best_machine(kind)
	var mk := str(Machines.MACHINES[mid]["kind"])
	_post({ "tool": { "kind": kind }, "machine_id": mid, "hand": SharpeningSim.default_hand(mk, kind) })
	_sync_workshop(kind, mid)


func _on_machine(id: String) -> void:
	var s: Dictionary = _snap.get("setup", {})
	var kind := str(s.get("tool", {}).get("kind", "cuchillo"))
	var hand := SharpeningSim.default_hand(str(Machines.MACHINES[id]["kind"]), kind)
	var old: Dictionary = s.get("hand", {})
	for k in KEEP_HAND:
		if old.has(k):
			hand[k] = old[k]
	_post({ "machine_id": id, "hand": hand })
	_sync_workshop(kind, id)


func _on_wheel(id: String) -> void:
	_post({ "wheel": id })


func _on_rpm(rpm: float) -> void:
	_post({ "rpm": rpm })


func _on_start() -> void:
	if bool(_snap.get("running", false)):
		runner.post("stop")
	else:
		runner.post("start")
	_poll()


func _on_reset() -> void:
	runner.post("reset")
	_poll()


func _on_pause() -> void:
	if not bool(_snap.get("running", false)):
		return
	runner.post("pause", not bool(_snap.get("paused", false)))
	_poll()


## Hoja nueva (lo mismo que el botón): fría y con el filo romo del principio.
func reset_blade() -> void:
	_on_reset()


## Empieza un programa de pasadas (lo mismo que «Afilar»).
func start_program() -> void:
	runner.post("start")
	_poll()


## Velocidad de la simulación (tiempo de proceso por segundo real).
func set_speed(s: float) -> void:
	speed = s
	Style.pick_chip(speed_chips, s)


## Vista de la escena 3D: general, filo o sección.
func set_view(id: String) -> void:
	Style.pick_chip(view_chips, id)
	if sharpen3d != null and sharpen3d.has_method("set_view"):
		sharpen3d.call("set_view", id)


## Compatibilidad: el tipo de herramienta y la máquina genérica en WorkshopState (lo que hoy hace sonar la sección).
func _sync_workshop(kind: String, machine_id: String) -> void:
	if state == null:
		return
	var gk := str(GENERIC_KIND.get(kind, "cuchillo"))
	if str(state.sharpen.get("kind", "")) != gk:
		state.set_sharpen("kind", gk)
	var mk := str(Machines.MACHINES[machine_id]["kind"])
	var wet := bool(Machines.wheel(machine_id, SharpeningSim.default_wheel(machine_id, kind, "x50crmov15")).get("wet", false))
	var gm := "tormek_t8" if mk == "lenta_humeda" or (mk == "combinada" and wet) else ("afiladora_universal" if mk in ["afiladora_brocas", "afiladora_fresas"] else "esmeriladora_banco")
	if str(state.sharpen.get("machine_id", "")) != gm:
		state.set_sharpen("machine_id", gm)


# ─────────────────────────────── Ciclo ───────────────────────────────

func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)
	view.custom_minimum_size = Vector2(240, (230 if view3d != null else 300) if on else (250 if view3d != null else 340))
	var grid := pane.visual.get_node_or_null("Lecturas") as GridContainer
	if grid != null:
		grid.columns = 2 if on else 3
	if view3d != null:
		view3d.custom_minimum_size = Vector2(240, 260 if on else 300)


func on_shown() -> void:
	if view3d != null:
		view3d.ensure_scene()


## La entrada de sonido de la máquina (CONTRATOS.md) según el simulador: {} si está parada.
func sound_input() -> Dictionary:
	return _snap.get("sound", {})


## La última instantánea del simulador (para la demo y los tests).
func latest() -> Dictionary:
	return _snap


func tick(delta: float) -> void:
	if runner == null:
		return
	if is_inside_tree() and not runner.is_threaded():
		runner.start_thread()
	if bool(_snap.get("running", false)) and not bool(_snap.get("paused", false)):
		runner.request(delta * speed)
	view.animate(delta)
	_poll()
	if sharpen3d != null and sharpen3d.has_method("set_state"):
		sharpen3d.call("set_state", _snap.get("state3d", {}))


## Pinta la instantánea nueva, si el simulador ha publicado otra desde la última vez.
func _poll() -> void:
	var n := runner.published()
	if n != _seen:
		_apply_snapshot(runner.latest())
		_seen = n


func refresh() -> void:
	if runner == null:
		return
	_follow_workshop()
	_apply_snapshot(runner.latest(), true)


## Compatibilidad: si otro cambia el tipo de herramienta en WorkshopState (set_sharpen("kind", …), como la demo de la
## sección), la página lo sigue con una herramienta nueva de ese tipo.
func _follow_workshop() -> void:
	if state == null:
		return
	var gk := str(state.sharpen.get("kind", ""))
	var kind := str(_snap.get("kind", "cuchillo"))
	if gk in ["cuchillo", "broca", "fresa"] and gk != str(GENERIC_KIND.get(kind, "cuchillo")):
		_on_kind(gk)


func _on_scene_ready(scene: Node) -> void:
	sharpen3d = scene
	_view3d_key = ""
	_push_3d(_snap)
	set_view("general")


func _push_3d(s: Dictionary) -> void:
	if sharpen3d == null:
		return
	var key := var_to_str([s.get("view_machine", {}), s.get("view_tool", {})])
	if key == _view3d_key:
		return
	_view3d_key = key
	if sharpen3d.has_method("set_machine"):
		sharpen3d.call("set_machine", s.get("view_machine", {}))
	if sharpen3d.has_method("set_tool"):
		sharpen3d.call("set_tool", s.get("view_tool", {}))


# ─────────────────────────────── Pintar la instantánea ───────────────────────────────

func _apply_snapshot(s: Dictionary, force: bool = false) -> void:
	if s.is_empty():
		return
	_snap = s
	var setup: Dictionary = s.get("setup", {})
	var key := var_to_str(setup)
	# (con hilo, una instantánea que aún no ha visto la última orden dejaría un deslizador en su valor de antes)
	if force or (key != _setup_key and runner.in_sync()):
		_setup_key = key
		_fill_controls(s, setup)
		_fill_recommendation(s, setup)
	_fill_live(s)
	view.set_snapshot(s)
	chart.set_data(s.get("history", {}), s.get("chart_lines", []), bool(s.get("thermal", false)), bool(s.get("burned", false)),
		"temperaturas ±40 % (banda de μ y ε)")
	var r: Dictionary = s.get("report", {})
	if force or not is_same(r, _report_ref):
		_report_ref = r
		_fill_report(r)
	var wk := var_to_str(s.get("warnings", []))
	if force or wk != _warn_key:
		_warn_key = wk
		_fill_warnings(s.get("warnings", []))
	_push_3d(s)


## Los controles con los ajustes del simulador (sin emitir señales).
func _fill_controls(s: Dictionary, setup: Dictionary) -> void:
	var mid := str(setup.get("machine_id", ""))
	var tool: Dictionary = setup.get("tool", {})
	var hand: Dictionary = setup.get("hand", {})
	var kind := str(tool.get("kind", "cuchillo"))
	Style.pick_chip(machine_chips, mid)
	Style.pick_chip(kind_chips, kind)
	Style.pick_chip(speed_chips, speed)
	# Ficha de la máquina
	var mc := SharpeningSim.machine_card(mid, str(setup.get("wheel", "")), float(setup.get("rpm", -1.0)), float(setup.get("diameter_mm", -1.0)))
	var motor: Dictionary = mc.get("motor", {})
	var s1: Variant = motor.get("s1_w")
	card["motor"].text = "%s · %s%s" % [str(motor.get("type_name", "")), Fmt.unit(motor.get("input_w"), 0, "W"), (" (S1 %s)" % Fmt.unit(s1, 0, "W")) if s1 != null else ""]
	var steps: Array = motor.get("steps", [])
	if not steps.is_empty():
		card["giro"].text = "%s–%s rpm en %d posiciones" % [Fmt.num(steps[0], 0), Fmt.num(steps[steps.size() - 1], 0), steps.size()]
	else:
		card["giro"].text = Fmt.unit(motor.get("rpm_no_load"), 0, "rpm") + (" (%s–%s)" % [Fmt.num(motor.get("rpm_min"), 0), Fmt.num(motor.get("rpm_max"), 0)] if motor.get("rpm_min") != null and float(motor["rpm_min"]) != float(motor["rpm_max"]) else "")
	card["red"].text = "%s · %s" % [str(mc.get("market", "")), str(mc.get("kind_name", ""))]
	var wl: Array[String] = []
	for w in mc.get("wheels", []):
		var width: Variant = w["width_mm"]
		var dims := "Ø%s%s" % [Fmt.num(w["diameter_mm"], 0), (" × %s" % Fmt.num(width, 0)) if width != null else ""]
		var line := "%s%s · %s %s · %s · %s" % ["▸ " if bool(w["selected"]) else "", str(w["id"]), str(w["grit"]), str(w["abrasive_name"]), dims + " mm", Fmt.unit(w["speed_ms"], 1 if float(w["speed_ms"]) >= 10.0 else 2, "m/s")]
		if w["max_speed_ms"] != null:
			line += " (máx. marcada %s)" % Fmt.unit(w["max_speed_ms"], 1, "m/s")
		if not bool(w["mounted"]):
			line += " · recambio"
		if str(w["abrasive_quality"]) == "estimate":
			line += " · abrasivo estimado"
		wl.append(line)
	card["muelas"].text = "\n".join(wl)
	var gap: Variant = mc.get("rest_gap_max_mm")
	card["apoyo"].text = ("a %s como mucho" % Fmt.unit((gap as Dictionary)["value"], 1, "mm")) if gap is Dictionary else "sin dato"
	var noise: Variant = mc.get("noise")
	var weight: Variant = mc.get("weight_kg")
	card["ruido"].text = "%s · %s" % [("LpA %s" % Fmt.unit((noise as Dictionary)["lpa_dba"], 1, "dB(A)")) if noise is Dictionary else "ruido sin dato", Fmt.unit((weight as Dictionary)["value"], 1, "kg") if weight is Dictionary else "—"]
	card["fuente"].text = "%s (calidad: %s)" % [str(mc.get("source", "")), Fmt.quality(mc.get("quality", ""))]
	var fit := Machines.suitability(mid, kind, str(tool.get("steel_id", "")))
	fit_label.text = "Para %s: %s. %s" % [str(SharpeningSim.KINDS[kind]["name"]).to_lower(), str(FIT_TEXT.get(str(fit["fit"]), "")), str(fit["why"])]
	fit_label.theme_type_variation = str(FIT_STYLE.get(str(fit["fit"]), "TallerAviso"))
	# Muelas y giro
	var wkey := mid
	if wkey != _wheel_key:
		_wheel_key = wkey
		Style.clear(wheel_box)
		var witems: Array = []
		for w in mc.get("wheels", []):
			witems.append([str(w["id"]), "%s %s%s" % [str(w["id"]), str(w["grit"]), "" if bool(w["mounted"]) else " (recambio)"]])
		wheel_chips = Style.chips(witems, _on_wheel, wheel_box).buttons
		Style.clear(rpm_box)
		rpm_chips = {}
		if not steps.is_empty():
			var ritems: Array = []
			for st in steps:
				ritems.append([float(st), Fmt.num(st, 0) + " rpm"])
			rpm_chips = Style.chips(ritems, _on_rpm, rpm_box).buttons
	Style.pick_chip(wheel_chips, str(setup.get("wheel", "")))
	Style.pick_chip(rpm_chips, float(s.get("rpm_no_load", 0.0)))
	rpm_box.visible = not steps.is_empty()
	var selw: Dictionary = {}
	for w in mc.get("wheels", []):
		if bool(w["selected"]):
			selw = w
	var dmin: Variant = selw.get("diameter_min_mm")
	var dmax := float(selw.get("diameter_mm", 150.0))
	var ds: HSlider = diam_slider.slider
	# Cambiar el recorrido recorta el valor y emite value_changed: sin bloquear las señales, el diámetro de la muela
	# anterior (Ø150 de la esmeriladora) se recortaba al mínimo de la nueva (Ø153 de la piedra al agua) y se enviaba al
	# simulador como si lo hubiera elegido el usuario (muela gastada a 0,88 m/s en lugar de Ø200 a 1,15 m/s)
	ds.set_block_signals(true)
	ds.min_value = float(dmin) if dmin != null else dmax
	ds.max_value = dmax
	ds.value = float(selw.get("d_now_mm", dmax))
	ds.set_block_signals(false)
	(diam_slider.value as Label).text = Fmt.unit(selw.get("d_now_mm", dmax), 0, "mm")
	diam_slider.row.visible = dmin != null
	# Herramienta
	var mats: Array = []
	for id in SharpeningSim.KINDS[kind]["materials"]:
		mats.append([id, SharpeningSim.material_name(id)])
	_set_options(steel_opt, mats)
	Style.pick_option(steel_opt, str(tool.get("steel_id", "")))
	knife_box.visible = kind == "cuchillo"
	Style.pick_chip(style_chips, str(tool.get("style", "occidental")))
	Style.pick_option(use_opt, str(tool.get("use", "cocina")))
	var edge := bool(SharpeningSim.KINDS[kind]["edge"])
	edge_box.visible = edge
	drill_box.visible = kind == "broca"
	mill_box.visible = kind == "fresa"
	for key in tool_sliders:
		var parts := str(key).split(":")
		var tk := parts[parts.size() - 1]
		var prefix := parts[0] if parts.size() > 1 else ""
		if (prefix == "" and not edge) or (prefix != "" and prefix != kind):
			continue
		_show_slider(tool_sliders[key], tool.get(tk), _unit_for(tk), _decimals_for(tk))
	# Mano
	_show_slider(hand_sliders["force_n"], hand.get("force_n"), "N", 1)
	var fi := SharpeningSim.hand_force_info(float(hand.get("force_n", 0.0)))
	force_name.text = "%s (≈%s kgf) · escala de la mano: estimación, sin medida publicada" % [str(fi["name"]), Fmt.num(fi["kgf"], 1)]
	edge_hand_box.visible = edge
	_show_slider(hand_sliders["angle_deg"], hand.get("angle_deg"), "°", 1)
	Style.pick_chip(angle_mode_chips, str(hand.get("angle_mode", "plantilla")))
	_show_slider(hand_sliders["wobble_deg"], hand.get("wobble_deg"), "°", 1)
	hand_sliders["wobble_deg"].row.visible = str(hand.get("angle_mode", "")) == "pulso"
	Style.pick_chip(motion_chips, str(hand.get("motion", "barrido")))
	Style.pick_chip(sides_chips, str(hand.get("sides", "alternar")))
	(sides_chips["b"] as Button).visible = kind != "cortacesped"
	(sides_chips["alternar"] as Button).visible = kind != "cortacesped"
	var sweep := edge and str(hand.get("motion", "")) == "barrido"
	hand_sliders["sweep_mm_s"].row.visible = sweep
	hand_sliders["hold_s"].row.visible = not sweep
	_show_slider(hand_sliders["sweep_mm_s"], hand.get("sweep_mm_s"), "mm/s", 0)
	_show_slider(hand_sliders["hold_s"], hand.get("hold_s"), "s", 1)
	_show_slider(hand_sliders["passes"], hand.get("passes"), "", 0)
	_show_slider(hand_sliders["rest_s"], hand.get("rest_s"), "s", 1)
	dip_check.set_pressed_no_signal(bool(hand.get("dip", false)))
	Style.pick_chip(direction_chips, str(hand.get("direction", "contra")))
	Style.pick_chip(mode_chips, str(hand.get("mode", "periferia")))
	var mk := str(Machines.MACHINES[mid]["kind"])
	bench_box.visible = mk in ["banco", "banco_lenta", "combinada"]
	_show_slider(hand_sliders["rest_gap_mm"], hand.get("rest_gap_mm"), "mm", 1)


static func _unit_for(key: String) -> String:
	match key:
		"bevel_deg", "point_deg", "clearance_deg", "primary_deg", "secondary_deg":
			return "°"
		"flat_um", "wear_um":
			return "µm"
		"feed_mm_rev":
			return "mm/v"
		"teeth":
			return ""
	return "mm"


static func _decimals_for(key: String) -> int:
	match key:
		"thickness_mm", "lip_diff_mm", "feed_mm_rev":
			return 2
		"length_mm", "flat_um", "wear_um", "teeth", "point_deg":
			return 0
	return 1


func _show_slider(sl: Dictionary, value: Variant, u: String, decimals: int) -> void:
	if value == null:
		return
	(sl.slider as HSlider).set_value_no_signal(float(value))
	(sl.value as Label).text = Fmt.unit(value, decimals, u)


func _set_options(o: OptionButton, items: Array) -> void:
	var ids: Array = []
	for it in items:
		ids.append(it[0])
	if ids == o.get_meta("ids", []):
		return
	o.clear()
	for it in items:
		o.add_item(str(it[1]))
	o.set_meta("ids", ids)
	for c in o.item_selected.get_connections():
		o.item_selected.disconnect(c["callable"])
	o.item_selected.connect(func(i: int) -> void: _set_tool(ids[i], "steel_id"))


## Recomendación del core (sharpening.gd): ángulos, abrasivo, velocidad para la muela montada y granos.
func _fill_recommendation(s: Dictionary, setup: Dictionary) -> void:
	var rec: Dictionary = s.get("rec", {})
	var check: Dictionary = s.get("check", {})
	var tool: Dictionary = setup.get("tool", {})
	var kind := str(tool.get("kind", "cuchillo"))
	var ang: Dictionary = rec.get("angles", {})
	match kind:
		"broca":
			var rc: Dictionary = check.get("recommended", ang)
			var hx: Variant = rc.get("helix")
			out["angles"].text = "punta %s° · incidencia %s° · arista transversal %s° · %s%s" % [
				Fmt.num(_v(rc.get("point")), 0), Fmt.num(_v(rc.get("clearance")), 0), Fmt.num(_v(rc.get("chisel_edge")), 0),
				str((rc.get("din_1412", {}) as Dictionary).get("name", "")),
				(" · hélice " + str((hx as Dictionary).get("name", ""))) if hx is Dictionary else ""]
		"fresa":
			var rm: Dictionary = check.get("recommended", ang)
			out["angles"].text = "incidencia 1.ª %s° · 2.ª %s° · hélice %s° · dedo de apoyo %s" % [
				Fmt.num(_v(rm.get("primary_clearance")), 0), Fmt.num(_v(rm.get("secondary_clearance")), 0),
				Fmt.num(_v(rm.get("helix")), 0), Fmt.unit(check.get("offset_mm"), 2, "mm")]
		"cortacesped":
			var ma: Dictionary = SharpeningSim.MOWER_ANGLE
			out["angles"].text = "%s° de un solo lado (%s–%s° en algunas marcas) · mantener el original" % [Fmt.num(ma["value"], 0), Fmt.num(ma["brands_min"], 0), Fmt.num(ma["brands_max"], 0)]
		_:
			var ps: Dictionary = ang.get("per_side", {})
			out["angles"].text = "%s° por lado (%s–%s) · %s° incluido · uso: %s" % [Fmt.num(ps.get("value"), 1),
				Fmt.num(ps.get("min"), 1), Fmt.num(ps.get("max"), 1), Fmt.num(_v(ang.get("included")), 1), str(ang.get("use_name", ""))]
	var ab := str(rec.get("abrasive_id", ""))
	out["abrasive"].text = SharpeningSim.abrasive_name(ab)
	out["why"].text = "Por qué: " + str(rec.get("abrasive_reason", ""))
	var mounted := str(s.get("abrasive_id", ""))
	var sr := Report.speed_range(mounted if mounted != "" else "al2o3", bool(s.get("water", false)))
	var mk := str(Machines.MACHINES[str(setup.get("machine_id", ""))]["kind"])
	if bool(s.get("water", false)) or mk == "lenta_humeda" or sr.is_empty():
		out["speed"].text = "%s: la de serie, lenta y en agua" % Fmt.unit(s.get("vs_no_load_ms"), 2, "m/s")
	else:
		out["speed"].text = "%s con %s (Nachi, Kraus & Winter); la máquina va a %s" % [Fmt.span(sr["min"], sr["max"], 1) + " m/s", SharpeningSim.abrasive_name(mounted if mounted != "" else "al2o3"), Fmt.unit(s.get("vs_no_load_ms"), 1, "m/s")]
	var fin: Variant = rec.get("edge_finish")
	out["edge"].text = ("%s · %s" % [Fmt.unit(rec.get("edge_width_um"), 2, "µm"), str((fin as Dictionary).get("name", ""))]) if fin is Dictionary else "—"
	Style.clear(grit_list)
	var i := 1
	for step in rec.get("grits", []):
		grit_list.add_child(Style.label("%d. %s: %s" % [i, str(step.get("step", "")), str(step.get("grit", ""))], "TallerTenue", true))
		i += 1
	result_card.set_hint("calidad: " + Fmt.quality(rec.get("quality", "")))


static func _v(entry: Variant) -> Variant:
	return (entry as Dictionary).get("value") if entry is Dictionary else null


## Lecturas en directo, botones y estado del programa.
func _fill_live(s: Dictionary) -> void:
	var running := bool(s.get("running", false))
	var paused := bool(s.get("paused", false))
	btn_start.text = "Parar" if running else "Afilar"
	btn_pause.text = "Sigue" if paused else "Pausa"
	btn_pause.disabled = not running
	var phase := str(s.get("phase", ""))
	var phase_txt := str(PHASE_TEXT.get(phase, phase))
	status_label.text = "Pasada %s de %s · %s · %s de %s%s" % [Fmt.num(s.get("pass", 0), 0), Fmt.num(s.get("passes", 0), 0), phase_txt,
		Fmt.seconds(s.get("program_t_s")), Fmt.seconds(s.get("program_len_s")), " · en pausa" if paused else ""]
	var vs := float(s.get("vs_ms", 0.0))
	var maxv: Variant = s.get("max_speed_ms")
	reads["vel"].text = Fmt.unit(vs, 1 if vs >= 10.0 else 2, "m/s") + ((" · máx. %s" % Fmt.num(maxv, 1)) if maxv != null else "")
	reads["vel"].theme_type_variation = "TallerMal" if bool(s.get("over_speed", false)) else "TallerDato"
	var rpm_txt := "%s (vacío %s)" % [Fmt.unit(s.get("rpm"), 0, "rpm"), Fmt.num(s.get("rpm_no_load"), 0)]
	if bool(s.get("stalled", false)) and bool(s.get("touching", false)):
		rpm_txt = "calada: 0 rpm"
	elif bool(s.get("overloaded", false)) and bool(s.get("touching", false)):
		rpm_txt += " · se frena"
	reads["rpm"].text = rpm_txt
	reads["fuerza"].text = "%s%s" % [Fmt.unit(s.get("force_n"), 1, "N"), "" if bool(s.get("touching", false)) else " (en el aire)"]
	reads["potencia"].text = "%s (%s)" % [Fmt.unit(s.get("power_w"), 1, "W"), Fmt.span(s.get("power_min_w"), s.get("power_max_w"), 0) + " al apoyar"]
	var thermal := bool(s.get("thermal", false))
	if not thermal:
		reads["temp"].text = "no se calcula"
		reads["pico"].text = "—"
		reads["color"].text = "—"
		reads["hrc"].text = "no se calcula"
	else:
		var now := float(s.get("max_temp_c", 20.0))
		var band: Dictionary = s.get("temp_band", {})
		# sin programa en marcha el simulador no avanza: la temperatura es la del final de la última pasada o descanso
		var when := " al acabar" if not running and bool(s.get("finished", false)) else ""
		reads["temp"].text = ("quemado (> 723 °C)" if now >= Heat.BURN_C else "%s (%s)" % [Fmt.unit(now, 0, "°C"), Fmt.span(band.get("lo_c"), band.get("hi_c"), 0)]) + when
		reads["temp"].theme_type_variation = "TallerMal" if now >= Heat.BURN_C else "TallerDato"
		reads["pico"].text = "quemado (> 723 °C)" if bool(s.get("burned", false)) else Fmt.unit(s.get("peak_edge_c"), 0, "°C")
		reads["pico"].theme_type_variation = "TallerMal" if bool(s.get("burned", false)) else "TallerDato"
		var tint: Variant = s.get("tint")
		if tint is Dictionary:
			reads["color"].text = "%s · hasta %s" % [str(tint["name"]), Fmt.unit(s.get("tint_width_mm"), 2, "mm")]
			tint_swatch.color = Color(str(tint["hex"])) if Color.html_is_valid(str(tint["hex"])) else Style.c("panel3")
		else:
			reads["color"].text = "sin color"
			tint_swatch.color = Style.c("panel3")
		var hard: Variant = s.get("hardness")
		if hard is Dictionary:
			var loss := float(hard["loss_hrc"])
			reads["hrc"].text = "%s (−%s)%s" % [Fmt.unit(hard["hrc"], 1, "HRC"), Fmt.num(loss, 2), " · más allá de la curva" if bool(hard.get("beyond", false)) else ""]
			reads["hrc"].theme_type_variation = "TallerMal" if loss >= 1.0 else ("TallerAviso" if loss >= 0.1 else "TallerDato")
		else:
			reads["hrc"].text = "sin curva de revenido"
			reads["hrc"].theme_type_variation = "TallerDato"
	var bev: Dictionary = s.get("bevel", {})
	var kind := str(s.get("kind", "cuchillo"))
	if kind == "fresa":
		reads["bisel"].text = "no se calcula"
	elif kind == "broca":
		reads["bisel"].text = "flanco al %s %% del desgaste" % Fmt.num(float(bev.get("progress_mean", 0.0)) * 100.0, 0)
	elif float(bev.get("reached", 0.0)) >= 1.0:
		reads["bisel"].text = "vértice hecho en todo el filo"
	else:
		reads["bisel"].text = "al %s %% · faltan %s" % [Fmt.num(float(bev.get("progress", 0.0)) * 100.0, 0), Fmt.unit(bev.get("gap_um"), 1, "µm")]
	var burr := float(bev.get("burr", 0.0))
	if not bool(bev.get("edge", false)):
		reads["rebaba"].text = "—"
	elif burr > 0.0:
		reads["rebaba"].text = "en el %s %% (cara %s)" % [Fmt.num(burr * 100.0, 0), str(bev.get("burr_side", ""))]
	elif float(bev.get("burr_removed", 0.0)) > 0.0:
		reads["rebaba"].text = "quitada en el %s %%" % Fmt.num(float(bev["burr_removed"]) * 100.0, 0)
	else:
		reads["rebaba"].text = "todavía no"
	var side := str(s.get("side", ""))
	reads["pasada"].text = "%s/%s · %s" % [Fmt.num(s.get("pass", 0), 0), Fmt.num(s.get("passes", 0), 0), ("cara " + side) if side != "" else str(phase_txt)]
	var water := "en húmedo" if bool(s.get("water", false)) else ("en agua" if bool(s.get("dipped", false)) else "en seco")
	reads["arranque"].text = "%s · %s" % [Fmt.unit(s.get("removed_mm3"), 2, "mm³"), water]
	var work := runner.work_ms() if runner != null else 0.0
	var n_sec := (s.get("section_sharp", PackedByteArray()) as PackedByteArray).size()
	perf_label.text = "Simulador: %s por fotograma %s; %d secciones del filo repartidas entre los núcleos." % [Fmt.unit(work, 2, "ms"), "en su propio hilo" if runner.is_threaded() else "en el hilo de la interfaz", n_sec]


## Informe final: nota, criterios y consejos con su fuente.
func _fill_report(r: Dictionary) -> void:
	report_grade.text = str(r.get("grade_text", "—"))
	report_verdict.text = str(r.get("verdict", ""))
	var g: Variant = r.get("grade")
	report_grade.theme_type_variation = "TallerGrande"
	if g != null and float(g) < 5.0:
		report_grade.add_theme_color_override("font_color", Style.c("coral"))
	elif g != null and float(g) < 7.0:
		report_grade.add_theme_color_override("font_color", Style.c("gold"))
	else:
		report_grade.remove_theme_color_override("font_color")
	Style.clear(criteria_list)
	for c in r.get("criteria", []):
		criteria_list.add_child(Style.label("−%s · %s: %s" % [Fmt.num(c["lost"], 1), str(c["title"]), str(c["text"])], "TallerMal" if float(c["lost"]) >= 2.0 else "TallerAviso", true))
	if (r.get("criteria", []) as Array).is_empty() and bool(r.get("ran", false)):
		criteria_list.add_child(Style.label("Sin fallos.", "TallerBien"))
	Style.clear(advice_list)
	for a in r.get("advice", []):
		advice_list.add_child(Style.label("%s: %s" % [str(a["title"]), str(a["text"])], "TallerTenue", true))
		advice_list.add_child(Style.label("Fuente: " + str(a["source"]), "TallerNota", true))
	var ef: Variant = r.get("edge_finish")
	report_card.set_hint(("filo: %s" % Fmt.unit((ef as Dictionary).get("value_um"), 2, "µm")) if ef is Dictionary and (ef as Dictionary).get("value_um") != null else "nota de 0 a 10")
	if bool(r.get("finished", false)) and compact and report_card.is_inside_tree():
		pane.reveal(report_card)


func _fill_warnings(ws: Array) -> void:
	Style.clear(warn_list)
	if ws.is_empty():
		warn_list.add_child(Style.label("Sin avisos.", "TallerBien"))
	for w in ws:
		var code := str(w.get("code", ""))
		var variant := "TallerMal" if code in ["exceso_velocidad", "se_cala", "quemado", "maquina_no", "diamante_acero", "costado_muela"] else "TallerAviso"
		warn_list.add_child(Style.label(str(w.get("message", "")), variant, true))
		if str(w.get("source", "")) != "":
			warn_list.add_child(Style.label("Fuente: " + str(w["source"]), "TallerNota", true))
