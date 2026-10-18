## Demo de la reacción del animal y de la lente de la cámara (unidad 5t-B) para las capturas y los vídeos: la escena 3D de
## la cetrería a pantalla completa con el animal sin sujetar, el aviso de amenaza y el zarpazo contra la cámara, con la
## lente que se raya, se raja o se mancha según la garra y la lente. Las reacciones las da la fuente de DEMOSTRACIÓN
## (reaction/reaction_demo.gd: cuándo salta, a mano), pero lo que le pasa a la lente es el motor de verdad
## (ClawCareReaction.lens_hit y ClawCareLens, core).
## Casos (-- --caso=K):
##   1 · la rapaz (águila) con queratina contra la lente de plástico: rayones finos; después, con una garra de acero
##   2 · la rapaz nocturna (búho real): el chasquido del pico, las alas como una capa; queratina y luego zafiro
##   3 · el tigre: las uñas que salen; queratina y luego carburo de tungsteno contra el vidrio
##   4 · el oso pardo: se levanta y barre de lado; queratina y luego diamante
##   5 · el velocirraptor de cine (ficción): la hoz; queratina y luego zafiro contra el vidrio templado
##   6 · la hoja de contacto: el mismo zarpazo de águila con queratina, oro, acero, zafiro y diamante contra las tres lentes
##       duras y el plástico (un fotograma tras cada impacto)
##   7 · la lente se acumula: tres zarpazos seguidos de tigre en plástico, la mancha limpiada con el paño y la lente que casi
##       no deja ver
##   8 · la pausa para calmarlo (el águila): la postura tranquila, la penumbra y la respiración más lenta, y su final
##   9 · la presentación (~13 s): la amenaza y el zarpazo del tigre, el del águila con garra de acero sobre la misma lente,
##       el paño y la pausa para calmarlo
## Captura: node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_reaccion.tscn --frames=420 --out=<carpeta> -- --caso=1
## El tiempo es la suma de los delta (Movie Maker los da fijos) y no hay hilos: cada captura sale igual. Al final escribe el
## coste por fotograma de la escena y de la reacción.
extends Node

const SCENE := "res://app/lab/cetreria/care_3d.tscn"
const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const ReactionDemo = preload("res://app/lab/cetreria/reaction/reaction_demo.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

const CASES := {
	1: { "animal": "rapaz", "claw": "aguila", "title": "Águila sin sujetar: el zarpazo contra la lente de plástico", "shots": [["none", "plastico"], ["acero", "plastico"]] },
	2: { "animal": "rapaz", "claw": "buho", "title": "Búho real: el chasquido del pico y las alas como una capa", "shots": [["none", "plastico"], ["zafiro", "plastico"]] },
	3: { "animal": "tigre", "claw": "tigre", "title": "Tigre mal anestesiado: las uñas que salen de la vaina", "shots": [["none", "plastico"], ["tungsteno", "vidrio"]] },
	4: { "animal": "oso", "claw": "oso", "title": "Oso pardo: se levanta un poco y barre de lado", "shots": [["none", "plastico"], ["diamante", "vidrio"]] },
	5: { "animal": "velociraptor", "claw": "velociraptor", "model": "pelicula", "title": "Velocirraptor de cine (ficción): la hoz por delante", "shots": [["none", "plastico"], ["zafiro", "vidrio_templado"]] },
	7: { "animal": "tigre", "claw": "tigre", "title": "La lente se acumula: tres zarpazos en plástico y el paño", "shots": [["none", "plastico"], ["acero", "plastico"], ["none", "plastico"]], "clean": true },
	8: { "animal": "rapaz", "claw": "aguila", "title": "Pausa para calmarlo", "shots": [] },
	9: { "animal": "tigre", "claw": "tigre", "title": "Tigre mal anestesiado: la amenaza y el zarpazo", "shots": [] },
}
## La hoja de contacto (caso 6): materiales y lentes.
const SHEET_MATS := ["none", "oro", "acero", "zafiro", "diamante"]
const SHEET_LENSES := ["plastico", "vidrio", "vidrio_templado", "zafiro"]
## Lo que dura cada parte de un disparo (s): reposo, aviso (el de 2 s del motor) y el plano entero.
const IDLE_S := 0.5
const WARN_S := 2.0
const SHOT_S := 3.6

var scene: Node3D
var runner: Runner
var demo := ReactionDemo.new()
var caption: Label
var _case := 1
## Sin el aviso (para probar deprisa): -- --sin-aviso
var _no_warn := false
## La pausa para calmarlo del caso 8: −1 la del estado, 0 sin pausa, 1 en pausa.
var _rest := -1
## El animal de ahora en la presentación (caso 9; vacío: el del caso).
var _animal := ""
var _claw := ""
var _t := 0.0
var _steps: Array = []
var _step := 0
var _cur_ev: Dictionary = {}
var _frames := 0
var _sum_us := 0
var _max_us := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_case = int(a.substr(7))
		if a == "--sin-aviso":
			_no_warn = true
	var c: Dictionary = CASES.get(_case, CASES[1]) if _case != 6 else { "animal": "rapaz", "claw": "aguila", "title": "Hoja de contacto: el zarpazo del águila según la garra y la lente" }
	runner = Runner.new({ "animal": String(c.animal), "claw": String(c.claw), "seed": "demo-reaccion" })
	runner.post("set_sedation", ["libre"])
	if c.has("model"):
		runner.post("set_model", [String(c.model)])
	runner.post("tick", [1.0 / 30.0])
	scene = (load(SCENE) as PackedScene).instantiate()
	scene.set("auto_process", false)
	add_child(scene)
	scene.call("show_view", runner.latest())
	scene.call("set_view", "animal", true)
	var r: Node = scene.call("reaction")
	r.set("external_lens", true)
	r.connect("lens_record", _on_record)
	scene.connect("reaction_sfx", _on_sfx)
	_build_caption(String(c.title))
	_plan(c)


func _build_caption(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	# arriba, a lo ancho, sobre un fondo oscuro: dos líneas cortas como mucho (el título y lo que ha pasado)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.08, 0.72)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12.0
	panel.offset_right = -12.0
	panel.offset_top = 10.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	caption = Label.new()
	caption.add_theme_font_override("font", FONT)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = text
	panel.add_child(caption)


## Los pasos del caso: [instante, qué, args].
func _plan(c: Dictionary) -> void:
	var t := IDLE_S
	if _case == 9:
		# la presentación (~13 s): la amenaza del tigre, su zarpazo, el del águila sobre la misma lente, el paño y la pausa
		_steps.append([0.2, "warn", [true]])
		_steps.append([1.4, "shot", ["none", "plastico", true]])
		_steps.append([4.4, "animal", ["rapaz", "aguila"]])
		_steps.append([4.6, "warn", [true]])
		_steps.append([5.6, "shot", ["acero", "plastico", true]])
		_steps.append([8.6, "clean", []])
		_steps.append([10.0, "rest", [true, "«Pausa para calmarlo»: en penumbra, los ojos entornados y la respiración más lenta; mientras descansa no se revuelve"]])
		_steps.append([13.2, "end", []])
		return
	if _case == 8:
		_steps.append([t, "rest", [true, "Pausa para calmarlo: los ojos entornados, la luz más baja y la respiración más lenta"]])
		t += 4.0
		_steps.append([t, "rest", [false, "Se acaba la pausa: vuelve a su postura de siempre"]])
		t += 2.0
		_steps.append([t, "end", []])
		return
	if _case == 6:
		for ln: String in SHEET_LENSES:
			for m: String in SHEET_MATS:
				_steps.append([t, "shot", [m, ln, false]])
				t += SHOT_S - 0.6
		_steps.append([t, "end", []])
		return
	for shot: Array in c.shots:
		if not _no_warn:
			_steps.append([t, "warn", [true]])
			t += WARN_S
		_steps.append([t, "shot", [String(shot[0]), String(shot[1]), true]])
		t += SHOT_S
	if bool(c.get("clean", false)):
		_steps.append([t, "clean", []])
		t += 1.4
	_steps.append([t, "end", []])


func _process(delta: float) -> void:
	_t += delta
	while _step < _steps.size() and _t >= float(_steps[_step][0]):
		_do(_steps[_step])
		_step += 1
	runner.post("tick", [delta])
	scene.call("show_view", _view())
	var t0 := Time.get_ticks_usec()
	scene.call("advance", delta)
	var us := Time.get_ticks_usec() - t0
	_frames += 1
	_sum_us += us
	_max_us = maxi(_max_us, us)


## La vista del estado; en el caso 8, con la pausa para calmarlo puesta a mano (view().animal.resting de la 5t-A) y un
## serial que cambia con ella, para que la escena la vea.
func _view() -> Dictionary:
	var v: Dictionary = runner.latest()
	if _rest < 0:
		return v
	v = v.duplicate(true)
	(v.animal as Dictionary)["resting"] = _rest == 1
	v["serial"] = int(v.serial) + 1000000 * _rest
	return v


func _do(st: Array) -> void:
	var r: Node = scene.call("reaction")
	var c: Dictionary = CASES.get(_case, {})
	var animal := String(c.get("animal", "rapaz")) if _animal == "" else _animal
	var claw := String(c.get("claw", "aguila")) if _claw == "" else _claw
	match String(st[1]):
		"animal":
			# otro animal en la misma mesa y con la misma lente (la presentación)
			_animal = String(st[2][0])
			_claw = String(st[2][1])
			runner = Runner.new({ "animal": _animal, "claw": _claw, "seed": "demo-reaccion" })
			runner.post("set_sedation", ["libre"])
			runner.post("tick", [1.0 / 30.0])
			scene.call("show_view", _view())
			scene.call("set_view", "animal", true)
			caption.text = "%s sin sujetar" % ("Águila" if _claw == "aguila" else _claw.capitalize())
		"warn":
			scene.call("set_view", "animal", true)
			r.call("trigger_event", demo.warning(animal, claw, true))
		"shot":
			var a: Array = st[2]
			var mat := String(a[0])
			var ln := String(a[1])
			# en la hoja de contacto, cada disparo con una lente nueva (para ver lo de cada garra)
			if ln != demo.lens.lens_id or _case == 6:
				demo.mount(ln)
				(r.get("lens") as Node).call("set_lens", ln, {})
			runner.post("set_inlay", [mat])
			runner.post("set_sedation", ["libre"])
			runner.post("tick", [1.0 / 30.0])
			scene.call("show_view", runner.latest())
			_cur_ev = demo.event(animal if _case != 6 else "rapaz", claw if _case != 6 else "aguila", mat, 0.9)
			r.call("trigger_event", demo.warning(animal, claw, false))
			r.call("play", _cur_ev)
			var hit: Dictionary = _cur_ev.lens
			# dos líneas cortas: quién y con qué; y lo que le pasa a la lente (el peor resultado del motor, y cuántas rayan)
			caption.text = "%s · garra de %s\n%s: %s · %d de %d garras rayan" % [(String(c.get("title", "Hoja de contacto")).get_slice(":", 0) if _animal == "" else "Águila sin sujetar"),
				_mat_name(mat), String(hit.lensName).get_slice(" (", 0), String(ReactionDemo.Reaction.OUTCOME_NAMES.get(String(hit.outcome), "")),
				int(hit.scratches), (hit.claws as Array).size()]
		"rest":
			_rest = 1 if bool(st[2][0]) else 0
			caption.text = String(st[2][1])
		"clean":
			demo.lens.clean()
			(r.get("lens") as Node).call("clean")
			caption.text = "«Limpiar la lente»: el paño quita las manchas; los rayones se quedan (una lente rayada se cambia en la tienda)"
		"end":
			var info: Dictionary = r.call("info")
			print("DEMO-REACCION caso %d · %d fotogramas · escena %s ms de media (máx. %s ms) · lente %s" % [_case, _frames,
				str(float(_sum_us) / float(maxi(_frames, 1)) / 1000.0), str(float(_max_us) / 1000.0), str(info.lens)])


static func _mat_name(mat: String) -> String:
	return "queratina" if mat == "none" else mat


func _on_sfx(id: String, volume: float, pitch: float) -> void:
	var path := "res://assets/sfx/lab/%s.wav" % id
	if not ResourceLoader.exists(path):
		return
	# varios a la vez (la voz y el impacto): un reproductor por efecto
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = linear_to_db(clampf(volume, 0.01, 1.0) * Sfx.gain(id))  # con el ajuste de la mezcla
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _on_record(seq: int, traces: Dictionary) -> void:
	if int(_cur_ev.get("seq", -1)) != seq:
		return
	demo.record(_cur_ev, traces)
	var r: Node = scene.call("reaction")
	(r.get("lens") as Node).call("apply_damage", demo.lens.view())
