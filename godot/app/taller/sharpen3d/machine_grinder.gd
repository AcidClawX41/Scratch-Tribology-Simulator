## Afiladora 3D · amoladora angular con disco de láminas (o de desbaste) y la herramienta sujeta en un tornillo de
## banco: hacha, cuchilla de cortacésped o cuchillo con el filo hacia arriba. Aquí se mueve la amoladora, no la
## herramienta: la cara del disco apoya en el bisel con su zona exterior (el disco de láminas es un cono de ≈5°; se
## inclina 3° más para que no toque con el centro) y recorre el filo con contact_pos.
##
## La amoladora y los discos son los de la radial (app/taller/radial3d/grinder_builder.gd y disco.gdshader, que se
## reutilizan sin tocarlos): una de 125 mm típica. El tornillo de banco es de dibujo (ESTIMACIÓN).
extends RefCounted

const Parts = preload("res://app/taller/sharpen3d/parts.gd")
const Tools = preload("res://app/taller/sharpen3d/tools.gd")
const GB = preload("res://app/taller/radial3d/grinder_builder.gd")
const Looks = preload("res://app/taller/radial3d/looks.gd")
const DISC_SHADER = preload("res://app/taller/radial3d/disco.gdshader")

const VISE_X := 0.16  # centro del tornillo de banco (m)
const JAW_Y := 0.06  # altura a la que muerden las mordazas
const TILT_EXTRA_DEG := 3.0
const CONTACT_R := 0.75  # radio relativo de la zona del disco que apoya
const DESBASTE_MM := 6.0  # espesor de dibujo del disco de desbaste si la vista no lo trae


static func build(parent: Node3D, view: Dictionary, _mobile: bool) -> Dictionary:
	var root := Parts.node(parent, "Amoladora")
	var steel := Parts.mat(Color("#6C737C"), 0.6, 0.45)
	var dark := Parts.mat(Color("#2E3238"), 0.4, 0.5)
	var chrome := Parts.mat(Color("#C9CED4"), 1.0, 0.25)
	# Tornillo de banco: base, cuerpo, mordaza fija, mordaza móvil y husillo con su palanca
	var vise := Parts.node(root, "Tornillo", Transform3D(Basis.IDENTITY, Vector3(VISE_X, 0.0, 0.0)))
	Parts.box(vise, Vector3(-0.07, 0.0, -0.06), Vector3(0.07, 0.02, 0.07), dark, 0.006)
	Parts.box(vise, Vector3(-0.055, 0.02, -0.055), Vector3(0.055, JAW_Y - 0.012, -0.02), steel, 0.006)
	var fixed := Parts.node(vise, "MordazaFija")
	Parts.box(fixed, Vector3(-0.055, JAW_Y - 0.03, -0.014), Vector3(0.055, JAW_Y + 0.016, 0.0), steel, 0.003)
	var moving := Parts.node(vise, "MordazaMovil")
	Parts.box(moving, Vector3(-0.055, JAW_Y - 0.03, 0.0), Vector3(0.055, JAW_Y + 0.016, 0.014), steel, 0.003)
	Parts.box(moving, Vector3(-0.03, 0.02, 0.014), Vector3(0.03, JAW_Y - 0.03, 0.05), steel, 0.004)
	Parts.rod(moving, Vector3(0.0, 0.035, 0.05), Vector3(0.0, 0.035, 0.1), 0.007, chrome, 12)
	Parts.rod(moving, Vector3(-0.05, 0.035, 0.1), Vector3(0.05, 0.035, 0.1), 0.004, chrome, 10)
	# Amoladora y disco (radial3d): se colocan en pose()
	var grinder := Parts.node(root, "Maquina")
	var w: Dictionary = {}
	for x in view.get("wheels", []):
		if x is Dictionary:
			w = x
			if bool(x.get("selected", false)):
				break
	var disc_id := _disc_id(w)
	var d_mm := Parts.num(w, "d_mm", 125.0)
	var r := d_mm / 2000.0
	# Disco de desbaste: plano, del espesor de la vista (width_mm; si llega null, 6 mm, el de la muela de desbaste
	# de 125 × 22 × 6 del manual de la TE-AG 125 CE). Los de la radial, con sus medidas (looks.gd).
	var width := Parts.num(w, "width_mm", DESBASTE_MM) / 1000.0 if disc_id == "desbaste" else float(Looks.disc(disc_id)["t_mm"]) / 1000.0
	var face_half := width * 0.5 if disc_id == "desbaste" else GB.disc_front(disc_id)
	GB.build_grinder(grinder, face_half, r)
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = DISC_SHADER
	_disc_look(disc_mat, "grueso_3mm" if disc_id == "desbaste" else disc_id, r)
	var disc_mesh := _flat_disc(r, width * 0.5) if disc_id == "desbaste" else GB.build_disc(disc_id, r)
	var disc := Parts.mesh_node(grinder, disc_mesh, disc_mat, Transform3D.IDENTITY, "Disco")
	var wheel := {
		"position": "disco", "view": w, "pivot": disc, "mesh": disc, "mat": disc_mat, "radius": r, "width": width,
		"center": Vector3.ZERO, "axis": Vector3.BACK, "spin": 1.0, "angle": 0.0, "grind": "cara",
		"rpm": Parts.num(w, "rpm", Parts.num(view, "rpm", 11000.0)), "wet": false, "honing": false,
		"shader": "disco", "disc_id": disc_id, "handle_side": 1.0, "selected": true, "face_half": face_half,
	}
	return {
		"kind": "amoladora", "root": root, "wheels": [wheel], "grinder": grinder, "vise": vise, "moving_jaw": moving,
		"fixed_jaw": fixed, "disc_id": disc_id,
		# Vista general centrada en el filo de la herramienta (cambia con cada herramienta); el detalle, desde el lado
		# contrario al cuerpo de la amoladora, a lo largo del filo, para ver la cara del disco contra el bisel
		"cam": {
			"general": { "target": Vector3(VISE_X - 0.14, 0.15, 0.0), "yaw": 28.0, "pitch": 22.0, "distance": 0.92,
				"follow": "edge_mid", "offset": Vector3(0.0, -0.02, 0.0) },
			"filo": { "yaw": 84.0, "pitch": 6.0, "distance": 0.26 },
		},
	}


## Disco que corresponde a la muela de la vista: el de láminas, uno de la radial por su id o, si no, uno de
## desbaste plano («desbaste», el otro de sharpening_machines.gd).
static func _disc_id(w: Dictionary) -> String:
	var id := str(w.get("disc_id", w.get("id", "laminas")))
	if id.contains("lamina"):
		return "laminas"
	if Looks.DISCS.has(id):
		return id
	return "desbaste"


## Disco plano de semiespesor h (m), con las partes de disco.gdshader (cara, canto, dorso, agujero).
static func _flat_disc(r: float, h: float) -> ArrayMesh:
	var prof := PackedVector2Array([Vector2(GB.BORE_M, h), Vector2(r, h), Vector2(r, -h), Vector2(GB.BORE_M, -h),
		Vector2(GB.BORE_M, h)])
	return GB.revolve(prof, 128, PackedFloat32Array([GB.PART_FACE, GB.PART_RIM, GB.PART_BACK, GB.PART_BORE]))


static func _disc_look(m: ShaderMaterial, disc_id: String, r: float) -> void:
	var look := Looks.disc(disc_id)
	var kinds := { "abrasivo": 0, "diamante": 1, "laminas": 2 }
	m.set_shader_parameter("kind", int(kinds.get(str(look["kind"]), 0)))
	m.set_shader_parameter("radius_mm", r * 1000.0)
	m.set_shader_parameter("bore_mm", GB.BORE_M * 1000.0)
	m.set_shader_parameter("label_mm", minf(36.0, r * 1000.0 - 12.0))
	m.set_shader_parameter("body", Color(str(look["body"])))
	m.set_shader_parameter("body_lo", Color(str(look["body_lo"])))
	m.set_shader_parameter("label_color", Color(str(look["label"])))
	m.set_shader_parameter("label_ink", Color(str(look["label_ink"])))
	m.set_shader_parameter("stripe", Looks.stripe_color(float(look["max_vs"])))
	m.set_shader_parameter("flaps", int(look.get("flaps", 72)))


## Altura de la cara del disco de láminas (m, en el marco de la amoladora) al radio rr: el cono de las láminas de
## grinder_builder.gd (de 9,2 mm a 30 mm del eje a 6,6 mm junto al borde). Los discos planos, su semiespesor.
static func face_z(wheel: Dictionary, rr: float) -> float:
	var r: float = wheel["radius"]
	if str(wheel["disc_id"]) == "laminas":
		return 0.0092 - (rr - 0.030) * (0.0092 - 0.0066) / maxf(r - 0.032, 0.001)
	return float(wheel["face_half"])


## Pose: la herramienta fija en el tornillo (filo arriba, la cara A hacia el operario) y la amoladora con el disco
## apoyado en su bisel, en contact_pos a lo largo del filo. Brocas y fresas no se afilan así: quedan en la mesa.
static func pose(rig: Dictionary, tool: Dictionary, st: Dictionary, retract: float) -> Dictionary:
	var wheel: Dictionary = rig["wheels"][0]
	var grinder: Node3D = rig["grinder"]
	var r: float = wheel["radius"]
	var out := { "wheel": wheel, "blade": bool(tool.get("blade", false)) }
	if not bool(tool.get("blade", false)):
		# Brocas y fresas no se afilan con la amoladora: queda apoyada en la mesa, con el disco boca abajo
		grinder.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.08, 0.0105, 0.22))
		out["idle"] = true
		return out
	# Herramienta en el tornillo: x local → −X, y local → −Y (filo arriba), z local → +Z (cara A al operario)
	var bt := Basis(Vector3.LEFT, Vector3.DOWN, Vector3.BACK)
	var clamp_l: Vector3 = tool.get("clamp_local", Vector3.ZERO)
	var tool_xf := Transform3D(bt, Vector3(VISE_X, JAW_Y, 0.0) - bt * clamp_l)
	out["tool_xf"] = tool_xf
	var half_t := float(tool.get("clamp_half", 0.01))
	(rig["fixed_jaw"] as Node3D).position = Vector3(0.0, 0.0, -half_t)
	(rig["moving_jaw"] as Node3D).position = Vector3(0.0, 0.0, half_t)
	# Punto de contacto: a media anchura del bisel de la cara A, en contact_pos a lo largo del filo
	var beta := deg_to_rad(clampf(float(st.get("angle_deg", 15.0)), 1.0, 60.0))
	var single := bool(tool.get("single_bevel", false))
	var u := clampf(float(st.get("contact_pos", 0.5)), 0.0, 1.0)
	var ea: Array = Tools.edge_at(tool, u)
	var p_edge: Vector3 = ea[0]
	var tb := tan(beta)
	var wb := bevel_width(tool, u, tb, single)
	var dc := wb * 0.5
	var hb: Vector2 = (tool["half"] as Callable).call(int(round(u * float((tool["xs"] as PackedFloat64Array).size() - 1))), dc)
	var zc := dc * tb - hb.x if single else dc * tb
	var p_local := p_edge + Vector3(0.0, dc, zc)
	var n_local := Vector3(0.0, -tb, 1.0).normalized()
	var toward_edge_local := Vector3(0.0, -1.0, -tb).normalized()
	var e1 := (bt * Vector3(1.0, float(ea[1]), 0.0)).normalized()
	var e3 := bt * n_local
	var e2 := bt * toward_edge_local
	var pc := tool_xf * p_local
	# Amoladora: z de la amoladora hacia la pieza (−e3), y hacia el filo (e2); inclinada para apoyar con el exterior
	var disc_id := str(rig["disc_id"])
	var b0 := Basis(-e1, e2, -e3)
	var cone := atan((0.0092 - 0.0066) / maxf(r - 0.032, 0.001)) if disc_id == "laminas" else 0.0
	var tilt := cone + deg_to_rad(TILT_EXTRA_DEG)
	var rc := CONTACT_R * r
	var pc_l := Vector3(0.0, -rc, face_z(wheel, rc))
	var p_in := Vector3(0.0, -0.3 * r, face_z(wheel, 0.3 * r))
	var basis := Basis(e1, tilt) * b0
	if (basis * (p_in - pc_l)).dot(e3) < 0.0:
		basis = Basis(e1, -tilt) * b0
	var origin := pc + e3 * (0.0002 + retract) - basis * pc_l
	grinder.transform = Transform3D(basis, origin)
	out["contact"] = pc
	out["normal"] = e3
	out["tangent"] = -e1
	out["D"] = -e2
	out["E"] = e1
	out["beta"] = beta
	out["contact_u"] = u
	out["disc_center"] = origin
	out["edge_mid"] = tool_xf * (Tools.edge_at(tool, 0.5)[0] as Vector3)
	# Sección (plano perpendicular al filo): el bisel de la cara A contra la cara del disco. Un solo bisel: el
	# vértice está en la cara B y el ángulo (el total) se mide desde ella
	var sl := float(ea[1])
	var xs := (bt * Vector3(1.0, sl, 0.0)).normalized()
	var ys := (bt * Vector3(-sl, 1.0, 0.0)).normalized()
	var zs := xs.cross(ys)
	out["edge_pt"] = tool_xf * p_edge
	out["apex"] = tool_xf * (p_edge + Vector3(0.0, 0.0, Tools.vertex_z(tool, u)))
	out["arc_from"] = (ys * cos(beta) + zs * sin(beta)).normalized()
	out["arc_to"] = ys
	out["view_dir"] = xs
	out["sec_up"] = ys
	out["disc_normal"] = basis * Vector3.FORWARD  # de la cara del disco hacia dentro del disco
	out["spark_pose"] = { "center": origin, "axis": basis * Vector3.BACK, "radius": rc, "contact": pc, "normal": e3,
		"spin": 1.0, "kerf": 0.004 }
	return out


## Anchura del bisel (m) de la hoja en la fracción u con tan(β) = tb: donde la cara del bisel (plana) llega al cuerpo.
static func bevel_width(tool: Dictionary, u: float, tb: float, single: bool) -> float:
	var half: Callable = tool["half"]
	var i := int(round(u * float((tool["xs"] as PackedFloat64Array).size() - 1)))
	var d := 0.0
	var step := 0.0002
	for k in 400:
		var hb: Vector2 = half.call(i, d)
		var need := 2.0 * hb.x if single else hb.x
		if d * tb >= need:
			return d
		d += step
	return d
