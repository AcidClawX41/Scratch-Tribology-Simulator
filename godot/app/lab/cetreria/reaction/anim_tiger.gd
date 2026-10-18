## Cetrería · la reacción del animal (unidad 5t-B): el animador del tigre. Solo dibujo.
## Las orejas aplastadas hacia atrás, la cabeza baja que mira a la cámara, los bigotes hacia delante, la cola que azota y,
## en el golpe, las uñas que salen de la vaina (en reposo están recogidas: lo hace el controlador con pose_claws). El bulto
## del músculo del hombro que se desliza sobre la paletilla va en body_fur.gdshader (bump_*), solo en escritorio.
extends RefCounted

const Common = preload("res://app/lab/cetreria/reaction/anim_common.gd")

## La cola que azota (Hz y rad) y lo que se aplastan las orejas del todo (rad). Dibujo.
const LASH_HZ := 2.2
const LASH_RAD := 0.3
const EARS_RAD := 1.1
const WHISK_RAD := 1.0


static func apply(r: RefCounted, ch: Dictionary, t: float) -> void:
	Common.head_eyes_jaw(r, ch)
	ears(r, float(ch.get("ears", 0.0)) * EARS_RAD)
	var sp: Dictionary = r.get("spec")
	for tag: String in ["d", "i"]:
		var w: Dictionary = sp.get("whisk_" + tag, {})
		if w.is_empty():
			continue
		var s := float(r.call("sign_toward", "whisk_" + tag, w.pivot, w.axis, Vector3(1.0, 0.0, 0.0)))
		r.call("rot_about", "whisk_" + tag, w.pivot, Basis(Vector3.UP, s * float(ch.get("whisk", 0.0)) * WHISK_RAD * 0.6))
	lash(r, float(ch.get("lash", 0.0)) * LASH_RAD * Common.wave(t, LASH_HZ, 0.0))


## Las orejas hacia atrás (ang, rad), cada una en su base.
static func ears(r: RefCounted, ang: float) -> void:
	var sp: Dictionary = r.get("spec")
	for tag: String in ["d", "i"]:
		var e: Dictionary = sp.get("ear_" + tag, {})
		if e.is_empty():
			continue
		# hacia la nuca (−X de la cabeza)
		var s := float(r.call("sign_toward", "ear_" + tag, e.pivot, e.axis, Vector3(-1.0, 0.0, 0.0)))
		r.call("rot_about", "ear_" + tag, e.pivot, Basis((e.axis as Vector3).normalized(), s * ang))


## La cola, de lado sobre la mesa (sobre la vertical de su raíz).
static func lash(r: RefCounted, ang: float) -> void:
	var tl: Dictionary = (r.get("spec") as Dictionary).get("tail", {})
	if not tl.is_empty():
		r.call("rot_about", "tail", tl.pivot, Basis(Vector3.UP, ang))
