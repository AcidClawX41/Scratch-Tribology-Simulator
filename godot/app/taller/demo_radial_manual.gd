## Demo de la radial en modo manual (e2e de la unidad 2c): la radial en tus manos con la entrada simulada por eventos
## de verdad (tecla Espacio, rueda y arrastres del ratón con y sin Mayús, empujados a la ventana con push_input), que
## recorren el mismo camino que los de una persona: la escena los traduce a la mano de core/taller/radial_manual.gd, y
## esta demo avanza el core y pinta su salida, como hace la página.
##   0-1,5 s     la pestaña se abre: apagada y apartada        1,5 s       Espacio: se enciende (arranque de ~1,5 s)
##   3-8 s       rueda: se acerca y entra despacio en la chapa 8-12 s      arrastre: corta a lo largo a 15 mm/s
##   12-13,5 s   Mayús + arrastre: inclina el disco cortando   13,5-15 s   arrastre ↑: se aparta (y se endereza)
##   15 s        Espacio: se apaga y para por inercia          16 s        se cambia al disco grueso de 3,2 mm
##   16,5-25 s   se enciende, entra y corta un tramo con el disco grueso a 5 mm/s: un surco más ancho
## Guion de quien no fuerza la radial: los avances van por debajo de lo que corta cada disco y la rueda baja 1 mm/s.
## Captura (bajo Xvfb, lenta): npm run godot:capture -- res://app/taller/demo_radial_manual.tscn --frames=250 --fps=10
## --out=<carpeta>. El tiempo es la suma de los delta (Movie Maker los da fijos): cada fotograma es siempre igual.
## Para revisar otra chapa: … -- --chapa=boro-22mnb5 (o cualquier id de RadialManual.PANELS).
extends Node

const RadialManual = preload("res://core/taller/radial_manual.gd")
const HandInput = preload("res://app/taller/radial3d/hand_input.gd")
const MachineSoundPlayer = preload("res://app/taller/machine_sound_player.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Palette = preload("res://app/theme/palette.gd")
const MONO = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const MONO_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")
const DISP = preload("res://assets/fonts/syne-latin-700-normal.woff2")

## Qué se ve en cada tramo (s, texto).
const STEPS := [
	[0.0, "1 · La pestaña se abre: la radial está apagada y apartada de la chapa"],
	[1.5, "2 · Espacio (gatillo): arranca con la corriente limitada, ~1,5 s hasta 11.500 rpm"],
	[3.0, "3 · Rueda del ratón: se acerca y entra despacio en la chapa"],
	[8.0, "4 · Arrastre ← →: corta a lo largo de la línea a 15 mm/s"],
	[12.0, "5 · Mayús + arrastre ↑ ↓: inclina el disco sin dejar de cortar"],
	[13.5, "6 · Arrastre ↑: se aparta de la chapa (y con Mayús se endereza)"],
	[15.0, "7 · Espacio: se suelta el gatillo y el disco para por inercia (sin freno)"],
	[16.0, "8 · Otro disco: el grueso de 3,2 mm (para cambiarlo, la radial se para y se saca)"],
	[16.5, "9 · Se enciende, entra y corta un tramo con el disco grueso: el surco sale más ancho"],
]
## Avances del guion: por debajo de lo que corta cada disco en acero dulce (unos 19 mm/s el fino y 7 mm/s el grueso, a
## 11.500 rpm), como quien no fuerza la radial.
const CUT_FEED_MM_S := 15.0
const SECOND_FEED_MM_S := 5.0
const TILT_RATE_DEG_S := 10.0
## Ritmo de la rueda del ratón: una muesca cada 0,1 s (10 por segundo, lo que da un dedo sin prisa); cerca de la chapa
## cada muesca baja 0,1 mm (hand_input.gd), 1 mm/s.
const WHEEL_NOTCH_S := 0.1
## Al apartarla, arrastre hacia arriba a 20 mm/s.
const RETREAT_MM_S := 20.0

var manual: RadialManual
var sound: MachineSoundPlayer
var _t := 0.0
var _labels := {}
var _warn_labels: Array[Label] = []
## Fotogramas de la grabación (--quit-after de Movie Maker; -1 si no se graba) y los ya pintados: en el último se
## sueltan las voces para que Godot no avise al salir de reproducciones vivas.
var _quit_after := -1
var _frames := 0
var _wheel_acc := 0.0

@onready var radial: Node3D = $Radial3D


func _ready() -> void:
	var panel := "acero-dulce"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapa="):
			panel = a.substr(8)
	var args := OS.get_cmdline_args()
	for i in args.size() - 1:
		if args[i] == "--quit-after":
			_quit_after = int(args[i + 1])
	manual = RadialManual.new("fino_1mm", panel)
	radial.set("manual", manual)
	radial.call("set_mode", "manual")
	radial.call("show_frame", manual.frame)
	radial.call("set_view", "detalle")
	sound = MachineSoundPlayer.new()
	sound.use_3d = false
	add_child(sound)
	_build_hud()


## La tecla Espacio es el gatillo (como en la página).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_SPACE:
		manual.toggle_trigger()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var t0 := _t
	_t += delta
	_script(t0, _t, delta)
	var f := manual.step(delta)
	radial.call("show_frame", f)
	_frames += 1
	if _quit_after > 0 and _frames >= _quit_after - 3:
		# fin de la grabación: se sueltan las voces unos fotogramas antes, para que el servidor de audio las libere
		if _frames == _quit_after - 3:
			sound.stop_now()
	else:
		sound.set_input(f["sound"])
	_update_hud(f)


# ───────────────────────────── el guion (eventos de entrada de verdad) ─────────────────────────────

func _script(t0: float, t1: float, dt: float) -> void:
	var total := float(manual.frame["total_mm"])
	_wheel_acc += dt
	var notch := _wheel_acc >= WHEEL_NOTCH_S
	if notch:
		_wheel_acc -= WHEEL_NOTCH_S
	if _crossed(t0, t1, 1.5) or _crossed(t0, t1, 15.0) or _crossed(t0, t1, 16.5):
		_key(KEY_SPACE)
	if notch and t1 > 3.0 and t1 <= 8.0 and manual.hand_depth < total + 3.0:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	if _crossed(t0, t1, 8.0) or _crossed(t0, t1, 22.5):
		_button(MOUSE_BUTTON_LEFT, true)
	if t1 > 8.0 and t1 <= 13.5:
		_drag_along(CUT_FEED_MM_S * dt)
	if t1 > 12.0 and t1 <= 13.5:
		_drag_turn(0.0, TILT_RATE_DEG_S * dt)
	if _crossed(t0, t1, 13.5) or _crossed(t0, t1, 25.0):
		_button(MOUSE_BUTTON_LEFT, false)
	if t1 > 13.5 and t1 <= 15.0:
		if manual.hand_depth > -25.0:
			_button(MOUSE_BUTTON_LEFT, true)
			_drag_out(RETREAT_MM_S * dt)  # arrastre hacia arriba: la aparta deprisa (la rueda va fina cerca de la chapa)
			_button(MOUSE_BUTTON_LEFT, false)
		if manual.tilt_deg > 0.5:
			_button(MOUSE_BUTTON_LEFT, true)
			_drag_turn(0.0, -minf(manual.tilt_deg, 2.0 * TILT_RATE_DEG_S * dt))
			_button(MOUSE_BUTTON_LEFT, false)
	if _crossed(t0, t1, 16.0):
		manual.set_disc("grueso_3mm")  # lo que hace la ficha del disco en la página
	if notch and t1 > 17.5 and t1 <= 22.5 and manual.hand_depth < total + 2.5:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	if t1 > 22.5 and t1 <= 25.0:
		_drag_along(SECOND_FEED_MM_S * dt)


static func _crossed(t0: float, t1: float, at: float) -> bool:
	return t0 < at and t1 >= at


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev, true)


func _button(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = get_viewport().get_visible_rect().size * 0.5
	get_viewport().push_input(ev, true)


func _wheel(button: MouseButton) -> void:
	_button(button, true)
	_button(button, false)


## Arrastre con el botón izquierdo que lleva la radial du mm a lo largo de la línea: los píxeles salen de la escala de la
## vista junto al disco (radial_3d.gd, input_geometry), como los movería una persona que sigue la línea en la pantalla.
func _drag_along(du_mm: float) -> void:
	var geo: Dictionary = radial.call("input_geometry")
	var ev := InputEventMouseMotion.new()
	ev.relative = (geo["px_u"] as Vector2) * du_mm
	ev.position = get_viewport().get_visible_rect().size * 0.5
	get_viewport().push_input(ev, true)


## Arrastre con el botón izquierdo que aparta la radial mm de la chapa (hacia fuera de la cara pintada en la pantalla).
func _drag_out(mm: float) -> void:
	var geo: Dictionary = radial.call("input_geometry")
	var ev := InputEventMouseMotion.new()
	ev.relative = (geo["px_n"] as Vector2) * mm
	ev.position = get_viewport().get_visible_rect().size * 0.5
	get_viewport().push_input(ev, true)


## Mayús + arrastre: giro (grados) e inclinación (grados) de la radial.
func _drag_turn(dyaw_deg: float, dtilt_deg: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.shift_pressed = true
	ev.relative = Vector2(dyaw_deg / HandInput.YAW_DEG_PX, dtilt_deg / HandInput.TILT_DEG_PX)
	ev.position = get_viewport().get_visible_rect().size * 0.5
	get_viewport().push_input(ev, true)


# ───────────────────────────── rótulos ─────────────────────────────

func _update_hud(f: Dictionary) -> void:
	var step := ""
	for s in STEPS:
		if _t >= float(s[0]):
			step = str(s[1])
	_labels["step"].text = step
	var state: String = { "apagada": "apagada", "arrancando": "arrancando", "en_marcha": "en marcha",
		"parando": "parando por inercia", "desconectada": "desconectada por rebote", "calada": "calada" }.get(str(f["state"]), str(f["state"]))
	_labels["machine"].text = "%s · disco %s Ø%s · %s · rueda %s" % [str(f["machine"]), str(f["disc_id"]).replace("_", " "),
		Fmt.num(f["diameter_mm"], 0), state, Fmt.num(f["dial_pos"], 1) if bool(f["dial"]) else "—"]
	var depth := float(f["depth_mm"])
	var depth_txt := "apartada %s" % Fmt.unit(-depth, 1, "mm") if depth < 0.0 else "dentro %s" % Fmt.unit(depth, 2, "mm")
	_labels["reads"].text = "%s · %s · avance %s · %s · ángulo %s · giro %s" % [
		Fmt.unit(f["rpm"], 0, "rpm"), Fmt.unit(f["vs_ms"], 1, "m/s"), Fmt.unit(f["feed_mm_s"], 1, "mm/s"), depth_txt,
		Fmt.unit(f["tilt_deg"], 0, "°"), Fmt.unit(f["yaw_deg"], 0, "°")]
	var clean := float(f["cleanliness"])
	_labels["cut"].text = "cortado %s · limpieza %s · potencia %s · chispas %s/s · disco gastado %s" % [
		Fmt.unit(f["cut_length_mm"], 1, "mm"), (Fmt.num(clean, 1) + "/10") if clean >= 0.0 else "—",
		Fmt.unit(float(f["power_kw"]), 2, "kW"), Fmt.num(float(f["sparks"].get("rate", 0.0)), 0),
		Fmt.unit(f["disc_wear_mm3"], 1, "mm³")]
	var ws: Array = f["warnings"]
	for i in _warn_labels.size():
		var l := _warn_labels[i]
		l.visible = i < ws.size()
		if i < ws.size():
			var w: Dictionary = ws[i]
			l.text = str(w["message"]) + ((" (" + str(w["source"]) + ")") if str(w["source"]) != "" else "")
			l.add_theme_color_override("font_color", Palette.color("coral" if w["level"] == "peligro" else ("gold" if w["level"] == "aviso" else "ice")))


func _label(parent: Control, font: Font, size: int, color: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(color))
	l.add_theme_color_override("font_outline_color", Color(0.09, 0.05, 0.11, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.color("panel"), 0.86)
	sb.border_color = Palette.color("line2")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(14, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var title := _label(box, DISP, 26, "text")
	title.text = "La radial en tus manos"
	_labels["step"] = _label(box, MONO_BOLD, 15, "mint")
	_labels["machine"] = _label(box, MONO, 14, "dim")
	_labels["reads"] = _label(box, MONO, 14, "text")
	_labels["cut"] = _label(box, MONO, 14, "text")
	for i in 3:
		var w := _label(box, MONO, 13, "gold")
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(720, 0)
		_warn_labels.append(w)
	var foot := _label(root, MONO, 13, "dimmer")
	foot.text = "Ratón: izquierdo mueve la radial · Mayús + izquierdo la gira y la inclina · rueda la acerca o la aparta · derecho gira la cámara · Espacio, gatillo"
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.anchor_right = 1.0
	foot.offset_left = 16.0
	foot.offset_top = -34.0
	foot.offset_right = -16.0
	foot.offset_bottom = -10.0
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
