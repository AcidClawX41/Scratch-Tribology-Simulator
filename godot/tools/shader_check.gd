## Comprueba que todos los sombreadores del programa (.gdshader de app/) compilan con el renderizador con el que se
## lanza: los pinta de uno en uno delante de una cámara y escribe «SOMBREADOR <ruta>» antes de cada uno, así que un
## error de compilación de la salida queda debajo de su sombreador. Un sombreador que no compila no se ve como error en
## pantalla: Godot pinta el material por defecto, blanco (las garras blancas de la petición 50 en Vulkan).
## Uso (Vulkan · Forward+; en la nube, con lavapipe):
##   xvfb-run -a godot --path godot --rendering-driver vulkan --rendering-method forward_plus -s res://tools/shader_check.gd
## Al final escribe «SOMBREADORES n» y sale. Para ver qué sombreador falla:
##   awk '/^SOMBREADOR /{s=$2} /ERROR/{e[s]++} END{for(k in e) print e[k], k}' salida.log
extends SceneTree

const FRAMES_EACH := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := PackedStringArray()
	_collect("res://app", paths)
	paths.sort()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	root.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.4, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	root.add_child(env)
	var n := 0
	for p in paths:
		var shader := load(p) as Shader
		if shader == null:
			print("SOMBREADOR-NO-CARGA ", p)
			continue
		var mode := shader.get_mode()
		var holder: Node = null
		var mat := ShaderMaterial.new()
		mat.shader = shader
		match mode:
			Shader.MODE_SPATIAL:
				var mi := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mi.mesh = mesh
				mi.material_override = mat
				holder = mi
			Shader.MODE_CANVAS_ITEM:
				var cr := ColorRect.new()
				cr.size = Vector2(64, 64)
				cr.material = mat
				holder = cr
			Shader.MODE_SKY:
				var old: Material = env.environment.sky.sky_material
				env.environment.sky.sky_material = mat
				print("SOMBREADOR ", p)
				for i in FRAMES_EACH:
					await process_frame
				env.environment.sky.sky_material = old
				n += 1
				continue
			Shader.MODE_PARTICLES:
				var gp := GPUParticles3D.new()
				gp.process_material = mat
				gp.draw_pass_1 = QuadMesh.new()
				holder = gp
			_:
				print("SOMBREADOR-SIN-PROBAR ", p)
				continue
		print("SOMBREADOR ", p)
		root.add_child(holder)
		for i in FRAMES_EACH:
			await process_frame
		holder.queue_free()
		await process_frame
		n += 1
	print("SOMBREADORES ", n, " · ", RenderingServer.get_current_rendering_method(), " con ", RenderingServer.get_current_rendering_driver_name())
	quit()


func _collect(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
