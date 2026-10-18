## Hoja superpuesta (Fundamentos, Créditos): oscurece la sección, muestra una tarjeta con título, botón de cerrar y
## contenido con desplazamiento. Se cierra con el botón, con Escape o pulsando fuera. Se adapta al teléfono.
## - Teclado: al abrirse, el foco va a «Cerrar»; Tab y Mayús + Tab dan la vuelta dentro de la hoja (no se escapan a la
##   página de detrás) y, al cerrarla, el foco vuelve a donde estaba.
## - Alto: el del contenido, hasta el de la ventana (una hoja corta, como «Gráficos», no se estira).
## Uso: var o := Overlay.new("Fundamentos físicos"); o.content.add_child(…); add_child(o); o.open()
extends Control

signal closed

const Ui = preload("res://app/common/ui.gd")
const Palette = preload("res://app/theme/palette.gd")
const Pill = preload("res://app/common/pill.gd")

const MAX_W := 780.0
## Por debajo de este ancho, la hoja va pegada a los bordes y «Cerrar» mide TOUCH_MIN de alto (teléfono).
const NARROW := 600.0
const TOUCH_MIN := 44.0

var content: VBoxContainer
var sheet: PanelContainer
var title_label: Label
var close_button: Button
var scroll: ScrollContainer
## Quién tenía el foco al abrir la hoja (vuelve a él al cerrarla).
var _return_focus: Control


func _init(title := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(Palette.color("bg"), 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	sheet = PanelContainer.new()
	sheet.theme_type_variation = &"Sheet"
	add_child(sheet)
	var col := Ui.vbox(12)
	sheet.add_child(col)
	var head := Ui.hbox(10)
	title_label = Ui.label(title, "CardTitle")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title_label)
	close_button = Pill.new("✕  Cerrar", "IconButton", false)
	close_button.accessibility_name = "Cerrar"
	close_button.pressed.connect(close)
	head.add_child(close_button)
	col.add_child(head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# el hueco de la barra, reservado: el ancho del texto no depende de si hace falta desplazarse (y el alto de la hoja,
	# que sale del texto, tampoco vuelve a cambiar la barra)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true  # con el teclado, lo que recibe el foco se desplaza hasta verse
	col.add_child(scroll)
	content = Ui.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	resized.connect(_layout)
	content.minimum_size_changed.connect(_on_content_changed)


func open() -> void:
	if is_inside_tree() and not visible:
		_return_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_layout()
	scroll.scroll_vertical = 0
	if is_inside_tree():
		close_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null


func _layout() -> void:
	var narrow := size.x < NARROW
	var w := minf(MAX_W, size.x - 24.0)
	var top := 12.0 if narrow else 40.0
	close_button.custom_minimum_size.y = TOUCH_MIN if narrow else 0.0
	var room := maxf(120.0, size.y - top - 12.0)
	# el alto del contenido más el de la cabecera y los márgenes de la hoja, hasta el de la ventana
	var need := sheet.get_combined_minimum_size().y + content.get_combined_minimum_size().y
	sheet.position = Vector2(floorf((size.x - w) / 2.0), top)
	sheet.size = Vector2(w, clampf(need, 120.0, room))


## El contenido cambia de alto (se rellena, o el texto se parte al ancho de la hoja): la hoja se ajusta.
func _on_content_changed() -> void:
	if visible:
		_layout.call_deferred()


## Tab y Mayús + Tab dan la vuelta dentro de la hoja: los controles de la página de detrás no reciben el foco.
func _input(e: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	var back := e.is_action_pressed("ui_focus_prev")
	if not back and not e.is_action_pressed("ui_focus_next"):
		return
	var items := focusables()
	if items.is_empty():
		return
	var i := items.find(get_viewport().gui_get_focus_owner())
	var next: Control
	if i < 0:
		next = items[-1] if back else items[0]
	else:
		next = items[(i + (items.size() - 1 if back else 1)) % items.size()]
	next.grab_focus()
	get_viewport().set_input_as_handled()


## Lo que puede recibir el foco dentro de la hoja, en el orden del árbol («Cerrar» primero).
func focusables() -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in sheet.find_children("*", "Control", true, false):
		var c := n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not (c is BaseButton and (c as BaseButton).disabled):
			out.append(c)
	return out


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		close()


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
