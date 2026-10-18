## Cetrería · la reacción del animal (unidad 5t-B): los fotogramas clave de cada especie, los del guion
## (docs/fase2/5tb-guion.md). Solo dibujo: los ángulos, las distancias, los tiempos de la anticipación y de la recuperación y
## las curvas. Lo que sale de la física (la duración real del golpe) lo da core/lab/care_strike.gd; lo que le pasa a la
## lente, core/lab/claw_care_reaction.gd.
##
## Cada canal es una lista de claves [tiempo, fracción, valor]: el tiempo es «A» (anticipación), «S» (golpe), «C» (contacto)
## o «R» (recuperación) y la fracción dice dónde dentro de él (0-1). Entre dos claves, entrada y salida suaves (seno); antes
## de la primera, el valor de la postura de amenaza (threat) o 0; después de la última, el último.
## Canales: head_pitch, head_yaw (rad), head_pull (fracción del largo de la cabeza), jaw (rad), ruffle (0-1), wing, wing_fan,
## tail (rad), ears, whisk (rad), roll (rad: el cuerpo que se levanta), eye (cuánto se abren los ojos, 1 del todo), nict
## (0-1: la membrana), disc (0-1: el disco facial), claw_out (0-1: las uñas del tigre fuera), sickle (rad: la hoz),
## arms (rad: los brazos del velocirraptor), coil (0-1: el miembro recogido), toe_back (0-1: el dedo IV de las nocturnas,
## hacia atrás).
extends RefCounted

## Las fases del plano (s en pantalla): el corte, el contacto según el resultado (rebote, arrastre o frenazo) y la vuelta de
## la cámara.
const CUT_S := 0.2
const CONTACT_S := { "rebote": 0.05, "arrastre": 0.13, "frenazo": 0.17 }
const HOLD_S := 0.3
const BACK_S := 0.5
## El golpe en pantalla: lo que dura de verdad (care_strike) llevado a TARGET_STRIKE_S con la cámara lenta, con su tope.
const TARGET_STRIKE_S := 0.2
const SLOWMO_MIN := 0.25
## Por debajo de esta intensidad (el animal casi no puede moverse), solo un tirón de la pata dormida, de TWITCH_S.
const TWITCH_INTENSITY := 0.15
const TWITCH_S := 0.35
## Entre dos reacciones en la escena, como mucho (s); el motor ya las separa ~20 s.
const MIN_GAP_S := 4.0

## Cada tipo de reacción (los «kind» del motor): la anticipación y la recuperación (s), el plano (cámara: distancia a la
## pata, alto sobre ella, hacia la cabeza, a qué distancia está la lente y el campo, todo en m y grados), la pata que
## golpea, cuánto se recoge (atrás y arriba, m; y el giro, rad), lo que arrastra por la lente (fracción del ancho que se
## ve), lo que gira la mano o el pie para que el dedo del golpe (Reaction.IMPACT_FINGER) llegue antes que los demás (lead,
## rad: mucho en las rapaces y en la hoz del velocirraptor, poco en el oso, que golpea con la mano entera), las variantes
## (dónde llega en la pantalla, el arco y la dirección del arrastre), la postura de amenaza y las claves.
const KINDS := {
	"rapaz": {
		"a_s": 0.42, "r_s": 0.75, "paw": "derecha",
		"cam": { "out": 1.0, "up": 0.4, "side": 0.35, "toward_head": 0.3, "lens": 0.2, "fov": 56.0 },
		"cock": { "back": 0.05, "up": 0.035, "ang": 0.6, "thrust": 0.03, "lift": 0.04 }, "drag": 0.22, "flex": 1.0, "lead": 0.35,
		"variants": [
			{ "id": "directa", "at": Vector2(0.5, 0.48), "arc": Vector2(0.4, 0.6), "drag": Vector2(0.15, -1.0), "toe": 0.0 },
			{ "id": "cruzada", "at": Vector2(0.42, 0.44), "arc": Vector2(-0.7, 0.5), "drag": Vector2(0.55, -0.8), "toe": 0.5 },
			{ "id": "alta", "at": Vector2(0.56, 0.36), "arc": Vector2(0.2, 1.0), "drag": Vector2(-0.2, -1.0), "toe": -0.35 },
		],
		"threat": { "head_yaw": 0.35, "head_pitch": 0.12, "eye": 1.15, "ruffle": 0.35, "wing": 0.12, "jaw": 0.08 },
		"keys": {
			"head_pull": [["A", 0.0, 0.0], ["A", 0.35, -0.22], ["A", 0.9, 0.12], ["S", 1.0, 0.3], ["R", 0.6, 0.0]],
			"head_pitch": [["A", 0.35, 0.05], ["S", 1.0, 0.22], ["R", 0.8, 0.0]],
			"head_yaw": [["A", 0.5, 0.42], ["R", 1.0, 0.0]],
			"jaw": [["A", 0.3, 0.05], ["A", 0.6, 0.42], ["S", 1.0, 0.5], ["R", 0.5, 0.0]],
			"ruffle": [["A", 0.0, 0.35], ["A", 0.7, 1.0], ["R", 0.8, 0.0]],
			"wing": [["A", 0.1, 0.12], ["A", 0.75, 0.55], ["S", 1.0, 0.6], ["R", 0.9, 0.0]],
			"wing_fan": [["A", 0.3, 0.0], ["A", 0.9, 0.45], ["S", 1.0, 0.5], ["R", 0.7, 0.0]],
			"tail": [["A", 0.2, 0.0], ["A", 0.8, -0.25], ["S", 1.0, -0.3], ["R", 0.7, 0.0]],
			"coil": [["A", 0.0, 0.0], ["A", 0.85, 1.0]],
			"eye": [["A", 0.0, 1.15], ["R", 1.0, 1.0]],
			"nict": [["A", 0.0, 0.0], ["A", 0.12, 1.0], ["A", 0.3, 0.0], ["C", 0.0, 0.0], ["C", 0.5, 1.0], ["R", 0.15, 0.0]],
		},
	},
	"nocturna": {
		"a_s": 0.5, "r_s": 0.8, "paw": "derecha",
		"cam": { "out": 1.0, "up": 0.25, "side": 0.35, "toward_head": 0.18, "lens": 0.11, "fov": 60.0 },
		"cock": { "back": 0.045, "up": 0.03, "ang": 0.55, "thrust": 0.03, "lift": 0.035 }, "drag": 0.2, "flex": 1.0, "lead": 0.3,
		"variants": [
			{ "id": "directa", "at": Vector2(0.5, 0.46), "arc": Vector2(0.3, 0.7), "drag": Vector2(0.1, -1.0), "toe": 0.0 },
			{ "id": "cruzada", "at": Vector2(0.44, 0.42), "arc": Vector2(-0.6, 0.5), "drag": Vector2(0.5, -0.85), "toe": 0.4 },
		],
		"threat": { "head_pitch": -0.18, "head_yaw": 0.25, "eye": 1.25, "ruffle": 0.6, "wing": 0.3, "disc": 0.6, "clack": 1.0 },
		"keys": {
			"head_pitch": [["A", 0.5, -0.3], ["S", 1.0, -0.1], ["R", 0.8, 0.0]],
			"head_yaw": [["A", 0.4, 0.3], ["R", 1.0, 0.0]],
			"ruffle": [["A", 0.0, 0.6], ["A", 0.6, 1.0], ["R", 0.9, 0.0]],
			"wing": [["A", 0.1, 0.3], ["A", 0.7, 0.8], ["S", 1.0, 0.85], ["R", 0.9, 0.0]],
			"wing_fan": [["A", 0.3, 0.1], ["A", 0.95, 0.6], ["R", 0.75, 0.0]],
			"disc": [["A", 0.5, 1.0], ["R", 0.8, 0.0]],
			"clack": [["A", 0.0, 1.0], ["A", 0.6, 1.0], ["A", 0.7, 0.0]],
			"toe_back": [["A", 0.2, 0.0], ["A", 0.8, 1.0], ["R", 0.6, 1.0], ["R", 1.0, 0.0]],
			"jaw": [["A", 0.65, 0.0], ["A", 0.85, 0.3], ["R", 0.4, 0.0]],
			"tail": [["A", 0.3, 0.0], ["A", 0.8, -0.2], ["R", 0.7, 0.0]],
			"coil": [["A", 0.0, 0.0], ["A", 0.85, 1.0]],
			"eye": [["A", 0.0, 1.25], ["R", 1.0, 1.0]],
			"nict": [["A", 0.0, 0.0], ["A", 0.1, 1.0], ["A", 0.25, 0.0], ["C", 0.0, 0.0], ["C", 0.5, 1.0], ["R", 0.12, 0.0], ["R", 0.5, 0.0], ["R", 0.6, 1.0], ["R", 0.72, 0.0]],
		},
	},
	"felino": {
		"a_s": 0.5, "r_s": 0.9, "paw": "delantera_derecha",
		"cam": { "out": 0.75, "up": 0.65, "side": 0.2, "toward_head": 0.15, "lens": 0.22, "fov": 58.0 },
		"cock": { "back": 0.1, "up": 0.12, "ang": 0.75, "thrust": 0.05, "lift": 0.1 }, "drag": 0.4, "flex": 0.0, "lead": 0.15, "tilt": -0.7,
		"variants": [
			{ "id": "directa", "at": Vector2(0.5, 0.5), "arc": Vector2(0.5, 0.7), "drag": Vector2(0.35, 0.95), "toe": 0.25 },
			{ "id": "gancho", "at": Vector2(0.42, 0.46), "arc": Vector2(-0.9, 0.4), "drag": Vector2(0.9, 0.45), "toe": 1.1 },
			{ "id": "finta", "at": Vector2(0.55, 0.52), "arc": Vector2(0.4, 0.6), "drag": Vector2(0.3, 1.0), "toe": 0.2, "feint": true },
		],
		"threat": { "ears": 1.0, "head_pitch": -0.06, "head_yaw": 0.3, "eye": 1.0, "whisk": 0.2, "jaw": 0.05, "claw_out": 0.25, "lash": 1.0 },
		"keys": {
			"ears": [["A", 0.0, 1.0], ["R", 0.4, 1.0], ["R", 1.0, 0.0]],
			"head_pitch": [["A", 0.4, -0.12], ["S", 1.0, 0.06], ["R", 0.8, 0.0]],
			"head_yaw": [["A", 0.4, 0.32], ["R", 1.0, 0.0]],
			"jaw": [["A", 0.2, 0.05], ["A", 0.5, 0.3], ["S", 1.0, 0.38], ["R", 0.6, 0.0]],
			"whisk": [["A", 0.6, 0.35], ["R", 0.9, 0.0]],
			"shoulder": [["A", 0.2, 0.0], ["A", 0.9, -1.0], ["S", 1.0, 1.0], ["R", 0.6, 0.0]],
			"lash": [["A", 0.0, 1.0], ["S", 1.0, 1.0], ["R", 1.0, 0.0]],
			"coil": [["A", 0.0, 0.0], ["A", 0.85, 1.0]],
			"claw_out": [["A", 0.0, 0.25], ["A", 0.55, 0.85], ["A", 0.9, 1.0], ["R", 0.5, 1.0], ["R", 0.9, 0.0]],
			"eye": [["A", 0.0, 1.0], ["R", 1.0, 1.0]],
		},
	},
	"oso": {
		"a_s": 0.6, "r_s": 1.0, "paw": "delantera_derecha",
		"cam": { "out": 0.8, "up": 0.55, "side": 0.1, "toward_head": 0.15, "lens": 0.26, "fov": 58.0 },
		"cock": { "back": 0.08, "up": 0.16, "ang": 0.55, "thrust": 0.05, "lift": 0.12 }, "drag": 0.35, "flex": 0.3, "lead": 0.08,
		"variants": [
			{ "id": "izquierda", "at": Vector2(0.5, 0.48), "arc": Vector2(-1.0, 0.3), "drag": Vector2(1.0, 0.12), "toe": 1.3 },
			{ "id": "derecha", "at": Vector2(0.52, 0.5), "arc": Vector2(1.0, 0.3), "drag": Vector2(-1.0, 0.15), "toe": -1.3 },
			{ "id": "alta", "at": Vector2(0.48, 0.42), "arc": Vector2(-0.7, 0.8), "drag": Vector2(0.8, 0.6), "toe": 1.0 },
		],
		"threat": { "head_pitch": 0.1, "head_yaw": 0.25, "ears": 0.6, "eye": 1.0, "huff": 1.0 },
		"keys": {
			"roll": [["A", 0.0, 0.0], ["A", 0.8, 0.16], ["S", 1.0, 0.18], ["R", 0.3, 0.18], ["R", 0.62, -0.015], ["R", 0.8, 0.0]],
			"head_pitch": [["A", 0.7, 0.25], ["S", 1.0, 0.2], ["R", 0.8, 0.0]],
			"head_yaw": [["A", 0.5, 0.3], ["R", 1.0, 0.0]],
			"jaw": [["A", 0.3, 0.08], ["A", 0.6, 0.35], ["S", 1.0, 0.4], ["R", 0.6, 0.0]],
			"ears": [["A", 0.4, 0.7], ["R", 1.0, 0.0]],
			"huff": [["A", 0.0, 1.0], ["A", 0.6, 1.0], ["A", 0.65, 0.0]],
			"coil": [["A", 0.0, 0.0], ["A", 0.9, 1.0]],
			"eye": [["A", 0.0, 1.0], ["R", 1.0, 1.0]],
		},
	},
	"dinosaurio": {
		"a_s": 0.45, "r_s": 0.8, "paw": "derecha",
		"cam": { "out": 0.6, "up": 0.8, "side": 0.3, "toward_head": 0.3, "lens": 0.12, "fov": 58.0 },
		"cock": { "back": 0.12, "up": 0.1, "ang": 0.7, "thrust": 0.08, "lift": 0.18 }, "drag": 0.45, "flex": 0.0, "lead": 0.4,
		"variants": [
			{ "id": "directa", "at": Vector2(0.5, 0.5), "arc": Vector2(0.5, 0.8), "drag": Vector2(0.25, 1.0), "toe": 0.3 },
			{ "id": "alta", "at": Vector2(0.54, 0.4), "arc": Vector2(-0.4, 1.0), "drag": Vector2(-0.2, 1.0), "toe": -0.2 },
		],
		"threat": { "sickle": 0.45, "arms": 0.25, "jaw": 0.1, "head_yaw": 0.3, "eye": 1.1 },
		"keys": {
			"sickle": [["A", 0.0, 0.45], ["S", 0.6, 0.6], ["S", 1.0, -0.35], ["R", 0.6, 0.0]],
			"arms": [["A", 0.2, 0.25], ["A", 0.6, 0.7], ["S", 1.0, 0.75], ["R", 0.8, 0.0]],
			"jaw": [["A", 0.3, 0.1], ["A", 0.5, 0.45], ["R", 0.6, 0.0]],
			"head_pitch": [["A", 0.5, 0.1], ["R", 0.8, 0.0]],
			"head_yaw": [["A", 0.5, 0.35], ["R", 1.0, 0.0]],
			"tail": [["A", 0.3, 0.0], ["A", 0.9, 0.05], ["S", 1.0, -0.07], ["R", 0.7, 0.0]],
			"coil": [["A", 0.0, 0.0], ["A", 0.85, 1.0]],
			"eye": [["A", 0.0, 1.1], ["R", 1.0, 1.0]],
		},
	},
}


static func kind(id: String) -> Dictionary:
	return KINDS.get(id, KINDS.rapaz)


## La cámara lenta del golpe (dibujo): la que lleva la duración real t_s a TARGET_STRIKE_S en pantalla (≤ 1: nunca más
## deprisa que de verdad).
static func slowmo_for(t_s: float) -> float:
	return clampf(t_s / TARGET_STRIKE_S, SLOWMO_MIN, 1.0)


## El instante (s desde el corte) de una clave [fase, fracción] con las duraciones de las fases (durs: { A, S, C, R }).
static func key_time(phase: String, frac: float, durs: Dictionary) -> float:
	var t := CUT_S
	for ph: String in ["A", "S", "C", "R"]:
		var d := float(durs.get(ph, 0.0))
		if ph == phase:
			return t + clampf(frac, 0.0, 1.0) * d
		t += d
	return t


## El valor del canal ch de la especie k en el instante t (s desde el corte), con las duraciones durs.
static func eval(k: Dictionary, ch: String, t: float, durs: Dictionary) -> float:
	var keys: Array = (k.keys as Dictionary).get(ch, [])
	var start := float((k.threat as Dictionary).get(ch, 0.0))
	if keys.is_empty():
		return start
	var t_prev := 0.0
	var v_prev := start
	for e: Array in keys:
		var tk := key_time(String(e[0]), float(e[1]), durs)
		var vk := float(e[2])
		if t <= tk:
			if tk - t_prev <= 1e-6:
				return vk
			var u := clampf((t - t_prev) / (tk - t_prev), 0.0, 1.0)
			return lerpf(v_prev, vk, 0.5 - 0.5 * cos(PI * u))
		t_prev = tk
		v_prev = vk
	return v_prev
