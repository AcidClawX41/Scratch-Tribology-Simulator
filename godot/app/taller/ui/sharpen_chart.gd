## Taller industrial · afiladora: gráfica de la temperatura del filo en el tiempo. Pinta la historia que da el
## simulador (el máximo del vértice en cada tramo), los ratos de contacto con la muela, y las líneas que da el core: el
## revenido de fábrica del acero, los 130 °C en los que el agua deja de enfriar y los 723 °C del quemado. Por encima de
## 723 °C la cifra no vale: la zona se rotula «quemado». Solo dibuja números del core.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")

const PAD_L := 44.0
const PAD_R := 10.0
const PAD_T := 22.0
const PAD_B := 22.0
const LINE_COLORS := { "revenido": "gold", "agua": "ice", "quemado": "coral" }

var history: Dictionary = {}
var lines: Array = []
var thermal := true
var burned := false
var note := ""


func _init() -> void:
	custom_minimum_size = Vector2(260, 150)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## La historia ({ t, c, on }), las líneas ([{ c, kind, label }]) y si hay temperatura que pintar.
func set_data(h: Dictionary, chart_lines: Array, has_thermal: bool, is_burned: bool, footnote: String = "") -> void:
	history = h
	lines = chart_lines
	thermal = has_thermal
	burned = is_burned
	note = footnote
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	var font := Style.font("mono")
	draw_string(font, Vector2(8, 14), "Temperatura del filo (°C) en el tiempo (s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("dimmer"))
	if not thermal:
		draw_string(font, Vector2(8, h * 0.55), "No se calcula la temperatura con esta herramienta.", HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, Style.c("dim"))
		return
	var ts: PackedFloat32Array = history.get("t", PackedFloat32Array())
	var cs: PackedFloat32Array = history.get("c", PackedFloat32Array())
	var on: PackedByteArray = history.get("on", PackedByteArray())
	var plot := Rect2(PAD_L, PAD_T, maxf(w - PAD_L - PAD_R, 10.0), maxf(h - PAD_T - PAD_B, 10.0))
	# Escalas: de 0 al máximo de lo visto (al menos 200 °C, y hasta el quemado con margen)
	var t_max := 5.0
	if ts.size() > 0:
		t_max = maxf(t_max, float(ts[ts.size() - 1]))
	var c_top := 200.0
	for c in cs:
		c_top = maxf(c_top, minf(c, 800.0) * 1.1)
	for ln in lines:
		if str(ln["kind"]) != "quemado":
			c_top = maxf(c_top, float(ln["c"]) * 1.08)  # que se vea la línea del revenido del acero
	c_top = minf(c_top, 820.0)
	var to_px := func(t: float, c: float) -> Vector2:
		return Vector2(plot.position.x + plot.size.x * clampf(t / t_max, 0.0, 1.0),
			plot.position.y + plot.size.y * (1.0 - clampf(c / c_top, 0.0, 1.0)))
	draw_rect(plot, Color(Style.c("panel"), 1.0))
	# Ratos de contacto con la muela
	var i := 0
	while i < ts.size():
		if i < on.size() and on[i] != 0:
			var j := i
			while j + 1 < ts.size() and j + 1 < on.size() and on[j + 1] != 0:
				j += 1
			var t_a := float(ts[i - 1]) if i > 0 else 0.0
			var x0: float = to_px.call(t_a, 0.0).x
			var x1: float = to_px.call(float(ts[j]), 0.0).x
			draw_rect(Rect2(x0, plot.position.y, maxf(x1 - x0, 1.0), plot.size.y), Color(Style.c("mint"), 0.08))
			i = j + 1
		else:
			i += 1
	# Zona del quemado
	if c_top > 723.0:
		var yq: float = to_px.call(0.0, 723.0).y
		draw_rect(Rect2(plot.position.x, plot.position.y, plot.size.x, yq - plot.position.y), Color(Style.c("coral"), 0.12))
		draw_string(font, Vector2(plot.position.x + 4.0, plot.position.y + 12.0), "quemado (> 723 °C): la cifra no vale", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("coral"))
	# Ejes y marcas
	draw_line(plot.position + Vector2(0, plot.size.y), plot.end, Style.c("line2"), 1.0)
	draw_line(plot.position, plot.position + Vector2(0, plot.size.y), Style.c("line2"), 1.0)
	for c_tick in _ticks(c_top):
		var y: float = to_px.call(0.0, c_tick).y
		draw_line(Vector2(plot.position.x - 3.0, y), Vector2(plot.position.x, y), Style.c("line2"), 1.0)
		draw_string(font, Vector2(4.0, y + 4.0), Fmt.num(c_tick, 0), HORIZONTAL_ALIGNMENT_LEFT, PAD_L - 8.0, 10, Style.c("dimmer"))
	for t_tick in _ticks(t_max):
		var x: float = to_px.call(t_tick, 0.0).x
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 3.0), Style.c("line2"), 1.0)
		draw_string(font, Vector2(x - 8.0, h - 6.0), Fmt.num(t_tick, 0 if t_tick >= 10.0 or t_max > 10.0 else 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dimmer"))
	# Líneas del core
	for ln in lines:
		var c := float(ln["c"])
		if c > c_top:
			continue
		var y: float = to_px.call(0.0, c).y
		var col := Style.c(str(LINE_COLORS.get(str(ln["kind"]), "dim")))
		_dashed(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(col, 0.85))
		var label := str(ln["label"])
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(plot.end.x - tw - 4.0, y - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	# La curva (recortada en 723 °C: por encima no es una temperatura)
	if ts.size() >= 2:
		var pts := PackedVector2Array()
		for k in ts.size():
			pts.append(to_px.call(float(ts[k]), minf(float(cs[k]), 760.0)))
		draw_polyline(pts, Style.c("text"), 2.0, true)
	elif ts.size() == 1:
		draw_circle(to_px.call(float(ts[0]), float(cs[0])), 2.5, Style.c("text"))
	if note != "":
		draw_string(font, Vector2(plot.position.x + 4.0, plot.end.y - 6.0), note, HORIZONTAL_ALIGNMENT_LEFT, plot.size.x - 8.0, 10, Style.c("dim"))


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 1e-6)
	var s := 0.0
	while s < length:
		draw_line(a + dir * s, a + dir * minf(s + 6.0, length), col, 1.0)
		s += 10.0


## Marcas «redondas» de un eje de 0 a top.
static func _ticks(top: float) -> Array:
	var steps := [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0]
	var step := 1000.0
	for s in steps:
		if top / s <= 6.0:
			step = s
			break
	var out := []
	var v := step
	while v <= top + 1e-9:
		out.append(v)
		v += step
	return out
