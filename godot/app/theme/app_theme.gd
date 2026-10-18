## Tema de la interfaz: el lenguaje visual de la 1.x (apps/desktop/src/styles.css y los estilos inline de las
## tarjetas) como un Theme de Godot construido en código. La paleta es la única del programa (palette.gd lee
## core/shared/theme.gd) y las tipografías son las empaquetadas: Syne para títulos (600, 700 y 800) y Space Mono para
## datos (400 y 700), con los emoji de un subconjunto de Noto Color Emoji de reserva. Sin CSS: cada clase de la 1.x es
## una variación de tipo (theme_type_variation):
##   paneles      Card · PreviewArt · BenchBox · SectionBox · Metric · VerdictBox · SegBox · Row · RowOn · Sheet
##   botones      Pill · PillGold · SegButton · Tile · IconButton · RowButton · FooterLink · RunButton
##   textos       Kicker · H1 · CardTitle · Title · SubLabel · Note · Body · Small · Display · StatKey · StatVal ·
##                Verdict · VerdictSmall · MetricValue · TileLabel · TileSub · RowName · Tag · StepBadge · Badge*
##   texto rico   MetricTitle · Rich
## El foco se ve siempre (contorno menta, como el :focus-visible de la 1.x).
## Uso: const AppTheme = preload("res://app/theme/app_theme.gd"); control.theme = AppTheme.get_theme()
extends RefCounted

const Palette = preload("res://app/theme/palette.gd")

const MONO = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const MONO_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")
const DISP_SEMI = preload("res://assets/fonts/syne-latin-600-normal.woff2")
const DISP = preload("res://assets/fonts/syne-latin-700-normal.woff2")
const DISP_BLACK = preload("res://assets/fonts/syne-latin-800-normal.woff2")
## Emoji: subconjunto de Noto Color Emoji (SIL OFL 1.1) con solo los que usan los textos (godot/tools/emoji.mjs lo
## regenera). Va de reserva de las cinco tipografías: así los emoji no dependen de las fuentes del sistema.
const EMOJI = preload("res://assets/fonts/noto-color-emoji-subset.ttf")

## Tamaño base del texto (px lógicos), el de la 1.x.
const BASE_SIZE := 12



## El tema del programa. main.gd lo construye una vez y las secciones lo heredan; una sección suelta (demo, tests)
## se construye el suyo.
static func get_theme() -> Theme:
	return build()


## Pone la fuente de emoji de reserva de las tipografías del programa (una vez; las variaciones de spaced() usan la de
## su tipografía base).
static func emoji_fallback() -> void:
	for f: Font in [MONO, MONO_BOLD, DISP_SEMI, DISP, DISP_BLACK]:
		if not f.fallbacks.has(EMOJI):
			var fb := f.fallbacks.duplicate()
			fb.append(EMOJI)
			f.fallbacks = fb


## Color de la paleta con opacidad (rgba de la 1.x).
static func rgba(name: String, alpha: float) -> Color:
	return Color(Palette.color(name), alpha)


## Space Mono con espaciado entre letras (letter-spacing de la 1.x), en px enteros.
static func spaced(px: int, bold := false) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = MONO_BOLD if bold else MONO
	f.spacing_glyph = px
	return f


static func build() -> Theme:
	emoji_fallback()
	var t := Theme.new()
	t.default_font = MONO
	t.default_font_size = BASE_SIZE
	_labels(t)
	_panels(t)
	_buttons(t)
	_ranges(t)
	_misc(t)
	return t


# ── Cajas ──

static func box(bg: Color, radius: int, border := Color.TRANSPARENT, bw := 0, pad_h := 0.0, pad_v := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func empty(pad_h := 0.0, pad_v := 0.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Contorno de foco: 2 px menta, separado 2 px del control (outline-offset de la 1.x).
static func focus_box(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Palette.color("mint")
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius + 3)
	s.set_expand_margin_all(3.0)
	s.anti_aliasing = true
	return s


static func _label(t: Theme, type: String, font: Font, size: int, color: String, base := "Label") -> void:
	t.set_type_variation(type, base)
	t.set_font("font" if base == "Label" else "normal_font", type, font)
	t.set_font_size("font_size" if base == "Label" else "normal_font_size", type, size)
	t.set_color("font_color" if base == "Label" else "default_color", type, Palette.color(color))


# ── Textos ──

static func _labels(t: Theme) -> void:
	t.set_color("font_color", "Label", Palette.color("text"))
	t.set_constant("line_spacing", "Label", 3)
	_label(t, "Kicker", spaced(2), 11, "mint")
	_label(t, "H1", DISP_BLACK, 28, "text")
	_label(t, "CardTitle", DISP, 15, "text")
	_label(t, "Title", DISP_BLACK, 18, "text")
	_label(t, "SubLabel", spaced(1), 11, "dimmer")
	_label(t, "Note", MONO, 11, "dimmer")
	t.set_constant("line_spacing", "Note", 5)
	_label(t, "Body", MONO, 12, "dim")
	t.set_constant("line_spacing", "Body", 6)
	_label(t, "Small", MONO, 11, "dimmer")
	_label(t, "Footer", MONO, 11, "dimmer")
	t.set_constant("line_spacing", "Footer", 5)
	_label(t, "Display", MONO_BOLD, 15, "rose")
	_label(t, "SliderLabel", MONO, 13, "dim")
	_label(t, "StatKey", MONO, 12, "dimmer")
	_label(t, "StatVal", MONO, 12, "mint")
	_label(t, "Verdict", DISP_BLACK, 25, "text")
	_label(t, "VerdictSmall", DISP_BLACK, 18, "text")
	_label(t, "MetricValue", MONO, 14, "text")
	_label(t, "TileLabel", DISP, 12, "dim")
	_label(t, "TileSub", MONO, 11, "dimmer")
	_label(t, "RowName", DISP, 14, "text")
	_label(t, "PillText", DISP, 13, "dim")
	_label(t, "PillMono", MONO, 11, "dim")
	_label(t, "Cell", MONO, 12, "dim")
	# etiquetas con fondo (.tag, .step y los logros)
	_label(t, "Tag", MONO_BOLD, 11, "bg")
	t.set_stylebox("normal", "Tag", box(Palette.color("gold"), 7, Color.TRANSPARENT, 0, 8.0, 2.0))
	_label(t, "StepBadge", MONO, 13, "gold")
	t.set_stylebox("normal", "StepBadge", box(Palette.color("panel3"), 9, Palette.color("line2"), 1, 7.0, 3.0))
	_label(t, "BadgeOn", MONO, 12, "bg")
	t.set_stylebox("normal", "BadgeOn", box(Palette.color("gold"), 9, Palette.color("gold"), 1, 10.0, 6.0))
	_label(t, "BadgeOff", MONO, 12, "dimmer")
	t.set_stylebox("normal", "BadgeOff", box(Palette.color("panel2"), 9, Palette.color("line"), 1, 10.0, 6.0))
	# texto rico: títulos de las métricas (con su símbolo) y párrafos con negritas
	t.set_font("normal_font", "RichTextLabel", MONO)
	t.set_font("bold_font", "RichTextLabel", MONO_BOLD)
	t.set_font_size("normal_font_size", "RichTextLabel", BASE_SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", BASE_SIZE)
	t.set_color("default_color", "RichTextLabel", Palette.color("dim"))
	t.set_constant("line_separation", "RichTextLabel", 5)
	t.set_stylebox("normal", "RichTextLabel", empty())
	t.set_stylebox("focus", "RichTextLabel", empty())
	_label(t, "MetricTitle", spaced(1), 10, "dimmer", "RichTextLabel")
	_label(t, "Rich", MONO, 12, "dim", "RichTextLabel")
	t.set_font("bold_font", "Rich", MONO_BOLD)
	t.set_font_size("bold_font_size", "Rich", 12)
	t.set_constant("line_separation", "Rich", 7)


# ── Paneles ──

static func _panel(t: Theme, type: String, s: StyleBox) -> void:
	t.set_type_variation(type, "PanelContainer")
	t.set_stylebox("panel", type, s)


static func _panels(t: Theme) -> void:
	var card := box(Palette.color("panel"), 20, Palette.color("line"), 1, 16.0, 16.0)
	card.content_margin_bottom = 18.0
	card.shadow_color = Color(0, 0, 0, 0.28)
	card.shadow_size = 14
	card.shadow_offset = Vector2(0, 8)
	_panel(t, "Card", card)
	var mixed := Palette.color("panel2").lerp(Palette.color("panel3"), 0.45)
	_panel(t, "PreviewArt", box(mixed, 16, Palette.color("line"), 1, 6.0, 6.0))
	var bench := box(Palette.color("panel2").lerp(Palette.color("panel3"), 0.3), 16, Palette.color("line"), 1, 6.0, 6.0)
	bench.content_margin_bottom = 2.0
	_panel(t, "BenchBox", bench)
	_panel(t, "SectionBox", box(Palette.color("panel2"), 14, Palette.color("line"), 1, 10.0, 10.0))
	_panel(t, "Metric", box(Palette.color("panel2"), 12, Palette.color("line"), 1, 12.0, 10.0))
	_panel(t, "VerdictBox", box(Palette.color("panel2"), 14, Palette.color("line"), 1, 14.0, 12.0))
	_panel(t, "SegBox", box(Palette.color("bg"), 14, Palette.color("line"), 1, 4.0, 4.0))
	_panel(t, "Row", empty())
	var hl := box(Palette.color("panel3"), 8, Color.TRANSPARENT, 0, 0.0, 0.0)
	_panel(t, "RowOn", hl)
	var sheet := box(Palette.color("panel"), 20, Palette.color("line2"), 1, 18.0, 16.0)
	sheet.shadow_color = Color(0, 0, 0, 0.45)
	sheet.shadow_size = 24
	sheet.shadow_offset = Vector2(0, 12)
	_panel(t, "Sheet", sheet)
	t.set_stylebox("panel", "PanelContainer", empty())
	t.set_stylebox("panel", "ScrollContainer", empty())
	t.set_stylebox("focus", "ScrollContainer", empty())
	t.set_stylebox("panel", "TooltipPanel", box(Palette.color("panel3"), 9, Palette.color("line2"), 1, 10.0, 7.0))
	t.set_font("font", "TooltipLabel", MONO)
	t.set_font_size("font_size", "TooltipLabel", 12)
	t.set_color("font_color", "TooltipLabel", Palette.color("text"))


# ── Botones ──

## Estilos de un botón: normal, encima, pulsado (y pulsado con el ratón encima), desactivado y foco.
static func _button(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, font: Font, size: int,
		col: String, col_hover: String, col_pressed: String, radius: int) -> void:
	t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, normal)
	t.set_stylebox("focus", type, focus_box(radius))
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, Palette.color(col))
	t.set_color("font_focus_color", type, Palette.color(col))
	t.set_color("font_hover_color", type, Palette.color(col_hover))
	t.set_color("font_pressed_color", type, Palette.color(col_pressed))
	t.set_color("font_hover_pressed_color", type, Palette.color(col_pressed))
	t.set_color("font_disabled_color", type, Palette.color("dimmer"))
	t.set_constant("h_separation", type, 7)


static func _buttons(t: Theme) -> void:
	var p := Palette.color("panel2")
	# .pill: píldora; pulsada, rosa con el texto oscuro
	_button(t, "Pill", box(p, 11, Palette.color("line"), 1, 12.0, 8.0), box(p, 11, Palette.color("line2"), 1, 12.0, 8.0),
		box(Palette.color("rose"), 11, Palette.color("rose"), 1, 12.0, 8.0), DISP, 13, "dim", "text", "bg", 11)
	# el botón de fuerza máxima: píldora con borde y texto oro
	_button(t, "PillGold", box(p, 11, Palette.color("gold"), 1, 12.0, 10.0), box(p.lerp(Palette.color("panel3"), 0.5), 11,
		Palette.color("gold"), 1, 12.0, 10.0), box(Palette.color("panel3"), 11, Palette.color("gold"), 1, 12.0, 10.0), DISP, 13,
		"gold", "gold", "gold", 11)
	# .seg button: segmento de un selector; el activo, sobre panel3 con borde interior
	var on := box(Palette.color("panel3"), 10, Palette.color("line2"), 1, 13.0, 8.0)
	on.shadow_color = Color(0, 0, 0, 0.25)
	on.shadow_size = 6
	on.shadow_offset = Vector2(0, 2)
	_button(t, "SegButton", empty(13.0, 8.0), empty(13.0, 8.0), on, DISP, 13, "dim", "text", "text", 10)
	# .tile: ficha con ilustración; la activa, con borde rosa y un halo
	var tile_on := box(Palette.color("panel3"), 14, Palette.color("rose"), 2, 4.0, 8.0)
	tile_on.shadow_color = rgba("rose", 0.16)
	tile_on.shadow_size = 10
	tile_on.shadow_offset = Vector2(0, 4)
	_button(t, "Tile", box(p, 14, Palette.color("line"), 1, 4.0, 8.0), box(Palette.color("panel3"), 14, Palette.color("line2"), 1, 4.0,
		8.0), tile_on, DISP, 12, "dim", "text", "text", 14)
	# .iconbtn: botones de la barra superior; activos, en menta
	_button(t, "IconButton", box(Palette.color("panel"), 12, Palette.color("line"), 1, 13.0, 9.0), box(Palette.color("panel"), 12,
		Palette.color("line2"), 1, 13.0, 9.0), box(Palette.color("panel"), 12, Palette.color("line2"), 1, 13.0, 9.0), MONO, 13, "dim",
		"text", "mint", 12)
	# filas de la comparativa: línea arriba; la herramienta en uso, sobre panel3
	var row := box(Color.TRANSPARENT, 12, Color.TRANSPARENT, 0, 8.0, 9.0)
	row.border_color = Palette.color("line")
	row.border_width_top = 1
	var row_hover := box(rgba("panel3", 0.5), 12, Color.TRANSPARENT, 0, 8.0, 9.0)
	row_hover.border_color = Palette.color("line")
	row_hover.border_width_top = 1
	_button(t, "RowButton", row, row_hover, box(Palette.color("panel3"), 12, Palette.color("line2"), 1, 8.0, 9.0), DISP, 14,
		"text", "text", "text", 12)
	# enlaces del pie y botones de cerrar
	_button(t, "FooterLink", empty(4.0, 2.0), empty(4.0, 2.0), empty(4.0, 2.0), MONO, 11, "mint", "text", "mint", 6)
	# ARAÑAR: el degradado lo pinta run_button.gd; aquí, la tipografía y el foco
	_button(t, "RunButton", empty(16.0, 16.0), empty(16.0, 16.0), empty(16.0, 16.0), DISP_BLACK, 18, "text", "text", "text", 16)
	t.set_color("font_color", "Button", Palette.color("dim"))
	t.set_font("font", "Button", DISP)
	t.set_font_size("font_size", "Button", 13)


# ── Deslizadores y barras de desplazamiento ──

static func _ranges(t: Theme) -> void:
	var track := box(Palette.color("line"), 6, Color.TRANSPARENT, 0, 0.0, 3.0)
	var fill := box(Palette.color("rose"), 6, Color.TRANSPARENT, 0, 0.0, 3.0)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("focus", "HSlider", focus_box(10))
	t.set_icon("grabber", "HSlider", _grabber(Palette.color("rose")))
	t.set_icon("grabber_highlight", "HSlider", _grabber(Palette.color("rose").lightened(0.25)))
	t.set_icon("grabber_disabled", "HSlider", _grabber(Palette.color("dimmer")))
	t.set_constant("center_grabber", "HSlider", 0)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, empty(3.0, 3.0))
		t.set_stylebox("scroll_focus", bar, empty(3.0, 3.0))
		t.set_stylebox("grabber", bar, box(Palette.color("line2"), 6, Color.TRANSPARENT, 0, 3.0, 3.0))
		t.set_stylebox("grabber_highlight", bar, box(Palette.color("dimmer"), 6, Color.TRANSPARENT, 0, 3.0, 3.0))
		t.set_stylebox("grabber_pressed", bar, box(Palette.color("dim"), 6, Color.TRANSPARENT, 0, 3.0, 3.0))


## Tirador del deslizador: círculo rosa con un aro del color del fondo y un anillo fino (como el de la 1.x).
static func _grabber(fill: Color) -> Texture2D:
	var f := "#" + fill.to_html(false)
	return icon_texture(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"22\" height=\"22\" viewBox=\"0 0 22 22\">"
		+ "<circle cx=\"11\" cy=\"11\" r=\"11\" fill=\"%s\"/><circle cx=\"11\" cy=\"11\" r=\"10\" fill=\"#%s\"/>"
		+ "<circle cx=\"11\" cy=\"11\" r=\"6.5\" fill=\"%s\"/></svg>") % [f, Palette.color("bg").to_html(false), f])


## Icono a partir de un SVG pequeño: DPITexture, que ThorVG vuelve a rasterizar a la escala de la pantalla.
static func icon_texture(svg: String) -> Texture2D:
	return DPITexture.create_from_string(svg)


## Altavoz de la 1.x (SpeakerIcon): con ondas si el sonido está activado; con un aspa si no.
static func speaker_icon(on: bool) -> Texture2D:
	var col := "#" + Palette.color("mint" if on else "dim").to_html(false)
	var waves := ("<path d=\"M16 9.5a4 4 0 0 1 0 5\"/><path d=\"M18.5 7a7.5 7.5 0 0 1 0 10\"/>" if on
		else "<path d=\"M17 9l5 6\"/><path d=\"M22 9l-5 6\"/>")
	return icon_texture(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" "
		+ "stroke=\"%s\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">"
		+ "<path d=\"M4 9v6h4l5 4V5L8 9H4z\" fill=\"%s\" stroke=\"none\"/>%s</svg>") % [col, col, waves])


## Taza de café con un corazón y su vapor (el botón «Dona o invítame», petición 39). Dibujo propio.
static func cup_icon(px := 18) -> Texture2D:
	var col := "#" + Palette.color("rose").to_html(false)
	return icon_texture(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 24 24\" fill=\"none\" " % [px, px]
		+ "stroke=\"%s\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">"
		+ "<path d=\"M4 10h12v4.5A5.5 5.5 0 0 1 10.5 20h-1A5.5 5.5 0 0 1 4 14.5z\"/>"
		+ "<path d=\"M16 11.5h1.5a2.5 2.5 0 0 1 0 5H16\"/>"
		+ "<path d=\"M8 3.5c-.8.9.8 1.6 0 2.5\"/><path d=\"M12 3.5c-.8.9.8 1.6 0 2.5\"/>"
		+ "<path d=\"M10 17.4l-1.9-1.8a1.2 1.2 0 0 1 1.7-1.7l.2.2.2-.2a1.2 1.2 0 0 1 1.7 1.7z\" fill=\"%s\" stroke=\"none\"/>"
		+ "</svg>") % [col, col])


# ── Contenedores ──

static func _misc(t: Theme) -> void:
	t.set_constant("separation", "BoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 7)
	t.set_constant("v_separation", "HFlowContainer", 7)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		t.set_constant(side, "MarginContainer", 0)
