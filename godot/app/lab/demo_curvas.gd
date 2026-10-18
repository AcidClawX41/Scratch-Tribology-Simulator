## Demo guionizada del coche en curva (unidad 4t) para las capturas: la sección del laboratorio entera, en la página del
## coche en marcha, pulsando los controles de la tarjeta como una persona (los deslizadores se arrastran):
##   1 · el tigre agazapado en el techo, en recta a 90 km/h (la referencia: sin medidor ni curva);
##   2 · el mismo en la curva de 130 m (la de 60 km/h de la norma), acelerando de 40 a 140 km/h: la fuerza crece con v² y,
##       a más de ~118 km/h, el coche derrapa;
##   3 · la curva en S de 130 m a 95 km/h: la fuerza cambia de lado y el medidor lo enseña (la S dura lo suyo; aquí, 8 s);
##   4 · la lechuza en el techo en la curva de 50 m (la de 40 km/h de la norma), de 30 a 85 km/h: resbala hacia fuera a
##       ~67 km/h, antes de que el coche derrape (~74 km/h);
##   5 · el oso de pie en el deportivo, en la S de 265 m (80 km/h) a 120 km/h;
##   6 · la S del caso 3, con la vista de lado (la de las garras), que sigue a un clic;
##   7 · el tigre que se abalanza sobre la puerta en la curva de 50 m: llega torciéndose (visto desde el coche que gira);
##   8 · el mismo con garras de zafiro: se mellan y los trocitos saltan, vistos con la cámara de persecución.
## Cristales (unidad 4v), en recta y de lado:
##   9 · el águila con garras de diamante en el parabrisas: lo raya y lo agrieta (las garras de cerca y la marca);
##  10 · el oso de pie en el parabrisas: el laminado se agrieta bajo su peso y la grieta tapa al conductor;
##  11 · el tigre con garras de cuarzo en la luneta: la luneta templada estalla y se le va el apoyo;
##  12 · el oso asustado con garras de diamante en la luneta, a 60 km/h: estalla bajo él.
## Agarre en curva (unidad 4u):
##  13 · el tigre en la S de 50 m a 90 km/h: se agarra con más fuerza, se recoloca al cambiar de lado y las garras de fuera
##       resbalan y vuelven a clavarse (sus surcos, hacia fuera);
##  14 · las marcas de esos resbalones de cerca: las garras y luego la marca a unos milímetros;
##  15 · el oso de pie en la curva de 50 m, acelerando de 80 a 125 km/h: se desequilibra a ~112 km/h, resbala hacia fuera
##       arañando el techo, se agarra un instante al borde y cae, rodando por la carretera.
## En curva, la vista es la de persecución (la cámara detrás del coche, por la carretera), salvo en el caso 6.
## Captura:   node godot/tools/godot.mjs capture res://app/lab/demo_curvas.tscn --frames=900 --out=<carpeta> (~30 s a 30 fps)
## Teléfono:  … con --phone. Un caso: … -- --caso=3 (y más fotogramas: cada escena dura lo suyo).
## Al final escribe en la salida el coste de la tarjeta y de la vista por fotograma en el hilo principal.
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const Catalog = preload("res://core/lab/catalog.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Ui = preload("res://app/common/ui.gd")

const SCENES := [
	"El tigre agazapado en el techo, en recta a 90 km/h",
	"El tigre en la curva de 130 m: de 40 a 140 km/h",
	"La curva en S de 130 m a 95 km/h: la fuerza G cambia de lado",
	"La lechuza en la curva de 50 m: resbala hacia fuera",
	"El oso de pie en el deportivo, en la S de 265 m a 120 km/h",
	"La misma S, con la vista de lado (la de las garras)",
	"El tigre contra la puerta en la curva de 50 m",
	"El tigre con garras de zafiro, en la curva de 50 m",
	"El águila con garras de diamante en el parabrisas: lo raya y lo agrieta",
	"El oso de pie en el parabrisas: la grieta tapa al conductor",
	"El tigre con garras de cuarzo en la luneta: estalla",
	"El oso asustado con garras de diamante en la luneta",
	"El tigre en la S de 50 m a 90 km/h: se agarra y se recoloca",
	"Las marcas de los resbalones, de cerca",
	"El oso en la curva de 50 m: de 80 a 125 km/h, se cae",
]

var lab: Control
var card: Control
var caption: Label
var _t := 0.0
var _queue: Array = []
var _drags: Array = []
var _only := -1
var _paint_max := 0
var _paint_sum := 0
var _paint_n := 0
var _draw_sum := 0
var _draw_n := 0
## El caso 15 con otro animal (para ver cómo cae cada especie): -- --caso=15 --animal=tigre --postura=tumbado --hasta=100
## --coche=deportivo (en el deportivo, que agarra 1 g, todos se caen hacia 80 km/h)
var _fall_claw := "oso"
var _fall_posture := "de_pie"
var _fall_v := 125.0
var _fall_car := "coche"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
		elif a.begins_with("--animal="):
			_fall_claw = a.substr(9)
		elif a.begins_with("--postura="):
			_fall_posture = a.substr(10)
		elif a.begins_with("--hasta="):
			_fall_v = float(a.substr(8))
		elif a.begins_with("--coche="):
			_fall_car = a.substr(8)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	lab.set_page(lab.PAGE_CAR, false)
	card = lab.moving_car_card
	_build_caption()
	var t := 0.3
	var order := range(SCENES.size()) if _only < 0 else [_only]
	for i: int in order:
		t = call("_scene_%d" % (i + 1), t)
	_at(t, _report)


func _build_caption() -> void:
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Coche en curva", "CardTitle")
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
	if card.view.curve_on:
		_draw_sum += card.view.last_draw_us
		_draw_n += 1


func _at(t: float, fn: Callable) -> void:
	_queue.append([t, fn])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _drag(t: float, slider: HSlider, from: float, to: float, dur: float) -> void:
	_at(t, func() -> void: _drags.append({ "slider": slider, "from": from, "to": to, "t0": t, "dur": dur, "started": false }))


func _caption(i: int) -> void:
	caption.text = "%s · %s" % [Ui.num(i + 1), SCENES[i]]


func _scroll(c: Control) -> void:
	lab.scroll_to(c, 8.0)


## El animal quieto encima, en una zona y una postura, con el coche a v km/h y la carretera elegida (con su radio).
func _hold(claw: String, zone: String, posture: String, v: float, road: String, r_m: float, car := "coche") -> void:
	lab.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, claw))
	lab.refresh_now()
	if card.car_pills.has(car):
		card.car_pills[car].pressed.emit()
	card.st.set_maneuver("crucero")
	card.mode_seg.buttons["hold"].pressed.emit()
	if card.zone_pills.has(zone):
		card.zone_pills[zone].pressed.emit()
	card.st.set_posture(posture)
	card.speed.slider.value = v
	card.road_seg.buttons[road].pressed.emit()
	card.view_seg.buttons["persecucion"].pressed.emit()
	if road != CarCurve.ROAD_STRAIGHT:
		card.radius.slider.value = CarCurve.slider_u(r_m)


func _scene_1(t: float) -> float:
	_at(t, _caption.bind(0))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 90.0, CarCurve.ROAD_STRAIGHT, 130.0))
	_at(t + 0.2, _scroll.bind(card.view))
	return t + 2.4


func _scene_2(t: float) -> float:
	_at(t, _caption.bind(1))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 40.0, CarCurve.ROAD_CURVE, 130.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.6, card.speed.slider, 40.0, 140.0, 4.0)
	_at(t + 5.0, _scroll.bind(card.road_box))
	return t + 6.6


func _scene_3(t: float) -> float:
	_at(t, _caption.bind(2))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 95.0, CarCurve.ROAD_S, 130.0))
	_at(t + 0.2, _scroll.bind(card.view))
	return t + 9.0


func _scene_4(t: float) -> float:
	_at(t, _caption.bind(3))
	_at(t, _hold.bind("lechuza", "techo", "plegadas", 30.0, CarCurve.ROAD_CURVE, 50.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.6, card.speed.slider, 30.0, 85.0, 3.0)
	_at(t + 4.2, _scroll.bind(card.road_box))
	return t + 5.6


func _scene_5(t: float) -> float:
	_at(t, _caption.bind(4))
	_at(t, _hold.bind("oso", "techo", "de_pie", 120.0, CarCurve.ROAD_S, 265.0, "deportivo"))
	_at(t + 0.2, _scroll.bind(card.view))
	return t + 9.0


func _scene_6(t: float) -> float:
	_at(t, _caption.bind(5))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 95.0, CarCurve.ROAD_S, 130.0))
	_at(t + 0.1, func() -> void: card.view_seg.buttons["lado"].pressed.emit())
	_at(t + 0.2, _scroll.bind(card.view))
	return t + 9.0


func _scene_7(t: float) -> float:
	return _hit_in_curve(t, 6, "tigre_puerta")


func _scene_8(t: float) -> float:
	return _hit_in_curve(t, 7, "tigre_zafiro")


## Un experimento del golpe en la curva de 50 m: se carga en recta (los experimentos van en recta), se pone la curva y se
## vuelve a golpear (la misma fuerza: solo cambia el camino y el dibujo).
func _hit_in_curve(t: float, i: int, id: String) -> float:
	_at(t, _caption.bind(i))
	_at(t, func() -> void:
		if not card.main_box.visible:
			lab.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
			lab.refresh_now()
		card.experiment_pills[id].pressed.emit())
	_at(t + 0.2, func() -> void:
		card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
		card.view_seg.buttons["persecucion"].pressed.emit()
		card.preset_pills["v40"].pressed.emit())
	_at(t + 0.3, _scroll.bind(card.view))
	_drag(t + 0.5, card.speed.slider, 50.0, 52.0, 0.3)
	return t + 4.0


func _report() -> void:
	print("demo_curvas: refresco de la tarjeta %s µs de media por fotograma (máx. %s µs); dibujo de la vista en curva %s µs de media" % [
		Ui.num(_paint_sum / maxi(_paint_n, 1)), Ui.num(_paint_max), Ui.num(_draw_sum / maxi(_draw_n, 1))])
	caption.text = "Fin de la demo"



# ════════ Cristales (unidad 4v) ════════

## El animal quieto encima de un cristal, en recta y de lado: la zona, la postura, el material de las garras, si está
## asustado y la velocidad.
func _glass_hold(claw: String, zone: String, posture: String, inlay: String, scared: bool, v: float) -> void:
	lab.lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, claw))
	lab.refresh_now()
	card.st.set_maneuver("crucero")
	card.mode_seg.buttons["hold"].pressed.emit()
	card.road_seg.buttons[CarCurve.ROAD_STRAIGHT].pressed.emit()
	if card.zone_pills.has(zone):
		card.zone_pills[zone].pressed.emit()
	card.st.set_posture(posture)
	if card.inlay_pills.has(inlay):
		card.inlay_pills[inlay].pressed.emit()
	if card.st.defense != scared:
		card.defense_pill.pressed.emit()
	card.zoom_seg.buttons["coche"].pressed.emit()
	card.speed.slider.value = v


func _zoom(id: String) -> void:
	card.zoom_seg.buttons[id].pressed.emit()


func _scene_9(t: float) -> float:
	_at(t, _caption.bind(8))
	_at(t, _glass_hold.bind("aguila", "parabrisas", "plegadas", "diamante", false, 40.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.6, card.speed.slider, 40.0, 90.0, 2.5)
	_at(t + 3.4, _zoom.bind("garras"))
	_at(t + 3.6, _scroll.bind(card.view))
	_at(t + 5.4, _zoom.bind("marca"))
	_at(t + 5.6, _scroll.bind(card.view))
	_at(t + 7.4, _zoom.bind("coche"))
	return t + 8.0


func _scene_10(t: float) -> float:
	_at(t, _caption.bind(9))
	_at(t, _glass_hold.bind("oso", "parabrisas", "de_pie", "none", false, 30.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 3.0, _scroll.bind(card.tear_cut))
	return t + 5.0


func _scene_11(t: float) -> float:
	_at(t, _caption.bind(10))
	_at(t, _glass_hold.bind("tigre", "techo", "tumbado", "cuarzo", false, 0.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.4, func() -> void: card.zone_pills["luneta"].pressed.emit())
	_at(t + 1.6, _scroll.bind(card.view))
	_at(t + 4.0, _zoom.bind("garras"))
	_at(t + 4.2, _scroll.bind(card.view))
	return t + 6.5


func _scene_12(t: float) -> float:
	_at(t, _caption.bind(11))
	_at(t, _glass_hold.bind("oso", "luneta", "tumbado", "diamante", false, 60.0))
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.4, func() -> void: card.defense_pill.pressed.emit())
	_at(t + 1.6, _scroll.bind(card.view))
	return t + 5.5


# ════════ Agarre en curva (unidad 4u) ════════

func _scene_13(t: float) -> float:
	_at(t, _caption.bind(12))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 90.0, CarCurve.ROAD_S, 50.0))
	_at(t + 0.2, _scroll.bind(card.view))
	return t + 9.0


func _scene_14(t: float) -> float:
	_at(t, _caption.bind(13))
	_at(t, _hold.bind("tigre", "techo", "tumbado", 90.0, CarCurve.ROAD_CURVE, 50.0))
	_at(t + 0.1, func() -> void: card.view_seg.buttons["lado"].pressed.emit())
	_at(t + 0.2, _scroll.bind(card.view))
	_at(t + 1.4, func() -> void: (card.zoom_seg.buttons["garras"] as Button).pressed.emit())
	_at(t + 3.0, func() -> void: (card.zoom_seg.buttons["marca"] as Button).pressed.emit())
	_at(t + 5.4, func() -> void: (card.zoom_seg.buttons["coche"] as Button).pressed.emit())
	return t + 5.6


func _scene_15(t: float) -> float:
	_at(t, _caption.bind(14))
	_at(t, _hold.bind(_fall_claw, "techo", _fall_posture, 60.0 if _fall_car != "coche" else 80.0, CarCurve.ROAD_CURVE, 50.0, _fall_car))
	_at(t + 0.2, _scroll.bind(card.view))
	_drag(t + 0.6, card.speed.slider, 60.0 if _fall_car != "coche" else 80.0, _fall_v, 2.4)
	return t + 6.4
