## Doble de LabState para los tests: apunta con qué modelo de la física llega al core cada cálculo del banco
## (compute, duel y resolve_tool) y lo deja pasar. Se pone en la sección con `state_script` antes de setup().
## Las filas de la comparativa se calculan en hilos: las notas van con un Mutex.
extends "res://core/lab/lab_state.gd"

## [qué, modelo]: qué es "compute", "duel", "tool" o "sharpness" (el afilado de una garra reforjada, 2.0); modelo, el
## `model` de los parámetros que recibe el core.
var seen: Array = []
var _seen_lock := Mutex.new()


func _note(what: String, p: Dictionary) -> void:
	_seen_lock.lock()
	seen.append([what, p.get("model")])
	_seen_lock.unlock()


func _core_compute(p: Dictionary) -> Dictionary:
	_note("compute", p)
	return super(p)


func _core_duel(p: Dictionary, claw_v: Variant, cars: Array) -> Array:
	_note("duel", p)
	return super(p, claw_v, cars)


func _core_tool(p: Dictionary) -> Dictionary:
	_note("tool", p)
	return super(p)


func _core_sharpness(p: Dictionary) -> Variant:
	_note("sharpness", p)
	return super(p)


## Modelos distintos que han llegado al core con cada tipo de cálculo: { qué: { modelo: veces } }.
func summary() -> Dictionary:
	var out := {}
	_seen_lock.lock()
	for s: Array in seen:
		var by: Dictionary = out.get(s[0], {})
		by[s[1]] = int(by.get(s[1], 0)) + 1
		out[s[0]] = by
	_seen_lock.unlock()
	return out
