## Serializador canónico del grafo de escena de las ilustraciones ({ tag, attrs, children }) a texto SVG.
##
## Port 1:1 de packages/core/scripts/lib/scene-svg.mjs: tiene que producir exactamente los mismos bytes que el
## oráculo (tests/lab/test_art.gd lo comprueba con los 372 dibujos de art-svg.json).
## - Atributos en su orden de inserción; se omiten `key` (solo servía a React) y los valores null o false.
## - Los atributos de presentación de React en camelCase pasan a kebab-case (strokeWidth → stroke-width); los demás
##   (gradientUnits, maskUnits, viewBox…) se quedan como están, igual que en SVG.
## - Valores como String(n) de JavaScript (Js.js_num_str) y texto escapado (& < > ").
## - Nodos sin hijos como <tag …/>.
## Uso: const Svg = preload("res://core/lab/svg.gd"); Svg.scene_to_svg(Art.surface_art("madera", {…}), view).
extends RefCounted

const Js = preload("res://core/shared/js.gd")

## Atributos que React DOM escribe con guion, ya convertidos.
const KEBAB := {
	"clipPath": "clip-path", "clipRule": "clip-rule", "dominantBaseline": "dominant-baseline",
	"fillOpacity": "fill-opacity", "fillRule": "fill-rule", "fontFamily": "font-family", "fontSize": "font-size",
	"fontWeight": "font-weight", "letterSpacing": "letter-spacing", "stopColor": "stop-color",
	"stopOpacity": "stop-opacity", "strokeDasharray": "stroke-dasharray", "strokeDashoffset": "stroke-dashoffset",
	"strokeLinecap": "stroke-linecap", "strokeLinejoin": "stroke-linejoin", "strokeMiterlimit": "stroke-miterlimit",
	"strokeOpacity": "stroke-opacity", "strokeWidth": "stroke-width", "textAnchor": "text-anchor",
}


## Nombre SVG de un atributo del grafo (strokeWidth → stroke-width; gradientUnits se queda igual).
static func svg_attr_name(k: String) -> String:
	return KEBAB.get(k, k)


## String(v) de JavaScript para los valores que aparecen en el grafo: números, textos y booleanos.
static func js_string(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return Js.js_num_str(v)
		TYPE_INT:
			return Js.js_num_str(float(v))
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
	return str(v)


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


## Nodos → SVG (sin el elemento <svg> que los envuelve).
static func nodes_to_svg(nodes: Array) -> String:
	var parts: Array[String] = []
	_emit(nodes, parts)
	return "".join(PackedStringArray(parts))


static func _emit(nodes: Array, parts: Array[String]) -> void:
	for n: Dictionary in nodes:
		var tag: String = n["tag"]
		parts.append("<" + tag)
		var attrs: Dictionary = n["attrs"]
		for k: String in attrs:
			var v: Variant = attrs[k]
			if k == "key" or v == null or (v is bool and not v):
				continue
			parts.append(" %s=\"%s\"" % [svg_attr_name(k), _esc(js_string(v))])
		var kids: Array = n["children"]
		if kids.is_empty():
			parts.append("/>")
		else:
			parts.append(">")
			_emit(kids, parts)
			parts.append("</" + tag + ">")


## Documento SVG completo de una ilustración: defs, body, lines y extras, en ese orden (como el banco).
## `art` es lo que devuelve una función de art.gd (diccionario) o una lista de nodos (pane_fracture_art).
## `view` = { "viewBox": "0 0 300 60", "width": 300, "height": 60 }.
static func scene_to_svg(art: Variant, view: Dictionary) -> String:
	var nodes: Dictionary = { "body": art } if art is Array else art
	var parts: Array[String] = []
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"%s\">" % [
		js_string(view["width"]), js_string(view["height"]), js_string(view["viewBox"])])
	var defs: Variant = nodes.get("defs")
	if defs is Array and not defs.is_empty():
		parts.append("<defs>")
		_emit(defs, parts)
		parts.append("</defs>")
	for k in ["body", "lines", "extras"]:
		var list: Variant = nodes.get(k)
		if list is Array:
			_emit(list, parts)
	parts.append("</svg>")
	return "".join(PackedStringArray(parts))
