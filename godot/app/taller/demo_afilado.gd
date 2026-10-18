## Taller industrial · demo guionizada del simulador de afilado (app/taller/ui/sharpener_page.gd), para las capturas
## con Movie Maker:
##   1 · seco:   cuchillo de cocina en la Einhell TC-BG 150, en seco, despacio y apretando: se quema (> 723 °C);
##   2 · humedo: el mismo cuchillo, hoja nueva, en la Einhell TC-WG 200 (lenta y en agua): no pasa de 130 °C;
##   3 · broca:  broca de 8 mm de M2 en la MRCM MR-13A, con su muela de CBN;
##   4 · hacha:  hacha con la amoladora Einhell TE-AG 125 CE y disco de láminas, en la posición más lenta.
## Captura (desde la raíz del repositorio):
##   node godot/tools/godot.mjs capture res://app/taller/demo_afilado.tscn --frames=900 --out=<carpeta>
##   Teléfono: … --phone (lienzo de 390 × 844: la página va en una columna). Una parte: … -- --parte=seco|humedo|broca|hacha
## La demo pulsa las fichas de la página y le manda órdenes como lo haría el usuario; el simulador va en su hilo (la
## página lo arranca al entrar en el árbol) y el sonido sale de page.sound_input() por un MachineSoundPlayer sin 3D.
## Al salir escribe en la consola el coste por fotograma: el trabajo del simulador en su hilo y el tiempo de proceso
## del hilo principal.
extends Control

const Page = preload("res://app/taller/ui/sharpener_page.gd")
const WorkshopState = preload("res://core/taller/workshop_state.gd")
const MachineSoundPlayer = preload("res://app/taller/machine_sound_player.gd")
const Style = preload("res://app/taller/ui/style.gd")

const PARTS := ["seco", "humedo", "broca", "hacha"]
const CAPTIONS := {
	"seco": "1 · Cuchillo de cocina en la Einhell TC-BG 150, en seco, despacio y apretando: se quema",
	"humedo": "2 · El mismo cuchillo, hoja nueva, en la Einhell TC-WG 200: lenta y en agua, no pasa de 130 °C",
	"broca": "3 · Broca de 8 mm en la MRCM MR-13A con muela de CBN",
	"hacha": "4 · Hacha con amoladora y disco de láminas, en la posición más lenta (3.000 rpm)",
}
## Por debajo de este ancho, la página en una columna (el de la sección del taller).
const COMPACT_W := 820.0

var page: Control
var sound: Node
var caption: Label
var phone := false
var part := ""
var _queue: Array = []
var _step := 0
var _t := 0.0  # s de la parte actual
var _end_t := -1.0
var _seen_running := false
var _work_ms: Array[float] = []
var _proc_us: Array[int] = []


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parte="):
			only = a.substr(8)
	theme = Style.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Style.c("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	caption = Style.label("", "TallerTitulo", true)
	col.add_child(caption)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	page = Page.new()
	page.call("build", WorkshopState.new())
	holder.add_child(page)
	phone = get_viewport_rect().size.x < COMPACT_W
	page.call("set_compact", phone)
	page.call("on_shown")
	sound = MachineSoundPlayer.new()
	sound.set("use_3d", false)  # vista 2D, sin Camera3D
	add_child(sound)
	_queue = PARTS.duplicate() if only == "" else [only]
	_start(str(_queue.pop_front()))


func _start(p: String) -> void:
	part = p
	_step = 0
	_t = 0.0
	_end_t = -1.0
	_seen_running = false
	caption.text = str(CAPTIONS.get(p, ""))


func _next() -> void:
	if _queue.is_empty():
		part = "fin"
		sound.call("stop_all")
		return
	_start(str(_queue.pop_front()))


func _process(delta: float) -> void:
	_t += delta
	match part:
		"seco":
			_run_part("cuchillo", "einhell_tc_bg_150", { "hand": { "force_n": 20.0, "sweep_mm_s": 8.0, "passes": 2, "rest_s": 0.0 } }, 2.0, 2.0, 10.0)
		"humedo":
			_run_part("cuchillo", "einhell_tc_wg_200", { "hand": { "passes": 3 } }, 2.0, 1.5, 10.0)
		"broca":
			_run_part("broca", "mrcm_mr_13a", {}, 2.0, 1.5, 5.0)
		"hacha":
			_run_part("hacha", "einhell_te_ag_125_ce", { "wheel": "laminas", "rpm": 3000.0, "hand": { "passes": 8, "rest_s": 3.0 } }, 2.0, 1.5, 10.0)
	page.call("tick", delta)
	sound.call("set_input", page.call("sound_input"))
	var runner: RefCounted = page.get("runner")
	_work_ms.append(float(runner.call("work_ms")))
	_proc_us.append(int(Performance.get_monitor(Performance.TIME_PROCESS) * 1e6))


## Una parte: elige herramienta y máquina con las fichas, ajusta el resto, hoja nueva y «Afilar» a ×slow; a los
## fast_at s pasa a ×fast; al acabar el programa enseña el informe y, 2,2 s después, sigue con la siguiente.
func _run_part(kind: String, machine_id: String, extra: Dictionary, slow: float, fast_at: float, fast: float) -> void:
	match _step:
		0:
			((page.get("kind_chips") as Dictionary)[kind] as Button).pressed.emit()
			((page.get("machine_chips") as Dictionary)[machine_id] as Button).pressed.emit()
			if not extra.is_empty():
				page.call("apply", extra)
			page.call("reset_blade")
			page.call("set_speed", slow)
			page.call("start_program")
			_reveal("view")
			_step = 1
		1:
			_watch()
			if _t >= fast_at:
				page.call("set_speed", fast)
				_step = 2
		2:
			_watch()
			var s: Dictionary = page.call("latest")
			if _seen_running and bool(s.get("finished", false)) and not bool(s.get("running", false)):
				_end_t = _t
				_reveal("report_card")
				_step = 3
		3:
			if _t >= _end_t + 2.2:
				_next()


## Con hilo, la instantánea que dice «en marcha» llega un fotograma después de la orden.
func _watch() -> void:
	if bool((page.call("latest") as Dictionary).get("running", false)):
		_seen_running = true


## Desplaza la columna de la página hasta un control (la vista al empezar, el informe al acabar).
func _reveal(member: String) -> void:
	var c: Variant = page.get(member)
	if c is Control:
		(page.get("pane") as Control).call("reveal", c)


func _exit_tree() -> void:
	if sound != null:
		sound.call("stop_now")
	if _work_ms.is_empty():
		return
	var w := _work_ms.duplicate()
	w.sort()
	var p := _proc_us.duplicate()
	p.sort()
	print("Demo del afilado: %d fotogramas · simulador en su hilo: mediana %.2f ms, p95 %.2f ms por fotograma · proceso del hilo principal: mediana %.2f ms, p95 %.2f ms" % [
		w.size(), float(w[w.size() / 2]), float(w[int(w.size() * 0.95)]),
		float(p[p.size() / 2]) / 1000.0, float(p[int(p.size() * 0.95)]) / 1000.0])
