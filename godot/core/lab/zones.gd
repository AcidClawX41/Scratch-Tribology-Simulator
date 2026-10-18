## Tribología biológica · zonas del cuerpo (modelo 2.0; en la 1.x solo existe el brazo).
##
## Cada zona da su pila de capas de piel con el MISMO esquema que Data.SKIN_LAYERS ({ id, name, short, from, to, jT,
## jC, E, col, note }, profundidades acumuladas en µm), así que las funciones de piel de physics.gd
## (skin_layer_at, skin_tear_depth) y los aguijones (Sting.puncture_force, Sting.skin_sting) la usan tal cual. Cada
## capa lleva además `source` y `quality` ("primary" | "secondary" | "estimate") de su ESPESOR: las propiedades del
## tejido (jT, jC, E) son las de la 1.x (docs/FISICA.md, apartado 7), las mismas en todas las zonas.
##
## Debajo de las partes blandas hay hueso (`bone`: dónde empieza, su cortical, su dureza Vickers y su tenacidad) o, en
## el abdomen, la cavidad abdominal (una capa más, «cavidad», que no se acaba). La zona por defecto, el brazo,
## reproduce las capas de la 1.x; lo nuevo es que el músculo acaba en el húmero.
##
## Modelo, fuentes, estimaciones y guía de integración: docs/fisica/pulido-biologia.md. Física: penetration.gd.
## Unidades: espesores y profundidades en µm · E del tejido en kPa · dureza del hueso en HV · E del hueso en GPa ·
## tenacidades en kJ/m² (= N/mm), salvo la de iniciación de la grieta del hueso (kInit), en MPa·m^½. Funciones puras y
## deterministas; sin estado.
## Uso: const Zones = preload("res://core/lab/zones.gd"), y después Zones.stack("palma"), Zones.bone("palma")…
extends RefCounted

const V8 = preload("res://core/shared/v8_math.gd")
const Data = preload("res://core/lab/data.gd")

## Zona por defecto: la de la 1.x (cara posterior del brazo).
const DEFAULT_ID := "brazo"

# ── Fuentes (texto de la cita) ──
const SRC_SANDBY_2003 := "Sandby-Møller J, Poulsen T, Wulf HC (2003). Epidermal thickness at different body sites: relationship to age, gender, pigmentation, blood content, skin type and smoking habits. Acta Derm. Venereol. 83:410-413 (biopsias, 71 adultos: capa córnea 18,3 ± 4,9 µm y epidermis viva 56,6 ± 11,5 µm en el dorso del antebrazo). doi:10.1080/00015550310015419"
const SRC_EGAWA_2007 := "Egawa M, Hirao T, Takahashi M (2007). In vivo estimation of stratum corneum thickness from water concentration profiles obtained with Raman spectroscopy. Acta Derm. Venereol. 87:4-8, tabla I (capa córnea: mejilla 16,8 ± 2,8; brazo 21,8 ± 3,6; antebrazo 22,6 ± 4,3; dorso de la mano 29,3 ± 6,8; palma, en la eminencia tenar, 173,0 ± 37,0 µm). doi:10.2340/00015555-0183"
const SRC_ROBERTSON_2010 := "Robertson K, Rees JL (2010). Variation in epidermal morphology in human skin at different body sites as measured by reflectance confocal microscopy. Acta Derm. Venereol. 90:368-373, tabla II (10 zonas, 39 adultos: el espesor de la epidermis apenas cambia entre zonas, 55,6-62,5 µm; el abdomen, 61,3 µm, como la cara interna del brazo, 58,2). doi:10.2340/00015555-0875"
const SRC_BAUMANN_2024 := "Baumann ME, Haddad NR, Salazar A et al. (2024). Testing the reliability of optical coherence tomography to measure epidermal thickness and distinguish volar and nonvolar skin. JID Innov. 4:100276 (epidermis entera, con la capa córnea, en la eminencia tenar: 265,1 ± 50,9 µm, 33 adultos). doi:10.1016/j.xjidi.2024.100276"
const SRC_LEE_HWANG_2002 := "Lee Y, Hwang K (2002). Skin thickness of Korean adults. Surg. Radiol. Anat. 24:183-189 (452 biopsias de 28 zonas: en la palma la epidermis es el 40,6-44,6 % de la piel, 601-637 µm; la dermis queda en ~0,8 mm). doi:10.1007/s00276-002-0034-5"
const SRC_GIBNEY_2010 := "Gibney MA, Arce CH, Byron KJ, Hirsch LJ (2010). Skin and subcutaneous adipose layer thickness in adults with diabetes at sites used for insulin injections: implications for needle length recommendations. Curr. Med. Res. Opin. 26:1519-1530 (ecografía, 388 adultos: piel 2,2 mm en el brazo y en el abdomen; grasa 10,8 mm en el brazo y 13,9 mm en el abdomen). doi:10.1185/03007995.2010.481203"
const SRC_STECCO_2009 := "Stecco A, Masiero S, Macchi V, Stecco C, Porzionato A, De Caro R (2009). The pectoral fascia: anatomical and histological study. J. Bodyw. Mov. Ther. 13:255-261 (fascia pectoral de 297 µm; la 1.x la usa como fascia profunda de referencia). doi:10.1016/j.jbmt.2008.04.036"
const SRC_HOMER_2025 := "Homer KA, Cross MR, Jukic I (2025). The concurrent validity of a portable ultrasound probe for muscle thickness measurements. Clin. Physiol. Funct. Imaging 45:e12901, tabla 3 (cara posterior del brazo, de la grasa al húmero: 2,84 ± 0,87 cm, 18 adultos jóvenes). doi:10.1111/cpf.12901"
const SRC_TINGART_2003 := "Tingart MJ, Apreleva M, von Stechow D, Zurakowski D, Warner JJ (2003). The cortical thickness of the proximal humeral diaphysis predicts bone mineral density of the proximal humerus. J. Bone Joint Surg. Br. 85:611-617 (cortical de la diáfisis proximal del húmero: 4,4 ± 1,0 mm). doi:10.1302/0301-620X.85B4.12843"
const SRC_LI_2021 := "Li S, Wang JZ, Yin B et al. (2021). Atlas of human skeleton hardness obtained using the micro-indentation technique. Orthop. Surg. 13:1417-1422 (Vickers de la cortical: húmero 47,25 HV, radio 42,54, cúbito 43,26, fémur 47,53, tibia 51,20; los huesos del cráneo, todos por encima de 40 HV). doi:10.1111/os.12841"
const SRC_YIN_2019 := "Yin B, Guo JL, Wang JZ, Li S, Liu YK, Zhang YZ (2019). Bone material properties of human phalanges using Vickers indentation. Orthop. Surg. 11:487-492 (tres donantes, 96 cortes de 15 falanges de la mano, 1920 indentaciones: diáfisis 38,52 ± 6,67 HV; base 30,73 y cabeza 30,64). doi:10.1111/os.12455"
const SRC_REILLY_1975 := "Reilly DT, Burstein AH (1975). The elastic and ultimate properties of compact bone tissue. J. Biomech. 8:393-405 (hueso cortical humano: E longitudinal 17,4 GPa). doi:10.1016/0021-9290(75)90075-5"
const SRC_KOESTER_2008 := "Koester KJ, Ager JW, Ritchie RO (2008). The true toughness of human cortical bone measured with realistically short cracks. Nat. Mater. 7:672-677 (cortical del húmero: la grieta arranca con ~1 MPa·m^½; al abrirse a lo largo, 1-2 → ~5 MPa·m^½, J ≈ 0,05-1,2 kJ/m²; al romperse de través llega a 25 MPa·m^½, J ≈ 31 kJ/m²). doi:10.1038/nmat2221"
const SRC_CETINER_2026 := "Çetiner Şeker A, Bayrak AO (2026). Diagnostic accuracy of ultrasonography compared with nerve conduction studies in carpal tunnel syndrome. Front. Neurol. 17 (grupo control, 162 muñecas: de la superficie del abductor corto del pulgar a la cortical del 1.er metacarpiano, 13,89 ± 1,60 mm). doi:10.3389/fneur.2026.1831290"
const SRC_SCHNEIDER_2025 := "Schneider MA, Gilmour RJ (2025). Continued metacarpal cortical bone growth in mid to late adolescence. Am. J. Biol. Anthropol. 188:e70186 (índice cortical del 2.º metacarpiano ~62 % a los 20 años). doi:10.1002/ajpa.70186"
const SRC_HUNG_2022 := "Hung YT, Cheng CY, Chen CB, Huang YL (2022). Ultrasound analyses of the dorsal hands for volumetric rejuvenation. Aesthet. Surg. J. 42:1119-1126 (105 adultos: las tres láminas grasas del dorso pierden 0,21 mm (30,0 %), 1,38 mm (63,89 %) y 0,31 mm (20,95 %) de los 20 a los más de 60 años, así que a los 20 miden 0,70 + 2,16 + 1,48 = 4,34 mm). doi:10.1093/asj/sjac035"
const SRC_KIM_2023 := "Kim JS (2023). Changes in sonographic thickness with identification of nine layers, roughness, and hydration in the dorsal hand after injectables. Plast. Reconstr. Surg. 152:1212-1225 (de la epidermis a la fascia dorsal profunda: 3,20 ± 0,48 mm en manos envejecidas). doi:10.1097/PRS.0000000000010372"
const SRC_WANG_2022 := "Wang S, Yu RX, Fan W et al. (2022). Detection of skin thickness and density in healthy Chinese people by using high-frequency ultrasound. Skin Res. Technol. 29:e13219 (189 adultos: dermis del antebrazo 1,0-1,2 mm; de la mejilla 1,8 mm). doi:10.1111/srt.13219"
const SRC_MENG_2022 := "Meng Y, Feng L, Shan J, Yuan Z, Jin L (2022). Application of high-frequency ultrasound to assess facial skin thickness in association with gender, age, and BMI in healthy adults. BMC Med. Imaging 22:113 (118 adultos: dermis sobre el cigoma 1,14 ± 0,21 mm en hombres y 0,87 ± 0,35 en mujeres). doi:10.1186/s12880-022-00839-w"
const SRC_DEGREEF_2006 := "De Greef S, Claes P, Vandermeulen D, Mollemans W, Suetens P, Willems G (2006). Large-scale in-vivo Caucasian facial soft tissue thickness database for craniofacial reconstruction. Forensic Sci. Int. 159S:S126-S146 (ecografía, 967 adultos; punto «lateral orbit», en la vertical del ángulo externo del ojo sobre el centro del cigoma, 18-29 años con IMC 20-25: 7,4 ± 1,4 mm en hombres y 10,0 ± 1,7 mm en mujeres). doi:10.1016/j.forsciint.2006.02.034"
const SRC_LEE_KIM_2025 := "Lee KL, Kim HJ (2025). Topographic analysis of the periorbital region including orbicularis oculi muscle based on ultrasonography interpretation. J. Cosmet. Dermatol. 24:e70004 (orbicular de los ojos de 1,56 ± 0,45 mm de grosor alrededor de la órbita). doi:10.1111/jocd.70004"
const SRC_COSTA_2021 := "Costa JVD, Ramos AL, Iwaki Filho L (2021). Zygomatic-maxillary cortical bone thickness in hyper, normo and hypodivergent patients. Dental Press J. Orthod. 26:e211965 (cortical cigomático-maxilar de 1-2 mm). doi:10.1590/2177-6709.26.1.e211965.oar"
const SRC_KIM_2012 := "Kim J, Lim H, Lee SI, Kim YJ (2012). Thickness of rectus abdominis muscle and abdominal subcutaneous fat tissue in adult women: correlation with age, pregnancy, laparotomy, and body mass index. Arch. Plast. Surg. 39:528-533 (TC de 545 mujeres: recto del abdomen de 10,26 mm a la altura del ombligo). doi:10.5999/aps.2012.39.5.528"

## Espesores de referencia de la 1.x (µm), calibrados en el brazo: el rasguño blanco levanta la capa córnea (18) y la
## excoriación arranca la epidermis (hasta 75); con 5 pasadas llega a las papilas y sangra (Physics.MODEL).
const ABRASION_WHITE_UM := 18.0
const ABRASION_EXCORIATE_UM := 75.0
const ABRASION_BLEED_PASSES := 5.0
## Exponente de las pasadas (profundidad ∝ n^0,4, Physics.MODEL.passExp): para llegar k veces más hondo hacen falta
## k^(1/0,4) veces más pasadas.
const PASS_EXP := 0.4
## Severidad por profundidad (Physics.SKIN_SEV): la de la 1.x tiene su último hito a 40 mm (0,97).
const SEV_DEEP_UM := 40000.0
const PAPILLARY_UM := 300.0  # dermis papilar (Physics.MODEL.skinPapillaryUm, estimación de la 1.x)

## Tejidos que se repiten en todas las zonas: los de la 1.x (Data.SKIN_LAYERS), por id. La cavidad abdominal es nueva:
## peritoneo e intestinos, sin medición de tenacidad; se le dan las del músculo (estimación: la punta no avanza más
## fácil que en el músculo, y así nunca «acelera» al entrar).
const TISSUE := {
	"cornea": Data.SKIN_LAYERS[0], "epidermis": Data.SKIN_LAYERS[1], "dermis": Data.SKIN_LAYERS[2],
	"grasa": Data.SKIN_LAYERS[3], "fascia": Data.SKIN_LAYERS[4], "musculo": Data.SKIN_LAYERS[5],
	"cavidad": {
		"id": "cavidad", "name": "Cavidad abdominal", "short": "Cavidad", "jT": 0.84, "jC": 0.084, "E": 53.0,
		"col": "#7A3848", "note": "peritoneo e intestinos: una herida que llega aquí es penetrante",
		"tissueSource": "estimación: sin medición de la tenacidad del peritoneo y las vísceras; se toman las del músculo (Aryeetey 2022)",
	},
}

## Zonas. `layers`: [id del tejido, espesor (µm), nota propia de la zona o "", fuente, calidad]. El último tejido acaba
## en el hueso (o, en el abdomen, la cavidad no acaba). `bone`: el hueso de debajo, o null.
const ZONES := [
	{
		"id": "brazo", "name": "Brazo (cara posterior)", "short": "Brazo", "default": true,
		"site": "cara posterior del brazo, a media altura (la zona de la 1.x); capa córnea y epidermis del dorso del antebrazo",
		"fact": "La piel de siempre: 18 µm de capa córnea, 57 de epidermis, 2,1 mm de dermis y casi 11 mm de grasa antes del tríceps. El húmero queda a unos 4 cm: solo lo alcanzan las dagas más largas.",
		"layers": [
			["cornea", 18.0, "", SRC_SANDBY_2003, "primary"],
			["epidermis", 57.0, "", SRC_SANDBY_2003, "primary"],
			["dermis", 2125.0, "", SRC_GIBNEY_2010, "primary"],
			["grasa", 10800.0, "", SRC_GIBNEY_2010, "primary"],
			["fascia", 300.0, "", SRC_STECCO_2009, "secondary"],
			["musculo", 28100.0, "",
				SRC_HOMER_2025 + " (tríceps; el grosor del músculo incluye la fascia: 2,84 cm desde el final de la grasa)", "secondary"],
		],
		"bone": {
			"id": "humero", "name": "Húmero", "short": "Hueso", "corticalUm": 4400.0, "hv": 47.25, "E": 17.4,
			"kInit": 1.0, "jSplit": 1.2, "jBreak": 31.0, "col": "#E8DDC4",
			"note": "hueso cortical: más duro que la queratina de cualquier garra",
			"source": SRC_LI_2021 + "; " + SRC_TINGART_2003 + "; " + SRC_REILLY_1975 + "; " + SRC_KOESTER_2008,
			"quality": "primary",
		},
	},
	{
		"id": "palma", "name": "Palma (eminencia tenar)", "short": "Palma",
		"site": "eminencia tenar (la base del pulgar), donde Egawa midió la capa córnea y Baumann la epidermis",
		"fact": "Callo de serie: la capa córnea mide ~170 µm, diez veces la del brazo, y la epidermis viva otros ~90. Un rasguño que en el brazo escuece aquí solo pule el callo.",
		"layers": [
			["cornea", 173.0, "callo natural: unas diez veces más gruesa que en el brazo", SRC_EGAWA_2007, "primary"],
			["epidermis", 92.0, "más gruesa que en el brazo; sin vasos",
				SRC_BAUMANN_2024 + " menos la capa córnea de Egawa 2007 (265 − 173 µm)", "secondary"],
			["dermis", 800.0, "", SRC_LEE_HWANG_2002, "secondary"],
			["grasa", 2500.0, "almohadilla fibrosa de la palma",
				"estimación: sin medición localizada en la eminencia tenar; del orden de la grasa del dorso de la mano (Hung 2022)", "estimate"],
			["fascia", 300.0, "fascia tenar", SRC_STECCO_2009 + " (como fascia de referencia)", "estimate"],
			["musculo", 13890.0, "músculos del pulgar (abductor corto, oponente y flexor corto)", SRC_CETINER_2026, "primary"],
		],
		"bone": {
			"id": "metacarpiano1", "name": "Primer metacarpiano", "short": "Hueso", "corticalUm": 2500.0, "hv": 43.0,
			"E": 17.4, "kInit": 1.0, "jSplit": 1.2, "jBreak": 31.0, "col": "#E8DDC4",
			"note": "hueso del pulgar bajo su almohadilla de músculo",
			"source": SRC_LI_2021 + " (midió también los metacarpianos, pero su texto no da el valor: se toma el del radio y el cúbito, 42,5-43,3 HV; la medición publicada más cercana en la mano, las diáfisis de las falanges, da 38,52 ± 6,67 HV: " + SRC_YIN_2019 + "); cortical de ~2,5 mm, estimación con el índice cortical del 2.º metacarpiano (" + SRC_SCHNEIDER_2025 + ") y una anchura de ~8 mm",
			"quality": "secondary",
		},
	},
	{
		"id": "dorsomano", "name": "Dorso de la mano", "short": "Dorso mano",
		"site": "dorso de la mano sobre el tercer metacarpiano, en un adulto joven (la zona donde Davis 2004 midió la perforación)",
		"fact": "Piel fina, tres láminas de grasa y los tendones extensores: el hueso está a poco más de 5 mm. Aquí se midió la fuerza de perforación de la piel que usa el banco (Davis 2004).",
		"layers": [
			["cornea", 29.0, "", SRC_EGAWA_2007, "primary"],
			["epidermis", 57.0, "", SRC_ROBERTSON_2010 + "; se toma la del brazo, " + SRC_SANDBY_2003, "secondary"],
			["dermis", 914.0, "",
				"estimación: piel de ~1 mm, como la del antebrazo por ecografía (" + SRC_WANG_2022 + ")", "estimate"],
			["grasa", 4340.0, "tres láminas de grasa con las venas y los tendones extensores", SRC_HUNG_2022, "secondary"],
			["fascia", 300.0, "fascia dorsal profunda sobre el metacarpiano", SRC_STECCO_2009 + " (como fascia de referencia)", "estimate"],
		],
		"bone": {
			"id": "metacarpiano3", "name": "Tercer metacarpiano", "short": "Hueso", "corticalUm": 2500.0, "hv": 43.0,
			"E": 17.4, "kInit": 1.0, "jSplit": 1.2, "jBreak": 31.0, "col": "#E8DDC4",
			"note": "el hueso de la mano, a un paso de la superficie",
			"source": SRC_LI_2021 + " (su texto no da el valor del metacarpiano: el del radio y el cúbito; las falanges de la mano dan 38,52 ± 6,67 HV, " + SRC_YIN_2019 + "); cortical de ~2,5 mm, estimación con el índice cortical de " + SRC_SCHNEIDER_2025,
			"quality": "secondary",
		},
	},
	{
		"id": "cara", "name": "Cara (pómulo)", "short": "Pómulo",
		"site": "mejilla sobre el hueso cigomático (el pómulo), en la vertical del ángulo externo del ojo",
		"fact": "Capa córnea fina (~17 µm), 1 mm de dermis, la grasa malar y el orbicular: el pómulo está a menos de 1 cm. Una garra larga no se hunde más: topa con el hueso.",
		"layers": [
			["cornea", 17.0, "", SRC_EGAWA_2007, "primary"],
			["epidermis", 57.0, "", SRC_ROBERTSON_2010 + "; se toma la del brazo, " + SRC_SANDBY_2003, "secondary"],
			["dermis", 1000.0, "", SRC_MENG_2022 + " (media de hombres y mujeres)", "secondary"],
			["grasa", 5766.0, "grasa malar",
				"estimación: lo que queda de los 8,7 mm hasta el hueso (" + SRC_DEGREEF_2006 + ") tras la piel, el SMAS y el músculo", "estimate"],
			["fascia", 300.0, "SMAS (sistema musculoaponeurótico superficial)", SRC_STECCO_2009 + " (como fascia de referencia)", "estimate"],
			["musculo", 1560.0, "orbicular de los ojos y origen de los cigomáticos", SRC_LEE_KIM_2025, "secondary"],
		],
		"bone": {
			"id": "cigomatico", "name": "Hueso cigomático", "short": "Hueso", "corticalUm": 1500.0, "hv": 40.0,
			"E": 17.4, "kInit": 1.0, "jSplit": 1.2, "jBreak": 31.0, "col": "#E8DDC4",
			"note": "el pómulo: hueso a menos de 1 cm de la superficie",
			"source": SRC_DEGREEF_2006 + " (profundidad: 7,4 y 10,0 mm, media 8,7); " + SRC_LI_2021 + " (huesos del cráneo > 40 HV); " + SRC_COSTA_2021,
			"quality": "secondary",
		},
	},
	{
		"id": "abdomen", "name": "Abdomen (junto al ombligo)", "short": "Abdomen",
		"site": "pared del abdomen junto al ombligo (donde se pincha la insulina): sin hueso debajo",
		"fact": "Casi 14 mm de grasa y 1 cm de recto del abdomen, y detrás no hay hueso: la cavidad abdominal. Una punta que pasa el músculo abre una herida penetrante.",
		"layers": [
			["cornea", 18.0, "", SRC_ROBERTSON_2010 + " (abdomen ≈ brazo); se toma la del brazo, " + SRC_SANDBY_2003, "secondary"],
			["epidermis", 57.0, "", SRC_ROBERTSON_2010 + "; se toma la del brazo, " + SRC_SANDBY_2003, "secondary"],
			["dermis", 2125.0, "", SRC_GIBNEY_2010, "primary"],
			["grasa", 13900.0, "la reserva de grasa del abdomen", SRC_GIBNEY_2010, "primary"],
			["fascia", 300.0, "vaina anterior del recto", SRC_STECCO_2009 + " (como fascia de referencia)", "estimate"],
			["musculo", 10260.0, "recto del abdomen", SRC_KIM_2012, "primary"],
			["cavidad", 33340.0, "", "estimación: la cavidad abdominal no acaba en el modelo (60 mm, como el músculo de la 1.x)", "estimate"],
		],
		"bone": null,
	},
]

## Médula del hueso, lo que hay pasada la cortical (penetration.gd le da la tenacidad y el módulo de la grasa).
const MARROW := {
	"id": "medula", "name": "Médula ósea", "short": "Médula", "col": "#E8C46A",
	"note": "médula amarilla: grasa dentro del hueso",
	"source": "estimación: la médula amarilla de la diáfisis de un adulto es sobre todo grasa; se le dan las propiedades de la hipodermis",
	"quality": "estimate",
}

## Aspecto sugerido para los dibujos de las capas nuevas (la interfaz las añade a Looks.MATERIAL_LOOK y SKIN_BAND).
const SECTION_LOOK := {
	"tejido-hueso": { "kind": "bone", "base": "#EFE5CF", "lo": "#CDBB98", "ink": "#A8906A" },
	"tejido-medula": { "kind": "fat", "base": "#EBCB7A", "lo": "#D4AE55", "ink": "#B8923E" },
	"tejido-cavidad": { "kind": "cavity", "base": "#8A4452", "lo": "#5E2733", "ink": "#3E1520" },
}
## Alto sugerido de la banda de cada capa nueva en el corte (como Looks.SKIN_BAND). La médula solo se dibuja si la
## punta atraviesa la cortical.
const SECTION_BAND := { "hueso": 14.0, "medula": 12.0, "cavidad": 20.0 }


# ── Catálogo ──

## La zona con ese id, o null.
static func find(id: Variant) -> Variant:
	for z: Dictionary in ZONES:
		if z.id == id:
			return z
	return null


## La zona con ese id o, si no existe o es null, la de por defecto (la de la 1.x).
static func resolve(id: Variant) -> Dictionary:
	var z: Variant = find(id)
	return z if z != null else find(DEFAULT_ID)


## Ids de las zonas, en orden (para el selector).
static func ids() -> Array:
	var out: Array = []
	for z: Dictionary in ZONES:
		out.append(z.id)
	return out


# ── Tablas de cada zona (calculadas una vez) ──

## Las tablas de cada zona: { id: { stack, bone, anchors, limits } }, calculadas una vez al cargar el script con las
## funciones _make_* de abajo. Solo lectura: nadie las vuelve a escribir, así que son seguras para hilos (como las
## constantes de v8_math.gd; lo vigila tests/lab/test_threads.gd). Las funciones públicas devuelven copias, que se pueden
## modificar sin tocar el catálogo. Así compute() no rehace las pilas en cada consulta (unidad 4b: la piel de la 2.0 las
## consulta varias veces por ensayo).
static var _TABLES: Dictionary = _build_tables()


static func _build_tables() -> Dictionary:
	var out := {}
	for z: Dictionary in ZONES:
		var stk := _make_stack(z)
		var b: Variant = _make_bone(z, stk)
		out[z.id] = { "stack": stk, "bone": b, "anchors": _make_anchors(stk, b), "limits": _make_limits(stk) }
	return out


## Las tablas de la zona con ese id (o de la de por defecto). Solo lectura.
static func _table(id: Variant) -> Dictionary:
	return _TABLES[resolve(id).id]


# ── Capas ──

## Pila de capas blandas de la zona, con el esquema de Data.SKIN_LAYERS (µm acumulados) más `source` y `quality`
## del espesor. Las funciones de piel de physics.gd la usan tal cual; la última capa acaba en el hueso (o no acaba,
## en el abdomen). Copias nuevas en cada llamada: se pueden modificar sin tocar el catálogo.
static func stack(id: Variant = DEFAULT_ID) -> Array:
	return (_table(id).stack as Array).duplicate(true)


static func _make_stack(z: Dictionary) -> Array:
	var out: Array = []
	var from := 0.0
	for row: Array in z.layers:
		var tissue: Dictionary = TISSUE[row[0]]
		var l := {
			"id": tissue.id, "name": tissue.name, "short": tissue.short, "from": from, "to": from + float(row[1]),
			"jT": tissue.jT, "jC": tissue.jC, "E": tissue.E, "col": tissue.col,
			"note": row[2] if String(row[2]) != "" else tissue.note, "source": row[3], "quality": row[4],
		}
		out.append(l)
		from = l.to
	return out


## Hueso de la zona con su profundidad (fromUm: donde acaban las partes blandas), o null (abdomen).
static func bone(id: Variant = DEFAULT_ID) -> Variant:
	var b: Variant = _table(id).bone
	return (b as Dictionary).duplicate() if b != null else null


static func _make_bone(z: Dictionary, stk: Array) -> Variant:
	if z.bone == null:
		return null
	var b: Dictionary = z.bone.duplicate()
	b["fromUm"] = stk[-1].to
	b["toUm"] = stk[-1].to + float(b.corticalUm)
	return b


## Profundidad (µm) a la que la punta topa con el hueso, o INF si la zona no tiene.
static func bone_depth_um(id: Variant = DEFAULT_ID) -> float:
	var b: Variant = _table(id).bone
	return float(b.fromUm) if b != null else INF


## Primera capa con ese id en la pila, o null.
static func layer(stk: Array, layer_id: String) -> Variant:
	for l: Dictionary in stk:
		if l.id == layer_id:
			return l
	return null


## Fin de la epidermis (µm): lo que hay que atravesar para que una herida sangre.
static func epidermis_end_um(stk: Array) -> float:
	var l: Variant = layer(stk, "epidermis")
	return float(l.to) if l != null else float(stk[0].to)


## Capas para el corte de la zona (dibujo): las blandas y, debajo, el hueso (su cortical) si lo hay. Cada banda lleva
## id, name, short, from, to, col y `look` (clave de Looks.MATERIAL_LOOK; las nuevas, en SECTION_LOOK).
static func section_layers(id: Variant = DEFAULT_ID) -> Array:
	var out: Array = []
	for l: Dictionary in stack(id):
		var band := l.duplicate()
		band["look"] = "tejido-" + String(l.id)
		out.append(band)
	var b: Variant = bone(id)
	if b != null:
		out.append({
			"id": "hueso", "name": b.name, "short": b.short, "from": b.fromUm, "to": b.toUm, "col": b.col,
			"note": b.note, "look": "tejido-hueso", "source": b.source, "quality": b.quality,
		})
	return out


# ── Umbrales de la 1.x llevados a cada zona ──

## Profundidades de la abrasión sin romper la piel (µm) y pasadas para que la excoriación sangre. La 1.x los calibró en
## el brazo (18 µm, 75 µm y 5 pasadas); aquí se conservan las profundidades ABSOLUTAS, acotadas por las capas de la
## zona: en la palma, 75 µm se quedan en el callo. Para sangrar, la excoriación tiene que llegar al final de la
## epidermis; con la ley de pasadas (profundidad ∝ n^0,4) hacen falta 5·(epi/75)^(1/0,4) pasadas. En el brazo da
## exactamente 18, 75 y 5 (estimación de la 1.x, no una medición).
static func abrasion_limits(id: Variant = DEFAULT_ID) -> Dictionary:
	return (_table(id).limits as Dictionary).duplicate()


static func _make_limits(stk: Array) -> Dictionary:
	var epi := epidermis_end_um(stk)
	var cornea: float = stk[0].to
	var white := minf(ABRASION_WHITE_UM, cornea)
	var excoriate := minf(ABRASION_EXCORIATE_UM, epi)
	var passes := ABRASION_BLEED_PASSES
	if epi != ABRASION_EXCORIATE_UM:
		passes = ABRASION_BLEED_PASSES * V8.js_pow(epi / ABRASION_EXCORIATE_UM, 1.0 / PASS_EXP)
	return {
		"whiteUm": white, "excoriateUm": excoriate, "bleedPasses": passes, "epiUm": epi, "corneaUm": cornea,
		"excoriateLayer": "cornea" if excoriate <= cornea else "epidermis",
	}


## Profundidad (µm) de una excoriación (el esfuerzo de «arrancar la epidermis» sin romper la piel) tras n pasadas.
## La 1.x la deja fija en la epidermis entera del brazo (75 µm) y hace sangrar a partir de 5 pasadas. Aquí la primera
## pasada arranca excoriateUm (75 µm o la epidermis, si es más fina) y las siguientes ahondan con la ley de pasadas de la
## 1.x, 75·(n/5)^0,4, hasta el final de la epidermis, al que llegan justo en bleedPasses: donde la epidermis es más
## gruesa (palma, dorso de la mano) la herida sangra cuando alcanza las papilas, y no antes (un callo pulido no sangra).
## En el brazo da siempre 75 µm, como la 1.x.
static func excoriation_depth_um(id: Variant, passes: float) -> float:
	var lim: Dictionary = _table(id).limits
	if passes >= float(lim.bleedPasses):
		return lim.epiUm
	var grown := ABRASION_EXCORIATE_UM * V8.js_pow(maxf(passes, 1.0) / ABRASION_BLEED_PASSES, PASS_EXP)
	return minf(float(lim.epiUm), maxf(float(lim.excoriateUm), grown))


## Hitos de severidad por profundidad ([µm, 0-1], crecientes) con la misma escala que Physics.SKIN_SEV, pero en las
## fronteras de la zona: fin de la epidermis (0,3), dermis papilar (0,45), fin de la dermis (0,62), de la grasa (0,8)
## y de la fascia (0,86), y 0,97 donde la herida ya es gravísima: el hueso o la cavidad, o a 40 mm (el de la 1.x). En
## el brazo da exactamente Physics.SKIN_SEV. Un hito que no avanza en profundidad se descarta.
static func severity_anchors(id: Variant = DEFAULT_ID) -> Array:
	return (_table(id).anchors as Array).duplicate(true)


## El hito profundo (µm): el hueso o la cavidad, o 40 mm (el de severidad 0,97).
static func deep_um(id: Variant = DEFAULT_ID) -> float:
	return float(_table(id).anchors[-1][0])


static func _make_anchors(stk: Array, bone_row: Variant) -> Array:
	var epi := epidermis_end_um(stk)
	var marks: Array = [[0.0, 0.25], [epi, 0.3], [epi + PAPILLARY_UM, 0.45]]
	for pair in [["dermis", 0.62], ["grasa", 0.8], ["fascia", 0.86]]:
		var l: Variant = layer(stk, pair[0])
		if l != null:
			marks.append([float(l.to), pair[1]])
	var deep := SEV_DEEP_UM
	var cav: Variant = layer(stk, "cavidad")
	if cav != null:
		deep = minf(deep, float(cav.from))
	deep = minf(deep, float(bone_row.fromUm) if bone_row != null else INF)
	# el hito profundo manda: fuera los que queden a su altura o por debajo
	var out: Array = []
	for m: Array in marks:
		if float(m[0]) < deep and (out.is_empty() or float(m[0]) > float(out[-1][0])):
			out.append(m)
	out.append([deep, 0.97])
	return out


## Severidad (0-1) de una herida de profundidad um (µm) en la zona: la interpolación logarítmica de
## Physics._skin_severity entre los hitos de severity_anchors (en el brazo, bit a bit la de la 1.x; hay test). La
## integración puede darle a _skin_severity los hitos como parámetro y usar esta solo de referencia.
static func severity(id: Variant, um: float) -> float:
	if um <= 0.0:
		return 0.0
	var marks: Array = _table(id).anchors
	for i in range(1, marks.size()):
		var u0: float = marks[i - 1][0]
		var s0: float = marks[i - 1][1]
		var u1: float = marks[i][0]
		var s1: float = marks[i][1]
		if um <= u1:
			return s0 + ((s1 - s0) * (V8.js_log(1.0 + um) - V8.js_log(1.0 + u0))) / (V8.js_log(1.0 + u1) - V8.js_log(1.0 + u0))
	return marks[-1][1]
