## Cetrería · la lupa de la punta (unidad 5s, petición 60): la punta de la garra de perfil a escala de micras, con la misma
## escala en los dos ejes (la forma de verdad), frente a la punta natural de su ficha (a trazos, con el vértice en el mismo
## sitio), con la barra de escala. Así se ve que 5 µm es una aguja y 113 µm la natural: la esfera de la punta, la faceta (en
## azul, con su ángulo) y la cara plana de un corte o de una mella (dentada). No calcula nada: pinta la lupa del motor
## (view().tip_help.lupa: SharpenHelp.lupa, hecha en el hilo del estado) y el tono del medidor. Se repinta solo si cambia.
extends PanelContainer

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const Rng = preload("res://core/shared/rng.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const FONT_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral" }
## Tamaño del dibujo (px) en escritorio y en el teléfono (allí, al lado del medidor: los dos caben en el ancho de la vista).
const SIZE := Vector2(300.0, 112.0)
const SIZE_PHONE := Vector2(140.0, 78.0)
const PAD := 8.0

var compact := false
var _title: Label
var _view: Control
var _key := ""
var _lp: Dictionary = {}
var _m: Dictionary = {}
var _col := Color(0.4, 0.35, 0.3)


func _init() -> void:
	name = "LupaDeLaPunta"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.07, 0.82)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_title = Label.new()
	_title.text = "Lupa de la punta"
	_title.add_theme_font_override("font", FONT_BOLD)
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Palette.color("text"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_view = Control.new()
	_view.custom_minimum_size = SIZE
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	col.add_child(_view)


func set_compact(on: bool) -> void:
	compact = on
	_view.custom_minimum_size = SIZE_PHONE if on else SIZE
	_title.add_theme_font_size_override("font_size", 10 if on else 12)
	_key = ""


## Pinta la lupa de la vista (view().tip_help.lupa). Barata si no ha cambiado.
func show_view(v: Dictionary) -> void:
	var th: Dictionary = v.get("tip_help", {})
	visible = not th.is_empty()
	if th.is_empty():
		return
	var key := "%s|%s|%s" % [String(th.get("key", "")), str(th.get("lupa", {}).get("chipped", false)), str(compact)]
	if key == _key:
		return
	_key = key
	_lp = th.get("lupa", {})
	_m = th.get("meter", {})
	var sn: Dictionary = v.get("snap", {})
	_col = Color(String(sn.get("claw", {}).get("color", "#6B5A45"))).lightened(0.35)
	_view.queue_redraw()


## Un radio (µm) con las cifras que se leen.
static func um_text(x: float) -> String:
	return Js.to_fixed(x, 1) if x < 10.0 else Js.to_fixed(x, 0)


func _draw_view() -> void:
	if _lp.is_empty():
		return
	var w := _view.size.x
	var h := _view.size.y
	var fs := 9 if compact else 10
	var ds: PackedFloat64Array = _lp.d
	var rs: PackedFloat64Array = _lp.r
	var nd: PackedFloat64Array = _lp.natural.d
	var nr: PackedFloat64Array = _lp.natural.r
	if ds.size() < 2:
		return
	var field := float(_lp.fieldMm)
	# la misma escala en los dos ejes: que quepa lo que abarca la lupa a lo ancho y la garra a lo alto (encima, las etiquetas)
	var text_h := 2.0 * float(fs) + 6.0
	var rmax := 0.0
	for i in ds.size():
		if ds[i] <= field:
			rmax = maxf(rmax, rs[i])
	for i in nd.size():
		rmax = maxf(rmax, nr[i])
	# de perfil, la mitad de arriba (el eje, a trazos, abajo): con la misma escala en los dos ejes, cabe el doble de grande
	var axis_y := h - 16.0
	var sc := minf((w - 2.0 * PAD) / maxf(field, 1e-6), (axis_y - text_h - 2.0) / maxf(rmax, 1e-6))
	var tip_x := w - PAD
	var cy := axis_y
	var px := func(d: float, r: float) -> Vector2: return Vector2(tip_x - d * sc, cy - r * sc)
	# la garra de ahora, rellena
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(ds.size() - 1, -1, -1):
		top.append(px.call(ds[i], rs[i]))
	bot.append(px.call(0.0, 0.0))
	bot.append(px.call(ds[ds.size() - 1], 0.0))
	var poly := PackedVector2Array(top)
	if String(_lp.kind) == "cara":
		# la cara plana del corte o de la mella
		poly.append(px.call(0.0, float(_lp.flatMm)))
	poly.append_array(bot)
	if Geometry2D.triangulate_polygon(poly).size() >= 3:
		var fill := _col
		fill.a = 0.92
		_view.draw_colored_polygon(poly, fill)
	_view.draw_polyline(top, Palette.color("text"), 1.2, true)
	_view.draw_dashed_line(px.call(0.0, 0.0), Vector2(0.0, cy), Color(Palette.color("dim"), 0.8), 1.0, 4.0)
	# la faceta, en azul (la cara que deja la lima, de su ángulo)
	var fl := float(_lp.get("facetLenMm", 0.0))
	if fl > 0.0:
		var f_pts := PackedVector2Array()
		for i in ds.size():
			if ds[i] <= fl + 1e-9:
				f_pts.append(px.call(ds[i], rs[i]))
		if f_pts.size() >= 2:
			_view.draw_polyline(f_pts, Palette.color("ice"), 2.4, true)
	# la cara: recta, o dentada si se ha mellado
	if String(_lp.kind) == "cara":
		var fr := float(_lp.flatMm)
		if bool(_lp.get("chipped", false)):
			var rng := Rng.new(Rng.seed_of(String((_lp.get("chip", {}) as Dictionary).get("seed", "mella"))))
			var jag := PackedVector2Array()
			var n := 9
			for j in n + 1:
				var u := float(j) / float(n)
				var dd := 0.0 if j == 0 or j == n else fr * 0.6 * rng.next()
				jag.append(px.call(dd, fr * (1.0 - u)))
			_view.draw_polyline(jag, Palette.color("coral"), 2.0, true)
		else:
			_view.draw_line(px.call(0.0, fr), px.call(0.0, 0.0), Palette.color("text"), 1.4, true)
	# la punta natural, a trazos, con el vértice en el mismo sitio
	var nat := PackedVector2Array()
	for i in range(nd.size() - 1, -1, -1):
		nat.append(px.call(nd[i], nr[i]))
	for i in nat.size() - 1:
		if i % 3 != 2:
			_view.draw_line(nat[i], nat[i + 1], Color(Palette.color("mint"), 0.95), 1.3, true)
	# la esfera de la punta (una punta o la natural): su radio, marcado
	var r_um := float(_lp.tipRadiusUm)
	var tone := Palette.color(String(TONE.get(String(_m.get("tone", "")), "text")))
	if String(_lp.kind) != "cara":
		var rr := r_um / 1000.0 * sc
		var c := Vector2(tip_x - (float(_lp.get("startMm", 0.0)) + r_um / 1000.0) * sc, cy)
		if rr >= 2.0:
			_view.draw_arc(c, rr, PI, TAU, 24, tone, 1.2, true)
		else:
			_view.draw_circle(Vector2(tip_x - float(_lp.get("startMm", 0.0)) * sc, cy), 2.4, tone)
	# la barra de escala
	var bar_um := float(_lp.scaleUm)
	var bl := bar_um / 1000.0 * sc
	var by := h - 4.0
	_view.draw_line(Vector2(PAD, by), Vector2(PAD + bl, by), Palette.color("text"), 2.0)
	_view.draw_line(Vector2(PAD, by - 3.0), Vector2(PAD, by + 1.0), Palette.color("text"), 1.0)
	_view.draw_line(Vector2(PAD + bl, by - 3.0), Vector2(PAD + bl, by + 1.0), Palette.color("text"), 1.0)
	var bt := ("%s mm" % Js.to_fixed(bar_um / 1000.0, 0)) if bar_um >= 1000.0 else ("%s µm" % Js.to_fixed(bar_um, 0))
	_view.draw_string(FONT, Vector2(PAD + bl + 4.0, by + 3.0), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color("dim"))
	# las dos etiquetas: la punta de ahora (del tono del medidor) y la natural (a trazos)
	var what := String(_m.get("zoneName", "")).to_lower()
	var l1 := "Punta %s µm%s" % [um_text(r_um), (" · " + what) if what != "" else ""]
	if bool(_lp.get("chipped", false)):
		l1 = "Mellada: cara de %s µm" % um_text(float(_lp.flatMm) * 1000.0)
	elif fl > 0.0 and not compact:
		l1 += " · faceta %s° de %s mm" % [Js.to_fixed(float(_lp.facetDeg), 0), Js.to_fixed(fl, 2)]
	_view.draw_string(FONT_BOLD, Vector2(2.0, float(fs) + 1.0), l1, HORIZONTAL_ALIGNMENT_LEFT, w - 4.0, fs, tone)
	_view.draw_string(FONT, Vector2(2.0, 2.0 * float(fs) + 4.0), "- - natural %s µm (%s°)" % [um_text(float(_lp.naturalUm)), Js.to_fixed(float(_lp.naturalAlphaDeg), 0)],
		HORIZONTAL_ALIGNMENT_LEFT, w - 4.0, fs, Palette.color("mint"))
