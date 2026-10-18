## Tribología biológica · dibujos de los materiales de la 2.0 (unidad 4f; docs/fisica/pulido-materiales.md §7.6): las
## grietas de Hertz (anillo, cono y herraduras al deslizar), el astillado y las grietas radiales de los frágiles, la
## ventanilla templada que estalla en trocitos, el parabrisas laminado que se agrieta y no cae, la abolladura de la chapa,
## la uña que se dobla o se parte, la huella que queda al levantar la punta y el aspecto de vidrio de los vidrios de coche.
## No existen en art.js.
##
## Mismo grafo de escena que core/lab/art.gd ({ tag, attrs, children } y números como JavaScript, redondeados a
## centésimas): svg.gd lo escribe y app/common/ lo rasteriza con ThorVG. art.gd y looks.gd no cambian (siguen dando los
## 372 SVG del oráculo) y todo esto solo dibuja algo cuando el resultado trae los campos de la 2.0 (Physics.V2_FIELDS):
## con un resultado de la 1.x, esos campos son null y los dibujos salen vacíos. ThorVG no pinta <text>: los rótulos van
## como datos (text, labels) y la interfaz los escribe.
##
## Qué sale del resultado y qué es dibujo:
##   · escala: las marcas del banco van a MM unidades por mm (la del surco de 25 mm por defecto) y la cara de la losa se
##     ve en escorzo (FORESHORTEN, el de la huella de la 1.x): convenciones de dibujo. La lupa enseña lo microscópico a
##     escala verdadera, con su barra de escala, o en corte, con la exageración vertical escrita en su rótulo;
##   · Hertz (fracture): el anillo (ringUm), la base del cono (crackUm) y su ángulo (coneAngleDeg) salen del resultado; al
##     deslizar, el radio del contacto bajo carga se deduce de los dos (hertz_contact_um) y las herraduras van abiertas
##     hacia delante y separadas dos radios de contacto (estimación de la guía, sobre la fig. 3 de Lawn & Marshall 1984);
##   · astillado y radiales (fracture): la longitud de las grietas (crackUm) sale del resultado; cuántas grietas laterales
##     y esquirlas hay y las seis radiales de la estrella (la punta es un cono: estrella, no la cruz del Vickers), dibujo;
##   · templado (glazing): el tamaño de los trozos (fragmentMm), cuántos caben en 5 × 5 cm (fragments25) y la capa
##     comprimida (compressionMm), del resultado; los dos trozos alargados junto al origen (Nielsen, Olesen & Stang 2009) y
##     los que se caen por el hueco, dibujo;
##   · laminado (glazing y las hojas de Glazing.WINDSCREEN): agrietado por flexión y abombado si hay penetrationRisk; el
##     número de radiales (6-12, más cuanto más pasa el golpe de la carga que lo agrieta) y los anillos, estimación visual
##     de la guía;
##   · abolladura (dent): la profundidad (depthMm) y si se ve (visible, ≥ 0,1 mm) salen del resultado; el diámetro, 30 veces
##     la profundidad (el centro del 20-40 de la guía: estimación visual de abolladuras de granizo);
##   · huella (recovery, residualDepthUm, depthUm, grooveWidthUm, tipRadiusUm, alphaDeg): profundidad bajo carga y la que
##     queda, anchura del contacto y forma de la punta, todo del resultado;
##   · uña (nail): el borde libre se separa por su raíz para doblarlo o partirlo (lo anima app/lab/bench_materials.gd); el
##     ángulo del dibujo y el momento en que cede los decide el guion, con la carga de cesión del resultado.
## Coordenadas del banco: las del lienzo de 360 × 170 de app/lab/bench.gd, que pasa su geometría en `o` (x1, x2, y del
## surco; cx, cy del punto de punción; face, la cara de arriba de la losa). En la cara, (x, z) son las coordenadas «de
## verdad» (sin escorzo): pantalla = (x, face.y + z·FORESHORTEN).
## Funciones puras y deterministas (azar de rng.gd, trigonometría de v8_math.gd): se pueden llamar desde hilos.
## Uso: const ArtMaterials = preload("res://core/lab/art_materials.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Art = preload("res://core/lab/art.gd")
const Looks = preload("res://core/lab/looks.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const Dent = preload("res://core/lab/dent.gd")

## Unidades del banco por mm para las marcas de la 2.0: el surco de 25 mm por defecto mide 70 + 25/60·222 = 162,5
## unidades en el banco de la 1.x (Bench.jsx). Convención de dibujo.
const MM := 6.5
## Escorzo de la cara de la losa (su alto en pantalla / su fondo de verdad): el de la huella de la 1.x (ry = 0,42·rx).
const FORESHORTEN := 0.42
## Radio de la lupa (unidades del banco).
const LUPA_R := 34.0
## Diámetro de la abolladura / profundidad: el centro del 20-40 de la guía (estimación visual de abolladuras de granizo).
const DENT_SPAN := 30.0
## Paleta (theme.gd) y el negro del hueco de un vidrio roto (el de art.gd).
const C := Looks.C
const HOLE := "#0A1418"
## Aspecto de los vidrios de coche de la 2.0 (dibujo): vidrio de tono verde en la ventanilla templada (el óxido de hierro
## del vidrio sodocálcico) y azul verdoso en el parabrisas, con la lámina de PVB de color miel en el canto. Mapa aparte de
## Looks.MATERIAL_LOOK, que es la tabla del oráculo de la 1.x y no se toca.
const LOOKS := {
	"ventanilla": { "kind": "glass", "base": "#C4E6DE", "lo": "#79B0A5", "tint": "#4F9A86" },
	"parabrisas": { "kind": "glass", "base": "#C8E2EE", "lo": "#7EA8BE", "tint": "#4F86A6", "pvb": "#E6D9AE" },
}
## Materiales de la 2.0 que se dibujan con el aspecto de uno de la 1.x (dibujo): el deportivo del coche en marcha (unidad
## 4r, core/lab/sports_car.gd) lleva la pintura y la chapa de aluminio del coche de aluminio.
const ALIAS := { "deportivo": "cochealu" }
## Tipos de lupa, por orden de prioridad (lupa_kind).
const LUPA_KINDS := ["templado-grieta", "templado-trozos", "laminado", "abolladura", "herradura", "cono", "astillado", "radiales",
	"recuperacion"]
## La huella que sube al levantar la punta se enseña a partir de este cuarto recuperado: el mismo umbral que el subtítulo
## (Physics.RECOVERY_TEXT_FRACTION; un test comprueba que siguen iguales).
const RECOVERY_SHOWN := 0.25


# ── Números y trazos (como art_insects.gd: String(n) de JavaScript, redondeado a centésimas) ──

static func _r2(v: float) -> float:
	return Js.js_round(v * 100.0) / 100.0


static func _n(v: float) -> String:
	return Js.js_num_str(_r2(v))


static func _p(v: Vector2) -> String:
	return "%s %s" % [_n(v.x), _n(v.y)]


## Trayecto «M … L … (Z)» por los puntos.
static func _path(pts: PackedVector2Array, close := true) -> String:
	var out := PackedStringArray()
	for i in pts.size():
		out.append(("M" if i == 0 else "L") + _p(pts[i]))
	return " ".join(out) + (" Z" if close else "")


## Puntos de un arco de elipse (centro c, semiejes rx y ry) de a0 a a1 (rad), en n tramos.
static func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		out.append(c + Vector2(rx * V8.js_cos(a), ry * V8.js_sin(a)))
	return out


static func _rad(deg: float) -> float:
	return deg * PI / 180.0


## Una grieta como se ve en un vidrio: una línea oscura (la sombra de la grieta) y encima, más fina, el reflejo blanco.
## Así se lee sobre un vidrio claro y sobre uno oscuro. d: el trayecto; w: grosor; op: opacidad del reflejo.
static func _crack(d: String, w: float, op: float, round_caps := true) -> Array:
	var a := { "d": d, "fill": "none", "stroke": "#10262B", "strokeOpacity": _r2(0.42 * op), "strokeWidth": _r2(w + 0.55) }
	var b := { "d": d, "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": _r2(op), "strokeWidth": _r2(w) }
	if round_caps:
		a["strokeLinecap"] = "round"
		b["strokeLinecap"] = "round"
	return [Art.h("path", a), Art.h("path", b)]


## Dirección de un ángulo (rad), con el seno y el coseno de V8.
static func _dir(a: float) -> Vector2:
	return Vector2(V8.js_cos(a), V8.js_sin(a))


## Valor «redondo» de la serie 1-2-5 más cercano por debajo a x (x > 0): 0,2 · 0,5 · 1 · 2 · 5 · 10…
static func nice_floor(x: float) -> float:
	if x <= 0.0 or not is_finite(x):
		return 0.0
	var p := V8.js_pow(10.0, floorf(V8.js_log(x) / V8.js_log(10.0)))
	# el logaritmo puede quedarse corto o pasarse en las potencias exactas (log10(1000) = 2,9999…)
	if x / p >= 10.0 * (1.0 - 1e-12):
		p *= 10.0
	elif x / p < 1.0:
		p /= 10.0
	var m := x / p
	if m >= 5.0 * (1.0 - 1e-12):
		return 5.0 * p
	if m >= 2.0 * (1.0 - 1e-12):
		return 2.0 * p
	return p


## Longitud legible para los rótulos de la lupa (con coma decimal, como los cortes): «200 µm», «1 mm», «2,5 cm».
static func len_text(um: float) -> String:
	if um >= 10000.0:
		return "%s cm" % _dec(um / 10000.0)
	if um >= 1000.0:
		return "%s mm" % _dec(um / 1000.0)
	return "%s µm" % _dec(um)


static func _dec(x: float) -> String:
	var s := Js.to_fixed(x, 0) if absf(x - Js.js_round(x)) < 1e-9 else Js.to_fixed(x, 1)
	return s.replace(".", ",")


## Milímetros con coma para los rótulos: 0,32 · 2,8.
static func mm_text(x: float) -> String:
	return (Js.to_fixed(x, 2) if x < 1.0 else Js.to_fixed(x, 1)).replace(".", ",")


# ════════ ASPECTO DE LOS VIDRIOS DE COCHE ════════

## Aspecto de un material: el de los vidrios de coche de la 2.0 o el de siempre (ArtInsects.look: Looks.MATERIAL_LOOK y la
## cutícula).
static func look(id: String) -> Dictionary:
	id = String(ALIAS.get(id, id))
	return LOOKS[id] if LOOKS.has(id) else ArtInsects.look(id)


## La superficie de un material: los vidrios de coche con su aspecto de vidrio; los demás, la de siempre
## (ArtInsects.surface_art, que es la de art.gd salvo la cutícula). o = { x, y, w, h, uid, detail, rx }.
static func surface_art(look_id: String, o: Dictionary) -> Dictionary:
	look_id = String(ALIAS.get(look_id, look_id))
	if not LOOKS.has(look_id):
		return ArtInsects.surface_art(look_id, o)
	var x: float = o.get("x", 0.0)
	var y: float = o.get("y", 0.0)
	var w: float = o.w
	var H: float = o.h
	var rx: float = o.get("rx", 0.0)
	var L: Dictionary = LOOKS[look_id]
	var id := "%s-%s" % [o.get("uid", "s"), look_id]
	var defs: Array = [
		Art._lin("%s-g" % id, [[0.0, Art.lighten(L.base, 0.08)], [0.55, L.base], [1.0, L.lo]]),
		Art.h("clipPath", { "id": "%s-c" % id }, Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx })),
	]
	var body: Array = [Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": rx, "fill": "url(#%s-g)" % id, "fillOpacity": 0.85 })]
	# los reflejos en diagonal del vidrio de la 1.x
	for q: Array in [[0.12, 0.2, 0.1, 0.02, 0.3], [0.24, 0.27, 0.17, 0.14, 0.18], [0.66, 0.74, 0.64, 0.56, 0.12]]:
		body.append(Art.h("polygon", {
			"points": Art._pts([[x + w * q[0], y], [x + w * q[1], y], [x + w * q[2], y + H], [x + w * q[3], y + H]]),
			"fill": "#FFFFFF", "fillOpacity": q[4] }))
	# el tono del vidrio de coche (dibujo)
	body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "fill": L.tint, "fillOpacity": 0.1 }))
	if look_id == "parabrisas":
		# la franja tintada de arriba de los parabrisas (dibujo)
		defs.append(Art._lin("%s-band" % id, [[0.0, L.tint, 0.4], [1.0, L.tint, 0.0]]))
		body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": H * 0.32, "fill": "url(#%s-band)" % id }))
	else:
		# las ondas suaves que dejan los rodillos del horno de templado (dibujo)
		for k in 3:
			body.append(Art.h("path", { "d": Art._wavy(x, x + w, y + H * (0.3 + 0.22 * k), 0.6, 0.045, 1.3 * k, 18),
				"stroke": "#FFFFFF", "strokeOpacity": 0.08, "strokeWidth": 1.4, "fill": "none" }))
	body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": 0.9, "fill": "#FFFFFF", "fillOpacity": 0.7 }))
	return { "defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s-c)" % id }, body)] }


## El canto de la losa del banco (la cara de delante: o = { x, y, w, h, rx, top }, con top el borde de arriba que se ve):
## en el parabrisas, las dos hojas de vidrio y la lámina de PVB con sus espesores (Glazing.WINDSCREEN); en la ventanilla
## templada, las capas comprimidas de las dos caras (el 21 % del espesor, Glazing.COMPRESSION_DEPTH_FRAC), algo más
## oscuras. Vacío en los demás materiales.
static func edge_art(look_id: String, o: Dictionary) -> Dictionary:
	if not LOOKS.has(look_id):
		return { "defs": [], "body": [] }
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var H: float = o.h
	var top: float = o.get("top", y)
	var L: Dictionary = LOOKS[look_id]
	var id := "%s-edge-%s" % [o.get("uid", "e"), look_id]
	var defs: Array = [Art.h("clipPath", { "id": id }, Art.h("rect", { "x": x, "y": y, "width": w, "height": H, "rx": o.get("rx", 0.0) }))]
	var body: Array = []
	var bottom := y + H
	if look_id == "parabrisas":
		var lam: Dictionary = Glazing.WINDSCREEN.laminated
		var plies: Array = lam.plies
		var total := float(plies[0]) + float(lam.pvbMm) + float(plies[1])
		var y1 := top + (bottom - top) * float(plies[0]) / total
		var y2 := y1 + (bottom - top) * float(lam.pvbMm) / total
		body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": y1 - y, "fill": Art.darken(L.lo, 0.2), "fillOpacity": 0.92 }))
		body.append(Art.h("rect", { "x": x, "y": y1, "width": w, "height": y2 - y1, "fill": L.pvb, "fillOpacity": 0.9 }))
		body.append(Art.h("rect", { "x": x, "y": y2, "width": w, "height": bottom - y2, "fill": Art.darken(L.lo, 0.38), "fillOpacity": 0.92 }))
	else:
		var d := (bottom - top) * Glazing.COMPRESSION_DEPTH_FRAC
		body.append(Art.h("rect", { "x": x, "y": y, "width": w, "height": top - y + d, "fill": "#123A44", "fillOpacity": 0.3 }))
		body.append(Art.h("rect", { "x": x, "y": bottom - d, "width": w, "height": d, "fill": "#123A44", "fillOpacity": 0.3 }))
	return { "defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s)" % id }, body)] }


# ════════ QUÉ HAY QUE DIBUJAR ════════

## ¿Trae el resultado los campos de la 2.0? (residualDepthUm nunca es null en la 2.0 y siempre lo es en la 1.x)
static func is_v2(res: Variant) -> bool:
	return res is Dictionary and (res as Dictionary).get("residualDepthUm") != null


## Campo de la 2.0 del resultado si es un diccionario; si no, null.
static func _f(res: Dictionary, key: String) -> Variant:
	var v: Variant = res.get(key)
	return v if v is Dictionary else null


## Material con que se dibujan las marcas de la 1.x (el surco y la huella de art.gd): los vidrios de coche, como el vidrio
## de ventana (art.gd no los conoce y los pintaría como el plástico, sin esquirlas).
static func marks_look_id(target_id: String) -> String:
	return "vidrio" if LOOKS.has(target_id) else String(ALIAS.get(target_id, target_id))


## El resultado que reciben las marcas de la 1.x: el mismo, salvo cuando la ventanilla templada estalla (el panal de
## trozos de burst_art sustituye a las grietas de la ventana recocida de art.gd). No modifica res.
static func res_for_1x_marks(res: Variant) -> Variant:
	if not is_v2(res):
		return res
	var gl: Variant = _f(res, "glazing")
	if gl != null and gl.kind == "templado" and gl.shattered == true:
		var r: Dictionary = (res as Dictionary).duplicate()
		r["shattered"] = false
		return r
	return res


## ¿Se estalla la ventanilla o se agrieta el parabrisas por flexión? (el panal o la estrella grande del banco)
static func glazing_burst(res: Dictionary) -> String:
	var gl: Variant = _f(res, "glazing")
	if gl == null:
		return ""
	if gl.kind == "templado" and gl.shattered == true:
		return "templado"
	if gl.kind == "laminado" and gl.cracked == true and gl.cause == "flexión":
		return "laminado"
	return ""


## ¿Hay una abolladura que se vea? (dent.visible: ≥ 0,1 mm)
static func dent_visible(res: Dictionary) -> bool:
	var d: Variant = _f(res, "dent")
	return d != null and d.visible == true and float(d.depthMm) > 0.0


## ¿Se enseña la huella que sube al levantar la punta? En los no frágiles, con un cuarto o más recuperado.
static func recovery_shown(res: Dictionary) -> bool:
	var rec: Variant = _f(res, "recovery")
	return rec != null and _f(res, "fracture") == null and float(rec.fraction) >= RECOVERY_SHOWN \
		and float(res.get("depthUm", 0.0)) >= 0.05 and float(res.get("grooveWidthUm", 0.0)) > 0.0


## Qué enseña la lupa del banco: el fenómeno protagonista del resultado ("" si no hay nada microscópico que enseñar).
static func lupa_kind(res: Variant) -> String:
	if not is_v2(res):
		return ""
	var gl: Variant = _f(res, "glazing")
	if gl != null and gl.kind == "templado" and gl.shattered == true:
		return "templado-grieta" if gl.cause == "grieta" else "templado-trozos"
	if gl != null and gl.kind == "laminado" and gl.cracked == true:
		return "laminado"
	if dent_visible(res):
		return "abolladura"
	var fr: Variant = _f(res, "fracture")
	if fr != null and fr.cracks == true:
		match String(fr.pattern):
			"herradura":
				return "herradura"
			"cono":
				return "cono"
			"astillado":
				return "astillado"
			"radiales":
				return "radiales"
	if recovery_shown(res):
		return "recuperacion"
	return ""


## Radio del contacto bajo carga (µm) en unas grietas de Hertz: el anillo nace a RING_RATIO veces el contacto de la carga
## crítica (Mouginot & Maugis 1985) y la base del cono crece como (P/Pc)^(2/3) (Fracture.cone_radius_um); el contacto,
## como (P/Pc)^(1/3). Así, a = (ringUm/RING_RATIO)·√(crackUm/ringUm).
static func hertz_contact_um(fr: Dictionary) -> float:
	var ring: float = fr.ringUm
	if ring <= 0.0:
		return 0.0
	return ring / Fracture.RING_RATIO * sqrt(maxf(float(fr.crackUm), ring) / ring)


## Radio de la abolladura en el dibujo (mm): la mitad de DENT_SPAN veces su profundidad.
static func dent_radius_mm(depth_mm: float) -> float:
	return DENT_SPAN * depth_mm / 2.0


# ════════ LA LOSA: GEOMETRÍA COMÚN ════════

static func _face(o: Dictionary) -> Rect2:
	var f: Dictionary = o.face
	return Rect2(float(f.x), float(f.y), float(f.w), float(f.h))


static func _face_clip(id: String, o: Dictionary) -> Dictionary:
	var f: Dictionary = o.face
	return Art.h("clipPath", { "id": id }, Art.h("rect", { "x": f.x, "y": f.y, "width": f.w, "height": f.h, "rx": f.get("rx", 0.0) }))


## Del punto de la cara (x, z) sin escorzo a la pantalla.
static func _screen(f: Rect2, p: Vector2) -> Vector2:
	return Vector2(p.x, f.position.y + p.y * FORESHORTEN)


static func _empty() -> Dictionary:
	return { "defs": [], "body": [] }


# ════════ ABOLLADURA (debajo de todo) ════════

## Coseno del ángulo desde el que se ve la losa (su seno es el escorzo): lo que baja en pantalla un punto que se hunde.
const SAG := 0.9075241043
## Alturas de los tres reflejos de la abolladura, en fracciones del fondo de la cara (dibujo).
const STREAKS := [0.22, 0.5, 0.78]


## Perfil de la abolladura (el del corte de la lupa): 1 en el centro y 0 en el borde, (1 + cos(π·r/R))/2.
static func dent_shape(r: float, R: float) -> float:
	if R <= 0.0 or r >= R:
		return 0.0
	return (1.0 + V8.js_cos(PI * r / R)) / 2.0


## La abolladura del resultado en la losa: un hoyuelo en el punto (cx, cy) al punzar o golpear, o una artesa a lo largo
## del surco al rayar (de x1 a x2 en y), de ancho DENT_SPAN veces su profundidad y en escorzo. La pared del fondo, más
## clara (le da la luz de delante), y la de delante, en sombra. Y tres reflejos de lado a lado de la losa que bajan lo que
## se hunde la chapa en cada punto, a la escala del banco (se ven también cuando la abolladura es más ancha que la losa).
## Solo si se ve (dent.visible). o = { x1, x2, y, cx, cy, face, uid, scratch }. Devuelve { defs, body, radius
## (unidades), sag (lo que baja un reflejo en el centro, unidades) }.
static func dent_art(res: Dictionary, o: Dictionary) -> Dictionary:
	if not is_v2(res) or not dent_visible(res):
		return _empty()
	var dent: Dictionary = res.dent
	var depth: float = dent.depthMm
	var R := dent_radius_mm(depth) * MM
	var ry := R * FORESHORTEN
	var f := _face(o)
	var uid: String = "%s-dent" % o.get("uid", "m")
	var defs: Array = [_face_clip("%s-f" % uid, o)]
	var body: Array = []
	var shape: String
	var box: Rect2
	if Js.truthy(o.get("scratch")):
		var x1: float = o.get("x_from", o.x1)
		var x2: float = o.x2
		var y: float = o.y
		var pts := PackedVector2Array([Vector2(x1, y - ry), Vector2(x2, y - ry)])
		pts.append_array(_arc(Vector2(x2, y), R, ry, -PI / 2.0, PI / 2.0, 12))
		pts.append(Vector2(x1, y + ry))
		pts.append_array(_arc(Vector2(x1, y), R, ry, PI / 2.0, PI * 1.5, 12))
		shape = _path(pts)
		box = Rect2(x1 - R, y - ry, x2 - x1 + 2.0 * R, 2.0 * ry)
	else:
		var c := Vector2(float(o.cx), float(o.cy))
		shape = _path(_arc(c, R, ry, 0.0, TAU, 40))
		box = Rect2(c.x - R, c.y - ry, 2.0 * R, 2.0 * ry)
	defs.append(Art.h("clipPath", { "id": "%s-s" % uid }, Art.h("path", { "d": shape })))
	defs.append(Art._lin("%s-g" % uid, [[0.0, "#FFFFFF", 0.0], [0.22, "#FFFFFF", 0.2], [0.5, "#FFFFFF", 0.0], [0.62, "#000000", 0.08],
		[0.86, "#000000", 0.32], [1.0, "#000000", 0.0]],
		{ "user": true, "x1": _r2(box.position.x), "y1": _r2(box.position.y), "x2": _r2(box.position.x), "y2": _r2(box.end.y) }))
	body.append(Art.h("g", { "clipPath": "url(#%s-s)" % uid },
		Art.h("rect", { "x": _r2(box.position.x), "y": _r2(box.position.y), "width": _r2(box.size.x), "height": _r2(box.size.y), "fill": "url(#%s-g)" % uid })))
	# el borde del hoyuelo, apenas marcado
	body.append(Art.h("path", { "d": shape, "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.14, "strokeWidth": 0.6 }))
	# los reflejos: cada punto baja lo que se hunde la chapa ahí (profundidad × perfil), visto en escorzo
	var sag := depth * MM * SAG
	var scratch := Js.truthy(o.get("scratch"))
	var zc := (float(o.get("cy", o.get("y", f.position.y))) - f.position.y) / FORESHORTEN
	var zg := (float(o.get("y", f.position.y)) - f.position.y) / FORESHORTEN
	var streaks := PackedStringArray()
	for zf: float in STREAKS:
		var z := zf * f.size.y / FORESHORTEN
		var pts := PackedVector2Array()
		for i in 73:
			var x := f.position.x + f.size.x * i / 72.0
			var r: float
			if scratch:
				var xs := clampf(x, float(o.get("x_from", o.x1)), float(o.x2))
				r = Vector2(x - xs, z - zg).length()
			else:
				r = Vector2(x - float(o.cx), z - zc).length()
			pts.append(Vector2(x, f.position.y + z * FORESHORTEN + sag * dent_shape(r, R)))
		streaks.append(_path(pts, false))
	body.append(Art.h("path", { "d": " ".join(streaks), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.3, "strokeWidth": 0.7,
		"strokeLinecap": "round" }))
	return { "defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s-f)" % uid }, body)], "radius": R, "sag": sag }


# ════════ A LO LARGO DEL SURCO (se revela con la punta) ════════

## Las grietas de la 2.0 a lo largo del surco al rayar: las herraduras de Hertz y el astillado (grietas laterales y
## desconchones). Empiezan en o.x_from (donde la carga llega al umbral; si no, en x1) y acaban en x2. o = { x1, x2, y,
## x_from, face, uid }. Devuelve { defs, body, count (herraduras o grietas laterales), spacing, size (unidades) }.
static func track_art(res: Dictionary, o: Dictionary) -> Dictionary:
	if not is_v2(res) or Js.truthy(res.get("puncture")):
		return _empty()
	var fr: Variant = _f(res, "fracture")
	if fr == null or fr.cracks != true:
		return _empty()
	var uid: String = "%s-trk" % o.get("uid", "m")
	var x0: float = o.get("x_from", o.x1)
	var x2: float = o.x2
	var y: float = o.y
	var out: Dictionary
	if fr.pattern == "herradura":
		out = _horseshoes(fr, Vector2(x0, y), x2 - x0, MM / 1000.0, FORESHORTEN, 0.6)
	elif fr.pattern == "astillado":
		out = _chips(fr, res, Vector2(x0, y), x2 - x0, MM / 1000.0, FORESHORTEN, "%s:%s" % [uid, _n(x2)], 0.3)
	else:
		return _empty()
	return {
		"defs": [_face_clip("%s-f" % uid, o)], "body": [Art.h("g", { "clipPath": "url(#%s-f)" % uid }, out.body)],
		"count": out.count, "spacing": out.spacing, "size": out.size,
	}


## Herraduras de Hertz a lo largo de una pista que empieza en p0 y mide len unidades hacia +x, a k unidades por µm y con
## escorzo fy: la grieta de la superficie (arco de RING_RATIO veces el contacto, en la cola del contacto: abierta hacia
## delante) y, más tenue, la base de su cono vista a través del vidrio (crackUm). Separadas dos radios de contacto.
## min_r: radio mínimo dibujado (para que se vean a la escala del banco).
static func _horseshoes(fr: Dictionary, p0: Vector2, len: float, k: float, fy: float, min_r: float) -> Dictionary:
	var a := hertz_contact_um(fr) * k
	var ring := maxf(a * Fracture.RING_RATIO, min_r)
	var cone := maxf(float(fr.crackUm) * k, ring)
	var step := maxf(2.0 * a, 0.5)
	var surf := PackedStringArray()
	var flank := PackedStringArray()
	var n := 0
	var x := p0.x + ring
	while x <= p0.x + len - 0.2 * ring:
		var c := Vector2(x, p0.y)
		surf.append(_path(_arc(c, ring, ring * fy, _rad(70.0), _rad(290.0), 10), false))
		if cone > ring * 1.05:
			flank.append(_path(_arc(c, cone, cone * fy, _rad(105.0), _rad(255.0), 10), false))
		x += step
		n += 1
	var body: Array = []
	if not flank.is_empty():
		body.append(Art.h("path", { "d": " ".join(flank), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.25, "strokeWidth": 0.35 }))
	if not surf.is_empty():
		body.append_array(_crack(" ".join(surf), 0.45, 0.85))
	return { "body": body, "count": n, "spacing": step, "size": cone }


## Astillado a lo largo de una pista: grietas laterales de crackUm desde el centro del surco a los dos lados (una por cada
## longitud de grieta, alternando un poco: dibujo) y desconchones semicirculares en el borde del surco. k: unidades por µm;
## fy: escorzo; min_hw: semiancho mínimo del surco dibujado.
static func _chips(fr: Dictionary, res: Dictionary, p0: Vector2, len: float, k: float, fy: float, seed_text: String, min_hw: float) -> Dictionary:
	var c := float(fr.crackUm) * k
	var hw := maxf(float(res.get("grooveWidthUm", 0.0)) / 2.0 * k, min_hw)
	var out := { "body": [], "count": 0, "spacing": 0.0, "size": c }
	if c <= hw:
		return out
	var R := Rng.new(Rng.seed_of("astillado:" + seed_text))
	var step := maxf(c, 1.2)
	var cracks := PackedStringArray()
	var flakes := PackedStringArray()
	var n := 0
	var x := p0.x + 0.5 * step
	var side := 1.0
	while x <= p0.x + len:
		for s: float in [-1.0, 1.0]:
			var j := (R.next() - 0.5) * 0.5 * step
			var l := c * (0.75 + 0.25 * R.next())
			var a := Vector2(x + j * 0.3, p0.y + s * hw * fy)
			var m := Vector2(x + j * 0.7 + 0.12 * l, p0.y + s * (hw + 0.55 * (l - hw)) * fy)
			var b := Vector2(x + j + 0.2 * l, p0.y + s * l * fy)
			cracks.append(_path(PackedVector2Array([a, m, b]), false))
		# desconchón: media elipse pegada al borde del surco, alternando los lados
		var rx := 0.45 * c * (0.7 + 0.5 * R.next())
		var ry := (0.55 * (c - hw) + 0.2 * hw) * fy
		flakes.append(_path(_arc(Vector2(x + 0.25 * step, p0.y + side * hw * fy), rx, ry * side, 0.0, PI, 8)))
		side = -side
		x += step
		n += 1
	var body: Array = [
		Art.h("path", { "d": " ".join(flakes), "fill": "#FFFFFF", "fillOpacity": 0.3, "stroke": "#10262B", "strokeOpacity": 0.35, "strokeWidth": 0.4 }),
	]
	body.append_array(_crack(" ".join(cracks), 0.4, 0.8))
	return { "body": body, "count": n, "spacing": step, "size": c }


# ════════ EN UN PUNTO (aparece de golpe) ════════

## Las marcas de la 2.0 que aparecen de golpe en el punto (cx, cy): el anillo y el cono de Hertz o la estrella de grietas
## radiales al apretar, el panal de trozos de la ventanilla templada que estalla y la estrella con telaraña del parabrisas
## laminado agrietado por flexión (con el abombado si podría atravesarlo). Al rayar (o.scratch), el punto es donde la carga
## llega al umbral del vidrio y no hay anillo ni estrella (son las del surco). o = { cx, cy, face, uid, scratch, part }:
## part "cracks" (solo el cono o las radiales, que el banco hace crecer con la carga), "glazing" (solo el panal o la
## estrella del vidrio de coche, instantáneos) o nada (todo).
## Devuelve { defs, body, pieces, cells, radials, rings }: pieces, los trozos del templado que se caen por el hueco ({ c:
## centro, poly: el trozo respecto a c, loop: el mismo, cerrado }), que el banco anima; cells, los trozos del panal con el
## centro en la cara; radials y rings, las radiales y los anillos dibujados.
static func burst_art(target: Dictionary, res: Dictionary, o: Dictionary) -> Dictionary:
	var out := { "defs": [], "body": [], "pieces": [], "cells": 0, "radials": 0, "rings": 0 }
	if not is_v2(res):
		return out
	var uid: String = "%s-bst" % o.get("uid", "m")
	var c := Vector2(float(o.cx), float(o.cy))
	var body: Array = []
	var defs: Array = [_face_clip("%s-f" % uid, o)]
	var fr: Variant = _f(res, "fracture")
	var puncture := Js.truthy(res.get("puncture")) and not Js.truthy(o.get("scratch"))
	var part: String = o.get("part", "")
	if puncture and fr != null and fr.cracks == true and part != "glazing":
		if fr.pattern == "cono":
			body.append_array(_cone_marks(fr, c))
		elif fr.pattern == "radiales":
			var st := _radial_star(fr, res, c, MM / 1000.0, FORESHORTEN, "%s:%s" % [uid, target.get("id", "")])
			body.append_array(st.body)
			out.radials = st.count
	match glazing_burst(res) if part != "cracks" else "":
		"templado":
			var t := _tempered(res.glazing, o, c, "%s-t" % uid)
			defs.append_array(t.defs)
			body.append_array(t.body)
			out.pieces = t.pieces
			out.cells = t.cells
		"laminado":
			var l := _laminated(res.glazing, res, o, c, "%s-l" % uid)
			defs.append_array(l.defs)
			body.append_array(l.body)
			out.radials = l.radials
			out.rings = l.rings
	if body.is_empty():
		return out
	out.defs = defs
	out.body = [Art.h("g", { "clipPath": "url(#%s-f)" % uid }, body)]
	return out


## Anillo de Hertz (ringUm) en la superficie y la base del cono (crackUm), más tenue, vista a través del vidrio.
static func _cone_marks(fr: Dictionary, c: Vector2) -> Array:
	var ring := maxf(float(fr.ringUm) / 1000.0 * MM, 0.6)
	var cone := maxf(float(fr.crackUm) / 1000.0 * MM, ring)
	var out: Array = [
		Art.h("path", { "d": _path(_arc(c, cone, cone * FORESHORTEN, 0.0, TAU, 36)), "fill": "#FFFFFF", "fillOpacity": 0.06,
			"stroke": "#FFFFFF", "strokeOpacity": 0.3, "strokeWidth": 0.4 }),
	]
	out.append_array(_crack(_path(_arc(c, ring, ring * FORESHORTEN, 0.0, TAU, 24)), 0.5, 0.9, false))
	return out


## Estrella de grietas radiales desde el pozo (la punta es un cono: estrella, no la cruz del Vickers): seis grietas de
## crackUm desde el centro, con un poco de azar (dibujo). k: unidades por µm; fy: escorzo.
static func _radial_star(fr: Dictionary, res: Dictionary, c: Vector2, k: float, fy: float, seed_text: String) -> Dictionary:
	var l := float(fr.crackUm) * k
	var a0 := maxf(float(res.get("grooveWidthUm", 0.0)) / 2.0 * k, 0.2)
	var R := Rng.new(Rng.seed_of("radiales:" + seed_text))
	var n := 6
	var d := PackedStringArray()
	for i in n:
		var a := TAU * (i + 0.5 * (R.next() - 0.5)) / n
		var pts := PackedVector2Array()
		for j in 5:
			var f := a0 + (l - a0) * j / 4.0
			var off := (R.next() - 0.5) * 0.18 * l * (j / 4.0)
			var u := _dir(a)
			var q := c + Vector2(u.x * f - u.y * off, (u.y * f + u.x * off) * fy)
			pts.append(q)
		d.append(_path(pts, false))
	return { "count": n, "body": _crack(" ".join(d), 0.45, 0.85) }


# ── Ventanilla templada: el panal de trozos ──

## Panal de trozos: los puntos de una red triangular de lado delta con un poco de azar y, alrededor de cada uno, el
## polígono de los centroides de los seis triángulos que lo rodean (así los trozos encajan sin huecos). origin: el origen
## de la rotura (un punto de la red, sin azar); bounds: lo que hay que cubrir. Devuelve [{ c, poly, d (distancia al
## origen), ij }] con poly en las mismas coordenadas que origin.
static func honeycomb(delta: float, origin: Vector2, bounds: Rect2, seed_text: String, jitter := 0.18) -> Array:
	var out: Array = []
	if delta <= 0.0 or not is_finite(delta):
		return out
	var R := Rng.new(Rng.seed_of("panal:" + seed_text))
	var h := delta * 0.8660254037844386
	var j0 := int(floorf((bounds.position.y - origin.y) / h)) - 2
	var j1 := int(ceilf((bounds.end.y - origin.y) / h)) + 2
	var i0 := int(floorf((bounds.position.x - origin.x) / delta)) - 2
	var i1 := int(ceilf((bounds.end.x - origin.x) / delta)) + 2
	var pts := {}
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := origin + Vector2((i + 0.5 * (j & 1)) * delta, j * h)
			var dx := R.next() - 0.5
			var dy := R.next() - 0.5
			if i != 0 or j != 0:
				p += Vector2(dx, dy) * (2.0 * jitter * delta)
			pts[Vector2i(i, j)] = p
	var grow := bounds.grow(delta)
	for j in range(j0 + 1, j1):
		for i in range(i0 + 1, i1):
			var p: Vector2 = pts[Vector2i(i, j)]
			if not grow.has_point(p):
				continue
			var odd := (j & 1) == 1
			# vecinos en orden: E, NE, NO, O, SO, SE (las filas impares van media celda a la derecha)
			var nb: Array[Vector2i] = [
				Vector2i(i + 1, j), Vector2i(i + (1 if odd else 0), j - 1), Vector2i(i - (0 if odd else 1), j - 1),
				Vector2i(i - 1, j), Vector2i(i - (0 if odd else 1), j + 1), Vector2i(i + (1 if odd else 0), j + 1),
			]
			var poly := PackedVector2Array()
			for k in 6:
				poly.append((p + (pts[nb[k]] as Vector2) + (pts[nb[(k + 1) % 6]] as Vector2)) / 3.0)
			out.append({ "c": p, "poly": poly, "d": p.distance_to(origin), "ij": Vector2i(i, j) })
	return out


## Trozos del templado que se caen por el hueco del impacto (el del origen y sus dos vecinos más cercanos): dibujo.
const TEMPERED_PIECES := 3


## La ventanilla templada que estalla: toda la cara en un panal de trozos de fragmentMm (del resultado), con dos trozos
## alargados en remolino junto al origen (Nielsen, Olesen & Stang 2009) y un hueco por el que se caen los trozos que
## rodean el origen (pieces, que anima el banco). Cada trozo, con el canto de arriba iluminado y el de abajo en sombra (se
## ha movido un pelo al estallar: dibujo). El destello y la caída, en el banco.
static func _tempered(gl: Dictionary, o: Dictionary, c: Vector2, _uid: String) -> Dictionary:
	var f := _face(o)
	var delta := float(gl.fragmentMm) * MM
	var origin := Vector2(c.x, (c.y - f.position.y) / FORESHORTEN)
	var bounds := Rect2(f.position.x, 0.0, f.size.x, f.size.y / FORESHORTEN)
	var cells := honeycomb(delta, origin, bounds, "templado:%s" % _n(delta), 0.24)
	var near: Array = cells.duplicate()
	near.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.d) < float(q.d))
	var falling := {}
	for i in mini(TEMPERED_PIECES, near.size()):
		falling[near[i].ij] = true
	var R := Rng.new(Rng.seed_of("templado-brillo:%s" % _n(delta)))
	var body: Array = []
	var holes := PackedStringArray()
	var pieces: Array = []
	var lines := PackedStringArray()
	var lit := PackedStringArray()
	var shade := PackedStringArray()
	var glints := PackedStringArray()
	var shown := 0
	for cell: Dictionary in cells:
		var scr := PackedVector2Array()
		for v: Vector2 in cell.poly:
			scr.append(_screen(f, v))
		var glint := R.next()
		if bounds.has_point(cell.c):
			shown += 1
		if falling.has(cell.ij):
			holes.append(_path(scr))
			var cc := _screen(f, cell.c)
			var rel := PackedVector2Array()
			for v: Vector2 in scr:
				rel.append(v - cc)
			var loop := PackedVector2Array(rel)
			loop.append(rel[0])
			pieces.append({ "c": cc, "poly": rel, "loop": loop })
			continue
		lines.append(_path(scr))
		# el bisel: un poco hacia dentro del trozo, los cantos de arriba e izquierda (vértices 0-3) a la luz y los de abajo
		# y derecha (3-0) en sombra
		var cc := _screen(f, cell.c)
		var ins := PackedVector2Array()
		for v: Vector2 in scr:
			ins.append(v + (cc - v).normalized() * 0.8)
		lit.append(_path(PackedVector2Array([ins[0], ins[1], ins[2], ins[3]]), false))
		shade.append(_path(PackedVector2Array([ins[3], ins[4], ins[5], ins[0]]), false))
		if glint > 0.6:
			glints.append(_path(scr))
	if not glints.is_empty():
		body.append(Art.h("path", { "d": " ".join(glints), "fill": "#FFFFFF", "fillOpacity": 0.13 }))
	body.append(Art.h("path", { "d": " ".join(holes), "fill": HOLE, "fillOpacity": 0.85 }))
	body.append(Art.h("path", { "d": " ".join(shade), "fill": "none", "stroke": "#0E2A2E", "strokeOpacity": 0.4, "strokeWidth": 0.9,
		"strokeLinejoin": "round" }))
	body.append(Art.h("path", { "d": " ".join(lit), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.5, "strokeWidth": 0.7,
		"strokeLinejoin": "round" }))
	body.append(Art.h("path", { "d": " ".join(lines), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.72, "strokeWidth": 0.35,
		"strokeLinejoin": "round" }))
	# dos trozos alargados en remolino, tangentes al hueco, a cada lado del origen (dibujo)
	var whirl := PackedStringArray()
	for s: float in [0.0, PI]:
		var a := _rad(35.0) + s
		var rr := 1.55 * delta
		var arc := _arc(origin, rr, rr, a - 0.42, a + 0.42, 6)
		var inner := _arc(origin, rr - 0.3 * delta, rr - 0.3 * delta, a + 0.36, a - 0.36, 6)
		arc.append_array(inner)
		var scr2 := PackedVector2Array()
		for v: Vector2 in arc:
			scr2.append(_screen(f, v))
		whirl.append(_path(scr2))
	body.append(Art.h("path", { "d": " ".join(whirl), "fill": "#FFFFFF", "fillOpacity": 0.16, "stroke": "#FFFFFF", "strokeOpacity": 0.8,
		"strokeWidth": 0.5 }))
	return { "defs": [], "body": body, "pieces": pieces, "cells": shown }


# ── Parabrisas laminado: estrella y telaraña ──

## Radiales de la estrella del laminado: de 6 a 12, más cuanto más pasa la fuerza de pico de la que lo agrieta (dibujo:
## estimación visual de la guía, una radial más por cada tercio de duplicación).
static func laminated_radials(peak_n: float, bend_n: float) -> int:
	if bend_n <= 0.0 or peak_n <= bend_n:
		return 6
	var doublings := V8.js_log(peak_n / bend_n) / V8.js_log(2.0)
	return 6 + int(Js.js_round(3.0 * clampf(doublings, 0.0, 2.0)))


## El parabrisas agrietado por flexión: estrella de radiales desde el impacto hasta los bordes de la losa y anillos cada
## vez más separados (la telaraña), en escorzo; la lámina de PVB sujeta los trozos: no cae ninguno. Con penetrationRisk,
## abombado hacia dentro (una sombra alrededor del impacto) y el vidrio molido en el centro.
static func _laminated(gl: Dictionary, res: Dictionary, o: Dictionary, c: Vector2, uid: String) -> Dictionary:
	var f := _face(o)
	var origin := Vector2(c.x, (c.y - f.position.y) / FORESHORTEN)
	var peak := float(res.get("peakN")) if res.get("peakN") != null else float(gl.bendN)
	var n := laminated_radials(peak, float(gl.bendN))
	var risk: bool = gl.penetrationRisk == true
	var n_rings := 4 if risk else 3
	var R := Rng.new(Rng.seed_of("laminado:%d:%s" % [n, _n(peak)]))
	var defs: Array = []
	var body: Array = []
	var ring_r: Array[float] = []
	for m in n_rings:
		ring_r.append(9.0 * V8.js_pow(1.85, float(m)))
	if risk:
		var rb: float = ring_r[-1] * 1.15
		defs.append(Art._rad("%s-b" % uid, [[0.0, "#000000", 0.42], [0.6, "#000000", 0.16], [1.0, "#000000", 0.0]]))
		body.append(Art.h("ellipse", { "cx": _r2(c.x), "cy": _r2(c.y), "rx": _r2(rb), "ry": _r2(rb * FORESHORTEN), "fill": "url(#%s-b)" % uid }))
	var angles: Array[float] = []
	for i in n:
		angles.append(TAU * (i + 0.6 * (R.next() - 0.5)) / n)
	var rad_d := PackedStringArray()
	for a: float in angles:
		var pts := PackedVector2Array()
		for j in 13:
			var dist := 2.0 + 34.0 * j
			var off := (R.next() - 0.5) * 3.0 * minf(1.0, j / 3.0)
			var u := _dir(a)
			pts.append(_screen(f, origin + Vector2(u.x * dist - u.y * off, u.y * dist + u.x * off)))
		rad_d.append(_path(pts, false))
	var web_d := PackedStringArray()
	for rr: float in ring_r:
		for i in n:
			var a0: float = angles[i]
			var a1: float = angles[(i + 1) % n] + (TAU if i == n - 1 else 0.0)
			var r0 := rr * (0.88 + 0.24 * R.next())
			var r1 := rr * (0.88 + 0.24 * R.next())
			var p0 := _screen(f, origin + _dir(a0) * r0)
			var p1 := _screen(f, origin + _dir(a1) * r1)
			var q := _screen(f, origin + _dir((a0 + a1) / 2.0) * (0.86 * (r0 + r1) / 2.0))
			web_d.append("M%s Q%s %s" % [_p(p0), _p(q), _p(p1)])
	body.append_array(_crack(" ".join(web_d), 0.4, 0.6))
	body.append_array(_crack(" ".join(rad_d), 0.55, 0.85))
	# el vidrio molido bajo la punta (dibujo)
	var crush := _arc(c, 3.2, 3.2 * FORESHORTEN, 0.0, TAU, 9)
	for i in crush.size():
		crush[i] = c + (crush[i] - c) * (0.7 + 0.5 * R.next())
	body.append(Art.h("path", { "d": _path(crush), "fill": "#FFFFFF", "fillOpacity": 0.45 if risk else 0.3 }))
	return { "defs": defs, "body": body, "radials": n, "rings": n_rings }


# ════════ LA LUPA ════════
# Un círculo de radio r centrado en (0, 0) con lo que pasa en el contacto: a escala verdadera (vista de arriba, con barra
# de escala) o en corte (con la exageración vertical, si la hay). El banco la coloca donde no estorba y la une con una
# línea al punto que aumenta. El rótulo (text) lo escribe la interfaz debajo.

## La lupa del resultado. target: el material; res: el resultado; o = { r, uid, vcol }. Devuelve { defs, body, kind,
## text, scale (unidades por µm, en vista de arriba o en horizontal), exaggeration, dyn } (dyn: lo que el banco anima
## encima en la huella que sube: ys, a, dLoad, dRes, p, r). Vacío si lupa_kind(res) es "".
static func lupa_art(target: Dictionary, res: Dictionary, o: Dictionary = {}) -> Dictionary:
	var kind := lupa_kind(res)
	if kind == "":
		return lupa_frame("", {}, 0.0, "")
	var r: float = o.get("r", LUPA_R)
	var uid: String = "%s-lupa" % o.get("uid", "lp")
	var part: Dictionary
	match kind:
		"herradura":
			part = _lupa_horseshoes(res.fracture, r)
		"cono":
			part = _lupa_cone(res.fracture, res, target, r, uid)
		"astillado":
			part = _lupa_chips(res.fracture, res, r, uid)
		"radiales":
			part = _lupa_radials(res.fracture, res, r, uid)
		"templado-trozos":
			part = _lupa_fragments(res.glazing, r, uid)
		"templado-grieta":
			part = _lupa_tempered_crack(res.glazing, res, target, r, uid)
		"laminado":
			part = _lupa_laminated(res.glazing, target, r, uid)
		"abolladura":
			part = _lupa_dent(res.dent, target, r, uid)
		"recuperacion":
			part = _lupa_recovery(res, target, r, uid)
	return lupa_frame(kind, part, r, uid)


## La lupa con lo que enseña (part = { defs, body, text, scale, exaggeration, dyn }) recortado en su círculo de radio r y
## con su aro. Devuelve el diccionario de lupa_art (vacío si kind es ""). La usan también las lupas de la biología
## (art_biology.gd).
static func lupa_frame(kind: String, part: Dictionary, r: float, uid: String) -> Dictionary:
	var out := { "defs": [], "body": [], "kind": kind, "text": "", "scale": 0.0, "exaggeration": 1.0, "dyn": {} }
	if kind == "":
		return out
	var clip := "%s-c" % uid
	var defs: Array = [Art.h("clipPath", { "id": clip }, Art.h("path", { "d": _path(_arc(Vector2.ZERO, r, r, 0.0, TAU, 48)) }))]
	defs.append_array(part.get("defs", []))
	out.defs = defs
	out.body = [
		Art.h("circle", { "cx": 0.0, "cy": 0.0, "r": r, "fill": C.bg, "fillOpacity": 0.95 }),
		Art.h("g", { "clipPath": "url(#%s)" % clip }, part.get("body", [])),
		Art.h("circle", { "cx": 0.0, "cy": 0.0, "r": r, "fill": "none", "stroke": C.line2, "strokeWidth": 1.4 }),
	]
	for k: String in ["text", "scale", "exaggeration", "dyn"]:
		if part.has(k):
			out[k] = part[k]
	return out


## Barra de escala de la lupa (abajo): la longitud «redonda» que ocupa cerca de la mitad del diámetro. k: unidades por µm.
## Devuelve [nodos, µm de la barra].
static func _scale_bar(r: float, k: float, y: float) -> Array:
	var um := nice_floor(r * 1.0 / k)
	var w := um * k
	var x0 := -w / 2.0
	var d := "M%s %s L%s %s M%s %s L%s %s M%s %s L%s %s" % [_n(x0), _n(y), _n(x0 + w), _n(y), _n(x0), _n(y - 2.0), _n(x0), _n(y + 2.0),
		_n(x0 + w), _n(y - 2.0), _n(x0 + w), _n(y + 2.0)]
	return [[Art.h("path", { "d": d, "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.85, "strokeWidth": 1.0 })], um]


## Fondo oscuro con el tono del material, para las vistas de arriba de un vidrio.
static func _glass_dark(r: float, tint: String) -> Dictionary:
	return Art.h("rect", { "x": -r, "y": -r, "width": 2.0 * r, "height": 2.0 * r, "fill": Art.darken(tint, 0.62) })


## El aire de un corte (más claro arriba), para que se lean la punta, la chapa y las capas: [degradado, rectángulo].
static func _air(r: float, uid: String) -> Array:
	return [
		Art._lin("%s-air" % uid, [[0.0, "#5E4E7A"], [1.0, "#2E2240"]]),
		Art.h("rect", { "x": -r, "y": -r, "width": 2.0 * r, "height": 2.0 * r, "fill": "url(#%s-air)" % uid }),
	]


## Herraduras de Hertz vistas desde arriba, a escala verdadera: una pista con su contacto y cinco o seis herraduras.
static func _lupa_horseshoes(fr: Dictionary, r: float) -> Dictionary:
	var cone := maxf(float(fr.crackUm), hertz_contact_um(fr) * Fracture.RING_RATIO)
	var k := 0.6 * r / cone
	var a := hertz_contact_um(fr) * k
	var body: Array = [_glass_dark(r, "#79B0A5")]
	# la pista del contacto (pulida) y la dirección del deslizamiento
	body.append(Art.h("rect", { "x": -r, "y": _r2(-a), "width": 2.0 * r, "height": _r2(2.0 * a), "fill": "#FFFFFF", "fillOpacity": 0.07 }))
	var hs := _horseshoes(fr, Vector2(-r, 0.0), 2.0 * r, k, 1.0, 0.0)
	body.append_array(hs.body)
	var ay := -0.62 * r
	body.append(Art.h("path", { "d": "M%s %s L%s %s M%s %s L%s %s L%s %s" % [_n(-0.3 * r), _n(ay), _n(0.3 * r), _n(ay), _n(0.2 * r), _n(ay - 3.0),
		_n(0.3 * r), _n(ay), _n(0.2 * r), _n(ay + 3.0)], "fill": "none", "stroke": C.gold, "strokeWidth": 1.2, "strokeLinecap": "round" }))
	var bar := _scale_bar(r, k, 0.72 * r)
	body.append_array(bar[0])
	return { "body": body, "text": len_text(bar[1]), "scale": k }


## Cono de Hertz en corte: la punta roma apoyada, el anillo en la superficie y el cono que baja a coneAngleDeg (22°) hasta
## su base (crackUm), a escala verdadera.
static func _lupa_cone(fr: Dictionary, res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var ring: float = fr.ringUm
	var cone := maxf(float(fr.crackUm), ring)
	var tana := V8.js_tan(_rad(float(fr.coneAngleDeg)))
	var depth := (cone - ring) * tana
	var k := minf(0.8 * r / cone, 0.45 * r / maxf(depth, 1e-9))
	var ys := -0.2 * r
	var L := look(String(target.get("id", "vidrio")))
	var air := _air(r, uid)
	var body: Array = [air[1], _block(r, ys, L, "%s-b" % uid)]
	var defs: Array = [air[0], Art._lin("%s-b" % uid, [[0.0, L.base, 0.9], [1.0, L.lo, 0.9]])]
	# la punta roma apoyada (su radio, tipRadiusUm)
	var R := float(res.get("tipRadiusUm", cone * 3.0)) * k
	var tip := _arc(Vector2(0.0, ys - R), R, R, 0.0, PI, 40)
	body.append(Art.h("path", { "d": _path(tip), "fill": "#E7E0EE", "fillOpacity": 0.55, "stroke": "#FFFFFF", "strokeOpacity": 0.7, "strokeWidth": 0.8 }))
	var d := PackedStringArray()
	for s: float in [-1.0, 1.0]:
		d.append(_path(PackedVector2Array([Vector2(s * ring * k, ys), Vector2(s * cone * k, ys + depth * k)]), false))
	body.append(Art.h("path", { "d": " ".join(d), "fill": "none", "stroke": "#FFFFFF", "strokeOpacity": 0.95, "strokeWidth": 1.1, "strokeLinecap": "round" }))
	var bar := _scale_bar(r, k, 0.74 * r)
	body.append_array(bar[0])
	return { "defs": defs, "body": body, "text": len_text(bar[1]), "scale": k }


## Bloque del material en un corte: el segmento del círculo por debajo de la superficie ys.
static func _block(r: float, ys: float, _L: Dictionary, grad: String) -> Dictionary:
	return Art.h("rect", { "x": -r, "y": _r2(ys), "width": 2.0 * r, "height": _r2(r - ys), "fill": "url(#%s)" % grad })


## Astillado visto desde arriba, a escala verdadera: el surco con sus grietas laterales y los desconchones.
static func _lupa_chips(fr: Dictionary, res: Dictionary, r: float, uid: String) -> Dictionary:
	var c: float = fr.crackUm
	var k := 0.7 * r / c
	var hw := float(res.get("grooveWidthUm", 0.0)) / 2.0 * k
	var body: Array = [_glass_dark(r, "#79B0A5")]
	body.append(Art.h("rect", { "x": -r, "y": _r2(-maxf(hw, 0.6)), "width": 2.0 * r, "height": _r2(2.0 * maxf(hw, 0.6)), "fill": "#FFFFFF",
		"fillOpacity": 0.55 }))
	var ch := _chips(fr, res, Vector2(-r, 0.0), 2.0 * r, k, 1.0, uid, 0.6)
	body.append_array(ch.body)
	var bar := _scale_bar(r, k, 0.78 * r)
	body.append_array(bar[0])
	return { "body": body, "text": len_text(bar[1]), "scale": k }


## Grietas radiales vistas desde arriba, a escala verdadera: el pozo de la punta y la estrella de seis radiales.
static func _lupa_radials(fr: Dictionary, res: Dictionary, r: float, uid: String) -> Dictionary:
	var c: float = fr.crackUm
	var k := 0.78 * r / c
	var a := float(res.get("grooveWidthUm", 0.0)) / 2.0 * k
	var body: Array = [_glass_dark(r, "#79B0A5")]
	body.append(Art.h("circle", { "cx": 0.0, "cy": 0.0, "r": _r2(maxf(a, 0.8)), "fill": HOLE, "stroke": "#FFFFFF", "strokeOpacity": 0.6,
		"strokeWidth": 0.6 }))
	var st := _radial_star(fr, res, Vector2.ZERO, k, 1.0, uid)
	body.append_array(st.body)
	var bar := _scale_bar(r, k, 0.8 * r)
	body.append_array(bar[0])
	return { "body": body, "text": len_text(bar[1]), "scale": k }


## El ensayo de la homologación (CEPE R43): los trozos que caben en un cuadrado de 5 × 5 cm, con el tamaño del resultado.
static func _lupa_fragments(gl: Dictionary, r: float, uid: String) -> Dictionary:
	var side := 2.0 * r * 0.7071 * 0.92
	var k := side / 50.0  # unidades por mm
	var half := side / 2.0
	var sq := Rect2(-half, -half, side, side)
	var cells := honeycomb(float(gl.fragmentMm) * k, Vector2.ZERO, sq, "r43:%s" % _n(float(gl.fragmentMm)))
	var d := PackedStringArray()
	for cell: Dictionary in cells:
		d.append(_path(cell.poly))
	var defs: Array = [Art.h("clipPath", { "id": "%s-sq" % uid }, Art.h("rect", { "x": _r2(-half), "y": _r2(-half), "width": _r2(side), "height": _r2(side) }))]
	var body: Array = [
		_glass_dark(r, "#79B0A5"),
		Art.h("g", { "clipPath": "url(#%s-sq)" % uid },
			Art.h("path", { "d": " ".join(d), "fill": "#FFFFFF", "fillOpacity": 0.08, "stroke": "#FFFFFF", "strokeOpacity": 0.75, "strokeWidth": 0.4 })),
		Art.h("rect", { "x": _r2(-half), "y": _r2(-half), "width": _r2(side), "height": _r2(side), "fill": "none", "stroke": C.gold,
			"strokeWidth": 1.0, "strokeDasharray": "3 2" }),
	]
	return { "defs": defs, "body": body, "text": "5 × 5 cm: ~%s trozos" % Js.js_num_str(Js.js_round(float(gl.fragments25))), "scale": k / 1000.0 }


## La ventanilla templada en corte: las dos caras comprimidas (compressionMm) y el centro en tracción, con el perfil de
## tensiones σ(ζ) = ½·σS·(1 − 3ζ²) al lado (Nielsen et al. 2022), y la grieta de la punta (crackUm) que atraviesa la capa
## comprimida y llega a la tracción, donde se ramifica: el truco del martillo de emergencia. A escala verdadera.
static func _lupa_tempered_crack(gl: Dictionary, res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var pane: Dictionary = target.get("pane", Glazing.SIDE_WINDOW.pane)
	var t: float = pane.t
	var dc: float = gl.compressionMm
	var k := 1.2 * r / t  # unidades por mm
	var y0 := -t * k / 2.0
	var y1 := t * k / 2.0
	var fr: Variant = _f(res, "fracture")
	var crack := float(fr.crackUm) / 1000.0 if fr != null and float(fr.crackUm) > 0.0 else dc * 1.4
	var air := _air(r, uid)
	var body: Array = [air[1]]
	var defs: Array = [air[0]]
	var L: Dictionary = LOOKS.ventanilla
	body.append(Art.h("rect", { "x": -r, "y": _r2(y0), "width": 2.0 * r, "height": _r2(y1 - y0), "fill": L.base, "fillOpacity": 0.85 }))
	# capas comprimidas (azul) y el centro en tracción (rojizo)
	body.append(Art.h("rect", { "x": -r, "y": _r2(y0), "width": 2.0 * r, "height": _r2(dc * k), "fill": C.ice, "fillOpacity": 0.55 }))
	body.append(Art.h("rect", { "x": -r, "y": _r2(y1 - dc * k), "width": 2.0 * r, "height": _r2(dc * k), "fill": C.ice, "fillOpacity": 0.55 }))
	body.append(Art.h("rect", { "x": -r, "y": _r2(y0 + dc * k), "width": 2.0 * r, "height": _r2(y1 - y0 - 2.0 * dc * k), "fill": C.coral, "fillOpacity": 0.2 }))
	# perfil de tensiones a la derecha: compresión hacia la izquierda, tracción hacia la derecha
	var x0 := 0.45 * r
	var amp := 0.28 * r
	var prof := PackedVector2Array()
	for i in 21:
		var zeta := -1.0 + 2.0 * i / 20.0
		var sigma := 0.5 * (1.0 - 3.0 * zeta * zeta)  # en unidades de σS: +½ en el centro, −1 en las caras
		prof.append(Vector2(x0 + amp * sigma, y0 + (zeta + 1.0) / 2.0 * (y1 - y0)))
	body.append(Art.h("path", { "d": "M%s %s L%s %s" % [_n(x0), _n(y0), _n(x0), _n(y1)], "stroke": "#000000", "strokeOpacity": 0.45, "strokeWidth": 0.6,
		"strokeDasharray": "2 1.5" }))
	body.append(Art.h("path", { "d": _path(prof, false), "fill": "none", "stroke": C.bg, "strokeWidth": 1.1 }))
	# la grieta de la punta: baja crackUm (sin pasar del espesor) y se ramifica en la tracción
	var cx := -0.25 * r
	var cd := minf(crack, t * 0.95) * k
	var R := Rng.new(Rng.seed_of("martillo:%s" % _n(crack)))
	var pts := PackedVector2Array()
	for j in 7:
		var jig := (R.next() - 0.5) * 2.0 if (j > 0 and j < 6) else 0.0
		pts.append(Vector2(cx + jig, y0 + cd * j / 6.0))
	var d := PackedStringArray([_path(pts, false)])
	if crack > dc:
		var tipp: Vector2 = pts[-1]
		for s: float in [-1.0, 1.0]:
			d.append(_path(PackedVector2Array([tipp, tipp + Vector2(s * 0.3 * r, 0.12 * r), tipp + Vector2(s * 0.55 * r, 0.05 * r)]), false))
	body.append(Art.h("path", { "d": " ".join(d), "fill": "none", "stroke": C.bg, "strokeWidth": 1.1, "strokeLinecap": "round" }))
	# la punta dura que aprieta (un cono con el semiángulo del resultado)
	var ta := V8.js_tan(_rad(float(res.get("alphaDeg", 20.0))))
	var hgt := 0.3 * r
	body.append(Art.h("path", { "d": _path(PackedVector2Array([Vector2(cx, y0), Vector2(cx - hgt * ta, y0 - hgt), Vector2(cx + hgt * ta, y0 - hgt)])),
		"fill": C.gold, "fillOpacity": 0.9, "stroke": "#000000", "strokeOpacity": 0.4, "strokeWidth": 0.5 }))
	return { "defs": defs, "body": body, "text": "capa comprimida %s mm" % mm_text(dc), "scale": k / 1000.0 }


## El parabrisas laminado en corte: las dos hojas de vidrio y la lámina de PVB (Glazing.WINDSCREEN o target.laminated), con
## la hoja de fuera agrietada bajo el impacto y la de dentro desde su cara de abajo (la que trabaja a tracción al flexar);
## la lámina, entera, sujeta los trozos. Con penetrationRisk, todo abombado hacia dentro y la lámina estirada.
static func _lupa_laminated(gl: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var lam: Dictionary = target.get("laminated", Glazing.WINDSCREEN.laminated)
	var p1 := float(lam.plies[0])
	var p2 := float(lam.plies[1])
	var pvb := float(lam.pvbMm)
	var total := p1 + pvb + p2
	var k := 1.05 * r / total
	var risk: bool = gl.penetrationRisk == true
	var sag := 0.22 * r if risk else 0.0
	var top := -total * k / 2.0
	var L: Dictionary = LOOKS.parabrisas
	var bounds := [top, top + p1 * k, top + (p1 + pvb) * k, top + total * k]
	# lo que baja cada frontera en x (abombado suave hacia dentro); la lámina se estira: su cara de abajo baja un poco más
	var layer := func(y_top: float, y_bot: float, extra_bot: float) -> String:
		var up := PackedVector2Array()
		var dn := PackedVector2Array()
		for i in 25:
			var x := -r + 2.0 * r * i / 24.0
			var w := 0.0
			if absf(x) < 0.9 * r:
				var cc := V8.js_cos(PI * x / (1.8 * r))
				w = cc * cc
			up.append(Vector2(x, y_top + sag * w))
			dn.append(Vector2(x, y_bot + (sag + extra_bot) * w))
		dn.reverse()
		up.append_array(dn)
		return _path(up)
	var air := _air(r, uid)
	var body: Array = [
		air[1],
		Art.h("path", { "d": layer.call(bounds[0], bounds[1], 0.0), "fill": L.base, "fillOpacity": 0.85, "stroke": "#FFFFFF", "strokeOpacity": 0.3, "strokeWidth": 0.5 }),
		Art.h("path", { "d": layer.call(bounds[1], bounds[2], 0.12 * sag), "fill": L.pvb, "fillOpacity": 0.95 }),
		Art.h("path", { "d": layer.call(bounds[2] + 0.12 * sag, bounds[3], 0.0), "fill": L.lo, "fillOpacity": 0.85, "stroke": "#FFFFFF", "strokeOpacity": 0.3,
			"strokeWidth": 0.5 }),
	]
	# grietas: un cono bajo el impacto y dos radiales en la hoja de fuera; tres desde abajo en la de dentro
	var d := PackedStringArray()
	var y_of := func(x: float, y: float) -> float:
		var w := 0.0
		if absf(x) < 0.9 * r:
			var cc := V8.js_cos(PI * x / (1.8 * r))
			w = cc * cc
		return y + sag * w
	for s: float in [-1.0, 1.0]:
		d.append(_path(PackedVector2Array([Vector2(s * 1.5, y_of.call(s * 1.5, bounds[0])), Vector2(s * 0.3 * r, y_of.call(s * 0.3 * r, bounds[1]))]), false))
		d.append(_path(PackedVector2Array([Vector2(s * 0.62 * r, y_of.call(s * 0.62 * r, bounds[0])), Vector2(s * 0.6 * r, y_of.call(s * 0.6 * r, bounds[1]))]), false))
	for x: float in [-0.22 * r, 0.04 * r, 0.3 * r]:
		var yb: float = y_of.call(x, bounds[3])
		var ytop: float = y_of.call(x, bounds[2]) + 0.12 * sag
		d.append(_path(PackedVector2Array([Vector2(x, yb), Vector2(x + 1.2, (yb + ytop) / 2.0), Vector2(x - 0.6, ytop)]), false))
	body.append(Art.h("path", { "d": " ".join(d), "fill": "none", "stroke": C.bg, "strokeWidth": 0.9, "strokeLinecap": "round" }))
	var txt := "%s + %s PVB + %s mm" % [mm_text(p1), mm_text(pvb), mm_text(p2)]
	return { "defs": [air[0]], "body": body, "text": txt, "scale": k / 1000.0 }


## La abolladura en corte: la chapa (su espesor, Dent.panel_of) hundida depthMm, con DENT_SPAN veces la profundidad de
## ancho; en vertical, exagerada lo que diga su rótulo (la forma es muy plana: 1 a 15 de pendiente media).
static func _lupa_dent(dent: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var panel: Variant = Dent.panel_of(target)
	var t: float = panel.t if panel != null else 1.0
	var depth: float = dent.depthMm
	var span := DENT_SPAN * depth
	var kh := 1.6 * r / span  # unidades por mm en horizontal
	var e := maxf(1.0, nice_floor(0.3 * r / (depth * kh)))
	var kv := kh * e
	var y0 := -0.15 * r
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 41:
		var x := -r + 2.0 * r * i / 40.0
		var w := 0.0
		var hs := span * kh / 2.0
		if absf(x) < hs:
			w = (1.0 + V8.js_cos(PI * x / hs)) / 2.0
		top.append(Vector2(x, y0 + depth * kv * w))
		bot.append(Vector2(x, y0 + depth * kv * w + t * kv))
	var band := PackedVector2Array(top)
	var rev := PackedVector2Array(bot)
	rev.reverse()
	band.append_array(rev)
	var metal: String = "#C3CAD2"
	var body_d: Variant = target.get("body")
	if body_d is Dictionary:
		metal = String(body_d.col)
	# detrás de la chapa, el hueco oscuro de la puerta (como en el corte del coche de la 1.x)
	var inside := PackedVector2Array(bot)
	inside.append(Vector2(r, r))
	inside.append(Vector2(-r, r))
	var air := _air(r, uid)
	var body: Array = [
		air[1],
		Art.h("path", { "d": _path(inside), "fill": "#0B0E12" }),
		Art.h("path", { "d": "M%s %s L%s %s" % [_n(-r), _n(y0), _n(r), _n(y0)], "stroke": "#FFFFFF", "strokeOpacity": 0.5, "strokeWidth": 0.8,
			"strokeDasharray": "3 2" }),
		Art.h("path", { "d": _path(band), "fill": metal, "fillOpacity": 0.95, "stroke": "#000000", "strokeOpacity": 0.35, "strokeWidth": 0.5 }),
	]
	if target.get("paint") == true:
		body.append(Art.h("path", { "d": _path(top, false), "fill": "none", "stroke": String(Looks.MATERIAL_LOOK.get(target.id, Looks.MATERIAL_LOOK.coche).base),
			"strokeWidth": 1.6 }))
	# la profundidad, acotada en el centro
	var yb := y0 + depth * kv
	body.append(Art.h("path", { "d": "M0 %s L0 %s M-2.5 %s L2.5 %s M-2.5 %s L2.5 %s" % [_n(y0), _n(yb), _n(y0), _n(y0), _n(yb), _n(yb)],
		"stroke": C.gold, "strokeWidth": 1.0 }))
	var txt := "hundida %s mm" % mm_text(depth)
	if e > 1.0:
		txt += " · vertical ×%s" % Js.js_num_str(e)
	return { "defs": [air[0]], "body": body, "text": txt, "scale": kh / 1000.0, "exaggeration": e }


## La huella que queda al levantar la punta, en corte: el material (la capa del fondo de la huella) y, dibujado por el
## banco encima (dyn), el fondo que sube de la profundidad bajo carga (depthUm) a la que queda (residualDepthUm) cuando la
## punta se va, con la anchura del contacto (grooveWidthUm) y la forma de la punta (esfera o cono). La línea de puntos
## marca dónde estaba el fondo bajo carga. En vertical, exagerada lo que diga el rótulo.
static func _lupa_recovery(res: Dictionary, target: Dictionary, r: float, uid: String) -> Dictionary:
	var a_um := float(res.grooveWidthUm) / 2.0
	var d_um: float = res.depthUm
	var dr_um: float = res.residualDepthUm
	var k := 0.6 * r / a_um
	var e_raw := 0.3 * r / (d_um * k)
	var e := 1.0
	if e_raw >= 1.0:
		e = nice_floor(e_raw)
	else:
		k = minf(k, 0.42 * r / d_um)
	var ys := -0.08 * r
	var L := _layer_look(target, d_um)
	var air := _air(r, uid)
	var defs: Array = [air[0], Art._lin("%s-b" % uid, [[0.0, Art.lighten(L.base, 0.1), 0.95], [1.0, L.lo, 0.95]])]
	var body: Array = [air[1], _block(r, ys, L, "%s-b" % uid)]
	var dl := d_um * k * e
	var a := a_um * k
	body.append(Art.h("path", { "d": "M%s %s L%s %s" % [_n(-a), _n(ys + dl), _n(a), _n(ys + dl)], "stroke": "#FFFFFF", "strokeOpacity": 0.75,
		"strokeWidth": 0.7, "strokeDasharray": "2 1.5" }))
	# forma de la huella: casquete esférico si el contacto no pasa de la esfera de la punta; si pasa, flancos de cono
	var tip_r := float(res.get("tipRadiusUm", a_um * 4.0))
	var alpha := _rad(float(res.get("alphaDeg", 30.0)))
	var p := 2.0 if a_um <= tip_r * V8.js_cos(alpha) else 1.3
	var txt := ("profundidad ×%s" % Js.js_num_str(e)) if e > 1.0 else "a escala"
	# el color del aire a la altura del surco (el banco rellena con él lo que la punta ha hundido)
	var air_col := Art.mix("#5E4E7A", "#2E2240", clampf((ys + 0.5 * dl + r) / (2.0 * r), 0.0, 1.0))
	return {
		"defs": defs, "body": body, "text": txt, "scale": k, "exaggeration": e,
		"dyn": { "ys": ys, "a": a, "dLoad": dl, "dRes": dr_um * k * e, "p": p, "r": r, "air": air_col },
	}


## Aspecto de la capa del fondo de una huella de depth_um: en un coche, la de la pintura (o la carrocería) a esa profundidad.
static func _layer_look(target: Dictionary, depth_um: float) -> Dictionary:
	if target.get("paint") == true:
		for l: Dictionary in Looks.PAINT_LAYERS:
			if depth_um <= float(l.to):
				return Looks.MATERIAL_LOOK[Looks.PAINT_LAYER_LOOK[l.id]]
		var body: Variant = target.get("body")
		if body is Dictionary and Looks.BODY_LOOK.has(body.id):
			return Looks.MATERIAL_LOOK[Looks.BODY_LOOK[body.id]]
	return look(String(target.get("id", "plastico")))


## Perfil de la huella a profundidad d (unidades de la lupa) en x: d·(1 − |x/a|^p) dentro del contacto (≥ 0) y, fuera,
## lo que sube la punta (< 0). La forma de la punta de _lupa_recovery (p = 2: esfera; 1,3: cono).
static func groove_profile(x: float, a: float, d: float, p: float) -> float:
	if a <= 0.0:
		return 0.0
	return d * (1.0 - V8.js_pow(absf(x) / a, p))


# ════════ LA UÑA QUE SE DOBLA ════════

## Geometría de la uña de perfil de Art.nail_side_art (las mismas fórmulas): de las coordenadas de la uña (u a lo largo
## hacia la punta, v hacia el dorso) al dibujo, con la punta en (0, 0). Devuelve { free (uña libre), pivot (la raíz del
## borde libre, a media placa), edge_clip y finger_clip (los dos recortes, que comparten la línea que sigue la cara de
## abajo de la placa: el pulpejo se queda en el dedo), edge_outline (el contorno del borde libre), pad (un punto del
## pulpejo bajo el borde libre) }.
static func nail_geometry(geom: Variant) -> Dictionary:
	var th := (35.0 * PI) / 180.0
	var c := V8.js_cos(th)
	var sn := V8.js_sin(th)
	var free: float = 16.0 + float(geom.reach) * 2.4 if geom != null else 28.0
	var curl: float = float(geom.curl) if geom != null else 0.5
	var v_bot := func(u: float) -> float:
		if u < -free:
			return 0.3
		var q := (u + free) / free
		return 0.3 - (2.0 + 9.0 * curl) * (q * q)
	var thick := func(u: float) -> float:
		return 3.3 if u < -free else 3.3 - 2.1 * ((u + free) / free)
	var tip_v: float = float(v_bot.call(0.0)) + float(thick.call(0.0)) * 0.5
	var P := func(u: float, v: float) -> Vector2:
		return Vector2(u * c + (v - tip_v) * sn, u * sn - (v - tip_v) * c)
	var margin := 0.35
	var line := PackedVector2Array()
	for i in 13:
		var u := -free + free * i / 12.0
		line.append(P.call(u, float(v_bot.call(u)) - margin))
	line.append(P.call(6.0, float(v_bot.call(0.0)) - margin))
	var edge := PackedVector2Array([P.call(-free, 40.0)])
	edge.append_array(line)
	edge.append(P.call(6.0, 40.0))
	var finger := PackedVector2Array([P.call(-420.0, 40.0), P.call(-free, 40.0)])
	finger.append_array(line)
	finger.append(P.call(6.0, -60.0))
	finger.append(P.call(-420.0, -60.0))
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 9:
		var u := -free + free * i / 8.0
		top.append(P.call(u, float(v_bot.call(u)) + float(thick.call(u))))
		bot.append(P.call(u, float(v_bot.call(u))))
	bot.reverse()
	top.append_array(bot)
	return {
		"free": free, "pivot": P.call(-free, 0.3 + 3.3 / 2.0), "edge_clip": edge, "finger_clip": finger, "edge_outline": top,
		"pad": P.call(-free + 4.0, -8.0),
	}


## La uña de perfil del banco (Art.nail_side_art) partida por la raíz del borde libre: part "finger" (el dedo y la uña
## hasta la raíz) o "edge" (el borde libre, que el banco dobla o deja caer). o: el de Art.nail_side_art. Devuelve su grafo
## dentro del recorte, con tip, pivot y edge_outline (en las coordenadas del dibujo).
static func nail_part_art(o: Dictionary, part: String) -> Dictionary:
	var art := Art.nail_side_art(o)
	var g := nail_geometry(o.get("geom"))
	var id := "%s-%s-cut" % [o.get("uid", "nside"), part]
	var clip: PackedVector2Array = g.edge_clip if part == "edge" else g.finger_clip
	var defs: Array = (art.defs as Array).duplicate()
	defs.append(Art.h("clipPath", { "id": id }, Art.h("path", { "d": _path(clip) })))
	var pv: Vector2 = g.pivot
	return {
		"defs": defs, "body": [Art.h("g", { "clipPath": "url(#%s)" % id }, art.body)], "tip": art.tip,
		"pivot": { "x": pv.x, "y": pv.y }, "edge_outline": g.edge_outline,
	}
