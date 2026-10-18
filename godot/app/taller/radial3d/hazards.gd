## Marcas del escenario de las chispas en la escena de la radial (modo manual): un EJEMPLO de dibujo, no un coche
## concreto, con las mismas posiciones que usan los avisos de core/taller/radial_manual.gd:
##   - en las piezas de rescate, el generador de gas del airbag de cortina, más allá del extremo de la pieza (el pilar B
##     sube hasta el techo);
##   - bajo la chapa, un charco de combustible derramado: las chispas que salen por debajo de la chapa van hacia él.
## La hoja de rescate ISO 17840 de cada modelo dice dónde está cada cosa. Se rehacen solo al cambiar de chapa.
extends RefCounted

const PB = preload("res://app/taller/radial3d/panel_builder.gd")
const RadialManual = preload("res://core/taller/radial_manual.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## Profundidad (m) del charco bajo la cara pintada (dibujo).
const FUEL_BELOW_M := 0.16


## Quita las marcas que haya bajo parent y pone las de esta chapa.
static func build(parent: Node3D, rescue: bool, line_mm: float) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()
	var mid := PB.surface(line_mm * 0.5, 0.0)
	var fuel := MeshInstance3D.new()
	fuel.name = "Combustible"
	var puddle := CylinderMesh.new()
	puddle.top_radius = 0.11
	puddle.bottom_radius = 0.12
	puddle.height = 0.002
	fuel.mesh = puddle
	fuel.material_override = _mat(Color(0.95, 0.55, 0.12, 0.35), true)
	fuel.position = mid + Vector3(0.0, -FUEL_BELOW_M, 0.0)
	fuel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fuel)
	_label(parent, "Combustible derramado (ejemplo)", fuel.position + Vector3(0.0, 0.012, 0.075), Color(1.0, 0.7, 0.35))
	if not rescue:
		return
	var h: Dictionary = RadialManual.HAZARD_AIRBAG
	var u := float(h["u_mm"])
	var at := PB.surface(minf(u, PB.U_MAX), 0.0) + Vector3((u - minf(u, PB.U_MAX)) / 1000.0, 0.0, 0.0) \
		+ PB.normal(PB.U_MAX, 0.0) * (float(h["n_mm"]) / 1000.0) + Vector3(0.0, 0.0, float(h["l_mm"]) / 1000.0)
	var gen := MeshInstance3D.new()
	gen.name = "GeneradorAirbag"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.011  # grosor de dibujo
	cyl.bottom_radius = 0.011
	cyl.height = 2.0 * float(h["r_mm"]) / 1000.0  # el largo de la zona de los avisos (radial_manual.gd)
	gen.mesh = cyl
	gen.material_override = _mat(Color(0.86, 0.22, 0.2), false)
	gen.position = at
	gen.rotation = Vector3(PI / 2.0, 0.0, 0.0)  # tumbado a lo largo del larguero del techo
	parent.add_child(gen)
	_label(parent, "Generador de gas del airbag (ejemplo; ver la hoja ISO 17840)", at + Vector3(0.0, 0.03, 0.0), Color(1.0, 0.55, 0.5))


static func _mat(c: Color, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _label(parent: Node3D, text: String, pos: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 40
	l.pixel_size = 0.00018
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.09, 0.05, 0.11, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
