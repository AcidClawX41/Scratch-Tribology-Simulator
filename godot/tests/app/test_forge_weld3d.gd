## La mesa de soldar en la escena 3D de la reforja (app/lab/cetreria/forge_3d.gd, unidad 5r): el aparato del método que se ve;
## «Colocar en la mesa» pone la funda partida en el soporte; apretar sobre la costura con el ratón da el pedal y los pulsos
## dejan sus cuentas; al soltar, el pedal se suelta; la vuelta entera deja una cuenta por tramo; y los fotogramas no crean
## nodos.
extends "res://tests/case.gd"

const SCENE := "res://app/lab/cetreria/forge_3d.tscn"
const Runner = preload("res://app/lab/cetreria/forge_runner.gd")
const State = preload("res://core/lab/claw_forge_state.gd")

const FRAME := 1.0 / 30.0
const VIEWPORT := Vector2i(800, 600)


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


## Una funda de acero hecha, fría y tallada, por las órdenes del estado (lo recomendado, a la velocidad máxima).
static func _piece(r: Runner) -> void:
	r.post("set_process", ["acero"])
	r.post("set_speed", [State.SPEEDS.size() - 1])
	r.post("set_tutorial", [false])
	r.post("apply_recommended")
	r.post("load_crucible")
	r.post("insert_charge")
	r.post("start")
	_settle(r)
	r.post("cool_piece")
	_settle(r)
	r.post("carve")
	_settle(r)


static func _settle(r: Runner) -> void:
	var st: State = r.state
	var n := 0
	while (st.running() or (not st.act.is_empty() and float(st.act.t) < float(st.act.dur))) and n < 20000:
		if st.running():
			r.post("skip")
		r.post("tick", [FRAME])
		n += 1


func _frame(s: Node3D, r: Runner) -> void:
	s.call("advance", FRAME)
	r.post("tick", [FRAME])
	s.call("show_view", r.latest())


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


func test_colocar_y_soldar_con_el_raton() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila" })
	s.connect("gesture", func(op: String, args: Array) -> void: r.post(op, args))
	_piece(r)
	r.post("set_weld_params", [r.state.forge.weld_recommended().weld_setup])
	s.call("show_view", r.latest())
	s.call("set_view", "soldar", true)
	_frame(s, r)
	var info: Dictionary = s.call("info")
	assert_eq(String(info.weld_device), "laser", "se ve la soldadora del método (el láser)")
	assert_false(bool(info.weld_work), "sin colocar, la mesa está vacía")
	r.post("weld_prepare")
	r.post("weld_align_pieces")
	for i in 3:
		_frame(s, r)
	info = s.call("info")
	assert_true(bool(info.weld_work), "colocadas: la funda partida en el soporte")
	assert_eq(int(info.weld_beads), 0, "sin puntos todavía")
	var n0 := int(s.call("node_count"))
	# apretar sobre la costura y recorrerla un poco: el pedal y los pulsos
	var p0: Vector2 = s.call("weld_seam_screen_point", 0.1)
	assert_true(p0.x >= 0.0, "la costura se ve en la vista «Soldar»")
	_mouse(s, p0)
	_mouse(s, p0, MOUSE_BUTTON_LEFT, true)
	assert_true(bool(r.latest().weld.hold), "apretar sobre la costura es el pedal")
	for i in 60:
		var u := 0.1 + 0.3 * float(i) / 60.0
		_mouse(s, s.call("weld_seam_screen_point", u))
		_frame(s, r)
	info = s.call("info")
	assert_true(int(info.weld_beads) > 2, "los pulsos dejan sus cuentas en la costura (%d)" % int(info.weld_beads))
	_mouse(s, s.call("weld_seam_screen_point", 0.4), MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_false(bool(r.latest().weld.hold), "al soltar, el pedal se suelta")
	assert_eq(int(s.call("node_count")), n0, "los fotogramas no crean nodos")
	# la vuelta entera: una cuenta por tramo
	r.post("weld_all")
	_frame(s, r)
	var w: Dictionary = r.latest().weld
	assert_true(bool(w.done), "la costura entera")
	info = s.call("info")
	assert_eq(int(info.weld_beads), mini(int(w.pulses_need), 200), "una cuenta por tramo")
