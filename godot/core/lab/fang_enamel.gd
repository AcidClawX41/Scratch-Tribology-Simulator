## Tribología biológica · esmalte en la punta de los colmillos (modelo 2.0; la 1.x los hace de dentina entera).
##
## Estrada et al. (2026) describen en los colmillos de tres víboras neotropicales esmalte aprismático concentrado en la
## punta sobre un cuerpo de dentina (0,4-0,6 GPa), con una composición «comparable a la de los dientes de cocodrilo».
## No dan la dureza del esmalte. Se toma la del esmalte de cocodrilo medida con el mismo tipo de ensayo (Enax et al.
## 2013: esmalte 3,15 GPa y dentina 0,60 GPa, la misma dentina que la de las víboras): calidad «secondary».
## Su espesor en la punta no está medido en víboras: las serpientes de presas blandas tienen un esmalte fino y solo en
## la punta (Dumont et al. 2023); se toman 10 µm (estimación).
##
## Modelo (estimación, la misma forma que la laca sobre la madera de la 1.x, FISICA.md §6): la punta es un casquete de
## esmalte sobre dentina; con un contacto de radio a, su dureza efectiva es
##   H(a) = H_dentina + (H_esmalte − H_dentina)·exp(−a/t_esmalte),
## así que el esmalte manda en un contacto pequeño (rayar con la puntita) y la dentina en uno grande (apoyar el
## colmillo). El módulo E de la punta sigue siendo el de la dentina: el casquete es demasiado fino para cambiar el
## contacto elástico. Un colmillo «reforjado» (incrustación) es entero de su material: sin esmalte.
## Unidades: dureza HV · radio de contacto mm · espesor µm. Funciones puras y deterministas.
## Uso: const FangEnamel = preload("res://core/lab/fang_enamel.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")

const SRC_ESTRADA_2026 := "Estrada S, Arredondo JC, Pereañez J, Arola D, Ossa A (2026). Mechanical properties, microstructure, and strike biomechanics of tubular fangs in neotropical vipers. Acta Biomater. 222:388-398 (esmalte aprismático concentrado en la punta; dentina de 0,4-0,6 GPa en Vickers; composición comparable a la de los dientes de cocodrilo). doi:10.1016/j.actbio.2026.07.058"
const SRC_ENAX_2013 := "Enax J, Fabritius HO, Rack A, Prymak O, Raabe D, Epple M (2013). Characterization of crocodile teeth: correlation of composition, microstructure, and hardness. J. Struct. Biol. 184:155-163 (microdureza: esmalte 3,15 ± 0,15 GPa, dentina 0,60 ± 0,05 GPa). doi:10.1016/j.jsb.2013.09.018"
const SRC_DUMONT_2023 := "Dumont M, Milgram J, Herrel A et al. (2023). Show me your teeth and I will tell you what you eat: differences in tooth enamel in snakes with different diets. Integr. Comp. Biol. 63:265-275 (63 especies: las serpientes de presas blandas tienen un esmalte fino limitado a la punta). doi:10.1093/icb/icad028"

## Número e (base de la exponencial). La exponencial va con V8.js_exp (la misma en todas las plataformas y tres veces más
## rápida que V8.js_pow(E_NUM, x): la resistencia del esmalte la evalúa en cada paso del resolvedor; unidad 4b).
const E_NUM := 2.718281828459045

## Esmalte de la punta. hv: 3,15 GPa / 9,807 MPa por HV = 321,2 HV (el de cocodrilo, Enax 2013).
const ENAMEL := {
	"hv": 321.2, "thicknessUm": 10.0,
	"source": SRC_ENAX_2013 + " (esmalte de cocodrilo como el de los colmillos: " + SRC_ESTRADA_2026 + ")",
	"quality": "secondary",
	"thicknessSource": "estimación: esmalte fino limitado a la punta (" + SRC_DUMONT_2023 + ")",
	"thicknessQuality": "estimate",
}


## ¿Tiene esmalte en la punta esta herramienta (resuelta con Physics.resolve_tool)? Solo los colmillos naturales.
static func applies(tool: Dictionary) -> bool:
	return Js.truthy(tool.get("fang")) and not Js.truthy(tool.get("hasGem"))


## Dureza (HV) de la punta con un contacto de radio a_mm: casquete de esmalte sobre la dentina de tool.hv.
static func tip_hv(tool: Dictionary, a_mm: float, enamel: Dictionary = ENAMEL) -> float:
	var hv_d: float = tool.hv
	if not applies(tool):
		return hv_d
	var hv_e: float = enamel.hv
	var t_mm: float = float(enamel.thicknessUm) / 1000.0
	if hv_e <= hv_d:
		return hv_d
	return hv_d + (hv_e - hv_d) * V8.js_exp(-maxf(a_mm, 0.0) / t_mm)


## Dureza (MPa) de la punta con un contacto de radio a_mm (para las resistencias del motor, en MPa).
static func tip_hardness_mpa(tool: Dictionary, a_mm: float, enamel: Dictionary = ENAMEL) -> float:
	return tip_hv(tool, a_mm, enamel) * Contact.HV_MPA


## Eficiencia de la punta (0-1, Contact.hardness_efficiency) con un contacto de radio a_mm contra un material de
## dureza h_mpa (MPa): la del modelo 2.0 en la resistencia de un sólido (FISICA §4-5), con la dureza de la punta en
## cada contacto en vez de la de la dentina. Para cualquier herramienta que no sea un colmillo natural es la de la 1.x.
static func efficiency(tool: Dictionary, a_mm: float, h_mpa: float) -> float:
	return Contact.hardness_efficiency(tip_hardness_mpa(tool, a_mm) / h_mpa)


## Relación de durezas al primer contacto (a → 0): la que decide si la punta «cede» (r < 0,8) o raya.
static func surface_ratio(tool: Dictionary, target_hv: float, enamel: Dictionary = ENAMEL) -> float:
	return tip_hv(tool, 0.0, enamel) / target_hv


## Radio de contacto (mm) hasta el que la punta conserva una relación de durezas ≥ r frente a target_hv: 0 si ni el
## esmalte llega, INF si la dentina ya llega sola.
static func contact_radius_for_ratio(tool: Dictionary, target_hv: float, r: float, enamel: Dictionary = ENAMEL) -> float:
	var hv_d: float = tool.hv
	var need := r * target_hv
	if hv_d >= need:
		return INF
	if not applies(tool) or float(enamel.hv) < need:
		return 0.0
	var t_mm: float = float(enamel.thicknessUm) / 1000.0
	return t_mm * V8.js_log((float(enamel.hv) - hv_d) / (need - hv_d))
