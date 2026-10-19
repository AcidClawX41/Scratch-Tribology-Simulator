## Unidad 4y: las marcas del coche en marcha salen de lo que hace cada animal, la cámara de persecución nunca entra en él y
## las garras dobladas o melladas son una sola malla continua.
extends "res://tests/case.gd"

const Card = preload("res://app/lab/moving_car_card.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Js = preload("res://core/shared/js.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const HdAnimal = preload("res://app/lab/animals/hd3d.gd")
const Animal3D = preload("res://app/lab/animals/animal3d.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


func _card(claw_id: String, width := 680.0) -> Control:
	var host := Control.new()
	host.size = Vector2(width + 20.0, 1600)
	add_to_tree(host)
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = false
	lab.set_claw(C(claw_id))
	card.refresh()
	card.finish()
	card.size = Vector2(width, 0)
	host.add_child(card)
	return card


func _run(card: Control, steps: int, ms := 16.0) -> void:
	for i in steps:
		card.step(ms)
		await wait_frames(1)


## La menor distancia (m) de la cámara de persecución a la caja de cada malla del animal (0 si está dentro de alguna).
static func _cam_gap(view: Control) -> float:
	var cam: Camera3D = view._scene.chase_cam
	var root: Node3D = view._rig.get("root")
	var p := cam.global_position
	var best := INF
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			var mi := n as MeshInstance3D
			var box: AABB = mi.global_transform * mi.get_aabb()
			if box.has_point(p):
				return 0.0
			var q := p.clamp(box.position, box.end)
			best = minf(best, q.distance_to(p))
	return best


func test_la_camara_de_persecucion_nunca_entra_en_el_animal() -> void:
	# en la S y en la curva, con las garras clavadas (el caso de Eric) y sin ellas, el velocirraptor de cine (3,4 m con la cola)
	# y los demás que se quedan encima: la cámara nunca dentro de la caja de una malla del animal, y el animal nunca ocupa más
	# de CarScene.CHASE_ANIMAL_MAX de la vista
	for cfg: Array in [["velociraptor_pelicula", 95.0, 130.0, CarCurve.ROAD_S, true], ["velociraptor_pelicula", 160.0, 130.0, CarCurve.ROAD_S, true],
			["velociraptor_pelicula", 60.0, 50.0, CarCurve.ROAD_S, false], ["velociraptor", 95.0, 130.0, CarCurve.ROAD_S, true],
			["velociraptor_pelicula", 200.0, 130.0, CarCurve.ROAD_CURVE, true], ["oso", 90.0, 130.0, CarCurve.ROAD_S, false],
			["tigre", 90.0, 50.0, CarCurve.ROAD_S, false],
			# en la luneta y en el maletero, la cola llegaba a medio metro de la cámara y tapaba el 93 % de la vista
			["velociraptor_pelicula", 70.0, 50.0, CarCurve.ROAD_S, true, "luneta"], ["velociraptor_pelicula", 95.0, 130.0, CarCurve.ROAD_S, false, "maletero"],
			["velociraptor", 70.0, 50.0, CarCurve.ROAD_S, true, "luneta"]]:
		var id: String = cfg[0]
		var card := _card(id)
		card.st.set_zone(String(cfg[5]) if cfg.size() > 5 else "techo")
		card.st.set_embedded(cfg[4])
		card.speed.slider.value = cfg[1]
		card.road_seg.buttons[cfg[3]].pressed.emit()
		card.radius.slider.value = CarCurve.slider_u(cfg[2])
		card.view_seg.buttons["persecucion"].pressed.emit()
		card.finish()
		await _run(card, 4)
		var view: Control = card.view
		var worst := INF
		var cover := 0.0
		for i in 90:
			await _run(card, 1, 100.0)
			if not view.holds:
				continue  # ya se ha caído: la cámara sigue al coche
			worst = minf(worst, _cam_gap(view))
			var cam: Camera3D = view._scene.chase_cam
			var box: AABB = view.animal_box()
			if box.size != Vector3.ZERO:
				var fwd := -cam.global_transform.basis.z
				var vp: Vector2 = view._scene.get_viewport().get_visible_rect().size
				cover = maxf(cover, CarScene._covers(cam.global_position, cam.global_position + fwd * 10.0, box, cam.fov, vp.x / maxf(vp.y, 1.0)))
		assert_true(worst > 0.0, "%s: la cámara fuera del animal (%s m)" % [cfg, worst])
		assert_true(cover <= CarScene.CHASE_ANIMAL_MAX + 0.02, "%s: el animal no tapa la vista (%s)" % [cfg, cover])


func test_keep_clear_saca_la_camara_de_la_caja() -> void:
	var look := Vector3(5.0, 1.4, 0.0)
	var box := AABB(Vector3(-1.0, 1.4, -0.4), Vector3(3.4, 1.2, 0.8))
	# dentro de la caja: sale por la misma recta, fuera de la caja agrandada
	var inside := Vector3(0.0, 2.0, 0.2)
	var p := CarScene.keep_clear(inside, look, box, 46.0)
	assert_false(box.grow(CarScene.CHASE_CLEAR_M).has_point(p), "fuera de la caja: %s" % p)
	assert_true(((p - look).normalized()).distance_to((inside - look).normalized()) < 1e-4, "por la misma recta")
	# lejos y pequeña: no se mueve
	var far := Vector3(-20.0, 3.0, 2.0)
	assert_eq(CarScene.keep_clear(far, look, AABB(Vector3(4.0, 1.4, -0.1), Vector3(0.2, 0.2, 0.2)), 46.0), far, "si no estorba, ni se mueve")
	# delante y grande: se aleja hasta que no ocupa más de lo que se permite
	var near := Vector3(-3.5, 2.4, 1.4)
	var q := CarScene.keep_clear(near, look, box, 46.0)
	assert_true(CarScene._covers(q, look, box, 46.0, 1.6) <= CarScene.CHASE_ANIMAL_MAX + 1e-6 or q.distance_to(look) >= near.distance_to(look) * 2.9,
		"no tapa la vista")


# ════════ Las marcas de cada garra ════════

## Las marcas del animal quieto encima en la vista: los puntos de donde salen (el principio de cada surco y el centro de cada
## huella o agujero), en el plano del daño.
static func _mark_starts(view: Control) -> Array:
	var out: Array = []
	var d: Dictionary = view._dmg_set
	for g: Dictionary in d.get("grooves", []):
		if float(g.get("t0", 0.0)) <= 0.0:
			out.append(g.a)
	for h: Dictionary in d.get("holes", []):
		out.append(h.c)
	return out


func test_las_marcas_salen_de_las_garras_en_cada_coche() -> void:
	for car: String in MCS.CARS:
		var card := _card("tigre")
		card.car_pills[car].pressed.emit()
		card.speed.slider.value = 90.0
		card.finish()
		await _run(card, 30)
		var view: Control = card.view
		var tips: Array = view._contact_tips
		var side := CarDamage.side_zone(view.hold_zone)
		assert_eq(tips.size(), int(MC.BODIES.tigre.contact), "%s: las puntas de las garras que agarran (%s)" % [car, view.hold_zone])
		var panel: Vector2 = CarShape.hold_panel(view.hold_zone, Vector2(0.0, CarShape.CAR_L))
		for t: Vector3 in tips:
			assert_true(t.x >= panel.x - 1e-6 and t.x <= panel.y + 1e-6, "%s: cada garra dentro de su panel (%s en %s)" % [car, t.x, panel])
		var starts := _mark_starts(view)
		assert_true(not starts.is_empty(), "%s: alguna marca (la huella de las garras)" % car)
		assert_true(starts.size() <= tips.size(), "%s: como mucho una marca por garra (%d)" % [car, starts.size()])
		for c: Vector2 in starts:
			var best := INF
			for t: Vector3 in tips:
				best = minf(best, c.distance_to(Vector2(t.x, t.y if side else t.z)))
			assert_true(best < 0.002, "%s: cada marca sale de una garra (a %s m)" % [car, best])
		# sin resbalar, ningún surco
		assert_true(bool(card.st.at.holds), "%s: a 90 km/h el tigre aguanta" % car)
		assert_eq((view._dmg_set.get("grooves", []) as Array).size(), 0, "%s: sin resbalar no hay surcos" % car)


func test_una_marca_por_garra_que_agarra_en_cada_animal() -> void:
	# el número de marcas es el de garras que agarran (MovingCar.BODIES: contact), el que dice la tarjeta, arriba y en un
	# costado; el velocirraptor, con los dedos III y IV (la falciforme va levantada), no con las garras de la hoz
	for id: String in ["aguila", "lechuza", "tigre", "oso", "velociraptor", "velociraptor_pelicula"]:
		var card := _card(id)
		var kind := String(MC.BODIES[id].kind)
		for zone: String in ["techo", "aleta"]:
			if not (MC.ZONES[zone].animals as Array).has(kind):
				continue
			card.st.set_zone(zone)
			card.speed.slider.value = 60.0
			card.finish()
			await _run(card, 30)
			var view: Control = card.view
			var claws := int(MC.BODIES[id].contact)
			var who := "%s en %s" % [id, zone]
			assert_eq(view._contact_tips.size(), claws, "%s: una punta por garra que agarra" % who)
			var p: Dictionary = card.st.hold_plan()
			assert_eq(int(p.prints.n), claws, "%s: la huella de cada garra" % who)
			assert_eq((view._dmg_set.get("holes", []) as Array).size(), claws, "%s: tantas huellas como garras" % who)
			assert_true(card.st.hold_plan_txt().contains("%d" % claws), "%s: el texto dice cuántas: %s" % [who, card.st.hold_plan_txt()])
			if kind == "teropodo" and not CarDamage.side_zone(zone):
				var sickle := INF
				for e: Array in view.tips_by_gap(view.hold_zone):
					sickle = minf(sickle, float(e[0]))
				var toes := INF
				for t: Array in view._rig.call("toe_points"):
					if String(t[1]) in ["III", "IV"]:
						toes = minf(toes, view._gap_of(view._rig.get("root").transform * (t[2] as Vector3), false))
				assert_true(toes < sickle, "%s: los dedos III y IV, más cerca de la chapa que la hoz levantada (%s < %s m)" % [who, toes, sickle])


func test_el_aguila_de_oro_no_raya_el_techo_en_la_curva() -> void:
	# el caso de Eric: el águila con garras de oro en la curva de 130 m a 94 km/h se agarra sin resbalar, y el lateral derecho
	# del techo salía rayado
	var card := _card("aguila")
	card.st.set_zone("techo")
	card.inlay_pills["oro"].pressed.emit()
	card.speed.slider.value = 94.0
	card.road_seg.buttons[CarCurve.ROAD_CURVE].pressed.emit()
	card.radius.slider.value = CarCurve.slider_u(130.0)
	card.finish()
	await _run(card, 40)
	var view: Control = card.view
	assert_true(bool(card.st.at.holds), "aguanta")
	var tips: Array = view._contact_tips
	var zmax := -INF
	for t: Vector3 in tips:
		zmax = maxf(zmax, t.z)
	for g: Dictionary in view._dmg_set.get("grooves", []):
		assert_true(((g.b as Vector2) - (g.a as Vector2)).length() < 0.005, "solo lo que rasca la punta doblada: %s m" % ((g.b as Vector2) - (g.a as Vector2)).length())
		assert_true(float((g.b as Vector2).y) < zmax + 0.01, "nada en el lado del techo que no toca")
	for c: Vector2 in _mark_starts(view):
		var best := INF
		for t: Vector3 in tips:
			best = minf(best, c.distance_to(Vector2(t.x, t.z)))
		assert_true(best < 0.002, "cada marca bajo una garra (a %s m)" % best)


func test_al_resbalar_un_surco_por_garra_en_la_direccion_del_resbalon() -> void:
	var card := _card("lechuza")
	card.st.set_zone("techo")
	card.finish()
	var off := float(card.st.det.kmh) + 10.0
	assert_true(is_finite(off) and off < card.st.top_kmh() and String(card.st.det.mode) == "atras", "la lechuza resbala hacia atrás (%s km/h)" % off)
	card.speed.slider.value = 60.0
	card.finish()
	await _run(card, 30)
	var view: Control = card.view
	var tips: Array = view._contact_tips.duplicate()
	assert_eq((view._dmg_set.get("grooves", []) as Array).size(), 0, "agarrada, sin surcos")
	# los surcos que deja al soltarse, con las puntas de donde estaba agarrada
	var ctx: Dictionary = view._hold_ctx.duplicate()
	card.speed.slider.value = off
	card.finish()
	ctx["speed"] = card.st.marks_now()
	ctx["plan"] = card.st.hold_plan()
	ctx["tips"] = tips
	var s := CarDamage.from_hold(card.st.scen, ctx)
	var claws := int(MC.BODIES.lechuza.contact)
	var by_claw := {}
	for g: Dictionary in s.grooves:
		by_claw[int(g.claw)] = true
		var d: Vector2 = (g.b as Vector2) - (g.a as Vector2)
		assert_true(d.x < 0.0, "hacia atrás, la dirección del resbalón")
		assert_true(absf(d.y) < absf(d.x) * 0.2, "paralelos al resbalón")
	assert_eq(by_claw.size(), claws, "un surco por garra que resbala")


func test_la_variacion_entre_garras_es_determinista_y_no_pasa_de_la_fisica() -> void:
	var top := CarShape.top_curve()
	var starts := [Vector2(2.0, -0.05), Vector2(2.0, -0.02), Vector2(2.0, 0.02), Vector2(2.0, 0.05)]
	var a := CarDamage.hold_rakes(starts, CarDamage.AXIS_TOP, 0.3, 0.0, CarShape.PANELS.techo, 1e-4, 3, 100.0, 0.3, top, "prueba")
	var b := CarDamage.hold_rakes(starts, CarDamage.AXIS_TOP, 0.3, 0.0, CarShape.PANELS.techo, 1e-4, 3, 100.0, 0.3, top, "prueba")
	assert_eq(a, b, "con la misma semilla, lo mismo")
	assert_eq(a.size(), starts.size() * 2, "dos tramos por garra")
	var lens := {}
	for k in starts.size():
		var g0: Dictionary = a[k * 2]
		var g1: Dictionary = a[k * 2 + 1]
		assert_eq(g0.a, starts[k], "sale de su garra")
		assert_true((g0.b as Vector2).distance_to(g1.a) < 1e-9, "los dos tramos, seguidos")
		var L := absf((g1.b as Vector2).x - (g0.a as Vector2).x)
		assert_true(L <= 0.3 + 1e-6 and L >= 0.3 * float(CarDamage.VARIATION.len[0]) * 0.98, "el largo, entre el 85 y el 100 %% del de la física: %s" % L)
		assert_true(float(g0.depth_um) <= 100.0 + 1e-9, "nunca más hondo que la física")
		lens[Js.to_fixed(L, 4)] = true
	assert_true(lens.size() > 1, "cada garra de la pata deja la suya")
	var c := CarDamage.hold_rakes(starts, CarDamage.AXIS_TOP, 0.3, 0.0, CarShape.PANELS.techo, 1e-4, 3, 100.0, 0.3, top, "otra")
	assert_true(c != a, "otra semilla, otra variación")
	assert_eq(CarDamage.VARIATION.quality, "juego", "marcada como juego")
	# los surcos paralelos nunca se cruzan, aunque el resbalón sea largo (1,6 m, las garras a 1-3 cm)
	var near := [Vector2(2.6, -0.03), Vector2(2.6, -0.01), Vector2(2.61, 0.0), Vector2(2.58, 0.02)]
	for seed_text: String in ["a", "b", "c", "d", "e"]:
		var r := CarDamage.hold_rakes(near, CarDamage.AXIS_TOP, 1.6, 0.0, CarShape.PANELS.techo, 1e-4, 1, 15.0, 0.3, top, seed_text)
		for i in r.size():
			for j in range(i + 1, r.size()):
				var gi: Dictionary = r[i]
				var gj: Dictionary = r[j]
				if int(gi.claw) == int(gj.claw):
					continue
				assert_true(Geometry2D.segment_intersects_segment(gi.a, gi.b, gj.a, gj.b) == null,
					"%s: los surcos de las garras %d y %d no se cruzan" % [seed_text, gi.claw, gj.claw])
	# el ancho a lo largo del sombreador: la parte del surco entero de cada tramo
	assert_near(CarDamage.shape_code({ "t0": 0.0, "t1": 1.0 }), 31.0 / 2048.0, 1e-12, 0.0, "un tramo entero")
	assert_true(CarDamage.shape_code({ "t0": 1.0, "t1": 1.0 }) < 0.5, "el número del golpe sigue siendo la parte entera")


# ════════ Garras dobladas y melladas, de una pieza ════════

## La mayor distancia (m) de un vértice del anillo del corte de la punta al anillo del corte de la base (en el mundo): 0 si la
## punta sigue pegada a la base. -1 si alguna pieza no tiene anillo en el corte.
static func _seam_gap(mb: MeshInstance3D, mt: MeshInstance3D, s_cut: float) -> float:
	var ring := func(mi: MeshInstance3D) -> Array:
		var out: Array = []
		var arr := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in vs.size():
			if absf(uvs[i].x - s_cut) < 1e-3:
				out.append(mi.global_transform * vs[i])
		return out
	var rb: Array = ring.call(mb)
	var rt: Array = ring.call(mt)
	if rb.is_empty() or rt.is_empty():
		return -1.0
	var worst := 0.0
	for p: Vector3 in rt:
		var best := INF
		for q: Vector3 in rb:
			best = minf(best, p.distance_to(q))
		worst = maxf(worst, best)
	return worst


## Las aristas de una malla que no comparten dos triángulos (con los vértices soldados por su posición): 0 si está cerrada.
static func _open_edges(mi: MeshInstance3D) -> int:
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var key := func(v: Vector3) -> String: return "%d,%d,%d" % [roundi(v.x * 1e4), roundi(v.y * 1e4), roundi(v.z * 1e4)]
	var count := {}
	for t in idx.size() / 3:
		for e: Array in [[0, 1], [1, 2], [2, 0]]:
			var a: String = key.call(vs[idx[t * 3 + e[0]]])
			var b: String = key.call(vs[idx[t * 3 + e[1]]])
			if a == b:
				continue
			var k := a + "|" + b if a < b else b + "|" + a
			count[k] = int(count.get(k, 0)) + 1
	var open := 0
	for k: String in count:
		if int(count[k]) == 1:
			open += 1
	return open


func test_las_garras_dobladas_o_melladas_son_una_malla_continua() -> void:
	for cfg: Array in [["velociraptor_pelicula", "tumbado", Vector3(0.87, 3.4, 0.0), true], ["velociraptor", "tumbado", Vector3(0.5, 2.07, 0.0), true],
			["tigre", "tumbado", Vector3(1.0, 1.9, 0.0), true], ["aguila", "plegadas", Vector3(0.8, 0.85, 1.9), true],
			["velociraptor_pelicula", "tumbado", Vector3(0.87, 3.4, 0.0), false], ["aguila", "abiertas", Vector3(0.8, 0.85, 1.9), false]]:
		var hd: bool = cfg[3]
		var a: RefCounted = HdAnimal.build(cfg[0], cfg[1], cfg[2], { "cache": {} }) if hd else Animal3D.build(cfg[0], cfg[1], cfg[2], { "cache": {} })
		var root: Node3D = a.get("root")
		add_to_tree(root)
		var who := "%s %s (%s)" % [cfg[0], cfg[1], "alta definición" if hd else "4l"]
		for state: Dictionary in [{ "claw_len": 0.85 }, { "claw_len": 0.5 }, { "claw_bend": 1.0, "claw_bend_frac": 0.2 }, {}]:
			a.call("pose", { "t": 0.0, "claws_out": 1.0, "claw_len": float(state.get("claw_len", 1.0)), "claw_bend": float(state.get("claw_bend", 0.0)),
				"claw_bend_frac": float(state.get("claw_bend_frac", 0.15)) })
			var checked := 0
			for c: Dictionary in a.get("claws"):
				var g: Dictionary = c.get("geo", {})
				if g.is_empty():
					continue
				var mb: MeshInstance3D = (c.meshes as Array)[0] if hd else Animal3D._claw_mesh_node(c.node)
				var mt: MeshInstance3D = (c.meshes as Array)[1] if hd else Animal3D._claw_mesh_node(c.tip)
				var s_cut := float(g.length) * 0.6
				var tip_on := (c.tip as Node3D).visible
				if tip_on:
					var gap := _seam_gap(mb, mt, s_cut)
					var size := float(g.length) * (0.001 if hd else 0.01)
					assert_true(gap >= 0.0 and gap < size * 1e-3, "%s %s: la punta pegada a la base (hueco %s m)" % [who, state, gap])
				if float(state.get("claw_len", 1.0)) < 0.97:
					var piece := mt if tip_on else mb
					var open := _open_edges(piece)
					assert_true(open <= (0 if not tip_on else 64), "%s %s: la rotura cerrada (%d aristas abiertas)" % [who, state, open])
				checked += 1
			assert_true(checked > 0, "%s: garras comprobadas" % who)
		a.call("free_nodes")


func test_las_garras_de_cada_material_son_de_una_pieza_en_la_vista() -> void:
	# los materiales de la tarjeta (la queratina y los del catálogo) en el velocirraptor de cine a 200 km/h, en la vista de las
	# garras de cerca: la que se dobla o se mella sigue siendo una pieza (la punta pegada a la base; la rotura, cerrada)
	var card := _card("velociraptor_pelicula")
	card.st.set_zone("techo")
	card.speed.slider.value = 200.0
	card.view_seg.buttons["lado"].pressed.emit()
	card.zoom_seg.buttons["garras"].pressed.emit()
	card.finish()
	var states := {}
	var n := 0
	for id: String in card.inlay_pills:
		card.inlay_pills[id].pressed.emit()
		card.finish()
		await _run(card, 12)
		var view: Control = card.view
		var rig: RefCounted = view._rig
		assert_true(rig != null and rig.get_script() == HdAnimal, "%s: el animal de alta definición" % id)
		var pose: Dictionary = view._pose
		var keep := float(pose.get("claw_len", 1.0))
		var state := "entera"
		if bool(pose.get("claw_gone", false)):
			state = "partida"
		elif keep < 0.97:
			state = "mellada"
		elif float(pose.get("claw_bend", 0.0)) > 0.5:
			state = "doblada"
		states[state] = true
		for c: Dictionary in rig.get("claws"):
			var g: Dictionary = c.get("geo", {})
			var mb: MeshInstance3D = (c.meshes as Array)[0]
			var mt: MeshInstance3D = (c.meshes as Array)[1]
			if not (c.node as Node3D).visible:
				continue
			if (c.tip as Node3D).visible:
				var gap := _seam_gap(mb, mt, float(g.length) * HdAnimal.CLAW_CUT)
				assert_true(gap >= 0.0 and gap < float(g.length) * 1e-6, "%s (%s): la punta pegada a la base (hueco %s m)" % [id, state, gap])
			elif keep < 0.97:
				assert_eq(_open_edges(mb), 0, "%s (%s): la rotura cerrada" % [id, state])
			n += 1
	assert_true(n > 0, "garras comprobadas")
	assert_true(states.size() >= 3, "entera, doblada y mellada entre los materiales: %s" % [states.keys()])
