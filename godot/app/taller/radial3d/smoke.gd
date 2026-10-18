## Humo de la pintura y del plástico que se queman junto al corte. Solo dibujo, determinista (core/shared/rng.gd):
## bocanadas que nacen en la zona caliente del surco, suben por flotación, se hinchan y se desvanecen.
## La intensidad (0-1) la da el modelo de corte (campo `smoke` propuesto; si falta, la escena la deduce de la
## pintura quemada). Velocidades y tamaños: ESTIMACIÓN visual.
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")

const MAX_PUFFS := 160
const FLOATS := 20

var _rng: Rng
var _rate := 0.0
var _color := Color(0.56, 0.54, 0.52, 0.34)
var _acc := 0.0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size0 := PackedFloat32Array()
var _size1 := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _buf := PackedFloat32Array()


func _init(seed_text: String = "humo") -> void:
	_rng = Rng.new(Rng.seed_of(seed_text))


## intensity 0-1 → hasta 45 bocanadas por segundo; color con alfa máximo.
func configure(intensity: float, color: Color) -> void:
	_rate = clampf(intensity, 0.0, 1.0) * 60.0
	_color = color


func reset() -> void:
	for arr in [_pos, _vel, _age, _life, _size0, _size1, _seed]:
		arr.resize(0)
	_acc = 0.0


func count() -> int:
	return _age.size()


## Avanza dt segundos. sources: puntos de la zona caliente (m) donde nace el humo; up: la vertical.
func step(dt: float, sources: PackedVector3Array, up: Vector3 = Vector3.UP) -> void:
	var i := 0
	while i < _age.size():
		_age[i] += dt
		if _age[i] >= _life[i]:
			_remove(i)
			continue
		var v := _vel[i]
		v += up * (0.35 * dt)  # flotación del aire caliente
		v *= 1.0 - minf(1.2 * dt, 0.5)  # frena contra el aire
		var wob := sin(_age[i] * 3.1 + _seed[i] * 11.0) * 0.004
		_vel[i] = v
		_pos[i] += (v + Vector3(wob, 0.0, wob * 0.6)) * dt
		i += 1
	if sources.is_empty():
		return
	_acc += _rate * dt
	var n := int(floor(_acc))
	_acc -= float(n)
	for k in n:
		if _age.size() >= MAX_PUFFS:
			_acc = 0.0
			break
		var src := sources[int(_rng.next() * sources.size()) % sources.size()]
		_pos.append(src + Vector3(_rng.next() - 0.5, 0.0, _rng.next() - 0.5) * 0.003)
		_vel.append(up * lerpf(0.02, 0.06, _rng.next()) + Vector3(_rng.next() - 0.5, 0.0, _rng.next() - 0.5) * 0.02)
		_age.append(0.0)
		_life.append(lerpf(1.6, 3.2, _rng.next()))
		_size0.append(lerpf(0.002, 0.004, _rng.next()))
		_size1.append(lerpf(0.03, 0.065, _rng.next()))
		_seed.append(_rng.next())


func _remove(i: int) -> void:
	var last := _age.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_age[i] = _age[last]
		_life[i] = _life[last]
		_size0[i] = _size0[last]
		_size1[i] = _size1[last]
		_seed[i] = _seed[last]
	for arr in [_pos, _vel, _age, _life, _size0, _size1, _seed]:
		arr.resize(last)


## Búfer del MultiMesh (TRANSFORM_3D + color + custom): origen = centro, |base X| = tamaño.
func buffer(capacity: int) -> PackedFloat32Array:
	var n := _age.size()
	_buf.resize(maxi(n, capacity) * FLOATS)
	for i in n:
		var u := _age[i] / _life[i]
		var size := lerpf(_size0[i], _size1[i], sqrt(u))
		var a := _color.a * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.45, 1.0, u))
		var o := i * FLOATS
		var p := _pos[i]
		var row := [size, 0.0, 0.0, p.x, 0.0, size, 0.0, p.y, 0.0, 0.0, size, p.z]
		for k in 12:
			_buf[o + k] = row[k]
		_buf[o + 12] = _color.r
		_buf[o + 13] = _color.g
		_buf[o + 14] = _color.b
		_buf[o + 15] = a
		_buf[o + 16] = _seed[i]
		_buf[o + 17] = u
		_buf[o + 18] = 0.0
		_buf[o + 19] = 0.0
	return _buf
