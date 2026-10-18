## Tribología biológica · el velocirraptor de película (FICCIÓN; catálogo de la 2.0, no existe en el motor 1.x).
##
## Petición de Eric (unidad 4i-B2): «un Velociraptor con una física algo más similar a Jurassic Park, […] que sus garras en
## forma falciforme puedan desgarrar algo el chasis y ciertas cosas». Para no romper la honestidad del programa hay DOS
## velocirraptores: la reconstrucción (core/lab/velociraptor.gd, 19,7 kg, pincha y sujeta) sigue tal cual, como dato; este es
## el de la película, en su propio grupo del catálogo («Dinosaurios de película (ficción)»: una reconstrucción no puede
## llevar ficción dentro).
##   - Lo que puede ser real, lo es. Los raptores de la película de 1993 tienen el tamaño de Deinonychus: Michael Crichton
##     basó los de la novela en Deinonychus, que Gregory Paul (1988) metía en Velociraptor, y los modelos de la película se
##     diseñaron casi enteramente con Deinonychus. Así que el tamaño, la masa (su fémur, con el mismo escalado que la
##     reconstrucción), la garra (reconstruida por Ostrom), el agarre (escalado de los gavilanes), la garra sola (Bishop
##     2019 modeló un Deinonychus), la carrera y el salto (los mismos w y f de MovingCar.KICK) son datos, con su calidad.
##   - Lo fantástico se marca como FICCIÓN (quality = «ficcion»), nunca como dato: que su garra falciforme raje en vez de
##     pinchar y que corte la chapa de un coche. Para que el motor de siempre lo haga (sin física nueva), la garra de
##     película tiene la dureza y el módulo de la tachuela de acero del banco (Data.INLAYS «acero»: 200 HV, 200 GPa): más dura
##     que el acero de la carrocería (101 HV). La de verdad es de queratina (32 HV) y no corta la chapa.
##   - Lo que no se ha medido en Deinonychus (la punta de la garra) es la misma pregunta abierta que en la reconstrucción.
## ENTRY lleva las claves de una garra de Data.CLAWS (como Velociraptor.ENTRY) y el bloque `dino`, con `film = true` y
## `fiction` (los valores de película). Especificación: docs/fisica/velociraptor.md §11.
## Uso: const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd").
extends RefCounted

const Velociraptor = preload("res://core/lab/velociraptor.gd")

## Grupo del catálogo 2.0: aparte de «Dinosaurios (reconstrucción)», que solo lleva datos.
const GROUP := "Dinosaurios de película (ficción)"
## Calidad de lo que es de película: ni medido ni estimado (CONTRATOS.md → «Fase 2»: nunca se presenta como dato).
const FICTION_QUALITY := "ficcion"

# ── Fuentes ──
const SRC_OSTROM_1969 := "Ostrom JH (1969). Osteology of Deinonychus antirrhopus, an unusual theropod from the Lower Cretaceous of Montana. Bull. Peabody Mus. Nat. Hist. 30:1-165 (la garra del dedo II de YPM 5205, reconstruida con su estuche de queratina: más de 120 mm; citado en la recopilación de Wikipedia, «Deinonychus»)"
const SRC_DEINONYCHUS_SIZE := "Deinonychus antirrhopus: 3,3-3,4 m de largo y 0,87 m de cadera (Paul GS 2016, The Princeton Field Guide to Dinosaurs, 2.ª ed.; recopilado en Wikipedia, «Deinonychus»; solo para el dibujo)"
const SRC_CRICHTON := "Michael Crichton basó los velocirraptores de Jurassic Park (1990) en Deinonychus «en casi todos los detalles», que Gregory Paul (1988, Predatory Dinosaurs of the World) incluía en Velociraptor (V. antirrhopus); los de la película (Universal Pictures, 1993) se diseñaron casi enteramente con Deinonychus (recopilado en Wikipedia, «Deinonychus», con sus fuentes)"
const SRC_FILM := "Jurassic Park (1993), dirigida por Steven Spielberg, Universal Pictures: los raptores rajan y saltan como en el cine; nada de eso se ha medido"
## Las referencias de la entrada, una por «; » con su autor y su año (la línea corta de la ficha: StingLab.short_sources).
const SRC_REFS := "Jurassic Park (1993), Universal Pictures, dirigida por Steven Spielberg: los raptores de la película, ficción; Crichton M (1990). Jurassic Park. Alfred A. Knopf (los velocirraptores de la novela, basados en Deinonychus); Paul GS (1988). Predatory Dinosaurs of the World. Simon & Schuster (Deinonychus antirrhopus como Velociraptor antirrhopus)"
const SRC_REAL_CLAW := "La garra de verdad es de queratina: ~32 HV (la del banco; McKittrick et al. 2012), menos que el acero de la carrocería (101 HV, el HC180B del catálogo): por debajo de 0,8 veces su dureza cede la punta y no la corta (Tabor 1954; Richardson 1968). Una réplica robótica de la garra de Deinonychus solo hizo punciones redondas de 3-4 cm en un cerdo, nunca un tajo (Manning et al. 2006); el animal pinchaba y sujetaba a la presa con su peso (Fowler et al. 2011)"

# ── Masa (kg): el mismo escalado del fémur que la reconstrucción (Campione et al. 2014) ──
## Circunferencia mínima del fémur de Deinonychus (mm) y su α² en los datos de Campione et al. (2014) (MASSTIMATE, dinosbip).
const FEMUR_CIRC_MM := 116.0
const FEMUR_ALPHA2 := 1.987
## Reconstrucciones volumétricas de Deinonychus recopiladas por Campione & Evans (2020) (kg): polinomio, cortes y dos
## modelos físicos (MASSTIMATE, dino_comparisons).
const VOLUMETRIC_KG := [44.3, 56.67, 73.0, 73.0]
const MASS := {
	"value": 99.8, "min": 44.3, "max": 124.8, "unit": "kg", "quality": "estimate",
	"source": "Valor: el escalado del fémur, 99,8 kg (circunferencia de 116 mm con α² = 1,987; " + Velociraptor.SRC_CAMPIONE_2014 + "; " + Velociraptor.SRC_CAMPIONE_2012 + "; datos de " + Velociraptor.SRC_MASSTIMATE + "), el mismo método que la reconstrucción de Velociraptor. Banda: de 44,3 kg (la reconstrucción volumétrica más ligera) a 124,8 kg (el escalado más su error de predicción del 25 %). Las cuatro reconstrucciones volumétricas recopiladas (44,3, 56,7, 73 y 73 kg; " + Velociraptor.SRC_CAMPIONE_2020 + ") caen por debajo, como en los dinosaurios pequeños. Gregory Paul da 60-73 kg",
}

# ── Cuerpo (Deinonychus; solo para el dibujo) ──
const BODY := {
	"lengthM": { "value": 3.4, "min": 3.3, "max": 3.4, "quality": "secondary", "source": SRC_DEINONYCHUS_SIZE },
	"hipM": { "value": 0.87, "quality": "secondary", "source": SRC_DEINONYCHUS_SIZE },
	"model": { "value": "Deinonychus", "quality": "secondary", "source": SRC_CRICHTON },
}

# ── Garra falciforme: la de Deinonychus, con la dureza de película ──
## Garra de Deinonychus con su estuche (mm): Ostrom (1969) la reconstruyó en más de 120 mm.
const KERATIN_MM := 120.0
const SICKLE := {
	"keratinMm": { "value": KERATIN_MM, "min": KERATIN_MM, "max": KERATIN_MM, "quality": "secondary", "source": SRC_OSTROM_1969 },
	"coreMm": {
		"value": KERATIN_MM * Velociraptor.CORE_TO_SHEATH, "quality": "estimate",
		"source": "solo para el dibujo: el estuche de Ostrom (120 mm) por la proporción núcleo/estuche de las aves (0,699; " + Velociraptor.SRC_HEDRICK_2019 + ")",
	},
	"coreHeightMm": {
		"value": 18.7 * KERATIN_MM / 92.7, "quality": "estimate",
		"source": "solo para el dibujo: la base de la garra de Velociraptor (18,7 mm de alto; Norell & Makovicky 1999) escalada con el largo de la garra (120/92,7)",
	},
	"coreWidthMm": {
		"value": 7.1 * KERATIN_MM / 92.7, "quality": "estimate",
		"source": "solo para el dibujo: la base de la garra de Velociraptor (7,1 mm de ancho; Norell & Makovicky 1999) escalada con el largo de la garra (120/92,7)",
	},
	"arcDeg": { "value": 160.0, "quality": "secondary", "source": "el arco interior de la garra del dedo II de Deinonychus, 160° (" + Velociraptor.SRC_MANNING_2006 + ")" },
	"tipRadiusUm": Velociraptor.SICKLE.tipRadiusUm,
	"alphaDeg": Velociraptor.SICKLE.alphaDeg,
	"hv": {
		"value": 200.0, "quality": FICTION_QUALITY,
		"source": "FICCIÓN (película): para que raje la chapa como en el cine, la garra de película corta como la tachuela de acero del banco (200 HV), el doble que el acero de la carrocería. " + SRC_REAL_CLAW,
	},
	"E": {
		"value": 200.0, "quality": FICTION_QUALITY,
		"source": "FICCIÓN (película): el módulo de la tachuela de acero del banco (200 GPa); la queratina de verdad, 2 GPa (McKittrick et al. 2012)",
	},
}

# ── Lo que es de película (ficción) ──
const FICTION := {
	"claw": {
		"hv": SICKLE.hv.value, "E": SICKLE.E.value, "mohs": 5.5, "quality": FICTION_QUALITY, "source": SICKLE.hv.source,
	},
	"slash": {
		"quality": FICTION_QUALITY,
		"source": "FICCIÓN (película): su garra falciforme raja la chapa al resbalar y la perfora al golpear, con el motor de siempre (el de las garras reforjadas que cortan el metal, el desgarro del plástico y la abolladura de la chapa) y la garra de película. " + SRC_REAL_CLAW,
	},
	"film": { "quality": FICTION_QUALITY, "source": SRC_FILM + ". " + SRC_CRICHTON },
}

# ── Fuerzas (N): las de la reconstrucción, con la masa de Deinonychus ──
const MASS_KG := 99.8
const FORCES := {
	"grip": {
		"value": 1841.0, "min": 696.4, "max": 5452.3, "unit": "N", "quality": "estimate",
		"source": "Agarre de un pie de 99,8 kg escalado desde el gavilán de Cooper hembra (9,77 N, 450 g) con la pendiente de los accipítridos, 0,97 (banda: pendiente 0,79 abajo; ×2,96 arriba, la dispersión entre técnicas), como el de la reconstrucción: " + Velociraptor.ClawsV2.SRC_SUSTAITA + ". Suposición: el pie de un dromeosáurido agarraba como el de un gavilán (" + Velociraptor.SRC_FOWLER_2011 + "). Es una extrapolación de ×222 en masa sobre lo medido",
	},
	"clawMuscle": {
		"value": 30.0, "min": 30.0, "max": 57.0, "unit": "N", "quality": "estimate",
		"source": "la garra sola, movida por sus músculos: " + Velociraptor.SRC_BISHOP_2019 + " modeló un Deinonychus de 490 N (18,9 N en la punta ósea); escalado a 99,8 kg con la semejanza geométrica (∝ m^(2/3)); banda alta con el doble de músculo (×1,901)",
	},
	"replica": {
		"value": 2446.8, "unit": "N", "quality": "secondary",
		"source": "la carga de la réplica de la garra de Deinonychus, 2,5 veces el peso, con la masa de su fémur: 2,5 × 99,8 × 9,807 N (" + Velociraptor.SRC_MANNING_2006 + ")",
	},
}

# ── Carrera y salto ──
const LOCOMOTION := {
	"runMs": {
		"value": Velociraptor.RUN_MS, "min": Velociraptor.RUN_MS, "max": 13.67, "quality": "estimate",
		"source": "Sin un modelo de la carrera de Deinonychus entre las fuentes usadas: la del modelo de su pariente Velociraptor, el caso modelado más parecido (" + Velociraptor.SRC_SELLERS_2007 + "; banda alta, la mayor subestimación del mismo modelo en especies actuales). En la película corren como un guepardo (ficción)",
	},
	"leapMs": Velociraptor.LOCOMOTION.leapMs,
}

# ── Coche en marcha ──
const CAR := {
	"contactMm": {
		"value": 50.0, "quality": "estimate",
		"source": "radio del apoyo del pie: el de la reconstrucción (~30 mm, del orden de las dos primeras falanges del dedo III, Norell & Makovicky 1999) escalado con la cadera de Deinonychus (0,87/0,5 m): ~50 mm. Solo reparte el peso o el golpe sobre el parabrisas",
	},
}

## La entrada del catálogo 2.0: todas las claves de una garra de Data.CLAWS, más `dino`.
##   - name: «Velocirraptor de cine», corto para que quepa en la comparativa del teléfono (los nombres del catálogo no
##     pasan de 18 letras); la ficha dice «de película (ficción)» en su título y en su grupo.
##   - hv, E, mohs: la garra de película (FICCIÓN: la tachuela de acero del banco).
##   - area, alpha: la punta del talón de la arpía, como la reconstrucción (sin medición: pregunta abierta).
##   - reach: la garra de Deinonychus con su estuche (Ostrom 1969); curve: 0,9, como la reconstrucción (arco de 160°).
##   - mass: MASS (el fémur de Deinonychus); force: FORCES.grip, el agarre de un pie.
##   - strike: como la reconstrucción, cae con los dos pies por delante a la velocidad del salto (los mismos w y f) y cada
##     pie lleva la mitad del impulso.
const ENTRY := {
	"id": "velociraptor_pelicula", "group": GROUP, "name": "Velocirraptor de cine",
	"title": "Garra de velocirraptor de película (ficción)",
	"hv": 200.0, "mohs": 5.5, "E": 200.0, "area": 0.06, "alpha": 15.0, "reach": KERATIN_MM, "curve": 0.9,
	"mass": MASS_KG, "force": 1841.0, "strike": { "v": 4.84, "m": MASS_KG / 2.0 }, "col": "#6B5B3E",
	"desc": "FICCIÓN: el velocirraptor de Jurassic Park (1993). Tiene el tamaño de Deinonychus, en el que se basó la película: ~100 kg por su fémur y 3,4 m de largo. Su garra de película raja la chapa de un coche como si fuera de acero (200 HV): eso es cine. La de verdad es de queratina (32 HV) y no corta la chapa; el Velociraptor de verdad era del tamaño de un pavo, con plumas, y pinchaba y sujetaba a la presa con su peso (Manning 2006; Fowler 2011).",
	"source": SRC_REFS + "; " + Velociraptor.SRC_CAMPIONE_2014 + "; " + SRC_OSTROM_1969,
	"quality": FICTION_QUALITY,
	"dino": {
		"species": "velocirraptor de Jurassic Park, con el tamaño de Deinonychus antirrhopus", "family": "Dromaeosauridae",
		"reconstruction": false, "film": true,
		"mass": MASS, "body": BODY, "sickle": SICKLE, "forces": FORCES, "locomotion": LOCOMOTION, "fiction": FICTION,
		"car": CAR,
		"colors": { "body": "#8C7651", "feathers": "#5E4B33", "claw": "#3D3A36", "quality": "dibujo" },
	},
}


## ¿Es un animal de película? (la garra de un catálogo con `dino.film`)
static func is_film(tool: Variant) -> bool:
	return tool is Dictionary and tool.get("dino") is Dictionary and tool.dino.get("film") == true


## Los dinosaurios de película del catálogo 2.0 (por ahora, uno).
static func entries() -> Array:
	return [ENTRY]


## La masa por el fémur de Deinonychus (kg), con el mismo escalado que la reconstrucción (Velociraptor.cqe_mass_kg).
static func femur_mass_kg() -> float:
	return Velociraptor.cqe_mass_kg(FEMUR_CIRC_MM, FEMUR_ALPHA2)
