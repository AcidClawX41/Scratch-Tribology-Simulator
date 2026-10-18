## Pieza del torno: la malla de revolución dinámica (core/taller/lathe_mesh.gd) con el material de acabado.
##
## La malla está en milímetros y en coordenadas del torno (x local = z del torno, radio en el plano yz); el nodo
## padre la escala a metros y la hace girar. Cada fotograma se lee el perfil de la fuente y, si hay anillos
## sucios, solo se reescriben esos bytes en la GPU (surface_update_vertex_region / surface_update_attribute_region).
extends MeshInstance3D

const LatheMesh = preload("res://core/taller/lathe_mesh.gd")
const FINISH_SHADER = preload("res://app/taller/acabado.gdshader")

var lathe_mesh: LatheMesh
var plan := {}  ## banda de tolerancia del plano ({z0, dz, r_min, r_max}); vacía: sin plano
var finish: ShaderMaterial
var last_update_usec := 0  ## coste (CPU) de la última actualización por rangos, en µs
var last_rebuild_usec := 0  ## coste (CPU) de la última reconstrucción completa, en µs
var rebuilds := 0

var _mesh: ArrayMesh
var _nt_offset := 0
var _profile := {}


func _init() -> void:
	name = "Workpiece"
	finish = ShaderMaterial.new()
	finish.shader = FINISH_SHADER
	material_override = finish
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Nivel de detalle: lados por anillo y tope de anillos (64 y 2000 en escritorio; 32 y 800 en móvil).
func configure_lod(sides: int, max_rings: int) -> void:
	lathe_mesh = LatheMesh.new(sides, max_rings)
	if not _profile.is_empty():
		rebuild(_profile)


## Reconstruye la malla entera (pieza nueva, otra rejilla u otro plano).
func rebuild(profile: Dictionary) -> void:
	if lathe_mesh == null:
		lathe_mesh = LatheMesh.new(64, 2000)
	_profile = profile
	var rr: PackedFloat64Array = profile.get("r", PackedFloat64Array())
	if rr.size() < 2:
		mesh = null
		return
	var b := lathe_mesh.build(profile, plan)
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b["arrays"], [], {}, LatheMesh.CUSTOM_FORMAT)
	var fmt := _mesh.surface_get_format(0)
	var vc := lathe_mesh.vertex_count
	_nt_offset = RenderingServer.mesh_surface_get_format_offset(fmt, vc, Mesh.ARRAY_NORMAL)
	var ok := RenderingServer.mesh_surface_get_format_vertex_stride(fmt, vc) == LatheMesh.POS_STRIDE \
		and RenderingServer.mesh_surface_get_format_normal_tangent_stride(fmt, vc) == LatheMesh.NT_STRIDE \
		and RenderingServer.mesh_surface_get_format_attribute_stride(fmt, vc) == LatheMesh.ATTR_STRIDE \
		and _nt_offset == vc * LatheMesh.POS_STRIDE
	if not ok:
		push_error("Formato de vértices inesperado: la malla de la pieza no se podrá actualizar por rangos.")
	mesh = _mesh
	custom_aabb = b["aabb"]
	rebuilds += 1


## Lee el perfil de la fuente y aplica los anillos sucios. Devuelve true si ha cambiado algo.
func apply_profile(profile: Dictionary) -> bool:
	var t0 := Time.get_ticks_usec()
	if lathe_mesh == null or _mesh == null or not lathe_mesh.matches(profile):
		rebuild(profile)
		last_rebuild_usec = Time.get_ticks_usec() - t0
		return true
	_profile = profile
	var d: Vector2i = profile.get("dirty", Vector2i(-1, -1))
	if d.x < 0 or d.y < d.x:
		return false
	var upd := lathe_mesh.update(profile, plan, d.x, d.y)
	if upd.is_empty():
		return false
	_mesh.surface_update_vertex_region(0, upd["pos_offset"], upd["pos"])
	_mesh.surface_update_vertex_region(0, _nt_offset + int(upd["first_vertex"]) * LatheMesh.NT_STRIDE, upd["nt"])
	_mesh.surface_update_attribute_region(0, upd["attr_offset"], upd["attr"])
	last_update_usec = Time.get_ticks_usec() - t0
	return true


## Nuevo plano (banda de tolerancia): se reconstruye porque cambian las desviaciones de todos los anillos.
func set_plan(band: Dictionary) -> void:
	plan = band
	if not _profile.is_empty():
		rebuild(_profile)


## Uniformes del material de acabado (ver acabado.gdshader).
func set_finish_params(params: Dictionary) -> void:
	for k in params:
		finish.set_shader_parameter(k, params[k])
