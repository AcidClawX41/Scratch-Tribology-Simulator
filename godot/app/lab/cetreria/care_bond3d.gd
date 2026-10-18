## Cetrería 3D · la colocación a mano de la pieza de la reforja (unidad 5o, petición 43): la bandeja de la colocación (la jeringa
## doble con su cánula, el vaso del acrílico con su masa, los frascos, la jeringa de la resina, la lámpara LED con su luz azul,
## la venda y el filtro naranja), la pieza (en la bandeja, en la mano siguiendo al puntero o al dedo, y apretada sobre el
## muñón con su inclinación), el cordón de lo que rebosa (brillante en fresco y mate ya curado) y la venda puesta.
## Solo pinta la vista de ClawCareState (view().bond y la malla de la pieza que hace el hilo, view().bond_mesh): no calcula
## física. Nada se crea en cada fotograma: se mueven transformaciones y se cambian parámetros.
## Uso (desde care_3d): b.build(world, tray, mobile); b.apply(v, claw, k); b.update(cam, pointer, claw, k, mm_px)
extends RefCounted

const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CareTools = preload("res://app/lab/cetreria/care_tools.gd")
const ClawLook = preload("res://app/lab/cetreria/claw_look.gd")
const KERATIN_SHADER = preload("res://app/lab/cetreria/keratin.gdshader")

const MM := 0.001
## El sitio de la pieza en la bandeja (m, en la bandeja de la colocación) y desde dónde se acopla al muñón al llevarla
## (px de pantalla del puntero a la unión): dibujo.
const PIECE_SLOT := Vector3(-0.07, 0.012, 0.04)
const DOCK_PX := 120.0
## El imán del muñón (px de pantalla): más cerca, la pieza se centra sola sobre él (lo que se aparta cuenta desde ahí). Con el
## dedo, más grande (el dedo tapa lo que hay debajo). Dibujo e interfaz: la tolerancia de verdad es la de CareData.BOND_ALIGN.
const SNAP_PX := 14.0
const SNAP_PX_TOUCH := 30.0
## El color del adhesivo fresco de cada uno (dibujo).
const ADHESIVE_COLOR := { "cianoacrilato": "#F4F1E6", "epoxi": "#E2C27A", "metacrilato": "#EFE6D0", "masilla": "#6E7378" }

var root: Node3D
var props: Dictionary = {}
var piece: MeshInstance3D
var piece_mesh := ArrayMesh.new()
var piece_mat: ShaderMaterial
var flash: MeshInstance3D
var flash_torus := TorusMesh.new()
var flash_mat := StandardMaterial3D.new()
var wrap_band: MeshInstance3D
var wrap_torus := TorusMesh.new()
var dough_mat: StandardMaterial3D
var lamp_rest := Transform3D.IDENTITY
var shield_rest := Transform3D.IDENTITY
var bv: Dictionary = {}
## La pieza de la vista: { key, arrays, jointMm, lengthMm } y la clave de su aspecto.
var mesh_key := ""
var look_key := ""
var joint_mm := 0.0
var length_mm := 0.0
## Lo que apunta el puntero frente al centro del muñón (mm), lo que la escena manda con bond_aim.
var aim_mm := 0.0
var docked := false
## Dentro del imán: la pieza, centrada sobre el muñón.
var snapped := false
var _snap_px := SNAP_PX
var _tray: Node3D


func build(world: Node3D, tray: Node3D, mobile: bool) -> void:
	_tray = tray
	_snap_px = SNAP_PX_TOUCH if mobile else SNAP_PX
	root = Node3D.new()
	root.name = "ColocarLaPieza"
	world.add_child(root)
	props = CareTools.bond_props(tray, mobile)
	dough_mat = props.dough_mat
	lamp_rest = (props.lamp as Node3D).transform
	shield_rest = (props.shield as Node3D).transform
	piece_mat = ShaderMaterial.new()
	piece_mat.shader = KERATIN_SHADER
	piece = MeshInstance3D.new()
	piece.name = "Pieza"
	piece.mesh = piece_mesh
	piece.material_override = piece_mat
	piece.visible = false
	root.add_child(piece)
	flash_torus.rings = 24
	flash_torus.ring_segments = 8
	flash = MeshInstance3D.new()
	flash.name = "LoQueRebosa"
	flash.mesh = flash_torus
	flash_mat.albedo_color = Color("#E2C27A")
	flash_mat.roughness = 0.08
	flash_mat.clearcoat_enabled = true
	flash_mat.clearcoat = 1.0
	flash.material_override = flash_mat
	flash.visible = false
	root.add_child(flash)
	wrap_torus.rings = 24
	wrap_torus.ring_segments = 10
	wrap_band = MeshInstance3D.new()
	wrap_band.name = "Venda"
	wrap_band.mesh = wrap_torus
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#5C9BD5")
	wm.roughness = 0.95
	wrap_band.material_override = wm
	wrap_band.visible = false
	root.add_child(wrap_band)


## La vista nueva: la pieza, su aspecto, lo que rebosa, la venda, la masa del vaso y la lámpara.
func apply(v: Dictionary, claw: Node3D, k: float) -> void:
	bv = v.get("bond", {})
	var bm: Dictionary = v.get("bond_mesh", {})
	var on := not bv.is_empty()
	(props.root as Node3D).visible = on
	if not on:
		piece.visible = false
		flash.visible = false
		wrap_band.visible = false
		return
	if not bm.is_empty() and String(bm.key) != mesh_key:
		mesh_key = String(bm.key)
		piece_mesh.clear_surfaces()
		if bm.arrays is Array and ClawMesh.has_triangles(bm.arrays):
			piece_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.arrays)
		joint_mm = float(bm.jointMm)
		length_mm = float(bm.lengthMm)
	var lk := "%s|%s" % [String(bv.material), String(bv.kind)]
	if lk != look_key:
		look_key = lk
		ClawLook.apply(piece_mat, ClawLook.params(String(bv.material), Color("#C7CDD6"), {}))
	piece.visible = not bm.is_empty()
	# lo que rebosa: un cordón alrededor de la unión, del volumen del motor; brillante en fresco, mate ya duro
	var sn: Dictionary = v.snap
	var prof: Dictionary = sn.profile
	var j := float(bv.jointMm)
	var r := maxf(ClawMesh.radius_at(prof.s, prof.r, j), 0.3)
	var vol := float(bv.flashMm3)
	flash.visible = vol > 0.0 and (bool(bv.placed) or bool(bv.attached))
	if flash.visible:
		var a := clampf(sqrt(vol / (2.0 * PI * PI * r)), 0.05, 1.5)
		flash_torus.inner_radius = r * MM
		flash_torus.outer_radius = (r + 2.0 * a) * MM
		var fresh := bool(bv.fresh)
		flash_mat.albedo_color = Color(String(ADHESIVE_COLOR.get(String(bv.adhesive), "#E6DCCF"))) if String(bv.method) == "adhesivo" else Color("#E6DCCF")
		flash_mat.roughness = 0.08 if fresh else 0.75
		flash_mat.clearcoat = 1.0 if fresh else 0.0
	wrap_band.visible = bool(bv.wrapped)
	if wrap_band.visible:
		wrap_torus.inner_radius = r * MM
		wrap_torus.outer_radius = (r + 1.6) * MM
	_place_on_claw(flash, claw, j, k)
	_place_on_claw(wrap_band, claw, j, k)
	# la masa del vaso: líquida y brillante, en masa, ya dura y mate
	var ph := String(bv.mixPhase)
	(props.dough as Node3D).visible = ph != ""
	dough_mat.roughness = { "liquida": 0.1, "masa": 0.45, "dura": 0.8, "fraguada": 0.9 }.get(ph, 0.5)
	# la lámpara: sobre la capa mientras cura, con la luz azul; si no, en la bandeja
	var lamp: Node3D = props.lamp
	var lit := bool(bv.lampOn)
	(props.lamp_light as Light3D).visible = lit
	(props.lamp_glow as Node3D).visible = lit
	if lit:
		var apex := float(sn.claw.lengthMm)
		var tip_w := claw.global_transform * ClawMesh.point_at(apex, k)
		var dir := (claw.global_transform.basis * ClawMesh.tangent_at(apex, k)).normalized()
		var up := (claw.global_transform.basis * ClawMesh.up_at(apex, k)).normalized()
		var at := tip_w + dir * (float(bv.lampMm) + 38.0) * MM + up * 0.004
		var bx := -dir
		var bz := bx.cross(up).normalized()
		lamp.global_transform = Transform3D(Basis(bx, bz.cross(bx), bz), at)
	else:
		lamp.transform = lamp_rest
	# el filtro naranja, de pie junto a la garra con los ojos tapados
	var sh: Node3D = props.shield
	if bool(bv.eyes) and String(bv.method) == "resina":
		var apex2 := float(sn.claw.lengthMm)
		sh.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), claw.global_transform * ClawMesh.point_at(apex2, k) + Vector3(0.0, 0.03, 0.03))
	else:
		sh.transform = shield_rest


## Pone n en la unión de la garra (j mm desde la base), con su eje a lo largo de la garra.
static func _place_on_claw(n: Node3D, claw: Node3D, j: float, k: float) -> void:
	if not n.visible:
		return
	var p := ClawMesh.point_at(j, k)
	var t := ClawMesh.tangent_at(j, k).normalized()
	var u := ClawMesh.up_at(j, k).normalized()
	var b := Basis(u, t, u.cross(t))
	n.global_transform = claw.global_transform * Transform3D(b.scaled(Vector3.ONE / MM), p)


## Cada fotograma: dónde está la pieza (en la bandeja, en la mano o apretada sobre el muñón con su inclinación y lo
## descentrada que quede). pointer: el puntero (o el dedo) en pantalla; mm_px: mm de la garra por píxel. Devuelve lo que
## apunta (mm del centro del muñón, contados desde el borde del imán) mientras la pieza está en la mano, o −1. docked: sobre
## el muñón (a menos de DOCK_PX); fuera, apretar no la coloca.
func update(cam: Camera3D, pointer: Vector2, claw: Node3D, k: float, mm_px: float) -> float:
	snapped = false
	if bv.is_empty() or not piece.visible:
		docked = false
		return -1.0
	var j := joint_mm
	var joint_w := claw.global_transform * ClawMesh.point_at(j, k)
	var placed := bool(bv.placed)
	var held := bool(bv.held)
	var tilt := deg_to_rad(float(bv.placedTiltDeg if placed else bv.tiltDeg))
	var hinge := Transform3D(Basis(Vector3.BACK, -tilt), Vector3.ZERO)
	var local := Transform3D(Basis.IDENTITY, ClawMesh.point_at(j, k)) * hinge * Transform3D(Basis.IDENTITY, -ClawMesh.point_at(j, k))
	if placed:
		docked = true
		var off := float(bv.placedOffsetMm) * MM
		piece.global_transform = Transform3D(Basis.IDENTITY, (cam.global_transform.basis.x * off)) * claw.global_transform * local
		return -1.0
	if held:
		var sp := cam.unproject_position(joint_w)
		var px := pointer.distance_to(sp)
		aim_mm = maxf(px - _snap_px, 0.0) * mm_px
		docked = px <= DOCK_PX
		snapped = px <= _snap_px
		var d := Vector3.ZERO
		if snapped:
			# dentro del imán: centrada sobre el muñón (d = 0)
			pass
		elif docked:
			var plane_n := -cam.global_transform.basis.z
			var o := cam.project_ray_origin(pointer)
			var dir := cam.project_ray_normal(pointer)
			var den := dir.dot(plane_n)
			if absf(den) > 1e-6:
				d = o + dir * ((joint_w - o).dot(plane_n) / den) - joint_w
				# lo que queda fuera del imán, desde su borde (como lo cuenta aim_mm)
				d *= maxf(1.0 - _snap_px / maxf(px, 1e-6), 0.0)
		else:
			# lejos de la garra: en la mano, delante de la cámara donde está el puntero
			var o2 := cam.project_ray_origin(pointer)
			var p2 := o2 + cam.project_ray_normal(pointer) * joint_w.distance_to(o2) * 0.8
			d = p2 - joint_w
		piece.global_transform = Transform3D(Basis.IDENTITY, d) * claw.global_transform * local
		return aim_mm
	docked = false
	# en la bandeja de la colocación, tumbada, con el centro de la pieza en su sitio
	var c := ClawMesh.point_at(j + 0.5 * length_mm, k)
	piece.global_transform = _tray.global_transform * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * MM), PIECE_SLOT) * Transform3D(Basis.IDENTITY, -c)
	return -1.0


## ¿Apunta el puntero a la pieza que espera en la bandeja (para cogerla)? El rayo contra su caja.
func points_at_piece(cam: Camera3D, pointer: Vector2) -> bool:
	if bv.is_empty() or not piece.visible or bool(bv.held) or bool(bv.placed):
		return false
	var box := piece.global_transform * piece_mesh.get_aabb()
	box = box.grow(0.006)
	var o := cam.project_ray_origin(pointer)
	var d := cam.project_ray_normal(pointer)
	return box.intersects_ray(o, d) != null
