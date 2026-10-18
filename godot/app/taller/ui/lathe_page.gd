## Taller industrial · página del torno: la escena 3D (vistas de detalle, frontal, superior y general; capa de
## acabado o de desviación del plano), la vista 2D de media sección con cotas y las tarjetas: pieza y control (CNC
## Fagor 8055 T o torno paralelo), reproducción, mando manual, lecturas en vivo, informe de inspección, alarmas y el
## programa editable con sus errores señalados.
## Todo lo que enseña sale de WorkshopState (core/taller/workshop_state.gd): aquí no se calcula nada del mecanizado.
## La sección llama a tick() en cada fotograma y a refresh() cuando el estado emite changed.
extends Control

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const ProfileView = preload("res://app/taller/ui/profile_view.gd")

const LATHE_SCENE := "res://app/taller/lathe_3d.tscn"
const VIEWS := [["detalle", "Detalle"], ["frontal", "Frontal"], ["superior", "Superior"], ["general", "General"]]
const OVERLAYS := [["acabado", "Acabado (Ra)"], ["desviacion", "Desviación del plano"]]
const PROGRAMS := [["pieza_a", "Pieza A · eje"], ["pieza_b", "Pieza B · bulón"], ["pieza_a_g42", "A con G42"],
	["pieza_b_g42", "B con G42 y RPT"], ["pieza_c", "Pieza C · rosca M20"], ["errores", "Con 3 errores"]]
const MODES := [["cnc", "CNC Fagor 8055 T"], ["manual", "Manual (paralelo)"]]
const PIECES := [["A", "Bruto A · Ø50"], ["B", "Bruto B · Ø40"], ["C", "Bruto C · Ø30"]]
const MOTION := {
	"rapid": "rápido", "feed": "avance", "arc": "arco", "dwell": "espera", "tool": "cambio de herramienta",
	"spindle": "cabezal", "coolant": "taladrina", "jog": "manivela", "manual": "avance automático", "end": "fin",
	"thread": "roscado",
}
## Cotas de rosca del informe (se escriben con tres decimales, como los diámetros)
const THREAD_KINDS := ["thread_major", "thread_pitch_diameter", "thread_minor", "thread_pitch"]
const EDIT_DEBOUNCE_S := 0.6

var state: WorkshopState
var pane: TwoPane
var view3d: View3D
var lathe3d: Node3D = null  # la escena lathe_3d.gd, cuando existe (solo dentro del árbol)
var profile_view: ProfileView
var view := "frontal"
var overlay := "acabado"
var compact := false

# Tarjetas y controles
var piece_card: Card
var play_card: Card
var manual_card: Card
var read_card: Card
var report_card: Card
var alarm_card: Card
var program_card: Card
var view_chips := {}
var overlay_chips := {}
var program_chips := {}
var mode_chips := {}
var piece_chips := {}
var speed_chips := {}
var jog_chips := {}
var program_row: Control
var piece_row: Control
var piece_info: Label
var btn_play: Button
var btn_step: Button
var btn_restart: Button
var btn_reset: Button
var status_label: Label
var reads := {}  # nombre → Label
var pc_bar: ProgressBar
var cut_note: Label
var alarm_list: VBoxContainer
var editor: TextEdit
var error_list: VBoxContainer
var warning_list: VBoxContainer
var report_score: Label
var report_verdict: Label
var report_grid: GridContainer
var ra_grid: GridContainer
var report_notes: VBoxContainer
var rpm_opt: OptionButton
var feed_slider: Dictionary
var feed_x_label: Label
var tool_opt: OptionButton
var work_opt: OptionButton
var coolant_check: CheckButton

var _serial := -1  # lathe_serial ya configurado en la escena 3D
var _shown_report: Variant = null
var _edit_left := -1.0
var _hl_line := -1
var _reveal_frames := 0
var _draw_key := ""
var _tool_key := ""
var _path_src: Variant = null  # interpretación cuya trayectoria tiene la vista 2D
var _path_cnc := true  # modo con el que se le pasó (en manual no hay trayectoria de programa)
var _built := false


## Construye la página con el estado del taller (una sola vez).
func build(ws: WorkshopState) -> void:
	if _built:
		return
	_built = true
	state = ws
	name = "Torno"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane = TwoPane.new()
	add_child(pane)
	_build_visual()
	_build_piece_card()
	_build_play_card()
	_build_manual_card()
	_build_readouts_card()
	_build_report_card()
	_build_alarm_card()
	_build_program_card()
	refresh()


func _build_visual() -> void:
	var bar := HFlowContainer.new()
	view_chips = Style.chips(VIEWS, set_view, bar).buttons
	var sep := VSeparator.new()
	bar.add_child(sep)
	overlay_chips = Style.chips(OVERLAYS, set_overlay, bar).buttons
	pane.visual.add_child(bar)
	view3d = View3D.new(LATHE_SCENE)
	view3d.name = "Torno3D"
	view3d.custom_minimum_size = Vector2(300, 300)
	view3d.scene_ready.connect(_on_scene_ready)
	pane.visual.add_child(view3d)
	profile_view = ProfileView.new()
	profile_view.name = "MediaSeccion"
	profile_view.custom_minimum_size = Vector2(300, 250)
	pane.visual.add_child(profile_view)
	Style.pick_chip(view_chips, view)
	Style.pick_chip(overlay_chips, overlay)


func _build_piece_card() -> void:
	piece_card = Card.new("Pieza y control")
	var mc := Style.chips(MODES, func(id: String) -> void: state.set_lathe_mode(id))
	mode_chips = mc.buttons
	piece_card.body.add_child(mc.box)
	var pc := Style.chips(PROGRAMS, func(id: String) -> void: state.set_program(id))
	program_chips = pc.buttons
	program_row = pc.box
	piece_card.body.add_child(program_row)
	var bc := Style.chips(PIECES, func(id: String) -> void: state.set_piece(id))
	piece_chips = bc.buttons
	piece_row = bc.box
	piece_card.body.add_child(piece_row)
	piece_info = Style.label("", "TallerTenue", true)
	piece_card.body.add_child(piece_info)
	pane.side.add_child(piece_card)


func _build_play_card() -> void:
	play_card = Card.new("Reproducción", "tiempo simulado")
	var row := HFlowContainer.new()
	btn_play = Style.button("Marcha", "TallerAccion")
	btn_play.pressed.connect(func() -> void: state.toggle_play())
	row.add_child(btn_play)
	btn_step = Style.button("Bloque a bloque")
	btn_step.pressed.connect(func() -> void: state.step_block())
	row.add_child(btn_step)
	btn_restart = Style.button("Reiniciar pieza")
	btn_restart.pressed.connect(func() -> void: state.restart())
	row.add_child(btn_restart)
	btn_reset = Style.button("RESET", "TallerPeligro")
	btn_reset.pressed.connect(func() -> void: state.reset_alarm())
	row.add_child(btn_reset)
	play_card.body.add_child(row)
	var items: Array = []
	for s: float in WorkshopState.SPEEDS:
		items.append([s, "×" + Fmt.num(s, 2 if s < 0.5 else (1 if s < 1.0 else 0))])
	var sc := Style.chips(items, func(s: float) -> void: state.set_speed(s))
	speed_chips = sc.buttons
	play_card.body.add_child(Style.label("Velocidad de la simulación", "TallerTenue", true))
	play_card.body.add_child(sc.box)
	status_label = Style.label("", "TallerAviso", true)
	play_card.body.add_child(status_label)
	pane.side.add_child(play_card)


func _build_manual_card() -> void:
	manual_card = Card.new("Mando manual", "torno paralelo")
	var b := manual_card.body
	# Cabezal
	b.add_child(Style.label("Cabezal (caja de 12 velocidades)", "TallerTenue", true))
	var srow := HBoxContainer.new()
	var speeds: Array = []
	for s in state.manual_speeds():
		speeds.append([float(s), Fmt.num(s, 0) + " rpm"])
	rpm_opt = Style.options(speeds, func(v: float) -> void: state.set_manual_rpm(v))
	srow.add_child(rpm_opt)
	for d in [["cw", "M3"], ["ccw", "M4"], ["stop", "M5"]]:
		var btn := Style.button(d[1], "TallerPeligro" if d[0] == "stop" else "")
		btn.tooltip_text = { "cw": "Cabezal a derechas", "ccw": "Cabezal a izquierdas", "stop": "Parar el cabezal" }[d[0]]
		btn.pressed.connect(state.manual_spindle.bind(d[0]))
		srow.add_child(btn)
	b.add_child(srow)
	# Avance automático
	var r: Array = state.manual_feed_range()
	feed_slider = Style.slider("Avance automático (longitudinal)", float(r[0]), float(r[1]), 0.01,
		func(v: float) -> void: state.set_manual_feed(v))
	b.add_child(feed_slider.row)
	feed_x_label = Style.label("", "TallerNota", true)
	b.add_child(feed_x_label)
	var frow := HFlowContainer.new()
	for f in [["z", -1.0, "Cilindrar Z−"], ["x", -1.0, "Refrentar X−"], ["z", 1.0, "Salir Z+"], ["x", 1.0, "Salir X+"]]:
		var btn := Style.button(f[2])
		btn.pressed.connect(state.manual_auto_feed.bind(f[0], f[1]))
		frow.add_child(btn)
	var stop := Style.button("Desembragar", "TallerPeligro")
	stop.pressed.connect(func() -> void: state.manual_feed_stop())
	frow.add_child(stop)
	b.add_child(frow)
	# Manivelas
	b.add_child(Style.label("Manivelas (X en diámetro, como el visualizador)", "TallerTenue", true))
	var steps: Array = []
	for s: float in WorkshopState.JOG_STEPS:
		steps.append([s, Fmt.num(s, 3 if s < 0.01 else (2 if s < 0.1 else (1 if s < 1.0 else 0))) + " mm"])
	var jc := Style.chips(steps, func(s: float) -> void: state.set_jog_step(s))
	jog_chips = jc.buttons
	b.add_child(jc.box)
	for axis in ["x", "z"]:
		var jrow := HBoxContainer.new()
		jrow.add_child(Style.label(axis.to_upper(), "TallerDato"))
		for k in [-10, -1, 1, 10]:
			var btn := Style.button(("+" if k > 0 else "−") + str(absi(k)))
			btn.tooltip_text = "%d clics de la manivela %s" % [absi(k), axis.to_upper()]
			btn.pressed.connect(state.jog.bind(axis, k))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			jrow.add_child(btn)
		b.add_child(jrow)
	# Herramienta, material y taladrina
	var tools: Array = []
	for id in LatheTools.ids():
		var t := LatheTools.tool(id)
		tools.append([id, "%s · %s · rε %s" % [str(t["insert"]), str(t["shape_name"]), Fmt.num(t["re_mm"], 1)]])
	b.add_child(Style.label("Herramienta (portaherramientas y plaquita)", "TallerTenue", true))
	tool_opt = Style.options(tools, func(id: String) -> void: state.set_manual_tool(id))
	b.add_child(tool_opt)
	var works: Array = [["", "El del plano"]]
	for id in WorkMaterials.ids():
		works.append([id, str(WorkMaterials.get_material(id)["name"])])
	b.add_child(Style.label("Material del bruto", "TallerTenue"))
	work_opt = Style.options(works, func(id: String) -> void: state.set_manual_work(id))
	b.add_child(work_opt)
	coolant_check = CheckButton.new()
	coolant_check.text = "Taladrina"
	coolant_check.focus_mode = Control.FOCUS_NONE
	coolant_check.toggled.connect(func(on: bool) -> void: state.set_coolant(on))
	b.add_child(coolant_check)
	var measure := Style.button("Medir la pieza contra el plano", "TallerAccion")
	measure.pressed.connect(func() -> void: state.measure())
	b.add_child(measure)
	pane.side.add_child(manual_card)


func _build_readouts_card() -> void:
	read_card = Card.new("Lecturas", "en vivo")
	var g := Style.grid()
	for k in [["rpm", "Cabezal"], ["vc", "vc"], ["f", "Avance"], ["ap", "ap"], ["pc", "Pc"], ["fc", "Fc · kc"],
			["ra", "Ra detrás de la punta"], ["vol", "Arrancado"], ["t", "Tiempo"], ["n", "Bloque"],
			["pos", "Punta"], ["tool", "Herramienta"], ["thread", "Roscado"], ["cool", "Taladrina"]]:
		reads[k[0]] = Style.grid_row(g, k[1])
	read_card.body.add_child(g)
	pc_bar = Style.bar("gold")
	read_card.body.add_child(pc_bar)
	cut_note = Style.label("", "TallerAviso", true)
	read_card.body.add_child(cut_note)
	pane.side.add_child(read_card)


func _build_report_card() -> void:
	report_card = Card.new("Informe de inspección", "pieza contra su plano")
	var head := HBoxContainer.new()
	report_score = Style.label("", "TallerGrande")
	head.add_child(report_score)
	report_verdict = Style.label("", "TallerTenue", true)
	report_verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(report_verdict)
	report_card.body.add_child(head)
	report_grid = Style.grid(5)
	report_grid.add_theme_constant_override("h_separation", 8)
	report_card.body.add_child(report_grid)
	ra_grid = Style.grid(4)
	ra_grid.add_theme_constant_override("h_separation", 8)
	report_card.body.add_child(ra_grid)
	report_notes = VBoxContainer.new()
	report_card.body.add_child(report_notes)
	report_card.visible = false
	pane.side.add_child(report_card)


func _build_alarm_card() -> void:
	alarm_card = Card.new("Alarmas")
	alarm_list = VBoxContainer.new()
	alarm_card.body.add_child(alarm_list)
	pane.side.add_child(alarm_card)


func _build_program_card() -> void:
	program_card = Card.new("Programa · Fagor 8055 T", "editable")
	editor = TextEdit.new()
	editor.name = "Editor"
	editor.custom_minimum_size = Vector2(200, 280)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	editor.scroll_fit_content_height = false
	editor.highlight_current_line = false
	var hl := CodeHighlighter.new()
	hl.number_color = Style.c("ice")
	hl.symbol_color = Style.c("dim")
	hl.function_color = Style.c("text")
	hl.member_variable_color = Style.c("text")
	hl.add_color_region(";", "", Style.c("dimmer"), true)
	editor.syntax_highlighter = hl
	editor.text_changed.connect(_on_text_changed)
	program_card.body.add_child(editor)
	var row := HBoxContainer.new()
	var restore := Style.button("Restaurar el ejemplo")
	restore.pressed.connect(func() -> void: state.set_program(state.program_id))
	row.add_child(restore)
	program_card.body.add_child(row)
	error_list = VBoxContainer.new()
	program_card.body.add_child(error_list)
	warning_list = VBoxContainer.new()
	program_card.body.add_child(warning_list)
	pane.side.add_child(program_card)


# ─────────────────────────── modo teléfono ───────────────────────────

func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)
	view3d.custom_minimum_size = Vector2(240, 280 if on else 300)
	profile_view.custom_minimum_size = Vector2(240, 220 if on else 250)
	_build_report_table()
	if lathe3d != null:
		# en teléfono, menos lados y anillos en la malla de la pieza (lo que recomienda la escena, fuentes-u9)
		lathe3d.call("configure_lod", 32 if on else 64, 800 if on else 2000)


## La página se enseña: crea la escena 3D la primera vez (solo dentro del árbol).
func on_shown() -> void:
	view3d.ensure_scene()


func _on_scene_ready(scene: Node) -> void:
	lathe3d = scene as Node3D
	if compact:
		lathe3d.call("configure_lod", 32, 800)
	_serial = -1
	_configure_3d()
	lathe3d.call("set_view", view, true)


## Torno nuevo (otra pieza, reinicio, otro modo): bruto, garras, material, plano y fuente del perfil.
func _configure_3d() -> void:
	if lathe3d == null or _serial == state.lathe_serial:
		return
	_serial = state.lathe_serial
	var st := state.stock()
	lathe3d.call("set_chuck_grip", float(st["clamp"]))
	lathe3d.call("set_work_material", str(st["work_kind"]))
	lathe3d.call("set_plan", state.band)
	lathe3d.call("set_profile_source", state)
	lathe3d.call("set_overlay", overlay)
	lathe3d.call("set_thread_pitch", _thread_pitch())
	_tool_key = ""


## Paso de la hélice del programa para la escena 3D: el del primer tramo de roscado del IR, con el signo del sentido
## de giro del cabezal y del avance (M03 hacia el plato: +). 0 si el programa no rosca.
func _thread_pitch() -> float:
	if state.lathe_mode != "cnc":
		return 0.0
	var dir := "cw"
	for m in state.interp.get("moves", []):
		match str(m["type"]):
			"spindle":
				dir = str(m["spindle"]["dir"])
			"thread":
				var sgn := 1.0 if dir != "ccw" else -1.0
				if float(m["to"]["z"]) > float(m["from"]["z"]):
					sgn = -sgn
				return sgn * float(m["thread"]["pitch"])
	return 0.0


func set_view(id: String) -> void:
	view = id
	Style.pick_chip(view_chips, id)
	if lathe3d != null:
		lathe3d.call("set_view", id, false)


func set_overlay(id: String) -> void:
	overlay = id
	Style.pick_chip(overlay_chips, id)
	if lathe3d != null:
		lathe3d.call("set_overlay", id)


# ─────────────────────────── cada fotograma ───────────────────────────

func tick(delta: float) -> void:
	if state == null:
		return
	if _edit_left > 0.0:
		_edit_left -= delta
		if _edit_left <= 0.0:
			apply_editor_text()
	var rd := state.lathe_readings()
	_update_3d(rd)
	_update_readouts(rd)
	_update_profile_view()
	_update_current_line(int(rd["line"]))
	if _reveal_frames > 0:
		_reveal_frames -= 1
		if _reveal_frames == 0:
			pane.reveal(report_card)


func _update_3d(rd: Dictionary) -> void:
	if lathe3d == null:
		return
	_configure_3d()
	var rpm := float(rd["rpm"])
	lathe3d.call("set_rpm", -rpm if str(rd["dir"]) == "ccw" else rpm)
	var running := state.is_running()
	lathe3d.call("set_cutting", bool(rd["cutting"]) and running, float(rd["pc_kw"]))
	lathe3d.call("set_coolant", bool(rd["coolant"]))
	var key := "%s|%s" % [rd["tool_id"], rd["feed"]]
	if key != _tool_key:
		_tool_key = key
		lathe3d.call("set_nose_radius", float(rd["re_mm"]))
		lathe3d.call("set_tool_shape", state.lathe.tool())
		# (el avance de un roscado es el paso: no son marcas de avance del resto de la pieza)
		if str(rd["feed_mode"]) == "mmrev" and rd.get("thread") == null:
			lathe3d.call("set_feed", float(rd["feed"]))


func _update_readouts(rd: Dictionary) -> void:
	var dir := str({ "cw": "M3", "ccw": "M4", "stop": "parado" }.get(str(rd["dir"]), ""))
	reads["rpm"].text = "%s rpm · %s" % [Fmt.num(rd["rpm"], 0), dir]
	var css: Variant = rd["css"]
	reads["vc"].text = Fmt.unit(rd["vc"], 0, "m/min") + (" · G96 constante" if css is Dictionary else "")
	reads["f"].text = Fmt.unit(rd["feed"], 3, "mm/vuelta" if str(rd["feed_mode"]) == "mmrev" else "mm/min")
	reads["ap"].text = Fmt.unit(rd["ap_mm"], 2, "mm")
	reads["pc"].text = "%s de %s" % [Fmt.unit(rd["pc_kw"], 2, "kW"), Fmt.unit(rd["power_kw"], 1, "kW")]
	pc_bar.value = clampf(float(rd["pc_kw"]) / maxf(float(rd["power_kw"]), 1e-6), 0.0, 1.0)
	reads["fc"].text = "%s · %s" % [Fmt.unit(rd["fc_n"], 0, "N"), Fmt.unit(rd["kc"], 0, "N/mm²")]
	reads["ra"].text = Fmt.unit(rd["ra_um"], 2, "µm")
	reads["vol"].text = Fmt.unit(float(rd["removed_mm3"]) / 1000.0, 2, "cm³")
	var t := Fmt.seconds(rd["t_s"])
	if rd["program_time_s"] != null:
		t += " de ~%s estimados" % Fmt.seconds(rd["program_time_s"])
	reads["t"].text = t
	var n := int(rd["block_n"])
	var motion := str(MOTION.get(str(rd["motion"]), str(rd["motion"])))
	reads["n"].text = ("N%d · línea %d" % [n, int(rd["line"])] if n >= 0 else "—") + (" · " + motion if motion != "" else "")
	reads["pos"].text = "X%s Z%s" % [Fmt.num(rd["x_diam"], 3), Fmt.num(rd["z"], 3)]
	# la plaquita y su radio (el portaherramientas, en la vista 2D)
	reads["tool"].text = "%s · rε %s" % [str(rd["tool_id"]).get_slice("/", 1), Fmt.num(rd["re_mm"], 1)]
	# roscado: paso, pasada n de N y profundidad (lo publica el torno con cada tramo sincronizado)
	var th: Variant = rd.get("thread", null)
	if th is Dictionary:
		var how := "radial" if float(th.get("infeed_deg", 0.0)) <= 0.0 else "flanco %s°" % Fmt.num(th["infeed_deg"], 0)
		if int(th.get("passes", 0)) > 0:
			reads["thread"].text = "paso %s · pasada %d de %d · %s de %s · %s" % [Fmt.unit(th["pitch"], 2, "mm"),
				int(th["pass"]), int(th["passes"]), Fmt.num(th["depth"], 2), Fmt.unit(th["total"], 2, "mm"), how]
		else:
			reads["thread"].text = "paso %s · %s" % [Fmt.unit(th["pitch"], 2, "mm"), str(th.get("kind", "G33"))]
	else:
		reads["thread"].text = "—"
	reads["cool"].text = "sí" if bool(rd["coolant"]) else "no"
	var note := ""
	if not bool(rd["cut_ok"]) and str(rd["cut_reason"]) != "":
		note = "Sin datos de fuerza de corte: " + str(rd["cut_reason"])
	cut_note.text = note
	cut_note.visible = note != ""


func _update_profile_view() -> void:
	var st := state.lathe_state()
	var key := "%d|%d|%s|%s" % [state.lathe_serial, int(st["ticks"]), state.tool_pose(), state.report != null]
	if key == _draw_key:
		return
	_draw_key = key
	profile_view.set_data(state.peek_profile(), state.drawing, state.stock(), state.lathe.machine(), state.lathe.tool(),
		state.tool_pose(), state.report)


func _update_current_line(line: int) -> void:
	if state.lathe_mode != "cnc":
		line = 0
	if line == _hl_line:
		return
	if _hl_line > 0:
		editor.set_line_background_color(_hl_line - 1, _line_color(_hl_line))
	_hl_line = line
	if line > 0 and line <= editor.get_line_count():
		editor.set_line_background_color(line - 1, Color(Style.c("mint"), 0.22))


## Fondo de una línea del editor: coral si tiene un error del intérprete.
func _line_color(line: int) -> Color:
	for e in state.errors():
		if int(e["line"]) == line:
			return Color(Style.c("coral"), 0.28)
	return Color(0, 0, 0, 0)


func _on_text_changed() -> void:
	_edit_left = EDIT_DEBOUNCE_S


## Lleva el texto del editor al estado (se reinterpreta y se pone un bruto nuevo).
func apply_editor_text() -> void:
	_edit_left = -1.0
	state.set_program_text(editor.text)


# ─────────────────────────── cambios del estado ───────────────────────────

func refresh() -> void:
	if state == null:
		return
	var cnc := state.lathe_mode == "cnc"
	Style.pick_chip(mode_chips, state.lathe_mode)
	Style.pick_chip(program_chips, state.program_id)
	Style.pick_chip(piece_chips, state.piece)
	Style.pick_chip(speed_chips, state.speed)
	Style.pick_chip(jog_chips, state.jog_step)
	program_row.visible = cnc
	piece_row.visible = not cnc
	var st := state.stock()
	var mat := WorkMaterials.get_material(str(st["work_id"]))
	piece_info.text = "%s · %s · bruto Ø%s × %s con %s mm en el plato · %s" % [
		str(state.drawing.get("name", "")), str(mat.get("name", st["work_id"])), Fmt.num(st["d"], 0),
		Fmt.num(st["length"], 0), Fmt.num(st["clamp"], 0), str(state.lathe.machine()["name"])]
	# Reproducción
	btn_play.text = "Pausa" if state.playing else "Marcha"
	btn_play.visible = cnc
	btn_step.visible = cnc
	btn_reset.visible = state.lathe.is_halted()
	btn_restart.text = "Reiniciar pieza" if cnc else "Bruto nuevo"
	status_label.text = state.status
	status_label.visible = state.status != ""
	manual_card.visible = not cnc
	program_card.visible = cnc
	# Mando manual
	Style.pick_option(rpm_opt, state.manual_rpm)
	(feed_slider.slider as HSlider).set_value_no_signal(state.manual_feed)
	(feed_slider.value as Label).text = Fmt.unit(state.manual_feed, 2, "mm/vuelta")
	feed_x_label.text = "Transversal (X): %s, a la relación de la caja" % Fmt.unit(state.manual_feed_x(), 3, "mm/vuelta")
	Style.pick_option(tool_opt, state.manual_tool)
	Style.pick_option(work_opt, state.manual_work)
	coolant_check.set_pressed_no_signal(state.coolant)
	# Programa
	editor.editable = cnc and not state.playing
	if editor.text != state.program_text and _edit_left <= 0.0:
		editor.text = state.program_text
		_hl_line = -1
	if not is_same(state.interp, _path_src) or _path_cnc != cnc:
		_path_src = state.interp
		_path_cnc = cnc
		profile_view.set_path(state.interp.get("moves", []) if cnc else [])
	_mark_error_lines()
	_fill_messages()
	_fill_alarms()
	_fill_report()


func _mark_error_lines() -> void:
	for i in editor.get_line_count():
		editor.set_line_background_color(i, Color(0, 0, 0, 0))
	for e in state.errors():
		var l := int(e["line"]) - 1
		if l >= 0 and l < editor.get_line_count():
			editor.set_line_background_color(l, Color(Style.c("coral"), 0.28))
	_hl_line = -1


func _fill_messages() -> void:
	Style.clear(error_list)
	Style.clear(warning_list)
	var errs := state.errors()
	if errs.is_empty():
		error_list.add_child(Style.label("Sin errores de programa.", "TallerBien"))
	else:
		var head := "1 error" if errs.size() == 1 else "%d errores" % errs.size()
		error_list.add_child(Style.label(head + " (el control no ejecuta un bloque erróneo):", "TallerMal", true))
		for e in errs:
			error_list.add_child(Style.label(str(e["message"]), "TallerMal", true))
	for w in state.warnings():
		warning_list.add_child(Style.label("Aviso · " + str(w["message"]), "TallerAviso", true))


func _fill_alarms() -> void:
	Style.clear(alarm_list)
	var al := state.lathe_alarms()
	if al.is_empty():
		alarm_list.add_child(Style.label("Sin alarmas.", "TallerBien"))
	for a in al:
		var v := "TallerMal" if bool(a["halt"]) else "TallerAviso"
		alarm_list.add_child(Style.label("%s%s" % [str(a["title"]), " · detiene la máquina" if bool(a["halt"]) else " · aviso"], v))
		alarm_list.add_child(Style.label(str(a["message"]), "TallerTenue", true))
	alarm_card.set_hint("%d" % al.size() if not al.is_empty() else "")


func _fill_report() -> void:
	var rep: Variant = state.report
	report_card.visible = rep != null
	if is_same(rep, _shown_report):
		return
	var had := _shown_report != null
	_shown_report = rep
	_build_report_table()
	if rep == null:
		if had:
			set_overlay("acabado")  # pieza nueva: vuelve la capa del acabado
		return
	# La primera vez: capa de desviación y la tarjeta a la vista
	set_overlay("desviacion")
	_reveal_frames = 2


## La tabla del informe mostrado (se rehace también al pasar a teléfono: allí va más estrecha, sin el código de la
## tolerancia, que ya lleva el rótulo de la cota, y con la cabecera abreviada).
func _build_report_table() -> void:
	Style.clear(report_grid)
	Style.clear(ra_grid)
	Style.clear(report_notes)
	if _shown_report == null:
		return
	var r: Dictionary = _shown_report
	report_grid.add_theme_constant_override("h_separation", 6 if compact else 8)
	report_score.text = "%s / 10" % Fmt.num(r["score"], 1)
	var fails := 0
	for f in r["features"]:
		if not bool(f.get("ok", false)):
			fails += 1
	if fails == 0:
		report_verdict.text = "todas las cotas en tolerancia"
	else:
		report_verdict.text = "1 cota fuera de tolerancia" if fails == 1 else "%d cotas fuera de tolerancia" % fails
	for h in (["Cota", "Medida", "Nom.", "Tolerancia", "Apto"] if compact else ["Cota", "Medida", "Nominal", "Tolerancia", "Apto"]):
		report_grid.add_child(Style.label(h, "TallerNota"))
	for f in r["features"]:
		var ok := bool(f.get("ok", false))
		var dec := 3 if str(f["kind"]) in ["diameter", "cone"] or str(f["kind"]) in THREAD_KINDS else 2
		report_grid.add_child(Style.label(str(f["label"]).get_slice(" (", 0), "TallerTenue"))
		report_grid.add_child(Style.label(Fmt.num(f.get("measured"), dec), "TallerBien" if ok else "TallerMal"))
		var nom_dec := 1 if float(f["nominal"]) != floorf(float(f["nominal"])) else 0
		if str(f["kind"]) in THREAD_KINDS and nom_dec > 0:
			nom_dec = 3  # d2 y d3 básicos de la rosca (18,376 y 16,933): con un decimal no se reconocen
		report_grid.add_child(Style.label(Fmt.num(f.get("nominal"), nom_dec), "TallerTenue"))
		# Límites que da el core (mín.–máx.) con el código de la tolerancia (ISO 286 o la general de ISO 2768)
		var tol := Fmt.span(f.get("lower"), f.get("upper"), dec)
		var iso := str(f.get("iso", "")).replace("ISO ", "")
		if iso != "" and not compact:
			tol = "%s · %s" % [iso, tol]
		report_grid.add_child(Style.label(tol, "TallerNota"))
		report_grid.add_child(Style.label("sí" if ok else "no", "TallerBien" if ok else "TallerMal"))
	for h in ["Zona Ra", "Medido", "Pide", "Apto"]:
		ra_grid.add_child(Style.label(h, "TallerNota"))
	for z in r["ra"]:
		var ok := bool(z.get("ok", false))
		ra_grid.add_child(Style.label(str(z["zone"]), "TallerTenue"))
		ra_grid.add_child(Style.label(Fmt.unit(z.get("measured"), 2, "µm"), "TallerBien" if ok else "TallerMal"))
		ra_grid.add_child(Style.label(Fmt.unit(z.get("required"), 1, "µm"), "TallerTenue"))
		ra_grid.add_child(Style.label("sí" if ok else "no", "TallerBien" if ok else "TallerMal"))
	report_notes.add_child(Style.label("Diámetros con un palpador de 1 mm sobre las crestas; Ra por la regla del 16 % (ISO 4288); la nota pondera los diámetros ×2 (elección de diseño, no física).", "TallerNota", true))
	report_notes.add_child(Style.label("Sin G41/G42 la punta teórica recorre el contorno y los chaflanes, conos y radios salen desplazados rε; con G42 (piezas A y B con G42) el control compensa el radio y salen a cota.", "TallerNota", true))
	if r.get("thread") != null:
		report_notes.add_child(Style.label("Rosca medida en la sección axial del perfil: Ø exterior sobre las crestas, Ø de fondo en los surcos completos, paso por ajuste de sus centros y Ø medio donde el surco mide medio paso (ISO 965-1, 6g). El modelo es axisimétrico: el perfil es la sección axial y la hélice existe en el tiempo (cada pasada espera al mismo ángulo del cabezal); la escena 3D la dibuja retorciendo los anillos.", "TallerNota", true))
	for w in state.warnings():
		report_notes.add_child(Style.label("Aviso del intérprete · " + str(w["message"]), "TallerAviso", true))
