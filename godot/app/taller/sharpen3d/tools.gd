## Afiladora 3D · herramientas procedurales (set_tool): cuchillo, hacha y cuchilla de cortacésped (hojas: el bisel lo
## dibuja el shader con el ángulo de cada fotograma) y broca helicoidal y fresa de mango (la punta se talla en la
## malla con el ángulo pedido; si cambia, se rehace la malla, que es un cambio de ajuste y no de cada fotograma).
##
## Marcos locales (metros):
## - Hojas: x a lo largo del filo, del talón (x = 0, lado del mango) a la punta (x = largo); y del filo al lomo; z el
##   espesor (cara A en +z). La curva del filo va en z = 0.
## - Broca y fresa: la punta en el origen y el eje hacia el mango en +Y.
## Medidas de la vista en mm (CONTRATOS.md): length_mm, width_mm o diameter_mm, spine_mm, steel_id; opcional flutes.
## Si faltan, las de DEFAULTS (medidas de dibujo). Solo dibujo: el ángulo, las temperaturas y la rebaba los da set_state.
extends RefCounted

const Parts = preload("res://app/taller/sharpen3d/parts.gd")
const BLADE_SHADER = preload("res://app/taller/sharpen3d/blade.gdshader")
const BURR_SHADER = preload("res://app/taller/sharpen3d/burr.gdshader")

const KINDS := ["cuchillo", "hacha", "cortacesped", "broca", "fresa"]
const BLADE_KINDS := ["cuchillo", "hacha", "cortacesped"]
const CUSTOM_FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

## Medidas por defecto (mm) si la vista no las trae. Cuchillo de cocina de 20 cm; hacha de bosque de ≈1 kg; cuchilla
## de cortacésped de 50 cm; broca DIN 338 de Ø10 (133 mm, 87 de hélice); fresa DIN 844 corta de Ø12 (83 mm, 26 de
## corte). ESTIMACIÓN de dibujo salvo las longitudes de las normas DIN (catálogos de fabricantes).
const DEFAULTS := {
	"cuchillo": { "length_mm": 200.0, "width_mm": 45.0, "spine_mm": 2.5 },
	"hacha": { "length_mm": 175.0, "width_mm": 95.0, "spine_mm": 28.0 },
	"cortacesped": { "length_mm": 500.0, "width_mm": 55.0, "spine_mm": 4.0 },
	"broca": { "length_mm": 133.0, "diameter_mm": 10.0, "flute_mm": 87.0, "flutes": 2 },
	"fresa": { "length_mm": 83.0, "diameter_mm": 12.0, "flute_mm": 26.0, "flutes": 4 },
}
## Espesor detrás del filo antes del bisel de afilado (mm): dibujo. Cuchillo de cocina 0,35; hacha 0,8; cortacésped:
## la chapa entera (bisel de un solo lado).
const BEHIND_EDGE_MM := { "cuchillo": 0.35, "hacha": 0.8, "cortacesped": 4.0 }
## Color del acero por material (dibujo): inoxidable claro, al carbono algo más oscuro, acero rápido y metal duro.
const STEEL_LOOK := {
	"vg10": "#B5B9BE", "x50crmov15": "#B7BBC0", "14c28n": "#B3B8BD", "1095": "#A2A5A8", "m2": "#9EA2A6",
	"metal_duro": "#7E8388", "": "#AEB2B6",
}


## Tipo de herramienta de una vista. «hacha» también llega como cuchillo con use = "hacha" (sharpening.gd).
static func kind_of(view: Dictionary) -> String:
	var k := str(view.get("kind", "cuchillo"))
	if k == "cuchillo" and str(view.get("use", "")) == "hacha":
		k = "hacha"
	return k if KINDS.has(k) else "cuchillo"


## Clave de la geometría de una vista (si no cambia, set_tool no reconstruye nada). point_deg: ángulo de la punta
## de la broca o de la incidencia de la fresa con el que se talla la malla.
static func key_of(view: Dictionary, point_deg: float) -> String:
	var k := kind_of(view)
	return "%s|%s|%s|%s|%s|%s|%s" % [k, Parts.num(view, "length_mm", -1.0), Parts.num(view, "width_mm", -1.0),
		Parts.num(view, "diameter_mm", -1.0), Parts.num(view, "spine_mm", -1.0), Parts.num(view, "flutes", -1.0),
		point_deg if not BLADE_KINDS.has(k) else 0.0]


static func dim(view: Dictionary, kind: String, key: String) -> float:
	var d: Dictionary = DEFAULTS[kind]
	var v := Parts.num(view, key, float(d.get(key, 0.0)))
	return v if v > 0.0 else float(d.get(key, 1.0))


## Construye la herramienta bajo `parent`. Devuelve su rig: { kind, root (el nodo que se coloca), mat (blade.gdshader),
## burr_mat, blade (bool), y lo que hace falta para colocarla y dibujar su sección }.
static func build(parent: Node3D, view: Dictionary, point_deg: float) -> Dictionary:
	var kind := kind_of(view)
	var root := Parts.node(parent, "Herramienta")
	var steel := str(view.get("steel_id", ""))
	var mat := ShaderMaterial.new()
	mat.shader = BLADE_SHADER
	mat.set_shader_parameter("steel_color", Color(STEEL_LOOK.get(steel, STEEL_LOOK[""])))
	var rig: Dictionary
	match kind:
		"hacha":
			rig = _axe(root, view, mat)
		"cortacesped":
			rig = _mower(root, view, mat)
		"broca":
			rig = _rotary(root, view, mat, "broca", point_deg)
		"fresa":
			rig = _rotary(root, view, mat, "fresa", point_deg)
		_:
			rig = _knife(root, view, mat)
	rig["kind"] = kind
	rig["root"] = root
	rig["mat"] = mat
	rig["steel_id"] = steel
	rig["blade"] = BLADE_KINDS.has(kind)
	var burr_mat := ShaderMaterial.new()
	burr_mat.shader = BURR_SHADER
	var burr := Parts.mesh_node(root, _polyline_tube(rig["edge_lines"], 0.00007 if rig["blade"] else 0.00005), burr_mat,
		Transform3D.IDENTITY, "Rebaba")
	burr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig["burr"] = burr
	rig["burr_mat"] = burr_mat
	return rig


# ───────────────────────────── hojas ─────────────────────────────


## Cuchillo de cocina: filo recto hasta la mitad y panza que sube a la punta; lomo recto que baja en el último
## tercio; espesor que baja del lomo al filo (afilado plano) y hacia la punta (conicidad). Recalce y mango.
static func _knife(root: Node3D, view: Dictionary, mat: ShaderMaterial) -> Dictionary:
	var L := dim(view, "cuchillo", "length_mm") / 1000.0
	var W := dim(view, "cuchillo", "width_mm") / 1000.0
	var ts := dim(view, "cuchillo", "spine_mm") / 1000.0
	var tb := float(BEHIND_EDGE_MM["cuchillo"]) / 1000.0
	var cols := 64
	var xs := PackedFloat64Array()
	var ye := PackedFloat64Array()
	var yt := PackedFloat64Array()
	var y_tip := 0.28 * W
	for i in cols + 1:
		var x := L * float(i) / float(cols)
		xs.append(x)
		ye.append(0.0 if x <= 0.5 * L else y_tip * pow((x - 0.5 * L) / (0.5 * L), 2.2))
		yt.append(W if x <= 0.62 * L else W - (W - y_tip) * pow((x - 0.62 * L) / (0.38 * L), 1.6))
	var half := func(i: int, d: float) -> Vector2:
		var H: float = maxf(yt[i] - ye[i], 1e-6)
		var hs: float = ts * 0.5 * (0.35 + 0.65 * H / W)
		var v: float = clampf(d / H, 0.0, 1.0)
		return Vector2(tb * 0.5 + (hs - tb * 0.5) * v, (hs - tb * 0.5) / H)
	var mesh := blade_mesh(xs, ye, yt, half, 22, L)
	var blade := Parts.mesh_node(root, mesh, mat, Transform3D.IDENTITY, "Hoja")
	blade.custom_aabb = AABB(Vector3(-0.01, -0.01, -ts), Vector3(L + 0.02, W + 0.02, 2.0 * ts))
	# Recalce y mango (a −x del talón), alineados con el lomo; remaches de latón
	var steel := Parts.mat(Color("#B9BDC2"), 1.0, 0.25)
	var scale_mat := Parts.mat(Color("#1E1D22"), 0.0, 0.42)
	var brass := Parts.mat(Color("#C9A456"), 1.0, 0.3)
	var hy := W - 0.013
	Parts.box(root, Vector3(-0.012, W - 0.028, -ts * 0.5 - 0.0035), Vector3(0.0, W, ts * 0.5 + 0.0035), steel, 0.002, "Recalce")
	Parts.box(root, Vector3(-0.13, hy - 0.012, -0.0085), Vector3(-0.012, hy + 0.012, 0.0085), scale_mat, 0.005, "Mango")
	for k in 3:
		var rx := -0.03 - 0.038 * k
		Parts.rod(root, Vector3(rx, hy, -0.0088), Vector3(rx, hy, 0.0088), 0.0024, brass, 12)
	return {
		"length": L, "width": W, "xs": xs, "ye": ye, "yt": yt, "thickness": ts, "behind": tb, "half": half,
		"edge_lines": [_edge_line(xs, ye)], "handle_len": 0.13, "single_bevel": false,
		"clamp_local": Vector3(-0.07, hy, 0.0), "clamp_half": 0.0085,
		"section": { "hb0": tb * 0.5, "slope": (ts * 0.5 - tb * 0.5) / W, "hmax": ts * 0.5, "window": 0.004 },
	}


## Hacha: filo convexo (x a lo largo del filo); de perfil, el ojo y la nuca (EYE_HALF_M a cada lado del centro) y
## el cuello que se abre hacia las puntas del filo (la «barba» y el «talón» del hacha); mejillas convexas que llegan
## al espesor del ojo; mango de madera que pasa por el ojo, paralelo al filo (el del hacha lo es). Dibujo.
static func _axe(root: Node3D, view: Dictionary, mat: ShaderMaterial) -> Dictionary:
	var Lh := dim(view, "hacha", "length_mm") / 1000.0  # del filo a la cabeza (nuca)
	var Wb := dim(view, "hacha", "width_mm") / 1000.0  # largo del filo
	var T := dim(view, "hacha", "spine_mm") / 1000.0  # espesor en el ojo
	var tb := float(BEHIND_EDGE_MM["hacha"]) / 1000.0
	var cols := 48
	var xs := PackedFloat64Array()
	var ye := PackedFloat64Array()
	var yt := PackedFloat64Array()
	var m := Wb * 0.5
	var eye := minf(0.022, Wb * 0.25)
	for i in cols + 1:
		var x := Wb * float(i) / float(cols)
		var c := 2.0 * x / Wb - 1.0
		xs.append(x)
		ye.append(-0.005 * (1.0 - c * c))
		# Nuca plana sobre el ojo; fuera, el cuello baja deprisa y se abre despacio hacia las puntas del filo
		var t := clampf((absf(x - m) - eye) / maxf(m - eye, 1e-4), 0.0, 1.0)
		yt.append(Lh - (Lh - 0.12 * Lh) * pow(t, 0.55))
	var lc := 0.55 * Lh
	var cheek := tan(deg_to_rad(7.0))
	var half := func(i: int, d: float) -> Vector2:
		if d >= lc:
			return Vector2(T * 0.5, 0.0)
		var extra: float = T * 0.5 - tb * 0.5 - lc * cheek
		var u: float = d / lc
		return Vector2(tb * 0.5 + d * cheek + extra * pow(u, 2.2), cheek + extra * 2.2 * pow(u, 1.2) / lc)
	var mesh := blade_mesh(xs, ye, yt, half, 26, Wb)
	var head := Parts.mesh_node(root, mesh, mat, Transform3D.IDENTITY, "Cabeza")
	head.custom_aabb = AABB(Vector3(-0.01, -0.01, -T), Vector3(Wb + 0.02, Lh + 0.02, 2.0 * T))
	# Mango de nogal americano por el ojo (a 30 mm de la nuca), paralelo al filo, hacia el talón
	var wood := Parts.mat(Color("#B08452"), 0.0, 0.55)
	var ey := Lh - 0.03
	Parts.box(root, Vector3(-0.6, ey - 0.017, -0.0135), Vector3(Wb * 0.5 + 0.035, ey + 0.017, 0.0135), wood, 0.009, "Mango")
	# En el tornillo de banco se sujeta por el mango, junto a la cabeza (las mordazas acaban a 5 mm de ella)
	return {
		"length": Wb, "width": Lh, "xs": xs, "ye": ye, "yt": yt, "thickness": T, "behind": tb, "half": half,
		"edge_lines": [_edge_line(xs, ye)], "handle_len": 0.6, "handle_y": ey, "single_bevel": false,
		"clamp_local": Vector3(-0.06, ey, 0.0), "clamp_half": 0.0135,
		"section": { "hb0": tb * 0.5, "slope": cheek, "hmax": T * 0.5, "window": 0.022 },
	}


## Cuchilla de cortacésped: pletina de acero dulce con filo de un solo bisel en cada extremo (lados opuestos) y
## agujero central. Se dibuja la zona de filo de un extremo (x del interior a la punta) y el resto de la pletina
## hacia −x (el lado del «mango» al colocarla), con el ala de la punta levantada.
static func _mower(root: Node3D, view: Dictionary, mat: ShaderMaterial) -> Dictionary:
	var Lt := dim(view, "cortacesped", "length_mm") / 1000.0
	var W := dim(view, "cortacesped", "width_mm") / 1000.0
	var t := dim(view, "cortacesped", "spine_mm") / 1000.0
	var Le := minf(0.11, Lt * 0.3)
	var cols := 32
	var xs := PackedFloat64Array()
	var ye := PackedFloat64Array()
	var yt := PackedFloat64Array()
	for i in cols + 1:
		xs.append(Le * float(i) / float(cols))
		ye.append(0.0)
		yt.append(W)
	var half := func(_i: int, _d: float) -> Vector2:
		return Vector2(t * 0.5, 0.0)
	var mesh := blade_mesh(xs, ye, yt, half, 20, Le)
	var edge := Parts.mesh_node(root, mesh, mat, Transform3D.IDENTITY, "Filo")
	edge.custom_aabb = AABB(Vector3(-0.01, -0.01, -t), Vector3(Le + 0.02, W + 0.02, 2.0 * t))
	var steel := Parts.mat(Color("#5E6268"), 0.7, 0.45)
	var dark := Parts.mat(Color("#101114"), 0.0, 0.8)
	var rest := Lt - Le
	var hole_x := Le - Lt * 0.5  # agujero en el centro de la cuchilla
	Parts.box(root, Vector3(-rest, 0.0, -t * 0.5), Vector3(0.0, W, t * 0.5), steel, 0.0, "Pletina")
	Parts.rod(root, Vector3(hole_x, W * 0.5, -t * 0.5 - 0.0002), Vector3(hole_x, W * 0.5, t * 0.5 + 0.0002), 0.009, dark, 24)
	# Ala levantada de la punta (vela), en el lado del lomo
	var wing := Parts.box(root, Vector3(Le - 0.05, 0.0, -t * 0.5), Vector3(Le, 0.02, t * 0.5), steel, 0.0, "Ala")
	wing.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)), Vector3(0.0, W, 0.0)) * wing.transform
	return {
		"length": Le, "width": W, "xs": xs, "ye": ye, "yt": yt, "thickness": t, "behind": t, "half": half,
		"edge_lines": [_edge_line(xs, ye)], "handle_len": rest, "single_bevel": true,
		"clamp_local": Vector3(-0.2, W * 0.75, 0.0), "clamp_half": t * 0.5,
		"section": { "hb0": t * 0.5, "slope": 0.0, "hmax": t * 0.5, "window": 0.016 },
	}


static func _edge_line(xs: PackedFloat64Array, ye: PackedFloat64Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in xs.size():
		out.append(Vector3(xs[i], ye[i], 0.0))
	return out


## Posición (m, marco de la hoja) y pendiente dy/dx del filo en la fracción u del largo (interpola la curva).
static func edge_at(rig: Dictionary, u: float) -> Array:
	var xs: PackedFloat64Array = rig["xs"]
	var ye: PackedFloat64Array = rig["ye"]
	var n := xs.size()
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(floor(f)), n - 2)
	var k := f - float(i)
	var p := Vector3(lerpf(xs[i], xs[i + 1], k), lerpf(ye[i], ye[i + 1], k), 0.0)
	var slope := (ye[i + 1] - ye[i]) / maxf(xs[i + 1] - xs[i], 1e-9)
	return [p, slope]


## z (m, marco de la hoja) del vértice del filo en la fracción u: 0 con bisel a los dos lados (el vértice está en la
## línea media); con un solo bisel, en la cara B (z = −semiespesor), como lo dibuja bevel.gdshaderinc.
static func vertex_z(rig: Dictionary, u: float) -> float:
	if not bool(rig.get("single_bevel", false)):
		return 0.0
	var half: Callable = rig["half"]
	var i := int(round(clampf(u, 0.0, 1.0) * float((rig["xs"] as PackedFloat64Array).size() - 1)))
	return -(half.call(i, 0.0) as Vector2).x


## Altura local de la hoja (m, del filo al lomo) en la fracción u.
static func height_at(rig: Dictionary, u: float) -> float:
	var xs: PackedFloat64Array = rig["xs"]
	var ye: PackedFloat64Array = rig["ye"]
	var yt: PackedFloat64Array = rig["yt"]
	var n := xs.size()
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(floor(f)), n - 2)
	var k := f - float(i)
	return lerpf(yt[i] - ye[i], yt[i + 1] - ye[i + 1], k)


## Malla de una hoja. Columnas xs (m) con la curva del filo ye y la del lomo yt; half.call(i, d) → Vector2(semiespesor
## del cuerpo, su pendiente) a la distancia d del filo en la columna i. Filas densas junto al filo (v³). Cada vértice
## va en la línea media con CUSTOM0 = (d, lado, semiespesor, pendiente); z lo pone el shader con el bisel. En la CPU
## se deja z = lado·semiespesor para que la caja de la malla ya tenga su grosor.
static func blade_mesh(xs: PackedFloat64Array, ye: PackedFloat64Array, yt: PackedFloat64Array, half: Callable, rows: int, length: float) -> ArrayMesh:
	var b := MeshArrays.new()
	var cols := xs.size()
	for side: float in [1.0, -1.0]:
		var base := b.count()
		for i in cols:
			var H := yt[i] - ye[i]
			for j in rows + 1:
				var v := pow(float(j) / float(rows), 3.0)
				var d := v * H
				var hb: Vector2 = half.call(i, d)
				b.add(Vector3(xs[i], ye[i] + d, side * hb.x), Vector3(0.0, -hb.y, side).normalized(), Vector2(xs[i] / length, v),
					Vector2(0.0, 0.0), Color(d, side, hb.x, hb.y))
		for i in cols - 1:
			for j in rows:
				var a := base + i * (rows + 1) + j
				var c := a + rows + 1
				b.quad(a, c, c + 1, a + 1, Vector3(0.0, 0.0, side))
	# Lomo: tira entre las dos caras a lo largo de yt, con la normal de la curva del lomo
	var base_s := b.count()
	for i in cols:
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, cols - 1)
		var tan2 := Vector2(xs[i1] - xs[i0], yt[i1] - yt[i0]).normalized()
		var n := Vector3(-tan2.y, tan2.x, 0.0)
		var H := yt[i] - ye[i]
		var hb: Vector2 = half.call(i, H)
		for side: float in [1.0, -1.0]:
			b.add(Vector3(xs[i], yt[i], side * hb.x), n, Vector2(xs[i] / length, 1.0), Vector2(0.0, 1.0),
				Color(H, side, hb.x, hb.y))
	for i in cols - 1:
		var a := base_s + i * 2
		var up := Vector3(-(yt[i + 1] - yt[i]), xs[i + 1] - xs[i], 0.0)
		b.quad(a, a + 2, a + 3, a + 1, up)
	# Talón (x del primer punto) y, si la hoja acaba en un canto (cortacésped), también la punta
	for end in [0, cols - 1]:
		var H := yt[end] - ye[end]
		if end == cols - 1 and H < 1e-4:
			continue
		var nx := Vector3(-1.0 if end == 0 else 1.0, 0.0, 0.0)
		var base_c := b.count()
		for j in rows + 1:
			var v := pow(float(j) / float(rows), 3.0)
			var d := v * H
			var hb: Vector2 = half.call(end, d)
			for side: float in [1.0, -1.0]:
				b.add(Vector3(xs[end], ye[end] + d, side * hb.x), nx, Vector2(xs[end] / length, v), Vector2(0.0, 1.0),
					Color(d, side, hb.x, hb.y))
		for j in rows:
			var a := base_c + j * 2
			b.quad(a, a + 2, a + 3, a + 1, nx)
	return b.commit()


# ───────────────────────────── broca y fresa ─────────────────────────────


## Broca helicoidal (2 labios, hélice N) o fresa de mango (z labios). La sección es polar: fajas (radio R) y canales
## cóncavos hasta el alma; gira con la hélice. La punta es la sección recortada por la superficie tallada: el cono
## del ángulo de punta en la broca (con la incidencia detrás de cada labio) o la cara frontal de la fresa (con su
## incidencia primaria). Donde el canal corta esa superficie queda el labio, como en la herramienta de verdad.
static func _rotary(root: Node3D, view: Dictionary, mat: ShaderMaterial, kind: String, point_deg: float) -> Dictionary:
	var geo := rotary_geometry(view, kind, point_deg)
	var mi := Parts.mesh_node(root, geo["mesh"], mat, Transform3D.IDENTITY, "Broca" if kind == "broca" else "Fresa")
	geo["mesh_node"] = mi
	geo.erase("mesh")
	return geo


## Vuelve a tallar la punta con otro ángulo (broca: ángulo de punta; fresa: incidencia) sin crear nodos: cambia las
## mallas de la herramienta y de su rebaba. Es un cambio de ajuste de la máquina, no de cada fotograma.
static func retool(rig: Dictionary, view: Dictionary, point_deg: float) -> void:
	var geo := rotary_geometry(view, str(rig["kind"]), point_deg)
	(rig["mesh_node"] as MeshInstance3D).mesh = geo["mesh"]
	(rig["burr"] as MeshInstance3D).mesh = _polyline_tube(geo["edge_lines"], 0.00005)
	for k in ["tip_len", "slope", "point_deg", "edge_lines", "lip_theta"]:
		rig[k] = geo[k]


## Geometría de la broca o la fresa con la punta tallada a point_deg: { mesh, edge_lines, lip_theta, … }.
static func rotary_geometry(view: Dictionary, kind: String, point_deg: float) -> Dictionary:
	var drill := kind == "broca"
	var D := dim(view, kind, "diameter_mm") / 1000.0
	var Lt := dim(view, kind, "length_mm") / 1000.0
	var R := D * 0.5
	var flutes := int(Parts.num(view, "flutes", float(DEFAULTS[kind]["flutes"])))
	flutes = clampi(flutes, 2, 6) if not drill else 2
	var flute_len := minf(float(DEFAULTS[kind]["flute_mm"]) / float(DEFAULTS[kind]["length_mm"]) * Lt, Lt - D)
	var helix := deg_to_rad(25.0 if drill else 30.0)
	var twist := tan(helix) / R  # rad por metro
	var slope: float  # altura de la superficie tallada por metro de radio
	var relief: float  # incidencia detrás del filo (rad)
	if drill:
		slope = 1.0 / tan(deg_to_rad(clampf(point_deg, 80.0, 150.0) * 0.5))
		relief = deg_to_rad(10.0)
	else:
		slope = tan(deg_to_rad(1.5))  # ligera concavidad de la cara frontal (dish)
		relief = deg_to_rad(clampf(point_deg, 0.0, 20.0))
	var land := 0.44 if drill else 0.3
	var r_core := (0.08 if drill else 0.3) * D
	var section := func(th: float) -> float:
		var period := TAU / float(flutes)
		var ph := fposmod(th, period) / period
		if ph < land:
			return R if ph < 0.1 * land else R - 0.015 * D
		var tt := (ph - land) / (1.0 - land)
		return R - (R - r_core) * pow(sin(PI * tt), 0.75 if drill else 0.6)
	var behind := func(th: float) -> float:
		var period := TAU / float(flutes)
		var ph := fposmod(th, period) / period
		return (land - ph) * period if ph < land else 0.0
	var n_th := 36 * flutes
	var y0 := R * slope  # altura del hombro (broca) o del borde de la cara frontal (fresa)
	var b := MeshArrays.new()
	var rings: Array = []  # cada anillo: [y del anillo (para la hélice), tipo, λ o y]
	var n_tip := 18
	for k in n_tip + 1:
		rings.append(["tip", 1.0 - float(k) / float(n_tip)])
	# El cuerpo empieza por encima del punto más alto de la superficie tallada (el talón con su incidencia)
	var y_b0 := y0 + R * land * TAU / float(flutes) * tan(relief) + 0.0002
	var n_body := 40
	for k in n_body + 1:
		rings.append(["body", y_b0 + (flute_len - y_b0) * float(k) / float(n_body)])
	rings.append(["runout", flute_len + 0.35 * D])
	var shank_r := R * (0.985 if drill else 1.0)
	rings.append(["shank", Lt - 0.0006])
	rings.append(["end", Lt])
	var grid: Array = []
	for rg in rings:
		var ring := PackedVector3Array()
		var ground: bool = rg[0] == "tip"
		for m in n_th:
			var th := TAU * float(m) / float(n_th)
			var p: Vector3
			match rg[0]:
				"tip":
					var lam: float = rg[1]
					var ths: float = th - twist * y0
					var r: float = minf(section.call(ths), R * (1.0 - lam))
					var y: float = r * slope + r * behind.call(ths) * tan(relief) * (1.0 if drill else 0.9)
					p = Vector3(r * cos(th), y, r * sin(th))
				"body":
					var yb: float = rg[1]
					var r2: float = section.call(th - twist * yb)
					p = Vector3(r2 * cos(th), yb, r2 * sin(th))
				"runout":
					p = Vector3(shank_r * cos(th), rg[1], shank_r * sin(th))
				"shank":
					p = Vector3(shank_r * cos(th), rg[1], shank_r * sin(th))
				_:
					p = Vector3(shank_r * 0.85 * cos(th), rg[1], shank_r * 0.85 * sin(th))
			ring.append(p)
		grid.append([ring, ground])
	# Vértices con normales por diferencias en la rejilla (la punta se sombrea por facetas en el shader)
	var nr := grid.size()
	for gi in nr:
		var ring: PackedVector3Array = grid[gi][0]
		var ground: bool = grid[gi][1]
		var prev: PackedVector3Array = grid[maxi(gi - 1, 0)][0]
		var next: PackedVector3Array = grid[mini(gi + 1, nr - 1)][0]
		for m in n_th:
			var p := ring[m]
			var t_th := ring[(m + 1) % n_th] - ring[(m - 1 + n_th) % n_th]
			var t_ax := next[m] - prev[m]
			var n := t_th.cross(t_ax)
			var radial := Vector3(p.x, 0.0, p.z)
			if n.length_squared() < 1e-20:
				n = radial if radial.length_squared() > 1e-20 else Vector3.DOWN
			if n.dot(radial) < 0.0 and not ground:
				n = -n
			if ground and n.y > 0.0:
				n = -n
			var r_here := Vector2(p.x, p.z).length()
			var d := 0.0 if ground else maxf(p.y - r_here * slope, 0.0)
			b.add(p, n.normalized(), Vector2(r_here / R, 0.0), Vector2(1.0 if ground else 0.0, 2.0 if ground else 0.0),
				Color(d, 0.0, 0.0, 0.0))
	for gi in nr - 1:
		for m in n_th:
			var a := gi * n_th + m
			var a2 := gi * n_th + (m + 1) % n_th
			var c := a + n_th
			var c2 := a2 + n_th
			var mid := (b.pos(a) + b.pos(c2)) * 0.5
			var want := Vector3(mid.x, 0.0, mid.z)
			if gi < n_tip:
				want = Vector3.DOWN
			b.quad(a, a2, c2, c, want)
	# Tapa del mango (abanico al centro)
	var top := b.add(Vector3(0.0, Lt, 0.0), Vector3.UP, Vector2(0.0, 0.0), Vector2(0.0, 1.0), Color(Lt, 0.0, 0.0, 0.0))
	var last := (nr - 1) * n_th
	for m in n_th:
		b.tri(top, last + m, last + (m + 1) % n_th, Vector3.UP)
	var mesh := b.commit()
	# Labios (broca) o filos frontales (fresa): donde el canal corta la superficie tallada
	var lines: Array = []
	for f in flutes:
		var line := PackedVector3Array()
		var th_lip := (float(f) + land) * TAU / float(flutes) + twist * y0
		for k in 13:
			var r3 := lerpf(r_core * 1.1, R, float(k) / 12.0)
			line.append(Vector3(r3 * cos(th_lip), r3 * slope, r3 * sin(th_lip)))
		lines.append(line)
	return {
		"mesh": mesh, "length": Lt, "radius": R, "flutes": flutes, "tip_len": y0, "slope": slope, "point_deg": point_deg,
		"edge_lines": lines, "lip_theta": land * TAU / float(flutes) + twist * y0, "single_bevel": false,
		"section": { "window": maxf(D * 1.6, 0.008) },
	}


# ───────────────────────────── utilidades de malla ─────────────────────────────


## Tubo fino a lo largo de unas polilíneas (la rebaba): 5 lados, UV.x = posición a lo largo del filo.
static func _polyline_tube(lines: Array, r: float) -> ArrayMesh:
	var b := MeshArrays.new()
	var sides := 5
	for line in lines:
		var pts: PackedVector3Array = line
		var n := pts.size()
		if n < 2:
			continue
		var base := b.count()
		for i in n:
			var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var ref := Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
			var a := t.cross(ref).normalized()
			var c := t.cross(a)
			for s in sides:
				var ang := TAU * float(s) / float(sides)
				var off := (a * cos(ang) + c * sin(ang))
				b.add(pts[i] + off * r, off, Vector2(float(i) / float(n - 1), 0.0), Vector2.ZERO, Color(0, 0, 0, 0))
		for i in n - 1:
			for s in sides:
				var p0 := base + i * sides + s
				var p1 := base + i * sides + (s + 1) % sides
				b.quad(p0, p1, p1 + sides, p0 + sides, (b.pos(p0) + b.pos(p1 + sides)) * 0.5 - pts[i])
	return b.commit()


## Acumulador de vértices con UV, UV2 y CUSTOM0 (4 float); cada triángulo se orienta con la normal que se le pide
## (Godot toma como frontales los triángulos en sentido horario vistos desde fuera).
class MeshArrays:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var idx := PackedInt32Array()

	func count() -> int:
		return v.size()

	func pos(i: int) -> Vector3:
		return v[i]

	func add(p: Vector3, nn: Vector3, t: Vector2, t2: Vector2, c: Color) -> int:
		v.append(p)
		n.append(nn)
		uv.append(t)
		uv2.append(t2)
		custom.append_array(PackedFloat32Array([c.r, c.g, c.b, c.a]))
		return v.size() - 1

	func tri(a: int, b: int, c: int, want: Vector3) -> void:
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		if fn.dot(want) > 0.0:
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	func quad(a: int, b: int, c: int, d: int, want: Vector3) -> void:
		tri(a, b, c, want)
		tri(a, c, d, want)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, CUSTOM_FORMAT)
		return m
