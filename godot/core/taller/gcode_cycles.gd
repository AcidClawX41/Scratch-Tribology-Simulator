## Taller · ciclos fijos de torneado del Fagor 8055 T expandidos a movimientos (IR de CONTRATOS.md).
##
## - G81 (torneado de tramos rectos) y G82 (refrentado de tramos rectos): el perfil es el segmento que va del punto
##   inicial (X, Z) al final (Q, R). Todas las pasadas son iguales, con un paso igual o menor que C (manual del
##   8055 T, p. 168 y 172).
## - G68 (desbaste en X) y G69 (desbaste en Z): el perfil está entre los bloques de las etiquetas S y E. Todas las
##   pasadas son de paso C menos la última, que quita el material sobrante (p. 154 y 161).
## - G86 (roscado longitudinal, p. 187-192): expand_thread(), al final del archivo.
## Cada pasada: 1-2 en rápido; 2-3 en G01 al avance de mecanizado; 3-4 retirada (D ≠ 0: a 45° en rápido hasta la
## distancia de seguridad; D = 0: sale por donde entró; sin D: sigue el perfil en G01 hasta la pasada anterior); y
## 4-5 en rápido (p. 158 y 170). Luego vienen la pasada final de desbaste, paralela al perfil y con las demasías
## (avance F), y la de acabado sobre el perfil (avance H). El ciclo acaba en el punto de llamada.
##
## Todo se calcula en un «marco del ciclo» (a, b): las pasadas avanzan a lo largo de a y el paso se da en b. En G68 y
## G81, a = Z y b = radio; en G69 y G82 se intercambian, y los arcos cambian de sentido porque el intercambio de ejes
## es una simetría. En ese marco el perfil sube (b crece) mientras va hacia el plato (a decrece), el material está
## por encima y a la derecha, y el punto de llamada queda arriba a la derecha. Así un solo motor sirve para los
## cuatro ciclos.
## MVP: mecanizado exterior de perfiles monótonos (sin canales ni rebajes). Lo demás es de la fase 2.
## Unidades: mm, con X en radio. Sin nodos, sin azar: el mismo programa da siempre la misma trayectoria.
extends RefCounted

const Js = preload("res://core/shared/js.gd")

const EPS := 1e-6  # tolerancia geométrica (mm)
const PHASE2 := "no soportado en este simulador (fase 2)"
const MAX_PASSES := 400  # más pasadas indica un paso C absurdo para la pieza
const SAMPLES := 16  # muestras por elemento al comprobar la monotonía


## Expande un ciclo. kind: "G68" | "G69" | "G81" | "G82".
## p (en mm y radio): x_r y z (punto inicial del perfil), q_r y r_z (punto final en G81 y G82), c (paso), d y has_d
## (distancia de seguridad), l y m (demasías en X y en Z), has_m, f (avance de la pasada final de desbaste; 0 si
## no hay), h (avance de acabado; 0 si no hay) y feed_mode ("mmrev" | "mmmin", el de G94/G95 para F y H).
## profile (G68 y G69): elementos en el plano del dibujo, { kind: "line"|"arc", z0, r0, z1, r1, cz, cr, rad, cw,
## n, line }, con cw = G02. feed: { mode, value }, el avance de mecanizado activo al llamar al ciclo.
## Devuelve { moves (IR sin n ni line), errors: [{ code, text, n?, line? }], warnings, passes, levels }.
static func expand(kind: String, p: Dictionary, call_r: float, call_z: float, profile: Array,
		feed: Dictionary) -> Dictionary:
	var res := { "moves": [], "errors": [], "warnings": [], "passes": 0, "levels": [] }
	var sw := kind == "G69" or kind == "G82"
	var ac := call_r if sw else call_z
	var bc := call_z if sw else call_r
	var l := absf(float(p.get("l", 0.0)))
	var m := absf(float(p.get("m", 0.0)))
	var la := l if sw else m  # demasía a lo largo de las pasadas
	var lb := m if sw else l  # demasía a lo largo del paso
	var prof: Array = []
	if kind == "G81" or kind == "G82":
		var seg := { "kind": "line", "z0": p["z"], "r0": p["x_r"], "z1": p["r_z"], "r1": p["q_r"], "n": -1, "line": 0 }
		if _dist(p["z"], p["x_r"], p["r_z"], p["q_r"]) < EPS:
			var same := "%s: el punto inicial (X, Z) y el final (Q, R) coinciden: no hay tramo que mecanizar." % kind
			res["errors"].append({ "code": "cycle_profile", "text": same })
			return res
		prof.append(_to_frame(seg, sw))
	else:
		for e in profile:
			prof.append(_to_frame(e, sw))
	if prof.is_empty():
		res["errors"].append({ "code": "cycle_profile", "text": "%s: el perfil está vacío." % kind })
		return res
	for e in prof:
		if not _monotone(e):
			res["errors"].append(_profile_error(kind, e))
			return res
	var off: Array
	if (kind == "G68" or kind == "G69") and not bool(p.get("has_m", false)):
		# sin M, la demasía L es constante en todo el perfil (p. 155): desplazamiento equidistante
		var eq := _offset_equidistant(prof, l)
		if eq.has("error"):
			res["errors"].append({ "code": "cycle_stock", "text": "%s: %s" % [kind, eq["error"]] })
			return res
		off = eq["chain"]
	else:
		off = _translate(prof, la, lb)  # demasías por ejes: L en X y M en Z
	var a_s: float = off[0]["a0"]
	var b_s: float = off[0]["b0"]
	var b_top: float = off[off.size() - 1]["b1"]
	if ac < a_s - EPS or bc < b_top - EPS:
		res["errors"].append({ "code": "cycle_position", "text": _position_text(kind, sw, a_s, b_top) })
		return res
	var c: float = p["c"]
	var depth := bc - b_s
	var levels: Array = []
	if depth > EPS:
		var n := ceili(depth / c - 1e-9)
		if n > MAX_PASSES:
			var many := "%s: saldrían %d pasadas con C = %s mm; revisa el paso (máximo %d)." \
					% [kind, n, _num(c), MAX_PASSES]
			res["errors"].append({ "code": "too_many_passes", "text": many })
			return res
		var step := depth / float(n) if (kind == "G81" or kind == "G82") else c
		for k in range(1, n):
			levels.append(bc - float(k) * step)
		levels.append(b_s)
	res["passes"] = levels.size()
	res["levels"] = levels
	var out := { "moves": res["moves"], "a": ac, "b": bc, "sw": sw }
	var prev_b := bc
	for b in levels:
		_rapid(out, ac, b)  # 1-2
		var ax := _a_cross(off, b)
		_feed(out, ax, b, feed)  # 2-3
		if not bool(p.get("has_d", false)):
			_follow(out, _chain_between(off, b, prev_b), feed)  # 3-4 siguiendo el perfil hasta la pasada anterior
		elif float(p["d"]) > EPS:
			_rapid(out, ax + float(p["d"]), b + float(p["d"]))  # 3-4 a 45° hasta la distancia de seguridad
		_rapid(out, ac, out["b"])  # 4-5 (con D = 0, por el mismo camino de entrada)
		prev_b = b
	_rapid(out, ac, bc)
	var f := float(p.get("f", 0.0))
	var h := float(p.get("h", 0.0))
	# F y H van en las unidades de G94/G95 activas, aunque el desbaste vaya a F0 (en mm/min)
	var mode: String = p.get("feed_mode", feed["mode"])
	if f > EPS:
		_profile_pass(out, off, ac, bc, { "mode": mode, "value": f })  # pasada final de desbaste
	if h > EPS:
		_profile_pass(out, prof, ac, bc, { "mode": mode, "value": h })  # pasada de acabado
	return res


# ---------------------------------------------------------------------------------------------------------------
# Marco del ciclo
# ---------------------------------------------------------------------------------------------------------------

## Elemento del dibujo (z, r) → marco del ciclo (a, b). G02 es horario con Z a la derecha y el radio hacia arriba.
static func _to_frame(e: Dictionary, sw: bool) -> Dictionary:
	var o := { "kind": e["kind"], "n": e.get("n", -1), "line": e.get("line", 0) }
	o["a0"] = e["r0"] if sw else e["z0"]
	o["b0"] = e["z0"] if sw else e["r0"]
	o["a1"] = e["r1"] if sw else e["z1"]
	o["b1"] = e["z1"] if sw else e["r1"]
	if e["kind"] == "arc":
		o["ca"] = e["cr"] if sw else e["cz"]
		o["cb"] = e["cz"] if sw else e["cr"]
		o["rad"] = e["rad"]
		o["ccw"] = bool(e["cw"]) if sw else not bool(e["cw"])
	return o


## Punto del marco del ciclo → punto del IR { r, z }.
static func _pt(out: Dictionary, a: float, b: float) -> Dictionary:
	return { "r": a, "z": b } if out["sw"] else { "r": b, "z": a }


static func _rapid(out: Dictionary, a: float, b: float) -> void:
	if absf(a - out["a"]) < EPS and absf(b - out["b"]) < EPS:
		return
	out["moves"].append({ "type": "rapid", "from": _pt(out, out["a"], out["b"]), "to": _pt(out, a, b) })
	out["a"] = a
	out["b"] = b


static func _feed(out: Dictionary, a: float, b: float, feed: Dictionary) -> void:
	if absf(a - out["a"]) < EPS and absf(b - out["b"]) < EPS:
		return
	out["moves"].append({ "type": "feed", "from": _pt(out, out["a"], out["b"]), "to": _pt(out, a, b),
		"feed": feed.duplicate() })
	out["a"] = a
	out["b"] = b


static func _arc(out: Dictionary, e: Dictionary, feed: Dictionary) -> void:
	if absf(e["a1"] - out["a"]) < EPS and absf(e["b1"] - out["b"]) < EPS:
		return
	var cw := bool(e["ccw"]) if out["sw"] else not bool(e["ccw"])
	out["moves"].append({ "type": "arc", "from": _pt(out, out["a"], out["b"]), "to": _pt(out, e["a1"], e["b1"]),
		"arc": { "cw": cw, "center": _pt(out, e["ca"], e["cb"]) }, "feed": feed.duplicate() })
	out["a"] = e["a1"]
	out["b"] = e["b1"]


## Recorre una cadena desde el punto actual (que es el inicio de su primer elemento).
static func _follow(out: Dictionary, chain: Array, feed: Dictionary) -> void:
	for e in chain:
		if e["kind"] == "line":
			_feed(out, e["a1"], e["b1"], feed)
		else:
			_arc(out, e, feed)


## Pasada paralela a una cadena (final de desbaste o acabado): baja en rápido fuera de la pieza hasta la altura del
## inicio, entra al avance de la pasada, recorre la cadena, sale por la pared del final hasta la altura de llamada
## y vuelve en rápido al punto de llamada.
static func _profile_pass(out: Dictionary, chain: Array, ac: float, bc: float, feed: Dictionary) -> void:
	var s: Dictionary = chain[0]
	var e: Dictionary = chain[chain.size() - 1]
	_rapid(out, ac, s["b0"])
	_feed(out, s["a0"], s["b0"], feed)
	_follow(out, chain, feed)
	_feed(out, e["a1"], bc, feed)
	_rapid(out, ac, bc)


# ---------------------------------------------------------------------------------------------------------------
# Geometría de la cadena (monótona: a no crece y b no decrece a lo largo del recorrido)
# ---------------------------------------------------------------------------------------------------------------

## a del borde de la cadena a la altura b: el final del tramo de cadena que no sube por encima de b. Por encima del
## final, la pared vertical del último punto; por debajo del inicio, el inicio.
static func _a_cross(chain: Array, b: float) -> float:
	var a: float = chain[0]["a0"]
	for e in chain:
		if e["b1"] <= b + EPS:
			a = e["a1"]
			continue
		if e["b0"] >= b - EPS:
			return a
		return _a_at(e, b)
	return a


## a de un elemento a la altura b (b entre sus extremos). Un arco monótono antihorario está en el primer cuadrante de
## su centro y uno horario en el tercero.
static func _a_at(e: Dictionary, b: float) -> float:
	if e["kind"] == "line":
		var db: float = e["b1"] - e["b0"]
		if absf(db) < EPS:
			return e["a1"]
		return e["a0"] + (b - e["b0"]) / db * (e["a1"] - e["a0"])
	var d: float = b - e["cb"]
	var h := sqrt(maxf(e["rad"] * e["rad"] - d * d, 0.0))
	return e["ca"] + h if e["ccw"] else e["ca"] - h


## Tramo de cadena entre las alturas b_lo y b_hi (la retirada sin D: sigue el perfil hasta la pasada anterior). Si la
## cadena acaba antes, sube por la pared vertical de su final.
static func _chain_between(chain: Array, b_lo: float, b_hi: float) -> Array:
	var out: Array = []
	var last_a := _a_cross(chain, b_lo)
	var last_b := b_lo
	for e in chain:
		if e["b1"] <= b_lo + EPS:
			continue
		if e["b0"] >= b_hi - EPS and e["b1"] > b_hi + EPS:
			break
		var sub := _sub(e, maxf(e["b0"], b_lo), minf(e["b1"], b_hi))
		if _length(sub) > EPS:
			out.append(sub)
			last_a = sub["a1"]
			last_b = sub["b1"]
		if e["b1"] > b_hi + EPS:
			return out
	if b_hi > last_b + EPS:
		out.append({ "kind": "line", "a0": last_a, "b0": last_b, "a1": last_a, "b1": b_hi })
	return out


## Parte de un elemento entre las alturas b_from y b_to. Los tramos horizontales se toman enteros.
static func _sub(e: Dictionary, b_from: float, b_to: float) -> Dictionary:
	var o := e.duplicate()
	if absf(e["b1"] - e["b0"]) < EPS:
		return o
	if b_from > e["b0"] + EPS:
		o["a0"] = _a_at(e, b_from)
		o["b0"] = b_from
	if b_to < e["b1"] - EPS:
		o["a1"] = _a_at(e, b_to)
		o["b1"] = b_to
	return o


static func _translate(chain: Array, da: float, db: float) -> Array:
	var out: Array = []
	for e in chain:
		var o: Dictionary = e.duplicate()
		o["a0"] += da
		o["a1"] += da
		o["b0"] += db
		o["b1"] += db
		if o["kind"] == "arc":
			o["ca"] += da
			o["cb"] += db
		out.append(o)
	return out


## Punto de un elemento en la fracción t de su recorrido (0 = inicio, 1 = final).
static func _point_at(e: Dictionary, t: float) -> PackedFloat64Array:
	if t >= 1.0:
		return PackedFloat64Array([e["a1"], e["b1"]])
	if e["kind"] == "line":
		return PackedFloat64Array([e["a0"] + t * (e["a1"] - e["a0"]), e["b0"] + t * (e["b1"] - e["b0"])])
	var th := _theta0(e) + t * _sweep(e)
	return PackedFloat64Array([e["ca"] + e["rad"] * cos(th), e["cb"] + e["rad"] * sin(th)])


static func _theta0(e: Dictionary) -> float:
	return atan2(e["b0"] - e["cb"], e["a0"] - e["ca"])


## Ángulo recorrido por un arco, con signo (positivo en sentido antihorario).
static func _sweep(e: Dictionary) -> float:
	var s := atan2(e["b1"] - e["cb"], e["a1"] - e["ca"]) - _theta0(e)
	if e["ccw"]:
		while s <= 0.0:
			s += TAU
	else:
		while s >= 0.0:
			s -= TAU
	return s


static func _length(e: Dictionary) -> float:
	if e["kind"] == "line":
		return _dist(e["a0"], e["b0"], e["a1"], e["b1"])
	if _dist(e["a0"], e["b0"], e["a1"], e["b1"]) < EPS:
		return 0.0
	return absf(_sweep(e)) * e["rad"]


static func _dist(a0: float, b0: float, a1: float, b1: float) -> float:
	return sqrt((a1 - a0) * (a1 - a0) + (b1 - b0) * (b1 - b0))


## ¿El elemento avanza hacia el plato (a no crece) sin bajar (b no decrece)? Se comprueba por muestras.
static func _monotone(e: Dictionary) -> bool:
	var prev := _point_at(e, 0.0)
	for i in range(1, SAMPLES + 1):
		var q := _point_at(e, float(i) / float(SAMPLES))
		if q[0] > prev[0] + EPS or q[1] < prev[1] - EPS:
			return false
		prev = q
	return true


# ---------------------------------------------------------------------------------------------------------------
# Demasía constante (sin M): desplazamiento equidistante del perfil hacia el lado del aire
# ---------------------------------------------------------------------------------------------------------------

## Dirección unitaria de avance al inicio (at_end = false) o al final (true) de un elemento.
static func _tangent(e: Dictionary, at_end: bool) -> PackedFloat64Array:
	if e["kind"] == "line":
		var len := _dist(e["a0"], e["b0"], e["a1"], e["b1"])
		return PackedFloat64Array([(e["a1"] - e["a0"]) / len, (e["b1"] - e["b0"]) / len])
	var pa: float = e["a1"] if at_end else e["a0"]
	var pb: float = e["b1"] if at_end else e["b0"]
	var ra: float = (pa - e["ca"]) / e["rad"]
	var rb: float = (pb - e["cb"]) / e["rad"]
	return PackedFloat64Array([-rb, ra]) if e["ccw"] else PackedFloat64Array([rb, -ra])


## Cadena a distancia s del perfil. Cada elemento se desplaza por la normal del lado del aire (a la derecha del
## sentido de avance): las rectas se trasladan y los arcos cambian de radio (más s si son convexos, menos s si son
## cóncavos). En las esquinas convexas se añade un arco de radio s alrededor del vértice; en las cóncavas se
## recortan los dos elementos en su intersección. Devuelve { chain } o { error }.
static func _offset_equidistant(chain: Array, s: float) -> Dictionary:
	if s <= EPS:
		return { "chain": _translate(chain, 0.0, 0.0) }
	var offs: Array = []
	for e in chain:
		var o: Dictionary = e.duplicate()
		if e["kind"] == "line":
			var t := _tangent(e, false)
			o["a0"] += s * t[1]
			o["b0"] -= s * t[0]
			o["a1"] += s * t[1]
			o["b1"] -= s * t[0]
		else:
			var rad2: float = e["rad"] + s if e["ccw"] else e["rad"] - s
			if rad2 <= EPS:
				return { "error": ("la demasía L (%s mm) no cabe en el radio cóncavo R%s del perfil; programa M " +
					"(demasías por ejes) o una L menor.") % [_num(s), _num(e["rad"])] }
			var k: float = rad2 / e["rad"]
			o["a0"] = e["ca"] + (e["a0"] - e["ca"]) * k
			o["b0"] = e["cb"] + (e["b0"] - e["cb"]) * k
			o["a1"] = e["ca"] + (e["a1"] - e["ca"]) * k
			o["b1"] = e["cb"] + (e["b1"] - e["cb"]) * k
			o["rad"] = rad2
		o["src"] = offs.size()  # elemento del perfil del que sale
		offs.append(o)
	var out: Array = []
	for i in offs.size():
		var o: Dictionary = offs[i]
		if i > 0:
			var prev: Dictionary = out[out.size() - 1]
			var t0 := _tangent(chain[i - 1], true)
			var t1 := _tangent(chain[i], false)
			var turn := t0[0] * t1[1] - t0[1] * t1[0]
			var va: float = chain[i]["a0"]
			var vb: float = chain[i]["b0"]
			if turn > 1e-9:
				# esquina convexa: arco de radio s alrededor del vértice
				out.append({ "kind": "arc", "a0": prev["a1"], "b0": prev["b1"], "a1": o["a0"], "b1": o["b0"],
					"ca": va, "cb": vb, "rad": s, "ccw": true, "n": o.get("n", -1), "line": o.get("line", 0),
					"src": -1 })
			elif turn < -1e-9:
				# esquina cóncava: los dos elementos desplazados se cortan
				var x := _intersect(prev, o, va, vb)
				if x.is_empty():
					return { "error": "demasía constante en una esquina cóncava: %s; programa M." % PHASE2 }
				prev["a1"] = x[0]
				prev["b1"] = x[1]
				o["a0"] = x[0]
				o["b0"] = x[1]
			else:
				o["a0"] = prev["a1"]
				o["b0"] = prev["b1"]
		out.append(o)
	# validación: ningún elemento se ha dado la vuelta al recortarlo y la cadena sigue siendo monótona
	var clean: Array = []
	for o in out:
		var si: int = o["src"]
		o.erase("src")
		if _length(o) < EPS:
			continue
		if si >= 0 and o["kind"] == "line":
			var src: Dictionary = chain[si]
			var dot: float = (o["a1"] - o["a0"]) * (src["a1"] - src["a0"]) \
					+ (o["b1"] - o["b0"]) * (src["b1"] - src["b0"])
			if dot <= 0.0:
				return { "error": "un tramo más corto que la demasía L: %s; programa M o una L menor." % PHASE2 }
		elif si >= 0 and absf(_sweep(o)) > absf(_sweep(chain[si])) + 1e-6:
			return { "error": "un arco del perfil más corto que la demasía L: %s; programa M o una L menor." % PHASE2 }
		if not _monotone(o):
			return { "error": "la demasía constante deja un perfil con canales: %s; programa M." % PHASE2 }
		clean.append(o)
	if clean.is_empty():
		return { "error": "la demasía constante anula el perfil." }
	return { "chain": clean }


## Intersección de dos elementos desplazados (rectas prolongadas y circunferencias completas), la más cercana al
## vértice (va, vb) del perfil. [] si no se cortan.
static func _intersect(e1: Dictionary, e2: Dictionary, va: float, vb: float) -> PackedFloat64Array:
	var cands: Array = []
	if e1["kind"] == "line" and e2["kind"] == "line":
		var d1a: float = e1["a1"] - e1["a0"]
		var d1b: float = e1["b1"] - e1["b0"]
		var d2a: float = e2["a1"] - e2["a0"]
		var d2b: float = e2["b1"] - e2["b0"]
		var den := d1a * d2b - d1b * d2a
		if absf(den) < 1e-12:
			return PackedFloat64Array()
		var t: float = ((e2["a0"] - e1["a0"]) * d2b - (e2["b0"] - e1["b0"]) * d2a) / den
		cands.append(PackedFloat64Array([e1["a0"] + t * d1a, e1["b0"] + t * d1b]))
	elif e1["kind"] == "line" or e2["kind"] == "line":
		var ln: Dictionary = e1 if e1["kind"] == "line" else e2
		var ci: Dictionary = e2 if e1["kind"] == "line" else e1
		cands = _line_circle(ln, ci)
	else:
		cands = _circle_circle(e1, e2)
	var best := PackedFloat64Array()
	var best_d := INF
	for q in cands:
		var d := _dist(q[0], q[1], va, vb)
		if d < best_d:
			best_d = d
			best = q
	return best


static func _line_circle(ln: Dictionary, ci: Dictionary) -> Array:
	var da: float = ln["a1"] - ln["a0"]
	var db: float = ln["b1"] - ln["b0"]
	var fa: float = ln["a0"] - ci["ca"]
	var fb: float = ln["b0"] - ci["cb"]
	var qa := da * da + db * db
	var qb := 2.0 * (fa * da + fb * db)
	var qc: float = fa * fa + fb * fb - ci["rad"] * ci["rad"]
	var disc := qb * qb - 4.0 * qa * qc
	if qa < 1e-18 or disc < -1e-12:
		return []
	var sq := sqrt(maxf(disc, 0.0))
	var out: Array = []
	for t in [(-qb - sq) / (2.0 * qa), (-qb + sq) / (2.0 * qa)]:
		out.append(PackedFloat64Array([ln["a0"] + t * da, ln["b0"] + t * db]))
	return out


static func _circle_circle(c1: Dictionary, c2: Dictionary) -> Array:
	var d := _dist(c1["ca"], c1["cb"], c2["ca"], c2["cb"])
	var r1: float = c1["rad"]
	var r2: float = c2["rad"]
	if d < 1e-12 or d > r1 + r2 + 1e-9 or d < absf(r1 - r2) - 1e-9:
		return []
	var x := (d * d + r1 * r1 - r2 * r2) / (2.0 * d)
	var y := sqrt(maxf(r1 * r1 - x * x, 0.0))
	var ua: float = (c2["ca"] - c1["ca"]) / d
	var ub: float = (c2["cb"] - c1["cb"]) / d
	var pa: float = c1["ca"] + x * ua
	var pb: float = c1["cb"] + x * ub
	return [PackedFloat64Array([pa - y * ub, pb + y * ua]), PackedFloat64Array([pa + y * ub, pb - y * ua])]


# ---------------------------------------------------------------------------------------------------------------
# G86: ciclo fijo de roscado longitudinal (manual, 9.9, p. 187-192)
# ---------------------------------------------------------------------------------------------------------------

## Expande G86. p, en mm y con X en radio: x_r y z (punto inicial de la rosca), q_r y r_z (punto final), i
## (profundidad en radio; positiva, rosca exterior), b (B > 0: penetraciones B, B√2, B√3…; B < 0: pasadas iguales de
## |B|), e (incremento mínimo de la penetración con B > 0), d (distancia de seguridad en X, radio), l (demasía del
## acabado: L > 0 con el ángulo A, L < 0 radial, L = 0 repite la última pasada), c (paso: C > 0 medido sobre el cono,
## C < 0 sobre el eje Z), j (salida: J > 0 en diagonal hasta la distancia de seguridad, J < 0 hasta el final (R, Q)
## y luego en X, J = 0 rosca ciega), a_deg (ángulo de penetración respecto al eje X, 30° si no se programa) y w_deg
## (posición angular del cabezal en el punto inicial de la rosca).
## Funcionamiento básico (p. 192): G00 al punto de aproximación (Z, X + D); en cada pasada, G00 a la profundidad según
## el ángulo A, roscado sincronizado con el cabezal con la salida J y G00 de vuelta al punto de aproximación a la
## distancia D del tramo roscado; al final, la pasada de acabado hasta I. El ciclo acaba en el punto de aproximación.
## Penetración por el flanco (lectura del simulador de la figura de la p. 187): la pasada de profundidad d empieza
## desplazada −d·tan A en Z (hacia el plato), así que la herramienta baja paralela al flanco de detrás y corta con el
## filo de delante.
## Devuelve { moves (IR sin n ni line), errors: [{ code, text }], pitch_z (avance en Z por vuelta), passes, depths }.
static func expand_thread(p: Dictionary, call_r: float, call_z: float) -> Dictionary:
	var res := { "moves": [], "errors": [], "pitch_z": 0.0, "passes": 0, "depths": [] }
	var zs: float = p["z"]
	var rs: float = p["x_r"]
	var ze: float = p["r_z"]
	var re: float = p["q_r"]
	var dz := ze - zs
	var dr := re - rs
	var span := sqrt(dz * dz + dr * dr)
	if absf(dz) < EPS:
		res["errors"].append({ "code": "cycle_profile", "text": "G86: el punto inicial (X, Z) y el final (Q, R) tienen la misma Z; el roscado en la cara es G87 (p. 193)." })
		return res
	if dz > 0.0:
		res["errors"].append({ "code": "unsupported", "text": "G86 alejándose del plato (R mayor que Z): %s. Programa la rosca desde Z hacia el plato (R menor que Z)." % PHASE2 })
		return res
	var c: float = p["c"]
	var pitch_z := absf(c) * absf(dz) / span if c > 0.0 else absf(c)
	res["pitch_z"] = pitch_z
	var j := float(p.get("j", 0.0))
	if absf(j) >= absf(dz) - EPS:
		res["errors"].append({ "code": "cycle_param", "text": "G86: la salida J (%s mm) es tan larga como la rosca (%s mm en Z)." % [_num(absf(j)), _num(absf(dz))] })
		return res
	var depth: float = p["i"]
	var l := float(p.get("l", 0.0))
	var plan := thread_passes(depth, float(p["b"]), absf(float(p.get("e", 0.0))), l)
	if not plan["errors"].is_empty():
		res["errors"] = plan["errors"]
		return res
	var depths: Array = plan["depths"]
	res["depths"] = depths
	res["passes"] = depths.size()
	var a_deg := float(p.get("a_deg", 30.0))
	var ta := tan(deg_to_rad(a_deg))
	var dd := absf(float(p.get("d", 0.0)))
	var w_deg := float(p.get("w_deg", 0.0))
	var st := { "moves": res["moves"], "z": call_z, "r": call_r }
	var az := zs  # punto de aproximación (p. 192)
	var ar := rs + dd
	_t_move(st, "rapid", az, ar, {})
	var rough := depth - absf(l)
	var n := depths.size()
	for k in n:
		var d: float = depths[k]
		var finish := k == n - 1
		var shift := -d * ta
		var infeed := a_deg
		if finish and l < 0.0:
			shift = -rough * ta  # acabado con penetración radial desde la última pasada (p. 188)
			infeed = 0.0
		var info := { "pitch": pitch_z, "start_deg": w_deg, "sync": true, "pass": k + 1, "passes": n, "depth": d,
			"total": depth, "kind": "G86", "infeed_deg": infeed }
		var sz := zs + shift
		var sr := rs - d
		var ez := ze + shift
		var er := re - d
		_t_move(st, "rapid", sz, sr, {})  # a la profundidad de la pasada
		if absf(j) < EPS:
			_t_thread(st, ez, er, pitch_z, info)  # rosca ciega: hasta el final y sale en X
			_t_move(st, "rapid", ez, re + dd, {})
		else:
			var t := (absf(dz) - absf(j)) / absf(dz)
			_t_thread(st, sz + t * (ez - sz), sr + t * (er - sr), pitch_z, info)  # hasta el punto J
			if j > 0.0:
				_t_thread(st, ez, re + dd, pitch_z, info)  # J > 0: en diagonal a la distancia de seguridad
			else:
				_t_thread(st, ez, re, pitch_z, info)  # J < 0: al final de la rosca (R, Q) y luego en X
				_t_move(st, "rapid", ez, re + dd, {})
		_t_move(st, "rapid", az, ar, {})  # vuelta a la distancia D del tramo roscado
	return res


## Profundidades acumuladas de las pasadas de G86 (p. 188): con B > 0, B·√n, con un incremento de al menos E; con
## B < 0, |B| más en cada pasada. La última de desbaste llega justo a I − |L| (se da una pasada igual a lo que falta) y
## detrás va la de acabado hasta I (con L = 0, la repetición de la última). Devuelve { depths, errors }.
static func thread_passes(depth: float, b: float, e: float, l: float) -> Dictionary:
	var out := { "depths": [], "errors": [] }
	var rough := depth - absf(l)
	if rough <= EPS:
		out["errors"].append({ "code": "cycle_param", "text": "G86: la demasía de acabado L (%s mm) debe ser menor que la profundidad de la rosca I (%s mm)." % [_num(absf(l)), _num(depth)] })
		return out
	var prev := 0.0
	var k := 0
	while prev < rough - EPS:
		k += 1
		if k > MAX_PASSES:
			out["errors"].append({ "code": "too_many_passes", "text": "G86: saldrían más de %d pasadas; revisa B y E." % MAX_PASSES })
			out["depths"] = []
			return out
		var target := b * sqrt(float(k)) if b > 0.0 else -b * float(k)
		if b > 0.0 and target - prev < e:
			target = prev + e
		if target > rough - EPS:
			target = rough
		out["depths"].append(target)
		prev = target
	out["depths"].append(depth)
	return out


static func _t_move(st: Dictionary, type: String, z: float, r: float, extra: Dictionary) -> void:
	if absf(z - float(st["z"])) < EPS and absf(r - float(st["r"])) < EPS:
		return
	var mv := { "type": type, "from": { "r": st["r"], "z": st["z"] }, "to": { "r": r, "z": z } }
	for k in extra:
		mv[k] = extra[k]
	st["moves"].append(mv)
	st["z"] = z
	st["r"] = r


## Tramo de roscado: el avance por vuelta sobre la trayectoria es el que da un paso por vuelta en Z. Solo el primer
## tramo de cada pasada espera a la posición angular del cabezal (sync); los siguientes siguen la misma hélice.
static func _t_thread(st: Dictionary, z: float, r: float, pitch_z: float, info: Dictionary) -> void:
	var dz := absf(z - float(st["z"]))
	var dr := absf(r - float(st["r"]))
	var seg := sqrt(dz * dz + dr * dr)
	if seg < EPS:
		return
	var f_path := pitch_z * seg / dz if dz > EPS else pitch_z
	var th := info.duplicate()
	info["sync"] = false
	_t_move(st, "thread", z, r, { "feed": { "mode": "mmrev", "value": f_path }, "thread": th, "pass": 4 })


# ---------------------------------------------------------------------------------------------------------------
# Mensajes
# ---------------------------------------------------------------------------------------------------------------

static func _profile_error(kind: String, e: Dictionary) -> Dictionary:
	var dir := "subir hacia el plato (X no decrece mientras Z decrece)"
	if kind == "G69" or kind == "G82":
		dir = "bajar hacia el eje (Z no decrece mientras X decrece)"
	var txt := "%s: el perfil debe %s; un perfil con canales o rebajes está %s." % [kind, dir, PHASE2]
	if kind == "G81" or kind == "G82":
		txt = ("%s: el tramo del punto inicial (X, Z) al final (Q, R) debe %s, como en la figura del manual; " +
			"el mecanizado interior está %s.") % [kind, dir, PHASE2]
	var err := { "code": "profile_not_monotone", "text": txt }
	if int(e.get("n", -1)) >= 0 or int(e.get("line", 0)) > 0:
		err["n"] = e.get("n", -1)
		err["line"] = e.get("line", 0)
	return err


static func _position_text(kind: String, sw: bool, a_s: float, b_top: float) -> String:
	var need_r := a_s if sw else b_top
	var need_z := b_top if sw else a_s
	return ("%s: posición de la herramienta incorrecta. El punto de llamada debe quedar fuera del perfil más las " +
		"demasías L y M: radio de al menos %s mm (Ø%s) y Z de al menos %s mm " +
		"(consideraciones del ciclo en el manual).") % [kind, _num(need_r), _num(2.0 * need_r), _num(need_z)]


## Número corto para los mensajes (3 decimales como mucho, sin ceros de sobra), con el toFixed de JavaScript.
static func _num(x: float) -> String:
	var s := Js.to_fixed(x, 3)
	if s.find(".") >= 0:
		s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
