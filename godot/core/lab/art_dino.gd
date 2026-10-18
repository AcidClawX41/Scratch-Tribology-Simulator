## Tribología biológica · dibujos de los dinosaurios reconstruidos (modelo 2.0; no existen en art.js). Hoy, la garra
## falciforme del dedo II del velocirraptor (docs/fisica/velociraptor.md §10.4, «Garra»).
##
## Mismo grafo de escena que core/lab/art.gd ({ tag, attrs, children }, con sus ayudantes de color y de números como
## JavaScript), como core/lab/art_insects.gd (unidad 2a); art.gd no cambia (sigue dando los 372 SVG del oráculo). ThorVG no
## pinta <text>: los rótulos van como datos (labels) y la interfaz los escribe con Label.
## Proporciones, las de los datos de velociraptor.gd (bloque dino.sickle), a escala entre sí:
##   - el hueso fósil (la falange ungueal II-3): 64,8 mm por la curva exterior, con 18,7 mm de alto en la base;
##   - el estuche de queratina que lo alarga hasta 92,7 mm por la curva exterior, y su banda (de 76,2 a 95,7 mm) como una
##     sombra que asoma de la punta y una raya discontinua donde acabaría la más corta;
##   - la curvatura: el arco de 160° (el de Deinonychus, el caso medido más parecido; es del dibujo);
##   - la sección de la base, una elipse de 18,7 × 7,1 mm: una hoja estrecha, 2,6 veces más alta que ancha.
## Lo que no está medido es solo dibujo y se dice: el grueso del estuche en la base (0,8 mm), cómo se estrecha la garra hacia
## la punta (la potencia de los perfiles), el dedo del que sale y los colores (dino.colors, «dibujo»). La punta no se mide
## (pregunta abierta, dino.sickle.tipRadiusUm.open): la ficha la marca con un «?».
## Funciones (todas puras):
##   - sickle_geometry(claw, bone): la garra en mm, con la base en (0, 0): { outline (estuche), shadow (la banda alta),
##     low (dónde acabaría la banda baja), bone (el hueso), tip, tipAngle, box }.
##   - claw_icon_art(claw, o): la garra para las fichas, la comparativa y el banco (lienzo 100 × 132, como las garras de
##     art.gd). o = { uid, inlay (reforjada: pintada en su material, sin hueso), tipColor (color de veredicto en la punta),
##     orient ("up" en las fichas; "down", colgando, en el banco), labels (los rótulos de la ficha: el «?» de la punta, las
##     longitudes y la sección de la base), bone (el hueso dentro, si la garra es de queratina) }. Devuelve { defs, body,
##     labels, tip: { x, y }, tipAngle, base: { x, y } }.
## Uso: const ArtDino = preload("res://core/lab/art_dino.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Art = preload("res://core/lab/art.gd")
const Looks = preload("res://core/lab/looks.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")

## Rasgos del dibujo que no son datos: grueso del estuche en la base (mm), radio que se deja en la punta (mm, para que se
## vea), potencias con que se estrechan el estuche y el hueso hacia la punta, tramos de cada borde y del perfil con que se
## miden los lomos.
const LOOK := {
	"sheathBaseMm": 0.8, "tipMm": 0.25, "boneTipMm": 0.9, "sheathPow": 0.85, "bonePow": 0.9, "steps": 36, "profileSteps": 96,
	"bone": "#D9CBB0", "boneLine": "#9C8A6A", "toe": "#8A6F4E", "scale": "#5B4A3A",
}
## Colores de reserva si la ficha no trae dino.colors (solo dibujo).
const DEFAULT_COLORS := { "body": "#8A6F4E", "feathers": "#5B4A3A", "claw": "#4A3F35" }
## Dirección de la línea media en la base (en pantalla, con y hacia abajo): arriba y algo a la izquierda (−125°), para que
## la garra, que se curva 160° a la derecha, se levante del dedo en diagonal y acabe con la punta hacia abajo (solo dibujo).
const PHI0 := -PI * 125.0 / 180.0


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


## Un dato de dino.sickle (su value).
static func _sk(claw: Dictionary, key: String, which := "value") -> float:
	var d: Variant = claw.get("dino")
	var sickle: Dictionary = d.sickle if d is Dictionary else Velociraptor.SICKLE
	var e: Dictionary = sickle[key]
	return float(e.get(which, e.value))


static func _colors(claw: Dictionary) -> Dictionary:
	var d: Variant = claw.get("dino")
	return d.colors if d is Dictionary and d.has("colors") else DEFAULT_COLORS


# ════════ Geometría (mm) ════════
# La garra es una hoja que se estrecha a lo largo de una línea media en arco de circunferencia: sale de la base (0, 0)
# con la dirección PHI0 (arriba y algo a la izquierda, en pantalla, con y hacia abajo) y se curva a la derecha, hasta
# acabar con la punta hacia abajo y a la derecha. El semialto en la fracción u de la línea media es
# w(u) = (w0 − w1)·(1 − u)^pw + w1. El lomo (el borde convexo) mide ∫ √((1 + w/R)²·L² + w'²) du, con L = R·arco: sin
# trigonometría, así que los ajustes (el radio de la garra, el arco de la banda y el del hueso) son baratos; los senos y
# cosenos de V8 solo se calculan para los puntos del contorno.

## Perfil del semialto en N tramos (puntos medios): { w: [w(u)], dw: [w'(u)] } (mm y mm por unidad de u).
static func _profile(w0: float, w1: float, pw: float, n: int) -> Dictionary:
	var w := PackedFloat64Array()
	var dw := PackedFloat64Array()
	for i in n:
		var u := (float(i) + 0.5) / float(n)
		var a := maxf(1.0 - u, 0.0)
		w.append((w0 - w1) * V8.js_pow(a, pw) + w1)
		dw.append(-(w0 - w1) * pw * V8.js_pow(a, pw - 1.0) if a > 0.0 else 0.0)
	return { "w": w, "dw": dw }


## Longitud del lomo (mm) de una garra con el perfil prof, línea media de radio rc y arco span (rad); hasta la fracción
## u_end de la línea media (1: entera).
static func _back_length(prof: Dictionary, rc: float, span: float, u_end := 1.0) -> float:
	var w: PackedFloat64Array = prof.w
	var dw: PackedFloat64Array = prof.dw
	var n := w.size()
	var lc := rc * span
	var s := 0.0
	for i in n:
		var u := (float(i) + 0.5) / float(n)
		if u > u_end:
			break
		var a := lc * (1.0 + w[i] / rc)
		s += sqrt(a * a + dw[i] * dw[i]) / float(n)
	return s


## Radio de la línea media con el que el lomo de una garra de arco span mide length (se ajusta iterando: el grueso no
## crece con el radio).
static func _fit_radius(length: float, span: float, prof: Dictionary) -> float:
	var rc := length / span
	for _i in 40:
		rc *= length / _back_length(prof, rc, span)
	return rc


## Arco (rad) con el que el lomo de una garra de línea media de radio rc mide length (bisección; crece con el arco).
static func _fit_span(length: float, rc: float, prof: Dictionary) -> float:
	var lo := 0.01
	var hi := 2.0 * PI
	for _i in 48:
		var mid := (lo + hi) / 2.0
		if _back_length(prof, rc, mid) < length:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


## Punto de la línea media con dirección phi (arco de radio rc que sale de la base (0, 0) con dirección PHI0).
static func _center(rc: float, phi: float) -> Vector2:
	return Vector2(rc * (V8.js_sin(phi) - V8.js_sin(PHI0)), -rc * (V8.js_cos(phi) - V8.js_cos(PHI0)))


## Normal hacia el lomo (el lado convexo) con dirección phi.
static func _normal(phi: float) -> Vector2:
	return Vector2(V8.js_sin(phi), -V8.js_cos(phi))


## Semialto a la fracción u de la línea media (0 en la base, 1 en la punta).
static func _half(w0: float, w1: float, pw: float, u: float) -> float:
	return (w0 - w1) * V8.js_pow(maxf(1.0 - u, 0.0), pw) + w1


## Contorno cerrado de la garra (steps tramos por lado): el lomo de la base a la punta y el vientre de vuelta.
static func _outline(rc: float, span: float, w0: float, w1: float, pw: float, steps: int) -> Array:
	var back: Array = []
	var belly: Array = []
	for i in steps + 1:
		var u := float(i) / float(steps)
		var phi := PHI0 + span * u
		var c := _center(rc, phi)
		var off := _normal(phi) * _half(w0, w1, pw, u)
		back.append(c + off)
		belly.append(c - off)
	belly.reverse()
	return back + belly


## La garra falciforme en mm, con la base (el centro de la articulación) en (0, 0): el estuche de keratinMm por el lomo con
## el arco de arcDeg; la sombra de la banda alta (keratinMm.max) en la misma curva, más larga; dónde acabaría la baja
## (keratinMm.min: la raya de lado a lado donde el lomo de la garra de siempre mide eso); y el hueso (coreMm por su lomo,
## coreHeightMm de alto en la base) dentro, si bone. { outline, shadow, low: [lomo, vientre], bone, tip, tipAngle (rad, la
## dirección de la punta), box: Rect2, rc, span, w0 }.
static func sickle_geometry(claw: Dictionary, bone := true) -> Dictionary:
	var steps: int = LOOK.steps
	var n: int = LOOK.profileSteps
	var span := _sk(claw, "arcDeg") * PI / 180.0
	var h_bone := _sk(claw, "coreHeightMm")
	var w0: float = h_bone / 2.0 + float(LOOK.sheathBaseMm)
	var w1: float = LOOK.tipMm
	var pw: float = LOOK.sheathPow
	var prof := _profile(w0, w1, pw, n)
	var rc := _fit_radius(_sk(claw, "keratinMm"), span, prof)
	var outline := _outline(rc, span, w0, w1, pw, steps)
	# la banda alta: la misma curva, más larga
	var shadow := _outline(rc, _fit_span(_sk(claw, "keratinMm", "max"), rc, prof), w0, w1, pw, steps)
	# la banda baja: la fracción de la línea media en que el lomo de la garra de siempre mide keratinMm.min (bisección)
	var want := _sk(claw, "keratinMm", "min")
	var lo := 0.0
	var hi := 1.0
	for _i in 40:
		var mid := (lo + hi) / 2.0
		if _back_length(prof, rc, span, mid) < want:
			lo = mid
		else:
			hi = mid
	var u_lo := (lo + hi) / 2.0
	var phi_lo := PHI0 + span * u_lo
	var c_lo := _center(rc, phi_lo)
	var off_lo := _normal(phi_lo) * _half(w0, w1, pw, u_lo)
	var bone_pts: Array = []
	if bone:
		# el hueso: la misma línea media, más corto y con la punta roma
		var wb0 := h_bone / 2.0
		var wb1: float = LOOK.boneTipMm
		var pwb: float = LOOK.bonePow
		var span_b := _fit_span(_sk(claw, "coreMm"), rc, _profile(wb0, wb1, pwb, n))
		bone_pts = _outline(rc, span_b, wb0, wb1, pwb, steps)
	var phi_t := PHI0 + span
	var tip := _center(rc, phi_t)
	var box := Rect2(tip, Vector2.ZERO)
	for p: Vector2 in outline + shadow:
		box = box.expand(p)
	return {
		"outline": outline, "shadow": shadow, "low": [c_lo + off_lo, c_lo - off_lo], "bone": bone_pts, "tip": tip,
		"tipAngle": phi_t, "box": box, "rc": rc, "span": span, "w0": w0,
	}


# ════════ Dibujo ════════

## La garra para las fichas y el banco (lienzo 100 × 132): o = { uid, inlay, tipColor, orient ("up" | "down"), labels,
## bone }. La garra ocupa hasta 80 × 96 unidades; la base queda abajo (o arriba, colgando, con orient "down").
static func claw_icon_art(claw: Dictionary, o: Dictionary = {}) -> Dictionary:
	var uid: String = o.get("uid", "dino")
	var inlay: Variant = o.get("inlay")
	var forged: bool = inlay is Dictionary and String(inlay.get("id", "none")) != "none"
	var down: bool = String(o.get("orient", "up")) == "down"
	var with_labels: bool = Js.truthy(o.get("labels"))
	var show_bone: bool = not forged and o.get("bone", true) != false
	var g := sickle_geometry(claw, show_bone)
	var cols := _colors(claw)
	# colgando (el banco), girada para que la punta apunte hacia abajo, al material; en la ficha, como sale del dedo
	var rot := PI / 2.0 - float(g.tipAngle) if down else 0.0
	var cr := V8.js_cos(rot)
	var sr := V8.js_sin(rot)
	var turn := func(p: Vector2) -> Vector2: return Vector2(p.x * cr - p.y * sr, p.x * sr + p.y * cr)
	# escala y colocación: la garra (con la sombra y el dedo) en 80 × 96, con la base a 20 unidades del borde. El dedo va
	# detrás de la base, en contra de la dirección con que sale la garra (dibujo)
	var toe_r: float = float(g.w0) * 1.25
	var toe_mm := -Vector2(V8.js_cos(PHI0), V8.js_sin(PHI0)) * (toe_r * 0.45)
	var toe_pts := _ellipse(toe_mm, toe_r * 1.05, toe_r * 0.62)
	var box := Rect2(turn.call(g.tip), Vector2.ZERO)
	for p: Vector2 in (g.outline as Array) + (g.shadow as Array) + toe_pts:
		box = box.expand(turn.call(p))
	var k := minf(80.0 / box.size.x, 96.0 / box.size.y)
	var ox := 50.0 - (box.position.x + box.size.x / 2.0) * k
	var oy := (20.0 - box.position.y * k) if down else (112.0 - box.end.y * k)
	var map := func(p: Vector2) -> Vector2:
		var q: Vector2 = turn.call(p)
		return Vector2(ox + q.x * k, oy + q.y * k)
	var T := func(pts: Array) -> Array:
		var out: Array = []
		for p: Vector2 in pts:
			out.append(map.call(p))
		return out
	var base: Vector2 = map.call(Vector2.ZERO)
	var tip: Vector2 = map.call(g.tip)
	var col: String = String(inlay.col) if forged else String(cols.claw)
	var light := Art.lighten(col, 0.6 if forged else 0.3)
	var dark := Art.darken(col, 0.45 if forged else 0.4)
	var id := "%s-%s%s" % [uid, claw.id, "-%s" % inlay.id if forged else ""]
	var defs: Array = [Art.h("linearGradient", {
		"id": "%s-k" % id, "gradientUnits": "userSpaceOnUse", "x1": Art._r2(base.x), "y1": Art._r2(base.y),
		"x2": Art._r2(tip.x), "y2": Art._r2(tip.y) },
		Art.h("stop", { "offset": 0.0, "stopColor": light }), Art.h("stop", { "offset": 0.6, "stopColor": col }),
		Art.h("stop", { "offset": 1.0, "stopColor": dark }))]
	var body: Array = []
	# el dedo del que sale (dibujo): la última falange con escamas, detrás de la garra
	var toe_c: Vector2 = map.call(toe_mm)
	body.append(Art.h("path", { "d": _path(T.call(toe_pts)), "fill": String(cols.body), "stroke": Art.darken(String(cols.body), 0.35),
		"strokeWidth": 0.7 }))
	for i in 3:
		var sx := toe_mm.x + (float(i) - 1.0) * toe_r * 0.55
		var s0: Vector2 = map.call(Vector2(sx - toe_r * 0.22, toe_mm.y + toe_r * 0.2))
		var s1: Vector2 = map.call(Vector2(sx + toe_r * 0.22, toe_mm.y + toe_r * 0.2))
		var sc: Vector2 = map.call(Vector2(sx, toe_mm.y - toe_r * 0.05))
		body.append(Art.h("path", { "d": "M%s Q%s %s" % [_p(s0), _p(sc), _p(s1)], "fill": "none", "stroke": String(cols.feathers),
			"strokeOpacity": 0.7, "strokeWidth": 0.6 }))
	# la banda alta: la garra de 95,7 mm, como sombra que asoma de la punta
	body.append(Art.h("path", { "d": _path(T.call(g.shadow)), "fill": col, "fillOpacity": 0.22, "stroke": col, "strokeOpacity": 0.35,
		"strokeWidth": 0.5, "strokeDasharray": "1.6 1.2" }))
	# el estuche (o la garra reforjada, en su material)
	body.append(Art.h("path", { "d": _path(T.call(g.outline)), "fill": "url(#%s-k)" % id, "stroke": Art.darken(col, 0.35),
		"strokeOpacity": 0.7, "strokeWidth": 0.7 }))
	# el hueso fósil dentro, como se ve en una radiografía
	if show_bone:
		body.append(Art.h("path", { "d": _path(T.call(g.bone)), "fill": String(LOOK.bone), "fillOpacity": 0.55,
			"stroke": String(LOOK.boneLine), "strokeOpacity": 0.8, "strokeWidth": 0.55 }))
	# la banda baja: dónde acabaría el estuche más corto (raya discontinua de lado a lado)
	var lo: Array = g.low
	var l0: Vector2 = map.call(lo[0])
	var l1: Vector2 = map.call(lo[1])
	body.append(Art.h("path", { "d": "M%s L%s" % [_p(l0), _p(l1)], "stroke": Looks.C["gold"], "strokeOpacity": 0.85, "strokeWidth": 0.7,
		"strokeDasharray": "1.4 1" }))
	# brillo del lomo
	var back: Array = (g.outline as Array).slice(2, int(LOOK.steps) - 4)
	var hl: Array = []
	for p: Vector2 in back:
		hl.append(p)
	body.append(Art.h("path", { "d": _path(T.call(hl), false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.55 if forged else 0.3,
		"strokeWidth": 1.1 if forged else 0.9, "strokeLinecap": "round" }))
	if forged and not (String(inlay.id) in Looks.METAL_INLAYS):
		for f: float in [0.3, 0.62]:
			var idx := int(Js.js_round(float(LOOK.steps) * f))
			var q: Vector2 = map.call((g.outline as Array)[idx])
			body.append(Art.h("path", { "d": Art.sparkle(q.x, q.y, 2.2 + 1.4 * f), "fill": "#FFFFFF", "fillOpacity": 0.85 }))
	if o.get("tipColor") != null:
		body.append(Art.h("circle", { "cx": Art._r2(tip.x), "cy": Art._r2(tip.y), "r": 1.8, "fill": o.tipColor, "fillOpacity": 0.95 }))
	var labels: Array = []
	if with_labels and not down:
		# la sección de la base: una hoja estrecha (18,7 × 7,1 mm), a escala, junto al dedo
		var hb := _sk(claw, "coreHeightMm")
		var wb := _sk(claw, "coreWidthMm")
		var sec := Vector2(minf(toe_c.x + toe_r * 1.05 * k + wb * k + 3.0, 96.0 - wb * k / 2.0), toe_c.y - hb * k * 0.15)
		body.append(Art.h("ellipse", { "cx": Art._r2(sec.x), "cy": Art._r2(sec.y), "rx": Art._r2(wb * k / 2.0), "ry": Art._r2(hb * k / 2.0),
			"fill": String(LOOK.bone), "fillOpacity": 0.7, "stroke": String(LOOK.boneLine), "strokeWidth": 0.6 }))
		labels.append({ "x": sec.x, "y": minf(sec.y + hb * k / 2.0 + 7.0, 130.0), "text": "%s × %s" % [Js.to_fixed(hb, 1), Js.to_fixed(wb, 1)],
			"size": 6.0, "color": Looks.C["dim"], "anchor": "middle" })
		# la punta no está medida (pregunta abierta)
		labels.append({ "x": tip.x + 3.0, "y": tip.y + 3.0, "text": "?", "size": 9.0, "color": Looks.C["gold"], "bold": true, "anchor": "start" })
	return {
		"defs": defs, "body": body, "labels": labels, "tip": { "x": tip.x, "y": tip.y },
		"tipAngle": float(g.tipAngle) + rot, "base": { "x": base.x, "y": base.y },
	}


## Contorno de una elipse de semiejes rx y ry (mm) centrada en c, en 24 tramos.
static func _ellipse(c: Vector2, rx: float, ry: float) -> Array:
	var out: Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		out.append(c + Vector2(rx * V8.js_cos(a), ry * V8.js_sin(a)))
	return out
