## Tribología biológica 2.0 · el corte de la piel por zonas del cuerpo, con su hueso (unidad 4f, lo que dejó pendiente la
## 4b: docs/fisica/pulido-biologia.md §9.6). No existe en art.js.
##
## Lo pide Art.skin_section_art (el corte de la tarjeta del resultado) con un resultado de la 2.0 (res.pen) que no es del
## brazo de la 1.x o que llega a su hueso (applies). Con cualquier otro, ese corte sigue siendo el de la 1.x, byte a byte
## (lo vigila test_art). Mismo lienzo de 300 × 164, mismo bloque de tejido (x 8-158, de y 6 a 158) y los rótulos como
## datos (labels), que la interfaz escribe con su tipografía.
## Las bandas son las de Zones.section_layers(res.zone): las capas blandas de la zona y, debajo, la cortical de su hueso
## o, en el abdomen, la cavidad abdominal; y la médula (Zones.MARROW) si la punta atraviesa la cortical.
## Qué sale del resultado y qué es dibujo:
##   · las capas, sus espesores y a qué profundidad está el hueso: zones.gd, con sus fuentes; la herida (depthUm, su anchura
##     grooveWidthUm, si sangra, si desgarra, si inyecta), como en la 1.x;
##   · lo que le pasa al hueso (res.pen): boneHit (la punta topa con él), boneIndentUm (lo que entra), bonePierced
##     (atraviesa la cortical y acaba en la médula) y toolBroken (el colmillo se rompe contra él);
##   · el alto de las bandas es dibujo, no escala (dentro de cada banda la escala es lineal, como en la 1.x): el de
##     Looks.SKIN_BAND por (espesor en la zona / espesor en el brazo)^GAMMA, para que el callo de la palma se vea más
##     grueso que la capa córnea del brazo y la dermis de la cara más fina, con el espesor de verdad en su rótulo; el hueso
##     (o la cavidad) ocupa lo que queda hasta el fondo del bloque, así que cuanto menos tejido blando hay encima, más
##     cerca y más grande se ve. Su rótulo dice a qué profundidad está;
##   · la muesca del hueso se exagera (una entrada de 15 µm no se vería) y su rótulo dice cuánto entra; la punta rota que
##     se queda clavada tiene un tamaño de dibujo (el motor no dice por dónde se parte el colmillo); la médula, sin fondo
##     (el modelo no la acaba), llega algo más allá de la punta.
## Funciones puras y deterministas (azar de rng.gd, potencias de v8_math.gd): se pueden llamar desde hilos.
## Uso: const ArtZones = preload("res://core/lab/art_zones.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Format = preload("res://core/shared/format.gd")
const Art = preload("res://core/lab/art.gd")
const Looks = preload("res://core/lab/looks.gd")
const Zones = preload("res://core/lab/zones.gd")

## El bloque de tejido del corte (el de Art.skin_section_art) y la columna de los rótulos.
const X := 8.0
const W := 150.0
const TOP := 6.0
const BOTTOM := 158.0
const LABEL_X := 166.0
## Alto de las bandas blandas (dibujo): el de Looks.SKIN_BAND por (espesor en la zona / espesor en el brazo)^GAMMA.
const GAMMA := 0.35
## La cortical, cuando debajo va la médula, se lleva esta parte de lo que queda (dibujo).
const CORTICAL_SHARE := 0.5
## Colores del hueso marcado y de la punta rota (dibujo): la tinta del hueso y el marfil de la dentina.
const BONE_INK := "#6B5A3E"
const TIP_IVORY := "#F2E8D2"


## ¿Dibuja este módulo el corte del resultado? Con un resultado de la 2.0 en la piel (trae pen) que no es del brazo de la
## 1.x o que llega a su hueso: el corte de la 1.x no tiene hueso.
static func applies(res: Variant) -> bool:
	if not (res is Dictionary) or not Js.truthy(res.get("skin")):
		return false
	var pen: Variant = res.get("pen")
	if not (pen is Dictionary):
		return false
	if String(Zones.resolve(res.get("zone")).id) != Zones.DEFAULT_ID:
		return true
	return pen.get("boneHit") == true or layer_id(pen) in ["hueso", "medula"]


## El id de la capa que alcanza la punta en el informe pen, o "" si no alcanza ninguna (una punción que no perfora o un roce
## sin marca traen layerId a null: String(null) es un error de ejecución en GDScript).
static func layer_id(pen: Dictionary) -> String:
	var id: Variant = pen.get("layerId")
	return String(id) if id != null else ""


## ¿Atraviesa la punta la cortical? (se dibuja la médula)
static func _marrow(res: Dictionary) -> bool:
	var pen: Variant = res.get("pen")
	return pen is Dictionary and (pen.get("bonePierced") == true or layer_id(pen) == "medula")


## Espesor (µm) de cada capa blanda en el brazo (la zona de la 1.x), por id.
static func _arm_thickness() -> Dictionary:
	var out := {}
	for row: Array in (Zones.find(Zones.DEFAULT_ID) as Dictionary).layers:
		out[row[0]] = float(row[1])
	return out


## Las bandas del corte de un resultado, de arriba abajo: [{ id, name, short, from, to, look, y0, y1 }] (µm y unidades del
## lienzo). Las blandas, con el alto de dibujo de GAMMA; la última (el hueso, la cavidad o la médula) llega al fondo. top y
## bottom: el bloque de tejido (el de este corte o, en el del aguijón, el suyo, más abajo).
static func bands(res: Dictionary, top := TOP, bottom := BOTTOM) -> Array:
	var layers := Zones.section_layers(res.get("zone"))
	var soft: Array = []
	var deep: Array = []
	for l: Dictionary in layers:
		if l.id == "hueso" or l.id == "cavidad":
			deep.append(l)
		else:
			soft.append(l)
	if _marrow(res) and not deep.is_empty() and deep[0].id == "hueso":
		var b: Dictionary = deep[0]
		var depth := maxf(float(res.get("depthUm", 0.0)), float(b.to))
		var m: Dictionary = Zones.MARROW
		deep.append({
			"id": m.id, "name": m.name, "short": m.short, "from": float(b.to),
			"to": float(b.to) + (depth - float(b.to)) * 1.3 + 500.0, "col": m.col, "look": "tejido-medula",
		})
	# altos: los blandos por su espesor; lo profundo, al menos su SECTION_BAND
	var arm := _arm_thickness()
	var hs: Array = []
	var soft_h := 0.0
	for l: Dictionary in soft:
		var t := float(l.to) - float(l.from)
		var ref: float = arm.get(l.id, t)
		var hh: float = float(Looks.SKIN_BAND.get(l.id, 20.0)) * V8.js_pow(t / ref, GAMMA)
		hs.append(hh)
		soft_h += hh
	var deep_min := 0.0
	for l: Dictionary in deep:
		deep_min += float(Zones.SECTION_BAND.get(l.id, 14.0))
	var avail := bottom - top
	var k := minf(1.0, (avail - deep_min) / soft_h) if soft_h > 0.0 else 1.0
	var out: Array = []
	var y := top
	for i in soft.size():
		var band: Dictionary = (soft[i] as Dictionary).duplicate()
		band["y0"] = y
		y += float(hs[i]) * k
		band["y1"] = y
		out.append(band)
	# lo que queda, para el hueso (y la médula) o la cavidad
	var rest := bottom - y
	for i in deep.size():
		var band: Dictionary = (deep[i] as Dictionary).duplicate()
		var hh := rest
		if deep.size() == 2 and i == 0:
			hh = maxf(float(Zones.SECTION_BAND.get("hueso", 14.0)), rest * CORTICAL_SHARE)
		band["y0"] = y
		y = bottom if i == deep.size() - 1 else y + hh
		band["y1"] = y
		out.append(band)
	return out


## Altura en el corte (unidades) a um µm de profundidad: la banda que la contiene, con escala lineal dentro de ella (la
## última se alarga si hace falta).
static func y_at(bs: Array, um: float) -> float:
	var b: Dictionary = bs[bs.size() - 1]
	for k: Dictionary in bs:
		if um <= float(k.to):
			b = k
			break
	var lf: float = b.from
	var lt: float = b.to
	return float(b.y0) + clampf((um - lf) / (lt - lf), 0.0, 1.0) * (float(b.y1) - float(b.y0))


## La banda con ese id, o null.
static func band(bs: Array, id: String) -> Variant:
	for b: Dictionary in bs:
		if b.id == id:
			return b
	return null


## Rótulo de una banda: nombre corto y espesor; el hueso y la cavidad, a qué profundidad empiezan; la médula, sin más.
static func band_label(b: Dictionary) -> String:
	match String(b.id):
		"hueso", "cavidad":
			return "%s a %s" % [b.short, Art._thick_label(float(b.from))]
		"medula":
			return String(b.short)
	return "%s · %s" % [b.short, Art._thick_label(float(b.to) - float(b.from))]


## Qué le pasa al hueso, en pocas palabras para el corte ("" si nada): al rayar, que el corte llega a él; al punzar, la
## punta rota, la que lo atraviesa, lo que entra o que topa sin marcarlo.
static func bone_tag(res: Dictionary) -> String:
	var pen: Variant = res.get("pen")
	if not (pen is Dictionary) or pen.get("boneHit") != true:
		return ""
	if not Js.truthy(res.get("puncture")):
		return "hasta el hueso"
	if pen.get("toolBroken") == true:
		return "punta rota"
	if pen.get("bonePierced") == true:
		return "la atraviesa"
	var ind := float(pen.get("boneIndentUm", 0.0)) if pen.get("boneIndentUm") != null else 0.0
	if ind > 0.0:
		return "entra %s" % Format.fmt_depth(ind)
	return "no lo marca"


# ════════ TEJIDOS NUEVOS: HUESO, MÉDULA Y CAVIDAD ════════

## Rellena el rectángulo con el aspecto de una capa del corte: las de la 1.x con Art.surface_art (tejido-cornea…) y las
## nuevas con el de Zones.SECTION_LOOK: la cortical con sus osteonas, la médula amarilla con sus adipocitos y la cavidad
## con las asas del intestino. o = { x, y, w, h, uid, detail }. Devuelve { defs, body }.
static func tissue_surface(look_id: String, o: Dictionary) -> Dictionary:
	if not Zones.SECTION_LOOK.has(look_id):
		return Art.surface_art(look_id, o)
	var L: Dictionary = Zones.SECTION_LOOK[look_id]
	var x: float = o.get("x", 0.0)
	var y: float = o.get("y", 0.0)
	var w: float = o.w
	var H: float = o.h
	var detail: float = o.get("detail", 1.0)
	var id := "%s-%s" % [o.get("uid", "s"), look_id]
	var R := Rng.new(Rng.seed_of("%s:%sx%s" % [look_id, Art._n(Js.js_round(w)), Art._n(Js.js_round(H))]))
	var defs: Array = [
		Art._lin("%s-g" % id, [[0.0, Art.lighten(L.base, 0.08)], [0.55, L.base], [1.0, L.lo]]),
		Art.h("clipPath", { "id": "%s-c" % id }, Art.h("rect", { "x": x, "y": Art._r2(y), "width": w, "height": Art._r2(H) })),
	]
	var body: Array = [Art.h("rect", { "x": x, "y": Art._r2(y), "width": w, "height": Art._r2(H), "fill": "url(#%s-g)" % id })]
	match String(L.kind):
		"bone":  # cortical: laminillas y osteonas (el conducto de Havers en el centro)
			for i in Art._cnt(H / 3.0, detail):
				var yy := y + R.next() * H
				body.append(Art.h("path", { "d": Art._wavy(x, x + w, yy, 0.4 + R.next() * 0.6, 0.05 + R.next() * 0.04, R.next() * 6.0),
					"stroke": L.ink, "strokeOpacity": 0.22, "strokeWidth": 0.4, "fill": "none" }))
			for i in Art._cnt((w * H) / 70.0, detail):
				var cx := Art._r2(x + R.next() * w)
				var cy := Art._r2(y + R.next() * H)
				var r := 1.3 + R.next() * 1.1
				body.append(Art.h("circle", { "cx": cx, "cy": cy, "r": Art._r2(r), "fill": "#FFFFFF", "fillOpacity": 0.18, "stroke": L.ink,
					"strokeOpacity": 0.42, "strokeWidth": 0.35 }))
				body.append(Art.h("circle", { "cx": cx, "cy": cy, "r": Art._r2(r * 0.55), "fill": "none", "stroke": L.ink, "strokeOpacity": 0.3,
					"strokeWidth": 0.3 }))
				body.append(Art.h("circle", { "cx": cx, "cy": cy, "r": 0.35, "fill": L.ink, "fillOpacity": 0.7 }))
			Art._sheen(defs, body, id, x, y, w, H, 0.25, 0.0, 0.4)
		"fat":  # médula amarilla: adipocitos, algún vaso y las espículas de hueso que bajan de la cortical
			for i in Art._cnt((w * H) / 16.0, detail):
				var r := 1.6 + R.next() * 1.8
				body.append(Art.h("circle", { "cx": Art._r2(x + R.next() * w), "cy": Art._r2(y + R.next() * H), "r": Art._r2(r), "fill": "#FFF3C8",
					"fillOpacity": 0.35, "stroke": L.ink, "strokeOpacity": 0.45, "strokeWidth": 0.4 }))
			for i in Art._cnt((w * H) / 140.0, detail):
				body.append(Art.h("circle", { "cx": Art._r2(x + R.next() * w), "cy": Art._r2(y + R.next() * H), "r": Art._r2(0.4 + R.next() * 0.5),
					"fill": "#B8423A", "fillOpacity": 0.55 }))
			for i in Art._cnt(w / 14.0, detail):
				var sx := x + R.next() * w
				var l := 1.5 + R.next() * minf(4.0, H * 0.3)
				body.append(Art.h("line", { "x1": Art._r2(sx), "y1": Art._r2(y), "x2": Art._r2(sx + (R.next() - 0.5) * 2.0), "y2": Art._r2(y + l),
					"stroke": "#EFE5CF", "strokeOpacity": 0.8, "strokeWidth": 0.8, "strokeLinecap": "round" }))
		"cavity":  # peritoneo brillante arriba y las asas del intestino, en sombra hacia el fondo
			var loop := Art.lighten(L.base, 0.22)
			var sw := Art._r2(clampf(H * 0.3, 2.5, 7.0))
			for i in Art._cnt(w / 18.0, detail):
				var yy := y + H * (0.35 + 0.5 * R.next())
				var x0 := x - 6.0 + R.next() * w
				var d := Art._wavy(x0, x0 + 14.0 + R.next() * 14.0, yy, H * (0.08 + R.next() * 0.1), 0.18 + R.next() * 0.1, R.next() * 6.0, 8)
				body.append(Art.h("path", { "d": d, "stroke": L.ink, "strokeOpacity": 0.55, "strokeWidth": Art._r2(sw + 1.2), "fill": "none",
					"strokeLinecap": "round" }))
				body.append(Art.h("path", { "d": d, "stroke": loop, "strokeOpacity": 0.9, "strokeWidth": sw, "fill": "none", "strokeLinecap": "round" }))
				body.append(Art.h("path", { "d": d, "stroke": "#FFFFFF", "strokeOpacity": 0.16, "strokeWidth": Art._r2(sw * 0.3), "fill": "none",
					"strokeLinecap": "round" }))
			body.append(Art.h("rect", { "x": x, "y": Art._r2(y + 0.4), "width": w, "height": 0.7, "fill": "#F2D6DC", "fillOpacity": 0.55 }))
	return { "defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s-c)" % id }, body)] }


# ════════ EL CORTE ════════

## Corte de la piel de la zona del resultado, con su hueso y la herida. o = { uid = "sk" }. Devuelve { defs, body, labels }
## como Art.skin_section_art (los rótulos, { x, y, text, size, color, bold }).
static func skin_section_art(res: Dictionary, o: Dictionary = {}) -> Dictionary:
	var uid: String = o.get("uid", "sk")
	var bs := bands(res)
	var cx := X + W * 0.42
	var defs: Array = []
	var body: Array = []
	var labels: Array = []
	for b: Dictionary in bs:
		var y0: float = b.y0
		var y1: float = b.y1
		var a := tissue_surface(String(b.look), { "x": X, "y": y0, "w": W, "h": y1 - y0, "uid": "%s-%s" % [uid, b.id], "detail": 0.8 })
		defs.append_array(a.defs)
		body.append_array(a.body)
		if y0 > TOP:
			body.append(Art.h("line", { "x1": X, "y1": Art._r2(y0), "x2": X + W, "y2": Art._r2(y0), "stroke": "#000000", "strokeOpacity": 0.2,
				"strokeWidth": 0.5 }))
		labels.append({ "x": LABEL_X, "y": Art._r2((y0 + y1) / 2.0 + 3.0), "text": band_label(b), "size": 8.0, "color": Looks.C.dim })
	body.append(Art.h("rect", { "x": X, "y": TOP, "width": W, "height": BOTTOM - TOP, "fill": "none", "stroke": Looks.C.line2, "strokeWidth": 1.0 }))
	var d := float(res.get("depthUm", 0.0)) if res.get("depthUm") != null else 0.0
	if d <= 0.0:
		return { "defs": defs, "body": body, "labels": labels }
	var dy := y_at(bs, d)
	var bleeds := Js.truthy(res.get("bleeds"))
	var wound := "#7E1520" if bleeds else "#FBF1E8"
	var gw := float(res.get("grooveWidthUm", 0.0)) if res.get("grooveWidthUm") != null else 0.0
	var puncture := Js.truthy(res.get("puncture"))
	var hw := 0.0
	if puncture:
		hw = Art._r2(clampf(1.6 + sqrt(gw) / 9.0, 1.6, 7.0))
		body.append(Art.h("polygon", { "points": Art._pts([[cx - hw, TOP], [cx + hw, TOP], [cx, Art._r2(dy)]]), "fill": wound, "fillOpacity": 0.95,
			"stroke": "#000000", "strokeOpacity": 0.35, "strokeWidth": 0.5 }))
	else:
		hw = Art._r2(clampf(2.0 + sqrt(gw) / 4.0, 2.5, 26.0))
		# sin sangre, más perfilada: una muesca clara sobre el callo o la capa córnea apenas se veía
		body.append(Art.h("path", { "d": Art._notch(cx, hw, TOP, dy), "fill": wound, "fillOpacity": 0.95, "stroke": "#000000",
			"strokeOpacity": 0.3 if bleeds else 0.6, "strokeWidth": 0.5 if bleeds else 0.6 }))
		if Js.truthy(res.get("tearing")):  # bordes desgarrados: fibras arrancadas (como en la 1.x)
			var R := Rng.new(Rng.seed_of("%s:tear" % uid))
			for k in 10:
				var f := (k + 0.5) / 10.0
				var yy := TOP + (dy - TOP) * f
				var side := 1.0 if k % 2 else -1.0
				var xx := cx + side * hw * (1.0 - f) * 0.8
				body.append(Art.h("line", { "x1": Art._r2(xx), "y1": Art._r2(yy), "x2": Art._r2(xx + side * (2.0 + R.next() * 3.0)),
					"y2": Art._r2(yy - 1.0 - R.next() * 2.0), "stroke": "#FFFFFF", "strokeOpacity": 0.7, "strokeWidth": 0.5 }))
	body.append_array(_bone_marks(res, bs, cx, hw, dy, uid))
	if puncture and Js.truthy(res.get("inject")):
		body.append(Art.h("ellipse", { "cx": cx, "cy": Art._r2(dy - 1.0), "rx": 3.2, "ry": 2.2, "fill": "#E3D466", "fillOpacity": 0.9 }))
	if bleeds:
		for k in 3:
			body.append(Art.h("circle", { "cx": Art._r2(cx - 6.0 + k * 6.0), "cy": TOP - 1.2 + (k % 2) * 0.6, "r": 1.4 - (k % 2) * 0.4, "fill": "#A31F29" }))
	var vcol := String(res.get("vcol", Looks.C.dim))
	body.append(Art.h("line", { "x1": X, "y1": Art._r2(dy), "x2": X + W, "y2": Art._r2(dy), "stroke": vcol, "strokeWidth": 1.0, "strokeDasharray": "3 2" }))
	var txt := "≈ %s" % Format.fmt_depth(d)
	var tx := cx + 10.0
	var ty := clampf(dy + 3.0, TOP + 8.0, BOTTOM - 2.0)
	body.append(Art.h("rect", { "x": tx - 3.0, "y": Art._r2(ty - 8.0), "width": Art._r2(txt.length() * 5.2 + 6.0), "height": 11.0, "rx": 3.0,
		"fill": Looks.C.bg, "fillOpacity": 0.78 }))
	labels.append({ "x": tx, "y": Art._r2(ty), "text": txt, "size": 8.5, "color": vcol, "bold": true })
	# lo que le pasa al hueso, a la izquierda de la herida (el rótulo de la profundidad va a la derecha), en su banda
	var tag := bone_tag(res)
	var bone: Variant = band(bs, "hueso")
	if tag != "" and bone != null:
		var by := minf(float(bone.y0) + 10.0, float(bone.y1) - 2.0)
		var tw := tag.length() * 4.6 + 6.0
		body.append(Art.h("rect", { "x": X + 3.0, "y": Art._r2(by - 7.5), "width": Art._r2(tw), "height": 10.0, "rx": 3.0, "fill": Looks.C.bg,
			"fillOpacity": 0.78 }))
		labels.append({ "x": X + 6.0, "y": Art._r2(by), "text": tag, "size": 7.5, "color": vcol, "bold": true })
	return { "defs": defs, "body": body, "labels": labels }


## Lo que le pasa al hueso bajo la herida (cx, dy): la punta rota clavada, la cortical atravesada (grietas y esquirlas en
## la entrada), la muesca de lo que entra (exagerada) o el golpe sin marca en la superficie del hueso. hw: el semiancho de
## la herida en la superficie.
static func _bone_marks(res: Dictionary, bs: Array, cx: float, hw: float, dy: float, uid: String) -> Array:
	var out: Array = []
	var pen: Variant = res.get("pen")
	var bone: Variant = band(bs, "hueso")
	if not (pen is Dictionary) or pen.get("boneHit") != true or bone == null:
		return out
	var yb: float = bone.y0
	var tag := bone_tag(res)
	var R := Rng.new(Rng.seed_of("%s:hueso" % uid))
	match tag:
		"punta rota":
			# el trozo de la punta, clavado en el hueso con el borde partido arriba
			var wf := maxf(1.8, hw * 6.0 / maxf(dy - TOP, 1.0))
			var top_y := dy - 6.0
			var pts: Array = [[cx - wf, top_y + 0.4], [cx - wf * 0.3, top_y - 0.7], [cx + wf * 0.2, top_y + 0.5], [cx + wf, top_y - 0.3],
				[cx, dy + 0.4]]
			for p: Array in pts:
				p[0] = Art._r2(p[0])
				p[1] = Art._r2(p[1])
			out.append(Art.h("polygon", { "points": Art._pts(pts), "fill": TIP_IVORY, "stroke": BONE_INK, "strokeWidth": 0.45 }))
			for s: float in [-1.0, 1.0]:  # la grieta que abre en el hueso
				out.append(Art.h("line", { "x1": Art._r2(cx + s * 0.6), "y1": Art._r2(yb + 0.6), "x2": Art._r2(cx + s * (2.4 + R.next())),
					"y2": Art._r2(yb + 2.6 + R.next() * 1.5), "stroke": BONE_INK, "strokeOpacity": 0.7, "strokeWidth": 0.4 }))
		"la atraviesa":
			# grietas en la cortical desde la entrada y esquirlas de hueso que la punta empuja hacia la médula
			var hb := hw * (dy - yb) / maxf(dy - TOP, 1.0)
			var marrow: Variant = band(bs, "medula")
			var yc: float = marrow.y0 if marrow != null else float(bone.y1)
			for i in 4:
				var s := -1.0 if i % 2 == 0 else 1.0
				var y0 := yb + (yc - yb) * (0.2 + 0.25 * float(i >> 1))
				out.append(Art.h("line", { "x1": Art._r2(cx + s * hb * 0.6), "y1": Art._r2(y0), "x2": Art._r2(cx + s * (hb + 4.0 + R.next() * 5.0)),
					"y2": Art._r2(y0 + 1.5 + R.next() * 3.0), "stroke": BONE_INK, "strokeOpacity": 0.65, "strokeWidth": 0.45 }))
			for i in 3:
				var ex := cx + (R.next() - 0.5) * 8.0
				var ey := yc + 2.0 + R.next() * 4.0
				var r := 0.8 + R.next() * 0.7
				out.append(Art.h("polygon", { "points": Art._pts([[Art._r2(ex - r), Art._r2(ey)], [Art._r2(ex + r * 0.4), Art._r2(ey - r)],
					[Art._r2(ex + r), Art._r2(ey + r * 0.6)]]), "fill": "#EFE5CF", "stroke": BONE_INK, "strokeOpacity": 0.6, "strokeWidth": 0.3 }))
		"no lo marca", "hasta el hueso":
			# la punta topa (o el corte llega) al hueso: un destello en su superficie, sin muesca
			out.append(Art.h("path", { "d": "M%s %s Q%s %s %s %s" % [Art._n(Art._r2(cx - 3.2)), Art._n(Art._r2(yb + 0.2)), Art._n(cx),
				Art._n(Art._r2(yb + 1.4)), Art._n(Art._r2(cx + 3.2)), Art._n(Art._r2(yb + 0.2))], "fill": "none", "stroke": "#FFFFFF",
				"strokeOpacity": 0.9, "strokeWidth": 0.8, "strokeLinecap": "round" }))
			for s: float in [-1.0, 1.0]:
				out.append(Art.h("line", { "x1": Art._r2(cx + s * 3.0), "y1": Art._r2(yb - 1.2), "x2": Art._r2(cx + s * 5.0), "y2": Art._r2(yb - 2.8),
					"stroke": "#FFFFFF", "strokeOpacity": 0.7, "strokeWidth": 0.5, "strokeLinecap": "round" }))
		_:
			# entra un poco: la muesca en la cortical (exagerada: su rótulo dice cuánto) y dos grietas finas
			out.append(Art.h("polygon", { "points": Art._pts([[Art._r2(cx - 2.2), Art._r2(yb)], [cx, Art._r2(yb + 1.9)], [Art._r2(cx + 2.2), Art._r2(yb)]]),
				"fill": "#8F7650", "fillOpacity": 0.95 }))
			for s: float in [-1.0, 1.0]:
				out.append(Art.h("line", { "x1": Art._r2(cx + s * 0.8), "y1": Art._r2(yb + 1.3), "x2": Art._r2(cx + s * (2.2 + R.next() * 1.5)),
					"y2": Art._r2(yb + 3.2 + R.next() * 1.5), "stroke": BONE_INK, "strokeOpacity": 0.6, "strokeWidth": 0.35 }))
	return out
