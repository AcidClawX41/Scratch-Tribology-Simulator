## Taller industrial · esquema animado del taladrado en sección (unidad 1e).
##
## - A la izquierda (o arriba, en el teléfono), la pieza cortada por el eje con el agujero que va quedando, y la broca
##   bajando a su avance real (el ciclo de MillDrillState: aproximación, taladrado, retirada), con sus dos gargantas
##   helicoidales girando en cámara lenta (la velocidad real, escrita), los filos encendidos mientras cortan, las
##   virutas subiendo por las gargantas (forma y color del core), el empuje, el par y el ángulo de punta.
## - A la derecha (o debajo), un filo de cerca: la capa que arranca cada filo en media vuelta, con su largo b, su espesor
##   h y el avance por filo f/2, exagerados con la escala escrita.
## Todos los números salen de MillDrillState (y este de cutting.gd): aquí solo se dibujan. Los textos quedan en `labels`.
extends Control

const Style = preload("res://app/taller/ui/style.gd")
const Fmt = preload("res://app/taller/ui/fmt.gd")
const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const Rng = preload("res://core/shared/rng.gd")

## Vueltas por segundo que se dibujan como mucho (cámara lenta).
const SHOWN_REV_S := 0.5
const WIDE_MIN := 560.0
## Ancho angular de cada garganta (dibujo) y virutas que se dibujan como mucho.
const FLUTE_W := 0.55 * PI
const MAX_CHIPS := 48
const PHASES := {
	"aproximacion": "aproximación en rápido", "taladrando": "taladrando", "retirada": "retirada en rápido",
	"pausa": "pausa entre agujeros",
}
const RAW := "line2"
const HOLE := "bg"

var geo: Dictionary = {}
var result: Dictionary = {}
var params: Dictionary = {}
var anim: Dictionary = {}
var slow: Dictionary = { "rev_s": 0.0, "time_scale": 1.0, "factor": 1.0, "s_per_rev": 0.0 }
var running := true
var anim_speed := 1.0
var coolant := false
var tool_color := Color("#BCA9C7")
var chip_color := Color.WHITE
var chip_form := "rizada"
var work_name := ""
## Textos que se dibujan (nombre → texto).
var labels := {}
## Giro dibujado de la broca (rad).
var theta := 0.0
var _chips: Array = []  # { y, x, side, vy, vx, age, out }
var _rng := Rng.new(Rng.seed_of("taladro:virutas"))
var _emit := 0.0
var _dirty := true  # algo cambió desde el último dibujo (con la máquina quieta no se redibuja: CONTRATOS, rendimiento)


func _init() -> void:
	custom_minimum_size = Vector2(300, 430)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## d: { geo, result, params, anim, slow, running, anim_speed, coolant, tool_color, chip_color, chip_form, work_name }.
func set_data(d: Dictionary) -> void:
	geo = d.get("geo", {})
	result = d.get("result", {})
	params = d.get("params", {})
	anim = d.get("anim", {})
	slow = d.get("slow", slow)
	running = bool(d.get("running", true))
	anim_speed = float(d.get("anim_speed", 1.0))
	coolant = bool(d.get("coolant", false))
	tool_color = d.get("tool_color", tool_color)
	chip_color = d.get("chip_color", chip_color)
	chip_form = str(d.get("chip_form", chip_form))
	work_name = str(d.get("work_name", ""))
	_make_labels()
	_dirty = true
	queue_redraw()


## Solo lo que cambia con la animación (cada fotograma).
func set_anim(a: Dictionary, s: Dictionary, on: bool) -> void:
	if a != anim or s != slow or on != running:
		_dirty = true
	anim = a
	slow = s
	running = on
	_make_labels()


## Un fotograma: la broca gira a la velocidad dibujada y las virutas suben y caen. Con todo quieto (parada, sin giro ni
## virutas) no se redibuja.
func tick(delta: float) -> void:
	var spinning := running and float(slow.get("rev_s", 0.0)) > 0.0
	if spinning:
		theta = fmod(theta + TAU * float(slow["rev_s"]) * delta, TAU)
	var busy := not _chips.is_empty()
	_update_chips(delta)
	if spinning or busy or not _chips.is_empty() or _dirty:
		queue_redraw()
	_dirty = false


## Nada que animar (parada o sin giro, sin virutas ni cambios): la pantalla no gasta en redibujarse.
func idle() -> bool:
	return not (running and float(slow.get("rev_s", 0.0)) > 0.0) and _chips.is_empty() and not _dirty


func _make_labels() -> void:
	labels = {}
	labels["speed"] = "n = %s · f = %s · vf = %s" % [Fmt.unit(result.get("rpm"), 0, "rpm"),
		Fmt.unit(params.get("f_mm_rev"), 2, "mm/vuelta"), Fmt.unit(result.get("vf_mm_min"), 0, "mm/min")]
	if float(slow.get("s_per_rev", 0.0)) > 0.0 and float(slow.get("factor", 1.0)) > 1.0:
		labels["slow"] = "giro dibujado: 1 vuelta cada %s (×1/%s)" % [Fmt.unit(slow["s_per_rev"], 0, "s"), Fmt.num(slow.get("factor"), 0)]
	elif float(slow.get("s_per_rev", 0.0)) > 0.0:
		labels["slow"] = "giro a su velocidad real"
	else:
		labels["slow"] = "parada"
	labels["feed"] = "avance a tiempo real%s" % ((" ×%s" % Fmt.num(anim_speed, 0)) if anim_speed > 1.0 else "")
	labels["phase"] = str(PHASES.get(str(anim.get("phase", "")), ""))
	labels["time"] = "tiempo del agujero: %s de %s" % [Fmt.seconds(anim.get("t_s")), Fmt.seconds(geo.get("time_s"))]
	labels["depth"] = "%s de %s" % [Fmt.num(anim.get("hole_mm"), 1), Fmt.unit(params.get("depth_mm"), 0, "mm")]
	labels["diameter"] = "Ø%s" % Fmt.num(geo.get("d_mm"), 1 if float(geo.get("d_mm", 0.0)) != floorf(float(geo.get("d_mm", 0.0))) else 0)
	labels["sigma"] = "σ = %s°" % Fmt.num(geo.get("sigma_deg"), 0)
	var rec: Dictionary = geo.get("point_rec", {})
	if not rec.is_empty() and float(rec["value"]) != float(geo.get("sigma_deg", 0.0)):
		labels["sigma_rec"] = "para %s se recomienda %s°" % [work_name, Fmt.num(rec["value"], 0)]
	labels["thrust"] = "empuje %s" % Fmt.unit(result.get("thrust_n"), 0, "N")
	labels["torque"] = "par %s" % Fmt.unit(result.get("torque_nm"), 1, "N·m")
	labels["b"] = "b = %s (largo del filo)" % Fmt.unit(geo.get("b_mm"), 2, "mm")
	labels["h"] = "h = (f/2)·sen(σ/2) = %s" % Fmt.unit(geo.get("h_mm"), 3, "mm")
	labels["fz"] = "f/2 = %s por filo" % Fmt.unit(geo.get("fz_mm"), 3, "mm")
	labels["area"] = "A = b·h = D·f/4 = %s por filo" % Fmt.unit(geo.get("area_mm2"), 3, "mm²")
	labels["vc"] = "vc: %s en la esquina y 0 en el eje" % Fmt.unit(result.get("vc"), 0, "m/min")
	labels["fc"] = "Fc por filo %s" % Fmt.unit(result.get("fc_edge_n"), 0, "N")
	var helix: Dictionary = geo.get("helix", {})
	labels["helix"] = "hélice %s (%s–%s°)" % [str(helix.get("name", "")), Fmt.num(helix.get("min"), 0), Fmt.num(helix.get("max"), 0)] if not helix.is_empty() else ""
	labels["scale"] = "espesores dibujados ×%s" % Fmt.num(_detail_scale(), 0)


## Exageración del espesor en el detalle del filo: el avance por filo ocupa ~14 % del largo del filo dibujado.
func _detail_scale() -> float:
	var fz := float(geo.get("fz_mm", 0.0))
	var b := float(geo.get("b_mm", 0.0))
	if fz <= 0.0 or b <= 0.0 or is_nan(b):
		return 0.0
	return 0.14 * b / fz


# ─────────────────────────── virutas ───────────────────────────

## Las virutas nacen en los filos mientras cortan, suben por las gargantas (una hélice por vuelta dibujada) y al salir
## del agujero caen a los lados, sobre la pieza.
func _update_chips(delta: float) -> void:
	var d := float(geo.get("d_mm", 0.0))
	var tip := float(geo.get("tip_mm", 0.0))
	if d <= 0.0 or is_nan(tip):
		_chips.clear()
		return
	var rev := float(slow.get("rev_s", 0.0)) if running else 0.0
	var lead := _lead_mm()
	if bool(anim.get("cutting", false)) and rev > 0.0:
		# Trozos que se dibujan por vuelta dibujada (dibujo, no una medida): muchos y pequeños si la viruta se astilla
		var per_rev := { "astillada": 14.0, "espiral": 4.0 }.get(chip_form, 7.0) as float
		_emit += per_rev * rev * delta * clampf(float(anim.get("engaged", 0.0)), 0.2, 1.0)
		while _emit >= 1.0 and _chips.size() < MAX_CHIPS:
			_emit -= 1.0
			var side := -1.0 if _rng.next() < 0.5 else 1.0
			_chips.append({
				"y": float(anim.get("depth_mm", 0.0)) - tip * (0.3 + 0.5 * _rng.next()), "x": side * d * 0.25,
				"side": side, "vy": -lead * rev * (0.8 + 0.4 * _rng.next()), "vx": 0.0, "age": 0.0, "out": false,
				"size": 0.7 + 0.6 * _rng.next(),
			})
		_emit = minf(_emit, 1.0)
	for c in _chips:
		c["age"] = float(c["age"]) + delta
		if not bool(c["out"]):
			c["y"] = float(c["y"]) + float(c["vy"]) * delta
			if float(c["y"]) < -0.5:
				c["out"] = true
				c["vx"] = float(c["side"]) * d * (1.5 + _rng.next())
				c["vy"] = -d * 0.8
		else:
			# Fuera del agujero: sale hacia un lado y cae sobre la pieza
			c["x"] = float(c["x"]) + float(c["vx"]) * delta
			c["vy"] = float(c["vy"]) + d * 6.0 * delta
			c["y"] = minf(float(c["y"]) + float(c["vy"]) * delta, -0.3)
			c["vx"] = float(c["vx"]) * maxf(0.0, 1.0 - 2.5 * delta)
	_chips = _chips.filter(func(c: Dictionary) -> bool: return float(c["age"]) < 4.0)


## Paso de la hélice (mm por vuelta): π·D/tan β, con β el centro del intervalo de la hélice que dan las tablas del afilado.
func _lead_mm() -> float:
	var hx: Dictionary = geo.get("helix", {})
	var beta := deg_to_rad(float(hx.get("deg", 25.0)))
	return PI * float(geo.get("d_mm", 10.0)) / maxf(tan(beta), 0.05)


# ─────────────────────────── dibujo ───────────────────────────

func _layout() -> Dictionary:
	var w := size.x
	var h := size.y
	if w >= WIDE_MIN:
		var dw := clampf(w * 0.40, 220.0, 330.0)
		return { "section": Rect2(0.0, 0.0, w - dw - 6.0, h), "detail": Rect2(w - dw, 0.0, dw, h), "wide": true }
	var dh := clampf(h * 0.42, 220.0, 300.0)
	return { "section": Rect2(0.0, 0.0, w, h - dh - 6.0), "detail": Rect2(0.0, h - dh, w, dh), "wide": false }


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Style.c("bg2"))
	var font := Style.font("mono")
	var d := float(geo.get("d_mm", 0.0))
	var tip := float(geo.get("tip_mm", NAN))
	if d <= 0.0 or is_nan(tip) or anim.is_empty():
		draw_string(font, Vector2(12, 40), "Sin broca que dibujar: faltan el diámetro o el ángulo de punta.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 12, Style.c("gold"))
		return
	var lay := _layout()
	_draw_section(font, lay["section"], d, tip)
	_draw_detail(font, lay["detail"])


func _draw_section(font: Font, sec: Rect2, d: float, tip: float) -> void:
	var r := d / 2.0
	var depth := float(anim.get("depth_mm", 0.0))
	var target := float(anim.get("target_mm", tip))
	var top_mm := -(MillDrillState.DRILL_CLEAR_MM + 0.8 * d + 4.0)
	var bottom_mm := target + maxf(0.35 * d, 3.0)
	var text_h := 70.0
	var avail := Rect2(sec.position + Vector2(8, 40), sec.size - Vector2(16, 40 + text_h))
	var s := minf(avail.size.y / (bottom_mm - top_mm), avail.size.x * 0.26 / d)
	var cx := avail.position.x + avail.size.x * 0.46
	var y0 := avail.position.y
	var sy := func(y_mm: float) -> float: return y0 + (y_mm - top_mm) * s
	var y_surf: float = sy.call(0.0)
	# Pieza en sección (rayada) con el agujero que va quedando
	var plate := Rect2(avail.position.x + 4.0, y_surf, avail.size.x - 8.0, sec.end.y - text_h - y_surf)
	draw_rect(plate, Style.c(RAW))
	_hatch(plate, Color(Style.c("line"), 0.9), 9.0)
	var bottom := float(anim.get("bottom_mm", 0.0))
	if bottom > 0.0:
		var hole := PackedVector2Array()
		if bottom < tip:
			var rr := bottom * r / tip
			hole = PackedVector2Array([Vector2(cx - rr * s, y_surf), Vector2(cx + rr * s, y_surf), Vector2(cx, sy.call(bottom))])
		else:
			hole = PackedVector2Array([Vector2(cx - r * s, y_surf), Vector2(cx + r * s, y_surf), Vector2(cx + r * s, sy.call(bottom - tip)),
				Vector2(cx, sy.call(bottom)), Vector2(cx - r * s, sy.call(bottom - tip))])
		draw_colored_polygon(hole, Style.c(HOLE))
		# pared del fondo del agujero, con un poco de sombra
		for k in 3:
			var xx := cx + (float(k) - 1.0) * r * s * 0.6
			draw_line(Vector2(xx, y_surf + 2.0), Vector2(xx, sy.call(maxf(bottom - tip, 0.0))), Color(Style.c("panel3"), 0.5), 1.0)
	draw_line(Vector2(plate.position.x, y_surf), Vector2(plate.end.x, y_surf), Style.c("text"), 1.0)
	draw_string(font, Vector2(plate.position.x + 4.0, plate.end.y - 6.0), work_name, HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 8.0, 10, Style.c("dim"))
	# Taladrina
	if coolant:
		var nz := Vector2(cx - r * s - 46.0, y_surf - 40.0)
		draw_line(nz, Vector2(cx - r * s * 0.3, y_surf - 2.0), Color(Style.c("ice"), 0.7), 3.0, true)
		draw_circle(nz, 5.0, Style.c("ice"))
	# Broca: cuerpo, punta y gargantas; los filos se encienden al cortar
	var y_tip: float = sy.call(depth)
	var y_shoulder: float = sy.call(depth - tip)
	var y_top := sec.position.y + 36.0
	if y_shoulder > y_top:
		draw_rect(Rect2(cx - r * s, y_top, 2.0 * r * s, y_shoulder - y_top), tool_color)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - r * s, y_shoulder), Vector2(cx + r * s, y_shoulder), Vector2(cx, y_tip)]), tool_color)
	_draw_flutes(y_top, y_shoulder, y_tip, cx, r * s, s)
	var lip_col := Style.c("gold") if bool(anim.get("cutting", false)) else Color(Style.c("text"), 0.7)
	draw_line(Vector2(cx - r * s, y_shoulder), Vector2(cx, y_tip), lip_col, 2.5 if bool(anim.get("cutting", false)) else 1.2, true)
	draw_line(Vector2(cx + r * s, y_shoulder), Vector2(cx, y_tip), lip_col, 2.5 if bool(anim.get("cutting", false)) else 1.2, true)
	draw_line(Vector2(cx - r * s, y_top), Vector2(cx - r * s, y_shoulder), Color(Style.c("text"), 0.6), 1.0)
	draw_line(Vector2(cx + r * s, y_top), Vector2(cx + r * s, y_shoulder), Color(Style.c("text"), 0.6), 1.0)
	# Virutas (con un contorno oscuro para que se vean sobre la broca y sobre la pieza)
	for c in _chips:
		var p := Vector2(cx + float(c["x"]) * s, sy.call(float(c["y"])))
		if p.y < y_top:
			continue
		_draw_chip(p, float(c["size"]) * clampf(d * s * 0.16, 5.0, 14.0), float(c["age"]) * 5.0)
	# Ángulo de punta
	var ra := clampf(tip * s * 0.55, 12.0, 34.0)
	var half := deg_to_rad(float(geo.get("sigma_deg", 118.0)) / 2.0)
	draw_arc(Vector2(cx, y_tip), ra, -PI / 2.0 - half, -PI / 2.0 + half, 20, Style.c("gold"), 1.5, true)
	draw_string(font, Vector2(cx + r * s + 8.0, y_tip + 4.0), str(labels.get("sigma", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("gold"))
	if labels.has("sigma_rec"):
		draw_string(font, Vector2(cx + r * s + 8.0, y_tip + 18.0), str(labels["sigma_rec"]), HORIZONTAL_ALIGNMENT_LEFT, sec.end.x - cx - r * s - 12.0, 10, Style.c("coral"))
	# Empuje (hacia abajo, sobre el eje) y par (alrededor del cuerpo)
	var ay := sec.position.y + 6.0
	draw_line(Vector2(cx, ay), Vector2(cx, ay + 22.0), Style.c("coral"), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, ay + 30.0), Vector2(cx - 6.0, ay + 20.0), Vector2(cx + 6.0, ay + 20.0)]), Style.c("coral"))
	draw_string(font, Vector2(cx + 10.0, ay + 14.0), str(labels.get("thrust", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("coral"))
	var ty := y_top + 18.0
	var ex := r * s + 10.0
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI * 0.15 + PI * 0.7 * float(i) / 16.0
		pts.append(Vector2(cx + cos(a) * ex, ty + sin(a) * ex * 0.3))
	draw_polyline(pts, Style.c("mint"), 2.0, true)
	var e0 := pts[0]
	draw_colored_polygon(PackedVector2Array([e0 + Vector2(8.0, -2.0), e0 + Vector2(-1.0, -6.0), e0 + Vector2(-1.0, 5.0)]), Style.c("mint"))
	draw_string(font, Vector2(cx - ex - 4.0 - font.get_string_size(str(labels.get("torque", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, ty + 4.0), str(labels.get("torque", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("mint"))
	# Cotas: diámetro sobre la pieza y hondo del agujero a la izquierda
	var xd := cx - r * s - 18.0
	var hole_mm := float(anim.get("hole_mm", 0.0))
	draw_line(Vector2(xd, y_surf), Vector2(xd, sy.call(hole_mm)), Style.c("ice"), 1.0)
	draw_line(Vector2(xd - 4.0, y_surf), Vector2(xd + 4.0, y_surf), Style.c("ice"), 1.0)
	draw_line(Vector2(xd - 4.0, sy.call(hole_mm)), Vector2(xd + 4.0, sy.call(hole_mm)), Style.c("ice"), 1.0)
	var dl := str(labels.get("depth", ""))
	var dw := font.get_string_size(dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(maxf(sec.position.x + 2.0, xd - dw - 4.0), y_surf + 14.0), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("ice"))
	draw_string(font, Vector2(cx + r * s + 6.0, y_surf - 6.0), str(labels.get("diameter", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.c("text"))
	# Textos
	var by := sec.end.y - text_h + 16.0
	draw_string(font, Vector2(sec.position.x + 8.0, by), "%s · %s" % [str(labels.get("phase", "")), str(labels.get("time", ""))], HORIZONTAL_ALIGNMENT_LEFT, sec.size.x - 16.0, 11, Style.c("text"))
	draw_string(font, Vector2(sec.position.x + 8.0, by + 15.0), str(labels.get("speed", "")), HORIZONTAL_ALIGNMENT_LEFT, sec.size.x - 16.0, 11, Style.c("dim"))
	draw_string(font, Vector2(sec.position.x + 8.0, by + 30.0), "%s · %s" % [str(labels.get("slow", "")), str(labels.get("feed", ""))] if sec.size.x >= 520.0 else str(labels.get("slow", "")), HORIZONTAL_ALIGNMENT_LEFT, sec.size.x - 16.0, 10, Style.c("dimmer"))
	if sec.size.x < 520.0:
		draw_string(font, Vector2(sec.position.x + 8.0, by + 43.0), str(labels.get("feed", "")), HORIZONTAL_ALIGNMENT_LEFT, sec.size.x - 16.0, 10, Style.c("dimmer"))


## Las dos gargantas helicoidales vistas de frente: bandas oscuras que suben al girar (una broca a derechas girando en
## M03 lleva la viruta hacia arriba). Se dibujan por líneas horizontales.
func _draw_flutes(y_top: float, y_shoulder: float, y_tip: float, cx: float, r_px: float, s: float) -> void:
	var lead_px := _lead_mm() * s
	if lead_px <= 0.0 or r_px < 2.0:
		return
	var dark := tool_color.darkened(0.45)
	var y := maxf(y_top, 0.0)
	var step := 2.0
	while y < y_tip:
		var half := r_px if y <= y_shoulder else r_px * (y_tip - y) / maxf(y_tip - y_shoulder, 1e-6)
		var phase := TAU * (y_tip - y) / lead_px - theta
		for k in 2:
			var lo := wrapf(phase + PI * float(k), -PI, PI)
			for shift in [0.0, -TAU]:
				var a0: float = lo + shift
				var i0 := maxf(a0, -PI / 2.0)
				var i1 := minf(a0 + FLUTE_W, PI / 2.0)
				if i1 > i0:
					draw_line(Vector2(cx + sin(i0) * half, y), Vector2(cx + sin(i1) * half, y), dark, step + 0.5)
		y += step


func _draw_chip(p: Vector2, sz: float, spin: float) -> void:
	var edge := Style.c("bg")
	match chip_form:
		"astillada":
			var tri := PackedVector2Array([p + Vector2(cos(spin), sin(spin)) * sz * 0.6, p + Vector2(cos(spin + 2.2), sin(spin + 2.2)) * sz * 0.5,
				p + Vector2(cos(spin + 4.0), sin(spin + 4.0)) * sz * 0.55])
			draw_colored_polygon(tri, chip_color)
			tri.append(tri[0])
			draw_polyline(tri, edge, 1.0, true)
		"espiral":
			var pts := PackedVector2Array()
			for i in 13:
				var a := spin + float(i) * 0.9
				pts.append(p + Vector2(cos(a) * sz * 0.7, sin(a) * sz * 0.35 + (float(i) - 6.0) * sz * 0.12))
			draw_polyline(pts, edge, maxf(sz * 0.18, 1.5) + 2.0, true)
			draw_polyline(pts, chip_color, maxf(sz * 0.18, 1.5), true)
		_:
			draw_arc(p, sz * 0.6, spin, spin + PI * 1.4, 10, edge, maxf(sz * 0.25, 1.5) + 2.0, true)
			draw_arc(p, sz * 0.6, spin, spin + PI * 1.4, 10, chip_color, maxf(sz * 0.25, 1.5), true)


## Un filo de cerca: la capa que arranca en media vuelta (entre la pasada del otro filo, f/2 más arriba, y la suya).
func _draw_detail(font: Font, r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Style.c("bg"))
	draw_string(font, r.position + Vector2(12, 22), "Un filo, de cerca", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Style.c("text"))
	draw_string(font, r.position + Vector2(12, 36), str(labels.get("scale", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 10, Style.c("dimmer"))
	var k := _detail_scale()
	var half := deg_to_rad(float(geo.get("sigma_deg", 118.0)) / 2.0)
	var b := float(geo.get("b_mm", 0.0))
	if k <= 0.0 or b <= 0.0 or is_nan(b):
		return
	var keys := ["b", "h", "fz", "area", "fc", "vc"]
	var text_h := 14.0 * float(keys.size()) + 8.0
	# Dibujo arriba (como mucho tan alto como ancho) y los textos justo debajo
	var area_h := minf(r.size.y - 60.0 - text_h, (r.size.x - 48.0) * 0.8)
	var area := Rect2(r.position + Vector2(24, 50), Vector2(r.size.x - 48.0, maxf(area_h, 40.0)))
	# El filo va del eje (abajo a la izquierda) a la esquina (arriba a la derecha), a σ/2 del eje
	var u := Vector2(sin(half), -cos(half))
	var lb := minf((area.size.x - 16.0) / maxf(u.x, 0.2), area.size.y * 0.72 / maxf(-u.y, 0.2))
	var px_mm := lb / b
	var p0 := Vector2(area.position.x + 6.0, area.end.y - 4.0)
	var p1 := p0 + u * lb
	var up := Vector2(0.0, -float(geo.get("fz_mm", 0.0)) * k * px_mm)
	# Capa que arranca el filo (entre la pasada del otro filo, media vuelta antes, y la suya), color de la viruta
	var band := PackedVector2Array([p0, p1, p1 + up, p0 + up])
	draw_colored_polygon(band, Color(chip_color, 0.85))
	# Eje de la broca, filo actual y pasada anterior
	var y := area.position.y
	while y < p0.y:
		draw_line(Vector2(p0.x, y), Vector2(p0.x, minf(y + 6.0, p0.y)), Color(Style.c("dim"), 0.7), 1.0)
		y += 10.0
	draw_line(p0, p1, Style.c("gold"), 3.0, true)
	var q := p0 + up
	var n := 0
	while n < 20:
		var t0 := float(n) / 20.0
		var t1 := minf(t0 + 0.025, 1.0)
		draw_line(q + (p1 - p0) * t0, q + (p1 - p0) * t1, Style.c("dim"), 1.0)
		n += 1
	draw_line(p1, Vector2(p1.x, area.position.y), Color(Style.c("text"), 0.5), 1.0)
	draw_string(font, p0 + (p1 - p0) * 0.62 + Vector2(6.0, 14.0), "filo", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.c("gold"))
	var pt := "pasada del otro filo"
	var ptw := font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var pp := q + (p1 - p0) * 0.9 + Vector2(-ptw, -8.0)
	draw_string(font, Vector2(maxf(pp.x, area.position.x + 12.0), pp.y), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.c("dim"))
	draw_string(font, Vector2(p0.x + 4.0, area.position.y + 10.0), "eje", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.c("dim"))
	# Cotas: f/2 en vertical junto a la esquina y h perpendicular al filo
	var cy0 := p1 + Vector2(8.0, 0.0)
	draw_line(cy0, cy0 + up, Style.c("ice"), 1.5)
	var nrm := Vector2(cos(half), sin(half))
	var mid := (p0 + p1) / 2.0
	draw_line(mid, mid - nrm * float(geo.get("h_mm", 0.0)) * k * px_mm, Style.c("mint"), 2.0)
	# Textos
	var ty := area.end.y + 18.0
	for key in keys:
		var col := Style.c("mint") if key == "h" else (Style.c("ice") if key == "fz" else (Style.c("dim") if key == "vc" else Style.c("text")))
		draw_string(font, Vector2(r.position.x + 12.0, ty), str(labels.get(key, "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 10, col)
		ty += 14.0


## Rayado de sección a 45° dentro de un rectángulo.
func _hatch(rect: Rect2, col: Color, gap: float) -> void:
	var c := -rect.size.y
	while c < rect.size.x:
		var a := Vector2(rect.position.x + maxf(c, 0.0), rect.position.y + maxf(-c, 0.0))
		var len := minf(rect.size.x - maxf(c, 0.0), rect.size.y - maxf(-c, 0.0))
		if len > 0.0:
			draw_line(a, a + Vector2(len, len), col, 1.0)
		c += gap
