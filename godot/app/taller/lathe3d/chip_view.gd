## Virutas del torno en pantalla: un MultiMeshInstance3D por forma de viruta (rizada, espiral, astillada),
## alimentado por el emisor determinista de core/taller/chips.gd. Las mallas son cintas helicoidales procedurales.
extends Node3D

const Chips = preload("res://core/taller/chips.gd")
const Shapes = preload("res://app/taller/lathe3d/shapes.gd")

var capacity := 360  ## virutas por forma
var kind := "acero"

var _emitters := {}  # forma → Chips
var _views := {}  # forma → MultiMeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	name = "Chips"
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.metallic = 0.65  # la capa de óxido colorea sobre todo el reflejo; algo de difuso la hace legible
	_material.roughness = 0.32
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes := {
		# Viruta en arco (la del rompevirutas): algo más de media vuelta que se cierra, ancho ≈ profundidad
		"rizada": Shapes.chip_curl(0.0034, 0.0022, 0.0026, 0.85, 0.0019, 0.0006, 16),
		# Viruta tubular/helicoidal: varias vueltas
		"espiral": Shapes.chip_curl(0.0036, 0.0033, 0.0036, 3.5, 0.0017, 0.0004, 64),
		# Viruta elemental: un trocito curvado
		"astillada": Shapes.chip_curl(0.0013, 0.0012, 0.0005, 0.25, 0.001, 0.0004, 4),
	}
	for form: String in Chips.FORMS:
		var em := Chips.new("acero", "torno3d:virutas:" + form, capacity)
		_emitters[form] = em
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[form]
		mm.instance_count = capacity
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chips_" + form
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# El volumen de las virutas cambia en cada fotograma: un AABB fijo alrededor de la máquina evita que se
		# recorten al salir del volumen de la malla original.
		mmi.custom_aabb = AABB(Vector3(-1.5, 0.0, -1.0), Vector3(3.0, 2.0, 2.5))
		add_child(mmi)
		_views[form] = mmi
	set_kind(kind)


## Material de la pieza (kind de CONTRATOS.md): decide la forma y el color de las próximas virutas.
func set_kind(k: String) -> void:
	kind = k
	for form: String in _emitters:
		(_emitters[form] as Chips).set_kind(k)
	var metal := bool(Chips.KINDS.get(k, Chips.KINDS["acero"])["metal"])
	if _material != null:
		_material.metallic = 0.65 if metal else 0.0
		_material.roughness = 0.32 if metal else 0.6


## Superficies de reposo (las mismas para todas las formas): ver Chips.set_box.
func set_box(id: int, rect: Rect2, y: float) -> void:
	for form: String in _emitters:
		(_emitters[form] as Chips).set_box(id, rect, y)


func set_floor(y: float) -> void:
	for form: String in _emitters:
		(_emitters[form] as Chips).floor_y = y


## Un fotograma: emite (si corta) con el emisor de la forma del material y mueve todas las virutas.
func tick(dt: float, cutting: bool, tip: Vector3, flow: Vector3, pc_kw: float, rpm: float, vc: float) -> void:
	var form := Chips.form_for(kind)
	if cutting:
		(_emitters[form] as Chips).emit(dt, tip, flow, Chips.rate_for(kind, pc_kw, rpm), vc)
	for f: String in _emitters:
		var em: Chips = _emitters[f]
		if em.count == 0:
			continue
		em.step(dt)
		var mm := (_views[f] as MultiMeshInstance3D).multimesh
		mm.buffer = em.buffer
		mm.visible_instance_count = em.count


## Virutas en el aire (todas las formas), para el panel y las pruebas.
func flying() -> int:
	var n := 0
	for f: String in _emitters:
		n += (_emitters[f] as Chips).flying()
	return n


func total() -> int:
	var n := 0
	for f: String in _emitters:
		n += (_emitters[f] as Chips).count
	return n
