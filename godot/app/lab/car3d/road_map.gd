## Plano de la carretera del coche en curva (unidad 4t): la curva o la S vista desde arriba (CarCurve.path, solo geometría)
## y el coche, un triángulo que la recorre en la S (o se queda en el tramo circular de la curva). La vista 3D dobla la
## carretera de lado, de perfil se lee poco: el plano dice qué curva es y por dónde va el coche. Solo pinta.
extends Control

const Palette = preload("res://app/theme/palette.gd")

const FONT := 10

var pts := PackedVector2Array()
var ss := PackedFloat64Array()
var car_s := 0.0
var note := ""
var draws := 0
var _lo := Vector2.ZERO
var _k := 1.0
var _off := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "PlanoCarretera"
	accessibility_name = "Plano de la carretera vista desde arriba"


## El recorrido (m: x a la derecha, y hacia delante) con los metros de carretera de cada punto, y la nota de debajo.
func set_path(p: PackedVector2Array, s: PackedFloat64Array, p_note: String) -> void:
	pts = p
	ss = s
	note = p_note
	_fit()
	queue_redraw()


## Dónde va el coche (m de carretera desde el principio).
func set_car(s_m: float) -> void:
	if s_m == car_s:
		return
	car_s = s_m
	queue_redraw()


func _fit() -> void:
	if pts.is_empty():
		return
	var lo := pts[0]
	var hi := pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var box := Vector2(size.x - 12.0, size.y - 22.0)
	var ext := (hi - lo).max(Vector2(1.0, 1.0))
	_k = minf(box.x / ext.x, box.y / ext.y)
	_lo = lo
	_off = Vector2(6.0, 4.0) + (box - ext * _k) * 0.5
	_off.y += ext.y * _k  # y hacia delante: arriba en la pantalla


func _to_px(p: Vector2) -> Vector2:
	return Vector2(_off.x + (p.x - _lo.x) * _k, _off.y - (p.y - _lo.y) * _k)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


func _draw() -> void:
	draws += 1
	if pts.size() < 2:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.color("bg"), 0.82))
	var line := PackedVector2Array()
	for p: Vector2 in pts:
		line.append(_to_px(p))
	draw_polyline(line, Color(Palette.color("panel3"), 1.0), 7.0, true)
	draw_polyline(line, Color(Palette.color("dim"), 0.9), 1.0, true)
	# el coche: interpolado entre los dos puntos de su tramo, apuntando por donde va
	var i := 0
	while i < ss.size() - 2 and ss[i + 1] < car_s:
		i += 1
	var f := clampf((car_s - ss[i]) / maxf(ss[i + 1] - ss[i], 1e-9), 0.0, 1.0)
	var a := _to_px(pts[i])
	var b := _to_px(pts[i + 1])
	var at := a.lerp(b, f)
	var dir := (b - a).normalized() if a.distance_to(b) > 0.0 else Vector2.UP
	var tri := PackedVector2Array([at + dir * 7.0, at - dir * 5.0 + dir.orthogonal() * 4.5, at - dir * 5.0 - dir.orthogonal() * 4.5])
	draw_colored_polygon(tri, Palette.color("rose"))
	if note != "":
		var font := get_theme_default_font()
		var y := size.y - 6.0
		draw_string_outline(font, Vector2(0.0, y), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, 3, Color(Palette.color("bg"), 0.85))
		draw_string(font, Vector2(0.0, y), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, Palette.color("dim"))
