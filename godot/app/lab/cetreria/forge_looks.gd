## Laboratorio experimental de la reforja · los materiales de la sala con relieve, hechos en código (unidad 5m; petición 45): la
## madera de las mesas, el acero cepillado de las patas, el hierro fundido de las bases, el refractario de la cámara del horno, el
## ladrillo y el hormigón de la sala, la hierba del campo que se ve por las ventanas y el vidrio de las ventanas.
## Cada uno es una textura pequeña de ruido sin costuras (FastNoiseLite.get_seamless_image, nativa) que matiza su color y su
## mapa de normales (el relieve: Image.bump_map_to_normal_map), con mapeo triplanar en el espacio del mundo (no hacen falta
## coordenadas de textura y la densidad es la misma en todas las piezas). Se hacen una sola vez por calidad y se comparten entre
## escenas (la caché es solo de dibujo). Sin descargas ni sombreadores propios: sirven en Compatibility y en el teléfono, con
## texturas más pequeñas. Solo dibujo: no son datos.
## Uso: const ForgeLooks = preload("res://app/lab/cetreria/forge_looks.gd"); mi.material_override = ForgeLooks.material("madera")
extends RefCounted

## Lado de las texturas (px): escritorio y teléfono.
const SIZE := 128
const SIZE_MOBILE := 64
## Cada material: su color, la aspereza, el metal, cuántas veces se repite la textura por metro (los ladrillos, dos de ~24 cm a lo
## ancho y cuatro hiladas de ~7,5 cm a lo alto en cada repetición), la fuerza del relieve, el
## dibujo del ruido («vetas», «cepillado», «poros», «ladrillo» o «manchas»), su frecuencia y lo que matiza el color (de lo a hi).
const LOOKS := {
	"madera": { "color": Color(0.52, 0.37, 0.24), "rough": 0.7, "metal": 0.0, "scale": 2.2, "relief": 0.5, "kind": "vetas", "freq": 0.05, "lo": 0.72, "hi": 1.0 },
	"acero": { "color": Color(0.68, 0.7, 0.73), "rough": 0.36, "metal": 0.85, "scale": 5.0, "relief": 0.2, "kind": "cepillado", "freq": 0.25, "lo": 0.86, "hi": 1.0 },
	"hierro": { "color": Color(0.25, 0.26, 0.28), "rough": 0.8, "metal": 0.55, "scale": 4.0, "relief": 1.1, "kind": "poros", "freq": 0.08, "lo": 0.72, "hi": 1.0 },
	"refractario": { "color": Color(0.86, 0.68, 0.5), "rough": 0.96, "metal": 0.0, "scale": 5.0, "relief": 0.9, "kind": "poros", "freq": 0.14, "lo": 0.8, "hi": 1.0 },
	"ladrillo": { "color": Color(1.0, 1.0, 1.0), "rough": 0.9, "metal": 0.0, "scale": Vector3(2.1, 3.3, 2.1), "relief": 2.2, "kind": "ladrillo", "freq": 0.12, "lo": 0.85, "hi": 1.0 },
	"hormigon": { "color": Color(0.56, 0.55, 0.53), "rough": 0.93, "metal": 0.0, "scale": 0.9, "relief": 0.7, "kind": "manchas", "freq": 0.035, "lo": 0.78, "hi": 1.0 },
	"hierba": { "color": Color(0.34, 0.54, 0.22), "rough": 0.96, "metal": 0.0, "scale": 0.12, "relief": 0.0, "kind": "manchas", "freq": 0.03, "lo": 0.7, "hi": 1.0 },
}
## Los colores del ladrillo (de dibujo): la llaga de mortero y los ladrillos, que varían un poco unos de otros.
const MORTAR := Color(0.66, 0.64, 0.6)
const BRICK := Color(0.6, 0.31, 0.23)

static var _cache := {}
## Cuántos materiales se han construido (los tests comprueban que se comparten).
static var built := 0


## El material de la sala id (LOOKS) para esa calidad; tint (opcional) cambia su color sin rehacer las texturas.
static func material(id: String, mobile := false, tint := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [id, str(mobile), tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var lk: Dictionary = LOOKS.get(id, LOOKS.hormigon)
	var tex := _textures(id, mobile)
	var m := StandardMaterial3D.new()
	m.albedo_color = tint if tint.a > 0.0 else Color(lk.color)
	m.albedo_texture = tex.albedo
	m.roughness = float(lk.rough)
	m.metallic = float(lk.metal)
	if float(lk.relief) > 0.0:
		m.normal_enabled = true
		m.normal_texture = tex.normal
		m.normal_scale = float(lk.relief)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	# un número: lo mismo en las tres direcciones; un vector, cada una la suya (los ladrillos, más anchos que altos)
	m.uv1_scale = lk.scale if lk.scale is Vector3 else Vector3.ONE * float(lk.scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	built += 1
	return m


## El vidrio de las ventanas: transparente, liso y que refleja algo del cielo.
static func glass() -> StandardMaterial3D:
	if _cache.has("vidrio"):
		return _cache.vidrio
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.9, 0.95, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["vidrio"] = m
	built += 1
	return m


## Las dos texturas de un material (el matiz del color y las normales), una vez por material y calidad.
static func _textures(id: String, mobile: bool) -> Dictionary:
	var key := "tex|%s|%s" % [id, str(mobile)]
	if _cache.has(key):
		return _cache[key]
	var lk: Dictionary = LOOKS.get(id, LOOKS.hormigon)
	var n := SIZE_MOBILE if mobile else SIZE
	var height := _height(String(lk.kind), n, float(lk.freq), id.hash())
	var albedo: Image
	if String(lk.kind) == "ladrillo":
		albedo = _brick_colors(n)
	else:
		albedo = _remap(height, float(lk.lo), float(lk.hi))
	albedo.generate_mipmaps()
	var normal := height.duplicate() as Image
	normal.bump_map_to_normal_map(1.0)
	normal.generate_mipmaps()
	var out := { "albedo": ImageTexture.create_from_image(albedo), "normal": ImageTexture.create_from_image(normal) }
	_cache[key] = out
	return out


## El relieve (gris, sin costuras) de cada dibujo: las vetas de la madera (ruido estirado a lo largo), el cepillado del acero
## (rayas finas), los poros del hierro fundido y del refractario (ruido celular), los ladrillos con sus llagas y las manchas del
## hormigón y de la hierba.
static func _height(kind: String, n: int, freq: float, seed_v: int) -> Image:
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.frequency = freq
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	var img: Image
	match kind:
		"vetas":
			fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			img = fn.get_seamless_image(n, maxi(n / 8, 4))
			img.resize(n, n, Image.INTERPOLATE_BILINEAR)
		"cepillado":
			fn.noise_type = FastNoiseLite.TYPE_VALUE
			fn.fractal_octaves = 2
			img = fn.get_seamless_image(n, 4)
			img.resize(n, n, Image.INTERPOLATE_BILINEAR)
		"poros":
			fn.noise_type = FastNoiseLite.TYPE_CELLULAR
			fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			img = fn.get_seamless_image(n, n)
		"ladrillo":
			img = _brick_height(n)
		_:
			fn.noise_type = FastNoiseLite.TYPE_PERLIN
			img = fn.get_seamless_image(n, n)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	return img


## El matiz del color: el gris del relieve llevado de lo a hi (multiplica el color del material).
static func _remap(src: Image, lo: float, hi: float) -> Image:
	var lut := PackedByteArray()
	lut.resize(256)
	for i in 256:
		lut[i] = int(round(255.0 * (lo + (hi - lo) * float(i) / 255.0)))
	var data := src.get_data()
	for i in data.size():
		data[i] = lut[data[i]]
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_L8, data)


## Los ladrillos a soga (dos por hilada, la de arriba corrida medio ladrillo), sin costuras; el número de cada uno decide su tono.
static func _brick_rects(n: int) -> Array:
	var out: Array = []
	var rows := 4
	var bh := n / rows
	var bw := n / 2
	var mortar := maxi(n / 32, 1)
	for r in rows:
		var off := bw / 2 if r % 2 == 1 else 0
		for c in range(-1, 3):
			var rect := Rect2i(c * bw + off + mortar, r * bh + mortar, bw - 2 * mortar, bh - 2 * mortar).intersection(Rect2i(0, 0, n, n))
			if rect.size.x > 0 and rect.size.y > 0:
				out.append([rect, r * 2 + posmod(c, 2)])
	return out


static func _brick_height(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	img.fill(Color(0.15, 0.15, 0.15))
	for e: Array in _brick_rects(n):
		var v := 0.8 + 0.15 * _jitter(int(e[1]))
		img.fill_rect(e[0], Color(v, v, v))
	return img


static func _brick_colors(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(MORTAR)
	for e: Array in _brick_rects(n):
		var j := _jitter(int(e[1]) + 11)
		img.fill_rect(e[0], BRICK.lerp(Color(0.5, 0.24, 0.18), j).lightened(0.12 * _jitter(int(e[1]) + 23)))
	return img


## Un número de 0 a 1 que depende solo de i (sin azar: la sala sale siempre igual).
static func _jitter(i: int) -> float:
	var h := (i * 1103515245 + 12345) & 0x7fffffff
	h = (h * 1103515245 + 12345) & 0x7fffffff
	return float(h % 1000) / 999.0
