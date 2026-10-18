## La postura «dormido» de los animales en 3D (unidad 5c, la cetrería): tumbado de lado sobre la mesa, anestesiado o
## sujeto, con las patas hacia quien lo atiende. Solo dibujo.
##
## La postura es la del modelo de pie con unos giros (los centímetros y el animal son los mismos): la vista tumba la raíz
## de lado (el lado de quien mira, +z del modelo, queda arriba) y aquí las patas de arriba bajan hasta la mesa, delante
## y detrás de las de abajo para no taparlas; el cuello y la cabeza bajan a la mesa; la cola descansa. Así las patas
## quedan hacia el borde de la mesa con las almohadillas de cara y las garras a la vista, como cuando se presenta la pata
## para cortarlas (Samour 2006: la rapaz envuelta en la toalla con las patas fuera; el tigre y el oso, anestesiados).
## El coche en marcha no la usa: es una postura más del modelo, que Animal3D añade la primera vez que se pide.
extends RefCounted

## Giros de cada hueso (radianes, orden YXZ como las demás posturas) por tipo de animal. Las patas de arriba (_n) bajan
## girando sobre x (hacia el lado de abajo, −z del modelo) y se abren delante y detrás (sobre z); el cuello y la cola
## bajan girando sobre y o sobre x según hacia dónde salen del tronco.
const ROT := {
	"mamifero": {
		"hombro_n": Vector3(0.5, 0.0, 0.3), "hombro_f": Vector3(0.12, 0.0, -0.08),
		"cadera_n": Vector3(0.5, 0.0, -0.3), "cadera_f": Vector3(0.12, 0.0, 0.1),
		"cuello": Vector3(0.0, 0.22, -0.12), "cabeza": Vector3(0.0, 0.12, 0.1),
		"cola0": Vector3(0.25, -0.2, 0.0),
	},
	"ave": {
		"tibia_n": Vector3(0.7, 0.0, 0.35), "tibia_f": Vector3(0.2, 0.0, -0.2),
		"cuello": Vector3(-0.25, 0.0, -0.2), "cabeza": Vector3(-0.2, 0.0, 0.0),
		"cola": Vector3(0.2, 0.0, 0.0),
	},
	"teropodo": {
		"muslo_n": Vector3(0.9, 0.0, 0.25), "muslo_f": Vector3(0.5, 0.0, -0.18),
		"cuello": Vector3(0.0, 0.22, -0.3), "cabeza": Vector3(0.0, 0.1, 0.25),
		"cola0": Vector3(0.0, -0.12, 0.05), "cola2": Vector3(0.0, -0.15, 0.0), "cola4": Vector3(0.0, -0.15, 0.0),
		"brazo_n": Vector3(0.3, 0.0, 0.4), "brazo_f": Vector3(0.0, 0.0, 0.4),
	},
}
## Retoques por especie (el oso, más ancho, baja más las patas de arriba).
const ROT_ART := {
	"oso": { "hombro_n": Vector3(0.68, 0.0, 0.3), "cadera_n": Vector3(0.62, 0.0, -0.3), "hombro_f": Vector3(0.16, 0.0, -0.08),
		"cadera_f": Vector3(0.16, 0.0, 0.1) },
}
## Los huesos de la raíz de cada pata (los que se mueven con el respingo de dolor): pata → hueso. La vista pide la pata
## por su nombre de la cetrería (ClawCareState.paws_of).
const LEG_BONES := {
	"mamifero": {
		"delantera_derecha": "hombro_n", "delantera_izquierda": "hombro_f", "trasera_derecha": "cadera_n",
		"trasera_izquierda": "cadera_f",
	},
	"ave": { "derecha": "tibia_n", "izquierda": "tibia_f" },
	"teropodo": { "derecha": "muslo_n", "izquierda": "muslo_f" },
}


## La postura «dormido» del modelo (data: el de la caché de Animal3D), de la de referencia más los giros de ROT.
static func posture(data: Dictionary, art := "") -> Dictionary:
	var kind := String(data.info.get("kind", ""))
	var ref: Dictionary = data.postures.get(String(data.info.get("ref_posture", "")), {})
	var out := ref.duplicate()
	var rot: Dictionary = (ROT.get(kind, {}) as Dictionary).duplicate()
	rot.merge(ROT_ART.get(art, {}), true)
	for b: String in rot:
		out[b] = rot[b]
	return out


## El hueso de la raíz de una pata de la cetrería («delantera_derecha», «izquierda»…) o «».
static func leg_bone(kind: String, paw: String) -> String:
	return String((LEG_BONES.get(kind, {}) as Dictionary).get(paw, ""))
