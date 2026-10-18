## Cetrería · la reacción del animal (unidad 5t-B): el animador del oso pardo. Solo dibujo.
## Se levanta un poco (rueda hacia el pecho), resopla (la cabeza da tirones cortos con cada resoplido y el vaho sale de la
## nariz: lo pinta el controlador; a los 20 °C de una clínica no se vería, es dibujo), las orejas atrás, y en la
## recuperación se deja caer con un rebote. El pelo y la grasa del brazo que siguen con retraso van en body_fur.gdshader
## (sway), solo en escritorio.
extends RefCounted

const Common = preload("res://app/lab/cetreria/reaction/anim_common.gd")
const AnimTiger = preload("res://app/lab/cetreria/reaction/anim_tiger.gd")

## Los resoplidos (por segundo) y el tirón de la cabeza en cada uno (rad). Dibujo.
const HUFF_HZ := 2.6
const HUFF_RAD := 0.05


static func apply(r: RefCounted, ch: Dictionary, t: float) -> void:
	var huff := float(ch.get("huff", 0.0))
	if huff > 0.0:
		var h := maxf(Common.wave(t, HUFF_HZ, 0.0), 0.0)
		ch["head_pitch"] = float(ch.get("head_pitch", 0.0)) + HUFF_RAD * huff * h * h
	r.call("pose_roll", float(ch.get("roll", 0.0)))
	Common.head_eyes_jaw(r, ch)
	AnimTiger.ears(r, float(ch.get("ears", 0.0)) * 0.9)


## ¿Resopla ahora? (para el vaho y el sonido: el pico de cada resoplido)
static func huff_phase(t: float) -> float:
	return fposmod(t * HUFF_HZ, 1.0)
