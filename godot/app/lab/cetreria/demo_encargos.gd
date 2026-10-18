## Demo guionizada de la unidad 5v (petición de Eric del 17-10) para las capturas: los encargos de veterinario con su tutorial
## de iniciación, los minijuegos y los animales que llegan con la garra rota, en la cetrería de verdad, con los botones de la
## tarjeta «Tu consulta de veterinario». Escenas:
##   1 · la ficha de los encargos: la cadena de iniciación (uno por tutorial) y los minijuegos, con qué llega el animal y por qué;
##   2 · la iniciación: aceptar «Preparar al águila» la trae a la mesa con el tutorial abierto en «Preparar al animal»;
##       seguirlo y terminar: cumplido, y se abre la siguiente;
##   3 · el minijuego de transformar: el águila llega con la punta roma; devolverle la punta natural con la lima fina (se pasa
##       a aguja y un toque de frente le deja una cara pequeña), con la barra y el medidor;
##   4 · la garra partida: el águila llega con la garra del talón rota y sangrando; parar la sangre, desinfectar y
##       reconstruirla con metacrilato: la barra se llena y se cobra;
##   5 · la garra que se rompe durante el encargo: un corte que la raja hasta la carne viva; el encargo pasa a «repararla»;
##   6 · el minijuego de pulir: el halcón a su largo y la punta pulida con la lija fina.
## Captura:   node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_encargos.tscn --frames=600 --fps=5 --out=<carpeta>
## Teléfono:  … con --phone. Un caso: … -- --caso=3. No guarda nada (sin ruta de progreso).
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Ui = preload("res://app/common/ui.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const VetMinigames = preload("res://core/lab/vet_minigames.gd")

const SCENES := [
	"Los encargos: la iniciación y los minijuegos",
	"La iniciación: el encargo abre su tutorial",
	"Minijuego · transformar: devolverle la punta a una garra roma",
	"Minijuego · reparar: la garra partida de serie",
	"La garra que se rompe: el encargo pasa a «repararla»",
	"Minijuego · pulir la punta del halcón",
]

var lab: Control
var care: Control
var card: Control
var caption: Label
var _t := 0.0
var _only := -1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	care = lab.care_page
	care.threaded = false
	lab.set_page(lab.PAGE_CARE, false)
	care.call("set_intro_seen", true)
	card = care.progress_card
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Encargos de veterinario", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 60.0, 620.0)
	pill.add_child(caption)
	add_child(pill)
	# abajo (arriba a la derecha tapaba la tarjeta del encargo)
	pill.position = Vector2(14, vs.y - 96.0) if vs.x < 600.0 else Vector2(16, vs.y - 64.0)
	_run()


func _process(delta: float) -> void:
	_t += delta


func _wait(secs: float) -> void:
	var end := _t + secs
	while _t < end:
		await get_tree().process_frame


func _caption(i: int, extra := "") -> void:
	caption.text = "%d · %s%s" % [i + 1, SCENES[i], (" · " + extra) if extra != "" else ""]
	print("[encargos %s s] %s" % [String.num(_t, 1), caption.text])


## Lleva una parte de la tarjeta (o otra tarjeta) a la vista: en escritorio, en la columna; en el teléfono, en la sección.
func _reveal(c: Control) -> void:
	await get_tree().process_frame
	var rs: ScrollContainer = care.right_scroll
	if rs.visible and rs.is_ancestor_of(c):
		var y := c.get_global_rect().position.y - (care.right as Control).get_global_rect().position.y - 8.0
		rs.scroll_vertical = int(maxf(y, 0.0))
	else:
		lab.call("scroll_to", c, 8.0)


func _press(b: BaseButton) -> void:
	if b != null and not b.disabled:
		b.pressed.emit()


func _sync() -> void:
	care.runner.post("tick", [0.0])
	care.refresh()
	care.call("_progress_check", care.runner.latest())


func _run() -> void:
	await get_tree().process_frame
	var order: Array = [0, 1, 2, 3, 4, 5] if _only < 0 else [_only]
	for i: int in order:
		await call("_scene_%d" % (i + 1))
	caption.text = "Fin"


func _scene_1() -> void:
	_caption(0, "la cadena de iniciación (uno por tutorial) y los minijuegos")
	card.call("set_open", "jobs", true)
	await _reveal(card.jobs_box)
	await _wait(3.0)


func _scene_2() -> void:
	_caption(1, "aceptar «Preparar al águila»: la trae a la mesa con su tutorial abierto")
	card.call("set_open", "jobs", true)
	await _reveal(card.jobs_box)
	await _wait(0.8)
	_press(card.buttons.get("encargo:inic_preparar"))
	_sync()
	card.call("set_open", "jobs", false)
	await _reveal(card)
	await _wait(2.4)
	await _reveal(care.tut_card)
	await _wait(2.0)
	_caption(1, "capucha y toalla: el paso se cumple y el tutorial sigue")
	care.runner.post("set_sedation", ["sujecion"])
	_sync()
	await _wait(1.6)
	var st: State = care.runner.state
	for i in 8:
		if st.process_id() != "preparar":
			break
		care.runner.post("tutorial_next")
		_sync()
		await _wait(0.5)
	_caption(1, "«Terminar»: el encargo de iniciación, cumplido; se abre el siguiente")
	_press(care.finish_button)
	_sync()
	await _reveal(card)
	await _wait(3.4)


func _scene_3() -> void:
	var p: Object = care.progress
	p.set("best_level", maxi(int(p.get("best_level")), 2))
	_caption(2, "aceptar: el águila llega con la punta roma (×6 la natural)")
	care.call("_progress_op", "accept", ["afilar_aguila"])
	_sync()
	care.call("set_view", "garra")
	await _reveal(card.mini_box)
	await _wait(2.4)
	_caption(2, "la lima fina a 22°: la barra y el medidor dicen lo que falta")
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	st.pick("lima_fina")
	st.set_angle(22.0)
	for i in 120:
		st.press_on(st.care.apex_mm() - 1.0)
		for k in 6:
			st.drag(10.0 / 6.0, 10.0 / 6.0, st.care.apex_mm() - 1.0, 1.0 / 30.0)
		st.release()
		if i % 4 == 0:
			_sync()
			await get_tree().process_frame
		# una faceta larga (la punta roma, gastada, pide quitar bastante): así el toque de frente deja una cara pequeña
		if i >= 60:
			break
	_sync()
	await _reveal(card.mini_box)
	_caption(2, "se ha pasado a aguja (el radio de los dientes de la lima): la barra lo avisa")
	await _wait(2.6)
	_caption(2, "toques muy ligeros de frente: le dejan una cara diminuta")
	var taps := 0
	while not VetMinigames.in_band(float(st.care.tip_state().ratio), st.care.tip_state().strengthRatio, "natural") and taps < 60:
		st.care.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
		taps += 1
		if taps % 3 == 0:
			_sync()
			await get_tree().process_frame
	_sync()
	_caption(2, "en la banda natural: ni roma ni aguja")
	await _reveal(card.mini_box)
	await _wait(3.0)


func _scene_4() -> void:
	var p: Object = care.progress
	p.set("best_level", maxi(int(p.get("best_level")), 2))
	_caption(3, "aceptar: el águila llega con la garra del talón partida y sangrando")
	care.call("_progress_op", "accept", ["rota_aguila"])
	_sync()
	care.call("set_view", "garra")
	await _reveal(card.mini_box)
	await _wait(2.6)
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	_caption(3, "polvo hemostático apretando hasta que pare")
	await _touch("hemostatico", 200, true)
	await _wait(1.2)
	_caption(3, "clorhexidina diluida al 0,05 %")
	await _touch("clorhexidina", 4, false)
	await _wait(1.2)
	_caption(3, "reconstruida con metacrilato: la barra, llena")
	await _touch("metacrilato", 4, false)
	await _wait(2.4)
	_press(care.finish_button)
	_sync()
	_caption(3, "«Terminar»: cumplido")
	await _reveal(card)
	await _wait(3.0)


## Coge tool de la bandeja y lo aprieta sobre la punta de la garra (como en la escena), n pasos de medio segundo o, until_stop,
## hasta que pare la sangre.
func _touch(tool: String, n: int, until_stop: bool) -> void:
	var st: State = care.runner.state
	st.pick(tool)
	st.press_on(maxf(st.care.apex_mm() - 0.2, 0.0))
	for i in n:
		st.tick(0.5)
		if i % 4 == 0:
			_sync()
			await get_tree().process_frame
		if until_stop and not bool(st.care.snapshot().bleeding.active):
			break
	st.release()
	st.drop()
	_sync()


func _scene_5() -> void:
	_caption(4, "el arreglo de las garras del águila, y un corte de más con la garra seca")
	care.call("_progress_op", "accept", ["coping_aguila"])
	care.call("_progress_op", "bring", ["coping_aguila"])
	_sync()
	care.call("set_view", "garra")
	await _wait(1.2)
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	st.press_on(float(st.care.get("_s_quick")) + 0.4)
	for i in 40:
		st.tick(1.0 / 30.0)
	st.release()
	_sync()
	_caption(4, "se raja hasta la carne viva: el encargo pasa a «repararla» (y se cobra la mitad)")
	await _reveal(card.mini_box.get_parent())
	await _wait(3.4)


func _scene_6() -> void:
	_caption(5, "aceptar: el halcón, a su largo y con la punta pulida (Ra ≤ 1,5 µm)")
	card.call("set_open", "jobs", true)
	await _reveal(card.jobs_box)
	_press(card.buttons.get("encargo:pulir_halcon"))
	card.call("set_open", "jobs", false)
	_sync()
	care.call("set_view", "garra")
	await _reveal(card.mini_box)
	await _wait(2.0)
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	var c := st.care
	var alpha := c.tip_alpha_deg()
	var over := c.overgrowth_left_mm()
	var strokes := 0
	_caption(5, "la lima gruesa quita la mitad del sobrante y deja la punta rayada")
	while c.overgrowth_left_mm() > 0.5 * over and strokes < 300:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
		if strokes % 4 == 0:
			_sync()
			await get_tree().process_frame
	_sync()
	await _wait(2.0)
	_caption(5, "la lija fina en la punta quita el resto y la deja lisa: la barra, llena")
	while c.overgrowth_left_mm() > 0.05 * over and strokes < 600:
		c.file({ "tool": "lija_p240", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
		if strokes % 4 == 0:
			_sync()
			await get_tree().process_frame
	_sync()
	await _wait(3.0)
