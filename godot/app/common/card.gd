## Tarjeta (Card de la 1.x): panel redondeado con cabecera (número de paso, título y un hueco a la derecha) y el
## contenido debajo. Si la cabecera no cabe en una fila (teléfono), el hueco de la derecha baja bajo el título.
## Uso: var c := Card.new("Herramienta", "1"); c.right.add_child(selector); c.body.add_child(contenido)
extends PanelContainer

const Ui = preload("res://app/common/ui.gd")
const WrapBox = preload("res://app/common/wrap_box.gd")

var body: VBoxContainer
var header: Container
var title_label: Label
var right: HBoxContainer


func _init(title := "", step := "") -> void:
	theme_type_variation = &"Card"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Ui.vbox(12)
	add_child(col)
	var head := WrapBox.new(10.0, 10.0)
	header = head
	var left := Ui.hbox(9)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if step != "":
		var s := Ui.label(step, "StepBadge")
		s.custom_minimum_size = Vector2(26, 26)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		left.add_child(s)
	title_label = Ui.label(title, "CardTitle")
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(title_label)
	head.add_child(left)
	right = Ui.hbox(8)
	right.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(right)
	col.add_child(head)
	header.visible = title != "" or step != ""
	body = Ui.vbox(8)
	col.add_child(body)
	accessibility_name = title
