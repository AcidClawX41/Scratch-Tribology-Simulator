## Demo guionizada del progreso del veterinario (unidad 5u; petición 62) para las capturas: la cetrería con su tarjeta «Tu
## consulta de veterinario», manejada con sus botones como una persona. Escenas:
##   1 · el principio: nivel 1, sin créditos, la lente de plástico de serie y la lista de los encargos;
##   2 · el arreglo de las garras del águila: aceptar el encargo, traer al animal, una consulta bien hecha y «Terminar»: el informe y el
##       encargo cumplido, con lo que se cobra;
##   3 · el encargo que sale mal: la carne viva cortada, y la tarjeta dice por qué no se cumple;
##   4 · la tienda (con su botón junto al de la reforja): con el nivel 2 y los créditos, la lente de vidrio (su ficha, qué la
##       raya y lo que le hace el animal de la mesa) comprada y puesta;
##   5 · la lente que ya no deja ver: la tienda se abre sola con el aviso, y «Empezar el juego de nuevo» (con confirmación);
##   6 · el primer ataque: el tutorial salta a «Tras un ataque» (parar, calmarla, la sujeción, curar y la lente) y la pausa
##       para calmarla baja el estrés.
## Captura:   node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_progreso.tscn --frames=900 --out=<carpeta>
## Teléfono:  … con --phone. Un caso: … -- --caso=2. No guarda nada (sin ruta de progreso).
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Ui = preload("res://app/common/ui.gd")
const State = preload("res://core/lab/claw_care_state.gd")

const SCENES := [
	"El principio: nivel 1, la lente de plástico y los encargos",
	"El arreglo de las garras del águila: aceptar, traer al animal, la consulta y cobrar",
	"Un encargo que sale mal: por qué no se cumple",
	"La tienda: la lente de vidrio, con el nivel y los créditos",
	"La lente que ya no deja ver: cambiarla o empezar de nuevo",
	"El primer ataque: el tutorial enseña a calmarla",
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
	card = care.progress_card
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Tu consulta de veterinario", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 60.0, 620.0)
	pill.add_child(caption)
	add_child(pill)
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


func _run() -> void:
	await get_tree().process_frame
	var order: Array = [0, 1, 2, 3, 4, 5] if _only < 0 else [_only]
	for i: int in order:
		await call("_scene_%d" % (i + 1))
	caption.text = "Fin"


func _scene_1() -> void:
	_caption(0)
	await _reveal(card)
	await _wait(2.0)
	_caption(0, "la lista de los encargos: lo que piden, el nivel y lo que dan")
	card.call("set_open", "jobs", true)
	await _reveal(card.jobs_box)
	await _wait(3.0)


## Una consulta bien hecha con la rapaz: encapuchada y envuelta, el sobrante limado con una faceta que sigue la curva y la
## punta rematada (la de tests/lab/test_claw_care.gd), a la vista.
func _good_session() -> void:
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	var c := st.care
	var alpha := c.tip_alpha_deg()
	var over := c.overgrowth_left_mm()
	var strokes := 0
	while c.overgrowth_left_mm() > 0.05 * over and strokes < 300:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
		if strokes % 6 == 0:
			care.runner.post("tick", [0.0])
			care.refresh()
			await get_tree().process_frame
	var taps := 0
	while float(c.tip_state().ratio) < 0.5 and taps < 50:
		c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
		taps += 1
	c.apply({ "tool": "crema" })


func _scene_2() -> void:
	_caption(1, "aceptar el encargo")
	card.call("set_open", "jobs", true)
	await _reveal(card.jobs_box)
	await _wait(1.0)
	_press(card.buttons.get("encargo:coping_aguila"))
	await _reveal(card)
	await _wait(2.0)
	_caption(1, "traer al animal a la mesa: el águila del encargo")
	_press(card.bring_button)
	care.refresh()
	await _wait(1.2)
	_caption(1, "encapuchada y en la toalla, el sobrante limado y la punta rematada")
	care.call("set_view", "garra")
	await _good_session()
	await _wait(0.8)
	_caption(1, "«Terminar y ver el informe»: el encargo se comprueba con él")
	_press(care.finish_button)
	care.refresh()
	await _reveal(care.report_card)
	await _wait(2.4)
	await _reveal(card)
	await _wait(3.4)


func _scene_3() -> void:
	var p: Object = care.progress
	if String(p.get("active_job")) == "":
		p.call("accept", "punta_halcon")
	_caption(2, "otro encargo: la carne viva cortada")
	care.call("_progress_op", "bring", [String(p.get("active_job"))])
	care.refresh()
	await _wait(0.8)
	var st: State = care.runner.state
	st.set_sedation("sujecion")
	st.care.call("_cut_to", st.care.apex_mm() - (st.care.quick_cover_mm() + 0.5))
	st.care.hemostasis({ "tool": "hemostatico", "pressure_s": 400.0 })
	care.runner.post("tick", [0.0])
	care.refresh()
	await _wait(1.0)
	_press(care.finish_button)
	care.refresh()
	_caption(2, "no se cumple: la tarjeta dice por qué, y sigue en curso")
	await _reveal(card)
	await _wait(3.6)


func _scene_4() -> void:
	var p: Object = care.progress
	if int(p.call("level")) < 2:
		p.set("best_level", 2)
	if int(p.get("credits")) < 80:
		p.set("credits", 120)
	p.set("serial", int(p.get("serial")) + 1)
	care.refresh()
	_caption(3, "la tienda: cada lente, con su ficha y qué la raya")
	card.call("set_open", "jobs", false)
	await _reveal(care.shop_button)
	await _wait(1.0)
	_press(care.shop_button)
	await _wait(3.0)
	_caption(3, "comprar la de vidrio: la puesta, sin rayones")
	_press(card.buttons.get("lente:vidrio"))
	care.refresh()
	await _reveal(card)
	await _wait(3.0)
	card.call("set_open", "shop", false)


func _scene_5() -> void:
	_caption(4)
	card.call("set_open", "shop", false)
	var st: State = care.runner.state
	for i in 80:
		st.lens.add_scratch("desgarro", [[0.0, 0.0125 * i], [1.0, 0.0125 * i]], 2000.0, 1500.0)
	st.lens.serial += 1
	care.runner.post("tick", [0.0])
	care.runner.post("lens_clean")
	care.refresh()
	await _wait(3.5)
	_caption(4, "empezar de nuevo pide confirmación")
	_press(card.restart_button)
	await _wait(2.5)
	_press(card.restart_button)
	await _wait(1.0)
	card.call("set_open", "shop", false)
	await _reveal(care.shop_button)
	await _wait(2.5)


func _scene_6() -> void:
	_caption(5)
	card.call("set_open", "shop", false)
	care.runner.post("configure", [{ "animal": "rapaz", "claw": "aguila", "sedation": "libre", "seed": "demo-ataque" }])
	care.runner.post("set_tutorial", [true])
	var st: State = care.runner.state
	st.patient.note_handling()
	# muy estresada, pero por debajo de lo que la hace soltarse (que para la sesión)
	st.patient.stress = 0.85
	var guard := 0
	while int(st.patient.reaction_seq) == 0 and guard < 200:
		care.runner.post("tick", [0.1])
		care.refresh()
		await get_tree().process_frame
		guard += 1
	await _reveal(care.tut_card)
	_caption(5, "el tutorial salta a «Tras un ataque»")
	await _wait(3.0)
	_caption(5, "pausa para calmarla: sin tocarla no se revuelve")
	_press(care.rest_button)
	care.refresh()
	await _wait(2.0)
	_caption(5, "encapuchada: a oscuras se calma mucho antes")
	care.runner.post("set_sedation", ["sujecion"])
	care.refresh()
	await _wait(1.5)
	for i in 90:
		care.runner.post("tick", [0.5])
		care.refresh()
		await get_tree().process_frame
	_caption(5, "calmada: el tutorial sigue con la lente")
	await _wait(3.0)
