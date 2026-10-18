## Taller · paneles de carrocería para probar la radial: los cuatro coches del laboratorio y tres piezas de rescate.
##
## - Coches: PAINT_LAYERS y CAR_BODIES son copia literal de packages/core/src/data.js (el oráculo V1): mismos ids,
##   espesores, durezas y capas de pintura. tests/taller/test_cut_panel.gd los compara con
##   tests/fixtures/lab-data.json. Sus fuentes están en docs/FISICA.md (apartados 6 y 14).
## - Rescate: pilar B de acero al boro estampado en caliente, refuerzo de acero de doble fase y perfil estructural
##   de aluminio, con fichas de fabricante (ArcelorMittal, SSAB, Hydro).
## - Propiedades térmicas, colores de revenido y clases de chispa, con su fuente o marcadas como estimación.
## Es un simulador educativo, no un procedimiento de rescate. Citas: docs/taller/fuentes-u6.md.
## Uso: const Panels = preload("res://core/taller/panels.gd"); Panels.get_panel("boro-22mnb5")
extends RefCounted

## Pintura OEM de coche: capas acumuladas (µm). Copia de PAINT_LAYERS (data.js).
const PAINT_LAYERS := [
	{ "id": "barniz", "name": "Barniz", "from": 0, "to": 45, "col": "#AED2E0", "cede": "el barniz (clearcoat)" },
	{ "id": "color", "name": "Color", "from": 45, "to": 60, "col": "#7E2B3A", "cede": "el color (basecoat)" },
	{ "id": "imprimacion", "name": "Imprimación", "from": 60, "to": 85, "col": "#9AA0A6", "cede": "la imprimación" },
	{ "id": "anticorrosivo", "name": "Anticorrosivo", "from": 85, "to": 110, "col": "#5E6B52", "cede": "el anticorrosivo (e-coat)" },
]

## Carrocerías del laboratorio (lo que hay debajo de la pintura). t en µm, hv, E en GPa y σ0 en MPa.
## Copia de CAR_BODIES (data.js): mismas claves y valores.
const CAR_BODIES := {
	"moderno": { "id": "acero-bh", "name": "Acero BH", "long": "acero de horno (HC180B)", "noun": "la chapa", "metal": true,
		"t": 700, "hv": 101, "E": 210, "sigma0": 264, "col": "#C3CAD2" },
	"clasico": { "id": "acero-dulce", "name": "Acero dulce", "long": "acero dulce (tipo DC04)", "noun": "la chapa", "metal": true,
		"t": 900, "hv": 92, "E": 210, "sigma0": 214, "col": "#B9C0C8" },
	"aluminio": { "id": "aluminio", "name": "Aluminio", "long": "aluminio AA6016", "noun": "la chapa", "metal": true,
		"t": 1000, "hv": 71, "E": 70, "sigma0": 211, "col": "#DCE3EA" },
	"plastico": { "id": "plastico-carroceria", "name": "Plástico PPE/PA", "long": "termoplástico PPE/PA (Noryl GTX)", "noun": "el plástico", "metal": false,
		"t": 2500, "hv": 13, "E": 1.8, "sigma0": 47, "col": "#3B4046" },
}
const LAB_SOURCE := "Carrocería del laboratorio V1 (packages/core/src/data.js, CAR_BODIES y PAINT_LAYERS; fuentes en docs/FISICA.md, apartados 6 y 14)"
const LAB_CITE := "Laboratorio V1 (data.js; FISICA.md, apartados 6 y 14)"

## Propiedades térmicas por familia. rho kg/m³ · c J/(kg·K) · alpha_k: dilatación lineal (1/K) · chip_j_mm3:
## energía que se llevan las virutas (chispas) · t_edge_c: temperatura de la pared del surco (y del frente del
## corte) · t_soft_c: temperatura a la que la pared se ablanda (rebaba, plástico fundido) · cite: cita corta.
const THERMAL := {
	"acero": {
		"rho": 7850.0, "c": 440.0, "alpha_k": 12e-6, "chip_j_mm3": 8.1, "t_edge_c": 1250.0, "t_soft_c": 727.0,
		"source": "ρ 7.850 kg/m³ y c ≈ 440 J/(kg·K) a 20 °C (EN 1993-1-2:2005, 3.2.2 y 3.4.1.2); α = 12·10⁻⁶ K⁻¹ (EN 1993-1-1:2005, 3.2.6, hasta 100 °C). Virutas: 8,1 J/mm³ para el AISI 1095 calentado hasta 1.500 °C (Rowe, Morgan, Batako y Jin 2003, «Energy and temperature analysis in grinding», WIT Trans. Eng. Sci. 44). Ablandamiento: 727 °C, la temperatura eutectoide del diagrama hierro-carbono.",
		"cite": "EN 1993-1-1 y 1993-1-2 (acero); Rowe et al. 2003",
		"quality": "secondary",
		"estimates": "t_edge_c 1.250 °C: la temperatura media de la viruta que proponen Rowe et al. (2003), usada aquí como temperatura de la pared del surco. c y α a 20 °C (a 400 °C c sube a ~600 y α crece, EN 1993-1-2): sobrestima algo el calor y subestima la dilatación.",
	},
	"aluminio": {
		"rho": 2710.0, "c": 897.0, "alpha_k": 23.1e-6, "chip_j_mm3": 1.35, "t_edge_c": 575.0, "t_soft_c": 250.0,
		"source": "EN AW-6082: 2,71 g/cm³, 897 J/(kg·K), 172 W/(m·K) en T6, dilatación 23,1·10⁻⁶ K⁻¹ e intervalo de fusión 575-650 °C (Hydro, ficha técnica EN AW-6082, rev. 4, 03/2023, propiedades físicas de MNC Handbok nr 12).",
		"cite": "Hydro, ficha EN AW-6082 (2023)",
		"quality": "estimate",
		"estimates": "Mismas constantes para el AA6016 de la carrocería. Virutas: ρ·c·(575 − 20) = 1,35 J/mm³ (se calientan hasta el sólidus). Ablandamiento a 250 °C: los 6xxx en T6 pierden resistencia por sobreenvejecimiento; ESTIMACIÓN sin medición propia.",
	},
	"plastico": {
		"rho": 1080.0, "c": 1500.0, "alpha_k": 8e-5, "chip_j_mm3": 0.45, "t_edge_c": 300.0, "t_soft_c": 180.0,
		"source": "NORYL GTX964W (PPE/PA): densidad 1,08, Vicat B/120 180 °C, temperatura de inyección 295-315 °C y conductividad 0,23 W/(m·K) (SABIC, ficha técnica, rev. 2019-09-25).",
		"cite": "SABIC, NORYL GTX964W (2019)",
		"quality": "estimate",
		"estimates": "c = 1.500 J/(kg·K) y α = 8·10⁻⁵ K⁻¹: valores típicos de una poliamida sin carga, la ficha no los da. Borde del surco a 300 °C (fundido); se ablanda en el Vicat (180 °C). Virutas: ρ·c·(300 − 20) = 0,45 J/mm³.",
	},
}

## Colores de revenido. Acero al carbono: temperatura (°C) y muestra de color de Engineering ToolBox, «Steel
## Tempering Colors» (los nombres describen la muestra). Inox 1.4301 calentado en aire: British Stainless Steel
## Association (BSSA), «Heat Tint (Temper) Colours on Stainless Steel Surface Heated in Air» (los hex son de
## pintado, ESTIMACIÓN). Por encima de la última fila la capa de óxido se vuelve opaca y gris (pintado estimado).
const TEMPER_COLORS := {
	"acero": [
		{ "t": 216.0, "hex": "#FFF05C", "name": "amarillo pálido" },
		{ "t": 221.0, "hex": "#FFE342", "name": "paja claro" },
		{ "t": 227.0, "hex": "#FDD444", "name": "paja" },
		{ "t": 232.0, "hex": "#FFC84A", "name": "paja oscuro" },
		{ "t": 238.0, "hex": "#FFCE49", "name": "paja oscuro" },
		{ "t": 249.0, "hex": "#FDAF4D", "name": "bronce" },
		{ "t": 260.0, "hex": "#FE7853", "name": "marrón rojizo" },
		{ "t": 271.0, "hex": "#EC5854", "name": "púrpura rojizo" },
		{ "t": 282.0, "hex": "#A3656A", "name": "púrpura" },
		{ "t": 293.0, "hex": "#6A6A8C", "name": "azul oscuro" },
		{ "t": 316.0, "hex": "#6697D1", "name": "azul claro" },
		{ "t": 340.0, "hex": "#8C959E", "name": "gris (óxido opaco)" },
	],
	"inox": [
		{ "t": 290.0, "hex": "#F3E9A6", "name": "amarillo pálido" },
		{ "t": 340.0, "hex": "#E8C96A", "name": "amarillo paja" },
		{ "t": 370.0, "hex": "#C9A43A", "name": "amarillo oscuro" },
		{ "t": 390.0, "hex": "#9B6B3A", "name": "marrón" },
		{ "t": 420.0, "hex": "#7A4A5A", "name": "marrón púrpura" },
		{ "t": 450.0, "hex": "#5A3570", "name": "púrpura oscuro" },
		{ "t": 540.0, "hex": "#3F5FA8", "name": "azul" },
		{ "t": 600.0, "hex": "#23386E", "name": "azul oscuro" },
	],
}
const TEMPER_SOURCE := "Acero: Engineering ToolBox, «Steel Tempering Colors» (216-316 °C). Inox: BSSA, «Heat Tint (Temper) Colours on Stainless Steel Surface Heated in Air» (290-600 °C). La fila de 340 °C del acero (gris opaco) y los hex del inox son de pintado: ESTIMACIÓN."

## Ensayo de chispas: cómo salta cada metal contra la muela. length_in: longitud relativa del chorro (pulgadas)
## con una muela a ~25 m/s (5.000 pies/min) · volume: tamaño del chorro (0 → nada; 1 → el mayor de la tabla) ·
## bursts: estallidos medios por chispa, con la escala de palabras de core/taller/sparks.gd (unidad 14): muy pocas
## 0,08 · pocas 0,15 · moderadas 0,35 · muchas 0,7 · muchísimas 1,2 (ESTIMACIÓN) · cite: cita corta.
const SPARK_CITE := "Steel Elements 2000; Buzzard 1933 (NBS RP605)"
const SPARK_CLASSES := {
	"hierro_bajo_c": {
		"name": "Acero de bajo carbono (≤ 0,15 % C)", "length_in": 65.0, "volume": 1.0,
		"color": "#F2C45A", "color_name": "amarillo paja", "color_end": "#FFF4D6", "color_end_name": "blanco",
		"bursts": 0.08, "bursts_name": "muy pocas, en horquilla",
		"source": "Tabla del ensayo de chispas de «Spark Testing for Mystery Metals» (Steel Elements, currículo del estado de Ohio, 2000): hierro dulce, chorro grande de 65 pulgadas, paja junto a la muela y blanco al final, muy pocas explosiones en horquilla. Buzzard R.W. (1933), «The utility of the spark test as applied to commercial steels», Bureau of Standards J. Res. 11:527 (RP605): con 0,10 % C aparece la lengua bifurcada y con 0,15 % C las primeras explosiones en serie.",
		"cite": SPARK_CITE,
		"quality": "secondary",
	},
	"acero_medio_c": {
		"name": "Acero de carbono medio (0,2-0,45 % C)", "length_in": 60.0, "volume": 0.9,
		"color": "#FFE7A0", "color_name": "amarillo blanquecino", "color_end": "#FFFFFF", "color_end_name": "blanco",
		"bursts": 0.35, "bursts_name": "moderadas, en serie, con estrellas",
		"source": "Buzzard (1933), NBS RP605: al subir el carbono por encima de 0,15 % las explosiones en serie se alargan y aparecen brotes y estrellas; la lengua más larga es con ~0,30 % C, el chorro más vistoso con 0,45 % C y el chorro se aclara hasta 0,45 % C.",
		"cite": SPARK_CITE,
		"quality": "estimate",
		"estimates": "Longitud de 60 pulgadas: entre el hierro dulce (65) y el acero de herramientas (55) de la tabla de Steel Elements.",
	},
	"acero_alto_c": {
		"name": "Acero de herramientas (alto carbono)", "length_in": 55.0, "volume": 0.8,
		"color": "#FFFFFF", "color_name": "blanco", "color_end": "#FFFFFF", "color_end_name": "blanco",
		"bursts": 1.2, "bursts_name": "muchísimas, finas y repetidas",
		"source": "Steel Elements (2000): acero al carbono de herramientas, chorro moderadamente grande de 55 pulgadas, blanco, con muchísimas explosiones finas y repetidas. Buzzard (1933): el número y la intensidad de las explosiones de carbono crecen con el carbono.",
		"cite": SPARK_CITE,
		"quality": "secondary",
	},
	"inox": {
		"name": "Acero inoxidable", "length_in": 50.0, "volume": 0.6,
		"color": "#C8553D", "color_name": "rojizo", "color_end": "#F2C45A", "color_end_name": "paja",
		"bursts": 0.35, "bursts_name": "moderadas, en horquilla",
		"source": "Steel Elements (2000): inoxidable, chorro moderado de 50 pulgadas con explosiones moderadas en horquilla. Buzzard (1933): con mucho cromo el chorro es muy corto; en los aceros al níquel-cromo, líneas rojo mate discontinuas, y desaparece con ~30 % de Ni + Cr.",
		"cite": SPARK_CITE,
		"quality": "secondary",
	},
	"fundicion_gris": {
		"name": "Fundición gris", "length_in": 25.0, "volume": 0.4,
		"color": "#B8432F", "color_name": "rojo", "color_end": "#F2C45A", "color_end_name": "paja",
		"bursts": 0.7, "bursts_name": "muchas, finas y repetidas",
		"source": "Steel Elements (2000): fundición gris, chorro pequeño de 25 pulgadas, rojo junto a la muela y paja al final, muchas explosiones finas. Buzzard (1933): portadores muy oscuros con una explosión relativamente clara.",
		"cite": SPARK_CITE,
		"quality": "secondary",
	},
	"niquel": {
		"name": "Níquel", "length_in": 10.0, "volume": 0.2,
		"color": "#E0822E", "color_name": "naranja", "color_end": "#E0822E", "color_end_name": "naranja",
		"bursts": 0.0, "bursts_name": "ninguna",
		"source": "Steel Elements (2000): níquel, chorro muy pequeño de 10 pulgadas, naranja, sin explosiones.",
		"cite": "Steel Elements 2000 (ensayo de chispas)",
		"quality": "secondary",
	},
	"no_ferrico": {
		"name": "Aluminio, cobre y latón", "length_in": 0.0, "volume": 0.0,
		"color": "", "color_name": "", "color_end": "", "color_end_name": "",
		"bursts": 0.0, "bursts_name": "ninguna",
		"source": "Steel Elements (2000): cobre, latón y aluminio no dan chorro de chispas.",
		"cite": "Steel Elements 2000 (ensayo de chispas)",
		"quality": "secondary",
	},
	"plastico": {
		"name": "Plástico", "length_in": 0.0, "volume": 0.0,
		"color": "", "color_name": "", "color_end": "", "color_end_name": "",
		"bursts": 0.0, "bursts_name": "ninguna",
		"source": "Un polímero no tiene hierro ni carbono que arda en el aire: se funde y humea, no chispea (mismo criterio que los no férricos de Steel Elements, 2000).",
		"cite": "sin chispas, como los no férricos de Steel Elements 2000 (estimación)",
		"quality": "estimate",
	},
}

## Paneles. Los de coche toman espesor, dureza y módulo de CAR_BODIES (lab_body); los de rescate los llevan aquí.
##   kind: `kind` de CONTRATOS.md · t_mm: espesor de la chapa (sin pintura) · paint_um: pintura encima (PAINT_LAYERS)
##   · thermal: familia de THERMAL · spark: clase de SPARK_CLASSES · tint: tabla de TEMPER_COLORS ("" si no toma
##   colores) · burr_factor: tendencia a la rebaba (1 = chapa de acero dulce; ESTIMACIÓN en todos) · cite: cita
##   corta para la lista `sources` del corte · press_hardened: acero estampado en caliente (aviso del pilar de boro).
const PANELS := {
	"acero-dulce": {
		"id": "acero-dulce", "group": "coche", "lab_body": "clasico", "kind": "acero", "paint_um": 110.0,
		"rm_mpa": 310.0, "thermal": "acero", "spark": "hierro_bajo_c", "tint": "acero", "burr_factor": 1.0,
		"source": LAB_SOURCE + ". Rm: el centro de 270-350 MPa del DC04 (ArcelorMittal, catálogo B10, EN 10130; FISICA.md).",
		"cite": LAB_CITE + "; ArcelorMittal B10", "press_hardened": false,
		"quality": "secondary", "estimates": "espesor de 0,9 mm (FISICA.md) · clase de chispa (acero de embutición de bajo carbono) · burr_factor",
	},
	"acero-bh": {
		"id": "acero-bh", "group": "coche", "lab_body": "moderno", "kind": "acero", "paint_um": 110.0,
		"rm_mpa": 340.0, "thermal": "acero", "spark": "hierro_bajo_c", "tint": "acero", "burr_factor": 1.0,
		"source": LAB_SOURCE + ". Rm 340 MPa (Nippon Steel 2013; voestalpine 2022; FISICA.md).",
		"cite": LAB_CITE + "; Nippon Steel 2013; voestalpine 2022", "press_hardened": false,
		"quality": "secondary", "estimates": "clase de chispa (acero de horno de bajo carbono) · burr_factor",
	},
	"aluminio": {
		"id": "aluminio", "group": "coche", "lab_body": "aluminio", "kind": "aluminio", "paint_um": 110.0,
		"rm_mpa": 273.0, "thermal": "aluminio", "spark": "no_ferrico", "tint": "", "burr_factor": 1.2,
		"source": LAB_SOURCE + ". Rm 273 MPa tras hornear la pintura (Prillhofer et al. 2014; FISICA.md).",
		"cite": LAB_CITE + "; Prillhofer et al. 2014", "press_hardened": false,
		"quality": "secondary", "estimates": "propiedades térmicas del 6082 · burr_factor",
	},
	"plastico-carroceria": {
		"id": "plastico-carroceria", "group": "coche", "lab_body": "plastico", "kind": "plastico", "paint_um": 110.0,
		"rm_mpa": 47.0, "thermal": "plastico", "spark": "plastico", "tint": "", "burr_factor": 1.5,
		"source": LAB_SOURCE + ". Termoplástico PPE/PA NORYL GTX964W (SABIC).",
		"cite": LAB_CITE + "; SABIC, NORYL GTX964W", "press_hardened": false,
		"quality": "secondary", "estimates": "espesor de 2,5 mm (FISICA.md) · calor específico · burr_factor (hilos de plástico fundido)",
	},
	"boro-22mnb5": {
		"id": "boro-22mnb5", "group": "rescate", "lab_body": "", "kind": "acero",
		"name": "Pilar B de acero al boro (22MnB5, Usibor 1500)", "t_mm": 1.5, "paint_um": 0.0,
		"hv": 464.0, "e_gpa": 210.0, "rm_mpa": 1500.0, "elongation_pct": 6.0, "carbon_max_pct": 0.24,
		"thermal": "acero", "spark": "acero_medio_c", "tint": "acero", "burr_factor": 0.4,
		"source": "ArcelorMittal, «Steels for Hot Stamping» (ficha técnica, febrero de 2026): 22MnB5 y Usibor 1500 tras el estampado en caliente, Rp0,2 1.100 MPa, Rm 1.500 MPa, A 6 %, C ≤ 0,24 %; para pilares A y B, largueros de techo y refuerzos antiintrusión; espesores de 0,8 a 2,4 mm. Pilar de 1,5 mm: ejemplo de ArcelorMittal Tailored Blanks, «Usibor 1500P and Ductibor 500P». Dureza por la tabla A.1 de DIN EN ISO 18265:2014 (Rm 1.485 → 460 HV, 1.520 → 470 HV; reproducida por WS Stahl).",
		"cite": "ArcelorMittal, «Steels for Hot Stamping» (2026); DIN EN ISO 18265:2014", "press_hardened": true,
		"quality": "secondary", "estimates": "hv 464 (conversión de Rm, orientativa) · espesor de ejemplo · burr_factor 0,4 (martensita poco dúctil)",
	},
	"dp800": {
		"id": "dp800", "group": "rescate", "lab_body": "", "kind": "acero",
		"name": "Refuerzo de acero de doble fase DP800 (Docol 800DP)", "t_mm": 1.2, "paint_um": 0.0,
		"hv": 273.0, "e_gpa": 210.0, "rm_mpa": 800.0, "elongation_pct": 10.0, "carbon_max_pct": 0.15,
		"thermal": "acero", "spark": "hierro_bajo_c", "tint": "acero", "burr_factor": 0.7,
		"source": "SSAB, ficha 2104 «Docol 800DP» (2017-11-16): CR500Y800T-DP, Rp0,2 500-650 MPa, Rm 800-950 MPa, A80 ≥ 10 %, C ≤ 0,15 %, de 0,50 a 2,10 mm; piezas de seguridad del coche. Dureza por DIN EN ISO 18265:2014, tabla A.1, con Rm 875 (centro del rango): ~273 HV.",
		"cite": "SSAB, «Docol 800DP» (2017); DIN EN ISO 18265:2014", "press_hardened": false,
		"quality": "secondary", "estimates": "espesor de 1,2 mm (dentro de 0,50-2,10) · hv (conversión de Rm) · burr_factor 0,7",
	},
	"perfil-aluminio": {
		"id": "perfil-aluminio", "group": "rescate", "lab_body": "", "kind": "aluminio",
		"name": "Perfil estructural de aluminio EN AW-6082 T6", "t_mm": 3.0, "paint_um": 0.0,
		"hv": 100.0, "e_gpa": 70.0, "rm_mpa": 290.0, "elongation_pct": 8.0, "carbon_max_pct": 0.0,
		"thermal": "aluminio", "spark": "no_ferrico", "tint": "", "burr_factor": 1.2,
		"source": "Hydro, «Technical datasheet - Extruded products, Alloy EN AW-6082» (rev. 4, 03/2023): perfil T6 de pared ≤ 5 mm, Rp0,2 250 y Rm 290 MPa (mínimos de EN 755-2), A 8 %, HBW 95 y HV 100 típicos, E 70 GPa; para vigas estructurales y parachoques.",
		"cite": "Hydro, ficha EN AW-6082 (2023)", "press_hardened": false,
		"quality": "secondary", "estimates": "pared de 3,0 mm (dentro de t ≤ 5 mm) · burr_factor 1,2",
	},
}


## Panel completo: los de coche con espesor (mm), dureza, módulo, σ0 y nombre de su carrocería del laboratorio.
## {} si no existe.
static func get_panel(id: String) -> Dictionary:
	if not PANELS.has(id):
		return {}
	var p: Dictionary = (PANELS[id] as Dictionary).duplicate(true)
	var key: String = p["lab_body"]
	if key != "":
		var body: Dictionary = CAR_BODIES[key]
		p["name"] = "Carrocería de " + String(body["long"])
		p["t_mm"] = float(body["t"]) / 1000.0
		p["hv"] = float(body["hv"])
		p["e_gpa"] = float(body["E"])
		p["sigma0"] = float(body["sigma0"])
		p["metal"] = body["metal"]
	else:
		p["sigma0"] = null
		p["metal"] = p["kind"] != "plastico"
	return p


## Espesor total que atraviesa el disco (mm): la chapa más su pintura.
static func total_thickness_mm(panel: Dictionary) -> float:
	return float(panel["t_mm"]) + float(panel["paint_um"]) / 1000.0


## Ids de todos los paneles, primero los de coche.
static func panel_ids() -> Array:
	return PANELS.keys()
