## Botón con contenido propio (ilustración y varios textos), que se dimensiona según ese contenido: las fichas
## (.tile), las píldoras con gema, las filas de la comparativa y el botón de fuerza máxima. Conserva lo de un Button
## (foco, teclado, grupo, pulsado, ayuda emergente) y pinta sus estilos del tema. Los textos principales siguen el
## color del estado del botón (normal, encima, pulsado); los secundarios, dimmer o dim si está pulsado (.tile-sub).
## Uso: var b := ContentButton.new("Tile"); b.set_body(caja); b.main_labels.append(etiqueta)
extends Button

const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")

var content: MarginContainer
var main_labels: Array[Label] = []
var sub_labels: Array[Label] = []
var sub_colors := ["dimmer", "dim"]


func _init(variation := "Tile", toggle := true) -> void:
	theme_type_variation = StringName(variation)
	toggle_mode = toggle
	content = MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.minimum_size_changed.connect(_sync_min)
	mouse_entered.connect(_restyle)
	mouse_exited.connect(_restyle)
	toggled.connect(_on_toggled)


## Pone el contenido (una sola vez) y le quita el ratón para que los clics lleguen al botón.
func set_body(node: Control) -> void:
	content.add_child(node)
	Ui.ignore_mouse(node)
	_apply_margins()
	_restyle()


## Estado pulsado sin emitir señales (la interfaz lo sincroniza con el banco).
func set_on(v: bool) -> void:
	set_pressed_no_signal(v)
	_restyle()


func _on_toggled(_on: bool) -> void:
	_restyle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_apply_margins()
		_restyle()


func _apply_margins() -> void:
	var sb := get_theme_stylebox(&"normal")
	if sb == null:
		return
	content.add_theme_constant_override("margin_left", int(sb.get_margin(SIDE_LEFT)))
	content.add_theme_constant_override("margin_top", int(sb.get_margin(SIDE_TOP)))
	content.add_theme_constant_override("margin_right", int(sb.get_margin(SIDE_RIGHT)))
	content.add_theme_constant_override("margin_bottom", int(sb.get_margin(SIDE_BOTTOM)))
	_sync_min()


func _restyle() -> void:
	var item := &"font_color"
	if disabled:
		item = &"font_disabled_color"
	elif button_pressed:
		item = &"font_hover_pressed_color" if is_hovered() else &"font_pressed_color"
	elif is_hovered():
		item = &"font_hover_color"
	var col := get_theme_color(item)
	for l in main_labels:
		l.add_theme_color_override("font_color", col)
	var sub := Palette.color(sub_colors[1] if button_pressed else sub_colors[0])
	for l in sub_labels:
		l.add_theme_color_override("font_color", sub)


func _sync_min() -> void:
	custom_minimum_size = content.get_combined_minimum_size()


func _make_custom_tooltip(for_text: String) -> Object:
	return Ui.tooltip(for_text)
