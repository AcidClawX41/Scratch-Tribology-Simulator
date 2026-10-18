## Tribología biológica · flexión y rotura de la uña (modelo 2.0, unidad 1f).
##
## El borde libre de la uña es una placa en voladizo: la reacción del material en la punta la flexa y la uña se dobla
## (queratina a humedad normal, metales) o se parte (acrílico, gel, zafiro) antes de transmitir la fuerza que pide el
## deslizador. Especificación y fuentes: docs/fisica/pulido-materiales.md (tema 2).
##   - Voladizo de longitud L (la uña libre, el «reach» de GEOMS) con la carga en la punta: M(x) = F·x. Si la anchura
##     decrece linealmente hacia la punta (de la cuadrada a la stiletto), la tensión máxima está siempre en la raíz:
##     F_rotura = σ_f·Z/L, con Z el módulo resistente de la sección de la raíz. La forma en planta no cambia la carga
##     de rotura; la longitud sí (una stiletto de 8 mm cede con la mitad que una cuadrada de 4 mm).
##   - La sección es un arco: la uña tiene curvatura transversal (la «C»), de radio 7,4 ± 0,7 mm en el índice de las
##     mujeres (Jung et al. 2015, galgas de radio en 300 voluntarios). Con 11 mm de anchura la «C» es ~3,8 veces más
##     resistente que una placa plana. Es una cota alta: con carga grande la «C» se aplana (efecto Brazier, no
##     modelado) y cede antes; la placa plana (section_modulus) es la cota baja.
##   - La fuerza del deslizador es la normal al material; a la placa le llega su componente perpendicular: con la
##     uña inclinada un ángulo β sobre la superficie, F⊥ = N·(cos β + μ·sin β) al arrastrar tirando (la fricción
##     suma) y N·cos β al apretar. β es el ángulo de ataque de attack.gd (unidad 1g; lo reparte Physics.attack_deg):
##     por defecto 45° en las uñas (ESTIMACIÓN). De gancho (β > 90°, la uña empujada con la punta por delante) la
##     proyección es la misma y cambia de signo: la placa se dobla igual hacia el dorso, así que cuenta su valor absoluto
##     (unidad 4b).
## Unidades: N · mm · MPa. Funciones puras, deterministas y seguras para hilos.
## Uso: const Bending = preload("res://core/lab/bending.gd").
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Attack = preload("res://core/lab/attack.gd")

const HV_MPA := Contact.HV_MPA
## Anchura de la uña del índice en la raíz del borde libre (mm): 11,0 ± 1,0 en mujeres y 13,0 ± 1,0 en hombres
## (Boike et al. 2025). Se usa la de las mujeres, las más habituales en el salón.
const NAIL_WIDTH_MM := 11.0
## Radio de la curvatura transversal de la uña del índice (mm): 7,4 ± 0,7 en mujeres y 8,9 ± 1,2 en hombres (Jung et al.
## 2015). El gel, el acrílico y las uñas macizas siguen la misma curvatura (ESTIMACIÓN: se construyen sobre ella).
const NAIL_CURVE_RADIUS_MM := 7.4
## Ángulo de ataque por defecto (grados entre la placa de la uña y la superficie): el de las uñas en attack.gd
## (Attack.NAIL_DEG, 45°, ESTIMACIÓN con su fuente allí). Es solo el valor por omisión de evaluate(): el del ensayo lo
## decide Physics.attack_deg(p), el mismo para la flexión y para el modo de abrasión.
const ATTACK_DEG := Attack.NAIL_DEG
## La queratina empapada pierde ~80 % de resistencia: la de la garra baja de 69 a 14 MPa (Bonser, en McKittrick et al.
## 2012). El mismo ×0,2 que el motor aplica a su dureza y su módulo.
const WET_STRENGTH := 0.2
## Uñas por material (id de BASES): t, espesor en la raíz del borde libre (mm); sigma, la resistencia medida en MPa (a
## tracción, Rm, en los dúctiles, como la de la uña natural; a flexión en los frágiles); ductile, se dobla (true) o se
## parte (false). En una placa dúctil la rótula plástica pide σ_flujo·Z_p ≈ 1,3-1,5·σ_flujo·Z, del orden de Rm·Z
## (ESTIMACIÓN del modelo): por eso F = Rm·Z/L es la carga con la que la uña dúctil se dobla.
const NAILS := {
	"natural": {
		"t": 0.49, "sigma": 63.7, "ductile": true, "quality": "primary",
		"source": "uña sana: espesor 0,49 ± 0,15 mm y resistencia a tracción 63,7 ± 13,4 MPa (Baraldi et al. 2015, Pharm. Res. 32); dúctil a humedad normal (Farran et al. 2009: E de 4,34 GPa seca a 0,47 GPa al 100 % HR); se agrieta en la dirección transversal, paralela al borde libre (Farren, Shayler & Ennos 2004: ~3 kJ/m² frente a ~6 kJ/m² longitudinal)",
	},
	"gel": {
		"t": 0.8, "sigma": 60.0, "ductile": false, "quality": "estimate",
		"source": "ESTIMACIÓN (sin ensayo publicado del gel de uñas): resistencia a flexión, el mínimo de la ISO 20795-1 para las resinas de metacrilato autopolimerizables (tipo 2: 60 MPa), dentro de lo medido en PMMA autopolimerizable (42-86 MPa; Casucci et al. 2023, 75-86 MPa); espesor de 0,8 mm en la raíz del borde libre (la guía del salón pide el grosor de una tarjeta, 0,76 mm, en el borde libre y el doble en el ápice)",
	},
	"acrilico": {
		"t": 0.8, "sigma": 60.0, "ductile": false, "quality": "estimate",
		"source": "ESTIMACIÓN (sin ensayo publicado del acrílico de uñas, metacrilato de etilo con polvo de PMMA): resistencia a flexión, el mínimo de la ISO 20795-1 para las resinas autopolimerizables (tipo 2: 60 MPa), dentro de lo medido en PMMA autopolimerizable (42-86 MPa; Casucci et al. 2023, 75-86 MPa); espesor de 0,8 mm en la raíz del borde libre (tarjeta de 0,76 mm en el borde libre y el doble en el ápice, guía del salón)",
	},
	"metal": {
		"t": 0.49, "sigma": 640.0, "ductile": true, "quality": "estimate",
		"source": "resistencia a tracción de un acero de 200 HV (la dureza del catálogo): 640 MPa en la tabla de conversión de la DIN EN ISO 18265, dentro de los 540-750 MPa de la EN 10088-2 para el inoxidable 1.4301 (AISI 304); espesor de la uña natural (ESTIMACIÓN)",
	},
	"titanio": {
		"t": 0.49, "sigma": 483.0, "ductile": true, "quality": "estimate",
		"source": "resistencia a tracción típica del titanio comercial de grado 2 (~150 HV, la dureza del catálogo): 70 ksi = 483 MPa a 20 °C (ficha de Rolled Alloys; mínimo de la ASTM B265, 345 MPa); espesor de la uña natural (ESTIMACIÓN)",
	},
	"zafiro": {
		"t": 0.49, "sigma": 760.0, "ductile": false, "quality": "estimate",
		"source": "resistencia a flexión del zafiro 760 MPa perpendicular al eje c (hojas técnicas de McDanel y UQG Optics); espesor de la uña natural (ESTIMACIÓN)",
	},
}


## Módulo resistente de la sección plana (mm³): b·t²/6.
static func section_modulus(b_mm: float, t_mm: float) -> float:
	return b_mm * t_mm * t_mm / 6.0


## Módulo resistente de una sección en arco circular (mm³): cuerda b, espesor t y radio ρ (la «C» de la uña). Pared
## delgada de semiángulo θ0 = asin(b/2ρ): respecto a su centroide, I = t·ρ³·(θ0 + sin θ0·cos θ0 − 2·sin²θ0/θ0), más
## la flexión propia de la pared, b·t³/12 (así ρ → ∞ da la placa plana). La fibra más lejana es la de los bordes
## laterales (en tracción cuando la punta se dobla hacia arriba) o el vértice.
static func section_modulus_arc(b_mm: float, t_mm: float, rho_mm: float) -> float:
	var flat := section_modulus(b_mm, t_mm)
	if rho_mm <= 0.0 or not is_finite(rho_mm):
		return flat
	var x := minf(b_mm / (2.0 * rho_mm), 1.0)
	var th := V8.js_atan2(x, sqrt(1.0 - x * x))  # asin(x)
	var s := V8.js_sin(th)
	var c := V8.js_cos(th)
	var i := t_mm * rho_mm * rho_mm * rho_mm * (th + s * c - 2.0 * s * s / th) + b_mm * t_mm * t_mm * t_mm / 12.0
	var ybar := rho_mm * s / th  # centroide del arco, desde el centro del círculo
	var c_edge := ybar - rho_mm * c + t_mm / 2.0
	var c_apex := rho_mm - ybar + t_mm / 2.0
	return maxf(i / maxf(c_edge, c_apex), flat)


## Uña del material de la base (NAILS por id), o null si no hay datos (el diamante: sin medición).
static func nail_of(base_id: String) -> Variant:
	return NAILS.get(base_id)


## Resistencia de la uña (MPa), con la queratina empapada ×0,2.
static func strength_mpa(nail: Dictionary, keratin_wet: bool) -> float:
	return nail.sigma * (WET_STRENGTH if keratin_wet else 1.0)


## Fuerza perpendicular a la placa (N) que dobla o parte el borde libre de longitud l_mm: σ·Z/L, con la sección en
## arco de radio rho_mm (INF: placa plana, la cota baja).
static func tip_break_perp(
	nail: Dictionary, l_mm: float, keratin_wet: bool, b_mm: float = NAIL_WIDTH_MM, rho_mm: float = NAIL_CURVE_RADIUS_MM
) -> float:
	return strength_mpa(nail, keratin_wet) * section_modulus_arc(b_mm, nail.t, rho_mm) / l_mm


## Parte de la carga normal que flexa la placa: cos β + μ·sin β al arrastrar; cos β al apretar. Es la proyección de la
## reacción (N hacia arriba y μ·N contra el avance) sobre la normal a la placa, con β el ángulo de ataque de attack.gd
## (medido hacia donde avanza). Hasta 90° es positiva; de gancho (β > 90°) cambia de signo y la placa se dobla igual,
## así que cuenta su valor absoluto: se anula cuando la reacción va a lo largo de la placa (β = 90° + atan μ, sin
## flexión; el pandeo no se modela).
static func bend_factor(attack_deg: float, mu: float, sliding: bool) -> float:
	var b := attack_deg * Contact.DEG
	return absf(V8.js_cos(b) + (maxf(mu, 0.0) * V8.js_sin(b) if sliding else 0.0))


## Resultado para compute() (modelo 2.0) en una uña: base_id (id de BASES), l_mm (uña libre), keratin_wet (la
## herramienta resuelta es queratina mojada), force_n (carga normal pedida), mu (fricción del material), sliding.
## null si no hay datos de esa base.
## { breakN (carga normal con la que cede, sección en «C»), perpN, flatBreakN (la de la placa plana: cota baja), broken,
##   mode: "dobla" | "parte", factor, stressMPa (con force_n), lengthMm, thicknessMm, curveRadiusMm, strengthMPa,
##   quality, source }.
static func evaluate(
	base_id: String, l_mm: float, keratin_wet: bool, force_n: float, mu: float, sliding: bool,
	attack_deg: float = ATTACK_DEG
) -> Variant:
	var nail: Variant = nail_of(base_id)
	if nail == null:
		return null
	var perp := tip_break_perp(nail, l_mm, keratin_wet)
	var factor := bend_factor(attack_deg, mu, sliding)
	var break_n := perp / factor if factor > 0.0 else INF
	var stress := force_n * factor * l_mm / section_modulus_arc(NAIL_WIDTH_MM, nail.t, NAIL_CURVE_RADIUS_MM)
	return {
		"breakN": break_n, "perpN": perp, "broken": force_n >= break_n, "mode": "dobla" if nail.ductile else "parte",
		"factor": factor, "stressMPa": stress, "lengthMm": l_mm, "thicknessMm": nail.t, "curveRadiusMm": NAIL_CURVE_RADIUS_MM,
		"flatBreakN": tip_break_perp(nail, l_mm, keratin_wet, NAIL_WIDTH_MM, INF) / factor if factor > 0.0 else INF,
		"strengthMPa": strength_mpa(nail, keratin_wet), "quality": nail.quality, "source": nail.source,
	}
