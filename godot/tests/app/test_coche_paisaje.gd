## El paisaje del coche en marcha (unidad 4x, petición de Eric del 18-10: scenery.gd y los bloques «Paisaje» de car_scene.gd,
## road_curve.gd, moving_car_view.gd y moving_car_card.gd). Se comprueba:
##   - los árboles: menos en el teléfono, siempre fuera del asfalto y su arcén, más lejos que cerca, deterministas;
##   - el paisaje solo con la persecución y el «Fondo: campo»; sin él, el entorno de siempre tal cual;
##   - la persecución también en la recta, solo si se elige (por defecto, la vista de lado de siempre);
##   - en cada fotograma no se crea nada (los mismos nodos).
extends "res://tests/case.gd"

const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const Scenery = preload("res://app/lab/car3d/scenery.gd")
const Card = preload("res://app/lab/moving_car_card.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Catalog = preload("res://core/lab/catalog.gd")


func _scene(q := "movil") -> CarScene:
	var host := Node3D.new()
	add_to_tree(host)
	var sc := CarScene.new()
	host.add_child(sc)
	sc.build(Color(0.6, 0.1, 0.15), q)
	return sc


func test_los_arboles_fuera_del_asfalto_y_mas_lejos_que_cerca() -> void:
	var counts := {}
	for mobile: bool in [false, true]:
		var s := Scenery.new()
		add_to_tree(s)
		s.build(-40.0, 260.0, -1.75, 8.4, mobile)
		var total := 0
		var near := 0
		var far := 0
		if true:
			for c: Color in s.placements:
				var off := absf(c.g + 1.75)
				assert_true(off >= 8.4 + 2.9, "un árbol a %s m del eje: fuera del asfalto y del arcén" % off)
				assert_true(c.r >= -40.0 - 8.0 and c.r <= 260.0 + 8.0, "a lo largo, dentro de la carretera larga (%s)" % c.r)
				if off < 8.4 + 40.0:
					near += 1
				elif off > 8.4 + 110.0:
					far += 1
				total += 1
		counts[mobile] = total
		assert_true(far > near, "más árboles lejos (%d) que junto al arcén (%d)" % [far, near])
	assert_true(int(counts[true]) * 2 < int(counts[false]), "en el teléfono, menos árboles: %s" % [counts])
	var a := Scenery.new()
	var b := Scenery.new()
	add_to_tree(a)
	add_to_tree(b)
	a.build(-40.0, 260.0, -1.75, 8.4, true)
	b.build(-40.0, 260.0, -1.75, 8.4, true)
	assert_eq(a.placements, b.placements, "con su semilla, siempre igual")


func test_el_paisaje_solo_con_la_persecucion_y_el_campo() -> void:
	var sc := _scene()
	var bg := sc._env.background_mode
	var fog := sc._env.fog_enabled
	assert_true(sc.scenery == null, "sin persecución, no se construye")
	sc.set_straight_chase(true)
	assert_true(sc.chasing and sc.scenery != null and sc.scenery.visible, "la persecución en la recta, con el campo")
	assert_true(sc.road_chase.visible, "la carretera larga, a la vista")
	assert_eq(sc._env.background_mode, Environment.BG_SKY, "el cielo de verdad detrás")
	assert_true(sc._env.fog_enabled, "y la niebla de la lejanía")
	var nodes := sc.scenery.get_child_count()
	sc.update_chase()
	sc.update_chase()
	assert_eq(sc.scenery.get_child_count(), nodes, "en cada fotograma, los mismos nodos")
	sc.set_scenery(false)
	assert_false(sc.scenery.visible, "«Fondo: liso»")
	assert_eq(sc._env.background_mode, bg, "con el fondo de siempre")
	sc.set_scenery(true)
	sc.set_straight_chase(false)
	assert_false(sc.chasing)
	assert_false(sc.scenery.visible)
	assert_eq(sc._env.background_mode, bg, "sin persecución, el entorno de siempre")
	assert_eq(sc._env.fog_enabled, fog)


func test_la_persecucion_en_la_recta_solo_si_se_elige() -> void:
	var host := Control.new()
	host.size = Vector2(700, 1400)
	add_to_tree(host)
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = false
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "tigre"))
	card.refresh()
	card.finish()
	host.add_child(card)
	assert_false(card.view.chasing(), "en la recta, por defecto, la vista de lado de siempre")
	assert_true(card.view_seg.visible, "y el selector de la vista, también en la recta")
	(card.view_seg.buttons["persecucion"] as Button).pressed.emit()
	assert_true(card.view.chase_straight, "elegida la persecución en la recta")
	assert_true(card.view.chasing())
	assert_true(card.view.chase_pref, "la de la curva no cambia")
	(card.scenery_seg.buttons["liso"] as Button).pressed.emit()
	assert_false(card.view.scenery_pref)
