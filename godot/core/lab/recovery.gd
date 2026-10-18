## Tribología biológica · recuperación elástica del surco o del pozo (modelo 2.0, unidad 1f).
##
## compute() da la profundidad BAJO CARGA. Al retirar la punta el material recupera su parte elástica y lo que se ve
## es la huella residual. Oliver & Pharr (1992): la descarga sigue P = α·(h − h_f)^m y la rigidez del contacto es
## S = dP/dh = 2·E'·a (Sneddon), así que la profundidad recuperada es
##     h_max − h_f = m·P/S = m·π·a·H/(2E'),
## con P = H·π·a² en contacto plástico, a el radio del contacto y E' = E/(1−ν²) el módulo del material (su superficie
## es la que vuelve). m = 1,5: Oliver & Pharr midieron m = 1,25-1,51 incluso con pirámides (la huella residual no es
## plana y descarga como un paraboloide). Stilwell & Tabor (1961) ya vieron lo esencial: al sacar un cono el diámetro
## de la huella casi no cambia y la profundidad sí, tanto más cuanto mayor es H/E.
## Consecuencias: los polímeros (barniz, ABS: H/E' ≈ 0,05) recuperan mucho, y una punta roma más que una afilada; los
## metales (H/E' ≈ 0,005-0,01) casi nada. Es la recuperación inmediata: la viscoelástica de los polímeros sigue
## horas después y no se modela.
## Unidades: µm · MPa · GPa. Funciones puras, deterministas y seguras para hilos.
## Uso: const Recovery = preload("res://core/lab/recovery.gd").
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")

const HV_MPA := Contact.HV_MPA
## Exponente de la descarga (Oliver & Pharr 1992: 1,25-1,51 en seis materiales; 1,5 es el del paraboloide).
const UNLOADING_M := 1.5
## Poisson del material: el común del motor (Contact.CONTACT.nu).
const NU: float = Contact.CONTACT["nu"]
## Materiales en los que no se aplica: la madera es un sólido celular y anisótropo (recupera por otras vías, con la
## humedad), y la piel se modela aparte por capas.
const EXCLUDED := ["madera", "puertamadera", "piel"]


## Módulo de deformación plana E' = E/(1−ν²) en MPa (E en GPa).
static func plane_strain_modulus(e_gpa: float) -> float:
	return e_gpa * 1000.0 / (1.0 - NU * NU)


## Profundidad recuperada al descargar (µm): m·π·a·H/(2E'), con a el radio del contacto bajo carga (µm), H la
## dureza del material (MPa) y E su módulo (GPa).
static func recovered_um(a_um: float, h_mpa: float, e_gpa: float) -> float:
	if a_um <= 0.0 or h_mpa <= 0.0:
		return 0.0
	return UNLOADING_M * PI * a_um * h_mpa / (2.0 * plane_strain_modulus(e_gpa))


## Profundidad residual (µm): la bajo carga menos la recuperada, nunca negativa (un contacto casi elástico no deja
## huella).
static func residual_um(depth_um: float, a_um: float, h_mpa: float, e_gpa: float) -> float:
	return maxf(0.0, depth_um - recovered_um(a_um, h_mpa, e_gpa))


## ¿Se aplica la recuperación a este material? No en la madera ni en la piel (ni en ningún tejido por capas).
static func applies(target: Dictionary) -> bool:
	return not EXCLUDED.has(target.get("id", "")) and target.get("skin", false) != true


## Capa que manda en la recuperación: la del fondo de la huella. En un coche, la pintura mientras no se atraviesa y la
## carrocería en cuanto la punta llega a ella (el fondo ya es metal); en un sólido, el propio material.
## { hv, E, from (µm): donde empieza esa capa }. Lo que la punta ha cortado por encima no vuelve: el fondo no sube de
## `from` (si la garra llegó al metal, el metal queda al aire).
static func layer_at(target: Dictionary, depth_um: float) -> Dictionary:
	var layers: Variant = target.get("layers")
	if layers == null:
		return { "hv": target.hv, "E": target.E, "from": 0.0 }
	var film: Dictionary = layers.film
	var sub: Dictionary = layers.sub
	if depth_um < film.t:
		return { "hv": film.hv, "E": film.E, "from": 0.0 }
	return { "hv": sub.hv, "E": sub.E, "from": film.t }


## Resultado para compute() (modelo 2.0). depth_um y a_um: la profundidad y el radio del contacto bajo carga que ya
## calcula compute(). null si no se aplica (madera, piel) o si el material queda perforado (through: el agujero no
## se cierra por recuperación elástica).
## { residualDepthUm, recoveredUm, fraction (recuperado / bajo carga), exponent }.
static func evaluate(target: Dictionary, depth_um: float, a_um: float, through: bool) -> Variant:
	if not applies(target) or through:
		return null
	var depth := maxf(depth_um, 0.0)
	var layer := layer_at(target, depth)
	var floor_um: float = minf(layer.from, depth)
	var residual := maxf(floor_um, depth - recovered_um(a_um, layer.hv * HV_MPA, layer.E))
	var rec := depth - residual
	return {
		"residualDepthUm": residual, "recoveredUm": rec, "fraction": rec / depth if depth > 0.0 else 0.0,
		"exponent": UNLOADING_M,
	}
