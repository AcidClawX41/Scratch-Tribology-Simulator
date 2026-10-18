## Tribology Simulator & Industrial Workshop 2.0 (antes Scratch Tribology Simulator): un solo programa con dos
## secciones, «Tribología biológica» (el laboratorio de la 1.x) y «Taller industrial». Barra superior (nombre, selector de sección, Fundamentos y sonido), la sección visible
## y un pie con la versión, la licencia y los créditos (Godot y sus componentes).
## Donaciones (petición 39): el botón «Dona o invítame» va con Fundamentos y Sonido, así que se ve en las dos secciones (en
## el teléfono, en el pie). Abre una hoja con el texto de Eric y sus enlaces (AppInfo.DONATE_*), que se abren en el
## navegador del sistema al pulsarlos: el programa no hace ninguna llamada a la red.
##
## Contrato de las secciones (detalle en docs/taller/fuentes-u12.md):
## - bio: res://app/lab/lab_section.tscn · taller: res://app/taller/taller_section.tscn si existe
##   (ResourceLoader.exists); si no, un aviso «en construcción». Cada una se instancia la primera vez que se muestra.
## - La raíz de cada sección es un Control a pantalla completa. Al cambiar de sección, la oculta pasa a
##   PROCESS_MODE_DISABLED (se paran su animación y su sonido) y la visible, a PROCESS_MODE_INHERIT.
## - Opcionales en la raíz: headline() (titular de la barra), fundamentos() → [[título, texto]] y fundamentos_note(); y
##   la señal headline_changed(text), si la sección tiene varias páginas con su propio titular, con headlines() → todos
##   ellos (la barra elige su forma con el más largo, así no cambia al pasar de página).
##   Sin fundamentos(), el botón «Fundamentos» se oculta.
## - Sonido: cada sección usa su bus (el laboratorio, «Lab»; el taller, «Maquina»); el interruptor general silencia
##   «Master».
## Ajustes en user://ajustes.cfg, sección [app]: section (bio o taller) y sound (true o false).
## Gráficos (petición 50, solo en escritorio): el botón «Gráficos» del pie elige el renderizador, Vulkan (Forward+) u
## OpenGL (Compatibility); se guarda en user://graficos.cfg, que Godot lee al arrancar, y el programa se reinicia
## (app/common/renderer_choice.gd).
## Escala: tamaño lógico = ventana / escala de la pantalla (sin estirar el lienzo de 1240 × 880 del proyecto), para
## que el diseño se adapte de verdad: dos columnas en escritorio y una en el teléfono. --escala=N la fuerza.
extends Control

const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Lab = preload("res://core/lab/lab.gd")
const AppInfo = preload("res://core/shared/app_info.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Art = preload("res://core/lab/art.gd")
const Ui = preload("res://app/common/ui.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ArtView = preload("res://app/common/art_view.gd")
const Overlay = preload("res://app/common/overlay.gd")
const Pill = preload("res://app/common/pill.gd")
const Segmented = preload("res://app/common/segmented.gd")
const SfxPlayer = preload("res://app/common/sfx_player.gd")
const WrapBox = preload("res://app/common/wrap_box.gd")
const DonateCard = preload("res://app/common/donate_card.gd")
const RendererChoice = preload("res://app/common/renderer_choice.gd")

const SETTINGS := "user://ajustes.cfg"
const LAB_SCENE := "res://app/lab/lab_section.tscn"
const TALLER_SCENE := "res://app/taller/taller_section.tscn"
const SECTIONS := [["bio", "Tribología biológica"], ["taller", "Taller industrial"]]
## Crédito de la fuente de emoji (un subconjunto: godot/tools/emoji.mjs).
const EMOJI_CREDIT := ("Subconjunto de Noto Color Emoji 2.047 © 2022 Google Inc. (github.com/googlefonts/noto-emoji), con "
	+ "licencia SIL Open Font License 1.1: solo los emoji que usan los textos del programa.")
## Ancho por debajo del cual la barra superior se compacta (teléfono).
const NARROW := 700.0
## Escritorio: tamaños del titular, del preferido al más pequeño. Si no cabe a 28 px, se encoge antes de cortarlo.
const HEADLINE_SIZES := [28, 26, 24, 22, 20]
## El titular más largo de la sección decide la forma de la barra medido a este tamaño (así la barra no cambia al pasar
## de página: solo el tamaño del titular).
const HEADLINE_REF_SIZE := 22
## Formas de la barra en escritorio, de la más completa a la más compacta (_set_bar_level): 0, todo con su texto; 1,
## Sonido solo con el altavoz; 2, y «Invítame»; 3, y las secciones con el nombre corto; 4, y Fundamentos solo con «∑».
const BAR_LEVELS := 5
## Teléfono: tamaños del titular, del preferido al más pequeño (se elige el más grande con el que cabe en dos líneas) y,
## del más espaciado al más apretado, el espacio entre letras y el tamaño del nombre del programa, para que se lea
## entero en una línea.
const NARROW_HEADLINES := [21, 20, 19, 18, 17]
const NARROW_KICKER := [[2, 11], [1, 11], [0, 11], [0, 10]]
## Alto mínimo de lo que se pulsa con el dedo en el teléfono (los botones del pie y el de cerrar las hojas).
const TOUCH_MIN := 44.0
## Margen lateral de la barra de arriba (el de bar_pad, a los dos lados).
const BAR_PAD_X := 32.0

## Ajustes: se puede cambiar la ruta (tests) o no guardar nada (demo).
var settings_path := SETTINGS
var remember := true
var sound_on := true
var current := ""
var pages := {}  # id → Control (raíz de la sección)
var art: ArtCache
var ui_sound: SfxPlayer
var host: Control
var topbar: WrapBox
var brand: HBoxContainer
var logo_box: PanelContainer
var kicker: Label
var headline: Label
var selector: Segmented
var fund_button: Pill
var sound_button: Pill
var footer_label: Label
var credits_button: Pill
var donate_button: Pill
var fund_overlay: Overlay
var credits_overlay: Overlay
var donate_overlay: Overlay
## Gráficos (null donde no se puede elegir el renderizador: teléfono y web).
var graphics_button: Pill
var graphics_overlay: Overlay
var graphics_picker: Segmented
var graphics_note: Label
var restart_button: Button
## Dónde se guarda la elección del renderizador (los tests la cambian) y cómo se reinicia (los tests no salen).
var renderer_path := RendererChoice.OVERRIDE_PATH
var restarter: Callable = func() -> void: RendererChoice.restart(get_tree())
## Cómo se abre un enlace de donación (los tests lo cambian para no abrir el navegador).
var link_opener: Callable = func(url: String) -> void: OS.shell_open(url)
## La fecha del texto de las donaciones (la edad de Eric, petición 41): la del sistema, o esta si no está vacía (tests).
var today_override: Dictionary = {}
var _built := false
var _mute_serial := 0
var _glows: Array = []
var _narrow := false
var _laid_out := false
## Forma de la barra en escritorio (0 … BAR_LEVELS - 1) y el ancho del titular más largo visto a HEADLINE_REF_SIZE.
var _bar_level := 0
var _headline_ref := 0.0
## Las variaciones del nombre del programa en el teléfono (NARROW_KICKER), hechas una vez.
var _kicker_fonts := {}
var _fund_for := ""
var actions: HBoxContainer
var foot: HBoxContainer


func _ready() -> void:
	_apply_window()
	setup()
	show_section(_initial_section())


## Escala de la interfaz: la de la pantalla (Retina ×2, teléfonos ×2-×3) o la de --escala=N.
func ui_scale() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--escala="):
			return clampf(float(a.substr(9)), 0.5, 4.0)
	var s := DisplayServer.screen_get_scale()
	if OS.has_feature("mobile") and s <= 1.0:
		s = DisplayServer.screen_get_dpi() / 160.0
	return clampf(s, 1.0, 4.0)


func _apply_window() -> void:
	var win := get_window()
	# dentro de un SubViewport (la demo en modo teléfono) manda el tamaño de ese SubViewport
	if win == null or get_viewport() != win:
		return
	var s := ui_scale()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_factor = s
	win.min_size = Vector2i(Vector2(360, 560) * s)
	# En una pantalla HiDPI de escritorio, la ventana del proyecto (1240 × 880 px) se quedaría en la mitad de su
	# tamaño lógico: se agranda hasta el de diseño, sin salirse de la pantalla.
	if s > 1.0 and not OS.has_feature("mobile") and win.mode == Window.MODE_WINDOWED:
		var want := (Vector2(1240, 880) * s).min(Vector2(DisplayServer.screen_get_usable_rect(win.current_screen).size) * 0.95)
		if win.size.x < want.x * 0.9:
			win.size = Vector2i(want)
			win.move_to_center()


## Construye la interfaz (una vez). Los tests la llaman sin árbol de escena.
func setup() -> void:
	if _built:
		return
	_built = true
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = ArtCache.new()
	ui_sound = SfxPlayer.new("Master")
	add_child(ui_sound)
	sound_on = bool(_setting("sound", true))
	_apply_sound()
	var root := Ui.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bar_pad := Ui.margin(16, 12, 16, 10)
	topbar = WrapBox.new(14.0, 10.0)
	bar_pad.add_child(topbar)
	root.add_child(bar_pad)
	brand = Ui.hbox(12)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo_box = PanelContainer.new()
	logo_box.theme_type_variation = &"PreviewArt"
	logo_box.custom_minimum_size = Vector2(46, 46)
	# centrado en vertical: en el teléfono, el titular puede ir en dos líneas
	logo_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var logo := ArtView.new()
	logo.custom_minimum_size = Vector2(34, 40)
	logo.set_art(art, "ci:logo:%s" % Catalog.CLAWS[0].id, Art.claw_art.bind(Catalog.CLAWS[0], { "uid": "logo" }), Rect2(0, 0, 100, 132), [])
	logo_box.add_child(logo)
	brand.add_child(logo_box)
	var titles := Ui.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker = Ui.label(AppInfo.NAME, "Kicker")
	kicker.uppercase = true
	kicker.clip_text = true
	kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	kicker.custom_minimum_size.x = 120.0
	titles.add_child(kicker)
	headline = Ui.label("", "H1")
	headline.clip_text = true
	headline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	headline.custom_minimum_size.x = 120.0
	titles.add_child(headline)
	brand.add_child(titles)
	topbar.add_child(brand)
	var opts: Array = []
	for s: Array in SECTIONS:
		opts.append({ "id": s[0], "label": s[1] })
	selector = Segmented.new(opts, "", "Sección del programa")
	selector.selected.connect(_on_section_picked)
	topbar.add_child(selector)
	actions = Ui.hbox(8)
	fund_button = Pill.new("∑  Fundamentos", "IconButton")
	fund_button.pressed.connect(toggle_fundamentos)
	actions.add_child(fund_button)
	sound_button = Pill.new("", "IconButton")
	sound_button.pressed.connect(toggle_sound)
	actions.add_child(sound_button)
	donate_button = Pill.new(AppInfo.DONATE_BUTTON, "IconButton", false)
	donate_button.icon = AppTheme.cup_icon()
	donate_button.accessibility_name = AppInfo.DONATE_TITLE
	donate_button.tooltip_text = AppInfo.DONATE_TITLE
	donate_button.pressed.connect(show_donate)
	actions.add_child(donate_button)
	topbar.add_child(actions)
	host = Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	root.add_child(host)
	var foot_pad := Ui.margin(16, 6, 16, 8)
	foot = Ui.hbox(12)
	footer_label = Ui.para("", "Footer")
	foot.add_child(footer_label)
	credits_button = Pill.new("Créditos y licencias", "FooterLink", false)
	credits_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_button.pressed.connect(show_credits)
	foot.add_child(credits_button)
	if RendererChoice.available():
		graphics_button = Pill.new("Gráficos", "FooterLink", false)
		graphics_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		graphics_button.tooltip_text = "Elegir el renderizador: %s u OpenGL" % RendererChoice.label("vulkan").get_slice(" ", 0)
		graphics_button.accessibility_name = graphics_button.tooltip_text
		graphics_button.pressed.connect(show_graphics)
		foot.add_child(graphics_button)
	foot_pad.add_child(foot)
	root.add_child(foot_pad)
	footer_label.text = footer_note(version())
	fund_overlay = Overlay.new("Fundamentos físicos")
	fund_overlay.closed.connect(_on_fund_closed)
	add_child(fund_overlay)
	credits_overlay = Overlay.new("Créditos y licencias")
	add_child(credits_overlay)
	donate_overlay = Overlay.new(AppInfo.DONATE_TITLE)
	add_child(donate_overlay)
	if graphics_button != null:
		graphics_overlay = Overlay.new("Gráficos")
		add_child(graphics_overlay)
	_update_sound_button()
	resized.connect(_layout)
	_layout()


## Versión del programa (project.godot → application/config/version).
static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "2.0"))


## El pie del escritorio, en una línea: el nombre, la versión, el autor y la licencia. La de las tipografías está en
## «Créditos y licencias» (el texto entero de AppInfo.license_note); en dos líneas, «License 1.1.» quedaba sola.
static func footer_note(v: String) -> String:
	return AppInfo.license_note(v).get_slice(". ", 0)


## Teléfono (menos de NARROW px): la barra superior queda en dos filas (nombre y selector) y los botones de
## Fundamentos y Sonido, solo con su icono, bajan al pie junto a «Créditos», como una barra de pestañas.
func _layout() -> void:
	var narrow := size.x > 0.0 and size.x < NARROW
	if narrow != _narrow or not _laid_out:
		_laid_out = true
		_narrow = narrow
		selector.size_flags_horizontal = Control.SIZE_FILL if narrow else Control.SIZE_SHRINK_BEGIN
		var home: Container = foot if narrow else topbar
		if actions.get_parent() != home:
			actions.get_parent().remove_child(actions)
			home.add_child(actions)
			home.move_child(actions, 0 if narrow else home.get_child_count() - 1)
		fund_button.tooltip_text = "Fundamentos físicos"
		credits_button.text = "Créditos" if narrow else "Créditos y licencias"
		# en el teléfono el pie es la barra de pestañas (Fundamentos, Sonido, «Invítame» y Créditos), con botones de
		# TOUCH_MIN de alto; la versión y la licencia están en «Créditos»
		footer_label.visible = not narrow
		for b: Control in [fund_button, sound_button, donate_button, credits_button, graphics_button]:
			if b != null:
				b.custom_minimum_size.y = TOUCH_MIN if narrow else 0.0
		# el titular del teléfono salta a dos líneas antes que cortarse; en escritorio, se encoge (_fit_bar). Con el ajuste de
		# línea, ni recorte ni puntos suspensivos: con ellos, Godot le da 1 px de alto mínimo y el titular desaparece
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
		headline.clip_text = not narrow
		headline.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if narrow else TextServer.OVERRUN_TRIM_ELLIPSIS
		_label_graphics()
	_fit_bar()


## La barra de arriba sin cortar el nombre del programa ni el titular de la página.
## - Teléfono: el nombre, con menos espacio entre letras si hace falta (NARROW_KICKER), y el titular, en dos líneas si no
##   cabe en una.
## - Escritorio: la barra toma la forma más completa (BAR_LEVELS) en la que caben el nombre y el titular más largo de las
##   secciones abiertas a HEADLINE_REF_SIZE, y el titular de la página se encoge lo justo (HEADLINE_SIZES). Si ni la más
##   compacta deja sitio, la barra va en columna, con todos los textos enteros.
func _fit_bar() -> void:
	_headline_ref = _text_width(headline, headline.text, HEADLINE_REF_SIZE)
	for p: Control in pages.values():
		var hs: Array = p.call("headlines") if p.has_method("headlines") else []
		for h: Variant in hs:
			_headline_ref = maxf(_headline_ref, _text_width(headline, String(h), HEADLINE_REF_SIZE))
	if _narrow:
		_set_bar_level(BAR_LEVELS - 1)
		topbar.row_min = 0.0
		var full := size.x - BAR_PAD_X
		# en un teléfono muy estrecho (360 px), también la tribología va con su nombre corto
		if selector.get_combined_minimum_size().x > full:
			_label_sections(true, true)
		# «Gráficos» solo existe en escritorio: en una ventana más estrecha que el pie, se esconde (ensanchaba la página)
		if graphics_button != null:
			graphics_button.visible = true
			graphics_button.visible = foot.get_combined_minimum_size().x <= full
		_fit_kicker(full - _logo_width())
		_set_narrow_headline(full - _logo_width())
		return
	_fit_kicker(INF)
	if graphics_button != null:
		graphics_button.visible = true
	var avail := size.x - BAR_PAD_X
	if avail <= 0.0:  # sin tamaño todavía (los tests sin árbol): la barra entera
		_set_bar_level(0)
		headline.add_theme_font_size_override("font_size", HEADLINE_SIZES[0])
		return
	var need := maxf(_headline_ref, _kicker_width())
	for level in BAR_LEVELS:
		_set_bar_level(level)
		var room := _brand_room(avail)
		if room >= need:
			topbar.row_min = 0.0
			_set_headline_size(room)
			return
	# en columna: el nombre y el titular en su fila, y los botones con su texto en las suyas
	_set_bar_level(0)
	topbar.row_min = 1.0e9
	_set_headline_size(avail - _logo_width())


## Lo que ocupa el logo con su separación.
func _logo_width() -> float:
	return logo_box.get_combined_minimum_size().x + float(brand.get_theme_constant(&"separation"))


## El ancho que le queda al nombre y al titular en una sola fila con el selector y los botones de la forma de ahora.
func _brand_room(avail: float) -> float:
	var others := selector.get_combined_minimum_size().x + actions.get_combined_minimum_size().x + 2.0 * topbar.gap
	return avail - others - _logo_width()


## La forma de la barra en escritorio (BAR_LEVELS); en el teléfono, la más compacta.
func _set_bar_level(level: int) -> void:
	_bar_level = level
	donate_button.text = AppInfo.DONATE_BUTTON_SHORT if level >= 2 else AppInfo.DONATE_BUTTON
	_label_sections(level >= 3)
	fund_button.text = "∑" if level >= 4 else "∑  Fundamentos"
	_update_sound_button()


## El tamaño más grande de HEADLINE_SIZES con el que el titular cabe en room (o el más pequeño).
func _set_headline_size(room: float) -> void:
	var fs: int = HEADLINE_SIZES[-1]
	for s: int in HEADLINE_SIZES:
		if _text_width(headline, headline.text, s) <= room:
			fs = s
			break
	headline.add_theme_font_size_override("font_size", fs)


## Teléfono: el titular al tamaño más grande de NARROW_HEADLINES con el que cabe en dos líneas de room px.
func _set_narrow_headline(room: float) -> void:
	var font := headline.get_theme_font(&"font")
	var fs: int = NARROW_HEADLINES[-1]
	for s: int in NARROW_HEADLINES:
		# con margen: la etiqueta parte la línea un poco antes que la suma de anchos (con 296 de 300 px ya la partía)
		if _lines_needed(font, headline.text, s, room - 8.0) <= 2:
			fs = s
			break
	headline.add_theme_font_size_override("font_size", fs)


## Líneas que ocupa un texto partido por palabras en width px (como el autowrap de la etiqueta).
static func _lines_needed(font: Font, text: String, fs: int, width: float) -> int:
	var lines := 1
	var cur := ""
	for word in text.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if cur == "" or font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
			cur = t
		else:
			lines += 1
			cur = word
	return lines


## El nombre del programa: en escritorio, el del tema; en el teléfono, la variación más espaciada que cabe en room.
func _fit_kicker(room: float) -> void:
	if is_inf(room):
		kicker.remove_theme_font_override(&"font")
		kicker.remove_theme_font_size_override(&"font_size")
		return
	var text := AppInfo.NAME.to_upper()
	for i in NARROW_KICKER.size():
		var px: int = NARROW_KICKER[i][0]
		var fs: int = NARROW_KICKER[i][1]
		if not _kicker_fonts.has(px):
			_kicker_fonts[px] = AppTheme.spaced(px)
		var f: Font = _kicker_fonts[px]
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room or i == NARROW_KICKER.size() - 1:
			kicker.add_theme_font_override(&"font", f)
			kicker.add_theme_font_size_override(&"font_size", fs)
			return


func _kicker_width() -> float:
	return _text_width(kicker, AppInfo.NAME.to_upper(), kicker.get_theme_font_size(&"font_size"))


## Ancho de un texto en una línea con la fuente de la etiqueta l a fs px.
static func _text_width(l: Label, text: String, fs: int) -> float:
	return l.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _process(_delta: float) -> void:
	art.poll()


func _exit_tree() -> void:
	if art != null:
		art.dispose()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color("bg"))
	if _glows.is_empty():
		_glows = [_glow_texture(Color(Palette.color("rose"), 0.10), 0.60), _glow_texture(Color(Palette.color("mint"), 0.07), 0.58)]
	draw_texture_rect(_glows[0], Rect2(Vector2(size.x * 0.08, size.y * -0.12) - Vector2(1100, 560), Vector2(2200, 1120)), false)
	draw_texture_rect(_glows[1], Rect2(Vector2(size.x * 1.08, size.y * 0.06) - Vector2(900, 520), Vector2(1800, 1040)), false)


## Resplandor radial del fondo (los radial-gradient de .app en la 1.x): el color se apaga en `stop` del radio.
static func _glow_texture(col: Color, stop: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, stop, 1.0])
	g.colors = PackedColorArray([col, Color(col, 0.0), Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# ── Secciones ──

func _initial_section() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--section=") or a.begins_with("--seccion="):
			return a.substr(a.find("=") + 1)
	return String(_setting("section", "bio"))


func _on_section_picked(id: String) -> void:
	show_section(id)


## Muestra una sección («bio» o «taller») y, si remember, la recuerda para la próxima vez.
func show_section(id: String) -> void:
	if not SECTIONS.any(func(s: Array) -> bool: return s[0] == id):
		id = "bio"
	var page := _page(id)
	for k: String in pages:
		var p: Control = pages[k]
		var on := k == id
		p.visible = on
		p.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	current = id
	selector.set_value(id)
	headline.text = String(page.call("headline")) if page.has_method("headline") else _section_name(id)
	_fit_bar()
	fund_button.visible = page.has_method("fundamentos")
	if fund_overlay.visible and not fund_button.visible:
		fund_overlay.close()
	if remember:
		_save("section", id)


static func _section_name(id: String) -> String:
	for s: Array in SECTIONS:
		if s[0] == id:
			return s[1]
	return id


## La raíz de una sección (se instancia la primera vez).
func _page(id: String) -> Control:
	if pages.has(id):
		return pages[id]
	var page: Control = null
	var path := LAB_SCENE if id == "bio" else TALLER_SCENE
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var node: Node = scene.instantiate()
		page = node as Control
		if page == null:
			push_warning("La sección %s no tiene un Control como raíz: se muestra el aviso." % path)
			if node != null:
				node.free()
	if page == null:
		page = _placeholder(id)
	# cada sección guarda lo suyo en otra sección del mismo archivo de ajustes (la demo, remember = false, no guarda nada)
	if remember and "settings_path" in page:
		page.set("settings_path", settings_path)
	page.name = id
	host.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages[id] = page
	# una sección con varias páginas (la tribología biológica: banco y coche en marcha) cambia el titular con ellas
	if page.has_signal("headline_changed"):
		page.connect("headline_changed", _on_headline_changed.bind(id))
	return page


## El titular de la sección que se ve, cuando cambia de página.
func _on_headline_changed(text: String, id: String) -> void:
	if current == id:
		headline.text = text
		_fit_bar()


## Aviso de una sección que aún no está (el taller, mientras lo prepara otra unidad).
func _placeholder(id: String) -> Control:
	var c := CenterContainer.new()
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size.x = 320.0
	var col := Ui.vbox(10)
	col.add_child(Ui.label(_section_name(id), "CardTitle"))
	var p := Ui.para(("Sección en construcción: el torno manual y CNC Fagor, la radial contra chapa de coche y la afiladora "
		+ "llegarán aquí. Mientras, el laboratorio de Tribología biológica está completo."), "Body")
	p.custom_minimum_size.x = 300.0
	col.add_child(p)
	card.add_child(col)
	c.add_child(card)
	c.set_meta("placeholder", true)
	return c


# ── Fundamentos y créditos ──

func toggle_fundamentos() -> void:
	if fund_overlay.visible:
		fund_overlay.close()
		return
	var page: Control = pages.get(current)
	if page == null or not page.has_method("fundamentos"):
		return
	if _fund_for != current:
		_fill_fundamentos(page)
	fund_overlay.open()
	fund_button.set_on(true)
	fund_button.accessibility_name = "Ocultar fundamentos físicos"


## Los fundamentos de la sección (se escriben una vez por sección).
func _fill_fundamentos(page: Control) -> void:
	_fund_for = current
	for c in fund_overlay.content.get_children():
		fund_overlay.content.remove_child(c)
		c.queue_free()
	var list: Array = page.call("fundamentos")
	for item: Array in list:
		var r := RichTextLabel.new()
		r.theme_type_variation = &"Rich"
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.selection_enabled = true
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.text = "· [color=#%s][b]%s[/b][/color]: %s" % [Palette.color("text").to_html(false), _bb(item[0]), _bb(item[1])]
		fund_overlay.content.add_child(r)
	if page.has_method("fundamentos_note"):
		fund_overlay.content.add_child(Ui.para(String(page.call("fundamentos_note")), "Note"))


func _on_fund_closed() -> void:
	fund_button.set_on(false)
	fund_button.accessibility_name = "Ver fundamentos físicos"


static func _bb(s: String) -> String:
	return s.replace("[", "[lb]")


## Ventana de créditos: el programa y su licencia, las tipografías, Godot y sus componentes con sus licencias.
func show_credits() -> void:
	if credits_overlay.content.get_child_count() == 0:
		_fill_credits()
	credits_overlay.open()


func _fill_credits() -> void:
	var c := credits_overlay.content
	# un párrafo, no una etiqueta de una línea: en el teléfono, el nombre con la versión ensanchaba la hoja más que la
	# pantalla y dejaba «Cerrar» fuera
	c.add_child(Ui.para("%s %s" % [AppInfo.NAME, version()], "Title"))
	c.add_child(Ui.para(AppInfo.license_note(version()), "Body"))
	c.add_child(Ui.para("%s. Hasta la 1.x se llamaba %s; el laboratorio de tribología es el mismo." % [AppInfo.NAME_ES, AppInfo.PREVIOUS_NAME], "Note"))
	c.add_child(Ui.para("Textos completos en LICENSE y THIRD-PARTY-NOTICES.md. Sin red, sin telemetría: todo va dentro del programa.", "Note"))
	c.add_child(Ui.sub_label("Emoji"))
	c.add_child(Ui.para(EMOJI_CREDIT, "Body"))
	var info := Engine.get_version_info()
	c.add_child(Ui.sub_label("Motor"))
	c.add_child(Ui.para("Hecho con Godot Engine %s (godotengine.org), con licencia MIT." % String(info.get("string", "")), "Body"))
	c.add_child(_text_block(Engine.get_license_text()))
	c.add_child(Ui.sub_label("Componentes de Godot"))
	var parts := PackedStringArray()
	for comp: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in comp.get("parts", []):
			var who := ", ".join(PackedStringArray(part.get("copyright", [])))
			parts.append("%s · %s · %s" % [comp.get("name", ""), who, part.get("license", "")])
	c.add_child(_text_block("\n".join(parts)))
	c.add_child(Ui.sub_label("Licencias de los componentes"))
	var lic: Dictionary = Engine.get_license_info()
	for k: String in lic:
		c.add_child(Ui.label(k, "CardTitle"))
		c.add_child(_text_block(String(lic[k])))


## Hoja de gráficos: con qué renderizador va el programa ahora, las dos opciones con lo que cambia cada una y el botón
## de reiniciar, que se enciende cuando lo elegido no es lo que va ahora.
func show_graphics() -> void:
	if graphics_overlay == null:
		return
	if graphics_overlay.content.get_child_count() == 0:
		_fill_graphics()
	var want := RendererChoice.saved(renderer_path)
	graphics_picker.set_value(want if want != "" else RendererChoice.current())
	_update_graphics()
	graphics_overlay.open()


func _fill_graphics() -> void:
	var c := graphics_overlay.content
	c.add_child(Ui.para("Ahora: %s." % RendererChoice.current_text(), "Body"))
	var opts := []
	for id: String in RendererChoice.IDS:
		opts.append({"id": id, "label": RendererChoice.label(id), "title": RendererChoice.NOTES[id]})
	graphics_picker = Segmented.new(opts, RendererChoice.current(), "Renderizador")
	graphics_picker.selected.connect(_on_renderer_picked)
	c.add_child(graphics_picker)
	_label_graphics()
	graphics_note = Ui.para("", "Note")
	c.add_child(graphics_note)
	restart_button = Pill.new("Reiniciar ahora", "Pill", false)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	restart_button.pressed.connect(func() -> void: restarter.call())
	c.add_child(restart_button)


## Las dos opciones del renderizador: en una ventana estrecha, solo «Vulkan» y «OpenGL» (con el nombre entero en la ayuda
## emergente); con los nombres enteros, la hoja se salía de la pantalla del teléfono.
func _label_graphics() -> void:
	if graphics_picker == null:
		return
	for id: String in RendererChoice.IDS:
		var full := RendererChoice.label(id)
		graphics_picker.set_label(id, full.get_slice(" ", 0) if _narrow else full)
		(graphics_picker.buttons[id] as Button).tooltip_text = ("%s: %s" % [full, RendererChoice.NOTES[id]]) if _narrow else String(RendererChoice.NOTES[id])


func _on_renderer_picked(id: String) -> void:
	graphics_picker.set_value(id)
	if remember:
		RendererChoice.save(id, renderer_path)
	_update_graphics()


func _update_graphics() -> void:
	var id := graphics_picker.value
	var pending := id != RendererChoice.current()
	graphics_note.text = String(RendererChoice.NOTES[id]) + (
		"\nSe aplica al reiniciar el programa." if pending else "")
	restart_button.visible = pending


## Las secciones en desarrollo (AppInfo.WIP_SECTIONS, petición 40) llevan «· WIP» en el selector (en el teléfono, con el
## nombre corto) y su aviso en la ayuda emergente. Con all_short (un teléfono muy estrecho), todas van con el nombre
## corto, y el entero en la ayuda emergente.
func _label_sections(narrow: bool, all_short := false) -> void:
	for s: Array in SECTIONS:
		var id := String(s[0])
		var name := String(s[1])
		var short := name.get_slice(" ", 0)
		var b: Button = selector.buttons[id]
		if id in AppInfo.WIP_SECTIONS:
			selector.set_label(id, "%s · WIP" % (short if narrow else name))
			b.tooltip_text = AppInfo.WIP_NOTE
		else:
			selector.set_label(id, short if all_short else name)
			b.tooltip_text = name if all_short else ""


# ── Donaciones (petición 39) ──

## La hoja «Dona o invítame a un café»: el texto de Eric y un botón por enlace (los vacíos no salen).
func show_donate() -> void:
	if donate_overlay.content.get_child_count() == 0:
		fill_donate(AppInfo.donate_links())
	donate_overlay.open()


func fill_donate(links: Array) -> void:
	var c := donate_overlay.content
	c.add_theme_constant_override("separation", 14)
	var today := today_override if not today_override.is_empty() else Time.get_date_dict_from_system()
	var text := AppInfo.donate_text(today)
	# la entradilla: la taza y el saludo, en una caja con el rosa de la paleta
	var hero := PanelContainer.new()
	hero.name = "Entradilla"
	hero.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.rgba("rose", 0.07), 16, AppTheme.rgba("rose", 0.32), 1, 18.0, 16.0))
	var hero_row := Ui.hbox(16)
	var cup_box := PanelContainer.new()
	cup_box.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.rgba("rose", 0.14), 14, AppTheme.rgba("rose", 0.5), 1, 10.0, 10.0))
	cup_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cup := TextureRect.new()
	cup.texture = AppTheme.cup_icon(30)
	cup.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cup_box.add_child(cup)
	hero_row.add_child(cup_box)
	var hero_text := Ui.vbox(6)
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hello := Ui.para(String(text[0]), "Title")
	hello.add_theme_font_size_override("font_size", 17 if _narrow else 20)
	hero_text.add_child(hello)
	hero_text.add_child(_donate_para(String(text[1]), "text"))
	hero_row.add_child(hero_text)
	hero.add_child(hero_row)
	c.add_child(hero)
	# las secciones: su título en versalitas y sus párrafos, con aire entre ellas; la de apoyar, con las tarjetas
	for sec: Array in AppInfo.DONATE_SECTIONS:
		var box := Ui.vbox(14)
		box.add_child(Ui.label(String(sec[0]).to_upper(), "Kicker"))
		for k: int in sec[1]:
			if k < text.size():
				box.add_child(_donate_para(String(text[k])))
		if bool(sec[2]) and not links.is_empty():
			box.add_child(_donate_cards(links))
			box.add_child(Ui.para(AppInfo.DONATE_NOTE, "Note"))
		c.add_child(box)


## La fila de tarjetas de donación (en el teléfono, una debajo de otra), cada una con su enlace.
func _donate_cards(links: Array) -> Control:
	var row := WrapBox.new(12.0, 12.0)
	row.name = "Enlaces"
	row.equal = true
	for l: Dictionary in links:
		var br: Dictionary = DonateCard.brand(String(l.id))
		var b: Button = DonateCard.new(String(l.label), String(l.get("detail", "")), Color(String(br.color)), String(br.icon))
		b.name = "Donar_" + String(l.id)
		b.tooltip_text = String(l.url)
		b.accessibility_name = "Donar con %s: %s (se abre en el navegador)" % [String(l.label), String(l.get("detail", ""))]
		b.set_meta("url", String(l.url))
		b.pressed.connect(func() -> void: link_opener.call(String(l.url)))
		row.add_child(b)
	return row


## Un párrafo del texto de las donaciones: más grande y con más interlínea que el cuerpo normal, para leerlo de seguido.
static func _donate_para(text: String, color := "dim") -> Label:
	var l := Ui.para(text, "Body", color)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_constant_override("line_spacing", 8)
	return l


static func _text_block(text: String) -> Label:
	var l := Ui.para(text, "Note")
	l.add_theme_font_size_override("font_size", 10)
	return l


# ── Sonido ──

## Activa o silencia todo el programa (bus «Master») y lo recuerda. Suena la confirmación en los dos sentidos, como
## en la 1.x: al silenciar, el bus se calla cuando acaba el «off».
func toggle_sound() -> void:
	set_sound(not sound_on)


func set_sound(on: bool) -> void:
	sound_on = on
	_mute_serial += 1
	if on:
		_apply_sound()
		ui_sound.play("on", 0.6)
	else:
		ui_sound.play("off", 0.6)
		if is_inside_tree():
			get_tree().create_timer(ui_sound.length_of("off") + 0.05).timeout.connect(_mute_after.bind(_mute_serial))
		else:
			_apply_sound()
	_update_sound_button()
	_save("sound", on)


func _mute_after(serial: int) -> void:
	if serial == _mute_serial:
		_apply_sound()


func _apply_sound() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)


func _update_sound_button() -> void:
	sound_button.text = "" if (_narrow or _bar_level >= 1) else ("Sonido" if sound_on else "Silencio")
	sound_button.icon = AppTheme.speaker_icon(sound_on)
	sound_button.set_on(sound_on)
	sound_button.accessibility_name = ("Sonido activado: pulsa para silenciar" if sound_on
		else "Sonido desactivado: pulsa para activar")
	sound_button.tooltip_text = sound_button.accessibility_name


# ── Ajustes ──

func _setting(key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return default
	return cfg.get_value("app", key, default)


func _save(key: String, value: Variant) -> void:
	if not remember:
		return
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("app", key, value)
	cfg.save(settings_path)
