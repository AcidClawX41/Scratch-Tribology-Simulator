## SVG → ImageTexture con ThorVG (Image.load_svg_from_string), a la escala de la pantalla y con caché LRU.
##
## Las ilustraciones del laboratorio salen de core/lab/art.gd como texto SVG (svg.gd). Aquí se rasterizan a una
## textura del tamaño justo para que se vean nítidas en pantallas HiDPI (factor de escala de la pantalla y del
## estirado de la ventana) y se guardan por (SVG, escala) para no rasterizar dos veces el mismo dibujo.
## Sin estado global: cada vista (banco, ficha, cortes) crea su propia caché con new() o usa rasterize().
## Uso:
##   const SvgTexture = preload("res://app/common/svg_texture.gd")
##   var cache := SvgTexture.new()                                    # 64 texturas y 8 Mpx como máximo
##   var tex := cache.texture(svg, SvgTexture.screen_scale(self))     # desde un Control o un Node2D
extends RefCounted

## Escala máxima que se acepta (un SVG de 300 px a ×4 ya son 1200 px de ancho).
const MAX_SCALE := 4.0

var max_items: int
var max_pixels: int
var _items := {}  # clave → ImageTexture, del menos al más usado (orden de inserción)
var _pixels := {}  # clave → píxeles de esa textura
var _total_pixels := 0
var _hits := 0
var _misses := 0


func _init(items := 64, pixels := 8_000_000) -> void:
	max_items = maxi(items, 1)
	max_pixels = maxi(pixels, 1)


## Rasteriza un SVG sin caché. scale multiplica el tamaño en píxeles del SVG (width × height). null si ThorVG no
## lo entiende.
static func rasterize(svg: String, scale := 1.0) -> ImageTexture:
	var img := rasterize_image(svg, scale)
	return ImageTexture.create_from_image(img) if img != null else null


## Igual que rasterize() pero devuelve la Image (para guardarla como PNG o comprobar píxeles en los tests).
## compat = false rasteriza el SVG tal cual, sin los arreglos de thorvg_compat() (solo para diagnóstico).
static func rasterize_image(svg: String, scale := 1.0, compat := true) -> Image:
	var img := Image.new()
	var err := img.load_svg_from_string(thorvg_compat(svg) if compat else svg, clampf(scale, 0.01, MAX_SCALE))
	if err != OK or img.is_empty():
		return null
	return img


# ── Arreglos para ThorVG ──
# El SVG canónico (el del oráculo) no cambia: esto solo afecta a lo que se le da a ThorVG, el rasterizador de SVG de
# Godot 4.7, en los dos puntos en que pinta distinto que un navegador con las ilustraciones del laboratorio.
# 1. Máscaras con degradado. ThorVG no pinta las máscaras cuyo contenido se rellena con un degradado: todo lo
#    enmascarado sale transparente. Sí entiende las de relleno sólido, con su luminancia y su opacidad. Las
#    ilustraciones las usan para difuminar el dedo de la uña de perfil y la pata, el dedo o la cabeza de garras y
#    colmillos, así que cada <rect> de una máscara relleno con un linearGradient se cambia por MASK_BANDS franjas
#    grises opacas cuya luminancia es el valor de máscara del degradado en esa franja.
# 2. Degradados en la caja de un trayecto con curvas. ThorVG calcula la caja (objectBoundingBox) con los vértices del
#    trayecto, sin lo que abomban las curvas, y el degradado sale desplazado (el brillo del barniz de la pintura de
#    coche). Esos degradados se pasan a coordenadas de usuario con la caja exacta.
# 3. Recortes (clipPath) con una forma que no es un rectángulo recto: ThorVG compone lo recortado a través de una máscara
#    de 8 bits y las líneas finas y translúcidas pierden contraste o desaparecen (el cepillado de la uña de metal y el
#    de las losas de acero, las estrías de la uña natural). Esas líneas (<line> con extremos rectos) se recortan antes, en
#    geometría, contra la forma del recorte, y se pintan fuera del grupo recortado, que se parte en dos para conservar el
#    orden de pintado. Lo demás (rellenos, trazos con extremos redondeados) sigue en el recorte: su error es pequeño
#    (tests/lab/test_art.gd lo mide).

## Franjas con que se aproxima el degradado de una máscara (saltos de 1/MASK_BANDS en el valor de máscara).
const MASK_BANDS := 64
## Tramos con que se aproxima cada curva de una forma de recorte (cuadrática o cúbica) y cada esquina redondeada.
const CLIP_CURVE_STEPS := 24
const CLIP_CORNER_STEPS := 8


## El SVG que hay que darle a ThorVG para que se vea como en un navegador.
static func thorvg_compat(svg: String) -> String:
	var out := svg
	if svg.contains("<linearGradient"):
		var grads := _linear_gradients(svg)
		if not grads.is_empty():
			if out.contains("<mask"):
				out = _fix_masks(out, grads)
			out = _fix_bbox_gradients(out, grads)
	if out.contains("clip-path=\"url(#") and out.contains("<line"):
		out = _fix_clipped_lines(out)
	return out


# ── 3. Líneas dentro de un recorte con forma ──

## Cada <g clip-path="url(#id)"> cuyo recorte es un trayecto (M, L, H, V, Q, C, Z) o un rectángulo con esquinas
## redondeadas, con sus <line> recortadas en geometría y pintadas fuera del recorte.
static func _fix_clipped_lines(svg: String) -> String:
	var clips := {}  # id → polígonos del recorte
	var re_clip := RegEx.create_from_string("(?s)<clipPath id=\"([^\"]+)\">(.*?)</clipPath>")
	for m: RegExMatch in re_clip.search_all(svg):
		var polys := _clip_polygons(m.get_string(2).strip_edges())
		if not polys.is_empty():
			clips[m.get_string(1)] = polys
	if clips.is_empty():
		return svg
	var re_group := RegEx.create_from_string("<g clip-path=\"url\\(#([^)\"]+)\\)\">")
	var out := PackedStringArray()
	var pos := 0
	var m := re_group.search(svg, pos)
	while m != null:
		var id := m.get_string(1)
		var start := m.get_end()
		var end := _group_end(svg, start)
		if not clips.has(id) or end < 0:
			m = re_group.search(svg, m.get_end())
			continue
		var children := _top_children(svg.substr(start, end - start))
		var rebuilt := _split_clip_group(m.get_string(), children, clips[id])
		if rebuilt != "":
			out.append(svg.substr(pos, m.get_start() - pos))
			out.append(rebuilt)
			pos = end + 4  # tras </g>
		m = re_group.search(svg, maxi(pos, m.get_end()))
	out.append(svg.substr(pos))
	return "".join(out)


## El grupo rehecho: los hijos que no son líneas, en trozos recortados; las líneas, recortadas en geometría entre ellos.
## "" si no hay ninguna línea que tratar.
static func _split_clip_group(open_tag: String, children: PackedStringArray, polys: Array) -> String:
	var out := PackedStringArray()
	var chunk := PackedStringArray()
	var any := false
	for c in children:
		var lines: Variant = _clip_line(c, polys)
		if lines == null:
			chunk.append(c)
			continue
		any = true
		if not chunk.is_empty():
			out.append(open_tag + "".join(chunk) + "</g>")
			chunk.clear()
		out.append_array(lines)
	if not any:
		return ""
	if not chunk.is_empty():
		out.append(open_tag + "".join(chunk) + "</g>")
	return "".join(out)


## Una <line> recortada contra los polígonos (regla nonzero): sus tramos de dentro como <line>, o null si el elemento
## no es una línea que se pueda tratar (otra etiqueta, extremos redondeados o transformaciones).
static func _clip_line(el: String, polys: Array) -> Variant:
	if not el.begins_with("<line ") or not el.ends_with("/>") or el.contains("transform=") \
			or (el.contains("stroke-linecap=") and not el.contains("stroke-linecap=\"butt\"")):
		return null
	var a := _attrs(el)
	if not (a.has("x1") and a.has("y1") and a.has("x2") and a.has("y2")):
		return null
	var p0 := Vector2(float(a.x1), float(a.y1))
	var p1 := Vector2(float(a.x2), float(a.y2))
	var rest := PackedStringArray()
	for k: String in a:
		if not k in ["x1", "y1", "x2", "y2"]:
			rest.append("%s=\"%s\"" % [k, a[k]])
	var out := PackedStringArray()
	for seg: Array in _clip_segment(p0, p1, polys):
		var q0: Vector2 = seg[0]
		var q1: Vector2 = seg[1]
		out.append("<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" %s/>" % [_num(q0.x), _num(q0.y), _num(q1.x), _num(q1.y), " ".join(rest)])
	return out


## Tramos [a, b] del segmento p0 → p1 que quedan dentro de los polígonos (número de vueltas distinto de cero).
static func _clip_segment(p0: Vector2, p1: Vector2, polys: Array) -> Array:
	var d := p1 - p0
	var ts: Array[float] = [0.0, 1.0]
	for poly: PackedVector2Array in polys:
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var e := poly[(i + 1) % n] - a
			var den := d.x * e.y - d.y * e.x
			if absf(den) < 1e-12:
				continue
			var w := a - p0
			var t := (w.x * e.y - w.y * e.x) / den
			var u := (w.x * d.y - w.y * d.x) / den
			if t > 0.0 and t < 1.0 and u >= 0.0 and u <= 1.0:
				ts.append(t)
	ts.sort()
	var out: Array = []
	for i in range(ts.size() - 1):
		var ta := ts[i]
		var tb := ts[i + 1]
		if tb - ta < 1e-9 or not _inside(p0 + d * ((ta + tb) * 0.5), polys):
			continue
		if not out.is_empty() and is_equal_approx(out[-1][2], ta):
			out[-1][1] = p0 + d * tb
			out[-1][2] = tb
		else:
			out.append([p0 + d * ta, p0 + d * tb, tb])
	return out


## ¿Está el punto dentro de los polígonos? (regla nonzero de SVG, la de clip-rule por defecto)
static func _inside(p: Vector2, polys: Array) -> bool:
	var wn := 0
	for poly: PackedVector2Array in polys:
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var cross := (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
			if a.y <= p.y:
				if b.y > p.y and cross > 0.0:
					wn += 1
			elif b.y <= p.y and cross < 0.0:
				wn -= 1
	return wn != 0


## Polígonos de una forma de recorte: un <path> (M, L, H, V, Q, C, Z) o un <rect> con esquinas redondeadas. [] si es
## otra cosa o un rectángulo recto (ThorVG lo recorta sin máscara: no hace falta tocarlo).
static func _clip_polygons(inner: String) -> Array:
	if inner.count("<") != 1 or not inner.ends_with("/>") or inner.contains("transform=") or inner.contains("clip-rule="):
		return []
	var a := _attrs(inner)
	if inner.begins_with("<path "):
		return _path_polygons(String(a.get("d", "")))
	if inner.begins_with("<rect "):
		var x := float(a.get("x", "0"))
		var y := float(a.get("y", "0"))
		var w := float(a.get("width", "0"))
		var h := float(a.get("height", "0"))
		var rx := float(a.get("rx", a.get("ry", "0")))
		var ry := float(a.get("ry", a.get("rx", "0")))
		rx = minf(rx, w / 2.0)
		ry = minf(ry, h / 2.0)
		if rx <= 0.0 or ry <= 0.0 or w <= 0.0 or h <= 0.0:
			return []
		var poly := PackedVector2Array()
		var corners := [[x + w - rx, y + ry, -PI / 2.0], [x + w - rx, y + h - ry, 0.0], [x + rx, y + h - ry, PI / 2.0], [x + rx, y + ry, PI]]
		for c: Array in corners:
			for k in CLIP_CORNER_STEPS + 1:
				var ang: float = c[2] + (PI / 2.0) * k / CLIP_CORNER_STEPS
				poly.append(Vector2(c[0] + rx * cos(ang), c[1] + ry * sin(ang)))
		return [poly]
	return []


## Polígonos (uno por subtrayecto) de un trayecto con órdenes M, L, H, V, Q, C y Z, absolutas o relativas, con las curvas
## en CLIP_CURVE_STEPS tramos. [] si hay otras órdenes.
static func _path_polygons(d: String) -> Array:
	var re := RegEx.create_from_string("[A-Za-z]|[-+]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	var tok: Array[String] = []
	for m: RegExMatch in re.search_all(d):
		tok.append(m.get_string())
	var polys: Array = []
	var cur := PackedVector2Array()
	var p := Vector2.ZERO
	var start := Vector2.ZERO
	var cmd := ""
	var i := 0
	while i < tok.size():
		var t := tok[i]
		if t.length() == 1 and t.to_upper() != t.to_lower():
			cmd = t
			i += 1
			if cmd == "Z" or cmd == "z":
				if cur.size() >= 3:
					polys.append(cur)
				cur = PackedVector2Array([start])  # sin M detrás, el subtrayecto siguiente empieza donde empezó este
				p = start
			continue
		var rel := cmd == cmd.to_lower()
		var o := p if rel else Vector2.ZERO
		var need := { "M": 2, "L": 2, "H": 1, "V": 1, "Q": 4, "C": 6 }.get(cmd.to_upper(), -1) as int
		if need < 0 or i + need > tok.size():
			return []
		var v: Array[float] = []
		for k in need:
			v.append(float(tok[i + k]))
		i += need
		match cmd.to_upper():
			"M":
				if cur.size() >= 3:
					polys.append(cur)
				p = o + Vector2(v[0], v[1])
				start = p
				cur = PackedVector2Array([p])
				cmd = "l" if rel else "L"  # los pares que siguen a una M son líneas
			"L":
				p = o + Vector2(v[0], v[1])
				cur.append(p)
			"H":
				p = Vector2(v[0] + (p.x if rel else 0.0), p.y)
				cur.append(p)
			"V":
				p = Vector2(p.x, v[0] + (p.y if rel else 0.0))
				cur.append(p)
			"Q":
				var c := o + Vector2(v[0], v[1])
				var e := o + Vector2(v[2], v[3])
				for k in range(1, CLIP_CURVE_STEPS + 1):
					var u := float(k) / CLIP_CURVE_STEPS
					cur.append(p.lerp(c, u).lerp(c.lerp(e, u), u))
				p = e
			"C":
				var c1 := o + Vector2(v[0], v[1])
				var c2 := o + Vector2(v[2], v[3])
				var e := o + Vector2(v[4], v[5])
				for k in range(1, CLIP_CURVE_STEPS + 1):
					var u := float(k) / CLIP_CURVE_STEPS
					cur.append(p.bezier_interpolate(c1, c2, e, u))
				p = e
	if cur.size() >= 3:
		polys.append(cur)
	return polys


## Posición del </g> que cierra el grupo cuyo contenido empieza en `from` (con grupos anidados), o −1.
static func _group_end(svg: String, from: int) -> int:
	var depth := 1
	var i := from
	while depth > 0:
		var open := svg.find("<g", i)
		var close := svg.find("</g>", i)
		if close < 0:
			return -1
		if open >= 0 and open < close:
			var gt := svg.find(">", open)
			var name_end := svg.substr(open + 2, 1)
			if name_end == " " or name_end == ">" or name_end == "/":
				if gt >= 0 and svg[gt - 1] != "/":
					depth += 1
			i = open + 2
			continue
		depth -= 1
		if depth == 0:
			return close
		i = close + 4
	return -1


## Los hijos de primer nivel de un contenido SVG, cada uno con su texto completo (con sus propios hijos).
static func _top_children(inner: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := inner.length()
	while i < n:
		var lt := inner.find("<", i)
		if lt < 0:
			break
		var gt := inner.find(">", lt)
		if gt < 0:
			break
		if inner[gt - 1] == "/":
			out.append(inner.substr(lt, gt - lt + 1))
			i = gt + 1
			continue
		var name := inner.substr(lt + 1, gt - lt - 1).split(" ")[0]
		var depth := 1
		var j := gt + 1
		while depth > 0 and j < n:
			var nlt := inner.find("<", j)
			var ngt := inner.find(">", nlt) if nlt >= 0 else -1
			if ngt < 0:
				j = n
				break
			if _is_tag(inner, nlt, "</" + name):
				depth -= 1
			elif _is_tag(inner, nlt, "<" + name) and inner[ngt - 1] != "/":
				depth += 1
			j = ngt + 1
		out.append(inner.substr(lt, j - lt))
		i = j
	return out


## ¿Empieza en `at` la etiqueta `prefix` («<g», «</line»…) y no otra más larga («<glyph», «</linearGradient»)?
static func _is_tag(s: String, at: int, prefix: String) -> bool:
	if s.substr(at, prefix.length()) != prefix:
		return false
	var next := s.substr(at + prefix.length(), 1)
	return next == ">" or next == "/" or next == " " or next == "\n" or next == "\t"


static func _url_id(ref: String) -> String:
	return ref.substr(5, ref.length() - 6) if ref.begins_with("url(#") and ref.ends_with(")") else ""


static func _fix_masks(svg: String, grads: Dictionary) -> String:
	var re_mask := RegEx.create_from_string("(?s)(<mask\\b[^>]*>)(.*?)(</mask>)")
	var re_rect := RegEx.create_from_string("<rect\\b([^>]*?)/>")
	var out := PackedStringArray()
	var pos := 0
	for m: RegExMatch in re_mask.search_all(svg):
		out.append(svg.substr(pos, m.get_start() - pos))
		out.append(m.get_string(1))
		var inner := m.get_string(2)
		var p := 0
		for r: RegExMatch in re_rect.search_all(inner):
			out.append(inner.substr(p, r.get_start() - p))
			var attrs := _attrs(r.get_string(1))
			var gid := _url_id(attrs.get("fill", ""))
			out.append(_mask_bands(attrs, grads[gid]) if grads.has(gid) else r.get_string(0))
			p = r.get_end()
		out.append(inner.substr(p))
		out.append(m.get_string(3))
		pos = m.get_end()
	out.append(svg.substr(pos))
	return "".join(out)


## Cada <path> relleno con un degradado lineal en su caja (alineado con los ejes, como los de art.js) cuya caja
## exacta no coincide con la de sus vértices pasa a un degradado nuevo en coordenadas de usuario.
static func _fix_bbox_gradients(svg: String, grads: Dictionary) -> String:
	var re_path := RegEx.create_from_string("<path\\b([^>]*?)/?>")
	var out := PackedStringArray()
	var extra := PackedStringArray()
	var pos := 0
	for m: RegExMatch in re_path.search_all(svg):
		var attrs := _attrs(m.get_string(1))
		var gid := _url_id(attrs.get("fill", ""))
		if not grads.has(gid):
			continue
		var g: Dictionary = grads[gid]
		if g["user"] or not (g["x1"] == g["x2"] or g["y1"] == g["y2"]):
			continue
		var tight := _path_bounds(attrs.get("d", ""), false)
		var loose := _path_bounds(attrs.get("d", ""), true)
		if tight.is_empty() or loose.is_empty() or _same_box(tight, loose):
			continue
		var nid := "%s--caja%d" % [gid, extra.size()]
		var bw := tight[2] - tight[0]
		var bh := tight[3] - tight[1]
		extra.append("<linearGradient id=\"%s\" x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" gradientUnits=\"userSpaceOnUse\">%s</linearGradient>" % [
			nid, _num(tight[0] + float(g["x1"]) * bw), _num(tight[1] + float(g["y1"]) * bh), _num(tight[0] + float(g["x2"]) * bw),
			_num(tight[1] + float(g["y2"]) * bh), g["inner"]])
		out.append(svg.substr(pos, m.get_start() - pos))
		out.append(m.get_string(0).replace("fill=\"url(#%s)\"" % gid, "fill=\"url(#%s)\"" % nid))
		pos = m.get_end()
	if extra.is_empty():
		return svg
	out.append(svg.substr(pos))
	var s := "".join(out)
	var at := s.find("</defs>")
	return s.insert(at, "".join(extra)) if at >= 0 else s


static func _num(v: float) -> String:
	return "%.4f" % v


static func _same_box(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	for i in 4:
		if absf(a[i] - b[i]) > 1e-6:
			return false
	return true


## Caja [xmin, ymin, xmax, ymax] de un trayecto con órdenes M, L, Q y Z (absolutas o relativas): la exacta, con los
## extremos de las curvas, o solo la de los vértices (como la calcula ThorVG). Vacía si hay otras órdenes.
static func _path_bounds(d: String, vertices_only: bool) -> PackedFloat64Array:
	var re := RegEx.create_from_string("[A-Za-z]|[-+]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	var tok: Array[String] = []
	for m: RegExMatch in re.search_all(d):
		tok.append(m.get_string())
	var box: Array[float] = [INF, INF, -INF, -INF]
	var cx := 0.0
	var cy := 0.0
	var sx := 0.0
	var sy := 0.0
	var cmd := ""
	var i := 0
	while i < tok.size():
		var t := tok[i]
		if t.length() == 1 and (t.to_upper() != t.to_lower()):  # una orden
			cmd = t
			i += 1
			if cmd == "Z" or cmd == "z":
				cx = sx
				cy = sy
			continue
		var rel := cmd == cmd.to_lower()
		match cmd.to_upper():
			"M", "L":
				if i + 1 >= tok.size():
					return PackedFloat64Array()
				var x := float(tok[i]) + (cx if rel else 0.0)
				var y := float(tok[i + 1]) + (cy if rel else 0.0)
				i += 2
				if cmd.to_upper() == "M":
					sx = x
					sy = y
					cmd = "l" if rel else "L"  # los pares que siguen a una M son líneas
				_grow(box, x, y)
				cx = x
				cy = y
			"Q":
				if i + 3 >= tok.size():
					return PackedFloat64Array()
				var qx := float(tok[i]) + (cx if rel else 0.0)
				var qy := float(tok[i + 1]) + (cy if rel else 0.0)
				var x := float(tok[i + 2]) + (cx if rel else 0.0)
				var y := float(tok[i + 3]) + (cy if rel else 0.0)
				i += 4
				if not vertices_only:
					for k in 2:  # extremos de la cuadrática en cada eje
						var p0 := cx if k == 0 else cy
						var p1 := qx if k == 0 else qy
						var p2 := x if k == 0 else y
						var den := p0 - 2.0 * p1 + p2
						if den != 0.0:
							var u := (p0 - p1) / den
							if u > 0.0 and u < 1.0:
								var e := (1.0 - u) * (1.0 - u) * p0 + 2.0 * u * (1.0 - u) * p1 + u * u * p2
								if k == 0:
									_grow(box, e, cy)
								else:
									_grow(box, cx, e)
				_grow(box, x, y)
				cx = x
				cy = y
			_:
				return PackedFloat64Array()
	return PackedFloat64Array(box) if box[0] <= box[2] else PackedFloat64Array()


static func _grow(box: Array[float], x: float, y: float) -> void:
	box[0] = minf(box[0], x)
	box[1] = minf(box[1], y)
	box[2] = maxf(box[2], x)
	box[3] = maxf(box[3], y)


## id → { x1, y1, x2, y2, user, stops: [[offset, Color]], inner } de cada linearGradient del SVG.
static func _linear_gradients(svg: String) -> Dictionary:
	var out := {}
	# (un <linearGradient …/> sin paradas no cuenta: el [^>/] impide que se trague el siguiente)
	var re_grad := RegEx.create_from_string("(?s)<linearGradient\\b((?:[^>/]|/(?!>))*)>(.*?)</linearGradient>")
	var re_stop := RegEx.create_from_string("<stop\\b([^>]*?)/?>")
	for g: RegExMatch in re_grad.search_all(svg):
		var a := _attrs(g.get_string(1))
		var stops: Array = []
		for s: RegExMatch in re_stop.search_all(g.get_string(2)):
			var sa := _attrs(s.get_string(1))
			var col := Color.html(sa.get("stop-color", "#000000"))
			col.a = float(sa.get("stop-opacity", "1"))
			stops.append([clampf(float(sa.get("offset", "0")), 0.0, 1.0), col])
		if stops.is_empty():
			continue
		out[a.get("id", "")] = {
			"x1": float(a.get("x1", "0")), "y1": float(a.get("y1", "0")), "x2": float(a.get("x2", "1")),
			"y2": float(a.get("y2", "0")), "user": a.get("gradientUnits", "") == "userSpaceOnUse", "stops": stops,
			"inner": g.get_string(2) }
	return out


static func _attrs(s: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("([A-Za-z_:][-\\w:.]*)=\"([^\"]*)\"")
	for m: RegExMatch in re.search_all(s):
		out[m.get_string(1)] = m.get_string(2)
	return out


## Valor de máscara (luminancia × opacidad) del degradado en t, con los extremos extendidos (spreadMethod="pad").
static func _mask_value(stops: Array, t: float) -> float:
	var c: Color = stops[0][1]
	if t > float(stops[0][0]):
		c = stops[-1][1]
		for i in range(1, stops.size()):
			if t <= float(stops[i][0]):
				var o0: float = stops[i - 1][0]
				var o1: float = stops[i][0]
				c = (stops[i - 1][1] as Color).lerp(stops[i][1], 0.0 if o1 <= o0 else (t - o0) / (o1 - o0))
				break
	return clampf((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a, 0.0, 1.0)


## Las franjas que sustituyen a un <rect> de máscara relleno con el degradado g.
static func _mask_bands(rect: Dictionary, g: Dictionary) -> String:
	var rx := float(rect.get("x", "0"))
	var ry := float(rect.get("y", "0"))
	var rw := float(rect.get("width", "0"))
	var rh := float(rect.get("height", "0"))
	var p1 := Vector2(g["x1"], g["y1"])
	var p2 := Vector2(g["x2"], g["y2"])
	var user: bool = g["user"]
	# Se trabaja en el espacio del degradado (el del usuario o la caja del rectángulo) y se vuelve al final.
	var poly := PackedVector2Array([Vector2(rx, ry), Vector2(rx + rw, ry), Vector2(rx + rw, ry + rh), Vector2(rx, ry + rh)])
	if not user:
		poly = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var to_user := func(p: Vector2) -> Vector2: return p if user else Vector2(rx + p.x * rw, ry + p.y * rh)
	var d := p2 - p1
	var dd := d.dot(d)
	var stops: Array = g["stops"]
	# Valor de cada franja: antes del degradado, las MASK_BANDS de dentro y después.
	var bounds: Array[float] = [-INF]
	var values: Array[float] = [_mask_value(stops, 0.0)]
	if dd > 0.0:
		for i in MASK_BANDS:
			bounds.append(float(i) / MASK_BANDS)
			values.append(_mask_value(stops, (i + 0.5) / MASK_BANDS))
		bounds.append(1.0)
		values.append(_mask_value(stops, 1.0))
	else:
		values[0] = _mask_value(stops, 1.0)  # degradado de longitud cero: el último color
	# Capas opacas de gris (luminancia = valor de máscara), en orden de pintor: la k cubre t ≥ bounds[k] y tapa a la
	# anterior, así cada píxel toma el valor de su franja una sola vez (ThorVG compone en 8 bits: apilar capas
	# semitransparentes acumula su error de redondeo) y en cada borde el antialias funde las dos franjas vecinas.
	var out := PackedStringArray()
	for k in values.size():
		var part := poly if k == 0 else _clip(poly, d, bounds[k] * dd + p1.dot(d))
		if part.size() < 3:
			continue
		var pts := PackedStringArray()
		for p in part:
			var q: Vector2 = to_user.call(p)
			pts.append("%.3f,%.3f" % [q.x, q.y])
		out.append("<polygon points=\"%s\" fill=\"#%s\"/>" % [" ".join(pts), Color(values[k], values[k], values[k]).to_html(false)])
	return "".join(out)


## Recorta un polígono convexo al semiplano p·d ≥ c (Sutherland-Hodgman).
static func _clip(poly: PackedVector2Array, d: Vector2, c: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var fa := a.dot(d) - c
		var fb := b.dot(d) - c
		if fa >= 0.0:
			out.append(a)
		if (fa >= 0.0) != (fb >= 0.0):
			out.append(a.lerp(b, fa / (fa - fb)))
	return out


## Factor por el que hay que multiplicar el tamaño lógico de un dibujo para que cada píxel del SVG caiga en un
## píxel físico: el del estirado de la ventana (canvas_items) y el de la escala de la propia rama. Nunca menos
## de 1 (en pantallas normales se rasteriza a tamaño lógico) ni más de MAX_SCALE.
static func screen_scale(item: CanvasItem, extra := 1.0) -> float:
	var s := 1.0
	if item != null and item.is_inside_tree():
		var t := item.get_screen_transform()
		s = maxf(t.get_scale().x, t.get_scale().y)
	return clampf(s * extra, 1.0, MAX_SCALE)


## Textura del SVG a esa escala, de la caché si ya se pintó. null si ThorVG no lo entiende.
func texture(svg: String, scale := 1.0) -> ImageTexture:
	scale = snappedf(scale, 0.001)  # la misma escala para la clave y para rasterizar
	var key := "%s@%s" % [svg.sha256_text(), var_to_str(scale)]
	if _items.has(key):
		_hits += 1
		var hit: ImageTexture = _items[key]
		var px: int = _pixels[key]
		_items.erase(key)  # pasa a ser el más reciente
		_pixels.erase(key)
		_items[key] = hit
		_pixels[key] = px
		return hit
	_misses += 1
	var tex := rasterize(svg, scale)
	if tex == null:
		return null
	var pixels := tex.get_width() * tex.get_height()
	_items[key] = tex
	_pixels[key] = pixels
	_total_pixels += pixels
	_evict()
	return tex


## Vacía la caché (p. ej. al cambiar el factor de escala de la ventana).
func clear() -> void:
	_items.clear()
	_pixels.clear()
	_total_pixels = 0


## Cuántas texturas hay guardadas.
func size() -> int:
	return _items.size()


## { items, pixels, hits, misses }: para el panel de depuración y los tests.
func stats() -> Dictionary:
	return { "items": _items.size(), "pixels": _total_pixels, "hits": _hits, "misses": _misses }


## Saca las menos usadas hasta caber en los dos límites (siempre queda la última, aunque sola los supere).
func _evict() -> void:
	while _items.size() > 1 and (_items.size() > max_items or _total_pixels > max_pixels):
		var oldest: String = _items.keys()[0]
		_total_pixels -= int(_pixels[oldest])
		_items.erase(oldest)
		_pixels.erase(oldest)
