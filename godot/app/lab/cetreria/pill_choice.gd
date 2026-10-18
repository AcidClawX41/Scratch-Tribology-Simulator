## Cetrería · una sola opción activa entre píldoras que pasan a la línea siguiente si no caben (en el teléfono, el
## selector segmentado de app/common/segmented.gd no cabe con cuatro opciones largas). La misma API que Segmented:
## `selected(id)` al elegir otra, set_value() para marcar la del estado sin emitir y set_label() para cambiar un texto.
## Uso: var c := PillChoice.new([{ "id": "a", "label": "A", "title": "ayuda" }], "a", "Sujeción")
extends HFlowContainer

signal selected(id: String)

const Pill = preload("res://app/common/pill.gd")

var value := ""
var buttons := {}  # id → Button


func _init(options: Array = [], p_value := "", label := "") -> void:
	add_theme_constant_override("h_separation", 5)
	add_theme_constant_override("v_separation", 5)
	var group := ButtonGroup.new()
	for o: Dictionary in options:
		var b := Pill.new(String(o.label))
		b.button_group = group
		b.tooltip_text = String(o.get("title", ""))
		b.accessibility_name = "%s: %s" % [label, String(o.label)] if label != "" else String(o.label)
		b.pressed.connect(_on_pressed.bind(String(o.id)))
		add_child(b)
		buttons[String(o.id)] = b
	accessibility_name = label
	set_value(p_value)


## Marca la opción activa sin emitir nada.
func set_value(id: String) -> void:
	value = id
	for k: String in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)


## Cambia el texto de una opción (y su nombre para los lectores de pantalla).
func set_label(id: String, text: String) -> void:
	if buttons.has(id):
		var b: Button = buttons[id]
		b.text = text
		b.accessibility_name = "%s: %s" % [String(accessibility_name), text] if String(accessibility_name) != "" else text


func _on_pressed(id: String) -> void:
	if id == value:
		set_value(id)
		return
	value = id
	selected.emit(id)
