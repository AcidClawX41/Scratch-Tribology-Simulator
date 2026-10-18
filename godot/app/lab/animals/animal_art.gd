## Los animales del coche en marcha: qué especies tienen dibujo, su tipo, sus posturas y la escala con la que caben en
## su tamaño. Los modelos 3D están en animal3d.gd (unidad 4l: mallas hechas en código, una por familia: cassowary3d.gd,
## mammals3d.gd, birds3d.gd y theropod3d.gd); esto es lo que la vista (moving_car_view.gd) y la galería
## (demo_animales.tscn) preguntan antes de construirlos.
##
## El tamaño es un dato del estado (MovingCarState.draw_size(): alto, largo y envergadura, de MovingCar.BODIES): el
## modelo se escala igual en todas las direcciones (sin deformarlo) para que su cuerpo quepa en alto × largo tocando uno
## de los dos (fit_scale). El «cuerpo» es todo menos la cola de los mamíferos (el largo de cabeza y tronco de las fichas
## de campo) y las alas abiertas de las aves (su envergadura es spanM); en los terópodos, el largo con la cola y el alto a
## la cadera. Proporciones y colores: dibujo, con sus referencias en docs/fisica/coche-en-marcha.md §9.6.
## Uso:
##   const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
##   if AnimalArt.has_art(id): var post := AnimalArt.postures_of(id)[0]
extends RefCounted

## Los velocirraptores (Theropod.variant_of(opts): la variante del dibujo, como en la 4h).
const Theropod = preload("res://app/lab/animals/theropod3d.gd")

## Especies con dibujo (ids de garra del catálogo) y su tipo (el de MovingCar.BODIES; el velocirraptor, «teropodo»).
const KINDS := {
	"aguila": "ave", "arpia": "ave", "halcon": "ave", "buho": "ave", "lechuza": "ave", "buitre": "ave",
	"tigre": "mamifero", "oso": "mamifero", "casuario": "corredora", "velociraptor": "teropodo", "velociraptor_pelicula": "teropodo",
}
## Posturas de cada tipo (las de MovingCar.POSTURES; el velocirraptor, solo agazapado).
const POSTURES := {
	"ave": ["plegadas", "abiertas"], "mamifero": ["tumbado", "de_pie"], "corredora": ["de_pie"], "teropodo": ["tumbado"],
}


## ¿Hay dibujo para esta especie?
static func has_art(id: String) -> bool:
	return KINDS.has(id)


## Tipo de animal del dibujo («ave», «mamifero», «corredora», «teropodo») o "".
static func kind_of(id: String) -> String:
	return String(KINDS.get(id, ""))


## Posturas con dibujo de una especie.
static func postures_of(id: String) -> Array:
	return POSTURES.get(kind_of(id), [])


## Escala para que la caja del cuerpo quepa en largo × alto tocando uno de los dos, sin deformarla (las unidades de
## salida por unidad de la caja).
static func fit_scale(box: Rect2, length_px: float, height_px: float) -> float:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return 1.0
	return minf(length_px / box.size.x, height_px / box.size.y)
