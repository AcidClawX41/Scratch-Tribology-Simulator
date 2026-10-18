## Cetrería · una barra horizontal fina (unidad 5o, petición 51): lo que se llena (value, 0-1) del color de su tono («bien» verde,
## «aviso» ámbar, «mal» rojo; «» gris) y, si la tiene, la marca de lo permitido (limit, 0-1). La usan la barra del estado del
## animal, la cuenta de lo que se está haciendo y el progreso del tutorial. Solo dibuja: nada se crea al cambiar el valor.
## Uso: var m := CareMeter.new(); m.set_state(0.4, 0.7, "aviso")
extends Control

const Palette = preload("res://app/theme/palette.gd")

const TONE_COLOR := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "dim" }

var value := 0.0
var limit := -1.0
var tone := ""
var _bg := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()


func _init(h := 8.0) -> void:
	custom_minimum_size = Vector2(48.0, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rad := int(minf(h * 0.5, 4.0))
	_bg.bg_color = Palette.color("panel3")
	_bg.set_corner_radius_all(rad)
	_fill.set_corner_radius_all(rad)
	_fill.bg_color = Palette.color("dim")


## El valor (0-1), la marca de lo permitido (0-1; < 0 sin marca) y el tono. Solo repinta si cambia.
func set_state(v: float, lim: float = -1.0, t: String = "") -> void:
	var nv := clampf(v, 0.0, 1.0)
	if is_equal_approx(nv, value) and is_equal_approx(lim, limit) and t == tone:
		return
	value = nv
	limit = lim
	if t != tone:
		tone = t
		_fill.bg_color = Palette.color(String(TONE_COLOR.get(tone, "dim")))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_bg, r)
	if value > 0.0:
		var w := maxf(r.size.x * value, minf(r.size.y, r.size.x))
		draw_style_box(_fill, Rect2(r.position, Vector2(w, r.size.y)))
	if limit > 0.0 and limit < 1.0:
		var x := r.size.x * limit
		draw_line(Vector2(x, -2.0), Vector2(x, r.size.y + 2.0), Palette.color("text"), 2.0)
