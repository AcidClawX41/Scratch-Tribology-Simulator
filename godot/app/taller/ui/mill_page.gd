## Taller industrial · página de la fresadora (unidad 1e).
##
## A la izquierda, el esquema animado visto desde arriba (la fresa con sus dientes, el arco de contacto y el espesor de
## viruta que varía) o la máquina en 3D, y la gráfica de un barrido (potencia en el motor frente a ae, fz, ap o vc,
## calculado en hilos por MillDrillState). A la derecha, las tarjetas: resultado de cutting.gd (giro, vf, hm y hex, kc
## con su banda, fuerza media, potencia en el filo y en el motor frente a la de la máquina, par, caudal, paso de dientes,
## vida de Taylor como estimación, calidad de los datos), herramienta (fresa de planear o de mango, material de corte y
## recubrimiento, Ø, z, κr), pieza (material con su grupo ISO y su fuente), condiciones de corte (vc o rpm, fz, ap, ae,
## centrada, en concordancia o en oposición, desgaste, taladrina), máquina (la ficha de la Lagun FTV 2, ajustable) y
## avisos con sus fuentes.
## Todo lo que enseña sale de MillDrillState (core/taller/mill_drill_state.gd): aquí no se calcula nada del corte.
extends Control

const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const MillView = preload("res://app/taller/mill3d/mill_view.gd")
const SweepChart = preload("res://app/taller/mill3d/sweep_chart.gd")

const KIND := "mill"
const SCENE_3D := "res://app/taller/mill3d/mill_3d.tscn"
const VIEWS := [["esquema", "Esquema desde arriba"], ["maquina", "Máquina 3D"]]
const CAM_VIEWS := [["detalle", "Detalle"], ["frontal", "Frontal"], ["superior", "Superior"], ["general", "General"]]
const TOOL_TYPES := [["planear", "Fresa de planear"], ["mango", "Fresa de mango"]]
const SPEED_MODES := [["vc", "Por vc"], ["rpm", "Por rpm"]]
const WEAR := [["nuevo", "nuevo"], ["ligero", "ligero"], ["medio", "medio"], ["fuerte", "fuerte"]]
const POSITION_ITEMS := [["centrada", "Centrada"], ["concordancia", "Concordancia"], ["oposicion", "Oposición"]]
## Deslizadores del corte: [clave, rótulo, mín, máx, paso, decimales, unidad]. Recorridos de interfaz (no datos).
const FIELDS := [
	["dc_mm", "Diámetro de la fresa Dc", 6.0, 160.0, 1.0, 0, "mm"],
	["z", "Dientes z", 1.0, 12.0, 1.0, 0, ""],
	["vc", "Velocidad de corte vc", 10.0, 600.0, 5.0, 0, "m/min"],
	["rpm", "Giro del husillo n", 50.0, 6000.0, 10.0, 0, "rpm"],
	["fz_mm", "Avance por diente fz", 0.01, 0.4, 0.005, 3, "mm"],
	["ap_mm", "Profundidad axial ap", 0.1, 20.0, 0.1, 1, "mm"],
	["ae_mm", "Ancho de corte ae", 0.5, 160.0, 0.5, 1, "mm"],
]
## Deslizadores de la máquina: [clave, rótulo, mín, máx, paso, decimales, unidad].
const MACHINE_FIELDS := [
	["pmax_kw", "Potencia del motor", 0.5, 15.0, 0.1, 1, "kW"],
	["rpm_max", "Tope de giro", 500.0, 12000.0, 50.0, 0, "rpm"],
	["eta", "Rendimiento η", 0.6, 0.95, 0.01, 2, ""],
]

var md: MillDrillState
var pane: TwoPane
var view: MillView
var view3d: View3D = null
var mill3d: Node3D = null
var chart: SweepChart
var compact := false
var view_mode := "esquema"
var cam_view := "detalle"
var sweep_output := "pmotor_kw"

var view_chips := {}
var cam_chips := {}
var cam_box: HFlowContainer
var type_chips := {}
var kappa_box: HFlowContainer
var kappa_chips := {}
var speed_chips := {}
var position_chips := {}
var wear_chips := {}
var anim_chips := {}
var sweep_x_chips := {}
var sweep_y_chips := {}
var tool_opt: OptionButton
var work_opt: OptionButton
var coolant_check: CheckButton
var sliders := {}  # clave → { row, slider, value }
var machine_sliders := {}
var tool_info: Label
var work_info: Label
var iso_swatch: ColorRect
var position_note: Label
var machine_info: Label
var btn_run: Button
var btn_ficha: Button
var out := {}  # nombre → Label
var power_bar: ProgressBar
var band_label: Label
var parts_label: Label
var quality_label: Label
var warn_list: VBoxContainer
var sources_label: Label
var result_card: Card
var _tool_key := ""
var _built := false


func build(state: MillDrillState) -> void:
	if _built:
		return
	_built = true
	md = state
	name = "Fresadora"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane = TwoPane.new()
	add_child(pane)
	_build_visual()
	_build_result_card()
	_build_tool_card()
	_build_work_card()
	_build_cut_card()
	_build_machine_card()
	_build_warn_card()
	md.sweep_ready.connect(_on_sweep_ready)
	refresh()


# ─────────────────────────── construcción ───────────────────────────

func _build_visual() -> void:
	var bar := HFlowContainer.new()
	var items: Array = VIEWS if ResourceLoader.exists(SCENE_3D) else [VIEWS[0]]
	view_chips = Style.chips(items, set_view, bar).buttons
	pane.visual.add_child(bar)
	# Vistas de la cámara 3D, en su propia fila (dos contenedores de flujo anidados se apilarían en columna)
	cam_box = HFlowContainer.new()
	cam_chips = Style.chips(CAM_VIEWS, set_cam_view, cam_box).buttons
	cam_box.visible = false
	Style.pick_chip(cam_chips, cam_view)
	pane.visual.add_child(cam_box)
	view = MillView.new()
	view.name = "EsquemaFresado"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.visual.add_child(view)
	if ResourceLoader.exists(SCENE_3D):
		view3d = View3D.new(SCENE_3D)
		view3d.name = "Fresadora3D"
		view3d.custom_minimum_size = Vector2(300, 320)
		view3d.visible = false
		view3d.scene_ready.connect(_on_scene_ready)
		pane.visual.add_child(view3d)
	# Barrido: qué se barre y qué se mira
	var sbar := HFlowContainer.new()
	var xs: Array = []
	for key in MillDrillState.SWEEP_AXES[KIND]:
		xs.append([key, str(MillDrillState.SWEEP_AXES[KIND][key]["label"]).get_slice(" ", 0) + " " + _axis_symbol(key)])
	sweep_x_chips = Style.chips(xs, func(k: String) -> void: md.set_sweep_x(KIND, k), sbar).buttons
	var sep := VSeparator.new()
	sbar.add_child(sep)
	var ys: Array = []
	for o in MillDrillState.SWEEP_OUTPUTS[KIND]:
		ys.append([o[0], str(o[1]).get_slice(" (", 0)])
	sweep_y_chips = Style.chips(ys, set_sweep_output, sbar).buttons
	pane.visual.add_child(sbar)
	chart = SweepChart.new()
	chart.name = "Barrido"
	pane.visual.add_child(chart)
	Style.pick_chip(view_chips, view_mode)


func _build_result_card() -> void:
	result_card = Card.new("Resultado del fresado", "valores orientativos")
	var g := Style.grid()
	for k in [["rpm", "Giro"], ["vc", "vc"], ["vf", "Avance de la mesa"], ["h", "Espesor de viruta"], ["kc", "kc"],
			["fc", "Fuerza de corte media"], ["pc", "Potencia"], ["torque", "Par en el husillo"], ["q", "Caudal de viruta"],
			["tooth", "Paso de dientes"], ["life", "Vida (Taylor)"]]:
		out[k[0]] = Style.grid_row(g, k[1], "TallerDato")
	result_card.body.add_child(g)
	power_bar = Style.bar("gold")
	result_card.body.add_child(power_bar)
	band_label = Style.label("", "TallerTenue", true)
	result_card.body.add_child(band_label)
	parts_label = Style.label("", "TallerNota", true)
	result_card.body.add_child(parts_label)
	quality_label = Style.label("", "TallerAviso", true)
	result_card.body.add_child(quality_label)
	pane.side.add_child(result_card)


func _build_tool_card() -> void:
	var card := Card.new("Herramienta")
	var tc := Style.chips(TOOL_TYPES, func(id: String) -> void: md.set_mill("tool_type", id))
	type_chips = tc.buttons
	card.body.add_child(tc.box)
	card.body.add_child(Style.label("Material de corte (y recubrimiento)", "TallerTenue", true))
	tool_opt = _dynamic_options(func(id: String) -> void: md.set_mill("tool_id", id))
	card.body.add_child(tool_opt)
	tool_info = Style.label("", "TallerNota", true)
	card.body.add_child(tool_info)
	card.body.add_child(Style.label("Ángulo de posición κr", "TallerTenue", true))
	kappa_box = HFlowContainer.new()
	card.body.add_child(kappa_box)
	for f in FIELDS.slice(0, 2):
		_add_slider(card.body, f)
	pane.side.add_child(card)


func _build_work_card() -> void:
	var card := Card.new("Pieza")
	var works: Array = []
	for id in WorkMaterials.ids():
		works.append([id, str(WorkMaterials.get_material(id)["name"])])
	var row := HBoxContainer.new()
	iso_swatch = Style.swatch(Color.WHITE, 16.0)
	row.add_child(iso_swatch)
	work_opt = Style.options(works, func(id: String) -> void: md.set_mill("work_id", id))
	row.add_child(work_opt)
	card.body.add_child(row)
	work_info = Style.label("", "TallerNota", true)
	card.body.add_child(work_info)
	pane.side.add_child(card)


func _build_cut_card() -> void:
	var card := Card.new("Condiciones de corte")
	var sc := Style.chips(SPEED_MODES, func(id: String) -> void: md.set_mill("speed_mode", id))
	speed_chips = sc.buttons
	card.body.add_child(sc.box)
	for f in FIELDS.slice(2):
		_add_slider(card.body, f)
	card.body.add_child(Style.label("Posición de la fresa y sentido de giro (M03)", "TallerTenue", true))
	var pc := Style.chips(POSITION_ITEMS, func(id: String) -> void: md.set_mill("position", id))
	position_chips = pc.buttons
	card.body.add_child(pc.box)
	position_note = Style.label("", "TallerNota", true)
	card.body.add_child(position_note)
	card.body.add_child(Style.label("Desgaste del filo (Kver)", "TallerTenue", true))
	var wc := Style.chips(WEAR, func(id: String) -> void: md.set_mill("wear", id))
	wear_chips = wc.buttons
	card.body.add_child(wc.box)
	coolant_check = CheckButton.new()
	coolant_check.text = "Taladrina"
	coolant_check.focus_mode = Control.FOCUS_NONE
	coolant_check.toggled.connect(func(on: bool) -> void: md.set_mill("coolant", on))
	card.body.add_child(coolant_check)
	pane.side.add_child(card)


func _build_machine_card() -> void:
	var card := Card.new("Máquina", "ficha ajustable")
	machine_info = Style.label("", "TallerNota", true)
	card.body.add_child(machine_info)
	for f in MACHINE_FIELDS:
		var key: String = f[0]
		var s := Style.slider(f[1], f[2], f[3], f[4], func(v: float) -> void: md.set_machine_param(KIND, key, v))
		card.body.add_child(s.row)
		machine_sliders[key] = s
	var row := HFlowContainer.new()
	btn_ficha = Style.button("Volver a la ficha")
	btn_ficha.pressed.connect(func() -> void: md.reset_machine(KIND))
	row.add_child(btn_ficha)
	btn_run = Style.button("Parar", "TallerPeligro")
	btn_run.pressed.connect(func() -> void: md.toggle_running(KIND))
	row.add_child(btn_run)
	var again := Style.button("Repetir la pasada")
	again.pressed.connect(func() -> void: md.reset_anim(KIND))
	row.add_child(again)
	card.body.add_child(row)
	card.body.add_child(Style.label("Velocidad de la animación (tiempo real ×)", "TallerTenue", true))
	var items: Array = []
	for s: float in MillDrillState.ANIM_SPEEDS:
		items.append([s, "×" + Fmt.num(s, 0)])
	var ac := Style.chips(items, func(s: float) -> void: md.set_anim_speed(KIND, s))
	anim_chips = ac.buttons
	card.body.add_child(ac.box)
	pane.side.add_child(card)


func _build_warn_card() -> void:
	var card := Card.new("Avisos y fuentes")
	warn_list = VBoxContainer.new()
	card.body.add_child(warn_list)
	sources_label = Style.label("", "TallerNota", true)
	card.body.add_child(sources_label)
	pane.side.add_child(card)


func _add_slider(parent: Control, f: Array) -> void:
	var key: String = f[0]
	var is_int := key == "z"
	var s := Style.slider(f[1], f[2], f[3], f[4], func(v: float) -> void: md.set_mill(key, int(v) if is_int else v))
	parent.add_child(s.row)
	sliders[key] = s


## Pone el recorrido y el valor de un deslizador sin emitir value_changed. Dentro del árbol, Godot recorta el valor al
## nuevo recorrido y lo emite: al pasar de una fresa de Ø63 a una de Ø16, el ancho de corte (40 mm) se recortaría a 16 y
## cambiaría el estado a mitad de refresh().
static func set_slider(s: HSlider, lo: float, hi: float, value: float) -> void:
	s.set_block_signals(true)
	s.min_value = lo
	s.max_value = maxf(hi, lo)
	s.value = value
	s.set_block_signals(false)


## Desplegable cuyos elementos cambian (los materiales de corte de cada tipo de fresa): lee los ids de su meta «ids» al
## elegir, no los del momento de crearlo (como Style.options).
static func _dynamic_options(on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.clip_text = true
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.set_meta("ids", [])
	o.item_selected.connect(func(i: int) -> void:
		var ids: Array = o.get_meta("ids", [])
		if i >= 0 and i < ids.size():
			on_pick.call(ids[i]))
	return o


static func _axis_symbol(key: String) -> String:
	return { "ae_mm": "(ae)", "fz_mm": "(fz)", "ap_mm": "(ap)", "vc": "(vc)" }.get(key, "")


# ─────────────────────────── vistas ───────────────────────────

func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)
	view.custom_minimum_size = Vector2(240, 560 if on else 430)
	chart.custom_minimum_size = Vector2(240, 200 if on else 190)
	if view3d != null:
		view3d.custom_minimum_size = Vector2(240, 300 if on else 320)


func on_shown() -> void:
	if view_mode == "maquina" and view3d != null:
		view3d.ensure_scene()


func set_view(id: String) -> void:
	view_mode = id if (id == "esquema" or view3d != null) else "esquema"
	Style.pick_chip(view_chips, view_mode)
	view.visible = view_mode == "esquema"
	cam_box.visible = view_mode == "maquina"
	if view3d != null:
		view3d.visible = view_mode == "maquina"
		if view3d.visible and is_inside_tree():
			view3d.ensure_scene()


## Vista de la cámara de la escena 3D («detalle», «frontal», «superior» o «general»).
func set_cam_view(id: String) -> void:
	cam_view = id
	Style.pick_chip(cam_chips, id)
	if mill3d != null:
		mill3d.call("set_view", id, false)


func set_sweep_output(key: String) -> void:
	sweep_output = key
	Style.pick_chip(sweep_y_chips, key)
	_fill_chart()


func _on_scene_ready(scene: Node) -> void:
	mill3d = scene as Node3D
	mill3d.call("set_state", md.mill_3d_view())
	mill3d.call("set_view", cam_view, true)


func _on_sweep_ready(kind: String) -> void:
	if kind == KIND:
		_fill_chart()


# ─────────────────────────── cada fotograma ───────────────────────────

func tick(delta: float) -> void:
	if md == null:
		return
	var slow := MillDrillState.slow_motion(float(md.mill_result.get("rpm", 0.0)) if md.mill_result.get("rpm") != null else 0.0, MillView.SHOWN_REV_S)
	if view.visible:
		view.set_anim(md.mill_anim, slow, bool(md.running[KIND]))
		view.tick(delta)
	_update_3d()
	var pending := md.sweep_pending(KIND)
	if pending != chart.pending:
		chart.pending = pending
		chart.queue_redraw()


func _update_3d() -> void:
	if mill3d == null or not view3d.visible:
		return
	mill3d.call("set_state", md.mill_3d_view())


# ─────────────────────────── cambios del estado ───────────────────────────

func refresh() -> void:
	if md == null:
		return
	var p: Dictionary = md.mill
	var r: Dictionary = md.mill_result
	var tool_def: Dictionary = MillDrillState.MILL_TOOLS[str(p["tool_type"])]
	Style.pick_chip(type_chips, p["tool_type"])
	_fill_tool_options(tool_def)
	Style.pick_option(tool_opt, p["tool_id"])
	_fill_kappas(tool_def)
	Style.pick_chip(kappa_chips, float(p["kappa_deg"]))
	Style.pick_option(work_opt, p["work_id"])
	Style.pick_chip(speed_chips, p["speed_mode"])
	Style.pick_chip(position_chips, p["position"])
	Style.pick_chip(wear_chips, str(p["wear"]))
	Style.pick_chip(anim_chips, float(md.anim_speed[KIND]))
	Style.pick_chip(sweep_x_chips, md.sweep_x[KIND])
	Style.pick_chip(sweep_y_chips, sweep_output)
	coolant_check.set_pressed_no_signal(bool(p["coolant"]))
	# Deslizadores: el ancho de corte llega al diámetro; el giro, hasta más allá del tope de la máquina para ver el aviso
	for f in FIELDS:
		var s: Dictionary = sliders[f[0]]
		var hi := float(f[3])
		if f[0] == "ae_mm":
			hi = float(p["dc_mm"])
		elif f[0] == "rpm":
			hi = ceilf(float(md.mill_machine["rpm_max"]) * 1.5 / 100.0) * 100.0
		set_slider(s.slider, float(f[2]), hi, float(p[f[0]]))
		(s.value as Label).text = Fmt.unit(p[f[0]], int(f[5]), str(f[6]))
	(sliders["vc"].row as Control).visible = p["speed_mode"] == "vc"
	(sliders["rpm"].row as Control).visible = p["speed_mode"] == "rpm"
	for f in MACHINE_FIELDS:
		var s: Dictionary = machine_sliders[f[0]]
		set_slider(s.slider, float(f[2]), float(f[3]), float(md.mill_machine[f[0]]))
		(s.value as Label).text = Fmt.unit(md.mill_machine[f[0]], int(f[5]), str(f[6]))
	_fill_infos(p)
	_fill_result(r)
	_fill_warnings(r)
	btn_run.text = "Parar" if bool(md.running[KIND]) else "Marcha"
	btn_run.theme_type_variation = "TallerPeligro" if bool(md.running[KIND]) else "TallerAccion"
	btn_ficha.disabled = md.machine_is_ficha(KIND)
	view.set_data(_view_data())
	_fill_chart()
	_update_3d()


## Lo que dibuja el esquema (todo del estado; los colores, del catálogo y de la paleta).
func _view_data() -> Dictionary:
	var p: Dictionary = md.mill
	var eng := md.mill_engagement()
	var rpm: Variant = md.mill_result.get("rpm")
	return {
		"eng": eng, "result": md.mill_result, "params": p, "anim": md.mill_anim, "block": md.mill_block(),
		"slow": MillDrillState.slow_motion(float(rpm) if rpm != null else 0.0, MillView.SHOWN_REV_S),
		"running": bool(md.running[KIND]), "anim_speed": float(md.anim_speed[KIND]),
		"tool_color": tool_color(str(p["tool_id"])),
		"chip_color": (eng.get("chip_color", Color.WHITE) as Color).linear_to_srgb() if not eng.is_empty() else Color.WHITE,
	}


## Color del filo en los dibujos: el del recubrimiento (catálogo de Balzers) o, sin capa, el del acero o el metal duro.
static func tool_color(tool_id: String) -> Color:
	var t := ToolMaterials.get_tool(tool_id)
	var c = t.get("coating")
	if c != null and ToolMaterials.COATINGS.has(c):
		return Color(str(ToolMaterials.COATINGS[c]["color"]))
	return Style.c("dim") if str(t.get("family", "")) == "hss" else Style.c("text").darkened(0.35)


func _fill_tool_options(tool_def: Dictionary) -> void:
	var key := ",".join(PackedStringArray(tool_def["tool_ids"]))
	if key == _tool_key:
		return
	_tool_key = key
	tool_opt.clear()
	var ids: Array = []
	for id in tool_def["tool_ids"]:
		tool_opt.add_item(str(ToolMaterials.get_tool(id)["name"]))
		ids.append(id)
	tool_opt.set_meta("ids", ids)


func _fill_kappas(tool_def: Dictionary) -> void:
	var have: Array = kappa_chips.keys()
	var want: Array = tool_def["kappas"]
	if have == want:
		return
	Style.clear(kappa_box)
	var items: Array = []
	for k: float in want:
		items.append([k, Fmt.num(k, 0) + "°"])
	kappa_chips = Style.chips(items, func(k: float) -> void: md.set_mill("kappa_deg", k), kappa_box).buttons


func _fill_infos(p: Dictionary) -> void:
	var t := ToolMaterials.get_tool(str(p["tool_id"]))
	var coat := ToolMaterials.get_coating(str(t.get("coating", ""))) if t.get("coating") != null else {}
	var groups := " ".join(PackedStringArray(t.get("iso_groups", [])))
	var capa := "sin recubrimiento" if coat.is_empty() else "capa %s de %s HV, hasta %s °C (%s)" % [str(coat["name"]), Fmt.num(coat["hv"], 0), Fmt.num(coat["max_temp_c"], 0), str(coat["color_name"])]
	tool_info.text = "%s · %s HV · %s · grupos ISO %s · calidad %s" % [str(t.get("designation", "")), Fmt.num(t.get("hv"), 0), capa, groups, Fmt.quality(t.get("quality"))]
	var w := WorkMaterials.get_material(str(p["work_id"]))
	var iso: Dictionary = ToolMaterials.ISO_GROUPS.get(str(w.get("iso", "")), {})
	iso_swatch.color = Color(str(iso.get("color", "#888888")))
	iso_swatch.tooltip_text = "Grupo ISO %s · %s" % [str(w.get("iso", "")), str(iso.get("name", ""))]
	var kc = w.get("kc")
	var kc_txt := "sin kc: %s" % str(w.get("kc_reason", "")) if kc == null else "kc1.1 %s N/mm², mc %s (%s; %s)" % [Fmt.num(kc["kc11"], 0), Fmt.num(kc["mc"], 2), str(kc["source"]), Fmt.quality(kc["quality"])]
	work_info.text = "ISO %s (%s) · %s · %s" % [str(w.get("iso", "")), str(iso.get("name", "")), str(w.get("designation", "")), kc_txt]
	var pos: Dictionary = MillDrillState.POSITIONS[str(p["position"])]
	position_note.text = "%s Fuente: %s (%s)." % [str(pos["note"]), str(pos["source"]), Fmt.quality(pos["quality"])]
	var ficha := MillDrillState.machine_ficha(KIND)
	machine_info.text = "%s · %s (%s)" % [str(ficha["name"]), str(ficha["source"]), Fmt.quality(ficha["quality"])] + ("" if md.machine_is_ficha(KIND) else " · cambiada a mano")


func _fill_result(r: Dictionary) -> void:
	out["rpm"].text = Fmt.unit(r.get("rpm"), 0, "rpm") + (" · limitado por la máquina" if bool(r.get("rpm_limited", false)) else "")
	out["vc"].text = Fmt.unit(r.get("vc"), 0, "m/min")
	out["vf"].text = "vf %s · fz %s" % [Fmt.unit(r.get("vf_mm_min"), 0, "mm/min"), Fmt.unit(r.get("fz_mm"), 3, "mm")]
	out["h"].text = "hm %s · hex %s · %s dientes en corte" % [Fmt.unit(r.get("hm_mm"), 3, "mm"), Fmt.unit(r.get("hex_mm"), 3, "mm"), Fmt.num(r.get("zc"), 2)]
	out["kc"].text = Fmt.unit(r.get("kc"), 0, "N/mm²")
	out["fc"].text = Fmt.unit(r.get("fc_mean_n"), 0, "N")
	var over := bool(r.get("overload", false))
	out["pc"].text = "%s en el filo · %s en el motor de %s%s" % [Fmt.unit(r.get("pc_kw"), 2, "kW"), Fmt.unit(r.get("pmotor_kw"), 2, "kW"),
		Fmt.unit(md.mill_machine["pmax_kw"], 1, "kW"), " · SOBRECARGA" if over else ""]
	out["pc"].theme_type_variation = "TallerMal" if over else "TallerDato"
	power_bar.value = clampf(float(r["pmotor_kw"]) / float(md.mill_machine["pmax_kw"]), 0.0, 1.0) if r.get("pmotor_kw") != null else 0.0
	out["torque"].text = Fmt.unit(r.get("torque_nm"), 1, "N·m")
	out["q"].text = Fmt.unit(r.get("q_cm3_min"), 1, "cm³/min")
	out["tooth"].text = "%s (z·n/60: lo que se oye)" % Fmt.unit(r.get("tooth_hz"), 0, "Hz")
	out["life"].text = "%s (%s)" % [Fmt.unit(r.get("life_min"), 1, "min"), Fmt.quality(r.get("life_quality"))] if r.get("life_min") != null else "—"
	var band: Variant = r.get("band")
	if band is Array and (band as Array).size() == 2:
		band_label.text = "Banda de incertidumbre de kc (todas las familias de datos del material): %s N/mm²" % Fmt.span(band[0], band[1], 0)
	else:
		band_label.text = "Sin banda: sin datos de fuerza de corte para este material."
	var parts: Variant = r.get("kc_parts")
	if parts is Dictionary:
		var pd: Dictionary = parts
		parts_label.text = "kc = kc1.1·hm^−mc (%s) × Kγ %s × Kvc %s × Kver %s × Ksp %s (fresado)" % [Fmt.num(pd.get("k"), 0),
			Fmt.num(pd.get("Kgamma"), 3), Fmt.num(pd.get("Kvc"), 2), Fmt.num(pd.get("Kver"), 2), Fmt.num(pd.get("Ksp"), 2)]
	else:
		parts_label.text = ""
	quality_label.text = "Calidad de los datos de fuerza: " + (Fmt.quality(r.get("quality")) if r.get("quality") != null else "—")
	result_card.set_hint("valores orientativos")


func _fill_warnings(r: Dictionary) -> void:
	Style.clear(warn_list)
	var notes: Array = []
	notes.append_array(r.get("warnings", []))
	notes.append_array(md.machine_notes(KIND))
	if notes.is_empty():
		warn_list.add_child(Style.label("Sin avisos.", "TallerBien"))
	for w in notes:
		var bad := str(w).begins_with("Sobrecarga") or str(w).begins_with("Tope") or str(w).contains("no es un material de corte indicado")
		warn_list.add_child(Style.label(str(w), "TallerMal" if bad else "TallerAviso", true))
	sources_label.text = "Fuentes: " + "; ".join(PackedStringArray(r.get("sources", [])))


func _fill_chart() -> void:
	var sw := md.sweep(KIND)
	if sw.is_empty():
		chart.set_data({ "pending": true, "title": "Barrido" })
		return
	var out_def: Array = []
	for o in MillDrillState.SWEEP_OUTPUTS[KIND]:
		if o[0] == sweep_output:
			out_def = o
	var ys: Array = []
	var over: Array = []
	for pt in sw["points"]:
		ys.append(pt.get(sweep_output))
		over.append(bool(pt.get("overload", false)))
	var key := str(sw["key"])
	var cur_y: Variant = md.mill_result.get(sweep_output)
	chart.set_data({
		"xs": sw["xs"], "ys": ys, "over": over,
		"current": Vector2(md.sweep_current_x(KIND, key), float(cur_y) if cur_y != null else NAN),
		"limit": float(md.mill_machine["pmax_kw"]) if sweep_output == "pmotor_kw" else NAN,
		"limit_label": "motor de la máquina: %s" % Fmt.unit(md.mill_machine["pmax_kw"], 1, "kW"),
		"title": "%s frente a %s" % [str(out_def[1]), str(sw["label"]).to_lower()],
		"x_label": "%s (%s)" % [str(sw["label"]), str(sw["unit"])], "y_unit": str(out_def[2]),
		"x_dec": int(sw["decimals"]), "y_dec": int(out_def[3]), "pending": bool(sw.get("pending", false)),
	})
