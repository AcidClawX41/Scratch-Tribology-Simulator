## Cetrería · la luz y la profundidad de la garra (unidad 5h, peticiones 35 y 36): el entorno de la sala, la luz de tres
## puntos que hace brillar la garra y lo que separa la garra del fondo, según el renderizador. Solo dibujo.
##
## La luz de tres puntos va con la cámara (como en una foto de producto), solo sobre la capa de lo que se enfoca
## (FOCUS_LAYER: la garra, los dedos y las patas): la principal, arriba y delante; la de relleno, fría y suave, del otro
## lado; y el contraluz, por detrás, que marca el borde de la garra. El sol de la ventana de la sala sigue quieto en el
## mundo: es el que da las sombras de la pata en la mesa (suaves; con el renderizador Forward+, con la penumbra de un sol
## de verdad) y alumbra la sala.
##
## Profundidad, en cada renderizador:
##   - Forward+ (escritorio): oclusión ambiental de pantalla (SSAO), luz indirecta de pantalla (SSIL), profundidad de
##     campo con el fondo desenfocado, un brillo suave, la sonda de reflexión de la sala (lo que se refleja en la
##     queratina pulida) y la niebla de profundidad que apaga el fondo;
##   - Mobile y Compatibility (y el preset del teléfono): sustitutos baratos: la niebla de profundidad, que oscurece y
##     quita detalle al fondo, el viñeteado (care_3d.gd lo pinta encima de la vista) y la oclusión horneada en los
##     vértices de las patas (care_paw.gd).
## Cada vista ajusta la distancia del enfoque, la niebla y las sombras a lo lejos que está la cámara (frame()); en cada
## fotograma solo se giran las luces que van con la cámara, y los parámetros del entorno cambian solo si la distancia
## cambia de verdad (un 3 %).
extends RefCounted

const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")

## Capa (1-20) de lo que se enfoca: la garra que se trabaja, las demás garras, los dedos y las patas. Solo ella recibe la
## luz de tres puntos.
const FOCUS_LAYER := 4
## Las tres luces de la garra (energía, color y cuánto brillo especular dan) y de dónde vienen respecto a la cámara:
## [delante (+) o detrás (−), a la derecha (+) o a la izquierda (−), arriba (+)] en el marco de la cámara.
const KEY := { "energy": 0.5, "color": Color(1.0, 0.97, 0.92), "specular": 1.8, "from": Vector3(0.75, -0.55, 0.85) }
const FILL := { "energy": 0.18, "color": Color(0.8, 0.87, 1.0), "specular": 0.3, "from": Vector3(0.7, 0.85, 0.15) }
const RIM := { "energy": 1.25, "color": Color(1.0, 0.95, 0.88), "specular": 1.8, "from": Vector3(-0.9, 0.35, 0.55) }
## Niebla de profundidad de cada vista: empieza a begin_k × la distancia de la cámara por detrás del enfoque (más
## begin_m) y llega a density a end_k × la distancia (más end_m). Dibujo: apaga la sala sin tapar la garra.
const FOG_VIEW := {
	"garra": { "begin_k": 0.45, "begin_m": 0.06, "end_k": 5.0, "end_m": 0.9, "density": 0.82 },
	"general": { "begin_k": 0.35, "begin_m": 0.3, "end_k": 2.0, "end_m": 2.5, "density": 0.55 },
	"animal": { "begin_k": 0.3, "begin_m": 0.5, "end_k": 1.6, "end_m": 3.0, "density": 0.45 },
}
## Color de la niebla de cada sitio: la penumbra de la sala (cálida en el centro de cetrería, fría en la clínica).
const FOG_COLOR := { "cetreria": Color(0.13, 0.105, 0.085), "clinica": Color(0.085, 0.1, 0.11) }
## Desenfoque del fondo (Forward+): el plano nítido acaba a far_k × la distancia por detrás del enfoque y la transición
## dura trans_k × la distancia.
const DOF_VIEW := {
	"garra": { "far_k": 0.3, "far_m": 0.012, "trans_k": 1.2, "amount": 0.11 },
	"general": { "far_k": 0.35, "far_m": 0.2, "trans_k": 1.0, "amount": 0.06 },
	"animal": { "far_k": 0.35, "far_m": 0.6, "trans_k": 1.2, "amount": 0.05 },
}
## Radio de la oclusión ambiental y de la luz indirecta de pantalla (m) por metro de distancia de la cámara.
const SSAO_K := 0.11
const SSIL_K := 0.5
## Sombras del sol a lo lejos (m) por metro de distancia de la cámara, y su mínimo (más lejos, más bastas: en la vista del
## animal basta con la mesa y el carro).
const SHADOW_K := 2.5
const SHADOW_MIN_M := 0.6
## La luz ambiente que da el cielo de cada sitio (la sala de la clínica, de azulejo blanco, refleja más).
const VENUE_AMBIENT := { "cetreria": 0.55, "clinica": 0.42 }
## El techo de la sala en el cielo (lo que se refleja arriba: encalado cálido en el centro de cetrería, blanco en la
## clínica), su alto y su ancho (m) y la fuerza de sus lámparas: dibujo.
const ROOM_CEILING := { "cetreria": Color(0.58, 0.54, 0.48), "clinica": Color(0.6, 0.64, 0.66) }
const ROOM_HEIGHT_M := 1.6
const ROOM_HALF_WIDTH_M := 3.0
const ROOM_LAMP_ENERGY := 4.5
## La ventana de la sala: del alféizar al dintel, en altura sobre el suelo (m).
const ROOM_WINDOW_M := Vector2(0.9, 2.3)
## Viñeteado (0-1) de cada renderizador: el sustituto barato de la profundidad de campo.
const VIGNETTE := { "forward_plus": 0.32, "mobile": 0.55, "gl_compatibility": 0.55 }

var settings: Dictionary = {}
var env: Environment
var world_env: WorldEnvironment
var cam_attr: CameraAttributesPractical
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var key: DirectionalLight3D
var fill: DirectionalLight3D
var rim: DirectionalLight3D
var probe: ReflectionProbe
var venue := "clinica"
var _frame_key := ""
var _rig_basis := Basis.IDENTITY


## Lo que se enciende en cada renderizador («forward_plus», «mobile» o «gl_compatibility») y calidad (mobile: el preset
## del teléfono). Puro: lo leen los tests.
static func settings_for(method: String, mobile: bool) -> Dictionary:
	var fwd := method == "forward_plus" and not mobile
	var compat := method == "gl_compatibility"
	return {
		"method": method, "mobile": mobile,
		"ssao": fwd, "ssil": fwd, "dof": fwd, "glow": not mobile, "glow_intensity": 0.32 if fwd else 0.22,
		"fog": true, "probe": not mobile and not compat, "shadows": not mobile, "soft_shadows": not compat and not mobile,
		"shadow_splits": 4 if fwd else 2, "three_point": true, "fill": not mobile,
		"vignette": float(VIGNETTE.get(method, 0.55)) if not mobile else 0.6,
		"vertex_ao": true,
	}


## El renderizador con el que corre el programa.
static func current_method() -> String:
	return RenderingServer.get_current_rendering_method()


## Construye el entorno y las luces bajo parent (la escena). → este objeto, con las referencias.
static func build(parent: Node, method: String, mobile: bool) -> RefCounted:
	var st: RefCounted = (load("res://app/lab/cetreria/care_stage.gd") as GDScript).new()
	st.call("_build", parent, method, mobile)
	return st


func _build(parent: Node, method: String, mobile: bool) -> void:
	settings = settings_for(method, mobile)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("wall_color", Color(0.72, 0.76, 0.76))
	sky_mat.set_shader_parameter("wall_low_color", Color(0.55, 0.6, 0.6))
	sky_mat.set_shader_parameter("floor_color", Color(0.46, 0.5, 0.5))
	# una sala, no la nave del taller: techo claro y bajo, con sus lámparas (lo que se refleja en la queratina pulida y
	# en un metal reforjado: con el techo oscuro de la nave, un metal pulido reflejaba casi negro)
	sky_mat.set_shader_parameter("ceiling_color", ROOM_CEILING.clinica)
	sky_mat.set_shader_parameter("hall_height", ROOM_HEIGHT_M)
	sky_mat.set_shader_parameter("hall_half_width", ROOM_HALF_WIDTH_M)
	sky_mat.set_shader_parameter("eye_height", 1.0)
	sky_mat.set_shader_parameter("lamp_energy", ROOM_LAMP_ENERGY)
	# la ventana de la sala, a la altura de una sala (5q, petición 56): con la de la nave (de 2,9 a 4,7 m sobre el suelo)
	# quedaba por encima del techo de 1,6 m y no se reflejaba en ningún metal pulido
	sky_mat.set_shader_parameter("window_bottom", ROOM_WINDOW_M.x)
	sky_mat.set_shader_parameter("window_top", ROOM_WINDOW_M.y)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	world_env = WorldEnvironment.new()
	world_env.name = "Entorno"
	world_env.environment = env
	cam_attr = CameraAttributesPractical.new()
	world_env.camera_attributes = cam_attr
	parent.add_child(world_env)
	# el sol de la ventana: quieto en el mundo, con las sombras
	sun = DirectionalLight3D.new()
	sun.name = "Sol"
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.93)
	sun.basis = Basis.looking_at(Vector3(0.6, -1.4, -1.0), Vector3.UP)
	sun.directional_shadow_max_distance = 1.5
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	parent.add_child(sun)
	# las tres luces de la garra: con la cámara, solo sobre lo que se enfoca, sin sombras
	key = _focus_light(parent, "Principal", KEY)
	fill = _focus_light(parent, "Relleno", FILL)
	rim = _focus_light(parent, "Contraluz", RIM)
	probe = ReflectionProbe.new()
	probe.name = "SondaDeReflexion"
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = true
	probe.size = Vector3(3.0, 2.4, 3.0)
	probe.box_projection = true
	probe.intensity = 0.85
	probe.cull_mask = 0xFFFFF & ~(1 << (FOCUS_LAYER - 1))
	# y sí la reciben (5q): un metal pulido en la garra refleja la mesa y la sala de cerca. Las garras blancas de la
	# petición 50 no eran la sonda (era la queratina, que no compilaba en Vulkan), así que la sonda vuelve a la garra
	probe.reflection_mask = 0xFFFFF
	parent.add_child(probe)
	apply_settings()


static func _focus_light(parent: Node, n: String, spec: Dictionary) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = n
	l.light_energy = float(spec.energy)
	l.light_color = spec.color
	l.light_specular = float(spec.specular)
	l.shadow_enabled = false
	l.light_cull_mask = 1 << (FOCUS_LAYER - 1)
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(l)
	return l


## Pone lo de settings en el entorno y las luces (al construir y al cambiar de calidad).
func apply_settings() -> void:
	var s := settings
	env.ssao_enabled = bool(s.ssao)
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.15
	env.ssil_enabled = bool(s.ssil)
	env.ssil_intensity = 0.55
	env.ssil_sharpness = 0.98
	env.glow_enabled = bool(s.glow)
	env.glow_intensity = float(s.glow_intensity)
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = bool(s.fog)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.9
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	cam_attr.dof_blur_far_enabled = bool(s.dof)
	cam_attr.dof_blur_near_enabled = false
	sun.shadow_enabled = bool(s.shadows)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(s.shadow_splits) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 1.4 if bool(s.soft_shadows) else 0.0
	fill.visible = bool(s.fill)
	probe.visible = bool(s.probe)
	_frame_key = ""


func set_quality(method: String, mobile: bool) -> void:
	settings = settings_for(method, mobile)
	apply_settings()


## La luz y el color de cada sitio: el sol que entra por la ventana (cálido por la tarde en el centro de cetrería, frío de
## día en la clínica), el color de las paredes del entorno (lo que se refleja en la queratina y en el acero) y la
## penumbra de la niebla.
func set_venue(p_venue: String, center: Vector3) -> void:
	venue = p_venue
	if venue == "cetreria":
		sun.light_color = Color(1.0, 0.9, 0.76)
		sun.light_energy = 1.05
		fill.light_color = Color(0.82, 0.86, 1.0)
		key.light_color = Color(1.0, 0.95, 0.86)
		sky_mat.set_shader_parameter("wall_color", Color(0.78, 0.74, 0.66))
		sky_mat.set_shader_parameter("wall_low_color", Color(0.6, 0.55, 0.47))
		sky_mat.set_shader_parameter("floor_color", Color(0.5, 0.42, 0.33))
		sky_mat.set_shader_parameter("ceiling_color", ROOM_CEILING.cetreria)
	else:
		sun.light_color = Color(0.98, 0.99, 1.0)
		sun.light_energy = 0.92
		fill.light_color = Color(0.78, 0.84, 1.0)
		key.light_color = Color(1.0, 0.98, 0.95)
		sky_mat.set_shader_parameter("wall_color", Color(0.76, 0.8, 0.8))
		sky_mat.set_shader_parameter("wall_low_color", Color(0.58, 0.63, 0.63))
		sky_mat.set_shader_parameter("floor_color", Color(0.48, 0.52, 0.53))
		sky_mat.set_shader_parameter("ceiling_color", ROOM_CEILING.clinica)
	env.fog_light_color = FOG_COLOR.get(venue, FOG_COLOR.clinica)
	env.ambient_light_energy = float(VENUE_AMBIENT.get(venue, VENUE_AMBIENT.clinica))
	# la sonda de reflexión, centrada en la pata (se vuelve a pintar una vez al moverla)
	probe.position = center + Vector3(0.0, 0.5, 0.0)
	_frame_key = ""


## Cada fotograma: gira las luces de la garra con la cámara y, si la distancia ha cambiado, ajusta el desenfoque, la
## niebla, la oclusión y las sombras a la vista. focus_m: la distancia de la cámara a lo que enfoca.
func frame(cam: Camera3D, view: String, focus_m: float) -> void:
	var cb := cam.global_transform.basis
	if not cb.is_equal_approx(_rig_basis):
		_rig_basis = cb
		for pair: Array in [[key, KEY], [fill, FILL], [rim, RIM]]:
			var l: DirectionalLight3D = pair[0]
			var f: Vector3 = (pair[1] as Dictionary).from
			# de dónde viene la luz, en el mundo (delante = hacia la cámara, +Z de la cámara)
			var from := (cb.z * f.x + cb.x * f.y + Vector3.UP * f.z).normalized()
			l.basis = Basis.looking_at(-from, Vector3.UP if absf(from.y) < 0.98 else Vector3.BACK)
	var d := maxf(focus_m, 0.005)
	var fk := "%s|%d" % [view, int(round(log(d) / log(1.03)))]
	if fk == _frame_key:
		return
	_frame_key = fk
	var fog: Dictionary = FOG_VIEW.get(view, {})
	env.fog_enabled = bool(settings.fog) and not fog.is_empty()
	if env.fog_enabled:
		env.fog_depth_begin = d + d * float(fog.begin_k) + float(fog.begin_m)
		env.fog_depth_end = d + d * float(fog.end_k) + float(fog.end_m)
		env.fog_density = float(fog.density)
	var dof: Dictionary = DOF_VIEW.get(view, {})
	cam_attr.dof_blur_far_enabled = bool(settings.dof) and not dof.is_empty()
	if cam_attr.dof_blur_far_enabled:
		cam_attr.dof_blur_far_distance = d + d * float(dof.far_k) + float(dof.far_m)
		cam_attr.dof_blur_far_transition = d * float(dof.trans_k) + float(dof.far_m)
		cam_attr.dof_blur_amount = float(dof.amount)
	env.ssao_radius = clampf(d * SSAO_K, 0.004, 1.0)
	env.ssil_radius = clampf(d * SSIL_K, 0.02, 4.0)
	sun.directional_shadow_max_distance = maxf(d * SHADOW_K, SHADOW_MIN_M)


## Lo que está encendido ahora (para los tests y el informe).
func info() -> Dictionary:
	return {
		"method": settings.get("method", ""), "ssao": env.ssao_enabled, "ssil": env.ssil_enabled,
		"dof": cam_attr.dof_blur_far_enabled, "glow": env.glow_enabled, "fog": env.fog_enabled, "probe": probe.visible,
		"probe_on_focus": (probe.reflection_mask & (1 << (FOCUS_LAYER - 1))) != 0,
		"shadows": sun.shadow_enabled, "soft_shadows": sun.light_angular_distance > 0.0, "fill": fill.visible,
		"vignette": float(settings.get("vignette", 0.0)), "fog_begin": env.fog_depth_begin, "fog_end": env.fog_depth_end,
		"dof_far": cam_attr.dof_blur_far_distance,
	}
