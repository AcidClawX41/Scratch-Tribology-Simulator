## Plato universal de 3 garras (Ø200) con garras escalonadas duras y efecto estroboscópico controlado.
##
## Marco local: X a lo largo del eje del cabezal, origen en la cara delantera del cuerpo del plato. El nodo padre
## (el husillo) gira; aquí solo se construye la geometría, se colocan las garras en el radio de amarre y se
## gestiona el desenfoque de movimiento.
##
## Efecto estroboscópico controlado: a 1200 rpm y 30 fotogramas/s el plato da 2/3 de vuelta por fotograma y,
## con 3 garras, un giro de 120° por fotograma parece quieto o marcha atrás (efecto carro de diligencia). En vez
## de ese aliasing al azar, la escena limita la velocidad aparente de las garras a una deriva lenta en el sentido
## real y aquí se dibujan copias translúcidas repartidas en el arco que barrerían durante la exposición: a rpm
## altas las garras se ven como un anillo borroso, que es lo que ve el ojo.
extends Node3D

const Shapes = preload("res://app/taller/lathe3d/shapes.gd")

const BODY_R := 0.100
const BODY_DEPTH := 0.090
const JAW_WIDTH := 0.024
const GHOSTS := 16

var grip_radius := 0.025  ## radio al que aprietan las garras (m)
var blur := 0.0

var _jaws: Array[Node3D] = []  # pivotes a 0°, 120° y 240°
var _ghost_root: Node3D
var _ghosts: Array[MeshInstance3D] = []
var _jaw_meshes: Array[MeshInstance3D] = []


## Construye el plato. mats: diccionario de materiales de machine.gd.
func build(mats: Dictionary) -> void:
	name = "Chuck"
	# Cuerpo con chaflanes y el agujero pasante
	var prof := PackedVector2Array([
		Vector2(-BODY_DEPTH, 0.0), Vector2(-BODY_DEPTH, 0.086), Vector2(-BODY_DEPTH + 0.004, BODY_R),
		Vector2(-0.004, BODY_R), Vector2(0.0, BODY_R - 0.004), Vector2(0.0, 0.034), Vector2(-0.003, 0.031),
		Vector2(-0.030, 0.031), Vector2(-0.030, 0.0),
	])
	_add(Shapes.revolve(prof, 72), mats["chuck"])
	# Brida del husillo (nariz) detrás del plato
	_add(Shapes.revolve(PackedVector2Array([Vector2(-0.100, 0.0), Vector2(-0.100, 0.082), Vector2(-BODY_DEPTH, 0.082), Vector2(-BODY_DEPTH, 0.0)]), 48), mats["steel_dark"])
	# Tornillos de la cara, entre garras, y los alojamientos de la llave en la periferia
	var bolt := Shapes.revolve(PackedVector2Array([Vector2(-0.001, 0.0), Vector2(-0.001, 0.0065), Vector2(0.004, 0.0065), Vector2(0.0048, 0.0055), Vector2(0.0048, 0.0), ]), 16)
	var socket := BoxMesh.new()
	socket.size = Vector3(0.002, 0.006, 0.006)
	var key := BoxMesh.new()
	key.size = Vector3(0.011, 0.004, 0.011)
	for k in 3:
		var ang := TAU * (float(k) + 0.5) / 3.0
		var dir := Vector3(0.0, cos(ang), sin(ang))
		var b := _add(bolt, mats["steel_dark"])
		b.position = dir * 0.072
		var s := _add(socket, mats["black"])
		s.position = dir * 0.072 + Vector3(0.0045, 0.0, 0.0)
		var kh := _add(key, mats["black"])
		kh.position = dir * (BODY_R - 0.0015) + Vector3(-0.030, 0.0, 0.0)
		kh.basis = Basis(Vector3.RIGHT, ang)
		# Ranuras guía de las garras en la cara
		var slot := BoxMesh.new()
		slot.size = Vector3(0.0012, 0.064, JAW_WIDTH + 0.006)
		var sl := _add(slot, mats["black"])
		var ja := TAU * float(k) / 3.0
		sl.position = Vector3(0.0003, 0.0, 0.0) + Vector3(0.0, cos(ja), sin(ja)) * 0.066
		sl.basis = Basis(Vector3.RIGHT, ja)
	# Garras escalonadas: el escalón interior (el que aprieta) sobresale 30 mm de la cara
	var jaw_mesh := _jaw_mesh()
	for k in 3:
		var pivot := Node3D.new()
		pivot.name = "Jaw%d" % k
		pivot.basis = Basis(Vector3.RIGHT, TAU * float(k) / 3.0)
		add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = jaw_mesh
		mi.material_override = mats["jaw"]
		pivot.add_child(mi)
		_jaws.append(pivot)
		_jaw_meshes.append(mi)
	# Copias para el desenfoque (se muestran solo a rpm altas)
	_ghost_root = Node3D.new()
	_ghost_root.name = "Blur"
	add_child(_ghost_root)
	for g in GHOSTS:
		for k in 3:
			var gi := MeshInstance3D.new()
			gi.mesh = jaw_mesh
			gi.material_override = mats["jaw"]
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ghost_root.add_child(gi)
			_ghosts.append(gi)
	set_grip_radius(grip_radius)
	set_blur(0.0, 0.0, 1.0)


## Coloca las garras apretando un diámetro de 2·r (m).
func set_grip_radius(r: float) -> void:
	grip_radius = maxf(r, 0.003)
	for mi in _jaw_meshes:
		mi.position = Vector3(0.0, grip_radius, 0.0)


## Desenfoque de las garras: amount 0 (nítidas) … 1 (anillo borroso); arc: ángulo barrido (rad) durante la
## exposición; spin_sign: sentido de giro (el rastro queda detrás).
func set_blur(amount: float, arc: float, spin_sign: float) -> void:
	blur = clampf(amount, 0.0, 1.0)
	var show_ghosts := blur > 0.01
	_ghost_root.visible = show_ghosts
	for mi in _jaw_meshes:
		mi.transparency = 0.4 * blur
	if not show_ghosts:
		return
	for g in GHOSTS:
		var u := float(g + 1) / float(GHOSTS + 1)
		var off := -spin_sign * arc * u
		# El rastro se desvanece hacia atrás: la garra pasó por ahí antes durante la exposición
		var alpha := clampf(2.6 / float(GHOSTS) * blur * (1.0 - 0.75 * u), 0.0, 0.6)
		for k in 3:
			var gi := _ghosts[g * 3 + k]
			gi.basis = Basis(Vector3.RIGHT, TAU * float(k) / 3.0 + off)
			gi.position = gi.basis * Vector3(0.0, grip_radius, 0.0)
			gi.transparency = 1.0 - alpha


func _add(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


## Garra dura de 3 escalones, en el marco del pivote: +y hacia fuera desde el radio de amarre, +x hacia delante.
func _jaw_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := [[0.0, 0.018, 0.030], [0.018, 0.036, 0.020], [0.036, 0.064, 0.010]]  # [r0, r1, saliente]
	for s in steps:
		var box: Dictionary = Shapes.box_between(Vector3(-0.012, s[0], -JAW_WIDTH * 0.5), Vector3(float(s[2]), s[1], JAW_WIDTH * 0.5), 0.0012, 2)
		st.append_from(box["mesh"], 0, Transform3D(Basis.IDENTITY, box["center"]))
	return st.commit()
