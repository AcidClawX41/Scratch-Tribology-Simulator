## Tribología biológica · página «Cetrería» (unidad 5b): el cuidado de las garras de una rapaz, un tigre, un oso pardo o
## un velocirraptor dormido, en 3D y con las manos, como en el taller: al abrir la página las herramientas están en su
## bandeja y el torno apagado; se coge una (clic en la bandeja, sus botones o 1-5), se lleva con el ratón sobre la garra
## y cada gesto es una llamada de ClawCare (limar, tornear, cortar, parar la sangre, desinfectar, poner crema o
## reconstruir). El tutorial va paso a paso con los de claw_care_tutorial.gd (texto, fuente legible y la condición que
## se cumple al hacerlo) y resalta en 3D dónde actuar; al terminar, la nota y los consejos de report().
## - El estado (core/lab/claw_care_state.gd) corre en su hilo (care_runner.gd): la página manda órdenes y pinta la
##   última vista. Aquí no se calcula nada: todo texto con números sale del estado o del motor.
## - La escena 3D (care_3d.tscn) se crea la primera vez que la página se ve en el árbol (en los tests sin ventana, no).
## - Sonido por el bus «Lab» (play_sfx, el de la sección): los efectos del laboratorio con los ids del motor, el zumbido
##   del torno y el roce de la lima (bucles horneados, core/lab/sfx_care.gd).
## - La página que no se ve no calcula ni suena (set_active): la sección solo llama a step() en la visible.
## Teclado: A/D ángulo · W/S presión · 1-5 herramienta · E interruptor del torno o de la amoladora · Q velocidad · P pata
## · G garra · T probar la punta · Espacio pausa · H ayuda · R de nuevo · V vista · F la forma sana · Esc dejar la
## herramienta. Ratón y dedo: en la ayuda (HELP_*). En el teléfono, sobre la vista: el deslizador de la presión y, con el
## torno o la amoladora en la mano, su interruptor y su velocidad (unidad 5c).
## - Las patas (unidad 5c): se elige la pata y, en ella, la garra (o se toca otra garra en la vista); el informe dice de
##   cuál es. El sitio para la reforja experimental (otra unidad, en el motor) queda junto a la elección del material.
## - El «Laboratorio experimental (reforja)» (unidad 5f), enchufado con plug_reforge_lab(): un interruptor sobre la vista,
##   su entrada junto al material y «Reforjar con material» cuando la garra se rompe; su página (forge_page.gd) se crea la
##   primera vez que se abre, ocupa el sitio de la cetrería mientras está abierta y devuelve la garra hecha (receive_forged).
extends BoxContainer

const State = preload("res://core/lab/claw_care_state.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const Ui = preload("res://app/common/ui.gd")
const Card = preload("res://app/common/card.gd")
const Pill = preload("res://app/common/pill.gd")
const Segmented = preload("res://app/common/segmented.gd")
const PillChoice = preload("res://app/lab/cetreria/pill_choice.gd")
const CareBondCard = preload("res://app/lab/cetreria/care_bond_card.gd")
const CareStatusBar = preload("res://app/lab/cetreria/care_status_bar.gd")
const CareMeter = preload("res://app/lab/cetreria/care_meter.gd")
const CareTipMeter = preload("res://app/lab/cetreria/care_tip_meter.gd")
const CareTipLupa = preload("res://app/lab/cetreria/care_tip_lupa.gd")
const SharpenHelp = preload("res://core/lab/claw_care_sharpen_help.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const Sfx = preload("res://core/lab/sfx.gd")
## 5tc · la lente de la cámara también sobre la vista de la reforja (la misma capa que en la clínica).
const LensLayer = preload("res://app/lab/cetreria/reaction/lens_layer.gd")
const SfxCare = preload("res://core/lab/sfx_care.gd")
# 5u · el progreso del veterinario: su motor sin nodos y su tarjeta
const VetProgress = preload("res://core/lab/vet_progress.gd")
const CareProgressCard = preload("res://app/lab/cetreria/care_progress_card.gd")
const VetMinigames = preload("res://core/lab/vet_minigames.gd")
const Lens = preload("res://core/lab/claw_care_lens.gd")
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
# 5y · el guiado del tutorial: el aviso corto y el aro sobre la vista, y el borde que late en el panel
const CareGuideView = preload("res://app/lab/cetreria/care_guide_view.gd")
const CareGuideFrame = preload("res://app/lab/cetreria/care_guide_frame.gd")

const SCENE := "res://app/lab/cetreria/care_3d.tscn"
## La página del laboratorio experimental de la reforja (se carga al abrirla por primera vez).
const FORGE_PAGE := "res://app/lab/cetreria/forge_page.gd"
const TITLE := "Cetrería: el cuidado de las garras"
const INTRO := "Recorta, lima y afila las garras de una rapaz en el banco de un centro de cetrería, o de un tigre, un oso pardo o un velocirraptor dormidos en la mesa de una clínica veterinaria, con las herramientas de verdad y el protocolo veterinario: sujeción o anestesia, la carne viva, la dirección de la lima, el calor del torno y de la amoladora, la sangre y la reconstrucción. Cada pata y cada garra, su propio ensayo. Cada paso lleva su fuente."
const BANNER := "Simulador educativo: no sustituye al veterinario. Los datos llevan su fuente («Valores y fuentes») y lo que no está medido va marcado como estimación; la nota es una rúbrica pedagógica. A un tigre, un oso o un gran carnívoro solo se le tocan las garras anestesiado."
const HELP_MOUSE := "Ratón · izquierdo sobre la bandeja: coger esa herramienta · izquierdo sobre la garra: usarla (arrastrar para limar: la pasada, de la base a la punta; mantener con el cortaúñas para cerrarlo; apretar con la gasa o el hemostático; con el torno o la amoladora encendidos, tocar y mover) · izquierdo sobre otra garra: trabajar esa · izquierdo en el aire con el torno o la amoladora: su interruptor · Mayús + arrastrar: girar la herramienta (el ángulo) · Mayús + rueda: la presión · derecho: girar la cámara · central: desplazarla · rueda: acercar."
const INTRO_TEXT := "El tutorial te lleva paso a paso, como en una consulta: preparar al animal, buscar la carne viva, recortar, limar y dar la punta, y terminar. En cada paso, qué control usar (ratón o tecla), la zona que se ilumina en la garra y la fuente de lo que se hace. Si algo sale mal, te explica qué ha pasado y cómo se arregla."
## Color de cada calidad en «Valores y fuentes» (como en «Fuentes y estimaciones» del coche en marcha).
const QUALITY_COLOR := { "primary": "mint", "secondary": "text", "estimate": "gold" }
const HELP_KEYS := "Teclado · 1-5: lima gruesa, lima fina, torno, cortaúñas, amoladora · A/D: ángulo · W/S: presión · E: encender el torno o la amoladora · Q: su velocidad · P: la pata siguiente · G: la garra siguiente · T: probar la punta · N: una herramienta nueva de la bandeja (la gastada se deja) · Espacio: pausa · V: vista · F: la forma sana · H: esta ayuda · R: empezar de nuevo · Esc: dejar la herramienta · con la pieza de la reforja: A/D la giran, K (mantenida) la aprieta y la sujeta, L enciende la lámpara."
const HELP_TOUCH := "Teléfono · un dedo: la herramienta (tocar la bandeja para cogerla; arrastrar sobre la garra para limar; tocar en el aire enciende el torno o la amoladora; tocar otra garra, trabajar esa) · el deslizador de la vista: la presión · dos dedos: girar la cámara y, al separarlos o juntarlos, acercar. Los botones de abajo hacen lo mismo que las teclas."
## Las vistas de la cámara: la garra de cerca primero (la de partida, unidad 5h); la mesa con la bandeja, el corte y el animal
## entero, aparte.
const VIEWS := [["garra", "La garra"], ["general", "General"], ["seccion", "Sección"], ["animal", "Animal"]]
## Los dibujos del velocirraptor (solo el dibujo: la garra y su física son las de la reconstrucción).
const MODELS := [["reconstruccion", "Reconstrucción"], ["pelicula", "De película (dibujo)"]]
const ANIMALS := [["rapaz", "Rapaz"], ["tigre", "Tigre"], ["oso", "Oso pardo"], ["velociraptor", "Velocirraptor"]]
const HUMIDITY := [["seca", "Seca"], ["natural", "Natural"], ["humeda", "Húmeda"], ["empapada", "Empapada"]]
## Grupos de la bandeja en la barra de herramientas.
const TRAY_GROUPS := [
	["Limas", ["lima_bastarda", "lima_fina", "lima_entrefina", "lima_diamante_gruesa", "lima_diamante_fina", "lija_p180", "lija_p240"]],
	["Giratorias y cortaúñas", ["torno", "amoladora", "guillotina", "tijera", "tenaza"]],
	["Curas", ["agua", "presion", "hemostatico", "nitrato_plata", "clorhexidina", "crema", "metacrilato"]],
	# unidad 5o: colocar la pieza de la reforja
	["Colocar la pieza", ["alcohol", "espatula"]],
]
## Ancho a partir del cual hay dos columnas y el ancho de la de las tarjetas.
const WIDE := 1000.0
const SIDE_W := 420.0
## Alto de la vista 3D (px lógicos) en escritorio y en el teléfono (fracción del alto de la ventana).
const VIEW_H := 560.0
const VIEW_H_PHONE := 0.52
const TOUCH := 44.0
## Lo que se reserva sobre la vista para que los textos no pisen el medidor «Forma de la garra» (abajo a la izquierda, de la
## escena 3D: 270 px más su relleno y su margen) ni los mandos táctiles (abajo a la derecha, 112 px). Solo con una vista
## ancha (HUD_WIDE): en el teléfono el medidor es compacto y los textos van de lado a lado.
const HUD_GAUGE_W := 300.0
const HUD_TOUCH_W := 112.0
const HUD_WIDE := 600.0
const BAR_MARGIN := 14  # el margen de la barra del animal fija en la sección del teléfono (el de las tarjetas)
## Tono de las lecturas.
const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "text" }

## Efecto de sonido: Callable(id: String, volume: float) (lo pone la sección: bus «Lab» y vibración).
var play_sfx: Callable = Callable()
var runner: Runner
var view3d: View3D
var scene: Node3D = null
var active := false
var compact := false
var quality := ""
## El estado corre en su hilo (false: en el de la interfaz; la demo, para que cada captura salga igual).
var threaded := true
var view := "garra"
var reduce_motion := false
## Métricas: vistas pintadas y coste del último repintado (µs).
var paints := 0
var last_paint_us := 0

var left: VBoxContainer
var right: VBoxContainer
## En escritorio, las tarjetas van en su propia columna con desplazamiento (la vista 3D se queda a la vista); en el
## teléfono, todo en una columna.
var right_scroll: ScrollContainer
## Alto que tiene la página en escritorio (lo pone la sección: el de su zona visible).
var fit_height := 0.0
var head_card: Card
var tools_card: Card
var readings_card: Card
var view_box: Control
var hud_tool: Label
var hud_hand: Label
var hud_action: Label
var hud_notice: Label
var hud_box: MarginContainer
var help_panel: PanelContainer
var view_seg: PillChoice
var tray_pills := {}  # id → Pill
var force_slider: ValueSlider
var angle_slider: ValueSlider
var rotary_pill: Pill
var rpm_seg: Segmented
## Las velocidades de la amoladora (cuatro, en píldoras que pasan a la línea siguiente en el teléfono; las del torno, en
## rpm_seg).
var rpm_seg_grinder: PillChoice
## Sobre la vista (sobre todo en el teléfono): la presión, el interruptor y la velocidad de la herramienta giratoria.
var touch_box: VBoxContainer
var touch_force: VSlider
var touch_power: Button
var touch_speed: Button
## La pata y la garra: un selector por animal (cuatro patas el tigre y el oso, dos los demás).
var paw_choices := {}
var digit_choices := {}
var paw_box: VBoxContainer
var model_choice: PillChoice
## El sitio de la reforja experimental, junto al material (la enchufará otra unidad).
var reforge_slot: VBoxContainer
## El laboratorio experimental de la reforja: su página (null hasta que se abre), si está abierta, si ya se ha visto su
## invitación de la primera vez (la sección lo recuerda), el interruptor de la vista y los botones que lo abren.
var lab_page: Control = null
## 5tc · la lente sobre la vista 3D de la reforja: la misma capa (lens_layer.gd) con el daño de la lente guardada de la clínica
## (view().lens del estado de la cetrería), y el serial de lo último que se le ha pintado.
var lab_lens: LensLayer = null
var _lab_lens_serial := -2
var lab_open := false
var lab_intro_seen := false
## Unidad 5t-B: la lente de la cámara sobre la vista (la puesta, lo rayada que está, «Limpiar la lente» y las dos opciones de
## accesibilidad: quitar el efecto de la lente y el temblor de la cámara) y el sonido de la reacción del animal.
var lens_box: PanelContainer
var lens_label: Label
var lens_detail: Label
var lens_risk: Label
var lens_more_btn: Button
var lens_opts: VBoxContainer
var lens_warn: Label
var lens_clean_btn: Button
var lens_fx_check: CheckBox
var lens_shake_check: CheckBox
## Las opciones de la reacción: { lens_fx, shake } (la sección puede guardarlas: reaction_options_changed).
var reaction_options := { "lens_fx": true, "shake": true }
signal reaction_options_changed(options: Dictionary)
## Tres reproductores por turnos: la voz del animal, el golpe en la lente y el rasguño suenan a la vez.
var _react_sfx: Array = []
var _react_i := 0
var lab_switch: PillChoice
var lab_entry: Button
var reforge_button: Button
var hud_claw: Label
var pause_pill: Pill
var clock_seg: PillChoice
var help_pill: Pill
## Probar la punta (unidad 5g): apoya el vértice en una uña y lo pasa de lado (ClawCareState.probe_tip; tecla T).
var probe_pill: Pill
## Una herramienta nueva de la bandeja (unidad 5l; tecla N): se ve con la de la mano gastada (embotada o vidriada).
var renew_pill: Pill
var restart_button: Button
var finish_button: Button
var tut_card: Card
## La tarjeta de la pieza de la reforja que se coloca a mano (unidad 5o).
var bond_card: CareBondCard
## La barra del estado del animal y de lo que se está haciendo (petición 51): encima de la vista en escritorio; en el teléfono,
## fija encima del desplazamiento de la sección (siempre visible aunque se baje por las tarjetas).
var status_bar: CareStatusBar
var bar_slot: MarginContainer  # la barra con su margen; es lo que se mueve a la sección en el teléfono
var _bar_fixed := false
## El tutorial guiado (petición 51): el objetivo del paso, su progreso y el del total, y el mando que hay que pulsar, resaltado.
var tut_goal: Label
var tut_step_bar: CareMeter
var tut_step_label: Label
var tut_total_bar: CareMeter
var tut_total_label: Label
var _hl: Control = null
var _hl_id := ""
var _hl_t := 0.0
## La sesión parada por el animal (petición 51), en el informe.
var report_halt: Label
var tut_flow: HFlowContainer
var tut_title: Label
var tut_text: Label
var tut_source: Label
var tut_status: Label
var tut_prev: Button
var tut_next: Button
var tut_toggle: Pill
var sedation_seg: PillChoice
var humidity_seg: PillChoice
var animal_seg: PillChoice
var raptor_flow: HFlowContainer
var raptor_pills := {}
var inlay_flow: HFlowContainer
var inlay_pills := {}
var growth_slider: ValueSlider
var growth_note: Label
## La punta con la que empiezan las garras (Roma · Natural · Afilada · Aguja) y lo que cambia en la física.
var tip_start_choice: PillChoice
var tip_start_note: Label
var readings: TileGrid
var reading_tiles := {}  # id → [PanelContainer, Label (valor), Label (nota)]
var events_box: VBoxContainer
var report_card: Card
var report_grade: Label
var report_verdict: Label
var report_quick: Label
var report_list: VBoxContainer
var report_advice: VBoxContainer
var report_regrow: Label
var resume_button: Button
var recapture_button: Button
var bench_button: Button
var bench_note: Label
var status_label: Label
## «¿Primera vez? Empieza aquí»: se enseña hasta que se pulsa una vez (la sección lo recuerda en sus ajustes).
var intro_box: PanelContainer
var intro_seen := false
var tut_control: Label
## El error que acaba de pasar: qué ha pasado y cómo se arregla (el paso del tutorial que lo arregla).
var mistake_box: PanelContainer
var mistake_what: Label
var mistake_fix: Label
var mistake_how: Label
var mistake_src: Label
var values_card: Card
var values_toggle: Pill
var values_list: VBoxContainer
var values_rows: Array = []
var sheet_grid: GridContainer
## El afilado que se ve y se entiende (unidad 5s): el medidor y la lupa de la punta sobre la vista, y en la tarjeta de las
## herramientas, para qué sirve cada una y el aviso para afilar.
var tip_box: VBoxContainer
var tip_meter: CareTipMeter
var tip_lupa: CareTipLupa
var tools_purpose: VBoxContainer
var tools_advice: Label

var _built := false
var _v: Dictionary = {}
var _seen_serial := -1
var _fx_seen := 0
var _tut_key := ""
var _report_key := ""
var _events_key := ""
var _setup_key := ""
var _flow_key := ""
var _mistake_key := ""
var _values_key := ""
var _torno: AudioStreamPlayer
var _rasp: AudioStreamPlayer
## El arranque y la parada del motor (de una vez, con el tono de la velocidad) y lo que falta del arranque (s) antes de
## que entre el bucle.
var _spin: AudioStreamPlayer
var _spin_left := 0.0
var _motor_was := false
var _motor_id := ""
var _growth_drag := false
## 5u · el progreso del veterinario (la página es su dueña: lo recupera de progress_path y lo guarda en cada cambio; sin ruta,
## en los tests y la demo, no se guarda nada), su tarjeta, la consulta que ya se ha comprobado y la última vista de la reforja
## mirada.
var progress := VetProgress.new()
var progress_card: CareProgressCard
## Arriba de la vista: el interruptor de la reforja y el botón de la tienda de lentes (fuera del panel de las herramientas y
## las garras, petición de Eric del 17-10), y si la lente ya dejó de ver la última vez que se pintó (para abrir la tienda una
## sola vez al pasar).
var mode_row: HFlowContainer
var shop_button: Button
## La pausa para calmarlo (los métodos de relajación, petición de Eric del 17-10): en la misma fila, solo cuando hace falta
## (estresado o en la pausa).
var rest_button: Button
var _rest_key := ""
var _blind_was := false
## Lo peligroso que es para la lente el animal de la mesa (ClawCareReaction.danger_of, la física de siempre), por animal y
## garra (se calcula una vez por cada uno: unos milisegundos).
var _danger: Dictionary = {}
var _danger_key := ""
var _danger_cache := {}
var progress_path := ""
var _progress_saved := -1
## (5v) La clave del minijuego pintado (se repinta solo si cambia).
var _mini_key := 0
var _progress_painted := -1
var _care_session := ""
var _care_checked := false
var _forge_serial := -1
var _weld_known := -1
var _lens_serial := -1
# 5y · el guiado: el aviso y el aro sobre la vista, el borde del panel, su interruptor, lo último que se señaló y lo atenuado
var guide_view: CareGuideView
var guide_frame: CareGuideFrame
var guide_pill: Pill
var _guide_id := ""
var _guide_key := ""
var _guide_ctrl: Control = null
## El mando señalado aún no se ha traído a la vista (se trae cuando ya está colocado).
var _reveal_pending: Control = null
var _guide_samples := PackedVector2Array()
var _guide_samples_t := 0.0
## Lo que se atenúa del panel mientras se señala un mando suyo (dibujo).
const GUIDE_DIM := 0.55
## Lo que se acerca la cámara a cada zona de la garra (× la distancia de la vista de la garra; dibujo).
const GUIDE_ZOOM := { "punta": 0.92, "herida": 0.92, "sobrante": 0.92, "angulo": 0.95, "pasada": 0.97 }


## La persona ha visto (o ha empezado) el tutorial de la primera vez: la sección lo guarda.
signal intro_done
## «Probar en el banco»: la garra terminada (animal, material y afilado: ClawCareState.bench_setup) al banco de ensayo.
signal try_on_bench(setup: Dictionary)
## La persona ha visto (o ha empezado) el tutorial de la primera vez del laboratorio de la reforja: la sección lo guarda.
signal lab_intro_done


func _init() -> void:
	name = "Cetreria"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)


## Construye la página (una vez). setup(play_sfx) la pone al día con el estado de partida.
func setup(p_play: Callable = Callable()) -> void:
	if _built:
		return
	_built = true
	play_sfx = p_play
	runner = Runner.new()
	reduce_motion = Ui.reduce_motion()
	_build()
	_apply_view(runner.latest(), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and runner != null:
		runner.stop_thread()
	# la barra fija en la sección (en el teléfono) no es hija de la página: se va con ella
	if what == NOTIFICATION_PREDELETE and _bar_fixed and bar_slot != null and is_instance_valid(bar_slot):
		bar_slot.queue_free()


func _enter_tree() -> void:
	if _built:
		_place_status_bar.call_deferred()


func _exit_tree() -> void:
	_stop_loops()
	if runner != null:
		runner.stop_thread()
	# mientras sale del árbol no se pueden mover nodos: la barra se esconde y vuelve a la página después
	if _bar_fixed and bar_slot != null:
		bar_slot.visible = false
		_home_status_bar.call_deferred()


func dispose() -> void:
	_stop_loops()
	if runner != null:
		runner.stop_thread()
	_home_status_bar.call_deferred()
	if lab_page != null:
		lab_page.call("dispose")


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
	_build_view()
	_build_intro()
	_build_tutorial()
	bond_card = CareBondCard.new(_post)
	bond_card.compact = compact
	right.add_child(bond_card)
	_build_report()
	_build_progress()
	_build_toolbar()
	_build_readings()
	_build_prepare()
	_build_animal()
	_build_values()
	_build_events()
	_build_head()
	_torno = AudioStreamPlayer.new()
	_torno.name = "ZumbidoDelTorno"
	_torno.bus = &"Lab"
	add_child(_torno)
	_rasp = AudioStreamPlayer.new()
	_rasp.name = "RoceDeLaLima"
	_rasp.bus = &"Lab"
	add_child(_rasp)
	_spin = AudioStreamPlayer.new()
	_spin.name = "ArranqueYParada"
	_spin.bus = &"Lab"
	add_child(_spin)
	# 5y · el borde que late sobre el mando del panel (encima de todo)
	guide_frame = CareGuideFrame.new()
	add_child(guide_frame)
	resized.connect(_layout)
	_layout()


func _a11y(c: Control, a_name: String, description := "") -> void:
	c.accessibility_name = a_name
	if description != "":
		c.accessibility_description = description
		if c is BaseButton or c is Range:
			c.tooltip_text = description


func _build_head() -> void:
	head_card = Card.new(TITLE)
	head_card.body.add_child(Ui.para(INTRO, "Body"))
	var band := PanelContainer.new()
	band.theme_type_variation = &"VerdictBox"
	var bl := Ui.para(BANNER, "Note", "gold")
	band.add_child(bl)
	head_card.body.add_child(band)
	right.add_child(head_card)


func _build_view() -> void:
	status_bar = CareStatusBar.new()
	bar_slot = MarginContainer.new()
	bar_slot.name = "EstadoDelAnimalSlot"
	bar_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_slot.add_child(status_bar)
	left.add_child(bar_slot)
	view_box = Control.new()
	view_box.name = "Vista"
	view_box.custom_minimum_size = Vector2(300.0, VIEW_H)
	view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_box.clip_contents = true
	left.add_child(view_box)
	view3d = View3D.new(SCENE)
	view3d.name = "Cetreria3D"
	view3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view3d.focus_mode = Control.FOCUS_ALL
	view3d.configure = _configure_scene
	view3d.scene_ready.connect(_on_scene_ready)
	view3d.gui_input.connect(_on_view_input)
	_a11y(view3d, "Vista 3D de la garra y de la bandeja de herramientas", HELP_MOUSE + " " + HELP_TOUCH)
	view_box.add_child(view3d)
	# 5y · el aro del guiado, encima de la escena y debajo de los textos
	guide_view = CareGuideView.new()
	view_box.add_child(guide_view)
	# lo que se sobrepone a la vista: la herramienta, la mano, lo último que ha hecho y los avisos
	var hud := Ui.margin(12, 10, 12, 10)
	hud_box = hud
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Ui.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)
	hud_claw = Ui.para("", "Small", "gold")
	hud_tool = Ui.para("", "Small", "text")
	hud_hand = Ui.para("", "Small", "ice")
	hud_action = Ui.para("", "Small", "dim")
	hud_notice = Ui.para("", "Small", "gold")
	for l: Label in [hud_claw, hud_tool, hud_hand, hud_action, hud_notice]:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	view_box.add_child(hud)
	view_box.resized.connect(_fit_hud)
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
	_build_tip_overlay()
	status_label = Ui.para("", "Note", "dim")
	left.add_child(status_label)
	_build_lens()


## Sobre la vista, abajo a la derecha: el deslizador vertical de la presión (el dedo aprieta más o menos) y, con el torno o la
## amoladora en la mano, su interruptor y su velocidad. En el teléfono siempre; en escritorio, con una herramienta en la
## mano (allí también están la rueda y las teclas).
func _build_touch() -> void:
	touch_box = Ui.vbox(6)
	touch_box.name = "MandosSobreLaVista"
	# abajo a la derecha: no tapa los textos de arriba de la vista
	touch_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_box.offset_left = -78.0
	touch_box.offset_right = -10.0
	touch_box.offset_top = -292.0
	touch_box.offset_bottom = -10.0
	touch_box.alignment = BoxContainer.ALIGNMENT_END
	# si un botón pide más ancho («Encender»), crece hacia dentro de la vista, no por fuera de su borde derecho
	touch_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	touch_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	touch_power = Button.new()
	touch_power.text = "Encender"
	touch_power.theme_type_variation = &"Pill"
	touch_power.custom_minimum_size = Vector2(68.0, TOUCH)
	touch_power.pressed.connect(func() -> void: _post("toggle_rotary"))
	_a11y(touch_power, "Interruptor de la herramienta giratoria", "Enciende o apaga el torno o la amoladora (tecla E).")
	touch_box.add_child(touch_power)
	touch_speed = Button.new()
	touch_speed.text = "Velocidad"
	touch_speed.theme_type_variation = &"Pill"
	touch_speed.custom_minimum_size = Vector2(68.0, TOUCH)
	touch_speed.pressed.connect(func() -> void: _post("cycle_rpm"))
	_a11y(touch_speed, "Velocidad de la herramienta giratoria", "La velocidad siguiente (tecla Q).")
	touch_box.add_child(touch_speed)
	var lab := Ui.label("Presión", "Small", "text")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
	lab.add_theme_constant_override("outline_size", 6)
	touch_box.add_child(lab)
	touch_force = VSlider.new()
	touch_force.min_value = 0.0
	touch_force.max_value = 1.0
	touch_force.step = 0.001
	touch_force.custom_minimum_size = Vector2(44.0, 150.0)
	touch_force.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	touch_force.value_changed.connect(func(t: float) -> void: _post("set_force", [State.force_from_t(t)]))
	_a11y(touch_force, "Presión de la mano", "Arriba, más presión; abajo, menos (de %s a %s N, escala logarítmica)." % [Js.to_fixed(State.FORCE_MIN, 1), Js.to_fixed(State.FORCE_MAX, 0)])
	touch_box.add_child(touch_force)
	touch_box.visible = false
	view_box.add_child(touch_box)


func _build_toolbar() -> void:
	var c := Card.new("Herramientas y mano")
	tools_card = c
	# las cuatro vistas, en píldoras que pasan a la línea siguiente si no caben (en el teléfono)
	view_seg = PillChoice.new(VIEWS.map(func(v: Array) -> Dictionary: return { "id": v[0], "label": v[1], "title": "Vista: " + String(v[1]) }), "garra", "Vista de la cámara")
	view_seg.selected.connect(set_view)
	c.body.add_child(view_seg)
	for g: Array in TRAY_GROUPS:
		c.body.add_child(Ui.sub_label(String(g[0])))
		if String(g[0]) == "Limas":
			# para qué sirve cada una y en qué orden (petición 51, «las limas, claras»)
			c.body.add_child(Ui.para("De grueso a fino: 1.º desbastar (lima gruesa; en lo duro, la de diamante gruesa), 2.º afinar (lima fina o entrefina, lija P180) y 3.º pulir y dar la punta (lija P240; en lo duro, la de diamante fina). Arrastra a lo largo de la garra, de la base a la punta; W/S, la presión; A/D, el ángulo.", "Note", "dim"))
		var flow := Ui.flow()
		for id: String in g[1]:
			var e := State.tray_entry(id)
			var key := int(e.key)
			var p := Pill.new(("%d · %s" % [key, String(e.short)]) if key > 0 else String(e.short))
			p.custom_minimum_size.y = TOUCH if compact else 32.0
			p.pressed.connect(_on_tray.bind(id))
			_a11y(p, "Coger: %s" % String(State.tool_data(id).get("name", e.short)), _tool_help(id))
			flow.add_child(p)
			tray_pills[id] = p
		c.body.add_child(flow)
		if String(g[0]) == "Giratorias y cortaúñas":
			_build_purposes(c)
	# la ayuda corta en la cabecera (no ensancha la columna); la entera, en la descripción y en «Ayuda (H)»
	force_slider = ValueSlider.new("Presión de la mano", "(W/S)", 0.0, 1.0, 0.001)
	force_slider.tooltip_text = "W y S, o Mayús + rueda del ratón"
	force_slider.value_changed.connect(func(t: float) -> void: _post("set_force", [State.force_from_t(t)]))
	_a11y(force_slider.slider, "Presión de la mano", "De %s a %s N (escala logarítmica). Teclas W y S, o Mayús + rueda." % [Js.to_fixed(State.FORCE_MIN, 1), Js.to_fixed(State.FORCE_MAX, 0)])
	c.body.add_child(force_slider)
	angle_slider = ValueSlider.new("Ángulo de la pasada", "(A/D)", State.ANGLE_MIN, State.ANGLE_MAX, 1.0)
	angle_slider.tooltip_text = "A y D, o Mayús + arrastrar sobre la garra"
	angle_slider.value_changed.connect(func(v: float) -> void: _post("set_angle", [v]))
	_a11y(angle_slider.slider, "Ángulo de la pasada", "Semiángulo de la faceta con el eje de la garra; %s. Teclas A y D, o Mayús + arrastrar sobre la garra." % State.frontal_text())
	c.body.add_child(angle_slider)
	var row := Ui.flow()
	rotary_pill = Pill.new("Encender el torno (E)")
	rotary_pill.pressed.connect(func() -> void: _post("toggle_rotary"))
	_a11y(rotary_pill, "Interruptor del torno o de la amoladora", "Enciende o apaga el torno de uñas o la amoladora (tecla E, o un clic en el aire con ella en la mano). Solo con una de las dos en la mano.")
	row.add_child(rotary_pill)
	rpm_seg = Segmented.new(State.rpm_options(), "0", "Velocidad del torno")
	rpm_seg.selected.connect(func(id: String) -> void: _post("set_rpm_index", [int(id)]))
	row.add_child(rpm_seg)
	rpm_seg_grinder = PillChoice.new(State.rpm_options("amoladora"), "0", "Velocidad de la amoladora")
	rpm_seg_grinder.selected.connect(func(id: String) -> void: _post("set_rpm_index", [int(id)]))
	rpm_seg_grinder.visible = false
	row.add_child(rpm_seg_grinder)
	pause_pill = Pill.new("Pausa (Espacio)")
	pause_pill.pressed.connect(func() -> void: _post("toggle_pause"))
	_a11y(pause_pill, "Pausa", "Para el reloj del ensayo (Espacio).")
	row.add_child(pause_pill)
	help_pill = Pill.new("Ayuda (H)")
	help_pill.pressed.connect(toggle_help)
	_a11y(help_pill, "Ayuda de los mandos", HELP_KEYS)
	row.add_child(help_pill)
	probe_pill = Pill.new("Probar la punta (T)", "Pill", false)
	probe_pill.pressed.connect(func() -> void: _post("probe_tip"))
	_a11y(probe_pill, "Probar la punta", "Apoya el vértice en una uña y lo pasa de lado con un toque ligero: una punta afilada prende, una roma resbala y una de aguja se mella (tecla T).")
	row.add_child(probe_pill)
	renew_pill = Pill.new("Una nueva (N)", "PillGold", false)
	renew_pill.pressed.connect(func() -> void: _post("renew_tool"))
	_a11y(renew_pill, "Una herramienta nueva", "Cambia la herramienta de la mano, gastada (la lima embotada o la banda vidriada), por una nueva de la bandeja: vuelve a cortar como el primer día (tecla N).")
	renew_pill.visible = false
	row.add_child(renew_pill)
	var drop := Pill.new("Dejar (Esc)", "Pill", false)
	drop.pressed.connect(func() -> void: _post("drop"))
	_a11y(drop, "Dejar la herramienta en la bandeja", "Tecla Esc.")
	row.add_child(drop)
	c.body.add_child(row)
	var row2 := Ui.flow()
	var speeds: Array = []
	for x: float in State.TIME_SCALES:
		speeds.append({ "id": Js.to_fixed(x, 0), "label": "×" + Js.to_fixed(x, 0), "title": "El ensayo avanza %s veces más deprisa que el tiempo real" % Js.to_fixed(x, 0) })
	clock_seg = PillChoice.new(speeds, "1", "Velocidad del reloj del ensayo")
	clock_seg.selected.connect(func(id: String) -> void: _post("set_time_scale", [float(id)]))
	row2.add_child(Ui.label("Reloj", "SliderLabel"))
	row2.add_child(clock_seg)
	restart_button = Button.new()
	restart_button.text = "Empezar de nuevo (R)"
	restart_button.theme_type_variation = &"Pill"
	restart_button.pressed.connect(func() -> void: _post("restart"))
	_a11y(restart_button, "Empezar de nuevo", "Otra garra igual, con la carne viva en otro sitio de su banda (tecla R).")
	row2.add_child(restart_button)
	finish_button = Button.new()
	finish_button.text = "Terminar y ver el informe"
	finish_button.theme_type_variation = &"RunButton"
	finish_button.pressed.connect(func() -> void: _post("finish"))
	_a11y(finish_button, "Terminar y ver el informe", "Para el reloj, revela la carne viva y enseña la nota y los consejos.")
	row2.add_child(finish_button)
	c.body.add_child(row2)
	right.add_child(c)


## Enchufa el panel de la reforja experimental junto a la elección del material (lo hará la unidad que la prepara).
func plug_reforge(panel: Control) -> void:
	reforge_slot.add_child(panel)
	reforge_slot.visible = true


## Ayuda de una herramienta: su nombre, su gesto y su fuente (la cita corta).
func _tool_help(id: String) -> String:
	var d := State.tool_data(id)
	var e := State.tray_entry(id)
	var how := String({
		"lima": "Arrastra sobre la garra: la pasada (de la base a la punta).",
		"torno": "Enciéndela (E o un clic en el aire) y toca la garra: unos segundos cada vez.",
		"corte": "Mantén pulsado sobre la garra donde quieras cortar: se cierra.",
		"presion": "Mantén pulsado sobre la herida: presión.",
		"aplicar": "Toca la garra para ponerlo.",
		"remojar": "Toca la garra para remojarla.",
	}.get(String(e.gesture), ""))
	var role := ""
	if State.TOOL_GUIDE.has(id):
		var gd: Array = State.TOOL_GUIDE[id]
		role = " Para %s: %s." % [String(State.ROLE_NAMES[String(gd[0])]), String(gd[2])]
	return "%s.%s %s Fuente: %s." % [String(d.get("name", e.short)), role, how, State.short_source(String(d.get("source", "")))]


## La invitación de la primera vez: empezar el tutorial (o no), y no se vuelve a enseñar.
func _build_intro() -> void:
	intro_box = PanelContainer.new()
	intro_box.theme_type_variation = &"VerdictBox"
	var col := Ui.vbox(8)
	col.add_child(Ui.label("¿Primera vez? Empieza aquí", "CardTitle"))
	col.add_child(Ui.para(INTRO_TEXT, "Body"))
	var row := Ui.flow()
	var go := Button.new()
	go.text = "Empezar el tutorial"
	go.theme_type_variation = &"PillGold"
	go.pressed.connect(func() -> void:
		_post("set_tutorial", [true])
		_post("tutorial_goto", ["preparar"])
		_dismiss_intro())
	_a11y(go, "Empezar el tutorial", "El tutorial guía paso a paso: qué hacer, con qué control y con qué fuente.")
	row.add_child(go)
	var later := Button.new()
	later.text = "Ya sé usarlo"
	later.theme_type_variation = &"Pill"
	later.pressed.connect(_dismiss_intro)
	_a11y(later, "Cerrar la invitación", "El tutorial sigue en su tarjeta, con su interruptor.")
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


## Si ya se ha visto la invitación de la primera vez (los ajustes de la sección).
func set_intro_seen(seen: bool) -> void:
	intro_seen = seen
	if intro_box != null:
		intro_box.visible = not seen


## «Valores y fuentes»: cada dato del ensayo con su valor, su calidad y su fuente (como «Fuentes y estimaciones» del
## coche en marcha). Plegada al empezar.
func _build_values() -> void:
	values_card = Card.new("Valores y fuentes", "")
	values_toggle = Pill.new("Ver")
	values_toggle.pressed.connect(func() -> void:
		values_list.visible = not values_list.visible
		values_toggle.text = "Ocultar" if values_list.visible else "Ver"
		if values_list.visible:
			_paint_values(_v, true))
	_a11y(values_toggle, "Ver u ocultar los valores y sus fuentes")
	values_card.right.add_child(values_toggle)
	values_card.body.add_child(Ui.para("Cada dato del ensayo, con su valor, si está medido, sale de un caso parecido o es una estimación, y su fuente.", "Note", "dim"))
	values_list = Ui.vbox(6)
	values_list.visible = false
	values_card.body.add_child(values_list)
	right.add_child(values_card)


func _build_tutorial() -> void:
	tut_card = Card.new("Tutorial", "")
	tut_toggle = Pill.new("Tutorial activado")
	tut_toggle.pressed.connect(func() -> void: _post("set_tutorial", [not bool(_v.get("tutorial", {}).get("on", true))]))
	_a11y(tut_toggle, "Activar o desactivar el tutorial")
	# 5y · el guiado, con su propio interruptor (solo con el tutorial activado)
	guide_pill = Pill.new("Guiado")
	guide_pill.name = "Guiado"
	guide_pill.pressed.connect(func() -> void: _post("set_guide", [not bool(_v.get("guide_on", true))]))
	_a11y(guide_pill, "Activar o desactivar el guiado", "Con el tutorial activado, el guiado señala cada acción: la herramienta de la bandeja, la zona de la garra o el mando del panel, con un aviso corto y su valor sobre la vista.")
	tut_card.right.add_child(guide_pill)
	tut_card.right.add_child(tut_toggle)
	tut_flow = Ui.flow(5, 5)
	tut_card.body.add_child(tut_flow)
	# el objetivo del paso, en pocas palabras, y su progreso (petición 51)
	tut_goal = Ui.para("", "CardTitle", "gold")
	tut_card.body.add_child(tut_goal)
	var prow := Ui.hbox(8)
	tut_step_bar = CareMeter.new(8.0)
	prow.add_child(tut_step_bar)
	tut_step_label = Ui.label("", "Small", "dim")
	prow.add_child(tut_step_label)
	tut_card.body.add_child(prow)
	tut_title = Ui.para("", "Body", "dim")
	tut_card.body.add_child(tut_title)
	tut_text = Ui.para("", "Body")
	tut_card.body.add_child(tut_text)
	tut_source = Ui.para("", "Note", "dim")
	tut_source.mouse_filter = Control.MOUSE_FILTER_STOP
	tut_card.body.add_child(tut_source)
	tut_control = Ui.para("", "Body", "mint")
	tut_card.body.add_child(tut_control)
	tut_status = Ui.para("", "Small", "gold")
	tut_card.body.add_child(tut_status)
	var trow := Ui.hbox(8)
	tut_total_bar = CareMeter.new(5.0)
	trow.add_child(tut_total_bar)
	tut_total_label = Ui.label("", "Small", "dimmer")
	trow.add_child(tut_total_label)
	tut_card.body.add_child(trow)
	var row := Ui.hbox(8)
	tut_prev = Button.new()
	tut_prev.text = "Anterior"
	tut_prev.theme_type_variation = &"Pill"
	tut_prev.pressed.connect(func() -> void: _post("tutorial_prev"))
	_a11y(tut_prev, "Paso anterior del tutorial")
	tut_next = Button.new()
	tut_next.text = "Siguiente"
	tut_next.theme_type_variation = &"PillGold"
	tut_next.pressed.connect(func() -> void: _post("tutorial_next"))
	_a11y(tut_next, "Paso siguiente del tutorial")
	row.add_child(tut_prev)
	row.add_child(tut_next)
	tut_card.body.add_child(row)
	mistake_box = PanelContainer.new()
	mistake_box.theme_type_variation = &"VerdictBox"
	var mcol := Ui.vbox(6)
	mistake_what = Ui.para("", "Body", "coral")
	mcol.add_child(mistake_what)
	mistake_fix = Ui.para("", "Body")
	mcol.add_child(mistake_fix)
	mistake_how = Ui.para("", "Body", "mint")
	mcol.add_child(mistake_how)
	mistake_src = Ui.para("", "Small", "dimmer")
	mcol.add_child(mistake_src)
	var ok := Button.new()
	ok.text = "Entendido"
	ok.theme_type_variation = &"Pill"
	ok.pressed.connect(func() -> void: _post("dismiss_mistake"))
	_a11y(ok, "Entendido", "Deja de enseñar la explicación del error.")
	mcol.add_child(ok)
	mistake_box.add_child(mcol)
	mistake_box.visible = false
	tut_card.body.add_child(mistake_box)
	right.add_child(tut_card)


func _build_prepare() -> void:
	var c := Card.new("Preparar al animal")
	c.body.add_child(Ui.sub_label("Sujeción o anestesia"))
	sedation_seg = PillChoice.new(State.sedation_options("rapaz"), "libre", "Sujeción o anestesia del animal")
	sedation_seg.selected.connect(func(id: String) -> void: _post("set_sedation", [id]))
	c.body.add_child(sedation_seg)
	c.body.add_child(Ui.sub_label("Humedad de la garra"))
	humidity_seg = PillChoice.new(HUMIDITY.map(func(h: Array) -> Dictionary: return { "id": h[0], "label": h[1], "title": State.short_source(String(CareData.KERATIN[h[0]].source)) }), "natural", "Humedad de la queratina")
	humidity_seg.selected.connect(func(id: String) -> void: _post("set_humidity", [id]))
	c.body.add_child(humidity_seg)
	c.body.add_child(Ui.para(State.humidity_note(), "Note", "dim"))
	right.add_child(c)


func _build_animal() -> void:
	var c := Card.new("Animal y garra")
	animal_seg = PillChoice.new(ANIMALS.map(func(a: Array) -> Dictionary: return { "id": a[0], "label": a[1], "title": String(CareData.ANIMALS[a[0]].note) }), "rapaz", "Animal")
	animal_seg.selected.connect(func(id: String) -> void: _post("set_animal", [id]))
	c.body.add_child(animal_seg)
	raptor_flow = Ui.flow()
	for id: String in CareData.RAPTOR_IDS:
		var nm := String(CareData.claw_entry(id).name)
		var p := Pill.new(nm)
		p.pressed.connect(func() -> void: _post("set_claw", [id]))
		_a11y(p, "Rapaz: " + nm)
		raptor_flow.add_child(p)
		raptor_pills[id] = p
	c.body.add_child(raptor_flow)
	model_choice = PillChoice.new(MODELS.map(func(m: Array) -> Dictionary: return { "id": m[0], "label": m[1],
		"title": "El dibujo del velocirraptor: la garra y su física son las de la reconstrucción" + (" (el de película es ficción)" if m[0] == "pelicula" else "") }), "reconstruccion", "Dibujo del velocirraptor")
	model_choice.selected.connect(func(id: String) -> void: _post("set_model", [id]))
	c.body.add_child(model_choice)
	# la pata y, en ella, la garra (un selector por animal)
	paw_box = Ui.vbox(6)
	paw_box.add_child(Ui.sub_label("Pata y garra"))
	for aid: String in CareData.ANIMAL_IDS:
		var pc := PillChoice.new(State.paws_of(aid).map(func(pid: String) -> Dictionary: return { "id": pid, "label": State.paw_name(aid, pid),
			"title": "Trabajar la %s" % State.paw_name(aid, pid).to_lower() }), String(State.paws_of(aid)[0]), "Pata")
		pc.selected.connect(func(pid: String) -> void: _post("set_paw", [pid]))
		pc.visible = false
		paw_box.add_child(pc)
		paw_choices[aid] = pc
		var dc := PillChoice.new((State.DIGITS[aid] as Array).map(func(d: Array) -> Dictionary: return { "id": d[0], "label": String(d[1]),
			"title": "Trabajar la garra del %s" % String(d[1]) }), String(State.digit_ids(aid)[0]), "Garra")
		dc.selected.connect(func(did: String) -> void: _post("set_digit", [did]))
		dc.visible = false
		paw_box.add_child(dc)
		digit_choices[aid] = dc
	paw_box.add_child(Ui.para("Cada garra de cada pata es su propio ensayo, con su carne viva. También: tecla P (la pata siguiente), G (la garra siguiente) o un clic sobre otra garra en la vista.", "Note", "dim"))
	c.body.add_child(paw_box)
	c.body.add_child(Ui.sub_label("Material de la garra · reforjada"))
	inlay_flow = Ui.flow(5, 5)
	for o: Dictionary in State.inlay_options():
		var iid := String(o.id)
		var ip := Pill.new(String(o.label))
		ip.pressed.connect(func() -> void: _post("set_inlay", [iid]))
		_a11y(ip, "Material de la garra: %s" % String(o.label), "%s. Las reforjadas son materiales experimentales del banco de ensayo, no tratamientos veterinarios." % String(o.title))
		inlay_flow.add_child(ip)
		inlay_pills[iid] = ip
	c.body.add_child(inlay_flow)
	# el sitio de la reforja experimental (tallar, calentar en un minihorno y recubrir): lo enchufa otra unidad con
	# plug_reforge(); hasta entonces, escondido
	reforge_slot = Ui.vbox(4)
	reforge_slot.name = "Reforja"
	reforge_slot.add_child(Ui.sub_label("Reforja experimental"))
	reforge_slot.visible = false
	c.body.add_child(reforge_slot)
	growth_slider = ValueSlider.new("Días sin desgaste", "", 0.0, 365.0, 5.0)
	# un ensayo nuevo al soltar el deslizador (o con cada paso del teclado), no con cada píxel del arrastre
	growth_slider.slider.drag_started.connect(func() -> void: _growth_drag = true)
	growth_slider.slider.drag_ended.connect(func(_changed: bool) -> void:
		_growth_drag = false
		_post("set_overgrowth_days", [growth_slider.slider.value]))
	growth_slider.value_changed.connect(func(v: float) -> void:
		if not _growth_drag:
			_post("set_overgrowth_days", [v]))
	_a11y(growth_slider.slider, "Días sin desgaste", "Cuánto ha crecido la garra de más: días al ritmo de crecimiento de su especie.")
	c.body.add_child(growth_slider)
	growth_note = Ui.para("", "Note", "dim")
	c.body.add_child(growth_note)
	# la punta al empezar (petición de Eric en la 5s): un ensayo nuevo con la punta roma, natural, afilada o de aguja
	tip_start_choice = PillChoice.new(CareData.TIP_START_IDS.map(func(id: String) -> Dictionary: return { "id": id,
		"label": String((CareData.TIP_STARTS[id] as Dictionary).name), "title": "Empezar con la punta %s" % String((CareData.TIP_STARTS[id] as Dictionary).name).to_lower() }),
		"natural", "Punta al empezar")
	tip_start_choice.selected.connect(func(id: String) -> void: _post("set_tip_start", [id]))
	c.body.add_child(tip_start_choice)
	tip_start_note = Ui.para("", "Note", "dim")
	c.body.add_child(tip_start_note)
	right.add_child(c)


func _build_readings() -> void:
	readings_card = Card.new("Lecturas", "")
	readings = TileGrid.new(150.0)
	readings_card.body.add_child(readings)
	right.add_child(readings_card)


func _build_events() -> void:
	var c := Card.new("Sucesos", "")
	events_box = Ui.vbox(6)
	c.body.add_child(events_box)
	right.add_child(c)


func _build_report() -> void:
	report_card = Card.new("Informe", "")
	report_halt = Ui.para("", "Body", "coral")
	report_halt.visible = false
	report_card.body.add_child(report_halt)
	var head := Ui.hbox(12)
	report_grade = Ui.label("", "Verdict")
	head.add_child(report_grade)
	report_verdict = Ui.para("", "Body")
	head.add_child(report_verdict)
	report_card.body.add_child(head)
	report_quick = Ui.para("", "Note", "rose")
	report_card.body.add_child(report_quick)
	report_card.body.add_child(Ui.sub_label("La garra, antes → después"))
	sheet_grid = GridContainer.new()
	sheet_grid.columns = 3
	sheet_grid.add_theme_constant_override("h_separation", 10)
	sheet_grid.add_theme_constant_override("v_separation", 4)
	report_card.body.add_child(sheet_grid)
	report_card.body.add_child(Ui.sub_label("Qué corregir"))
	report_list = Ui.vbox(4)
	report_card.body.add_child(report_list)
	report_card.body.add_child(Ui.sub_label("Consejos"))
	report_advice = Ui.vbox(4)
	report_card.body.add_child(report_advice)
	report_regrow = Ui.para("", "Note", "dim")
	report_card.body.add_child(report_regrow)
	bench_note = Ui.para("", "Small", "dimmer")
	report_card.body.add_child(bench_note)
	var row := Ui.flow()
	resume_button = Button.new()
	resume_button.text = "Seguir con esta garra"
	resume_button.pressed.connect(func() -> void: _post("resume"))
	_a11y(resume_button, "Seguir con esta garra")
	row.add_child(resume_button)
	bench_button = Button.new()
	bench_button.text = "Probar en el banco"
	bench_button.theme_type_variation = &"PillGold"
	bench_button.pressed.connect(func() -> void:
		var b: Dictionary = _v.get("bench", {})
		if not b.is_empty():
			try_on_bench.emit(b))
	_a11y(bench_button, "Probar en el banco", "Lleva esta garra (el animal, el material y lo afilada que ha quedado la punta) a la página «Banco de ensayo».")
	row.add_child(bench_button)
	recapture_button = Button.new()
	recapture_button.text = "Recogerla y encapucharla"
	recapture_button.theme_type_variation = &"PillGold"
	recapture_button.pressed.connect(func() -> void: _post("recapture"))
	_a11y(recapture_button, "Recogerla y encapucharla", "Se recoge la rapaz con la toalla, se encapucha y se deja calmar: sigues con esta garra y lo que llevas hecho.")
	recapture_button.visible = false
	row.add_child(recapture_button)
	var again := Button.new()
	again.text = "Otra garra"
	again.pressed.connect(func() -> void: _post("restart"))
	_a11y(again, "Empezar con otra garra")
	row.add_child(again)
	report_card.body.add_child(row)
	report_card.visible = false
	right.add_child(report_card)


## Escritorio: dos columnas a la altura de la zona visible (la vista 3D y sus lecturas a la izquierda; las tarjetas a la
## derecha, con su propio desplazamiento). Teléfono: una columna (la vista, el tutorial, las herramientas…).
func _layout() -> void:
	var w := size.x if size.x > 0.0 else (get_viewport_rect().size.x if is_inside_tree() else 1240.0)
	var wide := w >= WIDE
	vertical = not wide
	compact = not wide
	# en el teléfono no hay teclas: las pistas «(W/S)» y «(A/D)» sobran, y con «90° (de frente)» la fila no cabía en 390 px
	# (la sección entera se ensanchaba y las tarjetas y la barra del animal se salían por la derecha)
	for vs: Control in [force_slider, angle_slider]:
		for c in vs.name_label.get_parent().get_children():
			if c is Label and c != vs.name_label and c != vs.display:
				(c as Control).visible = wide
	if wide:
		if right.get_parent() != right_scroll:
			right.get_parent().remove_child(right)
			right_scroll.add_child(right)
		right_scroll.visible = true
		right_scroll.custom_minimum_size = Vector2(SIDE_W, 0.0)
		right_scroll.size_flags_horizontal = Control.SIZE_FILL
		right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var h := fit_height if fit_height > 0.0 else VIEW_H + 260.0
		custom_minimum_size.y = h
		# al pasar de la columna del teléfono (de unos 28 000 px) a las dos columnas, la vista 3D heredaba esa altura un
		# instante: un SubViewport de 765 × 27 856 px pasa del tope de las texturas y OpenGL avisaba
		# GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT (docs/fase2/qa-sonido.md)
		if size.y > 2.0 * h:
			size.y = h
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
	for id: String in tray_pills:
		(tray_pills[id] as Control).custom_minimum_size.y = TOUCH if compact else 32.0
	# el botón grande de terminar no cabe en el teléfono: allí, como una píldora dorada
	finish_button.theme_type_variation = &"PillGold" if compact else &"RunButton"
	_place_status_bar()
	# la calidad de la escena 3D sigue al ancho (al cambiar el tamaño de la ventana)
	if scene != null and String(scene.get("quality")) != _scene_quality():
		scene.call("set_quality", _scene_quality())
	if lab_open:
		right_scroll.visible = false


## Alto de la página en escritorio: el de la zona visible de la sección (la vista 3D llena lo que queda).
func set_fit_height(h: float) -> void:
	if lab_page != null:
		lab_page.call("set_fit_height", h)
	if absf(h - fit_height) > 0.5:
		fit_height = h
		_layout()


# ─────────────────────────────── Escena 3D ───────────────────────────────

func _configure_scene(s: Node) -> void:
	s.set("auto_process", false)
	s.set("quality", _scene_quality())


## La calidad de la escena 3D: la pedida o, si no, la del teléfono en un teléfono o en una ventana estrecha. Se mira el
## ancho de la ventana, no el de la página: la escena se crea antes de que la página se coloque, y con el ancho de antes
## (estrecho) el escritorio salía con la calidad del teléfono.
func _scene_quality() -> String:
	if quality != "":
		return quality
	var narrow := get_viewport_rect().size.x < WIDE if is_inside_tree() else compact
	return "movil" if OS.has_feature("mobile") or narrow else ""


func _on_scene_ready(s: Node) -> void:
	scene = s as Node3D
	scene.connect("gesture", _on_gesture)
	scene.call("set_view", view, true)
	scene.call("show_view", runner.latest())
	# 5t-B: el sonido de la reacción del animal y las opciones de la lente
	scene.connect("reaction_sfx", _on_reaction_sfx)
	set_reaction_options(reaction_options)


func _on_gesture(op: String, args: Array) -> void:
	_post(op, args)


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		view3d.grab_focus()


## Muestra la página (crea la escena la primera vez, arranca el hilo) o la esconde (sin sonido ni proceso).
func set_active(on: bool) -> void:
	active = on
	_sync_status_bar()
	# la hoja de la tienda va en su propia capa, que no se esconde con la página: se cierra al salir
	if not on and progress_card != null and progress_card.shop_overlay.visible:
		progress_card.set_open("shop", false)
	if lab_open:
		# con el laboratorio abierto, el que calcula y suena es él; la escena de la cetrería, parada
		lab_page.call("set_active", on)
		on = false
	if on:
		if threaded and is_inside_tree() and not runner.is_threaded():
			runner.start_thread()
		if view3d != null:
			view3d.ensure_scene()
		if scene != null:
			scene.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_stop_loops()
		if scene != null:
			scene.process_mode = Node.PROCESS_MODE_DISABLED
		_post("release")


func set_view(id: String, instant := false) -> void:
	view = id
	view_seg.set_value(id)
	if scene != null:
		scene.call("set_view", id, instant)
	_post("note_view", [id])


func cycle_view() -> void:
	var ids: Array = VIEWS.map(func(v: Array) -> String: return v[0])
	set_view(String(ids[(ids.find(view) + 1) % ids.size()]))


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	help_pill.set_on(help_panel.visible)


# ─────────────────────────────── Órdenes ───────────────────────────────

func _post(op: String, args: Array = []) -> void:
	runner.post(op, args)


func _on_tray(id: String) -> void:
	if String(_v.get("hand", {}).get("tool", "")) == id:
		_post("drop")
	else:
		_post("pick", [id])


## Un paso de la página (ms): la escena (el ratón, la herramienta, los efectos), el tiempo del estado y la vista nueva.
func step(ms: float) -> void:
	if runner == null:
		return
	if lab_open:
		lab_page.call("step", ms)
		# 5tc · la lente sigue en la cámara; el animal se queda en la clínica: su estado no avanza (no hay «tick»)
		_lab_lens_step(ms / 1000.0)
		return
	var dt := ms / 1000.0
	if scene != null and active:
		scene.call("advance", dt)
	if dt > 0.0:
		runner.post("tick", [dt])
	var v := runner.latest()
	if int(v.get("serial", -1)) != _seen_serial or not is_same(v.get("mesh"), _v.get("mesh")):
		_apply_view(v, false)
	_update_loops(dt)
	_pulse_highlight(dt)
	_guide_step(dt)


## Pinta ya la última vista (tests y demo).
func refresh() -> void:
	if lab_open:
		lab_page.call("refresh")
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
	_paint_hand(v)
	_paint_tray(v)
	_paint_setup(v, force)
	_paint_tutorial(v, force)
	_paint_guide(v)
	_paint_readings(v)
	_paint_events(v, force)
	_paint_report(v, force)
	_paint_mistake(v)
	_paint_values(v, force)
	_paint_lab(v)
	bond_card.paint(v.get("bond", {}), float(v.get("time_scale", 1.0)))
	status_bar.paint((v.get("animal", {}) as Dictionary).get("meters", []), v.get("activity", {}))
	_paint_tip(v)
	_paint_rest(v.get("animal", {}))
	_progress_check(v)
	_play_fx(v)
	_paint_lens(v)
	paints += 1
	last_paint_us = Time.get_ticks_usec() - t0


func _paint_hud(v: Dictionary) -> void:
	var tx: Dictionary = v.texts
	hud_claw.text = String(v.get("claw_label", ""))
	hud_tool.text = String(tx.tool)
	hud_hand.text = String(tx.hand)
	hud_action.text = String(tx.action)
	var notice := String(v.notice)
	if notice == "":
		notice = String(tx.status)
	hud_notice.text = notice
	# 5y · con el guiado, su aviso dice qué coger y qué hacer: la ficha larga de la herramienta se esconde (está en la tarjeta de
	# las herramientas) y, en el teléfono, también las líneas de la mano, para que el aviso quepa sin tapar la garra
	var guided := not (v.get("guide", {}) as Dictionary).is_empty()
	hud_tool.visible = not guided
	for l: Label in [hud_hand, hud_action]:
		l.visible = not (guided and compact)
	status_label.text = ("El ensayo corre en su propio hilo: %s ms en el último paso." % Js.to_fixed(runner.work_ms(), 2)) if runner.is_threaded() else ""


## Los textos de encima de la vista, sin pisar el medidor ni los mandos táctiles: en una vista ancha empiezan a la derecha
## del medidor y, con los mandos a la vista, acaban antes de ellos.
func _fit_hud() -> void:
	if hud_box == null:
		return
	var wide := view_box.size.x >= HUD_WIDE
	hud_box.add_theme_constant_override("margin_left", int(12.0 + (HUD_GAUGE_W if wide else 0.0)))
	hud_box.add_theme_constant_override("margin_right", int(12.0 + (HUD_TOUCH_W if wide and touch_box != null and touch_box.visible else 0.0)))


func _paint_hand(v: Dictionary) -> void:
	var h: Dictionary = v.hand
	force_slider.set_value(float(h.force_t), String(h.force_text), String(h.force_text))
	angle_slider.set_value(float(h.angle_deg), String(h.angle_text), String(h.angle_text))
	rotary_pill.set_on(bool(h.rotary_on))
	var grinder := String(h.get("rotary_tool", "torno")) == "amoladora"
	var what := "la amoladora" if grinder else "el torno"
	rotary_pill.text = ("Apagar %s (E) · %s" % [what, String(h.rpm_text)]) if bool(h.rotary_on) else "Encender %s (E)" % what
	rotary_pill.disabled = not bool(h.get("rotary", false))
	# la de la mano, gastada: se puede cambiar por una nueva (unidad 5l)
	renew_pill.visible = bool(h.get("worn", false))
	rpm_seg.visible = not grinder
	rpm_seg_grinder.visible = grinder
	(rpm_seg_grinder if grinder else rpm_seg).set_value(str(int(h.rpm_index)))
	# sobre la vista: la presión (con una herramienta en la mano o en el teléfono) y el interruptor y la velocidad
	touch_box.visible = String(h.tool) != "" and (compact or bool(h.get("rotary", false)) or OS.has_feature("mobile"))
	_fit_hud()
	touch_power.visible = bool(h.get("rotary", false))
	touch_speed.visible = bool(h.get("rotary", false))
	touch_power.text = "Apagar" if bool(h.rotary_on) else "Encender"
	touch_speed.text = String(h.rpm_text).replace(" rpm", "\nrpm")
	touch_force.set_value_no_signal(float(h.force_t))
	pause_pill.set_on(bool(v.paused))
	clock_seg.set_value(Js.to_fixed(float(v.get("time_scale", 1.0)), 0))
	finish_button.disabled = bool(v.finished)


func _paint_tray(v: Dictionary) -> void:
	for t: Dictionary in v.tray:
		var p: Pill = tray_pills.get(String(t.id))
		if p == null:
			continue
		p.set_on(bool(t.held))
		p.theme_type_variation = &"PillGold" if bool(t.suggested) and not bool(t.held) else &"Pill"


func _paint_setup(v: Dictionary, force: bool) -> void:
	var s: Dictionary = v.setup
	var sn: Dictionary = v.snap
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [String(s.animal), String(s.claw), String(s.inlay), str(s.overgrowth_days), String(sn.animal.sedation),
		String(sn.claw.humidity), String(v.get("paw", "")), String(v.get("digit", "")), String(v.get("model", "")), String(s.get("tip_start", "natural"))]
	if key == _setup_key and not force:
		return
	_setup_key = key
	animal_seg.set_value(String(s.animal))
	for aid: String in paw_choices:
		var on := aid == String(s.animal)
		(paw_choices[aid] as Control).visible = on
		(digit_choices[aid] as Control).visible = on and (State.DIGITS[aid] as Array).size() > 1
		if on:
			(paw_choices[aid] as PillChoice).set_value(String(v.get("paw", "")))
			(digit_choices[aid] as PillChoice).set_value(String(v.get("digit", "")))
	model_choice.visible = String(s.animal) == "velociraptor"
	model_choice.set_value(String(v.get("model", "reconstruccion")) if String(v.get("model", "")) != "" else "reconstruccion")
	raptor_flow.visible = String(s.animal) == "rapaz"
	for id: String in raptor_pills:
		(raptor_pills[id] as Pill).set_on(id == String(s.claw))
	for iid: String in inlay_pills:
		(inlay_pills[iid] as Pill).set_on(iid == String(s.inlay))
	growth_slider.set_value(float(s.overgrowth_days), String(v.texts.overgrowth_days))
	# una garra reforjada no crece (material inerte): el deslizador de los días no se aplica
	var inert := String(s.inlay) != "none"
	growth_slider.slider.editable = not inert
	growth_slider.modulate.a = 0.45 if inert else 1.0
	growth_note.text = String(v.texts.overgrowth)
	tip_start_choice.set_value(String(s.get("tip_start", "natural")))
	tip_start_note.text = String(v.texts.get("tip_start", ""))
	for o: Dictionary in State.sedation_options(String(s.animal)):
		sedation_seg.set_label(String(o.id), String(o.label))
	sedation_seg.set_value(String(sn.animal.sedation))
	humidity_seg.set_value(String(sn.claw.humidity))


func _paint_tutorial(v: Dictionary, force: bool) -> void:
	var tv: Dictionary = v.tutorial
	var st: Dictionary = tv.step
	_paint_tutorial_progress(tv)
	var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [str(tv.on), String(tv.process), str(tv.index), String(st.get("status", "")), str(tv.done), str(tv.processes.size()), String(st.get("status_text", "")), str(_guide_active())]
	if key == _tut_key and not force:
		return
	_tut_key = key
	tut_toggle.set_on(bool(tv.on))
	tut_toggle.text = "Tutorial activado" if bool(tv.on) else "Tutorial apagado"
	var fk := var_to_str(tv.processes)
	if fk != _flow_key:
		_flow_key = fk
		for ch in tut_flow.get_children():
			tut_flow.remove_child(ch)
			ch.queue_free()
		for p: Dictionary in tv.processes:
			var b := Pill.new(String(p.name))
			b.pressed.connect(func() -> void: _post("tutorial_goto", [String(p.id)]))
			tut_flow.add_child(b)
	var i := 0
	for p: Dictionary in tv.processes:
		var b := tut_flow.get_child(i) as Pill
		if b != null:
			# el que toca, encendido; los hechos, con su marca
			var done := String(p.state) == "hecho"
			b.set_on(String(p.state) == "ahora")
			b.text = ("✓ " if done else "") + String(p.name)
			_a11y(b, "Ir al proceso: %s%s" % [String(p.name), " (hecho)" if done else ""])
		i += 1
	var body_on := bool(tv.on)
	for c: Control in [tut_title, tut_text, tut_source, tut_status, tut_prev, tut_next, tut_control, tut_goal]:
		c.visible = body_on
	tut_flow.visible = body_on
	(tut_step_bar.get_parent() as Control).visible = body_on
	(tut_total_bar.get_parent() as Control).visible = body_on
	if not body_on:
		_set_highlight("")
		return
	if bool(tv.done) or st.is_empty():
		if not _guide_active():
			_set_highlight("boton:terminar")
		tut_goal.text = "Objetivo: terminar y mirar el informe"
		tut_title.text = "Tutorial terminado"
		tut_text.text = "Ya has recorrido todos los pasos. Pulsa «Terminar y ver el informe» para ver la nota, los consejos y dónde estaba la carne viva."
		tut_source.text = ""
		tut_status.text = ""
		tut_next.disabled = true
		return
	tut_next.disabled = false
	tut_goal.text = "Objetivo: %s" % String(tv.get("goal", st.title))
	if not _guide_active():
		_set_highlight(String(tv.get("ui", "")))
	tut_title.text = "%s · %s (%d de %d)" % [String(tv.process_name), String(st.title), int(tv.index) + 1, int(tv.count)]
	tut_text.text = String(st.text)
	tut_source.text = "Fuente: " + String(st.source_short)
	tut_source.tooltip_text = State.readable_source(String(st.source))
	tut_source.accessibility_description = State.readable_source(String(st.source))
	tut_control.text = ("Cómo: " + String(tv.control)) if String(tv.get("control", "")) != "" else ""
	tut_control.visible = tut_control.text != ""
	tut_status.text = ("✓ " if String(st.status) == "hecho" else ("· " if String(st.status) == "info" else "○ ")) + String(st.status_text)
	Ui.set_color(tut_status, "mint" if String(st.status) == "hecho" else ("dim" if String(st.status) == "info" else "gold"))


## El progreso del tutorial (petición 51): el del paso (la cuenta de lo que pide: los segundos, lo que falta, el tiempo de lectura
## de un informativo) y el del total. Cada vez: cambia mientras se trabaja.
func _paint_tutorial_progress(tv: Dictionary) -> void:
	var pr: Dictionary = tv.get("progress", {})
	if pr.is_empty():
		return
	var st: Dictionary = tv.get("step", {})
	var status := String(st.get("status", ""))
	tut_step_bar.set_state(float(pr.step), -1.0, "bien" if status == "hecho" else ("" if status == "info" else "aviso"))
	tut_step_label.text = String(pr.get("step_text", ""))
	tut_step_label.visible = tut_step_label.text != ""
	tut_total_bar.set_state(float(pr.total), -1.0, "bien")
	tut_total_label.text = "Tutorial: %s" % String(pr.get("total_text", "")) if String(pr.get("total_text", "")) != "" else ""


## El mando que hay que pulsar en el paso del tutorial (STEP_UI del estado: «sedacion:id», «humedad:id», «vista:id», «reloj:×»,
## «boton:probar|terminar» o «pieza:id»), o null.
func _ui_target(ui: String) -> Control:
	var parts := ui.split(":")
	if parts.size() != 2:
		return null
	var id := String(parts[1])
	match String(parts[0]):
		"sedacion":
			return sedation_seg.buttons.get(id)
		"humedad":
			return humidity_seg.buttons.get(id)
		"vista":
			return view_seg.buttons.get(id)
		"reloj":
			return clock_seg.buttons.get(id)
		"boton":
			return _button_target(id)
		"pieza":
			return bond_card.buttons.get(id)
		# 5y · los del guiado: las velocidades, la mano y las herramientas de la bandeja
		"rpm":
			var seg: Control = rpm_seg_grinder if rpm_seg_grinder.visible else rpm_seg
			var b: Control = seg.buttons.get(id)
			return b if b != null else rpm_seg_grinder.buttons.get(id)
		"mano":
			if id == "presion":
				return touch_force if compact and touch_box.visible else force_slider
			return angle_slider if id == "angulo" else null
		"bandeja":
			return tray_pills.get(id)
	return null


## Los botones que señalan el tutorial y el guiado (5y): «boton:id».
func _button_target(id: String) -> Control:
	match id:
		"probar":
			return probe_pill
		"terminar":
			return finish_button
		"siguiente":
			return tut_next
		"pausa":
			return pause_pill
		"calmar":
			return rest_button
		"recoger":
			return recapture_button
		"empezar":
			return restart_button
		"seguir":
			return resume_button
		"torno":
			return touch_power if compact and touch_box.visible and touch_power.visible else rotary_pill
		"informe":
			return report_card
		"tienda":
			return shop_button
	return null


## Resalta el mando del paso (deja el de antes como estaba).
func _set_highlight(ui: String) -> void:
	if ui == _hl_id:
		return
	if _hl != null and is_instance_valid(_hl):
		_hl.self_modulate = Color.WHITE
	_hl_id = ui
	_hl = _ui_target(ui)
	_hl_t = 0.0


## El mando resaltado late (dibujo: entre su color y el dorado de la paleta).
func _pulse_highlight(dt: float) -> void:
	if _hl == null or not is_instance_valid(_hl):
		return
	_hl_t += dt
	var k := 0.5 + 0.5 * sin(_hl_t * 5.0)
	_hl.self_modulate = Color.WHITE.lerp(Palette.color("gold"), 0.25 + 0.45 * k)


# ─────────────────────────────── 5y · el guiado ───────────────────────────────

func _guide_active() -> bool:
	return not (_v.get("guide", {}) as Dictionary).is_empty()


## El guiado (unidad 5y): el aviso corto y el aro sobre la vista; el mando del panel, resaltado con su borde que late y su
## etiqueta, y lo demás del panel algo atenuado; al cambiar lo que señala, la cámara va a la vista que toca y se acerca a la
## zona de la garra, y el panel se desplaza hasta el mando (en el teléfono, a la vista si lo señalado está en la escena).
## Con «Tutorial apagado» o «Guiado» apagado, nada se resalta ni se mueve solo.
func _paint_guide(v: Dictionary) -> void:
	var g: Dictionary = v.get("guide", {})
	var tv: Dictionary = v.get("tutorial", {})
	guide_pill.set_on(bool(v.get("guide_on", true)))
	guide_pill.text = "Guiado" if bool(v.get("guide_on", true)) else "Sin guiado"
	guide_pill.visible = bool(tv.get("on", true))
	guide_view.show_guide(g)
	if g.is_empty():
		if _guide_id != "":
			_guide_id = ""
			_guide_key = ""
			_guide_ctrl = null
			guide_frame.follow(null, "")
			_dim_panel(null)
			# (lo que resalta el tutorial sin el guiado ya lo ha puesto _paint_tutorial)
			if scene != null:
				scene.call("guide_focus", -1.0, 1.0, true)
		return
	var id := String(g.id)
	var panel := String(g.where) == "panel"
	var ctrl := _guide_control(g)
	var tone := String({ "mal": "coral", "bien": "mint" }.get(String(g.tone), "gold"))
	_set_highlight(id if panel else ("bandeja:" + String(g.tool) if String(g.kind) == "herramienta" else ""))
	# en el teléfono, la herramienta se señala en la bandeja 3D (sin bajar hasta su píldora, lejos de la vista)
	var framed: Control = ctrl if panel or not compact else null
	guide_frame.follow(framed, String(g.label), tone, _clip_of(framed))
	_dim_panel(ctrl if panel else null)
	if id == _guide_id and String(g.key) == _guide_key:
		return
	var moved := id != _guide_id
	_guide_id = id
	_guide_key = String(g.key)
	_guide_ctrl = ctrl
	if not moved:
		return
	if String(g.view) != "" and String(g.view) != view:
		set_view(String(g.view), reduce_motion)
	if scene != null:
		if String(g.kind) == "garra":
			scene.call("guide_focus", float(g.s_mm), float(GUIDE_ZOOM.get(String(g.zone), 1.0)), reduce_motion)
		else:
			scene.call("guide_focus", -1.0, 1.0, true)
	# el panel (o, en el teléfono, la vista) se trae cuando el mando ya está colocado: en el siguiente paso
	_reveal_pending = framed if framed != null else (view_box if compact and not panel else null)
	# en el teléfono, un paso que solo se lee (y sigue solo) no aparta la vista de la garra
	if compact and panel and String((g.get("act", {}) as Dictionary).get("op", "")) == "esperar":
		_reveal_pending = null


## Cada fotograma: el aro sigue a lo que señala en la escena y el borde, al mando (el panel se desplaza); los dos laten.
func _guide_step(dt: float) -> void:
	if guide_view == null:
		return
	var g: Dictionary = _v.get("guide", {})
	if not g.is_empty() and scene != null and active and not lab_open:
		guide_view.set_point(scene.call("guide_screen_point", g))
	else:
		guide_view.set_point(Vector2(-1.0, -1.0))
	# el aviso, arriba (debajo de los textos de la vista) o abajo: donde tape menos la garra
	if not g.is_empty() and hud_box != null:
		var col := hud_box.get_child(0) as Control
		var top := col.get_global_rect().end.y - view_box.get_global_rect().position.y + 6.0
		# los puntos de la garra en la pantalla, cada CareGuideView.PLACE_EVERY_S (el aviso solo se recoloca entonces)
		_guide_samples_t -= dt
		if _guide_samples_t <= 0.0 and scene != null:
			_guide_samples_t = CareGuideView.PLACE_EVERY_S
			_guide_samples = scene.call("claw_screen_samples")
		var samples := _guide_samples
		var gauge: Rect2 = scene.call("gauge_rect") if scene != null else Rect2()
		var touch := touch_box.size.x if touch_box.visible else 0.0
		guide_view.place(top, float(hud_box.get_theme_constant("margin_left")), float(hud_box.get_theme_constant("margin_right")), gauge, touch, samples, compact, dt)
	if _reveal_pending != null and is_instance_valid(_reveal_pending) and _reveal_pending.size.y > 0.0:
		_reveal(_reveal_pending)
		_reveal_pending = null
	guide_view.advance(dt)
	guide_frame.advance(dt)


## El control del panel de un objetivo del guiado (los del panel; la píldora de la herramienta de la bandeja), o null.
func _guide_control(g: Dictionary) -> Control:
	if String(g.get("where", "")) == "panel":
		return _ui_target(String(g.id))
	if String(g.get("kind", "")) == "herramienta" and String(g.id) != "bandeja":
		return tray_pills.get(String(g.tool))
	return null


## El resto del panel, algo atenuado mientras se señala un mando suyo (sin bloquearlo); except null lo deja todo como estaba.
func _dim_panel(except: Control) -> void:
	var inside := except != null and right.is_ancestor_of(except)
	for c in right.get_children():
		if c is Control:
			var keep := not inside or c == except or (c as Control).is_ancestor_of(except)
			(c as Control).modulate.a = 1.0 if keep else GUIDE_DIM


## El recorte del borde: el desplazamiento que contiene el control (lo que queda fuera no se ve), o ninguno.
func _clip_of(c: Control) -> Rect2:
	var sc := _scroll_of(c)
	return sc.get_global_rect() if sc != null else Rect2()


static func _scroll_of(c: Control) -> ScrollContainer:
	var n: Node = c.get_parent() if c != null else null
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


## Desplaza lo que contiene el control (la columna de las tarjetas o la sección) hasta que se vea, con una transición corta
## (sin ella, con movimiento reducido). Si ya se ve entero, nada.
func _reveal(c: Control) -> void:
	var sc := _scroll_of(c)
	if sc == null or sc.get_child_count() == 0 or not is_inside_tree():
		return
	var content := sc.get_child(0) as Control
	var cr := c.get_global_rect()
	var sr := sc.get_global_rect()
	if content == null or (cr.position.y >= sr.position.y and cr.end.y <= sr.end.y):
		return
	var y := cr.position.y - content.get_global_rect().position.y - maxf((sr.size.y - cr.size.y) * 0.3, 8.0)
	var to := int(clampf(y, 0.0, maxf(content.size.y - sc.size.y, 0.0)))
	if reduce_motion:
		sc.scroll_vertical = to
		return
	create_tween().tween_property(sc, "scroll_vertical", to, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Lo que enseña el guiado, para los tests y la demo: el objetivo, el aviso, el mando resaltado y su borde.
func guide_info() -> Dictionary:
	return { "guide": _v.get("guide", {}), "view": guide_view.info() if guide_view != null else {},
		"frame": guide_frame.info() if guide_frame != null else {}, "control": _guide_ctrl, "highlight": _hl_id }


## El desplazamiento de la sección que contiene la página (el de su raíz), o null.
func _outer_scroll() -> ScrollContainer:
	var n := get_parent()
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


## Coloca la barra del animal: en escritorio, encima de la vista; en el teléfono, fija encima del desplazamiento de la sección,
## fuera de él (siempre visible aunque se baje por las tarjetas). Sin sección (una página suelta), encima de la vista.
func _place_status_bar() -> void:
	if status_bar == null:
		return
	var sc := _outer_scroll() if compact else null
	var host: Node = sc.get_parent() if sc != null else null
	if host is Container:
		_put_before(bar_slot, host, sc)
		_bar_fixed = true
	else:
		_put_before(bar_slot, left, view_box)
		_bar_fixed = false
	# en la sección del teléfono, con el margen de las tarjetas; dentro de la columna, a ras de la vista
	var m := BAR_MARGIN if _bar_fixed else 0
	bar_slot.add_theme_constant_override("margin_left", m)
	bar_slot.add_theme_constant_override("margin_right", m)
	bar_slot.add_theme_constant_override("margin_bottom", 4 if _bar_fixed else 0)
	status_bar.set_compact(compact)
	_sync_status_bar()


## Pone un nodo justo antes de otro, del mismo padre. (Node.move_child deja el nodo EN ese índice: si ya estaba antes del
## hermano, moverlo al índice del hermano lo dejaría detrás, y la barra bajaba al pie de la pantalla a la segunda colocación.)
static func _put_before(n: Node, parent: Node, sibling: Node) -> void:
	if n.get_parent() != parent:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		parent.add_child(n)
	var at := sibling.get_index()
	if n.get_index() < at:
		at -= 1
	parent.move_child(n, at)


## La barra se ve con la página activa y sin el laboratorio de la reforja delante.
func _sync_status_bar() -> void:
	if bar_slot != null:
		bar_slot.visible = active and not lab_open if _bar_fixed else not lab_open


## La barra, si está fuera de la página (fija en la sección), vuelve a ella: así se va con la página y no se queda suelta en la
## sección cuando la página sale del árbol.
func _home_status_bar() -> void:
	if status_bar == null or not is_instance_valid(status_bar) or not _bar_fixed:
		return
	_put_before(bar_slot, left, view_box)
	_bar_fixed = false


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


func _paint_events(v: Dictionary, force: bool) -> void:
	var key := var_to_str(v.events.map(func(e: Dictionary) -> String: return String(e.message) + String(e.time)))
	if key == _events_key and not force:
		return
	_events_key = key
	for ch in events_box.get_children():
		ch.queue_free()
	if (v.events as Array).is_empty():
		events_box.add_child(Ui.para("Aún no ha pasado nada.", "Note", "dim"))
		return
	for e: Dictionary in v.events:
		var l := Ui.para("%s · %s" % [String(e.time), String(e.message)], "Body")
		l.tooltip_text = State.readable_source(String(e.source))
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		events_box.add_child(l)
		events_box.add_child(Ui.para("Fuente: " + String(e.source_short), "Small", "dimmer"))


func _paint_report(v: Dictionary, force: bool) -> void:
	var fin := bool(v.finished)
	report_card.visible = fin
	if not fin:
		_report_key = ""
		return
	var sh: Dictionary = v.get("sheet", {})
	if sh.is_empty():
		return
	var key := var_to_str([sh.verdict, sh.grade_text, sh.criteria.size(), sh.advice.size(), sh.rows.size()])
	if key == _report_key and not force:
		return
	_report_key = key
	var hl: Dictionary = v.get("halted", {})
	report_halt.visible = not hl.is_empty()
	if not hl.is_empty():
		report_halt.text = "%s %s %s (Fuente: %s)" % [String(hl.title), String(hl.text), String(hl.todo), String(hl.source)]
	resume_button.visible = hl.is_empty()
	recapture_button.visible = bool(hl.get("recoverable", false))
	report_grade.text = String(sh.grade_text)
	report_verdict.text = "%s: %s" % [String(sh.get("claw_label", "")), String(sh.verdict_text)] if String(sh.get("claw_label", "")) != "" else String(sh.verdict_text)
	report_quick.text = String(v.texts.quick)
	for box: Container in [report_list, report_advice, sheet_grid]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	for h: String in ["", "Antes", "Después"]:
		sheet_grid.add_child(Ui.label(h, "Small", "dimmer"))
	for r: Dictionary in sh.rows:
		var lab := Ui.para(String(r.label), "Small", "dim")
		lab.custom_minimum_size.x = 90.0 if compact else 130.0
		lab.size_flags_horizontal = Control.SIZE_FILL
		if String(r.note) != "":
			lab.tooltip_text = String(r.note)
			lab.mouse_filter = Control.MOUSE_FILTER_STOP
		sheet_grid.add_child(lab)
		sheet_grid.add_child(Ui.para(String(r.before), "Body", "dim"))
		sheet_grid.add_child(Ui.para("→ " + String(r.after), "Body", String(TONE.get(String(r.tone), "text"))))
	for c: Dictionary in sh.criteria:
		report_list.add_child(Ui.para("✗ %s: %s" % [String(c.title), String(c.text)], "Body", "coral"))
		report_list.add_child(Ui.para("Fuente: " + String(c.source), "Small", "dimmer"))
	if (sh.criteria as Array).is_empty():
		report_list.add_child(Ui.para("✓ Nada que corregir.", "Body", "mint"))
	for a: Dictionary in sh.advice:
		report_advice.add_child(Ui.para("%s: %s" % [String(a.title), String(a.text)], "Body"))
		report_advice.add_child(Ui.para("Fuente: " + String(a.source), "Small", "dimmer"))
	var others: Array = sh.get("others", [])
	if not others.is_empty():
		report_advice.add_child(Ui.sub_label("Las demás garras trabajadas"))
		for o: Dictionary in others:
			report_advice.add_child(Ui.para("%s · %s: %s" % [String(o.label), String(o.grade_text), String(o.verdict_text)], "Body", "dim"))
	report_regrow.text = String(sh.regrow)
	var b: Dictionary = v.get("bench", {})
	bench_button.visible = not b.is_empty()
	bench_note.text = ("Al banco: %s" % String(b.note)) if String(b.get("note", "")) != "" else ""
	bench_note.visible = bench_note.text != ""


## El error que acaba de pasar, explicado (o nada).
func _paint_mistake(v: Dictionary) -> void:
	var m: Dictionary = v.get("mistake", {})
	var key := var_to_str(m)
	if key == _mistake_key:
		return
	_mistake_key = key
	mistake_box.visible = not m.is_empty()
	if m.is_empty():
		return
	mistake_what.text = "Qué ha pasado: %s (%s)" % [String(m.what), String(m.what_source)]
	mistake_fix.text = ("Cómo se arregla · %s: %s" % [String(m.fix_title), String(m.fix_text)]) if String(m.fix_title) != "" else ""
	mistake_fix.visible = mistake_fix.text != ""
	mistake_how.text = ("Cómo: " + String(m.control)) if String(m.control) != "" else ""
	mistake_how.visible = mistake_how.text != ""
	mistake_src.text = ("Fuente: " + String(m.fix_source)) if String(m.fix_source) != "" else ""


## «Valores y fuentes»: las filas de los ajustes de ahora (solo si se ven y han cambiado).
func _paint_values(v: Dictionary, force: bool) -> void:
	if v.is_empty() or not values_list.visible:
		return
	var s: Dictionary = v.setup
	var key := "%s|%s|%s|%s|%s|%s" % [String(s.animal), String(s.claw), String(s.inlay), String(v.snap.claw.humidity), str(s.overgrowth_days), String(v.get("paw", ""))]
	if key == _values_key and not force:
		return
	_values_key = key
	var setup_now := s.duplicate()
	setup_now["humidity"] = String(v.snap.claw.humidity)
	setup_now["paw"] = String(v.get("paw", ""))
	var rows: Array = State.values_for(setup_now)
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
		var tag := (" · " + String(r.quality_text)) if String(r.quality_text) != "" else ""
		(it[1] as Label).text = "%s: %s%s" % [String(r.label), String(r.value), tag]
		Ui.set_color(it[1], String(QUALITY_COLOR.get(String(r.quality), "text")))
		(it[2] as Label).text = "Fuente: %s" % String(r.source)


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


# ─────────────────────────────── La lente de la cámara (unidad 5t-B) ───────────────────────────────

## Debajo de la vista, en la página: lo que tapa la lente puesta (el índice de juego del motor) en una línea, su aviso,
## «Limpiar la lente» cuando hay manchas (el paño las quita; los rayones se quedan) y, en «Opciones», lo rayada que está y
## las dos opciones de accesibilidad.
func _build_lens() -> void:
	lens_box = PanelContainer.new()
	lens_box.name = "LenteDeLaCamara"
	lens_box.theme_type_variation = &"Sheet"
	lens_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := Ui.vbox(4)
	lens_box.add_child(col)
	# compacta: una línea (la lente y lo que tapa) y «Opciones»; lo demás, al abrirla (en el teléfono no tapa la vista)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	lens_label = Ui.para("", "Small", "text")
	lens_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(lens_label)
	lens_more_btn = Button.new()
	lens_more_btn.text = "Opciones"
	lens_more_btn.flat = true
	lens_more_btn.toggle_mode = true
	lens_more_btn.custom_minimum_size = Vector2(0.0, 28.0)
	lens_more_btn.toggled.connect(func(on: bool) -> void: lens_opts.visible = on)
	_a11y(lens_more_btn, "Opciones de la lente", "Abre lo rayada que está la lente y las opciones de accesibilidad (quitar el efecto de la lente y el temblor de la cámara).")
	head.add_child(lens_more_btn)
	lens_warn = Ui.para("", "Small", "gold")
	lens_warn.custom_minimum_size.x = 150.0
	lens_warn.visible = false
	col.add_child(lens_warn)
	# la probabilidad de que se revuelva en la próxima tirada (view().animal.attackChance, índice de juego), discreta y solo
	# cuando no es cero
	lens_risk = Ui.para("", "Small", "dim")
	lens_risk.autowrap_mode = TextServer.AUTOWRAP_OFF
	lens_risk.visible = false
	col.add_child(lens_risk)
	lens_clean_btn = Button.new()
	lens_clean_btn.text = "Limpiar la lente"
	lens_clean_btn.custom_minimum_size = Vector2(0.0, 32.0)
	lens_clean_btn.pressed.connect(clean_lens)
	lens_clean_btn.visible = false
	_a11y(lens_clean_btn, "Limpiar la lente", "Un paño quita las manchas de grasa y polvo de la lente; los rayones se quedan (una lente rayada se cambia por otra).")
	col.add_child(lens_clean_btn)
	lens_opts = Ui.vbox(4)
	lens_opts.visible = false
	col.add_child(lens_opts)
	lens_detail = Ui.para("", "Small", "dim")
	lens_detail.custom_minimum_size.x = 150.0
	lens_opts.add_child(lens_detail)
	col = lens_opts
	lens_fx_check = CheckBox.new()
	lens_fx_check.text = "Efecto de la lente"
	lens_fx_check.button_pressed = true
	lens_fx_check.toggled.connect(func(on: bool) -> void: _set_reaction_option("lens_fx", on))
	_a11y(lens_fx_check, "Efecto de la lente", "Quita o pone el dibujo de los rayones, la grieta y las manchas sobre la vista (accesibilidad). El daño de la lente sigue contando.")
	col.add_child(lens_fx_check)
	lens_shake_check = CheckBox.new()
	lens_shake_check.text = "Temblor de cámara"
	lens_shake_check.button_pressed = true
	lens_shake_check.toggled.connect(func(on: bool) -> void: _set_reaction_option("shake", on))
	_a11y(lens_shake_check, "Temblor de cámara", "Quita o pone el temblor de la cámara cuando el animal golpea la lente (accesibilidad).")
	col.add_child(lens_shake_check)
	# debajo de la vista, en la página (antes iba encima, abajo a la izquierda, y tapaba el final del medidor «Forma de la
	# garra» y, en el teléfono, casi todo él)
	lens_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(lens_box)
	left.move_child(lens_box, view_box.get_index() + 1)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.name = "SonidoDeLaReaccion%d" % i
		p.bus = &"Lab"
		add_child(p)
		_react_sfx.append(p)


## Lo que dice la lente (view().lens del estado: ClawCareLens.view()).
func _paint_lens(v: Dictionary) -> void:
	if lens_box == null:
		return
	var lv: Dictionary = v.get("lens", {})
	if lv.is_empty():
		lens_box.visible = false
		return
	lens_box.visible = true
	# el panel del tema, con menos relleno (sobre la vista ocupa lo justo)
	if not lens_box.has_theme_stylebox_override("panel") and lens_box.is_inside_tree():
		var sb := lens_box.get_theme_stylebox("panel").duplicate() as StyleBox
		if sb != null:
			sb.content_margin_left = 8.0
			sb.content_margin_right = 6.0
			sb.content_margin_top = 4.0
			sb.content_margin_bottom = 4.0
			lens_box.add_theme_stylebox_override("panel", sb)
	var ob := float(lv.get("obscuration", 0.0))
	var n := (lv.get("scratches", []) as Array).size()
	var m := (lv.get("smudges", []) as Array).size()
	# en el teléfono (o una ventana estrecha), lo justo para no tapar la esquina de la vista: «Lente 0 %» y «Más»
	var narrow := OS.has_feature("mobile") or (get_viewport_rect().size.x < WIDE if is_inside_tree() else compact)
	lens_label.text = ("Lente %s %%" if narrow else "Lente · tapa %s %%") % Js.to_fixed(ob * 100.0, 0)
	lens_more_btn.text = "Más" if narrow else "Opciones"
	lens_detail.text = "%s · %s · tapa un %s %% de la vista (índice de juego)" % [String(lv.get("lensName", "Lente")),
		"sin rayones" if n == 0 else ("%d %s" % [n, "rayón" if n == 1 else "rayones"]), Js.to_fixed(ob * 100.0, 0)]
	if m > 0:
		lens_detail.text += " · %d %s" % [m, "mancha" if m == 1 else "manchas"]
	var w := String(lv.get("warning", ""))
	lens_warn.text = w
	lens_warn.visible = w != ""
	# el paño, a mano solo cuando hay manchas que quitar
	lens_clean_btn.visible = m > 0
	var an: Dictionary = v.get("animal", {})
	var ch := float(an.get("attackChance", 0.0))
	lens_risk.visible = ch > 0.0
	if ch > 0.0:
		lens_risk.text = "Probabilidad de que se revuelva: %s %% (%s)" % [Js.to_fixed(ch * 100.0, 0), String(an.get("attackChanceQuality", "juego"))]


## «Limpiar la lente»: el paño pasa por la vista y el estado quita las manchas (lens_clean).
func clean_lens() -> void:
	_post("lens_clean")
	if scene != null:
		var r: Node = scene.call("reaction")
		(r.get("lens") as Node).call("clean")
	# 5tc · desde la reforja: el paño pasa también por su vista (es la misma lente)
	if lab_open and lab_lens != null:
		lab_lens.clean()
	_one_shot_react("lente-pano", 0.7, 1.0)


## Las opciones de la reacción: { lens_fx (el efecto de la lente), shake (el temblor de la cámara) }.
func set_reaction_options(opts: Dictionary) -> void:
	reaction_options.merge(opts, true)
	if lens_fx_check != null:
		lens_fx_check.set_pressed_no_signal(bool(reaction_options.lens_fx))
		lens_shake_check.set_pressed_no_signal(bool(reaction_options.shake))
	if scene != null:
		var r: Node = scene.call("reaction")
		r.set("shake_enabled", bool(reaction_options.shake))
		(r.get("lens") as Node).call("set_effect_enabled", bool(reaction_options.lens_fx))
	if lab_lens != null:
		lab_lens.set_effect_enabled(bool(reaction_options.lens_fx))


# ─────────────────────────────── 5tc · la lente en la reforja ───────────────────────────────

## Al abrir la reforja (on) o al volver (off): la pastilla de la lente («Lente · tapa N %», el paño y las opciones) va debajo
## de la vista que se ve, la «Tienda de lentes» va junto al interruptor de la página que se ve (abre la misma hoja de la tienda, en
## su propia capa), y la reforja enseña la misma lente sobre su vista 3D (una LensLayer en su SubViewport, creada una vez:
## las mismas formas y el mismo sombreador; el mapa de daños solo se rehace cuando cambia).
func _lens_to_lab(on: bool) -> void:
	if lab_page == null or lens_box == null:
		return
	var row: Control = lab_page.get("mode_row") if on else mode_row
	if shop_button != null and row != null and shop_button.get_parent() != row:
		shop_button.get_parent().remove_child(shop_button)
		row.add_child(shop_button)
		if not on and lab_switch != null and lab_switch.get_parent() == row:
			row.move_child(shop_button, lab_switch.get_index() + 1)
	# la pastilla, debajo de la vista que se ve, en su columna (como en la clínica: no tapa la vista)
	var under: Control = lab_page.get("view_box") if on else view_box
	var col: Control = under.get_parent() if under != null else null
	if col != null and lens_box.get_parent() != col:
		lens_box.get_parent().remove_child(lens_box)
		col.add_child(lens_box)
	if col != null:
		col.move_child(lens_box, under.get_index() + 1)
	if not on:
		return
	if lab_lens == null:
		var lv: Variant = lab_page.get("view3d")
		if lv == null:
			return
		lab_lens = LensLayer.new()
		lab_lens.name = "LenteDeLaCamara"
		(lv.get("viewport") as SubViewport).add_child(lab_lens)
	var mobile := quality == "movil" or (quality == "" and (OS.has_feature("mobile") or compact))
	lab_lens.set_simple(mobile)
	lab_lens.set_effect_enabled(bool(reaction_options.lens_fx))
	_lab_lens_serial = -2
	_lab_lens_step(0.0)


## Con la reforja abierta: la lente guardada del estado de la cetrería (el paño o la tienda la cambian), su pastilla y el
## barrido del paño.
func _lab_lens_step(dt: float) -> void:
	if lab_lens == null or runner == null:
		return
	lab_lens.advance(dt)
	var v := runner.latest()
	var lv: Dictionary = v.get("lens", {})
	# la lente cambiada en la tienda es otra (su serial empieza de nuevo): la clave lleva también la lente y sus marcas
	var ser := hash([int(lv.get("serial", -1)), String(lv.get("lens", "")), (lv.get("scratches", []) as Array).size(), (lv.get("smudges", []) as Array).size()])
	if ser != _lab_lens_serial:
		_lab_lens_serial = ser
		if not lv.is_empty():
			lab_lens.apply_damage(lv, true)
		_paint_lens(v)


func _set_reaction_option(key: String, on: bool) -> void:
	set_reaction_options({ key: on })
	reaction_options_changed.emit(reaction_options.duplicate())


func _on_reaction_sfx(id: String, volume: float, pitch: float) -> void:
	_one_shot_react(id, volume, pitch)


func _one_shot_react(id: String, volume: float, pitch: float) -> void:
	if _react_sfx.is_empty() or not (_react_sfx[0] as Node).is_inside_tree():
		return
	var path := Sfx.path_of(id)
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _react_sfx[_react_i % _react_sfx.size()]
	_react_i += 1
	p.stream = load(path)
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = linear_to_db(clampf(volume, 0.01, 1.0) * Sfx.gain(id))  # con el ajuste de la mezcla
	p.play()


# ─────────────────────────────── Sonido continuo ───────────────────────────────

## El zumbido del torno o de la amoladora encendidos (su bucle, con el tono de sus rpm, que baja al apretar), su arranque
## y su parada (de una vez, con el tono de la velocidad; el bucle entra al acabar el arranque) y el roce de la lima o del
## tambor mientras trabaja: los sonidos horneados de SfxCare, con lo que pide el estado (sound_view), por el bus «Lab».
## Fuera de la página, en silencio. dt: lo que ha pasado desde el último paso (s).
func _update_loops(dt := 0.0) -> void:
	var snd: Dictionary = _v.get("sound", {})
	var motor := active and bool(snd.get("motor", false))
	var mid := String(snd.get("motor_id", SfxCare.MOTOR))
	var spin_pitch := float(snd.get("motor_rpm", SfxCare.SPIN_BASE_RPM)) / SfxCare.SPIN_BASE_RPM
	if motor and not _motor_was:
		_one_shot(SfxCare.SPIN_UP, spin_pitch, 0.6)
		_spin_left = SfxCare.SPIN_UP_S / maxf(spin_pitch, 0.25) * 0.85
	elif not motor and _motor_was and active:
		_one_shot(SfxCare.SPIN_DOWN, spin_pitch, 0.6)
	_motor_was = motor
	_spin_left = maxf(_spin_left - dt, 0.0)
	if mid != _motor_id and _torno != null:
		# otra herramienta giratoria: su propio bucle
		_motor_id = mid
		_torno.stop()
		_torno.stream = null
	_loop(_torno, mid, motor and _spin_left <= 0.0, float(snd.get("motor_pitch", 1.0)), 0.5)
	_loop(_rasp, SfxCare.RASP, active and bool(snd.get("rasp", false)), float(snd.get("rasp_pitch", 1.0)), 0.55)


## Toca de una vez un sonido de SfxCare (el arranque o la parada) con su tono.
func _one_shot(id: String, pitch: float, volume: float) -> void:
	if _spin == null or not _spin.is_inside_tree():
		return
	var path := Sfx.path_of(id)
	if not ResourceLoader.exists(path):
		return
	_spin.stream = load(path)
	_spin.pitch_scale = clampf(pitch, 0.25, 4.0)
	_spin.volume_db = linear_to_db(volume * Sfx.gain(id))  # con el ajuste de la mezcla
	_spin.play()


func _loop(p: AudioStreamPlayer, id: String, on: bool, pitch: float, volume: float) -> void:
	if p == null:
		return
	if not on:
		if p.playing:
			p.stop()
		return
	if p.stream == null and ResourceLoader.exists(Sfx.path_of(id)):
		p.stream = load(Sfx.path_of(id))
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = linear_to_db(maxf(volume * Sfx.gain(id), 0.0001))  # con el ajuste de la mezcla
	if not p.playing and p.stream != null and p.is_inside_tree():
		p.play()


## ¿Qué bucles suenan? (para los tests: [motor, roce]).
func loops_playing() -> Array:
	return [_torno != null and _torno.playing, _rasp != null and _rasp.playing]


func _stop_loops() -> void:
	for p: AudioStreamPlayer in [_torno, _rasp, _spin]:
		if p != null and p.playing:
			p.stop()
	_motor_was = false


# ─────────────────────────────── Teclado ───────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


## Las teclas de la página (A/D, W/S, 1-5, E, Q, P, G, T, N, Espacio, H, R, V, Esc). Devuelve si la ha usado.
func handle_key(k: InputEventKey) -> bool:
	if lab_open:
		return bool(lab_page.call("handle_key", k))
	if k == null or k.is_command_or_control_pressed() or k.alt_pressed:
		return false
	# la pieza de la reforja (unidad 5o): K apreta y sujeta mientras se mantiene (al soltarla, la suelta)
	var bv: Dictionary = _v.get("bond", {})
	if k.keycode == KEY_K and not bv.is_empty():
		if not k.echo:
			_post("bond_hold", [k.pressed, -1.0])
		return true
	if not k.pressed:
		return false
	var held := not bv.is_empty() and bool(bv.get("held", false))
	match k.keycode:
		KEY_A:
			if held:
				_post("bond_turn", [-CareBondCard.TURN_DEG])
			else:
				_post("nudge_angle", [-1.0])
		KEY_D:
			if held:
				_post("bond_turn", [CareBondCard.TURN_DEG])
			else:
				_post("nudge_angle", [1.0])
		KEY_L:
			if not k.echo and not bv.is_empty():
				_post("bond_lamp_on")
		KEY_W:
			_post("nudge_force", [1])
		KEY_S:
			_post("nudge_force", [-1])
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if k.echo:
				return true
			_post("pick", [State.tool_for_key(k.keycode - KEY_0)])
		KEY_E:
			if not k.echo:
				_post("toggle_rotary")
		KEY_Q:
			if not k.echo:
				_post("cycle_rpm")
		KEY_P:
			if not k.echo:
				_post("cycle_paw")
		KEY_G:
			if not k.echo:
				_post("cycle_digit")
		KEY_T:
			if not k.echo:
				_post("probe_tip")
		KEY_N:
			if not k.echo:
				_post("renew_tool")
		KEY_SPACE:
			if not k.echo:
				_post("toggle_pause")
		KEY_H:
			if not k.echo:
				toggle_help()
		KEY_R:
			if not k.echo:
				_post("restart")
		KEY_V:
			if not k.echo:
				cycle_view()
		KEY_F:
			# la silueta fantasma de la forma natural sana, para comparar (unidad 5h)
			if not k.echo and scene != null:
				scene.call("toggle_ghost")
		KEY_ESCAPE:
			_post("drop")
		_:
			return false
	return true


func headline() -> String:
	return "¿Afilada como una daga?"


# ─────────────────────────────── Laboratorio experimental (reforja) ───────────────────────────────

## Enchufa el «Laboratorio experimental (reforja)» (unidad 5f; petición 35: la rama experimental del trabajo
## veterinario): el interruptor «Trabajo veterinario | Laboratorio experimental (reforja)» sobre la vista, su entrada en
## el sitio de la reforja (plug_reforge) y «Reforjar con material» en el aviso de la garra rota. La página se crea la
## primera vez que se abre: si no se usa, no cuesta nada.
func plug_reforge_lab() -> void:
	if lab_switch != null:
		return
	lab_switch = PillChoice.new([
		{ "id": "cetreria", "label": "Trabajo veterinario", "title": "Limar, cortar y curar las garras del animal" },
		{ "id": "reforja", "label": "Laboratorio experimental (reforja)", "title": "Una funda o una prótesis de otro material para la garra, hecha en el horno del taller" },
	], "cetreria", "Cetrería")
	lab_switch.selected.connect(func(id: String) -> void:
		lab_switch.set_value("cetreria")
		if id == "reforja":
			open_lab())
	# que se estire en la fila: con el mínimo de su píldora más ancha, las dos opciones salían una debajo de otra aunque
	# cupieran en una línea
	lab_switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(lab_switch)
	mode_row.move_child(lab_switch, 0)
	var panel := Ui.vbox(6)
	panel.add_child(Ui.para("Una funda o una prótesis de otro material (zafiro, diamante, acero, oro…) hecha en el horno del taller y pegada en frío, como una corona dental; después se lima aquí, con una herramienta más dura que ella.", "Note", "dim"))
	lab_entry = Button.new()
	lab_entry.theme_type_variation = &"PillGold"
	lab_entry.pressed.connect(func() -> void: open_lab())
	_a11y(lab_entry, "Laboratorio experimental (reforja)", "Abre el laboratorio experimental con esta garra; si está rota, para hacerle una prótesis.")
	panel.add_child(lab_entry)
	plug_reforge(panel)
	reforge_button = Button.new()
	reforge_button.text = "Reforjar con material"
	reforge_button.theme_type_variation = &"PillGold"
	reforge_button.pressed.connect(func() -> void: open_lab())
	_a11y(reforge_button, "Reforjar con material", "La garra rota va al laboratorio experimental: se le hace una prótesis de otro material y vuelve aquí para darle forma con una lima o una amoladora más dura que ella.")
	var col := mistake_box.get_child(0) as VBoxContainer
	col.add_child(reforge_button)
	col.move_child(reforge_button, col.get_child_count() - 2)
	_paint_lab(_v)


## ¿La garra de ahora está rota y sin reconstruir?
static func _claw_broken(v: Dictionary) -> bool:
	var dmg: Dictionary = v.get("snap", {}).get("damage", {})
	return bool(dmg.get("broken", false)) and not bool(dmg.get("repaired", false))


## «Reforjar con material» con la garra rota; si no, la entrada de siempre.
func _paint_lab(v: Dictionary) -> void:
	if lab_entry == null:
		return
	var broken := _claw_broken(v)
	reforge_button.visible = broken
	lab_entry.text = "Reforjar con material" if broken else "Llevar esta garra al laboratorio"


## La garra de ahora para el laboratorio: { animal, claw, paw, digit, humidity, broken, claw_label } y, si está rota, el
## perfil que le queda (solo para dibujarla) y from_care: los ajustes de su ClawCare con stump_mm, lo que queda de ella
## (lo mismo que ClawCareState.reforge_request, desde la vista: el estado está en su hilo), para que vuelva como un bloque
## en bruto (ClawForge.care_setup(from_care)).
func _lab_setup() -> Dictionary:
	var s: Dictionary = _v.get("setup", {})
	var sn: Dictionary = _v.get("snap", {})
	var broken := _claw_broken(_v)
	var p := { "animal": String(s.get("animal", "rapaz")), "claw": String(s.get("claw", "")), "paw": String(_v.get("paw", "")),
		"digit": String(_v.get("digit", "")), "humidity": String(sn.get("claw", {}).get("humidity", "natural")), "broken": broken,
		"claw_label": String(_v.get("claw_label", "")) }
	if broken:
		var prof: Dictionary = sn.get("profile", {})
		p["profile"] = { "s": prof.get("s", PackedFloat64Array()), "r": prof.get("r", PackedFloat64Array()) }
		var fc := s.duplicate(true)
		fc["paw"] = String(_v.get("paw", ""))
		fc["digit"] = String(_v.get("digit", ""))
		fc["stump_mm"] = float(sn.get("claw", {}).get("lengthMm", 0.0))
		p["from_care"] = fc
	return p


## Abre el laboratorio con la garra de ahora (o con la que se le pase). La primera vez crea su página.
func open_lab(p: Dictionary = {}) -> void:
	if lab_switch == null:
		return
	lab_open = true
	left.visible = false
	right.visible = false
	right_scroll.visible = false
	if lab_page == null:
		lab_page = (load(FORGE_PAGE) as GDScript).new() as Control
		lab_page.set("threaded", threaded)
		lab_page.set("quality", quality)
		add_child(lab_page)
		lab_page.call("setup", play_sfx)
		lab_page.call("set_intro_seen", lab_intro_seen)
		lab_page.connect("back_requested", close_lab)
		lab_page.connect("to_care", receive_forged)
		lab_page.connect("to_bench", func(b: Dictionary) -> void: try_on_bench.emit(b))
		lab_page.connect("intro_done", func() -> void:
			lab_intro_seen = true
			lab_intro_done.emit())
	lab_page.call("open_with", p if not p.is_empty() else _lab_setup())
	lab_page.visible = true
	_lens_to_lab(true)
	_sync_status_bar()
	lab_page.call("set_fit_height", fit_height)
	set_active(active)
	lab_page.call("refresh")


## Vuelve al trabajo veterinario (el interruptor del laboratorio).
func close_lab() -> void:
	if not lab_open:
		return
	lab_page.call("set_active", false)
	lab_open = false
	lab_page.visible = false
	_lens_to_lab(false)
	left.visible = true
	right.visible = true
	_layout()
	_sync_status_bar()
	set_active(active)
	refresh()


## La garra hecha en el laboratorio vuelve a la cetrería («Pasar a la cetrería»: ClawForge.care_setup, con la pata y la
## garra de las que vino). La garra rota vuelve como un bloque en bruto pegado al muñón, en su pata y su dedo
## (ClawCareState.reforge_with, de la 5g: si aún sangra, el aviso dice que primero hay que parar la sangre); la funda
## entera, como un ensayo nuevo con ese material, en esa pata y esa garra, para limarla y pulirla aquí.
func receive_forged(setup_in: Dictionary) -> void:
	close_lab()
	# la pieza llega sin pegar (unidad 5o, petición 43): queda en la bandeja y la coloca el usuario
	_post("receive_piece", [setup_in.duplicate(true)])
	refresh()


# ─────────────────────────────── 5u · el progreso del veterinario ───────────────────────────────

## El botón de la pausa: se ve con el animal estresado (de «inquieto» arriba) o en la pausa, con lo que tiene de estrés.
func _paint_rest(an: Dictionary) -> void:
	if rest_button == null:
		return
	var resting := bool(an.get("resting", false))
	var st := float(an.get("stress", 0.0))
	var show := bool(an.get("handled", false)) and (resting or st >= float(CareData.ANIMAL_RISK["restless"]) or bool((an.get("reaction", {}) as Dictionary).get("warning", false)))
	var key := "%s|%s|%s" % [str(show), str(resting), Js.to_fixed(st * 100.0, 0)]
	if key == _rest_key:
		return
	_rest_key = key
	rest_button.visible = show
	rest_button.text = ("Seguir trabajando (estrés %s %%)" % Js.to_fixed(st * 100.0, 0)) if resting else "Pausa para calmarlo"
	rest_button.theme_type_variation = &"Pill" if resting else &"PillGold"


## La tarjeta «Tu consulta de veterinario» (unidad 5u; petición 62): el nivel, la experiencia, los créditos del juego, la
## lente, los encargos y la tienda. Va justo después del informe: al terminar una consulta, el encargo se comprueba con él.
func _build_progress() -> void:
	progress_card = CareProgressCard.new(_progress_op)
	progress_card.compact = compact
	right.add_child(progress_card)
	mode_row = Ui.flow(8, 6)
	mode_row.name = "Modos"
	left.add_child(mode_row)
	left.move_child(mode_row, 0)
	shop_button = Pill.new("Tienda de lentes", "PillGold", false)
	shop_button.name = "TiendaDeLentes"
	shop_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_button.pressed.connect(func() -> void: progress_card.set_open("shop", true))
	shop_button.accessibility_name = "Tienda de lentes"
	shop_button.accessibility_description = "Las cuatro lentes de la cámara, el nivel que pide cada una y su precio en créditos del juego; y empezar el juego de nuevo."
	shop_button.tooltip_text = shop_button.accessibility_description
	mode_row.add_child(shop_button)
	rest_button = Pill.new("Pausa para calmarlo", "Pill", false)
	rest_button.name = "PausaParaCalmarlo"
	rest_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rest_button.visible = false
	rest_button.pressed.connect(func() -> void:
		var an: Dictionary = _v.get("animal", {})
		_post("rest", [not bool(an.get("resting", false))]))
	_a11y(rest_button, "Pausa para calmarlo", "Sueltas la herramienta y apartas las manos: mientras descansa no se revuelve y su estrés baja (más deprisa encapuchada y en penumbra, o sedado).")
	mode_row.add_child(rest_button)
	_progress_saved = progress.serial
	_progress_paint(true)


## Recupera el progreso de path (user://cetreria.cfg en el programa; la sección la pone si guarda los ajustes) y desde ahí
## lo guarda en cada cambio. Un archivo roto o de otra versión no rompe nada: se avisa en la tarjeta.
func set_progress_path(path: String) -> void:
	progress_path = path
	progress.load_file(path)
	_progress_saved = progress.serial
	_send_lens()
	_progress_paint(true)


## Después de cada vista: la consulta que termina comprueba el encargo en curso de la cetrería (o la práctica libre) con su
## informe, una vez por consulta (otra vez si se sigue con la garra y se vuelve a terminar); la pieza del laboratorio, el de la
## reforja; y el daño de la lente que da la cetrería se guarda. Después, se guarda y se pinta si algo ha cambiado.
func _progress_check(v: Dictionary) -> void:
	var ses := String((v.get("setup", {}) as Dictionary).get("seed", ""))
	var fin := bool(v.get("finished", false))
	if ses != _care_session or not fin:
		_care_session = ses
		_care_checked = false
	if fin and not _care_checked:
		_care_checked = true
		progress.on_care_finished(VetProgress.care_summary(v))
	if lab_page != null:
		var fv: Dictionary = (lab_page.get("runner") as RefCounted).call("latest")
		var fser := int(fv.get("serial", -1))
		if fser != _forge_serial:
			_forge_serial = fser
			var aj := VetProgress.job(progress.active_job)
			var fsum := VetProgress.forge_summary(fv)
			if not aj.is_empty() and String(aj.kind) == "reforja" and (String(fsum.verdict) == "bien" or fsum.weld != null):
				progress.on_forge_finished(fsum)
	# lo peligroso que es el animal de la mesa para la lente, cuando cambia de animal o de garra
	var an: Dictionary = v.get("animal", {})
	var ld: Dictionary = v.get("lens_danger", {})
	if not ld.is_empty():
		# con las garras de ahora (su material y sus puntas: la cetrería lo da en view().lens_danger)
		var lkey := String(ld.get("text", ""))
		if lkey != _danger_key:
			_danger_key = lkey
			_danger = ld
			_progress_painted = -1
	else:
		var dkey := "%s/%s" % [String(an.get("animal", "")), String(an.get("claw", ""))]
		if String(an.get("animal", "")) != "" and dkey != _danger_key:
			_danger_key = dkey
			if not _danger_cache.has(dkey):
				_danger_cache[dkey] = Reaction.danger_of(String(an.animal), String(an.get("claw", "")))
			_danger = _danger_cache[dkey]
			_progress_painted = -1
	# el daño de la lente puesta, tal como lo da la cetrería (5t-A: view().lens, la de ClawCareLens.view()), cuando cambia
	var ln: Dictionary = v.get("lens", {})
	if not ln.is_empty() and String(ln.get("lens", "")) == progress.lens_on and int(ln.get("serial", -1)) != _lens_serial:
		_lens_serial = int(ln.get("serial", -1))
		progress.set_lens_damage(progress.lens_on, _lens_dict(ln))
	_progress_save()
	_progress_paint(false)
	_paint_minigame(v)


## Lo que hace el usuario en la tarjeta: aceptar o dejar un encargo, traer al animal, comprar o ponerse una lente.
func _progress_op(op: String, args: Array = []) -> void:
	progress.notice = ""
	var id := String(args[0]) if not args.is_empty() else ""
	match op:
		"accept":
			var r := progress.accept(id)
			if not bool(r.ok):
				progress.notice = String(r.text)
			else:
				# (5v) los encargos con tutorial, con minijuego o con el animal que llega roto o con otra punta: a la mesa ya
				var ja := VetProgress.job(id)
				if String(ja.get("kind", "")) == "cetreria" and (ja.has("tutorial") or ja.has("minigame") or ja.has("broken_start") or ja.has("tip_start")):
					_bring_job(ja)
		"abandon":
			progress.abandon()
		"bring":
			var j := VetProgress.job(id)
			if not j.is_empty() and String(j.animal) != "":
				_bring_job(j)
		"buy":
			progress.buy_lens(id)
			_send_lens()
		"wear":
			var w := progress.wear_lens(id)
			progress.notice = String(w.text)
			_send_lens()
		"restart":
			progress.restart_game()
			_send_lens()
	progress.serial += 1
	_progress_save()
	_progress_paint(true)


## Trae a la mesa el animal de un encargo: su especie y su garra, la punta con la que llega y la garra rota de serie (5v; sin
## ellas, sana y con la punta natural) y, si el encargo es de iniciación, su tutorial abierto en su proceso.
func _bring_job(j: Dictionary) -> void:
	var cfg := { "animal": String(j.animal), "sedation": "libre", "humidity": "natural", "inlay": "none",
		"tip_start": String(j.get("tip_start", "natural")), "broken_start": (j.get("broken_start", {}) as Dictionary).duplicate() }
	if String(j.claw) != "":
		cfg["claw"] = String(j.claw)
	_post("configure", [cfg])
	if String(j.digit) != "" and (j.get("broken_start", {}) as Dictionary).is_empty():
		_post("set_digit", [String(j.digit)])
	if String(j.get("tutorial", "")) != "":
		_post("set_tutorial", [true])
		_post("tutorial_goto", [String(j.tutorial)])


## (5v) El minijuego del encargo en curso y, si la garra se ha roto durante la operación, el aviso de que pasa a «repararla»:
## en cada vista de la consulta (solo se repinta si cambia).
func _paint_minigame(v: Dictionary) -> void:
	if progress_card == null:
		return
	var j := VetProgress.job(progress.active_job)
	var m := {}
	var rt := ""
	if not j.is_empty() and String(j.get("kind", "")) == "cetreria" and not v.is_empty():
		m = VetMinigames.view(j, v)
		if VetProgress.broke_here(j, VetMinigames.summary(v)):
			rt = "La garra se ha roto durante la operación: el encargo pasa a «repararla» (parar la sangre, desinfectar y reconstruirla o colocarle la pieza de la reforja) y se cobra la mitad."
	var key := var_to_str([m, rt]).hash()
	if key == _mini_key:
		return
	_mini_key = key
	progress_card.paint_minigame(m, rt)


## La lente puesta y su daño, a la cetrería (5t-A), si ya sabe de lentes.
func _send_lens() -> void:
	if runner == null:
		return
	var d := progress.lens_damage(progress.lens_on)
	_lens_serial = -1
	if d.is_empty():
		_post("lens_mount", [progress.lens_on])
	else:
		d["lens"] = progress.lens_on
		_post("lens_load", [d])


## El daño de la lente para guardarlo: el to_dict() de ClawCareLens (los trazos como pares) con su índice obscuration.
static func _lens_dict(lv: Dictionary) -> Dictionary:
	var l := Lens.new()
	l.from_dict({ "lens": String(lv.get("lens", "plastico")), "scratches": lv.get("scratches", []), "smudges": lv.get("smudges", []) })
	var d := l.to_dict()
	d["obscuration"] = l.obscuration()
	return d


func _progress_save() -> void:
	if progress.serial == _progress_saved:
		return
	_progress_saved = progress.serial
	if progress_path != "":
		progress.save_to(progress_path)


## ¿Tiene la reforja la mesa de soldar (5r)? (El encargo de soldar sale solo entonces.)
func _has_weld() -> bool:
	if _weld_known < 0:
		var names: Array = (load("res://core/lab/claw_forge.gd") as GDScript).get_script_method_list().map(func(m: Dictionary) -> String: return String(m.name))
		_weld_known = 1 if names.has("weld_setup") else 0
	return _weld_known == 1


## El nombre del animal de la mesa para los textos de la tienda («el águila», «el tigre»), de la ficha de su garra.
static func _animal_name(animal: String, claw: String) -> String:
	if animal == "":
		return ""
	var e := CareData.claw_entry(claw if claw != "" else String((CareData.ANIMALS.get(animal, CareData.ANIMALS.rapaz) as Dictionary).claw))
	return String(e.get("name", animal)).to_lower()


## La ficha de una lente de la cetrería (5t-A): lo que es, su dureza y qué la raya, con su fuente: { text, source }.
func _lens_info(id: String) -> Dictionary:
	if not Reaction.LENSES.has(id):
		return {}
	var L := Reaction.lens(id)
	# los nombres en medio de la frase, solo con la inicial en minúscula (como lower_first de la reforja: «circonita (CZ)»)
	var by: Array = Reaction.scratched_by(id).map(func(e: Dictionary) -> String: return String(e.name).substr(0, 1).to_lower() + String(e.name).substr(1))
	var who := ("La rayan: %s." % ", ".join(by)) if not by.is_empty() else "No la raya ninguna garra del laboratorio."
	if by.has("queratina"):
		# la ficha de la lente ya lo dice («la raya cualquier garra, también la de queratina»): una vez
		who = "" if String(L.fact).contains("queratina") else "La rayan todas las garras, también las de queratina."
	return { "text": ("%s %s" % [String(L.fact), who]).strip_edges(), "source": State.short_source(String(L.data.hv.source)),
		"short": "Dureza ~%s HV · %s" % [Js.to_fixed(float(L.hv), 0), "la raya cualquier garra" if by.has("queratina") else ("la rayan %s garras del laboratorio" % Js.to_fixed(float(by.size()), 0) if not by.is_empty() else "no la raya ninguna garra")] }


## Pinta la tarjeta con la vista del progreso (solo si ha cambiado, salvo force).
func _progress_paint(force: bool) -> void:
	if progress_card == null or (not force and progress.serial == _progress_painted):
		return
	_progress_painted = progress.serial
	progress_card.compact = compact
	var jobs := progress.jobs_view(_has_weld())
	var active := {}
	for e: Dictionary in jobs:
		if String(e.state) == "en_curso":
			active = e
	var infos := {}
	for id: String in VetProgress.LENS_IDS:
		infos[id] = _lens_info(id)
	progress_card.paint({
		"level": progress.level_view(), "credits_text": progress.credits_text(), "lens": progress.lens_view(),
		"lens_info": infos.get(progress.lens_on, {}), "active": active, "result": progress.last_result, "notice": progress.notice,
		"jobs": jobs, "shop": progress.shop_view(), "lens_infos": infos, "blind": progress.blind_view(),
		"danger": _danger, "animal_name": _animal_name(String(_danger.get("animal", "")), String(_danger.get("claw", ""))),
	})
	# el botón de la tienda: los créditos, o en rojo si la lente ya no deja ver (y la tienda se abre sola al pasar, una vez)
	var blind := progress.blind()
	shop_button.text = ("Lente rayada: cámbiala o empieza de nuevo" if blind else ("Tienda de lentes · %s" % progress.credits_text() if progress.credits > 0 else "Tienda de lentes · sin créditos"))
	Ui.set_color(shop_button, "coral" if blind else "gold")
	# (la hoja va en su propia capa, que no se esconde con la página: solo se abre sola si la página se ve)
	if blind and not _blind_was and is_visible_in_tree():
		progress_card.set_open("shop", true)
		_blind_was = true
	elif not blind:
		_blind_was = false


# ─────────────────────────────── El afilado que se ve (unidad 5s) ───────────────────────────────

## Sobre la vista, abajo a la izquierda: la lupa de la punta y, debajo, el medidor (siempre visible mientras se trabaja).
## Debajo de la vista 3D (sin taparla: la garra, el indicador de la forma y los mandos están encima): la lupa de la punta y el
## medidor, uno al lado del otro (en el teléfono pasan a la línea siguiente si no caben). Siempre a la vista mientras se trabaja.
func _build_tip_overlay() -> void:
	var flow := Ui.flow(6, 6)
	flow.name = "PuntaBajoLaVista"
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_meter = CareTipMeter.new()
	flow.add_child(tip_meter)
	tip_lupa = CareTipLupa.new()
	flow.add_child(tip_lupa)
	tip_box = Ui.vbox(0)
	tip_box.add_child(flow)
	left.add_child(tip_box)


## En la tarjeta «Herramientas y mano»: para qué sirve cada una en una línea, las que afilan marcadas, y el aviso para afilar.
func _build_purposes(c: Card) -> void:
	c.body.add_child(Ui.sub_label("Para qué sirve cada una"))
	tools_purpose = Ui.vbox(1)
	tools_purpose.name = "ParaQueSirve"
	var cures: Array = []
	for g: Array in TRAY_GROUPS:
		for id: String in g[1]:
			var p := SharpenHelp.purpose(id)
			if p.is_empty():
				continue
			var e := State.tray_entry(id)
			if String(p.role) in ["cura", "prepara", "pieza"]:
				cures.append("%s: %s" % [String(e.short), String(p.line)])
				continue
			var mark := String({ "si": "AFILA · ", "rapido": "AFILA, SE PASA · " }.get(String(p.sharpens), ""))
			var l := Ui.para("%s%s: %s" % [mark, String(e.short), String(p.line)], "Note",
				String({ "si": "mint", "rapido": "gold" }.get(String(p.sharpens), "dim")))
			l.tooltip_text = "Fuente: " + State.short_source(String(p.source))
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			tools_purpose.add_child(l)
	tools_purpose.add_child(Ui.para("Para curar y colocar: " + "; ".join(PackedStringArray(cures)) + ".", "Note", "dim"))
	c.body.add_child(tools_purpose)
	tools_advice = Ui.para("", "Note", "gold")
	tools_advice.visible = false
	c.body.add_child(tools_advice)


func _paint_tip(v: Dictionary) -> void:
	if tip_meter == null:
		return
	if tip_meter.compact != compact:
		tip_meter.set_compact(compact)
		tip_lupa.set_compact(compact)
	var th: Dictionary = v.get("tip_help", {})
	tip_meter.show_view(v)
	tip_lupa.show_view(v)
	# en el teléfono la vista es pequeña: la lupa, solo con una herramienta de limar en la mano
	var held := String((v.get("hand", {}) as Dictionary).get("tool", ""))
	tip_lupa.visible = not th.is_empty() and (not compact or SharpenHelp.is_filing(held))
	var adv: Dictionary = th.get("advice", {})
	tools_advice.visible = bool(adv.get("show", false))
	if tools_advice.visible:
		var fix := String(adv.get("fix", ""))
		tools_advice.text = String(adv.get("text", "")) + ((" " + fix) if fix != "" else "")
