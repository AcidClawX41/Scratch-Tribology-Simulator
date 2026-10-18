## Demo de la radial contra chapa de coche: guion determinista de 12 s (5 casos × 2,4 s) que compara, con la misma
## cámara de detalle y el recuadro de la sección a escala, cinco cortes del modelo de corte (core/taller/radial.gd):
##   1 · disco fino en acero dulce · 2 · disco grueso en acero dulce · 3 · Al₂O₃ en aluminio ·
##   4 · disco en la aleta de plástico · 5 · pilar B de acero al boro.
## Captura: npm run godot:capture -- res://app/taller/demo_radial.tscn --frames=360 --out=<carpeta>
## Para revisar un caso o una vista: … --frames=30 -- --caso=3 --vista=general (caso fijo de 1 a 5; vista: detalle,
## general, canto o cenital) y, para probar la máquina, --rpm=6000 o --angulo=20 (se aplican a todos los casos).
## El tiempo sale de la suma de los delta (Movie Maker los da fijos: 1/30 s), así que cada fotograma es siempre igual.
extends Node

const Radial = preload("res://core/taller/radial.gd")
const Looks = preload("res://app/taller/radial3d/looks.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const MONO = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const MONO_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")
const DISP = preload("res://assets/fonts/syne-latin-700-normal.woff2")

const CASE_S := 2.4
## El corte empieza ya avanzado: el disco (Ø125) queda dentro de la chapa y detrás se ve el surco hecho.
const PRE_CUT_MM := 110.0
const COMMON := {"diameter_mm": 125.0, "cut_length_mm": 200.0}
const CASES := [
	{
		"title": "Disco fino en acero dulce",
		"params": {"disc_id": "fino_1mm", "panel_id": "acero-dulce", "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 20.0},
	},
	{
		"title": "Disco grueso en acero dulce",
		"params": {"disc_id": "grueso_3mm", "panel_id": "acero-dulce", "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 12.0},
	},
	{
		"title": "Al2O3 en aluminio: el disco se embota",
		"params": {"disc_id": "fino_1mm", "panel_id": "aluminio", "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 16.0},
	},
	{
		"title": "Aleta de plástico: se funde, no se corta",
		"params": {
			"disc_id": "fino_1mm", "panel_id": "plastico-carroceria", "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 15.0,
		},
	},
	{
		"title": "Pilar B de acero al boro (22MnB5)",
		"params": {"disc_id": "diamante", "panel_id": "boro-22mnb5", "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 3.0},
	},
]

var _t := 0.0
var _case := -1
var _fixed_case := -1
var _override := {}
var _labels := {}
var _bar: ColorRect
var _bar_back: ColorRect
var _fade: ColorRect
var _dots: Array[Label] = []

@onready var radial: Node3D = $Radial3D


func _ready() -> void:
	var start_view := "detalle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_fixed_case = clampi(int(a.substr(7)) - 1, 0, CASES.size() - 1)
		elif a.begins_with("--vista="):
			start_view = a.substr(8)
		elif a.begins_with("--rpm="):
			_override["rpm"] = float(a.substr(6))
		elif a.begins_with("--angulo="):
			_override["angle_deg"] = float(a.substr(9))
	radial.set_inset(true)
	radial.set_view(start_view)
	_build_hud()
	_show_case(maxi(_fixed_case, 0))


func _process(delta: float) -> void:
	_t += delta
	var idx := int(floor(_t / CASE_S)) % CASES.size() if _fixed_case < 0 else _fixed_case
	if idx != _case:
		_show_case(idx)
	var local := fmod(_t, CASE_S) if _fixed_case < 0 else CASE_S
	_fade.color.a = clampf(1.0 - local / 0.18, 0.0, 1.0) * 0.85
	var inf: Dictionary = radial.info()
	_labels["strobe"].text = _strobe_text(inf)


func _show_case(idx: int) -> void:
	_case = idx
	var c: Dictionary = CASES[idx]
	var p: Dictionary = COMMON.duplicate()
	p.merge(c["params"], true)
	p.merge(_override, true)
	var res := Radial.cut_panel(p)
	radial.set_params(p)
	radial.set_result(res)
	radial.start_cut(PRE_CUT_MM, 0.5)
	var disc := Looks.disc(str(p["disc_id"]))
	var panel := Looks.panel(str(p["panel_id"]))
	var vs := float(res["vs_ms"])
	var clean := float(res["cleanliness"])
	_labels["case"].text = "Caso %d/%d" % [idx + 1, CASES.size()]
	_labels["title"].text = str(c["title"])
	_labels["disc"].text = "Disco %s · %s rpm · %s m/s · ángulo %s°" % [
		str(disc["short"]) + (" Al2O3" if str(disc["kind"]) == "abrasivo" else ""), _thousands(float(p["rpm"])),
		Js.to_fixed(vs, 0), Js.to_fixed(float(p["angle_deg"]), 0)]
	_labels["panel"].text = "%s %s mm (%s) · avance %s mm/s" % [
		str(panel["name"]), Js.to_fixed(float(panel["t_mm"]), 2), str(panel["part"]),
		Js.to_fixed(float(p["cut_length_mm"]) / float(res["time_s"]) if is_finite(float(res["time_s"])) and float(res["time_s"]) > 0.0 else 0.0, 1)]
	_labels["clean"].text = "Limpieza del corte: %s/10 · %s" % [Js.to_fixed(clean, 0), _clean_word(clean)]
	var sp: Dictionary = res["sparks"] if res["sparks"] is Dictionary else {}
	var sparks_txt := "sin chispas"
	if float(sp.get("rate", 0.0)) > 0.0:
		sparks_txt = "chispas %s/s, haz %s m" % [
			Js.to_fixed(float(sp["rate"]), 0), Js.to_fixed(float(sp["length_mm"]) / 1000.0, 1)]
	var tint: Dictionary = res["heat_tint"]
	_labels["data"].text = "surco %s mm · rebaba %s µm · pintura quemada %s mm\n%s °C en el borde (zona %s mm) · %s" % [
		Js.to_fixed(float(res["kerf_mm"]), 2), Js.to_fixed(float(res["burr_um"]), 0),
		Js.to_fixed(float(res["paint_burn_mm"]), 1),
		Js.to_fixed(float(tint["temp_c"]), 0), Js.to_fixed(float(res["haz_mm"]), 1), sparks_txt]
	var warns: Array = res["warnings"]
	_labels["warn"].text = String((warns[warns.size() - 1] as Dictionary).get("message", "")) if warns.size() > 0 else ""
	var k := clampf(clean / 10.0, 0.0, 1.0)
	_bar.size.x = _bar_back.size.x * maxf(k, 0.04)
	var warm := Palette.color("mint").lerp(Palette.color("gold"), clampf(k * 2.0, 0.0, 1.0))
	_bar.color = warm.lerp(Palette.color("coral"), clampf(k * 2.0 - 1.0, 0.0, 1.0))
	for i in _dots.size():
		_dots[i].add_theme_color_override("font_color", Palette.color("mint") if i == idx else Palette.color("dimmer"))
		_dots[i].add_theme_font_size_override("font_size", 26 if i == idx else 15)


func _strobe_text(inf: Dictionary) -> String:
	var hz := float(inf["strobe_hz"])
	var rps := float(radial.params["rpm"]) / 60.0
	if hz <= 0.0:
		return "El disco gira a %s vueltas/s" % Js.to_fixed(rps, 1)
	return "Estroboscopio a %s Hz: el disco gira a %s vueltas/s y parece ir despacio" % [
		Js.to_fixed(hz, 1), Js.to_fixed(rps, 1)]


static func _clean_word(c: float) -> String:
	if c < 3.0:
		return "limpio"
	if c < 5.5:
		return "aceptable"
	if c < 7.5:
		return "sucio"
	return "muy sucio"


## 11000 → «11 000» (separador de miles con espacio fino, como en la 1.x).
static func _thousands(x: float) -> String:
	var s := Js.to_fixed(x, 0)
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - 1 - i
		if left > 0 and left % 3 == 0:
			out += " "
	return out


func _label(parent: Control, font: Font, size: int, color: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(color))
	l.add_theme_color_override("font_outline_color", Color(0.09, 0.05, 0.11, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.color("panel"), 0.88)
	sb.border_color = Palette.color("line2")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(14, 14)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_labels["case"] = _label(head, MONO_BOLD, 15, "mint")
	for i in CASES.size():
		_dots.append(_label(head, MONO_BOLD, 15, "dimmer"))
		_dots[i].text = "•"
	_labels["title"] = _label(box, DISP, 28, "text")
	_labels["disc"] = _label(box, MONO, 15, "text")
	_labels["panel"] = _label(box, MONO, 15, "dim")
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 10)
	box.add_child(meter)
	_labels["clean"] = _label(meter, MONO_BOLD, 17, "gold")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(200, 14)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.add_child(holder)
	_bar_back = ColorRect.new()
	_bar_back.color = Palette.color("panel3")
	_bar_back.size = Vector2(200, 14)
	holder.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.size = Vector2(20, 14)
	holder.add_child(_bar)
	_labels["data"] = _label(box, MONO, 14, "dim")
	_labels["warn"] = _label(box, MONO, 14, "coral")
	_labels["warn"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_labels["warn"].custom_minimum_size = Vector2(620, 0)

	var foot := VBoxContainer.new()
	foot.anchor_left = 1.0
	foot.anchor_right = 1.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = -700.0
	foot.offset_right = -16.0
	foot.offset_top = -74.0
	foot.offset_bottom = -12.0
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 2)
	root.add_child(foot)
	_labels["strobe"] = _label(foot, MONO, 14, "ice")
	var model := _label(foot, MONO, 13, "dimmer")
	model.text = "Modelo de corte: core/taller/radial.gd (fuentes y estimaciones en docs/taller/fuentes-u6.md)"
	var src := _label(foot, MONO, 13, "dimmer")
	src.text = "Chispas: TC 9-237, tabla 7-5 · revenido: TM 9-237, tabla IV"
	for l in [_labels["strobe"], model, src]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(Palette.color("bg"), 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	root.move_child(_fade, 0)
