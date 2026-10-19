## Tribología biológica · «Laboratorio experimental (reforja)» de la cetrería (unidad 5f; petición 35: la rama
## experimental del trabajo veterinario). Se fabrica una funda o una prótesis de otro material, como una corona dental, y
## se pega en frío: el horno-fundidor (ficción en conjunto: cada modo es una máquina real), la balanza y los polvos, el
## taller para tallar, proteger la carne viva, recubrir, pegar, pulir y probar; y la garra vuelve a la cetrería para
## limarla y pulirla allí, o al banco de ensayo.
## - El estado (core/lab/claw_forge_state.gd) corre en su hilo (forge_runner.gd): la página manda órdenes y pinta la última
##   vista. Aquí no se calcula nada: todo texto con números sale del estado o del motor.
## - La escena 3D (forge_3d.tscn) se crea la primera vez que la página se ve en el árbol (en los tests sin ventana, no).
## - Sonido por el bus «Lab»: los efectos de una vez con play_sfx (el de la sección) y el bucle de la máquina que trabaja
##   o de la muela (core/lab/sfx_forge.gd) con el volumen y el tono que pide el estado.
## - La página la enchufa la cetrería (care_page.plug_reforge_page): «Trabajo veterinario» vuelve a ella; «Pasar a la
##   cetrería para colocarla» lleva la funda terminada y sin pegar (ClawForge.care_setup, con la pieza; petición 43) y
##   «Probar en el banco», al banco de ensayo.
## - 5m (petición 42): la carga se mete en su máquina (M, o un clic en la puerta) antes de arrancar; la marcha dura el tiempo
##   de verdad a la velocidad elegida (X) y el reloj dice lo que lleva y lo que tardaría en la vida real; la cera perdida (C) en
##   un molde con la forma de la garra; el tallado por pasadas (G elige la herramienta, T una pasada, Mayús + T una suave) con
##   el indicador de la forma contra la silueta de la garra; la prueba del ajuste (U).
## - Con la garra rota, «Qué quieres hacer» y el tutorial ofrecen también el acrílico dental, la prótesis de verdad, junto a
##   las recetas de fantasía (unidad 5j); con la garra sana no salen.
## Teclado: en HELP_KEYS. Ratón y dedo: en HELP_MOUSE y HELP_TOUCH. En el teléfono, sobre la vista, el deslizador grande del
## mando elegido y los botones de arrancar y enfriar; la escena encuadra lo suyo a su izquierda (inset_right; unidad 5j).
extends BoxContainer

const State = preload("res://core/lab/claw_forge_state.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Runner = preload("res://app/lab/cetreria/forge_runner.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const Forge3D = preload("res://app/lab/cetreria/forge_3d.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const Ui = preload("res://app/common/ui.gd")
const Card = preload("res://app/common/card.gd")
const Pill = preload("res://app/common/pill.gd")
const PillChoice = preload("res://app/lab/cetreria/pill_choice.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const SfxForge = preload("res://core/lab/sfx_forge.gd")
const GuideOverlay = preload("res://app/common/guide_overlay.gd")

const SCENE := "res://app/lab/cetreria/forge_3d.tscn"
const TITLE := "Laboratorio experimental (reforja)"
const INTRO := "La rama experimental del trabajo veterinario: una funda o una prótesis de otro material para la garra, hecha aparte en el taller, como una corona dental. Pesa los polvos, mete la carga en su máquina, ajusta los mandos del horno a la receta (el tiempo es el de verdad, a la velocidad que elijas), enfría, talla por pasadas, protege la carne viva y pule; la funda terminada y sin pegar pasa a la cetrería, donde se coloca y se acaba a mano."
const BANNER := "El horno que lo junta todo es FICCIÓN: cada modo es una máquina real (horno de mufla o de vacío, inducción, soplete de Verneuil, prensa de alta presión, reactor de plasma), con sus temperaturas y atmósferas de verdad, pero ninguna las reúne. La garra viva no entra en el horno: la queratina se quema a ~230 °C. Recubrir la garra en el animal es ficción y así se dice."
const HELP_MOUSE := "Ratón · izquierdo sobre un tarro: cogerlo; arrastrado sobre el plato de la balanza y mantenido: verter (Mayús: gota a gota) · izquierdo sobre un dial y arrastrar arriba o abajo: girarlo (Mayús: paso fino); rueda sobre él: un paso · clic en un selector: la opción siguiente · clic en la puerta del horno (o arrastrar el crisol hasta ella): meter la carga · clic en el botón rojo: arrancar; en el amarillo: sacar y enfriar · clic en el crisol, la caja de las piedras, la cera, la sierra, la muela, la garra, la pistola o la pulidora: lo que hace cada uno · en la mesa de soldar: clic en el aparato (el láser, el micro-TIG o el soplete) lo elige y coloca las piezas; arrastrar la punta la alinea; apretado sobre la costura y recorriéndola: los puntos · derecho: girar la cámara · central: desplazarla · rueda: acercar."
const HELP_KEYS := "Teclado · A/D: el mando anterior o el siguiente · W/S: girarlo (Mayús: paso fino) · Z: la tara de la balanza (la pantalla a cero) · L: cargar el crisol (o comprar la piedra) · M: meter la carga en su máquina · Intro: arrancar · X: la velocidad (Mayús: la anterior) · Espacio: acabar ya · E: sacar y enfriar · C: la cera perdida (el modelo, revestir, romper el molde) · G: la herramienta de tallar (Mayús: la anterior) · T: una pasada (Mayús: una suave) · B: proteger la carne viva · R: recubrir · O: pulir · U: probar el ajuste · Q: colocar las piezas en la mesa de soldar · F: el método de soldar · I: alinear las piezas · J: un punto en el primer tramo sin soldar (mantenla pulsada: sigue) · Retroceso: vaciar la balanza · P: poner lo recomendado · N: siguiente paso del tutorial · V: vista · H: esta ayuda · Esc: soltar el tarro."
const HELP_TOUCH := "Teléfono · un dedo: tocar un tarro para cogerlo y mantenerlo sobre el plato para verter (o los botones de dosis de cada polvo en la balanza); tocar un mando para elegirlo y moverlo con el deslizador grande de la vista; los botones «Meter», «Arrancar» y «Enfriar», sobre la vista · dos dedos: girar la cámara y, al separarlos o juntarlos, acercar. Los botones de las tarjetas hacen lo mismo que las teclas."
const INTRO_TEXT := "El tutorial del horno explica cada mando (qué hace y por qué importa), cómo se mete cada carga en su máquina y el reloj del tiempo de verdad; después, el de cada material te lleva paso a paso: qué polvos y en qué proporción, los parámetros con su margen bueno, la cera perdida de los metales y del vidrio, cómo enfriar, el tallado por pasadas y qué sale si te equivocas. El mando que toca se ilumina en la vista."
const WIDE := 1000.0
const SIDE_W := 440.0
const VIEW_H := 560.0
const VIEW_H_PHONE := 0.52
const TOUCH := 44.0
## El aire entre el deslizador grande y lo que encuadra la vista (px).
const TOUCH_GAP := 8.0
const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "text" }
const QUALITY_COLOR := { "primary": "mint", "secondary": "text", "estimate": "gold", "ficcion": "rose", "dibujo": "dim" }
## Nombres cortos de los tutoriales para el selector.
const TUT_SHORT := {
	"soldadura": "Soldar",
	"horno": "El horno", "zafiro": "Zafiro", "rubi": "Rubí", "metal_duro": "Metal duro", "alumina": "Alúmina", "acero": "Acero",
	"oro": "Oro", "titanio": "Titanio", "vidrio": "Vidrio", "diamante_hpht": "Diamante HPHT", "diamante_cvd": "Diamante CVD",
	"piedra": "Piedra comprada", "garra_viva": "Garra viva (ficción)", "acrilico": "Acrílico (de verdad)",
}

## Efecto de sonido: Callable(id: String, volume: float) (lo pone la cetrería: el de la sección).
var play_sfx: Callable = Callable()
var runner: Runner
var view3d: View3D
var scene: Node3D = null
var active := false
var compact := false
var quality := ""
## El estado corre en su hilo (false: en el de la interfaz; la demo y los tests).
var threaded := true
var view := "general"
var fit_height := 0.0
var paints := 0
var last_paint_us := 0

var left: VBoxContainer
var right: VBoxContainer
var right_scroll: ScrollContainer
var mode_seg: PillChoice
## La fila del interruptor: la cetrería pone aquí su «Tienda de lentes» mientras se ve la reforja (5tc).
var mode_row: HFlowContainer
var view_box: Control
var view_seg: PillChoice
var hud_title: Label
var hud_state: Label
var hud_notice: Label
## 5w · junto a la balanza, sobre la vista: lo que lleva y lo que falta de cada polvo, y el aviso («Listo: carga el crisol (L)»).
var hud_scale: Label
var hud_box: MarginContainer
var help_panel: PanelContainer
var help_pill: Pill
var status_label: Label
var touch_box: VBoxContainer
var touch_name: Label
var touch_slider: VSlider
var touch_start: Button
var touch_cool: Button
var touch_insert: Button
var head_card: Card
var intro_box: PanelContainer
var intro_seen := false
var tut_card: Card
var tut_choice: PillChoice
var tut_toggle: Pill
var tut_title: Label
var tut_text: Label
var tut_source: Label
var tut_control: Label
var tut_status: Label
var tut_mistake: Label
## 5w · la receta no sale con esta garra y esta forma (State.feasibility): por qué y qué probar.
var tut_warn: Label
var tut_prev: Button
var tut_next: Button
var tut_do: Button
## 5x · el interruptor «Guiado» (dentro del tutorial): con él apagado, solo el texto del paso.
var guide_toggle: Pill
## 5x · el guiado botón a botón: el aviso sobre la vista, el control del panel que late, el desplazamiento y el velo.
var guide: GuideOverlay
## Los botones que el guiado señala por su id (los que no se guardan en otra parte).
var guide_nodes := {}
var _guide_key := ""
var mistake_box: PanelContainer
var mistake_what: Label
var mistake_fix: Label
var mistake_how: Label
var mistake_src: Label
var make_card: Card
var recipe_grid: TileGrid
var recipe_tiles := {}
var recipe_detail: VBoxContainer
var shape_choice: PillChoice
var wall_choice: PillChoice
var stone_choice: PillChoice
var stone_box: VBoxContainer
var sheath_note: Label
var bench_card: Card
var jar_rows := {}
var other_box: VBoxContainer
var others_toggle: Pill
var bench_total: Label
var bench_mix: Label
var bench_plan: Label
var load_button: Button
var furnace_card: Card
var control_rows := {}
var start_button: Button
var skip_button: Button
var cool_button: Button
var furnace_note: Label
## 5m · meter la carga, lo que hay dentro, la velocidad y el reloj.
var insert_button: Button
var inside_label: Label
var speed_choice: PillChoice
var clock_label: Label
var clock_life: Label
## 5m · la cera perdida: su tarjeta, los pasos, los botones y la cera a la medida.
var wax_card: Card
var wax_steps: Label
var wax_note: Label
var wax_compensate: Pill
var wax_buttons := {}
## 5m · el tallado por pasadas: la herramienta, el indicador de la forma (la silueta de la pieza contra la de la funda) y la
## última pasada; la prueba del ajuste.
var carve_tools: PillChoice
var carve_verdict: Label
var carve_last: Label
var gauge: Control
var fit_label: Label
## 5r · la mesa de soldar
var weld_card: Card
var weld_method: PillChoice
var weld_part: PillChoice
var weld_mat: PillChoice
var weld_gas: PillChoice
var weld_overlap: PillChoice
var weld_sliders := {}
var weld_what: Label
var weld_bar: ProgressBar
var weld_bar_text: Label
var weld_verdict: Label
var weld_align_label: Label
var weld_safety: Label
var weld_buttons := {}
var weld_gas_row: Control
var _gauge_key := ""
var _gauge_target := PackedVector2Array()
var _gauge_now := PackedVector2Array()
var _gauge_box := Rect2()
var _gauge_col := Color(0.8, 0.8, 0.85)
var _clock_text := ""
var shop_card: Card
var shop := {}
var readings_card: Card
var readings: TileGrid
var reading_tiles := {}
var sheet_card: Card
var sheet_verdict: Label
var sheet_grid: GridContainer
var sheet_fiction: Label
var sheet_advice: VBoxContainer
var care_button: Button
var bench_button: Button
var care_note: Label
var values_card: Card
var values_toggle: Pill
var values_list: VBoxContainer
var values_rows: Array = []
var events_box: VBoxContainer

var _built := false
var _v: Dictionary = {}
var _seen_serial := -1
var _fx_seen := 0
var _keys := {}
var _loop: AudioStreamPlayer
var _loop_id := ""
## Las tarjetas de las recetas (no cambian: se leen una vez, al construir, antes de que arranque el hilo).
var _cards: Array = []

## «Trabajo veterinario»: vuelve a la cetrería.
signal back_requested
## «Pasar a la cetrería»: la garra reforjada (ClawForge.care_setup, con la pata y la garra de las que vino).
signal to_care(setup: Dictionary)
## «Probar en el banco»: { claw, inlay, sharpness }.
signal to_bench(setup: Dictionary)
## La persona ha visto (o ha empezado) el tutorial de la primera vez.
signal intro_done


func _init() -> void:
	name = "Reforja"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)


func setup(p_play: Callable = Callable()) -> void:
	if _built:
		return
	_built = true
	play_sfx = p_play
	runner = Runner.new()
	_build()
	_apply_view(runner.latest(), true)


## Abre el laboratorio con una garra de la cetrería: { animal, claw, paw, digit, broken, humidity, profile }.
func open_with(p: Dictionary) -> void:
	if runner == null:
		return
	runner.post("open", [p])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and runner != null:
		runner.stop_thread()


func _exit_tree() -> void:
	_stop_loop()
	if runner != null:
		runner.stop_thread()


func dispose() -> void:
	_stop_loop()
	if runner != null:
		runner.stop_thread()


# ─────────────────────────────── Construcción ───────────────────────────────

func _build() -> void:
	left = Ui.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right = Ui.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll = ScrollContainer.new()
	right_scroll.name = "Tarjetas"
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.follow_focus = true
	add_child(left)
	add_child(right_scroll)
	right_scroll.add_child(right)
	_build_switch()
	_build_view()
	_build_head()
	_build_intro()
	_build_tutorial()
	_build_make()
	_build_lost_wax()
	_build_bench()
	_build_furnace()
	_build_shop()
	_build_weld()
	_build_readings()
	_build_sheet()
	_build_values()
	_build_events()
	guide = GuideOverlay.new()
	guide.reduce_motion = Ui.reduce_motion()
	add_child(guide)
	guide.setup(right_scroll, view_box)
	_loop = AudioStreamPlayer.new()
	_loop.name = "MaquinaDeLaReforja"
	_loop.bus = &"Lab"
	add_child(_loop)
	resized.connect(_layout)
	_layout()


func _a11y(c: Control, a_name: String, description := "") -> void:
	c.accessibility_name = a_name
	if description != "":
		c.accessibility_description = description
		if c is BaseButton or c is Range:
			c.tooltip_text = description


func _button(text: String, variation := "Pill", description := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = StringName(variation)
	b.custom_minimum_size.y = TOUCH if compact else 32.0
	_a11y(b, text, description)
	return b


## «Trabajo veterinario | Laboratorio experimental (reforja)»: arriba de la vista, para volver a la cetrería.
func _build_switch() -> void:
	mode_seg = PillChoice.new([
		{ "id": "cetreria", "label": "Trabajo veterinario", "title": "La cetrería: limar, cortar y curar las garras del animal" },
		{ "id": "reforja", "label": "Laboratorio experimental (reforja)", "title": "La rama experimental: una funda o una prótesis de otro material" },
	], "reforja", "Cetrería")
	mode_seg.selected.connect(func(id: String) -> void:
		if id == "cetreria":
			mode_seg.set_value("reforja")
			back_requested.emit())
	mode_row = Ui.flow(8, 6)
	mode_row.name = "Modos"
	# que se estire en la fila: con el mínimo de su píldora más ancha, las dos opciones salían una debajo de otra aunque
	# cupieran en una línea (y la «Tienda de lentes» flotaba entre ellas)
	mode_seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_seg)
	left.add_child(mode_row)


func _build_view() -> void:
	view_box = Control.new()
	view_box.name = "Vista"
	view_box.custom_minimum_size = Vector2(300.0, VIEW_H)
	view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_box.clip_contents = true
	view_box.resized.connect(_update_inset)
	left.add_child(view_box)
	view3d = View3D.new(SCENE)
	view3d.name = "Reforja3D"
	view3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view3d.focus_mode = Control.FOCUS_ALL
	view3d.configure = _configure_scene
	view3d.scene_ready.connect(_on_scene_ready)
	view3d.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			view3d.grab_focus())
	_a11y(view3d, "Vista 3D del taller de la reforja: la balanza, el horno y el taller", HELP_MOUSE + " " + HELP_TOUCH)
	view_box.add_child(view3d)
	var hud := Ui.margin(12, 10, 12, 10)
	hud_box = hud
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Ui.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)
	hud_title = Ui.para("", "Small", "gold")
	hud_state = Ui.para("", "Small", "text")
	hud_notice = Ui.para("", "Small", "rose")
	hud_scale = Ui.para("", "Small", "text")
	for l: Label in [hud_title, hud_state, hud_notice, hud_scale]:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	view_box.add_child(hud)
	_build_touch()
	help_panel = PanelContainer.new()
	help_panel.theme_type_variation = &"Sheet"
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	help_panel.custom_minimum_size = Vector2(280.0, 0.0)
	var hv := Ui.vbox(8)
	for t: String in [HELP_MOUSE, HELP_KEYS, HELP_TOUCH]:
		var l := Ui.para(t, "Body")
		l.custom_minimum_size.x = 260.0
		hv.add_child(l)
	help_panel.add_child(hv)
	help_panel.visible = false
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_box.add_child(help_panel)
	view_seg = PillChoice.new(Array(Forge3D.VIEWS).map(func(v: String) -> Dictionary:
		return { "id": v, "label": String(Forge3D.VIEW_NAMES[v]), "title": "Vista: " + String(Forge3D.VIEW_NAMES[v]) }), "general", "Vista de la cámara")
	view_seg.selected.connect(set_view)
	left.add_child(view_seg)
	# «Ayuda (H)» dentro de la misma fila que fluye, justo detrás de las vistas (antes se iba al otro extremo y parecía suelta;
	# en el teléfono baja de línea con ellas)
	help_pill = Pill.new("Ayuda (H)")
	help_pill.pressed.connect(toggle_help)
	_a11y(help_pill, "Ayuda de los mandos", HELP_KEYS)
	view_seg.add_child(help_pill)
	status_label = Ui.para("", "Note", "dim")
	left.add_child(status_label)


## Sobre la vista, abajo a la derecha: el deslizador grande del mando elegido y los botones de arrancar y enfriar (en el
## teléfono siempre; en escritorio también están el ratón y las teclas).
func _build_touch() -> void:
	touch_box = Ui.vbox(6)
	touch_box.name = "MandosSobreLaVista"
	touch_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_box.offset_left = -112.0
	touch_box.offset_right = -10.0
	touch_box.offset_top = -382.0
	touch_box.offset_bottom = -10.0
	touch_box.alignment = BoxContainer.ALIGNMENT_END
	# el nombre del mando y su valor, una línea cada uno (lo que no cabe, con puntos suspensivos: el valor entero está en
	# el dial y en la tarjeta del horno)
	touch_name = Ui.label("", "Small", "text")
	touch_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	touch_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	touch_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	touch_name.clip_text = true
	touch_name.max_lines_visible = 2
	touch_name.custom_minimum_size.x = 102.0
	touch_name.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
	touch_name.add_theme_constant_override("outline_size", 6)
	touch_box.add_child(touch_name)
	touch_slider = VSlider.new()
	touch_slider.min_value = 0.0
	touch_slider.max_value = 1.0
	touch_slider.step = 0.001
	touch_slider.custom_minimum_size = Vector2(48.0, 150.0)
	touch_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	touch_slider.value_changed.connect(func(t: float) -> void:
		var id := String(_v.get("selected_control", "temp_c"))
		_post("set_control", [id, State.control_value_at(id, t)]))
	_a11y(touch_slider, "El mando elegido", "Arriba, más; abajo, menos. Toca un mando en la vista para elegirlo.")
	touch_box.add_child(touch_slider)
	touch_insert = Button.new()
	touch_insert.text = "Meter"
	touch_insert.theme_type_variation = &"Pill"
	touch_insert.custom_minimum_size = Vector2(86.0, TOUCH)
	touch_insert.pressed.connect(func() -> void: _post("insert_charge"))
	_a11y(touch_insert, "Meter la carga en su máquina", "Tecla M.")
	touch_box.add_child(touch_insert)
	touch_start = Button.new()
	touch_start.text = "Arrancar"
	touch_start.theme_type_variation = &"PillGold"
	touch_start.custom_minimum_size = Vector2(86.0, TOUCH)
	touch_start.pressed.connect(func() -> void: _post("start"))
	_a11y(touch_start, "Arrancar el horno", "Tecla Intro.")
	touch_box.add_child(touch_start)
	touch_cool = Button.new()
	touch_cool.text = "Enfriar"
	touch_cool.theme_type_variation = &"Pill"
	touch_cool.custom_minimum_size = Vector2(86.0, TOUCH)
	touch_cool.pressed.connect(func() -> void: _post("cool_piece"))
	_a11y(touch_cool, "Sacar y enfriar", "Tecla E.")
	touch_box.add_child(touch_cool)
	touch_box.visible = false
	view_box.add_child(touch_box)


func _build_head() -> void:
	head_card = Card.new(TITLE)
	head_card.body.add_child(Ui.para(INTRO, "Body"))
	var band := PanelContainer.new()
	band.theme_type_variation = &"VerdictBox"
	band.add_child(Ui.para(BANNER, "Note", "rose"))
	head_card.body.add_child(band)
	right.add_child(head_card)


func _build_intro() -> void:
	intro_box = PanelContainer.new()
	intro_box.theme_type_variation = &"VerdictBox"
	var col := Ui.vbox(8)
	col.add_child(Ui.label("¿Primera vez? Empieza por el horno", "CardTitle"))
	col.add_child(Ui.para(INTRO_TEXT, "Body"))
	var row := Ui.flow()
	var go := _button("Empezar el tutorial del horno", "PillGold", "El tutorial explica cada mando del horno y, después, cada receta.")
	go.pressed.connect(func() -> void:
		_post("set_tutorial", [true])
		_post("tutorial_goto", [State.GENERAL])
		_dismiss_intro())
	row.add_child(go)
	var later := _button("Ya sé usarlo", "Pill", "El tutorial sigue en su tarjeta, con su interruptor.")
	later.pressed.connect(_dismiss_intro)
	row.add_child(later)
	col.add_child(row)
	intro_box.add_child(col)
	intro_box.visible = not intro_seen
	right.add_child(intro_box)


func _dismiss_intro() -> void:
	if not intro_seen:
		intro_seen = true
		intro_done.emit()
	intro_box.visible = false


func set_intro_seen(seen: bool) -> void:
	intro_seen = seen
	if intro_box != null:
		intro_box.visible = not seen


func _build_tutorial() -> void:
	tut_card = Card.new("Tutorial", "")
	tut_toggle = Pill.new("Tutorial activado")
	tut_toggle.pressed.connect(func() -> void: _post("set_tutorial", [not bool(_v.get("tutorial", {}).get("on", true))]))
	_a11y(tut_toggle, "Activar o desactivar el tutorial")
	tut_card.right.add_child(tut_toggle)
	guide_toggle = Pill.new("Guiado")
	guide_toggle.pressed.connect(func() -> void: _post("set_guide", [not bool(_v.get("guide_on", true))]))
	_a11y(guide_toggle, "Guiado botón a botón", "La cámara se acerca a lo que hay que usar, el panel baja hasta el control que hay que pulsar y un aviso sobre la vista dice la acción con su valor. Apagado, solo el texto del paso.")
	tut_card.right.add_child(guide_toggle)
	tut_choice = PillChoice.new(State.TUTORIALS.map(func(id: String) -> Dictionary: return { "id": id, "label": String(TUT_SHORT.get(id, id)), "title": "Tutorial: " + String(TUT_SHORT.get(id, id)) }), State.GENERAL, "Tutorial")
	tut_choice.selected.connect(func(id: String) -> void: _post("tutorial_goto", [id]))
	tut_card.body.add_child(tut_choice)
	tut_title = Ui.para("", "CardTitle")
	tut_card.body.add_child(tut_title)
	tut_warn = Ui.para("", "Body", "coral")
	tut_card.body.add_child(tut_warn)
	tut_text = Ui.para("", "Body")
	tut_card.body.add_child(tut_text)
	tut_source = Ui.para("", "Note", "dim")
	tut_source.mouse_filter = Control.MOUSE_FILTER_STOP
	tut_card.body.add_child(tut_source)
	tut_control = Ui.para("", "Body", "mint")
	tut_card.body.add_child(tut_control)
	tut_status = Ui.para("", "Small", "gold")
	tut_card.body.add_child(tut_status)
	tut_mistake = Ui.para("", "Small", "coral")
	tut_card.body.add_child(tut_mistake)
	var row := Ui.flow()
	tut_prev = _button("Anterior", "Pill", "El paso anterior del tutorial.")
	tut_prev.pressed.connect(func() -> void: _post("tutorial_prev"))
	tut_next = _button("Siguiente (N)", "PillGold", "El paso siguiente del tutorial.")
	tut_next.pressed.connect(func() -> void: _post("tutorial_next"))
	tut_do = _button("Hazlo como dice el paso", "Pill", "Pone los mandos como recomienda la receta y hace la acción del paso.")
	tut_do.pressed.connect(func() -> void: _post("do_step"))
	for b: Button in [tut_prev, tut_next, tut_do]:
		row.add_child(b)
	tut_card.body.add_child(row)
	mistake_box = PanelContainer.new()
	mistake_box.theme_type_variation = &"VerdictBox"
	var mcol := Ui.vbox(6)
	mistake_what = Ui.para("", "Body", "coral")
	mistake_fix = Ui.para("", "Body")
	mistake_how = Ui.para("", "Body", "mint")
	mistake_src = Ui.para("", "Small", "dimmer")
	for l: Label in [mistake_what, mistake_fix, mistake_how, mistake_src]:
		mcol.add_child(l)
	var ok := _button("Entendido", "Pill", "Deja de enseñar la explicación del error.")
	ok.pressed.connect(func() -> void: _post("dismiss_mistake"))
	mcol.add_child(ok)
	mistake_box.add_child(mcol)
	mistake_box.visible = false
	tut_card.body.add_child(mistake_box)
	right.add_child(tut_card)


## «Qué quieres hacer»: las recetas en tarjetas (los polvos, los márgenes, el gemelo del banco y si el banco ya lo tiene),
## la forma de la funda y su pared, y la piedra que se compra.
func _build_make() -> void:
	make_card = Card.new("Qué quieres hacer")
	recipe_grid = TileGrid.new(132.0)
	_cards = runner.state.recipe_cards()
	for c: Dictionary in _cards:
		var id := String(c.id)
		var tile := Button.new()
		tile.theme_type_variation = &"Pill"
		tile.toggle_mode = true
		tile.custom_minimum_size = Vector2(0.0, 58.0)
		var tag := String(c.get("tag", ""))
		tile.text = "%s\n%s" % [String(c.name), tag if tag != "" else ("FICCIÓN" if bool(c.fiction) else ("en el banco" if bool(c.bench_ok) else "aún no en el banco"))]
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# con una pieza empezada, el primer clic solo avisa (State.choose_process): la tarjeta sigue sin marcar hasta que cambia
		tile.pressed.connect(func() -> void:
			tile.set_pressed_no_signal(String(_v.get("process", "")) == id)
			_post("choose_process", [id]))
		_a11y(tile, "Fabricar: %s" % String(c.name), "%s. %s" % [String(c.product), String(c.bench)])
		var sw := ColorRect.new()
		sw.color = Color(String(c.color))
		sw.custom_minimum_size = Vector2(10.0, 10.0)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		sw.offset_left = -16.0
		sw.offset_top = 6.0
		sw.offset_right = -6.0
		sw.offset_bottom = 16.0
		tile.add_child(sw)
		recipe_grid.add_child(tile)
		recipe_tiles[id] = tile
	make_card.body.add_child(recipe_grid)
	recipe_detail = Ui.vbox(4)
	make_card.body.add_child(recipe_detail)
	make_card.body.add_child(Ui.sub_label("La forma de la funda (petición de garras y formas nuevas)"))
	var v0 := runner.latest()
	var sv: Dictionary = v0.sheath
	shape_choice = PillChoice.new(sv.shapes, String(sv.shape), "Forma de la funda")
	shape_choice.selected.connect(func(id: String) -> void: _post("set_shape", [id]))
	make_card.body.add_child(shape_choice)
	wall_choice = PillChoice.new(sv.walls, String(sv.wall), "Pared de la funda")
	wall_choice.selected.connect(func(id: String) -> void: _post("set_wall", [id]))
	make_card.body.add_child(wall_choice)
	sheath_note = Ui.para("", "Note", "dim")
	make_card.body.add_child(sheath_note)
	stone_box = Ui.vbox(4)
	stone_box.add_child(Ui.sub_label("La piedra"))
	stone_choice = PillChoice.new(v0.stones, String(v0.stone), "Piedra")
	stone_choice.selected.connect(func(id: String) -> void: _post("set_stone", [id]))
	stone_box.add_child(stone_choice)
	make_card.body.add_child(stone_box)
	right.add_child(make_card)


## La cera perdida (5m): el modelo de cera de la funda con la forma de la garra, el revestimiento con el molde del selector
## «Molde» del horno y romper el molde; quemar la cera y colar se hacen en el horno. Con un mineral duro, por qué no se cuela.
func _build_lost_wax() -> void:
	wax_card = Card.new("La cera perdida")
	wax_card.body.add_child(Ui.para("Los metales y el vidrio se cuelan en un molde con la forma de la garra: el modelo de cera de la funda, revestido, se quema en el horno y deja el hueco que llena el metal. Lo que encoge el material al enfriarse se compensa haciendo la cera más grande.", "Note", "dim"))
	wax_steps = Ui.para("", "Body")
	wax_card.body.add_child(wax_steps)
	var row := Ui.flow()
	for e: Array in [["cera", "Modelo de cera (C)", "Hace el modelo de cera de la funda de la garra con su bebedero.", "make_wax"],
			["revestir", "Revestir", "Reviste la cera con el molde del selector «Molde» del horno: fragua lo que tarde de verdad.", "invest"],
			["romper", "Romper el molde", "Con la colada fría, rompe el molde y saca la funda con su bebedero.", "divest"]]:
		var b := _button(String(e[1]), "Pill", String(e[2]))
		var op := String(e[3])
		b.pressed.connect(func() -> void: _post(op))
		row.add_child(b)
		wax_buttons[String(e[0])] = b
	wax_compensate = Pill.new("Cera a la medida")
	wax_compensate.pressed.connect(func() -> void: _post("set_compensate", [not bool(_v.get("compensate", true))]))
	_a11y(wax_compensate, "Hacer la cera a la medida de la contracción", "La cera se hace más grande lo que encoge el material al colarse y no compensa el revestimiento: la funda sale a su medida.")
	row.add_child(wax_compensate)
	wax_card.body.add_child(row)
	wax_note = Ui.para("", "Small", "dim")
	wax_card.body.add_child(wax_note)
	right.add_child(wax_card)


## La balanza: un renglón por polvo de la receta (los demás, plegados), con sus gramos, su proporción frente a la de la
## receta y los botones de dosis; el total, vaciar, lo de la receta y cargar el crisol.
func _build_bench() -> void:
	bench_card = Card.new("La balanza y el crisol")
	var sv: Dictionary = runner.latest().bench
	# 5w · lo que pide la pieza de esta garra (de dónde sale el total y lo que vale)
	bench_plan = Ui.para("", "Note", "dim")
	bench_card.body.add_child(bench_plan)
	other_box = Ui.vbox(6)
	for j: Dictionary in sv.jars:
		var row := _jar_row(j)
		jar_rows[String(j.id)] = row
		bench_card.body.add_child(row.box)
	others_toggle = Pill.new("Otros polvos")
	others_toggle.pressed.connect(func() -> void:
		other_box.visible = not other_box.visible
		others_toggle.set_on(other_box.visible))
	_a11y(others_toggle, "Ver los polvos que no van en esta receta", "Se pueden echar, pero contaminan la mezcla.")
	bench_card.body.add_child(others_toggle)
	other_box.visible = false
	bench_card.body.add_child(other_box)
	bench_total = Ui.para("", "Body")
	bench_card.body.add_child(bench_total)
	bench_mix = Ui.para("", "Body", "dim")
	bench_card.body.add_child(bench_mix)
	var row2 := Ui.flow()
	var clear := _button("Vaciar (Retroceso)", "Pill", "Vacía el plato de la balanza.")
	clear.pressed.connect(func() -> void: _post("clear_pan"))
	var tare := _button("Tara (Z)", "Pill", "Pone la pantalla de la balanza a cero con lo que hay en el plato, para pesar el polvo siguiente desde cero.")
	tare.pressed.connect(func() -> void: _post("tare"))
	guide_nodes["tara"] = tare
	guide_nodes["vaciar"] = clear
	row2.add_child(tare)
	var rec := _button("Poner lo recomendado (P)", "Pill", "Pone en la balanza y en los mandos lo que recomienda la receta, sin arrancar nada.")
	rec.pressed.connect(func() -> void: _post("apply_recommended"))
	load_button = _button("Cargar el crisol (L)", "PillGold", "Carga lo pesado en el crisol o en el alimentador del soplete.")
	load_button.pressed.connect(func() -> void: _post("load_crucible"))
	guide_nodes["recomendado"] = rec
	for b: Button in [clear, rec, load_button]:
		row2.add_child(b)
	bench_card.body.add_child(row2)
	right.add_child(bench_card)


func _jar_row(j: Dictionary) -> Dictionary:
	var id := String(j.id)
	var box := Ui.vbox(2)
	var head := Ui.para("%s (%s)" % [String(j.name), String(j.formula)], "Body")
	head.tooltip_text = "%s Fuente: %s." % [String(j.what), String(j.source_short)]
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(head)
	var line := Ui.para("", "Small", "dim")
	box.add_child(line)
	var row := Ui.flow(5, 5)
	# 5w · las dosis van con el objetivo de cada polvo (State.doses_for): las tres de añadir y la de quitar
	var dose_g: Array = []
	var dose_b: Array = []
	var ds: Array = (j.doses as Array) + [j.minus]
	for i in ds.size():
		var d: Dictionary = ds[i]
		dose_g.append(float(d.g))
		var b := _button(String(d.label), "Pill", "")
		row.add_child(b)
		dose_b.append(b)
	var entry := { "box": box, "line": line, "head": head, "dose_g": dose_g, "dose_b": dose_b }
	for i in dose_b.size():
		var k := i
		(dose_b[i] as Button).pressed.connect(func() -> void: _post("add_powder", [id, float((entry.dose_g as Array)[k])]))
	_dose_tips(entry, String(j.name))
	var pick := Pill.new("Coger el tarro")
	pick.pressed.connect(func() -> void: _post("pick_jar", [id]))
	_a11y(pick, "Coger el tarro: %s" % String(j.name), "Con el tarro en la mano, mantenlo sobre el plato para verter.")
	row.add_child(pick)
	box.add_child(row)
	entry["pick"] = pick
	return entry


## El texto y la ayuda de los botones de dosis de un polvo (5w: cambian con su objetivo).
func _dose_tips(entry: Dictionary, nm: String) -> void:
	for i in (entry.dose_b as Array).size():
		var g := float((entry.dose_g as Array)[i])
		var b: Button = entry.dose_b[i]
		var amount := State._dose_label(absf(g))
		b.text = ("+" if g > 0.0 else "−") + amount
		_a11y(b, "%s %s de %s" % ["Añade" if g > 0.0 else "Quita", amount, nm.to_lower()], "Quitar solo se puede con ese polvo solo en el plato: mezclado con otros ya no se separa." if g < 0.0 else "Echa esa dosis en el plato de la balanza.")


## El horno: un renglón por mando (deslizador o selector), con su margen bueno, y los botones.
func _build_furnace() -> void:
	furnace_card = Card.new("El horno")
	for c: Dictionary in runner.latest().controls:
		var id := String(c.id)
		var box := Ui.vbox(3)
		var widget: Control
		if String(c.kind) == "dial":
			var s := ValueSlider.new(String(c.name), "", 0.0, 1.0, 0.001)
			s.slider.custom_minimum_size.y = TOUCH if compact else 24.0
			s.value_changed.connect(func(t: float) -> void: _post("set_control", [id, State.control_value_at(id, t)]))
			_a11y(s.slider, String(c.name), "%s %s" % [String(c.what), String(c.why)])
			widget = s
		else:
			box.add_child(Ui.sub_label(String(c.name)))
			var pc := PillChoice.new((c.options as Array).map(func(o: Dictionary) -> Dictionary: return { "id": o.id, "label": o.label, "title": String(c.why) }), String(c.value), String(c.name))
			pc.selected.connect(func(o: String) -> void: _post("set_control", [id, o]))
			widget = pc
		box.add_child(widget)
		var note := Ui.para("", "Small", "dim")
		note.tooltip_text = "%s %s Fuente: %s." % [String(c.what), String(c.why), String(c.source_short)]
		note.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(note)
		furnace_card.body.add_child(box)
		control_rows[id] = { "box": box, "widget": widget, "note": note }
	# 5m · la carga dentro de su máquina, la velocidad y el reloj
	var irow := Ui.flow()
	insert_button = _button("Meter la carga (M)", "PillGold", "Mete en la máquina del modo lo que le toca (el crisol, la tolva, la cápsula, el sustrato, la pastilla, la pieza o el molde) y la cierra.")
	insert_button.pressed.connect(func() -> void: _post("insert_charge"))
	irow.add_child(insert_button)
	furnace_card.body.add_child(irow)
	inside_label = Ui.para("", "Small", "dim")
	furnace_card.body.add_child(inside_label)
	furnace_card.body.add_child(Ui.sub_label("La velocidad (X) y el reloj del tiempo de verdad"))
	var names: Array = []
	for i in State.SPEED_NAMES.size():
		names.append({ "id": str(i), "label": String(State.SPEED_NAMES[i]), "title": "La marcha a %s: lo que tarda de verdad entre %s (con topes de unos segundos y unos minutos)" % [String(State.SPEED_NAMES[i]), String(State.SPEED_NAMES[i])] if float(State.SPEEDS[i]) > 0.0 else "Lo más rápido: unos segundos, tarde lo que tarde de verdad" })
	speed_choice = PillChoice.new(names, str(State.DEFAULT_SPEED), "Velocidad")
	speed_choice.selected.connect(func(id: String) -> void: _post("set_speed", [int(id)]))
	furnace_card.body.add_child(speed_choice)
	clock_label = Ui.para("", "Body", "gold")
	furnace_card.body.add_child(clock_label)
	clock_life = Ui.para("", "Small", "dim")
	furnace_card.body.add_child(clock_life)
	var row := Ui.flow()
	start_button = _button("Arrancar (Intro)", "RunButton", "Arranca el horno con los mandos de ahora, si la carga está dentro de su máquina (o calienta la pieza, o quema la cera del molde, en el modo «Calentar»).")
	start_button.pressed.connect(func() -> void: _post("start"))
	skip_button = _button("Acabar ya (Espacio)", "Pill", "Pasa al final de la marcha o de lo que corre en el taller.")
	skip_button.pressed.connect(func() -> void: _post("skip"))
	cool_button = _button("Sacar y enfriar (E)", "PillGold", "Saca la pieza y la enfría como dice el selector «Enfriar».")
	cool_button.pressed.connect(func() -> void: _post("cool_piece"))
	for b: Button in [start_button, skip_button, cool_button]:
		row.add_child(b)
	furnace_card.body.add_child(row)
	furnace_note = Ui.para("", "Note", "dim")
	furnace_card.body.add_child(furnace_note)
	right.add_child(furnace_card)


## El taller: tallar por pasadas, proteger la carne viva, recubrir, probar el ajuste y pulir, cada uno con sus ajustes (desde la
## 5m el laboratorio no pega la funda ni la prueba con la carga: eso es de la cetrería, petición 43).
func _build_shop() -> void:
	shop_card = Card.new("El taller")
	var abr: Array = []
	for id: String in ForgeData.ABRASIVES:
		var a: Dictionary = ForgeData.ABRASIVES[id]
		abr.append({ "id": id, "label": String(a.name).replace("Muela o pasta de ", "").replace("Muela de ", "").replace("carburo de silicio verde", "carburo de silicio"), "title": "%s, %s HV" % [String(a.name), Js.to_fixed(float(a.hv), 0)] })
	# tallar por pasadas (5m): la herramienta, su material, la fuerza y el agua; el indicador de la forma
	shop_card.body.add_child(Ui.sub_label("Tallar por pasadas (la pieza pegada en su palo, con agua)"))
	var v0 := runner.latest()
	var tools: Array = (v0.carving.tools as Array).map(func(t: Dictionary) -> Dictionary: return { "id": t.id, "label": t.label, "title": t.title })
	carve_tools = PillChoice.new(tools, String(v0.tool), "Herramienta")
	carve_tools.selected.connect(func(id: String) -> void: _post("set_carve_tool", [id]))
	shop_card.body.add_child(carve_tools)
	shop_card.body.add_child(Ui.para("El material de la herramienta: tiene que ser más duro que la pieza.", "Small", "dim"))
	shop["carve_abr"] = PillChoice.new(abr, "diamante", "Material de la herramienta")
	(shop.carve_abr as PillChoice).selected.connect(func(id: String) -> void: _post("set_carve", ["abrasive", id]))
	shop_card.body.add_child(shop.carve_abr)
	shop["carve_force"] = _slider("Fuerza", 1.0, 1000.0, true, func(v: float) -> void: _post("set_carve", ["force_n", v]), "La fuerza con la que se aprieta la pieza contra la herramienta (N). Un borde fino de una pieza frágil se desconcha si se aprieta de más.")
	shop["carve_wet"] = Pill.new("Con agua")
	(shop.carve_wet as Pill).pressed.connect(func() -> void: _post("set_carve", ["coolant", not bool(_v.get("workshop", {}).get("carve", {}).get("coolant", true))]))
	_a11y(shop.carve_wet, "Tallar con agua", "En seco, una pieza frágil que conduce mal el calor se agrieta y la herramienta de diamante se quema.")
	var b_pass := _button("Una pasada (T)", "PillGold", "Una pasada con la herramienta elegida: quita lo suyo en lo que tarda de verdad, a la velocidad elegida.")
	b_pass.pressed.connect(func() -> void: _post("carve_pass", [false]))
	var b_light := _button("Pasada suave (Mayús + T)", "Pill", "Una pasada suave, la cuarta parte de una normal, para acercarse a la silueta sin pasarse.")
	b_light.pressed.connect(func() -> void: _post("carve_pass", [true]))
	shop_card.body.add_child(_row([shop.carve_wet, b_pass, b_light]))
	guide_nodes["pasada"] = b_pass
	gauge = Control.new()
	gauge.name = "IndicadorDeLaForma"
	gauge.custom_minimum_size = Vector2(0.0, 104.0)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.draw.connect(_draw_gauge)
	gauge.accessibility_name = "Indicador de la forma: la silueta de la pieza (rellena) contra la de la funda de la garra (a trazos)"
	shop_card.body.add_child(gauge)
	carve_verdict = Ui.para("", "Body")
	shop_card.body.add_child(carve_verdict)
	carve_last = Ui.para("", "Small", "dim")
	shop_card.body.add_child(carve_last)
	# proteger
	shop_card.body.add_child(Ui.sub_label("Proteger la carne viva"))
	shop["barrier"] = PillChoice.new(ForgeData.BARRIER_IDS.map(func(id: String) -> Dictionary: return { "id": id, "label": String(ForgeData.BARRIERS[id].name), "title": String(ForgeData.BARRIERS[id].name) }), "aerogel", "Barrera")
	(shop.barrier as PillChoice).selected.connect(func(id: String) -> void: _post("set_barrier", ["barrier", id]))
	shop_card.body.add_child(shop.barrier)
	shop["barrier_th"] = _slider("Espesor de la barrera", 0.5, 10.0, false, func(v: float) -> void: _post("set_barrier", ["thickness_mm", v]), "El espesor de la barrera sobre la parte con carne viva (mm).")
	var b_prot := _button("Proteger (B)", "PillGold", "Pone la barrera sobre la mitad de la garra con carne viva.")
	b_prot.pressed.connect(func() -> void: _post("protect"))
	shop_card.body.add_child(_row([b_prot]))
	guide_nodes["proteger"] = b_prot
	# recubrir
	shop_card.body.add_child(Ui.sub_label("Recubrir (opcional)"))
	shop["coat"] = PillChoice.new(ForgeData.COATING_IDS.map(func(id: String) -> Dictionary: return { "id": id, "label": String(ForgeData.COATINGS[id].name), "title": String(ForgeData.COATINGS[id].name) }), "plasma_alumina", "Recubrimiento")
	(shop.coat as PillChoice).selected.connect(func(id: String) -> void: _post("set_coat", ["method", id]))
	shop_card.body.add_child(shop.coat)
	shop["coat_target"] = PillChoice.new([{ "id": "funda", "label": "La funda (real)", "title": "La funda aparte, como se hace de verdad" }, { "id": "garra_viva", "label": "La garra viva (FICCIÓN)", "title": "Nadie recubre la garra de un animal vivo: el simulador calcula qué le pasaría" }], "funda", "Qué se recubre")
	(shop.coat_target as PillChoice).selected.connect(func(id: String) -> void: _post("set_coat", ["target", id]))
	shop_card.body.add_child(shop.coat_target)
	shop["coat_time"] = _slider("Tiempo", 5.0, 3600.0, true, func(v: float) -> void: _post("set_coat", ["time_s", v]), "Cuánto dura el recubrimiento (s); en la garra viva, cuánto calor le llega.")
	shop["coat_cover"] = _slider("Cuánto de la punta se cubre", 0.5, 30.0, false, func(v: float) -> void: _post("set_coat", ["cover_mm", v]), "En la garra viva: los milímetros desde la punta que se recubren.")
	var b_coat := _button("Recubrir (R)", "PillGold", "Recubre con el método elegido.")
	b_coat.pressed.connect(func() -> void: _post("coat"))
	shop_card.body.add_child(_row([b_coat]))
	guide_nodes["recubrir"] = b_coat
	# probar el ajuste (5m; petición 43): el laboratorio no pega; la holgura es la del adhesivo con que se pegará en la cetrería
	shop_card.body.add_child(Ui.sub_label("Probar el ajuste (se pega en la cetrería, sobre el animal)"))
	var adh: Array = ForgeData.ADHESIVE_IDS.map(func(id: String) -> Dictionary: return { "id": id, "label": String(ForgeData.ADHESIVES[id].name).split(" (")[0], "title": String(ForgeData.ADHESIVES[id].name) })
	shop["bond"] = PillChoice.new(adh, "epoxi", "Adhesivo con el que se pegará")
	(shop.bond as PillChoice).selected.connect(func(id: String) -> void: _post("set_bond", ["adhesive", id]))
	shop_card.body.add_child(shop.bond)
	shop["gap"] = _slider("Holgura", 0.0, 3.5, false, func(v: float) -> void: _post("set_bond", ["gap_mm", v]), "El hueco entre la funda y la garra que llenará el adhesivo (mm).")
	var b_fit := _button("Probar el ajuste (U)", "PillGold", "Prueba la funda en la garra, sin pegarla: tiene que entrar con la holgura que llena el adhesivo.")
	b_fit.pressed.connect(func() -> void: _post("fit_test"))
	shop_card.body.add_child(_row([b_fit]))
	guide_nodes["ajuste"] = b_fit
	fit_label = Ui.para("", "Small", "dim")
	shop_card.body.add_child(fit_label)
	# pulir
	shop_card.body.add_child(Ui.sub_label("Pulir (la pulidora: el disco de fieltro o de cuero con pasta)"))
	shop["polish_abr"] = PillChoice.new(abr, "diamante", "Abrasivo de pulir")
	(shop.polish_abr as PillChoice).selected.connect(func(id: String) -> void: _post("set_polish", ["abrasive", id]))
	shop_card.body.add_child(shop.polish_abr)
	shop["grit"] = PillChoice.new(ForgeData.POLISH_GRITS.map(func(g: float) -> Dictionary: return { "id": Js.to_fixed(g, 0), "label": "%s µm" % Js.to_fixed(g, 0), "title": "Grano de %s µm" % Js.to_fixed(g, 0) }), "9", "Grano")
	(shop.grit as PillChoice).selected.connect(func(id: String) -> void: _post("set_polish", ["grain_um", float(id)]))
	shop_card.body.add_child(shop.grit)
	shop["sharpen"] = Pill.new("Afilar la punta")
	(shop.sharpen as Pill).pressed.connect(func() -> void: _post("set_polish", ["sharpen", not bool(_v.get("workshop", {}).get("polish", {}).get("sharpen", false))]))
	_a11y(shop.sharpen, "Afilar la punta al pulir", "Pulir no afila: con esto, la punta queda del radio del grano.")
	var b_pol := _button("Pulir (O)", "PillGold", "Pule la superficie (la capa, si la hay).")
	b_pol.pressed.connect(func() -> void: _post("polish"))
	shop_card.body.add_child(_row([shop.sharpen, b_pol]))
	guide_nodes["pulir"] = b_pol
	right.add_child(shop_card)


func _row(items: Array) -> HFlowContainer:
	var f := Ui.flow()
	for it: Control in items:
		f.add_child(it)
	return f


## Un deslizador del taller (log: en escala logarítmica). La posición la pone _paint_shop con el valor del estado.
func _slider(label: String, lo: float, hi: float, log_scale: bool, on_value: Callable, description: String, parent: Control = null) -> ValueSlider:
	var s := ValueSlider.new(label, "", 0.0, 1.0, 0.001)
	s.set_meta("lo", lo)
	s.set_meta("hi", hi)
	s.set_meta("log", log_scale)
	s.slider.custom_minimum_size.y = TOUCH if compact else 24.0
	s.value_changed.connect(func(t: float) -> void: on_value.call(_slider_value(s, t)))
	_a11y(s.slider, label, description)
	(parent if parent != null else shop_card.body).add_child(s)
	return s


## 5r · la mesa de soldar: el método (con su máquina de ficha), la pieza que se suelda, sus mandos, el gas y el solape; colocar y
## alinear; lo que se está haciendo y cuánto falta (la barra), el veredicto de la unión y la seguridad.
func _build_weld() -> void:
	weld_card = Card.new("La mesa de soldar")
	weld_card.body.add_child(Ui.para("Lo que sí se suelda es metal con metal, aquí, antes de colocar la pieza: la punta a la funda (o una funda rota). Sobre la queratina, nunca: no conduce y se quema. El titanio, siempre con argón; el metal duro, solo con plata.", "Note", "dim"))
	var v0: Dictionary = runner.latest().weld
	weld_method = PillChoice.new((v0.methods as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.label, "title": m.title }), String(v0.method), "Método")
	weld_method.selected.connect(func(id: String) -> void: _post("set_weld", ["method", id]))
	weld_card.body.add_child(weld_method)
	weld_safety = Ui.para("", "Small", "gold")
	weld_card.body.add_child(weld_safety)
	weld_card.body.add_child(Ui.sub_label("Qué se suelda"))
	weld_part = PillChoice.new((v0.parts as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.label, "title": m.title }), String(v0.part), "Qué se suelda")
	weld_part.selected.connect(func(id: String) -> void: _post("set_weld", ["part", id]))
	weld_card.body.add_child(weld_part)
	weld_mat = PillChoice.new((v0.materials as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.label, "title": m.title }), String(v0.material), "Material de la punta")
	weld_mat.selected.connect(func(id: String) -> void: _post("set_weld", ["material", id]))
	weld_card.body.add_child(weld_mat)
	weld_card.body.add_child(Ui.sub_label("Los mandos"))
	for key: String in ["energy_j", "pulse_ms", "spot_mm", "current_a", "tig_ms", "temp_c", "gap_mm"]:
		var cd := State.weld_control_data(key)
		var names := { "energy_j": "Energía por pulso", "pulse_ms": "Duración del pulso", "spot_mm": "Diámetro del punto", "current_a": "Corriente", "tig_ms": "Duración del pulso", "temp_c": "Temperatura del soplete", "gap_mm": "Holgura de la junta" }
		var helps := { "energy_j": "Julios de cada pulso del láser: con la duración dan el pico de potencia, que manda en la hondura.", "pulse_ms": "Milisegundos de cada pulso: más largo, más ancho el punto y menos pico.", "spot_mm": "El diámetro del punto enfocado: más estrecho, más densidad y más hondo.", "current_a": "Amperios del arco pulsado del micro-TIG.", "tig_ms": "Milisegundos de cada pulso del arco.", "temp_c": "La temperatura a la que el soplete lleva la junta: la plata funde entre 618 y 652 °C y el fundente se agota por encima de ~870.", "gap_mm": "La holgura entre las piezas por la que sube la plata por capilaridad (de 0,025 a 0,125 mm)." }
		var k2 := key
		weld_sliders[key] = _slider(String(names[key]), float(cd.min), float(cd.max), key in ["energy_j", "current_a", "pulse_ms", "tig_ms"], func(v: float) -> void: _post("set_weld", [k2, v]), String(helps[key]), weld_card.body)
	weld_gas_row = Ui.vbox(6)
	weld_gas = PillChoice.new((v0.gases as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.label, "title": m.title }), String(v0.gas), "Gas de protección")
	weld_gas.selected.connect(func(id: String) -> void: _post("set_weld", ["gas", id]))
	weld_gas_row.add_child(weld_gas)
	weld_overlap = PillChoice.new((v0.overlaps as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.label, "title": m.title }), String(v0.overlap), "Solape entre puntos")
	weld_overlap.selected.connect(func(id: String) -> void: _post("set_weld", ["overlap", id]))
	weld_gas_row.add_child(weld_overlap)
	weld_card.body.add_child(weld_gas_row)
	var row := Ui.flow()
	# 5x · lo recomendado para este metal y su método, también aquí (el guiado lo señala en la mesa de soldar)
	for e: Array in [["recomendado", "Poner lo recomendado (P)", "Pill", "Pone en la mesa de soldar el método y los mandos que unen este metal sin perforar la pared.", "apply_recommended"],
			["colocar", "Colocar en la mesa (Q)", "PillGold", "Pone la funda y la punta en la mesa de soldar, a ojo, y evalúa el punto con los mandos de ahora.", "weld_prepare"],
			["alinear", "Alinear (I)", "Pill", "Alinea las piezas del todo bajo el microscopio, como con el útil de alinear.", "weld_align_pieces"],
			["punto", "Un punto (J)", "Pill", "Un pulso en el primer tramo de la costura que falta (con el ratón: apretado sobre la costura y recorriéndola).", "weld_pulse_next"]]:
		var b := _button(String(e[1]), String(e[2]), String(e[3]))
		var op := String(e[4])
		b.pressed.connect(func() -> void: _post(op))
		row.add_child(b)
		weld_buttons[String(e[0])] = b
	weld_card.body.add_child(row)
	weld_align_label = Ui.para("", "Small", "dim")
	weld_card.body.add_child(weld_align_label)
	weld_what = Ui.para("", "Body")
	weld_card.body.add_child(weld_what)
	weld_bar = ProgressBar.new()
	weld_bar.min_value = 0.0
	weld_bar.max_value = 1.0
	weld_bar.step = 0.001
	weld_bar.show_percentage = false
	weld_bar.custom_minimum_size.y = 14.0
	weld_bar.accessibility_name = "Lo que lleva la costura"
	weld_card.body.add_child(weld_bar)
	weld_bar_text = Ui.para("", "Small", "text")
	weld_card.body.add_child(weld_bar_text)
	weld_verdict = Ui.para("", "Body")
	weld_card.body.add_child(weld_verdict)
	right.add_child(weld_card)


func _paint_weld(v: Dictionary) -> void:
	var w: Dictionary = v.weld
	weld_method.set_value(String(w.method))
	weld_safety.text = "Seguridad: " + String(w.safety)
	weld_part.set_value(String(w.part))
	weld_mat.set_value(String(w.material))
	weld_mat.visible = String(w.part) == "punta"
	var shown := {}
	for c: Dictionary in w.controls:
		shown[String(c.id)] = true
		_set_slider(weld_sliders[String(c.id)], float(c.value), String(c.text))
	for key: String in weld_sliders:
		(weld_sliders[key] as Control).visible = shown.has(key)
	weld_gas.visible = bool(w.has_gas)
	weld_gas.set_value(String(w.gas))
	weld_overlap.visible = String(w.method) != "braze"
	weld_overlap.set_value(String(w.overlap))
	var busy := bool(v.running)
	for id: String in weld_buttons:
		var b: Button = weld_buttons[id]
		b.disabled = busy
		var want := String(w.next) == id or (id == "punto" and String(w.next) == "soldar") or (id == "colocar" and not bool(w.on))
		b.theme_type_variation = &"PillGold" if want else &"Pill"
	(weld_buttons.alinear as Button).visible = bool(w.ready) and not bool(w.done)
	(weld_buttons.punto as Button).visible = bool(w.ready) and bool(w.aligned) and not bool(w.done)
	weld_align_label.text = String(w.align_text)
	weld_align_label.visible = bool(w.ready) and not bool(w.done)
	Ui.set_color(weld_align_label, "mint" if bool(w.aligned) else "gold")
	weld_what.text = String(w.what)
	Ui.set_color(weld_what, String(TONE.get(String(w.verdict_tone), "text")))
	var bar_on := String(w.bar_text) != ""
	weld_bar.visible = bar_on
	weld_bar_text.visible = bar_on
	weld_bar.value = float(w.progress)
	weld_bar_text.text = String(w.bar_text)
	weld_verdict.text = String(w.verdict)
	weld_verdict.visible = weld_verdict.text != ""
	Ui.set_color(weld_verdict, "mint" if String(w.verdict_tone) == "bien" else "coral")


static func _slider_value(s: ValueSlider, t: float) -> float:
	var lo := float(s.get_meta("lo"))
	var hi := float(s.get_meta("hi"))
	if bool(s.get_meta("log")):
		return lo * pow(hi / lo, clampf(t, 0.0, 1.0))
	return lo + (hi - lo) * clampf(t, 0.0, 1.0)


static func _slider_t(s: ValueSlider, v: float) -> float:
	var lo := float(s.get_meta("lo"))
	var hi := float(s.get_meta("hi"))
	if bool(s.get_meta("log")):
		return clampf(log(maxf(v, lo) / lo) / log(hi / lo), 0.0, 1.0)
	return clampf((v - lo) / (hi - lo), 0.0, 1.0)


func _build_readings() -> void:
	readings_card = Card.new("Lecturas", "")
	readings = TileGrid.new(150.0)
	readings_card.body.add_child(readings)
	right.add_child(readings_card)


func _build_sheet() -> void:
	sheet_card = Card.new("La garra, antes → después", "")
	sheet_verdict = Ui.para("", "Body")
	sheet_card.body.add_child(sheet_verdict)
	sheet_grid = GridContainer.new()
	sheet_grid.columns = 3
	sheet_grid.add_theme_constant_override("h_separation", 10)
	sheet_grid.add_theme_constant_override("v_separation", 4)
	sheet_card.body.add_child(sheet_grid)
	sheet_fiction = Ui.para("", "Note", "rose")
	sheet_card.body.add_child(sheet_fiction)
	sheet_advice = Ui.vbox(4)
	sheet_card.body.add_child(sheet_advice)
	care_note = Ui.para("", "Small", "dimmer")
	sheet_card.body.add_child(care_note)
	var row := Ui.flow()
	care_button = _button("Pasar a la cetrería para colocarla", "PillGold", "La funda terminada y sin pegar va a la cetrería: allí se coloca sobre la garra, se pega con su adhesivo y se acaba a mano.")
	care_button.pressed.connect(func() -> void:
		var c: Dictionary = _v.get("care", {})
		if bool(c.get("ok", false)):
			to_care.emit(c.setup))
	bench_button = _button("Probar en el banco", "PillGold", "Lleva la garra (su material y su afilado) a la página «Banco de ensayo».")
	bench_button.pressed.connect(func() -> void:
		var b: Dictionary = _v.get("bench_setup", {})
		if not b.is_empty():
			to_bench.emit(b))
	var again := _button("Otra pieza", "Pill", "Empieza otra pieza igual, con los mismos mandos.")
	again.pressed.connect(func() -> void: _post("restart"))
	for b: Button in [care_button, bench_button, again]:
		row.add_child(b)
	sheet_card.body.add_child(row)
	right.add_child(sheet_card)


func _build_values() -> void:
	values_card = Card.new("Valores y fuentes", "")
	values_toggle = Pill.new("Ver")
	values_toggle.pressed.connect(func() -> void:
		values_list.visible = not values_list.visible
		values_toggle.text = "Ocultar" if values_list.visible else "Ver"
		if values_list.visible:
			_paint_values(_v))
	_a11y(values_toggle, "Ver u ocultar los valores y sus fuentes")
	values_card.right.add_child(values_toggle)
	values_card.body.add_child(Ui.para("Cada dato de lo que se fabrica, con su valor, si está medido, sale de un caso parecido, es una estimación o es ficción, y su fuente.", "Note", "dim"))
	values_list = Ui.vbox(6)
	values_list.visible = false
	values_card.body.add_child(values_list)
	right.add_child(values_card)


func _build_events() -> void:
	var c := Card.new("Sucesos", "")
	events_box = Ui.vbox(6)
	c.body.add_child(events_box)
	right.add_child(c)


## Escritorio: dos columnas (la vista a la izquierda; las tarjetas a la derecha, con su desplazamiento). Teléfono: una.
func _layout() -> void:
	var w := size.x if size.x > 0.0 else (get_viewport_rect().size.x if is_inside_tree() else 1240.0)
	var wide := w >= WIDE
	vertical = not wide
	compact = not wide
	if wide:
		if right.get_parent() != right_scroll:
			right.get_parent().remove_child(right)
			right_scroll.add_child(right)
		right_scroll.visible = true
		right_scroll.custom_minimum_size = Vector2(SIDE_W, 0.0)
		right_scroll.size_flags_horizontal = Control.SIZE_FILL
		right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size.y = fit_height if fit_height > 0.0 else VIEW_H + 260.0
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view_box.custom_minimum_size.y = 300.0
		view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		if right.get_parent() == right_scroll:
			right_scroll.remove_child(right)
			add_child(right)
		right_scroll.visible = false
		custom_minimum_size.y = 0.0
		left.size_flags_vertical = Control.SIZE_FILL
		var win := get_viewport_rect().size.y if is_inside_tree() else 844.0
		view_box.custom_minimum_size.y = maxf(win * VIEW_H_PHONE, 300.0)
		view_box.size_flags_vertical = Control.SIZE_FILL
	start_button.theme_type_variation = &"PillGold" if compact else &"RunButton"
	touch_box.visible = _touch_wanted()
	if guide != null:
		guide.setup(right_scroll if wide else right, view_box)
	_update_inset()


## Lo que tapa el deslizador grande sobre la vista, por la derecha (su ancho, con un poco de aire, frente al de la vista):
## la escena encuadra cada vista en lo que queda a la izquierda, y en la vista «Horno» la columna derecha del panel no queda
## debajo (lo pidió la 5f; unidad 5j). Sin el deslizador (escritorio), nada.
func _update_inset() -> void:
	if scene != null:
		scene.call("set_inset_right", inset_right())


## La fracción del ancho de la vista que tapa el deslizador grande por la derecha (0 sin él).
func inset_right() -> float:
	if touch_box == null or view_box == null or not touch_box.visible or view_box.size.x <= 1.0:
		return 0.0
	return (-touch_box.offset_left + TOUCH_GAP) / view_box.size.x


func set_fit_height(h: float) -> void:
	if absf(h - fit_height) > 0.5:
		fit_height = h
		_layout()


# ─────────────────────────────── Escena 3D ───────────────────────────────

func _configure_scene(s: Node) -> void:
	s.set("auto_process", false)
	var q := quality
	if q == "":
		q = "movil" if OS.has_feature("mobile") or compact else ""
	s.set("quality", q)
	s.set("reduce_motion", guide.reduce_motion if guide != null else false)


func _on_scene_ready(s: Node) -> void:
	scene = s as Node3D
	scene.connect("gesture", func(op: String, args: Array) -> void: _post(op, args))
	_update_inset()
	scene.call("set_view", view, true)
	scene.call("show_view", runner.latest())


## Muestra la página (crea la escena la primera vez, arranca el hilo) o la esconde (sin sonido ni proceso).
func set_active(on: bool) -> void:
	active = on
	if on:
		if threaded and is_inside_tree() and not runner.is_threaded():
			runner.start_thread()
		_ensure_scene()
		if scene != null:
			scene.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_stop_loop()
		if scene != null:
			scene.process_mode = Node.PROCESS_MODE_DISABLED
		_post("set_pouring", [false])


## Crea la escena 3D cuando la vista ya tiene su tamaño (recién enseñada aún no lo tiene, y un visor de 0 × 0 no se puede
## dibujar); si no, lo intenta step() en el fotograma siguiente.
func _ensure_scene() -> void:
	if view3d == null or scene != null or not active:
		return
	if view3d.size.x >= 2.0 and view3d.size.y >= 2.0:
		view3d.ensure_scene()


func set_view(id: String) -> void:
	view = id
	view_seg.set_value(id)
	touch_box.visible = _touch_wanted()
	_update_inset()
	if scene != null:
		scene.call("set_view", id)
	if not _v.is_empty():
		_paint_hud(_v)


## El deslizador grande de los mandos del horno sobre la vista: en el teléfono (o una ventana estrecha), salvo en la mesa de
## soldar (5r), donde el dedo da los pulsos sobre la costura y el deslizador tapaba la pieza.
func _touch_wanted() -> bool:
	return (compact or OS.has_feature("mobile")) and view != "soldar"


func cycle_view() -> void:
	var ids: Array = Forge3D.VIEWS
	set_view(String(ids[(ids.find(view) + 1) % ids.size()]))


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	help_pill.set_on(help_panel.visible)


# ─────────────────────────────── Órdenes y pintura ───────────────────────────────

func _post(op: String, args: Array = []) -> void:
	runner.post(op, args)


## Un paso de la página (ms): la escena, el tiempo del estado y la vista nueva.
func step(ms: float) -> void:
	if runner == null:
		return
	var dt := ms / 1000.0
	if scene == null and active:
		_ensure_scene()
	if scene != null and active:
		scene.call("advance", dt)
	if dt > 0.0:
		runner.post("tick", [dt])
	var v := runner.latest()
	if int(v.get("serial", -1)) != _seen_serial:
		_apply_view(v, false)
	_advance_guide(dt)
	_update_loop()


## 5x · el aviso del guiado sigue al objeto en la pantalla (la cámara se mueve) y el borde late.
func _advance_guide(dt: float) -> void:
	if guide == null or not guide.visible:
		if guide != null:
			guide.advance(dt)
		return
	var g: Dictionary = guide.target
	var p := Vector2(-1.0, -1.0)
	var half := 0.0
	if scene != null and String(g.get("scene", "")) != "":
		if String(g.scene) == "costura":
			p = scene.call("weld_seam_screen_point", float(g.get("u", 0.5)))
			half = 14.0
		else:
			var r: Rect2 = scene.call("target_screen_rect", String(g.scene))
			p = r.get_center() if r.size != Vector2.ZERO else Vector2(-1.0, -1.0)
			half = r.size.y * 0.5
		if p.x < 0.0 or p.y < 0.0 or p.x > view_box.size.x or p.y > view_box.size.y:
			p = Vector2(-1.0, -1.0)
	guide.set_scene_point(p, half)
	guide.advance(dt)


## Pinta ya la última vista (tests y demo).
func refresh() -> void:
	_apply_view(runner.latest(), true)


func _apply_view(v: Dictionary, force: bool) -> void:
	if v.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_v = v
	_seen_serial = int(v.serial)
	if scene != null:
		scene.call("show_view", v)
	_paint_hud(v)
	if _changed("tut", [v.tutorial, v.mistake, v.feasible, v.get("guide_on", true)].hash(), force):
		_paint_tutorial(v)
	if _changed("make", [v.process, v.shape, v.wall, v.stone, v.sheath.text, v.feasible].hash(), force):
		_paint_make(v)
	if _changed("bench", (v.bench as Dictionary).hash(), force):
		_paint_bench(v)
	if _changed("furnace", [v.controls, v.running, v.stage, v.run.get("phase", ""), v.inside, v.speed].hash(), force):
		_paint_furnace(v)
	_paint_clock(v)
	if _changed("wax", [v.lost_wax, v.compensate, v.running].hash(), force):
		_paint_wax(v)
	if _changed("shop", [v.workshop, v.process, v.tool, (v.carving as Dictionary).hash(), (v.fit as Dictionary).hash()].hash(), force):
		_paint_shop(v)
	if _changed("weld", [(v.weld as Dictionary).hash(), v.running].hash(), force):
		_paint_weld(v)
	if _changed("read", (v.readouts as Array).hash(), force):
		_paint_readings(v)
	if _changed("sheet", [v.sheet, v.care, v.bench_setup].hash(), force):
		_paint_sheet(v)
	if _changed("events", (v.events as Array).hash(), force):
		_paint_events(v)
	if values_list.visible and _changed("values", [v.process, v.shape, v.wall, v.stone, v.workshop].hash(), force):
		_paint_values(v)
	_play_fx(v)
	_paint_guide(v)
	paints += 1
	last_paint_us = Time.get_ticks_usec() - t0


## Si esa parte de la vista ha cambiado (su huella: hash() es nativo y no crea textos).
func _changed(part: String, key: int, force: bool) -> bool:
	if not force and int(_keys.get(part, -1)) == key:
		return false
	_keys[part] = key
	return true


func _paint_hud(v: Dictionary) -> void:
	var lab := String(v.claw.get("label", ""))
	hud_title.text = "%s · %s%s" % [String(v.process_name), String(v.claw.name), (" · " + lab) if lab != "" else ""]
	var rv: Dictionary = v.run
	var line := String(v.stage_name)
	for r: Dictionary in v.readouts:
		if String(r.id) == "horno" and not rv.is_empty():
			line = "Horno: %s" % String(r.value)
	var clk: Dictionary = v.clock
	if bool(clk.on) and bool(clk.active):
		line += " · %s: %s · %s" % [String(clk.what), String(clk.text), String(clk.speed_name)]
	# 5r · en la mesa de soldar: qué se hace y cuánto falta, sobre la vista
	var wv: Dictionary = v.weld
	if bool(wv.get("at_bench", false)):
		line += " · " + (String(wv.bar_text) if String(wv.bar_text) != "" else String(wv.what))
	hud_state.text = line
	# 5w · junto a la balanza (la vista «La balanza» o con un tarro en la mano): cada polvo y el aviso
	var bv: Dictionary = v.bench
	var hl: Array = bv.get("hud", [])
	var at_scale := (view == "banco" or String(bv.held) != "") and not hl.is_empty() and not bool(v.running)
	hud_scale.visible = at_scale
	if at_scale:
		hud_scale.text = "Balanza: %s\n%s\n%s" % [String(bv.scale_text), "\n".join(hl), String(bv.get("status_short", bv.status_text))]
		Ui.set_color(hud_scale, String(TONE.get(String(bv.status_tone), "text")))
	var note := String(v.get("notice", ""))
	hud_notice.text = note if note != "" else ("FICCIÓN: recubrir la garra viva no se hace de verdad." if bool(v.fiction) else "")
	status_label.text = ("El laboratorio corre en su propio hilo: %s ms en el último paso." % Js.to_fixed(runner.work_ms(), 2)) if runner.is_threaded() else ""
	var sel := String(v.get("selected_control", "temp_c"))
	for c: Dictionary in v.controls:
		if String(c.id) == sel:
			touch_name.text = "%s\n%s" % [String(c.name), String(c.value_text)]
			touch_slider.set_value_no_signal(float(c.t))
	touch_box.visible = _touch_wanted()
	# 5w · en el teléfono, los textos de arriba no se meten debajo del deslizador grande (lo de la balanza lo pisaba)
	hud_box.offset_right = touch_box.offset_left - TOUCH_GAP if touch_box.visible else 0.0
	touch_start.disabled = bool(v.running)
	touch_insert.disabled = bool(v.running)


func _paint_tutorial(v: Dictionary) -> void:
	var tv: Dictionary = v.tutorial
	var st: Dictionary = tv.step
	tut_toggle.set_on(bool(tv.on))
	tut_toggle.text = "Tutorial activado" if bool(tv.on) else "Tutorial apagado"
	tut_choice.set_value(String(tv.id))
	# el acrílico de la prótesis de verdad solo tiene sentido con una garra rota (unidad 5j)
	(tut_choice.buttons[State.ACRYLIC] as Button).visible = bool(v.care.get("block", false)) or String(tv.id) == State.ACRYLIC
	var on := bool(tv.on)
	guide_toggle.visible = on
	guide_toggle.set_on(bool(v.get("guide_on", true)))
	for c: Control in [tut_choice, tut_title, tut_text, tut_source, tut_control, tut_status, tut_mistake, tut_prev, tut_next, tut_do]:
		c.visible = on
	var fz: Dictionary = v.get("feasible", {})
	tut_warn.text = String(fz.get("text", ""))
	tut_warn.visible = on and tut_warn.text != ""
	if on:
		if bool(tv.done) or st.is_empty():
			tut_title.text = "%s · terminado" % String(tv.name)
			tut_text.text = String(tv.get("done_text", ""))
			tut_source.text = ""
			tut_control.text = ""
			tut_status.text = ""
			tut_mistake.text = ""
			tut_next.disabled = true
			tut_do.disabled = true
		else:
			tut_next.disabled = false
			tut_do.disabled = false
			tut_title.text = "%s · %s (%d de %d)" % [String(tv.name), String(st.title), int(tv.index) + 1, int(tv.count)]
			tut_text.text = String(st.text)
			tut_source.text = "Fuente: " + String(st.source_short)
			tut_source.tooltip_text = String(st.source)
			tut_control.text = ("Cómo: " + String(tv.control)) if String(tv.control) != "" else ""
			tut_control.visible = tut_control.text != ""
			tut_status.text = ("✓ " if String(st.status) == "hecho" else ("· " if String(st.status) == "info" else "○ ")) + String(st.status_text)
			Ui.set_color(tut_status, "mint" if String(st.status) == "hecho" else ("dim" if String(st.status) == "info" else "gold"))
			tut_mistake.text = ("Si te equivocas: " + String(st.mistake)) if String(st.mistake) != "" else ""
			tut_mistake.visible = tut_mistake.text != ""
	var m: Dictionary = v.mistake
	mistake_box.visible = not m.is_empty()
	if not m.is_empty():
		mistake_what.text = "Qué ha pasado: %s (%s)" % [String(m.what), String(m.what_source)]
		mistake_fix.text = ("Cómo se arregla · %s: %s" % [String(m.fix_title), String(m.fix_text)]) if String(m.fix_title) != "" else ""
		mistake_fix.visible = mistake_fix.text != ""
		mistake_how.text = ("Cómo: " + String(m.control)) if String(m.control) != "" else ""
		mistake_how.visible = mistake_how.text != ""
		mistake_src.text = ("Fuente: " + String(m.fix_source)) if String(m.fix_source) != "" else ""


func _paint_make(v: Dictionary) -> void:
	var pid := String(v.process)
	for id: String in recipe_tiles:
		(recipe_tiles[id] as Button).set_pressed_no_signal(id == pid)
	for ch in recipe_detail.get_children():
		recipe_detail.remove_child(ch)
		ch.queue_free()
	for c: Dictionary in _cards:
		if String(c.id) != pid:
			continue
		recipe_detail.add_child(Ui.para(String(c.name), "CardTitle"))  # se parte: «Diamante CVD (funda…)» no cabía en 390 px
		recipe_detail.add_child(Ui.para("Sale: %s · %s" % [String(c.product), String(c.bench)], "Body", "mint" if bool(c.bench_ok) else "gold"))
		if not (c.powders as Array).is_empty():
			recipe_detail.add_child(Ui.para("Polvos: " + "; ".join(c.powders), "Body"))
		for pair: Array in [["Modo", c.mode], ["Temperatura", c.temp], ["Tiempo", c.time], ["Atmósfera", c.atmosphere], ["Presión", c.pressure], ["Molde", c.mold], ["Enfriar", c.cool], ["Crece", c.growth]]:
			if String(pair[1]) != "":
				recipe_detail.add_child(Ui.para("%s: %s" % [String(pair[0]), String(pair[1])], "Small", "text"))
		recipe_detail.add_child(Ui.para("Fuera de margen: " + String(c.defects), "Small", "coral"))
		var fz: Dictionary = v.get("feasible", {})
		if String(fz.get("text", "")) != "":
			recipe_detail.add_child(Ui.para(String(fz.text), "Body", "coral"))
		var src := Ui.para("%s · Fuente: %s" % [String(c.quality_text), String(c.source_short)], "Small", String(QUALITY_COLOR.get(String(c.quality), "dim")))
		src.tooltip_text = String(c.source)
		src.mouse_filter = Control.MOUSE_FILTER_STOP
		recipe_detail.add_child(src)
	shape_choice.set_value(String(v.shape))
	wall_choice.set_value(String(v.wall))
	sheath_note.text = "%s; %s.%s" % [String(v.sheath.text), String(v.sheath.raw_text), (" Masa: %s." % String(v.sheath.mass_text)) if String(v.sheath.mass_text) != "" else ""]
	stone_box.visible = pid == State.STONE
	stone_choice.set_value(String(v.stone))
	# el acrílico de la prótesis de verdad, con la garra rota (unidad 5j): junto a las recetas de fantasía
	(recipe_tiles[State.ACRYLIC] as Button).visible = bool(v.care.get("block", false)) or pid == State.ACRYLIC
	shape_choice.visible = pid != State.LIVE
	wall_choice.visible = pid != State.LIVE


func _paint_bench(v: Dictionary) -> void:
	var b: Dictionary = v.bench
	# los polvos de la receta, en su orden, debajo de lo que pide la pieza (5w: salían al revés, el cobalto antes que el WC)
	var at := bench_plan.get_index() + 1
	for j: Dictionary in b.jars:
		var row: Dictionary = jar_rows[String(j.id)]
		var box: Control = row.box
		var want_parent: Node = bench_card.body if bool(j.in_recipe) or float(j.grams) > 0.0 else other_box
		if box.get_parent() != want_parent:
			box.get_parent().remove_child(box)
			want_parent.add_child(box)
		if want_parent == bench_card.body:
			if box.get_index() != at:
				bench_card.body.move_child(box, at)
			at += 1
		# 5w · lo que lleva, su objetivo, lo que falta y lo que vale (sin objetivo: los gramos y la proporción)
		var lt := String(j.line) if String(j.line) != "" else "%s%s" % [String(j.grams_text), (" · " + String(j.frac_text)) if String(j.frac_text) != "" else ""]
		(row.line as Label).text = lt
		var stc := String(j.state)
		Ui.set_color(row.line, "coral" if stc in ["sobra", "fuera"] or (stc == "" and float(j.grams) > 0.0 and not bool(j.ok)) else ("mint" if stc == "bien" or (stc == "" and float(j.grams) > 0.0) else ("gold" if stc == "falta" else "dim")))
		var ds: Array = (j.doses as Array) + [j.minus]
		var changed := false
		for i in ds.size():
			if absf(float((row.dose_g as Array)[i]) - float(ds[i].g)) > 1e-12:
				row.dose_g[i] = float(ds[i].g)
				changed = true
		if changed:
			_dose_tips(row, String(j.name))
		(row.pick as Pill).set_on(String(b.held) == String(j.id))
	bench_plan.text = String(b.get("plan_text", ""))
	bench_plan.visible = bench_plan.text != ""
	var tt := String(b.get("target_text", ""))
	bench_total.text = "En el plato: %s%s%s" % [String(b.total_text), (" de %s" % tt) if tt != "" else "", (" · en el crisol: %s" % String(b.loaded_text)) if bool(b.loaded) else ""]
	bench_mix.text = String(b.get("status_text", b.mix_text))
	Ui.set_color(bench_mix, String(TONE.get(String(b.get("status_tone", "")), "text")))
	var stone := String(v.process) == State.STONE
	var acrylic := String(v.process) == State.ACRYLIC
	var lt := "Comprar la piedra (L)" if stone else ("Mezclar el acrílico (L)" if acrylic else "Cargar el crisol (L)")
	if load_button.text != lt:
		load_button.text = lt
		_a11y(load_button, lt, "Compra la piedra elegida: el bloque del que se talla la funda." if stone else ("Mezcla el polvo y el líquido del acrílico dental: queda un bloque que se pega sobre lo que queda de la garra rota y se lima en la cetrería." if acrylic else "Carga lo pesado en el crisol o en el alimentador del soplete."))
	bench_card.visible = String(v.process) != State.LIVE


func _paint_furnace(v: Dictionary) -> void:
	for c: Dictionary in v.controls:
		var row: Dictionary = control_rows.get(String(c.id), {})
		if row.is_empty():
			continue
		var m: Dictionary = c.margin
		if String(c.kind) == "dial":
			(row.widget as ValueSlider).set_value(float(c.t), String(c.value_text), String(c.value_text))
			(row.widget as ValueSlider).slider.editable = not bool(v.running)
		else:
			(row.widget as PillChoice).set_value(String(c.value))
		var note: Label = row.note
		note.text = String(m.text) if bool(m.has) else "No lo usa esta receta."
		Ui.set_color(note, ("mint" if bool(m.ok) else "gold") if bool(m.has) else "dimmer")
	start_button.disabled = bool(v.running) or String(v.process) == State.LIVE
	skip_button.disabled = not bool(v.running) and not bool(v.clock.active)
	cool_button.disabled = bool(v.running) or String(v.process) == State.LIVE
	# 5m · lo que hay dentro de la máquina del modo y la velocidad
	var iv: Dictionary = v.inside
	insert_button.disabled = bool(v.running) or String(v.process) == State.LIVE
	if String(iv.inside) != "":
		inside_label.text = "Dentro de su máquina (%s): %s." % [String(iv.name).to_lower(), String(iv.inside_name)]
		Ui.set_color(inside_label, "mint")
	elif String(iv.next) != "":
		inside_label.text = "%s, vacía: con M entra %s (%s)." % [String(iv.name), String(iv.next_name), String(iv.where)]
		Ui.set_color(inside_label, "gold")
	else:
		inside_label.text = "%s, vacía: carga primero lo pesado (L)." % String(iv.name)
		Ui.set_color(inside_label, "dim")
	speed_choice.set_value(str(int(v.speed)))
	var rv: Dictionary = v.run
	furnace_note.text = String(v.furnace_fiction) if rv.is_empty() else ""
	furnace_card.visible = String(v.process) != State.LIVE


func _paint_shop(v: Dictionary) -> void:
	var w: Dictionary = v.workshop
	(shop.carve_abr as PillChoice).set_value(String(w.carve.abrasive))
	_set_slider(shop.carve_force, float(w.carve.force_n), "%s N" % Js.to_fixed(float(w.carve.force_n), 0))
	(shop.carve_wet as Pill).set_on(bool(w.carve.coolant))
	# 5m · el tallado por pasadas, su indicador y la prueba del ajuste
	var cv: Dictionary = v.carving
	carve_tools.set_value(String(v.tool))
	var cs: Dictionary = cv.state
	carve_verdict.text = String(cs.get("text", "")) if String(cs.get("text", "")) != "" else "Sin pieza que tallar todavía."
	Ui.set_color(carve_verdict, String(TONE.get(String(cs.get("tone", "")), "text")))
	carve_last.text = String(cv.last.text)
	carve_last.visible = carve_last.text != ""
	_build_gauge(v)
	var fit: Dictionary = v.fit
	fit_label.text = String(fit.get("text", "")) if not fit.is_empty() else "Sin probar: la funda tallada y pulida se prueba en la garra antes de pasarla."
	Ui.set_color(fit_label, ("mint" if bool(fit.get("ok", false)) else "coral") if not fit.is_empty() else "dim")
	(shop.barrier as PillChoice).set_value(String(w.protect.barrier))
	_set_slider(shop.barrier_th, float(w.protect.thickness_mm), "%s mm" % Js.to_fixed(float(w.protect.thickness_mm), 1))
	(shop.coat as PillChoice).set_value(String(w.coat.method))
	(shop.coat_target as PillChoice).set_value(String(w.coat.target))
	_set_slider(shop.coat_time, float(w.coat.time_s), State.fmt_time(float(w.coat.time_s)))
	var cov := float(w.coat.cover_mm)
	_set_slider(shop.coat_cover, cov if cov > 0.0 else 5.0, ("%s mm" % Js.to_fixed(cov, 1)) if cov > 0.0 else "lo de la funda")
	(shop.coat_cover as Control).visible = String(w.coat.target) == "garra_viva" or String(v.process) == State.LIVE
	(shop.coat_target as Control).visible = String(v.process) != State.LIVE
	(shop.bond as PillChoice).set_value(String(w.bond.adhesive))
	_set_slider(shop.gap, float(w.bond.gap_mm), "%s mm" % Js.to_fixed(float(w.bond.gap_mm), 2))
	(shop.polish_abr as PillChoice).set_value(String(w.polish.abrasive))
	(shop.grit as PillChoice).set_value(Js.to_fixed(float(w.polish.grain_um), 0))
	(shop.sharpen as Pill).set_on(bool(w.polish.sharpen))


## El reloj y la velocidad (cambian en cada fotograma de la marcha: solo dos textos, si han cambiado).
func _paint_clock(v: Dictionary) -> void:
	var clk: Dictionary = v.clock
	var t := ("%s · %s" % [String(clk.what), String(clk.text)]) if bool(clk.on) else "El reloj, parado. El dial del tiempo programa el tiempo de verdad; la marcha dura eso a la velocidad elegida."
	if t == _clock_text:
		return
	_clock_text = t
	clock_label.text = t
	clock_life.text = String(clk.life)
	clock_life.visible = clock_life.text != ""


## La cera perdida (5m): sus pasos (hechos o no), los botones del que toca y, con un mineral duro, por qué no se cuela.
func _paint_wax(v: Dictionary) -> void:
	var lw: Dictionary = v.lost_wax
	var on := bool(lw.on)
	var why := String(lw.why_not)
	wax_card.visible = (on or why != "") and String(v.process) != State.LIVE and String(v.process) != State.ACRYLIC
	if not wax_card.visible:
		return
	var parts: Array = []
	for st: Dictionary in lw.steps:
		parts.append(("✓ " if bool(st.done) else "○ ") + String(st.label))
	wax_steps.text = "  ".join(parts) if on else why
	Ui.set_color(wax_steps, "text" if on else "gold")
	var nx := String(lw.next)
	for id: String in wax_buttons:
		var b: Button = wax_buttons[id]
		b.visible = on
		b.disabled = bool(v.running)
		b.theme_type_variation = &"PillGold" if id == nx else &"Pill"
	wax_compensate.visible = on
	wax_compensate.set_on(bool(lw.compensate))
	var note := String(lw.next_text)
	if on and note == "":
		var last: Dictionary = lw.invest if nx == "quemar" else (lw.wax if nx == "revestir" else lw.divest)
		note = String(last.get("text", ""))
	wax_note.text = note
	wax_note.visible = note != ""


## El indicador de la forma: la silueta de la pieza de ahora (rellena) y la de la funda (a trazos), de lado, en el plano de la
## curva de la garra (ClawMesh), con los radios del motor (carve_state().profile). Se rehace solo si ha cambiado.
func _build_gauge(v: Dictionary) -> void:
	var prof: Dictionary = (v.carving.state as Dictionary).get("profile", {})
	var key := "%d|%s" % [prof.hash(), String(v.piece.get("color", ""))]
	if key == _gauge_key:
		return
	_gauge_key = key
	_gauge_target = PackedVector2Array()
	_gauge_now = PackedVector2Array()
	if prof.is_empty():
		gauge.queue_redraw()
		return
	var k := float((v.get("claw_mesh", {}) as Dictionary).get("k", 0.0))
	_gauge_target = _outline(prof.s, prof.target, k)
	_gauge_now = _outline(prof.s, prof.now, k)
	var box := Rect2()
	var first := true
	for poly: PackedVector2Array in [_gauge_target, _gauge_now]:
		for p in poly:
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	_gauge_box = box
	_gauge_col = Color(String(v.piece.get("color", "#C7CDD6")))
	gauge.queue_redraw()


## El contorno de lado de una pieza redonda de radios rs a lo largo de la garra (s desde la base), en su curva (dibujo).
static func _outline(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in mini(ss.size(), rs.size()):
		var p := ClawMesh.point_at(ss[i], k)
		var u := ClawMesh.up_at(ss[i], k)
		var r := maxf(rs[i], 0.0)
		top.append(Vector2(p.x + u.x * r, p.y + u.y * r))
		bot.append(Vector2(p.x - u.x * r, p.y - u.y * r))
	var out := PackedVector2Array(top)
	for i in range(bot.size() - 1, -1, -1):
		out.append(bot[i])
	return out


func _draw_gauge() -> void:
	if _gauge_now.size() < 3 or _gauge_box.size.x <= 0.0:
		return
	var area := Rect2(Vector2(6.0, 6.0), gauge.size - Vector2(12.0, 12.0))
	var sc := minf(area.size.x / maxf(_gauge_box.size.x, 1e-3), area.size.y / maxf(_gauge_box.size.y, 1e-3))
	var off := area.position + (area.size - _gauge_box.size * sc) * 0.5
	var now := PackedVector2Array()
	for p in _gauge_now:
		now.append(off + Vector2(p.x - _gauge_box.position.x, _gauge_box.end.y - p.y) * sc)
	var fill := _gauge_col
	fill.a = 0.9
	if Geometry2D.triangulate_polygon(now).size() >= 3:
		gauge.draw_colored_polygon(now, fill)
	var closed := PackedVector2Array(now)
	closed.append(now[0])
	gauge.draw_polyline(closed, Palette.color("text"), 1.2, true)
	var tg := PackedVector2Array()
	for p in _gauge_target:
		tg.append(off + Vector2(p.x - _gauge_box.position.x, _gauge_box.end.y - p.y) * sc)
	tg.append(tg[0])
	for i in tg.size() - 1:
		if i % 3 != 2:
			gauge.draw_line(tg[i], tg[i + 1], Color(Palette.color("mint"), 0.95), 1.6, true)


func _set_slider(s: ValueSlider, v: float, text: String) -> void:
	s.set_value(_slider_t(s, v), text, text)


func _paint_readings(v: Dictionary) -> void:
	var seen := {}
	for r: Dictionary in v.readouts:
		var id := String(r.id)
		seen[id] = true
		if not reading_tiles.has(id):
			var box := PanelContainer.new()
			box.theme_type_variation = &"Tile"
			var col := Ui.vbox(2)
			box.add_child(col)
			col.add_child(Ui.label(String(r.label), "TileLabel"))
			var val := Ui.para("", "Body")
			col.add_child(val)
			var note := Ui.para("", "Small", "dim")
			col.add_child(note)
			readings.add_child(box)
			reading_tiles[id] = [box, val, note]
		var tile: Array = reading_tiles[id]
		(tile[1] as Label).text = String(r.value)
		Ui.set_color(tile[1], String(TONE.get(String(r.tone), "text")))
		(tile[2] as Label).text = String(r.note)
		(tile[2] as Label).visible = String(r.note) != ""
		(tile[0] as Control).visible = true
		(tile[0] as Control).accessibility_name = "%s: %s. %s" % [String(r.label), String(r.value), String(r.note)]
	for id: String in reading_tiles:
		if not seen.has(id):
			(reading_tiles[id][0] as Control).visible = false


func _paint_sheet(v: Dictionary) -> void:
	var sh: Dictionary = v.sheet
	sheet_verdict.text = String(sh.verdict_text)
	Ui.set_color(sheet_verdict, "mint" if String(sh.verdict) == "bien" else ("rose" if String(sh.verdict) == "ficcion" else ("text" if String(sh.verdict) == "incompleta" else "coral")))
	for ch in sheet_grid.get_children():
		sheet_grid.remove_child(ch)
		ch.queue_free()
	for ch in sheet_advice.get_children():
		sheet_advice.remove_child(ch)
		ch.queue_free()
	for h: String in ["", "Antes", "Después"]:
		sheet_grid.add_child(Ui.label(h, "Small", "dimmer"))
	for r: Dictionary in sh.rows:
		var lab := Ui.para(String(r.label), "Small", "dim")
		lab.custom_minimum_size.x = 90.0 if compact else 130.0
		if String(r.note) != "":
			lab.tooltip_text = String(r.note)
			lab.mouse_filter = Control.MOUSE_FILTER_STOP
		sheet_grid.add_child(lab)
		sheet_grid.add_child(Ui.para(String(r.before), "Body", "dim"))
		sheet_grid.add_child(Ui.para("→ " + String(r.after), "Body", String(TONE.get(String(r.tone), "text"))))
	var fic: Array = sh.fiction
	sheet_fiction.text = ("FICCIÓN: " + " ".join(fic)) if not fic.is_empty() else ""
	sheet_fiction.visible = not fic.is_empty()
	for a: Dictionary in sh.advice:
		sheet_advice.add_child(Ui.para(String(a.text), "Body"))
		sheet_advice.add_child(Ui.para("Fuente: " + String(a.source), "Small", "dimmer"))
	var c: Dictionary = v.care
	care_button.disabled = not bool(c.ok)
	var b: Dictionary = v.bench_setup
	bench_button.disabled = b.is_empty()
	care_note.text = String(c.text) + ((" Al banco: " + String(b.note)) if not b.is_empty() else "")


func _paint_events(v: Dictionary) -> void:
	for ch in events_box.get_children():
		events_box.remove_child(ch)
		ch.queue_free()
	if (v.events as Array).is_empty():
		events_box.add_child(Ui.para("Aún no ha pasado nada.", "Note", "dim"))
		return
	for e: Dictionary in v.events:
		var l := Ui.para(String(e.message), "Body")
		l.tooltip_text = String(e.source)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		events_box.add_child(l)
		events_box.add_child(Ui.para("Fuente: " + String(e.source_short), "Small", "dimmer"))


func _paint_values(v: Dictionary) -> void:
	var rows: Array = v.get("values", [])
	while values_rows.size() < rows.size():
		var box := Ui.vbox(1)
		var head := Ui.para("", "Body")
		box.add_child(head)
		var src := Ui.para("", "Small", "dimmer")
		box.add_child(src)
		values_list.add_child(box)
		values_rows.append([box, head, src])
	for i in values_rows.size():
		var it: Array = values_rows[i]
		(it[0] as Control).visible = i < rows.size()
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		(it[1] as Label).text = "%s: %s%s" % [String(r.label), String(r.value), (" · " + String(r.quality_text)) if String(r.quality_text) != "" else ""]
		Ui.set_color(it[1], String(QUALITY_COLOR.get(String(r.quality), "text")))
		(it[2] as Label).text = "Fuente: %s" % String(r.source)
		(it[2] as Label).tooltip_text = String(r.source_full)


## Los efectos nuevos: los sonidos con los ids del motor (bus «Lab»).
func _play_fx(v: Dictionary) -> void:
	var n := int(v.get("fx_n", 0))
	if n <= _fx_seen:
		return
	for e: Dictionary in v.fx:
		if int(e.n) <= _fx_seen:
			continue
		if String(e.kind) == "sfx" and play_sfx.is_valid() and active:
			play_sfx.call(String(e.id), 0.7)
	_fx_seen = n


## 5x · el guiado botón a botón (ClawForgeState.guide_view; solo con el tutorial y el «Guiado» encendidos): al cambiar de
## acción, la vista de la cámara que la enseña (la escena se acerca sola al objeto); en el panel, el control que toca con su
## borde que late, su etiqueta y el desplazamiento hasta él; sobre la vista, el aviso corto. Sin guiado, nada se mueve solo.
func _paint_guide(v: Dictionary) -> void:
	var g: Dictionary = v.get("guide", {})
	var on := bool(g.get("on", false))
	var node := guide_node(String(g.get("panel", ""))) if on else null
	if node != null and not node.is_visible_in_tree():
		node = null
	guide.view_inset_right = (-touch_box.offset_left + TOUCH_GAP) if touch_box.visible else 0.0
	if _changed("guide", [g, node].hash(), false):
		guide.show_target(g, node)
	var key := "%s|%s|%s" % [String(g.get("step", "")), String(g.get("id", "")), String(g.get("view", ""))] if on else ""
	if key == _guide_key:
		return
	_guide_key = key
	var want := String(g.get("view", "")) if on else ""
	if want != "" and want != view:
		set_view(want)


## El control del panel que hace la acción del guiado, por su id (claw_forge_guide.gd): null si no lo hay.
func guide_node(id: String) -> Control:
	if id == "":
		return null
	var parts := id.split(":")
	var head := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match head:
		"dosis", "quitar":
			var row: Dictionary = jar_rows.get(arg, {})
			if row.is_empty():
				return null
			var bs: Array = row.dose_b
			var i := int(parts[2]) if head == "dosis" and parts.size() > 2 else bs.size() - 1
			return bs[i] if i >= 0 and i < bs.size() else null
		"cargar":
			return load_button
		"mando":
			var cr: Dictionary = control_rows.get(arg, {})
			if cr.is_empty():
				return null
			if parts.size() > 2:
				return (cr.widget as PillChoice).buttons.get(parts[2]) if cr.widget is PillChoice else null
			return cr.widget
		"meter":
			return insert_button
		"arrancar":
			return start_button
		"acabar":
			return skip_button
		"enfriar":
			return cool_button
		"cera":
			return wax_buttons.get(arg)
		"cera_medida":
			return wax_compensate
		"herramienta":
			return carve_tools.buttons.get(arg)
		"tallar_material":
			return (shop.carve_abr as PillChoice).buttons.get(arg)
		"tallar_agua":
			return shop.carve_wet
		"tallar_fuerza":
			return shop.carve_force
		"barrera":
			return (shop.barrier as PillChoice).buttons.get(arg)
		"barrera_espesor":
			return shop.barrier_th
		"recubrimiento":
			return (shop.coat as PillChoice).buttons.get(arg)
		"recubrir_tiempo":
			return shop.coat_time
		"recubrir_punta":
			return shop.coat_cover
		"holgura":
			return shop.gap
		"pulir_abrasivo":
			return (shop.polish_abr as PillChoice).buttons.get(arg)
		"grano":
			return (shop.grit as PillChoice).buttons.get(arg)
		"soldar_recomendado", "soldar_colocar", "soldar_alinear", "soldar_punto":
			return weld_buttons.get(head.trim_prefix("soldar_"))
		"siguiente":
			return tut_next
		"tutorial":
			return tut_choice.buttons.get(arg)
	return guide_nodes.get(head)


# ─────────────────────────────── Sonido continuo ───────────────────────────────

## El bucle de la máquina que trabaja o de la muela (SfxForge), con el volumen y el tono que pide el estado.
func _update_loop() -> void:
	var snd: Dictionary = _v.get("sound", {})
	var id := String(snd.get("loop", ""))
	var on := active and id != ""
	if not on:
		if _loop.playing:
			_loop.stop()
		return
	if id != _loop_id:
		_loop_id = id
		_loop.stop()
		_loop.stream = load(Sfx.path_of(id)) if ResourceLoader.exists(Sfx.path_of(id)) else null
	_loop.pitch_scale = clampf(float(snd.get("pitch", 1.0)), 0.25, 4.0)
	_loop.volume_db = linear_to_db(maxf(float(snd.get("volume", 0.5)) * Sfx.gain(id), 0.0001))  # con el ajuste de la mezcla
	if not _loop.playing and _loop.stream != null and _loop.is_inside_tree():
		_loop.play()


func loop_playing() -> String:
	return _loop_id if _loop != null and _loop.playing else ""


func _stop_loop() -> void:
	if _loop != null and _loop.playing:
		_loop.stop()


# ─────────────────────────────── Teclado ───────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


## Las teclas del laboratorio (HELP_KEYS). Devuelve si la ha usado.
func handle_key(k: InputEventKey) -> bool:
	if k == null or not k.pressed or k.is_command_or_control_pressed() or k.alt_pressed:
		return false
	var sel := String(_v.get("selected_control", "temp_c"))
	match k.keycode:
		KEY_A:
			_post("cycle_control", [-1])
		KEY_D:
			_post("cycle_control", [1])
		KEY_W:
			_post("turn_control", [sel, 1, k.shift_pressed])
		KEY_S:
			_post("turn_control", [sel, -1, k.shift_pressed])
		KEY_ENTER, KEY_KP_ENTER:
			if not k.echo:
				_post("start")
		KEY_M:
			if not k.echo:
				_post("insert_charge")
		KEY_X:
			if not k.echo:
				_post("cycle_speed", [-1 if k.shift_pressed else 1])
		KEY_C:
			if not k.echo:
				_post("lost_wax_next")
		KEY_G:
			if not k.echo:
				_post("cycle_carve_tool", [-1 if k.shift_pressed else 1])
		KEY_SPACE:
			if not k.echo:
				_post("skip")
		KEY_E:
			if not k.echo:
				_post("cool_piece")
		KEY_L:
			if not k.echo:
				_post("load_crucible")
		KEY_BACKSPACE:
			if not k.echo:
				_post("clear_pan")
		KEY_Z:
			if not k.echo:
				_post("tare")
		KEY_T:
			if not k.echo:
				_post("carve_pass", [k.shift_pressed])
		KEY_B:
			if not k.echo:
				_post("protect")
		KEY_R:
			if not k.echo:
				_post("coat")
		KEY_U:
			if not k.echo:
				_post("fit_test")
		KEY_Q:
			if not k.echo:
				_post("weld_prepare")
		KEY_F:
			if not k.echo:
				_post("cycle_weld_method", [-1 if k.shift_pressed else 1])
		KEY_I:
			if not k.echo:
				_post("weld_align_pieces")
		KEY_J:
			_post("weld_pulse_next")
		KEY_O:
			if not k.echo:
				_post("polish")
		KEY_P:
			if not k.echo:
				_post("apply_recommended")
		KEY_N:
			if not k.echo:
				_post("tutorial_next")
		KEY_V:
			if not k.echo:
				cycle_view()
		KEY_H:
			if not k.echo:
				toggle_help()
		KEY_ESCAPE:
			if help_panel.visible:
				toggle_help()
			else:
				_post("drop_jar")
		_:
			return false
	return true


func headline() -> String:
	return "¿Zafiro a lo Minecraft, pero de verdad?"
