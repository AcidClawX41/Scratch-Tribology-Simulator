## Botón ARAÑAR (.run de la 1.x): todo el ancho, degradado de rosa a oro con un halo dorado, texto oscuro y el atajo
## (Ctrl ↩ o ⌘ ↩) a la derecha; mientras se ensaya, gris y «Ensayando…». El fondo es un SVG pequeño (DPITexture):
## esquinas suavizadas y nítidas a cualquier escala.
extends Button

const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const Js = preload("res://core/shared/js.gd")
const SharedTheme = preload("res://core/shared/theme.gd")

const RADIUS := 16.0
## Texto sobre el degradado: el color oscuro de .run en styles.css de la 1.x (no está en la paleta).
const INK := Color("#2a0e1e")

var shortcut_label := ""
var running := false
var _bg: Texture2D = null
var _bg_size := Vector2.ZERO
var _glow: StyleBoxFlat
var _off: StyleBoxFlat
var _focus: StyleBoxFlat


func _init() -> void:
	theme_type_variation = &"RunButton"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(200, 56)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_glow = AppTheme.box(Color(0, 0, 0, 0), int(RADIUS))
	_glow.shadow_color = Color(0.9, 0.7, 0.31, 0.22)
	_glow.shadow_size = 16
	_glow.shadow_offset = Vector2(0, 10)
	_off = AppTheme.box(Palette.color("panel2"), int(RADIUS))
	_focus = AppTheme.focus_box(int(RADIUS))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Estado del banco: mientras se ensaya no se puede volver a pulsar.
func set_running(v: bool) -> void:
	running = v
	disabled = v
	var shortcut := " (%s)" % shortcut_label if shortcut_label != "" else ""
	tooltip_text = "" if v else "Arañar%s" % shortcut
	accessibility_name = "Ensayando" if v else "Arañar: correr el ensayo"
	queue_redraw()


func _background(sz: Vector2) -> Texture2D:
	if _bg == null or not _bg_size.is_equal_approx(sz):
		_bg_size = sz
		var w := Js.js_num_str(sz.x)
		var h := Js.js_num_str(sz.y)
		_bg = AppTheme.icon_texture(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\"><defs>"
			+ "<linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0\" stop-color=\"%s\"/>"
			+ "<stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs>"
			+ "<rect width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"url(#g)\"/></svg>") % [w, h, SharedTheme.C.rose, SharedTheme.C.gold, w, h,
			Js.js_num_str(RADIUS)])
	return _bg


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if is_pressed() and not running:
		r.position.y += 1.0
	var font: Font = AppTheme.DISP_BLACK
	var mono: Font = AppTheme.MONO
	var main := "Ensayando…" if running else "▸ ARAÑAR"
	var ink := Palette.color("dim") if running else INK
	if running:
		draw_style_box(_off, r)
	else:
		_glow.shadow_size = 20 if is_hovered() else 16
		draw_style_box(_glow, r)
		var bg := _background(Vector2(round(size.x), round(size.y)))
		draw_texture_rect(bg, r, false, Color(1.04, 1.04, 1.04) if is_hovered() else Color.WHITE)
	var w := font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var extra := ""
	var ew := 0.0
	if not running and shortcut_label != "":
		extra = shortcut_label
		ew = mono.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
	var x := r.position.x + (r.size.x - w - ew) / 2.0
	var base := r.position.y + (r.size.y + font.get_ascent(18) - font.get_descent(18)) / 2.0
	draw_string(font, Vector2(x, base), main, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	if extra != "":
		draw_string(mono, Vector2(x + w + 10.0, base - 1.0), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.7))
	if has_focus() and not running:
		draw_style_box(_focus, r)


func _make_custom_tooltip(for_text: String) -> Object:
	return Ui.tooltip(for_text)
