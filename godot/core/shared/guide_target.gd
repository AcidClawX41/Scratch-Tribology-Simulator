## Guiado botón a botón (unidad 5x): el formato común del objetivo de una acción del tutorial, sin nodos y determinista.
## Lo usa la reforja (core/lab/claw_forge_guide.gd) y lo puede usar cualquier otro tutorial (la cetrería, 5y): el motor dice
## qué hay que pulsar ahora y con qué valor; la interfaz (app/common/guide_overlay.gd) solo lo pinta.
##
## Objetivo: { on, id, where, view, label, hint, value, scene, panel, op, args, step }
##   on      si hay guiado (false: nada que pintar; el resto, vacío)
##   id      id estable de lo que se pulsa: el del control del panel o el del objeto de la escena («dosis:co:2»,
##           «mando:temp_c», «arrancar»…)
##   where   dónde se hace sobre todo: "panel" (un control del panel de la derecha) o "scene" (un objeto de la vista 3D)
##   view    la vista de la cámara que lo enseña («banco», «horno»…; «» si no cambia)
##   label   la etiqueta corta junto al control del panel («Pulsa aquí: +0.1 g de cobalto»)
##   hint    el aviso corto sobre la vista 3D, con el valor exacto o lo que falta («Añade 0.198 g de Co»)
##   value   el valor exacto que hay que poner o lo que falta («1450 °C», «0.198 g»); «» si no hay
##   scene   el id del objeto de la escena que se resalta («» si ninguno)
##   panel   el id del control del panel que se resalta («» si ninguno)
##   op/args la orden del estado que manda ese control (la misma que su botón): con ella, un test juega pulsando solo lo
##           que señala el guiado
##   step    el id del paso del tutorial
## Puede llevar claves propias de cada tutorial (la reforja: «u», el punto de la costura que toca, de 0 a 1).
## Números: con la misma forma que el resto de la pantalla, para que en ella no salgan dos (Js.to_fixed: la reforja, con punto
## decimal, como su panel y su escena); comma() solo para una pantalla cuyos textos ya van con coma.
extends RefCounted

const KEYS := ["on", "id", "where", "view", "label", "hint", "value", "scene", "panel", "op", "args", "step"]

## Un objetivo con todo lo que pinta la interfaz.
static func make(id: String, where: String, view: String, label: String, hint: String, value := "", scene := "", panel := "",
		op := "", args: Array = [], step := "") -> Dictionary:
	return { "on": true, "id": id, "where": where, "view": view, "label": label, "hint": hint, "value": value, "scene": scene,
		"panel": panel, "op": op, "args": args, "step": step }


## Sin guiado (el tutorial apagado, el guiado apagado o el tutorial terminado).
static func off() -> Dictionary:
	return { "on": false, "id": "", "where": "", "view": "", "label": "", "hint": "", "value": "", "scene": "", "panel": "",
		"op": "", "args": [], "step": "" }


## ¿Tiene la forma del contrato? (Las claves, un sitio válido y, si está encendido, algo que pulsar y un aviso.)
static func is_valid(t: Dictionary) -> bool:
	for k: String in KEYS:
		if not t.has(k):
			return false
	if not bool(t.on):
		return true
	return String(t.where) in ["panel", "scene"] and String(t.id) != "" and String(t.hint) != "" and String(t.label) != "" \
		and (String(t.panel) != "" or String(t.scene) != "")


## La coma decimal en los números de un texto ya formateado con Js («0.198 g» → «0,198 g»): solo el punto entre dos cifras; el
## resto no cambia. Sin estado (se llama desde el hilo del estado y desde el de la interfaz).
static func comma(s: String) -> String:
	var out := s
	for i in range(1, s.length() - 1):
		if s[i] == "." and _digit(s[i - 1]) and _digit(s[i + 1]):
			out[i] = ","
	return out


static func _digit(c: String) -> bool:
	return c >= "0" and c <= "9"
