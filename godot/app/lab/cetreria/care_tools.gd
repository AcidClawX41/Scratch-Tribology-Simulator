## Cetrería · las herramientas de la bandeja en 3D (dibujo hecho en código, sin descargas), en metros y con las medidas
## de sus datos donde las hay (la lima de 150 mm de DIN 8349 con sus dientes por cm, el tambor de 12,7 mm del torno y de
## la amoladora, la boca de cada cortaúñas, la amoladora de 190,5 mm de la ficha); lo demás son proporciones de dibujo:
##   - limas de acero: plana (la gruesa y la entrefina) y de media caña (la fina), con su picado, la punta que se
##     estrecha, la espiga y el mango torneado de madera con su virola; limas de diamante (placa de acero con el grano y
##     mango de plástico); limas de cartón de corindón (P180 y P240);
##   - el torno de uñas de mascota (el 7300-PT: inalámbrico): el cuerpo con su agarre, el interruptor, el piloto, la
##     tuerca del mandril y el tambor de lija de grano 60; y su base de carga con el cable, en la bandeja;
##   - la amoladora de uñas con protector (unidad 5c): el cuerpo de dos colores, el collar metálico, el protector
##     translúcido con la guía de 45°, el interruptor deslizante con sus cuatro pilotos de velocidad, las rejillas del
##     motor, el conector de carga y la banda de lija de 1/2″ en su mandril;
##   - cortaúñas de guillotina, de tijera y tenazas de herrador, de metal (la hoja se cierra con closing 0-1);
##   - agua tibia, gasa, polvo hemostático, lápiz de nitrato de plata, clorhexidina, crema y metacrilato, los frascos y
##     tubos con su etiqueta.
## Marco de cada herramienta: el punto que trabaja en el origen, con la cara que toca mirando a +Y (la garra queda
## encima) y el largo de la herramienta a lo largo de X (el mango hacia −X). Los cortaúñas llevan la garra a lo largo de
## +X por el centro de su boca. build() devuelve también las piezas que se animan (el tambor que gira, la hoja, el
## interruptor deslizante y los pilotos).
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const ABRASIVE_SHADER = preload("res://app/lab/cetreria/abrasive.gdshader")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## Largo de las limas (mm): la de 150 mm de DIN 8349 (la de 13, 18 y 22 dientes por cm de CareData).
const FILE_MM := 150.0
## Medidas de dibujo (mm): ancho y grueso de la lima, largo del mango, placa de diamante, lima de cartón.
const FILE_W := 16.0
const FILE_T := 4.0
const HANDLE_MM := 95.0
const DIAMOND_MM := 110.0
const BOARD_MM := 180.0
## Lo que se estrecha la punta de la lima (fracción del largo y ancho que queda en la punta; dibujo).
const FILE_TAPER := 0.4
const FILE_TIP_W := 0.55
## El torno: cuerpo de Ø38 × 160 mm (dibujo); el tambor, el de CareData (12,7 mm).
const ROTARY_BODY_R := 19.0
const ROTARY_BODY_L := 160.0
## La amoladora: el largo de la ficha (CareData.TOOLS.amoladora.length_mm) y su sección, 1,5 × 1,75 in (38 × 44 mm).
const GRINDER_W := 38.0
const GRINDER_H := 44.0
## Posiciones del botón del interruptor de la amoladora a lo largo de su carril (mm), una por velocidad.
const GRINDER_SLIDE := [-118.0, -110.0, -102.0, -94.0]

const MM := 0.001


static func _steel(color := "#9EA3A8", rough := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = 0.9
	m.roughness = rough
	return m


static func _plastic(color: String, rough := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = rough
	return m


static func _glass(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _led(color: Color) -> StandardMaterial3D:
	var led := StandardMaterial3D.new()
	led.albedo_color = color.darkened(0.4)
	led.emission_enabled = true
	led.emission = color
	led.emission_energy_multiplier = 0.0
	return led


## Material de la cara que corta: la lima de dientes (teeth_cm) o de grano (grain_um y sus colores).
static func abrasive_mat(tool_d: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ABRASIVE_SHADER
	if String(tool_d.get("element", "")) == "diente":
		m.set_shader_parameter("mode", 0)
		m.set_shader_parameter("teeth_per_mm", float(tool_d.teeth_cm) / 10.0)
		m.set_shader_parameter("double_cut", 1.0 if String(tool_d.id) == "lima_bastarda" else 0.0)
	else:
		m.set_shader_parameter("mode", 1)
		var g := float(tool_d.get("grain_um", 60.0)) / 1000.0
		m.set_shader_parameter("grain_mm", maxf(g * 1.6, 0.03))
		var id := String(tool_d.id)
		if id.begins_with("lima_diamante"):
			m.set_shader_parameter("grain_color", Color("#C9CDD2"))
			m.set_shader_parameter("bond_color", Color("#50565E"))
			m.set_shader_parameter("metal_grain", 1.0)
		elif String(tool_d.get("kind", "")) == "torno":
			m.set_shader_parameter("grain_color", Color("#8A5A32"))
			m.set_shader_parameter("bond_color", Color("#4A2E18"))
		else:
			m.set_shader_parameter("grain_color", Color("#9A6A40"))
			m.set_shader_parameter("bond_color", Color("#5E3D22"))
	return m


static func _box(parent: Node, size_mm: Vector3, center_mm: Vector3, mat: Material, n := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size_mm * MM
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = center_mm * MM
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


static func _basis_y(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var z := ref.cross(y).normalized()
	return Basis(y.cross(z), y, z)


static func _cyl(parent: Node, r_mm: float, h_mm: float, center_mm: Vector3, axis: Vector3, mat: Material, n := "", r2_mm := -1.0, segs := 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_mm * MM
	c.bottom_radius = (r2_mm if r2_mm >= 0.0 else r_mm) * MM
	c.height = h_mm * MM
	c.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.transform = Transform3D(_basis_y(axis), center_mm * MM)
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


static func _torus(parent: Node, r_in_mm: float, r_out_mm: float, center_mm: Vector3, axis: Vector3, mat: Material, n := "") -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in_mm * MM
	t.outer_radius = r_out_mm * MM
	t.rings = 24
	t.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = mat
	mi.transform = Transform3D(_basis_y(axis), center_mm * MM)
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


## Una pieza torneada a lo largo de X: profile = [[x (mm), radio (mm)], …] de un extremo al otro; sz: el ancho en z
## frente al alto (1: redonda). Normales suaves, con las tapas de los dos extremos.
static func _lathe(parent: Node, profile: Array, mat: Material, n := "", segs := 20, sz := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in profile.size():
		var x := float(profile[i][0])
		var r := float(profile[i][1])
		# la pendiente del perfil (para la normal)
		var a: Array = profile[maxi(i - 1, 0)]
		var b: Array = profile[mini(i + 1, profile.size() - 1)]
		var dr := float(b[1]) - float(a[1])
		var dx := maxf(float(b[0]) - float(a[0]), 1e-6)
		var ring: Array = []
		for k in segs + 1:
			var th := TAU * float(k) / float(segs)
			var c := cos(th)
			var s := sin(th)
			var nrm := Vector3(-dr / dx, c, s * sz).normalized()
			ring.append([Vector3(x, r * c, r * s * sz) * MM, nrm])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in segs:
			var p00: Array = rings[i][k]
			var p01: Array = rings[i][k + 1]
			var p10: Array = rings[i + 1][k]
			var p11: Array = rings[i + 1][k + 1]
			for q: Array in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(q[1])
				st.add_vertex(q[0])
	# las tapas
	for e: Array in [[0, -1.0], [rings.size() - 1, 1.0]]:
		var ring: Array = rings[int(e[0])]
		var cx := float(profile[int(e[0])][0]) * MM
		for k in segs:
			var a2: Vector3 = ring[k][0]
			var b2: Vector3 = ring[k + 1][0]
			var c2 := Vector3(cx, 0, 0)
			st.set_normal(Vector3(float(e[1]), 0, 0))
			if float(e[1]) > 0.0:
				st.add_vertex(c2)
				st.add_vertex(a2)
				st.add_vertex(b2)
			else:
				st.add_vertex(c2)
				st.add_vertex(b2)
				st.add_vertex(a2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


## Una barra que se estrecha: de x0 a x1 (mm), ancho w0 → w1 y grueso t0 → t1, con la cara de arriba en y = top.
## La cara de arriba lleva UV en 0-1 (para el picado, con uv_mm) y la estrechez empieza en x_taper.
static func _tapered(parent: Node, x0: float, x1: float, x_taper: float, w0: float, w1: float, t0: float, t1: float, top: float,
		mat: Material, face: Material, n := "") -> Node3D:
	var node := Node3D.new()
	if n != "":
		node.name = n
	parent.add_child(node)
	var xs := [x0, x_taper, x1]
	var ws := [w0, w0, w1]
	var ts := [t0, t0, t1]
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 2:
		var xa := float(xs[i])
		var xb := float(xs[i + 1])
		var wa := float(ws[i]) * 0.5
		var wb := float(ws[i + 1]) * 0.5
		var ta := float(ts[i])
		var tb := float(ts[i + 1])
		var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * MM
		# los lados, el fondo
		for q: Array in [
			[v.call(xa, top, wa), v.call(xb, top, wb), v.call(xb, top - tb, wb), v.call(xa, top - ta, wa), Vector3.BACK],
			[v.call(xb, top, -wb), v.call(xa, top, -wa), v.call(xa, top - ta, -wa), v.call(xb, top - tb, -wb), Vector3.FORWARD],
			[v.call(xa, top - ta, wa), v.call(xb, top - tb, wb), v.call(xb, top - tb, -wb), v.call(xa, top - ta, -wa), Vector3.DOWN],
		]:
			body.set_normal(q[4])
			for idx: int in [0, 1, 2, 0, 2, 3]:
				body.add_vertex(q[idx])
		# la cara de arriba (UV: x a lo largo de 0 a 1, y a lo ancho)
		var ua := (xa - x0) / (x1 - x0)
		var ub := (xb - x0) / (x1 - x0)
		var quad := [[v.call(xa, top, -wa), Vector2(ua, 0.5 - wa / w0)], [v.call(xb, top, -wb), Vector2(ub, 0.5 - wb / w0)],
			[v.call(xb, top, wb), Vector2(ub, 0.5 + wb / w0)], [v.call(xa, top, wa), Vector2(ua, 0.5 + wa / w0)]]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			top_st.set_normal(Vector3.UP)
			top_st.set_uv(quad[idx][1])
			top_st.add_vertex(quad[idx][0])
	# la punta
	body.set_normal(Vector3.RIGHT)
	var w2 := float(ws[2]) * 0.5
	var t2 := float(ts[2])
	for p: Vector3 in [Vector3(x1, top, w2), Vector3(x1, top, -w2), Vector3(x1, top - t2, -w2), Vector3(x1, top, w2), Vector3(x1, top - t2, -w2), Vector3(x1, top - t2, w2)]:
		body.add_vertex(p * MM)
	var bm := MeshInstance3D.new()
	bm.name = "Cuerpo"
	bm.mesh = body.commit()
	bm.material_override = mat
	node.add_child(bm)
	var fm := MeshInstance3D.new()
	fm.name = "Picado"
	fm.mesh = top_st.commit()
	fm.material_override = face
	fm.position = Vector3(0, 0.05 * MM, 0)
	node.add_child(fm)
	return node


## Un cable: tramos de cilindro entre los puntos (mm).
static func _cable(parent: Node, pts: Array, r_mm: float, mat: Material, n := "Cable") -> void:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		_cyl(node, r_mm, a.distance_to(b) + r_mm, (a + b) * 0.5, b - a, mat, "Tramo", -1.0, 8)


## Una etiqueta impresa sobre un frasco o un tubo (dibujo): el texto en una cara, a lo largo de axis.
static func _label(parent: Node, text: String, at_mm: Vector3, basis: Basis, size_mm: float, color := Color("#1E2A33"), mobile := false) -> void:
	if mobile:
		return
	var l := Label3D.new()
	l.name = "Etiqueta"
	l.text = text
	l.font = FONT
	l.font_size = 32
	l.pixel_size = size_mm * MM / 32.0
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.transform = Transform3D(basis, at_mm * MM)
	parent.add_child(l)


## Una herramienta de la bandeja (ids de ClawCareState.TRAY). → { root, id, kind, face_mat, drum, blade, blade_open,
## length_mm, half_mm (medio largo que trabaja), switch, led_mats, slider, drum_mm }
static func build(parent: Node3D, id: String, mobile: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "Herramienta_" + id
	parent.add_child(root)
	var tool_d := CareData.tool(id)
	var out := { "root": root, "id": id, "kind": String(tool_d.get("kind", id)), "face_mat": null, "drum": null,
		"blade": null, "length_mm": 60.0, "half_mm": 20.0, "drum_mm": float(tool_d.get("drum_mm", 12.7)) }
	match id:
		"lima_bastarda", "lima_entrefina", "lima_fina":
			_file(root, tool_d, out, id == "lima_fina", mobile)
		"lima_diamante_gruesa", "lima_diamante_fina":
			_diamond(root, tool_d, out)
		"lija_p180", "lija_p240":
			_board(root, tool_d, out)
		"torno":
			_rotary(root, tool_d, out, mobile)
		"amoladora":
			_grinder(root, tool_d, out, mobile)
		"guillotina":
			_guillotine(root, tool_d, out)
		"tijera":
			_scissors(root, tool_d, out)
		"tenaza":
			_nippers(root, tool_d, out)
		"agua":
			_bowl(root, out)
		"presion":
			_gauze(root, out)
		"hemostatico":
			_jar(root, out, "#C8A060", "#7A5A2A", "HEMOSTÁTICO", mobile)
		"nitrato_plata":
			_pencil(root, out, mobile)
		"clorhexidina":
			_bottle(root, out, "#E9F2F7", "#D4447A", "CLORHEXIDINA 0,05 %", mobile)
		"crema":
			_swab(root, out, "#F3E6C8")
		"metacrilato":
			_applicator(root, out, mobile)
		# unidad 5o: colocar a mano la pieza de la reforja
		"alcohol":
			_bottle(root, out, "#F4F7F9", "#2F6FB5", "ALCOHOL ISOPROPÍLICO", mobile)
		"espatula":
			_spatula(root, out)
	return out


## El mango torneado de madera con su virola de latón, de from_x hacia −X (mm).
static func _handle(root: Node3D, from_x: float, mat: Material) -> void:
	var y := -FILE_T * 0.5
	var h := _lathe(root, [[0.0, 9.6], [6.0, 9.6], [6.5, 8.6], [14.0, 9.4], [40.0, 11.2], [70.0, 10.4], [88.0, 9.4], [93.0, 8.0], [HANDLE_MM, 4.0]],
		mat, "Mango", 20)
	h.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(from_x, y, 0.0) * MM)
	_cyl(root, 9.8, 6.0, Vector3(from_x - 3.0, y, 0.0), Vector3.RIGHT, _steel("#B9A06A", 0.25), "Virola")


## Lima de acero: plana o de media caña, con la cara de dientes arriba (y = 0) de x = −75 a +75 mm, la punta que se
## estrecha, la espiga y el mango.
static func _file(root: Node3D, tool_d: Dictionary, out: Dictionary, half_round: bool, _mobile: bool) -> void:
	var face := abrasive_mat(tool_d)
	var steel := _steel("#6F747A", 0.4)
	var x0 := -FILE_MM * 0.5
	var x1 := FILE_MM * 0.5
	var xt := x1 - FILE_MM * FILE_TAPER
	if half_round:
		# media caña: la cara plana arriba (con el picado), el lomo redondeado abajo
		var hr := _lathe(root, [[x0, FILE_W * 0.5], [xt, FILE_W * 0.5], [x1, FILE_W * 0.5 * FILE_TIP_W]], steel, "Lomo", 16, 1.0)
		hr.scale = Vector3(1.0, 0.45, 1.0)
		hr.position = Vector3(0.0, -FILE_T * 0.15, 0.0) * MM
		_tapered(root, x0, x1, xt, FILE_W, FILE_W * FILE_TIP_W, FILE_T * 0.4, FILE_T * 0.3, 0.0, steel, face, "Cara")
	else:
		_tapered(root, x0, x1, xt, FILE_W, FILE_W * FILE_TIP_W, FILE_T, FILE_T * 0.6, 0.0, steel, face, "Cuerpo")
	face.set_shader_parameter("uv_mm", Vector2(FILE_MM, FILE_W))
	# la espiga (sin picado) y el mango
	_box(root, Vector3(10.0, FILE_T * 0.9, FILE_W * 0.85), Vector3(x0 - 5.0, -FILE_T * 0.5, 0.0), steel, "Talon")
	_box(root, Vector3(22.0, 3.0, 6.0), Vector3(x0 - 16.0, -FILE_T * 0.5, 0.0), steel, "Espiga")
	_handle(root, x0 - 22.0, _plastic("#8A5A34", 0.62))
	out["face_mat"] = face
	out["length_mm"] = FILE_MM
	out["half_mm"] = FILE_MM * 0.5


static func _diamond(root: Node3D, tool_d: Dictionary, out: Dictionary) -> void:
	var face := abrasive_mat(tool_d)
	_box(root, Vector3(DIAMOND_MM, 2.0, 18.0), Vector3(0.0, -1.0, 0.0), _steel("#5D646C", 0.35), "Placa")
	var q := QuadMesh.new()
	q.size = Vector2(DIAMOND_MM, 18.0) * MM
	var qm := MeshInstance3D.new()
	qm.mesh = q
	qm.material_override = face
	qm.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.05, 0.0) * MM)
	root.add_child(qm)
	face.set_shader_parameter("uv_mm", Vector2(DIAMOND_MM, 18.0))
	var col := "#2F5FA8" if String(tool_d.id).ends_with("gruesa") else "#C0392B"
	var grip := _lathe(root, [[0.0, 7.0], [8.0, 9.5], [60.0, 10.5], [86.0, 9.0], [92.0, 5.0]], _plastic(col, 0.45), "Mango", 18, 0.7)
	grip.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-DIAMOND_MM * 0.5, -2.5, 0.0) * MM)
	_cyl(root, 7.5, 4.0, Vector3(-DIAMOND_MM * 0.5 - 1.0, -2.5, 0.0), Vector3.RIGHT, _steel("#C9CED3", 0.25), "Casquillo")
	out["face_mat"] = face
	out["length_mm"] = DIAMOND_MM
	out["half_mm"] = DIAMOND_MM * 0.5


static func _board(root: Node3D, tool_d: Dictionary, out: Dictionary) -> void:
	var face := abrasive_mat(tool_d)
	_box(root, Vector3(BOARD_MM, 2.6, 19.0), Vector3(0.0, -1.3, 0.0), _plastic("#E8DCC4", 0.9), "Carton")
	var q := QuadMesh.new()
	q.size = Vector2(BOARD_MM, 19.0) * MM
	var qm := MeshInstance3D.new()
	qm.mesh = q
	qm.material_override = face
	qm.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.05, 0.0) * MM)
	root.add_child(qm)
	face.set_shader_parameter("uv_mm", Vector2(BOARD_MM, 19.0))
	out["face_mat"] = face
	out["length_mm"] = BOARD_MM
	out["half_mm"] = BOARD_MM * 0.4


## El tambor de lija (Ø de CareData) en el eje X, con el punto de contacto en lo alto (y = 0); su mandril y la tuerca.
static func _drum(root: Node3D, tool_d: Dictionary, out: Dictionary) -> float:
	var d_mm := float(tool_d.drum_mm)
	var r_drum := d_mm * 0.5
	var face := abrasive_mat(tool_d)
	face.set_shader_parameter("circumference", PI * d_mm)
	face.set_shader_parameter("uv_mm", Vector2(PI * d_mm, 12.7))
	# el lado del CylinderMesh solo usa V de 0 a 0,5 (las tapas, el resto): sin esto, el grano sale estirado y la banda
	# gastada, en un extremo del tambor en vez de en medio, donde toca la garra
	face.set_shader_parameter("v_scale", 2.0)
	var drum := Node3D.new()
	drum.name = "Tambor"
	drum.position = Vector3(0.0, -r_drum, 0.0) * MM
	root.add_child(drum)
	var dc := CylinderMesh.new()
	dc.top_radius = r_drum * MM
	dc.bottom_radius = r_drum * MM
	dc.height = 12.7 * MM
	dc.radial_segments = 24
	var dm := MeshInstance3D.new()
	dm.mesh = dc
	dm.material_override = face
	dm.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
	drum.add_child(dm)
	# la arandela del extremo del mandril (gira con la banda)
	_cyl(drum, 2.6, 1.2, Vector3(7.0, 0, 0), Vector3.RIGHT, _steel("#D8DCE0", 0.18), "Arandela")
	out["face_mat"] = face
	out["drum"] = drum
	return -r_drum


static func _rotary(root: Node3D, tool_d: Dictionary, out: Dictionary, _mobile: bool) -> void:
	var axis_y := _drum(root, tool_d, out)
	_cyl(root, 1.6, 16.0, Vector3(-12.0, axis_y, 0.0), Vector3.RIGHT, _steel("#C9CED3", 0.2), "Mandril")
	_cyl(root, 4.2, 6.0, Vector3(-20.0, axis_y, 0.0), Vector3.RIGHT, _steel("#B8BEC4", 0.25), "Tuerca", -1.0, 6)
	_cyl(root, 10.0, 22.0, Vector3(-29.0, axis_y, 0.0), Vector3.RIGHT, _steel("#8E949A", 0.3), "Boquilla", ROTARY_BODY_R * 0.75)
	var body := _plastic("#2B2F36", 0.45)
	var shell := _lathe(root, [[-40.0, ROTARY_BODY_R * 0.78], [-55.0, ROTARY_BODY_R], [-170.0, ROTARY_BODY_R * 1.02], [-195.0, ROTARY_BODY_R * 0.9],
		[-200.0, ROTARY_BODY_R * 0.6]], body, "Cuerpo", 22)
	shell.position = Vector3(0.0, axis_y, 0.0) * MM
	var grip := _lathe(root, [[-70.0, ROTARY_BODY_R + 0.2], [-72.0, ROTARY_BODY_R + 0.8], [-125.0, ROTARY_BODY_R + 0.9], [-127.0, ROTARY_BODY_R + 0.2]],
		_plastic("#2E6FB5", 0.6), "Agarre", 22)
	grip.position = Vector3(0.0, axis_y, 0.0) * MM
	var sw := _box(root, Vector3(16.0, 4.0, 9.0), Vector3(-70.0, axis_y + ROTARY_BODY_R + 1.5, 0.0), _plastic("#E0E4E8", 0.4), "Interruptor")
	var led := _led(Color(0.2, 1.0, 0.35))
	var ledm := _box(root, Vector3(4.0, 1.5, 4.0), Vector3(-56.0, axis_y + ROTARY_BODY_R + 0.4, 0.0), led, "Piloto")
	out["switch"] = sw
	out["led"] = ledm
	out["led_mat"] = led
	out["led_mats"] = [led]
	out["length_mm"] = ROTARY_BODY_L + 40.0
	out["half_mm"] = 6.0


## Un trozo de cilindro hueco (el protector): de radio r, largo len a lo largo de X desde x0, que cubre de a0 a a1
## (radianes, 0 arriba, hacia +Z), con las dos caras.
static func _shell(parent: Node, r: float, x0: float, len: float, a0: float, a1: float, mat: Material, n: String, y0: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 18
	for k in segs:
		var ta := lerpf(a0, a1, float(k) / float(segs))
		var tb := lerpf(a0, a1, float(k + 1) / float(segs))
		var na := Vector3(0, cos(ta), sin(ta))
		var nb := Vector3(0, cos(tb), sin(tb))
		var pa0 := (Vector3(x0, y0, 0) + na * r) * MM
		var pa1 := (Vector3(x0 + len, y0, 0) + na * r) * MM
		var pb0 := (Vector3(x0, y0, 0) + nb * r) * MM
		var pb1 := (Vector3(x0 + len, y0, 0) + nb * r) * MM
		for q: Array in [[pa0, na], [pa1, na], [pb1, nb], [pa0, na], [pb1, nb], [pb0, nb]]:
			st.set_normal(q[1])
			st.add_vertex(q[0])
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## La amoladora de uñas con protector (CareData.TOOLS.amoladora: la ficha del Dremel 7760-PGK): la banda de lija de 1/2″
## en lo alto del eje (y = 0), el protector translúcido que la rodea dejando la ventana de arriba (la guía de 45°), el
## collar metálico, el cuerpo de 38 × 44 mm con su agarre blando, el interruptor deslizante con sus cuatro posiciones y
## sus cuatro pilotos de velocidad, las rejillas del motor y el conector de carga.
static func _grinder(root: Node3D, tool_d: Dictionary, out: Dictionary, mobile: bool) -> void:
	var axis_y := _drum(root, tool_d, out)
	var L := float(tool_d.get("length_mm", 190.5))
	var hw := GRINDER_W * 0.5
	var hh := GRINDER_H * 0.5
	var sz := GRINDER_W / GRINDER_H
	_cyl(root, 1.6, 12.0, Vector3(-11.0, axis_y, 0.0), Vector3.RIGHT, _steel("#C9CED3", 0.18), "Mandril")
	_cyl(root, 4.0, 5.0, Vector3(-17.5, axis_y, 0.0), Vector3.RIGHT, _steel("#BFC5CA", 0.2), "Tuerca", -1.0, 6)
	# el collar metálico de la boca (refleja la luz) y el cuerpo: la nariz que se estrecha, el cuerpo y la cola
	var collar := _lathe(root, [[-20.0, 6.5], [-24.0, 9.5], [-34.0, 11.0], [-36.0, 11.5]], _steel("#D9DDE1", 0.14), "Collar", 22)
	collar.position = Vector3(0.0, axis_y, 0.0) * MM
	var grey := _plastic("#9AA1A8", 0.38)
	grey.metallic_specular = 0.6
	var shell := _lathe(root, [[-36.0, 11.5], [-52.0, hh * 0.78], [-80.0, hh], [-L + 18.0, hh * 0.98], [-L + 4.0, hh * 0.86], [-L, hh * 0.55]], grey,
		"Cuerpo", 26, sz)
	shell.position = Vector3(0.0, axis_y, 0.0) * MM
	var grip := _lathe(root, [[-84.0, hh + 0.2], [-88.0, hh + 1.0], [-150.0, hh + 1.1], [-154.0, hh + 0.2]], _plastic("#2A8C8C", 0.7), "Agarre", 26, sz)
	grip.position = Vector3(0.0, axis_y, 0.0) * MM
	# el protector: un capuchón translúcido ahumado alrededor de la banda, con la ventana arriba (la guía de 45°: deja
	# entrar la uña de lado y solo asoma la punta) y su anillo de ajuste
	var guard := Node3D.new()
	guard.name = "Protector"
	root.add_child(guard)
	var smoky := _glass(Color(0.32, 0.36, 0.42), 0.38)
	smoky.roughness = 0.12
	smoky.metallic_specular = 0.9
	_shell(guard, 11.5, -6.0, 18.0, deg_to_rad(40.0), deg_to_rad(320.0), smoky, "Capuchon", axis_y)
	_torus(guard, 11.0, 13.0, Vector3(-8.0, axis_y, 0.0), Vector3.RIGHT, _plastic("#3A4048", 0.45), "Anillo")
	_cyl(guard, 11.5, 1.2, Vector3(11.4, axis_y, 0.0), Vector3.RIGHT, smoky, "Tapa")
	# el interruptor deslizante con su carril y los cuatro pilotos de velocidad, arriba del agarre
	var top := axis_y + hh
	_box(root, Vector3(34.0, 1.2, 8.0), Vector3(-106.0, top + 0.6, 0.0), _plastic("#1E2226", 0.5), "Carril")
	var slider := _box(root, Vector3(9.0, 3.6, 10.0), Vector3(float(GRINDER_SLIDE[0]), top + 1.8, 0.0), _plastic("#E6EAED", 0.35), "Interruptor")
	var leds: Array = []
	for i in 4:
		var led := _led(Color(0.35, 1.0, 0.55) if i < 3 else Color(1.0, 0.7, 0.2))
		_box(root, Vector3(2.6, 1.0, 2.6), Vector3(-76.0 + 5.0 * float(i), top + 0.3, 0.0), led, "Piloto%d" % (i + 1))
		leds.append(led)
	if not mobile:
		# las rejillas del motor (ranuras oscuras a los lados) y el conector de carga en la cola
		var vent := _plastic("#22262A", 0.6)
		for s: float in [1.0, -1.0]:
			for k in 5:
				_box(root, Vector3(9.0, 1.4, 1.0), Vector3(-160.0 + 4.0 * float(k), axis_y + 6.0, s * hw * 0.98), vent, "Rejilla")
		_box(root, Vector3(1.5, 3.0, 8.0), Vector3(-L + 0.4, axis_y, 0.0), vent, "Conector")
		_label(root, "4 V", Vector3(-130.0, axis_y + 2.0, hw + 0.25), Basis.IDENTITY, 6.0, Color("#E6EAED"))
	out["switch"] = slider
	out["slider"] = slider
	out["slider_y"] = top + 1.8
	out["led_mats"] = leds
	out["led_mat"] = leds[0]
	out["guard"] = guard
	out["length_mm"] = L
	out["half_mm"] = 6.0


## Guillotina: un anillo por el que pasa la garra (a lo largo de +X) y una hoja que lo cruza al cerrarse; los mangos de
## chapa cromada con sus fundas rojas y el muelle entre ellos.
static func _guillotine(root: Node3D, tool_d: Dictionary, out: Dictionary) -> void:
	var jaw := float(tool_d.jaw_mm)
	var chrome := _steel("#D5D9DD", 0.16)
	_torus(root, jaw * 0.5, jaw * 0.5 + 2.2, Vector3.ZERO, Vector3.RIGHT, chrome, "Anillo")
	_box(root, Vector3(3.0, jaw * 0.9, 6.0), Vector3(0.0, -jaw * 0.5 - 2.5, 0.0), chrome, "Cuello")
	var blade := Node3D.new()
	blade.name = "Hoja"
	root.add_child(blade)
	_box(blade, Vector3(1.2, jaw * 0.9, jaw + 4.0), Vector3(0.6, jaw * 0.95, 0.0), _steel("#E8EBEE", 0.1), "Filo")
	# los mangos de chapa, hacia −Y y abajo, con su funda y el muelle
	var grip := _plastic("#C0392B", 0.55)
	for s: float in [1.0, -1.0]:
		var plate := _box(root, Vector3(2.0, 92.0, 7.0), Vector3(0.0, -jaw * 0.5 - 48.0, 5.5 * s), chrome, "Chapa")
		plate.rotation = Vector3(0.12 * s, 0.0, 0.0)
		var sleeve := _box(root, Vector3(4.0, 52.0, 9.0), Vector3(0.0, -jaw * 0.5 - 70.0, 8.0 * s), grip, "Funda")
		sleeve.rotation = Vector3(0.12 * s, 0.0, 0.0)
	for k in 6:
		_torus(root, 1.6, 2.4, Vector3(0.0, -jaw * 0.5 - 20.0 - 2.2 * float(k), 0.0), Vector3.UP, _steel("#AEB4BA", 0.3), "Muelle")
	out["blade"] = blade
	out["blade_open"] = Vector3(0.0, jaw * 0.95 * MM, 0.0)
	out["blade_closed"] = Vector3.ZERO
	out["length_mm"] = 110.0
	out["half_mm"] = jaw * 0.5


## Cortaúñas de tijera: dos hojas curvas de acero que se cruzan en la garra, el eje con su tornillo y los mangos de metal
## con sus anillas.
static func _scissors(root: Node3D, tool_d: Dictionary, out: Dictionary) -> void:
	var jaw := float(tool_d.jaw_mm)
	var chrome := _steel("#D5D9DD", 0.16)
	_box(root, Vector3(2.0, jaw * 0.6, 3.0), Vector3(0.0, -jaw * 0.55, 0.0), chrome, "HojaFija")
	var blade := Node3D.new()
	blade.name = "Hoja"
	root.add_child(blade)
	_box(blade, Vector3(2.0, jaw * 0.6, 3.0), Vector3(0.0, jaw * 0.55, 0.0), chrome, "HojaMovil")
	for s: float in [1.0, -1.0]:
		_cyl(root, 2.6, 70.0, Vector3(-36.0, s * jaw * 0.9, 0.0), Vector3(1.0, -0.15 * s, 0.0), chrome, "Mango")
		_torus(root, 7.0, 10.0, Vector3(-74.0, s * jaw * 1.6, 0.0), Vector3.BACK, _plastic("#E67E22", 0.55), "Anilla")
	_cyl(root, 4.0, 4.5, Vector3(-4.0, 0.0, 0.0), Vector3.BACK, chrome, "Eje")
	_cyl(root, 1.8, 5.0, Vector3(-4.0, 0.0, 0.0), Vector3.BACK, _steel("#7E858C", 0.3), "Tornillo")
	out["blade"] = blade
	out["blade_open"] = Vector3(0.0, jaw * 0.3 * MM, 0.0)
	out["blade_closed"] = Vector3(0.0, -jaw * 0.5 * MM, 0.0)
	out["length_mm"] = 100.0
	out["half_mm"] = jaw * 0.5


## Tenazas de herrador: mordazas de acero forjado que se cierran sobre la garra, la articulación y los mangos largos de
## acero con sus puños.
static func _nippers(root: Node3D, tool_d: Dictionary, out: Dictionary) -> void:
	var jaw := float(tool_d.jaw_mm)
	var forged := _steel("#5E656C", 0.42)
	var edge := _steel("#C8CDD2", 0.2)
	_box(root, Vector3(6.0, jaw * 0.35, jaw * 0.9), Vector3(0.0, -jaw * 0.6, 0.0), forged, "MordazaFija")
	_box(root, Vector3(1.2, jaw * 0.1, jaw * 0.9), Vector3(3.2, -jaw * 0.45, 0.0), edge, "FiloFijo")
	var blade := Node3D.new()
	blade.name = "Hoja"
	root.add_child(blade)
	_box(blade, Vector3(6.0, jaw * 0.35, jaw * 0.9), Vector3(0.0, jaw * 0.6, 0.0), forged, "MordazaMovil")
	_box(blade, Vector3(1.2, jaw * 0.1, jaw * 0.9), Vector3(3.2, jaw * 0.45, 0.0), edge, "Filo")
	_cyl(root, 7.0, jaw * 0.95, Vector3(-14.0, 0.0, 0.0), Vector3.BACK, forged, "Articulacion")
	var grip := _plastic("#B03A2E", 0.6)
	for s: float in [1.0, -1.0]:
		_cyl(root, 4.5, 300.0, Vector3(-160.0, s * jaw * 0.4, 0.0), Vector3(1.0, -0.06 * s, 0.0), forged, "Mango")
		_cyl(root, 6.0, 90.0, Vector3(-270.0, s * (jaw * 0.4 + 6.5), 0.0), Vector3(1.0, -0.06 * s, 0.0), grip, "Puno")
	out["blade"] = blade
	out["blade_open"] = Vector3.ZERO
	out["blade_closed"] = Vector3(0.0, -jaw * 0.45 * MM, 0.0)
	out["length_mm"] = 340.0
	out["half_mm"] = jaw * 0.5


static func _bowl(root: Node3D, out: Dictionary) -> void:
	var bowl := _lathe(root, [[-26.0, 22.0], [-24.0, 29.0], [-10.0, 33.0], [0.0, 34.5]], _plastic("#F2F4F5", 0.2), "Cuenco", 24)
	bowl.rotation = Vector3(0, 0, PI * 0.5)
	_cyl(root, 31.0, 1.0, Vector3(0.0, -4.0, 0.0), Vector3.UP, _glass(Color(0.55, 0.78, 0.92), 0.7), "Agua")
	out["length_mm"] = 70.0


static func _gauze(root: Node3D, out: Dictionary) -> void:
	_box(root, Vector3(40.0, 5.0, 40.0), Vector3(0.0, -2.5, 0.0), _plastic("#F7F7F2", 0.95), "Gasa")
	_box(root, Vector3(38.0, 0.6, 38.0), Vector3(0.0, 0.2, 0.0), _plastic("#EEEEE6", 0.95), "Pliegue")
	out["length_mm"] = 40.0


static func _jar(root: Node3D, out: Dictionary, powder: String, lid: String, label: String, mobile: bool) -> void:
	_cyl(root, 14.0, 34.0, Vector3(0.0, -17.0, 0.0), Vector3.UP, _glass(Color(0.9, 0.9, 0.95), 0.55), "Bote")
	_cyl(root, 12.5, 18.0, Vector3(0.0, -24.0, 0.0), Vector3.UP, _plastic(powder, 0.95), "Polvo")
	_cyl(root, 15.0, 6.0, Vector3(0.0, -37.0, 0.0), Vector3.UP, _plastic(lid, 0.5), "Tapa")
	_cyl(root, 14.2, 12.0, Vector3(0.0, -14.0, 0.0), Vector3.UP, _plastic("#F4F1EA", 0.6), "Etiqueta")
	_label(root, label, Vector3(0.0, -14.0, 14.4), Basis.IDENTITY, 3.2, Color("#7A2A1A"), mobile)
	out["length_mm"] = 40.0


static func _pencil(root: Node3D, out: Dictionary, mobile: bool) -> void:
	_cyl(root, 3.0, 120.0, Vector3(-60.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#E8E2D4", 0.6), "Palito")
	_cyl(root, 3.0, 10.0, Vector3(-3.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#3A3A3E", 0.4), "Punta")
	_cyl(root, 3.2, 26.0, Vector3(-70.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#2F6FB5", 0.5), "Funda")
	_label(root, "AgNO₃", Vector3(-70.0, 3.3, 0.0), Basis(Vector3.RIGHT, -PI * 0.5), 3.0, Color("#FFFFFF"), mobile)
	out["length_mm"] = 120.0


static func _bottle(root: Node3D, out: Dictionary, body: String, cap: String, label: String, mobile: bool) -> void:
	_cyl(root, 3.0, 12.0, Vector3(-6.0, 0.0, 0.0), Vector3.RIGHT, _plastic(cap, 0.4), "Boquilla", 1.0)
	_cyl(root, 9.0, 8.0, Vector3(-15.0, 0.0, 0.0), Vector3.RIGHT, _plastic(cap, 0.45), "Tapon")
	_lathe(root, [[-19.0, 9.0], [-26.0, 18.0], [-82.0, 18.0], [-84.0, 16.0]], _plastic(body, 0.28), "Frasco", 22)
	_cyl(root, 18.3, 34.0, Vector3(-55.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#FFFFFF", 0.55), "Etiqueta")
	_label(root, label, Vector3(-55.0, 18.6, 0.0), Basis(Vector3.RIGHT, -PI * 0.5), 3.4, Color("#B0275A"), mobile)
	out["length_mm"] = 90.0


static func _swab(root: Node3D, out: Dictionary, tip: String) -> void:
	_cyl(root, 1.2, 70.0, Vector3(-38.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#F2F2F2", 0.5), "Palillo")
	var s := SphereMesh.new()
	s.radius = 3.5 * MM
	s.height = 9.0 * MM
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = _plastic(tip, 0.95)
	mi.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-2.5, 0.0, 0.0) * MM)
	root.add_child(mi)
	out["length_mm"] = 75.0


static func _applicator(root: Node3D, out: Dictionary, mobile: bool) -> void:
	_cyl(root, 1.0, 10.0, Vector3(-5.0, 0.0, 0.0), Vector3.RIGHT, _steel("#C9CED3", 0.2), "Aguja")
	_cyl(root, 6.0, 60.0, Vector3(-40.0, 0.0, 0.0), Vector3.RIGHT, _glass(Color(0.95, 0.95, 0.98), 0.6), "Jeringa")
	_cyl(root, 5.0, 40.0, Vector3(-52.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#F0EBE0", 0.5), "Pasta")
	_cyl(root, 9.0, 2.0, Vector3(-71.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#F0F0F0", 0.4), "Aletas")
	_cyl(root, 2.0, 18.0, Vector3(-80.0, 0.0, 0.0), Vector3.RIGHT, _plastic("#F0F0F0", 0.4), "Embolo")
	_label(root, "METACRILATO", Vector3(-38.0, 6.1, 0.0), Basis(Vector3.RIGHT, -PI * 0.5), 2.4, Color("#1E2A33"), mobile)
	out["length_mm"] = 80.0


## La espátula de acero de modelar (unidad 5o): mango de acero moleteado y una hoja plana y fina, para el acrílico, la resina y lo
## que rebosa en fresco (dibujo).
static func _spatula(root: Node3D, out: Dictionary) -> void:
	var steel := _steel("#C9CED3", 0.22)
	_box(root, Vector3(22.0, 0.6, 6.0), Vector3(-11.0, 0.0, 0.0), steel, "Hoja")
	_cyl(root, 1.4, 14.0, Vector3(-29.0, 0.0, 0.0), Vector3.RIGHT, steel, "Cuello")
	_cyl(root, 3.2, 90.0, Vector3(-81.0, 0.0, 0.0), Vector3.RIGHT, _steel("#8E949A", 0.55), "Mango")
	out["length_mm"] = 126.0


## Lo de la colocación que no se coge como una herramienta (unidad 5o; dibujo, en m, apoyado en y = 0): la jeringa doble del
## adhesivo con su cánula mezcladora, el vaso de vidrio del acrílico con su masa, los frascos del polvo y del líquido, la
## jeringa de la resina, la lámpara LED con su guía de luz y su luz azul, la venda autoadherente y la pala del filtro naranja.
## { root, syringe, cup, dough, dough_mat, lamp, lamp_light, lamp_tip, bandage, shield }.
static func bond_props(parent: Node3D, mobile: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "Colocacion"
	parent.add_child(root)
	var out := { "root": root }
	# la jeringa doble (2:1) con la cánula mezcladora en espiral
	var syr := Node3D.new()
	syr.name = "JeringaDoble"
	root.add_child(syr)
	_cyl(syr, 6.0, 70.0, Vector3(-35.0, 6.0, -4.0), Vector3.RIGHT, _glass(Color(0.95, 0.93, 0.85), 0.75), "CartuchoA")
	_cyl(syr, 4.2, 70.0, Vector3(-35.0, 6.0, 7.0), Vector3.RIGHT, _glass(Color(0.85, 0.85, 0.9), 0.75), "CartuchoB")
	_cyl(syr, 2.6, 34.0, Vector3(17.0, 6.0, 0.0), Vector3.RIGHT, _plastic("#E8D24A", 0.4), "Canula", 1.2)
	for i in 6:
		_torus(syr, 2.0, 2.8, Vector3(6.0 + 4.0 * float(i), 6.0, 0.0), Vector3.RIGHT, _plastic("#D9B92E", 0.4), "Espiral")
	_box(syr, Vector3(6.0, 16.0, 26.0), Vector3(-72.0, 6.0, 1.5), _plastic("#3A3F46", 0.5), "Embolo")
	_label(syr, "EPOXI 2:1", Vector3(-35.0, 12.2, -4.0), Basis(Vector3.RIGHT, -PI * 0.5), 3.0, Color("#1E2A33"), mobile)
	syr.position = Vector3(-0.07, 0.0, -0.07)
	out["syringe"] = syr
	# el vaso de vidrio (dappen) con la masa del acrílico
	var cup := Node3D.new()
	cup.name = "VasoAcrilico"
	root.add_child(cup)
	var glass := _lathe(cup, [[0.0, 10.0], [16.0, 14.0], [18.0, 14.5]], _glass(Color(0.9, 0.95, 1.0), 0.45), "Vaso", 20)
	glass.rotation = Vector3(0, 0, PI * 0.5)
	var dough_mat := _plastic("#E6DCCF", 0.5)
	var dough := _cyl(cup, 10.5, 5.0, Vector3(0.0, 4.0, 0.0), Vector3.UP, dough_mat, "Masa")
	dough.visible = false
	cup.position = Vector3(0.06, 0.0, -0.07)
	out["cup"] = cup
	out["dough"] = dough
	out["dough_mat"] = dough_mat
	var pw := Node3D.new()
	pw.name = "Polvo"
	root.add_child(pw)
	_cyl(pw, 11.0, 34.0, Vector3(0.0, 17.0, 0.0), Vector3.UP, _plastic("#F2EDE4", 0.6), "Frasco")
	_cyl(pw, 11.5, 7.0, Vector3(0.0, 37.0, 0.0), Vector3.UP, _plastic("#C73A4A", 0.4), "Tapa")
	pw.position = Vector3(0.1, 0.0, -0.08)
	var lq := Node3D.new()
	lq.name = "Liquido"
	root.add_child(lq)
	_cyl(lq, 8.0, 40.0, Vector3(0.0, 20.0, 0.0), Vector3.UP, _glass(Color(0.75, 0.6, 0.35), 0.6), "Frasco")
	_cyl(lq, 4.0, 10.0, Vector3(0.0, 45.0, 0.0), Vector3.UP, _plastic("#20242A", 0.4), "Gotero", 1.5)
	lq.position = Vector3(0.12, 0.0, -0.035)
	# la jeringa de la resina (composite) con su tapón
	var rs := Node3D.new()
	rs.name = "JeringaResina"
	root.add_child(rs)
	_cyl(rs, 4.0, 60.0, Vector3(-30.0, 4.0, 0.0), Vector3.RIGHT, _plastic("#2A2E33", 0.5), "Cuerpo")
	_cyl(rs, 2.5, 8.0, Vector3(4.0, 4.0, 0.0), Vector3.RIGHT, _plastic("#EDE6D6", 0.6), "Punta", 1.0)
	_label(rs, "COMPOSITE A2", Vector3(-30.0, 8.2, 0.0), Basis(Vector3.RIGHT, -PI * 0.5), 2.6, Color("#FFFFFF"), mobile)
	rs.position = Vector3(-0.06, 0.0, 0.0)
	# la lámpara LED con su guía de luz curva y la luz azul (encendida solo al curar)
	var lamp := Node3D.new()
	lamp.name = "Lampara"
	root.add_child(lamp)
	_cyl(lamp, 10.0, 150.0, Vector3(-75.0, 10.0, 0.0), Vector3.RIGHT, _plastic("#F2F4F5", 0.35), "Cuerpo")
	_cyl(lamp, 4.0, 40.0, Vector3(18.0, 10.0, 0.0), Vector3.RIGHT, _glass(Color(0.85, 0.75, 0.55), 0.7), "GuiaDeLuz")
	var tip := Node3D.new()
	tip.name = "PuntaDeLaLampara"
	tip.position = Vector3(38.0, 10.0, 0.0) * MM
	lamp.add_child(tip)
	var light := SpotLight3D.new()
	light.name = "LuzAzul"
	light.light_color = Color(0.35, 0.55, 1.0)
	light.light_energy = 6.0
	light.spot_range = 0.08
	light.spot_angle = 14.0
	light.shadow_enabled = false
	light.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	light.visible = false
	tip.add_child(light)
	var glow := _cyl(tip, 4.2, 0.6, Vector3.ZERO, Vector3.RIGHT, _led(Color(0.35, 0.55, 1.0)), "Brillo")
	glow.visible = false
	lamp.position = Vector3(-0.02, 0.0, 0.07)
	out["lamp"] = lamp
	out["lamp_light"] = light
	out["lamp_glow"] = glow
	out["lamp_tip"] = tip
	# la venda autoadherente y la pala del filtro naranja
	var bd := _cyl(root, 14.0, 25.0, Vector3(0.0, 12.5, 0.0), Vector3.UP, _plastic("#5C9BD5", 0.9), "Venda")
	bd.position = Vector3(0.11, 0.0125, 0.06)
	out["bandage"] = bd
	var sh := Node3D.new()
	sh.name = "FiltroNaranja"
	root.add_child(sh)
	_box(sh, Vector3(50.0, 1.5, 40.0), Vector3(0.0, 0.75, 0.0), _glass(Color(1.0, 0.55, 0.1), 0.55), "Pala")
	_box(sh, Vector3(40.0, 3.0, 8.0), Vector3(-45.0, 1.5, 0.0), _plastic("#2A2E33", 0.5), "Mango")
	sh.position = Vector3(0.05, 0.0, 0.075)
	out["shield"] = sh
	return out


## La base de carga del torno (el 7300-PT es inalámbrico) con su cable enrollado: se queda en la bandeja (no es parte de
## la herramienta que se coge). En m, apoyada en y = 0.
static func charger(parent: Node3D) -> Node3D:
	var base := Node3D.new()
	base.name = "BaseDeCarga"
	parent.add_child(base)
	_box(base, Vector3(40.0, 14.0, 46.0), Vector3(0.0, 7.0, 0.0), _plastic("#30343A", 0.5), "Base")
	_box(base, Vector3(30.0, 2.0, 30.0), Vector3(0.0, 14.5, 0.0), _plastic("#1E2226", 0.4), "Cuna")
	var led := _led(Color(0.3, 0.6, 1.0))
	led.emission_energy_multiplier = 1.2
	_box(base, Vector3(3.0, 1.0, 3.0), Vector3(15.0, 14.5, 0.0), led, "Piloto")
	_cable(base, [Vector3(-20.0, 4.0, 6.0), Vector3(-34.0, 2.0, 14.0), Vector3(-30.0, 2.0, 30.0), Vector3(-10.0, 2.0, 36.0),
		Vector3(14.0, 2.0, 34.0), Vector3(30.0, 2.0, 40.0)], 1.6, _plastic("#1C1E22", 0.6))
	return base


## La bandeja de acero inoxidable: una caja de fondo bajo (en m, centrada en el origen, de ancho w y fondo d).
static func tray(parent: Node3D, w: float, d: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bandeja"
	parent.add_child(root)
	var steel := _steel("#C3C8CD", 0.28)
	var base := BoxMesh.new()
	base.size = Vector3(w, 0.002, d)
	var bm := MeshInstance3D.new()
	bm.mesh = base
	bm.material_override = steel
	bm.position = Vector3(0.0, 0.001, 0.0)
	root.add_child(bm)
	for side: Array in [[Vector3(0.0, 0.009, d * 0.5), Vector3(w, 0.018, 0.002)], [Vector3(0.0, 0.009, -d * 0.5), Vector3(w, 0.018, 0.002)],
			[Vector3(w * 0.5, 0.009, 0.0), Vector3(0.002, 0.018, d)], [Vector3(-w * 0.5, 0.009, 0.0), Vector3(0.002, 0.018, d)]]:
		var b := BoxMesh.new()
		b.size = side[1]
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = steel
		mi.position = side[0]
		root.add_child(mi)
	return root
