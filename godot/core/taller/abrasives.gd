## Taller · abrasivos, tamaños de grano y discos de la radial (amoladora angular).
##
## Datos con fuente del Taller industrial: los granos (corindón, carburo de silicio, CBN, diamante y corindón
## cerámico), las tablas de tamaño de grano (FEPA F, FEPA P y JIS R6001), los discos de una radial con su franja
## de color de EN 12413 y las rpm máximas marcadas por diámetro. Cada entrada lleva `source` y `quality`
## ("primary" | "secondary" | "estimate"). Citas completas y estimaciones: docs/taller/fuentes-u6.md.
##
## Dureza de los granos. `hv` es la que usa el modelo de contacto (la escala del laboratorio: el corindón, la
## moissanita y el diamante valen lo mismo que en packages/core/src/data.js). `hk` es la Knoop que publican los
## fabricantes de granos. No se convierte una en otra: para cerámicas y superabrasivos no hay conversión
## normalizada (ISO 18265 y ASTM E140 son para metales) y, a carga baja, la Knoop del diamante (~7.100) queda muy
## por debajo de su Vickers (~10.000). Se guardan las dos medidas y el modelo usa HV, como el laboratorio.
## Uso: const Abrasives = preload("res://core/taller/abrasives.gd")
extends RefCounted

const Js = preload("res://core/shared/js.gd")

# ─────────────────────────────── Fuentes (texto de la cita) ───────────────────────────────
const SRC_PFERD := "PFERD, Werkzeughandbuch 23 (2019), catálogo 6 «Trenn-, Fächer- und Schruppscheiben» y catálogo 5 «Diamant-Trennscheiben»"
const SRC_KAPP := "Brazda P. (KAPP Technologies), «Hard Choices: Diamond or CBN?», Gear Solutions, 1-2-2006"
const SRC_KOMANDURI := "Komanduri R., Shaw M.C. (1975), Wear of synthetic diamond when grinding ferrous metals, Nature 255:211-213; (1976) On the diffusion wear of diamond in grinding pure iron, Phil. Mag. 34:195-204"
const SRC_LAB := "laboratorio V1 (packages/core/src/data.js, INLAYS: zafiro, moissanita y diamante; valores de manual, docs/FISICA.md)"
const SRC_PFERD_TM26_5 := "PFERD, Tool Manual 26, catálogo 5 «Diamond and CBN tools» (edición de EE. UU.), p. 23"
const SRC_PFERD_TM26_6 := "PFERD, Tool Manual 26, catálogo 6 «Cut-off wheels, flap discs and grinding wheels» (edición de EE. UU.), p. 23"

## Granos abrasivos. Claves de unión de CONTRATOS.md: al2o3 · sic · cbn · diamante (más ceramico, opcional).
##   hv, hk: dureza (kgf/mm²) · e_gpa: módulo de Young · max_temp_c: temperatura a la que el grano deja de servir
##   en aire · iron_reactive: se gasta químicamente contra el hierro · iron_reaction_c: desde qué temperatura
##   · best_for: tipos de pieza (`kind` de CONTRATOS.md; "acero_templado" = acero o inox del grupo ISO 513 H).
const ABRASIVES := {
	"al2o3": {
		"id": "al2o3", "name": "Corindón (alúmina fundida)", "formula": "Al₂O₃",
		"hv": 2000.0, "hk": 2050.0, "e_gpa": 400.0,
		"max_temp_c": 1750.0, "iron_reactive": false, "iron_reaction_c": null,
		"best_for": ["acero", "inox", "acero_templado", "aluminio", "laton", "niquel"],
		"source": "HV 2000 y E 400 GPa del corindón (zafiro) del " + SRC_LAB + ". Knoop (100) 2.050 de la alúmina marrón fundida (GNPGraystar, ficha técnica Brown Aluminum Oxide, rev. 02/2020); " + SRC_KAPP + ": ~20.000 N/mm² Knoop. Empieza a ablandarse hacia 1.750 °C, funde a ~2.040 °C y es químicamente inerte (Washington Mills, «Fused Mineral Properties»). Grano de los discos PFERD STEEL, STEELOX e INOX («Hochleistungskorund A», " + SRC_PFERD + ").",
		"quality": "primary",
	},
	"sic": {
		"id": "sic", "name": "Carburo de silicio", "formula": "SiC",
		"hv": 2800.0, "hk": 2500.0, "e_gpa": 440.0,
		"max_temp_c": 2700.0, "iron_reactive": true, "iron_reaction_c": null,
		"best_for": ["fundicion", "piedra", "aluminio", "titanio", "laton", "plastico", "vidrio"],
		"source": "Knoop (100) 2.500 kg/mm², Mohs 9,2; no funde, se disocia (GRAYSTAR, TDS Black Silicon Carbide, 2009; ~2.700 °C según la ficha CAS 409-21-2). HV 2800 y E 440 GPa de la moissanita (SiC) del " + SRC_LAB + ". «Se usa en fundición, varios metales y materiales no metálicos; no sirve para el acero por su reactividad química con él a la temperatura del contacto» (patente US 4.505.720, 1985, antecedentes). Discos PFERD PSF ALU+STONE de SiC: aluminio, titanio, no férricos, piedra, hormigón, azulejo y fundición (" + SRC_PFERD + "); Norton 37C: no férricos, fundición, cerámica, plástico, piedra y vidrio.",
		"quality": "primary",
	},
	"cbn": {
		"id": "cbn", "name": "Nitruro de boro cúbico (CBN)", "formula": "c-BN",
		"hv": 6322.0, "hk": 4487.0, "e_gpa": 909.0,
		"max_temp_c": 1000.0, "iron_reactive": false, "iron_reaction_c": null,
		"best_for": ["acero_templado", "fundicion", "niquel"],
		"source": "Monocristal: HV 62 GPa (6.322 kgf/mm²), HK 44 GPa (4.487) y E 909 GPa (Solozhenko, Bushlya y Zhou 2019, arXiv:1905.04304, tabla, valores de su ref. [24]). " + SRC_KAPP + ": 45.000 N/mm² Knoop, conserva el filo hasta 1.000 °C y por encima de 800 °C es más duro que el diamante: es el superabrasivo del acero. Benes J., «All About Abrasives», American Machinist, 10-5-2007: CBN para metales férricos duros, fundición y aleaciones de níquel y cobalto.",
		"quality": "primary",
	},
	"diamante": {
		"id": "diamante", "name": "Diamante", "formula": "C",
		"hv": 10000.0, "hk": 7138.0, "e_gpa": 1050.0,
		"max_temp_c": 600.0, "iron_reactive": true, "iron_reaction_c": 700.0,
		"best_for": ["piedra", "vidrio", "fundicion"],
		"source": "HV 10.000 y E 1050 GPa del diamante del " + SRC_LAB + ". " + SRC_KAPP + ": 70.000 N/mm² Knoop (7.138 kgf/mm²); «se oxida por encima de 600 °C» y «reacciona con los metales del grupo del hierro (hierro, cobalto, níquel) ya por encima de 700 °C». Mecanismo del desgaste contra el hierro: " + SRC_KOMANDURI + " (el carbono del diamante se difunde en el hierro). Discos de diamante PFERD para hormigón, piedra y azulejo (EN 13236) y discos galvánicos D 852 para fundición gris y esferoidal (" + SRC_PFERD + ").",
		"quality": "primary",
	},
	"ceramico": {
		"id": "ceramico", "name": "Corindón cerámico (alúmina sinterizada sol-gel)", "formula": "Al₂O₃ (microcristalino)",
		"hv": 2000.0, "hk": 2050.0, "e_gpa": 400.0,
		"max_temp_c": 1750.0, "iron_reactive": false, "iron_reaction_c": null,
		"best_for": ["acero", "acero_templado", "inox"],
		"source": "PFERD: el grano cerámico CO es un corindón sinterizado sol-gel, muy tenaz y autoafilable, «pensado para materiales duros» (disco de corte CERAMIC SGP STEEL para acero; " + SRC_PFERD + "). ESTIMACIÓN: dureza, módulo y temperatura iguales a los del corindón, porque también es alúmina α (el fabricante no los publica).",
		"quality": "estimate",
	},
	"carburo_w": {
		"id": "carburo_w", "name": "Carburo de tungsteno (metal duro)", "formula": "WC-Co",
		"hv": 2000.0, "hk": null, "e_gpa": 620.0,
		"max_temp_c": 1000.0, "iron_reactive": false, "iron_reaction_c": null,
		"best_for": [],
		"source": "HV 2000 y E 620 GPa del carburo de tungsteno del laboratorio V1 (packages/core/src/data.js, INLAYS: tungsteno; valores de manual, docs/FISICA.md); el metal duro va de ~700 a 2.200 HV30 según el cobalto y el tamaño de grano (Hyperion Materials & Technologies, «Cemented carbide hardness»). Grano afilado soldado a un cuerpo de acero en el disco DS Multi Power Carbide (" + SRC_PFERD_TM26_5 + "). Sin Knoop publicada (hk = null). Temperatura máxima: la del metal duro de tool_materials.gd (ESTIMACIÓN); el TZ (p. 213) avisa de que el WC y el Co se oxidan a alta temperatura. Fuera de RECOMMEND: es un disco de construcción y bricolaje, no un grano de muela.",
		"quality": "secondary",
	},
}

## Qué abrasivo conviene para cada tipo de pieza, por orden de preferencia (`kind` de CONTRATOS.md; los aceros
## templados, grupo ISO 513 H, van aparte). Sale de las mismas fuentes que ABRASIVES.best_for.
const RECOMMEND := {
	"acero": ["al2o3", "ceramico"],
	"acero_templado": ["cbn", "ceramico", "al2o3"],
	"inox": ["al2o3", "ceramico"],
	"fundicion": ["sic", "cbn", "diamante"],
	"aluminio": ["sic", "al2o3"],
	"laton": ["sic", "al2o3"],
	"titanio": ["sic"],
	"niquel": ["cbn", "al2o3"],
	"piedra": ["diamante", "sic"],
	"vidrio": ["diamante", "sic"],
	"plastico": ["sic"],
	"madera": [],
}


## Abrasivos adecuados para una pieza (ids, del mejor al peor). iso: grupo ISO 513 de la pieza ("H" = templado).
static func abrasives_for(kind: String, iso: String = "") -> Array:
	var key := kind
	if iso == "H" and (kind == "acero" or kind == "inox"):
		key = "acero_templado"
	return (RECOMMEND.get(key, []) as Array).duplicate()


# ─────────────────────────────── Tamaño de grano ───────────────────────────────
## Sistemas de tamaño de grano: mediana ds50 (µm) de cada grado.
##  · fepa_f: abrasivos aglomerados (muelas y discos). Macro F5-F220 por tamizado; micro F230-F1200 por
##    sedimentación (FEPA 42-1 y 42-2:2006; ISO 8486).
##  · fepa_p: abrasivos flexibles (lija, discos de láminas) P12-P2500 (FEPA 43-1 y 43-2:2006; ISO 6344).
##  · jis_r6001: micrograno japonés #240-#8000, método de resistencia eléctrica (el de sedimentación da
##    valores mayores: #1000 = 15,5 µm frente a 11,5; ABC SwissTech, tabla JIS R6001-1998).
const GRIT_SYSTEMS := {
	"fepa_f": {
		"id": "fepa_f", "name": "FEPA F (abrasivos aglomerados)", "prefix": "F", "macro_max": 220,
		"sizes": {
			5: 4125.0, 6: 3460.0, 7: 2900.0, 8: 2460.0, 10: 2085.0, 12: 1765.0, 14: 1470.0, 16: 1230.0,
			20: 1040.0, 22: 885.0, 24: 745.0, 30: 625.0, 36: 525.0, 40: 438.0, 46: 370.0, 54: 310.0,
			60: 260.0, 70: 218.0, 80: 185.0, 90: 154.0, 100: 129.0, 120: 109.0, 150: 82.0, 180: 69.0,
			220: 58.0, 230: 53.0, 240: 44.5, 280: 36.5, 320: 29.2, 360: 22.8, 400: 17.3, 500: 12.8,
			600: 9.3, 800: 6.5, 1000: 4.5, 1200: 3.0,
		},
		"source": "Universal Photonics, «Grit Size Comparison Chart» (D50 de FEPA F; micro según FEPA 42-2:2006). F1000 = 4,5 µm coincide con ABC SwissTech, tabla FEPA 42GB-1984 (4,5 ± 0,8 µm, Sedigraph 5000D).",
		"quality": "secondary",
	},
	"fepa_p": {
		"id": "fepa_p", "name": "FEPA P (abrasivos flexibles)", "prefix": "P",
		"sizes": {
			12: 1815.0, 16: 1324.0, 20: 1000.0, 24: 764.0, 30: 642.0, 36: 538.0, 40: 425.0, 50: 336.0,
			60: 269.0, 80: 201.0, 100: 162.0, 120: 125.0, 150: 100.0, 180: 82.0, 220: 68.0, 240: 58.5,
			280: 52.2, 320: 46.2, 360: 40.5, 400: 35.0, 500: 30.2, 600: 25.8, 800: 21.8, 1000: 18.3,
			1200: 15.3, 1500: 12.6, 2000: 10.3, 2500: 8.4,
		},
		"source": "Universal Photonics, «Grit Size Comparison Chart» (D50 de FEPA P, norma FEPA 43 / ISO 6344).",
		"quality": "secondary",
	},
	"jis_r6001": {
		"id": "jis_r6001", "name": "JIS R6001 (micrograno)", "prefix": "#",
		"sizes": {
			240: 57.0, 280: 48.0, 320: 40.0, 360: 35.0, 400: 30.0, 500: 25.0, 600: 20.0, 700: 17.0,
			800: 14.0, 1000: 11.5, 1200: 9.5, 1500: 8.0, 2000: 6.7, 2500: 5.5, 3000: 4.0, 4000: 3.0,
			6000: 2.0, 8000: 1.2,
		},
		"ranges": {
			240: [54.0, 60.0], 280: [45.0, 51.0], 320: [37.5, 42.5], 360: [33.0, 37.0], 400: [28.0, 32.0],
			500: [23.0, 27.0], 600: [18.5, 21.5], 700: [15.7, 18.3], 800: [13.0, 15.0], 1000: [10.5, 12.5],
			1200: [8.7, 10.3], 1500: [7.4, 8.6], 2000: [6.1, 7.3], 2500: [5.0, 6.0], 3000: [3.5, 4.5],
			4000: [2.6, 3.4], 6000: [1.6, 2.4], 8000: [0.9, 1.5],
		},
		"source": "Resonac (antes Showa Denko), «Morundum Micrograins» (JIS 6001: rango de ds-50; se usa el centro). Coincide con la columna de resistencia eléctrica de ABC SwissTech, tabla JIS R6001-1998 (#1000 = 11,5 ± 1,0 µm).",
		"quality": "primary",
	},
}


## Tamaño medio del grano (µm) de un grado: grit_microns("fepa_f", 1000) → 4,5. El grado puede ser un número o
## un texto con el prefijo de su sistema: "F1000" en fepa_f, "P1000" en fepa_p, "#1000" en jis_r6001 (o solo las
## cifras). Devuelve −1 si el grado no existe en ese sistema o si trae el prefijo de otro ("P1000" en fepa_f).
static func grit_microns(system: String, grade: Variant) -> float:
	var sys: Dictionary = GRIT_SYSTEMS.get(system, {})
	if sys.is_empty():
		return -1.0
	var g := _grade_number(grade, String(sys["prefix"]))
	var sizes: Dictionary = sys["sizes"]
	if g <= 0 or not sizes.has(g):
		return -1.0
	return float(sizes[g])


## Número de un grado. En texto solo admite el prefijo del sistema (sin distinguir mayúsculas) seguido de cifras.
static func _grade_number(grade: Variant, prefix: String) -> int:
	if typeof(grade) == TYPE_INT:
		return grade
	if typeof(grade) == TYPE_FLOAT:
		return int(grade) if float(int(grade)) == grade else -1
	if typeof(grade) != TYPE_STRING and typeof(grade) != TYPE_STRING_NAME:
		return -1
	var s := String(grade).strip_edges().to_upper()
	if prefix != "" and s.begins_with(prefix):
		s = s.substr(prefix.length()).strip_edges()
	if s == "":
		return -1
	for ch in s:
		if ch < "0" or ch > "9":
			return -1
	return s.to_int()


# ─────────────────────────────── Velocidad y marcado (EN 12413) ───────────────────────────────
## Franjas de color de la velocidad máxima de trabajo (EN 12413:2019, anexo D, informativo). Hasta 45 m/s no
## llevan franja. Las de un color están comprobadas en publicaciones de fabricantes; las de dos, en la tabla de la
## norma reproducida por las mutuas de bomberos alemanas (con Klingspor como fuente).
const STRIPES := [
	{ "max_speed_ms": 50.0, "colors": ["azul"], "quality": "primary" },
	{ "max_speed_ms": 63.0, "colors": ["amarillo"], "quality": "primary" },
	{ "max_speed_ms": 80.0, "colors": ["rojo"], "quality": "primary" },
	{ "max_speed_ms": 100.0, "colors": ["verde"], "quality": "primary" },
	{ "max_speed_ms": 125.0, "colors": ["azul", "amarillo"], "quality": "secondary" },
	{ "max_speed_ms": 140.0, "colors": ["azul", "rojo"], "quality": "secondary" },
	{ "max_speed_ms": 160.0, "colors": ["azul", "verde"], "quality": "secondary" },
	{ "max_speed_ms": 180.0, "colors": ["amarillo", "rojo"], "quality": "secondary" },
	{ "max_speed_ms": 200.0, "colors": ["amarillo", "verde"], "quality": "secondary" },
	{ "max_speed_ms": 225.0, "colors": ["rojo", "verde"], "quality": "secondary" },
	{ "max_speed_ms": 250.0, "colors": ["azul", "azul"], "quality": "secondary" },
	{ "max_speed_ms": 280.0, "colors": ["amarillo", "amarillo"], "quality": "secondary" },
	{ "max_speed_ms": 320.0, "colors": ["rojo", "rojo"], "quality": "secondary" },
]
const STRIPES_SOURCE := "EN 12413:2019, anexo D (informativo) y apartado 5.1.2 (serie de velocidades: <16, 16, 20, 25, 32, 35, 40, 45, 50, 63, 80, 100 y 125 m/s). Un color (50 azul · 63 amarillo · 80 rojo · 100 verde): Klingspor, «Arbeitshöchstgeschwindigkeit» (Schleifwissen, klingspor.de), y Andre Abrasive Articles, «General rules for marking abrasive tools» (extracto de EN 12413). Dos colores (125 a 320 m/s; franjas de 5 a 20 mm, separadas al menos 2 mm): tabla de DIN EN 12413 en HFUK Nord, FUK Mitte y FUK Brandenburg, «Stichpunkt Sicherheit B 7» (03/2020), con fuente DIN EN 12413 y Klingspor. Klingspor recuerda que ya no son obligatorias, aunque se siguen usando; oSa (Product marking requirements for bonded abrasives, 2020) las pide como marcado adicional según el anexo D."
## Colores de pintado de las franjas (solo para dibujarlas: la norma no fija valores RGB).
const STRIPE_HEX := { "azul": "#1E5AA8", "amarillo": "#F2C200", "rojo": "#C8102E", "verde": "#1E8C3A" }


## Franja de EN 12413 para una velocidad máxima (m/s): ["rojo"] a 80 m/s; [] si no lleva (≤ 45 m/s o fuera de tabla).
static func stripe_for(max_speed_ms: float) -> Array:
	for row in STRIPES:
		if absf(float(row["max_speed_ms"]) - max_speed_ms) < 1e-9:
			return (row["colors"] as Array).duplicate()
	return []


## rpm máximas marcadas por velocidad (m/s) y diámetro (mm). Tabla de conversión de EN 12413 (anexo E,
## informativo) según la reproduce un fabricante; a 80 m/s coincide con lo que marca Klingspor en sus discos.
## Redondea a 50 rpm, casi siempre hacia arriba: siempre queda a menos de 50 rpm de n = 60000·v/(π·D).
const MARKED_RPM := {
	50: { 115: 8350.0, 125: 7650.0, 150: 6400.0, 180: 5350.0, 230: 4200.0 },
	63: { 115: 10500.0, 125: 9650.0, 150: 8050.0, 180: 6700.0, 230: 5250.0 },
	80: { 115: 13300.0, 125: 12250.0, 150: 10200.0, 180: 8500.0, 230: 6650.0 },
	100: { 115: 16650.0, 125: 15300.0, 150: 12700.0, 180: 10650.0, 230: 8350.0 },
}
const MARKED_RPM_QUALITY := { 50: "secondary", 63: "secondary", 80: "primary", 100: "secondary" }
const MARKED_RPM_SOURCE := "Andre Abrasive Articles, «Speed conversion tables» (tabla de EN 12413 por diámetro y velocidad). A 80 m/s lo confirma la ficha de Klingspor Kronenflex A 24 R Supra (115: 13.300 · 125: 12.250 · 150: 10.200 · 180: 8.500 · 230: 6.650 rpm). Según oSa, las rpm marcadas deben salir del anexo E de EN 12413."
## Lo que marca PFERD en sus discos de 80 m/s (redondea a la centena más próxima): otra forma de redondear.
const MARKED_RPM_PFERD_80 := { 115: 13300.0, 125: 12200.0, 150: 10200.0, 180: 8500.0, 230: 6600.0 }
const MARKED_RPM_PFERD_SOURCE := "PFERD, Werkzeughandbuch 23 (2019), columnas «Max. RPM» de las tablas de discos de corte y desbaste de 80 m/s."


## rpm por la fórmula n = 60000·v/(π·D) (v en m/s, D en mm).
static func formula_rpm(diameter_mm: float, max_speed_ms: float) -> float:
	if diameter_mm <= 0.0:
		return INF
	return 60000.0 * max_speed_ms / (PI * diameter_mm)


## rpm máximas marcadas (tabla MARKED_RPM) para ese diámetro y esa velocidad; −1 si no está en la tabla.
static func marked_rpm(diameter_mm: float, max_speed_ms: float) -> float:
	var v := int(Js.js_round(max_speed_ms))
	var d := int(Js.js_round(diameter_mm))
	if float(v) != max_speed_ms or float(d) != diameter_mm or not MARKED_RPM.has(v):
		return -1.0
	var row: Dictionary = MARKED_RPM[v]
	return float(row[d]) if row.has(d) else -1.0


# ─────────────────────────────── Discos de radial ───────────────────────────────
## Discos de una amoladora angular. Todos de 80 m/s (las rpm máximas de cada diámetro son las que marca el
## fabricante). family: "corte" | "desbaste" | "laminas" | "diamante" · iso_type: forma según ISO 525 (41 plano,
## 42 de centro deprimido, 27 de desbaste) · bond: aglomerante (BF = resina reforzada con fibra de vidrio,
## EN 12413) · thickness_mm: anchura del disco (el surco sale 0,4 mm más ancho, ver radial.gd) · materials: `kind` de CONTRATOS.md para los
## que lo vende el fabricante · cuts: si sirve para tronzar · loading_resistance: 0 → se embota como un disco
## normal; 1 → no se embota nunca (ver radial.gd). `fino_1mm`, `grueso_3mm`, `diamante` y `laminas` son los ids del
## contrato de cut_panel (CONTRATOS.md); el resto son discos de más.
## Claves opcionales (fase 2): rpm_marked (false → rpm_by_diameter son los diámetros que se fabrican con las rpm de la
## fórmula, porque el fabricante solo marca la velocidad; el límite sale de la fórmula), stationary_only (disco para
## tronzadora fija: no se monta en una radial), bore_mm (agujero, si no es el de 22,23 mm de las radiales),
## work_angle_deg (ángulo de trabajo recomendado de un disco de láminas).
const DISCS := {
	"fino_1mm": {
		"id": "fino_1mm", "name": "Corte fino 1,0 mm (acero e inox)", "family": "corte",
		"iso_type": 41, "standard": "EN 12413", "abrasive": "al2o3", "abrasives": ["al2o3"], "bond": "BF",
		"thickness_mm": 1.0, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["acero", "inox"], "cuts": true, "loading_resistance": 0.0,
		"source": "PFERD EHT 125-1,0 SG STEELOX (corindón A, 12.200 rpm): «cortes finos y con poca rebaba» y «máxima rentabilidad por la rapidez del corte»; de 0,8 a 1,0 mm, «máxima rapidez y calidad de corte en chapa» (" + SRC_PFERD + ").",
		"quality": "primary",
	},
	"grueso_3mm": {
		"id": "grueso_3mm", "name": "Corte 3,2 mm (acero e inox)", "family": "corte",
		"iso_type": 42, "standard": "EN 12413", "abrasive": "al2o3", "abrasives": ["al2o3"], "bond": "BF",
		"thickness_mm": 3.2, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["acero", "inox"], "cuts": true, "loading_resistance": 0.0,
		"source": "PFERD EH 125-3,2 SG STEELOX (corindón A, forma 42, 12.200 rpm); ≥ 1,9 mm, «uso robusto» (" + SRC_PFERD + ").",
		"quality": "primary",
	},
	"corte_alu": {
		"id": "corte_alu", "name": "Corte 1,0 mm para aluminio (Al₂O₃ + SiC)", "family": "corte",
		"iso_type": 41, "standard": "EN 12413", "abrasive": "al2o3", "abrasives": ["al2o3", "sic"], "bond": "BF",
		"thickness_mm": 1.0, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["aluminio", "laton"], "cuts": true, "loading_resistance": 0.8,
		"source": "PFERD EHT 125-1,0 SG ALU (corindón A y carburo de silicio C, 12.200 rpm): «una mezcla especial de abrasivo y de ligante impide que el disco se embadurne, incluso en aluminio blando y tenaz»; para aluminio y otros no férricos (" + SRC_PFERD + "). loading_resistance 0,8: ESTIMACIÓN de ese «impide».",
		"quality": "primary",
	},
	"corte_sic": {
		"id": "corte_sic", "name": "Corte 1,6 mm de carburo de silicio (no férricos y piedra)", "family": "corte",
		"iso_type": 41, "standard": "EN 12413", "abrasive": "sic", "abrasives": ["sic"], "bond": "BF",
		"thickness_mm": 1.6, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["aluminio", "titanio", "laton", "piedra", "fundicion"], "cuts": true, "loading_resistance": 0.5,
		"source": "PFERD EHT 125-1,6 PSF ALU+STONE (carburo de silicio C, 12.200 rpm): aluminio, titanio, otros no férricos, piedra, hormigón, azulejo, duroplásticos (GFK, CFK) y fundición (" + SRC_PFERD + "). loading_resistance 0,5: ESTIMACIÓN (grano friable que se autoafila; el fabricante no lo cuantifica).",
		"quality": "primary",
	},
	"corte_ceramico": {
		"id": "corte_ceramico", "name": "Corte 1,0 mm de grano cerámico (acero)", "family": "corte",
		"iso_type": 41, "standard": "EN 12413", "abrasive": "ceramico", "abrasives": ["ceramico"], "bond": "BF",
		"thickness_mm": 1.0, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["acero"], "cuts": true, "loading_resistance": 0.0,
		"source": "PFERD EHT 125-1,0 CERAMIC SGP STEEL (grano cerámico CO, 12.200 rpm): «rendimiento de corte hasta ahora inalcanzado» y «vida útil sobresaliente», para acero de sección grande (" + SRC_PFERD + ").",
		"quality": "primary",
	},
	"desbaste": {
		"id": "desbaste", "name": "Desbaste 7,2 mm (acero y fundición)", "family": "desbaste",
		"iso_type": 27, "standard": "EN 12413", "abrasive": "al2o3", "abrasives": ["al2o3"], "bond": "BF",
		"thickness_mm": 7.2, "grit": "", "max_speed_ms": 80.0,
		"rpm_by_diameter": { 115: 13300.0, 125: 12200.0, 150: 10200.0, 180: 8500.0, 230: 6600.0 },
		"materials": ["acero", "fundicion"], "cuts": false, "loading_resistance": 0.0,
		"source": "PFERD E 125-7 PSF STEEL (corindón A, forma 27, 12.200 rpm): desbaste de superficies y cordones en acero y fundición; un disco de desbaste no es para tronzar (" + SRC_PFERD + ").",
		"quality": "primary",
	},
	"laminas": {
		"id": "laminas", "name": "Disco de láminas de corindón (P40-P120)", "family": "laminas",
		"iso_type": 0, "standard": "EN 13743", "abrasive": "al2o3", "abrasives": ["al2o3"], "bond": "abrasivo flexible (láminas de tela)",
		"thickness_mm": 0.0, "grit": "P40-P120", "max_speed_ms": 80.0,
		"rpm_by_diameter": { 115: 13300.0, 125: 12200.0, 180: 8500.0 },
		"materials": ["acero", "inox"], "cuts": false, "loading_resistance": 0.0,
		"work_angle_deg": [0.0, 15.0],
		"source": "PFERD POLIFAN PFF 125 A PSF STEELOX (corindón A, granos 40, 60, 80 y 120, 12.200 rpm): desbaste de superficies y soldaduras en acero e inox; abrasivo flexible según EN 13743 (" + SRC_PFERD + "). Ángulo de trabajo: el plano (PFF, tipo 27) rinde al máximo con un ángulo de contacto de 0 a 15° (el cónico PFC, de 10 a 25°) (" + SRC_PFERD_TM26_6 + "). No tiene ancho de corte: no es un disco de tronzar y el fabricante no da la anchura de su borde.",
		"quality": "primary",
	},
	"metal_duro": {
		"id": "metal_duro", "name": "Disco de grano de metal duro 1,9 mm (madera con clavos, plásticos y no férricos)", "family": "corte",
		"iso_type": 0, "standard": "sin norma indicada", "abrasive": "carburo_w", "abrasives": ["carburo_w"],
		"bond": "grano soldado a un cuerpo de acero", "thickness_mm": 1.905, "body_thickness_mm": 1.143, "grit": "",
		"max_speed_ms": 80.0, "rpm_by_diameter": { 125: 12200.0 },
		"materials": ["madera", "plastico", "aluminio", "laton"], "cuts": true, "loading_resistance": 0.8,
		"source": "PFERD DS Multi Power Carbide (novedad): 5 in (125 mm), cuerpo de acero T = 0,045 in (1,14 mm), borde de grano X = 0,075 in (1,9 mm, el que corta), agujero de 7/8 in, 12.200 rpm; grano afilado de carburo de tungsteno soldado al cuerpo; para madera con clavos, plásticos (tubos), metales no férricos y materiales de construcción en seco; diámetro constante y vida larga (" + SRC_PFERD_TM26_5 + "). 80 m/s: los que dan sus 12.200 rpm en 125 mm. loading_resistance 0,8: ESTIMACIÓN (se vende para plásticos y no férricos; el fabricante no lo cuantifica).",
		"quality": "primary",
	},
	"cbn_1mm": {
		"id": "cbn_1mm", "name": "Disco de CBN 1,0 mm para tronzadora fija (acero rápido)", "family": "corte",
		"iso_type": 0, "standard": "EN 13236", "abrasive": "cbn", "abrasives": ["cbn"], "bond": "resina (B)",
		"thickness_mm": 1.0, "grit": "B126", "max_speed_ms": 50.0, "rpm_by_diameter": { 125: 7639.4 }, "rpm_marked": false,
		"stationary_only": true, "bore_mm": 20.0,
		"materials": ["acero"], "cuts": true, "loading_resistance": 0.0,
		"source": "Tyrolit, disco de corte de CBN de forma 1A1R, 125 × 1 × 20 mm, especificación 51B 126 C75 B 53 ST (grano B126, resina), velocidad máxima 50 m/s, para cortar en húmedo herramientas de acero rápido en tronzadoras fijas con avance manual o automático (ficha reproducida por el distribuidor SKS, art. 788700; la versión PREMIUM 125 × 0,8 × 20, 63 m/s en Hoffmann Group, art. 364801). Su agujero de 20 mm no es el de 22,23 mm de las radiales. rpm: las de la fórmula para 50 m/s (solo se marca la velocidad). PFERD hace discos de CBN para radial solo por encargo (catálogo 5): no hay ficha pública de uno para radial.",
		"quality": "secondary",
	},
	"diamante": {
		"id": "diamante", "name": "Diamante segmentado 2,2 mm (hormigón y ladrillo)", "family": "diamante",
		"iso_type": 0, "standard": "EN 13236", "abrasive": "diamante", "abrasives": ["diamante"], "bond": "metálico (segmentos de 7 mm)",
		"thickness_mm": 2.2, "grit": "", "max_speed_ms": 80.0,
		"rpm_by_diameter": { 115: 13300.0, 125: 12200.0, 178: 8600.0, 230: 6600.0 },
		"materials": ["piedra"], "cuts": true, "loading_resistance": 0.3,
		"source": "PFERD DS 125 x 2,2 x 22,23 PSF (segmentos de 7 mm, 12.200 rpm): corte agresivo y rápido de hormigón, hormigón celular, ladrillo, clínker blando y bloque; se recomienda cortar en húmedo y con poca presión para no sobrecalentar el disco (" + SRC_PFERD + "). Ligante metálico y loading_resistance 0,3: ESTIMACIÓN (el fabricante no los indica).",
		"quality": "primary",
	},
	"diamante_turbo": {
		"id": "diamante_turbo", "name": "Diamante turbo 2,1 mm (granito y mármol)", "family": "diamante",
		"iso_type": 0, "standard": "EN 13236", "abrasive": "diamante", "abrasives": ["diamante"], "bond": "metálico (borde cerrado)",
		"thickness_mm": 2.1, "grit": "", "max_speed_ms": 80.0,
		"rpm_by_diameter": { 115: 13300.0, 125: 12200.0, 178: 8600.0, 230: 6600.0 },
		"materials": ["piedra"], "cuts": true, "loading_resistance": 0.3,
		"source": "PFERD DG 125 x 2,1 x 22,23 PSF (TURBO, borde cerrado, 12.200 rpm): corte cómodo y limpio de arenisca, ladrillo, pizarra, granito, mármol y hormigón fresco (" + SRC_PFERD + "). Ligante y loading_resistance: ESTIMACIÓN.",
		"quality": "primary",
	},
	"diamante_continuo": {
		"id": "diamante_continuo", "name": "Diamante de borde continuo 1,6 mm (azulejo)", "family": "diamante",
		"iso_type": 0, "standard": "EN 13236", "abrasive": "diamante", "abrasives": ["diamante"], "bond": "metálico (borde continuo)",
		"thickness_mm": 1.6, "grit": "", "max_speed_ms": 80.0, "rpm_by_diameter": { 115: 13300.0, 125: 12200.0 },
		"materials": ["piedra"], "cuts": true, "loading_resistance": 0.3,
		"source": "PFERD DG 125 x 1,6 x 22,23 FL PSF (borde cerrado, 12.200 rpm): cortes muy finos, sin desconchados, en azulejo, gres porcelánico, pizarra y mármol (" + SRC_PFERD + "). Ligante y loading_resistance: ESTIMACIÓN.",
		"quality": "primary",
	},
}


## rpm máximas que el fabricante marca en ese disco para ese diámetro (rpm_by_diameter); −1 si el disco no existe,
## no se fabrica en ese diámetro o el fabricante no marca rpm (rpm_marked = false). Es el límite que manda: la radial
## nunca debe pasar de lo marcado en el disco.
static func disc_rpm(disc_id: String, diameter_mm: float) -> float:
	var disc: Dictionary = DISCS.get(disc_id, {})
	if disc.is_empty() or not bool(disc.get("rpm_marked", true)):
		return -1.0
	var d := int(Js.js_round(diameter_mm))
	var table: Dictionary = disc["rpm_by_diameter"]
	if float(d) != diameter_mm or not table.has(d):
		return -1.0
	return float(table[d])


## Franja de color de un disco: la de EN 12413 para su velocidad; [] en discos de otras normas (los de láminas,
## EN 13743, pueden llevar un código de color opcional de su anexo B, no verificado; los de diamante, EN 13236, no).
static func disc_stripe(disc_id: String) -> Array:
	var disc: Dictionary = DISCS.get(disc_id, {})
	if disc.is_empty() or disc["standard"] != "EN 12413":
		return []
	return stripe_for(disc["max_speed_ms"])
