## Taller industrial · calculadoras de torneado, fresado y taladrado: las entradas (material, herramienta,
## diámetro, vc, avance, profundidad…) y lo que devuelve core/taller/cutting.gd: giro, espesor de viruta, kc con su
## banda de incertidumbre (todas las familias de datos del material) y su desglose, fuerzas, potencia en el filo y
## en el motor, par, caudal, Ra ideal, vida estimada (Taylor), la calidad de los datos, avisos y fuentes.
## Todo sale de WorkshopState: aquí no se calcula nada.
extends Control

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")

const KINDS := [["torneado", "Torneado"], ["fresado", "Fresado"], ["taladrado", "Taladrado"]]
const WEAR := [["nuevo", "nuevo"], ["ligero", "ligero"], ["medio", "medio"], ["fuerte", "fuerte"]]
## Deslizadores de cada calculadora: [clave, rótulo, mín, máx, paso, decimales, unidad]. Recorridos de interfaz.
const FIELDS := {
	"torneado": [
		["d_mm", "Diámetro de la pieza", 5.0, 200.0, 1.0, 0, "mm"],
		["vc", "Velocidad de corte vc", 10.0, 600.0, 5.0, 0, "m/min"],
		["f_mm_rev", "Avance f", 0.02, 0.8, 0.01, 2, "mm/vuelta"],
		["ap_mm", "Profundidad ap", 0.1, 10.0, 0.1, 1, "mm"],
		["kappa_deg", "Ángulo de posición κr", 45.0, 95.0, 5.0, 0, "°"],
		["nose_r_mm", "Radio de punta rε", 0.2, 1.6, 0.2, 1, "mm"],
	],
	"fresado": [
		["dc_mm", "Diámetro de la fresa", 6.0, 160.0, 1.0, 0, "mm"],
		["z", "Dientes", 1.0, 10.0, 1.0, 0, ""],
		["vc", "Velocidad de corte vc", 10.0, 600.0, 5.0, 0, "m/min"],
		["fz_mm", "Avance por diente fz", 0.02, 0.4, 0.01, 2, "mm"],
		["ap_mm", "Profundidad axial ap", 0.2, 10.0, 0.1, 1, "mm"],
		["ae_mm", "Ancho de corte ae", 1.0, 160.0, 1.0, 0, "mm"],
	],
	"taladrado": [
		["d_mm", "Diámetro de la broca", 1.0, 40.0, 0.5, 1, "mm"],
		["vc", "Velocidad de corte vc", 5.0, 150.0, 1.0, 0, "m/min"],
		["f_mm_rev", "Avance f", 0.02, 0.6, 0.01, 2, "mm/vuelta"],
		["point_angle_deg", "Ángulo de punta σ", 90.0, 140.0, 1.0, 0, "°"],
	],
}

var state: WorkshopState
var pane: TwoPane
var compact := false
var kind_chips := {}
var wear_chips := {}
var work_opt: OptionButton
var tool_opt: OptionButton
var centered_check: CheckButton
var field_box: VBoxContainer
var sliders := {}  # clave → { row, slider, value }
var out := {}  # nombre → Label
var band_label: Label
var parts_label: Label
var quality_label: Label
var warn_list: VBoxContainer
var sources_label: Label
var result_card: Card
var _fields_kind := ""
var _built := false


func build(ws: WorkshopState) -> void:
	if _built:
		return
	_built = true
	state = ws
	name = "Calculadoras"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane = TwoPane.new()
	add_child(pane)
	_build_result_card()
	_build_input_card()
	refresh()


func _build_input_card() -> void:
	var card := Card.new("Entradas")
	var kc := Style.chips(KINDS, func(id: String) -> void: state.set_calc_kind(id))
	kind_chips = kc.buttons
	card.body.add_child(kc.box)
	var works: Array = []
	for id in WorkMaterials.ids():
		works.append([id, str(WorkMaterials.get_material(id)["name"])])
	card.body.add_child(Style.label("Material de la pieza", "TallerTenue"))
	work_opt = Style.options(works, func(id: String) -> void: state.set_calc("work_id", id))
	card.body.add_child(work_opt)
	var tools: Array = []
	for id in ToolMaterials.ids():
		tools.append([id, str(ToolMaterials.get_tool(id)["name"])])
	card.body.add_child(Style.label("Material de la herramienta", "TallerTenue", true))
	tool_opt = Style.options(tools, func(id: String) -> void: state.set_calc("tool_id", id))
	card.body.add_child(tool_opt)
	field_box = VBoxContainer.new()
	card.body.add_child(field_box)
	centered_check = CheckButton.new()
	centered_check.text = "Fresa centrada sobre el ancho (si no, fresado lateral desde un borde)"
	centered_check.focus_mode = Control.FOCUS_NONE
	centered_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centered_check.toggled.connect(func(on: bool) -> void: state.set_calc("centered", on))
	card.body.add_child(centered_check)
	card.body.add_child(Style.label("Desgaste del filo (Kver)", "TallerTenue", true))
	var wc := Style.chips(WEAR, func(id: String) -> void: state.set_calc("wear", id))
	wear_chips = wc.buttons
	card.body.add_child(wc.box)
	pane.side.add_child(card)


func _build_result_card() -> void:
	result_card = Card.new("Resultado", "valores orientativos")
	var g := Style.grid()
	for k in [["rpm", "Giro"], ["vc", "vc"], ["h", "Espesor de viruta"], ["kc", "kc"], ["fc", "Fuerzas"], ["pc", "Potencia"],
			["torque", "Par"], ["q", "Caudal de viruta"], ["ra", "Rugosidad ideal"], ["life", "Vida (Taylor)"], ["extra", "Además"]]:
		out[k[0]] = Style.grid_row(g, k[1], "TallerDato")
	result_card.body.add_child(g)
	band_label = Style.label("", "TallerTenue", true)
	result_card.body.add_child(band_label)
	parts_label = Style.label("", "TallerNota", true)
	result_card.body.add_child(parts_label)
	quality_label = Style.label("", "TallerAviso", true)
	result_card.body.add_child(quality_label)
	warn_list = VBoxContainer.new()
	result_card.body.add_child(warn_list)
	sources_label = Style.label("", "TallerNota", true)
	result_card.body.add_child(sources_label)
	pane.visual.add_child(result_card)


func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)


func on_shown() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func _rebuild_fields(kind: String) -> void:
	if kind == _fields_kind:
		return
	_fields_kind = kind
	Style.clear(field_box)
	sliders.clear()
	for f in FIELDS[kind]:
		var key: String = f[0]
		var is_int: bool = key == "z"
		var s := Style.slider(f[1], f[2], f[3], f[4], func(v: float) -> void: state.set_calc(key, int(v) if is_int else v))
		field_box.add_child(s.row)
		sliders[key] = s


func refresh() -> void:
	if state == null:
		return
	var kind := state.calc_kind
	var p: Dictionary = state.calc[kind]
	var r: Dictionary = state.calc_result
	Style.pick_chip(kind_chips, kind)
	Style.pick_chip(wear_chips, str(p.get("wear", "nuevo")))
	Style.pick_option(work_opt, p["work_id"])
	Style.pick_option(tool_opt, p["tool_id"])
	_rebuild_fields(kind)
	for f in FIELDS[kind]:
		var s: Dictionary = sliders[f[0]]
		(s.slider as HSlider).set_value_no_signal(float(p[f[0]]))
		(s.value as Label).text = Fmt.unit(p[f[0]], int(f[5]), str(f[6]))
	centered_check.visible = kind == "fresado"
	centered_check.set_pressed_no_signal(bool(p.get("centered", true)))
	_fill(r, kind)


func _fill(r: Dictionary, kind: String) -> void:
	out["rpm"].text = Fmt.unit(r.get("rpm"), 0, "rpm") + (" · limitado por la máquina" if bool(r.get("rpm_limited", false)) else "")
	out["vc"].text = Fmt.unit(r.get("vc"), 0, "m/min")
	match kind:
		"fresado":
			out["h"].text = "hm %s · hex %s · %s dientes en corte" % [Fmt.unit(r.get("hm_mm"), 3, "mm"), Fmt.unit(r.get("hex_mm"), 3, "mm"), Fmt.num(r.get("zc"), 2)]
			out["fc"].text = "Fc media %s" % Fmt.unit(r.get("fc_mean_n"), 0, "N")
			out["ra"].text = "—"
			out["extra"].text = "vf %s · paso de dientes %s" % [Fmt.unit(r.get("vf_mm_min"), 0, "mm/min"), Fmt.unit(r.get("tooth_hz"), 0, "Hz")]
		"taladrado":
			out["h"].text = Fmt.unit(r.get("h_mm"), 3, "mm")
			out["fc"].text = "%s por filo · empuje %s" % [Fmt.unit(r.get("fc_edge_n"), 0, "N"), Fmt.unit(r.get("thrust_n"), 0, "N")]
			out["ra"].text = "—"
			out["extra"].text = "vf %s" % Fmt.unit(r.get("vf_mm_min"), 0, "mm/min")
		_:
			out["h"].text = "%s · b %s · A %s" % [Fmt.unit(r.get("h_mm"), 3, "mm"), Fmt.unit(r.get("b_mm"), 2, "mm"), Fmt.unit(r.get("a_mm2"), 3, "mm²")]
			out["fc"].text = "Fc %s · Ff %s · Fp %s" % [Fmt.unit(r.get("fc_n"), 0, "N"), Fmt.unit(r.get("ff_n"), 0, "N"), Fmt.unit(r.get("fp_n"), 0, "N")]
			out["ra"].text = "Ra %s · Rt %s" % [Fmt.unit(r.get("ra_um"), 2, "µm"), Fmt.unit(r.get("rt_um"), 2, "µm")]
			out["extra"].text = "calidad de Ff y Fp: " + Fmt.quality(r.get("ff_fp_quality")) if r.get("ff_fp_quality") != null else "—"
	out["kc"].text = Fmt.unit(r.get("kc"), 0, "N/mm²")
	var over := bool(r.get("overload", false))
	out["pc"].text = "%s en el filo · %s en el motor%s" % [Fmt.unit(r.get("pc_kw"), 2, "kW"), Fmt.unit(r.get("pmotor_kw"), 2, "kW"), " · SOBRECARGA" if over else ""]
	out["pc"].theme_type_variation = "TallerMal" if over else "TallerDato"
	out["torque"].text = Fmt.unit(r.get("torque_nm"), 1, "N·m")
	out["q"].text = Fmt.unit(r.get("q_cm3_min"), 1, "cm³/min")
	out["life"].text = "%s (%s)" % [Fmt.unit(r.get("life_min"), 1, "min"), Fmt.quality(r.get("life_quality"))] if r.get("life_min") != null else "—"
	var band: Variant = r.get("band")
	if band is Array and (band as Array).size() == 2:
		band_label.text = "Banda de incertidumbre de kc (todas las familias de datos del material): %s N/mm²" % Fmt.span(band[0], band[1], 0)
	else:
		band_label.text = "Sin banda: el material no tiene datos de fuerza de corte."
	var parts: Variant = r.get("kc_parts")
	if parts is Dictionary:
		var pd: Dictionary = parts
		parts_label.text = "kc = kc1.1·h^−mc (%s) × Kγ %s × Kvc %s × Kver %s × Ksp %s" % [Fmt.num(pd.get("k"), 0),
			Fmt.num(pd.get("Kgamma"), 3), Fmt.num(pd.get("Kvc"), 2), Fmt.num(pd.get("Kver"), 2), Fmt.num(pd.get("Ksp"), 2)]
	else:
		parts_label.text = ""
	quality_label.text = "Calidad de los datos: " + Fmt.quality(r.get("quality")) if r.get("quality") != null else "Calidad de los datos: —"
	Style.clear(warn_list)
	for w in r.get("warnings", []):
		warn_list.add_child(Style.label(str(w), "TallerAviso", true))
	sources_label.text = "Fuentes: " + "; ".join(PackedStringArray(r.get("sources", [])))
