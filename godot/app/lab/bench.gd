## Banco de ensayo (port de components/Bench.jsx de la 1.x): la losa del material con su textura real, la
## herramienta dibujada (uña de perfil o garra colgando) y la marca que deja. Mismo lienzo de 360 × 170, mismas
## posiciones y escalas. La animación es la de la app móvil 1.x (Bench.js), que sigue a la punta:
## - rayado: la punta recorre la losa de x1 a x2 en 1,1 s (cubic-bezier(.45,.05,.25,1)) y el surco se revela con
##   ella; las esquirlas, gotas o fibras (extras) aparecen en el último 15 %;
## - punción: la punta baja e impacta en 0,9 s (cubic-bezier(.6,0,.9,.4)), la huella aparece desde el 78 % y, al
##   terminar, la punta se retira 14,5 unidades en 0,5 s (cubic-bezier(.2,.8,.3,1)) para que se vea la herida.
## El surco es una textura fija: se revela recortándola a la izquierda de la punta. Con movimiento reducido, el
## banco salta al final. Las texturas vienen de la caché (ArtCache): se rasterizan a la escala de la pantalla y
## solo cuando cambian el material, la herramienta o el resultado.
## Precarga: con prewarm(ids), en cuanto el banco sabe a qué escala se pinta (su primer dibujo), encarga una losa por
## fotograma de esos materiales a la caché, que las construye y rasteriza en hilos de WorkerThreadPool (sin tocar el
## árbol de escena) y las entrega al hilo principal por su cola (poll). Así, al cambiar de material ya está su losa
## y no se ve la anterior mientras llega (unos 170 ms con el cuarzo).
## Aguijones (2.0): el insecto llega volando, pica con el aguijón en vertical y lo mete a su velocidad medida con el giro
## helicoidal; la abeja tira, el aparato se desgarra y se queda clavado con el saco del veneno latiendo mientras bombea
## (×10); las avispas lo sacan y se van; un aguijón que pandea se dobla. El guion es el de core/lab/sting_lab.gd y la
## pose de cada momento, la de bench_insect.gd. El cuerpo, las alas, el aparato y el saco son texturas de la caché que
## se dibujan con transformaciones (las alas, dos veces y translúcidas al aletear); el aguijón es un polígono que se
## calcula en cada fotograma (ArtInsects.stinger_outline), y el giro y el veneno se escriben en dos Label creados una
## vez. Con movimiento reducido se enseña quieto el momento que explica el resultado (BenchInsect.still_ms).
## buzz_state() dice qué zumbido suena y con qué volumen (lo reproduce la sección).
## Materiales de la 2.0 (docs/fisica/pulido-materiales.md §7.6): con un resultado que trae sus campos, el guion de
## bench_materials.gd dice cuándo pasa cada cosa y los dibujos salen de core/lab/art_materials.gd: la abolladura (debajo),
## las grietas del surco (se revelan con la punta), las del punto (crecen con la carga), la ventanilla que estalla o el
## parabrisas que se agrieta (de golpe, con un destello; los trozos del hueco caen), la uña que se dobla o se parte (el
## borde libre, textura aparte, gira en su raíz o cae a la losa), la esquirla de una punta frágil, la estela del surco
## que se cierra y la lupa con lo microscópico (la huella que sube se pinta encima). Todo son texturas de la caché que
## se piden al empezar el ensayo, más unos pocos trazos y polígonos que se calculan solo mientras hay animación; el
## rótulo de la lupa es un Label creado una vez. Con un resultado de la 1.x el banco es el de siempre.
## Biología de la 2.0 (docs/fisica/pulido-biologia.md §9.6 y §9.11; bench_biology.gd y core/lab/art_biology.gd): la
## herramienta inclinada con el ángulo de ataque del resultado (la uña que arrastra, dada la vuelta), la lupa de la punción
## que llega al hueso o a la cavidad, a escala verdadera, con la punta que entra, topa, marca, atraviesa o se rompe (pintada
## encima de su textura, como la huella que sube), y las lupas quietas del esmalte del colmillo, del ataque, del callo y
## de la laceración que llega al hueso.
extends Control

const LabArt = preload("res://app/lab/lab_art.gd")
const BenchInsect = preload("res://app/lab/bench_insect.gd")
const BenchMaterials = preload("res://app/lab/bench_materials.gd")
const BenchBiology = preload("res://app/lab/bench_biology.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")

const W := 360.0
const H := 170.0
const TOP := 104.0
const FACE := 38.0
const GY := TOP + FACE * 0.46
const CX := 180.0
const X1 := 46.0
## Caja visible de cada herramienta en su propio dibujo (medida rasterizando todas: la garra colgando asoma fuera
## de 0 0 100 132 y el dedo de la uña de perfil se difumina hasta -149, -113). En la 1.x el banco no la recorta.
const CLAW_VIEW := Rect2(-26.0, -64.0, 144.0, 184.0)
const NAIL_VIEW := Rect2(-151.0, -115.0, 156.0, 121.0)
const CLAW_SCALE := 0.56
const NAIL_SCALE := 0.78
const SCRATCH_MS := 1100.0
const PUNCTURE_MS := 900.0
const LIFT_MS := 500.0
const VIEW := Rect2(0.0, 0.0, W, H)

var cache: ArtCache = null
## Nombre del banco en las claves de la caché ("main", "A", "B"): cada banco tiene su surco.
var slot := "main"
var reduce_motion := false
var target: Dictionary = {}
var res: Variant = null
var phase := "idle"
var length := 25.0
var method := "rayado"
var tool_sel: Dictionary = {}
var run_id := -1
var _t := 0.0  # progreso del recorrido (0-1, lineal en el tiempo)
var _lift := 0.0  # retirada tras la punción (0-1)
var _pose := Vector3(X1, GY, 2.0)  # x, y de la punta y desplazamiento de la sombra (unidades del banco)
var _shadow: GradientTexture2D
var _res_copy: Dictionary = {}
var _tex := {}  # capa → última textura pintada (base, groove, extras, hole, tool)
## Precarga de losas: materiales pedidos, escala a la que se precargan, cola de los que faltan por encargar y medidas
## (inicio y fin de la precarga en µs de Time.get_ticks_usec, y lo más que ha tardado un fotograma en encargar).
var _warm_ids: Array = []
var _warm_px := -1.0
var _warm_queue: Array = []
var warm_started_us := 0
var warm_done_us := 0
var warm_submit_max_us := 0
## Insecto: ms del ensayo, pose de ahora (BenchInsect.pose), fin de su guion y cajas de sus dibujos por especie.
var _ins_ms := 0.0
var _ins_pose: Dictionary = {}
var _ins_end := 0.0
var _ins_views := {}
var twist_label: Label
var venom_label: Label
## Materiales de la 2.0: el guion del ensayo (BenchMaterials.plan; {} si no hay nada), sus ms, la pose de ahora, el
## material y el resultado con que se pintan las marcas de la 1.x (ArtMaterials.marks_look_id y res_for_1x_marks) y el
## rótulo de la lupa.
var _mat: Dictionary = {}
var _mat_ms := 0.0
var _mat_pose: Dictionary = {}
var _marks_tid := ""
var _marks_res: Dictionary = {}
var lupa_label: Label
## Biología de la 2.0: el ángulo de ataque pedido en espera (el estado lo trae en `attack`; si no, el de la herramienta)
## y la inclinación de la herramienta (BenchBiology.tool_tilt): la de ahora, de dónde viene, adónde va, cuánto lleva y de
## qué herramienta es.
var attack_req: Variant = null
## El modelo físico del ensayo que se prepara (LabState.model): con la 1.x, la herramienta en espera no se inclina.
var model_req := "2.0"
var _tilt: Dictionary = BenchBiology.none()
var _tilt_from: Dictionary = BenchBiology.none()
var _tilt_to: Dictionary = BenchBiology.none()
var _tilt_ms := BenchBiology.TILT_MS
var _tilt_tool := ""


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	twist_label = _overlay_label("dim")
	add_child(twist_label)
	venom_label = _overlay_label("gold")
	add_child(venom_label)
	lupa_label = _overlay_label("dim")
	add_child(lupa_label)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.45))
	g.set_color(1, Color(0, 0, 0, 0.0))
	_shadow = GradientTexture2D.new()
	_shadow.gradient = g
	_shadow.fill = GradientTexture2D.FILL_RADIAL
	_shadow.fill_from = Vector2(0.5, 0.5)
	_shadow.fill_to = Vector2(1.0, 0.5)
	_shadow.width = 64
	_shadow.height = 64


func setup(p_cache: ArtCache, p_slot: String) -> void:
	cache = p_cache
	slot = p_slot
	cache.art_ready.connect(_on_art_ready)


## Materiales cuyas losas se precargan (ids de Catalog.TARGETS), a la escala a la que se pinte el banco.
func prewarm(target_ids: Array) -> void:
	_warm_ids = target_ids.duplicate()
	_warm_px = -1.0
	_warm_queue.clear()
	queue_redraw()


## ¿Están ya en la caché las losas de todos los materiales pedidos, a la escala del banco?
func is_warm() -> bool:
	if _warm_ids.is_empty() or _warm_px <= 0.0 or not _warm_queue.is_empty():
		return false
	for id: String in _warm_ids:
		if not cache.has_texture("bench:" + id, _warm_px):
			return false
	return true


## Encarga a la caché la siguiente losa de la cola (una por fotograma: el hilo principal solo pone la tarea).
func _warm_step() -> void:
	if _warm_queue.is_empty():
		if warm_started_us > 0 and warm_done_us == 0 and is_warm():
			warm_done_us = Time.get_ticks_usec()
		return
	var t0 := Time.get_ticks_usec()
	var id: String = _warm_queue.pop_front()
	cache.texture("bench:" + id, LabArt.bench_base.bind(id), _view_of(VIEW), _warm_px)
	warm_submit_max_us = maxi(warm_submit_max_us, Time.get_ticks_usec() - t0)


## Con la escala del primer dibujo (o una nueva, si cambia el tamaño), la cola de las losas que faltan.
func _warm_plan(px: float) -> void:
	if _warm_ids.is_empty() or absf(px - _warm_px) < 0.005:
		return
	_warm_px = px
	_warm_queue.clear()
	for id: String in _warm_ids:
		if not cache.has_texture("bench:" + id, px):
			_warm_queue.append(id)
	warm_started_us = Time.get_ticks_usec()
	warm_done_us = 0


## Estado del banco: { target, res, phase, length, method, tool: { claw, geom, base, inlay, wet }, run } y, si lo trae,
## attack (el ángulo de ataque pedido, para la inclinación de la herramienta en espera).
func set_state(s: Dictionary) -> void:
	var new_run: int = s.run
	var new_phase: String = s.phase
	var restart := new_run != run_id and new_phase != "idle"
	target = s.target
	res = s.res
	length = s.length
	method = s.method
	tool_sel = s.tool
	attack_req = s.get("attack")
	model_req = String(s.get("model", "2.0"))
	_set_tilt(restart and not (reduce_motion or new_phase == "done"), new_phase)
	if restart:
		run_id = new_run
		_t = 1.0 if (reduce_motion or new_phase == "done") else 0.0
		_lift = 1.0 if (reduce_motion or new_phase == "done") else 0.0
		_res_copy = (res as Dictionary).duplicate(true) if res != null else {}
		_start_materials(reduce_motion or new_phase == "done")
	if new_phase == "idle":
		_t = 0.0
		_lift = 0.0
		_res_copy = {}
		_start_materials(false)
	phase = new_phase
	accessibility_name = ("Banco: %s" % res.verdict) if (res != null and phase == "done") else ("Banco listo: %s" % target.get("name", ""))
	if is_insect():
		if restart:
			_ins_end = StingLab.timeline(res, StingLab.RUN_MS).end if res != null else 0.0
			_ins_ms = BenchInsect.still_ms(res, StingLab.RUN_MS) if (res != null and (reduce_motion or new_phase == "done")) else 0.0
		if new_phase == "idle":
			_ins_ms = 0.0
		_update_insect()
	_update_pose(true)
	queue_redraw()


## ¿La herramienta del banco es un aguijón de insecto?
func is_insect() -> bool:
	var claw: Variant = tool_sel.get("claw")
	return claw != null and Insects.is_stinger(claw)


## 2.0 · la inclinación de la herramienta que toca ahora (la del resultado o la de la espera). animate: al empezar un
## ensayo, pasa a ella en TILT_MS desde la de antes; si no (o si cambia la herramienta), salta.
func _set_tilt(animate: bool, new_phase: String) -> void:
	if tool_sel.is_empty() or is_insect():
		_tilt = BenchBiology.none()
		_tilt_from = _tilt
		_tilt_to = _tilt
		_tilt_ms = BenchBiology.TILT_MS
		_tilt_tool = ""
		return
	var puncture := bool(res.puncture) if (res != null and new_phase != "idle") else method == "puncion"
	var goal := BenchBiology.tool_tilt(res if new_phase != "idle" else null, tool_sel, puncture, attack_req)
	if new_phase == "idle" and model_req == "1.x":
		goal = BenchBiology.none()  # la 1.x: su dibujo
	var tk := _tool_key()
	if goal != _tilt_to or tk != _tilt_tool:
		if animate and tk == _tilt_tool:
			_tilt_from = _tilt
			_tilt_ms = 0.0
		else:
			_tilt_from = goal
			_tilt_ms = BenchBiology.TILT_MS
		_tilt_to = goal
	_tilt_tool = tk
	_tilt = BenchBiology.tilt_at(_tilt_from, _tilt_to, _tilt_ms / BenchBiology.TILT_MS)


## Inclinación de la herramienta que se está pintando (BenchBiology.tool_tilt, o a mitad de camino).
func tool_tilt() -> Dictionary:
	return _tilt


## Materiales de la 2.0 al empezar un ensayo (o al volver a espera): el guion, el material y el resultado de las marcas de
## la 1.x y la pose. done: se enseña ya el final (movimiento reducido o un ensayo ya terminado).
func _start_materials(done: bool) -> void:
	_mat = {}
	_mat_ms = 0.0
	_marks_res = _res_copy
	_marks_tid = String(target.get("id", ""))
	if not _res_copy.is_empty() and not is_insect():
		_marks_res = ArtMaterials.res_for_1x_marks(_res_copy)
		_marks_tid = ArtMaterials.marks_look_id(_marks_tid)
		# la herramienta con su inclinación: si la base va por delante, la lupa va al otro lado
		var t := tool_sel.duplicate()
		t["lean"] = int(_tilt_to.lean)
		_mat = BenchMaterials.plan(_res_copy, t, X1, _x2())
		# 2.0 · biología: la lupa de la punción que llega al hueso o a la cavidad, la del esmalte… (bench_biology.gd)
		_mat = BenchBiology.with_biology(_mat, _res_copy, t, _x2())
		if not _mat.is_empty() and done:
			_mat_ms = float(_mat.end)
	_update_mat_pose()


func _update_mat_pose() -> void:
	_mat_pose = BenchMaterials.pose(_mat, _mat_ms, _lift) if not _mat.is_empty() else {}
	if _mat.get("bone") != null:
		_mat_pose["bone"] = BenchBiology.bone_pose(_mat, _mat_ms, _lift)
	_update_labels()


## Guion de los materiales de la 2.0 del ensayo que se pinta ({} si no hay) y su pose de ahora.
func materials_plan() -> Dictionary:
	return _mat


func materials_pose() -> Dictionary:
	return _mat_pose


func materials_ms() -> float:
	return _mat_ms


## Pose del insecto ahora (BenchInsect.pose, o la de espera) y los rótulos del giro y del veneno.
func _update_insect() -> void:
	var o := { "cx": CX, "gy": GY }
	if phase == "idle" or res == null or not (res as Dictionary).has("sting"):
		_ins_pose = BenchInsect.idle_pose(tool_sel.claw, o)
	else:
		_ins_pose = BenchInsect.pose(tool_sel.claw, res, _ins_ms, StingLab.RUN_MS, o)
	_update_labels()


## Pose del insecto que se está pintando ({} sin insecto).
func insect_pose() -> Dictionary:
	return _ins_pose if is_insect() else {}


## ms del ensayo del insecto que se está pintando.
func insect_ms() -> float:
	return _ins_ms


## El zumbido del insecto: { id (SfxInsects.buzz_id; "" si no zumba), volume (0-1), pitch }. Solo mientras vuela o pica
## en un ensayo, nunca en espera ni con movimiento reducido.
func buzz_state() -> Dictionary:
	if not is_insect() or _ins_pose.is_empty() or phase == "idle" or reduce_motion:
		return { "id": "", "volume": 0.0, "pitch": 1.0 }
	var id := SfxInsects.buzz_id(tool_sel.claw)
	return { "id": id, "volume": BenchInsect.buzz_volume(_ins_pose, id), "pitch": 1.0 }


## Avanza la animación ms milisegundos (lo llama la sección en _process) y la precarga de las losas.
func advance(ms: float) -> void:
	if cache != null:
		_warm_step()
	if is_insect():
		_advance_insect(ms)
		return
	var before := Vector3(_pose)
	var t0 := _t
	var l0 := _lift
	if phase != "idle":
		_t = 1.0 if reduce_motion else minf(1.0, _t + ms / (PUNCTURE_MS if _puncture() else SCRATCH_MS))
	if phase == "done":
		if _t < 1.0:
			_t = 1.0
		if _puncture():
			_lift = 1.0 if reduce_motion else minf(1.0, _lift + ms / LIFT_MS)
	_update_pose(false, ms)
	# la herramienta que se inclina al empezar (2.0)
	var tilt_moved := false
	if _tilt_ms < BenchBiology.TILT_MS:
		_tilt_ms = BenchBiology.TILT_MS if reduce_motion else minf(_tilt_ms + ms, BenchBiology.TILT_MS)
		_tilt = BenchBiology.tilt_at(_tilt_from, _tilt_to, _tilt_ms / BenchBiology.TILT_MS)
		tilt_moved = true
	# los materiales de la 2.0: su reloj y su pose, solo mientras dura su guion (o se retira la punta)
	var mat_moved := false
	if not _mat.is_empty() and phase != "idle":
		var m0 := _mat_ms
		_mat_ms = float(_mat.end) if reduce_motion else minf(_mat_ms + ms, float(_mat.end))
		if _mat_ms != m0 or _lift != l0:
			_update_mat_pose()
			mat_moved = true
	if _t != t0 or _lift != l0 or not before.is_equal_approx(_pose) or mat_moved or tilt_moved:
		queue_redraw()


func _advance_insect(ms: float) -> void:
	if phase == "idle" or res == null:
		return
	var before := _ins_ms
	if reduce_motion:
		_ins_ms = BenchInsect.still_ms(res, StingLab.RUN_MS)
	else:
		_ins_ms = minf(_ins_ms + ms, _ins_end)
	if _ins_ms != before:
		_update_insect()
		queue_redraw()


## ¿Queda animación pendiente? (la demo espera a que el banco esté quieto)
func is_animating() -> bool:
	if is_insect():
		return phase == "running" or (phase == "done" and not reduce_motion and _ins_ms < _ins_end)
	var mat := not _mat.is_empty() and phase == "done" and _mat_ms < float(_mat.end)
	var tilting := _tilt_ms < BenchBiology.TILT_MS
	return phase == "running" or (phase == "done" and (_t < 1.0 or (_puncture() and _lift < 1.0))) or mat or tilting


func _puncture() -> bool:
	return bool(res.puncture) if res != null else method == "puncion"


func _x2() -> float:
	return X1 + 70.0 + (length / 60.0) * 222.0


## Progreso suavizado del recorrido (la curva de la transición de cada método).
func eased() -> float:
	return Ui.cubic_bezier(0.6, 0.0, 0.9, 0.4, _t) if _puncture() else Ui.cubic_bezier(0.45, 0.05, 0.25, 1.0, _t)


func _target_pose() -> Vector3:
	var e := eased()
	if _puncture():
		var l := Ui.cubic_bezier(0.2, 0.8, 0.3, 1.0, _lift)
		return Vector3(CX, lerpf(GY - 34.0, GY + 1.5, e) - 14.5 * l, lerpf(34.0, 2.0, e) + 13.0 * l)
	return Vector3(lerpf(X1, _x2(), e), GY, 2.0)


## En reposo, la punta vuelve a su sitio con suavidad (en la 1.x, una transición CSS); durante el ensayo la
## posición es exactamente la de la animación.
func _update_pose(snap: bool, ms := 0.0) -> void:
	var goal := _target_pose()
	if phase != "idle" or snap and reduce_motion:
		_pose = goal
	elif snap:
		pass
	else:
		var k := 1.0 - exp(-ms / 90.0)
		_pose = _pose.lerp(goal, k)
		if _pose.distance_to(goal) < 0.05:
			_pose = goal


## Transparencia de las marcas que aparecen al final (extras del surco y huella de la punción).
func reveal() -> float:
	if phase == "done" and _t >= 1.0:
		return 1.0
	var th := 0.78 if _puncture() else 0.85
	return clampf((eased() - th) / (1.0 - th), 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var h := ceilf(size.x * H / W)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h
		_update_labels()
		queue_redraw()


## Rótulo sobre el banco (el giro y el veneno del insecto), creado una vez.
static func _overlay_label(color: String) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	l.add_theme_font_override("font", AppTheme.MONO_BOLD)
	l.add_theme_color_override("font_color", Palette.color(color))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 3)
	# un fondo translúcido: el rótulo se lee aunque caiga sobre la herramienta o el animal (la lupa cerca del borde)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.color("bg"), 0.72)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 5.0
	bg.content_margin_right = 5.0
	bg.content_margin_top = 1.0
	bg.content_margin_bottom = 1.0
	l.add_theme_stylebox_override("normal", bg)
	return l


## El giro helicoidal mientras entra (con el valor medido, Wu et al. 2014) y el veneno que va saliendo; junto al
## aguijón, a la escala del banco.
func _update_labels() -> void:
	if twist_label == null:
		return
	var p := _ins_pose if is_insect() else {}
	var running := not p.is_empty() and phase != "idle"
	var s := size.x / W if size.x > 0.0 else 1.0
	var fs := maxi(9, int(round(8.0 * s)))
	_update_lupa_label(s, fs)
	var tw: Variant = p.get("twist")
	twist_label.visible = running and tw != null and p.show_insect
	if twist_label.visible:
		twist_label.text = "giro %s°" % Js.to_fixed(float(tw), 1)
		twist_label.add_theme_font_size_override("font_size", fs)
		twist_label.size = Vector2.ZERO
		_place(twist_label, (CX + 10.0) * s, (GY - 14.0) * s)
	var v: Dictionary = p.get("venom", {})
	var frac := float(v.get("fraction", 0.0))
	venom_label.visible = running and frac > 0.0 and (p.show_insect or p.apparatus)
	if venom_label.visible:
		var ug: Variant = v.get("ug")
		var txt := ("veneno ~%s µg" % Js.js_num_str(Js.js_round(float(ug)))) if ug != null else ("veneno %s %%" % Js.to_fixed(frac * 100.0, 0))
		if p.apparatus:
			txt += " · saco vacío" if frac >= 0.999 else " · bombea solo (×%s)" % Js.js_num_str(StingLab.ANIM.pumpSpeedup)
		venom_label.text = txt
		venom_label.add_theme_font_size_override("font_size", fs)
		venom_label.size = Vector2.ZERO
		if p.apparatus:  # centrado sobre el aparato clavado
			_place(venom_label, CX * s - venom_label.get_minimum_size().x / 2.0, (GY - 48.0) * s)
		else:
			_place(venom_label, (CX + 10.0) * s, (GY - 30.0) * s)


## Coloca un rótulo en (x, y) (px del banco) sin que se salga por los lados (en un teléfono el banco es estrecho).
func _place(l: Label, x: float, y: float) -> void:
	var w := l.get_minimum_size().x
	l.position = Vector2(clampf(x, 4.0, maxf(4.0, size.x - w - 4.0)), y)


## El rótulo de la lupa (su barra de escala, la exageración o la cuenta de trozos), centrado debajo de ella; y la lupa en
## la descripción del banco.
func _update_lupa_label(s: float, fs: int) -> void:
	var a := float(_mat_pose.get("lupa", 0.0)) if not _mat.is_empty() and _mat.lupa != null and phase != "idle" else 0.0
	var text := ""
	if a > 0.0:
		text = String(cache.meta("bml:%s:%d:%s" % [slot, run_id, target.get("id", "")]).get("text", "")) if cache != null else ""
	lupa_label.visible = a > 0.05 and text != ""
	if not lupa_label.visible:
		return
	lupa_label.text = text
	lupa_label.modulate.a = a
	lupa_label.add_theme_font_size_override("font_size", fs)
	lupa_label.size = Vector2.ZERO
	var L: Vector2 = _mat.lupa.pos
	_place(lupa_label, L.x * s - lupa_label.get_minimum_size().x / 2.0, (L.y + ArtMaterials.LUPA_R * lupa_zoom() + 1.5) * s)
	if res != null and phase == "done":
		accessibility_name = "Banco: %s · lupa: %s" % [res.verdict, text]


func _on_art_ready(_k: String) -> void:
	_update_labels()
	queue_redraw()


# ── Claves de cada capa (los dibujos están en lab_art.gd: la caché los construye en hilos) ──

func _tool_key() -> String:
	var claw: Variant = tool_sel.get("claw")
	var who: String = ("c:" + String(claw.id)) if claw != null else ("n:%s:%s" % [tool_sel.geom.id, tool_sel.base.id])
	return "btool:%s:%s:%s" % [who, tool_sel.inlay.id, tool_sel.get("wet", false)]


static func _view_of(r: Rect2) -> Dictionary:
	return {
		"viewBox": "%s %s %s %s" % [Js.js_num_str(r.position.x), Js.js_num_str(r.position.y), Js.js_num_str(r.size.x),
			Js.js_num_str(r.size.y)],
		"width": r.size.x, "height": r.size.y,
	}


## Textura de una capa; mientras llega la nueva sigue la anterior, salvo en las marcas de un ensayo distinto.
func _layer(layer: String, key: String, make: Callable, view: Rect2, scale: float, keep_old := true) -> Texture2D:
	var t: Texture2D = cache.texture(key, make, _view_of(view), scale)
	if t != null:
		_tex[layer] = [key, t]
		return t
	var old: Array = _tex.get(layer, [])
	if keep_old and not old.is_empty():
		return old[1]
	return null


func _draw() -> void:
	if cache == null or target.is_empty() or size.x < 2.0:
		return
	var s := size.x / W
	var px := s * SvgTexture.screen_scale(self)
	_warm_plan(ArtCache.snap_scale(px))
	var tid: String = target.id
	var base := _layer("base", "bench:" + tid, LabArt.bench_base.bind(tid), VIEW, px)
	if base != null:
		draw_texture_rect(base, Rect2(Vector2.ZERO, size), false)
	if is_insect():
		_draw_insect(s, px)
		return
	var puncture := _puncture()
	var shown := res != null and phase != "idle"
	var mat := shown and not _mat.is_empty() and not _mat_pose.is_empty()
	var x2 := _x2()
	var gk := "%s:%d:%s:%s" % [slot, run_id, tid, Js.js_num_str(x2)]
	# hasta dónde se ve el surco: la punta (o todo, al acabar), sin pasar de donde se partió la uña
	var reveal_x := W if (phase == "done" and _t >= 1.0) else _pose.x
	if mat:
		reveal_x = minf(reveal_x, float(_mat.x_stop))
	if mat and _mat.dent != null:
		_draw_dent(gk, x2, reveal_x, puncture, s, px)
	if shown and not puncture:
		var lines := _layer("lines", "bgl:" + gk, LabArt.groove_part.bind(_marks_tid, _marks_res, x2, "lines"), VIEW, px, false)
		if lines != null and _tex.get("lines", [""])[0] == "bgl:" + gk:
			_draw_revealed(lines, reveal_x)
		if mat and _mat.hertz != null:
			var tk := "bmt:" + gk
			var track := _layer("mtrack", tk, LabArt.mat_track.bind(_res_copy, x2, float(_mat.hertz.x)), VIEW, px, false)
			if track != null and _tex.get("mtrack", [""])[0] == tk:
				_draw_revealed(track, reveal_x)
		var a := reveal()
		if a > 0.0:
			var extras := _layer("extras", "bgx:" + gk, LabArt.groove_part.bind(_marks_tid, _marks_res, x2, "extras"), VIEW, px, false)
			if extras != null and _tex.get("extras", [""])[0] == "bgx:" + gk:
				if mat and float(_mat.x_stop) < x2:
					_draw_revealed(extras, float(_mat.x_stop), a)
				else:
					draw_texture_rect(extras, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, a))
	if shown and puncture:
		var a := reveal()
		if a > 0.0:
			var claw: Variant = tool_sel.get("claw")
			var fangs: bool = claw != null and bool(claw.get("fang", false))
			var hk := "bph:%s:%d:%s" % [slot, run_id, tid]
			var hole := _layer("hole", hk, LabArt.bench_hole.bind(_marks_tid, _marks_res, fangs), VIEW, px, false)
			if hole != null and _tex.get("hole", [""])[0] == hk:
				draw_texture_rect(hole, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, a))
	if mat:
		_draw_burst(gk, x2, puncture, s, px)
	_draw_tool(s, px)
	if res != null and phase == "done" and Js.truthy(res.get("toolWorn")):
		var wx := CX if puncture else _x2()
		draw_circle(Vector2(wx, GY - 3.0) * s, 4.0 * s, Color(Palette.color("coral"), 0.85), true, -1.0, true)
	if mat and _mat.lupa != null:
		_draw_lupa(s, px)


## Una capa del banco (360 × 170) recortada a la izquierda de x (unidades), con opacidad a.
func _draw_revealed(tex: Texture2D, x: float, a := 1.0) -> void:
	var frac := clampf(x / W, 0.0, 1.0)
	if frac > 0.0:
		draw_texture_rect_region(tex, Rect2(0, 0, size.x * frac, size.y), Rect2(0, 0, tex.get_width() * frac, tex.get_height()),
			Color(1, 1, 1, a))


# ── Materiales de la 2.0 (el guion, en bench_materials.gd; los dibujos, en art_materials.gd) ──

## La abolladura: al punzar, se hunde al tocar (opacidad); al rayar, se revela con la punta desde el colapso de la chapa.
func _draw_dent(gk: String, x2: float, reveal_x: float, puncture: bool, _s: float, px: float) -> void:
	var a: float = _mat_pose.dent
	if a <= 0.0:
		return
	var dk := "bmd:" + gk
	var tex := _layer("mdent", dk, LabArt.mat_dent.bind(_res_copy, x2, not puncture, float(_mat.dent.x)), VIEW, px, false)
	if tex == null or _tex.get("mdent", [""])[0] != dk:
		return
	if puncture:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, a))
	else:
		_draw_revealed(tex, reveal_x + ArtMaterials.dent_radius_mm(float(_res_copy.dent.depthMm)) * ArtMaterials.MM)


## Lo que aparece en el punto: las grietas que crecen con la carga (escaladas desde el punto), el panal o la estrella del
## vidrio de coche (de golpe), sus trozos que caen, el destello y, al rayar, la estela del surco y la esquirla de la punta.
func _draw_burst(gk: String, x2: float, puncture: bool, s: float, px: float) -> void:
	var p := _mat_pose
	var face := Rect2(12.0, TOP, W - 24.0, FACE)
	if _mat.crack != null and float(p.crack) > 0.0:
		var ck := "bmc:" + gk
		var tex := _layer("mcrack", ck, LabArt.mat_burst.bind(target, _res_copy, x2, CX, false, "cracks"), VIEW, px, false)
		if tex != null and _tex.get("mcrack", [""])[0] == ck:
			var k: float = p.crack
			var c := Vector2(CX, GY) * s
			draw_set_transform(c * (1.0 - k), 0.0, Vector2(k, k))
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	if _mat.glazing != null and float(p.glazing) > 0.0:
		var gx: float = CX if puncture else float(_mat.glazing.x)
		var gk2 := "bmg:" + gk
		var tex := _layer("mglaze", gk2, LabArt.mat_burst.bind(target, _res_copy, x2, gx, not puncture, "glazing"), VIEW, px, false)
		if tex != null and _tex.get("mglaze", [""])[0] == gk2:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, float(p.glazing)))
			var m := cache.meta(gk2)
			if float(p.fall) >= 0.0 and m.has("pieces"):
				BenchMaterials.draw_pieces(self, m.pieces, float(p.fall), s, Color(String(ArtMaterials.look(String(target.id)).base)))
		BenchMaterials.draw_flash(self, face, float(p.flash), s)
	if _mat.wake and not puncture and phase != "idle":
		var w := maxf(1.2, float(_res_copy.get("grooveWidthUm", 0.0)) / 1000.0 * ArtMaterials.MM)
		BenchMaterials.draw_wake(self, _pose.x, X1, GY, w, s, Color("#F4F1F2"))
	if _mat.chip != null and float(p.chip) >= 0.0:
		var col := Color(String(tool_sel.inlay.col)) if tool_sel.get("inlay") is Dictionary else Color.WHITE
		BenchMaterials.draw_chips(self, Vector2(float(_mat.chip.x), GY - 1.0), GY + 2.0, float(p.chip), s, col)


## La lupa: su textura (con la opacidad de la pose), la línea de puntos hasta lo que aumenta y, si es la huella que sube,
## el surco y la punta pintados encima.
func _draw_lupa(s: float, px: float) -> void:
	var a: float = _mat_pose.lupa
	if a <= 0.0:
		return
	var L: Vector2 = _mat.lupa.pos
	var z := lupa_zoom()
	var view := LabArt.lupa_view()
	var key := "bml:%s:%d:%s" % [slot, run_id, target.id]
	var tex := _layer("mlupa", key, LabArt.mat_lupa.bind(target, _res_copy), view, px * z, false)
	if tex == null or _tex.get("mlupa", [""])[0] != key:
		return
	var p := lupa_point()
	var from := L + (p - L).normalized() * ArtMaterials.LUPA_R * z
	draw_dashed_line(from * s, p * s, Color(Palette.color("dim"), 0.85 * a), maxf(1.0, 0.7 * s), 3.0 * s, true, true)
	draw_circle(p * s, 1.8 * s, Color(Palette.color("gold"), a), false, maxf(1.0, 0.6 * s), true)
	draw_texture_rect(tex, Rect2((L + view.position * z) * s, view.size * z * s), false, Color(1, 1, 1, a))
	var m := cache.meta(key)
	var kind := String(m.get("kind", ""))
	if kind == "recuperacion" and m.has("dyn"):
		BenchMaterials.draw_recovery(self, L, m.dyn, _mat_pose.rec, a, s, Color(String(_res_copy.vcol)), Color("#EDE7F6"), z)
		draw_arc(L * s, ArtMaterials.LUPA_R * z * s, 0.0, TAU, 64, Color(Palette.color("line2"), a), 1.4 * s, true)
	elif (kind == "hueso" or kind == "cavidad") and m.has("dyn") and _mat_pose.has("bone"):
		BenchBiology.draw_bone(self, L, m.dyn, _mat_pose.bone, a, s, _tool_color(), z)
		draw_arc(L * s, ArtMaterials.LUPA_R * z * s, 0.0, TAU, 64, Color(Palette.color("line2"), a), 1.4 * s, true)


## Color de la herramienta en las lupas: el de su material si lleva incrustación (una garra reforjada o una gema) o el de
## la garra; si no, marfil (una uña no llega al hueso).
func _tool_color() -> Color:
	var inlay: Variant = tool_sel.get("inlay")
	if inlay is Dictionary and String(inlay.get("id", "none")) != "none" and inlay.get("col") != null:
		return Color(String(inlay.col))
	var claw: Variant = tool_sel.get("claw")
	if claw is Dictionary and claw.get("col") != null:
		return Color(String(claw.col))
	return Color("#E4E0D8")


## Aumento de la lupa: más grande en un banco estrecho (un teléfono), para que se lea lo que enseña. Con 1,2 cabe entre
## el borde de arriba del banco y la losa, con su rótulo debajo.
func lupa_zoom() -> float:
	return 1.2 if size.x > 0.0 and size.x < 430.0 else 1.0


## El punto que aumenta la lupa (unidades del banco): el de la punción, la mitad del surco (donde la lupa corta la
## huella), donde estalló el vidrio o el centro de las grietas del surco.
func lupa_point() -> Vector2:
	if _puncture():
		return Vector2(CX, GY)
	if _mat.rec != null:
		return Vector2((X1 + _x2()) / 2.0, GY)
	if _mat.glazing != null:
		return Vector2(float(_mat.glazing.x), GY)
	var x0 := float(_mat.hertz.x) if _mat.hertz != null else X1
	return Vector2((x0 + minf(_x2(), float(_mat.x_stop))) / 2.0, GY)


func _draw_tool(s: float, px: float) -> void:
	if tool_sel.is_empty():
		return
	var claw: Variant = tool_sel.get("claw")
	var view := CLAW_VIEW if claw != null else NAIL_VIEW
	var k := CLAW_SCALE if claw != null else NAIL_SCALE
	var key := _tool_key()
	var make := LabArt.bench_tool.bind(claw, tool_sel.geom, tool_sel.base, tool_sel.inlay, bool(tool_sel.get("wet", false)))
	# sombra en la losa, bajo la punta
	var sh := Vector2(_pose.x, _pose.y + _pose.z) * s
	draw_texture_rect(_shadow, Rect2(sh.x - 14.0 * s, sh.y - 3.2 * s, 28.0 * s, 6.4 * s), false)
	# 2.0 · la uña que se dobla o se parte: el dedo y el borde libre, cada uno con su textura
	if claw == null and not _mat.is_empty() and _mat.nail != null and not _mat_pose.is_empty() and phase != "idle":
		var np: Dictionary = _mat_pose.nail
		if (float(np.angle) != 0.0 or float(np.snap) >= 0.0) and _draw_nail_parts(np, s, px):
			return
	var tex := _layer("tool", key, make, view, px * k, true)
	if tex == null:
		return
	var tip := Vector2.ZERO
	var m: Dictionary = cache.meta(_tex["tool"][0])
	if m.has("tip"):
		tip = Vector2(float(m.tip.x), float(m.tip.y))
	# con la inclinación del ataque (2.0; la de la 1.x deja el dibujo tal cual: la punta en la pose)
	draw_set_transform_matrix(BenchBiology.tool_xform(Vector2(_pose.x, _pose.y), tip, k, _tilt, s))
	draw_texture_rect(tex, view, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## La uña de perfil partida por la raíz del borde libre (ArtMaterials.nail_part_art), con la inclinación del ataque.
## Doblándose (snap < 0), el borde libre gira angle en su raíz y el dedo se desplaza lo justo para que la punta siga en la
## losa; partida, el dedo sigue sin él (da un respingo) y el trozo cae desde donde se partió hasta quedar tumbado en la
## losa. false si las texturas aún no están (se pinta la uña entera mientras llegan).
func _draw_nail_parts(np: Dictionary, s: float, px: float) -> bool:
	var geom: Dictionary = tool_sel.geom
	var base: Dictionary = tool_sel.base
	var inlay: Dictionary = tool_sel.inlay
	var wet := bool(tool_sel.get("wet", false))
	var id := "%s:%s:%s:%s" % [geom.id, base.id, inlay.id, wet]
	var k := NAIL_SCALE
	var fk := "bnail:finger:" + id
	var ek := "bnail:edge:" + id
	var ft: Texture2D = cache.texture(fk, LabArt.nail_part.bind(geom, base, inlay, wet, "finger"), _view_of(NAIL_VIEW), px * k)
	var et: Texture2D = cache.texture(ek, LabArt.nail_part.bind(geom, base, inlay, wet, "edge"), _view_of(NAIL_VIEW), px * k)
	var m := cache.meta(ek)
	if ft == null or et == null or not m.has("pivot"):
		return false
	var pv := Vector2(float(m.pivot.x), float(m.pivot.y))  # la raíz del borde libre, en las coordenadas de la uña
	var rect := Rect2(NAIL_VIEW.position, NAIL_VIEW.size)
	var tip := Vector2(_pose.x, _pose.y)
	var snap: float = np.snap
	if snap < 0.0:
		var th: float = np.angle
		# el dibujo, desplazado lo que gira la raíz para que la punta doblada siga donde toca
		var xf := BenchBiology.tool_xform(tip, Vector2.ZERO, k, _tilt, s) * Transform2D(0.0, Vector2.ONE, 0.0, pv.rotated(th) - pv)
		draw_set_transform_matrix(xf)
		draw_texture_rect(ft, rect, false)
		draw_set_transform_matrix(xf * Transform2D(th, pv) * Transform2D(0.0, -pv))
		draw_texture_rect(et, rect, false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return true
	# partida: el dedo da un respingo y sigue; el borde libre cae y gira hasta quedar tumbado junto a donde se partió
	var o := tip + Vector2(0.0, -6.0 * clampf(snap * 4.0, 0.0, 1.0))
	draw_set_transform_matrix(BenchBiology.tool_xform(o, Vector2.ZERO, k, _tilt, s))
	draw_texture_rect(ft, rect, false)
	var outline: PackedVector2Array = m.edge_outline
	var ec := Vector2.ZERO
	for q: Vector2 in outline:
		ec += q
	ec /= maxf(1.0, outline.size())
	# la parte lineal del dibujo en el banco (inclinación, vuelta y escala) y el giro que deja la placa tumbada
	var lin := Transform2D(float(_tilt.angle), Vector2(float(_tilt.sx) * k, k), 0.0, Vector2.ZERO)
	var plate := lin.basis_xform(Vector2(-cos(deg_to_rad(BenchMaterials.NAIL_ATTACK_DEG)), -sin(deg_to_rad(BenchMaterials.NAIL_ATTACK_DEG))))
	var phi_f := -plate.angle()
	while phi_f > PI / 2.0:
		phi_f -= PI
	while phi_f <= -PI / 2.0:
		phi_f += PI
	var low := 0.0
	for q: Vector2 in outline:
		low = maxf(low, lin.basis_xform(q - ec).rotated(phi_f).y)
	var at := Vector2(float(_mat.nail.x), GY) if not _puncture() else Vector2(CX, GY + 1.5)
	var start := at + lin.basis_xform(ec)
	var end := Vector2(at.x - 8.0 * signf(float(_tilt.sx)), GY - 0.3 - low)
	var c := Vector2(lerpf(start.x, end.x, snap), lerpf(start.y, end.y, snap * snap))
	var phi := phi_f * clampf(snap * 1.3, 0.0, 1.0)
	draw_set_transform_matrix(Transform2D(phi, Vector2(s, s), 0.0, c * s) * lin * Transform2D(0.0, -ec))
	draw_texture_rect(et, rect, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


# ── El insecto (aguijones de la 2.0) ──

## Cajas de los dibujos de una especie (se calculan una vez): el cuerpo con las alas y el aparato clavado.
func _insect_views(claw: Dictionary) -> Dictionary:
	if not _ins_views.has(claw.id):
		_ins_views[claw.id] = { "body": LabArt.insect_view(claw), "app": LabArt.apparatus_view(claw) }
	return _ins_views[claw.id]


## Elipse rellena centrada en c (unidades del banco) de semiejes rx y ry (un círculo unidad escalado: sin suavizado,
## que se haría en unidades del círculo y la emborronaría).
func _ellipse(c: Vector2, rx: float, ry: float, color: Color, s: float) -> void:
	draw_set_transform(c * s, 0.0, Vector2(rx, ry) * s)
	draw_circle(Vector2.ZERO, 1.0, color, true, -1.0, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_insect(s: float, px: float) -> void:
	var p := _ins_pose
	if p.is_empty():
		return
	var claw: Dictionary = tool_sel.claw
	var inlay: Dictionary = tool_sel.inlay
	var views := _insect_views(claw)
	var at := Vector2(CX, GY)
	var skin := res != null and Js.truthy(res.get("skin"))
	# 1 · la superficie: hoyuelo bajo la punta, entrada con su halo, nube de veneno y la punta aplastada
	var dimple: float = p.dimple
	if dimple > 0.0:
		_ellipse(at + Vector2(0.0, 0.4), 1.0 + 4.5 * dimple, 0.3 + 1.3 * dimple, Color(0, 0, 0, 0.3 * dimple), s)
	var wound: float = p.wound
	var venom_f := float(p.venom.fraction)
	if wound > 0.0 and skin:
		if venom_f > 0.0:
			_ellipse(at + Vector2(0.0, 0.6), 2.5 + 7.0 * venom_f, 1.0 + 2.4 * venom_f, Color(ArtInsects.VENOM, 0.3 * venom_f), s)
		_ellipse(at, 3.4, 1.25, Color("#D98A8A", 0.35 * wound), s)
		_ellipse(at, 0.9, 0.45, Color("#5A1A1A", 0.9 * wound), s)
	elif wound > 0.0:
		_ellipse(at, 0.8, 0.35, Color(0, 0, 0, 0.6 * wound), s)
	var crush: float = p.crush
	if crush > 0.0:
		for i in 5:
			var a := PI * (1.1 + 0.2 * i)
			var r := 2.0 + 4.0 * (1.0 - crush)
			draw_circle((at + Vector2(cos(a), sin(a) * 0.4) * r) * s, 0.7 * s, Color(ArtInsects.sting_color(claw, inlay), crush), true, -1.0, true)
	# 2 · el aparato que se queda clavado tras la autotomía, con el saco del veneno latiendo mientras bombea
	if p.apparatus:
		var ak := "bapp:%s:%s" % [claw.id, inlay.id]
		var av: Rect2 = views.app
		var app := _layer("iapp", ak, LabArt.apparatus.bind(claw, inlay), av, px, false)
		if app != null:
			draw_set_transform(at * s, 0.0, Vector2(s, s))
			draw_texture_rect(app, av, false)
			var m: Dictionary = cache.meta(ak)
			if m.has("sac"):
				var r := float(m.sac.r)
				var sv := Rect2(-r - 1.0, -r - 1.0, 2.0 * r + 2.0, 2.0 * r + 2.0)
				var sk := "bsac:%s" % Js.js_num_str(r)
				var sac := _layer("isac", sk, LabArt.venom_sac.bind(r), sv, px, false)
				if sac != null:
					var f := (0.55 + 0.45 * float(p.sac_fill)) * float(p.sac_pulse)
					draw_set_transform((at + Vector2(float(m.sac.x), float(m.sac.y))) * s, 0.0, Vector2(s * f, s * f))
					draw_texture_rect(sac, sv, false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	if not p.show_insect and not p.apparatus:
		return
	var body_view: Rect2 = views.body
	var bk := "bins:%s" % claw.id
	var body := _layer("ibody", bk, LabArt.insect_body.bind(claw), body_view, px, false)
	var wings := _layer("iwing", "bwing:%s" % claw.id, LabArt.insect_wings.bind(claw), body_view, px, false)
	var m: Dictionary = cache.meta(bk)
	if body == null or not m.has("stingAngle"):
		return
	var gaster: Vector2 = p.gaster
	# 3 · sombra del insecto en la losa (más tenue cuanto más alto)
	if p.show_insect:
		var fade := clampf(1.0 - (GY - gaster.y) / 130.0, 0.0, 1.0)
		draw_texture_rect(_shadow, Rect2((gaster.x - 18.0) * s, (GY - 3.0) * s, 36.0 * s, 6.0 * s), false, Color(1, 1, 1, 0.8 * fade))
	# 4 · el aguijón: lo que asoma (el resto está dentro), doblado si pandea; tras la autotomía lo dibuja el aparato
	var col := Color(ArtInsects.sting_color(claw, inlay))
	if not p.apparatus:
		var keep := minf(float(p.visible), float(p.len) * float(p.extend))
		if keep > 0.3:
			var pts := ArtInsects.stinger_outline(claw, p.len, p.width, p.bend, keep)
			var xf := Transform2D(float(p.tilt), Vector2(s, s), 0.0, (p.base as Vector2) * s)
			var poly := xf * pts
			draw_colored_polygon(poly, col)
			poly.append(poly[0])
			draw_polyline(poly, col.darkened(0.5), maxf(0.6, 0.3 * s), true)
	# 5 · la abeja tira: el aparato se estira entre el gáster y el aguijón clavado hasta desgarrarse
	var fil: float = p.filament
	if fil > 0.0 and p.show_insect:
		var a: Vector2 = (p.base as Vector2)
		var b := gaster
		var n := (b - a).orthogonal().normalized() if a.distance_to(b) > 0.01 else Vector2.RIGHT
		var w0: float = float(p.width) * 0.9
		var w1: float = float(p.width) * (1.0 - 0.6 * fil)
		draw_colored_polygon(PackedVector2Array([(a - n * w0) * s, (a + n * w0) * s, (b + n * w1) * s, (b - n * w1) * s]),
			Color("#B85A58").lerp(col, 0.35))
	if not p.show_insect:
		return
	# 6 · alas (translúcidas y en dos posiciones al aletear; plegadas en reposo) y cuerpo
	var rot := PI / 2.0 - float(m.stingAngle) + float(p.tilt)
	var xf_body := Transform2D(rot, Vector2(s, s), 0.0, gaster * s)
	if wings != null and m.has("wing"):
		var w := Vector2(float(m.wing.x), float(m.wing.y))
		var flying: float = p.flying
		if flying > 0.0:
			var amp := 0.55 * flying
			var jitter := 0.08 * sin(_ins_ms * 0.9)
			for ang: float in [-amp + jitter, amp * 0.35 - jitter]:
				draw_set_transform_matrix(xf_body * Transform2D(ang, Vector2.ONE, 0.0, w) * Transform2D(0.0, Vector2.ONE, 0.0, -w))
				draw_texture_rect(wings, body_view, false, Color(1, 1, 1, 0.42))
		else:
			draw_set_transform_matrix(xf_body)
			draw_texture_rect(wings, body_view, false)
	draw_set_transform_matrix(xf_body)
	draw_texture_rect(body, body_view, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
