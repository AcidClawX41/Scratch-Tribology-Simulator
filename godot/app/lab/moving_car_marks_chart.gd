## Gráfica del daño frente a la velocidad (unidad 4s; docs/fisica/coche-en-marcha.md §19): la hondura del surco de cada
## garra de 0 al tope del deslizador, sobre las capas del panel dibujadas a su espesor real (Data.car_layers: barniz, color,
## imprimación, anticorrosivo y la carrocería), con su banda sombreada (todo en contra y todo a favor), la punta clavada
## (la punción estática, punteada) cuando entra más que el surco, los hitos («raya el barniz», «llega a la chapa»,
## «atraviesa», «raja», «se rompen las garras» con su banda y «se suelta») y el punto de la velocidad del deslizador.
## Solo pinta lo que le da el estado (core/lab/moving_car_state.gd): la curva de CarSpeedMarks.curve y la lectura de
## CarSpeedMarks.at. Como la gráfica de las fuerzas (moving_car_chart.gd): la curva se pasa a píxeles una vez por ensayo y
## tamaño y se pinta en una capa quieta; el punto, en la suya, solo cuando cambia.
## Escala vertical: la pintura (110 µm) ocupa la mitad de arriba y la carrocería la mitad de abajo (dos tramos lineales): si
## no, la chapa de 700 µm aplastaría las capas de la pintura, que son lo que se raya casi siempre.
extends Control

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const CarFormat = preload("res://core/lab/car_format.gd")

const PAD_L := 44.0
const PAD_R := 10.0
const PAD_T := 22.0
const PAD_B := 20.0
const FONT_SIZE := 10
## Parte del alto para la pintura (el resto, la carrocería).
const PAINT_SHARE := 0.5

var curve: Dictionary = {}
var v_kmh := 0.0
var depth_um := 0.0
var punct_um := 0.0
var broken := false
var x_max := 230.0
var paint_um := 110.0
var panel_um := 810.0
## Métricas (las pruebas): veces que la curva se ha pasado a píxeles y dibujos de cada capa.
var builds := 0
var plot_draws := 0
var marker_draws := 0

var _plot: Control
var _marker: Control
var _depth := PackedVector2Array()
var _punct := PackedVector2Array()
var _band := PackedVector2Array()
var _band_idx := PackedInt32Array()
var _band_cols := PackedColorArray()
var _built_for := Vector2(-1.0, -1.0)
var _stale := true


func _init() -> void:
	custom_minimum_size = Vector2(0, 200)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "Gráfica: hondura de las marcas, punción y rotura de las garras según la velocidad del coche"
	_plot = Control.new()
	_plot.clip_contents = true
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	add_child(_plot)
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	resized.connect(_on_resized)


## La curva de CarSpeedMarks.curve ({} mientras no llega: «calculando…»).
func set_curve(p_curve: Dictionary) -> void:
	curve = p_curve
	if not curve.is_empty():
		x_max = float(curve.vMaxKmh)
		panel_um = maxf(float(curve.panelUm), 1.0)
		var layers: Array = curve.layers
		paint_um = float(layers[-1].from) if layers.size() >= 2 else panel_um * 0.5
	_stale = true
	queue_redraw()
	_plot.queue_redraw()
	_marker.queue_redraw()


## La lectura a la velocidad del deslizador (CarSpeedMarks.at). Solo se redibuja el punto, y solo si cambia.
func set_point(m: Dictionary) -> void:
	if m.is_empty():
		return
	var v := float(m.vKmh)
	var d := float(m.depthUm)
	var p := float(m.punctUm)
	var b := Js.truthy(m.broken)
	if v == v_kmh and d == depth_um and p == punct_um and b == broken:
		return
	v_kmh = v
	depth_um = d
	punct_um = p
	broken = b
	_marker.queue_redraw()


func _on_resized() -> void:
	_plot.position = Vector2(PAD_L, PAD_T)
	_plot.size = Vector2(maxf(size.x - PAD_L - PAD_R, 10.0), maxf(size.y - PAD_T - PAD_B, 10.0))
	_marker.position = _plot.position
	_marker.size = _plot.size
	queue_redraw()


func _x_px(v: float) -> float:
	return v / x_max * _plot.size.x


## La hondura en píxeles: la pintura en la mitad de arriba y la carrocería en la de abajo; lo que pasa del panel se queda
## en el borde de abajo.
func _y_px(um: float) -> float:
	var h := _plot.size.y
	var u := clampf(um, 0.0, panel_um)
	if u <= paint_um:
		return h * PAINT_SHARE * u / maxf(paint_um, 1e-9)
	return h * (PAINT_SHARE + (1.0 - PAINT_SHARE) * (u - paint_um) / maxf(panel_um - paint_um, 1e-9))


func _ensure_built() -> void:
	if not _stale and _built_for == _plot.size:
		return
	_stale = false
	_built_for = _plot.size
	builds += 1
	_depth = PackedVector2Array()
	_punct = PackedVector2Array()
	_band = PackedVector2Array()
	_band_idx = PackedInt32Array()
	if curve.is_empty():
		return
	var vs: PackedFloat64Array = curve.vKmh
	var ds: PackedFloat64Array = curve.depthUm
	var ps: PackedFloat64Array = curve.punctUm
	for i in vs.size():
		var x := _x_px(vs[i])
		_depth.append(Vector2(x, _y_px(ds[i])))
		_punct.append(Vector2(x, _y_px(ps[i])))
	# la banda: con todo en contra (lo, más hondo) arriba... es decir, más abajo en la gráfica; se interpola a las
	# velocidades de cada lado
	var lo: Dictionary = curve.lo
	var hi: Dictionary = curve.hi
	var n: int = lo.vKmh.size()
	for i in n:
		_band.append(Vector2(_x_px(lo.vKmh[i]), _y_px(lo.depthUm[i])))
	for i in n:
		_band.append(Vector2(_x_px(hi.vKmh[i]), _y_px(hi.depthUm[i])))
	for i in n - 1:
		_band_idx.append_array(PackedInt32Array([i, i + 1, n + i + 1, i, n + i + 1, n + i]))
	_band_cols = PackedColorArray()
	_band_cols.resize(2 * n)
	_band_cols.fill(Color(Palette.color("text"), 0.14))


func _draw() -> void:
	_ensure_built()
	var font := get_theme_default_font()
	var dim := Palette.color("dimmer")
	var line := Palette.color("line")
	var ps := _plot.size
	var o := _plot.position
	draw_rect(Rect2(o, ps), Color(Palette.color("bg"), 0.35))
	if curve.is_empty():
		draw_string(font, Vector2(o.x + 8.0, o.y + ps.y * 0.5), "calculando el daño a cada velocidad…", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
		return
	# las capas, como bandas a su espesor real, con sus nombres a la izquierda
	var layers: Array = curve.layers
	for l: Dictionary in layers:
		var y0 := o.y + _y_px(float(l.from))
		var y1 := o.y + _y_px(float(l.to))
		var col := Palette.color(String(l.col))
		draw_rect(Rect2(o.x, y0, ps.x, maxf(y1 - y0, 1.0)), Color(col, 0.22))
		draw_line(Vector2(o.x, y0), Vector2(o.x + ps.x, y0), Color(line, 0.6), 1.0)
		if y1 - y0 >= 11.0:
			draw_string(font, Vector2(0.0, y0 + 10.0), String(l.name).substr(0, 9), HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 6.0, FONT_SIZE, dim)
	# marcas de µm: 0, la pintura y el panel entero
	for um: float in [0.0, paint_um, panel_um]:
		var y := o.y + _y_px(um)
		draw_line(Vector2(o.x - 3.0, y), Vector2(o.x, y), line, 1.0)
	draw_string(font, Vector2(0.0, PAD_T - 8.0), "µm", HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 6.0, FONT_SIZE, dim)
	draw_string(font, Vector2(o.x + 2.0, o.y + ps.y - 3.0), CarFormat.fmt_panel(panel_um), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
	var every := 50.0 if ps.x >= 300.0 else 100.0
	var v := 0.0
	while v <= x_max + 1e-9:
		var x := o.x + _x_px(v)
		draw_line(Vector2(x, o.y + ps.y), Vector2(x, o.y + ps.y + 3.0), line, 1.0)
		if v < x_max and o.x + ps.x - x > 72.0:
			draw_string(font, Vector2(x - 20.0, o.y + ps.y + 15.0), Js.js_num_str(v), HORIZONTAL_ALIGNMENT_CENTER, 40.0, FONT_SIZE, dim)
		v += every
	draw_string(font, Vector2(o.x + ps.x - 90.0, o.y + ps.y + 15.0), "%s km/h" % Js.js_num_str(x_max), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, FONT_SIZE, dim)
	# leyenda
	var lx := o.x + 2.0
	var ly := PAD_T - 12.0
	for item: Array in [["text", "surco"], ["ice", "punta clavada"], ["coral", "se rompen"], ["gold", "se suelta"]]:
		var col := Palette.color(item[0])
		draw_line(Vector2(lx, ly), Vector2(lx + 14.0, ly), col, 2.0)
		var w := font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(lx + 18.0, ly + 4.0), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
		lx += 18.0 + w + 12.0


## Capa quieta: la banda, las curvas, los hitos (una raya vertical con su rótulo, por orden, en lo alto) y la rotura con su
## banda.
func _draw_plot() -> void:
	_ensure_built()
	plot_draws += 1
	if curve.is_empty() or _depth.size() < 2:
		return
	var c := _plot
	var ps := c.size
	var font := get_theme_default_font()
	var gold := Palette.color("gold")
	var coral := Palette.color("coral")
	# la rotura de las garras: su banda y su raya
	var br: Variant = curve.breakAt
	if br != null:
		var b0: Variant = br.minKmh
		var b1: Variant = br.maxKmh
		if b0 != null or br.kmh != null:
			var x0 := _x_px(float(b0) if b0 != null else float(br.kmh))
			var x1 := _x_px(minf(float(b1), x_max)) if b1 != null else ps.x
			c.draw_rect(Rect2(x0, 0.0, maxf(x1 - x0, 2.0), ps.y), Color(coral, 0.10))
		if br.kmh != null:
			var xb := _x_px(float(br.kmh))
			c.draw_dashed_line(Vector2(xb, 0.0), Vector2(xb, ps.y), coral, 2.0, 5.0)
	# el despegue (contando la rotura)
	var dk := float(curve.detachKmh)
	if is_finite(dk) and dk <= x_max:
		var xd := _x_px(dk)
		c.draw_dashed_line(Vector2(xd, 0.0), Vector2(xd, ps.y), gold, 2.0, 5.0)
		# lo que hay más allá ya no deja marca: se sombrea
		c.draw_rect(Rect2(xd, 0.0, ps.x - xd, ps.y), Color(Palette.color("bg"), 0.45))
	var item := c.get_canvas_item()
	if _band_idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(item, _band_idx, _band, _band_cols)
	c.draw_polyline(_punct, Color(Palette.color("ice"), 0.9), 1.5, true)
	c.draw_polyline(_depth, Palette.color("text"), 2.0, true)
	# la última de las capas, si todas llegan ya parado: el rótulo de la más honda (arriba a la izquierda, la fila 0)
	var deepest := ""
	for e: Dictionary in curve.events:
		if e.kmh != null and (e.kind == "capa" or e.kind == "cuerpo" or e.kind == "raja" or e.kind == "atraviesa") and float(e.kmh) < 0.5:
			deepest = String(e.label)
	# los hitos de las capas y del panel: una raya corta y su rótulo, cada uno en la primera fila donde no pisa al de antes
	# (row_end: dónde acaba el último rótulo de cada fila; antes iban por turno y en la fila del barniz se pisaban dos)
	var row_end: Array = [-1e9, -1e9, -1e9, -1e9]
	if deepest != "":
		var dtxt := "ya parado: %s" % deepest
		c.draw_string(font, Vector2(4.0, 12.0), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.color("text"))
		row_end[0] = 4.0 + font.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var last_x := -1e9
	for e: Dictionary in curve.events:
		if e.kmh == null or e.kind == "rompe" or e.kind == "suelta":
			continue
		var x := _x_px(float(e.kmh))
		if x - last_x < 6.0:
			continue  # el mismo punto (varias capas de golpe): el rótulo de la más honda ya lo dice
		last_x = x
		var col := Palette.color(String(e.col)) if String(e.col) != "" else coral
		c.draw_line(Vector2(x, 0.0), Vector2(x, ps.y), Color(col, 0.55), 1.0)
		var w := font.get_string_size(String(e.label), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var row := label_row(row_end, x + 3.0)
		row_end[row] = x + 3.0 + w + 4.0
		c.draw_string(font, Vector2(x + 3.0, 12.0 + 11.0 * float(row)), String(e.label), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.color("text"))
	if br != null and br.kmh != null:
		var xb := _x_px(float(br.kmh))
		c.draw_string(font, Vector2(xb + 3.0, ps.y - 6.0), "se rompen", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, coral)
	if is_finite(dk) and dk <= x_max:
		c.draw_string(font, Vector2(_x_px(dk) + 3.0, ps.y - 18.0), "se suelta", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, gold)


## La fila de un rótulo que empieza en x: la primera cuyo último rótulo acaba antes; si todas están ocupadas, la que acaba
## antes (row_end, dónde acaba el último rótulo de cada fila).
static func label_row(row_end: Array, x: float) -> int:
	var best := 0
	for i in row_end.size():
		if float(row_end[i]) <= x:
			return i
		if float(row_end[i]) < float(row_end[best]):
			best = i
	return best


func _draw_marker() -> void:
	marker_draws += 1
	if curve.is_empty():
		return
	var c := _marker
	var ps := c.size
	var x := _x_px(clampf(v_kmh, 0.0, x_max))
	c.draw_line(Vector2(x, 0.0), Vector2(x, ps.y), Color(Palette.color("rose"), 0.7), 1.0)
	if punct_um > depth_um + 0.5:
		c.draw_circle(Vector2(x, _y_px(punct_um)), 3.5, Palette.color("ice"), true, -1.0, true)
	var col := Palette.color("coral") if broken else Palette.color("text")
	c.draw_circle(Vector2(x, _y_px(depth_um)), 4.5, col, true, -1.0, true)
	if broken:
		c.draw_circle(Vector2(x, _y_px(depth_um)), 8.0, col, false, 1.5, true)
	var font := get_theme_default_font()
	var txt := Format.fmt_len(depth_um)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var tx := x + 8.0 if x + 8.0 + w < ps.x else x - 8.0 - w
	c.draw_string(font, Vector2(tx, _y_px(depth_um) - 7.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.color("text"))
