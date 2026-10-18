## Tarjeta de una forma de donación (petición 39): el icono, el nombre y una línea que la explica, con el color de su
## plataforma. Al pasar el ratón, o con el foco del teclado, se ilumina con ese color, brilla y crece un poco; al pulsarla,
## se oscurece. Los iconos son dibujos propios (un corazón, una cartera y una taza), no los logotipos de las marcas.
## Uso: var br := DonateCard.brand(id); var c := DonateCard.new(nombre, detalle, Color(br.color), br.icon)
extends Button

const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")

## El color y el icono de cada plataforma, por el id de AppInfo.DONATE_LINKS (el resto, con el rosa de la paleta).
const BRANDS := {
	"github": { "color": "#EA4AAA", "icon": "heart" },
	"paypal": { "color": "#2B9BF0", "icon": "wallet" },
	"kofi": { "color": "#FF5E5B", "icon": "cup" },
}
const ICONS := {
	"heart": "<path d=\"M12 20.3s-7.4-4.5-9.1-9.1C1.7 7.8 3.9 4.6 7.2 4.6c2 0 3.7 1.1 4.8 2.7 1.1-1.6 2.8-2.7 4.8-2.7 3.3 0 5.5 3.2 4.3 6.6-1.7 4.6-9.1 9.1-9.1 9.1z\" fill=\"%s\" stroke=\"none\"/>",
	"wallet": "<rect x=\"3\" y=\"6.5\" width=\"18\" height=\"12.5\" rx=\"2.5\"/><path d=\"M16 10.5h5v5h-5a2.5 2.5 0 0 1 0-5z\"/><path d=\"M5.5 6.5l9-3 1.2 3\"/>",
	"cup": "<path d=\"M4 10h12v4.5A5.5 5.5 0 0 1 10.5 20h-1A5.5 5.5 0 0 1 4 14.5z\"/><path d=\"M16 11.5h1.5a2.5 2.5 0 0 1 0 5H16\"/><path d=\"M8 3.5c-.8.9.8 1.6 0 2.5\"/><path d=\"M12 3.5c-.8.9.8 1.6 0 2.5\"/>",
	"out": "<path d=\"M8 16L16 8\"/><path d=\"M10 8h6v6\"/>",
}
const RADIUS := 14
const HOVER_SCALE := 1.04
const MIN_W := 190.0
const MIN_H := 74.0

var accent := Color.WHITE
var name_label: Label
var detail_label: Label
var _tween: Tween
var _lit := false


## El color y el icono de una plataforma (BRANDS), o el rosa de la paleta y el corazón.
static func brand(id: String) -> Dictionary:
	return BRANDS.get(id, { "color": "#" + Palette.color("rose").to_html(false), "icon": "heart" })


func _init(title := "", detail := "", color := Color.WHITE, icon_id := "heart") -> void:
	accent = color
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(MIN_W, MIN_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", _box(0.10, 0.40, 0, 0.0))
	add_theme_stylebox_override("hover", _box(0.20, 1.0, 12, 0.45))
	add_theme_stylebox_override("pressed", _box(0.32, 1.0, 4, 0.30))
	add_theme_stylebox_override("hover_pressed", _box(0.32, 1.0, 4, 0.30))
	add_theme_stylebox_override("focus", AppTheme.focus_box(RADIUS))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 22)
	for side: String in ["margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 12)
	add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", AppTheme.box(Color(accent, 0.16), 12, Color(accent, 0.5), 1, 9.0, 9.0))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_texture(icon_id, accent)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.custom_minimum_size = Vector2(26, 26)
	badge.add_child(icon_rect)
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 3)
	name_label = Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"CardTitle"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# en una tarjeta estrecha el nombre se recorta con puntos suspensivos: nunca empuja la flecha fuera de la tarjeta
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	detail_label = Label.new()
	detail_label.text = detail
	detail_label.theme_type_variation = &"Small"
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.visible = detail != ""
	texts.add_child(detail_label)
	row.add_child(texts)
	# se abre fuera del programa: la flecha de enlace externo, pequeña en la esquina (no quita sitio al nombre)
	var arrow := TextureRect.new()
	arrow.texture = icon_texture("out", Color(accent, 0.9), 16)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	arrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	arrow.offset_left = -24.0
	arrow.offset_right = -8.0
	arrow.offset_top = 8.0
	arrow.offset_bottom = 24.0
	add_child(arrow)
	mouse_entered.connect(_light.bind(true))
	mouse_exited.connect(_light.bind(false))
	focus_entered.connect(_light.bind(true))
	focus_exited.connect(_light.bind(false))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## La caja de la tarjeta: el fondo y el borde con el color de la plataforma, y el brillo alrededor (glow, px).
func _box(bg_a: float, border_a: float, glow: int, glow_a: float) -> StyleBoxFlat:
	var s := AppTheme.box(Color(Palette.color("panel")).lerp(accent, bg_a), RADIUS, Color(accent, border_a), 1)
	if glow > 0:
		s.shadow_color = Color(accent, glow_a)
		s.shadow_size = glow
	return s


## Encendida (ratón encima o foco): crece un poco y el nombre toma el color de la plataforma.
func _light(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	name_label.add_theme_color_override("font_color", accent.lightened(0.25) if on else Palette.color("text"))
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		scale = Vector2.ONE * (HOVER_SCALE if on else 1.0)
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.12)


static func icon_texture(icon_id: String, color: Color, px := 26) -> Texture2D:
	var col := "#" + color.to_html(false)
	var body := String(ICONS.get(icon_id, ICONS.heart))
	if body.contains("%s"):
		body = body % col
	return AppTheme.icon_texture(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 24 24\" fill=\"none\" " % [px, px]
		+ "stroke=\"%s\" stroke-width=\"1.9\" stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</svg>") % [col, body])
