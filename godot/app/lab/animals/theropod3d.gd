## Los velocirraptores del coche en marcha en 3D (unidad 4l), en centímetros de su anatomía: los pies en el origen, el
## hocico hacia +x, la y hacia arriba y el lado de quien mira hacia +z. Dos variantes del dibujo (no son otra física):
##   - «reconstruccion»: Velociraptor mongoliensis como lo reconstruyen los fósiles (core/lab/velociraptor.gd y
##     docs/fisica/velociraptor.md): 0,5 m a la cadera y 2,07 m del hocico a la punta de la cola (Paul 1988); fémur de
##     23,8 cm, tibia de 25,5 cm y metatarso III de 9,9 cm (Norell & Makovicky 1999, IGM 100/986), flexionados de pie; el
##     cráneo largo y bajo, de ~25 cm, con el perfil del hocico cóncavo. Con plumas (las papilas de las remeras del
##     cúbito: Turner et al. 2007): de contorno por todo el cuerpo, remeras en el antebrazo y la mano (unas alas
##     pequeñas, plegadas) y un abanico de rectrices en la cola, que es rígida (las varillas de las vértebras la
##     atiesan: Ostrom 1969); escamas en los pies y el hocico; los dientes tapados por los labios (Cullen et al. 2023).
##     El pie es didáctilo: apoya en los dedos III y IV y lleva el II levantado con la garra en hoz, del largo y el arco
##     de la garra del catálogo (Data.CLAWS «velociraptor»: 9,3 cm de queratina, ~150°). Colores: los de su ficha
##     (dino.colors, «dibujo») y los que faltan, dibujo;
##   - «pelicula» (ficción): un diseño original inspirado en los raptores del cine de los 90, sin copiar ninguno: del
##     tamaño de Deinonychus (0,87 m a la cadera y 3,4 m: Ostrom 1969; Paul 1988), sin plumas, de piel escamosa pardo
##     oliva con bandas oscuras irregulares en el lomo y la cola, una hilera de escudos en el espinazo, la cabeza larga y
##     cuadrada con la ceja ósea marcada y el ojo de pupila rasgada, los dientes a la vista, manos de tres dedos con
##     garras largas y la hoz levantada; la garra, la del catálogo («velociraptor_pelicula») o, mientras no esté, 12 cm.
## Posturas: de pie (la de referencia: el tamaño del estado es la cadera de pie y el largo con la cola, y la cabeza
## sobresale), agazapado («tumbado»: la cadera más baja, el cuello recogido, listo para saltar) y el salto (pose.leap o
## pose.kick, el que manda la vista en el golpe: se estira hacia arriba con las patas por delante y las hoces abajo, los
## brazos abiertos y la boca abierta). Las demás
## medidas (grosores, brazos, plumas, colores) son dibujo. Solo dibujo.
extends RefCounted

const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Loft = preload("res://app/lab/animals/loft.gd")
const Mats3D = preload("res://app/lab/animals/mats3d.gd")
const Tex3D = preload("res://app/lab/animals/tex3d.gd")
const Mammals3D = preload("res://app/lab/animals/mammals3d.gd")
const Cassowary3D = preload("res://app/lab/animals/cassowary3d.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const Rng = preload("res://core/shared/rng.gd")

## Un trozo del mapa del patrón que siempre está en blanco (para las piezas sin patrón).
const BLANK_UV := Rect2(0.62, 0.8, 0.3, 0.15)
## Las dos variantes del dibujo.
const VARIANTS := ["pelicula", "reconstruccion"]


## La variante del dibujo: la del id («velociraptor_pelicula», el de cine) o la de opts.variant (la de MovingCar.BODIES
## y de MovingCarState.draw_size()); si no dice, la reconstrucción con el id «velociraptor» y, sin id, la de película
## (como en la 4h).
static func variant_of(opts: Dictionary, id := "") -> String:
	if id == "velociraptor_pelicula":
		return "pelicula"
	var v := String(opts.get("variant", ""))
	if VARIANTS.has(v):
		return v
	return "reconstruccion" if id == "velociraptor" else "pelicula"


## Las medidas (cm) de cada variante. Articulaciones de la pata de quien mira (la otra, con z cambiada); radios de los
## tramos de la pata [delante, detrás, lado] al principio, en medio y al final; estaciones del tronco, el cuello, la
## cabeza, la mandíbula y la cola [x, y, arriba, abajo, lado]; el ojo [x, y, z, radio]; el brazo (hombro, codo y
## muñeca) y sus radios [hombro, codo, muñeca, dedo]; largo de los dedos [I, II, III] y de sus garras.
static func params(v: String) -> Dictionary:
	if v == "pelicula":
		return {
			"film": true,
			"hip": Vector3(0, 87, 11.0), "knee": Vector3(22, 55.5, 12.5), "ankle": Vector3(-4, 21, 11.0), "mtp": Vector3(4, 4.2, 10.5),
			"thigh": [[15.5, 17.0, 11.5], [12.5, 14.5, 10.0], [7.6, 8.4, 6.8]],
			"shin": [[7.2, 8.8, 6.4], [5.0, 6.6, 4.6], [2.7, 2.9, 2.7]],
			"meta": [[2.9, 2.7, 2.7], [2.4, 2.3, 2.4], [2.5, 2.3, 2.9]],
			"toes": [15.0, 13.0], "toe_r": 2.0, "toe_claw": 4.4, "hallux": 4.0, "sickle_hw": Vector2(3.3, 1.5),
			"body": [[-24.0, 93.0, 10.0, 11.0, 9.5], [-8.0, 94.0, 14.0, 17.0, 14.5], [10.0, 92.5, 15.0, 22.0, 16.0], [28.0, 91.5, 14.0, 21.0, 15.0],
				[44.0, 94.0, 12.0, 15.0, 12.5], [56.0, 99.0, 9.0, 10.0, 9.5]],
			"neck": [[54.0, 99.0, 10.0, 11.0, 9.5], [64.0, 108.0, 8.2, 8.8, 7.6], [72.0, 118.0, 7.2, 7.8, 6.6], [79.0, 125.0, 6.8, 7.2, 6.3]],
			"head": [[77.0, 127.5, 7.6, 7.6, 7.4, 2.3], [85.0, 129.5, 8.2, 8.0, 7.6, 2.5], [95.0, 127.4, 6.6, 7.0, 6.2, 2.6], [105.0, 125.0, 5.4, 6.0, 5.0, 2.6],
				[114.0, 122.8, 4.4, 4.8, 4.0, 2.5], [121.5, 121.4, 3.0, 3.4, 2.8, 2.3]],
			"jaw": [[82.0, 121.5, 3.0, 4.6, 6.2], [100.0, 118.6, 2.4, 3.6, 4.6], [119.0, 117.4, 1.6, 2.2, 2.6]],
			"eye": [90.0, 130.4, 5.6, 1.9],
			"tail": [[-20.0, 96.0, 11.0, 12.0, 10.0], [-70.0, 95.0, 7.0, 7.5, 6.0], [-130.0, 92.5, 4.2, 4.5, 3.6], [-185.0, 90.5, 2.3, 2.5, 2.0],
				[-215.0, 89.5, 0.8, 0.8, 0.7]],
			"shoulder": Vector3(50, 90, 12.5), "elbow": Vector3(43, 72, 15.5), "wrist": Vector3(63, 63, 16.0),
			"arm": [6.0, 3.8, 2.6, 1.25], "fingers": [9.0, 13.5, 11.0], "hand_claws": [5.5, 7.5, 6.0],
		}
	return {
		"film": false,
		"hip": Vector3(0, 50, 6.5), "knee": Vector3(13.5, 30.5, 7.0), "ankle": Vector3(-2.5, 11.0, 6.2), "mtp": Vector3(2.5, 2.4, 5.8),
		"thigh": [[8.2, 9.2, 6.2], [7.0, 8.0, 5.6], [4.0, 4.5, 3.7]],
		"shin": [[3.9, 4.6, 3.5], [2.8, 3.5, 2.6], [1.35, 1.45, 1.35]],
		"meta": [[1.45, 1.35, 1.35], [1.2, 1.15, 1.2], [1.25, 1.15, 1.45]],
		"toes": [8.5, 7.5], "toe_r": 1.0, "toe_claw": 2.4, "hallux": 2.2, "sickle_hw": Vector2(2.3, 1.0),
		"body": [[-14.0, 54.5, 6.0, 6.5, 6.0], [-4.0, 55.0, 8.0, 10.0, 8.5], [6.0, 53.5, 8.5, 13.0, 9.5], [16.0, 52.5, 8.0, 14.0, 9.5],
			[25.0, 53.0, 7.0, 11.5, 8.5], [32.0, 55.5, 5.5, 7.5, 6.5]],
		"neck": [[30.0, 56.0, 6.0, 6.5, 5.5], [37.0, 61.0, 4.6, 5.0, 4.2], [42.0, 66.5, 3.9, 4.2, 3.6], [46.0, 70.5, 3.6, 3.8, 3.4]],
		"head": [[45.5, 72.0, 4.2, 4.4, 4.0, 2.3], [50.0, 72.6, 4.6, 4.6, 4.2, 2.4], [55.0, 71.6, 3.4, 3.8, 3.0, 2.5], [61.0, 70.4, 2.4, 2.9, 2.1, 2.6],
			[67.0, 70.4, 2.2, 2.3, 1.7, 2.6], [73.2, 70.9, 1.4, 1.6, 1.1, 2.4]],
		"jaw": [[49.0, 68.7, 1.6, 2.0, 2.3], [60.0, 68.1, 1.2, 1.5, 1.55], [72.0, 68.8, 0.7, 0.9, 0.8]],
		"eye": [51.5, 73.4, 3.0, 1.45],
		"tail": [[-8.0, 56.0, 6.0, 7.0, 5.5], [-40.0, 55.5, 3.5, 3.8, 3.0], [-75.0, 54.5, 2.2, 2.4, 1.8], [-105.0, 53.8, 1.4, 1.5, 1.2],
			[-132.0, 53.2, 0.6, 0.6, 0.5]],
		"shoulder": Vector3(27, 50, 7.5), "elbow": Vector3(21, 39.5, 9.0), "wrist": Vector3(32, 34.5, 9.5),
		"arm": [3.2, 2.0, 1.4, 0.65], "fingers": [4.5, 7.0, 6.0], "hand_claws": [3.0, 4.0, 3.2],
	}


## Colores (dibujo). La reconstrucción, los de su ficha (dino.colors: body, feathers, claw) y los que faltan; el de
## película, los de la 4h.
static func colors(v: String) -> Dictionary:
	if v == "pelicula":
		return { "skin": Color("#7f7148"), "skin_hi": Color("#a99a6a"), "skin_lo": Color("#4f4529"), "stripe": Color("#2E261A"),
			"belly": Color("#cbbd92"), "rust": Color("#A8643A"), "claw": Color("#24201D"), "teeth": Color("#EDE3CC"), "eye": Color("#E1A12A"),
			"mouth": Color("#6e302c"), "scute": Color("#4e432c") }
	var cols: Dictionary = Velociraptor.ENTRY.get("dino", {}).get("colors", {})
	return { "body": Color(String(cols.get("body", "#8A6F4E"))), "feathers": Color(String(cols.get("feathers", "#5B4A3A"))),
		"claw": Color(String(cols.get("claw", "#4A3F35"))), "belly": Color("#C9B38C"), "mask": Color("#3E3024"), "scale": Color("#6E5E4C"),
		"eye": Color("#c08a30"), "mouth": Color("#6e3a32") }


## La garra en hoz: largo (cm) del catálogo (como la física) y su arco medido (CareData.claw_arc, por Mammals3D.claw_of:
## unidad 5p); el de película, mientras no esté en el catálogo, 12 cm con el arco de la reconstrucción.
static func sickle_of(v: String) -> Vector2:
	var id := "velociraptor_pelicula" if v == "pelicula" else "velociraptor"
	if Catalog.find_by_id(Catalog.CLAWS, id) != null:
		return Mammals3D.claw_of(id)
	return Vector2(12.0, float(Mammals3D.CareData.claw_arc("velociraptor").arcDeg))


## El modelo (lo que se guarda en la caché).
static func make(v: String, mobile: bool, cache: Dictionary) -> Dictionary:
	var P := params(v)
	var C := colors(v)
	var film := bool(P.film)
	var m := Rig3D.Model.new(0.0 if mobile else 1.0)
	var px := 64 if mobile else 128
	var pat := _pattern(v, mobile, cache)
	if film:
		m.mats["escama"] = Mats3D.surface("escama", mobile, cache, { "pattern": pat, "rough": 0.56, "spec": 0.4, "rim": 0.16, "wobble": 0.0 })
		m.mats["diente"] = Mats3D.surface("queratina", mobile, cache, { "rough": 0.35, "spec": 0.5, "wobble": 0.0 })
	else:
		m.mats["pluma"] = Mats3D.surface("pluma", mobile, cache, { "pattern": pat, "wobble": 0.003 })
		m.mats["plumon"] = Mats3D.surface("plumon", mobile, cache, { "rough": 0.9, "wobble": 0.004 })
		m.mats["escama"] = Mats3D.surface("escama", mobile, cache, { "rough": 0.6, "wobble": 0.0 })
		m.mats["remera"] = Mats3D.cards(Tex3D.card_tex("rectriz", px * 2, cache, 2), { "raise": 0.0, "wobble": 0.008 })
		m.mats["rectriz"] = Mats3D.cards(Tex3D.card_tex("rectriz", px * 2, cache, 4), { "raise": 0.0, "wobble": 0.01 })
		m.mats["cobertera"] = Mats3D.cards(Tex3D.card_tex("cobertera", px, cache), { "raise": 0.02, "wobble": 0.006 })
	m.mats["escudo"] = Mats3D.surface("escudo", mobile, cache, { "rough": 0.5, "spec": 0.45, "wobble": 0.0 })
	m.mats["piel"] = Mats3D.surface("piel", mobile, cache, { "rough": 0.55, "wobble": 0.0 })
	m.mats["unas"] = Mats3D.surface("queratina", mobile, cache, { "rough": 0.32, "spec": 0.55, "wobble": 0.0 })
	m.mats["garra"] = Mats3D.claw(mobile, cache)
	m.mats["ojo"] = Mats3D.eye(C.eye, { "iris_r": 0.33, "pupil_r": 0.17 if film else 0.14, "pupil_sx": 0.34 if film else 1.0,
		"sclera": (C.eye as Color).darkened(0.35) })
	var made := 1
	for key: String in m.mats:
		made += int(m.mats[key].get("made", 0))
	var hip: Vector3 = P.hip
	var hc := Vector3(hip.x, hip.y, 0)
	m.bone("postura", "", Vector3.ZERO)
	m.bone("cuerpo", "postura", hc)
	m.bone("torso", "cuerpo", hc)
	m.bone("erizado", "torso", hc)
	m.bone("plumas", "torso", hc)
	m.fit_skip.append("erizado")
	m.fit_skip.append("plumas")
	var nk: Array = P.neck
	m.bone("cuello", "cuerpo", Vector3(nk[0][0], nk[0][1], 0))
	var hd: Array = P.head
	m.bone("cabeza", "cuello", Vector3(float(hd[0][0]) + 1.0, float(hd[0][1]) - 1.5, 0))
	var jw: Array = P.jaw
	m.bone("mandibula", "cabeza", Vector3(jw[0][0], float(jw[0][1]) + 0.6, 0))
	_body(m, P, C)
	_neck_head(m, P, C)
	_tail(m, P, C)
	for s: float in [1.0, -1.0]:
		_arm(m, P, C, s)
		_leg(m, P, C, s, v)
	_postures(m, P)
	m.anchors["eye"] = ["cabeza", Vector3(P.eye[0], P.eye[1], 0)]
	m.anchors["neck"] = ["cuello", Vector3(nk[0][0], nk[0][1], 0)]
	m.anchors["hip"] = ["cuerpo", hc]
	m.anchors["tail"] = ["cola0", Vector3(P.tail[0][0], P.tail[0][1], 0)]
	m.anchors["shoulder"] = ["cuerpo", Vector3((P.shoulder as Vector3).x, (P.shoulder as Vector3).y, 0)]
	m.info = { "kind": "teropodo", "ref_posture": "de_pie", "claw_natural": C.claw, "textures": made, "variant": v, "film": film }
	var data := m.finish()
	# la caja de referencia: del hocico a la punta de la cola y del suelo a la cadera (la cabeza sobresale)
	var box := Rig3D.posed_box(data, Rig3D.globals(data, {}), m.fit_skip)
	data.fit = AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, hip.y, box.size.z))
	return data


## El mapa del patrón (512 × 1024 en el escritorio): el tronco arriba (x alrededor: 0 y 1 el vientre, 0,5 el lomo; y de
## la grupa al cuello) y la cola abajo a la izquierda (y de la base a la punta); el resto, blanco. Gris sobre blanco: el
## color lo dan los vértices.
static func _pattern(v: String, mobile: bool, cache: Dictionary) -> ImageTexture:
	var w := 256 if mobile else 512
	var k := float(w) / 512.0
	var b := PackedStringArray()
	var rng := Rng.new(Rng.seed_of("teropodo:" + v))
	if v == "pelicula":
		# bandas oscuras e irregulares que bajan del lomo por los costados, y motas
		var ink := Tex3D.hex(Color(0.3, 0.28, 0.25))
		for i in 9:
			var y := (36.0 + 52.0 * float(i) + (rng.next() - 0.5) * 16.0) * k
			var y2 := y + (rng.next() - 0.5) * 26.0 * k
			b.append(Tex3D.spindle(Vector2(112.0 * k, y), Vector2(400.0 * k, y2), (14.0 + 9.0 * rng.next()) * k, ink, 0.07 * (rng.next() - 0.5)))
		for i in 46:
			var u := 0.12 + 0.24 * rng.next()
			if i % 2 == 1:
				u = 1.0 - u
			var y := (20.0 + 470.0 * rng.next()) * k
			b.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"%s\"/>" % [Tex3D._n(u * 512.0 * k), Tex3D._n(y), Tex3D._n((3.0 + 3.0 * rng.next()) * k),
				Tex3D._n((4.0 + 4.0 * rng.next()) * k), Tex3D.hex(Color(0.5, 0.47, 0.42))])
		for i in 11:
			var y := (512.0 + 26.0 + 42.0 * float(i) + (rng.next() - 0.5) * 10.0) * k
			b.append(Tex3D.spindle(Vector2(-24.0 * k, y), Vector2(280.0 * k, y + (rng.next() - 0.5) * 18.0 * k), (15.0 + 7.0 * rng.next()) * k, ink,
				0.05 * (rng.next() - 0.5)))
	else:
		# barras suaves en el lomo y anillos en la cola (como muchas aves de presa)
		for i in 10:
			var y := (40.0 + 46.0 * float(i)) * k
			b.append(Tex3D.spindle(Vector2(150.0 * k, y), Vector2(362.0 * k, y + 6.0 * k), 9.0 * k, Tex3D.hex(Color(0.7, 0.68, 0.66))))
		for i in 9:
			var y := (512.0 + 34.0 + 52.0 * float(i)) * k
			b.append("<rect x=\"0\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\"/>" % [Tex3D._n(y), Tex3D._n(256.0 * k), Tex3D._n(17.0 * k),
				Tex3D.hex(Color(0.52, 0.5, 0.48))])
	return Tex3D.pattern("teropodo|%s|%d" % [v, w], w, w * 2, "".join(b), cache)


## El tronco: plumas (la reconstrucción: el lomo oscuro, el vientre claro, plumas de contorno sueltas en los costados y
## las del lomo que se erizan) o escamas (el de película: con la hilera de escudos del espinazo).
static func _body(m: Rig3D.Model, P: Dictionary, C: Dictionary) -> void:
	var film := bool(P.film)
	var k := float((P.hip as Vector3).y) / 50.0
	var st: Array = []
	for e: Array in P.body:
		st.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	if film:
		var skin := func(_s01: float, u: float, _p: Vector3) -> Color:
			var belly := 1.0 - smoothstep(0.1, 0.27, minf(u, 1.0 - u))
			var top := 1.0 - smoothstep(0.0, 0.18, absf(u - 0.5))
			return Color((C.skin as Color).lerp(C.skin_lo, 0.4 * top).lerp(C.belly, belly), 0.0)
		m.loft("torso", "escama", st, { "segs": 28, "rings": 18, "paint": skin, "tile": 6.0, "uv_rect": Rect2(0, 0, 1, 0.5) })
		var n := 12 if m.detail > 0.5 else 7
		for i in n:
			var x := lerpf(-20.0, 52.0, (float(i) + 0.5) / float(n))
			var e := Rig3D.section_of(st, x)
			_ridge(m, "torso", Vector3(x, e.x + e.y - 0.45 * k, 0), Vector3(1, 0, 0), 2.2 * k, 1.2 * k, 0.8 * k, C.scute)
		return
	var plume := func(_s01: float, u: float, _p: Vector3) -> Color:
		var belly := 1.0 - smoothstep(0.08, 0.25, minf(u, 1.0 - u))
		var top := 1.0 - smoothstep(0.04, 0.24, absf(u - 0.5))
		return Color((C.body as Color).lerp(C.feathers, top).lerp(C.belly, belly), 0.5 + 0.3 * top)
	m.loft("torso", "pluma", st, { "segs": 26, "rings": 16, "paint": plume, "tile": 7.0, "uv_rect": Rect2(0, 0, 1, 0.5), "flip_v": true })
	# plumas de contorno sueltas en los costados: rompen la silueta lisa
	var rows: Array = [1.15, 1.5, 1.85, 2.2] if m.detail > 0.5 else [1.3, 2.0]
	var step := 4.0 if m.detail > 0.5 else 7.0
	var ci := 0
	var x := -10.0
	while x <= 28.0:
		for s: float in [1.0, -1.0]:
			for th: float in rows:
				ci += 1
				var srf := Rig3D.surface_of(st, x + 1.2 * sin(float(ci) * 7.1), th + 0.05 * sin(float(ci) * 3.7), s)
				var p: Vector3 = srf[0]
				var nn: Vector3 = srf[1]
				var down: Vector3 = srf[2]
				var ax := (down * 0.55 + Vector3(-0.85, 0, 0)).normalized() * (6.0 + 2.5 * absf(sin(float(ci) * 2.3)))
				var col: Color = (C.body as Color).lerp(C.belly, smoothstep(1.6, 2.4, th)).lerp(C.feathers, 0.3 * absf(sin(float(ci) * 5.1)))
				Mammals3D._card(m, "plumas", "cobertera", p - ax * 0.3 + nn * 0.15, ax, nn.cross(ax.normalized()).normalized() * 3.0, nn, col)
		x += step
	# el erizado: las plumas del lomo, que se levantan con miedo (escondidas si no)
	var nb := 10 if m.detail > 0.5 else 6
	for i in nb:
		var xx := lerpf(-8.0, 30.0, float(i) / float(nb - 1))
		for s: float in [1.0, -1.0]:
			var srf := Rig3D.surface_of(st, xx, 0.4, s)
			var p: Vector3 = srf[0]
			var nn: Vector3 = srf[1]
			var ax := Vector3(-0.85, 0.35, 0.25 * s).normalized() * 6.5
			Mammals3D._card(m, "erizado", "cobertera", p, ax, nn.cross(ax.normalized()).normalized() * 3.2, nn, (C.feathers as Color).lerp(C.body, 0.3))


## Un escudo en cresta (una lente baja sobre la piel): centro c, eje a lo largo, semilargo, alto y ancho.
static func _ridge(m: Rig3D.Model, b: String, c: Vector3, axis: Vector3, half: float, h: float, w: float, col: Color) -> void:
	var d := axis.normalized()
	m.loft(b, "escudo", [[c - d * half, 0.04, 0.04, 0.04], [c - d * half * 0.2, h, h * 0.3, w], [c + d * half, 0.04, 0.04, 0.04]],
		{ "segs": 6, "rings": 3, "cap0": "point", "cap1": "point", "col": Color(col, 1.0), "side": Vector3.BACK if d.x >= 0.0 else Vector3.FORWARD,
		"tile": 2.0 })


## El cuello, la cabeza (la reconstrucción: plumas hasta el hocico escamoso, el antifaz oscuro por el ojo, los labios
## que tapan los dientes; el de película: escamas, el hocico rojizo, la ceja ósea y los dientes), la mandíbula con la
## lengua, los ojos con su párpado y los orificios de la nariz.
static func _neck_head(m: Rig3D.Model, P: Dictionary, C: Dictionary) -> void:
	var film := bool(P.film)
	var k := float((P.hip as Vector3).y) / 50.0
	var nst: Array = []
	for e: Array in P.neck:
		nst.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var hst: Array = []
	for e: Array in P.head:
		hst.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4], e[5] if e.size() > 5 else 2.0])
	var jst: Array = []
	for e: Array in P.jaw:
		jst.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var eye: Array = P.eye
	var ex := float(eye[0])
	var tip_x := (hst[hst.size() - 1][0] as Vector3).x
	if film:
		var neck_paint := func(_s01: float, u: float, _p: Vector3) -> Color:
			var throat := 1.0 - smoothstep(0.08, 0.25, minf(u, 1.0 - u))
			var top := 1.0 - smoothstep(0.0, 0.2, absf(u - 0.5))
			return Color((C.skin as Color).lerp(C.skin_lo, 0.35 * top).lerp(C.belly, throat), 0.0)
		m.loft("cuello", "escama", nst, { "segs": 22, "rings": 10, "paint": neck_paint, "tile": 5.0, "uv_rect": BLANK_UV })
		for i in (5 if m.detail > 0.5 else 3):
			var f := (float(i) + 0.5) / (5.0 if m.detail > 0.5 else 3.0)
			var c := _on_polyline(nst, f)
			var e: Array = c[1]
			var up: Vector3 = Vector3(0, 0, 1).cross(c[2] as Vector3).normalized()
			_ridge(m, "cuello", (c[0] as Vector3) + up * (float(e[1]) - 0.45 * k), c[2], 1.8 * k, 1.0 * k, 0.7 * k, C.scute)
		var head_paint := func(_s01: float, u: float, p: Vector3) -> Color:
			var top := 1.0 - smoothstep(0.0, 0.2, absf(u - 0.5))
			var low := 1.0 - smoothstep(0.06, 0.2, minf(u, 1.0 - u))
			var col: Color = (C.skin as Color).lerp(C.skin_lo, 0.3 * top)
			col = col.lerp(C.rust, top * smoothstep(ex + 4.0 * k, ex + 12.0 * k, p.x) * 0.7)
			var band := (1.0 - smoothstep(0.025, 0.07, absf(minf(u, 1.0 - u) - 0.29))) * smoothstep(ex - 13.0 * k, ex - 4.0 * k, p.x) * (1.0 - smoothstep(ex - 2.0 * k, ex, p.x))
			col = col.lerp(C.stripe, band * 0.8).lerp(C.belly, low * 0.55)
			var palate := (1.0 - smoothstep(0.0, 0.05, minf(u, 1.0 - u))) * smoothstep(ex, ex + 4.0 * k, p.x)
			return Color(col.lerp(C.mouth, palate), 0.0)
		m.loft("cabeza", "escama", hst, { "segs": 26, "rings": 16, "paint": head_paint, "tile": 4.0, "uv_rect": BLANK_UV, "cap_len1": 2.2 * k })
	else:
		var neck_paint := func(_s01: float, u: float, _p: Vector3) -> Color:
			var throat := 1.0 - smoothstep(0.08, 0.25, minf(u, 1.0 - u))
			var top := 1.0 - smoothstep(0.04, 0.24, absf(u - 0.5))
			return Color((C.body as Color).lerp(C.feathers, top).lerp(C.belly, throat), 0.45)
		m.loft("cuello", "pluma", nst, { "segs": 20, "rings": 10, "paint": neck_paint, "tile": 2.6, "flip_v": true, "uv_rect": BLANK_UV })
		# la cabeza, emplumada hasta delante del ojo, con el antifaz oscuro; el hocico, de escamas, encima
		var face := func(_s01: float, u: float, p: Vector3) -> Color:
			var low := 1.0 - smoothstep(0.06, 0.2, minf(u, 1.0 - u))
			var top := 1.0 - smoothstep(0.0, 0.2, absf(u - 0.5))
			var col: Color = (C.body as Color).lerp(C.feathers, 0.7 * top)
			# el antifaz: una franja oscura por el ojo, que se apaga hacia la nuca
			var mask := (1.0 - smoothstep(0.03, 0.07, absf(minf(u, 1.0 - u) - 0.29))) * (1.0 - smoothstep(ex + 2.5, ex + 4.5, p.x)) * smoothstep(ex - 6.0, ex - 2.0, p.x)
			return Color(col.lerp(C.mask, mask * 0.85).lerp(C.belly, low * 0.6), 0.35)
		m.loft("cabeza", "pluma", hst, { "segs": 22, "rings": 14, "paint": face, "tile": 1.6, "flip_v": true, "cap_len1": 1.2, "uv_rect": BLANK_UV })
		var snout: Array = []
		for e: Array in hst:
			if (e[0] as Vector3).x >= ex + 2.5:
				snout.append([e[0], float(e[1]) + 0.05, float(e[2]) + 0.05, float(e[3]) + 0.05, e[4]])
		snout.insert(0, _station_at(hst, ex + 2.5, 0.0))
		var scales := func(_s01: float, u: float, _p: Vector3) -> Color:
			var low := 1.0 - smoothstep(0.06, 0.2, minf(u, 1.0 - u))
			var palate := 1.0 - smoothstep(0.0, 0.05, minf(u, 1.0 - u))
			return Color((C.scale as Color).lerp(C.belly, low * 0.4).lerp(C.mouth, palate), 0.0)
		m.loft("cabeza", "escama", snout, { "segs": 20, "rings": 10, "paint": scales, "tile": 1.4, "cap0": "none", "cap_len1": 1.25 })
		# una cresta baja de plumas en el cráneo y la nuca
		for i in (6 if m.detail > 0.5 else 3):
			var cx := ex - 0.5 - float(i) * (1.6 if m.detail > 0.5 else 3.2)
			var e := Rig3D.section_of(hst, cx)
			var ax := Vector3(-0.9, 0.42, 0.0).normalized() * (3.0 - 0.2 * float(i))
			Mammals3D._card(m, "cabeza", "cobertera", Vector3(cx, e.x + e.y - 0.5, 0.0), ax, Vector3(-ax.y, ax.x, 0.0).normalized() * 1.7,
				Vector3(0, 1, 0), (C.feathers as Color).darkened(0.15))
	# la mandíbula y la lengua (se ve al abrir la boca)
	var jaw_side: Color = C.skin if film else C.scale
	var jaw := func(_s01: float, u: float, _p: Vector3) -> Color:
		var top := 1.0 - smoothstep(0.0, 0.12, absf(u - 0.5))
		var low := 1.0 - smoothstep(0.08, 0.22, minf(u, 1.0 - u))
		return Color(jaw_side.lerp(C.belly, low * (0.8 if film else 0.4)).lerp(C.mouth, top), 0.0)
	m.loft("mandibula", "escama", jst, { "segs": 18, "rings": 10, "paint": jaw, "tile": 3.0 if film else 1.4, "uv_rect": BLANK_UV, "cap_len1": float(jst[jst.size() - 1][3]) })
	var tongue: Array = []
	for i in jst.size() - 1:
		var e: Array = jst[i]
		tongue.append([(e[0] as Vector3) + Vector3(0, float(e[1]) * 0.55, 0), float(e[1]) * 0.3, float(e[1]) * 0.3, float(e[3]) * 0.55])
	m.loft("mandibula", "piel", tongue, { "segs": 10, "rings": 4, "col": Color((C.mouth as Color).lightened(0.15), 1.0), "tile": 2.0 })
	if film:
		# los dientes, a la vista: los de arriba asoman por fuera de la mandíbula; los de abajo, al abrir la boca
		var nt := 9 if m.detail > 0.5 else 6
		for i in nt:
			var f := (float(i) + 0.5) / float(nt)
			var x := lerpf(ex + 4.0 * k, tip_x - 1.5 * k, f)
			var e := Rig3D.section_of(hst, x)
			var tl := lerpf(3.1, 2.0, f)
			for s: float in [1.0, -1.0]:
				_tooth(m, "cabeza", Vector3(x, e.x - e.z * 0.6, s * e.w * 0.76), Vector3(0, -1, 0.08 * s), tl, C.teeth)
		var x0 := (jst[0][0] as Vector3).x
		var x1 := (jst[jst.size() - 1][0] as Vector3).x
		for i in nt - 1:
			var f := (float(i) + 0.5) / float(nt - 1)
			var x := lerpf(lerpf(x0, x1, 0.4), x1 - 1.0 * k, f)
			var e := Rig3D.section_of(jst, x)
			var tl := lerpf(2.5, 1.7, f)
			for s: float in [1.0, -1.0]:
				_tooth(m, "mandibula", Vector3(x, e.x + e.y * 0.6, s * e.w * 0.62), Vector3(0, 1, 0.05 * s), tl, C.teeth)
	# los ojos (el de película, con la pupila rasgada), la ceja ósea y la nariz
	for s: float in [1.0, -1.0]:
		var c0 := Vector3(ex, eye[1], float(eye[2]) * s)
		var look := Vector3(0.28, 0.06, 0.96 * s).normalized()
		var lid_col: Color = C.skin_lo if film else C.mask
		_eye(m, c0, look, float(eye[3]), lid_col, film)
		if film:
			m.blob("cabeza", "escama", c0 + Vector3(0.8 * k, float(eye[3]) * 1.15, -0.1 * k * s), Vector3(1, -0.12, 0.06 * s), 4.0 * k, 0.9 * k, 0.6 * k, 1.1 * k,
				{ "col": Color((C.skin_lo as Color).lerp(C.rust, 0.25), 1.0), "uv_rect": BLANK_UV, "segs": 12 })
			# el oído: una abertura oscura detrás del ojo
			var ear := Rig3D.section_of(hst, ex - 10.0 * k)
			m.blob("cabeza", "piel", Vector3(ex - 10.0 * k, ear.x - 0.4 * k, s * ear.w * 0.93), Vector3(0, 1, 0), 0.9 * k, 0.5 * k, 0.5 * k, 0.25 * k,
				{ "col": Color(C.stripe, 1.0), "segs": 8 })
		var ns := Rig3D.section_of(hst, tip_x - 2.4 * k)
		m.blob("cabeza", "piel", Vector3(tip_x - 2.4 * k, ns.x + ns.y * 0.45, s * ns.w * 0.62), Vector3(1, 0.2, 0), 0.9 * k, 0.32 * k, 0.32 * k, 0.28 * k,
			{ "col": Color(0.08, 0.06, 0.05, 1.0), "segs": 8 })


## Una estación de un loft (estaciones [Vector3, arriba, abajo, lado] a lo largo de x) en x, con los radios crecidos grow.
static func _station_at(st: Array, x: float, grow: float) -> Array:
	var e := Rig3D.section_of(st, x)
	return [Vector3(x, e.x, 0), e.y + grow, e.z + grow, e.w + grow]


## Un diente (cono curvo de marfil, recurvado hacia la garganta): base, hacia dónde sale y largo (cm).
static func _tooth(m: Rig3D.Model, b: String, base: Vector3, dir: Vector3, len: float, col: Color) -> void:
	Loft.claw(m.acc(b), "diente", base, dir, Vector3(1, 0, 0), len, len * 0.5, len * 0.36, 22.0,
		{ "col": Color(col, 1.0), "segs": m.segs(8), "rings": m.rings(5), "stations": 5 })


## Punto a una fracción f del largo de unas estaciones: [punto, estación más cercana, tangente].
static func _on_polyline(st: Array, f: float) -> Array:
	var pts: Array = []
	for e: Array in st:
		pts.append(e[0])
	var p := Cassowary3D._along(pts, f)
	var best := 0
	for i in st.size():
		if (st[i][0] as Vector3).distance_to(p) < (st[best][0] as Vector3).distance_to(p):
			best = i
	var a := Cassowary3D._along(pts, maxf(f - 0.02, 0.0))
	var b := Cassowary3D._along(pts, minf(f + 0.02, 1.0))
	return [p, st[best], (b - a).normalized()]


## Ojo con su párpado (el casquete que se cierra al parpadear). slit: la pupila rasgada en vertical (el sombreador
## estrecha la pupila a lo largo de la costura del globo: aquí, de delante atrás).
static func _eye(m: Rig3D.Model, c: Vector3, look: Vector3, r: float, lid_col: Color, slit: bool) -> void:
	var sf := "_n" if c.z > 0.0 else "_f"
	m.bone("ojo" + sf, "cabeza", c)
	var across := Vector3.UP.cross(look).normalized()
	var side := (Vector3.UP - look * look.y).normalized() if slit else across
	m.loft("ojo" + sf, "ojo", [[c - look * r * 0.7, r * 0.7, r * 0.7, r * 0.7], [c, r, r, r], [c + look * r * 0.45, r * 0.8, r * 0.8, r * 0.8]],
		{ "segs": 16, "rings": 4, "side": side })
	m.bone("parpado" + sf, "cabeza", c)
	var lr := r * 1.18
	m.loft("parpado" + sf, "piel", [[c - look * r * 0.1, lr, lr, lr], [c + look * lr * 0.55, lr * 0.84, lr * 0.84, lr * 0.84],
		[c + look * lr * 1.02, 0.02, 0.02, 0.02]], { "segs": 12, "rings": 3, "side": across, "cap0": "none", "cap1": "point", "col": Color(lid_col, 1.0) })


## La cola: rígida (se mueve entera desde la base), en cuatro tramos; la de la reconstrucción, emplumada, con el abanico
## de rectrices en sus dos tercios finales y un penacho en la punta (en huesos aparte: no cuentan en el largo, que es el
## del esqueleto); la de película, con bandas y la hilera de escudos.
static func _tail(m: Rig3D.Model, P: Dictionary, C: Dictionary) -> void:
	var film := bool(P.film)
	var k := float((P.hip as Vector3).y) / 50.0
	var pts: Array = P.tail
	var total := 0.0
	for i in pts.size() - 1:
		total += Vector2(float(pts[i + 1][0]) - float(pts[i][0]), float(pts[i + 1][1]) - float(pts[i][1])).length()
	var done := 0.0
	var prev := "cuerpo"
	var paint := func(_s01: float, u: float, _p: Vector3) -> Color:
		var belly := 1.0 - smoothstep(0.1, 0.27, minf(u, 1.0 - u))
		var top := 1.0 - smoothstep(0.02, 0.22, absf(u - 0.5))
		if film:
			return Color((C.skin as Color).lerp(C.skin_lo, 0.4 * top).lerp(C.belly, belly), 0.0)
		return Color((C.body as Color).lerp(C.feathers, top).lerp(C.belly, belly * 0.8), 0.6)
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var e: Array = pts[i + 1]
		var pa := Vector3(a[0], a[1], 0)
		var pe := Vector3(e[0], e[1], 0)
		var bn := "cola%d" % i
		m.bone(bn, prev, pa)
		var l := pa.distance_to(pe)
		var f0 := done / total
		var f1 := (done + l) / total
		var last := i == pts.size() - 2
		var st := [[pa, a[2], a[3], a[4]], [pa.lerp(pe, 0.5), (float(a[2]) + float(e[2])) * 0.5, (float(a[3]) + float(e[3])) * 0.5,
			(float(a[4]) + float(e[4])) * 0.5], [pe, e[2], e[3], e[4]]]
		m.loft(bn, "escama" if film else "pluma", st, { "segs": 20 if i == 0 else 16, "rings": 6, "paint": paint, "side": Vector3.FORWARD,
			"tile": 6.0 if film else 5.0, "uv_rect": Rect2(0, 0.5 + 0.5 * f0, 0.5, 0.5 * (f1 - f0)), "cap_len0": float(a[3]) * 0.5,
			"cap_len1": float(e[3]) * (1.6 if last else 0.5) })
		if film:
			var n := (7 if i == 0 else 5) if m.detail > 0.5 else 3
			for q in n:
				var t := (float(q) + 0.5) / float(n)
				var p := pa.lerp(pe, t)
				var hu := lerpf(float(a[2]), float(e[2]), t)
				_ridge(m, bn, p + Vector3(0, hu - 0.4 * k, 0), Vector3(-1, 0, 0), lerpf(2.0, 1.0, f0 + (f1 - f0) * t) * k,
					lerpf(1.1, 0.5, f0 + (f1 - f0) * t) * k, 0.7 * k, C.scute)
		elif f1 > 0.25:
			_frond(m, bn, i, pa, pe, a, e, f0, f1, last, C)
		done += l
		prev = bn


## El abanico de la cola de la reconstrucción en el tramo i: rectrices a los dos lados, algo caídas, que crecen hacia la
## punta; plumas de contorno encima y debajo (de lado se ve una cola emplumada) y el penacho final.
static func _frond(m: Rig3D.Model, bn: String, i: int, pa: Vector3, pe: Vector3, a: Array, e: Array, f0: float, f1: float, last: bool,
		C: Dictionary) -> void:
	var ab := "abanico%d" % i
	m.bone(ab, bn, pa)
	m.fit_skip.append(ab)
	var step := 2.6 if m.detail > 0.5 else 5.0
	var x := pa.x - step * 0.5
	var ci := i * 31
	while x > pe.x:
		var t := (pa.x - x) / (pa.x - pe.x)
		var f := lerpf(f0, f1, t)
		if f >= 0.28:
			ci += 1
			var y := lerpf(pa.y, pe.y, t)
			var wz := lerpf(a[4], e[4], t)
			var hu := lerpf(a[2], e[2], t)
			var hd := lerpf(a[3], e[3], t)
			var len := lerpf(9.0, 17.0, smoothstep(0.28, 1.0, f))
			var col: Color = (C.feathers as Color).lerp(C.body, 0.25 * absf(sin(float(ci) * 2.7)))
			for s: float in [1.0, -1.0]:
				var ax := Vector3(-0.72, -0.3, 0.62 * s).normalized() * len
				var wv := Vector3(0, 1, 0).cross(ax.normalized()).normalized() * 3.6
				Mammals3D._card(m, ab, "rectriz", Vector3(x, y, s * wz * 0.6), ax, wv, Vector3(0, 1, 0.2 * s).normalized(), col)
				# contorno: encima y debajo, más cortas, hacia atrás
				for th: float in [0.55, 2.55]:
					var p := Vector3(x, y + (hu * cos(th) if cos(th) >= 0.0 else hd * cos(th)) * 0.9, s * wz * sin(th) * 0.9)
					var out := Vector3(0, cos(th), s * sin(th)).normalized()
					var ax2 := (Vector3(-1, 0, 0) + out * 0.5).normalized() * len * 0.65
					Mammals3D._card(m, ab, "cobertera", p, ax2, out.cross(ax2.normalized()).normalized() * 3.2, out, col.lerp(C.body, 0.2))
		x -= step
	if last:
		for q in 5:
			var ang := deg_to_rad(lerpf(-28.0, 28.0, float(q) / 4.0))
			var ax := Vector3(-cos(ang), -0.05, sin(ang)).normalized() * 18.0
			Mammals3D._card(m, ab, "rectriz", pe + Vector3(2.0, 0, 0), ax, Vector3(0, 1, 0).cross(ax.normalized()).normalized() * 3.4,
				Vector3(0, 1, 0), (C.feathers as Color).darkened(0.1))


## Un brazo (s = +1 el de quien mira): húmero, antebrazo y la mano con tres dedos y sus garras (el I, corto, arriba; el
## II, el más largo; el III, fino, abajo), con la palma hacia dentro y algo abajo. La reconstrucción lleva sus remeras: las
## secundarias en el antebrazo y las primarias en la mano, hacia atrás (un ala pequeña y plegada).
static func _arm(m: Rig3D.Model, P: Dictionary, C: Dictionary, s: float) -> void:
	var film := bool(P.film)
	var k := float((P.hip as Vector3).y) / 50.0
	var sf := "_n" if s > 0.0 else "_f"
	var zs := Vector3(1, 1, s)
	var sh: Vector3 = (P.shoulder as Vector3) * zs
	var el: Vector3 = (P.elbow as Vector3) * zs
	var wr: Vector3 = (P.wrist as Vector3) * zs
	var r: Array = P.arm
	m.bone("brazo" + sf, "cuerpo", sh)
	m.bone("antebrazo" + sf, "brazo" + sf, el)
	m.bone("mano" + sf, "antebrazo" + sf, wr)
	var mat := "escama" if film else "pluma"
	var top_col: Color = C.skin_lo if film else C.feathers
	var low_col: Color = C.skin if film else C.body
	var paint := func(_s01: float, u: float, _p: Vector3) -> Color:
		return Color(low_col.lerp(top_col, 1.0 - smoothstep(0.1, 0.35, absf(u - 0.5))), 0.0 if film else 0.5)
	var r0 := float(r[0])
	var r1 := float(r[1])
	var r2 := float(r[2])
	var rf := float(r[3])
	m.loft("brazo" + sf, mat, [[sh, r0, r0 * 1.1, r0 * 0.85], [sh.lerp(el, 0.55), r0 * 0.78, r0 * 0.85, r0 * 0.7], [el, r1, r1, r1 * 0.9]],
		{ "segs": 14, "rings": 5, "paint": paint, "uv_rect": BLANK_UV, "tile": 2.5 * k })
	m.loft("antebrazo" + sf, mat, [[el, r1 * 0.95, r1 * 0.95, r1 * 0.85], [el.lerp(wr, 0.5), (r1 + r2) * 0.5, (r1 + r2) * 0.5, (r1 + r2) * 0.42],
		[wr, r2, r2, r2 * 0.85]], { "segs": 12, "rings": 5, "paint": paint, "uv_rect": BLANK_UV, "tile": 2.5 * k })
	var fd := Vector3(0.78, -0.62, 0.0).normalized()
	var pd := Vector3(0.0, -0.55, -0.83 * s).normalized()
	var ta := pd.cross(fd).normalized()
	if ta.y < 0.0:
		ta = -ta
	var hand_end := wr + fd * 2.4 * k
	var skin: Color = C.skin if film else C.scale
	m.loft("mano" + sf, "escama", [[wr, r2 * 0.9, r2 * 0.9, r2 * 0.75], [hand_end, r2 * 0.7, r2 * 0.7, r2 * 0.95]],
		{ "segs": 12, "rings": 3, "col": Color(skin, 1.0), "uv_rect": BLANK_UV, "tile": 1.5 * k })
	var fl: Array = P.fingers
	var cl: Array = P.hand_claws
	for i in 3:
		var base := hand_end + ta * (1.0 - float(i)) * rf * 1.5 - fd * rf * 0.5
		var l := float(fl[i])
		var rr := rf * (1.1 if i == 1 else (1.0 if i == 0 else 0.85))
		var p1 := base + fd * l * 0.5 + pd * l * 0.06
		var d2 := (fd + pd * 0.35).normalized()
		var p2 := p1 + d2 * l * 0.5
		m.loft("mano" + sf, "escama", [[base, rr, rr, rr], [p1, rr * 0.88, rr * 0.88, rr * 0.9], [p2, rr * 0.72, rr * 0.72, rr * 0.75]],
			{ "segs": 10, "rings": 4, "col": Color(skin, 1.0), "uv_rect": BLANK_UV, "tile": 1.5 * k })
		var cd := (fd + pd * 0.5).normalized()
		Loft.claw(m.acc("mano" + sf), "unas", p2 + d2 * rr * 0.3, cd, -pd, float(cl[i]), rr * 1.7, rr * 1.0, 115.0,
			{ "col": Color(C.claw, 1.0), "segs": m.segs(8), "rings": m.rings(6) })
	if film:
		return
	# las remeras (estimación del dibujo: ~9 cm las secundarias y ~11 las primarias)
	var n := 6 if m.detail > 0.5 else 4
	var fore := (wr - el).normalized()
	for q in n:
		var f := (float(q) + 0.5) / float(n)
		var at := el.lerp(wr, f) + Vector3(0, -r1 * 0.5, 0)
		var ax := Vector3(-0.5, -0.86, 0.1 * s).normalized() * 9.0 * (0.9 + 0.1 * f)
		Mammals3D._card(m, "antebrazo" + sf, "remera", at, ax, fore * 2.6, Vector3(0.0, 0.2, s).normalized(), (C.feathers as Color).lerp(C.body, 0.15 * f))
	var hand := (hand_end + fd * float(fl[1]) * 0.8 - wr)
	for q in n:
		var f := (float(q) + 0.5) / float(n)
		var at := wr + hand * f + Vector3(0, -r2 * 0.4, 0)
		var ax := Vector3(-0.3 + 0.25 * f, -0.95, 0.12 * s).normalized() * 11.0 * (1.0 - 0.15 * f)
		Mammals3D._card(m, "mano" + sf, "remera", at, ax, hand.normalized() * 2.6, Vector3(0.0, 0.2, s).normalized(), (C.feathers as Color).darkened(0.1 * f))


## Una pata (s = +1 la de quien mira): el muslo (con plumas o escamas), la tibia, el metatarso con escudos, los dedos III
## y IV que apoyan, el II levantado con la garra en hoz (un hueso para su articulación: baja al golpear) y el I, pequeño,
## detrás y en alto.
static func _leg(m: Rig3D.Model, P: Dictionary, C: Dictionary, s: float, v: String) -> void:
	var film := bool(P.film)
	var k := float((P.hip as Vector3).y) / 50.0
	var sf := "_n" if s > 0.0 else "_f"
	var zs := Vector3(1, 1, s)
	var hip: Vector3 = (P.hip as Vector3) * zs
	var knee: Vector3 = (P.knee as Vector3) * zs
	var ankle: Vector3 = (P.ankle as Vector3) * zs
	var mtp: Vector3 = (P.mtp as Vector3) * zs
	m.bone("muslo" + sf, "cuerpo", hip)
	m.bone("tibia" + sf, "muslo" + sf, knee)
	m.bone("tarso" + sf, "tibia" + sf, ankle)
	m.bone("pie" + sf, "tarso" + sf, mtp)
	var th: Array = P.thigh
	var sh: Array = P.shin
	var mt: Array = P.meta
	var tp := func(_s01: float, u: float, _p: Vector3) -> Color:
		var front := 1.0 - smoothstep(0.05, 0.3, absf(u - 0.5))
		if film:
			return Color((C.skin as Color).lerp(C.skin_lo, 0.4 * front), 0.0)
		return Color((C.body as Color).lerp(C.feathers, 0.5 * front), 0.5)
	m.loft("muslo" + sf, "escama" if film else "plumon", [[hip, th[0][0], th[0][1], th[0][2]], [hip.lerp(knee, 0.55), th[1][0], th[1][1], th[1][2]],
		[knee, th[2][0], th[2][1], th[2][2]]], { "segs": 18, "rings": 8, "paint": tp, "tile": 5.0 if film else 3.0, "uv_rect": BLANK_UV })
	var scale_col: Color = C.skin_lo if film else C.scale
	var shin_col: Color = C.skin if film else C.scale
	var shin := func(_s01: float, u: float, _p: Vector3) -> Color:
		var front := 1.0 - smoothstep(0.05, 0.3, absf(u - 0.5))
		return Color(shin_col.lerp(scale_col.darkened(0.15), 0.4 * front), 0.0)
	m.loft("tibia" + sf, "escama", [[knee, sh[0][0], sh[0][1], sh[0][2]], [knee.lerp(ankle, 0.45), sh[1][0], sh[1][1], sh[1][2]],
		[ankle, sh[2][0], sh[2][1], sh[2][2]]], { "segs": 16, "rings": 8, "paint": shin, "tile": 4.0 if film else 1.6, "uv_rect": BLANK_UV })
	if not film:
		# las plumas de la tibia («pantalones»), hasta algo más abajo de la mitad
		m.loft("tibia" + sf, "plumon", [[knee + Vector3(0, 1, 0), float(sh[0][0]) * 1.15, float(sh[0][1]) * 1.12, float(sh[0][2]) * 1.15],
			[knee.lerp(ankle, 0.35), float(sh[1][0]) * 1.2, float(sh[1][1]) * 1.15, float(sh[1][2]) * 1.2],
			[knee.lerp(ankle, 0.6), float(sh[2][0]) * 1.7, float(sh[2][1]) * 1.6, float(sh[2][2]) * 1.6]],
			{ "segs": 16, "rings": 6, "paint": tp, "tile": 2.5, "cap1": "round", "cap_len1": 1.2 })
	m.loft("tarso" + sf, "escudo", [[ankle, mt[0][0], mt[0][1], mt[0][2]], [ankle.lerp(mtp, 0.5), mt[1][0], mt[1][1], mt[1][2]],
		[mtp, mt[2][0], mt[2][1], mt[2][2]]], { "segs": 14, "rings": 6, "col": Color(scale_col, 1.0), "tile": 1.3 * k })
	var tr := float(P.toe_r)
	var toes: Array = P.toes
	var claw_col: Color = C.claw
	_toe(m, "III" + sf, "pie" + sf, mtp + Vector3(0.4, 0, 0.2 * s) * k, 4.0 * s, float(toes[0]), tr, [0.38, 0.7], scale_col, claw_col, float(P.toe_claw))
	_toe(m, "IV" + sf, "pie" + sf, mtp + Vector3(-0.2, 0, 1.0 * s) * k, 18.0 * s, float(toes[1]), tr * 0.95, [0.36, 0.68], scale_col, claw_col,
		float(P.toe_claw) * 0.9)
	# el dedo II, levantado: la falange II-1 hacia delante y la II-2 hacia arriba, con la hoz que se curva hacia delante
	var b0 := mtp + Vector3(0.6, 0.5, -1.0 * s) * k
	var j := b0 + Vector3(2.3, 1.0, -0.15 * s) * k
	var t2 := j + Vector3(1.0, 1.8, 0.0) * k
	m.bone("dedoII" + sf, "pie" + sf, b0)
	m.bone("dedoII" + sf + "_1", "dedoII" + sf, j)
	var r2 := tr * 1.1
	m.loft("dedoII" + sf, "escama", [[b0, r2, r2 * 1.05, r2 * 1.1], [j, r2 * 0.95, r2, r2]], { "segs": 12, "rings": 3, "col": Color(scale_col, 1.0),
		"uv_rect": BLANK_UV, "tile": tr * 1.6 })
	m.loft("dedoII" + sf + "_1", "escama", [[j, r2 * 0.95, r2, r2], [t2, r2 * 0.9, r2 * 0.9, r2 * 0.9]], { "segs": 12, "rings": 3,
		"col": Color(scale_col, 1.0), "uv_rect": BLANK_UV, "tile": tr * 1.6 })
	var sk := sickle_of(v)
	var hw: Vector2 = P.sickle_hw
	var sd := Vector3(0.35, 1.0, 0.0).normalized()
	m.claw("dedoII" + sf + "_1", "hoz" + sf, t2 - sd * 0.3 * k, sd, Vector3(-1.0, 0.35, 0.0), sk.x, hw.x, hw.y, sk.y, s < 0.0)
	# el dedo I (el pulgar del pie): pequeño, detrás y en alto
	var hb := ankle.lerp(mtp, 0.7) + Vector3(-0.6, 0.0, -0.5 * s) * k
	var hdir := Vector3(-0.55, -0.75, -0.25 * s).normalized()
	var hl := float(P.hallux)
	var hr := tr * 0.6
	m.loft("tarso" + sf, "escama", [[hb, hr, hr, hr], [hb + hdir * hl, hr * 0.7, hr * 0.7, hr * 0.7]], { "segs": 8, "rings": 2,
		"col": Color(scale_col, 1.0), "uv_rect": BLANK_UV, "tile": tr * 1.6 })
	Loft.claw(m.acc("tarso" + sf), "unas", hb + hdir * hl, hdir + Vector3(0, -0.3, 0), Vector3(-1, 0.2, 0), hl * 0.6, hr * 1.3, hr * 0.9, 80.0,
		{ "col": Color(claw_col, 1.0), "segs": m.segs(8), "rings": m.rings(5) })
	if not film:
		# el borde de los «pantalones»: plumas que cuelgan del muslo por detrás de la rodilla
		var n := 7 if m.detail > 0.5 else 4
		for q in n:
			var f := float(q) / float(n - 1)
			var at := hip.lerp(knee, 0.62 + 0.3 * f) + Vector3(-float(th[1][1]) * (0.85 - 0.4 * f), -1.0, 0.0)
			var ax := Vector3(-0.35, -1.0, 0.1 * s).normalized() * (6.5 - 1.5 * f)
			var out := Vector3(-0.4, 0.0, s).normalized()
			Mammals3D._card(m, "muslo" + sf, "cobertera", at, ax, out.cross(ax.normalized()).normalized() * 3.2, out,
				(C.body as Color).lerp(C.feathers, 0.4 * float(q % 2)))


## Un dedo que apoya: sale de la articulación (base, algo levantada), baja hasta el suelo por su almohadilla y acaba en
## su garra; sus falanges (joints: fracciones del largo donde se dobla) son huesos.
static func _toe(m: Rig3D.Model, name: String, parent: String, base: Vector3, yaw_deg: float, len: float, r: float, joints: Array, col: Color,
		claw_col: Color, claw_len: float) -> void:
	var dir := Vector3(cos(deg_to_rad(yaw_deg)), 0, sin(deg_to_rad(yaw_deg)))
	var pts: Array = []
	var n := 6
	for i in n:
		var f := float(i) / float(n - 1)
		var rr := lerpf(r, r * 0.62, f)
		var y := lerpf(base.y, rr, smoothstep(0.0, 0.35, f))
		pts.append(base + dir * (len * f) + Vector3(0, y - base.y, 0))
	var bones := [parent]
	var prev := parent
	var kk := 0
	for jf: float in joints:
		var bn := "dedo%s_%d" % [name, kk]
		m.bone(bn, prev, Cassowary3D._along(pts, jf))
		bones.append(bn)
		prev = bn
		kk += 1
	var cuts := [0.0] + joints + [1.0]
	for i in cuts.size() - 1:
		var f0: float = cuts[i]
		var f1: float = cuts[i + 1]
		var st: Array = []
		for q in 3:
			var f := lerpf(f0, f1, float(q) / 2.0)
			var rr := lerpf(r, r * 0.62, f)
			st.append([Cassowary3D._along(pts, f), rr * 0.85, rr, rr * 1.08])
		m.loft(bones[i], "escama", st, { "segs": 10, "rings": 3, "col": Color(col, 1.0), "tile": r * 1.6, "uv_rect": BLANK_UV })
	var tip: Vector3 = pts[n - 1]
	var tip_dir := ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
	Loft.claw(m.acc(bones[bones.size() - 1]), "unas", tip + Vector3(0, r * 0.25, 0) - tip_dir * r * 0.5, tip_dir + Vector3(0, 0.15, 0), Vector3.UP,
		claw_len, r * 1.4, r * 0.95, 75.0, { "col": Color(claw_col, 1.0), "segs": m.segs(8), "rings": m.rings(6) })


## Las posturas: de pie (el reposo), agazapado (la cadera un 20 % más baja, las patas más dobladas con los pies donde
## estaban, el cuello recogido, la cabeza baja y los brazos delante) y el salto (que la pose mezcla con la postura: se
## estira hacia arriba, las patas por delante con la hoz abajo, los brazos abiertos hacia delante y la cola atrás).
static func _postures(m: Rig3D.Model, P: Dictionary) -> void:
	var k := float((P.hip as Vector3).y) / 50.0
	m.postures["de_pie"] = {}
	m.postures["tumbado"] = { "@cuerpo": Vector3(0, -10.0 * k, 0), "cuerpo": Vector3(0, 0, -0.06), "cuello": Vector3(0, 0, -0.22),
		"cabeza": Vector3(0, 0, 0.16), "cola0": Vector3(0, 0, -0.05) }
	m.postures["salto"] = { "cuerpo": Vector3(0, 0, 0.45), "cuello": Vector3(0, 0, -0.36), "cabeza": Vector3(0, 0, -0.14), "cola0": Vector3(0, 0, -0.32),
		"cola1": Vector3(0, 0, -0.04) }
	var toes: Array = P.toes
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var zs := Vector3(1, 1, s)
		var hip: Vector3 = (P.hip as Vector3) * zs
		var knee: Vector3 = (P.knee as Vector3) * zs
		var ankle: Vector3 = (P.ankle as Vector3) * zs
		var mtp: Vector3 = (P.mtp as Vector3) * zs
		var toe := Vector3(mtp.x + 0.4 * k + float(toes[0]), float(P.toe_r) * 0.62, mtp.z)
		var chain := ["muslo" + sf, "tibia" + sf, "tarso" + sf, "pie" + sf]
		m.pose_chain("tumbado", chain, [hip, knee + Vector3(3, -5, 0) * k, ankle + Vector3(-4.5, -3.5, 0) * k, mtp, toe], toe)
		m.pose_chain("salto", chain, [hip, hip + Vector3(22, 6, 0) * k, hip + Vector3(28, -12, 0) * k, hip + Vector3(37, -15, 0) * k,
			hip + Vector3(45, -11, 0) * k], toe)
		m.postures["salto"]["dedoII" + sf + "_1"] = Vector3(0, 0, -1.0)
		m.postures["salto"]["dedoIII" + sf + "_0"] = Vector3(0, 0, 0.3)
		m.postures["salto"]["dedoIV" + sf + "_0"] = Vector3(0, 0, 0.3)
		m.postures["tumbado"]["brazo" + sf] = Vector3(0, 0, 0.55)
		m.postures["tumbado"]["antebrazo" + sf] = Vector3(0, 0, -0.1)
		m.postures["salto"]["brazo" + sf] = Vector3(-0.35 * s, 0, 1.25)
		m.postures["salto"]["antebrazo" + sf] = Vector3(0, 0, -1.0)
		m.postures["salto"]["mano" + sf] = Vector3(0, 0, -0.1)


## La pose de cada fotograma: respiración, la cola rígida (se mueve entera, poco), la cabeza que tantea, el miedo o la
## amenaza (baja la cabeza, abre la boca, adelanta los brazos y eriza las plumas del lomo), el salto (pose.leap, mezclado
## con la postura) y el parpadeo.
static func pose(a: RefCounted, p: Dictionary) -> void:
	var t: float = a.get("_t")
	var info: Dictionary = (a.get("_data") as Dictionary).info
	var film := bool(info.get("film", false))
	var scared := clampf(float(p.get("scared", 0.0)), 0.0, 1.0)
	# el salto: pose.leap o, como lo manda la vista en el golpe, pose.kick (los pies por delante)
	var leap := smoothstep(0.0, 1.0, clampf(maxf(float(p.get("leap", 0.0)), float(p.get("kick", 0.0))), 0.0, 1.0))
	var bristle := clampf(maxf(float(p.get("bristle", 0.0)), scared), 0.0, 1.0)
	a.call("rot_add", "postura", Vector3(0, 0, -float(p.get("lean", 0.0))))
	var br := 1.0 + (0.01 + 0.01 * scared) * sin(TAU * t / (2.4 - 0.9 * scared))
	a.call("scale_bone", "torso", Vector3(1.0, br, 1.0 + 0.5 * (br - 1.0)))
	a.call("blend_post", "salto", leap)
	var sw := 0.02 * sin(t * 1.1) + 0.05 * scared * sin(t * 5.0)
	a.call("rot_add", "cola0", Vector3(0, sw, 0.015 * sin(t * 0.9)))
	a.call("rot_add", "cuello", Vector3(0, 0.04 * _wob(t, 0.5, 0.4), -0.1 * scared))
	a.call("rot_add", "cabeza", Vector3(0, 0.06 * _wob(t, 0.7, 1.1), -0.04 * _wob(t, 0.6, 2.3) + 0.08 * scared))
	a.call("rot_add", "mandibula", Vector3(0, 0, -(0.34 if film else 0.24) * maxf(scared, leap * 0.8)))
	for side: String in ["_n", "_f"]:
		var sg := 1.0 if side == "_n" else -1.0
		a.call("rot_add", "brazo" + side, Vector3(-0.15 * scared * sg, 0, 0.2 * scared))
		a.call("rot_add", "antebrazo" + side, Vector3(0, 0, -0.25 * scared))
	a.call("show_bone", "erizado", bristle > 0.02)
	a.call("show_shadow", 1.0 - leap)
	a.call("blink")


static func _wob(t: float, f: float, seed: float) -> float:
	return 0.6 * sin(t * f + seed) + 0.4 * sin(t * f * 2.13 + seed * 1.7)
