## Banco de pruebas de rendimiento, sin ventana. Mide las tareas calientes del motor con 1 hilo y con N hilos y
## guarda un JSON que se puede repetir y comparar entre equipos: CPU, núcleos, versión de Godot, tiempos por tarea
## (mediana de varias repeticiones), aceleración con cada número de hilos y si el resultado en paralelo es idéntico
## al secuencial (CONTRATOS.md → «Rendimiento y multinúcleo»).
##
## Uso (desde la raíz del repositorio):
##   npm run godot:bench                                  todo, con los hilos 1, 2, 4… hasta los de la CPU
##   npm run godot:bench -- --quick                       menos repeticiones y barridos más cortos
##   npm run godot:bench -- --threads=1,4,12 --out=x.json  hilos y archivo de salida a elegir
## Por defecto el JSON va a user://bench/bench-<fecha>.json (la carpeta de datos de la app) y la tabla, a la consola.
extends SceneTree

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")
const Gcode = preload("res://core/taller/gcode.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const Drawing = preload("res://core/taller/drawing.gd")
const LatheMesh = preload("res://core/taller/lathe_mesh.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")
const Radial = preload("res://core/taller/radial.gd")
const Panels = preload("res://core/taller/panels.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const SharpeningSim = preload("res://core/taller/sharpening_sim.gd")

const ART_FIXTURE := "res://tests/fixtures/generated/art-svg.json"

var quick := false
var reps := 3
var thread_counts: Array[int] = []
var out_path := ""
var report := {}


func _init() -> void:
	_parse_args()
	var cores := OS.get_processor_count()
	report = {
		"schema": 1,
		"godot": Engine.get_version_info().get("string", ""),
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"logical_cores": cores,
		"worker_pool_max_threads": ProjectSettings.get_setting("threading/worker_pool/max_threads", -1),
		"date": Time.get_datetime_string_from_system(true),
		"quick": quick,
		"repetitions": reps,
		"threads": thread_counts,
		"tasks": {},
	}
	print("Banco de pruebas · %s · %s (%d hilos lógicos) · Godot %s" % [report.os, report.cpu, cores, report.godot])
	print("Hilos: %s · repeticiones: %d%s" % [str(thread_counts), reps, " · rápido" if quick else ""])
	_bench_parallel("lab.compute", "Physics.compute() (barrido de herramientas × objetivos × métodos × fuerzas)", _lab_trials())
	_bench_raster()
	_bench_parallel("taller.radial", "Radial.cut_panel() (discos × chapas × rpm × ángulos)", _radial_jobs())
	_bench_parallel("taller.sharpening", "Sharpening.recommend_sharpening() (herramientas × aceros × máquinas × rpm)", _sharpening_jobs())
	_bench_sharpening_sim()
	_bench_lathe()
	_bench_sound()
	_write()
	quit(0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--quick":
			quick = true
		elif a.begins_with("--threads="):
			for t in a.get_slice("=", 1).split(",", false):
				thread_counts.append(maxi(1, t.to_int()))
		elif a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
		elif a.begins_with("--reps="):
			reps = maxi(1, a.get_slice("=", 1).to_int())
	var reps_given := false
	for a in args:
		reps_given = reps_given or a.begins_with("--reps=")
	if quick and not reps_given:
		reps = 1
	if thread_counts.is_empty():
		var cores := OS.get_processor_count()
		var t := 1
		while t < cores:
			thread_counts.append(t)
			t *= 2
		thread_counts.append(cores)


# ── utilidades ──

## Ejecuta fn(i) para i en [0, n) repartido en `threads` tareas de WorkerThreadPool y devuelve los resultados en
## orden. Con un hilo, un bucle normal (la referencia).
func _run(fn: Callable, n: int, threads: int) -> Array:
	var out: Array = []
	out.resize(n)
	if threads <= 1:
		for i in n:
			out[i] = fn.call(i)
		return out
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var r: Variant = fn.call(i)
		mutex.lock()
		out[i] = r
		mutex.unlock()
	var id := WorkerThreadPool.add_group_task(task, n, threads, true, "banco de pruebas")
	WorkerThreadPool.wait_for_group_task_completion(id)
	return out


## Mediana de `reps` tiempos (ms) de una llamada.
func _time_ms(call: Callable) -> float:
	var times: Array[float] = []
	for r in reps:
		var t0 := Time.get_ticks_usec()
		call.call()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	return times[times.size() / 2]


func _fmt(x: float, d := 1) -> String:
	return String.num(x, d)


## Tarea paralelizable: jobs = { "n": int, "fn": Callable(i) → resultado }. Mide cada número de hilos, comprueba que
## el resultado es idéntico al secuencial y guarda la aceleración.
func _bench_parallel(key: String, what: String, jobs: Dictionary) -> void:
	var n: int = jobs.n
	var fn: Callable = jobs.fn
	if n == 0:
		report.tasks[key] = { "what": what, "skipped": jobs.get("why", "sin trabajo") }
		print("\n%s: se salta (%s)" % [key, jobs.get("why", "sin trabajo")])
		return
	_run(fn, mini(n, 32), 1)  # calentamiento (carga de scripts y cachés de datos)
	var ref := var_to_str(_run(fn, n, 1))
	var rows := {}
	var base_ms := 0.0
	print("\n%s · %s · %d elementos" % [key, what, n])
	for t in thread_counts:
		var holder := [[]]  # las lambdas capturan las variables locales por valor: el resultado va en un contenedor
		var ms := _time_ms(func() -> void: holder[0] = _run(fn, n, t))
		if t == 1:
			base_ms = ms
		var same := var_to_str(holder[0]) == ref
		rows[str(t)] = { "ms": ms, "per_item_us": ms * 1000.0 / n, "speedup": base_ms / ms if ms > 0.0 else 0.0, "identical": same }
		print("  %2d hilos: %8s ms · %7s µs/elemento · ×%s%s" % [t, _fmt(ms), _fmt(ms * 1000.0 / n, 2),
			_fmt(base_ms / ms if ms > 0.0 else 0.0, 2), "" if same else " · ¡DISTINTO del secuencial!"])
	report.tasks[key] = { "what": what, "n": n, "threads": rows }


# ── tareas ──

func _lab_trials() -> Dictionary:
	var trials: Array = []
	var tools: Array = []
	var count := 3 if quick else 6
	for i in count:
		tools.append({ "geom": Data.GEOMS[i % Data.GEOMS.size()], "base": Data.BASES[(i * 3) % Data.BASES.size()], "claw": null })
	for c in Data.CLAWS:
		tools.append({ "geom": Data.GEOMS[0], "base": Data.BASES[0], "claw": c })
	var targets: Array = Data.TARGETS if not quick else Data.TARGETS.slice(0, 8)
	for tool in tools:
		for target in targets:
			for method in ["rayado", "puncion"]:
				for force in [3.0, 30.0]:
					trials.append({
						"geom": tool.geom, "base": tool.base, "inlay": Data.INLAYS[0], "claw": tool.claw,
						"target": target, "type": Data.TYPES[1], "force": force, "length": 25.0, "tear": false,
						"method": method, "strike": false, "passes": 1, "wet": false,
					})
	return { "n": trials.size(), "fn": func(i: int) -> Dictionary: return Physics.compute(trials[i]) }


func _bench_raster() -> void:
	if not FileAccess.file_exists(ART_FIXTURE):
		report.tasks["lab.raster"] = { "skipped": "faltan los datos del oráculo (npm run godot:fixtures)" }
		print("\nlab.raster: se salta (faltan los datos del oráculo: npm run godot:fixtures)")
		return
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(ART_FIXTURE))
	var svgs: Array[String] = []
	var step := 4 if quick else 1
	for i in range(0, rows.size(), step):
		svgs.append(String(rows[i]["svg"]))
	# ThorVG: el rasterizado de cada dibujo del laboratorio (lo que hace la caché de dibujos en hilos).
	_bench_parallel("lab.raster", "SvgTexture.rasterize_image() (dibujos del oráculo con ThorVG)", {
		"n": svgs.size(),
		"fn": func(i: int) -> String:
			var img := SvgTexture.rasterize_image(svgs[i], 1.0)
			return "%dx%d:%d" % [img.get_width(), img.get_height(), hash(img.get_data())] if img != null else "null",
	})


func _radial_jobs() -> Dictionary:
	var jobs: Array = []
	var discs := ["fino_1mm", "grueso_3mm", "diamante", "laminas"]
	var repeat := 2 if quick else 6
	for r in repeat:
		for disc in discs:
			for panel_id in Panels.PANELS:
				for rpm in [6000.0, 11000.0]:
					for angle in [0.0, 30.0]:
						jobs.append({ "disc_id": disc, "diameter_mm": 125.0, "rpm": rpm, "angle_deg": angle,
							"feed_mm_s": 10.0 + r, "panel_id": panel_id, "cut_length_mm": 100.0 })
	return { "n": jobs.size(), "fn": func(i: int) -> Dictionary: return Radial.cut_panel(jobs[i]) }


func _sharpening_jobs() -> Dictionary:
	var jobs: Array = []
	var steels: Array = Sharpening.STEELS.keys()
	var machines: Array = Sharpening.SHARPENING_MACHINES.keys()
	var repeat := 2 if quick else 8
	for r in repeat:
		for kind in ["cuchillo", "broca", "fresa"]:
			for steel in steels:
				for machine in machines:
					for rpm in [100.0, 2980.0, 3450.0]:
						jobs.append({ "tool": { "kind": kind, "steel_id": steel }, "machine_id": machine, "rpm": rpm + r })
	return { "n": jobs.size(), "fn": func(i: int) -> Dictionary: return Sharpening.recommend_sharpening(jobs[i]) }


## Simulador de afilado: un cuchillo de 16 secciones en la Einhell TC-BG 150 a ×1 (1/60 s de proceso por fotograma y
## la instantánea de la interfaz), con cada número de hilos. Las secciones se reparten en WorkerThreadPool con
## prioridad alta; el resultado tiene que ser idéntico al de un hilo.
func _bench_sharpening_sim() -> void:
	var frames := 60 if quick else 300
	var setup := { "machine_id": "einhell_tc_bg_150", "tool": { "kind": "cuchillo" },
		"hand": { "force_n": 15.0, "sweep_mm_s": 20.0, "passes": 4, "rest_s": 0.5 } }
	var rows := {}
	var base_ms := 0.0
	var ref := ""
	print("\ntaller.sharpening_sim · SharpeningSim a ×1: cuchillo de 16 secciones, %d fotogramas de 1/60 s con la instantánea" % frames)
	for t in thread_counts:
		var holder := [""]  # las lambdas capturan las variables locales por valor: el resultado va en un contenedor
		var ms := _time_ms(func() -> void:
			var sim = SharpeningSim.new(setup)
			sim.start()
			for k in frames:
				sim.advance(1.0 / 60.0, t)
				sim.snapshot()
			var s: Dictionary = sim.snapshot()
			holder[0] = var_to_str([s.t_s, s.edge_temp_c, s.removed_mm3, s.peak_edge_c, s.bevel])
		)
		if t == 1:
			base_ms = ms
			ref = holder[0]
		var same: bool = holder[0] == ref
		var per := ms / frames
		rows[str(t)] = { "ms": ms, "per_frame_ms": per, "speedup": base_ms / ms if ms > 0.0 else 0.0, "identical": same }
		print("  %2d hilos: %8s ms por fotograma · ×%s%s" % [t, _fmt(per, 3), _fmt(base_ms / ms if ms > 0.0 else 0.0, 2),
			"" if same else " · ¡DISTINTO del secuencial!"])
	report.tasks["taller.sharpening_sim"] = { "what": "SharpeningSim.advance(1/60 s) + snapshot() a ×1 (cuchillo de 16 secciones)",
		"frames": frames, "threads": rows }


## Torno: el programa Fagor de la pieza A de principio a fin (secuencial por naturaleza) y la malla 3D.
func _bench_lathe() -> void:
	var prog: Dictionary = Programs.EXAMPLE_PROGRAMS["pieza_a"]
	var it := Gcode.interpret_program(prog.text)
	var dt := 0.05
	var run := {}  # contenedor: las lambdas capturan las variables locales por valor
	var ms := _time_ms(func() -> void:
		var lathe = Lathe.new(Lathe.STOCKS["A"], "cnc", Cutting.model_callable())
		lathe.set_tool_table(prog.turret)
		lathe.load_moves(it.moves)
		var k := 0
		while not lathe.is_done() and not lathe.is_halted() and k < 400000:
			lathe.step(dt)
			k += 1
		run.steps = k
		run.profile = lathe.profile()
	)
	var steps: int = run.steps
	var profile: Dictionary = run.profile
	var sim_s := steps * dt
	print("\ntaller.lathe · programa A completo: %d pasos de %s s · %s ms · %s µs/paso · ×%s el tiempo real" % [
		steps, _fmt(dt, 2), _fmt(ms), _fmt(ms * 1000.0 / steps, 1), _fmt(sim_s * 1000.0 / ms, 0)])
	report.tasks["taller.lathe"] = { "what": "Programa Fagor A de principio a fin (Lathe.step de 0,05 s)", "steps": steps,
		"ms": ms, "per_step_us": ms * 1000.0 / steps, "realtime_factor": sim_s * 1000.0 / ms }
	var plan := Drawing.tolerance_band(Drawing.get_drawing("A"), profile.z0, profile.dz, profile.r.size())
	var mesh = LatheMesh.new()
	var build_ms := _time_ms(func() -> void: mesh.build(profile, plan))
	var rings: int = profile.r.size()
	var upd_ms := _time_ms(func() -> void:
		for k in 20:
			var a := (k * 97) % maxi(1, rings - 200)
			mesh.update(profile, plan, a, a + 199)
	)
	print("taller.mesh · malla de %d anillos: construir %s ms · actualizar 200 anillos %s ms" % [rings, _fmt(build_ms, 2), _fmt(upd_ms / 20.0, 3)])
	report.tasks["taller.mesh"] = { "what": "LatheMesh: malla completa y actualización de 200 anillos", "rings": rings,
		"build_ms": build_ms, "update_200_rings_ms": upd_ms / 20.0 }


func _bench_sound() -> void:
	var n := 2000 if quick else 20000
	var inp := { "process": "lathe", "rpm": 800.0, "teeth": 1, "jaws": 3, "pc_kw": 3.0, "pmax_kw": 7.5,
		"work_kind": "acero", "chatter": null, "coolant": true, "tool_pos": Vector3(0.1, 0.02, 0.0) }
	var ms := _time_ms(func() -> void:
		for i in n:
			inp.rpm = 600.0 + (i % 400)
			MachineSound.frame(inp)
	)
	print("\ntaller.sound · MachineSound.frame(): %s µs por marco (%d marcos)" % [_fmt(ms * 1000.0 / n, 2), n])
	report.tasks["taller.sound"] = { "what": "MachineSound.frame() (marco de parámetros del sonido)", "n": n, "ms": ms,
		"per_frame_us": ms * 1000.0 / n }


func _write() -> void:
	var path := out_path
	if path == "":
		DirAccess.make_dir_recursive_absolute("user://bench")
		path = "user://bench/bench-%s.json" % String(report.date).replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No puedo escribir %s" % path)
		return
	f.store_string(JSON.stringify(report, "  ", false))
	f.close()
	print("\nResultado guardado en %s" % ProjectSettings.globalize_path(path))
