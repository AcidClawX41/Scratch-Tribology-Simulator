## Tribología biológica · catálogo de la 2.0: los catálogos 1.x de data.gd más los añadidos de la 2.0.
##
## data.gd sigue siendo el port exacto de data.js (lo comparan los tests del oráculo) y no cambia. La interfaz
## (app/lab), el estado del banco (lab_state.gd) y el golden 2.0 leen de aquí: herramientas, grupos, objetivos…
## Cada catálogo es su parte 1.x, idéntica y en el mismo orden que en Data, seguida de sus añadidos de la 2.0.
##   - Añadidos: las listas V2_*. Hoy, los aguijones de core/lab/insects.gd (V2_CLAWS empieza por Insects.STINGERS y
##     V2_CLAW_GROUPS por Insects.GROUP, «Insectos»), el velocirraptor reconstruido de core/lab/velociraptor.gd (detrás,
##     Velociraptor.entries() en el grupo Velociraptor.GROUP, «Dinosaurios (reconstrucción)»; unidad 4i,
##     docs/fisica/velociraptor.md §10.1), el velocirraptor de película, que es FICCIÓN, en su propio grupo (detrás,
##     VelociraptorFilm.entries() en VelociraptorFilm.GROUP, «Dinosaurios de película (ficción)»; unidad 4i-B2: una
##     reconstrucción no lleva ficción dentro; sus datos de película llevan quality = «ficcion»), la cutícula de insecto
##     como material (V2_TARGETS, los datos de Sting.CUTICLE) y los vidrios de coche de core/lab/glazing.gd: la
##     ventanilla templada y el parabrisas laminado (Glazing.TARGETS, docs/fisica/pulido-materiales.md §6), y los dos
##     materiales nuevos de la reforja (V2_INLAYS: el rubí y la alúmina sinterizada de ForgeData.NEW_MATERIALS, unidad 5d;
##     en el catálogo desde la 5g). Cada añadido lleva las claves de una entrada 1.x de su
##     catálogo (una garra, las de Data.CLAWS; un material, las de Data.TARGETS), un id que no esté en la 1.x, y su
##     source y quality.
##   - Correcciones de la 2.0 a entradas de la 1.x: las garras pasan por ClawsV2.apply (core/lab/claws_v2.gd; unidad 1k,
##     aplicadas aquí en la 4b): el agarre de las rapaces escalado de Sustaita & Hertel (2010), los textos de su ficha y
##     `sources2` con la procedencia de cada campo corregido. Cambia la `force` del águila, la arpía y el halcón (la que
##     propone el botón de fuerza máxima; compute() usa la del deslizador), las `desc` y, desde la unidad 4i, el golpe
##     (`strike`) del casuario: la patada del coche en marcha. data.gd y el motor 1.x no cambian.
##   - Los catálogos son constantes: GDScript las pliega en copias al compilar otro script, así que se comparan por
##     valor o por id (==, find_by_id), nunca con is_same() (CONTRATOS.md). CLAWS no puede ser una constante (lleva las
##     correcciones de una función): es un static var que se calcula una vez al cargar el script y nadie vuelve a
##     escribir (seguro para hilos, como las constantes de v8_math.gd; lo vigila tests/lab/test_threads.gd).
## Uso: const Catalog = preload("res://core/lab/catalog.gd"), y después Catalog.CLAWS, Catalog.find_by_id(…).
extends RefCounted

const Data = preload("res://core/lab/data.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")
const SportsCar = preload("res://core/lab/sports_car.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

## Cutícula esclerotizada de insecto como material del banco (opcional en docs/fisica/aguijones.md §2.4 y §7.9): la
## referencia de anclaje de Sting.CUTICLE (dureza de la base de un aguijón, Das 2018; módulo de la cutícula fresca de la
## langosta, Dirks & Taylor 2012). Enseña que la abeja no se queda clavada en otro insecto. Para el resto de
## herramientas es un sólido homogéneo más; no modela las membranas blandas por las que pica una abeja.
const CUTICLE_TARGET := {
	"id": Sting.CUTICLE["id"], "name": Sting.CUTICLE["name"], "hv": Sting.CUTICLE["hv"], "E": Sting.CUTICLE["E"],
	"mohs": null, "col": "#8B5A2B", "mu": Sting.CUTICLE["mu"], "W": Sting.CUTICLE["W"],
	"fact": "Cutícula esclerotizada de un insecto (quitina y proteínas): ~43 HV, la dureza de la base de un aguijón (Das 2018), y 3 GPa, el módulo de la cutícula fresca de una langosta (Dirks & Taylor 2012). Es la prueba del anclaje: se estira un 5 % como mucho antes de ceder, y la púa de una abeja pide un 9 %, así que no se cierra tras las púas y el aguijón sale por el surco. Por eso la abeja no lo pierde cuando pica a otro insecto (Tautz 2008). Su punta, de ~7 HV, tampoco atraviesa un esclerito: pica por las membranas blandas de las articulaciones, que aquí no están.",
	"source": Sting.CUTICLE["source"], "quality": Sting.CUTICLE["quality"],
}

# ── Añadidos de la 2.0 (con su fuente y su calidad en cada entrada) ──
const V2_GEOMS := []
const V2_BASES := []
const V2_BASE_GROUPS := []
## Los materiales nuevos de la reforja (unidad 5d), tal cual vienen de ForgeData.NEW_MATERIALS: el rubí (corindón con
## cromo: la mecánica del zafiro y otro color) y la alúmina sinterizada (CoorsTek AD-995). Llevan las claves de
## Data.INLAYS (nombre, nombre corto, dureza, módulo, la talla de la incrustación y el color para la interfaz), su source y
## su quality, y lo que piden los motores de la garra (densidad, resistencia y tenacidad; ClawMass y ClawFracture tienen
## su fila, con la misma cifra: un test lo comprueba).
const V2_INLAYS := [ForgeData.NEW_MATERIALS["rubi"], ForgeData.NEW_MATERIALS["alumina"]]
## Los aguijones y, detrás, el velocirraptor reconstruido (Velociraptor.ENTRY: su `entries()` es [ENTRY], y una constante
## no puede llamar a una función) y el de película (VelociraptorFilm.ENTRY, ficción).
const V2_CLAWS := Insects.STINGERS + [Velociraptor.ENTRY, VelociraptorFilm.ENTRY]
const V2_CLAW_GROUPS := [Insects.GROUP, Velociraptor.GROUP, VelociraptorFilm.GROUP]
const V2_TARGETS := [CUTICLE_TARGET, Glazing.SIDE_WINDOW, Glazing.WINDSCREEN, SportsCar.ENTRY]
const V2_TYPES := []

# ── Catálogos de la aplicación: 1.x + 2.0 ──
const GEOMS := Data.GEOMS + V2_GEOMS
const BASES := Data.BASES + V2_BASES
const BASE_GROUPS := Data.BASE_GROUPS + V2_BASE_GROUPS
const INLAYS := Data.INLAYS + V2_INLAYS
## Las garras de data.gd con las correcciones de la 2.0 (ClawsV2.apply) y, detrás, los aguijones.
static var CLAWS: Array = _claws_2_0()
const CLAW_GROUPS := Data.CLAW_GROUPS + V2_CLAW_GROUPS
const TARGETS := Data.TARGETS + V2_TARGETS
const TYPES := Data.TYPES + V2_TYPES
## Sin añadidos: las capas de la piel y de la pintura y la mano humana son las de la 1.x.
const SKIN_LAYERS := Data.SKIN_LAYERS
const PAINT_LAYERS := Data.PAINT_LAYERS
const HUMAN := Data.HUMAN

## Nombre de cada catálogo → [parte 1.x, añadidos de la 2.0] (para los tests y las herramientas). La parte 1.x es la de
## data.gd tal cual; en CLAWS, la aplicación la usa con las correcciones de la 2.0 (list() y CLAWS).
const PARTS := {
	"GEOMS": [Data.GEOMS, V2_GEOMS], "BASES": [Data.BASES, V2_BASES], "BASE_GROUPS": [Data.BASE_GROUPS, V2_BASE_GROUPS],
	"INLAYS": [Data.INLAYS, V2_INLAYS], "CLAWS": [Data.CLAWS, V2_CLAWS], "CLAW_GROUPS": [Data.CLAW_GROUPS, V2_CLAW_GROUPS],
	"TARGETS": [Data.TARGETS, V2_TARGETS], "TYPES": [Data.TYPES, V2_TYPES],
}


## Primera entrada de un catálogo con ese id, o null.
static func find_by_id(list: Array, id: Variant) -> Variant:
	return Data.find_by_id(list, id)


## Título de una garra, colmillo o aguijón (Data.claw_title).
static func claw_title(c: Dictionary) -> String:
	return Data.claw_title(c)


## Capas de un coche, o null si el material no es un coche (Data.car_layers).
static func car_layers(target: Variant) -> Variant:
	return Data.car_layers(target)


## Catálogo por su nombre ("GEOMS", "CLAWS"…): el de la aplicación, 1.x + 2.0 (las garras, con sus correcciones).
static func list(name: String) -> Array:
	if name == "CLAWS":
		return CLAWS
	var parts: Array = PARTS[name]
	return (parts[0] as Array) + (parts[1] as Array)


## Las garras de la 2.0: cada una de data.gd con ClawsV2.apply (una copia corregida si tiene correcciones, idéntica si no)
## y los aguijones detrás. Se llama una sola vez, al cargar el script (CLAWS).
static func _claws_2_0() -> Array:
	var out: Array = []
	for c: Dictionary in Data.CLAWS:
		out.append(ClawsV2.apply(c))
	return out + V2_CLAWS


## ¿Es un añadido de la 2.0 (no está en data.gd)?
static func is_v2(name: String, id: Variant) -> bool:
	return find_by_id(PARTS[name][1], id) != null
