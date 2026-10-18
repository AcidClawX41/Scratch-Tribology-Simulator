## Sonidos del laboratorio: qué efecto suena con cada resultado. Port de sfxForResult (packages/core/src/sfx.js).
##
## Los 22 efectos se sintetizaron en la 1.x y se reutilizan tal cual: son los WAV de res://assets/sfx/lab/ (22 050 Hz,
## PCM de 16 bits, mono), idénticos byte a byte a los de la app móvil (tests/lab/test_sfx.gd lo comprueba con su
## sha256). Aquí solo se decide cuál toca; la app los reproduce (AudioStreamPlayer, en todas las plataformas).
## Uso: const Sfx = preload("res://core/lab/sfx.gd"); var id := Sfx.sfx_for_result(res, target); Sfx.path_of(id).
extends RefCounted

const V8 = preload("res://core/shared/v8_math.gd")
const Looks = preload("res://core/lab/looks.gd")

## Ids de los efectos, en el orden de sfx.js (interfaz, rayado, piel y punción).
const SFX_IDS := [
	"tap", "on", "off", "badge", "drip",
	"slide", "squeak", "scratch-soft", "scratch-deep", "scratch-wood", "scratch-metal", "scratch-glass",
	"skin-rub", "skin-cut",
	"press", "pierce", "inject", "pierce-solid", "pierce-brittle", "breakthrough", "shatter", "snap",
]
## Frecuencia de muestreo de los WAV (Hz).
const SFX_RATE := 22050
const SFX_DIR := "res://assets/sfx/lab/"
## Texturas que suenan a frágil (vidrio, pantalla, piedra, cristal, diamante).
const _BRITTLE := ["glass", "screen", "stone", "crystal", "diamond"]

## Mezcla (docs/fase2/qa-sonido.md). Cada efecto de res://assets/sfx/lab/ tiene su clase, y cada clase, una banda de
## sonoridad (LUFS momentáneos máximos, ponderación K de ITU-R BS.1770, un canal, medidos con Movie Maker después del
## limitador de «Master», al volumen con que lo pide el programa):
##   ui −30…−26 (clics, interruptores, pitidos) · logro −24…−20 · resultado −21…−17 (lo que suena al acabar un ensayo o una
##   pasada) · impacto −21…−17 (golpes, roturas, voces del animal, colada y temple) · herramienta −26…−22 (bucles de motores,
##   máquinas y roces; arranque y parada) · ambiente −30…−26 (el zumbido del insecto).
## Y ningún efecto suelto pasa de 0,70 de pico (−3 dBFS), para que la suma de dos no llegue al limitador.
const KIND := {
	"tap": "ui", "on": "ui", "off": "ui", "drip": "ui", "lampara-pitido": "ui",
	"badge": "logro",
	"slide": "resultado", "squeak": "resultado", "scratch-soft": "resultado", "scratch-deep": "resultado",
	"scratch-wood": "resultado", "scratch-metal": "resultado", "scratch-glass": "resultado", "skin-rub": "resultado",
	"skin-cut": "resultado", "press": "resultado", "pierce": "resultado", "inject": "resultado", "pierce-solid": "resultado",
	"pierce-brittle": "resultado", "breakthrough": "resultado", "picotazo": "resultado", "desgarro-aguijon": "resultado",
	"pandeo-aguijon": "resultado",
	"shatter": "impacto", "snap": "impacto", "reaccion-rapaz": "impacto", "reaccion-buho": "impacto",
	"reaccion-tigre": "impacto", "reaccion-oso": "impacto", "reaccion-raptor": "impacto", "lente-plastico": "impacto",
	"lente-vidrio": "impacto", "lente-grieta": "impacto", "lente-rasguno": "impacto", "forja-colada": "impacto",
	"forja-temple": "impacto",
	"torno-garras": "herramienta", "amoladora-garras": "herramienta", "lima-garra": "herramienta",
	"motor-arranque": "herramienta", "motor-parada": "herramienta", "lente-pano": "herramienta", "forja-horno": "herramienta",
	"forja-llama": "herramienta", "forja-induccion": "herramienta", "forja-prensa": "herramienta", "forja-muela": "herramienta",
	"forja-pulso": "herramienta", "forja-arco": "herramienta",
	"zumbido-abeja": "ambiente", "zumbido-abejorro": "ambiente", "zumbido-avispa": "ambiente", "zumbido-avispon": "ambiente",
	"zumbido-papelera": "ambiente", "zumbido-velutina": "ambiente",
}
## Ajuste de cada efecto (dB) para que caiga en la banda de su clase: lo que faltaba o sobraba al medirlo, en pasos de
## 0,5 dB, sin pasar el pico de 0,70 al subir (los 22 WAV de la 1.x no se tocan: son los de la app móvil). Los que no
## están, 0 dB. Medida: docs/fase2/qa-sonido.md.
const TRIM_DB := {
	"on": -7.5, "off": -7.5, "tap": 3.5, "drip": -3.0, "lampara-pitido": -2.0, "badge": -3.5,
	"slide": -0.5, "squeak": -3.5, "scratch-soft": -3.5, "scratch-deep": -2.0, "scratch-metal": -5.0, "scratch-glass": -5.0,
	"skin-cut": -1.0, "press": 1.5, "inject": -2.5, "pierce-solid": 1.0, "pierce-brittle": 3.5, "picotazo": 1.0,
	"desgarro-aguijon": -1.0, "pandeo-aguijon": -2.5,
	"shatter": 1.0, "snap": 3.5, "reaccion-rapaz": -4.0, "reaccion-buho": 3.0, "reaccion-tigre": 0.5, "reaccion-oso": 2.5,
	"lente-plastico": 6.5, "lente-grieta": 3.0, "forja-colada": -4.0, "forja-temple": -4.0,
	"torno-garras": -0.5, "amoladora-garras": -0.5, "motor-arranque": -1.5, "motor-parada": 0.5, "lente-pano": -3.5,
	"forja-llama": -4.0, "forja-induccion": -2.0, "forja-prensa": -1.5, "forja-muela": -2.5,
	"forja-pulso": 4.5, "forja-arco": 4.0,
	"zumbido-abeja": -2.5, "zumbido-abejorro": -2.5, "zumbido-avispa": -2.5, "zumbido-avispon": -2.5,
	"zumbido-papelera": -2.5, "zumbido-velutina": -2.5,
}
## Muestras del principio de un bucle que se repiten al final del WAV, después de edit/loop_end (que sigue en la última
## muestra del bucle): Godot 4.7.2 interpola leyendo pasado loop_end y, sin ellas, cada vuelta daba un chasquido de hasta el
## doble del pico del bucle (medido con Movie Maker: 0,93 en la prensa de la reforja a volumen 1).
const LOOP_TAIL := 32


## Ruta del WAV de un efecto.
static func path_of(id: String) -> String:
	return SFX_DIR + id + ".wav"


## Ganancia lineal de la mezcla de un efecto (TRIM_DB): los reproductores la multiplican por el volumen que pide el estado.
static func gain(id: String) -> float:
	return V8.js_pow(10.0, float(TRIM_DB.get(id, 0.0)) / 20.0)


## Las muestras de un bucle con su cola (LOOP_TAIL muestras de su principio) para hornearlo: el .import lo cierra en
## x.size() (edit/loop_end) y la cola solo la lee la interpolación.
static func with_loop_tail(x: PackedFloat32Array) -> PackedFloat32Array:
	var out := x.duplicate()
	for i in mini(LOOP_TAIL, x.size()):
		out.append(x[i])
	return out


## Qué efecto corresponde al resultado de un ensayo (cada situación suena distinta). `res` es el resultado de
## compute() y `target`, el material del catálogo (con su `body` si es un coche).
static func sfx_for_result(res: Dictionary, target: Dictionary) -> String:
	var look: Variant = Looks.MATERIAL_LOOK.get(target.get("id"))
	var kind: Variant = look["kind"] if look != null else null
	var brittle: bool = kind in _BRITTLE
	var depth := _num(res, "depthUm")
	if _truthy(res.get("shattered")):
		return "shatter"
	if _truthy(res.get("toolBroken")):
		return "snap"
	if _truthy(res.get("puncture")):
		if _truthy(res.get("skin")):
			if not _truthy(res.get("pierces")):
				return "press"
			return "inject" if _truthy(res.get("inject")) else "pierce"
		if _truthy(res.get("through")):
			return "breakthrough"
		if not _truthy(res.get("scratched")) or depth <= 1.0:
			return "press"
		return "pierce-brittle" if brittle else "pierce-solid"
	if _truthy(res.get("skin")):
		# «scratched» puede ser "faint" (marca roja, rasguño blanco): solo un true cuenta como corte
		var cut: bool = typeof(res.get("scratched")) == TYPE_BOOL and res["scratched"]
		return "skin-cut" if cut else "skin-rub"
	if not _truthy(res.get("scratched")):
		return "squeak" if _truthy(res.get("toolWorn")) and brittle else "slide"
	# chapa de coche o puerta: la garra rechina contra el metal (o raja el plástico)
	var body: Variant = target.get("body")
	var metal_body: bool = _truthy(body) and _truthy(body.get("metal"))
	if _truthy(res.get("through")):
		return "scratch-deep" if _truthy(body) and not metal_body else "scratch-metal"
	if metal_body and depth > 110.0:
		return "scratch-metal"
	if brittle:
		return "scratch-glass"
	if kind == "brushed" or kind == "copper":
		return "scratch-metal"
	if kind == "wood":
		return "scratch-wood"
	if res.get("absMode") == "corte" and _num(res, "sev") > 0.6:
		return "scratch-deep"
	return "scratch-soft"


## Boolean(v) de JavaScript.
static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(v).is_empty()
	return true


## Número de un campo como lo compara JavaScript: ausente (undefined) → NaN, null → 0.
static func _num(d: Dictionary, key: String) -> float:
	if not d.has(key):
		return NAN
	var v: Variant = d[key]
	match typeof(v):
		TYPE_NIL:
			return 0.0
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(v)
	return NAN
