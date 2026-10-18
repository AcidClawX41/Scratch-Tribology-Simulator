## Taller industrial · vista 3D de una escena del taller (torno o radial) en su propio SubViewport, con su mundo 3D,
## su cámara y su entorno: dos vistas no se ven la una a la otra y la escena no depende de la ventana.
##
## La escena se crea con ensure_scene() la primera vez que la página se enseña, y solo si la vista ya está en el
## árbol (en los tests sin ventana no se crea: no hace falta y ahorra el coste de la máquina 3D). Se libera con el
## nodo. El SubViewport solo se dibuja mientras la vista está visible.
extends SubViewportContainer

signal scene_ready(scene: Node)

var scene_path := ""
var scene: Node = null
var viewport := SubViewport.new()
## Opcional: se llama con la escena recién creada, antes de meterla en el árbol (parámetros que lee su _ready).
var configure: Callable = Callable()


func _init(path: String = "") -> void:
	scene_path = path
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.own_world_3d = true
	viewport.handle_input_locally = true
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.size = Vector2i(640, 400)
	add_child(viewport)


## Crea la escena si aún no existe (y la vista está en el árbol). Devuelve la escena o null.
func ensure_scene() -> Node:
	if scene == null and scene_path != "" and is_inside_tree():
		scene = (load(scene_path) as PackedScene).instantiate()
		if configure.is_valid():
			configure.call(scene)
		viewport.add_child(scene)
		scene_ready.emit(scene)
	return scene
