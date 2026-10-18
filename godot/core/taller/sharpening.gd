## Taller · afiladora de cuchillos, brocas y fresas: ángulos, abrasivo, granos, velocidad de la muela y riesgo
## térmico. Cada dato lleva su fuente y su calidad (primary · secondary · estimate).
##
## - Cuchillos: ángulo por lado según el estilo (lo que recomiendan los fabricantes, recopilado por Tormek) y
##   ángulo total según el uso (Tormek, Verhoeven 2004, Gränsfors Bruk). El ángulo no se ajusta con la dureza:
##   no hay una fórmula publicada que relacione el ángulo con los HRC.
## - Brocas: ángulo de punta por material (TC 9-524, CERATIZIT, Gühring, GSR, Nachi), incidencia de 8–12° (TC 9-524;
##   Nachi por diámetro), arista transversal de 120–135° (TC 9-524; patente US 4023552) y formas de DIN 1412.
## - Fresas: incidencia primaria y secundaria (Nachi; TC 9-524), hélice por material (Travers) y desplazamiento
##   del dedo de apoyo en la afiladora: 0,0088 × ángulo × diámetro (TC 9-524).
## - Máquina: velocidad periférica v = π·D·n/60 000 (m/s, D en mm, n en rpm) frente a la máxima de una muela
##   vitrificada (EN 12413) y a la recomendada para cada abrasivo (Kraus & Winter, Nachi, Tormek).
## - Abrasivo: Al₂O₃ en acero; CBN por encima de 58 HRC y en acero rápido; diamante (o SiC) en metal duro; nunca
##   diamante para amolar hierro o acero.
## Claves de unión de CONTRATOS.md: abrasivos al2o3 · sic · cbn · diamante; aceros vg10 · x50crmov15 · 14c28n · m2 ·
## 1095. El detalle de cada abrasivo es de la unidad 6: aquí solo se usan sus ids.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")

## Aceros de afilado (dureza, revenido y propiedades térmicas). Viven en sharpening_heat.gd, que los necesita.
const STEELS := Heat.STEELS

## Herramientas que no son de acero: con qué se amolan y por qué no llevan riesgo de revenido.
const TOOL_MATERIALS := {
	"metal_duro": {
		"name": "Metal duro (carburo de wolframio y cobalto)",
		"abrasive_id": "diamante",
		"alternative_id": "sic",
		"reason": "Metal duro: diamante (Haefeli; Kraus & Winter). En esmeriladora sin diamante, SiC verde (Norton 39C; Nachi, GC).",
		"heat_note": "El metal duro no se reviene: su riesgo es la fisuración por calor, que este modelo no calcula. Afila en húmedo o con pasadas ligeras.",
		"source": "Haefeli y Kraus & Winter: el metal duro se amola con diamante; Norton 39C: SiC verde para herramientas de metal duro en esmeriladora",
		"quality": "primary",
	},
}

const SRC_TORMEK_MAKERS := "Tormek, «Knife sharpening angles. Manufacturer's recommendations» (recopila lo que recomienda cada fabricante, por lado)"
const SRC_TORMEK_T8 := "Tormek, T-8 Original: muela SG-250 de 250 × 50 mm a 100 rpm; 90 rpm en las fichas del T-8 anterior y en Verhoeven 2004"
const SRC_TORMEK_SG := "Tormek, SG-250: Al₂O₃, de grano 220 a ≈1000 con el reavivador SP-650"
const SRC_TORMEK_SJ := "Tormek, SJ-250: piedra de agua japonesa de grano 4000"
const SRC_VERHOEVEN := "Verhoeven 2004, «Experiments on knife sharpening» (Iowa State University): tabla 1 y medidas al microscopio electrónico"
const SRC_GRANSFORS := "Gränsfors Bruk, «The Axe Book»: filo de 25–30°"
const SRC_SCALPEL := "Patente US 6330750 B1: los bisturís convencionales se afilan a un ángulo total de «unos 26°»"
const SRC_TC9524_DRILL := "US Army TC 9-524, cap. 4: punta de 118° (59° × 2) en brocas de uso general; incidencia de 8–12°; arista transversal a ≈45° de la línea de los filos"
const SRC_CERATIZIT := "CERATIZIT, geometría de la broca: 118° la mayoría; 130° en materiales blandos y tenaces; 140° en metales ligeros de viruta larga; 90° en plásticos duros que desgastan"
const SRC_GUEHRING_INOX := "Gühring, «Welche Bohrer für Edelstahl?»: punta de 135° (metal duro o HSS de tipo H)"
const SRC_MMS := "Modern Machine Shop, «Choosing the best drill point geometry»: 140° en inoxidable"
const SRC_NACHI_DRILL := "Nachi, datos técnicos de brocas: 118° de uso general y 135° en materiales duros o corte rápido; incidencia de 12°, 10° y 8° para Ø 2–5, 5,1–13 y 13,1–20 mm; bolsillo del adelgazado de 105–110°"
const SRC_US4023552 := "Patente US 4023552 A (afiladora de brocas): arista transversal de 120° a 135°"
const SRC_GSR := "GSR, «Handbuch Bohren»: 118° cónico normal; 135° con afilado en cruz para materiales más duros; hélices H 10–19° (latón), N 19–27° (acero) y W 27–45° (aluminio, cobre)"
const SRC_RUKO := "RUKO, «Spitzenanschliffe und Ausspitzungen»: formas de DIN 1412"
const SRC_NACHI_EM := "Nachi America, «End mill training»: incidencia primaria de 5–9° y secundaria de 14–17°; hélice baja de 10–20° (≥35 HRC), normal de 28–30° y alta de ≥40°"
const SRC_TC9524_MILL := "US Army TC 9-524, cap. 5: incidencia primaria de 3–5° en materiales duros y ≈10° en blandos como el aluminio (7° y 12° por debajo de 3″ de diámetro); secundaria de 20–30°; desplazamiento = 0,0088 × ángulo × diámetro"
const SRC_TRAVERS := "Travers Tool, «Choose the right helix angle»: 0° en latón, cobre, bronce y plásticos abrasivos; 30° en aceros y fundición; 35–40° en inoxidables; 37–45° en aluminio, cobre y plásticos"
const SRC_METABO := "Metabo DS 150 y DS 200: muelas de 150 y 200 mm a 2980 rpm en vacío (50 Hz); TC 9-524, cap. 5: 3450 rpm (60 Hz)"
const SRC_EN12413 := "Muela vitrificada de 200 mm para esmeriladora (WMW Niles): 35 m/s y 3350 rpm como máximo, un escalón de EN 12413; TC 9-524: vitrificadas hasta 6500 SFPM (33 m/s); Norton 38A de 8″: 3600 rpm (≈38 m/s)"
const SRC_KW := "Kraus & Winter, catálogo de muelas de diamante y CBN: CBN para aceros aleados de más de 58 HRC; velocidades de afilado de herramientas con ligante de resina"
const SRC_HAEFELI := "Haefeli, manual técnico: diamante para metal duro, cerámica y vidrio; CBN para HSS, aceros de herramientas y templados; equivalencias FEPA de grano"
const SRC_NACHI_WHEELS := "Nachi, reafilado de fresas: HSS al cobalto con WA60 J/K a 3800–5000 SFPM; HSS al cobalto-vanadio con CBN 120–220; metal duro con diamante D100 (desbaste) y D150–180 (acabado) o SiC verde GC, a 2600–3300 SFPM"
const SRC_NORTON := "Norton: 38A (Al₂O₃ blanco) para aceros rápidos y de herramientas templados y para afilar brocas; 37C y 39C (SiC) para fundición, metal duro y no férricos"
const SRC_MALKIN := "Malkin y Guo 2007, «Thermal analysis of grinding», CIRP Annals 56/2: con CBN solo ≈20 % del calor de amolado va a la pieza, frente al 60–85 % con muelas convencionales"
const SRC_DIAMOND_FE := "Brazda (KAPP), «Hard choices: diamond or CBN?», Gear Solutions 2006: el diamante se oxida por encima de 600 °C y reacciona con el hierro por encima de 700 °C; Zenkin et al. 2018 (Materials): en contacto con hierro empieza a grafitizarse hacia 400 °C"

const QUALITY_RANK := { "primary": 2, "secondary": 1, "estimate": 0 }
const TORMEK_TOTAL_USES := ["cocina", "fileteo", "carnicero"]  # usos en los que manda también la tabla de fabricantes
const MILL_SOFT := ["aluminio"]
const MILL_HARD := ["acero", "acero_duro", "inox", "fundicion"]
const INCH_MM := 25.4

## Ángulos de afilado. Cada entrada numérica lleva min, max (el intervalo citado), value (lo que se recomienda,
## dentro del intervalo), source y quality. Ángulos en grados.
const SHARPENING_ANGLES := {
	"cuchillo": {
		"estilos": {
			"japones": {
				"name": "japonés",
				"min": 9.0,
				"max": 16.0,
				"detail": "por lado: Zwilling (santoku), Miyabi y Kramer 9–12°; Wüsthof asiáticos 10°; Global y MAC 10–15°; Shun y Kai 16°",
				"source": SRC_TORMEK_MAKERS,
				"quality": "secondary",
			},
			"occidental": {
				"name": "occidental",
				"min": 14.0,
				"max": 20.0,
				"detail": "por lado: Wüsthof 14°; Zwilling ≈15°; Messermeister 15°; Victorinox 15–20°; Fischer-Bargoin 15–20°",
				"source": SRC_TORMEK_MAKERS,
				"quality": "secondary",
			},
		},
		# Ángulo total (incluido) por uso.
		"usos": {
			"cocina": {
				"name": "cocina",
				"by_style": {
					"occidental": {
						"min": 30.0,
						"max": 40.0,
						"source": "Tormek, «Knife sharpening»: cuchillos occidentales de cocina, de chef y de carnicero, 30–40° en total",
						"quality": "primary",
					},
					"japones": {
						"min": 25.0,
						"max": 30.0,
						"source": "Tormek, «Knife sharpening»: cuchillos japoneses de acero más duro, 25–30° en total",
						"quality": "primary",
					},
				},
			},
			"fileteo": {
				"name": "fileteo, loncheado y pelado",
				"min": 25.0,
				"max": 30.0,
				"source": "Tormek, «Knife sharpening»: cuchillos de lonchear, filetear y pelar, 25–30° en total",
				"quality": "primary",
			},
			"caza": {
				"name": "caza y exterior",
				"min": 30.0,
				"max": 40.0,
				"source": "Tormek, «Knife sharpening»: cuchillos de caza y deportivos, 30–40° en total",
				"quality": "primary",
			},
			"carnicero": {
				"name": "carnicero",
				"min": 30.0,
				"max": 40.0,
				"source": "Tormek, «Knife sharpening»: los de carnicero van con los occidentales de cocina, 30–40° en total",
				"quality": "primary",
			},
			"cuchilla": {
				"name": "cuchilla de picar",
				"min": 30.0,
				"max": 60.0,
				"source": "Verhoeven 2004, tabla 1: cuchillos de picar, 30–60° en total (cita a Leonard)",
				"quality": "secondary",
			},
			"navaja": {
				"name": "navaja de afeitar",
				"min": 15.0,
				"max": 19.0,
				"source": "Verhoeven 2004, tabla 1: navajas de afeitar medidas, 15–19° en total",
				"quality": "primary",
			},
			"bisturi": {
				"name": "bisturí",
				"min": 26.0,
				"max": 26.0,
				"source": SRC_SCALPEL,
				"quality": "secondary",
			},
			"hacha": {
				"name": "hacha",
				"min": 25.0,
				"max": 30.0,
				"source": SRC_GRANSFORS,
				"quality": "primary",
			},
			"talla": {
				"name": "talla de madera",
				"min": 20.0,
				"max": 25.0,
				"source": "Tormek, «Knife sharpening»: cuchillos de talla, 20–25° en total",
				"quality": "primary",
			},
			"utilidad": {
				"name": "cúter",
				"min": 30.0,
				"max": 30.0,
				"source": "Verhoeven 2004, tabla 1: cuchillas de cúter medidas, 30° en total",
				"quality": "primary",
			},
		},
		# Medida de referencia (no se usa para recomendar): Verhoeven midió 20–30° en cuchillos de cocina y fileteo.
		"cocina_medida": {
			"min": 20.0,
			"max": 30.0,
			"source": "Verhoeven 2004, tabla 1: cuchillos de cocina y fileteo medidos, 20–30° en total; un filo de 10–12° en total se deteriora pronto en cuchillos de cocina de 60 HRC",
			"quality": "primary",
		},
	},
	"broca": {
		# Ángulo de punta por material de la pieza (claves de CONTRATOS.md, más acero_duro y blando_tenaz).
		"punta": {
			"acero": {
				"value": 118.0,
				"min": 118.0,
				"max": 118.0,
				"form": "normal",
				"helix": "N",
				"source": SRC_TC9524_DRILL + "; " + SRC_CERATIZIT + "; " + SRC_GSR,
				"quality": "primary",
			},
			"acero_duro": {
				"value": 135.0,
				"min": 135.0,
				"max": 135.0,
				"form": "C",
				"helix": "N",
				"source": SRC_NACHI_DRILL + "; " + SRC_GSR,
				"quality": "primary",
			},
			"inox": {
				"value": 135.0,
				"min": 135.0,
				"max": 140.0,
				"form": "C",
				"helix": "H",
				"source": SRC_GUEHRING_INOX + "; " + SRC_MMS,
				"quality": "secondary",
			},
			"aluminio": {
				"value": 140.0,
				"min": 140.0,
				"max": 140.0,
				"form": "normal",
				"helix": "W",
				"source": SRC_CERATIZIT + "; " + SRC_GSR,
				"quality": "primary",
			},
			"blando_tenaz": {
				"value": 130.0,
				"min": 130.0,
				"max": 130.0,
				"form": "normal",
				"helix": "",
				"source": SRC_CERATIZIT,
				"quality": "primary",
			},
			"plastico": {
				"value": 90.0,
				"min": 90.0,
				"max": 90.0,
				"form": "normal",
				"helix": "",
				"source": SRC_CERATIZIT,
				"quality": "primary",
			},
			"laton": {
				"value": 118.0,
				"min": 118.0,
				"max": 118.0,
				"form": "normal",
				"helix": "H",
				"source": SRC_TC9524_DRILL + " (en latón y bronce, menos ángulo de desprendimiento para que la broca no «muerda»); " + SRC_GSR,
				"quality": "primary",
			},
			"fundicion": {
				"value": 118.0,
				"min": 118.0,
				"max": 118.0,
				"form": "D",
				"helix": "",
				"source": SRC_TC9524_DRILL + "; " + SRC_RUKO + " (forma D para fundición gris)",
				"quality": "primary",
			},
		},
		"incidencia": {
			"min": 8.0,
			"max": 12.0,
			"source": SRC_TC9524_DRILL,
			"quality": "primary",
		},
		# Incidencia por diámetro (Nachi): hasta d_max (mm), value.
		"incidencia_por_diametro": [
			{ "d_max": 5.0, "value": 12.0, "source": SRC_NACHI_DRILL, "quality": "primary" },
			{ "d_max": 13.0, "value": 10.0, "source": SRC_NACHI_DRILL, "quality": "primary" },
			{ "d_max": 20.0, "value": 8.0, "source": SRC_NACHI_DRILL, "quality": "primary" },
		],
		"arista_transversal": {
			"value": 125.0,
			"min": 120.0,
			"max": 135.0,
			"source": SRC_US4023552 + "; " + SRC_TC9524_DRILL + " (es decir, 135° medido desde el otro lado); en DIN, ψ ≈ 55° (125°)",
			"quality": "primary",
			"note": "Sale sola si la incidencia es correcta: sirve para comprobarla. El ≈110° que a veces se cita es el bolsillo del adelgazado (105–110°, Nachi).",
		},
		"adelgazado": {
			"min": 105.0,
			"max": 110.0,
			"source": SRC_NACHI_DRILL,
			"quality": "primary",
		},
		"din_1412": {
			"normal": { "name": "afilado cónico normal", "use": "acero en general, no férricos y plásticos", "source": SRC_RUKO, "quality": "secondary" },
			"A": { "name": "A · arista transversal acortada", "use": "brocas de diámetro grande", "source": SRC_RUKO, "quality": "secondary" },
			"B": { "name": "B · arista acortada y filo principal corregido", "use": "aceros de alta resistencia", "source": SRC_RUKO, "quality": "secondary" },
			"C": { "name": "C · afilado en cruz (punta partida)", "use": "centra solo y evacua bien la viruta: aceros duros y aleados", "source": SRC_RUKO + "; " + SRC_GSR, "quality": "secondary" },
			"D": { "name": "D · para fundición", "use": "fundición gris", "source": SRC_RUKO, "quality": "secondary" },
			"E": { "name": "E · punta de centrar", "use": "chapa y materiales blandos", "source": SRC_RUKO, "quality": "secondary" },
		},
		"helices": {
			"N": { "name": "N · normal", "min": 19.0, "max": 27.0, "use": "acero", "source": SRC_GSR, "quality": "primary" },
			"H": { "name": "H · hélice corta", "min": 10.0, "max": 19.0, "use": "metales frágiles de viruta corta (latón) y materiales duros (Gühring: inoxidable)", "source": SRC_GSR + "; " + SRC_GUEHRING_INOX, "quality": "primary" },
			"W": { "name": "W · hélice larga", "min": 27.0, "max": 45.0, "use": "metales blandos de viruta larga (aluminio, cobre)", "source": SRC_GSR, "quality": "primary" },
		},
	},
	"fresa": {
		"incidencia_primaria": {
			"value": 7.0,
			"min": 5.0,
			"max": 9.0,
			"source": SRC_NACHI_EM,
			"quality": "primary",
		},
		"incidencia_secundaria": {
			"value": 15.0,
			"min": 14.0,
			"max": 17.0,
			"source": SRC_NACHI_EM,
			"quality": "primary",
		},
		# TC 9-524 por dureza del material y tamaño (3″ = 76,2 mm).
		"incidencia_tc9524": {
			"duro": { "value": 7.0, "min": 7.0, "max": 7.0, "source": SRC_TC9524_MILL, "quality": "primary" },
			"duro_grande": { "value": 4.0, "min": 3.0, "max": 5.0, "source": SRC_TC9524_MILL, "quality": "primary" },
			"blando": { "value": 12.0, "min": 12.0, "max": 12.0, "source": SRC_TC9524_MILL, "quality": "primary" },
			"blando_grande": { "value": 10.0, "min": 10.0, "max": 10.0, "source": SRC_TC9524_MILL, "quality": "primary" },
			"secundaria": { "value": 30.0, "min": 20.0, "max": 30.0, "source": SRC_TC9524_MILL + " (fresas de disco)", "quality": "primary" },
		},
		# Hélice de la fresa que conviene para cada material (se elige al comprarla; el afilado la respeta).
		"helice": {
			"laton": { "value": 0.0, "min": 0.0, "max": 0.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"acero": { "value": 30.0, "min": 30.0, "max": 30.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"fundicion": { "value": 30.0, "min": 30.0, "max": 30.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"inox": { "value": 38.0, "min": 35.0, "max": 40.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"aluminio": { "value": 40.0, "min": 37.0, "max": 45.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"plastico": { "value": 40.0, "min": 37.0, "max": 45.0, "source": SRC_TRAVERS, "quality": "secondary" },
			"acero_duro": { "value": 15.0, "min": 10.0, "max": 20.0, "source": SRC_NACHI_EM, "quality": "primary" },
		},
	},
}

## Máquinas de afilar. Diámetros en mm, giro en rpm, velocidades en m/s.
const SHARPENING_MACHINES := {
	"tormek_t8": {
		"name": "Tormek T-8",
		"kind": "lenta_humeda",
		"wheel_diameter_mm": { "value": 250.0, "source": SRC_TORMEK_T8, "quality": "primary" },
		"rpm": { "value": 100.0, "min": 90.0, "max": 100.0, "source": SRC_TORMEK_T8, "quality": "primary" },
		"wet": true,
		"wheel_abrasive_id": "al2o3",
	},
	"esmeriladora_banco": {
		"name": "Esmeriladora de banco",
		"kind": "banco",
		"wheel_diameter_mm": { "value": 200.0, "min": 150.0, "max": 200.0, "source": SRC_METABO, "quality": "primary" },
		"rpm": { "value": 2980.0, "min": 2980.0, "max": 3450.0, "source": SRC_METABO, "quality": "primary" },
		"wet": false,
		"wheel_abrasive_id": "al2o3",
	},
	"afiladora_universal": {
		"name": "Afiladora universal de herramientas (muela de copa)",
		"kind": "universal",
		"wheel_diameter_mm": {
			"value": 125.0,
			"min": 75.0,
			"max": 125.0,
			"source": "Kraus & Winter: muelas de copa 11V9 de 75, 100 y 125 mm (se toma la de 125 mm si no se indica)",
			"quality": "primary",
		},
		"rpm": null,
		"wet": false,
		"wheel_abrasive_id": "",
	},
}

## Velocidad máxima de una muela vitrificada de Al₂O₃ o SiC (m/s). Se comprueba con la muela montada (la de
## serie o la de req.wheel_abrasive_id) o, si la máquina no trae ninguna, con la convencional que se recomienda.
## Las de CBN y diamante llevan su propia velocidad marcada.
const VITRIFIED_MAX_SPEED := { "value": 35.0, "source": SRC_EN12413, "quality": "primary" }
const CONVENTIONAL := ["al2o3", "sic"]
const ABRASIVE_IDS := ["al2o3", "sic", "cbn", "diamante"]

## Velocidad periférica recomendada (m/s) para amolar herramientas, por abrasivo y ligante.
const SPEED_RANGES := {
	"al2o3": {
		"min": 19.3,
		"max": 25.4,
		"source": "Nachi: reafilado de HSS al cobalto con muela WA60 J/K a 3800–5000 SFPM (19,3–25,4 m/s)",
		"quality": "primary",
	},
	"sic": {
		"min": 13.2,
		"max": 16.8,
		"source": "Nachi: reafilado de metal duro con muela GC de 60–120 a 2600–3300 SFPM (13,2–16,8 m/s)",
		"quality": "primary",
	},
	"cbn_seco": {
		"min": 16.0,
		"max": 28.0,
		"source": "Kraus & Winter: CBN con ligante de resina, afilado de herramientas en seco, 16–28 m/s",
		"quality": "primary",
	},
	"cbn_humedo": {
		"min": 25.0,
		"max": 35.0,
		"source": "Kraus & Winter: CBN con ligante de resina, afilado de herramientas en húmedo, 25–35 m/s",
		"quality": "primary",
	},
	"diamante_seco": {
		"min": 16.0,
		"max": 22.0,
		"source": "Kraus & Winter: diamante con ligante de resina para metal duro, afilado de herramientas en seco, 16–22 m/s",
		"quality": "primary",
	},
	"diamante_humedo": {
		"min": 25.0,
		"max": 30.0,
		"source": "Kraus & Winter: diamante con ligante de resina para metal duro, afilado de herramientas en húmedo, 25–30 m/s",
		"quality": "primary",
	},
}

## Pasos de las progresiones de grano. process: "amolado" (la muela arranca metal) o "asentado" (pulir y quitar
## la rebaba, casi sin arrancar). abrasive_id vacío si la fuente no dice el abrasivo o no es uno de los cuatro.
const GRIT_STEPS := {
	"tormek_sg_220": { "step": "reperfilar", "grit": "SG-250 a grano 220", "abrasive_id": "al2o3", "process": "amolado", "source": SRC_TORMEK_SG, "quality": "primary" },
	"tormek_sg_1000": { "step": "afilar", "grit": "SG-250 afinada a ≈1000 con el SP-650", "abrasive_id": "al2o3", "process": "amolado", "source": SRC_TORMEK_SG, "quality": "primary" },
	"tormek_cbn_160": { "step": "reperfilar", "grit": "CBN 160, muela de 250 mm para el T-8, en húmedo", "abrasive_id": "cbn", "process": "amolado", "source": "Muelas de CBN de 250 mm para Tormek T-8 (p. ej., Forever Superabrasives, UF-Sharp): granos de 80 a 1000, en agua", "quality": "secondary" },
	"tormek_cbn_400": { "step": "afilar", "grit": "CBN 400", "abrasive_id": "cbn", "process": "amolado", "source": "Muelas de CBN de 250 mm para Tormek T-8 (p. ej., Forever Superabrasives, UF-Sharp): granos de 80 a 1000, en agua", "quality": "secondary" },
	"tormek_cbn_1000": { "step": "afinar", "grit": "CBN 1000", "abrasive_id": "cbn", "process": "amolado", "source": "Muelas de CBN de 250 mm para Tormek T-8 (p. ej., Forever Superabrasives, UF-Sharp): granos de 80 a 1000, en agua", "quality": "secondary" },
	"tormek_sj_4000": { "step": "afinar", "grit": "SJ-250, piedra de agua japonesa de grano 4000", "abrasive_id": "", "process": "amolado", "source": SRC_TORMEK_SJ, "quality": "primary" },
	"cuero_cromo": { "step": "asentar", "grit": "rueda o asentador de cuero con óxido de cromo", "abrasive_id": "", "process": "asentado", "source": SRC_VERHOEVEN + " (el cuero limpio apenas hace nada; con óxido de cromo quita la rebaba)", "quality": "primary" },
	"piedras_mano": { "step": "afinar a mano", "grit": "piedras de agua de 1000 y de 6000–8000", "abrasive_id": "", "process": "asentado", "source": SRC_VERHOEVEN + " (piedras japonesas de 6000–8000: rebaba de ≈0,5 µm)", "quality": "primary" },
	"banco_grueso": { "step": "desbastar", "grit": "muela vitrificada de grano 46–60", "abrasive_id": "al2o3", "process": "amolado", "source": "TC 9-524, cap. 5: una muela gruesa para desbastar y otra fina para acabar; " + SRC_NORTON + " (38A de grano 46 y 60)", "quality": "primary" },
	"banco_fino": { "step": "acabar", "grit": "muela vitrificada fina (grano 80–120)", "abrasive_id": "al2o3", "process": "amolado", "source": "TC 9-524, cap. 5: muela fina para acabar (el grano 80–120 es una estimación)", "quality": "estimate" },
	"cbn_120": { "step": "desbastar", "grit": "CBN de malla 120 (B126)", "abrasive_id": "cbn", "process": "amolado", "source": SRC_NACHI_WHEELS + "; " + SRC_HAEFELI, "quality": "primary" },
	"cbn_220": { "step": "acabar", "grit": "CBN de malla 220 (B64–B76)", "abrasive_id": "cbn", "process": "amolado", "source": SRC_NACHI_WHEELS + "; " + SRC_HAEFELI, "quality": "primary" },
	"wa_60": { "step": "afilar", "grit": "WA (Al₂O₃ blanco) 60 J/K", "abrasive_id": "al2o3", "process": "amolado", "source": SRC_NACHI_WHEELS, "quality": "primary" },
	"wa_80": { "step": "acabar", "grit": "WA 80 K", "abrasive_id": "al2o3", "process": "amolado", "source": SRC_NACHI_WHEELS, "quality": "primary" },
	"diamante_100": { "step": "desbastar", "grit": "diamante de malla 100 (D151), ligante de resina", "abrasive_id": "diamante", "process": "amolado", "source": SRC_NACHI_WHEELS + "; " + SRC_HAEFELI, "quality": "primary" },
	"diamante_180": { "step": "acabar", "grit": "diamante de malla 150–180 (D76–D91)", "abrasive_id": "diamante", "process": "amolado", "source": SRC_NACHI_WHEELS + "; " + SRC_HAEFELI, "quality": "primary" },
	"gc_80": { "step": "desbastar", "grit": "SiC verde (GC) 60–80", "abrasive_id": "sic", "process": "amolado", "source": SRC_NACHI_WHEELS, "quality": "primary" },
	"gc_120": { "step": "acabar", "grit": "SiC verde (GC) 100–120", "abrasive_id": "sic", "process": "amolado", "source": SRC_NACHI_WHEELS, "quality": "primary" },
	"piedra_rebaba": { "step": "quitar la rebaba", "grit": "piedra de aceite fina, a mano", "abrasive_id": "", "process": "asentado", "source": "TC 9-524, cap. 5: tras amolar, asentar los filos con una piedra de aceite fina para quitar la rebaba", "quality": "primary" },
}

## Anchura del filo final (µm) medida al microscopio electrónico por Verhoeven (2004), según el último paso.
const EDGE_FINISH := {
	"diamante_1um_cuero": {
		"name": "cuero con diamante de 1 µm (12–15 pasadas)",
		"value": 0.31,
		"min": 0.23,
		"max": 0.40,
		"source": "Verhoeven 2004, tabla 6: 0,31 ± 0,06 µm; el grano previo (220, 600 o 1000) no cambia el resultado si hay pasadas suficientes",
		"quality": "primary",
	},
	"piedra_agua_cuero": {
		"name": "piedra de agua y cuero con óxido de cromo",
		"value": 0.35,
		"min": 0.35,
		"max": 0.5,
		"source": "Verhoeven 2004: piedra de agua del Tormek y rueda de cuero con óxido de cromo, ≈0,35 µm (fig. 33); piedras de 6000–8000 y cuero con óxido de cromo, 0,4–0,5 µm",
		"quality": "primary",
	},
	"piedras_mano_cuero": {
		"name": "piedras de agua de 6000–8000 y asentador de cuero con óxido de cromo",
		"value": 0.45,
		"min": 0.4,
		"max": 0.5,
		"source": "Verhoeven 2004: piedra de agua de 6000 y asentador de cuero con óxido de cromo, rebaba de 0,4–0,5 µm (fig. 26)",
		"quality": "primary",
	},
	"piedra_agua": {
		"name": "piedra de agua de 6000–8000",
		"value": 0.5,
		"min": 0.5,
		"max": 0.5,
		"source": "Verhoeven 2004: piedras de agua japonesas de 6000–8000, rebaba de ≈0,5 µm",
		"quality": "primary",
	},
	"muela_220_cuero": {
		"name": "muela de grano 220 y cuero con óxido de cromo",
		"value": 0.8,
		"min": 0.8,
		"max": 0.8,
		"source": "Verhoeven 2004: muela de 220 del Tormek y rueda de cuero con óxido de cromo, ≈0,8 µm (fig. 32)",
		"quality": "primary",
	},
	"muela_1000": {
		"name": "muela de grano 1000 (en húmedo)",
		"value": 1.25,
		"min": 1.0,
		"max": 1.5,
		"source": "Verhoeven 2004: muelas de grano 1000 de la Tru Hone, en húmedo, 1–1,5 µm",
		"quality": "primary",
	},
	"chaira_tras_600": {
		"name": "chaira tras muela de grano 600 o más gruesa",
		"value": 1.75,
		"min": 1.5,
		"max": 2.0,
		"source": "Verhoeven 2004: la chaira pasa el filo de 2–3 µm de la muela de 600 a 1,5–2 µm",
		"quality": "primary",
	},
	"muela_600": {
		"name": "muela de grano 600",
		"value": 2.5,
		"min": 2.0,
		"max": 3.0,
		"source": "Verhoeven 2004: muelas de óxido de aluminio de grano 600, 2–3 µm",
		"quality": "primary",
	},
	"muela_200": {
		"name": "muela de grano 200–220",
		"value": 3.0,
		"min": 2.0,
		"max": 4.0,
		"source": "Verhoeven 2004: muelas de óxido de aluminio de grano 200, 2–4 µm",
		"quality": "primary",
	},
	"cuchilla_afeitar": {
		"name": "hoja de afeitar (referencia)",
		"value": 0.4,
		"min": 0.35,
		"max": 0.45,
		"source": "Verhoeven 2004: hoja Gillette de doble filo, 0,35–0,45 µm; navaja de Solingen, ≈0,4 µm",
		"quality": "primary",
	},
}

## Ensayo de corte ISO 8442-5 (método CATRA) para cuchillos de cocina.
const ISO_8442_5 := {
	"load_n": 50.0,
	"stroke_mm": 40.0,
	"speed_mm_s": 50.0,
	"card_silica_pct": 5.0,
	"cycles": 60,
	"cycles_serrated": 200,
	"icp_strokes": 3,
	"icp_min_mm": 50.0,
	"tcc_min_mm": 150.0,
	"tcc_min_serrated_mm": 1500.0,
	"source": "ISO 8442-5:2004, método CATRA. CATRA, «Automatic Edge Tester»: 50 N, carrera de 40 mm, 50 mm/s, cartulina con 5 % de sílice. Arcos, «Ensayos de corte»: 60 ciclos; ICP (corte de los 3 primeros ciclos) ≥ 50 mm; TCC (corte total) ≥ 150 mm en filo liso; 200 ciclos y 1500 mm en filo dentado",
	"quality": "secondary",
}

## Cómo se afila de forma nominal, para el riesgo térmico de la recomendación (se puede cambiar en «operation»).
const NOMINAL_OPERATION := {
	"hand_force_n": {
		"value": 10.0,
		"source": "estimación: presión ligera de la mano (≈1 kgf); no hay medición publicada de la fuerza al afilar",
		"quality": "estimate",
	},
	"force_ratio": {
		"value": 0.325,
		"min": 0.25,
		"max": 0.40,
		"source": "Biro, Hagan y Gustafson (Saint-Gobain Abrasives), SME 2019: μ = Ft/Fn de 0,25 a 0,40 en la mayoría de aceros; potencia = Ft·Vs",
		"quality": "secondary",
	},
	"contact_area_mm2": {
		"value": 10.0,
		"source": "estimación: ≈1 mm de bisel por 10 mm de filo apoyados en la muela",
		"quality": "estimate",
	},
	"sweep_ms": {
		"value": 0.025,
		"source": "estimación a partir de Verhoeven 2004, que pasaba la hoja por la rueda del Tormek a ≈1 pulgada por segundo",
		"quality": "estimate",
	},
	"dwell_s": {
		"value": 5.0,
		"source": "estimación: 5 s seguidos sobre la muela",
		"quality": "estimate",
	},
}

## Coeficiente de desgaste de Archard para arrancar la rebaba en la piedra.
const BURR_WEAR_K := {
	"value": 1.0e-3,
	"source": "estimación: no hay medición del coeficiente de Archard para rebabas de afilado; orden de magnitud del desgaste abrasivo con abrasivo fino",
	"quality": "estimate",
}


## Velocidad periférica (m/s) de una muela de d_mm milímetros a rpm vueltas por minuto.
static func peripheral_speed(d_mm: float, rpm: float) -> float:
	return PI * d_mm * rpm / 60000.0


## Giro (rpm) que da la velocidad periférica v_ms con una muela de d_mm milímetros.
static func rpm_for_speed(v_ms: float, d_mm: float) -> float:
	return v_ms * 60000.0 / (PI * d_mm)


## Anchura del bisel (mm) de una hoja de espesor t_mm tras el bisel, con per_side_deg grados por lado:
## w = (t/2)/sin β. Un ángulo menor da un bisel más ancho.
static func bevel_width(t_mm: float, per_side_deg: float) -> float:
	var s := sin(deg_to_rad(per_side_deg))
	if s <= 0.0:
		return INF
	return (t_mm / 2.0) / s


## Desplazamiento (mm) del dedo de apoyo en la afiladora de fresas para una incidencia de angle_deg grados:
## 0,0088 × ángulo × D (TC 9-524). D es el diámetro de la muela recta o, con muela de copa, el de la fresa.
static func cutter_grinder_offset(angle_deg: float, d_mm: float) -> float:
	return 0.0088 * angle_deg * d_mm


## El mismo desplazamiento sin aproximar: (D/2)·sen α. La regla de TC 9-524 redondea π/360 = 0,00873 a 0,0088.
static func cutter_grinder_offset_exact(angle_deg: float, d_mm: float) -> float:
	return d_mm / 2.0 * sin(deg_to_rad(angle_deg))


## Veredicto de ISO 8442-5: ICP (corte de los 3 primeros ciclos) y TCC (corte total), en mm.
static func iso8442_verdict(icp_mm: float, tcc_mm: float, serrated: bool = false) -> Dictionary:
	var icp_min: float = ISO_8442_5["icp_min_mm"]
	var tcc_min: float = ISO_8442_5["tcc_min_serrated_mm"] if serrated else ISO_8442_5["tcc_min_mm"]
	var icp_ok := icp_mm >= icp_min
	var tcc_ok := tcc_mm >= tcc_min
	var icp_txt := _fmt_pair(icp_mm, icp_min, 1)
	var tcc_txt := _fmt_pair(tcc_mm, tcc_min, 1)
	var parts: Array[String] = []
	parts.append("ICP %s mm %s %s mm" % [icp_txt[0], "≥" if icp_ok else "<", icp_txt[1]])
	parts.append("TCC %s mm %s %s mm" % [tcc_txt[0], "≥" if tcc_ok else "<", tcc_txt[1]])
	var passed := icp_ok and tcc_ok
	return {
		"passed": passed,
		"icp_ok": icp_ok,
		"tcc_ok": tcc_ok,
		"icp_min_mm": icp_min,
		"tcc_min_mm": tcc_min,
		"message": ("Aprueba: " if passed else "Suspende: ") + " y ".join(parts) + ".",
		"source": ISO_8442_5["source"],
		"quality": ISO_8442_5["quality"],
	}


## Pasadas para arrancar una rebaba por abrasión, con la ley de Archard de core/shared/abrasion.gd.
## p = { burr_height_um, burr_thickness_um, edge_length_mm, load_n, stroke_mm, hardness_mpa, k (opcional) }.
## Solo cuenta la abrasión: en la práctica la rebaba también se dobla y se rompe (Verhoeven 2004), así que el
## número de pasadas es una cota superior.
static func burr_removal(p: Dictionary) -> Dictionary:
	var volume := _num(p, "burr_height_um", 0.0) * 1e-3 * _num(p, "burr_thickness_um", 0.0) * 1e-3 * _num(p, "edge_length_mm", 0.0)
	var k := _num(p, "k", BURR_WEAR_K["value"])
	var per_stroke := Abrasion.archard_wear(_num(p, "load_n", 0.0), _num(p, "stroke_mm", 0.0), _num(p, "hardness_mpa", 0.0), k)
	var strokes: Variant = null
	if per_stroke > 0.0:
		strokes = int(ceilf(volume / per_stroke))
	return {
		"volume_mm3": volume,
		"wear_per_stroke_mm3": per_stroke,
		"strokes": strokes,
		"k": k,
		"source": "Ley de Archard (core/shared/abrasion.gd); k: " + str(BURR_WEAR_K["source"]),
		"quality": "estimate",
		"note": "Solo cuenta la abrasión; la rebaba también se dobla y se rompe, así que es una cota superior de las pasadas.",
	}


## Ángulos de un cuchillo según tool.style ("occidental" | "japones") y tool.use (una clave de usos). El ángulo
## total sale del uso; en cocina, fileteo y carnicero se cruza con el intervalo de los fabricantes del estilo.
## Con tool.thickness_mm (espesor tras el bisel) da también la anchura del bisel.
static func knife_angles(tool: Dictionary) -> Dictionary:
	var knife: Dictionary = SHARPENING_ANGLES["cuchillo"]
	var styles: Dictionary = knife["estilos"]
	var uses: Dictionary = knife["usos"]
	var warnings: Array[String] = []
	var style := _str(tool, "style", "occidental")
	if not styles.has(style):
		warnings.append("Estilo «%s» desconocido: se usa el occidental." % style)
		style = "occidental"
	var use := _str(tool, "use", "cocina")
	if not uses.has(use):
		warnings.append("Uso «%s» desconocido: se usa el de cocina." % use)
		use = "cocina"
	var use_entry: Dictionary = uses[use]
	var inc: Dictionary = use_entry["by_style"][style] if use_entry.has("by_style") else use_entry
	var lo: float = inc["min"] / 2.0
	var hi: float = inc["max"] / 2.0
	var sources: Array[String] = [str(inc["source"])]
	var quality := str(inc["quality"])
	var style_entry: Dictionary = styles[style]
	var maker: Variant = null
	if use in TORMEK_TOTAL_USES:
		maker = style_entry.duplicate(true)
		var s_lo: float = style_entry["min"]
		var s_hi: float = style_entry["max"]
		if maxf(lo, s_lo) <= minf(hi, s_hi):
			lo = maxf(lo, s_lo)
			hi = minf(hi, s_hi)
			sources.append(str(style_entry["source"]))
			quality = _worst(quality, str(style_entry["quality"]))
		else:
			warnings.append("El ángulo del uso no coincide con el de los fabricantes del estilo: manda el uso.")
	var per_side := clampf(Js.js_round(lo + hi) / 2.0, lo, hi)  # centro del intervalo, redondeado a 0,5°
	var source := "; ".join(sources)
	var out := {
		"style": style,
		"use": use,
		"use_name": str(use_entry["name"]),
		"per_side": { "value": per_side, "min": lo, "max": hi, "source": source, "quality": quality },
		"included": { "value": 2.0 * per_side, "min": 2.0 * lo, "max": 2.0 * hi, "source": source, "quality": quality },
		"maker_per_side": maker,
		"note": "El ángulo sale del estilo y del uso; no se ajusta con la dureza porque no hay una fórmula publicada que relacione el ángulo con los HRC.",
		"warnings": warnings,
	}
	var t := _num(tool, "thickness_mm", 0.0)
	if t > 0.0:
		out["bevel_width_mm"] = {
			"value": bevel_width(t, per_side),
			"source": "geometría del bisel: w = (t/2)/sen β",
			"quality": "primary",
		}
	return out


## Ángulos de una broca para tool.work_material (clave de material de CONTRATOS.md) y tool.diameter_mm.
static func drill_angles(tool: Dictionary) -> Dictionary:
	var drill: Dictionary = SHARPENING_ANGLES["broca"]
	var points: Dictionary = drill["punta"]
	var warnings: Array[String] = []
	var work := _str(tool, "work_material", "acero")
	var point: Dictionary
	if points.has(work):
		point = points[work]
	else:
		point = points["acero"]
		warnings.append("No hay en las fuentes verificadas un ángulo de punta para «%s»: se da el de uso general (118°)." % work)
	var d := _num(tool, "diameter_mm", 0.0)
	var general: Dictionary = drill["incidencia"]
	var clearance := {
		"value": 10.0,
		"min": general["min"],
		"max": general["max"],
		"source": general["source"],
		"quality": general["quality"],
	}
	if d > 0.0:
		var rows: Array = drill["incidencia_por_diametro"]
		var row: Dictionary = rows[rows.size() - 1]
		for r in rows:
			if d <= r["d_max"]:
				row = r
				break
		clearance["value"] = row["value"]
		clearance["source"] = "%s; %s" % [row["source"], general["source"]]
		if d < 2.0 or d > 20.0:
			warnings.append("Nachi da la incidencia para Ø 2–20 mm: fuera de ese intervalo se usa el valor del extremo.")
	var form_key := str(point["form"])
	var helix_key := str(point["helix"])
	var helix: Variant = null
	if helix_key != "":
		helix = drill["helices"][helix_key].duplicate(true)
		helix["type"] = helix_key
	else:
		warnings.append("Las fuentes verificadas no dan un tipo de hélice (N, H o W) para «%s»." % work)
	var form: Dictionary = drill["din_1412"][form_key].duplicate(true)
	form["type"] = form_key
	return {
		"work_material": work,
		"point": _pick(point),
		"clearance": clearance,
		"chisel_edge": _pick(drill["arista_transversal"]),
		"thinning_pocket": drill["adelgazado"].duplicate(true),
		"din_1412": form,
		"helix": helix,
		"warnings": warnings,
	}


## Ángulos de una fresa de mango para tool.work_material y tool.diameter_mm, con el desplazamiento del dedo de
## apoyo para la incidencia primaria (muela de copa: diámetro de la fresa).
static func mill_angles(tool: Dictionary) -> Dictionary:
	var mill: Dictionary = SHARPENING_ANGLES["fresa"]
	var tc: Dictionary = mill["incidencia_tc9524"]
	var warnings: Array[String] = []
	var work := _str(tool, "work_material", "acero")
	var d := _num(tool, "diameter_mm", 0.0)
	var small := d < 3.0 * INCH_MM
	var primary: Dictionary
	if work in MILL_SOFT:
		primary = tc["blando"] if small else tc["blando_grande"]
	elif work in MILL_HARD:
		primary = tc["duro"] if small else tc["duro_grande"]
	else:
		primary = mill["incidencia_primaria"]
		warnings.append("TC 9-524 no da la incidencia para «%s»: se usa el intervalo general de Nachi (5–9°)." % work)
	var helix: Variant = null
	if mill["helice"].has(work):
		helix = _pick(mill["helice"][work])
	else:
		warnings.append("Las fuentes verificadas no dan la hélice de fresa para «%s»." % work)
	var offset: Variant = null
	if d > 0.0:
		var a: float = primary["value"]
		offset = {
			"value": cutter_grinder_offset(a, d),
			"exact": cutter_grinder_offset_exact(a, d),
			"angle_deg": a,
			"diameter_mm": d,
			"source": SRC_TC9524_MILL,
			"quality": "primary",
			"note": "Con muela de copa: el diámetro es el de la fresa y el dedo queda por debajo de su eje. Con muela recta, el de la muela (TC 9-524).",
		}
	else:
		warnings.append("Sin diámetro de la fresa no se puede calcular el desplazamiento del dedo de apoyo.")
	return {
		"work_material": work,
		"primary_clearance": _pick(primary),
		"secondary_clearance": _pick(mill["incidencia_secundaria"]),
		"helix": helix,
		"offset_mm": offset,
		"warnings": warnings,
	}


## Abrasivo para amolar una herramienta de material_id (un acero de STEELS, un material de TOOL_MATERIALS o un
## acero sin datos) con hrc de dureza (HRC, la escala en la que publican los fabricantes y la regla de 58 HRC).
## Devuelve { abrasive_id, alternative_id, reason, source, quality }. Nunca diamante para hierro o acero.
static func choose_abrasive(material_id: String, hrc: float) -> Dictionary:
	if TOOL_MATERIALS.has(material_id):
		var m: Dictionary = TOOL_MATERIALS[material_id]
		return {
			"abrasive_id": m["abrasive_id"],
			"alternative_id": m["alternative_id"],
			"reason": m["reason"],
			"source": SRC_HAEFELI + "; " + SRC_KW + "; " + SRC_NORTON,
			"quality": m["quality"],
		}
	var never := " Nunca diamante para amolar acero: se oxida por encima de 600 °C y reacciona con el hierro por encima de 700 °C (Brazda 2006); en contacto con hierro empieza a grafitizarse hacia 400 °C (Zenkin et al. 2018)."
	var steel: Dictionary = STEELS.get(material_id, {})
	if steel.get("family", "") == "acero rápido":
		return {
			"abrasive_id": "cbn",
			"alternative_id": "al2o3",
			"reason": "Acero rápido: CBN (Haefeli; Nachi con el HSS al cobalto-vanadio); también sirve Al₂O₃ blanco, WA (Nachi; Norton 38A). Con CBN solo ≈20 % del calor pasa a la herramienta, frente al 60–85 % con muelas convencionales (Malkin y Guo 2007)." + never,
			"source": SRC_HAEFELI + "; " + SRC_NACHI_WHEELS + "; " + SRC_MALKIN + "; " + SRC_DIAMOND_FE,
			"quality": "primary",
		}
	if hrc > 58.0:
		return {
			"abrasive_id": "cbn",
			"alternative_id": "al2o3",
			"reason": "Acero de %s HRC, por encima de 58: CBN (Kraus & Winter). Solo ≈20 %% del calor pasa a la herramienta, frente al 60–85 %% con Al₂O₃ (Malkin y Guo 2007)." % _fmt(hrc, 1) + never,
			"source": SRC_KW + "; " + SRC_MALKIN + "; " + SRC_DIAMOND_FE,
			"quality": "primary",
		}
	return {
		"abrasive_id": "al2o3",
		"alternative_id": "cbn",
		"reason": "Acero de hasta 58 HRC: óxido de aluminio (Norton 38A; TC 9-524; muela SG-250 de Tormek)." + never,
		"source": SRC_NORTON + "; " + SRC_TC9524_DRILL + "; " + SRC_TORMEK_SG + "; " + SRC_DIAMOND_FE,
		"quality": "primary",
	}


## Progresión de granos para una herramienta de kind en la máquina machine_id con el abrasivo abrasive_id.
## Devuelve [pasos, clave del filo final en EDGE_FINISH o ""].
static func grit_progression(kind: String, machine_id: String, abrasive_id: String) -> Array:
	var keys: Array[String] = []
	var finish := ""
	var machine_kind := str(SHARPENING_MACHINES.get(machine_id, {}).get("kind", "banco"))
	if machine_kind == "lenta_humeda" and not (abrasive_id in ["al2o3", "cbn"]):
		# No hay muelas de diamante ni de SiC con fuente para la máquina lenta: progresión de afiladora universal.
		machine_kind = "universal"
	if machine_kind == "lenta_humeda":
		if abrasive_id == "cbn":
			keys.assign(["tormek_cbn_160", "tormek_cbn_400", "tormek_cbn_1000"])
		else:
			keys.assign(["tormek_sg_220", "tormek_sg_1000"])
		if kind == "cuchillo":
			keys.append_array(["tormek_sj_4000", "cuero_cromo"])
			finish = "piedra_agua_cuero"
		else:
			keys.append("piedra_rebaba")
	else:
		match abrasive_id:
			"cbn":
				keys.assign(["cbn_120", "cbn_220"])
			"diamante":
				keys.assign(["diamante_100", "diamante_180"])
			"sic":
				keys.assign(["gc_80", "gc_120"])
			_:
				if machine_kind == "universal":
					keys.assign(["wa_60", "wa_80"])
				else:
					keys.assign(["banco_grueso", "banco_fino"])
		if kind == "cuchillo":
			keys.append_array(["piedras_mano", "cuero_cromo"])
			finish = "piedras_mano_cuero"
		else:
			keys.append("piedra_rebaba")
	var steps: Array = []
	for key in keys:
		var step: Dictionary = GRIT_STEPS[key].duplicate(true)
		step["id"] = key
		steps.append(step)
	return [steps, finish]


## Recomendación completa. req = {
##   tool: { kind: "cuchillo" | "broca" | "fresa", style, use, steel_id, diameter_mm, hrc, work_material, thickness_mm },
##   machine_id, wheel_diameter_mm, rpm, wheel_abrasive_id (la muela montada, si no es la de serie), wet (opcional),
##   operation (opcional: hand_force_n, contact_area_mm2, sweep_ms, dwell_s) }.
## Devuelve { tool, machine, angles, abrasive_id, abrasive_reason, grits, speed_ms, speed_range_ms, rpm_range,
## over_speed, max_speed_ms, edge_width_um, edge_finish, heat, warnings, sources, quality }.
## quality es la peor de los ángulos, el abrasivo, la velocidad y los granos; heat lleva la suya («estimate»).
## over_speed compara con el máximo de una muela vitrificada cuando la montada es de Al₂O₃ o SiC (o cuando la
## máquina no trae muela y se recomienda una de ellas); con CBN o diamante, un aviso pide mirar la marcada.
static func recommend_sharpening(req: Dictionary) -> Dictionary:
	var tool: Dictionary = req.get("tool", {}) if req.get("tool") is Dictionary else {}
	var warnings: Array[String] = []
	var sources: Array[String] = []
	var quality := "primary"
	var kind := _str(tool, "kind", "cuchillo")
	if not (kind in ["cuchillo", "broca", "fresa"]):
		warnings.append("Herramienta «%s» desconocida: se trata como un cuchillo." % kind)
		kind = "cuchillo"
	# Material de la herramienta y dureza (en HRC, como la publican los fabricantes)
	var material := _str(tool, "steel_id", "x50crmov15" if kind == "cuchillo" else "m2")
	var hrc := _num(tool, "hrc", 0.0)
	if STEELS.has(material):
		if hrc <= 0.0:
			hrc = STEELS[material]["hrc"]["value"]
	elif TOOL_MATERIALS.has(material):
		hrc = 0.0  # no es acero: la dureza no decide el abrasivo
	elif hrc > 0.0:
		warnings.append("Material «%s» sin datos: se usa la dureza indicada (%s HRC) y no se calcula el riesgo térmico." % [material, _fmt(hrc, 1)])
	else:
		warnings.append("Material «%s» sin datos: se trata como un acero de hasta 58 HRC y no se calcula el riesgo térmico." % material)
	# Ángulos
	var angles: Dictionary
	match kind:
		"cuchillo":
			angles = knife_angles(tool)
		"broca":
			angles = drill_angles(tool)
		_:
			angles = mill_angles(tool)
	for w in angles["warnings"]:
		warnings.append(w)
	for entry in _sourced_entries(angles):
		sources.append(str(entry["source"]))
		quality = _worst(quality, str(entry["quality"]))
	# Abrasivo
	var ab := choose_abrasive(material, hrc)
	var abrasive_id: String = ab["abrasive_id"]
	sources.append(str(ab["source"]))
	quality = _worst(quality, str(ab["quality"]))
	# Máquina y muela montada
	var machine_id := _str(req, "machine_id", "tormek_t8" if kind == "cuchillo" else ("esmeriladora_banco" if kind == "broca" else "afiladora_universal"))
	if not SHARPENING_MACHINES.has(machine_id):
		warnings.append("Máquina «%s» desconocida: se usa la esmeriladora de banco." % machine_id)
		machine_id = "esmeriladora_banco"
	var machine: Dictionary = SHARPENING_MACHINES[machine_id]
	var machine_kind := str(machine["kind"])
	var wet := Heat.input_flag(req, "wet", machine["wet"])
	var diam_entry: Dictionary = machine["wheel_diameter_mm"]
	var d := _num(req, "wheel_diameter_mm", diam_entry["value"])
	if d <= 0.0:
		warnings.append("Diámetro de muela no válido: se usa el de serie (%s mm)." % _fmt(diam_entry["value"], 0))
		d = diam_entry["value"]
	sources.append(str(diam_entry["source"]))
	var stock_ab := str(machine["wheel_abrasive_id"])
	var mounted := _str(req, "wheel_abrasive_id", stock_ab)
	if mounted != "" and not (mounted in ABRASIVE_IDS):
		warnings.append("Muela de «%s» desconocida: se supone la de serie." % mounted)
		mounted = stock_ab
	if mounted != "" and mounted != abrasive_id:
		warnings.append("La máquina lleva una muela de %s y para esta herramienta se recomienda %s: cambia la muela o usa la alternativa (%s)." % [_abrasive_name(mounted), _abrasive_name(abrasive_id), _abrasive_name(str(ab["alternative_id"]))])
	if machine_kind == "lenta_humeda" and not (abrasive_id in ["al2o3", "cbn"]):
		warnings.append("Para metal duro conviene una afiladora universal con muela de diamante: los granos son los de esa máquina.")
	# Velocidad recomendada y velocidad real
	var speed_range := _speed_range(machine, abrasive_id, wet, d)
	sources.append(str(speed_range["source"]))
	quality = _worst(quality, str(speed_range["quality"]))
	var rpm_range := {
		"min": rpm_for_speed(speed_range["min"], d),
		"max": rpm_for_speed(speed_range["max"], d),
	}
	var rpm := _num(req, "rpm", 0.0)
	if rpm <= 0.0:
		if req.get("rpm") != null:
			warnings.append("Giro no válido: se usa el de serie o, en una máquina de velocidad variable, el recomendado.")
		if machine["rpm"] is Dictionary:
			rpm = machine["rpm"]["value"]
		else:
			rpm = (rpm_range["min"] + rpm_range["max"]) / 2.0  # velocidad variable: centro del intervalo
	if machine["rpm"] is Dictionary:
		var r: Dictionary = machine["rpm"]
		sources.append(str(r["source"]))
		if rpm < r["min"] or rpm > r["max"]:
			warnings.append("%s gira de serie a %s–%s rpm; con %s rpm la velocidad cambia." % [machine["name"], _fmt(r["min"], 0), _fmt(r["max"], 0), _fmt(rpm, 0)])
	var speed := peripheral_speed(d, rpm)
	var max_speed: Variant = null
	var over := false
	var vitrified: bool = mounted in CONVENTIONAL or (mounted == "" and abrasive_id in CONVENTIONAL)
	if vitrified and machine_kind != "lenta_humeda":
		max_speed = VITRIFIED_MAX_SPEED["value"]
		sources.append(str(VITRIFIED_MAX_SPEED["source"]))
		if speed > max_speed:
			over = true
			var danger := _fmt_pair(speed, max_speed, 1)
			warnings.append("¡Peligro! La muela va a %s m/s y una muela vitrificada de %s admite como máximo %s m/s (EN 12413): puede reventar. Usa una muela marcada para más velocidad o menos rpm." % [danger[0], _abrasive_name(mounted if mounted != "" else abrasive_id), danger[1]])
	var superabrasive := mounted if mounted in ["cbn", "diamante"] else (abrasive_id if abrasive_id in ["cbn", "diamante"] else "")
	if superabrasive != "" and machine_kind != "lenta_humeda":
		warnings.append("Con muela de %s, comprueba la velocidad máxima marcada en ella." % _abrasive_name(superabrasive))
	var label := str(speed_range["label"])
	if speed > speed_range["max"] * 1.0001:
		var fast := _fmt_pair(speed, speed_range["max"], 1)
		warnings.append("La muela va a %s m/s, más rápido que %s (%s–%s m/s): calienta más el filo." % [fast[0], label, _fmt(speed_range["min"], 1), fast[1]])
	elif speed < speed_range["min"] * 0.9999:
		var slow := _fmt_pair(speed, speed_range["min"], 1)
		warnings.append("La muela va a %s m/s, más despacio que %s (%s–%s m/s): arranca menos y se desgasta más." % [slow[0], label, slow[1], _fmt(speed_range["max"], 1)])
	# Granos y filo final (Verhoeven midió filos de acero: no vale para otros materiales)
	var prog := grit_progression(kind, machine_id, abrasive_id)
	var grits: Array = prog[0]
	for step in grits:
		sources.append(str(step["source"]))
		quality = _worst(quality, str(step["quality"]))
	var edge_width: Variant = null
	var finish: Variant = null
	if str(prog[1]) != "" and not TOOL_MATERIALS.has(material):
		finish = EDGE_FINISH[prog[1]].duplicate(true)
		finish["id"] = prog[1]
		edge_width = finish["value"]
		sources.append(str(finish["source"]))
	# Riesgo térmico con la operación nominal (o la de req.operation)
	var op := _operation(req)
	var heat: Variant = null
	if STEELS.has(material):
		var power: float = op["force_ratio"] * op["hand_force_n"] * speed
		var heat_in := {
			"power_w": power,
			"contact_area_mm2": op["contact_area_mm2"],
			"speed_ms": op["sweep_ms"],
			"wet": wet,
			"abrasive_id": abrasive_id,
			"steel_id": material,
			"dwell_s": op["dwell_s"],
		}
		heat = Heat.heat_risk(heat_in)
		heat["inputs"] = {
			"power_w": power,
			"wheel_speed_ms": speed,
			"hand_force_n": op["hand_force_n"],
			"force_ratio": op["force_ratio"],
			"contact_area_mm2": op["contact_area_mm2"],
			"sweep_ms": op["sweep_ms"],
			"dwell_s": op["dwell_s"],
			"source": op["source"],
			"quality": "estimate",
		}
		match str(heat["level"]):
			"medio":
				if wet:
					warnings.append("Riesgo térmico medio: el contacto pasa de ≈130 °C y ahí el agua ya no enfría. Menos presión o pasadas más cortas.")
				else:
					warnings.append("Riesgo térmico medio: el contacto pasa de ≈130 °C, aunque sin llegar al revenido. Menos presión o pasadas más cortas.")
			"alto":
				warnings.append("Riesgo térmico alto: el filo puede revenirse y perder dureza. Menos presión, pasadas más cortas o una máquina lenta en húmedo.")
			"quemado":
				warnings.append("Riesgo de quemar el filo (≈723 °C): reduce mucho la presión o cambia de máquina.")
		if kind == "broca" and not wet and str(heat["level"]) != "bajo":
			warnings.append("Si la broca se calienta mucho, no la metas de golpe en agua fría: los filos pueden agrietarse (TC 9-524).")
		if mounted != "" and mounted != abrasive_id:
			var with_mounted := Heat.heat_risk(heat_in.merged({ "abrasive_id": mounted }, true))
			if with_mounted["level"] != heat["level"]:
				warnings.append("Con la muela montada de %s el riesgo térmico sería %s en vez de %s." % [_abrasive_name(mounted), with_mounted["level"], heat["level"]])
	elif TOOL_MATERIALS.has(material):
		warnings.append(str(TOOL_MATERIALS[material]["heat_note"]))
	return {
		"tool": { "kind": kind, "steel_id": material, "hrc": hrc if hrc > 0.0 else null },
		"machine": { "id": machine_id, "name": machine["name"], "wheel_diameter_mm": d, "rpm": rpm, "wet": wet, "wheel_abrasive_id": mounted },
		"angles": angles,
		"abrasive_id": abrasive_id,
		"abrasive_reason": ab["reason"],
		"grits": grits,
		"speed_ms": speed,
		"speed_range_ms": speed_range,
		"rpm_range": rpm_range,
		"over_speed": over,
		"max_speed_ms": max_speed,
		"edge_width_um": edge_width,
		"edge_finish": finish,
		"heat": heat,
		"warnings": warnings,
		"sources": _unique(sources),
		"quality": quality,
	}


## Intervalo de velocidad periférica recomendado, con label para los avisos. En la máquina lenta en húmedo es el
## de serie: sus rpm con el diámetro real de la muela.
static func _speed_range(machine: Dictionary, abrasive_id: String, wet: bool, d: float) -> Dictionary:
	if str(machine["kind"]) == "lenta_humeda":
		var r: Dictionary = machine["rpm"]
		return {
			"min": peripheral_speed(d, r["min"]),
			"max": peripheral_speed(d, r["max"]),
			"label": "la de serie de la máquina",
			"source": r["source"],
			"quality": r["quality"],
		}
	var key := abrasive_id
	var label := "la recomendada para %s" % _abrasive_name(abrasive_id)
	if abrasive_id in ["cbn", "diamante"]:
		key = abrasive_id + ("_humedo" if wet else "_seco")
		label += " en húmedo" if wet else " en seco"
	var out: Dictionary = SPEED_RANGES.get(key, SPEED_RANGES["al2o3"]).duplicate(true)
	out["label"] = label
	return out


## La operación de afilado: NOMINAL_OPERATION con lo que traiga req.operation.
static func _operation(req: Dictionary) -> Dictionary:
	var given: Dictionary = req.get("operation", {}) if req.get("operation") is Dictionary else {}
	var out := {}
	var notes: Array[String] = []
	for key in NOMINAL_OPERATION:
		var entry: Dictionary = NOMINAL_OPERATION[key]
		var v := Heat.input_num(given, key, NAN)
		if not is_nan(v):
			out[key] = v
			notes.append("%s: dato del usuario" % key)
		else:
			out[key] = entry["value"]
			notes.append("%s: %s" % [key, entry["source"]])
	out["source"] = "; ".join(notes)
	return out


## Nombre legible de un abrasivo (las claves son de CONTRATOS.md).
static func _abrasive_name(id: String) -> String:
	match id:
		"al2o3":
			return "Al₂O₃"
		"sic":
			return "SiC"
		"cbn":
			return "CBN"
		"diamante":
			return "diamante"
	return id


## Copia de una entrada de catálogo con value, min, max, source y quality.
static func _pick(entry: Dictionary) -> Dictionary:
	return entry.duplicate(true)


## Entradas con fuente (diccionarios con source y quality) de un resultado, recorrido en profundidad.
static func _sourced_entries(node: Variant) -> Array:
	var out: Array = []
	if node is Dictionary:
		if node.has("source") and node.has("quality"):
			out.append(node)
		for k in node:
			out.append_array(_sourced_entries(node[k]))
	elif node is Array:
		for x in node:
			out.append_array(_sourced_entries(x))
	return out


static func _worst(a: String, b: String) -> String:
	return a if int(QUALITY_RANK.get(a, 0)) <= int(QUALITY_RANK.get(b, 0)) else b


static func _unique(items: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for s in items:
		if s != "" and not out.has(s):
			out.append(s)
	return out


## Número con coma decimal, sin ceros de sobra (toFixed de JavaScript, como en el laboratorio).
static func _fmt(x: float, decimals: int) -> String:
	var s := Js.to_fixed(x, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")


## Dos números de un mismo mensaje: si al redondear saldrían iguales siendo distintos, con más decimales.
static func _fmt_pair(a: float, b: float, decimals: int) -> Array[String]:
	var dec := decimals
	var sa := _fmt(a, dec)
	var sb := _fmt(b, dec)
	while sa == sb and a != b and dec < decimals + 4:
		dec += 1
		sa = _fmt(a, dec)
		sb = _fmt(b, dec)
	var out: Array[String] = [sa, sb]
	return out


## Número de un diccionario de entrada, con la misma regla que sharpening_heat.gd (input_num).
static func _num(p: Dictionary, key: String, def: float) -> float:
	return Heat.input_num(p, key, def)


## Texto de un diccionario de entrada; def si falta, es null o está vacío.
static func _str(p: Dictionary, key: String, def: String) -> String:
	var v: Variant = p.get(key)
	if v == null or str(v) == "":
		return def
	return str(v)
