## Tribología biológica · ángulo de ataque explícito al rayar (modelo 2.0; en la 1.x la punta siempre va de frente).
##
## En la 1.x la punta esfero-cónica se presenta con su eje perpendicular a la superficie, y el modo de abrasión
## (arado, cuña o corte) sale del grado de penetración Dp = h/a (Hokkirigawa & Kato 1988; abrasion.gd). h/a es la
## pendiente media del frente del contacto: en la parte cónica, la de la cara que avanza, cuyo ángulo con la
## superficie es el «ángulo de ataque» de la literatura de abrasión, θ = 90° − α (Challen & Oxley 1979; Sedriks &
## Mulhearn 1963): cuanto más empinada la cara, antes pasa el surco del arado al corte.
##
## Aquí el ángulo de ataque de la herramienta es un parámetro: el que forma su eje con la superficie, medido hacia
## donde avanza (90° = de punta, como en la 1.x; menos de 90°, tumbada y arrastrando, con la base por delante; más de
## 90°, «de gancho», con la base por detrás, clavando). Inclinar la herramienta β = ataque − 90° gira la cara que avanza:
##   θ = 90° − α + β = ataque − α        (acotado a [1°, 90°]: una cara que se vuelca hacia delante ya corta del todo)
## Una punta roma apoyada en su casquete esférico no cambia al inclinarla (la esfera es igual en todas direcciones);
## solo cambia la parte cónica del frente. Con el contacto hasta la profundidad geométrica h_g (h_g > h_t, la
## tangencia esfera-cono), el frente sube (h_g − h_t) sobre un avance horizontal (h_g − h_t)/tan θ, así que
##   Dp_ef = profundidad / [a_t + (h_g − h_t)·cot θ]
## que con θ = 90° − α es exactamente la 1.x (cot θ = tan α). Con Dp_ef salen el modo, la fracción arrancada y la
## fricción de arado (Abrasion.abrasion_mode, sin copiar sus umbrales). La profundidad del surco no cambia: se
## sigue calculando con la punta de frente (limitación).
## Ángulo de cada ensayo (unidad 4b): el que pida el usuario o, si no, el de su tipo de herramienta (default_deg). Es UN
## solo ángulo por ensayo: el que flexa la uña (bending.gd) y el que decide el modo de abrasión (abrasion). Lo reparte
## Physics.attack_deg(p), el único sitio que lo decide.
## Unidades: ángulos en grados, profundidades en µm o mm (se dice). Determinista (V8.js_tan).
## Uso: const Attack = preload("res://core/lab/attack.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")

const SRC_HK_1988 := "Hokkirigawa K, Kato K (1988). An experimental and theoretical investigation of ploughing, cutting and wedge formation during abrasive wear. Tribol. Int. 21:51-57 (Dp = h/a decide arado, cuña o corte con un indentador esférico). doi:10.1016/0301-679X(88)90128-4"
const SRC_CHALLEN_1979 := "Challen JM, Oxley PLB (1979). An explanation of the different regimes of friction and wear using asperity deformation models. Wear 53:229-243 (el régimen, de la ola de arado a la formación de viruta, depende del ángulo de ataque de la aspereza y de la resistencia a cortadura de la intercara). doi:10.1016/0043-1648(79)90080-2"
const SRC_SEDRIKS_1963 := "Sedriks AJ, Mulhearn TO (1963). Mechanics of cutting and rubbing in simulated abrasive processes. Wear 6:457-466 (herramientas piramidales en distintas orientaciones: por debajo de un ángulo de ataque crítico la herramienta frota y ara; por encima, forma viruta; el ángulo crítico depende del material, la profundidad, la fricción y la cara de la herramienta). doi:10.1016/0043-1648(63)90281-3"

## Ángulo de ataque por defecto: la herramienta de punta (la 1.x).
const DEFAULT_DEG := 90.0
## Rango del deslizador: de casi tumbada (10°) a gancho muy cerrado (170°).
const MIN_DEG := 10.0
const MAX_DEG := 170.0
## La cara que avanza nunca se considera más tendida que 1° (un apoyo plano sobre el flanco del cono).
const FACE_MIN_DEG := 1.0
const DEG := PI / 180.0

## Ángulo de ataque por defecto de cada tipo de herramienta, sin medición por forma de uña ni por animal (docs/fisica/
## pulido-biologia.md §9.10):
##   - Uñas: 45° entre la placa y la superficie, ESTIMACIÓN de la unidad 1f (docs/fisica/pulido-materiales.md §2.1): no
##     hay medición del ángulo de la uña al rayar; el caso medido más parecido son las posturas del dedo en una pantalla
##     táctil, de 15° (casi tumbado) a 90° (vertical) (Holz & Baudisch 2010), y 45° es la del medio.
##   - Garras, colmillos y aguijones: 90°, la punta de frente de la 1.x. No hay medición del ángulo con el que una garra
##     ataca la superficie al rayar: es la geometría de la 1.x, no un dato (pregunta abierta).
const NAIL_DEG := 45.0
const CLAW_DEG := DEFAULT_DEG
const SRC_HOLZ_2010 := "Holz C, Baudisch P (2010). The generalized perceived input point model and how to double touch accuracy by extracting fingerprints. Proc. CHI 2010 (posturas del dedo de 15° a 90° sobre una pantalla táctil). doi:10.1145/1753326.1753413"
const DEFAULTS := {
	"uña": {
		"value": NAIL_DEG, "quality": "estimate",
		"source": "estimación: sin medición del ángulo de la uña al rayar; el caso medido más parecido son las posturas del dedo en una pantalla táctil, de 15° a 90° (" + SRC_HOLZ_2010 + "), y 45° es la del medio",
	},
	"garra": {
		"value": CLAW_DEG, "quality": "estimate",
		"source": "sin medición del ángulo con que una garra, un colmillo o un aguijón atacan la superficie: la punta de frente, la geometría de la 1.x (pregunta abierta)",
	},
}


## Tipo de herramienta para el ángulo por defecto: "garra" (garra, colmillo o aguijón: claw) o "uña" (sin claw).
static func kind_of(claw: Variant) -> String:
	return "garra" if Js.truthy(claw) else "uña"


## Ángulo de ataque por defecto (grados) de la herramienta: el de las garras (claw) o, sin ella, el de las uñas.
static func default_deg(claw: Variant) -> float:
	return float(DEFAULTS[kind_of(claw)].value)


## El ángulo que pide el usuario, dentro del rango del deslizador (MIN_DEG-MAX_DEG).
static func clamp_deg(attack_deg: float) -> float:
	return clampf(attack_deg, MIN_DEG, MAX_DEG)


## Ángulo de la cara que avanza (θ, grados) de una punta de semiángulo alpha_deg con el ángulo de ataque attack_deg.
static func face_angle_deg(alpha_deg: float, attack_deg: float = DEFAULT_DEG) -> float:
	return clampf(attack_deg - alpha_deg, FACE_MIN_DEG, 90.0)


## Ángulo de la cara con la punta de frente (la 1.x): 90° − α.
static func natural_face_angle_deg(alpha_deg: float) -> float:
	return face_angle_deg(alpha_deg, DEFAULT_DEG)


## ¿Es el comportamiento de la 1.x (ataque de 90° o sin dato)?
static func is_default(attack_deg: Variant) -> bool:
	return attack_deg == null or float(attack_deg) == DEFAULT_DEG


## Grado de penetración efectivo con el ataque dado. dp: el Dp de la 1.x (depth_um/a_um) · depth_um: profundidad del
## surco (µm) · m: el multiplicador geométrico de la 1.x (φ·tipo·pasadas; la profundidad geométrica es depth/m) ·
## tip: Contact.tip_geometry(...). Con el ataque por defecto, o si el contacto está en el casquete esférico, devuelve
## dp tal cual.
static func effective_dp(dp: float, depth_um: float, m: float, tip: Dictionary, alpha_deg: float, attack_deg: Variant = null) -> float:
	if is_default(attack_deg) or depth_um <= 0.0 or m <= 1e-9:
		return dp
	var h_g := depth_um / 1000.0 / m  # mm
	var ht: float = tip.ht
	if h_g <= ht:
		return dp
	var theta := face_angle_deg(alpha_deg, float(attack_deg))
	var cot := 0.0 if theta >= 90.0 else 1.0 / V8.js_tan(theta * DEG)
	var a_eff: float = float(tip.at) + (h_g - ht) * cot
	return depth_um / (a_eff * 1000.0)


## Modo de abrasión con el ataque dado: { absMode, fab, muPlough, Dp, DpEff, faceDeg, attackDeg } (Abrasion.abrasion_mode
## con el Dp efectivo).
static func abrasion(dp: float, depth_um: float, m: float, tip: Dictionary, alpha_deg: float, attack_deg: Variant = null) -> Dictionary:
	var dp_eff := effective_dp(dp, depth_um, m, tip, alpha_deg, attack_deg)
	var out := Abrasion.abrasion_mode(dp_eff)
	var att := DEFAULT_DEG if attack_deg == null else float(attack_deg)
	out.merge({ "Dp": dp, "DpEff": dp_eff, "faceDeg": face_angle_deg(alpha_deg, att), "attackDeg": att }, true)
	return out


## Pendiente media del frente (grados) para un Dp: atan(Dp). Los umbrales de la 1.x (Dp 0,1 y 0,2) son 5,7° y 11,3°.
static func mean_front_angle_deg(dp: float) -> float:
	return V8.js_atan2(dp, 1.0) / DEG


## Ángulo del borde de ataque de un indentador esférico con ese Dp: Dp = tan(θ/2) (h = R(1 − cos θ), a = R·sen θ). Es
## el que usaron Hokkirigawa y Kato: Dp 0,1 y 0,2 son 11,4° y 22,6°.
static func sphere_edge_angle_deg(dp: float) -> float:
	return 2.0 * V8.js_atan2(dp, 1.0) / DEG
