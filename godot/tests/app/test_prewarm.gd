## Precarga de las losas del banco (bench.gd → prewarm): se construyen y rasterizan en hilos de WorkerThreadPool sin
## bloquear el hilo principal, y al cambiar de material su losa ya está (antes se veía la anterior unos 170 ms). Con
## fotogramas de verdad (el test es una corrutina) y midiendo los tiempos.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const Catalog = preload("res://core/lab/catalog.gd")


func _section(prewarm: bool) -> Control:
	var host := Control.new()
	host.size = Vector2(1240, 880)
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	if not prewarm:
		s.result_card.bench.prewarm([])
	return s


## Fotogramas y ms hasta que el banco pinta la losa de ese material (y no la anterior).
func _time_to_slab(s: Control, id: String) -> Array:
	var bench: Control = s.result_card.bench
	s.lab.set_target(Catalog.find_by_id(Catalog.TARGETS, id))
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while frames < 600:
		await wait_frames(1)
		frames += 1
		if bench._tex.get("base", [""])[0] == "bench:" + id:
			break
	return [frames, (Time.get_ticks_usec() - t0) / 1000.0]


func test_las_losas_se_precargan_en_hilos_sin_bloquear() -> void:
	var s := _section(true)
	var bench: Control = s.result_card.bench
	var ok := await wait_until(func() -> bool: return bench.is_warm(), 1800)
	assert_true(ok, "todas las losas del banco en la caché")
	var warm_ms: float = (bench.warm_done_us - bench.warm_started_us) / 1000.0
	assert_true(bench.warm_submit_max_us < 20000, "el hilo principal solo encarga las tareas (%d µs como mucho por fotograma)" % bench.warm_submit_max_us)
	# con todo precargado, cada material se ve en el primer fotograma
	var worst := 0
	for t: Dictionary in Catalog.TARGETS:
		var r: Array = await _time_to_slab(s, t.id)
		worst = maxi(worst, r[0])
		assert_eq(r[0], 1, "%s: su losa en el primer fotograma (%d)" % [t.id, r[0]])
	print("    (info) precarga: %d losas en %s ms en hilos de WorkerThreadPool (%d núcleos); el hilo principal, %s ms como mucho por fotograma" % [
		Catalog.TARGETS.size(), _Js.to_fixed(warm_ms, 0), OS.get_processor_count(), _Js.to_fixed(bench.warm_submit_max_us / 1000.0, 2)])


func test_sin_precarga_se_ve_la_losa_anterior() -> void:
	# la medida del problema que arregla la precarga: el cuarzo, la losa que más tarda
	var s := _section(false)
	await wait_frames(3)
	var r: Array = await _time_to_slab(s, "cuarzo")
	assert_true(r[0] >= 2, "sin precarga, la losa del cuarzo llega en un fotograma posterior (%d)" % r[0])
	print("    (info) sin precarga, la losa del cuarzo tarda %d fotogramas (%s ms) en verse" % [r[0], _Js.to_fixed(r[1], 0)])
