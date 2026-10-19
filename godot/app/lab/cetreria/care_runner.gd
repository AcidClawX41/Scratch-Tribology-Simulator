## Cetrería · lleva el estado de la página (core/lab/claw_care_state.gd) en un hilo aparte con doble búfer, como el de la
## afiladora (app/taller/ui/sharpen_runner.gd), para que la interfaz nunca espere a la física (CONTRATOS.md →
## «Rendimiento y multinúcleo»): un tramo de lima o un toque del torno cuestan 1-3 ms en escritorio y bastante más en un
## teléfono.
## - El hilo de la interfaz solo manda órdenes (post: un método de ClawCareState con sus argumentos, en orden) y el tiempo
##   de cada fotograma (una orden «tick» más). El hilo las aplica en el orden en que llegan y publica una vista nueva
##   (ClawCareState.view()) con las mallas de la garra hechas en arrays (claw_mesh.gd) solo si ha cambiado su forma, y la
##   textura de su superficie (surface_img: ClawMaterial.surface_image con la lista del motor) solo si ha cambiado.
## - latest() devuelve la última vista publicada: un diccionario que el hilo ya no vuelve a tocar (el cerrojo solo
##   protege el cambio de búfer).
## - Sin hilo (tests sin ventana, o antes de start_thread), lo mismo, pero al momento y en el hilo que llama.
## No toca nodos. El dueño llama a stop_thread() antes de soltarlo: el hilo tiene cogido este objeto.
extends RefCounted

const State = preload("res://core/lab/claw_care_state.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const SharpenHelp = preload("res://core/lab/claw_care_sharpen_help.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")

## Órdenes que se pueden mandar: los métodos de ClawCareState que cambian algo.
const OPS := [
	"configure", "restart", "recapture", "set_animal", "set_claw", "set_inlay", "set_overgrowth_days", "set_tip_start", "set_sedation", "set_humidity",
	"pick", "drop", "set_force", "nudge_force", "wheel_force", "set_angle", "nudge_angle", "set_rotary", "toggle_rotary",
	"set_rpm_index", "cycle_rpm", "set_paused", "toggle_pause", "press_on", "drag", "release", "tick", "finish", "resume",
	"set_tutorial", "set_guide", "tutorial_next", "tutorial_prev", "tutorial_goto", "set_time_scale", "dismiss_mistake",
	"select_claw", "set_paw", "set_digit", "cycle_paw", "cycle_digit", "set_model", "probe_tip", "reforge_with",
	# unidad 5l: una herramienta nueva de la bandeja
	"renew_tool",
	# la pausa para calmarlo (petición de Eric del 17-10)
	"rest",
	# unidad 5o: colocar a mano la pieza de la reforja
	"receive_piece", "bond_method", "bond_adhesive", "bond_clean", "bond_purge", "bond_apply", "bond_grab", "bond_turn",
	"bond_aim", "bond_hold", "bond_move", "bond_wrap", "bond_unwrap", "bond_remove", "bond_mix", "set_layer_kind", "bond_layer",
	"bond_lamp", "bond_eyes", "bond_lamp_on", "bond_scrape", "bond_test", "bond_weld",
	# petición 51: la vista de la cámara que se ve (para los textos del tutorial)
	"note_view",
	# unidad 5t-A: la lente de la cámara (apuntar los rayones de un zarpazo, limpiar las manchas, poner otra lente)
	"lens_record", "lens_clean", "lens_mount", "lens_load",
]
## Tope del tiempo pendiente en una sola orden «tick» (s): si el equipo no da abasto, el ensayo va más despacio en vez
## de acumular trabajo.
const MAX_TICK_S := 0.25

var state: State
## Segmentos de cada anillo de la malla (menos en el teléfono).
var ring := ClawMesh.RING
var _thread: Thread = null
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _cmds: Array = []
var _view: Dictionary = {}
var _mesh: Dictionary = {}
## Las mallas de las demás garras trabajadas (las que no se ven en la malla de la elegida): clave de su forma → arrays.
var _others: Dictionary = {}
## La textura de la superficie de la garra y la huella de lo que la hizo (se rehace solo si cambia).
## La malla de la pieza de la reforja que se coloca a mano (unidad 5o): { key, arrays, kind } (se rehace al cambiar de pieza).
var _bond_mesh_cache: Dictionary = {}
## La ayuda del afilado de la garra elegida (unidad 5s: el medidor, la lupa y el aviso; SharpenHelp.view) y su clave: se rehace
## solo si cambia la punta o la mano.
var _help: Dictionary = {}
var _help_key := ""
## Las formas de partida de las garras que aún no se han tocado (unidad 5s): la de su propia ClawCare (ClawCareState.care_setup:
## su dedo, su pata y su semilla), hecha una vez por ensayo y garra: clave → { s, r }.
var _natural: Dictionary = {}
## (perf) La malla de cada garra que no se trabaja, por ensayo, garra y forma: la de la vista anterior.
var _slot_memo := {}
var _surface_img: Image = null
var _surface_hash := 0
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


## Arranca el hilo (si ya estaba, nada).
func start_thread() -> void:
	if _thread != null:
		return
	_quit = false
	_thread = Thread.new()
	_thread.start(_loop)


## Para el hilo y espera a que acabe. Después, todo va al momento en el hilo que llama.
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
		push_error("CareRunner: orden desconocida «%s»" % op)
		return
	if op == "tick" and not args.is_empty():
		args = [minf(float(args[0]), MAX_TICK_S)]
	_mutex.lock()
	_cmds.append([op, args])
	_posted += 1
	_mutex.unlock()
	_kick()


## ¿Ha visto ya la vista publicada todas las órdenes mandadas?
func in_sync() -> bool:
	_mutex.lock()
	var ok := _seen == _posted
	_mutex.unlock()
	return ok


## La última vista publicada.
func latest() -> Dictionary:
	_mutex.lock()
	var v := _view
	_mutex.unlock()
	return v


## Coste del último trabajo del hilo (ms): aplicar las órdenes, la vista y, si hacía falta, las mallas.
func work_ms() -> float:
	_mutex.lock()
	var us := _work_us
	_mutex.unlock()
	return float(us) / 1000.0


## Vistas publicadas (para esperar en los tests).
func published() -> int:
	_mutex.lock()
	var n := _published
	_mutex.unlock()
	return n


## Sin hilo: trabaja ya. Con hilo: lo despierta (una vez aunque lleguen varias órdenes seguidas).
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


## Aplica las órdenes y publica la vista (en el hilo del estado, o en el que llama).
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


## Vista nueva (y las mallas, si ha cambiado la forma de la garra).
func _publish() -> void:
	_serial = state.serial()
	var v := state.view()
	v["tip_help"] = _tip_help(v)
	var key := ClawMesh.geometry_key(v)
	if _mesh.is_empty() or String(_mesh.key) != key or int(_mesh.ring) != ring:
		_mesh = ClawMesh.claw_arrays(v, ring)
	v["mesh"] = _mesh
	v["others_mesh"] = _others_mesh(v)
	v["bond_mesh"] = _bond_mesh(v)
	v["surface_img"] = _surface_image(v)
	_mutex.lock()
	_view = v
	_published += 1
	_mutex.unlock()


## La ayuda del afilado (unidad 5s): el medidor de la punta, la lupa y el aviso, del motor y de la mano (SharpenHelp), solo
## cuando cambian la punta o la mano.
func _tip_help(v: Dictionary) -> Dictionary:
	if state.care == null:
		return {}
	var hand: Dictionary = v.get("hand", {})
	var k := SharpenHelp.key_of(state.care, hand) + "|" + str(int(v.snap.damage.get("breaks", []).size()))
	if k != _help_key:
		_help_key = k
		_help = SharpenHelp.view(state.care, hand, v.snap)
	return _help


## La textura de la superficie de la garra (la petición 37: la biblioteca de materiales la codifica con
## ClawMaterial.surface_image a partir de la lista del motor, ClawCare.surface_stations), hecha en este hilo y solo cuando
## cambia la superficie (la instantánea cambia en cada tic; la superficie, al limar o al calentar). null si el motor no
## la da. La imagen no se vuelve a tocar: si cambia, es otra.
func _surface_image(v: Dictionary) -> Image:
	var surf: Variant = v.snap.get("surface")
	if not (surf is Dictionary) or state.care == null or not state.care.has_method("surface_stations"):
		_surface_hash = 0
		_surface_img = null
		return null
	var h := hash(surf)
	if h != _surface_hash or _surface_img == null:
		_surface_hash = h
		_surface_img = ClawMaterial.surface_image(state.care.surface_stations())
	return _surface_img


## Las mallas de las garras trabajadas que no son la elegida, cada una con su perfil y la forma de su dedo
## (ClawCareState.slots_view: su arco y su sección; lo pidió la 5k, unidad 5o), no con la de la elegida. Hechas una vez por
## forma: { "pata|dedo": { key, arrays } }.
func _others_mesh(v: Dictionary) -> Dictionary:
	var out := {}
	var keep := {}
	var nat0 := maxf(float((v.snap.claw as Dictionary).get("naturalMm", 1.0)), 1e-6)
	var st: Dictionary = v.setup
	var sk := "%s|%s|%s|%s|%s|%s" % [String(st.get("seed", "")), String(st.get("claw", "")), String(st.get("inlay", "")),
		var_to_str(float(st.get("overgrowth_days", 0.0))), String(st.get("tip_start", "natural")), str(ring)]
	var memo := {}
	for e: Dictionary in v.get("slots", []):
		if bool(e.selected):
			continue
		# (perf, cierre de la 5s) la misma garra con la misma forma que en la vista anterior: lo de entonces, sin rehacer su
		# perfil ni su clave (con 19 garras, rehacerlo en cada vista costaba más que la garra que se trabaja)
		var mk := "%s|%s|%s|%s|%s" % [sk, String(e.key), String(e.key_geom), str(bool(e.worked)), str(bool(e.get("broken", false)))]
		if _slot_memo.has(mk):
			var hit: Dictionary = _slot_memo[mk]
			memo[mk] = hit
			keep[String(hit.key)] = true
			out[String(e.key)] = hit
			continue
		var k := ClawMesh.claw_curvature({ "naturalMm": float(e.get("naturalMm", nat0)), "arcDeg": e.get("arcDeg"), "curve": float(e.get("curve", 0.5)) })
		var sec := ClawMesh.section_of({ "snap": { "animal_id": String(v.snap.animal_id),
			"claw": { "sectionRatio": e.get("sectionRatio"), "ventralFlat": bool(e.get("ventralFlat", false)) } } })
		var prof: Dictionary = e.profile
		if prof.is_empty():
			# sin tocar (unidad 5s): la forma de partida de su propia ClawCare (su dedo, su pata y su semilla), no la de la elegida
			prof = _natural_profile(String(e.paw), String(e.digit))
			# y, en el oso y el tigre (sin medición dedo a dedo), con su forma de dibujo (CarePaw.claw_shape_drawing, estimación)
			var dv := CarePaw.claw_shape_drawing(String(v.setup.claw), String(e.key))
			if not prof.is_empty() and (float(dv.length) != 1.0 or float(dv.arc) != 1.0):
				var s2 := PackedFloat64Array(prof.s)
				for i in s2.size():
					s2[i] *= float(dv.length)
				prof = { "s": s2, "r": prof.r }
				k *= float(dv.arc) / float(dv.length)
		if prof.is_empty():
			continue
		var ps0: PackedFloat64Array = prof.s
		var gk := "%s|%s|%s|%s|%s|%s|%s" % [String(v.setup.seed), String(e.key), String(e.key_geom), str(ring), var_to_str(k), var_to_str(sec),
			var_to_str(ps0[ps0.size() - 1] if ps0.size() > 0 else 0.0)]
		if not _others.has(gk):
			_others[gk] = ClawMesh.tube_arrays(prof.s, prof.r, k, ring, 0.0, sec)
		keep[gk] = true
		var ps: PackedFloat64Array = prof.s
		out[String(e.key)] = { "key": gk, "arrays": _others[gk], "lengthMm": ps[ps.size() - 1] if ps.size() > 0 else 0.0 }
		memo[mk] = out[String(e.key)]
	_slot_memo = memo
	for gk: String in _others.keys():
		if not keep.has(gk):
			_others.erase(gk)
	return out


## La forma de partida de una garra sin tocar: el perfil de la ClawCare que tendría al elegirla (ClawCareState.care_setup), hecha
## una vez por ensayo, garra y largo de partida (sin crearla en el estado: no cambia el ensayo).
func _natural_profile(p: String, d: String) -> Dictionary:
	var cs: Dictionary = state.care_setup(p, d)
	var nk := "%s|%s|%s|%s|%s|%s|%s|%s" % [String(cs.get("seed", "")), String(cs.get("claw", "")), String(cs.get("inlay", "")), p, d,
		var_to_str(float(cs.get("overgrowth_days", 0.0))), var_to_str(cs.get("block", null)), String(cs.get("tip_start", "natural"))]
	if not _natural.has(nk):
		if _natural.size() > 64:
			_natural.clear()
		var sn: Dictionary = ClawCare.new(cs).snapshot()
		_natural[nk] = { "s": sn.profile.s, "r": sn.profile.r }
	return _natural[nk]


## La pieza rígida de la reforja que aún no está unida (unidad 5o: la funda o el bloque, ClawCareState.bond_view), en mm y en
## el sitio de la garra donde va (la curva de la garra): la funda, la forma sana desde su borde con su pared por fuera y un
## tapón delante de la punta; el bloque, un cilindro de su radio en bruto desde el muñón. {} si no hay pieza que coger (el
## acrílico y la resina se hacen sobre la garra).
func _bond_mesh(v: Dictionary) -> Dictionary:
	var bv: Dictionary = v.get("bond", {})
	if bv.is_empty() or bool(bv.attached) or String(bv.method) != "adhesivo":
		return {}
	var k := ClawMesh.claw_curvature(v.snap.claw)
	var key := "%s|%s|%s|%s|%s|%s" % [String(bv.kind), String(bv.material), var_to_str(float(bv.jointMm)), var_to_str(float(bv.needMm)), var_to_str(k), str(ring)]
	if String(_bond_mesh_cache.get("key", "")) == key:
		return _bond_mesh_cache
	var ss := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var j := float(bv.jointMm)
	var wall := float(bv.wallMm)
	if String(bv.kind) == "funda":
		var nat := ClawMesh.natural_profile(v)
		if not nat.has("s"):
			return {}
		var ns: PackedFloat64Array = nat.s
		var nr: PackedFloat64Array = nat.r
		ss.append(j)
		rs.append(ClawMesh.radius_at(ns, nr, j) + wall)
		for i in mini(ns.size(), nr.size()):
			if ns[i] > j:
				ss.append(ns[i])
				rs.append(nr[i] + wall)
		var end := ss[ss.size() - 1]
		ss.append(end + wall)
		rs.append(0.0)
	else:
		var r := float(bv.stumpRadiusMm) + wall
		ss.append_array([j, j + float(bv.needMm) - 0.01, j + float(bv.needMm)])
		rs.append_array([r, r, 0.0])
	_bond_mesh_cache = { "key": key, "kind": String(bv.kind), "arrays": ClawMesh.tube_arrays(ss, rs, k, ring, 0.0, ClawMesh.section_of(v)),
		"jointMm": j, "lengthMm": ss[ss.size() - 1] - j }
	return _bond_mesh_cache
