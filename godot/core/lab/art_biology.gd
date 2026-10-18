## Tribología biológica 2.0 · las lupas del banco para la biología (unidad 4f, lo que dejó pendiente la 4b:
## docs/fisica/pulido-biologia.md §9.6). No existen en art.js.
##   · "hueso" y "cavidad": la punción en corte y a escala verdadera, con las capas de la zona (Zones.section_layers) y su
##     hueso, o la cavidad del abdomen; el banco anima encima la punta que entra, topa con el hueso y lo marca, lo atraviesa
##     o se rompe contra él (app/lab/bench_biology.gd, con `dyn`);
##   · "esmalte": la punta del colmillo con su casquete de esmalte (FangEnamel.ENAMEL) metida en el surco que abre, a escala
##     verdadera, con la dureza de la punta en el contacto (tipHv);
##   · "ataque": con un ángulo de ataque que no es el de la herramienta, el surco en corte a escala verdadera con lo que
##     pasa con el material según el modo (absMode): lo que no se arranca (1 − fab) se aparta a los lados en dos rebordes
##     y lo que se arranca (fab) sale en virutas;
##   · "callo": el roce que se queda en la capa córnea de una zona con callo (la palma), en corte a escala verdadera;
##   · "laceracion": el corte de una garra que llega al hueso al rayar, en corte a escala verdadera con las capas de la zona;
##   · "afilado" (unidad 4n): la punta afilada de una garra o un colmillo reforjados en su surco, a escala verdadera, con
##     el contorno a trazos de la punta natural de la ficha (res.sharpness: naturalUm → tipRadiusUm) y, si la carga lateral
##     la mella o la dobla (survives = false), la punta mellada o doblada.
## Mismo formato que las lupas de los materiales (ArtMaterials.lupa_frame): la textura enseña lo que está quieto y `dyn` lo
## que el banco pinta encima en cada fotograma. El rótulo (text) lleva la barra de escala y lo que pasa.
## Qué sale del resultado y qué es dibujo:
##   · la escala es la de verdad (la barra lo dice): las capas con los espesores de la zona, el hueso a su profundidad con
##     su cortical y la herida hasta depthUm, con la forma de la punta del modelo (Contact.tip_geometry con el área y el
##     semiángulo del resultado: la anchura del agujero es la de grooveWidthUm);
##   · lo que le pasa al hueso sale de res.pen (boneHit, boneIndentUm, bonePierced, toolBroken); la muesca de lo que
##     entra se exagera (15 µm no se verían: el rótulo dice cuánto), el trozo de colmillo que se queda es dibujo (el motor no
##     dice por dónde se parte) y las texturas de los tejidos, también (no están a escala).
## Funciones puras y deterministas: se pueden llamar desde hilos.
## Uso: const ArtBiology = preload("res://core/lab/art_biology.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Format = preload("res://core/shared/format.gd")
const Contact = preload("res://core/shared/contact.gd")
const Art = preload("res://core/lab/art.gd")
const Zones = preload("res://core/lab/zones.gd")
const Attack = preload("res://core/lab/attack.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const ArtZones = preload("res://core/lab/art_zones.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")

## Tipos de lupa de la biología, por orden de prioridad (lupa_kind). Van detrás de los de los materiales.
const LUPA_KINDS := ["hueso", "cavidad", "laceracion", "callo", "esmalte", "afilado", "ataque"]
## El esmalte cuenta en la lupa si sube la dureza de la punta en el contacto más de esto sobre la de la dentina.
const ENAMEL_SHOWN := 1.02
## Colores de la dentina y del esmalte de la punta (dibujo).
const DENTIN := "#D9CDB2"
const ENAMEL := "#FAF8F2"
## La superficie de la piel en la lupa de la punción (fracción del radio, hacia arriba) y el fondo de lo que se enseña.
const SKIN_Y := -0.55
const FLOOR_Y := 0.9


## Qué enseña la lupa del banco con un resultado de la biología ("" si nada): la punción que llega al hueso o a la
## cavidad del abdomen, el esmalte de la punta de un colmillo que marca un sólido, el surco de un ataque que no es el de
## la herramienta o el roce que se queda en el callo.
static func lupa_kind(res: Variant) -> String:
	if not (res is Dictionary) or res.get("residualDepthUm") == null:
		return ""  # la 1.x
	var d := float(res.get("depthUm", 0.0)) if res.get("depthUm") != null else 0.0
	var w := float(res.get("grooveWidthUm", 0.0)) if res.get("grooveWidthUm") != null else 0.0
	if Js.truthy(res.get("skin")):
		var pen: Variant = res.get("pen")
		if not (pen is Dictionary):
			return ""
		if Js.truthy(res.get("puncture")):
			if pen.get("pierces") != true:
				return ""
			if pen.get("boneHit") == true and Zones.bone(res.get("zone")) != null:
				return "hueso"
			if ArtZones.layer_id(pen) == "cavidad":
				return "cavidad"
			return ""
		if pen.get("boneHit") == true and Zones.bone(res.get("zone")) != null and d > 0.0 and w > 0.0:
			return "laceracion"
		if String(Zones.resolve(res.get("zone")).id) != Zones.DEFAULT_ID and ArtZones.layer_id(pen) == "cornea" \
				and not Js.truthy(res.get("bleeds")) and d > 0.0 and w > 0.0:
			return "callo"
		return ""
	if d <= 0.0 or w <= 0.0 or res.get("tipRadiusUm") == null:
		return ""
	if res.get("tipHv") != null and float(res.tipHv) > float(res.get("hvTool", 0.0)) * ENAMEL_SHOWN:
		return "esmalte"
	var sh: Variant = res.get("sharpness")
	if sh is Dictionary and float(sh.get("sharpness", 0.0)) > 0.0:
		return "afilado"
	var att: Variant = res.get("attackDeg")
	if not Js.truthy(res.get("puncture")) and att != null and res.get("absMode") != null \
			and float(att) != Attack.default_deg(res.get("claw")):
		return "ataque"
	return ""


## La lupa de un resultado de la biología. o = { r, uid }. Devuelve lo mismo que ArtMaterials.lupa_art: { defs, body,
## kind, text, scale (unidades por µm), exaggeration, dyn }; vacía si lupa_kind(res) es "".
static func lupa_art(target: Dictionary, res: Dictionary, o: Dictionary = {}) -> Dictionary:
	var kind := lupa_kind(res)
	if kind == "":
		return ArtMaterials.lupa_frame("", {}, 0.0, "")
	var r: float = o.get("r", ArtMaterials.LUPA_R)
	var uid: String = "%s-lupa" % o.get("uid", "lp")
	var part: Dictionary
	match kind:
		"hueso", "cavidad":
			part = _lupa_puncture(res, r, uid)
		"esmalte":
			part = _lupa_enamel(res, target, r, uid)
		"ataque":
			part = _lupa_attack(res, target, r, uid)
		"callo":
			part = _lupa_callus(res, r, uid)
		"laceracion":
			part = _lupa_laceration(res, r, uid)
		"afilado":
			part = _lupa_sharp(res, target, r, uid)
	return ArtMaterials.lupa_frame(kind, part, r, uid)


## Dirección de un ángulo en pantalla (rad; y hacia abajo), con el seno y el coseno de V8.
static func _dir(a: float) -> Vector2:
	return Vector2(V8.js_cos(a), V8.js_sin(a))


## Número con coma decimal y sin ceros de más: 97 · 2,5.
static func _num(x: float, decimals := 0) -> String:
	return Js.to_fixed(x, decimals).replace(".", ",")


## Nombre de un hueso en medio de una frase («hueso cigomático», «húmero»).
static func _lower_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1) if s != "" else s


## Barra de escala vertical (la profundidad): de y0 hacia abajo len unidades en x, blanca sobre una sombra para que se lea
## en el aire y en los tejidos.
static func _vbar(x: float, y0: float, len: float) -> Array:
	var d := "M%s %s L%s %s M%s %s L%s %s M%s %s L%s %s" % [Art._n(x), Art._n(Art._r2(y0)), Art._n(x), Art._n(Art._r2(y0 + len)),
		Art._n(x - 2.0), Art._n(Art._r2(y0)), Art._n(x + 2.0), Art._n(Art._r2(y0)), Art._n(x - 2.0), Art._n(Art._r2(y0 + len)),
		Art._n(x + 2.0), Art._n(Art._r2(y0 + len))]
	return [
		Art.h("path", { "d": d, "fill": "none", "stroke": "#10262B", "strokeOpacity": 0.7, "strokeWidth": 2.4, "strokeLinecap": "round" }),
		Art.h("path", { "d": d, "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.95, "strokeWidth": 1.0, "strokeLinecap": "round" }),
	]


## Las capas de un corte a escala verdadera (k unidades por µm) desde la superficie ys hasta el borde de la lupa: cada una
## con su aspecto (ArtZones.tissue_surface) y una raya fina entre ellas; las de menos de 0,3 unidades no se dibujan (a esa
## escala no se verían) y la última llega al fondo.
static func _layer_bands(layers: Array, ys: float, k: float, r: float, uid: String, defs: Array, body: Array) -> void:
	var y_prev := ys
	for i in layers.size():
		var l: Dictionary = layers[i]
		var y1 := minf(ys + float(l.to) * k, r)
		if i == layers.size() - 1:
			y1 = r
		if y1 - y_prev < 0.3:
			continue
		var a := ArtZones.tissue_surface(String(l.look), { "x": -r, "y": y_prev, "w": 2.0 * r, "h": y1 - y_prev, "uid": "%s-%s" % [uid, l.id],
			"detail": 0.6 })
		defs.append_array(a.defs)
		body.append_array(a.body)
		if y_prev > ys:
			body.append(Art.h("line", { "x1": -r, "y1": Art._r2(y_prev), "x2": r, "y2": Art._r2(y_prev), "stroke": "#000000", "strokeOpacity": 0.25,
				"strokeWidth": 0.5 }))
		y_prev = y1
		if y_prev >= r:
			break


## La punción en corte, a escala verdadera: el aire, la piel de la zona con sus capas hasta el hueso (su cortical y, si la
## punta la atraviesa, la médula) o la cavidad del abdomen, y una barra de escala que baja desde la superficie. Lo que se
## mueve (la punta, la herida, el golpe, la marca, el trozo roto) lo pinta el banco con dyn.
static func _lupa_puncture(res: Dictionary, r: float, uid: String) -> Dictionary:
	var pen: Dictionary = res.pen
	var zone := String(Zones.resolve(res.get("zone")).id)
	var depth := float(res.depthUm)
	var bone: Variant = Zones.bone(zone)
	var hit: bool = pen.get("boneHit") == true and bone != null
	var pierced: bool = hit and pen.get("bonePierced") == true
	var shown := depth * 1.12
	if hit:
		shown = maxf(shown, float(bone.toUm) + 0.35 * float(bone.corticalUm))
	var ys := SKIN_Y * r
	var k := (FLOOR_Y * r - ys) / shown  # unidades por µm
	var air := ArtMaterials._air(r, uid)
	var defs: Array = [air[0]]
	var body: Array = [air[1]]
	var layers := Zones.section_layers(zone)
	if pierced:
		var m: Dictionary = Zones.MARROW
		layers.append({ "id": m.id, "from": float(bone.toUm), "to": shown * 2.0, "look": "tejido-medula" })
	# las capas, a escala: las muy finas (la capa córnea y la epidermis del brazo, a esta escala) no se ven porque son así
	_layer_bands(layers, ys, k, r, uid, defs, body)
	# la superficie de la piel (la epidermis, a esta escala una línea)
	body.append(Art.h("rect", { "x": -r, "y": Art._r2(ys - 0.5), "width": 2.0 * r, "height": 1.0, "fill": "#F6E3D4", "fillOpacity": 0.95 }))
	# la barra de escala, bajando desde la superficie por la izquierda
	var bar_um := ArtMaterials.nice_floor(0.55 * r / k)
	body.append_array(_vbar(-0.72 * r, ys, bar_um * k))
	var text := "%s · " % ArtMaterials.len_text(bar_um)
	if hit:
		text += "%s a %s" % [_lower_first(String(bone.name)), Art._thick_label(float(bone.fromUm))]
		var tag := ArtZones.bone_tag(res)
		if tag != "":
			text += " · " + tag
	else:
		var cav: Variant = Zones.layer(Zones.stack(zone), "cavidad")
		text += "cavidad a %s" % Art._thick_label(float(cav.from) if cav != null else depth)
	var tip := Contact.tip_geometry(float(res.area), float(res.alphaDeg))
	var mm := 1000.0 * k  # unidades por mm
	return {
		"defs": defs, "body": body, "text": text, "scale": k,
		"dyn": {
			"r": r, "ys": ys, "k": k, "depth": depth * k,
			"bone": float(bone.fromUm) * k if hit else -1.0, "boneEnd": float(bone.toUm) * k if hit else -1.0,
			"R": float(tip.R) * mm, "at": float(tip.at) * mm, "ht": float(tip.ht) * mm, "tanA": float(tip.tanA),
			"hit": hit, "indent": float(pen.get("boneIndentUm", 0.0)) if pen.get("boneIndentUm") != null else 0.0, "pierced": pierced,
			"broken": pen.get("toolBroken") == true, "cavity": not hit, "bleeds": Js.truthy(res.get("bleeds")),
		},
	}


## Trayecto «M … L … (Z)» por los puntos, redondeado a centésimas.
static func _path(pts: Array, close := true) -> String:
	var parts := PackedStringArray()
	for i in pts.size():
		var p: Vector2 = pts[i]
		parts.append("%s%s %s" % ["M" if i == 0 else "L", Art._n(Art._r2(p.x)), Art._n(Art._r2(p.y))])
	return " ".join(parts) + (" Z" if close else "")


## El casquete de esmalte de la punta del colmillo, en corte y a escala verdadera: la punta del modelo (su radio,
## tipRadiusUm, y su semiángulo, alphaDeg) de dentina, con el esmalte que la cubre (FangEnamel.ENAMEL: 10 µm, estimación)
## y que se acaba subiendo por el cono (dibujo: «concentrado en la punta», Estrada 2026), metida hasta el fondo del surco
## del resultado (depthUm) en el material. El rótulo: la barra de escala, el espesor del esmalte y la dureza de la punta en
## el contacto (tipHv).
## Contorno de una punta esfero-cónica con el centro de su casquete en c, radio R y semiángulo al (rad): el flanco
## derecho desde `up` unidades por encima de la tangencia, el casquete y el flanco izquierdo hasta la misma altura.
static func _tip_outline(c: Vector2, R: float, al: float, up: float) -> Array:
	var nr := _dir(al)
	var fr := Vector2(V8.js_sin(al), -V8.js_cos(al))
	var fl := Vector2(-fr.x, fr.y)
	var out: Array = [c + nr * R + fr * up]
	for i in 25:
		out.append(c + _dir(al + (PI - 2.0 * al) * i / 24.0) * R)
	out.append(c + Vector2(-nr.x, nr.y) * R + fl * up)
	return out


## Color de la garra reforjada en la lupa del afilado (dibujo: acero claro; el material lo dice el rótulo del banco).
const SHARP_TOOL := "#9FAEB7"


## La lupa del afilado: la punta afilada metida en el surco a escala verdadera (la escala de la punta natural, para que se
## vea cuánto se ha afilado), con el contorno de la punta natural de la ficha a trazos y el mismo vértice. Si la carga
## lateral al rayar la mella (flexión) o la dobla (fluencia), la punta lo enseña (dibujo: el motor no dice la forma).
static func _lupa_sharp(res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var sh: Dictionary = res.sharpness
	var R0 := float(sh.naturalUm)
	var R1 := float(sh.tipRadiusUm)
	var depth := float(res.depthUm)
	var k := 0.42 * r / maxf(R0, depth)
	var ys := 0.22 * r
	var al := ArtMaterials._rad(float(res.get("alphaDeg", 20.0)))
	var apex := Vector2(0.0, ys + depth * k)
	var air := ArtMaterials._air(r, uid)
	var defs: Array = [air[0]]
	var body: Array = [air[1]]
	var mat := ArtMaterials.surface_art(String(target.get("id", "acero")), { "x": -r, "y": ys, "w": 2.0 * r, "h": r - ys,
		"uid": "%s-m" % uid, "detail": 0.6 })
	defs.append_array(mat.defs)
	body.append_array(mat.body)
	var up := 2.2 * r
	var tip := _tip_outline(apex - Vector2(0.0, R1 * k), R1 * k, al, up)
	body.append(Art.h("path", { "d": _path(tip), "fill": SHARP_TOOL, "stroke": "#26333A", "strokeWidth": 0.8 }))
	# el filo, con un brillo a lo largo del flanco que da la luz
	var fr := Vector2(V8.js_sin(al), -V8.js_cos(al))
	body.append(Art.h("path", { "d": _path([apex + fr * 0.15 * r, apex + fr * 0.9 * r], false), "fill": "none", "stroke": "#FFFFFF",
		"strokeOpacity": 0.8, "strokeWidth": 0.8, "strokeLinecap": "round" }))
	# la punta natural de la ficha, a trazos y con el mismo vértice
	var nat := _tip_outline(apex - Vector2(0.0, R0 * k), R0 * k, al, up)
	body.append(Art.h("path", { "d": _path(nat, false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.85, "strokeWidth": 0.9,
		"strokeDasharray": "3 2" }))
	var broke := not bool(sh.get("survives", true))
	var kind := String(sh.get("kind", "flexion")) if sh.get("kind") != null else "flexion"
	if broke:
		# mellada: dos grietas que cortan el vértice; doblada: el vértice torcido hacia atrás
		var s := maxf(0.06 * r, 3.0 * R1 * k)
		if kind == "flexion":
			body.append(Art.h("path", { "d": _path([apex + Vector2(-0.6 * s, -1.4 * s), apex + Vector2(0.1 * s, -0.7 * s),
				apex + Vector2(-0.2 * s, -0.2 * s), apex + Vector2(0.7 * s, 0.0)], false), "fill": "none", "stroke": "#FF6B5B",
				"strokeWidth": 1.1, "strokeLinecap": "round", "strokeLinejoin": "round" }))
		else:
			body.append(Art.h("path", { "d": _path([apex + Vector2(0.0, -1.2 * s), apex + Vector2(-0.5 * s, -0.4 * s),
				apex + Vector2(-1.2 * s, -0.1 * s)], false), "fill": "none", "stroke": "#FFC24A", "strokeWidth": 1.4,
				"strokeLinecap": "round", "strokeLinejoin": "round" }))
	var bar := ArtMaterials._scale_bar(r, k, 0.72 * r)
	body.append_array(bar[0])
	var gain := float(sh.get("pressureGain", 1.0))
	var text := "%s · punta de %s (la natural, %s) · presión ×%s" % [ArtMaterials.len_text(bar[1]), Format.fmt_tip_um(R1).replace(".", ","),
		Format.fmt_tip_um(R0).replace(".", ","), _num(gain, 1) if gain < 100.0 else _num(gain)]
	if broke:
		text += " · se mella" if kind == "flexion" else " · se dobla"
	return { "defs": defs, "body": body, "text": text, "scale": k }


static func _lupa_enamel(res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var R_um := float(res.tipRadiusUm)
	var t_um := float(FangEnamel.ENAMEL.thicknessUm)
	var k := 0.42 * r / maxf(R_um, float(res.depthUm))
	var ys := 0.22 * r
	var R := R_um * k
	var t := minf(t_um * k, 0.8 * R)
	var al := ArtMaterials._rad(float(res.get("alphaDeg", 20.0)))
	var c := Vector2(0.0, ys + float(res.depthUm) * k - R)
	var air := ArtMaterials._air(r, uid)
	var defs: Array = [air[0]]
	var body: Array = [air[1]]
	var mat := ArtMaterials.surface_art(String(target.get("id", "plastico")), { "x": -r, "y": ys, "w": 2.0 * r, "h": r - ys,
		"uid": "%s-m" % uid, "detail": 0.6 })
	defs.append_array(mat.defs)
	body.append_array(mat.body)
	# la punta: el casquete esférico entre las tangentes al cono y los dos flancos, que suben hasta salir de la lupa
	var nr := _dir(al)
	var nl := Vector2(-nr.x, nr.y)
	var fr := Vector2(V8.js_sin(al), -V8.js_cos(al))
	var fl := Vector2(-fr.x, fr.y)
	var tr := c + nr * R
	var tl := c + nl * R
	var up := (tr.y + r) / maxf(V8.js_cos(al), 0.05) + 2.0
	var arc: Array = []
	for i in 25:
		arc.append(c + _dir(al + (PI - 2.0 * al) * i / 24.0) * R)
	var dentin: Array = [tr + fr * up]
	dentin.append_array(arc)
	dentin.append(tl + fl * up)
	body.append(Art.h("path", { "d": _path(dentin), "fill": DENTIN, "stroke": "#8F8069", "strokeWidth": 0.6 }))
	# el esmalte: por fuera, el contorno de la punta hasta le por el cono; por dentro, t más adentro, afinándose hasta le
	var le := 1.2 * R
	var enamel: Array = [tr + fr * le]
	enamel.append_array(arc)
	enamel.append(tl + fl * le)
	for i in 7:
		var s := le * (1.0 - i / 6.0)
		enamel.append(tl + fl * s - nl * t * (1.0 - s / le))
	for i in 25:
		enamel.append(c + _dir(PI - al - (PI - 2.0 * al) * i / 24.0) * (R - t))
	for i in 7:
		var s := le * i / 6.0
		enamel.append(tr + fr * s - nr * t * (1.0 - s / le))
	body.append(Art.h("path", { "d": _path(enamel), "fill": ENAMEL, "stroke": "#FFFFFF", "strokeOpacity": 0.6, "strokeWidth": 0.4 }))
	# el brillo del esmalte
	var gloss: Array = []
	for i in 9:
		gloss.append(c + _dir(PI * (0.62 + 0.16 * i / 8.0)) * (R - 0.35 * t))
	body.append(Art.h("path", { "d": _path(gloss, false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.9, "strokeWidth": 0.8,
		"strokeLinecap": "round" }))
	var bar := ArtMaterials._scale_bar(r, k, 0.72 * r)
	body.append_array(bar[0])
	var text := "%s · esmalte de %s µm · %s HV en la punta" % [ArtMaterials.len_text(bar[1]), Js.js_num_str(t_um),
		Js.to_fixed(float(res.tipHv), 0)]
	return { "defs": defs, "body": body, "text": text, "scale": k }


## Semiancho de cada reborde del surco en la lupa del ataque, en semianchos del surco (dibujo: la forma; el área, no).
const RIDGE_SPAN := 0.6


## Área (unidades²) de la sección del surco de semiancho a y fondo d con la forma de la punta p (d·(1 − |x/a|^p)).
static func groove_area(a: float, d: float, p: float) -> float:
	return 2.0 * a * d * p / (p + 1.0)


## Alto de cada reborde (una joroba parabólica de semiancho RIDGE_SPAN·a, cuya área es 4/3 del alto por el semiancho):
## entre los dos, el área de lo que no se arranca, (1 − fab) de la sección del surco.
static func ridge_height(a: float, d: float, p: float, fab: float) -> float:
	var b := RIDGE_SPAN * a
	return 3.0 * ((1.0 - clampf(fab, 0.0, 1.0)) * groove_area(a, d, p) / 2.0) / (4.0 * b) if b > 0.0 else 0.0


## El surco en corte (de lado a lado), a escala verdadera, con lo que hace el material según el modo de abrasión del
## resultado: del volumen que desplaza la punta, lo que no se arranca (1 − fab) se aparta a los lados en dos rebordes, con
## la misma área que ese volumen, a medias; lo que se arranca (fab) sale en virutas (cuántas y dónde, dibujo). La forma del
## surco es la de la punta (casquete esférico o cono, como la huella de ArtMaterials). El rótulo: la escala, el modo, la
## cara que avanza (faceDeg) y cuánto se arranca.
static func _lupa_attack(res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var a_um := float(res.grooveWidthUm) / 2.0
	var d_um := float(res.depthUm)
	var fab := clampf(float(res.get("fab", 1.0)) if res.get("fab") != null else 1.0, 0.0, 1.0)
	var k := minf(0.38 * r / a_um, 0.4 * r / d_um)
	var ys := -0.08 * r
	var a := a_um * k
	var d := d_um * k
	var tip_r := float(res.get("tipRadiusUm", a_um * 4.0))
	var p := 2.0 if a_um <= tip_r * V8.js_cos(ArtMaterials._rad(float(res.get("alphaDeg", 30.0)))) else 1.3
	# los rebordes: una joroba parabólica a cada lado, de semiancho b, con el área de lo que se aparta
	var b := RIDGE_SPAN * a
	var hr := ridge_height(a, d, p, fab)
	var surf: Array = []
	var n := 60
	for i in n + 1:
		var x := -r + 2.0 * r * i / n
		var y := ys
		if absf(x) < a:
			y = ys + ArtMaterials.groove_profile(x, a, d, p)
		else:
			var u := (absf(x) - a - b) / b
			if absf(u) < 1.0:
				y = ys - hr * (1.0 - u * u)
		surf.append(Vector2(x, y))
	surf.append(Vector2(r, r))
	surf.append(Vector2(-r, r))
	var air := ArtMaterials._air(r, uid)
	var clip := "%s-mc" % uid
	var defs: Array = [air[0], Art.h("clipPath", { "id": clip }, Art.h("path", { "d": _path(surf) }))]
	var body: Array = [air[1]]
	var mat := ArtMaterials.surface_art(String(target.get("id", "plastico")), { "x": -r, "y": ys - hr - 1.0, "w": 2.0 * r,
		"h": r - ys + hr + 1.0, "uid": "%s-m" % uid, "detail": 0.6 })
	defs.append_array(mat.defs)
	body.append(Art.h("g", { "clipPath": "url(#%s)" % clip }, mat.body))
	body.append(Art.h("path", { "d": _path(surf.slice(0, n + 1), false), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.55,
		"strokeWidth": 0.6 }))
	# las virutas de lo que se arranca (dibujo: más cuanto más se arranca), sobre el surco
	if fab > 0.05:
		var R := Rng.new(Rng.seed_of("%s:viruta" % uid))
		var L := ArtMaterials.look(String(target.get("id", "plastico")))
		for i in 2 + int(Js.js_round(6.0 * fab)):
			var cx := (R.next() - 0.5) * 3.0 * a
			var cy := ys - 2.0 - R.next() * 0.45 * r
			var s := 0.8 + R.next() * 1.6
			var ang := R.next() * TAU
			var pts: Array = []
			for j in 3:
				pts.append(Vector2(cx, cy) + _dir(ang + TAU * j / 3.0 + R.next() * 0.6) * s * (0.6 + 0.6 * R.next()))
			body.append(Art.h("path", { "d": _path(pts), "fill": Art.lighten(String(L.base), 0.15), "stroke": "#000000", "strokeOpacity": 0.35,
				"strokeWidth": 0.3 }))
	var bar := ArtMaterials._scale_bar(r, k, 0.74 * r)
	body.append_array(bar[0])
	var face := float(res.get("faceDeg", 90.0)) if res.get("faceDeg") != null else 90.0
	var text := "%s · %s · cara a %s° · se arranca el %s %%" % [ArtMaterials.len_text(bar[1]), String(res.absMode), _num(face),
		_num(fab * 100.0)]
	return { "defs": defs, "body": body, "text": text, "scale": k }


## El roce que se queda en el callo, en corte y a escala verdadera: la capa córnea de la zona (la palma: 173 µm), la
## epidermis viva y el principio de la dermis, con la muesca del resultado (depthUm de fondo y grooveWidthUm de ancho, con
## la forma de la punta) que no llega a lo vivo: no sangra. El rótulo: la escala, el espesor del callo y lo que pule.
static func _lupa_callus(res: Dictionary, r: float, uid: String) -> Dictionary:
	var zone := String(Zones.resolve(res.get("zone")).id)
	var layers := Zones.section_layers(zone)
	var cornea: Dictionary = layers[0]
	var epi := Zones.epidermis_end_um(Zones.stack(zone))
	var d_um := float(res.depthUm)
	var a_um := float(res.grooveWidthUm) / 2.0
	var ys := -0.45 * r
	var k := (0.9 * r - ys) / (1.5 * epi)
	var air := ArtMaterials._air(r, uid)
	var defs: Array = [air[0]]
	var body: Array = [air[1]]
	_layer_bands(layers, ys, k, r, uid, defs, body)
	# la muesca: el aire a esa altura, con el borde de la capa córnea arrancada más claro
	var a := minf(a_um * k, 0.8 * r)
	var d := d_um * k
	var tip_r := float(res.get("tipRadiusUm", a_um * 4.0))
	var p := 2.0 if a_um <= tip_r * V8.js_cos(ArtMaterials._rad(float(res.get("alphaDeg", 30.0)))) else 1.3
	var notch: Array = []
	for i in 21:
		var x := -a + 2.0 * a * i / 20.0
		notch.append(Vector2(x, ys + ArtMaterials.groove_profile(x, a, d, p)))
	var air_col := Art.mix("#5E4E7A", "#2E2240", clampf((ys + 0.5 * d + r) / (2.0 * r), 0.0, 1.0))
	body.append(Art.h("path", { "d": _path(notch), "fill": air_col }))
	body.append(Art.h("path", { "d": _path(notch, false), "fill": "none", "stroke": "#FFF6EC", "strokeOpacity": 0.95, "strokeWidth": 0.7 }))
	var bar := ArtMaterials._scale_bar(r, k, 0.78 * r)
	body.append_array(bar[0])
	var text := "%s · capa córnea de %s: pule %s" % [ArtMaterials.len_text(bar[1]), Art._thick_label(float(cornea.to) - float(cornea.from)),
		Format.fmt_depth(d_um)]
	return { "defs": defs, "body": body, "text": text, "scale": k }


## El corte de una garra que llega al hueso al rayar (LACERACIÓN HASTA EL HUESO), de lado a lado y a escala verdadera: las
## capas de la zona hasta la cortical del hueso y la herida, con el ancho (grooveWidthUm), el fondo (depthUm) y la forma
## de la punta del resultado; donde toca el hueso, un destello. La barra de escala baja desde la piel.
static func _lupa_laceration(res: Dictionary, r: float, uid: String) -> Dictionary:
	var zone := String(Zones.resolve(res.get("zone")).id)
	var bone: Dictionary = Zones.bone(zone)
	var d_um := float(res.depthUm)
	var a_um := float(res.grooveWidthUm) / 2.0
	var shown := maxf(d_um * 1.12, float(bone.toUm) + 0.35 * float(bone.corticalUm))
	var ys := SKIN_Y * r
	var k := (FLOOR_Y * r - ys) / shown
	var air := ArtMaterials._air(r, uid)
	var defs: Array = [air[0]]
	var body: Array = [air[1]]
	_layer_bands(Zones.section_layers(zone), ys, k, r, uid, defs, body)
	body.append(Art.h("rect", { "x": -r, "y": Art._r2(ys - 0.5), "width": 2.0 * r, "height": 1.0, "fill": "#F6E3D4", "fillOpacity": 0.95 }))
	# la herida, con la forma de la punta
	var a := minf(a_um * k, 0.7 * r)
	var d := d_um * k
	var tip_r := float(res.get("tipRadiusUm", a_um * 4.0))
	var p := 2.0 if a_um <= tip_r * V8.js_cos(ArtMaterials._rad(float(res.get("alphaDeg", 30.0)))) else 1.3
	var cut: Array = []
	for i in 25:
		var x := -a + 2.0 * a * i / 24.0
		cut.append(Vector2(x, ys + ArtMaterials.groove_profile(x, a, d, p)))
	body.append(Art.h("path", { "d": _path(cut), "fill": "#7E1520", "fillOpacity": 0.95, "stroke": "#000000", "strokeOpacity": 0.4,
		"strokeWidth": 0.5 }))
	# el fondo toca el hueso
	var yb := ys + float(bone.fromUm) * k
	body.append(Art.h("path", { "d": "M%s %s Q%s %s %s %s" % [Art._n(-2.5), Art._n(Art._r2(yb + 0.2)), Art._n(0.0), Art._n(Art._r2(yb + 1.2)),
		Art._n(2.5), Art._n(Art._r2(yb + 0.2))], "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.95, "strokeWidth": 0.8,
		"strokeLinecap": "round" }))
	var bar_um := ArtMaterials.nice_floor(0.55 * r / k)
	body.append_array(_vbar(-0.72 * r, ys, bar_um * k))
	var text := "%s · %s a %s · hasta el hueso" % [ArtMaterials.len_text(bar_um), _lower_first(String(bone.name)),
		Art._thick_label(float(bone.fromUm))]
	return { "defs": defs, "body": body, "text": text, "scale": k }
