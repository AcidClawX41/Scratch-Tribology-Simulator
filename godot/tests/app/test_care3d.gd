## Escena 3D de la cetrería (app/lab/cetreria/care_3d.tscn, unidad 5b) sin ventana, en un SubViewport de tamaño fijo:
## carga con su API; pinta los cuatro animales, las rapaces y las garras reforjadas, con la pata al borde de la mesa (las
## garras cuelgan libres) y las bandejas en el carro, lejos de ella; las tres vistas; el rayo del puntero sigue la garra
## sin saltos de estación en estación y toca la punta con un margen; el ratón coge de la bandeja y lima la garra (los
## gestos llegan al estado como órdenes); los fotogramas no crean nodos, la malla solo se rehace cuando cambia la forma,
## y lo que cuesta un fotograma de la escena (advance) cabe en el presupuesto.
extends "res://tests/case.gd"

const SCENE := "res://app/lab/cetreria/care_3d.tscn"
const Runner = preload("res://app/lab/cetreria/care_runner.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CareTools = preload("res://app/lab/cetreria/care_tools.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Data = preload("res://core/lab/data.gd")
const Js = preload("res://core/shared/js.gd")

const FRAME := 1.0 / 30.0
const VIEWPORT := Vector2i(800, 600)
## Presupuesto de un fotograma de la escena (ms de media de advance(), sin el dibujo): holgado para las máquinas de la
## integración continua; en un portátil, ~1 ms.
const BUDGET_MS := 4.0


## La escena dentro de un SubViewport de VIEWPORT píxeles en el árbol (para que la cámara proyecte como en la página).
func _host() -> Array:
	var vp := SubViewport.new()
	vp.size = VIEWPORT
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	return [vp, s]


static func _runner(setup: Dictionary = {}) -> Runner:
	var r := Runner.new(setup)
	r.post("tick", [FRAME])
	return r


## Los gestos de la escena van al estado como órdenes (lo que hace la página).
static func _wire(s: Node3D, r: Runner) -> void:
	s.connect("gesture", func(op: String, args: Array) -> void: r.post(op, args))


func _mouse(s: Node3D, p: Vector2, button := -1, pressed := false) -> void:
	if button < 0:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		s.call("handle_pointer", mm)
		return
	var mb := InputEventMouseButton.new()
	mb.button_index = button as MouseButton
	mb.pressed = pressed
	mb.position = p
	s.call("handle_pointer", mb)


func _frame(s: Node3D, r: Runner) -> void:
	s.call("advance", FRAME)
	r.post("tick", [FRAME])
	s.call("show_view", r.latest())


func test_carga_con_su_api() -> void:
	var h := _host()
	var s: Node3D = h[1]
	for m in ["show_view", "set_view", "info", "advance", "handle_pointer", "hit_at", "claw_screen_point", "tray_screen_point",
			"camera", "node_count", "set_quality", "is_mobile"]:
		assert_true(s.has_method(m), "la escena expone %s()" % m)
	var r := _runner()
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	var info: Dictionary = s.call("info")
	assert_eq(info.view, "garra", "empieza en la vista de la garra, de cerca")
	assert_eq(info.held, "", "con las herramientas en la bandeja")
	assert_eq(info.animal, "rapaz", "y la rapaz")
	assert_eq(int(info.mesh_builds), 1, "una malla de la garra")


## Cada animal, cada rapaz y las garras reforjadas: la garra tratada y las demás cuelgan por el borde de la mesa (nada
## de ellas por debajo de la mesa encima de ella) y las bandejas no tocan la pata.
func test_animales_rapaces_y_reforjadas() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var cases: Array = []
	for a in ["rapaz", "tigre", "oso", "velociraptor"]:
		cases.append({ "animal": a })
	for c in CareData.RAPTOR_IDS:
		cases.append({ "animal": "rapaz", "claw": c })
	for inlay in ["oro", "acero", "vidrio", "zafiro", "diamante"]:
		cases.append({ "animal": "tigre", "inlay": inlay })
	var edge := float(s.get("TABLE_EDGE_X"))
	for setup: Dictionary in cases:
		var r := _runner(setup)
		var v := r.latest()
		s.call("show_view", v)
		s.call("advance", FRAME)
		var what := "%s/%s/%s" % [String(v.setup.animal), String(v.setup.claw), String(v.setup.inlay)]
		assert_eq(String(s.call("info").animal), String(v.setup.animal), "%s: la pata de su animal" % what)
		# lo que baja a la altura de la mesa queda fuera de ella
		var claw: Node3D = s.get("_claw")
		var k := ClawMesh.curvature(float(v.snap.claw.naturalMm), float(v.snap.claw.curve))
		var ss: PackedFloat64Array = v.snap.profile.s
		var rs: PackedFloat64Array = v.snap.profile.r
		var low_inside := 0
		for i in ss.size():
			var p: Vector3 = claw.global_transform * ClawMesh.point_at(ss[i], k)
			if p.y - rs[i] * 0.001 < 0.0 and p.x < edge:
				low_inside += 1
		assert_eq(low_inside, 0, "%s: la garra no se mete en la mesa" % what)
		# las bandejas, en el carro y lejos de la pata
		var paw_box := _box(s.get("_paw").root as Node3D)
		for id: String in (s.get("_slots") as Dictionary):
			var wb: AABB = (s.get("_slots")[id] as Transform3D) * (s.get("_slot_boxes")[id] as AABB)
			assert_false(wb.intersects(paw_box), "%s: %s no toca la pata" % [what, id])
			assert_true(wb.position.x >= float(s.get("CART_X0")), "%s: %s está en el carro" % [what, id])


static func _box(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
			var b := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			out = b if first else out.merge(b)
			first = false
	return out


func test_tres_vistas() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	s.call("show_view", r.latest())
	for v in ["general", "garra", "seccion"]:
		s.call("set_view", v, true)
		s.call("advance", FRAME)
		assert_eq(s.call("info").view, v, "vista %s" % v)
	var sec: Node3D = s.get("_sec").root
	assert_true(sec.visible, "en la sección se ve el corte")
	var mid: Vector2 = Vector2(VIEWPORT) * 0.5
	assert_true((s.call("hit_at", mid) as Dictionary).is_empty(), "en la sección no se usan las herramientas")
	s.call("set_view", "garra", true)
	s.call("advance", FRAME)
	assert_false(sec.visible, "fuera de la sección, el corte no se ve")


## El rayo sigue al puntero a lo largo de la garra (sin quedarse en las estaciones de 0,5 mm del perfil) y la punta, de
## décimas de milímetro, se toca con el margen de la escena.
func test_el_rayo_sigue_la_garra_y_toca_la_punta() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	var v := r.latest()
	s.call("show_view", v)
	s.call("set_view", "garra", true)
	s.call("advance", FRAME)
	var apex := float(v.snap.claw.lengthMm)
	var seen := {}
	var prev := -1.0
	var back := 0
	for i in 41:
		var want := lerpf(apex * 0.45, apex * 0.85, float(i) / 40.0)
		var hit: Dictionary = s.call("hit_at", s.call("claw_screen_point", want, 0.0, 0.0))
		assert_false(hit.is_empty(), "el eje de la garra a %s mm se toca" % Js.to_fixed(want, 1))
		if hit.is_empty():
			continue
		seen[Js.to_fixed(float(hit.s), 2)] = true
		if float(hit.s) < prev - 0.05:
			back += 1
		prev = float(hit.s)
	assert_true(seen.size() >= 36, "el toque sigue al puntero: %d posiciones distintas de 41" % seen.size())
	assert_eq(back, 0, "y nunca vuelve atrás al avanzar hacia la punta")
	# justo al lado de la punta (unos píxeles), aún se toca la punta
	var tip: Vector2 = s.call("claw_screen_point", apex, 0.0, 0.0)
	var near: Vector2 = s.call("claw_screen_point", apex - 1.0, 0.0, 0.0)
	var out_dir := (tip - near).normalized()
	var hit_tip: Dictionary = s.call("hit_at", tip + out_dir * 4.0)
	assert_false(hit_tip.is_empty(), "a 4 px de la punta, se toca")
	if not hit_tip.is_empty():
		assert_true(float(hit_tip.s) > apex - 0.6, "y es la punta (%s de %s mm)" % [Js.to_fixed(float(hit_tip.s), 2), Js.to_fixed(apex, 2)])
	assert_true((s.call("hit_at", tip + out_dir * 60.0) as Dictionary).is_empty(), "lejos de la garra, no")


## El ratón coge la lima de la bandeja (vista general) y la pasa por la garra (vista de la garra): el estado recibe la
## orden de coger y las pasadas (file); lo que toca lo decide el rayo.
func test_el_raton_coge_de_la_bandeja_y_lima() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "general", true)
	s.call("advance", FRAME)
	var p: Vector2 = s.call("tray_screen_point", "lima_bastarda")
	assert_true(Rect2(Vector2.ZERO, Vector2(VIEWPORT)).has_point(p), "la lima se ve en la vista general (%s)" % p)
	_mouse(s, p)
	_mouse(s, p, MOUSE_BUTTON_LEFT, true)
	_mouse(s, p, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(r.state.tool, "lima_bastarda", "el clic en la bandeja la coge")
	assert_eq(s.call("info").held, "lima_bastarda", "y la escena la lleva en la mano")
	s.call("set_view", "garra", true)
	_frame(s, r)
	var apex: float = r.state.care.apex_mm()
	var a: Vector2 = s.call("claw_screen_point", apex - 2.5, 0.0, 0.0)
	var b: Vector2 = s.call("claw_screen_point", apex - 0.5, 0.0, 0.0)
	_mouse(s, a)
	_frame(s, r)
	_mouse(s, a, MOUSE_BUTTON_LEFT, true)
	for i in 12:
		_mouse(s, a.lerp(b, float(i + 1) / 12.0) + (b - a) * 2.0 * float(i + 1) / 12.0)
		_frame(s, r)
	_mouse(s, b, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	var files: Array = r.state.calls.filter(func(c: Array) -> bool: return String(c[0]) == "file")
	assert_true(files.size() >= 1, "la pasada lima la garra (%d llamadas a file)" % files.size())
	if not files.is_empty():
		assert_eq(String(files[0][1].tool), "lima_bastarda", "con la lima de la mano")
		assert_eq(String(files[0][1].zone), "punta", "en la punta, donde se apretó")
	# Esc la deja en la bandeja
	r.post("drop")
	_frame(s, r)
	assert_eq(s.call("info").held, "", "dejada en su sitio")


func test_los_fotogramas_no_crean_nodos_y_la_malla_solo_con_la_forma() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "garra", true)
	r.post("pick", ["lima_bastarda"])
	r.post("set_force", [8.0])
	_frame(s, r)
	_frame(s, r)
	var nodes := int(s.call("node_count"))
	var builds := int(s.call("info").mesh_builds)
	# lo que no cambia la forma no rehace la malla
	for i in 20:
		r.post("nudge_angle", [1.0])
		_frame(s, r)
	assert_eq(int(s.call("info").mesh_builds), builds, "cambiar el ángulo no rehace la malla")
	# limar sí (una vez por cada forma nueva), y los fotogramas no crean nodos
	var apex: float = r.state.care.apex_mm()
	var a: Vector2 = s.call("claw_screen_point", apex - 2.5, 0.0, 0.0)
	var b: Vector2 = s.call("claw_screen_point", apex + 3.0, 0.0, 0.0)
	var shapes := {}
	for stroke in 4:
		_mouse(s, a)
		_frame(s, r)
		_mouse(s, a, MOUSE_BUTTON_LEFT, true)
		for i in 15:
			_mouse(s, a.lerp(b, float(i + 1) / 15.0))
			_frame(s, r)
			shapes[String(r.latest().mesh.key)] = true
		_mouse(s, b, MOUSE_BUTTON_LEFT, false)
		_frame(s, r)
		shapes[String(r.latest().mesh.key)] = true
	for i in 30:
		_frame(s, r)
	var info: Dictionary = s.call("info")
	assert_true(int(info.mesh_builds) > builds, "limar cambia la forma y rehace la malla")
	assert_true(int(info.mesh_builds) - builds <= shapes.size(), "una malla por forma nueva (%d mallas, %d formas)" % [int(info.mesh_builds) - builds, shapes.size()])
	assert_eq(int(s.call("node_count")), nodes, "los fotogramas no crean nodos")
	assert_true(int(info.dust) > 0, "y el polvo de la lima, sin nodos nuevos (%d motas)" % int(info.dust))


## Lo que cuesta un fotograma de la escena con el puntero moviéndose sobre la garra (el rayo, la herramienta, el polvo y
## la cámara): la media de advance() cabe en el presupuesto.
func test_coste_por_fotograma() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "garra", true)
	r.post("pick", ["lima_bastarda"])
	_frame(s, r)
	var apex: float = r.state.care.apex_mm()
	var a: Vector2 = s.call("claw_screen_point", apex - 6.0, 0.0, 0.0)
	var b: Vector2 = s.call("claw_screen_point", apex + 2.0, 0.0, 0.0)
	var t0 := int(s.call("info").frames)
	for i in 240:
		var k := float(i % 40) / 40.0
		if i % 40 == 0:
			_mouse(s, a, MOUSE_BUTTON_LEFT, true)
		_mouse(s, a.lerp(b, k))
		if i % 40 == 39:
			_mouse(s, b, MOUSE_BUTTON_LEFT, false)
		_frame(s, r)
	var info: Dictionary = s.call("info")
	assert_true(int(info.frames) - t0 >= 240, "240 fotogramas")
	var avg := float(info.update_ms_avg)
	assert_true(avg < BUDGET_MS, "un fotograma de la escena cuesta %s ms de media (presupuesto %s ms)" % [Js.to_fixed(avg, 2), Js.to_fixed(BUDGET_MS, 1)])
	print("    (info) escena 3D de la cetrería: %s ms de media por fotograma (máximo %s ms) con el puntero limando la garra" % [Js.to_fixed(avg, 2), Js.to_fixed(float(info.update_ms_max), 2)])



## Sobre la garra, la herramienta de la mano se vuelve de cristal (se ve lo que lima) y fuera de ella recupera sus
## materiales; un ensayo nuevo empieza sin el polvo ni la sangre del anterior.
func test_herramienta_de_cristal_y_ensayo_nuevo_limpio() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner()
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "garra", true)
	r.post("pick", ["lima_bastarda"])
	r.post("set_force", [8.0])
	_frame(s, r)
	var meshes: Array = (s.get("_tools") as Dictionary)["lima_bastarda"].meshes
	var before: Array = meshes.map(func(mi: MeshInstance3D) -> Variant: return mi.material_override)
	var apex: float = r.state.care.apex_mm()
	var a: Vector2 = s.call("claw_screen_point", apex - 2.5, 0.0, 0.0)
	var b: Vector2 = s.call("claw_screen_point", apex + 3.0, 0.0, 0.0)
	_mouse(s, a)
	_frame(s, r)
	_mouse(s, a, MOUSE_BUTTON_LEFT, true)
	for i in 12:
		_mouse(s, a.lerp(b, float(i + 1) / 12.0))
		_frame(s, r)
	var glass: Material = s.get("_glass_tool_mat")
	assert_true(glass != null and meshes.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == glass), "sobre la garra, de cristal")
	_mouse(s, b, MOUSE_BUTTON_LEFT, false)
	_mouse(s, Vector2(4.0, 4.0))
	for i in 3:
		_frame(s, r)
	var after: Array = meshes.map(func(mi: MeshInstance3D) -> Variant: return mi.material_override)
	assert_eq(after, before, "fuera de la garra, con sus materiales")
	assert_true(int(s.call("info").dust) > 0, "el polvo de la pasada")
	r.post("restart")
	_frame(s, r)
	assert_eq(int(s.call("info").dust), 0, "otra garra: sin el polvo de antes")
	assert_eq(int(s.call("info").drops), 0, "ni gotas")



# ════════ Unidad 5c: el escenario, el animal entero, las patas y la amoladora ════════

## Cada animal entero, con su dibujo, en su sitio: la rapaz (cada una con el suyo) en el banco del centro de cetrería; el
## tigre, el oso y el velocirraptor (los dos dibujos) en la mesa de la clínica; cada garra de cada pata con su malla, y la
## garra de ClawCare colgada de la pata y el dedo elegidos.
func test_cada_animal_entero_en_su_sitio() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var cases: Array = []
	for c in CareData.RAPTOR_IDS:
		cases.append([{ "animal": "rapaz", "claw": c }, "", c, "cetreria"])
	cases.append([{ "animal": "tigre" }, "", "tigre", "clinica"])
	cases.append([{ "animal": "oso" }, "", "oso", "clinica"])
	cases.append([{ "animal": "velociraptor" }, "reconstruccion", "velociraptor", "clinica"])
	cases.append([{ "animal": "velociraptor" }, "pelicula", "velociraptor_pelicula", "clinica"])
	for c: Array in cases:
		var r := _runner(c[0])
		if String(c[1]) != "":
			r.post("set_model", [c[1]])
		var v := r.latest()
		s.call("show_view", v)
		s.call("advance", FRAME)
		var info: Dictionary = s.call("info")
		var what := "%s/%s" % [String(v.setup.animal), String(c[2])]
		assert_eq(String(info.art), String(c[2]), "%s: su propio modelo" % what)
		assert_eq(String(info.venue), String(c[3]), "%s: en su sitio" % what)
		var rig: Dictionary = s.get("_paw")
		var n_slots := State.paws_of(String(v.setup.animal)).size() * State.digit_ids(String(v.setup.animal)).size()
		assert_eq((rig.slots as Dictionary).size(), n_slots, "%s: cada garra de cada pata (%d)" % [what, n_slots])
		assert_eq((s.get("_others") as Dictionary).size(), n_slots, "%s: cada una con su malla" % what)
		var key := "%s|%s" % [String(v.paw), String(v.digit)]
		var claw: Node3D = s.get("_claw")
		assert_true(claw.get_parent() == (rig.slots[key] as Dictionary).node, "%s: la garra de ClawCare, en la pata y el dedo elegidos" % what)
		assert_false(((s.get("_others") as Dictionary)[key] as MeshInstance3D).visible, "%s: y la del modelo, escondida" % what)


## Las patas: al elegir otra pata y otra garra, la garra de ClawCare se cuelga ahí, su malla se rehace (cada garra tiene la
## suya) y la cámara de la vista de la garra va a ella; la que se deja se queda con su forma. Un clic sobre otra garra la
## elige (la orden select_claw).
func test_las_patas_y_la_camara_va_a_la_elegida() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "tigre", "seed": "patas" })
	_wire(s, r)
	r.post("set_sedation", ["anestesia"])
	s.call("show_view", r.latest())
	s.call("set_view", "garra", true)
	_frame(s, r)
	var builds := int(s.call("info").mesh_builds)
	var claw: Node3D = s.get("_claw")
	var first_parent := claw.get_parent()
	r.post("select_claw", ["trasera_izquierda", "V"])
	for i in 45:
		_frame(s, r)
	assert_eq(String(s.call("info").slot), "trasera_izquierda|V", "la garra elegida")
	assert_true(claw.get_parent() != first_parent, "la garra de ClawCare cambia de pata")
	assert_true(int(s.call("info").mesh_builds) > builds, "con su propia malla")
	var cam := s.call("camera") as Camera3D
	var mid: Vector3 = s.call("_claw_mid_world")
	var rig_target: Vector3 = (s.get("_rig") as Node).get("target")
	assert_true(rig_target.distance_to(mid) < 0.02, "la cámara va a la garra elegida (%s m)" % Js.to_fixed(rig_target.distance_to(mid), 3))
	assert_true(cam.global_position.distance_to(mid) < 0.6, "y de cerca")
	# un clic sobre otra garra de la misma pata la elige (en el águila: las del tigre que no se trabajan van recogidas)
	var r2 := _runner({ "animal": "rapaz", "seed": "clic" })
	_wire(s, r2)
	s.call("show_view", r2.latest())
	s.call("set_view", "garra", true)
	for i in 30:
		_frame(s, r2)
	var others: Dictionary = s.get("_others")
	var v2 := r2.latest()
	var k := ClawMesh.curvature(float(v2.snap.claw.naturalMm), float(v2.snap.claw.curve))
	var start := float(v2.snap.claw.startMm)
	var picked := ""
	for key: String in others:
		var mi: MeshInstance3D = others[key]
		if not mi.is_visible_in_tree():
			continue
		for f: float in [0.5, 0.35, 0.65]:
			var p := cam.unproject_position(mi.global_transform * ClawMesh.point_at(start * f, k))
			if cam.is_position_behind(mi.global_transform * ClawMesh.point_at(start * f, k)) or not Rect2(Vector2.ZERO, Vector2(VIEWPORT)).has_point(p):
				continue
			_mouse(s, p)
			if (s.call("hit_at", p) as Dictionary).is_empty() and String(s.call("_claw_pick")) == key:
				picked = key
				_mouse(s, p, MOUSE_BUTTON_LEFT, true)
				_mouse(s, p, MOUSE_BUTTON_LEFT, false)
				_frame(s, r2)
				break
		if picked != "":
			break
	assert_true(picked != "", "otra garra del águila se ve en la vista de la garra y se puede tocar")
	assert_eq("%s|%s" % [r2.state.paw, r2.state.digit], picked, "un clic sobre otra garra la elige")


## La amoladora en la escena: se coge del carro, un clic en el aire la enciende (su interruptor), el tambor arranca con la
## inercia del motor, los pilotos dicen la velocidad, el botón deslizante se mueve a su posición y al tocar la garra la lima
## (file con sus rpm); los fotogramas no crean nodos.
func test_la_amoladora_en_la_mano() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "tigre", "seed": "amoladora" })
	_wire(s, r)
	r.post("set_sedation", ["anestesia"])
	s.call("show_view", r.latest())
	s.call("set_view", "general", true)
	_frame(s, r)
	var p: Vector2 = s.call("tray_screen_point", "amoladora")
	assert_true(Rect2(Vector2.ZERO, Vector2(VIEWPORT)).has_point(p), "la amoladora se ve en el carro (%s)" % p)
	_mouse(s, p)
	_mouse(s, p, MOUSE_BUTTON_LEFT, true)
	_mouse(s, p, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(r.state.tool, "amoladora", "el clic la coge")
	assert_eq(r.state.angle_deg, 45.0, "apoyada en su protector, a 45°")
	s.call("set_view", "garra", true)
	_frame(s, r)
	var nodes := int(s.call("node_count"))
	# un clic en el aire (lejos de la garra y del carro): el interruptor
	_mouse(s, Vector2(6.0, 6.0))
	_mouse(s, Vector2(6.0, 6.0), MOUSE_BUTTON_LEFT, true)
	_mouse(s, Vector2(6.0, 6.0), MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_true(r.state.rotary_on, "un clic en el aire la enciende")
	var t: Dictionary = (s.get("_tools") as Dictionary)["amoladora"]
	_frame(s, r)
	var early := float(t.rpm_now)
	for i in 30:
		_frame(s, r)
	assert_true(early > 0.0 and early < float(t.rpm_now), "el tambor arranca con la inercia (%s → %s rpm)" % [Js.to_fixed(early, 0), Js.to_fixed(float(t.rpm_now), 0)])
	var leds: Array = t.led_mats
	var lit := leds.filter(func(m: StandardMaterial3D) -> bool: return m.emission_energy_multiplier > 0.0).size()
	assert_eq(lit, 1, "un piloto: la primera velocidad")
	r.post("cycle_rpm")
	r.post("cycle_rpm")
	for i in 10:
		_frame(s, r)
	lit = leds.filter(func(m: StandardMaterial3D) -> bool: return m.emission_energy_multiplier > 0.0).size()
	assert_eq(lit, 3, "tres pilotos: la tercera (21 000 rpm)")
	var slider: Node3D = t.slider
	assert_near(slider.position.x, float(CareTools.GRINDER_SLIDE[2]) * CareTools.MM, 0.0, 5e-4, "el botón del interruptor, en la tercera posición")
	# tocar la garra: lima con la amoladora a sus rpm
	var apex: float = r.state.care.apex_mm()
	var a: Vector2 = s.call("claw_screen_point", apex - 0.5, 0.0, 0.0)
	_mouse(s, a)
	_frame(s, r)
	_mouse(s, a, MOUSE_BUTTON_LEFT, true)
	for i in 20:
		_frame(s, r)
	_mouse(s, a, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	var files: Array = r.state.calls.filter(func(c: Array) -> bool: return String(c[0]) == "file")
	assert_true(not files.is_empty(), "al tocar la garra, la lima")
	if not files.is_empty():
		assert_eq(String(files[0][1].tool), "amoladora", "con la amoladora")
		assert_eq(float(files[0][1].rpm), 21000.0, "a sus rpm")
	assert_eq(int(s.call("node_count")), nodes, "los fotogramas no crean nodos")


## El sitio y el animal se construyen una vez por animal y calidad: empezar de nuevo, cambiar de garra o de pata no los
## rehace; el modelo del animal sale de la caché la segunda vez; el preset del teléfono quita detalle al sitio (menos
## nodos y sin la luz de la lámpara).
func test_se_construye_una_vez_por_animal_y_calidad() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner({ "animal": "oso" })
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	var animal_root: Node3D = (s.get("_paw") as Dictionary).root
	var room_root: Node3D = (s.get("_room") as Dictionary).root
	r.post("restart")
	r.post("select_claw", ["trasera_derecha", "II"])
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	assert_true((s.get("_paw") as Dictionary).root == animal_root, "empezar de nuevo o cambiar de garra no rehace el animal")
	assert_true((s.get("_room") as Dictionary).root == room_root, "ni el sitio")
	r.post("set_animal", ["tigre"])
	s.call("show_view", r.latest())
	r.post("set_animal", ["oso"])
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	assert_eq(int((s.get("_paw") as Dictionary).meshes_built), 0, "el oso, otra vez: de la caché (sin mallas nuevas)")
	var desk := _count_nodes((s.get("_room") as Dictionary).root)
	var lamp: Variant = (s.get("_room") as Dictionary).lamp
	assert_true(lamp != null and (lamp as Light3D).visible, "en el escritorio, la lámpara de quirófano alumbra")
	s.call("set_quality", "movil")
	r.post("restart")
	var v := r.latest()
	s.call("show_view", v)
	s.call("advance", FRAME)
	var phone := _count_nodes((s.get("_room") as Dictionary).root)
	assert_true(phone < desk, "en el teléfono, el sitio con menos detalle (%d nodos frente a %d)" % [phone, desk])
	assert_true((s.get("_room") as Dictionary).lamp == null, "y sin la luz de la lámpara")
	assert_false((s.get("_sun") as DirectionalLight3D).shadow_enabled, "ni sombras")


static func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


## Lo que cuesta un fotograma de la escena con el animal entero, la amoladora encendida tocando la garra y el polvo, en el
## escritorio y con el preset del teléfono.
func test_coste_por_fotograma_con_el_animal_y_la_amoladora() -> void:
	var line := PackedStringArray()
	for q: String in ["", "movil"]:
		var h := _host()
		var s: Node3D = h[1]
		s.call("set_quality", q)
		var r := _runner({ "animal": "oso", "seed": "coste" })
		_wire(s, r)
		r.post("set_sedation", ["anestesia"])
		r.post("pick", ["amoladora"])
		r.post("set_rotary", [true])
		s.call("show_view", r.latest())
		s.call("set_view", "garra", true)
		_frame(s, r)
		var apex: float = r.state.care.apex_mm()
		var a: Vector2 = s.call("claw_screen_point", apex - 1.0, 0.0, 0.0)
		var t0 := int(s.call("info").frames)
		var sum0 := float(s.call("info").update_ms_avg) * float(t0)
		_mouse(s, a)
		_mouse(s, a, MOUSE_BUTTON_LEFT, true)
		for i in 180:
			if i % 60 == 59:
				_mouse(s, a, MOUSE_BUTTON_LEFT, false)
				_mouse(s, a, MOUSE_BUTTON_LEFT, true)
			_frame(s, r)
		_mouse(s, a, MOUSE_BUTTON_LEFT, false)
		var info: Dictionary = s.call("info")
		var n := int(info.frames) - t0
		var avg := (float(info.update_ms_avg) * float(info.frames) - sum0) / float(maxi(n, 1))
		assert_true(avg < BUDGET_MS, "%s: un fotograma de la escena cuesta %s ms de media (presupuesto %s ms)" % [info.quality, Js.to_fixed(avg, 2), Js.to_fixed(BUDGET_MS, 1)])
		line.append("%s %s ms (máximo %s ms)" % [info.quality, Js.to_fixed(avg, 2), Js.to_fixed(float(info.update_ms_max), 2)])
		(h[0] as Node).queue_free()
	print("    (info) escena 3D de la cetrería con el oso entero y la amoladora: %s" % ", ".join(line))
	# lo que tarda en construirse cada animal con su sitio (la primera vez y con la caché del modelo), por calidad
	var builds := PackedStringArray()
	for q: String in ["", "movil"]:
		var h := _host()
		var s: Node3D = h[1]
		s.call("set_quality", q)
		var r := _runner()
		s.call("show_view", r.latest())
		for pass_i in 2:
			for a: String in ["rapaz", "tigre", "oso", "velociraptor"]:
				r.post("set_animal", [a])
				var t0 := Time.get_ticks_usec()
				s.call("show_view", r.latest())
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0
				builds.append("%s %s%s %s ms" % ["móvil" if q == "movil" else "escritorio", a, " (caché)" if pass_i == 1 else "", Js.to_fixed(ms, 0)])
				assert_true(ms < 3000.0, "%s: el animal y su sitio se construyen en %s ms" % [a, Js.to_fixed(ms, 0)])
		(h[0] as Node).queue_free()
	print("    (info) construir el animal y su sitio: %s" % ", ".join(builds))
