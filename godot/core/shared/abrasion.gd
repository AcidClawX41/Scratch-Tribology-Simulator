## Capa física compartida · abrasión y desgaste.
##
## - Modo de abrasión de Hokkirigawa y Kato (1988), según el grado de penetración Dp = h/a:
##   arado (< 0,1), cuña (0,1–0,2) o corte (> 0,2). En el laboratorio lo decide la punta de una uña o una
##   garra; en el taller, un grano abrasivo de la muela o del disco.
##   abrasion_mode() es la misma aritmética que estaba escrita dentro de solidResult en physics.js (1.x).
## - Ley de Archard: volumen desgastado V = k·F·L/H (mm³, con F en N, L en mm y H en MPa).
##   k es adimensional y depende del par de materiales; donde no hay medición se marca como estimación.
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")

const DP_WEDGE := 0.1  # Dp a partir del cual el arado pasa a cuña (Hokkirigawa-Kato 1988)
const DP_CUT := 0.2  # Dp a partir del cual la cuña pasa a corte


## { absMode: "arado" | "cuña" | "corte", fab: fracción del surco que se arranca, muPlough: μ de arado }.
## muPlough ≈ tan del ángulo de ataque (Bowden-Tabor), acotado a 1,2.
static func abrasion_mode(Dp: float) -> Dictionary:
	var mu_plough := Contact.clamp_js(0.9 * Dp, 0.0, 1.2)
	var mode := ""
	var fab := 0.0
	if Dp < DP_WEDGE:
		mode = "arado"
		fab = Contact.clamp_js(Dp / 0.1 * 0.15, 0.02, 0.15)
	elif Dp < DP_CUT:
		mode = "cuña"
		fab = Contact.clamp_js(0.15 + (Dp - 0.1) / 0.1 * 0.45, 0.15, 0.6)
	else:
		mode = "corte"
		fab = Contact.clamp_js(0.6 + (Dp - 0.2) * 2.0, 0.6, 1.0)
	return { "absMode": mode, "fab": fab, "muPlough": mu_plough }


## Ley de Archard: volumen (mm³) arrancado con fuerza load_n (N) a lo largo de sliding_mm (mm) sobre un
## material de dureza hardness_mpa (MPa), con el coeficiente adimensional k.
static func archard_wear(load_n: float, sliding_mm: float, hardness_mpa: float, k: float) -> float:
	if hardness_mpa <= 0.0:
		return 0.0
	return k * load_n * sliding_mm / hardness_mpa
