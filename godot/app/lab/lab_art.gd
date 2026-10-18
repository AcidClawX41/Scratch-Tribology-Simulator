## Dibujos de la interfaz del laboratorio que la 1.x componía en sus componentes (Bench.jsx, sections.jsx, ui.jsx),
## con el mismo grafo de escena que core/lab/art.gd ({ tag, attrs, children }) y números como JavaScript. No hay
## física: solo se colocan los resultados de compute() (profundidad, anchura, severidad…) en el dibujo.
## Son funciones estáticas y puras: ArtCache las ejecuta en hilos (Callable sobre este script, nunca sobre un nodo).
## - Banco: la losa (suelo, canto, superficie y borde), el surco en dos partes (líneas y extras), la huella y la
##   herramienta.
## - Cortes: la puerta (laca sobre roble) y el perfil de la huella en un sólido. Devuelven { defs, body, labels }:
##   los rótulos se escriben con Label encima (ThorVG no pinta <text>), con x, y de la línea base y text-anchor.
## - Iconos: la muestra de color de cada material de uña.
extends RefCounted

const Art = preload("res://core/lab/art.gd")
## Insectos y aguijones (2.0) y la superficie de la cutícula; para los demás materiales, la de art.gd tal cual.
const ArtInsects = preload("res://core/lab/art_insects.gd")
## Materiales de la 2.0: el aspecto de vidrio de los vidrios de coche (surface_art delega en ArtInsects para los demás).
const ArtMaterials = preload("res://core/lab/art_materials.gd")
## Biología de la 2.0: las lupas de la punción que llega al hueso o a la cavidad.
const ArtBiology = preload("res://core/lab/art_biology.gd")
## La garra falciforme del velocirraptor reconstruido (2.0, unidad 4i).
const ArtDino = preload("res://core/lab/art_dino.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const Looks = preload("res://core/lab/looks.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Contact = preload("res://core/shared/contact.gd")
const V8 = preload("res://core/shared/v8_math.gd")

# ── Banco (Bench.jsx: lienzo 360 × 170) ──
const W := 360.0
const TOP := 104.0
const FACE := 38.0
const GY := TOP + FACE * 0.46
const CX := 180.0
const X1 := 46.0

# ── Perfil de la huella (CrossSection: lienzo 320 × 112) ──
const XW := 320.0
const XTOP := 38.0
const XH := 56.0
const XCX := 160.0


static func n(v: float) -> String:
	return Js.js_num_str(v)


## Suelo, canto y superficie del material, con su borde (lo fijo del banco para cada material). Los vidrios de coche de la
## 2.0, con aspecto de vidrio y su canto (las hojas y la lámina del parabrisas; las caras comprimidas de la ventanilla).
static func bench_base(target_id: String) -> Dictionary:
	var look: Dictionary = ArtMaterials.look(target_id)
	var surf := ArtMaterials.surface_art(target_id, { "x": 12.0, "y": TOP, "w": W - 24.0, "h": FACE, "uid": "bench", "rx": 5.0 })
	var edge := ArtMaterials.edge_art(target_id, { "x": 12.0, "y": TOP + FACE - 6.0, "w": W - 24.0, "h": 22.0, "rx": 5.0, "top": TOP + FACE,
		"uid": "bench" })
	var defs: Array = (surf.defs as Array).duplicate()
	defs.append(Art.h("linearGradient", { "id": "bench-face", "x1": 0.0, "y1": 0.0, "x2": 0.0, "y2": 1.0 },
		Art.h("stop", { "offset": 0.0, "stopColor": Art.darken(look.lo, 0.25) }),
		Art.h("stop", { "offset": 1.0, "stopColor": Art.darken(look.lo, 0.55) })))
	defs.append(Art.h("radialGradient", { "id": "bench-floor", "cx": 0.5, "cy": 0.2, "r": 0.7 },
		Art.h("stop", { "offset": 0.0, "stopColor": "#000000", "stopOpacity": 0.35 }),
		Art.h("stop", { "offset": 1.0, "stopColor": "#000000", "stopOpacity": 0.0 })))
	defs.append_array(edge.defs)
	var body: Array = [
		Art.h("ellipse", { "cx": W / 2.0, "cy": TOP + FACE + 18.0, "rx": W / 2.0 - 10.0, "ry": 12.0, "fill": "url(#bench-floor)" }),
		Art.h("rect", { "x": 12.0, "y": TOP + FACE - 6.0, "width": W - 24.0, "height": 22.0, "rx": 5.0, "fill": "url(#bench-face)" }),
	]
	body.append_array(edge.body)
	body.append_array(surf.body)
	body.append(Art.h("rect", {
		"x": 12.0, "y": TOP, "width": W - 24.0, "height": FACE, "rx": 5.0, "fill": "none", "stroke": Art.rgba("#FFFFFF", 0.12) }))
	return { "defs": defs, "body": body }


## Una parte del surco del resultado: "lines" (se revelan con la punta) o "extras" (aparecen al final).
static func groove_part(target_id: String, res: Dictionary, x2: float, part: String) -> Dictionary:
	var g := Art.groove_art(target_id, res, { "x1": X1, "x2": x2, "y": GY, "uid": "bg" })
	return { part: g[part] }


## Huella de la punción (fangs: dos agujeros, la mordedura de un colmillo).
static func bench_hole(target_id: String, res: Dictionary, fangs: bool) -> Dictionary:
	return Art.puncture_art(target_id, res, { "cx": CX, "cy": GY, "uid": "bp", "fangs": fangs })


## La herramienta del banco: garra o colmillo colgando, o la uña de perfil (con la punta en tip). La garra falciforme del
## velocirraptor (2.0) es la de art_dino.gd, colgando y sin el hueso por dentro.
static func bench_tool(claw: Variant, geom: Dictionary, base: Dictionary, inlay: Dictionary, wet: bool) -> Dictionary:
	if claw != null and Velociraptor.is_dino(claw):
		return ArtDino.claw_icon_art(claw, { "orient": "down", "inlay": inlay, "uid": "bt", "bone": false })
	if claw != null:
		return Art.claw_art(claw, { "orient": "down", "inlay": inlay, "uid": "bt" })
	return Art.nail_side_art({ "geom": geom, "base": base, "inlay": inlay, "wet": wet, "uid": "bt" })


# ── Materiales de la 2.0 en el banco (art_materials.gd; bench.gd y bench_materials.gd los animan) ──

## Geometría del banco que reciben los dibujos de art_materials.gd: el surco (x1, x2, y), el punto (cx, cy) y la cara de
## arriba de la losa.
static func bench_geo(x2: float, scratch: bool, cx := CX, x_from := -1.0) -> Dictionary:
	var g := { "x1": X1, "x2": x2, "y": GY, "cx": cx, "cy": GY, "face": { "x": 12.0, "y": TOP, "w": W - 24.0, "h": FACE, "rx": 5.0 },
		"uid": "bm", "scratch": scratch }
	if x_from >= 0.0:
		g["x_from"] = x_from
	return g


## La abolladura (hoyuelo al punzar, artesa al rayar desde x_from, donde la carga pasa del colapso de la chapa), debajo de
## las marcas de la 1.x.
static func mat_dent(res: Dictionary, x2: float, scratch: bool, x_from := -1.0) -> Dictionary:
	return ArtMaterials.dent_art(res, bench_geo(x2, scratch, CX, x_from))


## Las grietas de la 2.0 a lo largo del surco, desde x_from (donde la carga llega al umbral).
static func mat_track(res: Dictionary, x2: float, x_from: float) -> Dictionary:
	return ArtMaterials.track_art(res, bench_geo(x2, true, CX, x_from))


## Lo que aparece de golpe en el punto cx: part "cracks" (el cono o las radiales, que crecen con la carga) o "glazing" (el
## panal de la ventanilla o la estrella del parabrisas, instantáneos).
static func mat_burst(target: Dictionary, res: Dictionary, x2: float, cx: float, scratch: bool, part: String) -> Dictionary:
	var g := bench_geo(x2, scratch, cx)
	g["part"] = part
	return ArtMaterials.burst_art(target, res, g)


## La lupa del resultado, centrada en (0, 0).
static func mat_lupa(target: Dictionary, res: Dictionary) -> Dictionary:
	var o := { "uid": "bl", "r": ArtMaterials.LUPA_R }
	var a := ArtMaterials.lupa_art(target, res, o)
	return a if a.kind != "" else ArtBiology.lupa_art(target, res, o)


static func lupa_view() -> Rect2:
	var r := ArtMaterials.LUPA_R + 2.0
	return Rect2(-r, -r, 2.0 * r, 2.0 * r)


## La uña de perfil del banco partida por la raíz del borde libre (part "finger" o "edge"), para doblarla o partirla.
static func nail_part(geom: Dictionary, base: Dictionary, inlay: Dictionary, wet: bool, part: String) -> Dictionary:
	return ArtMaterials.nail_part_art({ "geom": geom, "base": base, "inlay": inlay, "wet": wet, "uid": "bt" }, part)


# ── Insectos en el banco (bench.gd los anima: cuerpo, alas, aparato clavado y saco del veneno) ──

## Escala del insecto en el banco (unidades del banco por mm): el cuerpo mide ~78 unidades, entre 2,2 y 7 por mm (la
## abeja, 6,7: su aguijón de 1,8 mm, 12 unidades). El aguijón y el aparato se dibujan a esa misma escala.
static func insect_k(claw: Dictionary) -> float:
	return clampf(78.0 / float(claw.stinger.bodyMm.value), 2.2, 7.0)


## Caja del cuerpo y de las alas con la base del aguijón en (0, 0), en unidades del banco.
static func insect_view(claw: Dictionary) -> Rect2:
	var b := ArtInsects.insect_box(claw, { "k": insect_k(claw), "x": 0.0, "y": 0.0 })
	return Rect2(b.x, b.y, b.w, b.h)


static func insect_body(claw: Dictionary) -> Dictionary:
	return ArtInsects.insect_body_art(claw, { "k": insect_k(claw), "x": 0.0, "y": 0.0, "uid": "bi" })


static func insect_wings(claw: Dictionary) -> Dictionary:
	return ArtInsects.insect_wings_art(claw, { "k": insect_k(claw), "x": 0.0, "y": 0.0, "uid": "bw" })


## El aparato que se queda clavado tras la autotomía, con la entrada en la piel en (0, 0). Exagerado ×3 (APPARATUS_X)
## para que se vea latir el saco: a escala, el de la abeja mediría unas 8 unidades del banco y el saco, 2.
const APPARATUS_X := 3.0


static func apparatus(claw: Dictionary, inlay: Dictionary) -> Dictionary:
	return ArtInsects.apparatus_art(claw, { "k": insect_k(claw) * APPARATUS_X, "x": 0.0, "y": 0.0, "inlay": inlay })


static func apparatus_view(claw: Dictionary) -> Rect2:
	var b: Dictionary = ArtInsects.apparatus_art(claw, { "k": insect_k(claw) * APPARATUS_X, "x": 0.0, "y": 0.0 }).box
	return Rect2(b.x, b.y, b.w, b.h)


## El saco del veneno lleno, centrado en (0, 0), de radio r (el banco lo escala al latir y al vaciarse).
static func venom_sac(r: float) -> Dictionary:
	return ArtInsects.venom_sac_art({ "x": 0.0, "y": 0.0, "r": r, "fill": 1.0, "uid": "bsac" })


## Corte de la piel con el aguijón (lienzo 300 × 184): ArtInsects.sting_section_art.
static func sting_section(res: Dictionary, claw: Dictionary, inlay: Dictionary) -> Dictionary:
	return ArtInsects.sting_section_art(res, claw, { "uid": "sts", "inlay": inlay })


# ── Corte de la puerta (DoorLayers de sections.jsx: lienzo 300 × 156) ──

## Laca fina sobre roble macizo, con la cuña de la huella hasta su profundidad (en la madera, escala √ para que se
## vea también una huella poco profunda).
static func door_section(depth_um: float, vcol: String, laca_um: float, thickness_mm: float) -> Dictionary:
	var hh := 150.0
	var top := 6.0
	var draw := hh - 12.0
	var thick_um := thickness_mm * 1000.0
	var laca_h := draw * 0.16
	var wood_h := draw * 0.84
	var wood_top := top + laca_h
	var through := depth_um >= thick_um
	var dy: float
	if depth_um <= laca_um:
		dy = top + (Contact.clamp_js(depth_um, 0.0, laca_um) / laca_um) * laca_h
	else:
		var frac := Contact.clamp_js((depth_um - laca_um) / (thick_um - laca_um), 0.0, 1.0)
		dy = wood_top + sqrt(frac) * wood_h
	if through:
		dy = top + draw
	var d_txt := ("ATRAVIESA · %s mm" % n(thickness_mm)) if through else ("≈ " + Format.fmt_depth(depth_um))
	var laca := _layer_art("capa-laca", 8.0, top, 150.0, laca_h)
	var wood := _layer_art("capa-roble", 8.0, wood_top, 150.0, wood_h)
	var defs: Array = (laca.defs as Array) + (wood.defs as Array)
	var body: Array = (laca.body as Array) + (wood.body as Array)
	body.append(Art.h("rect", { "x": 8.0, "y": top, "width": 150.0, "height": draw, "fill": "none", "stroke": Looks.C["line2"], "strokeWidth": 1.0 }))
	var label_y := dy + 15.0 if dy < 22.0 else dy - 5.0
	body.append_array(_wedge(top, dy, vcol))
	var labels: Array = [
		_label(166.0, top + laca_h / 2.0 + 3.0, "Laca · 0–%s µm" % n(laca_um), 8.5, Looks.C["dim"]),
		_label(166.0, wood_top + 16.0, "Roble macizo", 8.5, Looks.C["dim"]),
		_label(166.0, wood_top + 29.0, "%s µm – %s mm" % [n(laca_um), n(thickness_mm)], 8.5, Looks.C["dimmer"]),
		_label(166.0, label_y, d_txt, 9.5, vcol, true),
	]
	return { "defs": defs, "body": body, "labels": labels, "aria": "Corte de la puerta: " + d_txt }


static func _layer_art(look: String, x: float, y: float, w: float, h: float) -> Dictionary:
	return Art.surface_art(look, { "x": x, "y": y, "w": w, "h": h, "uid": "ly-%s-%s" % [look, n(Js.js_round(y))], "detail": 0.8 })


static func _wedge(top: float, dy: float, vcol: String) -> Array:
	return [
		Art.h("polygon", { "points": "76,%s 90,%s 83,%s" % [n(top), n(top), n(dy)], "fill": vcol, "stroke": Art.rgba("#000000", 0.35), "strokeWidth": 0.6 }),
		Art.h("line", { "x1": 8.0, "y1": dy, "x2": 158.0, "y2": dy, "stroke": vcol, "strokeWidth": 1.4, "strokeDasharray": "4 3" }),
		Art.h("circle", { "cx": 83.0, "cy": dy, "r": 3.0, "fill": vcol, "stroke": "#000000", "strokeOpacity": 0.4, "strokeWidth": 0.6 }),
	]


static func _label(x: float, y: float, text: String, size: float, color: String, bold := false, anchor := "start") -> Dictionary:
	return { "x": x, "y": y, "text": text, "size": size, "color": color, "bold": bold, "anchor": anchor }


static func _num(res: Dictionary, key: String) -> float:
	var v: Variant = res.get(key)
	return float(v) if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) else 0.0


# ── Perfil de la huella en un sólido (CrossSection de sections.jsx) ──

## El bloque con su textura y la forma de la marca: dibujo exagerado (la escala real va de nanómetros a milímetros),
## con las proporciones y el modo que da el motor: relación anchura/profundidad, rebordes de arado, viruta de corte,
## grietas en los frágiles y agujero pasante.
static func cross_section(res: Dictionary, target: Dictionary) -> Dictionary:
	var block := ArtMaterials.surface_art(target.id, { "x": 8.0, "y": XTOP, "w": XW - 16.0, "h": XH, "uid": "xs", "rx": 5.0, "detail": 0.7 })
	var vcol: String = res.vcol
	var puncture := Js.truthy(res.get("puncture"))
	var skin_scratch := Js.truthy(res.get("skin")) and not puncture
	var depth := _num(res, "depthUm")
	var gw := _num(res, "grooveWidthUm")
	var sev := _num(res, "sev")
	var known := depth > 0.0 and gw > 0.0
	var marked := Js.is_true(res.get("scratched")) if skin_scratch else (sev > 0.02 and depth > 0.05)
	var through := Js.truthy(res.get("through"))
	var d := XH if through else 3.0 + sev * 38.0
	var ratio := gw / 2.0 / depth if known else 1.6
	var hw := Contact.clamp_js(d * ratio, 4.0, 118.0)
	var abs_mode: Variant = res.get("absMode")
	var pile := 0.0
	if marked:
		if abs_mode == "cuña":
			pile = d * 0.3
		elif abs_mode == "arado":
			pile = d * 0.2
		elif puncture and not Js.truthy(target.get("brittle")):
			pile = d * 0.08
	var L := XCX - hw
	var R := XCX + hw
	var bot := XTOP + d
	var profile: String
	if puncture:
		profile = "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s" % [
			n(L - 12.0), n(XTOP), n(L - 5.0), n(XTOP - pile), n(L), n(XTOP), n(XCX - 1.2), n(bot), n(XCX), n(bot + 1.5),
			n(XCX + 1.2), n(bot), n(R), n(XTOP), n(R + 5.0), n(XTOP - pile), n(R + 12.0), n(XTOP)]
	else:
		profile = "M%s %s Q%s %s %s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Q%s %s %s %s" % [
			n(L - 14.0), n(XTOP), n(L - 7.0), n(XTOP - pile), n(L), n(XTOP), n(XCX - hw * 0.45), n(XTOP), n(XCX - hw * 0.28), n(bot),
			n(XCX), n(bot), n(XCX + hw * 0.28), n(bot), n(XCX + hw * 0.45), n(XTOP), n(R), n(XTOP), n(R + 7.0), n(XTOP - pile),
			n(R + 14.0), n(XTOP)]
	var dims: String
	if not known:
		dims = "profundidad no calculada"
	elif puncture:
		dims = "↓ " + Format.fmt_depth(depth)
	else:
		dims = "↔ %s  ↓ %s" % [Format.fmt_depth(gw), Format.fmt_depth(depth)]
	var shattered := Js.truthy(res.get("shattered"))
	var label := dims if marked else ("hoja partida por flexión" if shattered else "sin huella medible")
	var body: Array = (block.body as Array).duplicate()
	if marked:
		var cut := ("M%s %s L%s %s L%s %s L%s %s Z" % [n(L), n(XTOP - 1.0), n(R), n(XTOP - 1.0), n(R), n(XTOP + XH + 1.0), n(L), n(XTOP + XH + 1.0)]
			if through else "%s L%s %s L%s %s Z" % [profile, n(R + 14.0), n(XTOP - 12.0), n(L - 14.0), n(XTOP - 12.0)])
		body.append(Art.h("path", { "d": cut, "fill": Looks.C["panel2"] }))
		if not through:
			body.append(Art.h("path", { "d": profile, "fill": "none", "stroke": vcol, "strokeWidth": 1.8, "strokeLinejoin": "round" }))
		else:
			body.append(Art.h("path", {
				"d": "M%s %s L%s %s M%s %s L%s %s" % [n(L), n(XTOP), n(L), n(XTOP + XH), n(R), n(XTOP), n(R), n(XTOP + XH)],
				"stroke": vcol, "strokeWidth": 1.8 }))
		if Js.truthy(target.get("brittle")) and sev > 0.3:
			for c: String in crack_lines(XCX, bot, d, 5):
				body.append(Art.h("path", { "d": c, "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.55, "strokeWidth": 0.8 }))
		if abs_mode == "corte":
			body.append(Art.h("path", {
				"d": "M%s %s q10 -4 12 -14 q1 -7 -6 -7 q-6 1 -3 7" % [n(R + 2.0), n(XTOP - 1.0)], "fill": "none", "stroke": vcol,
				"strokeWidth": 2.2, "strokeLinecap": "round" }))
	else:
		body.append(Art.h("path", { "d": "M8 %s L%s %s" % [n(XTOP), n(XW - 8.0), n(XTOP)], "stroke": vcol, "strokeWidth": 1.6 }))
	if shattered:
		body.append_array(Art.pane_fracture_art({ "x": 8.0, "y": XTOP, "w": XW - 16.0, "h": XH, "seed": target.id }))
	var title := "Perfil del agujero" if puncture else ("Perfil del arañazo" if skin_scratch else "Perfil del surco")
	var labels: Array = [
		_label(10.0, 16.0, title, 8.5, Looks.C["dim"]),
		_label(XW - 10.0, 16.0, label, 8.5, vcol if (marked or shattered) else Looks.C["dimmer"], true, "end"),
		_label(XW / 2.0, 108.0, "dibujo exagerado · proporción y modo según el modelo" if known else "esquema según la gravedad del resultado",
			7.0, Looks.C["dimmer"], false, "middle"),
	]
	var aria := ("Perfil de la huella: " + dims) if marked else ("La hoja de vidrio se ha partido por flexión" if shattered else "Sin huella medible")
	return { "defs": block.defs, "body": body, "labels": labels, "aria": aria }


## Grietas bajo la huella en un material frágil (crackLines de sections.jsx, con toFixed(1) como allí).
static func crack_lines(cx: float, y: float, d: float, count: int) -> Array[String]:
	var out: Array[String] = []
	for i in count:
		var a := PI / 2.0 + (i - (count - 1) / 2.0) * 0.55
		var l := 10.0 + d * 0.6 + (i % 2) * 6.0
		out.append("M%s %s l%s %s l%s %s" % [
			n(cx), n(y), Js.to_fixed(V8.js_cos(a) * l * 0.55, 1), Js.to_fixed(V8.js_sin(a) * l * 0.5, 1),
			Js.to_fixed(V8.js_cos(a) * l * 0.45 + (2.0 if i % 2 else -2.0), 1), Js.to_fixed(V8.js_sin(a) * l * 0.5, 1)])
	return out


# ── Iconos pequeños ──

## Muestra de color de un material de uña (el circulito de las píldoras de la 1.x), 13 × 13.
static func swatch_svg(base_id: String) -> String:
	var c: Array = Art.nail_swatch(base_id)
	return ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"13\" height=\"13\" viewBox=\"0 0 13 13\"><defs>"
		+ "<linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/>"
		+ "<stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs>"
		+ "<circle cx=\"6.5\" cy=\"6.5\" r=\"6\" fill=\"url(#g)\" stroke=\"#FFFFFF\" stroke-opacity=\"0.35\" stroke-width=\"1\"/></svg>") % [c[0], c[1]]
