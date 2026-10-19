## El coche en marcha en 3D (unidad 4k: app/lab/car3d/ y moving_car_view.gd). Se comprueba:
##   - que la silueta pasa por los puntos de la física (los draw de MovingCar.ZONES, la parte de arriba TOP con la que la
##     vista apoya el animal, surface_y, y los paneles del golpe PANELS y DOOR_DRAW, que no se mueven);
##   - que la malla no tiene huecos (el canto cabe en cada esquina y las ventanillas caben en la cabina);
##   - que los daños salen de impact() y hold_report() a su escala real (cuántos surcos, su largo y su ancho, la capa a la
##     que llegan, los agujeros, las abolladuras y las grietas);
##   - que el viento sale de la física (v·√(1 − Cp) de cada zona, a través del estado), que no hay a 0 km/h ni con
##     movimiento reducido y que en el teléfono hay menos partículas;
##   - que los daños se acumulan en el ensayo y se borran al cambiar de ensayo, y que en cada fotograma no se crea nada;
##   - que se dibujan los dos velocirraptores (4i-B2), cada uno con su variante y su tamaño, que llegan al panel de arriba
##     con su salto y que el de cine raja el capó.
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const MeshKit = preload("res://app/lab/car3d/mesh_kit.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const CarModel = preload("res://app/lab/car3d/car_model.gd")
const AirFlow = preload("res://app/lab/car3d/air_flow.gd")
const View = preload("res://app/lab/moving_car_view.gd")
const Card = preload("res://app/lab/moving_car_card.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5


## El contorno de dentro de un prisma (sin su canto), como lo hace MeshKit.prism.
static func inner_of(outline: PackedVector2Array, r: PackedFloat32Array) -> PackedVector2Array:
	var poly := MeshKit.ccw(outline)
	var radii := r.duplicate()
	if poly != outline:
		radii.reverse()
	radii = MeshKit.safe_radii(poly, radii)
	var miter: PackedVector2Array = MeshKit.normals(poly)[1]
	var inner := PackedVector2Array()
	for i in poly.size():
		inner.append(poly[i] - miter[i] * radii[i])
	return inner


## Un golpe en el acto (sin hilos).
static func strike(claw: String, car: String, zone: String, v: float, va: float, angle: float, drop: float, inlay := "none") -> MCS:
	var st := MCS.new(C(claw), T(car))
	st.threaded = false
	st.set_mode(MCS.MODE_IMPACT)
	st.set_impact_zone(zone)
	st.set_inlay(inlay)
	st.set_speed(v)
	st.set_impact("animal_kmh", va)
	st.set_impact("angle_deg", angle)
	st.set_impact("drop_m", drop)
	st.finish()
	return st


## Lo que car_damage.gd necesita del ensayo, como lo arma la vista.
static func ctx(st: MCS, zone: String) -> Dictionary:
	var body: Dictionary = MC.BODIES[st.claw.id]
	var zd: Variant = MC.ZONES.get(zone)
	return { "zone": zone, "draw": zd.draw if zd != null else null, "target": st.target, "kind": st.kind(), "kicker": st.is_kicker(),
		"size": Vector3(body.height_m, body.length_m, 0.0), "claws": int(body.get("contact", 4)),
		"contact_mm": float(body.get("contact_mm", CarDamage.DEFAULT_CONTACT_MM)), "dir": -1.0, "hit": 1, "top": CarShape.top_curve(),
		"claw_id": st.claw.id, "glass": bool(MC.IMPACT_ZONES[zone].glass) if MC.IMPACT_ZONES.has(zone) else false }


## Una tarjeta con su banco, en el árbol, con un animal y lo caro sin hilos.
func _card(claw_id: String, width := 680.0) -> Control:
	var host := Control.new()
	host.size = Vector2(width + 20.0, 1400)
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


# ════════ La silueta ════════

func test_la_silueta_pasa_por_los_puntos_de_la_fisica() -> void:
	var top := CarShape.top_curve()
	for id: String in MC.ZONES:
		var d: Dictionary = MC.ZONES[id].draw
		var w := View.draw_to_world(Vector2(d.x, d.y))
		assert_true(CarShape.ZONE_Z.has(id), "la zona «%s» tiene su z en el dibujo" % id)
		match id:
			"capo", "limpiaparabrisas", "parabrisas", "techo", "maletero":
				var y := CurveKit.top_y(top, w.x)
				assert_true(absf(y - w.y) < 0.04, "«%s»: el punto (%s, %s) está en la silueta (y = %s)" % [id, w.x, w.y, y])
			"barras":
				assert_true(absf(CarShape.BAR_Y - w.y) < 0.02 and w.x > float(CarShape.BAR_X[0]) and w.x < float(CarShape.BAR_X[1]),
					"las barras pasan por su punto")
			"antena":
				assert_true((CarShape.ANTENNA[1] as Vector2).distance_to(w) < 0.01, "la punta de la antena está en su punto")
			"retrovisor":
				var box := CurveKit.bounds_of(PackedVector2Array(CarShape.MIRROR)).grow(0.02)
				assert_true(box.has_point(w), "el retrovisor está en su punto")
				assert_true(float(CarShape.ZONE_Z[id]) > CarShape.MIRROR_Z.x and float(CarShape.ZONE_Z[id]) < CarShape.MIRROR_Z.y, "y sobresale del costado")
			"ventanilla":
				var near := INF
				for win: PackedVector2Array in CarShape.side_windows():
					for i in win.size():
						near = minf(near, Geometry2D.get_closest_point_to_segment(w, win[i], win[(i + 1) % win.size()]).distance_to(w))
				assert_true(near < 0.06, "el borde de la ventanilla está junto a su punto (%s m)" % near)
			"aleta":
				assert_true(w.y > CarShape.arch_top(w.x) and w.y < CurveKit.top_y(top, w.x), "la aleta: en la chapa del costado, entre el paso de rueda y el capó")
				assert_true(w.x > (CarShape.PANELS.aleta as Vector2).x and w.x < (CarShape.PANELS.aleta as Vector2).y, "y dentro de su panel")


func test_la_parte_de_arriba_y_los_paneles_no_se_mueven() -> void:
	# la curva de arriba (surface_y de la vista) pasa por los puntos de siempre de TOP
	var top := CarShape.top_curve()
	for i in CarShape.TOP.size():
		var p: Vector2 = CarShape.TOP[i]
		if p.x <= 0.0 or p.x >= CarShape.CAR_L or i >= 22:
			continue
		var y := CurveKit.top_y(top, p.x)
		assert_true(y >= p.y - 1e-6, "TOP[%d] (%s) está en la curva de arriba (o debajo de otro tramo más alto): %s" % [i, p, y])
	for k in [9, 10, 11, 12, 13]:
		var p: Vector2 = CarShape.TOP[k]
		assert_near(CurveKit.top_y(top, p.x), p.y, 1e-6, 1e-6, "el techo pasa por TOP[%d]" % k)
	assert_eq(CarShape.PANELS, { "capo": Vector2(3.15, 4.40), "techo": Vector2(1.44, 2.52), "parabrisas": Vector2(2.52, 3.15),
		"puerta": Vector2(1.36, 3.10), "aleta": Vector2(3.10, 4.30), "maletero": Vector2(0.10, 1.00), "luna": Vector2(2.27, 2.90) },
		"los paneles del golpe (y la ventanilla de la unidad 4m)")
	assert_eq(CarShape.DOOR_DRAW, Vector2(0.48, 0.42), "el golpe en la puerta")
	assert_eq(View.PANELS, CarShape.PANELS, "la vista usa los mismos paneles")
	assert_eq(View.DOOR_DRAW, CarShape.DOOR_DRAW, "y el mismo punto de la puerta")
	for x: float in [(CarShape.PANELS.puerta as Vector2).x, (CarShape.PANELS.puerta as Vector2).y]:
		var near := INF
		for sx: float in CarShape.SEAMS_X:
			near = minf(near, absf(sx - x))
		assert_true(near < 1e-5, "la junta de la puerta en el borde de su panel (%s)" % x)


func test_la_malla_no_tiene_huecos() -> void:
	var bo: Array = CarShape.body_outline()
	var poly := MeshKit.ccw(bo[0])
	var radii: PackedFloat32Array = (bo[2] as PackedFloat32Array).duplicate()
	if poly != bo[0]:
		radii.reverse()
	radii = MeshKit.safe_radii(poly, radii)
	var miter: PackedVector2Array = MeshKit.normals(poly)[1]
	var inner := PackedVector2Array()
	for i in poly.size():
		inner.append(poly[i] - miter[i] * radii[i])
	var n := inner.size()
	var crossings := 0
	for i in n:
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			if Geometry2D.segment_intersects_segment(inner[i], inner[(i + 1) % n], inner[j], inner[(j + 1) % n]) != null:
				crossings += 1
	assert_eq(crossings, 0, "el contorno de dentro del costado no se cruza (el canto cabe en cada esquina)")
	for tess: float in [0.05, 0.08]:
		var t: Array = MeshKit.tessellate(inner, tess)
		var pts: PackedVector2Array = t[0]
		var tris: PackedInt32Array = t[1]
		var sum := 0.0
		for k in range(0, tris.size(), 3):
			sum += area(PackedVector2Array([pts[tris[k]], pts[tris[k + 1]], pts[tris[k + 2]]]))
		assert_near(sum, area(inner), 2e-3, 0.0, "la rejilla de %s m cubre el costado entero" % tess)
	# las ventanillas, con su marco, caben en el costado de la cabina (sin su canto)
	var co: Array = CarShape.cabin_outline()
	var cabin: Array = [inner_of(co[0], co[2])]
	var wins: Array = CarShape.side_windows()
	assert_eq(wins.size(), 2, "dos ventanillas")
	for w: PackedVector2Array in wins:
		assert_true(w.size() >= 3 and area(w) > 0.1, "una ventanilla de verdad (%s m²)" % area(w))
		var grown: Array = Geometry2D.offset_polygon(w, CarShape.FRAME_W)
		var out := 0.0
		for piece: PackedVector2Array in Geometry2D.clip_polygons(grown[0], cabin[0]):
			out += area(piece)
		assert_true(out < 1e-4, "la ventanilla y su marco caben en la cabina (fuera: %s m²)" % out)


func test_cada_carroceria_tiene_su_aspecto() -> void:
	for id: String in MCS.CARS:
		assert_true(CarModel.STYLES.has(id), "aspecto para «%s»" % id)
	assert_true(bool(CarModel.STYLES.cocheclasico.classic) and float(CarModel.STYLES.cocheclasico.metallic) == 0.0, "el clásico: cromados y pintura sólida")
	assert_true(bool(CarModel.STYLES.cocheplastico.plastic), "el de plástico: aleta y paragolpes de termoplástico")
	var root := Node3D.new()
	var car := CarModel.new()
	car.build(root, Color(0.5, 0.2, 0.2), true)
	assert_true(car.triangles > 5000, "un coche de verdad (%d triángulos)" % car.triangles)
	car.set_style("cocheclasico")
	assert_true(car.classic_parts.visible, "con el clásico se ven los cromados")
	assert_true((car.wheels[0].cap as Node3D).visible and not (car.wheels[0].alloy as Node3D).visible, "y los tapacubos")
	car.set_style("cocheplastico")
	assert_false(car.classic_parts.visible, "con los demás, no")
	assert_eq(car.paint.get_shader_parameter("plastic_parts"), 1.0, "la aleta y los paragolpes de plástico")
	root.free()


# ════════ Los daños ════════

func test_los_surcos_y_la_abolladura_a_su_escala() -> void:
	var st := strike("tigre", "coche", "puerta", 50.0, 40.0, 90.0, 0.5)
	var h: Dictionary = st.hit
	var s := CarDamage.from_hit(h, ctx(st, "puerta"))
	assert_eq(s.grooves.size(), int(h.marks.count), "un surco por garra (marks.count)")
	for g: Dictionary in s.grooves:
		assert_near(absf(g.b.x - g.a.x), float(h.marks.lengthMm) / 1000.0, 0.08, 0.0, "cada surco mide marks.lengthMm (%s)" % absf(g.b.x - g.a.x))
		assert_near(float(g.hw), float(h.marks.widthUm) / 2.0e6, 1e-9, 0.0, "y marks.widthUm de ancho")
		assert_eq(int(g.layer), CarDamage.LAYER_BODY, "la queratina llega al metal sin atravesarlo")
		assert_eq(int(g.axis), CarDamage.AXIS_SIDE, "en el costado")
	assert_eq(s.dents.size(), int(h.dent.patches), "una abolladura por apoyo (dent.patches)")
	for d: Dictionary in s.dents:
		assert_near(float(d.depth), float(h.dent.depthMm) / 1000.0, 1e-9, 0.0, "hundida dent.depthMm")
		assert_true(float(d.r) >= float(d.depth) * CarDamage.DENT_SPREAD - 1e-9, "con el borde más ancho que hondo")
	assert_eq(s.holes.size(), 0, "la queratina no perfora la chapa")


func test_el_tajo_de_zafiro_y_sus_petalos() -> void:
	var st := strike("tigre", "coche", "puerta", 50.0, 40.0, 90.0, 0.5, "zafiro")
	var h: Dictionary = st.hit
	assert_true(h.puncture.through, "las garras de zafiro atraviesan la chapa")
	var s := CarDamage.from_hit(h, ctx(st, "puerta"))
	for g: Dictionary in s.grooves:
		assert_eq(int(g.layer), CarDamage.LAYER_THROUGH, "el tajo atraviesa la chapa (%s µm > pintura y chapa)" % h.marks.depthUm)
	assert_eq(s.holes.size(), s.grooves.size(), "un agujero donde entra cada garra")
	for hole: Dictionary in s.holes:
		assert_near(float(hole.r), float(h.puncture.holeUm) / 2.0e6, 1e-9, 0.0, "de puncture.holeUm de diámetro")
		assert_eq(int(hole.petals), CarDamage.PETALS, "la chapa se abre en pétalos")


func test_las_ranuras_del_plastico() -> void:
	var st := strike("tigre", "cocheplastico", "aleta", 50.0, 40.0, 90.0, 0.0)
	var h: Dictionary = st.hit
	assert_true(h.tear != null and h.tear.applies, "las garras trabadas rajan la aleta (4g)")
	var s := CarDamage.from_hit(h, ctx(st, "aleta"))
	assert_eq(s.grooves.size(), int(h.marks.count), "una ranura por garra")
	var panel: Vector2 = CarShape.PANELS.aleta
	for g: Dictionary in s.grooves:
		assert_eq(int(g.layer), CarDamage.LAYER_THROUGH, "de lado a lado")
		assert_near(float(g.hw), float(h.marks.widthUm) / 2.0e6, 1e-9, 0.0, "del ancho del agujero")
		assert_near(absf(g.b.x - g.a.x), minf(float(h.tear.lengthMm) / 1000.0, g.a.x - panel.x), 1e-6, 1e-6, "lo que raja (tear.lengthMm), sin pasar de la aleta")
		assert_true(g.a.y - g.hw > CarShape.arch_top(g.a.x) and g.b.y - g.hw > CarShape.arch_top(g.b.x), "por encima del paso de rueda")
	for hole: Dictionary in s.holes:
		assert_eq(int(hole.petals), 0, "el termoplástico no se abre en pétalos: se desgarra")


func test_el_parabrisas_y_el_techo() -> void:
	var st := strike("tigre", "coche", "parabrisas", 50.0, 40.0, 90.0, 0.5)
	var s := CarDamage.from_hit(st.hit, ctx(st, "parabrisas"))
	assert_true(st.hit.windshield.cracked, "el laminado se agrieta")
	assert_true(s.cracks.size() >= 1, "una estrella de grietas bajo cada apoyo")
	assert_eq(s.grooves.size(), 0, "la queratina no raya el vidrio")
	var hard := strike("tigre", "coche", "parabrisas", 50.0, 40.0, 90.0, 0.5, "diamante")
	var sh := CarDamage.from_hit(hard.hit, ctx(hard, "parabrisas"))
	assert_eq(sh.grooves.size(), int(hard.hit.marks.count), "unas garras de diamante sí rayan el vidrio")
	# el águila que se posa en el techo: surcos hasta el metal, por el techo dibujado
	var eagle := strike("aguila", "coche", "techo", 90.0, 60.0, 0.0, 0.2)
	var se := CarDamage.from_hit(eagle.hit, ctx(eagle, "techo"))
	assert_eq(se.grooves.size(), int(eagle.hit.marks.count), "un surco por talón")
	var roof: Vector2 = CarShape.PANELS.techo
	for g: Dictionary in se.grooves:
		assert_eq(int(g.axis), CarDamage.AXIS_TOP, "arriba")
		assert_true(g.b.x >= roof.x - 1e-6, "sin pasar del techo")
	assert_near(float(se.dents[0].depth), float(eagle.hit.dent.depthMm) / 1000.0, 1e-9, 0.0, "la abolladura de 0,35 mm")


func test_los_desgarros_del_animal_asustado() -> void:
	var st := MCS.new(C("lechuza"), T("coche"))
	st.threaded = false
	st.set_zone("techo")
	st.set_defense(true)
	st.set_speed(90.0)
	st.finish()
	var c := ctx(st, "techo")
	var w := View.draw_to_world(Vector2(st.scen.draw.x, st.scen.draw.y))
	c["feet"] = Vector3(w.x, CurveKit.top_y(CarShape.top_curve(), w.x), 0.0)
	c["speed"] = st.marks_now()
	c["plan"] = st.hold_plan()
	# unidad 4y: asustada aprieta y se agarra sin resbalar: la huella de cada garra, ningún surco
	assert_true(bool(st.at.holds), "a 90 km/h la lechuza asustada aguanta")
	var s := CarDamage.from_hold(st.scen, c)
	assert_eq(s.grooves.size(), 0, "sin resbalar no hay desgarros")
	assert_eq(s.holes.size(), int(MC.BODIES.lechuza.contact), "una huella por garra")
	# más deprisa de lo que aguanta, resbala por el techo hacia atrás: un desgarro por garra, hacia el borde de atrás
	var off := float(st.det.kmh) + 10.0
	assert_true(is_finite(off) and off <= st.top_kmh(), "se suelta en el deslizador (%s km/h)" % off)
	st.set_speed(off)
	st.finish()
	c["speed"] = st.marks_now()
	c["plan"] = st.hold_plan()
	assert_false(bool(st.at.holds), "a %s km/h ya no aguanta" % off)
	s = CarDamage.from_hold(st.scen, c)
	var claws := int(MC.BODIES.lechuza.contact)
	assert_eq(s.grooves.size(), claws * 2, "un desgarro por garra (en dos tramos)")
	for g: Dictionary in s.grooves:
		assert_true(int(g.layer) >= 0, "con la capa del motor")
		assert_true(g.b.x <= g.a.x + 1e-6 and g.b.x >= (CarShape.PANELS.techo as Vector2).x - 1e-6, "hacia atrás, sin pasar del panel")


func test_la_ventanilla_que_estalla() -> void:
	# la física aún no golpea las ventanillas (docs/fisica/coche-en-marcha.md §9.6.2, propuesta): con el contrato propuesto,
	# un golpe con sideWindow se dibuja; se prueba con un resultado de ejemplo
	var st := strike("tigre", "coche", "puerta", 50.0, 40.0, 90.0, 0.5)
	var h: Dictionary = st.hit.duplicate()
	h["sideWindow"] = { "shattered": true, "cause": "grieta", "fragmentMm": 5.6, "pane": "front" }
	var s := CarDamage.from_hit(h, ctx(st, "puerta"))
	assert_eq(s.shatter.front, 1.0, "estalla la delantera")
	assert_eq(s.shatter.rear, 0.0, "y no la trasera")
	assert_near(float(s.shatter.frag_m), 0.0056, 1e-9, 0.0, "en trozos de fragmentMm")
	var none := CarDamage.from_hit(st.hit, ctx(st, "puerta"))
	assert_eq(none.shatter.front, 0.0, "sin sideWindow, la ventanilla sigue entera")
	var root := Node3D.new()
	var car := CarModel.new()
	car.build(root, Color(0.5, 0.2, 0.2), true)
	car.set_damage(s)
	assert_eq(car.glass.get_shader_parameter("shatter_front"), 1.0, "las lunas lo saben")
	var nodes := car.nodes
	car.shatter_start(0, 0.0056, "prueba")
	car.shatter_step(0.5, 1.0)
	car.shatter_start(0, 0.0056, "prueba")
	assert_eq(car.nodes, nodes + 1, "los trocitos se crean una vez y se reutilizan")
	assert_eq(car.shards.multimesh.instance_count, CarModel.SHARDS, "SHARDS trocitos")
	car.shatter_step(CarModel.SHARD_S, 1.0)
	assert_false(car.shards.visible, "al acabar, se esconden")
	root.free()


# ════════ El viento ════════

func test_el_viento_sale_de_la_fisica() -> void:
	var st := MCS.new(C("aguila"), T("coche"))
	st.threaded = false
	st.set_speed(90.0)
	st.set_wind(20.0, 15.0)
	st.finish()
	var air: Dictionary = st.air_flow()
	assert_eq(air.alongKmh, 110.0, "el aire a lo largo: el coche más el viento de cara")
	assert_eq(air.crossKmh, 15.0, "y el lateral")
	for z: Dictionary in air.zones:
		assert_near(float(z.factor), MC.local_factor(float(MC.ZONES[z.id].cp.value)), 1e-12, 0.0, "«%s»: v·√(1 − Cp)" % z.id)
	var prof := AirFlow.top_profile(air.zones)
	var roof := AirFlow.profile_at(prof, View.draw_to_world(Vector2(0.55, 0.96)).x)
	var foot := AirFlow.profile_at(prof, View.draw_to_world(Vector2(0.30, 0.64)).x)
	assert_true(roof > 1.0 and foot < 1.0, "más deprisa sobre el techo (%s) y remanso al pie del parabrisas (%s)" % [roof, foot])
	# las líneas: junto a la chapa del techo, a la velocidad local; lejos de delante, a la del aire libre
	var p := AirFlow.build_paths(air.zones, CarShape.top_curve())
	var img: Image = p.image
	var near_roof := 0.0
	var far := 0.0
	for j in AirFlow.SAMPLES:
		var c := img.get_pixel(j, 0)
		if absf(c.r - 2.025) < 0.05:
			near_roof = c.a
		if c.r > AirFlow.X_IN - 0.3:
			far = c.a
	assert_true(near_roof > 1.1, "la línea pegada al techo va a ~%s veces el aire" % near_roof)
	assert_near(far, 1.0, 1e-6, 1e-6, "y delante del coche, a la del aire libre")
	# en el golpe no hay viento: solo el coche
	st.set_mode(MCS.MODE_IMPACT)
	assert_eq(st.air_flow().alongKmh, 90.0, "en el golpe, el aire del coche")
	assert_eq(st.air_flow().crossKmh, 0.0, "sin lateral")


func test_viento_parado_movil_y_movimiento_reducido() -> void:
	var card := _card("aguila")
	card.speed.slider.value_changed.emit(0.0)
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	var view: View = card.view
	var wind: AirFlow = view.get("_scene").wind
	assert_true(wind.built, "el viento se construye con las zonas del estado")
	assert_eq(wind.count, int(AirFlow.COUNT.escritorio), "en el escritorio, todas las partículas")
	assert_false(wind.visible, "a 0 km/h sin viento, nada")
	card.speed.slider.value_changed.emit(90.0)
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	assert_true(wind.visible and wind.mm.visible_instance_count > 0, "en marcha, partículas")
	var slow := wind.mm.visible_instance_count
	card.speed.slider.value_changed.emit(220.0)
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	assert_true(wind.mm.visible_instance_count > slow, "más deprisa, más densas (%d > %d)" % [wind.mm.visible_instance_count, slow])
	view.reduce_motion = true
	card.reduce_motion = true
	card.speed.slider.value_changed.emit(200.0)
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	assert_false(wind.visible, "con movimiento reducido, ninguna")
	# en el teléfono, menos partículas
	var phone := _card("aguila", 360.0)
	for i in 3:
		phone.step(16.0)
		await wait_frames(1)
	var pw: AirFlow = (phone.view as View).get("_scene").wind
	assert_eq((phone.view as View).quality, "movil", "una vista estrecha va con el preset móvil")
	assert_eq(pw.count, int(AirFlow.COUNT.movil), "con menos partículas")


func test_los_danos_se_acumulan_en_el_ensayo() -> void:
	var card := _card("tigre")
	card.speed.slider.value_changed.emit(50.0)
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	card.izone_pills["puerta"].pressed.emit()
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	var view: View = card.view
	var n0: int = int(card.st.hit.marks.count)
	assert_eq(view.damage().grooves.size(), n0, "el primer golpe deja sus surcos")
	card.speed.slider.value_changed.emit(60.0)
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.damage().grooves.size(), n0 + int(card.st.hit.marks.count), "el segundo, en el mismo ensayo, se suma")
	assert_eq(view.damage().dents.size(), 2 * int(card.st.hit.dent.patches), "y sus abolladuras")
	# otro ensayo (las garras de zafiro): se borran los de antes
	card.inlay_pills["zafiro"].pressed.emit()
	card.finish()
	for i in 3:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.damage().grooves.size(), int(card.st.hit.marks.count), "al cambiar de ensayo, solo los del golpe nuevo")


func test_en_cada_fotograma_no_se_crea_nada() -> void:
	var card := _card("aguila")
	card.speed.slider.value_changed.emit(120.0)
	card.finish()
	for i in 4:
		card.step(16.0)
		await wait_frames(1)
	var view: View = card.view
	var scene: Node3D = view.get("_scene")
	var nodes := scene.find_children("*", "", true, false).size()
	var builds: int = view.builds
	var sets: int = view.damage_sets
	var d0: int = view.draws
	for i in 30:
		card.step(16.0)
		await wait_frames(1)
	assert_true(view.draws > d0 + 10, "en marcha se redibuja (%d)" % (view.draws - d0))
	assert_eq(scene.find_children("*", "", true, false).size(), nodes, "sin nodos nuevos")
	assert_eq(view.builds, builds, "sin geometría nueva")
	assert_eq(view.damage_sets, sets, "y los daños no se rehacen")


# ════════ Los velocirraptores (4i-B2) ════════

func test_los_dos_velocirraptores_se_dibujan() -> void:
	var card := _card("velociraptor_pelicula")
	card.finish()
	await wait_frames(1)
	var view: View = card.view
	assert_eq(view.variant, "pelicula", "el de cine (ficción), la variante de draw_size()")
	var film: RefCounted = view.get("_rig")
	assert_true(film != null, "se dibuja aunque su dibujo aún sea el de la otra variante")
	assert_eq(String(film.get("variant")), "pelicula", "con su variante")
	var film_h: float = (film.get("fit_box") as Rect2).size.y
	assert_true(film_h <= 0.87 + 1e-6, "y cabe en su alto de draw_size(): %s m" % film_h)
	var builds: int = view.builds
	card.st.set_variant("velociraptor")
	card.finish()
	await wait_frames(1)
	assert_eq(view.variant, "reconstruccion", "la reconstrucción")
	var real: RefCounted = view.get("_rig")
	assert_true(real != null and real != film and view.builds > builds, "al cambiar de variante se rehace el animal")
	assert_eq(String(real.get("variant")), "reconstruccion", "con la suya")
	var real_h: float = (real.get("fit_box") as Rect2).size.y
	assert_near(real_h / film_h, 0.5 / 0.87, 0.05, 0.0, "más pequeña: 0,5 m de cadera contra 0,87 (%s y %s m)" % [real_h, film_h])
	assert_eq(View.art_id("velociraptor"), "velociraptor", "la reconstrucción, con su dibujo")
	assert_eq(View.art_id("tigre"), "tigre", "los demás, con el suyo")
	assert_eq(View.art_id(""), "", "sin animal, nada")


func test_el_salto_del_velocirraptor() -> void:
	var st := strike("velociraptor_pelicula", "coche", "capo", 50.0, 39.0, 90.0, 0.0)
	var lp: Dictionary = st.hit.leap
	var feet_y := 0.95
	var arc := View.leap_arc(lp, 50.0, feet_y)
	assert_near(arc.x, float(lp.ux) - 50.0 / MC.KMH, 1e-6, 1e-6, "llega con leap.ux menos la velocidad del coche (Vector3: float32)")
	assert_near(arc.y, float(lp.uz), 1e-6, 1e-6, "y con leap.uz")
	assert_true(arc.y < 0.0, "a un panel de arriba llega cayendo")
	assert_true(arc.z > 0.0 and Vector2(arc.x, arc.y).length() * arc.z <= View.APPROACH_M + 1e-5, "se ven sus últimos APPROACH_M m")
	for v: float in [0.0, 10.0, 50.0, 130.0]:
		var a := View.leap_arc(lp, v, feet_y)
		var dt := -a.z
		var y0 := feet_y + a.y * dt - 0.5 * MC.G * dt * dt
		assert_true(y0 >= -1e-6, "a %s km/h sale de encima del asfalto (%s m)" % [v, y0])
	var side := strike("velociraptor_pelicula", "coche", "puerta", 50.0, 39.0, 90.0, 0.0)
	assert_eq(View.leap_arc(side.hit.leap, 50.0, 0.6), Vector3.ZERO, "contra un costado, con la carrera: sin salto")
	assert_eq(View.leap_arc(null, 50.0, 1.0), Vector3.ZERO, "los demás no saltan")


func test_el_velocirraptor_de_cine_raja_el_capo() -> void:
	var film := strike("velociraptor_pelicula", "coche", "capo", 50.0, 39.0, 90.0, 0.0)
	var h: Dictionary = film.hit
	var s := CarDamage.from_hit(h, ctx(film, "capo"))
	assert_eq(s.grooves.size(), int(h.marks.count), "una raja por garra falciforme (marks.count)")
	for g: Dictionary in s.grooves:
		assert_eq(int(g.layer), CarDamage.LAYER_THROUGH, "la garra de película raja la chapa (%s µm)" % h.marks.depthUm)
		assert_near(float(g.hw), float(h.marks.widthUm) / 2.0e6, 1e-9, 0.0, "de marks.widthUm de ancho")
		assert_eq(int(g.axis), CarDamage.AXIS_TOP, "en el capó")
	if s.grooves.size() == 2:
		var across := absf(float(s.grooves[0].a.y) - float(s.grooves[1].a.y))
		assert_near(across, float(CarDamage.PAW_SEP.teropodo), 0.2, 0.0, "una con cada pie (%s m)" % across)
	assert_eq(s.holes.size(), s.grooves.size(), "y un agujero donde entra cada una")
	for hole: Dictionary in s.holes:
		assert_eq(int(hole.petals), CarDamage.PETALS, "con sus pétalos")
	var real := strike("velociraptor", "coche", "capo", 50.0, 39.0, 90.0, 0.0)
	var r := CarDamage.from_hit(real.hit, ctx(real, "capo"))
	assert_true(r.grooves.size() > 0, "el de verdad también raya")
	for g: Dictionary in r.grooves:
		assert_true(int(g.layer) < CarDamage.LAYER_THROUGH, "pero sin atravesar la chapa: pinchan y sujetan")
	assert_eq(r.holes.size(), 0, "ni perforarla")
	assert_eq(r.dents.size(), int(real.hit.dent.patches), "y la abolla bajo sus pies")



## Unidad 4r: el deportivo es un cupé (dos puertas por lado: una junta menos y un tirador por lado), más bajo y más ancho.
func test_el_cupe_del_deportivo() -> void:
	var holder := Node3D.new()
	var sedan := CarModel.new()
	sedan.build(holder, Color.RED, true)
	var coupe := CarModel.new()
	coupe.build(holder, Color.BLUE, true, Vector3(1.0, 0.9, 1.03), 2)
	assert_eq(coupe.doors, 2)
	var n_sedan := int(sedan.paint.get_shader_parameter("n_seams"))
	var n_coupe := int(coupe.paint.get_shader_parameter("n_seams"))
	assert_eq(n_sedan - n_coupe, CarShape.SEAMS_X.size() - CarShape.COUPE_SEAMS_X.size(), "una junta de puerta menos por lado")
	assert_true(coupe.triangles < sedan.triangles, "un tirador menos por lado")
	holder.free()
