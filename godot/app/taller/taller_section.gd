## Taller industrial · raíz de la sección (unidad 13).
##
## Contrato con app/main (unidad 12): main la carga desde res://app/taller/taller_section.tscn y la pone en
## PROCESS_MODE_DISABLED mientras no se ve, así que la animación, la simulación y el sonido se pausan solos. El
## taller suena por los buses «Maquina» y «MaquinaCorte» (el laboratorio, por «Lab»).
##
## Una barra con las máquinas (torno, fresadora, taladro, radial, afiladora y calculadoras), el aviso de valores
## orientativos y la página de la máquina activa. Hay dos estados, sin nodos: WorkshopState (core/taller/
## workshop_state.gd) para el torno, la radial, la afiladora y las calculadoras (sus páginas, en `pages`), y
## MillDrillState (core/taller/mill_drill_state.gd) para la fresadora y el taladro (en `md_pages`). Las páginas pintan lo
## que sale de ellos y les mandan los cambios; aquí no se calcula nada. Una máquina a la vez: la página visible es la
## que avanza y suena. Por debajo de COMPACT_W de ancho (teléfono) cada página pasa a una sola columna.
## Sin ventana (tests): build() construye la interfaz y tick(delta) hace lo de _process; las escenas 3D y el sonido
## solo se crean dentro del árbol.
extends Control

const WorkshopState = preload("res://core/taller/workshop_state.gd")
const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const Style = preload("res://app/taller/ui/style.gd")
const AppInfo = preload("res://core/shared/app_info.gd")
const LathePage = preload("res://app/taller/ui/lathe_page.gd")
const MillPage = preload("res://app/taller/ui/mill_page.gd")
const DrillPage = preload("res://app/taller/ui/drill_page.gd")
const RadialPage = preload("res://app/taller/ui/radial_page.gd")
const SharpenerPage = preload("res://app/taller/ui/sharpener_page.gd")
const CalcPage = preload("res://app/taller/ui/calc_page.gd")
const MachineSoundPlayer = preload("res://app/taller/machine_sound_player.gd")

const COMPACT_W := 820.0
const TABS := [
	["torno", "Torno"], ["fresadora", "Fresadora"], ["taladro", "Taladro"], ["radial", "Radial"], ["afiladora", "Afiladora"],
	["calculadoras", "Calculadoras"],
]
const NOTICE := "Valores orientativos: modelos con fuentes; sin medición publicada, estimación (docs/taller). Educativo: no es un procedimiento de taller ni de rescate."

var state: WorkshopState
## Estado de la fresadora y del taladro.
var md: MillDrillState
## Páginas de las máquinas de WorkshopState (torno, radial, afiladora y calculadoras).
var pages := {}
## Páginas de las máquinas de MillDrillState (fresadora y taladro).
var md_pages := {}
var tab_chips := {}
var compact := false
var sound: Node3D = null  ## MachineSoundPlayer (solo dentro del árbol)
var _built := false
var _page := ""


func _ready() -> void:
	build()
	if not resized.is_connected(_update_layout):
		resized.connect(_update_layout)
	_update_layout()
	_ensure_sound()
	_show_page(state.machine, true)  # ya dentro del árbol: la página crea su escena 3D


## Construye la sección (una sola vez); se puede llamar sin ventana.
func build() -> void:
	if _built:
		return
	_built = true
	theme = Style.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state = WorkshopState.new()
	state.changed.connect(_on_state_changed)
	# Sin fondo propio: dentro del programa se ve el de app/main.gd, como en el laboratorio (la demo pone el suyo)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	# El titular y el botón de sonido son de la barra superior del programa (app/main.gd: headline() y el bus Master)
	var tabs := HFlowContainer.new()
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Style.button(t[1], "TallerPestana", true)
		b.button_group = group
		b.pressed.connect(select_machine.bind(t[0]))
		tabs.add_child(b)
		tab_chips[t[0]] = b
	col.add_child(tabs)
	# petición 40: el taller está en desarrollo (WIP)
	var wip := Style.label(AppInfo.WIP_NOTE, "TallerNota", true)
	wip.name = "AvisoWIP"
	wip.add_theme_color_override("font_color", Style.c("gold"))
	col.add_child(wip)
	var notice := Style.label(NOTICE, "TallerNota", true)
	notice.name = "AvisoOrientativo"
	col.add_child(notice)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	pages["torno"] = LathePage.new()
	pages["radial"] = RadialPage.new()
	pages["afiladora"] = SharpenerPage.new()
	pages["calculadoras"] = CalcPage.new()
	for id in pages:
		var p: Control = pages[id]
		p.call("build", state)
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(p)
	md = MillDrillState.new()
	md.changed.connect(_on_md_changed)
	md_pages["fresadora"] = MillPage.new()
	md_pages["taladro"] = DrillPage.new()
	for id in md_pages:
		var p: Control = md_pages[id]
		p.call("build", md)
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(p)
	_show_page(state.machine)


## Titular de la barra superior del programa (app/main.gd).
func headline() -> String:
	return "¿Cómo se corta el metal?"


## Fundamentos del taller para el botón «Fundamentos» de app/main.gd: [[título, texto]].
func fundamentos() -> Array:
	return WorkshopState.FUNDAMENTOS + MillDrillState.FUNDAMENTOS


func fundamentos_note() -> String:
	return WorkshopState.FUNDAMENTOS_NOTE


## Cambia de máquina (las pestañas llaman aquí). La fresadora y el taladro no son de WorkshopState: al pasar a ellas, el
## torno se para (una máquina a la vez, como al cambiar de máquina en WorkshopState).
func select_machine(id: String) -> void:
	if md_pages.has(id):
		state.pause()
		_show_page(id)
		return
	state.set_machine(id)
	_show_page(state.machine)


## La página de una máquina (de cualquiera de los dos estados).
func page(id: String) -> Control:
	return pages.get(id, md_pages.get(id))


## Máquina visible («torno», «fresadora»…).
func current_page() -> String:
	return _page


func _show_page(id: String, force: bool = false) -> void:
	Style.pick_chip(tab_chips, id)
	if id == _page and not force:
		return
	_page = id
	for group in [pages, md_pages]:
		for k in group:
			var p: Control = group[k]
			var on: bool = k == id
			p.visible = on
			# la página escondida no procesa: su escena 3D se para (las chispas de la radial, el plato del torno…)
			p.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	var cur: Control = page(id)
	cur.call("on_shown")
	cur.call("refresh")


func _on_state_changed() -> void:
	if md_pages.has(_page):
		return  # se ve la fresadora o el taladro: el estado del taller no cambia de página
	if state.machine != _page:
		_show_page(state.machine)
	else:
		pages[_page].call("refresh")


func _on_md_changed() -> void:
	if md_pages.has(_page):
		md_pages[_page].call("refresh")


## Una columna por debajo de COMPACT_W (teléfono), dos por encima.
func set_compact(on: bool) -> void:
	compact = on
	for group in [pages, md_pages]:
		for k in group:
			group[k].call("set_compact", on)


func _update_layout() -> void:
	var on := size.x > 0.0 and size.x < COMPACT_W
	if on != compact:
		set_compact(on)


func _process(delta: float) -> void:
	tick(delta)


## Un fotograma: la máquina visible avanza (el torno, la pasada de la fresa o el ciclo del taladro), llegan los barridos
## que hayan terminado en sus hilos, la página se actualiza y el sonido sigue a la máquina.
func tick(delta: float) -> void:
	if state == null:
		return
	match _page:
		"torno":
			state.advance(delta)
		"fresadora":
			md.advance("mill", delta)
		"taladro":
			md.advance("drill", delta)
	md.poll()
	page(_page).call("tick", delta)
	_update_sound()


func _ensure_sound() -> void:
	if sound != null or not is_inside_tree():
		return
	sound = MachineSoundPlayer.new()
	sound.name = "Sonido"
	sound.set("use_3d", false)  # sin cámara en la raíz: voces no posicionales y paneo desde tool_pos.x
	add_child(sound)


func _update_sound() -> void:
	if sound == null:
		return
	match _page:
		"torno":
			sound.set("chuck_position", state.lathe_chuck_pos_m())
			sound.call("set_input", state.lathe_sound_input())
		"fresadora":
			sound.call("set_input", md.mill_sound_input())
		"taladro":
			sound.call("set_input", md.drill_sound_input())
		"radial":
			# la entrada de la página: la de la mano en el modo manual (apagada, en silencio) o la del estado en la demostración
			sound.call("set_input", pages["radial"].call("sound_input"))
		"afiladora":
			# la entrada del simulador de afilado: la muela suena cuando hay un programa en marcha, y corta al tocar
			sound.call("set_input", pages["afiladora"].call("sound_input"))
		_:
			sound.call("stop_all")
