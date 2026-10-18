## Demo guionizada de la tarjeta «Coche en marcha» (unidad 4c) para las capturas: la sección del laboratorio entera y
## nueve escenas, pulsando los controles de la tarjeta como una persona (los deslizadores se arrastran; los experimentos
## se cargan con su botón):
##   1 · águila con las alas plegadas en el techo, acelerando de 0 a 230 km/h: se suelta hacia los 196 (con su banda);
##   2 · los experimentos «¿Aguanta el águila a 120 km/h?» y «El mismo, a 35 °C y a 2000 m»: el aire menos denso mueve
##       la gráfica y la banda;
##   3 · oso de pie en el techo con una frenada de emergencia: al bajar la velocidad, lo tira la frenada;
##   4 · la lechuza asustada: desgarra la pintura y aguanta más;
##   5 · tigre que se abalanza sobre la puerta: abolladura, surcos y balance de energía;
##   6 · el mismo con garras de zafiro: raja la chapa, pero se mellan;
##   7 · la patada del casuario hembra;
##   8 · el águila con talones de tungsteno clavados en el techo: no se suelta;
##   9 · águila con las alas abiertas que despega.
## Y tres más para revisar el dibujo, solo con --caso: 10 · tigre que cae sobre el parabrisas (grietas en estrella);
## 11 · águila que persigue al coche y se posa en el techo (surcos; sale volando); 12 · tigre contra la aleta de plástico
## (la perfora). Y los velocirraptores (unidad 4i-B2), también solo con --caso: 13 · el experimento «El velocirraptor de
## cine» (salta sobre el capó y lo raja: ficción); 14 · «Y el de verdad, en el mismo salto» (abolla y raya). Y la ventanilla
## templada (unidad 4m), solo con --caso: 15 · «La garra de diamante contra la ventanilla» (estalla por una grieta, con
## poca fuerza); 16 · «Y con sus talones de queratina» (aguanta); 17 · el oso contra la ventanilla (estalla al flexar).
## Y los de la unidad 4r (los animales de la cetrería en el coche y el deportivo), también solo con --caso: 18 · el oso y el
## tigre en el techo, agazapados y de pie; 19 · el águila y el búho en el techo; 20 · los dos velocirraptores en el techo;
## 21 · el deportivo a más de 230 km/h con el oso de pie en el techo; 22 · el coste de cada animal (quieto en el techo a
## 120 km/h: lo que tarda en construirse y, por fotograma, el dibujo en el hilo principal y lo que dibuja el render; lo
## escribe en la salida; mejor sin Movie Maker, que graba cada fotograma); 23 · el tigre de pie en el techo con garras de
## acero y el oso con garras de oro (los metales reflejan la carretera: unidad 5q).
## Captura:   node godot/tools/godot.mjs capture res://app/lab/demo_coche.tscn --frames=660 --out=<carpeta> (~22 s a 30 fps)
## Teléfono:  … con --phone (el proyecto va a 390 × 844: una columna).
## Un caso:   … -- --caso=4 (y más fotogramas: cada escena dura lo suyo).
## El tiempo es la suma de los delta (Movie Maker los da fijos), así que cada captura sale igual. No guarda ajustes. Al
## final escribe en la salida el coste de la tarjeta por fotograma (el refresco en el hilo principal) y lo que tarda
## impact() en su hilo.
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const Catalog = preload("res://core/lab/catalog.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")

const SCENES := [
	"Águila con las alas plegadas en el techo: de 0 a 230 km/h",
	"Experimentos: el águila a 120 km/h, y a 35 °C y 2000 m",
	"Oso de pie en el techo con una frenada de emergencia",
	"Experimento: la lechuza, asustada",
	"Experimento: el tigre contra la puerta",
	"Experimento: el tigre con garras de zafiro",
	"Experimento: la patada del casuario hembra",
	"Experimento: el águila con talones de tungsteno",
	"Águila con las alas abiertas: despega",
	"Tigre que cae sobre el parabrisas",
	"Águila que persigue al coche y se posa en el techo",
	"Tigre contra la aleta de plástico",
	"Experimento: el velocirraptor de cine salta sobre el capó",
	"Experimento: y el de verdad, en el mismo salto",
	"Experimento: la garra de diamante contra la ventanilla",
	"Experimento: y con sus talones de queratina",
	"Oso contra la ventanilla",
	"El oso y el tigre en el techo, agazapados y de pie",
	"El águila y el búho en el techo",
	"Los dos velocirraptores en el techo",
	"El deportivo a más de 230 km/h con el oso de pie en el techo",
	"Rendimiento: cada animal quieto en el techo a 120 km/h",
	"El tigre con garras de acero y el oso con garras de oro en el techo",
	"Las garras de cerca: el tigre con garras de acero en el techo, de 60 a 200 km/h",
	"Hoja comparativa: el tigre en el techo con cinco materiales de garra, a 60 y a 200 km/h",
	"Las marcas de cerca: arañazo, punzada, abolladura y pintura saltada",
	"Una garra rota: el tigre con garras de vidrio en el techo a 200 km/h",
	"Las garras en curva: el tigre con garras de acero en la curva en S, con la ventana y de cerca",
	"El oso y el velocirraptor contra el techo y la puerta: qué capas atraviesan y si rajan o abren",
	"De cerca: la marca en la chapa, las garras de cada animal, una gema, una garra mellada y la abolladura",
	"Luz del sol: el oso con garras de diamante en el techo con cada luz, el coche entero y de cerca",
	"Luz del sol: la curva con el sol bajo, los reflejos corren por la chapa y las garras",
	"Luz del sol: cada material de garra del oso con cada luz (revisión de los materiales)",
	"Luz del sol: cada coche con cada luz (revisión de los materiales del coche)",
	"Paisaje: la persecución en la recta, con la luz de siempre y con el sol bajo",
	"Paisaje: la persecución en la curva, con la luz de siempre y con el sol bajo",
	"Paisaje: la persecución en la curva en S, con la luz de siempre y con el sol bajo",
	"Paisaje: la carretera sin fin a 120 km/h en la persecución",
]
## Unidad 4s: los materiales y las velocidades del coche de la hoja comparativa (caso 25) y lo que dura cada foto (s).
const SHEET_MATERIALS := ["none", "oro", "acero", "zafiro", "diamante"]
const SHEET_SPEEDS := [60.0, 200.0]
const SHEET_STEP_S := 1.2

## Los animales que se miden en el caso del rendimiento (todos los que se quedan encima del coche).
const PERF_ANIMALS := ["oso", "tigre", "aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "velociraptor_pelicula", "velociraptor"]
## Lo que se espera a que se asiente cada animal y lo que se mide después (s).
const PERF_SETTLE_S := 0.8
const PERF_SAMPLE_S := 1.6
## Escenas de la demo completa (las demás, solo con --caso).
const MAIN_SCENES := 9

var lab: Control  # la sección del laboratorio
var card: Control  # la tarjeta del coche en marcha
var caption: Label
var _t := 0.0
var _queue: Array = []  # [instante (s), Callable], por orden
var _drags: Array = []  # [{ slider, from, to, t0, dur, started }]
var _only := -1
var _paint_max := 0
var _paint_sum := 0
var _paint_n := 0
var _impact_us := 0
## El caso del rendimiento: el animal que se mide, si se está midiendo, y lo medido de cada fotograma.
var _perf_id := ""
var _perf_on := false
var _perf := {}
var _perf_last_us := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	lab.set_page(lab.PAGE_CAR, false)  # el coche en marcha tiene su propia página en la sección
	card = lab.moving_car_card
	_build_caption()
	var t := 0.3
	var order := range(MAIN_SCENES) if _only < 0 else [_only]
	for i: int in order:
		t = call("_scene_%d" % (i + 1), t)
	_at(t, _report)


func _build_caption() -> void:
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Coche en marcha", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 70.0, 560.0)
	pill.add_child(caption)
	add_child(pill)
	pill.position = Vector2(14, vs.y - 78.0) if vs.x < 600.0 else Vector2(16, vs.y - 62.0)


func _process(delta: float) -> void:
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
	for d: Dictionary in _drags.duplicate():
		var s: HSlider = d.slider
		if not d.started:
			d.started = true
			s.drag_started.emit()
		var k := clampf((_t - float(d.t0)) / float(d.dur), 0.0, 1.0)
		s.value = lerpf(d.from, d.to, k)
		if k >= 1.0:
			s.drag_ended.emit(true)
			_drags.erase(d)
	if card.paints > 0:
		_paint_max = maxi(_paint_max, card.last_paint_us)
		_paint_sum += card.last_paint_us
		_paint_n += 1
	if card.st != null and card.st.last_heavy_us > 0 and card.st.mode == "impact":
		_impact_us = card.st.last_heavy_us
	if _perf_on:
		_perf_sample()



func _at(t: float, fn: Callable) -> void:
	_queue.append([t, fn])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## Arrastra un deslizador de la tarjeta de from a to en dur segundos, desde t.
func _drag(t: float, slider: HSlider, from: float, to: float, dur: float) -> void:
	_at(t, func() -> void: _drags.append({ "slider": slider, "from": from, "to": to, "t0": t, "dur": dur, "started": false }))


func _caption(i: int) -> void:
	caption.text = "%s · %s" % [Ui.num(i + 1), SCENES[i]]


func _claw(id: String) -> void:
	lab.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, id))
	lab.refresh_now()


func _press(b: BaseButton) -> void:
	if b.is_visible_in_tree():
		b.pressed.emit()


func _slide(slider: HSlider, v: float) -> void:
	slider.value = v


func _scroll(c: Control) -> void:
	lab.scroll_to(c, 8.0)


func _scene_1(t: float) -> float:
	_at(t, _caption.bind(0))
	_at(t, _claw.bind("aguila"))
	_at(t + 0.05, func() -> void: _press(card.car_pills["coche"]))
	_at(t + 0.05, func() -> void: _press(card.zone_pills["techo"]))
	_at(t + 0.05, func() -> void: _press(card.bird_seg.buttons["plegadas"]))
	_at(t + 0.1, _slide.bind(card.speed.slider, 0.0))
	_at(t + 0.1, _scroll.bind(card.view))
	_drag(t + 0.4, card.speed.slider, 0.0, 230.0, 2.4)
	return t + 3.6  # hacia los 196 km/h se suelta: da tiempo a ver cómo sale despedida


## Con una herramienta sin datos (una escena suelta, con --caso) la tarjeta no enseña sus botones: primero, el águila.
func _ensure_card() -> void:
	if not card.main_box.visible:
		_claw("aguila")


## Un experimento de un clic: se pulsa su botón (arriba de la tarjeta), se mira el dibujo y, después, lo que se quiera.
func _experiment(t: float, i: int, id: String, then: Control = null, then_at := 1.6, dur := 2.4) -> float:
	_at(t, _caption.bind(i))
	_at(t, _ensure_card)
	_at(t, _scroll.bind(card.experiment_pills[id]))
	_at(t + 0.25, func() -> void: _press(card.experiment_pills[id]))
	_at(t + 0.45, _scroll.bind(card.view))
	if then != null:
		_at(t + then_at, _scroll.bind(then))
	return t + dur


func _scene_2(t: float) -> float:
	# «¿aguanta el águila a 120 km/h?» y el mismo experimento con el aire de montaña: la gráfica y la banda se mueven
	_at(t, _caption.bind(1))
	_at(t, _ensure_card)
	_at(t + 0.1, _scroll.bind(card.experiment_pills["aguila_120"]))
	_at(t + 0.3, func() -> void: _press(card.experiment_pills["aguila_120"]))
	_at(t + 0.9, func() -> void: _press(card.experiment_pills["aire"]))
	_at(t + 1.1, _scroll.bind(card.verdict_box))
	return t + 2.1


func _scene_3(t: float) -> float:
	_at(t, _caption.bind(2))
	_at(t, _slide.bind(card.temp.slider, 20.0))
	_at(t, _slide.bind(card.altitude.slider, 0.0))
	_at(t + 0.05, _claw.bind("oso"))
	_at(t + 0.1, func() -> void: _press(card.mammal_seg.buttons["de_pie"]))
	_at(t + 0.1, _slide.bind(card.speed.slider, 90.0))
	_at(t + 0.1, _scroll.bind(card.view))
	_at(t + 0.3, func() -> void: _press(card.maneuver_pills["emergencia"]))
	_drag(t + 0.45, card.speed.slider, 90.0, 0.0, 1.2)
	return t + 1.9


func _scene_4(t: float) -> float:
	return _experiment(t, 3, "lechuza_asustada", card.verdict_box, 1.2, 2.2)


func _scene_5(t: float) -> float:
	return _experiment(t, 4, "tigre_puerta", card.energy, 2.2, 2.8)


func _scene_6(t: float) -> float:
	return _experiment(t, 5, "tigre_zafiro", card.verdict_box, 2.2, 3.0)


func _scene_7(t: float) -> float:
	return _experiment(t, 6, "casuario_puerta", card.verdict_box, 2.0, 2.8)


func _scene_8(t: float) -> float:
	return _experiment(t, 7, "aguila_tungsteno", card.verdict_box, 1.2, 2.0)


func _scene_9(t: float) -> float:
	_at(t, _caption.bind(8))
	_at(t, _claw.bind("aguila"))
	_at(t + 0.05, func() -> void: _press(card.mode_seg.buttons["hold"]))
	_at(t + 0.1, func() -> void: _press(card.zone_pills["techo"]))
	_at(t + 0.1, func() -> void: _press(card.bird_seg.buttons["abiertas"]))
	_at(t + 0.1, func() -> void: _press(card.inlay_pills["none"]))  # queratina: deja de estar clavada
	_at(t + 0.1, _slide.bind(card.speed.slider, 0.0))
	_at(t + 0.15, _scroll.bind(card.view))
	_drag(t + 0.35, card.speed.slider, 0.0, 40.0, 0.6)
	return t + 1.2


## Un golpe de revisión: animal, zona, velocidades, ángulo y caída; se mira el dibujo y después el informe.
func _impact_scene(t: float, i: int, claw: String, car: String, zone: String, v: float, va: float, angle_deg: float, drop: float) -> float:
	_at(t, _caption.bind(i))
	_at(t, _claw.bind(claw))
	_at(t + 0.05, func() -> void:
		card.car_pills[car].pressed.emit()
		card.inlay_pills["none"].pressed.emit()
		if card.st.defense:
			card.defense_pill.pressed.emit())
	_at(t + 0.1, _slide.bind(card.speed.slider, v))
	_at(t + 0.1, _slide.bind(card.animal_speed.slider, va))
	_at(t + 0.1, _slide.bind(card.angle.slider, angle_deg))
	_at(t + 0.1, _slide.bind(card.drop.slider, drop))
	_at(t + 0.15, func() -> void:
		_press(card.mode_seg.buttons["impact"])
		card.izone_pills[zone].pressed.emit())
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 3.4, _scroll.bind(card.verdict_box))
	return t + 4.5


func _scene_10(t: float) -> float:
	return _impact_scene(t, 9, "tigre", "coche", "parabrisas", 50.0, 40.0, 90.0, 0.5)


func _scene_11(t: float) -> float:
	return _impact_scene(t, 10, "aguila", "coche", "techo", 90.0, 60.0, 0.0, 0.2)


func _scene_12(t: float) -> float:
	return _impact_scene(t, 11, "tigre", "cocheplastico", "aleta", 50.0, 40.0, 90.0, 0.0)


func _scene_13(t: float) -> float:
	return _experiment(t, 12, "velocirraptor_pelicula", card.verdict_box, 2.2, 3.2)


func _scene_14(t: float) -> float:
	return _experiment(t, 13, "velocirraptor_real", card.verdict_box, 2.2, 3.2)


## Unidad 4m: la ventanilla templada. Con garras de diamante estalla con poca fuerza (una grieta que atraviesa la capa
## comprimida); con queratina, el mismo golpe la deja entera; el oso la revienta al flexarla.
func _scene_15(t: float) -> float:
	return _experiment(t, 14, "ventanilla_diamante", card.verdict_box, 2.2, 3.2)


func _scene_16(t: float) -> float:
	return _experiment(t, 15, "ventanilla_queratina", card.verdict_box, 2.2, 3.2)


func _scene_17(t: float) -> float:
	return _impact_scene(t, 16, "oso", "coche", "luna", 50.0, 10.0, 90.0, 0.0)


## Unidad 4r: un animal quieto encima, en su zona, su postura y a su velocidad (sin maniobra ni garras reforjadas).
func _hold(claw: String, zone: String, posture: String, v: float, car := "coche", inlay := "none") -> void:
	_claw(claw)
	if card.car_pills.has(car):
		card.car_pills[car].pressed.emit()
	card.st.set_maneuver("crucero")
	if card.st.inlay != inlay and card.inlay_pills.has(inlay):
		card.inlay_pills[inlay].pressed.emit()
	if card.st.defense:
		card.defense_pill.pressed.emit()
	_press(card.mode_seg.buttons["hold"])
	if card.zone_pills.has(zone):
		card.zone_pills[zone].pressed.emit()
	card.st.set_posture(posture)
	_slide(card.speed.slider, v)


## 18 · El oso y el tigre en el techo, agazapados y de pie (a 90 km/h: el viento les mueve el pelo).
func _scene_18(t: float) -> float:
	_at(t, _caption.bind(17))
	_at(t, _hold.bind("oso", "techo", "tumbado", 90.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.6, _hold.bind("oso", "techo", "de_pie", 90.0))
	_at(t + 3.2, _hold.bind("tigre", "techo", "tumbado", 90.0))
	_at(t + 4.8, _hold.bind("tigre", "techo", "de_pie", 90.0))
	return t + 6.4


## 19 · El águila con las alas plegadas en el techo y el búho en el techo.
func _scene_19(t: float) -> float:
	_at(t, _caption.bind(18))
	_at(t, _hold.bind("aguila", "techo", "plegadas", 120.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.8, _hold.bind("buho", "techo", "plegadas", 90.0))
	return t + 3.6


## 20 · Los dos velocirraptores agazapados en el techo.
func _scene_20(t: float) -> float:
	_at(t, _caption.bind(19))
	_at(t, _hold.bind("velociraptor_pelicula", "techo", "tumbado", 60.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.8, _hold.bind("velociraptor", "techo", "tumbado", 60.0))
	return t + 3.6


## 21 · El deportivo (si lo hay; antes de la unidad 4r, el turismo) con el oso de pie en el techo, acelerando hasta su tope.
func _scene_21(t: float) -> float:
	var car := "deportivo" if card.car_pills.has("deportivo") else "coche"
	_at(t, _caption.bind(20))
	_at(t, _hold.bind("oso", "techo", "de_pie", 200.0, car))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.4, card.speed.slider, 200.0, 300.0, 2.6)
	return t + 4.2


## 22 · El coste de cada animal quieto en el techo a 120 km/h (en la postura de por defecto): construirlo (la primera vez y,
## al volver, desde la caché) y, por fotograma, el dibujo del hilo principal (moving_car_view.gd, last_draw_us), el render
## del mundo 3D (su SubViewport: CPU y GPU), lo que dibuja (primitivas y llamadas) y el fotograma entero (el tiempo de reloj
## entre dos fotogramas, que solo es el coste con --fixed-fps y la sincronía vertical apagada, y el render de la ventana).
## Lo escribe en la salida.
func _scene_22(t: float) -> float:
	_at(t, _caption.bind(21))
	_at(t, _ensure_card)
	for id: String in PERF_ANIMALS:
		# cada paso en su instante, sin empates: la cola no conserva el orden de dos con el mismo instante
		_at(t + 0.05, _perf_start.bind(id))
		_at(t + 0.05 + PERF_SETTLE_S, _perf_measure)
		t += 0.05 + PERF_SETTLE_S + PERF_SAMPLE_S
		_at(t, _perf_end)
	return t + 0.2


func _perf_start(id: String) -> void:
	var vp: SubViewport = card.view.get("_vp")
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_perf_id = id
	_hold(id, "techo", "", 120.0)
	_scroll(card.view)
	_perf = { "draw": 0, "cpu": 0.0, "gpu": 0.0, "prims": 0, "calls": 0, "objs": 0, "n": 0, "build_us": -1, "verts": -1,
		"proc": 0.0, "wall_n": 0, "win_cpu": 0.0, "win_gpu": 0.0 }
	_perf_last_us = 0


func _perf_measure() -> void:
	var rig: Variant = card.view.get("_rig")
	if rig != null:
		_perf.build_us = int(rig.get("build_us"))
		_perf.verts = int(rig.get("verts"))
	_perf_on = true


func _perf_sample() -> void:
	var vp: SubViewport = card.view.get("_vp")
	var rid := vp.get_viewport_rid()
	_perf.draw += card.view.last_draw_us
	_perf.cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_perf.gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	_perf.prims += RenderingServer.viewport_get_render_info(rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	_perf.calls += RenderingServer.viewport_get_render_info(rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_perf.objs += RenderingServer.viewport_get_render_info(rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	# el fotograma entero: el tiempo de reloj entre dos fotogramas (sin la espera de la sincronía vertical, medido con
	# --fixed-fps y vsync apagado: lo que cuesta de verdad) y el render de la ventana (la tarjeta y la sección; ms)
	var win := get_viewport().get_viewport_rid()
	var now := Time.get_ticks_usec()
	if _perf_last_us > 0:
		_perf.proc += float(now - _perf_last_us) / 1000.0
		_perf.wall_n += 1
	_perf_last_us = now
	_perf.win_cpu += RenderingServer.viewport_get_measured_render_time_cpu(win)
	_perf.win_gpu += RenderingServer.viewport_get_measured_render_time_gpu(win)
	_perf.n += 1


func _perf_end() -> void:
	_perf_on = false
	var n := maxi(int(_perf.n), 1)
	print("demo_coche rendimiento %s (%s): construir %s ms · %s vértices · dibujo %s µs · render CPU %s ms · GPU %s ms · %s primitivas · %s llamadas · %s objetos (%d fotogramas) · fotograma: reloj %s ms, ventana CPU %s ms, GPU %s ms" % [
		_perf_id, String(card.view.quality), String.num(float(_perf.build_us) / 1000.0, 1), Ui.num(int(_perf.verts)), Ui.num(int(_perf.draw) / n),
		String.num(float(_perf.cpu) / n, 2), String.num(float(_perf.gpu) / n, 2), Ui.num(int(_perf.prims) / n), Ui.num(int(_perf.calls) / n),
		Ui.num(int(_perf.objs) / n), int(_perf.n), String.num(float(_perf.proc) / maxi(int(_perf.wall_n), 1), 2), String.num(float(_perf.win_cpu) / n, 2),
		String.num(float(_perf.win_gpu) / n, 2)])


## 23 · El tigre de pie en el techo con garras de acero y el oso agazapado con garras de oro (a 90 km/h): los metales de la
## biblioteca reflejan la carretera (unidad 5q), también en el coche.
func _scene_23(t: float) -> float:
	_at(t, _caption.bind(22))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 90.0, "coche", "acero"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.8, _hold.bind("oso", "techo", "tumbado", 90.0, "coche", "oro"))
	return t + 3.6


## Unidad 4s: la vista de la tarjeta («coche» o «garras»).
func _view(id: String) -> void:
	if card.zoom_seg.buttons.has(id):
		(card.zoom_seg.buttons[id] as Button).pressed.emit()


## Marca en la salida el fotograma de una foto (para sacar la hoja de la captura).
func _shot(label: String) -> void:
	print("demo_coche foto: %s · fotograma %d" % [label, Engine.get_frames_drawn()])



## 24 · El tigre de pie en el techo con garras de acero: primero el coche entero con la ventana de las garras; después, las
## garras de cerca en toda la vista mientras el coche acelera de 60 a 200 km/h (las marcas crecen), y con garras de diamante.
func _scene_24(t: float) -> float:
	_at(t, _caption.bind(23))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 60.0, "coche", "acero"))
	_at(t + 0.05, _view.bind("coche"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.3, _shot.bind("ventana de las garras, acero a 60 km/h"))
	_at(t + 1.4, _view.bind("garras"))
	_at(t + 1.5, _scroll.bind(card.view))
	_at(t + 2.4, _shot.bind("garras de cerca, acero a 60 km/h"))
	_drag(t + 2.5, card.speed.slider, 60.0, 200.0, 1.6)
	_at(t + 4.4, _shot.bind("garras de cerca, acero a 200 km/h"))
	_at(t + 4.5, func() -> void: card.inlay_pills["diamante"].pressed.emit())
	_at(t + 5.6, _shot.bind("garras de cerca, diamante a 200 km/h"))
	return t + 5.8


## 25 · La hoja comparativa (petición de Eric del 13-10): el mismo agarre del tigre de pie en el techo con garras de
## queratina, oro, acero, zafiro y diamante, a dos velocidades del coche, en primer plano (cada foto, marcada en la salida
## con _shot). Encima del coche, las garras que agarran son las que dejan las marcas, en el mismo sitio; en el golpe contra
## la puerta las marcas van al punto del golpe y las garras del dibujo del salto caen en otra parte (caso 26).
func _scene_25(t: float) -> float:
	_at(t, _caption.bind(24))
	_at(t, _view.bind("garras"))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 60.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	t += 0.3
	for v: float in SHEET_SPEEDS:
		for m: String in SHEET_MATERIALS:
			_at(t, _hold.bind("tigre", "techo", "de_pie", v, "coche", m))
			_at(t + 0.05, _scroll.bind(card.view))
			_at(t + SHEET_STEP_S - 0.1, _shot.bind("%s a %d km/h" % [m, int(v)]))
			t += SHEET_STEP_S
	return t + 0.2


## 26 · Las marcas de cerca: el tigre con garras de metal duro contra la puerta (arañazos que atraviesan, punzadas y la
## abolladura), el oso de pie en el techo a 200 km/h (pintura saltada hasta la imprimación) y las garras de diamante contra
## la ventanilla (grietas en el vidrio), en primer plano.
func _scene_26(t: float) -> float:
	_at(t, _caption.bind(25))
	_at(t, _view.bind("garras"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 200.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.4, _shot.bind("oso de queratina en el techo a 200 km/h"))
	_at(t + 1.5, _hold.bind("tigre", "techo", "de_pie", 160.0, "coche", "tungsteno"))
	_at(t + 1.7, _scroll.bind(card.view))
	_at(t + 2.9, _shot.bind("tigre de tungsteno en el techo a 160 km/h"))
	t = _impact_scene(t + 3.0, 25, "tigre", "coche", "puerta", 50.0, 40.0, 90.0, 0.0)
	_at(t - 4.4, func() -> void: card.inlay_pills["tungsteno"].pressed.emit())
	_at(t - 4.3, _view.bind("garras"))
	_at(t - 3.2, _shot.bind("tigre de tungsteno contra la puerta"))
	return _experiment(t, 25, "ventanilla_diamante", null, 1.6, 2.6)


## 27 · Una garra rota: el tigre de pie en el techo con garras de vidrio (strass) a 60 km/h y después a 200 km/h, cuando la
## fuerza del agarre las parte; en primer plano.
func _scene_27(t: float) -> float:
	_at(t, _caption.bind(26))
	_at(t, _view.bind("garras"))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 60.0, "coche", "vidrio"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.3, _shot.bind("vidrio a 60 km/h"))
	_drag(t + 1.4, card.speed.slider, 60.0, 220.0, 1.2)
	_at(t + 3.2, _shot.bind("vidrio a 220 km/h"))
	return t + 3.4


## 28 · Las garras en curva (la 4s con la 4t): el tigre de pie en el techo con garras de acero a 90 km/h en la curva en S,
## primero con el coche entero (la ventana de las garras, abajo; arriba, el medidor de fuerza G y el mapa) y después de cerca.
func _scene_28(t: float) -> float:
	_at(t, _caption.bind(27))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 90.0, "coche", "acero"))
	_at(t + 0.1, func() -> void:
		if card.road_seg.buttons.has("s"):
			(card.road_seg.buttons["s"] as Button).pressed.emit())
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.8, _shot.bind("curva en S, coche entero"))
	_at(t + 1.9, _view.bind("garras"))
	_at(t + 2.0, _scroll.bind(card.view))
	_at(t + 3.4, _shot.bind("curva en S, de cerca"))
	return t + 3.6


## 29 · El oso y el velocirraptor contra el techo y la puerta (petición de Eric del 17-10): el oso de pie en el techo de 60 a
## 200 km/h (marca la pintura, no la chapa), el oso contra la puerta (abolla y raya; no la abre), el velocirraptor en el techo y
## el de cine contra la puerta (ficción); cada uno con el corte de la chapa de la tarjeta y de cerca.
func _scene_29(t: float) -> float:
	_at(t, _caption.bind(28))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 60.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.5, card.speed.slider, 60.0, 200.0, 1.5)
	_at(t + 2.3, _shot.bind("oso en el techo a 200 km/h"))
	_at(t + 2.4, _scroll.bind(card.tear_cut))
	_at(t + 3.4, _shot.bind("oso en el techo: el corte de la chapa"))
	t = _impact_scene(t + 3.6, 28, "oso", "coche", "puerta", 50.0, 30.0, 90.0, 0.0)
	_at(t - 4.4, _view.bind("garras"))
	_at(t - 1.0, _scroll.bind(card.tear_cut))
	_at(t - 0.2, _shot.bind("oso contra la puerta: el corte de la chapa"))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("velociraptor", "techo", "tumbado", 60.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.6, _shot.bind("velocirraptor en el techo"))
	t = _impact_scene(t + 1.8, 28, "velociraptor_pelicula", "coche", "puerta", 50.0, 40.0, 90.0, 0.0)
	_at(t - 4.4, _view.bind("garras"))
	_at(t - 1.0, _scroll.bind(card.tear_cut))
	_at(t - 0.2, _shot.bind("velocirraptor de cine contra la puerta"))
	return t + 0.3


## 30 · La segunda ronda de la 4s, de cerca: la marca de una garra de queratina del oso (pintura hasta el anticorrosivo) y la de
## carburo de tungsteno del tigre (atraviesa la chapa); el águila (3 + 1) y el tigre (4 paralelas); unas garras de zafiro;
## la garra de vidrio mellada a 220 km/h; y la abolladura del oso contra la puerta.
func _scene_30(t: float) -> float:
	_at(t, _caption.bind(29))
	_at(t, _view.bind("marca"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 160.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.4, _shot.bind("marca de queratina del oso"))
	_at(t + 1.5, _hold.bind("tigre", "techo", "de_pie", 160.0, "coche", "tungsteno"))
	_at(t + 1.7, _scroll.bind(card.view))
	_at(t + 2.9, _shot.bind("marca de carburo de tungsteno del tigre"))
	_at(t + 3.0, _view.bind("garras"))
	_at(t + 3.0, _hold.bind("aguila", "techo", "plegadas", 120.0, "coche", "none"))
	_at(t + 3.2, _scroll.bind(card.view))
	_at(t + 4.4, _shot.bind("águila: 3 + 1"))
	_at(t + 4.5, _hold.bind("tigre", "techo", "de_pie", 90.0, "coche", "zafiro"))
	_at(t + 4.7, _scroll.bind(card.view))
	_at(t + 5.9, _shot.bind("garras de zafiro"))
	_at(t + 6.0, _hold.bind("tigre", "techo", "de_pie", 220.0, "coche", "vidrio"))
	_at(t + 6.2, _scroll.bind(card.view))
	_at(t + 7.4, _shot.bind("garra de vidrio mellada a 220 km/h"))
	t = _impact_scene(t + 7.5, 29, "oso", "coche", "puerta", 50.0, 30.0, 90.0, 0.0)
	_at(t - 4.4, _view.bind("garras"))
	_at(t - 3.5, _scroll.bind(card.view))
	_at(t - 1.3, _shot.bind("la abolladura del oso"))
	return t


## El coste de la tarjeta, en la salida de la captura.
func _report() -> void:
	print("demo_coche: refresco de la tarjeta %s µs de media por fotograma (máx. %s µs) en el hilo principal; impact() en su hilo, %s µs" % [
		Ui.num(_paint_sum / maxi(_paint_n, 1)), Ui.num(_paint_max), Ui.num(_impact_us)])
	caption.text = "Fin de la demo"


# ════════ Luz del sol (unidad 4w) ════════

## Pulsa la luz de la tarjeta (CarScene.LIGHTS) y, con un sol, deja el rumbo en turn grados.
func _light(id: String, turn := 0.0) -> void:
	if card.light_seg.buttons.has(id):
		(card.light_seg.buttons[id] as Button).pressed.emit()
	if card.sun_turn.visible:
		card.sun_turn.slider.value = turn


## 31 · El oso de pie en el techo con garras de diamante a 90 km/h con cada luz (la de siempre, el sol de mediodía y el sol
## bajo): el coche entero y, después, las garras de cerca con cada una.
func _scene_31(t: float) -> float:
	_at(t, _caption.bind(30))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 90.0, "coche", "diamante"))
	_at(t + 0.2, _scroll.bind(card.view))
	var k := 0
	for view: String in ["coche", "garras"]:
		for id: String in ["defecto", "mediodia", "bajo"]:
			var at := t + 0.4 + float(k) * 1.6
			if k == 3:
				_at(at - 0.1, _view.bind("garras"))
			_at(at, _light.bind(id))
			_at(at + 1.4, _shot.bind("luz %s · %s" % [id, view]))
			k += 1
	_at(t + 0.4 + float(k) * 1.6, _light.bind("defecto"))
	return t + 0.6 + float(k) * 1.6


## 32 · La curva con el sol bajo: el oso de pie en el techo con garras de diamante a 90 km/h en la curva, con la cámara de
## persecución (el sol se queda en el mundo: los reflejos corren por la chapa al girar) y luego de cerca.
func _scene_32(t: float) -> float:
	_at(t, _caption.bind(31))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 90.0, "coche", "diamante"))
	_at(t + 0.1, func() -> void:
		if card.road_seg.buttons.has("curva"):
			(card.road_seg.buttons["curva"] as Button).pressed.emit())
	_at(t + 0.15, _light.bind("bajo"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 4.0, _shot.bind("curva con el sol bajo"))
	_at(t + 4.2, _view.bind("garras"))
	_at(t + 7.0, _shot.bind("curva con el sol bajo, de cerca"))
	return t + 7.2


## Los materiales de garra del selector del coche, en el orden de la revisión de la 4w (metales, gemas y vidrios), y lo
## que dura cada foto (s: el selector recalcula el ensayo y la vista se recoloca).
const AUDIT_INLAYS := ["none", "oro", "acero", "titanio", "tungsteno", "hematites", "vidrio", "swarovski", "cuarzo", "circonita",
	"zafiro", "rubi", "alumina", "moissanita", "diamante"]
const AUDIT_STEP_S := 1.3


## 33 · La revisión de los materiales de la 4w: el oso de pie en el techo a 90 km/h con las garras de cerca, cada material
## de garra con cada luz. Una foto por combinación (las busca la hoja de contacto por el registro).
func _scene_33(t: float) -> float:
	_at(t, _caption.bind(32))
	_at(t, _view.bind("garras"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 90.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	var at := t + 0.4
	for id: String in ["defecto", "mediodia", "bajo"]:
		_at(at, _light.bind(id))
		for inl: String in AUDIT_INLAYS:
			_at(at, func() -> void:
				if card.inlay_pills.has(inl):
					(card.inlay_pills[inl] as Button).pressed.emit())
			# el selector cambia lo que hay encima de la vista (el afilado de una garra reforjada): se vuelve a ella
			_at(at + 0.1, _scroll.bind(card.view))
			_at(at + 0.7, _scroll.bind(card.view))
			_at(at + AUDIT_STEP_S - 0.05, _shot.bind("garras %s · %s" % [inl, id]))
			at += AUDIT_STEP_S
	_at(at, _light.bind("defecto"))
	return at + 0.2


## 34 · La revisión de los coches de la 4w: el coche entero de cada carrocería (el turismo, el de aluminio, el clásico, el
## deportivo y la aleta de plástico) con cada luz, con el oso de pie en el techo.
func _scene_34(t: float) -> float:
	_at(t, _caption.bind(33))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("oso", "techo", "de_pie", 90.0, "coche", "none"))
	_at(t + 0.2, _scroll.bind(card.view))
	var at := t + 0.4
	for car: String in card.car_pills.keys():
		for id: String in ["defecto", "mediodia", "bajo"]:
			_at(at, func() -> void: card.car_pills[car].pressed.emit())
			_at(at, _light.bind(id))
			_at(at + 0.1, _scroll.bind(card.view))
			_at(at + 0.7, _scroll.bind(card.view))
			_at(at + 1.25, _shot.bind("coche %s · %s" % [car, id]))
			at += 1.3
	_at(at, _light.bind("defecto"))
	return at + 0.2


# ════════ Paisaje (unidad 4x) ════════

## La carretera (CarCurve: «recta», «curva» o «s») y la vista de persecución.
func _road_chase(road: String) -> void:
	if card.road_seg.buttons.has(road):
		(card.road_seg.buttons[road] as Button).pressed.emit()
	if card.view_seg.buttons.has("persecucion"):
		(card.view_seg.buttons["persecucion"] as Button).pressed.emit()


## Una escena del paisaje: el tigre de pie en el techo a 120 km/h en esa carretera con la persecución, con la luz de siempre
## y luego con el sol bajo (una foto con cada una).
func _scenery_scene(t: float, i: int, road: String) -> float:
	_at(t, _caption.bind(i))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 120.0, "coche", "none"))
	_at(t + 0.1, _road_chase.bind(road))
	_at(t + 0.15, _light.bind("defecto"))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 2.2, _shot.bind("paisaje %s · defecto" % road))
	_at(t + 2.3, _light.bind("bajo"))
	_at(t + 4.2, _shot.bind("paisaje %s · bajo" % road))
	_at(t + 4.3, _light.bind("defecto"))
	return t + 4.5


func _scene_35(t: float) -> float:
	return _scenery_scene(t, 34, "recta")


func _scene_36(t: float) -> float:
	return _scenery_scene(t, 35, "curva")


func _scene_37(t: float) -> float:
	return _scenery_scene(t, 36, "s")


## 38 · La carretera sin fin: 8 s de persecución en la recta a 120 km/h (para el vídeo).
func _scene_38(t: float) -> float:
	_at(t, _caption.bind(37))
	_at(t, _view.bind("coche"))
	_at(t, _hold.bind("tigre", "techo", "de_pie", 120.0, "coche", "none"))
	_at(t + 0.1, _road_chase.bind("recta"))
	# --fondo=liso: el mismo plano sin paisaje (para medir lo que cuesta)
	if OS.get_cmdline_user_args().has("--fondo=liso"):
		_at(t + 0.15, func() -> void: (card.scenery_seg.buttons["liso"] as Button).pressed.emit())
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 8.0, _shot.bind("sin fin"))
	return t + 8.2
