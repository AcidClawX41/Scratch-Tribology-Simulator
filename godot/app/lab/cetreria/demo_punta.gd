## Demo guionizada de la unidad 5s (petición 60 de Eric): el afilado que se ve y se entiende, y las garras de cada dedo. La
## página «Cetrería» de verdad, con los mismos gestos que manda la escena 3D (coger, apretar, arrastrar y soltar) y sus
## botones; el medidor y la lupa de la punta, sobre la vista.
##   1 · afilar después de recortar (el águila): la punta natural en la lupa; se remoja y se recorta (roma: el medidor y el
##       aviso «Para afilar…»); la lima gruesa a 22° hasta casi la banda, con las pasadas que faltan; la fina hasta la banda
##       («para aquí»); una pasada más y queda como una aguja (la lupa de cerca); probarla y se mella;
##   2 · la amoladora se pasa enseguida (solo con --caso=2): recortada, unos toques de una décima y ya es una aguja;
##   3 · las garras de cada dedo (solo con --caso=3): cada especie con la forma de su dedo (el I del águila, el mayor; el II, más
##       curvo) y las de las otras patas, de lejos y de cerca;
##   4 · el encuadre (solo con --caso=4): cada dedo de una pata en «La garra», de cada especie, y el animal entero;
##   5 · la faceta de cerca (solo con --caso=5): recortada, cuatro pasadas a 22° (las caras planas, de cerca) y hasta cerrar la cara;
##   6 · la punta al empezar (solo con --caso=6): el águila, el tigre y el oso con la punta roma, natural, afilada y de aguja.
## Captura: node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_punta.tscn --frames=1500 --out=<carpeta>
##          (con --phone, en el teléfono; un caso: -- --caso=2; un animal en los casos 3 y 4: --solo=oso). El estado va en el hilo de la interfaz: cada captura sale igual.
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Ui = preload("res://app/common/ui.gd")
const State = preload("res://core/lab/claw_care_state.gd")

const SCENES := [
	"Afilar después de recortar: el medidor, la lupa y las pasadas que faltan",
	"La amoladora se pasa enseguida: un toque y ya es una aguja",
	"Las garras de cada dedo y de cada pata: cada una con su forma",
	"El encuadre de cada dedo en «La garra» y el animal entero",
	"La faceta de cerca: las caras planas que deja la lima",
	"La punta al empezar: roma, natural, afilada y aguja",
]

## Desde dónde se ve la pata en la pose del dedo IV: [giro, altura (°), distancia (m)].
const TOE_VIEW := Vector3(320.0, 60.0, 0.24)

var lab: Control
var page: Control
var scene: Node3D
var caption: Label
## Un aro sobre la punta de la garra que se trabaja (para que se vea dónde mirar).
var mark: Panel
var _t := 0.0
var _only := -1
## Solo un animal en los casos 3 y 4 (--solo=oso).
var _solo := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
		elif a.begins_with("--solo="):
			_solo = a.substr(7)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	page = lab.care_page
	page.threaded = false
	lab.set_page(lab.PAGE_CARE, false)
	page.call("set_intro_seen", true)
	scene = page.scene
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Cetrería", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 60.0, 620.0)
	pill.add_child(caption)
	add_child(pill)
	pill.position = Vector2(14, 8) if vs.x < 600.0 else Vector2(vs.x - 660.0, 8)
	mark = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1.0, 0.85, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	mark.add_theme_stylebox_override("panel", sb)
	mark.size = Vector2(28, 28)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	_run()


func _process(delta: float) -> void:
	_t += delta
	if scene != null and page.runner != null:
		var p: Vector2 = scene.call("claw_screen_point", _apex(), 0.0, 0.0)
		mark.position = (page.view3d as Control).get_global_rect().position + p - mark.size * 0.5


func _run() -> void:
	await get_tree().process_frame
	var order: Array = [0] if _only < 0 else [_only]
	for i: int in order:
		await call("_scene_%d" % (i + 1))
	_say("Fin")
	page.call("set_active", false)


func _say(t: String) -> void:
	caption.text = t
	print("[punta %s s] %s" % [String.num(_t, 1), t])


func _st() -> State:
	return page.runner.state


func _post(op: String, args: Array = []) -> void:
	page.runner.post(op, args)


func _wait(secs: float) -> void:
	var end := _t + secs
	while _t < end:
		await get_tree().process_frame


func _apex() -> float:
	return _st().care.apex_mm()


func _meter() -> Dictionary:
	return (page.runner.latest().get("tip_help", {}) as Dictionary).get("meter", {})


## Una pasada de lima: aprieta a d mm de la punta y desliza mm milímetros hacia la punta en secs (los gestos de la escena).
func _stroke(d_from_tip: float, mm: float, secs: float) -> void:
	_post("press_on", [maxf(_apex() - d_from_tip, 0.0)])
	var steps := maxi(int(secs * 30.0), 1)
	for k in steps:
		_post("drag", [mm / float(steps), mm / float(steps), maxf(_apex() - d_from_tip, 0.0), 1.0 / 30.0])
		await get_tree().process_frame
	_post("release")
	await get_tree().process_frame


## Mantiene la herramienta apretada a d mm de la punta durante secs (el cortaúñas, el toque de una giratoria).
func _hold(d_from_tip: float, secs: float) -> void:
	_post("press_on", [maxf(_apex() - d_from_tip, 0.0)])
	await _wait(secs)
	_post("release")
	await get_tree().process_frame


## La cámara, de cerca sobre la punta (la rueda del ratón con el puntero sobre ella).
func _zoom_tip(times: int) -> void:
	for k in times:
		var p: Vector2 = scene.call("claw_screen_point", maxf(_apex() - 0.3, 0.0), 0.0, 0.0)
		var mm := InputEventMouseMotion.new()
		mm.position = p
		scene.call("handle_pointer", mm)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_WHEEL_UP
		mb.pressed = true
		mb.position = p
		scene.call("handle_pointer", mb)
		await _wait(0.12)


func _scene_1() -> void:
	_post("configure", [{ "animal": "rapaz", "claw": "aguila", "overgrowth_days": 90.0, "seed": "demo-punta" }])
	_post("set_sedation", ["sujecion"])
	page.call("set_view", "garra")
	_say("1 · La punta natural del águila: 113 µm de radio (la lupa, abajo a la izquierda)")
	await _wait(2.5)
	_say("1 · Se remoja y se recorta con el cortaúñas de guillotina: el corte deja la punta plana y roma")
	_post("set_humidity", ["humeda"])
	_post("pick", ["guillotina"])
	await _wait(0.6)
	await _hold(2.0, State.CLIP_CLOSE_S + 0.3)
	_post("set_humidity", ["natural"])
	await _wait(2.6)
	_say("1 · Roma: el medidor y el aviso «Para afilar…» (lima fina o de diamante fina, 20-25°)")
	await _wait(2.6)
	_post("pick", ["lima_bastarda"])
	_post("set_angle", [22.0])
	_post("set_force", [3.0])
	_say("1 · La lima gruesa a 22°: quita largo y da forma; el medidor cuenta las pasadas que faltan")
	await _wait(1.6)
	var n := 0
	while float(_st().care.tip_state().ratio) > 2.6 and n < 80:
		await _stroke(1.5, 10.0, 0.12)
		n += 1
	print("gruesa: %d pasadas, ×%s" % [n, String.num(float(_st().care.tip_state().ratio), 2)])
	await _wait(1.8)
	_post("pick", ["lima_fina"])
	_post("set_angle", [22.0])
	_say("1 · La lima fina: afila la punta, poco en cada pasada (mira la flecha y la lupa)")
	await _wait(1.6)
	n = 0
	while float(_st().care.tip_state().ratio) > 1.25 and n < 30 and float(_st().care.tip_state().flatMm) > 0.0:
		await _stroke(0.8, 10.0, 0.25)
		n += 1
		await _wait(0.5)
	print("fina: %d pasadas, ×%s · %s" % [n, String.num(float(_st().care.tip_state().ratio), 2), _meter().get("text", "")])
	_say("1 · En la banda buena: para aquí (el medidor avisa de que una pasada más la deja como una aguja)")
	await _wait(3.2)
	var extra := 0
	while float(_st().care.tip_state().flatMm) > 0.0 and extra < 6:
		await _stroke(0.8, 10.0, 0.25)
		extra += 1
	_say("1 · Una pasada de más: una aguja de 10 µm (el radio de los dientes de la lima)")
	await _wait(1.0)
	await _zoom_tip(3)
	await _wait(3.0)
	_say("1 · Probar la punta (T): no aguanta de lado y se mella")
	_post("probe_tip")
	await _wait(3.4)
	print("final: %s" % _meter().get("text", ""))


func _scene_2() -> void:
	_post("configure", [{ "animal": "rapaz", "claw": "aguila", "overgrowth_days": 90.0, "seed": "demo-amoladora" }])
	_post("set_sedation", ["sujecion"])
	_post("select_claw", ["derecha", "II"])
	page.call("set_view", "garra")
	_post("set_humidity", ["humeda"])
	_post("pick", ["guillotina"])
	await _wait(0.6)
	await _hold(2.0, State.CLIP_CLOSE_S + 0.3)
	_post("set_humidity", ["natural"])
	_say("2 · La amoladora a 45° y 8000 rpm sobre la punta recortada: el medidor dice décimas de segundo")
	_post("pick", ["amoladora"])
	_post("set_angle", [45.0])
	_post("set_rotary", [true])
	await _wait(2.6)
	var n := 0
	while float(_st().care.tip_state().flatMm) > 0.0 and n < 12:
		await _hold(0.8, 0.1)
		n += 1
	print("amoladora: %d toques, ×%s · %s" % [n, String.num(float(_st().care.tip_state().ratio), 3), _meter().get("text", "")])
	var touches := "Un toque" if n == 1 else "%d toques" % n
	_say("2 · %s de una décima: ya es una aguja de 5 µm, «facetada» a 45° (con la lima fina, decenas de pasadas)" % touches)
	await _wait(1.0)
	await _zoom_tip(3)
	await _wait(3.0)
	_post("set_rotary", [false])


func _scene_3() -> void:
	for a: Array in [["rapaz", "aguila", "sujecion"], ["rapaz", "buho", "sujecion"], ["oso", "oso", "anestesia"], ["tigre", "tigre", "anestesia"]]:
		if _solo != "" and String(a[1]) != _solo:
			continue
		_post("configure", [{ "animal": String(a[0]), "claw": String(a[1]), "overgrowth_days": 90.0, "seed": "demo-dedos" }])
		_post("set_sedation", [String(a[2])])
		page.call("set_view", "animal")
		_say("3 · %s: cada garra con la forma de su dedo (largo, arco y sección medidos)" % String(a[1]).capitalize())
		await _wait(2.4)
		page.call("set_view", "garra")
		await _wait(2.0)


func _scene_4() -> void:
	for a: Array in [["rapaz", "aguila", "sujecion"], ["rapaz", "buho", "sujecion"], ["oso", "oso", "anestesia"], ["tigre", "tigre", "anestesia"]]:
		if _solo != "" and String(a[1]) != _solo:
			continue
		_post("configure", [{ "animal": String(a[0]), "claw": String(a[1]), "overgrowth_days": 90.0, "seed": "demo-encuadre" }])
		_post("set_sedation", [String(a[2])])
		var slots: Array = page.runner.latest().get("slots", [])
		var first := String((slots[0] as Dictionary).paw) if not slots.is_empty() else ""
		for e: Dictionary in slots:
			if String(e.paw) != first:
				continue
			_post("select_claw", [String(e.paw), String(e.digit)])
			page.call("set_view", "garra")
			_say("4 · %s · %s" % [String(a[1]).capitalize(), String(e.get("label", e.key))])
			await _wait(1.6)
		if String(a[1]) == "aguila":
			# el dedo II, recortado: más corto, la cámara lo sigue igual de visible
			_post("select_claw", [first, "II"])
			page.call("set_view", "garra")
			_post("set_humidity", ["humeda"])
			_post("pick", ["guillotina"])
			await _wait(0.6)
			await _hold(4.5, State.CLIP_CLOSE_S + 0.3)
			_post("set_humidity", ["natural"])
			_post("pick", ["lima_fina"])
			page.call("set_view", "garra")
			_say("4 · Águila · dedo II recortado 4,5 mm, con la lima en la mano")
			await _wait(1.8)
		if String(a[1]) in ["buho", "lechuza"]:
			await _toe_pose(String(a[1]))
		page.call("set_view", "animal")
		_say("4 · %s entero: las garras, a su escala" % String(a[1]).capitalize())
		await _wait(1.8)


## Pasadas de lima sin esperar fotogramas (para llegar enseguida a lo que se quiere enseñar).
func _quick_strokes(d_from_tip: float, mm: float, n: int) -> void:
	for i in n:
		_post("press_on", [maxf(_apex() - d_from_tip, 0.0)])
		for k in 6:
			_post("drag", [mm / 6.0, mm / 6.0, maxf(_apex() - d_from_tip, 0.0), 1.0 / 30.0])
		_post("release")


func _scene_5() -> void:
	_post("configure", [{ "animal": "rapaz", "claw": "aguila", "overgrowth_days": 90.0, "seed": "demo-faceta" }])
	_post("set_sedation", ["sujecion"])
	page.call("set_view", "garra")
	_post("set_humidity", ["humeda"])
	_post("pick", ["guillotina"])
	await _wait(0.4)
	await _hold(2.0, State.CLIP_CLOSE_S + 0.3)
	_post("set_humidity", ["natural"])
	_post("pick", ["lima_bastarda"])
	_post("set_angle", [22.0])
	_quick_strokes(1.5, 10.0, 4)
	# sin la lima en la mano (que no tape la punta)
	_post("drop")
	_say("5 · Cuatro pasadas a 22° sobre la cara del corte: la faceta, con caras planas")
	await _wait(0.6)
	await _zoom_tip(20)
	await _wait(2.0)
	_post("pick", ["lima_bastarda"])
	var n := 0
	while float(_st().care.tip_state().flatMm) > 0.0 and n < 200:
		_quick_strokes(1.5, 10.0, 1)
		n += 1
	_post("drop")
	_say("5 · Limada hasta cerrar la cara (%d pasadas más): la punta, una aguja" % n)
	await _wait(2.0)


## El dedo IV de las nocturnas, girado hacia atrás y vuelto a su sitio (el pivote que usará el ataque de la calle B; pose de
## prueba): la pata vista desde arriba, con el dedo girando poco a poco.
func _toe_pose(art: String) -> void:
	page.call("set_view", "general")
	await _wait(0.4)
	var paw: Dictionary = scene.get("_paw")
	var tp: Dictionary = paw.get("toe_pivots", {})
	var rig: Node3D = scene.get("_rig")
	var c: Vector3 = scene.call("_paw_world")
	rig.call("set_orbit", c, TOE_VIEW.x, TOE_VIEW.y, TOE_VIEW.z, 30.0, true)
	_say("4 · %s · el dedo IV, el que se gira hacia atrás al agarrar (pose de prueba del pivote)" % art.capitalize())
	await _wait(1.0)
	for step: float in [0.25, 0.5, 0.75, 1.0, 1.0, 1.0, 1.0, 0.5, 0.0]:
		for k: String in tp:
			var e: Dictionary = tp[k]
			if not is_instance_valid(e.node):
				continue
			var b := Basis(e.axis as Vector3, deg_to_rad(float(e.back_deg) * step))
			(e.node as Node3D).transform = Transform3D(b, (e.point as Vector3) - b * (e.point as Vector3))
		await _wait(0.4)


func _scene_6() -> void:
	for a: Array in [["rapaz", "aguila", "sujecion"], ["tigre", "tigre", "anestesia"], ["oso", "oso", "anestesia"]]:
		if _solo != "" and String(a[1]) != _solo:
			continue
		for t: String in State.CareData.TIP_START_IDS:
			_post("configure", [{ "animal": String(a[0]), "claw": String(a[1]), "overgrowth_days": 0.0, "seed": "demo-punta-al-empezar", "tip_start": t }])
			_post("set_sedation", [String(a[2])])
			page.call("set_view", "garra")
			mark.visible = false
			_say("6 · %s · punta %s" % [String(a[1]).capitalize(), String((State.CareData.TIP_STARTS[t] as Dictionary).name).to_lower()])
			await _wait(1.4)
	mark.visible = true
