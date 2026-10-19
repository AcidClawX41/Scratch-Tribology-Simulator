## Laboratorio experimental de la reforja · lleva el estado (core/lab/claw_forge_state.gd) en un hilo aparte con doble
## búfer, como el de la cetrería (care_runner.gd): la interfaz nunca espera a la física (CONTRATOS.md → «Rendimiento y
## multinúcleo»). Lo caro va aquí: recubrir la garra viva (ClawForge.coat integra hasta 4000 pasos por vía, unas decenas
## de milisegundos), la vista (~1 ms) y las mallas de la garra y de la funda (claw_mesh.gd, solo cuando cambia su forma).
## - El hilo de la interfaz solo manda órdenes (post: un método de ClawForgeState con sus argumentos, en orden) y el tiempo
##   de cada fotograma (una orden «tick» más). El hilo las aplica en el orden en que llegan y publica una vista nueva
##   (ClawForgeState.view()) si algo ha cambiado.
## - latest() devuelve la última vista publicada: un diccionario que el hilo ya no vuelve a tocar.
## - Sin hilo (tests sin ventana, la demo), lo mismo, pero al momento y en el hilo que llama.
## No toca nodos. El dueño llama a stop_thread() antes de soltarlo.
extends RefCounted

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")

## Órdenes que se pueden mandar: los métodos de ClawForgeState que cambian algo.
const OPS := [
	"open", "set_process", "choose_process", "set_shape", "set_wall", "set_stone", "restart", "pick_jar", "drop_jar", "set_pouring",
	"add_powder", "clear_pan", "tare", "load_crucible", "choose_stone", "select_control", "cycle_control", "turn_control",
	"set_control", "start", "skip", "cool_piece", "carve", "protect", "coat", "bond", "polish", "check", "set_carve",
	"set_barrier", "set_coat", "set_bond", "set_polish", "set_load", "apply_recommended", "do_step", "set_tutorial",
	"tutorial_goto", "tutorial_next", "tutorial_prev", "dismiss_mistake", "tick",
	# 5m · la carga en su máquina, la velocidad, la cera perdida, el tallado por pasadas y la prueba del ajuste
	"insert_charge", "set_speed", "cycle_speed", "make_wax", "invest", "divest", "set_compensate", "lost_wax_next",
	"set_carve_tool", "cycle_carve_tool", "carve_pass", "carve_to", "fit_test",
	# 5r · la mesa de soldar: los mandos, colocar y alinear las piezas, el haz y el pedal, un pulso o la vuelta entera
	"set_weld", "set_weld_params", "cycle_weld_method", "weld_prepare", "weld_align_pieces", "weld_nudge", "weld_aim",
	"weld_set_hold", "weld_pulse_next", "weld_all",
]
## Tope del tiempo pendiente en una sola orden «tick» (s).
const MAX_TICK_S := 0.25
## Estaciones de la funda a lo largo de la garra (dibujo).
const SHEATH_STATIONS := 48

var state: State
## Segmentos de cada anillo de las mallas (menos en el teléfono).
var ring := ClawMesh.RING
var _thread: Thread = null
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _cmds: Array = []
var _view: Dictionary = {}
var _claw_mesh: Dictionary = {}
var _sheath_mesh: Dictionary = {}
var _weld_mesh: Dictionary = {}
var _quit := false
var _wake := false
var _work_us := 0
var _published := 0
var _posted := 0
var _taken := 0
var _seen := 0
var _serial := -1


func _init(setup: Dictionary = {}) -> void:
	state = State.new(setup)
	_publish()


func start_thread() -> void:
	if _thread != null:
		return
	_quit = false
	_thread = Thread.new()
	_thread.start(_loop)


func stop_thread() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_quit = true
	_mutex.unlock()
	_sem.post()
	_thread.wait_to_finish()
	_thread = null


func is_threaded() -> bool:
	return _thread != null


## Orden para el estado: un método de OPS con sus argumentos.
func post(op: String, args: Array = []) -> void:
	if not OPS.has(op):
		push_error("ForgeRunner: orden desconocida «%s»" % op)
		return
	if op == "tick" and not args.is_empty():
		args = [minf(float(args[0]), MAX_TICK_S)]
	_mutex.lock()
	_cmds.append([op, args])
	_posted += 1
	_mutex.unlock()
	_kick()


func in_sync() -> bool:
	_mutex.lock()
	var ok := _seen == _posted
	_mutex.unlock()
	return ok


func latest() -> Dictionary:
	_mutex.lock()
	var v := _view
	_mutex.unlock()
	return v


func work_ms() -> float:
	_mutex.lock()
	var us := _work_us
	_mutex.unlock()
	return float(us) / 1000.0


func published() -> int:
	_mutex.lock()
	var n := _published
	_mutex.unlock()
	return n


func _kick() -> void:
	if _thread == null:
		_work()
		return
	_mutex.lock()
	var was := _wake
	_wake = true
	_mutex.unlock()
	if not was:
		_sem.post()


func _loop() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		var quit := _quit
		_wake = false
		_mutex.unlock()
		if quit:
			return
		_work()


func _work() -> void:
	_mutex.lock()
	var cmds := _cmds
	_cmds = []
	_taken += cmds.size()
	var seen := _taken
	_mutex.unlock()
	var t0 := Time.get_ticks_usec()
	for c: Array in cmds:
		state.callv(String(c[0]), c[1])
	if state.serial() != _serial:
		_publish()
	var us := Time.get_ticks_usec() - t0
	_mutex.lock()
	_seen = seen
	_work_us = us
	_mutex.unlock()


## Vista nueva, con las mallas de la garra y de la funda (hechas otra vez solo si ha cambiado su forma).
func _publish() -> void:
	_serial = state.serial()
	var v := state.view()
	var prof: Dictionary = v.profile
	var k := ClawMesh.curvature(float(prof.natural_mm), float(prof.curve))
	var ckey := "%s|%s|%s|%d" % [var_to_str(prof.s), var_to_str(prof.r), var_to_str(k), ring]
	if _claw_mesh.is_empty() or String(_claw_mesh.key) != ckey:
		_claw_mesh = { "key": ckey, "k": k, "arrays": ClawMesh.tube_arrays(prof.s, prof.r, k, ring, 0.0),
			"quick": ClawMesh.tube_arrays(prof.s, prof.core, k, ring, 1.0) if prof.has("core") else [] }
	var sh: Dictionary = v.sheath
	var nat: PackedFloat64Array = prof.get("nat_s", prof.s)
	var skey := "%s|%s|%s|%s" % [ckey, var_to_str(float(sh.cover_mm)), var_to_str(float(sh.wall_mm)), var_to_str(nat[nat.size() - 1])]
	if _sheath_mesh.is_empty() or String(_sheath_mesh.key) != skey:
		_sheath_mesh = { "key": skey, "k": k, "arrays": sheath_arrays(prof, k, float(sh.cover_mm), float(sh.wall_mm), ring) }
	v["claw_mesh"] = _claw_mesh
	v["sheath_mesh"] = _sheath_mesh
	# 5r · en la mesa de soldar, la funda partida por la costura: la base y la punta (cada una su malla), solo con una forma nueva
	var wv: Dictionary = v.get("weld", {})
	var geo: Dictionary = wv.get("geometry", {})
	if bool(wv.get("on", false)) and not geo.is_empty():
		var wkey := "%s|%s" % [skey, var_to_str(float(geo.sMm))]
		if _weld_mesh.is_empty() or String(_weld_mesh.key) != wkey:
			var parts := split_sheath_arrays(prof, k, float(sh.cover_mm), float(sh.wall_mm), float(geo.sMm), ring)
			_weld_mesh = { "key": wkey, "k": k, "base": parts.base, "tip": parts.tip, "s_mm": float(geo.sMm), "r_mm": float(geo.radiusMm) }
		v["weld_mesh"] = _weld_mesh
	else:
		v["weld_mesh"] = {}
	_mutex.lock()
	_view = v
	_published += 1
	_mutex.unlock()


## La funda en 3D (dibujo, en mm y en el marco de la garra de claw_mesh.gd): un tubo que sigue la garra sana (nat_s y nat_r;
## en una garra rota, la prótesis rehace lo que falta hasta la punta natural) en los últimos cover_mm desde la punta con
## wall_mm de pared, y un casquete redondeado de wall_mm delante de la punta (como el tapón macizo de
## ClawForge.sheath_geometry).
static func sheath_arrays(prof: Dictionary, k: float, cover_mm: float, wall_mm: float, ring: int) -> Array:
	var ss: PackedFloat64Array = prof.get("nat_s", prof.s)
	var rs: PackedFloat64Array = prof.get("nat_r", prof.r)
	var apex := ss[ss.size() - 1]
	var s0 := maxf(apex - cover_mm, 0.0)
	var out_s := PackedFloat64Array()
	var out_r := PackedFloat64Array()
	for i in SHEATH_STATIONS:
		var s := s0 + (apex - s0) * float(i) / float(SHEATH_STATIONS - 1)
		out_s.append(s)
		out_r.append(ClawMesh.radius_at(ss, rs, s) + wall_mm)
	# el casquete: un cuarto de círculo del radio del borde de la punta
	var r_tip := out_r[out_r.size() - 1]
	for j in range(1, 7):
		var a := float(j) / 6.0 * PI * 0.5
		out_s.append(apex + wall_mm * sin(a))
		out_r.append(maxf(r_tip * cos(a), 0.0))
	return ClawMesh.tube_arrays(out_s, out_r, k, ring, 0.0)


## La funda partida en dos por la costura de la soldadura (5r; dibujo): la base, de donde empieza la funda hasta la estación
## s_cut, y la punta, de s_cut al casquete. Las mismas estaciones que sheath_arrays. { base, tip } (arrays de ClawMesh).
static func split_sheath_arrays(prof: Dictionary, k: float, cover_mm: float, wall_mm: float, s_cut: float, ring: int) -> Dictionary:
	var ss: PackedFloat64Array = prof.get("nat_s", prof.s)
	var rs: PackedFloat64Array = prof.get("nat_r", prof.r)
	var apex := ss[ss.size() - 1]
	var s0 := maxf(apex - cover_mm, 0.0)
	var cut := clampf(s_cut, s0 + 0.01, apex - 0.01)
	var base_s := PackedFloat64Array()
	var base_r := PackedFloat64Array()
	var n_base := maxi(int(round(float(SHEATH_STATIONS) * (cut - s0) / maxf(apex - s0, 1e-6))), 2)
	for i in n_base:
		var s := s0 + (cut - s0) * float(i) / float(n_base - 1)
		base_s.append(s)
		base_r.append(ClawMesh.radius_at(ss, rs, s) + wall_mm)
	var tip_s := PackedFloat64Array()
	var tip_r := PackedFloat64Array()
	var n_tip := maxi(SHEATH_STATIONS - n_base, 2)
	for i in n_tip:
		var s := cut + (apex - cut) * float(i) / float(n_tip - 1)
		tip_s.append(s)
		tip_r.append(ClawMesh.radius_at(ss, rs, s) + wall_mm)
	var r_tip := tip_r[tip_r.size() - 1]
	for j in range(1, 7):
		var a := float(j) / 6.0 * PI * 0.5
		tip_s.append(apex + wall_mm * sin(a))
		tip_r.append(maxf(r_tip * cos(a), 0.0))
	return { "base": ClawMesh.tube_arrays(base_s, base_r, k, ring, 0.0), "tip": ClawMesh.tube_arrays(tip_s, tip_r, k, ring, 0.0) }
