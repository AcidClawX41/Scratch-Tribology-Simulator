## Cámara orbital del torno: arrastrar con el botón izquierdo o derecho para girar, rueda o pellizco para
## acercar, botón central (o Mayús + arrastrar) para desplazar. Las vistas fijas se alcanzan con una transición
## suave, y la de detalle sigue a la punta de la herramienta.
##
## El nodo es el pivote; su hijo Camera3D se coloca a `distance` del objetivo con acimut `yaw` (0 = delante de la
## máquina, donde está el operario) y elevación `pitch` (grados sobre la horizontal).
extends Node3D

## Vistas con nombre. target en metros (marco de la escena del torno); "follow": el objetivo es la punta.
const VIEWS := {
	"general": {"target": Vector3(0.04, 0.95, 0.0), "yaw": 24.0, "pitch": 19.0, "distance": 2.7, "fov": 38.0},
	# Delante y hacia el contrapunto: se ven el plato, la pieza entera y la torreta sin que esta tape la pieza
	"frontal": {"target": Vector3(-0.115, 1.09, 0.0), "yaw": 38.0, "pitch": 27.0, "distance": 0.5, "fov": 38.0},
	"superior": {"target": Vector3(-0.10, 1.1, 0.03), "yaw": 0.0, "pitch": 78.0, "distance": 0.5, "fov": 38.0},
	# Desde el lado ya mecanizado: la plaquita, la viruta y la superficie que va dejando
	"detalle": {"target": Vector3.ZERO, "yaw": 72.0, "pitch": 20.0, "distance": 0.14, "fov": 36.0, "follow": true},
}

@export var smoothing := 4.0  ## 1/s: cuánto tarda en llegar a la vista pedida
@export var min_distance := 0.04
@export var max_distance := 6.0

var target := Vector3(0.0, 1.0, 0.0)
var yaw := 0.0
var pitch := 20.0
var distance := 1.0
var focus_point := Vector3.ZERO  ## punta de la herramienta (la escena lo actualiza cada fotograma)
var view_name := ""

var _goal := {}
var _follow := false
var _follow_offset := Vector3(0.006, 0.0, -0.008)
var _dragging := 0  # 0 nada · 1 girar · 2 desplazar
var _cam: Camera3D


func _ready() -> void:
	_cam = get_node_or_null("Camera3D") as Camera3D
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "Camera3D"
		add_child(_cam)
	_apply()


## Cambia a una vista con nombre («general», «frontal», «superior», «detalle»). Con instant = true, sin transición.
func set_view(new_view: String, instant := false) -> void:
	if not VIEWS.has(new_view):
		push_warning("Vista desconocida: %s" % new_view)
		return
	view_name = new_view
	var v: Dictionary = VIEWS[new_view]
	_follow = bool(v.get("follow", false))
	_goal = {"target": v["target"], "yaw": float(v["yaw"]), "pitch": float(v["pitch"]), "distance": float(v["distance"]), "fov": float(v["fov"])}
	if instant:
		target = focus_point + _follow_offset if _follow else v["target"]
		yaw = _goal["yaw"]
		pitch = _goal["pitch"]
		distance = _goal["distance"]
		if _cam != null:
			_cam.fov = _goal["fov"]
		_apply()


func camera() -> Camera3D:
	return _cam


func _process(delta: float) -> void:
	if not _goal.is_empty():
		var k := 1.0 - exp(-smoothing * delta)
		var tgt: Vector3 = focus_point + _follow_offset if _follow else _goal["target"]
		target = target.lerp(tgt, k)
		yaw = lerpf(yaw, float(_goal["yaw"]), k)
		pitch = lerpf(pitch, float(_goal["pitch"]), k)
		# La distancia se interpola en escala logarítmica: el paso de 2 m a 12 cm no se hace de golpe al final.
		distance = exp(lerpf(log(distance), log(float(_goal["distance"])), k))
		if _cam != null:
			_cam.fov = lerpf(_cam.fov, float(_goal["fov"]), k)
	elif _follow:
		target = focus_point + _follow_offset
	_apply()


func _apply() -> void:
	if _cam == null:
		return
	var el := deg_to_rad(clampf(pitch, -85.0, 88.0))
	var az := deg_to_rad(yaw)
	var off := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * distance
	_cam.global_position = to_global(target + off)
	_cam.look_at(to_global(target), Vector3.UP)
	# Plano cercano proporcional a la distancia: detalle de décimas de milímetro sin perder precisión de fondo
	_cam.near = clampf(distance * 0.02, 0.002, 0.05)
	_cam.far = 60.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.0 / 0.88)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = (2 if mb.shift_pressed else 1) if mb.pressed else 0
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = 2 if mb.pressed else 0
	elif event is InputEventMouseMotion and _dragging != 0:
		var mm := event as InputEventMouseMotion
		_release_goal()
		if _dragging == 1:
			yaw -= mm.relative.x * 0.3
			pitch = clampf(pitch + mm.relative.y * 0.3, -60.0, 88.0)
		else:
			var right := _cam.global_transform.basis.x
			var up := _cam.global_transform.basis.y
			target += (-right * mm.relative.x + up * mm.relative.y) * distance * 0.0015
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_release_goal()
		var pg := event as InputEventPanGesture
		yaw -= pg.delta.x * 2.0
		pitch = clampf(pitch + pg.delta.y * 2.0, -60.0, 88.0)


func _zoom(f: float) -> void:
	_release_goal()
	distance = clampf(distance * f, min_distance, max_distance)


## El usuario toma el control: se deja de perseguir la vista pedida (pero la de detalle sigue a la punta).
func _release_goal() -> void:
	if not _goal.is_empty():
		_goal = {}
