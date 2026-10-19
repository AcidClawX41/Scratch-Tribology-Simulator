## Cetrería 3D · el contorno del guiado (unidad 5y): lo que hay que coger o tocar se rodea de un contorno que late, la
## herramienta de la bandeja o la garra. Es una capa encima del material de cada malla (material_overlay, un casco un poco más
## grande con las caras de delante quitadas: se ve solo el borde), con su propio material, así que no toca los materiales de
## la escena ni crea nada en cada fotograma: late cambiando el alfa de dos materiales.
## Uso (lo lleva care_3d.gd): var g := CareGuide3D.new(); g.outline(mallas, "metros" | "mm"); g.advance(t); g.clear().
extends RefCounted

const Palette = preload("res://app/theme/palette.gd")

## El grosor del contorno (dibujo): en las herramientas, en metros; en la garra, en mm (su nodo va en mm).
const GROW_M := 0.0016
const GROW_MM := 0.35
## El latido (dibujo): veces por segundo (en radianes) y el alfa de abajo y de arriba.
const PULSE := 5.0
const ALPHA_LO := 0.3
const ALPHA_HI := 0.85

var _mat_m: StandardMaterial3D
var _mat_mm: StandardMaterial3D
var _meshes: Array = []
var _saved := {}


func _init() -> void:
	_mat_m = _make(GROW_M)
	_mat_mm = _make(GROW_MM)


static func _make(grow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = grow
	m.albedo_color = Color(Palette.color("gold"), ALPHA_HI)
	m.render_priority = Material.RENDER_PRIORITY_MAX
	return m


## Rodea estas mallas (y quita el contorno de las de antes). units: «metros» (las herramientas) o «mm» (la garra).
func outline(meshes: Array, units: String = "metros", tone: String = "gold") -> void:
	clear()
	var mat := _mat_mm if units == "mm" else _mat_m
	var c := Palette.color(tone)
	_mat_m.albedo_color = Color(c, _mat_m.albedo_color.a)
	_mat_mm.albedo_color = Color(c, _mat_mm.albedo_color.a)
	for mi: Variant in meshes:
		if not (mi is MeshInstance3D) or not is_instance_valid(mi):
			continue
		var m := mi as MeshInstance3D
		_saved[m] = m.material_overlay
		m.material_overlay = mat
		_meshes.append(m)


## Quita el contorno (cada malla vuelve a la capa que tenía).
func clear() -> void:
	for m: MeshInstance3D in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _saved.get(m)
	_meshes = []
	_saved = {}


## Cuántas mallas llevan el contorno (para los tests).
func count() -> int:
	return _meshes.size()


## El latido (t: el tiempo de la escena).
func advance(t: float) -> void:
	if _meshes.is_empty():
		return
	var a := ALPHA_LO + (ALPHA_HI - ALPHA_LO) * (0.5 + 0.5 * sin(t * PULSE))
	_mat_m.albedo_color.a = a
	_mat_mm.albedo_color.a = a
