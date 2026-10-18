## Tarjeta · Coche en marcha (laboratorio 2.0, unidad 4c): una rapaz que se agarra a un coche en marcha, un tigre o un
## oso que se abalanza sobre él o un casuario que le da una patada. Dos modos:
##   - «Encima del coche»: a qué velocidad se suelta y por dónde (despega, sale despedido, resbala…), siempre con su
##     banda (los datos más desfavorables y los más favorables); la gráfica de la fuerza necesaria frente a la
##     disponible; las lecturas en directo (resistencia, sustentación, peso, inercia, normal, margen, carga, potencia que
##     roba al motor y reparto frente al coche) y el informe (capas que raya, parabrisas, frenada máxima y el aire);
##   - «Se abalanza»: el golpe (velocidad relativa, energía, marcas, perforación, abolladura, parabrisas), el balance de
##     energía como barra apilada y a dónde va a parar el animal.
## Aparece con un animal con datos (MovingCar.supports: las seis rapaces, el tigre, el oso y el casuario); con otra
## herramienta, un texto que dice cuáles los tienen y deja elegirlos.
## Todo número sale de core/lab/moving_car_state.gd (MovingCar, con los formatos de siempre): aquí no se calcula nada.
## Cada estimación va marcada, con su fuente en la ayuda emergente y en «Fuentes y estimaciones».
## - Deslizadores: la velocidad del coche (de 0 al tope del coche: 230 km/h en el turismo, MovingCar.SLIDER_MAX_KMH; la velocidad máxima del deportivo) va en directo (at_speed en cada fotograma); lo caro (hold_report
##   e impact) lo lanza el estado en un hilo al soltarlos. Su recorrido se pone con las señales bloqueadas
##   (set_slider): dentro del árbol, Godot recorta el valor al nuevo recorrido y emite value_changed, y eso cambiaba el
##   ensayo a mitad de un refresco (MillPage.set_slider).
## - Para entenderlo y jugar: experimentos de un clic arriba (MovingCarState.EXPERIMENTS), el porqué de cada veredicto,
##   un «¿sabías que…?» con su fuente (y otro dato con cada pulsación) y la moraleja al final; todos los textos, del
##   estado. El golpe suena con los efectos del banco (bus «Lab», play_sfx: el que da la sección) al llegar al panel.
## - Teléfono: una columna, con los controles de tamaño táctil (TOUCH px de alto).
## - Unidad 4d (docs/fisica/coche-en-marcha.md §9.10): el casuario, solo en «Se abalanza» (con su sexo y su patada; «Encima
##   del coche» se desactiva y dice por qué, HOLD_NO_REASON), el material experimental de las garras (Data.INLAYS) y el
##   animal asustado en defensa, en los dos modos, con sus lecturas (fuerza con su banda, presión en la punta, arado,
##   garras clavadas, rotura) y las filas Patada, Garras y Defensa del informe.
## - Unidad 4j: en «Se abalanza», la banda del golpe (todo a favor del coche y todo en contra) en el cuadro del veredicto,
##   como la del despegue encima del coche; las componentes de la velocidad y el vuelo, y el desgarro del plástico («Raja»)
##   en las lecturas; «Fuentes y estimaciones» empieza plegada, con su resumen. Y lo que pidió la 4i-B2: las dos variantes
##   del velocirraptor (de cine, ficción, y la reconstrucción) bajo su píldora, el color de la ficción y el deslizador
##   «Afilado» de unas garras reforjadas (MovingCarState.sharpness_view, como en el banco); la caída no sale en un salto.
extends "res://app/common/card.gd"

const MovingCarState = preload("res://core/lab/moving_car_state.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Pill = preload("res://app/common/pill.gd")
const Segmented = preload("res://app/common/segmented.gd")
const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const MovingCarView = preload("res://app/lab/moving_car_view.gd")
## Unidad 4s: la muestra de cada material de garra (la biblioteca común: core/lab/claw_optics.gd).
const ClawSwatch = preload("res://app/lab/car3d/claw_swatch.gd")
## Unidad 4s (petición del 17-10): el corte de la chapa con la marca.
const LayerCut = preload("res://app/lab/car3d/layer_cut.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const MovingCarChart = preload("res://app/lab/moving_car_chart.gd")
## Unidad 4s: la gráfica del daño frente a la velocidad (marcas, punción y rotura de las garras).
const MarksChart = preload("res://app/lab/moving_car_marks_chart.gd")
const MovingCarEnergy = preload("res://app/lab/moving_car_energy.gd")
const Bar = preload("res://app/common/bar.gd")
const ForceMarks = preload("res://app/lab/force_marks.gd")
## Unidad 4t: la carretera en curva (los datos de la norma para el deslizador del radio).
const CarCurve = preload("res://core/lab/car_curve.gd")

const TITLE := "Coche en marcha"
const INTRO := "Una rapaz que se agarra a un coche en marcha, un tigre o un oso que se le echa encima, o un casuario que le da una patada. El aire sobre el coche está medido en túnel (DrivAer); la resistencia y el agarre de las rapaces parten de medidas en túnel y en vivo, escaladas a cada especie; la aerodinámica del tigre y del oso y la patada del casuario son estimaciones apoyadas en los casos medidos más parecidos. Cada dato lleva su banda o su fuente, y las estimaciones van marcadas."
## Alto mínimo de un control en el teléfono (px lógicos): 44 pt de Apple, cerca de los 48 dp de Android.
const TOUCH := 44.0
## Ancho de la tarjeta por debajo del cual va como en un teléfono.
const NARROW := 520.0
const MAX_READINGS := 18
## Color de cada calidad de dato (la ficción de película, en rosa: nunca se pinta como un dato).
const QUALITY_COLOR := { "primary": "mint", "secondary": "ice", "estimate": "gold", "ficcion": "rose", "": "dimmer" }
## Marcas del deslizador «Afilado»: la punta de la ficha y las referencias medidas (como en el banco).
const SHARP_MARKS_MAX := 7
## Paso del deslizador «Afilado» (0-1).
const SHARP_STEP := 0.01
## Unidad 4s: lo que enseña cada vista.
const VIEW_TIP := "Coche entero: el coche a escala, con una ventana que sigue a las garras que tocan la chapa. Garras de cerca: esa misma cámara en toda la vista, con las marcas a su tamaño real (la barra de escala lo dice). Marca de cerca: el surco de una garra a unos milímetros, con sus capas y sus labios"

var lab: LabState
var st: MovingCarState
var mode_seg: Segmented
var intro: Label
## El selector de animal, siempre a la vista en la física 2.0 (la tarjeta tiene su propia página en la sección).
var animal_box: VBoxContainer
var off_box: VBoxContainer
var off_text: Label
var animal_pills := {}  # id → Pill (los animales con datos)
var variant_box: VBoxContainer
var variant_pills := {}  # id → Pill (las variantes del animal elegido: el velocirraptor de cine y la reconstrucción)
var main_box: VBoxContainer
## Experimentos de un clic: id → Pill (marcada si lo que se ve es ese experimento).
var experiment_pills := {}
var car_pills := {}  # id → Pill
var zone_label: Label
var zone_flow: HFlowContainer
var zone_pills := {}  # id → Pill (zonas para quedarse)
var izone_flow: HFlowContainer
var izone_pills := {}  # id → Pill (zonas del golpe)
var posture_box: VBoxContainer
var bird_seg: Segmented
var mammal_seg: Segmented
## El casuario: por qué no se queda encima (MovingCar.HOLD_NO_REASON) y su sexo (la hembra de 58 kg o el macho).
var hold_no: Label
var sex_box: VBoxContainer
var sex_seg: Segmented
var embedded_pill: Pill
## Unidad 4s: «Cámara» (el coche entero, con la ventana de las garras dentro, o las garras de cerca en la vista entera).
var zoom_seg: Segmented
## Unidad 4s: el corte de la chapa con la marca y su escalón (MovingCarState.tear_now).
var tear_cut: LayerCut
var view: MovingCarView
var speed: ValueSlider
var verdict_box: PanelContainer
var verdict_label: Label
var vsub: Label
## ¿Por qué? (MovingCarState.why_text)
var why_label: Label
var band_bar: Control
var band_text: Label
var now_text: Label
var now_band: Label
var hold_box: VBoxContainer
var chart: MovingCarChart
## Leyenda del aire bajo la gráfica (airTxt y el despegue con el aire de referencia).
var chart_air: Label
## Unidad 4s: la gráfica del daño a cada velocidad y su nota (por qué no perfora y cuándo se rompen las garras).
var marks_chart: MarksChart
var marks_note: Label
var readings: TileGrid
var tiles: Array = []  # [panel, título, valor, sub, calidad]
var impact_readings: TileGrid
var impact_tiles: Array = []
var temp: ValueSlider
var altitude: ValueSlider
var air_label: Label
var wind: ValueSlider
var crosswind: ValueSlider
var maneuver_pills := {}  # id → Pill
var hold_report: GridContainer
var impact_box: VBoxContainer
var animal_speed: ValueSlider
var run_note: Label
var angle: ValueSlider
var drop: ValueSlider
var car_mass: ValueSlider
var layers_flow: HFlowContainer
var layer_chips: Array = []  # [panel, muestra, texto]
var energy: MovingCarEnergy
var impact_report: GridContainer
## Unidad 4d: material experimental de las garras (id de Data.INLAYS → Pill) y animal asustado, en defensa.
var claws_box: VBoxContainer
var inlay_pills := {}
var inlay_note: Label
var defense_pill: Pill
var sharp_box: VBoxContainer
var sharp: ValueSlider
var sharp_marks: ForceMarks
var sharp_legend: HFlowContainer
var sharp_items: Array = []  # [fila, muestra, texto] por marca
var sharp_bar_parts := {}  # "pressure" | "lateral" → [título, barra, texto]
var sharp_note: Label
var sources_box: VBoxContainer
var sources_toggle: Pill
var sources_summary: Label
var sources_list: VBoxContainer
var sources_rows: Array = []  # [caja, cabecera, fuente]
## «¿Sabías que…?»: un dato del ensayo con su fuente (MovingCarState.facts) y el botón que pasa al siguiente.
var fact_box: PanelContainer
var fact_text: Label
var fact_source: Label
var fact_next: Pill
var fact_index := 0
## La moraleja (MovingCarState.moral), antes de la nota de seguridad.
var moral_label: Label
var safety: Label
## Toca un efecto del banco (id, volumen) por el bus «Lab»: lo pone la sección (su _play, que también vibra). Sin él,
## en silencio.
var play_sfx := Callable()
## Unidad 4t: la carretera (recta, curva o curva en S), el radio con los valores de la norma y la frase de la curva.
var road_box: VBoxContainer
var road_seg: Segmented
var radius: ValueSlider
var radius_marks: ForceMarks
var preset_flow: HFlowContainer
var preset_pills := {}  # id → Pill (los radios de la norma y la glorieta)
var curve_label: Label
var view_seg: Segmented  # la vista en curva: persecución (se ve girar el coche) o de lado (las garras)
var compact := false
var reduce_motion := false
## Métricas: coste del último refresco de la tarjeta (µs) y el mayor desde que se creó (en el hilo principal).
var last_paint_us := 0
var max_paint_us := 0
var paints := 0
var _seen := Vector3i(-1, -1, -1)  # versiones pintadas del estado: setup, live y heavy
var _seen_sel := ""  # firma de la selección pintada (animal, coche, modo, zonas, postura, maniobra…)
var _seen_inputs := ""  # firma de los datos del golpe pintados
var _lab_claw := "-"
var _lab_target := ""
var _dirty := true
var _learn_dirty := false  # al soltar un deslizador: el dato y la moraleja de donde se ha quedado
var _learn_need := 0  # en este refresco: 0 nada · 1 solo el porqué · 2 el porqué, el dato y la moraleja
var _sized := false
## Triángulos de la barra de la banda (la velocidad del coche y la banda que sigue más allá), reutilizados: la barra se
## redibuja en cada fotograma del deslizador.
var _tri_v := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _tri_inf := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _init() -> void:
	super(TITLE)
	# el título lleva el animal («Coche en marcha · Velocirraptor de cine»): en el teléfono salta de línea en lugar de
	# ensanchar la página más que la pantalla (4q)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size.x = 120.0
	mode_seg = Segmented.new(MovingCarState.MODES.map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.name, "title": m.title }),
		MovingCarState.MODE_HOLD, "Modo del coche en marcha")
	right.add_child(mode_seg)
	intro = Ui.para(INTRO, "Body")
	body.add_child(intro)
	_build_off()
	main_box = Ui.vbox(10)
	body.add_child(main_box)
	_build_experiments()
	_build_selection()
	# rótulos cortos: los tres caben en la fila de un teléfono (lo que enseña cada uno, en la ayuda)
	zoom_seg = Segmented.new([{ "id": "coche", "label": "Coche", "title": "El coche entero, con la ventana de las garras" },
		{ "id": "garras", "label": "Garras", "title": "Las garras de cerca, en toda la vista" },
		{ "id": "marca", "label": "Marca", "title": "La marca de una garra a unos milímetros, con sus capas y sus labios" }], "coche", "Cámara")
	zoom_seg.tooltip_text = VIEW_TIP
	var vrow := Ui.flow()
	vrow.add_child(Ui.sub_label("Cámara"))
	vrow.add_child(zoom_seg)
	main_box.add_child(vrow)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"BenchBox"
	view = MovingCarView.new()
	frame.add_child(view)
	main_box.add_child(frame)
	speed = ValueSlider.new("Velocidad del coche", "", MovingCar.PARAMS.v_kmh.min, MovingCar.PARAMS.v_kmh.max, 1.0)
	main_box.add_child(speed)
	_build_road()  # unidad 4t
	_build_light()  # unidad 4w
	_build_verdict()
	tear_cut = LayerCut.new()
	tear_cut.visible = false
	main_box.add_child(tear_cut)
	_build_fact()
	_build_hold()
	_build_impact()
	_build_sources()
	moral_label = Ui.para("", "Body")
	Ui.set_color(moral_label, "gold")
	main_box.add_child(moral_label)
	safety = Ui.para(MovingCar.SAFETY_NOTE, "Note")
	main_box.add_child(safety)
	resized.connect(_on_resized)


func _build_off() -> void:
	# el animal, arriba y siempre a la vista: la tarjeta tiene su propia página y ya no depende de la herramienta del banco
	animal_box = Ui.vbox(6)
	animal_box.add_child(Ui.sub_label("Animal"))
	var flow := Ui.flow()
	for a: Dictionary in MovingCarState.supported_animals():
		var p := Pill.new(String(a.name))
		flow.add_child(p)
		animal_pills[a.id] = p
	animal_box.add_child(flow)
	# unidad 4j (lo que pidió la 4i-B2): las variantes de un animal, bajo su píldora (el velocirraptor de cine, ficción, y
	# la reconstrucción); en una fila que se parte, para que quepan en un teléfono
	variant_box = Ui.vbox(4)
	variant_box.add_child(Ui.sub_label("Variante"))
	var vflow := Ui.flow()
	for k: String in MovingCarState.VARIANTS:
		for v: String in MovingCarState.VARIANTS[k]:
			var vp := Pill.new(String(MovingCarState.VARIANT_NAMES.get(v, MovingCarState.species_name(v))))
			vflow.add_child(vp)
			variant_pills[v] = vp
	variant_box.add_child(vflow)
	animal_box.add_child(variant_box)
	body.add_child(animal_box)
	off_box = Ui.vbox(8)
	off_text = Ui.para("", "Body")
	off_box.add_child(off_text)
	body.add_child(off_box)


## Experimentos de un clic: cada botón carga un ensayo entero (MovingCarState.EXPERIMENTS), con lo que carga en su ayuda.
func _build_experiments() -> void:
	var box := Ui.vbox(6)
	box.add_child(Ui.sub_label("Experimentos"))
	var flow := Ui.flow()
	for e: Dictionary in MovingCarState.EXPERIMENTS:
		var p := Pill.new(String(e.name))
		p.tooltip_text = MovingCarState.experiment_tip(String(e.id))
		flow.add_child(p)
		experiment_pills[e.id] = p
	box.add_child(flow)
	main_box.add_child(box)


func _build_selection() -> void:
	var box := Ui.vbox(6)
	hold_no = Ui.para("Encima del coche, no. " + MovingCar.HOLD_NO_REASON, "Note")
	box.add_child(hold_no)
	box.add_child(Ui.sub_label("Coche"))
	var cars := Ui.flow()
	for id: String in MovingCarState.CARS:
		var t: Dictionary = Catalog.find_by_id(Catalog.TARGETS, id)
		var p := Pill.new(String(t.name))
		p.tooltip_text = String(t.fact)
		cars.add_child(p)
		car_pills[id] = p
	box.add_child(cars)
	zone_label = Ui.sub_label("Dónde se agarra")
	box.add_child(zone_label)
	zone_flow = Ui.flow()
	for id: String in MovingCar.ZONES:
		var p := Pill.new(String(MovingCar.ZONES[id].name))
		p.tooltip_text = "Cp %s · %s" % [MovingCarState.fmt_band(MovingCar.ZONES[id].cp), MovingCar.ZONES[id].cp.source]
		zone_flow.add_child(p)
		zone_pills[id] = p
	box.add_child(zone_flow)
	izone_flow = Ui.flow()
	for id: String in MovingCar.IMPACT_ZONES:
		var p := Pill.new(String(MovingCar.IMPACT_ZONES[id].name))
		izone_flow.add_child(p)
		izone_pills[id] = p
	box.add_child(izone_flow)
	posture_box = Ui.vbox(6)
	posture_box.add_child(Ui.sub_label("Postura"))
	bird_seg = Segmented.new(MovingCar.POSTURES.ave.map(func(id: String) -> Dictionary: return { "id": id, "label": MovingCar.POSTURE_NAMES[id] }),
		"plegadas", "Postura del ave")
	mammal_seg = Segmented.new(MovingCar.POSTURES.mamifero.map(func(id: String) -> Dictionary: return { "id": id, "label": MovingCar.POSTURE_NAMES[id] }),
		"tumbado", "Postura del mamífero")
	posture_box.add_child(bird_seg)
	posture_box.add_child(mammal_seg)
	box.add_child(posture_box)
	sex_box = Ui.vbox(6)
	sex_box.add_child(Ui.sub_label("Sexo"))
	sex_seg = Segmented.new(MovingCar.SEXES.map(func(id: String) -> Dictionary: return { "id": id, "label": MovingCar.SEX_NAMES[id] }),
		MovingCar.SEXES[0], "Sexo del casuario")
	sex_box.add_child(sex_seg)
	box.add_child(sex_box)
	_build_claws(box)
	embedded_pill = Pill.new("Garras clavadas (tras un golpe que atraviesa el panel)")
	embedded_pill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(embedded_pill)
	main_box.add_child(box)


## Unidad 4d: el material experimental de las garras (Data.INLAYS; «none» es la queratina) y el animal asustado. En los
## dos modos; cada material con su dureza y cómo se rompe en la ayuda emergente.
func _build_claws(parent: VBoxContainer) -> void:
	claws_box = Ui.vbox(6)
	claws_box.add_child(Ui.sub_label("Material de las garras (experimento)"))
	var flow := Ui.flow()
	for i: Dictionary in Catalog.INLAYS:
		var p := Pill.new("Queratina" if i.id == MovingCarState.KERATIN else String(i.short))
		p.tooltip_text = MovingCarState.inlay_tip(String(i.id))
		p.icon = ClawSwatch.texture(String(i.id))
		p.add_theme_constant_override("icon_max_width", ClawSwatch.SHOW)
		flow.add_child(p)
		inlay_pills[i.id] = p
	claws_box.add_child(flow)
	inlay_note = Ui.para("", "Small")
	claws_box.add_child(inlay_note)
	_build_sharpness(claws_box)
	defense_pill = Pill.new("Asustado / en defensa")
	defense_pill.tooltip_text = MovingCarState.DEFENSE_TIP
	var row := Ui.flow()  # en una fila que se parte: la píldora, de su tamaño (no de lado a lado)
	row.add_child(defense_pill)
	claws_box.add_child(row)
	parent.add_child(claws_box)


## Unidad 4j (lo que pidió la 4i-B2): el deslizador «Afilado» de unas garras reforjadas, como el del banco: sus marcas bajo
## la pista con su leyenda, las dos barras (la presión que sube y la carga que aguanta de lado, que baja) una debajo de otra
## para que quepan en un teléfono, y la nota. Todos los textos y los niveles, de MovingCarState.sharpness_view.
func _build_sharpness(parent: VBoxContainer) -> void:
	sharp_box = Ui.vbox(6)
	sharp = ValueSlider.new("Afilado", "(escala log)", 0.0, 1.0, SHARP_STEP)
	sharp_box.add_child(sharp)
	sharp_marks = ForceMarks.new(sharp.slider)
	sharp.slider.add_child(sharp_marks)
	sharp_legend = Ui.flow(12, 4)
	for i in SHARP_MARKS_MAX:
		var item := Ui.hbox(6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var text := Ui.label("", "Small")
		item.add_child(text)
		sharp_legend.add_child(item)
		sharp_items.append([item, swatch, text])
	sharp_box.add_child(sharp_legend)
	for key: String in ["pressure", "lateral"]:
		var col := Ui.vbox(4)
		var title := Ui.label("", "SliderLabel")
		col.add_child(title)
		var bar := Bar.new(9.0)
		col.add_child(bar)
		var text := Ui.para("", "Small")
		col.add_child(text)
		sharp_box.add_child(col)
		sharp_bar_parts[key] = [title, bar, text]
	sharp_note = Ui.para("", "Note")
	sharp_box.add_child(sharp_note)
	parent.add_child(sharp_box)


func _build_verdict() -> void:
	verdict_box = PanelContainer.new()
	verdict_box.theme_type_variation = &"VerdictBox"
	var col := Ui.vbox(6)
	col.accessibility_live = AccessibilityServer.LIVE_POLITE
	verdict_label = Ui.para("", "VerdictSmall")
	col.add_child(verdict_label)
	vsub = Ui.para("", "Body")
	col.add_child(vsub)
	why_label = Ui.para("", "Body")
	Ui.set_color(why_label, "ice")
	col.add_child(why_label)
	band_bar = Control.new()
	band_bar.custom_minimum_size = Vector2(0, 34)
	band_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_bar.draw.connect(_draw_band)
	col.add_child(band_bar)
	band_text = Ui.para("", "Small")
	Ui.set_color(band_text, "gold")
	col.add_child(band_text)
	now_text = Ui.para("", "Body")
	col.add_child(now_text)
	now_band = Ui.para("", "Small")
	col.add_child(now_band)
	verdict_box.add_child(col)
	main_box.add_child(verdict_box)


## «¿Sabías que…?»: el dato, su fuente (con su calidad) y el botón que pasa al siguiente.
func _build_fact() -> void:
	fact_box = PanelContainer.new()
	fact_box.theme_type_variation = &"SectionBox"
	var col := Ui.vbox(4)
	var head := Ui.hbox(8)
	var title := Ui.sub_label("¿Sabías que…?")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	fact_next = Pill.new("Otro dato", "Pill", false)
	head.add_child(fact_next)
	col.add_child(head)
	fact_text = Ui.para("", "Body")
	col.add_child(fact_text)
	fact_source = Ui.para("", "Small")
	col.add_child(fact_source)
	fact_box.add_child(col)
	main_box.add_child(fact_box)


func _build_hold() -> void:
	hold_box = Ui.vbox(10)
	chart = MovingCarChart.new()
	hold_box.add_child(chart)
	chart_air = Ui.para("", "Small")
	hold_box.add_child(chart_air)
	hold_box.add_child(Ui.sub_label("El daño a cada velocidad: surco, punta clavada y garras"))
	marks_chart = MarksChart.new()
	hold_box.add_child(marks_chart)
	marks_note = Ui.para("", "Small")
	hold_box.add_child(marks_note)
	hold_box.add_child(Ui.sub_label("Lecturas en directo"))
	readings = _readings_grid(tiles)
	hold_box.add_child(readings)
	hold_box.add_child(Ui.sub_label("Aire: temperatura y altitud"))
	temp = ValueSlider.new("Temperatura del aire", "", MovingCar.PARAMS.temp_c.min, MovingCar.PARAMS.temp_c.max, 1.0)
	hold_box.add_child(temp)
	altitude = ValueSlider.new("Altitud de la carretera", "", MovingCar.PARAMS.altitude_m.min, MovingCar.PARAMS.altitude_m.max, 50.0)
	hold_box.add_child(altitude)
	air_label = Ui.para("", "Note")
	hold_box.add_child(air_label)
	hold_box.add_child(Ui.sub_label("Viento y maniobra"))
	wind = ValueSlider.new("Viento de frente o de cola", "", MovingCar.PARAMS.wind_kmh.min, MovingCar.PARAMS.wind_kmh.max, 1.0)
	hold_box.add_child(wind)
	crosswind = ValueSlider.new("Viento lateral", "", MovingCar.PARAMS.crosswind_kmh.min, MovingCar.PARAMS.crosswind_kmh.max, 1.0)
	hold_box.add_child(crosswind)
	var man := Ui.flow()
	for m: Dictionary in MovingCar.MANEUVERS:
		var p := Pill.new(String(m.name))
		p.tooltip_text = "%s g de aceleración · %s g de curva · %s: %s" % [Ui.num(m.accel_g), Ui.num(m.lateral_g),
			MovingCarState.QUALITY_TEXT[m.quality], m.source]
		man.add_child(p)
		maneuver_pills[m.id] = p
	hold_box.add_child(man)
	hold_box.add_child(Ui.sub_label("Informe"))
	hold_report = _report_grid()
	hold_box.add_child(hold_report)
	main_box.add_child(hold_box)


func _build_impact() -> void:
	impact_box = Ui.vbox(10)
	impact_box.add_child(Ui.sub_label("El salto"))
	animal_speed = ValueSlider.new("Velocidad del animal", "", MovingCar.PARAMS.animal_kmh.min, MovingCar.PARAMS.animal_kmh.max, 1.0)
	impact_box.add_child(animal_speed)
	run_note = Ui.para("", "Small")
	impact_box.add_child(run_note)
	# las aclaraciones van debajo, en un texto que se parte: la cabecera de un deslizador no se parte y en un teléfono
	# desbordaba la columna
	angle = ValueSlider.new("Ángulo del salto", "", MovingCar.PARAMS.angle_deg.min, MovingCar.PARAMS.angle_deg.max, 5.0)
	impact_box.add_child(angle)
	impact_box.add_child(Ui.para("respecto al coche: 0° lo persigue, 90° lo cruza, 180° le viene de frente", "Small"))
	drop = ValueSlider.new("Caída sobre el panel", "", MovingCar.PARAMS.drop_m.min, MovingCar.PARAMS.drop_m.max, 0.1)
	impact_box.add_child(drop)
	car_mass = ValueSlider.new("Masa del coche", "", MovingCar.PARAMS.car_mass_kg.min, MovingCar.PARAMS.car_mass_kg.max, 50.0)
	impact_box.add_child(car_mass)
	impact_box.add_child(Ui.sub_label("El golpe"))
	impact_readings = _readings_grid(impact_tiles)
	impact_box.add_child(impact_readings)
	impact_box.add_child(Ui.sub_label("Capas del coche"))
	layers_flow = Ui.flow(8, 6)
	for i in 5:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"SectionBox"
		var h := Ui.hbox(6)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var l := Ui.label("", "Small")
		h.add_child(l)
		chip.add_child(h)
		layers_flow.add_child(chip)
		layer_chips.append([chip, sw, l])
	impact_box.add_child(layers_flow)
	impact_box.add_child(Ui.sub_label("Balance de energía del golpe"))
	energy = MovingCarEnergy.new()
	impact_box.add_child(energy)
	impact_box.add_child(Ui.sub_label("Informe de daños"))
	impact_report = _report_grid()
	impact_box.add_child(impact_report)
	main_box.add_child(impact_box)


func _build_sources() -> void:
	sources_box = Ui.vbox(6)
	var head := Ui.hbox(8)
	var title := Ui.sub_label("Fuentes y estimaciones")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	sources_toggle = Pill.new("Ver", "Pill", false)
	head.add_child(sources_toggle)
	sources_box.add_child(head)
	# unidad 4j: la lista es larga (cada dato con su fuente); empieza plegada, con el resumen del estado a la vista
	sources_summary = Ui.para("", "Small")
	sources_box.add_child(sources_summary)
	sources_list = Ui.vbox(6)
	sources_list.visible = false
	sources_box.add_child(sources_list)
	main_box.add_child(sources_box)


## Rejilla de lecturas (fichas con título, valor, banda o detalle y calidad; la fuente, en la ayuda emergente). Las fichas
## se crean una vez: pool guarda [panel, título, valor, sub, calidad] de cada una.
static func _readings_grid(pool: Array) -> TileGrid:
	var grid := TileGrid.new(150.0, 8.0)
	for i in MAX_READINGS:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"Metric"
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var v := Ui.vbox(3)
		var title := Ui.para("", "Small")
		title.uppercase = true
		v.add_child(title)
		var value := Ui.para("", "MetricValue")
		v.add_child(value)
		var sub := Ui.para("", "Small")
		v.add_child(sub)
		var q := Ui.para("", "Small")
		v.add_child(q)
		panel.add_child(v)
		grid.add_child(panel)
		pool.append([panel, title, value, sub, q])
	return grid


static func _report_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	return g


func setup(p_lab: LabState, _art: ArtCache) -> void:
	lab = p_lab
	st = MovingCarState.new()
	st.changed.connect(_on_state_changed)
	mode_seg.selected.connect(func(id: String) -> void: st.set_mode(id))
	for id: String in animal_pills:
		(animal_pills[id] as Button).pressed.connect(_on_animal.bind(id))
	for id: String in variant_pills:
		(variant_pills[id] as Button).pressed.connect(_on_variant.bind(id))
	for id: String in experiment_pills:
		(experiment_pills[id] as Button).pressed.connect(_on_experiment.bind(id))
	fact_next.pressed.connect(func() -> void:
		fact_index += 1
		_paint_fact())
	view.contact.connect(_on_contact)
	zoom_seg.selected.connect(func(id: String) -> void: view.set_closeup_full(id != "coche", id == "marca"))
	for id: String in car_pills:
		(car_pills[id] as Button).pressed.connect(_on_car.bind(id))
	for id: String in zone_pills:
		(zone_pills[id] as Button).pressed.connect(func() -> void: _pick(func() -> void: st.set_zone(id)))
	for id: String in izone_pills:
		(izone_pills[id] as Button).pressed.connect(func() -> void: _pick(func() -> void: st.set_impact_zone(id)))
	for seg: Segmented in [bird_seg, mammal_seg]:
		seg.selected.connect(func(id: String) -> void: st.set_posture(id))
	sex_seg.selected.connect(func(id: String) -> void: st.set_sex(id))
	for id: String in inlay_pills:
		(inlay_pills[id] as Button).pressed.connect(func() -> void: _pick(func() -> void: st.set_inlay(id)))
	defense_pill.pressed.connect(func() -> void: _pick(func() -> void: st.set_defense(not st.defense)))
	embedded_pill.pressed.connect(func() -> void: _pick(func() -> void: st.set_embedded(not st.embedded)))
	for id: String in maneuver_pills:
		(maneuver_pills[id] as Button).pressed.connect(func() -> void: _pick(func() -> void: st.set_maneuver(id)))
	sources_toggle.pressed.connect(func() -> void:
		sources_list.visible = not sources_list.visible
		sources_toggle.text = "Ocultar" if sources_list.visible else "Ver")
	speed.value_changed.connect(func(v: float) -> void: st.set_speed(v))
	temp.value_changed.connect(func(v: float) -> void: st.set_air(v, st.altitude_m))
	altitude.value_changed.connect(func(v: float) -> void: st.set_air(st.temp_c, v))
	wind.value_changed.connect(func(v: float) -> void: st.set_wind(v, st.crosswind_kmh))
	crosswind.value_changed.connect(func(v: float) -> void: st.set_wind(st.wind_kmh, v))
	animal_speed.value_changed.connect(func(v: float) -> void: st.set_impact("animal_kmh", v))
	angle.value_changed.connect(func(v: float) -> void: st.set_impact("angle_deg", v))
	drop.value_changed.connect(func(v: float) -> void: st.set_impact("drop_m", _snap(v, 1)))
	car_mass.value_changed.connect(func(v: float) -> void: st.set_impact("car_mass_kg", v))
	sharp.value_changed.connect(func(v: float) -> void: st.set_sharpness(_snap(v, 2)))
	_connect_road()  # unidad 4t
	_connect_light()  # unidad 4w
	for s: ValueSlider in _sliders():
		s.slider.drag_started.connect(func() -> void: st.set_dragging(true))
		s.slider.drag_ended.connect(func(_changed: bool) -> void:
			st.set_dragging(false)
			_learn_dirty = true  # al soltar, el dato y la moraleja de donde se ha quedado
			_dirty = true)
	refresh()


func _sliders() -> Array[ValueSlider]:
	return [speed, temp, altitude, wind, crosswind, animal_speed, angle, drop, car_mass, sharp, radius]


## Pulsar una píldora: si ya estaba elegida, el estado no cambia y solo hay que volver a marcarla.
func _pick(fn: Callable) -> void:
	fn.call()
	_dirty = true
	_paint()


func _on_animal(id: String) -> void:
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, id))


## Otra variante del animal elegido (el velocirraptor de cine o la reconstrucción): el estado la elige (set_variant) y el
## banco cambia al mismo animal, como al elegirlo arriba.
func _on_variant(id: String) -> void:
	st.set_variant(id)
	var c: Variant = Catalog.find_by_id(Catalog.CLAWS, id)
	if c != null and (lab.claw == null or lab.claw.id != id):
		lab.set_claw(c)
	_dirty = true
	_paint()


## Un experimento de un clic: el estado carga el ensayo entero (un solo setup) y el banco cambia al mismo animal.
func _on_experiment(id: String) -> void:
	var e := MovingCarState.experiment(id)
	if e.has("claw") and (lab.claw == null or lab.claw.id != e.claw):
		lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, e.claw))
	if st.load_experiment(id):
		fact_index = 0
	_dirty = true
	_paint()


## El golpe llega al panel (MovingCarView.contact): suena el efecto del banco que le corresponde.
func _on_contact() -> void:
	if not play_sfx.is_valid() or st == null or st.mode != MovingCarState.MODE_IMPACT:
		return
	var id := st.impact_sfx()
	if id != "":
		play_sfx.call(id, LabState.DEFAULT_VOLUME)


func _on_car(id: String) -> void:
	st.set_target(Catalog.find_by_id(Catalog.TARGETS, id))
	_dirty = true
	_paint()


func _on_state_changed() -> void:
	_dirty = true


## Número con una cifra decimal como máximo, a partir del valor de un deslizador (0.30000000000000004 → 0.3).
static func _snap(v: float, decimals: int) -> float:
	var k := pow(10.0, decimals)
	return Js.js_round(v * k) / k


func _on_resized() -> void:
	var c := size.x < NARROW
	if _sized and c == compact:
		return
	_sized = true
	compact = c
	for s: ValueSlider in _sliders():
		s.slider.custom_minimum_size.y = TOUCH if compact else 24.0
	var buttons: Array = []
	for d: Dictionary in [animal_pills, variant_pills, experiment_pills, car_pills, zone_pills, izone_pills, maneuver_pills, inlay_pills, preset_pills]:
		buttons.append_array(d.values())
	buttons.append(embedded_pill)
	buttons.append(defense_pill)
	buttons.append(sources_toggle)
	buttons.append(fact_next)
	for seg: Segmented in [mode_seg, bird_seg, mammal_seg, sex_seg, zoom_seg, road_seg, view_seg]:
		buttons.append_array(seg.buttons.values())
	for b: Control in buttons:
		b.custom_minimum_size.y = TOUCH if compact else 0.0
	_compact_light()  # unidad 4w


# ════════ Refresco ════════

## Pone la tarjeta al día (lo llama la sección cuando cambia el banco): el animal y el coche del banco, y lo que haya
## cambiado en el estado.
func refresh() -> void:
	if lab == null:
		return
	var cid: String = lab.claw.id if lab.claw != null else ""
	if cid != _lab_claw:
		_lab_claw = cid
		st.set_claw(lab.claw)
	var tid: String = lab.target.id
	if tid != _lab_target:
		_lab_target = tid
		if MovingCarState.CARS.has(tid):
			st.set_target(lab.target)
	_paint()


## Avanza la tarjeta ms milisegundos (lo llama la sección en cada fotograma): lo caro que llega de los hilos, el dibujo
## y, si algo ha cambiado, el refresco.
func step(ms: float) -> void:
	if st == null:
		return
	st.step(ms)
	view.step(ms)
	if _dirty:
		_paint()


## Espera lo caro (tests y demo) y repinta.
func finish() -> void:
	if st != null and st.finish():
		_paint()


## Espera las tareas en marcha del estado (al cerrar la sección).
func dispose() -> void:
	if st != null:
		st.dispose()


## Firma de lo que se elige con píldoras y selectores (lo que decide qué controles se ven y cuáles están marcados).
func _sel_sig() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [st.claw.id if st.claw != null else "-", st.target.id, st.mode, st.zone,
		st.impact_zone, st.posture, st.embedded, st.maneuver, st.inlay, st.defense, st.sex]


func _inputs_sig() -> String:
	return "%s|%s|%s|%s|%s" % [st.animal_kmh, st.angle_deg, st.drop_m, st.car_mass_kg, st.v_kmh]


## Repinta lo que ha cambiado: la selección, el ensayo (setup, gráfica y veredicto), las fuerzas a la velocidad del
## deslizador (en cada fotograma de ese deslizador) y lo caro que llega de los hilos.
func _paint() -> void:
	var t0 := Time.get_ticks_usec()
	_dirty = false
	paints += 1
	var ok := st.supported() and lab.model == MovingCarState.MODEL
	off_box.visible = not ok
	main_box.visible = ok
	animal_box.visible = lab.model == MovingCarState.MODEL
	var cur: String = MovingCarState.animal_entry_id(String(st.claw.id)) if st.claw != null else ""
	for id: String in animal_pills:
		(animal_pills[id] as Pill).set_on(id == cur)
	# las variantes del animal elegido, bajo su píldora (ninguna si no tiene o si no hay coche en marcha)
	var vs: Array = st.variants().map(func(v: Dictionary) -> String: return String(v.id)) if ok else []
	variant_box.visible = not vs.is_empty()
	for id: String in variant_pills:
		var vp: Pill = variant_pills[id]
		vp.visible = vs.has(id)
		vp.set_on(st.claw != null and id == String(st.claw.id))
	if not ok:
		_paint_off()
		_seen = Vector3i(-1, -1, -1)
		_seen_sel = ""
		return
	var sel_sig := _sel_sig()
	var sel := sel_sig != _seen_sel
	var setup_changed := sel or _seen.x != st.setup_version
	var live_changed := setup_changed or _seen.y != st.live_version
	var heavy_changed := setup_changed or _seen.z != st.heavy_version
	var inputs_sig := _inputs_sig()
	if sel:
		_paint_selection()
	if setup_changed:
		_paint_setup()
	if inputs_sig != _seen_inputs or sel:
		_paint_inputs()
	if live_changed:
		_paint_live()
	if sel or live_changed:
		_paint_road()  # unidad 4t
	if heavy_changed:
		_paint_heavy()
	if live_changed or heavy_changed:
		tear_cut.set_data(st.tear_now())  # unidad 4s
		# unidad 4p: los logros del coche en marcha (Lab.earn_car_badges, por el estado del banco)
		lab.earn_car_badges({ "mode": st.mode, "holds": st.at.get("holds"), "vKmh": st.v_kmh, "hit": st.hit })
	if _learn_dirty and not st.dragging:
		_learn_need = 2
	# el porqué, el dato y la moraleja, una vez por refresco
	if _learn_need > 0:
		_paint_learn(_learn_need == 1)
	_learn_need = 0
	_learn_dirty = false
	view.reduce_motion = reduce_motion
	view.sync(st, not st.dragging)
	_seen = Vector3i(st.setup_version, st.live_version, st.heavy_version)
	_seen_sel = sel_sig
	_seen_inputs = inputs_sig
	last_paint_us = Time.get_ticks_usec() - t0
	max_paint_us = maxi(max_paint_us, last_paint_us)


func _paint_off() -> void:
	var names: Array = MovingCarState.supported_animals().map(func(a: Dictionary) -> String: return String(a.name).to_lower())
	var list := "%s y %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]
	var why := ""
	if lab.model != MovingCarState.MODEL:
		why = "El coche en marcha es de la física 2.0: no existe en el motor 1.x. "
	elif st.claw == null:
		why = "Con una uña no hay coche en marcha. "
	elif st.scen.has("reason"):
		why = "Sin datos para esta herramienta (%s). " % st.scen.reason
	else:
		why = "Sin datos para esta herramienta. "
	off_text.text = "%sTienen datos para el coche en marcha: %s. Elige uno arriba, en «Animal»." % [why, list]


func _paint_selection() -> void:
	var hold := st.mode == MovingCarState.MODE_HOLD
	if st.claw != null and inlay_pills.has(MovingCarState.KERATIN):
		# la queratina, con el color de la del animal elegido
		(inlay_pills[MovingCarState.KERATIN] as Button).icon = ClawSwatch.texture("none", ClawOptics.keratin_color(String(st.claw.id)))
	mode_seg.set_value(st.mode)
	for id: String in car_pills:
		(car_pills[id] as Pill).set_on(id == st.target.id)
	zone_label.text = ("Dónde se agarra" if hold else ("Dónde patea" if st.is_kicker() else "Dónde golpea")).to_upper()
	zone_flow.visible = hold
	izone_flow.visible = not hold
	var zs := st.zones()
	for id: String in zone_pills:
		var p: Pill = zone_pills[id]
		p.visible = zs.has(id)
		p.set_on(id == st.zone)
	var izs := st.impact_zones()
	for id: String in izone_pills:
		var p: Pill = izone_pills[id]
		p.visible = izs.has(id)
		p.set_on(id == st.impact_zone)
	posture_box.visible = hold
	bird_seg.visible = st.kind() == "ave"
	mammal_seg.visible = st.kind() == "mamifero"
	bird_seg.set_value(st.posture)
	mammal_seg.set_value(st.posture)
	# el casuario: solo el golpe (la opción de quedarse encima, desactivada con su porqué) y su sexo
	var can_hold := st.supports_hold()
	var hold_button: Button = mode_seg.buttons[MovingCarState.MODE_HOLD]
	hold_button.disabled = not can_hold
	hold_button.tooltip_text = MovingCarState.MODES[0].title if can_hold else MovingCar.HOLD_NO_REASON
	hold_no.visible = not can_hold
	sex_box.visible = not hold and not st.sexes().is_empty()
	sex_seg.set_value(st.sex)
	for id: String in inlay_pills:
		(inlay_pills[id] as Pill).set_on(id == st.inlay)
	inlay_note.text = st.inlay_note()
	sharp_box.visible = st.sharpenable()
	defense_pill.set_on(st.defense)
	embedded_pill.visible = hold and st.can_embed()
	embedded_pill.set_on(st.embedded)
	for id: String in maneuver_pills:
		(maneuver_pills[id] as Pill).set_on(id == st.maneuver)
	hold_box.visible = hold
	impact_box.visible = not hold
	band_bar.visible = hold
	now_band.visible = hold
	now_text.visible = hold
	title_label.text = "%s · %s" % [TITLE, st.animal_name()]
	accessibility_name = title_label.text
	_paint_experiments()


## Los experimentos: ocultos los que aún no están cableados («aire», solo con el animal encima) y marcado el que se ve.
func _paint_experiments() -> void:
	for id: String in experiment_pills:
		var p: Pill = experiment_pills[id]
		p.visible = st.experiment_shown(id)
		p.set_on(st.experiment_matches(id))


## El ensayo nuevo (setup, o el aire con with_air): los deslizadores del ensayo, el aire, la gráfica, las fuentes y el
## informe.
func _paint_setup() -> void:
	var hold := st.mode == MovingCarState.MODE_HOLD
	set_slider(temp.slider, MovingCar.PARAMS.temp_c.min, MovingCar.PARAMS.temp_c.max, st.temp_c)
	temp.display.text = "%s °C" % Ui.num(st.temp_c)
	set_slider(altitude.slider, MovingCar.PARAMS.altitude_m.min, MovingCar.PARAMS.altitude_m.max, st.altitude_m)
	altitude.display.text = "%s m" % Ui.num(st.altitude_m)
	set_slider(wind.slider, MovingCar.PARAMS.wind_kmh.min, MovingCar.PARAMS.wind_kmh.max, st.wind_kmh)
	wind.display.text = _wind_txt(st.wind_kmh)
	set_slider(crosswind.slider, MovingCar.PARAMS.crosswind_kmh.min, MovingCar.PARAMS.crosswind_kmh.max, st.crosswind_kmh)
	crosswind.display.text = MovingCarState.fmt_kmh(st.crosswind_kmh)
	air_label.text = nb(st.air_txt)
	if hold and not st.chart.is_empty():
		chart.set_curve(st.chart, st.det, _chart_note(), st.ref_kmh())
		chart_air.text = nb(st.air_legend())
	if hold:
		_paint_marks_chart()
	_fill_sources()
	_paint_sharpness()
	_paint_experiments()


## Unidad 4s: la gráfica del daño a cada velocidad (la curva llega del hilo de lo caro, una vez por ensayo; mientras, dice
## «calculando…»), su punto a la velocidad del deslizador y la nota.
func _paint_marks_chart() -> void:
	var c: Dictionary = st.marks_curve()
	if not (c.is_empty() and marks_chart.curve.is_empty()) and (c.is_empty() or not is_same(c, marks_chart.curve)):
		marks_chart.set_curve(c)
	marks_chart.set_point(st.marks_now())
	var note := st.marks_note()
	marks_note.text = nb(note)
	marks_note.visible = note != ""


## Unidad 4j: el deslizador «Afilado», sus marcas y su leyenda, las dos barras y la nota (MovingCarState.sharpness_view);
## oculto si las garras no se pueden afilar (solo unas reforjadas).
func _paint_sharpness() -> void:
	var v: Dictionary = st.sharpness_view()
	sharp_box.visible = not v.is_empty()
	if v.is_empty():
		return
	set_slider(sharp.slider, 0.0, 1.0, st.sharpness)
	sharp.display.text = String(v.display)
	sharp.slider.accessibility_description = String(v.spoken)
	var marks: Array = v.marks
	sharp_marks.set_marks(marks.map(func(m: Dictionary) -> Array: return [float(m.t), Palette.color(String(m.color))]))
	for i in sharp_items.size():
		var item: Array = sharp_items[i]
		(item[0] as Control).visible = i < marks.size()
		if i < marks.size():
			var c := Palette.color(String(marks[i].color))
			(item[1] as ColorRect).color = c
			(item[2] as Label).text = String(marks[i].text)
			Ui.set_color(item[2], String(marks[i].color))
	for key: String in sharp_bar_parts:
		var parts: Array = sharp_bar_parts[key]
		var b: Dictionary = v[key]
		(parts[0] as Label).text = String(b.title)
		(parts[1] as Bar).set_level(float(b.level), Palette.color(String(b.color)))
		(parts[2] as Label).text = nb(String(b.text))
		Ui.set_color(parts[2], String(b.color))
	sharp_note.text = nb(String(v.note))


## Los deslizadores del golpe y la velocidad del coche (sin emitir: set_slider).
func _paint_inputs() -> void:
	set_slider(speed.slider, MovingCar.PARAMS.v_kmh.min, st.slider_max_kmh(), st.v_kmh)
	speed.display.text = MovingCarState.fmt_kmh(st.v_kmh)
	speed.slider.accessibility_description = "%s kilómetros por hora" % Ui.num(st.v_kmh)
	set_slider(animal_speed.slider, MovingCar.PARAMS.animal_kmh.min, MovingCar.PARAMS.animal_kmh.max, st.animal_kmh)
	animal_speed.display.text = MovingCarState.fmt_kmh(st.animal_kmh)
	set_slider(angle.slider, MovingCar.PARAMS.angle_deg.min, MovingCar.PARAMS.angle_deg.max, st.angle_deg)
	angle.display.text = "%s°" % Ui.num(st.angle_deg)
	set_slider(drop.slider, MovingCar.PARAMS.drop_m.min, MovingCar.PARAMS.drop_m.max, st.drop_m)
	drop.display.text = "%s m" % Ui.num(st.drop_m)
	# la patada no cae sobre el panel (salta) y un velocirraptor salta desde la carretera (su vuelo lo da el salto)
	drop.visible = not st.impact_side() and not st.is_kicker() and not st.is_leaper()
	set_slider(car_mass.slider, MovingCar.PARAMS.car_mass_kg.min, MovingCar.PARAMS.car_mass_kg.max, st.car_mass_kg)
	car_mass.display.text = "%s kg" % Ui.num(st.car_mass_kg)
	var body: Dictionary = MovingCar.body_of(st.claw)
	run_note.visible = body.has("run_kmh")
	if run_note.visible:
		var run: Dictionary = body.run_kmh
		run_note.text = nb("Carrera máxima: %s · %s (fuente en la ayuda y abajo)" % [MovingCarState.fmt_kmh(run.value),
			MovingCarState.QUALITY_TEXT[run.quality]])
		run_note.tooltip_text = "Fuente: %s" % run.source
		run_note.mouse_filter = Control.MOUSE_FILTER_PASS
	_paint_experiments()


func _paint_live() -> void:
	if st.mode != MovingCarState.MODE_HOLD:
		return
	var a: Dictionary = st.at
	if a.is_empty():
		return
	chart.set_point(a.vKmh, a.needN, a.availN, a.holds)
	marks_chart.set_point(st.marks_now())
	_fill_tiles(tiles, st.hold_readings())
	verdict_label.text = headline(String(st.verdict.verdict))
	Ui.set_color(verdict_label, st.verdict_color())
	vsub.text = nb(String(st.verdict.vsub))
	var b := st.band()
	band_text.text = nb("%s · valor central: %s" % [b.text, b.central])
	now_text.text = nb(st.now_text())
	Ui.set_color(now_text, st.now_color())
	now_band.text = nb(st.now_band_text())
	band_bar.queue_redraw()
	# mientras se arrastra, solo el porqué (el dato y la moraleja, al soltar: llegan con lo caro)
	_learn_need = maxi(_learn_need, 1 if st.dragging else 2)


## Lo caro, cuando llega de su hilo: el informe del animal quieto encima (la frenada máxima y el despegue de
## referencia) o el golpe entero.
func _paint_heavy() -> void:
	_learn_need = 2
	if st.mode == MovingCarState.MODE_HOLD:
		_fill_grid(hold_report, st.hold_rows())
		chart.set_ref(st.ref_kmh())
		chart_air.text = nb(st.air_legend())
		_paint_marks_chart()
		_fill_tiles(tiles, st.hold_readings())
		return
	var h: Dictionary = st.hit
	if h.is_empty() or not Js.truthy(h.get("ok")):
		verdict_label.text = "Calculando el golpe…"
		Ui.set_color(verdict_label, "dim")
		vsub.text = ""
		band_text.text = ""
		return
	verdict_label.text = headline(String(h.verdict))
	Ui.set_color(verdict_label, st.impact_color())
	vsub.text = nb(String(h.vsub))
	band_text.text = nb(st.impact_band_text())
	_fill_tiles(impact_tiles, st.impact_readings())
	var L: Array = st.layers_view()
	for i in layer_chips.size():
		var chip: Array = layer_chips[i]
		(chip[0] as Control).visible = i < L.size()
		if i >= L.size():
			continue
		var l: Dictionary = L[i]
		(chip[1] as ColorRect).color = Palette.color(String(l.col))
		(chip[2] as Label).text = "%s · %s" % [l.name, l.state]
		Ui.set_color(chip[2], "coral" if l.state == "atravesada" else ("gold" if l.state == "rayada" else "dimmer"))
	energy.set_terms(st.energy_terms(), "Total: %s respecto al coche" % MovingCar.fmt_energy(h.energy.totalJ))
	_fill_grid(impact_report, h.report)
	_fill_sources()


## El porqué del veredicto, el «¿sabías que…?» y la moraleja (textos del estado; ocultos si no hay). why_only: solo el
## porqué (en cada fotograma de un deslizador; los datos cuestan ~0,2 ms y se ponen al soltarlo).
func _paint_learn(why_only := false) -> void:
	var why := st.why_text()
	why_label.visible = why != ""
	why_label.text = nb("¿Por qué? " + why) if why != "" else ""
	if why_only:
		return
	_paint_fact()
	var m := st.moral()
	moral_label.visible = m != ""
	moral_label.text = nb("Moraleja: " + m) if m != "" else ""


## El dato de ahora (fact_index, que pasa al siguiente con «Otro dato»), con su calidad y su fuente.
func _paint_fact() -> void:
	var fs: Array = st.facts()
	fact_box.visible = not fs.is_empty()
	if fs.is_empty():
		return
	var f: Dictionary = fs[fact_index % fs.size()]
	fact_text.text = nb(String(f.text))
	var q: String = f.quality
	fact_source.text = ("%s. Fuente: %s" % [MovingCarState.quality_title(q), f.source]) if q != "" else ("Fuente: %s" % f.source)
	Ui.set_color(fact_source, QUALITY_COLOR.get(q, "dimmer"))
	fact_next.visible = fs.size() > 1


func _chart_note() -> String:
	var d: Dictionary = st.det
	if not d.is_empty() and d.get("holdFromKmh") != null:
		return MovingCarState.det_words(d)
	if d.is_empty() or not d.atRest:
		return ""
	if d.never:
		return "no se suelta ni a %s" % MovingCarState.fmt_kmh(MovingCarState.BAND_MAX_KMH)
	if d.beyond:
		return "se soltaría hacia ~%s" % MovingCarState.fmt_kmh(d.kmh)
	return ""


static func _wind_txt(w: float) -> String:
	if w == 0.0:
		return "sin viento"
	return "%s de %s" % [MovingCarState.fmt_kmh(absf(w)), "frente" if w > 0.0 else "cola"]


## El rótulo del veredicto va en la letra de los titulares (Syne), cuya virgulilla, a este tamaño, es un guion corto
## («DESPEGA A -24 km/h»): el «~» de MovingCar se dice con palabras, «DESPEGA A UNOS 24 km/h». El número no cambia.
static func headline(verdict: String) -> String:
	return nb(verdict.replace("~", "UNOS "))


## Unidades con barra de los textos del coche en marcha (la más larga primero: «m/s²» antes que «m/s»).
const _SLASH_UNITS := ["km/h", "kg/m³", "kg/m²", "m/s²", "m/s", "N/mm", "N/cm²"]
## El espacio entre un número y su unidad sin barra («22 N», «11.7 kJ», «101 HV», «2000 m», «24 %»), si la unidad no
## sigue con otra letra («2 garras» no es una unidad). Se crea al cargar el script y no cambia.
static var _num_unit := RegEx.create_from_string(
	"(?<=[0-9]) (?=(?:k?N|[kM]?J|[mcµμ]?m|HV|[MG]Pa|kg|g|k?W|°C|%|ms|s)(?![A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9²³]))")


## Un texto de párrafo que no se parte dentro de una unidad ni entre el número y su unidad: el ajuste por palabras corta
## tras la barra («ni a 400 km/» y «h, el tope…» en el renglón siguiente) y en el espacio de «22 N». Pega la unidad a
## su número con un espacio duro (U+00A0) y su barra a lo que sigue con una unión de palabras (U+2060, sin ancho ni
## glifo): se lee igual.
static func nb(s: String) -> String:
	for u: String in _SLASH_UNITS:
		if s.contains(u):
			var glued: String = u.replace("/", "/\u2060")
			s = s.replace(" " + u, "\u00a0" + glued).replace(u, glued)
	return _num_unit.sub(s, "\u00a0", true)


func _fill_tiles(pool: Array, rows: Array) -> void:
	for i in pool.size():
		var t: Array = pool[i]
		var panel: Control = t[0]
		panel.visible = i < rows.size()
		if not panel.visible:
			continue
		var r: Dictionary = rows[i]
		(t[1] as Label).text = String(r.label)
		(t[2] as Label).text = nb(String(r.value))
		(t[3] as Label).text = nb(String(r.sub))
		var q: String = r.quality
		(t[4] as Label).visible = q != ""
		(t[4] as Label).text = MovingCarState.QUALITY_TEXT.get(q, "")
		Ui.set_color(t[4], QUALITY_COLOR.get(q, "dimmer"))
		panel.tooltip_text = ("Fuente: " + String(r.source)) if String(r.source) != "" else ""


## Filas [etiqueta, valor] en una rejilla de dos columnas (crece si hace falta; las que sobran se ocultan).
func _fill_grid(grid: GridContainer, rows: Array) -> void:
	while grid.get_child_count() < rows.size() * 2:
		var l := Ui.label("", "Cell")
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(l)
	for i in grid.get_child_count():
		var l: Label = grid.get_child(i)
		var row := i / 2
		l.visible = row < rows.size()
		if not l.visible:
			continue
		var is_key := i % 2 == 0
		l.text = String(rows[row][0]) if is_key else nb(String(rows[row][1]))
		Ui.set_color(l, "dimmer" if is_key else "text")
		if not is_key:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.x = 60.0
		else:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 90.0 if compact else 150.0


func _fill_sources() -> void:
	var rows: Array = st.sources()
	sources_summary.text = nb(st.sources_summary(rows))
	while sources_rows.size() < rows.size():
		var box := Ui.vbox(1)
		var head := Ui.para("", "Cell")
		box.add_child(head)
		var src := Ui.para("", "Small")
		box.add_child(src)
		sources_list.add_child(box)
		sources_rows.append([box, head, src])
	for i in sources_rows.size():
		var it: Array = sources_rows[i]
		(it[0] as Control).visible = i < rows.size()
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		var q: String = r.quality
		var tag := (" · " + String(MovingCarState.QUALITY_TEXT[q])) if q != "" else ""
		(it[1] as Label).text = nb("%s: %s%s" % [r.label, r.value, tag])
		Ui.set_color(it[1], QUALITY_COLOR.get(q, "dim"))
		(it[2] as Label).text = "Fuente: %s" % r.source


# ════════ La banda del despegue ════════

## La banda de la velocidad de despegue sobre un eje de 0 a 400 km/h (el tope de la búsqueda de MovingCar), con el
## recorrido del deslizador (0-230) marcado, el valor central y la velocidad del coche.
func _draw_band() -> void:
	var d: Dictionary = st.det if st != null else {}
	if d.is_empty():
		return
	var c := band_bar
	var w := c.size.x
	var top := 4.0
	var h := 12.0
	var font := get_theme_default_font()
	var xmax := MovingCarState.BAND_MAX_KMH
	var x_of := func(v: float) -> float: return clampf(v / xmax, 0.0, 1.0) * w
	c.draw_rect(Rect2(0, top, w, h), Palette.color("panel3"))
	c.draw_rect(Rect2(0, top, x_of.call(st.slider_max_kmh()), h), Palette.color("line2"))
	var lo: float = d.minKmh
	var hi: float = d.maxKmh
	var x0: float = x_of.call(maxf(lo, 0.0))
	var x1: float = w if is_inf(hi) else x_of.call(hi)
	c.draw_rect(Rect2(x0, top, maxf(x1 - x0, 3.0), h), Color(Palette.color("gold"), 0.45))
	if is_inf(hi):
		# con todo a favor no se suelta ni al tope de la búsqueda: la banda sigue más allá
		_tri_inf[0] = Vector2(w - 8.0, top)
		_tri_inf[1] = Vector2(w, top + h / 2.0)
		_tri_inf[2] = Vector2(w - 8.0, top + h)
		c.draw_colored_polygon(_tri_inf, Palette.color("gold"))
	if d.atRest and is_finite(float(d.kmh)):
		var xc: float = x_of.call(d.kmh)
		c.draw_rect(Rect2(xc - 1.5, top - 3.0, 3.0, h + 6.0), Palette.color("gold"))
	elif d.get("holdFromKmh") != null:
		# solo aguanta en una ventana: marca dónde empieza (y dónde acaba, si se suelta antes del tope)
		for e: Variant in [d.holdFromKmh, d.holdToKmh]:
			if is_finite(float(e)):
				var xe: float = x_of.call(float(e))
				c.draw_rect(Rect2(xe - 1.5, top - 3.0, 3.0, h + 6.0), Palette.color("gold"))
	var xv: float = x_of.call(st.v_kmh)
	_tri_v[0] = Vector2(xv, top + h + 1.0)
	_tri_v[1] = Vector2(xv - 5.0, top + h + 8.0)
	_tri_v[2] = Vector2(xv + 5.0, top + h + 8.0)
	c.draw_colored_polygon(_tri_v, Palette.color("rose"))
	var dim := Palette.color("dimmer")
	c.draw_string(font, Vector2(0, top + h + 16.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
	var vmax: float = st.slider_max_kmh()
	var xs: float = x_of.call(vmax)
	c.draw_string(font, Vector2(xs - 20.0, top + h + 16.0), MovingCarState.num(vmax), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10, dim)
	c.draw_string(font, Vector2(w - 90.0, top + h + 16.0), MovingCarState.fmt_kmh(xmax), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 10, dim)


# ════════ Deslizadores ════════

## Pone el recorrido y el valor de un deslizador sin emitir value_changed (MillPage.set_slider). Dentro del árbol,
## Godot recorta el valor al nuevo recorrido y lo emite: sin bloquear las señales, un recorte cambiaría el ensayo a
## mitad del refresco.
static func set_slider(s: HSlider, lo: float, hi: float, value: float) -> void:
	s.set_block_signals(true)
	s.min_value = lo
	s.max_value = maxf(hi, lo)
	s.value = value
	s.set_block_signals(false)


# ════════ Curvas (unidad 4t) ════════

## La carretera, bajo la velocidad: recta, curva o curva en S; el radio (escala logarítmica, con los radios mínimos de la
## norma marcados bajo la pista y en píldoras) y la frase de la curva a esa velocidad. Solo con el animal quieto encima.
func _build_road() -> void:
	road_box = Ui.vbox(8)
	road_seg = Segmented.new(CarCurve.ROADS.map(func(r: Dictionary) -> Dictionary: return { "id": r.id, "label": r.name, "title": r.title }),
		CarCurve.ROAD_STRAIGHT, "Carretera")
	road_box.add_child(road_seg)
	view_seg = Segmented.new([
		{ "id": "persecucion", "label": "Persecución", "title": "La cámara va detrás del coche por la carretera: se ve girar y curvarse la carretera" },
		{ "id": "lado", "label": "De lado", "title": "La vista de siempre, de perfil: para ver de cerca las garras y las marcas" },
	], "persecucion", "Vista en curva")
	road_box.add_child(view_seg)
	# sin la pista «(escala log)»: con el radio y su velocidad de proyecto, la cabecera no cabría en un teléfono
	radius = ValueSlider.new("Radio de la curva", "", 0.0, 1.0, 0.001)
	radius.slider.tooltip_text = "Escala logarítmica, de la glorieta (15 m) al radio mínimo de 140 km/h (1050 m); al lado, la velocidad de proyecto de la norma 3.1-IC"
	road_box.add_child(radius)
	radius_marks = ForceMarks.new(radius.slider)
	radius.slider.add_child(radius_marks)
	preset_flow = Ui.flow(6, 6)
	for e: Dictionary in CarCurve.PRESETS:
		var p := Pill.new("%s · %s" % [String(e.name), CarCurve.r_txt(float(e.r_m))])
		p.tooltip_text = "%s: %s" % [MovingCarState.QUALITY_TEXT.get(String(e.quality), ""), String(e.source)]
		preset_flow.add_child(p)
		preset_pills[e.id] = p
	road_box.add_child(preset_flow)
	curve_label = Ui.para("", "Body")
	Ui.set_color(curve_label, "ice")
	road_box.add_child(curve_label)
	main_box.add_child(road_box)


func _connect_road() -> void:
	road_seg.selected.connect(func(id: String) -> void: _pick(func() -> void: st.set_road(id)))
	view_seg.selected.connect(func(id: String) -> void:  # (4x): en la recta, la persecución de la recta
		view_seg.set_value(id)
		if st.road == CarCurve.ROAD_STRAIGHT:
			view.set_chase_straight(id == "persecucion")
		else:
			view.set_chase_pref(id == "persecucion"))
	radius.value_changed.connect(func(u: float) -> void: st.set_radius(CarCurve.radius_at(u)))
	for e: Dictionary in CarCurve.PRESETS:
		var r := float(e.r_m)
		(preset_pills[e.id] as Button).pressed.connect(func() -> void:
			_pick(func() -> void: st.set_radius(r))
			_paint_road())  # ya elegida, el estado no cambia: solo hay que volver a marcarla


## La carretera elegida, el radio y la frase de la curva (al cambiar la selección o la velocidad).
func _paint_road() -> void:
	var hold := st.mode == MovingCarState.MODE_HOLD and st.supports_hold()
	# en el golpe también: el camino del animal se tuerce en la curva (la S es del animal quieto encima)
	road_box.visible = st.supported()
	if not road_box.visible:
		return
	var s_button: Button = road_seg.buttons[CarCurve.ROAD_S]
	s_button.disabled = not hold
	s_button.tooltip_text = String(CarCurve.ROADS[2].title) if hold else "En el golpe, la curva: la S es para el animal quieto encima, que cambia de lado"
	road_seg.set_value(st.road)
	var curved: bool = st.road != CarCurve.ROAD_STRAIGHT
	radius.visible = curved
	view_seg.visible = curved or hold  # (4x): también en la recta
	view_seg.set_value("persecucion" if (view.chase_pref if curved else view.chase_straight) else "lado")  # (4x)
	preset_flow.visible = curved
	curve_label.visible = curved
	if not curved:
		return
	set_slider(radius.slider, 0.0, 1.0, CarCurve.slider_u(st.radius_m))
	radius.display.text = st.radius_text()
	radius.slider.accessibility_description = st.radius_text()
	var gold := Palette.color("gold")
	radius_marks.set_marks(CarCurve.PRESETS.map(func(e: Dictionary) -> Array: return [CarCurve.slider_u(float(e.r_m)), gold]))
	for e: Dictionary in CarCurve.PRESETS:
		(preset_pills[e.id] as Pill).set_on(float(e.r_m) == st.radius_m)
	curve_label.text = nb(st.curve_text() if hold else st.impact_curve_text())


# ════════ Luz del sol (unidad 4w) ════════

## La luz de la escena (dibujo): la de siempre por defecto o un sol (CarScene.LIGHTS), y con un sol, su rumbo para mover los
## reflejos por la carrocería y las garras.
var light_seg: Segmented
var sun_turn: ValueSlider
var _light_box: VBoxContainer


func _build_light() -> void:
	_light_box = Ui.vbox(6)
	var row := Ui.flow()
	row.add_child(Ui.sub_label("Luz"))
	light_seg = Segmented.new(CarScene.LIGHTS.map(func(l: Dictionary) -> Dictionary: return { "id": l.id, "label": l.name, "title": l.title }),
		CarScene.LIGHT_DEFAULT, "Luz")
	row.add_child(light_seg)
	_light_box.add_child(row)
	sun_turn = ValueSlider.new("Rumbo del sol", "", -CarScene.SUN_TURN_MAX, CarScene.SUN_TURN_MAX, 1.0)
	sun_turn.slider.tooltip_text = "Gira el sol alrededor del coche para mover los reflejos por la chapa, los vidrios y las garras (dibujo)"
	sun_turn.visible = false
	_light_box.add_child(sun_turn)
	main_box.add_child(_light_box)
	main_box.move_child(_light_box, view.get_parent().get_index() + 1)
	_paint_light()
	_build_scenery()  # unidad 4x


func _connect_light() -> void:
	light_seg.selected.connect(func(id: String) -> void:
		view.set_light(id, view.sun_turn)
		_paint_light())
	sun_turn.value_changed.connect(func(v: float) -> void:
		view.set_light(view.light_pref, v)
		_paint_light())


## La luz elegida y el rumbo (solo con un sol).
func _paint_light() -> void:
	light_seg.set_value(view.light_pref)
	var sun := view.light_pref != CarScene.LIGHT_DEFAULT
	sun_turn.visible = sun
	if sun:
		var txt := "%s°" % Js.js_num_str(Js.js_round(view.sun_turn))
		sun_turn.set_value(view.sun_turn, txt, txt)


## En el teléfono, los rótulos cortos de la luz y su fila sin el «Luz» de delante (los tres caben); el nombre entero, en la
## ayuda de cada botón.
func _compact_light() -> void:
	if light_seg == null:
		return
	for l: Dictionary in CarScene.LIGHTS:
		var b: Button = light_seg.buttons[l.id]
		b.text = String(l.get("short", l.name)) if compact else String(l.name)
		b.custom_minimum_size.y = TOUCH if compact else 0.0
	sun_turn.slider.custom_minimum_size.y = TOUCH if compact else 24.0


# ════════ Paisaje (unidad 4x) ════════

## El fondo de la persecución: el campo con árboles y montañas (por defecto) o el liso de siempre.
var scenery_seg: Segmented


func _build_scenery() -> void:
	var row := Ui.flow()
	row.add_child(Ui.sub_label("Fondo"))
	scenery_seg = Segmented.new([
		{ "id": "campo", "label": "Campo", "title": "Con la cámara de persecución, el campo verde con árboles y montañas de fondo (dibujo)" },
		{ "id": "liso", "label": "Liso", "title": "El fondo liso de siempre, sin paisaje (para ver los daños o en un teléfono lento)" },
	], "campo", "Fondo")
	row.add_child(scenery_seg)
	_light_box.add_child(row)
	scenery_seg.selected.connect(func(id: String) -> void: view.set_scenery(id == "campo"))
