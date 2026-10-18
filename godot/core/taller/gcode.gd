## Taller · control compatible con el Fagor 8055 T: lector de bloques e intérprete (código G → trayectoria).
##
## Lee programas del CNC Fagor 8055 T / 8055i T y los convierte en el movimiento intermedio (IR) de CONTRATOS.md,
## que consume el torno. La sintaxis y la semántica salen del manual de programación de Fagor Automation (páginas
## en gcode_dialects.gd y fuentes en docs/taller/fuentes-u4.md y docs/taller/fagor-fase2.md):
## - Bloque: etiqueta N (opcional) + palabras en el orden G, cotas, F, S, T, D, M (p. 59) + «;» comentario (p. 34).
## - X en diámetro (G151, por defecto en esta máquina) o en radio (G152); I y K, siempre en radio (p. 80).
## - G70/G71 son pulgadas y milímetros, no ciclos; los ciclos de desbaste son G68/G69 (gcode_cycles.gd).
## - G92 S limita las rpm de G96; G04 K espera en centésimas de segundo.
## - Fase 2: compensación del radio de la punta G40/G41/G42 (gcode_comp.gd, p. 128-146), roscado electrónico G33
##   (p. 92), ciclo de roscado longitudinal G86 (p. 187), subrutinas (SUB)/(RET)/(CALL) y repeticiones (RPT) (p. 289-294).
## Lo que el simulador todavía no hace da un error «no soportado en este simulador (fase 2)» con el número de bloque
## y la línea. Un bloque con errores no se ejecuta, pero el programa sigue: ninguna entrada rompe el intérprete.
##
## API:
##   parse_program(text, dialect) → { blocks: [{ n, line, words, comment, hl?, … }], errors, warnings }
##   interpret_program(text, { dialect, tools, offsets, machine, start }) → { moves, errors, warnings, summary }
##   summarize(moves, machine) → { rapid_mm, feed_mm, time_s }
##   turret_options(turret) → { tools, offsets }: las tablas de herramientas y de correctores de una torreta
## Errores y avisos: { line, n, code, message }, con el mensaje en español.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Dialects = preload("res://core/taller/gcode_dialects.gd")
const Cycles = preload("res://core/taller/gcode_cycles.gd")
const Comp = preload("res://core/taller/gcode_comp.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")

const INCH := 25.4  # mm por pulgada (G70, p. 39)
const FOOT_M := 0.3048  # m por pie: en pulgadas, la S de G96 va en pies/min (p. 65)
const EPS := 1e-6
const MAX_MOVES := 100000  # tope de movimientos de un programa (protege de pasos absurdos)
const MAX_LINES := 50000
const MAX_EXEC := 100000  # tope de bloques ejecutados (subrutinas, repeticiones y saltos sin fin)
const MAX_NEST := 15  # niveles de anidamiento de subrutinas (manual, 12.5, p. 292)
const MAX_REPEAT := 9999  # repeticiones de un nivel (p. 292) y de un bloque (N0-9999, p. 34)
const PHASE2 := "no soportado en este simulador (fase 2)"

## Máquina simulada. Son los valores por defecto de los parámetros máquina del 8055 (manual de instalación
## Ref. 1006), salvo el formato del eje X, que en casi todos los tornos se pone en diámetros.
const MACHINE := {
	"rapid_mm_min": 10000.0,  # G00FEED (P38): avance en G00, por defecto 10000 mm/min (p. 173)
	"max_feed_mm_min": 5000.0,  # MAXFEED (P42): avance máximo programable, que es también F0 (p. 173)
	"max_rpm": 4000.0,  # MAXGEAR4 (P5) por defecto; el cabezal simulado no tiene gamas (p. 195)
	"cirinerr_mm": 0.01,  # CIRINERR (P20): diferencia máxima entre los radios de un arco (p. 111)
	"diameter": true,  # DFORMAT del eje X en diámetros: G151 al encender
	"inches": false,  # INCHES (P8) = 0: G71 al encender (p. 108)
	"imove": "G00",  # IMOVE (P9) = 0 (p. 108)
	"isystem": "G90",  # ISYSTEM (P13) = 0 (p. 109)
	"ifeed": "G94",  # IFEED (P14) = 0 (p. 109)
	"comptype": 0,  # COMPTYPE (P74), unidades: 0 = al empezar y acabar la compensación bordea la esquina (p. 119)
	"compmode": 0,  # COMPMODE (P175) = 0: esquinas con tramos rectos hasta 300° entre trayectorias (p. 154)
}
## Posición inicial de la punta por defecto (X100 Z100 en diámetro).
const START := { "r": 50.0, "z": 100.0 }

## Orden de las palabras en un bloque ISO (p. 59): funciones G, cotas, centro o radio del arco, paso y ángulo de G33
## (L y Q, p. 92), F, S, T, D y M.
const ORDER := { "G": 0, "X": 1, "Z": 2, "I": 3, "K": 4, "R": 5, "L": 6, "Q": 7, "F": 8, "S": 9, "T": 10, "D": 11, "M": 12 }
const ORDER_TEXT := "funciones G, X, Z, I y K (o R), L y Q (en G33), F, S, T, D y M"
## Parámetros de los ciclos, en el orden de la «estructura básica del bloque» del manual (p. 154, 161, 168, 172 y 187).
const CYCLE_WORDS := {
	"G81": ["X", "Z", "Q", "R", "C", "D", "L", "M", "F", "H"],
	"G82": ["X", "Z", "Q", "R", "C", "D", "L", "M", "F", "H"],
	"G68": ["X", "Z", "C", "D", "L", "M", "K", "F", "H", "S", "E", "Q"],
	"G69": ["X", "Z", "C", "D", "L", "M", "K", "F", "H", "S", "E", "Q"],
	"G86": ["X", "Z", "Q", "R", "K", "I", "B", "E", "D", "L", "C", "J", "A", "W", "V", "M", "H", "U"],
	"G87": ["X", "Z", "Q", "R", "K", "I", "B", "E", "D", "L", "C", "J", "A", "W", "V", "M", "H", "U"],
}
## Funciones G del simulador y su grupo: dos del mismo grupo en un bloque son incompatibles.
const G_GROUP := {
	0: "motion", 1: "motion", 2: "motion", 3: "motion", 33: "motion", 4: "dwell", 70: "units", 71: "units",
	90: "abs", 91: "abs", 92: "g92", 94: "feed", 95: "feed", 96: "css", 97: "css", 151: "diam", 152: "diam",
	40: "comp", 41: "comp", 42: "comp",
	68: "cycle", 69: "cycle", 81: "cycle", 82: "cycle", 86: "cycle", 87: "cycle",
}
const M_SUPPORTED := [2, 3, 4, 5, 8, 9, 30]
## Instrucciones de alto nivel (capítulo 12) que el simulador no ejecuta, con lo que son.
const HL_PHASE2 := {
	"MSG": "mensaje en la pantalla del CNC (p. 287)",
	"PCALL": "llamada a subrutina con parámetros locales (p. 293)",
	"MCALL": "subrutina modal (p. 294)",
	"MDOFF": "fin de la subrutina modal (p. 294)",
	"IF": "instrucción condicional (p. 289)",
	"ERROR": "instrucción de error (p. 287)",
	"EXEC": "ejecución de otro programa (p. 297)",
	"MEXEC": "ejecución modal de otro programa (p. 297)",
	"OPEN": "edición de un programa (p. 297)",
	"WRITE": "escritura de bloques (p. 298)",
	"ESBLK": "bloque único (p. 288)",
	"DSBLK": "bloque único (p. 288)",
	"ESTOP": "habilitación de la tecla de parada (p. 288)",
	"DSTOP": "inhibición de la tecla de parada (p. 288)",
	"EFHOLD": "habilitación de la retención de avance (p. 288)",
	"DFHOLD": "inhibición de la retención de avance (p. 288)",
	"DGWZ": "zona gráfica (p. 287)",
	"PROBE": "ciclo de palpación (p. 295)",
	"REPOS": "reposición tras una interrupción (p. 296)",
}

# ----- estado del intérprete (una instancia por programa) -----
var mach: Dictionary = {}
var tools: Dictionary = {}
var offsets: Dictionary = {}
var has_offsets := false
var blocks: Array = []
var moves: Array = []
var errors: Array = []
var warnings: Array = []
var used_blocks := {}  # índices de los bloques ejecutados o leídos como perfil de un ciclo
var warned := {}  # avisos que se dan una sola vez por programa
var motion := "G00"
var absolute := true
var inches := false
var per_rev := false
var diameter := true
var css := false
var css_vc := -1.0  # última S de G96 (m/min); -1 si todavía no hay
var rpm := 0.0  # S de G97 (rpm)
var rpm_limit := -1.0  # G92 S; -1 si no se ha programado
var spindle := "stop"
var feed := 0.0  # F en mm/min o mm/rev; 0 es F0 (avance máximo)
var tool_id := ""
var tool_offset := 0
var coolant := false
var pos_r := 0.0  # posición programada (sin compensar)
var pos_z := 0.0
var ended := false
var comp_side := 0  # compensación activa: 0 (G40), 41 o 42
var comp: Comp
var pc := 0  # siguiente bloque que se ejecuta
var stack: Array = []  # niveles de subrutina ({ kind: "call" }) y de repetición ({ kind: "rpt" })
var subs := {}  # número de subrutina → índice del bloque (SUB n)
var sub_end := {}  # índice del bloque (SUB n) → índice de su (RET)


# ===============================================================================================================
# API
# ===============================================================================================================

## Lee el texto de un programa en bloques. Un bloque es una línea; las líneas en blanco se saltan y las que empiezan
## por «;» son bloques de comentario (empty = true). Cada palabra: { letter, value, text, col, int_digits,
## dec_digits, has_number, negative }. Un bloque con errores de sintaxis lleva ok = false. Un bloque de alto nivel,
## «(instrucción)», lleva hl = { op, … } y repeat (el número de repeticiones N del final del bloque, o -1).
static func parse_program(text: String, dialect: String = "fagor8055t") -> Dictionary:
	var out := { "blocks": [], "errors": [], "warnings": [] }
	if not Dialects.DIALECTS.has(dialect):
		out["errors"].append(_alarm(0, -1, "dialect", "dialecto desconocido «%s»; el simulador ejecuta fagor8055t." % dialect))
		return out
	var lines := text.split("\n")
	var lower := false
	for i in lines.size():
		if i >= MAX_LINES:
			out["errors"].append(_alarm(i + 1, -1, "program_too_long", "el programa pasa de %d líneas; el resto no se lee." % MAX_LINES))
			break
		var res := _parse_line(lines[i], i + 1)
		if res["block"] != null:
			out["blocks"].append(res["block"])
		out["errors"].append_array(res["errors"])
		if res["lower"] and not lower:
			lower = true
			out["warnings"].append(_alarm(i + 1, -1, "lowercase", "el 8055 escribe los programas en mayúsculas; las minúsculas se leen como mayúsculas."))
	return out


## Interpreta un programa y devuelve la trayectoria. options (todas opcionales):
## - dialect: "fagor8055t" (el único ejecutable; "fanucT" es solo de contraste).
## - tools: { "T1": { "offset": 1 }, … } tabla de herramientas: el corrector asociado a cada T.
## - offsets: { 1: { "r": 0.8, "f": 3 }, … } tabla de correctores (D): radio R de la punta y código de forma F
##   (manual, 8.2.3, p. 133). Sin ella, la compensación toma D0 (R0 F0) y no desplaza la trayectoria.
## - machine: claves de MACHINE que se quieran cambiar (también comptype y compmode).
## - start: { r, z } posición inicial de la punta (mm, r en radio).
static func interpret_program(text: String, options: Dictionary = {}) -> Dictionary:
	var it = load("res://core/taller/gcode.gd").new()
	return it._run(text, options)


## Tablas de herramientas y de correctores de una torreta { "1": id de lathe_tools.gd, … }: T1 lleva el corrector D1
## con el radio de la punta de su plaquita y su código de forma (F3 en las de torneado exterior, F62 en la de roscar).
static func turret_options(turret: Dictionary) -> Dictionary:
	var t := {}
	var o := {}
	for k in turret:
		var num := str(k).trim_prefix("T").to_int()
		var tool := LatheTools.tool(str(turret[k]))
		if tool.is_empty():
			continue
		t["T%d" % num] = { "offset": num }
		o[num] = { "r": float(tool["re_mm"]), "f": int(tool.get("location", 3)), "tool": str(turret[k]) }
	return { "tools": t, "offsets": o }


## Recorrido en rápido y en avance (mm) y tiempo estimado (s) de una trayectoria. Los rápidos van a G00FEED en el
## eje que más recorre; en mm/rev, las rpm salen de cada movimiento de cabezal del IR (con G96 se recalculan con el
## radio y se limitan con el tope de G92 S o de la máquina).
static func summarize(path: Array, machine: Dictionary = {}) -> Dictionary:
	var m := _machine(machine)
	var rapid_mm := 0.0
	var feed_mm := 0.0
	var t := 0.0
	var sp := { "dir": "stop", "rpm": 0.0, "css": null }
	for mv in path:
		match str(mv.get("type", "")):
			"spindle":
				sp = mv["spindle"]
			"dwell":
				t += float(mv["dwell_s"])
			"rapid":
				var dr: float = mv["to"]["r"] - mv["from"]["r"]
				var dz: float = mv["to"]["z"] - mv["from"]["z"]
				rapid_mm += sqrt(dr * dr + dz * dz)
				t += maxf(absf(dr), absf(dz)) / float(m["rapid_mm_min"]) * 60.0
			"feed", "arc", "thread":
				var seg := _feed_segment(mv, sp, m)
				feed_mm += seg[0]
				t += seg[1]
	return { "rapid_mm": rapid_mm, "feed_mm": feed_mm, "time_s": t }


## Centro de un arco del plano ZX, en (z, r). cw es G02. Con R (use_r, radius): positivo si el arco es menor de 180°
## y negativo si es mayor (p. 82). Con I, K (i_off, k_off): centro respecto al punto inicial, en radios (p. 80); si
## los radios del inicio y del final difieren más que tol (CIRINERR), error. Devuelve { ok, cz, cr, rad } o
## { ok: false, code, text }.
static func arc_center(z0: float, r0: float, z1: float, r1: float, cw: bool, use_r: bool, radius: float, i_off: float,
		k_off: float, tol: float) -> Dictionary:
	var dz := z1 - z0
	var dr := r1 - r0
	var d := sqrt(dz * dz + dr * dr)
	if d < EPS:
		return { "ok": false, "code": "arc_full_circle", "text": "el arco empieza y acaba en el mismo punto: una circunferencia completa no tiene sentido en el torno (%s)." % PHASE2 }
	if use_r:
		var ar := absf(radius)
		if ar < EPS:
			return { "ok": false, "code": "arc_impossible", "text": "R0 no es un radio de arco." }
		if d > 2.0 * ar + tol:
			return { "ok": false, "code": "arc_impossible", "text": "arco imposible: los extremos están a %s mm, más que el diámetro 2R = %s mm." % [_num(d), _num(2.0 * ar)] }
		var h := sqrt(maxf(ar * ar - d * d / 4.0, 0.0))
		var nz := dr / d  # normal a la derecha de la cuerda en el plano (Z, radio)
		var nr := -dz / d
		var sgn := 1.0 if cw == (radius > 0.0) else -1.0
		return { "ok": true, "cz": (z0 + z1) / 2.0 + sgn * h * nz, "cr": (r0 + r1) / 2.0 + sgn * h * nr, "rad": ar }
	var cz := z0 + k_off
	var cr := r0 + i_off
	var ra := sqrt((z0 - cz) * (z0 - cz) + (r0 - cr) * (r0 - cr))
	var rb := sqrt((z1 - cz) * (z1 - cz) + (r1 - cr) * (r1 - cr))
	if ra < EPS:
		return { "ok": false, "code": "arc_no_center", "text": "arco sin centro: falta I y K (o R), o el centro cae en el punto inicial." }
	if absf(ra - rb) > tol:
		return { "ok": false, "code": "arc_radius_mismatch", "text": "los radios del arco no cuadran: %s mm al inicio y %s mm al final (CIRINERR admite %s mm)." % [_num(ra), _num(rb), _num(tol)] }
	return { "ok": true, "cz": cz, "cr": cr, "rad": ra }


# ===============================================================================================================
# Lector de bloques
# ===============================================================================================================

static func _parse_line(raw: String, line_no: int) -> Dictionary:
	var src := raw.replace("\r", "")
	var out := { "block": null, "errors": [], "lower": false }
	var comment := ""
	var code := src
	var semi := src.find(";")
	if semi >= 0:
		comment = src.substr(semi + 1).strip_edges()
		code = src.substr(0, semi)
	if code.strip_edges() == "" and semi < 0:
		return out  # línea en blanco: no es un bloque
	var blk := { "n": -1, "line": line_no, "words": [], "comment": comment, "text": src, "empty": false, "ok": true }
	out["block"] = blk
	if code.strip_edges() == "":
		blk["empty"] = true  # bloque de comentario: no se ejecuta (p. 34)
		return out
	var i := 0
	var size := code.length()
	var first := true
	while i < size:
		var c := code.unicode_at(i)
		if c == 32 or c == 9:
			i += 1
			continue
		if c == 47:
			out["errors"].append(_alarm(line_no, blk["n"], "unsupported", "la condición de salto de bloque «/» está %s." % PHASE2))
			blk["ok"] = false
			return out
		if c == 40:
			if not blk["words"].is_empty():
				out["errors"].append(_alarm(line_no, blk["n"], "hl_mixed", "una instrucción de alto nivel «( )» va sola en su bloque: no admite funciones ISO (manual, cap. 12, p. 285). Los comentarios van detrás de «;»."))
				blk["ok"] = false
				return out
			_parse_hl(code, i, blk, out)
			return out
		if c == 61:
			out["errors"].append(_alarm(line_no, blk["n"], "unsupported", "«=»: las asignaciones a parámetros (P0=K…) son del lenguaje de alto nivel, %s. Si es un ciclo G68 o G69 al estilo del Fagor 8025/8030, en el 8055 se programa con letras: G68 X Z C D L M K F H S E Q." % PHASE2))
			blk["ok"] = false
			return out
		var up := c
		if c >= 97 and c <= 122:
			up = c - 32
			out["lower"] = true
		if up < 65 or up > 90:
			out["errors"].append(_alarm(line_no, blk["n"], "bad_char", "carácter no válido «%s» en la columna %d." % [String.chr(c), i + 1]))
			blk["ok"] = false
			return out
		var letter := String.chr(up)
		var col := i + 1
		i = _skip_spaces(code, i + 1)
		var negative := false
		var has_sign := false
		if i < size and (code.unicode_at(i) == 43 or code.unicode_at(i) == 45):
			has_sign = true
			negative = code.unicode_at(i) == 45
			i = _skip_spaces(code, i + 1)
		var int_s := ""
		var dec_s := ""
		var has_point := false
		while i < size and _is_digit(code.unicode_at(i)):
			int_s += String.chr(code.unicode_at(i))
			i += 1
		if i < size and code.unicode_at(i) == 46:
			has_point = true
			i += 1
			while i < size and _is_digit(code.unicode_at(i)):
				dec_s += String.chr(code.unicode_at(i))
				i += 1
		var has_num := int_s != "" or dec_s != ""
		if (has_sign or has_point) and not has_num:
			out["errors"].append(_alarm(line_no, blk["n"], "bad_number", "número mal formado detrás de %s (columna %d)." % [letter, col]))
			blk["ok"] = false
			return out
		var int_sig := int_s.lstrip("0")
		if int_sig.length() > 9 or dec_s.length() > 9:
			out["errors"].append(_alarm(line_no, blk["n"], "bad_number", "número demasiado largo detrás de %s (columna %d)." % [letter, col]))
			blk["ok"] = false
			return out
		var value := 0.0
		if has_num:
			# valor exacto: entero de cifras dividido por una potencia de 10 exacta (un solo redondeo)
			value = float((int_sig + dec_s).to_int()) / pow(10.0, dec_s.length())
			if negative:
				value = -value
		var txt := letter + ("-" if negative else "") + int_s + ("." if has_point else "") + dec_s
		if letter == "N" and first:
			first = false
			if not has_num or has_point or has_sign or int_sig.length() > 8:
				out["errors"].append(_alarm(line_no, -1, "bad_label", "etiqueta mal formada «%s»: es N seguida de hasta 8 cifras (N0-99999999)." % txt))
				blk["ok"] = false
				return out
			blk["n"] = int_sig.to_int() if int_sig != "" else 0
			continue
		first = false
		blk["words"].append({ "letter": letter, "value": value, "text": txt, "col": col, "int_digits": int_sig.length(),
			"dec_digits": dec_s.length(), "has_number": has_num, "negative": negative })
	return out


## Bloque de alto nivel: «(instrucción)» y, detrás, como mucho el número de repeticiones «N(0-9999)» (p. 34 y 289).
## Admite (SUB n), (RET), (CALL n), (RPT N a, N b) y (GOTO N a); el resto del capítulo 12 da un error de la fase 2
## que dice qué es.
static func _parse_hl(code: String, start: int, blk: Dictionary, out: Dictionary) -> void:
	var line_no: int = blk["line"]
	var close := code.find(")", start + 1)
	var inner_open := code.find("(", start + 1)
	if close < 0:
		out["errors"].append(_alarm(line_no, blk["n"], "hl_syntax", "falta el paréntesis de cierre «)» de la instrucción de alto nivel."))
		blk["ok"] = false
		return
	if inner_open >= 0 and inner_open < close:
		out["errors"].append(_alarm(line_no, blk["n"], "unsupported", "expresiones entre paréntesis dentro de una instrucción de alto nivel (capítulo 11): %s. Escribe los números directamente: (CALL 1)." % PHASE2))
		blk["ok"] = false
		return
	var inner := code.substr(start + 1, close - start - 1).strip_edges()
	if inner != inner.to_upper() and not inner.to_upper().begins_with("MSG"):
		out["lower"] = true
	var tail := code.substr(close + 1).strip_edges().to_upper().replace(" ", "")
	var repeat := -1
	if tail != "":
		if tail.begins_with("N") and tail.substr(1).is_valid_int() and tail.length() <= 5:
			repeat = tail.substr(1).to_int()
		else:
			out["errors"].append(_alarm(line_no, blk["n"], "hl_mixed", "detrás de la instrucción de alto nivel solo puede ir el número de repeticiones N(0-9999) (p. 34 y 289); «%s» no." % tail))
			blk["ok"] = false
			return
	blk["repeat"] = repeat
	var compact := inner.to_upper().replace(" ", "").replace("\t", "")
	for op in ["SUB", "CALL"]:
		if compact.begins_with(op) and compact.substr(op.length()).is_valid_int():
			var num := compact.substr(op.length()).to_int()
			if op == "SUB" and num > 9999:
				out["errors"].append(_alarm(line_no, blk["n"], "unsupported", "(SUB %d): las subrutinas de 10000 a 20000 son del fabricante (OEM, p. 291), %s. Las generales van de 0 a 9999." % [num, PHASE2]))
				blk["ok"] = false
				return
			blk["hl"] = { "op": op, "num": num }
			return
	if compact == "RET":
		blk["hl"] = { "op": "RET" }
		return
	if compact.begins_with("GOTO"):
		var lab := compact.substr(4)
		if lab.begins_with("N") and lab.substr(1).is_valid_int():
			blk["hl"] = { "op": "GOTO", "label": lab.substr(1).to_int() }
			return
		out["errors"].append(_alarm(line_no, blk["n"], "hl_syntax", "(GOTO N etiqueta): el salto va a la etiqueta de un bloque, p. ej. (GOTO N22) (p. 289)."))
		blk["ok"] = false
		return
	if compact.begins_with("RPT"):
		var args := compact.substr(3).split(",")
		if args.size() == 3 and args[2].begins_with("P"):
			out["errors"].append(_alarm(line_no, blk["n"], "unsupported", "(RPT N, N, P): repetir los bloques de otro programa está %s; sin P se repiten los del mismo programa (p. 289)." % PHASE2))
			blk["ok"] = false
			return
		if args.size() == 2 and args[0].begins_with("N") and args[1].begins_with("N") \
				and args[0].substr(1).is_valid_int() and args[1].substr(1).is_valid_int():
			blk["hl"] = { "op": "RPT", "from": args[0].substr(1).to_int(), "to": args[1].substr(1).to_int() }
			return
		out["errors"].append(_alarm(line_no, blk["n"], "hl_syntax", "(RPT N inicio, N final): los dos extremos son etiquetas de bloque, p. ej. (RPT N10, N20) N3 (p. 289)."))
		blk["ok"] = false
		return
	var what := ""
	for key in HL_PHASE2:
		if compact.begins_with(key):
			what = HL_PHASE2[key]
			break
	if what == "" and compact.find("=") >= 0:
		what = "asignación a parámetros o variables (p. 286)"
	if what == "" and (compact.begins_with("P") or compact.length() == 0):
		what = "lenguaje de alto nivel (capítulos 11 y 12)"
	var txt := "«(%s)»: %s, %s." % [inner, what, PHASE2] if what != "" else "«(%s)» no es una instrucción del 8055 (capítulo 12). Los comentarios van detrás de «;»." % inner
	out["errors"].append(_alarm(line_no, blk["n"], "unsupported" if what != "" else "hl_syntax", txt))
	blk["ok"] = false


static func _skip_spaces(s: String, i: int) -> int:
	while i < s.length() and (s.unicode_at(i) == 32 or s.unicode_at(i) == 9):
		i += 1
	return i


static func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57


# ===============================================================================================================
# Intérprete
# ===============================================================================================================

func _run(text: String, options: Dictionary) -> Dictionary:
	var dialect := str(options.get("dialect", "fagor8055t"))
	var m_opt: Variant = options.get("machine", {})
	mach = _machine(m_opt if m_opt is Dictionary else {})
	var t_opt: Variant = options.get("tools", {})
	tools = t_opt if t_opt is Dictionary else {}
	var o_opt: Variant = options.get("offsets", null)
	has_offsets = o_opt is Dictionary
	offsets = o_opt if o_opt is Dictionary else {}
	var st: Variant = options.get("start", START)
	if not (st is Dictionary):
		st = START
	pos_r = _to_f(st.get("r", START["r"]), START["r"])
	pos_z = _to_f(st.get("z", START["z"]), START["z"])
	motion = "G01" if str(mach["imove"]) == "G01" else "G00"
	absolute = str(mach["isystem"]) != "G91"
	inches = bool(mach["inches"])
	per_rev = str(mach["ifeed"]) == "G95"
	diameter = bool(mach["diameter"])
	comp = Comp.new()
	comp.out = moves
	comp.tip_r = pos_r
	comp.tip_z = pos_z
	if not Dialects.DIALECTS.has(dialect):
		errors.append(_alarm(0, -1, "dialect", "dialecto desconocido «%s»; el simulador ejecuta fagor8055t." % dialect))
		return _result()
	if not bool(Dialects.DIALECTS[dialect]["executable"]):
		errors.append(_alarm(0, -1, "dialect_not_executable", "el dialecto %s (%s) es solo una tabla de contraste; el simulador ejecuta programas del Fagor 8055 T." % [dialect, Dialects.DIALECTS[dialect]["name"]]))
		return _result()
	var parsed := parse_program(text, dialect)
	blocks = parsed["blocks"]
	errors.append_array(parsed["errors"])
	warnings.append_array(parsed["warnings"])
	_collect_subs()
	var last_line := 0
	var end_index := -1
	var executed := 0
	pc = 0
	while true:
		_rpt_unwind()
		if pc >= blocks.size():
			break
		var i := pc
		var b: Dictionary = blocks[i]
		pc += 1
		executed += 1
		if executed > MAX_EXEC:
			errors.append(_alarm(b["line"], b["n"], "program_too_long", "se han ejecutado más de %d bloques: ¿un salto o una repetición sin fin? El programa se detiene aquí." % MAX_EXEC))
			break
		last_line = b["line"]
		used_blocks[i] = true
		if b["empty"] or not b["ok"]:
			continue
		_exec(b)
		_comp_errors()
		if ended:
			end_index = i
			break
		if moves.size() > MAX_MOVES:
			errors.append(_alarm(b["line"], b["n"], "program_too_long", "el programa pasa de %d movimientos; se detiene aquí." % MAX_MOVES))
			break
	if comp.pending() or comp.active():
		comp.stop()
		_comp_errors()
	if not ended:
		warnings.append(_alarm(last_line, -1, "no_end", "el programa no termina con M30 (ni con M02)."))
	else:
		_warn_unused_tail(end_index)
	return _result()


func _result() -> Dictionary:
	return { "moves": moves, "errors": _by_line(_dedupe(errors)), "warnings": _by_line(_dedupe(warnings)), "summary": summarize(moves, mach) }


## Alarmas ordenadas por línea; dentro de una línea, en el orden en que salieron (ordenación estable).
static func _by_line(list: Array) -> Array:
	var keyed: Array = []
	for i in list.size():
		keyed.append([int(list[i]["line"]), i, list[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for k in keyed:
		out.append(k[2])
	return out


## Bloques escritos después del M30 (o M02) que terminó el programa y que ningún ciclo, subrutina ni repetición usa:
## no se ejecutan nunca. Se avisa del primero.
func _warn_unused_tail(end_index: int) -> void:
	for i in range(end_index + 1, blocks.size()):
		var b: Dictionary = blocks[i]
		if b["empty"] or used_blocks.has(i):
			continue
		warnings.append(_alarm(b["line"], b["n"], "unreachable", "bloque después del final del programa que ningún ciclo usa como perfil ni ninguna subrutina o repetición ejecuta: no se ejecuta."))
		return


## Errores que deja el motor de compensación (se detectan al resolver la esquina con el bloque siguiente).
func _comp_errors() -> void:
	for e in comp.errors:
		errors.append(_alarm(int(e["line"]), int(e["n"]), str(e["code"]), str(e["text"])))
	comp.errors = []


func _exec(b: Dictionary) -> void:
	if b.has("hl"):
		_exec_hl(b)
		return
	var groups := {}
	for w in b["words"]:
		if w["letter"] == "N":
			_err(b, "word_order", "N solo va al principio del bloque (etiqueta); el número de repeticiones al final del bloque de movimiento (subrutinas modales) está %s." % PHASE2)
			return
		if w["letter"] != "G":
			continue
		if w["dec_digits"] > 0 or w["negative"] or w["int_digits"] > 3:
			_err(b, "format", "%s: las funciones G son G seguida de hasta 3 cifras enteras (G0-G319)." % w["text"])
			return
		var g := int(w["value"])
		if not G_GROUP.has(g):
			_unsupported_g(b, g)
			return
		var grp: String = G_GROUP[g]
		if groups.has(grp) and groups[grp] != g:
			_err(b, "incompatible_g", "G%02d y G%02d son incompatibles en el mismo bloque." % [groups[grp], g])
			return
		groups[grp] = g
	if groups.has("cycle"):
		_exec_cycle(b, groups)
	elif groups.has("g92"):
		_exec_g92(b, groups)
	else:
		_exec_iso(b, groups)


# ----- subrutinas, repeticiones y saltos (capítulo 12) -----

## Primera pasada: las definiciones (SUB n) … (RET). Dos subrutinas con el mismo número son un error (p. 291).
func _collect_subs() -> void:
	var open := -1
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if not b.has("hl"):
			continue
		var op: String = b["hl"]["op"]
		if op == "SUB":
			if open >= 0:
				_err(b, "sub_nested", "(SUB %d) dentro de la definición de otra subrutina: cierra la anterior con (RET) primero." % int(b["hl"]["num"]))
				continue
			var num: int = b["hl"]["num"]
			if subs.has(num):
				_err(b, "sub_duplicate", "la subrutina %d ya está definida (línea %d): no puede haber dos con el mismo número (manual, p. 291)." % [num, int(blocks[subs[num]]["line"])])
				open = i  # se salta hasta su (RET), pero no se usa
				continue
			subs[num] = i
			open = i
		elif op == "RET" and open >= 0:
			sub_end[open] = i
			open = -1
	if open >= 0:
		_err(blocks[open], "sub_no_ret", "(SUB %d) sin su (RET): la subrutina no termina." % int(blocks[open]["hl"]["num"]))


## Índice del primer bloque con la etiqueta label a partir de from (el 8055 da prioridad al primero, p. 32); -1 si no hay.
func _label_index(label: int, from: int = 0) -> int:
	for i in range(maxi(from, 0), blocks.size()):
		if int(blocks[i]["n"]) == label:
			return i
	return -1


## Fin de un tramo repetido: al volver al bloque siguiente al último, se repite o se sale de la repetición.
func _rpt_unwind() -> void:
	while not stack.is_empty():
		var f: Dictionary = stack.back()
		if f["kind"] != "rpt" or pc != int(f["end"]) + 1:
			return
		if int(f["left"]) > 1:
			f["left"] = int(f["left"]) - 1
			pc = f["start"]
			return
		stack.pop_back()
		pc = f["ret"]


func _exec_hl(b: Dictionary) -> void:
	var hl: Dictionary = b["hl"]
	var here := pc - 1
	if int(b.get("repeat", -1)) >= 0 and hl["op"] != "RPT":
		_err(b, "hl_mixed", "el número de repeticiones N detrás de «( )» solo vale para (RPT N, N) (p. 289).")
		return
	match str(hl["op"]):
		"SUB":
			_err(b, "sub_in_flow", "la ejecución llega a la definición de la subrutina %d: en el simulador las subrutinas se escriben detrás del M30 (como en el ejemplo del manual, p. 292) y solo se ejecutan con (CALL %d)." % [int(hl["num"]), int(hl["num"])])
			pc = int(sub_end.get(here, blocks.size() - 1)) + 1
		"RET":
			if stack.is_empty() or stack.back()["kind"] != "call":
				_err(b, "ret_without_call", "(RET) sin una llamada (CALL) pendiente: el programa llega al final de una subrutina sin haberla llamado.")
				return
			var f: Dictionary = stack.pop_back()
			pc = f["ret"]
		"CALL":
			var num: int = hl["num"]
			if not subs.has(num):
				_err(b, "sub_missing", "(CALL %d): no hay ninguna subrutina %d definida con (SUB %d) … (RET) en el programa." % [num, num, num])
				return
			if not sub_end.has(subs[num]):
				_err(b, "sub_no_ret", "(CALL %d): la subrutina no termina con (RET)." % num)
				return
			if stack.size() >= MAX_NEST:
				_err(b, "nesting", "más de %d niveles de anidamiento de subrutinas y repeticiones: el 8055 admite 15 (manual, p. 292)." % MAX_NEST)
				return
			stack.append({ "kind": "call", "ret": pc, "n": b["n"], "line": b["line"] })
			used_blocks[int(subs[num])] = true
			pc = int(subs[num]) + 1
		"RPT":
			var a: int = hl["from"]
			var e: int = hl["to"]
			var ia := _label_index(a)
			if ia < 0:
				_err(b, "label_missing", "(RPT N%d, N%d): no hay ningún bloque con la etiqueta N%d (primer bloque de la repetición)." % [a, e, a])
				return
			var ie := _label_index(e, ia)
			if ie < 0:
				_err(b, "label_missing", "(RPT N%d, N%d): no hay ningún bloque con la etiqueta N%d después de N%d (primero el bloque inicial y luego el final, p. 289)." % [a, e, e, a])
				return
			if here >= ia and here <= ie:
				_err(b, "rpt_self", "(RPT N%d, N%d) está dentro del tramo que repite: se llamaría a sí misma sin fin." % [a, e])
				return
			var count := int(b.get("repeat", -1))
			if count < 0:
				count = 1
			if count > MAX_REPEAT:
				_err(b, "format", "N%d: el número de repeticiones va de 0 a %d (p. 34)." % [count, MAX_REPEAT])
				return
			if count == 0:
				_warn(b, "rpt_zero", "N0: el tramo no se repite ninguna vez.", false)
				return
			if stack.size() >= MAX_NEST:
				_err(b, "nesting", "más de %d niveles de anidamiento de subrutinas y repeticiones: el 8055 admite 15 (manual, p. 292)." % MAX_NEST)
				return
			stack.append({ "kind": "rpt", "ret": pc, "start": ia, "end": ie, "left": count, "n": b["n"], "line": b["line"] })
			pc = ia
		"GOTO":
			var lab: int = hl["label"]
			var ig := _label_index(lab)
			if ig < 0:
				_err(b, "label_missing", "(GOTO N%d): no hay ningún bloque con esa etiqueta." % lab)
				return
			pc = ig


# ----- bloque ISO: movimientos, avance, cabezal, herramienta y funciones M -----

func _exec_iso(b: Dictionary, groups: Dictionary) -> void:
	var w := {}
	var ms: Array = []
	var last_rank := -1
	var dwell := groups.has("dwell")
	for word in b["words"]:
		var letter: String = word["letter"]
		if not ORDER.has(letter):
			_unsupported_letter(b, word, groups)
			return
		var rank: int = ORDER[letter]
		if rank < last_rank:
			_err(b, "word_order", "%s fuera de orden: dentro del bloque van %s (manual, p. 59)." % [word["text"], ORDER_TEXT])
			return
		last_rank = rank
		if letter == "G":
			continue
		if letter == "M":
			ms.append(word)
			continue
		if w.has(letter):
			_err(b, "duplicate_word", "%s está repetida en el bloque." % letter)
			return
		w[letter] = word
	var n_motion := motion
	if groups.has("motion"):
		n_motion = "G%02d" % groups["motion"]
	# L y Q solo son el paso y el ángulo de entrada del roscado G33 (p. 92)
	for letter in ["L", "Q"]:
		if w.has(letter) and n_motion != "G33":
			_unsupported_letter(b, w[letter], groups)
			return
	# formatos (cap. 3, 5 y 6 del manual)
	for letter in ["X", "Z"]:
		if w.has(letter) and not _fmt(b, w[letter], 5, 5, true, "±5.5"):
			return
	for letter in ["I", "R"]:
		if w.has(letter) and not _fmt(b, w[letter], 6, 5, true, "±6.5"):
			return
	if w.has("K"):
		if dwell:
			if not _fmt(b, w["K"], 5, 0, false, "K5 (centésimas de segundo)"):
				return
		elif not _fmt(b, w["K"], 6, 5, true, "±6.5"):
			return
	if w.has("L") and not _fmt(b, w["L"], 5, 5, false, "L5.5 (paso de la rosca)"):
		return
	if w.has("Q") and not _fmt(b, w["Q"], 3, 5, true, "Q±3.5 (ángulo del cabezal)"):
		return
	if w.has("F") and not _fmt(b, w["F"], 5, 5, false, "5.5"):
		return
	if w.has("S") and not _fmt(b, w["S"], 5, 4, false, "5.4"):
		return
	if w.has("T") and not _fmt(b, w["T"], 4, 0, false, "T4"):
		return
	if w.has("D") and not _fmt(b, w["D"], 4, 0, false, "D4"):
		return
	var m_codes: Array[int] = []
	for mw in ms:
		if not _fmt(b, mw, 4, 0, false, "M4"):
			return
		var mc := int(mw["value"])
		if not M_SUPPORTED.has(mc):
			_unsupported_m(b, mc)
			return
		m_codes.append(mc)
	if m_codes.has(3) and m_codes.has(4):
		_err(b, "incompatible_m", "M03 y M04 en el mismo bloque: el cabezal no puede girar en los dos sentidos.")
		return
	for letter in ["X", "Z", "I", "K", "R"]:
		if w.has(letter) and not w[letter]["has_number"] and not (letter == "K" and dwell):
			_warn(b, "zero_implied", "%s sin número: el 8055 lo lee como %s0 (p. 31)." % [letter, letter], false)
	# G04: temporización o detención de la preparación de bloques (p. 107-110)
	var dwell_s := 0.0
	var interrupt := false
	if dwell:
		if not w.has("K") or not w["K"]["has_number"] or w["K"]["value"] == 0.0:
			if b["words"].size() > 1:
				_err(b, "g04_alone", "G04 sin K debe ir sola (detiene la preparación de bloques). Para esperar, G04 K en centésimas de segundo: G04 K150 son 1.5 s.")
				return
			_warn(b, "g04_no_k", "G04 sin K (o con K0) solo detiene la preparación de bloques: no hay espera.", false)
			interrupt = true
		elif groups.has("motion") and int(groups["motion"]) >= 2:
			_err(b, "g04_arc", "G04 K con G02/G03 en el mismo bloque: K no puede ser a la vez la espera y el centro del arco.")
			return
		else:
			dwell_s = w["K"]["value"] / 100.0
	if interrupt:
		if comp_side != 0:
			_warn(b, "comp_cancelled", "G04 (interrupción de la preparación de bloques) anula la compensación G41/G42 (manual, p. 133): la herramienta queda tangente a la perpendicular del último tramo.", false)
			comp.stop()
			comp_side = 0
		return
	# ---- cálculo sin tocar el estado: un bloque con errores no se ejecuta ----
	var n_inches := inches
	if groups.has("units"):
		n_inches = groups["units"] == 70
	var n_abs := absolute
	if groups.has("abs"):
		n_abs = groups["abs"] == 90
	var n_per_rev := per_rev
	if groups.has("feed"):
		n_per_rev = groups["feed"] == 95
	var n_diam := diameter
	if groups.has("diam"):
		n_diam = groups["diam"] == 151
	var unit := INCH if n_inches else 1.0
	var tr := pos_r
	var tz := pos_z
	if w.has("X"):
		var xr: float = w["X"]["value"] * unit / (2.0 if n_diam else 1.0)
		tr = xr if n_abs else pos_r + xr
	if w.has("Z"):
		var zv: float = w["Z"]["value"] * unit
		tz = zv if n_abs else pos_z + zv
	var has_i := w.has("I")
	var has_k := w.has("K") and not dwell  # en G04, K es la espera
	var has_r := w.has("R")
	var arc_words := has_i or has_k or has_r
	var is_arc := n_motion == "G02" or n_motion == "G03"
	var center := {}
	var moving := absf(tr - pos_r) > EPS or absf(tz - pos_z) > EPS
	if arc_words and not is_arc:
		_err(b, "arc_words", "I, K y R solo van con G02 o G03 (ahora está activa %s)." % n_motion)
		return
	if is_arc and (moving or arc_words):
		if has_r and (has_i or has_k):
			_err(b, "arc_r_and_ik", "el arco lleva R y también I/K: se programa con una cosa o con la otra (p. 81).")
			return
		if not arc_words:
			_err(b, "arc_no_center", "arco sin centro: %s necesita I y K (centro) o R (radio)." % n_motion)
			return
		var ci: float = w["I"]["value"] * unit if has_i else 0.0
		var ck: float = w["K"]["value"] * unit if has_k else 0.0
		var rv: float = w["R"]["value"] * unit if has_r else 0.0
		center = arc_center(pos_z, pos_r, tz, tr, n_motion == "G02", has_r, rv, ci, ck, float(mach["cirinerr_mm"]))
		if not center["ok"]:
			_err(b, center["code"], center["text"])
			return
	# roscado electrónico G33 X… Z… L… Q… (p. 92)
	var pitch := 0.0
	var q_deg := 0.0
	if n_motion == "G33" and moving:
		if not w.has("L") or w["L"]["value"] <= 0.0:
			_err(b, "g33_no_pitch", "G33 sin paso: el roscado se programa G33 X… Z… L (paso, mm) y, si hace falta, Q (ángulo del cabezal en el inicio) (manual, p. 92).")
			return
		pitch = w["L"]["value"] * unit
		q_deg = w["Q"]["value"] if w.has("Q") else 0.0
		if absf(q_deg) > 359.9999 + EPS:
			_err(b, "format", "Q%s: el ángulo del cabezal de G33 va de −359,9999 a 359,9999 (p. 92)." % _num(q_deg))
			return
	# compensación del radio de la punta (p. 133-144)
	var n_side := comp_side
	if groups.has("comp"):
		var g: int = groups["comp"]
		if is_arc:
			_err(b, "comp_arc", "G%d se programa con G00 o G01 activas (movimientos rectilíneos): con G02 o G03 el CNC da error (manual, p. %d)." % [g, 138 if g == 40 else 134])
			return
		if n_motion == "G33" and g != 40:
			_err(b, "unsupported", "G%d con el roscado G33: %s." % [g, PHASE2])
			return
		if g != 40 and comp_side != 0 and comp_side != g:
			_err(b, "unsupported", "cambio de G%d a G%d sin G40 (manual, 8.2.8, p. 144): %s. Programa G40 y vuelve a activar la compensación." % [comp_side, g, PHASE2])
			return
		n_side = 0 if g == 40 else g
	if comp_side != 0 and n_side != 0 and (w.has("T") or w.has("D")):
		_err(b, "unsupported", "cambio de herramienta o de corrector con la compensación activa: %s. Anula con G40, cambia y vuelve a activar G41/G42." % PHASE2)
		return
	if comp_side != 0 and n_side != 0 and n_motion == "G33" and moving:
		_err(b, "unsupported", "roscado G33 con la compensación G41/G42 activa: %s. Programa G40 antes de roscar." % PHASE2)
		return
	# cabezal (G96/G97/S/M03/M04), p. 55 y 65-67
	var n_css := css
	if groups.has("css"):
		n_css = groups["css"] == 96
	var n_vc := css_vc
	var n_rpm := rpm
	if n_css:
		if w.has("S"):
			n_vc = w["S"]["value"] * (FOOT_M if n_inches else 1.0)
		elif groups.get("css", 0) == 96 and css_vc < 0.0:
			_err(b, "g96_no_speed", "G96 sin S y sin una velocidad de corte anterior: programa G96 S (m/min) en el mismo bloque (p. 66).")
			return
	else:
		if w.has("S"):
			n_rpm = w["S"]["value"]
			if rpm_limit >= 0.0 and n_rpm > rpm_limit + EPS:
				_err(b, "s_over_limit", "S%s supera el tope G92 S%s: a partir de G92 S el 8055 no acepta una S mayor (p. 55)." % [_num(n_rpm), _num(rpm_limit)])
				return
		elif groups.get("css", 0) == 97 and css:
			n_rpm = _css_rpm(pos_r, css_vc)  # G97 sin S: se queda con las rpm a las que gira en ese momento (p. 67)
	var n_dir := spindle
	for mc in m_codes:
		if mc == 3:
			n_dir = "cw"
		elif mc == 4:
			n_dir = "ccw"
	var will_move := moving or not center.is_empty()
	var no_turn := n_dir == "stop" or (n_css and n_vc <= 0.0) or (not n_css and n_rpm <= 0.0)
	if will_move and n_motion == "G33" and no_turn:
		_err(b, "feed_per_rev_spindle_stopped", "G33 con el cabezal parado o sin velocidad: el roscado va sincronizado con el giro. Arranca el cabezal con M03 o M04 y una S.")
		return
	if will_move and n_motion != "G00" and n_motion != "G33" and n_per_rev and no_turn:
		_err(b, "feed_per_rev_spindle_stopped", "avance en mm/rev (G95) con el cabezal parado o sin velocidad: " +
			"la herramienta no avanzaría. Arranca el cabezal con M03 o M04 y una S.")
		return
	var t_new := -1
	var d_new := -1
	if w.has("T"):
		t_new = int(w["T"]["value"])
	if w.has("D"):
		d_new = int(w["D"]["value"])
		if t_new < 0 and tool_id == "":
			_err(b, "d_without_tool", "D%d sin herramienta activa: programa T y D juntos (T1 D1)." % d_new)
			return
	# ---- ejecución ----
	var prev_motion := motion
	inches = n_inches
	absolute = n_abs
	per_rev = n_per_rev
	diameter = n_diam
	motion = n_motion
	if w.has("F"):
		feed = w["F"]["value"] * unit
	if dwell_s > 0.0:
		_event(b, "dwell", { "dwell_s": dwell_s })  # al comienzo del bloque (p. 110)
	if t_new >= 0 or d_new >= 0:
		_select_tool(b, t_new, d_new)
	var old := [spindle, css, css_vc, rpm]
	css = n_css
	css_vc = n_vc
	rpm = n_rpm
	if not css and rpm > float(mach["max_rpm"]) + EPS:
		_warn(b, "rpm_clamped", "S%s pasa del máximo de la máquina (%s rpm): el cabezal se queda en el máximo." % [_num(rpm), _num(float(mach["max_rpm"]))], true)
	spindle = n_dir
	if spindle != "stop" and [spindle, css, css_vc, rpm] != old:
		if not css and rpm <= 0.0:
			_warn(b, "no_speed", "el cabezal arranca sin velocidad: falta S.", true)
		_add_spindle(b)
	for mc in m_codes:
		if mc == 8 or mc == 9:
			var on := mc == 8
			if on != coolant:
				coolant = on
				_event(b, "coolant", { "coolant": on })
	var activating := n_side != 0 and comp_side == 0
	var deactivating := n_side == 0 and comp_side != 0
	if activating:
		var off := _offset_data(tool_offset)
		if float(off["r"]) <= 0.0:
			var why := "no hay tabla de correctores" if not has_offsets else "el corrector D%d no tiene radio en la tabla" % tool_offset
			_warn(b, "comp_r0", "G%d con R0: %s, así que la compensación no desplaza la trayectoria (el CNC toma D0 con R0 y F0, p. 133)." % [n_side, why], true)
		elif not Comp.LOCATION.has(int(off["f"])):
			_err(b, "unsupported", "código de forma F%d del corrector D%d: el simulador compensa F0-F9 y las de roscar F62, F64, F66 y F68 (p. 130); el resto, %s." % [int(off["f"]), tool_offset, PHASE2])
			return
		comp.activate(n_side, float(off["r"]), int(off["f"]), int(mach["comptype"]), int(mach["compmode"]))
		comp_side = n_side
	if will_move:
		_motion_move(b, tr, tz, center, activating, deactivating, pitch, q_deg, prev_motion)
	elif deactivating:
		comp.stop()
	if deactivating:
		comp_side = 0
	if m_codes.has(5) and spindle != "stop":
		spindle = "stop"
		_add_spindle(b)  # M05 al final del bloque (p. 73)
	if m_codes.has(30) or m_codes.has(2):
		if comp_side != 0:
			_warn(b, "comp_cancelled", "M%02d anula la compensación G41/G42 (manual, p. 133): la herramienta acaba tangente a la perpendicular del último tramo. Anúlala con G40 al retirarte." % (30 if m_codes.has(30) else 2), false)
			comp.stop()
			comp_side = 0
		if spindle != "stop":
			spindle = "stop"
			_add_spindle(b)  # M02 y M30 también paran el cabezal (p. 73)
		_event(b, "end", {})
		ended = true


func _motion_move(b: Dictionary, tr: float, tz: float, center: Dictionary, activating: bool, deactivating: bool,
		pitch: float, q_deg: float, prev_motion: String) -> void:
	if tr < -EPS:
		_warn(b, "x_negative", "X negativa: la punta pasa al otro lado del eje del cabezal.", false)
	match motion:
		"G00":
			comp.rapid(b["n"], b["line"], tz, tr)
			if deactivating:
				comp.stop()
		"G01":
			var el := { "kind": "line", "z0": pos_z, "r0": pos_r, "z1": tz, "r1": tr, "feed": _feed_now(b, feed, per_rev), "n": b["n"], "line": b["line"] }
			if comp_side == 0 and absf(tr - pos_r) > EPS and absf(tz - pos_z) > EPS:
				_warn_no_comp(b)
			if deactivating:
				comp.lead_out(el)
			else:
				comp.feed(el, activating)
		"G33":
			var spin := _rpm_at(pos_r)
			if pitch * spin > float(mach["max_feed_mm_min"]) + EPS:
				_warn(b, "thread_feed", "G33: paso × rpm = %s mm/min pasa del avance máximo de la máquina (%s mm/min). Baja las rpm." % [_num(pitch * spin), _num(float(mach["max_feed_mm_min"]))], true)
			var dz := absf(tz - pos_z)
			var seg_len := sqrt((tr - pos_r) * (tr - pos_r) + (tz - pos_z) * (tz - pos_z))
			# el paso L va a lo largo del eje Z: avance por vuelta sobre la trayectoria = L · longitud / |ΔZ|
			var f_path := pitch * seg_len / dz if dz > EPS else pitch
			var thread := { "pitch": pitch, "start_deg": q_deg, "sync": prev_motion != "G33", "pass": 0, "passes": 0,
				"depth": 0.0, "total": 0.0, "kind": "G33", "infeed_deg": 0.0 }
			var el := { "kind": "line", "type": "thread", "z0": pos_z, "r0": pos_r, "z1": tz, "r1": tr,
				"feed": { "mode": "mmrev", "value": f_path }, "n": b["n"], "line": b["line"],
				"tail": { "thread": thread, "pass": 4 } }
			comp.feed(el)
		_:
			if comp_side == 0:
				_warn_no_comp(b)
			var el := { "kind": "arc", "z0": pos_z, "r0": pos_r, "z1": tz, "r1": tr, "cz": center["cz"], "cr": center["cr"],
				"rad": center["rad"], "cw": motion == "G02", "feed": _feed_now(b, feed, per_rev), "n": b["n"], "line": b["line"] }
			comp.feed(el)
	pos_r = tr
	pos_z = tz


## Aviso didáctico (una vez por programa): sin compensación, la punta teórica recorre el contorno (p. 132).
func _warn_no_comp(b: Dictionary) -> void:
	_warn(b, "profile_no_comp", "sin G41/G42 la punta teórica recorre el contorno programado y en los chaflanes, conos y arcos queda el error del radio de la punta (manual, 8.2.2, p. 132). Con G42 (exterior, hacia el plato) el CNC lo compensa.", true)


## Datos del corrector d en la tabla: { r, f }. D0, o un corrector que no está, valen R0 F0 (p. 133).
func _offset_data(d: int) -> Dictionary:
	if d <= 0:
		return { "r": 0.0, "f": 0 }
	var row: Variant = offsets.get(d, offsets.get("D%d" % d, offsets.get(str(d), null)))
	if not (row is Dictionary):
		return { "r": 0.0, "f": 0 }
	return { "r": _to_f(row.get("r", 0.0), 0.0), "f": int(_to_f(row.get("f", 0), 0.0)) }


## Avance del IR. F0 (o ninguna F) es el avance máximo de la máquina, en mm/min (p. 62).
func _feed_now(b: Dictionary, f: float, pr: bool) -> Dictionary:
	if f <= 0.0:
		_warn(b, "f0_maxfeed", "avance F0 (o sin F): el 8055 mueve al avance máximo de la máquina, MAXFEED = %s mm/min (p. 62)." % _num(float(mach["max_feed_mm_min"])), true)
		return { "mode": "mmmin", "value": float(mach["max_feed_mm_min"]) }
	if not pr and f > float(mach["max_feed_mm_min"]) + EPS:
		_warn(b, "feed_clamped", "F%s pasa del avance máximo de la máquina (%s mm/min)." % [_num(f), _num(float(mach["max_feed_mm_min"]))], true)
	return { "mode": "mmrev" if pr else "mmmin", "value": f }


func _select_tool(b: Dictionary, t_new: int, d_new: int) -> void:
	if t_new >= 0:
		tool_id = "T%d" % t_new
		var row: Variant = tools.get(tool_id, null)
		if not tools.is_empty() and row == null:
			_warn(b, "tool_unknown", "%s no está en la tabla de herramientas del simulador." % tool_id, false)
		tool_offset = t_new
		if row is Dictionary:
			tool_offset = int(_to_f(row.get("offset", t_new), t_new))
	if d_new >= 0:
		tool_offset = d_new
	_event(b, "tool", { "tool": { "id": tool_id, "offset": tool_offset } })


func _add_spindle(b: Dictionary) -> void:
	var sp := { "dir": spindle, "rpm": _rpm_at(pos_r) if spindle != "stop" else 0.0, "css": null }
	if css:
		sp["css"] = { "vc": css_vc, "rpm_max": _rpm_cap() }
	_event(b, "spindle", { "spindle": sp })


## Tope de rpm: G92 S si se ha programado, y siempre el máximo de la máquina.
func _rpm_cap() -> float:
	var cap := float(mach["max_rpm"])
	if rpm_limit > 0.0:
		cap = minf(cap, rpm_limit)
	return cap


func _css_rpm(r: float, vc: float) -> float:
	if vc <= 0.0:
		return 0.0
	var dia := 2.0 * absf(r)
	if dia < EPS:
		return _rpm_cap()
	return minf(1000.0 * vc / (PI * dia), _rpm_cap())


func _rpm_at(r: float) -> float:
	return _css_rpm(r, css_vc) if css else minf(rpm, _rpm_cap())


# ----- G92 S: tope de rpm (p. 55) -----

func _exec_g92(b: Dictionary, groups: Dictionary) -> void:
	if groups.size() > 1:
		_err(b, "g92_not_alone", "G92 va sola en el bloque: «en el bloque en que se define G92 no se puede programar ninguna otra función» (p. 55).")
		return
	var s: Variant = null
	for w in b["words"]:
		if w["letter"] == "G":
			continue
		if w["letter"] == "X" or w["letter"] == "Z":
			_err(b, "unsupported", "G92 con cotas (preselección de cotas) está %s; aquí G92 solo limita la S." % PHASE2)
			return
		if w["letter"] != "S" or s != null:
			_err(b, "g92_not_alone", "G92 solo admite S (tope de rpm) en este simulador.")
			return
		s = w
	if s == null:
		_err(b, "g92_no_s", "G92 sin S: el tope de giro se programa G92 S (rpm).")
		return
	if not _fmt(b, s, 5, 4, false, "S5.4"):
		return
	if s["value"] <= 0.0:
		_err(b, "g92_no_s", "G92 S0 dejaría el cabezal sin giro posible.")
		return
	rpm_limit = s["value"]
	if spindle != "stop":
		_add_spindle(b)


# ----- ciclos fijos G68, G69, G81, G82 y G86 -----

func _exec_cycle(b: Dictionary, groups: Dictionary) -> void:
	var kind := "G%d" % groups["cycle"]
	for grp in groups:
		if not (grp in ["cycle", "units", "abs", "feed", "diam"]):
			_err(b, "cycle_param", "%s no se programa junto a G%02d: las condiciones de mecanizado van antes de llamar al ciclo." % [kind, groups[grp]])
			return
	if kind == "G87":
		_err(b, "unsupported", "G87 (roscado frontal, p. 193): la rosca en espiral de la cara no cabe en el modelo axisimétrico r(z) del torno simulado, %s." % PHASE2)
		return
	if kind == "G86":
		_exec_thread_cycle(b, groups)
		return
	var allowed: Array = CYCLE_WORDS[kind]
	var structure := "%s %s" % [kind, " ".join(PackedStringArray(allowed))]
	var par := {}
	var last := -1
	for w in b["words"]:
		if w["letter"] == "G":
			continue
		var idx := allowed.find(w["letter"])
		if idx < 0:
			var extra := ""
			if w["letter"] == "P":
				extra = " En el 8055 los parámetros de %s son letras; P0=K… P14=K es el formato del Fagor 8025/8030." % kind
			_err(b, "cycle_param", "%s no es un parámetro de %s (%s).%s" % [w["letter"], kind, structure, extra])
			return
		if par.has(w["letter"]):
			_err(b, "duplicate_word", "%s está repetida en el bloque de %s." % [w["letter"], kind])
			return
		if idx < last:
			_err(b, "word_order", "%s fuera de orden: la estructura del bloque es %s (p. %d)." % [w["text"], structure, _cycle_page(kind)])
			return
		last = idx
		par[w["letter"]] = w
	var profile_cycle := kind == "G68" or kind == "G69"
	var required: Array = ["X", "Z", "C", "S", "E"] if profile_cycle else ["X", "Z", "Q", "R", "C"]
	for letter in required:
		if not par.has(letter):
			_err(b, "cycle_param", "%s: falta el parámetro %s." % [kind, letter])
			return
	for letter in par:
		var w: Dictionary = par[letter]
		var ok := true
		match letter:
			"X", "Z":
				ok = _fmt(b, w, 5, 5, true, "±5.5")
			"Q":
				if profile_cycle:
					_err(b, "unsupported", "%s Q: el perfil en otro programa está %s." % [kind, PHASE2])
					return
				ok = _fmt(b, w, 5, 5, true, "±5.5")
			"R":
				ok = _fmt(b, w, 5, 5, true, "±5.5")
			"L", "M":
				ok = _fmt(b, w, 5, 5, profile_cycle, "±5.5" if profile_cycle else "5.5")
			"S", "E":
				ok = _fmt(b, w, 4, 0, false, "4 cifras enteras (etiqueta)")
			_:
				ok = _fmt(b, w, 5, 5, false, "5.5")
		if not ok:
			return
	if par["C"]["value"] <= 0.0:
		_err(b, "cycle_param", "%s: el paso C debe ser positivo; con C0 el CNC da error (p. %d)." % [kind, _cycle_page(kind)])
		return
	if profile_cycle and ((par.has("L") and par["L"]["negative"]) or (par.has("M") and par["M"]["negative"])):
		_warn(b, "corner_mode", "L o M negativas: el 8055 acaba en arista matada (G05); el simulador usa el valor absoluto y no modela G05 (fase 2).", false)
	if comp_side != 0 and not profile_cycle:
		_err(b, "unsupported", "%s con la compensación G41/G42 activa: el ciclo compensaría sus pasadas (p. %d), %s. Anúlala con G40 antes del ciclo." % [kind, _cycle_page(kind) + 2, PHASE2])
		return
	# modales del propio bloque (unidades, absoluto, avance, diámetro)
	var n_inches: bool = groups.get("units", 70 if inches else 71) == 70
	var n_diam: bool = groups.get("diam", 151 if diameter else 152) == 151
	var n_per_rev: bool = groups.get("feed", 95 if per_rev else 94) == 95
	var n_abs: bool = groups.get("abs", 90 if absolute else 91) == 90
	var unit := INCH if n_inches else 1.0
	var xdiv := 2.0 if n_diam else 1.0
	var p := {
		"x_r": par["X"]["value"] * unit / xdiv,
		"z": par["Z"]["value"] * unit,
		"c": par["C"]["value"] * unit,
		"has_d": par.has("D"),
		"d": par["D"]["value"] * unit if par.has("D") else 0.0,
		"l": par["L"]["value"] * unit if par.has("L") else 0.0,
		"has_m": par.has("M"),
		"m": par["M"]["value"] * unit if par.has("M") else 0.0,
		"f": par["F"]["value"] * unit if par.has("F") else 0.0,
		"h": par["H"]["value"] * unit if par.has("H") else 0.0,
		"feed_mode": "mmrev" if n_per_rev else "mmmin",
	}
	var profile: Array = []
	if profile_cycle:
		var prof := _profile(b, int(par["S"]["value"]), int(par["E"]["value"]), p["x_r"], p["z"], n_inches, n_diam, n_abs)
		if not prof["ok"]:
			return
		profile = prof["elements"]
		if profile.is_empty():
			_err(b, "cycle_profile", "%s: el perfil entre S y E no tiene ningún tramo." % kind)
			return
		for e in profile:
			if e["kind"] == "arc" or (absf(e["r1"] - e["r0"]) > EPS and absf(e["z1"] - e["z0"]) > EPS):
				if float(p["h"]) > EPS:
					_warn(b, "no_nose_comp", "%s hace el acabado con compensación del radio de la punta (p. 159); el simulador lo hace sin ella (G41/G42 dentro del ciclo, fase 2), así que en chaflanes, conos y arcos queda el error del radio de la plaquita. Para compensarlo, deja el ciclo sin H y acaba el perfil aparte con G42, por ejemplo repitiendo sus bloques con (RPT)." % kind, false)
				break
	else:
		p["q_r"] = par["Q"]["value"] * unit / xdiv
		p["r_z"] = par["R"]["value"] * unit
	if n_per_rev and (spindle == "stop" or (css and css_vc <= 0.0) or (not css and rpm <= 0.0)):
		_err(b, "feed_per_rev_spindle_stopped", "%s con avance en mm/rev (G95) y el cabezal parado o sin velocidad: " % kind +
			"arranca el cabezal (M03 o M04 y una S) antes del ciclo.")
		return
	var rough := _feed_now(b, feed, n_per_rev)
	var res := Cycles.expand(kind, p, pos_r, pos_z, profile, rough)
	if not res["errors"].is_empty():
		for e in res["errors"]:
			var n_e: int = int(e.get("n", b["n"]))
			var line_e: int = int(e.get("line", b["line"]))
			errors.append(_alarm(line_e, n_e, str(e["code"]), str(e["text"])))
		return
	if comp_side != 0:
		# G68 y G69 anulan la compensación (p. 133): lo pendiente acaba en la perpendicular de su final
		_warn(b, "comp_cancelled", "%s anula la compensación G41/G42 (manual, p. 133 y %d): al acabar el ciclo el CNC queda en G40." % [kind, _cycle_page(kind) + 2], false)
		comp.stop()
		comp_side = 0
	inches = n_inches
	diameter = n_diam
	per_rev = n_per_rev
	absolute = n_abs
	_append_cycle(b, res["moves"])
	if profile_cycle:
		# al acabar G68/G69 quedan G00, G40 y G90, con el último avance usado (F o H) (p. 156)
		motion = "G00"
		absolute = true
		if float(p["h"]) > EPS:
			feed = p["h"]
		elif float(p["f"]) > EPS:
			feed = p["f"]


## Movimientos de un ciclo al IR, con el número de bloque y la línea del ciclo, desde la posición real de la punta.
## La posición programada pasa al final del ciclo (el punto de llamada en G68-G82 y el de aproximación en G86).
func _append_cycle(b: Dictionary, list: Array) -> void:
	for mv in list:
		mv["n"] = b["n"]
		mv["line"] = b["line"]
		var o := _ordered(mv)
		o["from"] = { "r": comp.tip_r, "z": comp.tip_z }
		moves.append(o)
		comp.tip_r = o["to"]["r"]
		comp.tip_z = o["to"]["z"]
	if not list.is_empty():
		pos_r = comp.tip_r
		pos_z = comp.tip_z


## G86 X Z Q R K I B E D L C J A W V M H U: ciclo fijo de roscado longitudinal (manual, 9.9, p. 187-192).
func _exec_thread_cycle(b: Dictionary, groups: Dictionary) -> void:
	var kind := "G86"
	var allowed: Array = CYCLE_WORDS[kind]
	var structure := "%s %s" % [kind, " ".join(PackedStringArray(allowed))]
	var par := {}
	var last := -1
	for w in b["words"]:
		if w["letter"] == "G":
			continue
		var idx := allowed.find(w["letter"])
		if idx < 0:
			_err(b, "cycle_param", "%s no es un parámetro de %s (%s)." % [w["letter"], kind, structure])
			return
		if par.has(w["letter"]):
			_err(b, "duplicate_word", "%s está repetida en el bloque de %s." % [w["letter"], kind])
			return
		if idx < last:
			_err(b, "word_order", "%s fuera de orden: la estructura del bloque es %s (p. 187)." % [w["text"], structure])
			return
		last = idx
		par[w["letter"]] = w
	for letter in ["X", "Z", "Q", "R", "I", "B", "C"]:
		if not par.has(letter):
			_err(b, "cycle_param", "%s: falta el parámetro %s (%s)." % [kind, letter, structure])
			return
	for letter in par:
		var w: Dictionary = par[letter]
		var ok := true
		match letter:
			"H", "U":
				ok = _fmt(b, w, 1, 0, false, "%s1" % letter)
			_:
				ok = _fmt(b, w, 5, 5, true, "±5.5")
		if not ok:
			return
	# lo que el simulador no hace, con su porqué
	var phase2 := {
		"K": "la reparación de roscas (K y W, p. 187 y 192)",
		"U": "la reparación parcial (U1, p. 191)",
		"M": "el paso variable (M, p. 190)",
		"H": "los tipos de entrada H (p. 190-191); sin H, la entrada la da A",
	}
	for letter in phase2:
		if par.has(letter) and not (letter == "H" and par[letter]["value"] == 0.0) and not (letter == "U" and par[letter]["value"] == 0.0):
			_err(b, "unsupported", "%s %s: %s está %s." % [kind, par[letter]["text"], phase2[letter], PHASE2])
			return
	if par.has("V") and absf(par["V"]["value"]) > 1.0 + EPS:
		_err(b, "unsupported", "%s %s: las roscas de varias entradas (V, p. 190) están %s; una rosca de varias entradas se puede hacer con varios G86 que solo cambien W." % [kind, par["V"]["text"], PHASE2])
		return
	var i_val: float = par["I"]["value"]
	var b_val: float = par["B"]["value"]
	var c_val: float = par["C"]["value"]
	if i_val == 0.0:
		_err(b, "cycle_param", "%s: la profundidad I no puede ser 0: el CNC da error (p. 187)." % kind)
		return
	if i_val < 0.0:
		_err(b, "unsupported", "%s con I negativa (rosca interior, p. 187): %s; el torno simulado no tiene barras de interior." % [kind, PHASE2])
		return
	if b_val == 0.0:
		_err(b, "cycle_param", "%s: el paso de profundidad B no puede ser 0: el CNC da error (p. 188)." % kind)
		return
	if c_val == 0.0:
		_err(b, "cycle_param", "%s: el paso de rosca C no puede ser 0: el CNC da error (p. 189)." % kind)
		return
	var a_deg: float = par["A"]["value"] if par.has("A") else 30.0
	if a_deg < 0.0:
		_err(b, "unsupported", "%s A negativa (penetración en zigzag, p. 189): %s." % [kind, PHASE2])
		return
	if a_deg >= 60.0:
		_err(b, "cycle_param", "%s A%s: con 60° o más la penetración ya no sigue el perfil de 60° de la rosca métrica; A va de 0 (radial) a la mitad del ángulo de la herramienta (30°, p. 189)." % [kind, _num(a_deg)])
		return
	if par.has("D") and par["D"]["negative"]:
		_warn(b, "corner_mode", "D negativa: el 8055 se retira en arista viva (G07, p. 188); el simulador usa el valor absoluto.", false)
	var n_inches: bool = groups.get("units", 70 if inches else 71) == 70
	var n_diam: bool = groups.get("diam", 151 if diameter else 152) == 151
	var unit := INCH if n_inches else 1.0
	var xdiv := 2.0 if n_diam else 1.0
	var p := {
		"x_r": par["X"]["value"] * unit / xdiv, "z": par["Z"]["value"] * unit,
		"q_r": par["Q"]["value"] * unit / xdiv, "r_z": par["R"]["value"] * unit,
		"i": i_val * unit, "b": b_val * unit, "e": (par["E"]["value"] * unit) if par.has("E") else 0.0,
		"d": absf(par["D"]["value"] * unit) if par.has("D") else 0.0,
		"l": (par["L"]["value"] * unit) if par.has("L") else 0.0,
		"c": c_val * unit, "j": (par["J"]["value"] * unit) if par.has("J") else 0.0,
		"a_deg": a_deg, "w_deg": par["W"]["value"] if par.has("W") else 0.0,
	}
	if spindle == "stop" or (css and css_vc <= 0.0) or (not css and rpm <= 0.0):
		_err(b, "feed_per_rev_spindle_stopped", "%s con el cabezal parado o sin velocidad: el roscado va sincronizado con el giro; arranca el cabezal (M03 o M04 y una S) antes del ciclo (p. 192)." % kind)
		return
	var res := Cycles.expand_thread(p, pos_r, pos_z)
	if not res["errors"].is_empty():
		for e in res["errors"]:
			errors.append(_alarm(b["line"], b["n"], str(e["code"]), str(e["text"])))
		return
	var pitch_z: float = res["pitch_z"]
	var spin := _rpm_at(float(p["x_r"]))
	if pitch_z * spin > float(mach["max_feed_mm_min"]) + EPS:
		_warn(b, "thread_feed", "%s: paso × rpm = %s mm/min pasa del avance máximo de la máquina (%s mm/min). Baja las rpm." % [kind, _num(pitch_z * spin), _num(float(mach["max_feed_mm_min"]))], true)
	if comp_side != 0:
		# al acabar el ciclo solo se anula la compensación (p. 192); su primer movimiento es un G00
		_warn(b, "comp_cancelled", "G86 anula la compensación G41/G42 (manual, p. 192): al acabar el ciclo el CNC queda en G40.", false)
		comp.stop()
		comp_side = 0
	inches = n_inches
	diameter = n_diam
	_append_cycle(b, res["moves"])


## Lee el perfil de G68/G69: los bloques de la etiqueta s a la e, desde el punto inicial (r0, z0) del ciclo. Se
## admiten G01, G02, G03, G70, G71, G90 y G91; G05, G07, G50 y F, S, T, D, M se ignoran (p. 160). Devuelve
## { ok, elements } con tramos { kind, z0, r0, z1, r1, cz, cr, rad, cw, n, line } en mm y radio.
func _profile(cb: Dictionary, s_lab: int, e_lab: int, r0: float, z0: float, p_in: bool, p_diam: bool, p_abs: bool) -> Dictionary:
	var fail := { "ok": false, "elements": [] }
	var si := -1
	for i in blocks.size():
		if blocks[i]["n"] == s_lab:
			si = i
			break
	if si < 0:
		_err(cb, "label_missing", "no hay ningún bloque con la etiqueta N%d (parámetro S, primer bloque del perfil)." % s_lab)
		return fail
	var ei := -1
	for i in range(si, blocks.size()):
		if blocks[i]["n"] == e_lab:
			ei = i
			break
	if ei < 0:
		_err(cb, "label_missing", "no hay ningún bloque con la etiqueta N%d (parámetro E) después de N%d." % [e_lab, s_lab])
		return fail
	var p_motion := motion
	var cur_r := r0
	var cur_z := z0
	var els: Array = []
	var ignored := false
	for i in range(si, ei + 1):
		used_blocks[i] = true
		var b: Dictionary = blocks[i]
		if b["empty"]:
			continue
		if not b["ok"]:
			_err(cb, "cycle_profile", "el perfil incluye un bloque con errores (línea %d)." % b["line"])
			return fail
		if b.has("hl"):
			_err(b, "cycle_profile", "el perfil de un ciclo no puede contener instrucciones de alto nivel (saltos, subrutinas o repeticiones, p. 160).")
			return fail
		var w := {}
		var last_rank := -1
		for word in b["words"]:
			var letter: String = word["letter"]
			if letter == "G":
				if word["dec_digits"] > 0 or word["negative"] or word["int_digits"] > 3:
					_err(b, "format", "%s: las funciones G son G seguida de hasta 3 cifras enteras." % word["text"])
					return fail
				var g := int(word["value"])
				match g:
					1, 2, 3:
						p_motion = "G%02d" % g
					0:
						_err(b, "unsupported", "G00 dentro del perfil marca el comienzo del perfil del bruto (doble perfil): %s. Usa G01, G02 o G03." % PHASE2)
						return fail
					70, 71:
						p_in = g == 70
					90, 91:
						p_abs = g == 90
					5, 7, 50:
						ignored = true
					_:
						_err(b, "unsupported", "G%02d dentro de la definición del perfil: %s (el perfil admite G01, G02, G03, G70, G71, G90 y G91)." % [g, PHASE2])
						return fail
			elif letter in ["X", "Z", "I", "K", "R"]:
				if w.has(letter):
					_err(b, "duplicate_word", "%s está repetida en el bloque." % letter)
					return fail
				if not _fmt(b, word, 6 if letter in ["I", "K", "R"] else 5, 5, true, "±6.5" if letter in ["I", "K", "R"] else "±5.5"):
					return fail
				w[letter] = word
			elif letter in ["F", "S", "T", "D", "M"]:
				ignored = true
				continue
			else:
				_err(b, "unsupported", "la letra %s no se admite dentro del perfil: %s." % [letter, PHASE2])
				return fail
			var rank: int = ORDER.get(letter, 0)
			if rank < last_rank:
				_err(b, "word_order", "%s fuera de orden: dentro del bloque van %s (p. 59)." % [word["text"], ORDER_TEXT])
				return fail
			last_rank = rank
		var unit := INCH if p_in else 1.0
		var tr := cur_r
		var tz := cur_z
		if w.has("X"):
			var xr: float = w["X"]["value"] * unit / (2.0 if p_diam else 1.0)
			tr = xr if p_abs else cur_r + xr
		if w.has("Z"):
			var zv: float = w["Z"]["value"] * unit
			tz = zv if p_abs else cur_z + zv
		var arc_words := w.has("I") or w.has("K") or w.has("R")
		if not (w.has("X") or w.has("Z") or arc_words):
			continue
		if p_motion == "G00":
			_err(b, "unsupported", "el perfil empieza en G00, que dentro del perfil marca el perfil del bruto (doble perfil, %s). Programa G01, G02 o G03 en el primer bloque del perfil." % PHASE2)
			return fail
		if p_motion == "G01":
			if arc_words:
				_err(b, "arc_words", "I, K y R solo van con G02 o G03.")
				return fail
			if absf(tr - cur_r) > EPS or absf(tz - cur_z) > EPS:
				els.append({ "kind": "line", "z0": cur_z, "r0": cur_r, "z1": tz, "r1": tr, "n": b["n"], "line": b["line"] })
		else:
			if w.has("R") and (w.has("I") or w.has("K")):
				_err(b, "arc_r_and_ik", "el arco lleva R y también I/K: se programa con una cosa o con la otra (p. 81).")
				return fail
			if not arc_words:
				_err(b, "arc_no_center", "arco sin centro: %s necesita I y K (centro) o R (radio)." % p_motion)
				return fail
			var ci: float = w["I"]["value"] * unit if w.has("I") else 0.0
			var ck: float = w["K"]["value"] * unit if w.has("K") else 0.0
			var rv: float = w["R"]["value"] * unit if w.has("R") else 0.0
			var c := arc_center(cur_z, cur_r, tz, tr, p_motion == "G02", w.has("R"), rv, ci, ck, float(mach["cirinerr_mm"]))
			if not c["ok"]:
				_err(b, c["code"], c["text"])
				return fail
			els.append({ "kind": "arc", "z0": cur_z, "r0": cur_r, "z1": tz, "r1": tr, "cz": c["cz"], "cr": c["cr"], "rad": c["rad"],
				"cw": p_motion == "G02", "n": b["n"], "line": b["line"] })
		cur_r = tr
		cur_z = tz
	if ignored:
		_warn(cb, "profile_ignored", "dentro del perfil, G05/G07/G50 y F, S, T, D y M no cuentan: el ciclo los ignora (p. 160).", true)
	return { "ok": true, "elements": els }


# ----- mensajes -----

## Página del manual (Ref. 1110) donde empieza cada ciclo.
static func _cycle_page(kind: String) -> int:
	return { "G68": 154, "G69": 161, "G81": 168, "G82": 172, "G86": 187, "G87": 193 }.get(kind, 0)


func _unsupported_g(b: Dictionary, g: int) -> void:
	var code := "G%02d" % g
	var mean := Dialects.meaning("fagor8055t", code)
	var txt := "%s (%s): %s." % [code, mean, PHASE2] if mean != "" else "%s no figura en el manual del 8055 T: %s." % [code, PHASE2]
	var hint := Dialects.fanuc_hint(code)
	if hint != "":
		txt += " " + hint
	_err(b, "unsupported", txt)


func _unsupported_m(b: Dictionary, mc: int) -> void:
	var code := "M%02d" % mc
	var mean := Dialects.meaning("fagor8055t", code)
	var txt := "%s (%s): %s." % [code, mean, PHASE2] if mean != "" else "%s: %s (el fabricante de la máquina la define en su tabla de funciones M)." % [code, PHASE2]
	if mc == 6:
		txt += " En el torno, la torreta cambia de herramienta con T."
	_err(b, "unsupported", txt)


func _unsupported_letter(b: Dictionary, w: Dictionary, groups: Dictionary) -> void:
	var letter: String = w["letter"]
	var txt := "la letra %s no se admite en este bloque: %s." % [letter, PHASE2]
	match letter:
		"P":
			if groups.has("dwell"):
				txt += " En el 8055 la espera es G04 K, en centésimas de segundo."
			else:
				txt += " P son los parámetros aritméticos del lenguaje de alto nivel."
		"U", "W":
			txt += " " + Dialects.fanuc_hint(letter)
		"L", "Q":
			txt += " %s solo es el paso (L) o el ángulo de entrada (Q) del roscado G33 (p. 92), o un parámetro de los ciclos fijos." % letter
		"C", "H", "E":
			txt += " %s solo es parámetro de los ciclos fijos (o el eje C)." % letter
	if groups.has("units") and letter in ["P", "Q", "U", "W"]:
		txt += " " + Dialects.fanuc_hint("G%02d" % groups["units"])
	_err(b, "unsupported", txt)


## Comprueba el formato de una palabra: cifras enteras y decimales máximas y signo.
func _fmt(b: Dictionary, w: Dictionary, int_max: int, dec_max: int, signed: bool, fmt: String) -> bool:
	if w["int_digits"] > int_max or w["dec_digits"] > dec_max:
		_err(b, "format", "%s no cabe en el formato %s del 8055." % [w["text"], fmt])
		return false
	if not signed and w["negative"] and w["value"] != 0.0:
		_err(b, "format", "%s no admite valores negativos (formato %s)." % [w["text"], fmt])
		return false
	return true


func _err(b: Dictionary, code: String, text: String) -> void:
	errors.append(_alarm(b["line"], b["n"], code, text))


## Aviso; con once = true solo se da una vez por programa.
func _warn(b: Dictionary, code: String, text: String, once: bool) -> void:
	if once:
		if warned.has(code):
			return
		warned[code] = true
	warnings.append(_alarm(b["line"], b["n"], code, text))


## Alarma { line, n, code, message } con el mensaje en español y la línea y el bloque delante.
static func _alarm(line: int, n: int, code: String, text: String) -> Dictionary:
	var where := "Línea %d (N%d)" % [line, n] if n >= 0 else "Línea %d" % line
	return { "line": line, "n": n, "code": code, "message": "%s: %s" % [where, text] }


static func _dedupe(list: Array) -> Array:
	var seen := {}
	var out: Array = []
	for a in list:
		var key := "%d|%s|%s" % [a["line"], a["code"], a["message"]]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(a)
	return out


# ----- movimientos del IR -----

## Movimiento sin desplazamiento (espera, herramienta, cabezal, refrigerante, fin) en la posición real de la punta. Si
## la compensación tiene un tramo pendiente, va detrás de él.
func _event(b: Dictionary, type: String, extra: Dictionary) -> void:
	var mv := { "n": b["n"], "line": b["line"], "type": type, "from": {}, "to": {} }
	for k in extra:
		mv[k] = extra[k]
	comp.event(mv)


## Movimiento de un ciclo con las claves en el orden del IR (n, line, type, from, to, …).
static func _ordered(mv: Dictionary) -> Dictionary:
	var o := { "n": mv["n"], "line": mv["line"], "type": mv["type"], "from": mv["from"], "to": mv["to"] }
	for k in ["arc", "feed", "thread", "pass"]:
		if mv.has(k):
			o[k] = mv[k]
	return o


## Longitud (mm) y tiempo (s) de un movimiento de avance, de arco o de roscado.
static func _feed_segment(mv: Dictionary, sp: Dictionary, m: Dictionary) -> PackedFloat64Array:
	var fr: float = mv["from"]["r"]
	var fz: float = mv["from"]["z"]
	var tr: float = mv["to"]["r"]
	var tz: float = mv["to"]["z"]
	var length := sqrt((tr - fr) * (tr - fr) + (tz - fz) * (tz - fz))
	var th0 := 0.0
	var sweep := 0.0
	var cr := 0.0
	var cz := 0.0
	var rad := 0.0
	if mv["type"] == "arc":
		cr = mv["arc"]["center"]["r"]
		cz = mv["arc"]["center"]["z"]
		rad = sqrt((fr - cr) * (fr - cr) + (fz - cz) * (fz - cz))
		th0 = atan2(fr - cr, fz - cz)
		sweep = atan2(tr - cr, tz - cz) - th0
		if mv["arc"]["cw"]:
			while sweep >= 0.0:
				sweep -= TAU
		else:
			while sweep <= 0.0:
				sweep += TAU
		length = absf(sweep) * rad
	var fd: Dictionary = mv.get("feed", {})
	var f := float(fd.get("value", 0.0))
	var maxf_mm := float(m["max_feed_mm_min"])
	if length < EPS or f <= 0.0:
		return PackedFloat64Array([length, 0.0])
	if str(fd.get("mode", "mmmin")) == "mmmin":
		return PackedFloat64Array([length, length / minf(f, maxf_mm) * 60.0])
	# mm/rev: se integra a lo largo del tramo, porque con G96 las rpm cambian con el radio
	var n := clampi(ceili(length / 0.5), 4, 256)
	var t := 0.0
	for i in n:
		var u := (float(i) + 0.5) / float(n)
		var r := fr + u * (tr - fr)
		if mv["type"] == "arc":
			r = cr + rad * sin(th0 + u * sweep)
		var spin := _spin_rpm(sp, r)
		if spin <= 0.0:
			continue
		t += (length / float(n)) / minf(f * spin, maxf_mm) * 60.0
	return PackedFloat64Array([length, t])


## rpm del cabezal descrito por un movimiento «spindle» del IR, con la punta en el radio r.
static func _spin_rpm(sp: Dictionary, r: float) -> float:
	if str(sp.get("dir", "stop")) == "stop":
		return 0.0
	var c: Variant = sp.get("css", null)
	if c is Dictionary:
		var vc := float(c.get("vc", 0.0))
		if vc <= 0.0:
			return 0.0
		var dia := 2.0 * absf(r)
		var cap := float(c.get("rpm_max", 0.0))
		if dia < EPS:
			return cap
		return minf(1000.0 * vc / (PI * dia), cap)
	return float(sp.get("rpm", 0.0))


static func _machine(over: Dictionary) -> Dictionary:
	var m := MACHINE.duplicate()
	for k in over:
		if m.has(k) and typeof(over[k]) == typeof(m[k]):
			m[k] = over[k]
		elif m.has(k) and typeof(m[k]) == TYPE_FLOAT and typeof(over[k]) == TYPE_INT:
			m[k] = float(over[k])
	return m


static func _to_f(v: Variant, def: float) -> float:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return def


## Número corto para los mensajes (3 decimales como mucho), con el toFixed de JavaScript.
static func _num(x: float) -> String:
	var s := Js.to_fixed(x, 3)
	if s.find(".") >= 0:
		s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
