## Tribología biológica · cetrería y cuidado de garras: datos con fuente (modelo 2.0, unidad 5a). Sin estado.
##
## Qué hay aquí (la física está en claw_care.gd; la guía completa, en docs/fisica/cetreria.md):
##   - ANIMALS: la rapaz (con las seis del banco), el tigre, el oso pardo y el velocirraptor (reconstrucción, anestesiado):
##     dónde acaba la carne viva, ritmo de crecimiento, sujeción o anestesia, capas del estuche y si la carne viva se ve.
##   - KERATIN: la queratina según su humedad (seca, natural, húmeda y empapada): módulo, resistencia, deformación de
##     rotura y trabajo de rotura a lo largo y de través.
##   - TOOLS: limas de acero (DIN 8349), limas de diamante (DMT), lijas (FEPA P), torno de uñas de mascota (Dremel),
##     amoladora de uñas con protector y cuatro velocidades (Dremel), cortaúñas, hemostáticos, antiséptico, crema y metacrilato.
##   - Umbrales del calor (dolor y lesión) y de la hemostasia, y la rúbrica (pedagógica) del informe.
## Cada dato es { value, source, quality } (y min/max si tiene banda); quality: "primary" (medido en el caso), "secondary"
## (medido en un caso cercano o recopilado), "estimate" (sin medición: el caso medido más parecido y la suposición
## escrita) o "dibujo" (solo para pintar). Lo que no está medido se dice.
## Unidades: longitudes mm (radios de punta en µm) · fuerza N · dureza HV · módulo GPa · resistencia MPa · tenacidad
## kJ/m² (= N/mm) · temperatura °C · tiempo s (crecimiento en mm/día) · giro rpm.
## Uso: const CareData = preload("res://core/lab/claw_care_data.gd").
extends RefCounted

const Data = preload("res://core/lab/data.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")
const Insects = preload("res://core/lab/insects.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")

# ════════ Fuentes ════════
const SRC_SAMOUR := "Samour J (2006). Management of raptors. En Harrison GJ, Lightfoot TL (eds.), Clinical Avian Medicine, vol. II, cap. 40, pp. 915-956. Spix Publishing"
const SRC_ARENT := "Arent L, Pollock C (2012, revisado en 2023). Raptor anatomy fundamentals. LafeberVet"
const SRC_MSD := "MSD Veterinary Manual, «Management of pet birds» (herramientas y hemostáticos para uñas y pico)"
const SRC_SAKAS := "Sakas PS, «Grooming in pet birds», Niles Animal Hospital & Bird Medical Center (las aves tienen una carne viva muy larga; en las uñas claras se ve rosada)"
const SRC_HEDRICK := Velociraptor.SRC_HEDRICK_2019 + " (en 580 garras radiografiadas de 145 especies, el núcleo óseo mide 0,693-0,705 veces el estuche; ~0,70 en las rapaces)"
const SRC_MANNING := Velociraptor.SRC_MANNING_2006 + " (en 10 rapaces, el estuche sobresale del hueso como mucho un 15 % de la longitud total)"
const SRC_HOMBERGER := "Homberger DG, Ham K, Ogunbakin T et al. (2009). The structure of the cornified claw sheath in the domesticated cat (Felis catus): implications for the claw-shedding mechanism and the evolution of cornified digital end organs. J. Anat. 214:620-643. doi:10.1111/j.1469-7580.2009.01068.x"
const SRC_CONTRERAS := "Contreras ET, Bruner K, Hegwer C, Simpson A (2025). Claw growth rates in a subset of adult, indoor, domestic cats (Felis catus). Vet. Dermatol. 36:362-367. doi:10.1111/vde.13335 (manos: mediana de 0,13 mm/día, 0,01-0,27; patas: 0,08 mm/día; 17 gatos)"
const SRC_ETHIER := "Ethier DM, Kyle CJ, Kyser TK, Nocera JJ (2010). Can. J. Zool. 88:1043-1051, doi:10.1139/z10-073, citado por Fokidis HB, Brock T, Newman C, Macdonald DW, Buesching CD (2023). Conserv. Physiol. 11:coad024, doi:10.1093/conphys/coad024 (tejón americano: 0,26-0,28 mm/día, garra renovada en 130-140 días)"
const SRC_BEARHOP := "Bearhop S et al. (2003). Funct. Ecol. 17:270-275, citado por Mazerolle DF, Hobson KA (2005). Condor 107:280-288, doi:10.1093/condor/107.2.280 («claws of five European passerines grew at a rate of 0.04 mm per day»)"
const SRC_TAYLOR := "Taylor AM, Bonser RHC, Farrent JW (2004). The influence of hydration on the tensile and compressive properties of avian keratinous tissues. J. Mater. Sci. 39:939-942, doi:10.1023/B:JMSC.0000012925.92504.08, recogido en " + ClawsV2.SRC_MCKITTRICK + ", tabla II (garra de avestruz: 0 % HR, 2,7 GPa, 90 MPa, 5,7 %; 50 %, 2,0 GPa, 69 MPa, 6,7 %; 100 %, 0,1 GPa, 14 MPa, 50,5 %)"
const SRC_FARRAN := "Farran L, Ennos AR, Eichhorn SJ (2008). The effect of humidity on the fracture properties of human fingernails. J. Exp. Biol. 211:3677-3681. doi:10.1242/jeb.023218 (con cortaúñas: 11-22 kJ/m², máximo a 55 % HR; ahí, hacia la raíz el doble que de lado, y 1,5 veces de media; empapada, 8,35 ± 1,95 kJ/m² hacia la raíz; a 0 % HR «brittle fracture occurred leaving a powder»; «the nail layers tend to peel apart at their boundaries, particularly when wet»)"
const SRC_FARREN := "Farren L, Shayler S, Ennos AR (2004). The fracture properties and mechanical design of human fingernails. J. Exp. Biol. 207:735-741. doi:10.1242/jeb.00814 (las grietas se desvían de través, paralelas al borde libre; la capa intermedia pide un cuarto de energía de través que a lo largo)"
const SRC_AAD := "American Academy of Dermatology, «How to trim your nails»: «Always file the nail in the same direction, as filing back and forth can weaken your nails»; remojar las uñas en agua tibia unos minutos antes de cortarlas las ablanda"
const SRC_DIAS := "Dias DT, Steimacher A, Bento AC, Neto AM, Baesso ML (2007). Thermal characterization in vitro of human nail: photoacoustic study of the aging process. Photochem. Photobiol. 83:1144-1148. doi:10.1111/j.1751-1097.2007.00074.x (difusividad térmica de la uña: mínimo ~10·10⁻⁴ cm²/s hacia los 20 años; ~18·10⁻⁴ cm²/s pasados los 50)"
const SRC_PICARD := "Picard K, Thomas DW, Festa-Bianchet M, Belleville F, Laneville A (1999). Differences in the thermal conductance of tropical and temperate bovid horns. Écoscience 6:148-158, doi:10.1080/11956860.1999.11682515 (calor específico del estuche de queratina del cuerno: 1,53 ± 0,07 J/(g·°C), según el resumen; no hemos podido leer el artículo)"
const SRC_DUBIN := "Dubin AE, Patapoutian A (2010). Nociceptors: the sensors of the pain pathway. J. Clin. Invest. 120:3760-3772. doi:10.1172/JCI42843 (umbral de la percepción del dolor por calor, ~40-45 °C)"
const SRC_PAN := "Pan LH et al. (2024). The normative values of pain thresholds in healthy Taiwanese. Brain Behav. 14:e3485. doi:10.1002/brb3.3485 (umbral del dolor por calor desde 32 °C a 1 °C/s: 40,8 ± 3,7 °C en el antebrazo y 42,6 ± 3,4 °C en la frente; 130 adultos)"
const SRC_JORDT := "Jordt SE, Julius D (2002). Molecular basis for species-specific sensitivity to «hot» chili peppers. Cell 108:421-430. doi:10.1016/S0092-8674(02)00637-2 (el receptor TRPV1 del pollo se activa con el calor, como el de los mamíferos: las aves detectan el calor nocivo)"
const SRC_MORITZ := "Moritz AR, Henriques FC (1947). Studies of thermal injury II. Am. J. Pathol. 23:695-720, recogido en Milner SM (2024). Mechanism and management of scald burns. Eplasty 24:QA7 (44 °C 6 h; 45 °C 3 h; 50 °C 5 min; 55 °C 30 s; 60 °C 5 s; 65 °C 2 s; 70 °C 1 s)"
const SRC_DREMEL_7300 := "Dremel, ficha técnica del 7300-PT 4.8V Pet Grooming Kit: dos velocidades, 6500 y 13 000 rpm (así en la tabla; el texto dice 15 000), tambor de lija de grano 60"
const SRC_DREMEL_7760 := "Dremel, ficha del 7760-PGK PawControl (amoladora de uñas de mascota inalámbrica, 4 V y 2 Ah de ion-litio): interruptor deslizante con 4 velocidades de 8000 a 25 000 rpm; protector de uñas con guía de 45° para el ángulo y para recoger el polvo; banda de lija de 1/2″ (12,7 mm) de grano 60 (407 y 408); 7,5 × 1,5 × 1,75 in"
const SRC_DREMEL_LITE := "Dremel Lite 7760, manual de instrucciones original (la misma herramienta que la del 7760-PGK): las cuatro posiciones del interruptor, 8000, 14 000, 21 000 y 25 000 rpm; arranca a 8000 rpm"
const SRC_KAKKAR := "Kakkar P, Madhan B, Shanmugam G (2014). Extraction and characterization of keratin from bovine hoof: a potential material for biomedical applications. SpringerPlus 3:596 (la queratina de la pezuña se desnaturaliza a ~215 °C, medido por calorimetría)"
const SRC_WORTMANN := "Wortmann FJ, Wortmann G, Marsh J, Meinert K (2012). Thermal denaturation and structural changes of α-helical proteins in keratins. J. Struct. Biol. 177:553-560 (picos de desnaturalización de las queratinas α entre 230 y 255 °C)"
const SRC_DREMEL_GUIDE := "Dremel, «How to avoid failures while cutting your dog's nails»: «grinding creates friction and friction creates heat… limit the grinding action to a few seconds at a time, with short breaks in between»; la herramienta a 45° sigue la forma y la curva natural de la uña; si sangra, un pellizco de polvo hemostático y presión moderada hasta que pare"
const SRC_DIN8349 := "DIN 8349, en el catálogo de limas de PFERD: dientes por cm según el largo y el picado (150 mm: 13 con el picado 1, bastardo; 18 con el 2; 22 con el 3); PFERD recomienda para el cuerno las limas y escofinas de madera y las de casco"
const SRC_FWT := "FWT GmbH, limas de taller de acero al cromo de 60-62 HRC; ~700 HV por la tabla A.1 de DIN EN ISO 18265:2014 (la misma conversión que core/taller/radial.gd)"
const SRC_FILE_TEST := "HolzWerken (18-9-2024), «Stahlhärte bestimmen»: una lima solo deja marca en lo que es más blando que ella (juego de limas de prueba de 40 a 65 HRC); es el criterio del banco: raya lo más duro (Contact.hardness_efficiency)"
const SRC_NICHOLSON := "Crescent Nicholson, «Guide to files and filing»: la lima corta al empujar; en el retroceso se levanta de la pieza (arrastrarla hacia atrás desafila los dientes); el picado sencillo deja mejor acabado y el doble arranca más"
const SRC_DMT := "DMT Diamond Sharpeners, FAQ: extragruesa 60 µm (malla 220), gruesa 45 µm (325), fina 25 µm (600), extrafina 9 µm (1200); en seco o con agua"
const SRC_KLINGSPOR := "Klingspor, «Grit grading systems»: tamaño medio del grano FEPA P (P60 ≈ 0,0101 in, P180 ≈ 0,00304 in, P240 ≈ 0,00228 in)"
const SRC_KALACSKA := "Kalácska Á, Székely L, Keresztes RZ, Gábora A, Mankovits T, De Baets P (2021). Abrasive sensitivity of martensitic and a multi-phase steels under different abrasive conditions. Materials 14:1343. doi:10.3390/ma14061343 (el desgaste crece proporcionalmente al tamaño del abrasivo hasta el tamaño crítico, ~82 µm en su acero)"
const SRC_VCA := "VCA Animal Hospitals (Weir M, Williams K, Buzhardt L), «First aid for broken nails in dogs»: si la uña no deja de sangrar en 5-10 minutos, lápiz hemostático, nitrato de plata o polvo cauterizante"
const SRC_COAKLEY := "Coakley S et al. (2020). J. Clin. Aesthet. Dermatol. (PMC7819594): el nitrato de plata duele más que el subsulfato férrico (mediana 6 frente a 1,5 en una escala de dolor)"
const SRC_LOZIER := "Lozier S, Pope E, Berg J (1992). Effects of four preparations of 0.05% chlorhexidine diacetate on wound healing in dogs. Vet. Surg. 21:107-112 (clorhexidina al 0,05 %: 100 % de bacterias muertas sin retrasar la cicatrización)"
const SRC_CATTALES := "Cat Tales Wildlife Center (9-11-2024), «When a tiger needs a manicure»: un tigre con una garra clavada en la almohadilla, con sedación; tenazas de herrador y un torno sin cable; la almohadilla curó en unos días"
const SRC_ANIMALS_ASIA := "Animals Asia, «The first 100 days at sanctuary»: en la revisión con anestesia se recortan las garras crecidas y clavadas de los osos rescatados"
const SRC_BIAZA := "BIAZA (2019). Animal training guidelines: el entrenamiento con refuerzo positivo permite procedimientos que antes pedían sujeción o sedación (un oso polar presenta la pata para una radiografía)"
const SRC_MALKIN := "Malkin S, Guo C (2007). Thermal analysis of grinding. CIRP Annals 56:760-782 (con muelas convencionales entra en la pieza el 60-85 % del calor), el mismo dato de core/taller/sharpening_heat.gd"
const SRC_BIRO := "Relación de fuerzas del amolado Ft/Fn = 0,325 (0,25-0,40), la de core/taller/grinding.gd (FORCE_RATIO)"
const SRC_INCROPERA := "Incropera FP, DeWitt DP, Bergman TL, Lavine AS (2007). Fundamentals of Heat and Mass Transfer, 6.ª ed., tabla 1.1 (el mismo dato del aire en calma de core/taller/edge_thermal.gd)"
const SRC_C100S := "acero de herramientas C100S (1.1274): 49 W/(m·K) a 20 °C (HS-Folien, ficha técnica; el dato de core/taller/sharpening_heat.gd)"
const SRC_CARSLAW := "Carslaw HS, Jaeger JC (1959). Conduction of Heat in Solids, 2.ª ed., Oxford (fuente circular fija sobre un sólido semiinfinito, como en core/taller/sharpening_heat.gd)"
const SRC_ENGINE_KERATIN := "la queratina de la garra del banco: dureza y módulo de su ficha (Data.CLAWS; " + ClawsV2.SRC_MCKITTRICK + ")"
const SRC_ENGINE_GEOMETRY := "la garra del banco: área y semiángulo de la punta, alcance y base (0,15 × alcance) del motor (Data.CLAWS, Physics.MODEL.clawBase; estimaciones de la 1.x)"
const SRC_RUBRIC := "Rúbrica pedagógica del simulador (docs/fisica/cetreria.md, §6.8): cuánto pesa cada fallo y dónde se ponen los márgenes; lo que decide si hay fallo sale del modelo físico y de los datos con fuente"

# ════════ La queratina según su humedad ════════
## Estados de humedad de la garra de queratina. rh: humedad relativa de equilibrio (%). e_gpa, sigma_mpa, strain: módulo,
## resistencia y deformación de rotura de la garra de avestruz (Taylor et al. 2004): medidos a 0, 50 y 100 % HR; a 33 %
## HR, interpolados. j_long y j_lat: trabajo de rotura de la uña humana con cortaúñas hacia la raíz (una grieta a lo
## largo, la que raja) y de lado (Farran et al. 2008). hardness: la dureza del banco (medida a ~50 % HR) escalada con la
## resistencia (Tabor: H ∝ tensión de flujo); mojada, 14/69 = 0,203, el ×0,2 del banco (docs/FISICA.md §10).
## ductile: la queratina se deforma antes de romperse (la deformación de rotura pasa del 20 %: seca y natural, 6-7 %;
## húmeda, 50,5 %): la punta se aplasta en vez de mellarse. El 20 % es una frontera elegida entre los valores medidos.
const HUMIDITY_IDS := ["seca", "natural", "humeda", "empapada"]
const KERATIN := {
	"seca": {
		"name": "Seca", "rh": 33.0, "e_gpa": 2.24, "sigma_mpa": 76.1, "strain": 0.0636, "j_long": 11.0, "j_lat": 7.33,
		"ductile": false,
		"quality": "estimate",
		"source": "E, resistencia y deformación interpoladas entre 0 y 50 % HR de " + SRC_TAYLOR + ". Trabajo de rotura: el mínimo del intervalo medido (11 kJ/m², al bajar de 55 % HR) de " + SRC_FARRAN + "; de lado, 11/1,5 (la relación media). A 0 % HR la uña se rompe en polvo: más frágil todavía, sin cifra",
	},
	"natural": {
		"name": "Natural", "rh": 55.0, "e_gpa": 2.0, "sigma_mpa": 69.0, "strain": 0.067, "j_long": 22.0, "j_lat": 11.0,
		"ductile": false,
		"quality": "secondary",
		"source": "E, resistencia y deformación de la garra de avestruz a 50 % HR (" + SRC_TAYLOR + "). Trabajo de rotura: el máximo, a 55 % HR, 22 kJ/m² hacia la raíz y la mitad de lado (" + SRC_FARRAN + ")",
	},
	"humeda": {
		"name": "Húmeda", "rh": 100.0, "e_gpa": 0.1, "sigma_mpa": 14.0, "strain": 0.505, "j_long": 13.0, "j_lat": 8.67,
		"ductile": true,
		"quality": "secondary",
		"source": "E, resistencia y deformación de la garra de avestruz a 100 % HR (" + SRC_TAYLOR + "). Trabajo de rotura hacia la raíz a 100 % HR, ~13 kJ/m² (leído de la figura 3B de " + SRC_FARRAN + "); de lado, 13/1,5",
	},
	"empapada": {
		"name": "Empapada", "rh": 100.0, "e_gpa": 0.1, "sigma_mpa": 14.0, "strain": 0.505, "j_long": 8.35, "j_lat": 5.57,
		"ductile": true,
		"quality": "secondary",
		"source": "Sumergida en agua: 8,35 ± 1,95 kJ/m² hacia la raíz (" + SRC_FARRAN + "); de lado, 8,35/1,5 (estimación). E, resistencia y deformación: las de 100 % HR (" + SRC_TAYLOR + ")",
	},
}
## Resistencia de referencia de la dureza del banco (MPa): la garra de avestruz a 50 % HR (Taylor et al. 2004).
const SIGMA_REF_MPA := 69.0
## Frontera entre frágil y dúctil (deformación de rotura). Elección entre los valores medidos (6,7 % y 50,5 %).
const DUCTILE_STRAIN := 0.2
## Densidad de la queratina (kg/m³): la del banco (claw_mass.gd, «none»: Mason 1963).
const KERATIN_DENSITY: float = ClawMass.DENSITY["none"]["value"]
## Tenacidad entre capas: una cuarta parte de la de lado (kJ/m²). Sin medición entre capas; caso medido más parecido: la
## capa intermedia de la uña, que de través pide un cuarto de la energía que a lo largo (Farren et al. 2004).
const INTERLAMINAR := {
	"value": 0.25, "quality": "estimate",
	"source": "sin medición de la tenacidad entre las láminas de una garra; se toma la relación medida en la capa intermedia de la uña (" + SRC_FARREN + ") y la observación de que las capas se separan por sus bordes, sobre todo mojadas (" + SRC_FARRAN + ")",
}
## Espesor de un paquete de láminas que se levanta al deshojarse (mm). Sin medición: una quinta parte de una uña de 0,5 mm.
const PEEL_DEPTH := { "value": 0.1, "quality": "estimate", "source": "sin medición en garras; del orden de las capas de la uña humana (tres capas en ~0,5 mm; Farren et al. 2004)" }

# ════════ Calor ════════
const THERMAL := {
	"diffusivity_m2_s": {
		"value": 1.0e-7, "min": 0.89e-7, "max": 1.8e-7, "quality": "secondary",
		"source": SRC_DIAS + ". Caso medido más parecido: la uña humana; se toma el mínimo (la garra conduce el calor igual o mejor)",
	},
	"specific_heat_j_kg_k": {
		"value": 1530.0, "min": 1460.0, "max": 1600.0, "quality": "estimate",
		"source": SRC_PICARD + ". Caso medido más parecido: la queratina del cuerno",
	},
	"bed_c": {
		"value": 32.0, "quality": "estimate",
		"source": "temperatura de partida de la carne viva de la garra: la de la piel de la que parten las pruebas de dolor por calor (32 °C, " + SRC_PAN + "); sin medición en garras",
	},
	"partition": {
		"value": 0.5, "min": 0.2, "max": 0.85, "quality": "estimate",
		"source": "parte del calor del roce que entra en la garra. Caso medido más parecido: el amolado con abrasivos convencionales, 60-85 % a la pieza de acero (" + SRC_MALKIN + "); la queratina conduce ~100 veces menos que el acero y el tambor y el polvo se llevan más: se toma 0,5 con la banda 0,2-0,85. Con 0,5, tocar una uña varios segundos seguidos a 13 000 rpm la calienta por encima del umbral del dolor, como avisa " + SRC_DREMEL_GUIDE,
	},
	"friction": {
		"value": 0.325, "min": 0.25, "max": 0.40, "quality": "estimate",
		"source": "sin medición de la lija contra la queratina; caso medido más parecido: " + SRC_BIRO,
	},
	"h_air": {
		"value": 15.0, "min": 2.0, "max": 25.0, "quality": "estimate",
		"source": "convección natural en gases, 2-25 W/(m²·K): " + SRC_INCROPERA + ". El modelo sigue lo que el torno calienta por encima de la garra en reposo (la conducción es lineal), así que el aire cuenta a la temperatura de partida",
	},
	"hand": {
		"value": 0.0, "quality": "estimate",
		"source": "a mano, la lima desliza a ~0,1 m/s: P = μ·F·v ≈ 0,1 W con 3 N, 40-90 veces menos que el tambor del torno (4-9 m/s). Y una lima de acero conduce ~250 veces mejor que la queratina (" + SRC_C100S + "; la queratina, k = α·ρ·c ≈ 0,2 W/(m·K)): con los dos cuerpos quietos y el mismo contacto circular, las dos caras llegan a la misma temperatura cuando la garra se queda k_garra/(k_garra + k_lima) ≈ 0,4 % del calor (con la fuente circular fija de " + SRC_CARSLAW + "). El calor de las limas y las lijas a mano se desprecia (estimación)",
	},
	"pain_c": {
		"value": 43.0, "min": 40.0, "max": 45.0, "quality": "secondary",
		"source": "umbral del dolor por calor, ~40-45 °C (" + SRC_DUBIN + "); medido en personas, 40,8-42,6 °C de media (" + SRC_PAN + "). Las aves también detectan el calor nocivo (" + SRC_JORDT + "); en ellas y en los grandes carnívoros no está medido en la garra: se toma el centro de la banda",
	},
	"live_mm": { "value": 2.0, "quality": "estimate", "source": "tejido vivo del modelo térmico detrás de la carne viva, con la sangre a la temperatura de partida en su extremo (modelo)" },
	"max_depth_mm": { "value": 12.0, "quality": "estimate", "source": "más allá de 12 mm de queratina el calor de unos minutos no llega (√(α·t) ≈ 5 mm con t = 250 s): la carne viva se da por fría (modelo)" },
	# La queratina se desnaturaliza y empieza a quemarse hacia los 215-255 °C: por encima, el roce del torno la quema en
	# lugar de seguir calentándola. El modelo térmico no pasa de aquí (sin este tope, un torno quieto sobre un contacto
	# diminuto, sin material que arrancar, subía a miles de grados).
	"char_c": {
		"value": 230.0, "min": 215.0, "max": 255.0, "quality": "secondary",
		"source": SRC_KAKKAR + "; " + SRC_WORTMANN + ". Caso medido más parecido: la queratina de la pezuña y las queratinas α; la de las garras de las aves es β y no está medida. Por encima, la queratina se quema (huele a quemado) y el modelo no la calienta más (suposición del modelo)",
	},
}
## Lesión térmica del tejido: [temperatura (°C), tiempo hasta la lesión (s)] (Moritz & Henriques 1947). Por debajo de
## 44 °C no se acumula lesión. La lesión se suma como fracción del tiempo hasta la lesión a cada temperatura (como la
## regla de Miner: suposición del modelo).
const INJURY_TABLE := [
	[44.0, 21600.0], [45.0, 10800.0], [50.0, 300.0], [55.0, 30.0], [60.0, 5.0], [65.0, 2.0], [70.0, 1.0],
]

# ════════ Animales ════════
## Rapaces del banco que se pueden elegir (las mismas garras de Data.CLAWS, con las correcciones de claws_v2.gd).
const RAPTOR_IDS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const ANIMAL_IDS := ["rapaz", "tigre", "oso", "velociraptor"]
## Donde acaba la carne viva, como fracción del estuche medida desde la base (el núcleo óseo con su dermis).
const CORE_RATIO := {
	"value": 0.699, "min": 0.693, "max": 0.85, "quality": "secondary",
	"source": SRC_HEDRICK + "; banda alta: " + SRC_MANNING + ". La dermis con los vasos y los nervios cubre el hueso: la carne viva llega hasta la punta del núcleo",
}
const CORE_RATIO_MAMMAL := {
	"value": 0.699, "min": 0.693, "max": 0.85, "quality": "estimate",
	"source": "sin medición en felinos ni osos: caso medido más parecido, las garras de las aves (" + SRC_HEDRICK + "; " + SRC_MANNING + "). Pregunta abierta",
}
const ANIMALS := {
	"rapaz": {
		"id": "rapaz", "name": "Rapaz", "kind": "ave", "claws": RAPTOR_IDS, "claw": "aguila",
		"core_ratio": CORE_RATIO,
		"growth_mm_day": {
			"value": 0.04, "quality": "estimate",
			"source": "sin medición en rapaces; caso medido más parecido, cinco paseriformes europeos: " + SRC_BEARHOP,
		},
		"regrow_days": {
			"value": 75.0, "min": 60.0, "max": 90.0, "quality": "secondary",
			"source": SRC_SAMOUR + ", p. 925: una garra arrancada vuelve a crecer, «a slow process sometimes requiring up to 2 to 3 months»",
		},
		"restraint": "sujecion", "quick_visible": false, "retractile": false,
		"layers": {
			"value": "estuche duro por arriba y por los lados y placa ventral mucho más blanda; láminas de queratina",
			"quality": "secondary", "source": SRC_SAMOUR + ", p. 925; " + SRC_ARENT,
		},
		"note": "Encapuchada y envuelta en una toalla; las grandes, entre dos personas (Samour 2006). Isoflurano si se estresa mucho (Arent & Pollock).",
	},
	"tigre": {
		"id": "tigre", "name": "Tigre", "kind": "felino", "claws": ["tigre"], "claw": "tigre",
		"core_ratio": CORE_RATIO_MAMMAL,
		"growth_mm_day": {
			"value": 0.13, "min": 0.01, "max": 0.27, "quality": "estimate",
			"source": "sin medición en tigres; caso medido más parecido, las manos del gato doméstico: " + SRC_CONTRERAS,
		},
		"restraint": "anestesia", "quick_visible": true, "retractile": true,
		"layers": {
			"value": "conos de queratina anidados; las capas de fuera se desprenden en capuchones por microgrietas que no llegan al tejido vivo",
			"quality": "secondary", "source": "caso medido más parecido, el gato doméstico: " + SRC_HOMBERGER,
		},
		"note": "Siempre anestesiado por un veterinario de fauna (Cat Tales 2024). Garra clara: la carne viva se ve a trasluz.",
	},
	"oso": {
		"id": "oso", "name": "Oso pardo", "kind": "oso", "claws": ["oso"], "claw": "oso",
		"core_ratio": CORE_RATIO_MAMMAL,
		"growth_mm_day": {
			"value": 0.27, "min": 0.26, "max": 0.28, "quality": "estimate",
			"source": "sin medición en osos; caso medido más parecido, otro carnívoro excavador de garra larga: " + SRC_ETHIER,
		},
		"restraint": "anestesia", "quick_visible": false, "retractile": false,
		"layers": {
			"value": "garra no retráctil que crece sin parar y se gasta al excavar",
			"quality": "estimate", "source": "ficha del oso del banco (Data.CLAWS: «enorme y curva pero roma (excava)»)",
		},
		"note": "Siempre anestesiado (Animals Asia). Algunos zoológicos entrenan al oso para presentar la pata (BIAZA 2019), no para limarle la garra.",
	},
	"velociraptor": {
		"id": "velociraptor", "name": "Velocirraptor (reconstrucción)", "kind": "dinosaurio", "claws": ["velociraptor"],
		"claw": "velociraptor",
		"core_ratio": {
			"value": Velociraptor.CORE_TO_SHEATH, "min": Velociraptor.CORE_TO_SHEATH_LO, "max": 0.85, "quality": "estimate",
			"source": "la garra de la reconstrucción: hueso fósil de 64,8 mm y estuche de 92,7 mm (velociraptor.gd, unidad 4e); la carne viva, hasta la punta del hueso, como en sus parientes vivos, las aves (" + SRC_HEDRICK + ")",
		},
		"growth_mm_day": {
			"value": 0.04, "quality": "estimate",
			"source": "sin medición posible (extinguido); como las aves: " + SRC_BEARHOP,
		},
		"restraint": "anestesia", "quick_visible": false, "retractile": false,
		"layers": {
			"value": "estuche de queratina de ave (se supone): duro por arriba y por los lados, placa ventral más blanda",
			"quality": "estimate", "source": "suposición: como las rapaces, sus parientes vivos (" + SRC_SAMOUR + ")",
		},
		"note": "«Dormido» es anestesiado: experimento mental. Se sigue el protocolo de un gran carnívoro anestesiado y la garra se trata como la de un ave.",
	},
}

# ════════ La forma de cada garra, dedo a dedo (petición 36 y punto 4 de la 5g) ════════
## La garra de cada dedo, relativa a la del dedo de referencia (ref_digit), que es la de la ficha del banco: su largo es
## reach y su radio en la base, Physics.MODEL.clawBase·reach (la 1.x). Por garra del banco (Data.CLAWS):
##   - digits: { dedo: { length_ratio, base_ratio, arc_deg, arc_inner_deg } }:
##       · length_ratio: el largo de la garra (el arco medio, la media de los arcos de fuera y de dentro) entre el del dedo
##         de referencia;
##       · base_ratio: el alto de la garra en la base (de arriba abajo) entre el del dedo de referencia (el ahusado: el
##         radio de la base de cada dedo, relativo al largo, sale de los dos);
##       · arc_deg: el ángulo del arco de la curva exterior (Oo, método de Pike y Maitland 2004: el que gira la garra de la
##         base a la punta), salvo donde arc_method diga «interior» (el velocirraptor: el de dentro, por el método de
##         Feduccia 1993); arc_inner_deg: el de la curva de dentro (Oi) o null.
##   - hind (tigre y oso): las garras de las patas traseras, relativas a las de la mano del mismo dedo.
##   - section_ratio: lo comprimida de lado que es, alto/ancho de la sección en la base (1: redonda). La física es redonda,
##     con el radio del perfil (snapshot().profile.r); el dibujo la aplasta sin cambiar el área: alto = 2·r·√k y
##     ancho = 2·r/√k.
##   - ventral_flat: la cara de abajo plana (las rapaces: la placa ventral).
## Lo lee ClawCare (configure con digit y paw; CareData.claw_shape) y lo enseña snapshot().claw (digit, hind, arcDeg,
## arcInnerDeg, sectionRatio, ventralFlat, shapeQuality, shapeSource).
const SRC_PIKE_MAITLAND := "Pike AVL, Maitland DP (2004). Scaling of bird claws. J. Zool. 262:73-81 (el ángulo del arco de una curva de la garra: el del círculo que pasa por la base, la punta y su punto medio)"
const SRC_FOWLER_2009 := "Fowler DW, Freedman EA, Scannella JB (2009). Predatory functional morphology in raptors: interdigital variation in talon size is related to prey restraint and immobilisation technique. PLoS ONE 4:e7999. doi:10.1371/journal.pone.0007999, tabla S1 (cada garra de cada dedo, medida en fotografía con el método de " + SRC_PIKE_MAITLAND + ": cuerda, alto en el punto medio y ángulo de las curvas de fuera y de dentro, y alto en la base; el largo, el arco)"
const SRC_BIRN_JEFFERY := Velociraptor.SRC_BIRN_JEFFERY_2012 + ", tabla S1 (el ángulo de la curva de fuera, con el método de Pike y Maitland, de las garras del dedo III con su estuche, de museo, y las de Pike y Maitland 2004)"
## El arco de las rapaces (arc_deg): la media de lo medido en la garra del dedo III de la especie (la del banco o la más
## parecida), y cada dedo con lo que gira respecto al III en el ejemplar de Fowler et al. (2009); la curva de dentro, en la
## misma proporción. Un solo ejemplar varía ±15° (el halcón de Fowler, 136°; la media de siete, 122°).
const _RAPTOR_ARC := "El arco: la media de las garras del dedo III medidas por fuera (" + SRC_FOWLER_2009 + "; " + SRC_BIRN_JEFFERY + "), y cada dedo con lo que gira respecto al III en el ejemplar de Fowler; la curva de dentro, en la misma proporción"
const SRC_AIWC_2023 := "Muhsina Thunnisa, Pavithra Rajkumar (2023). Delineating feline claws and canine teeth of tiger and leopard by morphometric methods. Advanced Institute for Wildlife Conservation, Tamil Nadu Forest Department, tabla 4.7 (43 garras de tigre de necropsias, sin decir el dedo ni la pata: ángulo de la curva exterior 98,4° de media, 69,5-122,6°; radio 22,2 mm; largo exterior 43,3 mm, 29,2-62,3)"
const SRC_NPS_BEARS := "U.S. National Park Service, «Bear identification»: las garras de la mano del oso pardo son «slightly curved and 2-4 inches long» (51-102 mm), según lo que excave"
const _RAPTOR_SECTION := {
	"value": 1.0, "quality": "estimate",
	"source": "sin medición del alto y el ancho de la base en las rapaces: sección redondeada, como la de la física, con la cara de abajo plana (la placa ventral, mucho más blanda que el estuche de arriba y de los lados: " + SRC_SAMOUR + ", p. 925)",
}
const _RAPTOR_VENTRAL := { "value": true, "quality": "secondary", "source": SRC_SAMOUR + ", p. 925; " + SRC_ARENT }
## La base de la hoz del velocirraptor (petición 48, unidad 5o): el núcleo óseo medido en la base (18,7 × 7,1 mm, Norell y
## Makovicky 1999) más el estuche de queratina, con el estuche igual de grueso en proporción que de largo (el núcleo mide 0,699
## veces el estuche en las aves, Hedrick et al. 2019: estimación con el caso medido más parecido, la proporción a lo largo).
## radiusMm: el radio de la sección redonda de la misma área (la física, como las demás garras: alto 2·r·√k y ancho 2·r/√k en
## el dibujo); ratio: frente a la base genérica de la ficha del banco (0,15 × el alcance, Physics.MODEL), la que lee
## CLAW_SHAPES. Antes salía con la genérica: 13,9 mm de radio, 45 × 17 mm de base.
const VELOCIRAPTOR_BASE := {
	"heightMm": Velociraptor.SICKLE["coreHeightMm"]["value"] / Velociraptor.CORE_TO_SHEATH,
	"widthMm": Velociraptor.SICKLE["coreWidthMm"]["value"] / Velociraptor.CORE_TO_SHEATH,
	"radiusMm": 0.5 * sqrt(Velociraptor.SICKLE["coreHeightMm"]["value"] * Velociraptor.SICKLE["coreWidthMm"]["value"]) / Velociraptor.CORE_TO_SHEATH,
	"ratio": 0.5 * sqrt(Velociraptor.SICKLE["coreHeightMm"]["value"] * Velociraptor.SICKLE["coreWidthMm"]["value"]) / Velociraptor.CORE_TO_SHEATH / (ClawMass.CLAW_BASE * Velociraptor.ENTRY["reach"]),
	"quality": "estimate",
	"source": "el núcleo óseo medido en la base, 18,7 × 7,1 mm (" + Velociraptor.SRC_NORELL_1999 + ", tabla 3), más el estuche de queratina, igual de grueso en proporción que de largo: el núcleo mide 0,699 veces el estuche (" + Velociraptor.SRC_HEDRICK_2019 + "; estimación con el caso medido más parecido, la proporción a lo largo): 26,8 × 10,2 mm de base",
}
const CLAW_SHAPES := {
	"aguila": {
		"ref_digit": "III", "quality": "primary", "specimen": "águila real (Aquila chrysaetos), MSU ECO-4666, pata izquierda, con el estuche",
		"source": SRC_FOWLER_2009 + ". El largo del banco (35 mm) es el del dedo III: el arco medio de esta garra III mide 36,4 mm (30,3 por dentro y 42,6 por fuera). En las águilas, la garra del dedo I, el talón, es la mayor. " + _RAPTOR_ARC + ": 124,5° en el águila real (4 garras, 116-133°)",
		"digits": {
			"I": { "length_ratio": 1.625, "base_ratio": 1.401, "arc_deg": 134.1, "arc_inner_deg": 118.1 },
			"II": { "length_ratio": 1.394, "base_ratio": 1.381, "arc_deg": 130.4, "arc_inner_deg": 118.1 },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 124.5, "arc_inner_deg": 106.2 },
			"IV": { "length_ratio": 0.772, "base_ratio": 1.003, "arc_deg": 126.9, "arc_inner_deg": 94.6 },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"arpia": {
		"ref_digit": "III", "quality": "secondary", "specimen": "arpía (Harpia harpyja), AMNH-1383, los núcleos óseos sin el estuche",
		"source": SRC_FOWLER_2009 + ". Los largos y los altos, de los núcleos óseos (sin el estuche, el largo y la curva son menores, pero no lo que mide cada dedo respecto a los otros, según los autores). El arco: la media de las garras del dedo III de arpía medidas con su estuche, 114,6° (5 garras, 87-134°; " + SRC_BIRN_JEFFERY + "), y cada dedo con lo que gira respecto al III en la media de las 17 patas de accipítridas de Fowler (tabla resumen), porque el hueso solo es menos curvo",
		"digits": {
			"I": { "length_ratio": 2.057, "base_ratio": 1.712, "arc_deg": 131.6, "arc_inner_deg": null },
			"II": { "length_ratio": 1.537, "base_ratio": 1.547, "arc_deg": 127.5, "arc_inner_deg": null },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 114.6, "arc_inner_deg": null },
			"IV": { "length_ratio": 0.8, "base_ratio": 0.802, "arc_deg": 120.5, "arc_inner_deg": null },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"halcon": {
		"ref_digit": "III", "quality": "primary", "specimen": "halcón peregrino (Falco peregrinus), MOR OST-1265, macho adulto de 580 g",
		"source": SRC_FOWLER_2009 + ". En los halcones las cuatro garras se parecen más que en las águilas: rematan con el pico. " + _RAPTOR_ARC + ": 122,1° en el halcón peregrino (7 garras, 104-136°)",
		"digits": {
			"I": { "length_ratio": 1.15, "base_ratio": 1.333, "arc_deg": 135.5, "arc_inner_deg": 112.3 },
			"II": { "length_ratio": 0.991, "base_ratio": 1.175, "arc_deg": 122.0, "arc_inner_deg": 99.3 },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 122.1, "arc_inner_deg": 100.5 },
			"IV": { "length_ratio": 0.885, "base_ratio": 0.986, "arc_deg": 126.2, "arc_inner_deg": 103.3 },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"buho": {
		"ref_digit": "III", "quality": "secondary", "specimen": "búho americano (Bubo virginianus), MOR OST-1288, hembra adulta de 1440 g",
		"source": SRC_FOWLER_2009 + ". Caso medido más parecido al búho real (Bubo bubo), del mismo género. En los búhos la garra del dedo I no es la mayor. " + _RAPTOR_ARC + ": 115,5° en el búho real medido (4 garras, 105-123°)",
		"digits": {
			"I": { "length_ratio": 0.856, "base_ratio": 1.102, "arc_deg": 130.6, "arc_inner_deg": 115.4 },
			"II": { "length_ratio": 1.014, "base_ratio": 1.15, "arc_deg": 113.5, "arc_inner_deg": 101.8 },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 115.5, "arc_inner_deg": 97.3 },
			"IV": { "length_ratio": 0.84, "base_ratio": 0.92, "arc_deg": 120.4, "arc_inner_deg": 105.1 },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"lechuza": {
		"ref_digit": "III", "quality": "secondary", "specimen": "lechuza campestre (Asio flammeus), MOR OST-1282, adulta de 390 g",
		"source": SRC_FOWLER_2009 + ". Caso medido más parecido a la lechuza común (Tyto alba, sin medir dedo a dedo): una rapaz nocturna de su peso. " + _RAPTOR_ARC + ": 103,2° en la lechuza común medida (6 garras, 88-116°)",
		"digits": {
			"I": { "length_ratio": 0.899, "base_ratio": 1.085, "arc_deg": 115.8, "arc_inner_deg": 110.0 },
			"II": { "length_ratio": 0.934, "base_ratio": 1.081, "arc_deg": 101.9, "arc_inner_deg": 84.3 },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 103.2, "arc_inner_deg": 81.9 },
			"IV": { "length_ratio": 0.827, "base_ratio": 0.933, "arc_deg": 108.0, "arc_inner_deg": 101.7 },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"buitre": {
		"ref_digit": "III", "quality": "secondary", "specimen": "aura gallipavo (Cathartes aura), MOR OST-1269",
		"source": SRC_FOWLER_2009 + ". Caso medido más parecido al buitre leonado (Gyps fulvus, sin medir): el único carroñero de la tabla, que también camina sobre sus garras romas; la del dedo I, pequeña y poco curva. " + _RAPTOR_ARC + ": 81,0° en el buitre dorsiblanco africano (Gyps africanus, del mismo género que el leonado; 2 garras, 79-83°)",
		"digits": {
			"I": { "length_ratio": 0.568, "base_ratio": 0.888, "arc_deg": 79.5, "arc_inner_deg": 50.9 },
			"II": { "length_ratio": 0.999, "base_ratio": 1.034, "arc_deg": 99.4, "arc_inner_deg": 66.6 },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 81.0, "arc_inner_deg": 58.5 },
			"IV": { "length_ratio": 0.801, "base_ratio": 0.731, "arc_deg": 100.0, "arc_inner_deg": 85.8 },
		},
		"section_ratio": _RAPTOR_SECTION, "ventral_flat": _RAPTOR_VENTRAL,
	},
	"tigre": {
		"ref_digit": "III", "quality": "estimate", "specimen": "tigre (Panthera tigris): garras sueltas, sin el dedo",
		"source": "sin medición dedo a dedo en felinos: las cuatro garras de la mano que apoyan, del largo y el grueso de la del banco (40 mm, dentro de lo medido: " + SRC_AIWC_2023 + "). El arco, el medido en tigres, de media; pregunta abierta: qué dedo es cada garra",
		"digits": {
			"II": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.4, "arc_inner_deg": null },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.4, "arc_inner_deg": null },
			"IV": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.4, "arc_inner_deg": null },
			"V": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.4, "arc_inner_deg": null },
		},
		"hind": {
			"length_ratio": 1.0, "base_ratio": 1.0, "arc_ratio": 1.0, "quality": "estimate",
			"source": "sin medición de las garras de las patas traseras de los felinos: como las de la mano. En el gato crecen más despacio (0,08 frente a 0,13 mm/día: " + SRC_CONTRERAS + "), pero su largo no está medido. Pregunta abierta",
			# (última vuelta de la 5s) lo que crecen las de las patas frente a las de la mano: las medianas del gato
			"growth_ratio": 0.08 / 0.13, "growth_quality": "estimate",
			"growth_source": "sin medición en tigres; caso medido más parecido, el gato doméstico: las garras de las patas crecen 0,08 mm/día y las de las manos 0,13 (medianas; " + SRC_CONTRERAS + ")",
		},
		"section_ratio": {
			"value": 1.8, "quality": "estimate",
			"source": "sin medición del alto y el ancho de la base en felinos: una garra comprimida de lado, alta y estrecha; se toma 1,8, entre la sección casi redonda de las rapaces y la hoja de 2,6 de la garra en hoz del velocirraptor, la única medida (" + Velociraptor.SRC_NORELL_1999 + ")",
		},
		"ventral_flat": { "value": false, "quality": "estimate", "source": "la garra de los felinos acaba abajo en filo, no en una cara plana (sin medición)" },
	},
	"oso": {
		"ref_digit": "III", "quality": "estimate", "specimen": "oso pardo (Ursus arctos)",
		"source": "sin medición dedo a dedo en osos: las cinco garras de la mano, del largo y el grueso de la del banco (60 mm, dentro de lo medido: " + SRC_NPS_BEARS + "). El arco, el del dibujo del banco (35° + 115°·0,55): «slightly curved», sin el ángulo medido. Pregunta abierta",
		"digits": {
			"I": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.25, "arc_inner_deg": null },
			"II": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.25, "arc_inner_deg": null },
			"III": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.25, "arc_inner_deg": null },
			"IV": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.25, "arc_inner_deg": null },
			"V": { "length_ratio": 1.0, "base_ratio": 1.0, "arc_deg": 98.25, "arc_inner_deg": null },
		},
		"hind": {
			"length_ratio": 1.0, "base_ratio": 1.0, "arc_ratio": 1.0, "quality": "estimate",
			"source": "sin medición de las garras de las patas traseras del oso pardo: como las de la mano (se describen más cortas y menos curvas, pero sin medida publicada que hayamos podido leer). Pregunta abierta",
		},
		"section_ratio": {
			"value": 1.3, "quality": "estimate",
			"source": "sin medición: una garra larga y gruesa, algo más alta que ancha; se toma 1,3, entre la sección casi redonda de las rapaces y la de los felinos",
		},
		"ventral_flat": { "value": false, "quality": "estimate", "source": "sin medición" },
	},
	"velociraptor": {
		"ref_digit": "II", "quality": "estimate", "arc_method": "interior", "specimen": "Velociraptor mongoliensis, la garra en hoz del dedo II (velociraptor.gd, unidad 4e)",
		"source": "la garra de la reconstrucción (" + Velociraptor.SRC_NORELL_1999 + "), la única que se trabaja. El arco, el de velociraptor.gd: estimación con el arco interior de la garra II de Deinonychus, 160° (" + Velociraptor.SRC_MANNING_2006 + "). La base: " + String(VELOCIRAPTOR_BASE.source),
		"digits": {
			"II": { "length_ratio": 1.0, "base_ratio": VELOCIRAPTOR_BASE.ratio, "arc_deg": Velociraptor.SICKLE["arcDeg"]["value"], "arc_inner_deg": null },
		},
		"section_ratio": {
			"value": Velociraptor.SICKLE["coreHeightMm"]["value"] / Velociraptor.SICKLE["coreWidthMm"]["value"], "quality": "primary",
			"source": Velociraptor.SRC_NORELL_1999 + ", tabla 3: el núcleo óseo de IGM 100/985 mide 18,7 mm de alto por 7,1 de ancho en la base (2,6 veces más alto que ancho); el estuche se supone igual de comprimido",
		},
		"ventral_flat": { "value": false, "quality": "estimate", "source": "una hoja comprimida de lado (" + Velociraptor.SRC_NORELL_1999 + ")" },
	},
}


# ════════ El arco de cada garra del banco (lo pidió la 5e: una sola fuente para la cetrería, la galería y el coche) ════════
## Las garras del banco que no se trabajan en la cetrería: el ángulo del arco de la curva exterior (Pike y Maitland 2004),
## medido o estimado con el caso medido más parecido. Las de la cetrería, en CLAW_SHAPES (dedo a dedo). Lo da claw_arc().
const SRC_AIWC_TIGER_ARC := "el arco medido en tigres, 98,4° de media por fuera (" + SRC_AIWC_2023 + ")"
const CLAW_ARCS := {
	"gato": {
		"arc_deg": 98.4, "quality": "estimate",
		"source": "sin medición del arco en el gato: " + SRC_AIWC_TIGER_ARC + ", el felino medido más parecido",
	},
	"casuario": {
		"arc_deg": 41.0, "quality": "secondary",
		"source": "el casuario medido (Casuarius casuarius): la garra del dedo III, 41° (" + SRC_PIKE_MAITLAND + ", recogido en " + SRC_BIRN_JEFFERY + "). La daga es la garra del dedo II, «recta», sin el arco medido: se toma la del mismo pie",
	},
	"emu": {
		"arc_deg": 41.0, "quality": "estimate",
		"source": "sin medición en el emú: la del casuario, su pariente más cercano (dedo III, 41°; " + SRC_PIKE_MAITLAND + ", recogido en " + SRC_BIRN_JEFFERY + ")",
	},
	"avestruz": {
		"arc_deg": 31.0, "quality": "estimate",
		"source": "sin medición en el avestruz: la del ñandú (Rhea americana, dedo III, 31°; " + SRC_PIKE_MAITLAND + ", recogido en " + SRC_BIRN_JEFFERY + "), la otra rátida corredora medida: una uña casi pezuña",
	},
	"gallo": {
		"arc_deg": 75.25, "quality": "estimate",
		"source": "sin medición del arco del espolón: el del dibujo del banco (35° + 115°·0,35), dentro de lo medido en las garras de los faisánidos y las pintadas: de 54° el faisán (" + SRC_PIKE_MAITLAND + ") a 84-115° la pintada (" + SRC_BIRN_JEFFERY + ")",
	},
	"guacamayo": {
		"arc_deg": 136.0, "quality": "secondary",
		"source": "el guacamayo macao (Ara macao), dedo III: 136° (" + SRC_PIKE_MAITLAND + ", recogido en " + SRC_BIRN_JEFFERY + ")",
	},
	"pajaro": {
		"arc_deg": 105.3, "quality": "secondary",
		"source": "el gorrión común (Passer domesticus), dedo III: la media de 7 garras, 105,3° (89-130°; " + SRC_BIRN_JEFFERY + ")",
	},
}

## Crecimiento de más por defecto (días sin desgaste). Elección del ensayo: una temporada en cautividad con perchas o
## suelos blandos (el desgaste se toma nulo, estimación: sin medición del desgaste en cautividad).
const DEFAULT_OVERGROWTH_DAYS := 90.0

# ════════ Sujeción y anestesia ════════
## Cuánto dolor aguanta el animal sin moverse (0-1), según cómo está sujeto. ÍNDICE PEDAGÓGICO (no físico): con anestesia
## general no se mueve nunca; con sedación, solo con un dolor fuerte; sujeto (capucha y toalla), con un dolor moderado;
## suelto, con cualquier dolor.
const SEDATION := {
	"libre": { "name": "Sin sujetar", "move_pain": 0.15, "stress_rate": 0.02, "source": SRC_SAMOUR + ": una rapaz sin sujetar puede «clavar» al que la maneja" },
	"sujecion": { "name": "Capucha y toalla (dos personas)", "move_pain": 0.5, "stress_rate": 0.004, "source": SRC_SAMOUR + ", pp. 916-917: encapuchada, envuelta en una toalla suave; las grandes, entre dos personas" },
	"sedacion": { "name": "Sedación", "move_pain": 0.85, "stress_rate": 0.001, "source": SRC_CATTALES },
	"anestesia": { "name": "Anestesia general", "move_pain": INF, "stress_rate": 0.0, "source": SRC_SAMOUR + " (isoflurano en rapaces); " + SRC_CATTALES + "; " + SRC_ANIMALS_ASIA },
}
## Dolor (0-1) de cada suceso. ÍNDICE PEDAGÓGICO: cortar o rajar la carne viva, 1; aplastarla, 0,6; el calor, de 0 a 1
## entre el umbral del dolor y 50 °C; el nitrato de plata en una herida, 0,5 (duele más que el subsulfato férrico).
const PAIN := { "quick_cut": 1.0, "quick_split": 1.0, "quick_crush": 0.6, "heat_full_c": 50.0, "silver_nitrate": 0.5, "source": SRC_RUBRIC + "; " + SRC_COAKLEY }

# ════════ Herramientas ════════
## Elementos de corte: «diente» (arista de una lima: dientes por cm a lo largo) o «grano» (abrasivo: tamaño medio en µm).
## half_angle_deg y tip_um: semiángulo y radio de la arista o del grano (ESTIMACIONES de geometría, sin medición: dientes
## de lima de unos 90° y aristas de ~10 µm; granos de ~120° con puntas de ~5 µm). engaged: fracción de los granos de una
## lija que tocan a la vez (estimación). tool_hv: dureza de la herramienta, la que decide qué puede limar.
const TOOL_IDS := [
	"lima_bastarda", "lima_entrefina", "lima_fina", "lima_diamante_gruesa", "lima_diamante_fina", "lija_p180", "lija_p240",
	"torno", "amoladora", "guillotina", "tijera", "tenaza", "hemostatico", "nitrato_plata", "clorhexidina", "crema", "metacrilato",
]
const TOOTH_GEOMETRY := { "half_angle_deg": 45.0, "tip_um": 10.0, "quality": "estimate", "source": "sin medición: dientes de lima de ~90° de ángulo incluido y arista de ~10 µm (nueva)" }
const GRAIN_GEOMETRY := { "half_angle_deg": 60.0, "tip_um": 5.0, "engaged": 0.1, "quality": "estimate", "source": "sin medición: granos de ~120° con la punta de ~5 µm; tocan a la vez ~10 % de los granos" }
## Tamaño de grano crítico (µm): por debajo, el arranque crece con el tamaño del grano (Kalácska et al. 2021).
const CRITICAL_GRAIN_UM := { "value": 82.0, "quality": "secondary", "source": SRC_KALACSKA + ". Caso medido más parecido: aceros; en la queratina, sin medición" }
## El largo de la cara que trabaja de cada herramienta de limar (unidad 5l), face_mm: por donde se reparte su desgaste (la
## garra la recorre entera en cada pasada, como aconseja Nicholson: usar todo el largo de la lima). La del tambor es su vuelta,
## π·12,7 mm, y su banda mide 12,7 mm de alto (band_mm).
const SRC_FACE_FILE := "la lima de 150 mm de DIN 8349 (la de 13, 18 y 22 dientes por cm)"
const SRC_FACE_DIAMOND := "estimación: la cara de ~110 mm de una lima de diamante de mano de unas 4 in, la de la bandeja (sin el largo en la ficha de DMT)"
const SRC_FACE_BOARD := "estimación: una lima de cartón de ~7 in (180 mm), el largo habitual de las de uñas, la de la bandeja"
const SRC_FACE_DRUM := "la vuelta del tambor de 12,7 mm (π·D) y la banda de 1/2″ de alto: estimación (las bandas 407 y 408 de Dremel son de 1/2″)"
const TOOLS := {
	"lima_bastarda": {
		"id": "lima_bastarda", "name": "Lima de acero, picado bastardo (1)", "kind": "lima", "element": "diente",
		"teeth_cm": 13.0, "tool_hv": 700.0, "face_mm": 150.0, "face_source": SRC_FACE_FILE,
		"quality": "secondary", "source": SRC_DIN8349 + "; " + SRC_FWT,
	},
	"lima_entrefina": {
		"id": "lima_entrefina", "name": "Lima de acero, picado entrefino (2)", "kind": "lima", "element": "diente",
		"teeth_cm": 18.0, "tool_hv": 700.0, "face_mm": 150.0, "face_source": SRC_FACE_FILE,
		"quality": "secondary", "source": SRC_DIN8349 + "; " + SRC_FWT,
	},
	"lima_fina": {
		"id": "lima_fina", "name": "Lima de acero, picado fino (3)", "kind": "lima", "element": "diente",
		"teeth_cm": 22.0, "tool_hv": 700.0, "face_mm": 150.0, "face_source": SRC_FACE_FILE,
		"quality": "secondary", "source": SRC_DIN8349 + "; " + SRC_FWT,
	},
	"lima_diamante_gruesa": {
		"id": "lima_diamante_gruesa", "name": "Lima de diamante gruesa (45 µm)", "kind": "lima", "element": "grano",
		"grain_um": 45.0, "tool_hv": 10000.0, "face_mm": 110.0, "face_source": SRC_FACE_DIAMOND,
		"quality": "secondary", "source": SRC_DMT + "; diamante de 10 000 HV (Data.INLAYS, core/taller/abrasives.gd)",
	},
	"lima_diamante_fina": {
		"id": "lima_diamante_fina", "name": "Lima de diamante fina (25 µm)", "kind": "lima", "element": "grano",
		"grain_um": 25.0, "tool_hv": 10000.0, "face_mm": 110.0, "face_source": SRC_FACE_DIAMOND,
		"quality": "secondary", "source": SRC_DMT + "; diamante de 10 000 HV (Data.INLAYS, core/taller/abrasives.gd)",
	},
	"lija_p180": {
		"id": "lija_p180", "name": "Lima de cartón de corindón P180", "kind": "lima", "element": "grano",
		"grain_um": 77.2, "tool_hv": 2000.0, "face_mm": 180.0, "face_source": SRC_FACE_BOARD,
		"quality": "secondary", "source": SRC_KLINGSPOR + " (P180 ≈ 77 µm); corindón (Al₂O₃) de 2000 HV (core/taller/abrasives.gd)",
	},
	"lija_p240": {
		"id": "lija_p240", "name": "Lima de cartón de corindón P240", "kind": "lima", "element": "grano",
		"grain_um": 57.9, "tool_hv": 2000.0, "face_mm": 180.0, "face_source": SRC_FACE_BOARD,
		"quality": "secondary", "source": SRC_KLINGSPOR + " (P240 ≈ 58 µm); corindón (Al₂O₃) de 2000 HV (core/taller/abrasives.gd)",
	},
	"torno": {
		"id": "torno", "name": "Torno de uñas (tambor de lija de grano 60)", "kind": "torno", "element": "grano",
		"grain_um": 258.0, "tool_hv": 2000.0, "drum_mm": 12.7, "rpm_steps": [6500.0, 13000.0], "rpm": 6500.0,
		"face_mm": PI * 12.7, "band_mm": 12.7, "face_source": SRC_FACE_DRUM,
		"quality": "secondary",
		"source": SRC_DREMEL_7300 + "; grano 60 ≈ P60, 0,0101 in ≈ 258 µm (" + SRC_KLINGSPOR + "); tambor de 1/2″ (12,7 mm) y corindón de 2000 HV: estimación (lo habitual en las bandas de lija de tambor)",
	},
	## La amoladora de uñas de mascota con protector (unidad 5c): el mismo modelo que el torno (ClawCare, «torno»), con sus
	## cuatro velocidades y la banda de lija de grano 60 de la ficha. guard_deg: el ángulo al que la apoya su protector.
	"amoladora": {
		"id": "amoladora", "name": "Amoladora de uñas con protector (banda de lija de grano 60)", "kind": "torno", "element": "grano",
		"grain_um": 258.0, "tool_hv": 2000.0, "drum_mm": 12.7, "rpm_steps": [8000.0, 14000.0, 21000.0, 25000.0], "rpm": 8000.0,
		"guard_deg": 45.0, "battery_v": 4.0, "battery_ah": 2.0, "length_mm": 190.5,
		"face_mm": PI * 12.7, "band_mm": 12.7, "face_source": SRC_FACE_DRUM,
		"quality": "secondary",
		"source": SRC_DREMEL_7760 + "; " + SRC_DREMEL_LITE + "; grano 60 ≈ P60, 0,0101 in ≈ 258 µm (" + SRC_KLINGSPOR + "); corindón de 2000 HV: estimación (lo habitual en las bandas de lija)",
	},
	## Cortaúñas. wedge_mm: apertura que la hoja impone al entrar (la cuña de la grieta que raja); crush_k: hasta dónde
	## aplasta, en radios de la garra (Saint-Venant: una perturbación se apaga en ~1 sección); jaw_mm: la garra más gruesa
	## que cabe. ESTIMACIONES de geometría (sin medición publicada): la guillotina corta con una hoja contra un anillo; la
	## de tijera aprieta con dos hojas por los dos lados y aplasta más; las tenazas de herrador, para garras grandes.
	## lever: la palanca (unidad 5l), lo que multiplica la fuerza de la mano en el filo: el brazo de la mano entre el del filo,
	## desde el eje (geometría estimada de uno de cada tipo; CLIP_FORCE.lever_source).
	"guillotina": {
		"id": "guillotina", "name": "Cortaúñas de guillotina", "kind": "cortaunas", "wedge_mm": 0.3, "crush_k": 1.0, "jaw_mm": 7.0,
		"lever": 4.0,
		"quality": "estimate", "source": SRC_SAMOUR + " (las garras crecidas se cortan mejor con un cortaúñas de guillotina); geometría estimada",
	},
	"tijera": {
		"id": "tijera", "name": "Cortaúñas de tijera", "kind": "cortaunas", "wedge_mm": 0.6, "crush_k": 2.0, "jaw_mm": 6.0,
		"lever": 3.5,
		"quality": "estimate", "source": "dos hojas que aprietan por los dos lados: más cuña y más aplastamiento (geometría estimada)",
	},
	"tenaza": {
		"id": "tenaza", "name": "Tenazas de herrador", "kind": "cortaunas", "wedge_mm": 1.0, "crush_k": 1.5, "jaw_mm": 30.0,
		"lever": 10.0,
		"quality": "estimate", "source": SRC_CATTALES + "; geometría estimada",
	},
	"hemostatico": {
		"id": "hemostatico", "name": "Polvo hemostático (subsulfato férrico)", "kind": "hemostatico", "pain": 0.0,
		"quality": "secondary", "source": SRC_MSD + "; " + SRC_DREMEL_GUIDE,
	},
	"nitrato_plata": {
		"id": "nitrato_plata", "name": "Lápiz de nitrato de plata", "kind": "hemostatico", "pain": 0.5,
		"quality": "secondary", "source": SRC_SAMOUR + "; " + SRC_COAKLEY,
	},
	"clorhexidina": {
		"id": "clorhexidina", "name": "Clorhexidina al 0,05 %", "kind": "antiseptico",
		"quality": "secondary", "source": SRC_LOZIER,
	},
	"crema": {
		"id": "crema", "name": "Crema de lanolina o parafina", "kind": "crema",
		"quality": "secondary", "source": SRC_SAMOUR + ", p. 927: recomendada después de recortar y dar forma a las garras",
	},
	"metacrilato": {
		"id": "metacrilato", "name": "Metacrilato con bicarbonato", "kind": "reparacion",
		"quality": "estimate", "source": SRC_SAMOUR + ": así se rellenan los defectos del pico, y hay que rehacerlo cada 8-12 semanas porque la queratina crece. En una garra: la misma técnica (suposición)",
	},
}

# ════════ Cómo trabaja cada herramienta según la dureza (unidad 5l, petición 38) ════════
## Lo que pasa entre la herramienta y el material de la garra además de lo que arranca: lo que se gasta la herramienta, lo que
## calienta una giratoria que roza sin morder, la fuerza que piden los cortaúñas y lo que sale de cada pasada. La física, en
## claw_care.gd (tool_wear_k, rub_mu, shear_strength_mpa, debris_for) y en claw_care_kit.gd (cómo va cada herramienta).
const SRC_PINTAUDE_2009 := "Pintaude G, Bernardes FG, Santos MM, Sinatora A, Albertin E (2009). Mild and severe wear of steels and cast irons in sliding abrasion. Wear 267:19-25 (abrasión por deslizamiento con partículas de vidrio sobre aceros y fundiciones de distinta dureza), recogido en Pintaude G (2021). Remarks on wear transitions related to hardness and size of abrasive particles. En Tribology of Machine Elements: Fundamentals and Applications, IntechOpen, doi:10.5772/intechopen.99324: con el abrasivo menos de 1,2 veces más duro que el material, desgaste suave, K = 4,5·10⁻⁵ en el más duro ensayado (706 HV); desde 1,2, severo, K ≈ 1,5·10⁻², unas 330 veces más"
const SRC_RICHARDSON := "Richardson RCD (1968). The wear of metals by relatively soft abrasives. Wear 11:245-275, doi:10.1016/0043-1648(68)90175-0 (el desgaste cae mucho cuando la superficie pasa de ~0,8 veces la dureza del abrasivo: la r = 0,8 del banco, Contact.CONTACT.rOff)"
const SRC_YIELD_ONSET := "la cesión bajo una esfera, p0 = 1,6·Y (Johnson 1985), con H = 2,8·Y (Tabor 1951), las constantes del banco (Contact.CONTACT), y el pico de presión de Hertz, 1,5 veces la media"
const SRC_BARRETT_1990 := "Barrett RT (1990). Fastener Design Manual. NASA Reference Publication 1228, tabla de coeficientes de rozamiento en seco (carburo de tungsteno sobre carburo de tungsteno, 0,2; sobre acero, 0,5; vidrio sobre vidrio, 0,94 en reposo y 0,40 deslizando)"
const SRC_FRICTION_TABLES := "tablas de rozamiento en seco de los manuales (RoyMech, «Coefficient of friction»; Engineers Edge): diamante sobre diamante 0,1 (0,05-0,1 deslizando) y sobre metal 0,1-0,15; carburo de tungsteno sobre carburo 0,2-0,25 y sobre acero 0,4-0,6; vidrio sobre metal 0,5-0,7"
## El desgaste de la herramienta: Archard con la razón de durezas al revés, ρ = H_garra/H_herramienta (lo que la garra «raya» a
## la herramienta): ΔV = K(ρ)·F·L/H_herramienta, con L todo lo que desliza (también la vuelta de una lima en vaivén y lo que
## roza sin morder). K(ρ):
##   - por debajo de onset (ρ ≈ 0,38), 0: la garra cede antes de deformar las puntas de la herramienta (su presión no pasa de
##     su dureza, y el pico de Hertz, 1,5 veces la media, no llega a la cesión de la herramienta, 1,6·H/2,8): la queratina, el
##     acrílico, el oro, el acero y el titanio no gastan una lima de acero ni el corindón en un ensayo;
##   - de onset a 0,8 (la r del banco, Richardson), sube hasta el desgaste suave medido, k_mild;
##   - de 0,8 a 2, del suave al severo (k_severe) con la misma curva del banco (Contact.hardness_efficiency).
## El volumen gastado se reparte por las aristas o los granos de la tira de la cara que pasa por el contacto (el ancho del
## contacto por face_mm) y redondea cada filo: un diente de semiángulo θ que retrocede δ pierde δ²·tan θ por mm de arista, y
## un grano, (π/3)·tan²θ·δ³; queda una plataforma de semiancho δ·tan θ, que corta como una punta redonda de radio
## δ·tan θ/cos θ (combinada con el radio de nueva, √(R0² + R²)). Ese radio entra en el arranque (element_cut): con más radio,
## cada filo penetra menos (Dp más bajo) y pasa de cortar a arar (Hokkirigawa y Kato). dull_ratio: se avisa de que está
## embotada (la lima) o vidriada (el grano) cuando su radio dobla el de nueva.
const TOOL_WEAR := {
	"k_mild": {
		"value": 4.5e-5, "quality": "secondary",
		"source": SRC_PINTAUDE_2009 + ". Medido con partículas de vidrio sobre un acero de 706 HV, ρ ≈ 0,8: el caso de la lima de acero (700 HV) contra el vidrio",
	},
	"k_severe": {
		"value": 1.5e-2, "quality": "secondary",
		"source": SRC_PINTAUDE_2009 + ". Del orden del de la abrasión a dos cuerpos (K de 5·10⁻³ a 5·10⁻²) y del disco de la radial del taller (core/taller/radial.gd, 0,0125)",
	},
	"onset": {
		"value": 1.6 / 2.8 / 1.5, "quality": "estimate",
		"source": "por debajo, la garra no deforma las puntas de la herramienta: " + SRC_YIELD_ONSET + ". Sin medición del desgaste de una herramienta contra algo mucho más blando: se desprecia (estimación)",
	},
	"dull_ratio": {
		"value": 2.0, "quality": "estimate",
		"source": "elección del aviso: con el doble de radio, el mismo filo hunde mucho menos (Contact.depth_for_radius) y pasa de cortar a arar (Hokkirigawa y Kato 1988)",
	},
}
## Rozamiento de una herramienta que roza sin morder (o casi), por la pareja de materiales: con el diamante (de herramienta o
## de garra), la del diamante; la lima de acero sobre algo más duro, la del acero sobre carburo o vidrio; el corindón sobre otra
## cerámica dura (el zafiro, el rubí, la alúmina, el carburo, la moissanita), la del carburo sobre carburo. Mientras corta, la
## del amolado (THERMAL.friction); entre las dos, según la parte que muerde (ClawCare.rub_mu).
const RUB_FRICTION := {
	"ceramica": {
		"value": 0.2, "min": 0.2, "max": 0.25, "quality": "estimate",
		"source": "sin medición del corindón contra el zafiro o la moissanita; caso medido más parecido, el par de cerámicas duras de las tablas, carburo de tungsteno sobre carburo: " + SRC_BARRETT_1990 + "; " + SRC_FRICTION_TABLES,
	},
	"diamante": {
		"value": 0.1, "min": 0.05, "max": 0.15, "quality": "secondary",
		"source": SRC_FRICTION_TABLES,
	},
	"acero": {
		"value": 0.5, "min": 0.4, "max": 0.7, "quality": "estimate",
		"source": "la lima de acero que resbala sobre una gema; caso medido más parecido, el carburo de tungsteno y el vidrio sobre acero: " + SRC_BARRETT_1990 + "; " + SRC_FRICTION_TABLES,
	},
}
## La fuerza de los cortaúñas: cortar la sección entera de la garra pide τ·A (como cizallar una barra), con τ = σ/√3 en un
## dúctil (von Mises: la tensión de flujo de un metal, H/2,8 con la dureza del banco, o la resistencia de la queratina a su
## humedad) y τ = σ en un frágil (la tensión principal: su resistencia a flexión). El cortaúñas da la fuerza de la mano por
## su palanca (TOOLS[…].lever). Si no llega, no corta.
const SRC_MATHIOWETZ := "Mathiowetz V, Kashman N, Volland G, Weber K, Dowe M, Rogers S (1985). Grip and pinch strength: normative data for adults. Arch. Phys. Med. Rehabil. 66:69-74 (dinamómetro Jamar, la mano derecha, de 20 a 24 años: 121,0 ± 20,6 lb los hombres y 70,4 ± 14,5 lb las mujeres)"
const CLIP_FORCE := {
	"hand_n": {
		"value": 538.2, "min": 313.1, "max": 538.2, "quality": "secondary",
		"source": SRC_MATHIOWETZ + ": 121,0 lb = 538 N, la mayor fuerza de apretar de media (los hombres jóvenes; las mujeres, 70,4 lb = 313 N). Se toma la mayor: si así no corta, no corta",
	},
	"lever": {
		"quality": "estimate",
		"source": "geometría estimada de uno de cada tipo, sin medición publicada que hayamos podido leer: el de guillotina, la mano a ~8 cm del eje y la hoja a ~2 cm (×4); el de tijera, ~7 y ~2 cm (×3,5); las tenazas de herrador de 14 in, los mangos a ~30 cm del eje y la boca a ~3 cm (×10)",
	},
	"shear": {
		"quality": "estimate",
		"source": "τ·A con la sección entera de la garra donde se corta (redonda, la de la física): en un dúctil, τ = σ/√3 (el criterio de von Mises), con la tensión de flujo de un metal, H/2,8 (Tabor 1951, con la dureza del banco), o la resistencia de la queratina a su humedad (" + SRC_TAYLOR + "); en un frágil, τ = σ (la tensión principal de la cortadura pura), con su resistencia a flexión (ClawFracture). Una cota alta: una hoja afilada que entra poco a poco pide algo menos",
	},
}
## Lo que sale de cada pasada (para la escena): polvo de queratina, limaduras de metal, polvo de vidrio o de cerámica y virutas
## de acrílico. El tipo sale de cómo rompe el material (ClawFracture.behavior: los dúctiles dan limaduras; los frágiles,
## polvo); el tamaño, de la hondura del surco de cada filo (el grueso de la viruta), y la cantidad, del volumen arrancado. El
## color es dibujo; el de los minerales, el de su raya (el color de su polvo), del Handbook of Mineralogy.
const SRC_STREAK := "Anthony JW, Bideaux RA, Bladh KW, Nichols MC (eds.), Handbook of Mineralogy (Mineralogical Society of America): la raya, el color del mineral en polvo: el corindón (el zafiro y el rubí) y el cuarzo, blanca; la hematites, de pardo rojiza a rojo cereza; la moissanita, gris verdosa"
const DEBRIS_KIND := {
	"polvo": "polvo",
	"limaduras": "limaduras",
	"virutas": "virutas",
}
## Color de lo que sale de cada material de garra (dibujo; donde lo hay, la raya del mineral). La queratina, el de su garra.
const DEBRIS_COLOR := {
	"oro": ["#E6C36B", "dibujo: el color del metal (las limaduras brillan como él)"],
	"acero": ["#C7CDD6", "dibujo: el color del metal"],
	"titanio": ["#B8BFC7", "dibujo: el color del metal"],
	"tungsteno": ["#6E737A", "dibujo: el polvo de carburo de tungsteno es gris oscuro"],
	"vidrio": ["#F2F6F8", "dibujo: el vidrio molido es blanco (dispersa la luz)"],
	"swarovski": ["#F2F6F8", "dibujo: el vidrio molido es blanco (dispersa la luz)"],
	"hematites": ["#8E3B2E", SRC_STREAK],
	"cuarzo": ["#F4F2F0", SRC_STREAK],
	"circonita": ["#F4F4F2", "dibujo: la circonia en polvo es blanca"],
	"zafiro": ["#F4F4F2", SRC_STREAK],
	"rubi": ["#F4F1F1", SRC_STREAK],
	"alumina": ["#F4F4F2", "dibujo: la alúmina en polvo es blanca, como el corindón (" + SRC_STREAK + ")"],
	"moissanita": ["#8F9A8C", SRC_STREAK],
	"diamante": ["#D9DCDF", "dibujo: el polvo de diamante es gris claro"],
	"acrilico": ["#E9A0A8", "dibujo: el color rosado del acrílico dental de las prótesis"],
}
## Cómo cae lo que sale (para la escena): la ley de Stokes, una partícula de diámetro d y densidad ρ frena en el aire con
## k = 18·μ/(ρ·d²) (1/s) y cae a v = g/k. Vale con el número de Reynolds pequeño: el polvo de micras de los frágiles, que flota;
## las limaduras y las virutas son láminas más largas que gruesas y caen antes (no se usa con ellas). d: el grueso de la
## viruta, la hondura del surco de cada filo.
const SRC_STOKES := "Stokes GG (1851). On the effect of the internal friction of fluids on the motion of pendulums. Trans. Cambridge Philos. Soc. 9:8-106 (la resistencia de una esfera lenta, 3π·μ·d·v; la velocidad de caída, ρ·g·d²/(18·μ))"
const AIR_VISCOSITY := {
	"value": 1.81e-5, "quality": "secondary",
	"source": "Incropera et al. (2007), tabla A.4: el aire a 1 atm, 159,6·10⁻⁷ N·s/m² a 250 K y 184,6·10⁻⁷ a 300 K; a 20 °C, 1,81·10⁻⁵ Pa·s (interpolando)",
}
## Chispas de cada material de garra que puede echarlas al tocarlo con una herramienta giratoria que lo muerde: la clave de su
## firma en core/taller/sparks.gd (el ensayo de chispas del TC 9-237 y, para el titanio y el metal duro, Kelley y
## Blickensderfer 1974). Los demás no chispean: los no metales, porque no arden, y el oro, como el cobre (sin chispas).
const SPARK_MATERIAL := { "acero": "acero", "titanio": "titanio-cp", "tungsteno": "metal-duro", "oro": "oro" }

# ════════ La superficie de la garra (petición 37, unidad 5g) ════════
## La rugosidad que deja cada pasada, el quemado y los desconchones, por estación (ClawCare.snapshot().surface; el reparto
## con la escena y el material, en CONTRATOS.md, «La cetrería en alta definición y la superficie de la garra»).
##   - ra_per_depth: Ra de un perfil de surcos en V, uno junto a otro, de hondura h: Ra = h/4 (la media de |z| de una onda
##     triangular). La hondura h es la del surco de cada grano o de cada diente suelto (ClawCare.groove_um, con la misma
##     fuerza, el mismo contacto y la misma dureza que el arranque): así la rugosidad sale de la herramienta, de la fuerza y de
##     la garra.
##   - clear_per_ra: para borrar los surcos de la herramienta de antes hay que quitar su hondura, 4·Ra (la misma onda).
##   - natural_ra_um, polished_ra_um y raw_ra_um: la superficie de partida de la garra natural, de una reforjada pulida y de
##     un bloque en bruto.
##   - burn_depth_mm: lo que hay que quitar para que desaparezca lo quemado (un nodo del modelo térmico).
const SRC_LAUBE := "Laubé F, Poupon A, Zinck P, Müller-Goymann C, Reichl S, Nardello-Rataj V (2019). Physicochemical investigations of native nails and synthetic models for a better understanding of surface adhesion of nail lacquers. Eur. J. Pharm. Sci. 131:208-217. doi:10.1016/j.ejps.2019.02.014 (perfilómetro Alfa Step IQ, tramos de 1 mm a lo largo y de través, uñas cortadas de cuatro procedencias: Ra = 308 ± 52 nm, sin diferencias según la dirección)"
const SRC_ROUGHNESS_CHART := "Oberg E et al., Machinery's Handbook (Industrial Press), tabla «Surface roughness produced by common production methods», de ANSI/ASME B46.1: lapeado 0,05-0,4 µm de Ra y superacabado 0,025-0,2 µm en la aplicación normal; fundición a la cera perdida 1,6-3,2 µm"
const SURFACE := {
	"ra_per_depth": {
		"value": 0.25, "quality": "estimate",
		"source": "Ra = h/4, la de un perfil de surcos en V de hondura h (la definición de Ra sobre una onda triangular), con la hondura del surco de cada grano o de cada diente que calcula el motor (ClawCare.groove_um). Sale del orden de lo medido, quizá por lo bajo: con lija P180, ~0,6 µm en la queratina a 4 N (y 2,5 µm con el grano 60 del torno), cuando el acero lijado queda en ~0,8-1,5 µm con P150-P240 y en ~3-5 µm con P40-P60 (Whitby Abrasives, «Grit-to-surface-finish (Ra) chart», whitbyabrasives.ca, bandas orientativas) y una uña natural, sin limar, en 0,31 µm (" + SRC_LAUBE + "); en la queratina, más blanda que el acero, cabría esperar algo más. Estimación: sin medición de garras limadas",
	},
	"clear_per_ra": {
		"value": 4.0, "quality": "estimate",
		"source": "los surcos de la herramienta de antes desaparecen cuando se ha quitado su hondura, 4·Ra en la misma onda triangular (la regla de los pulidores: cada grano más fino tiene que borrar el rayado del anterior); suposición del modelo",
	},
	"natural_ra_um": {
		"value": 0.31, "min": 0.256, "max": 0.36, "quality": "secondary",
		"source": SRC_LAUBE + ". Caso medido más parecido: la uña humana; sin medición publicada de la rugosidad de una garra",
	},
	"polished_ra_um": {
		"value": 0.05, "quality": "estimate",
		"source": "una garra reforjada se da por pulida, como una gema tallada. Caso medido más parecido: el lapeado, 0,05-0,4 µm (" + SRC_ROUGHNESS_CHART + "); se toma el extremo fino",
	},
	"raw_ra_um": {
		"value": 3.2, "quality": "estimate",
		"source": "un bloque en bruto, como sale del horno o de la colada. Caso medido más parecido: la fundición a la cera perdida, 1,6-3,2 µm (" + SRC_ROUGHNESS_CHART + "); se toma el extremo alto",
	},
	"burn_depth_mm": {
		"value": 0.1, "quality": "estimate",
		"source": "lo quemado es una capa del orden de un nodo del modelo térmico (0,1 mm): limando esa hondura aparece queratina sana (suposición del modelo)",
	},
}

# ════════ Colocar a mano la pieza de la reforja (unidad 5o, petición 43) ════════
## La pieza llega sin pegar y la coloca el usuario: preparar la garra (limpiar, secar, lijar), el adhesivo, colocarla y sujetarla
## hasta que fija, quitar lo que rebosa y probar la unión. La física, en claw_care_bond.gd; los cortantes y las holguras de los
## adhesivos son los de la reforja (ForgeData.ADHESIVES, con su fuente).
const SRC_LOCTITE_401_TDS := "Henkel, ficha técnica de LOCTITE 401 (febrero de 2012): «Bond areas should be clean and free from grease. Clean all surfaces with a Loctite cleaning solvent and allow to dry»; tiempo de fijación (0,1 N/mm², 22 °C y 50 % HR): acero < 5 s, cuero 15-30 s, tela 10-20 s; «Assemble the parts within a few seconds… the short fixture time leaves little opportunity for adjustment»; «Bonds should be held fixed or clamped until adhesive has fixtured»; plena resistencia a las 24-72 h"
const SRC_E20HP_TDS := "Henkel, ficha técnica de LOCTITE EA E-20HP (mayo de 2023): dos componentes 2:1 en volumen con la cánula mezcladora (purgar 25-50 mm antes de aplicar); vida de mezcla de 20 min a 23 °C y seca al tacto a los 40 min; la gráfica de la resistencia con el tiempo (aluminio, holgura de 0,1-0,2 mm): casi nada hasta ~3 h y casi toda a las ~6 h; «Keep assembled parts from moving during cure»"
const SRC_H8000_TDS := "Henkel, ficha técnica de LOCTITE AA H8000 (septiembre de 2022): metacrilato de dos componentes 10:1 en volumen; tiempo de trabajo, 30 min; fijación (0,1 N/mm²) en 25-30 min; a las 24 h, ≥ 19,3 N/mm² en acero (24 a las 72 h); «Keep assembled parts from moving during cure»"
const SRC_LOCTITE_GUIDE_T7 := "Henkel, The LOCTITE Design Guide for Bonding Metals, vol. 6, tabla 7 (aluminio limpiado con alcohol isopropílico, liso de 9 µin rms frente a rugoso de 68 µin rms): el epoxi E-20HP, 1670 frente a 2160 psi; el metacrilato H8000, 2630 frente a 2820; el cianoacrilato en gel 454, 366 frente a 1921"
## Los tiempos de cada adhesivo (de su ficha técnica): work_s (lo que se puede tardar en montar después de aplicarlo), fix_s
## (fijación: el tiempo hasta 0,1 N/mm²; fix_min y fix_max, la banda), full_s (plena resistencia) y mix (cómo se prepara).
##   - el cianoacrilato fija en la queratina como en el cuero, el caso medido más parecido de la ficha (estimación);
##   - el epoxi E-20HP: la fijación y la plena resistencia, leídas de su gráfica de la resistencia con el tiempo.
## La resistencia crece de la de la fijación (0,1 N/mm²) a la plena, lineal en el logaritmo del tiempo, como se dibujan las
## gráficas de las fichas (suposición del modelo).
const BOND_TIMES := {
	"cianoacrilato": {
		"work_s": 5.0, "fix_s": 20.0, "fix_min": 15.0, "fix_max": 30.0, "full_s": 86400.0, "parts": 1,
		"mix": "un componente: cura con la humedad del aire", "quality": "secondary",
		"source": SRC_LOCTITE_401_TDS + ". En la queratina, la fijación del cuero (estimación: el sustrato natural más parecido de la ficha); montar en «unos segundos»: 5 s",
	},
	"epoxi": {
		"work_s": 1200.0, "fix_s": 10800.0, "fix_min": 9000.0, "fix_max": 12600.0, "full_s": 21600.0, "parts": 2,
		"mix": "2:1 en volumen, mezclado en la cánula de la jeringa doble", "quality": "secondary",
		"source": SRC_E20HP_TDS + ". La fijación (~3 h) y la plena resistencia (~6 h), leídas de la gráfica",
	},
	"metacrilato": {
		"work_s": 1800.0, "fix_s": 1650.0, "fix_min": 1500.0, "fix_max": 1800.0, "full_s": 86400.0, "parts": 2,
		"mix": "10:1 en volumen, mezclado en la cánula de la jeringa doble", "quality": "secondary",
		"source": SRC_H8000_TDS,
	},
}
## Lo que la preparación cambia en la unión:
##   - smooth: lo que aguanta cada adhesivo sobre una superficie lisa frente a la rugosa de su cortante (los de la reforja son
##     los del aluminio rugoso de la guía de Henkel), entre ra_smooth_um y ra_rough_um (9 y 68 µin rms), interpolado en el
##     logaritmo de la rugosidad. La garra natural (0,31 µm) está casi en la lisa; lijarla un poco la acerca a la rugosa.
##   - dirty: sin limpiar ni desengrasar (estimación: las fichas piden superficies limpias y la guía ensaya tras limpiar con
##     alcohol isopropílico; el metacrilato, que «pega en superficies moderadamente contaminadas», pierde menos).
##   - mojada: la queratina mojada bajo la unión (la de la reforja, empapada, ClawForge.keratin_shear_mpa) y lo que conserva cada
##     adhesivo mojado (ForgeData.ADHESIVES.wet).
##   - alcohol_dry_s: lo que tarda en evaporarse el alcohol; gauze_dry_s, lo que hay que apretar la gasa para secar el agua de la
##     clorhexidina (estimaciones, sin medición).
const BOND_PREP := {
	"smooth": { "cianoacrilato": 366.0 / 1921.0, "epoxi": 1670.0 / 2160.0, "metacrilato": 2630.0 / 2820.0 },
	"ra_smooth_um": 0.229, "ra_rough_um": 1.73, "smooth_quality": "secondary",
	"smooth_source": SRC_LOCTITE_GUIDE_T7 + ". En la queratina, la misma relación (estimación: sin medición de uniones a garras)",
	"dirty": 0.5, "dirty_metacrilato": 0.8, "dirty_quality": "estimate",
	"dirty_source": "sin medición en garras: las fichas piden superficies limpias y sin grasa (" + SRC_LOCTITE_401_TDS + "; " + SRC_E20HP_TDS + ") y la guía de Henkel ensaya tras limpiar con alcohol isopropílico; se toma la mitad sin limpiar, y 0,8 en el metacrilato de dos componentes, que «bonds to moderately contaminated surfaces» (la misma guía)",
	"alcohol_dry_s": 30.0, "gauze_dry_s": 4.0, "dry_quality": "estimate",
	"dry_source": "el alcohol se evapora en unos segundos y la clorhexidina al 0,05 % es agua: se seca con una gasa (estimación); las fichas: «allow to dry»",
}
## La unión que queda a la vista: el escalón entre la pieza y la garra (mm) que ya no se nota, el ancho del cordón de lo que
## rebosa (mm, dibujo) y la dureza del adhesivo curado (la del acrílico de las prótesis, ~20 HV: estimación con el polímero medido
## más parecido; las fichas dan Shore D 70-80).
const BOND_JOINT := {
	"step_ok_mm": 0.1, "flash_w_mm": 1.0, "polymer": "acrilico", "quality": "estimate",
	"source": "el escalón que ya no se nota al pasar el dedo, 0,1 mm, y el cordón de 1 mm de ancho: elecciones del ensayo; el adhesivo curado se lima como el acrílico de las prótesis (" + SRC_RUBRIC + ")",
}
## Lo que se mueve la mano al sujetar sin que cuente como moverla (mm): el temblor de una mano quieta (estimación, dibujo).
const BOND_HOLD_TOL_MM := 0.3
## La masilla de epoxi con carga de acero («soldadura en frío», petición 44): un cuarto adhesivo de dos componentes, 1:1, que
## se amasa o se mezcla a mano, llena holguras, fija en horas y luego se lima. tau: cortante de la ficha (1040 psi en acero);
## gap_max y wet: sin dato en la ficha, los del epoxi de la reforja (el adhesivo medido más parecido: estimación).
const SRC_JBWELD := "J-B Weld Company, J-B Weld Original Cold-Weld Steel Reinforced Epoxy, ficha técnica: mezcla 1:1, fragua en 4-6 h y cura en 15-24 h; resistencia a tracción por cortante (lap shear) 1040 psi = 7,2 MPa en acero a 25 °C; aguanta hasta 550 °F (288 °C)"
const PUTTY := {
	"id": "masilla", "name": "Masilla de epoxi con acero («soldadura en frío»)", "tau": 7.17, "gap_ideal_min": 0.1, "gap_ideal": 0.5,
	"gap_max": 3.2, "wet": 1.0, "quality": "secondary",
	"source": SRC_JBWELD + ". Holgura y humedad: sin dato en la ficha; las del epoxi de dos componentes (estimación con el adhesivo medido más parecido)",
}
## Los tiempos de la masilla (de su ficha): fragua en 4-6 h y cura en 15-24 h; el tiempo de trabajo, sin dato en la ficha: el
## del epoxi E-20HP (estimación).
const PUTTY_TIMES := {
	"work_s": 1200.0, "fix_s": 18000.0, "fix_min": 14400.0, "fix_max": 21600.0, "full_s": 86400.0, "parts": 2,
	"mix": "1:1, amasado a mano hasta un color uniforme", "quality": "secondary",
	"source": SRC_JBWELD + ". El tiempo de trabajo, el del epoxi de dos componentes (estimación: " + SRC_E20HP_TDS + ")",
}
## Purgar la cánula mezcladora (las jeringas dobles): lo primero que sale va con la proporción mal (la ficha pide tirar 25-50
## mm). Sin purgar, el cordón aguanta purge_off (estimación: sin medición; la mitad, como un adhesivo sin limpiar la pieza).
const BOND_PURGE := {
	"purge_off": 0.5, "quality": "estimate",
	"source": "la ficha del epoxi pide purgar 25-50 mm de la cánula antes de aplicar (" + SRC_E20HP_TDS + "); lo que aguanta un cordón sin purgar no está medido: se toma la mitad (estimación)",
}
## Colocar la pieza: el error de alineación que se tolera (mm del centro del muñón y grados del eje de la garra) y lo torcida
## que llega la pieza a la mano (grados): elecciones del ensayo, sin medición. Lo que aguanta una pieza torcida no se calcula: se
## quita y se vuelve a colocar.
const BOND_ALIGN := {
	"offset_mm": 0.5, "tilt_deg": 5.0, "start_tilt_deg": 14.0, "quality": "estimate",
	"source": "tolerancias de colocación: elección del ensayo (" + SRC_RUBRIC + "); una funda o una prótesis torcida se nota a simple vista y cambia la punta de sitio",
}
## Sujetar con venda o cinta (las colas lentas): una vez colocada y quieta, una venda autoadherente la sujeta el tiempo que haga
## falta, como se sujetan las piezas mientras fija el adhesivo («Bonds should be held fixed or clamped until adhesive has
## fixtured»). wrap_s: lo que se tarda en vendar con una mano mientras la otra sujeta (estimación).
const BOND_WRAP := {
	"wrap_s": 15.0, "quality": "estimate",
	"source": SRC_LOCTITE_401_TDS + "; " + SRC_H8000_TDS + ". El vendaje, como se sujetan las piezas pegadas o el apósito de la garra rota (" + SRC_SAMOUR + ", p. 925); el tiempo de vendar, estimación",
}
## La prueba de la unión: un tirón suave de lado con la mitad del agarre de la garra en el banco (claw.force). Elección del
## ensayo: la unión tiene que aguantar lo que la garra hará después; la mitad, para no romper una buena.
const BOND_TEST := {
	"force_frac": 0.5, "quality": "estimate",
	"source": "el tirón suave de lado, la mitad del agarre de la garra del banco (la fuerza de su ficha): elección del ensayo (" + SRC_RUBRIC + ")",
}
## Quitar lo que rebosa: el cordón que sale al apretar la pieza (overfill, la parte de más que se pone sobre el volumen de la
## holgura, para que no queden huecos; min_mm3, el cordón más pequeño que se pone) y lo que quita una pasada de la espátula en
## fresco (scrape). clean_mm3: lo que ya no se ve. Estimaciones: sin medición.
const BOND_FLASH := {
	"overfill": 0.5, "scrape": 0.7, "clean_mm3": 0.02, "min_mm3": 0.3, "quality": "estimate",
	"source": "se pone algo de más para que no queden huecos y lo que sobra rebosa al apretar; cuánto, y lo que se lleva cada pasada de la espátula en fresco, sin medición (estimación); lo que queda por debajo de 0,02 mm³ ya no se ve",
}

## El acrílico dental autopolimerizable (la prótesis de verdad de la 5j), a mano: polvo y líquido en su proporción, la fase de
## masa (filamentosa) en la que se aplica y se modela con la espátula, el tiempo de trabajo y el fraguado.
##   - ratio_w: polvo:líquido en peso (2:1; en volumen, 3:1); mix_s: lo que se mezcla; dough_s: desde la mezcla hasta la masa
##     (estimación: la ficha no da cifra y dice «hasta la fase filamentosa»); work_s: el final del tiempo de trabajo desde la
##     mezcla (la ficha: 3-5 min a 23 °C); set_s: el fraguado (~10 min de media).
##   - full_s: plena resistencia (estimación: un día, como el metacrilato de dos componentes de la reforja).
const SRC_VERACRIL := "Veracril (New Stetic), resina acrílica autopolimerizable para reparar prótesis dentales, instrucciones de uso: en peso, 2 partes de polímero y 1 de monómero; en volumen, 3:1; mezclar en cruz unos 30 s y tapar hasta la fase filamentosa; tiempo de trabajo de 3 a 5 min a 23 ± 2 °C; autopolimeriza en unos 10 min de media, según la temperatura"
const ACRYLIC_MIX := {
	"ratio_w": 2.0, "ratio_vol": 3.0, "mix_s": 30.0, "dough_s": 90.0, "work_s": 330.0, "set_s": 600.0, "full_s": 86400.0,
	"ratios": [1.5, 2.0, 2.5], "quality": "secondary",
	"source": SRC_VERACRIL + ". La masa, hacia el minuto y medio desde que se empieza a mezclar (estimación: la ficha no da cifra); la plena resistencia, en un día (estimación con el metacrilato de dos componentes)",
}
## La proporción: con más líquido hay más monómero (más calor y más encogimiento, y queda más blando); con más polvo la masa
## sale grumosa. off_ratio: lo que aguanta por cada 0,5 de diferencia con la de la ficha (estimación, sin medición).
const ACRYLIC_RATIO := {
	"off_ratio": 0.8, "quality": "estimate",
	"source": "la proporción de la ficha (" + SRC_VERACRIL + "); lo que pierde fuera de ella no está medido: un 20 % por cada media parte de diferencia (estimación)",
}
## El calor del fraguado: la polimerización del metacrilato de metilo desprende 56 kJ/mol (Odian), 100,12 g/mol; el monómero es
## 1/(1 + proporción) de la masa y reacciona casi todo (queda un 3-5 % sin reaccionar en los autopolimerizables: Alqutaibi et al.
## 2023, el dato de la reforja). El calor sale con la reacción, que se acelera al final (efecto Trommsdorff): se reparte como un
## triángulo desde la mezcla hasta el fraguado, con el pico en peak_frac del fraguado (estimación con la forma de las curvas de
## temperatura del fraguado del cemento óseo, que es el mismo PMMA autopolimerizable).
const SRC_ODIAN := "Odian G (2004). Principles of Polymerization, 4.ª ed., Wiley, tabla 3-14: calor de polimerización del metacrilato de metilo, −ΔH = 56 kJ/mol"
const SRC_ISO5833 := "ISO 5833:2002, implantes para cirugía, cementos de resina acrílica: el fraguado se mide con la curva de temperatura de una masa en un molde (el pico llega al final, con la autoaceleración)"
const ACRYLIC_HEAT := {
	"dh_j_mol": 56000.0, "molar_kg": 0.10012, "residual": 0.04, "peak_frac": 0.8, "density": 1180.0, "quality": "secondary",
	"source": SRC_ODIAN + "; el monómero que queda, 3-5 % (se toma el 4 %, el dato de Alqutaibi et al. 2023 de la reforja); la forma del calor con el tiempo, un triángulo con el pico al 80 % del fraguado (estimación con " + SRC_ISO5833 + ")",
}
## Las capas del acrílico y de la resina (mm de alto a lo largo de la garra): fina y gruesa.
const LAYER_MM := { "fina": 1.0, "gruesa": 3.0, "quality": "estimate", "source": "capas de 1 y 3 mm: elección del ensayo; las fichas de los composites piden capas de menos de 2,5 mm" }

## La resina compuesta fotopolimerizable (lo que Eric llama «acrílico con UV LED»): la de las restauraciones dentales, que se
## pone en capas finas y se cura con la lámpara azul. Material del bloque en la cetrería (como el acrílico): dureza, módulo,
## densidad, resistencia y tenacidad.
const SRC_Z250 := "3M ESPE, Filtek Z250 Universal Restorative, Technical Product Profile: resistencia a flexión 155 MPa y módulo a flexión 11,0 GPa; capas de menos de 2,5 mm, cada una 20 s con la lámpara"
const SRC_RUEGGEBERG_1994 := "Rueggeberg FA, Caughman WF, Curtis JW (1994). Effect of light intensity and exposure duration on cure of resin composite. Oper. Dent. 19:26-32: con menos de 400 mW/cm² o menos tiempo, la capa queda poco curada por debajo; recomienda capas de 1-2 mm"
const SRC_PRICE_2015 := "Price RB, Ferracane JL, Shortall AC (2015). Light-curing units: a review of what we need to know. J. Dent. Res. 94:1179-1186, doi:10.1177/0022034515594786: la dosis es la irradiancia por el tiempo (J/cm²); la irradiancia cae al alejar la punta de la lámpara; la luz azul intensa daña la retina y no se mira (filtro naranja)"
const SRC_RUEGGEBERG_2011 := "Rueggeberg FA (2011). State-of-the-art: dental photocuring — a review. Dent. Mater. 27:39-52, doi:10.1016/j.dental.2010.10.021: la canforquinona, el fotoiniciador de casi todos los composites, absorbe de ~400 a 500 nm con el pico en 468 nm; las lámparas LED azules de dentista emiten ahí"
const RESIN := {
	"id": "resina", "name": "Resina compuesta fotopolimerizable", "short": "Resina", "hv": 80.0, "E": 11.0, "col": "#EDE6D6",
	"density": 2000.0, "strength_mpa": 155.0, "strength_min": 80.0, "strength_max": 155.0, "kic": 1.3,
	"quality": "secondary", "hv_quality": "estimate", "real": true,
	"use": "Así se reparan de verdad los picos y las uñas rotas con resina: capas finas de composite, cada una curada con la lámpara azul, y se lima ya dura. En una garra, la misma técnica (estimación).",
	"source": SRC_Z250 + "; la norma pide al menos 80 MPa a flexión (ISO 4049); dureza ~80 HV, densidad ~2 g/cm³ y tenacidad ~1,3 MPa·√m: estimaciones con los composites de restauración medidos. El color es dibujo",
}
## Las dos lámparas: la azul de dentista (la realista: emite donde absorbe la canforquinona) y la UV de los geles de uñas (365-405
## nm: la canforquinona apenas absorbe ahí; eff, la parte de su luz que cura el composite: estimación). irradiance: mW/cm² en la
## punta; beep_s: el pitido de la lámpara (diseño de sonido, como las de dentista).
const SRC_ELIPAR := "3M, Elipar S10 LED Curing Light, ficha técnica: 430-480 nm, 1200 mW/cm² (−10 %/+20 %); se programa en intervalos de 5 a 20 s con una señal acústica"
const SRC_NAIL_LAMP := "Lámparas de uñas de gel de UV y LED (36-48 W, 365 y 405 nm): la irradiancia de UVA medida a la altura de la mano va de unos pocos a ~20 mW/cm² (Shipp LR, Warner CA, Rueggeberg FA, Davis LS (2014). Further investigation of the risk of skin cancer from nail lamps. JAMA Dermatol. 150:775-776)"
const LAMPS := {
	"azul": { "id": "azul", "name": "Lámpara LED azul de dentista (430-480 nm)", "nm": [430.0, 480.0], "irradiance": 1200.0, "eff": 1.0, "beep_s": 10.0,
		"quality": "secondary", "source": SRC_ELIPAR + "; " + SRC_RUEGGEBERG_2011 },
	"uv": { "id": "uv", "name": "Lámpara UV de uñas de gel (365-405 nm)", "nm": [365.0, 405.0], "irradiance": 10.0, "eff": 0.1, "beep_s": 10.0,
		"quality": "estimate", "source": SRC_NAIL_LAMP + "; la canforquinona apenas absorbe por debajo de 400 nm (" + SRC_RUEGGEBERG_2011 + "): se toma que cura con el 10 % de su luz (estimación)" },
}
## La profundidad de curado: Cd = Dp·ln(E/Ec), con E la dosis (J/cm²) en la cara de la capa (la ley de Jacobs de la
## fotopolimerización, y la reciprocidad de la dosis de Price 2015). Anclada en la ficha: 2,5 mm con 20 s a 400 mW/cm² (8 J/cm²);
## Dp, 1 mm (estimación: la luz cae a 1/e en cada mm de composite, del orden de lo medido). La irradiancia cae con la distancia
## como (R/(R + d·tan θ))² (un haz que se abre: R, el radio de la punta, 5 mm; θ, 12°: estimación). La norma ISO 4049 pide al
## menos 1,5 mm de profundidad de curado. times: los intervalos de la lámpara (s); distances: las distancias que se eligen (mm).
const CURE_DEPTH := {
	"ref_mm": 2.5, "ref_j_cm2": 8.0, "dp_mm": 1.0, "tip_r_mm": 5.0, "spread_deg": 12.0, "iso_min_mm": 1.5,
	"times": [5.0, 10.0, 20.0, 40.0], "distances": [1.0, 5.0, 10.0, 20.0], "quality": "estimate",
	"source": SRC_Z250 + "; " + SRC_RUEGGEBERG_1994 + "; " + SRC_PRICE_2015 + ". La ley de Jacobs (Cd = Dp·ln(E/Ec); Jacobs PF (1992), Rapid Prototyping & Manufacturing, SME) con Dp = 1 mm y la caída con la distancia: estimaciones; la norma: ISO 4049:2019 (al menos 1,5 mm)",
}

## La soldadura sobre la garra (petición 44): no se puede, y el programa lo explica con sus números sin hacérselo al animal.
##   - el arco del TIG salta entre el electrodo de tungsteno y la pieza conectada a masa: la queratina seca es un aislante;
##   - el baño de soldadura está a la temperatura de fusión del metal (las de la reforja) y la queratina se quema a ~230 °C;
##   - la queratina no se funde ni se mezcla con el metal: no hay soldadura posible.
## contact_s: el tiempo con el baño tocando que se calcula (un segundo).
const SRC_KERATIN_INSULATOR := "la queratina seca es un aislante eléctrico: la resistividad de las fibras de lana secas pasa de 10¹⁰ Ω·m (Hearle JWS (1953). The electrical resistance of textile materials. J. Text. Inst. 44; caso medido más parecido a la garra); en el TIG el arco salta entre el electrodo y la pieza conectada a masa"
const WELD := {
	"contact_s": 1.0, "quality": "secondary",
	"source": SRC_KERATIN_INSULATOR + ". El calor: un sólido semiinfinito con la cara a la temperatura del baño (" + SRC_CARSLAW + ")",
}

# ════════ Hemostasia ════════
## Segundos de presión hasta que para de sangrar: sin nada, 5-10 min (VCA); con un hemostático, en segundos (se toma
## 30 s, estimación pedagógica). Sin presión ni hemostático, se toma el extremo alto (10 min).
const HEMOSTASIS := {
	"pressure_s": { "value": 300.0, "min": 300.0, "max": 600.0, "quality": "secondary", "source": SRC_VCA },
	"agent_s": { "value": 30.0, "quality": "estimate", "source": "con hemostático y presión para en segundos (" + SRC_DREMEL_GUIDE + "); 30 s: estimación pedagógica" },
	"none_s": { "value": 600.0, "quality": "secondary", "source": SRC_VCA + " (el extremo alto)" },
}

# ════════ El estado del animal: estrés, sangre y calor (petición 51, Eric: «un medidor de estrés o peligro del animal… no
# quiero algo hardcore, solo algo que sea educativo») ════════
## La sangre del animal y lo que puede perder. volume_frac: el volumen de sangre, fracción de la masa del cuerpo (la masa, de
## care_anatomy.gd); safe_frac: lo que puede perder sin peligro (el aviso), danger_frac (peligro) y stop_frac (la sesión se para),
## fracciones de ese volumen; bleed_ml_s: lo que sale de una garra cortada hasta la carne viva mientras sangra.
const SRC_LAFEBER_BLOOD := "Pollock C, Powers L (2007, revisado en 2015). Venipuncture in birds. LafeberVet: «Up to 10% of blood volume (or 1% of total body weight in grams) can be safely drawn from healthy birds»; a las aves graves o anémicas, no más del 0,5 % del peso"
const SRC_MSD_BLOOD := "Blois S (2024). Blood transfusions in dogs and cats. MSD Veterinary Manual: el volumen de sangre, 40-60 mL/kg en los gatos y 80-90 mL/kg en los perros"
const SRC_RUDLOFF := "Rudloff E (2002). Resuscitation from hypovolemic shock. WSAVA 2002 Congress (VIN): «Once 40% of the intravascular volume is lost, the neuroendocrine responses to hypovolemia become ineffective and irreversible organ failure begins»"
const BLOOD := {
	"volume_frac": {
		"rapaz": { "value": 0.10, "quality": "secondary", "source": SRC_LAFEBER_BLOOD + " (el 10 % del volumen es el 1 % del peso: el volumen, ~10 % del peso)" },
		"velociraptor": { "value": 0.10, "quality": "estimate", "source": "el de las aves, sus parientes vivos (" + SRC_LAFEBER_BLOOD + "): estimación con el caso medido más parecido" },
		"tigre": { "value": 0.05, "quality": "estimate", "source": "el del gato, 40-60 mL/kg (" + SRC_MSD_BLOOD + "): estimación con el felino medido más parecido" },
		"oso": { "value": 0.085, "quality": "estimate", "source": "el del perro, 80-90 mL/kg (" + SRC_MSD_BLOOD + "): estimación con el carnívoro medido más parecido" },
	},
	"safe_frac": 0.10, "safe_quality": "secondary", "safe_source": SRC_LAFEBER_BLOOD,
	"danger_frac": 0.20, "stop_frac": 0.30, "stop_quality": "estimate",
	"stop_source": "con el 40 % del volumen perdido el daño ya es irreversible (" + SRC_RUDLOFF + "): la sesión se para antes, al 30 %, y avisa del peligro al 20 % (estimaciones con margen, sin medición en garras)",
	"bleed_ml_s": 0.05, "bleed_quality": "estimate",
	"bleed_source": "una garra cortada hasta la carne viva sangra gota a gota: una gota de ~0,05 mL (20 gotas por mL, la de los goteros) cada segundo (estimación, sin medición del sangrado de una garra)",
}
## Los límites del estrés del animal (el índice pedagógico de claw_care_patient.gd, de 0 a 1): inquieto, estresado y peligro;
## move_stop: las veces que puede moverse de dolor antes de soltarse. La sesión se para (el animal se suelta o ataca) si se
## mueve move_stop veces, si a un animal grande sin sedar se le tocan las garras otra vez después del aviso, o si una rapaz sin
## sujetar llega al estrés máximo; con la sujeción que pide su especie, el estrés del tiempo sujeto solo avisa. Elecciones del
## ensayo (generosas: hay un aviso antes de cada consecuencia), no mediciones.
const ANIMAL_RISK := {
	"restless": 0.4, "stressed": 0.7, "danger": 0.9, "move_stop": 3, "big_touch_stop": 2, "quality": "estimate",
	"source": "índice pedagógico del simulador, sin medición: una rapaz se sujeta encapuchada y envuelta en una toalla, y sin sujetar puede «clavar» al que la maneja (" + SRC_SAMOUR + ", pp. 916-917); a un tigre o a un oso solo se le tocan las garras sedado a fondo o anestesiado (" + SRC_CATTALES + "; " + SRC_ANIMALS_ASIA + ")",
}
## Un toque del torno o de la amoladora: «unos segundos cada vez, con pausas» (la guía de Dremel); se toman 3 s por toque para la
## cuenta de la pantalla (estimación con esa guía).
const ROTARY_TOUCH := { "value": 3.0, "quality": "estimate", "source": SRC_DREMEL_GUIDE + ". 3 s por toque: estimación con esa guía" }

# ════════ Rúbrica del informe (pedagógica) ════════
const RUBRIC := {
	"sin_anestesia": 10.0,  # tigre, oso o velocirraptor sin sedación ni anestesia: nota 0 (seguridad)
	"sin_sujecion": 3.0,
	"sangra": 3.0,
	"rota": 5.0,
	"sin_reconstruir": 1.0,
	"grieta": 2.0,
	"deshojada": 1.5,
	"mellada": 1.0,
	"calor_dolor": 1.5,
	"calor_lesion": 3.0,
	"se_mueve": 1.0,
	"sin_hemostasia": 2.0,
	"sin_desinfectar": 1.0,
	"sin_crema": 0.5,
	"largo": 2.0,  # × fracción del crecimiento que queda
	"corta": 1.5,
	"daga": 1.5,
	"roma": 1.5,
	"curva": 1.0,
	"lima_no_muerde": 1.0,
}
## Márgenes pedagógicos: lo que queda del crecimiento de más (fracción) para darla por «a su largo»; la banda del radio de la
## punta frente a la natural (×0,5 a ×2: afilada a la mitad aguanta la cuarta parte de lado, y con el doble hace falta ~4
## veces más fuerza para pinchar la piel, que crece con el área, Davis 2004); y cuánto se puede apartar el ángulo de la
## faceta del de la garra (grados).
const MARGINS := {
	"overgrowth_left": 0.1, "tip_ratio_lo": 0.5, "tip_ratio_hi": 2.0, "facet_deg": 10.0,
	"source": SRC_RUBRIC + "; " + ClawSharpness.SRC_PATTRICK + "; " + ClawSharpness.SRC_DAVIS,
}


# ════════ La punta al empezar (petición de Eric en la 5s: «más afilado, extremadamente puntiagudas y romas») ════════
## El estado de la punta con el que empieza la garra (ClawCare: setup.tip_start). natural: la de la ficha (no cambia nada).
## Las demás, con las bandas del medidor de la punta (MARGINS: ×0,5-×2; la aguja, por debajo de ¼ del aguante de lado):
##   - ratio: el radio de la punta frente al natural;
##   - alpha_k: el semiángulo de la punta frente al natural (más fina: un cono más estrecho cerca de la punta);
##   - needle_frac: el largo de ese cono más estrecho, en fracción del largo natural de la garra.
## La roma es la natural gastada: la misma curva con la punta redondeada (una esfera de ratio·R tangente al cono) y más corta;
## la afilada y la aguja, la punta más larga y estrecha hasta juntarse con la natural. Son experimento del banco: sin medición
## de cuánto se gasta o se afila una garra en la vida del animal (estimate).
const SRC_LDWF_HOUSING := "Louisiana Department of Wildlife and Fisheries, «Raptor Housing Information» (falconry): «avoid any substrate that might dull the hawk's talons» (el suelo y las posaderas gastan y embotan las garras)"
const TIP_STARTS := {
	"roma": {
		"name": "Roma", "ratio": 6.0, "alpha_k": 1.0, "needle_frac": 0.0, "quality": "estimate",
		"source": "una garra gastada (en cautividad, el suelo y las posaderas la embotan: " + SRC_LDWF_HOUSING + "); el radio, ×6 el natural, dentro de la banda «roma» del medidor (más de ×2: " + SRC_RUBRIC + "): estimación",
	},
	"natural": {
		"name": "Natural", "ratio": 1.0, "alpha_k": 1.0, "needle_frac": 0.0, "quality": "primary",
		"source": "la punta de la ficha de la garra (su área y su semiángulo: Data.CLAWS)",
	},
	"afilada": {
		"name": "Afilada", "ratio": 0.75, "alpha_k": 0.9, "needle_frac": 0.1, "quality": "estimate",
		"source": "una garra afilada, más fina que la natural sin pasar a aguja (la banda «afilada» del medidor, entre ×0,5 y ×1, y más de ¼ del aguante de lado: " + SRC_RUBRIC + "; " + ClawSharpness.SRC_PATTRICK + "): estimación",
	},
	"aguja": {
		"name": "Aguja", "ratio": 0.1, "alpha_k": 0.6, "needle_frac": 0.15, "quality": "estimate",
		"source": "extremadamente puntiaguda: el radio de los filos de la lima (~10 µm en el águila, lo que deja el motor al limar), con la punta larga y estrecha; aguanta de lado mucho menos de ¼ de la natural (la carga de rotura crece con R²: " + ClawSharpness.SRC_PATTRICK + "): se mella enseguida. Estimación",
	},
}
const TIP_START_IDS := ["roma", "natural", "afilada", "aguja"]


# ════════ La garra rota de serie (unidad 5v: «animales que lleguen con las garras rotas de serie») ════════
## Cómo llega rota una garra (ClawCare: setup.broken_start). La física de la rotura es la de siempre (_break_off: el trozo se
## va y, si pasa de la carne viva, sangra); aquí solo dónde se ha partido:
##   - fresca: partida hace un momento por dentro de la carne viva (into_quick_frac del largo natural antes de su final):
##     sangra y deja la carne viva al aire;
##   - muñon: partida hace días un poco por delante de la carne viva (beyond_quick_mm): ya no sangra, pero falta la punta.
const BROKEN_STARTS := {
	"fresca": {
		"name": "recién partida, con la carne viva al aire", "into_quick_frac": 0.08, "quality": "estimate",
		"source": SRC_SAMOUR + ", p. 925: una garra arrancada o partida deja la carne viva al aire y sangra; hay que parar la sangre, limpiar, proteger y, si hace falta, reconstruirla. Dónde se parte: estimación",
	},
	"muñon": {
		"name": "un muñón de una rotura de hace días", "beyond_quick_mm": 0.6, "quality": "estimate",
		"source": SRC_SAMOUR + ", p. 925: la garra rota tarda de 2 a 3 meses en rehacerse; mientras, se protege o se reconstruye. Dónde se partió: estimación",
	},
}


# ════════ Funciones de acceso ════════

## La entrada de un animal (copia) o {} si no existe.
static func animal(id: String) -> Dictionary:
	return (ANIMALS.get(id, {}) as Dictionary).duplicate(true)


## La garra del banco de un animal (la de su ficha, con las correcciones de la 2.0 para las rapaces), o {} si no existe.
static func claw_entry(claw_id: String) -> Dictionary:
	if claw_id == "velociraptor":
		return Velociraptor.ENTRY.duplicate(true)
	var c: Variant = Data.find_by_id(Data.CLAWS, claw_id)
	if c == null:
		return {}
	return ClawsV2.apply(c)


## La forma de la garra de un dedo (CLAW_SHAPES), resuelta: { claw, digit, refDigit, hind, lengthRatio, baseRatio, arcDeg,
## arcInnerDeg, sectionRatio, ventralFlat, quality, source, sectionQuality, sectionSource, growthRatio, growthQuality,
## growthSource }. Un dedo que no tiene, el de
## referencia (la garra de la ficha del banco); hind: la pata trasera (tigre y oso; los demás no la distinguen). quality,
## la más floja de las que entran.
static func claw_shape(claw_id: String, digit: String = "", hind: bool = false) -> Dictionary:
	var entry: Dictionary = CLAW_SHAPES.get(claw_id, {})
	if entry.is_empty():
		var ce := claw_entry(claw_id)
		return {
			"claw": claw_id, "digit": digit, "refDigit": digit, "hind": false, "lengthRatio": 1.0, "baseRatio": 1.0,
			"arcDeg": 35.0 + 115.0 * float(ce.get("curve", 0.5)), "arcInnerDeg": null, "sectionRatio": 1.0, "ventralFlat": false,
			"quality": "estimate", "source": "sin forma propia: la de la garra del banco y el arco de su dibujo",
			"sectionQuality": "estimate", "sectionSource": "sin medición: redonda, como la física",
		}.merged(_growth_of({}, false))
	var digits: Dictionary = entry.digits
	var d := digit if digits.has(digit) else String(entry.ref_digit)
	var dd: Dictionary = digits[d]
	var lr := float(dd.length_ratio)
	var br := float(dd.base_ratio)
	var arc := float(dd.arc_deg)
	var arc_in: Variant = dd.arc_inner_deg
	var quality := String(entry.quality)
	var source := String(entry.source)
	var back := hind and entry.has("hind")
	if back:
		var h: Dictionary = entry.hind
		lr *= float(h.length_ratio)
		br *= float(h.base_ratio)
		arc *= float(h.arc_ratio)
		if arc_in != null:
			arc_in = float(arc_in) * float(h.arc_ratio)
		quality = _weaker(quality, String(h.quality))
		source += "; patas traseras: " + String(h.source)
	var sec: Dictionary = entry.section_ratio
	var ven: Dictionary = entry.ventral_flat
	return {
		"claw": claw_id, "digit": d, "refDigit": String(entry.ref_digit), "hind": back, "lengthRatio": lr, "baseRatio": br,
		"arcDeg": arc, "arcInnerDeg": arc_in, "arcMethod": String(entry.get("arc_method", "exterior")),
		"sectionRatio": float(sec.value), "ventralFlat": bool(ven.value),
		"quality": quality, "source": source, "sectionQuality": String(sec.quality),
		"sectionSource": String(sec.source) + " · cara de abajo: " + String(ven.source),
	}.merged(_growth_of(entry, back))


## (última vuelta de la 5s) Lo que crece esta garra frente a lo que dice la ficha del animal (growth_mm_day): la de las
## patas traseras del tigre, con lo medido en el gato; las demás, sin medición dedo a dedo ni pata a pata: lo mismo.
## → { growthRatio, growthQuality, growthSource }.
static func _growth_of(entry: Dictionary, back: bool) -> Dictionary:
	var h: Dictionary = entry.get("hind", {}) if back else {}
	if h.has("growth_ratio"):
		return { "growthRatio": float(h.growth_ratio), "growthQuality": String(h.growth_quality), "growthSource": String(h.growth_source) }
	return { "growthRatio": 1.0, "growthQuality": "estimate",
		"growthSource": "sin medición dedo a dedo ni pata a pata: todas las garras crecen lo de la ficha del animal (growth_mm_day)" }


## El arco de la garra claw_id del banco (Catalog.CLAWS) o de la de un dedo (lo pidió la 5e: una sola fuente para el dibujo
## de la cetrería, de la galería y del coche). { claw, digit, arcDeg (el ángulo del arco: lo que gira la garra de la base a
## la punta), arcInnerDeg (el de la curva de dentro, o null), method («exterior»: Pike y Maitland 2004; «interior»:
## Feduccia 1993; «dibujo»), lengthMm (el largo de la línea media: el alcance del banco por el del dedo), radiusMm (el radio
## del arco: lengthMm entre el ángulo en radianes; INF si es recta), quality, source }. Las de la cetrería, dedo a dedo
## (CLAW_SHAPES; sin dedo, la de referencia); las demás garras de animales, CLAW_ARCS; lo que no es la garra de un animal
## (uñas de salón, garras de experimento, colmillos, aguijones), el arco de su dibujo (35° + 115°·curve), «dibujo».
static func claw_arc(claw_id: String, digit: String = "", hind: bool = false) -> Dictionary:
	var ce := claw_entry(claw_id)
	if ce.is_empty():
		var v2: Variant = _catalog_claw(claw_id)
		ce = v2 if v2 is Dictionary else {}
	var reach := float(ce.get("reach", 0.0))
	var out := { "claw": claw_id, "digit": digit, "arcDeg": 0.0, "arcInnerDeg": null, "method": "dibujo", "lengthMm": reach,
		"radiusMm": INF, "quality": "dibujo", "source": "" }
	if CLAW_SHAPES.has(claw_id):
		var sh := claw_shape(claw_id, digit, hind)
		out.merge({ "digit": String(sh.digit), "arcDeg": float(sh.arcDeg), "arcInnerDeg": sh.arcInnerDeg,
			"method": String((CLAW_SHAPES[claw_id] as Dictionary).get("arc_method", "exterior")),
			"lengthMm": reach * float(sh.lengthRatio), "quality": String(sh.quality), "source": String(sh.source) }, true)
	elif CLAW_ARCS.has(claw_id):
		var a: Dictionary = CLAW_ARCS[claw_id]
		out.merge({ "arcDeg": float(a.arc_deg), "method": "exterior", "quality": String(a.quality), "source": String(a.source) }, true)
	else:
		out.merge({ "arcDeg": 35.0 + 115.0 * float(ce.get("curve", 0.5)),
			"source": "no es la garra de un animal medida: el arco del dibujo del banco (35° + 115°·curva), solo para dibujar" }, true)
	var rad := float(out.arcDeg) * PI / 180.0
	out["radiusMm"] = float(out.lengthMm) / rad if rad > 0.0 and float(out.lengthMm) > 0.0 else INF
	return out


## Una garra del catálogo 2.0 que no está en Data.CLAWS (los aguijones y el velocirraptor de película), o null. Sin
## precargar Catalog (que, por la reforja, precarga este archivo): las mismas listas que Catalog.V2_CLAWS.
static func _catalog_claw(claw_id: String) -> Variant:
	for e: Dictionary in Insects.STINGERS + [VelociraptorFilm.ENTRY]:
		if String(e.get("id", "")) == claw_id:
			return e
	return null


## La más floja de dos calidades de dato (primary > secondary > estimate).
static func _weaker(a: String, b: String) -> String:
	var order := ["primary", "secondary", "estimate"]
	return a if order.find(a) >= order.find(b) else b


## Una herramienta (copia) o {} si no existe.
static func tool(id: String) -> Dictionary:
	return (TOOLS.get(id, {}) as Dictionary).duplicate(true)


## La queratina en un estado de humedad (copia); un estado desconocido da el natural.
static func keratin(humidity: String) -> Dictionary:
	return (KERATIN.get(humidity, KERATIN["natural"]) as Dictionary).duplicate(true)
