## Cetrería · la reacción del animal (unidad 5t-B): el esqueleto del animal entero de la escena (el de care_animal.gd con
## los pivotes que dejan care_body.gd y body_*.gd) visto por la animación del ataque. Solo dibujo; no crea nodos ni recursos
## en cada fotograma: mueve transformaciones.
##   - guarda la pose de reposo de todo lo que toca y la devuelve al acabar (reset);
##   - gira cada pivote alrededor de su punto (en reposo están en la identidad: rot_about);
##   - pone la pata que golpea donde diga la animación (en el mundo) y hace que la siga su miembro: el muslo de la rapaz desde
##     la rodilla, el brazo del tigre y del oso desde el hombro (con un estirón suave si hace falta) y la manga del antebrazo
##     con la pata;
##   - da la punta de cada garra de esa pata en el mundo (el vértice más lejos de su base, leído de la malla sin cambiarla):
##     de ahí salen los rayones de la lente.
extends RefCounted

const CareAnimal = preload("res://app/lab/cetreria/care_animal.gd")
const FEATHER_SHADER = preload("res://app/lab/cetreria/body_feather.gdshader")

## Lo que puede estirarse o encogerse un segmento del miembro para llegar (estirar y encoger, sutil).
const STRETCH_MIN := 0.8
const STRETCH_MAX := 1.3

var rig: Dictionary
var body: Dictionary
var kind := ""
var root: Node3D
var root_rest := Transform3D.IDENTITY
var paw := ""
var paw_node: Node3D
var paw_rest := Transform3D.IDENTITY
## El anclaje de la pata (el talón o el codo) en el marco de la pata.
var anchor_local := Vector3.ZERO
var head: Node3D
var head_rest := Transform3D.IDENTITY
var pivots: Dictionary = {}
var spec: Dictionary = {}
var _rest := {}
var _tip_cache := {}
var _slot_rest := {}
var _forced: Array = []
var _signs := {}


func _init(p_rig: Dictionary, p_kind: String, p_paw: String) -> void:
	rig = p_rig
	kind = p_kind
	body = rig.get("body", {})
	root = rig.get("root")
	root_rest = root.transform if root != null else Transform3D.IDENTITY
	pivots = body.get("pivots", {})
	spec = body.get("rig", {})
	head = body.get("head")
	head_rest = body.get("head_rest", Transform3D.IDENTITY)
	var pn: Dictionary = rig.get("paw_nodes", {})
	paw = p_paw if pn.has(p_paw) else (String(pn.keys()[0]) if not pn.is_empty() else "")
	if paw != "":
		paw_node = (pn[paw] as Dictionary).node
		paw_rest = (pn[paw] as Dictionary).rest
		var an: Transform3D = (rig.get("anchors", {}) as Dictionary).get(paw, paw_rest)
		anchor_local = paw_rest.affine_inverse() * an.origin
	for k: String in pivots:
		_rest[k] = (pivots[k] as Node3D).transform
	for key: String in (rig.get("slots", {}) as Dictionary):
		if key.begins_with(paw + "|"):
			var n: Node3D = rig.slots[key].node
			_slot_rest[key] = n.transform


func valid() -> bool:
	return root != null and is_instance_valid(root) and paw_node != null and is_instance_valid(paw_node)


## Todo a su sitio (lo que no mueve care_animal.animate cada fotograma).
func reset() -> void:
	if not valid():
		return
	root.transform = root_rest
	set_ruffle(0.0)
	paw_node.transform = paw_rest
	for k: String in _rest:
		var n: Node3D = pivots[k]
		if is_instance_valid(n):
			n.transform = _rest[k]
	for key: String in _slot_rest:
		var n: Node3D = rig.slots[key].node
		if is_instance_valid(n) and not (rig.get("protract", {}) as Dictionary).has(key):
			n.transform = _slot_rest[key]
	if head != null and is_instance_valid(head):
		head.transform = head_rest
	unforce()


## La pose de reposo de la pata en el mundo (con la raíz donde esté ahora).
func paw_rest_world() -> Transform3D:
	return (root.get_parent() as Node3D).global_transform * root.transform * paw_rest


## Pone la pata que golpea en xf (mundo) y la sigue su miembro.
func set_paw_world(xf: Transform3D) -> void:
	var parent_xf := (root.get_parent() as Node3D).global_transform * root.transform
	paw_node.transform = parent_xf.affine_inverse() * xf
	_limb_follow()


## Gira el pivote k (en reposo en la identidad) con b alrededor de su punto p (en el marco de su padre).
func rot_about(k: String, p: Vector3, b: Basis) -> void:
	var n: Node3D = pivots.get(k)
	if n == null:
		return
	var rest: Transform3D = _rest.get(k, Transform3D.IDENTITY)
	n.transform = Transform3D(b, p - b * p) * rest


## El signo que hace que girar el pivote k sobre axis lleve su malla hacia want (en el marco de su padre): +1 o −1. Una vez
## por pivote (la malla, la primera de sus hijas).
func sign_toward(k: String, p: Vector3, axis: Vector3, want: Vector3) -> float:
	var key := "%s|%s" % [k, str(want)]
	if _signs.has(key):
		return float(_signs[key])
	var s := 1.0
	var n: Node3D = pivots.get(k)
	if n != null:
		var c := p + want * 0.01
		for ch: Node in n.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
				c = (ch as MeshInstance3D).transform * (ch as MeshInstance3D).mesh.get_aabb().get_center()
				break
		var r := c - p
		var plus := (Basis(axis.normalized(), 0.2) * r).dot(want)
		var minus := (Basis(axis.normalized(), -0.2) * r).dot(want)
		s = 1.0 if plus >= minus else -1.0
	_signs[key] = s
	return s


## La cabeza: cabeceo (pitch, hacia arriba), giro (yaw, hacia la cámara: hacia +X del mundo, el borde de la mesa) y lo que
## se adelanta (pull, fracción de su largo), alrededor del cuello (spec.neck.pivot, en su marco); scale: el disco facial.
func pose_head(pitch: float, yaw: float, pull: float, disc := 0.0) -> void:
	if head == null or not is_instance_valid(head):
		return
	var nk: Dictionary = spec.get("neck", {})
	var pv: Vector3 = nk.get("pivot", Vector3.ZERO)
	var hl := float(nk.get("len", 0.1))
	# tumbado de lado (la derecha arriba): mirar hacia el borde de la mesa (la cámara) es girar sobre el eje z de la cabeza
	# hacia su vientre (−y); levantarla de la mesa, girar sobre su y hacia +z (arriba)
	var b := Basis(Vector3(0.0, 0.0, 1.0), -yaw) * Basis(Vector3(0.0, 1.0, 0.0), -pitch)
	if disc > 0.0:
		b = b * Basis.from_scale(Vector3(1.0, 1.0 + 0.04 * disc, 1.0 - 0.08 * disc))
	var local := Transform3D(b, pv - b * pv).translated_local(Vector3(pull * hl, 0.0, 0.0))
	head.transform = head_rest * local


## La mandíbula de abajo (abrir: ang > 0).
func pose_jaw(ang: float) -> void:
	var j: Dictionary = spec.get("jaw", {})
	if j.is_empty() or not pivots.has("jaw"):
		return
	rot_about("jaw", j.pivot, Basis((j.axis as Vector3).normalized(), -ang))


## Los párpados: open (1 del todo; más, muy abiertos), por encima de lo que pone care_body.animate.
func pose_eyes(open: float) -> void:
	for lid: Dictionary in body.get("lids", []):
		var up := bool(lid.upper)
		var ang := deg_to_rad(float(lid.open_deg)) * open * (-1.0 if up else 1.0)
		(lid.node as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, ang), Vector3.ZERO)


## El dedo IV de las nocturnas que se vuelve hacia atrás (0 delante, 1 del todo atrás: zigodáctilas al atacar), con el
## pivote de la calle E (rig.toe_pivots["pata|IV"]: point, axis, back_deg; en la identidad en reposo).
func pose_toe_back(w: float) -> void:
	for key: String in (rig.get("toe_pivots", {}) as Dictionary):
		if not key.begins_with(paw + "|"):
			continue
		var e: Dictionary = rig.toe_pivots[key]
		rot_about("toe|" + key, e.point, Basis((e.axis as Vector3).normalized(), deg_to_rad(float(e.back_deg)) * clampf(w, 0.0, 1.0)))


## Las plumas que se erizan (0-1): el uniforme «ruffle» de los materiales de plumas (body_feather.gdshader).
func set_ruffle(v: float) -> void:
	for m: Variant in body.get("breath_mats", []):
		if m is ShaderMaterial and (m as ShaderMaterial).shader == FEATHER_SHADER:
			(m as ShaderMaterial).set_shader_parameter("ruffle", clampf(v, 0.0, 1.0))


## La membrana nictitante (0 recogida, 1 tapando el ojo).
func pose_nict(v: float) -> void:
	for e: Variant in spec.get("nict", []):
		var d: Dictionary = e
		var n: Node3D = pivots.get(String(d.node))
		if n != null:
			n.transform = Transform3D(Basis(Vector3.UP, 2.2 * float(d.side) * (1.0 - clampf(v, 0.0, 1.0))), Vector3.ZERO)


## El cuerpo que rueda hacia el pecho (se levanta un poco), alrededor del canto del lomo en la mesa.
func pose_roll(ang: float) -> void:
	var box: AABB = rig.get("box", AABB())
	var p := Vector3(box.position.x, 0.0, 0.0)
	root.transform = root_rest * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), ang), p - Basis(Vector3(0.0, 0.0, 1.0), ang) * p)


## El cuerpo que gira en la cadera sobre la vertical (la cola rígida de contrapeso del velocirraptor).
func pose_yaw(ang: float, at: Vector3) -> void:
	root.transform = root_rest * Transform3D(Basis(Vector3.UP, ang), at - Basis(Vector3.UP, ang) * at)


## Las garras de la pata que golpea flexionadas (la última falange que se cierra al agarrar: la punta hacia la planta) y,
## en el tigre, fuera de su vaina (out, 0-1). k: cuánto, en rad.
func pose_claws(flex: float, out := -1.0) -> void:
	var pr: Dictionary = rig.get("protract", {})
	for key: String in _slot_rest:
		var n: Node3D = rig.slots[key].node
		var base: Transform3D = _slot_rest[key]
		if pr.has(key) and out >= 0.0:
			var e: Dictionary = pr[key]
			var k := maxf(float(e.k), clampf(out, 0.0, 1.0))
			var eased := k * k * (3.0 - 2.0 * k)
			base = (e["in"] as Transform3D).interpolate_with(e.out as Transform3D, eased)
		elif pr.has(key):
			continue
		n.transform = base * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -flex), Vector3.ZERO)


## La hoz (el dedo II del velocirraptor): levantada (ang > 0) o bajando para cortar (ang < 0).
func pose_sickle(ang: float) -> void:
	var key := paw + "|II"
	if not _slot_rest.has(key):
		return
	var n: Node3D = rig.slots[key].node
	n.transform = (_slot_rest[key] as Transform3D) * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), ang), Vector3.ZERO)


## Las garras de la pata que golpea, visibles mientras dura (las del tigre que no se trabajan van escondidas en la vaina).
func force_claws_visible() -> void:
	for key: String in _slot_rest:
		var n: Node3D = rig.slots[key].node
		for ch: Node in n.get_children():
			if ch is MeshInstance3D and not (ch as MeshInstance3D).visible:
				(ch as MeshInstance3D).visible = true
				if not _forced.has(ch):
					_forced.append(ch)


func unforce() -> void:
	for ch: Variant in _forced:
		if is_instance_valid(ch):
			(ch as MeshInstance3D).visible = false
	_forced.clear()


## La garra del dedo finger de la pata que golpea: el nodo que la dibuja (la malla del estuche de la que se trabaja, la de
## las demás, o las de dibujo del velocirraptor), o null.
func claw_mesh(finger: String) -> MeshInstance3D:
	var key := paw + "|" + finger
	var slots: Dictionary = rig.get("slots", {})
	if slots.has(key):
		var n: Node3D = slots[key].node
		for ch: Node in n.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null and (ch as MeshInstance3D).mesh.get_surface_count() > 0:
				return ch
			if ch.name == "Garra":
				var s := ch.get_node_or_null("Estuche") as MeshInstance3D
				if s != null and s.mesh != null and s.mesh.get_surface_count() > 0:
					return s
	var m := paw_node.get_node_or_null("Garra_" + finger) as MeshInstance3D
	return m


## La punta de la garra finger en el mundo (el vértice de su malla más lejos de su base), o null si no hay.
func tip_world(finger: String) -> Variant:
	var mi := claw_mesh(finger)
	if mi == null or not mi.is_inside_tree():
		return null
	var mesh := mi.mesh
	var id := mesh.get_instance_id()
	if not _tip_cache.has(id):
		var best := Vector3.ZERO
		var far := -1.0
		var arrays := mesh.surface_get_arrays(0)
		for v: Vector3 in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var d := v.length_squared()
			if d > far:
				far = d
				best = v
		_tip_cache[id] = best
	return mi.global_transform * (_tip_cache[id] as Vector3)


## Las puntas de los dedos fingers en el marco de la pata (en la pose de ahora), para encuadrar el golpe.
func tips_local(fingers: Array) -> Dictionary:
	var out := {}
	var inv := paw_node.global_transform.affine_inverse()
	for f: String in fingers:
		var p: Variant = tip_world(f)
		if p != null:
			out[f] = inv * (p as Vector3)
	return out


## El miembro sigue a la pata: el muslo de la rapaz (de la rodilla al talón) o el brazo (del hombro al codo), y la manga del
## antebrazo con la pata.
func _limb_follow() -> void:
	var heel_now := paw_node.transform * anchor_local
	for k: String in ["thigh", "arm"]:
		var s: Dictionary = spec.get(k, {})
		if s.is_empty() or not pivots.has(k):
			continue
		var p: Vector3 = s.pivot
		var rest_end: Vector3 = s.get("heel", s.get("elbow", paw_rest * anchor_local))
		var d0 := rest_end - p
		var d1 := heel_now - p
		if d0.length_squared() < 1e-10 or d1.length_squared() < 1e-10:
			continue
		var q := Quaternion(d0.normalized(), d1.normalized())
		var st := clampf(d1.length() / d0.length(), STRETCH_MIN, STRETCH_MAX)
		var n0 := d0.normalized()
		# estirar a lo largo del segmento de reposo: I + (s − 1)·n·nᵀ
		var sb := Basis(Vector3(1, 0, 0) + n0 * (n0.x * (st - 1.0)), Vector3(0, 1, 0) + n0 * (n0.y * (st - 1.0)), Vector3(0, 0, 1) + n0 * (n0.z * (st - 1.0)))
		rot_about(k, p, Basis(q) * sb)
	if pivots.has("forearm"):
		(pivots.forearm as Node3D).transform = paw_node.transform * paw_rest.affine_inverse()
