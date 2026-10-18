## Medidor de fuerza G del coche en marcha en curva (unidad 4t). Solo pinta lo que le da el estado (MovingCarState.meter()
## o el campo curve.meter de MovingCarState.s_frame(), de core/lab/car_curve.gd): visto desde arriba, con el morro hacia
## arriba, la flecha es la fuerza que tira del animal por cada unidad de su peso (g): de lado (la curva y el viento lateral)
## y a lo largo (el viento y la maniobra, hacia atrás abajo). El círculo discontinuo es el tope del coche (lo que dan sus
## neumáticos de lado: más allá derrapa) y el verde, lo que aguantan las garras del animal (μ·R + anclaje, por su peso): si
## la flecha sale de él, se suelta. En la curva en S se ve la flecha cambiar de lado, con su estela.
extends Control

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")

## Puntos de la estela (los últimos fotogramas de la S).
const TRAIL_N := 40
## Alto de los textos de debajo (px, con dos líneas) y tamaño de letra.
const TEXT_H := 30.0
const FONT := 10
const FONT_SMALL := 9
## Por debajo de este radio (px) «delante», «atrás» y los lados van en letra más pequeña (el teléfono).
const SMALL_R := 45.0
const FONT_TINY := 8

## { latG, backG, needG, availG, gripG, holds } (g).
var data: Dictionary = {}
## Lo que se dice debajo del círculo (la curva, el lado, la S comprimida…).
var note := ""
var draws := 0
## El destello del cambio de lado (1 al cambiar, baja a 0): un anillo que se abre desde el borde.
var flash := 0.0:
	set(v):
		if v != flash:
			flash = v
			queue_redraw()
var _trail := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "MedidorG"
	accessibility_name = "Medidor de fuerza G"


## Lo que se pinta: el medidor y la nota de debajo. Repinta solo si cambia.
func set_meter(m: Dictionary, p_note := "") -> void:
	if m == data and p_note == note:
		return
	data = m
	note = p_note
	queue_redraw()


## Añade el punto de ahora a la estela (en la S); clear_trail() la borra.
func push_trail() -> void:
	if data.is_empty():
		return
	_trail.append(Vector2(float(data.latG), float(data.backG)))
	if _trail.size() > TRAIL_N:
		_trail.remove_at(0)


func clear_trail() -> void:
	_trail.clear()


## Escala del círculo (g en el borde): el tope del coche con margen, o lo que pide o aguanta (hasta 3 g), en medios g.
func scale_g() -> float:
	var g := maxf(float(data.get("gripG", 1.0)) * 1.25, 1.0)
	g = maxf(g, minf(float(data.get("needG", 0.0)) * 1.1, 3.0))
	g = maxf(g, minf(float(data.get("availG", 0.0)) * 1.1, 3.0))
	return ceilf(g * 2.0) / 2.0


func _draw() -> void:
	draws += 1
	if data.is_empty():
		return
	var font := get_theme_default_font()
	var text_h := TEXT_H if note.contains("\n") else TEXT_H * 0.55  # una línea de nota en un teléfono
	var r := maxf(minf(size.x, size.y - text_h) * 0.5 - 4.0, 10.0)
	var c := Vector2(size.x * 0.5, r + 4.0)
	var sg := scale_g()
	var k := r / sg
	var text := Palette.color("text")
	var dim := Palette.color("dim")
	draw_circle(c, r + 3.0, Color(Palette.color("bg"), 0.82))
	# anillos cada medio g y la cruz
	var g := 0.5
	while g < sg + 1e-6:
		draw_arc(c, g * k, 0.0, TAU, 48, Color(dim, 0.35 if fmod(g, 1.0) == 0.0 else 0.18), 1.0, true)
		g += 0.5
	draw_line(c + Vector2(-r, 0.0), c + Vector2(r, 0.0), Color(dim, 0.4), 1.0)
	draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), Color(dim, 0.4), 1.0)
	draw_string(font, c + Vector2(3.0, -k + FONT_SMALL), "1 g", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, Color(dim, 0.8))
	# lo que aguantan las garras (verde) y el tope del coche (discontinuo)
	var avail := float(data.get("availG", 0.0))
	var mint := Palette.color("mint")
	if avail > 0.0:
		var ra := minf(avail, sg) * k
		draw_circle(c, ra, Color(mint, 0.10))
		draw_arc(c, ra, 0.0, TAU, 64, Color(mint, 0.75 if avail <= sg else 0.35), 1.5, true)
	var grip := float(data.get("gripG", 0.0))
	var gold := Palette.color("gold")
	if grip > 0.0:
		var rg := grip * k
		var n := 36
		for i in n:
			if i % 2 == 0:
				draw_arc(c, rg, TAU * float(i) / float(n), TAU * float(i + 1) / float(n), 4, gold, 1.5, true)
	# la estela de la S
	if _trail.size() >= 2:
		var pts := PackedVector2Array()
		for p: Vector2 in _trail:
			pts.append(c + _clip(p * k, r))
		draw_polyline(pts, Color(text, 0.35), 1.5, true)
	# la flecha
	var v := Vector2(float(data.get("latG", 0.0)), float(data.get("backG", 0.0)))
	var tip := c + _clip(v * k, r)
	var col := mint if bool(data.get("holds", true)) else Palette.color("coral")
	if tip.distance_to(c) > 2.0:
		var dir := (tip - c).normalized()
		draw_line(c, tip, Color(Palette.color("bg"), 0.8), 4.5, true)
		draw_line(c, tip, col, 2.5, true)
		var head := PackedVector2Array([tip, tip - dir.rotated(0.45) * 8.0, tip - dir.rotated(-0.45) * 8.0])
		draw_colored_polygon(head, col)
	draw_circle(c, 2.5, text)
	# delante / atrás y los lados (visto desde arriba, el morro arriba); en un medidor pequeño, en letra más pequeña
	_draw_compass(font, c, r, dim, FONT_SMALL if r >= SMALL_R else FONT_TINY)
	if flash > 0.0:
		draw_arc(c, r + 3.0 + (1.0 - flash) * 6.0, 0.0, TAU, 64, Color(Palette.color("gold"), flash), 3.0, true)
	# debajo: la nota (dos líneas como mucho), con un halo
	if note != "":
		var y := c.y + r + 4.0 + FONT
		var lines := note.split("\n")
		# una banda oscura detrás (unidad 4u): la línea del horizonte o de la carretera no la tacha
		var nl := mini(lines.size(), 2)
		draw_rect(Rect2(0.0, y - FONT - 1.0, size.x, float(nl) * (FONT + 2) + 4.0), Color(Palette.color("bg"), 0.62))
		for i in nl:
			var at := Vector2(0.0, y + float(i) * (FONT + 2))
			draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, 3, Color(Palette.color("bg"), 0.85))
			draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, text if i == 0 else dim)


func _draw_compass(font: Font, c: Vector2, r: float, dim: Color, fs: int) -> void:
	var col := Color(dim, 0.9)
	var w := r * 1.4
	draw_string(font, c + Vector2(-w * 0.5, -r + fs + 1.0), "delante", HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
	draw_string(font, c + Vector2(-w * 0.5, r - 2.0), "atrás", HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
	draw_string(font, c + Vector2(-r + 2.0, -3.0), "izq.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var dw := font.get_string_size("der.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(r - 2.0 - dw, -3.0), "der.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Un punto del medidor (px desde el centro) recortado al borde.
static func _clip(p: Vector2, r: float) -> Vector2:
	var l := p.length()
	return p * (r / l) if l > r else p
