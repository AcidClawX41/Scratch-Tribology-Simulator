## Cetrería · la barra del estado del animal y de lo que se está haciendo (unidad 5o, petición 51), de lado a lado encima de la
## vista 3D, siempre visible («como una barra de vida de un videojuego», Eric):
##   - una barra por medida (el estrés, la sangre perdida y el calor de la carne viva), cada una con su límite permitido marcado,
##     su color (verde dentro, ámbar cerca, rojo fuera), su etiqueta corta y su valor, y una ayuda emergente con el porqué y qué
##     hacer (ClawCareState.animal_view);
##   - la línea de lo que se está haciendo, con su cuenta y una barra que se llena hasta el 100 % justo al acabar, lo que hay que
##     mantener pulsado, «Listo: ya puedes soltar», «Has soltado antes de tiempo…» y el tiempo de verdad con el reloj acelerado
##     (ClawCareState.activity_view).
## Solo pinta la vista: no calcula nada. Repinta solo si cambia.
## Uso: var b := CareStatusBar.new(); b.paint(v.animal.meters, v.activity)
extends PanelContainer

const Ui = preload("res://app/common/ui.gd")
const Palette = preload("res://app/theme/palette.gd")
const CareMeter = preload("res://app/lab/cetreria/care_meter.gd")

const TONE_TEXT := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "dim" }

var compact := false
var meters_row: GridContainer
var meters := {}  # id → { box, head, label, value, bar }
var act_label: Label
var act_bar: CareMeter
var act_real: Label
var _animal: Array = []
var _key := ""


func _init() -> void:
	name = "EstadoDelAnimal"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.color("bg2"), 0.96)
	sb.border_color = Palette.color("line")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", sb)
	var col := Ui.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	meters_row = GridContainer.new()
	meters_row.columns = 3
	meters_row.add_theme_constant_override("h_separation", 12)
	meters_row.add_theme_constant_override("v_separation", 2)
	meters_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(meters_row)
	var arow := Ui.hbox(8)
	arow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_label = Ui.para("", "Small", "text")
	act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arow.add_child(act_label)
	act_bar = CareMeter.new(6.0)
	act_bar.custom_minimum_size.x = 90.0
	act_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	arow.add_child(act_bar)
	col.add_child(arow)
	act_real = Ui.para("", "Small", "dim")
	act_real.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(act_real)
	accessibility_name = "Estado del animal y lo que se está haciendo"


## Un indicador nuevo (la primera vez que llega su medida).
func _meter(id: String) -> Dictionary:
	if meters.has(id):
		return meters[id]
	var box := Ui.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	# (un BoxContainer a secas: a los HBox/VBox no se les puede cambiar la orientación, y en el teléfono va en vertical)
	var head := BoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := Ui.label("", "Small", "dim")
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(lab)
	var val := Ui.label("", "Small", "text")
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.clip_text = true
	val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(val)
	box.add_child(head)
	var bar := CareMeter.new(8.0)
	box.add_child(bar)
	meters_row.add_child(box)
	var e := { "box": box, "head": head, "label": lab, "value": val, "bar": bar }
	meters[id] = e
	_lay_meter(e)
	return e


## En el teléfono (compacto) no caben tres medidas con su etiqueta y su valor en una fila: la etiqueta va encima del valor.
func set_compact(c: bool) -> void:
	if c == compact:
		return
	compact = c
	for id: String in meters:
		_lay_meter(meters[id])
	_paint_values()


func _lay_meter(e: Dictionary) -> void:
	(e.head as BoxContainer).vertical = compact
	(e.value as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT


## Cada medida: en el teléfono, su texto corto (`short`: caben unos 15 caracteres por medida); el completo, en la ayuda.
func _paint_values() -> void:
	for m: Dictionary in _animal:
		var e := _meter(String(m.id))
		(e.label as Label).text = String(m.label)
		(e.value as Label).text = String(m.get("short", m.text)) if compact else String(m.text)
		Ui.set_color(e.value, String(TONE_TEXT.get(String(m.tone), "dim")))
		(e.bar as CareMeter).set_state(float(m.value), float(m.limit), String(m.tone))
		# el límite, con su fuente y su calidad (estimación, dato medido…)
		var src := String(m.get("source", ""))
		var tip := String(m.tip) + ("\nLímite (%s): %s" % [String(m.get("quality_text", "")), src] if src != "" else "")
		(e.box as Control).tooltip_text = "%s. %s" % [String(m.text), tip] if compact else tip
		(e.box as Control).accessibility_name = "%s: %s. %s" % [String(m.label), String(m.text), String(m.tip)]


## Pinta el estado del animal (ClawCareState.animal_view) y lo que se está haciendo (activity_view).
func paint(animal: Array, activity: Dictionary) -> void:
	var key := var_to_str(animal) + var_to_str(activity)
	if key == _key:
		return
	_key = key
	_animal = animal
	_paint_values()
	var text := String(activity.get("text", ""))
	act_label.text = text
	act_label.visible = text != ""
	Ui.set_color(act_label, String(TONE_TEXT.get(String(activity.get("tone", "")), "text")) if String(activity.get("tone", "")) != "" else "text")
	var f := float(activity.get("frac", -1.0))
	act_bar.visible = f >= 0.0
	if f >= 0.0:
		act_bar.set_state(f, -1.0, "bien" if bool(activity.get("ready", false)) or f >= 1.0 else ("mal" if String(activity.get("tone", "")) == "mal" else "aviso"))
	var real := String(activity.get("real", ""))
	act_real.text = real
	act_real.visible = real != ""
