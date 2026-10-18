## Cetrería · las patas, los dedos y las garras de cada animal en alta definición, hechos desde cero para la cetrería
## (unidad 5h, peticiones 35 a 37; independientes de los modelos del coche en marcha). Lo que se ve en primer plano:
##   - la rapaz: el tarso (desnudo y con escudetes, o emplumado: el águila real, el búho y la lechuza) y sus cuatro dedos
##     con los escudetes de arriba, las escamas de los lados y las almohadillas con papilas; la piel amarilla o gris según
##     la especie (los dedos del búho real, emplumados);
##   - el tigre: la mano con sus cuatro dedos, las almohadillas de piel negra y rugosa, el pelo corto con las rayas hacia el
##     antebrazo, el espolón y la vaina de piel de cada garra retráctil: la garra que se trabaja sale de su vaina;
##   - el oso: la mano ancha con cinco dedos cortos, las almohadillas negras y el pelo largo y oscuro;
##   - el velocirraptor: el metatarso, los dedos III y IV en la mesa y el II con la hoz levantada, con escamas y plumas
##     pequeñas (el de película, solo con escamas).
## Todo a la escala de la garra del motor (su radio en la base y su largo: ClawCare.snapshot().claw), con proporciones de
## dibujo para lo demás (no son medidas). Dos niveles de detalle: el de primer plano (hi) y uno ligero (lo) para lo que
## queda lejos; el teléfono usa siempre el ligero. Las mallas y los materiales se hacen una vez por especie, lado, nivel
## y calidad (la caché de la escena): rehacer el animal solo crea los nodos.
##
## Marco de cada pata (m): el origen en la mesa (y = 0), bajo el centro del pie o de la mano; +X hacia los dedos, +Y arriba
## y +Z hacia fuera en la pata derecha (en la izquierda, hacia dentro: la pata se construye ya reflejada, sin escalas
## negativas). El anclaje (anchor) es donde se engancha la pata al cuerpo: el talón de la rapaz y del velocirraptor (la
## articulación del tarso) y el codo o la rodilla del tigre y del oso (el antebrazo y la pierna, hasta ahí, son de la
## pata). Su +X va del cuerpo hacia la pata.
## El marco de la base de cada garra (slots) es el de claw_mesh.gd: +X la dirección de partida de la garra, +Y su cara de
## arriba y +Z el lado.
extends RefCounted

const CareKit = preload("res://app/lab/cetreria/care_kit.gd")
const Rng = preload("res://core/shared/rng.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const SKIN_SHADER = preload("res://app/lab/cetreria/paw_skin.gdshader")
const FUR_SHADER = preload("res://app/lab/cetreria/paw_fur.gdshader")

const MM := 0.001
## Cuánto se gira hacia atrás el dedo reversible de las nocturnas (°, en torno a la vertical): de ~40° hacia fuera a ~150°,
## hacia atrás y afuera, como se ve al agarrar (dibujo: sin medición del ángulo).
const REVERSE_DEG := 108.0
## Distancia de la cámara (m) hasta la que se ve el nivel de primer plano (y su margen, para que no parpadee).
const LOD_HI_M := 0.75
const LOD_MARGIN_M := 0.1
## Capas del pelo (o de las plumas cortas) de cada nivel y en el teléfono.
const FUR_LAYERS := { "hi": 18, "lo": 6, "movil": 3 }
## Cuánto se dibuja el pelo en mechones (paw_fur.gdshader: con pocas capas, un pelo de un píxel se ve como ruido).
const FUR_MASS := { "hi": 0.0, "lo": 0.6, "movil": 1.0 }

## Las rapaces (dibujo, proporcional a la garra del banco de cada una): la escama y su surco, la almohadilla y su fondo, las
## plumas [raíz, punta], el tarso [largo × el de la garra, radio × el de su base] y si va emplumado, cuánto de los dedos
## va emplumado (0-1, desde la planta), y los dedos: [ángulo (° desde delante, + hacia fuera), largo × el de la garra,
## radio × el de su base, falanges antes de la garra]. El tamaño de los escudetes, de las escamas y de las papilas, en
## mm (en el águila, ~2,6, ~0,9 y ~0,45 mm). reversible: el dedo que se gira hacia atrás (el IV de las nocturnas,
## semizigodáctilas: el dedo exterior se vuelve hacia atrás para agarrar; lo pidió la calle B para el ataque), con su pivote
## (build → toe_pivots). El búho (vuelta de pulido de la 5s): los dedos emplumados casi hasta la garra
## y la piel que asoma, gris oscura (antes, el último quinto del dedo desnudo y gris claro se veía como un collar pálido).
const RAPTOR := {
	"aguila": { "skin": ["#D8A52A", "#94661A"], "pad": ["#D4A440", "#86602A"], "plume": ["#4A321E", "#8A6440"],
		"tarsus": [2.7, 1.5], "feather_tarsus": true, "feather_toes": 0.0, "scute": 2.6, "scale": 0.9, "papilla": 0.45,
		"toes": { "I": [192.0, 0.95, 1.45, 1], "II": [-30.0, 1.1, 1.38, 2], "III": [0.0, 1.5, 1.3, 3], "IV": [36.0, 1.08, 1.22, 4] } },
	"arpia": { "skin": ["#F0C040", "#9E7016"], "pad": ["#E6B850", "#8C6220"], "plume": ["#5C5C60", "#B8B8BC"],
		"tarsus": [2.7, 2.0], "feather_tarsus": false, "feather_toes": 0.0, "scute": 3.4, "scale": 1.1, "papilla": 0.5,
		"toes": { "I": [192.0, 1.0, 1.55, 1], "II": [-30.0, 1.1, 1.5, 2], "III": [0.0, 1.4, 1.42, 3], "IV": [36.0, 1.05, 1.35, 4] } },
	"halcon": { "skin": ["#F2CA30", "#A8861A"], "pad": ["#E8C048", "#8A6A1C"], "plume": ["#5A5E66", "#A8ACB4"],
		"tarsus": [2.8, 1.45], "feather_tarsus": false, "feather_toes": 0.0, "scute": 1.8, "scale": 0.6, "papilla": 0.32,
		"toes": { "I": [192.0, 1.2, 1.3, 1], "II": [-30.0, 1.6, 1.25, 2], "III": [0.0, 2.6, 1.2, 3], "IV": [38.0, 1.7, 1.15, 4] } },
	"buho": { "skin": ["#6E655C", "#3A342E"], "pad": ["#8E857A", "#4E463E"], "plume": ["#9A6A34", "#E2BE84"],
		"tarsus": [2.6, 1.5], "feather_tarsus": true, "feather_toes": 0.95, "scute": 2.2, "scale": 0.8, "papilla": 0.42, "reversible": "IV",
		"toes": { "I": [190.0, 0.95, 1.4, 1], "II": [-28.0, 1.1, 1.35, 2], "III": [0.0, 1.5, 1.3, 3], "IV": [42.0, 1.15, 1.25, 4] } },
	"lechuza": { "skin": ["#B4A496", "#6E6052"], "pad": ["#A89888", "#5E5246"], "plume": ["#D8CCB8", "#FFFDF6"],
		"tarsus": [4.2, 1.5], "feather_tarsus": true, "feather_toes": 0.0, "scute": 1.4, "scale": 0.5, "papilla": 0.28, "reversible": "IV",
		"toes": { "I": [190.0, 1.2, 1.3, 1], "II": [-28.0, 1.5, 1.28, 2], "III": [0.0, 2.0, 1.25, 3], "IV": [44.0, 1.6, 1.2, 4] } },
	"buitre": { "skin": ["#9C9893", "#55514C"], "pad": ["#8E8A84", "#4C4844"], "plume": ["#7A5E44", "#B89A74"],
		"tarsus": [4.0, 2.0], "feather_tarsus": false, "feather_toes": 0.0, "scute": 2.8, "scale": 1.0, "papilla": 0.5,
		"toes": { "I": [192.0, 0.9, 1.5, 1], "II": [-30.0, 1.7, 1.45, 2], "III": [0.0, 2.4, 1.4, 3], "IV": [36.0, 1.75, 1.35, 4] } },
}
## Felinos y osos (dibujo; dimensiones en mm para una garra con base de base_ref mm, y se escalan con la del motor): el
## pelo [raíz, punta], el de la cara de abajo, la almohadilla [piel, surco], el largo del pelo de los dedos y del
## antebrazo, y los dedos: [x, z, ángulo (° hacia fuera), largo, medio ancho, alto] de la base de cada dedo.
const TIGER := {
	"base_ref": 6.0, "fur": ["#6E3A12", "#D8893A"], "belly": "#EFE0C2", "pad": ["#2B2523", "#0E0C0B"],
	"fur_mm": [3.6, 7.0], "strand": 0.24,
	"digits": { "II": [14.0, -24.0, -16.0, 38.0, 11.5, 10.0], "III": [20.0, -8.5, -5.0, 44.0, 12.0, 10.5],
		"IV": [20.0, 8.5, 5.0, 44.0, 12.0, 10.5], "V": [12.0, 24.0, 17.0, 37.0, 11.0, 9.5] },
	"palm": [22.0, 8.0, 30.0], "dorsum": [44.0, 22.0, 47.0], "arm": [180.0, 40.0],
}
const BEAR := {
	"base_ref": 9.0, "fur": ["#20140C", "#6A4A30"], "belly": "#4A3424", "pad": ["#26211E", "#0E0C0B"],
	"fur_mm": [8.0, 16.0], "strand": 0.34,
	"digits": { "I": [20.0, -46.0, -12.0, 28.0, 12.0, 11.0], "II": [29.0, -23.0, -6.0, 33.0, 12.5, 11.5],
		"III": [32.0, 0.0, 0.0, 35.0, 12.5, 11.5], "IV": [29.0, 23.0, 6.0, 33.0, 12.5, 11.5],
		"V": [21.0, 46.0, 12.0, 29.0, 12.0, 11.0] },
	"palm": [24.0, 8.0, 60.0], "dorsum": [52.0, 28.0, 66.0], "arm": [210.0, 55.0],
}
## El velocirraptor (dibujo; mm para la garra de 13,9 mm de base de la reconstrucción): la escama, la almohadilla, las
## plumas cortas del metatarso (la reconstrucción) y los dedos.
const DINO := {
	"velociraptor": { "skin": ["#6E5C46", "#33281E"], "pad": ["#625240", "#2E241A"], "plume": ["#4E3C2C", "#9C7C5C"],
		"feathers": true, "scute": 4.2, "scale": 1.6, "papilla": 0.9 },
	"velociraptor_pelicula": { "skin": ["#7A7656", "#363224"], "pad": ["#6E6A50", "#2E2A1E"], "plume": ["#000000", "#000000"],
		"feathers": false, "scute": 5.0, "scale": 2.0, "papilla": 1.1 },
}
const DINO_BASE_REF := 13.9


## La variación del color de la queratina de garra a garra (unidad 5s, petición 60: «las garras de las demás patas no sean
## copias idénticas»): cuánto cambian el valor, la saturación y el tono (fracciones, ±). Dibujo: el color de cada especie tiene
## su fuente (ClawOptics.KERATIN_COLORS, que ya dice que varía de un animal a otro); de garra a garra no está medido.
const CLAW_TONE_VARIATION := { "v": 0.12, "s": 0.12, "h": 0.012, "quality": "dibujo" }


## El color de la queratina de una garra del animal (key: «pata|dedo»), algo distinto en cada una: determinista, del mismo
## ejemplar (art) y la garra (core/shared/rng.gd), igual en cada ensayo. Solo el dibujo: no cambia la física.
static func claw_tone(base: Color, art: String, key: String) -> Color:
	var rng := Rng.new(Rng.seed_of("tono-garra:%s:%s" % [art, key]))
	var dv := (rng.next() * 2.0 - 1.0) * float(CLAW_TONE_VARIATION.v)
	var ds := (rng.next() * 2.0 - 1.0) * float(CLAW_TONE_VARIATION.s)
	var dh := (rng.next() * 2.0 - 1.0) * float(CLAW_TONE_VARIATION.h)
	return Color.from_hsv(fposmod(base.h + dh, 1.0), clampf(base.s * (1.0 + ds), 0.0, 1.0), clampf(base.v * (1.0 + dv), 0.0, 1.0), base.a)


## La forma de las garras que no se trabajan del oso y del tigre, de dedo a dedo (vuelta de pulido de la 5s: «las garras del
## oso parecen copias»). Sin medición dedo a dedo en osos ni en felinos (CareData.CLAW_SHAPES: todas iguales, «estimate»), el
## DIBUJO varía su largo y su arco: [largo, arco] frente a la del banco, los dedos de los lados algo más cortos y curvos
## (ESTIMACIÓN de dibujo, sin fuente: no es un dato), y además CLAW_SHAPE_JITTER (±, de garra a garra, de su semilla). Solo
## el dibujo de las que no se trabajan: la que se trabaja es la del motor (la de la ficha), también al elegir otra.
const CLAW_SHAPE_DRAWING := {
	"oso": { "I": [0.86, 1.06], "II": [0.96, 1.0], "III": [1.0, 1.0], "IV": [0.97, 1.0], "V": [0.88, 1.05] },
	"tigre": { "II": [0.94, 1.0], "III": [1.0, 1.0], "IV": [0.98, 1.0], "V": [0.9, 1.04] },
}
const CLAW_SHAPE_JITTER := { "length": 0.04, "arc": 0.05, "quality": "dibujo" }


## La forma de dibujo de la garra key («pata|dedo») del banco claw_id: { length, arc } (factores; 1 y 1 en las especies con
## sus garras medidas dedo a dedo, que ya salen de su ficha). Determinista (core/shared/rng.gd).
static func claw_shape_drawing(claw_id: String, key: String) -> Dictionary:
	var by: Dictionary = CLAW_SHAPE_DRAWING.get(claw_id, {})
	if by.is_empty():
		return { "length": 1.0, "arc": 1.0 }
	var base: Array = by.get(key.get_slice("|", 1), [1.0, 1.0])
	var rng := Rng.new(Rng.seed_of("forma-garra:%s:%s" % [claw_id, key]))
	var dl := (rng.next() * 2.0 - 1.0) * float(CLAW_SHAPE_JITTER.length)
	var da := (rng.next() * 2.0 - 1.0) * float(CLAW_SHAPE_JITTER.arc)
	return { "length": float(base[0]) * (1.0 + dl), "arc": float(base[1]) * (1.0 + da) }


## Las patas que se construyen de cada animal, por el nombre de la cetrería (ClawCareState.paws_of).
static func is_hind(paw: String) -> bool:
	return paw.begins_with("trasera")


static func side_of(paw: String) -> float:
	return 1.0 if paw.ends_with("derecha") else -1.0


## Construye una pata y sus nodos. animal: rapaz · tigre · oso · velociraptor; art: el dibujo (la rapaz de su especie, o
## velociraptor_pelicula); claw: { base_r_mm, length_mm, curve } (la garra del motor); paw: el nombre de la pata;
## opts: { lod («hi» | «lo»), mobile, cache (Dictionary compartido), claw_mat (el material de las garras que no se
## trabajan: el de la escena) }.
## → { root (Node3D), slots: { dedo: Node3D }, anchor (Transform3D en root), center (Vector3), aabb (AABB),
##     protract: { dedo: { node, out, in } }, toe_pivots: { dedo: { node (Node3D hijo de root, en la identidad en reposo:
##     su piel, sus plumas y la base de su garra cuelgan de él), point (la base del dedo, en root: en torno a ella gira),
##     axis (la vertical), dir (hacia dónde apunta el dedo en reposo), back_deg (cuánto girarlo sobre axis para volverlo
##     hacia atrás) } } (el IV de las nocturnas), verts (vértices), fresh (si se han hecho las mallas: no estaban en la
##     caché) }
static func build(parent: Node3D, animal: String, art: String, claw: Dictionary, paw: String, opts := {}) -> Dictionary:
	var mobile := bool(opts.get("mobile", false))
	var cache: Dictionary = opts.get("cache", {})
	var key := "pata|%s|%s|%s|%s|%s|%s" % [animal, art, paw, var_to_str(float(claw.base_r_mm)), var_to_str(float(claw.length_mm)), "movil" if mobile else "escritorio"]
	var model: Dictionary
	var fresh := not cache.has(key)
	if fresh:
		model = _model(animal, art, claw, paw, mobile)
		cache[key] = model
	else:
		model = cache[key]
	var root := Node3D.new()
	root.name = "Pata_" + paw
	parent.add_child(root)
	# los pivotes de los dedos que se giran (el IV de las nocturnas): un nodo en la identidad en reposo (como los del cuerpo,
	# care_body.gd), del que cuelgan su piel, sus plumas y la base de su garra; se gira en torno a point (la base del dedo)
	var toe_pivots := {}
	var pivot_nodes := {}
	for d: String in (model.get("pivots", {}) as Dictionary):
		var pe: Dictionary = model.pivots[d]
		var pn := Node3D.new()
		pn.name = "PivoteDelDedo_" + d
		root.add_child(pn)
		pivot_nodes[d] = pn
		toe_pivots[d] = { "node": pn, "point": pe.at, "axis": Vector3.UP, "dir": pe.dir,
			"back_deg": -side_of(paw) * REVERSE_DEG }
	var lods: Array = ["lo"] if mobile else ["hi", "lo"]
	var verts := 0
	for lod: String in lods:
		var parts: Dictionary = model.meshes[lod]
		for part: String in parts:
			var e: Dictionary = parts[part]
			var mi := MeshInstance3D.new()
			mi.name = "%s_%s" % [part, lod]
			mi.mesh = e.mesh
			mi.material_override = _material(String(e.mat), art, animal, lod, mobile, cache)
			if String(e.mat).begins_with("fur") or String(e.mat).begins_with("plume"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not mobile:
				if lod == "hi":
					mi.visibility_range_end = LOD_HI_M
					mi.visibility_range_end_margin = LOD_MARGIN_M
				else:
					mi.visibility_range_begin = LOD_HI_M
					mi.visibility_range_begin_margin = LOD_MARGIN_M
			var pv := String(e.get("pivot", ""))
			if pivot_nodes.has(pv):
				(pivot_nodes[pv] as Node3D).add_child(mi)
			else:
				root.add_child(mi)
			verts += int(e.verts) if lod == lods[0] else 0
	# las garras que no se trabajan (el velocirraptor: los dedos I, III y IV)
	var claw_mat: Material = opts.get("claw_mat")
	for mc: Dictionary in model.model_claws:
		var mi := MeshInstance3D.new()
		mi.name = "Garra_" + String(mc.digit)
		mi.mesh = mc.mesh
		mi.material_override = claw_mat
		mi.transform = mc.xf
		root.add_child(mi)
	var slots := {}
	var protract := {}
	for d: String in model.slots:
		var n := Node3D.new()
		n.name = "BaseDeLaGarra_" + d
		n.transform = model.slots[d]
		if pivot_nodes.has(d):
			(pivot_nodes[d] as Node3D).add_child(n)
		else:
			root.add_child(n)
		slots[d] = n
		if (model.protract as Dictionary).has(d):
			protract[d] = { "node": n, "out": model.slots[d], "in": model.protract[d], "k": 1.0, "goal": 1.0 }
	return { "root": root, "slots": slots, "anchor": model.anchor, "center": model.center, "aabb": model.aabb,
		"protract": protract, "toe_pivots": toe_pivots, "verts": verts, "key": key, "fresh": fresh }


# ─────────────────────────────── el modelo (arrays, mallas) ───────────────────────────────

## Las mallas de una pata (las de los dos niveles) y sus marcos. Puro salvo por los ArrayMesh que crea (una vez: caché).
static func _model(animal: String, art: String, claw: Dictionary, paw: String, mobile: bool) -> Dictionary:
	var side := side_of(paw)
	var hind := is_hind(paw)
	var levels: Array = ["lo"] if mobile else ["hi", "lo"]
	var out := { "meshes": {}, "slots": {}, "protract": {}, "model_claws": [], "anchor": Transform3D.IDENTITY,
		"center": Vector3.ZERO, "aabb": AABB(), "pivots": {} }
	for lod: String in levels:
		var spec: Dictionary
		match animal:
			"tigre":
				spec = _felid(claw, side, hind, lod, mobile, TIGER, true)
			"oso":
				spec = _felid(claw, side, hind, lod, mobile, BEAR, false)
			"velociraptor":
				spec = _theropod(art, claw, side, lod, mobile)
			_:
				spec = _raptor(art, claw, side, lod, mobile)
		var meshes := {}
		for part: String in spec.parts:
			var arrays: Array = spec.parts[part].arrays
			if not CareKit.has_triangles(arrays):
				continue
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshes[part] = { "mesh": am, "mat": String(spec.parts[part].mat), "verts": CareKit.vertex_count(arrays),
				"pivot": String(spec.parts[part].get("pivot", "")) }
		out.meshes[lod] = meshes
		if lod == levels[0]:
			out["slots"] = spec.slots
			out["protract"] = spec.get("protract", {})
			out["anchor"] = spec.anchor
			out["center"] = spec.center
			out["aabb"] = spec.aabb
			out["pivots"] = spec.get("pivots", {})
			var mcs: Array = []
			for mc: Dictionary in spec.get("model_claws", []):
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mc.arrays)
				mcs.append({ "digit": mc.digit, "mesh": am, "xf": mc.xf })
			out["model_claws"] = mcs
	return out


## El material de una parte (de la caché): «skin» y «pad» con paw_skin.gdshader; «fur» y «plume» con paw_fur.gdshader.
static func _material(id: String, art: String, animal: String, lod: String, mobile: bool, cache: Dictionary) -> Material:
	var key := "mat|%s|%s|%s|%s" % [id, art, lod, "movil" if mobile else ""]
	if cache.has(key):
		return cache[key]
	var m := ShaderMaterial.new()
	var detail := 0.0 if mobile or lod == "lo" else 1.0
	match animal:
		"tigre", "oso":
			var d: Dictionary = TIGER if animal == "tigre" else BEAR
			if id == "pad":
				m.shader = SKIN_SHADER
				_skin_params(m, [d.pad[0], d.pad[1]], [d.pad[0], d.pad[1]], 3.0, 0.7, 0.35, detail)
				m.set_shader_parameter("leather", 1.0)
				m.set_shader_parameter("rough_scale", 0.86)
				m.set_shader_parameter("rough_pad", 0.9)
				m.set_shader_parameter("sheen", 0.05)
				m.set_shader_parameter("relief_mm", 0.22)
			elif id == "claw_skin":
				m.shader = SKIN_SHADER
				_skin_params(m, [d.fur[0], d.fur[0]], [d.pad[0], d.pad[1]], 3.0, 0.7, 0.35, detail)
			else:
				m.shader = FUR_SHADER
				var arm := id == "fur_arm"
				m.set_shader_parameter("root_color", Color(String(d.fur[0])))
				m.set_shader_parameter("tip_color", Color(String(d.fur[1])))
				m.set_shader_parameter("belly_color", Color(String(d.belly)))
				m.set_shader_parameter("belly", 0.75 if animal == "tigre" else 0.2)
				m.set_shader_parameter("fur_mm", float(d.fur_mm[1 if arm else 0]))
				m.set_shader_parameter("strand_mm", float(d.strand) * (1.25 if arm else 1.0))
				m.set_shader_parameter("comb_dir", Vector3(1.0, -0.2, 0.0))
				m.set_shader_parameter("comb", 0.8 if animal == "oso" else 0.6)
				m.set_shader_parameter("droop", 0.35 if animal == "oso" else 0.15)
				m.set_shader_parameter("stripes", 1.0 if animal == "tigre" and arm else 0.0)
				m.set_shader_parameter("stripe_mm", 34.0)
				m.set_shader_parameter("stripe_axis", Vector2(-1.0, 0.0))
				m.set_shader_parameter("stripe_from_m", 0.07)
		"velociraptor":
			var dd: Dictionary = DINO.get(art, DINO.velociraptor)
			if id == "plume":
				m.shader = FUR_SHADER
				_plume_params(m, dd.plume, 6.0, 0.55)
			else:
				m.shader = SKIN_SHADER
				_skin_params(m, dd.skin, dd.pad, float(dd.scute), float(dd.scale), float(dd.papilla), detail)
				m.set_shader_parameter("relief_mm", 0.32)
				m.set_shader_parameter("sheen", 0.12)
		_:
			var r: Dictionary = RAPTOR.get(art, RAPTOR.aguila)
			if id == "plume":
				m.shader = FUR_SHADER
				_plume_params(m, r.plume, 7.0 if art != "lechuza" else 4.5, 0.42)
			else:
				m.shader = SKIN_SHADER
				_skin_params(m, r.skin, r.pad, float(r.scute), float(r.scale), float(r.papilla), detail)
	if m.shader == FUR_SHADER:
		# con pocas capas (el teléfono, el detalle ligero), mechones en lugar de pelos sueltos (paw_fur.gdshader)
		m.set_shader_parameter("mass", FUR_MASS.movil if mobile else float(FUR_MASS[lod]))
	cache[key] = m
	return m


static func _skin_params(m: ShaderMaterial, skin: Array, pad: Array, scute: float, scale: float, papilla: float, detail: float) -> void:
	m.set_shader_parameter("skin_a", Color(String(skin[0])))
	m.set_shader_parameter("skin_b", Color(String(skin[1])))
	m.set_shader_parameter("pad_a", Color(String(pad[0])))
	m.set_shader_parameter("pad_b", Color(String(pad[1])))
	m.set_shader_parameter("scute_mm", scute)
	m.set_shader_parameter("scale_mm", scale)
	m.set_shader_parameter("papilla_mm", papilla)
	m.set_shader_parameter("detail", detail)


## Plumas cortas y suaves (el tarso emplumado, los dedos del búho, el metatarso del velocirraptor): el sombreador del pelo
## con hebras más gruesas, poco peinadas y sin caer.
static func _plume_params(m: ShaderMaterial, cols: Array, len_mm: float, strand_mm: float) -> void:
	m.set_shader_parameter("root_color", Color(String(cols[0])))
	m.set_shader_parameter("tip_color", Color(String(cols[1])))
	m.set_shader_parameter("belly_color", Color(String(cols[1])))
	m.set_shader_parameter("belly", 0.25)
	m.set_shader_parameter("fur_mm", len_mm)
	m.set_shader_parameter("strand_mm", strand_mm)
	m.set_shader_parameter("thick", 1.15)
	m.set_shader_parameter("comb", 0.9)
	m.set_shader_parameter("droop", 0.1)
	m.set_shader_parameter("comb_dir", Vector3(1.0, -0.3, 0.0))


## Una garra de dibujo que no se trabaja (los dedos del velocirraptor que no tienen ficha): el cono de la punta del
## motor no hace falta; un perfil que se afina hasta la punta, con su curva.
static func _model_claw(length_mm: float, base_mm: float, curve: float, ring: int) -> Array:
	var ss := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var n := 16
	for i in n + 1:
		var t := float(i) / float(n)
		ss.append(t * length_mm)
		rs.append(base_mm * (1.0 - pow(t, 1.25)) + 0.04)
	rs[n] = 0.0
	var k := ClawMesh.curvature(length_mm, curve)
	return ClawMesh.tube_arrays(ss, rs, k, ring, 0.0, ClawMesh.SECTIONS.ave)


## Una garra de dibujo en milímetros pasada al marco de la pata (m).
static func _model_claw_xf(base: Transform3D) -> Transform3D:
	return base.scaled_local(Vector3.ONE * MM)


## Marco de la base de una garra: x la dirección de partida, y su arriba (ortogonalizada).
static func _frame(at: Vector3, x: Vector3, up: Vector3) -> Transform3D:
	var xx := x.normalized()
	var zz := xx.cross(up).normalized()
	var yy := zz.cross(xx).normalized()
	return Transform3D(Basis(xx, yy, zz), at)


# ─────────────────────────────── la rapaz ───────────────────────────────

## El pie de una rapaz: el tarso que llega del talón, la planta y los cuatro dedos (anisodáctilo: I hacia atrás, II, III
## y IV hacia delante), con la planta hacia abajo; las garras, al final de cada dedo, se curvan hacia abajo.
static func _raptor(art: String, claw: Dictionary, side: float, lod: String, mobile: bool) -> Dictionary:
	var r: Dictionary = RAPTOR.get(art, RAPTOR.aguila)
	var base_r := float(claw.base_r_mm) * MM
	var L := float(claw.length_mm) * MM
	var hi := lod == "hi"
	var ring := 30 if hi else 12
	var n_st := 30 if hi else 12
	var tarsus: Array = r.tarsus
	var t_len := float(tarsus[0]) * L
	var t_r := float(tarsus[1]) * base_r
	var yc := t_r * 1.0
	var center := Vector3(0.0, yc, 0.0)
	var skin_parts: Array = []
	var plume_parts: Array = []
	# el tarso: del talón (atrás, algo más alto) a la planta; la cara de delante (la de arriba aquí) con escudetes
	var t_pts := PackedVector3Array([Vector3(-t_len, yc + t_r * 0.5, 0.0), Vector3(-t_len * 0.5, yc + t_r * 0.18, 0.0), Vector3(t_r * 0.2, yc, 0.0)])
	var t_sp := CareKit.spine(t_pts, 16 if hi else 8)
	var tn := t_sp.size()
	var t_top := PackedFloat32Array()
	var t_bot := PackedFloat32Array()
	var t_z := PackedFloat32Array()
	var t_ao := PackedFloat32Array()
	for i in tn:
		var u := float(i) / float(tn - 1)
		var rr := t_r * (1.0 + 0.12 * CareKit.gauss(u, 0.0, 0.18) + 0.08 * CareKit.gauss(u, 1.0, 0.15))
		t_top.append(rr)
		t_bot.append(rr * 0.92)
		t_z.append(rr * 0.86)
		t_ao.append(1.0 - 0.25 * CareKit.gauss(u, 1.0, 0.12))
	var tarsus_arrays := CareKit.limb({ "spine": t_sp, "up": Vector3.UP, "ring": ring, "ry_top": t_top, "ry_bot": t_bot,
		"rz": t_z, "n_top": 2.3, "n_bot": 2.0, "ao": t_ao, "cap_start": true, "cap_end": false, "dorsal": 0.2, "ventral": 0.12 })
	skin_parts.append(tarsus_arrays)
	if bool(r.feather_tarsus):
		# el «pantalón» de plumas: casi todo el tarso, hasta poco antes de la planta
		plume_parts.append(CareKit.shells(_trim_limb(tarsus_arrays, 0.0, 0.86), int(FUR_LAYERS.movil if mobile else FUR_LAYERS[lod])))
	# la planta: la almohadilla del metatarso, con papilas
	var pr := base_r * 1.55
	skin_parts.append(CareKit.blob(center + Vector3(base_r * 0.3, -base_r * 0.25, 0.0), Vector3(pr * 1.25, pr * 0.8, pr * 1.2), Basis.IDENTITY,
		ring, 16 if hi else 8, { "pad": 1.0, "ao_under": 0.2, "bumps": [{ "dir": Vector3(0.0, -1.0, 0.0), "amp": 0.12, "width": 0.8 }] }))
	var slots := {}
	var toes: Dictionary = r.toes
	var feather_toes := float(r.feather_toes)
	var rev := String(r.get("reversible", ""))
	var pivots := {}
	var rev_skin: Array = []
	var rev_plume: Array = []
	for d: String in toes:
		var spec: Array = toes[d]
		var ang := deg_to_rad(float(spec[0]))
		var tl := float(spec[1]) * L
		var tr := float(spec[2]) * base_r
		var nph := int(spec[3])
		var dir := Vector3(cos(ang), 0.0, sin(ang) * side)
		# las falanges: se doblan hacia abajo en cada articulación (dedos relajados)
		var pts := PackedVector3Array([center + dir * base_r * 0.4])
		var joints := PackedFloat32Array([0.0])
		var p := pts[0]
		var pitch := deg_to_rad(-10.0)
		var lens: Array = []
		var tot := 0.0
		for k in nph:
			var w := 1.0 + 0.25 * float(nph - 1 - k)
			lens.append(w)
			tot += w
		var run := 0.0
		for k in nph:
			var seg := tl * float(lens[k]) / tot
			var dk := (dir * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			p += dk * seg
			pts.append(p)
			run += seg
			joints.append(run / tl)
			pitch += deg_to_rad(-11.0)
		var sp := CareKit.spine(pts, n_st)
		var n := sp.size()
		var top := PackedFloat32Array()
		var bot := PackedFloat32Array()
		var zz := PackedFloat32Array()
		var ao := PackedFloat32Array()
		var pad := PackedFloat32Array()
		for i in n:
			var u := float(i) / float(n - 1)
			var pd := 0.0
			var kn := 0.0
			for k in range(1, joints.size()):
				pd = maxf(pd, CareKit.gauss(u, joints[k] - 0.06, 0.075))
				kn = maxf(kn, CareKit.gauss(u, joints[k], 0.05))
			pd = maxf(pd, CareKit.gauss(u, 0.9, 0.06))
			# el dedo se afina hacia la garra y acaba en el pliegue de piel que rodea su base
			var rr := lerpf(tr, base_r * 1.12, smoothstep(0.55, 1.0, u)) * (1.0 - 0.1 * u)
			top.append(rr * (0.9 + 0.07 * kn))
			bot.append(rr * (0.8 + 0.42 * pd))
			zz.append(rr * 1.06)
			ao.append(1.0 - 0.2 * CareKit.gauss(u, 0.0, 0.1) - 0.12 * smoothstep(0.93, 1.0, u))
			pad.append(pd)
		var toe := CareKit.limb({ "spine": sp, "up": Vector3.UP, "ring": ring, "ry_top": top, "ry_bot": bot, "rz": zz,
			"n_top": 2.35, "n_bot": 2.1, "ao": ao, "pad": pad, "cap_end": true, "cap_k": 0.6, "dorsal": 0.15, "ventral": 0.2 })
		# el dedo que se gira hacia atrás (reversible), en sus propias partes, colgado de su pivote (en su base)
		var own_skin: Array = rev_skin if d == rev else skin_parts
		var own_plume: Array = rev_plume if d == rev else plume_parts
		if d == rev:
			pivots[d] = { "at": pts[0], "dir": dir }
		own_skin.append(toe)
		if feather_toes > 0.0:
			own_plume.append(CareKit.shells(_trim_limb(toe, 0.0, feather_toes), int(FUR_LAYERS.movil if mobile else FUR_LAYERS[lod]) / 2 + 1))
		# la base de la garra: en la punta del dedo, dentro del pliegue de piel, algo levantada
		var t_end := (sp[n - 1] - sp[n - 2]).normalized()
		var up_end := (Vector3.UP - t_end * Vector3.UP.dot(t_end)).normalized()
		var at := sp[n - 1] - t_end * base_r * 0.35 + up_end * base_r * 0.12
		var x := (t_end * cos(deg_to_rad(12.0)) + up_end * sin(deg_to_rad(12.0))).normalized()
		slots[d] = _frame(at, x, up_end)
	var aabb := _aabb_of(skin_parts + rev_skin)
	var parts := { "skin": { "arrays": CareKit.merge(skin_parts), "mat": "skin" } }
	if not plume_parts.is_empty():
		parts["plume"] = { "arrays": CareKit.merge(plume_parts), "mat": "plume" }
	if rev != "" and not rev_skin.is_empty():
		parts["toe_%s_skin" % rev] = { "arrays": CareKit.merge(rev_skin), "mat": "skin", "pivot": rev }
		if not rev_plume.is_empty():
			parts["toe_%s_plume" % rev] = { "arrays": CareKit.merge(rev_plume), "mat": "plume", "pivot": rev }
	return { "parts": parts, "slots": slots, "anchor": _frame(t_pts[0], (t_pts[1] - t_pts[0]), Vector3.UP), "center": center, "aabb": aabb,
		"pivots": pivots }


## La parte de un tubo entre las fracciones u0 y u1 de su largo (por la coordenada UV.x): para poner plumas solo en un
## tramo. Copia los vértices de ese tramo y los triángulos que caen dentro.
static func _trim_limb(arrays: Array, u0: float, u1: float) -> Array:
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var umax := 0.0
	for q in uv:
		umax = maxf(umax, q.x)
	var lo := u0 * umax
	var hi := u1 * umax
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var ok := true
		for k in 3:
			var x := uv[idx[t + k]].x
			if x < lo or x > hi:
				ok = false
				break
		if ok:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var out := arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = keep
	return out


static func _aabb_of(parts: Array) -> AABB:
	var out := AABB()
	var first := true
	for a: Array in parts:
		if not CareKit.has_triangles(a):
			continue
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
			if first:
				out = AABB(v, Vector3.ZERO)
				first = false
			else:
				out = out.expand(v)
	return out


# ─────────────────────────────── el tigre y el oso ───────────────────────────────

## La mano (o el pie) de un tigre o de un oso, con la palma hacia la mesa y los dedos hacia el borde: el dorso con su
## pelo, la almohadilla de la palma (trilobulada en el tigre, ancha de lado a lado en el oso) y la del carpo, cada dedo
## con su almohadilla negra y rugosa, y el antebrazo (o la pierna) hasta el codo (o la rodilla), el anclaje. En el
## tigre, cada garra tiene su vaina de piel al final del dedo y su posición recogida (protract.in) y fuera (la del
## marco): la escena la saca al trabajarla.
static func _felid(claw: Dictionary, side: float, hind: bool, lod: String, mobile: bool, d: Dictionary, retractile: bool) -> Dictionary:
	var base_r := float(claw.base_r_mm) * MM
	var s := base_r / (float(d.base_ref) * MM)
	var mm := MM * s
	var hi := lod == "hi"
	var ring := 30 if hi else 12
	var n_st := 22 if hi else 10
	var layers := int(FUR_LAYERS.movil if mobile else FUR_LAYERS[lod])
	var skin_parts: Array = []
	var fur_parts: Array = []
	var arm_parts: Array = []
	var pad_parts: Array = []
	var palm: Array = d.palm
	var dors: Array = d.dorsum
	# la palma: la almohadilla grande (tres lóbulos delante en el tigre; una judía ancha en el oso)
	var bumps: Array = []
	if retractile:
		for zl: float in [-0.55, 0.0, 0.55]:
			bumps.append({ "dir": Vector3(0.8, -0.3, zl), "amp": 0.16, "width": 0.45 })
	pad_parts.append(CareKit.blob(Vector3(-2.0, float(palm[1]) * 0.95, 0.0) * mm, Vector3(float(palm[0]), float(palm[1]), float(palm[2])) * mm,
		Basis.IDENTITY, ring, 14 if hi else 8, { "zone": 1.0, "ao_under": 0.1, "bumps": bumps }))
	# la del carpo (detrás, más alta) en la mano; en el pie, el talón largo
	if not hind:
		pad_parts.append(CareKit.blob(Vector3(-float(dors[0]) * 1.25, 12.0, -10.0 * side) * mm, Vector3(10.0, 7.0, 10.0) * mm, Basis.IDENTITY,
			ring / 2 + 4, 8, { "zone": 1.0, "ao_under": 0.1 }))
	# el dorso de la mano, con su pelo
	var dors_c := Vector3(-14.0, float(dors[1]) * 1.05, 0.0) * mm
	var dorsum := CareKit.blob(dors_c, Vector3(float(dors[0]), float(dors[1]), float(dors[2])) * mm, Basis.IDENTITY, ring, 16 if hi else 8,
		{ "zone": -1.0, "ao_under": 0.35 })
	skin_parts.append(dorsum)
	fur_parts.append(CareKit.shells(dorsum, layers))
	# el antebrazo (o la pierna) hasta el codo (o la rodilla): sube hacia atrás
	var arm: Array = d.arm
	var a_len := float(arm[0]) * (1.15 if hind else 1.0) * mm
	var a_r := float(arm[1]) * mm
	var wrist := dors_c + Vector3(-float(dors[0]) * 0.55, float(dors[1]) * 0.25, 0.0) * mm
	var elbow := wrist + Vector3(-a_len, a_len * 0.32, 0.0)
	var a_sp := CareKit.spine(PackedVector3Array([wrist + Vector3(float(dors[0]) * 0.45 * mm, -a_r * 0.25, 0.0), wrist, elbow]), 14 if hi else 7)
	var an := a_sp.size()
	var a_top := PackedFloat32Array()
	var a_z := PackedFloat32Array()
	for i in an:
		var u := float(i) / float(an - 1)
		var rr := a_r * lerpf(0.82, 1.08, smoothstep(0.0, 1.0, u))
		a_top.append(rr)
		a_z.append(rr * 0.92)
	var arm_arrays := CareKit.limb({ "spine": a_sp, "up": Vector3.UP, "ring": ring, "ry_top": a_top, "ry_bot": a_top, "rz": a_z,
		"cap_start": false, "cap_end": true, "cap_k": 0.4, "ao_under": 0.3 })
	skin_parts.append(arm_arrays)
	arm_parts.append(CareKit.shells(arm_arrays, maxi(layers - 2, 2)))
	var slots := {}
	var protract := {}
	var model_claws: Array = []
	var digits: Dictionary = d.digits
	for dg: String in digits:
		var e: Array = digits[dg]
		var bx := float(e[0]) * mm
		var bz := float(e[1]) * side * mm
		var ang := deg_to_rad(float(e[2]))
		var dl := float(e[3]) * mm
		var half_w := float(e[4]) * mm
		var hgt := float(e[5]) * mm
		var dir := Vector3(cos(ang), 0.0, sin(ang) * side)
		var b := Vector3(bx - dl * 0.15, hgt * 1.25, bz)
		var mid := b + dir * dl * 0.55 + Vector3(0.0, -hgt * 0.15, 0.0)
		var tip := b + dir * dl + Vector3(0.0, -hgt * 0.3, 0.0)
		var sp := CareKit.spine(PackedVector3Array([b, mid, tip]), n_st)
		var n := sp.size()
		var top := PackedFloat32Array()
		var bot := PackedFloat32Array()
		var zz := PackedFloat32Array()
		var ao := PackedFloat32Array()
		for i in n:
			var u := float(i) / float(n - 1)
			# la vaina: el final del dedo, más alto por arriba (donde se recoge la garra)
			var sheath := smoothstep(0.55, 0.9, u) if retractile else 0.0
			top.append(hgt * (0.92 + 0.32 * sheath) * (1.0 - 0.12 * smoothstep(0.9, 1.0, u)))
			bot.append(hgt * 0.78)
			zz.append(half_w * (1.0 - 0.18 * smoothstep(0.6, 1.0, u)))
			ao.append(1.0 - 0.25 * CareKit.gauss(u, 0.0, 0.15))
		var dg_arrays := CareKit.limb({ "spine": sp, "up": Vector3.UP, "ring": ring, "ry_top": top, "ry_bot": bot, "rz": zz,
			"n_top": 2.2, "n_bot": 2.6, "ao": ao, "cap_end": true, "cap_k": 0.75, "ao_under": 0.35 })
		skin_parts.append(dg_arrays)
		fur_parts.append(CareKit.shells(dg_arrays, layers))
		# la almohadilla del dedo, bajo su última falange, apoyada en la mesa
		var pc := b + dir * dl * 0.68
		pad_parts.append(CareKit.blob(Vector3(pc.x, float(e[5]) * 0.55 * mm, pc.z), Vector3(half_w * 1.0, hgt * 0.55, half_w * 0.86),
			Basis(Vector3.UP, -ang * side), ring / 2 + 6, 10 if hi else 6, { "zone": 1.0, "ao_under": 0.1 }))
		# la garra: sale de la punta del dedo, hacia delante y hacia abajo (fuera); recogida, dentro de la vaina
		var t_end := (sp[n - 1] - sp[n - 2]).normalized()
		var up_end := (Vector3.UP - t_end * Vector3.UP.dot(t_end)).normalized()
		var out_at := sp[n - 1] - t_end * hgt * 0.35 + up_end * hgt * 0.38
		var out_x := (t_end * cos(deg_to_rad(-18.0)) + up_end * sin(deg_to_rad(-18.0))).normalized()
		slots[dg] = _frame(out_at, out_x, up_end)
		if retractile:
			var in_x := (t_end * cos(deg_to_rad(58.0)) + up_end * sin(deg_to_rad(58.0))).normalized()
			protract[dg] = _frame(out_at - t_end * dl * 0.45 + up_end * hgt * 0.25, in_x, up_end)
	if retractile and not hind:
		# el espolón (dedo I), en la cara de dentro de la muñeca, sin apoyar
		var dw := wrist + Vector3(6.0, -10.0, -float(dors[2]) * 0.82 * side) * mm
		var dw_sp := CareKit.spine(PackedVector3Array([dw, dw + Vector3(16.0, -6.0, -6.0 * side) * mm]), 8 if hi else 5)
		var dw_arrays := CareKit.limb({ "spine": dw_sp, "up": Vector3.UP, "ring": ring / 2 + 4, "ry_top": CareKit.filled(dw_sp.size(), 7.0 * mm),
			"ry_bot": CareKit.filled(dw_sp.size(), 6.0 * mm), "rz": CareKit.filled(dw_sp.size(), 7.0 * mm), "cap_start": true, "cap_end": true })
		skin_parts.append(dw_arrays)
		fur_parts.append(CareKit.shells(dw_arrays, layers))
	var aabb := _aabb_of(skin_parts + pad_parts)
	var parts := {
		"skin": { "arrays": CareKit.merge(skin_parts), "mat": "claw_skin" },
		"pads": { "arrays": CareKit.merge(pad_parts), "mat": "pad" },
		"fur": { "arrays": CareKit.merge(fur_parts), "mat": "fur" },
		"fur_arm": { "arrays": CareKit.merge(arm_parts), "mat": "fur_arm" },
	}
	return { "parts": parts, "slots": slots, "protract": protract, "model_claws": model_claws,
		"anchor": _frame(elbow, wrist - elbow, Vector3.UP), "center": Vector3(0.0, float(dors[1]) * mm, 0.0), "aabb": aabb }


# ─────────────────────────────── el velocirraptor ───────────────────────────────

## El pie del velocirraptor tumbado: el metatarso en la mesa, los dedos III y IV hacia delante con sus garras pequeñas,
## el I detrás y el II levantado con la garra en hoz (la que se trabaja), con escamas; en la reconstrucción, plumas
## pequeñas en lo alto del metatarso.
static func _theropod(art: String, claw: Dictionary, side: float, lod: String, mobile: bool) -> Dictionary:
	var dd: Dictionary = DINO.get(art, DINO.velociraptor)
	var base_r := float(claw.base_r_mm) * MM
	var s := base_r / (DINO_BASE_REF * MM)
	var mm := MM * s
	var hi := lod == "hi"
	var ring := 30 if hi else 12
	var n_st := 26 if hi else 11
	var layers := int(FUR_LAYERS.movil if mobile else FUR_LAYERS[lod])
	var skin_parts: Array = []
	var plume_parts: Array = []
	var center := Vector3(0.0, 15.0, 0.0) * mm
	# el metatarso, del tobillo (atrás y arriba) al pie
	var m_pts := PackedVector3Array([Vector3(-100.0, 30.0, 0.0) * mm, Vector3(-50.0, 21.0, 0.0) * mm, center + Vector3(6.0, 0.0, 0.0) * mm])
	var m_sp := CareKit.spine(m_pts, 16 if hi else 8)
	var mn := m_sp.size()
	var m_top := PackedFloat32Array()
	var m_z := PackedFloat32Array()
	for i in mn:
		var u := float(i) / float(mn - 1)
		m_top.append((15.0 + 4.0 * CareKit.gauss(u, 0.0, 0.15) + 3.0 * CareKit.gauss(u, 1.0, 0.15)) * mm)
		m_z.append((12.5 + 3.0 * CareKit.gauss(u, 1.0, 0.2)) * mm)
	var meta := CareKit.limb({ "spine": m_sp, "up": Vector3.UP, "ring": ring, "ry_top": m_top, "ry_bot": m_top, "rz": m_z,
		"n_top": 2.3, "cap_start": true, "cap_end": false, "dorsal": 0.18, "ventral": 0.14 })
	skin_parts.append(meta)
	if bool(dd.feathers):
		plume_parts.append(CareKit.shells(_trim_limb(meta, 0.0, 0.55), layers))
	# la planta
	skin_parts.append(CareKit.blob(center + Vector3(4.0, -3.0, 0.0) * mm, Vector3(24.0, 12.0, 21.0) * mm, Basis.IDENTITY, ring, 14 if hi else 8,
		{ "pad": 1.0, "ao_under": 0.2 }))
	var slots := {}
	var model_claws: Array = []
	# [ángulo, largo, radio en la base, radio en la punta, falanges, levantado (°) en cada articulación, garra (mm)]
	var toes := {
		"III": [2.0, 82.0, 10.0, 6.5, 3, -6.0, 34.0], "IV": [24.0, 70.0, 9.0, 6.0, 4, -6.0, 28.0],
		"I": [200.0, 22.0, 6.0, 4.5, 1, -25.0, 14.0],
	}
	for dg: String in toes:
		var e: Array = toes[dg]
		var ang := deg_to_rad(float(e[0]))
		var dir := Vector3(cos(ang), 0.0, sin(ang) * side)
		var start := center + dir * 10.0 * mm + Vector3(0.0, (12.0 if dg != "I" else 22.0), 0.0) * mm
		if dg == "I":
			start = center + Vector3(-38.0, 20.0, -9.0 * side) * mm
		var pts := PackedVector3Array([start])
		var p := start
		var nph := int(e[4])
		var pitch := deg_to_rad(float(e[5]))
		for k in nph:
			p += (dir * cos(pitch) + Vector3.UP * sin(pitch)).normalized() * float(e[1]) * mm / float(nph)
			pts.append(p)
			pitch += deg_to_rad(-7.0)
		var sp := CareKit.spine(pts, n_st if dg != "I" else 8)
		var n := sp.size()
		var top := PackedFloat32Array()
		var bot := PackedFloat32Array()
		var zz := PackedFloat32Array()
		var pad := PackedFloat32Array()
		for i in n:
			var u := float(i) / float(n - 1)
			var pd := 0.0
			for k in range(1, nph + 1):
				pd = maxf(pd, CareKit.gauss(u, float(k) / float(nph) - 0.08, 0.08))
			var rr := lerpf(float(e[2]), float(e[3]), u) * mm
			top.append(rr * 0.92)
			bot.append(rr * (0.82 + 0.35 * pd))
			zz.append(rr * 1.05)
			pad.append(pd)
		skin_parts.append(CareKit.limb({ "spine": sp, "up": Vector3.UP, "ring": ring, "ry_top": top, "ry_bot": bot, "rz": zz,
			"n_top": 2.3, "pad": pad, "cap_end": true, "cap_k": 0.6, "dorsal": 0.15, "ventral": 0.2 }))
		var t_end := (sp[n - 1] - sp[n - 2]).normalized()
		var up_end := (Vector3.UP - t_end * Vector3.UP.dot(t_end)).normalized()
		var at := sp[n - 1] - t_end * float(e[3]) * 0.4 * mm
		var cxf := _frame(at, (t_end * cos(deg_to_rad(8.0)) + up_end * sin(deg_to_rad(8.0))), up_end)
		model_claws.append({ "digit": dg, "arrays": _model_claw(float(e[6]) * s, float(e[3]) * 0.8 * s, 0.75, ring), "xf": _model_claw_xf(cxf) })
	# el dedo II: dos falanges cortas y fuertes, levantadas, con la hoz al final
	var d2_dir := Vector3(cos(deg_to_rad(-14.0)), 0.0, sin(deg_to_rad(-14.0)) * side)
	var a := center + d2_dir * 8.0 * mm + Vector3(0.0, 16.0, 0.0) * mm
	var b := a + (d2_dir * cos(deg_to_rad(32.0)) + Vector3.UP * sin(deg_to_rad(32.0))) * 30.0 * mm
	var c := b + (d2_dir * cos(deg_to_rad(74.0)) + Vector3.UP * sin(deg_to_rad(74.0))) * 24.0 * mm
	var sp2 := CareKit.spine(PackedVector3Array([a, b, c]), n_st)
	var n2 := sp2.size()
	var top2 := PackedFloat32Array()
	var bot2 := PackedFloat32Array()
	var z2 := PackedFloat32Array()
	var pad2 := PackedFloat32Array()
	for i in n2:
		var u := float(i) / float(n2 - 1)
		var rr := lerpf(12.0, base_r / mm * 1.1, smoothstep(0.4, 1.0, u)) * mm
		var pd := CareKit.gauss(u, 0.52, 0.1)
		top2.append(rr * 0.95)
		bot2.append(rr * (0.85 + 0.3 * pd))
		z2.append(rr * 0.92)
		pad2.append(pd)
	skin_parts.append(CareKit.limb({ "spine": sp2, "up": Vector3.UP, "ring": ring, "ry_top": top2, "ry_bot": bot2, "rz": z2,
		"n_top": 2.3, "pad": pad2, "cap_end": true, "cap_k": 0.55, "dorsal": 0.15, "ventral": 0.2 }))
	var t2 := (sp2[n2 - 1] - sp2[n2 - 2]).normalized()
	# la hoz parte hacia arriba y algo hacia delante, y se curva hacia delante y abajo: su cara de arriba (la de fuera
	# de la curva) mira hacia atrás
	var fwd := (d2_dir - t2 * d2_dir.dot(t2)).normalized()
	var x2 := (t2 * cos(deg_to_rad(-22.0)) + fwd * sin(deg_to_rad(22.0))).normalized()
	var up2 := -(fwd - x2 * fwd.dot(x2)).normalized()
	slots["II"] = _frame(sp2[n2 - 1] - t2 * base_r * 0.3, x2, up2)
	var aabb := _aabb_of(skin_parts)
	var parts := { "skin": { "arrays": CareKit.merge(skin_parts), "mat": "skin" } }
	if not plume_parts.is_empty():
		parts["plume"] = { "arrays": CareKit.merge(plume_parts), "mat": "plume" }
	return { "parts": parts, "slots": slots, "model_claws": model_claws, "anchor": _frame(m_pts[0], m_pts[1] - m_pts[0], Vector3.UP),
		"center": center, "aabb": aabb }
