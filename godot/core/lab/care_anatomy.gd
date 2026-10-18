## Cetrería · las medidas de cada animal entero (unidad 5i, petición 37): el largo, la envergadura o el alto a la cruz y la
## masa de cada especie de la cetrería, con su fuente y su calidad, para dibujar su cuerpo de alta definición a su tamaño
## (app/lab/cetreria/care_body.gd). Determinista y sin nodos.
##   - Las rapaces: el largo (del pico a la punta de la cola), la envergadura y la masa de su ficha. El ala plegada (del
##     codo de la mano, el carpo, a la punta de la primaria más larga) es la medida de la lechuza (BTO); en las demás, una
##     proporción de dibujo de la envergadura (wing_k).
##   - El tigre y el oso: el largo de la cabeza y el cuerpo, la cola, el alto a la cruz y la masa; el largo del pelo, el ojo
##     y el cráneo del tigre (Mazák 1981: el largo, la anchura, lo separadas que van las órbitas y, desde la 5n, la anchura
##     del hocico) y el pelo y la cabeza del oso (Pasitschniak-Arts 1993), con su cráneo desde la 5n (los machos de Kodiak:
##     la longitud condilobasal y la anchura cigomática; el hocico, la frente y los huesos nasales de los machos de Siberia,
##     en proporción) y el largo de la oreja.
##   - Los velocirraptores: los de su ficha (core/lab/velociraptor.gd y velociraptor_film.gd), leídos de allí, sin copias;
##     el cráneo de la reconstrucción, el de GIN 100/25 medido por Barsbold y Osmólska (1999), con los labios que tapan los
##     dientes (Cullen et al. 2023) (5n).
##   - El búho real y la lechuza (5n): el disco facial y el color de los ojos, con su fuente, y el largo de los penachos
##     del búho (Delgado y Penteriani 2004).
## La masa es la del banco (Data.CLAWS: la del animal de la garra que se trabaja), dentro de lo publicado para la especie;
## el dibujo elige el largo de un animal de esa masa (una hembra en las rapaces grandes, un macho en el tigre y el oso).
## Cada medida es { value, min?, max?, unit, quality, source }: quality «primary» (medido en la especie), «secondary»
## (recopilado, o el rango publicado) o «estimate» (el caso medido más parecido, con la suposición escrita al lado).
## Lo que es solo dibujo (las proporciones de la cabeza o del ala plegada) lleva quality «dibujo» y no se enseña como dato.
## Lo que se describe sin número (la forma del disco facial, el color del iris, si los labios tapan los dientes) es
## { value (texto), quality, source }: rows() no lo lista (no es una medida), pero lleva su fuente igual.
## Unidades: longitudes en m (el ojo y el pelo, en mm) · masa en kg.
## Uso: const CareAnatomy = preload("res://core/lab/care_anatomy.gd"); CareAnatomy.of("tigre"), CareAnatomy.draw_length_m(art).
extends RefCounted

const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")

## Los dibujos de la cetrería con cuerpo propio: las rapaces (por la garra del banco), el tigre, el oso y los dos
## velocirraptores (la reconstrucción y el de película: mismo animal y misma física, otro dibujo).
const RAPTOR_ARTS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const ARTS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "tigre", "oso", "velociraptor", "velociraptor_pelicula"]
const QUALITIES := ["primary", "secondary", "estimate"]

# ── Fuentes ──
const SRC_ADW := "Animal Diversity Web (Museo de Zoología de la Universidad de Míchigan)"
const SRC_ADW_AQUILA := "Kirschbaum K, Ivory A (2002). Aquila chrysaetos. " + SRC_ADW + ": largo 70-84 cm, envergadura 185-220 cm, masa 3000-6125 g (hembras 3940-6125 g, machos 3000-4475 g)"
const SRC_ADW_HARPIA := "Shaner K (2011). Harpia harpyja. " + SRC_ADW + ": largo 89-102 cm (89-109 en su ficha), envergadura de 2 m, masa 5-9 kg (hembras 7-9 kg, machos 5-8 kg)"
const SRC_ADW_FALCO := "Potter M (2002). Falco peregrinus. " + SRC_ADW + ": largo 36-58 cm (machos 36-49, hembras 45-58 cm), envergadura 91-112 cm, masa media 907 g; las hembras, un 15-20 % más grandes y un 40-50 % más pesadas"
const SRC_ADW_BUBO := "Cantrell J (2004). Bubo bubo. " + SRC_ADW + ": largo 58-71 cm (65 de media), envergadura 1,5-2 m, masa 1600-4200 g (2800 g de media); la hembra, más grande"
const SRC_ADW_TYTO := "Bachynski K, Harris MS (2002). Tyto alba. " + SRC_ADW + ": largo 32-40 cm (machos 32-38, hembras 34-40 cm), envergadura 107-110 cm y masa 430-620 g, de lechuzas de Norteamérica"
const SRC_BTO_TYTO := "BTO BirdFacts, «Barn Owl» (British Trust for Ornithology, de aves vivas anilladas en Gran Bretaña): ala de 292,2 ± 7,6 mm (280-304 mm, 536 adultos) y masa de 337,3 ± 43,6 g (280-420 g, 522 adultos)"
const SRC_BOW_GYPS := "Salvador A (2026). Eurasian Griffon (Gyps fulvus), versión 11.0. Birds of the World, Cornell Lab of Ornithology, con los datos de Brown LH, Urban EK, Newman K (1982), The Birds of Africa, vol. 1: largo 106,4-119,9 cm, envergadura 232,6-275,6 cm, masa 6,2-10,5 kg los machos y 6,5-11,2 kg las hembras"
const SRC_HAREL_2016 := "Harel R, Horvitz N, Nathan R (2016). Adult vultures outperform juveniles in challenging thermal soaring conditions. Sci. Rep. 6:27865, doi:10.1038/srep27865 (buitres leonados de ~8 kg: carga alar de 9 kg/m² y alargamiento 7,61; envergadura b = √(7,61·S) = 2,6 m, la del coche en marcha)"
const SRC_MAZAK_1981 := "Mazák V (1981). Panthera tigris. Mammalian Species 152:1-8, doi:10.2307/3504004"
const SRC_SDZWA_TIGER := "San Diego Zoo Wildlife Alliance Library, «Tiger (Panthera tigris) fact sheet: characteristics», con Hunter L (2011), Carnivores of the World, y " + SRC_MAZAK_1981 + ": machos de 189-300 cm de cabeza y cuerpo, cola de 72-109 cm y 80-100 cm de alto a la cruz"
const SRC_PASITSCHNIAK_1993 := "Pasitschniak-Arts M (1993). Ursus arctos. Mammalian Species 439:1-10, doi:10.2307/3504138"
const SRC_HALL_1984 := "Hall ER (1984). Geographic variation among brown and grizzly bears (Ursus arctos) in North America. Spec. Publ. Mus. Nat. Hist. Univ. Kansas 13:1-16"
const SRC_STROGANOV_1969 := "Stroganov SU (1969). Carnivorous mammals of Siberia. Israel Program for Scientific Translations, Jerusalem"
const SRC_BEAR_SIBERIA := "los cráneos de 22 machos del este de Siberia (" + SRC_STROGANOV_1969 + ", recogido en " + SRC_PASITSCHNIAK_1993 + "): longitud condilobasal 380 mm, anchura cigomática 253, anchura interorbitaria 96, anchura del hocico sobre los caninos 83 y largo de los nasales 105 mm"
const SRC_BARSBOLD_1999 := "Barsbold R, Osmólska H (1999). The skull of Velociraptor (Theropoda) from the Late Cretaceous of Mongolia. Acta Palaeontologica Polonica 44(2):189-219"
const SRC_CULLEN_2023 := "Cullen TM, Larson DW, Witton MP, Scott D, Maho T, Brink KS, Evans DC, Reisz R (2023). Theropod dinosaur facial reconstruction and the importance of soft tissues in paleobiology. Science 379(6639):1348-1352, doi:10.1126/science.abo7877"
const SRC_DELGADO_2004 := "Delgado MM, Penteriani V (2004). Gender determination of Eurasian Eagle-Owls (Bubo bubo) by morphology. J. Raptor Res. 38(4):375-377, tabla 1 (pieles de museo de búhos reales de España)"
const SRC_BUBO_FACE := "Penteriani V, Delgado MM (2019), The Eagle Owl (Bloomsbury), y König C, Weick F (2008), Owls of the World, 2.ª ed. (Christopher Helm), tal como los recoge la Wikipedia en inglés («Eurasian eagle-owl», consultada el 04-10-2026)"
const SRC_TYTO_FACE := "Marti CD, Poole AF, Bevier LR, Bruce MD, Christie D, Kirwan GM, Marks JS, Pyle P, Lusby J (2024). Western Barn Owl (Tyto alba), versión 1.0. Birds of the World, Cornell Lab of Ornithology, doi:10.2173/bow.webowl1.01, y Bruce MD (1999), Family Tytonidae, Handbook of the Birds of the World 5:34-75 (Lynx), tal como los recoge la Wikipedia en inglés («Western barn owl», consultada el 04-10-2026)"
const SRC_KNUDSEN_1979 := "Knudsen EI, Konishi M (1979). Mechanisms of sound localization in the barn owl (Tyto alba). J. Comp. Physiol. 133:13-21, doi:10.1007/BF00663106"
const SRC_BANCO := "la masa de la garra del banco (Data.CLAWS, la de la ficha del animal de la 1.x)"

# ── Medidas ──
const SPECIES := {
	"aguila": {
		"kind": "ave", "name": "Águila real", "latin": "Aquila chrysaetos",
		"length_m": { "value": 0.82, "min": 0.70, "max": 0.84, "unit": "m", "quality": "secondary",
			"source": SRC_ADW_AQUILA + ". Para el dibujo, una hembra (la del banco pesa 5 kg): hacia lo alto del rango" },
		"span_m": { "value": 2.10, "min": 1.85, "max": 2.20, "unit": "m", "quality": "secondary", "source": SRC_ADW_AQUILA },
		"mass_kg": { "value": 5.0, "min": 3.0, "max": 6.125, "unit": "kg", "quality": "secondary", "source": SRC_BANCO + ", dentro de lo de " + SRC_ADW_AQUILA },
	},
	"arpia": {
		"kind": "ave", "name": "Águila arpía", "latin": "Harpia harpyja",
		"length_m": { "value": 1.0, "min": 0.89, "max": 1.02, "unit": "m", "quality": "secondary",
			"source": SRC_ADW_HARPIA + ". Para el dibujo, una hembra grande (la del banco pesa 9 kg)" },
		"span_m": { "value": 2.0, "unit": "m", "quality": "secondary", "source": SRC_ADW_HARPIA },
		"mass_kg": { "value": 9.0, "min": 5.0, "max": 9.0, "unit": "kg", "quality": "secondary", "source": SRC_BANCO + ", dentro de lo de " + SRC_ADW_HARPIA },
	},
	"halcon": {
		"kind": "ave", "name": "Halcón peregrino", "latin": "Falco peregrinus",
		"length_m": { "value": 0.48, "min": 0.36, "max": 0.58, "unit": "m", "quality": "secondary",
			"source": SRC_ADW_FALCO + ". Para el dibujo, una hembra (la del banco pesa 1 kg, más que la media)" },
		"span_m": { "value": 1.05, "min": 0.91, "max": 1.12, "unit": "m", "quality": "secondary", "source": SRC_ADW_FALCO },
		"mass_kg": { "value": 1.0, "min": 0.53, "max": 1.6, "unit": "kg", "quality": "secondary",
			"source": SRC_BANCO + ", algo por encima de la media de " + SRC_ADW_FALCO + "; el rango, de una hembra grande a un macho pequeño, es estimación" },
	},
	"buho": {
		"kind": "ave", "name": "Búho real", "latin": "Bubo bubo",
		"length_m": { "value": 0.62, "min": 0.58, "max": 0.71, "unit": "m", "quality": "secondary",
			"source": SRC_ADW_BUBO + ". Para el dibujo, un macho ligero (el del banco pesa 2 kg)" },
		"span_m": { "value": 1.6, "min": 1.5, "max": 2.0, "unit": "m", "quality": "secondary", "source": SRC_ADW_BUBO },
		"mass_kg": { "value": 2.0, "min": 1.6, "max": 4.2, "unit": "kg", "quality": "secondary", "source": SRC_BANCO + ", dentro de lo de " + SRC_ADW_BUBO },
		"ear_tuft_m": { "value": 0.0735, "min": 0.063, "max": 0.081, "unit": "m", "quality": "primary",
			"source": SRC_DELGADO_2004 + ": los penachos de 22 machos miden 72,2 ± 4,5 mm el izquierdo (63,3-81,3 mm) y 74,8 ± 3,8 mm el derecho (65-79,7 mm); los de 28 hembras, 73,0 y 72,2 mm de media. Para el dibujo, la media de los dos de un macho" },
		"facial_disc": { "value": "leonado, con motas pardo negruzcas tan densas en el borde que le hacen un marco", "quality": "secondary",
			"source": SRC_BUBO_FACE + ": «the facial disc is tawny-buff, speckled with black-brown, so densely on the outer edge of the disc as to form a frame around the face»; una banda clara sube de la base del pico por encima del ojo y por el borde de dentro de los penachos, que son pardo negruzcos; la barbilla y la garganta, blancas" },
		"iris": { "value": "naranja", "quality": "secondary",
			"source": "Cantrell J (2004). Bubo bubo. " + SRC_ADW + ": «best known for their large, striking, orange eyes»; el iris, casi siempre naranja, aunque varía (" + SRC_BUBO_FACE + ")" },
	},
	"lechuza": {
		"kind": "ave", "name": "Lechuza común", "latin": "Tyto alba",
		"length_m": { "value": 0.35, "min": 0.32, "max": 0.40, "unit": "m", "quality": "secondary", "source": SRC_ADW_TYTO },
		"span_m": { "value": 0.9, "min": 0.85, "max": 1.10, "unit": "m", "quality": "estimate",
			"source": "la de Norteamérica mide 107-110 cm (" + SRC_ADW_TYTO + "); la del banco (0,35 kg) es la europea, más pequeña: unas tres veces el ala medida (" + SRC_BTO_TYTO + "), como en las demás rapaces. Estimación" },
		"wing_m": { "value": 0.292, "min": 0.28, "max": 0.304, "unit": "m", "quality": "secondary", "source": SRC_BTO_TYTO },
		"mass_kg": { "value": 0.35, "min": 0.28, "max": 0.42, "unit": "kg", "quality": "secondary", "source": SRC_BANCO + ", dentro de lo de " + SRC_BTO_TYTO },
		"facial_disc": { "value": "en forma de corazón, blanco, con su borde de plumas rígidas", "quality": "secondary",
			"source": "BTO BirdFacts, «Barn Owl»: «a distinctively heart-shaped face»; la cara en forma de corazón, casi siempre de un blanco brillante (" + SRC_TYTO_FACE + "); el borde es la gorguera de plumas rígidas que hace de pabellón de la oreja: sin ella, la lechuza localiza el sonido de lado pero no en altura (" + SRC_KNUDSEN_1979 + ")" },
		"iris": { "value": "pardo negruzco", "quality": "secondary", "source": "el iris, pardo negruzco (" + SRC_TYTO_FACE + ")" },
	},
	"buitre": {
		"kind": "ave", "name": "Buitre leonado", "latin": "Gyps fulvus",
		"length_m": { "value": 1.1, "min": 1.064, "max": 1.199, "unit": "m", "quality": "secondary", "source": SRC_BOW_GYPS },
		"span_m": { "value": 2.6, "min": 2.326, "max": 2.756, "unit": "m", "quality": "primary", "source": SRC_HAREL_2016 + "; rango: " + SRC_BOW_GYPS },
		"mass_kg": { "value": 8.0, "min": 6.2, "max": 11.2, "unit": "kg", "quality": "secondary", "source": SRC_BANCO + ", dentro de lo de " + SRC_BOW_GYPS },
	},
	"tigre": {
		"kind": "mamifero", "name": "Tigre de Bengala", "latin": "Panthera tigris tigris",
		"total_m": { "value": 2.9, "min": 2.7, "max": 3.1, "unit": "m", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", tabla 1: largo total de los machos de P. t. tigris, 2700-3100 mm («between pegs»), con 180-258 kg; el del banco pesa 220 kg, en medio de los dos rangos" },
		"head_body_m": { "value": 1.94, "min": 1.89, "max": 2.1, "unit": "m", "quality": "estimate",
			"source": "la cola no suele pasar de la mitad de la cabeza y el cuerpo (" + SRC_MAZAK_1981 + "): con la cola en esa mitad, los 2,9 m son 1,94 m de cabeza y cuerpo y 0,96 m de cola; un macho de 170 kg medía 1980 mm de cabeza y cuerpo (Geptner y Sludskij 1972, en Mazák 1981). Suposición: la cola, en su máximo" },
		"tail_m": { "value": 0.96, "min": 0.72, "max": 1.09, "unit": "m", "quality": "estimate",
			"source": "lo que queda del largo total con la cabeza y el cuerpo de arriba; dentro de los 72-109 cm de " + SRC_SDZWA_TIGER },
		"shoulder_m": { "value": 0.95, "min": 0.8, "max": 1.0, "unit": "m", "quality": "secondary",
			"source": SRC_SDZWA_TIGER + ". Para el dibujo, hacia lo alto: un macho de 220 kg" },
		"mass_kg": { "value": 220.0, "min": 180.0, "max": 258.0, "unit": "kg", "quality": "secondary",
			"source": SRC_BANCO + ", dentro de los machos de P. t. tigris de " + SRC_MAZAK_1981 + ", tabla 1" },
		"eye_mm": { "value": 37.5, "min": 35.0, "max": 40.0, "unit": "mm", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", p. 4: el diámetro del ojo, de unos 35 a 40 mm (datos sin publicar del autor). La pupila es redonda y el iris, amarillo (p. 3)" },
		"hair_back_mm": { "value": 12.0, "min": 7.0, "max": 20.0, "unit": "mm", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", p. 1: pelo corto en las subespecies del sur, de 7 a 20 mm en el lomo y de 15 a 35 mm en la tripa; las orejas, redondas, negras por detrás con una mancha blanca en medio" },
		"hair_belly_mm": { "value": 25.0, "min": 15.0, "max": 35.0, "unit": "mm", "quality": "secondary", "source": SRC_MAZAK_1981 + ", p. 1" },
		"hind_to_fore": { "value": 1.23, "unit": "", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", p. 5: las patas traseras miden 1,23 veces las delanteras (cinco ejemplares, datos sin publicar)" },
		"skull_m": { "value": 0.355, "min": 0.329, "max": 0.378, "unit": "m", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", tabla 1: largo mayor del cráneo de los machos de P. t. tigris, 329-378 mm. Para el dibujo, en medio (un macho de 220 kg); cráneo abovedado, hocico corto y ancho (p. 1)" },
		"skull_width_m": { "value": 0.248, "unit": "m", "quality": "estimate",
			"source": "el cráneo más grande que midió Mazák (un macho del Usuri: 383 mm de largo y 268 mm de anchura cigomática; " + SRC_MAZAK_1981 + ", p. 2), con la misma proporción (0,70) en el cráneo de 355 mm. Suposición: los cráneos de los machos grandes son igual de anchos" },
		"interorbital_m": { "value": 0.077, "unit": "m", "quality": "estimate",
			"source": "la anchura entre las órbitas de ese mismo cráneo (83 mm; " + SRC_MAZAK_1981 + ", p. 2), con la misma proporción: da lo separados que van los ojos" },
		"rostrum_width_m": { "value": 0.105, "unit": "m", "quality": "estimate",
			"source": "la anchura del hocico de ese mismo cráneo (113 mm con 383 mm de largo; " + SRC_MAZAK_1981 + ", p. 2), con la misma proporción (0,295) en el cráneo de 355 mm: el hocico corto y relativamente ancho de los tigres («shorter and relatively broader rostrum», p. 1). Suposición: igual de ancho en los machos grandes" },
		"face": { "value": "cráneo abovedado, hocico corto y ancho, la cara enmarcada por pelos largos y la trufa casi tapada por el pelo desde arriba", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ": el cráneo más abovedado que el del león, con el hocico más corto y relativamente más ancho y la frente más convexa (p. 1); la cara enmarcada por pelos largos, más llamativos en los machos (p. 1); los pelos cortos de la nariz crecen casi hasta su borde, y desde arriba no se ve o casi no se ve la piel desnuda de la trufa (p. 3); la pupila, redonda, y el iris, amarillo (p. 3)" },
		"ears": { "value": "redondas y pequeñas, negras por detrás con una mancha blanca en medio", "quality": "secondary",
			"source": SRC_MAZAK_1981 + ", p. 1: «the ears are rounded and rather small, and are black on their dorsal side, with a conspicuous central white spot»; la mancha blanca sirve para intimidar a la presa y para comunicarse (p. 6)" },
	},
	"oso": {
		"kind": "mamifero", "name": "Oso pardo", "latin": "Ursus arctos",
		"head_body_m": { "value": 1.9, "min": 1.0, "max": 2.8, "unit": "m", "quality": "estimate",
			"source": "los 55 machos de Yellowstone: 164,3 cm de largo, 95,2 cm de alto y 41,7 cm de cabeza, con 193 kg de media (" + SRC_PASITSCHNIAK_1993 + "), escalados a los 300 kg del banco con la semejanza geométrica (largo ∝ m^(1/3): ×1,159). El rango, el de los adultos de la especie (la misma fuente). Suposición: un oso más pesado es igual de proporcionado" },
		"shoulder_m": { "value": 1.1, "min": 0.9, "max": 1.5, "unit": "m", "quality": "estimate",
			"source": "el alto de los machos de Yellowstone (95,2 cm) escalado igual (×1,159); hasta 1,5 m a la cruz en la especie (" + SRC_PASITSCHNIAK_1993 + ")" },
		"head_m": { "value": 0.48, "min": 0.42, "max": 0.5, "unit": "m", "quality": "estimate",
			"source": "la cabeza de los machos de Yellowstone (41,7 cm) escalada igual (×1,159) (" + SRC_PASITSCHNIAK_1993 + "): cabeza maciza, perfil cóncavo, orejas redondas y pequeñas, ojos pequeños y la joroba de los hombros" },
		"tail_m": { "value": 0.12, "min": 0.065, "max": 0.21, "unit": "m", "quality": "secondary", "source": SRC_PASITSCHNIAK_1993 + ": cola de 65-210 mm" },
		"mass_kg": { "value": 300.0, "min": 80.0, "max": 600.0, "unit": "kg", "quality": "secondary",
			"source": SRC_BANCO + ": cerca de la media de los machos de la isla de Kodiak (312 kg; " + SRC_PASITSCHNIAK_1993 + "); de 80 a más de 600 kg en la especie" },
		"hair_mm": { "value": 100.0, "min": 80.0, "max": 100.0, "unit": "mm", "quality": "secondary",
			"source": SRC_PASITSCHNIAK_1993 + ": pelos de guarda de unos 10 cm y borra de unos 8 cm; del rubio al casi negro, casi siempre pardo" },
		"skull_m": { "value": 0.393, "min": 0.332, "max": 0.397, "unit": "m", "quality": "secondary",
			"source": "longitud condilobasal media de los machos de la isla de Kodiak, 393 mm (" + SRC_HALL_1984 + ", recogido en " + SRC_PASITSCHNIAK_1993 + "), los de la masa del banco (312 kg de media); el rango, el de las medias de los machos de Norteamérica (332 mm en el Yukón, 397 mm en la península de Alaska)" },
		"skull_width_m": { "value": 0.284, "min": 0.216, "max": 0.284, "unit": "m", "quality": "secondary",
			"source": "anchura cigomática media de los machos de la isla de Kodiak, 284 mm (" + SRC_HALL_1984 + ", recogido en " + SRC_PASITSCHNIAK_1993 + "); de 216 mm (Yukón) a 284 mm en las medias de los machos de Norteamérica" },
		"rostrum_width_m": { "value": 0.086, "unit": "m", "quality": "estimate",
			"source": "la proporción de " + SRC_BEAR_SIBERIA + " (83/380) en el cráneo de Kodiak (393 mm): el hocico, mucho más estrecho que la frente y los pómulos. Suposición: las mismas proporciones en los dos" },
		"interorbital_m": { "value": 0.099, "unit": "m", "quality": "estimate",
			"source": "la proporción de " + SRC_BEAR_SIBERIA + " (96/380) en el cráneo de Kodiak: da lo separados que van los ojos" },
		"nasal_m": { "value": 0.109, "unit": "m", "quality": "estimate",
			"source": "la proporción de " + SRC_BEAR_SIBERIA + " (105/380) en el cráneo de Kodiak: el largo del caballete del hocico, de la trufa a la frente" },
		"ear_m": { "value": 0.16, "min": 0.14, "max": 0.16, "unit": "m", "quality": "secondary",
			"source": "largo de la oreja de 15 machos del extremo oriental de Siberia, 16 cm (14 cm las hembras), con 186 cm de largo total (" + SRC_STROGANOV_1969 + ", recogido en " + SRC_PASITSCHNIAK_1993 + ")" },
		"face": { "value": "perfil cóncavo, cabeza maciza, nariz prominente, orejas redondas y poco visibles, ojos pequeños y joroba en los hombros", "quality": "secondary",
			"source": SRC_PASITSCHNIAK_1993 + ": «a distinctive dished facial profile, heavily built body with a prominent shoulder hump» (diagnosis); «a massive head with a prominent nose, rounded inconspicuous ears, small eyes» (caracteres generales)" },
	},
}

## El cráneo de la reconstrucción del velocirraptor (5n): el de GIN 100/25, el de los «dinosaurios luchadores», medido por
## Barsbold y Osmólska (1999, tabla 1), con lo que dicen de su forma, y los labios (Cullen et al. 2023). of("velociraptor")
## lo junta con la ficha. Solo la reconstrucción: la cabeza del de película es ficción (un dibujo de cine).
const VELOCIRAPTOR_SKULL := {
	"skull_m": { "value": 0.23, "unit": "m", "quality": "primary",
		"source": SRC_BARSBOLD_1999 + ", tabla 1: largo máximo del cráneo de GIN 100/25 (el velocirraptor de los «dinosaurios luchadores»), de la apófisis paroccipital a la punta del hocico, 230 mm. El dibujo lo usa sin escalar con el cuerpo de 2,07 m (el largo mayor de la especie): suposición, el cráneo de un adulto grande" },
	"skull_depth_m": { "value": 0.066, "unit": "m", "quality": "primary", "source": SRC_BARSBOLD_1999 + ", tabla 1: alto máximo del cráneo de GIN 100/25, 66 mm" },
	"skull_width_m": { "value": 0.077, "unit": "m", "quality": "primary", "source": SRC_BARSBOLD_1999 + ", tabla 1: anchura por los arcos supratemporales, 77 mm (69 mm por el occipital)" },
	"lacrimal_width_m": { "value": 0.052, "unit": "m", "quality": "primary", "source": SRC_BARSBOLD_1999 + ", tabla 1: anchura por las puntas de los lagrimales, delante de las órbitas, 52 mm" },
	"snout_m": { "value": 0.14, "unit": "m", "quality": "primary",
		"source": SRC_BARSBOLD_1999 + ", tabla 1: largo del hocico, del borde de delante de la órbita a la punta, 140 mm: el 60 % del cráneo («among theropods, such a long snout occurs only in the ornithomimids»)" },
	"snout_depth_m": { "value": 0.045, "unit": "m", "quality": "primary", "source": SRC_BARSBOLD_1999 + ", tabla 1: alto del hocico delante de la órbita, 45 mm" },
	"snout_width_m": { "value": 0.022, "unit": "m", "quality": "primary",
		"source": SRC_BARSBOLD_1999 + ", tabla 1: ancho del hocico delante de los lagrimales, 22 mm: un tercio del ancho del cráneo detrás de las órbitas (p. 193)" },
	"mandible_m": { "value": 0.21, "unit": "m", "quality": "primary", "source": SRC_BARSBOLD_1999 + ", tabla 1: largo de la mandíbula, 210 mm" },
	"mandible_depth_m": { "value": 0.023, "unit": "m", "quality": "primary",
		"source": SRC_BARSBOLD_1999 + ", tabla 1: alto máximo de la mandíbula, 23 mm; el dentario, muy bajo (de un octavo a un séptimo de su largo) y con el borde de abajo convexo (diagnosis)" },
	"snout_profile": { "value": "cóncavo, con la punta algo levantada", "quality": "primary",
		"source": SRC_BARSBOLD_1999 + ", p. 192: desde la mitad de los nasales hacia delante, el hocico se levanta sobre la narina y se hunde detrás de ella (los nasales, hundidos y más hondos justo detrás de la narina); la narina, grande, oval y en una depresión; la órbita, casi redonda y mirando hacia delante y hacia fuera (visión estereoscópica)" },
	"lips": { "value": "labios que tapan los dientes", "quality": "secondary",
		"source": SRC_CULLEN_2023 + ": por el tamaño de los dientes frente al largo del cráneo (terópodos y varanos actuales) y por la histología del esmalte, los terópodos tenían los dientes tapados por tejido extraoral (encía y escamas labiales) con la boca cerrada. La reconstrucción sigue esa hipótesis: de sus 13-15 dientes de arriba y 14-15 de abajo (" + SRC_BARSBOLD_1999 + ", pp. 212-213), con la boca cerrada no se ve ninguno" },
}

## Proporciones de dibujo de las cabezas del oso, del tigre y del velocirraptor (5n; quality «dibujo», no son medidas):
## lo que la piel y el pelo corto añaden al cráneo (skin_k, a lo largo; skin_w, a lo ancho), el radio del ojo (m), lo que
## asoma la oreja sobre el pelo de la cabeza (ear_show, del largo medido; o su tamaño de dibujo, ear_m) y la trufa (nose:
## ancho y alto, fracciones del ancho del hocico).
const HEAD_DRAW := {
	"oso": { "skin_w": 1.08, "eye_r_m": 0.0105, "ear_show": 0.6, "nose": [0.86, 0.56], "quality": "dibujo" },
	"tigre": { "skin_k": 1.08, "skin_w": 1.09, "ear_m": 0.075, "nose": [0.46, 0.32], "quality": "dibujo" },
	"velociraptor": { "skin_k": 1.03, "skin_w": 1.12, "eye_r_m": 0.0145, "quality": "dibujo" },
}

## Proporciones de dibujo de cada rapaz (no son medidas: quality «dibujo»): la cola y la cabeza frente al largo, el ala
## plegada frente a la envergadura (wing_k; ~0,3 en las rapaces: la de la lechuza, 292 mm medidos con 0,9 m de
## envergadura), lo ancho del cuerpo frente al largo y el tipo de cabeza.
const DRAW := {
	"aguila": { "tail_k": 0.4, "head_k": 0.17, "wing_k": 0.29, "girth_k": 0.21, "head": "aguila", "quality": "dibujo" },
	"arpia": { "tail_k": 0.42, "head_k": 0.18, "wing_k": 0.28, "girth_k": 0.22, "head": "arpia", "quality": "dibujo" },
	"halcon": { "tail_k": 0.4, "head_k": 0.16, "wing_k": 0.31, "girth_k": 0.24, "head": "halcon", "quality": "dibujo" },
	"buho": { "tail_k": 0.37, "head_k": 0.22, "wing_k": 0.28, "girth_k": 0.26, "head": "buho", "quality": "dibujo" },
	"lechuza": { "tail_k": 0.33, "head_k": 0.24, "wing_k": 0.32, "girth_k": 0.24, "head": "lechuza", "quality": "dibujo" },
	"buitre": { "tail_k": 0.32, "head_k": 0.12, "wing_k": 0.27, "girth_k": 0.22, "head": "buitre", "quality": "dibujo" },
}


## La entrada de un dibujo: las rapaces, el tigre y el oso, de SPECIES; los velocirraptores, de su ficha (largo, cadera y
## masa, con su fuente). Una copia: quien la lea no cambia los datos.
static func of(art: String) -> Dictionary:
	match art:
		"velociraptor":
			var v := { "kind": "teropodo", "name": "Velocirraptor (reconstrucción)", "latin": "Velociraptor mongoliensis",
				"length_m": Velociraptor.BODY.lengthM, "hip_m": Velociraptor.BODY.hipM, "mass_kg": Velociraptor.MASS,
				"femur_mm": Velociraptor.BODY.femurMm, "tibia_mm": Velociraptor.BODY.tibiaMm,
				"metatarsus_mm": Velociraptor.BODY.metatarsalIIIMm, "feathers": Velociraptor.BODY.feathers }.duplicate(true)
			v.merge(VELOCIRAPTOR_SKULL.duplicate(true))
			v["head_draw"] = (HEAD_DRAW.velociraptor as Dictionary).duplicate()
			return v
		"velociraptor_pelicula":
			return { "kind": "teropodo", "name": "Velocirraptor de cine (ficción, con el tamaño de Deinonychus)", "latin": "Deinonychus antirrhopus",
				"length_m": VelociraptorFilm.BODY.lengthM, "hip_m": VelociraptorFilm.BODY.hipM, "mass_kg": VelociraptorFilm.MASS,
				"model": VelociraptorFilm.BODY.model, "film": true }.duplicate(true)
	if SPECIES.has(art):
		var e: Dictionary = (SPECIES[art] as Dictionary).duplicate(true)
		if DRAW.has(art):
			e["draw"] = (DRAW[art] as Dictionary).duplicate()
		if HEAD_DRAW.has(art):
			e["head_draw"] = (HEAD_DRAW[art] as Dictionary).duplicate(true)
		return e
	return {}


## Una proporción de dibujo de la cabeza (HEAD_DRAW; def si no está). No es una medida.
static func head_draw(art: String, key: String, def: Variant = 0.0) -> Variant:
	var d: Dictionary = HEAD_DRAW.get(art, {})
	return d.get(key, def)


## El valor de una medida (o def si no está).
static func value(art: String, key: String, def := 0.0) -> float:
	var e: Dictionary = of(art)
	var m: Variant = e.get(key)
	if m is Dictionary and (m as Dictionary).get("value") != null:
		return float((m as Dictionary).value)
	return def


## El largo con el que se dibuja el cuerpo (m): en las rapaces y los velocirraptores, el largo total (del pico o del
## morro a la punta de la cola); en el tigre y el oso, el de la cabeza y el cuerpo (sin la cola).
static func draw_length_m(art: String) -> float:
	var e := of(art)
	if e.is_empty():
		return 1.0
	if String(e.kind) == "mamifero":
		return value(art, "head_body_m", 1.9)
	return value(art, "length_m", 1.0)


## El ala plegada (m, del carpo a la punta): la medida si la hay (la lechuza); si no, la proporción de dibujo de la
## envergadura.
static func folded_wing_m(art: String) -> float:
	var w := value(art, "wing_m", -1.0)
	if w > 0.0:
		return w
	var d: Dictionary = DRAW.get(art, { "wing_k": 0.3 })
	return value(art, "span_m", 1.0) * float(d.wing_k)


## Las medidas de un dibujo como filas { key, value, min, max, unit, quality, source } (para «Valores y fuentes» y los
## tests), en el orden de la entrada; sin las de dibujo.
static func rows(art: String) -> Array:
	var out: Array = []
	var e := of(art)
	for k: String in e:
		var m: Variant = e[k]
		if m is Dictionary and (m as Dictionary).has("quality") and (m as Dictionary).has("source"):
			var d: Dictionary = m
			if String(d.quality) == "dibujo" or not (d.get("value") is float or d.get("value") is int):
				continue
			out.append({ "key": k, "value": d.value, "min": d.get("min"), "max": d.get("max"), "unit": String(d.get("unit", "")),
				"quality": String(d.quality), "source": String(d.source) })
	return out
