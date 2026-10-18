## Aleatorio determinista idéntico al de art.js: mulberry32 con la semilla FNV-1a de seedOf.
##
## El mismo texto de semilla da la misma secuencia en JavaScript y en GDScript, así que las ilustraciones y las
## virutas salen iguales en cada ejecución y en cada plataforma. Nada en core usa randf() ni la hora.
## Uso:
##   const Rng = preload("res://core/shared/rng.gd")
##   var R := Rng.new(Rng.seed_of("madera:300x60"))
##   var x := R.next()   # [0, 1), el mismo valor que R() en art.js
extends RefCounted

const Js = preload("res://core/shared/js.gd")

var _a: int


func _init(seed: int = 0) -> void:
	_a = seed & 0xFFFFFFFF


## Siguiente número en [0, 1). Todas las operaciones se hacen en enteros sin signo de 32 bits, que dan los
## mismos bits que las operaciones con signo de JavaScript.
func next() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := Js.imul32(_a ^ (_a >> 15), 1 | _a) & 0xFFFFFFFF
	t = ((t + (Js.imul32(t ^ (t >> 7), 61 | t) & 0xFFFFFFFF)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


## seedOf de art.js: FNV-1a de 32 bits sobre las unidades UTF-16 del texto (charCodeAt).
static func seed_of(s: String) -> int:
	var x := 2166136261
	for i in s.length():
		var code := s.unicode_at(i)
		if code > 0xFFFF:  # fuera del plano básico: JavaScript ve primero el sustituto alto
			code = 0xD800 + ((code - 0x10000) >> 10)
		x = Js.imul32(x ^ code, 16777619) & 0xFFFFFFFF
	return x


## Atajo: un generador a partir de un texto de semilla.
static func from_text(s: String) -> RefCounted:
	return load("res://core/shared/rng.gd").new(seed_of(s))
