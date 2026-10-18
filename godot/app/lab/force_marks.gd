## Marcas sobre la pista del deslizador de fuerza (docs/fisica/aguijones.md §7.5): con un aguijón, la fuerza para
## perforar la piel y la carga de pandeo. Va dentro del HSlider, lo cubre entero sin recibir el ratón y pone cada marca
## (un triángulo pequeño bajo la pista) donde el deslizador pondría el centro del tirador con ese valor. La leyenda, con
## los valores, la escribe la tarjeta de los parámetros con Label.
## Uso: var m := ForceMarks.new(slider); slider.add_child(m); m.set_marks([[t, color], …])
extends Control

var slider: HSlider
## [[t (0-1, la posición en la escala del deslizador), color], …]
var marks: Array = []


func _init(p_slider: HSlider = null) -> void:
	slider = p_slider
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_marks(list: Array) -> void:
	if list == marks:
		return
	marks = list
	queue_redraw()


## Centro del tirador con la posición t (0-1), en píxeles del deslizador: como lo dibuja Slider (sin center_grabber, la
## pista útil es el ancho menos el del tirador).
func x_of(t: float) -> float:
	var gw := 0.0
	var centered := false
	if slider != null:
		var g := slider.get_theme_icon("grabber")
		gw = float(g.get_width()) if g != null else 0.0
		centered = slider.get_theme_constant("center_grabber") != 0
	var r := clampf(t, 0.0, 1.0)
	return r * size.x if centered else gw / 2.0 + r * (size.x - gw)


func _draw() -> void:
	for m: Array in marks:
		var x := x_of(m[0])
		var y := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 6.0), Vector2(x - 4.0, y), Vector2(x + 4.0, y)]), m[1])
