## Las garras en los cristales del coche, en la vista (unidad 4v): la luneta donde se queda el animal (en la silueta y con su
## panel), el parabrisas que se agrieta bajo el animal dibujado como lo cuenta la estimación de lo que tapa al conductor, la
## luneta templada que estalla (en las lunas y con los trocitos dentro, que se crean una vez), el corte del vidrio y que en
## cada fotograma no se crea nada mientras estalla.
extends "res://tests/case.gd"

const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const CarModel = preload("res://app/lab/car3d/car_model.gd")
const LayerCut = preload("res://app/lab/car3d/layer_cut.gd")
const View = preload("res://app/lab/moving_car_view.gd")
const Card = preload("res://app/lab/moving_car_card.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const CarGlass = preload("res://core/lab/car_glass.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func _st(id: String, zone: String, inlay: String, v: float, defense := false) -> MCS:
	var st := MCS.new(C(id), Catalog.find_by_id(Catalog.TARGETS, "coche"))
	st.threaded = false
	st.set_zone(zone)
	st.set_inlay(inlay)
	st.set_defense(defense)
	st.set_speed(v)
	st.finish()
	return st


## Lo que car_damage.gd necesita del animal quieto encima, como lo arma la vista (sin las puntas de las garras).
static func _ctx(st: MCS) -> Dictionary:
	var body: Dictionary = MC.BODIES[st.claw.id]
	var d: Dictionary = st.scen.draw
	var w := View.draw_to_world(Vector2(d.x, d.y))
	return { "zone": st.zone, "draw": MC.ZONES[st.zone].draw, "target": st.target, "kind": st.kind(), "kicker": false,
		"size": Vector3(body.height_m, body.length_m, 0.0), "claws": int(body.get("contact", 4)), "contact_mm": float(body.contact_mm),
		"dir": -1.0, "hit": 0, "top": CarShape.top_curve(), "claw_id": st.claw.id, "glass": View.glass_zone(st.zone),
		"feet": Vector3(w.x, CurveKit.top_y(CarShape.top_curve(), w.x), 0.0), "speed": st.marks_now() }


func test_la_luneta_en_la_silueta() -> void:
	var d: Dictionary = MC.ZONES.luneta.draw
	var w := View.draw_to_world(Vector2(d.x, d.y))
	var y := CurveKit.top_y(CarShape.top_curve(), w.x)
	assert_true(absf(y - w.y) < 0.04, "el punto de la luneta (%s, %s) está en la silueta (y = %s)" % [w.x, w.y, y])
	assert_true(w.x > CarShape.LUNETA_PANEL.x and w.x < CarShape.LUNETA_PANEL.y, "y dentro de su panel")
	assert_true(CarShape.ZONE_Z.has("luneta"), "con su z")
	assert_eq(CarShape.hold_panel("luneta", Vector2.ZERO), CarShape.LUNETA_PANEL, "el panel de la luneta")
	assert_eq(CarShape.hold_panel("techo", Vector2.ZERO), CarShape.PANELS.techo, "los demás, los de siempre")
	assert_true(View.glass_zone("luneta") and View.glass_zone("parabrisas") and View.glass_zone("luna"), "los cristales")
	assert_false(View.glass_zone("techo") or View.glass_zone("ventanilla"), "la chapa y el borde de la ventanilla, no")


func test_el_parabrisas_agrietado_como_lo_que_tapa() -> void:
	# el oso de pie lo parte con su peso: una estrella del radio de la estimación bajo cada apoyo
	var bear := _st("oso", "parabrisas", "none", 30.0)
	var s := CarDamage.from_hold(bear.scen, _ctx(bear))
	assert_eq(String(bear.scen.windshield.viewLoss.cause), "flexión", "lo parte el peso")
	assert_eq(s.cracks.size(), 4, "una estrella por pata")
	for c: Dictionary in s.cracks:
		assert_near(float(c.r), CarGlass.STAR_RADIUS_M, 1e-9, 0.0, "del radio de la estimación")
	# el águila con garras de diamante lo agrieta al apoyarse: estrellas pequeñas donde tocan, y sus surcos en el vidrio
	var eagle := _st("aguila", "parabrisas", "diamante", 60.0)
	var e := CarDamage.from_hold(eagle.scen, _ctx(eagle))
	assert_eq(String(eagle.scen.windshield.viewLoss.cause), "grieta", "lo agrietan las garras")
	assert_true(e.cracks.size() >= 1 and e.cracks.size() <= CarDamage.MAX_CRACKS, "unas estrellas pequeñas")
	for c: Dictionary in e.cracks:
		assert_near(float(c.r), CarDamage.CLAW_CRACK_R, 1e-9, 0.0, "del ancho de la franja")
	assert_true(e.grooves.size() > 0, "los surcos del diamante en el vidrio")
	for g: Dictionary in e.grooves:
		assert_eq(int(g.layer), 0, "claros, como los pinta el shader de las lunas")
	# la queratina no raya
	assert_eq(s.grooves.size(), 0, "la queratina del oso no raya el vidrio")


func test_la_luneta_que_estalla() -> void:
	var tiger := _st("tigre", "luneta", "cuarzo", 0.0)
	var s := CarDamage.from_hold(tiger.scen, _ctx(tiger))
	assert_eq(float(s.shatter.luneta), 1.0, "estalla la luneta")
	assert_near(float(s.shatter.frag_m), float(tiger.scen.rearWindow.fragmentMm) / 1000.0, 1e-9, 0.0, "en trozos de fragmentMm")
	assert_eq(float(s.shatter.front) + float(s.shatter.rear), 0.0, "las ventanillas, enteras")
	var whole := _st("tigre", "luneta", "none", 60.0)
	assert_eq(float(CarDamage.from_hold(whole.scen, _ctx(whole)).shatter.get("luneta", 0.0)), 0.0, "con queratina, entera")
	assert_eq(float(CarDamage.merge(CarDamage.empty(), s).shatter.luneta), 1.0, "la mezcla la conserva")
	var root := Node3D.new()
	var car := CarModel.new()
	car.build(root, Color(0.5, 0.2, 0.2), true)
	car.set_damage(s)
	assert_eq(car.glass.get_shader_parameter("shatter_luneta"), 1.0, "las lunas lo saben")
	var nodes := car.nodes
	car.luneta_shards_start(0.0056, "prueba")
	car.shatter_step(1.0, 0.0)
	car.luneta_shards_start(0.0056, "prueba")
	assert_eq(car.nodes, nodes + 1, "los trocitos se crean una vez y se reutilizan")
	car.shatter_step(CarModel.SHARD_S + 1.0, 30.0)
	assert_true(car.shards.visible, "dentro del coche se quedan")
	# (sin servidor de render de verdad no se pueden leer las transformaciones del MultiMesh: se miran sus datos)
	assert_near(car.shard_floor, CarModel.LUNETA_FLOOR, 1e-9, 0.0, "caen a la banqueta de atrás")
	var p0: Vector3 = car.get("_shard_p0")[0]
	assert_true(p0.x >= CarShape.LUNETA_PANEL.x - 1e-6 and p0.x <= CarShape.LUNETA_PANEL.y + 1e-6, "salen de la luneta (%s m)" % p0.x)
	assert_true(absf(p0.z) <= CarShape.LUNETA_HW + 1e-6, "dentro de su ancho")
	car.shatter_start(0, 0.0056, "ventanilla")
	car.shatter_step(CarModel.SHARD_S, 1.0)
	assert_false(car.shards.visible, "los de la ventanilla del golpe, a la carretera y se esconden, como antes")
	root.free()


func test_el_corte_del_vidrio() -> void:
	for id: String in ["mancha", "raya_vidrio", "agrieta", "estalla"]:
		assert_true(LayerCut.GLASS_TITLES.has(id), "el corte tiene título para «%s»" % id)
	var lam := CarGlass.cutaway("laminado", 6.0, false, false, {})
	assert_eq(lam.size(), 3, "vidrio, PVB y vidrio")
	assert_eq(String(lam[0].state), "marcada", "el surco en el vidrio de fuera")
	var temp := CarGlass.cutaway("templado", 0.0, false, true, CarGlass.REAR_WINDOW_PANE)
	for l: Dictionary in temp:
		assert_eq(String(l.state), "estallada", "el templado, todo o nada")


func test_en_cada_fotograma_no_se_crea_nada_mientras_estalla() -> void:
	var host := Control.new()
	host.size = Vector2(700, 1400)
	add_to_tree(host)
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = false
	lab.set_claw(C("tigre"))
	card.refresh()
	card.finish()
	card.size = Vector2(680, 0)
	host.add_child(card)
	card.st.set_inlay("cuarzo")
	card.st.set_zone("luneta")
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	var view: View = card.view
	assert_true(view.glass_note.begins_with("Estalla la luneta"), "el rótulo de la vista")
	var scene: Node3D = view.get("_scene")
	var nodes := scene.find_children("*", "", true, false).size()
	var builds: int = view.builds
	for i in 20:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(scene.find_children("*", "", true, false).size(), nodes, "sin nodos nuevos mientras estalla")
	assert_eq(view.builds, builds, "sin geometría nueva")
	assert_true(float(scene.get("car").glass.get_shader_parameter("shatter_luneta")) > 0.0, "la luneta estalla en las lunas")
