## Fresadora vertical de torreta en 3D (unidad 1e), construida por código como el torno: bancada, columna, consola,
## carro y mesa de 1406 × 254 mm con sus 3 ranuras en T de 16 mm cada 63 mm, carnero y cabezal con la caña de Ø85,7 mm
## y 127 mm de carrera (las cotas de la Lagun FTV 2, catálogo de Lagun Machinery de 2016), el portaherramientas y la
## fresa: de planear, con z plaquitas del color de su recubrimiento, o de mango, con z hélices. La consola sube la pieza
## hasta la fresa, como lo haría el operario, con la caña casi recogida (QUILL_EXT). La fresa gira a las rpm de verdad
## (con el efecto estroboscópico controlado del torno a rpm altas: se deja de ver el giro real y se ve una deriva lenta y
## un anillo borroso), la mesa lleva la pieza a su vf real y la pieza se va rebajando ap en la franja de ancho ae.
## Virutas del emisor determinista del core (chips.gd) y taladrina de coolant.gd.
##
## La escena no calcula mecanizado: pinta la vista del estado (MillDrillState.mill_3d_view) con set_state(vista).
## Marco: metros; +x hacia donde avanza la fresa sobre la pieza (la mesa va hacia −x), +y arriba, +z hacia el operario;
## el eje del husillo es x = z = 0. Un diente en φ (el ángulo de cutting.gd) está en R·(sen φ, 0, −cos φ): φ = 0 hacia
## la columna, 90° en el sentido del avance; M03 gira en sentido horario visto desde arriba.
extends Node3D

const Shapes = preload("res://app/taller/lathe3d/shapes.gd")
const ChipView = preload("res://app/taller/lathe3d/chip_view.gd")
const Coolant = preload("res://app/taller/lathe3d/coolant.gd")
const Chips = preload("res://core/taller/chips.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")
const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")

const TABLE_Y := 0.96  ## cara de arriba de la mesa con la consola a media carrera (m); sube o baja knee_rise
const KNEE_TRAVEL := 0.406  ## carrera vertical de la consola (ficha)
const TABLE_SIZE := Vector3(1.406, 0.07, 0.254)
const SLOT_PITCH := 0.063
const SLOT_W := 0.016
const QUILL_R := 0.0857 / 2.0
const QUILL_STROKE := 0.127
const QUILL_EXT := 0.03  ## lo que sale la caña del cabezal al fresar (dibujo)
const HOLDER_H := 0.085  ## portaherramientas ISO 40 (cono y brida)
const HEAD_BOTTOM := 1.30
## Efecto estroboscópico controlado (el mismo criterio que el torno): por encima de STROBE_START grados por fotograma el
## giro dibujado se frena hacia STROBE_APPARENT_RPS vueltas por segundo en el sentido real y aparece el anillo borroso.
const STROBE_START_DEG := 18.0
const STROBE_FULL_DEG := 75.0
const STROBE_APPARENT_RPS := 0.35

var state: Dictionary = {}
var spin_angle := 0.0
var blur := 0.0

var _mats := {}
var _knee: Node3D  # consola, carro y mesa: suben knee_rise
var _screw: MeshInstance3D  # husillo de la consola, de la bancada a la consola
var _table: Node3D
var _spindle: Node3D  # gira alrededor de +y (la fresa y su portaherramientas)
var _tool_root: Node3D
var _blur_ring: MeshInstance3D
var _quill: MeshInstance3D
var _block_parts := {}  # nombre → MeshInstance3D con BoxMesh
var _nozzle: Node3D
var chips: ChipView
var coolant: Coolant
var _tool_key := ""
var _block_key := ""
var _cut_y := TABLE_Y + 0.02  # altura de la cara de abajo de la fresa (m)
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
	env.ssao_enabled = true  # solo Forward+
	($WorldEnvironment as WorldEnvironment).environment = env
	var sun := $Sun as DirectionalLight3D
	sun.basis = Basis.looking_at(Vector3(0.9, -3.0, -2.2), Vector3.UP)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 5.0


func _make_materials() -> void:
	_mats = {
		"paint": _mat(Color("#56656d"), 0.0, 0.42),
		"paint_dark": _mat(Color("#2f3538"), 0.0, 0.5),
		"cast": _mat(Color("#4a4e52"), 0.35, 0.55),
		"steel": _mat(Color("#b9bcbe"), 1.0, 0.24),
		"steel_dark": _mat(Color("#6d7175"), 1.0, 0.36),
		"chrome": _mat(Color("#dcdfe2"), 1.0, 0.08),
		"black": _mat(Color("#0d0e0f"), 0.2, 0.55),
		"red": _mat(Color("#b8161c"), 0.0, 0.32),
		"floor": _mat(Color("#62625e"), 0.0, 0.9),
		"slot": _mat(Color("#1b1d1f"), 0.3, 0.7),
		"insert": _mat(Color("#6D5F87"), 1.0, 0.3),
		"flute": _mat(Color("#2a2c30"), 0.8, 0.35),
		"raw": _mat(Color("#303236"), 0.3, 0.8),
		"machined": _mat(Color("#c4c6c9"), 1.0, 0.18),
		"hose": _mat(Color("#1f63b4"), 0.0, 0.42),
	}
	var blur_mat := _mat(Color(0.8, 0.82, 0.86, 0.0), 0.8, 0.3)
	blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["blur"] = blur_mat
	var ribbon := (_mats["flute"] as StandardMaterial3D)
	ribbon.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _mi(parent: Node3D, mesh: Mesh, mat_name: String, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats[mat_name]
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


## Caja con cantos redondeados entre dos esquinas.
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
	# Bancada y columna
	_box(root, Vector3(-0.38, 0.0, -0.78), Vector3(0.38, 0.09, 0.30), "paint", 0.01)
	_box(root, Vector3(-0.24, 0.09, -0.78), Vector3(0.24, 1.50, -0.36), "paint", 0.02)
	# Consola y carro, que suben con la pieza, y el husillo de la consola desde la bancada
	_knee = Node3D.new()
	_knee.name = "Consola"
	add_child(_knee)
	_box(_knee, Vector3(-0.30, 0.45, -0.36), Vector3(0.30, TABLE_Y - 0.19, 0.16), "paint", 0.012)
	_box(_knee, Vector3(-0.26, TABLE_Y - 0.19, -0.26), Vector3(0.26, TABLE_Y - TABLE_SIZE.y, 0.18), "paint", 0.008)
	_screw = _cyl(root, 0.03, 0.09, 0.45, "chrome", Vector3(0.0, 0.0, 0.05), 20)
	var wheel := TorusMesh.new()  # volante del carro transversal
	wheel.inner_radius = 0.07
	wheel.outer_radius = 0.082
	_mi(_knee, wheel, "chrome", Vector3(0.0, TABLE_Y - 0.13, 0.22), Basis(Vector3.RIGHT, PI / 2.0))
	# Carnero y cabezal con el motor encima
	_box(root, Vector3(-0.14, 1.40, -0.78), Vector3(0.14, 1.58, 0.06), "paint", 0.02)
	_box(root, Vector3(-0.11, HEAD_BOTTOM, -0.13), Vector3(0.11, 1.46, 0.13), "paint", 0.02)
	_cyl(root, 0.085, 1.58, 1.80, "paint_dark", Vector3(0.0, 0.0, -0.02), 32)
	_cyl(root, 0.09, 1.80, 1.815, "black", Vector3(0.0, 0.0, -0.02), 32)
	# Palanca de la caña y botonera
	_box(root, Vector3(0.11, 1.34, 0.02), Vector3(0.24, 1.35, 0.03), "chrome")
	var ball := SphereMesh.new()
	ball.radius = 0.014
	ball.height = 0.028
	_mi(root, ball, "red", Vector3(0.245, 1.345, 0.025))
	_box(root, Vector3(-0.22, 1.20, 0.13), Vector3(-0.12, 1.34, 0.15), "paint_dark", 0.004)
	_cyl(root, 0.012, 0.0, 0.01, "red", Vector3(-0.17, 1.30, 0.155) - Vector3(0.0, 0.0, 0.0), 16).rotation = Vector3(PI / 2.0, 0.0, 0.0)
	# Mesa (se mueve a lo largo de x con la pieza, sobre el carro)
	_table = Node3D.new()
	_table.name = "Table"
	_knee.add_child(_table)
	_box(_table, Vector3(-TABLE_SIZE.x / 2.0, TABLE_Y - TABLE_SIZE.y, -TABLE_SIZE.z / 2.0), Vector3(TABLE_SIZE.x / 2.0, TABLE_Y, TABLE_SIZE.z / 2.0), "cast", 0.004)
	for k in [-1, 0, 1]:
		_box(_table, Vector3(-TABLE_SIZE.x / 2.0, TABLE_Y - 0.0005, float(k) * SLOT_PITCH - SLOT_W / 2.0), Vector3(TABLE_SIZE.x / 2.0, TABLE_Y + 0.0004, float(k) * SLOT_PITCH + SLOT_W / 2.0), "slot")
	for side in [-1.0, 1.0]:  # volantes de la mesa en los extremos
		var hw := TorusMesh.new()
		hw.inner_radius = 0.055
		hw.outer_radius = 0.065
		_mi(_table, hw, "chrome", Vector3(side * (TABLE_SIZE.x / 2.0 + 0.04), TABLE_Y - 0.035, 0.0), Basis(Vector3.FORWARD, PI / 2.0))
	for part in ["lower", "milled", "outside", "strip", "clamp_a", "clamp_b"]:
		var mi := MeshInstance3D.new()
		mi.name = "Pieza_" + part
		mi.mesh = BoxMesh.new()
		_table.add_child(mi)
		_block_parts[part] = mi
	# Caña (sale del cabezal hasta el portaherramientas) y husillo que gira
	_quill = _cyl(root, QUILL_R, HEAD_BOTTOM - 0.1, HEAD_BOTTOM, "chrome", Vector3.ZERO, 40)
	_spindle = Node3D.new()
	_spindle.name = "Spindle"
	add_child(_spindle)
	_tool_root = Node3D.new()
	_tool_root.name = "Fresa"
	_spindle.add_child(_tool_root)
	_blur_ring = MeshInstance3D.new()
	_blur_ring.material_override = _mats["blur"]
	add_child(_blur_ring)
	# Tobera de la taladrina, colgada del cabezal y apuntando a la fresa
	_nozzle = Node3D.new()
	_nozzle.name = "Nozzle"
	add_child(_nozzle)
	_mi(_nozzle, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.006), Vector2(0.03, 0.0035), Vector2(0.03, 0.0)]), 16), "hose", Vector3.ZERO, Basis(Vector3.UP, PI * 0.5))


# ─── API ─────────────────────────────────────────────────────────────────────────────────────────────────

## Vista del estado (MillDrillState.mill_3d_view). Rehace la fresa o la pieza solo si cambian.
func set_state(v: Dictionary) -> void:
	state = v
	if _table == null:
		return  # aún fuera del árbol: se aplica en _ready
	var tk := "%s|%s|%s|%s|%s|%s" % [v["tool_type"], v["dc_mm"], v["z"], v["kappa_deg"], v["helix_deg"], v["tool_id"]]
	var geo := block_geometry(v)
	var bk := "%s|%s|%s|%s" % [geo["cut_y"], geo["length"], geo["z0"], geo["z1"]]
	if tk != _tool_key or bk != _block_key:
		_tool_key = tk
		_cut_y = cut_height(v)
		_place_knee(_cut_y - float(geo["cut_y"]))
		_build_tool(v)
		_update_views()
	_block_key = bk
	_update_block(v, geo)
	chips.set_kind(str(v["work_kind"]))
	var look := work_look(str(v["work_kind"]))
	(_mats["raw"] as StandardMaterial3D).albedo_color = look["raw"]
	(_mats["machined"] as StandardMaterial3D).albedo_color = look["machined"]
	(_mats["machined"] as StandardMaterial3D).metallic = look["metallic"]


func set_view(view_name: String, instant := false) -> void:
	_rig.call("set_view", view_name, instant)


## Geometría de la pieza a partir de la vista (en m, marco de la mesa con la consola abajo, pieza de x = −L/2 a L/2):
## { length, height, cut_y (cara de abajo de la fresa), z0, z1 (ancho de la pieza), sz0, sz1 (franja que se fresa),
## x_cut (hasta dónde está fresada), table_x (posición de la mesa) }. Pura: la usan la escena y los tests.
static func block_geometry(v: Dictionary) -> Dictionary:
	var r := float(v["dc_mm"]) / 2000.0
	var ae := float(v["ae_mm"]) / 1000.0
	var ap := float(v["ap_mm"]) / 1000.0
	var length := float(v["length_mm"]) / 1000.0
	var width := float(v["width_mm"]) / 1000.0
	var height := maxf(0.040, ap + 0.025)
	var side := int(v["material_side"])
	var z0 := -ae / 2.0
	var z1 := ae / 2.0
	var sz0 := z0
	var sz1 := z1
	if side > 0:  # oposición: la pieza hacia la columna (−z) y la franja en el casquete de la fresa de ese lado
		z1 = -(r - ae)
		z0 = z1 - width
		sz0 = -r
		sz1 = z1
	elif side < 0:  # concordancia: la pieza hacia el operario
		z0 = r - ae
		z1 = z0 + width
		sz0 = z0
		sz1 = r
	var x := float(v["x_mm"]) / 1000.0
	return {
		"length": length, "height": height, "cut_y": TABLE_Y + height - ap, "ap": ap, "z0": z0, "z1": z1,
		"sz0": sz0, "sz1": sz1, "x_cut": -length / 2.0 + clampf(x, 0.0, length), "table_x": length / 2.0 - x,
	}


## Alto de la fresa sobre su cara de abajo, hasta el portaherramientas (m): el plato de la de planear o la parte
## cortante y el mango de la de mango. Puro (tests).
static func tool_height(v: Dictionary) -> float:
	var dc := float(v["dc_mm"]) / 1000.0
	if str(v["tool_type"]) == "planear":
		return clampf(0.55 * dc, 0.030, 0.060)
	return maxf(2.0 * dc, float(v["ap_mm"]) / 1000.0 + 0.01) + 0.04


## Altura de la cara de abajo de la fresa (m) con la caña fuera QUILL_EXT. Puro (tests).
static func cut_height(v: Dictionary) -> float:
	return HEAD_BOTTOM - QUILL_EXT - HOLDER_H - tool_height(v)


## Lo que sube la consola para que la pieza llegue a la fresa (m). Puro (tests).
static func knee_rise(v: Dictionary) -> float:
	return cut_height(v) - float(block_geometry(v)["cut_y"])


## Aspecto de la pieza por material: el metal mecanizado con el color de chips.gd (F0 en sRGB lineal) y el bruto más
## oscuro (cascarilla, estimación visual).
static func work_look(kind: String) -> Dictionary:
	var k: Dictionary = Chips.KINDS.get(kind, Chips.KINDS["acero"])
	var base: Color = (k["base"] as Color).linear_to_srgb()
	var metal: bool = k["metal"]
	return { "machined": base, "raw": base.darkened(0.78 if metal else 0.3), "metallic": 1.0 if metal else 0.0 }


# ─── fresa y pieza ───────────────────────────────────────────────────────────────────────────────────────

func _build_tool(v: Dictionary) -> void:
	for ch in _tool_root.get_children():
		_tool_root.remove_child(ch)
		ch.queue_free()
	var dc := float(v["dc_mm"]) / 1000.0
	var r := dc / 2.0
	var z := maxi(int(v["z"]), 1)
	(_mats["insert"] as StandardMaterial3D).albedo_color = _tool_color(str(v["tool_id"]))
	var top := tool_height(v)  # altura de la parte de arriba de la fresa sobre su cara de abajo
	if str(v["tool_type"]) == "planear":
		# Plato: cuerpo de acero, cubo y z plaquitas en la periferia inclinadas κr
		var hb := top
		var rb := r - 0.004
		_mi(_tool_root, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.002, rb * 0.95), Vector2(0.006, rb),
			Vector2(hb * 0.55, rb), Vector2(hb * 0.75, rb * 0.62), Vector2(hb, rb * 0.55), Vector2(hb, 0.0)]), 48, false), "steel_dark",
			Vector3.ZERO, Basis(Vector3.BACK, PI / 2.0))
		var kappa := deg_to_rad(float(v["kappa_deg"]))
		for k in z:
			var phi := TAU * float(k) / float(z)
			var holder := Node3D.new()
			holder.rotation = Vector3(0.0, -phi, 0.0)
			_tool_root.add_child(holder)
			# Plaquita cuadrada de 12 mm con el filo en la periferia (en −z del soporte, que gira con φ); su cara de
			# desprendimiento mira hacia +x, el sentido en que se mueve el diente en φ = 0, y el asiento va detrás
			var ins := _mi(holder, _box_mesh(Vector3(0.0045, 0.012, 0.012)), "insert", Vector3(0.0, 0.007, -(r - 0.006)))
			ins.rotation = Vector3(kappa - PI / 2.0, 0.0, 0.0)
			_mi(holder, _box_mesh(Vector3(0.008, 0.014, 0.010)), "steel_dark", Vector3(-0.0055, 0.009, -(r - 0.008)))
		_set_blur_ring(r, 0.012, _cut_y + 0.006)
	else:
		# Fresa de mango: parte cortante con z hélices y mango liso (el alto de tool_height)
		var shank := 0.04
		var lf := top - shank
		_mi(_tool_root, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0005, r * 0.97), Vector2(lf, r * 0.97),
			Vector2(lf + 0.002, r * 0.9), Vector2(lf + shank, r * 0.9), Vector2(lf + shank, 0.0)]), 32, false), "steel",
			Vector3.ZERO, Basis(Vector3.BACK, PI / 2.0))
		var helix := deg_to_rad(maxf(float(v["helix_deg"]), 5.0))
		var pitch := PI * dc / tan(helix)
		var turns := lf / pitch
		for k in z:
			var rib := _mi(_tool_root, Shapes.helix_ribbon(r * 0.985, r * 0.985, pitch, turns, r * 0.55, maxi(16, int(turns * 48.0))), "flute", Vector3(0.0, lf / 2.0, 0.0))
			rib.rotation = Vector3(0.0, -TAU * float(k) / float(z), 0.0)
		_set_blur_ring(r, lf, _cut_y + lf / 2.0)
	# Portaherramientas ISO 40 y la caña hasta el cabezal
	_cyl(_tool_root, 0.032, top, top + 0.07, "steel_dark", Vector3.ZERO, 32)
	_cyl(_tool_root, 0.040, top + 0.07, top + HOLDER_H, "black", Vector3.ZERO, 32)
	_spindle.position = Vector3(0.0, _cut_y, 0.0)
	var q0 := _cut_y + top + HOLDER_H
	var qm := _quill.mesh as CylinderMesh
	qm.height = maxf(HEAD_BOTTOM - q0, 0.01)
	_quill.position = Vector3(0.0, (q0 + HEAD_BOTTOM) / 2.0, 0.0)
	_nozzle.position = Vector3(-r - 0.05, _cut_y + 0.07, -r * 0.5 - 0.03)
	var aim := Vector3(0.0, _cut_y + 0.004, 0.0) - _nozzle.position
	_nozzle.basis = Basis.looking_at(aim, Vector3.UP)


## Sube la consola (con el carro, la mesa y la pieza) y alarga su husillo desde la bancada.
func _place_knee(rise: float) -> void:
	_knee.position = Vector3(0.0, rise, 0.0)
	var cm := _screw.mesh as CylinderMesh
	cm.height = 0.36 + rise
	_screw.position = Vector3(0.0, 0.09 + cm.height / 2.0, 0.05)


func _set_blur_ring(r: float, h: float, y: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 48
	cm.cap_top = false
	cm.cap_bottom = false
	_blur_ring.mesh = cm
	_blur_ring.position = Vector3(0.0, y, 0.0)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Color del filo: el del recubrimiento del catálogo; sin capa, acero o metal duro.
static func _tool_color(tool_id: String) -> Color:
	var t := ToolMaterials.get_tool(tool_id)
	var c = t.get("coating")
	if c != null and ToolMaterials.COATINGS.has(c):
		return Color(str(ToolMaterials.COATINGS[c]["color"]))
	return Color("#b9bcbe") if str(t.get("family", "")) == "hss" else Color("#7d8086")


func _update_block(v: Dictionary, g: Dictionary) -> void:
	_table.position = Vector3(float(g["table_x"]), 0.0, 0.0)
	var length := float(g["length"])
	var h := float(g["height"])
	var ap := float(g["ap"])
	var y_low := TABLE_Y + h - ap
	_set_part("lower", Vector3(-length / 2.0, TABLE_Y, float(g["z0"])), Vector3(length / 2.0, y_low, float(g["z1"])), "raw")
	# La cara recién fresada: una lámina brillante en la franja, desde el principio de la pieza hasta la fresa
	_set_part("milled", Vector3(-length / 2.0, y_low, float(g["sz0"])), Vector3(float(g["x_cut"]), y_low + 0.0003, float(g["sz1"])), "machined")
	# Capa de arriba fuera de la franja (fresado lateral) y la franja aún sin fresar, delante de la fresa
	var side := int(v["material_side"])
	if side > 0:
		_set_part("outside", Vector3(-length / 2.0, y_low, float(g["z0"])), Vector3(length / 2.0, TABLE_Y + h, float(g["sz0"])), "raw")
	elif side < 0:
		_set_part("outside", Vector3(-length / 2.0, y_low, float(g["sz1"])), Vector3(length / 2.0, TABLE_Y + h, float(g["z1"])), "raw")
	else:
		_set_part("outside", Vector3.ZERO, Vector3.ZERO, "raw")
	_set_part("strip", Vector3(float(g["x_cut"]), y_low, float(g["sz0"])), Vector3(length / 2.0, TABLE_Y + h, float(g["sz1"])), "raw")
	# Topes de sujeción en los dos extremos, más bajos que la cara de corte (la fresa entra y sale por ellos)
	var hc := (h - ap) * 0.6
	for part in [["clamp_a", -1.0], ["clamp_b", 1.0]]:
		var x0: float = float(part[1]) * (length / 2.0 + 0.004)
		var x1: float = float(part[1]) * (length / 2.0 + 0.030)
		_set_part(part[0], Vector3(minf(x0, x1), TABLE_Y, float(g["z0"]) - 0.01), Vector3(maxf(x0, x1), TABLE_Y + hc, float(g["z1"]) + 0.01), "steel_dark")
	# Las virutas se quedan en la mesa y sobre la pieza (se mueven con ellas; en el marco del mundo, con la consola subida)
	var tx := float(g["table_x"])
	var ty := TABLE_Y + _knee.position.y
	chips.set_box(0, Rect2(tx - TABLE_SIZE.x / 2.0, -TABLE_SIZE.z / 2.0, TABLE_SIZE.x, TABLE_SIZE.z), ty)
	chips.set_box(1, Rect2(tx - length / 2.0, float(g["z0"]), length, float(g["z1"]) - float(g["z0"])), ty + h)


func _set_part(part: String, a: Vector3, b: Vector3, mat_name: String) -> void:
	var mi: MeshInstance3D = _block_parts[part]
	var size := (b - a).abs()
	mi.visible = size.x > 1e-6 and size.y > 1e-6 and size.z > 1e-6
	if not mi.visible:
		return
	(mi.mesh as BoxMesh).size = size
	mi.position = (a + b) / 2.0
	mi.material_override = _mats[mat_name]


## Vistas de la cámara según el tamaño de la fresa y la altura de corte.
func _update_views() -> void:
	var dc := float(state.get("dc_mm", 63.0)) / 1000.0
	var zone := Vector3(0.0, _cut_y + 0.01, 0.0)
	_rig.set("views", {
		"detalle": { "target": zone + Vector3(0.01, -0.01, 0.0), "yaw": 30.0, "pitch": 32.0, "distance": clampf(6.0 * dc, 0.16, 0.6), "fov": 36.0 },
		"frontal": { "target": zone, "yaw": 0.0, "pitch": 10.0, "distance": clampf(8.0 * dc, 0.3, 0.8), "fov": 36.0 },
		"superior": { "target": zone, "yaw": 0.0, "pitch": 86.0, "distance": clampf(7.0 * dc, 0.28, 0.7), "fov": 36.0 },
		"general": { "target": Vector3(0.0, 0.95, -0.2), "yaw": 32.0, "pitch": 16.0, "distance": 3.0, "fov": 38.0 },
	})


# ─── fotograma ──────────────────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if state.is_empty():
		return
	_spin(delta)
	var r := float(state["dc_mm"]) / 2000.0
	var phi := float(state["phi_out"])
	# Las virutas salen por el final del arco de contacto: en el sentido del giro, hacia fuera y hacia arriba
	var u := Vector3(sin(phi), 0.0, -cos(phi))
	var t := Vector3(cos(phi), 0.0, sin(phi))
	var tip := Vector3(0.0, _cut_y + float(state["ap_mm"]) / 2000.0, 0.0) + u * r
	var cutting := bool(state["cutting"]) and float(state["rpm"]) > 0.0
	chips.tick(delta, cutting, tip, t + u * 0.6 + Vector3.UP * 0.8, float(state["pc_kw"]), float(state["rpm"]), float(state["vc"]))
	coolant.update(bool(state["coolant"]), tip)


## Giro de la fresa con el efecto estroboscópico controlado (horario visto desde arriba: M03).
func _spin(delta: float) -> void:
	var omega := float(state["rpm"]) / 60.0 * TAU
	var per_frame := absf(rad_to_deg(omega * delta))
	blur = clampf((per_frame - STROBE_START_DEG) / (STROBE_FULL_DEG - STROBE_START_DEG), 0.0, 1.0)
	var shown := lerpf(omega, TAU * STROBE_APPARENT_RPS if omega > 0.0 else 0.0, blur)
	spin_angle = fmod(spin_angle + shown * delta, TAU)
	_spindle.rotation = Vector3(0.0, -spin_angle, 0.0)
	var m := _mats["blur"] as StandardMaterial3D
	m.albedo_color = Color(m.albedo_color, 0.35 * blur)
	_blur_ring.visible = blur > 0.01
