## Materiales físicos de los animales en 3D (unidad 4l): la descripción de cada uno (qué sombreador, qué tesela del
## detalle, rugosidad, brillo especular, luz de contorno…), que el modelo guarda en la caché; cada animal crea con ella
## sus propios ShaderMaterial (el viento, el tiempo y el desvanecido son suyos). En la línea de la luz del coche y del
## taller: el mismo sol, el mismo cielo y las mismas sombras.
##   - pluma: mate con luz de contorno, plumas en tejado en relieve;
##   - pelo: mate, pelo en relieve, luz de contorno y algo de luz que atraviesa el borde, y unas capas de pelo en el
##     contorno (el preset móvil, menos);
##   - escama y escudo: algo satinados, escamas o placas en relieve;
##   - piel desnuda: satinada, arrugas finas;
##   - queratina (pico, casco): brillante, con estrías (las garras, con la biblioteca de materiales de la 5e);
##   - tarjetas (plumas del ala y de la cola, mechones): la silueta de la pluma recortada, de dos caras;
##   - ojo: córnea brillante con su reflejo.
## Solo dibujo.
extends RefCounted

const Tex3D = preload("res://app/lab/animals/tex3d.gd")


static func _px(mobile: bool) -> int:
	return Tex3D.TILE_PX_MOBILE if mobile else Tex3D.TILE_PX


## Superficie con una tesela del detalle (kind: «pluma», «plumon», «pelo», «escama», «escudo», «piel», «queratina»).
static func surface(kind: String, mobile: bool, cache: Dictionary, o := {}) -> Dictionary:
	var t := Tex3D.tile(kind, _px(mobile), cache)
	var spec := {
		"shader": "surface", "detail_albedo": t.albedo, "detail_normal": t.normal, "pattern": o.get("pattern", null),
		"detail_mix": 0.4, "normal_depth": 1.0, "rough": 0.8, "spec": 0.3, "metal": 0.0, "rim": 0.3, "rim_tint": 0.6, "sheen": 0.0,
		"wobble": 0.004, "tint": o.get("tint", Color(1, 1, 1)),
	}
	match kind:
		"pluma":
			spec.merge({ "detail_mix": 0.2, "normal_depth": 0.65, "rough": 0.82, "spec": 0.28, "rim": 0.38, "rim_tint": 0.65, "sheen": 0.12 }, true)
		"plumon":
			spec.merge({ "detail_mix": 0.1, "normal_depth": 0.4, "rough": 0.86, "spec": 0.25, "rim": 0.42, "rim_tint": 0.65, "sheen": 0.15 }, true)
		"pelo":
			spec.merge({ "detail_mix": 0.35, "normal_depth": 0.9, "rough": 0.88, "spec": 0.22, "rim": 0.5, "rim_tint": 0.55, "sheen": 0.22 }, true)
		"escama", "escudo":
			spec.merge({ "detail_mix": 0.3, "normal_depth": 1.2, "rough": 0.55, "spec": 0.42, "rim": 0.12, "rim_tint": 0.4, "sheen": 0.0 }, true)
		"piel":
			spec.merge({ "detail_mix": 0.2, "normal_depth": 0.6, "rough": 0.48, "spec": 0.4, "rim": 0.15, "rim_tint": 0.4, "sheen": 0.08 }, true)
		"queratina":
			spec.merge({ "detail_mix": 0.12, "normal_depth": 0.35, "rough": 0.3, "spec": 0.6, "rim": 0.05, "rim_tint": 0.2, "sheen": 0.0 }, true)
	spec.merge(o, true)
	spec["made"] = int(t.made)
	return spec


## Pelo con capas en el contorno: surface(«pelo») y n capas de largo len_m (m) en el escritorio (en el teléfono, una).
static func fur(mobile: bool, cache: Dictionary, len_m: float, n := 3, o := {}) -> Dictionary:
	var spec := surface(String(o.get("tile", "pelo")), mobile, cache, o)
	spec["shells"] = 1 if mobile else n
	spec["shell_len"] = len_m
	spec["strands"] = Tex3D.strands(_px(mobile), cache)
	spec["strand_scale"] = float(o.get("strand_scale", 2.0))
	spec["tip"] = o.get("tip", Color(1.1, 1.08, 1.05))
	return spec


## Tarjetas con la silueta de tex (alfa recortada).
static func cards(tex: Texture2D, o := {}) -> Dictionary:
	var spec := { "shader": "card", "tex": tex, "rough": 0.78, "spec": 0.3, "rim": 0.35, "rim_tint": 0.6, "sheen": 0.2, "raise": 0.02,
		"wobble": 0.006, "tint": Color(1, 1, 1) }
	spec.merge(o, true)
	return spec


## Ojo: iris, esclerótica y tamaños del iris y la pupila (en la escala de UV.y del globo, 0 en el polo de delante).
static func eye(iris: Color, o := {}) -> Dictionary:
	var spec := { "shader": "eye", "iris": iris, "sclera": Color("#E8DFCF"), "iris_r": 0.62, "pupil_r": 0.28, "pupil_sx": 1.0 }
	spec.merge(o, true)
	return spec


## Garras: la descripción de la queratina del modelo. Las garras las pinta la biblioteca de materiales de las garras
## (ClawMaterial, unidad 5e) desde Animal3D.set_claws: la queratina de la especie o el material reforjado.
static func claw(mobile: bool, cache: Dictionary) -> Dictionary:
	var spec := surface("queratina", mobile, cache, { "rough": 0.3, "spec": 0.6, "detail_mix": 0.1 })
	spec["claw"] = true
	return spec
