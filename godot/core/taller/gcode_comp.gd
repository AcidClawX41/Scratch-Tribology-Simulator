## Taller · compensación del radio de la punta (G40, G41, G42) del control compatible con el Fagor 8055 T.
##
## El CNC programa la punta teórica P: la esquina de los dos lados con los que se calibró la herramienta. Sin
## compensación, P recorre el contorno programado y el redondeo de la punta deja el error en los chaflanes, los conos y
## los arcos (manual de programación Ref. 1110, 8.2 y 8.2.2, p. 128 y 132). Con G41 o G42 el CNC tiene en cuenta el
## radio R y el código de forma F del corrector activo (8.2.3, p. 133): el centro de la punta recorre el contorno
## desplazado R hacia el lado de la herramienta y el IR vuelve a ser la punta teórica, P = centro − v(F), con v el
## vector de la punta teórica al centro según el código de forma (p. 129-131).
##
## - G41: herramienta a la izquierda de la pieza según el sentido del mecanizado; G42, a la derecha (p. 133; ed.
##   española, cap. 8, p. 4). En la vista del plano (Z a la derecha, X hacia arriba), cilindrar hacia el plato por
##   fuera es G42.
## - Inicio (8.2.4, p. 134-136) y final (8.2.6, p. 138-140), según el parámetro máquina COMPTYPE (P74, manual de
##   instalación Ref. 1006, p. 119-121): con 0 (por defecto) la herramienta «bordea la esquina» cuando es convexa; con 1
##   va directamente a la perpendicular del punto. En una esquina cóncava las dos formas coinciden: la entrada va a la
##   perpendicular del primer tramo en su punto inicial y la salida sale de la perpendicular del último en su final.
## - Esquinas (8.2.5, p. 137), según COMPMODE (P175, manual de instalación p. 154-155): cóncavas, en la intersección de
##   las trayectorias desplazadas; convexas, con 0 (por defecto) tramos rectos hasta un ángulo entre trayectorias de
##   300° y arcos por encima; con 1, siempre arcos; con 2, la intersección hasta 300°.
## - Un G00 anula temporalmente la compensación: la herramienta queda tangente a la perpendicular del final del último
##   bloque compensado, el G00 va sin compensar y el siguiente G01 es de nuevo el primer punto compensado (8.2.7,
##   p. 142).
## Decisiones del simulador (docs/taller/fagor-fase2.md): los «tramos rectos» de COMPMODE 0 prolongan cada trayectoria
## desplazada hasta su intersección, como mucho R (con 90° es la esquina en escuadra de la figura de la p. 137), y los une
## con una cuerda si no se cortan antes; el cambio de G41 a G42 sin G40 (8.2.8) y la detección de colisiones (G41 N,
## 8.3) son de la fase 2.
##
## Uso (lo hace el intérprete, gcode.gd): activate() al programar G41/G42, feed() por cada G01/G02/G03, rapid() por cada
## G00, event() por cada movimiento sin desplazamiento (cabezal, refrigerante, espera…), lead_out() para G40 con un G01 y
## stop() para anularla sin movimiento (G40 sola, G04, un ciclo, M30). Los movimientos del IR se añaden a `out`.
## Geometría en (z, r) con dobles (Vector2 es de precisión simple): sin nodos ni azar.
extends RefCounted

const Js = preload("res://core/shared/js.gd")

const EPS := 1e-9
const LEN_EPS := 1e-7  # mm: los tramos más cortos no se emiten (un arco de barrido nulo sería una vuelta entera)
const ANG_EPS := 1e-7  # rad: por debajo, dos tramos son tangentes en la esquina
const ARC_LIMIT_DEG := 120.0  # giro de la trayectoria que corresponde a 300° entre trayectorias (COMPMODE 0 y 2)
const PHASE2 := "no soportado en este simulador (fase 2)"

## Vector de la punta teórica al centro de la punta, en unidades de R y en (dz, dr), por código de forma F: torno
## horizontal con X hacia arriba y Z a la derecha (manual, 8.2.1, p. 129-130). La herramienta exterior estándar del
## simulador (centro = punta teórica + (rε, rε), CONTRATOS.md) es la F3; la de roscar, con la punta en el eje de la V,
## la F62. F0 y F9: la punta teórica es el centro. Las familias de ranurar (F21-F39), las plaquitas redondas (F40-F59) y
## las brocas no están en el simulador.
const LOCATION := {
	0: [0.0, 0.0], 9: [0.0, 0.0],
	1: [-1.0, 1.0], 2: [0.0, 1.0], 3: [1.0, 1.0], 4: [1.0, 0.0],
	5: [1.0, -1.0], 6: [0.0, -1.0], 7: [-1.0, -1.0], 8: [-1.0, 0.0],
	62: [0.0, 1.0], 64: [1.0, 0.0], 66: [0.0, -1.0], 68: [-1.0, 0.0],
}

const S_OFF := 0  # sin compensación
const S_ARMED_PERP := 1  # G41/G42 sin movimiento: el primer tramo se compensa desde su punto inicial (p. 134)
const S_ARMED_LEAD := 2  # tras un G00: el siguiente G01 es la entrada (p. 142)
const S_LEAD := 3  # entrada pendiente (su final depende del tramo siguiente)
const S_CHAIN := 4  # tramo compensado pendiente (su final depende del siguiente)

var side := 0  # 0, 41 o 42
var rad := 0.0  # R del corrector activo (mm)
var loc := 0  # código de forma F
var vz := 0.0  # vector punta teórica → centro (mm)
var vr := 0.0
var comptype := 0
var compmode := 0
var tip_z := 0.0  # posición real de la punta teórica (el último «to» emitido)
var tip_r := 0.0
var out: Array = []  # IR emitido (lo comparte el intérprete)
var errors: Array = []  # { n, line, code, text }

var _state := S_OFF
var _lead := {}  # entrada pendiente: { el, cz, cr } (centro de partida, sin compensar)
var _pend := {}  # tramo pendiente: { el, sz, sr } (inicio ya resuelto del recorrido del centro)
var _events: Array = []  # movimientos sin desplazamiento que van detrás del pendiente


## Vector (dz, dr) de la punta teórica al centro para el código de forma f y el radio r. [] si el código no está.
static func center_offset(f: int, r: float) -> PackedFloat64Array:
	if not LOCATION.has(f):
		return PackedFloat64Array()
	var u: Array = LOCATION[f]
	return PackedFloat64Array([float(u[0]) * r, float(u[1]) * r])


## ¿Hay algo pendiente de resolver (una entrada o un tramo compensado)?
func pending() -> bool:
	return _state == S_LEAD or _state == S_CHAIN


func active() -> bool:
	return side != 0


## G41 (s = 41) o G42 (s = 42) con el radio y el código de forma del corrector. Sin movimiento en el bloque, el primer
## tramo se compensa desde su punto inicial; si el bloque se mueve, lo decide feed() o rapid().
func activate(s: int, r: float, f: int, ctype: int, cmode: int) -> void:
	side = s
	rad = maxf(r, 0.0)
	loc = f
	var v := center_offset(f, rad)
	vz = v[0] if v.size() == 2 else 0.0
	vr = v[1] if v.size() == 2 else 0.0
	comptype = ctype
	compmode = cmode
	_state = S_ARMED_PERP


## Movimiento sin desplazamiento (cabezal, refrigerante, espera, herramienta, fin): detrás del tramo pendiente.
func event(mv: Dictionary) -> void:
	mv["from"] = { "r": tip_r, "z": tip_z }
	mv["to"] = { "r": tip_r, "z": tip_z }
	if pending():
		_events.append(mv)
	else:
		out.append(mv)


## G00 hasta (z1, r1): nunca se compensa (p. 142). Lo pendiente acaba en la perpendicular de su final.
func rapid(n: int, line: int, z1: float, r1: float) -> void:
	_break()
	_emit_raw(n, line, "rapid", z1, r1, {})
	if side != 0:
		_state = S_ARMED_LEAD


## G01, G02 o G03 (o un tramo de ciclo) con el elemento programado el:
##   { kind: "line"|"arc", z0, r0, z1, r1, cz, cr, rad, cw, feed, n, line, extra? }
## lead = true si es el propio bloque que activa G41/G42 (la entrada).
func feed(el: Dictionary, lead: bool = false) -> void:
	if side == 0 or _state == S_OFF:
		_emit_uncomp(el)
		return
	if lead:
		_break()
		_lead = { "el": el, "cz": tip_z + vz, "cr": tip_r + vr }
		_state = S_LEAD
		return
	match _state:
		S_ARMED_PERP, S_ARMED_LEAD:
			if _state == S_ARMED_LEAD and el["kind"] == "line":
				_lead = { "el": el, "cz": tip_z + vz, "cr": tip_r + vr }
				_state = S_LEAD
				return
			# primer tramo compensado desde su punto inicial: la herramienta se mueve a la perpendicular (p. 134)
			var q := _offset_point(el, false)
			_seg_line(el, q[0], q[1])
			_pend = { "el": el, "sz": q[0], "sr": q[1] }
			_state = S_CHAIN
		S_LEAD:
			_resolve_lead(el)
		S_CHAIN:
			_resolve_corner(el)


## G40 con un G01 hasta el final de lo programado en lo (la salida, p. 138-140). Después, sin compensación.
func lead_out(lo: Dictionary) -> void:
	match _state:
		S_CHAIN:
			var a: Dictionary = _pend["el"]
			_leave(a, lo, _pend["sz"], _pend["sr"], true)
		S_LEAD:
			var l: Dictionary = _lead["el"]
			_leave(l, lo, _lead["cz"], _lead["cr"], false)
		_:
			_emit_uncomp(lo)
	_flush_events()
	_off()


## Anula la compensación sin movimiento (G40 sola, G04, ciclo fijo, M30…): lo pendiente acaba en la perpendicular.
func stop() -> void:
	_break()
	_off()


# ── internos ──────────────────────────────────────────────────────────────────────────────────────────────────

func _off() -> void:
	side = 0
	_state = S_OFF
	_pend = {}
	_lead = {}


## Termina lo pendiente con la herramienta tangente a la perpendicular del final (p. 138 y 142).
func _break() -> void:
	match _state:
		S_CHAIN:
			var a: Dictionary = _pend["el"]
			var q := _offset_point(a, true)
			_seg_element(a, _pend["sz"], _pend["sr"], q[0], q[1])
			_pend = {}
			_flush_events()
			_state = S_ARMED_LEAD
		S_LEAD:
			var l: Dictionary = _lead["el"]
			var q := _offset_point(l, true)
			_seg_line(l, q[0], q[1])
			_lead = {}
			_flush_events()
			_state = S_ARMED_LEAD


func _flush_events() -> void:
	for mv in _events:
		mv["from"] = { "r": tip_r, "z": tip_z }
		mv["to"] = { "r": tip_r, "z": tip_z }
		out.append(mv)
	_events = []


## Entrada pendiente + primer tramo b: la entrada acaba donde manda COMPTYPE y b empieza compensado.
func _resolve_lead(b: Dictionary) -> void:
	var l: Dictionary = _lead["el"]
	var pz: float = l["z1"]
	var pr: float = l["r1"]
	var dl := _tangent(l, true)
	var db := _tangent(b, false)
	var kind := _corner_kind(dl, db)
	var qb := _offset_point(b, false)
	if comptype == 0 and kind == "convex":
		# bordea la esquina: perpendicular de la entrada en su final y unión por fuera de la esquina (p. 135)
		var ql := _offset_point(l, true)
		_seg_line(l, ql[0], ql[1])
		var j := _convex_join(pz, pr, dl, db, ql, qb, false, b["kind"] == "line")
		for s in j["joins"]:
			_seg(l, s)
		_flush_events()
		_pend = { "el": b, "sz": j["b_start"][0], "sr": j["b_start"][1] }
	else:
		# va directamente a la perpendicular del primer tramo en su punto inicial (p. 135)
		_seg_line(l, qb[0], qb[1])
		_flush_events()
		_pend = { "el": b, "sz": qb[0], "sr": qb[1] }
	_lead = {}
	_state = S_CHAIN


## Tramo pendiente a + siguiente b: se resuelve la esquina, se emite a y b queda pendiente.
func _resolve_corner(b: Dictionary) -> void:
	var a: Dictionary = _pend["el"]
	var pz: float = a["z1"]
	var pr: float = a["r1"]
	var da := _tangent(a, true)
	var db := _tangent(b, false)
	var qa := _offset_point(a, true)
	var qb := _offset_point(b, false)
	var kind := _corner_kind(da, db)
	var a_end := qa
	var joins: Array = []
	var b_start := qb
	if kind == "concave":
		var x := _intersect(a, b, qa, qb)
		if x.is_empty():
			_err(b, "comp_corner", "no se puede compensar la esquina con el bloque anterior: las trayectorias desplazadas R = %s mm no se cortan." % _num(rad))
			x = qa
		a_end = x
		b_start = x
	elif kind == "convex":
		var j := _convex_join(pz, pr, da, db, qa, qb, a["kind"] == "line", b["kind"] == "line")
		a_end = j["a_end"]
		joins = j["joins"]
		b_start = j["b_start"]
	_seg_element(a, _pend["sz"], _pend["sr"], a_end[0], a_end[1])
	for s in joins:
		_seg(a, s)
	_flush_events()
	_pend = { "el": b, "sz": b_start[0], "sr": b_start[1] }


## Salida (G40 con G01 de lo): el último tramo a acaba en su perpendicular; con COMPTYPE 0 y esquina convexa la
## herramienta bordea la esquina hasta la perpendicular de la salida (p. 139); luego va al final sin compensar.
## (sz, sr): inicio resuelto de a. a_is_chain: a es un tramo compensado (si no, es la entrada, que no se prolonga).
func _leave(a: Dictionary, lo: Dictionary, sz: float, sr: float, a_is_chain: bool) -> void:
	var pz: float = a["z1"]
	var pr: float = a["r1"]
	var da := _tangent(a, true)
	var dlo := _tangent(lo, false)
	var qa := _offset_point(a, true)
	var kind := _corner_kind(da, dlo)
	if comptype == 0 and kind == "convex":
		var qlo := _offset_point(lo, false)
		var j := _convex_join(pz, pr, da, dlo, qa, qlo, a_is_chain and a["kind"] == "line", false)
		if a_is_chain:
			_seg_element(a, sz, sr, j["a_end"][0], j["a_end"][1])
		else:
			_seg_line(a, j["a_end"][0], j["a_end"][1])
		for s in j["joins"]:
			_seg(a, s)
	elif a_is_chain:
		_seg_element(a, sz, sr, qa[0], qa[1])
	else:
		_seg_line(a, qa[0], qa[1])
	_flush_events()
	# a la cota programada sin compensar: el centro en el final + v
	_seg_line(lo, float(lo["z1"]) + vz, float(lo["r1"]) + vr, false)


## Unión de una esquina convexa en el vértice (pz, pr), de qa (perpendicular del final del tramo a) a qb (del inicio
## de b): arco de radio R alrededor del vértice o tramos rectos, según COMPMODE (p. 137). merge_a / merge_b: el tramo
## es una recta que se puede prolongar sobre sí misma. Devuelve { a_end, joins: [segmentos], b_start }.
func _convex_join(pz: float, pr: float, da: PackedFloat64Array, db: PackedFloat64Array, qa: PackedFloat64Array,
		qb: PackedFloat64Array, merge_a: bool, merge_b: bool) -> Dictionary:
	var cross := da[0] * db[1] - da[1] * db[0]
	var dot := da[0] * db[0] + da[1] * db[1]
	var turn := absf(atan2(cross, dot))
	var joins: Array = []
	if compmode == 1 or turn > deg_to_rad(ARC_LIMIT_DEG) + 1e-12:
		# arco de radio R alrededor del vértice: con G42 la herramienta rodea la esquina en sentido antihorario
		joins.append({ "kind": "arc", "z": qb[0], "r": qb[1], "cz": pz, "cr": pr, "cw": side == 41 })
		return { "a_end": qa, "joins": joins, "b_start": qb }
	var e := rad * tan(turn / 2.0)
	if compmode == 0:
		e = minf(e, rad)
	var xa := PackedFloat64Array([qa[0] + e * da[0], qa[1] + e * da[1]])
	var xb := PackedFloat64Array([qb[0] - e * db[0], qb[1] - e * db[1]])
	var a_end := qa
	if merge_a:
		a_end = xa
	else:
		joins.append({ "kind": "line", "z": xa[0], "r": xa[1] })
	if _dist(xa[0], xa[1], xb[0], xb[1]) > LEN_EPS:
		joins.append({ "kind": "line", "z": xb[0], "r": xb[1] })
	var b_start := qb
	if merge_b:
		b_start = xb
	else:
		joins.append({ "kind": "line", "z": qb[0], "r": qb[1] })
	return { "a_end": a_end, "joins": joins, "b_start": b_start }


## «tangent», «convex» o «concave» para la herramienta en el lado activo. Una vuelta atrás completa es convexa.
func _corner_kind(da: PackedFloat64Array, db: PackedFloat64Array) -> String:
	var cross := da[0] * db[1] - da[1] * db[0]
	var dot := da[0] * db[0] + da[1] * db[1]
	var turn := atan2(cross, dot)
	if absf(turn) < ANG_EPS:
		return "tangent"
	if absf(cross) < 1e-12:
		return "convex"  # vuelta atrás: la herramienta rodea el vértice
	var sgn := 1.0 if side == 42 else -1.0
	return "convex" if sgn * cross > 0.0 else "concave"


## Dirección unitaria del elemento en su inicio (at_end = false) o en su final.
static func _tangent(el: Dictionary, at_end: bool) -> PackedFloat64Array:
	if el["kind"] == "line":
		var dz: float = el["z1"] - el["z0"]
		var dr: float = el["r1"] - el["r0"]
		var d := sqrt(dz * dz + dr * dr)
		if d < EPS:
			return PackedFloat64Array([-1.0, 0.0])
		return PackedFloat64Array([dz / d, dr / d])
	var pz: float = el["z1"] if at_end else el["z0"]
	var pr: float = el["r1"] if at_end else el["r0"]
	var uz: float = (pz - el["cz"]) / el["rad"]
	var ur: float = (pr - el["cr"]) / el["rad"]
	# antihorario (G03): (−ur, uz); horario (G02): (ur, −uz)
	return PackedFloat64Array([ur, -uz]) if el["cw"] else PackedFloat64Array([-ur, uz])


## Normal unitaria hacia el lado de la herramienta: a la derecha del avance con G42 y a la izquierda con G41.
func _normal(d: PackedFloat64Array) -> PackedFloat64Array:
	var sgn := 1.0 if side == 42 else -1.0
	return PackedFloat64Array([sgn * d[1], -sgn * d[0]])


## Punto del recorrido del centro en el inicio (at_end = false) o en el final del elemento: la perpendicular a R.
func _offset_point(el: Dictionary, at_end: bool) -> PackedFloat64Array:
	var n := _normal(_tangent(el, at_end))
	var pz: float = el["z1"] if at_end else el["z0"]
	var pr: float = el["r1"] if at_end else el["r0"]
	return PackedFloat64Array([pz + rad * n[0], pr + rad * n[1]])


## Radio del arco desplazado: R más si la herramienta va por fuera del arco, R menos si va por dentro.
func _offset_radius(el: Dictionary) -> float:
	var ccw: bool = not bool(el["cw"])
	var outside := (side == 42) == ccw
	return float(el["rad"]) + (rad if outside else -rad)


## Intersección de las trayectorias desplazadas de a y b en una esquina cóncava, la más cercana a las perpendiculares.
func _intersect(a: Dictionary, b: Dictionary, qa: PackedFloat64Array, qb: PackedFloat64Array) -> PackedFloat64Array:
	var cands: Array = []
	var da := _tangent(a, true)
	var db := _tangent(b, false)
	if a["kind"] == "line" and b["kind"] == "line":
		var den := da[0] * db[1] - da[1] * db[0]
		if absf(den) < 1e-15:
			return PackedFloat64Array()
		var t := ((qb[0] - qa[0]) * db[1] - (qb[1] - qa[1]) * db[0]) / den
		cands.append(PackedFloat64Array([qa[0] + t * da[0], qa[1] + t * da[1]]))
	elif a["kind"] == "line" or b["kind"] == "line":
		var ln: Dictionary = a if a["kind"] == "line" else b
		var ci: Dictionary = b if a["kind"] == "line" else a
		var q: PackedFloat64Array = qa if a["kind"] == "line" else qb
		var d: PackedFloat64Array = da if a["kind"] == "line" else db
		var rr := _offset_radius(ci)
		if rr > EPS:
			cands = _line_circle(q[0], q[1], d[0], d[1], ci["cz"], ci["cr"], rr)
	else:
		var r1 := _offset_radius(a)
		var r2 := _offset_radius(b)
		if r1 > EPS and r2 > EPS:
			cands = _circle_circle(a["cz"], a["cr"], r1, b["cz"], b["cr"], r2)
	var mz := 0.5 * (qa[0] + qb[0])
	var mr := 0.5 * (qa[1] + qb[1])
	var best := PackedFloat64Array()
	var best_d := INF
	for c in cands:
		var dd := _dist(c[0], c[1], mz, mr)
		if dd < best_d:
			best_d = dd
			best = c
	return best


static func _line_circle(pz: float, pr: float, dz: float, dr: float, cz: float, cr: float, rr: float) -> Array:
	var fz := pz - cz
	var fr := pr - cr
	var b := 2.0 * (fz * dz + fr * dr)
	var c := fz * fz + fr * fr - rr * rr
	var disc := b * b - 4.0 * c
	if disc < -1e-12:
		return []
	var sq := sqrt(maxf(disc, 0.0))
	var out: Array = []
	for t in [(-b - sq) / 2.0, (-b + sq) / 2.0]:
		out.append(PackedFloat64Array([pz + t * dz, pr + t * dr]))
	return out


static func _circle_circle(z1: float, r1c: float, ra: float, z2: float, r2c: float, rb: float) -> Array:
	var d := _dist(z1, r1c, z2, r2c)
	if d < 1e-12 or d > ra + rb + 1e-9 or d < absf(ra - rb) - 1e-9:
		return []
	var x := (d * d + ra * ra - rb * rb) / (2.0 * d)
	var y := sqrt(maxf(ra * ra - x * x, 0.0))
	var uz := (z2 - z1) / d
	var ur := (r2c - r1c) / d
	var pz := z1 + x * uz
	var pr := r1c + x * ur
	return [PackedFloat64Array([pz - y * ur, pr + y * uz]), PackedFloat64Array([pz + y * ur, pr - y * uz])]


# ── emisión del IR (punta teórica = centro − v) ──────────────────────────────────────────────────────────────────

## Recorre el elemento compensado de (sz, sr) a (ez, er) (puntos del recorrido del centro).
func _seg_element(el: Dictionary, sz: float, sr: float, ez: float, er: float) -> void:
	if el["kind"] == "line":
		var d := _tangent(el, false)
		if (ez - sz) * d[0] + (er - sr) * d[1] < -LEN_EPS:
			_err(el, "comp_short", "el tramo es más corto que lo que exige el radio de la punta (R = %s mm): la compensación lo recorrería al revés. El CNC real lo resuelve con la detección de colisiones G41 N/G42 N (manual, 8.3, p. 146), %s." % [_num(rad), PHASE2])
			return
		_seg_line(el, ez, er)
		return
	var rr := _offset_radius(el)
	if rr < -EPS:
		_err(el, "comp_radius", "el radio de la punta (R = %s mm) es mayor que el radio del arco cóncavo (%s mm): la herramienta no cabe en él." % [_num(rad), _num(float(el["rad"]))])
		return
	if rr <= 1e-6:
		return  # el radio de la punta es el del arco: el centro se queda en el centro del arco
	# el arco desplazado no puede darse la vuelta: su inicio y su final deben estar en el barrido programado
	var sweep := _sweep_of(el)
	var t0 := _param_on(el, sz, sr)
	var t1 := _param_on(el, ez, er)
	if t1 < t0 - 1e-9 or t0 > sweep + 1e-7 or t1 < -1e-7:
		_err(el, "comp_short", "el arco es más corto que lo que exige el radio de la punta (R = %s mm): %s." % [_num(rad), PHASE2])
		return
	if (t1 - t0) * rr < LEN_EPS:
		return
	var mv := _ir(el, "arc", ez - vz, er - vr, { "arc": { "cw": bool(el["cw"]), "center": { "r": float(el["cr"]) - vr, "z": float(el["cz"]) - vz } } }, true)
	out.append(mv)


## Barrido del arco programado (radianes, positivo).
static func _sweep_of(el: Dictionary) -> float:
	var a0 := atan2(float(el["r0"]) - float(el["cr"]), float(el["z0"]) - float(el["cz"]))
	var a1 := atan2(float(el["r1"]) - float(el["cr"]), float(el["z1"]) - float(el["cz"]))
	var s := fposmod((a0 - a1) if el["cw"] else (a1 - a0), TAU)
	return s if s > 1e-12 else TAU


## Posición angular de un punto en el sentido del arco, desde su inicio (radianes; puede ser algo negativa).
static func _param_on(el: Dictionary, z: float, r: float) -> float:
	var a0 := atan2(float(el["r0"]) - float(el["cr"]), float(el["z0"]) - float(el["cz"]))
	var a := atan2(r - float(el["cr"]), z - float(el["cz"]))
	var t := fposmod((a0 - a) if el["cw"] else (a - a0), TAU)
	if t > TAU - 1e-6:
		t -= TAU  # un pelo antes del inicio (redondeo), no una vuelta entera
	return t


## Segmento de unión (recta o arco alrededor del vértice) del bloque owner.
func _seg(owner: Dictionary, s: Dictionary) -> void:
	if s["kind"] == "line":
		_seg_line(owner, s["z"], s["r"])
		return
	var cz: float = s["cz"]
	var cr: float = s["cr"]
	if _dist(tip_z + vz, tip_r + vr, s["z"], s["r"]) < LEN_EPS:
		return
	out.append(_ir(owner, "arc", float(s["z"]) - vz, float(s["r"]) - vr, { "arc": { "cw": bool(s["cw"]), "center": { "r": cr - vr, "z": cz - vz } } }, true))


## Recta del recorrido del centro desde la posición actual hasta (ez, er). comp = false: la cota final va sin compensar.
func _seg_line(owner: Dictionary, ez: float, er: float, comp: bool = true) -> void:
	if _dist(tip_z + vz, tip_r + vr, ez, er) < LEN_EPS:
		return
	out.append(_ir(owner, "feed", ez - vz, er - vr, {}, comp))


## Movimiento del IR con la punta teórica; from es la posición actual (el «to» anterior).
func _ir(owner: Dictionary, type: String, tz: float, tr: float, extra: Dictionary, comp: bool) -> Dictionary:
	var mv := { "n": owner["n"], "line": owner["line"], "type": type, "from": { "r": tip_r, "z": tip_z }, "to": { "r": tr, "z": tz } }
	for k in extra:
		mv[k] = extra[k]
	mv["feed"] = (owner["feed"] as Dictionary).duplicate()
	if comp:
		mv["comp"] = { "side": "G%d" % side, "r": rad, "f": loc, "vz": vz, "vr": vr }
	tip_z = tz
	tip_r = tr
	return mv


## Movimiento sin compensar del elemento programado (lo que hacía el intérprete sin G41/G42).
func _emit_uncomp(el: Dictionary) -> void:
	var extra := {}
	var type := "feed"
	if el["kind"] == "arc":
		type = "arc"
		extra["arc"] = { "cw": bool(el["cw"]), "center": { "r": el["cr"], "z": el["cz"] } }
	if el.has("type"):
		type = el["type"]
	for k in el.get("extra", {}):
		extra[k] = el["extra"][k]
	var mv := { "n": el["n"], "line": el["line"], "type": type, "from": { "r": tip_r, "z": tip_z }, "to": { "r": el["r1"], "z": el["z1"] } }
	for k in extra:
		mv[k] = extra[k]
	mv["feed"] = el["feed"]
	for k in el.get("tail", {}):
		mv[k] = el["tail"][k]
	tip_z = el["z1"]
	tip_r = el["r1"]
	out.append(mv)


func _emit_raw(n: int, line: int, type: String, z1: float, r1: float, extra: Dictionary) -> void:
	var mv := { "n": n, "line": line, "type": type, "from": { "r": tip_r, "z": tip_z }, "to": { "r": r1, "z": z1 } }
	for k in extra:
		mv[k] = extra[k]
	tip_z = z1
	tip_r = r1
	out.append(mv)


func _err(el: Dictionary, code: String, text: String) -> void:
	errors.append({ "n": el.get("n", -1), "line": el.get("line", 0), "code": code, "text": text })


static func _dist(z0: float, r0: float, z1: float, r1: float) -> float:
	return sqrt((z1 - z0) * (z1 - z0) + (r1 - r0) * (r1 - r0))


## Número corto para los mensajes (3 decimales como mucho), con el toFixed de JavaScript.
static func _num(x: float) -> String:
	var s := Js.to_fixed(x, 3)
	if s.find(".") >= 0:
		s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
