## Cetrería · partículas de dibujo para un MultiMesh (polvo de queratina, esquirlas de una punta mellada, gotas de
## sangre): posiciones, velocidades y vidas en arrays de capacidad fija, con gravedad y rozamiento con el aire, que
## caen hasta la mesa. Sin nodos: la escena copia fill() al búfer del MultiMesh (transformación 3D y color por
## partícula). Determinista: el azar sale de core/shared/rng.gd con una semilla. Todo en metros y segundos; lo que sale
## de aquí es dibujo, no física (el volumen arrancado lo da ClawCare y solo decide cuántas partículas salen).
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")

## Floats por partícula en el búfer: 12 de la transformación y 4 del color.
const FLOATS := 16
const GRAVITY := Vector3(0.0, -9.81, 0.0)

var capacity := 256
## Rozamiento con el aire (1/s): el polvo fino frena enseguida.
var drag := 4.0
## Altura de la mesa (m): lo que cae se queda ahí y se apaga.
var floor_y := 0.0
## Hueco sin mesa entre x = gap_x.x y gap_x.y (m: entre la mesa y el carro): lo que cae ahí sigue hasta el suelo.
var gap_x := Vector2(INF, -INF)
var gap_floor_y := -0.75
var count := 0
var landed := 0
var _rng: Rng
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _col := PackedColorArray()
var _buf := PackedFloat32Array()


func _init(p_capacity: int = 256, seed_text: String = "cetreria-polvo") -> void:
	capacity = p_capacity
	_rng = Rng.from_text(seed_text)
	# (los arrays empaquetados se copian al meterlos en otro array: se dimensiona cada uno)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_age.resize(capacity)
	_life.resize(capacity)
	_size.resize(capacity)
	_drag.resize(capacity)
	_col.resize(capacity)
	_buf.resize(capacity * FLOATS)


## Saca n partículas en at, hacia dir (unitario) con un cono de spread radianes y una velocidad de hasta speed m/s; drag_k, su
## rozamiento con el aire (1/s; el de la reserva, drag, si es negativo).
func spawn(at: Vector3, dir: Vector3, spread: float, speed: float, n: int, size: float, color: Color, life_s: float, drag_k := -1.0) -> void:
	var d := dir.normalized() if dir.length_squared() > 1e-12 else Vector3.UP
	var ref := Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.BACK
	var e1 := d.cross(ref).normalized()
	var e2 := d.cross(e1)
	for k in n:
		if count >= capacity:
			return
		var a := _rng.next() * TAU
		var r := sin(spread * _rng.next())
		var v := (d * sqrt(maxf(1.0 - r * r, 0.0)) + (e1 * cos(a) + e2 * sin(a)) * r) * speed * (0.35 + 0.65 * _rng.next())
		_pos[count] = at
		_vel[count] = v
		_age[count] = 0.0
		_life[count] = life_s * (0.6 + 0.8 * _rng.next())
		_size[count] = size * (0.5 + _rng.next())
		_drag[count] = drag_k if drag_k >= 0.0 else drag
		_col[count] = color
		count += 1


## Avanza dt: gravedad, rozamiento, la mesa; las que se apagan se quitan (la última pasa a su hueco).
func step(dt: float) -> void:
	var i := 0
	# el rozamiento de cada partícula (las de una misma tanda lo comparten: la exponencial, solo cuando cambia)
	var k_last := -1.0
	var k := 1.0
	while i < count:
		_age[i] += dt
		var p := _pos[i]
		var fy := gap_floor_y if p.x > gap_x.x and p.x < gap_x.y else floor_y
		if p.y > fy:
			if _drag[i] != k_last:
				k_last = _drag[i]
				k = exp(-k_last * dt)
			var v := (_vel[i] + GRAVITY * dt) * k
			_vel[i] = v
			p += v * dt
			if p.y <= fy:
				p.y = fy
				_vel[i] = Vector3.ZERO
				landed += 1
			_pos[i] = p
		if _age[i] >= _life[i]:
			count -= 1
			_pos[i] = _pos[count]
			_vel[i] = _vel[count]
			_age[i] = _age[count]
			_life[i] = _life[count]
			_size[i] = _size[count]
			_drag[i] = _drag[count]
			_col[i] = _col[count]
			continue
		i += 1


## Búfer del MultiMesh: cada partícula mirando a la cámara (basis: la de la cámara), del tamaño que le toca y con el
## color apagándose al final de su vida.
func fill(cam_basis: Basis) -> PackedFloat32Array:
	for i in count:
		var s := _size[i]
		var b := cam_basis.scaled(Vector3(s, s, s))
		var p := _pos[i]
		var o := i * FLOATS
		_buf[o] = b.x.x
		_buf[o + 1] = b.y.x
		_buf[o + 2] = b.z.x
		_buf[o + 3] = p.x
		_buf[o + 4] = b.x.y
		_buf[o + 5] = b.y.y
		_buf[o + 6] = b.z.y
		_buf[o + 7] = p.y
		_buf[o + 8] = b.x.z
		_buf[o + 9] = b.y.z
		_buf[o + 10] = b.z.z
		_buf[o + 11] = p.z
		var c := _col[i]
		var fade := clampf((_life[i] - _age[i]) / maxf(_life[i] * 0.3, 1e-3), 0.0, 1.0)
		_buf[o + 12] = c.r
		_buf[o + 13] = c.g
		_buf[o + 14] = c.b
		_buf[o + 15] = c.a * fade
	return _buf


func clear() -> void:
	count = 0
	landed = 0
