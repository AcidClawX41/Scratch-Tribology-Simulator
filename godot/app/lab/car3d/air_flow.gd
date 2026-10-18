## El viento alrededor del coche en marcha (unidad 4k): partículas que siguen líneas de corriente por encima del coche y
## a lo largo de su costado y se separan detrás, en una estela con remolinos. Es una ILUSTRACIÓN a la velocidad local del
## modelo, no una simulación del flujo:
##   - la velocidad de cada tramo sale de la física: junto a la chapa, v_local = v·√(1 − Cp) con el Cp de cada zona de
##     MovingCar.ZONES (medido en el DrivAer o estimado, con su fuente: el estado lo da en air_flow().zones), repartido
##     en línea recta entre los puntos de las zonas; donde no hay zona (delante del morro, más allá de la zaga), la del
##     aire libre. Lejos de la chapa vuelve a la del aire libre en DECAY m (dibujo);
##   - la forma de las líneas (se apartan de la silueta, se juntan sobre el techo) y la estela (más lenta, con remolinos)
##     son dibujo: el modelo no calcula el flujo detrás del coche;
##   - el aire respecto al coche (v más el viento de cara; con viento de cola más rápido que el coche, al revés) mueve las
##     partículas; el lateral las hace derivar hacia quien mira; a 0 km/h sin viento, nada. A cámara lenta (la vista).
## Más deprisa, más partículas (density) y estelas más largas. En el teléfono, menos; con movimiento reducido, ninguna
## (la vista lo esconde).
## build() hace una vez las líneas (una textura de flotantes, muestreada a pasos iguales de recorrido del aire libre: donde
## el aire va más deprisa, las muestras se separan) y las partículas (un MultiMesh); en cada fotograma set_air() solo
## cambia parámetros del shader (air_streak.gdshader, que mueve las partículas en la GPU) y cuántas se ven.
extends Node3D

const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const Rng = preload("res://core/shared/rng.gd")
const STREAK_SHADER = preload("res://app/lab/car3d/air_streak.gdshader")

## Dominio (m): de dónde entra el aire (delante del morro) a dónde sale (detrás de la zaga) y hasta dónde sube.
const X_IN := CarShape.CAR_L + 2.4
const X_OUT := -3.4
const Y_TOP := 3.2
## Muestras de cada línea.
const SAMPLES := 192
## Líneas por encima del coche (fracción de la altura libre sobre la silueta) y a lo largo del costado (alto, m).
const TOP_ETA := [0.012, 0.03, 0.055, 0.085, 0.12, 0.165, 0.22, 0.29, 0.38, 0.5, 0.64, 0.8]
const SIDE_Y := [0.34, 0.52, 0.7, 0.86, 1.02, 1.18]
## Holgura de la primera línea sobre la chapa y del costado (m), lo que tarda la velocidad en volver a la del aire libre
## al alejarse de la chapa (m) y el largo de la estela detrás de la zaga (m): dibujo.
const CLEAR0 := 0.035
const SIDE_GAP := 0.13
const DECAY := 0.35
const WAKE_L := 1.6
## Remolinos de la estela: radio (m) y recorrido del aire por vuelta (m): dibujo.
const SWIRL_R := 0.11
const SWIRL_LAMBDA := 0.38
## Capa de render de las partículas (bit de VisualInstance3D.layers): la lupa de la vista no las ve.
const WIND_LAYER := 4
## Partículas: en el escritorio y en el teléfono.
const COUNT := { "escritorio": 320, "movil": 120 }
## Estela de cada partícula: el recorrido del aire en este tiempo de «exposición» (s, a cámara lenta): dibujo.
const EXPOSURE_S := 0.05

var rows := 0
var count := 0
var built := false
var paths_image: Image
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var mat: ShaderMaterial
## Largo de cada línea en recorrido del aire libre (m).
var lengths := PackedFloat32Array()


## Factor de velocidad junto a la chapa en x (m) por encima del coche: las zonas de arriba de MovingCar.ZONES en su x (el
## estado: air_flow().zones, con x desde el morro 0-1) y la del aire libre (1) donde no hay zona. [[x, factor], …] por x.
static func top_profile(zones: Array) -> Array:
	var pts: Array = []
	for z: Dictionary in zones:
		var zz: float = CarShape.ZONE_Z.get(z.id, 0.0)
		if zz >= CarShape.HALF_W - 0.1 or z.id == "barras":
			continue  # las del costado van aparte; las barras están a unos centímetros del techo, como el techo
		pts.append([CarShape.CAR_L * (1.0 - float(z.x)), float(z.factor)])
	pts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return pts


## Factor de velocidad a lo largo del costado: las zonas del costado (retrovisor, ventanilla, aleta) y el aire libre en la
## zaga y en el morro, donde no hay zona.
static func side_profile(zones: Array) -> Array:
	var pts: Array = [[0.0, 1.0]]
	for z: Dictionary in zones:
		var zz: float = CarShape.ZONE_Z.get(z.id, 0.0)
		if zz >= CarShape.HALF_W - 0.1:
			pts.append([CarShape.CAR_L * (1.0 - float(z.x)), float(z.factor)])
	pts.append([CarShape.CAR_L, 1.0])
	pts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return pts


## Interpolación lineal de un perfil [[x, f], …] en x; fuera de él, el primero o el último.
static func profile_at(pts: Array, x: float) -> float:
	if pts.is_empty():
		return 1.0
	if x <= float(pts[0][0]):
		return float(pts[0][1])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
	return float(pts[pts.size() - 1][1])


## La envolvente por encima de la cual pasa el aire (m) en x: la silueta de arriba, una rampa suave delante del morro y
## la burbuja de la estela detrás de la zaga, suavizada (dibujo), sin bajar nunca de la silueta.
static func envelope(top: PackedVector2Array, xs: PackedFloat32Array) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	for x in xs:
		var y := 0.0
		if x >= 0.0 and x <= CarShape.CAR_L:
			var ty := CurveKit.top_y(top, x)
			y = ty if not is_nan(ty) else 0.44
		if x > 4.3:
			y = maxf(y, 0.78 * exp(-(x - 4.3) / 0.55))
		if x < 0.15:
			y = maxf(y, 0.98 * exp((x - 0.15) / WAKE_L))
		raw.append(y)
	var out := PackedFloat32Array()
	var half := 8
	for i in raw.size():
		var s := 0.0
		var n := 0
		for k in range(maxi(0, i - half), mini(raw.size(), i + half + 1)):
			s += raw[k]
			n += 1
		var y := s / float(n)
		var x := xs[i]
		if x >= 0.0 and x <= CarShape.CAR_L:
			var ty := CurveKit.top_y(top, x)
			if not is_nan(ty):
				y = maxf(y, ty)
		out.append(y)
	return out


## Las líneas de corriente muestreadas a pasos iguales de recorrido del aire libre: { image (SAMPLES + 1 columnas por
## línea: x, y, z, factor; la última: largo total y tipo), rows, lengths }. zones: las del estado (air_flow().zones).
static func build_paths(zones: Array, top: PackedVector2Array) -> Dictionary:
	var dx := 0.02
	var xs := PackedFloat32Array()
	var x := X_IN
	while x >= X_OUT:
		xs.append(x)
		x -= dx
	var env := envelope(top, xs)
	var topf := top_profile(zones)
	var sidef := side_profile(zones)
	var lines: Array = []  # [{ pts: PackedVector3Array, f: PackedFloat32Array, kind }]
	for eta: float in TOP_ETA:
		var pts := PackedVector3Array()
		var fs := PackedFloat32Array()
		for i in xs.size():
			var e := env[i]
			var clear := CLEAR0 + eta * (Y_TOP - e)
			var xi := xs[i]
			# delante del morro no hay zona: el aire libre (con un paso suave)
			var near := (profile_at(topf, xi) - 1.0) * (1.0 - smoothstep(CarShape.CAR_L - 0.1, CarShape.CAR_L + 0.5, xi))
			var f := 1.0 + near * exp(-clear / DECAY)
			# la estela: más lenta cuanto más cerca de la zaga y de la burbuja (dibujo, sin datos), con un paso suave
			var wake := 1.0 - 0.5 * exp(minf(xi, 0.2) / 1.0) * exp(-clear / 0.5)
			f = lerpf(f, wake, smoothstep(0.35, -0.25, xi))
			pts.append(Vector3(xi, e + clear, 0.0))
			fs.append(f)
		lines.append({ "pts": pts, "f": fs, "kind": 0 })
	for y0: float in SIDE_Y:
		var pts := PackedVector3Array()
		var fs := PackedFloat32Array()
		var body := CarShape.body_hw(minf(y0, 1.0)) if y0 < 0.97 else CarShape.cabin_hw(y0)
		for i in xs.size():
			var xi := xs[i]
			var z := body + SIDE_GAP
			if xi > 4.2:
				z += 0.3 * (1.0 - exp(-(xi - 4.2) / 0.35)) * exp(-(xi - 4.2) / 1.2)
			if xi < 0.0:
				z -= 0.5 * (1.0 - exp(xi / 1.1))
			var f := 1.0 + (profile_at(sidef, xi) - 1.0) * exp(-SIDE_GAP / DECAY)
			f = lerpf(f, 1.0 - 0.35 * exp(minf(xi, 0.0) / 1.0), smoothstep(0.3, -0.2, xi))
			pts.append(Vector3(xi, y0, z))
			fs.append(f)
		lines.append({ "pts": pts, "f": fs, "kind": 1 })
	var img := Image.create_empty(SAMPLES + 1, lines.size(), false, Image.FORMAT_RGBAF)
	var lens := PackedFloat32Array()
	for r in lines.size():
		var ln: Dictionary = lines[r]
		var pts: PackedVector3Array = ln.pts
		var fs: PackedFloat32Array = ln.f
		# recorrido del aire libre a cada punto: dτ = ds / factor
		var tau := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			var ds := pts[i].distance_to(pts[i - 1])
			tau.append(tau[i - 1] + ds / maxf(0.5 * (fs[i] + fs[i - 1]), 0.05))
		var total := tau[tau.size() - 1]
		lens.append(total)
		var k := 0
		for j in SAMPLES:
			var t := total * float(j) / float(SAMPLES - 1)
			while k < tau.size() - 2 and tau[k + 1] < t:
				k += 1
			var w := clampf((t - tau[k]) / maxf(tau[k + 1] - tau[k], 1e-6), 0.0, 1.0)
			var p := pts[k].lerp(pts[k + 1], w)
			var f := lerpf(fs[k], fs[k + 1], w)
			# remolinos en la estela: la partícula da vueltas mientras la burbuja la arrastra (dibujo)
			if p.x < 0.25:
				var h := p.y - (0.98 * exp(minf(p.x, 0.15) / WAKE_L) if int(ln.kind) == 0 else 0.0)
				var amp := SWIRL_R * smoothstep(0.25, -0.5, p.x) * exp(p.x / 2.4) * exp(-maxf(h, 0.0) / 0.5)
				var th := TAU * t / SWIRL_LAMBDA
				p.x += amp * (cos(th) - 1.0)
				p.y += amp * sin(th)
			img.set_pixel(j, r, Color(p.x, p.y, p.z, f))
		img.set_pixel(SAMPLES, r, Color(total, float(ln.kind), 0.0, 0.0))
	return { "image": img, "rows": lines.size(), "lengths": lens }


## Construye las líneas y las partículas (una vez). zones: las del estado (air_flow().zones); quality: «escritorio» o
## «movil».
func build(zones: Array, top: PackedVector2Array, quality: String) -> void:
	if built:
		return
	built = true
	var p := build_paths(zones, top)
	paths_image = p.image
	rows = p.rows
	lengths = p.lengths
	count = int(COUNT.get(quality, COUNT.escritorio))
	mat = ShaderMaterial.new()
	mat.shader = STREAK_SHADER
	mat.set_shader_parameter("paths", ImageTexture.create_from_image(paths_image))
	mat.set_shader_parameter("samples", SAMPLES)
	mat.set_shader_parameter("x_in", X_IN)
	mat.set_shader_parameter("x_out", X_OUT)
	# la estela: una tira de 5 tramos a lo largo (x: 0 cabeza · 1 cola) y de lado a lado (y: −0,5 · 0,5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 5
	for i in seg + 1:
		var t := float(i) / float(seg)
		st.add_vertex(Vector3(t, -0.5, 0.0))
		st.add_vertex(Vector3(t, 0.5, 0.0))
	for i in seg:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	var strip := st.commit()
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = strip
	mm.instance_count = count
	# las partículas, barajadas: cualquier principio de la lista es una muestra pareja (se ven las primeras N)
	var rng := Rng.new(Rng.seed_of("viento"))
	var top_rows := TOP_ETA.size()
	for i in count:
		var side := rng.next() < 0.28
		var row := top_rows + int(rng.next() * float(SIDE_Y.size())) if side else int(rng.next() * float(top_rows))
		row = mini(row, rows - 1)
		var lane := rng.next() * 0.22 if side else (rng.next() - 0.5) * 1.5
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(float(row), rng.next(), lane, 0.8 + 0.6 * rng.next()))
	mm.visible_instance_count = 0
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Viento"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(X_OUT - 1.0, -0.5, -3.0), Vector3(X_IN - X_OUT + 2.0, Y_TOP + 1.0, 6.0))
	mmi.sorting_offset = 8.0  # delante de las lunas: se pinta después que ellas
	mmi.layers = WIND_LAYER
	add_child(mmi)
	visible = false


## Pone el aire de este fotograma: along_kmh y cross_kmh (el aire respecto al coche, del estado), travel (recorrido del
## aire libre acumulado, m a cámara lenta), speed_ms (su velocidad a cámara lenta, m/s: el largo de las estelas), px_m
## (m por píxel: el grosor), focus (el animal: posición y radio; w < 0, sin animal) y cuántas se ven (density 0-1).
func set_air(along_kmh: float, cross_kmh: float, travel: float, speed_ms: float, px_m: float, focus: Vector4, density: float,
		col: Color, col_fast: Color, col_near: Color) -> void:
	if not built:
		return
	var n := int(roundf(float(count) * clampf(density, 0.0, 1.0)))
	visible = n > 0
	mm.visible_instance_count = n
	if n == 0:
		return
	var along := absf(along_kmh)
	mat.set_shader_parameter("travel", travel)
	mat.set_shader_parameter("flow_sign", 1.0 if along_kmh >= 0.0 else -1.0)
	mat.set_shader_parameter("cross_tan", clampf(cross_kmh / maxf(along, 5.0), 0.0, 2.5))
	mat.set_shader_parameter("trail", clampf(speed_ms * EXPOSURE_S, 0.02, 0.6))
	mat.set_shader_parameter("width_m", maxf(px_m * 2.0, 0.005))
	mat.set_shader_parameter("alpha", 0.45 + 0.35 * clampf(density, 0.0, 1.0))
	mat.set_shader_parameter("focus", focus)
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("color_fast", col_fast)
	mat.set_shader_parameter("color_near", col_near)
