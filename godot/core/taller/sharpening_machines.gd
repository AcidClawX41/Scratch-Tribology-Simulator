## Taller · afiladora: catálogo de máquinas reales de consumo (Einhell, VEVOR, MRCM) y la de referencia (Tormek
## T-8), con las muelas o discos que traen de serie. Cada dato lleva `source` y `quality` (primary · secondary ·
## estimate); las citas completas y las URL están en docs/taller/afilado-simulador.md.
##
## Qué se ha comprobado: manuales originales de Einhell (TC-BG 150, TC-WD 200/150, TC-WG 200, TE-AG 125 CE), el
## manual de VEVOR de la MD150G-450, las fichas de VEVOR (MD150-4, SCM8082), las de MRCM (MR-13A, MR-X3), la de
## Tormek (T-8) y las de las muelas de recambio de Einhell (velocidad máxima). Donde el fabricante no da un dato
## (el abrasivo de algunas muelas, el ancho de otras), el campo es null o lleva su calidad «estimate».
## Versiones: las de Einhell y MRCM son de 230 V ~ 50 Hz; las de VEVOR comprobadas, de 120 V ~ 60 Hz (EE. UU.): no
## se ha encontrado la ficha de su versión europea y no se inventa su giro a 50 Hz.
##
## Esquema de una máquina:
##   { id, name, brand, model, kind: "banco" | "banco_lenta" | "combinada" | "lenta_humeda" | "amoladora" |
##     "afiladora_brocas" | "afiladora_fresas", market, mains_hz,
##     motor: { type: "induccion" | "universal" | "universal_constante", input_w: {…}, rpm_no_load: {…} },
##     wheels: [ { id, role, position ("izquierda" | "derecha" | "piedra" | "cuero" | "disco", como la vista 3D de
##                 CONTRATOS.md), mounted (false: recambio que se monta en lugar de la de serie), abrasive_id ("al2o3" |
##                 "cbn" | "diamante" | "sic" | "" si no se sabe), abrasive_quality, grit, grit_system, grit_number,
##                 diameter_mm, width_mm (null si el fabricante no lo da), bore_mm, diameter_min_mm, rpm, speed_ms
##                 (la que declara el fabricante, o null), max_rpm (marcada en la muela o el disco, o null), wet,
##                 honing (rueda de cuero), source, quality } ],
##     rest_gap_max_mm, layout { source, quality } (de dónde sale la posición de las muelas), water_trough (muela
##     que gira en agua), quench_pot (baño para enfriar la pieza), noise, weight_kg, accessories, for_tools, source,
##     quality }
## view(id, muela) da el diccionario `set_machine(view)` de la escena 3D (CONTRATOS.md → «Vista 3D de la afiladora»).
## Unidades: mm, rpm, W, m/s, kg, dB(A) (CONTRATOS.md).
extends RefCounted

const Sharpening = preload("res://core/taller/sharpening.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")

# ─────────────────────────────── Fuentes (texto de la cita) ───────────────────────────────
const SRC_TCBG150 := "Einhell TC-BG 150 (art. 44.126.32), manual original (I.-Nr. 11019, 2020): 220–240 V ~ 50 Hz; S1 110 W | S2 30 min 150 W; 2980 min⁻¹ en vacío; muela Ø150 (127–157) × 16 × 32 mm; 23,4 m/s; K36 y K60; apoyo y protector a ≤ 2 mm; LpA 82,3 dB(A), LWA 95,3 dB(A); ≈6 kg"
const SRC_TCBG150_WEB := "Einhell, ficha web de la TC-BG 150: motor de inducción, 2980 min⁻¹, muelas K36 y K60 de 150 mm, 5,89 kg"
const SRC_EINHELL_WHEEL_16 := "Einhell, muelas de recambio Ø150 × 32 × 16 mm K36 (49507435) y K60 (49507465), con anillo de 12,7 mm: máx. 4456 min⁻¹ (35,0 m/s)"
const SRC_EINHELL_WHEEL_20 := "Einhell, muela de recambio Ø150 × 32 × 20 mm K36 (49507535) para la TC-WD 200/150: máx. 4456 min⁻¹ (35,0 m/s)"
const SRC_TCWD := "Einhell TC-WD 200/150 (art. 44.172.42), manual original (I.-Nr. 11019, 2020): 220–240 V ~ 50 Hz; S1 170 W | S2 30 min 250 W; muela seca Ø150 × 20 × 32 mm K36 a 2980 min⁻¹ (23,4 m/s); muela húmeda Ø200 × 40 × 20 mm K200 a 134 min⁻¹ (1,4 m/s), sumergida 1/3 en agua; LpA 79,4 dB(A), LWA 92,4 dB(A); ≈9,5 kg. «El afinado se hace en la muela húmeda: basta apoyar la pieza con poca presión»"
const SRC_TCWG := "Einhell TC-WG 200 (art. 44.180.08), manual original (I.-Nr. 11019, 2020): 125 W; 110 min⁻¹; muela Ø200 (153–207) × 40 × 32 mm K220 a 1,15 m/s; rueda de asentar Ø180 × 30 mm a 1,04 m/s con pasta; galga de ángulos; LpA 79 dB(A), LWA 92 dB(A); ≈8 kg. «Cuanta menos presión, más afilado; cuanta más, más arranque»"
const SRC_TCWG_WEB := "Einhell, ficha web de la TC-WG 200: muela de corindón noble (Edelkorund) K220 de 200 × 40 mm, lenta y fina; rueda de cuero de 180 mm para quitar la rebaba; 7,33 kg"
const SRC_VEVOR_450 := "VEVOR (Sanven Technology), manual de la esmeriladora de banco MD150G-450: 120 V ~ 60 Hz, 3,8 A, 3450 rpm en vacío, muelas 150 × 16 × 12,7 mm K36 y K60, baño de enfriamiento; muelas según ANSI B7.1 de más de 3450 rpm; apoyo a ≤ 1/8″ (3,2 mm)"
const SRC_VEVOR_450_WEB := "VEVOR, ficha web de la MD150G-450: 450 W, 3,8 A, 3450 rpm, corindón marrón (brown fused alumina) 36 y 60, 9,08 kg"
const SRC_VEVOR_1750 := "VEVOR, ficha web de la esmeriladora lenta MD150-4: 120 V ~ 60 Hz, 250 W, 2,0 A, 1750 rpm, muelas de 150 mm de corindón marrón 36 y 60, agujero de 1/2″ (respuesta del fabricante), 8,62 kg"
const SRC_VEVOR_SCM := "VEVOR, ficha web del sistema de afilado en húmedo SCM8082: S2 30 min 150 W, 110 V, 155 rpm; muela húmeda 200 × 40 × 12 mm de grano 220; rueda de cuero 200 × 30 × 12,5 mm; guía de ángulo y plantilla recta; cubeta de agua; 10 kg"
const SRC_TEAG := "Einhell TE-AG 125 CE (art. 44.308.60), manual original (I.-Nr. 21074, 2025): 230 V ~ 50 Hz; 1100 W; 3000–12 000 min⁻¹ en 6 posiciones (≈3000, 6000, 8000, 9800, 10 500 y 12 000); disco máx. 125 mm; muela de desbaste 125 × 22 × 6 mm; M14; 2,6 kg; solo discos para ≥ 12 000 min⁻¹ y 80 m/s; desbastar con el disco a 30–40° de la superficie; se vende sin disco"
const SRC_TCAG := "Einhell, ficha web de la TC-AG 125/850: 850 W, 12 000 min⁻¹, disco de 125 mm, 1,75 kg, sin disco"
const SRC_MR13A := "MRCM (Zhejiang Meiri), ficha de la MR-13A: Φ3–13 (15) mm, punta de 95° (90°) a 135°, 220 V, 120 W, 4400 rpm, muela de CBN (para HSS), 11 pinzas, 10 kg. VEVOR la vende con 4500 rpm y 120 W (y muela SDC opcional para metal duro)"
const SRC_MR13A_WHEEL := "Muelas de recambio para MR-13A, MR-X3 y afines (anuncios de CPTRMCY y MRCM en Amazon): Ø78 × 10 mm, agujero de 12,7 mm, grano 230; CBN para HSS y SDC (diamante) para metal duro (vía buscador)"
const SRC_MRX3 := "MRCM, ficha de la MR-X3: Φ4–14 mm, 220 V / 160 W, 4400 rpm, ángulo de 0–5°, muela SDC (metal duro) de serie y CBN (HSS) opcional, 6 pinzas, fresas de 2, 3 y 4 labios, 14 kg"
const SRC_TORMEK_T8 := "Tormek, ficha de la T-8 Original: motor industrial monofásico de 200 W (entrada) para uso continuo; muela SG-250 de óxido de aluminio de Ø250 × 50 mm a 100 rpm (220 a ≈1000 con el SP-650); rueda de cuero LA-220 de Ø220 × 31 mm con pasta PA-70; 14,8 kg; versiones de 230 V y 115 V"
const SRC_NPS := "Naval Postgraduate School, «Safety Gram: pedestal / bench grinder» (resumen de 29 CFR 1910.215 y ANSI B7.1): apoyo a ≤ 1/8″, ponerse a un lado al arrancar, mover la pieza por toda la cara de la muela, enfriar en agua las herramientas templadas pequeñas (las brocas no, se agrietan), no amolar con el costado de la muela"
const SRC_PFERD_LAMINAS := "PFERD POLIFAN PFF 125 A PSF STEELOX (disco de láminas de corindón P40–P120, EN 13743, máx. 12 200 rpm en 125 mm), abrasives.gd"
const SRC_PFERD_DESBASTE := "PFERD E 125-7 PSF STEEL (disco de desbaste de corindón, forma 27, máx. 12 200 rpm en 125 mm), abrasives.gd"
const SRC_GRANSFORS := "Gränsfors Bruk, guía de reafilado: muela húmeda o piedra gruesa, lima para mellas grandes, piedras y cuero para la rebaba; «no calientes el acero o perderá el temple: enfría a menudo»; 25–30° en filo recto"
const SRC_MOWER_ANGLE := "All American Sharpener, «Blade guide»: 30° es el filo habitual de una cuchilla de cortacésped; 35–45° para igualar el bisel de fábrica de John Deere, Gator, Walker, Kubota o EGO"
const SRC_TOROBLADE :="Toro, manual 205759: afilar la cuchilla con lima manteniendo el ángulo original y quitando lo mismo de los dos extremos (equilibrado); Honda Lawn Parts: las cuchillas son de acero dulce y se estropean si se calientan: con herramienta eléctrica, dejar enfriar unos segundos entre pasadas"
const SRC_KSN := "Knife Steel Nerds (L. Thomas, 2019), «Does sharpening with a grinder ruin your edge?»: CATRA encuentra ablandamiento del filo en más del 75 % de los cuchillos ensayados (casi todos los afilados en fábrica); R. Landes midió hasta 5 HRC menos junto al filo con banda de 220; enfriar en agua entre pasadas no basta porque el filo se calienta muy deprisa"
const SRC_TC9524_DRILL := "US Army TC 9-524, cap. 4: afilado de brocas a pulso en esmeriladora con galga de 59°; no dejar que se calienten (el azul indica que se ha perdido el temple); una broca muy caliente puede agrietarse si se mete en agua fría"
const SRC_TC9524_MILL := "US Army TC 9-524, cap. 5: las fresas se afilan en una afiladora universal de herramientas con muela de copa o recta y el dedo de apoyo desplazado"
# Disposición de las muelas (para dibujar la máquina).
const SRC_LAYOUT_TCBG := "Einhell TC-BG 150, manual original, fig. 1: muela gruesa (5) a la izquierda y fina (6) a la derecha, vista de frente"
const SRC_LAYOUT_TCWD := "Einhell TC-WD 200/150, manual original, fig. 1: muela húmeda (6) con su depósito de agua (10) a la izquierda y muela seca (5) a la derecha, vista de frente"
const SRC_LAYOUT_TCWG := "Einhell TC-WG 200, manual original, fig. 1: muela húmeda (5) con su depósito de agua (10) en un extremo del eje y rueda de asentar (6) en el otro"
const SRC_LAYOUT_VEVOR := "El manual y la ficha de VEVOR no dicen en qué lado va cada grano: la gruesa a la izquierda es una convención de dibujo (como en la Einhell TC-BG 150)"
const SRC_LAYOUT_SCM := "La ficha de VEVOR no da el esquema: piedra con su cubeta en un extremo del eje y rueda de cuero en el otro, como en la Tormek T-8"
const SRC_LAYOUT_ANGLE := "Manual de la amoladora: un solo disco en el husillo M14, bajo el protector; el de desbaste y el de láminas se montan uno u otro"
const SRC_LAYOUT_MRCM := "Fichas de MRCM y anuncios de las muelas de recambio: una sola muela dentro de la máquina; la otra (CBN o SDC) se monta en su lugar"
const SRC_LAYOUT_TORMEK := "Tormek, ficha de la T-8: muela SG-250 con su cubeta de agua en un extremo del eje y rueda de cuero LA-220 en el otro"

const FITS := ["ideal", "buena", "con_cuidado", "no"]

## Máquinas.
const MACHINES := {
	"einhell_tc_bg_150": {
		"id": "einhell_tc_bg_150", "name": "Einhell TC-BG 150", "brand": "Einhell", "model": "TC-BG 150 (44.126.32)",
		"kind": "banco", "market": "UE, 220–240 V ~ 50 Hz", "mains_hz": 50.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 150.0, "s1": 110.0, "s2_30min": 150.0, "source": SRC_TCBG150, "quality": "primary" },
			"rpm_no_load": { "value": 2980.0, "source": SRC_TCBG150, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "grueso", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "estimate",
				"position": "izquierda", "mounted": true,
				"abrasive_note": "Einhell no dice el grano; «muela cerámica» es el ligante vitrificado y el grano habitual de estas muelas es corindón",
				"grit": "K36", "grit_system": "fepa_f", "grit_number": 36,
				"diameter_mm": 150.0, "diameter_min_mm": 127.0, "width_mm": 16.0, "bore_mm": 32.0,
				"rpm": 2980.0, "speed_ms": 23.4, "max_rpm": 4456.0, "wet": false, "honing": false,
				"source": SRC_TCBG150 + ". " + SRC_EINHELL_WHEEL_16, "quality": "primary",
			},
			{
				"id": "fino", "role": "acabado", "abrasive_id": "al2o3", "abrasive_quality": "estimate",
				"position": "derecha", "mounted": true,
				"abrasive_note": "Einhell no dice el grano; «muela cerámica» es el ligante vitrificado y el grano habitual de estas muelas es corindón",
				"grit": "K60", "grit_system": "fepa_f", "grit_number": 60,
				"diameter_mm": 150.0, "diameter_min_mm": 127.0, "width_mm": 16.0, "bore_mm": 32.0,
				"rpm": 2980.0, "speed_ms": 23.4, "max_rpm": 4456.0, "wet": false, "honing": false,
				"source": SRC_TCBG150 + ". " + SRC_EINHELL_WHEEL_16, "quality": "primary",
			},
		],
		"rest_gap_max_mm": { "value": 2.0, "source": SRC_TCBG150, "quality": "primary" },
		"layout": { "source": SRC_LAYOUT_TCBG, "quality": "primary" },
		"water_trough": false, "quench_pot": false,
		"noise": { "lpa_dba": 82.3, "lwa_dba": 95.3, "k_dba": 3.0, "source": SRC_TCBG150, "quality": "primary" },
		"weight_kg": { "value": 6.0, "source": SRC_TCBG150 + "; " + SRC_TCBG150_WEB, "quality": "primary" },
		"accessories": ["dos apoyos de pieza regulables", "dos protectores de chispas con cristal"],
		"for_tools": {
			"cuchillo": { "fit": "con_cuidado", "why": "Muela seca a 23,4 m/s: con 10 N el vértice de un cuchillo fino pasa el revenido en décimas de segundo (edge_thermal.gd). Solo para reperfilar con presión muy ligera y pasadas rápidas; el filo final, en húmedo o a mano.", "source": SRC_KSN + "; " + SRC_TCBG150 },
			"broca": { "fit": "buena", "why": "El método clásico a pulso con galga de 59° (TC 9-524). Sin agua de golpe si la broca está muy caliente.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Las fresas se afilan en una afiladora universal con el dedo de apoyo desplazado (TC 9-524).", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "con_cuidado", "why": "Sección gruesa: aguanta más, pero Gränsfors pide no calentar el acero y enfriar a menudo.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "buena", "why": "Acero dulce y filo grueso: mantener el ángulo original y dejar enfriar entre pasadas.", "source": SRC_TOROBLADE },
		},
		"source": SRC_TCBG150 + ". " + SRC_TCBG150_WEB, "quality": "primary",
	},
	"einhell_tc_wd_200_150": {
		"id": "einhell_tc_wd_200_150", "name": "Einhell TC-WD 200/150", "brand": "Einhell", "model": "TC-WD 200/150 (44.172.42)",
		"kind": "combinada", "market": "UE, 220–240 V ~ 50 Hz", "mains_hz": 50.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 250.0, "s1": 170.0, "s2_30min": 250.0, "source": SRC_TCWD, "quality": "primary" },
			"rpm_no_load": { "value": 2980.0, "source": SRC_TCWD, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "seca", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "estimate",
				"position": "derecha", "mounted": true,
				"abrasive_note": "Einhell no dice el grano de la muela seca; corindón es lo habitual",
				"grit": "K36", "grit_system": "fepa_f", "grit_number": 36,
				"diameter_mm": 150.0, "diameter_min_mm": 127.0, "width_mm": 20.0, "bore_mm": 32.0,
				"rpm": 2980.0, "speed_ms": 23.4, "max_rpm": 4456.0, "wet": false, "honing": false,
				"source": SRC_TCWD + ". " + SRC_EINHELL_WHEEL_20, "quality": "primary",
			},
			{
				"id": "humeda", "role": "afilado", "abrasive_id": "", "abrasive_quality": "estimate",
				"position": "piedra", "mounted": true,
				"abrasive_note": "Einhell no dice de qué es la muela húmeda K200; «K» es la Körnung (grano) de Einhell y FEPA F no tiene F200 (queda entre F180 y F220)",
				"grit": "K200", "grit_system": "", "grit_number": 200,
				"diameter_mm": 200.0, "diameter_min_mm": 173.0, "width_mm": 40.0, "bore_mm": 20.0,
				"rpm": 134.0, "speed_ms": 1.4, "max_rpm": null, "wet": true, "honing": false,
				"source": SRC_TCWD, "quality": "primary",
			},
		],
		"rest_gap_max_mm": { "value": 2.0, "source": SRC_TCWD, "quality": "primary" },
		"layout": { "source": SRC_LAYOUT_TCWD, "quality": "primary" },
		"water_trough": true, "quench_pot": false,
		"noise": { "lpa_dba": 79.4, "lwa_dba": 92.4, "k_dba": 3.0, "source": SRC_TCWD, "quality": "primary" },
		"weight_kg": { "value": 9.5, "source": SRC_TCWD, "quality": "primary" },
		"accessories": ["depósito de agua de la muela húmeda", "apoyo de pieza", "protector de chispas"],
		"for_tools": {
			"cuchillo": { "fit": "buena", "why": "Desbastar solo si hace falta en la seca y afilar en la húmeda lenta (1,4 m/s) con poca presión, como dice el manual.", "source": SRC_TCWD },
			"broca": { "fit": "buena", "why": "La muela seca sirve para el método a pulso de TC 9-524.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "buena", "why": "Gränsfors recomienda la muela húmeda.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "buena", "why": "En la muela seca, manteniendo el ángulo original y dejando enfriar.", "source": SRC_TOROBLADE },
		},
		"source": SRC_TCWD, "quality": "primary",
	},
	"einhell_tc_wg_200": {
		"id": "einhell_tc_wg_200", "name": "Einhell TC-WG 200", "brand": "Einhell", "model": "TC-WG 200 (44.180.08)",
		"kind": "lenta_humeda", "market": "UE, 220–240 V ~ 50 Hz", "mains_hz": 50.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 125.0, "source": SRC_TCWG, "quality": "primary" },
			"rpm_no_load": { "value": 110.0, "source": SRC_TCWG, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "humeda", "role": "afilado", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "piedra", "mounted": true,
				"abrasive_note": "corindón noble (Edelkorund), ficha web de Einhell",
				"grit": "K220", "grit_system": "fepa_f", "grit_number": 220,
				"diameter_mm": 200.0, "diameter_min_mm": 153.0, "width_mm": 40.0, "bore_mm": 32.0,
				"rpm": 110.0, "speed_ms": 1.15, "max_rpm": null, "wet": true, "honing": false,
				"source": SRC_TCWG + ". " + SRC_TCWG_WEB, "quality": "primary",
			},
			{
				"id": "cuero", "role": "asentado", "abrasive_id": "", "abrasive_quality": "primary",
				"position": "cuero", "mounted": true,
				"abrasive_note": "rueda de cuero con pasta de asentar; nunca en seco ni contra el filo",
				"grit": "pasta de asentar", "grit_system": "", "grit_number": 0,
				"diameter_mm": 180.0, "diameter_min_mm": null, "width_mm": 30.0, "bore_mm": null,
				"rpm": 110.0, "speed_ms": 1.04, "max_rpm": null, "wet": false, "honing": true,
				"source": SRC_TCWG + ". " + SRC_TCWG_WEB, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_TCWG, "quality": "primary" },
		"water_trough": true, "quench_pot": false,
		"noise": { "lpa_dba": 79.0, "lwa_dba": 92.0, "k_dba": 3.0, "source": SRC_TCWG, "quality": "primary" },
		"weight_kg": { "value": 8.0, "source": SRC_TCWG + "; " + SRC_TCWG_WEB + " (7,33 kg)", "quality": "primary" },
		"accessories": ["galga de ángulos", "soporte universal con brazo de Ø12 mm", "piedra de reavivar de dos granos", "pasta de asentar", "depósito de agua regulable"],
		"for_tools": {
			"cuchillo": { "fit": "ideal", "why": "Lenta (1,15 m/s) y en agua: el filo no se calienta; la rueda de cuero quita la rebaba.", "source": SRC_TCWG },
			"broca": { "fit": "con_cuidado", "why": "Lenta y sin plantilla de brocas: es difícil mantener la incidencia a mano.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "buena", "why": "Muela húmeda: la que recomienda Gränsfors.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "con_cuidado", "why": "Funciona, pero es lenta para un filo grueso de acero dulce.", "source": SRC_TOROBLADE },
		},
		"source": SRC_TCWG + ". " + SRC_TCWG_WEB, "quality": "primary",
	},
	"vevor_md150g_450": {
		"id": "vevor_md150g_450", "name": "VEVOR MD150G-450 (6″)", "brand": "VEVOR", "model": "MD150G-450",
		"kind": "banco", "market": "EE. UU., 120 V ~ 60 Hz", "mains_hz": 60.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 450.0, "source": SRC_VEVOR_450_WEB + "; " + SRC_VEVOR_450 + " (3,8 A a 120 V)", "quality": "primary" },
			"rpm_no_load": { "value": 3450.0, "source": SRC_VEVOR_450, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "grueso", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "izquierda", "mounted": true,
				"abrasive_note": "corindón marrón (brown fused alumina), ficha de VEVOR",
				"grit": "36", "grit_system": "fepa_f", "grit_number": 36,
				"diameter_mm": 150.0, "diameter_min_mm": null, "width_mm": 16.0, "bore_mm": 12.7,
				"rpm": 3450.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_VEVOR_450 + ". " + SRC_VEVOR_450_WEB, "quality": "primary",
			},
			{
				"id": "fino", "role": "acabado", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "derecha", "mounted": true,
				"abrasive_note": "corindón marrón (brown fused alumina), ficha de VEVOR",
				"grit": "60", "grit_system": "fepa_f", "grit_number": 60,
				"diameter_mm": 150.0, "diameter_min_mm": null, "width_mm": 16.0, "bore_mm": 12.7,
				"rpm": 3450.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_VEVOR_450 + ". " + SRC_VEVOR_450_WEB, "quality": "primary",
			},
		],
		"rest_gap_max_mm": { "value": 3.2, "source": SRC_VEVOR_450, "quality": "primary" },
		"layout": { "source": SRC_LAYOUT_VEVOR, "quality": "estimate" },
		"water_trough": false, "quench_pot": true,
		"noise": null,
		"weight_kg": { "value": 9.08, "source": SRC_VEVOR_450_WEB, "quality": "primary" },
		"accessories": ["baño de enfriamiento", "dos apoyos regulables sin herramientas", "dos pantallas transparentes"],
		"for_tools": {
			"cuchillo": { "fit": "con_cuidado", "why": "Seca y a 27,1 m/s: calienta aún más que una de 50 Hz. El baño sirve para las herramientas gruesas; en un filo fino el calor llega antes de poder enfriarlo.", "source": SRC_KSN + "; " + SRC_VEVOR_450 },
			"broca": { "fit": "buena", "why": "Método a pulso de TC 9-524, con el baño para la broca templada (no metida de golpe si está muy caliente).", "source": SRC_TC9524_DRILL + "; " + SRC_NPS },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "con_cuidado", "why": "Aguanta más que un cuchillo, pero hay que enfriar a menudo.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "buena", "why": "El propio manual trata el afilado de cuchillas de cortacésped por los dos extremos y su equilibrado.", "source": SRC_VEVOR_450 + "; " + SRC_TOROBLADE },
		},
		"source": SRC_VEVOR_450 + ". " + SRC_VEVOR_450_WEB, "quality": "primary",
	},
	"vevor_md150_4": {
		"id": "vevor_md150_4", "name": "VEVOR MD150-4 (6″, lenta)", "brand": "VEVOR", "model": "MD150-4",
		"kind": "banco_lenta", "market": "EE. UU., 120 V ~ 60 Hz", "mains_hz": 60.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 250.0, "source": SRC_VEVOR_1750, "quality": "primary" },
			"rpm_no_load": { "value": 1750.0, "source": SRC_VEVOR_1750, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "grueso", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "izquierda", "mounted": true,
				"abrasive_note": "corindón marrón, ficha de VEVOR",
				"grit": "36", "grit_system": "fepa_f", "grit_number": 36,
				"diameter_mm": 150.0, "diameter_min_mm": null, "width_mm": null, "bore_mm": 12.7,
				"rpm": 1750.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_VEVOR_1750, "quality": "primary",
			},
			{
				"id": "fino", "role": "acabado", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "derecha", "mounted": true,
				"abrasive_note": "corindón marrón, ficha de VEVOR",
				"grit": "60", "grit_system": "fepa_f", "grit_number": 60,
				"diameter_mm": 150.0, "diameter_min_mm": null, "width_mm": null, "bore_mm": 12.7,
				"rpm": 1750.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_VEVOR_1750, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_VEVOR, "quality": "estimate" },
		"water_trough": false, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 8.62, "source": SRC_VEVOR_1750, "quality": "primary" },
		"accessories": ["apoyo regulable sin herramientas", "pantalla transparente"],
		"for_tools": {
			"cuchillo": { "fit": "con_cuidado", "why": "Lenta (13,7 m/s): con la misma fuerza mete la mitad de calor que una de 3450 rpm, pero sigue siendo seca.", "source": SRC_VEVOR_1750 + "; " + SRC_KSN },
			"broca": { "fit": "buena", "why": "Método a pulso de TC 9-524; calienta menos que la rápida.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "buena", "why": "Lenta y con sección gruesa; enfriar a menudo.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "buena", "why": "Mantener el ángulo original y equilibrar.", "source": SRC_TOROBLADE },
		},
		"source": SRC_VEVOR_1750, "quality": "primary",
	},
	"vevor_scm8082": {
		"id": "vevor_scm8082", "name": "VEVOR SCM8082 (8″, en húmedo)", "brand": "VEVOR", "model": "SCM8082",
		"kind": "lenta_humeda", "market": "EE. UU., 110 V", "mains_hz": 60.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 150.0, "s2_30min": 150.0, "source": SRC_VEVOR_SCM, "quality": "primary" },
			"rpm_no_load": { "value": 155.0, "source": SRC_VEVOR_SCM, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "humeda", "role": "afilado", "abrasive_id": "", "abrasive_quality": "estimate",
				"position": "piedra", "mounted": true,
				"abrasive_note": "VEVOR no dice de qué es la muela de grano 220",
				"grit": "220", "grit_system": "fepa_f", "grit_number": 220,
				"diameter_mm": 200.0, "diameter_min_mm": null, "width_mm": 40.0, "bore_mm": 12.0,
				"rpm": 155.0, "speed_ms": null, "max_rpm": null, "wet": true, "honing": false,
				"source": SRC_VEVOR_SCM, "quality": "primary",
			},
			{
				"id": "cuero", "role": "asentado", "abrasive_id": "", "abrasive_quality": "primary",
				"position": "cuero", "mounted": true,
				"abrasive_note": "rueda de cuero para quitar la rebaba y pulir",
				"grit": "cuero", "grit_system": "", "grit_number": 0,
				"diameter_mm": 200.0, "diameter_min_mm": null, "width_mm": 30.0, "bore_mm": 12.5,
				"rpm": 155.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": true,
				"source": SRC_VEVOR_SCM, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_SCM, "quality": "estimate" },
		"water_trough": true, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 10.0, "source": SRC_VEVOR_SCM, "quality": "primary" },
		"accessories": ["guía de ángulo", "plantilla recta", "cubeta de agua"],
		"for_tools": {
			"cuchillo": { "fit": "ideal", "why": "Lenta (1,6 m/s) y en agua; la rueda de cuero quita la rebaba.", "source": SRC_VEVOR_SCM },
			"broca": { "fit": "con_cuidado", "why": "Sin plantilla de brocas: es difícil mantener la incidencia a mano.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "buena", "why": "Muela húmeda, como recomienda Gränsfors.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "con_cuidado", "why": "Lenta para un filo grueso.", "source": SRC_TOROBLADE },
		},
		"source": SRC_VEVOR_SCM, "quality": "primary",
	},
	"einhell_te_ag_125_ce": {
		"id": "einhell_te_ag_125_ce", "name": "Einhell TE-AG 125 CE", "brand": "Einhell", "model": "TE-AG 125 CE (44.308.60)",
		"kind": "amoladora", "market": "UE, 230 V ~ 50 Hz", "mains_hz": 50.0,
		"motor": {
			"type": "universal_constante",
			"input_w": { "value": 1100.0, "source": SRC_TEAG, "quality": "primary" },
			"rpm_no_load": { "value": 12000.0, "min": 3000.0, "max": 12000.0, "steps": [3000.0, 6000.0, 8000.0, 9800.0, 10500.0, 12000.0], "source": SRC_TEAG, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "laminas", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "disco", "mounted": true,
				"abrasive_note": "disco de láminas de corindón (accesorio: la amoladora se vende sin disco); de P40 a P120, se toma P60",
				"grit": "P60", "grit_system": "fepa_p", "grit_number": 60,
				"diameter_mm": 125.0, "diameter_min_mm": null, "width_mm": null, "bore_mm": 22.23,
				"rpm": 12000.0, "speed_ms": null, "max_rpm": 12200.0, "wet": false, "honing": false,
				"disc_id": "laminas",
				"source": SRC_TEAG + ". " + SRC_PFERD_LAMINAS, "quality": "primary",
			},
			{
				"id": "desbaste", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "disco", "mounted": false,
				"abrasive_note": "muela de desbaste de corindón de forma 27 (accesorio)",
				"grit": "", "grit_system": "", "grit_number": 0,
				"diameter_mm": 125.0, "diameter_min_mm": null, "width_mm": 7.2, "bore_mm": 22.23,
				"rpm": 12000.0, "speed_ms": null, "max_rpm": 12200.0, "wet": false, "honing": false,
				"disc_id": "desbaste",
				"source": SRC_TEAG + ". " + SRC_PFERD_DESBASTE, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_ANGLE, "quality": "primary" },
		"water_trough": false, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 2.6, "source": SRC_TEAG, "quality": "primary" },
		"accessories": ["protector de desbaste", "empuñadura adicional en 3 posiciones", "llave de pivotes"],
		"for_tools": {
			"cuchillo": { "fit": "no", "why": "Hasta 78,5 m/s con grano P40–P120 y sin apoyo: el filo fino se quema en menos de un segundo (edge_thermal.gd), el bisel sale irregular y el disco puede enganchar la hoja.", "source": SRC_TEAG + "; " + SRC_KSN },
			"broca": { "fit": "no", "why": "Sin apoyo ni plantilla no se puede dar la incidencia y los labios salen desiguales.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "con_cuidado", "why": "Solo para reparar mellas grandes, en la posición más lenta y sin calentar; Gränsfors prefiere lima y muela húmeda.", "source": SRC_GRANSFORS + "; " + SRC_TEAG },
			"cortacesped": { "fit": "buena", "why": "Acero dulce y filo grueso de 30–45°: con disco de láminas a pocas rpm, pasadas cortas y enfriando.", "source": SRC_TOROBLADE + "; " + SRC_MOWER_ANGLE + "; " + SRC_TEAG },
		},
		"source": SRC_TEAG, "quality": "primary",
	},
	"einhell_tc_ag_125_850": {
		"id": "einhell_tc_ag_125_850", "name": "Einhell TC-AG 125/850", "brand": "Einhell", "model": "TC-AG 125/850",
		"kind": "amoladora", "market": "UE, 230 V ~ 50 Hz", "mains_hz": 50.0,
		"motor": {
			"type": "universal",
			"input_w": { "value": 850.0, "source": SRC_TCAG, "quality": "primary" },
			"rpm_no_load": { "value": 12000.0, "source": SRC_TCAG, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "laminas", "role": "desbaste", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "disco", "mounted": true,
				"abrasive_note": "disco de láminas de corindón (accesorio: la amoladora se vende sin disco); de P40 a P120, se toma P60",
				"grit": "P60", "grit_system": "fepa_p", "grit_number": 60,
				"diameter_mm": 125.0, "diameter_min_mm": null, "width_mm": null, "bore_mm": 22.23,
				"rpm": 12000.0, "speed_ms": null, "max_rpm": 12200.0, "wet": false, "honing": false,
				"disc_id": "laminas",
				"source": SRC_TCAG + ". " + SRC_PFERD_LAMINAS, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_ANGLE, "quality": "primary" },
		"water_trough": false, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 1.75, "source": SRC_TCAG, "quality": "primary" },
		"accessories": [],
		"for_tools": {
			"cuchillo": { "fit": "no", "why": "12 000 rpm fijas (78,5 m/s con 125 mm): el filo fino se quema en menos de un segundo y no hay apoyo.", "source": SRC_TCAG + "; " + SRC_KSN },
			"broca": { "fit": "no", "why": "Sin apoyo ni plantilla no se puede dar la incidencia.", "source": SRC_TC9524_DRILL },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "con_cuidado", "why": "Solo para mellas grandes y sin calentar; mejor lima y muela húmeda.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "con_cuidado", "why": "Sirve con disco de láminas y pasadas muy cortas: a velocidad fija calienta más que la de velocidad regulable.", "source": SRC_TOROBLADE },
		},
		"source": SRC_TCAG, "quality": "primary",
	},
	"mrcm_mr_13a": {
		"id": "mrcm_mr_13a", "name": "MRCM MR-13A (afiladora de brocas)", "brand": "MRCM (también VEVOR)", "model": "MR-13A",
		"kind": "afiladora_brocas", "market": "220 V", "mains_hz": 50.0,
		"motor": {
			"type": "universal",
			"input_w": { "value": 120.0, "source": SRC_MR13A, "quality": "primary" },
			"rpm_no_load": { "value": 4400.0, "min": 4400.0, "max": 4500.0, "source": SRC_MR13A, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "cbn", "role": "afilado", "abrasive_id": "cbn", "abrasive_quality": "primary",
				"position": "disco", "mounted": true,
				"abrasive_note": "CBN para acero rápido (HSS)",
				"grit": "230", "grit_system": "", "grit_number": 230,
				"diameter_mm": 78.0, "diameter_min_mm": null, "width_mm": 10.0, "bore_mm": 12.7,
				"rpm": 4400.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_MR13A + ". " + SRC_MR13A_WHEEL, "quality": "secondary",
			},
			{
				"id": "sdc", "role": "afilado", "abrasive_id": "diamante", "abrasive_quality": "primary",
				"position": "disco", "mounted": false,
				"abrasive_note": "SDC (diamante) solo para brocas de metal duro, opcional",
				"grit": "230", "grit_system": "", "grit_number": 230,
				"diameter_mm": 78.0, "diameter_min_mm": null, "width_mm": 10.0, "bore_mm": 12.7,
				"rpm": 4400.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_MR13A + ". " + SRC_MR13A_WHEEL, "quality": "secondary",
			},
		],
		"point_deg": { "min": 95.0, "max": 135.0, "source": SRC_MR13A, "quality": "primary" },
		"range_mm": { "min": 3.0, "max": 13.0, "source": SRC_MR13A, "quality": "primary" },
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_MRCM, "quality": "secondary" },
		"water_trough": false, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 10.0, "source": SRC_MR13A, "quality": "primary" },
		"accessories": ["11 pinzas de Φ3 a Φ13", "portapinzas"],
		"for_tools": {
			"cuchillo": { "fit": "no", "why": "Solo afila brocas.", "source": SRC_MR13A },
			"broca": { "fit": "ideal", "why": "Punta de 95–135° fija con pinza: labios iguales y la incidencia que da la máquina, con CBN (poco calor).", "source": SRC_MR13A },
			"fresa": { "fit": "no", "why": "VEVOR responde que no afila fresas.", "source": SRC_MR13A },
			"hacha": { "fit": "no", "why": "Solo afila brocas.", "source": SRC_MR13A },
			"cortacesped": { "fit": "no", "why": "Solo afila brocas.", "source": SRC_MR13A },
		},
		"source": SRC_MR13A + ". " + SRC_MR13A_WHEEL, "quality": "primary",
	},
	"mrcm_mr_x3": {
		"id": "mrcm_mr_x3", "name": "MRCM MR-X3 (afiladora de fresas)", "brand": "MRCM", "model": "MR-X3",
		"kind": "afiladora_fresas", "market": "220 V", "mains_hz": 50.0,
		"motor": {
			"type": "universal",
			"input_w": { "value": 160.0, "source": SRC_MRX3, "quality": "primary" },
			"rpm_no_load": { "value": 4400.0, "source": SRC_MRX3, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "sdc", "role": "afilado", "abrasive_id": "diamante", "abrasive_quality": "primary",
				"position": "disco", "mounted": true,
				"abrasive_note": "SDC (diamante) de serie, para fresas de metal duro",
				"grit": "230", "grit_system": "", "grit_number": 230,
				"diameter_mm": 78.0, "diameter_min_mm": null, "width_mm": 10.0, "bore_mm": 12.7,
				"rpm": 4400.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_MRX3 + ". " + SRC_MR13A_WHEEL, "quality": "secondary",
			},
			{
				"id": "cbn", "role": "afilado", "abrasive_id": "cbn", "abrasive_quality": "primary",
				"position": "disco", "mounted": false,
				"abrasive_note": "CBN opcional, para fresas de acero rápido",
				"grit": "230", "grit_system": "", "grit_number": 230,
				"diameter_mm": 78.0, "diameter_min_mm": null, "width_mm": 10.0, "bore_mm": 12.7,
				"rpm": 4400.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": false,
				"source": SRC_MRX3 + ". " + SRC_MR13A_WHEEL, "quality": "secondary",
			},
		],
		"angle_deg": { "min": 0.0, "max": 5.0, "source": SRC_MRX3 + " («point angle» de 0–5°: en una fresa de mango es la inclinación del filo frontal, el «dish» de Nachi; interpretación nuestra)", "quality": "estimate" },
		"range_mm": { "min": 4.0, "max": 14.0, "source": SRC_MRX3, "quality": "primary" },
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_MRCM, "quality": "secondary" },
		"water_trough": false, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 14.0, "source": SRC_MRX3, "quality": "primary" },
		"accessories": ["6 pinzas de Φ4 a Φ14", "portapinzas de 2 y 4 labios", "portapinzas de 3 y 6 labios"],
		"for_tools": {
			"cuchillo": { "fit": "no", "why": "Solo afila el extremo de fresas de mango.", "source": SRC_MRX3 },
			"broca": { "fit": "no", "why": "Es una afiladora de fresas.", "source": SRC_MRX3 },
			"fresa": { "fit": "ideal", "why": "Afila los filos frontales de fresas de 2, 3 y 4 labios; SDC para metal duro y CBN para HSS.", "source": SRC_MRX3 },
			"hacha": { "fit": "no", "why": "Solo afila fresas.", "source": SRC_MRX3 },
			"cortacesped": { "fit": "no", "why": "Solo afila fresas.", "source": SRC_MRX3 },
		},
		"source": SRC_MRX3 + ". " + SRC_MR13A_WHEEL, "quality": "primary",
	},
	"tormek_t8": {
		"id": "tormek_t8", "name": "Tormek T-8 (referencia)", "brand": "Tormek", "model": "T-8 Original",
		"kind": "lenta_humeda", "market": "UE, 230 V (y 115 V)", "mains_hz": 50.0,
		"motor": {
			"type": "induccion",
			"input_w": { "value": 200.0, "source": SRC_TORMEK_T8, "quality": "primary" },
			"rpm_no_load": { "value": 100.0, "min": 90.0, "max": 100.0, "source": SRC_TORMEK_T8 + "; " + Sharpening.SRC_TORMEK_T8, "quality": "primary" },
		},
		"wheels": [
			{
				"id": "sg250", "role": "afilado", "abrasive_id": "al2o3", "abrasive_quality": "primary",
				"position": "piedra", "mounted": true,
				"abrasive_note": "SG-250 de óxido de aluminio; el SP-650 la deja entre grano 220 y ≈1000",
				"grit": "220–1000", "grit_system": "fepa_f", "grit_number": 220,
				"diameter_mm": 250.0, "diameter_min_mm": null, "width_mm": 50.0, "bore_mm": null,
				"rpm": 100.0, "speed_ms": null, "max_rpm": null, "wet": true, "honing": false,
				"source": SRC_TORMEK_T8 + ". " + Sharpening.SRC_TORMEK_SG, "quality": "primary",
			},
			{
				"id": "la220", "role": "asentado", "abrasive_id": "", "abrasive_quality": "primary",
				"position": "cuero", "mounted": true,
				"abrasive_note": "rueda de cuero LA-220 con pasta PA-70; siempre girando alejándose del filo",
				"grit": "PA-70", "grit_system": "", "grit_number": 0,
				"diameter_mm": 220.0, "diameter_min_mm": null, "width_mm": 31.0, "bore_mm": null,
				"rpm": 100.0, "speed_ms": null, "max_rpm": null, "wet": false, "honing": true,
				"source": SRC_TORMEK_T8, "quality": "primary",
			},
		],
		"rest_gap_max_mm": null,
		"layout": { "source": SRC_LAYOUT_TORMEK, "quality": "primary" },
		"water_trough": true, "quench_pot": false,
		"noise": null,
		"weight_kg": { "value": 14.8, "source": SRC_TORMEK_T8, "quality": "primary" },
		"accessories": ["plantilla SE-77", "goniómetro WM-200 AngleMaster", "reavivador SP-650", "pasta PA-70", "herramienta de rectificar"],
		"for_tools": {
			"cuchillo": { "fit": "ideal", "why": "La referencia: 1,3 m/s en agua, sin riesgo de destemplar (Tormek); filo de ≈0,35 µm con piedra y cuero (Verhoeven 2004).", "source": SRC_TORMEK_T8 + "; " + Sharpening.SRC_VERHOEVEN },
			"broca": { "fit": "con_cuidado", "why": "Necesita la plantilla de brocas, que no viene con la máquina.", "source": SRC_TORMEK_T8 },
			"fresa": { "fit": "no", "why": "Hace falta una afiladora universal o una de fresas.", "source": SRC_TC9524_MILL },
			"hacha": { "fit": "ideal", "why": "Muela húmeda, como recomienda Gränsfors.", "source": SRC_GRANSFORS },
			"cortacesped": { "fit": "con_cuidado", "why": "Lenta para un filo grueso de acero dulce.", "source": SRC_TOROBLADE },
		},
		"source": SRC_TORMEK_T8, "quality": "primary",
	},
}


## Copia de una máquina ({} si no existe).
static func machine(id: String) -> Dictionary:
	var m: Dictionary = MACHINES.get(id, {})
	return m.duplicate(true)


## Copia de una muela de la máquina por su id o por su índice ({} si no existe).
static func wheel(machine_id: String, wheel_ref: Variant = 0) -> Dictionary:
	var m: Dictionary = MACHINES.get(machine_id, {})
	if m.is_empty():
		return {}
	var wheels: Array = m["wheels"]
	if typeof(wheel_ref) == TYPE_INT:
		var i: int = wheel_ref
		return (wheels[i] as Dictionary).duplicate(true) if i >= 0 and i < wheels.size() else {}
	for w in wheels:
		if str(w["id"]) == str(wheel_ref):
			return (w as Dictionary).duplicate(true)
	return {}


## Velocidad de la muela: { speed_ms, rpm, diameter_mm, max_rpm, max_speed_ms, over_speed, declared_ms } con el giro
## y el diámetro de serie o los que se pasen (una muela gastada es más pequeña; una amoladora regulable, más lenta).
## over_speed compara con la velocidad máxima marcada en la muela o el disco (si el fabricante la da).
static func wheel_speed(machine_id: String, wheel_ref: Variant = 0, rpm: float = -1.0, diameter_mm: float = -1.0) -> Dictionary:
	var w := wheel(machine_id, wheel_ref)
	if w.is_empty():
		return {}
	var d: float = diameter_mm if diameter_mm > 0.0 else float(w["diameter_mm"])
	var n: float = rpm if rpm > 0.0 else float(w["rpm"])
	var v := Sharpening.peripheral_speed(d, n)
	var max_rpm: Variant = w.get("max_rpm")
	var max_v: Variant = null
	var over := false
	if max_rpm != null:
		max_v = Sharpening.peripheral_speed(float(w["diameter_mm"]), float(max_rpm))
		over = n > float(max_rpm)
	return {
		"speed_ms": v,
		"rpm": n,
		"diameter_mm": d,
		"max_rpm": max_rpm,
		"max_speed_ms": max_v,
		"over_speed": over,
		"declared_ms": w.get("speed_ms"),
		"source": str(w["source"]),
		"quality": str(w["quality"]),
	}


## Para qué sirve la máquina con una herramienta (cuchillo, broca, fresa, hacha, cortacesped): { fit, why, source }.
## steel_id (opcional) añade si el abrasivo de serie vale para ese material (nunca diamante para acero).
static func suitability(machine_id: String, tool_kind: String, steel_id: String = "") -> Dictionary:
	var m: Dictionary = MACHINES.get(machine_id, {})
	if m.is_empty():
		return { "fit": "no", "why": "Máquina desconocida.", "source": "", "abrasive_ok": false }
	var ft: Dictionary = m["for_tools"]
	var out: Dictionary = (ft.get(tool_kind, { "fit": "no", "why": "Sin datos para esa herramienta.", "source": "" }) as Dictionary).duplicate()
	var ok_wheels: Array = []
	var bad: Array = []
	for w in m["wheels"]:
		var ab := str(w["abrasive_id"])
		if bool(w["honing"]):
			continue
		if steel_id != "" and not abrasive_suits(ab, steel_id):
			bad.append(str(w["id"]))
		else:
			ok_wheels.append(str(w["id"]))
	out["abrasive_ok"] = ok_wheels.size() > 0
	out["wheels_ok"] = ok_wheels
	out["wheels_bad"] = bad
	return out


## Si un abrasivo sirve para amolar ese material: nunca diamante (ni SiC) para acero; el metal duro, con diamante (o
## SiC verde). Un abrasivo desconocido ("") se da por bueno para acero (las muelas sin grano declarado son de
## esmeriladora o piedras de agua).
static func abrasive_suits(abrasive_id: String, steel_id: String) -> bool:
	if Sharpening.TOOL_MATERIALS.has(steel_id):
		return abrasive_id in ["diamante", "sic"]
	return not (abrasive_id in ["diamante", "sic"])


## Máquinas para una herramienta, de la más adecuada a la menos (las «no» al final): [{ id, fit, why }].
static func machines_for(tool_kind: String) -> Array:
	var rows: Array = []
	for id in MACHINES:
		var s := suitability(id, tool_kind)
		rows.append({ "id": id, "fit": s["fit"], "why": s["why"], "rank": FITS.find(str(s["fit"])) })
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["rank"] < b["rank"] if a["rank"] != b["rank"] else str(a["id"]) < str(b["id"]))
	return rows


## `kind` de la vista 3D (CONTRATOS.md → «Vista 3D de la afiladora») para cada `kind` del catálogo. La combinada es
## una de banco con una muela húmeda («piedra») en un extremo del eje.
const VIEW_KIND := {
	"banco": "banco",
	"banco_lenta": "banco",
	"combinada": "banco",
	"lenta_humeda": "humeda_lenta",
	"amoladora": "amoladora",
	"afiladora_brocas": "afilabrocas",
	"afiladora_fresas": "afilafresas",
}


## Diccionario de la escena 3D para `set_machine(view)`: { machine_id, kind, rpm, wheels: [{ id, position, d_mm,
## width_mm, abrasive_id, grit, rpm, wet, honing, selected }], wet, water_trough, quench_pot }. wheel_ref es la muela
## con la que se trabaja (su id o su índice; por defecto, la primera montada): manda en `rpm` y `wet` y, si es un
## recambio, sustituye a la de serie de su misma posición. width_mm puede ser null (el fabricante no lo da) y entonces
## la escena dibuja el suyo. diameter_mm (opcional) es el de la muela gastada. {} si la máquina no existe.
static func view(machine_id: String, wheel_ref: Variant = -1, diameter_mm: float = -1.0) -> Dictionary:
	var m: Dictionary = MACHINES.get(machine_id, {})
	if m.is_empty():
		return {}
	var sel: Dictionary = {}
	if not (typeof(wheel_ref) == TYPE_INT and int(wheel_ref) < 0):
		sel = wheel(machine_id, wheel_ref)
	if sel.is_empty():
		for w in m["wheels"]:
			if bool(w["mounted"]):
				sel = (w as Dictionary).duplicate(true)
				break
	var wheels: Array = []
	for w in m["wheels"]:
		var is_sel := str(w["id"]) == str(sel.get("id", ""))
		if not is_sel and (not bool(w["mounted"]) or str(w["position"]) == str(sel.get("position", ""))):
			continue
		var d: float = float(w["diameter_mm"])
		if is_sel and diameter_mm > 0.0:
			d = diameter_mm
		wheels.append({
			"id": str(w["id"]), "position": str(w["position"]), "d_mm": d, "width_mm": w["width_mm"],
			"abrasive_id": str(w["abrasive_id"]), "grit": str(w["grit"]), "rpm": float(w["rpm"]),
			"wet": bool(w["wet"]), "honing": bool(w["honing"]), "selected": is_sel,
		})
	return {
		"machine_id": machine_id,
		"kind": str(VIEW_KIND.get(str(m["kind"]), "banco")),
		"rpm": float(sel.get("rpm", 0.0)),
		"wheels": wheels,
		"wet": bool(sel.get("wet", false)),
		"water_trough": bool(m["water_trough"]),
		"quench_pot": bool(m["quench_pot"]),
	}
