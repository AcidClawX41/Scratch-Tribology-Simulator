## Taller industrial · estilo de la interfaz: la paleta glam-lab (app/theme/palette.gd) y las fuentes del programa
## (Syne en los títulos, Space Mono en los datos), reunidos en un solo archivo.
##
## theme() es un tema LOCAL que la sección aplica a su raíz (no el global: ese lo hace la unidad 12). Todo lo demás
## pide variantes por nombre (theme_type_variation = "TallerTitulo"…), así que para pasar al tema común basta con
## quitar theme() de la sección y definir estas variantes allí.
extends RefCounted

const Palette = preload("res://app/theme/palette.gd")
const MONO_FILE = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const MONO_BOLD_FILE = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")
const DISP_FILE = preload("res://assets/fonts/syne-latin-700-normal.woff2")
const DISP_XB_FILE = preload("res://assets/fonts/syne-latin-800-normal.woff2")

## Tamaños de letra (px lógicos).
const SIZE := 13
const SIZE_SMALL := 11
const SIZE_TITLE := 20

static var _theme: Theme = null
static var _fonts := {}


static func c(name: String) -> Color:
	return Palette.color(name)


## Fuente con respaldo: el subconjunto latino de Space Mono y Syne no trae algunos signos de los textos del core
## (→, ≈, ₂…); el respaldo es la fuente por defecto de Godot, empaquetada con el motor (sin red ni fuentes del
## sistema).
static func font(which: String) -> Font:
	if _fonts.has(which):
		return _fonts[which]
	var base: Font = { "mono": MONO_FILE, "mono_bold": MONO_BOLD_FILE, "disp": DISP_FILE, "disp_xb": DISP_XB_FILE }.get(which, MONO_FILE)
	var f := FontVariation.new()
	f.base_font = base
	if ThemeDB.fallback_font != null:
		f.fallbacks = [ThemeDB.fallback_font]
	_fonts[which] = f
	return f


static func _box(bg: Color, border: Color, radius: int, pad_h: float, pad_v: float, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb


static func _label_variant(t: Theme, name: String, f: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, f)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _button_variant(t: Theme, name: String, bg: Color, border: Color, fg: Color, on_bg: Color, on_fg: Color, radius: int, size: int) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, _box(bg, border, radius, 10, 5))
	t.set_stylebox("hover", name, _box(bg.lightened(0.08), c("line2"), radius, 10, 5))
	t.set_stylebox("pressed", name, _box(on_bg, on_bg, radius, 10, 5))
	t.set_stylebox("hover_pressed", name, _box(on_bg.lightened(0.06), on_bg, radius, 10, 5))
	t.set_stylebox("disabled", name, _box(bg.darkened(0.2), c("line"), radius, 10, 5))
	t.set_stylebox("focus", name, _box(Color(0, 0, 0, 0), c("ice"), radius, 10, 5))
	t.set_color("font_color", name, fg)
	t.set_color("font_hover_color", name, fg)
	t.set_color("font_focus_color", name, fg)
	t.set_color("font_pressed_color", name, on_fg)
	t.set_color("font_hover_pressed_color", name, on_fg)
	t.set_color("font_disabled_color", name, c("dimmer"))
	t.set_font_size("font_size", name, size)


## Tema local de la sección del taller (se construye una vez).
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("mono")
	t.default_font_size = SIZE
	t.set_color("font_color", "Label", c("text"))
	_label_variant(t, "TallerTitulo", font("disp_xb"), SIZE_TITLE, c("mint"))
	_label_variant(t, "TallerTarjeta", font("disp"), 15, c("text"))
	_label_variant(t, "TallerDato", font("mono_bold"), 15, c("text"))
	_label_variant(t, "TallerGrande", font("disp_xb"), 30, c("mint"))
	_label_variant(t, "TallerTenue", font("mono"), 12, c("dim"))
	_label_variant(t, "TallerNota", font("mono"), SIZE_SMALL, c("dimmer"))
	_label_variant(t, "TallerAviso", font("mono"), 12, c("gold"))
	_label_variant(t, "TallerMal", font("mono"), 12, c("coral"))
	_label_variant(t, "TallerBien", font("mono"), 12, c("mint"))
	# Botones: normales, fichas (conmutables) y acciones
	for kind in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, _box(c("panel2"), c("line2"), 8, 10, 5))
		t.set_stylebox("hover", kind, _box(c("panel3"), c("line2"), 8, 10, 5))
		t.set_stylebox("pressed", kind, _box(c("panel3"), c("mint"), 8, 10, 5))
		t.set_stylebox("disabled", kind, _box(c("bg2"), c("line"), 8, 10, 5))
		t.set_stylebox("focus", kind, _box(Color(0, 0, 0, 0), c("ice"), 8, 10, 5))
		t.set_color("font_color", kind, c("text"))
		t.set_color("font_hover_color", kind, c("text"))
		t.set_color("font_pressed_color", kind, c("mint"))
		t.set_color("font_disabled_color", kind, c("dimmer"))
	_button_variant(t, "TallerFicha", c("panel2"), c("line2"), c("dim"), c("mint"), c("bg"), 14, 12)
	_button_variant(t, "TallerAccion", c("mint").darkened(0.35), c("mint"), c("text"), c("mint"), c("bg"), 8, SIZE)
	_button_variant(t, "TallerPeligro", c("coral").darkened(0.45), c("coral"), c("text"), c("coral"), c("bg"), 8, SIZE)
	_button_variant(t, "TallerPestana", c("bg2"), c("line"), c("dim"), c("panel3"), c("mint"), 10, 14)
	t.set_font("font", "TallerPestana", font("disp"))
	# Tarjetas
	t.set_type_variation("TallerTarjetaPanel", "PanelContainer")
	t.set_stylebox("panel", "TallerTarjetaPanel", _box(c("panel"), c("line"), 14, 14, 12))
	t.set_type_variation("TallerRecuadro", "PanelContainer")
	t.set_stylebox("panel", "TallerRecuadro", _box(c("bg2"), c("line"), 10, 10, 8))
	t.set_type_variation("TallerBanda", "PanelContainer")
	t.set_stylebox("panel", "TallerBanda", _box(c("gold").darkened(0.72), c("gold").darkened(0.3), 10, 12, 8))
	t.set_stylebox("panel", "PanelContainer", _box(c("bg"), c("bg"), 0, 0, 0, 0))
	# Deslizadores, barras, texto editable y listas
	var track := _box(c("panel3"), c("line2"), 4, 0, 3)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(c("mint").darkened(0.2), c("mint").darkened(0.2), 4, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(c("mint"), c("mint"), 4, 0, 3))
	t.set_stylebox("background", "ProgressBar", _box(c("panel3"), c("line"), 5, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(c("mint"), c("mint"), 5, 0, 0))
	t.set_color("font_color", "ProgressBar", c("text"))
	t.set_stylebox("normal", "TextEdit", _box(c("bg2"), c("line"), 8, 8, 6))
	t.set_stylebox("focus", "TextEdit", _box(c("bg2"), c("mint").darkened(0.3), 8, 8, 6))
	t.set_stylebox("read_only", "TextEdit", _box(c("bg2"), c("line"), 8, 8, 6))
	t.set_color("font_color", "TextEdit", c("text"))
	t.set_color("font_readonly_color", "TextEdit", c("dim"))
	t.set_color("caret_color", "TextEdit", c("mint"))
	t.set_color("selection_color", "TextEdit", Color(c("mint"), 0.3))
	t.set_color("current_line_color", "TextEdit", Color(c("panel3"), 0.6))
	t.set_font_size("font_size", "TextEdit", 12)
	t.set_stylebox("panel", "PopupMenu", _box(c("panel2"), c("line2"), 8, 6, 6))
	t.set_color("font_color", "PopupMenu", c("text"))
	t.set_color("font_hover_color", "PopupMenu", c("mint"))
	t.set_stylebox("hover", "PopupMenu", _box(c("panel3"), c("panel3"), 6, 6, 3))
	t.set_color("font_color", "CheckButton", c("text"))
	t.set_color("font_pressed_color", "CheckButton", c("mint"))
	t.set_color("font_hover_color", "CheckButton", c("text"))
	t.set_color("font_hover_pressed_color", "CheckButton", c("mint"))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 4)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	_theme = t
	return t


# ── Fábricas pequeñas (sin estado) ──

static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120.0
	return l


static func button(text: String, variation: String = "", toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	return b


## Fila de fichas conmutables (una sola pulsada, como radio): [[id, texto], …]. Devuelve { box, buttons: id → Button }.
## into: un contenedor de flujo ya existente donde añadirlas (así varias filas de fichas comparten la misma barra
## sin anidar contenedores de flujo, que se apilarían en columna).
static func chips(items: Array, on_pick: Callable, into: Container = null) -> Dictionary:
	var box: Container = into if into != null else HFlowContainer.new()
	var group := ButtonGroup.new()
	var buttons := {}
	for it in items:
		var b := button(str(it[1]), "TallerFicha", true)
		b.button_group = group
		b.pressed.connect(on_pick.bind(it[0]))
		box.add_child(b)
		buttons[it[0]] = b
	return { "box": box, "buttons": buttons }


## Marca la ficha id sin emitir señales.
static func pick_chip(buttons: Dictionary, id: Variant) -> void:
	for k in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)


## Desplegable con [[id, texto], …]; on_pick recibe el id.
static func options(items: Array, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.clip_text = true
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = []
	for it in items:
		o.add_item(str(it[1]))
		ids.append(it[0])
	o.set_meta("ids", ids)
	o.item_selected.connect(func(i: int) -> void: on_pick.call(ids[i]))
	return o


static func pick_option(o: OptionButton, id: Variant) -> void:
	var ids: Array = o.get_meta("ids", [])
	var i := ids.find(id)
	if i >= 0 and o.selected != i:
		o.select(i)


## Deslizador con su rótulo: devuelve { row, slider, value }. on_change recibe el valor.
static func slider(title: String, lo: float, hi: float, step: float, on_change: Callable) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var t := label(title, "TallerTenue", true)  # se parte en pantallas estrechas
	head.add_child(t)
	var v := label("", "TallerDato")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(v)
	row.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 20.0
	s.value_changed.connect(on_change)
	row.add_child(s)
	return { "row": row, "slider": s, "value": v }


## Quita y libera los hijos de un contenedor (listas que se rehacen).
static func clear(box: Node) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


## Rejilla de lecturas: dos columnas (nombre · valor).
static func grid(columns: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


## Añade una fila «nombre · valor» a una rejilla y devuelve la etiqueta del valor.
static func grid_row(g: GridContainer, name: String, variation: String = "TallerDato") -> Label:
	var n := label(name, "TallerTenue")
	g.add_child(n)
	var v := label("—", variation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(v)
	return v


## Barra de 0 a 1 (potencia, limpieza, riesgo…).
static func bar(color_name: String = "mint") -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.step = 0.0
	p.show_percentage = false
	p.custom_minimum_size = Vector2(60, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if color_name != "mint":
		p.add_theme_stylebox_override("fill", _box(c(color_name), c(color_name), 5, 0, 0))
	return p


## Muestra de color (revenido, chispas…).
static func swatch(color: Color, w: float = 16.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(w, 14)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r
