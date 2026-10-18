## Taller industrial · gráfica de un barrido (unidad 1e): la curva y = f(x) que calcula MillDrillState en hilos (potencia
## en el motor frente a ae, empuje frente al avance…), el punto del ensayo actual y, si la hay, la línea del límite de la
## máquina. Solo dibuja los números que recibe; las marcas de los ejes redondean la escala, no calculan física.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")

const PAD_L := 58.0
const PAD_R := 14.0
const PAD_T := 26.0
const PAD_B := 36.0

var xs := PackedFloat64Array()
var ys: Array = []  # float o null (el modelo no pudo calcular ese punto)
var over: Array = []  # bool: sobrecarga en ese punto
var current := Vector2(NAN, NAN)  # ensayo actual (x de la entrada, y del resultado)
var limit := NAN  # límite de la máquina (en unidades de y) o NAN
var title := ""
var x_label := ""
var y_unit := ""
var limit_label := ""
var x_dec := 1
var y_dec := 1
var pending := false
var empty_note := "Calculando el barrido…"


func _init() -> void:
	custom_minimum_size = Vector2(260, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## d: { xs, ys, over, current: Vector2, limit, title, x_label, y_unit, limit_label, x_dec, y_dec, pending }.
func set_data(d: Dictionary) -> void:
	xs = d.get("xs", PackedFloat64Array())
	ys = d.get("ys", [])
	over = d.get("over", [])
	current = d.get("current", Vector2(NAN, NAN))
	limit = float(d.get("limit", NAN))
	title = str(d.get("title", ""))
	x_label = str(d.get("x_label", ""))
	y_unit = str(d.get("y_unit", ""))
	limit_label = str(d.get("limit_label", ""))
	x_dec = int(d.get("x_dec", 1))
	y_dec = int(d.get("y_dec", 1))
	pending = bool(d.get("pending", false))
	queue_redraw()


## Número de puntos con valor (para los tests).
func valid_points() -> int:
	var n := 0
	for y in ys:
		if y != null and not is_nan(float(y)) and not is_inf(float(y)):
			n += 1
	return n


func _draw() -> void:
	var font := Style.font("mono")
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	draw_string(font, Vector2(10, 17), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 12, Style.c("text"))
	var plot := Rect2(PAD_L, PAD_T, maxf(size.x - PAD_L - PAD_R, 10.0), maxf(size.y - PAD_T - PAD_B, 10.0))
	if xs.size() < 2 or valid_points() < 2:
		draw_string(font, plot.position + Vector2(8, plot.size.y / 2.0), empty_note if pending or xs.is_empty() else "Sin datos: el modelo no calcula este barrido con este material.", HORIZONTAL_ALIGNMENT_LEFT, plot.size.x - 16.0, 11, Style.c("dimmer"))
		return
	var x0 := xs[0]
	var x1 := xs[xs.size() - 1]
	var ymax := 0.0
	for y in ys:
		if y != null and not is_inf(float(y)):
			ymax = maxf(ymax, float(y))
	if not is_nan(limit):
		ymax = maxf(ymax, limit)
	if not is_nan(current.y) and not is_inf(current.y):
		ymax = maxf(ymax, current.y)
	var ystep := _nice_step(ymax / 4.0)
	var ytop := ystep * ceilf(ymax * 1.08 / ystep) if ystep > 0.0 else 1.0
	# Rejilla y marcas
	var grid_col := Color(Style.c("line"), 0.9)
	var k := 0
	while k * ystep <= ytop + 1e-12 and k < 12:
		var yv := k * ystep
		var py := _py(yv, plot, ytop)
		draw_line(Vector2(plot.position.x, py), Vector2(plot.end.x, py), grid_col, 1.0)
		var lbl := Fmt.num(yv, _dec_for(ystep, y_dec))
		var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(plot.position.x - tw - 6.0, py + 4.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dimmer"))
		k += 1
	var xstep := _nice_step((x1 - x0) / 4.0)
	if xstep > 0.0:
		var xv := ceilf(x0 / xstep) * xstep
		var guard := 0
		while xv <= x1 + 1e-9 and guard < 12:
			var px := _px(xv, plot, x0, x1)
			draw_line(Vector2(px, plot.end.y), Vector2(px, plot.end.y + 4.0), Style.c("line2"), 1.0)
			var lbl := Fmt.num(xv, _dec_for(xstep, x_dec))
			var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(font, Vector2(px - tw / 2.0, plot.end.y + 15.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dimmer"))
			xv += xstep
			guard += 1
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), Style.c("line2"), 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, Style.c("line2"), 1.0)
	draw_string(font, Vector2(plot.position.x, size.y - 5.0), x_label, HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, 10, Style.c("dim"))
	draw_string(font, Vector2(4.0, PAD_T - 5.0 + 12.0), y_unit, HORIZONTAL_ALIGNMENT_LEFT, PAD_L - 8.0, 10, Style.c("dim"))
	# Límite de la máquina (discontinuo)
	if not is_nan(limit) and limit > 0.0:
		var ly := _py(limit, plot, ytop)
		var xx := plot.position.x
		while xx < plot.end.x:
			draw_line(Vector2(xx, ly), Vector2(minf(xx + 7.0, plot.end.x), ly), Style.c("coral"), 1.5)
			xx += 12.0
		draw_string(font, Vector2(plot.position.x + 6.0, ly - 4.0), limit_label, HORIZONTAL_ALIGNMENT_LEFT, plot.size.x - 12.0, 10, Style.c("coral"))
	# Curva: los tramos con sobrecarga, en coral
	for i in range(1, xs.size()):
		var a: Variant = ys[i - 1]
		var b: Variant = ys[i]
		if a == null or b == null or is_inf(float(a)) or is_inf(float(b)):
			continue
		var pa := Vector2(_px(xs[i - 1], plot, x0, x1), _py(float(a), plot, ytop))
		var pb := Vector2(_px(xs[i], plot, x0, x1), _py(float(b), plot, ytop))
		var bad := i < over.size() and bool(over[i]) and bool(over[i - 1])
		draw_line(pa, pb, Style.c("coral") if bad else Style.c("mint"), 2.0, true)
	# Ensayo actual (el barrido llega siempre hasta él; si no, no se pinta en un sitio que no es el suyo)
	var tol := (x1 - x0) * 1e-6
	if not is_nan(current.x) and not is_nan(current.y) and not is_inf(current.y) and current.x >= x0 - tol and current.x <= x1 + tol:
		var cx := _px(current.x, plot, x0, x1)
		var cy := _py(current.y, plot, ytop)
		draw_line(Vector2(cx, plot.end.y), Vector2(cx, cy), Color(Style.c("gold"), 0.5), 1.0)
		draw_circle(cx * Vector2.RIGHT + cy * Vector2.DOWN, 5.0, Style.c("gold"))
		draw_arc(Vector2(cx, cy), 7.5, 0.0, TAU, 20, Color(Style.c("gold"), 0.6), 1.0, true)
	# Leyenda del tramo en rojo: la potencia en el motor pasa de la de la máquina
	if over.has(true):
		var t := "en rojo: sobrecarga del motor"
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(plot.end.x - tw, PAD_T + 10.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("coral"))
	if pending:
		draw_string(font, Vector2(size.x - 104.0, 17.0), "actualizando…", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dimmer"))


func _px(x: float, plot: Rect2, x0: float, x1: float) -> float:
	return plot.position.x + (x - x0) / maxf(x1 - x0, 1e-12) * plot.size.x


func _py(y: float, plot: Rect2, ytop: float) -> float:
	return plot.end.y - clampf(y / maxf(ytop, 1e-12), 0.0, 1.05) * plot.size.y


## Paso «redondo» (1, 2 o 5 por una potencia de 10) de una escala.
static func _nice_step(raw: float) -> float:
	if raw <= 0.0 or is_nan(raw) or is_inf(raw):
		return 0.0
	var mag := pow(10.0, floorf(log(raw) / log(10.0)))
	var r := raw / mag
	var m := 1.0 if r <= 1.0 else (2.0 if r <= 2.0 else (5.0 if r <= 5.0 else 10.0))
	return m * mag


## Decimales para las marcas de un paso: los justos para que no se repitan.
static func _dec_for(step: float, max_dec: int) -> int:
	var d := 0
	while d < 4 and absf(step * pow(10.0, d) - roundf(step * pow(10.0, d))) > 1e-6:
		d += 1
	return mini(maxi(d, 0), maxi(max_dec, d))
