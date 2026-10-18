## Utilidades de interfaz sin estado: crear textos y contenedores con las variaciones del tema, números como
## JavaScript (core/shared/js.gd), el suavizado cubic-bezier de las transiciones CSS de la 1.x y una ayuda emergente
## con ancho máximo. Solo crean nodos; no guardan nada.
## Uso: const Ui = preload("res://app/common/ui.gd"); var l := Ui.label("Hola", "Note")
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")

## Ancho máximo de las ayudas emergentes (px lógicos).
const TOOLTIP_WIDTH := 340.0


## String(n) de JavaScript: los números visibles pasan siempre por aquí (o por Js.to_fixed / Format).
static func num(v: Variant) -> String:
	return Js.template_str(v) if v == null else Js.js_num_str(float(v))


## Texto de una línea con una variación del tema y, si se da, un color de la paleta o hexadecimal.
static func label(text: String, variation := "", color := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = StringName(variation)
	if color != "":
		l.add_theme_color_override("font_color", Palette.color(color))
	return l


## Párrafo que se parte en líneas y ocupa el ancho disponible.
static func para(text: String, variation := "Body", color := "") -> Label:
	var l := label(text, variation, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40.0
	return l


## Rótulo en versalitas (SubLabel de la 1.x) con su margen superior.
static func sub_label(text: String) -> Label:
	var l := para(text, "SubLabel")
	l.uppercase = true
	return l


static func vbox(sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


## Fila que se parte en varias (flex-wrap de la 1.x): chips, píldoras y datos.
static func flow(h_sep := 7, v_sep := 7) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", h_sep)
	f.add_theme_constant_override("v_separation", v_sep)
	return f


## Contenedor con márgenes (izquierda, arriba, derecha, abajo).
static func margin(l := 0, t := 0, r := 0, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


## Espacio vertical fijo.
static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func set_color(c: Control, color: Variant, item := "font_color") -> void:
	c.add_theme_color_override(item, color if color is Color else Palette.color(String(color)))


## El nodo y sus descendientes dejan pasar el ratón (el contenido de un botón no debe robarle los clics).
static func ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


## Ayuda emergente que se parte en líneas (las de Godot son de una sola línea).
static func tooltip(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := l.get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x if font != null else TOOLTIP_WIDTH
	l.custom_minimum_size.x = minf(TOOLTIP_WIDTH, w + 2.0)
	return l


## Easing cubic-bezier(x1, y1, x2, y2) de CSS en t ∈ [0, 1] (Newton y, si no converge, bisección).
static func cubic_bezier(x1: float, y1: float, x2: float, y2: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var u := t
	for i in 8:
		var dx := _bz(x1, x2, u) - t
		if absf(dx) < 1e-7:
			return _bz(y1, y2, u)
		var d := _bz_d(x1, x2, u)
		if absf(d) < 1e-6:
			break
		u -= dx / d
		if u < 0.0 or u > 1.0:
			break
	var lo := 0.0
	var hi := 1.0
	u = t
	for i in 40:
		var x := _bz(x1, x2, u)
		if absf(x - t) < 1e-7:
			break
		if x < t:
			lo = u
		else:
			hi = u
		u = (lo + hi) * 0.5
	return _bz(y1, y2, u)


static func _bz(a: float, b: float, u: float) -> float:
	var v := 1.0 - u
	return 3.0 * v * v * u * a + 3.0 * v * u * u * b + u * u * u


static func _bz_d(a: float, b: float, u: float) -> float:
	var v := 1.0 - u
	return 3.0 * v * v * a + 6.0 * v * u * (b - a) + 3.0 * u * u * (1.0 - b)


## ¿Pide el sistema menos movimiento? (prefers-reduced-motion de la 1.x; -1 = no se sabe).
static func reduce_motion() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--movimiento-reducido":
			return true
	return DisplayServer.accessibility_should_reduce_animation() == 1
