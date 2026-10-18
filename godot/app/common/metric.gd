## Métrica del resultado (Metric de la 1.x): etiqueta en versalitas con su símbolo tal cual (χ, φ… no se pasan a
## mayúsculas para que no parezcan una X) y el valor debajo, del color que toque.
## Uso: var m := Metric.new(); m.set_data("Penetración", "χ = P/H", "0.123", Palette.color("coral"))
extends PanelContainer

const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")

var title: RichTextLabel
var value: Label
## Etiqueta sin formato (la busca quien lee la tarjeta: tests y lectores de pantalla).
var key := ""


func _init() -> void:
	theme_type_variation = &"Metric"
	var v := Ui.vbox(4)
	add_child(v)
	title = RichTextLabel.new()
	title.theme_type_variation = &"MetricTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(title)
	value = Ui.para("", "MetricValue")
	v.add_child(value)


func set_data(label: String, sym: String, val: String, color: Color) -> void:
	key = label
	var t := label.to_upper()
	if sym != "":
		# la barra del símbolo, pegada a lo que sigue (una unión de palabras, sin ancho ni glifo): en la casilla estrecha del
		# teléfono, «F/A» y «σ·Z/L» se partían por la barra
		t += " [font_size=12][color=#%s]%s[/color][/font_size]" % [Palette.color("dim").to_html(false), sym.replace("/", "/⁠")]
	title.text = t
	value.text = val
	value.add_theme_color_override("font_color", color)
	accessibility_name = "%s %s: %s" % [label, sym, val]
