## Cetrería · la reacción del animal (unidad 5t-B): lo que comparten los animadores de cada especie (anim_bird.gd,
## anim_tiger.gd, anim_bear.gd y anim_raptor.gd). Solo dibujo; solo mueve transformaciones y parámetros.
## ch: los valores de los canales en este instante (reaction_keys.gd), ya multiplicados por el peso de la postura (el aviso
## crece de 0 a 1); t: el reloj de la escena (s), para lo que oscila (el chasquido del pico, la cola que azota).
extends RefCounted


## La cabeza (con su cuello), los ojos y la membrana nictitante, la mandíbula.
static func head_eyes_jaw(r: RefCounted, ch: Dictionary, jaw_extra := 0.0) -> void:
	# la cabeza descansa en la mesa: no baja de ella (un poco de cabeceo «abajo» solo la aprieta)
	r.call("pose_head", maxf(float(ch.get("head_pitch", 0.0)), -0.04), float(ch.get("head_yaw", 0.0)), float(ch.get("head_pull", 0.0)), float(ch.get("disc", 0.0)))
	if ch.has("eye"):
		r.call("pose_eyes", float(ch.eye))
	r.call("pose_nict", float(ch.get("nict", 0.0)))
	r.call("pose_jaw", maxf(float(ch.get("jaw", 0.0)) + jaw_extra, 0.0))


## Un giro de amplitud a y frecuencia hz (con fase), suave al empezar.
static func wave(t: float, hz: float, phase: float) -> float:
	return sin(TAU * hz * t + phase)
