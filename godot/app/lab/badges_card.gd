## Tarjeta · Logros y cuaderno (BadgesCard de la 1.x): los logros ganados en oro y los pendientes en gris, y las
## últimas entradas del cuaderno (herramienta → material y veredicto con su color). La aplicación los recuerda entre
## sesiones (lab_section.gd → ajustes.cfg); «Reiniciar logros y cuaderno» los borra, con una segunda pulsación para
## confirmarlo. En el teléfono, al lado, el interruptor de la vibración (señal haptics_toggled; lo guarda la sección).
## Unidad 4p: debajo de los 15 de la 1.x (los que cuenta la cabecera, como en la 1.x), «Lo nuevo de la 2.0» con su propio
## contador (Lab.BADGES_V2: los del banco con la física 2.0 y los del coche en marcha).
extends "res://app/common/card.gd"

const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Palette = preload("res://app/theme/palette.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Pill = preload("res://app/common/pill.gd")

const RESET_TEXT := "Reiniciar logros y cuaderno"
const RESET_CONFIRM := "¿Seguro? Pulsa otra vez para borrarlo todo"
const HAPTICS_TEXT := ["Vibración: no", "Vibración: sí"]

## El usuario enciende o apaga la vibración (la sección la aplica y la guarda).
signal haptics_toggled(on: bool)

var lab: LabState
var count: Label
var badges := {}  # id → Label (los 15 de la 1.x: la cabecera cuenta solo estos, como en la 1.x)
## Unidad 4p: los logros de lo nuevo de la 2.0 (Lab.BADGES_V2), debajo, con su propio contador.
var count_v2: Label
var badges_v2 := {}  # id → Label
var book_box: VBoxContainer
var book_rows: Array = []  # [separador, herramienta → material, veredicto]
var reset_button: Pill
var haptics_button: Pill
## Lo que enseña el interruptor de la vibración (lo pone la sección con show_haptics).
var haptics_on := true
## Fila del pie: vibración (solo en el teléfono) y reiniciar, a la derecha; se parte en dos si no cabe.
var footer: HFlowContainer
## Primera pulsación de «Reiniciar»: espera la confirmación mientras no haya otro ensayo (el número de ensayos de
## entonces).
var _armed := -1


func _init() -> void:
	super("Logros de laboratorio")
	count = Ui.label("", "Small", "gold")
	right.add_child(count)
	var chips := Ui.flow()
	for b: Dictionary in Lab.BADGES:
		var l := Ui.label("", "BadgeOff")
		chips.add_child(l)
		badges[b.id] = l
	body.add_child(chips)
	# unidad 4p: lo nuevo de la 2.0 (aguijones, velocirraptor, zonas, hueso, ángulo, uña rota, ventanilla y coche en marcha)
	body.add_child(Ui.gap(4))
	var head_v2 := Ui.hbox(8)
	var title_v2 := Ui.sub_label("Lo nuevo de la 2.0")
	title_v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_v2.add_child(title_v2)
	count_v2 = Ui.label("", "Small", "gold")
	head_v2.add_child(count_v2)
	body.add_child(head_v2)
	var chips_v2 := Ui.flow()
	for b: Dictionary in Lab.BADGES_V2:
		var l := Ui.label("", "BadgeOff")
		chips_v2.add_child(l)
		badges_v2[b.id] = l
	body.add_child(chips_v2)
	book_box = Ui.vbox(0)
	book_box.add_child(Ui.gap(8))
	var title := Ui.sub_label("Cuaderno · últimos ensayos")
	book_box.add_child(title)
	book_box.add_child(Ui.gap(4))
	for i in LabState.LOG_SIZE:
		var line := ColorRect.new()
		line.color = Palette.color("line")
		line.custom_minimum_size.y = 1.0
		line.visible = i > 0
		book_box.add_child(line)
		var h := Ui.hbox(10)
		# en dos líneas si no cabe (4q): cortada con puntos suspensivos, en el teléfono se perdía justo el material
		# («Garra de gato → Coche moder…»)
		var what := Ui.para("", "Cell")
		what.custom_minimum_size.x = 60.0
		h.add_child(what)
		var v := Ui.label("", "Cell")
		h.add_child(v)
		var m := Ui.margin(0, 7, 0, 7)
		m.add_child(h)
		book_box.add_child(m)
		book_rows.append([line, m, what, v])
	body.add_child(book_box)
	footer = Ui.flow(14, 4)
	footer.alignment = FlowContainer.ALIGNMENT_END
	footer.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_END
	haptics_button = Pill.new(HAPTICS_TEXT[1], "FooterLink", false)
	haptics_button.visible = false
	haptics_button.tooltip_text = "Vibración del teléfono con los sonidos del ensayo"
	footer.add_child(haptics_button)
	reset_button = Pill.new(RESET_TEXT, "FooterLink", false)
	reset_button.accessibility_name = RESET_TEXT
	footer.add_child(reset_button)
	body.add_child(footer)


func setup(p_lab: LabState, _art: ArtCache) -> void:
	lab = p_lab
	reset_button.pressed.connect(_on_reset)
	haptics_button.pressed.connect(_on_haptics)


func _on_haptics() -> void:
	haptics_toggled.emit(not haptics_on)


## El interruptor de la vibración: se ve solo donde se puede vibrar (en el teléfono) y dice si está encendida.
func show_haptics(available: bool, on: bool) -> void:
	haptics_on = on
	haptics_button.visible = available
	haptics_button.text = HAPTICS_TEXT[int(on)]
	haptics_button.accessibility_name = ("Vibración activada: pulsa para apagarla" if on
			else "Vibración apagada: pulsa para activarla")
	footer.visible = haptics_button.visible or reset_button.visible


## Primera pulsación: pide confirmación. Segunda: borra logros, cuaderno y ensayos (LabState.reset_progress).
func _on_reset() -> void:
	if _armed != lab.count:
		_armed = lab.count
		refresh()
		return
	_armed = -1
	lab.reset_progress()


func refresh() -> void:
	count.text = "%s/%s" % [Ui.num(_paint_chips(Lab.BADGES, badges)), Ui.num(Lab.BADGES.size())]
	count_v2.text = "%s/%s" % [Ui.num(_paint_chips(Lab.BADGES_V2, badges_v2)), Ui.num(Lab.BADGES_V2.size())]
	_paint_book()


## Pinta las fichas de una lista de logros (★ en oro las ganadas, ○ en gris las que faltan) y devuelve cuántas hay ganadas.
func _paint_chips(list: Array, chips: Dictionary) -> int:
	var n := 0
	for b: Dictionary in list:
		var got: bool = lab.badges.has(b.id)
		n += 1 if got else 0
		var l: Label = chips[b.id]
		l.text = ("★ " if got else "○ ") + String(b.t)
		l.theme_type_variation = &"BadgeOn" if got else &"BadgeOff"
	return n


## El pie (reiniciar, con su confirmación) y el cuaderno.
func _paint_book() -> void:
	if _armed >= 0 and _armed != lab.count:
		_armed = -1  # otro ensayo: ya no se espera la confirmación
	reset_button.visible = lab.count > 0 or not lab.badges.is_empty()
	reset_button.text = RESET_CONFIRM if _armed >= 0 else RESET_TEXT
	reset_button.accessibility_name = reset_button.text
	footer.visible = haptics_button.visible or reset_button.visible
	reset_button.tooltip_text = "Borra los logros, el cuaderno y el número de ensayos que el programa recuerda"
	var book: Array = lab.notebook
	book_box.visible = not book.is_empty()
	for i in book_rows.size():
		var parts: Array = book_rows[i]
		var on := i < book.size()
		(parts[0] as Control).visible = on and i > 0
		(parts[1] as Control).visible = on
		if on:
			var e: Dictionary = book[i]
			(parts[2] as Label).text = "%s → %s" % [e.tool, e.tgt]
			(parts[2] as Label).tooltip_text = (parts[2] as Label).text
			(parts[3] as Label).text = String(e.verdict)
			Ui.set_color(parts[3], Palette.color(e.col))
