## Tribología biológica · afilado de las garras experimentales (modelo 2.0, unidad 4e). Funciones puras, sin estado.
##
## Una garra «reforjada» en otro material (Data.INLAYS) conserva la forma de la garra: el material cambia la dureza y el
## módulo, no la geometría (Physics.resolve_tool). El afilado sí cambia la geometría: el radio R de la esfera del ápice de
## la punta esfero-cónica del motor (Contact.tip_geometry). El semiángulo α del cono sigue siendo el de la garra.
##   1. Límites medidos. De la punta de la garra (la de su ficha) al filo más fino medido en acero, el de una hoja de
##      afeitar: 40 nm de radio (Roscioli et al. 2020). Por el camino, marcas medidas (REFERENCES): el filo de un cuchillo
##      afilado a mano y pulido con diamante, la punta del aguijón de la abeja, las microagujas y el cono del Rockwell. El
##      afilado s ∈ [0, 1] recorre el intervalo en escala logarítmica: R(s) = R0·(R_min/R0)^s.
##   2. Más presión con la misma fuerza. Contacto elástico (Hertz, el del motor): p0 = (6·F·E*²/(π³·R²))^(1/3) ∝ R^(−2/3),
##      y la fuerza con la que el material empieza a ceder (p0 = 1,6·Y, Johnson; Y = H/2,8, Tabor) baja con R². Contacto
##      plástico: la presión media no pasa de la dureza H, así que lo que gana una punta afilada es hondura: la huella de
##      radio a = √(F/(π·H)) cabe más honda. Con poca fuerza (la huella en la esfera) la hondura crece como 1/R; con mucha,
##      la huella está en el cono y el afilado importa menos.
##   3. Pero una punta afilada se rompe antes. De frente, una punta más dura que lo que pincha está en compresión y no se
##      rompe (unidad 4d); la rompe la carga lateral, la fricción μ·F al rayar. La punta, una viga en voladizo (el mellado
##      de la unidad 1f, Fracture.tip_chip_load, y la rotura de la 4d, claw_fracture.gd): σ(x) = 4·F·(x − x0)/(π·r(x)³),
##      con la carga a x0 del vértice. En el cono, r = tan α·(x + d) con d = R·(1 − sen α)/sen α, y la sección más cargada
##      está en x* = d/2 + 1,5·x0 (nunca dentro de la esfera: desde h_t). Con la carga en el vértice y α ≤ 30°:
##      F_mella = σ·(27π/16)·R²·sen α·(1 − sen α)²/cos³α. La carga que aguanta la punta crece con R²: afilada a la mitad,
##      aguanta la cuarta parte (para no romperse, el diámetro de la punta tiene que crecer con la raíz de la carga:
##      Pattrick et al. 2018). Los frágiles se mellan con su resistencia a flexión medida; los dúctiles se doblan con su
##      tensión de flujo, H/2,8 (Tabor).
##   4. La tenacidad K_Ic dice cuándo vale la resistencia medida. La distancia crítica L = (K_Ic/σ_f)²/π (Taylor 2007) es
##      el orden del defecto que rompe la probeta de flexión. Si la sección más cargada de la punta es más pequeña que L,
##      no cabe ese defecto: la punta aguanta más de lo que dice σ_f (efecto de escala) y el modelo se queda del lado
##      seguro. Si es mucho mayor, σ_f manda. Así, un diamante afilado a 1 µm (L ≈ 0,5 µm) se mella de verdad, y un vidrio
##      afilado a 1 µm (L ≈ 90 µm) aguantaría bastante más de lo que dice el modelo.
## La resistencia es la de claw_fracture.gd (unidad 4d): strength_of(inlay) = ClawFracture.strength(inlay), el diccionario
## { value, min, max (MPa), kind («flexion» | «fluencia»), kic (MPa·√m o null), quality, source }; null con la queratina
## («none»), sin datos (la hematites) o un material desconocido. Las funciones reciben ese diccionario como parámetro, y
## los casos de referencia llevan los mismos valores (un test lo comprueba).
## Qué no predice: el efecto de escala en números (solo lo señala), cómo se desgasta o se embota la punta con el uso, la
## curvatura y la sección aplanada de una garra real, las puntas de más de 30° de semiángulo (el máximo de la viga cae
## dentro de la esfera, donde el contacto reparte la carga) ni el afilado del semiángulo, que se deja como el de la garra.
## Unidades: fuerza N · longitudes mm (radios de punta en µm) · presiones y resistencias MPa · E en GPa · K en MPa·√m.
## Uso: const ClawSharpness = preload("res://core/lab/claw_sharpness.gd").
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Insects = preload("res://core/lab/insects.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")

# ── Fuentes ──
const SRC_ROSCIOLI := "Roscioli G, Taheri-Mousavi SM, Tasan CC (2020). How hair deforms steel. Science 369:689-694. doi:10.1126/science.aba9490 (hoja de afeitar de acero martensítico: cuña de 17° y radio de punta de 40 nm, citando a McCarthy, Hussey & Gilchrist 2007, Eng. Fract. Mech. 74:2205; 8,7 GPa de dureza, ~50 veces la del pelo, y aun así se mella al cortarlo)"
const SRC_VERHOEVEN := "Verhoeven JD (2004). Experiments on knife sharpening. Iowa State University (anchura del filo en la vista de canto al microscopio electrónico: 0,23-0,40 µm, media 0,31 ± 0,06, tras pulir con diamante de 1 µm en cuero, tabla 6; hoja Gillette 0,32; 1-1,5 µm con la muela de grano 1000 en húmedo, apartado 2)"
const SRC_DAVIS := "Davis SP, Landis BJ, Adams ZH, Allen MG, Prausnitz MR (2004). Insertion of microneedles into skin: measurement and prediction of insertion force and needle fracture force. J. Biomech. 37:1155-1163. doi:10.1016/j.jbiomech.2003.12.010 (radios de punta de 30-80 µm; de frente, el margen entre romper la aguja y perforar la piel crece al afilar la punta)"
const SRC_ISO_6508 := "ISO 6508-2 (Rockwell): cono de diamante de 120° y radio de 0,2 mm"
const SRC_PATTRICK := "Pattrick JG, Labonte D, Federle W (2018). Scaling of claw sharpness: mechanical constraints reduce attachment performance in larger insects. J. Exp. Biol. 221:jeb188391. doi:10.1242/jeb.188391 (una punta más afilada engancha más pero se rompe antes: con la tensión constante, la carga de rotura crece con el cuadrado del diámetro de la punta)"
const SRC_TAYLOR := "Taylor D (2007). The Theory of Critical Distances: A New Perspective in Fracture Mechanics. Elsevier (L = (1/π)·(K_c/σ_0)², la longitud del material que separa el régimen de la resistencia del de la tenacidad)"
const SRC_TABOR := "Tabor D (1951). The Hardness of Metals. Oxford, Clarendon Press: H ≈ 2,8·σ_flujo (la constante de Tabor que usa el motor del banco)"
const SRC_JOHNSON := "Johnson KL (1985). Contact Mechanics. Cambridge University Press (Hertz; bajo una esfera el material empieza a ceder cuando p0 = 1,6·Y, el umbral que usa el motor del banco)"

## El filo más fino medido en acero (µm de radio): el de una hoja de afeitar (Roscioli et al. 2020). Es el extremo del
## afilado s = 1.
const SHARPEST_UM := 0.04

## Marcas de referencia del afilado, de la más fina a la más roma: radio de la punta (µm) con su banda. kind: «filo» (una
## arista, como la de un cuchillo) o «punta» (un vértice, como el de una garra). En los filos de Verhoeven se toma como
## radio la mitad de la anchura del filo (suposición: filo redondeado).
const REFERENCES := [
	{ "id": "cuchilla", "name": "Hoja de afeitar", "kind": "filo", "tipRadiusUm": SHARPEST_UM, "min": SHARPEST_UM, "max": SHARPEST_UM, "quality": "secondary", "source": SRC_ROSCIOLI },
	{ "id": "filo_diamante", "name": "Cuchillo pulido con diamante", "kind": "filo", "tipRadiusUm": 0.155, "min": 0.115, "max": 0.2, "quality": "secondary", "source": SRC_VERHOEVEN + " · radio = anchura/2" },
	{ "id": "filo_grano_1000", "name": "Cuchillo afilado con grano 1000", "kind": "filo", "tipRadiusUm": 0.625, "min": 0.5, "max": 0.75, "quality": "secondary", "source": SRC_VERHOEVEN + " · radio = anchura/2" },
	{ "id": "aguijon_abeja", "name": "Aguijón de abeja", "kind": "punta", "tipRadiusUm": Insects.BEE_TIP_MM * 1000.0, "min": 1.0, "max": 1.5, "quality": "secondary", "source": Insects.SRC_LING_2017 + " (1-1,5 µm, microscopio electrónico de la abeja asiática)" },
	{ "id": "microaguja", "name": "Microagujas", "kind": "punta", "tipRadiusUm": 49.0, "min": 30.0, "max": 80.0, "quality": "primary", "source": SRC_DAVIS + " · la marca es el centro geométrico de la banda (dibujo)" },
	{ "id": "rockwell", "name": "Cono de diamante del Rockwell", "kind": "punta", "tipRadiusUm": 200.0, "min": 200.0, "max": 200.0, "quality": "primary", "source": SRC_ISO_6508 },
]


# ════════ 1. Geometría del afilado ════════

## Radio de la punta (µm) de un área de punta del motor (mm²): √(área/π).
static func radius_um_of_area(area_mm2: float) -> float:
	return sqrt(area_mm2 / PI) * 1000.0


## Área de la punta (mm²) de un radio (µm): π·R².
static func area_of_radius_um(r_um: float) -> float:
	var r := r_um / 1000.0
	return PI * r * r


## Radio de la punta (µm) con el afilado s ∈ [0, 1], desde el natural r0_um: R0·(R_min/R0)^s. Una punta que ya es más
## fina que el extremo medido no se afila más.
static func radius_at(r0_um: float, s: float) -> float:
	var t := Contact.clamp_js(s, 0.0, 1.0)
	if r0_um <= SHARPEST_UM or t <= 0.0:
		return r0_um
	return r0_um * V8.js_pow(SHARPEST_UM / r0_um, t)


## Afilado s ∈ [0, 1] que lleva la punta de r0_um a r_um (inversa de radius_at).
static func sharpness_for(r0_um: float, r_um: float) -> float:
	if r0_um <= SHARPEST_UM or r_um >= r0_um:
		return 0.0
	if r_um <= SHARPEST_UM:
		return 1.0
	return V8.js_log(r_um / r0_um) / V8.js_log(SHARPEST_UM / r0_um)


## La forma afilada de una garra (o de su punta: un diccionario con area y alpha): una copia con el área nueva y
## { tipRadiusUm, naturalTipRadiusUm, sharpness }. El semiángulo no cambia. Sin afilar, el área es la misma al bit (el
## ensayo da lo mismo que con la garra de siempre).
static func sharpen(shape: Dictionary, s: float) -> Dictionary:
	var out := shape.duplicate(true)
	var r0 := radius_um_of_area(float(shape.area))
	var r := radius_at(r0, s)
	out["area"] = area_of_radius_um(r) if r < r0 else float(shape.area)
	out["tipRadiusUm"] = r
	out["naturalTipRadiusUm"] = r0
	out["sharpness"] = Contact.clamp_js(s, 0.0, 1.0) if r < r0 else 0.0
	return out


## Punta esfero-cónica del motor (Contact.tip_geometry) de radio r_um (µm) y semiángulo alpha_deg.
static func tip_of(r_um: float, alpha_deg: float) -> Dictionary:
	return Contact.tip_geometry(area_of_radius_um(r_um), alpha_deg)


# ════════ 2. Presión y hondura con la misma fuerza ════════

## Módulo efectivo de Hertz (MPa) del motor: 1/E* = (1 − ν²)·(1/E_punta + 1/E_material), con ν = 0,3 (Contact).
static func estar_mpa(e_tool_gpa: float, e_target_gpa: float) -> float:
	var nu: float = Contact.CONTACT["nu"]
	return 1000.0 / ((1.0 - nu * nu) * (1.0 / e_tool_gpa + 1.0 / e_target_gpa))


## Presión de pico elástica (MPa) con la fuerza f_n y la punta de radio r_um: la de Contact.plastic_fraction (el motor).
static func hertz_peak_mpa(f_n: float, r_um: float, e_tool_gpa: float, e_target_gpa: float) -> float:
	return float(Contact.plastic_fraction(f_n, r_um / 1000.0, e_tool_gpa, e_target_gpa, 1.0).p0)


## Fuerza (N) con la que el material de dureza h_mpa empieza a ceder bajo la punta de radio r_um: p0 = 1,6·H/2,8,
## F = π³·R²·p0³/(6·E*²). Crece con R²: una punta afilada marca con mucha menos fuerza.
static func yield_onset_n(r_um: float, e_tool_gpa: float, e_target_gpa: float, h_mpa: float) -> float:
	var r := r_um / 1000.0
	var es := estar_mpa(e_tool_gpa, e_target_gpa)
	var p0: float = Contact.CONTACT["yieldOnset"] * h_mpa / Contact.CONTACT["tabor"]
	return PI * PI * PI * r * r * p0 * p0 * p0 / (6.0 * es * es)


## Cuánto sube la presión de pico elástica al pasar de r0_um a r_um con la misma fuerza: (R0/R)^(2/3).
static func pressure_gain(r0_um: float, r_um: float) -> float:
	return V8.js_pow(r0_um / r_um, 2.0 / 3.0)


## Hondura (µm) de una huella totalmente plástica: la presión media es la dureza h_mpa, el radio de la huella es
## a = √(F/(π·H)) y la hondura, la de la punta con ese radio (Contact.depth_for_radius). Estimación de referencia: el
## motor afina con la eficiencia de la dureza y la fracción plástica.
static func plastic_depth_um(r_um: float, alpha_deg: float, f_n: float, h_mpa: float) -> float:
	if f_n <= 0.0 or h_mpa <= 0.0:
		return 0.0
	var a := sqrt(f_n / (PI * h_mpa))
	return Contact.depth_for_radius(tip_of(r_um, alpha_deg), a) * 1000.0


# ════════ 3. Mellado o doblado de la punta ════════

## Sección más cargada de la punta con una carga lateral a x0_mm del vértice: { factor (MPa por N), xMm, rMm }. En el
## cono, (x − x0)/r³ es máxima en x* = (a_t − h_t·tan α)/(2·tan α) + 1,5·x0 (la de claw_fracture.gd); no se busca dentro
## de la esfera (antes de h_t el contacto reparte la carga, como en Fracture.tip_chip_load).
static func peak(tip: Dictionary, x0_mm: float = 0.0) -> Dictionary:
	var t: float = tip.tanA
	var x0 := maxf(x0_mm, 0.0)
	var lo := maxf(maxf(float(tip.ht), 1e-12), x0)
	var x := maxf((float(tip.at) - float(tip.ht) * t) / (2.0 * t) + 1.5 * x0, lo) if t > 0.0 else lo
	var r := Contact.contact_radius(tip, x)
	var f := (4.0 * (x - x0)) / (PI * r * r * r) if r > 0.0 else 0.0
	return { "factor": f, "xMm": x, "rMm": r }


## Carga lateral (N) con la que la sección más cargada llega a la tensión sigma_mpa.
static func chip_load_n(tip: Dictionary, sigma_mpa: float, x0_mm: float = 0.0) -> float:
	var f: float = peak(tip, x0_mm).factor
	return sigma_mpa / f if f > 0.0 else INF


## La fórmula cerrada con la carga en el vértice y α ≤ 30°: F = σ·(27π/16)·R²·sen α·(1 − sen α)²/cos³α (R en mm).
static func chip_load_closed_n(r_um: float, alpha_deg: float, sigma_mpa: float) -> float:
	var r := r_um / 1000.0
	var s := V8.js_sin(alpha_deg * Contact.DEG)
	var c := V8.js_cos(alpha_deg * Contact.DEG)
	return sigma_mpa * (27.0 * PI / 16.0) * r * r * s * (1.0 - s) * (1.0 - s) / (c * c * c)


## La punta más fina (radio en µm) que aguanta una carga lateral lateral_n en el vértice con la tensión sigma_mpa: como la
## carga que aguanta crece con R², R = √(F/(σ·k)), con k la carga que aguanta una punta de 1 mm con 1 MPa.
static func sharpest_surviving_um(alpha_deg: float, sigma_mpa: float, lateral_n: float) -> float:
	if lateral_n <= 0.0:
		return 0.0
	var k := chip_load_n(tip_of(1000.0, alpha_deg), 1.0)
	return sqrt(lateral_n / (sigma_mpa * k)) * 1000.0


## Resistencia del material de una garra reforjada (entrada de Data.INLAYS o su id): la de claw_fracture.gd (unidad 4d),
## o null con la queratina, sin datos o un material desconocido.
static func strength_of(inlay: Variant) -> Variant:
	return ClawFracture.strength(inlay)


## evaluate() con la resistencia del material de la garra (strength_of).
static func evaluate_inlay(tip: Dictionary, inlay: Variant, lateral_n: float, x0_mm: float = 0.0) -> Dictionary:
	return evaluate(tip, strength_of(inlay), lateral_n, x0_mm)


## Distancia crítica (µm) de un material: L = (K_Ic/σ)²/π (Taylor 2007). null sin tenacidad.
static func critical_distance_um(kic: Variant, sigma_mpa: float) -> Variant:
	if kic == null or sigma_mpa <= 0.0:
		return null
	var q := float(kic) / sigma_mpa
	return q * q / PI * 1.0e6


## ¿Aguanta la punta una carga lateral? tip: la punta (tip_of o Contact.tip_geometry); strength: el diccionario de
## ClawFracture.strength() o null (sin datos); lateral_n: la carga lateral (N); x0_mm: dónde empuja (0 en el vértice).
## { chipN, chipMinN, chipMaxN, lateralN, stressMPa, fails, breaks (frágil), bends (dúctil), failsLo, failsHi (con la
##   resistencia mínima y la máxima), mode («intacta» | «mella» | «dobla» | «sin_datos»), peakXUm, peakRUm, criticalUm,
##   sizeEffect (la sección más cargada es más pequeña que la distancia crítica: el modelo se queda del lado seguro),
##   quality, source }.
static func evaluate(tip: Dictionary, strength: Variant, lateral_n: float, x0_mm: float = 0.0) -> Dictionary:
	var lat := maxf(lateral_n, 0.0)
	var pk := peak(tip, x0_mm)
	var out := {
		"chipN": null, "chipMinN": null, "chipMaxN": null, "lateralN": lat, "stressMPa": lat * float(pk.factor),
		"fails": false, "breaks": false, "bends": false, "failsLo": false, "failsHi": false, "mode": "sin_datos",
		"peakXUm": float(pk.xMm) * 1000.0, "peakRUm": float(pk.rMm) * 1000.0, "criticalUm": null, "sizeEffect": false,
		"quality": null, "source": null,
	}
	if strength == null:
		return out
	var f: float = pk.factor
	var sv := float(strength.value)
	var smin := float(strength.get("min", sv))
	var smax := float(strength.get("max", sv))
	var stress := lat * f
	var fails := lat > 0.0 and stress >= sv
	var brittle: bool = strength.get("kind", "flexion") == "flexion"
	var crit: Variant = critical_distance_um(strength.get("kic"), sv) if brittle else null
	out.merge({
		"chipN": sv / f if f > 0.0 else INF, "chipMinN": smin / f if f > 0.0 else INF,
		"chipMaxN": smax / f if f > 0.0 else INF, "fails": fails, "breaks": brittle and fails,
		"bends": not brittle and fails, "failsLo": lat > 0.0 and stress >= smin, "failsHi": lat > 0.0 and stress >= smax,
		"mode": ("mella" if brittle else "dobla") if fails else "intacta", "criticalUm": crit,
		"sizeEffect": crit != null and float(pk.rMm) * 1000.0 < float(crit),
		"quality": strength.get("quality"), "source": strength.get("source"),
	}, true)
	return out


# ════════ 4. El compromiso completo (para la interfaz y los casos de referencia) ════════

## El afilado s de una garra de punta natural r0_um y semiángulo alpha_deg, del material de módulo e_tool_gpa y
## resistencia strength, apretando con force_n contra un material de módulo e_target_gpa y dureza h_target_mpa, con la
## fricción mu (la carga lateral es μ·F, en el vértice). Compara con la punta natural:
## { naturalUm, tipRadiusUm, sharpness, pressureGain, p0MPa, p0NaturalMPa, yieldOnsetN, yieldOnsetNaturalN, depthUm,
##   depthNaturalUm, lateralN, chipN, chipNaturalN, sharpestSurvivingUm, fracture (evaluate), survives }.
static func tradeoff(
	r0_um: float, alpha_deg: float, s: float, e_tool_gpa: float, strength: Variant, force_n: float, mu: float,
	e_target_gpa: float, h_target_mpa: float
) -> Dictionary:
	var r := radius_at(r0_um, s)
	var tip := tip_of(r, alpha_deg)
	var lateral := maxf(mu, 0.0) * maxf(force_n, 0.0)
	var fr := evaluate(tip, strength, lateral)
	var nat: Variant = null
	var sharpest: Variant = null
	if strength != null:
		nat = chip_load_n(tip_of(r0_um, alpha_deg), float(strength.value))
		sharpest = sharpest_surviving_um(alpha_deg, float(strength.value), lateral)
	return {
		"naturalUm": r0_um, "tipRadiusUm": r, "sharpness": sharpness_for(r0_um, r),
		"pressureGain": pressure_gain(r0_um, r),
		"p0MPa": hertz_peak_mpa(force_n, r, e_tool_gpa, e_target_gpa),
		"p0NaturalMPa": hertz_peak_mpa(force_n, r0_um, e_tool_gpa, e_target_gpa),
		"yieldOnsetN": yield_onset_n(r, e_tool_gpa, e_target_gpa, h_target_mpa),
		"yieldOnsetNaturalN": yield_onset_n(r0_um, e_tool_gpa, e_target_gpa, h_target_mpa),
		"depthUm": plastic_depth_um(r, alpha_deg, force_n, h_target_mpa),
		"depthNaturalUm": plastic_depth_um(r0_um, alpha_deg, force_n, h_target_mpa),
		"lateralN": lateral, "chipN": fr.chipN, "chipNaturalN": nat, "sharpestSurvivingUm": sharpest,
		"fracture": fr, "survives": not bool(fr.fails),
	}
