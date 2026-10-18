## Ilustraciones del laboratorio: port 1:1 de packages/core/src/art.js (1.x), que sigue siendo el oráculo.
##
## Cada función devuelve un grafo de escena: nodos { "tag", "attrs", "children" } con etiquetas SVG y atributos en
## camelCase de React (stopColor, strokeWidth, clipPath…), en el mismo orden que en JavaScript. svg.gd lo escribe
## como SVG (idéntico al del oráculo, byte a byte) y app/common/svg_texture.gd lo rasteriza con ThorVG.
## Sin filtros SVG: el realismo sale de degradados, capas y detalle procedural determinista (core/shared/rng.gd,
## la misma semilla que en art.js). No calcula física: solo pinta resultados del motor (el `res` de compute()).
##
## Para salir idéntico al bit se imita a JavaScript en todo lo que acaba escrito en el SVG:
## - números con Js.js_num_str (String(n)), Js.js_round (Math.round) y Js.to_fixed (toFixed);
## - las operaciones en el mismo orden (cada redondeo cuenta) y las llamadas al aleatorio también;
## - Math.sin, cos, tan, atan2 y pow de V8, portadas al final de este archivo: la libm de cada plataforma difiere
##   de V8 en el último bit en un 3-18 % de los casos, y clawArt escribe coordenadas sin redondear.
## Los puntos son listas [x, y] de float (Vector2 guarda 32 bits y cambiaría los decimales).
## Uso: const Art = preload("res://core/lab/art.gd"); var a := Art.surface_art("madera", { "w": 300, "h": 60 }).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Rng = preload("res://core/shared/rng.gd")
const Looks = preload("res://core/lab/looks.gd")
const Data = preload("res://core/lab/data.gd")
const Format = preload("res://core/shared/format.gd")
const V8 = preload("res://core/shared/v8_math.gd")
## 2.0: el corte de la piel por zonas, con su hueso (no existe en art.js; solo con resultados de la 2.0).
const ArtZones = preload("res://core/lab/art_zones.gd")

const MATERIAL_LOOK = Looks.MATERIAL_LOOK
const SKIN_LAYER_LOOK = Looks.SKIN_LAYER_LOOK
const PAINT_LAYER_LOOK = Looks.PAINT_LAYER_LOOK
const BODY_LOOK = Looks.BODY_LOOK
const CAR_SECTION = Looks.CAR_SECTION
const SKIN_SECTION = Looks.SKIN_SECTION

# ── Grafo de escena ──


## Nodo { tag, attrs, children }. Los hijos se aplanan y se filtran como children.flat(Infinity).filter(Boolean):
## las listas se despliegan y se quitan null, false, 0, NaN y "".
static func h(tag: String, attrs: Dictionary = {}, ...children: Array) -> Dictionary:
	var kids: Array = []
	_flat_into(kids, children)
	return { "tag": tag, "attrs": attrs, "children": kids }


static func _flat_into(out: Array, v: Variant) -> void:
	if v is Array:
		for x: Variant in v:
			_flat_into(out, x)
	elif Js.truthy(v):
		out.append(v)


## Número de un campo como lo compararía JavaScript: ausente (undefined) → NaN, null → 0, booleano → 0 o 1.
static func _num_of(d: Variant, key: String) -> float:
	if d == null or not (d as Dictionary).has(key):
		return NAN
	var v: Variant = d[key]
	match typeof(v):
		TYPE_NIL:
			return 0.0
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(v)
	return NAN


## `v || 0` con un número.
static func _or0(v: Variant) -> float:
	return float(v) if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and Js.truthy(v) else 0.0


## `${d.key}` de una plantilla de JavaScript (undefined y null se escriben tal cual).
static func _tpl_of(d: Dictionary, key: String) -> String:
	if not d.has(key):
		return "undefined"
	var v: Variant = d[key]
	if v == null:
		return "null"
	return _jstr(v)


static func _jstr(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return Js.js_num_str(v)
		TYPE_INT:
			return Js.js_num_str(float(v))
		TYPE_BOOL:
			return "true" if v else "false"
	return str(v)


## Opción de un diccionario de parámetros con su valor por defecto (destructuring con `= def` de JavaScript).
static func _opt(o: Dictionary, key: String, def: Variant) -> Variant:
	var v: Variant = o.get(key)
	return def if v == null else v


# ── Color ──


static func _cl(x: float, a: float, b: float) -> float:
	return maxf(a, minf(b, x))


static func _to_rgb(c: String) -> Array[int]:
	var n := c.substr(1).hex_to_int()
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255]


static func _to_hex(r: float, g: float, b: float) -> String:
	var s := "#"
	for v: float in [r, g, b]:
		s += Js.hex2(int(Js.js_round(_cl(v, 0.0, 255.0))))
	return s.to_upper()


## Mezcla de dos colores #RRGGBB (t = 0 → a; t = 1 → b), en mayúsculas como en art.js.
static func mix(a: String, b: String, t: float) -> String:
	var A := _to_rgb(a)
	var B := _to_rgb(b)
	return _to_hex(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t)


static func lighten(c: String, t: float) -> String:
	return mix(c, "#FFFFFF", t)


static func darken(c: String, t: float) -> String:
	return mix(c, "#000000", t)


static func rgba(c: String, a: float) -> String:
	var rgb := _to_rgb(c)
	return "rgba(%d,%d,%d,%s)" % [rgb[0], rgb[1], rgb[2], Js.js_num_str(a)]


# ── Utilidades SVG ──


static func _r2(v: float) -> float:
	return Js.js_round(v * 100.0) / 100.0


static func _n(v: float) -> String:
	return Js.js_num_str(v)


static func _pts(arr: Array) -> String:
	var out := PackedStringArray()
	for p: Array in arr:
		out.append("%s,%s" % [_n(_r2(p[0])), _n(_r2(p[1]))])
	return " ".join(out)


static func _poly(arr: Array, close := true) -> String:
	var out := PackedStringArray()
	for p: Array in arr:
		out.append("%s %s" % [_n(_r2(p[0])), _n(_r2(p[1]))])
	return "M" + " L".join(out) + (" Z" if close else "")


static func _stops(stops: Array) -> Array:
	var out: Array = []
	for i in stops.size():
		var s: Array = stops[i]
		out.append(h("stop", { "key": i, "offset": s[0], "stopColor": s[1], "stopOpacity": s[2] if s.size() > 2 else 1.0 }))
	return out


## `v ?? def`
static func _nn(v: Variant, def: Variant) -> Variant:
	return def if v == null else v


static func _lin(id: String, stops: Array, g: Dictionary = {}) -> Dictionary:
	var attrs := {
		"id": id, "x1": _nn(g.get("x1"), 0.0), "y1": _nn(g.get("y1"), 0.0), "x2": _nn(g.get("x2"), 0.0),
		"y2": _nn(g.get("y2"), 1.0),
	}
	if Js.truthy(g.get("user")):
		attrs["gradientUnits"] = "userSpaceOnUse"
	return h("linearGradient", attrs, _stops(stops))


static func _rad(id: String, stops: Array, g: Dictionary = {}) -> Dictionary:
	var attrs := { "id": id, "cx": _nn(g.get("cx"), 0.5), "cy": _nn(g.get("cy"), 0.5), "r": _nn(g.get("r"), 0.5) }
	if g.get("fx") != null:
		attrs["fx"] = g["fx"]
		attrs["fy"] = g.get("fy")
	return h("radialGradient", attrs, _stops(stops))


## Destello de 4 puntas (brillo de gema o cristal).
static func sparkle(cx: float, cy: float, r: float) -> String:
	var X := _n(_r2(cx))
	var Y := _n(_r2(cy))
	var top := _n(_r2(cy - r))
	return "M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % [
		X, top, X, Y, _n(_r2(cx + r)), Y, X, Y, X, _n(_r2(cy + r)), X, Y, _n(_r2(cx - r)), Y, X, Y, X, top]


## Línea ondulada horizontal (vetas de madera, fibras).
static func _wavy(x0: float, x1: float, y: float, amp: float, freq: float, phase: float, n := 14) -> String:
	var out: Array = []
	for i in n + 1:
		var x := x0 + ((x1 - x0) * i) / n
		out.append([x, y + amp * V8.js_sin(phase + freq * x) + amp * 0.35 * V8.js_sin(phase * 1.7 + freq * 2.3 * x)])
	return _poly(out, false)


# ════════ MATERIALES ════════


## Cuántos elementos de detalle: max(1, round(k·detail)).
static func _cnt(k: float, detail: float) -> int:
	return int(maxf(1.0, Js.js_round(k * detail)))


static func _sheen(defs: Array, body: Array, id: String, x: float, y: float, w: float, H: float, op: float,
		from := 0.0, to := 0.45) -> void:
	defs.append(_lin("%s-sh" % id, [[0.0, "#FFFFFF", op], [1.0, "#FFFFFF", 0.0]]))
	body.append(h("rect", { "x": x, "y": y + H * from, "width": w, "height": H * (to - from), "fill": "url(#%s-sh)" % id }))


## Rellena el rectángulo (x, y, w, h) con el aspecto del material. `detail` (0-1) reduce el detalle en miniaturas.
## o = { x = 0, y = 0, w, h, uid = "s", detail = 1, rx = 0 }. Devuelve { defs, body }.
static func surface_art(look_id: String, o: Dictionary) -> Dictionary:
	var x: float = _opt(o, "x", 0.0)
	var y: float = _opt(o, "y", 0.0)
	var w: float = o["w"]
	var H: float = o["h"]
	var uid: String = _opt(o, "uid", "s")
	var detail: float = _opt(o, "detail", 1.0)
	var rx: float = _opt(o, "rx", 0.0)
	var L: Dictionary = MATERIAL_LOOK.get(look_id, MATERIAL_LOOK["plastico"])
	var R := Rng.new(Rng.seed_of("%s:%sx%s" % [look_id, _n(Js.js_round(w)), _n(Js.js_round(H))]))
	var id := "%s-%s" % [uid, look_id]
	var defs: Array = [
		_lin("%s-g" % id, [[0.0, lighten(L["base"], 0.08)], [0.55, L["base"]], [1.0, L["lo"]]]),
		h("clipPath", { "id": "%s-c" % id }, h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx })),
	]
	var body: Array = [h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-g)" % id })]
	match String(L["kind"]):
		"skin":
			defs.append(_rad("%s-hl" % id, [[0.0, "#FFFFFF", 0.28], [1.0, "#FFFFFF", 0.0]], { "cx": 0.35, "cy": 0.3, "r": 0.6 }))
			body.append(h("rect", { "x": x, "y": y, "width": w, "height": H, "fill": "url(#%s-hl)" % id }))
			for i in _cnt(4.0, detail):
				var yy := y + H * (0.2 + 0.6 * R.next())
				var amp := 0.6 + R.next()
				var freq := 0.05 + 0.05 * R.next()
				var phase := R.next() * 6.0
				body.append(h("path", {
					"d": _wavy(x, x + w, yy, amp, freq, phase), "stroke": L.get("ink"), "strokeOpacity": 0.18,
					"strokeWidth": 0.5, "fill": "none" }))
			for i in _cnt((w * H) / 55.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 0.25 + R.next() * 0.4
				body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": L.get("ink"), "fillOpacity": 0.28 }))
		"wood":
			var lines := _cnt(H / 3.2, detail)
			for i in lines:
				var yy := y + ((i + 0.5) * H) / lines + (R.next() - 0.5) * 2.0
				var amp := 0.6 + R.next() * 1.6
				var freq := 0.03 + R.next() * 0.04
				var phase := R.next() * 6.0
				var op := 0.25 + R.next() * 0.35
				var sw := 0.4 + R.next() * 1.1
				body.append(h("path", {
					"d": _wavy(x - 2.0, x + w + 2.0, yy, amp, freq, phase), "stroke": L.get("ink"), "strokeOpacity": op,
					"strokeWidth": sw, "fill": "none" }))
			if Js.truthy(L.get("knot")) and detail > 0.6:
				var kx := x + w * (0.25 + 0.5 * R.next())
				var ky := y + H * (0.35 + 0.3 * R.next())
				for k in 4:
					body.append(h("ellipse", {
						"cx": kx, "cy": ky, "rx": 3.0 + k * 2.4, "ry": 1.5 + k * 1.2, "stroke": L.get("ink"),
						"strokeOpacity": 0.45 - k * 0.08, "strokeWidth": 0.7, "fill": L.get("ink") if k == 0 else "none",
						"fillOpacity": 0.5 }))
			if Js.truthy(L.get("lacquer")):
				_sheen(defs, body, id, x, y, w, H, 0.3, 0.0, 0.5)
				body.append(h("rect", { "x": x, "y": y + H * 0.1, "width": w, "height": 0.8, "fill": "#FFFFFF", "fillOpacity": 0.35 }))
		"brushed":
			for i in _cnt(H / 1.1, detail):
				var yy := y + R.next() * H
				var stroke := "#FFFFFF" if R.next() > 0.5 else "#000000"
				var op := 0.04 + R.next() * 0.09
				var sw := 0.3 + R.next() * 0.5
				body.append(h("line", {
					"x1": x, "y1": yy, "x2": x + w, "y2": yy, "stroke": stroke, "strokeOpacity": op, "strokeWidth": sw }))
			defs.append(_lin("%s-sp" % id, [[0.0, "#FFFFFF", 0.0], [0.5, "#FFFFFF", 0.32], [1.0, "#FFFFFF", 0.0]],
				{ "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.0 }))
			body.append(h("rect", { "x": x + w * 0.35, "y": y, "width": w * 0.25, "height": H, "fill": "url(#%s-sp)" % id }))
			if Js.truthy(L.get("tint")):
				body.append(h("rect", { "x": x, "y": y, "width": w, "height": H, "fill": L["tint"], "fillOpacity": 0.12 }))
		"keratin":
			var xx := x + 2.0
			while xx < x + w:
				var x2 := xx + (R.next() - 0.5) * 2.0
				var stroke: String = "#FFFFFF" if R.next() > 0.5 else L["lo"]
				body.append(h("line", {
					"x1": xx, "y1": y, "x2": x2, "y2": y + H, "stroke": stroke, "strokeOpacity": 0.22, "strokeWidth": 0.6 }))
				xx += 3.0 + R.next() * 2.0
			_sheen(defs, body, id, x, y, w, H, 0.35, 0.0, 0.35)
		"plastic":
			for i in _cnt((w * H) / 18.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 0.2 + R.next() * 0.3
				var fill := "#FFFFFF" if R.next() > 0.5 else "#000000"
				var op := 0.1 + R.next() * 0.12
				body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": fill, "fillOpacity": op }))
			_sheen(defs, body, id, x, y, w, H, 0.14, 0.0, 0.3)
		"paint":
			# metalizado: escamas de aluminio en la capa de color; un esmalte liso de época solo tiene "piel de naranja"
			if Js.truthy(L.get("flake")):
				for i in _cnt((w * H) / 10.0, detail):
					var cx := x + R.next() * w
					var cy := y + R.next() * H
					var r := 0.25 + R.next() * 0.45
					var fill: String = L["flake"] if R.next() > 0.3 else "#FFFFFF"
					var op := 0.12 + R.next() * 0.38
					body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": fill, "fillOpacity": op }))
			else:
				for i in _cnt((w * H) / 40.0, detail):
					var cx := x + R.next() * w
					var cy := y + R.next() * H
					var r := 0.6 + R.next() * 0.9
					var op := 0.04 + R.next() * 0.05
					body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": "#FFFFFF", "fillOpacity": op }))
			defs.append(_lin("%s-cc" % id, [[0.0, "#FFFFFF", 0.0], [0.5, "#FFFFFF", 0.22], [1.0, "#FFFFFF", 0.0]]))
			body.append(h("path", {
				"d": "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % [
					_n(x), _n(y + H * 0.18), _n(x + w * 0.5), _n(y - H * 0.05), _n(x + w), _n(y + H * 0.22),
					_n(x + w), _n(y + H * 0.42), _n(x + w * 0.5), _n(y + H * 0.2), _n(x), _n(y + H * 0.4)],
				"fill": "url(#%s-cc)" % id }))
			body.append(h("path", {
				"d": "M%s %s Q%s %s %s %s" % [
					_n(x + w * 0.05), _n(y + H * 0.22), _n(x + w * 0.5), _n(y + H * 0.04), _n(x + w * 0.95), _n(y + H * 0.25)],
				"stroke": "#FFFFFF", "strokeOpacity": 0.45, "strokeWidth": 0.7, "fill": "none" }))
		"copper":
			defs.append(_lin("%s-d" % id, [[0.0, lighten(L["base"], 0.25)], [0.45, L["base"]], [1.0, L["lo"]]],
				{ "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0 }))
			body[0] = h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-d)" % id })
			defs.append(_rad("%s-hl" % id, [[0.0, "#FFFFFF", 0.35], [1.0, "#FFFFFF", 0.0]], { "cx": 0.3, "cy": 0.3, "r": 0.55 }))
			body.append(h("rect", { "x": x, "y": y, "width": w, "height": H, "fill": "url(#%s-hl)" % id }))
			for i in _cnt(H / 1.4, detail):
				var yy := y + R.next() * H
				var y2 := yy + (R.next() - 0.5) * 3.0
				var op := 0.05 + R.next() * 0.07
				body.append(h("line", {
					"x1": x, "y1": yy, "x2": x + w, "y2": y2, "stroke": "#FFFFFF", "strokeOpacity": op, "strokeWidth": 0.4 }))
			for i in _cnt(6.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 0.6 + R.next() * 1.6
				var op := 0.18 + R.next() * 0.15
				body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": L.get("ink"), "fillOpacity": op }))
		"glass":
			body[0] = h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-g)" % id, "fillOpacity": 0.85 })
			body.append(h("polygon", {
				"points": _pts([[x + w * 0.12, y], [x + w * 0.2, y], [x + w * 0.1, y + H], [x + w * 0.02, y + H]]),
				"fill": "#FFFFFF", "fillOpacity": 0.3 }))
			body.append(h("polygon", {
				"points": _pts([[x + w * 0.24, y], [x + w * 0.27, y], [x + w * 0.17, y + H], [x + w * 0.14, y + H]]),
				"fill": "#FFFFFF", "fillOpacity": 0.18 }))
			body.append(h("polygon", {
				"points": _pts([[x + w * 0.66, y], [x + w * 0.74, y], [x + w * 0.64, y + H], [x + w * 0.56, y + H]]),
				"fill": "#FFFFFF", "fillOpacity": 0.12 }))
			body.append(h("rect", { "x": x, "y": y, "width": w, "height": 0.9, "fill": "#FFFFFF", "fillOpacity": 0.7 }))
		"screen":
			defs.append(_lin("%s-rf" % id, [[0.0, "#FFFFFF", 0.12], [1.0, "#FFFFFF", 0.0]], { "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0 }))
			body.append(h("polygon", {
				"points": _pts([[x, y], [x + w * 0.55, y], [x + w * 0.25, y + H], [x, y + H]]), "fill": "url(#%s-rf)" % id }))
			defs.append(_rad("%s-gl" % id, [[0.0, "#4A7BD0", 0.22], [1.0, "#4A7BD0", 0.0]], { "cx": 0.7, "cy": 0.6, "r": 0.5 }))
			body.append(h("rect", { "x": x, "y": y, "width": w, "height": H, "fill": "url(#%s-gl)" % id }))
			body.append(h("rect", { "x": x, "y": y, "width": w, "height": 0.8, "fill": "#FFFFFF", "fillOpacity": 0.3 }))
		"stone":
			var flecks: Array = L["flecks"]
			for i in _cnt((w * H) / 9.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 0.25 + R.next() * R.next() * 1.4
				var fill: String = flecks[int(floorf(R.next() * flecks.size()))]
				var op := 0.35 + R.next() * 0.55
				body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": fill, "fillOpacity": op }))
			for i in _cnt(2.0, detail):
				var yy := y + H * (0.2 + 0.6 * R.next())
				var amp := 2.0 + R.next() * 3.0
				var freq := 0.02 + R.next() * 0.03
				var phase := R.next() * 6.0
				body.append(h("path", {
					"d": _wavy(x, x + w, yy, amp, freq, phase, 10), "stroke": "#FFFFFF", "strokeOpacity": 0.35,
					"strokeWidth": 0.6, "fill": "none" }))
			_sheen(defs, body, id, x, y, w, H, 0.16, 0.0, 0.3)
		"crystal", "diamond":
			var k: bool = L["kind"] == "diamond"
			for i in _cnt(26.0 if k else 14.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var s := 3.0 + R.next() * (8.0 if k else 12.0)
				var p1x := cx + s * (0.6 + R.next() * 0.6)
				var p2x := cx - s * (0.5 + R.next() * 0.6)
				var p2y := cy + s * (0.2 + R.next() * 0.5)
				var fill: String = "#FFFFFF" if R.next() > (0.45 if k else 0.6) else L["lo"]
				var op := 0.07 + R.next() * (0.25 if k else 0.16)
				body.append(h("polygon", {
					"points": _pts([[cx, cy - s], [p1x, cy + s * 0.4], [p2x, p2y]]), "fill": fill, "fillOpacity": op }))
			for i in _cnt(5.0 if k else 2.0, detail):
				var sx := x + R.next() * w
				var sy := y + R.next() * H * 0.8
				var sr := 1.5 + R.next() * 2.5
				body.append(h("path", { "d": sparkle(sx, sy, sr), "fill": "#FFFFFF", "fillOpacity": 0.85 }))
			_sheen(defs, body, id, x, y, w, H, 0.25, 0.0, 0.35)
		"clear":
			body[0] = h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-g)" % id, "fillOpacity": 0.8 })
			body.append(h("rect", {
				"x": x, "y": y + H * 0.15, "width": w, "height": maxf(0.6, H * 0.08), "fill": "#FFFFFF", "fillOpacity": 0.5 }))
		"matte":
			for i in _cnt((w * H) / 12.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 0.2 + R.next() * 0.35
				var fill := "#FFFFFF" if R.next() > 0.5 else "#000000"
				var op := 0.08 + R.next() * 0.1
				body.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": fill, "fillOpacity": op }))
		"lacquer":
			for i in _cnt(H / 4.0, detail):
				var yy := y + R.next() * H
				var amp := 0.5 + R.next()
				var phase := R.next() * 6.0
				body.append(h("path", {
					"d": _wavy(x, x + w, yy, amp, 0.05, phase), "stroke": darken(L["lo"], 0.3), "strokeOpacity": 0.25,
					"strokeWidth": 0.5, "fill": "none" }))
			_sheen(defs, body, id, x, y, w, H, 0.4, 0.0, 0.5)
		"cornea":  # escamas de células muertas, apiladas
			for i in _cnt(w / 5.0, detail):
				var xx := x + R.next() * w
				var yy := y + R.next() * H
				body.append(h("path", {
					"d": "M%s %s q3 %s 6 0" % [_n(_r2(xx - 3.0)), _n(_r2(yy)), _n(_r2(-0.8 - R.next()))], "stroke": L["lo"],
					"strokeOpacity": 0.6, "strokeWidth": 0.5, "fill": "none" }))
			_sheen(defs, body, id, x, y, w, H, 0.35, 0.0, 0.6)
		"cells":  # queratinocitos: células redondeadas con núcleo
			for i in _cnt((w * H) / 14.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 1.0 + R.next() * 0.8
				body.append(h("circle", {
					"cx": _r2(cx), "cy": _r2(cy), "r": _r2(r), "fill": "none", "stroke": L.get("ink"), "strokeOpacity": 0.28,
					"strokeWidth": 0.35 }))
				body.append(h("circle", { "cx": _r2(cx), "cy": _r2(cy), "r": 0.35, "fill": L.get("ink"), "fillOpacity": 0.45 }))
		"collagen":  # haces de colágeno ondulados y capilares arriba (papilas)
			for i in _cnt(H / 2.2, detail):
				var yy := y + R.next() * H
				var amp := 0.8 + R.next() * 1.2
				var freq := 0.08 + R.next() * 0.08
				var phase := R.next() * 6.0
				var stroke: Variant = "#FFFFFF" if R.next() > 0.5 else L.get("ink")
				var op := 0.16 + R.next() * 0.14
				var sw := 0.5 + R.next() * 0.6
				body.append(h("path", {
					"d": _wavy(x, x + w, yy, amp, freq, phase, 18), "stroke": stroke, "strokeOpacity": op, "strokeWidth": sw,
					"fill": "none" }))
			var nv := _cnt(w / 12.0, detail)
			for i in nv:
				var xx := x + ((i + R.next()) * w) / nv
				body.append(h("path", {
					"d": "M%s %s q2 %s 4 0" % [_n(_r2(xx - 2.0)), _n(_r2(y + 0.5)), _n(_r2(3.0 + R.next() * 3.0))],
					"stroke": L.get("vessel"), "strokeOpacity": 0.7, "strokeWidth": 0.6, "fill": "none" }))
		"fat":  # lóbulos de adipocitos
			for i in _cnt((w * H) / 16.0, detail):
				var cx := x + R.next() * w
				var cy := y + R.next() * H
				var r := 1.6 + R.next() * 1.8
				body.append(h("circle", {
					"cx": _r2(cx), "cy": _r2(cy), "r": _r2(r), "fill": "#FFF3C8", "fillOpacity": 0.35, "stroke": L.get("ink"),
					"strokeOpacity": 0.45, "strokeWidth": 0.4 }))
		"fascia":  # lámina brillante de colágeno paralelo
			for i in _cnt(H / 0.9, detail):
				var yy := y + R.next() * H
				var y2 := _r2(yy + (R.next() - 0.5))
				var stroke: String = "#FFFFFF" if R.next() > 0.4 else L["lo"]
				body.append(h("line", {
					"x1": x, "y1": _r2(yy), "x2": x + w, "y2": y2, "stroke": stroke, "strokeOpacity": 0.5, "strokeWidth": 0.35 }))
			_sheen(defs, body, id, x, y, w, H, 0.5, 0.0, 0.7)
		"muscle":  # fibras con estrías
			var nf := _cnt(H / 2.6, detail)
			for i in nf:
				var yy := y + ((i + 0.5) * H) / nf
				body.append(h("line", {
					"x1": x, "y1": _r2(yy), "x2": x + w, "y2": _r2(yy + (R.next() - 0.5) * 1.5), "stroke": L.get("ink"),
					"strokeOpacity": 0.45, "strokeWidth": 0.7 }))
			var xx := x + 1.0
			while xx < x + w:
				body.append(h("line", {
					"x1": _r2(xx), "y1": y, "x2": _r2(xx + (R.next() - 0.5)), "y2": y + H, "stroke": "#FFFFFF",
					"strokeOpacity": 0.06, "strokeWidth": 0.5 }))
				xx += 2.2 + R.next()
	return { "defs": defs, "body": [h("g", { "clipPath": "url(#%s-c)" % id }, body)] }


# ════════ MARCAS: SURCO Y PERFORACIÓN ════════


## Carrocería del coche (material con `body`) de ese id, o null.
static func _car_body(target_id: String) -> Variant:
	return Looks.CAR_BODY.get(target_id)


## Color del fondo del surco en la pintura según la capa alcanzada (se ve la capa de debajo): el color de cada
## coche y, al pasar la pintura, su carrocería (acero o aluminio brillante, plástico gris oscuro).
static func _paint_groove_color(depth_um: float, target_id := "coche") -> String:
	var body: Variant = _car_body(target_id)
	var plastic: bool = body != null and not body["metal"]
	if depth_um > float(Looks.PAINT_LAYERS[-1]["to"]):
		return "#50565E" if plastic else lighten(body["col"] if body != null else "#C3CAD2", 0.45)
	var l: Dictionary = Looks.PAINT_LAYERS[-1]
	for p: Dictionary in Looks.PAINT_LAYERS:
		if depth_um <= float(p["to"]):
			l = p
			break
	var look: Dictionary = MATERIAL_LOOK.get(target_id, MATERIAL_LOOK["coche"])
	match String(l["id"]):
		"barniz":
			return "#F4F1F2"
		"color":
			return lighten(look["base"], 0.12)
		"imprimacion":
			return "#CDD1D5"
	return "#A9AEB4" if plastic else "#76846B"


static func _groove_line(lines: Array, base: Dictionary, attrs: Dictionary) -> void:
	var a := base.duplicate()
	for k: String in attrs:
		a[k] = attrs[k]
	lines.append(h("line", a))


## Surco horizontal de x1 a x2 en la altura y. o = { x1, x2, y, uid = "gv" }. Devuelve { lines, extras, length }:
## las `lines` admiten la animación de trazo (strokeDasharray = length); los `extras` (esquirlas, gotas, fibras)
## aparecen al final.
static func groove_art(target_id: String, res: Dictionary, o: Dictionary) -> Dictionary:
	var x1: float = o["x1"]
	var x2: float = o["x2"]
	var y: float = o["y"]
	var uid: String = _opt(o, "uid", "gv")
	var L: Dictionary = MATERIAL_LOOK.get(target_id, MATERIAL_LOOK["plastico"])
	var R := Rng.new(Rng.seed_of("%s:%s:%s" % [uid, target_id, _tpl_of(res, "verdict")]))
	var length := x2 - x1
	var sev := _cl(_or0(res.get("sev")), 0.0, 1.0)
	var w := 1.2 + sev * 6.5
	var lines: Array = []
	var extras: Array = []
	var base := { "x1": x1, "y1": y, "x2": x2, "y2": y, "strokeLinecap": "round", "strokeDasharray": length }
	var depth := _num_of(res, "depthUm")
	var out := { "lines": lines, "extras": extras, "length": length }
	if Js.truthy(res.get("skin")):
		if not Js.truthy(res.get("scratched")):
			return out
		var red := "#8E1B22" if sev > 0.8 else "#C33A3A"
		_groove_line(lines, base, { "stroke": "#E0707A", "strokeOpacity": 0.35, "strokeWidth": 3.0 + sev * 5.0 })  # enrojecimiento
		if Js.truthy(res.get("bleeds")):
			_groove_line(lines, base, { "stroke": red, "strokeOpacity": 0.85, "strokeWidth": 0.8 + sev * 2.2 })
			var layer: Variant = res.get("layer")
			if Js.truthy(layer) and _jstr(layer).to_lower().contains("grasa"):  # asoma la grasa
				_groove_line(lines, base, { "stroke": "#F1D27A", "strokeOpacity": 0.7, "strokeWidth": 0.6 })
			for i in int(Js.js_round(2.0 + sev * 9.0)):
				var cx := x1 + R.next() * length
				var cy := y + (R.next() - 0.3) * 2.5
				var r := 0.5 + R.next() * sev * 1.6
				extras.append(h("circle", { "cx": cx, "cy": cy, "r": r, "fill": "#A31F29", "fillOpacity": 0.75 }))
			if Js.truthy(res.get("tearing")):  # desgarro: colgajos de piel levantados a los dos lados de la herida
				for i in 6 + int(Js.js_round(sev * 10.0)):
					var cx := x1 + R.next() * length
					var side := 1.0 if R.next() > 0.5 else -1.0
					var s := 1.2 + R.next() * (1.6 + sev * 2.5)
					var y0 := y + side * (1.0 + sev * 1.5)
					# epidermis levantada (más clara) con el borde en carne viva
					extras.append(h("polygon", {
						"points": _pts([[cx, y0], [cx + s * 1.4, y0 + side * s * 0.95], [cx + s * 2.6, y0]]), "fill": "#FCE6DC",
						"fillOpacity": 0.97, "stroke": "#8E1B22", "strokeOpacity": 0.85, "strokeWidth": 0.45 }))
		elif depth > 0.0:
			# sin sangre: raya blanca (capa córnea levantada) o línea en carne viva (epidermis excoriada)
			_groove_line(lines, base, {
				"stroke": "#FFFFFF" if depth <= 20.0 else "#F7C9BF", "strokeOpacity": 0.9,
				"strokeWidth": 0.7 if depth <= 20.0 else 1.3 })
		return out
	if not Js.truthy(res.get("scratched")):
		# Roce sin marca: solo un pulido tenue
		_groove_line(lines, base, { "stroke": "#FFFFFF", "strokeOpacity": 0.18 if depth > 0.01 else 0.08, "strokeWidth": 1.4 })
		return out
	var kind: String = L["kind"]
	var brittle: bool = kind in Looks.BRITTLE
	var metal: bool = kind in Looks.METALLIC
	var car: Variant = _car_body(target_id)
	var inner := ""
	if car != null:
		inner = _paint_groove_color(depth, target_id)
	elif kind == "wood":
		var layer: Variant = res.get("layer")
		var laca := Js.truthy(L.get("lacquer")) and Js.truthy(layer) and _jstr(layer).begins_with("laca")
		inner = "#F3E2BD" if laca else "#F0D39E"
	elif metal:
		inner = lighten(L["base"], 0.55)
	elif brittle:
		inner = "#FFFFFF"
	elif kind == "plastic":
		inner = lighten(L["base"], 0.45)
	else:
		inner = lighten(L["base"], 0.35)
	_groove_line(lines, base, { "stroke": "#000000", "strokeOpacity": 0.35, "strokeWidth": w + 1.4 })  # sombra del surco
	_groove_line(lines, base, {
		"stroke": inner, "strokeOpacity": 0.85 if brittle else 0.95, "strokeWidth": maxf(0.8, w * 0.45) if brittle else w })
	_groove_line(lines, base, {  # labio iluminado
		"stroke": "#FFFFFF", "strokeOpacity": 0.6 if metal else 0.3, "strokeWidth": 0.7, "y1": y - w / 2.0, "y2": y - w / 2.0 })
	if brittle:
		for i in 6 + int(Js.js_round(sev * 14.0)):
			var cx := x1 + R.next() * length
			var up := -1.0 if R.next() > 0.5 else 1.0
			var s := 0.8 + R.next() * (1.0 + sev * 3.0)
			var op := 0.5 + R.next() * 0.4
			extras.append(h("polygon", {
				"points": _pts([[cx, y], [cx + s, y + up * s * 0.9], [cx + s * 1.8, y]]), "fill": "#FFFFFF", "fillOpacity": op }))
			if R.next() > 0.6:
				var lx2 := cx + (R.next() - 0.5) * 8.0
				var ly2 := y + up * (2.0 + R.next() * 5.0)
				extras.append(h("line", {
					"x1": cx, "y1": y, "x2": lx2, "y2": ly2, "stroke": "#FFFFFF", "strokeOpacity": 0.45, "strokeWidth": 0.35 }))
	elif kind == "wood":
		for i in 4 + int(Js.js_round(sev * 10.0)):
			var cx := x1 + R.next() * length
			var ly1 := y + (R.next() - 0.5) * w
			var lx2 := cx + 3.0 + R.next() * 5.0
			var ly2 := y + (R.next() - 0.5) * (w + 3.0)
			extras.append(h("line", {
				"x1": cx, "y1": ly1, "x2": lx2, "y2": ly2, "stroke": "#F5DEB0", "strokeOpacity": 0.8, "strokeWidth": 0.5 }))
	elif metal:
		_groove_line(lines, base, {  # rebaba
			"stroke": darken(L["lo"], 0.35), "strokeOpacity": 0.5, "strokeWidth": 0.6, "y1": y + w / 2.0, "y2": y + w / 2.0 })
	# Desgarro: la garra enganchada arranca material a los lados del surco. Los frágiles no se desgarran: se
	# astillan (ya dibujado arriba).
	if Js.truthy(res.get("tearing")) and not brittle:
		var flap := ""
		if kind == "wood":
			flap = "#F5DEB0"
		elif car != null:
			flap = lighten(L["base"], 0.15)
		elif metal:
			flap = lighten(L["base"], 0.6)
		elif kind == "plastic":
			flap = "#EEF1F4"
		else:
			flap = lighten(L["base"], 0.45)
		for i in 8 + int(Js.js_round(sev * 16.0)):
			var cx := x1 + R.next() * length
			var side := 1.0 if R.next() > 0.5 else -1.0
			var s := 1.0 + R.next() * (1.5 + sev * 3.0)
			var y0 := y + side * w * 0.5
			var py := y0 + side * s * (0.7 + R.next() * 0.7)
			extras.append(h("polygon", {
				"points": _pts([[cx, y0], [cx + s * 1.5, py], [cx + s * 2.6, y0 + side * 0.2]]), "fill": flap,
				"fillOpacity": 0.9, "stroke": "#000000", "strokeOpacity": 0.3, "strokeWidth": 0.3 }))
			if kind == "wood" and R.next() > 0.35:  # fibras largas arrancadas
				var l := 4.0 + R.next() * (5.0 + sev * 6.0)
				extras.append(h("line", {
					"x1": cx + s, "y1": y0, "x2": cx + s + l * 0.9, "y2": y0 + side * l * 0.45, "stroke": "#F5DEB0",
					"strokeOpacity": 0.85, "strokeWidth": 0.45 }))
			if car != null and R.next() > 0.5:  # escamas de pintura saltadas, con la imprimación debajo
				var erx := 0.9 + R.next() * 1.4
				var ery := 0.5 + R.next() * 0.8
				extras.append(h("ellipse", {
					"cx": cx + s, "cy": y0 + side * (s + 1.5), "rx": erx, "ry": ery,
					"fill": _paint_groove_color(85.0, target_id), "fillOpacity": 0.85 }))
		_groove_line(lines, base, {  # borde irregular en sombra
			"stroke": "#000000", "strokeOpacity": 0.25, "strokeWidth": 0.5, "y1": y - w * 0.5, "y2": y - w * 0.5 })
	# Chapa rajada de lado a lado: se ve el hueco oscuro y los bordes doblados hacia dentro
	if Js.truthy(res.get("through")) and not Js.truthy(res.get("puncture")):
		var edge := ""
		if car != null and not car["metal"]:
			edge = "#8A9098"
		else:
			edge = lighten(car["col"] if car != null else L["base"], 0.5)
		_groove_line(lines, base, { "stroke": "#06080B", "strokeOpacity": 0.92, "strokeWidth": maxf(1.2, w * 0.5) })
		for i in 12 + int(Js.js_round(sev * 10.0)):
			var cx := x1 + R.next() * length
			var side := 1.0 if R.next() > 0.5 else -1.0
			var l := 1.5 + R.next() * 3.0
			var ly2 := y + side * (w * 0.28 + 0.8 + R.next() * 1.6)
			extras.append(h("line", {
				"x1": cx, "y1": y + side * w * 0.28, "x2": cx + l, "y2": ly2, "stroke": edge, "strokeOpacity": 0.85,
				"strokeWidth": 0.55 }))
	if Js.truthy(res.get("shattered")):  # la carga partió la hoja de vidrio
		extras.append_array(_crack_art((x1 + x2) / 2.0, y, R))
	return out


## Hoja de vidrio rota alrededor de (cx, cy): grietas radiales, anillos concéntricos y el hueco del impacto. En
## perspectiva (la losa se ve de canto), así que lo vertical se aplasta ×0,3 y nunca se sale de la cara.
static func _crack_art(cx: float, cy: float, R: Rng) -> Array:
	var out: Array = []
	var n_rad := 9.0 + Js.js_round(R.next() * 4.0)
	for i in int(n_rad):
		var a := (i / n_rad) * PI * 2.0 + (R.next() - 0.5) * 0.5
		var sa := absf(V8.js_sin(a) * 0.3)
		var ln := (0.45 + R.next() * 0.55) * (minf(150.0, 15.0 / sa) if sa > 0.01 else 150.0)
		var path: Array = [[cx, cy]]
		for j in range(1, 7):
			var f := j / 6.0
			var jit := (R.next() - 0.5) * 4.0
			path.append([cx + V8.js_cos(a) * ln * f - V8.js_sin(a) * jit, cy + (V8.js_sin(a) * ln * f + V8.js_cos(a) * jit) * 0.3])
		out.append(h("path", { "d": _poly(path, false), "stroke": "#FFFFFF", "strokeOpacity": 0.75, "strokeWidth": 0.55, "fill": "none" }))
	for rr: float in [9.0, 20.0]:
		var ring: Array = []
		for j in 16:
			var a := (j / 16.0) * PI * 2.0
			var r := rr * (0.85 + R.next() * 0.3)
			ring.append([cx + V8.js_cos(a) * r, cy + V8.js_sin(a) * r * 0.3])
		out.append(h("path", { "d": _poly(ring, true), "stroke": "#FFFFFF", "strokeOpacity": 0.5, "strokeWidth": 0.45, "fill": "none" }))
	out.append(h("polygon", {
		"points": _pts([[cx - 3.0, cy - 0.6], [cx - 0.5, cy - 1.6], [cx + 3.2, cy - 0.4], [cx + 1.0, cy + 1.5], [cx - 2.4, cy + 1.0]]),
		"fill": "#0A1418", "fillOpacity": 0.8 }))
	return out


## Hoja de vidrio partida vista en corte (perfil de la huella), en el rectángulo x, y, w × h. Al flexar, la cara
## de atrás trabaja a tracción: las grietas nacen ahí, bajo la carga, y cruzan todo el espesor; en el centro
## salta un trozo. o = { x, y, w, h, seed = "pane" }. Devuelve una lista de nodos.
static func pane_fracture_art(o: Dictionary) -> Array:
	var x: float = o["x"]
	var y: float = o["y"]
	var w: float = o["w"]
	var H: float = o["h"]
	var R := Rng.new(Rng.seed_of(_jstr(_opt(o, "seed", "pane"))))
	var out: Array = []
	var cx := x + w / 2.0
	var n := 7
	for i in n:
		var k := i - (n - 1) / 2.0
		var x0 := cx + k * (w / 10.0) + (R.next() - 0.5) * 6.0
		var path: Array = [[x0, y + H]]
		for j in range(1, 6):
			path.append([x0 + k * j * 0.9 + (R.next() - 0.5) * 6.0, y + H - (H * j) / 5.0])
		out.append(h("path", { "d": _poly(path, false), "stroke": "#FFFFFF", "strokeOpacity": 0.8, "strokeWidth": 0.7, "fill": "none" }))
	out.append(h("polygon", {
		"points": _pts([[cx - 8.0, y + H], [cx - 3.0, y + H * 0.55], [cx + 4.0, y + H * 0.62], [cx + 9.0, y + H]]),
		"fill": "#0A1418", "fillOpacity": 0.55 }))
	return out


# ════════ CORTE DEL COCHE POR CAPAS ════════
# Lienzo 300 × 164: las cuatro capas de pintura (110 µm) ampliadas arriba, la carrocería de verdad debajo
# (0,7-2,5 mm) y, al fondo, el hueco de dentro de la puerta: ahí se ve si la punta se quedó en la pintura, se
# clavó en la chapa, la perforó o la atravesó entera. Dentro de cada zona la escala es lineal.


## carLayers de data.js (la pintura común y, debajo, la carrocería del coche) y fmtDepth de physics.js: los mismos
## de la física (core/lab/data.gd y core/shared/format.gd).
static func _car_layers(target: Dictionary) -> Variant:
	return Data.car_layers(target)


static func _fmt_depth(um: float) -> String:
	return Format.fmt_depth(um)


## Espesor de una capa para los rótulos de los cortes: «45 µm» o «2,1 mm».
static func _thick_label(t: float) -> String:
	return "%s mm" % Js.to_fixed(t / 1000.0, 1).replace(".", ",") if t >= 1000.0 else "%s µm" % _n(t)


## Corte del coche por capas con la huella del resultado. o = { uid = "car" }. Devuelve { defs, body, labels }:
## los rótulos son datos ({ x, y, text, size, color, bold }) que cada app escribe con su tipografía.
static func car_section_art(res: Variant, target: Dictionary, o: Dictionary = {}) -> Dictionary:
	var uid: String = _opt(o, "uid", "car")
	var x := 8.0
	var w := 150.0
	var top := 6.0
	var cx := x + w * 0.42
	var paint_um: float = Looks.PAINT_LAYERS[-1]["to"]
	var body: Dictionary = target["body"]
	var body_t: float = body["t"]
	var L: Array = _car_layers(target)
	var y_paint := top + 64.0
	var y_body := y_paint + 56.0
	var bottom := y_body + 30.0
	var y_of := func(um: float) -> float:
		if um <= paint_um:
			return top + (_cl(um, 0.0, paint_um) / paint_um) * (y_paint - top)
		if um <= paint_um + body_t:
			return y_paint + ((um - paint_um) / body_t) * (y_body - y_paint)
		var past_mm := (um - paint_um - body_t) / 1000.0
		return y_body + (bottom - y_body - 2.0) * (past_mm / (past_mm + 8.0))  # detrás de la chapa: escala que se satura
	var defs: Array = []
	var out: Array = []
	var labels: Array = []
	for l: Dictionary in L:
		var is_body: bool = l["id"] == "carroceria"
		var y0: float = y_of.call(float(l["from"]))
		var y1: float = y_body if is_body else y_of.call(float(l["to"]))
		var look: String = BODY_LOOK[body["id"]] if is_body else PAINT_LAYER_LOOK[l["id"]]
		var a := surface_art(look, { "x": x, "y": y0, "w": w, "h": y1 - y0, "uid": "%s-%s" % [uid, l["id"]], "detail": 0.8 })
		defs.append_array(a["defs"])
		out.append_array(a["body"])
		if y0 > top:
			out.append(h("line", { "x1": x, "y1": y0, "x2": x + w, "y2": y0, "stroke": "#000000", "strokeOpacity": 0.25, "strokeWidth": 0.5 }))
		var t: float = float(l["to"]) - float(l["from"])
		labels.append({
			"x": 166.0, "y": (y0 + y1) / 2.0 + 3.0, "text": "%s · %s" % [l["name"], _thick_label(t)], "size": 8.0,
			"color": Looks.C["text"] if is_body else Looks.C["dim"], "bold": is_body })
	out.append(h("rect", { "x": x, "y": y_body, "width": w, "height": bottom - y_body, "fill": "#0B0E12" }))  # el hueco de la puerta
	labels.append({ "x": 166.0, "y": y_body + 17.0, "text": "detrás: hueco de la puerta", "size": 8.0, "color": Looks.C["dimmer"] })
	out.append(h("rect", { "x": x, "y": top, "width": w, "height": y_body - top, "fill": "none", "stroke": Looks.C["line2"], "strokeWidth": 1.0 }))
	var d := _num_of(res, "depthUm") if res != null else 0.0
	if res != null and d > 0.0 and Js.truthy(res.get("scratched")):
		var dy: float = y_of.call(d)
		var cut := "#101418"
		var gw := _or0(res.get("grooveWidthUm"))
		var through := Js.truthy(res.get("through"))
		var hw := _cl(1.5 + gw / 1000.0 * 0.9, 2.5, 22.0) if through else _cl(1.6 + sqrt(gw) / 6.0, 1.6, 12.0)
		if Js.truthy(res.get("puncture")):
			out.append(h("polygon", {
				"points": _pts([[cx - hw, top], [cx + hw, top], [cx, dy]]), "fill": cut, "fillOpacity": 0.95, "stroke": "#000000",
				"strokeOpacity": 0.4, "strokeWidth": 0.5 }))
		else:
			out.append(h("path", {
				"d": _notch(cx, hw, top, dy), "fill": cut, "fillOpacity": 0.95, "stroke": "#000000", "strokeOpacity": 0.35,
				"strokeWidth": 0.5 }))
		if through:
			# pétalos (o bordes de la raja) doblados hacia dentro, por debajo de la chapa
			var petal := lighten(body["col"], 0.25) if body["metal"] else "#6A7078"
			var ew := minf(hw, 10.0)
			for side: float in [-1.0, 1.0]:
				var xe := cx + side * ew * 0.55
				out.append(h("polygon", {
					"points": _pts([[xe, y_body], [xe + side * 4.0, y_body], [xe + side * 1.2, y_body + 7.0 + ew * 0.3]]),
					"fill": petal, "fillOpacity": 0.95, "stroke": "#000000", "strokeOpacity": 0.4, "strokeWidth": 0.4 }))
		out.append(h("line", {
			"x1": x, "y1": _r2(dy), "x2": x + w, "y2": _r2(dy), "stroke": res.get("vcol"), "strokeWidth": 1.0, "strokeDasharray": "3 2" }))
		var hole := " · Ø %s" % _fmt_depth(gw) if through else ""
		# el rótulo no invade la columna de nombres de capa (x ≥ 166)
		var txt := "≈ %s%s" % [_fmt_depth(d), hole]
		var tw := txt.length() * 5.2 + 6.0
		var tx := minf(cx + 10.0, x + w + 2.0 - tw)
		var ty := _cl(dy + 3.0, top + 8.0, bottom - 2.0)
		out.append(h("rect", { "x": tx - 3.0, "y": ty - 8.0, "width": tw, "height": 11.0, "rx": 3.0, "fill": Looks.C["bg"], "fillOpacity": 0.8 }))
		labels.append({ "x": tx, "y": ty, "text": txt, "size": 8.5, "color": res.get("vcol"), "bold": true })
	return { "defs": defs, "body": out, "labels": labels }


## Muesca de la herida o del arañazo en los cortes (dos cuadráticas hasta la profundidad dy).
static func _notch(cx: float, hw: float, top: float, dy: float) -> String:
	return "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % [
		_n(_r2(cx - hw)), _n(top), _n(_r2(cx - hw * 0.25)), _n(top + 0.5), _n(_r2(cx)), _n(_r2(dy)),
		_n(_r2(cx + hw * 0.25)), _n(top + 0.5), _n(_r2(cx + hw)), _n(top)]


# ════════ CORTE DE LA PIEL POR CAPAS ════════
# Lienzo 300 × 164: bloque de tejido (x 8-158) con una banda por capa de SKIN_LAYERS, alturas fijas para que se vean
# también las finas, y la herida hasta la profundidad del resultado. Dentro de cada banda la escala es lineal. Los
# rótulos se devuelven como datos (labels): cada app los escribe con su tipografía.


## Corte de la piel por capas con la herida del resultado. o = { uid = "sk" }. Devuelve { defs, body, labels }.
## 2.0: con un resultado de otra zona del cuerpo o que llega al hueso, el de art_zones.gd (la 1.x nunca entra ahí).
static func skin_section_art(res: Variant, o: Dictionary = {}) -> Dictionary:
	if ArtZones.applies(res):
		return ArtZones.skin_section_art(res, o)
	var uid: String = _opt(o, "uid", "sk")
	var x := 8.0
	var w := 150.0
	var top := 6.0
	var cx := x + w * 0.42
	var y := top
	var bands: Array = []
	for l: Dictionary in Looks.SKIN_LAYERS:
		var hh: float = _nn(Looks.SKIN_BAND.get(l["id"]), 20.0)
		bands.append({ "l": l, "y0": y, "y1": y + hh })
		y += hh
	var bottom := y
	var y_of := func(um: float) -> float:
		var b: Dictionary = bands[bands.size() - 1]
		for k: Dictionary in bands:
			if um <= float(k["l"]["to"]):
				b = k
				break
		var lf: float = b["l"]["from"]
		var lt: float = b["l"]["to"]
		var y0: float = b["y0"]
		var y1: float = b["y1"]
		return y0 + _cl((um - lf) / (lt - lf), 0.0, 1.0) * (y1 - y0)
	var defs: Array = []
	var body: Array = []
	var labels: Array = []
	for b: Dictionary in bands:
		var l: Dictionary = b["l"]
		var y0: float = b["y0"]
		var y1: float = b["y1"]
		var a := surface_art(SKIN_LAYER_LOOK[l["id"]], { "x": x, "y": y0, "w": w, "h": y1 - y0, "uid": "%s-%s" % [uid, l["id"]], "detail": 0.8 })
		defs.append_array(a["defs"])
		body.append_array(a["body"])
		if y0 > top:
			body.append(h("line", { "x1": x, "y1": y0, "x2": x + w, "y2": y0, "stroke": "#000000", "strokeOpacity": 0.2, "strokeWidth": 0.5 }))
		var t: float = float(l["to"]) - float(l["from"])
		var thick := "" if l["id"] == "musculo" else " · %s" % _thick_label(t)
		var label: String = l["short"] if Js.truthy(l.get("short")) else l["name"]
		labels.append({ "x": 166.0, "y": (y0 + y1) / 2.0 + 3.0, "text": label + thick, "size": 8.0, "color": Looks.C["dim"] })
	body.append(h("rect", { "x": x, "y": top, "width": w, "height": bottom - top, "fill": "none", "stroke": Looks.C["line2"], "strokeWidth": 1.0 }))
	var d := _num_of(res, "depthUm") if res != null else 0.0
	if res != null and d > 0.0:
		var dy: float = y_of.call(d)
		var bleeds := Js.truthy(res.get("bleeds"))
		var wound := "#7E1520" if bleeds else "#FBF1E8"
		var gw := _or0(res.get("grooveWidthUm"))
		if Js.truthy(res.get("puncture")):
			var hw := _cl(1.6 + sqrt(gw) / 9.0, 1.6, 7.0)
			body.append(h("polygon", {
				"points": _pts([[cx - hw, top], [cx + hw, top], [cx, dy]]), "fill": wound, "fillOpacity": 0.95, "stroke": "#000000",
				"strokeOpacity": 0.35, "strokeWidth": 0.5 }))
			if Js.truthy(res.get("inject")):
				body.append(h("ellipse", { "cx": cx, "cy": dy - 1.0, "rx": 3.2, "ry": 2.2, "fill": "#E3D466", "fillOpacity": 0.9 }))
		else:
			var hw := _cl(2.0 + sqrt(gw) / 4.0, 2.5, 26.0)
			body.append(h("path", {
				"d": _notch(cx, hw, top, dy), "fill": wound, "fillOpacity": 0.95, "stroke": "#000000", "strokeOpacity": 0.3,
				"strokeWidth": 0.5 }))
			if Js.truthy(res.get("tearing")):  # bordes desgarrados: fibras arrancadas
				var R := Rng.new(Rng.seed_of("%s:tear" % uid))
				for k in 10:
					var f := (k + 0.5) / 10.0
					var yy := top + (dy - top) * f
					var side := 1.0 if k % 2 else -1.0
					var xx := cx + side * hw * (1.0 - f) * 0.8
					var lx2 := _r2(xx + side * (2.0 + R.next() * 3.0))
					var ly2 := _r2(yy - 1.0 - R.next() * 2.0)
					body.append(h("line", {
						"x1": _r2(xx), "y1": _r2(yy), "x2": lx2, "y2": ly2, "stroke": "#FFFFFF", "strokeOpacity": 0.7, "strokeWidth": 0.5 }))
		if bleeds:
			for k in 3:
				body.append(h("circle", {
					"cx": _r2(cx - 6.0 + k * 6.0), "cy": top - 1.2 + (k % 2) * 0.6, "r": 1.4 - (k % 2) * 0.4, "fill": "#A31F29" }))
		body.append(h("line", {
			"x1": x, "y1": _r2(dy), "x2": x + w, "y2": _r2(dy), "stroke": res.get("vcol"), "strokeWidth": 1.0, "strokeDasharray": "3 2" }))
		var txt := "≈ %s" % _fmt_depth(d)
		var tw := txt.length() * 5.2 + 6.0
		var tx := cx + 10.0
		var ty := _cl(dy + 3.0, top + 8.0, bottom - 2.0)
		body.append(h("rect", { "x": tx - 3.0, "y": ty - 8.0, "width": tw, "height": 11.0, "rx": 3.0, "fill": Looks.C["bg"], "fillOpacity": 0.78 }))
		labels.append({ "x": tx, "y": ty, "text": txt, "size": 8.5, "color": res.get("vcol"), "bold": true })
	return { "defs": defs, "body": body, "labels": labels }


## Marca de punción en (cx, cy) sobre la cara superior. o = { cx, cy, uid = "pc", fangs = false }; `fangs` = dos
## punciones (mordedura). Devuelve { defs, body }.
static func puncture_art(target_id: String, res: Dictionary, o: Dictionary) -> Dictionary:
	var cx: float = o["cx"]
	var cy: float = o["cy"]
	var uid: String = _opt(o, "uid", "pc")
	var fangs: bool = Js.truthy(o.get("fangs"))
	var L: Dictionary = MATERIAL_LOOK.get(target_id, MATERIAL_LOOK["plastico"])
	var R := Rng.new(Rng.seed_of("%s:%s:%s" % [uid, target_id, _tpl_of(res, "verdict")]))
	var sev := _cl(_or0(res.get("sev")), 0.0, 1.0)
	var out: Array = []
	var defs: Array = []
	var at: Array = [cx - 5.0, cx + 5.0] if fangs else [cx]
	if Js.truthy(res.get("skin")):
		for x: float in at:
			if not Js.truthy(res.get("pierces")):
				out.append(h("ellipse", { "cx": x, "cy": cy, "rx": 3.5, "ry": 1.4, "fill": "#C9777A", "fillOpacity": 0.35 }))
				continue
			out.append(h("ellipse", { "cx": x, "cy": cy, "rx": 3.6, "ry": 1.6, "fill": "#E0707A", "fillOpacity": 0.4 }))
			out.append(h("ellipse", { "cx": x, "cy": cy, "rx": 1.3 + sev, "ry": 0.7 + sev * 0.4, "fill": "#7A1016" }))
			out.append(h("circle", {
				"cx": x + 0.6, "cy": cy + 1.6, "r": 0.8, "fill": "#D8C95A" if Js.truthy(res.get("inject")) else "#A31F29",
				"fillOpacity": 0.85 }))
		return { "defs": defs, "body": out }
	var id := "%s-%s-hole" % [uid, target_id]
	if Js.truthy(res.get("shattered")):  # la hoja se ha partido entera
		return { "defs": defs, "body": _crack_art(cx, cy, R) }
	var car: Variant = _car_body(target_id)
	var through := Js.truthy(res.get("through"))
	var gw := _or0(res.get("grooveWidthUm"))
	if through and (car != null or target_id == "puertametal"):
		# Chapa perforada: agujero con 4-6 pétalos doblados hacia dentro (Wierzbicki 1999). Detrás de la puerta de un
		# coche está oscuro; por la de casa entra la luz del otro lado.
		var hole_mm := gw / 1000.0
		var hx := _cl(1.8 + hole_mm * 0.55, 2.2, 12.0)
		var hy := hx * 0.42
		var petal := ""
		if car != null and not car["metal"]:
			petal = "#5A6068"
		else:
			petal = lighten(car["col"] if car != null else L["base"], 0.3)
		defs.append(_rad(id, [
			[0.0, "#040608" if car != null else "#FFF3C4", 1.0 if car != null else 0.95], [0.75, "#000000", 0.75],
			[1.0, "#000000", 0.3]]))
		if car != null:
			out.append(h("ellipse", {
				"cx": cx, "cy": cy, "rx": hx * 1.7, "ry": hy * 1.7,
				"fill": _paint_groove_color(float(Looks.PAINT_LAYERS[-1]["to"]) + 5.0, target_id), "fillOpacity": 0.9 }))
		out.append(h("ellipse", { "cx": cx, "cy": cy, "rx": hx, "ry": hy, "fill": "url(#%s)" % id }))
		var n_p := 4 + int(floorf(R.next() * 3.0))
		for i in n_p:
			var a := (float(i) / n_p) * PI * 2.0 + R.next() * 0.5
			var da := (PI / n_p) * 0.85
			var p1: Array = [cx + V8.js_cos(a - da) * hx, cy + V8.js_sin(a - da) * hy]
			var p2: Array = [cx + V8.js_cos(a + da) * hx, cy + V8.js_sin(a + da) * hy]
			var tip: Array = [cx + V8.js_cos(a) * hx * 0.3, cy + V8.js_sin(a) * hy * 0.3 + hy * 0.55]
			out.append(h("polygon", {
				"points": _pts([p1, tip, p2]), "fill": petal, "fillOpacity": 0.92, "stroke": darken(petal, 0.45),
				"strokeOpacity": 0.7, "strokeWidth": 0.35 }))
		return { "defs": defs, "body": out }
	var rx := 9.0 if through else 1.2 + sev * 5.5
	var ry := rx * 0.42
	if not Js.truthy(res.get("scratched")) and not Js.truthy(res.get("toolBroken")):
		out.append(h("ellipse", { "cx": cx, "cy": cy, "rx": 3.0, "ry": 1.2, "fill": "#000000", "fillOpacity": 0.18 }))
		return { "defs": defs, "body": out }
	defs.append(_rad(id, [
		[0.0, "#FFF3C4" if through else "#000000", 0.95 if through else 0.85], [0.7, "#000000", 0.6], [1.0, "#000000", 0.15]]))
	var kind: String = L["kind"]
	if kind in Looks.BRITTLE:
		for i in 5 + int(Js.js_round(sev * 5.0)):
			var a := R.next() * PI * 2.0
			var l := 3.0 + R.next() * (5.0 + sev * 8.0)
			out.append(h("line", {
				"x1": cx, "y1": cy, "x2": cx + V8.js_cos(a) * l, "y2": cy + V8.js_sin(a) * l * 0.45, "stroke": "#FFFFFF",
				"strokeOpacity": 0.6, "strokeWidth": 0.4 }))
		out.append(h("ellipse", {
			"cx": cx, "cy": cy, "rx": rx * 1.9, "ry": ry * 1.9, "stroke": "#FFFFFF", "strokeOpacity": 0.35, "strokeWidth": 0.4,
			"fill": "none" }))
	if kind == "wood":
		for i in 6 + int(Js.js_round(sev * 8.0)):
			var a := R.next() * PI * 2.0
			var l := rx + 1.0 + R.next() * (3.0 + sev * 4.0)
			out.append(h("line", {
				"x1": cx + V8.js_cos(a) * rx * 0.8, "y1": cy + V8.js_sin(a) * ry * 0.8, "x2": cx + V8.js_cos(a) * l,
				"y2": cy + V8.js_sin(a) * l * 0.45, "stroke": "#F0D39E", "strokeOpacity": 0.85, "strokeWidth": 0.6 }))
	if kind in Looks.METALLIC:
		out.append(h("ellipse", { "cx": cx, "cy": cy, "rx": rx + 1.2, "ry": ry + 0.6, "fill": lighten(L["base"], 0.5), "fillOpacity": 0.7 }))
	out.append(h("ellipse", { "cx": cx, "cy": cy, "rx": rx, "ry": ry, "fill": "url(#%s)" % id }))
	if car != null:
		out.append(h("ellipse", {
			"cx": cx, "cy": cy + ry * 0.2, "rx": rx * 0.5, "ry": ry * 0.45,
			"fill": _paint_groove_color(_num_of(res, "depthUm"), target_id), "fillOpacity": 0.9 }))
	return { "defs": defs, "body": out }


# ════════ GEMAS Y TACHUELAS ════════


## Gema tallada (8 facetas y un destello) o tachuela metálica pulida, de radio r en (cx, cy). Devuelve { defs, body }.
static func gem_art(inlay: Dictionary, cx: float, cy: float, r: float, uid := "gem") -> Dictionary:
	var id := "%s-%s" % [uid, inlay["id"]]
	var col: String = inlay["col"]
	if inlay["id"] in Looks.METAL_INLAYS:
		return {
			"defs": [_rad("%s-m" % id, [[0.0, lighten(col, 0.7)], [0.45, col], [1.0, darken(col, 0.5)]], { "cx": 0.35, "cy": 0.3, "r": 0.75 })],
			"body": [
				h("circle", { "cx": cx, "cy": cy, "r": r, "fill": "url(#%s-m)" % id, "stroke": darken(col, 0.45), "strokeWidth": maxf(0.3, r * 0.08) }),
				h("ellipse", { "cx": cx - r * 0.3, "cy": cy - r * 0.35, "rx": r * 0.35, "ry": r * 0.2, "fill": "#FFFFFF", "fillOpacity": 0.7 }),
			],
		}
	var dark := "#8FA9CC" if col == "#FFFFFF" else darken(col, 0.35)
	var out: Array = []
	var G: Array = []
	var T: Array = []
	for i in 8:
		var a := (i / 8.0) * PI * 2.0 + PI / 8.0
		G.append([cx + V8.js_cos(a) * r, cy + V8.js_sin(a) * r])
		T.append([cx + V8.js_cos(a) * r * 0.55, cy + V8.js_sin(a) * r * 0.55])
	for i in 8:
		var j := (i + 1) % 8
		out.append(h("polygon", {
			"points": _pts([G[i], G[j], T[j], T[i]]), "fill": lighten(col, 0.25) if i % 2 else mix(col, dark, 0.55),
			"stroke": "#FFFFFF", "strokeOpacity": 0.55, "strokeWidth": maxf(0.2, r * 0.04) }))
	out.append(h("polygon", {
		"points": _pts(T), "fill": lighten(col, 0.4), "stroke": "#FFFFFF", "strokeOpacity": 0.7, "strokeWidth": maxf(0.2, r * 0.04) }))
	out.append(h("path", { "d": sparkle(cx + r * 0.25, cy - r * 0.3, r * 0.55), "fill": "#FFFFFF", "fillOpacity": 0.95 }))
	return { "defs": [], "body": out }


# ════════ UÑA (vista frontal, viewBox 0 0 100 168) ════════


## Colores de la placa de cada material de uña (muestras de color de la interfaz).
static func nail_swatch(base_id: String) -> Array:
	return Looks.NAIL_LOOK.get(base_id, Looks.NAIL_LOOK["natural"])["bed"]


## Uña de frente sobre la yema del dedo. o = { geom, base, inlay, wet = false, uid = "nail" } (diccionarios de
## catálogo con las claves de data.js). Devuelve { defs, body }.
static func nail_art(o: Dictionary) -> Dictionary:
	var geom: Dictionary = o["geom"]
	var base: Dictionary = o["base"]
	var inlay: Variant = o.get("inlay")
	var wet: bool = Js.truthy(o.get("wet"))
	var uid: String = _opt(o, "uid", "nail")
	var N: Dictionary = Looks.NAIL_LOOK.get(base["id"], Looks.NAIL_LOOK["natural"])
	var id := "%s-%s-%s" % [uid, geom["id"], base["id"]]
	var tip_y := 84.0  # punta del dedo (hiponiquio): por encima empieza el borde libre
	var bed: Array = N["bed"]
	var defs: Array = [
		_lin("%s-skin" % id, [[0.0, "#C9876E"], [0.22, "#EDB9A0"], [0.55, "#F3C7B0"], [1.0, "#C07A62"]], { "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.0 }),
		_lin("%s-bed" % id, [[0.0, bed[0]], [1.0, bed[1]]]),
		_lin("%s-gl" % id, [[0.0, "#FFFFFF", _nn(N.get("gloss"), 0.5)], [1.0, "#FFFFFF", 0.0]]),
		h("clipPath", { "id": "%s-nc" % id }, h("path", { "d": geom["path"] })),
	]
	# curvatura en C: la placa es un tubo abierto (bordes en sombra, centro iluminado)
	defs.append(_lin("%s-cc" % id, [
		[0.0, "#000000", 0.28], [0.18, "#000000", 0.06], [0.42, "#FFFFFF", 0.08], [0.62, "#000000", 0.0], [1.0, "#000000", 0.3]],
		{ "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.0 }))
	var R := Rng.new(Rng.seed_of(id))
	var ridges: Variant = null
	if Js.truthy(N.get("ridges")):
		ridges = []
		for rx: float in [36.0, 43.0, 50.0, 57.0, 64.0]:
			ridges.append(h("line", {
				"key": rx, "x1": rx, "y1": 20.0, "x2": rx + 0.5, "y2": 140.0, "stroke": "#FFFFFF", "strokeOpacity": 0.18, "strokeWidth": 0.6 }))
	var brushed: Variant = null
	if Js.truthy(N.get("brushed")):
		brushed = []
		for i in 40:
			var yy := 4.0 + i * 3.6 + R.next() * 2.0
			var y2 := yy + (R.next() - 0.5)
			var stroke := "#FFFFFF" if R.next() > 0.5 else "#000000"
			var op := 0.06 + R.next() * 0.1
			brushed.append(h("line", {
				"key": "b%d" % i, "x1": 20.0, "y1": yy, "x2": 80.0, "y2": y2, "stroke": stroke, "strokeOpacity": op, "strokeWidth": 0.5 }))
	var facets: Variant = null
	if Js.truthy(N.get("facets")):
		facets = []
		for i in 16:
			var fx := 28.0 + R.next() * 44.0
			var fy := 10.0 + R.next() * 130.0
			var sz := 5.0 + R.next() * 9.0
			var fill: String = "#FFFFFF" if R.next() > 0.5 else darken(bed[1], 0.2)
			var op := 0.1 + R.next() * 0.2
			facets.append(h("polygon", {
				"key": "f%d" % i, "points": _pts([[fx, fy - sz], [fx + sz * 0.8, fy + sz * 0.5], [fx - sz * 0.7, fy + sz * 0.4]]),
				"fill": fill, "fillOpacity": op }))
	var sparkles: Variant = null
	if Js.truthy(N.get("sparkles")):
		sparkles = []
		var list := [[58.0, 40.0, 4.0], [44.0, 96.0, 3.0], [60.0, 118.0, 2.4]]
		for i in list.size():
			var s: Array = list[i]
			sparkles.append(h("path", { "key": "s%d" % i, "d": sparkle(s[0], s[1], s[2]), "fill": "#FFFFFF", "fillOpacity": 0.95 }))
	var body: Array = [
		# dedo con sombreado cilíndrico y pliegues
		h("path", { "d": "M22 168 L22 104 Q22 78 50 76 Q78 78 78 104 L78 168 Z", "fill": "url(#%s-skin)" % id }),
		h("path", { "d": "M30 158 Q50 152 70 158", "stroke": "#A8664F", "strokeOpacity": 0.35, "strokeWidth": 0.8, "fill": "none" }),
		h("path", { "d": "M34 163 Q50 158 66 163", "stroke": "#A8664F", "strokeOpacity": 0.25, "strokeWidth": 0.7, "fill": "none" }),
		# placa de la uña (recortada a la forma)
		h("g", { "clipPath": "url(#%s-nc)" % id }, [
			h("rect", { "x": 0.0, "y": 0.0, "width": 100.0, "height": 168.0, "fill": "url(#%s-bed)" % id }),
			h("path", {
				"d": "M0 0 L100 0 L100 %s Q50 %s 0 %s Z" % [_n(tip_y + 2.0), _n(tip_y - 8.0), _n(tip_y + 2.0)], "fill": N["edge"],
				"fillOpacity": N["edgeOp"] }),
			h("ellipse", { "cx": 50.0, "cy": 136.0, "rx": 17.0, "ry": 9.0, "fill": "#FFF4F2", "fillOpacity": 0.55 })
				if Js.truthy(N.get("lunula")) else null,
			ridges,
			brushed,
			facets,
			h("rect", { "x": 0.0, "y": 0.0, "width": 100.0, "height": 168.0, "fill": "url(#%s-cc)" % id }),
			h("path", { "d": "M34 150 L34 40 Q36 30 40 28 L42 150 Z", "fill": "url(#%s-gl)" % id }),
			h("ellipse", { "cx": 40.0, "cy": 48.0, "rx": 2.4, "ry": 5.0, "fill": "#FFFFFF", "fillOpacity": 0.55 }),
			sparkles,
		]),
		h("path", { "d": geom["path"], "fill": "none", "stroke": darken(bed[1], 0.25), "strokeOpacity": 0.55, "strokeWidth": 0.9 }),
		# pliegue proximal (cutícula) que tapa la base de la uña
		h("path", { "d": "M24 168 L24 140 Q50 126 76 140 L76 168 Z", "fill": "#E7AE95" }),
		h("path", { "d": "M26 140 Q50 127 74 140", "stroke": "#C98770", "strokeWidth": 1.1, "fill": "none" }),
	]
	if Js.truthy(inlay) and inlay["id"] != "none":
		# pedrería decorativa en abanico junto a la cutícula (solo adorno: la que araña es la de la punta)
		var small := _cl(sqrt(float(inlay["area"])) * 5.5, 2.2, 3.8)
		for p: Array in [[50.0, 118.0, 1.0], [41.5, 114.0, 0.8], [58.5, 114.0, 0.8], [35.0, 106.0, 0.62], [65.0, 106.0, 0.62], [50.0, 104.0, 0.7]]:
			var g := gem_art(inlay, p[0], p[1], small * p[2], "%s-p%s%s" % [id, _n(p[0]), _n(p[1])])
			defs.append_array(g["defs"])
			body.append_array(g["body"])
		var g := gem_art(inlay, 50.0, float(geom["ay"]) + 10.0, _cl(sqrt(float(inlay["area"])) * 10.0, 3.4, 8.0), id)
		defs.append_array(g["defs"])
		body.append_array(g["body"])
	if wet:
		body.append(h("path", { "d": geom["path"], "fill": "#9FD8FF", "fillOpacity": 0.12 }))
		body.append_array(_wet_drops(id, [[40.0, 70.0, 3.2], [60.0, 100.0, 2.4], [30.0, 124.0, 2.8], [66.0, 132.0, 2.0]]))
	return { "defs": defs, "body": body }


static func _wet_drops(_id: String, list: Array) -> Array:
	var out: Array = []
	for i in list.size():
		var x: float = list[i][0]
		var y: float = list[i][1]
		var r: float = list[i][2]
		out.append(h("g", { "key": "d%d" % i }, [
			h("ellipse", {
				"cx": x, "cy": y, "rx": r, "ry": r * 1.15, "fill": "#DDF3FF", "fillOpacity": 0.45, "stroke": "#FFFFFF",
				"strokeOpacity": 0.7, "strokeWidth": 0.4 }),
			h("ellipse", { "cx": x - r * 0.3, "cy": y - r * 0.4, "rx": r * 0.3, "ry": r * 0.22, "fill": "#FFFFFF", "fillOpacity": 0.9 }),
		]))
	return out


## Punta de dedo vista de lado, con la punta de la uña en (0, 0) y el dedo hacia arriba-izquierda (banco y ficha).
## o = { geom = null, base, inlay, wet = false, uid = "nside" }. Devuelve { defs, body, tip }.
static func nail_side_art(o: Dictionary) -> Dictionary:
	var geom: Variant = o.get("geom")
	var base: Dictionary = o["base"]
	var inlay: Variant = o.get("inlay")
	var wet: bool = Js.truthy(o.get("wet"))
	var uid: String = _opt(o, "uid", "nside")
	var N: Dictionary = Looks.NAIL_LOOK.get(base["id"], Looks.NAIL_LOOK["natural"])
	var bed: Array = N["bed"]
	var id := "%s-%s-%s" % [uid, base["id"], geom["id"] if geom != null else "x"]
	# u: a lo largo del dedo hacia la punta · v: hacia el dorso. La uña ataca la superficie a 35°. El borde libre y
	# su curva de pinza dependen de la forma: la Stiletto XL es larga y se curva hacia abajo como una garra.
	var th := (35.0 * PI) / 180.0
	var c := V8.js_cos(th)
	var sn := V8.js_sin(th)
	var free: float = 16.0 + float(geom["reach"]) * 2.4 if geom != null else 28.0
	var curl: float = float(geom["curl"]) if geom != null else 0.5
	var u0 := -(free + 36.0)  # cutícula
	var v_bot := func(u: float) -> float:
		if u < -free:
			return 0.3
		var q := (u + free) / free
		return 0.3 - (2.0 + 9.0 * curl) * (q * q)  # q ** 2 (V8 lo calcula como q·q)
	var thick := func(u: float) -> float:
		return 3.3 if u < -free else 3.3 - 2.1 * ((u + free) / free)
	var tip_v: float = v_bot.call(0.0) + thick.call(0.0) * 0.5
	var P := func(u: float, v: float) -> Array:
		return [(u - 0.0) * c + (v - tip_v) * sn, (u - 0.0) * sn - (v - tip_v) * c]
	var shape := func(list: Array) -> String:
		var pts: Array = []
		for p: Array in list:
			pts.append(P.call(p[0], p[1]))
		return _poly(pts)
	var plate := func(a: float, b: float) -> String:
		var top: Array = []
		var bot: Array = []
		for i in 19:
			var u := a + ((b - a) * i) / 18.0
			top.append([u, v_bot.call(u) + thick.call(u)])
			bot.append([u, v_bot.call(u)])
		bot.reverse()
		return shape.call(top + bot)
	var fc := -free - 1.0  # yema: centro del arco
	var tip_arc: Array = []
	var ang := 90
	while ang >= -90:
		tip_arc.append([fc + 11.0 * V8.js_cos((ang * PI) / 180.0), -10.5 + 10.8 * V8.js_sin((ang * PI) / 180.0)])
		ang -= 15
	var back := u0 - 96.0
	# El dedo se difumina hacia atrás (máscara), así entra en escena sin un corte seco en el banco.
	var f0: Array = P.call(back, -10.0)
	var f1: Array = P.call(u0 - 28.0, -10.0)
	var defs: Array = [
		_lin("%s-sk" % id, [[0.0, "#F4CDB8"], [0.6, "#E9AF96"], [1.0, "#C4806A"]]),
		_lin("%s-nl" % id, [[0.0, lighten(bed[0], 0.12)], [1.0, bed[1]]]),
		_lin("%s-fg" % id, [[0.0, "#FFFFFF", 0.0], [1.0, "#FFFFFF", 1.0]], {
			"user": true, "x1": _r2(f0[0]), "y1": _r2(f0[1]), "x2": _r2(f1[0]), "y2": _r2(f1[1]) }),
		h("mask", { "id": "%s-fade" % id, "maskUnits": "userSpaceOnUse", "x": -420.0, "y": -320.0, "width": 460.0, "height": 360.0 },
			[h("rect", { "x": -420.0, "y": -320.0, "width": 460.0, "height": 360.0, "fill": "url(#%s-fg)" % id })]),
	]
	var skin_list: Array = [[back, 0.3]]
	skin_list.append_array(tip_arc)
	skin_list.append([back, -21.3])
	var mid := -free * 0.55
	var body: Array = [
		h("path", { "d": shape.call(skin_list), "fill": "url(#%s-sk)" % id }),
		h("path", {
			"d": shape.call([[fc - 14.0, -21.2], [fc - 7.0, -20.8], [fc, -21.2]]), "stroke": "#B8735B", "strokeOpacity": 0.35,
			"strokeWidth": 0.6, "fill": "none" }),
		h("path", { "d": plate.call(u0, 0.0), "fill": "url(#%s-nl)" % id, "stroke": darken(bed[1], 0.25), "strokeOpacity": 0.6, "strokeWidth": 0.5 }),
		h("path", { "d": plate.call(-free - 2.0, 0.0), "fill": N["edge"], "fillOpacity": N["edgeOp"] }),
		h("path", {
			"d": shape.call([
				[u0 + 4.0, 3.1], [-free, 3.2], [mid, v_bot.call(mid) + thick.call(mid) - 0.3], [-5.0, v_bot.call(-5.0) + thick.call(-5.0) - 0.4]]),
			"stroke": "#FFFFFF", "strokeOpacity": 0.6, "strokeWidth": 0.8, "fill": "none" }),
		h("path", {
			"d": shape.call([[back - 2.0, 0.2], [u0 - 4.0, -0.4], [u0 + 2.0, 1.6], [u0 + 3.5, 4.4], [u0 - 2.0, 6.6], [back - 2.0, 6.0]]),
			"fill": "#E3A58C" }),
		h("path", {
			"d": shape.call([[u0, 6.2], [u0 + 3.2, 4.4], [u0 + 2.4, 1.4]]), "stroke": "#B8735B", "strokeOpacity": 0.55,
			"strokeWidth": 0.7, "fill": "none" }),
	]
	if Js.truthy(inlay) and inlay["id"] != "none":
		var gp: Array = P.call(-5.0, v_bot.call(-5.0) + thick.call(-5.0) + 1.2)
		var g := gem_art(inlay, gp[0], gp[1], 3.2, id)
		defs.append_array(g["defs"])
		body.append_array(g["body"])
	if wet:
		var d1: Array = P.call(u0 + 22.0, 5.6)
		var d2: Array = P.call(-free + 6.0, 4.4)
		body.append_array(_wet_drops(id, [[d1[0], d1[1], 2.2], [d2[0], d2[1], 1.6]]))
	return { "defs": defs, "body": [h("g", { "mask": "url(#%s-fade)" % id }, body)], "tip": { "x": 0.0, "y": 0.0 } }


# ════════ GARRAS, TALONES, ESPOLONES Y COLMILLOS (viewBox 0 0 100 132) ════════


## Geometría de la garra: línea media en arco (curvatura) y grosor según afilado (área) y semiángulo α.
static func _claw_geometry(claw: Dictionary, art: Dictionary) -> Dictionary:
	var fang: bool = art["kind"] == "fang"
	var curve: float = claw["curve"]
	var theta := ((55.0 + 45.0 * curve if fang else 35.0 + 115.0 * curve) * PI) / 180.0
	var phi0 := -PI / 2.0 - 0.15 * theta
	var N := 40
	var Lm := 100.0
	var P: Array = []
	var phi: Array = []
	var x := 0.0
	var y := 0.0
	for i in N + 1:
		var a := phi0 + (theta * i) / N
		P.append([x, y])
		phi.append(a)
		x += (Lm / N) * V8.js_cos(a)
		y += (Lm / N) * V8.js_sin(a)
	var w_tip := _cl(sqrt(float(claw["area"])) * 5.0, 0.35, 3.2)
	var taper := V8.js_tan((_cl(float(claw["alpha"]), 10.0, 40.0) * PI) / 180.0)
	var w0: float = art["w0"]
	var dors: Array = []
	var vent: Array = []
	var ws: Array = []
	for i in N + 1:
		var s := float(i) / N
		var w := maxf(w_tip, minf(w0 * V8.js_pow(1.0 - s, 0.65), w_tip + (1.0 - s) * Lm * taper))
		var a: float = phi[i]
		var nx := -V8.js_sin(a)  # normal hacia el centro de curvatura (cara ventral)
		var ny := V8.js_cos(a)
		ws.append(w)
		dors.append([P[i][0] - nx * w * 1.08, P[i][1] - ny * w * 1.08])
		vent.append([P[i][0] + nx * w * 0.92, P[i][1] + ny * w * 0.92])
	var a_t: float = phi[N]
	var tip: Array = [P[N][0] + V8.js_cos(a_t) * w_tip, P[N][1] + V8.js_sin(a_t) * w_tip]
	return { "P": P, "phi": phi, "dors": dors, "vent": vent, "ws": ws, "tip": tip, "wTip": w_tip, "N": N }


## Del lienzo de la garra al viewBox (escala k y desplazamiento); "down" la da la vuelta (punta abajo).
static func _claw_t(p: Array, ox: float, oy: float, k: float, down: bool) -> Array:
	var x: float = ox + p[0] * k
	var y: float = oy + p[1] * k
	return [100.0 - x, 132.0 - y] if down else [x, y]


## Garra o colmillo. o = { inlay = null, uid = "claw", tipColor = null, orient, drop = false }; orient "up": base
## abajo y punta arriba (ficha); "down": colgando, punta abajo (colmillo en la ficha y herramienta del banco).
## Devuelve { defs, body, tip: { x, y }, tipAngle }.
static func claw_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var inlay: Variant = o.get("inlay")
	var uid: String = _opt(o, "uid", "claw")
	var tip_color: Variant = o.get("tipColor")
	var drop: bool = Js.truthy(o.get("drop"))
	var art: Dictionary = Looks.CLAW_ART.get(claw["id"], Looks.CLAW_ART_DEFAULT)
	var fang: bool = art["kind"] == "fang"
	var orient: String = o["orient"] if Js.truthy(o.get("orient")) else ("down" if fang else "up")
	var down := orient == "down"
	var g := _claw_geometry(claw, art)
	var n: int = g["N"]
	# Ajuste al viewBox: escala uniforme para que la garra quepa entre y 10 y la base en y 112.
	var all: Array = []
	all.append_array(g["dors"])
	all.append_array(g["vent"])
	all.append(g["tip"])
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p: Array in all:
		min_x = minf(min_x, p[0])
		max_x = maxf(max_x, p[0])
		min_y = minf(min_y, p[1])
		max_y = maxf(max_y, p[1])
	var k := minf(80.0 / (max_x - min_x), 96.0 / (max_y - min_y))
	var ox := 50.0 - ((min_x + max_x) / 2.0) * k
	var oy := 112.0 - max_y * k
	var D: Array = []
	for p: Array in g["dors"]:
		D.append(_claw_t(p, ox, oy, k, down))
	var V: Array = []
	for p: Array in g["vent"]:
		V.append(_claw_t(p, ox, oy, k, down))
	var CL: Array = []
	for p: Array in g["P"]:
		CL.append(_claw_t(p, ox, oy, k, down))
	var tip := _claw_t(g["tip"], ox, oy, k, down)
	var base := _claw_t([0.0, 0.0], ox, oy, k, down)
	# Garra o colmillo "reforjados" en otro material: misma forma, pintados en ese material
	var forged: Variant = inlay if Js.truthy(inlay) and inlay["id"] != "none" else null
	var id := "%s-%s%s" % [uid, claw["id"], "-%s" % forged["id"] if forged != null else ""]
	var ivory := Js.truthy(art.get("ivory"))
	var pale := forged == null and (ivory or fang)
	var col: String = forged["col"] if forged != null else claw["col"]
	var light := ""
	var dark := ""
	if forged != null:
		light = lighten(col, 0.6)
		dark = darken(col, 0.45)
	elif ivory:
		light = "#FBF3E6"
		dark = "#D9C6AA"
	elif fang:
		light = "#F5EEE2"
		dark = "#E8DCC6"
	else:
		light = lighten(col, 0.28)
		dark = darken(col, 0.35)
	var defs: Array = [_lin("%s-k" % id, [
		[0.0, light], [0.6, mix(light, dark, 0.5) if pale else col], [1.0, "#FFFDF8" if pale else dark]],
		{ "user": true, "x1": base[0], "y1": base[1], "x2": tip[0], "y2": tip[1] })]
	var ring: Array = D.duplicate()
	ring.append(tip)
	var v_rev := V.duplicate()
	v_rev.reverse()
	ring.append_array(v_rev)
	var outline := _poly(ring)
	var body: Array = []
	# Base anatómica: lo de detrás se pinta antes que la garra y el mechón delantero, después
	var toe := _toe_art(art, base, orient, id, defs, k * float(art["w0"]), tip)
	body.append_array(toe["back"])
	# Garra: relleno, cara ventral en sombra, estrías de crecimiento y brillo dorsal
	body.append(h("path", {
		"d": outline, "fill": "url(#%s-k)" % id, "fillOpacity": 0.96 if pale else 1.0, "stroke": darken(dark if pale else col, 0.35),
		"strokeOpacity": 0.6, "strokeWidth": 0.7 }))
	var shade: Array = CL.slice(0, n)
	var v_part := V.slice(0, n)
	v_part.reverse()
	shade.append_array(v_part)
	body.append(h("path", { "d": _poly(shade), "fill": "#000000", "fillOpacity": 0.1 if pale else 0.22 }))
	var P: Array = g["P"]
	var phi: Array = g["phi"]
	var ws: Array = g["ws"]
	if forged == null:  # estrías: solo en queratina
		for f: float in [-0.55, -0.15, 0.3]:
			var line: Array = []
			for j in range(3, int(Js.js_round(n * 0.86))):
				var a: float = phi[j]
				var w: float = ws[j]
				line.append(_claw_t([P[j][0] - V8.js_sin(a) * w * f, P[j][1] + V8.js_cos(a) * w * f], ox, oy, k, down))
			body.append(h("path", {
				"d": _poly(line, false), "stroke": darken(dark if pale else col, 0.3), "strokeOpacity": 0.22, "strokeWidth": 0.45, "fill": "none" }))
	var hl: Array = []
	for j in range(2, int(Js.js_round(n * 0.8))):
		var a: float = phi[j]
		var w: float = ws[j]
		hl.append(_claw_t([P[j][0] + V8.js_sin(a) * w * 0.6, P[j][1] - V8.js_cos(a) * w * 0.6], ox, oy, k, down))
	body.append(h("path", {
		"d": _poly(hl, false), "stroke": "#FFFFFF", "strokeOpacity": 0.7 if pale or forged != null else 0.4,
		"strokeWidth": 1.4 if forged != null else 1.1, "fill": "none", "strokeLinecap": "round" }))
	if fang:
		# canal del veneno y orificio de salida cerca de la punta
		var canal: Array = []
		for j in range(4, int(Js.js_round(n * 0.9))):
			var a: float = phi[j]
			var w: float = ws[j]
			canal.append(_claw_t([P[j][0] - V8.js_sin(a) * w * 0.35, P[j][1] + V8.js_cos(a) * w * 0.35], ox, oy, k, down))
		body.append(h("path", { "d": _poly(canal, false), "stroke": "#B8A58A", "strokeOpacity": 0.6, "strokeWidth": 0.6, "fill": "none" }))
		var oe: Array = canal[canal.size() - 1]
		body.append(h("ellipse", { "cx": oe[0], "cy": oe[1], "rx": 0.9, "ry": 0.5, "fill": "#8C7B63" }))
		if drop:
			var tx: float = tip[0]
			var ty: float = tip[1]
			body.append(h("path", {
				"d": "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % [
					_n(_r2(tx)), _n(_r2(ty + 0.5)), _n(_r2(tx + 2.4)), _n(_r2(ty + 4.0)), _n(_r2(tx)), _n(_r2(ty + 6.0)),
					_n(_r2(tx - 2.4)), _n(_r2(ty + 4.0)), _n(_r2(tx)), _n(_r2(ty + 0.5))],
				"fill": "#E3D466", "fillOpacity": 0.85 }))
	body.append_array(toe["front"])
	# Material reforjado: las gemas (no los metales) brillan con destellos a lo largo de la garra
	if forged != null and not (forged["id"] in Looks.METAL_INLAYS):
		for f: float in [0.35, 0.7]:
			var p := _claw_t(P[int(Js.js_round(n * f))], ox, oy, k, down)
			body.append(h("path", { "d": sparkle(p[0], p[1], 2.4 + 1.2 * f), "fill": "#FFFFFF", "fillOpacity": 0.85 }))
	# Punta: color de veredicto
	if Js.truthy(tip_color):
		body.append(h("circle", {
			"cx": tip[0], "cy": tip[1], "r": maxf(1.6, float(g["wTip"]) * k * 0.9), "fill": tip_color, "fillOpacity": 0.95 }))
	var a_t: float = phi[n]
	var tip_angle := V8.js_atan2(-V8.js_sin(a_t), -V8.js_cos(a_t)) if down else a_t
	return { "defs": defs, "body": body, "tip": { "x": tip[0], "y": tip[1] }, "tipAngle": tip_angle }


## Dedo, pata o encía de la que sale la garra/colmillo. bw = semiancho de la base de la garra (viewBox).
## Devuelve { back, front }: lo que va detrás de la garra y lo que la tapa por delante.
static func _toe_art(art: Dictionary, base: Array, orient: String, id: String, defs: Array, bw: float, tip: Variant) -> Dictionary:
	var bx: float = base[0]
	var by: float = base[1]
	var down := orient == "down"
	var dir := -1.0 if down else 1.0
	var back: Array = []
	var front: Array = []
	var R := Rng.new(Rng.seed_of(id))
	var kind: String = art["kind"]
	if kind == "fang":
		# Maxilar de víbora de perfil, boca abierta: el colmillo cuelga delante, bajo el hocico, y se curva hacia la
		# garganta. u: a lo largo de la cabeza (+ hacia el hocico) · t: alejándose del colmillo.
		var sx := -1.0 if tip != null and float(tip[0]) > bx else 1.0
		var X := func(u: float) -> float: return _r2(bx + sx * u)
		var Y := func(t: float) -> float: return _r2(by + dir * t)
		var jaw: String = art["jaw"]
		var toe_col: String = art["toe"]
		var head := "M%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % [
			_n(X.call(bw * 3.4)), _n(Y.call(-0.6)), _n(X.call(bw * 4.3)), _n(Y.call(9.0)), _n(X.call(bw * 2.2)), _n(Y.call(15.0)),
			_n(X.call(-18.0)), _n(Y.call(23.0)), _n(X.call(-100.0)), _n(Y.call(25.0)), _n(X.call(-100.0)), _n(Y.call(-1.5)),
			_n(X.call(-30.0)), _n(Y.call(-3.2)), _n(X.call(bw * 3.4)), _n(Y.call(-0.6))]
		defs.append(_lin("%s-jaw" % id, [[0.0, lighten(jaw, 0.22)], [1.0, darken(jaw, 0.3)]],
			{ "user": true, "x1": bx, "y1": Y.call(0.0), "x2": bx, "y2": Y.call(25.0) }))
		defs.append(_lin("%s-gum" % id, [[0.0, lighten(toe_col, 0.15)], [1.0, darken(toe_col, 0.2)]]))
		defs.append(h("clipPath", { "id": "%s-hc" % id }, h("path", { "d": head })))
		defs.append(_lin("%s-hf" % id, [[0.0, "#FFFFFF", 0.0], [1.0, "#FFFFFF", 1.0]],
			{ "user": true, "x1": X.call(-100.0), "y1": by, "x2": X.call(-48.0), "y2": by }))
		defs.append(h("mask", { "id": "%s-hm" % id, "maskUnits": "userSpaceOnUse", "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0 },
			h("rect", { "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0, "fill": "url(#%s-hf)" % id })))
		var scales: Array = []
		for r in 5:
			for cc in 14:
				var u := bw * 3.2 - cc * 8.5 - (r % 2) * 4.2
				var t := 3.5 + r * 5.2
				scales.append(h("path", {
					"d": "M%s %s Q%s %s %s %s" % [
						_n(X.call(u - 4.4)), _n(Y.call(t)), _n(X.call(u)), _n(Y.call(t + 5.2)), _n(X.call(u + 4.4)), _n(Y.call(t))],
					"stroke": darken(jaw, 0.4), "strokeOpacity": 0.5, "strokeWidth": 0.6, "fill": lighten(jaw, 0.04 + R.next() * 0.1) }))
		# labiales: fila de escamas claras a lo largo del borde de la boca
		for cc in 9:
			var u := bw * 2.6 - cc * 9.5
			scales.append(h("rect", {
				"x": minf(X.call(u), X.call(u - 8.0)), "y": minf(Y.call(-0.8), Y.call(3.4)), "width": 8.0, "height": 4.2, "rx": 1.6,
				"fill": lighten(jaw, 0.35), "fillOpacity": 0.55, "stroke": darken(jaw, 0.35), "strokeOpacity": 0.4, "strokeWidth": 0.5 }))
		var eu := -16.0
		var et := 15.0
		back.append(h("g", { "mask": "url(#%s-hm)" % id },
			h("path", { "d": head, "fill": "url(#%s-jaw)" % id }),
			h("g", { "clipPath": "url(#%s-hc)" % id }, scales),
			# ojo con pupila vertical y escama supraocular
			h("path", {
				"d": "M%s %s Q%s %s %s %s" % [
					_n(X.call(eu - 7.0)), _n(Y.call(et + 4.5)), _n(X.call(eu)), _n(Y.call(et + 8.5)), _n(X.call(eu + 7.0)), _n(Y.call(et + 4.5))],
				"stroke": darken(jaw, 0.5), "strokeWidth": 1.2, "fill": "none", "strokeLinecap": "round" }),
			h("circle", { "cx": X.call(eu), "cy": Y.call(et), "r": 4.4, "fill": "#C99A3B", "stroke": darken(jaw, 0.55), "strokeWidth": 0.8 }),
			h("ellipse", { "cx": X.call(eu), "cy": Y.call(et), "rx": 0.95, "ry": 3.6, "fill": "#15110C" }),
			h("circle", { "cx": X.call(eu + 1.6), "cy": Y.call(et + 1.6), "r": 0.9, "fill": "#FFFFFF", "fillOpacity": 0.85 }),
			h("path", { "d": head, "fill": "none", "stroke": darken(jaw, 0.45), "strokeOpacity": 0.55, "strokeWidth": 0.8 })))
		# vaina de encía de la que sale el colmillo
		back.append(h("ellipse", { "cx": bx, "cy": by + dir * 0.6, "rx": bw * 2.1, "ry": bw * 0.9 + 1.4, "fill": "url(#%s-gum)" % id }))
		front.append(h("path", {
			"d": "M%s %s Q%s %s %s %s" % [
				_n(_r2(bx - bw * 1.9)), _n(_r2(by + 0.8 * dir)), _n(bx), _n(_r2(by + (1.2 + bw * 0.8) * dir)), _n(_r2(bx + bw * 1.9)),
				_n(_r2(by + 0.8 * dir))],
			"stroke": darken(toe_col, 0.3), "strokeOpacity": 0.5, "strokeWidth": 0.8, "fill": "none" }))
		return { "back": back, "front": front }
	if kind == "mammal" or kind == "owl":
		# Dedo cubierto de pelo (o de plumas, en los búhos) del que asoma la garra. El pelo apunta hacia la garra, las
		# rayas del tigre cruzan el dedo y un mechón tapa la raíz. Se difumina hacia atrás.
		var owl := kind == "owl"
		var dw := bw * 1.95
		var span := 92.0
		var top := by - bw * 0.35 * dir
		var Y := func(t: float) -> float: return _r2(top + dir * t)
		var toe_col: String = art["toe"]
		var hair: Array = ["#FFFFFF", lighten(toe_col, 0.25), darken(toe_col, 0.2)] if owl else art["fur"]
		var digit := "M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % [
			_n(_r2(bx - dw)), _n(Y.call(span)), _n(_r2(bx - dw)), _n(Y.call(dw)), _n(_r2(bx - dw)), _n(Y.call(-dw * 0.35)),
			_n(_r2(bx)), _n(Y.call(-dw * 0.35)), _n(_r2(bx + dw)), _n(Y.call(-dw * 0.35)), _n(_r2(bx + dw)), _n(Y.call(dw)),
			_n(_r2(bx + dw)), _n(Y.call(span))]
		defs.append(_lin("%s-paw" % id, [
			[0.0, darken(toe_col, 0.3)], [0.38, lighten(toe_col, 0.12)], [0.7, toe_col], [1.0, darken(toe_col, 0.38)]],
			{ "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.0 }))
		defs.append(_lin("%s-pf" % id, [[0.0, "#FFFFFF", 1.0], [1.0, "#FFFFFF", 0.0]],
			{ "user": true, "x1": bx, "y1": Y.call(span * 0.4), "x2": bx, "y2": Y.call(span * 0.9) }))
		defs.append(h("mask", { "id": "%s-pm" % id, "maskUnits": "userSpaceOnUse", "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0 },
			h("rect", { "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0, "fill": "url(#%s-pf)" % id })))
		defs.append(h("clipPath", { "id": "%s-pc" % id }, h("path", { "d": digit })))
		var fur: Array = [h("path", { "d": digit, "fill": "url(#%s-paw)" % id })]
		var inside: Array = []
		# pelo del dorso: trazos cortos a lo largo del dedo, apuntando hacia la garra
		for i in 90:
			var t := R.next() * span * 0.85
			var x0 := bx + (R.next() * 2.0 - 1.0) * dw * 0.95
			var l := bw * (0.5 + R.next() * 0.6)
			var a := -dir * PI / 2.0 + (x0 - bx) / dw * 0.35 + (R.next() - 0.5) * 0.4
			var d := "M%s %s l%s %s" % [_n(_r2(x0)), _n(Y.call(t)), _n(_r2(V8.js_cos(a) * l)), _n(_r2(V8.js_sin(a) * l))]
			inside.append(h("path", {
				"d": d, "stroke": hair[int(floorf(R.next() * 3.0))], "strokeOpacity": 0.55, "strokeWidth": 1.1 if owl else 0.7,
				"strokeLinecap": "round" }))
		# rayas transversales del tigre, afiladas y alternando lado
		if Js.truthy(art.get("stripes")):
			for i in 4:
				var t := dw * (1.1 + i * 1.05)
				var side := 1.0 if i % 2 else -1.0
				var x0 := bx + side * dw * 1.05
				var x1 := bx - side * dw * (0.35 + 0.1 * i)
				inside.append(h("path", {
					"d": "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % [
						_n(_r2(x0)), _n(Y.call(t)), _n(_r2((x0 + x1) / 2.0)), _n(Y.call(t - bw * 0.3)), _n(_r2(x1)), _n(Y.call(t + bw * 0.12)),
						_n(_r2((x0 + x1) / 2.0)), _n(Y.call(t + bw * 0.3)), _n(_r2(x0)), _n(Y.call(t + bw * 0.55))],
					"fill": art["fur"][2], "fillOpacity": 0.75 }))
		fur.append(h("g", { "clipPath": "url(#%s-pc)" % id }, inside))
		# pelo del contorno: sobresale del perfil hacia fuera y hacia la garra
		for i in 70:
			var side := 1.0 if i % 2 else -1.0
			var t := dw * 0.4 + R.next() * span * 0.8
			var l := bw * (0.45 + R.next() * 0.7) * (1.3 if owl else 1.0)
			var a := V8.js_atan2(-dir * 0.75, side * 0.65) + (R.next() - 0.5) * 0.5
			var px := _r2(bx + side * dw * (0.86 + R.next() * 0.1))
			var qx := _r2(V8.js_cos(a) * l * 0.5 + (R.next() - 0.5))
			var d := "M%s %s q%s %s %s %s" % [_n(px), _n(Y.call(t)), _n(qx), _n(_r2(V8.js_sin(a) * l * 0.5)), _n(_r2(V8.js_cos(a) * l)), _n(_r2(V8.js_sin(a) * l))]
			fur.append(h("path", {
				"d": d, "stroke": hair[int(floorf(R.next() * 3.0))], "strokeWidth": 1.3 if owl else 0.9, "strokeLinecap": "round",
				"fill": "none", "strokeOpacity": 0.9 }))
		back.append(h("g", { "mask": "url(#%s-pm)" % id }, fur))
		# mechón delantero que cubre la raíz de la garra
		for i in 28:
			var x0 := bx + (R.next() - 0.5) * dw * 1.7
			var t := dw * (0.15 + R.next() * 0.45)
			var l := bw * (0.6 + R.next() * 0.6) * (1.25 if owl else 1.0)
			var a := -dir * PI / 2.0 + (x0 - bx) / dw * 0.6 + (R.next() - 0.5) * 0.5
			var qx := _r2(V8.js_cos(a) * l * 0.5 + (R.next() - 0.5) * 1.5)
			var d := "M%s %s q%s %s %s %s" % [
				_n(_r2(x0)), _n(Y.call(t)), _n(qx), _n(_r2(V8.js_sin(a) * l * 0.5)), _n(_r2(V8.js_cos(a) * l)), _n(_r2(V8.js_sin(a) * l))]
			front.append(h("path", {
				"d": d, "stroke": hair[int(floorf(R.next() * 3.0))], "strokeWidth": 1.3 if owl else 1.0, "strokeLinecap": "round", "fill": "none" }))
		return { "back": back, "front": front }
	# dedo escamoso (rapaces, ratites, gallo, loros, pájaros)
	# Dedo largo con escudetes transversales; se difumina hacia el extremo (máscara) para que no parezca un tornillo
	# cuando nada lo recorta (banco de ensayo).
	var toe_col: String = art["toe"]
	defs.append(_lin("%s-toe" % id, [[0.0, darken(toe_col, 0.25)], [0.35, lighten(toe_col, 0.18)], [1.0, darken(toe_col, 0.3)]],
		{ "x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.0 }))
	var tw := bw * 1.45
	var top := by - bw * 0.2 * dir
	var span := 96.0
	defs.append(_lin("%s-tf" % id, [[0.0, "#FFFFFF", 1.0], [1.0, "#FFFFFF", 0.0]],
		{ "user": true, "x1": bx, "y1": _r2(top + span * 0.42 * dir), "x2": bx, "y2": _r2(top + span * 0.92 * dir) }))
	defs.append(h("mask", { "id": "%s-tm" % id, "maskUnits": "userSpaceOnUse", "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0 },
		h("rect", { "x": -200.0, "y": -200.0, "width": 500.0, "height": 540.0, "fill": "url(#%s-tf)" % id })))
	var toe: Array = [h("rect", {
		"x": _r2(bx - tw), "y": _r2(top - span if down else top), "width": _r2(tw * 2.0), "height": span, "rx": _r2(tw * 0.9),
		"fill": "url(#%s-toe)" % id })]
	var r := 0
	while r * bw * 0.8 + bw * 0.55 < span - bw:
		var sy := top + (r * bw * 0.8 + bw * 0.55) * dir
		toe.append(h("path", {
			"d": "M%s %s Q%s %s %s %s" % [
				_n(_r2(bx - tw * 0.92)), _n(_r2(sy)), _n(_r2(bx)), _n(_r2(sy + bw * 0.55 * dir)), _n(_r2(bx + tw * 0.92)), _n(_r2(sy))],
			"stroke": darken(toe_col, 0.45), "strokeOpacity": 0.6, "strokeWidth": 0.8, "fill": "none" }))
		toe.append(h("path", {
			"d": "M%s %s Q%s %s %s %s" % [
				_n(_r2(bx - tw * 0.6)), _n(_r2(sy + bw * 0.12 * dir)), _n(_r2(bx)), _n(_r2(sy + bw * 0.45 * dir)), _n(_r2(bx + tw * 0.6)),
				_n(_r2(sy + bw * 0.12 * dir))],
			"stroke": "#FFFFFF", "strokeOpacity": 0.18, "strokeWidth": 0.6, "fill": "none" }))
		r += 1
	back.append(h("g", { "mask": "url(#%s-tm)" % id }, toe))
	front.append(h("path", {
		"d": "M%s %s Q%s %s %s %s" % [
			_n(_r2(bx - tw * 0.95)), _n(_r2(top + bw * 0.1 * dir)), _n(_r2(bx)), _n(_r2(top + bw * 0.9 * dir)), _n(_r2(bx + tw * 0.95)),
			_n(_r2(top + bw * 0.1 * dir))],
		"stroke": darken(toe_col, 0.5), "strokeOpacity": 0.7, "strokeWidth": 1.1, "fill": "none" }))
	return { "back": back, "front": front }
