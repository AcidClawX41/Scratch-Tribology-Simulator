## Taller · la radial (amoladora angular): velocidad del disco, tronzado, el grano como punta y el corte de chapa.
##
## Comparte la física del laboratorio (core/shared, sin copiar sus fórmulas): el grano abrasivo del disco es una
## punta esfero-cónica (Contact.tip_geometry) que raya la pieza con su ratio de dureza (hardness_efficiency), su
## fracción plástica de Hertz (plastic_fraction) y la resolución estática del laboratorio (solve_static); el modo
## de abrasión es el de Hokkirigawa y Kato (Abrasion.abrasion_mode), el mismo que decide si una uña ara o corta; y
## lo que el disco arranca con el empuje del operario sigue la ley de Archard (Abrasion.archard_wear).
##   disc_check()    velocidad periférica y rpm marcadas (del disco o de EN 12413): ¿va por encima de lo permitido?
##   cut_off()       tronzado: caudal, energía específica, potencia, tiempo y avisos.
##   grain_contact() un grano contra la pieza: profundidad, Dp y modo (arado, cuña o corte).
##   cut_panel()     corte de chapa y carrocería, más limpio o más sucio según el disco, las rpm y el ángulo. Su
##                   salida es el contrato de la escena 3D del corte (CONTRATOS.md; ver la función).
##   cut_step()      el mismo corte en el instante presente, con la profundidad a la que entra el disco (modo manual,
##                   core/taller/radial_manual.gd); cut_capacity(): lo que el disco puede arrancar ahora (mm³/s).
## Modelo del corte:
##   1. Energía específica medida en tronzado con disco fino (Awan et al. 2022): SEC = SCE + C_sl·Vc/Q + C_pl·Vc·e²/Q²
##      (J/mm³, con Vc en mm/s, Q en mm³/s y e la anchura del surco en mm). En acero a caudal normal da ~25 J/mm³,
##      el valor típico de Rowe et al. (2003). Embotada o vidriada, la muela pide un 40 % más (Rowe et al.).
##   2. El avance lo limitan la potencia útil de la radial (Bosch) y el empuje del operario: con una fuerza normal F
##      el disco arranca Q = K·F·Vc/H (Archard), así que un acero duro se corta despacio aunque sobre potencia.
##   3. Calor: las virutas (las chispas) se llevan su parte (8,1 J/mm³ en acero, Rowe et al.); del resto, la pieza
##      recibe R_ws (0,9 con corindón y 0,5 con CBN, Rowe et al.). La temperatura de pico a cada lado del corte sale
##      de la fórmula de Adams (1958) para chapa fina.
## Lo que no tiene medición está marcado como ESTIMACIÓN. Fuentes: docs/taller/fuentes-u6.md. Es un simulador
## educativo, no un procedimiento de taller ni de rescate.
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Js = preload("res://core/shared/js.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Panels = preload("res://core/taller/panels.gd")
const Sparks = preload("res://core/taller/sparks.gd")

# ─────────────────────────────── Constantes del modelo ───────────────────────────────
## Energía específica del tronzado con disco de 1 mm (Cubitron, Ø115, 80 m/s): Awan, González Rojas, Perat
## Benavides, Hameed, Hussain y Sánchez Egea (2022), J. Mater. Res. Technol. 18:3302-3310, tabla 1 (dureza Brinell
## de cada material). La figura 4 del artículo se reproduce con Vc ≈ 70.000 mm/s.
const CUT_ENERGY := {
	"ss201": { "name": "inox SS201", "sce": 20.82, "c_sl": 0.0009, "c_pl": 1.5e-3, "hb": 121.0 },
	"al1100": { "name": "aluminio 1100", "sce": 18.59, "c_sl": 0.0016, "c_pl": 7.5e-3, "hb": 32.0 },
	"al7075": { "name": "aluminio 7075", "sce": 17.38, "c_sl": 0.0011, "c_pl": 7.5e-18, "hb": 150.0 },
	"in718": { "name": "Inconel 718", "sce": 22.92, "c_sl": 0.0025, "c_pl": 3.4e-19, "hb": 340.0 },
}
## Acero al carbono (fase 2): tronzado con un disco fino de corindón (41 99A 46 S7 BF, Ø115 × 1 mm, radial Ryobi de
## 600 W) de Awan, González Rojas, Perat Benavides y Hameed (2021, publicado en 2022), «Experimental technique to
## analyze the influence of cutting conditions on specific energy consumption during abrasive metal cutting with thin
## discs», Adv. Manuf. 10:260-271, doi:10.1007/s40436-021-00361-2, tabla 3: SEC = SCE + (Psl + Ppl)/Q (Psl y Ppl en W,
## SCE en J/mm³), con avances de 0,539 a 1,488 mm/s, barras de 3 mm (S235JR) y 10 mm (C45K) y dureza HRB (tabla 2).
## No sustituyen a la fila del SS201 como energía del acero: el S235JR se midió en barras de 3 mm, justo el caso que la
## tesis del autor (Awan 2021, UPC, anexo II.4) señala como el que infla la SCE; y la SCE del C45K es 4,16 J/mm³ en el
## artículo y 12,3 en la tesis (tabla 6). Se usan como banda de incertidumbre de la energía del acero al carbono
## (specific_energy_band_j_mm3), evaluadas al caudal del corte.
const CUT_ENERGY_2021 := {
	"s235jr": { "name": "S235JR", "hrb": 80.05, "psl_w": 29.16, "ppl_w": 163.69, "sce": 37.50, "r2": 0.956, "bar_mm": 3.0 },
	"c45k": { "name": "C45K", "hrb": 100.20, "psl_w": 127.36, "ppl_w": 152.18, "sce": 4.16, "r2": 0.872, "bar_mm": 10.0 },
	"c45k_q": { "name": "C45K templado", "hrb": 120.60, "psl_w": 99.36, "ppl_w": 228.04, "sce": 7.82, "r2": 0.912, "bar_mm": 10.0 },
	"c45k_qt": { "name": "C45K templado y revenido", "hrb": 85.85, "psl_w": 117.36, "ppl_w": 216.21, "sce": 4.93, "r2": 0.923, "bar_mm": 10.0 },
}
const Q_MEASURED_MIN := 3.4  # mm³/s · el menor caudal medido por Awan et al. (2022): por debajo no se extrapola
const KERF_EXTRA_MM := 0.4  # un disco de 1 mm abre 1,3-1,5 mm (Awan et al. 2022, Sensors 22:7152): holgura y vibración
## Holgura medida del surco con disco de 1 mm: de 0,3 a 0,5 mm (Awan et al. 2022, Sensors 22:7152) y 0,8 mm (surco de
## 1,8 mm con avances altos para ese disco, que se dobla y vibra: Awan et al. 2021, Adv. Manuf.). Banda de kerf_mm.
const KERF_EXTRA_MIN_MM := 0.3
const KERF_EXTRA_MAX_MM := 0.8
const LOADING_GAIN := 0.4  # embotada o vidriada: de 25 a 35 J/mm³ (Rowe et al. 2003)
const K_ARCHARD := 0.0125  # coeficiente de desgaste abrasivo del disco (ESTIMACIÓN, abrasión a dos cuerpos; ver fuentes)
const PUSH_N := 30.0  # N · empuje típico del operario sobre la radial (ESTIMACIÓN)
const CERAMIC_K_GAIN := 1.3  # el grano cerámico se autoafila y arranca más con el mismo empuje (ESTIMACIÓN; PFERD)
const T_AMBIENT := 20.0  # °C (estimación)
const T_PAINT_BURN := 250.0  # °C · la pintura se quema (ESTIMACIÓN: por encima de los 140-180 °C de su horneado)
const SMOKE_PAINT_MM := 10.0  # mm · humo de pintura = 1 − e^(−quemada/10 mm) (ESTIMACIÓN; con plástico fundido, +0,6·melt)
## haz_mm: anchura, a cada lado, hasta la que la chapa pasa de 200 °C (contrato de la escena 3D). Es donde empiezan
## los colores de revenido del acero (216 °C, Engineering ToolBox), el sobreenvejecimiento de un 6xxx T6 (~250 °C)
## y, un poco por encima del Vicat (180 °C), el ablandamiento del PPE/PA.
const HAZ_T_C := 200.0
## Chispas visibles por mm³ de metal arrancado, con un chorro de tamaño 1 (ESTIMACIÓN: calibrado para que el corte de
## referencia, disco fino en acero dulce a ~30 mm³/s, dé unas 3.000 por segundo, del orden de la referencia de
## dibujo de core/taller/sparks.gd; no hay recuento publicado de chispas visibles). El tamaño del chorro, su longitud,
## su color y sus estallidos salen de Sparks.stream_for (TC 9-237, tabla 7-5): una sola fuente para el modelo y el
## emisor de la escena.
const SPARKS_PER_MM3 := 100.0
const BURR_UM_PER_MM := 250.0  # µm de rebaba por mm de surco con la pared blanda (ESTIMACIÓN)
## Con el disco inclinado la rebaba media crece × (1 + 1,5·sen θ) y todo lo de más sale del lado de la arista aguda
## (ESTIMACIÓN).
const BURR_TILT_GAIN := 1.5
const ANGLE_WARN_DEG := 1.0  # a partir de aquí el disco trabaja de lado (ESTIMACIÓN)
const LOADING_WARN := 0.4  # embotamiento a partir del que se avisa (ESTIMACIÓN)
const GRAIN_ALPHA_DEG := 60.0  # semiángulo del cono del grano (ESTIMACIÓN: grano poliédrico, ataque de 30°)
const GRAIN_LOAD_SHARE := 0.5  # al rayar, solo el frente del contacto carga (como en physics.js)
const GRAIN_K := 1.0  # un arañazo de una pasada (TYPES "aranazo" del laboratorio)
const GROOVE_MIN_UM := 0.5  # µm · por debajo no hay surco ni modo de abrasión (el umbral de solidResult en physics.js)
## Acero templado (grupo H de ISO 513) cuando no se da su dureza: 60 HRC, el acero templado de referencia de Rowe
## et al. (2003, 60-62 HRC), que son 700 HV por la tabla A.1 de DIN EN ISO 18265:2014. ESTIMACIÓN: cada temple da
## la suya; con `work_hv` se usa la de la pieza.
const HARDENED_HV := 700.0
## Un grano que reacciona con el hierro (el SiC: patente US 4.505.720) dura la mitad en acero (ESTIMACIÓN; el
## diamante tiene su propia relación G, ver _g_ratio).
const IRON_WEAR_G_FACTOR := 0.5

## Parte del calor del contacto (sin lo que se llevan las virutas) que entra en la pieza: Rowe et al. (2003),
## 0,9 con alúmina en acero y 0,5 con CBN. SiC y cerámico como la alúmina, diamante como el CBN: ESTIMACIÓN.
const R_WS := { "al2o3": 0.9, "ceramico": 0.9, "sic": 0.9, "cbn": 0.5, "diamante": 0.5 }

## Radiales de referencia: Bosch GWS 12-125 (125 mm: 1.200 W de entrada, 690 W útiles, 11.000 rpm en vacío) y
## Bosch GWS 22-230 P (230 mm: 2.200 W, 6.500 rpm). La potencia útil de la grande sale con el mismo rendimiento
## (57,5 %): ESTIMACIÓN. Potencias en kW (CONTRATOS.md).
const GRINDERS := [
	{ "name": "Bosch GWS 12-125", "max_diameter_mm": 150.0, "input_kw": 1.2, "power_kw": 0.69, "rpm": 11000.0, "quality": "primary" },
	{ "name": "Bosch GWS 22-230 P", "max_diameter_mm": 230.0, "input_kw": 2.2, "power_kw": 1.265, "rpm": 6500.0, "quality": "estimate" },
]

## Piezas por tipo (`kind` de CONTRATOS.md) para cut_off(): dureza (HV, para el empuje), energía de corte (una fila
## de CUT_ENERGY; "al" = interpolada por dureza entre el 1100 y el 7075; o una SCE fija), tendencia a embotar el
## disco (`loading`, 0-1: ESTIMACIÓN en todos, ningún fabricante la cuantifica) y si es férrica o frágil (en las
## frágiles no se aplica el límite de Archard). Sin datos → energía y dureza del acero, y aviso.
const WORK_KINDS := {
	"acero": { "name": "acero", "hv": 92.0, "energy": "ss201", "sce": -1.0, "thermal": "acero", "ferrous": true, "brittle": false, "loading": 0.0,
		"source": "Coeficientes del inox SS201 de Awan et al. (2022) (ESTIMACIÓN para el acero al carbono): las medidas de acero al carbono de Awan et al. (2021, Adv. Manuf., S235JR y C45K) no son fiables como valor único (ver CUT_ENERGY_2021) y dan la banda de incertidumbre. Dureza del acero dulce del laboratorio (92 HV).", "quality": "estimate" },
	"inox": { "name": "acero inoxidable", "hv": 127.0, "energy": "ss201", "sce": -1.0, "thermal": "acero", "ferrous": true, "brittle": false, "loading": 0.0,
		"source": "Awan et al. (2022): SS201 de 121 HB (≈127 HV por DIN EN ISO 18265).", "quality": "primary" },
	"fundicion": { "name": "fundición", "hv": -1.0, "energy": "", "sce": 20.0, "thermal": "acero", "ferrous": true, "brittle": true, "loading": 0.0,
		"source": "ESTIMACIÓN: SCE del orden de la del acero; viruta que rompe por el grafito.", "quality": "estimate" },
	"aluminio": { "name": "aluminio", "hv": 71.0, "energy": "al", "sce": -1.0, "thermal": "aluminio", "ferrous": false, "brittle": false, "loading": 0.8,
		"source": "Awan et al. (2022): aluminios 1100 (32 HB) y 7075 (150 HB), interpolados por dureza (ESTIMACIÓN) con los 71 HV del AA6016 del laboratorio. Embota un disco normal (PFERD SG ALU); la tendencia a embotar, 0,8, es ESTIMACIÓN.", "quality": "secondary" },
	"niquel": { "name": "aleación de níquel", "hv": 358.0, "energy": "in718", "sce": -1.0, "thermal": "", "ferrous": false, "brittle": false, "loading": 0.0,
		"source": "Awan et al. (2022): Inconel 718 de 340 HB (≈358 HV por DIN EN ISO 18265).", "quality": "primary" },
	"laton": { "name": "latón", "hv": -1.0, "energy": "", "sce": -1.0, "thermal": "", "ferrous": false, "brittle": false, "loading": 0.5,
		"source": "Sin datos de energía específica. Tendencia a embotar 0,5: ESTIMACIÓN (no férrico blando; PFERD vende para él los discos ALU).", "quality": "estimate" },
	"titanio": { "name": "titanio", "hv": -1.0, "energy": "", "sce": -1.0, "thermal": "", "ferrous": false, "brittle": false, "loading": 0.0,
		"source": "Sin datos de energía específica.", "quality": "estimate" },
	"madera": { "name": "madera", "hv": -1.0, "energy": "", "sce": -1.0, "thermal": "", "ferrous": false, "brittle": false, "loading": 0.5,
		"source": "Sin datos: no se modela madera con discos abrasivos. Tendencia a embotar 0,5: ESTIMACIÓN.", "quality": "estimate" },
	"plastico": { "name": "plástico", "hv": 16.0, "energy": "", "sce": 10.0, "thermal": "plastico", "ferrous": false, "brittle": false, "loading": 0.9,
		"source": "ESTIMACIÓN: entre la energía de fundirlo (~0,45 J/mm³) y los ~60 J/mm³ medidos al amolar PA66 con refrigerante a 3 m/s, donde no llega a fundirse (Spina et al. 2021). Empasta el disco: tendencia a embotar 0,9, ESTIMACIÓN.", "quality": "estimate" },
	"piedra": { "name": "piedra", "hv": -1.0, "energy": "", "sce": 20.0, "thermal": "", "ferrous": false, "brittle": true, "loading": 0.0,
		"source": "ESTIMACIÓN: se arranca por microfractura, no por flujo plástico; del orden del acero.", "quality": "estimate" },
	"vidrio": { "name": "vidrio", "hv": -1.0, "energy": "", "sce": 20.0, "thermal": "", "ferrous": false, "brittle": true, "loading": 0.0,
		"source": "ESTIMACIÓN: como la piedra.", "quality": "estimate" },
}

# Citas cortas de los avisos (las completas, en docs/taller/fuentes-u6.md)
const CITE_EN12413 := "EN 12413:2019"
const CITE_EN62841 := "EN 62841-2-3, advertencias de tronzado (manual de la Parkside PWS 115 C3); PFERD WHB 23"
const CITE_DIAMOND := "Brazda (KAPP), Gear Solutions 2006; Komanduri y Shaw 1975"
const CITE_ROWE := "Rowe, Morgan, Batako y Jin 2003, WIT Trans. Eng. Sci. 44"
const CITE_AWAN := "Awan et al. 2022, J. Mater. Res. Technol. 18:3302 y Sensors 22:7152"
const CITE_AWAN_2021 := "Awan et al. 2021, Adv. Manuf. 10:260 (banda del acero al carbono)"
const CITE_TYROLIT := "Tyrolit, disco de CBN 1A1R (fichas de SKS y Hoffmann Group)"
## Por qué un grano no sirve para acero (avisos «<abrasivo>_ferrico»).
const IRON_CITE := { "diamante": CITE_DIAMOND, "sic": "Patente US 4.505.720 (1985), antecedentes" }


# ─────────────────────────────── Velocidad del disco ───────────────────────────────
## Velocidad periférica (m/s) de un disco de diámetro D (mm) a n rpm: v = π·D·n/60000.
static func peripheral_speed(diameter_mm: float, rpm: float) -> float:
	return PI * diameter_mm * rpm / 60000.0


## Radial de referencia para un diámetro de disco.
static func grinder_for(diameter_mm: float) -> Dictionary:
	for g in GRINDERS:
		if diameter_mm <= float(g["max_diameter_mm"]):
			return g
	return GRINDERS[GRINDERS.size() - 1]


## ¿Va el disco demasiado rápido? p = { diameter_mm, rpm, max_speed_ms, nominal_diameter_mm (opcional: el
## diámetro con el que se marcó un disco ya gastado), disc_id (opcional: un disco de Abrasives.DISCS, que aporta
## su velocidad máxima, sus rpm marcadas y su franja) }
## → { speed_ms, max_rpm, marked_rpm, disc_rpm, limit_rpm, over_speed, warning, stripe }.
##   speed_ms: velocidad del borde · max_rpm: n = 60000·v/(π·D) del diámetro nominal · marked_rpm: la tabla de
##   marcado de EN 12413 (null si ese diámetro no está) · disc_rpm: las que el fabricante marca en ese disco (null
##   si no hay disco o no se fabrica en ese diámetro) · limit_rpm: el límite, por este orden: las del disco, las de
##   la tabla o las de la fórmula · over_speed: rpm por encima del límite · stripe: franja de EN 12413 ([] en los
##   discos de otras normas).
static func disc_check(p: Dictionary) -> Dictionary:
	var disc_id := String(p.get("disc_id", ""))
	var disc: Dictionary = Abrasives.DISCS.get(disc_id, {})
	var d := float(p.get("diameter_mm", 125.0))
	var rpm := maxf(float(p.get("rpm", 0.0)), 0.0)
	var vmax := float(p.get("max_speed_ms", disc.get("max_speed_ms", 80.0)))
	var d_nom := float(p.get("nominal_diameter_mm", d))
	var speed := peripheral_speed(d, rpm)
	var max_rpm := Abrasives.formula_rpm(d_nom, vmax)
	# La tabla de marcado es de EN 12413: para un disco de otra norma (diamante y CBN, EN 13236; láminas, EN 13743) sin
	# rpm propias en ese diámetro, manda la fórmula
	var en12413 := disc.is_empty() or String(disc.get("standard", "")) == "EN 12413"
	var marked := Abrasives.marked_rpm(d_nom, vmax) if en12413 else -1.0
	# Las rpm del propio disco solo valen para la velocidad con la que se marcó
	var own := Abrasives.disc_rpm(disc_id, d_nom) if not disc.is_empty() and float(disc["max_speed_ms"]) == vmax else -1.0
	var limit := max_rpm
	var limit_text := "máximas para %s m/s (n = 60.000·v/(π·D))" % _fmt(vmax)
	if own > 0.0:
		limit = own
		limit_text = "marcadas en el disco (%s m/s)" % _fmt(vmax)
	elif marked > 0.0:
		limit = marked
		limit_text = "marcadas para %s m/s (tabla de EN 12413)" % _fmt(vmax)
	var over := rpm > limit
	var warning := ""
	if over:
		warning = "Exceso de velocidad: a %s rpm el disco de %s mm supera las %s rpm %s y su borde va a %s m/s. Por encima de su velocidad un disco puede reventar: las rpm de la radial nunca deben pasar de las marcadas en el disco." % [
			_fmt(rpm), _fmt(d_nom), _fmt(limit), limit_text, _fmt(speed, 1)]
		if d_nom > d:
			warning += " Tampoco se montan en una radial pequeña los discos gastados de una grande: siguen marcados para las rpm de la grande."
	var marked_out: Variant = null
	if marked > 0.0:
		marked_out = marked
	var own_out: Variant = null
	if own > 0.0:
		own_out = own
	return {
		"speed_ms": speed, "max_rpm": max_rpm, "marked_rpm": marked_out, "disc_rpm": own_out, "limit_rpm": limit,
		"over_speed": over, "warning": warning,
		"stripe": Abrasives.disc_stripe(disc_id) if not disc.is_empty() else Abrasives.stripe_for(vmax),
	}


# ─────────────────────────────── Tronzado ───────────────────────────────
## Tronzado de una pieza con la radial. p = { disc_id, diameter_mm, rpm, work_kind, thickness_mm, depth_mm, feed_mm_s,
## y opcionales: length_mm (100), work_hv (dureza de la pieza, HV), work_iso ("H" = templado: 700 HV si no se da
## work_hv), power_kw (potencia útil de la radial), push_n (empuje) y angle_deg }.
##   thickness_mm: espesor de la pieza que hay que atravesar · depth_mm: profundidad de cada pasada (por defecto,
##   todo el espesor) · feed_mm_s: avance a lo largo del corte (0 → el máximo que permiten la radial y el empuje).
## → { vs, q_mm3_s, specific_energy_j_mm3, power_kw, time_s, warnings, feed_mm_s, passes, limited_by, over_speed,
##   kerf_mm (en perpendicular al disco), kerf_surface_mm (en la cara de la pieza), work_hv, kerf_band_mm,
##   specific_energy_band_j_mm3, … }
static func cut_off(p: Dictionary) -> Dictionary:
	var disc_id := String(p.get("disc_id", "fino_1mm"))
	var disc: Dictionary = Abrasives.DISCS.get(disc_id, {})
	var d := float(p.get("diameter_mm", 125.0))
	var rpm := float(p.get("rpm", float(grinder_for(d)["rpm"])))
	var thickness := maxf(float(p.get("thickness_mm", 3.0)), 0.0)
	var depth := float(p.get("depth_mm", thickness))
	if depth <= 0.0 or depth > thickness:
		depth = thickness
	var length := maxf(float(p.get("length_mm", 100.0)), 0.0)
	var kind := String(p.get("work_kind", "acero"))
	var work := _work_from_kind(kind, String(p.get("work_iso", "")), float(p.get("work_hv", -1.0)))
	var warnings: Array = []
	if work["no_data"]:
		_warn(warnings, "sin_datos", "No hay energía específica publicada para %s: se calcula con la del acero." % String(work["name"]), "")
	var eng := _engine(disc, d, rpm, work, depth, float(p.get("feed_mm_s", 5.0)), float(p.get("angle_deg", 0.0)),
		float(p.get("power_kw", -1.0)), float(p.get("push_n", PUSH_N)), warnings)
	var passes := 1 if depth >= thickness else int(ceil(thickness / depth - 1e-9))
	var feed: float = eng["feed_mm_s"]
	var time_s: float = passes * length / feed if feed > 0.0 else INF
	return {
		"vs": eng["vs_ms"], "q_mm3_s": eng["q_mm3_s"], "specific_energy_j_mm3": eng["specific_energy_j_mm3"],
		"power_kw": eng["power_kw"], "time_s": time_s, "warnings": warnings,
		"feed_mm_s": feed, "passes": passes, "limited_by": eng["limited_by"], "over_speed": eng["over_speed"],
		"kerf_mm": eng["kerf_mm"], "kerf_surface_mm": eng["kerf_surface_mm"], "disc_id": disc_id, "work_kind": kind,
		"work_hv": work["hv"], "quality": "estimate",
		"kerf_band_mm": eng["kerf_band_mm"], "specific_energy_band_j_mm3": eng["specific_energy_band_j_mm3"],
	}


# ─────────────────────────────── El grano como punta ───────────────────────────────
## Un grano abrasivo del disco contra la pieza, con la misma cuenta que una uña del laboratorio (un arañazo de una
## pasada): punta esfero-cónica de radio d/2 (el grano como una esfera de su tamaño medio, como las puntas
## semiesféricas de Hokkirigawa y Kato) y cono de 60° (ESTIMACIÓN).
## p = { grit_microns, abrasive_id, work_hv, work_e_gpa, load_n, work_mu (opcional, 0,5 como el acero del lab) }
## → { depth_um, a_um, Dp, absMode, fab, phi, muPlough, eta, ratio, tip_radius_um }. Sin surco (grano más blando o
## menos de 0,5 µm de hondo, como en el laboratorio): absMode null, fab 0 y muPlough 0.
static func grain_contact(p: Dictionary) -> Dictionary:
	var d_um := float(p.get("grit_microns", 260.0))
	var ab: Dictionary = Abrasives.ABRASIVES.get(String(p.get("abrasive_id", "al2o3")), {})
	var work_hv := float(p.get("work_hv", 200.0))
	var work_e := float(p.get("work_e_gpa", 210.0))
	var load := float(p.get("load_n", 1.0))
	var mu := float(p.get("work_mu", 0.5))
	var out := { "depth_um": 0.0, "a_um": 0.0, "Dp": 0.0, "absMode": null, "fab": 0.0, "phi": 0.0, "muPlough": 0.0,
		"eta": 0.0, "ratio": 0.0, "tip_radius_um": d_um / 2.0 }
	if ab.is_empty() or d_um <= 0.0 or work_hv <= 0.0:
		return out
	var r_mm := d_um / 2000.0
	var tip := Contact.tip_geometry(PI * r_mm * r_mm, GRAIN_ALPHA_DEG)
	var h_work := work_hv * Contact.HV_MPA
	var ratio := float(ab["hv"]) / work_hv
	var eta := Contact.hardness_efficiency(ratio)
	var f_mu := sqrt(1.0 + 3.0 * mu * mu)  # von Mises con cizalla de Coulomb, como en el laboratorio
	var pf := Contact.plastic_fraction(load, tip["R"], float(ab["e_gpa"]), work_e, h_work, f_mu)
	var phi: float = pf["phi"]
	var m := phi * GRAIN_K
	out["eta"] = eta
	out["ratio"] = ratio
	out["phi"] = phi
	if m <= 1e-9 or eta <= 0.0 or load <= 0.0:
		return out
	var res := func(h: float) -> float:
		var a := Contact.contact_radius(tip, h / m)
		if a <= 0.0:
			return 0.0
		return (h_work / eta) * GRAIN_LOAD_SHARE * PI * a * a
	var h_mm := Contact.solve_static(load, res)
	var a_mm := Contact.contact_radius(tip, h_mm / m)
	var depth_um := h_mm * 1000.0
	var a_um := a_mm * 1000.0
	var dp := depth_um / a_um if a_um > 0.0 else 0.0
	out["depth_um"] = depth_um
	out["a_um"] = a_um
	out["Dp"] = dp
	if depth_um > GROOVE_MIN_UM:
		var mode := Abrasion.abrasion_mode(dp)
		out["absMode"] = mode["absMode"]
		out["fab"] = mode["fab"]
		out["muPlough"] = mode["muPlough"]
	return out


# ─────────────────────────────── Corte de chapa y carrocería ───────────────────────────────
## Corte de un panel de carrocería (Panels.PANELS) con la radial. Contrato de la escena 3D del corte (CONTRATOS.md).
## p = { disc_id ("fino_1mm" | "grueso_3mm" | "diamante" | "laminas" u otro de Abrasives.DISCS), diameter_mm, rpm,
## angle_deg (0 = disco perpendicular a la chapa; inclinación lateral), feed_mm_s (0 → el máximo que permiten la
## radial y el empuje), panel_id, cut_length_mm, y opcionales power_kw y push_n }
## → {
##   vs_ms, over_speed, time_s: velocidad del borde (m/s), si pasa de las rpm marcadas y tiempo del corte (s; INF si
##     no corta);
##   kerf_mm: anchura del surco medida en perpendicular al disco (en la chapa, kerf_mm / cos θ = kerf_surface_mm);
##   burr_um: altura media de la rebaba en la cara de salida (en plástico, hilos) · haz_mm: anchura, a cada lado,
##     hasta la que la chapa pasó de 200 °C;
##   heat_tint: { temp_c: pico en el borde del surco, color: hex, name, width_mm: banda con color de revenido a cada
##     lado, bands: [ { from_mm, to_mm, color, name } ] } · paint_burn_mm: pintura quemada a cada lado;
##   sparks: { rate: chispas visibles por segundo, color, color_name, color_end, color_end_name, length_mm: longitud
##     del chorro con la vs del corte, bursts: estallidos medios por chispa, bursts_name, class: familia del ensayo de
##     chispas } (todo menos rate, de Sparks.stream_for: una sola fuente con el emisor);
##   disc_wear_mm3: disco gastado · disc_loading: embotamiento 0-1 · deformation: deformación térmica junto al corte
##     (mm) · cleanliness: 0 limpio … 10 sucio · warnings: [ { code, message, source } ] · quality: "estimate" ·
##     sources: [citas cortas];
##   campos propuestos por la escena: smoke (0-1), melt (0-1, plástico fundido en hilos), burr_sides_um:
##     { lado_menos, lado_mas } (con θ > 0, la arista aguda y la rebaba mayor quedan en el lado −) y front_temp_c
##     (temperatura del frente del corte);
##   y además: kerf_surface_mm, burr_side ("ambos" | "un_lado"), smoke_from, panel_id, disc_id, angle_deg, feed_mm_s,
##     limited_by, power_kw, q_mm3_s, specific_energy_j_mm3, heat_j_mm, glazing;
##   fase 2: kerf_band_mm [mín, máx] (holgura medida del surco, en perpendicular al disco) y
##     specific_energy_band_j_mm3 [mín, máx] (en acero, con las medidas de acero al carbono de Awan et al. 2021) }
static func cut_panel(p: Dictionary) -> Dictionary:
	var disc_id := String(p.get("disc_id", "fino_1mm"))
	var disc: Dictionary = Abrasives.DISCS.get(disc_id, {})
	var panel_id := String(p.get("panel_id", "acero-dulce"))
	var panel := Panels.get_panel(panel_id)
	var d := float(p.get("diameter_mm", 125.0))
	var rpm := float(p.get("rpm", float(grinder_for(d)["rpm"])))
	var angle := float(p.get("angle_deg", 0.0))
	var length := maxf(float(p.get("cut_length_mm", 100.0)), 0.0)
	var warnings: Array = []
	var out := _empty_panel_result(panel_id, disc_id, angle, warnings)
	if panel.is_empty() or disc.is_empty():
		_warn(warnings, "sin_datos", "No existe el panel «%s» o el disco «%s»." % [panel_id, disc_id], "")
		return out
	var th: Dictionary = Panels.THERMAL[panel["thermal"]]
	var kind_data: Dictionary = WORK_KINDS[panel["kind"]]
	var work := {
		"kind": panel["kind"], "name": kind_data["name"], "hv": float(panel["hv"]), "energy": kind_data["energy"],
		"sce": kind_data["sce"], "thermal": panel["thermal"], "ferrous": kind_data["ferrous"], "brittle": false,
		"loading": kind_data["loading"], "no_data": false, "iso": "",
	}
	var t_total := Panels.total_thickness_mm(panel)
	var eng := _engine(disc, d, rpm, work, t_total, float(p.get("feed_mm_s", 0.0)), angle, float(p.get("power_kw", -1.0)),
		float(p.get("push_n", PUSH_N)), warnings)
	var q: float = eng["q_mm3_s"]
	var cutting := q > 0.0
	var kerf: float = eng["kerf_mm"]
	var kerf_s: float = eng["kerf_surface_mm"]
	var feed: float = eng["feed_mm_s"]
	var e_eff: float = eng["specific_energy_j_mm3"]
	var vs: float = eng["vs_ms"]

	# Calor por milímetro de corte que entra en la chapa y temperaturas de pico (Adams 1958, chapa fina). Sin corte
	# no hay calor: ni zona afectada, ni colores, ni pintura quemada.
	var t_mm: float = panel["t_mm"]
	var rho_c: float = float(th["rho"]) * 1e-9 * float(th["c"])  # J/(mm³·K)
	var t_edge: float = th["t_edge_c"]
	var rws: float = R_WS.get(String(disc["abrasive"]), 0.9)
	var heat_j_mm := rws * maxf(e_eff - float(th["chip_j_mm3"]), 0.0) * kerf_s * t_total if cutting else 0.0
	var haz := _adams_width(heat_j_mm, rho_c, t_mm, HAZ_T_C, t_edge)
	var soft_w := _adams_width(heat_j_mm, rho_c, t_mm, float(th["t_soft_c"]), t_edge)
	var tint := _heat_tint(panel, heat_j_mm, rho_c, t_mm, t_edge)
	var paint_burn := _adams_width(heat_j_mm, rho_c, t_mm, T_PAINT_BURN, t_edge) if float(panel["paint_um"]) > 0.0 else 0.0

	# Rebaba (ESTIMACIÓN): crece con el surco y con la pared ablandada por el calor; la inclinación la sube y lo de
	# más sale del lado de la arista aguda. burr_um es la media de los dos lados.
	var sin_a := absf(sin(deg_to_rad(clampf(angle, -60.0, 60.0))))
	var burr_base := 0.0
	if cutting:
		var soft := soft_w / (soft_w + t_mm) if soft_w > 0.0 else 0.0
		burr_base = minf(BURR_UM_PER_MM * kerf * float(panel["burr_factor"]) * (0.1 + 0.9 * soft), 1000.0 * t_mm)
	var burr_acute := minf(burr_base * (1.0 + 2.0 * BURR_TILT_GAIN * sin_a), 1000.0 * t_mm)
	var burr := 0.5 * (burr_base + burr_acute)

	# Chispas: tamaño del chorro, longitud a esta vs, color y estallidos, de una sola fuente (Sparks.stream_for, el
	# ensayo de chispas del TC 9-237); cuántas por segundo, según el caudal
	var st := Sparks.stream_for(panel_id, vs)
	var rate := SPARKS_PER_MM3 * float(st["volume"]) * q
	var sparks: Dictionary = out["sparks"]
	sparks["color"] = st["color"]
	sparks["color_name"] = st["color_name"]
	sparks["color_end"] = st["color_end"]
	sparks["color_end_name"] = st["color_end_name"]
	sparks["class"] = st["family"]
	if rate > 0.0:
		sparks["rate"] = rate
		sparks["length_mm"] = st["length_mm"]
		sparks["bursts"] = st["bursts"]
		sparks["bursts_name"] = st["bursts_name"]

	# Desgaste y embotamiento del disco (solo si arranca material)
	var wear := kerf_s * t_total * length / _g_ratio(String(disc["abrasive"]), work) if cutting else 0.0
	var loading: float = eng["loading"] if cutting else 0.0
	var glazing: bool = eng["glazing"] and cutting

	# Deformación (mm): dilatación transversal que da el calor del corte, α·H/(ρ·c·t) (por conservación de la
	# energía, ∫ρ·c·t·ΔT dy = H): la escala del alabeo, no una medida del pandeo (ESTIMACIÓN). Plástico fundido:
	# la parte del espesor que pasa del Vicat (ESTIMACIÓN).
	var plastic: bool = panel["kind"] == "plastico"
	var deformation := float(th["alpha_k"]) * heat_j_mm / (rho_c * t_mm) if heat_j_mm > 0.0 else 0.0
	var melt := clampf(soft_w / (2.0 * t_mm), 0.0, 1.0) if plastic and cutting else 0.0

	# Humo y limpieza del corte (ESTIMACIÓN: escalas y pesos elegidos para ordenar los casos, no medidos)
	var smoke_from: Array = []
	var smoke := 0.0
	if paint_burn > 0.0:
		smoke += 1.0 - exp(-paint_burn / SMOKE_PAINT_MM)
		smoke_from.append("pintura")
	if melt > 0.0:
		smoke += 0.6 * melt
		smoke_from.append("plástico")
	var tint_w: float = tint["width_mm"]
	var heat_w := tint_w if String(panel["tint"]) != "" else haz  # anchura con el calor a la vista
	var burr_n := clampf(burr / (500.0 * t_mm), 0.0, 1.0)
	var heat_n := clampf(heat_w / 10.0, 0.0, 1.0)
	var angle_n := clampf(sin_a / sin(deg_to_rad(20.0)), 0.0, 1.0) if cutting else 0.0
	var dirt := 0.3 * burr_n + 0.2 * heat_n + 0.25 * loading + 0.1 * angle_n + (0.1 if glazing else 0.0) + 0.2 * melt
	var cleanliness := 10.0 * clampf(dirt, 0.0, 1.0)

	# Avisos propios del panel
	if melt > 0.0:
		_warn(warnings, "plastico_fundido", "El termoplástico se funde: se ablanda a 180 °C (Vicat) y se inyecta a 295-315 °C. El disco lo arrastra en hilos, humea y no salta ninguna chispa.", "SABIC, NORYL GTX964W")
	if paint_burn > 0.0:
		_warn(warnings, "pintura_humo", "La pintura se quema y humea a ambos lados del corte (unos %s mm por lado): pasa de ~250 °C, muy por encima de los 140-180 °C a los que se hornea." % _fmt(paint_burn, 1), "estimación (docs/taller/fuentes-u6.md)")
	if bool(panel.get("press_hardened", false)):
		_warn(warnings, "pilar_boro", "%s: acero estampado en caliente (Rm ≈ %s MPa, ~%s HV). El disco avanza despacio, se calienta y se gasta mucho. La norma de herramientas de rescate NFPA 1936 añadió en 2020 una prueba opcional de corte de estos pilares de alta resistencia." % [
			String(panel["name"]), _fmt(float(panel["rm_mpa"])), _fmt(float(panel["hv"]))], String(panel["cite"]) + "; DHS SAVER TechNote 2022")
	_rescue_warnings(warnings)

	var minus_acute := angle > 0.0
	out["vs_ms"] = vs
	out["over_speed"] = eng["over_speed"]
	out["time_s"] = length / feed if feed > 0.0 else INF
	out["kerf_mm"] = kerf
	out["burr_um"] = burr
	out["haz_mm"] = haz
	out["heat_tint"] = tint
	out["paint_burn_mm"] = paint_burn
	out["disc_wear_mm3"] = wear
	out["disc_loading"] = loading
	out["deformation"] = deformation
	out["cleanliness"] = cleanliness
	out["sources"] = [CITE_AWAN, CITE_ROWE, "Archard 1953", "Adams 1958 (temperatura de pico en chapa fina)", "PFERD WHB 23",
		"Bosch (potencia de la radial)", String(panel["cite"]), String(th["cite"]), String(st["cite"])]
	out["smoke"] = clampf(smoke, 0.0, 1.0)
	out["melt"] = melt
	out["burr_sides_um"] = { "lado_menos": burr_acute if minus_acute else burr_base, "lado_mas": burr_base if minus_acute else burr_acute }
	out["front_temp_c"] = t_edge if cutting else T_AMBIENT
	out["kerf_surface_mm"] = kerf_s
	out["burr_side"] = "un_lado" if cutting and absf(angle) >= ANGLE_WARN_DEG else "ambos"
	out["smoke_from"] = smoke_from
	out["feed_mm_s"] = feed
	out["limited_by"] = eng["limited_by"]
	out["power_kw"] = eng["power_kw"]
	out["q_mm3_s"] = q
	out["specific_energy_j_mm3"] = e_eff
	out["heat_j_mm"] = heat_j_mm
	out["glazing"] = glazing
	out["kerf_band_mm"] = eng["kerf_band_mm"]
	out["specific_energy_band_j_mm3"] = eng["specific_energy_band_j_mm3"]
	if panel["kind"] == "acero":
		(out["sources"] as Array).append(CITE_AWAN_2021)
	return out


# ─────────────────────────────── Corte en directo (modo manual) ───────────────────────────────
## Corte de chapa en directo, para el modo manual de la radial (core/taller/radial_manual.gd): el mismo modelo que
## cut_panel en el instante presente, con las rpm reales de ese momento y la profundidad a la que entra el disco, sin
## longitud de corte. A profundidad completa da lo mismo que cut_panel con el mismo avance (lo comprueba
## tests/taller/test_radial_manual.gd); con menos es un surco que aún no atraviesa la chapa: no deja rebaba en la cara
## de salida y el calor por mm de corte es proporcional a la profundidad (H = R_ws·(SEC − e_viruta)·surco·profundidad).
## p = { disc_id, diameter_mm, rpm, angle_deg, panel_id, depth_mm (de 0 al espesor total con la pintura; por defecto,
##   todo), feed_mm_s (avance pedido a lo largo del corte, > 0: con 0 no corta, no es el «máximo» de cut_panel), y
##   opcionales power_kw (potencia útil en ese momento) y push_n (empuje) }
## → las claves de cut_panel que no dependen de la longitud del corte (todas menos time_s, disc_wear_mm3 y sources) y
##   además depth_mm, through (atraviesa la chapa), cutting (arranca material) y wear_mm3_per_mm3 (mm³ de disco que se
##   gastan por mm³ de chapa arrancada: 1/G).
static func cut_step(p: Dictionary) -> Dictionary:
	var disc_id := String(p.get("disc_id", "fino_1mm"))
	var panel_id := String(p.get("panel_id", "acero-dulce"))
	var angle := float(p.get("angle_deg", 0.0))
	var warnings: Array = []
	var out := _empty_step_result(panel_id, disc_id, angle, warnings)
	var s := _step_setup(p)
	if s.is_empty():
		_warn(warnings, "sin_datos", "No existe el panel «%s» o el disco «%s»." % [panel_id, disc_id], "")
		return out
	var disc: Dictionary = s["disc"]
	var panel: Dictionary = s["panel"]
	var work: Dictionary = s["work"]
	var t_total: float = s["t_total"]
	var depth: float = s["depth"]
	var feed_req := maxf(float(p.get("feed_mm_s", 0.0)), 0.0)
	out["depth_mm"] = depth
	if feed_req <= 0.0 or depth <= 0.0:
		return out
	var th: Dictionary = Panels.THERMAL[panel["thermal"]]
	var eng := _engine(disc, s["d"], s["rpm"], work, depth, feed_req, angle, s["power_kw"], s["push_n"], warnings)
	var q: float = eng["q_mm3_s"]
	var cutting := q > 0.0
	var through := depth >= t_total - 1e-9
	var kerf: float = eng["kerf_mm"]
	var kerf_s: float = eng["kerf_surface_mm"]
	var e_eff: float = eng["specific_energy_j_mm3"]
	var vs: float = eng["vs_ms"]

	# Calor por mm de lo que arranca el disco (Adams 1958, chapa fina): el de cut_panel con la profundidad del surco
	var t_mm: float = panel["t_mm"]
	var rho_c: float = float(th["rho"]) * 1e-9 * float(th["c"])
	var t_edge: float = th["t_edge_c"]
	var rws: float = R_WS.get(String(disc["abrasive"]), 0.9)
	var heat_j_mm := rws * maxf(e_eff - float(th["chip_j_mm3"]), 0.0) * kerf_s * depth if cutting else 0.0
	var haz := _adams_width(heat_j_mm, rho_c, t_mm, HAZ_T_C, t_edge)
	var soft_w := _adams_width(heat_j_mm, rho_c, t_mm, float(th["t_soft_c"]), t_edge)
	var tint := _heat_tint(panel, heat_j_mm, rho_c, t_mm, t_edge)
	var paint_burn := _adams_width(heat_j_mm, rho_c, t_mm, T_PAINT_BURN, t_edge) if float(panel["paint_um"]) > 0.0 else 0.0

	# Rebaba (ESTIMACIÓN, la de cut_panel): solo sale por la cara de salida cuando el disco atraviesa la chapa
	var sin_a := absf(sin(deg_to_rad(clampf(angle, -60.0, 60.0))))
	var burr_base := 0.0
	if cutting and through:
		var soft := soft_w / (soft_w + t_mm) if soft_w > 0.0 else 0.0
		burr_base = minf(BURR_UM_PER_MM * kerf * float(panel["burr_factor"]) * (0.1 + 0.9 * soft), 1000.0 * t_mm)
	var burr_acute := minf(burr_base * (1.0 + 2.0 * BURR_TILT_GAIN * sin_a), 1000.0 * t_mm)
	var burr := 0.5 * (burr_base + burr_acute)

	# Chispas (Sparks.stream_for, la fuente única) y cuántas por segundo según el caudal
	var st := Sparks.stream_for(panel_id, vs)
	var rate := SPARKS_PER_MM3 * float(st["volume"]) * q
	var sparks: Dictionary = out["sparks"]
	sparks["color"] = st["color"]
	sparks["color_name"] = st["color_name"]
	sparks["color_end"] = st["color_end"]
	sparks["color_end_name"] = st["color_end_name"]
	sparks["class"] = st["family"]
	if rate > 0.0:
		sparks["rate"] = rate
		sparks["length_mm"] = st["length_mm"]
		sparks["bursts"] = st["bursts"]
		sparks["bursts_name"] = st["bursts_name"]

	var loading: float = eng["loading"] if cutting else 0.0
	var glazing: bool = eng["glazing"] and cutting
	var plastic: bool = panel["kind"] == "plastico"
	var deformation := float(th["alpha_k"]) * heat_j_mm / (rho_c * t_mm) if heat_j_mm > 0.0 else 0.0
	var melt := clampf(soft_w / (2.0 * t_mm), 0.0, 1.0) if plastic and cutting else 0.0

	# Humo y limpieza (ESTIMACIÓN): las mismas escalas y pesos que cut_panel
	var smoke_from: Array = []
	var smoke := 0.0
	if paint_burn > 0.0:
		smoke += 1.0 - exp(-paint_burn / SMOKE_PAINT_MM)
		smoke_from.append("pintura")
	if melt > 0.0:
		smoke += 0.6 * melt
		smoke_from.append("plástico")
	var tint_w: float = tint["width_mm"]
	var heat_w := tint_w if String(panel["tint"]) != "" else haz
	var burr_n := clampf(burr / (500.0 * t_mm), 0.0, 1.0)
	var heat_n := clampf(heat_w / 10.0, 0.0, 1.0)
	var angle_n := clampf(sin_a / sin(deg_to_rad(20.0)), 0.0, 1.0) if cutting else 0.0
	var dirt := 0.3 * burr_n + 0.2 * heat_n + 0.25 * loading + 0.1 * angle_n + (0.1 if glazing else 0.0) + 0.2 * melt

	if melt > 0.0:
		_warn(warnings, "plastico_fundido", "El termoplástico se funde: se ablanda a 180 °C (Vicat) y se inyecta a 295-315 °C. El disco lo arrastra en hilos, humea y no salta ninguna chispa.", "SABIC, NORYL GTX964W")
	if paint_burn > 0.0:
		_warn(warnings, "pintura_humo", "La pintura se quema y humea a ambos lados del corte (unos %s mm por lado): pasa de ~250 °C, muy por encima de los 140-180 °C a los que se hornea." % _fmt(paint_burn, 1), "estimación (docs/taller/fuentes-u6.md)")
	if cutting and bool(panel.get("press_hardened", false)):
		_warn(warnings, "pilar_boro", "%s: acero estampado en caliente (Rm ≈ %s MPa, ~%s HV). El disco avanza despacio, se calienta y se gasta mucho. La norma de herramientas de rescate NFPA 1936 añadió en 2020 una prueba opcional de corte de estos pilares de alta resistencia." % [
			String(panel["name"]), _fmt(float(panel["rm_mpa"])), _fmt(float(panel["hv"]))], String(panel["cite"]) + "; DHS SAVER TechNote 2022")

	var minus_acute := angle > 0.0
	out["vs_ms"] = vs
	out["over_speed"] = eng["over_speed"]
	out["kerf_mm"] = kerf
	out["burr_um"] = burr
	out["haz_mm"] = haz
	out["heat_tint"] = tint
	out["paint_burn_mm"] = paint_burn
	out["disc_loading"] = loading
	out["deformation"] = deformation
	out["cleanliness"] = 10.0 * clampf(dirt, 0.0, 1.0)
	out["smoke"] = clampf(smoke, 0.0, 1.0)
	out["melt"] = melt
	out["burr_sides_um"] = { "lado_menos": burr_acute if minus_acute else burr_base, "lado_mas": burr_base if minus_acute else burr_acute }
	out["front_temp_c"] = t_edge if cutting else T_AMBIENT
	out["kerf_surface_mm"] = kerf_s
	out["burr_side"] = "un_lado" if cutting and through and absf(angle) >= ANGLE_WARN_DEG else "ambos"
	out["smoke_from"] = smoke_from
	out["feed_mm_s"] = eng["feed_mm_s"]
	out["limited_by"] = eng["limited_by"]
	out["power_kw"] = eng["power_kw"]
	out["q_mm3_s"] = q
	out["specific_energy_j_mm3"] = e_eff
	out["heat_j_mm"] = heat_j_mm
	out["glazing"] = glazing
	out["kerf_band_mm"] = eng["kerf_band_mm"]
	out["specific_energy_band_j_mm3"] = eng["specific_energy_band_j_mm3"]
	out["through"] = through and cutting
	out["cutting"] = cutting
	out["wear_mm3_per_mm3"] = 1.0 / _g_ratio(String(disc["abrasive"]), work) if cutting else 0.0
	return out


## Lo que el disco puede arrancar ahora mismo con esa potencia y ese empuje, sea cual sea el avance: el menor de los
## límites de _engine (la potencia útil, resolviendo SEC(Q)·Q = P, y el empuje por Archard). No depende de la
## profundidad. Mismas claves de entrada que cut_step (sin depth_mm ni feed_mm_s).
## → { q_cap_mm3_s, limited_by ("potencia" | "empuje"; "" si no corta), kerf_mm, kerf_surface_mm, vs_ms, over_speed,
##   warnings (los del disco con esas rpm y ese ángulo: exceso de velocidad, disco fijo, inadecuado, embotamiento,
##   acuñamiento, sin corte…), y los dos límites por separado: q_power_mm3_s (el de la potencia), q_push_mm3_s (el del
##   empuje, proporcional a push_n; INF si la pieza es frágil) y push_power_kw (la potencia que pediría arrancar
##   q_push_mm3_s, con la misma energía específica; 0 si no hay empuje) }
static func cut_capacity(p: Dictionary) -> Dictionary:
	var warnings: Array = []
	var out := { "q_cap_mm3_s": 0.0, "limited_by": "", "kerf_mm": 0.0, "kerf_surface_mm": 0.0, "vs_ms": 0.0,
		"over_speed": false, "warnings": warnings, "q_power_mm3_s": 0.0, "q_push_mm3_s": 0.0, "push_power_kw": 0.0 }
	var s := _step_setup(p)
	if s.is_empty():
		return out
	var eng := _engine(s["disc"], s["d"], s["rpm"], s["work"], s["t_total"], 0.0, float(p.get("angle_deg", 0.0)),
		s["power_kw"], s["push_n"], warnings)
	out["q_cap_mm3_s"] = eng["q_mm3_s"]
	out["limited_by"] = eng["limited_by"]
	out["kerf_mm"] = eng["kerf_mm"]
	out["kerf_surface_mm"] = eng["kerf_surface_mm"]
	out["vs_ms"] = eng["vs_ms"]
	out["over_speed"] = eng["over_speed"]
	out["q_power_mm3_s"] = eng["q_power_mm3_s"]
	out["q_push_mm3_s"] = eng["q_push_mm3_s"]
	out["push_power_kw"] = eng["push_power_kw"]
	return out


## Disco, panel, pieza, espesor y profundidad de un paso en directo (cut_step y cut_capacity); {} si falta el panel o
## el disco. La pieza es la misma que arma cut_panel.
static func _step_setup(p: Dictionary) -> Dictionary:
	var disc: Dictionary = Abrasives.DISCS.get(String(p.get("disc_id", "fino_1mm")), {})
	var panel := Panels.get_panel(String(p.get("panel_id", "acero-dulce")))
	if panel.is_empty() or disc.is_empty():
		return {}
	var kind_data: Dictionary = WORK_KINDS[panel["kind"]]
	var work := {
		"kind": panel["kind"], "name": kind_data["name"], "hv": float(panel["hv"]), "energy": kind_data["energy"],
		"sce": kind_data["sce"], "thermal": panel["thermal"], "ferrous": kind_data["ferrous"], "brittle": false,
		"loading": kind_data["loading"], "no_data": false, "iso": "",
	}
	var d := float(p.get("diameter_mm", 125.0))
	var t_total := Panels.total_thickness_mm(panel)
	return {
		"disc": disc, "panel": panel, "work": work, "t_total": t_total, "d": d,
		"depth": clampf(float(p.get("depth_mm", t_total)), 0.0, t_total),
		"rpm": maxf(float(p.get("rpm", float(grinder_for(d)["rpm"]))), 0.0),
		"power_kw": float(p.get("power_kw", -1.0)), "push_n": float(p.get("push_n", PUSH_N)),
	}


## Salida de cut_step sin corte: la de cut_panel sin corte, sin lo que depende de la longitud, y con los campos del paso.
static func _empty_step_result(panel_id: String, disc_id: String, angle: float, warnings: Array) -> Dictionary:
	var out := _empty_panel_result(panel_id, disc_id, angle, warnings)
	for k in ["time_s", "disc_wear_mm3", "sources"]:
		out.erase(k)
	out["depth_mm"] = 0.0
	out["through"] = false
	out["cutting"] = false
	out["wear_mm3_per_mm3"] = 0.0
	return out


# ─────────────────────────────── Motor común ───────────────────────────────
## Lo común al tronzado y al corte de chapa: velocidad, surco, energía específica (con embotamiento y vidriado),
## avance limitado por la potencia y por el empuje, caudal y avisos del disco.
static func _engine(disc: Dictionary, d: float, rpm: float, work: Dictionary, depth: float, feed_req: float, angle: float,
		power_kw: float, push_n: float, warnings: Array) -> Dictionary:
	var out := { "vs_ms": 0.0, "over_speed": false, "kerf_mm": 0.0, "kerf_surface_mm": 0.0, "specific_energy_j_mm3": 0.0,
		"feed_mm_s": 0.0, "q_mm3_s": 0.0, "power_kw": 0.0, "limited_by": "", "loading": 0.0, "glazing": false,
		"kerf_band_mm": [0.0, 0.0], "specific_energy_band_j_mm3": [0.0, 0.0],
		"q_power_mm3_s": 0.0, "q_push_mm3_s": 0.0, "push_power_kw": 0.0 }
	if disc.is_empty():
		_warn(warnings, "sin_datos", "No existe ese disco.", "")
		return out
	var chk := disc_check({ "diameter_mm": d, "rpm": rpm, "disc_id": String(disc["id"]) })
	var vs: float = chk["speed_ms"]
	out["vs_ms"] = vs
	out["over_speed"] = chk["over_speed"]
	if chk["over_speed"]:
		_warn(warnings, "exceso_velocidad", chk["warning"], CITE_EN12413 + "; " + CITE_EN62841)
	if bool(disc.get("stationary_only", false)):
		var msg := "«%s» es para tronzadoras fijas y para cortar en húmedo, a %s m/s como mucho: no se monta en una radial." % [
			String(disc["name"]), _fmt(float(disc["max_speed_ms"]))]
		var bore := float(disc.get("bore_mm", 22.23))
		if bore < 22.23:
			msg += " Su agujero de %s mm ni siquiera entra en la brida de 22,23 mm de la radial." % _fmt(bore, 0 if bore == floorf(bore) else 2)
		_warn(warnings, "disco_fijo", msg, CITE_TYROLIT + "; " + CITE_EN62841)
	var kind := String(work["kind"])
	var material := String(work["name"])
	var abrasive := String(disc["abrasive"])
	var ab: Dictionary = Abrasives.ABRASIVES[abrasive]
	if not disc["cuts"]:
		_warn(warnings, "disco_no_corta", "«%s» es un disco de %s: no es para tronzar. Cada disco, solo para lo que indica el fabricante." % [
			String(disc["name"]), "desbaste" if disc["family"] == "desbaste" else "láminas"], CITE_EN62841)
	if not (disc["materials"] as Array).has(kind):
		var own: Array = disc.get("abrasives", [abrasive])
		var recs := Abrasives.abrasives_for(kind, String(work.get("iso", "")))
		var names: Array = []
		for r in recs:
			if not own.has(r):
				names.append(_lower_first(String(Abrasives.ABRASIVES[r]["name"])))
		var sold: Array = []
		for k in disc["materials"]:
			sold.append(_kind_name(String(k)))
		var hint := ""
		if names.size() > 0:
			hint = " Para esta pieza: " + ", ".join(PackedStringArray(names)) + "."
		if recs.has(abrasive):
			hint += " Su grano sí sirve para esta pieza; el disco, no."
		_warn(warnings, "disco_inadecuado", "«%s» no está pensado para %s (el fabricante lo vende para %s).%s" % [
			String(disc["name"]), material, ", ".join(PackedStringArray(sold)), hint], "PFERD WHB 23")
	# Granos que reaccionan con el hierro (ABRASIVES.iron_reactive). Si además se sabe a qué temperatura reaccionan
	# y la pared del surco pasa de ella, el disco se vidria (el diamante: Komanduri y Shaw).
	var reacts := bool(ab["iron_reactive"]) and bool(work["ferrous"]) and kind != "fundicion"
	var react_c: Variant = ab["iron_reaction_c"]
	var t_wall := _wall_temp(work)
	var glazing := reacts and react_c != null and t_wall > float(react_c)
	if glazing:
		_warn(warnings, abrasive + "_ferrico", "%s sobre %s: se oxida por encima de ~%s °C y reacciona con el hierro desde ~%s °C, y la pared del surco llega a ~%s °C. El disco se vidria y se gasta muy deprisa. Para acero, corindón; para acero templado, CBN." % [
			String(ab["name"]), material, _fmt(float(ab["max_temp_c"])), _fmt(float(react_c)), _fmt(t_wall)], IRON_CITE.get(abrasive, ""))
	elif reacts:
		_warn(warnings, abrasive + "_ferrico", "%s sobre %s: reacciona con el hierro a la temperatura del contacto y el disco se gasta deprisa. Para acero, corindón." % [
			String(ab["name"]), material], IRON_CITE.get(abrasive, ""))
	if abrasive == "diamante" and kind == "fundicion":
		_warn(warnings, "diamante_fundicion", "En fundición gris y esferoidal sí se usan discos de diamante galvánico de grano grueso (D 852): el fabricante les da una vida muy larga.", "PFERD WHB 23")
	var loading := float(work["loading"]) * (1.0 - float(disc["loading_resistance"]))
	if loading >= LOADING_WARN:
		_warn(warnings, "embotamiento", "El disco se embota: la viruta de %s se pega al grano y tapa sus poros. Corta peor, se calienta más (hace falta ~40 %% más energía) y deja un corte sucio. Usa un disco específico para ese material." % _kind_name(kind), CITE_ROWE + "; PFERD SG ALU")
	if kind == "aluminio":
		_warn(warnings, "polvo_aluminio", "El polvo de aluminio puede ser explosivo: con aspiración, sin fuentes de ignición cerca y sin mezclarlo con polvo de acero.", "PFERD WHB 23, instrucciones de seguridad")
	out["loading"] = loading
	out["glazing"] = glazing
	var thick: float = disc["thickness_mm"]
	if thick <= 0.0:
		return out
	# Surco: en perpendicular al disco, su espesor más la holgura; en la cara de la pieza, / cos θ
	var kerf := thick + KERF_EXTRA_MM
	var kerf_s := kerf / cos(deg_to_rad(clampf(absf(angle), 0.0, 60.0)))
	out["kerf_mm"] = kerf
	out["kerf_surface_mm"] = kerf_s
	out["kerf_band_mm"] = [thick + KERF_EXTRA_MIN_MM, thick + KERF_EXTRA_MAX_MM]
	if absf(angle) >= ANGLE_WARN_DEG:
		_warn(warnings, "acunamiento", "Disco inclinado %s°: el surco se ensancha, la rebaba sale a un lado y el disco roza de lado. Un disco de corte trabaja con el borde: las fuerzas laterales lo pueden romper y, si se acuña en el corte, la radial rebota." % _fmt(absf(angle)), CITE_EN62841)
	var area := kerf_s * maxf(depth, 0.0)
	if area <= 0.0:
		return out
	# Energía específica: la medida por Awan et al. (2022), más un 40 % si el disco se embota o se vidria (Rowe)
	var coef := _energy_coeffs(work)
	var mult := 1.0 + LOADING_GAIN * maxf(loading, 1.0 if glazing else 0.0)
	var vc := vs * 1000.0  # mm/s
	var push := maxf(push_n, 0.0)
	# Caudal que da la potencia de la radial (P = mult·SEC(Q)·Q) y el que da el empuje (Archard). Parado, nada.
	var avail_kw := power_kw if power_kw > 0.0 else float(grinder_for(d)["power_kw"])
	var q_power := _q_for_power(avail_kw * 1000.0 / mult, coef, vc, kerf) if vc > 0.0 else 0.0
	var q_push := INF
	var hv := float(work["hv"])
	var eta := 1.0
	if not work["brittle"] and hv > 0.0:
		var gain := CERAMIC_K_GAIN if abrasive == "ceramico" else 1.0
		eta = Contact.hardness_efficiency(float(ab["hv"]) / hv)
		q_push = Abrasion.archard_wear(push, vc, hv * Contact.HV_MPA, K_ARCHARD) * gain * eta / mult
	var q_req := feed_req * area if feed_req > 0.0 else INF
	var q := minf(q_req, minf(q_power, q_push))
	var limited_by := ""
	if q <= 0.0 or not is_finite(q):
		q = 0.0
		var why := "el disco no gira"
		if vc > 0.0:
			why = "el grano es más blando que la pieza y no la raya" if eta <= 0.0 else ("sin empuje, el disco no entra" if push <= 0.0 else "el disco no arranca material")
		_warn(warnings, "sin_corte", "No hay corte: %s." % why, "")
	elif q < q_req:
		limited_by = "potencia" if q_power <= q_push else "empuje"
		if feed_req > 0.0 and limited_by == "potencia":
			_warn(warnings, "potencia", "La radial no da para ese avance: con %s W útiles corta como mucho a %s mm/s; si se empuja más, el motor cae de vueltas." % [_fmt(avail_kw * 1000.0), _fmt(q / area, 1)], "Bosch GWS 12-125 y GWS 22-230 P")
		elif feed_req > 0.0:
			_warn(warnings, "empuje", "Con un empuje de unos %s N el disco no arranca más de %s mm³/s en un material de %s HV: el avance se queda en %s mm/s. Cuanto más duro, más despacio (ley de Archard)." % [_fmt(push), _fmt(q, 1), _fmt(hv), _fmt(q / area, 1)], "Archard 1953")
	var e_eff := 0.0
	if q > 0.0:
		e_eff = maxf(mult * _sec(coef, vc, q, kerf), _chip_energy(work))
		out["specific_energy_band_j_mm3"] = _energy_band(work, e_eff, mult, vc, q, kerf)
	out["specific_energy_j_mm3"] = e_eff
	out["feed_mm_s"] = q / area
	out["q_mm3_s"] = q
	out["power_kw"] = e_eff * q / 1000.0
	out["limited_by"] = limited_by
	# Los dos límites por separado y la potencia que pediría arrancar lo que da el empuje (para el modo manual: si pasa
	# de la potencia útil, el motor pierde vueltas)
	out["q_power_mm3_s"] = q_power
	out["q_push_mm3_s"] = q_push
	if is_finite(q_push) and q_push > 0.0:
		out["push_power_kw"] = maxf(mult * _sec(coef, vc, q_push, kerf), _chip_energy(work)) * q_push / 1000.0
	return out


## Banda de la energía específica (J/mm³) al caudal q: la del modelo (e_eff) y la de las otras medidas de ese tipo de
## pieza con el mismo embotamiento (mult). Acero: las cuatro filas de acero al carbono de Awan et al. (2021) sin escalar
## con la velocidad (se midieron a la de su radial, no publicada). Aluminio: el 1100 y el 7075 de Awan et al. (2022).
## El resto: una sola medida, banda de anchura cero.
static func _energy_band(work: Dictionary, e_eff: float, mult: float, vc: float, q: float, kerf: float) -> Array:
	var lo := e_eff
	var hi := e_eff
	var chip := _chip_energy(work)
	if String(work.get("kind", "")) == "acero" and q > 0.0:
		for id in CUT_ENERGY_2021:
			var r: Dictionary = CUT_ENERGY_2021[id]
			var e := maxf(mult * (float(r["sce"]) + (float(r["psl_w"]) + float(r["ppl_w"])) / q), chip)
			lo = minf(lo, e)
			hi = maxf(hi, e)
	elif String(work.get("energy", "")) == "al":
		for id in ["al1100", "al7075"]:
			var e := maxf(mult * _sec(CUT_ENERGY[id], vc, q, kerf), chip)
			lo = minf(lo, e)
			hi = maxf(hi, e)
	return [lo, hi]


## Coeficientes de energía de la pieza: una fila de CUT_ENERGY, la interpolada del aluminio o una SCE fija.
static func _energy_coeffs(work: Dictionary) -> Dictionary:
	var energy := String(work.get("energy", ""))
	if energy == "al":
		var soft: Dictionary = CUT_ENERGY["al1100"]
		var hard: Dictionary = CUT_ENERGY["al7075"]
		var w := clampf((float(work["hv"]) - float(soft["hb"])) / (float(hard["hb"]) - float(soft["hb"])), 0.0, 1.0)
		return {
			"sce": lerpf(soft["sce"], hard["sce"], w), "c_sl": lerpf(soft["c_sl"], hard["c_sl"], w),
			"c_pl": lerpf(soft["c_pl"], hard["c_pl"], w),
		}
	if CUT_ENERGY.has(energy):
		return CUT_ENERGY[energy]
	return { "sce": maxf(float(work.get("sce", -1.0)), 1.0), "c_sl": 0.0, "c_pl": 0.0 }


## Caudal a partir del que se usa la fórmula medida: el menor medido, o el de mínima potencia si es mayor (por
## debajo, la energía se deja constante en vez de extrapolar el arado hacia infinito). kerf: anchura del disco.
static func _q_floor(coef: Dictionary, vc: float, kerf: float) -> float:
	var q_turn := sqrt(float(coef["c_pl"]) * vc * kerf * kerf / float(coef["sce"]))
	return maxf(Q_MEASURED_MIN, q_turn)


## Energía específica (J/mm³) a un caudal q (Awan et al. 2022).
static func _sec(coef: Dictionary, vc: float, q: float, kerf: float) -> float:
	var qc := maxf(q, _q_floor(coef, vc, kerf))
	return float(coef["sce"]) + float(coef["c_sl"]) * vc / qc + float(coef["c_pl"]) * vc * kerf * kerf / (qc * qc)


## Caudal (mm³/s) que se consigue con una potencia p (W): resuelve SEC(Q)·Q = p (con la energía constante por
## debajo del caudal mínimo).
static func _q_for_power(p: float, coef: Dictionary, vc: float, kerf: float) -> float:
	if p <= 0.0:
		return 0.0
	var qf := _q_floor(coef, vc, kerf)
	var ef := _sec(coef, vc, qf, kerf)
	if p <= ef * qf:
		return p / ef
	var a := float(coef["sce"])
	var b := float(coef["c_sl"]) * vc - p
	var c := float(coef["c_pl"]) * vc * kerf * kerf
	return (-b + sqrt(maxf(b * b - 4.0 * a * c, 0.0))) / (2.0 * a)


## Pieza de cut_off() a partir de su tipo, su grupo ISO 513 ("H" = templado) y su dureza (HV, si se conoce). Un tipo
## desconocido conserva su nombre, no se da por férrico y se calcula con la energía y la dureza del acero.
static func _work_from_kind(kind: String, iso: String, hv_override: float) -> Dictionary:
	var w: Dictionary
	if WORK_KINDS.has(kind):
		w = (WORK_KINDS[kind] as Dictionary).duplicate()
	else:
		w = { "name": kind.replace("_", " "), "hv": -1.0, "energy": "", "sce": -1.0, "thermal": "", "ferrous": false,
			"brittle": false, "loading": 0.0 }
	w["kind"] = kind
	w["iso"] = iso
	w["no_data"] = String(w["energy"]) == "" and float(w["sce"]) <= 0.0
	if w["no_data"]:
		var steel: Dictionary = WORK_KINDS["acero"]
		for k in ["hv", "energy", "sce", "thermal", "brittle"]:
			w[k] = steel[k]
	if iso == "H" and (kind == "acero" or kind == "inox"):
		w["name"] = String(w["name"]) + " templado"
		w["hv"] = HARDENED_HV
	if hv_override > 0.0:
		w["hv"] = hv_override
	return w


## Energía que se llevan las virutas de esa pieza (J/mm³); 0 si no hay datos térmicos.
static func _chip_energy(work: Dictionary) -> float:
	var fam := String(work.get("thermal", ""))
	if fam == "" or not Panels.THERMAL.has(fam):
		return 0.0
	return float(Panels.THERMAL[fam]["chip_j_mm3"])


## Temperatura de la pared del surco de esa pieza (°C); la ambiente si no hay datos térmicos.
static func _wall_temp(work: Dictionary) -> float:
	var fam := String(work.get("thermal", ""))
	if fam == "" or not Panels.THERMAL.has(fam):
		return T_AMBIENT
	return float(Panels.THERMAL[fam]["t_edge_c"])


## Relación G (volumen de pieza arrancado por volumen de disco gastado). ESTIMACIÓN: ~5 para un disco de resina en
## acero dulce, inversa a la dureza; el cerámico dura el doble; un grano que reacciona con el hierro, la mitad; el
## diamante en acero se gasta químicamente (0,5) y en piedra, vidrio o fundición dura mucho; el grano de metal duro
## soldado a un cuerpo de acero, 20.
static func _g_ratio(abrasive: String, work: Dictionary) -> float:
	var kind := String(work["kind"])
	var ab: Dictionary = Abrasives.ABRASIVES[abrasive]
	var reacts := bool(ab["iron_reactive"]) and bool(work["ferrous"]) and kind != "fundicion"
	if abrasive == "diamante":
		if reacts:
			return 0.5
		return 200.0 if kind in ["piedra", "vidrio", "fundicion"] else 20.0
	if abrasive == "cbn":
		return 100.0
	if abrasive == "carburo_w":
		# Grano soldado a un cuerpo de acero: el diámetro no mengua (PFERD). Del orden del diamante en no férricos
		return 20.0
	var hv := float(work.get("hv", -1.0))
	var g := 5.0 * 92.0 / hv if hv > 0.0 else 10.0
	if abrasive == "ceramico":
		g *= 2.0
	if reacts:
		g *= IRON_WEAR_G_FACTOR
	return clampf(g, 0.5, 50.0)


# ─────────────────────────────── Calor ───────────────────────────────
## Distancia (mm) al borde del surco a la que la temperatura de pico llega a t_c en una chapa fina de espesor t_mm
## (Adams 1958): 1/(Tp − T0) = √(2πe)·ρ·c·t·y/H + 1/(T_borde − T0), con H el calor por mm de corte (J/mm).
static func _adams_width(heat_j_mm: float, rho_c: float, t_mm: float, t_c: float, t_edge_c: float) -> float:
	if heat_j_mm <= 0.0 or t_c >= t_edge_c or t_c <= T_AMBIENT or rho_c <= 0.0 or t_mm <= 0.0:
		return 0.0
	var k := sqrt(TAU * exp(1.0))
	return (1.0 / (t_c - T_AMBIENT) - 1.0 / (t_edge_c - T_AMBIENT)) * heat_j_mm / (k * rho_c * t_mm)


## Color junto al corte: temperatura de pico en el borde del surco, su color, la banda con color de revenido y las
## bandas por color (del corte hacia fuera).
static func _heat_tint(panel: Dictionary, heat_j_mm: float, rho_c: float, t_mm: float, t_edge: float) -> Dictionary:
	var temp := t_edge if heat_j_mm > 0.0 else T_AMBIENT
	var table_id := String(panel["tint"])
	if table_id == "" or not Panels.TEMPER_COLORS.has(table_id):
		var melted: bool = panel["kind"] == "plastico" and temp >= float(Panels.THERMAL["plastico"]["t_soft_c"])
		return { "temp_c": temp, "color": "#4A3B30" if melted else "", "name": "plástico fundido y tostado" if melted else "sin colores de revenido",
			"width_mm": 0.0, "bands": [] }
	var rows: Array = Panels.TEMPER_COLORS[table_id]
	var color := ""
	var cname := "sin color"
	for row in rows:
		if temp >= float(row["t"]):
			color = row["hex"]
			cname = row["name"]
	var bands: Array = []
	for i in rows.size():
		var outer := _adams_width(heat_j_mm, rho_c, t_mm, float(rows[i]["t"]), t_edge)
		var inner := _adams_width(heat_j_mm, rho_c, t_mm, float(rows[i + 1]["t"]), t_edge) if i + 1 < rows.size() else 0.0
		if outer > inner:
			bands.push_front({ "from_mm": inner, "to_mm": outer, "color": rows[i]["hex"], "name": rows[i]["name"] })
	var width := _adams_width(heat_j_mm, rho_c, t_mm, float(rows[0]["t"]), t_edge)
	return { "temp_c": temp, "color": color, "name": cname, "width_mm": width, "bands": bands }


# ─────────────────────────────── Avisos ───────────────────────────────
static func _warn(list: Array, code: String, message: String, source: String) -> void:
	list.append({ "code": code, "message": message, "source": source })


## Avisos educativos de rescate: van con cualquier corte de carrocería.
static func _rescue_warnings(list: Array) -> void:
	_warn(list, "rescate_herramientas", "Los bomberos excarcelan sobre todo con cizallas y separadores hidráulicos. Una radial es trabajo en caliente: sus chispas pueden prender el combustible derramado o sus vapores, y no se usa cerca de materiales inflamables.", "DHS SAVER TechNote «Battery-Powered Rescue Tools» (2022); OSHA 4188 (2022); EN 62841-2-3")
	_warn(list, "rescate_airbag", "Ojo con los infladores de airbag de gas comprimido (argón y helio, hasta ~4.000 psi, sin válvula de alivio): el calor los puede reventar. La hoja de rescate ISO 17840 de cada modelo marca dónde están.", "Moore R., Firehouse, 1-10-2005; ISO 17840-1:2022")
	_warn(list, "rescate_alta_tension", "En híbridos y eléctricos, los cables de alta tensión van forrados de naranja y no se cortan: la hoja de rescate ISO 17840 muestra su recorrido.", "Reglamento CEPE/ONU n.º 100, 5.1.1.5.3; ISO 17840-1:2022")
	_warn(list, "educativo", "Simulador educativo: esto no es un procedimiento de rescate ni de taller.", "")


## Salida de cut_panel sin corte: todos los campos del contrato, en cero.
static func _empty_panel_result(panel_id: String, disc_id: String, angle: float, warnings: Array) -> Dictionary:
	return {
		"vs_ms": 0.0, "over_speed": false, "time_s": INF, "kerf_mm": 0.0, "burr_um": 0.0, "haz_mm": 0.0,
		"heat_tint": { "temp_c": T_AMBIENT, "color": "", "name": "sin color", "width_mm": 0.0, "bands": [] },
		"paint_burn_mm": 0.0, "sparks": { "rate": 0.0, "color": "", "color_name": "", "color_end": "", "color_end_name": "",
			"length_mm": 0.0, "bursts": 0.0, "bursts_name": "ninguna", "class": "" },
		"disc_wear_mm3": 0.0, "disc_loading": 0.0, "deformation": 0.0, "cleanliness": 0.0, "warnings": warnings,
		"quality": "estimate", "sources": [],
		"smoke": 0.0, "melt": 0.0, "burr_sides_um": { "lado_menos": 0.0, "lado_mas": 0.0 }, "front_temp_c": T_AMBIENT,
		"kerf_surface_mm": 0.0, "burr_side": "ambos", "smoke_from": [], "panel_id": panel_id, "disc_id": disc_id,
		"angle_deg": angle, "feed_mm_s": 0.0, "limited_by": "", "power_kw": 0.0, "q_mm3_s": 0.0,
		"specific_energy_j_mm3": 0.0, "heat_j_mm": 0.0, "glazing": false,
		"kerf_band_mm": [0.0, 0.0], "specific_energy_band_j_mm3": [0.0, 0.0],
	}


# ─────────────────────────────── Textos ───────────────────────────────
## Nombre en español de un `kind` de CONTRATOS.md (con tildes).
static func _kind_name(kind: String) -> String:
	return String(WORK_KINDS[kind]["name"]) if WORK_KINDS.has(kind) else kind.replace("_", " ")


## Primera letra en minúscula para meter un nombre en una frase, salvo siglas («CBN», «AA6016»).
static func _lower_first(s: String) -> String:
	if s.length() >= 2 and s[1] == s[1].to_lower():
		return s[0].to_lower() + s.substr(1)
	return s


## Número para los textos: el redondeo de JavaScript (Js.to_fixed), coma decimal y punto de miles (12.250; 1,5).
## Infinito, «∞».
static func _fmt(x: float, decimals: int = 0) -> String:
	if is_nan(x):
		return "—"
	if is_inf(x):
		return "∞" if x > 0.0 else "-∞"
	var s := Js.to_fixed(x, decimals)
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var int_part := s
	var frac := ""
	var dot := s.find(".")
	if dot >= 0:
		int_part = s.substr(0, dot)
		frac = s.substr(dot + 1)
	if int_part.length() > 3:
		var grouped := ""
		var n := 0
		for i in range(int_part.length() - 1, -1, -1):
			grouped = int_part[i] + grouped
			n += 1
			if n % 3 == 0 and i > 0:
				grouped = "." + grouped
		int_part = grouped
	var out := int_part + ("," + frac if frac != "" else "")
	return ("-" + out) if neg else out
