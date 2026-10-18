## Afiladora 3D · afiladoras compactas: de brocas («afilabrocas»: caja con el puerto en ángulo y la muela dentro) y
## de fresas («afilafresas»: cabezal con pinza encima de la muela). La muela es de copa, con el eje vertical y el
## anillo abrasivo (CBN o diamante) arriba; la herramienta baja por el puerto hasta él.
##
## Proporciones de las fichas de MRCM (MR-13A: 32 × 18 × 19 cm y muela de Ø78 × 10 mm; MR-X3: 35 × 25 × 25 cm), sin
## logotipos ni marcas. La disposición interior (motor bajo la muela, puerto, pinza) es de dibujo: ESTIMACIÓN. La
## cara delantera es una ventana transparente para ver la muela y la punta (en la máquina real va cerrada).
##
## Broca: el eje forma con la cara de la muela la mitad del ángulo de punta (así un labio queda apoyado en ella) y
## contact_pos gira la pinza a un lado y a otro, como se hace para tallar la incidencia. Fresa: casi vertical,
## inclinada la incidencia, y contact_pos la mece dentro del paso de un labio.
extends RefCounted

const Parts = preload("res://app/taller/sharpen3d/parts.gd")

const HOUSING_LAYER := 2  # capa de la carcasa: la vista «seccion» de brocas y fresas no la dibuja
const RIM_MM := 8.0  # anchura del anillo abrasivo de la muela de copa (dibujo)


static func build(parent: Node3D, view: Dictionary, _mobile: bool) -> Dictionary:
	var kind := str(view.get("kind", "afilabrocas"))
	var mill := kind == "afilafresas"
	var root := Parts.node(parent, "AfiladoraDeFresas" if mill else "AfiladoraDeBrocas")
	var paint := Parts.mat(Color("#5F6873") if not mill else Color("#566069"), 0.35, 0.45)
	var dark := Parts.mat(Color("#1E2024"), 0.2, 0.6)
	var steel := Parts.mat(Color("#BFC4CA"), 1.0, 0.28)
	var accent := Parts.mat(Color("#5BE0C8"), 0.1, 0.45)
	var window := Parts.glass(Color("#E4F1F8"), 0.16)
	var hx := 0.175 if mill else 0.15
	var hz := 0.12 if mill else 0.08
	var top := 0.2 if mill else 0.17
	var y_face := 0.12 if mill else 0.1
	# Carcasa: base opaca, trasera, laterales y tapa; la parte delantera de arriba es una ventana
	var housing := Parts.node(root, "Carcasa")
	var parts: Array = []
	parts.append(Parts.box(housing, Vector3(-hx, 0.008, -hz), Vector3(hx, 0.05, hz), paint, 0.012))
	parts.append(Parts.box(housing, Vector3(-hx, 0.04, -hz), Vector3(hx, top, -hz + 0.006), paint, 0.004))
	for s: float in [-1.0, 1.0]:
		parts.append(Parts.box(housing, Vector3(s * hx - 0.003, 0.04, -hz), Vector3(s * hx + 0.003, top, hz), paint, 0.003))
	parts.append(Parts.box(housing, Vector3(-hx, top - 0.006, -hz), Vector3(hx, top, hz), paint, 0.004))
	var glass := Parts.box(housing, Vector3(-hx + 0.004, 0.05, hz - 0.003), Vector3(hx - 0.004, top - 0.006, hz), window, 0.0, "Ventana")
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.append(glass)
	for fx: float in [-hx + 0.03, hx - 0.03]:
		for fz: float in [-hz + 0.025, hz - 0.025]:
			parts.append(Parts.rod(housing, Vector3(fx, 0.0, fz), Vector3(fx, 0.009, fz), 0.012, dark, 16))
	parts.append(Parts.box(housing, Vector3(hx - 0.05, 0.02, hz - 0.002), Vector3(hx - 0.03, 0.036, hz + 0.004), accent, 0.002, "Interruptor"))
	for p in parts:
		(p as VisualInstance3D).layers = 1 << (HOUSING_LAYER - 1)
	# Muela de copa con el eje vertical y el anillo abrasivo arriba, y el motor debajo
	var w: Dictionary = {}
	for x in view.get("wheels", []):
		if x is Dictionary:
			w = x
			if bool(x.get("selected", false)):
				break
	var r := Parts.num(w, "d_mm", 78.0) / 2000.0
	var width := Parts.num(w, "width_mm", 10.0) / 1000.0
	var hw := width * 0.5
	var xw := -0.03
	var pivot := Parts.node(root, "Muela_disco", Transform3D(Parts.basis_x(Vector3.UP), Vector3(xw, y_face - hw, 0.0)))
	var rim_in := r - RIM_MM / 1000.0
	var bore := 0.00635
	var prof := PackedVector2Array([Vector2(-hw, bore), Vector2(-hw, r), Vector2(hw, r), Vector2(hw, rim_in),
		Vector2(-hw + 0.003, rim_in), Vector2(-hw + 0.003, bore), Vector2(-hw, bore)])
	var mat := Parts.wheel_material(w, 3, r, width, bore)
	mat.set_shader_parameter("rim_in_mm", rim_in * 1000.0)
	var surf := Parts.mesh_node(pivot, Parts.revolve(prof, 96), mat, Transform3D.IDENTITY, "Superficie")
	Parts.mesh_node(root, Parts.x_cylinder(-0.06, 0.0, 0.028, 32), dark,
		Transform3D(Parts.basis_x(Vector3.UP), Vector3(xw, y_face - hw, 0.0)), "Motor")
	var wheel := {
		"position": "disco", "view": w, "pivot": pivot, "mesh": surf, "mat": mat, "radius": r, "width": width,
		"center": Vector3(xw, y_face, 0.0), "axis": Vector3.UP, "spin": 1.0, "angle": 0.0, "grind": "cara",
		"rpm": Parts.num(w, "rpm", Parts.num(view, "rpm", 4400.0)), "wet": false, "honing": false, "shader": "muela",
		"rim_in": rim_in, "y_face": y_face, "handle_side": 1.0, "selected": true,
	}
	# Pinza que gira con la herramienta (construida en el marco de la herramienta: punta en el origen, eje +Y)
	var chuck := Parts.node(root, "Pinza")
	var knurl := Parts.mat(Color("#8A9098"), 0.9, 0.4)
	var nose := 0.022 if not mill else 0.03
	var body_r := 0.013 if not mill else 0.02
	Parts.mesh_node(chuck, _y_cylinder(nose, nose + 0.009, body_r * 0.8, 6), steel, Transform3D.IDENTITY, "Tuerca")
	Parts.mesh_node(chuck, _y_cylinder(nose + 0.009, nose + 0.075, body_r, 32), knurl, Transform3D.IDENTITY, "Cuerpo")
	for k in (2 if not mill else 4):
		var a := TAU * float(k) / (2.0 if not mill else 4.0)
		Parts.box(chuck, Vector3(body_r * cos(a) - 0.002, nose + 0.06, body_r * sin(a) - 0.002),
			Vector3(body_r * cos(a) + 0.002, nose + 0.075, body_r * sin(a) + 0.002), accent, 0.0005)
	# Puerto (broca) o cabezal (fresa): el manguito fijo por el que entra la pinza, sobre la tapa
	var port := Parts.node(root, "Puerto" if not mill else "Cabezal")
	var sleeve := Parts.mesh_node(port, _y_cylinder(0.0, 0.03, body_r + 0.004, 32), dark, Transform3D.IDENTITY, "Manguito")
	sleeve.layers = 1 << (HOUSING_LAYER - 1)
	return {
		"kind": kind, "root": root, "wheels": [wheel], "chuck": chuck, "port": port, "top": top, "mill": mill,
		"cam": {
			"general": { "target": Vector3(0.0, top * 0.62, 0.0), "yaw": 22.0, "pitch": 24.0, "distance": 0.62 + hx },
			"filo": { "yaw": 12.0, "pitch": 10.0, "distance": 0.07 },
		},
	}


static func _y_cylinder(y0: float, y1: float, r: float, sides: int) -> ArrayMesh:
	var m := Parts.x_cylinder(y0, y1, r, sides)
	var st := SurfaceTool.new()
	st.append_from(m, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
	return st.commit()


## Pose de la broca o la fresa en el puerto. Las hojas no caben en estas máquinas: quedan en la mesa.
static func pose(rig: Dictionary, tool: Dictionary, st: Dictionary, retract: float) -> Dictionary:
	var wheel: Dictionary = rig["wheels"][0]
	var out := { "wheel": wheel, "blade": bool(tool.get("blade", false)) }
	var mill: bool = rig["mill"]
	var kind := str(tool.get("kind", ""))
	var fits := (kind == "broca" and not mill) or (kind == "fresa" and mill)
	(rig["chuck"] as Node3D).visible = fits
	if not fits:
		out["idle"] = true
		return out
	var c: Vector3 = wheel["center"]
	var y_face: float = wheel["y_face"]
	var rim_in: float = wheel["rim_in"]
	var gap := 0.00008
	var u := clampf(float(st.get("contact_pos", 0.5)), 0.0, 1.0)
	var basis: Basis
	var apex: Vector3
	var axis: Vector3
	if not mill:
		# Eje a la mitad del ángulo de punta de la cara de la muela; el labio en la cara, hacia fuera (+x)
		var half := deg_to_rad(clampf(float(st.get("angle_deg", 118.0)), 80.0, 150.0) * 0.5)
		axis = Vector3(cos(half), sin(half), 0.0)
		var ex := Vector3(sin(half), -cos(half), 0.0)
		var ez := ex.cross(axis)
		var psi := (u - 0.5) * deg_to_rad(30.0)
		basis = Basis(ex, axis, ez) * Basis(Vector3.UP, float(tool.get("lip_theta", 0.0)) + psi)
		apex = Vector3(c.x + rim_in + 0.0005, y_face + gap, 0.0)
		out["beta"] = half
	else:
		# Fresa: casi vertical, con el labio que se talla hacia +x e inclinada la incidencia (la cara con incidencia
		# queda plana contra la muela)
		var alpha := deg_to_rad(clampf(float(st.get("angle_deg", 7.0)), 0.0, 20.0))
		var flutes := maxi(int(tool.get("flutes", 4)), 1)
		var psi2 := (u - 0.5) * TAU / float(flutes) * 0.25
		basis = Basis(Vector3.RIGHT, -alpha) * Basis(Vector3.UP, float(tool.get("lip_theta", 0.0)) + psi2)
		axis = basis * Vector3.UP
		var r_core := 0.3 * 2.0 * float(tool.get("radius", 0.006))
		apex = Vector3(c.x + rim_in - r_core * 0.5, y_face + gap, 0.0)
		out["beta"] = alpha
	var xf := Transform3D(basis, apex + axis * retract)
	out["tool_xf"] = xf
	# Sección: la punta de perfil. Broca, vista de frente: el labio sobre la cara de la muela y el eje a la mitad del
	# ángulo de punta. Fresa, vista a lo largo del filo frontal: el eje inclinado la incidencia desde la vertical
	out["apex"] = xf.origin
	out["arc_from"] = Vector3.RIGHT if not mill else Vector3.UP
	out["arc_to"] = axis
	out["view_dir"] = Vector3.BACK if not mill else Vector3.RIGHT
	out["sec_up"] = axis if not mill else Vector3.UP
	(rig["chuck"] as Node3D).transform = xf
	# El manguito del puerto sigue el eje (fijo en la máquina para un ángulo dado)
	var port: Node3D = rig["port"]
	var top: float = rig["top"]
	var s_top := (top - apex.y) / maxf(axis.y, 0.05)
	port.transform = Transform3D(Parts.basis_y(axis), apex + axis * (s_top - 0.015))
	var lip_mid := apex + Vector3.RIGHT * float(tool.get("radius", 0.005)) * 0.8
	out["contact"] = lip_mid
	out["normal"] = Vector3.UP
	out["tangent"] = Vector3.UP.cross(lip_mid - c).normalized()
	out["D"] = axis
	out["E"] = Vector3.RIGHT
	out["axis"] = axis
	# Chispas cortas: se quedan dentro de la caja (en la máquina real, la carcasa las recoge)
	out["spark_pose"] = { "center": c, "axis": Vector3.UP, "radius": (lip_mid - c).length(), "contact": lip_mid,
		"normal": Vector3.UP, "spin": 1.0, "kerf": 0.003 }
	out["spark_max_mm"] = 60.0
	return out
