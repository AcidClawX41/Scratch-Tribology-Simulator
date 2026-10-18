## Ejecutor de tests sin dependencias. Recorre tests/**/test_*.gd, crea una instancia de cada script y llama a
## sus métodos test_* en orden de declaración. Sale con código 1 si algo falla.
## Los tests pueden ser corrutinas: un test que hace `await wait_frames(n)` (case.gd) espera fotogramas de verdad del
## árbol de escena (para probar la disposición real de la interfaz); el ejecutor lo espera antes de pasar al siguiente.
## Los demás siguen siendo síncronos: no pasa ningún fotograma entre ellos.
## Uso (a través del envoltorio, que antes importa el proyecto y genera los datos del oráculo):
##   npm run godot:test                      todos
##   npm run godot:test -- --filter=shared   solo los archivos cuya ruta contiene «shared»
##   npm run godot:test -- --verbose          lista cada test
extends SceneTree

var _filter := ""
var _verbose := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			_filter = a.substr(9)
		elif a == "--verbose":
			_verbose = true


## Con el bucle principal en marcha (para que los tests que esperan fotogramas los tengan).
func _initialize() -> void:
	_run()


func _run() -> void:
	# _initialize llega antes de que la raíz entre en el árbol: se espera un fotograma, así un nodo que un test añada a
	# la raíz recibe _ready() al momento, como en la aplicación
	await process_frame
	var files: Array[String] = []
	_collect("res://tests", files)
	files.sort()
	var total := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		if _filter != "" and not f.contains(_filter):
			continue
		var script := load(f) as GDScript
		if script == null or not script.can_instantiate():
			print("  ✗ %s: no se puede cargar el script" % f)
			failed += 1
			continue
		var inst: Object = script.new()
		var names: Array[String] = []
		for m in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		var file_failed := 0
		var t_file := Time.get_ticks_msec()
		for n in names:
			total += 1
			inst.call("_begin", "%s::%s" % [f.trim_prefix("res://tests/"), n])
			if inst.has_method("before_each"):
				await inst.call("before_each")  # sin esperar nada si no es una corrutina
			await inst.call(n)
			if inst.has_method("_end"):
				inst.call("_end")
			var fails: Array = inst.get("_failures")
			if fails.size() > 0:
				failed += 1
				file_failed += 1
				for x in fails:
					print("  ✗ " + str(x))
			elif int(inst.get("_asserts")) == 0:
				print("  ⚠ %s::%s no comprueba nada" % [f.trim_prefix("res://tests/"), n])
			elif _verbose:
				print("  ✓ %s::%s" % [f.trim_prefix("res://tests/"), n])
		print("%s %s: %d tests (%d ms)" % ["✗" if file_failed else "✓", f.trim_prefix("res://tests/"), names.size(), Time.get_ticks_msec() - t_file])
	print("\n%d tests, %d fallidos, %d ms" % [total, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 or total == 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		if sub != "fixtures":
			_collect(dir.path_join(sub), out)
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
