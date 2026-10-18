## Cetrería · la reacción del animal (unidad 5t-B): el animador de las rapaces diurnas y nocturnas. Solo dibujo.
##   - diurnas: se encoge y saca la cabeza, abre el pico, las plumas se erizan (body_feather.gdshader: ruffle), abre el ala
##     de arriba a medias (el «mantling») con las primarias que se abren con su retraso, y la cola compensa;
##   - nocturnas: el chasquido del pico (abre y cierra a ~12 Hz), todo el plumaje ahuecado, las alas hacia delante como una
##     capa, la cabeza baja que se balancea, el disco facial que se contrae y la membrana nictitante.
extends RefCounted

const Common = preload("res://app/lab/cetreria/reaction/anim_common.gd")

## El chasquido del pico de los búhos (Hz y lo que se abre, rad) y el balanceo de la cabeza (Hz, rad). Dibujo.
const CLACK_HZ := 12.0
const CLACK_RAD := 0.22
const SWAY_HZ := 2.4
const SWAY_RAD := 0.12


static func apply(r: RefCounted, ch: Dictionary, t: float, owl: bool) -> void:
	var jaw_extra := 0.0
	if owl:
		var clack := float(ch.get("clack", 0.0))
		if clack > 0.0:
			jaw_extra = CLACK_RAD * clack * maxf(Common.wave(t, CLACK_HZ, 0.0), 0.0)
		ch["head_yaw"] = float(ch.get("head_yaw", 0.0)) + SWAY_RAD * float(ch.get("disc", 0.0)) * Common.wave(t, SWAY_HZ, 0.7)
	Common.head_eyes_jaw(r, ch, jaw_extra)
	# las plumas que se erizan (body_feather.gdshader: ruffle)
	r.call("set_ruffle", float(ch.get("ruffle", 0.0)))
	# el dedo IV de las nocturnas, hacia atrás al atacar (zigodáctilas)
	if owl:
		r.call("pose_toe_back", float(ch.get("toe_back", 0.0)))
	var sp: Dictionary = r.get("spec")
	# el ala de arriba: se levanta del flanco girando en el hombro; las primarias se abren en abanico en el carpo
	var w: Dictionary = sp.get("wing", {})
	if not w.is_empty():
		var n: Vector3 = w.normal
		var s := float(r.call("sign_toward", "wing", w.pivot, w.axis, n))
		r.call("rot_about", "wing", w.pivot, Basis((w.axis as Vector3).normalized(), s * float(ch.get("wing", 0.0))))
	var wp: Dictionary = sp.get("wing_p", {})
	if not wp.is_empty():
		var s2 := float(r.call("sign_toward", "wing_p", wp.pivot, wp.axis, -(wp.along as Vector3)))
		r.call("rot_about", "wing_p", wp.pivot, Basis((wp.axis as Vector3).normalized(), s2 * float(ch.get("wing_fan", 0.0))))
	# la cola, contra la pata (sobre la normal de la rabadilla)
	var tl: Dictionary = sp.get("tail", {})
	if not tl.is_empty():
		r.call("rot_about", "tail", tl.pivot, Basis((tl.axis as Vector3).normalized(), float(ch.get("tail", 0.0))))
