## Afiladora 3D · máquinas de eje horizontal con muelas: esmeriladora de banco («banco», también la combinada con
## una piedra húmeda en un extremo) y afiladora húmeda lenta («humeda_lenta»: piedra grande en su bandeja de agua,
## rueda de cuero al otro lado y barra universal con la plantilla del cuchillo).
##
## Proporciones de productos reales, sin logotipos ni marcas: la de banco, como una de 150 mm (muelas de 150 × 16 mm,
## apoyo y protector a ≤ 2 mm, pantallas; manual de la Einhell TC-BG 150); la lenta, como una de 200–250 mm con la
## piedra que entra ~30 mm en el agua (manuales de la Einhell TC-WG 200 y del Tormek T-8). El resto de medidas
## (bancada, motor, carcasa, bandeja, barra) son de dibujo: ESTIMACIÓN.
##
## Marco: metros; +x a la derecha del operario, +y arriba, +z hacia el operario; la mesa en y = 0. Cada muela gira
## alrededor de +x: a velocidad positiva su frente baja (en la esmeriladora, la cara de trabajo va hacia abajo, como
## debe ser; en la lenta, la parte de arriba viene hacia el operario).
extends RefCounted

const Parts = preload("res://app/taller/sharpen3d/parts.gd")
const Tools = preload("res://app/taller/sharpen3d/tools.gd")
const WATER_SHADER = preload("res://app/taller/sharpen3d/water.gdshader")

## Contacto con cada muela: ángulo del punto de contacto sobre la horizontal delantera (grados), si el filo sale
## («trailing»: la muela pasa del lomo al filo) o entra contra ella («leading») y si se dibuja la barra universal.
## Esmeriladora: contacto justo encima del centro, sobre el apoyo, con el filo hacia abajo: las chispas salen hacia
## abajo, lejos de la hoja. Piedra lenta: arriba y algo detrás, contra el filo, con la plantilla en la barra delante.
## Cuero: siempre con el filo saliendo (la rueda de cuero se corta si va contra el filo). Decisiones de dibujo.
const CONTACT := {
	"izquierda": { "deg": 10.0, "mode": "trailing" },
	"derecha": { "deg": 10.0, "mode": "trailing" },
	"piedra": { "deg": 10.0, "mode": "trailing" },
	"piedra_lenta": { "deg": 100.0, "mode": "leading" },
	"cuero": { "deg": 30.0, "mode": "trailing" },
}
## Cuchilla de un solo bisel en la muela izquierda: contacto más arriba y contra el giro (ver pose()). Dibujo.
const SINGLE_SWITCH_DEG := 40.0
const GUARD_OPEN := [20.0, 125.0]  # sector abierto del protector (grados desde +y hacia +z): el frente de la muela
const REST_GAP := 0.002  # apoyo y protector a ≤ 2 mm de la muela (manual de la Einhell TC-BG 150)
const SLEEVE_Z := 0.06  # z de los casquillos de la barra universal (dibujo)


## Construye la máquina bajo `parent` a partir de la vista (set_machine). mobile: menos partículas.
static func build(parent: Node3D, view: Dictionary, mobile: bool) -> Dictionary:
	var kind := str(view.get("kind", "banco"))
	var slow := kind == "humeda_lenta"
	var root := Parts.node(parent, "Afiladora humeda" if slow else "Esmeriladora")
	var mats := {
		"paint": Parts.mat(Color("#34373D"), 0.35, 0.45),
		"paint_light": Parts.mat(Color("#4A4F57"), 0.3, 0.5),
		"steel": Parts.mat(Color("#C3C7CC"), 1.0, 0.28),
		"dark": Parts.mat(Color("#1B1C20"), 0.2, 0.6),
		"guard": Parts.mat(Color("#5E656E"), 0.7, 0.42, true),
		"rubber": Parts.mat(Color("#141417"), 0.0, 0.9),
		"accent": Parts.mat(Color("#5BE0C8"), 0.1, 0.45),
		"shield": Parts.glass(Color("#DDEBF5"), 0.22),
		"plastic": Parts.mat(Color("#2A2D33"), 0.0, 0.55, true),
		"brown": Parts.mat(Color("#6E4A2E"), 0.0, 0.7),
	}
	# Muelas de la vista, con su lado: izquierda / piedra a la izquierda, derecha / cuero a la derecha
	var wheels: Array = []
	var left: Dictionary = {}
	var right: Dictionary = {}
	for w in view.get("wheels", []):
		if not (w is Dictionary):
			continue
		var pos := str(w.get("position", ""))
		if (pos == "izquierda" or pos == "piedra") and left.is_empty():
			left = w
		elif (pos == "derecha" or pos == "cuero") and right.is_empty():
			right = w
	if left.is_empty() and right.is_empty():
		left = { "position": "piedra" if slow else "izquierda", "grit": "K36", "abrasive_id": "al2o3", "wet": slow }
		right = { "position": "cuero" if slow else "derecha", "grit": "K60", "abrasive_id": "al2o3", "honing": slow }
	var r_max := 0.0
	for w in [left, right]:
		if not w.is_empty():
			r_max = maxf(r_max, _diameter(w) * 0.0005)
	var has_stone := str(left.get("position", "")) == "piedra"
	var y_axis := r_max + (0.035 if has_stone else 0.06)
	var body_half := 0.1
	if slow:
		_slow_body(root, mats, y_axis)
	else:
		_bench_body(root, mats, y_axis)
	var machine_rpm := Parts.num(view, "rpm", 0.0)
	for side: float in [-1.0, 1.0]:
		var w: Dictionary = left if side < 0.0 else right
		if w.is_empty():
			continue
		var pos := str(w.get("position", ""))
		var r := _diameter(w) * 0.0005
		var width := _width(w) * 0.001
		# En la combinada, la piedra con su bandeja va más afuera para que la bandeja no pise la base
		var gap := 0.06 if pos == "piedra" and not slow else 0.03
		var cx := side * (body_half + gap + width * 0.5)
		var rig := _wheel(root, mats, w, Vector3(cx, y_axis, 0.0), r, width, pos, slow, mobile)
		rig["rpm"] = Parts.num(w, "rpm", machine_rpm)
		rig["handle_side"] = side
		var ckey := "piedra_lenta" if pos == "piedra" and slow else pos
		var c: Dictionary = CONTACT.get(ckey, CONTACT["derecha"])
		rig["contact_deg"] = float(c["deg"])
		rig["mode"] = str(c["mode"])
		rig["selected"] = bool(w.get("selected", false))
		if not slow and pos != "cuero":
			_guard(root, mats, rig)
		if not slow:
			rig["rest"] = _rest(root, mats, rig)
		wheels.append(rig)
	# Cámara: en la lenta, más alta y más lejos (la hoja va encima de la piedra, con la plantilla y la barra)
	var general := { "target": Vector3(0.0, y_axis * 0.8, 0.0), "yaw": 24.0, "pitch": 20.0, "distance": 0.62 + r_max * 1.6 }
	if slow:
		general = { "target": Vector3(-0.05, y_axis + 0.06, 0.04), "yaw": 38.0, "pitch": 42.0, "distance": 0.8 + r_max * 1.6 }
	var rig_m := {
		"kind": kind, "root": root, "wheels": wheels, "y_axis": y_axis, "slow": slow, "mats": mats,
		"cam": { "general": general, "filo": { "yaw": -38.0, "pitch": 14.0, "distance": 0.13 } },
	}
	if slow:
		rig_m["usb"] = _usb(root, mats, y_axis)
	elif bool(view.get("quench_pot", false)):
		_quench_pot(root, mats)
	return rig_m


## Baño de enfriamiento (quench_pot de la vista): cubeta con agua en el frente de la base. Medidas de dibujo.
static func _quench_pot(root: Node3D, mats: Dictionary) -> void:
	var node := Parts.node(root, "BanoDeEnfriamiento", Transform3D(Basis.IDENTITY, Vector3(-0.055, 0.036, 0.066)))
	var wall := PackedVector2Array([Vector2(0.0, 0.0165), Vector2(0.026, 0.0165), Vector2(0.026, 0.0155), Vector2(0.0, 0.0155)])
	Parts.mesh_node(node, Parts.revolve(wall, 32), mats["steel"], Transform3D(Parts.basis_x(Vector3.UP), Vector3.ZERO), "Cubeta")
	Parts.mesh_node(node, Parts.x_cylinder(0.0, 0.002, 0.0165, 32), mats["steel"], Transform3D(Parts.basis_x(Vector3.UP), Vector3.ZERO))
	var water := Parts.glass(Color("#8FB7C8"), 0.6, 0.05)
	Parts.mesh_node(node, Parts.x_cylinder(0.0, 0.02, 0.0153, 32), water, Transform3D(Parts.basis_x(Vector3.UP), Vector3.ZERO), "Agua")


static func _diameter(w: Dictionary) -> float:
	var pos := str(w.get("position", "derecha"))
	return Parts.num(w, "d_mm", float(Parts.DEFAULT_DIAMETER_MM.get(pos, 150.0)))


## Ancho de la muela (mm). width_mm puede llegar null (el fabricante no lo da): entonces, el de dibujo de su
## posición (Parts.DEFAULT_WIDTH_MM, estimación).
static func _width(w: Dictionary) -> float:
	var pos := str(w.get("position", "derecha"))
	return Parts.num(w, "width_mm", float(Parts.DEFAULT_WIDTH_MM.get(pos, 16.0)))


## Bancada y motor de la esmeriladora: base con patas de goma, pedestal y motor cilíndrico con aletas.
static func _bench_body(root: Node3D, mats: Dictionary, y_axis: float) -> void:
	Parts.box(root, Vector3(-0.125, 0.006, -0.085), Vector3(0.125, 0.036, 0.085), mats["paint"], 0.008, "Base")
	for fx: float in [-0.105, 0.105]:
		for fz: float in [-0.065, 0.065]:
			Parts.rod(root, Vector3(fx, 0.0, fz), Vector3(fx, 0.007, fz), 0.011, mats["rubber"], 16)
	Parts.box(root, Vector3(-0.07, 0.03, -0.05), Vector3(0.07, y_axis - 0.03, 0.05), mats["paint"], 0.01, "Pedestal")
	var motor := PackedVector2Array([Vector2(-0.1, 0.0), Vector2(-0.1, 0.05), Vector2(-0.096, 0.058),
		Vector2(0.096, 0.058), Vector2(0.1, 0.05), Vector2(0.1, 0.0)])
	Parts.mesh_node(root, Parts.revolve(motor, 48), mats["paint"], Transform3D(Basis.IDENTITY, Vector3(0.0, y_axis, 0.0)), "Motor")
	for k in 5:
		var x := -0.06 + 0.03 * k
		Parts.mesh_node(root, Parts.x_cylinder(x - 0.003, x + 0.003, 0.061, 48), mats["paint_light"],
			Transform3D(Basis.IDENTITY, Vector3(0.0, y_axis, 0.0)))
	Parts.mesh_node(root, Parts.x_cylinder(-0.19, 0.19, 0.0063, 16), mats["steel"], Transform3D(Basis.IDENTITY, Vector3(0.0, y_axis, 0.0)), "Eje")
	# Interruptor en el frente de la base
	Parts.box(root, Vector3(-0.012, 0.012, 0.085), Vector3(0.012, 0.03, 0.093), mats["dark"], 0.002)
	Parts.box(root, Vector3(-0.007, 0.016, 0.092), Vector3(0.007, 0.026, 0.097), mats["accent"], 0.0015, "Interruptor")


## Carcasa de la afiladora lenta: caja con la tapa algo más clara y el eje que sale por los dos lados.
static func _slow_body(root: Node3D, mats: Dictionary, y_axis: float) -> void:
	var top := y_axis + 0.03
	Parts.box(root, Vector3(-0.1, 0.004, -0.09), Vector3(0.1, top, 0.09), mats["paint"], 0.02, "Carcasa")
	Parts.box(root, Vector3(-0.094, top - 0.004, -0.084), Vector3(0.094, top + 0.004, 0.084), mats["paint_light"], 0.006, "Tapa")
	for fx: float in [-0.08, 0.08]:
		for fz: float in [-0.07, 0.07]:
			Parts.rod(root, Vector3(fx, 0.0, fz), Vector3(fx, 0.005, fz), 0.012, mats["rubber"], 16)
	Parts.mesh_node(root, Parts.x_cylinder(-0.2, 0.2, 0.006, 16), mats["steel"], Transform3D(Basis.IDENTITY, Vector3(0.0, y_axis, 0.0)), "Eje")
	Parts.box(root, Vector3(0.03, top - 0.03, 0.089), Vector3(0.06, top - 0.012, 0.096), mats["accent"], 0.002, "Interruptor")


## Una muela con su pivote de giro (el nodo que se gira alrededor de su x local), sus bridas y, si es una piedra
## húmeda, su bandeja con agua, goteo y salpicaduras.
static func _wheel(root: Node3D, mats: Dictionary, w: Dictionary, center: Vector3, r: float, width: float, pos: String,
		_slow: bool, mobile: bool) -> Dictionary:
	var pivot := Parts.node(root, "Muela_" + pos, Transform3D(Basis.IDENTITY, center))
	var hw := width * 0.5
	var bore := 0.016 if r > 0.09 else 0.0127
	var kind := 2 if pos == "cuero" or bool(w.get("honing", false)) else (1 if pos == "piedra" else 0)
	var mat := Parts.wheel_material(w, kind, r, width, bore * 0.5)
	var prof := PackedVector2Array([Vector2(-hw, bore * 0.5), Vector2(-hw, r), Vector2(hw, r), Vector2(hw, bore * 0.5),
		Vector2(-hw, bore * 0.5)])
	var surf := Parts.mesh_node(pivot, Parts.revolve(prof, 96), mat, Transform3D.IDENTITY, "Superficie")
	var fl := minf(0.03, r * 0.4)
	for s: float in [-1.0, 1.0]:
		var x0 := s * hw
		var x1 := s * (hw + 0.003)
		Parts.mesh_node(pivot, Parts.x_cylinder(minf(x0, x1), maxf(x0, x1), fl, 32), mats["steel"], Transform3D.IDENTITY)
	Parts.mesh_node(pivot, Parts.x_cylinder(-hw - 0.009, hw + 0.009, 0.011, 6), mats["steel"], Transform3D.IDENTITY, "Tuerca")
	var rig := {
		"position": pos, "view": w, "pivot": pivot, "mesh": surf, "mat": mat, "radius": r, "width": width,
		"center": center, "axis": Vector3.RIGHT, "spin": 1.0, "angle": 0.0, "grind": "periferia",
		"wet": bool(w.get("wet", false)) or pos == "piedra", "honing": kind == 2, "shader": "muela",
	}
	if pos == "piedra":
		rig["water"] = _trough(root, mats, center, r, width, mobile)
	return rig


## Protector de la muela: canal en U que cubre de 125° a 380° (deja el frente abierto), deflector de chispas arriba y
## pantalla transparente regulable.
static func _guard(root: Node3D, mats: Dictionary, rig: Dictionary) -> void:
	var c: Vector3 = rig["center"]
	var r: float = rig["radius"]
	var hw: float = rig["width"] * 0.5 + 0.006
	var rg := r + 0.008
	var prof := PackedVector2Array([Vector2(-hw, 0.03), Vector2(-hw, rg), Vector2(hw, rg), Vector2(hw, 0.03)])
	var open_to: float = GUARD_OPEN[1]
	var arc := deg_to_rad(360.0 + float(GUARD_OPEN[0]) - open_to)
	Parts.mesh_node(root, Parts.revolve(prof, 64, false, arc), mats["guard"],
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(open_to)), c), "Protector")
	# Deflector de chispas: chapa en el borde de arriba de la abertura, a 2 mm de la muela
	var a0 := deg_to_rad(float(GUARD_OPEN[0]))
	var edge_dir := Vector3(0.0, cos(a0), sin(a0))
	var tang := Vector3(0.0, -sin(a0), cos(a0))
	var p := c + edge_dir * (r + REST_GAP + 0.0015)
	var defl := Parts.box(root, Vector3(-hw, -0.0015, -0.012), Vector3(hw, 0.0015, 0.012), mats["steel"], 0.0008, "Deflector")
	defl.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(GUARD_OPEN[0]))), p + tang * 0.012)
	# Pantalla de policarbonato, por encima y delante de la abertura
	var sp := c + Vector3(0.0, r * 0.95, r * 0.72)
	var shield := Parts.box(root, Vector3(-0.045, -0.0015, -0.03), Vector3(0.045, 0.0015, 0.03), mats["shield"], 0.004, "Pantalla")
	shield.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(60.0)), sp)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Parts.rod(root, c + Vector3(0.0, rg * 0.9, -rg * 0.25), sp - Vector3(0.0, 0.0, 0.03), 0.003, mats["steel"], 8)


## Apoyo de la herramienta: pletina delante de la muela, 12 mm por debajo del eje y a 2 mm de ella, con su escuadra.
static func _rest(root: Node3D, mats: Dictionary, rig: Dictionary) -> Node3D:
	var c: Vector3 = rig["center"]
	var r: float = rig["radius"]
	var y_top := c.y - 0.012
	var z_back := sqrt(maxf(r * r - 0.012 * 0.012, 0.0)) + REST_GAP
	var node := Parts.node(root, "Apoyo_" + str(rig["position"]))
	Parts.box(node, Vector3(c.x - 0.026, y_top - 0.004, z_back), Vector3(c.x + 0.026, y_top, z_back + 0.032), mats["steel"], 0.001)
	Parts.box(node, Vector3(c.x - 0.006, 0.036, z_back + 0.004), Vector3(c.x + 0.006, y_top - 0.004, z_back + 0.01), mats["paint"], 0.002)
	return node


## Bandeja de agua bajo la piedra (abierta por arriba): agua a 30 mm por encima del borde de abajo de la piedra, con
## las ondas del shader, el goteo que cae de la piedra y del filo y las salpicaduras donde la piedra entra en el agua.
static func _trough(root: Node3D, mats: Dictionary, c: Vector3, r: float, width: float, mobile: bool) -> Dictionary:
	var hx := width * 0.5 + 0.016
	var hz := r * 0.78
	var y0 := 0.006
	var y_water := c.y - r + 0.03
	var y_rim := y_water + 0.018
	var node := Parts.node(root, "Bandeja")
	var plastic: Material = mats["plastic"]
	Parts.box(node, Vector3(c.x - hx, y0, -hz), Vector3(c.x + hx, y0 + 0.004, hz), plastic, 0.0)
	for s: float in [-1.0, 1.0]:
		Parts.box(node, Vector3(c.x - hx, y0, s * hz - 0.002), Vector3(c.x + hx, y_rim, s * hz + 0.002), plastic, 0.0)
		Parts.box(node, Vector3(c.x + s * hx - 0.002, y0, -hz), Vector3(c.x + s * hx + 0.002, y_rim, hz), plastic, 0.0)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2(hx * 2.0 - 0.004, hz * 2.0 - 0.004)
	var surface := Parts.mesh_node(node, plane, water_mat, Transform3D(Basis.IDENTITY, Vector3(c.x, y_water, 0.0)), "Agua")
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop_mat := Parts.glass(Color("#CFE4EE"), 0.55, 0.05)
	var drop := SphereMesh.new()
	drop.radius = 0.0011
	drop.height = 0.0022
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = drop_mat
	var drips := _particles(node, "Goteo", drop, 28 if not mobile else 12, 0.45, Vector3(0.0, -1.0, 0.25), 20.0, 0.1, 0.35)
	var splash := _particles(node, "Salpicaduras", drop, 18 if not mobile else 8, 0.25, Vector3(0.0, 1.0, 0.4), 55.0, 0.25, 0.55)
	splash.position = Vector3(c.x, y_water + 0.002, sqrt(maxf(r * r - (c.y - y_water) * (c.y - y_water), 0.0)))
	return { "node": node, "surface": surface, "mat": water_mat, "drips": drips, "splash": splash, "y": y_water }


static func _particles(parent: Node3D, node_name: String, mesh: Mesh, amount: int, life: float, dir: Vector3, spread: float,
		v_min: float, v_max: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = node_name
	gp.amount = amount
	gp.lifetime = life
	gp.local_coords = false
	gp.use_fixed_seed = true
	gp.seed = 20260926
	gp.draw_pass_1 = mesh
	gp.emitting = false
	gp.visibility_aabb = AABB(Vector3(-0.4, -0.4, -0.4), Vector3(0.8, 0.8, 0.8))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.012, 0.002, 0.004)
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	gp.process_material = pm
	parent.add_child(gp)
	return gp


## Barra universal de la afiladora lenta: dos casquillos en la tapa, dos patas que suben y bajan (se estiran con la
## escala) y la barra encima de la piedra; la plantilla del cuchillo (mordaza en el lomo, brazo y manguito en la
## barra). update() la coloca según la pose del cuchillo.
static func _usb(root: Node3D, mats: Dictionary, y_axis: float) -> Dictionary:
	var node := Parts.node(root, "BarraUniversal")
	var top := y_axis + 0.034
	var legs: Array = []
	var unit := Parts.unit_rod_mesh(0.006, 16)
	for x: float in [-0.085, -0.035]:
		Parts.mesh_node(node, Parts.x_cylinder(-0.012, 0.012, 0.011, 20), mats["dark"],
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, top + 0.012, SLEEVE_Z)))
		var leg := Parts.mesh_node(node, unit, mats["steel"], Transform3D.IDENTITY, "Pata")
		legs.append(leg)
	var bar := Parts.mesh_node(node, Parts.x_cylinder(-0.25, -0.02, 0.006, 20), mats["steel"], Transform3D.IDENTITY, "Barra")
	var jig := Parts.node(node, "Plantilla")
	var clamp_mat: Material = mats["dark"]
	var clamp := Parts.box(jig, Vector3(-0.02, -0.004, -0.009), Vector3(0.02, 0.012, 0.009), clamp_mat, 0.002, "Mordaza")
	var arm := Parts.mesh_node(jig, BoxMesh.new(), mats["steel"], Transform3D.IDENTITY, "Brazo")
	var sleeve := Parts.mesh_node(jig, Parts.x_cylinder(-0.014, 0.014, 0.0095, 20), mats["paint_light"], Transform3D.IDENTITY, "Manguito")
	return { "node": node, "legs": legs, "bar": bar, "jig": jig, "clamp": clamp, "arm": arm, "sleeve": sleeve, "top": top + 0.024 }


## Muela con la que se trabaja: la de st.wheel (su posición), la marcada «selected» en la vista o la primera.
static func selected_wheel(rig: Dictionary, st: Dictionary) -> Dictionary:
	var wheels: Array = rig["wheels"]
	if wheels.is_empty():
		return {}
	var want := str(st.get("wheel", ""))
	for w in wheels:
		if want != "" and str(w["position"]) == want:
			return w
	if want == "":
		for w in wheels:
			if bool(w["selected"]):
				return w
	return wheels[0]


## Pose de la herramienta contra la periferia de la muela. Hojas: el filo paralelo al eje de la muela y la hoja a
## `angle_deg` por lado de la tangente en el contacto (la cara del bisel, tangente a la muela), deslizada a lo largo
## del eje para que toque en contact_pos y girada en su plano para que la panza también apoye. Broca: a pulso, con
## el eje a la mitad del ángulo de punta de la línea de la muela y el labio horizontal (TC 9-524). Las fresas no se
## afilan a pulso (TC 9-524, cap. 5): quedan en la mesa. retract (m): lo que se separa de la muela cuando no toca.
## Devuelve { tool_xf, contact, normal, tangent, D, wheel, spark_pose, … } y, para la vista de sección, apex (vértice
## del ángulo), edge_pt (filo en la línea media de la hoja), arc_from (la muela: su tangente o su línea), arc_to (la
## herramienta: su línea media o su eje), view_dir (hacia la cámara de la sección) y sec_up (arriba en la sección).
static func pose(rig: Dictionary, tool: Dictionary, st: Dictionary, retract: float) -> Dictionary:
	var wheel := selected_wheel(rig, st)
	if wheel.is_empty():
		return {}
	var c: Vector3 = wheel["center"]
	var r: float = wheel["radius"]
	var spin: float = wheel["spin"]
	var hs: float = wheel["handle_side"]
	var gap := 0.00008
	var out := { "wheel": wheel, "blade": bool(tool.get("blade", false)) }
	if bool(tool.get("blade", false)):
		var mode := str(wheel["mode"])
		var phi := deg_to_rad(float(wheel["contact_deg"]))
		var beta := deg_to_rad(clampf(float(st.get("angle_deg", 15.0)), 1.0, 60.0))
		var e_dir := Vector3(-hs, 0.0, 0.0)  # del talón a la punta: el mango hacia fuera de la máquina
		var fr := _blade_frame(phi, mode, spin, beta)
		# Un solo bisel (cortacésped): la cara A, la del bisel, tiene que dar a la muela. Si con el mango hacia fuera
		# no da (muela izquierda), se trabaja contra el giro y más arriba en la muela, con la hoja hacia delante y
		# por encima del apoyo (dibujo)
		if bool(tool.get("single_bevel", false)) and e_dir.cross(fr[2]).dot(-(fr[0] as Vector3)) < 0.0:
			mode = "leading" if mode == "trailing" else "trailing"
			phi = deg_to_rad(SINGLE_SWITCH_DEG)
			fr = _blade_frame(phi, mode, spin, beta)
		var rv: Vector3 = fr[0]
		var tsel: Vector3 = fr[1]
		var d_dir: Vector3 = fr[2]
		var n_dir := e_dir.cross(d_dir)
		var u := clampf(float(st.get("contact_pos", 0.5)), 0.0, 1.0)
		var ea: Array = Tools.edge_at(tool, u)
		var vz := Tools.vertex_z(tool, u)
		var p_local: Vector3 = (ea[0] as Vector3) + Vector3(0.0, 0.0, vz)
		var basis := Basis(e_dir, d_dir, n_dir) * Basis(Vector3.BACK, -atan(float(ea[1])))
		var p := c + rv * (r + gap + retract)
		out["tool_xf"] = Transform3D(basis, p - basis * p_local)
		out["contact"] = c + rv * r
		out["normal"] = rv
		out["tangent"] = Vector3.RIGHT.cross(rv) * spin
		out["D"] = d_dir
		out["E"] = e_dir
		out["beta"] = beta
		out["contact_u"] = u
		out["apex"] = p
		out["edge_pt"] = p - n_dir * vz
		out["arc_from"] = tsel
		out["arc_to"] = d_dir
		out["view_dir"] = e_dir
		out["sec_up"] = d_dir
		var x_jig := 0.35 * float(tool["length"])
		var yt_j := Tools.edge_at(tool, 0.35)
		out["spine_local"] = Vector3(x_jig, float(yt_j[0].y) + Tools.height_at(tool, 0.35), 0.0)
		out["spark_pose"] = { "center": c, "axis": Vector3.RIGHT, "radius": r, "contact": c + rv * r, "normal": rv,
			"spin": spin, "kerf": minf(float(wheel["width"]), 0.02) }
		return out
	if str(tool.get("kind", "")) != "broca":
		out["idle"] = true
		return out
	# Broca a pulso: contacto en el frente de la muela, a la altura del eje
	var half := deg_to_rad(clampf(float(st.get("angle_deg", 118.0)), 80.0, 150.0) * 0.5)
	var u_ax := Vector3(cos(half) * hs, 0.0, sin(half))  # del ápice al mango
	var ex := Vector3(sin(half) * hs, 0.0, -cos(half))
	var ez := ex.cross(u_ax)
	var psi := (clampf(float(st.get("contact_pos", 0.5)), 0.0, 1.0) - 0.5) * deg_to_rad(30.0)
	var basis2 := Basis(ex, u_ax, ez) * Basis(Vector3.UP, float(tool.get("lip_theta", 0.0)) + psi)
	var lip := float(tool.get("radius", 0.005)) / sin(half)
	var p2 := c + Vector3(0.0, 0.0, r + gap + retract) - Vector3(hs, 0.0, 0.0) * (lip * 0.5)
	out["tool_xf"] = Transform3D(basis2, p2)
	out["contact"] = c + Vector3(0.0, 0.0, r)
	out["normal"] = Vector3.BACK
	out["tangent"] = Vector3.RIGHT.cross(Vector3.BACK) * spin
	out["D"] = u_ax
	out["E"] = Vector3(hs, 0.0, 0.0)
	out["beta"] = half
	# Sección: la punta vista desde arriba, con el labio sobre la línea de la muela y el eje a la mitad del ángulo
	out["apex"] = p2
	out["arc_from"] = Vector3(hs, 0.0, 0.0)
	out["arc_to"] = u_ax
	out["view_dir"] = Vector3.UP
	out["sec_up"] = u_ax
	out["spark_pose"] = { "center": c, "axis": Vector3.RIGHT, "radius": r, "contact": c + Vector3(0.0, 0.0, r),
		"normal": Vector3.BACK, "spin": spin, "kerf": minf(float(wheel["width"]), 0.012) }
	return out


## Direcciones de una hoja contra la periferia en el ángulo phi del contacto: [rv (radial), tangente del lado del
## lomo (la cara del bisel en el vértice), D (del filo al lomo, a beta de la tangente)].
static func _blade_frame(phi: float, mode: String, spin: float, beta: float) -> Array:
	var rv := Vector3(0.0, sin(phi), cos(phi))
	var tg := Vector3.RIGHT.cross(rv) * spin
	var tsel := -tg if mode == "trailing" else tg
	return [rv, tsel, (tsel * cos(beta) + rv * sin(beta)).normalized()]


## Lo que se mueve con la herramienta: la barra universal y la plantilla (solo con la piedra lenta y una hoja).
## pose: { tool_xf (Transform3D de la herramienta), D (dirección del filo al lomo), spine_local (punto del lomo donde
## muerde la plantilla, en el marco de la herramienta), wheel (rig de la muela), blade (bool) }.
static func update(rig: Dictionary, pose: Dictionary) -> void:
	if not rig.has("usb"):
		return
	var usb: Dictionary = rig["usb"]
	var wheel: Dictionary = pose.get("wheel", {})
	var on: bool = bool(pose.get("blade", false)) and str(wheel.get("position", "")) == "piedra"
	(usb["node"] as Node3D).visible = on
	if not on:
		return
	var xf: Transform3D = pose["tool_xf"]
	var d_dir: Vector3 = pose["D"]
	var pj: Vector3 = xf * (pose["spine_local"] as Vector3)
	# La barra está en el plano de la hoja, donde la recta del lomo por la plantilla corta el plano de los casquillos
	var s := (SLEEVE_Z - pj.z) / d_dir.z if absf(d_dir.z) > 1e-4 else 0.05
	s = clampf(s, 0.01, 0.2)
	var bar_p := pj + d_dir * s
	var y_bar := bar_p.y
	(usb["bar"] as Node3D).position = Vector3(0.0, y_bar, SLEEVE_Z)
	var top: float = usb["top"]
	var legs: Array = usb["legs"]
	var xs := [-0.085, -0.035]
	for i in legs.size():
		var h := maxf(y_bar - top, 0.001)
		(legs[i] as Node3D).transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(xs[i], top + h * 0.5, SLEEVE_Z))
	# Plantilla: mordaza en el lomo (con la base de la hoja), brazo hasta la barra y manguito en ella
	var jig: Node3D = usb["jig"]
	jig.transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var clamp: Node3D = usb["clamp"]
	clamp.transform = Transform3D(xf.basis.orthonormalized(), pj)
	var arm: MeshInstance3D = usb["arm"]
	var mid := (pj + Vector3(pj.x, y_bar, SLEEVE_Z)) * 0.5
	var along := Vector3(pj.x, y_bar, SLEEVE_Z) - pj
	var len := maxf(along.length(), 0.001)
	arm.transform = Transform3D(Parts.basis_y(along).scaled_local(Vector3(0.012, len, 0.006)), mid)
	(usb["sleeve"] as Node3D).position = Vector3(pj.x, y_bar, SLEEVE_Z)
