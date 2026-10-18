## Cámara orbital de las escenas 3D de la fresadora y el taladro: la del torno (lathe3d/orbit_camera.gd: arrastrar para
## girar, rueda o pellizco para acercar, Mayús o botón central para desplazar, transiciones suaves entre vistas) con
## las vistas de cada escena, que esta pone en `views` antes de pedir la primera.
extends "res://app/taller/lathe3d/orbit_camera.gd"

## Vistas con nombre: { nombre: { target: Vector3, yaw, pitch, distance, fov } } (en metros y grados).
var views := {}


func set_view(new_view: String, instant := false) -> void:
	if not views.has(new_view):
		push_warning("Vista desconocida: %s" % new_view)
		return
	view_name = new_view
	var v: Dictionary = views[new_view]
	_follow = false
	_goal = { "target": v["target"], "yaw": float(v["yaw"]), "pitch": float(v["pitch"]), "distance": float(v["distance"]),
		"fov": float(v["fov"]) }
	if instant:
		target = v["target"]
		yaw = _goal["yaw"]
		pitch = _goal["pitch"]
		distance = _goal["distance"]
		if _cam != null:
			_cam.fov = _goal["fov"]
		_apply()
