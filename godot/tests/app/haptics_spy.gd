## Vibración de prueba: puede vibrar, como en un teléfono, y apunta los pulsos en vez de vibrar.
extends "res://app/common/haptics.gd"

## [duración en ms, intensidad] de cada pulso, en orden.
var pulses: Array = []


func _init() -> void:
	available = true


func _vibrate(ms: int, amplitude: float) -> void:
	pulses.append([ms, amplitude])
