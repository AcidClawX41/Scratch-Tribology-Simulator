## Sonido de máquina del taller · función PURA: entrada de sonido (CONTRATOS.md) → marco de parámetros.
##
## En tiempo real no se sintetiza nada muestra a muestra (en móvil sería lento): el sonido son bucles
## horneados (tools/bake_sounds.gd → assets/sfx/taller/) y este módulo decide, a partir del estado de la
## máquina, qué frecuencias y qué niveles deben sonar. voices() lo traduce a cada bucle: pitch_scale, volumen
## y filtros del bus «MaquinaCorte». app/taller/machine_sound_player.gd lo aplica 60 veces por segundo.
##
## Entrada (CONTRATOS.md, «Entrada de sonido de máquina»):
##   { process: "lathe" | "mill" | "drill" | "grinder" | "sharpener", rpm, teeth, jaws, pc_kw, pmax_kw,
##     work_kind, chatter: { risk, mode_hz } | null, coolant, tool_pos: Vector3 }
## Campos opcionales que añade esta unidad (pendientes de pasar al contrato):
##   disc_id: "fino_1mm" | "grueso_3mm" | "diamante" | "laminas" (radial) · sheet_mm: espesor de la chapa (mm;
##   0 = sin chapa que vibre, p. ej. un hacha en el tornillo de banco) · vc (m/min), o diameter_mm para calcularla ·
##   mains_hz (50 por defecto) · speed_droop (caída relativa del giro a plena carga; 0 si un variador lo regula) ·
##   machine_kind (solo con process "sharpener"): "banco" (por defecto) | "humeda_lenta" | "afilabrocas" |
##   "afilafresas", los mismos nombres que la vista 3D de la afiladora. La amoladora con disco de láminas es
##   process "grinder" con disc_id "laminas".
##   Combinada (esmeriladora con una piedra húmeda reducida en el mismo motor, «banco» con muela «piedra»):
##   stone_rpm (giro de la piedra; añade su roce mojado) y grind_kind ("humeda_lenta" mientras se trabaja en la
##   piedra: banda del amolado en húmedo y sin chispas; pasar entonces vc, la de la piedra, en m/min).
##   rpm es el giro sin carga; el marco aplica la caída bajo carga del motor (ver droop en MACHINES).
##   tool_pos va en metros, en el sistema local del nodo de sonido (x a la derecha del operario).
##   En la afiladora húmeda lenta, coolant no pone la bomba de taladrina: el agua de la bandeja suena en su bucle.
## Salida (marco):
##   { process, rpm (giro real), load (Pc/Pmáx), vc (m/min),
##     tones: [{ name, layer, hz, gain }],   capas: motor · spindle · pass · sheet · coolant
##     noise: { fc_hz, q, gain, lp_hz },     banda de ruido del corte (gain = valor eficaz)
##     crackle_rate (1/s), crackle_gain,     crujido de viruta o chispas
##     chatter: { hz, gain, mod_hz, depth }, coolant_gain, master_gain, pan (−1…1),
##     machine_kind,                         variante de la afiladora («» en las demás máquinas)
##     rub: { gain, pitch } }                roce de la piedra húmeda (bucle de ruido que late con el giro)
## Las ganancias son amplitudes lineales (1 = fondo de escala) antes de master_gain. El primer tono de cada
## capa es su tono clave: los demás mantienen con él la proporción del bucle horneado.
##
## Fuentes en docs/taller/fuentes-u8.md. Cada ficha de catálogo lleva source y quality (CONTRATOS.md); lo que
## no tiene medición publicada va marcado "estimate".
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")

const PROCESSES := ["lathe", "mill", "drill", "grinder", "sharpener"]
const SAMPLE_RATE := 22050  # Hz de los bucles horneados (el mismo que los efectos de la 1.x)
const QUALITIES := ["primary", "secondary", "estimate"]

## Red eléctrica: 50 Hz en Europa (EN 50160). El zumbido magnético de un motor de inducción está en 2·f y en
## múltiplos pares (fuerzas de Maxwell ∝ B²; Gieras, Wang y Lai 2006). [nombre, múltiplo de f, amplitud
## relativa]; las amplitudes relativas son estimación.
const MAINS_HZ := 50.0
const MOTOR_HUM := [
	["motor_2f", 2, 1.0], ["motor_4f", 4, 0.45], ["motor_6f", 6, 0.25], ["motor_8f", 8, 0.12], ["motor_12f", 12, 0.06],
]
const MOTOR_ON_RPM := 10.0  # por debajo, el motor se da por parado (fundido suave al arrancar y parar)
const MOTOR_LOAD_BOOST := 0.3  # +30 % de zumbido a plena carga (rizado de par y armónicos de ranura): estimación

## Máquinas. spindle: [nombre, orden (múltiplo de n/60), amplitud relativa] de lo que gira con el husillo:
## desequilibrio residual (1×), desalineación (2×; ISO 13373-3, Randall 2011) y engrane (z·n/60; Smith 2003).
## level_db: presión sonora típica en vacío a 1 m, dB(A). droop: caída del giro a plena carga. speed_exp: la
## amplitud del giro crece como (n/n_ref)^exp: 6 dB por duplicar la velocidad en las máquinas de engranajes y
## 12 dB en la radial, donde manda el ventilador.
const SRC_MACHINE := (
	"Frecuencias: n/60, z·n/60 (Randall 2011; Smith 2003). Estimación: dientes de engranajes, álabes, "
	+ "relación de la radial (33/11), amplitudes, level_db y speed_exp. Caída de giro: deslizamiento del "
	+ "3–5 % en catálogos de motores IEC 60034 (inducción); motor universal, estimación (Chapman 2012)."
)
const MACHINES := {
	"lathe": {
		"label": "Torno paralelo", "motor": "induction", "rpm_ref": 1200.0, "pmax_kw": 5.5, "diameter_mm": 50.0,
		"level_db": 78.0, "droop": 0.04, "speed_exp": 1.0, "spindle_gain": 0.05, "motor_gain": 1.0,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.5], ["gear_mesh", 47, 0.8], ["gear_mesh_2x", 94, 0.25]],
		"pass": "jaws", "pass_count": 3, "loop": "spindle_lathe", "source": SRC_MACHINE, "quality": "estimate",
	},
	"mill": {
		"label": "Fresadora", "motor": "induction", "rpm_ref": 3000.0, "pmax_kw": 3.0, "diameter_mm": 16.0,
		"level_db": 78.0, "droop": 0.04, "speed_exp": 1.0, "spindle_gain": 0.05, "motor_gain": 1.0,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.4], ["gear_mesh", 31, 0.6], ["gear_mesh_2x", 62, 0.2]],
		"pass": "teeth", "pass_count": 4, "loop": "spindle_mill", "source": SRC_MACHINE, "quality": "estimate",
	},
	"drill": {
		"label": "Taladro de columna", "motor": "induction", "rpm_ref": 1000.0, "pmax_kw": 1.1, "diameter_mm": 10.0,
		"level_db": 75.0, "droop": 0.04, "speed_exp": 1.0, "spindle_gain": 0.05, "motor_gain": 1.0,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.4], ["spindle_3x", 3, 0.15]],
		"pass": "teeth", "pass_count": 2, "loop": "spindle_drill", "source": SRC_MACHINE, "quality": "estimate",
	},
	"grinder": {
		# Amoladora de 125 mm a 11.000 rpm (disco 1× = 183,3 Hz). Motor universal a 3× por la corona cónica
		# 33/11: rotor 550 Hz, 9 álabes de ventilador (27×) y engrane 33×. level_db en el orden de lo que
		# declaran los fabricantes según EN 62841-2-3.
		"label": "Radial de 125 mm", "motor": "universal", "rpm_ref": 11000.0, "pmax_kw": 0.72, "diameter_mm": 125.0,
		"level_db": 91.0, "droop": 0.30, "speed_exp": 2.0, "spindle_gain": 0.07, "motor_gain": 0.35,
		"spindle": [
			["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.35], ["rotor", 3, 1.1], ["rotor_2x", 6, 0.45], ["fan", 27, 0.5],
			["gear_mesh", 33, 0.4],
		],
		"pass": "segments", "pass_count": 0, "loop": "spindle_grinder", "source": SRC_MACHINE, "quality": "estimate",
	},
	"sharpener": {
		# Esmeriladora de banco de 150 mm con motor de inducción de 2 polos: las muelas giran con el rotor, a
		# 2950 rpm en vacío (49,2 Hz; síncrono de 3000 rpm a 50 Hz menos el deslizamiento). Es la variante «banco»
		# de SHARPENERS (machine_kind por defecto). grind: banda del ruido de amolado (ver SHARPENERS).
		"label": "Esmeriladora de banco", "motor": "induction", "rpm_ref": 2950.0, "pmax_kw": 0.37, "diameter_mm": 150.0,
		"level_db": 82.0, "droop": 0.05, "speed_exp": 1.0, "spindle_gain": 0.06, "motor_gain": 1.0,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.5], ["spindle_3x", 3, 0.2]],
		"pass": "", "pass_count": 0, "loop": "spindle_sharpener",
		"grind": { "fc": 4200.0, "q": 1.3, "gain": 0.9, "lp_hz": 16000.0, "vc_ref": 1390.2, "sparks": 150.0 },
		"rub": 0.0, "pump": true,
		"source": "Einhell TC-BG 150, manual original (art. 44.126.32): 220–240 V ~ 50 Hz, n0 = 2980 min⁻¹, muelas de"
			+ " 150 × 16 × 32 mm (K36 y K60), 23,4 m/s, LpA = 82,3 dB(A) ± 3 (EN 62841). Esmeriladoras de 150 mm y 150 W a"
			+ " 2950 min⁻¹ (fichas de venta). Motor de 2 polos: síncrono de 3000 rpm a 50 Hz. " + SRC_MACHINE,
		"quality": "secondary",
	},
}

## Variantes de la afiladora (process "sharpener", campo machine_kind). «banco» es MACHINES["sharpener"]. Mismas
## claves que MACHINES, más:
##   grind: banda del ruido de amolado { fc, q, gain, lp_hz, vc_ref (m/min: la velocidad periférica de la
##     máquina de referencia; la banda sube con √(vc/vc_ref), acotada), sparks (chasquidos por segundo a plena
##     carga, proporcionales a la carga; 0 en húmedo) } — ESTIMACIÓN: sin medición publicada del espectro;
##   rub: nivel relativo del bucle «stone_rub» (piedra que gira mojada en su bandeja; 0 si no hay);
##   pump: si coolant pone la bomba de taladrina (la húmeda lenta no tiene bomba: la piedra se moja en la bandeja).
## pmax_kw es la potencia absorbida de la ficha: la de contacto (μ·F·v) se compara con ella.
const SRC_WET := (
	"Tormek T-8, manual: 200 W, 100 rpm, muela de 250/180 mm (máx./mín.), LpA = 59 dB(A) (KpA 2,5), LWA = 54 dB(A);"
	+ " Einhell TC-WG 200: 110 min⁻¹, 125 W, muela de 200 × 40 mm K220 y rueda de cuero de 180 mm. Motor de"
	+ " inducción: zumbido a 2·f de red (Gieras, Wang y Lai 2006). Estimación: bandas, roce y caída de giro."
)
const SRC_COMPACT := (
	"MRCM MR-13A (afiladora de brocas): 220 V, motor universal de 120 W, 4400 rpm, muela de CBN; VEVOR MR-13A:"
	+ " 120 W, 4500 rpm; MRCM MR-X3 (afiladora de fresas): 160 W, 4400 rpm, muela de diamante (SDC); muelas de"
	+ " recambio de Ø78 × 10 mm para las dos (sharpening_machines.gd). La muela va en el eje del motor."
	+ " Estimación: delgas del colector (12), niveles, caída de giro y bandas."
)
const SHARPENERS := {
	"humeda_lenta": {
		# Afiladora húmeda lenta (tipo Tormek): piedra de 250 mm a 100 rpm (1,67 Hz, inaudible como tono). Suenan
		# el zumbido del motor y el roce mojado de la piedra, que late con cada vuelta.
		"label": "Afiladora húmeda lenta", "motor": "induction", "rpm_ref": 100.0, "pmax_kw": 0.2, "diameter_mm": 250.0,
		"level_db": 59.0, "droop": 0.05, "speed_exp": 1.0, "spindle_gain": 0.0, "motor_gain": 1.0,
		"spindle": [], "pass": "", "pass_count": 0, "loop": "",
		"grind": { "fc": 1500.0, "q": 0.8, "gain": 0.7, "lp_hz": 5000.0, "vc_ref": 78.54, "sparks": 0.0 },
		"rub": 1.0, "pump": false, "source": SRC_WET, "quality": "secondary",
	},
	"afilabrocas": {
		# Afiladora de brocas compacta: motor universal (con escobillas y colector) y la muela de CBN en su eje.
		"label": "Afiladora de brocas", "motor": "universal", "rpm_ref": 4400.0, "pmax_kw": 0.12, "diameter_mm": 78.0,
		"level_db": 74.0, "droop": 0.2, "speed_exp": 1.0, "spindle_gain": 0.05, "motor_gain": 0.3,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.4], ["spindle_3x", 3, 0.15], ["commutator", 12, 0.3]],
		"pass": "", "pass_count": 0, "loop": "spindle_compact",
		"grind": { "fc": 5200.0, "q": 1.6, "gain": 0.8, "lp_hz": 16000.0, "vc_ref": 1078.2, "sparks": 40.0 },
		"rub": 0.0, "pump": true, "source": SRC_COMPACT, "quality": "estimate",
	},
	"afilafresas": {
		# Afiladora de fresas compacta: la misma arquitectura, con muela de diamante y la fresa en un cabezal de pinza.
		"label": "Afiladora de fresas", "motor": "universal", "rpm_ref": 4400.0, "pmax_kw": 0.16, "diameter_mm": 78.0,
		"level_db": 75.0, "droop": 0.2, "speed_exp": 1.0, "spindle_gain": 0.05, "motor_gain": 0.3,
		"spindle": [["spindle_1x", 1, 1.0], ["spindle_2x", 2, 0.4], ["spindle_3x", 3, 0.15], ["commutator", 12, 0.3]],
		"pass": "", "pass_count": 0, "loop": "spindle_compact",
		"grind": { "fc": 5800.0, "q": 1.8, "gain": 0.7, "lp_hz": 16000.0, "vc_ref": 1078.2, "sparks": 15.0 },
		"rub": 0.0, "pump": true, "source": SRC_COMPACT, "quality": "estimate",
	},
}
const SHARPENER_KINDS := ["banco", "humeda_lenta", "afilabrocas", "afilafresas"]
const SHARPENER_DEFAULT := "banco"
const LEVEL_REF_DB := 97.0  # nivel al que master_gain = 1 (margen para el limitador del Master)
const LEVEL_COMPRESS := 0.5  # la escala de dB se comprime a la mitad: el torno no queda inaudible junto a la radial
const LOAD_MAX := 1.5  # sobrecarga máxima considerada (Pc/Pmáx)
const SPEED_MAX := 2.5  # n/n_ref máximo para la ley de ganancia del giro

## Capa de paso: garras del plato (aire que baten), dientes de la fresa o labios de la broca (impactos), o
## segmentos del disco de diamante. Frecuencia = cuenta · n/60. Las garras son una fuente aerodinámica: su
## amplitud crece como (n/n_ref)³ (potencia ∝ U⁶ de un dipolo, Curle 1955; ruido de rotores, Gutin 1936); los
## impactos, con √carga.
const PASS := {
	"jaws": { "loop": "jaws", "air": 0.05, "cut": 0.0 },
	"teeth": { "loop": "teeth", "air": 0.006, "cut": 0.22 },
	"segments": { "loop": "segments", "air": 0.02, "cut": 0.12 },
}

## Banda de ruido del corte según el material (kind de CONTRATOS.md), para torno, fresa, taladro y afiladora.
## fc (Hz) y q: centro y selectividad de la banda; vc_ref (m/min): la banda sube con √(vc/vc_ref); gain: nivel
## relativo; chip_mm: largo de la viruta rota; lambda: relación de compresión de la viruta; lp_hz: paso bajo
## que apaga los materiales blandos.
const SRC_KIND := (
	"Estimación: sin medición publicada de la banda del ruido de corte por material. Orden cualitativo de"
	+ " las formas de viruta: ISO 3685:1993, anexo G (fundición y latón, discontinua; aluminio, larga; "
	+ "acero con rompevirutas, corta). λ de 1,5 a 4 en aceros (Trent y Wright 2000)."
)
const KIND := {
	"acero": { "fc": 3200.0, "q": 2.2, "vc_ref": 200.0, "gain": 1.0, "chip_mm": 30.0, "lambda": 2.5, "lp_hz": 16000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"inox": { "fc": 3800.0, "q": 2.8, "vc_ref": 150.0, "gain": 1.1, "chip_mm": 60.0, "lambda": 2.5, "lp_hz": 16000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"fundicion": { "fc": 2400.0, "q": 1.2, "vc_ref": 180.0, "gain": 0.9, "chip_mm": 2.0, "lambda": 1.5, "lp_hz": 12000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"aluminio": { "fc": 2200.0, "q": 1.3, "vc_ref": 400.0, "gain": 0.75, "chip_mm": 150.0, "lambda": 2.0, "lp_hz": 8000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"laton": { "fc": 3000.0, "q": 1.6, "vc_ref": 250.0, "gain": 0.9, "chip_mm": 3.0, "lambda": 1.5, "lp_hz": 14000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"titanio": { "fc": 4200.0, "q": 3.0, "vc_ref": 60.0, "gain": 1.1, "chip_mm": 25.0, "lambda": 1.2, "lp_hz": 16000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"niquel": { "fc": 4000.0, "q": 2.8, "vc_ref": 40.0, "gain": 1.1, "chip_mm": 40.0, "lambda": 2.0, "lp_hz": 16000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"madera": { "fc": 1200.0, "q": 0.9, "vc_ref": 1000.0, "gain": 0.9, "chip_mm": 5.0, "lambda": 1.0, "lp_hz": 7000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"plastico": { "fc": 900.0, "q": 0.8, "vc_ref": 300.0, "gain": 0.5, "chip_mm": 500.0, "lambda": 1.5, "lp_hz": 3500.0,
		"source": SRC_KIND, "quality": "estimate" },
	"piedra": { "fc": 2600.0, "q": 0.9, "vc_ref": 60.0, "gain": 1.0, "chip_mm": 0.5, "lambda": 1.0, "lp_hz": 14000.0,
		"source": SRC_KIND, "quality": "estimate" },
	"vidrio": { "fc": 4500.0, "q": 1.4, "vc_ref": 30.0, "gain": 1.0, "chip_mm": 0.5, "lambda": 1.0, "lp_hz": 16000.0,
		"source": SRC_KIND, "quality": "estimate" },
}
## La banda del corte se acota a [CUT_FC_MIN, CUT_FC_MAX]: tiene que caer dentro del ruido rosa horneado
## (100 Hz–10 kHz, bajo el Nyquist de 11 kHz) para que la compensación de nivel de voices() valga.
const CUT_FC_MIN := 300.0
const CUT_FC_MAX := 6500.0
## Radial cortando chapa (el caso de los rescates): el acero chirría (banda alta y estrecha, chispas), el
## aluminio embota el disco y suena más apagado, y el plástico se funde (banda baja, sin chispas). La velocidad
## periférica de referencia es la del disco de 125 mm a 11.000 rpm (72 m/s = 4.320 m/min). sparks: chasquidos
## por segundo a plena carga (proporcionales a la carga). Los demás materiales usan KIND con la banda un 50 %
## más alta; el disco se aplica igual a todos.
const SRC_GRINDER := (
	"Estimación: sin medición publicada del ruido de una radial cortando chapa por material. Velocidad "
	+ "periférica: 72 m/s (máximo de 80 m/s para discos de 125 mm, EN 12413)."
)
const GRINDER_KIND := {
	"acero": { "fc": 5200.0, "q": 3.5, "gain": 0.65, "sparks": 120.0, "lp_hz": 16000.0,
		"source": SRC_GRINDER, "quality": "estimate" },
	"inox": { "fc": 5600.0, "q": 3.8, "gain": 0.7, "sparks": 90.0, "lp_hz": 16000.0,
		"source": SRC_GRINDER, "quality": "estimate" },
	"aluminio": { "fc": 2400.0, "q": 1.2, "gain": 0.45, "sparks": 12.0, "lp_hz": 6000.0,
		"source": SRC_GRINDER, "quality": "estimate" },
	"plastico": { "fc": 850.0, "q": 0.8, "gain": 0.3, "sparks": 0.0, "lp_hz": 2500.0,
		"source": SRC_GRINDER, "quality": "estimate" },
}
const GRINDER_VC_REF := 4320.0  # m/min: π·125 mm·11.000 rpm
const GRINDER_FALLBACK_FC := 1.5  # los materiales sin ficha de radial suben la banda un 50 % (velocidad periférica)
## Discos de la radial (disc_id). fc, q, gain, crackle y sheet multiplican los valores del material; drag es
## la carga extra por rozamiento del disco (un disco grueso roza más y frena más el motor). segments: segmentos
## del borde (solo el de diamante: su paso suena como un silbido a segmentos·n/60).
const SRC_DISC := (
	"Estimación: comportamiento cualitativo de cada tipo de disco (fino, grueso, diamante segmentado y "
	+ "láminas); sin medición publicada."
)
const DISCS := {
	"fino_1mm": { "label": "Disco de corte fino (1 mm)", "source": SRC_DISC, "quality": "estimate",
		"fc": 1.1, "q": 1.2, "gain": 1.0, "crackle": 1.0, "sheet": 1.0, "drag": 0.0, "segments": 0 },
	"grueso_3mm": { "label": "Disco de corte grueso (3 mm)", "source": SRC_DISC, "quality": "estimate",
		"fc": 0.8, "q": 0.7, "gain": 1.15, "crackle": 1.4, "sheet": 0.8, "drag": 0.15, "segments": 0 },
	"diamante": { "label": "Disco de diamante segmentado", "source": SRC_DISC, "quality": "estimate",
		"fc": 1.2, "q": 1.3, "gain": 0.9, "crackle": 0.35, "sheet": 1.1, "drag": 0.0, "segments": 10 },
	"laminas": { "label": "Disco de láminas", "source": SRC_DISC, "quality": "estimate",
		"fc": 0.65, "q": 0.6, "gain": 0.9, "crackle": 0.6, "sheet": 0.5, "drag": 0.05, "segments": 0 },
}
const DISC_DEFAULT := "fino_1mm"

## Chapa que vibra (el «ring»): modos de flexión de una placa rectangular apoyada (Kirchhoff; Leissa 1969,
## NASA SP-160): f_mn = (π/2)·√(D/(ρh))·((m/a)² + (n/b)²), con D = E·h³/(12(1−ν²)). Todos los modos escalan
## con h·c_p, c_p = √(E/(ρ(1−ν²))): un solo pitch_scale mueve el bucle de un material o espesor a otro. Suenan
## sobre todo los modos impar-impar, los que mejor radian por debajo de la frecuencia de coincidencia (Wallace
## 1972). Panel de referencia: 300 × 200 mm de acero de 0,8 mm (un tramo de puerta entre refuerzos). eta:
## factor de pérdidas; ring: nivel relativo del «ring».
const SRC_SHEET := (
	"E, ρ y ν: valores de manual (acero DC04, aluminio 6016, PP con talco). Estimación: espesores típicos"
	+ " de carrocería, panel de referencia, eta (del orden de Cremer, Heckl y Petersson 2005) y ring."
)
const SHEET := {
	"acero": { "e_gpa": 210.0, "rho": 7850.0, "nu": 0.30, "h_mm": 0.8, "eta": 0.01, "ring": 1.0,
		"source": SRC_SHEET, "quality": "estimate" },
	"inox": { "e_gpa": 200.0, "rho": 7900.0, "nu": 0.30, "h_mm": 0.8, "eta": 0.01, "ring": 1.0,
		"source": SRC_SHEET, "quality": "estimate" },
	"aluminio": { "e_gpa": 70.0, "rho": 2700.0, "nu": 0.33, "h_mm": 1.0, "eta": 0.012, "ring": 0.6,
		"source": SRC_SHEET, "quality": "estimate" },
	"plastico": { "e_gpa": 1.5, "rho": 1000.0, "nu": 0.40, "h_mm": 3.0, "eta": 0.08, "ring": 0.05,
		"source": SRC_SHEET, "quality": "estimate" },
}
const SHEET_REF := { "kind": "acero", "a_mm": 300.0, "b_mm": 200.0, "f_lo": 900.0, "f_hi": 3600.0 }

## Chatter regenerativo: la máquina vibra cerca de un modo estructural, no a un múltiplo del paso de dientes
## (Tlusty y Polacek 1963; Altintas 2012, «Manufacturing Automation», cap. 3). En el mínimo de los lóbulos,
## donde la parte real de la FRF es más negativa, f_c = f_n·√(1+2ζ). En fresado aparecen además bandas laterales
## f_c ± k·f_tp (Insperger et al. 2003): se modelan con dos bandas a ±f_tp que, al batir, modulan el tono.
## risk = b/b_lim (profundidad frente a la de estabilidad): estable por debajo de 1, desarrollado a 1,5.
## ζ = 3 % (estimación; los modos de máquina herramienta rondan el 1–5 %).
const CHATTER_ZETA := 0.03
const CHATTER_DEPTH := 0.5

## Refrigerante: bomba centrífuga de 2 polos (2.800 rpm, 46,7 Hz) con 6 álabes (280 Hz; paso de álabes z·n/60,
## Brennen 1994) y el chorro que salpica (banda de ruido del bucle). Estimación.
const COOLANT_PUMP_HZ := 2800.0 / 60.0
const COOLANT := [["pump", 1, 1.0], ["pump_vanes", 6, 0.5]]

## Niveles (amplitud lineal antes de master_gain). Estimación de mezcla: el corte a plena carga queda unos
## 8–10 dB por encima de la máquina en vacío. ISO 230-5 define cómo medir la emisión de ruido de una máquina
## herramienta, pero los valores dependen de cada máquina y no hay una medición publicada que copiar.
const G_MOTOR := 0.07
const G_CUT := 0.5
const G_SHEET := 0.22
const G_CHATTER := 0.3
const G_COOLANT := 0.09
const G_CHIP := 0.3
const G_RUB := 0.05  # roce de la piedra húmeda a las rpm de referencia (crece con el giro): estimación de mezcla
const RUB_PITCH := Vector2(0.25, 4.0)  # margen del pitch_scale del roce (de 25 a 400 rpm con la piedra de 100)
const PAN_HALF_M := 0.75  # m: media bancada; tool_pos.x = ±0,75 m da el paneo máximo
## Margen de las voces: voices() entrega los volúmenes 12 dB por debajo y el bus «Maquina» los recupera con un
## AudioEffectAmplify de +12 dB (default_bus_layout.tres). Así ninguna voz pasa de 0 dB y el tope max_db de
## AudioStreamPlayer3D (+6 dB, pensado para fuentes muy cercanas) no aplasta el corte más fuerte.
const HEADROOM_DB := 12.0
const HEADROOM_GAIN := 0.251188643150958  # 10^(−12/20)

## Bucles horneados (assets/sfx/taller/<id>.wav, mono, 16 bits, 22.050 Hz). level: amplitud del tono clave o
## valor eficaz del ruido en el bucle; dur: s, elegidos para que todos los tonos den ciclos enteros (costura
## exacta). La frecuencia del tono clave no se copia aquí: sale del marco de la entrada de referencia de cada
## bucle (loop_ref_hz), la misma de la que toma sus frecuencias tools/bake_sounds.gd. El chatter es un tono
## genérico de 1000 Hz. «stone_rub» es ruido sin tono clave: late turn_hz veces por segundo (dos vueltas de la
## piedra a 100 rpm en 1,2 s) y su pitch_scale es rpm/rpm_ref (marco → rub.pitch).
const LOOPS := {
	"motor": { "level": 0.4, "dur": 1.2 },
	"spindle_lathe": { "level": 0.25, "dur": 1.2 },
	"spindle_mill": { "level": 0.25, "dur": 1.2 },
	"spindle_drill": { "level": 0.25, "dur": 1.2 },
	"spindle_grinder": { "level": 0.2, "dur": 1.2 },
	"spindle_sharpener": { "level": 0.25, "dur": 1.2 },
	"spindle_compact": { "level": 0.25, "dur": 1.2 },
	"stone_rub": { "level": 0.15, "dur": 1.2, "turn_hz": 100.0 / 60.0 },
	"jaws": { "level": 0.3, "dur": 1.2 },
	"teeth": { "level": 0.18, "dur": 1.2 },
	"segments": { "level": 0.22, "dur": 1.2 },
	"cut": { "level": 0.18, "dur": 2.0, "band_lo": 100.0, "band_hi": 10000.0 },
	"sheet": { "level": 0.1, "dur": 2.0 },
	"chatter": { "level": 0.4, "dur": 1.2, "ref_hz": 1000.0 },
	"coolant": { "level": 0.2, "dur": 1.2 },
	"crackle": { "level": 0.08, "dur": 2.0, "rate": 200.0 },
}
## Granos de viruta (one-shots, assets/sfx/taller/chip_<i>.wav, pico exacto CHIP_PEAK).
const CHIP_GRAINS := 4
const CHIP_PEAK := 0.9
const GRAIN_RATE_MAX := 30.0  # por encima, el crujido se completa con el bucle «crackle» (granos más densos)
const CRACKLE_RATE_MAX := 400.0

## Cachés de valores que solo dependen de constantes. El módulo es seguro para hilos (CONTRATOS.md,
## «Rendimiento y multinúcleo»): las dos cachés se leen y se escriben siempre con _cache_lock. El valor se calcula
## fuera del cerrojo (es una función pura: si dos hilos lo calculan a la vez, sale el mismo número).
static var _cache_lock := Mutex.new()
static var _sheet_key_hz := 0.0  # caché de sheet_key_hz()
static var _ref_hz := {}  # caché de loop_ref_hz()


## Ficha de la máquina: la de MACHINES o, con process "sharpener", la de su variante (SHARPENERS; «banco» y
## cualquier otro nombre, la de MACHINES["sharpener"]).
static func machine_def(process: String, machine_kind: String = "") -> Dictionary:
	if process == "sharpener" and SHARPENERS.has(machine_kind):
		return SHARPENERS[machine_kind]
	return MACHINES[process] if MACHINES.has(process) else MACHINES["lathe"]


## Entrada completa: rellena los campos que falten con los valores de la máquina y acota los números.
static func normalize(input: Dictionary) -> Dictionary:
	var p := str(input.get("process", "lathe"))
	if not MACHINES.has(p):
		p = "lathe"
	var mk := ""
	var grind_kind := ""
	var stone_rpm := 0.0
	if p == "sharpener":
		mk = str(input.get("machine_kind", SHARPENER_DEFAULT))
		if not SHARPENER_KINDS.has(mk):
			mk = SHARPENER_DEFAULT
		grind_kind = str(input.get("grind_kind", ""))
		if not SHARPENER_KINDS.has(grind_kind):
			grind_kind = ""
		stone_rpm = maxf(0.0, float(input.get("stone_rpm", 0.0)))
	var m := machine_def(p, mk)
	var kind := str(input.get("work_kind", "acero"))
	if not KIND.has(kind):
		kind = "acero"
	var disc := str(input.get("disc_id", DISC_DEFAULT))
	if not DISCS.has(disc):
		disc = DISC_DEFAULT
	var pos: Variant = input.get("tool_pos", Vector3.ZERO)
	var ch: Variant = input.get("chatter", null)
	var chatter: Variant = null
	if ch is Dictionary and float(ch.get("mode_hz", 0.0)) > 0.0:
		chatter = { "risk": maxf(0.0, float(ch.get("risk", 0.0))), "mode_hz": float(ch["mode_hz"]) }
	var count := int(m["pass_count"])
	if m["pass"] == "jaws":
		count = int(input.get("jaws", count))
	elif m["pass"] == "teeth":
		count = int(input.get("teeth", count))
	elif m["pass"] == "segments":
		count = int(DISCS[disc]["segments"])
	return {
		"process": p,
		"machine_kind": mk,
		"grind_kind": grind_kind,
		"stone_rpm": stone_rpm,
		"rpm": maxf(0.0, float(input.get("rpm", 0.0))),
		"pass_count": maxi(0, count),
		"pc_kw": maxf(0.0, float(input.get("pc_kw", 0.0))),
		"pmax_kw": maxf(0.01, float(input.get("pmax_kw", m["pmax_kw"]))),
		"work_kind": kind,
		"chatter": chatter,
		"coolant": bool(input.get("coolant", false)),
		"tool_pos": pos if pos is Vector3 else Vector3.ZERO,
		"disc_id": disc,
		"sheet_mm": float(input.get("sheet_mm", SHEET[kind]["h_mm"] if SHEET.has(kind) else 0.0)),
		"diameter_mm": maxf(0.0, float(input.get("diameter_mm", m["diameter_mm"]))),
		"vc": float(input.get("vc", -1.0)),
		"mains_hz": float(input.get("mains_hz", MAINS_HZ)),
		"speed_droop": Contact.clamp_js(float(input.get("speed_droop", m["droop"])), 0.0, 0.9),
	}


## El marco de parámetros de una entrada de sonido (función pura y determinista: misma entrada, mismo marco).
static func frame(input: Dictionary) -> Dictionary:
	var inp := normalize(input)
	var p: String = inp["process"]
	var mk: String = inp["machine_kind"]
	var m := machine_def(p, mk)
	var kind: String = inp["work_kind"]
	var disc: Dictionary = DISCS[inp["disc_id"]]
	var grinder := p == "grinder"
	# Carga del motor: la potencia de corte y, en la radial, el roce extra del disco mientras corta
	var cut_load := Contact.clamp_js(float(inp["pc_kw"]) / float(inp["pmax_kw"]), 0.0, LOAD_MAX)
	var cutting := cut_load > 0.0
	var load := cut_load
	if grinder and cutting:
		load = minf(LOAD_MAX, cut_load + float(disc["drag"]))
	# Giro real: el motor cae bajo carga (en la radial se oye cómo «se ahoga» el disco). Nunca por debajo de 0,
	# aunque una caída grande y una sobrecarga lo pidieran.
	var rpm_cmd: float = inp["rpm"]
	var rpm: float = rpm_cmd * maxf(0.0, 1.0 - float(inp["speed_droop"]) * load)
	var f_rot := rpm / 60.0
	var speed := Contact.clamp_js(rpm / float(m["rpm_ref"]), 0.0, SPEED_MAX)
	var vc: float = inp["vc"]
	if vc < 0.0:
		vc = PI * float(inp["diameter_mm"]) * rpm / 1000.0  # m/min
	var fade := Contact.smoothstep(0.0, 0.05, cut_load)  # el corte entra sin escalón
	var sq_load := sqrt(cut_load)
	var tones: Array = []

	# Motor: zumbido magnético a 2·f de red y múltiplos pares (la radial, motor universal, lo tiene más débil)
	var on := Contact.smoothstep(0.0, MOTOR_ON_RPM, rpm_cmd)
	var g_motor := G_MOTOR * float(m["motor_gain"]) * on * (1.0 + MOTOR_LOAD_BOOST * minf(load, 1.0))
	for h in MOTOR_HUM:
		tones.append(_tone(h[0], "motor", float(h[1]) * float(inp["mains_hz"]), g_motor * float(h[2])))

	# Husillo: todo lo que gira con él (1×, 2×, engranes, rotor y ventilador de la radial)
	var g_spindle := float(m["spindle_gain"]) * pow(speed, float(m["speed_exp"]))
	for c in m["spindle"]:
		tones.append(_tone(c[0], "spindle", float(c[1]) * f_rot, g_spindle * float(c[2])))

	# Paso de garras, dientes o segmentos
	var pass_kind: String = m["pass"]
	var count: int = inp["pass_count"]
	if pass_kind != "" and count > 0:
		var ps: Dictionary = PASS[pass_kind]
		var g_pass := float(ps["air"]) * pow(minf(speed, 1.6), 3.0) + float(ps["cut"]) * sq_load * fade
		tones.append(_tone(pass_kind + "_pass", "pass", count * f_rot, g_pass))

	# Chapa que vibra (radial sobre chapa; sheet_mm = 0: una pieza maciza, sin chapa)
	if grinder and SHEET.has(kind) and float(inp["sheet_mm"]) > 0.0:
		var sh: Dictionary = SHEET[kind]
		var thin := Contact.clamp_js(sqrt(float(sh["h_mm"]) / maxf(0.1, float(inp["sheet_mm"]))), 0.5, 2.0)
		var g_sheet := G_SHEET * float(sh["ring"]) * float(disc["sheet"]) * thin * sq_load * fade
		var hz_sheet := sheet_key_hz() * sheet_scale(kind, float(inp["sheet_mm"]))
		tones.append(_tone("sheet_ring", "sheet", hz_sheet, g_sheet))

	# Refrigerante (la bomba; la afiladora húmeda lenta no la tiene: su agua suena en el roce de la piedra)
	var coolant_gain := G_COOLANT if bool(inp["coolant"]) and bool(m.get("pump", true)) else 0.0
	for c in COOLANT:
		tones.append(_tone(c[0], "coolant", float(c[1]) * COOLANT_PUMP_HZ, coolant_gain * float(c[2])))

	# Banda de ruido del corte y crujido
	var noise := {}
	var crackle_rate := 0.0
	var crackle_gain := 0.0
	if grinder:
		# Radial: ficha propia (chapa) o la general con la banda más alta; el disco se aplica siempre
		var vfac := Contact.clamp_js(sqrt(vc / GRINDER_VC_REF), 0.6, 1.6)
		var gk: Dictionary = GRINDER_KIND[kind] if GRINDER_KIND.has(kind) else {}
		var k0: Dictionary = KIND[kind]
		var fc0: float = gk["fc"] if not gk.is_empty() else float(k0["fc"]) * GRINDER_FALLBACK_FC
		var q0: float = gk["q"] if not gk.is_empty() else float(k0["q"])
		var gain0: float = gk["gain"] if not gk.is_empty() else float(k0["gain"])
		var lp0: float = gk["lp_hz"] if not gk.is_empty() else float(k0["lp_hz"])
		# Chispas o esquirlas por segundo a plena carga: de la ficha de radial o, si no hay, las de romper viruta
		var sparks: float = gk["sparks"] if not gk.is_empty() else _chip_break_rate(k0, vc)
		noise = { "fc_hz": fc0 * float(disc["fc"]) * vfac, "q": q0 * float(disc["q"]),
			"gain": G_CUT * gain0 * float(disc["gain"]) * sq_load * fade, "lp_hz": lp0 }
		crackle_rate = minf(CRACKLE_RATE_MAX, sparks * float(disc["crackle"]) * minf(cut_load, 1.0)) * fade
		crackle_gain = G_CHIP * sq_load * (1.0 if sparks > 0.0 else 0.0)
	elif m.has("grind"):
		# Afiladora: el ruido de amolado de la muela (banda de la máquina, que sube con la velocidad periférica) y
		# el crujido de las chispas, proporcional a la carga; en húmedo no hay chispas. En la combinada, grind_kind
		# da la banda de la muela con la que se trabaja (la piedra húmeda: «humeda_lenta»)
		var gk_name: String = inp["grind_kind"]
		var gr: Dictionary = (machine_def(p, gk_name) if gk_name != "" else m)["grind"]
		var vfac3 := Contact.clamp_js(sqrt(maxf(vc, 0.0) / float(gr["vc_ref"])), 0.6, 1.6)
		noise = { "fc_hz": float(gr["fc"]) * vfac3, "q": float(gr["q"]),
			"gain": G_CUT * float(gr["gain"]) * sq_load * fade, "lp_hz": float(gr["lp_hz"]) }
		var sparks_g: float = gr["sparks"]
		crackle_rate = minf(CRACKLE_RATE_MAX, sparks_g * minf(cut_load, 1.0)) * fade
		crackle_gain = G_CHIP * sq_load * (1.0 if sparks_g > 0.0 else 0.0)
	else:
		var k: Dictionary = KIND[kind]
		var vfac2 := Contact.clamp_js(sqrt(maxf(vc, 0.0) / float(k["vc_ref"])), 0.6, 1.6)
		noise = { "fc_hz": float(k["fc"]) * vfac2, "q": float(k["q"]),
			"gain": G_CUT * float(k["gain"]) * sq_load * fade, "lp_hz": float(k["lp_hz"]) }
		crackle_rate = _chip_break_rate(k, vc) * fade
		crackle_gain = G_CHIP * sq_load
	noise["fc_hz"] = Contact.clamp_js(float(noise["fc_hz"]), CUT_FC_MIN, CUT_FC_MAX)
	if not cutting:
		crackle_rate = 0.0
		crackle_gain = 0.0

	# Chatter: solo mientras corta y con la profundidad por encima de la de estabilidad
	var chatter := { "hz": 0.0, "gain": 0.0, "mod_hz": 0.0, "depth": 0.0 }
	var ch: Variant = inp["chatter"]
	if ch != null and cutting:
		# Periodo entre cortes: el paso de dientes en fresa y taladro; en el torno, una vuelta
		var f_tp := f_rot * (count if pass_kind == "teeth" and count > 0 else 1)
		chatter = { "hz": float(ch["mode_hz"]) * sqrt(1.0 + 2.0 * CHATTER_ZETA),
			"gain": G_CHATTER * Contact.smoothstep(1.0, 1.5, float(ch["risk"])) * fade,
			"mod_hz": f_tp, "depth": CHATTER_DEPTH }

	# Roce de la piedra húmeda: suena con la piedra girando, toque o no la herramienta; crece con el giro y late
	# una vez por vuelta (el bucle se mueve con pitch_scale = rpm/rpm_ref). En la combinada, la piedra reducida
	# (stone_rpm) suena igual que la de la afiladora lenta y sigue la caída de giro del motor.
	var rub := { "gain": 0.0, "pitch": 1.0 }
	var rub_level := float(m.get("rub", 0.0))
	var rub_speed := speed
	var rub_ratio := rpm / float(m["rpm_ref"])
	if rub_level <= 0.0 and float(inp["stone_rpm"]) > 0.0:
		var slow: Dictionary = SHARPENERS["humeda_lenta"]
		rub_level = float(slow["rub"])
		rub_ratio = float(inp["stone_rpm"]) * (rpm / rpm_cmd if rpm_cmd > 0.0 else 0.0) / float(slow["rpm_ref"])
		rub_speed = Contact.clamp_js(rub_ratio, 0.0, SPEED_MAX)
	if rub_level > 0.0:
		rub = { "gain": G_RUB * rub_level * on * rub_speed,
			"pitch": Contact.clamp_js(rub_ratio, RUB_PITCH.x, RUB_PITCH.y) }

	var pos: Vector3 = inp["tool_pos"]
	return {
		"process": p, "rpm": rpm, "load": load, "vc": vc, "disc_id": inp["disc_id"], "work_kind": kind,
		"machine_kind": mk,
		"tones": tones,
		"noise": noise,
		"crackle_rate": crackle_rate,
		"crackle_gain": crackle_gain,
		"chatter": chatter,
		"coolant_gain": coolant_gain,
		"rub": rub,
		"master_gain": pow(10.0, LEVEL_COMPRESS * (float(m["level_db"]) - LEVEL_REF_DB) / 20.0),
		"pan": Contact.clamp_js(pos.x / PAN_HALF_M, -1.0, 1.0),
	}


## Rotura de viruta (1/s): la viruta sale a vc/λ y se rompe cada chip_mm; acotada a CRACKLE_RATE_MAX.
static func _chip_break_rate(k: Dictionary, vc: float) -> float:
	var v_chip := (maxf(vc, 0.0) / 60.0) / float(k["lambda"])  # m/s
	return minf(CRACKLE_RATE_MAX, v_chip / (float(k["chip_mm"]) / 1000.0))


static func _tone(name: String, layer: String, hz: float, gain: float) -> Dictionary:
	return { "name": name, "layer": layer, "hz": hz, "gain": gain }


## Bucle de cada capa en un proceso dado (y, en la afiladora, en su variante).
static func layer_loop(layer: String, process: String, machine_kind: String = "") -> String:
	match layer:
		"motor":
			return "motor"
		"spindle":
			return str(machine_def(process, machine_kind)["loop"])
		"pass":
			var pk: String = machine_def(process, machine_kind)["pass"]
			return PASS[pk]["loop"] if PASS.has(pk) else ""
		"sheet":
			return "sheet"
		"coolant":
			return "coolant"
	return ""


## Capa del marco que representa un bucle («» si el bucle no sale de una capa: corte, chatter y crujido).
static func loop_layer(loop: String) -> String:
	if loop.begins_with("spindle_"):
		return "spindle"
	match loop:
		"motor", "sheet", "coolant":
			return loop
		"jaws", "teeth", "segments":
			return "pass"
	return ""


## Traduce un marco a las voces que suenan: { voz: { loop, pitch, volume } } más «bus» (filtros del corte) y
## «grains» (granos). pitch = hz del tono clave / loop_ref_hz; volume = master · ganancia / level · HEADROOM_GAIN.
## El corte es ruido rosa que filtra el bus «MaquinaCorte»: un paso banda de Godot con Q = 2·resonance y
## ganancia de pico √(Q+1) deja pasar, del ruido rosa de banda [lo, hi], la fracción de potencia
## π(Q+1)/(2Q·ln(hi/lo)) (ancho de banda equivalente πfc/2Q; medido con Movie Maker, ver fuentes-u8.md).
static func voices(fr: Dictionary) -> Dictionary:
	var master: float = float(fr["master_gain"]) * HEADROOM_GAIN
	var process: String = fr["process"]
	var mk := str(fr.get("machine_kind", ""))
	var out := {}
	var seen := {}
	for t in fr["tones"]:
		var layer: String = t["layer"]
		if seen.has(layer):
			continue
		seen[layer] = true
		var loop := layer_loop(layer, process, mk)
		if loop == "":
			continue
		var level: float = LOOPS[loop]["level"]
		out[layer] = { "loop": loop, "pitch": _pitch(float(t["hz"]), loop_ref_hz(loop)),
			"volume": master * float(t["gain"]) / level }
	# Corte
	var nz: Dictionary = fr["noise"]
	var q: float = maxf(0.05, float(nz["q"]))
	var cut: Dictionary = LOOPS["cut"]
	var passed := sqrt(PI * (q + 1.0) / (2.0 * q * log(float(cut["band_hi"]) / float(cut["band_lo"]))))
	out["cut"] = { "loop": "cut", "pitch": 1.0, "volume": master * float(nz["gain"]) / (float(cut["level"]) * passed) }
	out["bus"] = { "cut_hz": float(nz["fc_hz"]), "cut_resonance": q / 2.0, "cut_lp_hz": float(nz["lp_hz"]) }
	# Chatter: tono en f_c y dos bandas laterales a ±f_tp que baten con él
	var chv: Dictionary = fr["chatter"]
	var ch_ref := loop_ref_hz("chatter")
	var g_c: float = master * float(chv["gain"]) / float(LOOPS["chatter"]["level"])
	var f_c: float = chv["hz"]
	var f_m: float = chv["mod_hz"]
	var side := g_c * float(chv["depth"]) * 0.5 if f_m > 0.0 and f_m < f_c * 0.5 else 0.0
	out["chatter"] = { "loop": "chatter", "pitch": _pitch(f_c, ch_ref), "volume": g_c }
	out["chatter_lo"] = { "loop": "chatter", "pitch": _pitch(f_c - f_m, ch_ref), "volume": side }
	out["chatter_hi"] = { "loop": "chatter", "pitch": _pitch(f_c + f_m, ch_ref), "volume": side }
	# Crujido: granos sueltos hasta GRAIN_RATE_MAX por segundo y, por encima, el bucle de crujido denso
	var rate: float = fr["crackle_rate"]
	var cg: float = fr["crackle_gain"]
	var crackle: Dictionary = LOOPS["crackle"]
	var dense := sqrt(maxf(0.0, rate - GRAIN_RATE_MAX) / float(crackle["rate"]))
	out["crackle"] = { "loop": "crackle", "pitch": 1.0, "volume": master * cg * 0.35 * dense / float(crackle["level"]) }
	out["grains"] = { "rate": minf(rate, GRAIN_RATE_MAX), "volume": master * cg / CHIP_PEAK }
	# Roce de la piedra húmeda: ruido sin tono clave; su pitch_scale sigue al giro de la piedra
	var rub: Dictionary = fr.get("rub", {})
	out["rub"] = { "loop": "stone_rub", "pitch": float(rub.get("pitch", 1.0)),
		"volume": master * float(rub.get("gain", 0.0)) / float(LOOPS["stone_rub"]["level"]) }
	return out


## Frecuencia del tono clave de un bucle (Hz; 0 si es ruido sin tono): el primer tono de su capa en el marco de
## su entrada de referencia (la chapa, su modo más grave; el chatter, su tono genérico). Se calcula una vez y se
## guarda con el cerrojo (seguro para hilos).
static func loop_ref_hz(loop: String) -> float:
	_cache_lock.lock()
	var cached: Variant = _ref_hz.get(loop)
	_cache_lock.unlock()
	if cached != null:
		return cached
	var hz := _loop_ref_hz_uncached(loop)
	_cache_lock.lock()
	_ref_hz[loop] = hz
	_cache_lock.unlock()
	return hz


static func _loop_ref_hz_uncached(loop: String) -> float:
	if loop == "sheet":
		return sheet_key_hz()
	if LOOPS.has(loop) and LOOPS[loop].has("ref_hz"):
		return float(LOOPS[loop]["ref_hz"])
	if loop_layer(loop) != "":
		for t in frame(reference_input(loop))["tones"]:
			if t["layer"] == loop_layer(loop):
				return t["hz"]
	return 0.0


## Vacía las cachés (solo para los tests: comprueban que varios hilos a la vez calculan lo mismo que uno).
static func clear_caches() -> void:
	_cache_lock.lock()
	_sheet_key_hz = 0.0
	_ref_hz = {}
	_cache_lock.unlock()


static func _pitch(hz: float, ref: float) -> float:
	if ref <= 0.0:
		return 1.0
	return maxf(0.01, hz / ref)


# ── Chapa ──


## Velocidad de las ondas de flexión de referencia c_p = √(E/(ρ(1−ν²))) (m/s) de un material de SHEET.
static func plate_speed(kind: String) -> float:
	var s: Dictionary = SHEET[kind]
	return sqrt(float(s["e_gpa"]) * 1e9 / (float(s["rho"]) * (1.0 - float(s["nu"]) * float(s["nu"]))))


## Frecuencia (Hz) del modo (m, n) de una placa apoyada de a × b mm y h mm del material kind (Kirchhoff).
static func plate_mode_hz(m: int, n: int, h_mm: float, a_mm: float, b_mm: float, kind: String) -> float:
	var h := h_mm / 1000.0
	var a := a_mm / 1000.0
	var b := b_mm / 1000.0
	var k := PI / 2.0 * h / sqrt(12.0) * plate_speed(kind)  # (π/2)·√(D/(ρh)) = (π/2)·h·c_p/√12
	return k * (pow(m / a, 2.0) + pow(n / b, 2.0))


## Modos impar-impar del panel de referencia entre f_lo y f_hi, ordenados por frecuencia: [[m, n, hz], …].
static func sheet_modes() -> Array:
	var r: Dictionary = SHEET_REF
	var kind: String = r["kind"]
	var h: float = SHEET[kind]["h_mm"]
	var out: Array = []
	for m in range(1, 40, 2):
		for n in range(1, 40, 2):
			var f := plate_mode_hz(m, n, h, r["a_mm"], r["b_mm"], kind)
			if f >= float(r["f_lo"]) and f <= float(r["f_hi"]):
				out.append([m, n, f])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[2] < y[2])
	return out


## Frecuencia del modo clave (el más grave de sheet_modes) del panel de referencia. Se calcula una vez: solo
## depende de constantes, y frame() la pide 60 veces por segundo. Caché con cerrojo (seguro para hilos).
static func sheet_key_hz() -> float:
	_cache_lock.lock()
	var hz := _sheet_key_hz
	_cache_lock.unlock()
	if hz == 0.0:
		hz = float(sheet_modes()[0][2])
		_cache_lock.lock()
		_sheet_key_hz = hz
		_cache_lock.unlock()
	return hz


## Cuánto suben los modos de una chapa de kind y h_mm respecto al panel de referencia: h·c_p / (h_ref·c_p,ref).
static func sheet_scale(kind: String, h_mm: float) -> float:
	var ref: String = SHEET_REF["kind"]
	return (h_mm * plate_speed(kind)) / (float(SHEET[ref]["h_mm"]) * plate_speed(ref))


## Entrada de referencia de un bucle horneado: el horneado toma las frecuencias y proporciones del marco de
## esta entrada, y loop_ref_hz() su tono clave.
static func reference_input(loop: String) -> Dictionary:
	match loop:
		"spindle_lathe", "jaws", "motor":
			return { "process": "lathe", "rpm": 1200.0, "jaws": 3 }
		"spindle_mill", "teeth":
			return { "process": "mill", "rpm": 3000.0, "teeth": 4 }
		"spindle_drill":
			return { "process": "drill", "rpm": 1000.0, "teeth": 2 }
		"spindle_grinder", "segments":
			return { "process": "grinder", "rpm": 11000.0, "disc_id": "diamante" }
		"spindle_sharpener":
			return { "process": "sharpener", "machine_kind": "banco", "rpm": 2950.0 }
		"spindle_compact":
			return { "process": "sharpener", "machine_kind": "afilabrocas", "rpm": 4400.0 }
		"stone_rub":
			return { "process": "sharpener", "machine_kind": "humeda_lenta", "rpm": 100.0 }
		"coolant":
			return { "process": "lathe", "rpm": 1200.0, "coolant": true }
	return { "process": "lathe", "rpm": 1200.0 }
