## Selector segmentado (.seg de la 1.x): una sola opción activa. Emite `selected(id)` cuando se elige otra opción;
## la interfaz vuelve a marcar la activa con set_value() al leer el estado.
## Uso: var s := Segmented.new([{ "id": "a", "label": "A" }, { "id": "b", "label": "B", "title": "ayuda" }], "a", "Método")
extends PanelContainer

signal selected(id: String)

const Pill = preload("res://app/common/pill.gd")

var value := ""
var buttons := {}  # id → Button
var _row: HBoxContainer


func _init(options: Array = [], p_value := "", label := "") -> void:
	theme_type_variation = &"SegBox"
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	add_child(_row)
	var group := ButtonGroup.new()
	for o: Dictionary in options:
		var b := Pill.new(String(o.label), "SegButton")
		b.button_group = group
		b.tooltip_text = String(o.get("title", ""))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(String(o.id)))
		_row.add_child(b)
		buttons[String(o.id)] = b
	accessibility_name = label
	set_value(p_value)


## Marca la opción activa sin emitir nada.
func set_value(id: String) -> void:
	value = id
	for k: String in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)


## Cambia el texto de una opción (p. ej. al pasar de uña a garra).
func set_label(id: String, text: String) -> void:
	if buttons.has(id):
		(buttons[id] as Button).text = text


func _on_pressed(id: String) -> void:
	if id == value:
		set_value(id)
		return
	value = id
	selected.emit(id)
