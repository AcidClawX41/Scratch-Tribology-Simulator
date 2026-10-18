## Vibración del teléfono con los efectos de sonido: los hápticos de la 1.x móvil (apps/mobile/src/sound.js, con
## expo-haptics). Cada efecto tiene un pulso [duración en ms, intensidad de 0 a 1] con el carácter del estilo que tenía
## en la 1.x: selección, impacto suave, ligero, medio, rígido o fuerte, y los avisos de éxito, advertencia y error, que
## aquí son un pulso más largo (Input.vibrate_handheld no hace patrones). Son valores de diseño, no mediciones.
## - Solo vibra en móvil (OS.has_feature("mobile")): en escritorio no hace nada.
## - Android necesita el permiso VIBRATE (export_presets.cfg → permissions/vibrate); iOS no pide permiso. La intensidad
##   la respetan Android 8+ e iOS 13+; en los demás, la del sistema.
## - `enabled` es el ajuste del usuario ([lab] haptics en ajustes.cfg; lo guarda lab_section.gd).
## Uso: var h := Haptics.new(); h.play("scratch-metal")
extends RefCounted

const SELECTION := [10, 0.25]
const SOFT := [15, 0.3]
const LIGHT := [20, 0.4]
const MEDIUM := [30, 0.6]
const RIGID := [20, 0.9]
const HEAVY := [45, 1.0]
const SUCCESS := [60, 0.5]
const WARNING := [80, 0.7]
const ERROR := [120, 0.9]

## Pulso de cada efecto de core/lab/sfx.gd (los 22 de la 1.x, con el mismo estilo que en sound.js) y de los efectos
## cortos de los aguijones de la 2.0 (core/lab/sfx_insects.gd): el picotazo, un toque ligero como una punta que entra;
## el desgarro del aparato del aguijón, medio, y el pandeo, rígido, como un golpe seco. El zumbido es un bucle que
## acompaña al vuelo: no vibra.
const PULSES := {
	"tap": SELECTION, "on": SELECTION, "off": SELECTION, "drip": SELECTION,
	"slide": SOFT, "squeak": SOFT, "skin-rub": SOFT, "press": SOFT,
	"scratch-soft": LIGHT, "scratch-wood": LIGHT, "skin-cut": MEDIUM,
	"scratch-metal": RIGID, "scratch-glass": RIGID, "scratch-deep": HEAVY,
	"pierce": MEDIUM, "inject": MEDIUM, "pierce-solid": HEAVY,
	"pierce-brittle": RIGID, "breakthrough": HEAVY,
	"shatter": WARNING, "snap": ERROR, "badge": SUCCESS,
	"picotazo": LIGHT, "desgarro-aguijon": MEDIUM, "pandeo-aguijon": RIGID,
}

## El ajuste del usuario: vibrar o no.
var enabled := true
## ¿Hay con qué vibrar? Solo en móvil (los tests lo fuerzan para probar la interfaz en escritorio).
var available := OS.has_feature("mobile")


## [duración en ms, intensidad 0-1] del efecto `id`, o [] si no vibra.
static func pulse_for(id: String) -> Array:
	return PULSES.get(id, [])


## Vibra con el pulso del efecto `id` si se puede y el usuario no lo ha apagado. Devuelve si ha vibrado.
func play(id: String) -> bool:
	var p := pulse_for(id)
	if not enabled or not available or p.is_empty():
		return false
	_vibrate(p[0], p[1])
	return true


## (Los tests lo sustituyen para contar los pulsos sin vibrar.)
func _vibrate(ms: int, amplitude: float) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
