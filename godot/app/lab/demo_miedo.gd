## Hoja del miedo del agarre en curva (unidad 4u, petición de Eric del 18-10): el mismo animal de la cetrería en el coche, cuatro
## veces, con el miedo de CarCurveGrip.fear a 0, 0,4, 0,8 y 1 (la curva empuja hacia la derecha), en la pose de agarre en curva
## de hd3d.gd, sobre un techo plano y visto desde atrás y un poco a la derecha, como la cámara de persecución. Solo dibujo:
## sirve para revisar las poses de cada especie.
## Captura: node godot/tools/godot.mjs capture res://app/lab/demo_miedo.tscn --frames=8 --out=<carpeta> -- --solo=tigre
## (tigre, oso, velociraptor, velociraptor_pelicula, aguila, buho, lechuza…; --t=<s> fija el instante de la vida y el temblor;
## --lado: de lado, para ver lo que se agacha).
extends Node3D

const HdAnimal = preload("res://app/lab/animals/hd3d.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

const FEARS := [0.0, 0.4, 0.8, 1.0]
const POSTURE := { "tigre": "tumbado", "oso": "de_pie", "velociraptor": "tumbado", "velociraptor_pelicula": "tumbado" }
## Separación entre los cuatro (m, por cada metro de largo del animal) y el color del techo. Dibujo.
const GAP_K := 1.1
const ROOF := Color("#7A1F2B")

var _rigs: Array = []
var _id := "tigre"
var _t := 1.3
var _side_view := false
var _size := Vector3.ONE
## Solo uno de los cuatro (--uno=K, 0-3), de cerca; -1 los cuatro.
var _one := -1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--solo="):
			_id = a.substr(7)
		elif a.begins_with("--t="):
			_t = float(a.substr(4))
		elif a.begins_with("--uno="):
			_one = int(a.substr(6))
		elif a == "--lado":
			_side_view = true
	var claw: Dictionary = Catalog.find_by_id(Catalog.CLAWS, _id)
	var st := MCS.new(claw, Catalog.find_by_id(Catalog.TARGETS, "coche"))
	var d: Dictionary = st.draw_size()
	_size = Vector3(float(d.heightM), float(d.lengthM), float(d.spanM))
	var post: String = POSTURE.get(_id, "plegadas")
	var cache := {}
	var gap := maxf(_size.y, _size.x) * GAP_K
	for i in FEARS.size():
		if _one >= 0 and i != _one:
			_rigs.append(null)
			continue
		var rig: RefCounted = HdAnimal.build(_id, post, _size, { "quality": "escritorio", "cache": cache, "variant": String(d.get("variant", "")) })
		var root: Node3D = rig.get("root")
		add_child(root)
		root.position = Vector3((float(i) - 1.5) * gap * 1.4, 0.0, 0.0) if _side_view else Vector3(0.0, 0.0, (float(i) - 1.5) * gap)
		if _one >= 0:
			root.position = Vector3.ZERO
		_rigs.append(rig)
		var lab := Label3D.new()
		lab.font = FONT
		lab.font_size = 48
		lab.pixel_size = 0.0035 * maxf(_size.y, 0.6)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.text = "miedo %s" % ("0" if FEARS[i] == 0.0 else String.num(FEARS[i], 1).replace(".", ","))
		lab.position = root.position + Vector3(0.0, _size.x * 1.5, 0.0)
		add_child(lab)
	_build_world(gap)


func _build_world(gap: float) -> void:
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(gap * 7.0, gap * 7.0)
	plane.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROOF
	mat.roughness = 0.35
	mat.metallic = 0.2
	plane.material_override = mat
	add_child(plane)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2A1D36")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#B9A6C9")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	var span := gap * (1.1 if _one >= 0 else 4.0)
	if _side_view:
		cam.position = Vector3(0.0, _size.x * 1.3, span * 1.55)
		cam.look_at(Vector3(0.0, _size.x * 0.45, 0.0), Vector3.UP)
	else:
		cam.position = Vector3(-span * (1.6 if _one >= 0 else 1.25), _size.x * (1.1 if _one >= 0 else 1.55), span * (0.5 if _one >= 0 else 0.0))
		cam.look_at(Vector3(0.0, _size.x * 0.45, 0.0), Vector3.UP)
	cam.current = true


func _process(_delta: float) -> void:
	for i in _rigs.size():
		var rig: RefCounted = _rigs[i]
		if rig == null:
			continue
		var p := {
			"t": _t + float(i) * 0.37, "live": true, "alpha": 1.0, "claws_out": 1.0, "claw_len": 1.0, "claw_gone": false,
			"claw_bend": 0.0, "bristle": 0.0, "scared": 0.0, "wind_local_ms": 0.0, "flail": 0.0, "lean": 0.0, "wing_open": 0.0,
			"curve_on": true, "curve_fear": float(FEARS[i]), "curve_regrip": 0.0,
		}
		var root: Node3D = rig.get("root")
		var keep := root.position
		root.position = Vector3.ZERO
		root.rotation = Vector3.ZERO
		rig.call("pose", p)
		root.position = keep + Vector3(0.0, root.position.y, 0.0)
		rig.call("set_claws", true, "none", Color.WHITE)
