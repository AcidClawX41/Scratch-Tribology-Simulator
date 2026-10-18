## Tribología biológica · fractura de materiales frágiles (modelo 2.0, unidad 1f).
##
## Qué le pasa a un vidrio, a una pantalla, a una encimera de cuarzo, a un zafiro o a un diamante cuando una punta
## MÁS DURA lo aprieta o lo arrastra. Especificación, datos y fuentes: docs/fisica/pulido-materiales.md.
##
## Dos mecanismos, los dos de la mecánica de la fractura por indentación (Lawn & Marshall 1984):
##   1. Punta roma (contacto elástico de Hertz): grieta de anillo que salta a un cono al llegar a la carga crítica
##      de Auerbach, P = A·(K_c²/E*)·R, con A = 8,63·10³ (Rhee et al. 2001; Ren & Zhang 2014). Al DESLIZAR, la
##      fricción multiplica la tracción del borde trasero del contacto (Hamilton & Goodman 1966) y la carga crítica
##      cae como (1 + k·μ)⁻³, con k = 3π(4+ν)/[8(1−2ν)] (Ren & Zhang 2014, válida con μ < 0,5 y R < 5 mm): el
##      rastro son conos parciales en herradura. Una compresión superficial σS (vidrio templado o reforzado) se suma
##      a la tensión que hay que vencer: P ∝ (1 + σS/σ_m0)³, con σ_m0 = (1−2ν)·P0/(2π·a²) (Hertz).
##   2. Punta afilada (contacto plástico, surco): grietas radiales y laterales (astillado) cuando la huella pasa de
##      un tamaño crítico. Umbral de Lawn & Evans (1977), P* ∝ K_c⁴/H³, calibrado con el umbral medido en el vidrio
##      sodocálcico (0,18 N con un Vickers; Mikowski et al. 2006). Longitud de la grieta: Anstis et al. (1981),
##      c = (ξ·√(E/H)·P/K_c)^(2/3) con ξ = 0,016.
## Hipótesis del modelo: solo una punta al menos tan dura como el material (r ≥ 1) y que siga elástica hasta la carga
## crítica puede agrietarlo; una punta más blanda se aplasta antes (la queratina nunca agrieta el vidrio).
##
## Unidades: fuerza N · longitudes mm (radios de contacto y grietas en µm) · E en GPa · dureza y tensiones en MPa ·
## tenacidad K_c en MPa·√m. Funciones puras, deterministas y seguras para hilos (sin estado).
## Uso: const Fracture = preload("res://core/lab/fracture.gd"), y después Fracture.evaluate(…).
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")

const HV_MPA := Contact.HV_MPA
## Coeficiente de Auerbach adimensional: P = A·(K_c²/E*)·R (Rhee, Kim, Deng & Lawn 2001, vía Ren & Zhang 2014).
const AUERBACH_A := 8630.0
## Validez de la carga crítica al deslizar (Ren & Zhang 2014): μ < 0,5 y radio de la esfera < 5 mm.
const MU_MAX := 0.5
const R_MAX_MM := 5.0
## Poisson de la herramienta: el común del motor (Contact.CONTACT.nu), el mismo que usa su contacto de Hertz.
const NU_TOOL: float = Contact.CONTACT["nu"]
## Relación del radio del anillo con el del contacto al iniciarse: 1,1-1,4 (Mouginot & Maugis 1985, en esferas;
## vía Marulli et al. 2023). Para el dibujo se usa el centro del intervalo.
const RING_RATIO_MIN := 1.1
const RING_RATIO_MAX := 1.4
const RING_RATIO := 1.25
## Ángulo del cono de Hertz con la superficie, solo para el dibujo: ~22° en vidrio sodocálcico (ESTIMACIÓN medida
## sobre la fig. 1b de Lawn & Marshall 1984).
const CONE_ANGLE_DEG := 22.0
## Pirámide Vickers: HV = 1,8544·P/d², con d = 2a (a, semidiagonal) → P = (4/1,8544)·HV·a².
const VICKERS_K := 4.0 / 1.8544
## Grietas radiales de Anstis et al. (1981): K_c = ξ·√(E/H)·P/c^(3/2), ξ = 0,016 ± 0,004 (con un Vickers).
const ANSTIS_XI := 0.016
## Semiángulo entre el eje y las caras del Vickers (68°), la referencia de ξ. Una punta más afilada empuja más la
## grieta: χ ∝ (cot ψ)^(2/3) (Lawn, Evans & Marshall 1980).
const VICKERS_PSI_DEG := 68.0
## Una punta más blanda que el material no le impone la presión que lo agrieta (hipótesis del modelo).
const HARDER_RATIO := 1.0
## Por debajo de esta profundidad (µm) no hay surco: el mismo límite que el veredicto «ROZA SIN MARCAR» del 1.x.
const GROOVE_MIN_UM := 0.05
## El vidrio sodocálcico de referencia de la escala de Lawn-Evans: el «vidrio» de TARGETS y su dureza (HV). Un test
## comprueba que REF_HV sigue siendo la del catálogo.
const REF_ID := "vidrio"
const REF_HV := 550.0

## Datos de fractura de los frágiles del banco, por id de TARGETS (data.gd). Kc en MPa·√m; nu, Poisson;
## sigmaS, compresión superficial (MPa, 0 si no hay); dolUm, profundidad de esa capa (µm); vickersN, umbral medido de
## grietas radiales con un Vickers (N) o null (se escala desde el vidrio con Lawn-Evans). Los objetivos nuevos de la
## 2.0 (glazing.gd) llevan estos mismos datos en su clave «frac».
const BRITTLE := {
	"vidrio": {
		"Kc": 0.75, "nu": 0.22, "sigmaS": 0.0, "dolUm": 0.0, "vickersN": 0.18, "quality": "secondary",
		"source": "K_c ≈ 0,75 MPa·√m, valor de referencia del vidrio sodocálcico (Wiederhorn 1969 mide 3-5 J/m² de energía de fractura: K_c ≈ 0,65-0,85); ν 0,22 (el de la hoja del motor); umbral Vickers 0,18 N (Mikowski et al. 2006)",
	},
	"movil": {
		"Kc": 0.68, "nu": 0.21, "sigmaS": 1000.0, "dolUm": 40.0, "vickersN": 4.5, "quality": "estimate",
		"source": "Corning Gorilla Glass 2 (2012): K_c 0,68 MPa·√m, ν 0,21, 649 HV reforzado, compresión 1000 MPa a 40 µm (capacidad máxima). Umbral Vickers ESTIMADO: 0,18 N (Mikowski 2006) × 25, el cociente Gorilla con intercambio iónico / sodocálcico sin él de la gráfica de Corning (2012)",
	},
	"cuarzo": {
		"Kc": 1.0, "nu": 0.2, "sigmaS": 0.0, "dolUm": 0.0, "vickersN": null, "quality": "estimate",
		"source": "ESTIMACIÓN: la encimera es cuarzo aglomerado sin medición; K_c del cuarzo monocristalino 0,85-1,15 MPa·√m según el plano (Iwasa, Ueno & Bradt 1981); ν 0,2; umbral radial escalado desde el vidrio (Lawn & Evans 1977)",
	},
	"zafiro": {
		"Kc": 2.4, "nu": 0.29, "sigmaS": 0.0, "dolUm": 0.0, "vickersN": null, "quality": "secondary",
		"source": "K_c 2,38-2,43 MPa·√m en los planos (1-102) y (11-20) (Iwasa et al. 1981), 2,31-2,47 en nitrógeno seco (Salem 2006); ν 0,29 (valor de manual, estimación); umbral radial escalado desde el vidrio (Lawn & Evans 1977)",
	},
	"diamante": {
		"Kc": 3.4, "nu": 0.07, "sigmaS": 0.0, "dolUm": 0.0, "vickersN": null, "quality": "estimate",
		"source": "K_c 3,4 ± 0,5 MPa·√m del diamante natural por indentación (Field & Freeman 1981, citado en revisiones); ν 0,07 (estimación); umbral radial escalado desde el vidrio (Lawn & Evans 1977)",
	},
}

## Resistencia a flexión de las herramientas frágiles (MPa) para el mellado de la punta (tip_chip_load): solo
## INFORMATIVO en la 2.0 (docs/fisica/pulido-materiales.md, tema 4). Por id de INLAYS.
const TOOL_STRENGTH := {
	"zafiro": {
		"sigmaF": 760.0, "quality": "secondary",
		"source": "zafiro: 760 MPa perpendicular al eje c y 1035 MPa paralelo (hojas técnicas de McDanel y UQG Optics); se toma el menor",
	},
	# unidad 4i-B2 (coherencia): una sola resistencia del cuarzo, la de la rotura de las garras (ClawFracture.BRITTLE, unidad 4d):
	# la sílice fundida con la superficie desgastada (Corning HPFS 7980, 52,4 MPa), en lugar de los 67 MPa de MakeItFrom
	"cuarzo": {
		"sigmaF": ClawFracture.BRITTLE.cuarzo.value, "quality": ClawFracture.BRITTLE.cuarzo.quality,
		"source": "ESTIMACIÓN. " + String(ClawFracture.BRITTLE.cuarzo.source),
	},
	# unidad 5g: el rubí del catálogo 2.0 (Catalog.V2_INLAYS) es corindón, como el zafiro: la misma resistencia (la de su fila
	# de ClawFracture.BRITTLE, 760 MPa, como el zafiro de aquí), para que en el banco dé lo mismo que el zafiro
	"rubi": {
		"sigmaF": ClawFracture.BRITTLE.rubi.value, "quality": ClawFracture.BRITTLE.rubi.quality,
		"source": String(ClawFracture.BRITTLE.rubi.source),
	},
}


# ── Datos ──

## Datos de fractura del material (su clave «frac» o la tabla BRITTLE por id), o null si no es frágil.
static func props(target: Dictionary) -> Variant:
	var own: Variant = target.get("frac")
	if own != null:
		return own
	return BRITTLE.get(target.get("id", ""))


## Módulo efectivo de Hertz E* (GPa): 1/E* = (1−ν₁²)/E₁ + (1−ν₂²)/E₂ (Ren & Zhang 2014, ec. 7).
static func effective_modulus(e1_gpa: float, nu1: float, e2_gpa: float, nu2: float) -> float:
	return 1.0 / ((1.0 - nu1 * nu1) / e1_gpa + (1.0 - nu2 * nu2) / e2_gpa)


## Carga crítica de Auerbach sin fricción (N): P = A·K_c²·R/E*, con K_c en MPa·√m, R en mm y E* en GPa (los
## factores 10¹²·10⁻³/10⁹ de las unidades se cancelan).
static func auerbach_load(kc: float, estar_gpa: float, r_mm: float) -> float:
	return AUERBACH_A * kc * kc * r_mm / estar_gpa


## k del deslizamiento: k = 3π(4+ν)/[8(1−2ν)] (Ren & Zhang 2014, ec. 5).
static func sliding_k(nu: float) -> float:
	return (3.0 * PI * (4.0 + nu)) / (8.0 * (1.0 - 2.0 * nu))


## μ que entra en la carga crítica al deslizar: dentro de [0, MU_MAX] (validez de la fórmula).
static func clamp_mu(mu: float) -> float:
	return Contact.clamp_js(mu, 0.0, MU_MAX)


## Cuánto baja la carga crítica al deslizar: (1 + k·μ)³ ≥ 1 (Ren & Zhang 2014, ec. 4).
static func sliding_factor(mu: float, nu: float) -> float:
	var f := 1.0 + sliding_k(nu) * clamp_mu(mu)
	return f * f * f


## Radio del contacto de Hertz (mm) con carga P (N), radio R (mm) y E* (GPa).
static func hertz_radius(p_n: float, r_mm: float, estar_gpa: float) -> float:
	return Js.cbrt((3.0 * p_n * r_mm) / (4.0 * estar_gpa * 1000.0))


## Tracción radial máxima en el borde del contacto (MPa): σ_m = (1−2ν)·P/(2π·a²) (Ren & Zhang 2014, ec. 1).
static func hertz_edge_stress(p_n: float, r_mm: float, estar_gpa: float, nu: float) -> float:
	var a := hertz_radius(p_n, r_mm, estar_gpa)
	return (1.0 - 2.0 * nu) * p_n / (2.0 * PI * a * a)


## Presión máxima de Hertz (MPa) con carga P: p0 = 3P/(2π·a²).
static func hertz_peak_pressure(p_n: float, r_mm: float, estar_gpa: float) -> float:
	var a := hertz_radius(p_n, r_mm, estar_gpa)
	return (3.0 * p_n) / (2.0 * PI * a * a)


## Factor de la compresión superficial σS (MPa): hay que vencer σ_m0 + σS con σ ∝ P^(1/3) → (1 + σS/σ_m0)³.
static func residual_factor(sigma_s: float, sigma_m0: float) -> float:
	if sigma_s <= 0.0 or sigma_m0 <= 0.0:
		return 1.0
	var f := 1.0 + sigma_s / sigma_m0
	return f * f * f


# ── 1. Punta roma: grietas de Hertz ──

## Cargas críticas de Hertz para una punta de módulo e_tool (GPa) y dureza h_tool (MPa) con radio r_mm sobre un
## frágil fp de módulo e_target (GPa). Con sliding, la del deslizamiento con fricción mu.
## { freeN (Auerbach sin compresión), staticN (con compresión), slidingFactor, loadN (la que aplica), estar,
##   ringUm (radio del anillo al iniciarse), contactUm, peakMPa (p0 en la carga crítica), toolElastic, k, mu, valid }.
static func hertz_threshold(
	e_tool: float, h_tool: float, fp: Dictionary, e_target: float, r_mm: float, mu: float, sliding: bool
) -> Dictionary:
	var nu: float = fp.nu
	var estar := effective_modulus(e_tool, NU_TOOL, e_target, nu)
	var p_free := auerbach_load(fp.Kc, estar, r_mm)
	var sigma_m0 := hertz_edge_stress(p_free, r_mm, estar, nu)
	var p_static := p_free * residual_factor(fp.get("sigmaS", 0.0), sigma_m0)
	var fs := sliding_factor(mu, nu) if sliding else 1.0
	var p_c := p_static / fs
	var a_c := hertz_radius(p_c, r_mm, estar)
	var p0 := hertz_peak_pressure(p_c, r_mm, estar)
	# la punta sigue elástica si su p0 no llega a la plastificación de Johnson (1,6·Y, con Y = H/2,8, Tabor)
	var tool_yield: float = Contact.CONTACT["yieldOnset"] * h_tool / Contact.CONTACT["tabor"]
	return {
		"freeN": p_free, "staticN": p_static, "slidingFactor": fs, "loadN": p_c, "estar": estar,
		"ringUm": RING_RATIO * a_c * 1000.0, "contactUm": a_c * 1000.0, "peakMPa": p0, "toolYieldMPa": tool_yield,
		"toolElastic": p0 <= tool_yield, "k": sliding_k(nu), "mu": clamp_mu(mu) if sliding else 0.0,
		"valid": r_mm <= R_MAX_MM,
	}


## Radio de la base del cono (µm) para el dibujo: sale del anillo en la carga crítica y crece como P^(2/3) (ley de
## propagación P/c^(3/2) = cte, Lawn & Marshall 1984, ec. 1). 0 por debajo de la carga crítica. ESTIMACIÓN de dibujo.
static func cone_radius_um(p_n: float, p_c: float, ring_um: float) -> float:
	if p_c <= 0.0 or p_n < p_c:
		return 0.0
	return ring_um * V8.js_pow(p_n / p_c, 2.0 / 3.0)


# ── 2. Punta afilada: grietas radiales y laterales ──

## Umbral de grietas radiales con un Vickers (N): el medido o, si no hay, la escala de Lawn-Evans desde el vidrio:
## P* = P*_vidrio·(K_c/K_c,vidrio)⁴·(H_vidrio/H)³. hv, dureza del material (HV).
static func radial_threshold_n(fp: Dictionary, hv: float) -> float:
	var own: Variant = fp.get("vickersN")
	if own != null:
		return own
	var ref: Dictionary = BRITTLE[REF_ID]
	var kr: float = fp.Kc / ref.Kc
	var hr: float = REF_HV / hv
	return ref.vickersN * (kr * kr * kr * kr) * (hr * hr * hr)


## Tamaño crítico de la huella (µm): la semidiagonal del Vickers en el umbral, a* = √(P*/((4/1,8544)·HV)). Es la
## longitud de fragilidad de Lawn-Marshall, a* ∝ (K_c/H)², independiente de la forma de la punta a primer orden.
static func radial_contact_um(fp: Dictionary, hv: float) -> float:
	return sqrt(radial_threshold_n(fp, hv) / (VICKERS_K * hv * HV_MPA)) * 1000.0


## Factor de afilado de la grieta radial frente al Vickers: (cot ψ / cot 68°)^(2/3), con tan ψ la de la punta
## (Lawn, Evans & Marshall 1980). 1 con el Vickers; ~1,6 con una gema de 50°; ~4,4 con una garra de 15°.
static func sharpness_factor(tan_a: float) -> float:
	var ref := V8.js_tan(VICKERS_PSI_DEG * Contact.DEG)
	return V8.js_pow(ref / maxf(tan_a, 1e-6), 2.0 / 3.0)


## Coeficiente de la grieta radial χ = ξ·√(E/H)·(afilado): K = χ·P/c^(3/2).
static func radial_chi(e_gpa: float, hv: float, tan_a: float) -> float:
	return ANSTIS_XI * sqrt((e_gpa * 1000.0) / (hv * HV_MPA)) * sharpness_factor(tan_a)


## Longitud de la grieta radial (µm) con carga P (N): Anstis et al. (1981), c = (χ·P/K_c)^(2/3), con el afilado de
## la punta de tangente tan_a (por defecto la del Vickers).
static func radial_crack_um(p_n: float, e_gpa: float, hv: float, kc: float, tan_a: float = -1.0) -> float:
	if p_n <= 0.0:
		return 0.0
	var ta := tan_a if tan_a > 0.0 else V8.js_tan(VICKERS_PSI_DEG * Contact.DEG)
	return V8.js_pow(radial_chi(e_gpa, hv, ta) * p_n / (kc * 1.0e6), 2.0 / 3.0) * 1.0e6


# ── Resultado para compute() (modelo 2.0) ──

## Fractura del material bajo la punta. tool: la herramienta resuelta (hv, E); tip: su geometría
## (Contact.tip_geometry: R, tanA…); target: el material; force_n: carga normal en la punta (N, la que llega de
## verdad); sliding: rayando (true) o apretando (false); mu: fricción del material; depth_um y contact_um:
## profundidad y radio del contacto bajo carga que ya calcula compute(). null si el material no es frágil.
## { cracks, mode: "hertz" | "radial" | "none", pattern: "herradura" | "cono" | "astillado" | "radiales" | null,
##   hertzN, hertzStaticN, hertzFreeN, toolElastic, harderTool, radialN, radialContactUm, crackUm, ringUm,
##   coneAngleDeg, mu, k, valid, quality, source }.
static func evaluate(
	tool: Dictionary, tip: Dictionary, target: Dictionary, force_n: float, sliding: bool, mu: float, depth_um: float,
	contact_um: float
) -> Variant:
	var fp: Variant = props(target)
	if fp == null:
		return null
	var hv_target: float = target.hv
	var harder: bool = tool.hv / hv_target >= HARDER_RATIO
	var h := hertz_threshold(tool.E, tool.hv * HV_MPA, fp, target.E, tip.R, mu, sliding)
	var hertz_cracks: bool = harder and h.toolElastic and force_n >= h.loadN
	var a_star := radial_contact_um(fp, hv_target)
	var groove := depth_um >= GROOVE_MIN_UM
	var radial_cracks: bool = harder and groove and contact_um >= a_star
	var mode := "none"
	var pattern: Variant = null
	var crack_um := 0.0
	if groove and (radial_cracks or hertz_cracks):
		# surco con grietas: radiales al apretar, laterales (astillado) al rayar
		mode = "radial"
		pattern = "astillado" if sliding else "radiales"
		crack_um = radial_crack_um(force_n, target.E, hv_target, fp.Kc, tip.tanA)
	elif hertz_cracks:
		mode = "hertz"
		pattern = "herradura" if sliding else "cono"
		crack_um = cone_radius_um(force_n, h.loadN, h.ringUm)
	return {
		"cracks": mode != "none", "mode": mode, "pattern": pattern,
		"hertzN": h.loadN, "hertzStaticN": h.staticN, "hertzFreeN": h.freeN, "toolElastic": h.toolElastic,
		"harderTool": harder, "radialN": radial_threshold_n(fp, hv_target), "radialContactUm": a_star,
		"crackUm": crack_um, "ringUm": h.ringUm, "coneAngleDeg": CONE_ANGLE_DEG, "mu": h.mu, "k": h.k,
		"valid": h.valid, "quality": fp.quality, "source": fp.source,
	}


# ── Tema 4 (informativo): mellado de la punta de una herramienta frágil ──

## Fuerza lateral (N) que mella la punta frágil: la punta esfero-cónica como voladizo, σ(x) = 4·F·x/(π·r(x)³), con
## r(x) el radio de su sección a la distancia x del vértice (Contact.contact_radius). Se busca el x más cargado desde
## el final de la esfera (antes, la carga se reparte en el contacto). F = σ_f / máx(4x/(π·r³)). ESTIMACIÓN.
static func tip_chip_load(tip: Dictionary, sigma_f: float, reach_mm: float) -> float:
	var x0: float = maxf(tip.ht, 1e-6)
	var worst := 0.0
	var n := 400
	for i in range(0, n + 1):
		# muestreo geométrico desde el final de la esfera hasta el alcance
		var x := x0 * V8.js_pow(maxf(reach_mm, x0) / x0, float(i) / n)
		var r := Contact.contact_radius(tip, x)
		if r <= 0.0:
			continue
		worst = maxf(worst, (4.0 * x) / (PI * r * r * r))
	return sigma_f / worst if worst > 0.0 else INF


## Mellado de la punta: { chipN, lateralN, chipped } para una herramienta frágil (TOOL_STRENGTH por id del
## material) que soporta la carga normal force_n con fricción mu (la fuerza lateral es μ·F). null si el material no
## está en la tabla. Solo informativo: la 2.0 no cambia la profundidad por esto (docs/fisica/pulido-materiales.md).
static func tip_chip(material_id: String, tip: Dictionary, reach_mm: float, force_n: float, mu: float) -> Variant:
	var s: Variant = TOOL_STRENGTH.get(material_id)
	if s == null:
		return null
	var chip := tip_chip_load(tip, s.sigmaF, reach_mm)
	var lateral := maxf(mu, 0.0) * force_n
	return { "chipN": chip, "lateralN": lateral, "chipped": lateral >= chip, "quality": s.quality, "source": s.source }
