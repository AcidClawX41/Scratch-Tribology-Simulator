## Taller industrial · afiladora: lleva el simulador (core/taller/sharpening_sim.gd) en un hilo aparte con doble búfer,
## para que la interfaz nunca espere a la física (CONTRATOS.md → «Rendimiento y multinúcleo»).
## - El hilo de la interfaz solo manda órdenes (post) y pide tiempo de proceso (request). El hilo del simulador las
##   aplica en el orden en que llegan, avanza (repartiendo las secciones del filo en WorkerThreadPool, con prioridad
##   alta) y publica una instantánea nueva.
## - latest() devuelve la última instantánea publicada: un diccionario que el simulador ya no vuelve a tocar, así que se
##   puede leer sin cerrojo una vez cogido (el cerrojo solo protege el cambio de búfer).
## - Sin hilo (tests sin ventana, o antes de start_thread), lo mismo, pero al momento y en el hilo que llama.
## No toca nodos. El sonido (MachineSound.frame, con cachés estáticas) lo calcula el reproductor en el hilo principal.
## El dueño llama a stop_thread() antes de soltarlo: el hilo tiene cogido este objeto.
extends RefCounted

const SharpeningSim = preload("res://core/taller/sharpening_sim.gd")

## Tope del tiempo de proceso pendiente (s): si el equipo no da abasto, la simulación va más despacio en vez de
## acumular trabajo (lo que se descarta se cuenta en dropped_s).
const MAX_PENDING_S := 1.0

var _sim: SharpeningSim
var _thread: Thread = null
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _cmds: Array = []
var _pending := 0.0
var _dropped := 0.0
var _snap: Dictionary = {}
var _quit := false
var _wake := false
var _work_us := 0
var _published := 0
var _posted := 0  # órdenes mandadas
var _taken := 0  # órdenes que ya ha cogido el simulador
var _snap_seen := 0  # órdenes que ha visto la instantánea publicada


func _init(setup: Dictionary = {}) -> void:
	_sim = SharpeningSim.new(setup)
	_snap = _sim.snapshot()


## Arranca el hilo del simulador (si ya estaba, nada).
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


## Orden para el simulador: "configure" (diccionario de ajustes), "start", "pause" (true/false), "stop" o "reset".
func post(op: String, arg: Variant = null) -> void:
	_mutex.lock()
	_cmds.append([op, arg])
	_posted += 1
	_mutex.unlock()
	_kick()


## La última instantánea ya ha visto todas las órdenes mandadas (con hilo, las de este fotograma llegan en el
## siguiente): la página solo rellena sus controles con una instantánea al día, para que un deslizador no salte atrás.
func in_sync() -> bool:
	_mutex.lock()
	var ok := _snap_seen == _posted
	_mutex.unlock()
	return ok


## Pide sim_s segundos de proceso (se suman a lo que quede pendiente, con el tope MAX_PENDING_S).
func request(sim_s: float) -> void:
	if not (sim_s > 0.0) or not is_finite(sim_s):
		return
	_mutex.lock()
	var total := _pending + sim_s
	_pending = minf(total, MAX_PENDING_S)
	_dropped += total - _pending
	_mutex.unlock()
	_kick()


## La última instantánea publicada.
func latest() -> Dictionary:
	_mutex.lock()
	var s := _snap
	_mutex.unlock()
	return s


## Coste del último trabajo del simulador (ms): avanzar y hacer la instantánea.
func work_ms() -> float:
	_mutex.lock()
	var us := _work_us
	_mutex.unlock()
	return float(us) / 1000.0


## Tiempo de proceso descartado porque el equipo no daba abasto (s).
func dropped_s() -> float:
	_mutex.lock()
	var d := _dropped
	_mutex.unlock()
	return d


## Instantáneas publicadas (para esperar en los tests).
func published() -> int:
	_mutex.lock()
	var n := _published
	_mutex.unlock()
	return n


## Sin hilo: trabaja ya. Con hilo: lo despierta (una sola vez aunque lleguen varias órdenes seguidas).
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


## Aplica las órdenes, avanza lo pendiente y publica la instantánea (en el hilo del simulador, o en el que llama).
func _work() -> void:
	_mutex.lock()
	var cmds := _cmds
	_cmds = []
	_taken += cmds.size()
	var seen := _taken
	var t := _pending
	_pending = 0.0
	_mutex.unlock()
	var t0 := Time.get_ticks_usec()
	for c: Array in cmds:
		match str(c[0]):
			"configure":
				_sim.configure(c[1])
			"start":
				_sim.start()
			"pause":
				_sim.pause(bool(c[1]))
			"stop":
				_sim.stop()
			"reset":
				_sim.reset_blade()
	if t > 0.0:
		_sim.advance(t)
	var snap := _sim.snapshot()
	var us := Time.get_ticks_usec() - t0
	_mutex.lock()
	_snap = snap
	_snap_seen = seen
	_work_us = us
	_published += 1
	_mutex.unlock()
