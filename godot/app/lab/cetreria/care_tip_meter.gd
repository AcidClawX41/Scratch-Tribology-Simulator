## Cetrería · el medidor de la punta (unidad 5s, petición 60), sobre la vista 3D y siempre visible mientras se trabaja: una
## regla en escala logarítmica del radio de la punta frente al natural, con sus cuatro zonas (aguja · afilada · natural · roma),
## la banda buena enmarcada (del borde de la aguja a ×2: CareData.MARGINS), la flecha de dónde está ahora y, debajo, cuántas
## pasadas faltan con la mano de ahora y el aviso para afilar si se ha recortado. No calcula nada: pinta la ayuda del afilado
## del motor (view().tip_help: SharpenHelp.meter y advice, hecha en el hilo del estado). Se repinta solo si cambia.
extends PanelContainer

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const FONT_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## Color de cada zona de la regla.
const ZONE_COLOR := { "aguja": "coral", "afilada": "mint", "natural": "ice", "roma": "gold" }
const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral" }
## Ancho del medidor (px) en escritorio y en el teléfono, y alto de la regla.
const WIDTH := 300.0
const WIDTH_PHONE := 160.0
const BAR_H := 30.0

var compact := false
var _title: Label
var _zone: Label
var _bar: Control
var _text: Label
var _advice: Label
## Qué hace la punta según su material (SharpenHelp.tip_character): se mella, se dobla o se parte; corta, entra en cuña o ara.
var _char: Label
var _key := ""
var _m: Dictionary = {}


func _init() -> void:
	name = "MedidorDeLaPunta"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.09, 0.78)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = _label("Punta", 13, "text", true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_zone = _label("", 13, "mint", true)
	head.add_child(_zone)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(WIDTH, BAR_H)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	_text = _label("", 11, "text", false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH
	col.add_child(_text)
	_advice = _label("", 11, "gold", false)
	_advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advice.custom_minimum_size.x = WIDTH
	_advice.visible = false
	col.add_child(_advice)
	_char = _label("", 10, "dim", false)
	_char.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char.custom_minimum_size.x = WIDTH
	col.add_child(_char)


func _label(t: String, size: int, tone: String, bold: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(tone))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## El teléfono: más estrecho, la regla más baja y el texto de las pasadas solo (el de la zona va en la cabecera).
func set_compact(on: bool) -> void:
	compact = on
	var w := WIDTH_PHONE if on else WIDTH
	_bar.custom_minimum_size = Vector2(w, BAR_H * (0.8 if on else 1.0))
	for l: Label in [_text, _advice]:
		l.custom_minimum_size.x = w
		l.add_theme_font_size_override("font_size", 10 if on else 11)
	_char.custom_minimum_size.x = w
	# en el teléfono no cabe: va en la tarjeta («Punta al empezar»)
	_char.visible = not on
	_title.add_theme_font_size_override("font_size", 11 if on else 13)
	_zone.add_theme_font_size_override("font_size", 11 if on else 13)
	_key = ""


## Pinta la ayuda del afilado de la vista (view().tip_help). Barata si no ha cambiado.
func show_view(v: Dictionary) -> void:
	var th: Dictionary = v.get("tip_help", {})
	visible = not th.is_empty()
	if th.is_empty():
		return
	var m: Dictionary = th.get("meter", {})
	var adv: Dictionary = th.get("advice", {})
	var ch := String((m.get("character", {}) as Dictionary).get("text", ""))
	var key := "%s|%s|%s|%s|%s" % [String(th.get("key", "")), String(m.get("text", "")), String(adv.get("fix", "")), str(compact), ch]
	if key == _key:
		return
	_key = key
	_m = m
	_zone.text = "%s · ×%s" % [String(m.get("zoneName", "")), _ratio(float(m.get("ratio", 1.0)))]
	_zone.add_theme_color_override("font_color", Palette.color(String(TONE.get(String(m.get("tone", "")), "text"))))
	var ps: Dictionary = m.get("passes", {})
	# lo que hay que hacer (las pasadas que faltan o el aviso de la herramienta); el radio y la zona, en la cabecera y en la lupa
	var pt := String(ps.get("text", ""))
	_text.text = (pt.substr(0, 1).to_upper() + pt.substr(1)) if pt != "" else "Punta de %s µm (la natural, %s µm)." % [_um(float(m.get("tipRadiusUm", 0.0))), _um(float(m.get("naturalUm", 0.0)))]
	var show_adv := bool(adv.get("show", false))
	_advice.visible = show_adv
	if show_adv:
		var fix := String(adv.get("fix", ""))
		_advice.text = (fix if compact and fix != "" else String(adv.get("text", "")) + ((" " + fix) if fix != "" else ""))
	_char.text = ch
	_bar.queue_redraw()


static func _ratio(r: float) -> String:
	if r < 0.1:
		return Js.to_fixed(r, 2)
	return Js.to_fixed(r, 1) if r < 10.0 else Js.to_fixed(r, 0)


static func _um(x: float) -> String:
	return Js.to_fixed(x, 1) if x < 10.0 else Js.to_fixed(x, 0)


## La regla: las cuatro zonas, la banda buena enmarcada, las marcas (×0,5 · natural · ×2) y la flecha.
func _draw_bar() -> void:
	if _m.is_empty():
		return
	var w := _bar.size.x
	var h := _bar.size.y
	var y0 := 4.0
	var bh := h * 0.42
	for z: Dictionary in _m.get("zones", []):
		var x0 := float(z.from) * w
		var x1 := float(z.to) * w
		var c := Palette.color(String(ZONE_COLOR.get(String(z.id), "dim")))
		c.a = 0.55
		_bar.draw_rect(Rect2(x0, y0, maxf(x1 - x0, 1.0), bh), c)
	var bp: Array = _m.get("bandPos", [0.0, 0.0])
	_bar.draw_rect(Rect2(float(bp[0]) * w, y0 - 1.0, (float(bp[1]) - float(bp[0])) * w, bh + 2.0), Palette.color("mint"), false, 2.0)
	var fs := 9 if compact else 10
	for mk: Dictionary in _m.get("marks", []):
		# en el teléfono no caben las tres: solo la natural (la banda va enmarcada)
		if compact and float(mk.ratio) != 1.0:
			continue
		var x := float(mk.pos) * w
		_bar.draw_line(Vector2(x, y0 + bh), Vector2(x, y0 + bh + 4.0), Palette.color("text"), 1.0)
		var txt := String(mk.label)
		var tw := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_bar.draw_string(FONT, Vector2(clampf(x - tw * 0.5, 0.0, w - tw), h - 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color("dim"))
	# los nombres de los extremos
	_bar.draw_string(FONT, Vector2(1.0, h - 1.0), "aguja", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color("coral"))
	var rw := FONT.get_string_size("roma", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_bar.draw_string(FONT, Vector2(w - rw - 1.0, h - 1.0), "roma", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color("gold"))
	# la flecha de dónde está ahora (hacia abajo, sobre la regla)
	var ax := clampf(float(_m.get("pos", 0.5)) * w, 3.0, w - 3.0)
	var col := Palette.color(String(TONE.get(String(_m.get("tone", "")), "text")))
	var tri := PackedVector2Array([Vector2(ax - 6.0, y0 - 3.0), Vector2(ax + 6.0, y0 - 3.0), Vector2(ax, y0 + bh * 0.75)])
	_bar.draw_colored_polygon(tri, col)
	_bar.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.05, 0.02, 0.07, 0.9), 1.0, true)
	_bar.draw_line(Vector2(ax, y0), Vector2(ax, y0 + bh), col, 2.0)
	# los extremos: más allá, la flecha se queda en el borde
	if float(_m.get("pos", 0.5)) <= 0.0 or float(_m.get("pos", 0.5)) >= 1.0:
		_bar.draw_string(FONT_BOLD, Vector2(ax - 4.0, y0 + bh - 2.0), "»", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
