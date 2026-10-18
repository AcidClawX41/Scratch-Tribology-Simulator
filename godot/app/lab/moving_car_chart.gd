## Gráfica en directo del coche en marcha (docs/fisica/coche-en-marcha.md §9.5): la fuerza necesaria (viento, inercia y
## cuesta) frente a la disponible (fricción y anclaje) de 0 al tope del coche (230 km/h en el turismo; la velocidad máxima del deportivo), en N; sus bandas sombreadas (con todos los
## datos en contra y con todos a favor); la velocidad de despegue con su banda y el punto de la velocidad del
## deslizador. Solo pinta lo que le da el estado (core/lab/moving_car_state.gd): la curva de MovingCar.curve y las
## fuerzas de at_speed.
## - set_curve(curve, det, note) al cambiar el ensayo o el aire: la curva se pasa a píxeles una vez (y al cambiar de
##   tamaño) y se pinta en una capa quieta, que no se vuelve a dibujar mientras no cambie;
## - set_point(v, need, avail, holds) en cada fotograma del deslizador: solo se redibuja la capa del punto, y solo si
##   ha cambiado.
## Tres capas: la gráfica (marcas, leyenda), el área de las curvas (recortada: una curva que se sale por arriba se corta
## en el borde, no se aplasta contra él) y el punto. Las bandas son listas de triángulos (sin triangular polígonos, que
## fallan con bandas de ancho cero).
extends Control

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")

## Tope del eje (km/h): el del deslizador del coche elegido (set_curve: el último punto de la curva; 230 en el turismo, la
## velocidad máxima del deportivo, unidad 4r).
var x_max: float = MovingCar.SLIDER_MAX_KMH
## Márgenes del área de las curvas (px): a la izquierda, las marcas de N; abajo, las de km/h; arriba, la leyenda.
const PAD_L := 44.0
const PAD_R := 10.0
const PAD_T := 22.0
const PAD_B := 20.0
const FONT_SIZE := 10

var curve: Dictionary = {}
var det: Dictionary = {}
## Texto del despegue cuando cae fuera del eje («se soltaría hacia ~196 km/h»).
var note := ""
## Despegue con el aire de referencia (20 °C al nivel del mar, hold_report.detachRef): una línea tenue para comparar
## cuando el aire elegido es otro; INF sin referencia.
var ref_kmh := INF
var v_kmh := 0.0
var need := 0.0
var avail := 0.0
var holds := true
## Escala vertical (N) y paso de sus marcas.
var y_max := 1.0
var y_step := 1.0
## Métricas: veces que la curva se ha pasado a píxeles (una por ensayo y tamaño) y dibujos de cada capa.
var builds := 0
var plot_draws := 0
var marker_draws := 0

var _plot: Control
var _marker: Control
var _need := PackedVector2Array()
var _avail := PackedVector2Array()
var _band_idx := PackedInt32Array()
var _need_band := PackedVector2Array()
var _avail_band := PackedVector2Array()
var _need_cols := PackedColorArray()
var _avail_cols := PackedColorArray()
var _built_for := Vector2(-1.0, -1.0)
var _stale := true


func _init() -> void:
	custom_minimum_size = Vector2(0, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "Gráfica: fuerza necesaria frente a disponible según la velocidad del coche"
	_plot = Control.new()
	_plot.clip_contents = true
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	add_child(_plot)
	# el punto va encima del área, sin recortar: en 0 y en 150 km/h se ve entero
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	resized.connect(_on_resized)


## La curva de MovingCar.curve (PackedFloat64Array de 0 a 150 km/h), el despegue (detach), el texto del despegue si
## cae fuera del eje y el despegue con el aire de referencia (INF si no hay que enseñarlo).
func set_curve(p_curve: Dictionary, p_det: Dictionary, p_note: String, p_ref_kmh := INF) -> void:
	curve = p_curve
	det = p_det
	var vs: PackedFloat64Array = p_curve.get("vKmh", PackedFloat64Array())
	if not vs.is_empty() and vs[-1] > 0.0:
		x_max = vs[-1]
	note = p_note
	ref_kmh = p_ref_kmh
	_stale = true
	queue_redraw()
	_plot.queue_redraw()
	_marker.queue_redraw()


## El despegue con el aire de referencia (llega de un hilo con hold_report): solo se redibuja la capa quieta si cambia.
func set_ref(p_ref_kmh: float) -> void:
	if p_ref_kmh == ref_kmh:
		return
	ref_kmh = p_ref_kmh
	_plot.queue_redraw()


## La velocidad del deslizador y las fuerzas a esa velocidad (at_speed). Solo se redibuja el punto, y solo si cambia.
func set_point(p_v: float, p_need: float, p_avail: float, p_holds: bool) -> void:
	if p_v == v_kmh and p_need == need and p_avail == avail and p_holds == holds:
		return
	v_kmh = p_v
	need = p_need
	avail = p_avail
	holds = p_holds
	_marker.queue_redraw()


func _on_resized() -> void:
	_plot.position = Vector2(PAD_L, PAD_T)
	_plot.size = Vector2(maxf(size.x - PAD_L - PAD_R, 10.0), maxf(size.y - PAD_T - PAD_B, 10.0))
	_marker.position = _plot.position
	_marker.size = _plot.size
	queue_redraw()


## Paso «bonito» (1, 2, 2,5 o 5 por una potencia de 10) para unas cuatro marcas.
static func nice_step(span: float, ticks := 4) -> float:
	if span <= 0.0 or not is_finite(span):
		return 1.0
	var raw := span / float(ticks)
	var mag := pow(10.0, floorf(log(raw) / log(10.0)))
	for m: float in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if raw <= m * mag * (1.0 + 1e-9):
			return m * mag
	return 10.0 * mag


## Escala vertical: la fuerza disponible del caso central y la necesaria hasta el doble de esa, con un poco de aire. Las
## bandas y la curva necesaria que pasen de ahí se recortan en el borde.
static func y_scale(c: Dictionary) -> Dictionary:
	var a := 0.0
	var n := 0.0
	for x: float in c.get("avail", PackedFloat64Array()):
		a = maxf(a, x)
	for x: float in c.get("need", PackedFloat64Array()):
		n = maxf(n, x)
	var ref := maxf(a, minf(n, 2.0 * a)) if a > 0.0 else n
	ref = maxf(ref * 1.15, 1.0)
	var step := nice_step(ref)
	return { "max": ceilf(ref / step - 1e-9) * step, "step": step }


func _x_px(v: float) -> float:
	return v / x_max * _plot.size.x


func _y_px(f: float) -> float:
	return _plot.size.y - f / y_max * _plot.size.y


## Pasa la curva a píxeles si ha cambiado la curva o el tamaño (una vez, no en cada fotograma).
func _ensure_built() -> void:
	if not _stale and _built_for == _plot.size:
		return
	_stale = false
	_built_for = _plot.size
	builds += 1
	_need = PackedVector2Array()
	_avail = PackedVector2Array()
	_need_band = PackedVector2Array()
	_avail_band = PackedVector2Array()
	_band_idx = PackedInt32Array()
	if curve.is_empty():
		return
	var ys := y_scale(curve)
	y_max = ys.max
	y_step = ys.step
	var vs: PackedFloat64Array = curve.vKmh
	var nv: PackedFloat64Array = curve.need
	var av: PackedFloat64Array = curve.avail
	var lo_n: PackedFloat64Array = curve.needMin
	var hi_n: PackedFloat64Array = curve.needMax
	var lo_a: PackedFloat64Array = curve.availMin
	var hi_a: PackedFloat64Array = curve.availMax
	var n := vs.size()
	var far := y_max * 4.0  # lo que se sale se corta en el borde del área (clip_contents): basta con pasar de él
	for i in n:
		var x := _x_px(vs[i])
		_need.append(Vector2(x, _y_px(minf(nv[i], far))))
		_avail.append(Vector2(x, _y_px(minf(av[i], far))))
		_need_band.append(Vector2(x, _y_px(minf(hi_n[i], far))))
		_avail_band.append(Vector2(x, _y_px(minf(hi_a[i], far))))
	for i in n:
		var x := _x_px(vs[i])
		_need_band.append(Vector2(x, _y_px(minf(lo_n[i], far))))
		_avail_band.append(Vector2(x, _y_px(minf(lo_a[i], far))))
	# dos triángulos por tramo: arriba i, i+1 y abajo n+i+1, n+i
	for i in n - 1:
		_band_idx.append_array(PackedInt32Array([i, i + 1, n + i + 1, i, n + i + 1, n + i]))
	_need_cols = PackedColorArray()
	_avail_cols = PackedColorArray()
	_need_cols.resize(2 * n)
	_avail_cols.resize(2 * n)
	_need_cols.fill(Color(Palette.color("coral"), 0.16))
	_avail_cols.fill(Color(Palette.color("mint"), 0.16))


func _draw() -> void:
	_ensure_built()
	var font := get_theme_default_font()
	var dim := Palette.color("dimmer")
	var line := Palette.color("line")
	var ps := _plot.size
	var o := _plot.position
	draw_rect(Rect2(o, ps), Color(Palette.color("bg"), 0.35))
	if curve.is_empty():
		return
	# marcas: N a la izquierda y km/h abajo
	var k := 0.0
	while k <= y_max * (1.0 + 1e-9):
		var y := o.y + _y_px(k)
		draw_line(Vector2(o.x, y), Vector2(o.x + ps.x, y), Color(line, 0.6), 1.0)
		draw_string(font, Vector2(0.0, y + 4.0), Js.js_num_str(k), HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 6.0, FONT_SIZE, dim)
		k += y_step
	var every := 50.0 if ps.x >= 300.0 else 100.0
	var v := 0.0
	while v <= x_max + 1e-9:
		var x := o.x + _x_px(v)
		draw_line(Vector2(x, o.y + ps.y), Vector2(x, o.y + ps.y + 3.0), line, 1.0)
		# sin pisar el rótulo del final («230 km/h»)
		if v < x_max and o.x + ps.x - x > 72.0:
			draw_string(font, Vector2(x - 20.0, o.y + ps.y + 15.0), Js.js_num_str(v), HORIZONTAL_ALIGNMENT_CENTER, 40.0, FONT_SIZE, dim)
		v += every
	draw_string(font, Vector2(o.x + ps.x - 90.0, o.y + ps.y + 15.0), "%s km/h" % Js.js_num_str(x_max), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, FONT_SIZE, dim)
	draw_string(font, Vector2(0.0, PAD_T - 8.0), "N", HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 6.0, FONT_SIZE, dim)
	# leyenda: necesaria, disponible (con su banda) y despegue (con la suya)
	var lx := o.x + 2.0
	var ly := PAD_T - 12.0
	for item: Array in [["coral", "necesaria"], ["mint", "disponible"], ["gold", "despegue"]]:
		var col := Palette.color(item[0])
		draw_rect(Rect2(lx, ly - 5.0, 14.0, 9.0), Color(col, 0.22))
		draw_line(Vector2(lx, ly), Vector2(lx + 14.0, ly), col, 2.0)
		var w := font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(lx + 18.0, ly + 4.0), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
		lx += 18.0 + w + 12.0


## Capa quieta, recortada en el área: la banda del despegue, las bandas de las fuerzas, las curvas y el texto del
## despegue si cae fuera del eje.
func _draw_plot() -> void:
	_ensure_built()
	plot_draws += 1
	if curve.is_empty() or _need.size() < 2:
		return
	var c := _plot
	var ps := c.size
	var gold := Palette.color("gold")
	if not det.is_empty():
		var lo: float = det.minKmh
		var hi: float = det.maxKmh
		if lo < x_max:
			var x0 := _x_px(maxf(lo, 0.0))
			var x1 := _x_px(minf(hi, x_max)) if is_finite(hi) else ps.x
			c.draw_rect(Rect2(x0, 0.0, maxf(x1 - x0, 2.0), ps.y), Color(gold, 0.10))
		var kmh: float = det.kmh
		if det.atRest and is_finite(kmh) and kmh <= x_max:
			var x := _x_px(kmh)
			c.draw_dashed_line(Vector2(x, 0.0), Vector2(x, ps.y), gold, 2.0, 5.0)
		elif det.get("holdFromKmh") != null and float(det.holdFromKmh) <= x_max:
			# solo aguanta en una ventana: una raya donde empieza y otra donde acaba (si caen en el eje)
			for e: Variant in [det.holdFromKmh, det.holdToKmh]:
				if is_finite(float(e)) and float(e) <= x_max:
					var xe := _x_px(float(e))
					c.draw_dashed_line(Vector2(xe, 0.0), Vector2(xe, ps.y), gold, 2.0, 5.0)
		elif not det.atRest:
			c.draw_line(Vector2(1.0, 0.0), Vector2(1.0, ps.y), gold, 2.0)
		# el despegue con el aire de referencia, para comparar (si el aire elegido es otro)
		if is_finite(ref_kmh) and ref_kmh <= x_max and absf(ref_kmh - kmh) >= 0.5:
			var xr := _x_px(ref_kmh)
			c.draw_dashed_line(Vector2(xr, 0.0), Vector2(xr, ps.y), Color(Palette.color("dim"), 0.7), 1.0, 3.0)
	var item := c.get_canvas_item()
	RenderingServer.canvas_item_add_triangle_array(item, _band_idx, _avail_band, _avail_cols)
	RenderingServer.canvas_item_add_triangle_array(item, _band_idx, _need_band, _need_cols)
	c.draw_polyline(_avail, Palette.color("mint"), 2.0, true)
	c.draw_polyline(_need, Palette.color("coral"), 2.0, true)
	if note != "":
		var font := get_theme_default_font()
		var w := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var box := Rect2(ps.x - w - 12.0, 4.0, w + 8.0, 16.0)
		c.draw_rect(box, Color(Palette.color("panel2"), 0.9))
		c.draw_string(font, Vector2(box.position.x + 4.0, box.position.y + 12.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, gold)


## Capa del punto: la velocidad del deslizador y las dos fuerzas a esa velocidad (un aro si ya no aguanta).
func _draw_marker() -> void:
	marker_draws += 1
	if curve.is_empty():
		return
	var c := _marker
	var ps := c.size
	var x := _x_px(clampf(v_kmh, 0.0, x_max))
	c.draw_line(Vector2(x, 0.0), Vector2(x, ps.y), Color(Palette.color("rose"), 0.7), 1.0)
	# una fuerza que se sale del área se marca en el borde de arriba
	var ya := _y_px(minf(avail, y_max))
	var yn := _y_px(minf(need, y_max))
	c.draw_circle(Vector2(x, ya), 4.5, Palette.color("mint"), true, -1.0, true)
	c.draw_circle(Vector2(x, yn), 4.5, Palette.color("coral"), true, -1.0, true)
	if not holds:
		c.draw_circle(Vector2(x, yn), 8.0, Palette.color("coral"), false, 1.5, true)
