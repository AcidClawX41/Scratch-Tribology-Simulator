## Los animales de la cetrería en el coche en marcha (unidad 4r, petición 51: «poner los animales ya recreados del simulador
## de cetrería y garras 3D en los del coche»): el cuerpo de alta definición de la cetrería (care_body.gd y body_*.gd, de las
## unidades 5i y 5n, con las medidas de core/lab/care_anatomy.gd) y sus patas (care_paw.gd, 5h), de pie o agazapados encima
## del coche en lugar de tumbados en la mesa, con las garras de la biblioteca de materiales (ClawGeo y ClawMaterial) del
## material elegido. Todo se coloca aquí, sin cambiar cómo se ven en la cetrería:
##   - cada pata de la cetrería está hecha tumbada (la palma o los dedos en la mesa y el antebrazo, la pierna, el tarso o el
##     metatarso hacia atrás, casi tumbado): se dobla por la muñeca o el tobillo (bend) y sube, con la palma o los dedos en
##     el suelo y las garras en la chapa;
##   - el cuerpo se hace alrededor de esos anclajes con la pose del coche (body_*.gd: sin la mesa, el tronco entre las patas
##     y a la altura de la postura), en el marco de la cetrería (el lomo hacia −X, la cabeza hacia −Z, la derecha hacia +Y), y
##     se gira al del coche (la cabeza hacia +X, arriba +Y y la derecha hacia +Z, hacia quien mira); las rapaces, además,
##     levantan el pecho (posadas);
##   - sin la tela, la toalla, la capucha, la mascarilla ni el pulsioxímetro de la clínica, y con los ojos abiertos (la
##     sujeción «libre»: parpadean y respiran despacio).
## La misma API que Animal3D (la vista no los distingue): build(id, posture, size_m, opts) → root, fit_box, full_box, anchors,
## pose(p), set_claws(natural, inlay, color, env), set_alpha(a), free_nodes() y claw_points(); y verts, build_us, kind,
## posture y variant. El origen, en el suelo: entre las manos y los pies (tigre y oso) o en los pies (rapaces y
## velocirraptores), como los de la 4l. Solo dibujo: el tamaño lo da el estado (MovingCar.BODIES: el largo y el alto) y el
## sitio, la vista (los puntos de apoyo de las zonas de MovingCar).
## Lo que no tiene (los cuerpos de la cetrería son rígidos): las alas abiertas de las rapaces y el salto de los
## velocirraptores; para eso la vista sigue con los modelos de la 4l (supports()). El casuario no tiene cuerpo de cetrería.
## Coste: el modelo (las mallas de las patas y el cuerpo, en la caché de la vista) se hace una vez por especie, postura y
## calidad; en cada fotograma, la pose solo mueve nodos y pasa la respiración y los párpados a los materiales.
extends RefCounted

const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const Theropod3D = preload("res://app/lab/animals/theropod3d.gd")
const CareBody = preload("res://app/lab/cetreria/care_body.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const CareKit = preload("res://app/lab/cetreria/care_kit.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const ClawGeo = preload("res://app/common/claw_geo.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")

## Las especies con cuerpo de la cetrería y su animal de la cetrería (el de care_body.gd y care_paw.gd).
const SPECIES := {
	"tigre": "tigre", "oso": "oso", "aguila": "rapaz", "arpia": "rapaz", "halcon": "rapaz", "buho": "rapaz", "lechuza": "rapaz",
	"buitre": "rapaz", "velociraptor": "velociraptor", "velociraptor_pelicula": "velociraptor",
}
## Las posturas del coche que tienen cuerpo de la cetrería, por tipo (MovingCar.POSTURES); las alas abiertas, no.
const POSTURES := { "mamifero": ["tumbado", "de_pie"], "ave": ["plegadas"], "teropodo": ["tumbado"] }
## Las patas de cada tipo (los nombres de la cetrería: ClawCareState.paws_of).
const PAWS := {
	"mamifero": ["delantera_derecha", "delantera_izquierda", "trasera_derecha", "trasera_izquierda"],
	"ave": ["derecha", "izquierda"], "teropodo": ["derecha", "izquierda"],
}
## Cada postura (dibujo): cuánto sube el antebrazo o el tarso (fore_deg) y la pierna (hind_deg) al doblar la pata de la
## cetrería por la muñeca o el tobillo; el lomo del tigre y del oso, en fracciones de su alto (back_k: de pie, el alto a la
## cruz; agazapado, más bajo); cuánto levanta el pecho (pitch_deg: la rapaz posada, por especie en pitch_by: más erguidos
## el búho y la lechuza, menos la arpía, de cola larga, para que la cola no se meta en la chapa; el velocirraptor, casi
## horizontal); lo que mira la cabeza hacia el suelo (head_pitch) y lo que se adelantan las manos (reach_k). Las rapaces, con
## el tarso casi vertical (fore_deg 80; con 60 y el pecho a 38°, parecían tumbadas hacia delante).
const POSE := {
	"mamifero": {
		"tumbado": { "fore_deg": 34.0, "hind_deg": 40.0, "back_k": 0.6, "head_pitch": 0.2, "reach_k": 1.12 },
		"de_pie": { "fore_deg": 70.0, "hind_deg": 60.0, "back_k": 0.9, "head_pitch": 0.12, "reach_k": 1.0 },
	},
	"ave": { "plegadas": { "fore_deg": 80.0, "pitch_deg": 50.0, "pitch_by": { "aguila": 46.0, "arpia": 40.0, "buitre": 46.0, "buho": 60.0, "lechuza": 66.0 } } },
	"teropodo": { "tumbado": { "fore_deg": 46.0, "pitch_deg": 4.0, "head_pitch": 0.08 } },
}
## Lo que separa las manos del medio del cuerpo (m, a su tamaño de la cetrería: dibujo) y las de delante de las de detrás
## (los codos de la mesa de la cetrería, care_animal.gd PAW_SPOTS: 0,68 m por cada 1,9 m de cabeza y cuerpo).
const HALF_TRACK := { "tigre": 0.12, "oso": 0.18 }
const ELBOWS_M_PER_M := 0.68 / 1.9
## Rapaces y velocirraptores: medio paso entre los dos pies, en fracciones de su largo (dibujo).
const FEET_K := { "ave": 0.065, "teropodo": 0.03 }
## La transición del doblez de la pata (m, a cada lado de la muñeca o del tobillo, a la escala de su garra): dibujo.
const BEND_BLEND := 0.012
## Capas del pelo del cuerpo en el coche: la calidad del teléfono de la cetrería (6) en los dos; el animal se ve de lejos.
const FUR_LAYERS := 6
## El pelo de lejos (dibujo): en el coche el animal mide unos cientos de píxeles y cada pelo de la cetrería, menos de uno; las
## capas dejan entonces un granulado de raíces oscuras y puntas claras. La raíz se acerca a la punta (ROOT_TO_TIP) y el tono
## varía menos de un mechón a otro (TONE_VAR): se ve la masa del pelo con su color.
const ROOT_TO_TIP := 0.55
const TONE_VAR := 0.04
## Lo que acortan las garras de la rapaz los dedos III y IV (las del pulgar y del II, enteras), como los modelos de la 4l.
const RAPTOR_CLAW_K := { "I": 1.0, "II": 1.0, "III": 0.8, "IV": 0.7 }
## El reflejo dibujado de la carretera en los metales (dibujo, unidad 4r con la 5q): el cielo del coche en marcha es el de un
## atardecer, oscuro por el cenit, y el reflejo de Godot (sin sonda en el coche) deja el acero gris y el oro apagado; el
## entorno dibujado de la biblioteca (claw_env_road, con el horizonte y el sol) se sube para que un metal se vea como metal.
const METAL_ENV_ROAD := 4.0
## Vueltas de la malla de una garra en el escritorio (unidad 4w: de cerca, redonda).
const CLAW_RING_NEAR := 32
## Lo mismo en las gemas y los vidrios (unidad 4s, dibujo): lo que se ve dentro es el entorno dibujado, refractado.
const GEM_ENV_ROAD := 2.5
## Unidad 4s (lo que anotó la 4r: «el tigre y el oso, rígidos como estatuas, sin postura de agarre»; «el oso se suelta
## rígido, girando de una pieza»). Dibujo: con la carga (pose.bristle: lo que el agarre se acerca a su tope; asustado, algo
## siempre) el cuerpo se agazapa (baja CROUCH_K de su alto, las patas se doblan bajo él) y la cabeza se agacha contra el viento
## (HEAD_DOWN rad); se balancea un poco con el viento (SWAY rad a SWAY_HZ); y al soltarse (pose.flail, 0-1) las patas se
## abren y se agitan (FLAIL rad), en lugar de irse de una pieza.
const CROUCH_K := 0.12
const HEAD_DOWN := 0.35
const SWAY := 0.012
const SWAY_HZ := 0.7
const FLAIL := 0.9
## Dónde se parte una garra en dos trozos (la base y la punta, que se mella o se dobla), en fracciones de su largo.
const CLAW_CUT := 0.6

## La rotación del marco de la cetrería (L: lomo −X, cabeza −Z, derecha +Y) al del coche (S: cabeza +X, arriba +Y, derecha
## +Z): las columnas son X, Y y Z de L en S.
const L_TO_S := Basis(Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0))

var id := ""
var kind := ""
var posture := ""
## Variante del dibujo (los velocirraptores: «pelicula» o «reconstruccion»; "" en los demás).
var variant := ""
## Raíz del animal (en el suelo): la vista la coloca, la gira y la escala.
var root: Node3D
## Caja del cuerpo (m, en la raíz: x hacia la cabeza, y hacia arriba), sin la cola de los mamíferos; en los velocirraptores,
## hasta la cadera (como su alto del estado, como en la 4l). full_box: todo el animal.
var fit_box := Rect2()
var full_box := Rect2()
## Puntos (m, en la raíz): claws (las puntas de las garras en la postura construida) y, en los velocirraptores, hip.
var anchors := {}
## Vértices de las mallas (las capas del pelo, una vez), mallas construidas (0 si venían de la caché) y lo que tardó (µs).
var verts := 0
var meshes_built := 0
var build_us := 0
## m por m del modelo de la cetrería (su tamaño de care_anatomy.gd frente al del estado).
var scale := 1.0
## El cuerpo de la cetrería (lo que devuelve CareBody.build) y las garras: [{ node, tip, out, in, tip_mm, mis: [base, punta] }].
var body := {}
var claws: Array = []
var claw_mat: ShaderMaterial
var claw_natural := Color("#1E1B1A")

var _model: Node3D
var _lean: Node3D
var _offset: Node3D
var _geoms: Array = []
var _claw_slots: Array = []
var _claw_copies := {}
var _claws_look := ""
var _claw_key := ""
var _claw_quality := "escritorio"
var _claw_env := "carretera"
var _alpha := 1.0
var _breath_t := -1.0
var _cache := {}
## Unidad 4s: el cuerpo (su sitio de reposo), las patas (nodo y su giro de reposo) y la última pose de agarre (para no
## mover nada si no cambia).
var _holder: Node3D
var _holder_rest := Transform3D.IDENTITY
var _height_m := 0.0
var _paw_list: Array = []
var _grip_key := ""
var _near_fur := false


## ¿Tiene cuerpo de la cetrería esta especie en esta postura? (las alas abiertas y el salto, no: los de la 4l)
static func supports(p_id: String, p_posture: String) -> bool:
	var k := AnimalArt.kind_of(p_id)
	return SPECIES.has(p_id) and (POSTURES.get(k, []) as Array).has(p_posture)


## Construye el animal: size_m = (alto, largo, envergadura) en m (draw_size del estado). opts: quality («movil»: la calidad
## del teléfono de la cetrería), cache (Dictionary compartido: las mallas y los materiales), variant (velocirraptor),
## claw_env (el entorno de las garras de gema: «carretera»). Las demás opciones de Animal3D se aceptan y no hacen falta.
static func build(p_id: String, p_posture: String, size_m: Vector3, opts := {}) -> RefCounted:
	var t0 := Time.get_ticks_usec()
	var a: RefCounted = (load("res://app/lab/animals/hd3d.gd") as GDScript).new()
	a.call("_build", p_id, p_posture, size_m, opts)
	a.set("build_us", Time.get_ticks_usec() - t0)
	return a


func _build(p_id: String, p_posture: String, size_m: Vector3, opts: Dictionary) -> void:
	id = p_id
	posture = p_posture
	kind = AnimalArt.kind_of(id)
	root = Node3D.new()
	root.name = "Animal_" + id
	if not supports(id, posture):
		kind = ""
		return
	var mobile := String(opts.get("quality", "")) == "movil"
	_claw_quality = "movil" if mobile else "escritorio"
	_claw_env = String(opts.get("claw_env", "carretera"))
	var cache: Dictionary = opts.get("cache", {})
	_cache = cache
	if kind == "teropodo":
		variant = Theropod3D.variant_of(opts, id)
	var animal := String(SPECIES[id])
	var cl := _claw_spec(id)
	var pose: Dictionary = (POSE[kind] as Dictionary)[posture]
	# la escala: el largo del estado frente al de la cetrería (los dos, del mismo animal; dibujo)
	var natural := CareAnatomy.draw_length_m(id)
	scale = size_m.y / natural if size_m.y > 0.0 and natural > 0.0 else 1.0
	_model = Node3D.new()
	_model.name = "Modelo"
	_model.scale = Vector3.ONE * scale
	root.add_child(_model)
	_lean = Node3D.new()
	_lean.name = "Postura"
	_model.add_child(_lean)
	_offset = Node3D.new()
	_offset.name = "Centro"
	_lean.add_child(_offset)
	# ── las patas, dobladas y en el suelo (marco del coche, m de la cetrería) ──
	var paws := {}
	var anchors_s := {}
	var paw_box := AABB()
	var first := true
	for pw: String in PAWS[kind]:
		var e := _paw(animal, id, cl, pw, pose, mobile, cache)
		paws[pw] = e
	_place_paws(paws, pose, size_m.x / scale)
	for pw: String in paws:
		var e: Dictionary = paws[pw]
		var xf: Transform3D = e.xf
		anchors_s[pw] = xf * (e.anchor as Transform3D)
		var b: AABB = xf * (e.aabb as AABB)
		paw_box = b if first else paw_box.merge(b)
		first = false
	# ── el cuerpo, alrededor de los anclajes, en el marco de la cetrería, y girado al del coche ──
	var body_pose := { "head_pitch": float(pose.get("head_pitch", 0.1)) }
	body_pose["rig"] = kind != "teropodo"  # unidad 4u: la cola (y las alas de la rapaz) en sus pivotes, para el agarre en curva
	var pitch := deg_to_rad(float((pose.get("pitch_by", {}) as Dictionary).get(id, pose.get("pitch_deg", 0.0))))
	var center := Vector3.ZERO
	for pw: String in anchors_s:
		center += (anchors_s[pw] as Transform3D).origin
	center /= float(anchors_s.size())
	match kind:
		"mamifero":
			var top_y := float(pose.back_k) * size_m.x / scale
			var elbow_y := maxf((anchors_s.delantera_derecha as Transform3D).origin.y, (anchors_s.delantera_izquierda as Transform3D).origin.y)
			body_pose["back_m"] = maxf(top_y - elbow_y, 0.05)
		"teropodo":
			var heel_y := maxf((anchors_s.derecha as Transform3D).origin.y, (anchors_s.izquierda as Transform3D).origin.y)
			body_pose["hip_m"] = maxf(size_m.x / scale - heel_y, 0.05)
		"ave":
			# con el pecho levantado, la cabeza mira al frente: baja lo que sube el cuerpo
			body_pose["head_pitch"] = tan(pitch)
	var to_s := Transform3D(Basis(Vector3.BACK, pitch) * L_TO_S, center)
	var to_l := to_s.affine_inverse()
	var anchors_l := {}
	for pw: String in anchors_s:
		anchors_l[pw] = to_l * (anchors_s[pw] as Transform3D)
	var holder := Node3D.new()
	holder.name = "Cuerpo"
	holder.transform = to_s
	_offset.add_child(holder)
	_holder = holder
	_holder_rest = to_s
	_height_m = size_m.x / scale
	body = CareBody.build(holder, animal, id, anchors_l, { "mobile": mobile, "cache": cache, "claw": cl, "pose": body_pose, "props": false,
		"fur_layers": FUR_LAYERS })
	CareBody.set_sedation(body, "libre")
	meshes_built += 1 if bool(body.get("fresh", false)) else 0
	_far_fur(body.get("root") as Node3D)
	_curve_rig(anchors_l)  # unidad 4u: el ala izquierda de la rapaz
	# ── las patas y sus garras, en su sitio ──
	for pw: String in paws:
		_paw_nodes(paws[pw] as Dictionary, pw)
	# ── las cajas, el origen (en el suelo: entre las manos y los pies, o en los pies) y los puntos ──
	var body_box := _box_of(to_s, body.box as AABB)
	var all := body_box.merge(paw_box)
	var origin_x := (paw_box.position.x + paw_box.end.x) * 0.5
	if kind != "mamifero":
		# en los pies: entre los dos, bajo el centro de cada uno
		origin_x = 0.0
		for pw: String in paws:
			origin_x += ((paws[pw] as Dictionary).xf as Transform3D).origin.x / float(paws.size())
	_offset.position = Vector3(-origin_x, 0.0, -center.z)
	full_box = Rect2((all.position.x - origin_x) * scale, all.position.y * scale, all.size.x * scale, all.size.y * scale)
	fit_box = full_box
	if kind == "mamifero":
		# sin la cola: del hocico a la grupa (el tronco acaba poco detrás de las rodillas: ~0,3 m por cada 1,9 m)
		var rump := minf(paw_box.position.x, center.x - ELBOWS_M_PER_M * natural * 0.5 - 0.3 * natural / 1.9)
		fit_box = Rect2((rump - origin_x) * scale, 0.0, (all.end.x - rump) * scale, all.end.y * scale)
	elif kind == "teropodo":
		var hip_y := (center.y + float(body_pose.get("hip_m", 0.0))) * scale
		fit_box = Rect2(full_box.position.x, 0.0, full_box.size.x, hip_y)
		anchors["hip"] = Vector2(0.0, hip_y)
	_count_verts()
	claw_natural = ClawOptics.keratin_color(id, claw_natural.to_html(false))
	set_claws(true, "none", claw_natural)
	anchors["claws"] = claw_points()


## La garra de la especie para las patas (su escala) y las garras: la del catálogo (ClawGeo.spec_of: el alcance y la
## base de la física), con su curvatura.
static func _claw_spec(p_id: String) -> Dictionary:
	var sp := ClawGeo.spec_of(p_id)
	if sp.is_empty():
		return { "base_r_mm": 5.25, "length_mm": 35.0, "curve": 0.85, "arc_deg": 90.0 }
	return { "base_r_mm": float(sp.base_r_mm), "length_mm": float(sp.length_mm), "curve": float(sp.curve), "arc_deg": float(sp.arc_deg) }


# ════════ Las patas ════════

## Una pata de la cetrería doblada para el coche (de la caché): las mallas y los materiales de sus partes, sus garras
## (slots: el marco de la base de cada una; protract: el de la garra recogida del tigre), el anclaje y su caja (m, en el
## marco de la pata: el origen en el suelo bajo el pie, +X hacia los dedos, +Z hacia fuera en la derecha y hacia dentro en
## la izquierda).
func _paw(animal: String, art: String, cl: Dictionary, pw: String, pose: Dictionary, mobile: bool, cache: Dictionary) -> Dictionary:
	var hind := pw.begins_with("trasera")
	var side := 1.0 if pw.ends_with("derecha") else -1.0
	var deg := float(pose.get("hind_deg" if hind else "fore_deg", pose.get("fore_deg", 45.0)))
	var key := "pata4r|%s|%s|%s|%s|%s|%s" % [art, pw, var_to_str(deg), var_to_str(snappedf(float(cl.base_r_mm), 0.001)),
		var_to_str(snappedf(float(cl.length_mm), 0.01)), "movil" if mobile else "escritorio"]
	if cache.has(key):
		var hit: Dictionary = (cache[key] as Dictionary).duplicate()
		hit["fresh"] = false
		return hit
	var spec: Dictionary
	var s := 1.0
	var pivot := Vector2.ZERO
	var behind := -INF
	match animal:
		"tigre", "oso":
			var d: Dictionary = CarePaw.TIGER if animal == "tigre" else CarePaw.BEAR
			spec = CarePaw._felid(cl, side, hind, "lo", mobile, d, animal == "tigre")
			# la muñeca (o el tobillo): donde acaba el antebrazo (o la pierna) de la pata de la cetrería
			s = float(cl.base_r_mm) / float(d.base_ref)
			var dors: Array = d.dorsum
			pivot = Vector2(-14.0 - 0.55 * float(dors[0]), 1.3 * float(dors[1])) * CarePaw.MM * s
		"velociraptor":
			spec = CarePaw._theropod(art, cl, side, "lo", mobile)
			s = float(cl.base_r_mm) / CarePaw.DINO_BASE_REF
			pivot = Vector2(6.0, 15.0) * CarePaw.MM * s
			behind = -80.0 * CarePaw.MM * s
		_:
			spec = CarePaw._raptor(art, cl, side, "lo", mobile)
			var r: Dictionary = CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila)
			var t_r := float((r.tarsus as Array)[1]) * float(cl.base_r_mm) * CarePaw.MM
			var t_len := float((r.tarsus as Array)[0]) * float(cl.length_mm) * CarePaw.MM
			pivot = Vector2(0.0, t_r)
			behind = -0.6 * t_len
	var angle := -deg_to_rad(deg)
	var blend := BEND_BLEND * s
	var parts := {}
	var box := AABB()
	var first := true
	var n_verts := 0
	for part: String in spec.parts:
		var arrays: Array = bend(spec.parts[part].arrays as Array, pivot, angle, blend, behind)
		if not CareKit.has_triangles(arrays):
			continue
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		parts[part] = { "mesh": am, "mat": CarePaw._material(String(spec.parts[part].mat), art, animal, "lo", mobile, cache) }
		n_verts += CareKit.vertex_count(arrays)
		var b := am.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var turn := pivot_xf(pivot, angle)
	var mcs: Array = []
	for mc: Dictionary in spec.get("model_claws", []):
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mc.arrays)
		mcs.append({ "mesh": am, "xf": mc.xf })
	var out := { "parts": parts, "slots": spec.slots, "protract": spec.get("protract", {}), "model_claws": mcs, "anchor": turn * (spec.anchor as Transform3D),
		"aabb": box, "verts": n_verts, "fresh": true, "xf": Transform3D.IDENTITY }
	cache[key] = out
	var copy := out.duplicate()
	return copy


## Dónde va cada pata en el suelo (marco del coche, m de la cetrería): el tigre y el oso, los codos y las rodillas a lo largo
## del cuerpo (como en la mesa de la cetrería) con las manos y los pies bajo ellos, a los dos lados; la rapaz y el
## velocirraptor, los dos pies juntos, uno a cada lado.
func _place_paws(paws: Dictionary, pose: Dictionary, _height: float) -> void:
	var natural := CareAnatomy.draw_length_m(id)
	if kind == "mamifero":
		var half := float(HALF_TRACK.get(id, 0.12))
		var spread := ELBOWS_M_PER_M * natural * float(pose.get("reach_k", 1.0))
		for pw: String in paws:
			var e: Dictionary = paws[pw]
			var hind := pw.begins_with("trasera")
			var side := 1.0 if pw.ends_with("derecha") else -1.0
			# el codo (o la rodilla) en su sitio a lo largo del cuerpo: la pata, debajo
			var want := -spread * 0.5 if hind else spread * 0.5
			var ax := (e.anchor as Transform3D).origin.x
			e["xf"] = Transform3D(Basis.IDENTITY, Vector3(want - ax, 0.0, side * half))
		return
	var half_feet := float(FEET_K.get(kind, 0.05)) * natural
	for pw: String in paws:
		var e: Dictionary = paws[pw]
		var side := 1.0 if pw.ends_with("derecha") else -1.0
		var ax := (e.anchor as Transform3D).origin.x
		# el talón sobre el punto de apoyo (el origen): el pie, delante
		e["xf"] = Transform3D(Basis.IDENTITY, Vector3(-ax * 0.5, 0.0, side * half_feet))


## Los nodos de una pata: sus mallas, las garras de dibujo (las del velocirraptor que no se trabajan) y una garra de la
## biblioteca en cada dedo (en dos trozos: la base y la punta, que se mella o se dobla).
func _paw_nodes(e: Dictionary, pw: String) -> void:
	var node := Node3D.new()
	node.name = "Pata_" + pw
	_paw_list.append([node, (e.xf as Transform3D)])
	node.transform = e.xf
	_offset.add_child(node)
	for part: String in e.parts:
		var p: Dictionary = e.parts[part]
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = p.mesh
		mi.material_override = p.mat
		node.add_child(mi)
	meshes_built += 1 if bool(e.get("fresh", false)) else 0
	verts += int(e.get("verts", 0))
	for mc: Dictionary in e.model_claws:
		var mi := MeshInstance3D.new()
		mi.name = "GarraDibujo"
		mi.mesh = mc.mesh
		mi.transform = mc.xf
		node.add_child(mi)
		_claw_slots.append(mi)
	var cl := _claw_spec(id)
	var prot: Dictionary = e.protract
	for d: String in e.slots:
		var k := float(RAPTOR_CLAW_K.get(d, 1.0)) if kind == "ave" else 1.0
		var length := float(cl.length_mm) * k
		var mc := _claw_meshes(length, float(cl.base_r_mm) * k, float(cl.arc_deg), _claw_quality == "movil", _cache)
		var base := Node3D.new()
		base.name = "Garra_" + d
		base.transform = e.slots[d]
		node.add_child(base)
		var mb := MeshInstance3D.new()
		mb.name = "Base"
		mb.mesh = mc.base
		mb.scale = Vector3.ONE * 0.001
		base.add_child(mb)
		var tip := Node3D.new()
		tip.name = "Punta"
		tip.position = (mc.cut_point as Vector3) * 0.001
		base.add_child(tip)
		var mt := MeshInstance3D.new()
		mt.name = "Malla"
		mt.mesh = mc.tip
		mt.scale = Vector3.ONE * 0.001
		mt.position = -(mc.cut_point as Vector3) * 0.001
		tip.add_child(mt)
		_claw_slots.append(mb)
		_claw_slots.append(mt)
		var chip := _chip_face(length, float(cl.base_r_mm) * k, float(cl.arc_deg), mc.cut_point as Vector3)
		mb.add_child(chip)
		claws.append({ "node": base, "tip": tip, "out": e.slots[d], "in": prot.get(d, e.slots[d]), "tip_m": (mc.tip_point as Vector3) * 0.001,
			"cut_m": (mc.cut_point as Vector3) * 0.001, "meshes": [mb, mt], "paw": pw, "digit": d, "chip": chip })


## Unidad 4s (lo que daba mala imagen: «la garra mellada se distingue poco»): la cara de la rotura de una garra mellada, en
## el corte (cut, mm, en el marco de la base): un disco claro, la queratina o el material recién partido (dibujo), de la
## sección de la garra ahí (la de model_claw: base_h × base_w con su ahusado), a lo largo de su tangente. Escondido hasta
## que se mella.
const CHIP_COLOR := Color(0.93, 0.89, 0.8)
static var _chip_mat: StandardMaterial3D = null
static var _chip_mesh: CylinderMesh = null


static func _chip_face(length_mm: float, base_r_mm: float, arc_deg: float, cut: Vector3) -> MeshInstance3D:
	if _chip_mesh == null:
		_chip_mesh = CylinderMesh.new()
		_chip_mesh.top_radius = 1.0
		_chip_mesh.bottom_radius = 1.0
		_chip_mesh.height = 1.0
		_chip_mesh.radial_segments = 10
		_chip_mesh.rings = 1
		_chip_mat = StandardMaterial3D.new()
		_chip_mat.albedo_color = CHIP_COLOR
		_chip_mat.roughness = 0.55
		_chip_mat.emission_enabled = true
		_chip_mat.emission = CHIP_COLOR * 0.25
	var L := maxf(length_mm, 0.1)
	var kk := deg_to_rad(arc_deg) / L
	var sc := L * CLAW_CUT
	var t := Vector3(cos(kk * sc), -sin(kk * sc), 0.0)
	var f := pow(maxf(1.0 - CLAW_CUT, 0.0), ClawGeo.TAPER_EXP)
	var rh := base_r_mm * 2.3 * 0.5 * f
	var rw := base_r_mm * 1.75 * 0.5 * f
	var y := t.normalized()
	var z := Vector3(0.0, 0.0, 1.0)
	var x := y.cross(z).normalized()
	var mi := MeshInstance3D.new()
	mi.name = "Rotura"
	mi.mesh = _chip_mesh
	mi.material_override = _chip_mat
	mi.transform = Transform3D(Basis(x * rh * 1.08, y * 0.35, z * rw * 1.08), cut)
	mi.visible = false
	return mi


## Las mallas de una garra (ClawGeo.model_claw, de la caché por largo, base, arco y calidad; mm, en el marco de su base): la
## base y la punta.
static func _claw_meshes(length_mm: float, base_r_mm: float, arc_deg: float, mobile: bool, cache: Dictionary) -> Dictionary:
	var key := "garra4r|%s|%s|%s|%s" % [var_to_str(snappedf(length_mm, 0.01)), var_to_str(snappedf(base_r_mm, 0.001)), var_to_str(snappedf(arc_deg, 0.01)), mobile]
	if cache.has(key):
		return cache[key]
	# unidad 4w: en el escritorio, más vueltas y tramos (32 × 30): en «Garras de cerca» del coche, a ~50 aumentos, la garra se
	# veía de pocos polígonos
	var ring := ClawGeo.RING_MOBILE if mobile else CLAW_RING_NEAR
	var mc := ClawGeo.model_claw(length_mm, base_r_mm * 2.3, base_r_mm * 1.75, arc_deg, 4 if mobile else 10, 6 if mobile else 20, ring, CLAW_CUT)
	var mb := ArrayMesh.new()
	mb.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mc.base)
	var mt := ArrayMesh.new()
	mt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mc.tip)
	var out := { "base": mb, "tip": mt, "cut_point": mc.cut_point, "tip_point": mc.tip_point }
	cache[key] = out
	return out


## Gira (alrededor del eje z que pasa por pivot, en el plano XY de la pata) la parte de la malla que queda detrás de pivot.x:
## angle (rad; negativo: sube) entero a más de blend por detrás, nada a más de blend por delante y una transición suave en
## medio; las normales giran con ella. Solo en las piezas sueltas de la malla que llegan más atrás que behind (m): el tarso
## o el metatarso, y no el dedo de atrás que va por debajo. Devuelve una copia (los arrays de care_kit.gd).
static func bend(arrays: Array, pivot: Vector2, angle: float, blend: float, behind := -INF) -> Array:
	if not CareKit.has_triangles(arrays) or is_zero_approx(angle):
		return arrays
	var v: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var eligible := PackedByteArray()
	eligible.resize(v.size())
	eligible.fill(1)
	if is_finite(behind):
		var comp := components(v.size(), arrays[Mesh.ARRAY_INDEX] as PackedInt32Array)
		var min_x := {}
		for i in v.size():
			var c := comp[i]
			min_x[c] = minf(float(min_x.get(c, INF)), v[i].x)
		for i in v.size():
			eligible[i] = 1 if float(min_x[comp[i]]) < behind else 0
	for i in v.size():
		if eligible[i] == 0:
			continue
		var x := v[i].x
		var w := 1.0 if x <= pivot.x - blend else (0.0 if x >= pivot.x + blend else smoothstep(0.0, 1.0, (pivot.x + blend - x) / (2.0 * blend)))
		if w <= 0.0:
			continue
		var a := angle * w
		var c := cos(a)
		var s := sin(a)
		var dx := v[i].x - pivot.x
		var dy := v[i].y - pivot.y
		v[i] = Vector3(pivot.x + dx * c - dy * s, pivot.y + dx * s + dy * c, v[i].z)
		var nx := n[i].x
		var ny := n[i].y
		n[i] = Vector3(nx * c - ny * s, nx * s + ny * c, n[i].z)
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = n
	return out


## La pieza suelta (componente conexa por los triángulos) de cada vértice: unión y búsqueda con los índices.
static func components(count: int, idx: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array()
	parent.resize(count)
	for i in count:
		parent[i] = i
	for t in range(0, idx.size(), 3):
		var a := _find(parent, idx[t])
		for k in range(1, 3):
			var b := _find(parent, idx[t + k])
			if a != b:
				parent[b] = a
	for i in count:
		parent[i] = _find(parent, i)
	return parent


static func _find(parent: PackedInt32Array, i: int) -> int:
	var r := i
	while parent[r] != r:
		r = parent[r]
	# acorta el camino
	var j := i
	while parent[j] != r:
		var nxt := parent[j]
		parent[j] = r
		j = nxt
	return r


## El giro de la pata alrededor del eje z que pasa por pivot (lo que se lleva el anclaje del final del antebrazo o del tarso).
static func pivot_xf(pivot: Vector2, angle: float) -> Transform3D:
	var p := Vector3(pivot.x, pivot.y, 0.0)
	return Transform3D(Basis(Vector3.BACK, angle), p) * Transform3D(Basis.IDENTITY, -p)


## El pelo del cuerpo para verse de lejos (ROOT_TO_TIP y TONE_VAR): en los materiales de la caché de la vista (los del coche,
## no los de la cetrería), una vez por material.
static func _far_fur(holder: Node3D) -> void:
	if holder == null:
		return
	for n: Node in holder.find_children("*", "GeometryInstance3D", true, false):
		var m := (n as GeometryInstance3D).material_override as ShaderMaterial
		if m == null or m.shader != CareBody.FUR_SHADER or m.has_meta("lejos_4r"):
			continue
		m.set_meta("lejos_4r", true)
		var root_c: Variant = m.get_shader_parameter("root_color")
		var tip_c: Variant = m.get_shader_parameter("tip_color")
		# unidad 4s: lo de la cetrería se guarda para el pelo de cerca (set_near_fur)
		m.set_meta("cerca_4s", { "root_color": root_c, "tone_var": m.get_shader_parameter("tone_var"),
			"strand_mm": m.get_shader_parameter("strand_mm"), "clump_mm": m.get_shader_parameter("clump_mm") })
		if root_c is Color and tip_c is Color:
			m.set_shader_parameter("root_color", (root_c as Color).lerp(tip_c as Color, ROOT_TO_TIP))
		m.set_meta("lejos_4s", { "root_color": m.get_shader_parameter("root_color"), "tone_var": TONE_VAR,
			"strand_mm": m.get_shader_parameter("strand_mm"), "clump_mm": m.get_shader_parameter("clump_mm") })
		m.set_shader_parameter("tone_var", TONE_VAR)


## Unidad 4s (lo que daba mala imagen: «el pelo de cerca parece un peluche»): con el primer plano en toda la vista, el pelo de
## la cetrería (sus raíces oscuras y su variación de tono) con mechones más finos (NEAR_STRAND veces); si no, el de lejos.
## Solo cambia parámetros de los materiales (los de la caché de la vista); nada se crea.
const NEAR_STRAND := 0.4


func set_near_fur(on: bool) -> void:
	if body.get("root") == null:
		return
	_near_fur = on
	for n: Node in (body.root as Node3D).find_children("*", "GeometryInstance3D", true, false):
		var m := (n as GeometryInstance3D).material_override as ShaderMaterial
		if m == null or not m.has_meta("cerca_4s"):
			continue
		var p: Dictionary = m.get_meta("cerca_4s" if on else "lejos_4s")
		for k: String in p:
			if p[k] != null:
				var v: Variant = p[k]
				if on and (k == "strand_mm" or k == "clump_mm"):
					v = float(v) * NEAR_STRAND
				m.set_shader_parameter(k, v)


## La caja (en el marco del coche) de una caja del marco de la cetrería.
static func _box_of(xf: Transform3D, b: AABB) -> AABB:
	var out := AABB(xf * b.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(xf * b.get_endpoint(i))
	return out


func _count_verts() -> void:
	var holder: Node = body.get("root")
	if holder == null:
		return
	for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			verts += m.surface_get_array_len(s)
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		_geoms.append(n)


# ════════ Cada fotograma ════════

## La pose del fotograma (la de Animal3D: t, live, alpha, claws_out, claw_len, claw_gone, claw_bend, lean; las demás
## claves se aceptan y no hacen nada: el cuerpo de la cetrería no abre las alas ni salta). Respira y parpadea con la
## sujeción «libre» de la cetrería. Solo mueve nodos y parámetros: nada se crea.
func pose(p: Dictionary) -> void:
	if kind == "":
		return
	set_alpha(float(p.get("alpha", 1.0)))
	_pose_claws(p)
	_lean.rotation = Vector3(0.0, 0.0, -float(p.get("lean", 0.0)))
	var live := bool(p.get("live", false))
	var t := float(p.get("t", 0.0)) if live else 0.0
	_pose_grip(p, t)
	if live or _breath_t < 0.0:
		_breath_t = t
		CareBody.animate(body, t, "libre", 0.0)
	_pose_curve(p)  # unidad 4u: se agarra en la curva


## Unidad 4s: la postura de agarre del tigre, el oso y el velocirraptor (se agazapa y agacha la cabeza con la carga, se
## balancea con el viento) y las patas que se agitan al soltarse. Solo mueve nodos.
func _pose_grip(p: Dictionary, t: float) -> void:
	if _holder == null or kind == "ave":
		return
	var load := clampf(maxf(float(p.get("bristle", 0.0)), float(p.get("scared", 0.0)) * 0.6), 0.0, 1.0)
	var wind := clampf(float(p.get("wind_local_ms", 0.0)) / 30.0, 0.0, 1.0)
	var crouch := clampf(0.6 * wind + 0.6 * load, 0.0, 1.0)
	var flail := clampf(float(p.get("flail", 0.0)), 0.0, 1.0)
	var sway := SWAY * wind * sin(t * TAU * SWAY_HZ) if bool(p.get("live", false)) else 0.0
	var key := "%s|%s|%s" % [snappedf(crouch, 0.01), snappedf(sway, 0.0005), snappedf(flail, 0.01) if flail <= 0.0 else t]
	if key == _grip_key:
		return
	_grip_key = key
	var down := Vector3(0.0, -CROUCH_K * _height_m * crouch, 0.0)
	_holder.transform = Transform3D(Basis(Vector3.RIGHT, sway), down) * _holder_rest
	var head: Node3D = body.get("head")
	if head != null:
		var rest: Transform3D = body.head_rest
		head.transform = rest.rotated_local(Vector3(0.0, 1.0, 0.0), HEAD_DOWN * crouch) if crouch > 0.01 else rest
	for k in _paw_list.size():
		var e: Array = _paw_list[k]
		var n: Node3D = e[0]
		var rest_xf: Transform3D = e[1]
		if flail <= 0.0:
			n.transform = rest_xf
			continue
		var ph := float(k) * 1.9
		var a := FLAIL * flail * (0.6 + 0.4 * sin(t * 9.0 + ph))
		var side := 1.0 if k % 2 == 0 else -1.0
		n.transform = rest_xf * Transform3D(Basis(Vector3.BACK, a * side * 0.7) * Basis(Vector3.RIGHT, a * side * 0.5), Vector3.ZERO)


## Las garras: fuera o recogidas (las del tigre, en su vaina), melladas (sin la punta), partidas (sin garra) o dobladas (la
## punta torcida).
func _pose_claws(p: Dictionary) -> void:
	var out := clampf(float(p.get("claws_out", 1.0)), 0.0, 1.0)
	var gone := bool(p.get("claw_gone", false))
	var keep := clampf(float(p.get("claw_len", 1.0)), 0.15, 1.0)
	var bend_on := float(p.get("claw_bend", 0.0)) > 0.5
	var key := "%s|%s|%s|%s" % [snappedf(out, 0.01), gone, snappedf(keep, 0.01), bend_on]
	if key == _claw_key:
		return
	_claw_key = key
	for c: Dictionary in claws:
		var n: Node3D = c.node
		n.visible = not gone
		n.transform = (c["in"] as Transform3D).interpolate_with(c.out as Transform3D, out)
		var chipped := keep < 0.97
		var tip: Node3D = c.tip
		tip.visible = not chipped
		(c.chip as Node3D).visible = chipped and not gone
		tip.rotation = Vector3(0.0, 0.0, -0.6 if bend_on else 0.0) if not bend_on else Vector3(0.9, 0.0, -0.6)
		var mb: MeshInstance3D = (c.meshes as Array)[0]
		mb.scale = Vector3.ONE * 0.001 * (clampf(keep / CLAW_CUT, 0.3, 1.0) if chipped else 1.0)


## Opacidad de todo el animal: los materiales de la cetrería no se desvanecen, así que por debajo de 1 se usa la
## transparencia de cada malla (Forward+ y Mobile; en Compatibility no se ve: solo se esconde al final).
func set_alpha(a: float) -> void:
	a = clampf(a, 0.0, 1.0)
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	root.visible = a > 0.003
	for g: GeometryInstance3D in _geoms:
		g.transparency = 1.0 - a
	if claw_mat != null:
		claw_mat.set_shader_parameter("claw_fade", a)


## Material de las garras, de la biblioteca (como Animal3D.set_claws): la queratina con el color natural de la especie o el
## material reforjado (un id de claw_optics.gd) con su color, su brillo y su luz reales; una copia por animal.
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
	for mi: MeshInstance3D in _claw_slots:
		mi.material_override = claw_mat


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
		out.append(xf * ((c.tip_m as Vector3) - (c.cut_m as Vector3)))
	return out


## Unidad 4s: de qué pata y qué dedo es cada garra, en el orden de claw_points(): [[pata, dedo]].
func claw_tags() -> Array:
	var out: Array = []
	for c: Dictionary in claws:
		out.append([String(c.get("paw", "")), String(c.get("digit", ""))])
	return out


## Libera los nodos.
func free_nodes() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()


# ════════ Agarre en curva (unidad 4u) ════════
# Dibujo: en curva el animal lucha por no soltarse con su miedo (pose.curve_fear, de -1 a 1: el signo es el lado al que
# empuja la curva, +1 hacia la derecha del coche, +z; el valor, CarCurveGrip.fear: 0 tranquilo, 1 a punto de soltarse,
# suavizado por la vista para que no salte). Cada especie a su manera, con el cuerpo girado hacia dentro de la curva y las
# patas de fuera estiradas, clavando las garras:
#   - el tigre: la barriga al techo, los hombros encogidos, las patas de fuera abiertas hacia el borde, la cabeza baja y la
#     cola dando latigazos de contrapeso;
#   - el oso: aplastado y abierto de patas, abrazado al techo, girando entero, con la cabeza metida;
#   - el velocirraptor: agazapado, girado con la cola de contrapeso (la cola va en el tronco: gira el cuerpo entero);
#   - las rapaces y la lechuza: el cuerpo bajo, las dos alas medio abiertas e inclinadas contra la fuerza (aletean con mucho
#     miedo) y la cola abierta.
# Siempre con vida en curva (respira, corrige el equilibrio y gira la cabeza); con mucho miedo, un temblor rápido y las patas
# de fuera que se recolocan a zarpazos cortos (con pose.curve_regrip, cuando resbala una garra de verdad). En la S, el miedo
# cambia de signo: el cuerpo pasa al otro lado y las patas cambian de papel. Solo mueve nodos: nada se crea en cada fotograma
# (el ala izquierda de la rapaz, espejo de la derecha, se hace una vez al construirla).

## Por especie (o por tipo): lo que se agacha el cuerpo (fracción del alto), lo que gira hacia dentro (rad, en el eje del coche),
## lo que gira sobre sí mismo hacia dentro con la cola fuera (rad), lo que se desplaza hacia dentro (fracción del alto), lo que
## baja la cabeza (rad), lo que abren las patas de fuera y las de dentro (rad), lo que mueve la cola (rad) y lo que abren las
## alas (rad). Dibujo.
const CURVE_POSE := {
	"tigre": { "crouch": 0.28, "roll": 0.5, "yaw": 0.12, "shift": 0.04, "head": 0.5, "out": 0.05, "in": 0.0, "tail": 0.7 },
	"oso": { "crouch": 0.36, "roll": 0.4, "yaw": 0.08, "shift": 0.03, "head": 0.6, "out": 0.12, "in": 0.1, "tail": 0.25 },
	"teropodo": { "crouch": 0.36, "roll": 0.45, "yaw": 0.4, "shift": 0.04, "head": 0.3, "out": 0.05, "in": 0.0, "tail": 0.0 },
	"ave": { "crouch": 0.14, "roll": 0.3, "yaw": 0.05, "shift": 0.0, "head": 0.25, "out": 0.0, "in": 0.0, "tail": 0.45, "wing": 1.5 },
}
## La vida (dibujo): el balanceo de corrección (rad) y su ritmo (Hz), lo que gira la cabeza mirando (rad), el temblor con mucho
## miedo (m por m de alto y su ritmo), desde qué miedo tiembla y escarba, y lo que se levanta una pata al escarbar (fracción del
## alto) y a qué ritmo (Hz).
const CURVE_SWAY := 0.035
const CURVE_SWAY_HZ := 0.45
const CURVE_LOOK := 0.35
const CURVE_TREMOR := 0.01
const CURVE_TREMOR_HZ := 7.5
const CURVE_PANIC_FROM := 0.55
const CURVE_SCRABBLE := 0.07
const CURVE_SCRABBLE_HZ := 2.2

var _curve_on := false
var _wing_l: Node3D
var _wing_l_p: Node3D


## Al construirla: el ala izquierda de la rapaz, espejo de la derecha (el cuerpo de la cetrería solo lleva entera la de arriba),
## en su pivote; solo si el cuerpo trae el ala en su pivote (pose.rig). anchors_l: los anclajes de las patas en el marco de la
## cetrería (el espejo pasa por el medio de los dos pies).
func _curve_rig(anchors_l: Dictionary) -> void:
	var pv: Dictionary = body.get("pivots", {})
	if kind != "ave" or not pv.has("wing"):
		return
	var y_mid := 0.0
	var n := 0
	for k: String in anchors_l:
		y_mid += (anchors_l[k] as Transform3D).origin.y
		n += 1
	y_mid /= float(maxi(n, 1))
	var mirror := Node3D.new()
	mirror.name = "AlaIzquierdaEspejo"
	mirror.transform = Transform3D(Basis.from_scale(Vector3(1.0, -1.0, 1.0)), Vector3(0.0, 2.0 * y_mid, 0.0))
	(body.root as Node3D).add_child(mirror)
	_wing_l = Node3D.new()
	_wing_l.name = "AlaIzquierda"
	mirror.add_child(_wing_l)
	_copy_meshes(pv.wing as Node3D, _wing_l, pv.get("wing_p"))
	if pv.has("wing_p"):
		_wing_l_p = Node3D.new()
		_wing_l_p.name = "AlaIzquierdaPrimarias"
		_wing_l.add_child(_wing_l_p)
		_copy_meshes(pv.wing_p as Node3D, _wing_l_p, null)


static func _copy_meshes(from: Node3D, to: Node3D, skip: Variant) -> void:
	for c: Node in from.get_children():
		if c == skip:
			continue
		if c is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.name = c.name
			mi.mesh = (c as MeshInstance3D).mesh
			mi.material_override = (c as MeshInstance3D).material_override
			mi.cast_shadow = (c as MeshInstance3D).cast_shadow
			mi.layers = (c as MeshInstance3D).layers
			to.add_child(mi)


## Un giro de ang (rad) alrededor del eje axis que pasa por pivot (en el marco del nodo padre).
static func _about(pivot: Vector3, axis: Vector3, ang: float) -> Transform3D:
	var b := Basis(axis.normalized(), ang)
	return Transform3D(b, pivot - b * pivot)


func _pose_curve(p: Dictionary) -> void:
	if _holder == null:
		return
	var on := bool(p.get("curve_on", false))
	if not on:
		if _curve_on:
			_curve_on = false
			_curve_rest()
		return
	_curve_on = true
	var pf := clampf(float(p.get("curve_fear", 0.0)), -1.0, 1.0)
	var f := absf(pf)
	var s := 1.0 if pf >= 0.0 else -1.0
	var live := bool(p.get("live", false))
	var t := float(p.get("t", 0.0)) if live else 0.0
	var flail := clampf(float(p.get("flail", 0.0)), 0.0, 1.0)
	var regrip := clampf(float(p.get("curve_regrip", 0.0)), 0.0, 1.0)
	var c: Dictionary = CURVE_POSE.get(id, CURVE_POSE.get(kind, CURVE_POSE.ave))
	var h := _height_m
	var panic := clampf((f - CURVE_PANIC_FROM) / (1.0 - CURVE_PANIC_FROM), 0.0, 1.0)
	# la vida: el balanceo de corrección (más suave con miedo: se queda pegado) y el temblor con mucho miedo
	var sway := CURVE_SWAY * (1.0 - 0.6 * f) * (sin(t * TAU * CURVE_SWAY_HZ) + 0.5 * sin(t * TAU * CURVE_SWAY_HZ * 2.3 + 1.1))
	var trem := CURVE_TREMOR * h * panic * sin(t * TAU * CURVE_TREMOR_HZ * 6.3)
	# lo que pone la 4s con la carga y el viento (se agazapa): aquí se suma
	var load := clampf(maxf(float(p.get("bristle", 0.0)), float(p.get("scared", 0.0)) * 0.6), 0.0, 1.0)
	var wind := clampf(float(p.get("wind_local_ms", 0.0)) / 30.0, 0.0, 1.0)
	var crouch4s := CROUCH_K * h * clampf(0.6 * wind + 0.6 * load, 0.0, 1.0) if kind != "ave" else 0.0
	var down := crouch4s + float(c.crouch) * h * f * (1.0 - 0.6 * flail)
	var roll := -s * float(c.roll) * f + sway
	var yaw := -s * float(c.yaw) * f
	var shift := -s * float(c.shift) * h * f
	_holder.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, roll), Vector3(0.0, -down + trem, shift + trem * 0.5)) * _holder_rest
	# la cabeza: baja con el miedo y mira a los lados cuando está tranquila
	var head: Node3D = body.get("head")
	if head != null:
		var look := CURVE_LOOK * (1.0 - f) * sin(t * TAU * 0.13 + 0.7) + (-s * 0.25 * f)
		var rest: Transform3D = body.head_rest
		head.transform = rest.rotated_local(Vector3(0.0, 0.0, 1.0), -float(c.head) * f).rotated_local(Vector3(0.0, 1.0, 0.0), look)
	# las patas: las de fuera se abren hacia el borde y escarban con mucho miedo; las de dentro, menos
	if flail <= 0.0:
		for k in _paw_list.size():
			var pe: Array = _paw_list[k]
			var n: Node3D = pe[0]
			var rest_xf: Transform3D = pe[1]
			var side := 1.0 if String(n.name).ends_with("derecha") else -1.0
			var outer := side == s
			var spread := (float(c.out) if outer else float(c.get("in", 0.0))) * f
			var up := 0.0
			if outer:
				var ph := float(k) * 1.7
				up = CURVE_SCRABBLE * h * panic * pow(maxf(0.0, sin(t * TAU * CURVE_SCRABBLE_HZ + ph)), 6.0)
				up += CURVE_SCRABBLE * h * sin(regrip * PI)
			# la pata se inclina con el cuerpo alrededor de su pie (que se queda en el techo): así sigue unida a su brazo
			var tilt := Basis(Vector3.UP, yaw * 0.5) * Basis(Vector3.RIGHT, roll)
			var own := rest_xf * Transform3D(Basis(Vector3.RIGHT, -side * spread), Vector3(0.0, up, 0.0))
			n.transform = Transform3D(tilt * own.basis, own.origin)
	# la cola: latigazos de contrapeso hacia dentro (el tigre y el oso); la rapaz la abre y la inclina contra la fuerza
	var pv: Dictionary = body.get("pivots", {})
	var rg: Dictionary = body.get("rig", {})
	if pv.has("tail") and rg.has("tail"):
		var ts: Dictionary = rg.tail
		var lash := float(c.tail) * ((0.35 + 0.65 * f) * sin(t * TAU * (0.6 + 1.4 * f)) + s * 0.6 * f)
		var axis := Vector3(1.0, 0.0, 0.0)
		if kind == "ave":
			axis = (ts.get("axis", Vector3.UP) as Vector3)
		(pv.tail as Node3D).transform = _about(ts.pivot as Vector3, axis, lash)
	# las alas de la rapaz: medio abiertas e inclinadas contra la fuerza, aleteando con mucho miedo
	if kind == "ave" and pv.has("wing") and rg.has("wing"):
		var ws: Dictionary = rg.wing
		# al soltarse (pose.curve_fly, de la vista) intenta despegar: aletea entero y más deprisa
		var fly := clampf(float(p.get("curve_fly", 0.0)), 0.0, 1.0)
		var flap := (0.45 * panic + 0.5 * fly) * sin(t * TAU * (3.2 + 2.0 * fly))
		var open := float(c.get("wing", 1.0)) * (0.15 + 0.85 * f) * f + flap
		var tilt := 0.25 * s * f
		var w_r := clampf(open + tilt, 0.0, 1.6)
		var w_l := clampf(open - tilt, 0.0, 1.6)
		var sgn := -float(_wing_sign(ws))
		(pv.wing as Node3D).transform = _about(ws.pivot as Vector3, ws.axis as Vector3, sgn * w_r)
		if _wing_l != null:
			_wing_l.transform = _about(ws.pivot as Vector3, ws.axis as Vector3, sgn * w_l)
		if pv.has("wing_p") and rg.has("wing_p"):
			var wp: Dictionary = rg.wing_p
			var fan := 0.6 * f + flap * 0.5
			var sp := -1.0
			(pv.wing_p as Node3D).transform = _about(wp.pivot as Vector3, wp.axis as Vector3, sp * fan)
			if _wing_l_p != null:
				_wing_l_p.transform = _about(wp.pivot as Vector3, wp.axis as Vector3, sp * fan)


## El sentido en que el ala se levanta del flanco (hacia su normal): el signo del giro que aparta su borde del cuerpo.
static func _wing_sign(ws: Dictionary) -> float:
	var axis := (ws.axis as Vector3).normalized()
	var nrm := (ws.get("normal", Vector3.UP) as Vector3).normalized()
	# un punto del ala hacia atrás del hombro, girado un poco: ¿sube hacia la normal?
	var arm := axis.cross(nrm).normalized()
	var turned := Basis(axis, 0.3) * arm
	return 1.0 if turned.dot(nrm) > arm.dot(nrm) else -1.0


## Vuelve todo a su sitio (al acabar la curva).
func _curve_rest() -> void:
	_holder.transform = _holder_rest
	_grip_key = ""
	var head: Node3D = body.get("head")
	if head != null:
		head.transform = body.head_rest
	for pe: Array in _paw_list:
		(pe[0] as Node3D).transform = pe[1]
	var pv: Dictionary = body.get("pivots", {})
	for k: String in ["tail", "wing", "wing_p"]:
		if pv.has(k):
			(pv[k] as Node3D).transform = Transform3D.IDENTITY
	if _wing_l != null:
		_wing_l.transform = Transform3D.IDENTITY
	if _wing_l_p != null:
		_wing_l_p.transform = Transform3D.IDENTITY


# ════════ Luz del sol (unidad 4w) ════════

## La luz del coche ha cambiado (ClawMaterial.road_light): sus copias de la carretera la toman.
func relight_claws() -> void:
	if _claw_env != "carretera":
		return
	for k: String in _claw_copies:
		ClawMaterial.apply_road_light(_claw_copies[k])
