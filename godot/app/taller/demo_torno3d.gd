## Demostración del torno 3D (unos 10 s). Una fuente de perfil SIMULADA (lathe3d/demo_source.gd), que cumple el
## contrato del perfil, arranca material anillo a anillo —refrentado, desbaste mate, acabado brillante, pulido—
## mientras la herramienta recorre el programa, y la cámara pasa por las vistas. En la integración, la fuente será
## el núcleo del torno (unidad 3) y el programa, el del intérprete Fagor.
##
## Al salir escribe en la consola el coste medio y máximo (CPU) de actualizar la malla de la pieza.
## Argumentos de usuario (tras --), para capturas de un momento concreto:
##   --at=<s>        avanza la simulación hasta ese instante antes del primer fotograma
##   --view=<nombre> fija la vista de cámara (general, frontal, superior, detalle)
##   --overlay=<capa> fija la capa (acabado, desviacion)
##   --orbit=<pitch>,<distancia>  congela la simulación y da una vuelta de cámara (15° por fotograma) alrededor
##                   de la vista pedida: sirve para elegir encuadres
extends Node3D

const DemoSource = preload("res://app/taller/lathe3d/demo_source.gd")
const Palette = preload("res://app/theme/palette.gd")
const FONT_MONO = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const FONT_TITLE = preload("res://assets/fonts/syne-latin-700-normal.woff2")

var src: DemoSource
var _view := ""
var _overlay := ""
var _title: Label
var _op: Label
var _data: Label
var _legend: Control
var _upd_sum := 0
var _upd_n := 0
var _upd_max := 0
var _force_view := ""
var _force_overlay := ""
var _orbit := Vector2.ZERO  # (elevación, distancia) del modo de vuelta de cámara; (0, 0) = desactivado
var _frame := 0

@onready var lathe: Node3D = $Lathe3D


func _ready() -> void:
	src = DemoSource.new()
	lathe.call("set_work_material", "acero")
	lathe.call("set_chuck_grip", 25.0)
	lathe.call("set_plan", src.plan_band())
	lathe.call("set_profile_source", src)
	var at := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			at = a.substr(5).to_float()
		elif a.begins_with("--view="):
			_force_view = a.substr(7)
		elif a.begins_with("--overlay="):
			_force_overlay = a.substr(10)
		elif a.begins_with("--orbit="):
			var parts := a.substr(8).split(",")
			_orbit = Vector2(parts[0].to_float(), parts[1].to_float() if parts.size() > 1 else 0.5)
	while src.t < at - 1e-6:
		src.advance(minf(1.0 / 30.0, at - src.t))
	_build_hud()
	_apply_choreography(true)


func _process(delta: float) -> void:
	if _orbit != Vector2.ZERO:
		var rig: Node3D = lathe.get_node("CameraRig")
		rig.set("yaw", -90.0 + 15.0 * float(_frame))
		rig.set("pitch", _orbit.x)
		rig.set("distance", _orbit.y)
		rig.call("_release_goal")
		_frame += 1
		_op.text = "yaw %d° · pitch %d° · %s m" % [int(rig.get("yaw")), int(_orbit.x), _fmt(_orbit.y, 2)]
		return
	src.advance(delta)
	lathe.call("set_rpm", src.rpm)
	lathe.call("set_cutting", src.cutting, src.pc_kw)
	lathe.call("set_coolant", src.coolant)
	if src.feed > 0.0:
		lathe.call("set_feed", src.feed)
	_apply_choreography(false)
	_update_hud()
	var wp: Object = lathe.get("workpiece")
	var us := int(wp.get("last_update_usec"))
	if us > 0:
		_upd_sum += us
		_upd_n += 1
		_upd_max = maxi(_upd_max, us)
		wp.set("last_update_usec", 0)


func _exit_tree() -> void:
	if _upd_n > 0:
		var wp: Object = lathe.get("workpiece")
		print("Torno 3D: %d actualizaciones por rangos de la malla, media %.3f ms, máxima %.3f ms (CPU); última reconstrucción completa %.1f ms" % [
			_upd_n, float(_upd_sum) / float(_upd_n) / 1000.0, float(_upd_max) / 1000.0, float(int(wp.get("last_rebuild_usec"))) / 1000.0])


func _apply_choreography(instant: bool) -> void:
	var v := _force_view if _force_view != "" else src.view
	var o := _force_overlay if _force_overlay != "" else src.overlay
	if v != _view:
		_view = v
		lathe.call("set_view", _view, instant)
	if o != _overlay:
		_overlay = o
		lathe.call("set_overlay", _overlay)
		if _legend != null:
			_legend.visible = _overlay == "desviacion"


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
	_title = _label(box, "TALLER INDUSTRIAL · TORNO 3D", FONT_TITLE, 17, Palette.color("mint"))
	_op = _label(box, "", FONT_TITLE, 22, Palette.color("text"))
	_data = _label(box, "", FONT_MONO, 14, Palette.color("dim"))
	_label(box, "Pieza A · C45E · bruto Ø50 × 85 · demostración con el tiempo acelerado", FONT_MONO, 12, Palette.color("dimmer"))
	# Leyenda de la capa de desviación
	var lg := PanelContainer.new()
	lg.add_theme_stylebox_override("panel", sb)
	lg.anchor_top = 1.0
	lg.anchor_bottom = 1.0
	lg.position = Vector2(18, 0)
	layer.add_child(lg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	lg.add_child(row)
	for item in [["#FAAB29", "Sobra material"], ["#4DCC75", "En tolerancia"], ["#ED3838", "Pasado de medida"], ["#6B6B75", "Sin cota"]]:
		var sw := ColorRect.new()
		sw.color = Color(item[0])
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		_label(row, item[1], FONT_MONO, 13, Palette.color("text"))
	lg.visible = false
	_legend = lg
	# La leyenda va abajo: se coloca cuando se conoce su tamaño
	lg.resized.connect(func() -> void: lg.position = Vector2(18, get_viewport().get_visible_rect().size.y - lg.size.y - 16))


func _label(parent: Control, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _update_hud() -> void:
	_op.text = src.op
	var vc := TAU * maxf(src.tool.x, 0.0) * src.rpm / 1000.0
	var parts := ["%s rpm" % _fmt(src.rpm, 0)]
	if src.cutting:
		parts.append("vc %s m/min" % _fmt(vc, 0))
		parts.append("f %s mm/vuelta" % _fmt(src.feed, 2))
		parts.append("Pc %s kW" % _fmt(src.pc_kw, 1))
	if src.coolant:
		parts.append("taladrina")
	parts.append("t %s s" % _fmt(src.t, 1))
	_data.text = " · ".join(parts)


## Número con coma decimal (español).
static func _fmt(x: float, d: int) -> String:
	return (("%." + str(d) + "f") % x).replace(".", ",")
