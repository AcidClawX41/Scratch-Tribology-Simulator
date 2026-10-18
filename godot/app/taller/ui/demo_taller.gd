## Taller industrial · demo guionizada de la sección, para las capturas con Movie Maker:
##   1 · torno: pieza A a ×5 (se oye y se ve cortar), a ×50 hasta el final, informe de inspección y capa de
##       desviación;
##   2 · radial: disco fino y disco grueso en acero dulce, y el pilar B de acero al boro (sin pintura) en el canto;
##   3 · afiladora: cuchillo en el Tormek y broca en la esmeriladora;
##   4 · calculadoras: torneado y fresado.
## Captura (desde la raíz del repositorio):
##   npm run godot:capture -- res://app/taller/ui/demo_taller.tscn --frames=480 --out=<carpeta> -- --log=<ruta.json>
## Teléfono:  … -- --ancho=390 --alto=844 (la sección va en un SubViewport de ese tamaño, centrado, con el guion al
##            lado: Movie Maker graba siempre al tamaño del proyecto, 1240 × 880; lo mismo hace la demo del laboratorio).
## Una parte: … -- --parte=torno|radial|afiladora|calculadoras, o --parte=manual (el torno paralelo cilindrando con
##            el avance automático; no va en la demo completa)
## El tiempo es la suma de los delta (Movie Maker los da fijos). Al salir escribe en la consola el coste por
## fotograma (tiempo real entre fotogramas y tiempo de proceso) y, con --log, un registro por fotograma para
## analizar el sonido.
extends Control

const SECTION := preload("res://app/taller/taller_section.tscn")
const WorkshopState = preload("res://core/taller/workshop_state.gd")
const Style = preload("res://app/taller/ui/style.gd")

const CAPTIONS := {
	"torno": "Torno CNC · pieza A (Fagor 8055 T) a ×5 y a ×50 hasta el informe",
	"radial": "Radial contra chapa · disco fino, disco grueso y pilar B de acero al boro",
	"afiladora": "Afiladora · cuchillo en el Tormek y broca en la esmeriladora",
	"calculadoras": "Calculadoras · torneado y fresado",
	"manual": "Torno paralelo · cilindrado con el avance automático",
}

var section: Control
var state: WorkshopState
var part := "todo"
var log_path := ""
var phone := false
var phone_size := Vector2i(390, 844)
var caption: Label
var _step := 0
var _t := 0.0  # s de la parte actual
var _frames: Array = []
var _proc_us: Array[int] = []
var _wall_us: Array[int] = []
var _last_us := 0
var _queue: Array = []  # partes que quedan
var _report_at := -1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parte="):
			part = a.substr(8)
		elif a.begins_with("--log="):
			log_path = a.substr(6)
		elif a.begins_with("--ancho="):
			phone = true
			phone_size.x = int(a.substr(8))
		elif a.begins_with("--alto="):
			phone = true
			phone_size.y = int(a.substr(7))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	section = SECTION.instantiate()
	if phone:
		_build_phone()
	else:
		var bg := ColorRect.new()
		bg.color = Style.c("bg")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		add_child(section)
	state = section.get("state")
	_queue = ["torno", "radial", "afiladora", "calculadoras"] if part == "todo" else [part]
	_start(_queue.pop_front())


## Teléfono: la sección en un SubViewport del tamaño pedido, centrado, y el guion a la izquierda.
func _build_phone() -> void:
	var bg := ColorRect.new()
	bg.color = Style.c("bg2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(phone_size)
	box.size = Vector2(phone_size)
	box.position = Vector2(floorf((1240.0 - phone_size.x) / 2.0), floorf((880.0 - phone_size.y) / 2.0))
	add_child(box)
	var vp := SubViewport.new()
	vp.size = phone_size
	box.add_child(vp)
	var pbg := ColorRect.new()
	pbg.color = Style.c("bg")
	pbg.size = Vector2(phone_size)
	vp.add_child(pbg)
	vp.add_child(section)
	caption = Style.label("", "TallerTitulo", true)
	caption.theme = Style.theme()
	caption.position = Vector2(24, 60)
	caption.size = Vector2(box.position.x - 48.0, 300)
	caption.custom_minimum_size.x = box.position.x - 48.0
	add_child(caption)


func _start(p: String) -> void:
	part = p
	_step = 0
	_t = 0.0
	section.call("select_machine", "torno" if p == "manual" else p)
	if caption != null:
		caption.text = CAPTIONS.get(p, "")


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_wall_us.append(now - _last_us)
		# tiempo de proceso del fotograma anterior: todos los _process (la sección, el torno y las escenas 3D)
		_proc_us.append(int(Performance.get_monitor(Performance.TIME_PROCESS) * 1e6))
	_last_us = now
	_t += delta
	match part:
		"torno":
			_torno()
		"manual":
			_manual()
		"radial":
			_radial()
		"afiladora":
			_afiladora()
		"calculadoras":
			_calculadoras()
	var st: Dictionary = state.lathe_state()
	_frames.append({
		"frame": _frames.size(), "machine": state.machine, "lathe_t": st["t_s"],
		"cutting": bool(st["cutting"]) and state.is_running() and state.machine == "torno",
		"rpm": (st["spindle"] as Dictionary)["rpm"], "pc_kw": st["pc_kw"], "report": state.report != null,
	})


func _next_part() -> void:
	if _queue.is_empty():
		part = "fin"
		return
	_start(_queue.pop_front())


## En teléfono, la tarjeta que interesa a la vista (la columna es una sola y larga).
func _reveal(page_id: String, card_name: String) -> void:
	if not phone:
		return
	var page: Control = section.call("page", page_id)
	var card: Control = page.get(card_name)
	(page.get("pane") as Control).call("reveal", card)


func _torno() -> void:
	var lp: Control = section.call("page", "torno")
	match _step:
		0:
			state.set_program("pieza_a")
			state.set_speed(5.0)
			lp.call("set_view", "frontal")
			state.play()
			_step = 1
		1:
			if _t >= 1.4:
				lp.call("set_view", "detalle")
				_step = 2
		2:
			if _t >= 3.2:
				lp.call("set_view", "frontal")
				state.set_speed(50.0)
				_step = 3
		3:
			if state.report != null:
				_report_at = _t
				_step = 4
		4:
			if _t >= _report_at + 2.2:
				_next_part()


## Solo con --parte=manual: el torno paralelo cilindrando con el avance automático.
func _manual() -> void:
	var lp: Control = section.call("page", "torno")
	match _step:
		0:
			state.set_lathe_mode("manual")
			state.set_manual_rpm(745.0)
			state.manual_spindle("cw")
			state.set_speed(2.0)
			# preparación de la escena: la punta junto a la cara del bruto, 1 mm por debajo de su radio
			var st: Dictionary = state.stock()
			state.lathe.place_tool(float(st["d"]) / 2.0 - 1.0, float(st["face_z"]) + 1.0)
			lp.call("set_view", "detalle")
			_step = 1
		1:
			if _t >= 0.5:
				state.set_manual_feed(0.2)
				state.manual_auto_feed("z", -1.0)
				_reveal("torno", "manual_card")
				_step = 2
		2:
			if _t >= 2.5:
				state.manual_feed_stop()
				_next_part()


func _radial() -> void:
	var rp: Control = section.call("page", "radial")
	match _step:
		0:
			# la radial abre apagada y en manos del usuario: el guion enseña su corte automático («Ver demostración»)
			rp.call("set_demo", true)
			state.set_radial("panel_id", "acero-dulce")
			state.set_radial("disc_id", "fino_1mm")
			state.set_radial("rpm", 11000.0)
			rp.call("set_view", "detalle")
			_step = 1
		1:
			if _t >= 1.0:
				_reveal("radial", "result_card")
				_step = 2
		2:
			if _t >= 1.9:
				state.set_radial("disc_id", "grueso_3mm")
				_step = 3
		3:
			if _t >= 3.8:
				state.set_radial("disc_id", "fino_1mm")
				state.set_radial("panel_id", "boro-22mnb5")
				rp.call("set_view", "canto")
				_step = 4
		4:
			if _t >= 5.4:
				rp.call("set_view", "detalle")
				rp.call("set_demo", false)
				_next_part()


func _afiladora() -> void:
	match _step:
		0:
			state.set_sharpen("kind", "cuchillo")
			_step = 1
		1:
			if _t >= 0.6:
				_reveal("afiladora", "result_card")
				_step = 2
		2:
			if _t >= 1.1:
				state.set_sharpen("kind", "broca")
				_step = 3
		3:
			if _t >= 2.2:
				_next_part()


func _calculadoras() -> void:
	match _step:
		0:
			state.set_calc_kind("torneado")
			_step = 1
		1:
			if _t >= 1.1:
				state.set_calc_kind("fresado")
				_step = 2
		2:
			if _t >= 2.2:
				_next_part()


func _exit_tree() -> void:
	if not _wall_us.is_empty():
		var w := _wall_us.duplicate()
		w.sort()
		var p := _proc_us.duplicate()
		p.sort()
		var mean := 0.0
		for x in w:
			mean += x
		mean /= w.size()
		print("Demo del taller: %d fotogramas · tiempo real entre fotogramas: mediana %d ms, media %d ms, p95 %d ms · tiempo de proceso: mediana %d ms, p95 %d ms" % [
			w.size(), w[w.size() / 2] / 1000, int(mean) / 1000, w[int(w.size() * 0.95)] / 1000,
			p[p.size() / 2] / 1000, p[int(p.size() * 0.95)] / 1000])
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_frames))
			f.close()
