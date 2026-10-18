## Cetrería · el aspecto de una garra, en un solo sitio (unidad 5c; desde la 5e, con la biblioteca de materiales de las
## garras): de su material (la queratina o un material reforjado: los de Data.INLAYS y los de la reforja) y su acabado
## salen los parámetros del sombreador de la queratina (keratin.gdshader, que incluye el modelo de la biblioteca,
## app/common/claw_material.gdshaderinc) de la garra que se trabaja y de las demás garras de las patas, y el material de
## las garras del modelo 3D que no se trabajan (el mismo de la biblioteca, Animal3D.set_claws).
##   - El color, el brillo y la luz de cada material salen de sus datos ópticos con fuente (core/lab/claw_optics.gd): el
##     reflejo medido de cada metal, el índice, la dispersión y la absorción de cada gema; la queratina, con el color de su
##     especie, sus líneas de crecimiento, su barniz y la carne viva a trasluz en las garras claras.
##   - La superficie que deja cada pasada (la textura surface_tex del contrato «La cetrería en alta definición y la
##     superficie de la garra») la pasa la escena al material; aquí no se toca.
##   - La forma de las garras no sale de aquí: es la del perfil de ClawCare (los datos de cada animal).
## Solo dibujo (los números físicos son los de core/).
## Uso: var p := ClawLook.params("none", Color("#2b2420"), { "light": false }); ClawLook.apply(mat, p)
extends RefCounted

const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")

## Claves de params() que no son del sombreador (las demás, sí; el calor, las heridas, el resaltado y la superficie son
## del estado, y los pone la escena).
const META_KEYS := ["natural", "material", "color", "claw_apex_mm"]
## Lo opaca que es la queratina (dibujo de la 5c, la referencia de la petición 36): una garra clara deja ver la carne viva
## a trasluz; al terminar, una oscura se aclara para enseñarla; las demás garras de las patas no llevan la carne viva
## dibujada dentro (una clara, algo translúcida). Una gema o un vidrio deja ver algo de lo de detrás (sin leer la
## pantalla: la luz que sale de dentro es la del entorno del taller, refractada con su índice).
const OPACITY_LIGHT := 0.6
const OPACITY_FINISHED := 0.5
const OPACITY_DARK := 0.97
const OPACITY_OTHER_LIGHT := 0.8
const OPACITY_GEM := 0.88
## El reflejo dibujado de la biblioteca en un metal (unidad 5q) cuando la sala ya tiene sonda de reflexión (Forward+): la
## sonda trae la sala de verdad y el entorno dibujado solo rellena lo que la sonda no alcanza (las lámparas); sin sonda
## (OpenGL y teléfono) el entorno dibujado es todo el reflejo, con su energía entera.
const METAL_ENV_WITH_PROBE := 0.35
## El largo máximo (mm) de cada faceta de una talla (dibujo): la biblioteca las hace de un 20 % del largo de la garra, y en
## la hoz del velocirraptor (~80 mm) salían de ~16 mm, franjas anchas y oscuras en vez de una gema tallada. Hasta 30 mm de
## garra no cambia nada.
const FACET_MAX_MM := 6.0


## El aspecto de una garra. material: «none» (queratina) o un id de claw_optics.gd (Data.INLAYS y la reforja); color: el
## de la garra (snap.claw.color: el de la queratina de su especie; en un material reforjado no se usa, su color es el de
## sus datos ópticos); finish: { light (garra clara: la carne viva se ve a trasluz), finished (al terminar, una oscura se
## aclara para enseñarla), other (una de las demás garras de las patas: sin la carne viva dentro), y, opcionales:
## surface (un acabado de ClawOptics, p. ej. ClawOptics.finish_from_care(snapshot)), quality («movil»: un solo rayo en
## las gemas), length_mm (el largo de la garra: las facetas de una talla, como mucho de FACET_MAX_MM), probe (la sala tiene
## sonda de reflexión: el entorno dibujado baja en los metales, METAL_ENV_WITH_PROBE), section_k (alto/ancho de una sección
## comprimida de lado: lo que absorbe una gema, a lo largo de su ancho) }.
## → los parámetros del sombreador (claw_* de la biblioteca, opacity y rim_k) y natural, material y color.
static func params(material: String, color: Color, finish := {}) -> Dictionary:
	var mid := material if ClawOptics.MATERIALS.has(material) else "none"
	var opts := { "quality": String(finish.get("quality", "escritorio")), "env": "taller", "color": color }
	if finish.has("length_mm"):
		opts["facet_mm"] = facet_mm(float(finish.length_mm))
	if bool(finish.get("probe", false)) and ClawMaterial.KIND.get(String(ClawOptics.look(mid).family), 0) == 1:
		opts["env_energy"] = METAL_ENV_WITH_PROBE
	var surf: Dictionary = finish.get("surface", {})
	var out := ClawMaterial.params(mid, surf, opts)
	out.merge({ "natural": mid == "none", "material": material, "color": color }, true)
	# la sección comprimida de lado (la hoz del velocirraptor: alto/ancho = k): la luz atraviesa su ancho, 2·r/√k, y no el
	# diámetro de la sección redonda equivalente (claw_section_k de la biblioteca; sin ella, 1: como siempre)
	if finish.has("section_k"):
		out["claw_section_k"] = maxf(float(finish.section_k), 1.0)
	if mid != "none":
		var transparent := bool(ClawOptics.look(mid).get("transparent", false))
		out["opacity"] = OPACITY_GEM if transparent else 1.0
		out["rim_k"] = 0.6 if transparent else 0.0
		return out
	var light := bool(finish.get("light", false))
	var opacity := OPACITY_LIGHT if light else (OPACITY_FINISHED if bool(finish.get("finished", false)) else OPACITY_DARK)
	if bool(finish.get("other", false)):
		opacity = OPACITY_OTHER_LIGHT if light else OPACITY_DARK
	out["opacity"] = opacity
	out["rim_k"] = 0.6
	return out


## El largo de cada faceta para una garra de length_mm: −1 (el de la biblioteca, un 20 % del largo) hasta FACET_MAX_MM.
static func facet_mm(length_mm: float) -> float:
	return FACET_MAX_MM if length_mm * 0.2 > FACET_MAX_MM else -1.0


## Pone el aspecto en un material del sombreador de la queratina (los parámetros del estado no se tocan).
static func apply(mat: ShaderMaterial, p: Dictionary) -> void:
	for k: String in p:
		if not META_KEYS.has(k):
			mat.set_shader_parameter(k, p[k])


## Las garras del modelo 3D (Animal3D.set_claws) con el mismo material de la biblioteca, con el entorno del taller.
static func apply_model(a3d: RefCounted, p: Dictionary) -> void:
	if a3d != null:
		a3d.call("set_claws", bool(p.natural), String(p.material), p.color as Color, "taller")
