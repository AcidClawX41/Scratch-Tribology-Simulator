## La luz del sol del coche en marcha (unidad 4w, petición de Eric del 18-10: car_scene.gd, moving_car_view.gd y
## moving_car_card.gd, bloques «Luz del sol»). Se comprueba:
##   - «Como hasta ahora» deja el sol, la luz de relleno, la ambiente y el cielo tal cual (y volver a ella también);
##   - un sol cambia la luz y el cielo de reflexión, y las garras ven el mismo cielo (ClawMaterial.road_light);
##   - el sol, a su altura y su rumbo; en curva gira al revés que el coche (se queda quieto en el mundo);
##   - el selector de la tarjeta, y el deslizador del rumbo solo con un sol.
extends "res://tests/case.gd"

const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const Card = preload("res://app/lab/moving_car_card.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const SKY_KEYS := ["zenith_color", "mid_color", "horizon_color", "sun_dir", "sun_color", "sun_energy", "horizon_energy"]


func _scene() -> CarScene:
	var host := Node3D.new()
	add_to_tree(host)
	var sc := CarScene.new()
	host.add_child(sc)
	sc.build(Color(0.6, 0.1, 0.15), "movil")
	return sc


static func _snap(sc: CarScene) -> Dictionary:
	var out := {
		"basis": sc.sun.basis, "energy": sc.sun.light_energy, "color": sc.sun.light_color, "fill": sc._fill.light_energy,
		"ambient": sc._env.ambient_light_energy,
	}
	for k: String in SKY_KEYS:
		out[k] = sc._sky_mat.get_shader_parameter(k)
	return out


func test_como_hasta_ahora_no_cambia_nada() -> void:
	var sc := _scene()
	var before := _snap(sc)
	assert_eq(sc.light_id, CarScene.LIGHT_DEFAULT, "la luz de siempre, por defecto")
	sc.set_light("bajo", 30.0)
	var low := _snap(sc)
	assert_true(low.basis != before.basis and low.sun_dir != before.sun_dir, "el sol bajo mueve el sol y su disco del cielo")
	sc.set_light("defecto")
	assert_eq(var_to_str(_snap(sc)), var_to_str(before), "volver a la de siempre la deja tal cual")
	for k: String in ["claw_road_sun_dir", "claw_road_sun_color", "claw_road_sun_k", "claw_road_zenith", "claw_road_mid", "claw_road_horizon"]:
		assert_eq(ClawMaterial.road_light.get(k), ClawMaterial.ROAD_DEFAULTS[k], "y las garras, con el cielo de siempre (%s)" % k)
	# lo que pisan: la pintura del coche, iluminada (la revisión de los materiales de la 4w)
	var g: Vector3 = ClawMaterial.road_light.claw_road_ground_near
	assert_true(g.x > g.z, "una garra sobre un coche rojo refleja rojo por debajo: %s" % g)
	assert_eq(float(ClawMaterial.road_light.claw_road_neutral), CarScene.GEM_NEUTRAL)


func test_el_sol_a_su_altura_y_en_curva_quieto_en_el_mundo() -> void:
	for l: Dictionary in CarScene.LIGHTS.slice(1):
		var d := CarScene.sun_dir(float(l.elev), float(l.az))
		assert_true(absf(d.length() - 1.0) < 1e-6)
		assert_true(absf(rad_to_deg(asin(d.y)) - float(l.elev)) < 1e-3, "%s, a %s° del horizonte" % [l.id, l.elev])
	var sc := _scene()
	sc.set_light("mediodia")
	var d0: Vector3 = sc._sky_mat.get_shader_parameter("sun_dir")
	sc.set_car_heading(deg_to_rad(30.0))
	var d1: Vector3 = sc._sky_mat.get_shader_parameter("sun_dir")
	var a0 := rad_to_deg(atan2(d0.z, d0.x))
	var a1 := rad_to_deg(atan2(d1.z, d1.x))
	assert_true(absf(wrapf(a0 - a1, -180.0, 180.0) - 30.0) < 0.01, "el coche gira 30° a la izquierda: el sol, 30° al revés (%s → %s)" % [a0, a1])
	assert_true(absf(d0.y - d1.y) < 1e-6, "a la misma altura")
	var mat := ShaderMaterial.new()
	ClawMaterial.apply_road_light(mat)
	assert_eq(mat.get_shader_parameter("claw_road_sun_dir"), d1, "las garras ven el sol donde está")
	sc.set_light("defecto")
	ClawMaterial.apply_road_light(mat)
	assert_eq(mat.get_shader_parameter("claw_road_sun_dir"), ClawMaterial.ROAD_DEFAULTS.claw_road_sun_dir, "y con la de siempre, el suyo")


func test_el_selector_de_la_tarjeta() -> void:
	var host := Control.new()
	host.size = Vector2(700, 1400)
	add_to_tree(host)
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = false
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, "oso"))
	card.refresh()
	card.finish()
	host.add_child(card)
	assert_eq(card.view.light_pref, CarScene.LIGHT_DEFAULT, "por defecto, la de siempre")
	assert_false(card.sun_turn.visible, "sin sol, no hay rumbo")
	(card.light_seg.buttons["bajo"] as Button).pressed.emit()
	assert_eq(card.view.light_pref, "bajo")
	assert_true(card.sun_turn.visible, "con un sol, su rumbo")
	card.sun_turn.slider.value = 45.0
	assert_eq(card.view.sun_turn, 45.0)
	(card.light_seg.buttons["defecto"] as Button).pressed.emit()
	assert_false(card.sun_turn.visible)
