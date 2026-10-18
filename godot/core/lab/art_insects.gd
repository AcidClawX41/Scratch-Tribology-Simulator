## Tribología biológica · dibujos de los insectos y de sus aguijones (modelo 2.0; no existen en art.js).
##
## Mismo grafo de escena que core/lab/art.gd ({ tag, attrs, children }, con sus ayudantes de color y de números como
## JavaScript), que svg.gd escribe y app/common/ rasteriza con ThorVG; art.gd no cambia (sigue dando los 372 SVG del
## oráculo). ThorVG no pinta <text>: los rótulos van como datos (labels) y la interfaz los escribe con Label.
## Proporciones de los datos de insects.gd (docs/fisica/aguijones.md §7.7): cuerpo (bodyMm), ala anterior
## (forewingMm), eje del aguijón (shaftMm), lo que entra (insertMm), diámetro (diameterUm) y, en la abeja, la posición y
## la altura de sus 10 púas por lanceta (Ramirez-Esquivel & Ravi 2023) y el bulbo de 786 × 320 µm. Donde no hay medida
## (las púas de las otras especies), el reparto es ilustrativo y se dice. Los colores de cada especie son los de
## stinger.colors; LOOK añade los rasgos de dibujo (patas, pelo, bandas, cintura), que no son datos.
## Funciones (todas puras; o = { k: unidades por mm, x, y: dónde va la base del aguijón, uid }):
##   - insect_body_art(claw, o): el cuerpo de perfil (mirando a la izquierda) en posición de picar, sin alas ni
##     aguijón; devuelve también sting (base del aguijón), stingAngle, wing (raíz de las alas) y box (su caja).
##   - insect_wings_art(claw, o): las alas, en el mismo sistema que el cuerpo (el banco las hace aletear girándolas).
##   - insect_icon_art(claw, o): el insecto entero con su aguijón para las fichas (lienzo 100 × 132, como las garras) y,
##     con o.lupa, una lupa con la punta del aguijón aumentada y sus púas.
##   - stinger_art(claw, o): el aguijón aumentado (bulbo, estilete, lancetas y púas) de la base a la punta.
##   - stinger_outline(claw, len, width, bend, from_tip): el contorno del aguijón para dibujarlo en cada fotograma.
##   - apparatus_art(claw, o) y venom_sac_art(claw, o): el aparato que se queda clavado tras la autotomía y el saco.
##   - sting_section_art(res, claw, o): el corte de la piel con el aguijón dentro hasta la capa que alcanza.
##   - surface_art(look_id, o) y look(id): Art.surface_art más la cutícula de insecto (el material de la 2.0).
## Uso: const ArtInsects = preload("res://core/lab/art_insects.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Art = preload("res://core/lab/art.gd")
const Looks = preload("res://core/lab/looks.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")
const Zones = preload("res://core/lab/zones.gd")
## 2.0: el corte de la piel por zonas (las capas de otra zona que el brazo, en el corte del aguijón).
const ArtZones = preload("res://core/lab/art_zones.gd")

## Rasgos de dibujo de cada especie (no son datos): familia, robustez (ancho del gáster frente al cuerpo), cintura,
## pelo, tamaño de la cabeza y de las patas, y los colores de cada parte (con los de stinger.colors de base).
const LOOK := {
	"abeja": {
		"family": "apid", "stout": 0.36, "hair": 1.0, "head": 1.0, "legs": 1.0,
		"headCol": "#3B2A1A", "thorax": "#8A5A2B", "hairCol": "#D9B26A", "gaster": "#C98A2B", "band": "#3B2A1A",
		"bands": [[0.40, 0.49], [0.58, 0.67], [0.75, 0.83], [0.9, 1.0]], "legCol": "#2A1E12",
	},
	"avispa": {
		"family": "vespid", "stout": 0.31, "hair": 0.12, "head": 1.0, "legs": 1.0,
		"headCol": "#F2C200", "thorax": "#1A1A1A", "hairCol": "#6B5A2A", "gaster": "#F2C200", "band": "#1A1A1A",
		"bands": [[0.0, 0.16], [0.30, 0.37], [0.49, 0.56], [0.67, 0.73], [0.83, 0.88]], "legCol": "#E0B000",
	},
	"papelera": {
		"family": "vespid", "stout": 0.25, "hair": 0.05, "head": 0.95, "legs": 1.45,
		"headCol": "#F0B400", "thorax": "#1E1A14", "hairCol": "#6B5A2A", "gaster": "#F0B400", "band": "#1E1A14",
		"bands": [[0.0, 0.12], [0.30, 0.35], [0.50, 0.55], [0.68, 0.72], [0.84, 0.87]], "legCol": "#F0B400",
	},
	"avispon": {
		"family": "vespid", "stout": 0.33, "hair": 0.35, "head": 1.05, "legs": 1.0,
		"headCol": "#E8A33A", "thorax": "#6B3A1E", "hairCol": "#B07A45", "gaster": "#E3B22C", "band": "#6B3A1E",
		"bands": [[0.0, 0.27], [0.50, 0.54], [0.66, 0.70], [0.80, 0.83]], "legCol": "#7A4424",
	},
	"velutina": {
		"family": "vespid", "stout": 0.31, "hair": 0.2, "head": 1.0, "legs": 1.0,
		"headCol": "#E09A2A", "thorax": "#2B211A", "hairCol": "#5A4A38", "gaster": "#2B211A", "band": "#E07B1A",
		"bands": [[0.24, 0.27], [0.66, 0.82]], "legCol": "#2B211A", "tarsus": "#E8C040",
	},
	"abejorro": {
		"family": "apid", "stout": 0.48, "hair": 1.8, "head": 0.95, "legs": 0.9,
		"headCol": "#161616", "thorax": "#161616", "hairCol": "#2E2E2E", "gaster": "#161616", "band": "#E6B422",
		"bands": [[0.08, 0.24]], "collar": "#E6B422", "tail": "#F2EEE6", "legCol": "#161616",
	},
	"hormigabala": {
		"family": "ant", "stout": 0.26, "hair": 0.3, "head": 1.35, "legs": 1.2,
		"headCol": "#3A1F14", "thorax": "#2A1A12", "hairCol": "#C9A24A", "gaster": "#1C1411", "band": "#5A2E1C",
		"bands": [[0.0, 0.05]], "legCol": "#3A1F14",
	},
	"pepsis": {
		"family": "pompilid", "stout": 0.22, "hair": 0.05, "head": 0.9, "legs": 1.6,
		"headCol": "#1B2440", "thorax": "#1B2440", "hairCol": "#3A4A7A", "gaster": "#1B2440", "band": "#2E3F72",
		"bands": [], "legCol": "#141B30", "sheen": "#6F8CD8",
	},
}
const DEFAULT_LOOK := {
	"family": "vespid", "stout": 0.3, "hair": 0.2, "head": 1.0, "legs": 1.0, "headCol": "#4A3A28", "thorax": "#4A3A28",
	"hairCol": "#8A7A60", "gaster": "#6B5A40", "band": "#2A2018", "bands": [], "legCol": "#2A2018",
}
## Cutícula de insecto (el material de la 2.0): ámbar oscuro, brillante, con la microescultura poligonal de un esclerito.
const CUTICLE_LOOK := { "kind": "cuticle", "base": "#9A6430", "lo": "#4E2A10", "ink": "#E8B872" }
## Veneno: amarillo pálido traslúcido (el de la 1.x en los cortes de la piel es #E3D466).
const VENOM := "#E6D56A"


# ── Números y trazos (como art.gd: números con Js.js_num_str, redondeados a centésimas) ──

static func _n(v: float) -> String:
	return Js.js_num_str(Js.js_round(v * 100.0) / 100.0)


static func _p(v: Vector2) -> String:
	return "%s %s" % [_n(v.x), _n(v.y)]


## Trayecto «M … L … Z» por los puntos.
static func _path(pts: Array, close := true) -> String:
	var out := PackedStringArray()
	for i in pts.size():
		out.append(("M" if i == 0 else "L") + _p(pts[i]))
	return " ".join(out) + (" Z" if close else "")


## Trayecto suave (Catmull-Rom a cúbicas) por los puntos, cerrado.
static func _smooth(pts: Array, close := true) -> String:
	var n := pts.size()
	if n < 3:
		return _path(pts, close)
	var out := PackedStringArray(["M" + _p(pts[0])])
	var last := n if close else n - 1
	for i in last:
		var p0: Vector2 = pts[(i - 1 + n) % n] if (close or i > 0) else pts[i]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var p3: Vector2 = pts[(i + 2) % n] if (close or i + 2 < n) else p2
		var c1 := p1 + (p2 - p0) / 6.0
		var c2 := p2 - (p3 - p1) / 6.0
		out.append("C%s %s %s" % [_p(c1), _p(c2), _p(p2)])
	return " ".join(out) + (" Z" if close else "")


static func _ellipse_pts(c: Vector2, rx: float, ry: float, rot: float, n := 20) -> Array:
	var out: Array = []
	var cr := V8.js_cos(rot)
	var sr := V8.js_sin(rot)
	for i in n:
		var a := TAU * i / n
		var x := rx * V8.js_cos(a)
		var y := ry * V8.js_sin(a)
		out.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	return out


## Color del aguijón: el de la especie (stinger.colors.sting) o, reforjado, el de su material.
static func sting_color(claw: Dictionary, inlay: Variant = null) -> String:
	return String(inlay.col) if Sting.is_reforged(inlay) else _col(claw, "sting", String(claw.col))


static func look_of(claw: Dictionary) -> Dictionary:
	return LOOK.get(claw.get("id"), DEFAULT_LOOK)


static func _col(claw: Dictionary, key: String, def: String) -> String:
	var c: Variant = claw.get("stinger", {}).get("colors", {}).get(key)
	return String(c) if c != null else def


# ════════ EL INSECTO ════════
# Coordenadas del cuerpo en unidades de su longitud (L = 1), de perfil y mirando a la izquierda, con el gáster curvado
# hacia abajo para picar: la cabeza en x ≈ 0,1 y la punta del gáster (la base del aguijón) abajo a la derecha. El dibujo
# se lleva al lienzo con _frame: la base del aguijón en (o.x, o.y) y S = bodyMm·k unidades por L.

## Esqueleto de la especie en unidades de L: { head, headR, thorax, thoraxR, p0, p1, p2 (curva del gáster), W (ancho
## máximo del gáster), wing (raíz de las alas), legs (raíces), node (nodo del peciolo de las hormigas o null) }.
static func _skeleton(claw: Dictionary) -> Dictionary:
	var lk := look_of(claw)
	var fam: String = lk.family
	var stout: float = lk.stout
	var hs: float = lk.head
	var sk := {
		"head": Vector2(0.105, 0.0), "headR": Vector2(0.085, 0.095) * hs, "thorax": Vector2(0.30, -0.01),
		"thoraxR": Vector2(0.13, 0.12 * stout / 0.34 if fam == "apid" else 0.105), "p0": Vector2(0.44, 0.03),
		"p1": Vector2(0.80, 0.0), "p2": Vector2(0.86, 0.34), "W": stout * 0.62, "wing": Vector2(0.29, -0.11),
		"legs": [Vector2(0.24, 0.07), Vector2(0.30, 0.09), Vector2(0.36, 0.08)], "node": null,
	}
	match fam:
		"vespid":
			sk.merge({ "thorax": Vector2(0.30, -0.005), "thoraxR": Vector2(0.135, 0.1), "p0": Vector2(0.465, 0.035),
				"p1": Vector2(0.82, 0.01), "p2": Vector2(0.88, 0.33) }, true)
		"ant":
			sk.merge({ "head": Vector2(0.11, 0.0), "thorax": Vector2(0.31, 0.005), "thoraxR": Vector2(0.15, 0.07),
				"p0": Vector2(0.53, 0.03), "p1": Vector2(0.82, -0.02), "p2": Vector2(0.87, 0.28), "node": Vector2(0.475, -0.005),
				"legs": [Vector2(0.25, 0.05), Vector2(0.32, 0.06), Vector2(0.39, 0.055)] }, true)
		"pompilid":
			sk.merge({ "thorax": Vector2(0.30, -0.005), "thoraxR": Vector2(0.14, 0.085), "p0": Vector2(0.46, 0.03),
				"p1": Vector2(0.85, 0.015), "p2": Vector2(0.90, 0.29) }, true)
	return sk


## Punto y tangente de la curva del gáster (Bézier cuadrática) en s ∈ [0, 1].
static func _gaster_at(sk: Dictionary, s: float) -> Array:
	var p0: Vector2 = sk.p0
	var p1: Vector2 = sk.p1
	var p2: Vector2 = sk.p2
	var u := 1.0 - s
	var p := p0 * (u * u) + p1 * (2.0 * u * s) + p2 * (s * s)
	var t := (p1 - p0) * (2.0 * u) + (p2 - p1) * (2.0 * s)
	return [p, t.normalized()]


## Semiancho del gáster en s: ancho en la unión (los ápidos, anchos; los demás, con cintura), máximo hacia el 40 % y
## romo en la punta, donde sale el aguijón.
static func _gaster_w(sk: Dictionary, lk: Dictionary, s: float) -> float:
	var shape := V8.js_pow(maxf(V8.js_sin(PI * V8.js_pow(clampf(s, 0.0, 1.0), 0.72)), 0.0), 0.85)
	var a0 := 0.42 if lk.family == "apid" else 0.12
	return 0.5 * float(sk.W) * (maxf(shape, a0 * (1.0 - s) * (1.0 - s)) * (1.0 - 0.22 * s) + 0.05)


## Bordes del gáster de s0 a s1 (n tramos): [lado dorsal, lado ventral].
static func _gaster_edges(sk: Dictionary, lk: Dictionary, s0: float, s1: float, n: int) -> Array:
	var up: Array = []
	var dn: Array = []
	for i in n + 1:
		var s := s0 + (s1 - s0) * i / n
		var pt: Array = _gaster_at(sk, s)
		var nrm := Vector2(-pt[1].y, pt[1].x)  # hacia el vientre (abajo-izquierda)
		var w := _gaster_w(sk, lk, s)
		up.append(pt[0] - nrm * w)
		dn.append(pt[0] + nrm * w)
	return [up, dn]


## Marco del dibujo: la base del aguijón (sk.p2) en (o.x, o.y) y S unidades por L. Devuelve un Callable u → lienzo.
static func _frame(claw: Dictionary, o: Dictionary) -> Dictionary:
	var sk := _skeleton(claw)
	var k: float = o.get("k", 1.0)
	var S: float = float(Sting.sval(claw.stinger, "bodyMm")) * k
	var origin := Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	var p2: Vector2 = sk.p2
	return { "sk": sk, "S": S, "at": func(u: Vector2) -> Vector2: return origin + (u - p2) * S }


## Cuerpo del insecto de perfil en posición de picar (sin alas ni aguijón). o = { k, x, y, uid }.
## Devuelve { defs, body, sting: {x, y}, stingAngle (rad, dirección del aguijón), wing: {x, y}, box: {x, y, w, h}, S }.
static func insect_body_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var fr := _frame(claw, o)
	var sk: Dictionary = fr.sk
	var S: float = fr.S
	var at: Callable = fr.at
	var lk := look_of(claw)
	var uid: String = "%s-%s" % [o.get("uid", "ins"), claw.id]
	var R := Rng.new(Rng.seed_of("insecto:" + String(claw.id)))
	var sw := S / 80.0  # grosor de trazo proporcional al tamaño del dibujo
	var defs: Array = []
	var back: Array = []
	var body: Array = []
	var front: Array = []
	# ── patas del lado de atrás (más oscuras), luego el cuerpo y las del lado de delante ──
	var legs := _legs(sk, lk, at, S, sw)
	back.append_array(legs.far)
	# ── gáster ──
	var ed := _gaster_edges(sk, lk, 0.0, 1.0, 28)
	var ring: Array = (ed[0] as Array).duplicate()
	var dn: Array = (ed[1] as Array).duplicate()
	dn.reverse()
	ring.append_array(dn)
	var ring_w: Array = ring.map(func(u: Vector2) -> Vector2: return at.call(u))
	var gaster_col: String = lk.gaster
	var gid := "%s-g" % uid
	var g_mid: Array = _gaster_at(sk, 0.45)
	var g_a: Vector2 = at.call(g_mid[0] + Vector2(-g_mid[1].y, g_mid[1].x) * -0.12)
	var g_b: Vector2 = at.call(g_mid[0] + Vector2(-g_mid[1].y, g_mid[1].x) * 0.12)
	defs.append(Art._lin(gid, [[0.0, Art.lighten(gaster_col, 0.35)], [0.45, gaster_col], [1.0, Art.darken(gaster_col, 0.45)]],
		{ "user": true, "x1": Art._r2(g_a.x), "y1": Art._r2(g_a.y), "x2": Art._r2(g_b.x), "y2": Art._r2(g_b.y) }))
	defs.append(Art.h("clipPath", { "id": "%s-gc" % uid }, Art.h("path", { "d": _path(ring_w) })))
	body.append(Art.h("path", { "d": _smooth(ring_w), "fill": "url(#%s)" % gid, "stroke": Art.darken(gaster_col, 0.6),
		"strokeOpacity": 0.55, "strokeWidth": Art._r2(0.8 * sw) }))
	# bandas (entre los bordes del gáster) y la cola del abejorro
	var bands: Array = []
	for b: Array in lk.bands:
		bands.append(_band(sk, lk, at, b[0], b[1], String(lk.band)))
	if lk.has("tail"):
		bands.append(_band(sk, lk, at, 0.8, 1.0, String(lk.tail)))
	# brillo del esclerito y pelo del borde dorsal
	var shine: Array = []
	var sh: Array = []
	for i in 13:
		var s := 0.1 + 0.62 * i / 12.0
		var pt: Array = _gaster_at(sk, s)
		sh.append(at.call(pt[0] - Vector2(-pt[1].y, pt[1].x) * _gaster_w(sk, lk, s) * 0.55))
	shine.append(Art.h("path", { "d": _path(sh, false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.35,
		"strokeWidth": Art._r2(1.6 * sw), "strokeLinecap": "round" }))
	if lk.has("sheen"):
		shine.append(Art.h("path", { "d": _path(sh, false), "fill": "none", "stroke": lk.sheen, "strokeOpacity": 0.5,
			"strokeWidth": Art._r2(3.0 * sw), "strokeLinecap": "round" }))
	body.append(Art.h("g", { "clipPath": "url(#%s-gc)" % uid }, bands, shine))
	# ── peciolo y nodo (hormigas) ──
	var j0: Vector2 = at.call(sk.thorax + Vector2(float(sk.thoraxR.x) * 0.85, 0.02))
	var j1: Vector2 = at.call(sk.p0)
	body.append(Art.h("path", { "d": "M%s L%s" % [_p(j0), _p(j1)], "stroke": Art.darken(String(lk.thorax), 0.2),
		"strokeWidth": Art._r2(S * (0.05 if lk.family == "apid" else 0.022)), "strokeLinecap": "round", "fill": "none" }))
	if sk.node != null:
		var nd: Vector2 = at.call(sk.node)
		body.append(Art.h("ellipse", { "cx": Art._r2(nd.x), "cy": Art._r2(nd.y), "rx": Art._r2(S * 0.035), "ry": Art._r2(S * 0.05),
			"fill": String(lk.thorax), "stroke": Art.darken(String(lk.thorax), 0.5), "strokeWidth": Art._r2(0.6 * sw) }))
	# ── tórax ──
	var th: Vector2 = at.call(sk.thorax)
	var tr: Vector2 = sk.thoraxR * S
	var tid := "%s-t" % uid
	defs.append(Art._rad(tid, [[0.0, Art.lighten(String(lk.thorax), 0.35)], [0.6, String(lk.thorax)], [1.0, Art.darken(String(lk.thorax), 0.5)]],
		{ "cx": 0.4, "cy": 0.3, "r": 0.75 }))
	var th_pts := _ellipse_pts(th, tr.x, tr.y, -0.12, 22)
	if lk.family == "ant":  # mesosoma con joroba: el lomo sube en la mitad delantera
		for i in th_pts.size():
			var p: Vector2 = th_pts[i]
			var f := (p.x - (th.x - tr.x)) / (1.2 * tr.x)
			if p.y < th.y and f > 0.0 and f < 1.0:
				th_pts[i] = p + Vector2(0.0, -0.45 * tr.y * V8.js_sin(PI * f))
	body.append(Art.h("path", { "d": _smooth(th_pts), "fill": "url(#%s)" % tid, "stroke": Art.darken(String(lk.thorax), 0.6),
		"strokeOpacity": 0.6, "strokeWidth": Art._r2(0.8 * sw) }))
	if lk.has("collar"):  # franja amarilla del abejorro delante del tórax
		var cpts := _ellipse_pts(th + Vector2(-0.55 * tr.x, -0.05 * tr.y), 0.32 * tr.x, 0.92 * tr.y, -0.12, 16)
		body.append(Art.h("path", { "d": _smooth(cpts), "fill": lk.collar, "fillOpacity": 0.95 }))
	if lk.family == "vespid" and String(lk.headCol) != String(lk.thorax):  # marcas amarillas del tórax de las avispas
		for m: Array in [[Vector2(-0.35, -0.55), 0.22, 0.1], [Vector2(0.45, -0.35), 0.16, 0.08], [Vector2(0.1, 0.5), 0.18, 0.07]]:
			var mc: Vector2 = th + Vector2(m[0].x * tr.x, m[0].y * tr.y)
			body.append(Art.h("ellipse", { "cx": Art._r2(mc.x), "cy": Art._r2(mc.y), "rx": Art._r2(float(m[1]) * tr.x),
				"ry": Art._r2(float(m[2]) * tr.x), "fill": String(lk.headCol), "fillOpacity": 0.85,
				"transform": "rotate(-12 %s %s)" % [_n(mc.x), _n(mc.y)] }))
	# ── cabeza ──
	var hd: Vector2 = at.call(sk.head)
	var hr: Vector2 = sk.headR * S
	var hid := "%s-h" % uid
	defs.append(Art._rad(hid, [[0.0, Art.lighten(String(lk.headCol), 0.3)], [0.65, String(lk.headCol)], [1.0, Art.darken(String(lk.headCol), 0.45)]],
		{ "cx": 0.35, "cy": 0.35, "r": 0.8 }))
	body.append(Art.h("ellipse", { "cx": Art._r2(hd.x), "cy": Art._r2(hd.y), "rx": Art._r2(hr.x), "ry": Art._r2(hr.y),
		"fill": "url(#%s)" % hid, "stroke": Art.darken(String(lk.headCol), 0.6), "strokeOpacity": 0.6, "strokeWidth": Art._r2(0.8 * sw) }))
	if lk.family == "vespid" or lk.family == "pompilid":  # frente oscura sobre la cara
		body.append(Art.h("path", { "d": "M%s Q%s %s" % [_p(hd + Vector2(-0.8 * hr.x, -0.45 * hr.y)), _p(hd + Vector2(0.0, -1.25 * hr.y)),
			_p(hd + Vector2(0.9 * hr.x, -0.35 * hr.y))], "fill": String(lk.thorax), "fillOpacity": 0.85 }))
	# ojo compuesto, mandíbula y antena
	var ec := hd + Vector2(0.12 * hr.x, -0.1 * hr.y)
	body.append(Art.h("ellipse", { "cx": Art._r2(ec.x), "cy": Art._r2(ec.y), "rx": Art._r2(0.38 * hr.x), "ry": Art._r2(0.62 * hr.y),
		"fill": "#15110C", "fillOpacity": 0.92 if lk.family != "ant" else 0.55 }))
	body.append(Art.h("ellipse", { "cx": Art._r2(ec.x - 0.1 * hr.x), "cy": Art._r2(ec.y - 0.25 * hr.y), "rx": Art._r2(0.12 * hr.x),
		"ry": Art._r2(0.16 * hr.y), "fill": "#FFFFFF", "fillOpacity": 0.55 }))
	var mb := hd + Vector2(-0.75 * hr.x, 0.55 * hr.y)
	var mandible_len := (1.2 if lk.family == "ant" else 0.6) * hr.x
	front.append(Art.h("path", { "d": "M%s Q%s %s" % [_p(mb), _p(mb + Vector2(-0.6 * mandible_len, 0.3 * mandible_len)),
		_p(mb + Vector2(-0.9 * mandible_len, -0.25 * mandible_len))], "fill": "none", "stroke": "#1A120C",
		"strokeWidth": Art._r2(1.8 * sw * (1.6 if lk.family == "ant" else 1.0)), "strokeLinecap": "round" }))
	var ab := hd + Vector2(-0.35 * hr.x, -0.75 * hr.y)
	var scape := (1.4 if lk.family == "ant" else 0.9) * hr.y
	var elbow := ab + Vector2(-0.35 * scape, -scape)
	var antenna := "M%s Q%s %s Q%s %s" % [_p(ab), _p(ab + Vector2(-0.05 * scape, -0.7 * scape)), _p(elbow),
		_p(elbow + Vector2(-1.1 * scape, -0.1 * scape)), _p(elbow + Vector2(-1.5 * scape, 0.75 * scape))]
	front.append(Art.h("path", { "d": antenna, "fill": "none", "stroke": Art.darken(String(lk.headCol), 0.55),
		"strokeWidth": Art._r2(1.3 * sw), "strokeLinecap": "round" }))
	# ── pelo (ápidos) ──
	var hair: float = lk.hair
	if hair > 0.0:
		var hc: String = lk.hairCol
		for i in int(Js.js_round(46.0 * hair)):
			var a := R.next() * TAU
			var base := th + Vector2(V8.js_cos(a) * tr.x, V8.js_sin(a) * tr.y)
			var l := S * (0.018 + R.next() * 0.02) * clampf(hair, 0.5, 1.6)
			var tip := base + Vector2(V8.js_cos(a), V8.js_sin(a)) * l
			front.append(Art.h("path", { "d": "M%s L%s" % [_p(base), _p(tip)], "stroke": hc, "strokeOpacity": 0.7,
				"strokeWidth": Art._r2(0.7 * sw), "strokeLinecap": "round" }))
		for i in int(Js.js_round(30.0 * hair)):
			var s := R.next() * 0.8
			var pt: Array = _gaster_at(sk, s)
			var nrm := Vector2(-pt[1].y, pt[1].x)
			var side := -1.0 if R.next() < 0.6 else 1.0
			var base: Vector2 = at.call(pt[0] + nrm * side * _gaster_w(sk, lk, s))
			var l := S * (0.012 + R.next() * 0.015) * clampf(hair, 0.5, 1.6)
			front.append(Art.h("path", { "d": "M%s L%s" % [_p(base), _p(base + nrm * side * l)], "stroke": hc,
				"strokeOpacity": 0.55, "strokeWidth": Art._r2(0.6 * sw), "strokeLinecap": "round" }))
	front.append_array(legs.near)
	var all: Array = []
	all.append_array(back)
	all.append_array(body)
	all.append_array(front)
	var tip_dir: Vector2 = (_gaster_at(sk, 1.0) as Array)[1]
	var sting_w: Vector2 = at.call(sk.p2)
	var wing_w: Vector2 = at.call(sk.wing)
	return {
		"defs": defs, "body": all, "sting": { "x": sting_w.x, "y": sting_w.y }, "stingAngle": V8.js_atan2(tip_dir.y, tip_dir.x),
		"wing": { "x": wing_w.x, "y": wing_w.y }, "box": _box(claw, o), "S": S,
	}


## Banda del gáster entre s0 y s1 (sigue sus bordes, así nunca se sale).
static func _band(sk: Dictionary, lk: Dictionary, at: Callable, s0: float, s1: float, col: String) -> Dictionary:
	var ed := _gaster_edges(sk, lk, s0, s1, 6)
	var pts: Array = (ed[0] as Array).duplicate()
	var dn: Array = (ed[1] as Array).duplicate()
	dn.reverse()
	pts.append_array(dn)
	return Art.h("path", { "d": _path(pts.map(func(u: Vector2) -> Vector2: return at.call(u))), "fill": col, "fillOpacity": 0.95 })


## Patas: seis, colgando (de perfil se ven tres de cada lado). { far: [...], near: [...] }.
static func _legs(sk: Dictionary, lk: Dictionary, at: Callable, _S: float, sw: float) -> Dictionary:
	var ls: float = lk.legs
	var col: String = lk.legCol
	var tars: String = lk.get("tarsus", col)
	var far: Array = []
	var near: Array = []
	# ángulos (grados, desde +x y hacia abajo; el insecto mira a la izquierda) de fémur, tibia y tarso de las patas
	# anterior (hacia delante), media (abajo) y posterior (hacia atrás), con la rodilla doblada
	var poses := [[148.0, 102.0, 132.0], [108.0, 78.0, 104.0], [48.0, 98.0, 62.0]]
	var seg := [0.11 * ls, 0.13 * ls, 0.1 * ls]
	for side in 2:
		for i in 3:
			var root: Vector2 = sk.legs[i] + Vector2(0.01 * (side * 2 - 1), 0.0)
			var pts: Array = [root]
			var p := root
			for j in 3:
				var a: float = (float(poses[i][j]) + (9.0 if side == 0 else 0.0)) * PI / 180.0
				p = p + Vector2(V8.js_cos(a), V8.js_sin(a)) * float(seg[j]) * (0.9 if side == 0 else 1.0)
				pts.append(p)
			var w: Array = pts.map(func(u: Vector2) -> Vector2: return at.call(u))
			var width := 1.5 * sw * clampf(ls, 0.8, 1.2)
			var node := Art.h("g", {},
				Art.h("path", { "d": _path(w.slice(0, 3), false), "fill": "none", "stroke": Art.darken(col, 0.35 if side == 0 else 0.0),
					"strokeWidth": Art._r2(width), "strokeLinecap": "round", "strokeLinejoin": "round" }),
				Art.h("path", { "d": _path(w.slice(2, 4), false), "fill": "none", "stroke": Art.darken(tars, 0.35 if side == 0 else 0.0),
					"strokeWidth": Art._r2(width * 0.75), "strokeLinecap": "round" }))
			(far if side == 0 else near).append(node)
	return { "far": far, "near": near }


## Caja del dibujo del insecto con las alas (también levantadas al aletear) y las patas: { x, y, w, h } en unidades
## del lienzo, con la base del aguijón en (o.x, o.y).
static func insect_box(claw: Dictionary, o: Dictionary) -> Dictionary:
	return _box(claw, o)


static func _box(claw: Dictionary, o: Dictionary) -> Dictionary:
	var fr := _frame(claw, o)
	var sk: Dictionary = fr.sk
	var at: Callable = fr.at
	var lk := look_of(claw)
	var pts: Array = []
	pts.append(at.call(Vector2(sk.head.x - float(sk.headR.x) * 2.4, -0.36)))  # antena y cabeza
	pts.append(at.call(Vector2(sk.p2.x + 0.07, sk.p2.y + 0.05)))
	var fw := _wing_len(claw)
	pts.append(at.call(sk.wing + Vector2(V8.js_cos(-0.62), V8.js_sin(-0.62)) * (fw * 1.08)))  # ala levantada (aleteo)
	pts.append(at.call(sk.wing + Vector2(1.0, 0.0) * (fw * 1.08)))
	pts.append(at.call(Vector2(0.18, 0.1 + 0.42 * float(lk.legs))))  # patas
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return { "x": floorf(lo.x), "y": floorf(lo.y), "w": ceilf(hi.x - lo.x) + 1.0, "h": ceilf(hi.y - lo.y) + 1.0 }


## Longitud del ala anterior en unidades de L (0 sin alas o sin medida).
static func _wing_len(claw: Dictionary) -> float:
	var fw: Variant = Sting.sval(claw.stinger, "forewingMm")
	var body := float(Sting.sval(claw.stinger, "bodyMm"))
	if fw == null:
		# sin medida del ala: Pepsis tiene alas (naranjas) aunque no haya dato; se dibujan a la proporción de los véspidos
		return 0.0 if String(claw.stinger.wingbeat.get("note", "")).contains("no tienen alas") else 0.72
	return float(fw) / body


## Alas (anterior y posterior) en el mismo marco que el cuerpo, extendidas hacia atrás. o = { k, x, y, uid, angle }:
## angle (rad) las levanta (el banco las hace aletear dibujándolas giradas alrededor de `wing`). Sin alas: vacío.
static func insect_wings_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var fr := _frame(claw, o)
	var sk: Dictionary = fr.sk
	var S: float = fr.S
	var at: Callable = fr.at
	var fw := _wing_len(claw)
	var uid: String = "%s-%s" % [o.get("uid", "wg"), claw.id]
	if fw <= 0.0:
		return { "defs": [], "body": [], "wing": { "x": 0.0, "y": 0.0 } }
	var col := _col(claw, "wings", "#DDE6EE")
	var opaque: bool = claw.id == "pepsis"
	var lift: float = o.get("angle", 0.0)
	var defs: Array = []
	var body: Array = []
	var root: Vector2 = sk.wing
	for wi in 2:
		var len := fw * (1.0 if wi == 0 else 0.62)
		var width := len * (0.3 if wi == 0 else 0.28)
		var a := -0.22 + lift + (0.0 if wi == 0 else 0.12)
		var ax := Vector2(V8.js_cos(a), V8.js_sin(a))
		var nx := Vector2(-ax.y, ax.x)
		var pts: Array = []
		for i in 13:  # borde anterior (arriba) y posterior, con la punta redondeada
			var s := i / 12.0
			pts.append(root + ax * (len * s) - nx * (width * 0.42 * V8.js_sin(PI * V8.js_pow(s, 0.8))))
		for i in range(12, -1, -1):
			var s := i / 12.0
			pts.append(root + ax * (len * s) + nx * (width * 0.58 * V8.js_sin(PI * V8.js_pow(s, 0.65))))
		var w: Array = pts.map(func(u: Vector2) -> Vector2: return at.call(u))
		var gid := "%s-%d" % [uid, wi]
		var r0: Vector2 = at.call(root)
		var r1: Vector2 = at.call(root + ax * len)
		defs.append(Art._lin(gid, [[0.0, col, 0.85 if opaque else 0.55], [1.0, Art.lighten(col, 0.2), 0.7 if opaque else 0.22]],
			{ "user": true, "x1": Art._r2(r0.x), "y1": Art._r2(r0.y), "x2": Art._r2(r1.x), "y2": Art._r2(r1.y) }))
		body.append(Art.h("path", { "d": _smooth(w), "fill": "url(#%s)" % gid, "stroke": Art.darken(col, 0.45),
			"strokeOpacity": 0.55 if opaque else 0.4, "strokeWidth": Art._r2(S / 110.0) }))
		for v in 3:  # venas
			var t0 := 0.08
			var t1 := 0.55 + 0.15 * v
			var off := (v - 1) * 0.16 * width
			var q0: Vector2 = at.call(root + ax * (len * t0) + nx * off * 0.3)
			var q1: Vector2 = at.call(root + ax * (len * t1) + nx * off)
			body.append(Art.h("path", { "d": "M%s L%s" % [_p(q0), _p(q1)], "stroke": Art.darken(col, 0.55),
				"strokeOpacity": 0.45 if opaque else 0.3, "strokeWidth": Art._r2(S / 160.0) }))
	var ww: Vector2 = at.call(root)
	return { "defs": defs, "body": body, "wing": { "x": ww.x, "y": ww.y } }


# ════════ EL AGUIJÓN ════════

## Púas de una lanceta, desde la punta: [[distancia a la punta (µm), altura (µm)], …]. La abeja, con las medidas de
## Ramirez-Esquivel & Ravi (2023); las demás, perLancet púas de la profundidad media repartidas en el 36 % distal del eje
## con separaciones crecientes, como en la abeja (reparto ilustrativo: no hay medidas).
static func barbs(claw: Dictionary) -> Array:
	var b: Dictionary = claw.stinger.barbs
	var out: Array = []
	var first: Variant = b.get("firstUm")
	var pitch: Variant = b.get("pitchUm")
	var lens: Variant = b.get("lengthUm")
	if first != null and pitch is Array and lens is Array:
		var d := float(first)
		for i in (lens as Array).size():
			out.append([d, float(lens[i])])
			if i < (pitch as Array).size():
				d += float(pitch[i])
		return out
	var n: Variant = b.get("perLancet")
	var depth: Variant = b.get("depthUm")
	if n == null or int(n) <= 0 or depth == null:
		return out
	var shaft_um := float(Sting.sval(claw.stinger, "shaftMm")) * 1000.0
	var span := 0.36 * shaft_um
	var cnt := int(n)
	for i in cnt:
		var f := (float(i) + 0.4) / cnt
		out.append([span * f * f * 0.85 + span * 0.08, float(depth) * (0.7 + 0.6 * V8.js_sin(PI * f))])
	return out


## Semiancho del aguijón (µm) a d µm de la punta: esfera de la punta, cono del ápice (tipAngleDeg) hasta el diámetro
## del estilete y, cerca de la base, el ensanche hacia el bulbo.
static func half_width_um(claw: Dictionary, d_um: float) -> float:
	var st: Dictionary = claw.stinger
	var R: float = float(Sting.sval(st, "tipRadiusUm"))
	var D: float = float(Sting.sval(st, "diameterUm"))
	var shaft := float(Sting.sval(st, "shaftMm")) * 1000.0
	var tan_a := V8.js_tan(float(Sting.sval(st, "tipAngleDeg")) * 0.5 * PI / 180.0)
	var w := minf(D * 0.5, R + maxf(d_um, 0.0) * tan_a)
	var widen := clampf((d_um - 0.82 * shaft) / (0.18 * shaft), 0.0, 1.0)
	return w * (1.0 + 0.9 * widen * widen)


## Contorno del aguijón para dibujarlo en cada fotograma (el banco): de la base (0, 0) hacia +y, `len` unidades de
## largo y `width` de ancho, doblado `bend` (flecha de la punta en unidades, con la forma del primer modo de un
## voladizo, y = f·(1 − cos(πx/2L))) y, con keep ≥ 0, solo sus primeras `keep` unidades desde la base (lo que asoma de
## la piel: el resto está dentro). Devuelve PackedVector2Array (contorno cerrado).
static func stinger_outline(claw: Dictionary, len: float, width: float, bend: float, keep := -1.0) -> PackedVector2Array:
	var n := 18
	var shaft_um := float(Sting.sval(claw.stinger, "shaftMm")) * 1000.0
	var d_max := float(Sting.sval(claw.stinger, "diameterUm"))
	var shown := len if keep < 0.0 else clampf(keep, 0.0, len)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var x := shown * i / n  # desde la base hasta donde se ve
		var y_bend := bend * (1.0 - V8.js_cos(PI * x / (2.0 * len)))
		var slope := bend * PI / (2.0 * len) * V8.js_sin(PI * x / (2.0 * len))
		var nx := Vector2(1.0, -slope).normalized()
		var d_um := (len - x) / len * shaft_um
		var hw := width * 0.5 * half_width_um(claw, d_um) / (0.5 * d_max)
		var c := Vector2(y_bend, x)
		left.append(c - nx * hw)
		right.append(c + nx * hw)
	var out := PackedVector2Array(left)
	right.reverse()
	out.append_array(right)
	return out


## El aguijón aumentado, vertical, de la base (arriba) a la punta (abajo): bulbo (la abeja: 786 × 320 µm), estilete con
## el canal del veneno, las dos lancetas con sus púas y el reflejo. o = { x, y (la punta), scale (unidades por µm),
## uid, inlay (reforjado: su color), from_um (dibujar solo desde la punta hasta esa distancia) }.
static func stinger_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var st: Dictionary = claw.stinger
	var inlay: Variant = o.get("inlay")
	var forged: bool = Sting.is_reforged(inlay)
	var col: String = String(inlay.col) if forged else _col(claw, "sting", String(claw.col))
	var k: float = o.get("scale", 0.05)
	var tip := Vector2(float(o.get("x", 50.0)), float(o.get("y", 120.0)))
	var shaft_um := float(Sting.sval(st, "shaftMm")) * 1000.0
	var upto: float = minf(float(o.get("from_um", shaft_um)), shaft_um)
	var uid: String = "%s-%s%s" % [o.get("uid", "stg"), claw.id, ("-" + String(inlay.id)) if forged else ""]
	var defs: Array = []
	var body: Array = []
	var pts_l: Array = []
	var pts_r: Array = []
	var n := 40
	for i in n + 1:
		var d := upto * i / n
		var hw := half_width_um(claw, d) * k
		pts_l.append(tip + Vector2(-hw, -d * k))
		pts_r.append(tip + Vector2(hw, -d * k))
	var outline: Array = pts_l.duplicate()
	var rr := pts_r.duplicate()
	rr.reverse()
	outline.append_array(rr)
	var gid := "%s-k" % uid
	var top_y := tip.y - upto * k
	defs.append(Art._lin(gid, [[0.0, Art.darken(col, 0.4)], [0.35, Art.lighten(col, 0.45 if forged else 0.3)], [0.7, col], [1.0, Art.darken(col, 0.55)]],
		{ "user": true, "x1": Art._r2(tip.x - half_width_um(claw, upto) * k), "y1": Art._r2(tip.y), "x2": Art._r2(tip.x + half_width_um(claw, upto) * k), "y2": Art._r2(tip.y) }))
	# bulbo (solo si se dibuja entero)
	if upto >= shaft_um - 1e-6:
		var bw := (320.0 if claw.id == "abeja" else float(Sting.sval(st, "diameterUm")) * 3.7) * k
		var bh := (786.0 if claw.id == "abeja" else shaft_um * 0.43) * k
		var bc := Vector2(tip.x, top_y - bh * 0.35)
		body.append(Art.h("ellipse", { "cx": Art._r2(bc.x), "cy": Art._r2(bc.y), "rx": Art._r2(bw * 0.5), "ry": Art._r2(bh * 0.5),
			"fill": Art.darken(col, 0.15), "stroke": Art.darken(col, 0.6), "strokeWidth": 0.6 }))
		body.append(Art.h("ellipse", { "cx": Art._r2(bc.x - bw * 0.15), "cy": Art._r2(bc.y - bh * 0.18), "rx": Art._r2(bw * 0.12),
			"ry": Art._r2(bh * 0.25), "fill": "#FFFFFF", "fillOpacity": 0.3 }))
	body.append(Art.h("path", { "d": _path(outline), "fill": "url(#%s)" % gid, "stroke": Art.darken(col, 0.6), "strokeWidth": 0.5 }))
	# canal del veneno y juntas entre el estilete y las lancetas
	var canal := float(Sting.sval(st, "canalUm")) * k
	if canal > 0.4:
		body.append(Art.h("path", { "d": "M%s L%s" % [_p(tip + Vector2(0.0, -minf(upto, 160.0) * k)), _p(Vector2(tip.x, top_y))],
			"stroke": "#000000", "strokeOpacity": 0.28, "strokeWidth": Art._r2(canal * 0.6) }))
	for side: float in [-1.0, 1.0]:
		var seam: Array = []
		for i in range(2, n + 1):
			var d := upto * i / n
			seam.append(tip + Vector2(side * half_width_um(claw, d) * k * 0.45, -d * k))
		body.append(Art.h("path", { "d": _path(seam, false), "fill": "none", "stroke": "#000000", "strokeOpacity": 0.25, "strokeWidth": 0.4 }))
	# púas: dientes de sierra hacia la base, alternando las dos lancetas
	var bl := barbs(claw)
	for i in bl.size():
		var d: float = bl[i][0]
		var hgt: float = bl[i][1]
		if d > upto:
			break
		for side: float in [-1.0, 1.0]:
			var dd := d + (0.0 if side < 0.0 else 9.0)  # las dos lancetas no coinciden
			var hw := half_width_um(claw, dd) * k
			var base_a := tip + Vector2(side * hw, -dd * k)
			var base_b := tip + Vector2(side * hw, -(dd + hgt * 1.7) * k)
			var barb_tip := tip + Vector2(side * (hw + hgt * k), -(dd + hgt * 1.5) * k)
			body.append(Art.h("path", { "d": "M%s L%s L%s Z" % [_p(base_a), _p(barb_tip), _p(base_b)], "fill": Art.darken(col, 0.1),
				"stroke": Art.darken(col, 0.6), "strokeWidth": 0.35 }))
	# reflejo a lo largo del eje
	var hl: Array = []
	for i in range(3, n):
		var d := upto * i / n
		hl.append(tip + Vector2(-half_width_um(claw, d) * k * 0.55, -d * k))
	body.append(Art.h("path", { "d": _path(hl, false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.55 if forged else 0.35,
		"strokeWidth": 0.6, "strokeLinecap": "round" }))
	if forged and not (String(inlay.id) in Looks.METAL_INLAYS):
		body.append(Art.h("path", { "d": Art.sparkle(tip.x, tip.y - upto * k * 0.45, 2.2), "fill": "#FFFFFF", "fillOpacity": 0.85 }))
	return { "defs": defs, "body": body, "tip": { "x": tip.x, "y": tip.y }, "top": top_y }


## El insecto entero con su aguijón, para las fichas y la comparativa (lienzo 100 × 132, como las garras): el cuerpo, las
## alas y el aguijón a escala (el eje de la abeja mide ~1/6 de su cuerpo). o = { uid, inlay, lupa (una lupa con la punta
## aumentada y sus púas), tipColor (color de veredicto en la punta, como en las garras) }.
static func insect_icon_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var uid: String = o.get("uid", "ic")
	var inlay: Variant = o.get("inlay")
	var lupa: bool = Js.truthy(o.get("lupa"))
	# escala: que el insecto (con alas y patas) quepa en 92 × 84 (o 92 × 70 con lupa) con el aguijón apuntando abajo
	var probe := _box(claw, { "k": 1.0, "x": 0.0, "y": 0.0 })
	var k := minf(92.0 / float(probe.w), (70.0 if lupa else 88.0) / float(probe.h))
	var box := _box(claw, { "k": k, "x": 0.0, "y": 0.0 })
	var ox := 50.0 - (float(box.x) + float(box.w) / 2.0)
	var oy := (8.0 if lupa else 12.0) - float(box.y)
	var o2 := { "k": k, "x": ox, "y": oy, "uid": uid }
	var wings := insect_wings_art(claw, o2)
	var ins := insect_body_art(claw, o2)
	var defs: Array = []
	defs.append_array(wings.defs)
	defs.append_array(ins.defs)
	var body: Array = []
	body.append_array(wings.body)
	body.append_array(ins.body)
	# aguijón a escala desde la base del gáster, en la dirección del gáster
	var st: Dictionary = claw.stinger
	var ang: float = ins.stingAngle
	var dir := Vector2(V8.js_cos(ang), V8.js_sin(ang))
	var s0 := Vector2(float(ins.sting.x), float(ins.sting.y))
	var slen := float(Sting.sval(st, "shaftMm")) * k
	var forged: bool = Sting.is_reforged(inlay)
	var scol: String = String(inlay.col) if forged else _col(claw, "sting", String(claw.col))
	var tip := s0 + dir * slen
	var nx := Vector2(-dir.y, dir.x)
	var w0 := maxf(float(Sting.sval(st, "diameterUm")) / 1000.0 * k, 0.9)
	body.append(Art.h("path", { "d": "M%s L%s L%s Z" % [_p(s0 + nx * w0), _p(tip), _p(s0 - nx * w0)], "fill": scol,
		"stroke": Art.darken(scol, 0.5), "strokeWidth": 0.35 }))
	if o.get("tipColor") != null:
		body.append(Art.h("circle", { "cx": Art._r2(tip.x), "cy": Art._r2(tip.y), "r": 1.8, "fill": o.tipColor, "fillOpacity": 0.95 }))
	var labels: Array = []
	if lupa:
		# lupa: los 700 µm de la punta con sus púas, dentro de un círculo, unida a la punta por una línea
		var lc := Vector2(70.0, 103.0)
		var lr := 24.0
		var cid := "%s-lupa" % uid
		defs.append(Art.h("clipPath", { "id": cid }, Art.h("circle", { "cx": lc.x, "cy": lc.y, "r": lr })))
		body.append(Art.h("path", { "d": "M%s L%s" % [_p(tip), _p(lc + (tip - lc).normalized() * lr)], "stroke": Looks.C["dim"],
			"strokeWidth": 0.6, "strokeDasharray": "2 1.5" }))
		body.append(Art.h("circle", { "cx": lc.x, "cy": lc.y, "r": lr, "fill": Looks.C["bg"], "fillOpacity": 0.92 }))
		var span_um := 700.0
		var scale := (2.0 * lr * 0.92) / span_um
		var zoom := stinger_art(claw, { "x": lc.x, "y": lc.y + lr * 0.92, "scale": scale, "uid": uid + "z", "inlay": inlay, "from_um": span_um })
		defs.append_array(zoom.defs)
		body.append(Art.h("g", { "clipPath": "url(#%s)" % cid }, zoom.body))
		body.append(Art.h("circle", { "cx": lc.x, "cy": lc.y, "r": lr, "fill": "none", "stroke": Looks.C["line2"], "strokeWidth": 1.2 }))
		labels.append({ "x": lc.x - lr - 3.0, "y": lc.y + lr - 2.0, "text": "700 µm", "size": 6.5, "color": Looks.C["dim"], "anchor": "end" })
	return { "defs": defs, "body": body, "labels": labels, "tip": { "x": tip.x, "y": tip.y }, "tipAngle": ang }


# ════════ CLAVADO: EL APARATO Y EL SACO DEL VENENO ════════

## El aparato que se queda clavado tras la autotomía (Hermann 1971; Ramirez-Esquivel & Ravi 2023): lo que asoma del
## aguijón, el bulbo y los jirones del abdomen (músculos, ganglio). La entrada en la piel está en (o.x, o.y); asoma hacia
## arriba. o = { k: unidades por mm, x, y, uid, inlay }. Devuelve también sac: { x, y, r } (dónde va el saco).
static func apparatus_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var st: Dictionary = claw.stinger
	var k: float = o.get("k", 1.0)
	var entry := Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	var inlay: Variant = o.get("inlay")
	var forged: bool = Sting.is_reforged(inlay)
	var col: String = String(inlay.col) if forged else _col(claw, "sting", String(claw.col))
	var out_mm := float(Sting.sval(st, "shaftMm")) - float(claw.reach)
	var stub := maxf(out_mm * k, 1.5)
	var w := maxf(float(Sting.sval(st, "diameterUm")) / 1000.0 * k, 0.8)
	var bulb := Vector2(entry.x, entry.y - stub - 0.23 * k)
	var body: Array = []
	# jirones de tejido detrás del bulbo
	var R := Rng.new(Rng.seed_of("aparato:" + String(claw.id)))
	for i in 5:
		var a := -PI * 0.5 + (R.next() - 0.5) * 1.8
		var l := k * (0.35 + R.next() * 0.45)
		var p1 := bulb + Vector2(V8.js_cos(a), V8.js_sin(a)) * l
		var ctrl := bulb + Vector2(V8.js_cos(a + 0.5), V8.js_sin(a + 0.5)) * l * 0.6
		body.append(Art.h("path", { "d": "M%s Q%s %s" % [_p(bulb), _p(ctrl), _p(p1)], "fill": "none", "stroke": "#B85A58" if i % 2 else "#E8C9A8",
			"strokeOpacity": 0.85, "strokeWidth": Art._r2(maxf(0.6, 0.06 * k)), "strokeLinecap": "round" }))
	body.append(Art.h("path", { "d": "M%s L%s L%s Z" % [_p(entry + Vector2(-w, 0.0)), _p(bulb), _p(entry + Vector2(w, 0.0))], "fill": col,
		"stroke": Art.darken(col, 0.55), "strokeWidth": 0.35 }))
	body.append(Art.h("ellipse", { "cx": Art._r2(bulb.x), "cy": Art._r2(bulb.y), "rx": Art._r2(maxf(0.16 * k, 1.2)),
		"ry": Art._r2(maxf(0.39 * k, 2.4)), "fill": Art.darken(col, 0.1), "stroke": Art.darken(col, 0.6), "strokeWidth": 0.4 }))
	body.append(Art.h("circle", { "cx": Art._r2(bulb.x + 0.08 * k), "cy": Art._r2(bulb.y - 0.5 * k), "r": Art._r2(maxf(0.09 * k, 0.8)),
		"fill": "#F1E7C4", "stroke": "#8A7A50", "strokeWidth": 0.3 }))  # ganglio terminal
	var sac := bulb + Vector2(-0.12 * k, -0.55 * k)
	var r := maxf(0.3 * k, 2.2)
	var top := minf(bulb.y - 0.85 * k, sac.y - r) - 1.0
	var half := maxf(0.9 * k, r + 2.0)
	return {
		"defs": [], "body": body, "sac": { "x": sac.x, "y": sac.y, "r": r },
		"box": { "x": floorf(entry.x - half), "y": floorf(top), "w": ceilf(2.0 * half) + 1.0, "h": ceilf(entry.y + 1.0 - top) + 1.0 },
	}


## El saco del veneno (reservorio), centrado en (o.x, o.y) con radio o.r; `fill` (0-1) lo que le queda. El banco lo
## dibuja latiendo con la bomba de válvulas.
static func venom_sac_art(o: Dictionary = {}) -> Dictionary:
	var c := Vector2(float(o.get("x", 10.0)), float(o.get("y", 10.0)))
	var r: float = o.get("r", 8.0)
	var fill: float = clampf(float(o.get("fill", 1.0)), 0.0, 1.0)
	var uid: String = o.get("uid", "sac")
	var defs: Array = [Art._rad(uid, [[0.0, "#FFF8D0", 0.95], [0.55, VENOM, 0.9], [1.0, Art.darken(VENOM, 0.3), 0.85]],
		{ "cx": 0.38, "cy": 0.35, "r": 0.7 })]
	var rr := r * (0.55 + 0.45 * fill)
	var body: Array = [
		Art.h("ellipse", { "cx": Art._r2(c.x), "cy": Art._r2(c.y), "rx": Art._r2(rr * 0.8), "ry": Art._r2(rr), "fill": "url(#%s)" % uid,
			"stroke": "#8A7A30", "strokeOpacity": 0.7, "strokeWidth": Art._r2(maxf(0.3, r * 0.06)) }),
		Art.h("ellipse", { "cx": Art._r2(c.x - rr * 0.25), "cy": Art._r2(c.y - rr * 0.35), "rx": Art._r2(rr * 0.18), "ry": Art._r2(rr * 0.26),
			"fill": "#FFFFFF", "fillOpacity": 0.6 }),
	]
	return { "defs": defs, "body": body }


# ════════ CORTE DE LA PIEL CON EL AGUIJÓN ════════
# Lienzo 300 × 184: 28 unidades de aire (lo que asoma del aguijón y, si se ha quedado, el aparato con el saco) y el
# bloque de tejido con una banda por capa (las alturas fijas de Looks.SKIN_BAND, como el corte de la piel de art.gd:
# dentro de cada banda la escala es lineal; en otra zona que el brazo, las capas de la zona con su hueso, como el corte
# de art_zones.gd). El aguijón baja hasta la profundidad del resultado con su anchura exagerada ×4 para que se vea, sus
# púas y una nube de veneno donde acaba.
const SECTION := { "w": 300.0, "h": 184.0, "air": 26.0, "x": 8.0, "bw": 150.0 }


## Las bandas del corte en otra zona que el brazo (2.0: sting_lab.gd pica con las capas de la zona): las de art_zones.gd,
## en el bloque de este corte; [] en el brazo, que se dibuja como siempre.
static func zone_bands(res: Dictionary, top: float) -> Array:
	if String(Zones.resolve(res.get("zone")).id) == Zones.DEFAULT_ID:
		return []
	return ArtZones.bands(res, top, top + (ArtZones.BOTTOM - ArtZones.TOP))


## Altura en el corte: la de section_y o, en otra zona, la de sus bandas (zone_bands).
static func _sy(um: float, top: float, zb: Array) -> float:
	return section_y(um, top) if zb.is_empty() else ArtZones.y_at(zb, um)


## Altura del corte (unidades) a um µm de profundidad (la escala por bandas del corte de la piel de art.gd).
static func section_y(um: float, top: float) -> float:
	var y := top
	for l: Dictionary in Looks.SKIN_LAYERS:
		var hh: float = Looks.SKIN_BAND.get(l.id, 20.0)
		if um <= float(l.to) or l.id == Looks.SKIN_LAYERS[-1].id:
			return y + clampf((um - float(l.from)) / (float(l.to) - float(l.from)), 0.0, 1.0) * hh
		y += hh
	return y


static func sting_section_art(res: Dictionary, claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var uid: String = o.get("uid", "ss")
	var inlay: Variant = o.get("inlay")
	var s: Dictionary = res.get("sting", {})
	var x: float = SECTION.x
	var w: float = SECTION.bw
	var top: float = SECTION.air
	var cx := x + w * 0.42
	var defs: Array = []
	var body: Array = []
	var labels: Array = []
	var y := top
	var zb := zone_bands(res, top)
	if zb.is_empty():
		for l: Dictionary in Looks.SKIN_LAYERS:
			var hh: float = Looks.SKIN_BAND.get(l.id, 20.0)
			var a := Art.surface_art(Looks.SKIN_LAYER_LOOK[l.id], { "x": x, "y": y, "w": w, "h": hh, "uid": "%s-%s" % [uid, l.id], "detail": 0.8 })
			defs.append_array(a.defs)
			body.append_array(a.body)
			if y > top:
				body.append(Art.h("line", { "x1": x, "y1": Art._r2(y), "x2": x + w, "y2": Art._r2(y), "stroke": "#000000", "strokeOpacity": 0.2, "strokeWidth": 0.5 }))
			var t: float = float(l.to) - float(l.from)
			var thick := "" if l.id == "musculo" else " · %s" % _thick(t)
			labels.append({ "x": 166.0, "y": y + hh / 2.0 + 3.0, "text": String(l.short) + thick, "size": 8.0, "color": Looks.C["dim"] })
			y += hh
	else:
		# 2.0: en otra zona, sus capas y su hueso (o la cavidad), como el corte de la piel de art_zones.gd
		for b: Dictionary in zb:
			var y0: float = b.y0
			var y1: float = b.y1
			var a := ArtZones.tissue_surface(String(b.look), { "x": x, "y": y0, "w": w, "h": y1 - y0, "uid": "%s-%s" % [uid, b.id], "detail": 0.8 })
			defs.append_array(a.defs)
			body.append_array(a.body)
			if y0 > top:
				body.append(Art.h("line", { "x1": x, "y1": Art._r2(y0), "x2": x + w, "y2": Art._r2(y0), "stroke": "#000000", "strokeOpacity": 0.2, "strokeWidth": 0.5 }))
			labels.append({ "x": 166.0, "y": Art._r2((y0 + y1) / 2.0 + 3.0), "text": ArtZones.band_label(b), "size": 8.0, "color": Looks.C["dim"] })
		y = float(zb[-1].y1)
	var bottom := y
	body.append(Art.h("rect", { "x": x, "y": top, "width": w, "height": bottom - top, "fill": "none", "stroke": Looks.C["line2"], "strokeWidth": 1.0 }))
	var pierces: bool = s.get("pierces") == true
	var depth: float = float(res.get("depthUm", 0.0))
	var forged: bool = Sting.is_reforged(inlay)
	var col: String = String(inlay.col) if forged else _col(claw, "sting", String(claw.col))
	var vcol: String = String(res.get("vcol", Looks.C["dim"]))
	var hw := 1.8  # semiancho dibujado del estilete (exagerado)
	if pierces:
		var dy := _sy(depth, top, zb)
		# veneno: nube donde acaba el aguijón (en la capa que alcanza)
		var vid := "%s-v" % uid
		defs.append(Art._rad(vid, [[0.0, VENOM, 0.8], [1.0, VENOM, 0.0]]))
		body.append(Art.h("ellipse", { "cx": Art._r2(cx), "cy": Art._r2(dy - 2.0), "rx": 12.0, "ry": 8.0, "fill": "url(#%s)" % vid }))
		# el aguijón dentro: del aire a la profundidad, con púas en su parte distal
		var above := 8.0
		var pts: Array = [Vector2(cx - hw, top - above), Vector2(cx + hw, top - above), Vector2(cx + hw, dy - 6.0), Vector2(cx, dy),
			Vector2(cx - hw, dy - 6.0)]
		body.append(Art.h("path", { "d": _path(pts), "fill": col, "stroke": Art.darken(col, 0.6), "strokeWidth": 0.5 }))
		var bl := barbs(claw)
		var reach_um := float(claw.reach) * 1000.0
		for b: Array in bl:
			var d: float = b[0]
			if d > reach_um:
				continue
			var by := _sy(depth - d, top, zb)
			if by >= dy - 5.0:
				by = dy - 5.0 - 0.6 * bl.find(b)
			for side: float in [-1.0, 1.0]:
				body.append(Art.h("path", { "d": "M%s L%s L%s" % [_p(Vector2(cx + side * hw, by)), _p(Vector2(cx + side * (hw + 1.6), by - 2.2)),
					_p(Vector2(cx + side * hw, by - 2.6))], "fill": Art.darken(col, 0.15), "stroke": "none" }))
		body.append(Art.h("line", { "x1": x, "y1": Art._r2(dy), "x2": x + w, "y2": Art._r2(dy), "stroke": vcol, "strokeWidth": 1.0, "strokeDasharray": "3 2" }))
		var txt := "≈ %s" % _fmt_depth(depth)
		var tx := cx + 10.0
		var ty := clampf(dy + 3.0, top + 8.0, bottom - 2.0)
		body.append(Art.h("rect", { "x": Art._r2(tx - 3.0), "y": Art._r2(ty - 8.0), "width": Art._r2(txt.length() * 5.2 + 6.0), "height": 11.0, "rx": 3.0,
			"fill": Looks.C["bg"], "fillOpacity": 0.78 }))
		labels.append({ "x": tx, "y": ty, "text": txt, "size": 8.5, "color": vcol, "bold": true })
		if s.get("stuck") == true:
			# se ha quedado: el aparato con el saco del veneno asoma sobre la piel
			var ap := apparatus_art(claw, { "k": 10.0, "x": cx, "y": top, "inlay": inlay })
			body.append_array(ap.body)
			var sac := venom_sac_art({ "x": ap.sac.x, "y": ap.sac.y, "r": 5.5, "fill": 0.7, "uid": uid + "-sac" })
			defs.append_array(sac.defs)
			body.append_array(sac.body)
			labels.append({ "x": cx + 14.0, "y": 12.0, "text": "se queda clavado", "size": 8.0, "color": vcol, "bold": true })
		else:
			labels.append({ "x": cx + 8.0, "y": 12.0, "text": "lo saca", "size": 8.0, "color": Looks.C["dim"] })
	else:
		# sin perforar: la piel se hunde bajo la punta (o el aguijón se dobla encima)
		var buckled: bool = s.get("buckled") == true
		var dimple := 3.0
		body.append(Art.h("path", { "d": "M%s Q%s %s" % [_p(Vector2(cx - 14.0, top)), _p(Vector2(cx, top + dimple * 2.0)), _p(Vector2(cx + 14.0, top))],
			"fill": "none", "stroke": "#7A4A3A", "strokeOpacity": 0.6, "strokeWidth": 0.8 }))
		var shaft: Array = []
		for i in 9:
			var f := i / 8.0
			var yy := top + dimple - (1.0 - f) * 22.0
			var xx := cx + (6.0 * V8.js_sin(PI * f) if buckled else 0.0)
			shaft.append(Vector2(xx, yy))
		body.append(Art.h("path", { "d": _path(shaft, false), "fill": "none", "stroke": col, "strokeWidth": 2.6, "strokeLinecap": "round" }))
		labels.append({ "x": cx + 12.0, "y": 12.0, "text": "se dobla" if buckled else "no perfora", "size": 8.0, "color": vcol, "bold": true })
	var aria := ("Corte de la piel: el aguijón llega a %s, %s" % [_fmt_depth(depth), String(res.get("layer", ""))]) if pierces else "Corte de la piel: el aguijón no la perfora"
	return { "defs": defs, "body": body, "labels": labels, "aria": aria }


static func _thick(t_um: float) -> String:
	return ("%s mm" % Js.to_fixed(t_um / 1000.0, 1).replace(".", ",")) if t_um >= 1000.0 else "%s µm" % Js.js_num_str(t_um)


static func _fmt_depth(um: float) -> String:
	if um >= 1000.0:
		return Js.to_fixed(um / 1000.0, 1) + " mm"
	return (Js.to_fixed(um, 1) if um < 10.0 else Js.to_fixed(um, 0)) + " µm"


# ════════ LA CUTÍCULA COMO MATERIAL ════════

## Aspecto de un material: el de Looks.MATERIAL_LOOK o el de la cutícula (añadido de la 2.0).
static func look(id: String) -> Dictionary:
	if id == "cuticula":
		return CUTICLE_LOOK
	return Looks.MATERIAL_LOOK.get(id, Looks.MATERIAL_LOOK["plastico"])


## La superficie de un material (Art.surface_art) o, si es la cutícula, esclerito ámbar con su microescultura poligonal,
## unas sedas y el brillo de la cera. o = { x, y, w, h, uid, detail, rx }. Devuelve { defs, body }.
static func surface_art(look_id: String, o: Dictionary) -> Dictionary:
	if look_id != "cuticula":
		return Art.surface_art(look_id, o)
	var x: float = o.get("x", 0.0)
	var y: float = o.get("y", 0.0)
	var w: float = o.w
	var H: float = o.h
	var uid: String = o.get("uid", "s")
	var detail: float = o.get("detail", 1.0)
	var rx: float = o.get("rx", 0.0)
	var L := CUTICLE_LOOK
	var R := Rng.new(Rng.seed_of("cuticula:%sx%s" % [Js.js_num_str(Js.js_round(w)), Js.js_num_str(Js.js_round(H))]))
	var id := "%s-cuticula" % uid
	var defs: Array = [
		Art._lin("%s-g" % id, [[0.0, Art.lighten(L.base, 0.18)], [0.55, L.base], [1.0, L.lo]]),
		Art.h("clipPath", { "id": "%s-c" % id }, Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx })),
		Art._lin("%s-sh" % id, [[0.0, "#FFFFFF", 0.45], [1.0, "#FFFFFF", 0.0]]),
	]
	var body: Array = [Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-g)" % id })]
	# microescultura: celdas hexagonales (la huella de las células de la epidermis que la segregan)
	var cell := maxf(3.2, H / 7.0)
	var rows := int(ceilf(H / (cell * 0.87))) + 1
	var cols := int(ceilf(w / (cell * 1.5))) + 2
	var hex := PackedStringArray()
	for r in rows:
		for c in cols:
			if detail < 1.0 and R.next() > detail:
				continue
			var cx := x + c * cell * 1.5 + (r % 2) * cell * 0.75
			var cy := y + r * cell * 0.87
			var pts: Array = []
			for k in 6:
				var a := PI / 3.0 * k
				pts.append(Vector2(cx + cell * 0.48 * V8.js_cos(a), cy + cell * 0.48 * V8.js_sin(a) * 0.9))
			hex.append(_path(pts))
	body.append(Art.h("path", { "d": " ".join(hex), "fill": "none", "stroke": L.ink, "strokeOpacity": 0.16, "strokeWidth": 0.35 }))
	# sedas (pelos sensoriales) y hoyuelos de sus bases
	for i in int(maxf(1.0, Js.js_round((w * H) / 260.0 * detail))):
		var sx := x + R.next() * w
		var sy := y + R.next() * H
		var l := 2.0 + R.next() * 3.0
		body.append(Art.h("circle", { "cx": Art._r2(sx), "cy": Art._r2(sy), "r": 0.45, "fill": L.lo, "fillOpacity": 0.6 }))
		body.append(Art.h("path", { "d": "M%s %s q%s %s %s %s" % [_n(sx), _n(sy), _n(l * 0.4), _n(-l * 0.3), _n(l), _n(-l * 0.2)],
			"stroke": L.ink, "strokeOpacity": 0.45, "strokeWidth": 0.3, "fill": "none" }))
	# brillo de la capa de cera
	body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": H * 0.4, "fill": "url(#%s-sh)" % id }))
	body.append(Art.h("path", { "d": "M%s %s Q%s %s %s %s" % [_n(x + w * 0.05), _n(y + H * 0.2), _n(x + w * 0.5), _n(y + H * 0.05), _n(x + w * 0.95), _n(y + H * 0.24)],
		"stroke": "#FFFFFF", "strokeOpacity": 0.4, "strokeWidth": 0.7, "fill": "none" }))
	return { "defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s-c)" % id }, body)] }
