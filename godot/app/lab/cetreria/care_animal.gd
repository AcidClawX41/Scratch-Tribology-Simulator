## Cetrería · el animal tumbado sobre la mesa (unidades 5c y 5h): desde la petición 37, con sus propios modelos, hechos
## desde cero para la cetrería e independientes de los del coche en marcha:
##   - las patas, los dedos y las garras en alta definición (care_paw.gd), lo que se ve en primer plano;
##   - el cuerpo entero en alta definición (care_body.gd y body_*.gd, unidad 5i: plumas en capas, pelo con volumen,
##     escamas, ojos con párpados), a su tamaño (core/lab/care_anatomy.gd), enganchado a las patas por sus anclajes;
##   - lo de la sujeción o la anestesia: la toalla (con sus pliegues) y la capucha de la rapaz, la mascarilla del
##     isoflurano y la pinza del pulsioxímetro de los grandes. Solo dibujo.
##
## Cada garra que se trabaja (ClawCareState: pata y dedo) tiene un nodo en la punta de su dedo con el marco de su base
## (+X la dirección de partida, +Y la cara dorsal, +Z el lado, como el de claw_mesh.gd): la escena cuelga ahí la suya (la
## del perfil de ClawCare). En el tigre, ese nodo va de la vaina (la garra recogida) a fuera cuando se trabaja esa garra
## (present() y animate()).
## Orientación: la raíz queda en la mesa (y = 0), con las patas hacia +X (el borde), la cabeza hacia −Z y el lado
## derecho del animal arriba. Los anclajes de las patas (anchors) quedan fijados en la raíz: es donde se enganchará el
## cuerpo de alta definición.
extends RefCounted

const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const CareBody = preload("res://app/lab/cetreria/care_body.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const State = preload("res://core/lab/claw_care_state.gd")

## Lo que tarda en salir o en recogerse la garra del tigre (s, constante de tiempo).
const PROTRACT_TAU := 0.12
## Dónde va cada pata en la mesa (m, en la raíz; × la escala del cuerpo): la rapaz y el velocirraptor, dos patas; el tigre y
## el oso, cuatro (las de arriba, las derechas, algo más hacia la cabeza que las de abajo).
const PAW_SPOTS := {
	"ave": { "derecha": Vector3(0.0, 0.0, -0.05), "izquierda": Vector3(0.014, 0.0, 0.055) },
	"mamifero": { "delantera_derecha": Vector3(0.0, 0.0, -0.43), "delantera_izquierda": Vector3(0.02, 0.0, -0.24),
		"trasera_derecha": Vector3(0.0, 0.0, 0.25), "trasera_izquierda": Vector3(0.02, 0.0, 0.44) },
	"teropodo": { "derecha": Vector3(0.0, 0.0, -0.08), "izquierda": Vector3(0.02, 0.0, 0.1) },
}


## El dibujo de cada animal de la cetrería: la rapaz, el de su especie (la garra del banco); el velocirraptor, el de la
## reconstrucción o el de cine (model: «pelicula»; misma garra y misma física: solo cambia el dibujo).
static func art_of(animal: String, claw_id: String, model := "") -> String:
	match animal:
		"rapaz":
			return claw_id if CarePaw.RAPTOR.has(claw_id) else "aguila"
		"velociraptor":
			return "velociraptor_pelicula" if model == "pelicula" else "velociraptor"
	return animal


static func kind_of(animal: String) -> String:
	match animal:
		"tigre", "oso":
			return "mamifero"
		"velociraptor":
			return "teropodo"
	return "ave"


## Construye el animal tumbado. opts: mobile, cache (las mallas y los materiales se hacen una vez por especie, lado y
## calidad), model (el dibujo del velocirraptor), claw ({ base_r_mm, length_mm, curve }: la garra del motor, que da la
## escala de las patas), claw_mat (el material de las garras que no se trabajan).
## → { root, a3d (null: sin modelo del coche), kind, animal, art, slots: { "pata|dedo": { index, node, xf, mm_scale } },
##     box (AABB en m, en la raíz), props: { wrap, hood, mask, clip }, under (la tela de debajo), paws: { pata: Vector3
##     (el centro de la pata, en la raíz) }, anchors: { pata: Transform3D (el anclaje, en la raíz) }, paw_nodes,
##     protract: { "pata|dedo": … }, toe_pivots: { "pata|dedo": … } (CarePaw.build: el dedo IV de las nocturnas, que se
##     gira hacia atrás; también en body.pivots como «toe|pata|dedo»), body, verts, meshes_built (las patas y el cuerpo que no
##     estaban en la caché) }
static func build(parent: Node3D, animal: String, claw_id: String, opts := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var mobile := bool(opts.get("mobile", false))
	var art := art_of(animal, claw_id, String(opts.get("model", "")))
	var kind := kind_of(animal)
	var claw: Dictionary = opts.get("claw", { "base_r_mm": 5.25, "length_mm": 35.0, "curve": 0.85 })
	var body_len := _body_len(art)
	var sc := body_len / (0.85 if kind == "ave" else (1.9 if kind == "mamifero" else 2.07))
	var root := Node3D.new()
	root.name = "Animal"
	parent.add_child(root)
	var cache: Dictionary = opts.get("cache", {})
	var slots := {}
	var paws := {}
	var anchors := {}
	var paw_nodes := {}
	var protract := {}
	var toe_pivots := {}
	var box := AABB()
	var first := true
	var verts := 0
	var built := 0
	var spots: Dictionary = PAW_SPOTS[kind]
	for p: String in State.paws_of(animal):
		var spot: Vector3 = spots.get(p, Vector3.ZERO)
		var pw := CarePaw.build(root, animal, art, claw, p, { "mobile": mobile, "cache": cache, "claw_mat": opts.get("claw_mat") })
		var pnode: Node3D = pw.root
		pnode.position = Vector3(spot.x, 0.0, spot.z * sc)
		paw_nodes[p] = { "node": pnode, "rest": pnode.transform }
		verts += int(pw.verts)
		built += 1 if bool(pw.fresh) else 0
		for d: String in State.digit_ids(animal):
			if not (pw.slots as Dictionary).has(d):
				continue
			slots[State.slot_key(p, d)] = { "index": -1, "node": pw.slots[d], "xf": Transform3D.IDENTITY, "mm_scale": 0.001 }
			if (pw.protract as Dictionary).has(d):
				protract[State.slot_key(p, d)] = pw.protract[d]
			if (pw.get("toe_pivots", {}) as Dictionary).has(d):
				toe_pivots[State.slot_key(p, d)] = pw.toe_pivots[d]
		paws[p] = pnode.transform * (pw.center as Vector3)
		anchors[p] = pnode.transform * (pw.anchor as Transform3D)
		var pb: AABB = pnode.transform * (pw.aabb as AABB)
		box = pb if first else box.merge(pb)
		first = false
	var body := CareBody.build(root, animal, art, anchors, { "mobile": mobile, "cache": cache, "claw": claw })
	box = box.merge(body.box as AABB)
	# (vuelta de pulido de la 5s, para la calle B) los pivotes de los dedos que se giran, también entre los del cuerpo:
	# «toe|pata|dedo» (rot_about gira el nodo en torno a su punto, en el marco de su padre: la pata)
	var bp: Dictionary = body.get("pivots", {})
	for k: String in toe_pivots:
		bp["toe|" + k] = (toe_pivots[k] as Dictionary).node
	body["pivots"] = bp
	built += 1 if bool(body.get("fresh", false)) else 0
	var rig := { "root": root, "a3d": null, "kind": kind, "animal": animal, "art": art, "slots": slots, "box": box, "paws": paws,
		"anchors": anchors, "paw_nodes": paw_nodes, "protract": protract, "toe_pivots": toe_pivots, "props": body.props, "under": body.under, "body": body,
		"mpc": 0.01, "t": -1.0, "verts": verts, "meshes_built": built, "build_us": Time.get_ticks_usec() - t0 }
	return rig


## El largo con el que se dibuja el cuerpo (m): el de la ficha de su especie (core/lab/care_anatomy.gd): el largo total
## en las rapaces y los velocirraptores, el de la cabeza y el cuerpo en el tigre y el oso. Da dónde van las patas.
static func _body_len(art: String) -> float:
	return CareAnatomy.draw_length_m(art)


## Transformación de un nodo relativa a un antepasado (sin el árbol de la escena).
static func rel_xf(n: Node3D, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != ancestor:
		xf = (x as Node3D).transform * xf
		x = x.get_parent()
	return xf


## Lo que cambia con la sujeción: la toalla y la capucha de la rapaz (sujeta o sedada), la mascarilla (anestesiada) y la
## pinza del pulsioxímetro (anestesiado). Libre, nada.
static func set_sedation(rig: Dictionary, sedation: String) -> void:
	var body: Dictionary = rig.get("body", {})
	if not body.is_empty():
		CareBody.set_sedation(body, sedation)


## Qué garras del tigre están fuera de su vaina: la que se trabaja (selected) y las que ya se han trabajado (worked, para
## ver su forma); las demás, recogidas. instant: sin transición (al construir).
static func present(rig: Dictionary, selected: String, worked: Array, instant := false) -> void:
	var pr: Dictionary = rig.get("protract", {})
	for key: String in pr:
		var e: Dictionary = pr[key]
		e["goal"] = 1.0 if key == selected or worked.has(key) else 0.0
		if instant:
			e["k"] = float(e.goal)
			(e.node as Node3D).transform = _protract_xf(e)


static func _protract_xf(e: Dictionary) -> Transform3D:
	var k := float(e.k)
	var eased := k * k * (3.0 - 2.0 * k)
	return (e["in"] as Transform3D).interpolate_with(e.out as Transform3D, eased)


## La pose de cada fotograma: la respiración (lenta si duerme), el respingo de dolor (flinch, 0-1) de la pata paw y la garra
## del tigre que sale o se recoge. Solo mueve transformaciones.
static func animate(rig: Dictionary, t: float, sedation: String, flinch: float, paw: String) -> void:
	var dt := clampf(t - float(rig.get("t", t)), 0.0, 0.25) if float(rig.get("t", -1.0)) >= 0.0 else 0.0
	rig["t"] = t
	var body: Dictionary = rig.get("body", {})
	if not body.is_empty():
		CareBody.animate(body, t, sedation, flinch)
	var pn: Dictionary = rig.get("paw_nodes", {})
	for p: String in pn:
		var e: Dictionary = pn[p]
		var rest: Transform3D = e.rest
		if p == paw and flinch > 0.0:
			var j := clampf(flinch, 0.0, 1.0) * sin(t * 40.0)
			(e.node as Node3D).transform = rest.rotated_local(Vector3.UP, 0.05 * j).translated(Vector3(-0.006 * absf(j), 0.002 * absf(j), 0.0))
		elif (e.node as Node3D).transform != rest:
			(e.node as Node3D).transform = rest
	var pr: Dictionary = rig.get("protract", {})
	var a := 1.0 - exp(-dt / PROTRACT_TAU) if dt > 0.0 else 0.0
	for key: String in pr:
		var e: Dictionary = pr[key]
		var goal := float(e.goal)
		if absf(float(e.k) - goal) > 1e-4:
			e["k"] = lerpf(float(e.k), goal, a) if absf(float(e.k) - goal) > 0.002 else goal
			(e.node as Node3D).transform = _protract_xf(e)
