## Píldora (.pill de la 1.x): botón de texto que se queda pulsado cuando su opción está elegida, con ayuda emergente
## de varias líneas. Puede llevar un icono pequeño (muestra de color, gema) delante del texto.
## Uso: var p := Pill.new("Uña natural"); p.pressed.connect(…); p.set_on(true)
extends Button

const Ui = preload("res://app/common/ui.gd")


func _init(label_text := "", variation := "Pill", toggle := true) -> void:
	text = label_text
	theme_type_variation = StringName(variation)
	toggle_mode = toggle
	focus_mode = Control.FOCUS_ALL


func set_on(v: bool) -> void:
	set_pressed_no_signal(v)


func _make_custom_tooltip(for_text: String) -> Object:
	return Ui.tooltip(for_text)
