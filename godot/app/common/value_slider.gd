## Deslizador con cabecera (Slider de la 1.x): nombre y pista a la izquierda, valor en rosa a la derecha, y la
## pista rellena hasta el valor. Emite `value_changed(v)` al moverlo; set_value() lo coloca sin emitir.
## Uso: var s := ValueSlider.new("Fuerza", "(escala log)", 0.0, 1.0, 0.004)
extends VBoxContainer

signal value_changed(v: float)

const Ui = preload("res://app/common/ui.gd")

var slider: HSlider
var display: Label
var name_label: Label


func _init(label: String = "", hint := "", min_v := 0.0, max_v := 1.0, step := 0.01) -> void:
	add_theme_constant_override("separation", 8)
	var head := Ui.hbox(6)
	name_label = Ui.label(label, "SliderLabel")
	head.add_child(name_label)
	if hint != "":
		head.add_child(Ui.label(hint, "SliderLabel", "dimmer"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	display = Ui.label("", "Display")
	head.add_child(display)
	add_child(head)
	slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size.y = 24.0
	slider.focus_mode = Control.FOCUS_ALL
	# la rueda del ratón desplaza el panel, no el deslizador: al bajar por un panel con la rueda, el deslizador que
	# pasaba por debajo del puntero cambiaba sin querer (el de los días sin desgaste empezaba una garra nueva: fallo de
	# Eric en la cetrería). Se mueve arrastrando, con un clic en la pista o con las flechas del teclado
	slider.scrollable = false
	slider.accessibility_name = label
	slider.value_changed.connect(_on_value)
	add_child(slider)


func _on_value(v: float) -> void:
	value_changed.emit(v)


## Posición del deslizador, texto del valor y descripción para lectores de pantalla (aria-valuetext).
func set_value(v: float, text: String, value_text := "") -> void:
	slider.set_value_no_signal(v)
	display.text = text
	if value_text != "":
		slider.accessibility_description = value_text
