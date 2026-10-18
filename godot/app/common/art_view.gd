## Una ilustración de la caché (ArtCache) pintada en su rectángulo, como un <svg viewBox> de la 1.x con
## preserveAspectRatio "xMidYMid meet": se ajusta sin deformarse y se centra. Se rasteriza a la escala real de la
## pantalla (nítida en HiDPI) y solo cuando cambian el dibujo o el tamaño. Mientras llega la textura nueva sigue
## pintando la anterior (sin parpadeo).
## Los rótulos de los cortes (labels: { x, y, text, size, color, bold, anchor }, en coordenadas del dibujo) se
## escriben encima con Label, escalados con el mismo factor que el dibujo: ThorVG no pinta <text>.
## Con `aspect` > 0 la vista pide la altura que le corresponde a su ancho (hasta max_width, centrada).
## Uso: v.set_art(cache, "ci:gato", Art.claw_art.bind(claw, o), Rect2(0, 0, 100, 132))
extends Control

const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Js = preload("res://core/shared/js.gd")

var cache: ArtCache = null
var key := ""
var make: Callable
var view_rect := Rect2(0, 0, 100, 100)
## Relación alto/ancho para pedir altura según el ancho (0 = tamaño fijo con custom_minimum_size).
var aspect := 0.0
var max_width := 0.0
## Mientras llega un dibujo nuevo, ¿se sigue viendo el anterior? (sí en fichas y vistas previas; no en los cortes de
## un resultado, que no deben mezclarse con los del ensayo anterior)
var stale_ok := true
var _tex: Texture2D = null
var _tex_key := ""
var _labels: Array = []
var _label_nodes: Array[Label] = []
var _labels_from_meta := false
var _meta_key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Dibujo a mostrar. labels: rótulos propios; si es null, los del propio dibujo (meta.labels) cuando llegue.
func set_art(p_cache: ArtCache, p_key: String, p_make: Callable, p_view: Rect2, p_labels: Variant = null) -> void:
	if p_cache != cache:
		if cache != null and cache.art_ready.is_connected(_on_art_ready):
			cache.art_ready.disconnect(_on_art_ready)
		cache = p_cache
		if cache != null:
			cache.art_ready.connect(_on_art_ready)
	var changed_key := p_key != key
	make = p_make
	var same_labels: bool = ((p_labels == null and _labels_from_meta)
		or (p_labels is Array and not _labels_from_meta and p_labels == _labels))
	if not changed_key and p_view == view_rect and same_labels:
		return  # el mismo dibujo: nada que rasterizar ni que redibujar
	key = p_key
	view_rect = p_view
	_labels_from_meta = p_labels == null
	if changed_key:
		_labels = p_labels if p_labels is Array else _meta_labels()
		_sync_labels()
	elif p_labels is Array:
		_labels = p_labels
		_sync_labels()
	_update_min()
	queue_redraw()


func _exit_tree() -> void:
	if cache != null and cache.art_ready.is_connected(_on_art_ready):
		cache.art_ready.disconnect(_on_art_ready)


func _enter_tree() -> void:
	if cache != null and not cache.art_ready.is_connected(_on_art_ready):
		cache.art_ready.connect(_on_art_ready)


func _meta_labels() -> Array:
	if cache == null or key == "":
		return []
	var m: Dictionary = cache.meta(key)
	return m.get("labels", [])


func _on_art_ready(k: String) -> void:
	if k != key:
		return
	_take_meta()
	queue_redraw()


## Rótulos y descripción que trae el propio dibujo, una vez por dibujo (llegan con él, en un hilo o no).
func _take_meta() -> void:
	if _meta_key == key:
		return
	_meta_key = key
	var m: Dictionary = cache.meta(key)
	if m.has("aria"):
		accessibility_name = String(m.aria)
	if _labels_from_meta:
		_labels = m.get("labels", [])
		_sync_labels()


## Rectángulo donde cabe el dibujo sin deformarse, centrado.
func fit_rect() -> Rect2:
	var avail := size
	if max_width > 0.0:
		avail.x = minf(avail.x, max_width)
	var s := minf(avail.x / view_rect.size.x, avail.y / view_rect.size.y) if view_rect.size.x > 0.0 and view_rect.size.y > 0.0 else 0.0
	var w := view_rect.size.x * s
	var h := view_rect.size.y * s
	return Rect2(floorf((size.x - w) / 2.0), floorf((size.y - h) / 2.0), w, h)


## Escala del dibujo en pantalla (px lógicos por unidad del dibujo).
func draw_scale() -> float:
	var r := fit_rect()
	return r.size.x / view_rect.size.x if view_rect.size.x > 0.0 else 0.0


func view_dict() -> Dictionary:
	return {
		"viewBox": "%s %s %s %s" % [Js.js_num_str(view_rect.position.x), Js.js_num_str(view_rect.position.y),
			Js.js_num_str(view_rect.size.x), Js.js_num_str(view_rect.size.y)],
		"width": view_rect.size.x, "height": view_rect.size.y,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_min()
		_layout_labels()
		queue_redraw()


func _update_min() -> void:
	if aspect <= 0.0:
		return
	var w := size.x if max_width <= 0.0 else minf(size.x, max_width)
	var h := ceilf(w * aspect)
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size.y = h


func _draw() -> void:
	if cache == null or key == "":
		return
	var r := fit_rect()
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	var sc: float = r.size.x / view_rect.size.x * SvgTexture.screen_scale(self)
	var t: Texture2D = cache.texture(key, make, view_dict(), sc)
	if t != null:
		_tex = t
		_tex_key = key
		if _meta_key != key:
			_take_meta.call_deferred()  # sin hilos llega aquí, en pleno dibujo: los rótulos, después
	if _tex != null and (stale_ok or _tex_key == key):
		draw_texture_rect(_tex, r, false)


# ── Rótulos ──

func _sync_labels() -> void:
	while _label_nodes.size() < _labels.size():
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_label_nodes.append(l)
	for i in _label_nodes.size():
		var l := _label_nodes[i]
		l.visible = i < _labels.size()
		if l.visible:
			var d: Dictionary = _labels[i]
			l.text = String(d.text)
			l.add_theme_font_override("font", AppTheme.MONO_BOLD if d.get("bold", false) else AppTheme.MONO)
			l.add_theme_color_override("font_color", Palette.color(String(d.get("color", "dim"))))
	_layout_labels()


func _layout_labels() -> void:
	if _labels.is_empty():
		return
	var r := fit_rect()
	var s := draw_scale()
	for i in _labels.size():
		var d: Dictionary = _labels[i]
		var l := _label_nodes[i]
		var fs := maxi(1, int(round(float(d.get("size", 8.0)) * s)))
		l.add_theme_font_size_override("font_size", fs)
		var font: Font = AppTheme.MONO_BOLD if d.get("bold", false) else AppTheme.MONO
		var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := r.position.x + (float(d.x) - view_rect.position.x) * s
		match String(d.get("anchor", "start")):
			"end":
				x -= w
			"middle":
				x -= w / 2.0
		var baseline := r.position.y + (float(d.y) - view_rect.position.y) * s
		l.position = Vector2(round(x), round(baseline - font.get_ascent(fs)))
		l.size = Vector2(w + 2.0, font.get_height(fs))
