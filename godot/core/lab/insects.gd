## Tribología biológica · aguijones de insectos (catálogo de la 2.0, no existe en el motor 1.x).
##
## Cada entrada lleva TODAS las claves de una garra de Data.CLAWS, con las mismas unidades, para que
## Physics.resolve_tool, el banco y la interfaz la traten como una garra:
##   - hv (HV) y E (GPa): los de la PUNTA, que es lo que toca el objetivo (nanoindentación, muestras secas);
##   - area (mm²): la esfera de la punta, tipRadiusUm = √(area/π)·1000; alpha: semiángulo del ápice (°);
##   - reach (mm): la longitud que puede entrar (hasta el bulbo, que nunca entra);
##   - force (N): el empuje típico al picar; fBreak (N): la carga a la que el aguijón PANDEA (Euler, sting.gd),
##     no a la que se rompe: el motor 1.x ya la usa como límite de la herramienta en los sólidos;
##   - strike { v, m }: el aguijón no golpea, empuja; v es la velocidad media de inserción y m la masa del insecto,
##     así que la energía del «golpe» es despreciable (≈10⁻¹¹ J);
##   - mass (kg): el insecto entero; curve (0-1): curvatura propia del aguijón.
## Y además `stinger` con los datos propios, cada uno como { value, source, quality } (o con sus campos y un
## source/quality del grupo), y `source`/`quality` de la entrada. quality: "primary" (medido en la especie),
## "secondary" (medido en una especie hermana o del mismo género, o tomado de una revisión o de divulgación) o
## "estimate" (sin medición: se dice en desc). La de la entrada resume la de sus datos clave.
##
## Modelo y fuentes completas: docs/fisica/aguijones.md. Física: core/lab/sting.gd.
## Uso: const Insects = preload("res://core/lab/insects.gd"), y después Insects.STINGERS, Insects.find_by_id("abeja").
extends RefCounted

const GROUP := "Insectos"

# ── Fuentes (texto de la cita) ──
const SRC_ZHAO_2015 := "Zhao Z-L, Zhao H-P, Ma G-J, Wu C-W, Yang K, Feng X-Q (2015). Structures, properties, and functions of the stings of honey bees and paper wasps: a comparative study. Biol. Open 4:921-928. doi:10.1242/bio.012195"
const SRC_DAS_2018 := "Das R, Yadav RN, Sihota P, Uniyal P, Kumar N, Bhushan B (2018). Biomechanical evaluation of wasp and honeybee stingers. Sci. Rep. 8:14945. doi:10.1038/s41598-018-33386-y"
const SRC_LING_2016 := "Ling J, Jiang L, Chen K, Pan C, Li Y, Yuan W, Liang L (2016). Insertion and pull behavior of worker honeybee stinger. J. Bionic Eng. 13:303-311. doi:10.1016/S1672-6529(16)60303-7"
const SRC_LING_2017 := "Ling J, Song Z, Wang J et al. (2017). Effect of honeybee stinger and its microstructured barbs on insertion and pull force. J. Mech. Behav. Biomed. Mater. 68:173-179. doi:10.1016/j.jmbbm.2017.01.040"
const SRC_RAMIREZ_2023 := "Ramirez-Esquivel F, Ravi S (2023). Functional anatomy of the worker honeybee stinger (Apis mellifera). iScience 26:107103. doi:10.1016/j.isci.2023.107103"
const SRC_WU_2014 := "Wu J, Yan S, Zhao J, Ye Y (2014). Barbs facilitate the helical penetration of honeybee (Apis mellifera ligustica) stingers. PLoS ONE 9:e103823. doi:10.1371/journal.pone.0103823"
const SRC_BISS_2021 := "Bissessarsingh M, Starr CK (2021). Comparative morphology of the stinger in social wasps (Hymenoptera: Vespidae). Insects 12:729. doi:10.3390/insects12080729"
const SRC_MULFINGER_1992 := "Mulfinger L, Yunginger J, Styer W, Guralnick M, Lintner T (1992). Sting morphology and frequency of sting autotomy among medically important vespids and the honey bee. J. Med. Entomol. 29:325-328. doi:10.1093/jmedent/29.2.325"
const SRC_HERRERA_2023 := "Herrera C, Williams M, Encarnação J, Roura-Pascual N, Faulhaber B, Jurado-Rivera JA, Leza M (2023). Automated detection of the yellow-legged hornet (Vespa velutina) using an optical sensor with machine learning. Pest Manag. Sci. 79:1225-1233, tablas S1-S2. doi:10.1002/ps.7296"
const SRC_ALTSHULER_2005 := "Altshuler DL, Dickson WB, Vance JT, Roberts SP, Dickinson MH (2005). Short-amplitude high-frequency wing strokes determine the aerodynamics of honeybee flight. PNAS 102:18213-18218. doi:10.1073/pnas.0506590102"
const SRC_KOVAC_2012 := "Kovac H, Stabentheiner A (2012). Does size matter? Thermoregulation of 'heavyweight' and 'lightweight' wasps (Vespa crabro and Vespula sp.). Biol. Open 1:848-856. doi:10.1242/bio.20121156"
const SRC_KAFER_2015 := "Käfer H, Kovac H, Oswald B, Stabentheiner A (2015). Respiration and metabolism of the resting European paper wasp (Polistes dominulus). J. Comp. Physiol. B 185:647-658. doi:10.1007/s00360-015-0915-7"
const SRC_KENNEDY_2018 := "Kennedy PJ, Ford SM, Poidatz J, Thiéry D, Osborne JL (2018). Searching for nests of the invasive Asian hornet (Vespa velutina) using radio-telemetry. Commun. Biol. 1:88. doi:10.1038/s42003-018-0092-9"
const SRC_GLASS_2024 := "Glass JR, Burnett NP, Combes SA, Weisman E, Helbling A, Harrison JF (2024). Flying, nectar-loaded honey bees conserve water and improve heat tolerance by reducing wingbeat frequency and metabolic heat production. PNAS 121:e2311025121. doi:10.1073/pnas.2311025121"
const SRC_KARDUM_2023 := "Kardum Hjort C, Smith HG, Allen AP, Dudaniec RY (2023). Morphological variation in bumblebees (Bombus terrestris) after three decades of an island invasion. J. Insect Sci. 23:10. doi:10.1093/jisesa/iead006"
const SRC_SCHUMACHER_1990 := "Schumacher MJ, Schmidt JO, Egen NB, Lowry JE (1990). Quantity, analysis, and lethality of European and Africanized honey bee venoms. Am. J. Trop. Med. Hyg. 43:79-86. doi:10.4269/ajtmh.1990.43.79"
const SRC_SCHUMACHER_1994 := "Schumacher MJ, Tveten MS, Egen NB (1994). Rate and quantity of delivery of venom from honeybee stings. J. Allergy Clin. Immunol. 93:831-835. doi:10.1016/0091-6749(94)90373-5"
const SRC_SAHINER_2019 := "Sahiner UM, Durham SR (2019). Hymenoptera venom allergy: how does venom immunotherapy prevent anaphylaxis from bee and wasp stings? Front. Immunol. 10:1959 (cita a Hoffman & Jacobson 1984). doi:10.3389/fimmu.2019.01959"
const SRC_VESPID_LABEL := "Prospecto de los extractos alergénicos de veneno de himenópteros (DailyMed, NLM/FDA): un véspido típico deja ~10 µg por picadura (2-15 µg)"
const SRC_SCHMIDT_2016 := "Schmidt JO (2016). The Sting of the Wild. Johns Hopkins University Press (índice de dolor, apéndice); Schmidt JO (1990), en Evans DL, Schmidt JO (eds.) Insect Defenses, SUNY Press, pp. 387-419"
const SRC_HERMANN_1971 := "Hermann HR (1971). Sting autotomy, a defensive mechanism in certain social Hymenoptera. Insectes Soc. 18:111-120. doi:10.1007/BF02223116"
const SRC_GREENE_2012 := "Greene A, Breisch NL, Golden DBK, Kelly D, Douglass LW (2012). Sting embedment and avulsion in yellowjackets (Hymenoptera: Vespidae): a functional equivalent to autotomy. Am. Entomol. 58:50-57. doi:10.1093/ae/58.1.0050"
const SRC_BRITANNICA_PEPSIS := "Encyclopaedia Britannica, «Tarantula hawk» (aguijón curvo de hasta 7 mm en las hembras de Pepsis)"
const SRC_ANTWIKI_PARAPONERA := "AntWiki y Wikipedia, «Paraponera clavata» (obreras de 18-30 mm)"
## Escalado geométrico de las especies sin medición (estimación): el aguijón de los véspidos y de la abeja crece con
## el insecto (eje/ala anterior ≈ 0,17-0,21 en 51 especies, Bissessarsingh & Starr 2021) y la forma de los aguijones
## es universal (Jensen et al. 2020, Nat. Phys. 16:1074, doi:10.1038/s41567-020-0930-9). Se escalan el radio de la
## punta, el diámetro y el canal de la abeja por la anchura de la lanceta (Σpúas/Sr) o por el tamaño del cuerpo.
const SRC_SCALING := "Escalado geométrico desde la abeja (estimación): anchura de la lanceta = Σpúas/Sr (Bissessarsingh & Starr 2021) o tamaño del cuerpo; forma universal de los aguijones (Jensen et al. 2020, Nat. Phys. 16:1074, doi:10.1038/s41567-020-0930-9)"
## Longitud que entra / longitud del eje: 1,32/1,81 en la abeja (Ramirez-Esquivel 2023; Bissessarsingh & Starr 2021)
## y 1,55/1,92 en Vespula (Das 2018; Bissessarsingh & Starr 2021): media 0,77.
const SRC_INSERT_RATIO := "Longitud que entra ≈ 0,77 × eje (estimación): 1,32/1,81 mm en la abeja (Ramirez-Esquivel 2023; Bissessarsingh & Starr 2021) y 1,55/1,92 mm en Vespula (Das 2018; Bissessarsingh & Starr 2021)"
const SRC_FORCE_MARGIN := "Empuje típico = 1,4 × la fuerza de perforación del modelo (estimación): la abeja (5,75 mN medidos frente a 4,25 del modelo) y la avispa papelera (8 frente a 5,8) empujan ~1,4 veces lo justo"

## Radio de la punta de la abeja (mm): 1-1,5 µm (Ling 2017, MEB de A. cerana; la anatomía de A. mellifera es
## casi idéntica, Ramirez-Esquivel 2023). Las demás puntas se escalan desde aquí (estimación).
const BEE_TIP_MM := 0.00125

const STINGERS := [
	# ── Abeja melífera (obrera) ──
	{
		"id": "abeja", "group": GROUP, "name": "Abeja melífera", "title": "Aguijón de abeja melífera",
		"hv": 7.1, "mohs": 1.5, "E": 0.42, "area": PI * BEE_TIP_MM * BEE_TIP_MM, "alpha": 16.5, "reach": 1.32,
		"curve": 0.0, "mass": 0.00007, "force": 0.00575, "fBreak": 0.00864241,
		"strike": { "v": 0.00088, "m": 0.00007 }, "col": "#6B4A2B",
		"desc": "Obrera de Apis mellifera. Aguijón recto de 1,3 mm útiles con ~10 púas por lanceta que no se pueden enfundar: perfora la piel con 1-6 mN (medido en la abeja asiática, de aguijón casi idéntico), entra hasta la dermis serrando con las lancetas y se queda clavado. La abeja se va sin él (autotomía) y muere en horas o pocos días. La punta es ~6 veces más blanda que la base (nanoindentación, muestras secas).",
		"source": SRC_RAMIREZ_2023 + "; " + SRC_ZHAO_2015 + "; " + SRC_LING_2017 + "; " + SRC_DAS_2018,
		"quality": "primary",
		"stinger": {
			"species": "Apis mellifera", "family": "Apidae", "caste": "obrera",
			"shaftMm": { "value": 1.81, "source": SRC_BISS_2021, "quality": "primary" },
			"insertMm": { "value": 1.32, "source": SRC_RAMIREZ_2023, "quality": "primary", "note": "1320 ± 61 µm hasta el bulbo, que nunca entra (24 de 24 ensayos)" },
			"diameterUm": { "value": 86.0, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "estilete de A. cerana en la parte media, ~86 µm" },
			"canalUm": { "value": 39.0, "source": SRC_RAMIREZ_2023, "quality": "primary", "note": "canal del veneno de 39 ± 4,5 µm" },
			"tipRadiusUm": { "value": 1.25, "source": SRC_LING_2017, "quality": "secondary", "note": "1-1,5 µm (MEB de A. cerana); se usa el centro. Dato citado del texto del artículo: no hemos podido leer el original" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_LING_2017, "quality": "secondary", "note": "ángulo del ápice de las lancetas" },
			"barbs": {
				"perLancet": 10, "depthUm": 12.0, "maxUm": 22.4, "firstUm": 52.6,
				"pitchUm": [23.6, 29.5, 38.4, 47.1, 60.3, 70.3, 84.0, 105.5, 143.6],
				"lengthUm": [12.0, 18.2, 21.7, 22.1, 21.6, 22.4, 21.3, 20.4, 17.2, 11.5],
				"angleDeg": [90.33, 89.62, 80.31, 72.13, 72.36, 59.63, 46.19], "rowHelixDeg": 8.5,
				"serrationUm": 102.0, "serrationIndex": 2.43, "sheathable": false,
				"source": SRC_RAMIREZ_2023 + "; " + SRC_BISS_2021 + "; " + SRC_WU_2014 + "; " + SRC_MULFINGER_1992,
				"quality": "primary",
				"note": "10 púas por lanceta (MEB; 8-9 contando solo las agudas); la primera a 52,6 µm de la punta; profundidad media Σ/n = 102/8,5 µm; la fila forma una hélice dextrógira de ~8,5°; el estilete es demasiado estrecho para enfundarlas",
			},
			"material": {
				"tip": { "E": 0.42, "H": 0.07 }, "mid": { "E": 1.42, "H": 0.22 }, "base": { "E": 3.08, "H": 0.42 },
				"dry": true, "source": SRC_DAS_2018, "quality": "secondary",
				"note": "nanoindentación de A. cerana (muestras secas, E y H en GPa); la cutícula hidratada es más blanda (Klocke & Schmitz 2011)",
			},
			"insertionN": { "value": 0.0025, "range": [0.00134, 0.00575], "substrate": "piel de cerdo (Zhao), conejo (Ling 2017)", "source": SRC_ZHAO_2015 + "; " + SRC_LING_2016 + "; " + SRC_LING_2017, "quality": "secondary", "note": "2-3 mN en piel de cerdo, 1,34 mN (Ling 2016) y 5,75 mN en piel de conejo; todas en A. cerana" },
			"extractionN": { "value": 0.12477, "range": [0.1135, 0.13604], "source": SRC_LING_2016 + "; " + SRC_LING_2017, "quality": "secondary", "note": "113,5 y 136,0 mN (A. cerana, aguijón entero); en piel de cerdo, solo 3,3 veces la de perforación (Zhao 2015; probablemente con menos púas dentro)" },
			"bucklingN": { "value": 0.00672, "source": SRC_LING_2016, "quality": "secondary", "note": "pandeo en el plano medido en A. cerana" },
			"autotomy": { "class": "+", "value": true, "survivalH": [18.0, 114.0], "source": SRC_BISS_2021 + "; " + SRC_HERMANN_1971 + "; " + SRC_RAMIREZ_2023, "quality": "primary", "why": "púas grandes y expuestas (Sr 2,43) que la piel elástica engancha; el aparato está sujeto por músculos atrofiados y se desgarra con el saco del veneno, el ganglio y parte del intestino" },
			"angleDeg": { "value": -6.0, "range": [-13.0, -6.0], "kind": "óptimo calculado (MEF) y regulado durante la picadura", "source": SRC_DAS_2018 + "; " + SRC_ZHAO_2015, "quality": "secondary", "note": "casi perpendicular: el ángulo solo varía unos grados (Zhao)" },
			"twistDeg": { "value": -8.4, "source": SRC_WU_2014, "quality": "primary", "note": "giro horario medio de −8,36° al entrar (visto desde la base hacia la punta); menor en sustratos duros; ~−8° en gel de sílice, el más parecido a la piel" },
			"insertionS": { "value": 1.5, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "~1,5 s en A. cerana (vídeo de alta velocidad)" },
			"venom": { "ug": 147.0, "kind": "reservorio", "pump": "válvulas de las lancetas", "t90S": 20.0, "totalS": 60.0, "source": SRC_SCHUMACHER_1990 + "; " + SRC_SCHUMACHER_1994 + "; " + SRC_RAMIREZ_2023, "quality": "primary", "note": "147 µg por abeja europea; el aguijón arrancado sigue bombeando: ≥90 % en 20 s y todo en 1 min" },
			"schmidt": { "value": 2.0, "note": "«ardiente, corrosivo, pero se aguanta»", "source": SRC_SCHMIDT_2016, "quality": "primary" },
			"wingbeat": { "hz": 231.5, "sdHz": 21.1, "harmonicsHz": [231.5, 462.0, 692.1, 925.3], "powersDb": [-28.63, -34.1, -41.9, -43.6], "source": SRC_HERRERA_2023 + "; " + SRC_ALTSHULER_2005, "quality": "primary", "note": "sensor óptico en laboratorio; ~230 Hz también en Altshuler 2005" },
			"massKg": { "value": 0.00007, "source": SRC_GLASS_2024, "quality": "primary", "note": "~70 mg la pecoreadora vacía" },
			"bodyMm": { "value": 11.7, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "11,7 ± 1,3 mm en A. cerana; ala anterior 8,6 mm en A. mellifera (Bissessarsingh & Starr 2021)" },
			"forewingMm": { "value": 8.6, "source": SRC_BISS_2021, "quality": "primary" },
			"colors": { "body": "#C98A2B", "bands": "#3B2A1A", "wings": "#E8F1F8", "sting": "#6B4A2B" },
		},
	},
	# ── Avispa común (Vespula vulgaris / V. germanica) ──
	{
		"id": "avispa", "group": GROUP, "name": "Avispa común", "title": "Aguijón de avispa común",
		"hv": 9.2, "mohs": 1.5, "E": 0.47, "area": PI * 0.002076 * 0.002076, "alpha": 16.5, "reach": 1.55,
		"curve": 0.2, "mass": 0.0000841, "force": 0.0099, "fBreak": 0.051554,
		"strike": { "v": 0.0031, "m": 0.0000841 }, "col": "#3E3226",
		"desc": "Obrera de Vespula (V. vulgaris y V. germanica). Aguijón curvo de ~1,5 mm útiles con 8 púas pequeñas que el estilete enfunda: pica, inyecta y lo saca para volver a picar. A veces lo deja clavado si la aplastas mientras pica. Fuerza de perforación y radio de la punta estimados (escalados desde la abeja).",
		"source": SRC_DAS_2018 + "; " + SRC_BISS_2021 + "; " + SRC_MULFINGER_1992 + "; " + SRC_KOVAC_2012,
		"quality": "secondary",
		"stinger": {
			"species": "Vespula vulgaris / V. germanica", "family": "Vespidae", "caste": "obrera",
			"shaftMm": { "value": 1.92, "source": SRC_BISS_2021, "quality": "primary", "note": "V. germanica; el aguijón entero de V. vulgaris mide 2,67 ± 0,38 mm (Das 2018)" },
			"insertMm": { "value": 1.55, "source": SRC_DAS_2018, "quality": "primary", "note": "tramo que entra en la piel, ~1,55 mm (V. vulgaris, micro-TC)" },
			"diameterUm": { "value": 142.8, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 64.8, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 2.076, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": 8, "depthUm": 8.6, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": 69.0, "serrationIndex": 0.99, "sheathable": true,
				"source": SRC_BISS_2021 + "; " + SRC_MULFINGER_1992, "quality": "primary",
				"note": "V. germanica: 8 púas, Σ 69 µm, Sr 0,99; el estilete liso, más ancho que las lancetas, las enfunda al retraerlas",
			},
			"material": {
				"tip": { "E": 0.47, "H": 0.09 }, "mid": { "E": 1.32, "H": 0.31 }, "base": { "E": 3.45, "H": 0.56 },
				"dry": true, "source": SRC_DAS_2018, "quality": "primary", "note": "nanoindentación de V. vulgaris (muestras secas, GPa)",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición publicada en Vespula (los 6-8 mN de Zhao 2015 son de Polistes)", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": SRC_MULFINGER_1992, "quality": "secondary", "note": "sin medida; las púas se enfundan y el aguijón sale sin esfuerzo" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "±", "value": false, "survivalH": null, "source": SRC_BISS_2021 + "; " + SRC_MULFINGER_1992 + "; " + SRC_GREENE_2012, "quality": "primary", "why": "lo retira enfundando las púas; en la piel humana a veces se queda (8 púas, Sr ≈ 1), sobre todo si se aparta a la avispa a la fuerza" },
			"angleDeg": { "value": 10.0, "range": null, "kind": "óptimo calculado (MEF)", "source": SRC_DAS_2018, "quality": "secondary" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 0.5, "source": SRC_ZHAO_2015, "quality": "estimate", "note": "como la avispa papelera (~0,5 s)" },
			"venom": { "ug": 3.0, "kind": "por picadura", "pump": "músculo del saco del veneno", "t90S": null, "totalS": 0.5, "source": SRC_SAHINER_2019, "quality": "secondary", "note": "~3 µg de proteína por picadura; el saco se exprime durante la picadura (duración estimada)" },
			"schmidt": { "value": 2.0, "note": "valor del género (V. pensylvanica, «caliente y humeante»)", "source": SRC_SCHMIDT_2016, "quality": "secondary" },
			"wingbeat": { "hz": 165.8, "sdHz": 22.3, "harmonicsHz": [165.8, 330.4, 496.2, 661.9], "powersDb": [-26.1, -32.6, -39.1, -41.0], "source": SRC_HERRERA_2023, "quality": "primary", "note": "V. germanica" },
			"massKg": { "value": 0.0000841, "source": SRC_KOVAC_2012, "quality": "primary", "note": "V. vulgaris 84,1 ± 19,0 mg; V. germanica 74,1 ± 9,6 mg" },
			"bodyMm": { "value": 14.0, "source": "estimación (obrera de 12-16 mm)", "quality": "estimate" },
			"forewingMm": { "value": 9.5, "source": SRC_BISS_2021, "quality": "primary", "note": "V. germanica" },
			"colors": { "body": "#F2C200", "bands": "#1A1A1A", "wings": "#DDE6EE", "sting": "#3E3226" },
		},
	},
	# ── Avispa papelera (Polistes dominula) ──
	{
		"id": "papelera", "group": GROUP, "name": "Avispa papelera", "title": "Aguijón de avispa papelera",
		"hv": 9.2, "mohs": 1.5, "E": 0.47, "area": PI * 0.001712 * 0.001712, "alpha": 16.5, "reach": 1.82,
		"curve": 0.3, "mass": 0.0000898, "force": 0.008, "fBreak": 0.0173193,
		"strike": { "v": 0.0036, "m": 0.0000898 }, "col": "#4A3A28",
		"desc": "Polistes dominula. Aguijón muy curvo con solo 5 púas escondidas bajo el estilete: perfora la piel con 6-8 mN (medido en Polistes), endereza el aguijón al entrar y lo saca sin esfuerzo. Pica de frente o de espaldas doblando el abdomen. Longitud útil, punta y material estimados.",
		"source": SRC_ZHAO_2015 + "; " + SRC_BISS_2021 + "; " + SRC_KAFER_2015 + "; " + SRC_HERRERA_2023,
		"quality": "secondary",
		"stinger": {
			"species": "Polistes dominula", "family": "Vespidae", "caste": "obrera",
			"shaftMm": { "value": 2.37, "source": SRC_BISS_2021, "quality": "primary" },
			"insertMm": { "value": 1.82, "source": SRC_INSERT_RATIO, "quality": "estimate" },
			"diameterUm": { "value": 117.8, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 53.4, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 1.712, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": 5, "depthUm": 4.6, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": 23.0, "serrationIndex": 0.40, "sheathable": true,
				"source": SRC_BISS_2021 + "; " + SRC_ZHAO_2015 + "; " + SRC_MULFINGER_1992, "quality": "primary",
				"note": "5 púas, Σ 23 µm, Sr 0,40; las lancetas se retuercen en espiral y esconden las púas bajo el estilete ancho",
			},
			"material": {
				"tip": { "E": 0.47, "H": 0.09 }, "mid": { "E": 1.32, "H": 0.31 }, "base": { "E": 3.45, "H": 0.56 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de Vespula vulgaris (no hay nanoindentación de Polistes)",
			},
			"insertionN": { "value": 0.007, "range": [0.006, 0.008], "substrate": "piel de cerdo (10-18 mN en gel de sílice)", "source": SRC_ZHAO_2015, "quality": "secondary", "note": "Polistes sp. de Pekín, no necesariamente P. dominula" },
			"extractionN": { "value": null, "range": null, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "cociente extracción/perforación «muy pequeño»" },
			"bucklingN": { "value": null, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "sin medida; en gel de sílice (10-18 mN) el aguijón curvo se dobló mucho" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_BISS_2021 + "; " + SRC_ZHAO_2015, "quality": "primary", "why": "pocas púas pequeñas y escondidas: puede picar una y otra vez" },
			"angleDeg": { "value": 9.0, "range": [18.0, 9.0], "kind": "observado: baja de 18° a 9° mientras entra", "source": SRC_ZHAO_2015, "quality": "secondary" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 0.5, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "~0,5 s, un tercio que la abeja" },
			"venom": { "ug": 10.0, "kind": "por picadura", "pump": "músculo del saco del veneno", "t90S": null, "totalS": 0.5, "source": SRC_VESPID_LABEL, "quality": "secondary", "note": "valor típico de véspido (2-15 µg); sin dato de la especie" },
			"schmidt": { "value": null, "note": "P. dominula no está valorada; las Polistes van de 1,5 a 3", "source": SRC_SCHMIDT_2016, "quality": "secondary" },
			"wingbeat": { "hz": 108.8, "sdHz": 13.3, "harmonicsHz": [108.8, 217.1, 324.8, 432.3], "powersDb": [-22.2, -26.3, -32.5, -33.6], "source": SRC_HERRERA_2023, "quality": "primary" },
			"massKg": { "value": 0.0000898, "source": SRC_KAFER_2015, "quality": "primary", "note": "89,8 ± 15,4 mg" },
			"bodyMm": { "value": 14.7, "source": SRC_ZHAO_2015, "quality": "secondary", "note": "14,7 ± 1,7 mm en Polistes sp." },
			"forewingMm": { "value": 12.4, "source": SRC_BISS_2021, "quality": "primary" },
			"colors": { "body": "#F0B400", "bands": "#1E1A14", "wings": "#D9CFA8", "sting": "#4A3A28" },
		},
	},
	# ── Avispón europeo (Vespa crabro) ──
	{
		"id": "avispon", "group": GROUP, "name": "Avispón europeo", "title": "Aguijón de avispón europeo",
		"hv": 9.2, "mohs": 1.5, "E": 0.47, "area": PI * 0.002978 * 0.002978, "alpha": 16.5, "reach": 2.77,
		"curve": 0.2, "mass": 0.0004775, "force": 0.014, "fBreak": 0.0684364,
		"strike": { "v": 0.0055, "m": 0.0004775 }, "col": "#5A3A22",
		"desc": "Vespa crabro, el avispón autóctono de Europa: casi seis veces más pesado que una avispa común. Aguijón de 3,6 mm con 7 púas, el más largo de las avispas sociales del banco: llega a la grasa del brazo. No se queda clavado. Longitud útil, punta, material y fuerza estimados.",
		"source": SRC_BISS_2021 + "; " + SRC_KOVAC_2012 + "; " + SRC_HERRERA_2023,
		"quality": "estimate",
		"stinger": {
			"species": "Vespa crabro", "family": "Vespidae", "caste": "obrera",
			"shaftMm": { "value": 3.6, "source": SRC_BISS_2021, "quality": "primary" },
			"insertMm": { "value": 2.77, "source": SRC_INSERT_RATIO, "quality": "estimate" },
			"diameterUm": { "value": 204.9, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 92.9, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 2.978, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": 7, "depthUm": 9.7, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": 68.0, "serrationIndex": 0.68, "sheathable": true,
				"source": SRC_BISS_2021 + "; " + SRC_MULFINGER_1992, "quality": "primary", "note": "7 púas, Σ 68 µm, Sr 0,68",
			},
			"material": {
				"tip": { "E": 0.47, "H": 0.09 }, "mid": { "E": 1.32, "H": 0.31 }, "base": { "E": 3.45, "H": 0.56 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de Vespula vulgaris",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": "sin medición", "quality": "estimate" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_BISS_2021, "quality": "primary", "why": "7 púas fuertes, pero los avispones son lo bastante robustos para arrancarlas de la herida" },
			"angleDeg": { "value": null, "range": null, "kind": "", "source": "sin medición", "quality": "estimate" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 0.5, "source": SRC_ZHAO_2015, "quality": "estimate", "note": "como la avispa papelera" },
			"venom": { "ug": 10.0, "kind": "por picadura", "pump": "músculo del saco del veneno", "t90S": null, "totalS": 0.5, "source": SRC_VESPID_LABEL, "quality": "secondary", "note": "valor típico de véspido (2-15 µg); sin dato de la especie" },
			"schmidt": { "value": null, "note": "no aparece en el índice de Schmidt", "source": SRC_SCHMIDT_2016, "quality": "secondary" },
			"wingbeat": { "hz": 115.4, "sdHz": 9.8, "harmonicsHz": [115.4, 229.0, 345.2, 460.9], "powersDb": [-15.5, -21.2, -27.9, -30.4], "source": SRC_HERRERA_2023, "quality": "primary" },
			"massKg": { "value": 0.0004775, "source": SRC_KOVAC_2012, "quality": "primary", "note": "477,5 ± 59,9 mg" },
			"bodyMm": { "value": 25.0, "source": "estimación (obrera de 18-25 mm)", "quality": "estimate" },
			"forewingMm": { "value": 19.1, "source": SRC_BISS_2021, "quality": "primary" },
			"colors": { "body": "#E3B22C", "bands": "#6B3A1E", "wings": "#E2C9A6", "sting": "#5A3A22" },
		},
	},
	# ── Avispa asiática (Vespa velutina, invasora en España) ──
	{
		"id": "velutina", "group": GROUP, "name": "Avispa asiática", "title": "Aguijón de avispa asiática",
		"hv": 9.2, "mohs": 1.5, "E": 0.47, "area": PI * 0.002941 * 0.002941, "alpha": 16.5, "reach": 2.46,
		"curve": 0.2, "mass": 0.00042, "force": 0.014, "fBreak": 0.0824377,
		"strike": { "v": 0.0049, "m": 0.00042 }, "col": "#2B211A",
		"desc": "Vespa velutina, invasora en España y cazadora de abejas a la entrada de las colmenas. Aguijón de 3,2 mm con 7 púas: pasa la dermis del brazo y deja el veneno en la grasa. No se queda clavado. Longitud útil, punta, material y fuerza estimados.",
		"source": SRC_BISS_2021 + "; " + SRC_KENNEDY_2018 + "; " + SRC_HERRERA_2023,
		"quality": "estimate",
		"stinger": {
			"species": "Vespa velutina", "family": "Vespidae", "caste": "obrera",
			"shaftMm": { "value": 3.2, "source": SRC_BISS_2021, "quality": "primary" },
			"insertMm": { "value": 2.46, "source": SRC_INSERT_RATIO, "quality": "estimate" },
			"diameterUm": { "value": 202.3, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 91.8, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 2.941, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": 7, "depthUm": 11.3, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": 79.0, "serrationIndex": 0.80, "sheathable": true,
				"source": SRC_BISS_2021 + "; " + SRC_MULFINGER_1992, "quality": "primary", "note": "7 púas, Σ 79 µm, Sr 0,80",
			},
			"material": {
				"tip": { "E": 0.47, "H": 0.09 }, "mid": { "E": 1.32, "H": 0.31 }, "base": { "E": 3.45, "H": 0.56 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de Vespula vulgaris",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": "sin medición", "quality": "estimate" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_BISS_2021, "quality": "primary", "why": "7 púas y Sr 0,80: por debajo del umbral en el que empieza a quedarse clavado" },
			"angleDeg": { "value": null, "range": null, "kind": "", "source": "sin medición", "quality": "estimate" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 0.5, "source": SRC_ZHAO_2015, "quality": "estimate", "note": "como la avispa papelera" },
			"venom": { "ug": 10.0, "kind": "por picadura", "pump": "músculo del saco del veneno", "t90S": null, "totalS": 0.5, "source": SRC_VESPID_LABEL, "quality": "secondary", "note": "valor típico de véspido (2-15 µg); sin dato de la especie" },
			"schmidt": { "value": null, "note": "no aparece en el índice de Schmidt", "source": SRC_SCHMIDT_2016, "quality": "secondary" },
			"wingbeat": { "hz": 110.8, "sdHz": 22.2, "harmonicsHz": [110.8, 219.8, 331.4, 439.2], "powersDb": [-13.8, -20.7, -26.2, -29.3], "source": SRC_HERRERA_2023, "quality": "primary", "note": "primera medida publicada para la especie" },
			"massKg": { "value": 0.00042, "source": SRC_KENNEDY_2018, "quality": "primary", "note": "obreras grandes de 0,356-0,475 g (las elegidas para llevar radioemisor)" },
			"bodyMm": { "value": 24.0, "source": "estimación (obrera de 20-25 mm)", "quality": "estimate" },
			"forewingMm": { "value": 17.3, "source": SRC_BISS_2021, "quality": "primary" },
			"colors": { "body": "#2B211A", "bands": "#E07B1A", "wings": "#C9B79A", "sting": "#2B211A" },
		},
	},
	# ── Abejorro (Bombus terrestris) ──
	{
		"id": "abejorro", "group": GROUP, "name": "Abejorro", "title": "Aguijón de abejorro",
		"hv": 7.1, "mohs": 1.5, "E": 0.42, "area": PI * 0.00196 * 0.00196, "alpha": 16.5, "reach": 2.07,
		"curve": 0.1, "mass": 0.00027, "force": 0.0093, "fBreak": 0.0212748,
		"strike": { "v": 0.0014, "m": 0.00027 }, "col": "#2A2118",
		"desc": "Obrera de Bombus terrestris. Pariente de la abeja pero sin su trampa: púas pequeñas, pica varias veces y no pierde el aguijón. Casi todo estimado: el aguijón se escala desde la abeja con la masa del insecto (no hemos encontrado medidas publicadas).",
		"source": SRC_HERRERA_2023 + "; " + SRC_KARDUM_2023 + "; " + SRC_RAMIREZ_2023 + "; " + SRC_SCALING,
		"quality": "estimate",
		"stinger": {
			"species": "Bombus terrestris", "family": "Apidae", "caste": "obrera",
			"shaftMm": { "value": 2.84, "source": SRC_SCALING, "quality": "estimate", "note": "abeja × (masa/masa de la abeja)^(1/3)" },
			"insertMm": { "value": 2.07, "source": SRC_SCALING, "quality": "estimate" },
			"diameterUm": { "value": 134.9, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 61.2, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 1.96, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": null, "depthUm": null, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": null, "serrationIndex": null, "sheathable": null,
				"source": "Packer 2003 (Zool. J. Linn. Soc. 138:1-38), vía Bissessarsingh & Starr 2021: las abejas sociales tienen púas", "quality": "secondary",
				"note": "púas pequeñas; sin recuento publicado que hayamos podido verificar",
			},
			"material": {
				"tip": { "E": 0.42, "H": 0.07 }, "mid": { "E": 1.42, "H": 0.22 }, "base": { "E": 3.08, "H": 0.42 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de la abeja (misma familia)",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": "sin medición", "quality": "estimate" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_RAMIREZ_2023, "quality": "secondary", "why": "entre las abejas, la autotomía solo se conoce en el género Apis" },
			"angleDeg": { "value": null, "range": null, "kind": "", "source": "sin medición", "quality": "estimate" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 1.5, "source": SRC_ZHAO_2015, "quality": "estimate", "note": "como la abeja" },
			"venom": { "ug": null, "kind": "por picadura", "pump": "válvulas de las lancetas", "t90S": null, "totalS": null, "source": "sin medición", "quality": "estimate" },
			"schmidt": { "value": 2.0, "note": "valor del género Bombus", "source": SRC_SCHMIDT_2016, "quality": "secondary" },
			"wingbeat": { "hz": 168.6, "sdHz": 30.1, "harmonicsHz": [168.6, 336.7, 503.3, 672.1], "powersDb": [-22.7, -31.9, -37.9, -41.9], "source": SRC_HERRERA_2023, "quality": "primary" },
			"massKg": { "value": 0.00027, "source": SRC_KARDUM_2023, "quality": "secondary", "note": "mediana de las medias por sitio (0,22-0,63 g; obreras conservadas en etanol, Tasmania)" },
			"bodyMm": { "value": 16.0, "source": "estimación (obrera de 11-20 mm)", "quality": "estimate" },
			"forewingMm": { "value": 11.0, "source": "estimación", "quality": "estimate" },
			"colors": { "body": "#161616", "bands": "#E6B422", "wings": "#C8C2B8", "sting": "#2A2118" },
		},
	},
	# ── Hormiga bala (Paraponera clavata) ──
	{
		"id": "hormigabala", "group": GROUP, "name": "Hormiga bala", "title": "Aguijón de hormiga bala",
		"hv": 7.1, "mohs": 1.5, "E": 0.42, "area": PI * 0.002564 * 0.002564, "alpha": 16.5, "reach": 2.71,
		"curve": 0.1, "mass": 0.00013, "force": 0.012, "fBreak": 0.0362945,
		"strike": { "v": 0.0027, "m": 0.00013 }, "col": "#3A1F14",
		"desc": "Paraponera clavata, de las selvas de Centro y Sudamérica: un 4 en el índice de Schmidt («dolor puro, intenso, brillante»). Obrera sin alas: no zumba. La geometría del aguijón y la masa son estimaciones (escaladas desde la abeja con la longitud del cuerpo).",
		"source": SRC_SCHMIDT_2016 + "; " + SRC_ANTWIKI_PARAPONERA + "; " + SRC_SCALING,
		"quality": "estimate",
		"stinger": {
			"species": "Paraponera clavata", "family": "Formicidae", "caste": "obrera",
			"shaftMm": { "value": 3.71, "source": SRC_SCALING, "quality": "estimate", "note": "abeja × 24/11,7 (longitud del cuerpo)" },
			"insertMm": { "value": 2.71, "source": SRC_SCALING, "quality": "estimate" },
			"diameterUm": { "value": 176.4, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 80.0, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 2.564, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": null, "depthUm": null, "maxUm": null, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": null, "serrationIndex": null, "sheathable": null,
				"source": SRC_BISS_2021, "quality": "secondary", "note": "en las hormigas las púas varían mucho; sin datos de la especie",
			},
			"material": {
				"tip": { "E": 0.42, "H": 0.07 }, "mid": { "E": 1.42, "H": 0.22 }, "base": { "E": 3.08, "H": 0.42 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de la abeja (las hormigas son las parientes más cercanas de las abejas)",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": "sin medición", "quality": "estimate" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_RAMIREZ_2023 + "; " + SRC_HERMANN_1971, "quality": "secondary", "why": "entre las hormigas, la autotomía solo se conoce en Pogonomyrmex y pocos géneros más" },
			"angleDeg": { "value": null, "range": null, "kind": "", "source": "sin medición", "quality": "estimate" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 1.0, "source": "estimación", "quality": "estimate" },
			"venom": { "ug": null, "kind": "por picadura", "pump": "", "t90S": null, "totalS": null, "source": "sin medición", "quality": "estimate" },
			"schmidt": { "value": 4.0, "note": "«dolor puro, intenso, brillante» (4+ en 1990)", "source": SRC_SCHMIDT_2016, "quality": "primary" },
			"wingbeat": { "hz": null, "sdHz": null, "harmonicsHz": [], "powersDb": [], "source": SRC_ANTWIKI_PARAPONERA, "quality": "secondary", "note": "las obreras no tienen alas" },
			"massKg": { "value": 0.00013, "source": "estimación: cuerpo de ~25 × 3,5 mm con densidad ~1,1 g/cm³", "quality": "estimate" },
			"bodyMm": { "value": 24.0, "source": SRC_ANTWIKI_PARAPONERA, "quality": "secondary", "note": "18-30 mm" },
			"forewingMm": { "value": null, "source": SRC_ANTWIKI_PARAPONERA, "quality": "secondary", "note": "las obreras no tienen alas" },
			"colors": { "body": "#1C1411", "bands": "#5A2E1C", "wings": "#00000000", "sting": "#3A1F14" },
		},
	},
	# ── Avispa halcón (Pepsis) ──
	{
		"id": "pepsis", "group": GROUP, "name": "Avispa halcón", "title": "Aguijón de avispa halcón",
		"hv": 9.2, "mohs": 1.5, "E": 0.47, "area": PI * 0.004834 * 0.004834, "alpha": 16.5, "reach": 5.38,
		"curve": 0.3, "mass": 0.0006, "force": 0.023, "fBreak": 0.125951,
		"strike": { "v": 0.011, "m": 0.0006 }, "col": "#1B2440",
		"desc": "Pepsis, la avispa que paraliza tarántulas («tarantula hawk» en inglés): aguijón curvo de hasta 7 mm, el más largo del banco, y sin púas (las lancetas de los pompílidos son lisas). Índice de Schmidt 4. Masa, punta, material y fuerza estimados.",
		"source": SRC_SCHMIDT_2016 + "; " + SRC_BRITANNICA_PEPSIS + "; " + SRC_BISS_2021 + "; " + SRC_SCALING,
		"quality": "estimate",
		"stinger": {
			"species": "Pepsis sp.", "family": "Pompilidae", "caste": "hembra",
			"shaftMm": { "value": 7.0, "source": SRC_BRITANNICA_PEPSIS, "quality": "secondary" },
			"insertMm": { "value": 5.38, "source": SRC_INSERT_RATIO, "quality": "estimate" },
			"diameterUm": { "value": 332.6, "source": SRC_SCALING, "quality": "estimate" },
			"canalUm": { "value": 150.8, "source": SRC_SCALING, "quality": "estimate" },
			"tipRadiusUm": { "value": 4.834, "source": SRC_SCALING, "quality": "estimate" },
			"tipAngleDeg": { "value": 33.0, "source": SRC_SCALING, "quality": "estimate", "note": "como la abeja" },
			"barbs": {
				"perLancet": 0, "depthUm": 0.0, "maxUm": 0.0, "firstUm": null, "pitchUm": null, "lengthUm": null,
				"angleDeg": null, "rowHelixDeg": null, "serrationUm": 0.0, "serrationIndex": 0.0, "sheathable": null,
				"source": SRC_BISS_2021, "quality": "secondary", "note": "todos los pompílidos estudiados tienen lancetas lisas, sin púas",
			},
			"material": {
				"tip": { "E": 0.47, "H": 0.09 }, "mid": { "E": 1.32, "H": 0.31 }, "base": { "E": 3.45, "H": 0.56 },
				"dry": true, "source": SRC_DAS_2018, "quality": "estimate", "note": "los de Vespula vulgaris",
			},
			"insertionN": { "value": null, "range": null, "substrate": "", "source": "sin medición", "quality": "estimate" },
			"extractionN": { "value": null, "range": null, "source": "sin medición", "quality": "estimate" },
			"bucklingN": { "value": null, "source": "sin medición", "quality": "estimate" },
			"autotomy": { "class": "−", "value": false, "survivalH": null, "source": SRC_BISS_2021, "quality": "secondary", "why": "sin púas no hay nada que enganchar" },
			"angleDeg": { "value": null, "range": null, "kind": "", "source": "sin medición", "quality": "estimate" },
			"twistDeg": { "value": null, "source": "sin medición", "quality": "estimate" },
			"insertionS": { "value": 0.5, "source": "estimación", "quality": "estimate" },
			"venom": { "ug": null, "kind": "por picadura", "pump": "músculo del saco del veneno", "t90S": null, "totalS": null, "source": "sin medición", "quality": "estimate" },
			"schmidt": { "value": 4.0, "note": "P. grossa: «cegador, feroz, sorprendentemente eléctrico»", "source": SRC_SCHMIDT_2016, "quality": "primary" },
			"wingbeat": { "hz": null, "sdHz": null, "harmonicsHz": [], "powersDb": [], "source": "sin medición", "quality": "estimate" },
			"massKg": { "value": 0.0006, "source": "estimación: cuerpo de ~40 × 6 mm con densidad ~1,1 g/cm³", "quality": "estimate" },
			"bodyMm": { "value": 40.0, "source": "estimación (hembras grandes de Pepsis)", "quality": "estimate" },
			"forewingMm": { "value": null, "source": "sin medición", "quality": "estimate" },
			"colors": { "body": "#1B2440", "bands": "#1B2440", "wings": "#E0782A", "sting": "#1B2440" },
		},
	},
]


## Primera entrada con ese id, o null.
static func find_by_id(id: Variant) -> Variant:
	for s: Dictionary in STINGERS:
		if s.id == id:
			return s
	return null


## Ids de todos los aguijones, en el orden del catálogo.
static func ids() -> Array:
	var out: Array = []
	for s: Dictionary in STINGERS:
		out.append(s.id)
	return out


## ¿Es un aguijón? (una garra con el bloque `stinger`).
static func is_stinger(tool: Variant) -> bool:
	return tool is Dictionary and tool.get("stinger") != null
