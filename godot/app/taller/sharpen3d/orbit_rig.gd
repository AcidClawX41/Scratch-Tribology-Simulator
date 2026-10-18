## Cámara de la afiladora 3D: orbital como la del torno (arrastrar para girar, rueda o pellizco para acercar, botón
## central o Mayús para desplazar) con transiciones suaves entre vistas, y ortográfica para la vista de sección.
## La mueve la escena con step(delta) desde su propio fotograma (no tiene _process): así las capturas y los tests
## salen iguales cada vez.
##
## Órbita: objetivo `target`, acimut `yaw` (0 = delante de la máquina, donde está el operario), elevación `pitch`
## (grados sobre la horizontal) y `distance` (m). Sección: posición, dirección y tamaño explícitos (set_ortho).
extends Node3D

@export var smoothing := 5.0  ## 1/s: cuánto tarda en llegar a la vista pedida
@export var min_distance := 0.03
@export var max_distance := 4.0

var target := Vector3(0.0, 0.1, 0.0)
var yaw := 20.0
var pitch := 18.0
var distance := 0.8
var fov := 38.0
var ortho := false

var _goal := {}
var _user := false  # el usuario ha tomado el control de la órbita
var _dragging := 0  # 0 nada · 1 girar · 2 desplazar
var _cam: Camera3D


func _init() -> void:
	name = "Camara"
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = fov
	add_child(_cam)


func camera() -> Camera3D:
	return _cam


## Vista orbital pedida: la cámara llega a ella con suavidad (o de golpe con instant). follow_target: el objetivo
## se sigue actualizando (vista del filo, que sigue al punto de contacto).
func set_orbit(p_target: Vector3, p_yaw: float, p_pitch: float, p_distance: float, p_fov: float, instant := false) -> void:
	_goal = { "target": p_target, "yaw": p_yaw, "pitch": p_pitch, "distance": p_distance, "fov": p_fov }
	if ortho:
		ortho = false
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		instant = true
	if instant:
		target = p_target
		yaw = p_yaw
		pitch = p_pitch
		distance = p_distance
		fov = p_fov
		_user = false
		_apply()


## Nuevo objetivo sin cambiar el resto (la vista del filo sigue al contacto).
func follow(p_target: Vector3) -> void:
	if not _goal.is_empty():
		_goal["target"] = p_target


## Sección: cámara ortográfica en `eye` mirando hacia `dir`, con `up` hacia arriba y `size` m de alto.
func set_ortho(eye: Vector3, dir: Vector3, up: Vector3, size: float, cull_mask: int) -> void:
	ortho = true
	_goal = {}
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = size
	_cam.near = 0.001
	_cam.far = 1.0
	_cam.cull_mask = cull_mask
	var up2 := up if absf(up.normalized().dot(dir.normalized())) < 0.98 else Vector3.BACK
	# El rig va en el origen de la escena: el marco local de la cámara es el de la escena
	_cam.transform = Transform3D(Basis.looking_at(dir, up2), eye)


## Capas que ve la cámara en órbita.
func set_mask(mask: int) -> void:
	if not ortho:
		_cam.cull_mask = mask


func step(delta: float) -> void:
	if ortho:
		return
	if not _goal.is_empty() and not _user:
		var k := 1.0 - exp(-smoothing * maxf(delta, 0.0))
		target = target.lerp(_goal["target"], k)
		yaw = lerpf(yaw, float(_goal["yaw"]), k)
		pitch = lerpf(pitch, float(_goal["pitch"]), k)
		distance = exp(lerpf(log(distance), log(float(_goal["distance"])), k))
		fov = lerpf(fov, float(_goal["fov"]), k)
	elif _user and not _goal.is_empty():
		target = target.lerp(_goal["target"], 1.0 - exp(-smoothing * maxf(delta, 0.0)))
	_apply()


func _apply() -> void:
	if ortho:
		return
	var el := deg_to_rad(clampf(pitch, -80.0, 88.0))
	var az := deg_to_rad(yaw)
	var off := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * distance
	_cam.fov = fov
	_cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), target + off)
	_cam.near = clampf(distance * 0.02, 0.002, 0.05)
	_cam.far = 40.0


func _unhandled_input(event: InputEvent) -> void:
	if ortho:
		return
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
		_user = true
		if _dragging == 1:
			yaw -= mm.relative.x * 0.3
			pitch = clampf(pitch + mm.relative.y * 0.3, -60.0, 88.0)
		else:
			var right := _cam.transform.basis.x
			var upv := _cam.transform.basis.y
			target += (-right * mm.relative.x + upv * mm.relative.y) * distance * 0.0015
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_user = true
		var pg := event as InputEventPanGesture
		yaw -= pg.delta.x * 2.0
		pitch = clampf(pitch + pg.delta.y * 2.0, -60.0, 88.0)


func _zoom(f: float) -> void:
	_user = true
	distance = clampf(distance * f, min_distance, max_distance)
