## Taladro de columna en 3D (unidad 1e), construido por código como el torno, con las cotas de la ficha del ERLO TSAR-32
## (columna de Ø125 mm, husillo a 300 mm de la columna y a 1245 mm de la base, carrera de la caña de 180 mm, mesa de
## 400 × 420 mm y base de 492 × 655 mm, según las fichas de venta de GMF Maquinaria y Rastro Máquinas): base, columna,
## mesa con su brazo, cabezal con el motor, las tres manetas del avance, la caña, el portabrocas y la broca con sus dos
## gargantas. La mesa sube o baja por la columna, como la pondría el operario, para que la broca quede a DRILL_CLEAR_MM
## de la pieza con la caña recogida; así la caña nunca sale más que su carrera. La broca gira a las rpm de verdad (con el
## efecto estroboscópico controlado del torno) y baja con el ciclo de MillDrillState (aproximación, taladrado a vf,
## retirada). La pieza va cortada por el eje, con la otra mitad translúcida, para ver el agujero por dentro (CSG); la
## viruta sale por la boca del agujero (chips.gd) y la taladrina es la de coolant.gd.
##
## La escena no calcula mecanizado: pinta la vista del estado (MillDrillState.drill_3d_view) con set_state(vista).
## Marco: metros; +y arriba, +z hacia el operario; el eje del husillo es x = z = 0.
extends Node3D

const Shapes = preload("res://app/taller/lathe3d/shapes.gd")
const ChipView = preload("res://app/taller/lathe3d/chip_view.gd")
const Coolant = preload("res://app/taller/lathe3d/coolant.gd")
const Mill3D = preload("res://app/taller/mill3d/mill_3d.gd")
const MillDrillState = preload("res://core/taller/mill_drill_state.gd")
const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")

const BASE_TOP := 0.06
const COLUMN_R := 0.0625
const COLUMN_Z := -0.30
const TABLE_SIZE := Vector3(0.40, 0.03, 0.42)
## Nariz del husillo con la caña recogida: a 1245 mm de la base (ficha)
const HEAD_BOTTOM := BASE_TOP + 1.245
## Carrera de la caña (ficha) y lo que asoma recogida (dibujo)
const QUILL_STROKE := 0.18
const QUILL_REST := 0.015
## Distancia de la nariz del husillo a la mesa, mínima y máxima (ficha)
const SPINDLE_TABLE := Vector2(0.07, 0.885)
const PLATE := Vector2(0.14, 0.10)  ## largo (x) y fondo (z) de la pieza (m)
## Paso de la cremallera de la caña: una vuelta de las manetas por cada 100 mm de bajada (dibujo)
const FEED_PER_TURN := 0.1
const STROBE_START_DEG := 18.0
const STROBE_FULL_DEG := 75.0
const STROBE_APPARENT_RPS := 0.35
## Espesor de la pieza que se rehace la CSG del agujero (m): no hace falta a cada fotograma
const HOLE_STEP := 0.0002

var state: Dictionary = {}
var spin_angle := 0.0
var blur := 0.0

var _mats := {}
var _table: Node3D  # mesa, brazo y collar: suben o bajan por la columna
var _table_y := 0.95  # cara de arriba de la mesa (m)
var _spindle: Node3D  # la broca y el portabrocas: baja con la punta y gira
var _bit_root: Node3D
var _quill: MeshInstance3D
var _handles: Node3D
var _blur: MeshInstance3D
var _plate: CSGBox3D
var _ghost: CSGBox3D
var _holes: Array = []  # [cilindro, cono] de cada mitad
var _nozzle: Node3D
var chips: ChipView
var coolant: Coolant
var _bit_key := ""
var _plate_t := 0.03
var _hole_bottom := -1.0
var _bit_len := 0.1
@onready var _rig: Node3D = $CameraRig


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_environment()
	_make_materials()
	_build_machine()
	chips = ChipView.new()
	add_child(chips)
	chips.set_floor(0.0)
	coolant = Coolant.new()
	add_child(coolant)
	coolant.setup(_nozzle)
	_update_views()
	set_view("detalle", true)
	if not state.is_empty():
		var s := state
		state = {}
		set_state(s)


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
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = true
	($WorldEnvironment as WorldEnvironment).environment = env
	var sun := $Sun as DirectionalLight3D
	sun.basis = Basis.looking_at(Vector3(0.9, -3.0, -2.2), Vector3.UP)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 5.0


func _make_materials() -> void:
	_mats = {
		"paint": Mill3D._mat(Color("#3f6a86"), 0.0, 0.4),
		"paint_dark": Mill3D._mat(Color("#2b3033"), 0.0, 0.5),
		"cast": Mill3D._mat(Color("#4a4e52"), 0.35, 0.55),
		"steel": Mill3D._mat(Color("#a9adb0"), 1.0, 0.42),
		"steel_dark": Mill3D._mat(Color("#6d7175"), 1.0, 0.36),
		"chrome": Mill3D._mat(Color("#dcdfe2"), 1.0, 0.08),
		"black": Mill3D._mat(Color("#0d0e0f"), 0.2, 0.55),
		"red": Mill3D._mat(Color("#b8161c"), 0.0, 0.32),
		"yellow": Mill3D._mat(Color("#e2b31a"), 0.0, 0.45),
		"floor": Mill3D._mat(Color("#62625e"), 0.0, 0.9),
		"slot": Mill3D._mat(Color("#1b1d1f"), 0.3, 0.7),
		"bit": Mill3D._mat(Color("#b9bcbe"), 1.0, 0.3),
		"flute": Mill3D._mat(Color("#2a2c30"), 0.8, 0.35),
		"section": Mill3D._mat(Color("#8a8d92"), 0.8, 0.35),
		"hole": Mill3D._mat(Color("#34373c"), 0.3, 0.7),
		"hose": Mill3D._mat(Color("#1f63b4"), 0.0, 0.42),
	}
	(_mats["flute"] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	var ghost := Mill3D._mat(Color(0.62, 0.74, 0.86, 0.1), 0.2, 0.4)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["ghost"] = ghost
	var blur_mat := Mill3D._mat(Color(0.8, 0.82, 0.86, 0.0), 0.8, 0.3)
	blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["blur"] = blur_mat


func _mi(parent: Node3D, mesh: Mesh, mat_name: String, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats[mat_name]
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, a: Vector3, b: Vector3, mat_name: String, r := 0.0) -> MeshInstance3D:
	var bx: Dictionary = Shapes.box_between(a, b, r, 2 if r > 0.0 else 0)
	return _mi(parent, bx["mesh"], mat_name, bx["center"])


func _cyl(parent: Node3D, r: float, y0: float, y1: float, mat_name: String, pos := Vector3.ZERO, sides := 32) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = absf(y1 - y0)
	cm.radial_segments = sides
	cm.rings = 1
	return _mi(parent, cm, mat_name, pos + Vector3(0.0, (y0 + y1) / 2.0, 0.0))


# ─── máquina ─────────────────────────────────────────────────────────────────────────────────────────────

func _build_machine() -> void:
	var root := Node3D.new()
	root.name = "Machine"
	add_child(root)
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	_mi(root, pm, "floor")
	# Base con ranuras en T y columna
	_box(root, Vector3(-0.246, 0.0, COLUMN_Z - 0.10), Vector3(0.246, BASE_TOP, COLUMN_Z + 0.555), "cast", 0.01)
	_cyl(root, COLUMN_R, BASE_TOP, 1.72, "steel", Vector3(0.0, 0.0, COLUMN_Z), 40)
	# Mesa con su brazo y el collar de la columna (en su marco, la cara de arriba de la mesa en y = 0)
	_table = Node3D.new()
	_table.name = "Mesa"
	root.add_child(_table)
	_cyl(_table, COLUMN_R + 0.012, -0.12, -0.03, "paint", Vector3(0.0, 0.0, COLUMN_Z), 40)
	_box(_table, Vector3(-0.07, -0.10, COLUMN_Z + 0.04), Vector3(0.07, -0.03, -0.16), "paint", 0.008)
	_box(_table, Vector3(-TABLE_SIZE.x / 2.0, -TABLE_SIZE.y, -TABLE_SIZE.z / 2.0), Vector3(TABLE_SIZE.x / 2.0, 0.0, TABLE_SIZE.z / 2.0), "cast", 0.004)
	for k in [-1, 1]:
		_box(_table, Vector3(float(k) * 0.08 - 0.009, -0.0005, -TABLE_SIZE.z / 2.0), Vector3(float(k) * 0.08 + 0.009, 0.0004, TABLE_SIZE.z / 2.0), "slot")
	_table.position = Vector3(0.0, _table_y, 0.0)
	# Cabezal, motor detrás y botonera con la seta de emergencia
	_box(root, Vector3(-0.14, HEAD_BOTTOM, COLUMN_Z - 0.12), Vector3(0.14, 1.72, 0.12), "paint", 0.02)
	_cyl(root, 0.075, 1.72, 1.98, "paint_dark", Vector3(0.0, 0.0, COLUMN_Z - 0.02), 32)
	_box(root, Vector3(-0.13, 1.52, 0.12), Vector3(-0.04, 1.66, 0.135), "paint_dark", 0.004)
	var mush := CylinderMesh.new()
	mush.top_radius = 0.018
	mush.bottom_radius = 0.018
	mush.height = 0.014
	_mi(root, mush, "red", Vector3(-0.085, 1.62, 0.145), Basis(Vector3.RIGHT, PI / 2.0))
	_cyl(root, 0.03, 0.0, 0.004, "yellow", Vector3(-0.085, 1.62, 0.134), 24).rotation = Vector3(PI / 2.0, 0.0, 0.0)
	# Manetas del avance: tres radios con bola a la derecha del cabezal (giran al bajar la caña)
	_handles = Node3D.new()
	_handles.name = "Manetas"
	_handles.position = Vector3(0.155, 1.52, -0.02)
	root.add_child(_handles)
	_cyl(_handles, 0.03, -0.02, 0.02, "chrome", Vector3.ZERO, 20).rotation = Vector3(0.0, 0.0, PI / 2.0)
	var ball := SphereMesh.new()
	ball.radius = 0.016
	ball.height = 0.032
	for k in 3:
		var a := TAU * float(k) / 3.0
		var dir := Vector3(0.0, cos(a), sin(a))
		var spoke := CylinderMesh.new()
		spoke.top_radius = 0.0055
		spoke.bottom_radius = 0.0055
		spoke.height = 0.2
		var sp := _mi(_handles, spoke, "chrome", Vector3(0.03, 0.0, 0.0) + dir * 0.1)
		sp.basis = Basis(Quaternion(Vector3.UP, dir))
		_mi(_handles, ball, "black", Vector3(0.03, 0.0, 0.0) + dir * 0.2)
	# Caña (sale del cabezal hasta el portabrocas), portabrocas y broca, que bajan y giran
	_quill = _cyl(root, 0.036, HEAD_BOTTOM - 0.1, HEAD_BOTTOM, "chrome", Vector3.ZERO, 40)
	_spindle = Node3D.new()
	_spindle.name = "Spindle"
	add_child(_spindle)
	_bit_root = Node3D.new()
	_bit_root.name = "Broca"
	_spindle.add_child(_bit_root)
	_blur = MeshInstance3D.new()
	_blur.material_override = _mats["blur"]
	_spindle.add_child(_blur)
	# Pieza cortada por el eje (la mitad de atrás) y la otra mitad translúcida, con el agujero que va quedando
	_plate = _make_plate("section", -1.0)
	_ghost = _make_plate("ghost", 1.0)
	# Tobera de la taladrina
	_nozzle = Node3D.new()
	_nozzle.name = "Nozzle"
	add_child(_nozzle)
	_mi(_nozzle, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.006), Vector2(0.03, 0.0035), Vector2(0.03, 0.0)]), 16), "hose", Vector3.ZERO, Basis(Vector3.UP, PI * 0.5))


## Media pieza (z de 0 a side·fondo/2) con el agujero restado: un cilindro y la punta cónica.
func _make_plate(mat_name: String, side: float) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = "Pieza_" + ("delante" if side > 0.0 else "detras")
	box.material = _mats[mat_name]
	if side > 0.0:
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # la translúcida no oscurece el corte
	add_child(box)
	# Las caras que deja cada forma restada llevan su material: en la mitad de atrás, más oscuro, para que el agujero se
	# distinga de la cara del corte; en la translúcida, el suyo
	var hole_mat: Material = _mats["hole"] if side < 0.0 else _mats[mat_name]
	var cyl := CSGCylinder3D.new()
	cyl.operation = CSGShape3D.OPERATION_SUBTRACTION
	cyl.sides = 32
	cyl.material = hole_mat
	box.add_child(cyl)
	var cone := CSGCylinder3D.new()
	cone.operation = CSGShape3D.OPERATION_SUBTRACTION
	cone.cone = true
	cone.sides = 32
	cone.material = hole_mat
	cone.rotation = Vector3(PI, 0.0, 0.0)  # la punta hacia abajo
	box.add_child(cone)
	_holes.append([cyl, cone, side])
	return box


# ─── API ─────────────────────────────────────────────────────────────────────────────────────────────────

## Vista del estado (MillDrillState.drill_3d_view).
func set_state(v: Dictionary) -> void:
	state = v
	if _spindle == null:
		return
	var d := float(v["d_mm"]) / 1000.0
	var tip := float(v["tip_mm"]) / 1000.0
	var t := plate_thickness(v)
	var key := "%s|%s|%s|%s|%s" % [v["d_mm"], v["sigma_deg"], v["helix_deg"], v["tool_id"], t]
	if key != _bit_key:
		_bit_key = key
		_plate_t = t
		_build_bit(v, d, tip)
		_table_y = table_top(v)
		_table.position = Vector3(0.0, _table_y, 0.0)
		_place_plate(d)
		_hole_bottom = -1.0
		_update_views()
	chips.set_kind(str(v["work_kind"]))
	var look := Mill3D.work_look(str(v["work_kind"]))
	(_mats["section"] as StandardMaterial3D).albedo_color = look["machined"]
	(_mats["section"] as StandardMaterial3D).metallic = look["metallic"]
	(_mats["hole"] as StandardMaterial3D).albedo_color = (look["machined"] as Color).darkened(0.6)
	_update_hole(d, tip, float(v["bottom_mm"]) / 1000.0)
	_place_spindle(float(v["depth_mm"]) / 1000.0)


func set_view(view_name: String, instant := false) -> void:
	_rig.call("set_view", view_name, instant)


## Espesor de la pieza (m): la profundidad pedida más la punta y 10 mm por debajo, y 25 mm como poco. Puro (tests).
static func plate_thickness(v: Dictionary) -> float:
	return maxf(0.025, (float(v["depth_goal_mm"]) + float(v["tip_mm"]) + 10.0) / 1000.0)


## Largo de la broca con el portabrocas, de la punta a la nariz del husillo (m): gargantas de 6·D como poco (más que el
## agujero, para que el portabrocas no llegue a la pieza), mango de 3·D (30 mm como poco) y portabrocas. Puro (tests).
static func bit_length(v: Dictionary) -> float:
	var d := float(v["d_mm"]) / 1000.0
	var lf := maxf(6.0 * d, (float(v["depth_goal_mm"]) + float(v["tip_mm"])) / 1000.0 + 0.015)
	var shank := maxf(0.03, 3.0 * d)
	return lf + shank * 0.35 + 0.095


## Altura de la cara de arriba de la mesa (m): la que deja la punta a DRILL_CLEAR_MM de la pieza con la caña recogida,
## como la pondría el operario. Puro (tests).
static func table_top(v: Dictionary) -> float:
	return HEAD_BOTTOM - QUILL_REST - bit_length(v) - MillDrillState.DRILL_CLEAR_MM / 1000.0 - plate_thickness(v)


## Cara de arriba de la pieza (m).
func plate_top() -> float:
	return _table_y + _plate_t


# ─── broca, pieza y agujero ──────────────────────────────────────────────────────────────────────────────

func _build_bit(v: Dictionary, d: float, tip: float) -> void:
	for ch in _bit_root.get_children():
		_bit_root.remove_child(ch)
		ch.queue_free()
	var r := d / 2.0
	# Largo de las gargantas y del mango: los de bit_length
	var lf := maxf(6.0 * d, float(v["depth_goal_mm"]) / 1000.0 + tip + 0.015)
	var shank := maxf(0.03, 3.0 * d)
	(_mats["bit"] as StandardMaterial3D).albedo_color = Mill3D._tool_color(str(v["tool_id"]))
	_mi(_bit_root, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(tip, r), Vector2(lf, r), Vector2(lf + 0.002, r * 0.96),
		Vector2(lf + shank, r * 0.96), Vector2(lf + shank, 0.0)]), 32, false), "bit", Vector3.ZERO, Basis(Vector3.BACK, PI / 2.0))
	var helix := deg_to_rad(maxf(float(v["helix_deg"]), 5.0))
	var pitch := PI * d / tan(helix)
	var turns := (lf - tip) / pitch
	for k in 2:
		var rib := _mi(_bit_root, Shapes.helix_ribbon(r * 1.004, r * 1.004, pitch, turns, r * 0.9, maxi(24, int(turns * 48.0))), "flute", Vector3(0.0, (tip + lf) / 2.0, 0.0))
		rib.rotation = Vector3(0.0, PI * float(k), 0.0)
	# Portabrocas: cuerpo con la punta cónica y el anillo
	var rc := maxf(0.022, r + 0.008)
	var y0 := lf + shank * 0.35
	_mi(_bit_root, Shapes.revolve(PackedVector2Array([Vector2(y0, 0.0), Vector2(y0, r + 0.002), Vector2(y0 + 0.02, rc), Vector2(y0 + 0.09, rc),
		Vector2(y0 + 0.095, rc * 0.8), Vector2(y0 + 0.095, 0.0)]), 32, true), "steel_dark", Vector3.ZERO, Basis(Vector3.BACK, PI / 2.0))
	_cyl(_bit_root, rc * 1.04, y0 + 0.045, y0 + 0.06, "black", Vector3.ZERO, 32)
	_bit_len = bit_length(v)  # = y0 + 0.095
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = lf - tip
	cm.cap_top = false
	cm.cap_bottom = false
	_blur.mesh = cm
	_blur.position = Vector3(0.0, (tip + lf) / 2.0, 0.0)


func _place_plate(d: float) -> void:
	_plate.size = Vector3(PLATE.x, _plate_t, PLATE.y / 2.0)
	# La mitad translúcida, 1 mm más pequeña con el mismo centro: sus caras no coinciden con la del corte ni con la mesa
	# (dos caras en el mismo plano parpadean)
	_ghost.size = Vector3(PLATE.x - 0.001, _plate_t - 0.001, PLATE.y / 2.0 - 0.001)
	_plate.position = Vector3(0.0, _table_y + _plate_t / 2.0, -PLATE.y / 4.0)
	_ghost.position = Vector3(0.0, _table_y + _plate_t / 2.0, PLATE.y / 4.0)
	chips.set_box(0, Rect2(-TABLE_SIZE.x / 2.0, -TABLE_SIZE.z / 2.0, TABLE_SIZE.x, TABLE_SIZE.z), _table_y)
	chips.set_box(1, Rect2(-PLATE.x / 2.0, -PLATE.y / 2.0, PLATE.x, PLATE.y), plate_top())
	_nozzle.position = Vector3(-0.07, plate_top() + 0.06, -0.06)
	_nozzle.basis = Basis.looking_at(Vector3(0.0, plate_top() + 0.002, 0.0) - _nozzle.position, Vector3.UP)
	# Radio del agujero de las dos mitades
	for h in _holes:
		(h[0] as CSGCylinder3D).radius = d / 2.0
		(h[1] as CSGCylinder3D).radius = d / 2.0


## Agujero hasta la punta en bottom (m bajo la cara): el cilindro del diámetro entero y la punta cónica. Se rehace solo
## cada HOLE_STEP.
func _update_hole(_d: float, tip: float, bottom: float) -> void:
	if absf(bottom - _hole_bottom) < HOLE_STEP and _hole_bottom >= 0.0:
		return
	_hole_bottom = bottom
	var on := bottom > 0.0
	var cyl_len := maxf(bottom - tip, 0.0)
	for h in _holes:
		var cyl: CSGCylinder3D = h[0]
		var cone: CSGCylinder3D = h[1]
		var side: float = h[2]
		cyl.visible = on and cyl_len > 0.0
		cone.visible = on
		# En el marco de su media pieza (centrada en y y en z = side·fondo/4)
		var top_local := _plate_t / 2.0
		var zc := -side * PLATE.y / 4.0
		cyl.height = cyl_len + 0.001
		cyl.position = Vector3(0.0, top_local - cyl_len / 2.0 + 0.0005, zc)
		cone.height = tip
		cone.position = Vector3(0.0, top_local - (bottom - tip) - tip / 2.0, zc)


func _place_spindle(depth: float) -> void:
	var tip_y := plate_top() - depth
	_spindle.position = Vector3(0.0, tip_y, 0.0)
	var q0 := tip_y + _bit_len
	var qm := _quill.mesh as CylinderMesh
	qm.height = maxf(HEAD_BOTTOM - q0, 0.01)
	_quill.position = Vector3(0.0, (q0 + HEAD_BOTTOM) / 2.0, 0.0)
	_handles.rotation = Vector3(-(depth + MillDrillState.DRILL_CLEAR_MM / 1000.0) / FEED_PER_TURN * TAU, 0.0, 0.0)


func _update_views() -> void:
	var zone := Vector3(0.0, plate_top() - 0.01, 0.0)
	var span := clampf(_plate_t * 4.0 + 0.1, 0.22, 0.7)
	_rig.set("views", {
		"detalle": { "target": zone, "yaw": 24.0, "pitch": 14.0, "distance": span, "fov": 36.0 },
		"frontal": { "target": zone, "yaw": 0.0, "pitch": 4.0, "distance": span * 1.2, "fov": 36.0 },
		"superior": { "target": zone, "yaw": 0.0, "pitch": 80.0, "distance": span, "fov": 36.0 },
		"general": { "target": Vector3(0.0, 0.95, -0.15), "yaw": 32.0, "pitch": 14.0, "distance": 3.0, "fov": 38.0 },
	})


# ─── fotograma ──────────────────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if state.is_empty():
		return
	var omega := float(state["rpm"]) / 60.0 * TAU
	var per_frame := absf(rad_to_deg(omega * delta))
	blur = clampf((per_frame - STROBE_START_DEG) / (STROBE_FULL_DEG - STROBE_START_DEG), 0.0, 1.0)
	var shown := lerpf(omega, TAU * STROBE_APPARENT_RPS if omega > 0.0 else 0.0, blur)
	spin_angle = fmod(spin_angle + shown * delta, TAU)
	_bit_root.rotation = Vector3(0.0, -spin_angle, 0.0)
	var m := _mats["blur"] as StandardMaterial3D
	m.albedo_color = Color(m.albedo_color, 0.3 * blur)
	_blur.visible = blur > 0.01
	# Viruta por la boca del agujero, hacia arriba y hacia un lado que va girando con la broca
	var mouth := Vector3(0.0, plate_top() + 0.0015, 0.0)
	var flow := Vector3(cos(spin_angle), 1.2, sin(spin_angle))
	var cutting := bool(state["cutting"]) and float(state["rpm"]) > 0.0
	chips.tick(delta, cutting, mouth, flow, float(state["pc_kw"]), float(state["rpm"]), float(state["vc"]))
	coolant.update(bool(state["coolant"]), mouth)
