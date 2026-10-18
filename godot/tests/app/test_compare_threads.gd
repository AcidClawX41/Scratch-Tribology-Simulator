## La comparativa del banco en hilos no deja nada con estado en manos de un hilo de trabajo.
## El fallo (signal 11 en un hilo de la comparativa, con «caller thread can't call propagate_notification() on /root»,
## que es el aviso del manejador de fallos de Godot al avisar al árbol desde ese hilo): la tarea de cada fila era una
## lambda que capturaba el estado del banco (LabState: con la señal `changed` conectada a la sección y Callables de la
## interfaz). WorkerThreadPool suelta cada tarea en el hilo que la ha corrido y después de despertar a quien la espera,
## así que, si el hilo principal ya había soltado sus referencias (la sección se libera, el banco cambia de estado), la
## última referencia del estado se iba con la tarea y el estado se destruía en el hilo de trabajo: desconectaba sus
## señales de una sección que el hilo principal estaba liberando a la vez. Ahora los hilos solo reciben un Callable de
## método (una referencia débil, un ObjectID) y la tanda con el estado la suelta el hilo principal después de esperarla.
## La prueba lo reproduce como al arrancar: una comparativa nueva con su estado, sus primeras filas en hilos y el hilo
## principal que suelta el estado mientras se calculan. Sin el arreglo, el estado moría en un hilo de trabajo en casi
## todas las vueltas; con él, en ninguna. Se repite con la CPU libre y con la CPU sobrecargada (hilos que giran), que
## cambia el reparto de las tareas entre hilos.
extends "res://tests/case.gd"

const CompareCard = preload("res://app/lab/compare_card.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")

const ROUNDS := 24
const CLAWS := ["tigre", "oso", "aguila", "velociraptor", "vibora", "abeja"]


## Estado del banco que apunta en qué hilo muere.
class DeathSpy:
	extends "res://core/lab/lab_state.gd"
	static var _m := Mutex.new()
	static var _deaths := 0
	static var _on_worker := 0

	static func reset() -> void:
		_m.lock()
		_deaths = 0
		_on_worker = 0
		_m.unlock()

	## [muertes, muertes en un hilo que no es el principal]
	static func counts() -> Array:
		_m.lock()
		var out := [_deaths, _on_worker]
		_m.unlock()
		return out

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			_m.lock()
			_deaths += 1
			if OS.get_thread_caller_id() != OS.get_main_thread_id():
				_on_worker += 1
			_m.unlock()


var _spinning := false


func _spin() -> void:
	var x := 0.0
	while _spinning:
		x += sin(x)


## Espera (con tope) a que hayan muerto n estados: las tareas que el planificador deja para el final acaban enseguida.
func _wait_deaths(n: int) -> Array:
	var t0 := Time.get_ticks_msec()
	while int(DeathSpy.counts()[0]) < n and Time.get_ticks_msec() - t0 < 3000:
		OS.delay_msec(2)
	return DeathSpy.counts()


## Vueltas de arranque: [vueltas con las filas bien, estados muertos al recoger las filas, muertos, muertos en un hilo]
func _rounds(art: ArtCache) -> Array:
	DeathSpy.reset()
	var rows_ok := 0
	var dead_on_collect := 0
	for i in ROUNDS:
		var lab: LabState = DeathSpy.new()
		lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, CLAWS[i % CLAWS.size()]))
		lab.set_force(20.0 + float(i))
		var card := CompareCard.new()
		card.setup(lab, art)
		card.update_rows()  # las primeras filas, en hilos
		# mientras se calculan, el hilo principal suelta el estado (como si la sección se liberara)
		lab = null
		card.lab = null
		card.finish()
		# la tanda se recoge en el hilo principal: el estado tiene que haber muerto ya, y aquí
		dead_on_collect += 1 if int(DeathSpy.counts()[0]) == i + 1 else 0
		rows_ok += 1 if card.rows.size() > 2 and card.rows.all(func(r: Dictionary) -> bool: return r.res is Dictionary) else 0
		card.free()
		_wait_deaths(i + 1)
	var c := _wait_deaths(ROUNDS)
	return [rows_ok, dead_on_collect, c[0], c[1]]


func test_el_estado_del_banco_muere_en_el_hilo_principal() -> void:
	var art := ArtCache.new()
	art.threaded = false
	var probe := CompareCard.new()
	assert_true(probe.threaded, "la comparativa calcula en hilos")
	probe.free()
	for loaded: bool in [false, true]:
		var spin: Array[Thread] = []
		_spinning = loaded
		if loaded:
			for i in OS.get_processor_count() * 2:
				var th := Thread.new()
				th.start(_spin)
				spin.append(th)
		var r := _rounds(art)
		_spinning = false
		for th in spin:
			th.wait_to_finish()
		var tag := "CPU sobrecargada" if loaded else "CPU libre"
		assert_eq(r[0], ROUNDS, "%s: cada vuelta, las filas de la comparativa" % tag)
		assert_eq(r[2], ROUNDS, "%s: todos los estados del banco se destruyen" % tag)
		assert_eq(r[3], 0, "%s: ninguno en un hilo de trabajo (%d de %d)" % [tag, r[3], r[2]])
		assert_eq(r[1], ROUNDS, "%s: cada estado muere al recoger sus filas, en el hilo principal" % tag)
