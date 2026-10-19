## Cetrería · el guiado sobre la vista 3D (unidad 5y): el aviso corto con la acción de ahora y su valor («Coge la lima fina
## (2)», «Lima de la base a la punta a 20°», «Para: la carne viva está a 1.2 mm»), del color de su tono, y, si lo que se
## señala está en la escena, un aro que late encima con su etiqueta corta. Solo pinta: el objetivo y sus textos salen del
## motor (core/lab/claw_care_guide.gd, en la vista del estado).
## - El aviso (bubble) va arriba, debajo de los textos de la vista, o abajo (en escritorio, a la derecha del indicador de la
##   forma; en el teléfono, encima de él): donde tape menos la garra que se trabaja (place, con los puntos de la garra en la
##   pantalla que da la escena); si empatan, arriba. En el teléfono, la página esconde las líneas de la mano mientras hay
##   guiado.
## - El aro y su etiqueta, en el punto de la pantalla que da la escena (care_3d.guide_screen_point); la etiqueta, al lado del
##   aro y dentro de la vista.
## Nada se crea en cada fotograma: late con queue_redraw.
extends Control

const Ui = preload("res://app/common/ui.gd")
const Palette = preload("res://app/theme/palette.gd")

## El aro (dibujo): radio de abajo, cuánto crece al latir, grosor y latido (rad/s).
const RING_R := 13.0
const RING_GROW := 6.0
const RING_W := 3.0
const PULSE := 5.0
const TONES := { "mal": "coral", "bien": "mint", "aviso": "gold", "": "gold" }

var bubble: PanelContainer
var hint_label: Label
var value_label: Label
var tag: PanelContainer
var tag_label: Label
var _style: StyleBoxFlat
var _tag_style: StyleBoxFlat
var _point := Vector2(-1.0, -1.0)
var _tone := "gold"
var _t := 0.0
var _key := ""
## Dónde va el aviso: «arriba» o «abajo»; cada cuánto se vuelve a mirar (s) y lo que falta.
var side := "arriba"
const PLACE_EVERY_S := 0.25
var _place_t := 0.0


func _init() -> void:
	name = "Guiado"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble = PanelContainer.new()
	bubble.name = "AvisoDelGuiado"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.03, 0.08, 0.84)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)
	_style.content_margin_left = 12.0
	_style.content_margin_right = 12.0
	_style.content_margin_top = 6.0
	_style.content_margin_bottom = 7.0
	bubble.add_theme_stylebox_override("panel", _style)
	var col := Ui.vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(col)
	hint_label = Ui.para("", "CardTitle", "text")
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_label)
	value_label = Ui.para("", "Small", "gold")
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(value_label)
	bubble.visible = false
	add_child(bubble)
	tag = PanelContainer.new()
	tag.name = "EtiquetaDelGuiado"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_style = StyleBoxFlat.new()
	_tag_style.bg_color = Color(0.06, 0.03, 0.08, 0.8)
	_tag_style.set_corner_radius_all(6)
	_tag_style.content_margin_left = 6.0
	_tag_style.content_margin_right = 6.0
	_tag_style.content_margin_top = 1.0
	_tag_style.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("panel", _tag_style)
	tag_label = Ui.label("", "Small", "gold")
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(tag_label)
	tag.visible = false
	add_child(tag)


## El objetivo del guiado ({} lo esconde). Barato si no ha cambiado.
func show_guide(g: Dictionary) -> void:
	var key := String(g.get("key", ""))
	if key == _key:
		return
	_key = key
	if g.is_empty():
		bubble.visible = false
		tag.visible = false
		_point = Vector2(-1.0, -1.0)
		queue_redraw()
		return
	_tone = String(TONES.get(String(g.get("tone", "")), "gold"))
	var c := Palette.color(_tone)
	_style.border_color = Color(c, 0.95)
	_tag_style.border_color = Color(c, 0.9)
	_tag_style.set_border_width_all(1)
	hint_label.text = String(g.get("hint", ""))
	value_label.text = String(g.get("value", ""))
	value_label.visible = value_label.text != ""
	Ui.set_color(value_label, _tone)
	Ui.set_color(tag_label, _tone)
	tag_label.text = String(g.get("label", ""))
	bubble.visible = hint_label.text != ""
	queue_redraw()


## El ancho del aviso (px): el de la columna de los textos, sin pasar de lo que se lee de un vistazo.
func set_width(w: float) -> void:
	var ww := clampf(w, 160.0, 440.0) - 26.0
	if absf(hint_label.custom_minimum_size.x - ww) > 0.5:
		hint_label.custom_minimum_size.x = ww
		value_label.custom_minimum_size.x = ww


## En el teléfono, el aviso más pequeño (una línea donde cabe): deja sitio a la garra.
func set_compact(on: bool) -> void:
	var v := &"Body" if on else &"CardTitle"
	if hint_label.theme_type_variation != v:
		hint_label.theme_type_variation = v
		_style.content_margin_top = 4.0 if on else 6.0
		_style.content_margin_bottom = 5.0 if on else 7.0


## Coloca el aviso donde tape menos la garra: top (px desde arriba: debajo de los textos), left y right (los márgenes de los
## textos), gauge (el indicador de la forma), touch (el ancho de los mandos táctiles de abajo a la derecha, 0 si no están),
## samples (los puntos de la garra en la vista) y compact (el teléfono).
func place(top: float, left: float, right: float, gauge: Rect2, touch: float, samples: PackedVector2Array, compact: bool, dt := 1.0) -> void:
	if not bubble.visible:
		return
	set_compact(compact)
	_place_t -= dt
	var h := bubble.get_combined_minimum_size().y
	var w := minf(size.x - left - right, 440.0)
	var up := Rect2(left, top, w, h)
	var down := Rect2(left, size.y - h - 10.0, minf(size.x - left - maxf(right, touch + 12.0), 440.0), h)
	if compact and gauge.has_area():
		down = Rect2(12.0, gauge.position.y - h - 6.0, size.x - 24.0 - (touch + 6.0 if touch > 0.0 else 0.0), h)
	if _place_t <= 0.0:
		_place_t = PLACE_EVERY_S
		# lo que se señala (el aro y su etiqueta) no se tapa nunca: pesa como toda la garra
		var n_up := _hits(up, samples) + (100 if _covers(up) else 0)
		var n_down := _hits(down, samples) + (100 if _covers(down) else 0) if down.size.x >= 160.0 and down.position.y > up.end.y else 1 << 20
		if side == "arriba" and n_down < n_up:
			side = "abajo"
		elif side == "abajo" and n_up <= n_down:
			side = "arriba"
	var r := down if side == "abajo" else up
	bubble.position = r.position
	bubble.size = Vector2(r.size.x, h)
	set_width(r.size.x)


## ¿Tapa el rectángulo el aro o su etiqueta?
func _covers(r: Rect2) -> bool:
	if _point.x < 0.0:
		return false
	var ring := Rect2(_point - Vector2.ONE * (RING_R + RING_GROW), Vector2.ONE * 2.0 * (RING_R + RING_GROW))
	return r.intersects(ring) or (tag.visible and r.intersects(Rect2(tag.position, tag.size)))


static func _hits(r: Rect2, pts: PackedVector2Array) -> int:
	var n := 0
	for p: Vector2 in pts:
		if r.has_point(p):
			n += 1
	return n


## El punto de la vista (px) de lo que se señala en la escena; (−1, −1): nada (un mando del panel, o no se ve).
func set_point(p: Vector2) -> void:
	var inside := p.x >= 0.0 and p.y >= 0.0 and p.x <= size.x and p.y <= size.y
	var q := p if inside else Vector2(-1.0, -1.0)
	if q.distance_squared_to(_point) < 0.25:
		return
	_point = q
	tag.visible = inside and tag_label.text != "" and _key != ""
	if tag.visible:
		var ts := tag.get_combined_minimum_size()
		var at := q + Vector2(RING_R + RING_GROW + 6.0, -ts.y * 0.5)
		if at.x + ts.x > size.x - 6.0:
			at.x = q.x - (RING_R + RING_GROW + 6.0) - ts.x
		at.y = clampf(at.y, 4.0, maxf(size.y - ts.y - 4.0, 4.0))
		at.x = clampf(at.x, 4.0, maxf(size.x - ts.x - 4.0, 4.0))
		tag.position = at
		tag.size = ts
	queue_redraw()


## Lo que se ve, para los tests: el aviso, su valor, la etiqueta y el punto.
func info() -> Dictionary:
	return { "visible": bubble.visible, "hint": hint_label.text, "value": value_label.text, "label": tag_label.text,
		"tag": tag.visible, "point": _point, "tone": _tone, "side": side, "rect": Rect2(bubble.position, bubble.size) }


func advance(dt: float) -> void:
	_t += dt
	if _point.x >= 0.0:
		queue_redraw()


func _draw() -> void:
	if _point.x < 0.0 or _key == "":
		return
	var k := 0.5 + 0.5 * sin(_t * PULSE)
	var c := Palette.color(_tone)
	draw_arc(_point, RING_R + RING_GROW * k, 0.0, TAU, 40, Color(0.05, 0.02, 0.07, 0.6), RING_W + 2.0, true)
	draw_arc(_point, RING_R + RING_GROW * k, 0.0, TAU, 40, Color(c, 0.55 + 0.4 * k), RING_W, true)
	draw_circle(_point, 2.5, Color(c, 0.95))
