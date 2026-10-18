## Afiladora 3D · piezas comunes de dibujo: materiales, cajas redondeadas, varillas, sólidos de revolución y la
## lectura de los diccionarios de vista (medidas de las muelas, grano). Todo en metros; los diccionarios de vista
## llegan en mm (CONTRATOS.md → «Vista 3D de la afiladora») y aquí se pasan a metros.
## Solo dibujo: no calcula física. Las mallas base son las de lathe3d/shapes.gd (cajas con cantos redondeados y
## sólidos de revolución alrededor de X), que se reutilizan sin tocarlas.
extends RefCounted

const Shapes = preload("res://app/taller/lathe3d/shapes.gd")
const WHEEL_SHADER = preload("res://app/taller/sharpen3d/wheel.gdshader")

## Anchura de dibujo cuando la vista trae width_mm = null (el fabricante no la da): la de una muela típica de cada
## posición. ESTIMACIÓN de dibujo, no un dato: esmeriladora de 150 mm, 16–20 mm; piedra húmeda, 40–50 mm; rueda
## de cuero, 30 mm; cuerpo de un disco de láminas de 125 mm, 12 mm; muela de las afiladoras compactas, 10 mm.
const DEFAULT_WIDTH_MM := { "izquierda": 16.0, "derecha": 16.0, "piedra": 40.0, "cuero": 30.0, "disco": 12.0 }
const DEFAULT_DIAMETER_MM := { "izquierda": 150.0, "derecha": 150.0, "piedra": 200.0, "cuero": 180.0, "disco": 125.0 }

## Color de dibujo de cada abrasivo (orientativo, como sharpen_view.gd): corindón gris pardo (grueso) o claro
## (fino), SiC verde, CBN ámbar oscuro, diamante gris oscuro; «» (sin dato), gris neutro.
const ABRASIVE_LOOK := {
	"al2o3": ["#8E857C", "#5E5751"], "al2o3_fino": ["#BDB7AE", "#8C867E"], "sic": ["#5E8C74", "#3A5A49"],
	"cbn": ["#8A5E2E", "#4A3220"], "diamante": ["#4E5359", "#2B2E33"], "": ["#9A958E", "#66625D"],
	"cuero": ["#8A5A36", "#5C3920"], "piedra": ["#8E8A82", "#5E5A54"],
}


static func mat(color: Color, metallic := 0.0, roughness := 0.5, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.metallic_specular = 0.5
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Material transparente (pantallas de policarbonato, ventanas, agua sin shader).
static func glass(color: Color, alpha: float, roughness := 0.08) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = roughness
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func node(parent: Node, node_name: String, xf := Transform3D.IDENTITY) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.transform = xf
	parent.add_child(n)
	return n


static func mesh_node(parent: Node, mesh: Mesh, material: Material, xf := Transform3D.IDENTITY, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xf
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


## Caja con cantos redondeados entre dos esquinas (en el marco del padre).
static func box(parent: Node, a: Vector3, b: Vector3, material: Material, r := 0.0, node_name := "") -> MeshInstance3D:
	var bx: Dictionary = Shapes.box_between(a, b, r, 2 if r > 0.0 else 0)
	return mesh_node(parent, bx["mesh"], material, Transform3D(Basis.IDENTITY, bx["center"]), node_name)


## Base cuyo eje Y apunta en `dir` (para una varilla o un cilindro de Godot, que van a lo largo de Y).
static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var z := ref.cross(y).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


## Base cuyo eje X apunta en `dir` (sólidos de revolución de shapes.gd, que van a lo largo de X).
static func basis_x(dir: Vector3) -> Basis:
	var x := dir.normalized()
	var ref := Vector3.UP if absf(x.y) < 0.9 else Vector3.BACK
	var z := x.cross(ref).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


## Varilla (cilindro) de radio r entre dos puntos.
static func rod(parent: Node, a: Vector3, b: Vector3, r: float, material: Material, sides := 16, node_name := "") -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = maxf((b - a).length(), 1e-6)
	cm.radial_segments = sides
	cm.rings = 1
	return mesh_node(parent, cm, material, Transform3D(basis_y(b - a), (a + b) * 0.5), node_name)


## Cilindro de longitud unidad a lo largo de Y (de y = 0 a y = 1) para estirarlo con la escala en cada fotograma:
## las patas de la barra del soporte universal cambian de largo sin rehacer la malla.
static func unit_rod_mesh(r: float, sides := 16) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = sides
	cm.rings = 1
	return cm


## Sólido de revolución alrededor del eje X local: perfil (x, radio) en metros (shapes.gd). arc < TAU: revolución
## parcial que empieza en +Y y avanza hacia +Z; para que empiece en otro ángulo, se gira el nodo alrededor de X.
static func revolve(profile: PackedVector2Array, sides := 48, smooth := false, arc := TAU) -> ArrayMesh:
	return Shapes.revolve(profile, sides, smooth, arc)


## Cilindro a lo largo de X local (de x0 a x1) con radio r.
static func x_cylinder(x0: float, x1: float, r: float, sides := 32) -> ArrayMesh:
	return Shapes.x_cylinder(x0, x1, r, sides)


## Número de la vista, o el valor por defecto si falta, es null o no es un número.
static func num(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key)
	if v == null or not (v is float or v is int):
		return fallback
	return float(v)


## Número del grano de un texto de la vista («K36», «P60», «220–1000», «pasta de asentar» → 36, 60, 220, 0).
static func grit_number(grit: Variant) -> float:
	if grit is float or grit is int:
		return float(grit)
	var s := str(grit)
	var digits := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return digits.to_float() if digits != "" else 0.0


## Tamaño aparente del grano (mm) para el dibujo de la muela: grano FEPA F ≈ 15,2/n mm (F36 ≈ 0,42 mm; F60 ≈ 0,25;
## F220 ≈ 0,07). Aproximación de dibujo; las equivalencias medidas están en abrasives.gd (GRIT_SYSTEMS).
static func grit_mm(grit: Variant) -> float:
	var n := grit_number(grit)
	return 15.2 / n if n > 0.0 else 0.3


## Colores [claro, oscuro] de dibujo de una muela de la vista.
static func wheel_colors(w: Dictionary) -> Array:
	var pos := str(w.get("position", ""))
	if bool(w.get("honing", false)) or pos == "cuero":
		return [Color(ABRASIVE_LOOK["cuero"][0]), Color(ABRASIVE_LOOK["cuero"][1])]
	var ab := str(w.get("abrasive_id", ""))
	if ab == "al2o3" and grit_number(w.get("grit", "")) >= 60.0:
		ab = "al2o3_fino"
	if ab == "" and pos == "piedra":
		ab = "piedra"
	var look: Array = ABRASIVE_LOOK.get(ab, ABRASIVE_LOOK[""])
	return [Color(look[0]), Color(look[1])]


## Material de una muela (wheel.gdshader). kind: 0 muela vitrificada · 1 piedra húmeda · 2 cuero · 3 muela de
## copa con capa de CBN o diamante sobre cuerpo de metal.
static func wheel_material(w: Dictionary, kind: int, radius_m: float, width_m: float, bore_m: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WHEEL_SHADER
	var cols := wheel_colors(w)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("grain_color", cols[0])
	m.set_shader_parameter("grain_dark", cols[1])
	m.set_shader_parameter("grit_mm", grit_mm(w.get("grit", "")))
	m.set_shader_parameter("radius_mm", radius_m * 1000.0)
	m.set_shader_parameter("half_width_mm", width_m * 500.0)
	m.set_shader_parameter("bore_mm", bore_m * 1000.0)
	m.set_shader_parameter("label_mm", radius_m * 1000.0 * 0.45 if kind == 0 else 0.0)
	m.set_shader_parameter("wet", 1.0 if bool(w.get("wet", false)) else 0.0)
	return m
