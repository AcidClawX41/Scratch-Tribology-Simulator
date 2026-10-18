## Balance de energía del golpe como barra apilada (docs/fisica/coche-en-marcha.md §2.10 y §9.6): los términos de
## MovingCar.impact(p).energy.terms en su orden fijo (garras, chapa o vidrio, animal, coche, rozamiento y salida), cada
## uno con el ancho de su parte (share) y su nombre corto (short) en la leyenda, con su tanto por ciento y su calidad (las
## estimaciones, marcadas). Solo pinta: set_terms(terms, total_txt).
## Uso: var e := MovingCarEnergy.new(); e.set_terms(hit.energy.terms, "34.8 kJ")
extends VBoxContainer

const Palette = preload("res://app/theme/palette.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const Ui = preload("res://app/common/ui.gd")

## Color de cada término (paleta única): lo que se queda la carrocería en tonos fríos, el calor en coral.
const COLORS := {
	"garras": "gold", "chapa": "ice", "vidrio": "ice", "animal": "rose", "coche": "mint", "rozamiento": "coral", "salida": "dim",
}
const MAX_TERMS := 6

var terms: Array = []
var bar: Control
var total: Label
var legend: HFlowContainer
## Por término: [muestra de color, texto].
var items: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total = Ui.para("", "Body")
	add_child(total)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	add_child(bar)
	legend = Ui.flow(12, 4)
	for i in MAX_TERMS:
		var row := Ui.hbox(6)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var l := Ui.label("", "Small")
		row.add_child(l)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		legend.add_child(row)
		items.append([row, sw, l])
	add_child(legend)
	accessibility_name = "Balance de energía del golpe"


## Los términos del balance (energy.terms) y el total ya con su formato.
func set_terms(p_terms: Array, total_txt: String) -> void:
	terms = p_terms
	total.text = total_txt
	for i in items.size():
		var it: Array = items[i]
		var row: Control = it[0]
		row.visible = i < terms.size()
		if not row.visible:
			continue
		var t: Dictionary = terms[i]
		(it[1] as ColorRect).color = color_of(String(t.id))
		var est := " (estimación)" if t.quality == "estimate" else ""
		(it[2] as Label).text = "%s %s%s" % [t.short, share_txt(float(t.share)), est]
		row.tooltip_text = "%s: %s" % [t.name, t.source]
	bar.queue_redraw()


static func color_of(id: String) -> Color:
	return Palette.color(String(COLORS.get(id, "dim")))


## Parte del total en tanto por ciento: sin decimales desde el 1 %, con uno por debajo, «<0.1 %» si hay algo pero no
## llega y «0 %» si no hay nada. El formato vive en el core (CarFormat.fmt_share).
static func share_txt(share: float) -> String:
	return CarFormat.fmt_share(share)


func _draw_bar() -> void:
	var w := bar.size.x
	var h := bar.size.y
	bar.draw_rect(Rect2(0, 0, w, h), Palette.color("panel3"))
	var x := 0.0
	for t: Dictionary in terms:
		var dw := w * clampf(float(t.share), 0.0, 1.0)
		if dw <= 0.0:
			continue
		bar.draw_rect(Rect2(x, 0, dw, h), color_of(String(t.id)))
		if t.quality == "estimate" and dw >= 6.0:
			# rayado a 45°, recortado al tramo: la parte estimada
			var k := 0.0
			while k < dw + h:
				var b := Vector2(x + k, h)
				var top := Vector2(x + k - h, 0.0)
				if b.x > x + dw:
					b = Vector2(x + dw, h - (b.x - x - dw))
				if top.x < x:
					top = Vector2(x, x - top.x)
				if b.y > top.y:
					bar.draw_line(b, top, Color(Palette.color("bg"), 0.35), 1.0)
				k += 6.0
		x += dw
	bar.draw_rect(Rect2(0, 0, w, h), Palette.color("line2"), false, 1.0)
