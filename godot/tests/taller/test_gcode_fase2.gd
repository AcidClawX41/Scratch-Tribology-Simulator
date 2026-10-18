## Control compatible con el Fagor 8055 T, fase 2 (core/taller/gcode.gd, gcode_comp.gd y gcode_cycles.gd):
## compensación del radio de la punta G40/G41/G42, subrutinas y repeticiones, roscado G33 y ciclo G86.
## La geometría de la compensación se comprueba sin reutilizar el motor: el centro de la punta (punta teórica + v) no se
## mete nunca a menos de R del contorno programado y pasa a R de cada tramo (la circunferencia de la punta es tangente).
extends "res://tests/case.gd"

const Gcode = preload("res://core/taller/gcode.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")

const HEAD := "N10 G90 G95 G151\nN20 T1 D1\nN30 G97 S1000 M3\n"


func _run(text: String, options: Dictionary = {}) -> Dictionary:
	return Gcode.interpret_program(text, options)


func _codes(list: Array) -> Array:
	var out := []
	for e in list:
		out.append(e["code"])
	return out


func _enough(list: Array, n: int, what: String) -> bool:
	assert_true(list.size() >= n, "%s: hay %d y hacen falta al menos %d" % [what, list.size(), n])
	return list.size() >= n


func _offsets(r: float, f: int = 3) -> Dictionary:
	return { "offsets": { 1: { "r": r, "f": f } } }


func _by_type(res: Dictionary, type: String) -> Array:
	var out := []
	for m in res["moves"]:
		if m["type"] == type:
			out.append(m)
	return out


func _by_n(res: Dictionary, n: int) -> Array:
	var out := []
	for m in res["moves"]:
		if m["n"] == n:
			out.append(m)
	return out


static func _hyp(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


## Distancia de (z, r) a un elemento { kind: "line"|"arc", z0, r0, z1, r1, cz, cr, rad, cw } (en dobles: Vector2 es
## de precisión simple).
static func _dist_el(e: Dictionary, z: float, r: float) -> float:
	var z0: float = e["z0"]
	var r0: float = e["r0"]
	var z1: float = e["z1"]
	var r1: float = e["r1"]
	if e["kind"] == "line":
		var dz := z1 - z0
		var dr := r1 - r0
		var l2 := dz * dz + dr * dr
		var t := 0.0 if l2 < 1e-24 else clampf(((z - z0) * dz + (r - r0) * dr) / l2, 0.0, 1.0)
		return _hyp(z - (z0 + t * dz), r - (r0 + t * dr))
	var cz: float = e["cz"]
	var cr: float = e["cr"]
	var cw: bool = e["cw"]
	var a0 := atan2(r0 - cr, z0 - cz)
	var a1 := atan2(r1 - cr, z1 - cz)
	var a := atan2(r - cr, z - cz)
	var sweep := fposmod((a0 - a1) if cw else (a1 - a0), TAU)
	var t := fposmod((a0 - a) if cw else (a - a0), TAU)
	if t <= sweep + 1e-12:
		return absf(sqrt((z - cz) * (z - cz) + (r - cr) * (r - cr)) - float(e["rad"]))
	return minf(sqrt((z - z0) * (z - z0) + (r - r0) * (r - r0)), sqrt((z - z1) * (z - z1) + (r - r1) * (r - r1)))


## Movimiento compensado del IR → elemento recorrido por el centro de la punta (punta teórica + v).
static func _center_el(m: Dictionary) -> Dictionary:
	var vz: float = m["comp"]["vz"]
	var vr: float = m["comp"]["vr"]
	var e := { "kind": "line", "z0": float(m["from"]["z"]) + vz, "r0": float(m["from"]["r"]) + vr,
		"z1": float(m["to"]["z"]) + vz, "r1": float(m["to"]["r"]) + vr }
	if m["type"] == "arc":
		e["kind"] = "arc"
		e["cz"] = float(m["arc"]["center"]["z"]) + vz
		e["cr"] = float(m["arc"]["center"]["r"]) + vr
		e["cw"] = bool(m["arc"]["cw"])
		e["rad"] = _hyp(float(e["z0"]) - float(e["cz"]), float(e["r0"]) - float(e["cr"]))
	return e


## Puntos del elemento cada ~step mm.
static func _samples(e: Dictionary, step := 0.01) -> Array:
	var pts := []
	var z0: float = e["z0"]
	var r0: float = e["r0"]
	var z1: float = e["z1"]
	var r1: float = e["r1"]
	if e["kind"] == "line":
		var n := maxi(2, ceili(_hyp(z1 - z0, r1 - r0) / step))
		for i in n + 1:
			var t := float(i) / float(n)
			pts.append(PackedFloat64Array([z0 + t * (z1 - z0), r0 + t * (r1 - r0)]))
		return pts
	var cz: float = e["cz"]
	var cr: float = e["cr"]
	var rad: float = e["rad"]
	var a0 := atan2(r0 - cr, z0 - cz)
	var a1 := atan2(r1 - cr, z1 - cz)
	var sweep := fposmod((a0 - a1) if e["cw"] else (a1 - a0), TAU)
	var n := maxi(8, ceili(sweep * rad / step))
	for i in n + 1:
		var a := a0 + (-sweep if e["cw"] else sweep) * float(i) / float(n)
		pts.append(PackedFloat64Array([cz + rad * cos(a), cr + rad * sin(a)]))
	return pts


## Punto medio de un elemento programado y su normal hacia el lado de la herramienta (G42: a la derecha del avance).
static func _mid_offset(e: Dictionary, rad: float, side: int) -> PackedFloat64Array:
	var sgn := 1.0 if side == 42 else -1.0
	if e["kind"] == "line":
		var dz := float(e["z1"]) - float(e["z0"])
		var dr := float(e["r1"]) - float(e["r0"])
		var l := _hyp(dz, dr)
		var mz := 0.5 * (float(e["z0"]) + float(e["z1"]))
		var mr := 0.5 * (float(e["r0"]) + float(e["r1"]))
		return PackedFloat64Array([mz + rad * sgn * dr / l, mr - rad * sgn * dz / l])
	var cz: float = e["cz"]
	var cr: float = e["cr"]
	var a0 := atan2(float(e["r0"]) - cr, float(e["z0"]) - cz)
	var a1 := atan2(float(e["r1"]) - cr, float(e["z1"]) - cz)
	var sweep := fposmod((a0 - a1) if e["cw"] else (a1 - a0), TAU)
	var am := a0 + (-0.5 * sweep if e["cw"] else 0.5 * sweep)
	var uz := cos(am)
	var ur := sin(am)
	var tz := ur if e["cw"] else -ur  # tangente en el sentido del arco
	var tr := -uz if e["cw"] else uz
	var nz := sgn * tr  # normal hacia el lado de la herramienta
	var nr := -sgn * tz
	var big: float = e["rad"]
	return PackedFloat64Array([cz + big * uz + rad * nz, cr + big * ur + rad * nr])


## Comprueba que el centro de la punta nunca se acerca a menos de rad del contorno y que pasa a rad del punto medio
## de cada tramo. Devuelve el número de movimientos compensados.
func _check_offset_path(res: Dictionary, contour: Array, rad: float, side: int, what: String) -> int:
	var centers := []
	for m in res["moves"]:
		if m.has("comp"):
			centers.append(_center_el(m))
	var worst := INF
	for c in centers:
		for p in _samples(c):
			var d := INF
			for e in contour:
				d = minf(d, _dist_el(e, p[0], p[1]))
			worst = minf(worst, d)
	assert_true(worst >= rad - 1e-7, "%s: el centro de la punta no se mete a menos de R = %s del contorno (mínimo %s)" % [what, _Js.js_num_str(rad), _Js.js_num_str(worst)])
	for i in contour.size():
		var q := _mid_offset(contour[i], rad, side)
		var best := INF
		for c in centers:
			best = minf(best, _dist_el(c, q[0], q[1]))
		assert_true(best < 1e-7, "%s: la punta es tangente al tramo %d del contorno (el centro pasa a %s de su perpendicular)" % [what, i, _Js.js_num_str(best)])
	return centers.size()


# ---------------------------------------------------------------------------------------------------------------
# Compensación del radio de la punta
# ---------------------------------------------------------------------------------------------------------------

## Ejemplo del manual de programación (ed. española Ref. 9806, cap. 8, p. 14): mecanizado en diámetros con G42.
func test_g42_ejemplo_del_manual_el_centro_de_la_punta_va_a_r_del_contorno() -> void:
	var text := "N10 G90 G95 G151\nN15 G97 S500 M3\nN20 G00 X240 Z220 T1 D1\nN30 G42 G01 X0 Z200 F0.2\nN40 G03 X60 Z170 I0 K-30\nN50 G01 Z120\nN60 G02 X120 Z90 I30 K0\nN70 G01 X160\nN80 X200 Z60\nN90 Z30\nN100 G40 G00 X240 Z220\nN110 M30\n"
	var contour := [
		{ "kind": "arc", "z0": 200.0, "r0": 0.0, "z1": 170.0, "r1": 30.0, "cz": 170.0, "cr": 0.0, "rad": 30.0, "cw": false },
		{ "kind": "line", "z0": 170.0, "r0": 30.0, "z1": 120.0, "r1": 30.0 },
		{ "kind": "arc", "z0": 120.0, "r0": 30.0, "z1": 90.0, "r1": 60.0, "cz": 120.0, "cr": 60.0, "rad": 30.0, "cw": true },
		{ "kind": "line", "z0": 90.0, "r0": 60.0, "z1": 90.0, "r1": 80.0 },
		{ "kind": "line", "z0": 90.0, "r0": 80.0, "z1": 60.0, "r1": 100.0 },
		{ "kind": "line", "z0": 60.0, "r0": 100.0, "z1": 30.0, "r1": 100.0 },
	]
	for rad in [0.4, 2.0]:
		var res := _run(text, _offsets(rad))
		assert_eq(res["errors"], [], "sin errores con R%s" % _Js.js_num_str(rad))
		var n := _check_offset_path(res, contour, rad, 42, "R%s" % _Js.js_num_str(rad))
		assert_true(n >= 6, "movimientos compensados: %d" % n)
		# F3: la punta teórica es el centro − (R, R); el IR lo dice en cada movimiento compensado
		for m in res["moves"]:
			if m.has("comp"):
				assert_eq([m["comp"]["side"], m["comp"]["f"], m["comp"]["vz"], m["comp"]["vr"]], ["G42", 3, rad, rad], "datos de la compensación en el IR")
		# el primer tramo empieza en la perpendicular del arco en su punto inicial (esquina cóncava de entrada, p. 135)
		var lead: Dictionary = _by_n(res, 30)[0]
		assert_near(lead["to"]["z"] + rad, 200.0 + rad, 1e-12, 1e-12, "entrada: el centro acaba en Z200 + R")
		assert_near(lead["to"]["r"] + rad, 0.0, 1e-12, 1e-12, "entrada: el centro acaba en el eje")
		# el G00 con G40 sale sin compensar hasta la cota programada
		var out: Array = _by_n(res, 100)
		assert_eq(out.size(), 1)
		assert_eq(out[0]["type"], "rapid")
		assert_eq([out[0]["to"]["z"], out[0]["to"]["r"]], [220.0, 120.0])
		assert_false(out[0].has("comp"), "la retirada en G00 no se compensa")


## Sin tabla de correctores (o con R0) la compensación no desplaza nada: la trayectoria es la de sin G42 (p. 133).
func test_g42_con_r0_no_desplaza_y_avisa() -> void:
	var plain := HEAD + "N40 G00 X20 Z2\nN50 G01 Z0 F0.1\nN60 X27.974\nN70 X29.974 Z-1\nN80 Z-20\nN90 X52\nN100 G00 X100 Z100\nN110 M30\n"
	var comp := HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 X27.974\nN70 X29.974 Z-1\nN80 Z-20\nN90 G40 X52\nN100 G00 X100 Z100\nN110 M30\n"
	var a := _run(plain)
	var b := _run(comp)
	assert_eq(b["errors"], [])
	assert_true(_codes(b["warnings"]).has("comp_r0"), "aviso: G42 con R0")
	assert_eq(a["moves"].size(), b["moves"].size())
	for i in mini(a["moves"].size(), b["moves"].size()):
		assert_eq([b["moves"][i]["from"], b["moves"][i]["to"]], [a["moves"][i]["from"], a["moves"][i]["to"]], "movimiento %d" % i)
	assert_true(_codes(a["warnings"]).has("profile_no_comp"), "sin G42, el chaflán avisa del error del radio de la punta")
	assert_false(_codes(b["warnings"]).has("profile_no_comp"))


## Chaflán 1×45° con la plaquita de rε 0,4 (el acabado de la pieza A): en el IR la punta teórica sigue el contorno
## desplazado; en el chaflán, la diagonal de la punta teórica queda rε·(√2 − 1) por dentro, en perpendicular, para que
## el redondeo de la punta sea tangente al chaflán programado.
func test_g42_chaflan_a_45_grados() -> void:
	var text := HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 X27.974\nN70 X29.974 Z-1\nN80 Z-20\nN90 G40 X52\nN100 G00 X100 Z100\nN110 M30\n"
	var re := 0.4
	var res := _run(text, _offsets(re))
	assert_eq(res["errors"], [])
	var contour := [
		{ "kind": "line", "z0": 0.0, "r0": 10.0, "z1": 0.0, "r1": 13.987 },
		{ "kind": "line", "z0": 0.0, "r0": 13.987, "z1": -1.0, "r1": 14.987 },
		{ "kind": "line", "z0": -1.0, "r0": 14.987, "z1": -20.0, "r1": 14.987 },
	]
	_check_offset_path(res, contour, re, 42, "chaflán")
	var ch: Array = _by_n(res, 70)
	if not _enough(ch, 1, "tramos del chaflán"):
		return
	var m: Dictionary = ch[0]
	assert_near(m["to"]["r"] - m["from"]["r"], -(m["to"]["z"] - m["from"]["z"]), 1e-12, 1e-12, "el chaflán compensado sigue a 45°")
	# la recta de la punta teórica: r = 13.987 − z + c, con c = −(2 − √2)·rε (con F3, la punta es el centro − (rε, rε))
	var c: float = m["from"]["r"] + m["from"]["z"] - 13.987
	assert_near(c, -(2.0 - sqrt(2.0)) * re, 1e-9, 1e-12, "desplazamiento de la punta teórica en el chaflán")
	# el cilindro Ø29.974 lo recorre la punta teórica en su cota: con F3 el desplazamiento vertical se anula
	for mv in _by_n(res, 80):
		if mv["type"] == "feed" and absf(mv["from"]["r"] - mv["to"]["r"]) < 1e-12:
			assert_near(mv["to"]["r"], 14.987, 1e-12, 1e-12, "Ø29.974: la punta teórica en la cota del cilindro")


## COMPMODE (P175, p. 154): esquinas convexas en escuadra (0 y 2) o con arco (1); más allá de 120° de giro, arco.
func test_esquinas_convexas_segun_compmode() -> void:
	var text := HEAD + "N40 G00 X10 Z2\nN50 G42 G01 Z0 F0.1\nN60 X20\nN70 Z-10\nN80 G40 X40\nN90 M30\n"
	var re := 0.8
	for mode in [0, 1, 2]:
		var opts := _offsets(re)
		opts["machine"] = { "compmode": mode }
		var res := _run(text, opts)
		assert_eq(res["errors"], [], "COMPMODE %d" % mode)
		var arcs := 0
		var corner := false
		for m in res["moves"]:
			if m.has("comp") and m["type"] == "arc":
				arcs += 1
			# la punta teórica pasa por la arista (Z0, X20) en la esquina en escuadra: centro en (R, 10 + R)
			if m.has("comp") and absf(m["to"]["z"]) < 1e-9 and absf(m["to"]["r"] - 10.0) < 1e-9:
				corner = true
		assert_eq(arcs, 1 if mode == 1 else 0, "COMPMODE %d: arcos en la esquina de 90°" % mode)
		assert_eq(corner, mode != 1, "COMPMODE %d: esquina en escuadra" % mode)
	# giro de 100°: con 0 las prolongaciones se quedan en R y se unen con una cuerda; con 2, la intersección
	var sharp := HEAD + "N40 G00 X10 Z2\nN50 G42 G01 Z0 F0.1\nN60 X20\nN80 X16.47329 Z-10\nN90 G40 X40\nN100 M30\n"
	var reach := []
	for mode in [0, 2]:
		var opts := _offsets(re)
		opts["machine"] = { "compmode": mode }
		var res := _run(sharp, opts)
		assert_eq(res["errors"], [], "COMPMODE %d con giro de 100°" % mode)
		var far := 0.0
		for m in res["moves"]:
			if m.has("comp"):
				var d := _hyp(float(m["to"]["z"]) + re, float(m["to"]["r"]) + re - 10.0)
				if d < 2.0:
					far = maxf(far, d)
		reach.append(far)
	if reach.size() == 2:
		var turn := deg_to_rad(180.0 - rad_to_deg(atan2(10.0, 1.763355)))
		assert_true(reach[0] < reach[1] - 1e-3, "COMPMODE 0 recorta la esquina (%s) y 2 va a la intersección (%s)" % reach)
		assert_near(reach[1], re / cos(turn / 2.0), 1e-6, 0.0, "COMPMODE 2: intersección a R/cos(giro/2) del vértice")


## COMPTYPE (P74, p. 119): al empezar en una esquina convexa, 0 bordea la esquina y 1 va directo a la perpendicular.
func test_inicio_segun_comptype() -> void:
	# entrada hacia arriba y primer tramo hacia el plato: esquina convexa para G42
	var text := HEAD + "N40 G00 X10 Z0\nN50 G42 G01 X20 F0.1\nN60 Z-10\nN70 G40 X40\nN80 M30\n"
	var re := 0.8
	var ends := []
	for ctype in [0, 1]:
		var opts := _offsets(re)
		opts["machine"] = { "comptype": ctype }
		var res := _run(text, opts)
		assert_eq(res["errors"], [])
		var lead: Array = _by_n(res, 50)
		if not _enough(lead, 1, "entrada"):
			return
		ends.append(PackedFloat64Array([float(lead[0]["to"]["z"]) + re, float(lead[0]["to"]["r"]) + re]))
	if ends.size() == 2:
		# COMPTYPE 0: la entrada acaba en su propia perpendicular (a la derecha de subir: +Z) y luego rodea la esquina
		assert_near(ends[0][0], re, 1e-12, 1e-12, "COMPTYPE 0: perpendicular de la entrada (Z = R)")
		assert_near(ends[0][1], 10.0, 1e-12, 1e-12)
		# COMPTYPE 1: directamente a la perpendicular del primer tramo en su inicio (encima de la arista)
		assert_near(ends[1][0], 0.0, 1e-12, 1e-12, "COMPTYPE 1: perpendicular del primer tramo (Z0)")
		assert_near(ends[1][1], 10.0 + re, 1e-12, 1e-12)


## G00 en medio anula temporalmente la compensación (p. 142): acaba en la perpendicular y el G01 siguiente entra de nuevo.
func test_g00_anula_temporalmente() -> void:
	var text := HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z-10 F0.1\nN60 G00 X30\nN70 G01 Z-20\nN80 X40\nN90 G40 G00 X60\nN100 M30\n"
	var re := 0.4
	var res := _run(text, _offsets(re))
	assert_eq(res["errors"], [])
	var rap: Array = _by_n(res, 60)
	assert_eq(rap.size(), 1)
	if rap.size() == 1:
		assert_false(rap[0].has("comp"), "el G00 va sin compensar")
		assert_eq([rap[0]["to"]["z"], rap[0]["to"]["r"]], [-10.0, 15.0], "a la cota programada")
	# el G01 N70 es una entrada: su final depende del tramo siguiente (N80, esquina cóncava → perpendicular de N80)
	var lead: Array = _by_n(res, 70)
	assert_true(lead.size() >= 1 and lead[0].has("comp"), "tras el G00, el G01 vuelve a compensar")


## Errores de la compensación con el número de bloque y la línea.
func test_errores_de_la_compensacion() -> void:
	var cases := [
		[HEAD + "N40 G00 X20 Z2\nN50 G42 G02 X22 Z0 R2\nN60 M30\n", 5, 50, "comp_arc"],
		[HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 G41 X30\nN70 M30\n", 6, 60, "unsupported"],
		[HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 T2 D2\nN70 M30\n", 6, 60, "unsupported"],
		[HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 G33 Z-10 L1\nN70 M30\n", 6, 60, "unsupported"],
		[HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 G81 X20 Z0 Q20 R-5 C1\nN70 M30\n", 6, 60, "unsupported"],
	]
	for c in cases:
		var res := _run(c[0], _offsets(0.4))
		var hit := false
		for e in res["errors"]:
			if e["line"] == c[1] and e["n"] == c[2] and e["code"] == c[3]:
				hit = true
				assert_true(str(e["message"]).begins_with("Línea %d (N%d): " % [c[1], c[2]]), "mensaje con línea y bloque")
		assert_true(hit, "%s en la línea %d: %s" % [c[3], c[1], JSON.stringify(res["errors"])])
	# una ranura de 0,5 mm con rε 0,8: entre las dos esquinas cóncavas, el fondo compensado iría al revés
	var short := _run(HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 Z-10\nN70 X18\nN80 Z-10.5\nN90 X20\nN100 Z-20\nN110 G40 X40\nN120 M30\n", _offsets(0.8))
	var hit_short := false
	for e in short["errors"]:
		if e["code"] == "comp_short" and e["n"] == 80 and e["line"] == 8:
			hit_short = true
	assert_true(hit_short, "fondo de ranura más estrecho que 2·rε: %s" % JSON.stringify(short["errors"]))
	# el radio de la punta no cabe en un arco cóncavo más pequeño
	var small := _run(HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 Z-10\nN70 G02 X21 Z-10.5 R0.5\nN80 G01 X30\nN90 G40 X40\nN100 M30\n", _offsets(0.8))
	assert_true(_codes(small["errors"]).has("comp_radius"), "R0.5 cóncavo con rε 0,8: %s" % JSON.stringify(_codes(small["errors"])))
	# M30 con la compensación activa la anula con un aviso
	var open := _run(HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 Z-10\nN70 M30\n", _offsets(0.4))
	assert_eq(open["errors"], [])
	assert_true(_codes(open["warnings"]).has("comp_cancelled"))


## G41 por dentro del sentido contrario da el mismo recorrido del centro que G42 (la herramienta sigue fuera).
func test_g41_en_sentido_contrario() -> void:
	var g42 := _run(HEAD + "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 X30\nN70 Z-20\nN80 X40\nN90 G40 G00 X60\nN100 M30\n", _offsets(0.8))
	var g41 := _run(HEAD + "N40 G00 X60 Z-20\nN50 G41 G01 X40 F0.1\nN60 X30\nN70 Z0\nN80 X20\nN90 G40 G00 X20 Z2\nN100 M30\n", _offsets(0.8))
	assert_eq(g42["errors"], [])
	assert_eq(g41["errors"], [])
	var contour := [
		{ "kind": "line", "z0": 0.0, "r0": 10.0, "z1": 0.0, "r1": 15.0 },
		{ "kind": "line", "z0": 0.0, "r0": 15.0, "z1": -20.0, "r1": 15.0 },
		{ "kind": "line", "z0": -20.0, "r0": 15.0, "z1": -20.0, "r1": 20.0 },
	]
	_check_offset_path(g42, contour, 0.8, 42, "G42")
	var rev := []
	for i in range(contour.size() - 1, -1, -1):
		var e: Dictionary = contour[i]
		rev.append({ "kind": "line", "z0": e["z1"], "r0": e["r1"], "z1": e["z0"], "r1": e["r0"] })
	_check_offset_path(g41, rev, 0.8, 41, "G41")


# ---------------------------------------------------------------------------------------------------------------
# Subrutinas, repeticiones y saltos (capítulo 12)
# ---------------------------------------------------------------------------------------------------------------

func test_subrutinas_call_y_ret() -> void:
	var text := HEAD + "N40 G00 X40 Z2\nN50 (CALL 1)\nN60 G00 X50\nN70 (CALL 1)\nN80 M30\n; subrutina detrás del M30, como en el ejemplo del manual (p. 292)\nN90 (SUB 1)\nN100 G91 G01 Z-5 F0.2\nN110 G90 G00 Z2\nN120 (RET)\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var cuts := []
	for m in _by_n(res, 100):
		cuts.append([m["from"]["r"], m["from"]["z"], m["to"]["z"]])
	assert_eq(cuts, [[20.0, 2.0, -3.0], [25.0, 2.0, -3.0]], "la subrutina se ejecuta dos veces, cada una desde donde se llama")
	assert_false(_codes(res["warnings"]).has("unreachable"), "los bloques de la subrutina no son inalcanzables")
	assert_eq(res["moves"][res["moves"].size() - 1]["type"], "end")


func test_rpt_repite_un_tramo_n_veces() -> void:
	var text := HEAD + "N40 G00 X40 Z2\nN50 G91 G01 X-2 F0.2\nN60 Z-5\nN70 G00 Z5\nN80 (RPT N50, N70) N3\nN90 G90 G00 X100 Z100\nN100 M30\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var levels := []
	for m in _by_n(res, 60):
		levels.append(m["from"]["r"])
	assert_eq(levels, [19.0, 18.0, 17.0, 16.0], "una vez al pasar y tres más con (RPT) N3")
	var after: Array = _by_n(res, 90)
	assert_eq(after.size(), 1, "sigue en el bloque siguiente al RPT")
	# N0: el tramo no se repite
	var zero := _run(HEAD + "N40 G00 X40 Z2\nN50 G01 Z-5 F0.2\nN60 G00 Z2\nN70 (RPT N50, N60) N0\nN80 M30\n")
	assert_true(_codes(zero["warnings"]).has("rpt_zero"))
	assert_eq(_by_n(zero, 50).size(), 1)


func test_rpt_mantiene_la_compensacion() -> void:
	# el manual: RPT no interrumpe la preparación de bloques ni la compensación (p. 289)
	var body := "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 (RPT N200, N220)\nN70 G40 G00 X80\nN80 M30\nN200 G01 X30\nN210 Z-20\nN220 X40\n"
	var flat := "N40 G00 X20 Z2\nN50 G42 G01 Z0 F0.1\nN60 G01 X30\nN70 Z-20\nN80 X40\nN90 G40 G00 X80\nN100 M30\n"
	var a := _run(HEAD + body, _offsets(0.8))
	var b := _run(HEAD + flat, _offsets(0.8))
	assert_eq(a["errors"], [])
	var pa := []
	var pb := []
	for m in a["moves"]:
		if m.has("comp"):
			pa.append([m["to"]["z"], m["to"]["r"]])
	for m in b["moves"]:
		if m.has("comp"):
			pb.append([m["to"]["z"], m["to"]["r"]])
	assert_eq(pa, pb, "el perfil repetido con (RPT) se compensa igual que escrito en línea")


func test_goto_salta() -> void:
	var res := _run(HEAD + "N40 G00 X40 Z2\nN50 (GOTO N80)\nN60 G01 X30 F0.2\nN70 X20\nN80 G01 Z-5 F0.2\nN90 M30\n")
	assert_eq(res["errors"], [])
	assert_eq(_by_n(res, 60).size() + _by_n(res, 70).size(), 0, "N60 y N70 no se ejecutan")
	assert_eq(_by_n(res, 80).size(), 1)
	# un salto sin fin se corta con un error, no cuelga el intérprete
	var loop := _run("N10 G00 X10\nN20 (GOTO N10)\n")
	assert_true(_codes(loop["errors"]).has("program_too_long"), "salto sin fin: %s" % JSON.stringify(_codes(loop["errors"])))


func test_errores_de_subrutinas_con_n_y_linea() -> void:
	var cases := [
		["N10 (CALL 7)\nN20 M30\n", 1, 10, "sub_missing"],
		["N10 (RET)\nN20 M30\n", 1, 10, "ret_without_call"],
		["N10 (SUB 3)\nN20 G00 X10\nN30 (RET)\nN40 M30\n", 1, 10, "sub_in_flow"],
		["N10 M30\nN20 (SUB 3)\nN30 G00 X10\nN40 (RET)\nN50 (SUB 3)\nN60 (RET)\n", 5, 50, "sub_duplicate"],
		["N10 M30\nN20 (SUB 4)\nN30 G00 X10\n", 2, 20, "sub_no_ret"],
		["N10 (RPT N50, N60)\nN20 M30\n", 1, 10, "label_missing"],
		["N10 G00 X10\nN20 (RPT N10, N30)\nN30 M30\n", 2, 20, "rpt_self"],
		["N10 (SUB 12000)\nN20 M30\n", 1, 10, "unsupported"],
		["N10 (PCALL 1, A2)\nN20 M30\n", 1, 10, "unsupported"],
		["N10 (P100 = 3)\nN20 M30\n", 1, 10, "unsupported"],
		["N10 G00 X10 (CALL 1)\nN20 M30\n", 1, 10, "hl_mixed"],
		["N10 (CALL 1) X10\nN20 M30\n", 1, 10, "hl_mixed"],
		["N10 (CALL 1\nN20 M30\n", 1, 10, "hl_syntax"],
		["N10 (FOO)\nN20 M30\n", 1, 10, "hl_syntax"],
	]
	for c in cases:
		var res := _run(c[0])
		var hit := false
		for e in res["errors"]:
			if e["line"] == c[1] and e["n"] == c[2] and e["code"] == c[3]:
				hit = true
				assert_true(str(e["message"]).begins_with("Línea %d (N%d): " % [c[1], c[2]]), "mensaje con línea y bloque")
		assert_true(hit, "%s: %s" % [c[3], JSON.stringify(res["errors"])])


func test_anidamiento_de_15_niveles() -> void:
	# una subrutina que se llama a sí misma: el nivel 16 da error (manual, p. 292) y el programa sigue
	var rec := _run("N10 G00 X10 Z10\nN20 (CALL 1)\nN30 M30\nN40 (SUB 1)\nN50 G91 G00 Z-1\nN60 (CALL 1)\nN70 (RET)\n")
	var nest := []
	for e in rec["errors"]:
		if e["code"] == "nesting":
			nest.append([e["line"], e["n"]])
	assert_eq(nest, [[6, 60]], "un solo error de anidamiento, en el CALL del nivel 16")
	assert_eq(_by_n(rec, 50).size(), 15, "15 niveles ejecutan el movimiento")
	assert_eq(rec["moves"][rec["moves"].size() - 1]["type"], "end", "tras el error, los RET deshacen la pila y llega al M30")
	# 15 niveles exactos no dan error
	var text := "N10 G00 X10 Z0\nN100 (CALL 1)\nN200 M30\n"
	var subs := ""
	for k in range(1, 16):
		subs += "N%d (SUB %d)\n" % [1000 + 10 * k, k]
		if k < 15:
			subs += "N%d (CALL %d)\n" % [1001 + 10 * k, k + 1]
		else:
			subs += "N%d G91 G00 Z-1\n" % [1001 + 10 * k]
		subs += "N%d (RET)\n" % [1002 + 10 * k]
	var deep := _run(text + subs)
	assert_eq(_codes(deep["errors"]), [], "15 niveles caben")
	assert_eq(_by_n(deep, 1151).size(), 1, "el nivel 15 se ejecuta")


# ---------------------------------------------------------------------------------------------------------------
# Roscado G33 y ciclo G86
# ---------------------------------------------------------------------------------------------------------------

func test_g33_roscado_electronico() -> void:
	var text := "N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G00 X19 Z5\nN40 G33 Z-20 L2.5\nN50 G33 X22 Z-22 L2.5\nN60 G00 X30\nN70 Z5\nN80 M30\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var th := _by_type(res, "thread")
	if not _enough(th, 2, "tramos de roscado"):
		return
	var a: Dictionary = th[0]
	assert_eq([a["n"], a["feed"]["mode"], a["feed"]["value"], a["pass"]], [40, "mmrev", 2.5, 4], "paso L2.5 por vuelta")
	assert_eq([a["thread"]["pitch"], a["thread"]["sync"], a["thread"]["start_deg"], a["thread"]["kind"]], [2.5, true, 0.0, "G33"])
	# el segundo G33 seguido sigue la misma hélice: no espera al cabezal; su paso L va en Z
	var b: Dictionary = th[1]
	assert_false(b["thread"]["sync"], "G33 encadenado: sin sincronizar de nuevo")
	assert_near(b["feed"]["value"], 2.5 * sqrt(1.5 * 1.5 + 2.0 * 2.0) / 2.0, 1e-12, 0.0, "en un cono, el avance sobre la trayectoria da L por vuelta en Z")
	# tiempo: 25 mm de rosca a 2,5 mm/vuelta y 500 rpm son 1,2 s
	var t_one := Gcode.summarize([{ "type": "spindle", "spindle": { "dir": "cw", "rpm": 500.0, "css": null } }, a])
	assert_near(t_one["time_s"], 25.0 / (2.5 * 500.0) * 60.0, 1e-9, 0.0)
	# errores
	var e1 := _run("N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G00 X19 Z5\nN40 G33 Z-20\nN50 M30\n")
	assert_eq(_codes(e1["errors"]), ["g33_no_pitch"])
	var e2 := _run("N10 G90 G95 G151\nN20 G00 X19 Z5\nN30 G33 Z-20 L2\nN40 M30\n")
	assert_eq(_codes(e2["errors"]), ["feed_per_rev_spindle_stopped"])
	var e3 := _run("N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G01 X19 Z5 L2 F0.1\nN40 M30\n")
	assert_eq(_codes(e3["errors"]), ["unsupported"], "L solo va con G33")
	var e4 := _run("N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G00 X19 Z5\nN40 G33 Z-20 L2 Q400\nN50 M30\n")
	assert_eq(_codes(e4["errors"]), ["format"], "Q de ±359.9999")


## M20×2,5 como en la pieza C: I = h3 = 0,6134·P (ISO 68-1), B y E del manual (p. 188).
func test_g86_pasadas_de_profundidad_y_penetracion_por_el_flanco() -> void:
	var text := "N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G00 X30 Z10\nN40 G86 X20 Z5 Q20 R-20 I1.534 B0.35 E0.05 D1 L0.05 C2.5 J0 A30\nN50 G00 X100 Z100\nN60 M30\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var passes := {}
	for m in _by_n(res, 40):
		if m["type"] == "thread":
			var k: int = m["thread"]["pass"]
			if not passes.has(k):
				passes[k] = m
	var n := passes.size()
	assert_true(n >= 10 and n <= 25, "número de pasadas razonable para P2,5: %d" % n)
	var prev := 0.0
	var depths := []
	for k in range(1, n + 1):
		if not passes.has(k):
			fail("falta la pasada %d" % k)
			return
		var m: Dictionary = passes[k]
		var d: float = m["thread"]["depth"]
		depths.append(d)
		assert_eq(m["thread"]["passes"], n)
		assert_true(m["thread"]["sync"], "cada pasada empieza sincronizada con el cabezal")
		assert_near(m["from"]["r"], 10.0 - d, 1e-12, 1e-12, "pasada %d a la profundidad" % k)
		# penetración por el flanco a 30°: la pasada empieza desplazada −d·tan 30° hacia el plato
		if k < n:
			assert_near(m["from"]["z"], 5.0 - d * tan(deg_to_rad(30.0)), 1e-12, 1e-12, "pasada %d desplazada por el flanco" % k)
			var want: float = 0.35 * sqrt(float(k))
			if k < n - 1:
				assert_true(d >= prev + 0.05 - 1e-12, "incremento de al menos E = 0,05 (pasada %d)" % k)
				assert_true(absf(d - maxf(want, prev + 0.05)) < 1e-12, "B·√n o E (pasada %d: %s)" % [k, _Js.js_num_str(d)])
		prev = d
	assert_near(depths[n - 2], 1.534 - 0.05, 1e-12, 0.0, "la última de desbaste llega a I − L")
	assert_near(depths[n - 1], 1.534, 1e-12, 0.0, "la de acabado, a I")
	# el ciclo acaba en el punto de aproximación (Z, X + D)
	var last: Dictionary = _by_n(res, 40)[-1]
	assert_eq([last["to"]["z"], last["to"]["r"]], [5.0, 11.0], "fin en el punto de aproximación")
	# las pasadas van a paso 2,5 mm/vuelta, con los rápidos de entrada y salida
	for m in _by_n(res, 40):
		if m["type"] == "thread":
			assert_near(m["feed"]["value"], 2.5, 1e-12, 0.0)
			assert_eq(m["pass"], 4)


func test_g86_acabado_salida_y_errores() -> void:
	var base := "N10 G90 G95 G151\nN20 G97 S500 M3\nN30 G00 X30 Z10\n"
	# L negativa: acabado radial desde la última pasada (p. 188)
	var rad := _run(base + "N40 G86 X20 Z5 Q20 R-20 I1 B-0.25 D1 L-0.1 C2 A30\nN50 M30\n")
	assert_eq(rad["errors"], [])
	var firsts := []
	for m in _by_n(rad, 40):
		if m["type"] == "thread" and m["thread"]["sync"]:
			firsts.append(m)
	if _enough(firsts, 3, "pasadas"):
		var depths := []
		for m in firsts:
			depths.append(m["thread"]["depth"])
		assert_eq(depths.slice(0, 3), [0.25, 0.5, 0.75], "B negativa: pasadas iguales de |B|")
		var fin: Dictionary = firsts[-1]
		var pre: Dictionary = firsts[-2]
		assert_near(fin["from"]["z"], pre["from"]["z"], 1e-12, 1e-12, "acabado radial: misma Z que la última de desbaste")
		assert_eq(fin["thread"]["infeed_deg"], 0.0)
	# J positiva: salida en diagonal hasta la distancia de seguridad; J negativa: al final (R, Q) y luego en X
	var jp := _run(base + "N40 G86 X20 Z5 Q20 R-20 I1 B0.5 D1 L0 C2 J3 A0\nN50 M30\n")
	var jn := _run(base + "N40 G86 X20 Z5 Q20 R-20 I1 B0.5 D1 L0 C2 J-3 A0\nN50 M30\n")
	assert_eq(jp["errors"] + jn["errors"], [])
	var exit_p := []
	for m in _by_n(jp, 40):
		if m["type"] == "thread" and not m["thread"]["sync"]:
			exit_p.append(m)
	if _enough(exit_p, 1, "salidas J > 0"):
		assert_near(exit_p[0]["from"]["z"], -17.0, 1e-12, 1e-12, "J3: la salida empieza 3 mm antes del final")
		assert_eq([exit_p[0]["to"]["z"], exit_p[0]["to"]["r"]], [-20.0, 11.0], "J3: en diagonal hasta (R, Q + D)")
	var exit_n := []
	for m in _by_n(jn, 40):
		if m["type"] == "thread" and not m["thread"]["sync"]:
			exit_n.append(m)
	if _enough(exit_n, 1, "salidas J < 0"):
		assert_eq([exit_n[0]["to"]["z"], exit_n[0]["to"]["r"]], [-20.0, 10.0], "J-3: hasta el final de la rosca (R, Q)")
	# errores con su página
	var cases := [
		["N40 G86 X20 Z5 Q20 R-20 I0 B0.3 C2\n", "cycle_param"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0 C2\n", "cycle_param"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0.3 C0\n", "cycle_param"],
		["N40 G86 X20 Z5 Q20 R-20 I-1 B0.3 C2\n", "unsupported"],
		["N40 G86 X20 Z5 Q20 R-20 K-10 I1 B0.3 C2 W30\n", "unsupported"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0.3 C2 A-30\n", "unsupported"],
		["N40 G86 X20 Z-20 Q20 R5 I1 B0.3 C2\n", "unsupported"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0.3 L1.2 C2\n", "cycle_param"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0.3 C2 J30\n", "cycle_param"],
		["N40 G86 X20 Z5 Q20 R-20 I1 B0.3\n", "cycle_param"],
		["N40 G87 X20 Z5 Q20 R-20 I1 B0.3 C2\n", "unsupported"],
	]
	for c in cases:
		var res := _run(base + c[0] + "N50 M30\n")
		assert_eq(_codes(res["errors"]), [c[1]], c[0])
	var stopped := _run("N10 G90 G95 G151\nN20 G00 X30 Z10\nN30 G86 X20 Z5 Q20 R-20 I1 B0.3 C2\nN40 M30\n")
	assert_eq(_codes(stopped["errors"]), ["feed_per_rev_spindle_stopped"], "G86 con el cabezal parado")


func test_programas_nuevos_cumplen_el_contrato() -> void:
	for id in ["pieza_a_g42", "pieza_b_g42", "pieza_c"]:
		if not Programs.EXAMPLE_PROGRAMS.has(id):
			fail("falta el programa %s" % id)
			continue
		var prog: Dictionary = Programs.EXAMPLE_PROGRAMS[id]
		var res := _run(prog["text"], Programs.options(id))
		assert_eq(res["errors"], [], "%s sin errores" % id)
		var prev := {}
		for m in res["moves"]:
			assert_true(m["type"] in ["rapid", "feed", "arc", "thread", "dwell", "tool", "spindle", "coolant", "end"], "tipo %s" % m["type"])
			if not prev.is_empty():
				assert_eq(m["from"], prev, "%s: el movimiento empieza donde acabó el anterior (N%d)" % [id, m["n"]])
			prev = m["to"]
			if m["type"] == "thread":
				assert_true(m["feed"]["mode"] == "mmrev" and m["feed"]["value"] > 0.0 and m["pass"] == 4)
				for k in ["pitch", "start_deg", "sync", "pass", "passes", "depth", "total", "kind", "infeed_deg"]:
					assert_true(m["thread"].has(k), "%s: thread.%s" % [id, k])
			if m.has("comp"):
				for k in ["side", "r", "f", "vz", "vr"]:
					assert_true(m["comp"].has(k), "%s: comp.%s" % [id, k])
		var a := _run(prog["text"], Programs.options(id))
		assert_eq(JSON.stringify(a), JSON.stringify(res), "%s: determinista" % id)
