## Torno paralelo de taller, construido con mallas procedurales (shapes.gd): 360 mm de volteo sobre la bancada
## (180 mm de altura de puntos), plato de Ø200 y unos 800 mm entre puntos, sobre dos pies con la bandeja de
## virutas en medio. Proporciones de un torno de taller de FP (estimación, docs/taller/fuentes-u9.md).
##
## Marco de la escena: metros; +x hacia el contrapunto, +y arriba, +z hacia el operario. El eje del cabezal es
## la recta y = AXIS_Y, z = 0. Las piezas que se mueven quedan en nodos propios:
##   Spindle (gira alrededor de x) → Chuck (+ la pieza, que añade la escena)
##   Carriage (x de la punta)      → bancada del carro, delantal, volante → CrossSlide (z de la punta) →
##                                    charriot, torreta, herramienta (Tool, con la punta en su origen), tobera
extends RefCounted

const Shapes = preload("res://app/taller/lathe3d/shapes.gd")
const Chuck = preload("res://app/taller/lathe3d/chuck.gd")

const AXIS_Y := 1.10  ## altura del eje del cabezal sobre el suelo (m)
const BED_TOP := 0.92  ## cara superior de las guías del carro
const CHUCK_FACE_X := -0.165  ## cara delantera del cuerpo del plato
const JAW_FRONT_X := -0.135  ## cara delantera de las garras (el escalón que aprieta sobresale 30 mm)
const HEAD_FACE_X := -0.29  ## cara derecha del cabezal
const TRAY_Y := 0.525  ## fondo de la bandeja de virutas
const TOOLPOST_TOP := 0.03  ## altura de la cara de arriba de la torreta sobre el eje
const COMPOUND_TOP := 1.062
const CROSS_TOP := 1.025
const SADDLE_TOP := 0.975

var mats := {}
var spindle: Node3D
var chuck: Chuck
var carriage: Node3D
var cross_slide: Node3D
var tool: Node3D
var nozzle: Node3D
var lamp: SpotLight3D
var wheel_carriage: Node3D
var wheel_cross: Node3D
var _insert_mi: MeshInstance3D  # plaquita (prisma) y su cara superior: se rehacen con la herramienta montada
var _insert_top_mi: MeshInstance3D

var _root: Node3D


## Construye la máquina dentro de `parent`.
func build(parent: Node3D) -> void:
	_root = parent
	_make_materials()
	_floor()
	_base_and_bed()
	_headstock()
	_tailstock()
	_carriage()
	_guard_and_lamp()


func _make_materials() -> void:
	mats = {
		"paint": _mat(Color("#5d786e"), 0.0, 0.38),
		"paint_dark": _mat(Color("#2c3234"), 0.0, 0.5),
		"paint_light": _mat(Color("#7f8a84"), 0.0, 0.6),
		"steel": _mat(Color("#b9bcbe"), 1.0, 0.22),
		"steel_dark": _mat(Color("#74787b"), 1.0, 0.34),
		"chuck": _mat(Color("#6c7074"), 0.85, 0.5),
		"jaw": _mat(Color("#a4a8ab"), 1.0, 0.32),
		"black": _mat(Color("#0d0e0f"), 0.2, 0.55),
		"oxide": _mat(Color("#303236"), 0.75, 0.32),
		"chrome": _mat(Color("#dcdfe2"), 1.0, 0.08),
		"red": _mat(Color("#b8161c"), 0.0, 0.32),
		"yellow": _mat(Color("#e2b31a"), 0.0, 0.45),
		"green": _mat(Color("#1f9d3a"), 0.0, 0.35),
		"insert": _mat(Color("#d7a84c"), 1.0, 0.26),
		"insert_top": _mat(Color("#2b2c30"), 0.55, 0.32),
		"plate": _mat(Color("#cfccc1"), 0.2, 0.5),
		"floor": _mat(Color("#62625e"), 0.0, 0.9),
		"rubber": _mat(Color("#1d1e1f"), 0.0, 0.95),
		"tray": _mat(Color("#5a5f63"), 0.75, 0.48),
		"hose": _mat(Color("#1f63b4"), 0.0, 0.42),
		"lamp_glow": _mat(Color("#fff4dd"), 0.0, 0.3),
	}
	(mats["lamp_glow"] as StandardMaterial3D).emission_enabled = true
	(mats["lamp_glow"] as StandardMaterial3D).emission = Color("#fff1d6")
	(mats["lamp_glow"] as StandardMaterial3D).emission_energy_multiplier = 3.0


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.metallic_specular = 0.5
	return m


# ─── utilidades de colocación ────────────────────────────────────────────────────────────────────────────

func _mi(parent: Node3D, mesh: Mesh, mat_name: String, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mats[mat_name]
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


## Caja con cantos redondeados entre dos esquinas (en el marco de `parent`).
func _box(parent: Node3D, a: Vector3, b: Vector3, mat_name: String, r := 0.0) -> MeshInstance3D:
	var bx: Dictionary = Shapes.box_between(a, b, r, 2 if r > 0.0 else 0)
	return _mi(parent, bx["mesh"], mat_name, bx["center"])


## Cilindro de radio r entre dos puntos.
func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, mat_name: String, sides := 12) -> MeshInstance3D:
	var d := b - a
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = sides
	cm.rings = 1
	var basis := Basis(Quaternion(Vector3.UP, d.normalized())) if d.normalized().cross(Vector3.UP).length() > 1e-6 else (Basis.IDENTITY if d.y >= 0.0 else Basis(Vector3.RIGHT, PI))
	return _mi(parent, cm, mat_name, (a + b) * 0.5, basis)


func _ball(parent: Node3D, c: Vector3, r: float, mat_name: String) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = 2.0 * r
	sm.radial_segments = 16
	sm.rings = 8
	return _mi(parent, sm, mat_name, c)


## Volante con el eje a lo largo de `axis` (unitario), centrado en c. Devuelve el nodo que gira: su rotation.x
## es el giro del volante alrededor de su eje.
func _wheel(parent: Node3D, c: Vector3, axis: Vector3, radius: float, tube: float) -> Node3D:
	var hw: Dictionary = Shapes.handwheel(radius, tube)
	var node := Node3D.new()
	node.position = c
	node.basis = Basis(Quaternion(Vector3.RIGHT, axis.normalized())) if absf(axis.normalized().dot(Vector3.RIGHT)) < 0.999 else Basis.IDENTITY
	parent.add_child(node)
	var spin := Node3D.new()
	spin.name = "Spin"
	node.add_child(spin)
	_mi(spin, hw["rim"], "chrome", Vector3.ZERO, Basis(Vector3.BACK, PI * 0.5))
	_mi(spin, hw["hub"], "chrome")
	for k in 3:
		_mi(spin, hw["spoke"], "chrome", Vector3.ZERO, Basis(Vector3.RIGHT, TAU * float(k) / 3.0) * Basis(Vector3.BACK, PI * 0.5))
	# Maneta: sale de la llanta a lo largo del eje, hacia el operario
	_mi(spin, hw["handle"], "black", Vector3(0.0, radius * 0.92, 0.0))
	return spin


# ─── piezas ──────────────────────────────────────────────────────────────────────────────────────────────

func _floor() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(14.0, 14.0)
	_mi(_root, pm, "floor", Vector3(0.0, 0.0, 0.0))
	# Esterilla antifatiga del operario y líneas de seguridad amarillas alrededor de la máquina
	_box(_root, Vector3(-0.55, 0.0, 0.42), Vector3(0.85, 0.012, 1.02), "rubber", 0.004)
	var lo := Vector2(-1.2, -0.6)
	var hi := Vector2(1.4, 1.2)
	var w := 0.06
	_box(_root, Vector3(lo.x, 0.0, lo.y), Vector3(hi.x, 0.002, lo.y + w), "yellow")
	_box(_root, Vector3(lo.x, 0.0, hi.y - w), Vector3(hi.x, 0.002, hi.y), "yellow")
	_box(_root, Vector3(lo.x, 0.0, lo.y), Vector3(lo.x + w, 0.002, hi.y), "yellow")
	_box(_root, Vector3(hi.x - w, 0.0, lo.y), Vector3(hi.x, 0.002, hi.y), "yellow")


func _base_and_bed() -> void:
	# Pies (el izquierdo lleva el motor; puerta con tirador) y zócalo
	for side in [[-0.86, -0.40], [0.62, 1.02]]:
		_box(_root, Vector3(side[0], 0.06, -0.24), Vector3(side[1], 0.64, 0.22), "paint", 0.012)
		_box(_root, Vector3(side[0] - 0.01, 0.0, -0.25), Vector3(side[1] + 0.01, 0.06, 0.23), "paint_dark", 0.004)
		_box(_root, Vector3(side[0] + 0.035, 0.11, 0.219), Vector3(side[1] - 0.035, 0.58, 0.226), "paint", 0.004)
		_box(_root, Vector3(side[1] - 0.07, 0.33, 0.226), Vector3(side[1] - 0.055, 0.42, 0.236), "chrome", 0.003)
	# Bandeja de virutas entre los pies
	_box(_root, Vector3(-0.40, TRAY_Y - 0.01, -0.26), Vector3(0.62, TRAY_Y, 0.36), "tray")
	_box(_root, Vector3(-0.40, TRAY_Y - 0.01, 0.35), Vector3(0.62, TRAY_Y + 0.07, 0.362), "tray", 0.002)
	_box(_root, Vector3(-0.40, TRAY_Y - 0.01, -0.262), Vector3(0.62, 0.64, -0.25), "tray")
	# Bancada: cuerpo pintado y guías rectificadas (prismática delante, plana detrás; y las del contrapunto)
	_box(_root, Vector3(-0.86, 0.64, -0.19), Vector3(1.02, 0.90, 0.19), "paint", 0.01)
	_mi(_root, Shapes.extrude_x(PackedVector2Array([Vector2(0.135, 0.90), Vector2(0.175, 0.90), Vector2(0.175, 0.906), Vector2(0.155, BED_TOP), Vector2(0.135, 0.906)]), -0.86, 1.02), "steel")
	_box(_root, Vector3(-0.86, 0.90, -0.175), Vector3(1.02, BED_TOP, -0.135), "steel")
	_box(_root, Vector3(-0.29, 0.90, 0.07), Vector3(1.02, 0.915, 0.10), "steel")
	_mi(_root, Shapes.extrude_x(PackedVector2Array([Vector2(-0.105, 0.90), Vector2(-0.075, 0.90), Vector2(-0.075, 0.905), Vector2(-0.09, 0.917), Vector2(-0.105, 0.905)]), -0.29, 1.02), "steel")
	# Cremallera, husillo de roscar (trapecial, paso 6 mm) y barra de cilindrar, con el soporte del extremo
	_box(_root, Vector3(-0.29, 0.862, 0.19), Vector3(1.0, 0.884, 0.197), "steel_dark")
	var thread := PackedVector2Array([Vector2(-0.29, 0.0), Vector2(-0.29, 0.0125)])
	var x := -0.29
	while x < 0.975:
		thread.append(Vector2(x + 0.0012, 0.016))
		thread.append(Vector2(x + 0.0030, 0.016))
		thread.append(Vector2(x + 0.0042, 0.0125))
		thread.append(Vector2(x + 0.006, 0.0125))
		x += 0.006
	thread.append(Vector2(x, 0.0))
	_mi(_root, Shapes.revolve(thread, 14), "steel", Vector3(0.0, 0.80, 0.222))
	_mi(_root, Shapes.x_cylinder(-0.29, 0.98, 0.0125, 16), "steel", Vector3(0.0, 0.745, 0.222))
	_box(_root, Vector3(0.975, 0.70, 0.19), Vector3(1.02, 0.85, 0.25), "paint", 0.006)


func _headstock() -> void:
	# Cabezal y caja de avances (Norton) debajo, delante de la bancada
	_box(_root, Vector3(-0.84, BED_TOP - 0.02, -0.23), Vector3(HEAD_FACE_X, 1.37, 0.205), "paint", 0.025)
	_box(_root, Vector3(-0.86, 0.66, 0.19), Vector3(-0.38, 0.89, 0.27), "paint", 0.015)
	_box(_root, Vector3(-0.80, 1.05, 0.204), Vector3(-0.52, 1.14, 0.209), "plate", 0.002)  # tabla de velocidades
	for i in 5:  # rayas de la tabla
		_box(_root, Vector3(-0.79, 1.062 + 0.016 * float(i), 0.2092), Vector3(-0.53, 1.064 + 0.016 * float(i), 0.2096), "paint_dark")
	# Palancas de velocidades (varilla cromada y bola roja) y selectores de la caja de avances
	for lx in [-0.74, -0.62]:
		_rod(_root, Vector3(lx, 1.24, 0.205), Vector3(lx + 0.02, 1.27, 0.29), 0.0065, "chrome")
		_ball(_root, Vector3(lx + 0.02, 1.27, 0.29), 0.016, "red")
	for lx in [-0.78, -0.66, -0.54, -0.46]:
		_rod(_root, Vector3(lx, 0.78, 0.27), Vector3(lx, 0.78, 0.31), 0.012, "black")
	# Botonera: seta de emergencia (roja sobre amarillo), marcha y paro
	_box(_root, Vector3(-0.45, 1.02, 0.205), Vector3(-0.33, 1.30, 0.225), "paint_dark", 0.006)
	_rod(_root, Vector3(-0.39, 1.25, 0.225), Vector3(-0.39, 1.25, 0.232), 0.03, "yellow", 24)
	_rod(_root, Vector3(-0.39, 1.25, 0.232), Vector3(-0.39, 1.25, 0.25), 0.012, "red", 16)
	_rod(_root, Vector3(-0.39, 1.25, 0.25), Vector3(-0.39, 1.25, 0.262), 0.022, "red", 24)
	_rod(_root, Vector3(-0.415, 1.12, 0.225), Vector3(-0.415, 1.12, 0.236), 0.011, "green", 16)
	_rod(_root, Vector3(-0.365, 1.12, 0.225), Vector3(-0.365, 1.12, 0.236), 0.011, "black", 16)
	# Resalte del husillo en la cara del cabezal
	_mi(_root, Shapes.x_cylinder(HEAD_FACE_X - 0.002, CHUCK_FACE_X - 0.1, 0.098, 48), "paint", Vector3(0.0, AXIS_Y, 0.0))
	# Husillo que gira, con el plato
	spindle = Node3D.new()
	spindle.name = "Spindle"
	spindle.position = Vector3(CHUCK_FACE_X, AXIS_Y, 0.0)
	_root.add_child(spindle)
	chuck = Chuck.new()
	spindle.add_child(chuck)
	chuck.build(mats)


func _tailstock() -> void:
	var node := Node3D.new()
	node.name = "Tailstock"
	_root.add_child(node)
	_box(node, Vector3(0.52, BED_TOP, -0.17), Vector3(0.80, 0.975, 0.17), "paint", 0.006)
	_box(node, Vector3(0.54, 0.975, -0.10), Vector3(0.80, AXIS_Y + 0.01, 0.10), "paint", 0.02)
	_mi(node, Shapes.x_cylinder(0.50, 0.80, 0.05, 40), "paint", Vector3(0.0, AXIS_Y, 0.0))
	_mi(node, Shapes.x_cylinder(0.44, 0.502, 0.026, 32), "steel", Vector3(0.0, AXIS_Y, 0.0))
	_mi(node, Shapes.x_cylinder(0.405, 0.44, 0.03, 32), "steel_dark", Vector3(0.0, AXIS_Y, 0.0))
	_mi(node, Shapes.revolve(PackedVector2Array([Vector2(0.38, 0.0), Vector2(0.405, 0.0145), Vector2(0.405, 0.0)]), 32), "steel", Vector3(0.0, AXIS_Y, 0.0))
	_wheel(node, Vector3(0.83, AXIS_Y, 0.0), Vector3.RIGHT, 0.075, 0.008)
	_rod(node, Vector3(0.58, AXIS_Y + 0.05, 0.0), Vector3(0.62, AXIS_Y + 0.10, 0.07), 0.006, "chrome")
	_ball(node, Vector3(0.62, AXIS_Y + 0.10, 0.07), 0.013, "black")


func _carriage() -> void:
	carriage = Node3D.new()
	carriage.name = "Carriage"
	_root.add_child(carriage)
	# Bancada del carro sobre las guías, cola de milano del transversal y delantal con sus mandos
	_box(carriage, Vector3(-0.03, BED_TOP, -0.21), Vector3(0.31, SADDLE_TOP, 0.205), "paint", 0.008)
	_box(carriage, Vector3(0.0, SADDLE_TOP, -0.21), Vector3(0.18, 0.985, 0.205), "steel_dark")
	_box(carriage, Vector3(-0.03, 0.60, 0.205), Vector3(0.31, SADDLE_TOP - 0.003, 0.30), "paint", 0.015)
	wheel_carriage = _wheel(carriage, Vector3(0.04, 0.78, 0.315), Vector3.BACK, 0.085, 0.0085)
	_rod(carriage, Vector3(0.25, 0.74, 0.30), Vector3(0.27, 0.70, 0.36), 0.006, "chrome")
	_ball(carriage, Vector3(0.27, 0.70, 0.36), 0.013, "black")
	_rod(carriage, Vector3(0.21, 0.89, 0.30), Vector3(0.21, 0.89, 0.33), 0.014, "black", 16)
	# Carro transversal (se mueve con el radio de la punta)
	cross_slide = Node3D.new()
	cross_slide.name = "CrossSlide"
	carriage.add_child(cross_slide)
	_box(cross_slide, Vector3(0.0, 0.985, -0.08), Vector3(0.18, CROSS_TOP, 0.32), "paint", 0.004)
	_box(cross_slide, Vector3(0.07, 0.99, 0.32), Vector3(0.11, 1.02, 0.34), "paint", 0.003)
	wheel_cross = _wheel(cross_slide, Vector3(0.09, 1.005, 0.36), Vector3.BACK, 0.055, 0.007)
	_mi(cross_slide, Shapes.revolve(PackedVector2Array([Vector2(-0.012, 0.0), Vector2(-0.012, 0.024), Vector2(0.004, 0.024), Vector2(0.004, 0.0)]), 32), "chrome", Vector3(0.09, 1.005, 0.345), Basis(Vector3.UP, -PI * 0.5))
	# Charriot (carro superior) sobre su base giratoria, con su manivela
	var base := CylinderMesh.new()
	base.top_radius = 0.07
	base.bottom_radius = 0.07
	base.height = 0.012
	base.radial_segments = 40
	_mi(cross_slide, base, "steel_dark", Vector3(0.06, CROSS_TOP + 0.006, 0.10))
	_box(cross_slide, Vector3(0.0, CROSS_TOP + 0.012, 0.02), Vector3(0.12, COMPOUND_TOP, 0.24), "paint", 0.003)
	_wheel(cross_slide, Vector3(0.06, 1.05, 0.265), Vector3.BACK, 0.032, 0.005)
	# Torreta portaherramientas cuadrangular de 85 mm (pavonada), con la ranura de la herramienta a la izquierda
	var ty := AXIS_Y
	_box(cross_slide, Vector3(0.0, COMPOUND_TOP, 0.035), Vector3(0.085, ty - 0.025, 0.12), "oxide", 0.001)
	_box(cross_slide, Vector3(0.022, ty - 0.025, 0.035), Vector3(0.085, ty - 0.005, 0.12), "oxide", 0.001)
	_box(cross_slide, Vector3(0.0, ty - 0.005, 0.035), Vector3(0.085, ty + TOOLPOST_TOP, 0.12), "oxide", 0.002)
	for bz in [0.05, 0.0775, 0.105]:
		_rod(cross_slide, Vector3(0.011, ty + TOOLPOST_TOP, bz), Vector3(0.011, ty + TOOLPOST_TOP + 0.01, bz), 0.0068, "oxide", 12)
		_box(cross_slide, Vector3(0.0085, ty + TOOLPOST_TOP + 0.0095, bz - 0.0025), Vector3(0.0135, ty + TOOLPOST_TOP + 0.0105, bz + 0.0025), "black")
	_rod(cross_slide, Vector3(0.052, ty + TOOLPOST_TOP, 0.0775), Vector3(0.052, ty + TOOLPOST_TOP + 0.03, 0.0775), 0.0095, "oxide", 16)
	# Palanca de apriete hacia atrás y a la derecha: no se mete delante de la cámara
	_rod(cross_slide, Vector3(0.052, ty + TOOLPOST_TOP + 0.026, 0.0775), Vector3(0.125, ty + TOOLPOST_TOP + 0.03, 0.035), 0.0042, "chrome")
	_ball(cross_slide, Vector3(0.125, ty + TOOLPOST_TOP + 0.03, 0.035), 0.0075, "red")
	# Herramienta: portaherramientas PCLNR 2020 y plaquita CNMG 120408 (80°, rε = 0,8 mm), κr = 95°
	tool = Node3D.new()
	tool.name = "Tool"
	tool.position = Vector3(0.0, AXIS_Y, 0.0)
	cross_slide.add_child(tool)
	_box(tool, Vector3(0.001, -0.025, 0.02), Vector3(0.021, -0.005, 0.130), "oxide", 0.001)
	_box(tool, Vector3(0.0, -0.025, 0.003), Vector3(0.021, -0.0049, 0.022), "oxide", 0.0008)
	var poly := insert_polygon()
	_insert_mi = _mi(tool, Shapes.prism(poly, 0.00476), "insert", Vector3(0.0, -0.00476, 0.0))
	_insert_top_mi = _mi(tool, Shapes.prism(_inner(poly), 0.00012), "insert_top", Vector3(0.0, 0.0, 0.0))
	_box(tool, Vector3(0.005, 0.0, 0.009), Vector3(0.017, 0.0042, 0.023), "oxide", 0.0008)
	_rod(tool, Vector3(0.011, 0.0042, 0.018), Vector3(0.011, 0.0068, 0.018), 0.0035, "steel_dark", 12)
	# Manguera articulada del refrigerante (eslabones azules) desde la parte de atrás del carro, para no tapar la
	# pieza desde el puesto del operario; la tobera apunta a la punta en cada fotograma (aim_nozzle)
	var p0 := Vector3(0.10, SADDLE_TOP, -0.19)
	var p1 := Vector3(0.05, 1.215, -0.16)
	var p2 := Vector3(0.024, 1.158, -0.042)
	var prev := p0
	var n := 22
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var q := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		_ball(carriage, q, 0.0052, "hose")
		_rod(carriage, prev, q, 0.0036, "hose", 10)
		prev = q
	nozzle = Node3D.new()
	nozzle.name = "Nozzle"
	carriage.add_child(nozzle)
	nozzle.position = p2
	_mi(nozzle, Shapes.revolve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.0055), Vector2(0.02, 0.0032), Vector2(0.02, 0.0)]), 16), "hose", Vector3.ZERO, Basis(Vector3.UP, PI * 0.5))
	aim_nozzle(Vector3(0.0, AXIS_Y, 0.02))


## Cara superior de la plaquita: el contorno encogido un 6 % hacia su centro.
static func _inner(poly: PackedVector2Array) -> PackedVector2Array:
	var inner := PackedVector2Array()
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(poly.size())
	for p in poly:
		inner.append(cen + (p - cen) * 0.94)
	return inner


## Monta la plaquita de una herramienta del catálogo (lathe_tools.gd): su contorno con el arco de la punta. Así se ve
## la V de la de roscar o la rómbica de 35° de la de acabado. {} vuelve a la plaquita por defecto.
func set_insert(t: Dictionary) -> void:
	if _insert_mi == null:
		return
	var poly := insert_polygon_from(t)
	var thick := float(t.get("s_mm", 4.76)) * 0.001
	_insert_mi.mesh = Shapes.prism(poly, thick)
	_insert_mi.position = Vector3(0.0, -thick, 0.0)
	_insert_top_mi.mesh = Shapes.prism(_inner(poly), 0.00012)


## Contorno de la plaquita de una herramienta del catálogo en metros (x = z del torno, y = radio, punta teórica en el
## origen): el insert_poly de lathe_tools.gd (mm respecto a la punta teórica) con el arco de la punta entre los dos
## puntos tangentes al círculo de centro «center» y radio rε. Sin polígono (plaquita redonda o {}), la de por defecto.
static func insert_polygon_from(t: Dictionary) -> PackedVector2Array:
	var flat: PackedFloat64Array = t.get("insert_poly", PackedFloat64Array())
	if flat.size() < 6:
		return insert_polygon()
	var re := float(t.get("re_mm", 0.8))
	var c: Array = t.get("center", [re, re])
	var cen := Vector2(float(c[0]), float(c[1]))
	var n := flat.size() / 2
	var out := PackedVector2Array()
	for i in n:
		var a := Vector2(flat[2 * i], flat[2 * i + 1])
		var j := (i + 1) % n
		var b := Vector2(flat[2 * j], flat[2 * j + 1])
		out.append(a * 0.001)
		# la cuerda entre los dos puntos de tangencia es el arco de la punta (antihorario, como el contorno)
		if absf(a.distance_to(cen) - re) < 1e-4 and absf(b.distance_to(cen) - re) < 1e-4:
			var a0 := (a - cen).angle()
			var a1 := (b - cen).angle()
			while a1 <= a0:
				a1 += TAU
			for k in range(1, 8):
				var ang := lerpf(a0, a1, float(k) / 8.0)
				out.append((cen + Vector2(cos(ang), sin(ang)) * re) * 0.001)
	return out


## Orienta la tobera hacia un punto (en el marco del carro).
func aim_nozzle(target_local: Vector3) -> void:
	var d := target_local - nozzle.position
	if d.length_squared() > 1e-10:
		nozzle.basis = Basis.looking_at(d, Vector3.UP)


## Contorno de la plaquita (80°, rε = 0,8 mm) en el plano horizontal (x = z del torno, z = radio), con la punta
## teórica en el origen: el arco de punta es tangente a x = 0 y a z = 0 (CONTRATOS.md: centro en (rε, rε)).
static func insert_polygon() -> PackedVector2Array:
	var re := 0.0008
	var side := 0.0129
	var e_main := Vector2(cos(deg_to_rad(85.0)), sin(deg_to_rad(85.0)))  # filo principal (κr = 95°)
	var e_sec := Vector2(cos(deg_to_rad(5.0)), sin(deg_to_rad(5.0)))  # filo secundario (5° de despulla)
	var c := Vector2(re, re)
	var corner := c - (e_main + e_sec).normalized() * (re / sin(deg_to_rad(40.0)))
	var poly := PackedVector2Array()
	# Arco de punta: de la tangencia con el filo secundario (normal hacia fuera a −85°) a la del principal (a
	# −185°), pasando por la punta (−135°), en 8 tramos
	var a0 := e_sec.orthogonal().angle()
	var a1 := (-e_main.orthogonal()).angle()
	if a1 > a0:
		a1 -= TAU
	for k in 9:
		var ang := lerpf(a0, a1, float(k) / 8.0)
		poly.append(c + Vector2(cos(ang), sin(ang)) * re)
	poly.reverse()
	var b := corner + e_sec * side
	var a := corner + e_main * side
	var out := PackedVector2Array([b, corner + e_sec * side + e_main * side, a])
	out.append_array(poly)
	return out


func _guard_and_lamp() -> void:
	# Protección trasera de chapa (salpicaduras y virutas)
	_box(_root, Vector3(HEAD_FACE_X, BED_TOP - 0.02, -0.246), Vector3(1.0, 1.42, -0.239), "paint_light")
	_box(_root, Vector3(HEAD_FACE_X, 1.42, -0.246), Vector3(1.0, 1.426, -0.215), "paint_light")
	# Lámpara de máquina articulada sobre el cabezal
	var base := Vector3(-0.36, 1.37, -0.17)
	var j1 := Vector3(-0.31, 1.58, -0.12)
	var head := Vector3(-0.19, 1.50, -0.03)
	var target := Vector3(-0.085, AXIS_Y, 0.02)
	_rod(_root, base, base + Vector3(0.0, 0.02, 0.0), 0.03, "paint_dark", 20)
	_rod(_root, base, j1, 0.008, "steel_dark")
	_ball(_root, j1, 0.013, "paint_dark")
	_rod(_root, j1, head, 0.008, "steel_dark")
	var lamp_node := Node3D.new()
	lamp_node.position = head
	lamp_node.basis = Basis.looking_at(target - head, Vector3.UP)
	_root.add_child(lamp_node)
	# Pantalla cónica abierta (se ve por dentro y por fuera) y el disco luminoso al fondo
	var shade_mat := (mats["paint_dark"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["shade"] = shade_mat
	var shade := Shapes.revolve(PackedVector2Array([Vector2(-0.035, 0.0), Vector2(-0.035, 0.02), Vector2(0.0, 0.024), Vector2(0.03, 0.043)]), 28)
	_mi(lamp_node, shade, "shade", Vector3.ZERO, Basis(Vector3.UP, PI * 0.5))
	var glow := CylinderMesh.new()
	glow.top_radius = 0.022
	glow.bottom_radius = 0.022
	glow.height = 0.002
	_mi(lamp_node, glow, "lamp_glow", Vector3(0.0, 0.0, -0.002), Basis(Vector3.RIGHT, PI * 0.5))
	lamp = SpotLight3D.new()
	lamp.name = "WorkLamp"
	lamp.position = Vector3(0.0, 0.0, -0.01)
	lamp.light_color = Color(1.0, 0.93, 0.82)
	lamp.light_energy = 1.1
	lamp.spot_range = 0.9
	lamp.spot_angle = 34.0
	lamp.spot_angle_attenuation = 0.8
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.02
	lamp_node.add_child(lamp)
