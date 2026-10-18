## Barra de nivel redondeada (las barras de dureza y de severidad de la 1.x), con una transición suave del ancho.
## Uso: var b := Bar.new(9.0); b.set_level(0.62, Palette.color("rose"))
extends Control

const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")

## Duración de la transición del ancho (s): .6s en las barras de dureza de la 1.x.
var duration := 0.6
var level := 0.0
var color := Color.WHITE
var with_border := true
var _shown := 0.0
var _from := 0.0
var _t := 1.0
var _bg: StyleBoxFlat
var _fill: StyleBoxFlat


func _init(height := 9.0, border := true) -> void:
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	with_border = border
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := int(height * 0.7)
	_bg = AppTheme.box(Palette.color("panel2"), r, Palette.color("line") if border else Color.TRANSPARENT, 1 if border else 0)
	_fill = AppTheme.box(Color.WHITE, r)


## Nivel 0-1 y color. instant = sin transición.
func set_level(v: float, col: Color, instant := false) -> void:
	color = col
	if instant or duration <= 0.0:
		level = v
		_shown = v
		_t = 1.0
	elif not is_equal_approx(v, level):
		_from = _shown
		level = v
		_t = 0.0
	set_process(_t < 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t = minf(1.0, _t + delta / duration)
	var e := 1.0 - pow(1.0 - _t, 3.0)
	_shown = lerpf(_from, level, e)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)


func _draw() -> void:
	draw_style_box(_bg, Rect2(Vector2.ZERO, size))
	var w := size.x * clampf(_shown, 0.0, 1.0)
	if w >= 1.0:
		_fill.bg_color = color
		draw_style_box(_fill, Rect2(0, 0, maxf(w, size.y), size.y))
