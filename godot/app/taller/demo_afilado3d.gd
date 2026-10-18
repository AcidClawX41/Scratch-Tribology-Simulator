## Demostración de la afiladora 3D (8 s, en bucle) con el simulador DE PRUEBA de sharpen3d/demo_sim.gd, que da
## DATOS INVENTADOS (temperaturas, rebaba, chispas por segundo): no es la física del afilado, que enchufa la
## oleada 2. Tres casos:
##   0,0–3,2 s  esmeriladora de banco (Einhell TC-BG 150, 2980 rpm) y un cuchillo de cocina de acero al carbono en
##              una pasada lenta: chispas y el filo que pasa de paja a azul (vista general y detalle del filo);
##   3,2–5,6 s  afiladora húmeda lenta (Tormek T-8, 100 rpm): agua, goteo y el filo frío (general y sección);
##   5,6–8,0 s  amoladora con disco de láminas en su posición lenta y un hacha en el tornillo de banco.
## Los colores de revenido son los de la tabla del core (panels.gd → TEMPER_COLORS["acero"], la de
## EdgeThermal.tint()); la escena solo los pinta. El sonido es el de core/taller/machine_sound.gd con
## machine_sound_player.gd (use_3d = false: el paneo sale de tool_pos.x).
## Captura (desde la raíz): npm run godot:capture -- res://app/taller/demo_afilado3d.tscn --frames=240 --out=/tmp/afilado
## Argumentos de usuario (tras --): --caso=banco|humeda|amoladora (empieza en ese caso) · --at=<s> (empieza en ese
## instante) · --vista=general|filo|seccion (fija la vista) · --movil (calidad de móvil).
## Al salir escribe el coste medio y máximo (CPU, sin dibujar) de actualizar la escena en cada fotograma.
extends Node

const DemoSim = preload("res://app/taller/sharpen3d/demo_sim.gd")
const MachineSoundPlayer = preload("res://app/taller/machine_sound_player.gd")
const Panels = preload("res://core/taller/panels.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const FONT_MONO = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const FONT_TITLE = preload("res://assets/fonts/syne-latin-700-normal.woff2")

var sim: DemoSim
var sound: MachineSoundPlayer
var _case := ""
var _view := ""
var _force_view := ""
var _title: Label
var _data: Label
var _recording := false  # con Movie Maker, el sonido se corta al final de cada vuelta del guion (ver _process)

@onready var scene: Node3D = $Afiladora3D


## Entrada de sonido del guion en el instante t (función del tiempo: determinista).
static func sound_input_at(t: float) -> Dictionary:
	return DemoSim.frame_at(t)["sound"]


func _ready() -> void:
	sim = DemoSim.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			var id := a.substr(7)
			for c in DemoSim.CASES:
				if c["id"] == id:
					sim.t = float(c["t0"])
		elif a.begins_with("--at="):
			sim.t = a.substr(5).to_float()
		elif a.begins_with("--vista="):
			_force_view = a.substr(8)
		elif a == "--movil":
			scene.call("set_quality", "movil")
	_recording = Engine.get_write_movie_path() != ""
	# Colores de revenido: la tabla del core para el acero al carbono (EdgeThermal.tint_table elige «acero» o «inox»)
	scene.call("set_temper_ramp", Panels.TEMPER_COLORS["acero"])
	sound = MachineSoundPlayer.new()
	sound.name = "SonidoMaquina"
	sound.use_3d = false
	add_child(sound)
	_build_hud()


func _process(delta: float) -> void:
	var fr := sim.step(delta)
	if fr["case"] != _case:
		_case = fr["case"]
		scene.call("set_machine", fr["machine"])
		scene.call("set_tool", fr["tool"])
	var v: String = _force_view if _force_view != "" else fr["view"]
	scene.call("set_state", fr["state"])
	if v != _view:
		scene.call("set_view", v, _view == "")
		_view = v
	# Grabando, los últimos 0,1 s de cada vuelta van en silencio: si la captura acaba ahí (--frames=240), el servidor
	# de audio ya ha soltado las reproducciones y Godot no avisa al salir de que quedaron vivas
	if _recording and float(fr["t"]) >= DemoSim.DURATION - 0.11:
		sound.stop_now()
	else:
		sound.set_input(fr["sound"])
	_update_hud(fr)


func _exit_tree() -> void:
	var info: Dictionary = scene.call("info")
	if int(info["frames"]) > 0:
		print("Afiladora 3D: %d fotogramas, actualización media %s ms, máxima %s ms (CPU, sin dibujar)" % [
			int(info["frames"]), Js.to_fixed(float(info["update_ms_avg"]), 3), Js.to_fixed(float(info["update_ms_max"]), 3)])


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.color("bg"), 0.78)
	sb.border_color = Color(Palette.color("line2"), 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_label(box, "TALLER INDUSTRIAL · AFILADORA 3D", FONT_TITLE, 17, Palette.color("mint"))
	_title = _label(box, "", FONT_TITLE, 19, Palette.color("text"))
	_data = _label(box, "", FONT_MONO, 14, Palette.color("dim"))
	_label(box, "Simulador de prueba: temperaturas, rebaba y chispas INVENTADAS para enseñar la escena", FONT_MONO, 12,
		Palette.color("dimmer"))


func _label(parent: Control, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _update_hud(fr: Dictionary) -> void:
	_title.text = fr["title"]
	var st: Dictionary = fr["state"]
	var info: Dictionary = scene.call("info")
	var parts := [
		"%s rpm" % _es(float(info["rpm"]), 0),
		"%s m/s" % _es(float(info["peripheral_speed_ms"]), 1),
		"%s°" % _es(float(st["angle_deg"]), 1),
	]
	if bool(st["contact"]):
		parts.append("filo %s °C" % _es(float(st["max_temp_c"]), 0))
	parts.append("t %s s" % _es(float(fr["t"]), 1))
	_data.text = " · ".join(parts)


## Número con coma decimal (Js.to_fixed: el redondeo de JavaScript).
static func _es(x: float, d: int) -> String:
	return Js.to_fixed(x, d).replace(".", ",")
