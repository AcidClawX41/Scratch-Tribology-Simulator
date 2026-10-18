## Torno 3D del Taller industrial (unidad 9): bancada, cabezal con plato de 3 garras que gira a las rpm (con
## efecto estroboscópico controlado a rpm altas), contrapunto, carro y charriot, torreta con plaquita, pieza con
## malla dinámica y acabado según Ra, virutas, refrigerante, nave de taller como entorno y cámara orbital.
##
## La escena no calcula mecanizado: pinta lo que le dice una fuente de perfil (el núcleo del torno, unidad 3, o
## la fuente simulada de la demo) y lo que le pasa la interfaz.
##
## API pública (coordenadas del torno en mm, r en radio; CONTRATOS.md):
##   set_profile_source(obj)   cualquier objeto con profile() → perfil del contrato. Si además tiene
##                             tool_pose() → Vector2(r, z) o {r, z}, la escena la lee en cada fotograma.
##   set_rpm(rpm)              giro del cabezal (negativo: al revés)
##   set_tool_pose(r, z)       punta teórica de la herramienta
##   set_cutting(on, pc_kw)    ¿está cortando?, potencia de corte (kW): caudal de virutas
##   set_overlay(name)         "acabado" | "desviacion"
##   set_view(name)            "frontal" | "superior" | "detalle" | "general"
## Además: set_work_material(kind), set_plan(banda), set_coolant(on), set_chuck_grip(mm), set_feed(f_mm),
## set_nose_radius(mm), set_tool_shape(herramienta de lathe_tools.gd), set_thread_pitch(mm con signo) y
## configure_lod(lados, anillos).
extends Node3D

const Machine = preload("res://app/taller/lathe3d/machine.gd")
const Workpiece = preload("res://app/taller/lathe3d/workpiece.gd")
const ChipView = preload("res://app/taller/lathe3d/chip_view.gd")
const Coolant = preload("res://app/taller/lathe3d/coolant.gd")
const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")

const OVERLAYS := {"acabado": 0, "desviacion": 1}
## Efecto estroboscópico controlado: por debajo de STROBE_START grados por fotograma las garras giran de verdad;
## por encima se van desenfocando y su giro aparente se frena hasta STROBE_APPARENT_RPS vueltas por segundo en
## el sentido real (en vez del aliasing, que las haría parecer quietas o marcha atrás).
const STROBE_START_DEG := 18.0
const STROBE_FULL_DEG := 75.0
const STROBE_APPARENT_RPS := 0.35
## Dirección media de salida de la viruta: resbala por la cara de desprendimiento hacia el operario (+z) y el
## rompevirutas la levanta y la curva (+y).
const CHIP_FLOW := Vector3(0.12, 0.85, 1.0)

## Aspecto de cada material de pieza (kind de CONTRATOS.md) para acabado.gdshader. F0 de los metales mecanizados
## en sRGB lineal (Hoffman 2015; latón e inoxidable: estimación); el aspecto del bruto es una estimación visual.
const WORK_LOOKS := {
	"acero": {"metal_f0": Vector3(0.562, 0.565, 0.578), "metallic_amount": 1.0, "raw_color": Vector3(0.075, 0.078, 0.086), "raw_patch_color": Vector3(0.14, 0.105, 0.08), "raw_metallic": 0.4, "raw_roughness": 0.6, "raw_lay": 0.0},
	"inox": {"metal_f0": Vector3(0.60, 0.59, 0.57), "metallic_amount": 1.0, "raw_color": Vector3(0.45, 0.44, 0.43), "raw_patch_color": Vector3(0.40, 0.39, 0.38), "raw_metallic": 1.0, "raw_roughness": 0.42, "raw_lay": 1.0},
	"fundicion": {"metal_f0": Vector3(0.40, 0.40, 0.41), "metallic_amount": 0.85, "raw_color": Vector3(0.11, 0.105, 0.10), "raw_patch_color": Vector3(0.16, 0.12, 0.09), "raw_metallic": 0.2, "raw_roughness": 0.85, "raw_lay": 0.0},
	"aluminio": {"metal_f0": Vector3(0.913, 0.922, 0.924), "metallic_amount": 1.0, "raw_color": Vector3(0.62, 0.63, 0.63), "raw_patch_color": Vector3(0.55, 0.56, 0.56), "raw_metallic": 1.0, "raw_roughness": 0.5, "raw_lay": 1.0},
	"laton": {"metal_f0": Vector3(0.887, 0.789, 0.434), "metallic_amount": 1.0, "raw_color": Vector3(0.55, 0.43, 0.22), "raw_patch_color": Vector3(0.45, 0.33, 0.17), "raw_metallic": 1.0, "raw_roughness": 0.5, "raw_lay": 1.0},
	"titanio": {"metal_f0": Vector3(0.542, 0.497, 0.449), "metallic_amount": 1.0, "raw_color": Vector3(0.30, 0.29, 0.27), "raw_patch_color": Vector3(0.26, 0.24, 0.22), "raw_metallic": 0.8, "raw_roughness": 0.55, "raw_lay": 1.0},
	"niquel": {"metal_f0": Vector3(0.660, 0.609, 0.526), "metallic_amount": 1.0, "raw_color": Vector3(0.36, 0.34, 0.31), "raw_patch_color": Vector3(0.30, 0.28, 0.25), "raw_metallic": 0.8, "raw_roughness": 0.55, "raw_lay": 1.0},
	"madera": {"metal_f0": Vector3(0.55, 0.38, 0.22), "metallic_amount": 0.0, "raw_color": Vector3(0.30, 0.20, 0.11), "raw_patch_color": Vector3(0.24, 0.16, 0.09), "raw_metallic": 0.0, "raw_roughness": 0.85, "raw_lay": 1.0},
	"plastico": {"metal_f0": Vector3(0.85, 0.85, 0.82), "metallic_amount": 0.0, "raw_color": Vector3(0.78, 0.78, 0.75), "raw_patch_color": Vector3(0.74, 0.74, 0.71), "raw_metallic": 0.0, "raw_roughness": 0.45, "raw_lay": 1.0},
	"piedra": {"metal_f0": Vector3(0.52, 0.50, 0.46), "metallic_amount": 0.0, "raw_color": Vector3(0.36, 0.34, 0.31), "raw_patch_color": Vector3(0.30, 0.28, 0.26), "raw_metallic": 0.0, "raw_roughness": 0.9, "raw_lay": 0.0},
	"vidrio": {"metal_f0": Vector3(0.75, 0.80, 0.80), "metallic_amount": 0.0, "raw_color": Vector3(0.62, 0.68, 0.68), "raw_patch_color": Vector3(0.58, 0.64, 0.64), "raw_metallic": 0.0, "raw_roughness": 0.3, "raw_lay": 0.0},
}

@export var lod_sides := 64  ## lados de cada anillo de la pieza (32 en móvil)
@export var lod_max_rings := 2000  ## tope de anillos de la malla de la pieza (800 en móvil)
@export var msaa := true  ## antialiasing 4× en el viewport de la escena

var rpm := 0.0
var tool_r := 34.0  ## mm (radio de la punta teórica)
var tool_z := 8.0  ## mm
var cutting := false
var pc_kw := 0.0
var coolant_on := false
var overlay := "acabado"
var work_kind := "acero"
var grip_mm := 25.0  ## longitud de la pieza dentro del plato

var machine: Machine
var workpiece: Workpiece
var chips: ChipView
var coolant: Coolant

var _source: Object
var _spin_angle := 0.0
var _x0 := -0.076  # x (m) de la escena donde cae Z0 del torno
var _z0 := NAN  # z0 del perfil con el que se colocó la pieza
@onready var _rig: Node3D = $CameraRig


func _ready() -> void:
	if msaa:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_environment()
	machine = Machine.new()
	machine.build($Machine)
	workpiece = Workpiece.new()
	workpiece.configure_lod(lod_sides, lod_max_rings)
	workpiece.scale = Vector3(0.001, 0.001, 0.001)  # la malla va en mm
	machine.spindle.add_child(workpiece)
	chips = ChipView.new()
	add_child(chips)
	chips.set_floor(Machine.TRAY_Y)
	coolant = Coolant.new()
	add_child(coolant)
	coolant.setup(machine.nozzle)
	set_work_material(work_kind)
	_place_tool()
	set_view("frontal", true)


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = true  # solo Forward+; en Mobile y Compatibility se ignora
	env.ssao_radius = 0.25
	env.ssao_intensity = 1.2
	($WorldEnvironment as WorldEnvironment).environment = env
	# Luz principal de la nave: desde arriba, delante y a la izquierda (lado del cabezal)
	var sun := $Sun as DirectionalLight3D
	sun.basis = Basis.looking_at(Vector3(1.2, -3.0, -2.6), Vector3.UP)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 5.0
	# Sonda de reflejos de la zona de trabajo (el plato y la pieza reflejan la máquina, no solo la nave). En
	# Compatibility la captura sale negra (probado con Godot 4.7.2 bajo OpenGL por software), así que allí se
	# apaga y el metal refleja solo el cielo de la nave.
	var probe := $ReflectionProbe as ReflectionProbe
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 1.0
	probe.visible = RenderingServer.get_current_rendering_method() != "gl_compatibility"


# ─── API pública ─────────────────────────────────────────────────────────────────────────────────────────

## Fuente del perfil de la pieza: cualquier objeto con profile() (CONTRATOS.md → Perfil de la pieza).
func set_profile_source(obj: Object) -> void:
	_source = obj
	_z0 = NAN
	if obj != null and obj.has_method("profile"):
		_apply_profile(obj.call("profile"))


func set_rpm(p_rpm: float) -> void:
	rpm = p_rpm


## Punta teórica de la herramienta en coordenadas del torno (mm): r en radio, z con Z0 en la cara acabada.
func set_tool_pose(r: float, z: float) -> void:
	tool_r = r
	tool_z = z
	_place_tool()


func set_cutting(on: bool, p_pc_kw := 0.0) -> void:
	cutting = on
	pc_kw = maxf(p_pc_kw, 0.0)


func set_overlay(overlay_name: String) -> void:
	if not OVERLAYS.has(overlay_name):
		push_warning("Capa desconocida: %s" % overlay_name)
		return
	overlay = overlay_name
	workpiece.finish.set_shader_parameter("overlay", OVERLAYS[overlay_name])


func set_view(view_name: String, instant := false) -> void:
	_rig.set("focus_point", _rig.transform.affine_inverse() * tool_tip_local())  # el detalle arranca ya en la punta
	_rig.call("set_view", view_name, instant)


## Material de la pieza (kind de CONTRATOS.md): aspecto del metal y del bruto, y forma y color de las virutas.
func set_work_material(kind: String) -> void:
	work_kind = kind if WORK_LOOKS.has(kind) else "acero"
	workpiece.set_finish_params(WORK_LOOKS[work_kind])
	chips.set_kind(work_kind)


## Banda de tolerancia del plano ({z0, dz, r_min, r_max}, ver LatheMesh.band_from_segments) para la capa de
## desviación.
func set_plan(band: Dictionary) -> void:
	workpiece.set_plan(band)


func set_coolant(on: bool) -> void:
	coolant_on = on


## Longitud de la pieza dentro del plato (mm): decide dónde queda Z0 respecto a las garras.
func set_chuck_grip(mm: float) -> void:
	grip_mm = maxf(mm, 1.0)
	_z0 = NAN


## Paso real de las marcas de avance (mm/vuelta); 0: se deduce de Ra en el shader.
func set_feed(f_mm: float) -> void:
	workpiece.finish.set_shader_parameter("feed_override_mm", maxf(f_mm, 0.0))


## Radio de punta de la plaquita (mm): forma de las crestas en el shader.
func set_nose_radius(r_mm: float) -> void:
	workpiece.finish.set_shader_parameter("nose_radius_mm", maxf(r_mm, 0.05))


## Paso de la rosca de la pieza (mm, con el signo del sentido de giro; 0: sin rosca): los anillos roscados del perfil
## se dibujan como una hélice (acabado.gdshader).
func set_thread_pitch(p_mm: float) -> void:
	workpiece.finish.set_shader_parameter("thread_pitch_mm", p_mm)


## Plaquita de la herramienta montada (diccionario de lathe_tools.gd): su contorno, con la V de la de roscar.
func set_tool_shape(t: Dictionary) -> void:
	machine.set_insert(t)


func configure_lod(sides: int, max_rings: int) -> void:
	lod_sides = sides
	lod_max_rings = max_rings
	workpiece.configure_lod(sides, max_rings)


## Punta de la herramienta en el marco de este nodo (m): el de la máquina, las virutas y la cámara.
func tool_tip_local() -> Vector3:
	return Vector3(_x0 + tool_z * 0.001, Machine.AXIS_Y, tool_r * 0.001)


## Punta de la herramienta en coordenadas globales (m), p. ej. para la posición del sonido.
func tool_tip_global() -> Vector3:
	return global_transform * tool_tip_local()


## Velocidad de corte (m/min) en la punta: vc = π·D·n/1000.
func cutting_speed() -> float:
	return TAU * maxf(tool_r, 0.0) * absf(rpm) / 1000.0


# ─── fotograma ──────────────────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _source != null:
		if _source.has_method("tool_pose"):
			var tp: Variant = _source.call("tool_pose")
			if tp is Vector2:
				tool_r = (tp as Vector2).x
				tool_z = (tp as Vector2).y
			elif tp is Dictionary:
				tool_r = float((tp as Dictionary).get("r", tool_r))
				tool_z = float((tp as Dictionary).get("z", tool_z))
		if _source.has_method("profile"):
			_apply_profile(_source.call("profile"))
	_spin(delta)
	_place_tool()
	# Virutas, superficies de reposo y cámara van en el marco de este nodo; el refrigerante, en global
	var tip := tool_tip_local()
	var tip_global := global_transform * tip
	chips.tick(delta, cutting and absf(rpm) > 1.0, tip + Vector3(0.0, 0.0012, 0.0006), CHIP_FLOW, pc_kw, rpm, cutting_speed())
	machine.aim_nozzle(($Machine.transform * machine.carriage.transform).affine_inverse() * tip)
	coolant.update(coolant_on, tip_global)
	_rig.set("focus_point", _rig.transform.affine_inverse() * tip)


func _apply_profile(prof: Dictionary) -> void:
	if prof.is_empty():
		return
	var z0 := float(prof.get("z0", 0.0))
	if z0 != _z0:
		# Z0 queda donde lo pone la pieza: su extremo del plato entra grip_mm entre las garras
		_z0 = z0
		_x0 = Machine.JAW_FRONT_X - (z0 + grip_mm) * 0.001
		workpiece.position = Vector3(_x0 - Machine.CHUCK_FACE_X, 0.0, 0.0)
		var rr: PackedFloat64Array = prof.get("r", PackedFloat64Array())
		var dz := float(prof.get("dz", 0.02))
		if rr.size() > 0:
			var gi := clampi(int(round(grip_mm * 0.5 / dz)), 0, rr.size() - 1)
			machine.chuck.set_grip_radius(rr[gi] * 0.001)
		_place_tool()
	workpiece.apply_profile(prof)


## Giro del husillo con el efecto estroboscópico controlado.
func _spin(delta: float) -> void:
	var omega := rpm / 60.0 * TAU  # rad/s
	var per_frame := absf(rad_to_deg(omega * delta))
	var b := clampf((per_frame - STROBE_START_DEG) / (STROBE_FULL_DEG - STROBE_START_DEG), 0.0, 1.0)
	var sgn := signf(omega) if omega != 0.0 else 1.0
	var omega_disp := lerpf(omega, sgn * TAU * STROBE_APPARENT_RPS, b)
	# Positivo alrededor de +x: la cara que mira al operario baja hacia la herramienta (M03 en un torno paralelo)
	_spin_angle = fmod(_spin_angle + omega_disp * delta, TAU)
	machine.spindle.rotation = Vector3(_spin_angle, 0.0, 0.0)
	machine.chuck.set_blur(b, minf(absf(omega * delta) * 0.5, TAU / 3.0), sgn)


## Coloca el carro, el transversal y las superficies de reposo de las virutas según la punta.
func _place_tool() -> void:
	if machine == null:
		return
	var tx := _x0 + tool_z * 0.001
	var tz := tool_r * 0.001
	machine.carriage.position = Vector3(tx, 0.0, 0.0)
	machine.cross_slide.position = Vector3(0.0, 0.0, tz)
	# Volantes: el del carro gira con el avance (piñón de la cremallera, 1 vuelta ≈ 110 mm) y el del transversal
	# con el husillo de 5 mm de paso
	machine.wheel_carriage.rotation.x = -tx / 0.110 * TAU
	machine.wheel_cross.rotation.x = -tz / 0.005 * TAU
	var ty := Machine.AXIS_Y
	chips.set_box(0, Rect2(tx, tz + 0.035, 0.085, 0.085), ty + Machine.TOOLPOST_TOP)
	chips.set_box(1, Rect2(tx, tz + 0.02, 0.12, 0.22), Machine.COMPOUND_TOP)
	chips.set_box(2, Rect2(tx, tz - 0.08, 0.18, 0.40), Machine.CROSS_TOP)
	chips.set_box(3, Rect2(tx - 0.03, -0.21, 0.34, 0.415), Machine.SADDLE_TOP)
	chips.set_box(4, Rect2(tx - 0.03, 0.205, 0.34, 0.095), Machine.SADDLE_TOP - 0.003)
	chips.set_box(5, Rect2(Machine.HEAD_FACE_X, -0.19, 1.31, 0.38), Machine.BED_TOP)
