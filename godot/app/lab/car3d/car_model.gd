## El turismo 3D del coche en marcha (solo dibujo), construido en código a partir de su silueta (car_shape.gd): una
## berlina de serie como el DrivAer de la guía. Carrocería y cabina son prismas de perfil con los cantos redondeados
## (el de la cintura, más vivo) y los costados teselados, para que una abolladura hunda la malla de verdad. Unidad 4k:
##   - carrocería: juntas de las puertas, del capó, del maletero y la tapa del depósito (en el shader: siguen la
##     abolladura), tiradores, retrovisores con su brazo, pilares A, B y C, marcos de las ventanillas, pasos de rueda con
##     su guardabarros interior, faldones, frontal con la calandra, la toma de aire, la matrícula en blanco y los
##     antinieblas, limpiaparabrisas, barras del techo y antena (las zonas «barras» y «antena» de MovingCar.ZONES);
##   - lunas de vidrio de verdad (car_glass.gdshader): transparentes y tintadas, con el reflejo de Fresnel, y el interior
##     oscuro detrás (salpicadero, volante y asientos, apenas insinuados); por las dos ventanillas se ve lo de detrás;
##   - ruedas: neumático 225/45 R17 con flanco y dibujo (car_tire.gdshader), llanta de radios con el disco y la pinza del
##     freno detrás; giran según la velocidad y, deprisa, radios y tacos se emborronan (un disco translúcido sin rasgos
##     que dependan del ángulo: sin efecto estroboscópico);
##   - faros y pilotos con su lente y su emisión (la luz de día y la de posición); la de freno sube en las frenadas;
##   - cada carrocería del catálogo con su aspecto (STYLES, dibujo): acero moderno (metalizada con barniz), clásico
##     (pintura sólida, cromados, tapacubos y banda blanca), aluminio (metalizada más viva, marcos de aluminio) y la
##     aleta y los paragolpes de termoplástico del coche de plástico (pintados con otro brillo);
##   - daños en el propio material (set_damage: car_damage.gd y car_damage.gdshaderinc).
## build() crea los nodos una vez; set_paint(), set_style() y set_damage() cambian parámetros de los materiales;
## set_wheels(), set_brake() y set_damage_progress() se llaman en cada fotograma y solo tocan transformaciones y
## parámetros.
extends RefCounted

const MeshKit = preload("res://app/lab/car3d/mesh_kit.gd")
const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const Rng = preload("res://core/shared/rng.gd")
const PAINT_SHADER = preload("res://app/lab/car3d/car_paint.gdshader")
const PART_SHADER = preload("res://app/lab/car3d/car_part.gdshader")
const GLASS_SHADER = preload("res://app/lab/car3d/car_glass.gdshader")
const TIRE_SHADER = preload("res://app/lab/car3d/car_tire.gdshader")

enum { M_PAINT, M_UNDER, M_GLASS, M_INTERIOR, M_TRIM, M_CHROME, M_FRAME, M_HEAD, M_HEAD_SIDE, M_TAIL, M_WELL, M_BAR, M_PLATE,
	M_GRILLE, M_INTAKE, M_HANDLE, M_SEAT, M_FOG, M_CALIPER }

## Aspecto de cada carrocería del catálogo (dibujo): pintura (metálico, rugosidad, barniz y su rugosidad), marcos de las
## lunas y tiradores (negro, cromo, aluminio o pintura), calandra, cromados del clásico, banda blanca y la aleta y los
## paragolpes de plástico.
const STYLES := {
	"coche": { "metallic": 0.5, "rough": 0.3, "coat": 1.0, "coat_rough": 0.04, "frame": "negro", "handle": "pintura", "grille": "negro",
		"classic": false, "plastic": false, "whitewall": 0.0, "caliper": Color(0.16, 0.16, 0.18) },
	"cocheclasico": { "metallic": 0.0, "rough": 0.24, "coat": 0.45, "coat_rough": 0.09, "frame": "cromo", "handle": "cromo", "grille": "cromo",
		"classic": true, "plastic": false, "whitewall": 1.0, "caliper": Color(0.2, 0.2, 0.21) },
	"cochealu": { "metallic": 0.62, "rough": 0.26, "coat": 1.0, "coat_rough": 0.035, "frame": "aluminio", "handle": "pintura", "grille": "negro",
		"classic": false, "plastic": false, "whitewall": 0.0, "caliper": Color(0.55, 0.08, 0.09) },
	"cocheplastico": { "metallic": 0.04, "rough": 0.3, "coat": 1.0, "coat_rough": 0.05, "frame": "negro", "handle": "pintura", "grille": "negro",
		"classic": false, "plastic": true, "whitewall": 0.0, "caliper": Color(0.16, 0.16, 0.18) },
	# el deportivo (core/lab/sports_car.gd, unidad 4r): pintura lisa (azul: con metalizado, el cielo morado de la carretera volvía marrón el amarillo de antes) con barniz fino, marcos negros, pinzas de freno
	# rojas; su carrocería es la del turismo escalada (shape: el mismo largo, un 10 % más baja y un 3 % más ancha, las
	# medidas de su ficha), que se pasa a build
	"deportivo": { "metallic": 0.12, "rough": 0.22, "coat": 1.0, "coat_rough": 0.03, "frame": "negro", "handle": "pintura", "grille": "negro",
		"classic": false, "plastic": false, "whitewall": 0.0, "caliper": Color(0.62, 0.07, 0.08) },
}
## Los trocitos de la ventanilla templada que estalla: cuántos, la gravedad de su caída en la animación (m/s²: a cámara
## lenta, como la carretera) y lo que dura (s). Dibujo.
const SHARDS := 90
const SHARD_G := 3.2
const SHARD_S := 2.2
## Puntos del contorno de cada ventanilla que se pasan a las lunas (car_glass.gdshader, WIN_PTS).
const WIN_PTS := 12
const FRAME_LOOK := { "negro": [Color(0.03, 0.03, 0.034), 0.0, 0.42], "cromo": [Color(0.9, 0.91, 0.93), 1.0, 0.07],
	"aluminio": [Color(0.72, 0.73, 0.75), 0.9, 0.3] }

var root: Node3D
var paint: ShaderMaterial
var glass: ShaderMaterial
var mats := {}
## Materiales que leen los daños (la pintura, las lunas y las piezas pegadas a la chapa).
var damage_mats: Array[ShaderMaterial] = []
## Las capas de la pintura y el panel (µm) que ven los sombreadores de los daños (set_layer_depths; unidad 4s).
var layer_depths := Vector4(45.0, 60.0, 85.0, 110.0)
var panel_um := 810.0
var wheels: Array = []  # [{ pivot: Node3D, blur_mat: StandardMaterial3D, tire: ShaderMaterial, alloy: Node3D, cap: Node3D }]
var tail_mat: ShaderMaterial
var head_mat: ShaderMaterial
var classic_parts: Node3D
var style := "coche"
## Escala de la carrocería con la que se construyó (unidad 4r: el deportivo; Vector3.ONE en el turismo). Las ruedas no
## se escalan: son las mismas (225/45 R17).
var shape := Vector3.ONE
## Puertas por lado (unidad 4r: 2 en el deportivo, un cupé; 4 en los demás): las juntas y los tiradores.
var doors := 4
var windows: Array = []  # [delantera, trasera] (XY, m)
var nodes := 0  # nodos creados (para las pruebas)
var triangles := 0
var damage_version := 0
## La ventanilla templada que estalla: los trocitos que caen (un MultiMesh que se crea la primera vez y se reutiliza).
var shards: MultiMeshInstance3D
var shard_runs := 0
var _shard_p0 := PackedVector3Array()
var _shard_v := PackedVector3Array()
var _shard_spin := PackedVector3Array()
var _shard_size := PackedFloat32Array()
var _paint_col := Color.WHITE


# ════════ Materiales ════════

static func _part(c: Color, metallic: float, rough: float, pattern := 0, emit := Color.BLACK, energy := 0.0, coat := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PART_SHADER
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("emission_color", emit)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("coat", coat)
	return m


static func _std(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


## Materiales físicos del coche (paint_col: el color de la pintura).
func _materials(paint_col: Color) -> void:
	paint = ShaderMaterial.new()
	paint.shader = PAINT_SHADER
	mats[M_PAINT] = paint
	glass = ShaderMaterial.new()
	glass.shader = GLASS_SHADER
	mats[M_GLASS] = glass
	mats[M_UNDER] = _part(Color(0.05, 0.05, 0.055), 0.0, 0.9, 2)
	mats[M_INTERIOR] = _std(Color(0.028, 0.028, 0.031), 0.0, 0.9)
	mats[M_SEAT] = _std(Color(0.045, 0.044, 0.048), 0.0, 0.95)
	mats[M_TRIM] = _part(Color(0.03, 0.03, 0.034), 0.0, 0.45)
	mats[M_CHROME] = _part(Color(0.9, 0.91, 0.93), 1.0, 0.07)
	mats[M_FRAME] = _part(Color(0.03, 0.03, 0.034), 0.0, 0.42)
	mats[M_HANDLE] = _part(paint_col, 0.4, 0.3, 0, Color.BLACK, 0.0, 1.0)
	head_mat = _part(Color(0.1, 0.1, 0.11), 0.3, 0.2, 4, Color(1.0, 0.95, 0.86), 2.2)
	mats[M_HEAD] = head_mat
	mats[M_HEAD_SIDE] = _part(Color(0.55, 0.56, 0.6), 0.9, 0.12, 0, Color(1.0, 0.95, 0.86), 0.25, 1.0)
	tail_mat = _part(Color(0.42, 0.02, 0.05), 0.0, 0.12, 5, Color(1.0, 0.1, 0.12), 0.7)
	mats[M_TAIL] = tail_mat
	mats[M_WELL] = _part(Color(0.022, 0.022, 0.025), 0.0, 0.95, 6)
	mats[M_BAR] = _part(Color(0.62, 0.64, 0.68), 0.85, 0.32)
	mats[M_PLATE] = _part(Color(0.86, 0.87, 0.88), 0.0, 0.45, 3)
	mats[M_GRILLE] = _part(Color(0.05, 0.05, 0.055), 0.2, 0.35, 1)
	mats[M_INTAKE] = _part(Color(0.03, 0.03, 0.033), 0.0, 0.6, 1)
	mats[M_FOG] = _part(Color(0.7, 0.72, 0.75), 0.9, 0.1, 0, Color(1.0, 0.97, 0.9), 0.15, 1.0)
	mats[M_CALIPER] = _std(Color(0.16, 0.16, 0.18), 0.3, 0.45)
	damage_mats.clear()
	for k: int in mats:
		if mats[k] is ShaderMaterial and k != M_GLASS:
			damage_mats.append(mats[k])
	damage_mats.append(glass)
	_paint_col = paint_col
	set_style("coche")


## Una MeshInstance3D con la malla del acumulador y el material de cada superficie.
func _instance(parent: Node3D, b: MeshKit.Builder, node_name: String, scaled := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	if scaled:
		b.scale(shape)
	mi.mesh = b.commit()
	var ids := b.ids()
	for k in ids.size():
		mi.set_surface_override_material(k, mats[int(ids[k])])
	parent.add_child(mi)
	nodes += 1
	triangles += b.triangles()
	return mi


# ════════ Construcción ════════

## Construye el coche bajo parent. mobile: menos segmentos, una rejilla más gruesa y menos detalle en las ruedas.
## p_shape: la escala de la carrocería por eje (unidad 4r: el deportivo, más bajo y más ancho; las ruedas no cambian);
## p_doors: las puertas por lado (2: el cupé).
func build(parent: Node3D, paint_col: Color, mobile := false, p_shape := Vector3.ONE, p_doors := 4) -> void:
	shape = p_shape
	doors = p_doors
	_materials(paint_col)
	root = Node3D.new()
	root.name = "Coche"
	parent.add_child(root)
	nodes += 1
	var seg := 3 if mobile else 5
	var tess := 0.08 if mobile else 0.05
	var strips := 12 if mobile else 24
	windows = CarShape.side_windows()
	# ── carrocería: el perfil sin la cabina, a todo el ancho; la parte de arriba bajo las lunas es el interior
	var body := MeshKit.Builder.new()
	var bo: Array = CarShape.body_outline()
	var bm := PackedInt32Array()
	for m: int in (bo[1] as PackedInt32Array):
		bm.append({ 0: M_PAINT, 1: M_UNDER, 3: M_INTERIOR }[m])
	MeshKit.prism(body, bo[0], CarShape.body_section(), bo[2], seg, bm, M_PAINT, { "tess": tess, "strips": strips })
	_body_details(body, mobile)
	_instance(root, body, "Carroceria")
	# ── cabina: parabrisas, techo y luneta, más estrecha y cayendo hacia dentro, con los huecos de las ventanillas
	var cab := MeshKit.Builder.new()
	var co: Array = CarShape.cabin_outline()
	var cm := PackedInt32Array()
	for m: int in (co[1] as PackedInt32Array):
		cm.append({ 0: M_PAINT, 2: M_GLASS, 3: M_INTERIOR }[m])
	var holes: Array = []
	for w: PackedVector2Array in windows:
		var grown: Array = Geometry2D.offset_polygon(w, CarShape.FRAME_W, Geometry2D.JOIN_MITER)
		if not grown.is_empty():
			holes.append(grown[0])
	MeshKit.prism(cab, co[0], MeshKit.linear_section(CarShape.CABIN_HW_BELT, CarShape.CABIN_HW_ROOF, 0.95, 1.395), co[2], seg, cm,
		M_PAINT, { "strips": maxi(strips - 4, 8), "holes": holes, "y_cut": 1.15 })
	_cabin_details(cab)
	_instance(root, cab, "Cabina")
	# ── interior, apenas insinuado detrás de las lunas
	var inside := MeshKit.Builder.new()
	_interior(inside)
	_instance(root, inside, "Interior")
	# ── frontal y luces
	var front := MeshKit.Builder.new()
	_front(front)
	_instance(root, front, "Frontal")
	# ── cromados del clásico (se ven solo con él)
	classic_parts = Node3D.new()
	classic_parts.name = "Clasico"
	root.add_child(classic_parts)
	nodes += 1
	var chrome := MeshKit.Builder.new()
	_classic(chrome)
	_instance(classic_parts, chrome, "Cromados")
	# ── ruedas
	for i in 2:
		_wheel(float(CarShape.WHEEL_X[i]), mobile)
	_glass_setup()
	_seams_setup()
	set_style(style)
	set_damage(CarDamage.empty())


## Detalles de la carrocería: faldones, tiradores, retrovisor con su brazo, pilotos y faros del costado, pasos de rueda
## con su guardabarros interior y la chapa de dentro que tapa el hueco.
func _body_details(b: MeshKit.Builder, mobile: bool) -> void:
	var side := func(y: float) -> float: return CarShape.body_hw(y)
	# faldón negro entre las ruedas
	MeshKit.flat(b, M_TRIM, PackedVector2Array([Vector2(1.40, 0.255), Vector2(3.33, 0.255), Vector2(3.30, 0.325), Vector2(1.43, 0.325)]),
		side, Vector3(0.0, -0.3, 1.0), 0.004, 0.0 if mobile else 0.06)
	MeshKit.flat(b, M_TRIM, PackedVector2Array([Vector2(1.40, 0.255), Vector2(3.33, 0.255), Vector2(3.30, 0.325), Vector2(1.43, 0.325)]),
		func(y: float) -> float: return -CarShape.body_hw(y), Vector3(0.0, -0.3, -1.0), 0.004)
	# tiradores: una barra y el hueco oscuro detrás, pegados a la chapa (siguen la abolladura)
	for h: Array in (CarShape.COUPE_HANDLES if doors == 2 else CarShape.HANDLES):
		var x0 := float(h[0])
		var x1 := float(h[1])
		var y := float(h[2])
		var z := CarShape.body_hw(y)
		MeshKit.flat(b, M_TRIM, PackedVector2Array([Vector2(x0 - 0.01, y - 0.026), Vector2(x1 + 0.01, y - 0.026), Vector2(x1 + 0.01, y - 0.004),
			Vector2(x0 - 0.01, y - 0.004)]), side, CarShape.body_normal(y), 0.0015)
		MeshKit.box(b, M_HANDLE, Vector3(x0, y - 0.013, z - 0.004), Vector3(x1, y + 0.012, z + 0.016))
	# retrovisor: brazo negro desde la puerta y la carcasa del color de la carrocería
	var mz: Vector2 = CarShape.MIRROR_Z
	MeshKit.tube(b, M_TRIM, PackedVector3Array([Vector3(3.10, 0.985, CarShape.body_hw(0.985) - 0.02), Vector3(3.09, 1.01, mz.x + 0.02)]), 0.016, 6)
	var mb := MeshKit.Builder.new()
	MeshKit.prism(mb, PackedVector2Array(CarShape.MIRROR), MeshKit.linear_section((mz.y - mz.x) * 0.5, (mz.y - mz.x) * 0.5, 0.0, 1.0), 0.02, 3,
		PackedInt32Array(), 0)
	var mesh := mb.commit()
	b.merge(M_PAINT, mesh, Vector3(0.0, 0.0, (mz.x + mz.y) * 0.5))
	b.merge(M_PAINT, mesh, Vector3(0.0, 0.0, -(mz.x + mz.y) * 0.5))
	# pilotos y faros del costado
	for sgn: float in [1.0, -1.0]:
		var sd := func(y: float) -> float: return sgn * CarShape.body_hw(y)
		MeshKit.flat(b, M_HEAD_SIDE, PackedVector2Array(CarShape.HEADLIGHT), sd, Vector3(0.25, 0.1, sgn), 0.006)
		MeshKit.flat(b, M_TAIL, PackedVector2Array(CarShape.TAILLIGHT), sd, Vector3(-0.25, 0.0, sgn), 0.006)
	# pasos de rueda: el guardabarros interior (medio cilindro granulado) y la chapa de dentro
	for i in 2:
		var cx := float(CarShape.WHEEL_X[i])
		var r := CarShape.ARCH_R - 0.012
		var steps := 12 if mobile else 20
		for sgn: float in [1.0, -1.0]:
			var z_out := sgn * (CarShape.HALF_W - 0.045)
			var z_in := sgn * (CarShape.WHEEL_Z - 0.17)
			var prev := -1
			var prev_in := -1
			for k in steps + 1:
				var a := PI * float(k) / float(steps)
				var d := Vector3(cos(a), sin(a), 0.0)
				var c := Vector3(cx, CarShape.WHEEL_R, 0.0) + d * r
				var o := b.add(M_WELL, Vector3(c.x, c.y, z_out), -d, Vector2(a, 0.0))
				var n := b.add(M_WELL, Vector3(c.x, c.y, z_in), -d, Vector2(a, 1.0))
				if prev >= 0:
					b.quad(M_WELL, prev, o, n, prev_in)
				prev = o
				prev_in = n
			var ring := PackedVector2Array()
			for k in 25:
				var a := PI * float(k) / 24.0
				ring.append(Vector2(cx + CarShape.ARCH_R * cos(a), CarShape.WHEEL_R + CarShape.ARCH_R * sin(a)))
			ring.append(Vector2(cx - CarShape.ARCH_R, 0.05))
			ring.append(Vector2(cx + CarShape.ARCH_R, 0.05))
			var zw := z_in
			MeshKit.flat(b, M_WELL, ring, func(_y: float) -> float: return zw, Vector3(0.0, 0.0, sgn), 0.0)


## Detalles de la cabina: marcos de las lunas, lunas laterales, pilar B negro, junta de goma de la cintura,
## limpiaparabrisas, barras del techo y antena.
func _cabin_details(b: MeshKit.Builder) -> void:
	var nrm := Vector3(0.0, (CarShape.CABIN_HW_BELT - CarShape.CABIN_HW_ROOF) / (1.395 - 0.95), 1.0)
	for sgn: float in [1.0, -1.0]:
		var hw := func(y: float) -> float: return sgn * CarShape.cabin_hw(y)
		var hw_in := func(y: float) -> float: return sgn * (CarShape.cabin_hw(y) - 0.006)
		var n := Vector3(nrm.x, nrm.y, nrm.z * sgn)
		for w: PackedVector2Array in windows:
			for piece: PackedVector2Array in MeshKit.ring(w, CarShape.FRAME_W, 1.15):
				MeshKit.flat(b, M_FRAME, piece, hw, n, 0.002)
			MeshKit.flat(b, M_GLASS, w, hw_in, n, 0.0)
		# pilar B negro
		MeshKit.flat(b, M_TRIM, PackedVector2Array([Vector2(CarShape.B_X.x - 0.02, 0.975), Vector2(CarShape.B_X.y + 0.02, 0.975),
			Vector2(CarShape.B_X.y + 0.02, 1.30), Vector2(CarShape.B_X.x - 0.02, 1.30)]), hw, n, 0.003)
	# limpiaparabrisas: dos brazos negros tumbados sobre el pie del parabrisas
	for zw: float in [0.3, -0.34]:
		MeshKit.tube(b, M_TRIM, PackedVector3Array([Vector3(3.13, 0.95, zw), Vector3(3.07, 0.99, zw - 0.12), Vector3(3.03, 1.02, zw - 0.36)]), 0.009, 5)
		MeshKit.tube(b, M_TRIM, PackedVector3Array([Vector3(3.035, 1.018, zw - 0.02), Vector3(3.065, 0.998, zw - 0.52)]), 0.006, 4)
	# barras del techo: dos largueros de aluminio sobre sus pies
	for zb: float in [CarShape.BAR_Z, -CarShape.BAR_Z]:
		MeshKit.box(b, M_BAR, Vector3(float(CarShape.BAR_X[0]), CarShape.BAR_Y - 0.022, zb - 0.022), Vector3(float(CarShape.BAR_X[1]), CarShape.BAR_Y, zb + 0.022))
		for fx: float in CarShape.BAR_FEET:
			MeshKit.box(b, M_TRIM, Vector3(fx - 0.035, 1.38, zb - 0.03), Vector3(fx + 0.035, CarShape.BAR_Y - 0.02, zb + 0.03))
	# antena de varilla sobre su base
	var a0: Vector2 = CarShape.ANTENNA[0]
	var a1: Vector2 = CarShape.ANTENNA[1]
	MeshKit.box(b, M_TRIM, Vector3(a0.x - 0.035, a0.y - 0.03, -0.022), Vector3(a0.x + 0.035, a0.y + 0.012, 0.022))
	MeshKit.rod(b, M_TRIM, Vector3(a0.x, a0.y, 0.0), Vector3(a1.x, a1.y, 0.0), 0.0035, 6)


## El interior, oscuro y apenas insinuado: salpicadero, volante (a la izquierda, lejos de quien mira: el costado que se
## ve es el derecho) y los asientos con sus cabezales.
func _interior(b: MeshKit.Builder) -> void:
	# salpicadero: por debajo del parabrisas (su parte de delante baja con él)
	MeshKit.box(b, M_INTERIOR, Vector3(2.70, 0.8, -0.72), Vector3(2.95, 0.99, 0.72))
	MeshKit.box(b, M_INTERIOR, Vector3(2.95, 0.8, -0.72), Vector3(3.07, 0.925, 0.72))
	MeshKit.box(b, M_INTERIOR, Vector3(0.80, 0.9, -0.7), Vector3(1.05, 1.0, 0.7))
	# volante: un aro inclinado y su columna
	var c := Vector3(2.66, 1.02, -0.37)
	var ring := PackedVector3Array()
	var ax := Vector3(-0.9, 0.44, 0.0).normalized()
	var u := Vector3(0.0, 0.0, 1.0)
	var v := ax.cross(u).normalized()
	for k in 17:
		var a := TAU * float(k) / 16.0
		ring.append(c + (u * cos(a) + v * sin(a)) * 0.185)
	MeshKit.tube(b, M_SEAT, ring, 0.014, 5)
	MeshKit.rod(b, M_INTERIOR, c, c + Vector3(0.28, -0.14, 0.0), 0.03, 6)
	for s: Array in CarShape.SEATS:
		var x := float(s[0])
		var z := float(s[1])
		var front := x > 1.8
		var lean := deg_to_rad(18.0 if front else 22.0)
		var basis := Basis(Vector3.BACK, lean)
		var h := Vector3(0.07, 0.3, 0.24) if front else Vector3(0.07, 0.26, 0.34)
		var sc := Vector3(x, 0.82 if front else 0.74, z * (1.0 if front else 0.95))
		MeshKit.obox(b, M_SEAT, sc, h, basis)
		var top := sc + basis.y * h.y
		MeshKit.obox(b, M_SEAT, top + basis.y * 0.11, Vector3(0.06, 0.09, 0.13), basis)


## El frontal (en la cara del morro): calandra, toma de aire, matrícula en blanco, faros y antinieblas; y los pilotos en
## la tapa del maletero.
func _front(b: MeshKit.Builder) -> void:
	var nose := func(y: float) -> float: return CarShape.nose_x(y)
	var tail := func(y: float) -> float: return CarShape.tail_x(y)
	var g: Rect2 = CarShape.GRILLE
	MeshKit.face_patch(b, M_GRILLE, nose, 1.0, g.position.y, g.end.y, -g.size.x, g.size.x, 0.004, 4, 6)
	var it: Rect2 = CarShape.INTAKE
	MeshKit.face_patch(b, M_INTAKE, nose, 1.0, it.position.y, it.end.y, -it.size.x, it.size.x, 0.004, 2, 6)
	var pl: Rect2 = CarShape.PLATE
	MeshKit.face_patch(b, M_PLATE, nose, 1.0, pl.position.y, pl.end.y, -pl.size.x, pl.size.x, 0.007, 2, 4)
	var hf: Rect2 = CarShape.HEAD_FRONT
	var fg: Rect2 = CarShape.FOG
	var tb: Rect2 = CarShape.TAIL_BACK
	for sgn: float in [1.0, -1.0]:
		var z0 := hf.position.x if sgn > 0.0 else -hf.end.x
		var z1 := hf.end.x if sgn > 0.0 else -hf.position.x
		MeshKit.face_patch(b, M_HEAD, nose, 1.0, hf.position.y, hf.end.y, z0, z1, 0.005, 3, 5)
		var f0 := fg.position.x if sgn > 0.0 else -fg.end.x
		var f1 := fg.end.x if sgn > 0.0 else -fg.position.x
		MeshKit.face_patch(b, M_FOG, nose, 1.0, fg.position.y, fg.end.y, f0, f1, 0.005, 1, 2)
		var t0 := tb.position.x if sgn > 0.0 else -tb.end.x
		var t1 := tb.end.x if sgn > 0.0 else -tb.position.x
		MeshKit.face_patch(b, M_TAIL, tail, -1.0, tb.position.y, tb.end.y, t0, t1, 0.005, 2, 5)


## Cromados del coche clásico: los paragolpes de hoja (delante y detrás, doblando hacia los costados) y la moldura de la
## cintura.
func _classic(b: MeshKit.Builder) -> void:
	var nose := func(y: float) -> float: return CarShape.nose_x(y)
	var tail := func(y: float) -> float: return CarShape.tail_x(y)
	MeshKit.face_patch(b, M_CHROME, nose, 1.0, 0.43, 0.475, -0.82, 0.82, 0.018, 2, 8)
	MeshKit.face_patch(b, M_CHROME, tail, -1.0, 0.5, 0.545, -0.82, 0.82, 0.018, 2, 8)
	for sgn: float in [1.0, -1.0]:
		var sd := func(y: float) -> float: return sgn * CarShape.body_hw(y)
		MeshKit.flat(b, M_CHROME, PackedVector2Array([Vector2(4.2, 0.43), Vector2(4.47, 0.43), Vector2(4.47, 0.475), Vector2(4.2, 0.475)]), sd,
			Vector3(0.0, 0.0, sgn), 0.016)
		MeshKit.flat(b, M_CHROME, PackedVector2Array([Vector2(0.02, 0.5), Vector2(0.3, 0.5), Vector2(0.3, 0.545), Vector2(0.02, 0.545)]), sd,
			Vector3(0.0, 0.0, sgn), 0.016)
		MeshKit.flat(b, M_CHROME, PackedVector2Array([Vector2(1.13, 0.943), Vector2(3.07, 0.93), Vector2(3.07, 0.942), Vector2(1.13, 0.955)]), sd,
			Vector3(0.0, 0.5, sgn), 0.004)


## Una rueda en x: neumático de goma con su dibujo, llanta de aleación de cinco radios dobles (o, en el clásico, el
## tapacubos cromado sobre la llanta de acero), disco de freno detrás y su pinza (fija al coche), y el disco translúcido
## que desenfoca los radios al girar deprisa. Gira alrededor de z en un pivote.
func _wheel(x: float, mobile: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = "Rueda"
	pivot.position = Vector3(x, CarShape.WHEEL_R, CarShape.WHEEL_Z)
	root.add_child(pivot)
	nodes += 1
	var sides := 32 if mobile else 56
	var tw := CarShape.TIRE_W * 0.5
	var rim_r := CarShape.RIM_R
	var tire := PackedVector2Array([Vector2(-tw * 0.89, rim_r - 0.002), Vector2(-tw * 0.98, rim_r + 0.024), Vector2(-tw, rim_r + 0.058),
		Vector2(-tw * 0.95, rim_r + 0.082), Vector2(-tw * 0.78, CarShape.WHEEL_R - 0.001), Vector2(-tw * 0.35, CarShape.WHEEL_R),
		Vector2(tw * 0.35, CarShape.WHEEL_R), Vector2(tw * 0.78, CarShape.WHEEL_R - 0.001), Vector2(tw * 0.95, rim_r + 0.082),
		Vector2(tw, rim_r + 0.058), Vector2(tw * 0.98, rim_r + 0.024), Vector2(tw * 0.89, rim_r - 0.002)])
	var tm := MeshInstance3D.new()
	tm.name = "Neumatico"
	tm.mesh = MeshKit.revolve_z(tire, sides, true)
	var tmat := ShaderMaterial.new()
	tmat.shader = TIRE_SHADER
	tm.material_override = tmat
	pivot.add_child(tm)
	# fondo de la llanta y disco de freno (gira con la rueda)
	var back := MeshInstance3D.new()
	back.mesh = MeshKit.disc_z(0.0, rim_r, -0.05, 32)
	back.material_override = _std(Color(0.02, 0.02, 0.025), 0.0, 1.0)
	pivot.add_child(back)
	var disc := MeshInstance3D.new()
	disc.mesh = MeshKit.disc_z(0.06, 0.165, 0.012, 40)
	disc.material_override = _std(Color(0.36, 0.35, 0.37), 0.85, 0.42)
	pivot.add_child(disc)
	# llanta de aleación: aro y cinco radios dobles con el buje
	var alloy := Node3D.new()
	alloy.name = "Aleacion"
	pivot.add_child(alloy)
	var rim := MeshKit.Builder.new()
	var lip := PackedVector2Array([Vector2(0.074, rim_r), Vector2(0.086, rim_r - 0.002), Vector2(0.09, rim_r - 0.014), Vector2(0.086, rim_r - 0.024),
		Vector2(0.06, rim_r - 0.03)])
	rim.merge(0, MeshKit.revolve_z(lip, sides, true))
	for k in 5:
		for sd: float in [-1.0, 1.0]:
			var a := TAU * float(k) / 5.0 + sd * 0.11
			var dir := Vector3(cos(a), sin(a), 0.0)
			var perp := Vector3(-dir.y, dir.x, 0.0)
			var p0 := dir * 0.05
			var p1 := dir * (rim_r - 0.024)
			var q := [p0 - perp * 0.017, p1 - perp * 0.011, p1 + perp * 0.011, p0 + perp * 0.017]
			var f: Array = []
			var bk: Array = []
			for pt: Vector3 in q:
				f.append(rim.add(0, pt + Vector3(0, 0, 0.085), Vector3(0, 0, 1)))
				bk.append(rim.add(0, pt + Vector3(0, 0, 0.055), perp.normalized()))
			rim.quad(0, f[0], f[1], f[2], f[3])
			rim.quad(0, bk[0], bk[1], f[1], f[0])
			rim.quad(0, bk[3], f[3], f[2], bk[2])
	var hub := PackedVector2Array([Vector2(0.098, 0.0), Vector2(0.097, 0.02), Vector2(0.092, 0.042), Vector2(0.08, 0.055), Vector2(0.06, 0.058)])
	rim.merge(1, MeshKit.revolve_z(hub, 20, true))
	var rmi := MeshInstance3D.new()
	rmi.mesh = rim.commit()
	rmi.set_surface_override_material(0, _std(Color(0.72, 0.74, 0.78), 0.92, 0.24))
	rmi.set_surface_override_material(1, _std(Color(0.86, 0.88, 0.92), 1.0, 0.1))
	alloy.add_child(rmi)
	# el clásico: llanta de acero pintada con el tapacubos cromado
	var cap := Node3D.new()
	cap.name = "Tapacubos"
	pivot.add_child(cap)
	var steel := MeshInstance3D.new()
	steel.mesh = MeshKit.disc_z(0.0, rim_r, 0.05, 40)
	steel.material_override = _std(Color(0.1, 0.1, 0.11), 0.3, 0.5)
	cap.add_child(steel)
	var dome := MeshInstance3D.new()
	dome.mesh = MeshKit.revolve_z(PackedVector2Array([Vector2(0.055, 0.17), Vector2(0.075, 0.15), Vector2(0.092, 0.1), Vector2(0.1, 0.04),
		Vector2(0.101, 0.0)]), sides, true)
	dome.material_override = _std(Color(0.9, 0.91, 0.93), 1.0, 0.08)
	cap.add_child(dome)
	# pinza del freno: fija al coche, arriba y detrás del disco
	var cal := MeshInstance3D.new()
	var cb := MeshKit.Builder.new()
	MeshKit.obox(cb, 0, Vector3(x - 0.1, CarShape.WHEEL_R + 0.1, CarShape.WHEEL_Z + 0.03), Vector3(0.035, 0.05, 0.022), Basis(Vector3.BACK, 0.8))
	cal.mesh = cb.commit()
	cal.material_override = mats[M_CALIPER]
	root.add_child(cal)
	# desenfoque: disco translúcido con el barrido de los radios (bandas concéntricas, sin nada que dependa del ángulo)
	var blur_mat := StandardMaterial3D.new()
	blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_mat.albedo_texture = _blur_texture()
	blur_mat.albedo_color = Color(1, 1, 1, 0.0)
	blur_mat.metallic = 0.7
	blur_mat.roughness = 0.4
	blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bmi := MeshInstance3D.new()
	bmi.mesh = MeshKit.disc_z(0.0, rim_r - 0.022, 0.092, 48)
	bmi.material_override = blur_mat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(bmi)
	nodes += 10
	wheels.append({ "pivot": pivot, "blur_mat": blur_mat, "tire": tmat, "alloy": alloy, "cap": cap })


## Textura radial del desenfoque de la llanta: v = radio relativo (0 el centro, 1 el aro).
static func _blur_texture() -> ImageTexture:
	var img := Image.create_empty(4, 64, false, Image.FORMAT_RGBA8)
	for j in 64:
		var f := float(j) / 63.0
		var c: Color
		if f < 0.27:
			c = Color(0.82, 0.84, 0.88, 1.0)  # buje
		elif f < 0.93:
			c = Color(0.5, 0.51, 0.55, 0.92 - 0.2 * (f - 0.27))  # radios barridos, sobre el fondo oscuro y el disco
		else:
			c = Color(0.74, 0.76, 0.8, 1.0)  # aro
		for i in 4:
			img.set_pixel(i, j, c)
	return ImageTexture.create_from_image(img)


## El contorno de una ventanilla en n puntos repartidos por su perímetro (el shader de las lunas los lee para dejar los
## trozos del templado en el marco).
static func window_outline(w: PackedVector2Array, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if w.is_empty():
		for k in n:
			out.append(Vector2.ZERO)
		return out
	var ring := w.duplicate()
	ring.append(w[0])
	var total := CurveKit.total(ring)
	for k in n:
		out.append(CurveKit.at_length(ring, total * float(k) / float(n)))
	return out


## Parámetros fijos de las lunas: los contornos de las ventanillas (para dejar los trozos del templado en el marco).
func _glass_setup() -> void:
	for i in 2:
		var w: PackedVector2Array = windows[i] if i < windows.size() else PackedVector2Array()
		for k in w.size():
			w[k] = Vector2(w[k].x * shape.x, w[k].y * shape.y)
		windows[i] = w
		glass.set_shader_parameter("win_front" if i == 0 else "win_rear", window_outline(w, WIN_PTS))
	glass.set_shader_parameter("rear_x", (CarShape.B_X.x + CarShape.B_X.y) * 0.5 * shape.x)
	glass.set_shader_parameter("crack_e1", Vector3(-0.63, 0.45, 0.0).normalized())


## Juntas de los paneles en la pintura (car_paint.gdshader): las de las puertas en los costados; las del capó y de la
## tapa del maletero arriba, a ±LID_Z del eje y de lado a lado; y la tapa del depósito. Holgura de 4 mm (dibujo: las de
## un coche de serie miden 3-5 mm).
func _seams_setup() -> void:
	var gap := 0.004
	var ab: Array[Vector4] = []
	var sp: Array[Vector4] = []
	for sx: float in (CarShape.COUPE_SEAMS_X if doors == 2 else CarShape.SEAMS_X):
		var x := sx * shape.x
		ab.append(Vector4(x, 0.3 * shape.y, x, 0.955 * shape.y))
		sp.append(Vector4(1.0, 1.0, gap, 0.0))
	var lid_z := CarShape.LID_Z * shape.z
	for span: Vector2 in [CarShape.HOOD_X, CarShape.TRUNK_X]:
		ab.append(Vector4(span.x * shape.x, lid_z, span.y * shape.x, lid_z))
		sp.append(Vector4(0.0, 1.0, gap, 0.0))
		for x: float in [span.x * shape.x, span.y * shape.x]:
			ab.append(Vector4(x, -lid_z, x, lid_z))
			sp.append(Vector4(0.0, 0.0, gap, 0.0))
	paint.set_shader_parameter("n_seams", ab.size())
	while ab.size() < 16:
		ab.append(Vector4.ZERO)
		sp.append(Vector4.ZERO)
	paint.set_shader_parameter("seam_ab", ab)
	paint.set_shader_parameter("seam_p", sp)
	var f: Vector3 = CarShape.FUEL_FLAP
	paint.set_shader_parameter("fuel_flap", Vector4(f.x * shape.x, f.y * shape.y, f.z, 1.0))
	paint.set_shader_parameter("fender_zone", Vector3(3.10 * shape.x, 4.40 * shape.x, 0.97 * shape.y))
	paint.set_shader_parameter("bumper_zone", Vector3(0.22 * shape.x, 4.28 * shape.x, 0.62 * shape.y))


# ════════ Aspecto ════════

## Cambia el color de la pintura (sin rehacer las mallas).
func set_paint(c: Color) -> void:
	_paint_col = c
	if paint != null:
		paint.set_shader_parameter("paint_color", c)
		(mats[M_HANDLE] as ShaderMaterial).set_shader_parameter("albedo", c if String(STYLES[style].handle) == "pintura" else Color(0.9, 0.91, 0.93))


## Aspecto de la carrocería (id del objetivo del coche: STYLES) y colores de las capas de la pintura (layers: los de
## Catalog.car_layers del objetivo, del barniz a la carrocería; body_metal: la carrocería es de metal).
func set_style(id: String, layers: Array = [], body_metal := true) -> void:
	style = id if STYLES.has(id) else "coche"
	var s: Dictionary = STYLES[style]
	if paint == null:
		return
	paint.set_shader_parameter("paint_metallic", s.metallic)
	paint.set_shader_parameter("paint_rough", s.rough)
	paint.set_shader_parameter("coat", s.coat)
	paint.set_shader_parameter("coat_rough", s.coat_rough)
	paint.set_shader_parameter("plastic_parts", 1.0 if s.plastic else 0.0)
	paint.set_shader_parameter("body_metal", 1.0 if body_metal else 0.0)
	var look: Array = FRAME_LOOK[s.frame]
	var frame := mats[M_FRAME] as ShaderMaterial
	frame.set_shader_parameter("albedo", look[0])
	frame.set_shader_parameter("metallic", look[1])
	frame.set_shader_parameter("roughness", look[2])
	var handle := mats[M_HANDLE] as ShaderMaterial
	var chrome_handle := String(s.handle) == "cromo"
	handle.set_shader_parameter("albedo", Color(0.9, 0.91, 0.93) if chrome_handle else _paint_col)
	handle.set_shader_parameter("metallic", 1.0 if chrome_handle else float(s.metallic))
	handle.set_shader_parameter("roughness", 0.07 if chrome_handle else float(s.rough))
	var grille := mats[M_GRILLE] as ShaderMaterial
	grille.set_shader_parameter("albedo", Color(0.88, 0.89, 0.91) if String(s.grille) == "cromo" else Color(0.05, 0.05, 0.055))
	grille.set_shader_parameter("metallic", 1.0 if String(s.grille) == "cromo" else 0.2)
	(mats[M_CALIPER] as StandardMaterial3D).albedo_color = s.caliper
	if classic_parts != null:
		classic_parts.visible = bool(s.classic)
	for w: Dictionary in wheels:
		(w.alloy as Node3D).visible = not bool(s.classic)
		(w.cap as Node3D).visible = bool(s.classic)
		(w.tire as ShaderMaterial).set_shader_parameter("whitewall", s.whitewall)
	# colores de las capas: barniz, color (el del coche), imprimación, anticorrosivo o promotor, carrocería y el hueco
	var cols: Array[Vector4] = []
	var defaults := [Color("#AED2E0"), _paint_col, Color("#9AA0A6"), Color("#5E6B52"), Color("#C3CAD2")]
	for i in 5:
		var c: Color = layers[i] if i < layers.size() and i != 1 else defaults[i]
		var lin := c.srgb_to_linear()
		cols.append(Vector4(lin.r, lin.g, lin.b, 1.0))
	cols.append(Vector4(0.002, 0.002, 0.003, 1.0))
	paint.set_shader_parameter("layer_col", cols)


## Gira las ruedas (angle, rad; el coche va hacia +x: giran en sentido horario) y desenfoca sus llantas y el dibujo del
## neumático (blur 0-1).
func set_wheels(angle: float, blur: float) -> void:
	var b := clampf(blur, 0.0, 1.0)
	for w: Dictionary in wheels:
		(w.pivot as Node3D).rotation = _wheel_rot(w, angle)  # unidad 4t: el giro de la dirección y las ruedas del otro lado
		(w.blur_mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, b)
		(w.tire as ShaderMaterial).set_shader_parameter("blur", b)


## Luz de freno.
func set_brake(on: bool) -> void:
	if tail_mat != null:
		tail_mat.set_shader_parameter("emission_energy", 3.4 if on else 0.7)


# ════════ Daños ════════

## Pone los daños (un conjunto de car_damage.gd) en los materiales: se llama cuando llega un golpe nuevo o cambia el
## ensayo, nunca en cada fotograma.
func set_damage(s: Dictionary) -> void:
	damage_version += 1
	var packed := CarDamage.pack(s)
	for m: ShaderMaterial in damage_mats:
		for k: String in ["n_grooves", "groove_ab", "groove_p", "n_holes", "hole_c", "hole_p", "n_dents", "dent_c", "dent_p"]:
			m.set_shader_parameter(k, packed[k])
	for k: String in ["n_cracks", "crack_c", "crack_p"]:
		glass.set_shader_parameter(k, packed[k])
	var sh: Dictionary = s.get("shatter", {})
	glass.set_shader_parameter("shatter_front", float(sh.get("front", 0.0)))
	glass.set_shader_parameter("shatter_rear", float(sh.get("rear", 0.0)))
	glass.set_shader_parameter("frag_m", float(sh.get("frag_m", 0.0056)))
	glass.set_shader_parameter("shatter_luneta", float(sh.get("luneta", 0.0)))  # unidad 4v


## Unidad 4s: dónde acaba cada capa de la pintura (µm desde la superficie: barniz, color, imprimación y anticorrosivo) y el
## espesor de la pintura con la carrocería (µm): con ellas el sombreador decide la capa que se ve a cada hondura de un
## surco o de una punzada (las capas del coche elegido: Catalog.car_layers). Se llama al cambiar de coche.
func set_layer_depths(to_um: Vector4, p_panel_um: float) -> void:
	layer_depths = to_um
	panel_um = p_panel_um
	for m: ShaderMaterial in damage_mats:
		m.set_shader_parameter("paint_to_um", to_um)
		m.set_shader_parameter("panel_um", p_panel_um)


## Unidad 4s: lo que se exagera el relieve de los labios de los surcos y de las punzadas (1 de verdad; el primer plano en
## toda la vista lo sube: dibujo, la hondura y el ancho siguen siendo los de la física).
func set_lip_boost(k: float) -> void:
	for m: ShaderMaterial in damage_mats:
		m.set_shader_parameter("lip_boost", k)


## Lo que va del golpe que se anima (hit: su número; crush y slide, 0-1): la abolladura, las grietas y los agujeros
## crecen con crush; los surcos, con slide. Los demás golpes, enteros.
func set_damage_progress(hit: int, crush: float, slide: float) -> void:
	for m: ShaderMaterial in damage_mats:
		m.set_shader_parameter("current_hit", float(hit))
		m.set_shader_parameter("hit_crush", crush)
		m.set_shader_parameter("hit_slide", slide)


## Los trocitos de una ventanilla templada que estalla (pane: 0 la delantera · 1 la trasera; frag_m: el tamaño de los
## trozos, Glazing.fragment_size_mm): SHARDS cajitas romas del tamaño de los trozos o de grupos de unos pocos (caen así,
## trabados), repartidas por la ventanilla, con un empujón hacia fuera. Se colocan una vez por golpe; shatter_step() las
## mueve. Dibujo: dónde y cómo caen.
func shatter_start(pane: int, frag_m: float, seed_text: String) -> void:
	if pane < 0 or pane >= windows.size():
		return
	var w: PackedVector2Array = windows[pane]
	if w.size() < 3:
		return
	if shards == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mm.mesh = box
		mm.instance_count = SHARDS
		shards = MultiMeshInstance3D.new()
		shards.name = "Trocitos"
		shards.multimesh = mm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.82, 0.8)
		m.roughness = 0.15
		m.metallic_specular = 0.8
		shards.material_override = m
		shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shards)
		nodes += 1
	shard_runs += 1
	var rng := Rng.new(Rng.seed_of(seed_text))
	var box_r := CurveKit.bounds_of(w)
	_shard_p0.resize(SHARDS)
	_shard_v.resize(SHARDS)
	_shard_spin.resize(SHARDS)
	_shard_size.resize(SHARDS)
	for i in SHARDS:
		var q := box_r.get_center()
		for _try in 12:
			q = box_r.position + Vector2(rng.next(), rng.next()) * box_r.size
			if Geometry2D.is_point_in_polygon(q, w):
				break
		_shard_p0[i] = Vector3(q.x, q.y, CarShape.cabin_hw(q.y) - 0.006)
		_shard_v[i] = Vector3((rng.next() - 0.5) * 0.4, rng.next() * 0.3, 0.15 + rng.next() * 0.45)
		_shard_spin[i] = Vector3(rng.next(), rng.next(), rng.next()) * 9.0
		_shard_size[i] = frag_m * (1.0 + 2.0 * rng.next())
	shard_floor = 0.0  # unidad 4v: los de la ventanilla caen a la carretera
	shards.visible = true
	shatter_step(0.0, 0.0)


## Mueve los trocitos t s (de la animación) después de estallar: caen (con una gravedad de la animación, SHARD_G), llegan al
## asfalto y se quedan atrás con la carretera (road_ms: la velocidad del coche a cámara lenta); al acabar SHARD_S, se
## esconden.
func shatter_step(t: float, road_ms: float) -> void:
	if shards == null:
		return
	if t >= SHARD_S and shard_floor <= 0.0:  # unidad 4v: dentro del coche se quedan en los asientos
		shards.visible = false
		return
	t = minf(t, SHARD_S)
	var mm := shards.multimesh
	for i in SHARDS:
		var p0 := _shard_p0[i]
		var v := _shard_v[i]
		var half := _shard_size[i] * 0.5
		var t_land := (v.y + sqrt(v.y * v.y + 2.0 * SHARD_G * maxf(p0.y - half - shard_floor, 0.0))) / SHARD_G  # unidad 4v: el suelo
		var p: Vector3
		if t < t_land:
			p = p0 + v * t + Vector3(0.0, -0.5 * SHARD_G * t * t, 0.0)
		else:
			var land := p0 + v * t_land + Vector3(0.0, -0.5 * SHARD_G * t_land * t_land, 0.0)
			p = Vector3(land.x - (0.0 if shard_floor > 0.0 else road_ms) * (t - t_land), half + shard_floor, land.z + v.z * 0.2 * (t - t_land))
		var basis := Basis.from_euler(_shard_spin[i] * minf(t, t_land)).scaled(Vector3.ONE * _shard_size[i])
		mm.set_instance_transform(i, Transform3D(basis, p))


## La ventanilla templada que estalla (0 entera · hasta 0,35 se cuartea · luego caen los trozos · 1 caída).
func set_shatter(front: float, rear: float, frag_m: float) -> void:
	glass.set_shader_parameter("shatter_front", front)
	glass.set_shader_parameter("shatter_rear", rear)
	glass.set_shader_parameter("frag_m", frag_m)


# ════════ Curvas (unidad 4t) ════════
# Las ruedas del otro lado (la vista de persecución ve el coche por detrás: sin ellas, le faltaban dos) y el giro de las
# delanteras (dibujo: RoadCurve.steer_rad). Se crean una vez, la primera vez que hace falta.

var far_wheels := false
var steer := 0.0


## Las dos ruedas del lado de allá (z = −WHEEL_Z), giradas media vuelta para que la llanta mire hacia fuera.
func ensure_far_wheels(mobile: bool) -> void:
	if far_wheels or root == null:
		return
	far_wheels = true
	var n0 := wheels.size()
	for i in 2:
		_wheel(float(CarShape.WHEEL_X[i]), mobile)
	for k in range(n0, wheels.size()):
		var w: Dictionary = wheels[k]
		w["far"] = true
		(w.pivot as Node3D).position.z = -CarShape.WHEEL_Z
		(w.pivot as Node3D).rotation = _wheel_rot(w, 0.0)
		(w.alloy as Node3D).visible = (wheels[0].alloy as Node3D).visible
		(w.cap as Node3D).visible = (wheels[0].cap as Node3D).visible
		(w.tire as ShaderMaterial).set_shader_parameter("whitewall", (wheels[0].tire as ShaderMaterial).get_shader_parameter("whitewall"))


## Giro de la dirección (rad, + a la izquierda) de las ruedas delanteras.
func set_steer(rad: float) -> void:
	steer = rad
	for w: Dictionary in wheels:
		w["steer"] = rad if (w.pivot as Node3D).position.x > CarShape.CAR_L * 0.5 else 0.0


## El giro de una rueda: la dirección (en y) y lo que ha rodado (en z); las del otro lado, giradas media vuelta, ruedan al
## revés en su eje.
static func _wheel_rot(w: Dictionary, angle: float) -> Vector3:
	var st := float(w.get("steer", 0.0))
	if bool(w.get("far", false)):
		return Vector3(0.0, PI + st, angle)
	return Vector3(0.0, st, -angle)


# ════════ Cristales (unidad 4v) ════════
# La luneta templada que estalla bajo el animal: el cuarteado y los trozos que caen en el shader de las lunas
# (shatter_luneta) y SHARDS trocitos que caen dentro, sobre la banqueta de atrás (los mismos de la ventanilla). Dibujo.

## Dónde caen los trocitos de la luneta (m sobre el suelo): la banqueta de atrás, apenas insinuada.
const LUNETA_FLOOR := 0.5
## Alto (m) al que caen los trozos que se quedan dentro (0: los de la ventanilla, a la carretera).
var shard_floor := 0.0


## Lo que ha estallado la luneta (0 entera · hasta 0,35 se cuartea · luego caen los trozos · 1 caída).
func set_luneta_shatter(s: float, frag_m: float) -> void:
	glass.set_shader_parameter("shatter_luneta", s)
	if s > 0.0:
		glass.set_shader_parameter("frag_m", frag_m)


## Los trocitos de la luneta que estalla: salen de su panel (CarShape.LUNETA_PANEL, sobre la silueta de arriba) y caen
## dentro del coche, a la banqueta de atrás, donde se quedan. Se colocan una vez; shatter_step() los mueve.
func luneta_shards_start(frag_m: float, seed_text: String) -> void:
	shatter_start(0, frag_m, seed_text)  # crea el MultiMesh la primera vez (con los trozos de la ventanilla)
	if shards == null:
		return
	var rng := Rng.new(Rng.seed_of(seed_text + "|luneta"))
	var top := CarShape.scaled_top(shape)
	var span := Vector2(CarShape.LUNETA_PANEL.x * shape.x, CarShape.LUNETA_PANEL.y * shape.x)
	for i in SHARDS:
		var x := lerpf(span.x, span.y, rng.next())
		var y := CurveKit.top_y(top, x)
		var z := (rng.next() * 2.0 - 1.0) * CarShape.LUNETA_HW * shape.z
		_shard_p0[i] = Vector3(x, (y if not is_nan(y) else 1.2) - 0.01, z)
		# el temple suelta su energía: los trozos saltan un poco antes de caer dentro (dibujo)
		_shard_v[i] = Vector3((rng.next() - 0.3) * 0.4, 0.15 + rng.next() * 0.5, (rng.next() - 0.5) * 0.4)
	shard_floor = LUNETA_FLOOR * shape.y
	shatter_step(0.0, 0.0)
