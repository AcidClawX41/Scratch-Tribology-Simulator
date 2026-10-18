## Texturas de los animales en 3D hechas en código (unidad 4l): SVG escrito aquí y rasterizado con ThorVG
## (app/common/svg_texture.gd), sin descargas.
##   - Teselas del detalle (se repiten por UV2, en cm de la anatomía): plumas en tejado, pelo, escamas pequeñas, escudos
##     del tarso, piel arrugada y queratina con estrías. De cada una salen el relieve (altura → mapa de normales con
##     Image.bump_map_to_normal_map, calculado sobre la tesela repetida 3 × 3 para que no tenga costuras) y la
##     modulación del color (gris que multiplica el color de la pieza).
##   - Puntas de pelo para las capas de pelo del contorno (ruido de puntos claros).
##   - Mapas del patrón de cada especie en el espacio UV de una pieza (x alrededor, y a lo largo): rayas del tigre,
##     barras, listas y bandas; blanco donde manda el color de los vértices.
## Todo se guarda en la caché que se le pasa (un Dictionary compartido por la vista), así que cada textura se hace una
## vez. Solo dibujo.
extends RefCounted

const SvgTexture = preload("res://app/common/svg_texture.gd")
const Rng = preload("res://core/shared/rng.gd")

## Lado de las teselas del detalle (px): escritorio y teléfono.
const TILE_PX := 128
const TILE_PX_MOBILE := 64


static func _n(v: float) -> String:
	return String.num(snappedf(v, 0.01))


static func _svg(w: int, h: int, body: String, defs := "") -> String:
	var d := "<defs>%s</defs>" % defs if defs != "" else ""
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">%s%s</svg>" % [w, h, w, h, d, body]


static func _grey(v: float) -> String:
	var g := clampi(int(roundf(clampf(v, 0.0, 1.0) * 255.0)), 0, 255)
	return "#%02x%02x%02x" % [g, g, g]


## Una tesela del detalle: { albedo, normal } (ImageTexture), de un tipo («pluma», «pelo», «escama», «escudo», «piel»,
## «queratina», «plumon») y lado px. Se guarda en cache.
static func tile(kind: String, px: int, cache: Dictionary) -> Dictionary:
	var key := "tile|%s|%d" % [kind, px]
	if cache.has(key):
		return cache[key]
	var hsvg := _tile_svg(kind, px, true)
	var asvg := _tile_svg(kind, px, false)
	var himg := SvgTexture.rasterize_image(hsvg, 1.0)
	var aimg := SvgTexture.rasterize_image(asvg, 1.0)
	var out := { "albedo": null, "normal": null, "made": 0 }
	if himg != null:
		out.normal = ImageTexture.create_from_image(_normal_tileable(himg, _bump_k(kind, px)))
		out.made = int(out.made) + 1
	if aimg != null:
		aimg.convert(Image.FORMAT_RGBA8)
		aimg.generate_mipmaps()
		out.albedo = ImageTexture.create_from_image(aimg)
		out.made = int(out.made) + 1
	cache[key] = out
	return out


## Fuerza del relieve de cada tesela (para bump_map_to_normal_map).
static func _bump_k(kind: String, px: int) -> float:
	var k := float(px) / 128.0
	match kind:
		"pluma":
			return 3.2 * k
		"plumon":
			return 1.6 * k
		"pelo":
			return 2.6 * k
		"escama":
			return 3.0 * k
		"escudo":
			return 4.0 * k
		"piel":
			return 1.8 * k
		"queratina":
			return 1.2 * k
	return 2.0 * k


## Mapa de normales sin costuras: la altura repetida 3 × 3, convertida y recortada al centro.
static func _normal_tileable(h: Image, strength: float) -> Image:
	h.convert(Image.FORMAT_RGBA8)
	var w := h.get_width()
	var hh := h.get_height()
	var big := Image.create_empty(w * 3, hh * 3, false, Image.FORMAT_RGBA8)
	for y in 3:
		for x in 3:
			big.blit_rect(h, Rect2i(0, 0, w, hh), Vector2i(x * w, y * hh))
	big.bump_map_to_normal_map(strength)
	var out := big.get_region(Rect2i(w, hh, w, hh))
	out.generate_mipmaps()
	return out


## SVG de una tesela: height = true, la altura (blanco = alto); si no, la modulación del color (gris claro).
static func _tile_svg(kind: String, px: int, height: bool) -> String:
	var t := float(px)
	var b := PackedStringArray()
	var defs := ""
	match kind:
		"pluma", "plumon":
			# plumas en tejado con la punta hacia +y (hacia donde apunta el plumaje): la base, baja y oscura; la punta,
			# alta; filas de abajo arriba para que la de delante tape la base de la de detrás
			var soft := kind == "plumon"
			var cols := 4 if not soft else 5
			var rows := 5 if not soft else 6
			var fw := t / float(cols) * 1.18
			var fl := t / float(rows) * 2.1
			var g0 := 0.18 if height else 0.84
			var g1 := 1.0 if height else 1.0
			defs = "<linearGradient id=\"f\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.82\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [
				_grey(g0), _grey(g1), _grey(g1 * (0.8 if height else 0.9))]
			b.append("<rect width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [px, px, _grey(g0)])
			for ry in range(rows + 2, -3, -1):
				for cx in range(-1, cols + 1):
					var x := (float(cx) + (0.5 if ry % 2 == 0 else 0.0)) * t / float(cols)
					var y := float(ry) * t / float(rows) - fl
					var tip := y + fl
					var r := fw * 0.5
					var d := "M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % [_n(x - r), _n(y), _n(x - r), _n(tip - r * 0.9),
						_n(x - r), _n(tip), _n(x), _n(tip), _n(x + r), _n(tip), _n(x + r), _n(tip - r * 0.9), _n(x + r), _n(y)]
					b.append("<path d=\"%s\" fill=\"url(#f)\"/>" % d)
					if not height and not soft:
						# el raquis, un poco más claro
						b.append("<path d=\"M%s %s L%s %s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [_n(x), _n(y + fl * 0.3), _n(x),
							_n(tip - r * 0.3), _grey(1.0), _n(maxf(t / 128.0, 0.6))])
		"pelo":
			var rng := Rng.new(Rng.seed_of("tesela:pelo"))
			b.append("<rect width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [px, px, _grey(0.45 if height else 0.82)])
			var count := int(t * 2.2)
			for k in count:
				var x := rng.next() * t
				var y := rng.next() * t
				var l := t * (0.18 + 0.2 * rng.next())
				var dx := (rng.next() - 0.5) * l * 0.25
				var g := 0.25 + 0.75 * rng.next() if height else 0.7 + 0.3 * rng.next()
				var wv := maxf(t / 128.0 * (0.8 + 0.9 * rng.next()), 0.5)
				for oy: float in [-t, 0.0, t]:
					for ox: float in [-t, 0.0, t]:
						var x0 := x + ox
						var y0 := y + oy
						if x0 + absf(dx) < -2.0 or x0 - absf(dx) > t + 2.0 or y0 > t + 2.0 or y0 + l < -2.0:
							continue
						b.append("<path d=\"M%s %s Q%s %s %s %s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linecap=\"round\" fill=\"none\"/>" % [
							_n(x0), _n(y0), _n(x0 + dx * 0.3), _n(y0 + l * 0.5), _n(x0 + dx), _n(y0 + l), _grey(g), _n(wv)])
		"escama", "escudo":
			var big := kind == "escudo"
			var cols := 4 if not big else 1
			var rows := 5 if not big else 4
			var sw := t / float(cols)
			var sh := t / float(rows)
			b.append("<rect width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [px, px, _grey(0.08 if height else 0.62)])
			defs = "<radialGradient id=\"s\" cx=\"0.5\" cy=\"0.42\" r=\"0.6\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.7\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></radialGradient>" % [
				_grey(1.0 if height else 1.0), _grey(0.7 if height else 0.92), _grey(0.3 if height else 0.75)]
			for ry in range(-1, rows + 1):
				for cx in range(-1, cols + 1):
					var x := (float(cx) + (0.5 if ry % 2 != 0 and not big else 0.0)) * sw
					var y := float(ry) * sh
					if big:
						# escudos: placas anchas y bajas, con la ranura entre ellas
						b.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"url(#s)\"/>" % [_n(-2.0), _n(y + sh * 0.08),
							_n(t + 4.0), _n(sh * 0.84), _n(sh * 0.35)])
					else:
						b.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"url(#s)\"/>" % [_n(x + sw * 0.5), _n(y + sh * 0.5),
							_n(sw * 0.48), _n(sh * 0.56)])
		"piel":
			var rng := Rng.new(Rng.seed_of("tesela:piel"))
			b.append("<rect width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [px, px, _grey(0.6 if height else 0.9)])
			for k in 22:
				var y := rng.next() * t
				var a := (rng.next() - 0.5) * t * 0.12
				var g := 0.2 if height else 0.8
				for oy: float in [-t, 0.0, t]:
					b.append("<path d=\"M%s %s C%s %s %s %s %s %s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [_n(-4.0), _n(y + oy),
						_n(t * 0.3), _n(y + oy + a), _n(t * 0.7), _n(y + oy - a), _n(t + 4.0), _n(y + oy), _grey(g), _n(maxf(t / 110.0, 0.6))])
			for k in 60:
				var x := rng.next() * t
				var y := rng.next() * t
				b.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [_n(x), _n(y), _n(maxf(t / 90.0, 0.5)), _grey(0.35 if height else 0.85)])
		"queratina":
			var rng := Rng.new(Rng.seed_of("tesela:queratina"))
			b.append("<rect width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [px, px, _grey(0.5 if height else 0.95)])
			for k in 26:
				var x := rng.next() * t
				var g := 0.3 + 0.4 * rng.next() if height else 0.88 + 0.12 * rng.next()
				for ox: float in [-t, 0.0, t]:
					b.append("<rect x=\"%s\" y=\"0\" width=\"%s\" height=\"%d\" fill=\"%s\"/>" % [_n(x + ox), _n(maxf(t / 64.0, 0.6)), px, _grey(g)])
	return _svg(px, px, "".join(b), defs)


## Puntas de pelo para las capas del contorno: puntos claros de brillo al azar sobre negro (R = altura del pelo).
static func strands(px: int, cache: Dictionary) -> ImageTexture:
	var key := "strands|%d" % px
	if cache.has(key):
		return cache[key]
	var rng := Rng.new(Rng.seed_of("tesela:puntas"))
	var b := PackedStringArray(["<rect width=\"%d\" height=\"%d\" fill=\"#000000\"/>" % [px, px]])
	var t := float(px)
	var count := int(t * t / 9.0)
	for k in count:
		var x := rng.next() * t
		var y := rng.next() * t
		var r := maxf(t / 64.0 * (0.55 + 0.6 * rng.next()), 0.45)
		var g := 0.2 + 0.8 * rng.next()
		for oy: float in [-t, 0.0, t]:
			for ox: float in [-t, 0.0, t]:
				if x + ox < -r or x + ox > t + r or y + oy < -r or y + oy > t + r:
					continue
				b.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [_n(x + ox), _n(y + oy), _n(r), _grey(g)])
	var img := SvgTexture.rasterize_image(_svg(px, px, "".join(b)), 1.0)
	var tex: ImageTexture = null
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	cache[key] = tex
	return tex


## Textura de una tarjeta (RGB gris que se tiñe con el color de los vértices; alfa, la silueta), con la base arriba y la
## punta abajo: «mechon» (flecos lacios del casuario: hebras sueltas), «pluma_dedo» (primaria escotada de águila y
## buitre), «pluma_punta» (halcón), «pluma_redonda» (búhos), «cobertera» y «rectriz»; nbars franjas oscuras.
static func card_tex(kind: String, px: int, cache: Dictionary, nbars := 0) -> ImageTexture:
	var key := "card|%s|%d|%d" % [kind, px, nbars]
	if cache.has(key):
		return cache[key]
	var w := maxi(px / 4, 8)
	var h := px
	var fw := float(w)
	var fh := float(h)
	var b := PackedStringArray()
	var defs := ""
	if kind == "mechon":
		var rng := Rng.new(Rng.seed_of("tarjeta:mechon"))
		for k in 16:
			var x0 := fw * (0.2 + 0.6 * rng.next())
			var x1 := x0 + (rng.next() - 0.5) * fw * 0.5
			var l := fh * (0.55 + 0.45 * rng.next())
			var g := 0.75 + 0.25 * rng.next()
			b.append("<path d=\"M%s 0 Q%s %s %s %s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linecap=\"round\" fill=\"none\"/>" % [_n(x0),
				_n((x0 + x1) * 0.5 + (rng.next() - 0.5) * fw * 0.2), _n(l * 0.5), _n(x1), _n(l), _grey(g), _n(maxf(fw / 12.0, 0.8))])
	else:
		var tipk := kind
		var pts: PackedVector2Array
		match tipk:
			"pluma_dedo":
				pts = PackedVector2Array([Vector2(0.42, 0), Vector2(0.95, 0.12), Vector2(0.98, 0.55), Vector2(0.72, 0.72), Vector2(0.66, 0.92),
					Vector2(0.5, 1.0), Vector2(0.3, 0.9), Vector2(0.12, 0.66), Vector2(0.06, 0.35), Vector2(0.2, 0.05)])
			"pluma_punta":
				pts = PackedVector2Array([Vector2(0.42, 0), Vector2(0.92, 0.12), Vector2(0.86, 0.6), Vector2(0.62, 0.9), Vector2(0.5, 1.0),
					Vector2(0.36, 0.86), Vector2(0.14, 0.5), Vector2(0.2, 0.06)])
			"pluma_redonda":
				pts = PackedVector2Array([Vector2(0.4, 0), Vector2(0.94, 0.12), Vector2(0.98, 0.7), Vector2(0.82, 0.93), Vector2(0.5, 1.0),
					Vector2(0.18, 0.93), Vector2(0.03, 0.7), Vector2(0.1, 0.1)])
			"cobertera":
				pts = PackedVector2Array([Vector2(0.35, 0), Vector2(0.92, 0.2), Vector2(0.95, 0.62), Vector2(0.72, 0.92), Vector2(0.5, 1.0),
					Vector2(0.28, 0.92), Vector2(0.05, 0.62), Vector2(0.08, 0.2)])
			_:
				pts = PackedVector2Array([Vector2(0.38, 0), Vector2(0.9, 0.08), Vector2(0.94, 0.75), Vector2(0.78, 0.96), Vector2(0.5, 1.0),
					Vector2(0.22, 0.96), Vector2(0.06, 0.75), Vector2(0.1, 0.08)])
		var d := PackedStringArray()
		for i in pts.size():
			var p := Vector2(pts[i].x * fw, pts[i].y * fh)
			var q := Vector2(pts[(i + 1) % pts.size()].x * fw, pts[(i + 1) % pts.size()].y * fh)
			var m := (p + q) * 0.5
			if i == 0:
				d.append("M%s %s" % [_n(m.x), _n(m.y)])
			else:
				d.append("Q%s %s %s %s" % [_n(p.x), _n(p.y), _n(m.x), _n(m.y)])
		var p0 := Vector2(pts[0].x * fw, pts[0].y * fh)
		var m0 := (p0 + Vector2(pts[1].x * fw, pts[1].y * fh)) * 0.5
		d.append("Q%s %s %s %s Z" % [_n(p0.x), _n(p0.y), _n(m0.x), _n(m0.y)])
		var path := " ".join(d)
		defs = "<linearGradient id=\"v\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.5\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient><clipPath id=\"c\"><path d=\"%s\"/></clipPath>" % [
			_grey(0.8), _grey(1.0), _grey(0.86), path]
		b.append("<path d=\"%s\" fill=\"url(#v)\"/>" % path)
		b.append("<g clip-path=\"url(#c)\">")
		var rng := Rng.new(Rng.seed_of("tarjeta:" + kind))
		for k in 9:
			var y := fh * (0.08 + 0.88 * float(k) / 9.0)
			var g := _grey(0.84 + 0.08 * rng.next())
			b.append("<path d=\"M%s %s L0 %s M%s %s L%s %s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [_n(fw * 0.5), _n(y), _n(y + fh * 0.06),
				_n(fw * 0.5), _n(y), _n(fw), _n(y + fh * 0.05), g, _n(maxf(fw / 40.0, 0.4))])
		for k in nbars:
			var y := fh * (0.22 + 0.7 * (float(k) + 0.5) / float(nbars))
			b.append("<rect x=\"0\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\" fill-opacity=\"0.8\"/>" % [_n(y), _n(fw), _n(fh * 0.045), _grey(0.28)])
		b.append("</g>")
		b.append("<path d=\"M%s 0 Q%s %s %s %s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [_n(fw * 0.47), _n(fw * 0.49), _n(fh * 0.5),
			_n(fw * 0.5), _n(fh * 0.97), _grey(1.0), _n(maxf(fw / 14.0, 0.8))])
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var r := SvgTexture.rasterize_image("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><defs>%s</defs>%s</svg>" % [
		w, h, w, h, defs, "".join(b)], 1.0)
	if r != null:
		img = r
		img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	cache[key] = tex
	return tex


## Un mapa de patrón en el espacio UV de una pieza: body es SVG en un lienzo de w × h px (x alrededor de la pieza, y a
## lo largo), sobre blanco. Se guarda con la clave key.
static func pattern(key: String, w: int, h: int, body: String, cache: Dictionary, defs := "") -> ImageTexture:
	var k := "pat|" + key
	if cache.has(k):
		return cache[k]
	var svg := _svg(w, h, "<rect width=\"%d\" height=\"%d\" fill=\"#ffffff\"/>" % [w, h] + body, defs)
	var img := SvgTexture.rasterize_image(svg, 1.0)
	var tex: ImageTexture = null
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	cache[k] = tex
	return tex


## Huso afilado de a a b con ancho w (px) en el SVG: para rayas, barras y listas.
static func spindle(a: Vector2, b: Vector2, w: float, col: String, bend := 0.0) -> String:
	var d := b - a
	var l := d.length()
	if l <= 0.0:
		return ""
	var t := d / l
	var nrm := Vector2(-t.y, t.x)
	var mid := a + d * 0.5 + nrm * (bend * l)
	var p1 := mid + nrm * (w * 0.5)
	var p2 := mid - nrm * (w * 0.5)
	return "<path d=\"M%s %s Q%s %s %s %s Q%s %s %s %s Z\" fill=\"%s\"/>" % [_n(a.x), _n(a.y), _n(p1.x), _n(p1.y), _n(b.x), _n(b.y), _n(p2.x),
		_n(p2.y), _n(a.x), _n(a.y), col]


## Color como texto SVG (#rrggbb).
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
