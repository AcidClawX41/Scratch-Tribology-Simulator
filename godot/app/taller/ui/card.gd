## Taller industrial · tarjeta: el mismo lenguaje visual que las tarjetas de la 1.x (panel redondeado, título en
## Syne y cuerpo con los datos). body es el contenedor de lo que lleve dentro.
extends PanelContainer

const Style = preload("res://app/taller/ui/style.gd")

var title_label: Label
var hint_label: Label
var body: VBoxContainer


func _init(title: String = "", hint: String = "") -> void:
	theme_type_variation = "TallerTarjetaPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	title_label = Style.label(title, "TallerTarjeta")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title_label)
	hint_label = Style.label(hint, "TallerNota")
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.visible = hint != ""
	head.add_child(hint_label)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	col.add_child(body)


func set_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = text != ""
