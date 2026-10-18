## Demo guionizada del laboratorio: arranca el programa en «Tribología biológica» y encadena veinticinco ensayos
## representativos, pulsando los mismos controles que una persona y con pausas para ver cada resultado:
##   1 · uña almendra natural contra vidrio      2 · garra de tigre contra coche moderno
##   3 · colmillo de víbora punzando piel         4 · casuario con golpe contra piel
##   5 · modo dual: coche clásico frente a moderno (garra de oso, golpe)
##   6 · uña de diamante contra zafiro
##   7 · abeja contra la piel: se queda clavada y el saco sigue bombeando (2.0)
##   8 · avispa contra la piel: pica y se va (2.0)
##   9 · abeja de acero contra el pino a 1 N: el aguijón pandea (2.0)
##   materiales de la 2.0 (docs/fisica/pulido-materiales.md):
##  10 · stiletto natural a 30 N sobre la piel: la uña se dobla a unos 14 N
##  11 · uña almendra a 4 N sobre el coche: se hunde en el barniz, que recupera todo
##  12 · zarpazo de oso contra el coche moderno: no lo perfora, pero abolla la chapa
##  13 · uña cuadrada de zafiro (punta roma) sobre el vidrio: grietas de Hertz
##  14 · garra de tigre de diamante apretando la ventanilla templada: estalla (martillo de emergencia)
##  15 · zarpazo de oso contra el parabrisas laminado: se agrieta, pero no cae
##   biología de la 2.0 (docs/fisica/pulido-biologia.md): zona del cuerpo, hueso, ángulo de ataque y esmalte
##  16 · pájaro rayando la palma: solo pule el callo
##  17 · colmillo de víbora punzando el pómulo: se clava en el hueso
##  18 · casuario de tungsteno, golpe en el brazo: atraviesa el húmero
##  19 · víbora de Gabón mordiendo el abdomen: herida penetrante
##  20 · garra de tigre en el dorso de la mano: laceración hasta el hueso
##  21 · stiletto tumbada a 20°, 10 N sobre el pino: ara en vez de cortar
##  22 · colmillo de víbora rayando el cobre: el esmalte de la punta lo marca
##   velocirraptor y afilado de la 2.0 (docs/fisica/velociraptor.md §10; unidad 4i)
##  23 · velocirraptor (reconstrucción): su ficha y su golpe en el brazo
##  24 · velocirraptor de diamante afilado a media escala rayando el acero: entra más y la punta se mella
##   el banco de la 2.0 en la interfaz (unidad 4n): ficción, presión real y fuentes del ensayo
##  25 · velocirraptor de cine contra el coche moderno: raja la chapa, y el resultado dice que es ficción
## «after» (casos 24 y 25): tras el resultado se mira la comparativa o la lista de fuentes y estimaciones.
## Captura:   npm run godot:capture -- res://app/lab/demo_lab.tscn --frames=300 --fps=8 --out=<carpeta>
## Teléfono:  … -- --ancho=390 --alto=844 (el programa va en un SubViewport de ese tamaño, centrado, con el guion al
##            lado: Movie Maker graba siempre al tamaño del proyecto, 1240 × 880).
## Un caso:   … -- --caso=5
## El tiempo es la suma de los delta (Movie Maker los da fijos), así que cada captura sale igual. No guarda ajustes.
extends Control

const MAIN = preload("res://app/main.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const Format = preload("res://core/shared/format.gd")

const TRIALS := [
	{ "title": "Uña almendra natural contra vidrio de ventana", "geom": "almendra", "base": "natural", "target": "vidrio" },
	{ "title": "Garra de tigre contra coche moderno", "claw": "tigre", "target": "coche" },
	{ "title": "Colmillo de víbora punzando la piel", "claw": "vibora", "target": "piel", "method": "puncion" },
	{ "title": "Casuario: golpe (punción + impacto) contra la piel", "claw": "casuario", "target": "piel", "method": "puncion", "strike": true },
	{ "title": "Modo dual: coche clásico frente a moderno (garra de oso, golpe)", "claw": "oso", "target": "coche", "method": "puncion",
		"strike": true, "dual": true },
	{ "title": "Uña de diamante contra cristal de zafiro", "geom": "stiletto", "base": "diamante", "target": "zafiro", "dual_off": true },
	# aguijones (2.0): «watch» son los segundos que se mira el banco (la abeja bombea el veneno ×10 durante 6 s)
	{ "title": "Abeja melífera contra la piel: se queda clavada", "insect": "abeja", "target": "piel", "dual_off": true, "watch": 6.2 },
	{ "title": "Avispa común contra la piel: pica y se va", "insect": "avispa", "target": "piel", "dual_off": true, "watch": 2.2 },
	{ "title": "Abeja de acero contra el pino a 1 N: el aguijón pandea", "insect": "abeja", "inlay": "acero", "target": "madera", "force": 1.0,
		"dual_off": true, "watch": 2.0 },
	# materiales de la 2.0 (sin «force»: el botón de fuerza máxima, 30 N con la mano y la del animal con una garra)
	{ "title": "Stiletto natural a 30 N sobre la piel: la uña se dobla a unos 14 N", "geom": "stiletto", "base": "natural", "target": "piel",
		"dual_off": true },
	{ "title": "Uña almendra a 4 N sobre el coche: el barniz recupera", "geom": "almendra", "base": "natural", "target": "coche", "force": 4.0,
		"dual_off": true },
	{ "title": "Zarpazo de oso contra el coche moderno: abolla la chapa", "claw": "oso", "target": "coche", "method": "puncion", "strike": true,
		"dual_off": true },
	{ "title": "Uña cuadrada de zafiro sobre el vidrio: grietas de Hertz", "geom": "cuadrada", "base": "zafiro", "target": "vidrio",
		"dual_off": true },
	{ "title": "Garra de tigre de diamante apretando la ventanilla: estalla", "claw": "tigre", "inlay": "diamante", "target": "ventanilla",
		"method": "puncion", "dual_off": true },
	{ "title": "Zarpazo de oso contra el parabrisas: se agrieta, no cae", "claw": "oso", "target": "parabrisas", "method": "puncion",
		"strike": true, "dual_off": true },
	# biología de la 2.0: «zone» es la píldora de la zona del cuerpo y «attack», el ángulo de ataque del deslizador
	{ "title": "Pájaro rayando la palma: solo pule el callo", "claw": "pajaro", "target": "piel", "zone": "palma", "force": 1.5,
		"dual_off": true },
	{ "title": "Víbora punzando el pómulo: el colmillo se clava en el hueso", "claw": "vibora", "target": "piel", "zone": "cara",
		"method": "puncion", "force": 4.0, "dual_off": true },
	{ "title": "Casuario de tungsteno, golpe en el brazo: atraviesa el húmero", "claw": "casuario", "inlay": "tungsteno", "target": "piel",
		"zone": "brazo", "method": "puncion", "strike": true, "dual_off": true },
	{ "title": "Víbora de Gabón mordiendo el abdomen: herida penetrante", "claw": "gabon", "target": "piel", "zone": "abdomen",
		"method": "puncion", "strike": true, "force": 30.0, "dual_off": true },
	{ "title": "Garra de tigre en el dorso de la mano: hasta el hueso", "claw": "tigre", "target": "piel", "zone": "dorsomano",
		"dual_off": true },
	{ "title": "Stiletto tumbada a 20°, 10 N sobre el pino: ara en vez de cortar", "geom": "stiletto", "base": "natural",
		"target": "madera", "attack": 20.0, "force": 10.0, "dual_off": true },
	{ "title": "Colmillo de víbora rayando el cobre: el esmalte lo marca", "claw": "vibora", "target": "cobre", "force": 4.0,
		"dual_off": true },
	# velocirraptor y afilado (2.0): «look» es lo que se enseña un momento antes de ensayar (la ficha o el deslizador) y
	# «sharpness», el afilado del deslizador
	{ "title": "Velocirraptor (reconstrucción): su ficha y su golpe en el brazo", "claw": "velociraptor", "target": "piel",
		"zone": "brazo", "method": "puncion", "strike": true, "look": "ficha", "dual_off": true },
	{ "title": "Velocirraptor de diamante afilado rayando el acero: entra más y la punta se mella", "claw": "velociraptor",
		"inlay": "diamante", "target": "acero", "sharpness": 0.5, "look": "sharp", "dual_off": true, "after": "compare" },
	# el banco de la 2.0 en la interfaz (unidad 4n): la garra de película es ficción, y la tarjeta lo dice
	{ "title": "Velocirraptor de cine contra el coche moderno: raja la chapa (ficción)", "claw": "velociraptor_pelicula",
		"target": "coche", "dual_off": true, "after": "sources" },
]
const STEP_S := 0.3
const HOLD_S := 2.8
## Lo que se mira «after» (la comparativa o las fuentes del ensayo).
const AFTER_S := 2.6

var phone := false
var phone_size := Vector2i(390, 844)
var main: Control
var lab: Control  # la sección del laboratorio
var caption: Label
var steps_list: Array[Label] = []
var step_ids: Array[int] = []  # el ensayo de cada línea del guion (con --caso, solo ese)
var _t := 0.0
var _queue: Array = []  # [instante (s), Callable], por orden
var _only := -1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ancho="):
			phone_size.x = int(a.substr(8))
			phone = true
		elif a.begins_with("--alto="):
			phone_size.y = int(a.substr(7))
			phone = true
		elif a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, TRIALS.size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main = MAIN.instantiate()
	main.remember = false
	main.settings_path = "user://demo_sin_ajustes.cfg"
	if phone:
		_build_phone()
	else:
		add_child(main)
	_build_caption()
	lab = main.pages["bio"]
	var t := 1.2  # primero se cargan las fichas
	var order := range(TRIALS.size()) if _only < 0 else [_only]
	for i: int in order:
		t = _schedule(i, t)
	if _only >= 0:
		_at(t + 0.5, get_tree().quit)
		return
	# para acabar: los fundamentos físicos y el cambio de sección (la oculta se desactiva)
	_at(t, func() -> void: caption.text = "Fundamentos físicos")
	_at(t + 0.3, main.toggle_fundamentos)
	_at(t + 2.8, main.toggle_fundamentos)
	_at(t + 3.1, func() -> void: caption.text = "Dos secciones en un solo programa")
	_at(t + 3.4, main.show_section.bind("taller"))
	_at(t + 5.4, main.show_section.bind("bio"))
	_at(t + 5.8, func() -> void: caption.text = "Fin de la demo")


## Teléfono: el programa en un SubViewport del tamaño pedido, centrado, y el guion a la izquierda.
func _build_phone() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.color("bg2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(phone_size)
	box.size = Vector2(phone_size)
	box.position = Vector2(floorf((1240.0 - phone_size.x) / 2.0), floorf((880.0 - phone_size.y) / 2.0))
	add_child(box)
	var vp := SubViewport.new()
	vp.size = phone_size
	vp.audio_listener_enable_2d = true
	box.add_child(vp)
	vp.add_child(main)
	var frame := Panel.new()
	var sb := AppTheme.box(Color.TRANSPARENT, 26, Palette.color("line2"), 2)
	sb.set_expand_margin_all(6.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = box.position
	frame.size = Vector2(phone_size)
	add_child(frame)


func _build_caption() -> void:
	if phone:
		var col := Ui.vbox(10)
		col.position = Vector2(28, 60)
		col.size = Vector2(360, 700)
		col.add_child(Ui.label("Demo · Tribología biológica", "Kicker"))
		col.add_child(Ui.label("Teléfono · %s × %s" % [Ui.num(phone_size.x), Ui.num(phone_size.y)], "Small"))
		for i in TRIALS.size():
			if _only >= 0 and i != _only:
				continue
			var l := Ui.para("%s · %s" % [Ui.num(i + 1), TRIALS[i].title], "Body")
			l.custom_minimum_size.x = 330.0
			col.add_child(l)
			steps_list.append(l)
			step_ids.append(i)
		add_child(col)
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Cargando las ilustraciones…", "CardTitle")
	if phone:
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size.x = 330.0
	pill.add_child(caption)
	add_child(pill)
	if phone:
		pill.position = Vector2(28, 740)
	else:
		pill.position = Vector2(16, 818)


func _process(delta: float) -> void:
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()


func _at(t: float, fn: Callable) -> void:
	_queue.append([t, fn])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## Programa un ensayo desde el instante t; devuelve cuándo acaba.
func _schedule(i: int, t: float) -> float:
	var c: Dictionary = TRIALS[i]
	_at(t, _caption.bind(i))
	var actions: Array[Callable] = []
	if c.get("dual_off", false):
		actions.append(_dual.bind(false))
	if c.has("insect"):
		actions.append(_click_seg.bind("tool_card", "kind_seg", "insectos"))
		actions.append(_click_map.bind("tool_card", "claw_tiles", c.insect))
		actions.append(_click_map.bind("tool_card", "inlay_pills", c.get("inlay", "none")))
	elif c.has("claw"):
		actions.append(_click_seg.bind("tool_card", "kind_seg", "garras"))
		actions.append(_click_map.bind("tool_card", "claw_tiles", c.claw))
		actions.append(_click_map.bind("tool_card", "inlay_pills", c.get("inlay", "none")))  # reforjada o no
	else:
		actions.append(_click_seg.bind("tool_card", "kind_seg", "unas"))
		actions.append(_click_map.bind("tool_card", "geom_tiles", c.geom))
		actions.append(_click_map.bind("tool_card", "base_pills", c.base))
		actions.append(_click_map.bind("tool_card", "inlay_pills", c.get("inlay", "none")))
	actions.append(_click_map.bind("target_card", "tiles", c.target))
	if c.has("zone"):  # 2.0: la zona del cuerpo, con la piel (y se enseña un momento dónde se elige)
		actions.append(_scroll.bind("zone"))
		actions.append(_click_map.bind("target_card", "zone_pills", c.zone))
		actions.append(func() -> void: pass)
	if not c.has("insect"):  # un aguijón solo pica: no hay método ni golpe que elegir
		actions.append(_click_seg.bind("params_card", "method_seg", c.get("method", "rayado")))
		if c.get("method", "rayado") == "puncion":
			actions.append(_click_seg.bind("params_card", "strike_seg", "impacto" if c.get("strike", false) else "estatico"))
	actions.append(_set_force.bind(float(c.force)) if c.has("force") else _max_force)
	if c.has("attack"):  # 2.0: el ángulo de ataque, como quien arrastra el deslizador
		actions.append(_scroll.bind("attack"))
		actions.append(_set_attack.bind(float(c.attack)))
		actions.append(func() -> void: pass)
	if c.has("sharpness"):  # 2.0: el afilado de una garra reforjada, como quien arrastra el deslizador
		actions.append(_scroll.bind("sharp"))
		actions.append(_set_sharpness.bind(float(c.sharpness)))
	if c.has("look"):  # se mira un momento la ficha o el deslizador del afilado (en el teléfono, la ficha en dos veces)
		actions.append(_scroll.bind(String(c.look)))
		for _i in 5:
			actions.append(func() -> void: pass)
		if phone and c.look == "ficha":
			actions.append(_scroll.bind("ficha-filas"))
			for _i in 5:
				actions.append(func() -> void: pass)
	if c.get("dual", false):
		actions.append(_dual.bind(true))
	for a in actions:
		t += STEP_S
		_at(t, a)
	t += 0.3
	_at(t, _scroll.bind("run"))
	t += 0.6
	_at(t, _run)
	if c.has("watch"):
		# el insecto: se mira el banco mientras llega, pica, se va y (la abeja) el saco bombea; luego el resultado
		_at(t + 0.1, _scroll.bind("result"))
		t += float(c.watch)
		if phone:
			_at(t, _scroll.bind("verdict"))
		return t + HOLD_S
	t += 1.4  # el ensayo dura 1,15 s
	_at(t, _scroll.bind("dual" if c.get("dual", false) else "result"))
	if phone:
		_at(t + 1.6, _scroll.bind("table" if c.get("dual", false) else "verdict"))
	var end := t + HOLD_S + (1.2 if c.get("dual", false) else 0.0)
	if c.has("after"):  # unidad 4n: la comparativa o las fuentes del ensayo, un momento después del resultado
		_at(end, _scroll.bind(String(c.after)))
		end += AFTER_S
	return end


func _caption(i: int) -> void:
	caption.text = "%s · %s" % [Ui.num(i + 1), TRIALS[i].title]
	for k in steps_list.size():
		Ui.set_color(steps_list[k], "text" if step_ids[k] == i else "dimmer")


func _click(b: BaseButton) -> void:
	if b.is_visible_in_tree():
		b.pressed.emit()


func _click_seg(card: String, seg: String, id: String) -> void:
	var s: Control = lab.get(card).get(seg)
	_click(s.buttons[id])


func _click_map(card: String, field: String, id: String) -> void:
	var m: Dictionary = lab.get(card).get(field)
	_click(m[id])


func _max_force() -> void:
	_click(lab.params_card.max_button)


## Mueve el deslizador de fuerza hasta f (N) en la escala de la herramienta, como quien lo arrastra.
func _set_force(f: float) -> void:
	var r: Dictionary = lab.lab.force_range()
	var slider: HSlider = lab.params_card.force.slider
	if slider.is_visible_in_tree():
		slider.value = Format.f_to_t_in(f, r.min, r.max)


## Mueve el deslizador del ángulo de ataque hasta deg grados.
func _set_attack(deg: float) -> void:
	var slider: HSlider = lab.params_card.attack.slider
	if slider.is_visible_in_tree():
		slider.value = deg


## Mueve el deslizador del afilado (0-1) de la tarjeta de la herramienta.
func _set_sharpness(s: float) -> void:
	var slider: HSlider = lab.tool_card.sharp.slider
	if slider.is_visible_in_tree():
		slider.value = s


func _dual(on: bool) -> void:
	if lab.lab.dual != on:
		_click(lab.dual_card.toggle)


func _run() -> void:
	_click(lab.run_button)


func _scroll(where: String) -> void:
	var target: Control
	match where:
		"run":
			target = lab.run_button if phone else lab.tool_card
		"result":
			target = lab.result_card
		"verdict":
			target = lab.result_card.verdict_box
		"dual":
			target = lab.dual_card
		"table":
			target = lab.dual_card.hint if lab.dual_card.hint.visible else lab.dual_card.table_head
		"zone":
			target = lab.target_card.zone_box if lab.target_card.zone_box.visible else lab.target_card
		"attack":
			target = lab.params_card.attack_box if lab.params_card.attack_box.visible else lab.params_card
		"ficha":
			target = lab.tool_card
		"ficha-filas":  # el teléfono: la descripción y las filas de la ficha, debajo del dibujo
			target = lab.tool_card.claw_desc
		"sharp":
			target = lab.tool_card.sharp_box if lab.tool_card.sharp_box.visible else lab.tool_card
		"compare":
			target = lab.compare_card
		"sources":  # la lista de fuentes y estimaciones del ensayo (unidad 4n), abierta; sin ella, el pie del resultado
			var rc: Control = lab.result_card
			target = rc.adhesion
			if rc.get("sources_box") != null:
				target = rc.sources_box
				if not rc.sources_list.visible:
					_click(rc.sources_toggle)
	lab.scroll_to(target, 12.0)
