## Escena 3D del coche en marcha (unidades 4h y 4k): el mundo que la vista (moving_car_view.gd) pinta en su SubViewport.
## Solo dibujo; los números los da el estado.
##   - Entorno como el del taller (sharpen_3d.gd, lathe_3d.gd): tonemap fílmico, brillo para las luces, luz ambiente y
##     reflejos de un cielo procedural (road_sky.gdshader, el de una carretera al atardecer: la nave del taller se
##     reflejaría en la chapa de un coche en la calle). El fondo no se ve: el SubViewport es transparente y detrás está la
##     tarjeta (y se ve por las lunas).
##   - Sol con sombras (sin sombras en el preset móvil) y luz de relleno fría.
##   - Cámara ortográfica de perfil con PITCH_DEG de picado y YAW_DEG de giro hacia el morro (unidad 4k: se ven el frontal,
##     la calandra, la matrícula y los faros, como en una foto de tres cuartos de lejos); la conversión mundo → pantalla
##     sigue siendo lineal (project()), así que lo que la vista pinta en 2D encima cae en su sitio.
##   - Carretera: asfalto con su textura, línea continua del arcén y discontinua del centro que corren con el coche (solo
##     se mueven transformaciones y un desplazamiento de UV), y una sombra de contacto suave bajo el coche.
##   - El viento (air_flow.gd, unidad 4k): partículas por las líneas de corriente, a la velocidad local del modelo.
## Coordenadas: metros, x desde la zaga del coche hacia el morro, y hacia arriba, z hacia quien mira.
extends Node3D

const CarModel = preload("res://app/lab/car3d/car_model.gd")
const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const AirFlow = preload("res://app/lab/car3d/air_flow.gd")
const SKY_SHADER = preload("res://app/lab/car3d/road_sky.gdshader")
const Rng = preload("res://core/shared/rng.gd")
## Unidad 4t: la carretera en curva y el balanceo.
const RoadCurve = preload("res://app/lab/car3d/road_curve.gd")
## Unidad 4w: el cielo que ven las garras sigue a la luz.
const ClawMaterial = preload("res://app/common/claw_material.gd")
## Unidad 4x: el paisaje de la persecución.
const Scenery = preload("res://app/lab/car3d/scenery.gd")

## Picado de la cámara (grados) y giro hacia el morro (grados): dibujo.
const PITCH_DEG := 8.0
const YAW_DEG := 14.0
## Distancia de la cámara (m) a lo largo de su eje.
const CAM_DIST := 14.0
## Carretera: medio ancho (m), las líneas y el tramo de las discontinuas (dibujo: más corto que el de verdad para que su
## movimiento se lea en una vista de 6 m).
const ROAD_HW := 2.4
const EDGE_Z := 2.05
const CENTER_Z := -2.05
const DASH_L := 1.0
const DASH_GAP := 2.0
const DASHES := 14
const ROAD_X := [-12.0, 18.0]
## Capa de render del animal (bit de VisualInstance3D.layers).
const ANIMAL_LAYER := 2
## Capa de las garras del animal (además de ANIMAL_LAYER; unidad 4s): el primer plano del golpe las ve sin el cuerpo.
const CLAW_LAYER := 8
const ALL_LAYERS := 0xFFFFF

var quality := "escritorio"
var car := CarModel.new()
## Escala de la carrocería (unidad 4r: el deportivo; Vector3.ONE en el turismo).
var shape := Vector3.ONE
## Puertas por lado del coche construido (unidad 4r: 2 en el deportivo).
var doors := 4
var camera: Camera3D
var sun: DirectionalLight3D
## Nodo donde la vista pone el animal (y lo que sale de él).
var animal_root: Node3D
## El viento (se construye cuando la vista tiene las zonas del estado: build_wind).
var wind: AirFlow
var built := false
var _asphalt: StandardMaterial3D
var _dashes: Array = []
## Unidad 4t: los nodos de la carretera recta (se esconden en curva) y la carretera en curva (se crea la primera vez).
var _flat: Array = []
var road_curve: RoadCurve = null
var curved := false


## Construye el mundo (una vez): entorno, luces, cámara, carretera y coche.
func build(paint: Color, p_quality := "escritorio", p_shape := Vector3.ONE, p_doors := 4) -> void:
	if built:
		return
	built = true
	quality = p_quality
	shape = p_shape
	doors = p_doors
	_paint = paint  # unidad 4w
	var mobile := quality == "movil"
	_environment()
	_road()
	car.build(self, paint, mobile, shape, doors)
	animal_root = Node3D.new()
	animal_root.name = "Animal"
	add_child(animal_root)
	wind = AirFlow.new()
	wind.name = "Aire"
	add_child(wind)
	camera = Camera3D.new()
	camera.name = "Camara"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.5
	camera.far = CAM_DIST * 2.5
	camera.basis = view_basis()
	camera.current = true
	add_child(camera)
	set_quality(quality)
	_apply_light()  # unidad 4w: el destello del sol en las lunas, ya con el coche


## Base de la cámara: el giro hacia el morro y luego el picado.
static func view_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(YAW_DEG)) * Basis(Vector3.RIGHT, -deg_to_rad(PITCH_DEG))


## Las líneas del viento con los factores de velocidad de las zonas (del estado: air_flow().zones), una vez (y otra vez
## si cambia la carrocería: rebuild_car).
func build_wind(zones: Array) -> void:
	if wind != null and not wind.built:
		wind.build(zones, CarShape.scaled_top(shape), quality)


## Otra carrocería (unidad 4r: del turismo al deportivo y vuelta): el coche se construye de nuevo con su escala, con la
## misma pintura, y las líneas del viento se rehacen sobre su silueta (zones: las de build_wind; vacío: no había); p_doors:
## las puertas por lado.
func rebuild_car(paint: Color, p_shape: Vector3, zones: Array, p_doors := 4) -> void:
	if not built or (shape.is_equal_approx(p_shape) and doors == p_doors):
		return
	shape = p_shape
	doors = p_doors
	if car.root != null:
		remove_child(car.root)
		car.root.queue_free()
	car = CarModel.new()
	car.build(self, paint, quality == "movil", shape, doors)
	if wind != null:
		remove_child(wind)
		wind.queue_free()
		wind = AirFlow.new()
		wind.name = "Aire"
		add_child(wind)
		if not zones.is_empty():
			build_wind(zones)
	_apply_light()  # unidad 4w: el destello del sol en las lunas del coche nuevo


func _environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	_env = env  # unidad 4w: la luz del sol la cambia (set_light)
	_sky_mat = sky_mat
	var we := WorldEnvironment.new()
	we.name = "Entorno"
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sol"
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.basis = Basis.looking_at(Vector3(-0.42, -0.8, -0.45), Vector3.UP)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = CAM_DIST + 10.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Relleno"
	fill.light_energy = 0.35
	fill.light_color = Color(0.74, 0.8, 1.0)
	fill.light_specular = 0.25
	fill.basis = Basis.looking_at(Vector3(0.65, -0.35, -0.7), Vector3.UP)
	add_child(fill)
	_fill = fill
	_apply_light()


func _road() -> void:
	var road := MeshInstance3D.new()
	road.name = "Carretera"
	var pm := PlaneMesh.new()
	var len := float(ROAD_X[1]) - float(ROAD_X[0])
	pm.size = Vector2(len, ROAD_HW * 2.0)
	road.mesh = pm
	road.position = Vector3((float(ROAD_X[0]) + float(ROAD_X[1])) * 0.5, 0.0, 0.0)
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_texture = _asphalt_texture()
	_asphalt.albedo_color = Color(1, 1, 1)
	_asphalt.roughness = 0.9
	_asphalt.uv1_scale = Vector3(len / 1.6, ROAD_HW * 2.0 / 1.6, 1.0)
	_asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	road.material_override = _asphalt
	add_child(road)
	_flat.append(road)
	# arcén: una franja más clara y rugosa al otro lado de la carretera, y la tierra detrás
	var verge := MeshInstance3D.new()
	var vm := PlaneMesh.new()
	vm.size = Vector2(len, 1.2)
	verge.mesh = vm
	verge.position = Vector3(road.position.x, -0.004, -ROAD_HW - 0.6)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.2, 0.17, 0.2)
	vmat.roughness = 1.0
	verge.material_override = vmat
	add_child(verge)
	_flat.append(verge)
	# línea continua del arcén (delante del coche) y discontinuas del centro (detrás)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.86, 0.85, 0.82)
	paint.roughness = 0.62
	var edge := MeshInstance3D.new()
	var em := PlaneMesh.new()
	em.size = Vector2(len, 0.12)
	edge.mesh = em
	edge.material_override = paint
	edge.position = Vector3(road.position.x, 0.003, EDGE_Z)
	add_child(edge)
	_flat.append(edge)
	var dm := PlaneMesh.new()
	dm.size = Vector2(DASH_L, 0.12)
	for k in DASHES:
		var d := MeshInstance3D.new()
		d.mesh = dm
		d.material_override = paint
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_dashes.append(d)
		_flat.append(d)
	# sombra de contacto: lo oscuro justo debajo del coche (con o sin sombras de verdad)
	var sh := MeshInstance3D.new()
	sh.name = "SombraDeContacto"
	var sm := PlaneMesh.new()
	sm.size = Vector2(CarShape.CAR_L + 0.5, CarShape.HALF_W * 2.0 + 0.4)
	sh.mesh = sm
	sh.position = Vector3(CarShape.CAR_L * 0.5, 0.006, 0.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = _contact_texture()
	smat.albedo_color = Color(0, 0, 0, 0.85)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.material_override = smat
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)
	set_road(0.0)


## Textura del asfalto: gravilla clara y oscura sobre gris, determinista.
static func _asphalt_texture() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var rng := Rng.new(Rng.seed_of("asfalto"))
	for y in n:
		for x in n:
			var g := 0.17 + 0.05 * rng.next()
			var r := rng.next()
			if r > 0.965:
				g += 0.16 * rng.next()
			elif r < 0.05:
				g -= 0.07
			img.set_pixel(x, y, Color(g * 0.98, g * 0.95, g * 1.02))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Textura de la sombra de contacto: un rectángulo redondeado oscuro con el borde difuminado.
static func _contact_texture() -> ImageTexture:
	var w := 96
	var h := 32
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			var v := absf((float(y) + 0.5) / float(h) * 2.0 - 1.0)
			var d := maxf(u * 1.02, v)
			var a := clampf((1.0 - d) / 0.35, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.8))
	return ImageTexture.create_from_image(img)


## La carretera corre: road_m es lo recorrido (m, a cámara lenta).
func set_road(road_m: float) -> void:
	var period := DASH_L + DASH_GAP
	var x0 := float(ROAD_X[0])
	var off := fmod(road_m, period)
	for k in _dashes.size():
		(_dashes[k] as Node3D).position = Vector3(x0 + float(k) * period - off, 0.003, CENTER_Z)
	if _asphalt != null:
		var len := float(ROAD_X[1]) - float(ROAD_X[0])
		_asphalt.uv1_offset = Vector3(fmod(road_m / len * (len / 1.6), 1.0), 0.0, 0.0)
	if curved:
		road_curve.set_road(road_m)  # unidad 4t


## Preset de calidad: «movil» sin sombras.
func set_quality(q: String) -> void:
	quality = "movil" if q == "movil" else "escritorio"
	if sun != null:
		sun.shadow_enabled = quality != "movil"


## Coloca la cámara para que el punto del mundo p caiga en la pantalla en project(p, s, ox, oy), en un SubViewport de size
## px lógicos.
func frame(size: Vector2, s: float, ox: float, oy: float) -> void:
	if camera == null or s <= 0.0:
		return
	camera.size = size.y / s
	var b := view_basis()
	var xc := (size.x * 0.5 - ox) / s
	var yc := (oy - size.y * 0.5) / s
	camera.position = b.x * xc + b.y * yc + b.z * CAM_DIST


## Proyección (la misma que la cámara): del mundo (m) a la pantalla (px). Con la base de la cámara (derecha, arriba):
## x_pantalla = ox + (p · derecha)·s, y_pantalla = oy − (p · arriba)·s.
static func project(p: Vector3, s: float, ox: float, oy: float) -> Vector2:
	var b := view_basis()
	return Vector2(ox + p.dot(b.x) * s, oy - p.dot(b.y) * s)


# ════════ Curvas (unidad 4t) ════════

## La carretera en curva en lugar de la recta (on) o la recta de siempre. La curva se crea la primera vez que hace falta.
func set_curved(on: bool) -> void:
	if on == curved or not built:
		return
	curved = on
	if on and road_curve == null:
		road_curve = RoadCurve.new()
		road_curve.build(float(ROAD_X[0]), float(ROAD_X[1]), 0.0, ROAD_HW, 1.2, _asphalt.albedo_texture, EDGE_Z, CENTER_Z, false,
			32 if quality == "movil" else 64)
		road_curve.position.y = -0.002
		add_child(road_curve)
	for n: Node3D in _flat:
		n.visible = not on
	_show_roads()
	if not on:
		set_roll(0.0)
		set_chase(false)
		car.set_steer(0.0)


## Balanceo (rad, giro en x): el coche y el animal, alrededor del eje del coche en el suelo.
func set_roll(rad: float) -> void:
	if car.root != null:
		car.root.rotation.x = rad
	if animal_root != null:
		animal_root.rotation.x = rad


## Dibujo, la carretera larga de la vista de persecución: de CHASE_X[0] a CHASE_X[1] m a lo largo (la vista ve cientos de
## metros por delante), dos carriles de 3,5 m con el coche en el de la derecha: el eje de la carretera a CHASE_AXIS_Z m, el
## asfalto con CHASE_HW m de medio ancho, la línea continua de la derecha a CHASE_EDGE_Z y la discontinua del centro en el eje.
const CHASE_X := [-40.0, 260.0]
const CHASE_AXIS_Z := -1.75
const CHASE_HW := 3.7
const CHASE_EDGE_Z := 1.75
const CHASE_VERGE := 4.0

## La carretera larga y la cámara de persecución (se crean la primera vez que hacen falta).
var road_chase: RoadCurve = null
var chase_cam: Camera3D = null
var chasing := false


## La vista de persecución (on) o la de lado de siempre: cambia de cámara y de carretera.
func set_chase(on: bool) -> void:
	if on == chasing or not built:
		return
	chasing = on
	if on and road_chase == null:
		road_chase = RoadCurve.new()
		road_chase.build(float(CHASE_X[0]), float(CHASE_X[1]), CHASE_AXIS_Z, CHASE_HW, CHASE_VERGE, _asphalt.albedo_texture, CHASE_EDGE_Z,
			CHASE_AXIS_Z, true, 96 if quality == "movil" else 192)
		road_chase.position.y = -0.002
		add_child(road_chase)
		chase_cam = Camera3D.new()
		chase_cam.name = "CamaraPersecucion"
		chase_cam.fov = float(RoadCurve.CHASE_COMPACT.fov) if quality == "movil" else RoadCurve.CHASE_FOV
		chase_cam.near = 0.2
		chase_cam.far = 900.0
		add_child(chase_cam)
	if chase_cam != null:
		chase_cam.current = on
	camera.current = not on
	_show_roads()
	_scenery_show()  # (4x)


func _show_roads() -> void:
	if road_curve != null:
		road_curve.visible = curved and not chasing
	if road_chase != null:
		road_chase.visible = curved and chasing


## La cámara de persecución con la carretera larga de ahora (en cada fotograma de la vista de persecución).
func update_chase() -> void:
	if not chasing or road_chase == null:
		return
	if not car.far_wheels:
		car.ensure_far_wheels(quality == "movil")  # también tras rehacer el coche (otra carrocería)
	# la cámara cerca solo en una vista baja y ancha (el teléfono con la vista de siempre); en la vista alta del teléfono en
	# curva, la de siempre, que ya cabe
	var vp := get_viewport().get_visible_rect().size
	var compact := quality == "movil" and vp.x > 1.6 * vp.y
	chase_cam.fov = float(RoadCurve.CHASE_COMPACT.fov) if compact else RoadCurve.CHASE_FOV
	var pose := road_chase.chase_pose(compact)
	chase_cam.position = pose[0]
	chase_cam.look_at(pose[1], Vector3.UP)
	_scenery_frame()  # (4x)


# ════════ Luz del sol (unidad 4w) ════════

## La luz de la escena (dibujo, calidad «dibujo»: no cambia ningún número). «Como hasta ahora» es la de siempre, tal cual (el
## atardecer de road_sky.gdshader con su sol y la luz de relleno); las otras, un sol que el cielo de reflexión pinta como un
## disco: la pintura con barniz, las lunas, los cromados y las garras lo reflejan como un punto brillante. Cada una: elev
## (grados sobre el horizonte), az (rumbo, grados: 0 hacia el morro, 90 hacia quien mira en la vista de lado), el color y la
## fuerza de la luz, la luz de relleno, la ambiente y los colores del cielo (cenit, medio, horizonte, el disco del sol).
##   - «Sol de mediodía»: alto y blanco, del lado de quien mira (los costados y las ventanillas devuelven el destello),
##     sombras cortas y duras, cielo azul;
##   - «Sol bajo»: a ~11° del horizonte, cálido, de tres cuartos por detrás del lado de quien mira (el costado se tiñe de
##     naranja y los vidrios y los cromados lo devuelven rasante), sombras largas hacia delante, el horizonte anaranjado; con el
##     rumbo, a contraluz (el techo, el capó y el parabrisas lo reflejan hacia la cámara).
const LIGHT_DEFAULT := "defecto"
const LIGHTS := [
	{ "id": "defecto", "name": "Como hasta ahora", "short": "Como ahora", "title": "La luz de siempre: el atardecer suave del cielo de la carretera",
		"ground": 0.45, "ground_color": Color(1.0, 0.92, 0.85), "gem_sun": 5.0 },
	{ "id": "mediodia", "name": "Sol de mediodía", "short": "Mediodía", "title": "Un sol alto y blanco: sombras cortas y duras, destellos en los costados y las ventanillas",
		"elev": 58.0, "az": 110.0, "color": Color(1.0, 0.97, 0.92), "energy": 2.3, "fill": 0.28, "fill_color": Color(0.7, 0.8, 1.0),
		"ambient": 0.62, "shadow_blur": 0.6, "ground": 0.8, "gem_sun": 14.0,
		"sky": { "zenith": Color(0.13, 0.27, 0.56), "mid": Color(0.36, 0.52, 0.76), "horizon": Color(0.82, 0.87, 0.93),
			"sun": Color(1.0, 0.97, 0.9), "sun_energy": 9.0, "horizon_energy": 1.0 } },
	{ "id": "bajo", "name": "Sol bajo", "short": "Sol bajo", "title": "Un sol de atardecer a ras del horizonte: cálido, sombras largas y reflejos rasantes en la chapa y los vidrios",
		"elev": 11.0, "az": 125.0, "color": Color(1.0, 0.7, 0.44), "energy": 2.1, "fill": 0.22, "fill_color": Color(0.55, 0.62, 0.95),
		"ambient": 0.45, "shadow_blur": 1.0, "ground": 0.5, "gem_sun": 12.0,
		"sky": { "zenith": Color(0.11, 0.12, 0.27), "mid": Color(0.32, 0.26, 0.34), "horizon": Color(1.0, 0.62, 0.36),
			"sun": Color(1.0, 0.66, 0.4), "sun_energy": 8.0, "horizon_energy": 1.1 } },
]
## Lo que se puede girar el sol con el deslizador del rumbo (grados, a cada lado del de su luz).
const SUN_TURN_MAX := 180.0
## Lo que se acerca al blanco lo que se ve dentro de una gema en la carretera (ClawMaterial: claw_road_neutral; dibujo: el
## cielo dibujado es más morado y oscuro que uno de verdad, y el diamante se veía lila y con caras negras).
const GEM_NEUTRAL := 0.6

## La luz elegida, el giro del sol que pide el deslizador (grados) y, en curva, lo que ha girado el coche (rad, + a la
## izquierda: el sol se queda quieto en el mundo, así que respecto al coche gira al revés).
var light_id := LIGHT_DEFAULT
var sun_turn_deg := 0.0
var car_heading := 0.0
var _env: Environment
var _sky_mat: ShaderMaterial
var _fill: DirectionalLight3D
## La pintura del coche (sRGB): lo que reflejan las garras por debajo (las pisan).
var _paint := Color(0.5, 0.5, 0.5)
## Lo de la luz de siempre, para volver a ella tal cual (lo toma la primera vez que se cambia).
var _base := {}


## Elige la luz (LIGHTS) y el giro del sol (grados). Barata: solo cambia parámetros.
func set_light(id: String, turn_deg := 0.0) -> void:
	var known := LIGHTS.any(func(l: Dictionary) -> bool: return l.id == id)
	var nid := id if known else LIGHT_DEFAULT
	var nturn := clampf(turn_deg, -SUN_TURN_MAX, SUN_TURN_MAX)
	if nid == light_id and is_equal_approx(nturn, sun_turn_deg):
		return
	light_id = nid
	sun_turn_deg = nturn
	_apply_light()


## En curva, lo que ha girado el coche desde que empezó (rad): el sol gira al revés respecto a él.
func set_car_heading(rad: float) -> void:
	if is_equal_approx(rad, car_heading):
		return
	car_heading = rad
	if light_id != LIGHT_DEFAULT:
		_apply_light()


## La luz de light_id en el sol, la luz de relleno, la ambiente y el cielo de reflexión.
func _apply_light() -> void:
	if sun == null or _env == null:
		return
	if _base.is_empty():
		_base = {
			"basis": sun.basis, "energy": sun.light_energy, "color": sun.light_color, "blur": sun.shadow_blur,
			"fill": _fill.light_energy, "fill_color": _fill.light_color, "ambient": _env.ambient_light_energy,
			"sky": {}, "angular": sun.light_angular_distance,
		}
		for k: String in ["zenith_color", "mid_color", "horizon_color", "sun_dir", "sun_color", "sun_energy", "horizon_energy"]:
			_base.sky[k] = _sky_mat.get_shader_parameter(k)
	if light_id == LIGHT_DEFAULT:
		sun.basis = _base.basis
		sun.light_energy = _base.energy
		sun.light_color = _base.color
		sun.shadow_blur = _base.blur
		sun.light_angular_distance = _base.angular
		_fill.light_energy = _base.fill
		_fill.light_color = _base.fill_color
		_env.ambient_light_energy = _base.ambient
		for k: String in _base.sky:
			_sky_mat.set_shader_parameter(k, _base.sky[k])
		_glass_glint(Vector3(0.42, 0.8, 0.45), Color.WHITE, 0.0)
		var road := ClawMaterial.ROAD_DEFAULTS.duplicate()
		road.merge(_ground_params(light_of(LIGHT_DEFAULT)), true)
		ClawMaterial.set_road_light(road)
		_scenery_light()  # unidad 4x
		return
	var l: Dictionary = light_of(light_id)
	var to_sun := sun_dir(float(l.elev), float(l.az) + sun_turn_deg - rad_to_deg(car_heading))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.999 else Vector3.BACK)
	sun.light_energy = float(l.energy)
	sun.light_color = l.color
	sun.shadow_blur = float(l.shadow_blur)
	# el disco del sol mide ~0,5°: el brillo de la chapa y de las garras, del tamaño del de verdad
	sun.light_angular_distance = 0.53
	_fill.light_energy = float(l.fill)
	_fill.light_color = l.fill_color
	_env.ambient_light_energy = float(l.ambient)
	var sk: Dictionary = l.sky
	_sky_mat.set_shader_parameter("zenith_color", sk.zenith)
	_sky_mat.set_shader_parameter("mid_color", sk.mid)
	_sky_mat.set_shader_parameter("horizon_color", sk.horizon)
	_sky_mat.set_shader_parameter("sun_dir", to_sun)
	_sky_mat.set_shader_parameter("sun_color", sk.sun)
	_sky_mat.set_shader_parameter("sun_energy", float(sk.sun_energy))
	_sky_mat.set_shader_parameter("horizon_energy", float(sk.horizon_energy))
	_glass_glint(to_sun, l.color, float(l.get("glint", 1.0)))
	# el mismo cielo en las garras (su entorno «carretera»: lo que reflejan los metales y lo que se ve dentro de las gemas)
	var v3 := func(c: Color) -> Vector3: return Vector3(c.r, c.g, c.b)
	_scenery_light()  # unidad 4x: el paisaje con esta luz
	ClawMaterial.set_road_light({
		"claw_road_sun_dir": to_sun, "claw_road_sun_color": v3.call(sk.sun), "claw_road_sun_k": float(sk.sun_energy) * 6.0,
		"claw_road_zenith": v3.call(sk.zenith), "claw_road_mid": v3.call(sk.mid), "claw_road_horizon": v3.call(sk.horizon) * float(sk.horizon_energy),
	}.merged(_ground_params(l)))


## La luz de LIGHTS con ese id (la de siempre si no está).
static func light_of(id: String) -> Dictionary:
	for l: Dictionary in LIGHTS:
		if l.id == id:
			return l
	return LIGHTS[0]


## Hacia dónde está el sol (unitario, en la escena): elev grados sobre el horizonte y rumbo az (0 hacia el morro, +x; 90
## hacia quien mira, +z).
static func sun_dir(elev_deg: float, az_deg: float) -> Vector3:
	var e := deg_to_rad(elev_deg)
	var a := deg_to_rad(az_deg)
	return Vector3(cos(e) * cos(a), sin(e), cos(e) * sin(a)).normalized()


## Lo que ven las garras por debajo con la luz l (la pintura que pisan, iluminada) y lo blanco de dentro de las gemas.
func _ground_params(l: Dictionary) -> Dictionary:
	var c := _paint.srgb_to_linear() * float(l.get("ground", 0.45))
	var lc: Color = l.get("ground_color", l.get("color", Color.WHITE))
	return { "claw_road_ground_near": Vector3(c.r * lc.r, c.g * lc.g, c.b * lc.b), "claw_road_neutral": GEM_NEUTRAL,
		"claw_road_gem_sun": float(l.get("gem_sun", 0.0)) }


## La pintura del coche ha cambiado (o es la primera): las garras la reflejan por debajo.
func set_ground_paint(c: Color) -> void:
	_paint = c
	_apply_light()


## El destello del disco del sol en las lunas del coche (car_glass.gdshader): hacia dónde está, su color y cuánto (0 sin).
func _glass_glint(to_sun: Vector3, col: Color, k: float) -> void:
	if car == null or car.glass == null:
		return
	car.glass.set_shader_parameter("sun_glint_dir", to_sun)
	car.glass.set_shader_parameter("sun_glint_color", col)
	car.glass.set_shader_parameter("sun_glint", k)


# ════════ Paisaje (unidad 4x) ════════

## El paisaje de la persecución (scenery.gd: el campo, los árboles y las montañas), el cielo de verdad detrás y la niebla de
## la lejanía. scenery_on: «Fondo: campo» (por defecto) o «liso» (el fondo de siempre, el de la tarjeta). straight: la
## persecución también en la recta (la carretera larga, sin curva). Solo con la cámara de persecución.
var scenery: Scenery = null
var scenery_on := true
var straight_chase := false
## Lo del entorno de siempre, para volver a él tal cual al dejar la persecución.
var _env_base := {}
const FOG_DENSITY := 0.0042
const FOG_DENSITY_MOBILE := 0.0055


## «Fondo: campo» o «liso».
func set_scenery(on: bool) -> void:
	if on == scenery_on:
		return
	scenery_on = on
	_scenery_show()


## La persecución en la recta (on) o la vista de lado de siempre en la recta. En curva no cambia nada (lo lleva set_curved).
func set_straight_chase(on: bool) -> void:
	if not built or curved:
		straight_chase = false
		return
	if on == straight_chase and on == chasing:
		return
	straight_chase = on
	set_chase(on)
	if on:
		road_chase.set_kappa_const(0.0)
	_scenery_show()


## Lo que se ve según la cámara: el paisaje, el cielo y la niebla con la persecución y el campo; si no, el fondo de siempre.
func _scenery_show() -> void:
	if not built:
		return
	var straight := chasing and not curved
	for n: Node3D in _flat:
		n.visible = not curved and not straight
	if road_chase != null and straight:
		road_chase.visible = true
	var show := chasing and scenery_on
	if show and scenery == null:
		scenery = Scenery.new()
		scenery.build(road_chase.x0, road_chase.x1, CHASE_AXIS_Z, road_chase.edge_m(), quality == "movil")
		add_child(scenery)
	if scenery != null:
		scenery.visible = show
	if _env == null:
		return
	if _env_base.is_empty():
		_env_base = { "bg": _env.background_mode, "fog": _env.fog_enabled }
	if show:
		_env.background_mode = Environment.BG_SKY
		_env.fog_enabled = true
		_env.fog_density = FOG_DENSITY_MOBILE if quality == "movil" else FOG_DENSITY
		_env.fog_aerial_perspective = 0.6
		_env.fog_sky_affect = 0.0
		_scenery_light()
	else:
		_env.background_mode = _env_base.bg
		_env.fog_enabled = _env_base.fog


## Un fotograma de la persecución: el paisaje con el trazado y lo recorrido de la carretera, y lo lejano donde está la cámara.
func _scenery_frame() -> void:
	if scenery == null or not scenery.visible or road_chase == null:
		return
	scenery.set_path(road_chase.pts, road_chase.heads, road_chase.road_m())
	scenery.follow(chase_cam.global_position, car_heading if curved else 0.0)


## Los colores del paisaje con la luz de ahora (la de siempre o un sol de la 4w): la neblina es el horizonte de su cielo.
func _scenery_light() -> void:
	if scenery == null or _sky_mat == null:
		return
	var hz: Variant = _sky_mat.get_shader_parameter("horizon_color")
	var sd: Variant = _sky_mat.get_shader_parameter("sun_dir")
	var sc: Variant = _sky_mat.get_shader_parameter("sun_color")
	if light_id != LIGHT_DEFAULT:
		var sk: Dictionary = light_of(light_id).sky
		hz = sk.horizon
		sc = sk.sun
	var haze: Color = hz if hz is Color else Color(0.92, 0.8, 0.7)
	_env.fog_light_color = haze.darkened(0.08)
	scenery.set_light(haze, sd if sd is Vector3 else Vector3(0.42, 0.8, 0.45), sc if sc is Color else Color(1.0, 0.86, 0.66))
