## Una pieza del dibujo vectorial (una textura): sus definiciones (degradados, recortes, desenfoques), sus elementos SVG
## y lo que ocupa (outline), en unidades del dibujo con la y hacia arriba. svg() la recorta a su caja y la deja lista para
## ThorVG. La usan svg_kit.gd (Kit.Part), los animales y el coche. Solo dibujo.
extends RefCounted

const Kit = preload("res://app/lab/animals/svg_kit.gd")

var name := ""
var defs := PackedStringArray()
var body := PackedStringArray()
## Puntos (unidades del dibujo) de lo que ocupa: la caja de la textura.
var outline := PackedVector2Array()
## Margen alrededor de la caja (desenfoques y trazos que salen del contorno).
var margin := 1.0
## Marca de lo que es luz pintada (sombras propias, brillos, luz de borde, sombras proyectadas): el SVG plano la quita,
## porque en 3D la luz la pone el render.
const FX := "data-fx=\"1\""
var _ids := 0
var _open := 0


func _init(p_name := "") -> void:
	name = p_name


## Identificador nuevo dentro de la pieza.
func uid(prefix := "i") -> String:
	_ids += 1
	return "%s%d" % [prefix, _ids]


## Cuenta estos puntos en lo que ocupa la pieza.
func bound(pts: PackedVector2Array) -> void:
	outline.append_array(pts)


## Degradado lineal de a a b (userSpaceOnUse); devuelve su url() para fill o stroke.
func lin(a: Vector2, b: Vector2, stops: Array) -> String:
	var id := uid("g")
	defs.append(Kit.lin_def(id, a, b, stops))
	return "url(#%s)" % id


## Degradado radial; devuelve su url().
func rad(c: Vector2, r: float, stops: Array, f: Variant = null) -> String:
	var id := uid("r")
	defs.append(Kit.rad_def(id, c, r, stops, f))
	return "url(#%s)" % id


## Desenfoque gaussiano (stdDeviation en unidades del dibujo); devuelve su url() para filter.
func blur(std: float) -> String:
	var id := uid("b")
	defs.append("<filter id=\"%s\" x=\"-60%%\" y=\"-60%%\" width=\"220%%\" height=\"220%%\"><feGaussianBlur stdDeviation=\"%s\"/></filter>" % [id, Kit.n(std)])
	return "url(#%s)" % id


## Atributos de relleno: un Color o un url() de lin/rad.
static func _fill_attr(p: Variant, what := "fill") -> String:
	return Kit.paint(p, what) if p is Color else "%s=\"%s\"" % [what, p]


## Relleno: p es un Color o un url(). extra: más atributos.
func fill(d: String, p: Variant, extra := "") -> void:
	body.append("<path d=\"%s\" %s%s/>" % [d, _fill_attr(p), (" " + extra) if extra != "" else ""])


## Relleno desenfocado (sombras y brillos suaves): luz pintada, que no sale en el SVG plano (svg(…, flat)).
func soft(d: String, c: Color, std: float) -> void:
	fill(d, c, "filter=\"%s\" %s" % [blur(std), FX])


## Trazo sin relleno, con extremos y uniones redondeados. p: Color o url().
func stroke(d: String, p: Variant, w: float, extra := "") -> void:
	body.append("<path d=\"%s\" fill=\"none\" %s stroke-width=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\"%s/>" % [
		d, _fill_attr(p, "stroke"), Kit.n(w), (" " + extra) if extra != "" else ""])


## Elipse rellena (el elemento de SVG); rot_deg en grados (antihorario con la y hacia arriba).
func ellipse(c: Vector2, rx: float, ry: float, p: Variant, rot_deg := 0.0, extra := "") -> void:
	var tr := " transform=\"rotate(%s %s %s)\"" % [Kit.n(-rot_deg), Kit.n(c.x), Kit.n(-c.y)] if rot_deg != 0.0 else ""
	body.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" %s%s%s/>" % [Kit.n(c.x), Kit.n(-c.y), Kit.n(rx), Kit.n(ry), _fill_attr(p), tr,
		(" " + extra) if extra != "" else ""])


## Abre un grupo recortado por el trayecto d (se cierra con end()).
func clip(d: String) -> void:
	var id := uid("c")
	defs.append("<clipPath id=\"%s\"><path d=\"%s\"/></clipPath>" % [id, d])
	body.append("<g clip-path=\"url(#%s)\">" % id)
	_open += 1


## Abre un grupo con atributos (opacity, transform…); se cierra con end().
func group(attrs: String) -> void:
	body.append("<g %s>" % attrs)
	_open += 1


## Cierra el último grupo abierto.
func end() -> void:
	if _open > 0:
		body.append("</g>")
		_open -= 1


## Caja de la pieza (unidades del dibujo, y hacia arriba), con su margen.
func box() -> Rect2:
	return Kit.bounds_of(outline).grow(margin)


## El SVG de la pieza a s px por unidad (y rs de más por la escala de la pantalla), recortado a su caja: [svg, Rect2 en
## px lógicos con la y hacia abajo, relativo al origen del dibujo]. flat: sin la luz pintada (para las texturas 3D).
func svg(s: float, rs := 1.0, flat := false) -> Array:
	while _open > 0:
		end()
	var b := box()
	var k := s * rs
	var wpx := maxi(1, ceili(b.size.x * k))
	var hpx := maxi(1, ceili(b.size.y * k))
	# la caja en px enteros: el ancho y el alto del dibujo se ajustan a ellos (la esquina de arriba no se mueve)
	var vw := float(wpx) / k
	var vh := float(hpx) / k
	var x0 := b.position.x
	var y0 := -b.end.y  # arriba de la caja, con la y hacia abajo
	var head := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%s %s %s %s\">" % [
		wpx, hpx, Kit.n(x0), Kit.n(y0), String.num(vw, 4), String.num(vh, 4)]
	var d := "<defs>%s</defs>" % "".join(defs) if not defs.is_empty() else ""
	var els := body
	if flat:
		els = PackedStringArray()
		for e in body:
			if not e.contains(FX):
				els.append(e)
	return [head + d + "".join(els) + "</svg>", Rect2(x0 * s, y0 * s, vw * s, vh * s)]
