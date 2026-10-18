## Taller industrial · esquema animado del fresado visto desde arriba (unidad 1e).
##
## - La fresa con sus z dientes girando en el sentido de M03 (horario visto desde arriba), en cámara lenta y con la
##   velocidad real escrita.
## - La pieza: la parte en bruto, la ya fresada y, dentro del arco de contacto, el material que deja cada diente al
##   siguiente (el festón de espesor h(φ), exagerado con la escala escrita). En cada diente que corta, su viruta, del
##   color de revenido que da el core; al salir del arco, la viruta sale despedida.
## - El arco de contacto con la entrada y la salida (concordancia, oposición o centrada) y las cotas de Ø y ae.
## - Al lado (o debajo, en el teléfono), la curva h(φ) = fz·sen κ·sen φ con hm y hex y un punto por diente que corta.
## - Arriba, una tira con la pasada entera a tiempo real (dónde está la fresa en la pieza).
## Todos los números salen de MillDrillState (y este de cutting.gd): aquí solo se dibujan. Los textos quedan en
## `labels` para que los tests los comparen con el core sin dibujar.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const MillDrillState = preload("res://core/taller/mill_drill_state.gd")

## Vueltas por segundo que se dibujan como mucho (cámara lenta).
const SHOWN_REV_S := 0.25
## El espesor de viruta máximo (hex) se dibuja con esta fracción del radio de la fresa.
const H_DRAW_FRAC := 0.16
const STRIP_H := 44.0
## Por encima de este ancho, el esquema y la curva van lado a lado.
const WIDE_MIN := 560.0
## Colores de la pieza: bruto, fresado y mesa (paleta del programa).
const RAW := "line2"
const MILLED := "dim"
const TABLE := "bg"
## Las virutas que salen volando desaparecen al alejarse más de esto (en radios de la fresa): así no se quedan
## dibujadas fuera de la pieza, encima de los textos del esquema.
const FLY_MAX_R := 1.35

var eng: Dictionary = {}
var result: Dictionary = {}
var params: Dictionary = {}
var anim: Dictionary = {}
var block: Dictionary = {}
var slow: Dictionary = { "rev_s": 0.0, "time_scale": 1.0, "factor": 1.0, "s_per_rev": 0.0 }
var running := true
var anim_speed := 1.0
var tool_color := Color("#9C89AD")
var chip_color := Color.WHITE
## Textos que se dibujan (nombre → texto).
var labels := {}
## Ángulo dibujado de la fresa (rad): el diente 0 está en φ = theta.
var theta := 0.0
var _flying: Array = []  # virutas que salen del arco: { pos (en radios), vel (radios/s), age, spin }
var _was_in := PackedByteArray()
var _dirty := true  # algo cambió desde el último dibujo (con la máquina quieta no se redibuja: CONTRATOS, rendimiento)


func _init() -> void:
	custom_minimum_size = Vector2(300, 430)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## d: { eng, result, params, anim, block, slow, running, anim_speed, tool_color, chip_color }.
func set_data(d: Dictionary) -> void:
	eng = d.get("eng", {})
	result = d.get("result", {})
	params = d.get("params", {})
	anim = d.get("anim", {})
	block = d.get("block", {})
	slow = d.get("slow", slow)
	running = bool(d.get("running", true))
	anim_speed = float(d.get("anim_speed", 1.0))
	tool_color = d.get("tool_color", tool_color)
	chip_color = d.get("chip_color", chip_color)
	_make_labels()
	_dirty = true
	queue_redraw()


## Solo lo que cambia con la animación (cada fotograma): la pasada y la cámara lenta.
func set_anim(a: Dictionary, s: Dictionary, on: bool) -> void:
	if a != anim or s != slow or on != running:
		_dirty = true
	anim = a
	slow = s
	running = on
	_make_labels()


## Un fotograma: la fresa gira a la velocidad dibujada y las virutas que salen vuelan. Con todo quieto (parada, sin
## giro ni virutas en el aire) no se redibuja.
func tick(delta: float) -> void:
	var spinning := running and float(slow.get("rev_s", 0.0)) > 0.0
	if spinning:
		theta = fmod(theta + TAU * float(slow["rev_s"]) * delta, TAU)
	var flying := not _flying.is_empty()
	_update_flying(delta)
	if spinning or flying or not _flying.is_empty() or _dirty:
		queue_redraw()
	_dirty = false


## Nada que animar (parada o sin giro, sin virutas en el aire ni cambios): la pantalla no gasta en redibujarse.
func idle() -> bool:
	return not (running and float(slow.get("rev_s", 0.0)) > 0.0) and _flying.is_empty() and not _dirty


## Ángulos φ de los dientes ahora mismo (rad, de 0 a 2π).
func tooth_angles() -> PackedFloat64Array:
	var z := maxi(int(params.get("z", 1)), 1)
	var out := PackedFloat64Array()
	for t in z:
		out.append(fmod(theta + TAU * float(t) / float(z), TAU))
	return out


func _make_labels() -> void:
	labels = {}
	var z := int(params.get("z", 0))
	labels["tool"] = "Ø%s · z = %d · κr %s°" % [Fmt.num(params.get("dc_mm"), 0), z, Fmt.num(params.get("kappa_deg"), 0)]
	labels["speed"] = "n = %s" % Fmt.unit(result.get("rpm"), 0, "rpm")
	if float(slow.get("s_per_rev", 0.0)) > 0.0:
		labels["slow"] = "dibujada a 1 vuelta cada %s (×1/%s)" % [Fmt.unit(slow["s_per_rev"], 0, "s"), Fmt.num(slow.get("factor"), 0)] if float(slow.get("factor", 1.0)) > 1.0 else "a su velocidad real"
	else:
		labels["slow"] = "parada"
	labels["vf"] = "vf = %s" % Fmt.unit(result.get("vf_mm_min"), 0, "mm/min")
	labels["position"] = str(MillDrillState.POSITIONS.get(str(params.get("position", "")), {}).get("name", ""))
	if eng.is_empty():
		labels["empty"] = "Sin contacto que dibujar: faltan datos (ap, ae, fz o la velocidad)."
		return
	labels["ae"] = "ae = %s" % Fmt.unit(eng["ae_mm"], 1 if float(eng["ae_mm"]) < 10.0 else 0, "mm")
	labels["arc"] = "arco de contacto %s°" % Fmt.num(eng["contact_deg"], 0)
	labels["entry"] = "entra con h = %s" % Fmt.unit(eng["entry_h_mm"], 3, "mm")
	labels["exit"] = "sale con h = %s" % Fmt.unit(eng["exit_h_mm"], 3, "mm")
	labels["hm"] = "hm = %s (media)" % Fmt.unit(eng["hm_mm"], 3, "mm")
	labels["hex"] = "hex = %s (máxima)" % Fmt.unit(eng["hex_mm"], 3, "mm")
	labels["zc"] = "%s dientes cortando a la vez (media)" % Fmt.num(eng["zc"], 2)
	labels["h_law"] = "h = fz·sen κ·sen φ = %s·sen φ" % Fmt.unit(eng["h_scale_mm"], 3, "mm")
	labels["scale"] = "espesor de viruta dibujado ×%s" % Fmt.num(_h_scale_mm_per_mm(), 0)
	if not anim.is_empty():
		var sp := " ×%s" % Fmt.num(anim_speed, 0) if anim_speed > 1.0 else ""
		labels["pass"] = "Pasada a tiempo real%s: %s de %s" % [sp, Fmt.seconds(anim.get("t_s")), Fmt.seconds(anim.get("pass_time_s"))]
		var e := float(anim.get("engaged", 0.0))
		labels["engaged"] = "fuera de la pieza" if e <= 0.0 else ("todo el arco en la pieza" if e >= 1.0 else "entrando: %s %% del arco" % Fmt.num(e * 100.0, 0))


## Exageración del espesor de viruta en el dibujo (mm dibujados por mm de h): hex ocupa H_DRAW_FRAC del radio.
func _h_scale_mm_per_mm() -> float:
	if eng.is_empty() or float(eng.get("hex_mm", 0.0)) <= 0.0:
		return 0.0
	return H_DRAW_FRAC * float(eng["dc_mm"]) / 2.0 / float(eng["hex_mm"])


# ─────────────────────────── virutas que salen ───────────────────────────

func _update_flying(delta: float) -> void:
	if eng.is_empty():
		_flying.clear()
		return
	var ang := tooth_angles()
	if _was_in.size() != ang.size():
		_was_in.resize(ang.size())
		_was_in.fill(0)
	var a := float(eng["phi_in"])
	var b := float(eng["phi_out"])
	for t in ang.size():
		var inside := ang[t] >= a and ang[t] <= b
		if _was_in[t] == 1 and not inside and running:
			# Sale por el final del arco: hacia fuera y en el sentido del giro
			var u := Vector2(sin(b), -cos(b))
			var tang := Vector2(cos(b), sin(b))
			_flying.append({ "pos": u * 1.0, "vel": u * 0.9 + tang * 0.6, "age": 0.0, "spin": 4.0 })
		_was_in[t] = 1 if inside else 0
	for f in _flying:
		f["age"] = float(f["age"]) + delta
		f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta
	_flying = _flying.filter(func(f: Dictionary) -> bool:
		return float(f["age"]) < 0.9 and (f["pos"] as Vector2).length() < FLY_MAX_R)


# ─────────────────────────── dibujo ───────────────────────────

func _layout() -> Dictionary:
	var w := size.x
	var h := size.y
	var wide := w >= WIDE_MIN
	var strip_h := STRIP_H if wide else STRIP_H + 14.0  # en estrecho, los dos textos de la tira van en dos filas
	var strip := Rect2(8.0, 4.0, w - 16.0, strip_h)
	var top := strip_h + 10.0
	var view: Rect2
	var graph: Rect2
	if wide:
		var gw := clampf(w * 0.38, 210.0, 330.0)
		view = Rect2(0.0, top, w - gw - 6.0, h - top)
		graph = Rect2(w - gw, top + 4.0, gw - 8.0, minf(h - top - 8.0, 280.0))
	else:
		var gh := clampf((h - top) * 0.38, 150.0, 230.0)
		view = Rect2(0.0, top, w, h - top - gh - 6.0)
		graph = Rect2(8.0, h - gh - 2.0, w - 16.0, gh)
	return { "strip": strip, "view": view, "graph": graph, "wide": wide }


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	var font := Style.font("mono")
	var lay := _layout()
	_draw_strip(font, lay["strip"], bool(lay["wide"]))
	if eng.is_empty() or float(params.get("dc_mm", 0.0)) <= 0.0:
		draw_string(font, Vector2(12, STRIP_H + 40.0), str(labels.get("empty", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 12, Style.c("gold"))
		return
	_draw_top_view(font, lay["view"])
	_draw_graph(font, lay["graph"])


## La pasada entera, a escala a lo largo del avance: la pieza, lo ya fresado y lo que ocupa la fresa ahora.
func _draw_strip(font: Font, r: Rect2, wide: bool) -> void:
	draw_string(font, r.position + Vector2(0, 11), str(labels.get("pass", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x * (0.64 if wide else 1.0), 11, Style.c("dim"))
	var eng_pos := r.position + (Vector2(r.size.x * 0.66, 11) if wide else Vector2(0, 25))
	draw_string(font, eng_pos, str(labels.get("engaged", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x * (0.34 if wide else 1.0), 11, Style.c("gold"))
	var length := float(block.get("length_mm", anim.get("length_mm", 0.0)))
	var dc := float(params.get("dc_mm", 0.0))
	if length <= 0.0 or dc <= 0.0 or anim.is_empty():
		return
	var span := length + dc + 2.0 * MillDrillState.MILL_CLEAR_MM
	var s := r.size.x / span
	var x0 := r.position.x + (dc / 2.0 + MillDrillState.MILL_CLEAR_MM) * s
	var hb := 16.0
	var yb := r.end.y - hb - 2.0
	draw_rect(Rect2(x0, yb, length * s, hb), Style.c(RAW))
	var x := float(anim.get("x_mm", 0.0))
	var cut := clampf(x, 0.0, length)
	if cut > 0.0:
		draw_rect(Rect2(x0, yb, cut * s, hb), Style.c(MILLED))
	# La fresa: su diámetro a lo largo del avance y su centro
	var xc := x0 + x * s
	var rr := dc / 2.0 * s
	var col := Style.c("gold") if bool(anim.get("cutting", false)) else Style.c("text")
	draw_rect(Rect2(xc - rr, yb - 3.0, 2.0 * rr, hb + 6.0), Color(Style.c("panel3"), 0.7))
	draw_rect(Rect2(xc - rr, yb - 3.0, 2.0 * rr, hb + 6.0), col, false, 1.5)
	draw_line(Vector2(xc, yb - 5.0), Vector2(xc, yb + hb + 5.0), col, 1.0)


## Vista desde arriba: pieza, festones del arco, fresa, dientes, virutas, cotas y flechas.
func _draw_top_view(font: Font, v: Rect2) -> void:
	var dc := float(params["dc_mm"])
	var r_mm := dc / 2.0
	# Arriba, la flecha del avance y la leyenda; abajo, la cota del diámetro y cuatro líneas de texto
	var top_pad := 46.0
	var bottom_pad := 86.0
	var avail_h := maxf(v.size.y - top_pad - bottom_pad, 60.0)
	var rp := minf(v.size.x * 0.28, avail_h * 0.40)
	var c := Vector2(v.position.x + v.size.x * 0.47, v.position.y + top_pad + avail_h / 2.0)
	var s := rp / r_mm  # px por mm
	var kh := _h_scale_mm_per_mm() * s  # px por mm de espesor de viruta
	var side := int(eng["material_side"])
	var ae := float(eng["ae_mm"])
	var left := v.position.x
	var right := v.end.x
	# Mesa (lo que no es pieza) y pieza: franja fresada y bruto
	draw_rect(v, Style.c(TABLE))
	var y_top: float  # límites de la franja que se fresa (px, pantalla)
	var y_bot: float
	if side == 0:
		y_top = c.y - ae / 2.0 * s
		y_bot = c.y + ae / 2.0 * s
	elif side > 0:  # oposición: la pieza arriba; la franja va de R − ae a R sobre el centro
		y_top = c.y - rp
		y_bot = c.y - (r_mm - ae) * s
		draw_rect(Rect2(left, v.position.y, right - left, y_top - v.position.y), Style.c(RAW))
	else:  # concordancia: la pieza abajo
		y_top = c.y + (r_mm - ae) * s
		y_bot = c.y + rp
		draw_rect(Rect2(left, y_bot, right - left, v.end.y - y_bot), Style.c(RAW))
	draw_rect(Rect2(left, y_top, right - left, y_bot - y_top), Style.c(MILLED))
	# Bruto por delante de la fresa, con el festón que deja cada diente al siguiente
	var ang := tooth_angles()
	var z := ang.size()
	var pitch := TAU / float(maxi(z, 1))
	var a := float(eng["phi_in"])
	var b := float(eng["phi_out"])
	var poly := PackedVector2Array()
	var n := 96
	for i in n + 1:
		var phi := a + (b - a) * float(i) / float(n)
		var d := _dist_ahead(phi, ang)
		var rb := rp - kh * MillDrillState.chip_h(eng, phi) * (d / pitch)
		poly.append(c + Vector2(sin(phi), -cos(phi)) * rb)
	poly.append(Vector2(right, poly[poly.size() - 1].y))
	poly.append(Vector2(right, poly[0].y))
	if Geometry2D.triangulate_polygon(poly).size() > 0:
		draw_colored_polygon(poly, Style.c(RAW))
	# Borde de la pieza fresada (la pared nueva en el fresado lateral)
	if side != 0:
		var yw := y_top if side > 0 else y_bot
		draw_line(Vector2(left, yw), Vector2(c.x, yw), Style.c("ice"), 2.0)
	# Fresa: cuerpo translúcido, dientes y virutas
	draw_circle(c, rp * 0.97, Color(Style.c("panel3"), 0.55))
	draw_arc(c, rp * 0.97, 0.0, TAU, 72, Color(Style.c("text"), 0.5), 1.0, true)
	draw_circle(c, rp * 0.22, Color(Style.c("panel2"), 0.9))
	draw_arc(c, rp * 0.22, 0.0, TAU, 32, Color(Style.c("text"), 0.4), 1.0, true)
	for t in z:
		var phi := ang[t]
		var inside := phi >= a and phi <= b
		_draw_tooth(c, rp, phi, inside)
		if inside:
			_draw_chip(c, rp, phi, kh, a, b)
	for f in _flying:
		var p: Vector2 = c + (f["pos"] as Vector2) * rp
		var alpha := clampf(1.0 - float(f["age"]) / 0.9, 0.0, 1.0)
		var hh := maxf(kh * float(eng["hm_mm"]), 2.0)
		var dir := (f["vel"] as Vector2).normalized()
		var poly2 := PackedVector2Array([p, p + dir * hh * 3.0 + dir.orthogonal() * hh, p + dir * hh * 2.0 - dir.orthogonal() * hh * 0.6])
		draw_colored_polygon(poly2, Color(chip_color, alpha))
	# Arco de contacto por fuera, con la entrada y la salida
	var ra := rp + 12.0
	draw_arc(c, ra, a - PI / 2.0, b - PI / 2.0, 48, Style.c("gold"), 3.0, true)
	for ep in [[a, str(labels.get("entry", ""))], [b, str(labels.get("exit", ""))]]:
		var phi: float = ep[0]
		var u := Vector2(sin(phi), -cos(phi))
		draw_line(c + u * (rp - 4.0), c + u * (ra + 6.0), Style.c("gold"), 1.5)
		_label_near(font, c + u * (ra + 10.0), u, ep[1], Style.c("gold"), v)
	# Giro (M03: horario visto desde arriba) en la parte de atrás de la fresa
	var g0 := PI * 1.18
	var g1 := PI * 1.62
	draw_arc(c, rp + 7.0, g0 - PI / 2.0, g1 - PI / 2.0, 20, Style.c("mint"), 2.0, true)
	var tip := c + Vector2(sin(g1), -cos(g1)) * (rp + 7.0)
	var tdir := Vector2(cos(g1), sin(g1))
	draw_colored_polygon(PackedVector2Array([tip + tdir * 7.0, tip - tdir * 2.0 + tdir.orthogonal() * 5.0, tip - tdir * 2.0 - tdir.orthogonal() * 5.0]), Style.c("mint"))
	# Avance de la fresa
	var fy := v.position.y + 16.0
	var fx := c.x - rp
	draw_line(Vector2(fx, fy), Vector2(fx + 58.0, fy), Style.c("mint"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(fx + 64.0, fy), Vector2(fx + 56.0, fy - 5.0), Vector2(fx + 56.0, fy + 5.0)]), Style.c("mint"))
	draw_string(font, Vector2(fx + 70.0, fy + 4.0), "avance · " + str(labels.get("vf", "")), HORIZONTAL_ALIGNMENT_LEFT, right - fx - 76.0, 11, Style.c("mint"))
	# Cota de ae (a la izquierda, sobre lo ya fresado, con el texto girado) y del diámetro (debajo)
	_dim_v(font, left + 12.0, y_top, y_bot, str(labels.get("ae", "")))
	var yd := c.y + rp + 16.0
	draw_line(Vector2(c.x - rp, yd), Vector2(c.x + rp, yd), Style.c("dim"), 1.0)
	for xx in [c.x - rp, c.x + rp]:
		draw_line(Vector2(xx, yd - 4.0), Vector2(xx, yd + 4.0), Style.c("dim"), 1.0)
	_centered(font, Vector2(c.x, yd + 14.0), str(labels.get("tool", "")), 11, Style.c("text"))
	# Textos de la vista
	var rows := [
		["%s · %s" % [str(labels.get("speed", "")), str(labels.get("slow", ""))], Style.c("dim"), 11],
		["%s · %s" % [str(labels.get("position", "")), str(labels.get("arc", ""))], Style.c("gold"), 11],
		[str(labels.get("zc", "")), Style.c("text"), 11],
		[str(labels.get("scale", "")), Style.c("dimmer"), 10],
	]
	var ty := v.end.y - 8.0 - 13.0 * float(rows.size() - 1)
	for row in rows:
		draw_string(font, Vector2(left + 8.0, ty), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, v.size.x - 16.0, int(row[2]), row[1])
		ty += 13.0
	# Leyenda de colores
	var lx := left + 8.0
	var ly := v.position.y + 30.0
	draw_rect(Rect2(lx - 4.0, ly - 12.0, 72.0, 46.0), Color(Style.c("bg2"), 0.85))
	for it in [[RAW, "bruto"], [MILLED, "fresado"], ["", "viruta"]]:
		var col: Color = chip_color if it[0] == "" else Style.c(it[0])
		draw_rect(Rect2(lx, ly - 8.0, 10.0, 10.0), col)
		draw_rect(Rect2(lx, ly - 8.0, 10.0, 10.0), Style.c("dim"), false, 1.0)
		draw_string(font, Vector2(lx + 14.0, ly + 1.0), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dim"))
		ly += 14.0


## Distancia angular (rad) desde φ hasta el primer diente por delante (el último que pasó por φ).
func _dist_ahead(phi: float, ang: PackedFloat64Array) -> float:
	var best := TAU
	for t in ang:
		var d := fmod(t - phi + 2.0 * TAU, TAU)
		best = minf(best, d)
	return best


## Un diente: la plaquita (o el filo de la fresa enteriza) en la periferia, con el color del recubrimiento.
func _draw_tooth(c: Vector2, rp: float, phi: float, cutting: bool) -> void:
	var u := Vector2(sin(phi), -cos(phi))
	var t := Vector2(cos(phi), sin(phi))  # sentido del giro
	var len := clampf(rp * 0.2, 6.0, 16.0)
	var w := clampf(rp * 0.12, 4.0, 10.0)
	var tip := c + u * rp
	var quad := PackedVector2Array([tip, tip - u * len, tip - u * len - t * w, tip - t * w * 0.8])
	draw_colored_polygon(quad, tool_color if not cutting else tool_color.lightened(0.25))
	quad.append(quad[0])
	draw_polyline(quad, Style.c("gold") if cutting else Color(Style.c("text"), 0.6), 1.5 if cutting else 1.0, true)


## La viruta de un diente que corta: en su cara, con el espesor que corta ahora (exagerado) y más larga cuanto más arco
## lleva recorrido.
func _draw_chip(c: Vector2, rp: float, phi: float, kh: float, a: float, b: float) -> void:
	var h := maxf(kh * MillDrillState.chip_h(eng, phi), 1.5)
	var frac := clampf((phi - a) / maxf(b - a, 1e-6), 0.0, 1.0)
	var u := Vector2(sin(phi), -cos(phi))
	var t := Vector2(cos(phi), sin(phi))
	var base := c + u * rp + t * 1.5
	var length := 4.0 + frac * rp * 0.32
	# Se enrolla hacia dentro (la cara de desprendimiento la desvía hacia el hueco de la viruta)
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var q := float(i) / float(steps)
		var bend := q * q * 1.6
		var dir := (t * cos(bend) - u * sin(bend)).normalized()
		var p := base + (t * 0.6 - u * 0.4).normalized() * length * q + dir * length * 0.25 * q
		var thick := h * (1.0 - 0.5 * q)
		pts.append(p)
		inner.append(p - u * thick)
	inner.reverse()
	pts.append_array(inner)
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		draw_colored_polygon(pts, chip_color)


## Curva h(φ) de 0 a 180°: el arco de contacto resaltado, hm, hex y un punto por diente que corta.
func _draw_graph(font: Font, g: Rect2) -> void:
	draw_rect(g, Style.c("bg"))
	draw_string(font, g.position + Vector2(8, 14), "Espesor de viruta de cada diente", HORIZONTAL_ALIGNMENT_LEFT, g.size.x - 16.0, 11, Style.c("text"))
	draw_string(font, g.position + Vector2(8, 28), str(labels.get("h_law", "")), HORIZONTAL_ALIGNMENT_LEFT, g.size.x - 16.0, 10, Style.c("dim"))
	var p := Rect2(g.position + Vector2(40, 48), g.size - Vector2(52, 82))
	if p.size.x < 40.0 or p.size.y < 30.0:
		return
	var hs := float(eng["h_scale_mm"])
	var ytop := hs * 1.15 if hs > 0.0 else 1.0
	var samples: PackedFloat64Array = eng["h_samples"]
	var ns := samples.size()
	var a := float(eng["phi_in"])
	var b := float(eng["phi_out"])
	# Ejes
	draw_line(Vector2(p.position.x, p.end.y), p.end, Style.c("line2"), 1.0)
	draw_line(p.position, Vector2(p.position.x, p.end.y), Style.c("line2"), 1.0)
	for deg in [0, 45, 90, 135, 180]:
		var x := p.position.x + p.size.x * float(deg) / 180.0
		draw_line(Vector2(x, p.end.y), Vector2(x, p.end.y + 3.0), Style.c("line2"), 1.0)
		_centered(font, Vector2(x, p.end.y + 14.0), "%d°" % deg, 10, Style.c("dimmer"))
	draw_string(font, Vector2(p.position.x, g.end.y - 6.0), "ángulo del diente φ", HORIZONTAL_ALIGNMENT_LEFT, p.size.x, 10, Style.c("dim"))
	draw_string(font, Vector2(g.position.x + 4.0, p.position.y + 4.0), "h", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("dim"))
	# Arco de contacto sombreado
	var xa := p.position.x + p.size.x * a / PI
	var xb := p.position.x + p.size.x * b / PI
	draw_rect(Rect2(xa, p.position.y, xb - xa, p.size.y), Color(Style.c("gold"), 0.08))
	# Curva: tenue fuera del arco, resaltada dentro
	for i in range(1, ns):
		var p0 := Vector2(p.position.x + p.size.x * float(i - 1) / float(ns - 1), p.end.y - samples[i - 1] / ytop * p.size.y)
		var p1 := Vector2(p.position.x + p.size.x * float(i) / float(ns - 1), p.end.y - samples[i] / ytop * p.size.y)
		var phi_mid := PI * (float(i) - 0.5) / float(ns - 1)
		var on := phi_mid >= a and phi_mid <= b
		draw_line(p0, p1, Style.c("mint") if on else Color(Style.c("dim"), 0.35), 2.0 if on else 1.0, true)
	# hm (línea) y hex (punto más alto dentro del arco)
	var yhm := p.end.y - float(eng["hm_mm"]) / ytop * p.size.y
	var xx := xa
	while xx < xb:
		draw_line(Vector2(xx, yhm), Vector2(minf(xx + 5.0, xb), yhm), Style.c("gold"), 1.5)
		xx += 9.0
	# Rótulos: hm justo encima de su línea y hex por encima (nunca encima del subtítulo)
	var y_hm_label := maxf(yhm - 4.0, p.position.y + 22.0)
	draw_string(font, Vector2(p.position.x + 4.0, y_hm_label), str(labels.get("hm", "")), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 8.0, 10, Style.c("gold"))
	var yhex := p.end.y - float(eng["hex_mm"]) / ytop * p.size.y
	var y_hex_label := minf(maxf(yhex - 4.0, p.position.y + 8.0), y_hm_label - 13.0)
	draw_string(font, Vector2(p.position.x + 4.0, y_hex_label), str(labels.get("hex", "")), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 8.0, 10, Style.c("mint"))
	# Un punto por diente que corta, a su φ y con el h del core
	for phi in tooth_angles():
		if phi < a or phi > b:
			continue
		var x := p.position.x + p.size.x * phi / PI
		var y := p.end.y - MillDrillState.chip_h(eng, phi) / ytop * p.size.y
		draw_circle(Vector2(x, y), 4.5, Style.c("gold"))
	# Marcas de h
	for f: float in [0.0, 0.5, 1.0]:
		var hv := hs * f
		var y := p.end.y - hv / ytop * p.size.y
		var t := Fmt.num(hv, 3)
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, Vector2(p.position.x - tw - 4.0, y + 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.c("dimmer"))


## Cota vertical con su texto girado a lo largo de ella (si no cabe en la cota, sale de ella hacia abajo).
func _dim_v(font: Font, x: float, y0: float, y1: float, text: String) -> void:
	draw_line(Vector2(x, y0), Vector2(x, y1), Style.c("ice"), 1.0)
	for y in [y0, y1]:
		draw_line(Vector2(x - 5.0, y), Vector2(x + 5.0, y), Style.c("ice"), 1.0)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var yc := (y0 + y1) / 2.0 + tw / 2.0
	draw_set_transform(Vector2(x + 13.0, yc), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("ice"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Texto junto a un punto, hacia fuera según u, sin salirse de la vista.
func _label_near(font: Font, p: Vector2, u: Vector2, text: String, col: Color, v: Rect2) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := p.x if u.x >= 0.0 else p.x - tw
	x = clampf(x, v.position.x + 2.0, v.end.x - tw - 2.0)
	var y := clampf(p.y + (4.0 if u.y >= 0.0 else 0.0), v.position.y + 12.0, v.end.y - 4.0)
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


func _centered(font: Font, bottom_center: Vector2, text: String, fsize: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var x := clampf(bottom_center.x - tw / 2.0, 2.0, maxf(2.0, size.x - tw - 2.0))
	draw_string(font, Vector2(x, bottom_center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
