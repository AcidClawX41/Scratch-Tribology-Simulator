## Taller industrial · página de la radial contra chapa de coche.
##
## La radial se usa a mano (unidad 2c): al abrir la pestaña está apagada y apartada de la chapa y no arranca nada. Se
## enciende con el gatillo (botón o Espacio) y se maneja con el ratón sobre la vista 3D (izquierdo: la lleva a lo largo
## del corte y la acerca o la aparta; Mayús + izquierdo: la gira y la inclina; rueda: la acerca o la aparta; derecho:
## gira la cámara) o con la tarjeta «La radial en tus manos», con botones grandes y deslizadores rotulados para el
## teléfono y para quien no use ratón. La física de cada fotograma la hace core/taller/radial_manual.gd (con
## Radial.cut_step, el modelo de cut_panel en ese instante); la página y la escena solo pintan su salida: lecturas bajo
## la vista y avisos en directo con su fuente.
## «Ver demostración» pone el corte automático de siempre (cut_panel con los ajustes de las tarjetas); «Reiniciar chapa»
## empieza una chapa sin cortar. Tarjetas: aviso educativo · la radial en tus manos · disco y radial (6 discos,
## diámetros, rueda de velocidad) · chapa y corte (4 carrocerías y 3 piezas de rescate, ángulo, avance) · predicción de un
## corte completo (cut_panel) · avisos del montaje con su fuente. Los ajustes se guardan en WorkshopState (disc_check y
## cut_panel de core/taller/radial.gd); el estado de la mano, en el RadialManual de la página.
extends Control

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const RadialManual = preload("res://core/taller/radial_manual.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Panels = preload("res://core/taller/panels.gd")
const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Card = preload("res://app/taller/ui/card.gd")
const TwoPane = preload("res://app/taller/ui/two_pane.gd")
const View3D = preload("res://app/taller/ui/view3d.gd")
const Looks = preload("res://app/taller/radial3d/looks.gd")

const RADIAL_SCENE := "res://app/taller/radial_3d.tscn"
const VIEWS := [["detalle", "Detalle del corte"], ["general", "General"], ["canto", "Canto a escala"], ["cenital", "Surco a escala"]]
## Demostración: el corte automático empieza ya avanzado (el disco de Ø125 dentro de la chapa) y se repite tras una
## pausa corta.
const PRE_CUT_MM := 110.0
const LOOP_PAUSE_S := 0.8
## Para los recuadros a escala (dos de 424 × 236 px) hace falta una vista alta y ancha.
const INSET_MIN_H := 620.0
const INSET_MIN_W := 640.0
const STRIPE_HEX := { "azul": "#2F6FD6", "amarillo": "#F2C230", "rojo": "#D6333A", "verde": "#3BA55C" }
## La mano con los botones y las teclas (elección de la interfaz, no datos): lejos de la chapa se acerca deprisa; a
## menos de 2 mm o dentro, a 1 mm/s (para entrar con suavidad). A lo largo, el avance pedido de la tarjeta «Chapa y
## corte» o, con «máximo», lo que el disco puede cortar en ese momento.
const APPROACH_FAR_MM_S := 15.0
const APPROACH_NEAR_MM_S := 1.0
const NEAR_MM := 2.0
const TILT_DEG_S := 10.0
const YAW_DEG_S := 30.0
## Avisos en directo que caben en la tarjeta: se reutilizan siempre las mismas etiquetas (ningún nodo nuevo por
## fotograma).
const LIVE_WARN_SLOTS := 5
const STATE_TEXT := { "apagada": "apagada", "arrancando": "arrancando", "en_marcha": "en marcha",
	"parando": "parando por inercia", "desconectada": "desconectada por rebote (suelta el gatillo)",
	"calada": "calada: el disco se ha bloqueado" }
const HELP_MOUSE := "Ratón sobre la vista: botón izquierdo y arrastrar ← → lleva la radial a lo largo del corte (la velocidad del ratón es el avance) y ↑ ↓ la acerca o la aparta · Mayús + izquierdo: ← → la gira, ↑ ↓ inclina el disco · rueda: la acerca o la aparta · Alt + rueda: rueda de velocidad · botón derecho: gira la cámara · central: la desplaza · Ctrl + rueda: zoom. Teclado: Espacio gatillo · ← → a lo largo · ↑ ↓ apartar o acercar · Q E inclinar · Z X girar · V dar la vuelta · + − rueda de velocidad."
const HELP_TOUCH := "Un dedo sobre la vista mueve la radial (← → a lo largo, ↑ ↓ la acerca o la aparta); con dos dedos se gira la cámara y se hace zoom. O usa los botones de «La radial en tus manos»."

var state: WorkshopState
var manual: RadialManual
var frame: Dictionary = {}
var pane: TwoPane
var view3d: View3D
var radial3d: Node3D = null
var view := "detalle"
var compact := false
## La demostración (el corte automático) está en marcha.
var demo := false

var view_chips := {}
var disc_chips := {}
var panel_chips := {}
var diam_box: HFlowContainer
var diam_chips := {}
var rpm_slider: Dictionary
var angle_slider: Dictionary
var feed_slider: Dictionary
var yaw_slider: Dictionary
var disc_info: Label
var panel_info: Label
var check_label: Label
var check_warn: Label
var stripe_box: HBoxContainer
var clean_bar: ProgressBar
var clean_value: Label
var res := {}  # nombre → Label (predicción de un corte completo)
var tint_box: HBoxContainer
var warn_list: VBoxContainer
var sources_label: Label
var inset_check: CheckButton
var result_card: Card
# La radial en tus manos
var demo_button: Button
var reset_button: Button
var trigger_button: Button
var flip_button: Button
var state_label: Label
var help_label: Label
var hold_buttons := {}  # "atras" · "adelante" · "acercar" · "apartar" → Button
var reads := {}  # lecturas en directo bajo la vista: nombre → Label
var top_warn: Label
var live_warns: Array[Label] = []
var live_srcs: Array[Label] = []

var _restart := false
var _loop_wait := -1.0
var _built := false
var _diam_key := ""
var _synced_angle := INF
var _hold_u := 0.0
var _hold_d := 0.0
var _keys := {}  # tecla pulsada → true


func build(ws: WorkshopState) -> void:
	if _built:
		return
	_built = true
	state = ws
	name = "Radial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p: Dictionary = state.radial
	manual = RadialManual.new(str(p["disc_id"]), str(p["panel_id"]), float(p["diameter_mm"]))
	manual.set_dial_rpm(float(p["rpm"]))
	manual.set_tilt(float(p["angle_deg"]))
	_synced_angle = float(p["angle_deg"])
	frame = manual.step(0.0)
	pane = TwoPane.new()
	add_child(pane)
	_build_visual()
	_build_banner()
	_build_hands_card()
	_build_disc_card()
	_build_cut_card()
	_build_result_card()
	_build_warn_card()
	refresh()
	_update_live(frame)


func _build_visual() -> void:
	var bar := HFlowContainer.new()
	view_chips = Style.chips(VIEWS, set_view, bar).buttons
	inset_check = CheckButton.new()
	inset_check.text = "Recuadros a escala"
	inset_check.focus_mode = Control.FOCUS_NONE
	# apagados de entrada: en una columna de ~700 px taparían media vista (las vistas «Canto» y «Surco» dan lo mismo a
	# pantalla completa)
	inset_check.button_pressed = false
	inset_check.toggled.connect(func(_on: bool) -> void: _update_insets())
	bar.add_child(inset_check)
	demo_button = Style.button("Ver demostración", "", true)
	_a11y(demo_button, "Ver demostración", "Pone el corte automático con los ajustes de las tarjetas; se vuelve al mando manual con el mismo botón.")
	demo_button.toggled.connect(set_demo)
	bar.add_child(demo_button)
	reset_button = Style.button("Reiniciar chapa")
	_a11y(reset_button, "Reiniciar chapa", "Chapa nueva sin cortar; la radial se aparta.")
	reset_button.pressed.connect(reset_panel)
	bar.add_child(reset_button)
	pane.visual.add_child(bar)
	view3d = View3D.new(RADIAL_SCENE)
	view3d.name = "Radial3D"
	view3d.custom_minimum_size = Vector2(300, 320)
	view3d.configure = _configure_scene
	view3d.scene_ready.connect(_on_scene_ready)
	view3d.resized.connect(_update_insets)
	_a11y(view3d, "Vista 3D de la radial", HELP_MOUSE)
	pane.visual.add_child(view3d)
	# Lecturas en directo, siempre a la vista
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 14)
	for k in [["rpm", "Giro"], ["vs", "Periférica"], ["feed", "Avance"], ["depth", "Profundidad"], ["tilt", "Ángulo"],
			["yaw", "Giro de la radial"], ["cut", "Cortado"], ["clean", "Calidad del corte"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(Style.label(k[1], "TallerNota"))
		var v := Style.label("—", "TallerDato")
		v.accessibility_live = AccessibilityServer.LIVE_POLITE if k[0] in ["rpm", "cut"] else AccessibilityServer.LIVE_OFF
		cell.add_child(v)
		strip.add_child(cell)
		reads[k[0]] = v
	pane.visual.add_child(strip)
	top_warn = Style.label("", "TallerMal", true)
	top_warn.accessibility_live = AccessibilityServer.LIVE_ASSERTIVE
	pane.visual.add_child(top_warn)
	help_label = Style.label(HELP_MOUSE, "TallerNota", true)
	pane.visual.add_child(help_label)
	Style.pick_chip(view_chips, view)


func _build_banner() -> void:
	var band := PanelContainer.new()
	band.theme_type_variation = "TallerBanda"
	var l := Style.label("Simulador educativo: no es un procedimiento de rescate ni de taller. Los avisos (chispas cerca del combustible y de los airbags, pilares de acero al boro, cables naranjas de alta tensión, hoja de rescate ISO 17840) llevan su fuente.", "TallerAviso", true)
	band.add_child(l)
	pane.side.add_child(band)


## La radial en tus manos: gatillo, botones que se mantienen pulsados para moverla, giro, estado y avisos en directo.
func _build_hands_card() -> void:
	var card := Card.new("La radial en tus manos", "modo manual")
	var row := HBoxContainer.new()
	trigger_button = Style.button("Encender (Espacio)", "TallerAccion", true)
	trigger_button.custom_minimum_size = Vector2(180, 40)
	_a11y(trigger_button, "Gatillo de la radial", "Enciende o apaga la radial (tecla Espacio). Al soltarlo, el disco sigue girando unos segundos.")
	trigger_button.toggled.connect(func(on: bool) -> void: set_trigger(on))
	row.add_child(trigger_button)
	state_label = Style.label("", "TallerDato", true)
	state_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	row.add_child(state_label)
	card.body.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for b in [["atras", "◀ Atrás", "Lleva la radial hacia el principio de la línea de corte mientras se mantiene pulsado (tecla ←)."],
			["adelante", "Adelante ▶", "Lleva la radial a lo largo de la línea de corte mientras se mantiene pulsado (tecla →)."],
			["acercar", "▼ Acercar", "Baja la radial hacia la chapa mientras se mantiene pulsado; cerca de ella, despacio (tecla ↓)."],
			["apartar", "▲ Apartar", "Aparta la radial de la chapa mientras se mantiene pulsado (tecla ↑)."]]:
		var btn := Style.button(b[1])
		btn.custom_minimum_size = Vector2(120, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_a11y(btn, b[1].replace("◀ ", "").replace(" ▶", "").replace("▼ ", "").replace("▲ ", ""), b[2])
		btn.button_down.connect(_hold.bind(b[0], true))
		btn.button_up.connect(_hold.bind(b[0], false))
		grid.add_child(btn)
		hold_buttons[b[0]] = btn
	card.body.add_child(grid)
	yaw_slider = Style.slider("Giro de la radial (0° o 180°: alineada con la línea de corte; dada la vuelta, las chispas salen al otro lado)", -180.0, 180.0, 1.0,
		func(v: float) -> void: manual.set_yaw(v))
	_a11y(yaw_slider.slider, "Giro de la radial", "Gira la radial alrededor de la normal de la chapa (Z y X, o Mayús + arrastre horizontal).")
	card.body.add_child(yaw_slider.row)
	flip_button = Style.button("Dar la vuelta (180°)")
	_a11y(flip_button, "Dar la vuelta a la radial", "Gira la radial 180°: el disco gira al revés respecto al corte (tecla V).")
	flip_button.pressed.connect(func() -> void: manual.flip())
	card.body.add_child(flip_button)
	card.body.add_child(Style.label("Avisos en directo", "TallerTenue"))
	for i in LIVE_WARN_SLOTS:
		var w := Style.label("", "TallerAviso", true)
		w.visible = false
		card.body.add_child(w)
		var s := Style.label("", "TallerNota", true)
		s.visible = false
		card.body.add_child(s)
		live_warns.append(w)
		live_srcs.append(s)
	pane.side.add_child(card)


func _build_disc_card() -> void:
	var card := Card.new("Disco y radial")
	var discs: Array = []
	for id in RadialManual.DISCS:
		discs.append([id, str(Abrasives.DISCS[id]["name"]).get_slice(" (", 0)])
	var dc := Style.chips(discs, func(id: String) -> void: state.set_radial("disc_id", id))
	disc_chips = dc.buttons
	card.body.add_child(dc.box)
	disc_info = Style.label("", "TallerNota", true)
	card.body.add_child(disc_info)
	card.body.add_child(Style.label("Diámetro (solo los que el fabricante hace de ese disco)", "TallerTenue", true))
	diam_box = HFlowContainer.new()
	card.body.add_child(diam_box)
	rpm_slider = Style.slider("Rueda de velocidad: rpm pedidas (la radial nunca pasa de las marcadas en el disco)", 0.0, 16000.0, 50.0,
		func(v: float) -> void: state.set_radial("rpm", v))
	_a11y(rpm_slider.slider, "Rueda de velocidad", "Las rpm que se piden (Alt + rueda del ratón, o las teclas + y −). La radial no pasa de su máximo ni de las rpm marcadas en el disco.")
	card.body.add_child(rpm_slider.row)
	var srow := HBoxContainer.new()
	check_label = Style.label("", "TallerTenue", true)
	srow.add_child(check_label)
	stripe_box = HBoxContainer.new()
	stripe_box.add_theme_constant_override("separation", 2)
	srow.add_child(stripe_box)
	card.body.add_child(srow)
	check_warn = Style.label("", "TallerMal", true)
	card.body.add_child(check_warn)
	pane.side.add_child(card)


func _build_cut_card() -> void:
	var card := Card.new("Chapa y corte")
	var coches: Array = []
	var rescate: Array = []
	for id in RadialManual.PANELS:
		var p := Panels.get_panel(id)
		var item := [id, "%s · %s mm" % [str(Looks.panel(id)["short"]), Fmt.num(p["t_mm"], 1)]]
		if str(p["group"]) == "rescate":
			rescate.append(item)
		else:
			coches.append(item)
	card.body.add_child(Style.label("Carrocerías del laboratorio", "TallerTenue", true))
	var pc := Style.chips(coches, func(id: String) -> void: state.set_radial("panel_id", id))
	card.body.add_child(pc.box)
	card.body.add_child(Style.label("Piezas de rescate (acero y aluminio sin pintura)", "TallerTenue", true))
	var rc := Style.chips(rescate, func(id: String) -> void: state.set_radial("panel_id", id))
	card.body.add_child(rc.box)
	# Una sola selección entre los dos grupos
	var group := ButtonGroup.new()
	panel_chips = pc.buttons.merged(rc.buttons)
	for k in panel_chips:
		(panel_chips[k] as Button).button_group = group
	panel_info = Style.label("", "TallerNota", true)
	card.body.add_child(panel_info)
	angle_slider = Style.slider("Ángulo del disco (0° = perpendicular a la chapa)", -45.0, 45.0, 1.0,
		func(v: float) -> void: state.set_radial("angle_deg", v))
	_a11y(angle_slider.slider, "Ángulo del disco", "Inclinación del disco sobre la línea de corte (Q y E, o Mayús + arrastre vertical).")
	card.body.add_child(angle_slider.row)
	feed_slider = Style.slider("Avance pedido: el de los botones y la predicción (0 = lo que den la radial y el empuje)", 0.0, 60.0, 1.0,
		func(v: float) -> void: state.set_radial("feed_mm_s", v))
	_a11y(feed_slider.slider, "Avance pedido", "Velocidad a lo largo del corte de los botones Atrás y Adelante y de la predicción.")
	card.body.add_child(feed_slider.row)
	pane.side.add_child(card)


func _build_result_card() -> void:
	result_card = Card.new("Predicción de un corte completo (cut_panel)", "estimación")
	var head := HBoxContainer.new()
	head.add_child(Style.label("Limpieza", "TallerTenue"))
	clean_bar = Style.bar("coral")
	clean_bar.custom_minimum_size.y = 14.0
	clean_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(clean_bar)
	clean_value = Style.label("", "TallerDato")
	head.add_child(clean_value)
	result_card.body.add_child(head)
	result_card.body.add_child(Style.label("0 limpio · 10 sucio · con los ajustes de arriba y el avance pedido, de lado a lado de 200 mm", "TallerNota", true))
	var g := Style.grid()
	for k in [["time", "Tiempo del corte"], ["feed", "Avance real"], ["vs", "Velocidad del borde"], ["kerf", "Surco"],
			["burr", "Rebaba por lado"], ["haz", "Zona > 200 °C"], ["tint", "Borde del surco"], ["paint", "Pintura quemada"],
			["sparks", "Chispas"], ["wear", "Disco"], ["deform", "Deformación"], ["smoke", "Humo · fundido"],
			["energy", "Energía · potencia"]]:
		res[k[0]] = Style.grid_row(g, k[1], "TallerTenue")
	result_card.body.add_child(g)
	result_card.body.add_child(Style.label("Colores de revenido, del surco hacia fuera", "TallerNota", true))
	tint_box = HBoxContainer.new()
	tint_box.add_theme_constant_override("separation", 2)
	result_card.body.add_child(tint_box)
	sources_label = Style.label("", "TallerNota", true)
	result_card.body.add_child(sources_label)
	pane.side.add_child(result_card)


func _build_warn_card() -> void:
	var card := Card.new("Avisos del montaje", "con su fuente")
	warn_list = VBoxContainer.new()
	card.body.add_child(warn_list)
	pane.side.add_child(card)


## Nombre completo de la chapa (el del modelo), su espesor y su pintura.
static func _panel_name(p: Dictionary) -> String:
	var paint := float(p.get("paint_um", 0.0))
	return "%s · %s mm%s" % [str(p["name"]), Fmt.num(p["t_mm"], 2), (" + pintura de %s µm" % Fmt.num(paint, 0)) if paint > 0.0 else " · sin pintura"]


## Nombre y descripción para los lectores de pantalla (y tooltip para el ratón).
static func _a11y(c: Control, a_name: String, description: String) -> void:
	c.accessibility_name = a_name
	c.accessibility_description = description
	c.tooltip_text = description


## Cambia el recorrido y el valor de un deslizador sin emitir value_changed: si el tope nuevo recorta el valor, ese
## recorte no se manda al estado como si lo hubiera elegido el usuario (el mismo patrón que la fresadora).
static func _set_slider(s: HSlider, lo: float, hi: float, v: float) -> void:
	s.set_block_signals(true)
	s.min_value = lo
	s.max_value = hi
	s.value = v
	s.set_block_signals(false)


# ─────────────────────────── escena 3D ───────────────────────────

func set_compact(on: bool) -> void:
	compact = on
	pane.set_compact(on)
	view3d.custom_minimum_size = Vector2(240, 300 if on else 320)
	inset_check.visible = not on
	help_label.text = HELP_TOUCH if on else HELP_MOUSE
	for k in hold_buttons:
		(hold_buttons[k] as Button).custom_minimum_size.y = 52.0 if on else 40.0
	trigger_button.custom_minimum_size.y = 52.0 if on else 40.0
	_update_insets()


## Al abrir la pestaña nada arranca: la radial se apaga, se para y se aparta (el corte hecho se queda) y, si estaba la
## demostración, se vuelve al mando manual.
func on_shown() -> void:
	view3d.ensure_scene()
	if demo:
		set_demo(false)
	manual.park()
	_hold_u = 0.0
	_hold_d = 0.0
	_keys.clear()
	frame = manual.frame
	if radial3d != null:
		radial3d.call("show_frame", frame)
	_update_live(frame)


## Antes de entrar en el árbol: la escena arranca en el modo manual, con la radial de la página y los ajustes del estado.
func _configure_scene(scene: Node) -> void:
	scene.set("auto_start", false)
	scene.set("mode", "manual")
	scene.set("manual", manual)
	scene.set("frame", frame)
	scene.set("params", state.radial.duplicate())
	scene.set("result", state.radial_result)


func _on_scene_ready(scene: Node) -> void:
	radial3d = scene as Node3D
	radial3d.connect("cut_finished", _on_cut_finished)
	radial3d.connect("gesture_finished", _on_gesture_finished)
	radial3d.connect("dial_step_requested", dial_step)
	radial3d.call("set_view", view)
	_update_insets()


func _on_cut_finished() -> void:
	_loop_wait = LOOP_PAUSE_S


## Se ha soltado el ratón tras girar o inclinar la radial: el ángulo pasa a los ajustes (y a la predicción).
func _on_gesture_finished() -> void:
	var tilt := snappedf(manual.tilt_deg, 0.1)
	if absf(tilt - float(state.radial["angle_deg"])) > 0.05:
		_synced_angle = tilt
		state.set_radial("angle_deg", tilt)


func set_view(id: String) -> void:
	view = id
	Style.pick_chip(view_chips, id)
	if radial3d != null:
		radial3d.call("set_view", id)


func _update_insets() -> void:
	if radial3d == null:
		return
	var on := not compact and inset_check.button_pressed and view3d.size.y >= INSET_MIN_H and view3d.size.x >= INSET_MIN_W
	radial3d.call("set_inset", on)


## Demostración: el corte automático de siempre (cut_panel con los ajustes de las tarjetas), en bucle, sin la mano.
func set_demo(on: bool) -> void:
	demo = on
	demo_button.set_pressed_no_signal(on)
	demo_button.text = "Volver al mando manual" if on else "Ver demostración"
	manual.park()
	_hold_u = 0.0
	_hold_d = 0.0
	frame = manual.frame
	if radial3d != null:
		radial3d.set("input_enabled", not on)
		radial3d.call("set_mode", "auto" if on else "manual")
		if on:
			radial3d.call("set_params", state.radial.duplicate())
			radial3d.call("set_result", state.radial_result)
			_restart = true
		else:
			radial3d.call("show_frame", frame)
	_update_live(frame)


## Chapa nueva, sin cortar (la radial se aparta).
func reset_panel() -> void:
	manual.reset_panel()
	frame = manual.step(0.0)
	_update_live(frame)


# ─────────────────────────── la mano ───────────────────────────

## Gatillo (el botón y la tecla Espacio).
func set_trigger(on: bool) -> void:
	if demo:
		set_demo(false)
	manual.set_trigger(on)
	trigger_button.set_pressed_no_signal(manual.trigger)


func toggle_trigger() -> void:
	set_trigger(not manual.trigger)


## Mueve la rueda de velocidad k posiciones (Alt + rueda del ratón, teclas + y −): pasa por el estado como el deslizador.
func dial_step(k: int) -> void:
	var rpm := RadialManual.dial_step_rpm(manual.machine(), float(state.radial["rpm"]), k)
	if rpm != float(state.radial["rpm"]):
		state.set_radial("rpm", rpm)


func _hold(which: String, down: bool) -> void:
	var dir := 1.0 if down else 0.0
	match which:
		"atras":
			_hold_u = -dir
		"adelante":
			_hold_u = dir
		"acercar":
			_hold_d = dir
		"apartar":
			_hold_d = -dir


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo or not is_visible_in_tree():
		return
	var code := k.keycode
	var handled := true
	match code:
		KEY_SPACE:
			if k.pressed:
				toggle_trigger()
		KEY_V:
			if k.pressed:
				manual.flip()
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			if k.pressed:
				dial_step(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			if k.pressed:
				dial_step(-1)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_Q, KEY_E, KEY_Z, KEY_X:
			if k.pressed:
				_keys[code] = true
			else:
				_keys.erase(code)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Velocidades de la mano de los botones que se mantienen pulsados y de las teclas: mm/s a lo largo y hacia dentro.
func _hand_velocity() -> Vector2:
	var along := _hold_u + (1.0 if _keys.has(KEY_RIGHT) else 0.0) - (1.0 if _keys.has(KEY_LEFT) else 0.0)
	var down := _hold_d + (1.0 if _keys.has(KEY_DOWN) else 0.0) - (1.0 if _keys.has(KEY_UP) else 0.0)
	var feed := float(state.radial["feed_mm_s"])
	if feed <= 0.0:
		# «máximo»: un poco menos de lo que el disco puede cortar ahora
		feed = maxf(0.95 * float(frame.get("feed_cap_mm_s", 0.0)), 5.0)
	# Los botones y las teclas son la mano de quien no fuerza la radial: si ya empuja casi lo que el motor aguanta sin
	# perder vueltas (push_limit_n del core), no se adelanta más y va a lo que corta el disco. Para forzarla, el ratón.
	if bool(frame.get("cutting", false)) and float(frame.get("push_n", 0.0)) > 0.95 * float(frame.get("push_limit_n", 0.0)):
		feed = minf(feed, 0.9 * float(frame.get("feed_mm_s", 0.0)))
	var near := float(frame.get("depth_mm", -99.0)) > -NEAR_MM
	var approach := APPROACH_FAR_MM_S
	if near and down > 0.0:
		# dentro de la chapa, sin pasar de lo que el disco puede entrar (como quien no fuerza la radial al bajar)
		approach = APPROACH_NEAR_MM_S
		var plunge_cap := float(frame.get("plunge_cap_mm_s", 0.0))
		if plunge_cap > 0.0:
			approach = minf(approach, 0.9 * plunge_cap)
	return Vector2(clampf(along, -1.0, 1.0) * feed, clampf(down, -1.0, 1.0) * approach)


func tick(delta: float) -> void:
	if demo:
		_tick_demo(delta)
		return
	var v := _hand_velocity()
	manual.set_hand_velocity(v.x, v.y)
	var turn := Vector2(
		((1.0 if _keys.has(KEY_X) else 0.0) - (1.0 if _keys.has(KEY_Z) else 0.0)) * YAW_DEG_S * delta,
		((1.0 if _keys.has(KEY_E) else 0.0) - (1.0 if _keys.has(KEY_Q) else 0.0)) * TILT_DEG_S * delta)
	if turn != Vector2.ZERO:
		manual.turn_hand(turn.x, turn.y)
	frame = manual.step(delta)
	if radial3d != null:
		radial3d.call("show_frame", frame)
	_update_live(frame)


func _tick_demo(delta: float) -> void:
	if radial3d == null:
		return
	if _loop_wait > 0.0:
		_loop_wait -= delta
		if _loop_wait <= 0.0:
			_restart = true
	if _restart:
		_restart = false
		_loop_wait = -1.0
		radial3d.call("start_cut", PRE_CUT_MM, 0.3)


## ¿Está el disco cortando ahora? (para el sonido de la sección)
func cutting_now() -> bool:
	if demo:
		if radial3d == null:
			return false
		return bool((radial3d.call("info") as Dictionary).get("cutting", false))
	return bool(frame.get("cutting", false))


## Entrada de sonido de la radial (CONTRATOS.md): en el modo manual, la del core (proceso «grinder», rpm reales y
## potencia de corte; apagada, en silencio); en la demostración, la del corte automático.
func sound_input() -> Dictionary:
	if demo:
		return state.radial_sound_input(cutting_now())
	return frame.get("sound", { "process": "grinder", "rpm": 0.0 })


# ─────────────────────────── lecturas en directo ───────────────────────────

## Lecturas bajo la vista, estado del gatillo y avisos en directo: solo se cambian textos y visibilidad.
func _update_live(f: Dictionary) -> void:
	if reads.is_empty():
		return
	var rpm := float(f["rpm"])
	var rpm_txt := Fmt.unit(rpm, 0, "rpm")
	if bool(f["powered"]) and absf(rpm - float(f["rpm_set"])) > 0.01 * float(f["rpm_set"]):
		rpm_txt += " (fijadas %s)" % Fmt.num(f["rpm_set"], 0)
	reads["rpm"].text = rpm_txt
	reads["vs"].text = Fmt.unit(f["vs_ms"], 1, "m/s")
	var feed_txt := Fmt.unit(f["feed_mm_s"], 1, "mm/s")
	if bool(f["contact"]) and float(f["feed_want_mm_s"]) > 0.05:
		feed_txt += " · pides %s · puede %s" % [Fmt.num(f["feed_want_mm_s"], 1), Fmt.num(f["feed_cap_mm_s"], 1)]
	reads["feed"].text = feed_txt
	var depth := float(f["depth_mm"])
	if depth < 0.0:
		reads["depth"].text = "apartada %s" % Fmt.unit(-depth, 1, "mm")
	else:
		reads["depth"].text = "%s bajo la pintura%s" % [Fmt.unit(depth, 2, "mm"), " · atraviesa" if depth >= float(f["total_mm"]) - 1e-6 else ""]
	reads["tilt"].text = Fmt.unit(f["tilt_deg"], 0, "°")
	reads["yaw"].text = Fmt.unit(f["yaw_deg"], 0, "°")
	var cut_txt := Fmt.unit(f["cut_length_mm"], 1, "mm")
	if float(f["groove_length_mm"]) > float(f["cut_length_mm"]) + 0.5:
		cut_txt += " · surco %s" % Fmt.unit(f["groove_length_mm"], 1, "mm")
	reads["cut"].text = cut_txt
	var clean := float(f["cleanliness"])
	reads["clean"].text = "—" if clean < 0.0 else "%s/10 · %s" % [Fmt.num(clean, 1), clean_word(clean)]
	state_label.text = "%s · %s" % [str(f["machine"]), STATE_TEXT.get(str(f["state"]), str(f["state"]))]
	trigger_button.set_pressed_no_signal(bool(f["trigger"]))
	trigger_button.text = "Apagar (Espacio)" if bool(f["trigger"]) else "Encender (Espacio)"
	var ws: Array = f["warnings"]
	for i in LIVE_WARN_SLOTS:
		var on := i < ws.size()
		live_warns[i].visible = on
		live_srcs[i].visible = on and str(ws[i]["source"]) != ""
		if on:
			var w: Dictionary = ws[i]
			var variation := "TallerMal" if w["level"] == "peligro" else ("TallerAviso" if w["level"] == "aviso" else "TallerTenue")
			if live_warns[i].theme_type_variation != variation:
				live_warns[i].theme_type_variation = variation
			if live_warns[i].text != str(w["message"]):
				live_warns[i].text = str(w["message"])
			var src := "Fuente: " + str(w["source"])
			if live_srcs[i].text != src:
				live_srcs[i].text = src
	var top := ""
	if ws.size() > 0 and ws[0]["level"] == "peligro":
		top = str(ws[0]["message"])
	if top_warn.text != top:
		top_warn.text = top
	top_warn.visible = top != ""


## Palabra de la limpieza del corte (0 limpio … 10 sucio), la misma escala que la demo guionizada.
static func clean_word(c: float) -> String:
	if c < 3.0:
		return "limpio"
	if c < 5.5:
		return "aceptable"
	if c < 7.5:
		return "sucio"
	return "muy sucio"


# ─────────────────────────── cambios del estado ───────────────────────────

func refresh() -> void:
	if state == null:
		return
	var p: Dictionary = state.radial
	var r: Dictionary = state.radial_result
	var ck: Dictionary = state.radial_check
	# La radial de la mano con los ajustes: otro disco, diámetro o chapa (la radial se para o se aparta, como en la
	# realidad), rueda de velocidad y, si ha cambiado en las tarjetas, el ángulo
	manual.set_disc(str(p["disc_id"]))
	manual.set_diameter(float(p["diameter_mm"]))
	manual.set_panel(str(p["panel_id"]))
	manual.set_dial_rpm(float(p["rpm"]))
	if float(p["angle_deg"]) != _synced_angle:
		_synced_angle = float(p["angle_deg"])
		manual.set_tilt(_synced_angle)
	frame = manual.step(0.0)
	_update_live(frame)
	Style.pick_chip(disc_chips, p["disc_id"])
	Style.pick_chip(panel_chips, p["panel_id"])
	var disc: Dictionary = Abrasives.DISCS.get(str(p["disc_id"]), {})
	disc_info.text = "%s · %s" % [str(disc.get("name", "")), str(disc.get("standard", ""))]
	panel_info.text = _panel_name(Panels.get_panel(str(p["panel_id"])))
	_fill_diameters()
	# Rueda de velocidad: el deslizador llega un 30 % por encima del límite para poder ver el aviso de exceso (la radial
	# se queda siempre en el límite)
	var limit := float(ck["limit_rpm"])
	var over := bool(ck["over_speed"])
	_set_slider(rpm_slider.slider, 0.0, ceilf(maxf(limit, float(manual.machine()["rpm_max"])) * 1.3 / 500.0) * 500.0, float(p["rpm"]))
	(rpm_slider.value as Label).text = Fmt.unit(p["rpm"], 0, "rpm")
	(rpm_slider.value as Label).theme_type_variation = "TallerMal" if over else "TallerDato"
	var src := "marcadas en el disco" if ck["disc_rpm"] != null else ("tabla de EN 12413" if ck["marked_rpm"] != null else "fórmula")
	var mach := manual.machine()
	var dial_txt := "rueda de %s a %s rpm" % [Fmt.num((mach["dial_rpm"] as Array)[0], 0), Fmt.num(mach["rpm_max"], 0)] if not (mach["dial_rpm"] as Array).is_empty() else "sin rueda de velocidad, %s rpm" % Fmt.num(mach["rpm_max"], 0)
	check_label.text = "Borde a %s · límite %s (%s) · %s: %s; gira a %s" % [Fmt.unit(ck["speed_ms"], 1, "m/s"), Fmt.unit(limit, 0, "rpm"), src,
		str(mach["name"]), dial_txt, Fmt.unit(manual.set_rpm(), 0, "rpm")]
	check_warn.text = str(ck["warning"])
	check_warn.visible = over
	Style.clear(stripe_box)
	for c in ck.get("stripe", []):
		stripe_box.add_child(Style.swatch(Color(STRIPE_HEX.get(str(c), "#888888")), 10.0))
	_set_slider(angle_slider.slider, -45.0, 45.0, float(p["angle_deg"]))
	(angle_slider.value as Label).text = Fmt.unit(p["angle_deg"], 0, "°")
	_set_slider(feed_slider.slider, 0.0, 60.0, float(p["feed_mm_s"]))
	(feed_slider.value as Label).text = "máximo" if float(p["feed_mm_s"]) <= 0.0 else Fmt.unit(p["feed_mm_s"], 0, "mm/s")
	_set_slider(yaw_slider.slider, -180.0, 180.0, manual.yaw_deg)
	(yaw_slider.value as Label).text = Fmt.unit(manual.yaw_deg, 0, "°")
	_fill_result(r, p)
	_fill_warnings(r)
	if demo and radial3d != null:
		radial3d.call("set_params", p.duplicate())
		radial3d.call("set_result", r)
		_restart = true


func _fill_diameters() -> void:
	var ds := state.radial_diameters()
	var key := "%s" % [ds]
	if key != _diam_key:
		_diam_key = key
		Style.clear(diam_box)
		var items: Array = []
		for d: float in ds:
			items.append([d, Fmt.num(d, 0) + " mm"])
		diam_chips = Style.chips(items, func(d: float) -> void: state.set_radial("diameter_mm", d), diam_box).buttons
	Style.pick_chip(diam_chips, float(state.radial["diameter_mm"]))


func _fill_result(r: Dictionary, p: Dictionary) -> void:
	var clean := float(r.get("cleanliness", 0.0))
	clean_bar.value = clampf(clean / 10.0, 0.0, 1.0)
	clean_value.text = Fmt.num(clean, 1)
	var t := float(r.get("time_s", INF))
	res["time"].text = "no corta" if is_inf(t) else "%s para %s" % [Fmt.seconds(t), Fmt.unit(p["cut_length_mm"], 0, "mm")]
	var lim := str({"potencia": " (lo limita la potencia)", "empuje": " (lo limita el empuje)"}.get(str(r.get("limited_by", "")), ""))
	res["feed"].text = Fmt.unit(r.get("feed_mm_s"), 1, "mm/s") + lim
	res["vs"].text = Fmt.unit(r.get("vs_ms"), 1, "m/s")
	res["kerf"].text = "%s · en la chapa %s" % [Fmt.unit(r.get("kerf_mm"), 2, "mm"), Fmt.unit(r.get("kerf_surface_mm"), 2, "mm")]
	var bs: Dictionary = r.get("burr_sides_um", {})
	res["burr"].text = "lado − %s · lado + %s" % [Fmt.unit(bs.get("lado_menos"), 0, "µm"), Fmt.unit(bs.get("lado_mas"), 0, "µm")]
	res["haz"].text = Fmt.unit(r.get("haz_mm"), 2, "mm a cada lado")
	var tint: Dictionary = r.get("heat_tint", {})
	res["tint"].text = "%s · %s" % [Fmt.unit(tint.get("temp_c"), 0, "°C"), str(tint.get("name", ""))]
	var paint_um := float(Panels.get_panel(str(p["panel_id"])).get("paint_um", 0.0))
	res["paint"].text = "sin pintura" if paint_um <= 0.0 else Fmt.unit(r.get("paint_burn_mm"), 1, "mm a cada lado")
	var sp: Dictionary = r.get("sparks", {})
	if float(sp.get("rate", 0.0)) <= 0.0:
		res["sparks"].text = "ninguna"
	else:
		res["sparks"].text = "%s por segundo · %s → %s · %s · estallidos: %s" % [Fmt.num(sp.get("rate"), 0), str(sp.get("color_name", "")),
			str(sp.get("color_end_name", "")), Fmt.unit(sp.get("length_mm"), 0, "mm"), str(sp.get("bursts_name", ""))]
	res["wear"].text = "desgaste %s · embotado %s %%" % [Fmt.unit(r.get("disc_wear_mm3"), 1, "mm³"), Fmt.num(float(r.get("disc_loading", 0.0)) * 100.0, 0)]
	res["deform"].text = Fmt.unit(r.get("deformation"), 3, "mm")
	res["smoke"].text = "%s · %s" % [Fmt.num(r.get("smoke"), 2), Fmt.num(r.get("melt"), 2)]
	res["energy"].text = "%s · %s" % [Fmt.unit(r.get("specific_energy_j_mm3"), 1, "J/mm³"), Fmt.unit(r.get("power_kw"), 2, "kW")]
	Style.clear(tint_box)
	for b in tint.get("bands", []):
		var sw := Style.swatch(Color.html(str(b["color"])) if Color.html_is_valid(str(b["color"])) else Style.c("dim"), 22.0)
		sw.tooltip_text = "%s · %s–%s mm" % [str(b.get("name", "")), Fmt.num(b.get("from_mm"), 2), Fmt.num(b.get("to_mm"), 2)]
		tint_box.add_child(sw)
	if tint_box.get_child_count() == 0:
		tint_box.add_child(Style.label("sin colores de revenido", "TallerNota"))
	result_card.set_hint("calidad: " + Fmt.quality(r.get("quality", "estimate")))
	sources_label.text = "Fuentes: " + "; ".join(PackedStringArray(r.get("sources", [])))


func _fill_warnings(r: Dictionary) -> void:
	Style.clear(warn_list)
	for w in r.get("warnings", []):
		var code := str(w.get("code", ""))
		var v := "TallerMal" if code in ["exceso_velocidad", "pilar_boro", "acunamiento", "disco_fijo"] or code.begins_with("rescate") else "TallerAviso"
		warn_list.add_child(Style.label(str(w.get("message", "")), v, true))
		if str(w.get("source", "")) != "":
			warn_list.add_child(Style.label("Fuente: " + str(w["source"]), "TallerNota", true))
