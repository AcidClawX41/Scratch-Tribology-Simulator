## Control compatible con el Fagor 8055 T (core/taller/gcode*.gd): lector de bloques, intérprete, ciclos G68, G69,
## G81 y G82, programas de ejemplo y robustez. Las comprobaciones geométricas no reutilizan el motor de ciclos: el
## perfil se muestrea desde la pasada de acabado y la zona prohibida (perfil más creces) se calcula aparte.
extends "res://tests/case.gd"

const Gcode = preload("res://core/taller/gcode.gd")
const Dialects = preload("res://core/taller/gcode_dialects.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Rng = preload("res://core/shared/rng.gd")

const TYPES := ["rapid", "feed", "arc", "dwell", "tool", "spindle", "coolant", "end"]


func _run(text: String, options: Dictionary = {}) -> Dictionary:
	return Gcode.interpret_program(text, options)


func _codes(list: Array) -> Array:
	var out := []
	for e in list:
		out.append(e["code"])
	return out


func _motion(res: Dictionary) -> Array:
	var out := []
	for m in res["moves"]:
		if m["type"] in ["rapid", "feed", "arc"]:
			out.append(m)
	return out


## Pasadas de desbaste: avances horizontales hacia el plato que empiezan en la Z de llamada, con el avance de desbaste.
func _passes(res: Dictionary, n: int, z_call: float, f_rough: float) -> Array:
	var levels := []
	for m in res["moves"]:
		if m["n"] == n and m["type"] == "feed" and m["feed"]["value"] == f_rough and absf(m["from"]["z"] - z_call) < 1e-9 \
				and absf(m["from"]["r"] - m["to"]["r"]) < 1e-9 and m["to"]["z"] < m["from"]["z"]:
			levels.append(m["from"]["r"])
	return levels


## Puntos de un movimiento (rectas y arcos), cada ~step mm.
func _samples(m: Dictionary, step := 0.005) -> Array:
	var pts := []
	var fr: float = m["from"]["r"]
	var fz: float = m["from"]["z"]
	var tr: float = m["to"]["r"]
	var tz: float = m["to"]["z"]
	if m["type"] != "arc":
		var n := maxi(2, ceili(sqrt((tr - fr) * (tr - fr) + (tz - fz) * (tz - fz)) / step))
		for i in n + 1:
			var t := float(i) / float(n)
			pts.append([fz + t * (tz - fz), fr + t * (tr - fr)])
		return pts
	var cz: float = m["arc"]["center"]["z"]
	var cr: float = m["arc"]["center"]["r"]
	var rad := sqrt((fz - cz) * (fz - cz) + (fr - cr) * (fr - cr))
	var t0 := atan2(fr - cr, fz - cz)
	var sw := atan2(tr - cr, tz - cz) - t0
	if m["arc"]["cw"]:
		while sw >= 0.0:
			sw -= TAU
	else:
		while sw <= 0.0:
			sw += TAU
	var n := maxi(8, ceili(absf(sw) * rad / step))
	for i in n + 1:
		var th := t0 + sw * float(i) / float(n)
		pts.append([cz + rad * cos(th), cr + rad * sin(th)])
	return pts


## Tabla del perfil muestreado para consultar su radio: z de mayor a menor y el radio máximo acumulado.
func _r_table(prof: Array) -> Array:
	var pts := prof.duplicate()
	pts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var zs := PackedFloat64Array()
	var rmax := PackedFloat64Array()
	var best := -INF
	for p in pts:
		best = maxf(best, p[1])
		zs.append(p[0])
		rmax.append(best)
	return [zs, rmax]


## Radio del perfil justo a la derecha de z (perfil monótono: el radio crece hacia el plato). Un punto que está sobre
## la pared de un hombro cuenta como fuera de la pieza.
func _profile_r(table: Array, z: float) -> float:
	var zs: PackedFloat64Array = table[0]
	var lo := 0
	var hi := zs.size()  # primer índice con zs < z + 1e-6
	while lo < hi:
		var mid := (lo + hi) >> 1
		if zs[mid] >= z + 1e-6:
			lo = mid + 1
		else:
			hi = mid
	return -INF if lo == 0 else table[1][lo - 1]


## Muestras del perfil repartidas en casillas de 0.5 mm de Z, para medir distancias deprisa.
func _buckets(prof: Array) -> Dictionary:
	var out := {}
	for p in prof:
		var k := floori(p[0] / 0.5)
		if not out.has(k):
			out[k] = []
		out[k].append(p)
	return out


func _dist_to(buckets: Dictionary, z: float, r: float) -> float:
	var best := INF
	var k := floori(z / 0.5)
	for kk in range(k - 3, k + 4):
		for p in buckets.get(kk, []):
			best = minf(best, sqrt((p[0] - z) * (p[0] - z) + (p[1] - r) * (p[1] - r)))
	return best


## ¿Tiene la lista al menos n elementos? Si no, el test falla aquí (sin acceder a índices que no existen).
func _enough(list: Array, n: int, what: String) -> bool:
	assert_true(list.size() >= n, "%s: hay %d y hacen falta al menos %d" % [what, list.size(), n])
	return list.size() >= n


func _has_point(moves: Array, r: float, z: float, tol := 1e-6) -> int:
	for i in moves.size():
		var m: Dictionary = moves[i]
		if absf(m["to"]["r"] - r) <= tol and absf(m["to"]["z"] - z) <= tol:
			return i
	return -1


# ---------------------------------------------------------------------------------------------------------------

func test_lector_de_bloques() -> void:
	var text := "; programa de prueba\n\nN10 G1 X30.5 Z-2 F.2 ; comentario\nn20 g0 x 40 z - 1.25\nN30 (MSG \"hola\")\nN40 X\n"
	var p := Gcode.parse_program(text)
	var blocks: Array = p["blocks"]
	assert_eq(blocks.size(), 5, "la línea en blanco no es un bloque")
	assert_true(blocks[0]["empty"], "un bloque que empieza por «;» es un comentario")
	var b: Dictionary = blocks[1]
	assert_eq(b["n"], 10)
	assert_eq(b["line"], 3)
	assert_eq(b["comment"], "comentario")
	assert_eq(b["words"].size(), 4)
	assert_eq(b["words"][0]["letter"], "G")
	assert_eq(b["words"][0]["value"], 1.0)
	assert_eq(b["words"][1]["value"], 30.5)
	assert_eq(b["words"][2]["value"], -2.0)
	assert_eq(b["words"][3]["value"], 0.2, "F.2 es F0.2")
	var c: Dictionary = blocks[2]
	assert_eq(c["n"], 20, "minúsculas y espacios entre letra, signo y número (p. 31)")
	assert_eq(c["words"][2]["value"], -1.25)
	assert_true(_codes(p["warnings"]).has("lowercase"))
	assert_false(blocks[3]["ok"], "los paréntesis son lenguaje de alto nivel")
	assert_eq(p["errors"].size(), 1)
	if not _enough(p["errors"], 1, "errores"):
		return
	assert_eq(p["errors"][0]["line"], 5)
	assert_eq(p["errors"][0]["n"], 30)
	assert_true(str(p["errors"][0]["message"]).contains("no soportado en este simulador (fase 2)"))
	assert_false(blocks[4]["words"][0]["has_number"], "X sin número (vale X0)")
	assert_eq(_codes(Gcode.parse_program("N123456789 G1")["errors"]), ["bad_label"], "etiquetas de hasta 8 cifras")


func test_diametro_y_persistencia_modal() -> void:
	var res := _run("N10 G90 G94 G151\nN20 G00 X40 Z5\nN30 G01 Z-10 F100\nN40 X30\nN50 G91 X-4 Z-2\nN60 G152 X1\nN70 G90 X20\nN80 M30\n")
	assert_eq(res["errors"], [])
	var mv := _motion(res)
	if not _enough(mv, 6, "movimientos"):
		return
	assert_eq(mv[0]["to"], { "r": 20.0, "z": 5.0 }, "G151: X40 es un radio de 20 mm")
	assert_eq(mv[1]["type"], "feed")
	assert_eq(mv[2]["type"], "feed", "G01 es modal")
	assert_eq(mv[2]["to"], { "r": 15.0, "z": -10.0 }, "Z se mantiene y X30 es radio 15")
	assert_eq(mv[2]["feed"], { "mode": "mmmin", "value": 100.0 }, "F es modal")
	assert_eq(mv[3]["to"], { "r": 13.0, "z": -12.0 }, "G91 en diámetro: X-4 son 2 mm de radio")
	assert_eq(mv[4]["to"], { "r": 14.0, "z": -12.0 }, "G152: X en radio y G91 sigue activa")
	assert_eq(mv[5]["to"], { "r": 20.0, "z": -12.0 }, "G90 con G152: X20 es radio 20")
	var def := _run("N10 G00 X10 Z0\nN20 M30\n")
	assert_eq(_motion(def)[0]["to"], { "r": 5.0, "z": 0.0 }, "por defecto la máquina programa X en diámetro")


func test_arco_con_r_y_con_i_k() -> void:
	# ejemplo del manual (p. 83), con X en radios: desde X40 Z60, G03 X90 Z110 con R50 o con I50 K0
	var by_r := _run("N10 G152 G94 F100\nN20 G00 X40 Z60\nN30 G03 X90 Z110 R50\nN40 X40 Z160 R50\nN50 M30\n")
	var by_ik := _run("N10 G152 G94 F100\nN20 G00 X40 Z60\nN30 G03 X90 Z110 I50 K0\nN40 X40 Z160 I0 K50\nN50 M30\n")
	assert_eq(by_r["errors"], [])
	assert_eq(by_ik["errors"], [])
	var ar := _motion(by_r)
	var ai := _motion(by_ik)
	if not (_enough(ar, 3, "movimientos con R") and _enough(ai, 3, "movimientos con I, K")):
		return
	assert_false(ar[1]["arc"]["cw"], "G03 es antihorario con Z a la derecha y X hacia arriba")
	assert_near(ar[1]["arc"]["center"]["r"], 90.0, 1e-12, 0.0, "centro del manual: X90 Z60")
	assert_near(ar[1]["arc"]["center"]["z"], 60.0, 1e-12, 0.0)
	for i in [1, 2]:
		assert_near(ar[i]["arc"]["center"]["r"], ai[i]["arc"]["center"]["r"], 0.0, 1e-9, "centro con R = centro con I, K")
		assert_near(ar[i]["arc"]["center"]["z"], ai[i]["arc"]["center"]["z"], 0.0, 1e-9)
	assert_eq(ai[2]["arc"]["center"], { "r": 90.0, "z": 160.0 })
	# R negativo: el arco de más de 180° tiene el centro al otro lado de la cuerda
	var big := _motion(_run("N10 G152 G94 F100\nN20 G00 X0 Z0\nN30 G02 X0 Z-10 R-6\nN40 M30\n"))
	var small := _motion(_run("N10 G152 G94 F100\nN20 G00 X0 Z0\nN30 G02 X0 Z-10 R6\nN40 M30\n"))
	if _enough(big, 2, "arco R-") and _enough(small, 2, "arco R+"):
		assert_near(big[1]["arc"]["center"]["r"], -small[1]["arc"]["center"]["r"], 0.0, 1e-12, "R- y R+ son simétricos")
		assert_near(absf(small[1]["arc"]["center"]["r"]), sqrt(11.0), 0.0, 1e-12)
	# errores: radios que no cuadran, radio que no llega, R con I/K, arco sin centro
	var bad := "N10 G152 G94 F100\nN20 G00 X10 Z0\nN30 G02 X15 Z-5 I5 K1\nN40 G02 X15 Z-5 R2\nN50 G02 X15 Z-5 I5 R5\nN60 G02 X15 Z-5\nN70 M30\n"
	var e := _run(bad)
	assert_eq(_codes(e["errors"]), ["arc_radius_mismatch", "arc_impossible", "arc_r_and_ik", "arc_no_center"])
	if _enough(e["errors"], 1, "errores"):
		assert_eq(e["errors"][0]["n"], 30)
		assert_eq(e["errors"][0]["line"], 3)
	# dentro de CIRINERR (0.01 mm) el arco se acepta
	assert_eq(_run("N10 G152 G94 F100\nN20 G00 X10 Z0\nN30 G02 X15 Z-5 I5 K0.005\nN40 M30\n")["errors"], [])


func test_g96_con_g92_limita_las_rpm() -> void:
	var res := _run("N10 G90 G95 G151\nN20 G92 S2000\nN30 G96 S200 M3\nN40 G00 X10 Z2\nN50 G01 Z-20 F0.2\nN60 G00 X100\nN70 M30\n")
	assert_eq(res["errors"], [])
	var sp: Dictionary = {}
	for m in res["moves"]:
		if m["type"] == "spindle":
			sp = m["spindle"]
			break
	if sp.is_empty():
		fail("no hay movimiento de cabezal")
		return
	assert_eq(sp["dir"], "cw")
	assert_eq(sp["css"], { "vc": 200.0, "rpm_max": 2000.0 })
	assert_near(sp["rpm"], 1000.0 * 200.0 / (PI * 100.0), 1e-12, 0.0, "rpm en Ø100 (punto de partida)")
	# a Ø10, Vc 200 pide 6366 rpm: el tope G92 las deja en 2000 y el tiempo del G01 sale con 2000 rpm
	var only_feed := 0.0
	for m in res["moves"]:
		if m["type"] == "feed":
			only_feed += 22.0 / (0.2 * 2000.0) * 60.0
	var s: Dictionary = res["summary"]
	var rapid_t := 0.0
	for m in _motion(res):
		if m["type"] == "rapid":
			rapid_t += maxf(absf(m["to"]["r"] - m["from"]["r"]), absf(m["to"]["z"] - m["from"]["z"])) / 10000.0 * 60.0
	assert_near(s["time_s"], only_feed + rapid_t, 1e-9, 0.0, "tiempo con las rpm limitadas por G92 S")
	var sin_tope := _run("N10 G90 G95 G151\nN30 G96 S200 M3\nN40 G00 X10 Z2\nN50 G01 Z-20 F0.2\nN60 G00 X100\nN70 M30\n")
	assert_near(sin_tope["summary"]["time_s"], 22.0 / (0.2 * 4000.0) * 60.0 + rapid_t, 1e-9, 0.0, "sin G92, el tope es el de la máquina (4000 rpm)")
	# en G97, una S por encima del tope G92 no se acepta (p. 55)
	var over := _run("N10 G92 S1500\nN20 G97 S1800 M3\nN30 M30\n")
	assert_eq(_codes(over["errors"]), ["s_over_limit"])
	assert_eq(_codes(_run("N10 G96 M3\nN20 M30\n")["errors"]), ["g96_no_speed"], "G96 sin S ni velocidad anterior")


func test_g70_multiplica_por_25_4() -> void:
	var res := _run("N10 G90 G94 G151 G70\nN20 G01 X2 Z-1 F10\nN30 G71 X20\nN40 M30\n")
	assert_eq(res["errors"], [])
	var mv := _motion(res)
	if not _enough(mv, 2, "movimientos"):
		return
	assert_near(mv[0]["to"]["r"], 25.4, 1e-15, 0.0, "X2 pulgadas en diámetro = 25.4 mm de radio")
	assert_near(mv[0]["to"]["z"], -25.4, 1e-15, 0.0)
	assert_near(mv[0]["feed"]["value"], 254.0, 1e-15, 0.0, "F10 pulgadas/min = 254 mm/min")
	assert_eq(mv[1]["to"]["r"], 10.0, "G71 vuelve a milímetros")
	assert_eq(mv[1]["to"]["z"], -25.4)


func test_g04_temporiza_en_centesimas() -> void:
	var res := _run("N10 G04 K50\nN20 G4 K200\nN30 G04\nN40 M30\n")
	assert_eq(res["errors"], [])
	var d := []
	for m in res["moves"]:
		if m["type"] == "dwell":
			d.append(m["dwell_s"])
	assert_eq(d, [0.5, 2.0], "K en centésimas de segundo (p. 110)")
	assert_eq(res["summary"]["time_s"], 2.5)
	assert_true(_codes(res["warnings"]).has("g04_no_k"), "G04 sola solo detiene la preparación de bloques")
	assert_eq(_codes(_run("N10 G04 X1.5\nN20 M30\n")["errors"]), ["g04_alone"])


func test_g81_pasadas_iguales_de_paso_menor_o_igual_que_c() -> void:
	var text := "N10 G90 G95 G151\nN20 G97 S1000 M3\nN30 G00 X50 Z3 F0.3\nN40 G81 X30 Z0 Q30 R-25 C2.5 D1 L0.2 M0.1 F0.2 H0.1\nN50 M30\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var levels := _passes(res, 40, 3.0, 0.3)
	var depth := 25.0 - (15.0 + 0.2)
	assert_eq(levels.size(), ceili(depth / 2.5), "ceil(profundidad / C) pasadas")
	if not _enough(levels, 1, "pasadas"):
		return
	var step := depth / float(levels.size())
	for i in levels.size():
		assert_near(levels[i], 25.0 - step * float(i + 1), 1e-12, 1e-12, "pasada %d" % i)
	assert_true(step <= 2.5 + 1e-12, "todas iguales y no mayores que C")
	assert_near(levels[levels.size() - 1], 15.2, 1e-12, 0.0, "la última deja la demasía L")
	# cada pasada acaba en R + M y se retira a 45° la distancia D
	for m in res["moves"]:
		if m["type"] == "feed" and m["feed"]["value"] == 0.3 and m["from"]["z"] == 3.0:
			assert_near(m["to"]["z"], -24.9, 1e-12, 0.0)
	var finish := []
	for m in res["moves"]:
		if m["type"] == "feed" and m["feed"]["value"] == 0.1:
			finish.append(m)
	assert_true(_has_point(finish, 15.0, -25.0) >= 0, "el acabado llega al punto final (Q, R)")
	var last := {}
	for m in res["moves"]:
		if m["n"] == 40:
			last = m
	assert_eq(last.get("type"), "rapid")
	assert_eq(last.get("to"), { "r": 25.0, "z": 3.0 }, "el ciclo acaba en el punto de llamada")


func test_g82_refrentado_de_tramos_rectos() -> void:
	var res := _run("N10 G90 G95 G151\nN20 G97 S800 M3\nN30 G00 X64 Z5 F0.3\nN40 G82 X60 Z0 Q20 R3 C1.2 D1 M0.1\nN50 M30\n")
	assert_eq(res["errors"], [])
	var zs := []
	for m in res["moves"]:
		if m["type"] == "feed" and absf(m["from"]["r"] - 32.0) < 1e-9 and m["to"]["r"] < m["from"]["r"] and m["from"]["z"] == m["to"]["z"]:
			zs.append(m["from"]["z"])
	var depth := 5.0 - 0.1
	assert_eq(zs.size(), ceili(depth / 1.2), "pasadas de refrentado en Z")
	if not _enough(zs, 1, "pasadas"):
		return
	for i in zs.size():
		assert_near(zs[i], 5.0 - depth / float(zs.size()) * float(i + 1), 1e-12, 1e-12)
	# las pasadas bajan hasta el cono más la demasía M, y por debajo del punto B hasta Q
	for m in res["moves"]:
		if m["type"] == "feed" and m["from"]["z"] == m["to"]["z"] and absf(m["from"]["r"] - 32.0) < 1e-9:
			var z: float = m["to"]["z"]
			var want := 10.0 if z >= 3.1 - 1e-9 else 30.0 - 20.0 * (z - 0.1) / 3.0
			assert_near(m["to"]["r"], want, 1e-9, 1e-9, "fin de la pasada a Z%s" % z)


func test_g68_pasadas_perfil_y_acabado() -> void:
	var text: String = Programs.EXAMPLE_PROGRAMS["pieza_b"]["text"]
	var res := _run(text)
	assert_eq(res["errors"], [])
	var levels := _passes(res, 90, 2.0, 0.25)
	var start_off := 22.9835 / 2.0 + 0.3
	var depth := 22.0 - start_off
	assert_eq(levels.size(), ceili(depth / 2.0), "ceil(profundidad / C) pasadas")
	if not _enough(levels, 1, "pasadas"):
		return
	for i in levels.size() - 1:
		assert_near(levels[i], 22.0 - 2.0 * float(i + 1), 1e-12, 0.0, "pasadas de paso C")
	assert_near(levels[levels.size() - 1], start_off, 1e-12, 0.0, "la última quita el sobrante y deja L")
	# perfil muestreado desde la pasada de acabado (avance H = 0.1), sin su entrada ni su salida
	var block := []
	for m in res["moves"]:
		if m["n"] == 90:
			block.append(m)
	var fin := []
	var first_final := -1
	for i in block.size():
		var m: Dictionary = block[i]
		if m.has("feed") and m["feed"]["value"] == 0.1:
			fin.append(m)
		if first_final < 0 and m.has("feed") and m["feed"]["value"] == 0.2:
			first_final = i
	if not (_enough(fin, 3, "pasada de acabado") and _enough(block, 2, "movimientos del ciclo")):
		return
	assert_true(first_final > 0)
	var prof := []
	for i in range(1, fin.size() - 1):
		prof.append_array(_samples(fin[i]))
	var table := _r_table(prof)
	var z_start := 0.0
	var z_end := -45.0
	var bad := 0
	for i in first_final:
		for p in _samples(block[i], 0.02):
			var z: float = p[0] - 0.1
			if z > z_start + 1e-9:
				continue
			if z < z_end - 1e-9 or p[1] < _profile_r(table, z) + 0.3 - 2e-3:
				bad += 1
	assert_eq(bad, 0, "ningún movimiento de desbaste invade el perfil más las creces (L0.3 M0.1)")
	# acaba con la pasada de acabado: sus últimos avances siguen el perfil y luego vuelve al punto de llamada
	var tail: Dictionary = block[block.size() - 1]
	assert_eq(tail["type"], "rapid")
	assert_eq(tail["to"], { "r": 22.0, "z": 2.0 })
	var before: Dictionary = block[block.size() - 2]
	assert_eq(before["feed"]["value"], 0.1, "el último avance del ciclo es de acabado")


func test_g68_sin_m_demasia_constante() -> void:
	var text := "N10 G90 G95 G151\nN20 G97 S1000 M3\nN30 G00 X44 Z2 F0.3\nN40 G68 X20 Z0 C1.5 D0.5 L0.4 H0.1 S100 E150\nN50 M30\n" + \
		"N100 G01 X24 Z-2\nN110 Z-10\nN120 G03 X30 Z-13 R3\nN130 G01 Z-20\nN140 X36 Z-24\nN150 X40\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var levels := _passes(res, 40, 2.0, 0.3)
	var start_off := 10.0 + 0.4 / sqrt(2.0)  # chaflán a 45°: la demasía constante sube el inicio L·sen 45°
	assert_eq(levels.size(), ceili((22.0 - start_off) / 1.5))
	if not _enough(levels, 1, "pasadas"):
		return
	assert_near(levels[levels.size() - 1], start_off, 1e-12, 0.0)
	var fin := []
	var rough := []
	for m in res["moves"]:
		if m["n"] != 40 or not m.has("feed"):
			continue
		if m["feed"]["value"] == 0.1:
			fin.append(m)
		elif m["feed"]["value"] == 0.3:
			rough.append(m)
	var prof := []
	for i in range(1, fin.size() - 1):  # sin la entrada ni la salida de la pasada de acabado
		prof.append_array(_samples(fin[i], 0.01))
	var table := _r_table(prof)
	var buckets := _buckets(prof)
	var worst := INF
	var inside := 0
	for m in rough:
		for p in _samples(m, 0.05):
			if p[1] >= 10.0 and p[0] <= 0.0:
				worst = minf(worst, _dist_to(buckets, p[0], p[1]))
				if p[1] < _profile_r(table, p[0]) - 1e-9:
					inside += 1
	assert_eq(inside, 0, "nunca dentro de la pieza")
	assert_true(worst >= 0.4 - 2e-3, "sin M la demasía es constante: el desbaste queda a ≥ L del perfil (mínimo %s)" % worst)
	assert_true(worst <= 0.4 + 2e-3, "y la pasada llega hasta la demasía (mínimo %s)" % worst)


func test_g69_desbaste_en_z() -> void:
	var text := "N10 G90 G95 G151\nN20 G97 S600 M3\nN30 G00 X84 Z4 F0.3\nN40 G69 X80 Z-10 C2 D1 L0.2 M0.2 H0.1 S100 E130\nN50 M30\n" + \
		"N100 G01 X60 Z-10\nN110 Z-5\nN120 X40 Z0\nN130 X0\n"
	var res := _run(text)
	assert_eq(res["errors"], [])
	var zs := []
	for m in res["moves"]:
		if m["n"] == 40 and m["type"] == "feed" and m["feed"]["value"] == 0.3 and absf(m["from"]["r"] - 42.0) < 1e-9 and m["from"]["z"] == m["to"]["z"]:
			zs.append(m["from"]["z"])
	var depth := 4.0 - (-10.0 + 0.2)
	assert_eq(zs.size(), ceili(depth / 2.0), "pasadas verticales en Z con paso C")
	if _enough(zs, 1, "pasadas"):
		assert_near(zs[zs.size() - 1], -9.8, 1e-12, 0.0)
	var finish := []
	for m in res["moves"]:
		if m.has("feed") and m["feed"]["value"] == 0.1:
			finish.append(m)
	for v in [[30.0, -10.0], [30.0, -5.0], [20.0, 0.0], [0.0, 0.0]]:
		assert_true(_has_point(finish, v[0], v[1]) >= 0, "el acabado pasa por r=%s z=%s" % v)


func test_programas_a_y_b_sin_errores_y_con_las_cotas_del_plano() -> void:
	var a := _run(Programs.EXAMPLE_PROGRAMS["pieza_a"]["text"])
	assert_eq(a["errors"], [], "pieza A")
	# acabado de A: los avances con T3 (tabla de CONTRATOS.md: h9 18-30 → 0/-52 µm; h9 30-50 → 0/-62 µm)
	var t3 := false
	var fin := []
	for m in a["moves"]:
		if m["type"] == "tool":
			t3 = m["tool"]["id"] == "T3"
		elif t3 and m["type"] == "feed":
			fin.append(m)
	if not _enough(fin, 8, "acabado de la pieza A"):
		return
	var d30: float = 2.0 * fin[2]["to"]["r"]
	var d40: float = 2.0 * fin[4]["to"]["r"]
	assert_true(d30 >= 30.0 - 0.052 and d30 <= 30.0, "Ø30 h9: %s" % d30)
	assert_true(d40 >= 40.0 - 0.062 and d40 <= 40.0, "Ø40 h9: %s" % d40)
	var want_a := [[d30 / 2.0 - 1.0, 0.0], [d30 / 2.0, -1.0], [d30 / 2.0, -20.0], [d40 / 2.0, -20.0], [d40 / 2.0, -40.0], [23.0, -40.0], [23.0, -55.0], [26.0, -55.0]]
	var idx := -1
	for v in want_a:
		var j := _has_point(fin, v[0], v[1])
		assert_true(j > idx, "el acabado de A pasa por r=%s z=%s, en orden" % v)
		idx = j
	for m in fin:
		var straight: bool = m["from"]["r"] == m["to"]["r"] or m["from"]["z"] == m["to"]["z"] or absf(absf(m["to"]["r"] - m["from"]["r"]) - absf(m["to"]["z"] - m["from"]["z"])) < 1e-9
		assert_true(straight, "tramos del acabado de A: cilindros, caras o el chaflán a 45°")
	var b := _run(Programs.EXAMPLE_PROGRAMS["pieza_b"]["text"])
	assert_eq(b["errors"], [], "pieza B")
	var fb := []
	for m in b["moves"]:
		if m.has("feed") and m["feed"]["value"] == 0.1 and m["n"] == 90:
			fb.append(m)
	if not _enough(fb, 8, "acabado de la pieza B"):
		return
	var d24: float = 2.0 * fb[2]["to"]["r"]
	assert_true(d24 >= 24.0 - 0.033 and d24 <= 24.0, "Ø24 h8: %s" % d24)
	var want_b := [[d24 / 2.0 - 0.5, 0.0], [d24 / 2.0, -0.5], [d24 / 2.0, -13.0], [d24 / 2.0 + 2.0, -15.0], [18.0, -15.0], [18.0, -35.0], [19.0, -45.0]]
	idx = -1
	for v in want_b:
		var j := _has_point(fb, v[0], v[1])
		assert_true(j > idx, "el acabado de B pasa por r=%s z=%s, en orden" % v)
		idx = j
	var arc: Dictionary = fb[maxi(_has_point(fb, d24 / 2.0 + 2.0, -15.0), 0)]
	assert_eq(arc["type"], "arc")
	assert_true(arc["arc"]["cw"], "R2 cóncavo en el hombro: G02")
	assert_near(arc["arc"]["center"]["r"], d24 / 2.0 + 2.0, 1e-12, 0.0)
	assert_near(arc["arc"]["center"]["z"], -13.0, 1e-12, 0.0)
	for s in [a["summary"], b["summary"]]:
		assert_true(s["rapid_mm"] > 0.0 and s["feed_mm"] > 0.0, "recorridos")
		assert_true(s["time_s"] > 10.0 and s["time_s"] < 1200.0, "tiempo razonable: %s s" % s["time_s"])


func test_programa_con_tres_errores_didacticos() -> void:
	var prog: Dictionary = Programs.EXAMPLE_PROGRAMS["errores"]
	var res := _run(prog["text"])
	assert_eq(res["errors"].size(), 3, "exactamente los tres errores")
	if not (_enough(res["errors"], 3, "errores") and _enough(res["moves"], 1, "movimientos")):
		return
	var lines: PackedStringArray = str(prog["text"]).split("\n")
	for i in prog["errors"].size():
		var want: Dictionary = prog["errors"][i]
		var got: Dictionary = res["errors"][i]
		assert_eq(got["n"], want["n"])
		assert_eq(got["code"], want["code"])
		assert_true(lines[got["line"] - 1].begins_with("N%d " % want["n"]), "la línea del error es la del bloque N%d" % want["n"])
	assert_true(str(res["errors"][0]["message"]).contains("G92 S"), "la pista del G50 de Fanuc lleva a G92 S")
	assert_true(res["moves"].size() > 10, "el resto del programa se ejecuta")
	assert_eq(res["moves"][res["moves"].size() - 1]["type"], "end")


func test_errores_en_espanol_con_n_y_linea() -> void:
	var text := "N10 G90 G95\nN20 G05 X10\nN30 M06\nN40 X10 G01\nN50 G00 G01 X5\nN60 G71 U1 R0.5\nN70 T1 D1 M3 S100\n/N80 X1\nN90 G81 X10 Z0 Q10 R-5 C0\nN100 G68 X10 Z0 C1 S500 E600\nN110 G92 X0 Z0\n"
	var res := _run(text)
	var want := [[2, 20, "unsupported"], [3, 30, "unsupported"], [4, 40, "word_order"], [5, 50, "incompatible_g"], [6, 60, "unsupported"],
		[7, 70, "word_order"], [8, -1, "unsupported"], [9, 90, "cycle_param"], [10, 100, "label_missing"], [11, 110, "unsupported"]]
	assert_eq(res["errors"].size(), want.size())
	for i in mini(want.size(), res["errors"].size()):
		var e: Dictionary = res["errors"][i]
		assert_eq([e["line"], e["n"], e["code"]], want[i], "error %d" % i)
		var head := "Línea %d (N%d): " % [e["line"], e["n"]] if e["n"] >= 0 else "Línea %d: " % e["line"]
		assert_true(str(e["message"]).begins_with(head), "el mensaje empieza con la línea y el bloque: %s" % e["message"])
	if not _enough(res["errors"], 5, "errores"):
		return
	assert_true(str(res["errors"][0]["message"]).contains("no soportado en este simulador (fase 2)"))
	assert_true(str(res["errors"][0]["message"]).contains("Arista matada"), "explica qué es G05 en el 8055")
	assert_true(str(res["errors"][4]["message"]).contains("G68"), "G71 U de Fanuc: en el 8055 el desbaste es G68")
	assert_true(_codes(res["warnings"]).has("no_end"), "aviso: falta M30")
	# el G68 con parámetros P del 8025/8030 recibe una pista, en el lector y en el bloque del ciclo
	var p_form := _run("N10 G68 P0=K20 P1=K0 P5=K2 P13=K100 P14=K200\nN20 G68 P0\nN30 M30\n")
	assert_eq(_codes(p_form["errors"]), ["unsupported", "cycle_param"])
	for e in p_form["errors"]:
		assert_true(str(e["message"]).contains("8025/8030"), "pista: %s" % e["message"])


func test_mil_lineas_aleatorias_dan_errores_y_nunca_un_fallo() -> void:
	var rng := Rng.from_text("fagor8055t:ruido")
	var letters := "GXZIKRFSTDMNCDLQHEPUWY"
	var bits := ["G00", "G01", "G02", "G03", "G04 K", "G68", "G69", "G81", "G82", "G92 S", "G96", "G151", "G70", "M3", "M30",
		"(", ")", ";", "/", "=", "#", ".", "-", "+", "ñ", "Ø", "°", "\t", " ", "P1=", "S100 E200", "R-", "X.", "N"]
	var all := PackedStringArray()
	var total_errors := 0
	for i in 1000:
		var line := ""
		var n := int(rng.next() * 12.0)
		for k in n:
			var r: float = rng.next()
			if r < 0.45:
				line += letters[int(rng.next() * letters.length())]
				var digits := int(rng.next() * 14.0)
				if rng.next() < 0.3:
					line += "-"
				for d in digits:
					line += "0123456789."[int(rng.next() * 11.0)]
			elif r < 0.8:
				line += bits[int(rng.next() * bits.size())]
			else:
				line += String.chr(32 + int(rng.next() * 400.0))
			if rng.next() < 0.5:
				line += " "
		all.append(line)
		var res := Gcode.interpret_program(line)
		if not (res.has("moves") and res.has("errors") and res.has("warnings") and res.has("summary")):
			fail("línea %d: resultado incompleto" % i)
			continue
		for e in res["errors"] + res["warnings"]:
			if not (e.has("line") and e.has("n") and e.has("code") and str(e.get("message", "")).begins_with("Línea")):
				fail("línea %d: alarma mal formada %s" % [i, e])
		total_errors += res["errors"].size()
	assert_true(total_errors > 300, "el ruido da errores (%d)" % total_errors)
	var big := Gcode.interpret_program("\n".join(all))
	assert_true(big["errors"].size() > 300, "el programa entero también se lee hasta el final (%d errores)" % big["errors"].size())
	assert_true(is_finite(big["summary"]["time_s"]))


func test_regresiones_de_la_revision() -> void:
	# en G95 sin F previa, el desbaste va a F0 (mm/min) pero F y H del ciclo siguen siendo mm/rev
	var cyc := _run("N10 G90 G95 G151\nN20 G97 S1000 M3\nN30 G00 X50 Z3\nN40 G81 X30 Z0 Q30 R-25 C2.5 D1 L0.2 M0.1 F0.2 H0.1\nN50 M30\n")
	assert_eq(cyc["errors"], [])
	var modes := {}
	for m in cyc["moves"]:
		if m.has("feed"):
			modes[m["feed"]["value"]] = m["feed"]["mode"]
	assert_eq(modes.get(0.2), "mmrev", "pasada final de desbaste en mm/rev")
	assert_eq(modes.get(0.1), "mmrev", "pasada de acabado en mm/rev")
	assert_eq(modes.get(5000.0), "mmmin", "el desbaste a F0 va al avance máximo en mm/min")
	# G96 S0: el cabezal no gira (0 rpm), G97 sin S se queda en 0 y el avance por vuelta no puede avanzar
	var s0 := _run("N10 G90 G95 G151\nN20 G96 S0 M3\nN30 G00 X40 Z2\nN40 G97\nN50 G01 Z-10 F0.2\nN60 M30\n")
	for m in s0["moves"]:
		if m["type"] == "spindle" and m["spindle"]["dir"] != "stop":
			assert_eq(m["spindle"]["rpm"], 0.0, "con Vc 0 el cabezal está a 0 rpm")
	assert_eq(_codes(s0["errors"]), ["feed_per_rev_spindle_stopped"])
	# el aviso de bloques inalcanzables empieza en el M30 que de verdad terminó el programa
	var tail := _run("N10 G00 X100 M30 Q1\nN20 G00 X50\nN30 M30\nN40 G00 X10\n")
	var unreachable := []
	for w in tail["warnings"]:
		if w["code"] == "unreachable":
			unreachable.append(w["n"])
	assert_eq(unreachable, [40], "solo el bloque que sigue al M30 ejecutado")


func test_determinismo() -> void:
	for id in ["pieza_a", "pieza_b", "errores"]:
		var text: String = Programs.EXAMPLE_PROGRAMS[id]["text"]
		var a := _run(text)
		var b := _run(text)
		assert_true(same(a, b), "%s: el mismo programa da el mismo resultado" % id)
		assert_eq(JSON.stringify(a), JSON.stringify(b))


func test_ir_cumple_el_contrato() -> void:
	for id in ["pieza_a", "pieza_b"]:
		var res := _run(Programs.EXAMPLE_PROGRAMS[id]["text"])
		var prev := {}
		for m in res["moves"]:
			assert_true(m["type"] in TYPES, "tipo %s" % m["type"])
			assert_true(typeof(m["n"]) == TYPE_INT and typeof(m["line"]) == TYPE_INT)
			for k in ["from", "to"]:
				assert_true(typeof(m[k]["r"]) == TYPE_FLOAT and typeof(m[k]["z"]) == TYPE_FLOAT)
			if not prev.is_empty():
				assert_eq(m["from"], prev, "%s: el movimiento empieza donde acabó el anterior (N%d)" % [id, m["n"]])
			prev = m["to"]
			match m["type"]:
				"feed", "arc":
					assert_true(m["feed"]["mode"] in ["mmrev", "mmmin"] and m["feed"]["value"] > 0.0)
					if m["type"] == "arc":
						assert_true(typeof(m["arc"]["cw"]) == TYPE_BOOL and m["arc"]["center"].has("r") and m["arc"]["center"].has("z"))
				"spindle":
					assert_true(m["spindle"]["dir"] in ["cw", "ccw", "stop"] and m["spindle"].has("rpm") and m["spindle"].has("css"))
				"tool":
					assert_true(typeof(m["tool"]["id"]) == TYPE_STRING and typeof(m["tool"]["offset"]) == TYPE_INT)
				"coolant":
					assert_true(typeof(m["coolant"]) == TYPE_BOOL)
				"dwell":
					assert_true(m["dwell_s"] > 0.0)
		if _enough(res["moves"], 1, "movimientos"):
			assert_eq(res["moves"][res["moves"].size() - 1]["type"], "end")


func test_dialectos_fagor_y_contraste_fanuc() -> void:
	var fagor: Dictionary = Dialects.DIALECTS["fagor8055t"]["codes"]
	var fanuc: Dictionary = Dialects.DIALECTS["fanucT"]["codes"]
	assert_true(str(fagor["G70"]["meaning"]).contains("pulgadas"), "en el Fagor G70 son pulgadas")
	assert_true(str(fagor["G71"]["meaning"]).contains("milímetros"))
	assert_true(str(fanuc["G70"]["meaning"]).contains("Ciclo") and str(fanuc["G71"]["meaning"]).contains("Ciclo"), "en Fanuc G70/G71 son ciclos")
	assert_true(str(fanuc["G20"]["meaning"]).contains("pulgadas") and str(fanuc["G21"]["meaning"]).contains("milímetros"))
	assert_true(str(fanuc["G50"]["meaning"]).contains("tope"), "en Fanuc G50 limita las rpm")
	assert_true(str(fagor["G92"]["meaning"]).contains("velocidad"), "en el Fagor el tope es G92 S")
	assert_false(Dialects.DIALECTS["fanucT"]["executable"])
	var res := _run("N10 G71 G00 X10\nN20 M30\n", { "dialect": "fanucT" })
	assert_eq(_codes(res["errors"]), ["dialect_not_executable"])
	assert_eq(res["moves"], [])
	# todos los códigos del MVP tienen su página del manual
	for code in fagor:
		if fagor[code]["mvp"]:
			assert_true(int(fagor[code]["page"]) > 0, "%s con página" % code)
