## El corte de la chapa del coche con la marca (unidad 4s, petición de Eric del 17-10: «ver qué capas de la chapa del coche
## atraviesan»): las capas de la pintura y la carrocería una debajo de otra (Data.car_layers, a través de
## MovingCarState.tear_now: CarTear.cutaway) y el surco de la garra hasta donde llega, con el escalón del veredicto (marca,
## perfora, raja, abre) y las capas que corta. Lo usan la tarjeta (con los nombres) y el primer plano (pequeño, sin ellos).
## Solo dibujo: el alto de cada capa va en escala de raíz cuadrada (el barniz mide 45 µm y la chapa 700: a escala, la
## pintura no se vería); lo dice el rótulo.
extends Control

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")

## Alto (px) de la tarjeta y ancho de la columna del corte.
const H := 150.0
const CUT_W := 120.0
## Por debajo de este ancho (px), el porqué va debajo, en varias líneas (y la tarjeta crece NARROW_EXTRA px).
const NARROW := 480.0
const NARROW_EXTRA := 68.0
## Lo que se ve, de lo que llega del estado (tear_now): el escalón, el texto, las capas y la hondura.
var data: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, H)
	resized.connect(func() -> void:
		var want := H + (NARROW_EXTRA if size.x < NARROW else 0.0)
		if absf(custom_minimum_size.y - want) > 0.5:
			custom_minimum_size.y = want
		queue_redraw())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "Corte de la chapa con la marca de la garra"


## Pone lo que se enseña (un tear_now; {} lo esconde). Solo redibuja si cambia.
func set_data(t: Dictionary) -> void:
	var key := _key(t)
	if key == _key(data):
		return
	data = t
	visible = not t.is_empty() and int(t.get("level", 0)) > 0
	accessibility_description = String(t.get("text", ""))
	queue_redraw()


static func _key(t: Dictionary) -> String:
	if t.is_empty():
		return ""
	var states: Array = (t.get("layers", []) as Array).map(func(l: Dictionary) -> String: return String(l.state))
	return "%s|%s|%s|%s" % [t.get("id"), Js.to_fixed(float(t.get("lengthMm", 0.0)), 0), "".join(PackedStringArray(states)), t.get("text")]


## Dónde cae una hondura (µm) en el corte (0-1 de arriba abajo): raíz cuadrada de lo que hay hasta ella.
static func depth_frac(um: float, total_um: float) -> float:
	return sqrt(clampf(um, 0.0, total_um) / maxf(total_um, 1e-6))


## Dibuja el corte en rect: las capas, el surco hasta su capa (en V; atravesado, de lado a lado) y, con labels, los nombres.
static func draw_cut(ci: CanvasItem, rect: Rect2, t: Dictionary, font: Font, fs: int, labels: bool) -> void:
	var layers: Array = t.get("layers", [])
	if layers.is_empty():
		return
	var total := float((layers[-1] as Dictionary).to)
	var deepest := 0.0
	var through := false
	var k := 0
	for l: Dictionary in layers:
		var y0 := rect.position.y + depth_frac(float(l.from), total) * rect.size.y
		var y1 := rect.position.y + depth_frac(float(l.to), total) * rect.size.y
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, maxf(y1 - y0, 1.0)), Palette.color(String(l.col)))
		if l.state == "atravesada":
			through = true
			deepest = total
		elif l.state == "cortada":
			deepest = maxf(deepest, float(l.to))
		elif l.state == "marcada":
			deepest = maxf(deepest, (float(l.from) + float(l.to)) * 0.5)
		if labels:
			# los nombres, repartidos a lo alto (las capas de la pintura son finas), con una línea hasta su capa
			var col := "coral" if l.state == "atravesada" else ("gold" if l.state == "cortada" else ("rose" if l.state == "marcada" else "dimmer"))
			var name := "%s · %s" % [l.name, l.state]
			var ly := rect.position.y + (float(k) + 0.5) * rect.size.y / float(layers.size())
			var mid := (y0 + y1) * 0.5
			ci.draw_line(Vector2(rect.end.x + 1.0, mid), Vector2(rect.end.x + 10.0, ly), Color(Palette.color(col), 0.7), 1.0, true)
			ci.draw_string(font, Vector2(rect.end.x + 13.0, ly + fs * 0.35), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color(col))
		k += 1
	# el surco de la garra: una V hasta la hondura (la pared enseña las capas que corta); atravesado, un hueco de lado a lado
	var cx := rect.position.x + rect.size.x * 0.5
	var w := rect.size.x * (0.34 if through else 0.26)
	var yd := rect.position.y + depth_frac(deepest, total) * rect.size.y
	var hole := Color(0.03, 0.02, 0.04)
	if through:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5, rect.position.y), Vector2(cx + w * 0.5, rect.position.y),
			Vector2(cx + w * 0.22, rect.end.y), Vector2(cx - w * 0.22, rect.end.y)]), hole)
		# los labios de la chapa rota, doblados hacia dentro (pétalos)
		var lip := Palette.color("text")
		ci.draw_line(Vector2(cx - w * 0.22, rect.end.y), Vector2(cx - w * 0.5, rect.end.y + 8.0), lip, 2.0, true)
		ci.draw_line(Vector2(cx + w * 0.22, rect.end.y), Vector2(cx + w * 0.5, rect.end.y + 8.0), lip, 2.0, true)
	elif deepest > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5, rect.position.y), Vector2(cx + w * 0.5, rect.position.y),
			Vector2(cx, maxf(yd, rect.position.y + 2.0))]), hole)
	ci.draw_rect(rect, Color(Palette.color("text"), 0.5), false, 1.0)


func _draw() -> void:
	if data.is_empty():
		return
	var font := get_theme_default_font()
	var title: String = { "marca": "MARCA", "perfora": "PERFORA", "raja": "RAJA", "abre": "ABRE LA PUERTA" }.get(String(data.id), "")
	var col := "gold" if data.id == "marca" else "coral"
	if GLASS_TITLES.has(String(data.id)):  # unidad 4v: el corte del vidrio
		title = GLASS_TITLES[String(data.id)][0]
		col = GLASS_TITLES[String(data.id)][1]
	draw_string(font, Vector2(0.0, 14.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.color(col))
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var narrow := size.x < NARROW
	if narrow:
		# en un teléfono, el porqué debajo del corte, en varias líneas
		draw_multiline_string(font, Vector2(0.0, H + 18.0), String(data.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x, 11, 4,
			Palette.color("dim"))
	else:
		draw_string(font, Vector2(tw + 10.0, 14.0), String(data.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - tw - 10.0, 10.0), 11,
			Palette.color("dim"))
	var r := Rect2(4.0, 26.0, CUT_W * 0.45, H - 44.0)
	draw_cut(self, r, data, font, 11, true)
	# la nota del dibujo, corta en el teléfono (la larga se salía por la derecha y la pisaba el porqué de debajo)
	var note := "Corte (alto de cada capa: raíz de su espesor)" if narrow else "Corte de la chapa (alto de cada capa en raíz cuadrada de su espesor)"
	if bool(data.get("glass", false)) and not narrow:
		note = "Corte del vidrio (alto de cada capa en raíz cuadrada de su espesor)"  # unidad 4v
	draw_string(font, Vector2(0.0, H - 2.0), note, HORIZONTAL_ALIGNMENT_LEFT, size.x, 9, Palette.color("dimmer"))


# ════════ Cristales (unidad 4v) ════════
## El escalón del corte del vidrio (CarGlass.glass_cut, a través de MovingCarState.tear_now): título y color.
const GLASS_TITLES := {
	"mancha": ["NO LO RAYA", "mint"], "raya_vidrio": ["RAYA EL VIDRIO", "gold"], "agrieta": ["SE AGRIETA", "coral"],
	"estalla": ["ESTALLA", "coral"],
}
