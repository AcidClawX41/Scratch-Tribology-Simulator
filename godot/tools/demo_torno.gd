## Demostración del núcleo del torno, sin ventana: refrentado, tres pasadas de cilindrado, acabado con chaflán y un G00
## que se mete en la pieza (alarma). Escribe perfil.svg (media sección con cotas básicas), perfil.png (el mismo SVG
## rasterizado con ThorVG) y metricas.txt.
## Uso: $GODOT --headless --path godot --script res://tools/demo_torno.gd -- --out=/ruta/de/salida
## ThorVG no pinta <text>, así que los rótulos se dibujan con una fuente de trazos propia: el SVG se ve igual en un
## navegador y en el PNG.
extends SceneTree

const Js = preload("res://core/shared/js.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")

const W := 1180
const H := 640
const S := 10.0  # px por mm
const X0 := 150.0  # px de z_min
const AXIS_Y := 470.0  # px del eje

## Colores (paleta de la aplicación: fondo oscuro, acentos menta y ámbar)
const INK := "#e8e2f0"
const DIM := "#9a8fb0"
const BG := "#170e1c"
const STEEL := "#3b3447"
const RAW := "#8d8499"
const ROUGH := "#f0a24a"
const FINISH := "#5ee0b8"
const ALARM := "#ff5c7a"


# ─── fuente de trazos (rejilla 4 × 6, línea base en 0; acentos y virgulilla por encima) ───

const GLYPHS := {
	"0": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0]],
	"1": [[1, 5, 2, 6, 2, 0], [1, 0, 3, 0]],
	"2": [[0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 0, 0, 4, 0]],
	"3": [[0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 3, 3, 1, 3], [3, 3, 4, 2, 4, 1, 3, 0, 1, 0, 0, 1]],
	"4": [[3, 0, 3, 6, 0, 2, 4, 2]],
	"5": [[4, 6, 0, 6, 0, 3, 3, 3, 4, 2, 4, 1, 3, 0, 0, 0]],
	"6": [[4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0, 3, 0, 4, 1, 4, 2, 3, 3, 0, 3]],
	"7": [[0, 6, 4, 6, 1, 0]],
	"8": [[1, 3, 0, 4, 0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 3, 3, 1, 3, 0, 2, 0, 1, 1, 0, 3, 0, 4, 1, 4, 2, 3, 3]],
	"9": [[0, 1, 1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 4, 1, 3, 4, 3]],
	",": [[1, 0.6, 1, 0, 0.4, -1.2]],
	".": [[1, 0, 1, 0.5]],
	"-": [[0.5, 3, 3.5, 3]],
	"·": [[1, 3, 1, 3.5]],
	"(": [[2.5, 6.5, 1.5, 5, 1.5, 1, 2.5, -0.5]],
	")": [[1.5, 6.5, 2.5, 5, 2.5, 1, 1.5, -0.5]],
	"/": [[0, 0, 4, 6]],
	"×": [[0.5, 1, 3.5, 4], [0.5, 4, 3.5, 1]],
	"_": [[0, -0.6, 4, -0.6]],
	"Ø": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0], [-0.5, -0.5, 4.5, 6.5]],
	"A": [[0, 0, 2, 6, 4, 0], [0.8, 2.4, 3.2, 2.4]],
	"B": [[0, 0, 0, 6, 3, 6, 4, 5, 4, 4, 3, 3, 0, 3], [3, 3, 4, 2, 4, 1, 3, 0, 0, 0]],
	"C": [[4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0, 3, 0, 4, 1]],
	"D": [[0, 0, 0, 6, 3, 6, 4, 5, 4, 1, 3, 0, 0, 0]],
	"E": [[4, 6, 0, 6, 0, 0, 4, 0], [0, 3, 3, 3]],
	"F": [[4, 6, 0, 6, 0, 0], [0, 3, 3, 3]],
	"G": [[4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0, 3, 0, 4, 1, 4, 3, 2, 3]],
	"H": [[0, 0, 0, 6], [4, 0, 4, 6], [0, 3, 4, 3]],
	"I": [[1, 0, 1, 6]],
	"J": [[4, 6, 4, 1, 3, 0, 1, 0, 0, 1]],
	"K": [[0, 0, 0, 6], [4, 6, 0, 2], [1, 3, 4, 0]],
	"L": [[0, 6, 0, 0, 4, 0]],
	"M": [[0, 0, 0, 6, 2, 3, 4, 6, 4, 0]],
	"N": [[0, 0, 0, 6, 4, 0, 4, 6]],
	"O": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0]],
	"P": [[0, 0, 0, 6, 3, 6, 4, 5, 4, 4, 3, 3, 0, 3]],
	"Q": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0], [2.5, 1.5, 4, 0]],
	"R": [[0, 0, 0, 6, 3, 6, 4, 5, 4, 4, 3, 3, 0, 3], [2, 3, 4, 0]],
	"S": [[4, 5, 3, 6, 1, 6, 0, 5, 0, 4, 1, 3, 3, 3, 4, 2, 4, 1, 3, 0, 1, 0, 0, 1]],
	"T": [[0, 6, 4, 6], [2, 6, 2, 0]],
	"U": [[0, 6, 0, 1, 1, 0, 3, 0, 4, 1, 4, 6]],
	"V": [[0, 6, 2, 0, 4, 6]],
	"W": [[0, 6, 1, 0, 2, 4, 3, 0, 4, 6]],
	"X": [[0, 0, 4, 6], [0, 6, 4, 0]],
	"Y": [[0, 6, 2, 3, 4, 6], [2, 3, 2, 0]],
	"Z": [[0, 6, 4, 6, 0, 0, 4, 0]],
	"a": [[3.5, 4, 3.5, 0], [3.5, 3, 2.5, 4, 1, 4, 0, 3, 0, 1, 1, 0, 2.5, 0, 3.5, 1]],
	"m": [[0, 0, 0, 4], [0, 3, 1, 4, 1.5, 3.5, 2, 4, 3, 4, 4, 3, 4, 0], [2, 3.5, 2, 0]],
	"µ": [[0, -2, 0, 4], [0, 1, 1, 0, 3, 0, 4, 1], [4, 4, 4, 0]],
}
const NARROW := [",", ".", "·", "I", "(", ")"]


func _init() -> void:
	var out := "."
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var stock: Dictionary = Lathe.STOCKS["A"].duplicate()
	var lathe = Lathe.new(stock, "cnc", Lathe.kienzle_model(1700.0, 0.25))
	lathe.set_tool_table({ "1": LatheTools.ROUGH, "2": LatheTools.FINISH })
	var moves := program()
	lathe.load_moves(moves)
	var t0 := Time.get_ticks_usec()
	var steps := 0
	while not lathe.is_done() and not lathe.is_halted() and steps < 100000:
		lathe.step(1.0 / 60.0)
		steps += 1
	var wall_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var prof: Dictionary = lathe.profile()
	var svg := draw_svg(lathe, prof)
	var f := FileAccess.open(out.path_join("perfil.svg"), FileAccess.WRITE)
	f.store_string(svg)
	f.close()
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err == OK:
		img.save_png(out.path_join("perfil.png"))
	var m := metrics(lathe, prof, steps, wall_ms, err)
	var g := FileAccess.open(out.path_join("metricas.txt"), FileAccess.WRITE)
	g.store_string(m)
	g.close()
	print(m)
	quit(0 if err == OK else 1)


## Programa en el IR del intérprete (X en radio dentro del IR; aquí se escribe en diámetro y se divide).
static func program() -> Array:
	return [
		tool(10, "1"), css(20, 200.0, 2500.0), coolant(25, true),
		# refrentado hasta X−2·rε para no dejar pezón
		g0(30, 54.0, 0.0), g1(40, -1.6, 0.0, 0.2), g0(50, 54.0, 2.0),
		# tres pasadas de cilindrado de 1,5 mm hasta Ø41 en 40 mm
		g0(60, 47.0, 2.0), g1(70, 47.0, -40.0, 0.3), g0(80, 48.0, -40.0), g0(90, 48.0, 2.0),
		g0(100, 44.0, 2.0), g1(110, 44.0, -40.0, 0.3), g0(120, 45.0, -40.0), g0(130, 45.0, 2.0),
		g0(140, 41.0, 2.0), g1(150, 41.0, -40.0, 0.3), g0(160, 42.0, -40.0), g0(170, 60.0, 5.0),
		# acabado: chaflán 1×45°, Ø40 hasta Z−40 y cara del hombro
		tool(180, "2"), css(190, 250.0, 2500.0), g0(200, 36.0, 2.0), g1(210, 38.0, 0.0, 0.1), g1(220, 40.0, -1.0, 0.1),
		g1(230, 40.0, -40.0, 0.1), g1(240, 52.0, -40.0, 0.1), g0(250, 60.0, 5.0),
		# error de programa: un G00 que atraviesa la pieza
		g0(260, 30.0, -20.0), end(270),
	]


static func g0(n: int, x: float, z: float) -> Dictionary:
	return { "n": n, "type": "rapid", "to": { "r": x / 2.0, "z": z } }


static func g1(n: int, x: float, z: float, f: float) -> Dictionary:
	return { "n": n, "type": "feed", "to": { "r": x / 2.0, "z": z }, "feed": { "mode": "mmrev", "value": f } }


static func css(n: int, vc: float, rpm_max: float) -> Dictionary:
	return { "n": n, "type": "spindle", "spindle": { "dir": "cw", "rpm": 0.0, "css": { "vc": vc, "rpm_max": rpm_max } } }


static func tool(n: int, id: String) -> Dictionary:
	return { "n": n, "type": "tool", "tool": { "id": id, "offset": int(id) } }


static func coolant(n: int, on: bool) -> Dictionary:
	return { "n": n, "type": "coolant", "coolant": on }


static func end(n: int) -> Dictionary:
	return { "n": n, "type": "end" }


# ─── métricas ───

func metrics(lathe: RefCounted, prof: Dictionary, steps: int, wall_ms: float, svg_err: int) -> String:
	var st: Dictionary = lathe.state()
	var stock: Dictionary = lathe.stock()
	var lines := PackedStringArray()
	lines.append("Demostración del torno (núcleo, sin gráficos) · Tribology Simulator & Industrial Workshop 2.0")
	lines.append("")
	lines.append("Bruto: %s, Ø%s × %s mm, %s mm en el plato, creces de refrentado %s mm" % [stock["work_id"], fx(stock["d"], 0), fx(stock["length"], 0), fx(stock["clamp"], 0), fx(stock["face_z"], 1)])
	lines.append("Máquina: %s (%s kW, %s rpm)" % [lathe.machine()["name"], fx(lathe.machine()["power_kw"], 1), fx(lathe.machine()["rpm_max"], 0)])
	lines.append("Herramientas: T1 %s · T2 %s" % [LatheTools.ROUGH, LatheTools.FINISH])
	lines.append("Modelo de corte: Kienzle de prueba kc1.1 = 1700 N/mm², mc = 0,25 (hasta que se inyecte el de la unidad de corte)")
	lines.append("")
	lines.append("Tiempo de máquina: %s s (hasta la alarma) · %d pasos de 1/60 s en %s ms de reloj" % [fx(st["t_s"], 2), steps, fx(wall_ms, 0)])
	lines.append("Volumen arrancado: %s mm³ (%s %% del bruto) · estampados: %d" % [fx(st["removed_mm3"], 1), fx(100.0 * float(st["removed_mm3"]) / lathe.initial_volume_mm3(), 1), st["stamps"]])
	lines.append("Energía de corte: %s kJ · potencia de corte máxima: %s kW" % [fx(st["energy_kj"], 2), fx(st["pc_peak_kw"], 2)])
	lines.append("")
	lines.append("Cotas medidas en el perfil simulado:")
	var face := face_z(prof)
	for feat in features(prof):
		if int(feat["pass"]) == Lathe.PASS_RAW:
			lines.append("  Ø%s de Z%s a Z%s · bruto (Ra del bruto %s µm, tabla por proceso)" % [fx(feat["d"], 3), fx(feat["z1"], 2), fx(feat["z0"], 2), fx(stock_ra(prof, feat), 1)])
			continue
		# Ra y Rt medidas dentro del tramo, a 1 mm de sus extremos (fuera de chaflanes y redondeos)
		var ra: Dictionary = lathe.measure_roughness(float(feat["z1"]) + 1.0, float(feat["z0"]) - 1.0)
		lines.append("  Ø%s de Z%s a Z%s · Ra %s µm · Rt %s µm · %s" % [fx(feat["d"], 3), fx(feat["z1"], 2), fx(feat["z0"], 2), fx(ra["ra_um"], 2), fx(ra["rt_um"], 2), pass_name(int(feat["pass"]))])
	for sh in shoulders(prof):
		lines.append("  Hombro en Z%s: %s mm desde la cara (Z%s)" % [fx(sh, 2), fx(face - sh, 2), fx(face, 2)])
	var fin: Dictionary = lathe.measure_roughness(-35.0, -5.0)
	lines.append("")
	lines.append("Acabado del Ø40 (f 0,1 mm/rev, rε 0,4 mm), medido entre Z−35 y Z−5:")
	lines.append("  Rt %s µm (teórico f²/8rε = %s µm) · Ra %s µm (f²/32rε = %s µm)" % [fx(fin["rt_um"], 2), fx(1000.0 * 0.01 / 3.2, 2), fx(fin["ra_um"], 3), fx(1000.0 * 0.01 / 12.8, 3)])
	var ch: Dictionary = lathe.chatter_now()
	lines.append("Riesgo de vibración (estimación): %s (%s) · %s" % [ch["level"], fx(ch["risk"], 2), ch["explanation"]])
	lines.append("")
	lines.append("Alarmas:")
	for a in lathe.alarms():
		lines.append("  N%d %s · %s" % [a["n"], a["code"], a["message"]])
	lines.append("")
	lines.append("perfil.svg · perfil.png (%s)" % ("rasterizado con ThorVG" if svg_err == OK else "error %d al rasterizar" % svg_err))
	return "\n".join(lines) + "\n"


static func stock_ra(prof: Dictionary, feat: Dictionary) -> float:
	var ra: PackedFloat32Array = prof["ring_ra"]
	var i := roundi((0.5 * (float(feat["z0"]) + float(feat["z1"])) - float(prof["z0"])) / float(prof["dz"]))
	return ra[i]


## z de la cara de la pieza: el borde del último anillo con material.
static func face_z(prof: Dictionary) -> float:
	var r: PackedFloat64Array = prof["r"]
	var i := r.size() - 1
	while i > 0 and r[i] <= 0.0:
		i -= 1
	return float(prof["z0"]) + (i + 0.5) * float(prof["dz"])


## Posición de cada hombro: donde el radio cruza la media entre dos tramos cilíndricos seguidos.
static func shoulders(prof: Dictionary) -> Array:
	var r: PackedFloat64Array = prof["r"]
	var feats := features(prof)
	var out: Array = []
	for k in feats.size() - 1:
		var a: Dictionary = feats[k]
		var b: Dictionary = feats[k + 1]
		var mid := 0.25 * (float(a["d"]) + float(b["d"]))
		var i := roundi((float(a["z1"]) - float(prof["z0"])) / float(prof["dz"]))
		while i > 0 and (r[i] - mid) * (r[i - 1] - mid) > 0.0:
			i -= 1
		out.append(float(prof["z0"]) + (i - 0.5) * float(prof["dz"]))
	return out


static func pass_name(k: int) -> String:
	return ["bruto", "desbaste", "acabado", "pulido"][clampi(k, 0, 3)]


static func fx(x: Variant, d: int) -> String:
	return Js.to_fixed(float(x), d).replace(".", ",")


## Tramos cilíndricos del perfil (anillos seguidos con radio casi constante), de la cara hacia el plato.
static func features(prof: Dictionary) -> Array:
	var r: PackedFloat64Array = prof["r"]
	var pk: PackedByteArray = prof["ring_pass"]
	var z0: float = prof["z0"]
	var dz: float = prof["dz"]
	var out: Array = []
	var i := r.size() - 1
	while i >= 0:
		if r[i] <= 0.0:
			i -= 1
			continue
		var j := i
		while j - 1 >= 0 and absf(r[j - 1] - r[i]) < 0.03:
			j -= 1
		if (i - j) * dz >= 3.0:
			var s := 0.0
			for k in range(j, i + 1):
				s += r[k]
			out.append({ "z1": z0 + j * dz, "z0": z0 + i * dz, "d": 2.0 * s / (i - j + 1), "pass": pk[int((i + j) / 2.0)] })
		i = j - 1
	return out


# ─── dibujo ───

static func px(z: float) -> float:
	return X0 + (z + 85.0) * S


static func py(r: float) -> float:
	return AXIS_Y - r * S


static func n2(x: float) -> String:
	return Js.to_fixed(x, 2)


func draw_svg(lathe: RefCounted, prof: Dictionary) -> String:
	var r: PackedFloat64Array = prof["r"]
	var pk: PackedByteArray = prof["ring_pass"]
	var z0: float = prof["z0"]
	var dz: float = prof["dz"]
	var stock: Dictionary = lathe.stock()
	var zf: float = stock["face_z"]
	var ze: float = zf - float(stock["length"])
	var zj: float = ze + float(stock["clamp"])
	var r0: float = 0.5 * float(stock["d"])
	var b := PackedStringArray()
	b.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [W, H, W, H])
	b.append('<title>Perfil simulado del torno · media sección</title>')
	b.append('<rect x="0" y="0" width="%d" height="%d" fill="%s"/>' % [W, H, BG])
	# garras del plato
	var jl: float = lathe.machine()["jaw_len"]
	var jh: float = lathe.machine()["jaw_h"]
	b.append('<rect x="%s" y="%s" width="%s" height="%s" fill="#2a2233" stroke="%s" stroke-width="1"/>' % [n2(px(zj - jl)), n2(py(r0 + jh)), n2(jl * S), n2(jh * S), DIM])
	b.append(label(px(zj - jl) + 8.0, py(r0) - 12.0, "GARRAS", 11.0, DIM))
	# bruto (discontinuo)
	b.append('<path d="M%s %s L%s %s L%s %s L%s %s" fill="none" stroke="%s" stroke-width="1" stroke-dasharray="6 4"/>' % [n2(px(ze)), n2(py(0.0)), n2(px(ze)), n2(py(r0)), n2(px(zf)), n2(py(r0)), n2(px(zf)), n2(py(0.0)), RAW])
	# pieza: polígono de la media sección
	var d := PackedStringArray()
	d.append("M%s %s" % [n2(px(ze)), n2(py(0.0))])
	for i in r.size():
		d.append("L%s %s" % [n2(px(z0 + i * dz)), n2(py(r[i]))])
	d.append("L%s %s Z" % [n2(px(z0 + (r.size() - 1) * dz)), n2(py(0.0))])
	b.append('<path d="%s" fill="%s" stroke="none"/>' % [" ".join(d), STEEL])
	# contorno coloreado por tipo de pasada
	var i0 := 0
	while i0 < r.size():
		var k := pk[i0]
		var i1 := i0
		while i1 + 1 < r.size() and pk[i1 + 1] == k:
			i1 += 1
		var seg := PackedStringArray()
		for i in range(maxi(i0 - 1, 0), i1 + 1):
			seg.append(("M" if seg.is_empty() else "L") + "%s %s" % [n2(px(z0 + i * dz)), n2(py(r[i]))])
		var col := RAW if k == 0 else (ROUGH if k == 1 else FINISH)
		b.append('<path d="%s" fill="none" stroke="%s" stroke-width="2.2" stroke-linejoin="round"/>' % [" ".join(seg), col])
		i0 = i1 + 1
	# eje (trazo y punto)
	b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="1" stroke-dasharray="14 4 2 4"/>' % [n2(px(ze) - 30.0), n2(AXIS_Y), n2(px(zf) + 40.0), n2(AXIS_Y), DIM])
	# cotas de diámetro de cada tramo (con su Ra) y longitudes desde la cara hasta cada hombro
	var feats := features(prof)
	for feat in feats:
		var zc: float = 0.5 * (float(feat["z0"]) + float(feat["z1"]))
		var rr: float = 0.5 * float(feat["d"])
		var xx := px(zc)
		b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="1"/>' % [n2(xx), n2(py(0.0)), n2(xx), n2(py(rr)), INK])
		b.append(arrow(xx, py(rr), -1.0))
		b.append(label(xx + 6.0, py(rr * 0.55), "Ø" + fx(feat["d"], 2), 14.0, INK))
		if int(feat["pass"]) == Lathe.PASS_RAW:
			b.append(label(xx + 6.0, py(rr * 0.55) + 20.0, "BRUTO · Ra " + fx(stock_ra(prof, feat), 1), 11.0, RAW))
		else:
			var ra: Dictionary = lathe.measure_roughness(float(feat["z1"]) + 1.0, float(feat["z0"]) - 1.0)
			b.append(label(xx + 6.0, py(rr * 0.55) + 20.0, "Ra " + fx(ra["ra_um"], 2), 11.0, FINISH if int(feat["pass"]) == Lathe.PASS_FINISH else ROUGH))
	var face := face_z(prof)
	var row := 0
	for sh in shoulders(prof):
		var yl := AXIS_Y + 40.0 + 28.0 * row
		b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="1"/>' % [n2(px(sh)), n2(AXIS_Y + 6.0), n2(px(sh)), n2(yl + 6.0), DIM])
		b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="1"/>' % [n2(px(sh)), n2(yl), n2(px(face)), n2(yl), INK])
		b.append(label(0.5 * (px(sh) + px(face)) - 20.0, yl - 6.0, fx(face - sh, 2), 12.0, INK))
		b.append(label(px(sh) - 24.0, AXIS_Y + 18.0, "Z" + fx(sh, 1), 11.0, DIM))
		row += 1
	b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="1"/>' % [n2(px(face)), n2(AXIS_Y + 6.0), n2(px(face)), n2(AXIS_Y + 46.0 + 28.0 * maxi(row - 1, 0)), DIM])
	b.append(label(px(face) - 8.0, AXIS_Y + 18.0, "Z0", 11.0, DIM))
	# herramienta en su posición final (la de la alarma)
	var st: Dictionary = lathe.state()
	var tip_r: float = st["tip"]["r"]
	var tip_z: float = st["tip"]["z"]
	var t: Dictionary = lathe.tool()
	var re: float = t["re_mm"]
	b.append(poly_path(clip_below(t["holder_poly"], 22.0), tip_z, tip_r, "none", ALARM, 1.5))
	if (t["insert_poly"] as PackedFloat64Array).size() > 0:
		b.append(poly_path(t["insert_poly"], tip_z, tip_r, ALARM, ALARM, 1.2).replace('fill="%s"' % ALARM, 'fill="%s" fill-opacity="0.3"' % ALARM))
	b.append('<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="1.2"/>' % [n2(px(tip_z + re)), n2(py(tip_r + re)), n2(re * S), ALARM])
	var al: Array = lathe.alarms()
	if al.size() > 0:
		var a: Dictionary = al[-1]
		var t1 := "N%d G00 %s" % [a["n"], a["code"]]
		var t2 := "PARADA EN X%s Z%s" % [fx(2.0 * tip_r, 2), fx(tip_z, 2)]
		var wmax := maxf(label_width(t1, 14.0), label_width(t2, 11.0))
		var lx := px(tip_z) + 40.0
		if lx + wmax > W - 12.0:
			lx = px(tip_z) - 20.0 - wmax
		b.append(label(lx, py(tip_r) - 150.0, t1, 14.0, ALARM))
		b.append(label(lx, py(tip_r) - 128.0, t2, 11.0, ALARM))
	# título y leyenda
	b.append(label(24.0, 34.0, "PIEZA A · PERFIL SIMULADO (MEDIA SECCIÓN)", 18.0, INK))
	b.append(label(24.0, 58.0, "C45E Ø50 × 85 · REFRENTADO, 3 PASADAS DE CILINDRADO, ACABADO Y UN G00 CONTRA LA PIEZA", 11.0, DIM))
	var lx := 24.0
	for item in [[RAW, "BRUTO"], [ROUGH, "DESBASTE"], [FINISH, "ACABADO"]]:
		b.append('<path d="M%s %s L%s %s" stroke="%s" stroke-width="3"/>' % [n2(lx), n2(84.0), n2(lx + 26.0), n2(84.0), item[0]])
		b.append(label(lx + 34.0, 89.0, item[1], 11.0, INK))
		lx += 150.0
	b.append(label(W - 150.0, H - 16.0, "ESCALA 10 PX/MM", 10.0, DIM))
	b.append("</svg>")
	return "\n".join(b) + "\n"


func poly_path(poly: PackedFloat64Array, oz: float, orr: float, fill: String, stroke: String, w: float) -> String:
	var d := PackedStringArray()
	for k in range(0, poly.size(), 2):
		d.append(("M" if k == 0 else "L") + "%s %s" % [n2(px(poly[k] + oz)), n2(py(poly[k + 1] + orr))])
	return '<path d="%s Z" fill="%s" stroke="%s" stroke-width="%s"/>' % [" ".join(d), fill, stroke, n2(w)]


## Recorta un polígono convexo relativo a la punta (dz, dr) por encima de dr = top (Sutherland–Hodgman con un semiplano).
static func clip_below(poly: PackedFloat64Array, top: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var n := poly.size() / 2
	for k in n:
		var az := poly[2 * k]
		var ar := poly[2 * k + 1]
		var bz := poly[2 * ((k + 1) % n)]
		var br := poly[2 * ((k + 1) % n) + 1]
		var a_in := ar <= top
		var b_in := br <= top
		if a_in:
			out.append(az)
			out.append(ar)
		if a_in != b_in:
			var t := (top - ar) / (br - ar)
			out.append(az + t * (bz - az))
			out.append(top)
	return out


static func arrow(x: float, y: float, dir: float) -> String:
	return '<path d="M%s %s L%s %s L%s %s Z" fill="%s"/>' % [n2(x), n2(y), n2(x - 4.0), n2(y - 10.0 * dir), n2(x + 4.0), n2(y - 10.0 * dir), INK]


## Ancho aproximado de un rótulo (px) con la misma regla de avance que label().
static func label_width(text: String, size: float) -> float:
	var w := 0.0
	for ch in text:
		w += (3.5 if ch == " " else (3.0 if NARROW.has(ch) else 5.2)) * size / 6.0
	return w


## Un rótulo como trazos: x, y (línea base, px), altura de mayúscula en px.
static func label(x: float, y: float, text: String, size: float, color: String) -> String:
	var k := size / 6.0
	var d := PackedStringArray()
	var cx := x
	for ch in text:
		var accent := ""
		var base := ch
		match ch:
			"Á", "É", "Í", "Ó", "Ú":
				accent = "acute"
				base = {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U"}[ch]
			"Ñ":
				accent = "tilde"
				base = "N"
		if base == " ":
			cx += 3.5 * k
			continue
		var strokes: Array = GLYPHS.get(base, GLYPHS.get(base.to_upper(), [[0, 0, 4, 0, 4, 6, 0, 6, 0, 0]]))
		if accent == "acute":
			strokes = strokes + [[1.5, 6.8, 2.6, 8.0]]
		elif accent == "tilde":
			strokes = strokes + [[0.5, 6.9, 1.5, 7.6, 2.5, 6.9, 3.5, 7.6]]
		for s in strokes:
			for p in range(0, s.size(), 2):
				d.append(("M" if p == 0 else "L") + "%s %s" % [Js.to_fixed(cx + float(s[p]) * k, 2), Js.to_fixed(y - float(s[p + 1]) * k, 2)])
		cx += (3.0 if NARROW.has(base) else 5.2) * k
	return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [" ".join(d), color, Js.to_fixed(maxf(size / 9.0, 1.0), 2)]
