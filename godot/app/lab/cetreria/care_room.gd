## Cetrería · el sitio de trabajo (unidad 5c), hecho en código y sin descargas, con los materiales físicos del taller:
##   - «cetreria» (la rapaz): el banco de trabajo de madera de un centro de cetrería, la pared encalada con su ventana y su
##     luz cálida, el estante con las capuchas y los botes, el guante de cetrería sobre el banco y la percha de arco del
##     ave en el suelo de arena;
##   - «clinica» (el tigre, el oso y el velocirraptor, anestesiados): la mesa de quirófano de acero inoxidable con su
##     columna, la pared de azulejos con la ventana, el armario de vitrina con los frascos, la lámpara de quirófano y la
##     máquina de anestesia junto a la cabeza.
## La mesa (o el banco) acaba en edge_x, el borde por el que cuelgan las garras, y su tablero está en y = 0. Que no
## distraiga: colores apagados, sin brillos fuertes detrás de la garra, y el preset del teléfono quita detalle (sin los
## objetos pequeños, sin la luz de la lámpara y con texturas más pequeñas). Se construye una vez por sitio, tamaño y
## calidad: en cada fotograma no hace nada. Solo dibujo (las medidas son las habituales de estos muebles, no datos).
extends RefCounted

## Alto del tablero sobre el suelo (m).
const TABLE_H := 0.9


static func _mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node, size: Vector3, center: Vector3, mat: Material, n := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = center
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node, r: float, h: float, center: Vector3, mat: Material, n := "", r2 := -1.0, segs := 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r2 if r2 >= 0.0 else r
	c.height = h
	c.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = center
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


## Ruido de valor determinista (para las texturas: sin azar del sistema, siempre la misma imagen).
static func _hash(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _vnoise(x: float, y: float, seed: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - float(xi)
	var fy := y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash(xi, yi, seed), _hash(xi + 1, yi, seed), fx)
	var b := lerpf(_hash(xi, yi + 1, seed), _hash(xi + 1, yi + 1, seed), fx)
	return lerpf(a, b, fy)


## La veta de la madera: tablas a lo largo de u con su veta (anillos estirados) y las juntas entre tablas.
static func wood_tex(w: int, h: int, light: Color, dark: Color, planks: int, seed: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var plank := int(floor(float(y) / float(h) * float(planks)))
		var vy := float(y) / float(h) * float(planks) - float(plank)
		var tone := 0.85 + 0.3 * _hash(plank, 7, seed)
		for x in w:
			var u := float(x) / float(w)
			var n := _vnoise(u * 6.0 + float(plank) * 3.1, vy * 2.0, seed)
			var ring := 0.5 + 0.5 * sin((vy * 9.0 + n * 6.0 + u * 2.0) * TAU * 0.5)
			var c := light.lerp(dark, clampf(ring * 0.55 + n * 0.25, 0.0, 1.0)) * tone
			# la junta entre tablas
			if vy < 0.035 or vy > 0.965:
				c = c.darkened(0.45)
			img.set_pixel(x, y, Color(c, 1.0))
	return ImageTexture.create_from_image(img)


## Azulejos: cuadros claros con su junta gris y un poco de variación en cada uno.
static func tile_tex(n: int, tile: Color, grout: Color, seed: int) -> ImageTexture:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var cells := 4
	var cs := float(n) / float(cells)
	for y in n:
		for x in n:
			var cx := int(floor(float(x) / cs))
			var cy := int(floor(float(y) / cs))
			var fx := float(x) - float(cx) * cs
			var fy := float(y) - float(cy) * cs
			var c := tile * (0.96 + 0.06 * _hash(cx, cy, seed))
			if fx < 1.5 or fy < 1.5:
				c = grout
			img.set_pixel(x, y, Color(c, 1.0))
	return ImageTexture.create_from_image(img)


## Enlucido o arena: un color con manchas suaves.
static func plaster_tex(n: int, base: Color, spot: Color, scale: float, seed: int) -> ImageTexture:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := float(x) / float(n)
			var v := float(y) / float(n)
			# ruido periódico (la textura se repite sin costura): suma de dos octavas sobre una rejilla que da la vuelta
			var a := _tile_noise(u, v, scale, seed)
			var b := _tile_noise(u, v, scale * 4.0, seed + 5)
			img.set_pixel(x, y, Color(base.lerp(spot, clampf(a * 0.7 + b * 0.3, 0.0, 1.0)), 1.0))
	return ImageTexture.create_from_image(img)


static func _tile_noise(u: float, v: float, cells: float, seed: int) -> float:
	var x := u * cells
	var y := v * cells
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - float(xi)
	var fy := y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var c := int(cells)
	var a := lerpf(_hash(posmod(xi, c), posmod(yi, c), seed), _hash(posmod(xi + 1, c), posmod(yi, c), seed), fx)
	var b := lerpf(_hash(posmod(xi, c), posmod(yi + 1, c), seed), _hash(posmod(xi + 1, c), posmod(yi + 1, c), seed), fx)
	return lerpf(a, b, fy)


## Una textura de la caché (o la pinta make la primera vez).
static func _cached(cache: Dictionary, key: String, make: Callable) -> Texture2D:
	if not cache.has(key):
		cache[key] = make.call()
	return cache[key]


static func _tex_mat(tex: Texture2D, uv: Vector2, rough := 0.85, metal := 0.0, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Construye el sitio. venue: «cetreria» o «clinica»; top: el tablero (x0 → edge_x, z0 → z1, en m, y = 0); cache: un
## Dictionary que guarda las texturas hechas en código (se pintan una vez por sitio y calidad).
## → { root, venue, top: Rect2 (x, z), lamp (la luz de la lámpara de quirófano o null), window (Vector3: el centro de la
## ventana, de donde viene el sol) }
static func build(parent: Node3D, venue: String, edge_x: float, x0: float, z0: float, z1: float, mobile: bool, cache := {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "Sala_" + venue
	parent.add_child(root)
	var out := { "root": root, "venue": venue, "top": Rect2(x0, z0, edge_x - x0, z1 - z0), "lamp": null }
	if venue == "cetreria":
		_falconry(root, edge_x, x0, z0, z1, mobile, out, cache)
	else:
		_clinic(root, edge_x, x0, z0, z1, mobile, out, cache)
	return out


# ─────────────────────────────── Clínica ───────────────────────────────

static func _clinic(root: Node3D, edge_x: float, x0: float, z0: float, z1: float, mobile: bool, out: Dictionary, cache: Dictionary) -> void:
	var tsz := 64 if mobile else 128
	var steel := _mat(Color("#B9C0C6"), 0.3, 0.8)
	var brushed := _mat(Color("#A9B0B6"), 0.42, 0.75)
	var floor_t: Texture2D = _cached(cache, "suelo_clinica|%d" % tsz, func() -> Texture2D: return plaster_tex(tsz, Color("#8E979B"), Color("#7E878B"), 6.0, 11))
	var wall_t: Texture2D = _cached(cache, "azulejos|%d" % tsz, func() -> Texture2D: return tile_tex(tsz, Color("#D9DEDF"), Color("#A9B0B2"), 3))
	var floor_m := _tex_mat(floor_t, Vector2(6, 6), 0.6)
	var wall_m := _tex_mat(wall_t, Vector2(10, 4), 0.35)
	var w := edge_x - x0
	var d := z1 - z0
	var cx := 0.5 * (x0 + edge_x)
	var cz := 0.5 * (z0 + z1)
	# el suelo y las paredes (detrás del animal y a su cabeza)
	var back_x := x0 - 1.1
	var side_z := z0 - 1.2
	_box(root, Vector3(edge_x + 3.0 - back_x, 0.02, z1 + 3.0 - side_z), Vector3(0.5 * (back_x + edge_x + 3.0), -TABLE_H - 0.01, 0.5 * (side_z + z1 + 3.0)), floor_m, "Suelo")
	_box(root, Vector3(0.04, 2.8, z1 + 3.0 - side_z), Vector3(back_x, -TABLE_H + 1.4, 0.5 * (side_z + z1 + 3.0)), wall_m, "Pared")
	_box(root, Vector3(edge_x + 3.0 - back_x, 2.8, 0.04), Vector3(0.5 * (back_x + edge_x + 3.0), -TABLE_H + 1.4, side_z), wall_m, "ParedLateral")
	# la ventana de la pared del fondo: luz fría de día (el sol entra por ella)
	var win_c := Vector3(back_x + 0.03, 0.55, cz + 0.2)
	var win_size := Vector2(1.6, 1.1)
	_window(root, win_c, win_size, Color(0.86, 0.93, 1.0), mobile)
	out["window"] = Vector3(back_x, 0.55, cz + 0.2)
	# la mesa de quirófano: el tablero de acero con su reborde, la columna hidráulica y el pie
	_box(root, Vector3(w, 0.03, d), Vector3(cx, -0.015, cz), steel, "Mesa")
	for side: Array in [[Vector3(w, 0.02, 0.015), Vector3(cx, 0.008, z0)], [Vector3(w, 0.02, 0.015), Vector3(cx, 0.008, z1)],
			[Vector3(0.015, 0.02, d), Vector3(x0, 0.008, cz)]]:
		_box(root, side[0], side[1], steel, "Reborde")
	_box(root, Vector3(w, 0.05, 0.02), Vector3(cx, -0.04, z1), brushed, "Canto")
	_cyl(root, 0.09, TABLE_H - 0.12, Vector3(cx, -TABLE_H * 0.5 - 0.06, cz), brushed, "Columna")
	_box(root, Vector3(minf(w, 0.7), 0.06, minf(d, 1.1)), Vector3(cx, -TABLE_H + 0.03, cz), _mat(Color("#5E666C"), 0.5, 0.4), "Pie")
	if mobile:
		return
	# el armario de vitrina en la pared, con sus frascos
	var cab := Node3D.new()
	cab.name = "Vitrina"
	root.add_child(cab)
	# al lado de la ventana, nunca delante: el armario (1 m) acaba 8 cm antes del marco
	var cab_z := win_c.z - win_size.x * 0.5 - 0.08 - 0.5
	_box(cab, Vector3(0.34, 0.9, 1.0), Vector3(back_x + 0.19, 0.75, cab_z), _mat(Color("#E8ECEE"), 0.4), "Armario")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.9, 0.95, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	_box(cab, Vector3(0.01, 0.8, 0.92), Vector3(back_x + 0.365, 0.75, cab_z), glass, "Cristal")
	for shelf in 3:
		var y := 0.42 + 0.27 * float(shelf)
		_box(cab, Vector3(0.3, 0.012, 0.94), Vector3(back_x + 0.2, y, cab_z), _mat(Color("#CFD5D8"), 0.4), "Balda")
		for k in 6:
			var col: Color = [Color("#7A4A2A"), Color("#2F6FB5"), Color("#E9F2F7"), Color("#C8A060"), Color("#3E8F6A"), Color("#B0362E")][(k + shelf) % 6]
			var h := 0.1 + 0.05 * _hash(k, shelf, 5)
			_cyl(cab, 0.026, h, Vector3(back_x + 0.2, y + 0.006 + h * 0.5, cab_z - 0.38 + 0.15 * float(k)), _mat(col, 0.3), "Frasco", -1.0, 12)
	# la lámpara de quirófano: el brazo del techo y el disco con su luz (una SpotLight hacia la mesa)
	var lamp := Node3D.new()
	lamp.name = "Lampara"
	root.add_child(lamp)
	var lp := Vector3(cx + 0.15, 1.35, cz)
	_cyl(lamp, 0.018, 0.9, lp + Vector3(0, 0.55, 0), brushed, "Brazo")
	_cyl(lamp, 0.24, 0.07, lp, _mat(Color("#E6E9EB"), 0.35, 0.3), "Cupula", 0.27)
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(1.0, 0.98, 0.94)
	face.emission_enabled = true
	face.emission = Color(1.0, 0.97, 0.9)
	face.emission_energy_multiplier = 1.6
	_cyl(lamp, 0.2, 0.01, lp + Vector3(0, -0.04, 0), face, "Luz")
	var spot := SpotLight3D.new()
	spot.name = "Foco"
	spot.light_energy = 1.6
	spot.light_color = Color(1.0, 0.97, 0.92)
	spot.spot_range = 3.0
	spot.spot_angle = 38.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = false
	spot.position = lp + Vector3(0, -0.06, 0)
	spot.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	lamp.add_child(spot)
	out["lamp"] = spot
	# la máquina de anestesia, junto a la cabeza: el carro, el vaporizador y la bolsa
	var anes := Node3D.new()
	anes.name = "Anestesia"
	root.add_child(anes)
	var ap := Vector3(x0 + 0.25, -TABLE_H, z0 - 0.45)
	_box(anes, Vector3(0.45, 1.1, 0.4), ap + Vector3(0, 0.55, 0), _mat(Color("#D7DCDF"), 0.45), "Carro")
	_box(anes, Vector3(0.12, 0.2, 0.12), ap + Vector3(0.08, 1.2, 0.05), _mat(Color("#C8A23A"), 0.35, 0.3), "Vaporizador")
	_cyl(anes, 0.06, 0.03, ap + Vector3(0.23, 0.95, -0.1), _mat(Color("#222428"), 0.3), "Manometro")
	var bag := _cyl(anes, 0.07, 0.22, ap + Vector3(-0.1, 1.25, 0.12), _mat(Color("#1E2024"), 0.6), "Bolsa", 0.05)
	bag.rotation = Vector3(0.0, 0.0, 0.2)


# ─────────────────────────────── Centro de cetrería ───────────────────────────────

static func _falconry(root: Node3D, edge_x: float, x0: float, z0: float, z1: float, mobile: bool, out: Dictionary, cache: Dictionary) -> void:
	var tsz := 64 if mobile else 128
	var wood_t: Texture2D = _cached(cache, "madera_banco|%d" % tsz, func() -> Texture2D: return wood_tex(tsz * 2, tsz / 2, Color("#B98B5A"), Color("#7A5432"), 4, 21))
	var leg_t: Texture2D = _cached(cache, "madera_patas|%d" % tsz, func() -> Texture2D: return wood_tex(tsz, tsz / 4, Color("#9C7248"), Color("#6A4A2C"), 1, 23))
	var floor_t: Texture2D = _cached(cache, "suelo_cetreria|%d" % tsz, func() -> Texture2D: return plaster_tex(tsz, Color("#A88F6C"), Color("#8C7354"), 8.0, 31))
	var wall_t: Texture2D = _cached(cache, "encalado|%d" % tsz, func() -> Texture2D: return plaster_tex(tsz, Color("#E6E0D2"), Color("#CFC6B2"), 5.0, 33))
	var wood := _tex_mat(wood_t, Vector2(1, 1), 0.65)
	var leg_wood := _tex_mat(leg_t, Vector2(1, 1), 0.7)
	var floor_m := _tex_mat(floor_t, Vector2(5, 5), 0.95)
	var wall_m := _tex_mat(wall_t, Vector2(3, 2), 0.9)
	var w := edge_x - x0
	var d := z1 - z0
	var cx := 0.5 * (x0 + edge_x)
	var cz := 0.5 * (z0 + z1)
	var back_x := x0 - 0.9
	var side_z := z0 - 1.4
	_box(root, Vector3(edge_x + 3.0 - back_x, 0.02, z1 + 3.0 - side_z), Vector3(0.5 * (back_x + edge_x + 3.0), -TABLE_H - 0.01, 0.5 * (side_z + z1 + 3.0)), floor_m, "Suelo")
	_box(root, Vector3(0.05, 2.8, z1 + 3.0 - side_z), Vector3(back_x, -TABLE_H + 1.4, 0.5 * (side_z + z1 + 3.0)), wall_m, "Pared")
	_box(root, Vector3(edge_x + 3.0 - back_x, 2.8, 0.05), Vector3(0.5 * (back_x + edge_x + 3.0), -TABLE_H + 1.4, side_z), wall_m, "ParedLateral")
	# el zócalo de madera y la viga del techo
	_box(root, Vector3(0.03, 0.5, z1 + 3.0 - side_z), Vector3(back_x + 0.03, -TABLE_H + 0.25, 0.5 * (side_z + z1 + 3.0)), leg_wood, "Zocalo")
	# la ventana: luz cálida de la tarde
	var win_c := Vector3(back_x + 0.03, 0.6, cz + 0.35)
	var win_size := Vector2(1.1, 0.9)
	_window(root, win_c, win_size, Color(1.0, 0.9, 0.72), mobile)
	out["window"] = Vector3(back_x, 0.6, cz + 0.35)
	# el banco de trabajo: tablero grueso de tablas, cuatro patas y la balda de abajo
	var top_m := wood.duplicate() as StandardMaterial3D
	top_m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	_box(root, Vector3(w, 0.05, d), Vector3(cx, -0.025, cz), top_m, "Banco")
	for px: float in [x0 + 0.06, edge_x - 0.06]:
		for pz: float in [z0 + 0.06, z1 - 0.06]:
			_box(root, Vector3(0.07, TABLE_H - 0.05, 0.07), Vector3(px, -TABLE_H * 0.5 - 0.025, pz), leg_wood, "Pata")
	_box(root, Vector3(w - 0.08, 0.025, d - 0.08), Vector3(cx, -TABLE_H + 0.2, cz), leg_wood, "Balda")
	if mobile:
		return
	# el estante de la pared: las capuchas de cuero con su copete y los botes
	var shelf := Node3D.new()
	shelf.name = "Estante"
	root.add_child(shelf)
	# al lado de la ventana, nunca delante: la tabla (1 m) acaba 10 cm antes del marco
	var sz := win_c.z - win_size.x * 0.5 - 0.1 - 0.5
	_box(shelf, Vector3(0.22, 0.025, 1.0), Vector3(back_x + 0.12, 0.75, sz), leg_wood, "Tabla")
	var leather := [Color("#5C3B22"), Color("#7A4E2C"), Color("#3E2A1A")]
	for k in 3:
		var hz := sz - 0.3 + 0.17 * float(k)
		var hood := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.07
		sm.is_hemisphere = true
		hood.mesh = sm
		hood.material_override = _mat(leather[k], 0.5)
		hood.position = Vector3(back_x + 0.12, 0.7625, hz)
		hood.name = "Capucha"
		shelf.add_child(hood)
		_cyl(shelf, 0.006, 0.04, Vector3(back_x + 0.12, 0.81, hz), _mat(Color("#C9A25A"), 0.6), "Copete", 0.009, 8)
	for k in 3:
		var bz := sz + 0.2 + 0.1 * float(k)
		_cyl(shelf, 0.035, 0.12, Vector3(back_x + 0.12, 0.8225, bz), _mat([Color("#E9DCC0"), Color("#3E6F8F"), Color("#8A5A34")][k], 0.35), "Bote", -1.0, 14)
	# el guante de cetrería sobre el banco, en la esquina del fondo
	var glove := Node3D.new()
	glove.name = "Guante"
	root.add_child(glove)
	var gp := Vector3(x0 + 0.16, 0.0, z1 - 0.2)
	var gm := _mat(Color("#8B5E36"), 0.75)
	_box(glove, Vector3(0.14, 0.04, 0.1), gp + Vector3(0, 0.02, 0), gm, "Mano")
	var cuff := _cyl(glove, 0.06, 0.2, gp + Vector3(-0.15, 0.04, 0), gm, "Manga", 0.07)
	cuff.rotation = Vector3(0, 0, PI * 0.5)
	for f in 4:
		_box(glove, Vector3(0.06, 0.025, 0.02), gp + Vector3(0.095, 0.015, -0.035 + 0.023 * float(f)), gm, "Dedo")
	# la percha de arco del ave en el suelo, sobre su césped, junto a la pared
	var perch := Node3D.new()
	perch.name = "Percha"
	root.add_child(perch)
	var pp := Vector3(back_x + 0.55, -TABLE_H, z1 + 0.5)
	_cyl(perch, 0.32, 0.02, pp + Vector3(0, 0.01, 0), _mat(Color("#4E7A3A"), 0.95), "Cesped", -1.0, 24)
	var arc := TorusMesh.new()
	arc.inner_radius = 0.2
	arc.outer_radius = 0.235
	arc.rings = 24
	arc.ring_segments = 8
	var am := MeshInstance3D.new()
	am.name = "Arco"
	am.mesh = arc
	am.material_override = _mat(Color("#B89A6A"), 0.85)
	am.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pp + Vector3(0, 0.02, 0))
	perch.add_child(am)


## Una ventana en la pared del fondo (x fija): el cielo que brilla, el marco y los parteluces.
static func _window(root: Node3D, c: Vector3, size: Vector2, sky: Color, mobile: bool) -> void:
	var win := Node3D.new()
	win.name = "Ventana"
	root.add_child(win)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = sky
	glow.emission_enabled = true
	glow.emission = sky
	glow.emission_energy_multiplier = 1.1
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(win, Vector3(0.01, size.y, size.x), c, glow, "Cielo")
	var frame := _mat(Color("#F2F2EE"), 0.5)
	var t := 0.05
	for e: Array in [[Vector3(0.04, t, size.x + t), c + Vector3(0.01, size.y * 0.5, 0)], [Vector3(0.04, t, size.x + t), c + Vector3(0.01, -size.y * 0.5, 0)],
			[Vector3(0.04, size.y, t), c + Vector3(0.01, 0, size.x * 0.5)], [Vector3(0.04, size.y, t), c + Vector3(0.01, 0, -size.x * 0.5)]]:
		_box(win, e[0], e[1], frame, "Marco")
	if not mobile:
		_box(win, Vector3(0.03, size.y, 0.03), c + Vector3(0.012, 0, 0), frame, "Parteluz")
		_box(win, Vector3(0.03, 0.03, size.x), c + Vector3(0.012, 0, 0), frame, "Travesano")
