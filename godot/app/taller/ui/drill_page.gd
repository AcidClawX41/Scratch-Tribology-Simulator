## Taller industrial · página del taladro (unidad 1e).
##
## A la izquierda, el esquema animado en sección (la broca bajando a su avance real, sus gargantas girando en cámara lenta,
## la viruta que sube, el empuje, el par, el ángulo de punta y un filo de cerca con b, h y f/2) o la máquina en 3D, y la
## gráfica de un barrido (empuje, par, potencia o vida frente al avance, al diámetro o a vc, calculado en hilos por
## MillDrillState). A la derecha, las tarjetas: resultado de cutting.gd (giro, vf, h, kc con su banda, fuerza por filo,
## empuje, par, potencia en el filo y en el motor, caudal, tiempo del agujero, vida de Taylor como estimación, calidad de
## los datos), broca (material, Ø, ángulo de punta con el recomendado para el material y su hélice), pieza, condiciones
## de corte (vc o rpm, avance con los avances automáticos de la máquina, profundidad, desgaste, taladrina), máquina (la
## ficha del ERLO TSAR-32, ajustable) y avisos con sus fuentes.
## Todo lo que enseña sale de MillDrillState (core/taller/mill_drill_state.gd): aquí no se calcula nada del corte.
extends Control

const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")
const Chips = preload("res://core/taller/chips.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const MillPage = preload("res://app/taller/ui/mill_page.gd")
const DrillView = preload("res://app/taller/mill3d/drill_view.gd")
const SweepChart = preload("res://app/taller/mill3d/sweep_chart.gd")

const KIND := "drill"
const SCENE_3D := "res://app/taller/mill3d/drill_3d.tscn"
const VIEWS := [["esquema", "Sección animada"], ["maquina", "Máquina 3D"]]
const CAM_VIEWS := [["detalle", "Detalle en corte"], ["frontal", "Frontal"], ["superior", "Superior"], ["general", "General"]]
const SPEED_MODES := [["vc", "Por vc"], ["rpm", "Por rpm"]]
const WEAR := [["nuevo", "nuevo"], ["ligero", "ligero"], ["medio", "medio"], ["fuerte", "fuerte"]]
## Deslizadores: [clave, rótulo, mín, máx, paso, decimales, unidad]. Recorridos de interfaz (no datos).
const FIELDS := [
	["d_mm", "Diámetro de la broca D", 1.0, 40.0, 0.5, 1, "mm"],
	["point_angle_deg", "Ángulo de punta σ", 80.0, 150.0, 1.0, 0, "°"],
	["vc", "Velocidad de corte vc", 5.0, 150.0, 1.0, 0, "m/min"],
	["rpm", "Giro del husillo n", 50.0, 4000.0, 10.0, 0, "rpm"],
	["f_mm_rev", "Avance f", 0.01, 0.6, 0.01, 2, "mm/vuelta"],
	["depth_mm", "Profundidad del agujero", 2.0, 100.0, 1.0, 0, "mm"],
]
const MACHINE_FIELDS := [
	["pmax_kw", "Potencia del motor", 0.2, 5.0, 0.05, 2, "kW"],
	["rpm_max", "Tope de giro", 300.0, 6000.0, 10.0, 0, "rpm"],
	["eta", "Rendimiento η", 0.6, 0.95, 0.01, 2, ""],
]

var md: MillDrillState
var pane: TwoPane
var view: DrillView
var view3d: View3D = null
var drill3d: Node3D = null
var chart: SweepChart
var compact := false
var view_mode := "esquema"
var cam_view := "detalle"
var sweep_output := "thrust_n"

var view_chips := {}
var cam_chips := {}
var cam_box: HFlowContainer
var speed_chips := {}
var wear_chips := {}
var feed_chips := {}
var anim_chips := {}
var sweep_x_chips := {}
var sweep_y_chips := {}
var tool_opt: OptionButton
var work_opt: OptionButton
var coolant_check: CheckButton
var sliders := {}
var machine_sliders := {}
var tool_info: Label
var point_info: Label
var btn_point: Button
var work_info: Label
var iso_swatch: ColorRect
var machine_info: Label
var btn_run: Button
var btn_ficha: Button
var out := {}
var power_bar: ProgressBar
var band_label: Label
var parts_label: Label
var quality_label: Label
var warn_list: VBoxContainer
var sources_label: Label
var result_card: Card
var _built := false


func build(state: MillDrillState) -> void:
	if _built:
		return
	_built = true
	md = state
	name = "Taladro"
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
	view = DrillView.new()
	view.name = "SeccionTaladro"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.visual.add_child(view)
	if ResourceLoader.exists(SCENE_3D):
		view3d = View3D.new(SCENE_3D)
		view3d.name = "Taladro3D"
		view3d.custom_minimum_size = Vector2(300, 320)
		view3d.visible = false
		view3d.scene_ready.connect(_on_scene_ready)
		pane.visual.add_child(view3d)
	var sbar := HFlowContainer.new()
	var xs: Array = []
	for key in MillDrillState.SWEEP_AXES[KIND]:
		xs.append([key, { "f_mm_rev": "Avance (f)", "d_mm": "Diámetro (D)", "vc": "Velocidad (vc)" }.get(key, key)])
	sweep_x_chips = Style.chips(xs, func(k: String) -> void: md.set_sweep_x(KIND, k), sbar).buttons
	sbar.add_child(VSeparator.new())
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
	result_card = Card.new("Resultado del taladrado", "valores orientativos")
	var g := Style.grid()
	for k in [["rpm", "Giro"], ["vc", "vc en la esquina"], ["vf", "Avance"], ["h", "Espesor de viruta"], ["kc", "kc"],
			["fc", "Fuerza de corte"], ["thrust", "Empuje"], ["torque", "Par"], ["pc", "Potencia"], ["q", "Caudal de viruta"],
			["time", "Tiempo del agujero"], ["life", "Vida (Taylor)"]]:
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
	var card := Card.new("Broca helicoidal")
	card.body.add_child(Style.label("Material de la broca", "TallerTenue", true))
	var tools: Array = []
	for id in MillDrillState.DRILL_TOOL_IDS:
		tools.append([id, str(ToolMaterials.get_tool(id)["name"])])
	tool_opt = Style.options(tools, func(id: String) -> void: md.set_drill("tool_id", id))
	card.body.add_child(tool_opt)
	tool_info = Style.label("", "TallerNota", true)
	card.body.add_child(tool_info)
	for f in FIELDS.slice(0, 2):
		_add_slider(card.body, f)
	point_info = Style.label("", "TallerNota", true)
	card.body.add_child(point_info)
	btn_point = Style.button("Usar el ángulo recomendado")
	btn_point.pressed.connect(_use_recommended_point)
	card.body.add_child(btn_point)
	pane.side.add_child(card)


func _build_work_card() -> void:
	var card := Card.new("Pieza")
	var works: Array = []
	for id in WorkMaterials.ids():
		works.append([id, str(WorkMaterials.get_material(id)["name"])])
	var row := HBoxContainer.new()
	iso_swatch = Style.swatch(Color.WHITE, 16.0)
	row.add_child(iso_swatch)
	work_opt = Style.options(works, func(id: String) -> void: md.set_drill("work_id", id))
	row.add_child(work_opt)
	card.body.add_child(row)
	work_info = Style.label("", "TallerNota", true)
	card.body.add_child(work_info)
	pane.side.add_child(card)


func _build_cut_card() -> void:
	var card := Card.new("Condiciones de corte")
	var sc := Style.chips(SPEED_MODES, func(id: String) -> void: md.set_drill("speed_mode", id))
	speed_chips = sc.buttons
	card.body.add_child(sc.box)
	for f in FIELDS.slice(2):
		_add_slider(card.body, f)
		if f[0] == "f_mm_rev":
			var items: Array = []
			for fv: float in MillDrillState.MACHINES[KIND]["feeds_mm_rev"]:
				items.append([fv, Fmt.num(fv, 2)])
			var fc := Style.chips(items, func(v: float) -> void: md.set_drill("f_mm_rev", v))
			feed_chips = fc.buttons
			card.body.add_child(Style.label("Avances automáticos de la máquina (mm/vuelta)", "TallerNota", true))
			card.body.add_child(fc.box)
	card.body.add_child(Style.label("Desgaste del filo (Kver)", "TallerTenue", true))
	var wc := Style.chips(WEAR, func(id: String) -> void: md.set_drill("wear", id))
	wear_chips = wc.buttons
	card.body.add_child(wc.box)
	coolant_check = CheckButton.new()
	coolant_check.text = "Taladrina"
	coolant_check.focus_mode = Control.FOCUS_NONE
	coolant_check.toggled.connect(func(on: bool) -> void: md.set_drill("coolant", on))
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
	var again := Style.button("Otro agujero")
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
	var s := Style.slider(f[1], f[2], f[3], f[4], func(v: float) -> void: md.set_drill(key, v))
	parent.add_child(s.row)
	sliders[key] = s


func _use_recommended_point() -> void:
	var rec: Dictionary = md.drill_geometry()["point_rec"]
	if not rec.is_empty():
		md.set_drill("point_angle_deg", float(rec["value"]))


# ─────────────────────────── vistas ───────────────────────────

func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)
	view.custom_minimum_size = Vector2(240, 700 if on else 430)
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
	if drill3d != null:
		drill3d.call("set_view", id, false)


func set_sweep_output(key: String) -> void:
	sweep_output = key
	Style.pick_chip(sweep_y_chips, key)
	_fill_chart()


func _on_scene_ready(scene: Node) -> void:
	drill3d = scene as Node3D
	drill3d.call("set_state", md.drill_3d_view())
	drill3d.call("set_view", cam_view, true)


func _on_sweep_ready(kind: String) -> void:
	if kind == KIND:
		_fill_chart()


# ─────────────────────────── cada fotograma ───────────────────────────

func tick(delta: float) -> void:
	if md == null:
		return
	if view.visible:
		view.set_anim(md.drill_anim, _slow(), bool(md.running[KIND]))
		view.tick(delta)
	_update_3d()
	var pending := md.sweep_pending(KIND)
	if pending != chart.pending:
		chart.pending = pending
		chart.queue_redraw()


func _slow() -> Dictionary:
	var rpm: Variant = md.drill_result.get("rpm")
	return MillDrillState.slow_motion(float(rpm) if rpm != null else 0.0, DrillView.SHOWN_REV_S)


func _update_3d() -> void:
	if drill3d == null or not view3d.visible:
		return
	drill3d.call("set_state", md.drill_3d_view())


# ─────────────────────────── cambios del estado ───────────────────────────

func refresh() -> void:
	if md == null:
		return
	var p: Dictionary = md.drill
	var r: Dictionary = md.drill_result
	var g := md.drill_geometry()
	Style.pick_option(tool_opt, p["tool_id"])
	Style.pick_option(work_opt, p["work_id"])
	Style.pick_chip(speed_chips, p["speed_mode"])
	Style.pick_chip(wear_chips, str(p["wear"]))
	Style.pick_chip(feed_chips, float(p["f_mm_rev"]))
	Style.pick_chip(anim_chips, float(md.anim_speed[KIND]))
	Style.pick_chip(sweep_x_chips, md.sweep_x[KIND])
	Style.pick_chip(sweep_y_chips, sweep_output)
	coolant_check.set_pressed_no_signal(bool(p["coolant"]))
	for f in FIELDS:
		var s: Dictionary = sliders[f[0]]
		var hi := float(f[3])
		if f[0] == "rpm":  # hasta más allá del tope de la máquina, para ver el aviso
			hi = ceilf(float(md.drill_machine["rpm_max"]) * 1.5 / 100.0) * 100.0
		MillPage.set_slider(s.slider, float(f[2]), hi, float(p[f[0]]))
		(s.value as Label).text = Fmt.unit(p[f[0]], int(f[5]), str(f[6]))
	(sliders["vc"].row as Control).visible = p["speed_mode"] == "vc"
	(sliders["rpm"].row as Control).visible = p["speed_mode"] == "rpm"
	for f in MACHINE_FIELDS:
		var s: Dictionary = machine_sliders[f[0]]
		MillPage.set_slider(s.slider, float(f[2]), float(f[3]), float(md.drill_machine[f[0]]))
		(s.value as Label).text = Fmt.unit(md.drill_machine[f[0]], int(f[5]), str(f[6]))
	_fill_infos(p, g)
	_fill_result(r, g)
	_fill_warnings(r)
	btn_run.text = "Parar" if bool(md.running[KIND]) else "Marcha"
	btn_run.theme_type_variation = "TallerPeligro" if bool(md.running[KIND]) else "TallerAccion"
	btn_ficha.disabled = md.machine_is_ficha(KIND)
	view.set_data(_view_data(g))
	_fill_chart()
	_update_3d()


func _view_data(g: Dictionary) -> Dictionary:
	var p: Dictionary = md.drill
	var w := WorkMaterials.get_material(str(p["work_id"]))
	return {
		"geo": g, "result": md.drill_result, "params": p, "anim": md.drill_anim, "slow": _slow(),
		"running": bool(md.running[KIND]), "anim_speed": float(md.anim_speed[KIND]), "coolant": bool(p["coolant"]),
		"tool_color": MillPage.tool_color(str(p["tool_id"])), "chip_color": (g["chip_color"] as Color).linear_to_srgb(),
		"chip_form": Chips.form_for(str(w.get("kind", "acero"))), "work_name": str(w.get("name", "")),
	}


func _fill_infos(p: Dictionary, g: Dictionary) -> void:
	var t := ToolMaterials.get_tool(str(p["tool_id"]))
	var coat := ToolMaterials.get_coating(str(t.get("coating", ""))) if t.get("coating") != null else {}
	var capa := "sin recubrimiento" if coat.is_empty() else "capa %s de %s HV, hasta %s °C (%s)" % [str(coat["name"]), Fmt.num(coat["hv"], 0), Fmt.num(coat["max_temp_c"], 0), str(coat["color_name"])]
	tool_info.text = "%s · %s HV · %s · grupos ISO %s · calidad %s" % [str(t.get("designation", "")), Fmt.num(t.get("hv"), 0), capa,
		" ".join(PackedStringArray(t.get("iso_groups", []))), Fmt.quality(t.get("quality"))]
	var rec: Dictionary = g.get("point_rec", {})
	var hx: Dictionary = g.get("helix", {})
	var w := WorkMaterials.get_material(str(p["work_id"]))
	var hx_txt := "hélice %s de %s–%s° (%s)" % [str(hx.get("name", "")), Fmt.num(hx.get("min"), 0), Fmt.num(hx.get("max"), 0), str(hx.get("source", ""))]
	if rec.is_empty():
		point_info.text = "Las tablas del afilado no dan un ángulo de punta para %s. Se dibuja con %s." % [str(w.get("name", "")), hx_txt]
		btn_point.visible = false
	else:
		point_info.text = "Para %s: punta de %s° (%s; %s) y %s." % [str(w.get("name", "")), Fmt.num(rec["value"], 0), str(rec["source"]), Fmt.quality(rec["quality"]), hx_txt]
		btn_point.visible = float(rec["value"]) != float(p["point_angle_deg"])
		btn_point.text = "Usar %s°, el recomendado" % Fmt.num(rec["value"], 0)
	var iso: Dictionary = ToolMaterials.ISO_GROUPS.get(str(w.get("iso", "")), {})
	iso_swatch.color = Color(str(iso.get("color", "#888888")))
	iso_swatch.tooltip_text = "Grupo ISO %s · %s" % [str(w.get("iso", "")), str(iso.get("name", ""))]
	var kc = w.get("kc")
	var kc_txt := "sin kc: %s" % str(w.get("kc_reason", "")) if kc == null else "kc1.1 %s N/mm², mc %s (%s; %s)" % [Fmt.num(kc["kc11"], 0), Fmt.num(kc["mc"], 2), str(kc["source"]), Fmt.quality(kc["quality"])]
	work_info.text = "ISO %s (%s) · %s · %s" % [str(w.get("iso", "")), str(iso.get("name", "")), str(w.get("designation", "")), kc_txt]
	var ficha := MillDrillState.machine_ficha(KIND)
	machine_info.text = "%s · %s (%s)" % [str(ficha["name"]), str(ficha["source"]), Fmt.quality(ficha["quality"])] + ("" if md.machine_is_ficha(KIND) else " · cambiada a mano")


func _fill_result(r: Dictionary, g: Dictionary) -> void:
	out["rpm"].text = Fmt.unit(r.get("rpm"), 0, "rpm") + (" · limitado por la máquina" if bool(r.get("rpm_limited", false)) else "")
	out["vc"].text = Fmt.unit(r.get("vc"), 0, "m/min")
	out["vf"].text = "vf %s · f %s" % [Fmt.unit(r.get("vf_mm_min"), 0, "mm/min"), Fmt.unit(md.drill["f_mm_rev"], 2, "mm/vuelta")]
	out["h"].text = "h %s · b %s · A %s por filo" % [Fmt.unit(r.get("h_mm"), 3, "mm"), Fmt.unit(g.get("b_mm"), 2, "mm"), Fmt.unit(g.get("area_mm2"), 3, "mm²")]
	out["kc"].text = Fmt.unit(r.get("kc"), 0, "N/mm²")
	out["fc"].text = "%s por filo" % Fmt.unit(r.get("fc_edge_n"), 0, "N")
	out["thrust"].text = Fmt.unit(r.get("thrust_n"), 0, "N")
	out["torque"].text = Fmt.unit(r.get("torque_nm"), 1, "N·m")
	var over := bool(r.get("overload", false))
	out["pc"].text = "%s en el filo · %s en el motor de %s%s" % [Fmt.unit(r.get("pc_kw"), 2, "kW"), Fmt.unit(r.get("pmotor_kw"), 2, "kW"),
		Fmt.unit(md.drill_machine["pmax_kw"], 2, "kW"), " · SOBRECARGA" if over else ""]
	out["pc"].theme_type_variation = "TallerMal" if over else "TallerDato"
	power_bar.value = clampf(float(r["pmotor_kw"]) / float(md.drill_machine["pmax_kw"]), 0.0, 1.0) if r.get("pmotor_kw") != null else 0.0
	out["q"].text = Fmt.unit(r.get("q_cm3_min"), 1, "cm³/min")
	out["time"].text = "%s para %s (con la punta)" % [Fmt.seconds(g.get("time_s")), Fmt.unit(md.drill["depth_mm"], 0, "mm")]
	out["life"].text = "%s (%s)" % [Fmt.unit(r.get("life_min"), 1, "min"), Fmt.quality(r.get("life_quality"))] if r.get("life_min") != null else "—"
	var band: Variant = r.get("band")
	if band is Array and (band as Array).size() == 2:
		band_label.text = "Banda de incertidumbre de kc (todas las familias de datos del material): %s N/mm²" % Fmt.span(band[0], band[1], 0)
	else:
		band_label.text = "Sin banda: sin datos de fuerza de corte para este material."
	var parts: Variant = r.get("kc_parts")
	if parts is Dictionary:
		var pd: Dictionary = parts
		parts_label.text = "kc = kc1.1·h^−mc (%s) × Kγ %s × Kvc %s × Kver %s × Ksp %s (taladrado)" % [Fmt.num(pd.get("k"), 0),
			Fmt.num(pd.get("Kgamma"), 3), Fmt.num(pd.get("Kvc"), 2), Fmt.num(pd.get("Kver"), 2), Fmt.num(pd.get("Ksp"), 2)]
	else:
		parts_label.text = ""
	quality_label.text = "Calidad de los datos de fuerza: " + (Fmt.quality(r.get("quality")) if r.get("quality") != null else "—")


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
	var cur_y: Variant = md.drill_result.get(sweep_output)
	chart.set_data({
		"xs": sw["xs"], "ys": ys, "over": over,
		"current": Vector2(md.sweep_current_x(KIND, key), float(cur_y) if cur_y != null else NAN),
		"limit": float(md.drill_machine["pmax_kw"]) if sweep_output == "pmotor_kw" else NAN,
		"limit_label": "motor de la máquina: %s" % Fmt.unit(md.drill_machine["pmax_kw"], 2, "kW"),
		"title": "%s frente a %s" % [str(out_def[1]), str(sw["label"]).to_lower()],
		"x_label": "%s (%s)" % [str(sw["label"]), str(sw["unit"])], "y_unit": str(out_def[2]),
		"x_dec": int(sw["decimals"]), "y_dec": int(out_def[3]), "pending": bool(sw.get("pending", false)),
	})
