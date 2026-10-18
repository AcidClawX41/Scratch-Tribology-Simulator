## Cetrería · la cámara orbital de la afiladora del taller (app/taller/sharpen3d/orbit_rig.gd, sin tocarla), con los
## mandos de esta escena: el botón izquierdo es la herramienta, así que la cámara no lee el ratón por su cuenta; la
## escena le pasa el botón derecho (girar), el central (desplazar), la rueda (acercar) y los dos dedos del teléfono.
## De cerca (unidad 5h): el plano cercano se acerca con la cámara (a 8 mm de la garra, a unas décimas de milímetro), para
## poder llegar a la punta sin que la recorte, y el lejano se ajusta para no perder precisión de profundidad.
extends "res://app/taller/sharpen3d/orbit_rig.gd"

## Plano cercano y lejano por metro de distancia al objetivo, y sus topes (m).
const NEAR_K := 0.04
const NEAR_MIN := 0.0004
const FAR_K := 300.0
const FAR_MIN := 6.0


## Sin entrada propia: la reparte la escena (care_3d.gd).
func _unhandled_input(_event: InputEvent) -> void:
	pass


## Gira la órbita con un arrastre de rel píxeles.
func orbit_by(rel: Vector2) -> void:
	if ortho:
		return
	_user = true
	yaw -= rel.x * 0.3
	pitch = clampf(pitch + rel.y * 0.3, -60.0, 88.0)


## Desplaza el objetivo con un arrastre de rel píxeles.
func pan_by(rel: Vector2) -> void:
	if ortho:
		return
	_user = true
	var right := _cam.transform.basis.x
	var upv := _cam.transform.basis.y
	target += (-right * rel.x + upv * rel.y) * distance * 0.0015
	if not _goal.is_empty():
		_goal["target"] = target


## Acerca (f < 1) o aleja (f > 1).
func zoom_by(f: float) -> void:
	if ortho:
		return
	_zoom(f)


## ¿Ha movido el usuario la cámara desde la última vista pedida?
func user_moved() -> bool:
	return _user


## La próxima vista pedida manda sobre lo que el usuario haya movido la cámara (y llega con suavidad).
func reset_user() -> void:
	_user = false


func _apply() -> void:
	super()
	if not ortho:
		_cam.near = clampf(distance * NEAR_K, NEAR_MIN, 0.05)
		_cam.far = clampf(distance * FAR_K, FAR_MIN, 40.0)
