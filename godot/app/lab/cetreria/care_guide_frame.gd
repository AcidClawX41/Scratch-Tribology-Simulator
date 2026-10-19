## Cetrería · el mando que señala el guiado en el panel (unidad 5y): un borde que late alrededor del control y una etiqueta
## corta encima («Pulsa aquí · Capucha y toalla»). Va encima de todo (top_level) y sigue al control en cada fotograma (el
## panel se desplaza); dentro del recorte que le da la página (la columna con su desplazamiento): lo que queda fuera no se
## dibuja. Solo pinta: qué control es lo decide la página con el id del objetivo.
## Uso: var f := CareGuideFrame.new(); page.add_child(f); f.follow(control, "Capucha y toalla", "gold", recorte); f.advance(dt).
extends Control

const Ui = preload("res://app/common/ui.gd")
const Palette = preload("res://app/theme/palette.gd")

## El borde (dibujo): cuánto sobresale del control, grosor, esquinas y latido (rad/s).
const PAD := 4.0
const BORDER := 3
const RADIUS := 10
const PULSE := 5.0

var target: Control = null
var clip := Rect2()
var tag: PanelContainer
var tag_label: Label
var _style: StyleBoxFlat
var _tag_style: StyleBoxFlat
var _tone := "gold"
var _t := 0.0


func _init() -> void:
	name = "MarcoDelGuiado"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_style = StyleBoxFlat.new()
	_style.draw_center = false
	_style.set_border_width_all(BORDER)
	_style.set_corner_radius_all(RADIUS)
	tag = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_style = StyleBoxFlat.new()
	_tag_style.set_corner_radius_all(6)
	_tag_style.content_margin_left = 7.0
	_tag_style.content_margin_right = 7.0
	_tag_style.content_margin_top = 1.0
	_tag_style.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("panel", _tag_style)
	tag_label = Ui.label("", "Small", "bg")
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(tag_label)
	add_child(tag)
	visible = false


## Señala este control (null lo quita) con su etiqueta y su tono; clip: el recorte en coordenadas globales (vacío: ninguno).
func follow(c: Control, label: String, tone: String = "gold", clip_rect := Rect2()) -> void:
	target = c
	clip = clip_rect
	_tone = tone
	var col := Palette.color(tone)
	_tag_style.bg_color = Color(col, 0.95)
	tag_label.text = ("Pulsa aquí · " + label) if label != "" else "Pulsa aquí"
	_place()


## Lo que se ve, para los tests.
func info() -> Dictionary:
	return { "visible": visible, "rect": Rect2(position, size), "label": tag_label.text, "target": target }


func advance(dt: float) -> void:
	_t += dt
	_place()
	if visible:
		queue_redraw()


func _place() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		visible = false
		return
	var r := target.get_global_rect().grow(PAD)
	if clip.has_area():
		r = r.intersection(clip)
	if not r.has_area() or r.size.y < 6.0:
		visible = false
		return
	visible = true
	position = r.position
	size = r.size
	var ts := tag.get_combined_minimum_size()
	# la etiqueta encima del borde (o debajo, si no cabe por arriba del recorte)
	var top := clip.position.y if clip.has_area() else 0.0
	var y := -ts.y - 2.0 if r.position.y - ts.y - 2.0 >= top else r.size.y + 2.0
	tag.position = Vector2(0.0, y)
	tag.size = ts


func _draw() -> void:
	var k := 0.5 + 0.5 * sin(_t * PULSE)
	_style.border_color = Color(Palette.color(_tone), 0.45 + 0.5 * k)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
