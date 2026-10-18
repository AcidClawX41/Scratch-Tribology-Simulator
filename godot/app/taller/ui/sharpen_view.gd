## Taller industrial · afiladora: vista 2D del ensayo (la que ocupa el sitio de la escena 3D si no está, y la sección
## del filo si está). Solo dibuja lo que da el simulador (core/taller/sharpening_sim.gd):
## - la muela a escala entre sí (su diámetro, el color de su abrasivo), girando, con el agua de las húmedas, la
##   herramienta que se apoya o descansa (y se moja), y las chispas de sparks.gd (ritmo, largo y color);
## - la sección del filo en la sección más caliente: el contorno de sharpening_bevel.gd (el bisel de antes, las caras
##   nuevas que avanzan, el plano romo o el vértice, y la rebaba en esquema), coloreada con la temperatura de cada
##   celda de edge_thermal.gd y con el color de revenido de la cara;
## - el filo a lo largo: la temperatura del vértice de cada sección, dónde toca la muela y dónde hay rebaba.
## La escala de colores de la temperatura y el giro de la muela son de dibujo, no datos.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Rng = preload("res://core/shared/rng.gd")

## Color de dibujo de cada abrasivo (orientativo: corindón, SiC verde, CBN ámbar, diamante; cuero).
const ABRASIVE_LOOK := { "al2o3": "#C9C3B8", "sic": "#4F8A6B", "cbn": "#C7923E", "diamante": "#BFE9FF", "": "#9C89AD", "cuero": "#8A5A3C" }
## Escala de colores de la temperatura (dibujo): de la hoja fría al blanco del quemado.
const HEAT := [[20.0, "#3A2A52"], [60.0, "#3F4FA8"], [130.0, "#2F9FD6"], [250.0, "#5BE0C8"], [400.0, "#E6B450"], [600.0, "#FF6B7A"], [723.0, "#FFF4E8"]]
const SPARKS_MAX := 70

var snap: Dictionary = {}
var _spin := 0.0  # ángulo de dibujo de la muela (rad)
var _frame := 0


func _init() -> void:
	custom_minimum_size = Vector2(300, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## La instantánea del simulador que se pinta.
func set_snapshot(s: Dictionary) -> void:
	snap = s
	queue_redraw()


## Avanza la animación (el giro de la muela y las chispas): solo dibujo.
func animate(delta: float) -> void:
	var rpm := float(snap.get("state3d", {}).get("rpm_actual", 0.0))
	# a más de ~5 vueltas por segundo el ojo no las sigue: el dibujo gira como mucho a esa velocidad
	_spin = fmod(_spin + TAU * minf(rpm / 60.0, 5.0) * delta, TAU)
	_frame += 1
	queue_redraw()


## Color de dibujo para una temperatura (°C).
static func heat_color(c: float) -> Color:
	var first: Array = HEAT[0]
	if c <= float(first[0]):
		return Color(str(first[1]))
	for i in range(1, HEAT.size()):
		var hi: Array = HEAT[i]
		if c <= float(hi[0]):
			var lo: Array = HEAT[i - 1]
			var k := (c - float(lo[0])) / (float(hi[0]) - float(lo[0]))
			return Color(str(lo[1])).lerp(Color(str(hi[1])), k)
	return Color(str(HEAT[HEAT.size() - 1][1]))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	if snap.is_empty():
		return
	var font := Style.font("mono")
	var w := size.x
	var h := size.y
	var wide := w >= 520.0
	var strip_h := 42.0
	var body := Rect2(0, 18, w, h - 18 - strip_h - 6)
	var left := Rect2(body.position, Vector2(body.size.x * (0.44 if wide else 0.5), body.size.y))
	var right := Rect2(Vector2(left.end.x, body.position.y), Vector2(w - left.end.x, body.size.y))
	_draw_machine(font, left)
	var kind := str(snap.get("kind", "cuchillo"))
	match kind:
		"broca":
			_draw_drill(font, right)
		"fresa":
			_draw_mill(font, right)
		_:
			_draw_section(font, right)
	_draw_strip(font, Rect2(8, h - strip_h - 4, w - 16, strip_h))
	draw_string(font, Vector2(8, 13), "Vista 2D · muela, sección del filo y filo a lo largo", HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, Style.c("dimmer"))


# ─────────────────────────────── Muela ───────────────────────────────

func _draw_machine(font: Font, r: Rect2) -> void:
	var vm: Dictionary = snap.get("view_machine", {})
	var st: Dictionary = snap.get("state3d", {})
	var wheel: Dictionary = {}
	for wd in vm.get("wheels", []):
		if bool(wd.get("selected", false)):
			wheel = wd
	var d := float(wheel.get("d_mm", 150.0))
	var honing := bool(wheel.get("honing", false))
	var rmax := minf(r.size.x * 0.34, r.size.y * 0.30)
	var rw := rmax * clampf(d / 250.0, 0.3, 1.0)
	var c := Vector2(r.position.x + r.size.x * 0.46, r.position.y + r.size.y * 0.40)
	var look := "cuero" if honing else str(wheel.get("abrasive_id", ""))
	var col := Color(str(ABRASIVE_LOOK.get(look, "#9C89AD")))
	var wet := bool(st.get("water", false))
	if wet:
		var tray := Rect2(c.x - rw * 0.9, c.y + rw * 0.55, rw * 1.8, rw * 0.6)
		draw_rect(tray, Style.c("panel3"))
		draw_rect(Rect2(tray.position + Vector2(3, rw * 0.12), tray.size - Vector2(6, rw * 0.12 + 3)), Color(Style.c("ice"), 0.30))
	draw_circle(c, rw, col.darkened(0.35))
	draw_arc(c, rw, 0.0, TAU, 72, col, 3.0, true)
	var rpm := float(st.get("rpm_actual", 0.0))
	# Marcas que giran (a pocas vueltas) o un anillo borroso (a muchas)
	if rpm > 0.0 and rpm / 60.0 > 5.0:
		for k in 3:
			draw_arc(c, rw * (0.55 + 0.12 * k), 0.0, TAU, 48, Color(col, 0.20), 2.0, true)
	else:
		for k in 6:
			var a := _spin + TAU * float(k) / 6.0
			draw_line(c + Vector2(cos(a), sin(a)) * rw * 0.3, c + Vector2(cos(a), sin(a)) * rw * 0.9, Color(col.lightened(0.2), 0.6), 2.0)
	draw_circle(c, rw * 0.16, Style.c("panel3"))
	if wet:
		draw_line(Vector2(c.x - rw * 0.8, c.y + rw * 0.62), Vector2(c.x + rw * 0.8, c.y + rw * 0.62), Color(Style.c("ice"), 0.9), 2.0)
	# Sentido de giro
	if rpm > 0.0:
		draw_arc(c, rw + 7.0, -2.4, -0.9, 20, Style.c("mint"), 2.0, true)
		var tip := c + Vector2(cos(-0.9), sin(-0.9)) * (rw + 7.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(6, 2), tip + Vector2(-3, -6), tip + Vector2(-4, 5)]), Style.c("mint"))
	# Herramienta: tocando la muela por delante (a la derecha, algo por encima del centro) o retirada
	var touching := bool(st.get("contact", false))
	var dipped := bool(st.get("dipped", false))
	var ang := deg_to_rad(-12.0)
	var contact := c + Vector2(cos(ang), sin(ang)) * rw
	var tool_tip := contact if touching else contact + Vector2(rw * 0.45, rw * 0.05)
	if dipped:
		var cup := Rect2(r.position.x + r.size.x * 0.70, c.y + rw * 0.55, r.size.x * 0.22, rw * 0.55)
		draw_rect(cup, Style.c("panel3"))
		draw_rect(Rect2(cup.position + Vector2(2, cup.size.y * 0.3), cup.size - Vector2(4, cup.size.y * 0.3 + 2)), Color(Style.c("ice"), 0.35))
		tool_tip = cup.get_center()
	var blade := PackedVector2Array([tool_tip, tool_tip + Vector2(rw * 0.9, -rw * 0.16), tool_tip + Vector2(rw * 0.95, rw * 0.06)])
	var edge_c := float(st.get("max_temp_c", 20.0))
	draw_colored_polygon(blade, heat_color(edge_c).lerp(Style.c("dim"), 0.35))
	draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[0]]), Style.c("text"), 1.2, true)
	# Chispas (sparks.gd): ritmo → cuántas, largo → cuánto vuelan, color del haz
	var sp: Dictionary = st.get("sparks", {})
	var rate := float(sp.get("rate", 0.0))
	if touching and rate > 0.0:
		var n := clampi(int(rate / 30.0) + 4, 4, SPARKS_MAX)
		var length := clampf(float(sp.get("length_mm", 0.0)) / 1000.0, 0.0, 1.5) * r.size.y * 0.9
		var scol: Variant = sp.get("color", Color(1.0, 0.8, 0.3))
		var spark_col: Color = scol if scol is Color else Color(1.0, 0.8, 0.3)
		var rng := Rng.new(1000 + _frame)
		var tangent := Vector2(-sin(ang), cos(ang))  # la muela gira y lanza las chispas hacia abajo y hacia fuera
		for _k in n:
			var spread := (rng.next() - 0.5) * 0.5
			var dir := tangent.rotated(spread + 0.35)
			var l := length * (0.35 + 0.65 * rng.next())
			var a0 := contact + dir * l * rng.next() * 0.3
			draw_line(a0, a0 + dir * l * 0.35, Color(spark_col, 0.85), 1.5, true)
	# Rótulos: muela y velocidad
	var y := c.y + rw + (rw * 0.75 if wet else 18.0)
	var lines := [
		"%s · Ø %s mm" % [str(snap.get("wheel_id", "")) if not honing else "cuero", Fmt.num(d, 0)],
		"%s · %s" % [Fmt.unit(snap.get("rpm"), 0, "rpm"), Fmt.unit(snap.get("vs_ms"), 1 if float(snap.get("vs_ms", 0.0)) >= 10.0 else 2, "m/s")],
	]
	var maxv: Variant = snap.get("max_speed_ms")
	if maxv != null:
		lines.append("máx. marcada %s" % Fmt.unit(maxv, 1, "m/s"))
	for i in lines.size():
		_centered(font, Vector2(c.x, minf(y + 13.0 * i, r.end.y - 4.0 - 13.0 * (lines.size() - 1 - i))), lines[i], 11, Style.c("coral") if bool(snap.get("over_speed", false)) and i == 1 else Style.c("text"))
	if bool(snap.get("stalled", false)) and touching:
		_centered(font, Vector2(c.x, c.y + 4.0), "¡se cala!", 12, Style.c("coral"))


# ─────────────────────────────── Sección del filo ───────────────────────────────

func _draw_section(font: Font, r: Rect2) -> void:
	var sec: Dictionary = snap.get("section", {})
	var ol: Dictionary = sec.get("outline", {})
	if ol.is_empty():
		return
	var pa: PackedVector2Array = ol["a"]
	var pb: PackedVector2Array = ol["b"]
	if pa.size() < 2 or pb.size() < 2:
		return
	var tip: Vector2 = ol["tip"]
	var x_max := float(ol["x_max"])
	var y_max := 0.0
	for p in pa:
		y_max = maxf(y_max, absf(p.y))
	for p in pb:
		y_max = maxf(y_max, absf(p.y))
	var box := Rect2(r.position + Vector2(r.size.x * 0.12, 26.0), Vector2(r.size.x * 0.62, r.size.y - 60.0))
	var span_x := maxf(x_max - tip.x, 1e-3)
	var scale := minf(box.size.y / span_x, box.size.x / maxf(2.0 * y_max, 1e-3))
	var cx := box.position.x + box.size.x * 0.5
	var base_y := box.end.y
	# x del filo hacia arriba; y hacia los lados (la cara A a la derecha)
	var to_px := func(p: Vector2) -> Vector2:
		return Vector2(cx + p.y * scale, base_y - (p.x - tip.x) * scale)
	# Relleno: una franja por celda de edge_thermal, del color de su temperatura
	var xs: PackedFloat32Array = sec.get("x_mm", PackedFloat32Array())
	var ts: PackedFloat32Array = sec.get("temp_c", PackedFloat32Array())
	var hexes: PackedStringArray = sec.get("tint_hex", PackedStringArray())
	if xs.size() > 1:
		# caras entre celdas: a medio camino entre centros (la primera en el vértice)
		var faces := PackedFloat32Array([0.0])
		for i in range(1, xs.size()):
			faces.append(0.5 * (float(xs[i - 1]) + float(xs[i])))
		faces.append(float(xs[xs.size() - 1]) + 0.5 * (float(xs[xs.size() - 1]) - float(xs[xs.size() - 2])))
		for i in xs.size():
			var x_lo := tip.x + float(faces[i])
			var x_hi := tip.x + float(faces[i + 1])
			if x_lo >= x_max:
				break
			x_hi = minf(x_hi, x_max)
			if x_hi <= x_lo:
				continue
			var q := PackedVector2Array([
				to_px.call(Vector2(x_lo, _y_at(pb, x_lo))), to_px.call(Vector2(x_lo, _y_at(pa, x_lo))),
				to_px.call(Vector2(x_hi, _y_at(pa, x_hi))), to_px.call(Vector2(x_hi, _y_at(pb, x_hi))),
			])
			if Geometry2D.triangulate_polygon(q).size() > 0:
				draw_colored_polygon(q, heat_color(float(ts[i])))
			# color de revenido de la cara amolada (la A), por fuera del contorno
			if i < hexes.size() and str(hexes[i]) != "" and Color.html_is_valid(str(hexes[i])):
				var a0: Vector2 = to_px.call(Vector2(x_lo, _y_at(pa, x_lo)))
				var a1: Vector2 = to_px.call(Vector2(x_hi, _y_at(pa, x_hi)))
				draw_line(a0 + Vector2(3, 0), a1 + Vector2(3, 0), Color(str(hexes[i])), 4.0)
	else:
		var full := PackedVector2Array()
		for p in pa:
			full.append(to_px.call(p))
		for k in range(pb.size() - 1, -1, -1):
			full.append(to_px.call(pb[k]))
		if Geometry2D.triangulate_polygon(full).size() > 0:
			draw_colored_polygon(full, Color(Style.c("dim"), 0.5))
	# Contorno, caras nuevas, filo romo o vértice, rebaba
	var la := PackedVector2Array()
	for p in pa:
		la.append(to_px.call(p))
	var lb := PackedVector2Array()
	for p in pb:
		lb.append(to_px.call(p))
	draw_polyline(la, Style.c("text"), 1.5, true)
	draw_polyline(lb, Style.c("text"), 1.5, true)
	for side in ["a", "b"]:
		var seg: Array = ol.get("new_" + side, [])
		if seg.size() == 2:
			var pts: PackedVector2Array = pa if side == "a" else pb
			var from := float(seg[0])
			var to := float(seg[1])
			var line := PackedVector2Array()
			line.append(to_px.call(Vector2(from, _y_at(pts, from))))
			for p in pts:
				if p.x > from and p.x < to:
					line.append(to_px.call(p))
			line.append(to_px.call(Vector2(to, _y_at(pts, to))))
			draw_polyline(line, Style.c("mint"), 3.0, true)
	if ol.has("flat"):
		var fl: Array = ol["flat"]
		draw_line(to_px.call(fl[0]), to_px.call(fl[1]), Style.c("coral"), 3.0, true)
	var burr := int(ol.get("burr_side", 0))
	if burr != 0:
		var tp: Vector2 = to_px.call(tip)
		var dir := 1.0 if burr == 2 else -1.0  # 2: rebaba en la cara A (a la derecha)
		draw_polyline(PackedVector2Array([tp, tp + Vector2(dir * 6.0, 5.0), tp + Vector2(dir * 12.0, 4.0)]), Style.c("gold"), 2.0, true)
	# Escala y rótulos
	var bar_mm := _nice(span_x / 3.0)
	var bx := r.position.x + 10.0
	var by := r.end.y - 16.0
	draw_line(Vector2(bx, by), Vector2(bx + bar_mm * scale, by), Style.c("dim"), 2.0)
	draw_string(font, Vector2(bx, by - 4.0), Fmt.unit(bar_mm * 1000.0, 0, "µm") if bar_mm < 1.0 else Fmt.unit(bar_mm, 1, "mm"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dim"))
	var bev: Dictionary = snap.get("bevel", {})
	var hand: Dictionary = snap.get("setup", {}).get("hand", {})
	var info := [
		"sección del filo a %s del talón" % Fmt.unit(sec.get("z_mm"), 0, "mm"),
		"ángulo %s por lado" % Fmt.unit(snap.get("state3d", {}).get("angle_deg", hand.get("angle_deg")), 1, "°"),
		("vértice hecho" if bool(ol.get("sharp", false)) else "romo: faltan %s" % Fmt.unit(ol.get("gap_um"), 1, "µm")),
		"bisel al %s %%" % Fmt.num(float(bev.get("progress_mean", 0.0)) * 100.0, 0),
	]
	for i in info.size():
		draw_string(font, Vector2(r.position.x + 6.0, r.position.y + 12.0 + 13.0 * i), info[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 10, Style.c("dim"))
	if burr != 0:
		draw_string(font, Vector2(r.position.x + 6.0, r.position.y + 12.0 + 13.0 * info.size()), "rebaba (esquema, no a escala)", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 10, Style.c("gold"))
	_legend(font, Rect2(r.end.x - 26.0, box.position.y, 10.0, box.size.y))


## y (mm) de una polilínea ordenada por x, interpolada.
static func _y_at(pts: PackedVector2Array, x: float) -> float:
	if pts.is_empty():
		return 0.0
	if x <= pts[0].x:
		return pts[0].y
	for i in range(1, pts.size()):
		if x <= pts[i].x:
			var a := pts[i - 1]
			var b := pts[i]
			var k := (x - a.x) / maxf(b.x - a.x, 1e-12)
			return a.y + (b.y - a.y) * k
	return pts[pts.size() - 1].y


static func _nice(v: float) -> float:
	var p := pow(10.0, floor(log(maxf(v, 1e-9)) / log(10.0)))
	for m in [1.0, 2.0, 5.0]:
		if m * p >= v * 0.7:
			return m * p
	return 10.0 * p


func _legend(font: Font, r: Rect2) -> void:
	var n := 24
	for i in n:
		var c0 := 20.0 + (723.0 - 20.0) * float(i) / float(n)
		var y0 := r.end.y - r.size.y * float(i + 1) / float(n)
		draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / float(n) + 1.0), heat_color(c0))
	for c: float in [20.0, 130.0, 400.0, 723.0]:
		var y := r.end.y - r.size.y * (c - 20.0) / (723.0 - 20.0)
		draw_string(font, Vector2(r.position.x - 30.0, y + 4.0), Fmt.num(c, 0), HORIZONTAL_ALIGNMENT_RIGHT, 28.0, 9, Style.c("dimmer"))
	draw_string(font, Vector2(r.position.x - 12.0, r.position.y - 4.0), "°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.c("dimmer"))


# ─────────────────────────────── Broca y fresa ───────────────────────────────

func _draw_drill(font: Font, r: Rect2) -> void:
	var tool: Dictionary = snap.get("setup", {}).get("tool", {})
	var temps: PackedFloat32Array = snap.get("edge_temp_c", PackedFloat32Array())
	var point := float(tool.get("point_deg", 118.0))
	var e := Vector2(r.position.x + r.size.x * 0.45, r.position.y + r.size.y * 0.55)
	var half_w := minf(r.size.x * 0.22, r.size.y * 0.16)
	var cone := half_w / tan(deg_to_rad(maxf(point, 10.0) / 2.0))
	var top := r.position.y + 30.0
	var tipp := Vector2(e.x, e.y + r.size.y * 0.18)
	var shoulder := tipp.y - cone
	var body := PackedVector2Array([Vector2(e.x - half_w, top), Vector2(e.x + half_w, top), Vector2(e.x + half_w, shoulder), tipp, Vector2(e.x - half_w, shoulder)])
	draw_colored_polygon(body, Color(Style.c("dim"), 0.45))
	for k in 2:
		var lip := PackedVector2Array([tipp, Vector2(e.x + (half_w if k == 0 else -half_w), shoulder), Vector2(e.x + (half_w if k == 0 else -half_w) * 0.55, shoulder - cone * 0.1)])
		var t := float(temps[k]) if k < temps.size() else 20.0
		draw_colored_polygon(lip, heat_color(t) if temps.size() > 0 else Color(Style.c("dim"), 0.6))
		var lx := e.x + (half_w + 6.0 if k == 0 else -half_w - 70.0)
		draw_string(font, Vector2(lx, shoulder + 14.0), "labio %d%s" % [k + 1, (" · " + Fmt.unit(t, 0, "°C")) if temps.size() > 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, 90.0, 10, Style.c("dim"))
	body.append(body[0])
	draw_polyline(body, Style.c("text"), 1.5, true)
	draw_arc(tipp, cone * 0.7, -PI / 2.0 - deg_to_rad(point / 2.0), -PI / 2.0 + deg_to_rad(point / 2.0), 20, Style.c("gold"), 2.0, true)
	_centered(font, Vector2(e.x, tipp.y + 16.0), "punta %s · incidencia %s" % [Fmt.unit(point, 0, "°"), Fmt.unit(tool.get("clearance_deg"), 0, "°")], 11, Style.c("gold"))
	if temps.is_empty():
		_centered(font, Vector2(e.x, tipp.y + 30.0), "sin temperatura (metal duro)", 10, Style.c("dim"))
	_legend(font, Rect2(r.end.x - 26.0, r.position.y + 30.0, 10.0, r.size.y - 70.0))


func _draw_mill(font: Font, r: Rect2) -> void:
	var tool: Dictionary = snap.get("setup", {}).get("tool", {})
	var a1 := float(tool.get("primary_deg", 7.0))
	var a2 := float(tool.get("secondary_deg", 15.0))
	var rad := minf(r.size.x, r.size.y) * 0.30
	var c := Vector2(r.position.x + r.size.x * 0.45, r.position.y + r.size.y * 0.62)
	draw_arc(c, rad, -PI, 0.0, 32, Style.c("line2"), 1.0, true)
	var edge := c + Vector2(0.0, -rad)
	var land := rad * 0.35
	var p1 := edge + Vector2(-cos(deg_to_rad(a1)), sin(deg_to_rad(a1))) * land
	var p2 := p1 + Vector2(-cos(deg_to_rad(a2)), sin(deg_to_rad(a2))) * land * 1.6
	var tooth := PackedVector2Array([edge, p1, p2, Vector2(p2.x, c.y), Vector2(edge.x + rad * 0.15, c.y), Vector2(edge.x + rad * 0.15, edge.y + 4.0)])
	if Geometry2D.triangulate_polygon(tooth).size() > 0:
		draw_colored_polygon(tooth, Color(Style.c("dim"), 0.5))
	draw_polyline(PackedVector2Array([edge, p1, p2]), Style.c("mint"), 2.0, true)
	draw_line(edge, edge + Vector2(-land * 2.4, 0.0), Color(Style.c("dimmer"), 0.9), 1.0)
	_centered(font, Vector2(c.x, c.y + 18.0), "incidencia 1.ª %s · 2.ª %s" % [Fmt.unit(a1, 0, "°"), Fmt.unit(a2, 0, "°")], 11, Style.c("gold"))
	_centered(font, Vector2(c.x, c.y + 32.0), "sin temperatura: la fresa no tiene perfil térmico", 10, Style.c("dim"))


# ─────────────────────────────── Filo a lo largo ───────────────────────────────

func _draw_strip(font: Font, r: Rect2) -> void:
	var temps: PackedFloat32Array = snap.get("edge_temp_c", PackedFloat32Array())
	var burrs: PackedByteArray = snap.get("section_burr", PackedByteArray())
	var sharps: PackedByteArray = snap.get("section_sharp", PackedByteArray())
	var n := maxi(temps.size(), burrs.size())
	var kind := str(snap.get("kind", "cuchillo"))
	var bar := Rect2(r.position + Vector2(0, 14), Vector2(r.size.x, 12))
	draw_rect(bar, Style.c("panel3"))
	if n > 0:
		var cw := bar.size.x / float(n)
		for i in n:
			var cell := Rect2(bar.position.x + cw * float(i) + 1.0, bar.position.y, cw - 2.0, bar.size.y)
			draw_rect(cell, heat_color(float(temps[i])) if i < temps.size() else Style.c("panel2"))
			if i < sharps.size() and sharps[i] != 0:
				draw_line(Vector2(cell.position.x, cell.end.y + 2.0), Vector2(cell.end.x, cell.end.y + 2.0), Style.c("mint"), 2.0)
			if i < burrs.size() and burrs[i] != 0:
				draw_line(Vector2(cell.position.x + 2.0, cell.position.y - 3.0), Vector2(cell.end.x - 2.0, cell.position.y - 3.0), Style.c("gold"), 2.0)
	var st: Dictionary = snap.get("state3d", {})
	if bool(st.get("contact", false)) and kind in ["cuchillo", "hacha", "cortacesped"]:
		var x := bar.position.x + bar.size.x * float(st.get("contact_pos", 0.5))
		draw_colored_polygon(PackedVector2Array([Vector2(x, bar.end.y + 4.0), Vector2(x - 5.0, bar.end.y + 12.0), Vector2(x + 5.0, bar.end.y + 12.0)]), Style.c("mint"))
	var names := ["labio 1", "labio 2"] if kind == "broca" else (["diente 1", "último"] if kind == "fresa" else ["talón", "punta"])
	draw_string(font, Vector2(r.position.x, r.position.y + 10.0), "filo a lo largo · %s → %s · verde: vértice hecho · oro: rebaba" % names, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 10, Style.c("dimmer"))


func _centered(font: Font, bottom_center: Vector2, text: String, fsize: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var x := clampf(bottom_center.x - tw / 2.0, 2.0, maxf(2.0, size.x - tw - 2.0))
	draw_string(font, Vector2(x, bottom_center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
