## Cetrería · la reacción del animal (unidad 5t-B): el animador del velocirraptor (el de cine, ficción; la reconstrucción,
## con sus plumas, igual). Solo dibujo.
## Levanta la hoz del dedo II y la baja para cortar en el golpe, abre la boca (siseo) y el cuerpo gira un poco en la cadera
## contra la patada: la cola larga y rígida hace de contrapeso.
extends RefCounted

const Common = preload("res://app/lab/cetreria/reaction/anim_common.gd")


static func apply(r: RefCounted, ch: Dictionary, _t: float) -> void:
	Common.head_eyes_jaw(r, ch)
	r.call("pose_sickle", float(ch.get("sickle", 0.0)))
	# la cola de contrapeso: el cuerpo gira sobre la vertical en la cadera (la pata de arriba)
	var paw_rest: Transform3D = r.get("paw_rest")
	r.call("pose_yaw", float(ch.get("tail", 0.0)), paw_rest.origin + Vector3(-0.2, 0.0, 0.0))
