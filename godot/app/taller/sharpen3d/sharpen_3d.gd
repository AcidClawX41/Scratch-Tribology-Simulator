## Afiladora 3D del Taller industrial: la máquina (esmeriladora de banco, afiladora húmeda lenta, amoladora con disco
## de láminas, afiladora de brocas o de fresas), la herramienta (cuchillo, hacha, cuchilla de cortacésped, broca o
## fresa) y el contacto: la muela girando a sus rpm (con desenfoque de movimiento, sin efecto estroboscópico), el
## bisel al ángulo pedido, las chispas (core/taller/sparks.gd; en húmedo, ninguna), el agua de la bandeja, los colores
## de revenido, la incandescencia del filo y la rebaba.
##
## La escena no calcula física: pinta los diccionarios de vista de CONTRATOS.md («Vista 3D de la afiladora»), que en
## la aplicación construye la oleada 2 con sharpening_machines.gd (view()) y sharpening_sim.gd:
##   set_machine(view)  { kind: "banco" | "humeda_lenta" | "amoladora" | "afilabrocas" | "afilafresas", rpm, wet,
##                      wheels: [{ position, d_mm, width_mm (null: ancho de dibujo), abrasive_id, grit, rpm, wet,
##                      honing, selected }] }
##   set_tool(view)     { kind: "cuchillo" | "hacha" | "cortacesped" | "broca" | "fresa", length_mm, width_mm o
##                      diameter_mm, spine_mm, steel_id, flutes (opcional) }
##   set_state(view)    cada fotograma: { angle_deg, force_n, contact, contact_pos (0–1 a lo largo del filo),
##                      edge_temp_c: PackedFloat32Array a lo largo del filo, max_temp_c, sparks: { rate, color,
##                      length_mm }, water, rpm_actual, burr (0–1) }; opcionales: wheel (posición de la muela con la
##                      que se trabaja), edge_peak_c (pico alcanzado a lo largo del filo: el color de revenido se
##                      queda al enfriarse; sin él, el color sigue a edge_temp_c), temp_field (perfil hacia el lomo:
##                      { u_count, d_mm, temps, peaks }), tint_depth_mm
##   set_view(nombre)   "general" | "filo" | "seccion"
##   set_temper_ramp(filas, interpolar)  tabla de colores de revenido del core ([{ t, hex }] de panels.gd, o
##                      [[t, "#hex"]]). Sin tabla, el filo no toma color: la escena no inventa colores.
##   set_quality(p)     "escritorio" | "movil" (sin sombras, menos chispas y partículas)
##   info(), contact_point() (m, para el tool_pos del sonido)
## Ángulo (angle_deg): cuchillo y hacha, por lado; cortacésped (un solo bisel), el total; broca, el de punta; fresa,
## la incidencia. Vistas en mm, °C y rpm; la escena en metros.
##
## Rendimiento: las mallas se construyen en set_machine / set_tool (y la punta de la broca se vuelve a tallar solo si
## su ángulo cambia más de medio grado); en cada fotograma solo se mueven transformaciones, parámetros de shader y
## partículas. El bisel de las hojas lo dibuja el shader con el ángulo del fotograma.
extends Node3D

const Parts = preload("res://app/taller/sharpen3d/parts.gd")
const Tools = preload("res://app/taller/sharpen3d/tools.gd")
const MachineWheels = preload("res://app/taller/sharpen3d/machine_wheels.gd")
const MachineGrinder = preload("res://app/taller/sharpen3d/machine_grinder.gd")
const MachineCompact = preload("res://app/taller/sharpen3d/machine_compact.gd")
const OrbitRig = preload("res://app/taller/sharpen3d/orbit_rig.gd")
const Sparks = preload("res://core/taller/sparks.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const SPARK_SHADER = preload("res://app/taller/radial3d/chispa.gdshader")
const SECTION_SHADER = preload("res://app/taller/sharpen3d/section.gdshader")
const ARC_SHADER = preload("res://app/taller/sharpen3d/arc.gdshader")
const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

const MACHINE_KINDS := ["banco", "humeda_lenta", "amoladora", "afilabrocas", "afilafresas"]
const VIEWS := ["general", "filo", "seccion"]
const VIEW_ALIASES := { "detalle": "filo", "detalle del filo": "filo", "sección": "seccion", "corte": "seccion",
	"vista general": "general" }
## Textura de temperaturas: 64 muestras a lo largo del filo × 16 hacia el lomo (escala logarítmica)
const TEMP_W := 64
const TEMP_H := 16
const TEMP_D0 := 0.00005
const TEMP_DMAX := 0.03
## Exposición de la «cámara» (s): desenfoque de las muelas y estela de las chispas, como en una foto de 1/60 s.
const EXPOSURE_S := 1.0 / 60.0
## Giro que se enseña: el de verdad hasta 18° por fotograma; por encima, el dibujo de la muela se desenfoca con el arco
## que barre en la exposición y su giro aparente se frena hasta 0,35 vueltas/s en el sentido real (como en el torno):
## a 30 fps una muela a 2950 rpm da 590° por fotograma y, pintada tal cual, parecería quieta o marcha atrás.
const STROBE_START_DEG := 18.0
const STROBE_FULL_DEG := 75.0
const STROBE_APPARENT_RPS := 0.35
const RETRACT_M := 0.02  # lo que se separa la herramienta cuando no toca
const CONTACT_TAU := 0.08  # s: suavizado del acercamiento (dibujo)
const DEFAULT_ANGLE := { "cuchillo": 15.0, "hacha": 13.75, "cortacesped": 30.0, "broca": 118.0, "fresa": 7.0 }
## Caída de dibujo del color de revenido hacia el lomo si la simulación solo da la temperatura a lo largo del filo
## (m). No es un perfil térmico: la oleada 2 puede dar temp_field o tint_depth_mm.
const TINT_LEN := { "cuchillo": 0.0015, "hacha": 0.004, "cortacesped": 0.003, "broca": 0.0015, "fresa": 0.001 }
const SECTION_LAYER := 3
const HOUSING_LAYER := 2
const MOBILE_SPARK_FACTOR := 0.35

@export var quality := "escritorio"

var machine_view: Dictionary = {}
var tool_view: Dictionary = {}
var state: Dictionary = {}
var view := "general"

var _built := false
var _world: Node3D
var _mrig: Dictionary = {}
var _mkey := ""
var _trig: Dictionary = {}
var _tkey := ""
var _pose: Dictionary = {}
var _t := 0.0
var _contact_k := 0.0
var _rig: Node3D
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _emitter: Sparks
var _spark_key := ""
var _sparks_mmi: MultiMeshInstance3D
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _temp_img: Image
var _temp_tex: ImageTexture
var _temp_last: Variant = null
var _temp_2d := false
var _ramp_tex: GradientTexture1D
var _ramp_range := Vector2(150.0, 450.0)
var _heat_tex: GradientTexture1D
var _sec: Dictionary = {}
var _upd_n := 0
var _upd_sum := 0
var _upd_max := 0
var _snap_view := false


func _ready() -> void:
	_ensure_built()
	if _mrig.is_empty():
		set_machine({ "kind": "banco" })
	if _trig.is_empty():
		set_tool({ "kind": "cuchillo" })
	_apply_view(true)


func _process(delta: float) -> void:
	advance(delta)


# ───────────────────────────── API ─────────────────────────────


## Máquina (vista de SharpeningMachines.view()). Solo se reconstruye si cambian el tipo o las muelas; las rpm de cada
## muela se toman siempre.
func set_machine(v: Dictionary) -> void:
	_ensure_built()
	machine_view = v.duplicate(true)
	var key := _machine_key(machine_view)
	if key != _mkey:
		_mkey = key
		if not _mrig.is_empty():
			_free_node(_mrig["root"])
		_mrig = _build_machine(machine_view)
		_pose = {}
		_spark_key = ""
		_emitter.reset()
		_apply_quality()
		_apply_view(true)
		_snap_view = true
	_update_wheel_rpms()


## Herramienta. Solo se reconstruye si cambian el tipo o las medidas.
func set_tool(v: Dictionary) -> void:
	_ensure_built()
	tool_view = v.duplicate(true)
	var kind := Tools.kind_of(tool_view)
	var key := Tools.key_of(tool_view, 0.0)
	if key != _tkey:
		_tkey = key
		if not _trig.is_empty():
			_free_node(_trig["root"])
		_trig = Tools.build(_world, tool_view, _angle_of(state, kind))
		_setup_tool_material()
		_spark_key = ""
		_temp_last = null
		_snap_view = true


## Estado del fotograma (la simulación). Se aplica en advance(); aquí solo se guarda.
func set_state(v: Dictionary) -> void:
	_ensure_built()
	state = v


## «general» (órbita alrededor de la máquina), «filo» (detalle del contacto, que lo sigue) o «seccion» (corte a
## escala perpendicular al filo con el bisel y el ángulo; en brocas y fresas, la punta de perfil sobre la muela).
func set_view(name: String, instant := false) -> void:
	var v: String = VIEW_ALIASES.get(name.to_lower(), name.to_lower())
	if not VIEWS.has(v):
		push_warning("Vista desconocida: %s" % name)
		return
	view = v
	_ensure_built()
	_apply_view(instant)


## Tabla de colores de revenido del core: filas { t, hex } (panels.gd → TEMPER_COLORS, la que usa edge_thermal.gd)
## o [t, "#hex" | Color]. Por defecto en escalones, como EdgeThermal.tint(); interpolate = true, interpolada.
func set_temper_ramp(rows: Array, interpolate := false) -> void:
	_ensure_built()
	var pts: Array = []
	for r in rows:
		var t: Variant = null
		var c: Variant = null
		if r is Dictionary:
			t = r.get("t", r.get("temp_c"))
			c = r.get("hex", r.get("color"))
		elif r is Array and r.size() >= 2:
			t = r[0]
			c = r[1]
		if t == null or c == null:
			continue
		var col: Color = c if c is Color else Color(str(c))
		pts.append([float(t), col])
	pts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_ramp_tex = _make_ramp(pts, interpolate)
	if not _trig.is_empty():
		_setup_tool_material()


func set_quality(preset: String) -> void:
	quality = "movil" if preset == "movil" else "escritorio"
	_ensure_built()
	_apply_quality()


## Punto de contacto en metros (marco de la escena): el tool_pos del sonido.
func contact_point() -> Vector3:
	return _pose.get("contact", Vector3.ZERO)


## Datos para rótulos y para los tests.
func info() -> Dictionary:
	var sel: Dictionary = _pose.get("wheel", {})
	var rpm := float(sel.get("rpm_shown", sel.get("rpm", 0.0)))
	var d_mm := float(sel.get("radius", 0.0)) * 2000.0
	return {
		"machine_kind": str(_mrig.get("kind", "")), "tool_kind": str(_trig.get("kind", "")), "view": view,
		"wheel": str(sel.get("position", "")), "wheels": (_mrig.get("wheels", []) as Array).size(), "rpm": rpm,
		"peripheral_speed_ms": Sharpening.peripheral_speed(d_mm, rpm),
		"deg_per_frame": float(sel.get("deg_per_frame", 0.0)), "blur_rad": float(sel.get("blur", 0.0)),
		"contact": _contact_k > 0.5, "compatible": not bool(_pose.get("idle", false)),
		"sparks": _emitter.stats() if _emitter != null else {}, "quality": quality,
		"update_ms_avg": float(_upd_sum) / float(maxi(_upd_n, 1)) / 1000.0, "update_ms_max": float(_upd_max) / 1000.0,
		"frames": _upd_n,
	}


## Un fotograma (lo llama _process; los tests lo llaman sin ventana).
func advance(delta: float) -> void:
	_ensure_built()
	var t0 := Time.get_ticks_usec()
	if _mrig.is_empty():
		set_machine({ "kind": "banco" })
	if _trig.is_empty():
		set_tool({ "kind": "cuchillo" })
	var dt := maxf(delta, 0.0)
	_t += dt
	var st := state
	_sync_rotary_angle(st)
	var want := 1.0 if bool(st.get("contact", false)) else 0.0
	_contact_k += (want - _contact_k) * (1.0 - exp(-dt / CONTACT_TAU))
	_pose = _compute_pose(st, RETRACT_M * (1.0 - _contact_k))
	(_trig["root"] as Node3D).transform = _pose.get("tool_xf", _rest_xf())
	if _snap_view:
		# Máquina o herramienta nueva: la cámara va de golpe a la vista, con los puntos de la pose ya calculados
		_snap_view = false
		_apply_view(true)
	_spin_wheels(st, dt)
	_update_tool_shader(st)
	_update_temps(st)
	_update_sparks(st, dt)
	_update_water(st)
	_update_glow(st)
	_update_camera(dt)
	var us := Time.get_ticks_usec() - t0
	_upd_n += 1
	_upd_sum += us
	_upd_max = maxi(_upd_max, us)


# ───────────────────────────── construcción ─────────────────────────────


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_environment()
	_world = Parts.node(self, "Mundo")
	var wood := Parts.mat(Color("#8C6B4B"), 0.0, 0.72)
	var wood_dark := Parts.mat(Color("#5E4632"), 0.0, 0.8)
	Parts.box(self, Vector3(-0.8, -0.045, -0.38), Vector3(0.8, 0.0, 0.45), wood, 0.004, "Banco")
	Parts.box(self, Vector3(-0.8, -0.06, 0.43), Vector3(0.8, -0.045, 0.45), wood_dark, 0.0)
	_temp_img = Image.create(TEMP_W, TEMP_H, false, Image.FORMAT_RGH)
	_temp_img.fill(Color(0.02, 0.02, 0.0))
	_temp_tex = ImageTexture.create_from_image(_temp_img)
	_ramp_tex = _make_ramp([], false)
	_heat_tex = _make_heat_ramp()
	_emitter = Sparks.new("afiladora")
	_emitter.set_exposure(EXPOSURE_S)
	_sparks_mmi = _multimesh("Chispas", Sparks.MAX_SPARKS)
	_build_glow()
	_build_section()
	_rig = OrbitRig.new()
	add_child(_rig)
	(_rig.call("camera") as Camera3D).current = true
	_apply_quality()


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.name = "Entorno"
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.light_energy = 1.25
	_sun.light_color = Color(1.0, 0.97, 0.93)
	_sun.basis = Basis.looking_at(Vector3(0.6, -1.4, -1.0), Vector3.UP)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 2.5
	add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.name = "Relleno"
	_fill.light_energy = 0.35
	_fill.light_color = Color(0.78, 0.84, 1.0)
	_fill.light_specular = 0.2
	_fill.basis = Basis.looking_at(Vector3(-0.8, -0.5, 0.9), Vector3.UP)
	add_child(_fill)


func _build_machine(v: Dictionary) -> Dictionary:
	var mobile := quality == "movil"
	match str(v.get("kind", "banco")):
		"amoladora":
			return MachineGrinder.build(_world, v, mobile)
		"afilabrocas", "afilafresas":
			return MachineCompact.build(_world, v, mobile)
		"humeda_lenta":
			return MachineWheels.build(_world, v, mobile)
	var v2 := v.duplicate()
	v2["kind"] = "banco"
	return MachineWheels.build(_world, v2, mobile)


static func _machine_key(v: Dictionary) -> String:
	var parts: Array = [str(v.get("kind", "banco")), str(bool(v.get("quench_pot", false)))]
	for w in v.get("wheels", []):
		if w is Dictionary:
			parts.append("%s,%s,%s,%s,%s,%s,%s,%s,%s" % [w.get("position", ""), w.get("d_mm", ""), w.get("width_mm", ""),
				w.get("abrasive_id", ""), w.get("grit", ""), w.get("wet", ""), w.get("honing", ""), w.get("selected", ""),
				w.get("id", "")])
	return "|".join(parts)


## rpm de cada muela: la suya de la vista o, si no la trae, la de la máquina.
func _update_wheel_rpms() -> void:
	var views: Array = machine_view.get("wheels", [])
	var m_rpm := Parts.num(machine_view, "rpm", 0.0)
	for w in _mrig.get("wheels", []):
		var rpm := Parts.num(w["view"], "rpm", m_rpm) if w["view"] is Dictionary else m_rpm
		for x in views:
			if x is Dictionary and str(x.get("position", "")) == str(w["position"]):
				rpm = Parts.num(x, "rpm", m_rpm)
				break
		w["rpm"] = rpm


func _free_node(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


func _setup_tool_material() -> void:
	var m: ShaderMaterial = _trig["mat"]
	var kind := str(_trig["kind"])
	m.set_shader_parameter("use_bevel", bool(_trig["blade"]))
	m.set_shader_parameter("two_sided", 0.0 if bool(_trig.get("single_bevel", false)) else 1.0)
	m.set_shader_parameter("edge_temp", _temp_tex)
	m.set_shader_parameter("temper_ramp", _ramp_tex)
	m.set_shader_parameter("heat_ramp", _heat_tex)
	m.set_shader_parameter("ramp_min_c", _ramp_range.x)
	m.set_shader_parameter("ramp_max_c", _ramp_range.y)
	m.set_shader_parameter("temp_d0", TEMP_D0)
	m.set_shader_parameter("temp_dmax", TEMP_DMAX)
	m.set_shader_parameter("tint_len", float(TINT_LEN.get(kind, 0.0015)))
	m.set_shader_parameter("temp_2d", _temp_2d)
	var sec_mat: ShaderMaterial = _sec["strip_mat"]
	sec_mat.set_shader_parameter("two_sided", 0.0 if bool(_trig.get("single_bevel", false)) else 1.0)


func _angle_of(st: Dictionary, kind: String) -> float:
	return Parts.num(st, "angle_deg", float(DEFAULT_ANGLE.get(kind, 15.0)))


## Broca y fresa: si el ángulo de la punta cambia más de medio grado, se vuelve a tallar (sin crear nodos).
func _sync_rotary_angle(st: Dictionary) -> void:
	if bool(_trig.get("blade", true)) or not st.has("angle_deg"):
		return
	var a := _angle_of(st, str(_trig["kind"]))
	if absf(a - float(_trig.get("point_deg", a))) > 0.5:
		Tools.retool(_trig, tool_view, a)


func _multimesh(node_name: String, capacity: int) -> MultiMeshInstance3D:
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, -0.5, 0), Vector3(1.0, -0.5, 0), Vector3(1.0, 0.5, 0), Vector3(0, 0.5, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	quad.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _build_glow() -> void:
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
	_glow_mat.albedo_color = Sparks.heat_color(1050.0) * Color(1.3, 1.15, 1.0, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	_glow = MeshInstance3D.new()
	_glow.name = "BrilloDelContacto"
	_glow.mesh = quad
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)


## Rampa de revenido para el shader: transparente por debajo del primer color. En escalones (como EdgeThermal.tint)
## o interpolada.
func _make_ramp(pts: Array, interpolate: bool) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	if pts.is_empty():
		_ramp_range = Vector2(150.0, 450.0)
		offsets = PackedFloat32Array([0.0, 1.0])
		colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	else:
		var t0: float = float(pts[0][0]) - 1.0
		var t1: float = float(pts[pts.size() - 1][0]) + 30.0
		_ramp_range = Vector2(t0, t1)
		offsets.append(0.0)
		colors.append(Color(0, 0, 0, 0))
		for p in pts:
			offsets.append((float(p[0]) - t0) / (t1 - t0))
			colors.append(p[1])
	g.offsets = offsets
	g.colors = colors
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR if interpolate else Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 512
	return tex


## Incandescencia de 300 a 1300 °C con los colores de calor de sparks.gd (TM 9-237, tabla V).
func _make_heat_ramp() -> GradientTexture1D:
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


func _apply_quality() -> void:
	if _sun == null:
		return
	var mobile := quality == "movil"
	_sun.shadow_enabled = not mobile
	for w in _mrig.get("wheels", []):
		if (w as Dictionary).has("water"):
			var wd: Dictionary = w["water"]
			(wd["drips"] as GPUParticles3D).amount_ratio = 0.5 if mobile else 1.0
			(wd["splash"] as GPUParticles3D).amount_ratio = 0.5 if mobile else 1.0
	_spark_key = ""


# ───────────────────────────── cada fotograma ─────────────────────────────


func _compute_pose(st: Dictionary, retract: float) -> Dictionary:
	var p: Dictionary
	match str(_mrig.get("kind", "banco")):
		"amoladora":
			p = MachineGrinder.pose(_mrig, _trig, st, retract)
		"afilabrocas", "afilafresas":
			p = MachineCompact.pose(_mrig, _trig, st, retract)
		_:
			p = MachineWheels.pose(_mrig, _trig, st, retract)
			if p.has("tool_xf"):
				MachineWheels.update(_mrig, p)
	if not p.has("tool_xf"):
		p["idle"] = true
	return p


## Donde queda la herramienta si no se puede afilar en esta máquina: tumbada en la mesa, delante.
func _rest_xf() -> Transform3D:
	if bool(_trig.get("blade", true)):
		return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.1, float(_trig.get("thickness", 0.003)) * 0.5, 0.3))
	return Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.1, float(_trig.get("radius", 0.005)), 0.3))


func _spin_wheels(st: Dictionary, dt: float) -> void:
	var sel: Dictionary = _pose.get("wheel", {})
	var ratio := 1.0
	if st.has("rpm_actual") and not sel.is_empty() and float(sel.get("rpm", 0.0)) > 0.0:
		ratio = maxf(Parts.num(st, "rpm_actual", 0.0), 0.0) / float(sel["rpm"])
	for w in _mrig.get("wheels", []):
		var rpm := float(w["rpm"]) * ratio
		var omega := rpm / 60.0 * TAU * float(w["spin"])
		var per_frame := absf(rad_to_deg(omega * dt))
		var b := clampf((per_frame - STROBE_START_DEG) / (STROBE_FULL_DEG - STROBE_START_DEG), 0.0, 1.0)
		var omega_disp := lerpf(omega, signf(omega) * TAU * STROBE_APPARENT_RPS, b)
		w["angle"] = fposmod(float(w["angle"]) + omega_disp * dt, TAU)
		var blur := minf(absf(omega) * EXPOSURE_S, 8.0)
		var m: ShaderMaterial = w["mat"]
		m.set_shader_parameter("spin", float(w["angle"]))
		m.set_shader_parameter("blur", minf(blur, 1.5) if str(w["shader"]) == "disco" else blur)
		w["rpm_shown"] = rpm
		w["deg_per_frame"] = per_frame
		w["blur"] = blur


func _update_tool_shader(st: Dictionary) -> void:
	var m: ShaderMaterial = _trig["mat"]
	var kind := str(_trig["kind"])
	if bool(_trig["blade"]):
		var beta := clampf(_angle_of(st, kind), 1.0, 60.0)
		m.set_shader_parameter("bevel_tan", tan(deg_to_rad(beta)))
		var sel: Dictionary = _pose.get("wheel", {})
		var hollow := 0.0
		if not bool(_pose.get("idle", false)) and str(sel.get("grind", "")) == "periferia":
			hollow = float(sel.get("radius", 0.0))
		m.set_shader_parameter("hollow_r", hollow)
	var depth := Parts.num(st, "tint_depth_mm", -1.0)
	m.set_shader_parameter("tint_len", depth / 1000.0 if depth > 0.0 else float(TINT_LEN.get(kind, 0.0015)))
	var burr := clampf(Parts.num(st, "burr", 0.0), 0.0, 1.0)
	var bm: ShaderMaterial = _trig["burr_mat"]
	bm.set_shader_parameter("burr", burr)
	bm.set_shader_parameter("phase", _t)
	(_trig["burr"] as Node3D).visible = burr > 0.001


## Temperaturas a la textura (solo si cambian). Canal R: la temperatura de ahora (la incandescencia); canal G: el
## pico que ha alcanzado cada punto (el color de revenido, que no se va al enfriarse): edge_temp_c y edge_peak_c a
## lo largo del filo (sin edge_peak_c, el color sigue a edge_temp_c) o temp_field con el perfil hacia el lomo. Se
## reutiliza la misma imagen y la misma textura: no se crean objetos en cada fotograma.
func _update_temps(st: Dictionary) -> void:
	var field: Variant = st.get("temp_field")
	var src: Array
	if field is Dictionary and not (field as Dictionary).is_empty():
		src = [field]
	else:
		src = [st.get("edge_temp_c"), st.get("edge_peak_c")]
	if _temp_last is Array and src == _temp_last:
		return
	_temp_last = src.duplicate(true)
	_temp_2d = src.size() == 1
	if _temp_2d:
		_fill_field(src[0])
	else:
		_fill_edge(src[0], src[1])
	_temp_tex.update(_temp_img)
	(_trig["mat"] as ShaderMaterial).set_shader_parameter("temp_2d", _temp_2d)


## Muestras de temperatura (°C) de una vista: PackedFloat32Array, PackedFloat64Array o Array (vacía si no hay).
static func _samples(v: Variant) -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	if v is PackedFloat32Array or v is PackedFloat64Array or v is Array:
		for x in v:
			arr.append(float(x))
	return arr


## Valor en la fracción f (0–1) de unas muestras repartidas a lo largo del filo (20 °C si no hay).
static func _sample_at(arr: PackedFloat32Array, f: float) -> float:
	var n := arr.size()
	if n == 0:
		return 20.0
	if n == 1:
		return arr[0]
	var x := clampf(f, 0.0, 1.0) * float(n - 1)
	var i := mini(int(floor(x)), n - 2)
	return lerpf(arr[i], arr[i + 1], x - float(i))


func _fill_edge(temps: Variant, peaks: Variant) -> void:
	var now := _samples(temps)
	var top := _samples(peaks)
	if top.is_empty():
		top = now
	for x in TEMP_W:
		var f := (float(x) + 0.5) / float(TEMP_W)
		var tn := _sample_at(now, f)
		var c := Color(tn / 1000.0, maxf(_sample_at(top, f), tn) / 1000.0, 0.0)
		for y in [TEMP_H / 2 - 1, TEMP_H / 2]:
			_temp_img.set_pixel(x, y, c)


## temp_field: { u_count, d_mm: [distancias al filo, mm], temps: [°C], peaks (opcional): [°C] } con u_count × d_count
## valores por filas de u (las secciones de EdgeThermal: temps() y surface_peaks()).
func _fill_field(f: Dictionary) -> void:
	var nu := maxi(int(f.get("u_count", 1)), 1)
	var dmm: Array = Array(f.get("d_mm", []))
	var temps: Array = Array(f.get("temps", []))
	var peaks: Array = Array(f.get("peaks", []))
	var nd := dmm.size()
	if nd == 0 or temps.size() < nu * nd:
		_fill_edge(PackedFloat32Array(), PackedFloat32Array())
		return
	if peaks.size() < nu * nd:
		peaks = temps
	for y in TEMP_H:
		var v := (float(y) + 0.5) / float(TEMP_H)
		var d := TEMP_D0 * (pow(1.0 + TEMP_DMAX / TEMP_D0, v) - 1.0) * 1000.0
		var j := 0
		while j < nd - 2 and float(dmm[j + 1]) < d:
			j += 1
		var kd := clampf((d - float(dmm[j])) / maxf(float(dmm[mini(j + 1, nd - 1)]) - float(dmm[j]), 1e-9), 0.0, 1.0) if nd > 1 else 0.0
		for x in TEMP_W:
			var fu := (float(x) + 0.5) / float(TEMP_W) * float(nu - 1)
			var i := mini(int(floor(fu)), maxi(nu - 2, 0))
			var ku := fu - float(i) if nu > 1 else 0.0
			var tn := _grid_at(temps, nd, i, j, kd, ku, nu)
			var tp := maxf(_grid_at(peaks, nd, i, j, kd, ku, nu), tn)
			_temp_img.set_pixel(x, y, Color(tn / 1000.0, tp / 1000.0, 0.0))


## Interpolación bilineal en la rejilla u × d de temp_field.
static func _grid_at(vals: Array, nd: int, i: int, j: int, kd: float, ku: float, nu: int) -> float:
	var i1 := mini(i + 1, nu - 1)
	var j1 := mini(j + 1, nd - 1)
	var a := lerpf(float(vals[i * nd + j]), float(vals[i * nd + j1]), kd)
	var b := lerpf(float(vals[i1 * nd + j]), float(vals[i1 * nd + j1]), kd)
	return lerpf(a, b, ku)


func _update_sparks(st: Dictionary, dt: float) -> void:
	var sel: Dictionary = _pose.get("wheel", {})
	var sp_pose: Dictionary = _pose.get("spark_pose", {})
	var sp: Dictionary = st.get("sparks") if st.get("sparks") is Dictionary else {}
	# En una muela húmeda no salen chispas (lo que dé la simulación); en las secas, las de sparks.gd con su haz
	var active := not bool(_pose.get("idle", false)) and bool(st.get("contact", false)) and _contact_k > 0.5 \
		and not bool(sel.get("wet", false)) and not sp_pose.is_empty()
	var cfg := {}
	if not active:
		cfg["rate"] = 0.0
	else:
		for k in ["rate", "length_mm", "color", "bursts"]:
			if sp.get(k) != null:
				cfg[k] = sp[k]
		if cfg.has("rate") and quality == "movil":
			cfg["rate"] = float(cfg["rate"]) * MOBILE_SPARK_FACTOR
		if _pose.has("spark_max_mm"):
			cfg["length_mm"] = minf(float(cfg.get("length_mm", 1e9)), float(_pose["spark_max_mm"]))
	var steel := str(_trig.get("steel_id", ""))
	if steel == "":
		steel = "acero"
	var d_c := float(sp_pose.get("radius", 0.0)) * 2000.0
	var vs := Sharpening.peripheral_speed(d_c, float(sel.get("rpm_shown", 0.0)))
	var key := "%s|%s|%s" % [steel, var_to_str(cfg), Js.to_fixed(vs, 2)]
	if key != _spark_key:
		_spark_key = key
		_emitter.configure(steel, cfg, vs)
	if not sp_pose.is_empty():
		_emitter.set_pose(sp_pose)
	_emitter.step(dt)
	var mm := _sparks_mmi.multimesh
	mm.buffer = _emitter.buffer(EXPOSURE_S, 0.0005 if view != "general" else 0.0009, Sparks.MAX_SPARKS)
	var cap := Sparks.MAX_SPARKS if quality != "movil" else 400
	mm.visible_instance_count = mini(_emitter.count(), cap)


func _update_water(st: Dictionary) -> void:
	var has_water := not (st.has("water") and not bool(st["water"]))
	var sel: Dictionary = _pose.get("wheel", {})
	for w in _mrig.get("wheels", []):
		if not (w as Dictionary).has("water"):
			continue
		var wd: Dictionary = w["water"]
		var rpm := absf(float(w.get("rpm_shown", 0.0)))
		var turning := rpm > 5.0
		(wd["surface"] as Node3D).visible = has_water
		var wm: ShaderMaterial = wd["mat"]
		wm.set_shader_parameter("phase", _t)
		wm.set_shader_parameter("stir", clampf(rpm / 100.0, 0.0, 2.0))
		(w["mat"] as ShaderMaterial).set_shader_parameter("wet", 1.0 if has_water else 0.15)
		var drips: GPUParticles3D = wd["drips"]
		var here := str(sel.get("position", "")) == str(w["position"]) and _contact_k > 0.5 and not bool(_pose.get("idle", false))
		var c: Vector3 = w["center"]
		var r: float = w["radius"]
		# Las posiciones de la pose están en el marco de la escena; la bandeja y la máquina cuelgan de ella sin girar
		drips.position = _pose["contact"] if here else c + Vector3(0.0, -0.25 * r, 0.96 * r)
		var on := has_water and turning
		if drips.emitting != on:
			drips.emitting = on
		var splash: GPUParticles3D = wd["splash"]
		if splash.emitting != on:
			splash.emitting = on


func _update_glow(st: Dictionary) -> void:
	var sel: Dictionary = _pose.get("wheel", {})
	var sp: Dictionary = st.get("sparks") if st.get("sparks") is Dictionary else {}
	var dry := not bool(sel.get("wet", false))
	var on := dry and not bool(_pose.get("idle", false)) and _contact_k > 0.05 and _emitter.count() > 0 \
		and float(sp.get("rate", 1.0)) > 0.0
	_glow.visible = on
	if on:
		var n: Vector3 = _pose.get("normal", Vector3.UP)
		_glow.position = (_pose["contact"] as Vector3) + n * 0.0006
		_glow_mat.albedo_color.a = 0.85 * _contact_k


# ───────────────────────────── cámara y vistas ─────────────────────────────


func _apply_view(instant: bool) -> void:
	if _rig == null or _mrig.is_empty():
		return
	var cam: Dictionary = _mrig.get("cam", {})
	var mask := 0xFFFFF & ~(1 << (SECTION_LAYER - 1))
	(_sec["root"] as Node3D).visible = view == "seccion"
	match view:
		"general":
			var g: Dictionary = cam.get("general", {})
			_rig.call("set_orbit", _general_target(g), float(g.get("yaw", 20.0)), float(g.get("pitch", 18.0)),
				float(g.get("distance", 0.8)), 38.0, instant)
			_rig.call("set_mask", mask)
		"filo":
			var f: Dictionary = cam.get("filo", {})
			_rig.call("set_orbit", _pose.get("contact", cam.get("general", {}).get("target", Vector3.ZERO)),
				float(f.get("yaw", -30.0)), float(f.get("pitch", 14.0)), float(f.get("distance", 0.13)), 32.0, instant)
			_rig.call("set_mask", mask)


## Objetivo de la vista general: fijo en la máquina o, si la máquina lo pide (amoladora), un punto de la pose (el
## centro del filo de la herramienta, que cambia con cada una) más un desplazamiento.
func _general_target(g: Dictionary) -> Vector3:
	var key := str(g.get("follow", ""))
	if key != "" and _pose.has(key) and not bool(_pose.get("idle", false)):
		return (_pose[key] as Vector3) + (g.get("offset", Vector3.ZERO) as Vector3)
	return g.get("target", Vector3(0, 0.12, 0))


func _update_camera(dt: float) -> void:
	if view == "filo" and _pose.has("contact"):
		_rig.call("follow", _pose["contact"])
	elif view == "general":
		_rig.call("follow", _general_target(_mrig.get("cam", {}).get("general", {})))
	elif view == "seccion":
		_update_section()
	_rig.call("step", dt)


# ───────────────────────────── vista de sección ─────────────────────────────


func _build_section() -> void:
	var root := Parts.node(self, "Seccion")
	root.visible = false
	var bit := 1 << (SECTION_LAYER - 1)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Palette.color("bg2")
	var bg := Parts.mesh_node(root, QuadMesh.new(), bg_mat, Transform3D.IDENTITY, "Fondo")
	var strip_mat := ShaderMaterial.new()
	strip_mat.shader = SECTION_SHADER
	var strip := Parts.mesh_node(root, _strip_mesh(), strip_mat, Transform3D.IDENTITY, "Hoja")
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wheel_mat.albedo_color = Color("#9C9187")
	wheel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc := Parts.mesh_node(root, _disc_mesh(96), wheel_mat, Transform3D.IDENTITY, "Muela")
	var slab := Parts.mesh_node(root, BoxMesh.new(), wheel_mat, Transform3D.IDENTITY, "Disco")
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Palette.color("ice")
	line_mat.no_depth_test = true
	var tangent := Parts.mesh_node(root, BoxMesh.new(), line_mat, Transform3D.IDENTITY, "Tangente")
	var center_mat := line_mat.duplicate() as StandardMaterial3D
	center_mat.albedo_color = Palette.color("mint")
	var center := Parts.mesh_node(root, BoxMesh.new(), center_mat, Transform3D.IDENTITY, "Eje")
	var arc_mat := ShaderMaterial.new()
	arc_mat.shader = ARC_SHADER
	arc_mat.set_shader_parameter("color", Palette.color("gold"))
	var arc := Parts.mesh_node(root, _arc_mesh(48), arc_mat, Transform3D.IDENTITY, "Arco")
	var scale_bar := Parts.mesh_node(root, BoxMesh.new(), center_mat, Transform3D.IDENTITY, "Escala")
	for n in [bg, strip, disc, slab, tangent, center, arc, scale_bar]:
		(n as GeometryInstance3D).layers = bit
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var labels := {}
	for k in ["angle", "wheel", "bevel", "scale"]:
		var l := Label3D.new()
		l.name = "Rotulo_" + k
		l.font = FONT
		l.font_size = 48
		l.outline_size = 10
		l.outline_modulate = Color(0.09, 0.05, 0.11, 0.9)
		l.no_depth_test = true
		l.layers = bit
		l.modulate = Palette.color("gold") if k == "angle" else Palette.color("text")
		root.add_child(l)
		labels[k] = l
	_sec = { "root": root, "bg": bg, "strip": strip, "strip_mat": strip_mat, "disc": disc, "slab": slab,
		"wheel_mat": wheel_mat, "tangent": tangent, "center": center, "arc": arc, "arc_mat": arc_mat,
		"scale": scale_bar, "labels": labels }


## Tira de la sección: vértices en la línea media (0, d, 0) con CUSTOM0 = (d, lado); el shader les da el espesor.
static func _strip_mesh() -> ArrayMesh:
	var b := Tools.MeshArrays.new()
	var n := 70
	for j in n + 1:
		var d := 0.05 * pow(float(j) / float(n), 2.5)
		for side: float in [1.0, -1.0]:
			b.add(Vector3(0.0, d, 0.0), Vector3.RIGHT, Vector2(0.0, 0.0), Vector2.ZERO, Color(d, side, 0.0, 0.0))
	for j in n:
		var a := j * 2
		b.quad(a, a + 2, a + 3, a + 1, Vector3.RIGHT)
	return b.commit()


## Círculo de radio 1 en el plano yz (se escala al radio de la muela).
static func _disc_mesh(segs: int) -> ArrayMesh:
	var b := Tools.MeshArrays.new()
	var c := b.add(Vector3.ZERO, Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Color(0, 0, 0, 0))
	for k in segs:
		var a := TAU * float(k) / float(segs)
		b.add(Vector3(0.0, cos(a), sin(a)), Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Color(0, 0, 0, 0))
	for k in segs:
		b.tri(c, 1 + k, 1 + (k + 1) % segs, Vector3.RIGHT)
	return b.commit()


## Tira del arco: UV.x = fracción del ángulo, UV.y = lado de la anchura (el vértice la abre en arc.gdshader).
static func _arc_mesh(segs: int) -> ArrayMesh:
	var b := Tools.MeshArrays.new()
	for k in segs + 1:
		var t := float(k) / float(segs)
		b.add(Vector3(0.0, 1.0, t), Vector3.RIGHT, Vector2(t, 0.0), Vector2.ZERO, Color(0, 0, 0, 0))
		b.add(Vector3(0.0, 1.1, t), Vector3.RIGHT, Vector2(t, 1.0), Vector2.ZERO, Color(0, 0, 0, 0))
	for k in segs:
		var a := k * 2
		b.quad(a, a + 2, a + 3, a + 1, Vector3.RIGHT)
	var m := b.commit()
	m.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	return m


## Coloca la vista de sección en el contacto: corte a escala perpendicular al filo (hojas) o la punta de perfil
## sobre la cara de la muela (brocas y fresas), con las dos líneas del ángulo, su arco y los rótulos. La pose da el
## vértice (apex), las dos líneas (arc_from: la muela; arc_to: la herramienta), hacia dónde está la cámara
## (view_dir) y qué queda arriba (sec_up). Sin contacto que cortar, la cámara ortográfica mira la máquina de frente.
func _update_section() -> void:
	var p := _pose
	var root: Node3D = _sec["root"]
	var labels: Dictionary = _sec["labels"]
	var scene_mask := 0xFFFFF & ~(1 << (SECTION_LAYER - 1))
	if p.is_empty() or bool(p.get("idle", false)) or not p.has("arc_from"):
		root.visible = false
		var g: Dictionary = _mrig.get("cam", {}).get("general", {})
		var tgt: Vector3 = g.get("target", Vector3(0, 0.1, 0))
		_rig.call("set_ortho", tgt + Vector3(0, 0, 0.6), Vector3(0, 0, -1), Vector3.UP, 0.45, scene_mask)
		return
	root.visible = true
	var blade := bool(_trig.get("blade", false))
	var apex: Vector3 = p["apex"]
	var a_from: Vector3 = (p["arc_from"] as Vector3).normalized()
	var a_to: Vector3 = (p["arc_to"] as Vector3).normalized()
	var look: Vector3 = (p["view_dir"] as Vector3).normalized()
	var right := (p.get("sec_up", a_to) as Vector3).cross(look).normalized()
	var up := look.cross(right)
	var win := float((_trig.get("section", {}) as Dictionary).get("window", 0.01))
	var sel: Dictionary = p.get("wheel", {})
	var th := win / 300.0
	var bit := 1 << (SECTION_LAYER - 1)
	# Fondo detrás del plano de corte (solo en las hojas: en brocas y fresas se ve la escena de perfil)
	var bg: MeshInstance3D = _sec["bg"]
	bg.visible = blade
	bg.transform = Transform3D(Basis(right * win * 3.0, up * win * 3.0, look), apex - look * 0.004)
	var strip: MeshInstance3D = _sec["strip"]
	var disc: MeshInstance3D = _sec["disc"]
	var slab: MeshInstance3D = _sec["slab"]
	strip.visible = blade
	disc.visible = blade and str(sel.get("grind", "")) == "periferia"
	slab.visible = blade and str(sel.get("grind", "")) == "cara"
	if blade:
		# Tira de la sección con el mismo bisel que la hoja (uniformes del material de la herramienta), en el filo
		var u := float(p.get("contact_u", 0.5))
		var sl := float(Tools.edge_at(_trig, u)[1])
		var b := (p["tool_xf"] as Transform3D).basis.orthonormalized()
		var xs := (b * Vector3(1.0, sl, 0.0)).normalized()
		var ys := (b * Vector3(-sl, 1.0, 0.0)).normalized()
		strip.transform = Transform3D(Basis(xs, ys, xs.cross(ys)), p.get("edge_pt", apex))
		var tm: ShaderMaterial = _trig["mat"]
		var sm: ShaderMaterial = _sec["strip_mat"]
		for k in ["bevel_tan", "hollow_r"]:
			sm.set_shader_parameter(k, tm.get_shader_parameter(k))
		var half: Callable = _trig["half"]
		var i := int(round(u * float((_trig["xs"] as PackedFloat64Array).size() - 1)))
		var h0: Vector2 = half.call(i, 0.0)
		var hmax: Vector2 = half.call(i, Tools.height_at(_trig, u))
		sm.set_shader_parameter("sec_hb0", h0.x)
		sm.set_shader_parameter("sec_slope", h0.y)
		sm.set_shader_parameter("sec_hmax", maxf(hmax.x, h0.x))
		sm.set_shader_parameter("hatch_m", win / 36.0)
		var wm: StandardMaterial3D = _sec["wheel_mat"]
		wm.albedo_color = Parts.wheel_colors(sel.get("view", {}))[0] as Color
		if disc.visible:
			# La muela cortada por el mismo plano: su círculo, un poco por detrás de la hoja
			var c: Vector3 = sel["center"]
			var r: float = sel["radius"]
			var ax: Vector3 = sel["axis"]
			var e1 := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.BACK).normalized()
			var e2 := ax.cross(e1)
			disc.transform = Transform3D(Basis(ax, e1 * r, e2 * r), c + ax * (apex - c).dot(ax) - look * 0.0003)
		if slab.visible:
			# La cara del disco (con su inclinación) y el disco detrás de ella
			var nd: Vector3 = p.get("disc_normal", p.get("normal", Vector3.UP))
			var wdir := xs.cross(nd).normalized()
			slab.transform = Transform3D(Basis(xs * 0.0004, wdir * win * 1.4, nd * 0.008),
				(p["contact"] as Vector3) + nd * 0.004 - look * 0.0003)
	# Las dos líneas del ángulo: la de la muela (su tangente o su cara) y la de la herramienta (línea media o eje)
	var tangent: MeshInstance3D = _sec["tangent"]
	var axis_line: MeshInstance3D = _sec["center"]
	tangent.transform = Transform3D(Basis(a_from * win * 0.9, a_from.cross(look).normalized() * th, look * th),
		apex + a_from * win * 0.15)
	axis_line.transform = Transform3D(Basis(a_to * win * 0.6, a_to.cross(look).normalized() * th, look * th),
		apex + a_to * win * 0.3)
	# Arco del ángulo (de la muela a la herramienta) y rótulos
	var arc: MeshInstance3D = _sec["arc"]
	var z_arc := (a_to - a_from * a_to.dot(a_from)).normalized()
	arc.transform = Transform3D(Basis(a_from.cross(z_arc), a_from, z_arc), apex)
	var am: ShaderMaterial = _sec["arc_mat"]
	var ang := float(p.get("beta", 0.0))
	am.set_shader_parameter("angle", ang)
	am.set_shader_parameter("radius", win * 0.28)
	am.set_shader_parameter("width", th * 2.0)
	# Rótulos: el del ángulo junto al arco, del lado de la muela; el de la muela, abajo de su lado; el del bisel, al
	# otro lado de la hoja; la escala, en la esquina de abajo del lado de la hoja. La vista mide win de alto.
	var text_h := win * 0.032
	for k in labels:
		(labels[k] as Label3D).pixel_size = text_h / 48.0 * 1.3
	var lbasis := _label_basis(look, up)
	var side := -1.0 if a_from.dot(right) < 0.0 else 1.0  # lado de la pantalla hacia el que queda la muela
	var center := apex + up * win * 0.12
	var la: Label3D = labels["angle"]
	la.text = _angle_text(ang)
	la.transform = Transform3D(lbasis, apex + (a_from + a_to).normalized() * win * 0.3 + right * side * win * 0.16)
	var lw: Label3D = labels["wheel"]
	lw.text = _wheel_text(sel)
	lw.transform = Transform3D(lbasis, center - up * win * 0.4 + right * side * win * 0.22)
	var lb: Label3D = labels["bevel"]
	lb.visible = blade
	if blade:
		lb.text = "bisel %s mm" % _es(_bevel_width_now() * 1000.0, 2)
		lb.transform = Transform3D(lbasis, apex + up * win * 0.1 - right * side * win * 0.24)
	var ls: Label3D = labels["scale"]
	var bar_len := 0.001 if win < 0.012 else 0.005
	ls.text = "%s mm" % _es(bar_len * 1000.0, 0)
	var corner := center - up * win * 0.42 - right * side * win * 0.45
	var bar: MeshInstance3D = _sec["scale"]
	bar.transform = Transform3D(Basis(right * bar_len, up * th * 2.5, look * th), corner + right * side * bar_len * 0.5)
	ls.transform = Transform3D(lbasis, corner + right * side * bar_len * 0.5 + up * text_h * 0.9)
	# Hojas: solo el dibujo de la sección. Brocas y fresas: la escena de perfil (sin carcasa) con el dibujo encima
	var mask := bit if blade else ((scene_mask | bit) & ~(1 << (HOUSING_LAYER - 1)))
	_rig.call("set_ortho", center + look * 0.1, -look, up, win, mask)


## Base de un rótulo que mira a la cámara de la sección (la cámara mira hacia −look).
static func _label_basis(look: Vector3, up: Vector3) -> Basis:
	var z := look.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


func _angle_text(ang: float) -> String:
	var deg := rad_to_deg(ang)
	match str(_trig.get("kind", "")):
		"broca":
			return "%s° por labio · punta %s°" % [_es(deg, 1), _es(deg * 2.0, 0)]
		"fresa":
			return "incidencia %s°" % _es(deg, 1)
		"cortacesped":
			return "%s° (un solo bisel)" % _es(deg, 1)
	return "%s° por lado" % _es(deg, 1)


func _wheel_text(sel: Dictionary) -> String:
	var pos := str(sel.get("position", ""))
	var what := "disco" if pos == "disco" and str(_mrig.get("kind", "")) == "amoladora" else ("piedra" if pos == "piedra" else ("rueda de cuero" if pos == "cuero" else "muela"))
	return "%s Ø%s mm · %s rpm" % [what, _es(float(sel.get("radius", 0.0)) * 2000.0, 0), _es(float(sel.get("rpm_shown", 0.0)), 0)]


## Anchura del bisel dibujado ahora (m): donde la cara del bisel (plana o vaciada con el radio de la muela) llega al
## cuerpo de la hoja. La misma geometría que bevel.gdshaderinc, para el rótulo.
func _bevel_width_now() -> float:
	var tm: ShaderMaterial = _trig["mat"]
	var tb := float(tm.get_shader_parameter("bevel_tan"))
	var hr := float(tm.get_shader_parameter("hollow_r"))
	var single := bool(_trig.get("single_bevel", false))
	var u := float(_pose.get("contact_u", 0.5))
	var half: Callable = _trig["half"]
	var i := int(round(u * float((_trig["xs"] as PackedFloat64Array).size() - 1)))
	var d := 0.0
	for k in 600:
		var hb: Vector2 = half.call(i, d)
		var need := 2.0 * hb.x if single else hb.x
		if _bevel_half(d, tb, hr) >= need:
			return d
		d += 0.00002 if d < 0.002 else 0.0002
	return d


static func _bevel_half(d: float, tb: float, hr: float) -> float:
	if hr <= 0.0:
		return d * tb
	var c := 1.0 / sqrt(1.0 + tb * tb)
	var s := tb * c
	var xx := d + hr * s
	if xx >= hr:
		return 1e3
	return hr * c - sqrt(hr * hr - xx * xx)


## Número con coma decimal (Js.to_fixed: el redondeo de JavaScript).
static func _es(x: float, decimals: int) -> String:
	return Js.to_fixed(x, decimals).replace(".", ",")
