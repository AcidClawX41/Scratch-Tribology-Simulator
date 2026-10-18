## Tribología biológica · Velociraptor mongoliensis, reconstrucción (catálogo de la 2.0, no existe en el motor 1.x).
##
## Un animal extinguido no se puede medir vivo: cada número sale de una medición publicada y se dice de cuál.
##   - Medido en el fósil: el fémur (circunferencia y longitud), la falange de la garra falciforme del dedo II (el
##     núcleo óseo: largo por la curva exterior, alto y ancho en la base), la tibia y los metatarsos.
##   - Escalado de animales actuales: la masa (la circunferencia del fémur con la recta de los cuadrúpedos actuales,
##     corregida para bípedos), el estuche de queratina de la garra (la proporción medida en 580 garras de aves), el
##     agarre (medido en gavilanes y halcones) y el salto (el trabajo muscular medido en aves).
##   - Ensayo con réplica y modelos: la réplica robótica de una garra de dromeosáurido (Manning 2006), el modelo
##     musculoesquelético de la garra (Bishop 2019) y la carrera con robótica evolutiva (Sellers & Manning 2007).
##   - Sin medición: el radio de la punta de la queratina (no fosiliza) y la superficie de las plumas de los brazos. No se
##     presentan como dato: la punta se ensaya con la del talón de la arpía del banco y se dice que es una pregunta
##     abierta; las plumas no entran en la aerodinámica.
## quality: "primary" (medido en el fósil de la especie), "secondary" (medido en un pariente o recopilado) o «estimate»
## (sin medición en la especie: el caso medido más parecido, con la suposición escrita al lado).
##
## ENTRY lleva todas las claves de una garra de Data.CLAWS, con las mismas unidades, para que Physics.resolve_tool, el
## banco y la interfaz lo traten como una garra; y el bloque `dino` con los datos propios, cada uno con value, source,
## quality y, si tiene incertidumbre, min y max. Especificación completa: docs/fisica/velociraptor.md.
## Unidades: masa kg · longitudes mm (el cuerpo en m) · fuerza N · velocidad m/s · área m² · ángulo ° · E en GPa.
## Uso: const Velociraptor = preload("res://core/lab/velociraptor.gd"); Velociraptor.ENTRY, Velociraptor.grip_n(m).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Data = preload("res://core/lab/data.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
## El salto (w y f) es el de la patada del casuario del coche en marcha (MovingCar.KICK, unidad 4d): un solo sitio para los
## dos (unidad 4i-B2). MovingCar no precarga este módulo (lee los datos del animal de su propia entrada), así que no hay
## precarga cíclica nueva.
const MovingCar = preload("res://core/lab/moving_car.gd")

## Grupo del catálogo 2.0 (la 1.x no lo tiene).
const GROUP := "Dinosaurios (reconstrucción)"
## Gravedad (m/s²): la misma con la que 1 kgf son 9,807 N (Contact.HV_MPA) y la del coche en marcha.
const G := 9.807

# ── Fuentes ──
const SRC_NORELL_1999 := "Norell MA, Makovicky PJ (1999). Important features of the dromaeosaurid skeleton II: information from newly collected specimens of Velociraptor mongoliensis. American Museum Novitates 3282:1-45, tablas 2 y 3. hdl:2246/3025"
const SRC_CAMPIONE_2014 := "Campione NE, Evans DC, Brown CM, Carrano MT (2014). Body mass estimation in non-avian bipeds using a theoretical conversion to quadruped stylopodial proportions. Methods Ecol. Evol. 5:913-923. doi:10.1111/2041-210X.12226"
const SRC_CAMPIONE_2012 := "Campione NE, Evans DC (2012). A universal scaling relationship between body mass and proximal limb bone dimensions in quadrupedal terrestrial tetrapods. BMC Biol. 10:60. doi:10.1186/1741-7007-10-60"
const SRC_CAMPIONE_2020 := "Campione NE, Evans DC (2020). The accuracy and precision of body mass estimation in non-avian dinosaurs. Biol. Rev. 95:1759-1797. doi:10.1111/brv.12638"
const SRC_MASSTIMATE := "Campione NE (2020). MASSTIMATE: Body Mass Estimation Equations for Vertebrates, paquete de R 2.0-1 (CRAN): datos dinosbip (Campione et al. 2014) y dino_comparisons (Campione & Evans 2020), función cQE"
const SRC_TURNER_QUILL := "Turner AH, Makovicky PJ, Norell MA (2007). Feather quill knobs in the dinosaur Velociraptor. Science 317:1721. doi:10.1126/science.1145076"
const SRC_NAPOLI_2021 := "Napoli JG, Ruebenstahl AA, Bhullar B-AS, Turner AH, Norell MA (2021). A new dromaeosaurid (Dinosauria: Coelurosauria) from Khulsan, central Mongolia. American Museum Novitates 3982:1-47. doi:10.1206/3982.1"
const SRC_PAUL_1988 := "Paul GS (1988). Predatory Dinosaurs of the World. Simon & Schuster, p. 370, y Turner AH et al. (2007), Science 317:1378, material suplementario (citados; no hemos podido leer los originales)"
const SRC_PAUL_2024 := "Paul GS (2024). The Princeton Field Guide to Dinosaurs, 3.ª ed. Princeton University Press (citado; no hemos podido leer el original)"
const SRC_PEI_2020 := "Pei R, Pittman M, Goloboff PA, Dececchi TA, Habib MB, Kaye TG, Larsson HCE, Norell MA, Brusatte SL, Xu X (2020). Potential for powered flight neared by most close avialan relatives, but few crossed its thresholds. Curr. Biol. 30:4033-4046. doi:10.1016/j.cub.2020.06.105"
const SRC_MANNING_2006 := "Manning PL, Payne D, Pennicott J, Barrett PM, Ennos RA (2006). Dinosaur killer claws or climbing crampons? Biol. Lett. 2:110-112. doi:10.1098/rsbl.2005.0395"
const SRC_MANNING_2009 := "Manning PL, Margetts L, Johnson MR, Withers PJ, Sellers WI, Falkingham PL, Mummery PM, Barrett PM, Raymont DR (2009). Biomechanics of dromaeosaurid dinosaur claws: application of X-ray microtomography, nanoindentation, and finite element analysis. Anat. Rec. 292:1397-1405. doi:10.1002/ar.20986"
const SRC_FOWLER_2011 := "Fowler DW, Freedman EA, Scannella JB, Kambic RE (2011). The predatory ecology of Deinonychus and the origin of flapping in birds. PLoS ONE 6:e28964. doi:10.1371/journal.pone.0028964"
const SRC_BISHOP_2019 := "Bishop PJ (2019). Testing the function of dromaeosaurid (Dinosauria, Theropoda) «sickle claws» through musculoskeletal modelling and optimization. PeerJ 7:e7577. doi:10.7717/peerj.7577"
const SRC_SELLERS_2007 := "Sellers WI, Manning PL (2007). Estimating dinosaur maximum running speeds using evolutionary robotics. Proc. R. Soc. B 274:2711-2716. doi:10.1098/rspb.2007.0846"
const SRC_HEDRICK_2019 := "Hedrick BP, Cordero SA, Zanno LE, Noto C, Dodson P (2019). Quantifying shape and ecology in avian pedal claws: the relationship between the bony core and keratinous sheath. Ecol. Evol. 9:11545-11556. doi:10.1002/ece3.5507"
const SRC_BIRN_JEFFERY_2012 := "Birn-Jeffery AV, Miller CE, Naish D, Rayfield EJ, Hone DWE (2012). Pedal claw curvature in birds, lizards and Mesozoic dinosaurs. PLoS ONE 7:e50555. doi:10.1371/journal.pone.0050555"
const SRC_HENRY_2005 := "Henry HT, Ellerby DJ, Marsh RL (2005). Performance of guinea fowl Numida meleagris during jumping requires storage and release of elastic energy. J. Exp. Biol. 208:3293-3302. doi:10.1242/jeb.01764"
const SRC_HUTCHINSON_2015 := "Hutchinson JR, Rankin JW, Rubenson J, Rosenbluth KH, Siston RA, Delp SL (2015). Musculoskeletal modelling of an ostrich (Struthio camelus) pelvic limb. PeerJ 3:e1001. doi:10.7717/peerj.1001"
const SRC_PENNYCUICK := "Pennycuick CJ, Obrecht HH, Fuller MR (1988). Empirical estimates of body drag of large waterfowl and raptors. J. Exp. Biol. 135:253-264 (área frontal del cuerpo S_b = 0,00813·m^0,666, en m² con m en kg; Cd de cuerpos congelados 0,25-0,39)"
const SRC_LI_2008 := "Li R, Lockley MG, Makovicky PJ, Matsukawa M, Norell MA, Harris JD, Liu M (2008). Behavioral and faunal implications of Early Cretaceous deinonychosaur trackways from China. Naturwissenschaften 95:185-191. doi:10.1007/s00114-007-0310-7 (rastros de dos dedos: la garra del dedo II no tocaba el suelo)"

# ── Masa (kg) ──
## Escalado del fémur (Campione et al. 2014): la recta de los cuadrúpedos actuales, log10(M[g]) = 2,754·log10(C) − 1,097
## con C la suma de las circunferencias del húmero y el fémur (Campione & Evans 2012, PGLS), y en un bípedo C = C_f·√α²
## con α² ≈ 2 (la corrección de Campione et al. 2014; 2,008 en el fémur de Velociraptor). Error de predicción ±25,03 %.
const CQE_SLOPE := 2.754
const CQE_INTERCEPT := -1.097
const CQE_PPE := 0.2503
## Circunferencia mínima del fémur de Velociraptor (mm) y su α² en los datos de Campione et al. (2014).
const FEMUR_CIRC_MM := 64.0
const FEMUR_ALPHA2 := 2.008
## Reconstrucciones volumétricas recopiladas por Campione & Evans (2020) (kg): tres escaneos y un modelo físico.
const VOLUMETRIC_KG := [9.89, 14.1, 15.0, 18.3]

const MASS := {
	"value": 19.7, "min": 14.1, "max": 24.6, "unit": "kg", "quality": "estimate",
	"source": "Valor: el escalado del fémur, 19,7 kg (circunferencia de 64 mm; " + SRC_CAMPIONE_2014 + "; " + SRC_CAMPIONE_2012 + "; datos de " + SRC_MASSTIMATE + "). Banda: de 14,1 kg (reconstrucción volumétrica por escaneo) a 24,6 kg (el escalado más su error de predicción del 25 %). Las cuatro reconstrucciones volumétricas recopiladas (9,9, 14,1, 15,0 y 18,3 kg; " + SRC_CAMPIONE_2020 + ") caen por debajo: en los dinosaurios pequeños los modelos volumétricos suelen quedarse cortos, dicen los mismos autores. El modelo de carrera usó 20 kg (" + SRC_SELLERS_2007 + "); la réplica de la garra imitaba, según la prensa, un velocirraptor de 20 kg, aunque el artículo calcula su fuerza con 40 kg (" + SRC_MANNING_2006 + ")",
	"note": "el escaneo de 9,9 kg queda muy por debajo de los demás; Paul (2024) da hasta 28 kg para los mayores",
}

# ── Cuerpo (fósil) ──
const BODY := {
	"femurMm": { "value": 238.0, "quality": "primary", "source": SRC_NORELL_1999 + ": fémur izquierdo de IGM 100/986" },
	"tibiaMm": { "value": 255.0, "quality": "primary", "source": SRC_NORELL_1999 + ": tibiotarso de IGM 100/986" },
	"metatarsalIIIMm": { "value": 99.1, "min": 85.6, "max": 99.1, "quality": "primary", "source": SRC_NORELL_1999 + ": metatarso III de IGM 100/986 (99,1 mm, el ejemplar del fémur y la tibia) y de IGM 100/985 (85,6-86,2 mm)" },
	"femurCircMm": { "value": FEMUR_CIRC_MM, "quality": "primary", "source": "circunferencia mínima medida en el fémur (" + SRC_CAMPIONE_2014 + "; " + SRC_MASSTIMATE + ")" },
	"hipM": { "value": 0.5, "quality": "secondary", "source": SRC_PAUL_1988 + ". Cuadra con los huesos medidos: fémur, tibia y metatarso de IGM 100/986 suman 0,59 m, y de pie las articulaciones van flexionadas" },
	"lengthM": { "value": 2.07, "min": 1.5, "max": 2.07, "quality": "secondary", "source": SRC_PAUL_1988 + ": adultos de 1,5 a 2,07 m. Para el dibujo se usa el extremo mayor (solo dibujo); hasta ~2,5 m y 28 kg según " + SRC_PAUL_2024 },
	"stance": { "value": "didáctilo", "quality": "secondary", "source": "la garra del dedo II iba levantada y el pie apoyaba en los dedos III y IV: " + SRC_LI_2008 + "; " + SRC_FOWLER_2011 },
	"feathers": {
		"value": true, "quality": "secondary",
		"source": "papilas de las plumas secundarias en el cúbito de IGM 100/981 (6 conservadas; por su separación, ~14 en total) de un animal de ~1,5 m y ~15 kg: " + SRC_TURNER_QUILL + ". El ejemplar se ha renumerado como IGM 100/3503 y su atribución a Velociraptor está por revisar: " + SRC_NAPOLI_2021 + ". Sus parientes dromeosáuridos con plumas conservadas lo respaldan",
	},
	"wingAreaM2": {
		"value": null, "quality": "estimate",
		"source": "sin medición publicada: las plumas no fosilizaron y el estudio de la carga alar de los paravianos no lo incluye (" + SRC_PEI_2020 + "). Pregunta abierta: no entra en la aerodinámica",
	},
}

# ── Garra falciforme del dedo II ──
## Núcleo óseo medido (mm): largo por la curva exterior, alto y ancho en la base. IGM 100/985 (derecha) es el ejemplar
## con la medida completa; IGM 100/982 da ~66,3 mm (aproximada) y las bases de 18,3 a 23,4 mm de alto.
const CORE_MM := 64.8
## Núcleo / estuche de queratina en las aves actuales (Hedrick et al. 2019: IC 95 % 0,693-0,705; ~0,70 en las rapaces).
const CORE_TO_SHEATH := 0.699
const CORE_TO_SHEATH_LO := 0.693
const CORE_TO_SHEATH_HI := 0.705
## Manning et al. (2006): en 10 rapaces el estuche sobresale del hueso como mucho un 15 % de la longitud total.
const SHEATH_TIP_MAX := 0.15

const SICKLE := {
	"coreMm": { "value": CORE_MM, "min": CORE_MM, "max": 66.3, "quality": "primary", "source": SRC_NORELL_1999 + ", tabla 3: falange ungueal II-3 de IGM 100/985 (64,8 mm por la curva exterior) y de IGM 100/982 (~66,3 mm, aproximada)" },
	"coreHeightMm": { "value": 18.7, "min": 18.3, "max": 23.4, "quality": "primary", "source": SRC_NORELL_1999 + ", tabla 3: alto de la base de la falange ungueal II-3 (IGM 100/982, 100/985, 100/986 y AMNH 6518; 18,7 mm en IGM 100/985, el de la medida del largo)" },
	"coreWidthMm": { "value": 7.1, "min": 6.1, "max": 9.9, "quality": "primary", "source": SRC_NORELL_1999 + ", tabla 3: ancho de la base (la garra es una hoja estrecha: ~2,6 veces más alta que ancha)" },
	"coreToSheath": { "value": CORE_TO_SHEATH, "min": CORE_TO_SHEATH_LO, "max": CORE_TO_SHEATH_HI, "quality": "secondary", "source": SRC_HEDRICK_2019 + ": en 580 garras radiografiadas de 145 especies de aves, el núcleo óseo mide 0,693-0,705 veces el estuche (IC 95 %), sin diferencias entre grupos; ~0,70 en las rapaces. Sin el estuche la garra es más corta y menos curva: " + SRC_BIRN_JEFFERY_2012 },
	"sheathTipMax": { "value": SHEATH_TIP_MAX, "quality": "secondary", "source": SRC_MANNING_2006 + ": en 10 especies de rapaces el estuche sobresale del hueso como mucho un 15 % de la longitud total (discrepa de Hedrick et al. 2019: es la banda baja)" },
	"keratinMm": {
		"value": 92.7, "min": 76.2, "max": 95.7, "quality": "estimate",
		"source": "núcleo óseo medido entre la proporción de las aves: 64,8/0,699 = 92,7 mm. Banda: con el 15 % de Manning et al. (2006), 64,8/0,85 = 76,2 mm; con el núcleo de 66,3 mm y la proporción 0,693, 95,7 mm. Suposición: el estuche de un dromeosáurido crecía como el de las aves, sus parientes vivos",
	},
	"arcDeg": { "value": 160.0, "quality": "estimate", "source": "caso medido más parecido: el arco interior de la garra del dedo II de Deinonychus, 160° (" + SRC_MANNING_2006 + "), en lo alto de las aves trepadoras (129,5-161,6°). No hemos encontrado el de Velociraptor: solo para el dibujo y para la curvatura del motor" },
	"tipRadiusUm": {
		"value": 138.2, "quality": "estimate", "open": true,
		"source": "sin medición: la queratina no fosiliza y no hemos encontrado radios de punta medidos en garras de vertebrados. Se ensaya con la punta del talón de la arpía del banco (0,06 mm², estimación de la 1.x), su análogo funcional: la garra del dedo II de los dromeosáuridos equivale al talón agrandado del dedo II de las accipítridas (" + SRC_FOWLER_2011 + "). Pregunta abierta: el deslizador de afilado enseña cuánto importa",
	},
	"alphaDeg": { "value": 15.0, "quality": "estimate", "open": true, "source": "sin medición: el semiángulo del talón de la arpía del banco (estimación de la 1.x), como el radio de la punta" },
	"hv": { "value": 32.0, "quality": "secondary", "source": "la queratina de las garras del banco (águila 32 HV, casuario 32 HV); " + ClawsV2.SRC_MCKITTRICK },
	"E": { "value": Data.KERATIN_E, "quality": "secondary", "source": ClawsV2.SRC_MCKITTRICK },
}

# ── Función de la garra (ensayos y modelos) ──
const FUNCTION := {
	"replica": {
		"quality": "secondary",
		"source": SRC_MANNING_2006 + ": réplica robótica hidráulica de la garra del dedo II de Deinonychus con un estuche de Kevlar y fibra de carbono. A 2 y 11 m/s (el artículo escribe «m s⁻²») contra un cerdo solo hizo punciones redondas de 30-40 mm, nunca un tajo; contra la piel de cocodrilo rebotó y en una prueba se le partió la punta",
		"punctureMm": { "min": 30.0, "max": 40.0 },
	},
	"fem": {
		"quality": "secondary",
		"source": SRC_MANNING_2009 + ": elementos finitos de una garra de Velociraptor con la queratina del búho real: aguanta bien la carga a lo largo de su eje (trepar, colgarse) y mal la tangencial; la punta pincha y agarra",
	},
	"restraint": {
		"quality": "secondary",
		"source": SRC_FOWLER_2011 + ": modelo de sujeción de las rapaces. La garra del dedo II sujeta a la presa como el talón agrandado de un gavilán, el peso del animal la inmoviliza y los metatarsos cortos y robustos dan más agarre (y menos velocidad)",
	},
	"musculo": {
		"quality": "secondary",
		"source": SRC_BISHOP_2019 + ": en un Deinonychus de 490 N, los músculos del dedo dan como mucho 18,9 N en la punta ósea de la garra (a 76 mm de la articulación): menos del 5 % del peso. Con el doble de fuerza muscular, ×1,901. Apoya la función de agarre; la fuerza grande la pone el peso del animal",
	},
}

# ── Fuerzas (N) ──
## Réplica de Manning et al. (2006): 981 N = 2,5 × peso de un dromeosáurido de 40 kg (con g = 9,81).
const REPLICA_BW := 2.5
const REPLICA_N := 981.0
const REPLICA_MASS_KG := 40.0
## Modelo de Bishop (2019): 18,9 N como mucho en la punta de la garra con 490 N de peso; ×1,901 con el doble de músculo.
const BISHOP_TIP_N := 18.9
const BISHOP_WEIGHT_N := 490.0
const BISHOP_STRONG := 1.901

# ── Carrera y salto (m/s) ──
## Sellers & Manning (2007): 10,8 m/s con un modelo de 20 kg. Validación del mismo modelo en especies actuales
## (predicho frente a medido): emú 13,3/14, avestruz 15,4/17 y persona 7,9/10: subestima entre un 5 y un 21 %.
const RUN_MS := 10.8
const RUN_MODEL_KG := 20.0
const RUN_VALIDATION := [[13.3, 14.0], [15.4, 17.0], [7.9, 10.0]]
## Salto: v = √(4·w·f) (trabajo de los músculos de las dos patas = energía cinética del despegue), con w = 45 J por kg de
## músculo, medido en el salto máximo de la gallina de Guinea (hasta 67,5 J/kg, el máximo esperable del músculo
## esquelético, dos tercios más; Henry et al. 2005), y f = 8,498/65,3 = 13,0 % de la masa en los músculos de cada pata,
## disecados en un avestruz (Hutchinson et al. 2015, tabla 2). Son los w y f de la patada del casuario de la unidad 4d
## (MovingCar.KICK): no se copian.
const LEAP_WORK_J_KG: float = MovingCar.KICK.work_j_per_kg.value
const LEAP_WORK_MAX_J_KG: float = MovingCar.KICK.work_j_per_kg.max
const LEAP_MUSCLE_FRACTION: float = MovingCar.KICK.muscle_fraction.value

const LOCOMOTION := {
	"runMs": {
		"value": RUN_MS, "min": RUN_MS, "max": 13.67, "quality": "estimate",
		"source": SRC_SELLERS_2007 + ": 10,8 m/s (39 km/h) con un modelo musculoesquelético de 20 kg. Banda alta: el mismo modelo subestima a la persona un 21 % (7,9 m/s frente a 10), al avestruz un 9 % y al emú un 5 %",
	},
	"leapMs": {
		"value": 4.84, "min": 4.84, "max": 5.93, "quality": "estimate",
		"source": "v = √(4·w·f): w = 45 J/kg de músculo (" + SRC_HENRY_2005 + "; hasta 67,5 J/kg, la banda alta) y f = 13,0 % de la masa en cada pata (" + SRC_HUTCHINSON_2015 + ", tabla 2). Suposición: el músculo de un dromeosáurido rinde como el de las aves; el salto no depende de la masa (Hill 1950). Con el 15 % por pata que usan Sellers & Manning (2007), 5,20 m/s: dentro de la banda",
	},
}

# ── Golpe y agarre para el banco ──
const FORCES := {
	"grip": {
		"value": 381.5, "min": 193.3, "max": 1129.9, "unit": "N", "quality": "estimate",
		"source": "Agarre de un pie de 19,7 kg escalado desde el gavilán de Cooper hembra (9,77 N, 450 g) con la pendiente de los accipítridos, 0,97 (banda: pendiente 0,79 abajo; ×2,96 arriba, la dispersión entre técnicas): " + ClawsV2.SRC_SUSTAITA + ". Suposición: el pie de un dromeosáurido agarraba como el de un gavilán (" + SRC_FOWLER_2011 + "). Es una extrapolación de ×44 en masa sobre lo medido",
	},
	"replica": {
		"value": 483.0, "unit": "N", "quality": "secondary",
		"source": "la carga de la réplica, 2,5 veces el peso (981 N con 40 kg), con la masa de Velociraptor: 2,5 × 19,7 × 9,807 = 483 N (" + SRC_MANNING_2006 + ")",
	},
	"clawMuscle": {
		"value": 10.2, "min": 10.2, "max": 19.3, "unit": "N", "quality": "estimate",
		"source": "la garra sola, movida por sus músculos: 18,9 N con 490 N de peso (" + SRC_BISHOP_2019 + "), escalados a 19,7 kg con la semejanza geométrica (fuerza muscular ∝ m^(2/3), brazos ∝ m^(1/3)); banda alta con el doble de músculo (×1,901). Con el estuche, aún menos: la punta queda más lejos de la articulación",
	},
}

# ── Coche en marcha (para la fase B; aerodinámica de ave sin alas) ──
## Área frontal del cuerpo: la de Pennycuick (1988) para aves, S_b = 0,00813·m^0,666 (m², m en kg), extrapolada a ~20 kg
## desde las aves grandes medidas; es un cuerpo emplumado, como el de ellas. Sin superficie alar publicada (BODY.wingAreaM2):
## solo la postura agazapada. Contacto: 4 garras (dedos III y IV de los dos pies; la del dedo II va levantada).
const PENNYCUICK_COEF := 0.00813
const PENNYCUICK_EXP := 0.666
const CAR := {
	"kind": "teropodo", "species": "Velociraptor mongoliensis (reconstrucción)",
	"frontalCoef": PENNYCUICK_COEF, "frontalExp": PENNYCUICK_EXP, "frontalQuality": "estimate",
	"frontalSource": "caso medido más parecido: " + SRC_PENNYCUICK + "; suposición: un cuerpo emplumado de terópodo frena como el de un ave grande",
	"wingM2": null,
	"contact": 4, "contactQuality": "secondary", "contactSource": SRC_LI_2008,
	"contactMm": { "value": 30.0, "quality": "estimate", "source": "radio del apoyo del pie, del orden de las dos primeras falanges del dedo III (23,6-26,6 mm y 24,7-27,4 mm, " + SRC_NORELL_1999 + ", tabla 3); como el del águila del coche en marcha" },
	"grasp": { "quality": "secondary", "source": SRC_FOWLER_2011 + ": el pie se cierra en un puño sin llegar a la flexión máxima, con el dedo I frente al IV" },
}

## La entrada del catálogo 2.0: todas las claves de una garra de Data.CLAWS (mismas unidades), más `dino`.
##   - hv, E: la queratina de las garras del banco (SICKLE.hv, SICKLE.E).
##   - area, alpha: la punta del talón de la arpía (sin medición: SICKLE.tipRadiusUm, pregunta abierta).
##   - reach: la garra de queratina por la curva exterior (SICKLE.keratinMm); curve: 0,9, la de las garras más curvas del
##     banco (arpía), por el arco de 160° (SICKLE.arcDeg): el `curve` de la 1.x es una estimación de su motor.
##   - mass: MASS; force: FORCES.grip, el agarre de un pie, el mismo sentido que en las rapaces de claws_v2.gd.
##   - strike: salta y cae con los dos pies por delante (el modelo de sujeción): v, el despegue del salto
##     (LOCOMOTION.leapMs); m, la mitad de la masa, la parte del impulso que lleva cada pie (estimación).
const ENTRY := {
	"id": "velociraptor", "group": GROUP, "name": "Velocirraptor", "title": "Garra falciforme de velocirraptor",
	"hv": 32.0, "mohs": 3.0, "E": Data.KERATIN_E, "area": 0.06, "alpha": 15.0, "reach": 92.7, "curve": 0.9,
	"mass": 19.7, "force": 381.5, "strike": { "v": 4.84, "m": 9.85 }, "col": "#4A3F35",
	"desc": "Reconstrucción de Velociraptor mongoliensis, del Cretácico de Mongolia: del tamaño de un pavo grande (~20 kg), con plumas y una garra en hoz de ~9 cm en el dedo II de cada pie. No rajaba como en las películas: una réplica robótica solo hizo punciones de 3-4 cm (Manning 2006). Pinchaba y sujetaba a la presa con su peso, como un gavilán gigante (Fowler 2011). Masa por el fémur; la garra, del hueso fósil más el estuche de las aves; la punta no fosiliza: se ensaya con la de la arpía (pregunta abierta).",
	"source": SRC_NORELL_1999 + "; " + SRC_CAMPIONE_2014 + "; " + SRC_HEDRICK_2019 + "; " + SRC_MANNING_2006 + "; " + SRC_FOWLER_2011 + "; " + SRC_SELLERS_2007,
	"quality": "estimate",
	"dino": {
		"species": "Velociraptor mongoliensis", "family": "Dromaeosauridae", "reconstruction": true,
		"mass": MASS, "body": BODY, "sickle": SICKLE, "function": FUNCTION, "forces": FORCES, "locomotion": LOCOMOTION,
		"car": CAR,
		"colors": { "body": "#8A6F4E", "feathers": "#5B4A3A", "claw": "#4A3F35", "quality": "dibujo" },
	},
}


# ════════ Masa ════════

## Masa (kg) por el escalado del fémur de Campione et al. (2014): log10(M[g]) = 2,754·log10(C_f·√α²) − 1,097.
static func cqe_mass_kg(femur_circ_mm: float, alpha2: float = 2.0) -> float:
	return V8.js_pow(10.0, CQE_SLOPE * Js.log10(femur_circ_mm * sqrt(alpha2)) + CQE_INTERCEPT) / 1000.0


## Masa con su banda por método: { cqeKg, cqeMinKg, cqeMaxKg (el error de predicción), volumetricKg (las cuatro
## reconstrucciones), value, min, max (MASS) }.
static func mass_report() -> Dictionary:
	var cqe := cqe_mass_kg(FEMUR_CIRC_MM, FEMUR_ALPHA2)
	return {
		"cqeKg": cqe, "cqeMinKg": cqe * (1.0 - CQE_PPE), "cqeMaxKg": cqe * (1.0 + CQE_PPE),
		"volumetricKg": VOLUMETRIC_KG.duplicate(), "value": MASS.value, "min": MASS.min, "max": MASS.max,
	}


# ════════ Fuerzas ════════

## Agarre (N) de un pie de masa m (kg), escalado de los gavilanes medidos (ClawsV2.accipiter_grip). which: «value» (pendiente
## 0,97), «min» (0,79) o «max» (×2,96, la dispersión entre técnicas).
static func grip_n(mass_kg: float, which: String = "value") -> float:
	match which:
		"min":
			return ClawsV2.accipiter_grip(mass_kg, ClawsV2.ACCIPITER_SLOPE_LO)
		"max":
			return ClawsV2.accipiter_grip(mass_kg) * ClawsV2.TECHNIQUE_FACTOR
	return ClawsV2.accipiter_grip(mass_kg)


## La carga de la réplica de Manning et al. (2006), 2,5 pesos, con la masa m (kg).
static func replica_load_n(mass_kg: float) -> float:
	return REPLICA_BW * mass_kg * G


## Fuerza (N) en la punta de la garra con sus propios músculos (Bishop 2019), escalada a la masa m (kg) con la semejanza
## geométrica: ∝ m^(2/3). strong: con el doble de fuerza muscular (×1,901).
static func claw_muscle_n(mass_kg: float, strong: bool = false) -> float:
	var ref_kg := BISHOP_WEIGHT_N / G
	var f := BISHOP_TIP_N * V8.js_pow(mass_kg / ref_kg, 2.0 / 3.0)
	return f * BISHOP_STRONG if strong else f


# ════════ Carrera y salto ════════

## Velocidad máxima de carrera (m/s): la del modelo (Sellers & Manning 2007) o, con hi, la corregida con la mayor
## subestimación del mismo modelo en las especies actuales (la persona: 7,9 frente a 10 m/s).
static func run_speed_ms(hi: bool = false) -> float:
	if not hi:
		return RUN_MS
	var worst := 1.0
	for pair: Array in RUN_VALIDATION:
		worst = minf(worst, float(pair[0]) / float(pair[1]))
	return RUN_MS / worst


## Velocidad de despegue del salto (m/s): v = √(4·w·f). hi: con el trabajo muscular máximo esperable (banda alta).
static func leap_speed_ms(hi: bool = false) -> float:
	return MovingCar.kick_leap_ms(hi)


## Altura (m) que sube el centro de masas en un salto vertical con esa velocidad: v²/(2g).
static func leap_height_m(hi: bool = false) -> float:
	var v := leap_speed_ms(hi)
	return v * v / (2.0 * G)


# ════════ Garra ════════

## Largo de la garra de queratina (mm) con un núcleo óseo core_mm y la proporción núcleo/estuche ratio.
static func keratin_length_mm(core_mm: float = CORE_MM, ratio: float = CORE_TO_SHEATH) -> float:
	return core_mm / ratio


## La banda de la garra de queratina: { value, min (Manning 2006: el estuche sobresale ≤ 15 %), max (núcleo mayor y la
## proporción más baja de Hedrick 2019) }.
static func keratin_band_mm() -> Dictionary:
	return {
		"value": keratin_length_mm(), "min": keratin_length_mm(CORE_MM, 1.0 - SHEATH_TIP_MAX),
		"max": keratin_length_mm(float(SICKLE.coreMm.max), CORE_TO_SHEATH_LO),
	}


## Radio (µm) de la punta de la entrada del catálogo: √(área/π).
static func tip_radius_um(entry: Dictionary = ENTRY) -> float:
	return sqrt(float(entry.area) / PI) * 1000.0


# ════════ Aerodinámica (fase B) ════════

## Área frontal del cuerpo (m²) de masa m (kg): la de las aves de Pennycuick (1988).
static func frontal_area_m2(mass_kg: float) -> float:
	return PENNYCUICK_COEF * V8.js_pow(mass_kg, PENNYCUICK_EXP)


# ════════ Catálogo ════════

## ¿Es un dinosaurio reconstruido? (una garra con el bloque `dino`).
static func is_dino(tool: Variant) -> bool:
	return tool is Dictionary and tool.get("dino") != null


## Los dinosaurios del catálogo 2.0 (por ahora, uno).
static func entries() -> Array:
	return [ENTRY]


## Primera entrada con ese id, o null.
static func find_by_id(id: Variant) -> Variant:
	for e: Dictionary in entries():
		if e.id == id:
			return e
	return null
