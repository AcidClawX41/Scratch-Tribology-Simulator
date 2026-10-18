## Amoladora angular y discos, procedurales (superficies de revolución). Marco local: el eje del husillo es +Z, el
## plano medio del disco es z = 0 y el cabezal queda detrás (z < 0). El cuerpo del motor sale hacia atrás y arriba
## (−X, +Y) y la empuñadura lateral, perpendicular al cuerpo y al husillo. Medidas típicas de una radial de
## 125 mm (dibujo, no un modelo concreto); colores neutros con el acento de la paleta del laboratorio.
extends RefCounted

const PB = preload("res://app/taller/radial3d/panel_builder.gd")
const Looks = preload("res://app/taller/radial3d/looks.gd")

## Ángulo del cuerpo del motor sobre la horizontal, hacia atrás.
const BODY_TILT_DEG := 20.0
## Agujero de los discos: 22,23 mm.
const BORE_M := 0.022225 / 2.0
## Partes del disco (UV2.x) para el shader disco.gdshader.
const PART_FACE := 0.0
const PART_RIM := 1.0
const PART_BACK := 2.0
const PART_BORE := 3.0
const PART_SEG_STEP := 4.0
const PART_SEG_FACE := 5.0
const PART_FLAP := 8.0


## Superficie de revolución alrededor de Z: perfil (r, z) en metros recorrido de modo que la normal exterior de
## cada tramo sea (−dz, dr). `parts`: id de parte de cada tramo (UV2.x). arc < TAU: revolución parcial.
static func revolve(
	profile: PackedVector2Array, segments: int, parts: PackedFloat32Array = PackedFloat32Array(),
	arc: float = TAU, start: float = 0.0
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		if p0.is_equal_approx(p1):
			continue
		var n2 := Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized()
		var part := parts[i] if i < parts.size() else 0.0
		for s in segments:
			var a0 := start + arc * float(s) / float(segments)
			var a1 := start + arc * float(s + 1) / float(segments)
			var q: Array[Dictionary] = []
			for e in [[p0, a0], [p0, a1], [p1, a1], [p1, a0]]:
				var p: Vector2 = e[0]
				var a: float = e[1]
				var c := Vector2(cos(a), sin(a))
				var pos := Vector3(c.x * p.x, c.y * p.x, p.y)
				var n := Vector3(c.x * n2.x, c.y * n2.x, n2.y)
				q.append({"p": pos, "n": n, "uv": Vector2(a / TAU, p.x), "uv2": Vector2(part, 0.0)})
			PB.quad(st, q[0], q[1], q[2], q[3])
	return st.commit()


static func _mat(hex: String, metallic: float, rough: float, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metallic
	m.roughness = rough
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _add(
	parent: Node3D, mesh: Mesh, mat: Material, xf := Transform3D.IDENTITY, node_name := ""
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


## Base cuyo eje Z apunta en `dir` (para girar un sólido de revolución hacia donde toca).
static func basis_z(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


## Construye la amoladora bajo `parent` para un disco de semiespesor half_t y radio disc_r (m). Devuelve los nodos
## que la escena mueve o recolorea.
static func build_grinder(parent: Node3D, half_t: float, disc_r: float) -> Dictionary:
	var steel := _mat("#C9CED4", 0.9, 0.28)
	var dark_steel := _mat("#5C636C", 0.85, 0.35)
	var alu := _mat("#A9AFB7", 0.8, 0.38)
	var body_mat := _mat("#2B2A31", 0.05, 0.55)
	var rubber := _mat("#18181C", 0.0, 0.85)
	var mint := _mat("#5BE0C8", 0.1, 0.45)
	var guard_mat := _mat("#6C7480", 0.7, 0.42, true)
	var out := {}
	var h := half_t
	# Brida exterior y tuerca (lado visible del disco)
	var nut := PackedVector2Array([
		Vector2(0.0048, h + 0.0056), Vector2(0.0160, h + 0.0056), Vector2(0.0176, h + 0.0044),
		Vector2(0.0176, h + 0.0003), Vector2(0.0048, h + 0.0003), Vector2(0.0048, h + 0.0056)])
	out["nut"] = _add(parent, revolve(nut, 48), steel, Transform3D.IDENTITY, "Tuerca")
	var shaft := PackedVector2Array([
		Vector2(0.0, h + 0.0062), Vector2(0.0046, h + 0.0062), Vector2(0.0046, h), Vector2(0.0, h)])
	_add(parent, revolve(shaft, 24), dark_steel, Transform3D.IDENTITY, "Husillo")
	# Agujeros de la llave de pivotes en la tuerca
	for k in 2:
		var hole := CylinderMesh.new()
		hole.top_radius = 0.0017
		hole.bottom_radius = 0.0017
		hole.height = 0.0012
		var pos := Vector3(0.0118 * (1.0 if k == 0 else -1.0), 0.0, h + 0.0053)
		_add(parent, hole, _mat("#1C1E22", 0.3, 0.6), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), pos))
	# Brida interior, cuello del husillo y cabezal (aluminio inyectado)
	var inner := PackedVector2Array([
		Vector2(0.0, -h - 0.0003), Vector2(0.0170, -h - 0.0003), Vector2(0.0170, -h - 0.0042),
		Vector2(0.0125, -h - 0.0050), Vector2(0.0125, -0.0210), Vector2(0.0, -0.0210)])
	_add(parent, revolve(inner, 48), steel, Transform3D.IDENTITY, "Brida")
	var head := PackedVector2Array([
		Vector2(0.0, -0.0205), Vector2(0.0300, -0.0205), Vector2(0.0345, -0.0240), Vector2(0.0360, -0.0290),
		Vector2(0.0360, -0.0560), Vector2(0.0340, -0.0610), Vector2(0.0290, -0.0640), Vector2(0.0, -0.0640)])
	out["head"] = _add(parent, revolve(head, 56), alu, Transform3D.IDENTITY, "Cabezal")
	# Cuerpo del motor
	var tilt := deg_to_rad(BODY_TILT_DEG)
	var b := Vector3(-cos(tilt), sin(tilt), 0.0)
	var up := Vector3(sin(tilt), cos(tilt), 0.0)
	var body_origin := Vector3(0.0, 0.0, -0.042) + b * 0.026
	var body_xf := Transform3D(basis_z(b), body_origin)
	var body := PackedVector2Array([
		Vector2(0.0, 0.196), Vector2(0.012, 0.194), Vector2(0.024, 0.187), Vector2(0.028, 0.174),
		Vector2(0.0315, 0.150), Vector2(0.0315, 0.026), Vector2(0.0290, 0.012), Vector2(0.0250, 0.0),
		Vector2(0.0, 0.0)])
	out["body"] = _add(parent, revolve(body, 48), body_mat, body_xf, "Motor")
	var ring := PackedVector2Array([Vector2(0.0318, 0.046), Vector2(0.0318, 0.030)])
	_add(parent, revolve(ring, 48), mint, body_xf, "Franja")
	var vents := PackedVector2Array([Vector2(0.0317, 0.168), Vector2(0.0317, 0.154)])
	_add(parent, revolve(vents, 48), _mat("#0E0E11", 0.0, 0.9), body_xf, "Rejilla")
	var cord := PackedVector2Array([
		Vector2(0.0, 0.232), Vector2(0.0070, 0.230), Vector2(0.0075, 0.190), Vector2(0.0, 0.190)])
	_add(parent, revolve(cord, 20), rubber, body_xf, "Cable")
	var switch := BoxMesh.new()
	switch.size = Vector3(0.014, 0.006, 0.034)
	var sw_basis := basis_z(b)
	var sw_pos := body_origin + b * 0.095 + up * 0.0325
	_add(parent, switch, mint, Transform3D(sw_basis.rotated(b, 0.0), sw_pos), "Interruptor")
	# Empuñadura lateral (roscada al cabezal, perpendicular al cuerpo y al husillo)
	var handle := PackedVector2Array([
		Vector2(0.0, 0.118), Vector2(0.013, 0.116), Vector2(0.0165, 0.104), Vector2(0.0165, 0.034),
		Vector2(0.0120, 0.020), Vector2(0.0075, 0.014), Vector2(0.0075, 0.0), Vector2(0.0, 0.0)])
	var handle_xf := Transform3D(basis_z(up), Vector3(0.0, 0.0, -0.042) + up * 0.033)
	out["handle"] = _add(parent, revolve(handle, 40), rubber, handle_xf, "Empunadura")
	# Protector: canal en U de ~170° sobre la mitad trasera del disco (deja libre el frente del corte, por donde
	# salen las chispas) y una abrazadera en el cuello.
	var gr := disc_r + 0.007
	var guard := PackedVector2Array([
		Vector2(0.0200, -h - 0.0048), Vector2(gr, -h - 0.0048), Vector2(gr, h + 0.0036), Vector2(gr - 0.0055, h + 0.0036)])
	var guard_mesh := revolve(guard, 64, PackedFloat32Array(), deg_to_rad(168.0), deg_to_rad(62.0))
	out["guard"] = _add(parent, guard_mesh, guard_mat, Transform3D.IDENTITY, "Protector")
	var clamp := PackedVector2Array([
		Vector2(0.0150, -h - 0.0060), Vector2(0.0150, -h - 0.0160), Vector2(0.0128, -h - 0.0160),
		Vector2(0.0128, -h - 0.0060), Vector2(0.0150, -h - 0.0060)])
	_add(parent, revolve(clamp, 40), guard_mat, Transform3D.IDENTITY, "Abrazadera")
	return out


## Malla del disco (radio en m). Perfiles por tipo; el dibujo de la cara (etiqueta, franja de velocidad, grano,
## segmentos, láminas) y el giro los hace disco.gdshader.
static func build_disc(disc_id: String, disc_r: float) -> ArrayMesh:
	var look := Looks.disc(disc_id)
	var kind := str(look["kind"])
	var r_in := BORE_M
	var h := float(look["t_mm"]) / 2000.0
	var prof := PackedVector2Array()
	var parts := PackedFloat32Array()
	if kind == "diamante" or kind == "borde":
		var hc := float(look["core_t_mm"]) / 2000.0
		var rs := disc_r - float(look["segment_mm"]) / 1000.0
		prof = PackedVector2Array([
			Vector2(r_in, hc), Vector2(rs, hc), Vector2(rs, h), Vector2(disc_r, h), Vector2(disc_r, -h),
			Vector2(rs, -h), Vector2(rs, -hc), Vector2(r_in, -hc), Vector2(r_in, hc)])
		parts = PackedFloat32Array([
			PART_FACE, PART_SEG_STEP, PART_SEG_FACE, PART_RIM, PART_SEG_FACE, PART_SEG_STEP, PART_BACK, PART_BORE])
	elif kind == "laminas":
		prof = PackedVector2Array([
			Vector2(r_in, 0.0012), Vector2(0.027, 0.0012), Vector2(0.030, 0.0092), Vector2(disc_r - 0.002, 0.0066),
			Vector2(disc_r, 0.0050), Vector2(disc_r, -0.0010), Vector2(r_in, -0.0010), Vector2(r_in, 0.0012)])
		parts = PackedFloat32Array([PART_FACE, PART_FLAP, PART_FLAP, PART_FLAP, PART_RIM, PART_BACK, PART_BORE])
	else:
		prof = PackedVector2Array([
			Vector2(r_in, h), Vector2(disc_r, h), Vector2(disc_r, -h), Vector2(r_in, -h), Vector2(r_in, h)])
		parts = PackedFloat32Array([PART_FACE, PART_RIM, PART_BACK, PART_BORE])
	return revolve(prof, 128, parts)


## Semiespesor (m) de lo que asoma del disco hacia la cara visible (para colocar la tuerca y las etiquetas).
static func disc_front(disc_id: String) -> float:
	var look := Looks.disc(disc_id)
	if str(look["kind"]) == "laminas":
		return 0.0012
	if str(look["kind"]) == "diamante" or str(look["kind"]) == "borde":
		return float(look["core_t_mm"]) / 2000.0
	return float(look["t_mm"]) / 2000.0
