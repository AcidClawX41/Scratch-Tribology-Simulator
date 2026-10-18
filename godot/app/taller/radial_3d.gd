## Radial contra chapa de coche: escena 3D educativa del Taller industrial.
##
## Sin entorno de juego: una amoladora angular, un trozo de chapa de puerta curvada con su pintura de fábrica y el
## corte visto de cerca. Todo lo que pasa en el corte (surco, rebaba, colores de revenido, pintura quemada, chispas,
## humo e hilos de plástico) sale de la salida del modelo de corte, core/taller/radial.gd → cut_panel (unidad 6).
## La escena no calcula física: la dibuja.
## Las chispas las emite core/taller/sparks.gd (ensayo de chispas, TC 9-237).
##
## API para la interfaz:
##   set_params(params)              entrada del contrato { disc_id, diameter_mm, rpm, angle_deg, feed_mm_s,
##                                   panel_id, cut_length_mm }
##   set_result(result)              salida del contrato (cut_panel)
##   start_cut(from_mm, prewarm_s)   empieza el corte (opcional: con parte ya cortada y el haz ya formado)
##   set_view(name)                  «detalle» (del corte) · «general» · «canto» (sección a escala) · «cenital»
##                                   (el surco visto desde arriba, a escala)
##   set_rpm(rpm)                    cambia el giro y la velocidad de las chispas al momento; la interfaz pide
##                                   luego otro cut_panel y llama a set_result
##   set_angle(deg)                  inclina el disco sobre la línea de corte (0 = perpendicular a la chapa)
##   set_inset(on)                   recuadros a la derecha con el canto y la vista cenital del corte, a escala
##   info()                          datos para rótulos: vs, estroboscopio, avance real, progreso…
## Nada arranca solo: sin auto_start, la escena espera a start_cut (modo «auto») o a la mano (modo «manual»).
##
## Modo manual (la radial en tus manos, docs/taller/radial-manual.md):
##   set_mode("manual" | "auto")     «auto» es el corte automático de siempre (la demo guionizada); «manual», el de la
##                                   mano
##   manual                          el RadialManual (core/taller/radial_manual.gd) al que el ratón pasa lo que hace la
##                                   mano (move_hand, turn_hand); lo pone la página o la demo, que lo avanzan
##   show_frame(frame)               la salida de ese paso del core: pose del disco, giro, mapa del surco, chispas, humo…
##                                   La escena lo dibuja; no calcula nada.
##   señales gesture_finished (se suelta el ratón tras mover o girar la radial) y dial_step_requested(k) (Alt + rueda)
##   reset_camera() · stats() (contadores para los tests: mallas hechas, texturas subidas)
## Ratón (radial3d/hand_input.gd): izquierdo mueve la radial; Mayús + izquierdo la gira y la inclina; rueda la acerca
## o la aparta; derecho gira la cámara, central la desplaza y Ctrl + rueda hace zoom.
## Unidades de la escena: metros (la geometría) y los mm/µm del contrato (los datos).
extends Node3D

signal cut_finished
## (modo manual) Se ha soltado el ratón (o la rueda) después de mover o girar la radial.
signal gesture_finished
## (modo manual) Alt + rueda del ratón: mover la rueda de velocidad k posiciones.
signal dial_step_requested(steps: int)

const Sparks = preload("res://core/taller/sparks.gd")
const Js = preload("res://core/shared/js.gd")
const Looks = preload("res://app/taller/radial3d/looks.gd")
const Radial = preload("res://core/taller/radial.gd")
const PB = preload("res://app/taller/radial3d/panel_builder.gd")
const GB = preload("res://app/taller/radial3d/grinder_builder.gd")
const Smoke = preload("res://app/taller/radial3d/smoke.gd")
const Palette = preload("res://app/theme/palette.gd")
const PANEL_SHADER = preload("res://app/taller/corte_chapa.gdshader")
const DISC_SHADER = preload("res://app/taller/radial3d/disco.gdshader")
const SPARK_SHADER = preload("res://app/taller/radial3d/chispa.gdshader")
const SMOKE_SHADER = preload("res://app/taller/radial3d/humo.gdshader")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")
const Panels = preload("res://core/taller/panels.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const CutMapView = preload("res://app/taller/radial3d/cut_map_view.gd")
const HandInput = preload("res://app/taller/radial3d/hand_input.gd")
const Hazards = preload("res://app/taller/radial3d/hazards.gd")

const VIEWS := ["detalle", "general", "canto", "cenital"]
const VIEW_ALIASES := {
	"detalle del corte": "detalle", "vista general": "general", "canto del corte": "canto", "seccion": "canto",
	"sección": "canto", "surco": "cenital", "desde arriba": "cenital",
}
const DEFAULT_PARAMS := {
	"disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 20.0,
	"panel_id": "acero-dulce", "cut_length_mm": 200.0,
}
## El disco baja 4 mm por debajo de la chapa (lo que asoma por abajo al cortar de lado a lado).
const PLUNGE_BELOW_MM := 4.0
## Por encima de 2 vueltas/s el giro real no se puede seguir fotograma a fotograma (a 30 fps, 11 000 rpm son 6,1
## vueltas por fotograma): la escena lo muestra como con un estroboscopio que destella un poco por debajo de la
## frecuencia de giro, de modo que el disco parece avanzar 0,35 vueltas/s y se ve nítido.
const STROBE_MIN_RPS := 2.0
const STROBE_APPARENT_RPS := 0.35
## Exposición de la «cámara» para las estelas de las chispas (1/60 s: las estelas largas de una foto normal).
const SPARK_EXPOSURE_S := 1.0 / 60.0
## Capas de render de los rótulos de las vistas a escala: solo las ve su cámara (recuadros o cámara principal).
const CANTO_LAYER := 20
const TOP_LAYER := 19
const MAIN_SCALE_LAYER := 18
## Posición (u, mm) que enseña la vista cenital: junto al canto, en lo ya cortado y lejos del disco.
const TOP_VIEW_U := 20.0
## Tamaño de los recuadros (px).
const INSET_SIZE := Vector2i(424, 236)
## Temperatura del frente del corte en el acero (rojo anaranjado de la tabla V del TM 9-237). ESTIMACIÓN visual.
const FRONT_GLOW_C := 900.0
## Modo manual: el brillo del frente (a la temperatura del modelo) se apaga en ~0,3 s al dejar de cortar (dibujo, no un
## dato de enfriamiento) y la cámara de detalle sigue al disco con esta constante de tiempo.
const GLOW_FADE_C_S := 3000.0
const FOCUS_TAU_S := 0.25
## Los rótulos a escala se rehacen tras este rato sin cortar (interfaz).
const LABELS_IDLE_S := 0.4
## Preset móvil: menos chispas y humo (la física no cambia: solo cuántas partículas se dibujan).
const MOBILE_PARTICLES := 0.4
const MOBILE_SMOKE := 0.5

## Sin arranque automático: nada corta hasta que alguien llama a start_cut (o mueve la radial en el modo manual).
@export var auto_start := false
## Lado de la pantalla donde van los recuadros a escala: «izquierda» o «derecha».
@export var inset_side := "izquierda"
## «auto»: el corte automático con la salida de cut_panel (start_cut). «manual»: la radial en tus manos (show_frame).
@export var mode := "auto"
## Calidad de las partículas: «» según la plataforma, «escritorio» o «movil» (menos chispas y humo).
@export var quality := ""

var params: Dictionary = DEFAULT_PARAMS.duplicate()
var result: Dictionary = {}
var view := "detalle"
var time_scale := 1.0
## Modo manual: el RadialManual que mueve la mano (lo pone quien lo avanza: la página o la demo) y su última salida.
var manual: RefCounted = null
var frame: Dictionary = {}
## La entrada del ratón mueve la radial y la cámara (la página la apaga durante la demostración).
var input_enabled := true

var _built := false
var _started := false
var _cut_mm := 0.0
var _cutting := false
var _feed_eff := 20.0
var _spin_angle := 0.0
var _strobe_hz := 0.0
var _total_mm := 1.035
var _pose := {}
var _disc_key := ""
var _panel_key := ""
var _cut_key := ""
var _inset_on := false

var _panel: MeshInstance3D
var _walls: MeshInstance3D
var _burrs: MeshInstance3D
var _threads: MeshInstance3D
var _panel_mat: ShaderMaterial
var _grinder: Node3D
var _disc: MeshInstance3D
var _disc_mat: ShaderMaterial
var _label_pivot: Node3D
var _sparks_mmi: MultiMeshInstance3D
var _smoke_mmi: MultiMeshInstance3D
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _camera: Camera3D
var _canto_labels: Node3D
var _top_labels: Node3D
var _main_labels: Node3D
var _inset_layer: CanvasLayer
var _inset_cams := {}
var _emitter: Sparks
var _smoke: Smoke

# Modo manual
var _cutmap: CutMapView
var _m_walls: MeshInstance3D
var _m_burrs: MeshInstance3D
var _m_threads: MeshInstance3D
var _hazards: Node3D
var _hazard_key := ""
var _hand := HandInput.new()
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _orbit_zoom := 1.0
var _orbit_pan := Vector3.ZERO
var _focus := Vector3.ZERO
var _focus_ready := false
var _top_u := TOP_VIEW_U
var _loading_shown := 0.0
var _glow_c := 0.0
var _was_cutting := false
var _idle_s := 0.0
var _last_cut_frame: Dictionary = {}
var _grinder_builds := 0
var _legacy_builds := 0
var _particles := 1.0
var _smoke_scale := 1.0


func _ready() -> void:
	var mobile := quality == "movil" or (quality == "" and OS.has_feature("mobile"))
	_particles = MOBILE_PARTICLES if mobile else 1.0
	_smoke_scale = MOBILE_SMOKE if mobile else 1.0
	_build()
	_built = true
	if result.is_empty():
		result = Radial.cut_panel(params)
	_apply_params()
	_apply_result()
	if mode == "manual":
		_enter_manual()
	elif auto_start and not _started:
		start_cut(110.0, 0.4)
	set_view(view)


# ───────────────────────────── API ─────────────────────────────


## Entrada del contrato del modelo de corte (se pueden pasar solo las claves que cambian).
func set_params(p: Dictionary) -> void:
	for k in p:
		params[k] = p[k]
	if _built:
		_apply_params()


## Salida del contrato del modelo de corte (cut_panel).
func set_result(r: Dictionary) -> void:
	result = r
	if _built:
		_apply_result()


## Empieza el corte desde el canto de la chapa (o con from_mm ya cortados). prewarm_s: segundos de chispas y humo
## que se simulan de golpe para que el haz ya esté formado (la demo lo usa para comparar casos).
func start_cut(from_mm: float = 0.0, prewarm_s: float = 0.0) -> void:
	_cut_mm = clampf(from_mm, 0.0, float(params["cut_length_mm"]))
	_cutting = true
	_started = true
	if not _built:
		return
	_emitter.reset()
	_smoke.reset()
	_configure_effects(true)
	_update_pose()
	var dt := 1.0 / 60.0
	for k in int(round(prewarm_s / dt)):
		_step_effects(dt)


## «detalle» (del corte), «general», «canto» (sección a escala) o «cenital» (el surco desde arriba, a escala);
## también «detalle del corte», «vista general», «canto del corte»…
func set_view(name: String) -> void:
	var v: String = VIEW_ALIASES.get(name.to_lower(), name.to_lower())
	if not VIEWS.has(v):
		push_warning("Vista desconocida: %s" % name)
		return
	view = v
	reset_camera()
	if _built:
		# En las vistas a escala, la cámara principal ve sus propios rótulos (hechos para su proporción).
		var mask := _base_mask()
		if v == "canto" or v == "cenital":
			mask |= 1 << (MAIN_SCALE_LAYER - 1)
		_camera.cull_mask = mask
		if mode == "manual":
			_top_u = clampf(float(frame.get("u_mm", TOP_VIEW_U)), 15.0, PB.U_MAX - 15.0)
		_build_inset_labels()
		_update_camera()


## Giro del disco (rpm). Cambia al momento el giro que se ve y la velocidad de las chispas.
func set_rpm(rpm: float) -> void:
	params["rpm"] = maxf(rpm, 0.0)
	var rps := float(params["rpm"]) / 60.0
	_strobe_hz = rps - STROBE_APPARENT_RPS if rps > STROBE_MIN_RPS else 0.0
	if _built and mode == "auto":
		_configure_effects(_cutting)


## Ángulo del disco respecto a la perpendicular de la chapa (grados), girando sobre la línea de corte.
func set_angle(deg: float) -> void:
	params["angle_deg"] = clampf(deg, -60.0, 60.0)
	if _built and mode == "auto":
		_rebuild_cut_meshes()
		_build_inset_labels()
		_update_pose()


## «auto» (el corte automático de start_cut, con la salida de cut_panel) o «manual» (la radial en tus manos, con
## show_frame). El corte hecho a mano se queda al pasar a la demostración y al volver.
func set_mode(m: String) -> void:
	if m != "auto" and m != "manual":
		push_warning("Modo desconocido: %s" % m)
		return
	if m == mode:
		return
	mode = m
	if not _built:
		return
	if m == "manual":
		_enter_manual()
	else:
		_enter_auto()


## (modo manual) La salida de un paso de core/taller/radial_manual.gd: se dibuja en el siguiente _process.
func show_frame(f: Dictionary) -> void:
	frame = f


## Vuelve a la vista pedida, sin el giro, el desplazamiento ni el zoom que haya puesto el ratón.
func reset_camera() -> void:
	_orbit_yaw = 0.0
	_orbit_pitch = 0.0
	_orbit_zoom = 1.0
	_orbit_pan = Vector3.ZERO


## Contadores para los tests: mallas hechas (amoladora, surco automático, surco manual) y texturas del mapa subidas.
func stats() -> Dictionary:
	return {
		"grinder_builds": _grinder_builds, "legacy_mesh_builds": _legacy_builds,
		"manual_mesh_builds": _cutmap.mesh_builds if _cutmap != null else 0,
		"map_uploads": _cutmap.uploads if _cutmap != null else 0, "mode": mode,
	}


## Recuadros a la derecha con el canto (sección) y la vista cenital del corte, a escala.
func set_inset(on: bool) -> void:
	_inset_on = on
	if not _built:
		return
	if on and _inset_layer == null:
		_build_insets()
	if _inset_layer != null:
		_inset_layer.visible = on


## Datos para rótulos de la interfaz.
func info() -> Dictionary:
	var d := float(params["diameter_mm"])
	var rpm := float(params["rpm"])
	return {
		"vs_ms": Radial.peripheral_speed(d, rpm),
		"max_rpm": _disc_limit_rpm(str(params["disc_id"]), d),
		"strobe_hz": _strobe_hz,
		"feed_mm_s": _feed_eff,
		"cut_mm": _cut_mm if mode == "auto" else float(frame.get("cut_length_mm", 0.0)),
		"cut_length_mm": float(params["cut_length_mm"]),
		"cutting": _cutting if mode == "auto" else bool(frame.get("cutting", false)),
		"sparks": _emitter.stats() if _emitter != null else {},
		"stub": bool(result.get("stub", false)),
	}


# ───────────────────────────── construcción ─────────────────────────────


func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color("bg")
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	# Estudio oscuro: el cielo solo da reflejos suaves a los metales y a la pintura (no se ve de fondo).
	sky_mat.sky_top_color = Color(0.1, 0.09, 0.12)
	sky_mat.sky_horizon_color = Color(0.3, 0.29, 0.33)
	sky_mat.ground_horizon_color = Color(0.13, 0.12, 0.14)
	sky_mat.ground_bottom_color = Color(0.04, 0.03, 0.05)
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_light(Vector3(-52.0, -38.0, 0.0), Color(1.0, 0.95, 0.88), 1.0, true)
	_light(Vector3(-25.0, 125.0, 0.0), Color(0.72, 0.8, 1.0), 0.4, false)
	_light(Vector3(-38.0, -62.0, 0.0), Color(1.0, 0.97, 0.94), 0.3, false)  # ilumina de lado el canto u = 0 (la sección)

	_panel_mat = ShaderMaterial.new()
	_panel_mat.shader = PANEL_SHADER
	_panel_mat.set_shader_parameter("temper_ramp", Looks.temper_ramp())
	_panel_mat.set_shader_parameter("heat_ramp", _heat_ramp())
	_panel_mat.set_shader_parameter("temper_min_c", Looks.TEMPER_MIN_C)
	_panel_mat.set_shader_parameter("temper_max_c", Looks.TEMPER_MAX_C)
	_panel = _mesh_node("Chapa", _panel_mat)
	_walls = _mesh_node("ParedesDelSurco", _panel_mat)
	_burrs = _mesh_node("Rebabas", _panel_mat)
	_threads = _mesh_node("HilosDePlastico", _panel_mat)

	_grinder = Node3D.new()
	_grinder.name = "Amoladora"
	add_child(_grinder)
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = DISC_SHADER

	_emitter = Sparks.new("radial")
	_emitter.set_exposure(SPARK_EXPOSURE_S)
	_smoke = Smoke.new("radial:humo")
	_sparks_mmi = _multimesh_node("Chispas", SPARK_SHADER, Sparks.MAX_SPARKS, false)
	_smoke_mmi = _multimesh_node("Humo", SMOKE_SHADER, Smoke.MAX_PUFFS, true)

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var g2 := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g2.gradient = grad
	g2.fill = GradientTexture2D.FILL_RADIAL
	g2.fill_from = Vector2(0.5, 0.5)
	g2.fill_to = Vector2(0.5, 0.0)
	g2.width = 64
	g2.height = 64
	_glow_mat.albedo_texture = g2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.006, 0.006)
	_glow = MeshInstance3D.new()
	_glow.name = "BrilloDelFrente"
	_glow.mesh = quad
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)

	# Modo manual: el surco del mapa (material y mallas de toda la línea) y las marcas del escenario de las chispas
	_cutmap = CutMapView.new()
	var cm := _cutmap.material
	cm.set_shader_parameter("temper_ramp", Looks.temper_ramp())
	cm.set_shader_parameter("heat_ramp", _heat_ramp())
	cm.set_shader_parameter("temper_min_c", Looks.TEMPER_MIN_C)
	cm.set_shader_parameter("temper_max_c", Looks.TEMPER_MAX_C)
	cm.set_shader_parameter("line_mm", PB.U_MAX)
	_m_walls = _mesh_node("SurcoManual", cm)
	_m_burrs = _mesh_node("RebabasManual", cm)
	_m_threads = _mesh_node("HilosManual", cm)
	for mi: MeshInstance3D in [_m_walls, _m_burrs, _m_threads]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
	_hazards = Node3D.new()
	_hazards.name = "EscenarioDeLasChispas"
	_hazards.visible = false
	add_child(_hazards)

	_canto_labels = Node3D.new()
	_canto_labels.name = "RotulosDelCanto"
	add_child(_canto_labels)
	_top_labels = Node3D.new()
	_top_labels.name = "RotulosCenitales"
	add_child(_top_labels)
	_main_labels = Node3D.new()
	_main_labels.name = "RotulosDeLaVistaAEscala"
	add_child(_main_labels)

	_camera = Camera3D.new()
	_camera.name = "Camara"
	_camera.cull_mask = _base_mask()
	add_child(_camera)
	_camera.current = true
	if _inset_on:
		_build_insets()


## Todas las capas menos las de los rótulos de las vistas a escala.
static func _base_mask() -> int:
	return 0xFFFFF & ~(1 << (CANTO_LAYER - 1)) & ~(1 << (TOP_LAYER - 1)) & ~(1 << (MAIN_SCALE_LAYER - 1))


func _light(rot: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.light_specular = 0.5 if shadows else 0.0  # las de relleno no hacen brillos en la pintura
	l.rotation_degrees = rot
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	l.shadow_enabled = shadows
	if shadows:
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		l.directional_shadow_max_distance = 0.9
	add_child(l)


func _mesh_node(node_name: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.material_override = mat
	add_child(mi)
	return mi


func _multimesh_node(node_name: String, shader: Shader, capacity: int, centered: bool) -> MultiMeshInstance3D:
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var x0 := -0.5 if centered else 0.0
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(x0, -0.5, 0), Vector3(x0 + 1.0, -0.5, 0), Vector3(x0 + 1.0, 0.5, 0), Vector3(x0, 0.5, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	quad.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Rampa de incandescencia (TM 9-237, tabla V) de 300 a 1300 °C para el shader de la chapa.
func _heat_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for k in 21:
		offsets.append(float(k) / 20.0)
		colors.append(Sparks.heat_color(300.0 + 50.0 * float(k)))
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 128
	return tex


func _rebuild_grinder() -> void:
	_grinder_builds += 1
	for c in _grinder.get_children():
		_grinder.remove_child(c)
		c.queue_free()
	var disc_id := str(params["disc_id"])
	var r := float(params["diameter_mm"]) / 2000.0
	var front := GB.disc_front(disc_id)
	GB.build_grinder(_grinder, front, r)
	_disc = MeshInstance3D.new()
	_disc.name = "Disco"
	_disc.mesh = GB.build_disc(disc_id, r)
	_disc.material_override = _disc_mat
	_grinder.add_child(_disc)
	var look := Looks.disc(disc_id)
	var kinds := {"abrasivo": 0, "diamante": 1, "laminas": 2, "borde": 3}
	_disc_mat.set_shader_parameter("kind", int(kinds.get(str(look["kind"]), 0)))
	_disc_mat.set_shader_parameter("rim_color", Color(str(look.get("rim", "#6E737A"))))
	_disc_mat.set_shader_parameter("radius_mm", r * 1000.0)
	_disc_mat.set_shader_parameter("bore_mm", GB.BORE_M * 1000.0)
	_disc_mat.set_shader_parameter("label_mm", minf(36.0, r * 1000.0 - 12.0))
	_disc_mat.set_shader_parameter("body", Color(str(look["body"])))
	_disc_mat.set_shader_parameter("body_lo", Color(str(look["body_lo"])))
	_disc_mat.set_shader_parameter("label_color", Color(str(look["label"])))
	_disc_mat.set_shader_parameter("label_ink", Color(str(look["label_ink"])))
	var phys: Dictionary = Abrasives.DISCS.get(str(params["disc_id"]), {})
	var max_vs := float(phys.get("max_speed_ms", look["max_vs"]))  # la del modelo; la de Looks solo si no hay
	_disc_mat.set_shader_parameter("stripe", Looks.stripe_color(max_vs))
	_disc_mat.set_shader_parameter("segments", int(look.get("segments", 12)))
	_disc_mat.set_shader_parameter("segment_mm", float(look.get("segment_mm", 8.0)))
	_disc_mat.set_shader_parameter("flaps", int(look.get("flaps", 72)))
	# Rótulos impresos en la etiqueta (giran con el dibujo del disco)
	_label_pivot = Node3D.new()
	_label_pivot.name = "Etiqueta"
	_grinder.add_child(_label_pivot)
	if str(look["kind"]) != "laminas":
		# Lo impreso en la etiqueta sale del modelo: medidas y agujero (abrasives.gd), velocidad máxima y rpm máximas
		# (Radial.disc_check: las marcadas en el disco, las de la tabla de EN 12413 o las de la fórmula)
		var d_mm := float(params["diameter_mm"])
		var z := front + 0.00012
		var ink := Color(str(look["label_ink"]))
		var bore := float(phys.get("bore_mm", 22.23))
		var dims := "%s × %s × %s" % [Js.to_fixed(d_mm, 0), Js.to_fixed(float(look["t_mm"]), 1),
			Js.to_fixed(bore, 0 if bore == floorf(bore) else 2)]
		_disc_text(dims, Vector3(0.0, 0.0268, z), ink, 26)
		_disc_text("máx. %s rpm" % Js.to_fixed(floorf(_disc_limit_rpm(str(params["disc_id"]), d_mm)), 0), Vector3(0.0, -0.0262, z), ink, 26)
		_disc_text("%s m/s" % Js.to_fixed(max_vs, 0), Vector3(0.0272, 0.0, z), Color(1, 1, 1), 28)


## rpm máximas de un disco en ese diámetro, del modelo (Radial.disc_check).
static func _disc_limit_rpm(disc_id: String, d_mm: float) -> float:
	return float(Radial.disc_check({ "disc_id": disc_id, "diameter_mm": d_mm, "rpm": 0.0 })["limit_rpm"])


func _disc_text(text: String, pos: Vector3, color: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = size
	l.pixel_size = 0.0001
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_label_pivot.add_child(l)


## Recuadros a escala, apilados a la derecha: la sección por el canto y el surco visto desde arriba.
func _build_insets() -> void:
	_inset_layer = CanvasLayer.new()
	_inset_layer.name = "Recuadros"
	_inset_layer.layer = 4
	add_child(_inset_layer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var right := inset_side == "derecha"
	col.anchor_left = 1.0 if right else 0.0
	col.anchor_right = col.anchor_left
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	var w := float(INSET_SIZE.x) + 16.0
	col.offset_left = -w - 14.0 if right else 14.0
	col.offset_right = -14.0 if right else 14.0 + w
	col.offset_top = -2.0 * (float(INSET_SIZE.y) + 48.0) - 6.0
	col.offset_bottom = -14.0
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_inset_layer.add_child(col)
	_inset_cams["cenital"] = _inset(col, "Surco desde arriba · a escala", TOP_LAYER)
	_inset_cams["canto"] = _inset(col, "Canto del corte · sección a escala", CANTO_LAYER)


func _inset(parent: Control, title_text: String, layer: int) -> Camera3D:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.color("panel")
	sb.border_color = Palette.color("line2")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	parent.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.color("mint"))
	box.add_child(title)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(INSET_SIZE)
	box.add_child(svc)
	var sv := SubViewport.new()
	sv.size = INSET_SIZE
	sv.msaa_3d = Viewport.MSAA_2X
	if is_inside_tree():
		sv.world_3d = get_viewport().find_world_3d()
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.cull_mask = _base_mask() | (1 << (layer - 1))
	sv.add_child(cam)
	cam.current = true
	return cam


# ───────────────────────────── aplicar datos ─────────────────────────────


func _apply_params() -> void:
	var disc_key := "%s|%s" % [params["disc_id"], params["diameter_mm"]]
	if disc_key != _disc_key:
		_disc_key = disc_key
		_rebuild_grinder()
	var panel_id := str(params["panel_id"])
	var pl := Looks.panel(panel_id)
	var is_plastic := str(pl["kind"]) == "plastico"
	# Pintura del modelo (panels.gd): 110 µm en las carrocerías; las piezas de rescate son acero desnudo (0 µm),
	# sin capas de pintura, sin color de coche y sin la cataforesis de dentro.
	var paint_um := float(pl["paint_um"])
	var bare := paint_um <= 0.0
	var inner := 0.0 if is_plastic or bare else Looks.INNER_ECOAT_UM / 1000.0
	_total_mm = paint_um / 1000.0 + float(pl["t_mm"]) + inner
	if panel_id != _panel_key:
		_panel_key = panel_id
		_panel.mesh = PB.build_panel(_total_mm)
		_legacy_builds += 1
		for m: ShaderMaterial in [_panel_mat, _cutmap.material]:
			_apply_panel_look(m, panel_id)
		if mode == "manual":
			_build_manual_scene()
	set_rpm(float(params["rpm"]))
	if mode == "auto":
		_rebuild_cut_meshes()
		_update_pose()


## Pintura, capas, metal y tipo de chapa de un material de chapa (el del corte automático o el del manual: los mismos
## uniformes).
func _apply_panel_look(m: ShaderMaterial, panel_id: String) -> void:
	var pl := Looks.panel(panel_id)
	var is_plastic := str(pl["kind"]) == "plastico"
	var paint_um := float(pl["paint_um"])
	var bare := paint_um <= 0.0
	var car := Looks.car_paint(panel_id)
	m.set_shader_parameter("total_mm", _total_mm)
	m.set_shader_parameter("metal_mm", float(pl["t_mm"]))
	# Las capas de la 1.x (barniz, color, imprimación, anticorrosivo) a escala de la pintura del panel
	var lay: Array = Looks.PAINT_LAYERS_UM
	var k := paint_um / float(lay[3])
	m.set_shader_parameter("layers_mm", Vector4(lay[0], lay[1], lay[2], lay[3]) * k / 1000.0)
	if bare:
		# La cara de fuera es el propio acero
		m.set_shader_parameter("paint_color", Color(str(pl["metal"])))
		m.set_shader_parameter("paint_lo", Color(str(pl["metal_lo"])))
		m.set_shader_parameter("flake", 0.0)
	else:
		m.set_shader_parameter("paint_color", Color(str(car["base"])))
		m.set_shader_parameter("paint_lo", Color(str(car["lo"])))
		m.set_shader_parameter("flake", 0.0 if str(car["flake"]) == "" else 1.0)
	m.set_shader_parameter("flake_color", Color(str(car["flake"])) if str(car["flake"]) != "" else Color(1, 1, 1))
	m.set_shader_parameter("clear_color", Color(Looks.CLEAR))
	m.set_shader_parameter("primer_color", Color(Looks.PRIMER))
	m.set_shader_parameter("ecoat_color", Color(Looks.ECOAT))
	m.set_shader_parameter("metal_color", Color(str(pl["metal"])))
	m.set_shader_parameter("metal_lo", Color(str(pl["metal_lo"])))
	m.set_shader_parameter("is_plastic", 1.0 if is_plastic else 0.0)
	m.set_shader_parameter("inner_ecoat", 0.0 if is_plastic or bare else 1.0)
	m.set_shader_parameter("tint_mode", {"acero": 0, "aluminio": 1, "plastico": 2}.get(str(pl["kind"]), 0))


func _apply_result() -> void:
	if mode != "auto":
		return  # en el modo manual el corte lo dibuja el mapa del surco (show_frame); se aplica al volver a «auto»
	var pl := Looks.panel(str(params["panel_id"]))
	var kind := str(pl["kind"])
	var m := _panel_mat
	var tint: Dictionary = result.get("heat_tint", {}) if result.get("heat_tint") is Dictionary else {}
	m.set_shader_parameter("kerf_mm", float(result.get("kerf_mm", 1.0)))
	m.set_shader_parameter("burn_mm", float(result.get("paint_burn_mm", 1.0)))
	m.set_shader_parameter("haz_mm", float(result.get("haz_mm", 1.0)))
	m.set_shader_parameter("temp_c", float(tint.get("temp_c", 200.0)))
	m.set_shader_parameter("tint_mode", {"acero": 0, "aluminio": 1, "plastico": 2}.get(kind, 0))
	m.set_shader_parameter("tint_color", _color_of(tint.get("color"), Color(0.6, 0.62, 0.65)))
	m.set_shader_parameter("glow_c", FRONT_GLOW_C if kind == "acero" else 0.0)
	m.set_shader_parameter("deformation_mm", float(result.get("deformation", 0.0)))
	_disc_mat.set_shader_parameter("loading", float(result.get("disc_loading", 0.0)))
	var stuck := {"aluminio": Color("#D9DFE6"), "plastico": Color("#30343A")}
	_disc_mat.set_shader_parameter("loading_color", stuck.get(kind, Color("#8C95A0")))
	var length := float(params["cut_length_mm"])
	var t_s := float(result.get("time_s", 0.0))
	_feed_eff = length / t_s if t_s > 0.0 else float(params["feed_mm_s"])
	_cut_key = ""
	_rebuild_cut_meshes()
	_configure_effects(_cutting)
	_build_inset_labels()


func _color_of(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return fallback


## Paredes del surco, rebabas e hilos: se rehacen si cambia el surco, el ángulo, la rebaba o la chapa.
func _rebuild_cut_meshes() -> void:
	if result.is_empty():
		return
	var kerf := float(result.get("kerf_mm", 1.0))
	var tilt := tan(deg_to_rad(float(params["angle_deg"])))
	var burr := float(result.get("burr_um", 0.0))
	var melt := _melt()
	var length := float(params["cut_length_mm"])
	var key := "%s|%s|%s|%s|%s|%s|%s" % [kerf, tilt, burr, melt, length, _total_mm, params["disc_id"]]
	if key == _cut_key:
		return
	_cut_key = key
	_legacy_builds += 1
	_panel_mat.set_shader_parameter("tilt_tan", tilt)
	_walls.mesh = PB.build_walls(kerf, tilt, _total_mm, length)
	# Con el disco inclinado, la arista aguda (el lado − si el ángulo es positivo) se dobla más: más rebaba.
	# Es un reparto de dibujo: el contrato da una sola rebaba (ver «Para el coordinador» en fuentes-u14.md).
	var s := sin(deg_to_rad(float(params["angle_deg"])))
	var heights := [burr * (1.0 + 0.6 * s), burr * (1.0 - 0.6 * s)]
	var seed_burr := "rebaba:%s:%s" % [params["panel_id"], params["disc_id"]]
	_burrs.mesh = PB.build_burrs(heights, kerf, tilt, _total_mm, length, melt, seed_burr)
	var seed_threads := "hilos:%s" % params["disc_id"]
	_threads.mesh = PB.build_threads(kerf, tilt, _total_mm, length, melt, seed_threads) if melt > 0.0 else null


## Plástico fundido (0-1): campo `melt` propuesto; si el modelo no lo da, solo lo hay en la chapa de plástico.
func _melt() -> float:
	if result.has("melt"):
		return clampf(float(result["melt"]), 0.0, 1.0)
	return 0.8 if str(Looks.panel(str(params["panel_id"]))["kind"]) == "plastico" else 0.0


## Humo (0-1): campo `smoke` propuesto; si falta, proporcional a la pintura quemada.
func _smoke_amount() -> float:
	if result.has("smoke"):
		return clampf(float(result["smoke"]), 0.0, 1.0)
	return clampf(float(result.get("paint_burn_mm", 0.0)) / 6.0, 0.0, 1.0)


func _configure_effects(active: bool) -> void:
	var vs := PI * float(params["diameter_mm"]) * float(params["rpm"]) / 60000.0
	var sp: Variant = result.get("sparks")
	var sparks: Dictionary = (sp if sp is Dictionary else {}) if active else {"rate": 0.0}
	_emitter.configure(str(params["panel_id"]), sparks, vs)
	var plastic := _melt() > 0.0
	# humo de pintura: gris claro y tenue; de plástico: gris oscuro, espeso
	var col := Color(0.42, 0.41, 0.42, 0.62) if plastic else Color(0.78, 0.76, 0.72, 0.4)
	_smoke.configure(_smoke_amount() if active else 0.0, col)
	var glow_on := active and str(Looks.panel(str(params["panel_id"]))["kind"]) == "acero"
	_glow.visible = glow_on
	_glow_mat.albedo_color = Sparks.heat_color(FRONT_GLOW_C) * Color(1.3, 1.15, 1.0, 0.8)


# ───────────────────────────── cada fotograma ─────────────────────────────


func _process(delta: float) -> void:
	if not _built:
		return
	var dt := delta * time_scale
	if mode == "manual":
		_process_manual(dt)
		return
	if _cutting:
		var length := float(params["cut_length_mm"])
		_cut_mm = minf(_cut_mm + _feed_eff * dt, length)
		if _cut_mm >= length - 1e-6:
			_cutting = false
			_configure_effects(false)
			cut_finished.emit()
	_update_pose()
	_update_spin(dt)
	_step_effects(dt)
	_update_camera()


## Disco y amoladora: el borde delantero del disco toca la cara pintada en el frente del corte.
func _update_pose() -> void:
	var r := float(params["diameter_mm"]) / 2.0
	var yc := r - (_total_mm + PLUNGE_BELOW_MM)
	var chord_top := sqrt(maxf(r * r - yc * yc, 0.0))
	var chord_bottom := sqrt(maxf(r * r - (yc + _total_mm) * (yc + _total_mm), 0.0))
	var u_center := _cut_mm - chord_top
	var alpha := deg_to_rad(float(params["angle_deg"]))
	var n := PB.normal(u_center, 0.0)
	var t := (PB.surface(u_center + 1.0, 0.0) - PB.surface(u_center - 1.0, 0.0)).normalized()
	var lateral := t.cross(n).normalized()
	var n_t := n.rotated(t, -alpha)
	var l_t := lateral.rotated(t, -alpha)
	var center := PB.surface(u_center, 0.0) + n_t * (yc / 1000.0)
	_grinder.transform = Transform3D(Basis(t, n_t, l_t), center)
	var front := PB.surface(_cut_mm, 0.0)
	var n_front := PB.normal(_cut_mm, 0.0)
	_pose = {
		"center": center, "axis": l_t, "radius": r / 1000.0, "contact": front + n_front * 0.0002,
		"normal": n_front, "spin": 1.0, "kerf": float(result.get("kerf_mm", 1.0)) / 1000.0,
		"u_front": _cut_mm, "u_front_bottom": u_center + chord_bottom, "t": t, "n": n, "l": lateral,
	}
	_panel_mat.set_shader_parameter("front_top_mm", _cut_mm if _started else 0.0)
	_panel_mat.set_shader_parameter("front_bottom_mm", clampf(u_center + chord_bottom, 0.0, _cut_mm) if _started else 0.0)
	_glow.position = front + n_front * 0.0004


## Giro que se ve: el real si es lento; si no, el de un estroboscopio (el disco avanza despacio y nítido).
func _update_spin(dt: float) -> void:
	var rps := float(params["rpm"]) / 60.0
	var shown := rps if _strobe_hz <= 0.0 else STROBE_APPARENT_RPS
	_spin_angle = fposmod(_spin_angle + TAU * shown * dt, TAU)
	_disc_mat.set_shader_parameter("spin", _spin_angle)
	_disc_mat.set_shader_parameter("blur", 0.0 if _strobe_hz > 0.0 else minf(TAU * rps / 60.0, 1.5))
	if _label_pivot != null:
		_label_pivot.rotation = Vector3(0.0, 0.0, _spin_angle)


func _step_effects(dt: float) -> void:
	_emitter.set_pose(_pose)
	_emitter.step(dt)
	var width := 0.0012 if view == "general" else 0.0006
	var mm := _sparks_mmi.multimesh
	mm.buffer = _emitter.buffer(SPARK_EXPOSURE_S, width, Sparks.MAX_SPARKS)
	mm.visible_instance_count = _emitter.count()
	var sources := PackedVector3Array()
	if _cutting and _cut_mm > 0.0:
		var half := PB.kerf_half(float(result.get("kerf_mm", 1.0)), tan(deg_to_rad(float(params["angle_deg"]))))
		for k in 6:
			var u := maxf(_cut_mm - 2.5 * float(k), 0.0)
			for side: float in [-1.0, 1.0]:
				sources.append(PB.surface(u, side * (half + 0.5)) + PB.normal(u, 0.0) * 0.0004)
	_smoke.step(dt, sources, PB.normal(_cut_mm, 0.0))
	var sm := _smoke_mmi.multimesh
	sm.buffer = _smoke.buffer(Smoke.MAX_PUFFS)
	sm.visible_instance_count = _smoke.count()


# ───────────────────────────── modo manual ─────────────────────────────


## Pasa al modo manual: el material y las mallas del mapa del surco, las marcas del escenario de las chispas, y ni una
## chispa ni una bocanada del corte automático.
func _enter_manual() -> void:
	_cutting = false
	_panel.material_override = _cutmap.material
	for mi: MeshInstance3D in [_walls, _burrs, _threads]:
		mi.visible = false
	for mi: MeshInstance3D in [_m_walls, _m_burrs]:
		mi.visible = true
	_hazards.visible = true
	_emitter.reset()
	_smoke.reset()
	_emitter.configure(str(params["panel_id"]), { "rate": 0.0 }, 0.0)
	_smoke.configure(0.0, Color(0.5, 0.5, 0.5, 0.4))
	_glow.visible = false
	_glow_c = 0.0
	_focus_ready = false
	if manual != null and frame.is_empty():
		frame = manual.get("frame")
	_build_manual_scene()


## Vuelve al corte automático de siempre (la demostración): el corte hecho a mano queda en el mapa para cuando vuelva.
func _enter_auto() -> void:
	_panel.material_override = _panel_mat
	for mi: MeshInstance3D in [_m_walls, _m_burrs, _m_threads]:
		mi.visible = false
	for mi: MeshInstance3D in [_walls, _burrs, _threads]:
		mi.visible = true
	_hazards.visible = false
	_apply_params()
	_apply_result()
	_update_pose()


## Mallas del mapa del surco para la chapa y el disco de ahora (solo si cambian), marcas del escenario y color de lo
## que embota el disco.
func _build_manual_scene() -> void:
	var panel_id := str(params["panel_id"])
	var pl := Looks.panel(panel_id)
	var kind := str(pl["kind"])
	var kerf := float(frame.get("kerf_mm", float(Looks.disc(str(params["disc_id"]))["t_mm"]) + Radial.KERF_EXTRA_MM))
	_cutmap.build_meshes(_m_walls, _m_burrs, _m_threads, panel_id, kind == "plastico", _total_mm, PB.U_MAX, kerf)
	_m_threads.visible = _m_threads.visible and mode == "manual"
	var rescue := str(Panels.get_panel(panel_id).get("group", "")) == "rescate"
	var key := "%s|%s" % [panel_id, rescue]
	if key != _hazard_key:
		_hazard_key = key
		Hazards.build(_hazards, rescue, PB.U_MAX)
	var stuck := {"aluminio": Color("#D9DFE6"), "plastico": Color("#30343A")}
	_disc_mat.set_shader_parameter("loading_color", stuck.get(kind, Color("#8C95A0")))
	_cutmap.material.set_shader_parameter("through_mm", float(frame.get("total_mm", _total_mm)))


func _process_manual(dt: float) -> void:
	if frame.is_empty():
		if manual == null:
			_update_camera()
			return
		frame = manual.get("frame")
	_sync_manual_setup()
	if manual != null:
		_cutmap.upload(manual.call("texture_data"), int(manual.get("n")), int(frame.get("map_version", 0)))
	_update_manual_pose()
	var rpm := float(frame.get("rpm", 0.0))
	params["rpm"] = rpm
	var rps := rpm / 60.0
	_strobe_hz = rps - STROBE_APPARENT_RPS if rps > STROBE_MIN_RPS else 0.0
	_update_spin(dt)
	_manual_effects(dt)
	# La cámara sigue al disco (un poco por delante de su punto más bajo y más arriba si está apartado)
	var u := float(frame.get("u_mm", 0.0))
	var fu := clampf(u + 22.0, -60.0, PB.U_MAX + 60.0)
	var goal := PB.surface(fu, 0.0) + PB.normal(clampf(fu, 0.0, PB.U_MAX), 0.0) * (minf(float(frame.get("gap_mm", 0.0)), 60.0) * 0.6 / 1000.0)
	if not _focus_ready:
		_focus = goal
		_focus_ready = true
	else:
		_focus = _focus.lerp(goal, 1.0 - exp(-dt / FOCUS_TAU_S))
	_update_camera()
	# Los rótulos a escala se rehacen cuando se ha dejado de cortar un rato (LABELS_IDLE_S), no en cada fotograma ni cada
	# vez que el disco alcanza a la mano un instante
	var cutting := bool(frame.get("cutting", false))
	if cutting:
		_last_cut_frame = frame
		_was_cutting = true
		_idle_s = 0.0
	elif _was_cutting:
		_idle_s += dt
		if _idle_s >= LABELS_IDLE_S:
			_was_cutting = false
			_refresh_manual_labels()


## El disco, el diámetro o la chapa de la salida del core han cambiado: se rehace lo que toca (solo entonces).
func _sync_manual_setup() -> void:
	var changed := false
	var disc_changed := false
	for k in ["disc_id", "diameter_mm", "panel_id"]:
		if frame.has(k) and params.get(k) != frame[k]:
			params[k] = frame[k]
			changed = true
			disc_changed = disc_changed or k != "panel_id"
	params["angle_deg"] = float(frame.get("tilt_deg", 0.0))
	if changed:
		var old_panel := _panel_key
		_apply_params()
		if _panel_key == old_panel:
			_build_manual_scene()
		if disc_changed:
			_loading_shown = 0.0
		_refresh_manual_labels()
	_cutmap.material.set_shader_parameter("through_mm", float(frame.get("total_mm", _total_mm)))


## Amoladora y chispas en la pose que da el core: punto más bajo del disco en u y a su profundidad, inclinación sobre
## la línea de corte y giro alrededor de la normal de la chapa.
func _update_manual_pose() -> void:
	var r := float(params["diameter_mm"]) / 2.0
	var u := float(frame.get("u_mm", 0.0))
	var depth := float(frame.get("depth_mm", -30.0))
	var alpha := deg_to_rad(float(frame.get("tilt_deg", 0.0)))
	var psi := deg_to_rad(float(frame.get("yaw_deg", 0.0)))
	var n := PB.normal(u, 0.0)
	var t := PB.surface(u + 1.0, 0.0) - PB.surface(u - 1.0, 0.0)
	t = (t - n * t.dot(n)).normalized()
	var lat := t.cross(n).normalized()
	var t_y := (t * cos(psi) + lat * sin(psi)).normalized()
	var l_y := t_y.cross(n).normalized()
	var n_t := n.rotated(t_y, -alpha)
	var l_t := l_y.rotated(t_y, -alpha)
	var center := PB.surface(u, 0.0) + n_t * ((r - depth / maxf(cos(alpha), 1e-6)) / 1000.0)
	_grinder.transform = Transform3D(Basis(t_y, n_t, l_t), center)
	var contact := PB.surface(u, 0.0) - n * (maxf(depth, 0.0) / 1000.0)
	var nrm := n
	var exit: Dictionary = frame.get("spark_exit", {})
	if not exit.is_empty():
		var ue := float(exit["u_mm"])
		var ne := PB.normal(ue, 0.0)
		nrm = -ne if str(exit["side"]) == "abajo" else ne
		contact = PB.surface(ue, 0.0) - ne * (float(exit["depth_mm"]) / 1000.0) + nrm * 0.0002
	var front_u := float(frame.get("front_u_mm", u))
	_pose = {
		"center": center, "axis": l_t, "radius": r / 1000.0, "contact": contact, "normal": nrm, "spin": 1.0,
		"kerf": float(frame.get("kerf_mm", 1.0)) / 1000.0, "u_front": front_u, "t": t, "n": n, "l": lat,
	}
	_glow.position = PB.surface(front_u, 0.0) + PB.normal(front_u, 0.0) * 0.0004


## Chispas, humo, brillo del frente, color del borde del surco y embotamiento del disco de este paso (partículas y
## parámetros de shader: nada de nodos ni mallas).
func _manual_effects(dt: float) -> void:
	var cutting := bool(frame.get("cutting", false))
	var panel_id := str(params["panel_id"])
	var kind := str(Looks.panel(panel_id)["kind"])
	var sp: Dictionary = frame.get("sparks", {}) if cutting else {}
	var rate := float(sp.get("rate", 0.0)) * _particles
	var sparks := { "rate": 0.0 }
	if rate > 0.0:
		sparks = sp.duplicate()
		sparks["rate"] = rate
	_emitter.configure(panel_id, sparks, float(frame.get("vs_ms", 0.0)))
	var col := Color(0.42, 0.41, 0.42, 0.62) if kind == "plastico" else Color(0.78, 0.76, 0.72, 0.4)
	_smoke.configure(float(frame.get("smoke", 0.0)) * _smoke_scale if cutting else 0.0, col)
	# Temperatura del frente: la del modelo (front_temp_c: 1.250 °C en el acero, 575 °C en el aluminio, 300 °C en el
	# plástico, de panels.gd); al dejar de cortar, el brillo se apaga (dibujo)
	_glow_c = float(frame.get("front_temp_c", Radial.T_AMBIENT)) if cutting else maxf(_glow_c - GLOW_FADE_C_S * dt, 0.0)
	_glow.visible = _glow_c > 420.0
	_glow_mat.albedo_color = Sparks.heat_color(_glow_c) * Color(1.3, 1.15, 1.0, 0.8)
	var cm := _cutmap.material
	cm.set_shader_parameter("glow_c", _glow_c)
	cm.set_shader_parameter("glow_u_mm", float(frame.get("front_u_mm", 0.0)))
	if cutting:
		var tint: Dictionary = frame.get("heat_tint", {})
		cm.set_shader_parameter("temp_c", float(tint.get("temp_c", Radial.T_AMBIENT)))
		cm.set_shader_parameter("tint_color", _color_of(tint.get("color"), Color(0.6, 0.62, 0.65)))
		_loading_shown = maxf(_loading_shown, float(frame.get("disc_loading", 0.0)))
	_disc_mat.set_shader_parameter("loading", _loading_shown)
	_emitter.set_pose(_pose)
	_emitter.step(dt)
	var width := 0.0012 if view == "general" else 0.0006
	var mm := _sparks_mmi.multimesh
	mm.buffer = _emitter.buffer(SPARK_EXPOSURE_S, width, Sparks.MAX_SPARKS)
	mm.visible_instance_count = _emitter.count()
	var fu := clampf(float(frame.get("front_u_mm", 0.0)), 0.0, PB.U_MAX)
	var sources := PackedVector3Array()
	if cutting:
		var dir := float(frame.get("feed_dir", 0))
		if dir == 0.0:
			dir = 1.0
		var half := 0.5 * float(frame.get("kerf_surface_mm", 1.4))
		for k in 6:
			var us := clampf(fu - dir * 2.5 * float(k), 0.0, PB.U_MAX)
			for side: float in [-1.0, 1.0]:
				sources.append(PB.surface(us, side * (half + 0.5)) + PB.normal(us, 0.0) * 0.0004)
	_smoke.step(dt, sources, PB.normal(fu, 0.0))
	var sm := _smoke_mmi.multimesh
	sm.buffer = _smoke.buffer(Smoke.MAX_PUFFS)
	sm.visible_instance_count = _smoke.count()


## Rótulos de las vistas a escala con las condiciones del último corte (al dejar de cortar o al cambiar de montaje).
func _refresh_manual_labels() -> void:
	var f := _last_cut_frame if not _last_cut_frame.is_empty() else frame
	result = {
		"kerf_mm": float(f.get("kerf_mm", 1.0)), "paint_burn_mm": float(f.get("paint_burn_mm", 0.0)),
		"burr_um": float(f.get("burr_um", 0.0)), "haz_mm": float(f.get("haz_mm", 0.0)),
		"heat_tint": f.get("heat_tint", {}) if (f.get("heat_tint", {}) as Dictionary).size() > 0 else { "temp_c": Radial.T_AMBIENT },
	}
	_build_inset_labels()


## Lo que la entrada necesita de la vista: cuántos píxeles de pantalla son un mm a lo largo de la línea de corte y
## hacia fuera de la chapa, junto al disco, y a qué distancia está el disco de la chapa (también para una demo que
## simule el ratón con eventos de verdad).
func input_geometry() -> Dictionary:
	var u := clampf(float(frame.get("u_mm", 0.0)), 0.0, PB.U_MAX)
	var geo := { "px_u": Vector2(4.0, 0.0), "px_n": Vector2(0.0, -4.0), "gap_mm": float(frame.get("gap_mm", 0.0)),
		"engaged": float(frame.get("depth_mm", -1.0)) > 0.0 }
	if _camera == null or not is_inside_tree():
		return geo
	var a := PB.surface(u, 0.0)
	var n := PB.normal(u, 0.0)
	var t := (PB.surface(u + 1.0, 0.0) - PB.surface(u - 1.0, 0.0)).normalized()
	var sa := _camera.unproject_position(a)
	geo["px_u"] = (_camera.unproject_position(a + t * 0.010) - sa) / 10.0
	geo["px_n"] = (_camera.unproject_position(a + n * 0.010) - sa) / 10.0
	return geo


func _unhandled_input(event: InputEvent) -> void:
	if not _built or mode != "manual" or not input_enabled:
		return
	var act := _hand.handle(event, input_geometry())
	if not bool(act["handled"]):
		return
	get_viewport().set_input_as_handled()
	var mv: Vector2 = act["move"]
	var tn: Vector2 = act["turn"]
	if manual != null:
		if mv != Vector2.ZERO:
			manual.call("move_hand", mv.x, mv.y)
		if tn != Vector2.ZERO:
			manual.call("turn_hand", tn.x, tn.y)
	var ob: Vector2 = act["orbit"]
	if ob != Vector2.ZERO:
		_orbit_yaw += ob.x
		_orbit_pitch = clampf(_orbit_pitch + ob.y, -70.0, 70.0)
	var pn: Vector2 = act["pan"]
	if pn != Vector2.ZERO and _camera != null:
		var b := _camera.global_transform.basis
		var dist := (_camera.global_position - _focus).length()
		_orbit_pan += (-b.x * pn.x + b.y * pn.y) * dist * 0.0015
	var zm := float(act["zoom"])
	if zm != 1.0:
		_orbit_zoom = clampf(_orbit_zoom * zm, 0.15, 6.0)
	var dial := int(act["dial"])
	if dial != 0:
		dial_step_requested.emit(dial)
	if bool(act["gesture_end"]):
		gesture_finished.emit()


## La vista pedida girada, desplazada y con el zoom que ha puesto el ratón (solo la cámara principal).
func _orbited(eye: Vector3, target: Vector3, up: Vector3) -> Array:
	var off := eye - target
	off = off.rotated(up, deg_to_rad(-_orbit_yaw))
	var right := off.cross(up)
	if right.length_squared() > 1e-12:
		off = off.rotated(right.normalized(), deg_to_rad(_orbit_pitch))
	off *= _orbit_zoom
	return [target + off + _orbit_pan, target + _orbit_pan]


# ───────────────────────────── cámaras ─────────────────────────────


func _update_camera() -> void:
	if _pose.is_empty():
		return
	_place_camera(_camera, view)
	for k in _inset_cams:
		_place_camera(_inset_cams[k], k)


## Extensión (mm) que enseñan las vistas a escala: [ancho, alto] mínimos.
func _scale_view_mm(v: String) -> Vector2:
	var kerf := float(result.get("kerf_mm", 1.0))
	var burn := float(result.get("paint_burn_mm", 1.0))
	var burr := float(result.get("burr_um", 0.0)) / 1000.0
	if v == "canto":
		return Vector2(kerf + 2.0 * clampf(burn, 1.0, 3.2) + 1.4, _total_mm + 1.6 * burr + 1.1)
	var across := kerf + 2.0 * maxf(burn, float(result.get("haz_mm", 1.0))) + 2.4
	return Vector2(across * 1.25, across)


## Tamaño en píxeles de lo que enseña una cámara (la principal: la ventana; las de los recuadros: INSET_SIZE).
func _cam_px(cam: Camera3D) -> Vector2:
	if cam == _camera and is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(INSET_SIZE)


func _cam_aspect(cam: Camera3D) -> float:
	var px := _cam_px(cam)
	return px.x / maxf(px.y, 1.0)


func _place_camera(cam: Camera3D, v: String) -> void:
	var t: Vector3 = _pose["t"]
	var n: Vector3 = _pose["n"]
	var l: Vector3 = _pose["l"]
	var front := PB.surface(_cut_mm, 0.0) if mode == "auto" else _focus
	var tilt := tan(deg_to_rad(float(params["angle_deg"])))
	var main := cam == _camera
	match v:
		"detalle":
			# Del lado de la etiqueta, algo por encima: la mitad de abajo del disco, el frente del corte con el haz de
			# chispas saliendo hacia delante (a la derecha de la pantalla) y la pintura quemada a este lado del surco.
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 40.0
			cam.near = 0.004
			cam.far = 6.0
			var target := front - t * 0.010 + n * 0.050
			var eye := front + t * 0.020 + n * 0.105 + l * 0.255
			if main:
				var o := _orbited(eye, target, n)
				eye = o[0]
				target = o[1]
			cam.look_at_from_position(eye, target, n)
		"general":
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 45.0
			cam.near = 0.01
			cam.far = 12.0
			var target := front - t * 0.07 + n * 0.06
			var eye := front + t * 0.08 + n * 0.24 + l * 0.42
			if main:
				var o := _orbited(eye, target, n)
				eye = o[0]
				target = o[1]
			cam.look_at_from_position(eye, target, n)
		"canto":
			# Ortográfica y recortada: solo los primeros 2,5 mm detrás del canto (la sección), sin el disco detrás.
			var ext := _scale_view_mm("canto")
			var burr := float(result.get("burr_um", 0.0)) / 1000.0
			var d_mid := 0.5 * (_total_mm + burr)
			var target := PB.inside(0.0, tilt * d_mid, d_mid)
			var t0 := (PB.surface(1.0, 0.0) - PB.surface(0.0, 0.0)).normalized()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = maxf(ext.y, ext.x / _cam_aspect(cam)) / 1000.0
			cam.near = 0.079
			cam.far = 0.0825
			cam.look_at_from_position(target - t0 * 0.08, target, PB.normal(0.0, 0.0))
		"cenital":
			# Ortográfica desde arriba, recortada a una loncha alrededor de la chapa (sin la amoladora encima).
			var ext := _scale_view_mm("cenital")
			var target := PB.surface(_top_u, 0.0)
			var n0 := PB.normal(_top_u, 0.0)
			var t0 := (PB.surface(_top_u + 1.0, 0.0) - PB.surface(_top_u - 1.0, 0.0)).normalized()
			var l0 := t0.cross(n0).normalized()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = maxf(ext.y, ext.x / _cam_aspect(cam)) / 1000.0
			cam.near = 0.074
			cam.far = 0.092
			cam.look_at_from_position(target + n0 * 0.08, target, -l0)


# ───────────────────────────── rótulos de los recuadros ─────────────────────────────


## Rótulos de las vistas a escala: los de los recuadros y, si la vista principal es «canto» o «cenital», los suyos.
func _build_inset_labels() -> void:
	if not _built:
		return
	for holder in [_canto_labels, _top_labels, _main_labels]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	if result.is_empty():
		return
	var inset_px := Vector2(INSET_SIZE)
	_build_canto_labels(_canto_labels, CANTO_LAYER, inset_px, 12.0)
	_build_top_labels(_top_labels, TOP_LAYER, inset_px, 12.0)
	if view == "canto":
		_build_canto_labels(_main_labels, MAIN_SCALE_LAYER, _cam_px(_camera), 18.0)
	elif view == "cenital":
		_build_top_labels(_main_labels, MAIN_SCALE_LAYER, _cam_px(_camera), 18.0)


## Sección (canto): pintura, chapa, surco, pintura quemada, rebaba y la barra de escala, delante del canto u = 0.
## px: tamaño en píxeles de la vista; text_px: altura de la letra en píxeles.
func _build_canto_labels(holder: Node3D, layer: int, px: Vector2, text_px: float) -> void:
	var pl := Looks.panel(str(params["panel_id"]))
	var kerf := float(result.get("kerf_mm", 1.0))
	var burn := float(result.get("paint_burn_mm", 1.0))
	var burr := float(result.get("burr_um", 0.0))
	var tilt := tan(deg_to_rad(float(params["angle_deg"])))
	var half := PB.kerf_half(kerf, tilt)
	var ext := _scale_view_mm("canto")
	var aspect := px.x / maxf(px.y, 1.0)
	var view_h := maxf(ext.y, ext.x / aspect)
	var view_w := view_h * aspect
	var text_h := view_h * text_px / maxf(px.y, 1.0)
	var burr_mm := burr / 1000.0
	var d_mid := 0.5 * (_total_mm + burr_mm)
	var top := d_mid - view_h * 0.5  # profundidad del borde de arriba del recuadro (negativa: por encima)
	var bottom := d_mid + view_h * 0.5
	var basis := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))  # mirando hacia −u
	var u := -0.3
	var side_v := -half - 0.25
	# pintura del panel (0 en las piezas de rescate, de acero desnudo: entonces no se rotula pintura)
	var paint := float(pl["paint_um"])
	var line_gap := text_h * 1.25
	var left := HORIZONTAL_ALIGNMENT_LEFT
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	if paint > 0.0:
		_label_at(holder, layer, "pintura %s µm ↓" % _es(paint, 0),
			PB.inside(u, -view_w * 0.47, top + line_gap * 0.9), basis, Palette.color("text"), text_h, left)
	# el material, escrito sobre la propia chapa (a media altura del metal), para que no choque con la rebaba
	var metal_mid := paint / 1000.0 + float(pl["t_mm"]) * 0.5 + text_h * 0.35
	_label_at(holder, layer, "%s %s mm" % [str(pl["short"]), _es(float(pl["t_mm"]), 2)],
		PB.inside(u, -view_w * 0.47, metal_mid), basis, Palette.color("text"), text_h, left)
	_label_at(holder, layer, "surco %s mm" % _es(kerf, 2),
		PB.inside(u, tilt * d_mid, top + line_gap * 2.0), basis, Palette.color("mint"), text_h, HORIZONTAL_ALIGNMENT_CENTER)
	if paint > 0.0:
		_label_at(holder, layer, "quemada %s mm" % _es(burn, 1),
			PB.inside(u, view_w * 0.47, top + line_gap * 0.9), basis, Palette.color("gold"), text_h, right)
	var burr_txt := "rebaba %s µm" % _es(burr, 0)
	if burr >= 1000.0:
		burr_txt = "rebaba %s mm" % _es(burr_mm, 1)
	_label_at(holder, layer, burr_txt,
		PB.inside(u, side_v, _total_mm + burr_mm + line_gap * 0.8), basis, Palette.color("rose"), text_h, right)
	_scale_bar(holder, layer, view_w, PB.inside(u, view_w * 0.47, bottom - line_gap * 0.45), basis, text_h)


## Vista cenital: el surco visto desde arriba con la pintura quemada y el color de revenido, y la barra de escala.
func _build_top_labels(holder: Node3D, layer: int, px: Vector2, text_px: float) -> void:
	var kerf := float(result.get("kerf_mm", 1.0))
	var burn := float(result.get("paint_burn_mm", 1.0))
	var tint: Dictionary = result.get("heat_tint", {}) if result.get("heat_tint") is Dictionary else {}
	var ext := _scale_view_mm("cenital")
	var aspect := px.x / maxf(px.y, 1.0)
	var view_h := maxf(ext.y, ext.x / aspect)
	var view_w := view_h * aspect
	var text_h := view_h * text_px / maxf(px.y, 1.0)
	var n0 := PB.normal(_top_u, 0.0)
	var t0 := (PB.surface(_top_u + 1.0, 0.0) - PB.surface(_top_u - 1.0, 0.0)).normalized()
	var l0 := t0.cross(n0).normalized()
	var basis := Basis(t0, -l0, n0)
	var lift := 0.002
	var half := PB.kerf_half(kerf, tan(deg_to_rad(float(params["angle_deg"]))))
	var left_u := _top_u - view_w * 0.47
	var right_u := _top_u + view_w * 0.47
	# arriba en pantalla es −v
	var up_v := -view_h * 0.5 + text_h * 1.1
	var down_v := view_h * 0.5 - text_h * 0.9
	if float(Looks.panel(str(params["panel_id"]))["paint_um"]) > 0.0:
		_label_at(holder, layer, "pintura quemada %s mm" % _es(burn, 1),
			PB.surface(left_u, up_v) + n0 * lift, basis, Palette.color("gold"), text_h, HORIZONTAL_ALIGNMENT_LEFT)
	var tint_txt := "%s °C en el borde del surco" % _es(float(tint.get("temp_c", 0.0)), 0)
	_label_at(holder, layer, tint_txt,
		PB.surface(left_u, down_v) + n0 * lift, basis, Palette.color("ice"), text_h, HORIZONTAL_ALIGNMENT_LEFT)
	var kerf_at := PB.surface(right_u, -half - text_h * 0.9) + n0 * lift
	_label_at(holder, layer, "surco %s mm" % _es(kerf, 2),
		kerf_at, basis, Palette.color("mint"), text_h, HORIZONTAL_ALIGNMENT_RIGHT)
	_scale_bar(holder, layer, view_w, PB.surface(right_u, up_v - text_h * 0.35) + n0 * lift, basis, text_h)


## Rótulo plano de un recuadro a escala; height_mm: altura de la letra en mm de la escena.
func _label_at(
	holder: Node3D, layer: int, text: String, pos: Vector3, basis: Basis, color: Color, height_mm: float,
	align: HorizontalAlignment
) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 48
	l.pixel_size = height_mm / 1000.0 / 48.0 * 1.35
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0.09, 0.05, 0.11, 0.9)
	l.horizontal_alignment = align
	l.layers = 1 << (layer - 1)
	l.no_depth_test = true
	l.transform = Transform3D(basis, pos)
	holder.add_child(l)


## Barra de escala (0,5, 1, 2 o 5 mm, la que ocupe ~1/5 del recuadro) con su rótulo, acabando en `end_pos`.
func _scale_bar(holder: Node3D, layer: int, view_w_mm: float, end_pos: Vector3, basis: Basis, text_h: float) -> void:
	var length := 0.5
	for cand in [0.5, 1.0, 2.0, 5.0, 10.0]:
		if cand <= view_w_mm * 0.24:
			length = cand
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, text_h * 0.22, text_h * 0.05) / 1000.0
	bar.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Palette.color("text")
	mat.no_depth_test = true
	bar.material_override = mat
	bar.layers = 1 << (layer - 1)
	var x := basis.x
	var y := basis.y
	bar.transform = Transform3D(basis, end_pos - x * (length * 0.5 / 1000.0) - y * (text_h * 0.45 / 1000.0))
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bar)
	var txt := "%s mm" % (_es(length, 1) if length < 1.0 else _es(length, 0))
	var at := end_pos - x * (length * 0.5 / 1000.0) + y * (text_h * 0.35 / 1000.0)
	_label_at(holder, layer, txt, at, basis, Palette.color("text"), text_h, HORIZONTAL_ALIGNMENT_CENTER)


## Número de los rótulos de las vistas a escala, con coma decimal como el resto de la interfaz del taller
## (Js.to_fixed: el redondeo de JavaScript).
static func _es(x: float, decimals: int) -> String:
	return Js.to_fixed(x, decimals).replace(".", ",")
