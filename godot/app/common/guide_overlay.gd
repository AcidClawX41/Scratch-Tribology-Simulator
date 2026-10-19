## Guiado botón a botón (unidad 5x): la interfaz común que pinta el objetivo del motor (core/shared/guide_target.gd). Sirve
## para la reforja y, al unirse, para la cetrería (5y). No calcula nada: el objetivo, sus textos y sus números vienen hechos.
## - Sobre la vista 3D, el aviso corto (hint), cerca del punto del objeto señalado (encima o debajo, sin taparlo) o, sin
##   punto, en una franja abajo; al cambiar de acción se va con una transición corta y sale el siguiente.
## - En el panel: el control objetivo con un borde que late y la etiqueta corta (label), y el resto del panel algo atenuado
##   (sin bloquearlo: nada de esto coge el ratón).
## - El panel se desplaza solo hasta el control (cada contenedor con barra que lo contiene, del de dentro al de fuera), con
##   suavidad, durante un momento después de cada objetivo nuevo; si la persona mueve la barra, la deja. Si la acción se hace
##   en la escena (where = "scene", como la costura), lo que se trae a la vista es la vista 3D (en el teléfono, arriba).
## - Con movimiento reducido, sin transiciones: todo llega de golpe y el borde no late.
## Va como hijo de la página, encima de todo y fuera de su maquetación (top_level): dibuja en coordenadas de la ventana y
## recorta cada cosa a lo que se ve de su contenedor con barra.
## Uso: var g := GuideOverlay.new(); page.add_child(g); g.setup(panel_area, view_area)
##      cada repintado: g.show_target(objetivo, control_del_panel); cada fotograma: g.set_scene_point(p); g.advance(dt)
extends Control

const Ui = preload("res://app/common/ui.gd")
const Palette = preload("res://app/theme/palette.gd")

## Cuánto dura el desvanecido del aviso al cambiar (s).
const FADE_S := 0.22
## El latido del borde (Hz) y lo que se atenúa el resto del panel (opacidad del velo).
const PULSE_HZ := 1.1
const DIM_ALPHA := 0.36
## Desplazamiento del panel: rapidez (1/s), cuánto dura como mucho (s) y dónde queda el control (fracción del alto visible).
const SCROLL_K := 9.0
const SCROLL_FOLLOW_S := 1.4
const SCROLL_AT := 0.38
## El aire alrededor del control resaltado y entre el aviso y el objeto (px).
const PAD := 5.0
const HINT_GAP := 10.0
const HINT_MAX_W := 420.0
## Lo que ocupan a los lados los márgenes de una burbuja (px).
const BUBBLE_PAD := 22.0
## Lo que tiene que verse de la vista para que el aviso vaya dentro (px de alto; si no, en una franja de lo que se ve).
const VIEW_MIN_H := 140.0

var reduce_motion := false
## Lo que tapan por la derecha los mandos sobre la vista (px; el deslizador grande del teléfono).
var view_inset_right := 0.0

var target: Dictionary = {}
var panel_node: Control = null
## Lo que se trae a la vista: el control del panel o, si la acción se hace en la escena («where» = «scene»), la vista.
var _scroll_node: Control = null
var _panel_area: Control = null
var _view_area: Control = null
var _point := Vector2(-1.0, -1.0)
var _point_r := 0.0
var _t := 0.0
var _hint_box: PanelContainer
var _hint_label: Label
var _tag_box: PanelContainer
var _tag_label: Label
var _hint_now := ""
var _hint_next := ""
var _hint_a := 0.0
var _scroll_left := 0.0
var _scroll_set := {}
var _key := ""


func _init() -> void:
	name = "Guiado"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_hint_box = _bubble("gold", "CardTitle")
	_hint_label = _hint_box.get_child(0) as Label
	_tag_box = _bubble("gold", "Body")
	_tag_label = _tag_box.get_child(0) as Label
	visible = false


func _bubble(color: String, variation: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.theme_type_variation = &"Sheet"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.09, 0.9)
	sb.border_color = Palette.color(color)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	box.add_theme_stylebox_override("panel", sb)
	var l := Ui.label("", variation, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	box.visible = false
	add_child(box)
	return box


## panel_area: lo que se atenúa (la columna del panel); view_area: la vista 3D (el aviso va dentro).
func setup(p_panel_area: Control, p_view_area: Control) -> void:
	_panel_area = p_panel_area
	_view_area = p_view_area


## El objetivo de ahora (el del motor) y el control del panel que lo hace (null si no hay o no se ve). Un objetivo apagado
## lo quita todo.
func show_target(t: Dictionary, node: Control) -> void:
	target = t
	var on := bool(t.get("on", false))
	panel_node = node if on else null
	visible = on
	var hint := String(t.get("hint", "")) if on else ""
	var key := "%s|%s" % [String(t.get("step", "")), String(t.get("id", ""))] if on else ""
	if hint != _hint_next:
		var fading := _hint_now != _hint_next
		_hint_next = hint
		# la misma acción con otro valor (lo que falta de un polvo, los puntos de la costura): el texto cambia sin desvanecerse
		if reduce_motion or _hint_now == "" or (key == _key and hint != "" and not fading):
			_hint_now = hint
			_hint_a = 1.0 if hint != "" else 0.0
	_tag_label.text = String(t.get("label", "")) if on else ""
	_scroll_node = _view_area if on and String(t.get("where", "")) == "scene" else panel_node
	if key != _key:
		_key = key
		_scroll_left = SCROLL_FOLLOW_S if on and _scroll_node != null else 0.0
		_scroll_set = {}
		if reduce_motion and _scroll_left > 0.0:
			_scroll_now(true)
	_layout()
	queue_redraw()


## El punto de la pantalla del objeto señalado, en coordenadas de la vista ((−1, −1) si no hay o no se ve), y lo que mide de
## alto hacia cada lado (px): el aviso va encima o debajo, sin taparlo.
func set_scene_point(p: Vector2, half_h := 0.0) -> void:
	_point = p
	_point_r = maxf(half_h, 0.0)


func clear() -> void:
	show_target({}, null)


## Un fotograma: el latido, el desvanecido del aviso y el desplazamiento del panel.
func advance(dt: float) -> void:
	if not visible and _hint_now == "":
		return
	_t += dt
	# el aviso: se va el de antes y llega el nuevo
	if _hint_now != _hint_next:
		_hint_a = maxf(_hint_a - dt / FADE_S, 0.0) if not reduce_motion else 0.0
		if _hint_a <= 0.0:
			_hint_now = _hint_next
	elif _hint_now != "" and _hint_a < 1.0:
		_hint_a = minf(_hint_a + dt / FADE_S, 1.0) if not reduce_motion else 1.0
	if _scroll_left > 0.0:
		_scroll_left -= dt
		_scroll_now(reduce_motion, dt)
	# después de que los contenedores recoloquen lo desplazado (también en diferido, antes): así el borde y la etiqueta no van
	# un fotograma por detrás del control
	_relayout.call_deferred()


func _relayout() -> void:
	_layout()
	queue_redraw()


## Lo que pinta ahora (tests y demo): { on, hint, hint_alpha, label, panel_rect (en la ventana), clip, hint_rect, scrolling }.
func info() -> Dictionary:
	return { "on": visible, "hint": _hint_now if _hint_a > 0.0 else "", "hint_alpha": _hint_a, "label": _tag_label.text,
		"panel_rect": _node_rect(), "clip": _clip_of(panel_node), "hint_rect": _hint_box.get_global_rect() if _hint_box.visible else Rect2(),
		"tag_rect": _tag_box.get_global_rect() if _tag_box.visible else Rect2(), "scrolling": _scroll_left > 0.0 }


# ─────────────────────────────── desplazamiento ───────────────────────────────

## Lleva cada contenedor con barra que contiene el control (del de dentro al de fuera) hasta dejarlo a la vista.
func _scroll_now(instant: bool, dt := 0.0) -> void:
	var target_node := _scroll_node
	if target_node == null or not is_instance_valid(target_node) or not target_node.is_visible_in_tree():
		_scroll_left = 0.0
		return
	var n: Node = target_node.get_parent()
	var moving := false
	while n != null:
		if n is ScrollContainer:
			var sc := n as ScrollContainer
			var key := sc.get_instance_id()
			# la persona ha movido la barra: se deja
			if _scroll_set.has(key) and absf(float(sc.scroll_vertical) - float(_scroll_set[key])) > 1.5:
				_scroll_left = 0.0
				return
			var goal := scroll_goal(sc, target_node)
			var now := float(sc.scroll_vertical)
			var next := goal if instant else now + (goal - now) * (1.0 - exp(-SCROLL_K * maxf(dt, 0.0)))
			if absf(goal - now) > 0.5:
				moving = true
			if absf(next - goal) < 1.0:
				next = goal
			sc.scroll_vertical = int(round(next))
			_scroll_set[key] = sc.scroll_vertical
		n = n.get_parent()
	if not moving and not instant:
		_scroll_left = minf(_scroll_left, 0.2)


## El desplazamiento de sc que deja el control a SCROLL_AT del alto visible (o arriba, si no cabe), dentro de su recorrido.
static func scroll_goal(sc: ScrollContainer, node: Control) -> float:
	var r := node.get_global_rect()
	var sr := sc.get_global_rect()
	var y := r.position.y - sr.position.y + float(sc.scroll_vertical)
	var room := sr.size.y - r.size.y
	var goal := y - (room * SCROLL_AT if room > 0.0 else 8.0)
	var vmax := maxf(float(sc.get_v_scroll_bar().max_value) - sr.size.y, 0.0)
	return clampf(goal, 0.0, vmax)


# ─────────────────────────────── maquetación y dibujo ───────────────────────────────

## Lo que se ve de un control: la intersección de los contenedores que recortan (los de barra y los que recortan su contenido).
func _clip_of(node: Control) -> Rect2:
	var vp := get_viewport_rect() if is_inside_tree() else Rect2(0, 0, 4096, 4096)
	var clip := vp
	if node == null or not is_instance_valid(node):
		return clip
	var n: Node = node.get_parent()
	while n != null:
		if n is Control and ((n as Control).clip_contents or n is ScrollContainer):
			clip = clip.intersection((n as Control).get_global_rect())
		n = n.get_parent()
	return clip


func _node_rect() -> Rect2:
	if panel_node == null or not is_instance_valid(panel_node) or not panel_node.is_visible_in_tree():
		return Rect2()
	return panel_node.get_global_rect().grow(PAD)


func _layout() -> void:
	if is_inside_tree():
		position = Vector2.ZERO
		size = get_viewport_rect().size
	# la etiqueta, junto al control: encima si cabe; si no, debajo
	var r := _node_rect()
	var clip := _clip_of(panel_node)
	var tag_on := r.size.x > 0.0 and _tag_label.text != "" and clip.intersects(r)
	_tag_box.visible = tag_on
	if tag_on:
		# en una línea si cabe; si no, partida al ancho de lo que se ve del panel
		var bs := _fit_bubble(_tag_box, _tag_label, maxf(clip.size.x - 8.0, 120.0))
		var y := r.position.y - bs.y - 4.0
		if y < clip.position.y:
			y = r.end.y + 4.0
		var x := clampf(r.position.x, clip.position.x + 4.0, maxf(clip.end.x - bs.x - 4.0, clip.position.x + 4.0))
		_tag_box.position = Vector2(x, y)
		_tag_box.modulate.a = 0.8 + 0.2 * _pulse()
	# el aviso, sobre la vista; si la vista no se ve (en el teléfono, el panel bajado hasta el control), en una franja de lo que
	# se ve de la pantalla, arriba o abajo, lejos del control
	var hint_on := _view_area != null and is_instance_valid(_view_area) and _view_area.is_visible_in_tree() and _hint_now != "" and _hint_a > 0.0
	_hint_box.visible = hint_on
	if hint_on:
		var vr := _view_area.get_global_rect().intersection(_clip_of(_view_area))
		var in_view := vr.size.y >= minf(VIEW_MIN_H, _view_area.size.y * 0.5) and vr.size.x >= 200.0
		var usable := Rect2(vr.position, Vector2(maxf(vr.size.x - view_inset_right, 120.0), vr.size.y)) if in_view else _clip_of(panel_node)
		_hint_label.text = _hint_now
		var bs := _fit_bubble(_hint_box, _hint_label, minf(HINT_MAX_W, usable.size.x - 16.0))
		var pos: Vector2
		if in_view and _point.x >= 0.0:
			var p := _view_area.get_global_rect().position + _point
			pos = Vector2(p.x - bs.x * 0.5, p.y - _point_r - HINT_GAP - bs.y)
			# sin sitio encima: debajo del objeto, sin taparlo
			if pos.y < usable.position.y + 4.0:
				pos.y = p.y + _point_r + HINT_GAP
		elif in_view:
			pos = Vector2(usable.position.x + (usable.size.x - bs.x) * 0.5, usable.end.y - bs.y - 12.0)
		else:
			var top := r.size.y <= 0.0 or r.get_center().y > usable.get_center().y
			pos = Vector2(usable.position.x + (usable.size.x - bs.x) * 0.5, usable.position.y + 8.0 if top else usable.end.y - bs.y - 8.0)
		pos.x = clampf(pos.x, usable.position.x + 6.0, maxf(usable.end.x - bs.x - 6.0, usable.position.x + 6.0))
		pos.y = clampf(pos.y, usable.position.y + 4.0, maxf(usable.end.y - bs.y - 4.0, usable.position.y + 4.0))
		_hint_box.position = pos
		_hint_box.modulate.a = _hint_a


## Ajusta una burbuja a su texto (medido con su letra: el tamaño mínimo de un Label recién cambiado llega un fotograma tarde),
## como mucho de max_w de ancho y partido en líneas si no cabe. Devuelve su tamaño.
static func _fit_bubble(box: PanelContainer, l: Label, max_w: float) -> Vector2:
	# medido una vez por texto y ancho; el tamaño se pone siempre (el mínimo de la burbuja, guardado, llega un fotograma tarde y
	# no deja encogerla en el primero)
	var key := "%s|%d" % [l.text, int(max_w)]
	if String(box.get_meta("fit", "")) != key:
		box.set_meta("fit", key)
		var font := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		var one := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# unos píxeles de holgura: con el ancho justo, la medida partía la línea en dos
		var w := minf(ceilf(one) + BUBBLE_PAD + 4.0, max_w)
		var lines := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, w - BUBBLE_PAD, fs)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF if w < max_w else TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w - BUBBLE_PAD, lines.y)
		box.set_meta("fit_size", Vector2(w, lines.y + 12.0))
	var sz: Vector2 = box.get_meta("fit_size")
	box.size = sz
	return sz


func _pulse() -> float:
	return 1.0 if reduce_motion else 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ)


func _draw() -> void:
	var r := _node_rect()
	if r.size.x <= 0.0:
		return
	var clip := _clip_of(panel_node)
	# el resto del panel, algo atenuado (cuatro bandas alrededor del control)
	if _panel_area != null and is_instance_valid(_panel_area) and _panel_area.is_visible_in_tree():
		var area := _panel_area.get_global_rect().intersection(_clip_of(_panel_area))
		var hole := r.intersection(area)
		var veil := Color(0.04, 0.02, 0.06, DIM_ALPHA)
		if hole.size.x > 0.0 and hole.size.y > 0.0:
			for band: Rect2 in [Rect2(area.position, Vector2(area.size.x, hole.position.y - area.position.y)),
					Rect2(Vector2(area.position.x, hole.end.y), Vector2(area.size.x, area.end.y - hole.end.y)),
					Rect2(Vector2(area.position.x, hole.position.y), Vector2(hole.position.x - area.position.x, hole.size.y)),
					Rect2(Vector2(hole.end.x, hole.position.y), Vector2(area.end.x - hole.end.x, hole.size.y))]:
				if band.size.x > 0.0 and band.size.y > 0.0:
					draw_rect(band, veil)
		else:
			draw_rect(area, veil)
	# el borde que late, recortado a lo que se ve
	var shown := r.intersection(clip)
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return
	var gold := Palette.color("gold")
	var k := _pulse()
	draw_rect(shown, Color(gold.r, gold.g, gold.b, 0.1 + 0.12 * k))
	draw_rect(shown, Color(gold.r, gold.g, gold.b, 0.55 + 0.45 * k), false, 3.0)
