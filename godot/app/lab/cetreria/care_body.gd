## Cetrería · el cuerpo de cada animal tumbado en la mesa, en alta definición (unidad 5i, petición 37): hecho en código desde
## cero para la cetrería e independiente de los modelos del coche en marcha, a su tamaño (core/lab/care_anatomy.gd), y
## enganchado a las patas de la 5h por sus anclajes (anchors: el talón de la rapaz y del velocirraptor, el codo o la
## rodilla del tigre y del oso; el miembro del cuerpo llega al anclaje por −X y lo pasa un poco, para tapar la juntura).
## Solo dibujo. Cada animal en su archivo (todos puros: arrays y transformaciones, se pueden hacer en un hilo):
##   - las rapaces (body_bird.gd), con las plumas en capas, la toalla, la capucha y la mascarilla (body_props.gd);
##   - el tigre y el oso, con el pelo con volumen y las rayas, y la mascarilla y la pinza del pulsioxímetro;
##   - los dos velocirraptores (body_dino.gd), con plumas y escamas (la reconstrucción) o solo escamas (el de película),
##     con la mascarilla y la pinza como los grandes.
## Aquí se hacen los recursos una vez por animal, dibujo, calidad y sitio de las patas (las mallas, las capas del pelo en un
## MultiMesh y los materiales, en la caché de la escena), los nodos de cada construcción y lo que se mueve en cada
## fotograma (animate): la respiración lenta (un parámetro de los sombreadores: solo se hincha el tronco), los párpados (se
## cierran con la sedación y parpadean despierto), el respingo con dolor de la cabeza y la pupila que se dilata con la
## anestesia. En cada fotograma no se crea nada (con su test).
extends RefCounted

const BodyKit = preload("res://app/lab/cetreria/body_kit.gd")
const BodyBird = preload("res://app/lab/cetreria/body_bird.gd")
const BodyMammal = preload("res://app/lab/cetreria/body_mammal.gd")
const BodyDino = preload("res://app/lab/cetreria/body_dino.gd")
const BodyProps = preload("res://app/lab/cetreria/body_props.gd")
const FUR_SHADER = preload("res://app/lab/cetreria/body_fur.gdshader")
const FEATHER_SHADER = preload("res://app/lab/cetreria/body_feather.gdshader")
const PLUMAGE_SHADER = preload("res://app/lab/cetreria/body_plumage.gdshader")
const SKIN_SHADER = preload("res://app/lab/cetreria/body_skin.gdshader")
const EYE_SHADER = preload("res://app/lab/cetreria/body_eye.gdshader")
const LEATHER_SHADER = preload("res://app/lab/cetreria/body_leather.gdshader")
const CLOTH_SHADER = preload("res://app/lab/cetreria/care_cloth.gdshader")

## Capas del pelo de cada calidad (el MultiMesh de las conchas) y cuánto se dibuja el pelo en mechones.
const FUR_LAYERS := { "escritorio": 22, "movil": 6 }
## Respiración de cada sujeción (Hz): dormido, despacio (dibujo).
const BREATH_HZ := { "anestesia": 0.22, "sedacion": 0.3, "sujecion": 0.55, "libre": 0.6 }
## Cuánto se abren los ojos con cada sujeción (0 cerrados, 1 abiertos; dibujo) y lo que tardan en llegar (s).
const EYE_OPEN := { "libre": 1.0, "sujecion": 0.8, "sedacion": 0.28, "anestesia": 0.0 }
const EYE_TAU := 0.35
## Lo que se giran los párpados para abrir del todo (°): [el de arriba, el de abajo]. En las aves cierra el de abajo; en
## los mamíferos, el de arriba.
const LID_OPEN_DEG := { "ave": [38.0, 66.0], "mamifero": [44.0, 16.0], "teropodo": [34.0, 56.0] }
## Cada cuánto parpadea despierto (s) y lo que dura el parpadeo (s).
const BLINK_EVERY := 4.3
const BLINK_S := 0.16


static func kind_of(animal: String) -> String:
	match animal:
		"tigre", "oso":
			return "mamifero"
		"velociraptor":
			return "teropodo"
	return "ave"


## Construye el cuerpo. anchors: { pata: Transform3D (en la raíz) }; opts: { mobile, cache, claw ({ base_r_mm, length_mm }) }.
## Unidad 4r (el coche en marcha; sin ellas, la cetrería de siempre): pose (la de body_*.gd: de pie o agazapado, no tumbado),
## props (false: sin la tela de debajo, la toalla, la capucha, la mascarilla ni el pulsioxímetro) y fur_layers (las capas
## del pelo, si no son las de su calidad).
## → { root, head (Node3D), props: { wrap, hood, mask, clip }, under (MeshInstance3D: la tela de debajo, PlaneMesh), box
##     (AABB), fresh (si se han hecho los recursos), kind, lids, eyes, breath_mats, … (lo que mueve animate) }
static func build(parent: Node3D, animal: String, art: String, anchors: Dictionary, opts := {}) -> Dictionary:
	var kind := kind_of(animal)
	var mobile := bool(opts.get("mobile", false))
	var cache: Dictionary = opts.get("cache", {})
	var claw: Dictionary = opts.get("claw", { "base_r_mm": 5.25, "length_mm": 35.0 })
	var pose: Dictionary = opts.get("pose", {})
	var layers := int(opts.get("fur_layers", 0))
	var q := "movil" if mobile else "escritorio"
	var key := "cuerpo5i|%s|%s|%s|%s" % [art, q, _anchors_key(anchors), var_to_str(snappedf(float(claw.get("base_r_mm", 0.0)), 0.001))]
	if not pose.is_empty() or layers > 0:
		key += "|4r|%s|%d" % [var_to_str(pose), layers]
	var fresh := not cache.has(key)
	var res: Dictionary
	if fresh:
		res = _resources(_model(kind, art, anchors, claw, mobile, pose), mobile, layers)
		cache[key] = res
	else:
		res = cache[key]
	var root := Node3D.new()
	root.name = "Cuerpo"
	parent.add_child(root)
	var nodes := { "": root }
	_make_nodes(res.nodes as Dictionary, nodes)
	var mats := _materials(kind, art, mobile, cache)
	# el dibujo de la cara del tigre va con el ojo de su cabeza y, desde la 5n, con el escalón de la frente y la comisura de
	# la boca (los mismos en cada construcción: no dependen de las patas)
	var eq: Variant = (res.layout as Dictionary).get("eye_q")
	var fq: Variant = (res.layout as Dictionary).get("face_q")
	for id: String in ["fur_head", "fur_head_capas"]:
		if mats.has(id):
			if eq is Vector3:
				(mats[id] as ShaderMaterial).set_shader_parameter("eye_at", eq)
			if fq is Vector3:
				(mats[id] as ShaderMaterial).set_shader_parameter("face_at", fq)
	var breath_mats: Array = []
	for id: String in mats:
		var m: Material = mats[id]
		if m is ShaderMaterial and (m as ShaderMaterial).shader in [FUR_SHADER, FEATHER_SHADER, PLUMAGE_SHADER, SKIN_SHADER]:
			breath_mats.append(m)
	for part: String in res.parts:
		var e: Dictionary = res.parts[part]
		var holder: Node3D = nodes.get(String(e.node), root)
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = e.mesh
		mi.material_override = mats.get(String(e.mat))
		if String(e.mat) in ["feather", "plumage_head", "lid", "nict", "mouth"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		if e.get("shells") != null:
			var mmi := MultiMeshInstance3D.new()
			mmi.name = part + "_pelo"
			mmi.multimesh = e.shells
			mmi.material_override = mats.get(String(e.get("shell_mat", String(e.mat) + "_capas")))
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mmi)
	var out := { "root": root, "head": nodes.get("head"), "kind": kind, "animal": animal, "art": art, "box": res.box, "fresh": fresh,
		"breath_mats": breath_mats, "eye_mat": mats.get("eye"), "open": -1.0, "sed": "", "t": -1.0, "props": {} }
	out["head_rest"] = (nodes.get("head") as Node3D).transform if nodes.has("head") else Transform3D.IDENTITY
	out["head_size"] = (res.layout as Dictionary).get("head_size", Vector3(0.1, 0.07, 0.07))
	if nodes.has("head"):
		out["head_cards"] = (nodes.head as Node3D).get_node_or_null("PlumasCabeza")
	var lids: Array = []
	var degs: Array = LID_OPEN_DEG.get(kind, LID_OPEN_DEG.ave)
	for n: String in nodes:
		if n.begins_with("lid_"):
			var up := n.ends_with("_sup")
			var spec: Dictionary = (res.nodes as Dictionary).get(n, {})
			lids.append({ "node": nodes[n], "upper": up, "open_deg": float(spec.get("open_deg", degs[0] if up else degs[1])) })
	out["lids"] = lids
	# 5t-B (la reacción del animal): los pivotes del modelo (el ala, la mandíbula, la pata que golpea…) y su marco, para que
	# los mueva app/lab/cetreria/reaction/ (en reposo están en la identidad: el cuerpo se ve igual)
	var rig: Dictionary = (res.layout as Dictionary).get("rig", {})
	var pivots := {}
	for k: String in rig:
		var spec: Variant = rig[k]
		if spec is Dictionary and (spec as Dictionary).has("node") and nodes.has(String((spec as Dictionary).node)):
			pivots[k] = nodes[String((spec as Dictionary).node)]
	for e: Variant in rig.get("nict", []):
		if e is Dictionary and nodes.has(String((e as Dictionary).node)):
			pivots[String((e as Dictionary).node)] = nodes[String((e as Dictionary).node)]
	out["rig"] = rig
	out["pivots"] = pivots
	out["mats"] = mats
	if bool(opts.get("props", true)):
		_props(out, nodes, res, kind, art, mobile, cache)
	else:
		out["under"] = null
	return out


static func _anchors_key(anchors: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys: Array = anchors.keys()
	keys.sort()
	for k: String in keys:
		var o: Vector3 = (anchors[k] as Transform3D).origin
		parts.append("%s:%.4f,%.4f,%.4f" % [k, o.x, o.y, o.z])
	return ";".join(parts)


## El modelo (arrays) de un animal: el de su archivo (pose: la del coche en marcha, o vacía).
static func _model(kind: String, art: String, anchors: Dictionary, claw: Dictionary, mobile: bool, pose := {}) -> Dictionary:
	match kind:
		"mamifero":
			return BodyMammal.model(art, anchors, claw, mobile, pose)
		"teropodo":
			return BodyDino.model(art, anchors, claw, mobile, pose)
	return BodyBird.model(art, anchors, claw, mobile, pose)


## Los recursos de un modelo: las mallas y, en las partes con pelo, el MultiMesh de las capas (fur_layers > 0: esas capas
## en lugar de las de su calidad).
static func _resources(model: Dictionary, mobile: bool, fur_layers := 0) -> Dictionary:
	var parts := {}
	for name: String in model.parts:
		var e: Dictionary = model.parts[name]
		var am := BodyKit.to_mesh(e.arrays as Array)
		var r := { "mesh": am, "mat": String(e.mat), "node": String(e.node) }
		if e.has("shell_mat"):
			r["shell_mat"] = String(e.shell_mat)
		var layers := int(e.get("shells", 0))
		if layers > 0:
			var n := int(FUR_LAYERS.movil if mobile else FUR_LAYERS.escritorio) if layers < 0 or layers > 0 else 0
			if fur_layers > 0:
				n = fur_layers
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			# con el color de cada instancia en blanco: el renderizador multiplica el color del vértice (la oclusión y el largo del
			# pelo) por el de la instancia, y sin colores de instancia en Compatibility valdría 0
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = am
			mm.instance_count = n
			for i in n:
				mm.set_instance_transform(i, Transform3D.IDENTITY)
				mm.set_instance_color(i, Color.WHITE)
				mm.set_instance_custom_data(i, Color(float(i + 1) / float(n), 0.0, 0.0, 0.0))
			var grow := float(e.get("fur_m", 0.02))
			mm.custom_aabb = am.get_aabb().grow(grow)
			r["shells"] = mm
		parts[name] = r
	return { "parts": parts, "nodes": model.nodes, "box": model.box, "layout": model.layout }


## Los nodos del modelo ({ nombre: { parent, xf } }), cada uno bajo su padre (que puede venir después en el diccionario).
static func _make_nodes(spec: Dictionary, nodes: Dictionary) -> void:
	var pending: Array = spec.keys()
	var guard := 0
	while not pending.is_empty() and guard < 64:
		guard += 1
		var next: Array = []
		for n: String in pending:
			var e: Dictionary = spec[n]
			var par := String(e.parent)
			if not nodes.has(par):
				next.append(n)
				continue
			var nd := Node3D.new()
			nd.name = n.capitalize().replace(" ", "")
			nd.transform = e.xf
			(nodes[par] as Node3D).add_child(nd)
			nodes[n] = nd
		pending = next


## Los materiales de un animal (de la caché): los de su archivo, hechos con su sombreador.
static func _materials(kind: String, art: String, mobile: bool, cache: Dictionary) -> Dictionary:
	var key := "mats5i|%s|%s|%s" % [kind, art, "movil" if mobile else ""]
	if cache.has(key):
		return cache[key]
	var specs: Dictionary
	match kind:
		"mamifero":
			specs = BodyMammal.materials(art, mobile)
		"teropodo":
			specs = BodyDino.materials(art, mobile)
		_:
			specs = BodyBird.materials(art, mobile)
	var out := {}
	for id: String in specs:
		var sp: Dictionary = specs[id]
		if String(sp.shader) == "std":
			# 5t-B: un material sencillo translúcido (la membrana nictitante)
			var sm := StandardMaterial3D.new()
			var alb: Color = (sp.params as Dictionary).get("albedo", Color(1, 1, 1, 1))
			sm.albedo_color = alb
			sm.roughness = float((sp.params as Dictionary).get("rough", 0.5))
			if alb.a < 1.0:
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			out[id] = sm
			continue
		var m := ShaderMaterial.new()
		match String(sp.shader):
			"fur":
				m.shader = FUR_SHADER
			"feather":
				m.shader = FEATHER_SHADER
			"plumage":
				m.shader = PLUMAGE_SHADER
			"eye":
				m.shader = EYE_SHADER
			"leather":
				m.shader = LEATHER_SHADER
			_:
				m.shader = SKIN_SHADER
		for p: String in sp.params:
			m.set_shader_parameter(p, sp.params[p])
		out[id] = m
		if String(sp.shader) == "fur":
			var s := m.duplicate() as ShaderMaterial
			s.set_shader_parameter("shell", true)
			out[id + "_capas"] = s
	cache[key] = out
	return out


# ─────────────────────────────── lo de encima ───────────────────────────────

static func _cloth_mat(base: String, stripe: String, terry: bool, cache: Dictionary) -> ShaderMaterial:
	var key := "mat_tela|%s|%s|%s" % [base, stripe, str(terry)]
	if cache.has(key):
		return cache[key]
	var m := ShaderMaterial.new()
	m.shader = CLOTH_SHADER
	m.set_shader_parameter("base_color", Color(base))
	m.set_shader_parameter("stripe_color", Color(stripe))
	m.set_shader_parameter("terry", 1.0 if terry else 0.0)
	m.set_shader_parameter("stripe_m", 0.07 if terry else 0.3)
	m.set_shader_parameter("stripe_w", 0.16 if terry else 0.04)
	cache[key] = m
	return m


static func _std(color: Color, rough: float, metal := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Un material sencillo de la caché.
static func _cached_mat(cache: Dictionary, key: String, make: Callable) -> Material:
	if not cache.has(key):
		cache[key] = make.call()
	return cache[key]


static func _mesh_node(parent: Node3D, n: String, arrays: Array, mat: Material, cache: Dictionary, key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	if not cache.has(key):
		cache[key] = BodyKit.to_mesh(arrays)
	mi.mesh = cache[key]
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## La tela de debajo, la toalla, la capucha y la mascarilla de la rapaz; la mascarilla y la pinza de los grandes.
static func _props(out: Dictionary, nodes: Dictionary, res: Dictionary, kind: String, art: String, mobile: bool, cache: Dictionary) -> void:
	var root: Node3D = out.root
	var lay: Dictionary = res.layout
	var props := {}
	var q := "movil" if mobile else "escritorio"
	var box: AABB = res.box
	# la tela de debajo: la toalla del banco de cetrería o el paño verde de la clínica (la escena la recorta en el borde)
	var under := MeshInstance3D.new()
	under.name = "TelaDeDebajo"
	var size := Vector2(box.size.x + 0.3, box.size.z + 0.25)
	var towel := kind == "ave"
	var ukey := "tela5i|%s|%s" % [art, var_to_str(size.snapped(Vector2(0.001, 0.001)))]
	if not cache.has(ukey):
		var pm := PlaneMesh.new()
		pm.size = size
		var um := _cloth_mat("#DDE6EE" if towel else "#1F5246", "#7FA6C8" if towel else "#183F36", towel, cache).duplicate() as ShaderMaterial
		um.set_shader_parameter("uv_scale", maxf(size.x, size.y))
		cache[ukey] = [pm, um]
	under.mesh = (cache[ukey] as Array)[0]
	under.material_override = (cache[ukey] as Array)[1]
	under.position = Vector3(box.get_center().x + 0.02, 0.0015, box.get_center().z)
	root.add_child(under)
	out["under"] = under
	var head: Node3D = nodes.get("head")
	var hs: Vector3 = lay.get("head_size", Vector3(0.1, 0.07, 0.07))
	if kind == "ave":
		var lo: Dictionary = lay.trunk
		var key_w := "toalla5i|%s|%s|%s" % [art, q, _anchors_key({})]
		if not cache.has(key_w + "|arr"):
			cache[key_w + "|arr"] = BodyProps.towel(lo, float(lay.n_frac) + 0.04, 0.97, float(lay.girth), mobile, art)
		var tw := _mesh_node(root, "Toalla", cache[key_w + "|arr"], null, cache, key_w + "|" + str(lay.x_c))
		tw.material_override = _cached_mat(cache, "mat_toalla5i", func() -> Material:
			var m := _cloth_mat("#DDE6EE", "#7FA6C8", true, cache).duplicate() as ShaderMaterial
			m.set_shader_parameter("use_vertex_ao", 1.0)
			m.set_shader_parameter("uv_scale", 1.0)
			return m)
		props["wrap"] = tw
		# la capucha, en la cabeza
		var hood := Node3D.new()
		hood.name = "Capucha"
		head.add_child(hood)
		var hkey := "capucha5i|%s|%s" % [art, q]
		if not cache.has(hkey):
			cache[hkey] = BodyProps.hood(hs.x, hs.y, hs.z, mobile, Color("#B8342A"))
		var hd: Dictionary = cache[hkey]
		var leather := _cached_mat(cache, "mat_cuero5i", func() -> Material:
			var m := ShaderMaterial.new()
			m.shader = LEATHER_SHADER
			m.set_shader_parameter("leather_color", Color("#5E3B20"))
			m.set_shader_parameter("panel_color", Color("#2F5A3A"))
			m.set_shader_parameter("stitch_every", 14.0)
			m.set_shader_parameter("panel_from", 0.52)
			m.set_shader_parameter("panel_to", 0.8)
			return m)
		_mesh_node(hood, "Cuero", hd.leather, leather, cache, hkey + "|cuero")
		var trim := _cached_mat(cache, "mat_cuero5i_canto", func() -> Material:
			var m := ShaderMaterial.new()
			m.shader = LEATHER_SHADER
			m.set_shader_parameter("leather_color", Color("#3A2312"))
			return m)
		_mesh_node(hood, "Canto", hd.trim, trim, cache, hkey + "|canto")
		var plume := _mesh_node(hood, "Penacho", hd.plume, _materials(kind, art, mobile, cache).get("feather"), cache, hkey + "|penacho")
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props["hood"] = hood
		# la mascarilla del isoflurano, sobre el pico
		var mask := Node3D.new()
		mask.name = "Mascarilla"
		head.add_child(mask)
		var mkey := "mascarilla5i|%s|%s" % [art, q]
		if not cache.has(mkey):
			var hd2: Dictionary = BodyBird.HEADS.get(String((BodyBird.PLUMAGE.get(art, BodyBird.PLUMAGE.aguila) as Dictionary).head), BodyBird.HEADS.aguila)
			var blen := float((hd2.bill as Array)[0]) * float(lay.head_len)
			var base0 := Vector3(hs.x * 0.18, -hs.y * 0.05, 0.0)
			var tip := Vector3(hs.x * 0.42 + blen * 1.2, -hs.y * 0.12, 0.0)
			cache[mkey] = BodyProps.mask(base0, tip, maxf(hs.y, hs.z) * 0.62, maxf(hs.y, hs.z) * 0.16, tip + Vector3(blen * 2.5, -hs.y * 2.5, hs.z * 3.0), mobile)
		_mask_nodes(mask, cache[mkey], cache, mkey)
		props["mask"] = mask
	else:
		# los grandes y los velocirraptores
		var head_xf: Transform3D = lay.head_xf
		var L := float(lay.head_len)
		var inv := head_xf.affine_inverse()
		# la mascarilla, sobre el hocico, con el tubo hacia la máquina de anestesia (junto a la cabeza, fuera de la mesa)
		var mask := Node3D.new()
		mask.name = "Mascarilla"
		head.add_child(mask)
		var mkey := "mascarilla5i|%s|%s" % [art, q]
		if not cache.has(mkey):
			# el borde, delante de los ojos (el hocico entero dentro)
			var base0 := Vector3(L * 0.24, -hs.y * 0.05, 0.0)
			var tip := Vector3(L * 0.5 + L * 0.2, -hs.y * 0.08, 0.0)
			var r0 := maxf(hs.y, hs.z) * 0.36
			var r1 := L * 0.06
			# la del velocirraptor, del tamaño de su hocico (la da su modelo)
			var ms: Array = lay.get("mask", [])
			if ms.size() == 4:
				base0 = ms[0]
				tip = ms[1]
				r0 = float(ms[2])
				r1 = float(ms[3])
			var to_root := head_xf * tip + Vector3(0.1, -0.4, -0.45)
			cache[mkey] = BodyProps.mask(base0, tip, r0, r1, inv * to_root, mobile)
		_mask_nodes(mask, cache[mkey], cache, mkey)
		props["mask"] = mask
		# la lengua fuera, por delante de la boca y hacia la mesa, con la pinza del pulsioxímetro y su luz roja
		var clip := Node3D.new()
		clip.name = "Pulsioximetro"
		head.add_child(clip)
		var ckey := "pinza5i|%s|%s" % [art, q]
		if not cache.has(ckey):
			var mouth: Dictionary = lay.mouth
			var m0: Vector3 = (mouth.get(-1.0, Vector3(L * 0.1, -hs.y * 0.3, -hs.z * 0.3)) as Vector3).lerp(Vector3(L * 0.38, -hs.y * 0.32, 0.0), 0.6)
			var down := inv.basis * Vector3(0.0, -1.0, 0.0)
			cache[ckey] = BodyProps.tongue_clip(m0, Vector3(1.0, -0.3, 0.0).normalized(), down.normalized(), L * 0.45, L * 0.16, mobile)
		var cd: Dictionary = cache[ckey]
		var tongue_m := _cached_mat(cache, "mat_lengua5i", func() -> Material:
			var m := ShaderMaterial.new()
			m.shader = SKIN_SHADER
			m.set_shader_parameter("mode", 4)
			m.set_shader_parameter("color_a", Color("#C9606A"))
			m.set_shader_parameter("color_b", Color("#8E3A44"))
			m.set_shader_parameter("relief_mm", 0.4)
			return m)
		_mesh_node(clip, "Lengua", cd.tongue, tongue_m, cache, ckey + "|lengua")
		_mesh_node(clip, "Pinza", cd.clip, _cached_mat(cache, "mat_pinza5i", func() -> Material: return _std(Color("#D9DDE2"), 0.4)), cache, ckey + "|pinza")
		_mesh_node(clip, "Cable", cd.cable, _cached_mat(cache, "mat_cable5i", func() -> Material: return _std(Color("#2A2C30"), 0.5)), cache, ckey + "|cable")
		var led := MeshInstance3D.new()
		led.name = "Luz"
		var lkey := "luz5i|%s|%s" % [art, q]
		if not cache.has(lkey):
			var lm := SphereMesh.new()
			lm.radius = L * 0.012
			lm.height = L * 0.024
			cache[lkey] = lm
		led.mesh = cache[lkey]
		led.material_override = _cached_mat(cache, "mat_led5i", func() -> Material:
			var m := _std(Color(1.0, 0.12, 0.1), 0.3)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.08)
			m.emission_energy_multiplier = 2.5
			return m)
		led.position = cd.led
		clip.add_child(led)
		props["clip"] = clip
	out["props"] = props


static func _mask_nodes(mask: Node3D, md: Dictionary, cache: Dictionary, key: String) -> void:
	var glass := _cached_mat(cache, "mat_plastico5i", func() -> Material: return _std(Color(0.86, 0.93, 1.0), 0.05, 0.0, 0.3))
	var rubber := _cached_mat(cache, "mat_goma5i", func() -> Material: return _std(Color(0.06, 0.06, 0.07), 0.6))
	var tube := _cached_mat(cache, "mat_tubo5i", func() -> Material: return _std(Color(0.55, 0.75, 0.88), 0.25, 0.0, 0.75))
	var c := _mesh_node(mask, "Cono", md.cone, glass, cache, key + "|cono")
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_node(mask, "Diafragma", md.rubber, rubber, cache, key + "|goma")
	_mesh_node(mask, "Tubo", md.tube, tube, cache, key + "|tubo")


# ─────────────────────────────── la sujeción y cada fotograma ───────────────────────────────

## Lo que cambia con la sujeción: la toalla y la capucha de la rapaz (sujeta o sedada), la mascarilla (anestesiada) y la
## pinza del pulsioxímetro (anestesiado); la pupila, dilatada con la anestesia. Libre, nada.
static func set_sedation(body: Dictionary, sedation: String) -> void:
	var props: Dictionary = body.get("props", {})
	if props.has("wrap"):
		(props.wrap as Node3D).visible = sedation in ["sujecion", "sedacion", "anestesia"]
	if props.has("hood"):
		var hooded := sedation in ["sujecion", "sedacion"]
		(props.hood as Node3D).visible = hooded
		# con la capucha puesta, las plumas de la cabeza van debajo
		var hc: Node3D = body.get("head_cards")
		if hc != null:
			hc.visible = not hooded
	if props.has("mask"):
		(props.mask as Node3D).visible = sedation == "anestesia"
	if props.has("clip"):
		(props.clip as Node3D).visible = sedation == "anestesia"
	var em: ShaderMaterial = body.get("eye_mat")
	if em != null:
		em.set_shader_parameter("pupil_open", 0.8 if sedation == "anestesia" else (0.35 if sedation == "sedacion" else 0.0))
	if String(body.get("sed", "")) == "":
		body["open"] = float(EYE_OPEN.get(sedation, 1.0))
	body["sed"] = sedation


## Cada fotograma: la respiración, los párpados (con el parpadeo despierto y el apretón del dolor) y el respingo de la
## cabeza. Solo mueve transformaciones y parámetros de los materiales.
static func animate(body: Dictionary, t: float, sedation: String, flinch: float) -> void:
	var dt := clampf(t - float(body.t), 0.0, 0.25) if float(body.t) >= 0.0 else 0.0
	body["t"] = t
	var hz := float(BREATH_HZ.get(sedation, 0.6))
	var b := 0.5 + 0.5 * sin(t * TAU * hz)
	for m: ShaderMaterial in body.breath_mats:
		m.set_shader_parameter("breath", b)
	# los ojos
	var target := float(EYE_OPEN.get(sedation, 1.0))
	if sedation in ["libre", "sujecion"]:
		var ph := fmod(t + 1.7, BLINK_EVERY)
		if ph < BLINK_S:
			target *= 1.0 - sin(ph / BLINK_S * PI)
	if flinch > 0.0:
		target *= 1.0 - 0.8 * clampf(flinch, 0.0, 1.0)
	var open := float(body.open)
	if open < 0.0:
		open = target
	open = lerpf(open, target, 1.0 - exp(-dt / EYE_TAU)) if dt > 0.0 else open
	body["open"] = open
	for lid: Dictionary in body.lids:
		var up := bool(lid.upper)
		var ang := deg_to_rad(float(lid.open_deg)) * open * (-1.0 if up else 1.0)
		(lid.node as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, ang), Vector3.ZERO)
	# el respingo de la cabeza con el dolor
	var head: Node3D = body.get("head")
	if head != null:
		var rest: Transform3D = body.head_rest
		if flinch > 0.0:
			var j := clampf(flinch, 0.0, 1.0) * sin(t * 34.0)
			head.transform = rest.rotated_local(Vector3(0.0, 1.0, 0.0), 0.05 * j).rotated_local(Vector3(0.0, 0.0, 1.0), 0.03 * absf(j))
		elif head.transform != rest:
			head.transform = rest
