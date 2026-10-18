## Cetrería · demo de los cuerpos enteros y de sus cabezas (unidad 5n) para las capturas, sin la página: cada animal tumbado
## en su sitio (el banco del centro de cetrería o la mesa de la clínica, care_room.gd), con la luz de la cetrería
## (care_stage.gd) y sus garras de partida, visto de lejos (como en la vista del animal) y con la cabeza de cerca: en tres
## cuartos, de lado (desde arriba: tumbado, el lado derecho de la cara mira al techo), de frente y con lo que lleva puesto
## (la capucha de la rapaz sujeta; la mascarilla y la pinza del pulsioxímetro del anestesiado, también la mascarilla de la
## rapaz).
## Captura: node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_cuerpos.tscn --frames=N --out=<carpeta> [--phone]
##          -- [--animales=oso,tigre,…] [--planos=lejos,cabeza,perfil,frente,atrezo,mascarilla] [--fotogramas=3]
##             [--registro=/ruta/fuera/del/repo.txt]
## Sin --animales, los diez dibujos (CareAnatomy.ARTS); sin --planos, lejos, cabeza y atrezo. Con --phone (390 × 844), la
## calidad del teléfono. Escribe (en la salida y, con --registro, en ese archivo: la captura solo enseña los avisos) qué
## fotogramas son de cada plano, lo que cuesta construir cada animal (la primera vez), sus vértices y lo que cuesta animarlo
## en cada fotograma. Solo dibujo: no toca nada del estado de la cetrería.
extends Node3D

const CareAnimal = preload("res://app/lab/cetreria/care_animal.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const CareStage = preload("res://app/lab/cetreria/care_stage.gd")
const CareRoom = preload("res://app/lab/cetreria/care_room.gd")
const CareOrbit = preload("res://app/lab/cetreria/care_orbit.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")

## El borde de la mesa (m) y lo que se separa de él la garra que cuelga: los de la escena de la cetrería (care_3d.gd).
const TABLE_EDGE_X := 0.03
const EDGE_LOW := 0.004
const EDGE_CLEAR := 0.006
const BASE_TUCK := 0.6
## Cada plano: [sujeción (la de la rapaz, la de los demás), vista de care_stage, guiñada, cabeceo (°), distancia (en
## largos de la cabeza; 0: la del animal entero), campo de visión (°)].
const SHOTS := {
	"lejos": [["libre", "libre"], "animal", 70.0, 46.0, 0.0, 40.0],
	"cabeza": [["libre", "libre"], "general", 72.0, 36.0, 3.0, 34.0],
	"perfil": [["libre", "libre"], "general", 90.0, 86.0, 2.6, 34.0],
	"frente": [["libre", "libre"], "general", 185.0, 28.0, 2.4, 34.0],
	"atrezo": [["sujecion", "anestesia"], "general", 72.0, 36.0, 3.0, 34.0],
	"mascarilla": [["anestesia", "anestesia"], "general", 150.0, 50.0, 2.6, 34.0],
}

var _arts: Array = []
var _shots: Array = ["lejos", "cabeza", "atrezo"]
var _hold := 3
var _mobile := false
var _cache := {}
var _stage: RefCounted
var _rig: Node3D
var _world: Node3D
var _room := {}
var _room_key := ""
var _animal := {}
var _claw_mat: StandardMaterial3D
var _queue: Array = []
var _frame := 0
var _t := 0.0
var _left := 0
var _shot := ""
var _anim_us := 0
var _anim_n := 0
var _sed := ""
var _log_path := ""


func _ready() -> void:
	_arts = CareAnatomy.ARTS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--animales="):
			_arts = Array(a.substr(11).split(",", false))
		elif a.begins_with("--planos="):
			_shots = Array(a.substr(9).split(",", false))
		elif a.begins_with("--fotogramas="):
			_hold = maxi(int(a.substr(13)), 1)
		elif a.begins_with("--registro="):
			_log_path = a.substr(11)
			var f := FileAccess.open(_log_path, FileAccess.WRITE)
			if f != null:
				f.close()
		elif a == "--movil":
			_mobile = true
	_mobile = _mobile or get_viewport().get_visible_rect().size.x < 600.0
	_stage = CareStage.build(self, CareStage.current_method(), _mobile)
	_world = Node3D.new()
	_world.name = "Mundo"
	add_child(_world)
	_rig = CareOrbit.new()
	add_child(_rig)
	_rig.min_distance = 0.01
	(_rig.call("camera") as Camera3D).current = true
	_claw_mat = StandardMaterial3D.new()
	_claw_mat.albedo_color = Color("#2A2420")
	_claw_mat.roughness = 0.35
	for art: String in _arts:
		for s: String in _shots:
			if SHOTS.has(s):
				_queue.append([art, s])
	_log("Demo de los cuerpos (5n): %d planos de %d fotogramas, calidad %s." % [_queue.size(), _hold, "movil" if _mobile else "escritorio"])


func _process(delta: float) -> void:
	_t += delta
	if _left <= 0:
		_next()
	if not _animal.is_empty():
		var t0 := Time.get_ticks_usec()
		CareAnimal.animate(_animal, _t, _sed, 0.0, "")
		_anim_us += Time.get_ticks_usec() - t0
		_anim_n += 1
		var cam := _rig.call("camera") as Camera3D
		_stage.call("frame", cam, String((SHOTS.get(_shot, SHOTS.lejos) as Array)[1]), float(_rig.get("distance")))
	_left -= 1
	_frame += 1


## El plano siguiente: el animal (si cambia), la sujeción y la cámara.
func _next() -> void:
	if _queue.is_empty():
		_report_animal()
		_log("Fin de la demo de los cuerpos (5n), fotograma %d." % _frame)
		_left = 1 << 30
		return
	var e: Array = _queue.pop_front()
	var art := String(e[0])
	if _animal.is_empty() or String(_animal.art) != art:
		_report_animal()
		_build(art)
	_shot = String(e[1])
	var spec: Array = SHOTS[_shot]
	var seds: Array = spec[0]
	_sed = String(seds[0] if String(_animal.kind) == "ave" else seds[1])
	CareAnimal.set_sedation(_animal, _sed)
	# los párpados, ya en su sitio (sin la transición de la sujeción anterior)
	(_animal.body as Dictionary)["open"] = -1.0
	_aim(spec)
	_left = _hold
	_log("plano %s %s (%s): fotogramas %d-%d" % [art, _shot, _sed, _frame, _frame + _hold - 1])


## La cámara de un plano: el animal entero (como la vista del animal de la cetrería) o la cabeza a k largos de ella.
func _aim(spec: Array) -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := clampf(vs.x / maxf(vs.y, 1.0), 0.4, 1.0)
	var box: AABB = _animal.box
	var off: Vector3 = _animal.get("offset", Vector3.ZERO)
	var fov := float(spec[5])
	var k := float(spec[4])
	if k <= 0.0:
		var c := box.get_center() + off + Vector3(0.15, -0.05, 0.0)
		var pitch := float(spec[3])
		var half_v := tan(deg_to_rad(fov) * 0.5)
		var tall := box.size.x * sin(deg_to_rad(pitch)) + box.size.y * cos(deg_to_rad(pitch))
		var dist := maxf(box.size.z * 0.55 / (half_v * minf(aspect, 1.0)), tall * 0.55 / half_v) + 0.2
		_rig.call("set_orbit", c, float(spec[2]), pitch, clampf(dist, 0.8, 7.0), fov, true)
		return
	var body: Dictionary = _animal.body
	var head: Node3D = body.head
	var hs: Vector3 = body.get("head_size", Vector3(0.14, 0.1, 0.1))
	var at := (head.global_transform * Vector3(hs.x * 0.08, 0.0, 0.0)) if head != null else box.get_center()
	# el teléfono, algo más lejos: la vista es estrecha
	var dist := hs.x * k / pow(aspect, 0.6)
	_rig.call("set_orbit", at, float(spec[2]), float(spec[3]), dist, fov, true)


## Construye el animal en su sitio, con las garras de partida en sus dedos y en el borde de la mesa.
func _build(art: String) -> void:
	if not _animal.is_empty():
		var old: Node3D = _animal.root
		old.get_parent().remove_child(old)
		old.queue_free()
	var animal := "rapaz"
	var claw_id := art
	var model := ""
	match art:
		"tigre", "oso":
			animal = art
			claw_id = ""
		"velociraptor", "velociraptor_pelicula":
			animal = "velociraptor"
			claw_id = ""
			model = "pelicula" if art == "velociraptor_pelicula" else ""
	var setup := { "animal": animal }
	if claw_id != "":
		setup["claw"] = claw_id
	var sn: Dictionary = ClawCare.new(setup).snapshot()
	var claw := { "base_r_mm": float(sn.claw.baseRadiusMm), "length_mm": float(sn.claw.naturalMm), "curve": float(sn.claw.curve) }
	var t0 := Time.get_ticks_usec()
	_animal = CareAnimal.build(_world, animal, claw_id, { "mobile": _mobile, "cache": _cache, "model": model, "claw": claw, "claw_mat": _claw_mat })
	var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_animal["build_ms"] = build_ms
	_claws(claw)
	_place(claw)
	_focus_layer(_animal.root as Node)
	_build_room(animal)
	_anim_us = 0
	_anim_n = 0


## Las garras de partida en los dedos que se trabajan (en la cetrería las pone la escena con el perfil de ClawCare; aquí, un
## perfil que se afina hasta la punta, con su curva).
func _claws(claw: Dictionary) -> void:
	var L := float(claw.length_mm)
	var r0 := float(claw.base_r_mm)
	var key := "garra5n|%s|%s" % [var_to_str(snappedf(L, 0.01)), var_to_str(snappedf(r0, 0.01))]
	if not _cache.has(key):
		var ss := PackedFloat64Array()
		var rs := PackedFloat64Array()
		for i in 17:
			var t := float(i) / 16.0
			ss.append(t * L)
			rs.append(r0 * (1.0 - pow(t, 1.25)) + 0.04)
		rs[16] = 0.0
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ClawMesh.tube_arrays(ss, rs, ClawMesh.curvature(L, float(claw.curve)), 24))
		_cache[key] = am
	for k: String in _animal.slots:
		var e: Dictionary = _animal.slots[k]
		var mi := MeshInstance3D.new()
		mi.name = "Garra_" + k.replace("|", "_")
		mi.mesh = _cache[key]
		mi.material_override = _claw_mat
		mi.transform = Transform3D.IDENTITY.scaled_local(Vector3.ONE * float(e.mm_scale)).translated_local(Vector3(-BASE_TUCK * r0, 0.0, 0.0))
		(e.node as Node3D).add_child(mi)
	CareAnimal.present(_animal, "", [], true)


## Al borde de la mesa, como en la cetrería: lo que de las garras baja hasta la mesa cuelga libre por el borde.
func _place(claw: Dictionary) -> void:
	var root: Node3D = _animal.root
	var k := ClawMesh.curvature(float(claw.length_mm), float(claw.curve))
	var dx := 0.0
	var found := false
	for key: String in _animal.slots:
		var node: Node3D = (_animal.slots[key] as Dictionary).node
		for mi: Node in node.get_children():
			if not mi is MeshInstance3D:
				continue
			var xf := CareAnimal.rel_xf(mi as MeshInstance3D, root)
			var sc := xf.basis.get_scale().x
			for i in 17:
				var s := float(i) / 16.0 * float(claw.length_mm)
				var r := float(claw.base_r_mm) * (1.0 - pow(float(i) / 16.0, 1.25))
				var p := xf * ClawMesh.point_at(s, k)
				if p.y - r * sc < EDGE_LOW:
					var need := TABLE_EDGE_X + EDGE_CLEAR + r * sc - p.x
					dx = need if not found else maxf(dx, need)
					found = true
	_animal["offset"] = Vector3(dx, 0.0, 0.0)
	root.position = _animal.offset
	var under: MeshInstance3D = _animal.get("under")
	if under != null and under.mesh is PlaneMesh:
		var pm := under.mesh as PlaneMesh
		var x0 := under.position.x - pm.size.x * 0.5
		var x1 := minf(under.position.x + pm.size.x * 0.5, TABLE_EDGE_X - dx - 0.002)
		under.visible = x1 > x0 + 0.01
		if under.visible:
			# la tela es de la caché: aquí, una copia del plano con su tamaño
			var pm2 := pm.duplicate() as PlaneMesh
			pm2.size = Vector2(x1 - x0, pm.size.y)
			under.mesh = pm2
			under.position.x = 0.5 * (x0 + x1)


## Todo el animal, en la capa de lo que se enfoca (la de la luz de tres puntos), como en la cetrería.
static func _focus_layer(root: Node) -> void:
	var bit := 1 << (CareStage.FOCUS_LAYER - 1)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers |= bit
		stack.append_array(n.get_children())


## El sitio a la medida del animal (el banco del centro de cetrería o la mesa de la clínica) y su luz.
func _build_room(animal: String) -> void:
	var venue := "cetreria" if animal == "rapaz" else "clinica"
	var box: AABB = _animal.box
	var off: Vector3 = _animal.offset
	var x0 := snappedf(minf(box.position.x + off.x - 0.12, TABLE_EDGE_X - 0.6), 0.05)
	var z0 := snappedf(minf(box.position.z - 0.15, -0.45), 0.05)
	var z1 := snappedf(maxf(box.end.z + 0.15, 0.6), 0.05)
	var key := "%s|%s|%s|%s" % [venue, x0, z0, z1]
	if key != _room_key:
		_room_key = key
		if not _room.is_empty():
			var old: Node3D = _room.root
			old.get_parent().remove_child(old)
			old.queue_free()
		_room = CareRoom.build(_world, venue, TABLE_EDGE_X, x0, z0, z1, _mobile, _cache)
		var lamp: Variant = _room.get("lamp")
		if lamp != null and is_instance_valid(lamp):
			(lamp as Light3D).visible = not _mobile
	var paws: Dictionary = _animal.paws
	var c := Vector3.ZERO
	for p: String in paws:
		c += paws[p] as Vector3
	c = c / float(maxi(paws.size(), 1)) + off
	_stage.call("set_venue", venue, c)


## Lo que ha costado el animal que se va: construirlo, sus vértices (el cuerpo y las patas) y animarlo.
func _report_animal() -> void:
	if _animal.is_empty():
		return
	var verts := _verts(_animal.root as Node)
	var body_verts := _verts((_animal.body as Dictionary).root as Node)
	var us := float(_anim_us) / float(maxi(_anim_n, 1))
	_log("coste %s: construir %s ms · %d vértices (el cuerpo, %d) · animar %s µs por fotograma" % [String(_animal.art),
		String.num(float(_animal.build_ms), 1), verts, body_verts, String.num(us, 1)])


## Una línea del registro: en la salida y, con --registro, al final de ese archivo.
func _log(t: String) -> void:
	print(t)
	if _log_path == "":
		return
	var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f != null:
		f.seek_end()
		f.store_line(t)
		f.close()


static func _verts(n: Node) -> int:
	var v := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		var am := (n as MeshInstance3D).mesh as ArrayMesh
		for si in am.get_surface_count():
			v += am.surface_get_array_len(si)
	for ch in n.get_children():
		v += _verts(ch)
	return v
