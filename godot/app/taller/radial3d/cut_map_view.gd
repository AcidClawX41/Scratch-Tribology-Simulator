## Modo manual de la escena de la radial: el surco hecho a mano en la chapa. Sube el mapa del surco de
## core/taller/radial_manual.gd (texture_data) a una textura de datos que lee corte_manual.gdshader y construye las
## mallas de toda la línea que ese shader coloca (paredes y fondo del surco, rebabas e hilos de plástico). Las mallas se
## hacen al cambiar de chapa (o de disco, los hilos); en cada fotograma solo se sube la textura, y solo si el mapa
## cambió. Solo dibujo: los números los pone el core.
extends RefCounted

const PB = preload("res://app/taller/radial3d/panel_builder.gd")
const SHADER = preload("res://app/taller/radial3d/corte_manual.gdshader")

var material := ShaderMaterial.new()
## Contadores para los tests (nada se rehace en cada fotograma).
var uploads := 0
var mesh_builds := 0

var _image: Image
var _texture: ImageTexture
var _n := 0
var _version := -1
var _mesh_key := ""
var _threads_key := ""


func _init() -> void:
	material.shader = SHADER


## Mallas de toda la línea para una chapa: se rehacen solo si cambian la chapa, su espesor o la longitud de la línea (y
## los hilos, si cambia el surco del disco).
func build_meshes(walls: MeshInstance3D, burrs: MeshInstance3D, threads: MeshInstance3D, panel_id: String,
		plastic: bool, total_mm: float, line_mm: float, kerf_mm: float) -> void:
	var key := "%s|%s|%s" % [panel_id, total_mm, line_mm]
	if key != _mesh_key:
		_mesh_key = key
		walls.mesh = PB.build_manual_walls(line_mm)
		burrs.mesh = PB.build_manual_burrs(line_mm, plastic, "rebaba-manual:%s" % panel_id)
		for mi: MeshInstance3D in [walls, burrs]:
			mi.custom_aabb = mi.mesh.get_aabb().grow(0.02)  # el shader desplaza unos milímetros los vértices
		mesh_builds += 2
		_threads_key = ""
	var tkey := "%s|%s" % [key, kerf_mm]
	if tkey != _threads_key:
		_threads_key = tkey
		threads.mesh = PB.build_threads(maxf(kerf_mm, 0.5), 0.0, total_mm, line_mm, 1.0, "hilos-manual:%s" % panel_id) if plastic else null
		if plastic:
			mesh_builds += 1
	threads.visible = plastic


## Sube el mapa del surco si cambió de versión: n muestras, 2 filas × n × 4 floats (ver radial_manual.gd).
func upload(data: PackedFloat32Array, n: int, version: int) -> void:
	if version == _version and n == _n and _texture != null:
		return
	var bytes := data.to_byte_array()
	if _texture == null or n != _n:
		_image = Image.create_from_data(n, 2, false, Image.FORMAT_RGBAF, bytes)
		_texture = ImageTexture.create_from_image(_image)
		material.set_shader_parameter("cut_map", _texture)
		material.set_shader_parameter("n_samples", float(n))
	else:
		_image.set_data(n, 2, false, Image.FORMAT_RGBAF, bytes)
		_texture.update(_image)
	_n = n
	_version = version
	uploads += 1
