## Carretera en curva, balanceo, giro de las ruedas y cámara de persecución del coche en marcha (unidad 4t y su pulido).
## Solo dibujo: los números los da el estado (MovingCarState: la curva, su radio, la S y la aceleración lateral de cada
## instante).
##   - La carretera: una tira recta y subdividida que el sombreador road_curve.gdshader lleva a lo largo del eje de la curva
##     (path_p y path_h: BEND_N puntos con su rumbo), con el coche en su sitio y la carretera tangente a él. Así conserva el
##     ancho aunque dé media vuelta. car_scene.gd tiene dos: la corta de la vista de lado (la curva dibujada más cerrada
##     que la de verdad, VIS_GAIN: de perfil, una curva de 130 m en 6 m de carretera sería casi recta) y la larga de la vista
##     de persecución (cientos de metros por delante, al radio de verdad).
##   - El balanceo de la carrocería: ROLL_DEG_PER_G grados por g de aceleración lateral, hacia fuera de la curva. Dibujo:
##     no hay medición del coche del dibujo y la física no lo usa (el animal siente la aceleración del coche).
##   - El giro de las ruedas delanteras: el de Ackermann, atan(batalla/R), por STEER_GAIN para que se vea (dibujo).
##   - La cámara de persecución: detrás del coche sobre la propia carretera (CHASE_BACK m), algo a su derecha y por encima,
##     mirando por delante de él: sigue la curva, así que el coche se ve girado respecto a ella y la carretera se curva
##     delante.
## Coordenadas: las de car_scene.gd (m; x desde la zaga hacia el morro, y arriba, z hacia quien mira en la vista de lado: la
## derecha del coche). Una curva a la izquierda (side = +1, empuja a la derecha) tiene el centro hacia −z.
extends MeshInstance3D

const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const SHADER = preload("res://app/lab/car3d/road_curve.gdshader")

## Puntos del eje de la carretera (los del sombreador).
const BEND_N := 64
## Dibujo, vista de lado: cuánto más cerrada se dibuja la curva que la de verdad y el tope de la curvatura dibujada (1/m).
const VIS_GAIN := 6.0
const VIS_KMAX := 1.0 / 14.0
## Dibujo, vista de lado: cuánto se comprime la S a lo largo (m de carretera de verdad por m de la vista).
const S_STRETCH := 6.0
## Dibujo, vista de persecución: el radio de verdad, con un tope de curvatura (1/m) por debajo de la glorieta.
const CHASE_KMAX := 1.0 / 12.0
## Dibujo: lo que dura la curva en S en la pantalla (s), sea cual sea lo que dura de verdad (la nota del medidor lo dice).
const S_LOOP_S := 8.0
## Dibujo: grados de balanceo de la carrocería por g de aceleración lateral, y el tope (grados).
const ROLL_DEG_PER_G := 5.0
const ROLL_MAX_DEG := 6.0
## Dibujo: grados que se inclina el animal hacia dentro de la curva por g (se agarra contra la fuerza), y el tope.
const LEAN_DEG_PER_G := 14.0
const LEAN_MAX_DEG := 16.0
## Dibujo: el giro de las ruedas delanteras, atan(batalla·κ) (Ackermann, con la batalla del coche del dibujo) por STEER_GAIN,
## con su tope (grados).
const WHEELBASE_M := 2.745
const STEER_GAIN := 3.0
const STEER_MAX_DEG := 30.0
## Dibujo: la cámara de persecución, a CHASE_BACK m por detrás del centro del coche sobre la carretera, CHASE_SIDE m a su
## derecha y CHASE_UP m por encima, mirando a CHASE_AHEAD m por delante, a CHASE_LOOK_Y m del suelo; su campo de visión.
const CHASE_BACK := 4.9
const CHASE_SIDE := 1.4
const CHASE_UP := 2.45
const CHASE_AHEAD := 3.2
const CHASE_LOOK_Y := 1.4
const CHASE_FOV := 46.0
## Dibujo, en un teléfono (la vista mide ~310 × 150 px): la cámara más cerca y más baja, y un campo de visión más cerrado,
## para que el coche y el animal no se queden en un rincón.
const CHASE_COMPACT := { "back": 3.9, "side": 1.0, "up": 2.1, "ahead": 2.8, "look_y": 1.35, "fov": 44.0 }

var x0 := -12.0
var x1 := 18.0
var pts := PackedVector2Array()
var heads := PackedFloat32Array()
var _mat: ShaderMaterial
var _dx := 1.0
## Unidad 4x: hasta dónde llega de lado desde el eje (m) y lo recorrido, para el paisaje.
var _verge := 0.0
var _road_m := 0.0


## Construye la tira de x0 a x1 (m a lo largo, con el centro del coche en un punto del eje) con la textura del asfalto de
## la recta. axis_z: dónde está el eje de la carretera (m); hw: medio ancho del asfalto; verge: ancho del arcén; edge_z y
## center_z: la línea continua del borde y la discontinua; edge2: también la continua del otro borde.
func build(p_x0: float, p_x1: float, axis_z: float, hw: float, verge: float, asphalt: Texture2D, edge_z: float, center_z: float,
		edge2: bool, segs := 64) -> void:
	var xc := CarShape.CAR_L * 0.5
	_dx = (p_x1 - p_x0) / float(BEND_N - 1)
	var ic := roundi((xc - p_x0) / _dx)
	x0 = xc - float(ic) * _dx
	x1 = x0 + float(BEND_N - 1) * _dx
	name = "CarreteraEnCurva"
	var kerb := 0.35
	_verge = verge + hw + kerb  # unidad 4x: hasta dónde llega de lado (el asfalto, el bordillo y el arcén)
	var half := hw + kerb + verge
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, half * 2.0)
	pm.subdivide_width = segs - 1
	pm.subdivide_depth = 1
	pm.center_offset = Vector3((x0 + x1) * 0.5, 0.0, axis_z)
	mesh = pm
	# la curva saca la carretera de su caja: que no la recorte la cámara
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("asphalt", asphalt)
	_mat.set_shader_parameter("x0", x0)
	_mat.set_shader_parameter("x1", x1)
	_mat.set_shader_parameter("road_hw", hw)
	_mat.set_shader_parameter("axis_z", axis_z)
	_mat.set_shader_parameter("edge2", 1.0 if edge2 else 0.0)
	_mat.set_shader_parameter("edge_z", edge_z)
	_mat.set_shader_parameter("center_z", center_z)
	_mat.set_shader_parameter("kerb_w", kerb)
	material_override = _mat
	pts.resize(BEND_N)
	heads.resize(BEND_N)
	set_kappa_const(0.0)


## La carretera corre: road_m es lo recorrido (m).
func set_road(road_m: float) -> void:
	_road_m = road_m  # (4x)
	if _mat != null:
		_mat.set_shader_parameter("road_m", road_m)


## Curvatura dibujada (1/m, + a la izquierda) de una curva de verdad de curvatura k (1/m) en la vista de lado.
static func vis_kappa(k: float) -> float:
	return clampf(k * VIS_GAIN, -VIS_KMAX, VIS_KMAX)


## La misma en la vista de persecución: la de verdad, con su tope.
static func chase_kappa(k: float) -> float:
	return clampf(k, -CHASE_KMAX, CHASE_KMAX)


## Una curva de curvatura k constante (1/m, + a la izquierda).
func set_kappa_const(k: float) -> void:
	set_kappa_fn(func(_a: float) -> float: return k)


## Una carretera de curvatura variable: kappa_at(a) da la curvatura (1/m) a a metros por delante (+) o por detrás (−) del
## centro del coche; se integran el rumbo y el eje desde el coche (tangente en él, en su eje).
func set_kappa_fn(kappa_at: Callable) -> void:
	var xc := CarShape.CAR_L * 0.5
	var ic := roundi((xc - x0) / _dx)
	pts[ic] = Vector2(xc, 0.0)
	heads[ic] = 0.0
	var h := 0.0
	var p := Vector2(xc, 0.0)
	for i in range(ic + 1, BEND_N):
		var a := (float(i - ic) - 0.5) * _dx
		var k := float(kappa_at.call(a))
		var hm := h + k * _dx * 0.5
		p += Vector2(cos(hm), -sin(hm)) * _dx
		h += k * _dx
		pts[i] = p
		heads[i] = h
	h = 0.0
	p = Vector2(xc, 0.0)
	for i in range(ic - 1, -1, -1):
		var a := (float(i - ic) + 0.5) * _dx
		var k := float(kappa_at.call(a))
		var hm := h - k * _dx * 0.5
		p -= Vector2(cos(hm), -sin(hm)) * _dx
		h -= k * _dx
		pts[i] = p
		heads[i] = h
	_mat.set_shader_parameter("path_p", pts)
	_mat.set_shader_parameter("path_h", heads)


## Punto del eje (m, en el plano xz) y su rumbo (rad) a a metros del centro del coche a lo largo de la carretera.
func point_at(a: float) -> Vector3:
	var xc := CarShape.CAR_L * 0.5
	var u := clampf((xc + a - x0) / _dx, 0.0, float(BEND_N - 1))
	var i := mini(int(floorf(u)), BEND_N - 2)
	var f := u - float(i)
	var p := pts[i].lerp(pts[i + 1], f)
	return Vector3(p.x, p.y, lerpf(heads[i], heads[i + 1], f))


## Dónde va la cámara de persecución y adónde mira (en el mundo), con la carretera de ahora: [posición, objetivo]. compact:
## la del teléfono (CHASE_COMPACT).
func chase_pose(compact := false) -> Array:
	var c: Dictionary = CHASE_COMPACT if compact else { "back": CHASE_BACK, "side": CHASE_SIDE, "up": CHASE_UP, "ahead": CHASE_AHEAD,
		"look_y": CHASE_LOOK_Y }
	var back := point_at(-float(c.back))
	var ahead := point_at(float(c.ahead))
	var hb := back.z
	var right := Vector2(sin(hb), cos(hb))
	var pos := Vector3(back.x + right.x * float(c.side), float(c.up), back.y + right.y * float(c.side))
	var look := Vector3(ahead.x, float(c.look_y), ahead.y)
	return [pos, look]


## Balanceo de la carrocería (rad) con la aceleración lateral lat_g (g, + hacia la derecha): hacia fuera de la curva.
static func roll_rad(lat_g: float) -> float:
	return deg_to_rad(clampf(lat_g * ROLL_DEG_PER_G, -ROLL_MAX_DEG, ROLL_MAX_DEG))


## Inclinación del animal (rad, giro en x) con lat_g: hacia dentro de la curva, contra la fuerza.
static func lean_rad(lat_g: float) -> float:
	return -deg_to_rad(clampf(lat_g * LEAN_DEG_PER_G, -LEAN_MAX_DEG, LEAN_MAX_DEG))


## Giro de las ruedas delanteras (rad, + hacia la izquierda) en una curva de curvatura k (1/m, + a la izquierda).
static func steer_rad(k: float) -> float:
	var d := atan(WHEELBASE_M * k) * STEER_GAIN
	return clampf(d, -deg_to_rad(STEER_MAX_DEG), deg_to_rad(STEER_MAX_DEG))


# ════════ Paisaje (unidad 4x) ════════

## Lo recorrido de ahora (m): lo que ha puesto set_road (el paisaje corre con él).
func road_m() -> float:
	return _road_m


## Hasta dónde llega de lado desde el eje lo que pinta esta carretera (m): el asfalto, el bordillo y el arcén.
func edge_m() -> float:
	return _verge
