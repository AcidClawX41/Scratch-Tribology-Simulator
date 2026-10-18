## Taller industrial · vista 2D de media sección del torno, como la gráfica del Fagor: el perfil actual de la pieza
## (lleno, con el borde del color de la pasada que lo dejó: bruto, desbaste, acabado o roscado), el plano en línea
## fina, el bruto a trazos, las garras, el eje, la herramienta (plaquita y portaherramientas del catálogo, en su pose)
## y las cotas del plano: diámetros arriba y longitudes desde la cara abajo. Con el informe de inspección, cada cota
## lleva lo medido, en verde si está en tolerancia y en coral si no. De la trayectoria del programa se dibujan los
## tramos compensados con G41/G42 (la punta teórica y, a trazos, el centro de la punta) y las pasadas de roscado: la
## rosca se ve en la sección axial, con un diente en V cada paso.
## Solo dibuja lo que le pasan (perfil, plano, bruto, herramienta e informe): no calcula nada del mecanizado.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const Drawing = preload("res://core/taller/drawing.gd")

const TOP_PX := 48.0  # hueco de arriba para los diámetros
const BOTTOM_PX := 64.0  # hueco de abajo para las longitudes
const SIDE_PX := 10.0
const FRONT_MM := 10.0  # delante de la cara del bruto
const BEHIND_JAW_MM := 14.0  # de garras que se ven

var prof: Dictionary = {}
var drawing: Dictionary = {}
var stock: Dictionary = {}
var machine: Dictionary = {}
var tool: Dictionary = {}
var tip := Vector2(40.0, 40.0)  # (r, z) mm
var report: Variant = null
var path: Array = []  # movimientos del IR que se dibujan: los compensados y los de roscado
var _has_comp := false

var _s := 1.0  # px/mm
var _x0 := 0.0  # px de z = _z_left
var _z_left := 0.0
var _axis_y := 0.0


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(300, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Datos de la vista (el perfil se vuelve a leer en cada fotograma; el resto cambia con la pieza).
func set_data(p: Dictionary, dwg: Dictionary, st: Dictionary, mc: Dictionary, tl: Dictionary, tp: Vector2, rep: Variant) -> void:
	prof = p
	drawing = dwg
	stock = st
	machine = mc
	tool = tl
	tip = tp
	report = rep
	queue_redraw()


## Trayectoria del programa (IR del intérprete): se guardan los tramos compensados con G41/G42 y los de roscado.
func set_path(moves: Array) -> void:
	path = []
	_has_comp = false
	for m in moves:
		if m.has("comp") or str(m.get("type", "")) == "thread":
			path.append(m)
			_has_comp = _has_comp or m.has("comp")
	queue_redraw()


func _zx(z: float) -> float:
	return _x0 + (z - _z_left) * _s


func _ry(r: float) -> float:
	return _axis_y - r * _s


func _pt(z: float, r: float) -> Vector2:
	return Vector2(_zx(z), _ry(r))


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	if prof.is_empty() or stock.is_empty():
		return
	var face_z := float(stock["face_z"])
	var z_end := face_z - float(stock["length"])
	var z_jaw := z_end + float(stock["clamp"])
	var r_stock := float(stock["d"]) / 2.0
	_z_left = z_jaw - BEHIND_JAW_MM
	var z_right := face_z + FRONT_MM
	var r_top := r_stock + 4.0
	_s = minf((w - 2.0 * SIDE_PX) / (z_right - _z_left), (h - TOP_PX - BOTTOM_PX) / r_top)
	var used := (z_right - _z_left) * _s
	_x0 = (w - used) / 2.0
	_axis_y = TOP_PX + r_top * _s
	var font := Style.font("mono")
	# Garras (media sección de arriba)
	var jaw_len := float(machine.get("jaw_len", 30.0))
	var jaw_h := float(machine.get("jaw_h", 25.0))
	var jaw := Rect2(_pt(z_jaw - jaw_len, r_stock + jaw_h), Vector2(jaw_len * _s, jaw_h * _s))
	draw_rect(jaw, Style.c("panel3"))
	draw_rect(jaw, Style.c("line2"), false, 1.0)
	# Bruto a trazos
	var dash := Style.c("dimmer")
	draw_dashed_line(_pt(z_jaw, r_stock), _pt(face_z, r_stock), dash, 1.0, 4.0)
	draw_dashed_line(_pt(face_z, r_stock), _pt(face_z, 0.0), dash, 1.0, 4.0)
	# Perfil actual: el radio más alto de los anillos de cada columna de píxeles
	_draw_profile(z_right)
	# Plano en línea fina
	_draw_contour()
	# Trayectoria compensada y pasadas de roscado
	_draw_path()
	# Eje (trazo y punto)
	var ax_col := Style.c("dim")
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, _axis_y), Vector2(minf(x + 14.0, w), _axis_y), ax_col, 1.0)
		draw_line(Vector2(x + 18.0, _axis_y), Vector2(minf(x + 20.0, w), _axis_y), ax_col, 1.0)
		x += 24.0
	# Herramienta
	_draw_tool()
	# Cotas
	_draw_dimensions(font)
	# Rótulos y escala
	var head := "Media sección · plano en línea fina · Z0 en la cara"
	if _has_comp:
		head += " · G41/G42: punta teórica y centro de la punta a trazos"
	draw_string(font, Vector2(8, 14), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("dimmer"))
	_legend(font, Vector2(8, h - 8))
	var bar_mm := 10.0
	var bx := w - 12.0 - bar_mm * _s
	var by := h - 10.0
	draw_line(Vector2(bx, by), Vector2(bx + bar_mm * _s, by), Style.c("text"), 2.0)
	draw_string(font, Vector2(bx, by - 4.0), "10 mm", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("text"))


func _draw_profile(z_right: float) -> void:
	var rr: PackedFloat64Array = prof.get("r", PackedFloat64Array())
	var ps: PackedByteArray = prof.get("ring_pass", PackedByteArray())
	var n := rr.size()
	if n == 0:
		return
	var z0 := float(prof["z0"])
	var dz := float(prof["dz"])
	var x_a := floori(_zx(maxf(_z_left, z0)))
	var x_b := ceili(_zx(minf(z_right, z0 + (n - 1) * dz)))
	var poly := PackedVector2Array()
	var tops := PackedFloat32Array()
	var kinds := PackedByteArray()
	var xs := PackedFloat32Array()
	var any := false
	for px in range(x_a, x_b + 1):
		var za := _z_left + (float(px) - _x0) / _s
		var zb := za + 1.0 / _s
		var i0 := clampi(floori((za - z0) / dz), 0, n - 1)
		var i1 := clampi(ceili((zb - z0) / dz), 0, n - 1)
		var top := 0.0
		var kind := 0
		for i in range(i0, i1 + 1):
			if rr[i] > top:
				top = rr[i]
				kind = ps[i] if i < ps.size() else 0
		xs.append(float(px))
		tops.append(top)
		kinds.append(kind)
		any = any or top > 0.0
	if not any:
		return
	# Relleno: columnas con material, cerradas sobre el eje (tramos separados si hay huecos). Solo se añaden
	# vértices en los escalones: un polígono rectilíneo sin puntos repetidos, que siempre se triangula.
	var metal := Color(Style.c("dim"), 0.55)
	var k := 0
	while k < xs.size():
		if tops[k] <= 0.0:
			k += 1
			continue
		poly.clear()
		poly.append(Vector2(xs[k], _axis_y))
		var y := _ry(tops[k])
		poly.append(Vector2(xs[k], y))
		k += 1
		while k < xs.size() and tops[k] > 0.0:
			var y2 := _ry(tops[k])
			if y2 != y:
				poly.append(Vector2(xs[k], y))
				poly.append(Vector2(xs[k], y2))
				y = y2
			k += 1
		var x_end := xs[k - 1] + 1.0
		poly.append(Vector2(x_end, y))
		poly.append(Vector2(x_end, _axis_y))
		if poly.size() >= 4 and Geometry2D.triangulate_polygon(poly).size() > 0:
			draw_colored_polygon(poly, metal)
	# Borde con el color de la pasada: bruto, desbaste, acabado (pulido: el de acabado) y roscado
	var cols := [Style.c("dimmer"), Style.c("gold"), Style.c("mint"), Style.c("mint"), Style.c("rose")]
	for j in range(1, xs.size()):
		if tops[j] <= 0.0 and tops[j - 1] <= 0.0:
			continue
		var c: Color = cols[clampi(kinds[j], 0, 4)]
		draw_line(Vector2(xs[j - 1] + 1.0, _ry(tops[j - 1])), Vector2(xs[j], _ry(tops[j])), c, 1.5)
		draw_line(Vector2(xs[j], _ry(tops[j])), Vector2(xs[j] + 1.0, _ry(tops[j])), c, 1.5)


## El contorno del plano: tramos rectos y arcos (radios con segment_radius del plano), con los escalones.
func _draw_contour() -> void:
	var segs: Array = drawing.get("contour", [])
	if segs.is_empty():
		return
	var pts := PackedVector2Array()
	pts.append(_pt(0.0, 0.0))
	for seg in segs:
		var zh := float(seg["z_hi"])
		var zl := float(seg["z_lo"])
		var steps := 12 if str(seg["kind"]) == "arc" else 1
		for k in steps + 1:
			var z := zh + (zl - zh) * float(k) / float(steps)
			pts.append(_pt(z, Drawing.segment_radius(seg, z)))
	draw_polyline(pts, Style.c("ice"), 1.0, true)


## Tramos compensados (punta teórica en dorado y centro de la punta, punta + v, a trazos) y de roscado (rosa).
func _draw_path() -> void:
	if path.is_empty():
		return
	var tip_col := Color(Style.c("gold"), 0.7)
	var cen_col := Color(Style.c("text"), 0.55)
	var thr_col := Color(Style.c("rose"), 0.4)
	for m in path:
		if str(m["type"]) == "thread":
			draw_polyline(_move_points(m, 0.0, 0.0), thr_col, 1.0, true)
			continue
		draw_polyline(_move_points(m, 0.0, 0.0), tip_col, 1.0, true)
		var c: Dictionary = m["comp"]
		var cp := _move_points(m, float(c["vz"]), float(c["vr"]))
		for k in range(1, cp.size()):
			draw_dashed_line(cp[k - 1], cp[k], cen_col, 1.0, 3.0)


## Puntos de pantalla de un movimiento del IR desplazado (oz, orr) mm: una recta o el arco en 12 tramos.
func _move_points(m: Dictionary, oz: float, orr: float) -> PackedVector2Array:
	var fz := float(m["from"]["z"]) + oz
	var fr := float(m["from"]["r"]) + orr
	var tz := float(m["to"]["z"]) + oz
	var tr := float(m["to"]["r"]) + orr
	if str(m["type"]) != "arc":
		return PackedVector2Array([_pt(fz, fr), _pt(tz, tr)])
	var cz := float(m["arc"]["center"]["z"]) + oz
	var cr := float(m["arc"]["center"]["r"]) + orr
	var rad := sqrt((fz - cz) * (fz - cz) + (fr - cr) * (fr - cr))
	var a0 := atan2(fr - cr, fz - cz)
	var a1 := atan2(tr - cr, tz - cz)
	var sweep := fposmod((a0 - a1) if bool(m["arc"]["cw"]) else (a1 - a0), TAU)
	var sgn := -1.0 if bool(m["arc"]["cw"]) else 1.0
	var out := PackedVector2Array()
	for k in 13:
		var a := a0 + sgn * sweep * float(k) / 12.0
		out.append(_pt(cz + rad * cos(a), cr + rad * sin(a)))
	return out


## Plaquita (llena) y portaherramientas (contorno) en la pose de la punta teórica; círculo de la punta.
func _draw_tool() -> void:
	if tool.is_empty():
		return
	var holder: PackedFloat64Array = tool.get("holder_poly", PackedFloat64Array())
	var insert: PackedFloat64Array = tool.get("insert_poly", PackedFloat64Array())
	var r0 := tip.x
	var z0 := tip.y
	var hp := PackedVector2Array()
	for k in range(0, holder.size() - 1, 2):
		hp.append(_pt(z0 + holder[k], r0 + holder[k + 1]))
	if hp.size() >= 3:
		hp.append(hp[0])
		draw_polyline(hp, Style.c("dim"), 1.0, true)
	var ip := PackedVector2Array()
	for k in range(0, insert.size() - 1, 2):
		ip.append(_pt(z0 + insert[k], r0 + insert[k + 1]))
	if ip.size() >= 3:
		if Geometry2D.triangulate_polygon(ip).size() > 0:
			draw_colored_polygon(ip, Color(Style.c("gold"), 0.85))
		ip.append(ip[0])
		draw_polyline(ip, Style.c("gold"), 1.0, true)
	var re := float(tool.get("re_mm", 0.8))
	var c: Array = tool.get("center", [re, re])  # centro de la punta: (rε, rε), o (0, rε) en la de roscar
	draw_arc(_pt(z0 + float(c[0]), r0 + float(c[1])), re * _s, 0.0, TAU, 24, Style.c("rose"), 1.0, true)
	draw_circle(_pt(z0, r0), 2.0, Style.c("rose"))


## Cotas del plano: diámetros (y cono) sobre la pieza, longitudes desde la cara bajo el eje.
func _draw_dimensions(font: Font) -> void:
	var feats: Array = drawing.get("features", [])
	var measured := {}
	if report is Dictionary:
		for f in (report as Dictionary).get("features", []):
			measured[f["id"]] = f
	var row := 0
	var len_row := 0
	for f in feats:
		var kind := str(f["kind"])
		var m: Dictionary = measured.get(f["id"], {})
		var col := Style.c("text")
		var extra := ""
		if not m.is_empty():
			col = Style.c("mint") if bool(m.get("ok", false)) else Style.c("coral")
			extra = " · " + Fmt.num(m.get("measured"), 3 if kind in ["diameter", "cone"] else 2)
		if kind == "diameter" or kind == "cone":
			# en una franja fija sobre el bruto, en dos filas alternas (los rótulos vecinos no se pisan), con una
			# línea de referencia hasta el contorno
			var zm := (float(f["z_from"]) + float(f["z_to"])) / 2.0
			var r := Drawing.nominal_radius(drawing, zm)
			var p := _pt(zm, r)
			var y := TOP_PX - 6.0 - 12.0 * float(row % 2)
			draw_line(Vector2(p.x, p.y - 2.0), Vector2(p.x, y + 2.0), Color(col, 0.45), 1.0)
			_centered(font, Vector2(p.x, y), str(f["label"]).get_slice(" (", 0) + extra, 11, col)
			row += 1
		elif kind == "length":
			var z := float(f["z_to"])
			var y := _axis_y + 14.0 + 13.0 * float(len_row)
			var xa := _zx(0.0)
			var xb := _zx(z)
			var c2 := Color(col, 0.8)
			draw_line(Vector2(xa, _axis_y + 2.0), Vector2(xa, y + 3.0), Style.c("line2"), 1.0)
			draw_line(Vector2(xb, _ry(Drawing.nominal_radius(drawing, z + 0.01))), Vector2(xb, y + 3.0), Style.c("line2"), 1.0)
			draw_line(Vector2(xa, y), Vector2(xb, y), c2, 1.0)
			_arrow(Vector2(xa, y), 1.0, c2)
			_arrow(Vector2(xb, y), -1.0, c2)
			var nominal := Fmt.num(f["nominal"], 0)
			_centered(font, Vector2((xa + xb) / 2.0, y - 2.0), nominal + extra, 10, col)
			len_row += 1


func _arrow(p: Vector2, dir: float, col: Color) -> void:
	# dir: +1 apunta hacia la izquierda (la cara está a la derecha de la cota)
	var a := PackedVector2Array([p, p + Vector2(-5.0 * dir, -2.5), p + Vector2(-5.0 * dir, 2.5)])
	draw_colored_polygon(a, col)


func _centered(font: Font, bottom_center: Vector2, text: String, fsize: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var x := clampf(bottom_center.x - tw / 2.0, 2.0, maxf(2.0, size.x - tw - 2.0))
	draw_string(font, Vector2(x, bottom_center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _legend(font: Font, at: Vector2) -> void:
	var items := [["bruto", "dimmer"], ["desbaste", "gold"], ["acabado", "mint"], ["roscado", "rose"], ["plano", "ice"]]
	var x := at.x
	for it in items:
		draw_line(Vector2(x, at.y - 4.0), Vector2(x + 12.0, at.y - 4.0), Style.c(it[1]), 2.0)
		x += 16.0
		draw_string(font, Vector2(x, at.y), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dim"))
		x += font.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
