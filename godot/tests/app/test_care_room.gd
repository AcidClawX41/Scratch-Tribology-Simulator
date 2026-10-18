## Cetrería · la sala (app/lab/cetreria/care_room.gd), sin ventana: lo que cuelga de la pared del fondo (el estante de las
## capuchas del centro de cetrería y el armario de vitrina de la clínica) queda al lado de la ventana, nunca delante, con
## cualquier tamaño de mesa que pueda pedir la vista 3D (care_3d.gd: z0 ≤ −0,45 y z1 ≥ 0,6), y sin salirse de la pared
## lateral.
extends "res://tests/case.gd"

const CareRoom = preload("res://app/lab/cetreria/care_room.gd")

## [x0, z0, z1] de la mesa: la más pequeña que da care_3d.gd y otras más grandes.
const TABLES := [[-0.6, -0.45, 0.6], [-0.8, -0.6, 0.8], [-1.1, -0.9, 1.2], [-0.6, -0.45, 1.5]]
## La pieza de la pared que no puede tapar la ventana en cada sala: [sala, nodo, pieza].
const WALL_ITEMS := [["cetreria", "Estante", "Tabla"], ["clinica", "Vitrina", "Armario"]]


static func _find(n: Node, path: Array) -> MeshInstance3D:
	if n.name == path[0]:
		if path.size() == 1:
			return n as MeshInstance3D
		for ch in n.get_children():
			var hit := _find(ch, path.slice(1))
			if hit != null:
				return hit
	for ch in n.get_children():
		var hit := _find(ch, path)
		if hit != null:
			return hit
	return null


## El tramo en z (a lo largo de la pared) y en y (alto) de una caja de la sala.
static func _span(mi: MeshInstance3D) -> Rect2:
	var size := (mi.mesh as BoxMesh).size
	var c := mi.global_position
	return Rect2(c.z - size.z * 0.5, c.y - size.y * 0.5, size.z, size.y)


func test_lo_de_la_pared_no_tapa_la_ventana() -> void:
	for item: Array in WALL_ITEMS:
		for t: Array in TABLES:
			var host := Node3D.new()
			add_to_tree(host)
			var room := CareRoom.build(host, String(item[0]), 0.03, float(t[0]), float(t[1]), float(t[2]), false, {})
			var root: Node3D = room.root
			var piece := _find(root, [item[1], item[2]])
			var sky := _find(root, ["Ventana", "Cielo"])
			var wall := _find(root, ["ParedLateral"])
			assert_true(piece != null and sky != null and wall != null, "%s: están el estante, la ventana y la pared" % item[0])
			if piece == null or sky == null or wall == null:
				continue
			var p := _span(piece)
			var w := _span(sky)
			assert_false(p.intersects(w), "%s con la mesa %s: %s tapa la ventana (%s frente a %s)" % [item[0], t, item[2], p, w])
			assert_true(p.position.x > wall.global_position.z, "%s con la mesa %s: %s no se sale por la pared lateral" % [item[0], t, item[2]])
			host.queue_free()
