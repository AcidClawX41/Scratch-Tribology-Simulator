## La muestra de cada material de garra en el selector «Material de las garras» del coche en marcha (unidad 4s, petición de
## Eric del 13-10: «varios tipos de garras con varios materiales, como en la cetrería»): una garra pequeña (un gancho) con el
## color y el brillo de la biblioteca común (los datos ópticos de core/lab/claw_optics.gd, los mismos que usa ClawMaterial):
## el reflejo medido de cada metal (F0), el tinte de cada gema o vidrio con su destello, el color del cuerpo de la cerámica y
## la queratina con el color de la especie. Solo dibujo; se construye una vez por material y color (caché).
extends RefCounted

const ClawOptics = preload("res://core/lab/claw_optics.gd")

## Lado de la imagen (px de verdad: se enseña a la mitad, para que se vea nítida en una pantalla ×2).
const SIZE := 32
const SHOW := 16
## Muestras por píxel en cada eje (suavizado).
const SS := 3

static var _cache := {}
## La forma del gancho, la misma para todos los materiales (una vez): por píxel, la luz, el reflejo, el destello y la
## cobertura.
static var _shape_px: Array = []


## La textura de la muestra de un material (un id de claw_optics.gd; «none» la queratina, con keratin_col).
static func texture(id: String, keratin_col := Color("#2e2a26")) -> ImageTexture:
	var key := "%s|%s" % [id, keratin_col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var lk := ClawOptics.look(id if ClawOptics.MATERIALS.has(id) else "none")
	var fam := String(lk.get("family", "queratina"))
	var base := keratin_col
	var spec := 0.35
	var sparkle := false
	match fam:
		"metal", "mineral":
			base = _lin(lk.f0)
			spec = 0.9
		"gema", "vidrio":
			base = _lin(lk.tint).lerp(Color(0.85, 0.9, 1.0), 0.25)
			spec = 1.0
			sparkle = true
		"ceramica", "polimero":
			base = _lin(lk.albedo) if not (lk.albedo as Array).is_empty() else Color(0.9, 0.9, 0.88)
			spec = 0.5
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var shape := _shape()
	for y in SIZE:
		for x in SIZE:
			var q: Color = shape[y * SIZE + x]  # r: luz, g: reflejo, b: destello, a: cobertura
			if q.a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := (base * q.r).lerp(Color(1, 1, 1), q.g * spec * 0.8)
			if sparkle:
				col = col.lerp(Color(1, 1, 1), q.b * 0.8)
			col.a = q.a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _shape() -> Array:
	if not _shape_px.is_empty():
		return _shape_px
	var light := Vector2(-0.6, -0.8).normalized()
	for y in SIZE:
		for x in SIZE:
			var acc := Vector4.ZERO
			for sy in SS:
				for sx in SS:
					var p := (Vector2(x, y) + (Vector2(sx, sy) + Vector2(0.5, 0.5)) / float(SS)) / float(SIZE)
					acc += _sample(p, light)
			var n := float(SS * SS)
			var a := acc.w / n
			_shape_px.append(Color(acc.x / maxf(acc.w, 1e-6), acc.y / maxf(acc.w, 1e-6), acc.z / maxf(acc.w, 1e-6), a))
	return _shape_px


## Un color lineal de un array [r, g, b] pasado a sRGB.
static func _lin(a: Variant) -> Color:
	var v: Array = a if a is Array else []
	if v.size() < 3:
		return Color(0.6, 0.6, 0.6)
	return Color(clampf(float(v[0]), 0.0, 1.0), clampf(float(v[1]), 0.0, 1.0), clampf(float(v[2]), 0.0, 1.0)).linear_to_srgb()


## El gancho (p en 0-1): un disco grande menos uno desplazado, la punta abajo a la izquierda; con una normal de cilindro a lo
## ancho del gancho: (luz, reflejo, destello de gema, 1) dentro y 0 fuera.
static func _sample(p: Vector2, light: Vector2) -> Vector4:
	var c1 := Vector2(0.62, 0.62)
	var c2 := Vector2(0.78, 0.74)
	var r1 := 0.5
	var r2 := 0.42
	var d1 := p.distance_to(c1)
	var d2 := p.distance_to(c2)
	if d1 > r1 or d2 < r2 or p.y > 0.95 or p.x > 0.95:
		return Vector4.ZERO
	var w := clampf((r1 - d1) / maxf((r1 - d1) + (d2 - r2), 1e-4), 0.0, 1.0)
	var out := (p - c1).normalized()
	var nrm := out * (1.0 - 2.0 * w)
	var lam := clampf(0.55 + 0.45 * nrm.dot(-light) + 0.25 * sqrt(maxf(1.0 - nrm.length_squared(), 0.0)), 0.0, 1.0)
	var hl := pow(clampf(1.0 - absf(w - 0.3) * 4.0, 0.0, 1.0), 3.0) * clampf(-out.dot(light), 0.0, 1.0)
	var sp := 1.0 if p.distance_to(Vector2(0.3, 0.42)) < 0.05 else 0.0
	return Vector4(lam, hl, sp, 1.0)
