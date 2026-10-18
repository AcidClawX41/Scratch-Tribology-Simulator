## El punto del golpe en la ventanilla (unidad 4m) cae en la ventanilla que estalla del dibujo: IMPACT_ZONES.luna.draw está
## dentro de la luna delantera de la vista (CarShape.side_windows()[0]), la que golpea (MovingCar.WINDOW_PANE). Y la vista lo
## usa: toma el punto de la zona del golpe (zone_draw), trata la ventanilla como un costado (CarDamage.side_zone) y le da su
## tramo de la silueta (CarShape.PANELS); los demás golpes caen donde siempre.
extends "res://tests/case.gd"

const MC = preload("res://core/lab/moving_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const View = preload("res://app/lab/moving_car_view.gd")


func test_el_punto_del_golpe_esta_en_la_ventanilla_que_golpea() -> void:
	var d: Dictionary = MC.IMPACT_ZONES[MC.WINDOW_ZONE].draw
	var w := Vector2(CarShape.CAR_L * (1.0 - float(d.x)), CarShape.CAR_H * float(d.y))
	var panes: Array = CarShape.side_windows()
	assert_eq(panes.size(), 2, "dos ventanillas: delantera y trasera")
	var i := 0 if MC.WINDOW_PANE == "front" else 1
	assert_true(Geometry2D.is_point_in_polygon(w, panes[i]), "el punto %s, dentro de la ventanilla %s" % [w, MC.WINDOW_PANE])
	assert_false(Geometry2D.is_point_in_polygon(w, panes[1 - i]), "y no en la otra")


func test_la_vista_golpea_el_cristal_y_no_la_puerta() -> void:
	var zone: String = MC.WINDOW_ZONE
	var d: Dictionary = MC.IMPACT_ZONES[zone].draw
	assert_eq(View.zone_draw(zone), d, "el punto de la zona del golpe")
	assert_true(CarDamage.side_zone(zone), "un costado")
	var top := CarShape.top_curve()
	var p := CarDamage.impact_point(zone, d, top)
	assert_near(p.z, CarShape.HALF_W, 1e-6, 1e-6, "en la cara del costado (Vector3, en coma flotante de 32 bits)")
	var pane: PackedVector2Array = CarShape.side_windows()[0]
	assert_true(Geometry2D.is_point_in_polygon(Vector2(p.x, p.y), pane), "en el cristal de la ventanilla delantera: %s" % p)
	var door := CarDamage.impact_point("puerta", View.zone_draw("puerta"), top)
	assert_false(Geometry2D.is_point_in_polygon(Vector2(door.x, door.y), pane), "el de la puerta, no")
	assert_true(p.y > door.y, "por encima del golpe en la puerta")
	# su tramo: dentro de la ventanilla delantera, con el punto del golpe
	var span: Vector2 = CarShape.PANELS[zone]
	var lo := INF
	var hi := -INF
	for q: Vector2 in pane:
		lo = minf(lo, q.x)
		hi = maxf(hi, q.x)
	assert_true(span.x >= lo - 1e-6 and span.y <= hi + 1e-6, "dentro de la ventanilla (%s; de %s a %s)" % [span, lo, hi])
	assert_true(p.x > span.x and p.x < span.y, "con el punto del golpe dentro")
	# los demás golpes no se mueven: el punto de su zona de siempre (MovingCar.ZONES) o, en la puerta, DOOR_DRAW
	for z: String in MC.IMPACT_ZONES:
		if z == zone:
			continue
		var zd: Variant = MC.ZONES.get(z)
		assert_eq(View.zone_draw(z), zd.draw if zd != null else null, "%s: el punto de siempre" % z)
	assert_true(CarDamage.side_zone("puerta") and CarDamage.side_zone("aleta"), "la puerta y la aleta, costados")
	for z: String in ["capo", "techo", "parabrisas"]:
		assert_false(CarDamage.side_zone(z), "%s: arriba" % z)
	# los daños de una ventanilla que estalla: la delantera, con el golpe en el cristal (también los que se acumulan desplazados)
	var car: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "coche")
	var r := MC.impact({ "claw": Catalog.find_by_id(Catalog.CLAWS, "oso"), "target": car, "zone": zone, "v_kmh": 50.0,
		"animal_kmh": 10.0, "angle_deg": 90.0 })
	assert_true(r.sideWindow.shattered, "el oso a 10 km/h la revienta")
	for shift: Vector2 in View.DMG_SHIFTS:
		var s := CarDamage.from_hit(r, { "zone": zone, "draw": View.zone_draw(zone), "target": car, "kind": "mamifero", "kicker": false,
			"size": Vector3(1.2, 2.0, 0.0), "claws": 10, "contact_mm": 65.0, "dir": -1.0, "hit": 1, "shift": shift, "top": top,
			"claw_id": "oso", "glass": true })
		assert_eq(float(s.shatter.front), 1.0, "estalla la delantera")
		var f: Vector3 = s.focus
		assert_true(Geometry2D.is_point_in_polygon(Vector2(f.x, f.y), pane), "el golpe %s, en el cristal: %s" % [shift, f])
		assert_near(f.z, CarShape.HALF_W, 1e-6, 1e-6, "en el costado")
