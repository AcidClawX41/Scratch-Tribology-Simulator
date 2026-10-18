## El renderizador que elige quien usa el programa (petición 50): «vulkan» (Forward+, el de serie: SSAO, SSIL, la sonda de
## reflexión y el desenfoque del fondo) u «opengl» (Compatibility: más sencillo, para tarjetas o controladores con
## problemas, y el que se ve en las capturas de la nube).
## Godot elige el renderizador al arrancar, antes de cargar ninguna escena: lo lee de project.godot y de
## application/config/project_settings_override (= OVERRIDE_PATH), que se lee justo después. Aquí se escribe ese archivo
## y el programa se reinicia con los mismos argumentos, sin los que fuerzan otro renderizador.
## Solo en escritorio: en el teléfono manda el renderizador Mobile del proyecto.
extends RefCounted

## El archivo que lee Godot al arrancar (project.godot → application/config/project_settings_override).
const OVERRIDE_PATH := "user://graficos.cfg"
const METHOD_KEY := "renderer/rendering_method"
const DRIVER_KEYS := ["rendering_device/driver.windows", "rendering_device/driver.linuxbsd"]
const IDS := ["vulkan", "opengl"]
const LABELS := {"vulkan": "Vulkan · Forward+", "opengl": "OpenGL · Compatibility"}
const NOTES := {
	"vulkan": "El de serie: sombras suaves, oclusión ambiental, luz rebotada, reflejos de la sala y desenfoque del fondo. Si la tarjeta o el controlador no lo admiten, Godot pasa solo a OpenGL.",
	"opengl": "Más sencillo y más compatible: sin oclusión ambiental, ni luz rebotada, ni reflejos de la sala; la niebla y el viñeteado los sustituyen. Útil si algo se ve mal o va lento con Vulkan.",
}
## Argumentos de la línea de órdenes que fuerzan un renderizador (con su valor detrás): se quitan al reiniciar, porque
## mandarían sobre la elección.
const FORCING_ARGS := ["--rendering-driver", "--rendering-method"]


## El nombre de cada opción en este sistema: en macOS, Forward+ va con Metal (Vulkan solo con MoltenVK).
static func label(id: String) -> String:
	if id == "vulkan" and OS.get_name() == "macOS":
		return "Metal · Forward+"
	return String(LABELS.get(id, id))


## Se puede elegir aquí (escritorio; en la web y en el teléfono, no).
static func available() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web")


## El renderizador con el que va el programa ahora: «opengl» si es Compatibility, «vulkan» si es Forward+ (o Mobile en
## escritorio, que también usa Vulkan).
static func current() -> String:
	return "opengl" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "vulkan"


## Texto de lo que va ahora, con el controlador de verdad (por ejemplo, «Forward+ con Vulkan» u «OpenGL (Compatibility)»).
static func current_text() -> String:
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	if method == "gl_compatibility":
		return "OpenGL (Compatibility)"
	var names := {"forward_plus": "Forward+", "mobile": "Mobile"}
	var drivers := {"vulkan": "Vulkan", "d3d12": "Direct3D 12", "metal": "Metal"}
	return "%s con %s" % [names.get(method, method), drivers.get(driver, driver)]


## La elección guardada en path («vulkan», «opengl» o «» si no hay ninguna).
static func saved(path := OVERRIDE_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	match String(cfg.get_value("rendering", METHOD_KEY, "")):
		"gl_compatibility":
			return "opengl"
		"forward_plus":
			return "vulkan"
	return ""


## Guarda la elección en path para el próximo arranque. → OK o el error de ConfigFile.
static func save(id: String, path := OVERRIDE_PATH) -> Error:
	if not id in IDS:
		return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	cfg.load(path)
	if id == "opengl":
		cfg.set_value("rendering", METHOD_KEY, "gl_compatibility")
	else:
		cfg.set_value("rendering", METHOD_KEY, "forward_plus")
	# Vulkan también en Windows (allí Godot podría ir con Direct3D 12); OpenGL no usa estos
	for k: String in DRIVER_KEYS:
		cfg.set_value("rendering", k, "vulkan")
	return cfg.save(path)


## Los argumentos para reiniciar: los mismos, sin los que fuerzan un renderizador (ni su valor, si va aparte).
static func restart_args(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var skip := false
	for a in args:
		if skip:
			skip = false
			continue
		var forcing := false
		for f: String in FORCING_ARGS:
			if a == f:
				forcing = true
				skip = true
			elif a.begins_with(f + "="):
				forcing = true
		if not forcing:
			out.append(a)
	return out


## Reinicia el programa al salir, con los argumentos de restart_args, y sale. En el editor no reinicia (se aplica la
## próxima vez que se ejecute).
static func restart(tree: SceneTree) -> void:
	if not OS.has_feature("editor"):
		OS.set_restart_on_exit(true, restart_args(OS.get_cmdline_args()))
	tree.quit()
