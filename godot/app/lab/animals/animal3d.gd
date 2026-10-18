## Un animal del coche en marcha en el mundo 3D (car3d/car_scene.gd), modelado en 3D de verdad (unidad 4l).
##
## Técnica: mallas hechas en código (loft.gd: cilindros generalizados con las secciones de la anatomía, normales suaves,
## casquetes en las uniones; las garras, tubos curvos con s, la vuelta y el radio en mm, de ClawGeo.model_claw, para que
## las vista el material de la biblioteca sin deformarlas), colgadas de un esqueleto de nodos (rig3d.gd: por qué
## nodos y no Skeleton3D). Cada especie describe su cuerpo en centímetros (cassowary3d.gd, …); aquí se monta, se escala
## a su tamaño y se anima.
##   - Materiales físicos (mats3d.gd y los sombreadores animal_*.gdshader): plumas, pelo con capas en el contorno,
##     escamas, piel desnuda, queratina brillante, ojos con reflejo y tarjetas de plumas. Las garras, con la biblioteca de
##     materiales de las garras (ClawMaterial, unidad 5e): la queratina con el color de cada especie
##     (ClawOptics.KERATIN_COLORS) o el material reforjado con su color, su brillo y su luz reales; el mismo material que
##     en la cetrería y en la galería (cada animal lleva su copia, por el desvanecido; el largo de cada garra va en su
##     malla).
##   - Caché: el modelo (mallas, texturas, materiales descritos) se construye una vez por especie, sexo, variante y
##     calidad y se guarda en opts.cache; el tamaño solo cambia la escala de un nodo y la postura, los giros de reposo.
##   - Cada fotograma (pose): solo se giran o escalan nodos y se pasan el viento, el tiempo y el desvanecido a los
##     materiales. Nada se crea.
##   - Tamaño: el del estado (alto, largo y envergadura de MovingCar.BODIES). La caja de referencia (el cuerpo en su
##     postura de referencia: de pie, alas plegadas) cabe en alto × largo tocando uno de los dos; las demás posturas son
##     el mismo animal con los mismos centímetros (un tigre agazapado no encoge ni crece).
## API (la de la vista, moving_car_view.gd, y la galería): build(id, posture, size_m, opts) → root, fit_box, anchors,
## pose(p), set_claws(natural, inlay, color), set_alpha(a), free_nodes(); y claw_points() (dónde están ahora las puntas
## de las garras). Solo dibujo: el tamaño y las posiciones las da el estado.
extends RefCounted

const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Cassowary3D = preload("res://app/lab/animals/cassowary3d.gd")
const Mammals3D = preload("res://app/lab/animals/mammals3d.gd")
const Birds3D = preload("res://app/lab/animals/birds3d.gd")
const Theropod3D = preload("res://app/lab/animals/theropod3d.gd")
const Sleep3D = preload("res://app/lab/animals/sleep3d.gd")
const SURFACE = preload("res://app/lab/animals/animal_surface.gdshader")
const SHELL = preload("res://app/lab/animals/animal_shell.gdshader")
const CARD = preload("res://app/lab/animals/animal_card.gdshader")
const EYE = preload("res://app/lab/animals/animal_eye.gdshader")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")

## Especies modeladas (todas las de AnimalArt.KINDS).
const MODELS := ["casuario", "tigre", "oso", "aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "velociraptor", "velociraptor_pelicula"]
## Lo que dura el vuelo de los trozos de una garra que se rompe (s).
const SHARDS_S := 0.9

var id := ""
var kind := ""
var posture := ""
## Raíz del animal (en los pies): la vista la coloca, la gira y la escala.
var root: Node3D
## m por cm del modelo.
var mpc := 0.01
## Caja del cuerpo (m, y hacia arriba, origen en los pies) en la postura construida; en los terópodos, hasta la cadera
## (como su tamaño del estado: la cabeza sobresale), como en la 4h.
var fit_box := Rect2()
## Lo que ocupa entero (m), con la cola, los mechones y las garras (para encuadrarlo).
var full_box := Rect2()
## Puntos (m, en la raíz, en la postura construida): eye, neck, hip… y claws (las puntas de las garras).
var anchors := {}
## Garras: [{ node (base), tip (nodo de la punta), tip_cm, far }] y su material (el de la biblioteca, compartido).
var claws: Array = []
var claw_mat: ShaderMaterial
## El color natural de las garras de la especie (ClawOptics.KERATIN_COLORS, con su fuente).
var claw_natural := Color("#1E1B1A")
## Compatibilidad con la 4h (las alas abiertas de las aves: [cerca, lejos]).
var wings: Array = []
## Texturas creadas al construirlo (0 si venían de la caché), mallas construidas, vértices y lo que tardó (µs).
var rasterized := 0
var meshes_built := 0
var verts := 0
var build_us := 0
## Variante del dibujo (velocirraptor: «reconstruccion» o «pelicula»); no es otra física.
var variant := ""
## Huesos: nombre → Node3D.
var bones := {}

var _data := {}
var _post := {}
## Los giros de este fotograma antes de los retoques (la postura, mezclada con otra si pose lo pide).
var _cur := {}
var _model: Node3D
var _base := {}
var _mats: Array = []
var _anim_mats: Array = []
var _shell_mats: Array = []
var _card_mats: Array = []
var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _t := 0.0
## El reloj de lo que mueve el aire (plumas, pelo, la cola de las aves): el de la pose a la cámara lenta de la vista
## (pose.slowmo; las frecuencias del aleteo están pensadas para ×0,1, la de la vista).
var _air_t := 0.0
var _alpha := 1.0
var _claw_key := ""
var _claws_look := ""
## Dónde va el material de las garras: [MeshInstance3D, superficie (−1: material_override, los trozos)], con qué
## calidad y entorno se pide a la biblioteca, y las copias de este animal (clave → ShaderMaterial: el desvanecido es suyo).
var _claw_slots: Array = []
var _claw_copies := {}
var _claw_quality := "escritorio"
## El reflejo dibujado de la carretera en los metales (dibujo, unidad 4r con la 5q): el cielo del coche en marcha es el de un
## atardecer, oscuro por el cenit, y el reflejo de Godot (sin sonda en el coche) deja el acero gris y el oro apagado; el
## entorno dibujado de la biblioteca (claw_env_road, con el horizonte y el sol) se sube para que un metal se vea como metal.
const METAL_ENV_ROAD := 4.0
## Lo mismo en las gemas y los vidrios (unidad 4s, dibujo): lo que se ve dentro es el entorno dibujado, refractado.
const GEM_ENV_ROAD := 2.5
var _claw_env := "carretera"
var _broken := false
var _break_t := -1.0
var _shards: Array = []


## Construye el animal: size_m = (alto, largo, envergadura) en m. opts: sex, quality («movil»: menos segmentos y
## texturas más pequeñas), cache (Dictionary compartido: modelos y texturas), variant (velocirraptor), pitch_deg (no
## hace falta en 3D; se acepta), claw_env (el entorno que se ve dentro de las garras de gema: «carretera», por defecto,
## o «taller»).
static func build(p_id: String, p_posture: String, size_m: Vector3, opts := {}) -> RefCounted:
	var t0 := Time.get_ticks_usec()
	var a: RefCounted = (load("res://app/lab/animals/animal3d.gd") as GDScript).new()
	a.call("_build", p_id, p_posture, size_m, opts)
	a.set("build_us", Time.get_ticks_usec() - t0)
	return a


func _build(p_id: String, p_posture: String, size_m: Vector3, opts: Dictionary) -> void:
	id = p_id
	posture = p_posture
	kind = AnimalArt.kind_of(id) if MODELS.has(id) else ""
	root = Node3D.new()
	root.name = "Animal_" + id
	if kind == "":
		return
	var mobile := String(opts.get("quality", "")) == "movil"
	_claw_quality = "movil" if mobile else "escritorio"
	_claw_env = String(opts.get("claw_env", "carretera"))
	var cache: Dictionary = opts.get("cache", {})
	var sex := String(opts.get("sex", "hembra"))
	if kind == "teropodo":
		variant = Theropod3D.variant_of(opts, id)
	var key := "modelo|%s|%s|%s|%s" % [id, sex if kind == "corredora" else "", variant, "movil" if mobile else "escritorio"]
	if cache.has(key):
		_data = cache[key]
	else:
		_data = _make(sex, mobile, cache)
		cache[key] = _data
		meshes_built = (_data.meshes as Dictionary).size()
		rasterized = int(_data.info.get("textures", 0))
	verts = int(_data.verts)
	claw_natural = ClawOptics.keratin_color(id, (_data.info.get("claw_natural", claw_natural) as Color).to_html(false))
	# «dormido» (la cetrería, unidad 5c): tumbado de lado; se añade al modelo la primera vez que se pide
	if posture == "dormido" and not (_data.postures as Dictionary).has("dormido"):
		_data.postures["dormido"] = Sleep3D.posture(_data, id)
	# la postura: giros de reposo de los huesos
	var post: Dictionary = _data.postures.get(posture, _data.postures.get(_data.info.get("ref_posture", ""), {}))
	_post = post
	for b: String in post:
		if not b.begins_with("@"):
			_base[b] = Quaternion.from_euler(post[b])
	# la escala: la caja de referencia cabe en alto × largo
	var fit: AABB = _data.fit
	mpc = AnimalArt.fit_scale(Rect2(fit.position.x, fit.position.y, fit.size.x, fit.size.y), size_m.y, size_m.x)
	_model = Node3D.new()
	_model.name = "Modelo"
	_model.scale = Vector3.ONE * mpc
	root.add_child(_model)
	_nodes()
	# las alas abiertas, con la envergadura del estado: su largo (del hombro a la punta) es la media envergadura menos
	# el medio cuerpo
	var wing: Dictionary = _data.info.get("wing", {})
	if not wing.is_empty() and size_m.z > 0.0:
		var k := clampf((size_m.z * 0.5 / mpc - float(wing.body_half)) / maxf(float(wing.len), 1.0), 0.5, 2.0)
		for s: String in ["_n", "_f"]:
			scale_bone("ala" + s, Vector3.ONE * k)
	# la caja y las anclas en la postura construida
	var xf := Rig3D.globals(_data, post)
	var box := Rig3D.posed_box(_data, xf, _data.get("fit_skip", []))
	fit_box = Rect2(box.position.x * mpc, box.position.y * mpc, box.size.x * mpc, box.size.y * mpc)
	var all := Rig3D.posed_box(_data, xf)
	full_box = Rect2(all.position.x * mpc, all.position.y * mpc, all.size.x * mpc, all.size.y * mpc)
	for n: String in _data.anchors:
		var e: Array = _data.anchors[n]
		var bx: Transform3D = xf.get(e[0], Transform3D.IDENTITY)
		var p: Vector3 = bx * ((e[1] as Vector3) - _pivot(e[0]))
		anchors[n] = Vector2(p.x, p.y) * mpc
	var tips: Array = []
	for c: Dictionary in _data.claws:
		var bx: Transform3D = xf.get(c.tip_bone, Transform3D.IDENTITY)
		tips.append(bx * ((c.tip as Vector3) - _pivot(c.tip_bone)) * mpc)
	anchors["claws"] = tips
	if kind == "teropodo" and anchors.has("hip"):
		fit_box.size.y = (anchors.hip as Vector2).y - fit_box.position.y
	_add_shadow(box)
	_add_shards()
	set_claws(true, "none", claw_natural)


## El modelo de la especie (lo que se guarda en la caché).
func _make(sex: String, mobile: bool, cache: Dictionary) -> Dictionary:
	match id:
		"casuario":
			return Cassowary3D.make(sex, mobile, cache)
		"tigre", "oso":
			return Mammals3D.make(id, mobile, cache)
		"aguila", "arpia", "halcon", "buho", "lechuza", "buitre":
			return Birds3D.make(id, mobile, cache)
		"velociraptor", "velociraptor_pelicula":
			return Theropod3D.make(variant, mobile, cache)
	return {}


func _pivot(b: String) -> Vector3:
	return Rig3D._pivot_of(_data, b)


## Los nodos: un Node3D por hueso (en su pivote, con el giro de la postura) y la malla de cada uno con sus materiales.
func _nodes() -> void:
	var mats := {}
	for b: Dictionary in _data.bones:
		var name: String = b.name
		var n := Node3D.new()
		n.name = name
		var parent: String = b.parent
		var ppos: Vector3 = _pivot(parent) if parent != "" else Vector3.ZERO
		n.position = (b.pivot as Vector3) - ppos + (_post.get("@" + name, Vector3.ZERO) as Vector3)
		n.quaternion = _base.get(name, Quaternion.IDENTITY)
		if parent != "" and bones.has(parent):
			(bones[parent] as Node3D).add_child(n)
		else:
			_model.add_child(n)
		bones[name] = n
		if _data.meshes.has(name):
			var mm: Array = _data.meshes[name]
			var mi := MeshInstance3D.new()
			mi.name = "Malla"
			mi.mesh = mm[0]
			var ids: Array = mm[1]
			for i in ids.size():
				var mid: String = ids[i]
				if mid == "garra":
					# el material de las garras lo pone set_claws (de la biblioteca); su largo, para la punta
					_claw_slots.append([mi, i])
					continue
				if not mats.has(mid):
					mats[mid] = _material(mid)
				mi.set_surface_override_material(i, mats[mid])
			n.add_child(mi)
	for c: Dictionary in _data.claws:
		claws.append({ "node": bones[c.bone], "tip": bones[c.tip_bone], "tip_cm": c.tip, "tip_local": (c.tip as Vector3) - _pivot(c.tip_bone),
			"far": bool(c.far), "name": String(c.get("name", "")), "base_basis": _claw_basis(c) })
	for s: String in ["_n", "_f"]:
		show_bone("parpado" + s, false)


## El marco de la base de una garra (en su hueso, que tiene el pivote en la base): +X la dirección de partida, +Y su
## «arriba» (la cara dorsal) y +Z el lado.
static func _claw_basis(c: Dictionary) -> Basis:
	if not c.has("d0"):
		return Basis.IDENTITY
	var d: Vector3 = c.d0
	var u: Vector3 = c.up
	return Basis(d, u, d.cross(u).normalized()).orthonormalized()


## Una garra por su nombre (el del modelo: «mano_n1», «talon3_f», «hoz_n»…) o -1.
func claw_index(claw_name: String) -> int:
	for i in claws.size():
		if String(claws[i].name) == claw_name:
			return i
	return -1


## El nodo de la base de la garra i (su pivote, en la base) y el marco de la base en él (para colgar otra garra ahí).
func claw_base(i: int) -> Array:
	var c: Dictionary = claws[i]
	return [c.node, Transform3D(c.base_basis as Basis, Vector3.ZERO)]


## Esconde (o enseña) la malla de la garra i y la de su punta, sin tocar sus nodos (lo que cuelga de ellos sigue a la
## vista).
func show_claw_mesh(i: int, on: bool) -> void:
	var c: Dictionary = claws[i]
	for n: Node3D in [c.node, c.tip]:
		var mi := n.get_node_or_null("Malla") as MeshInstance3D
		if mi != null:
			mi.visible = on


## Caja (cm, en el modelo, en la postura construida) de la malla de un hueso; vacía si no tiene.
func bone_box(b: String) -> AABB:
	if not (_data.meshes as Dictionary).has(b):
		return AABB()
	var xf := Rig3D.globals(_data, _post)
	return Rig3D.posed_box(_data, { b: xf[b] })


## Caja (m, en el espacio de la raíz, en la postura construida) de todo el animal en 3D (con su anchura en z), sin las
## alas abiertas de las aves (escondidas con las alas plegadas).
func posed_aabb() -> AABB:
	var skip: Array = ["ala_n", "ala_f", "mano_n", "mano_f"] if kind == "ave" else []
	var b := Rig3D.posed_box(_data, Rig3D.globals(_data, _post), skip)
	return AABB(b.position * mpc, b.size * mpc)


## Pivote de un hueso (cm, en el modelo, en reposo).
func bone_pivot(b: String) -> Vector3:
	return _pivot(b)


## Dónde está ahora un hueso (su pivote, m, en el espacio de la raíz, con la pose de este fotograma).
func bone_point(b: String) -> Vector3:
	var n: Node3D = bones.get(b)
	if n == null:
		return Vector3.ZERO
	var xf := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != root:
		xf = (x as Node3D).transform * xf
		x = x.get_parent()
	return xf.origin


## Un material de la especie (su descripción, en _data.mats) para este animal: sus parámetros y sus capas de pelo.
func _material(mid: String) -> Material:
	var spec: Dictionary = _data.mats.get(mid, {})
	var m := ShaderMaterial.new()
	match String(spec.get("shader", "surface")):
		"surface":
			m.shader = SURFACE
			if spec.get("pattern") != null:
				m.set_shader_parameter("albedo_tex", spec.pattern)
			if spec.get("detail_albedo") != null:
				m.set_shader_parameter("detail_albedo", spec.detail_albedo)
			if spec.get("detail_normal") != null:
				m.set_shader_parameter("detail_normal", spec.detail_normal)
			for k: Array in [["detail_mix", "detail_mix"], ["normal_depth", "normal_depth"], ["rough", "roughness"], ["spec", "specular"],
					["metal", "metallic"], ["rim", "rim"], ["rim_tint", "rim_tint"], ["sheen", "sheen"], ["wobble", "wobble_m"]]:
				if spec.has(k[0]):
					m.set_shader_parameter(k[1], float(spec[k[0]]))
			m.set_shader_parameter("tint", spec.get("tint", Color(1, 1, 1)))
			_anim_mats.append(m)
			var n := int(spec.get("shells", 0))
			var prev: Material = m
			for i in n:
				var s := ShaderMaterial.new()
				s.shader = SHELL
				s.set_shader_parameter("shell_k", float(i + 1) / float(n))
				s.set_shader_parameter("shell_len", float(spec.get("shell_len", 0.01)))
				s.set_shader_parameter("strands", spec.get("strands"))
				s.set_shader_parameter("strand_scale", float(spec.get("strand_scale", 2.0)))
				s.set_shader_parameter("tip_tint", spec.get("tip", Color(1, 1, 1)))
				s.set_shader_parameter("tint", spec.get("tint", Color(1, 1, 1)))
				if spec.get("pattern") != null:
					s.set_shader_parameter("albedo_tex", spec.pattern)
				s.set_shader_parameter("roughness", float(spec.get("rough", 0.9)))
				s.set_shader_parameter("rim", float(spec.get("rim", 0.5)))
				s.set_shader_parameter("rim_tint", float(spec.get("rim_tint", 0.5)))
				s.set_shader_parameter("sheen", float(spec.get("sheen", 0.2)))
				s.render_priority = i + 1
				prev.next_pass = s
				prev = s
				_shell_mats.append(s)
				_mats.append(s)
		"card":
			m.shader = CARD
			m.set_shader_parameter("feather_tex", spec.get("tex"))
			for k: Array in [["rough", "roughness"], ["spec", "specular"], ["rim", "rim"], ["rim_tint", "rim_tint"], ["sheen", "sheen"],
					["raise", "raise_m"], ["wobble", "wobble_m"]]:
				if spec.has(k[0]):
					m.set_shader_parameter(k[1], float(spec[k[0]]))
			m.set_shader_parameter("tint", spec.get("tint", Color(1, 1, 1)))
			_card_mats.append(m)
		"eye":
			m.shader = EYE
			m.set_shader_parameter("iris", spec.get("iris", Color(0.8, 0.5, 0.1)))
			m.set_shader_parameter("sclera", spec.get("sclera", Color(0.9, 0.86, 0.78)))
			m.set_shader_parameter("iris_r", float(spec.get("iris_r", 0.6)))
			m.set_shader_parameter("pupil_r", float(spec.get("pupil_r", 0.28)))
			m.set_shader_parameter("pupil_sx", float(spec.get("pupil_sx", 1.0)))
	_mats.append(m)
	return m


## Sombra de contacto: una mancha oscura y difuminada bajo los pies (con o sin sombras de verdad).
func _add_shadow(box: AABB) -> void:
	var w := maxf(box.size.x * 0.75, 10.0)
	_shadow = MeshInstance3D.new()
	_shadow.name = "Sombra"
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, w * 0.45)
	_shadow.mesh = pm
	_shadow.position = Vector3(box.position.x + box.size.x * 0.5, 0.25, 0.0)
	var img := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var u := (float(x) + 0.5) / 32.0 - 1.0
			var v := (float(y) + 0.5) / 16.0 - 1.0
			var d := sqrt(u * u + v * v)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.7))
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_texture = ImageTexture.create_from_image(img)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_shadow)


## Trozos de las garras: tres esquirlas por garra, escondidas; saltan cuando la garra se mella o se parte.
func _add_shards() -> void:
	if claws.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, 0), Vector3(0.9, 0.2, 0.1), Vector3(0.3, 0.8, 0.2), Vector3(0.2, 0.3, 0.7)]
	for f: Array in [[0, 2, 1], [0, 1, 3], [0, 3, 2], [1, 2, 3]]:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		var nn := (b - a).cross(c - a).normalized()
		for v: Vector3 in [a, b, c]:
			st.set_normal(-nn)
			st.set_color(Color(1, 1, 1, 0))
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2.ZERO)
			st.add_vertex(v)
	var mesh := st.commit()
	for c: Dictionary in claws:
		var group := Node3D.new()
		group.name = "Trozos"
		group.visible = false
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3(float(k) * 0.6 - 0.6, float(k % 2) * 0.5, float(k) * 0.3)
			mi.scale = Vector3.ONE * (0.9 + 0.35 * float(k))
			_claw_slots.append([mi, -1])
			group.add_child(mi)
		_model.add_child(group)
		_shards.append({ "node": group, "at": c.tip_cm, "k": _shards.size() })


# ════════ Cada fotograma ════════

## Gira el hueso b: su postura por el giro r (radianes, orden YXZ).
func rot(b: String, r: Vector3) -> void:
	var n: Node3D = bones.get(b)
	if n == null:
		return
	n.quaternion = (_base.get(b, Quaternion.IDENTITY) as Quaternion) * Quaternion.from_euler(r)


## Retoque sobre lo de este fotograma (la postura o su mezcla): el giro r encima.
func rot_add(b: String, r: Vector3) -> void:
	var n: Node3D = bones.get(b)
	if n == null:
		return
	n.quaternion = (_cur.get(b, Quaternion.IDENTITY) as Quaternion) * Quaternion.from_euler(r)


## Mezcla la postura con otra del modelo (post, k de 0 a 1): giros y desplazamientos (el salto sobre el agazapado, …).
func blend_post(post: String, k: float) -> void:
	var tgt: Dictionary = _data.postures.get(post, {})
	if tgt.is_empty():
		return
	for b: String in tgt:
		if b.begins_with("@"):
			continue
		var q0: Quaternion = _base.get(b, Quaternion.IDENTITY)
		var q := q0.slerp(Quaternion.from_euler(tgt[b]), k) if k > 0.0 else q0
		_cur[b] = q
		var n: Node3D = bones.get(b)
		if n != null:
			n.quaternion = q
	# los desplazamientos de los huesos de las dos posturas
	var keys := {}
	for b: String in tgt:
		if b.begins_with("@"):
			keys[b] = true
	for b: String in _post:
		if b.begins_with("@"):
			keys[b] = true
	for key: String in keys:
		var name := key.substr(1)
		var n: Node3D = bones.get(name)
		if n == null:
			continue
		var o0: Vector3 = _post.get(key, Vector3.ZERO)
		var o1: Vector3 = tgt.get(key, Vector3.ZERO)
		n.position = _rest_pos(name) + o0.lerp(o1, k)


func _rest_pos(b: String) -> Vector3:
	for e: Dictionary in _data.bones:
		if e.name == b:
			var parent: String = e.parent
			return (e.pivot as Vector3) - (_pivot(parent) if parent != "" else Vector3.ZERO)
	return Vector3.ZERO


func scale_bone(b: String, s: Vector3) -> void:
	var n: Node3D = bones.get(b)
	if n != null:
		n.scale = s


func show_bone(b: String, on: bool) -> void:
	var n: Node3D = bones.get(b)
	if n != null:
		n.visible = on


## Opacidad de la sombra de contacto (0-1), por la del animal.
func show_shadow(k: float) -> void:
	if _shadow == null:
		return
	var a := clampf(k, 0.0, 1.0) * _alpha
	_shadow.visible = a > 0.01
	_shadow_mat.albedo_color = Color(1, 1, 1, a)


## Parpadeo: los párpados se cierran un instante cada pocos segundos (el casquete de piel se abre en vertical).
func blink() -> void:
	var ph := fmod(_t + 0.37 * float(id.length()), 4.3)
	var on := _t > 0.0 and ph < 0.16
	var k := sin(ph / 0.16 * PI) if on else 0.0
	for s: String in ["_n", "_f"]:
		var n: Node3D = bones.get("parpado" + s)
		if n != null:
			n.visible = k > 0.05
			n.scale = Vector3(1.0, maxf(k, 0.05), 1.0)


## Opacidad de todo el animal (tramado ordenado por debajo de 1: sin materiales translúcidos).
func set_alpha(a: float) -> void:
	a = clampf(a, 0.0, 1.0)
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("fade", a)
	if claw_mat != null:
		claw_mat.set_shader_parameter("claw_fade", a)
	root.visible = a > 0.003


## La pose del fotograma: asleep (dormido: respiración lenta, ojos cerrados, quieto; con breath_hz, breath_amp, flinch y
## flinch_leg; unidad 5c), t, live, alpha, wing_open, wing_lift, bristle, flutter, scared, claws_out, claw_len, claw_gone,
## claw_bend, kick (la patada del casuario y, como leap, el salto del velocirraptor), lean; y, nuevas (unidad 4l):
## wind_local_ms (el aire junto al animal, m/s reales: mueve plumas y pelo), slowmo (la cámara lenta de la vista, 0,1:
## el aire se agita a su ritmo), wind_dir (Vector3: hacia dónde va el aire, en el mundo; por defecto hacia la zaga), leap
## (0-1: salto con las patas delante), shards (0-1: el vuelo de los trozos de una garra rota, si la vista lo quiere
## guiar). La pose no toca la raíz (es de la vista): solo nodos de dentro.
func pose(p: Dictionary) -> void:
	if kind == "":
		return
	_t = float(p.get("t", 0.0)) if bool(p.get("live", false)) else 0.0
	_air_t = _t * clampf(float(p.get("slowmo", 0.1)) / 0.1, 0.05, 10.0)
	set_alpha(float(p.get("alpha", 1.0)))
	_pose_air(p)
	_pose_claws(p)
	_cur = _base.duplicate()
	if bool(p.get("asleep", false)):
		_pose_asleep(p)
		return
	match kind:
		"corredora":
			Cassowary3D.pose(self, p)
		"mamifero":
			Mammals3D.pose(self, p)
		"ave":
			Birds3D.pose(self, p)
		"teropodo":
			Theropod3D.pose(self, p)


## Dormido (anestesiado o sedado; la cetrería, unidad 5c): respira despacio (breath_hz, 0,25 por defecto), los ojos
## cerrados y quieto; el respingo de dolor (flinch, 0-1) sacude la pata flinch_leg (el hueso de su raíz).
func _pose_asleep(p: Dictionary) -> void:
	var hz := float(p.get("breath_hz", 0.25))
	var amp := float(p.get("breath_amp", 0.012))
	var br := 1.0 + amp * sin(TAU * hz * _t)
	scale_bone("torso", Vector3(1.0, br, 1.0 + 0.5 * (br - 1.0)))
	for s: String in ["_n", "_f"]:
		var lid: Node3D = bones.get("parpado" + s)
		if lid != null:
			lid.visible = true
			lid.scale = Vector3.ONE
	for leg: String in (Sleep3D.LEG_BONES.get(kind, {}) as Dictionary).values():
		rot_add(leg, Vector3.ZERO)
	var fl := clampf(float(p.get("flinch", 0.0)), 0.0, 1.0)
	var leg_b := String(p.get("flinch_leg", ""))
	if fl > 0.0 and leg_b != "":
		var j := fl * sin(_t * 40.0)
		rot_add(leg_b, Vector3(0.05 * j, 0.0, 0.12 * j))
	show_bone("erizado", false)
	if kind == "ave":
		# las alas plegadas (las abiertas, escondidas)
		for s: String in ["_n", "_f"]:
			show_bone("ala" + s, false)
			show_bone("ala_plegada" + s, true)


## El aire en los materiales: dirección, fuerza (0-1) y el tiempo de la pose; y el erizado.
func _pose_air(p: Dictionary) -> void:
	var fl := clampf(float(p.get("flutter", 0.0)), 0.0, 1.0)
	if p.has("wind_local_ms"):
		fl = maxf(fl, clampf(float(p.wind_local_ms) / 33.0, 0.0, 1.0))
	if not bool(p.get("live", false)):
		fl = 0.0
	var wd: Vector3 = p.get("wind_dir", Vector3(-1, 0, 0))
	var br := clampf(maxf(float(p.get("bristle", 0.0)), float(p.get("scared", 0.0)) * 0.6), 0.0, 1.0)
	for m: ShaderMaterial in _anim_mats:
		m.set_shader_parameter("flutter", fl)
		m.set_shader_parameter("wind", wd)
		m.set_shader_parameter("anim_t", _air_t)
	for m: ShaderMaterial in _shell_mats:
		m.set_shader_parameter("flutter", fl)
		m.set_shader_parameter("wind", wd)
		m.set_shader_parameter("anim_t", _air_t)
		m.set_shader_parameter("bristle", br)
	for m: ShaderMaterial in _card_mats:
		m.set_shader_parameter("flutter", fl)
		m.set_shader_parameter("wind", wd)
		m.set_shader_parameter("anim_t", _air_t)
		m.set_shader_parameter("bristle", br)


## Las garras: fuera o no, melladas (más cortas: se pierde la punta), partidas (sin garra) o dobladas (la punta
## torcida), y los trozos que saltan al romperse.
func _pose_claws(p: Dictionary) -> void:
	var out := clampf(float(p.get("claws_out", 1.0)), 0.0, 1.0)
	var gone := bool(p.get("claw_gone", false))
	var keep := clampf(float(p.get("claw_len", 1.0)), 0.15, 1.0)
	var bend := float(p.get("claw_bend", 0.0)) > 0.5
	var key := "%s|%s|%s|%s" % [snappedf(out, 0.01), gone, snappedf(keep, 0.01), bend]
	if key != _claw_key:
		_claw_key = key
		for c: Dictionary in claws:
			var n: Node3D = c.node
			var tip: Node3D = c.tip
			n.visible = out > 0.0 and not gone
			var chipped := keep < 0.97
			tip.visible = not chipped
			var s := out * (clampf(keep / 0.6, 0.3, 1.0) if chipped else 1.0)
			n.scale = Vector3.ONE * maxf(s, 0.001)
			tip.quaternion = Quaternion.from_euler(Vector3(0.9 if bend else 0.0, 0.0, -0.6 if bend else 0.0))
	var broken := gone or keep < 0.97
	if broken and not _broken:
		_break_t = _t
	_broken = broken
	var prog := -1.0
	if p.has("shards"):
		prog = float(p.shards)
	elif broken and _t > 0.0 and _break_t >= 0.0:
		prog = (_t - _break_t) / SHARDS_S
	for sh: Dictionary in _shards:
		var g: Node3D = sh.node
		var on := prog >= 0.0 and prog < 1.0
		g.visible = on
		if on:
			var k := float(sh.k)
			var v := Vector3(18.0 + 6.0 * sin(k * 1.7), 24.0 + 5.0 * cos(k * 2.3), 8.0 * sin(k * 3.1))
			var tt := prog * SHARDS_S
			g.position = (sh.at as Vector3) + v * tt + Vector3(0, -490.0, 0) * tt * tt * 0.5
			g.rotation = Vector3(tt * 9.0, tt * 7.0 + k, tt * 5.0)


## Material de las garras, de la biblioteca (ClawMaterial: se construye una vez por material y queda en su caché): la
## queratina con el color natural de la especie o el material reforjado (un id de claw_optics.gd: los de Data.INLAYS y
## los de la reforja) con su color, su brillo y su luz reales y su acabado de serie. El animal usa una copia (una vez por
## material: el desvanecido es suyo, como en sus demás materiales). Un id que la biblioteca no conoce se pinta como
## queratina del color col (dibujo). env: el entorno que se ve dentro de las gemas («taller» en la cetrería; "" = el de
## build, «carretera» por defecto).
func set_claws(natural: bool, inlay_id: String, col: Color, env := "") -> void:
	if kind == "":
		return
	if env != "":
		_claw_env = env
	var known := ClawOptics.MATERIALS.has(inlay_id) and inlay_id != "none"
	var mid := inlay_id if not natural and known else "none"
	var tint := claw_natural if natural or known else col
	var key := "%s|%s|%s" % [mid, tint.to_html(false), _claw_env]
	if key == _claws_look:
		return
	_claws_look = key
	if not _claw_copies.has(key):
		var o := { "quality": _claw_quality, "env": _claw_env }
		if mid == "none":
			o["color"] = tint
		var copy: ShaderMaterial = ClawMaterial.material(mid, {}, o).duplicate()
		var claw_kind := int(ClawMaterial.KIND.get(String(ClawOptics.look(mid).family), 0))
		if _claw_env == "carretera" and claw_kind == 1:
			# en la copia (la caché de la biblioteca no distingue la energía del entorno)
			copy.set_shader_parameter("claw_env_energy", METAL_ENV_ROAD)
		elif _claw_env == "carretera" and claw_kind == 2:
			# unidad 4s: una gema o un vidrio de cerca, delante de un hueco oscuro, se veía negra: el entorno dibujado sube
			copy.set_shader_parameter("claw_env_energy", GEM_ENV_ROAD)
		if _claw_env == "carretera":
			ClawMaterial.apply_road_light(copy)  # unidad 4w: el cielo de la luz del coche
		_claw_copies[key] = copy
	claw_mat = _claw_copies[key]
	claw_mat.set_shader_parameter("claw_fade", _alpha)
	for slot: Array in _claw_slots:
		var mi: MeshInstance3D = slot[0]
		if int(slot[1]) < 0:
			mi.material_override = claw_mat
		else:
			mi.set_surface_override_material(int(slot[1]), claw_mat)


## Dónde están ahora las puntas de las garras (m, en el espacio de la raíz, con la pose de este fotograma).
func claw_points() -> Array:
	var out: Array = []
	for c: Dictionary in claws:
		var tip: Node3D = c.tip
		var xf := Transform3D.IDENTITY
		var n: Node = tip
		while n != null and n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		out.append(xf * (c.tip_local as Vector3))
	return out


## Libera los nodos.
func free_nodes() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()


# ════════ Luz del sol (unidad 4w) ════════

## La luz del coche ha cambiado (ClawMaterial.road_light): sus copias de la carretera la toman.
func relight_claws() -> void:
	if _claw_env != "carretera":
		return
	for k: String in _claw_copies:
		ClawMaterial.apply_road_light(_claw_copies[k])
