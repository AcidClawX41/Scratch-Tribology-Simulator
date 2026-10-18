## Las seis rapaces del coche en marcha en 3D (unidad 4l), posadas, en centímetros de su anatomía: los pies en el origen,
## el pico hacia +x, la y hacia arriba y el lado de quien mira hacia +z. Un mismo modelo de rapaz con las medidas de cada
## especie (docs/fisica/coche-en-marcha.md §9.6.3, con sus fuentes): el largo del tarso, de la cola, del ala plegada
## (la cuerda) y del pico, con las proporciones de las guías (Ferguson-Lees & Christie 2001; König & Weick 2008;
## Xirouchakis & Poulakakis 2008), y los grosores y los colores, con los rasgos de campo de siempre (todo, dibujo):
##   - águila real: pardo oscuro, la corona y la nuca doradas, «botas» emplumadas hasta los dedos, cola larga;
##   - arpía: cabeza gris con el penacho doble, banda pectoral negra, vientre blanco, tarsos desnudos amarillos y gruesos;
##   - halcón peregrino: pizarra, capucha y bigotera negras, mejilla blanca, pecho barrado, alas en punta;
##   - búho real: penachos, disco facial leonado de borde oscuro, ojos naranjas, pecho listado, patas emplumadas;
##   - lechuza común: disco facial blanco en corazón, dorso dorado con motas, patas largas;
##   - buitre leonado: el cuello largo de plumón blanco, el collar claro, cuerpo leonado y encorvado, pico grande.
## Las lechuzas y los búhos giran la cabeza hacia quien mira (se les ven los dos ojos y el disco facial).
## Piezas: el tronco con las alas plegadas (un manto de plumas en cada costado, las primarias hasta la cola), la cola en
## abanico, el cuello y la cabeza (pico ganchudo con la cera, ojos con párpado, ceja), las patas (pantalones de plumas,
## tarso, cuatro dedos con su talón: el pie se cierra al agarrarse con miedo) y el ala abierta (brazo y mano con las
## secundarias y las primarias en tarjetas de plumas: se abre en abanico y se levanta con la sustentación, con la
## envergadura del estado). Garras: el alcance (reach) y la curva del catálogo, como la física. Solo dibujo.
extends RefCounted

const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Loft = preload("res://app/lab/animals/loft.gd")
const Mats3D = preload("res://app/lab/animals/mats3d.gd")
const Tex3D = preload("res://app/lab/animals/tex3d.gd")
const Mammals3D = preload("res://app/lab/animals/mammals3d.gd")
const Rng = preload("res://core/shared/rng.gd")

## Un trozo del mapa del patrón que siempre está en blanco (para las piezas sin patrón).
const BLANK_UV := Rect2(0.3, 0.004, 0.4, 0.02)


## Las medidas y los colores de cada especie (cm). trunk: estaciones del tronco de la cloaca al cuello [x, y, espalda,
## pecho, lado]; head: las del cráneo; bill: la quilla del pico [x, y, radio]; tail: base, punta y anchos; wing: el
## hombro, la punta de las primarias plegadas y el ala abierta (brazo, mano, secundarias y primarias); leg: rodilla,
## tobillo, articulación de los dedos, radios y largo de los dedos [pulgar, II, III, IV].
static func species(id: String) -> Dictionary:
	match id:
		"arpia":
			return {
				"trunk": [[-2.0, 14.0, 6.0, 7.0, 7.0], [-3.0, 24.0, 12.5, 15.0, 12.5], [-2.0, 37.0, 14.5, 19.0, 14.0], [0.0, 50.0, 13.5, 19.0, 13.5],
					[2.0, 61.0, 11.0, 14.0, 11.0], [4.0, 69.0, 7.5, 8.5, 8.0]],
				"neck": [[4.0, 67.0, 8.0, 8.5, 8.0], [7.0, 74.0, 7.5, 8.0, 7.5]],
				"head": [[1.0, 79.0, 7.0, 6.5, 7.2], [8.0, 82.0, 9.0, 8.0, 8.8], [15.0, 82.0, 8.4, 7.4, 8.0], [21.0, 80.0, 5.4, 5.4, 5.2]],
				"bill": [[21.5, 82.0, 2.8], [26.0, 82.3, 2.2], [29.5, 80.6, 1.6], [31.0, 78.0, 0.9], [30.8, 76.0, 0.2]],
				"eye": [19.0, 81.6, 1.9, Color("#4a2e1c")], "brow": 0.6,
				"tail": [Vector3(-6, 27, 0), Vector3(-41, 3, 0), 7.5, 10.5, 1.5], "tail_bands": 3,
				"wing": { "shoulder": Vector3(3, 66, 0), "tip": Vector3(-24, 15, 0), "chord": 20.0, "arm": 40.0, "hand": 52.0, "sec": 34.0, "prim": 48.0,
					"tip_kind": "pluma_dedo" },
				"leg": { "z": 6.0, "knee": Vector3(-1, 27, 0), "ankle": Vector3(2.5, 17, 0), "mtp": Vector3(3, 3.2, 0), "tarsus_r": 2.3, "bare": true,
					"trouser_r": 6.5, "toes": [7.6, 7.6, 10.0, 8.6], "toe_r": 1.55 },
				"colors": { "body": Color("#2a2c33"), "breast": Color("#efebe3"), "head": Color("#6e7178"), "head_hi": Color("#8f939b"), "band": Color("#1a1a1e"),
					"wing": Color("#2a2d34"), "covert": Color("#3a3d45"), "prim": Color("#15161a"), "tail": Color("#1d1d22"), "tail_bar": Color("#8d9097"),
					"leg": Color("#e0ae36"), "toe": Color("#e6b53a"), "trouser": Color("#ece8e0"), "bill": Color("#3c3e44"), "bill_tip": Color("#0e0e11"),
					"cere": Color("#34353b"), "claw": Color("#141315") },
				"crest": true,
			}
		"halcon":
			return {
				"trunk": [[-1.0, 8.0, 3.0, 3.5, 3.5], [-1.5, 13.0, 5.5, 6.5, 5.5], [-1.0, 19.0, 6.5, 8.5, 6.5], [0.0, 26.0, 6.0, 8.0, 6.0], [1.0, 31.0, 4.8, 6.0, 5.0],
					[2.0, 34.5, 3.4, 3.8, 3.6]],
				"neck": [[2.0, 33.5, 3.6, 3.8, 3.6], [3.5, 37.0, 3.2, 3.4, 3.2]],
				"head": [[1.0, 38.0, 3.2, 3.2, 3.2], [4.5, 40.0, 4.0, 3.8, 3.8], [8.0, 40.0, 3.8, 3.3, 3.5], [10.5, 39.2, 2.4, 2.4, 2.4]],
				"bill": [[10.6, 40.7, 1.2], [12.0, 40.9, 1.0], [13.0, 40.1, 0.75], [13.4, 38.9, 0.45], [13.2, 37.9, 0.1]],
				"eye": [8.4, 40.7, 1.15, Color("#3a2416")], "eye_ring": Color("#e8c040"), "brow": 0.2,
				"tail": [Vector3(-5, 15, 0), Vector3(-17.5, 1.5, 0), 3.4, 4.4, 0.8], "tail_bands": 5,
				"wing": { "shoulder": Vector3(1.5, 32, 0), "tip": Vector3(-16, 2.2, 0), "chord": 9.0, "arm": 18.0, "hand": 31.0, "sec": 14.0, "prim": 30.0,
					"tip_kind": "pluma_punta" },
				"leg": { "z": 2.6, "knee": Vector3(-0.5, 12, 0), "ankle": Vector3(0.6, 7.2, 0), "mtp": Vector3(1.2, 1.5, 0), "tarsus_r": 0.75, "bare": true,
					"trouser_r": 2.8, "toes": [3.4, 3.8, 4.8, 3.8], "toe_r": 0.55 },
				"colors": { "body": Color("#4e5866"), "breast": Color("#f2ecdf"), "head": Color("#1c1f25"), "head_hi": Color("#2a2f37"), "band": Color("#262a31"),
					"wing": Color("#4f5a68"), "covert": Color("#6c7888"), "prim": Color("#16191e"), "tail": Color("#56606e"), "tail_bar": Color("#1e2229"),
					"leg": Color("#e8be32"), "toe": Color("#ebc23a"), "trouser": Color("#efe6d6"), "bill": Color("#7c889a"), "bill_tip": Color("#1a1d22"),
					"cere": Color("#eac23c"), "claw": Color("#16151a") },
				"falcon": true,
			}
		"buho":
			return {
				"trunk": [[-1.0, 8.0, 4.0, 5.0, 5.0], [-1.5, 14.0, 9.0, 11.0, 9.0], [-1.0, 24.0, 12.0, 15.0, 11.5], [0.0, 35.0, 11.0, 14.5, 11.0],
					[1.0, 44.0, 9.0, 10.0, 9.0], [2.0, 49.0, 6.5, 7.0, 7.0]],
				"neck": [[2.0, 48.0, 7.0, 7.0, 7.0], [3.0, 51.0, 6.5, 6.5, 6.5]],
				"head": [[-3.5, 52.0, 6.5, 6.5, 7.5], [1.5, 56.0, 8.8, 8.2, 9.2], [6.5, 56.0, 8.6, 7.6, 9.0], [10.5, 54.0, 6.0, 6.0, 7.0]],
				"bill": [[11.8, 53.6, 0.9], [12.8, 53.3, 0.75], [13.3, 52.2, 0.5], [13.2, 51.2, 0.1]],
				"eye": [12.4, 55.6, 2.3, Color("#ff7a10")], "brow": 0.0,
				"tail": [Vector3(-8, 16, 0), Vector3(-15.5, 4.8, 0), 5.0, 6.0, 1.2], "tail_bands": 5,
				"wing": { "shoulder": Vector3(-1, 45, 0), "tip": Vector3(-14, 5.5, 0), "chord": 16.0, "arm": 30.0, "hand": 37.0, "sec": 26.0, "prim": 36.0,
					"tip_kind": "pluma_redonda" },
				"leg": { "z": 4.5, "knee": Vector3(-0.5, 16, 0), "ankle": Vector3(1.5, 10, 0), "mtp": Vector3(2.4, 2.4, 0), "tarsus_r": 2.4, "bare": false,
					"trouser_r": 5.0, "toes": [4.0, 4.6, 6.0, 5.0], "toe_r": 1.25 },
				"colors": { "body": Color("#8e6436"), "breast": Color("#d2a46a"), "head": Color("#946a40"), "head_hi": Color("#b08050"), "band": Color("#2a1a0e"),
					"wing": Color("#6a4e32"), "covert": Color("#8a6844"), "prim": Color("#4a3522"), "tail": Color("#5e4630"), "tail_bar": Color("#2e2016"),
					"leg": Color("#c9a06a"), "toe": Color("#c79e68"), "trouser": Color("#c9a06a"), "bill": Color("#1c1814"), "bill_tip": Color("#1c1814"),
					"cere": Color("#1c1814"), "claw": Color("#141210"), "disc": Color("#c98a48"), "disc_rim": Color("#1e140c") },
				"owl": "buho",
			}
		"lechuza":
			return {
				"trunk": [[0.0, 8.0, 2.2, 2.6, 2.6], [-0.5, 11.0, 4.0, 5.0, 4.0], [-0.5, 15.0, 5.0, 6.5, 5.0], [0.0, 19.0, 4.6, 6.0, 4.6], [0.5, 22.5, 3.6, 4.4, 3.8],
					[1.0, 25.0, 2.6, 2.8, 2.8]],
				"neck": [[1.0, 24.5, 2.8, 2.8, 2.8], [1.5, 26.0, 2.7, 2.7, 2.7]],
				"head": [[-2.5, 26.5, 3.2, 3.0, 3.8], [1.0, 29.0, 4.6, 4.2, 5.0], [4.5, 29.0, 4.4, 4.0, 4.8], [7.0, 28.0, 3.0, 3.0, 3.6]],
				"bill": [[7.7, 28.0, 0.55], [8.4, 27.6, 0.42], [8.6, 26.8, 0.25], [8.5, 26.2, 0.06]],
				"eye": [7.4, 28.6, 0.95, Color("#221614")], "brow": 0.0,
				"tail": [Vector3(-4, 11, 0), Vector3(-8.2, 4.6, 0), 2.6, 3.2, 0.6], "tail_bands": 4,
				"wing": { "shoulder": Vector3(-1, 22, 0), "tip": Vector3(-9.2, 2.6, 0), "chord": 8.0, "arm": 19.0, "hand": 26.0, "sec": 15.0, "prim": 26.0,
					"tip_kind": "pluma_redonda" },
				"leg": { "z": 2.0, "knee": Vector3(0, 10.5, 0), "ankle": Vector3(-0.4, 7.4, 0), "mtp": Vector3(0.6, 1.2, 0), "tarsus_r": 0.8, "bare": false,
					"trouser_r": 2.2, "toes": [2.4, 2.6, 3.2, 2.8], "toe_r": 0.42 },
				"colors": { "body": Color("#c99a55"), "breast": Color("#f8f2e6"), "head": Color("#ce9c52"), "head_hi": Color("#e2b46a"), "band": Color("#3a2a20"),
					"wing": Color("#ce9a4e"), "covert": Color("#e0b266"), "prim": Color("#a87a3c"), "tail": Color("#c49650"), "tail_bar": Color("#7a6048"),
					"leg": Color("#f4eee2"), "toe": Color("#bfa096"), "trouser": Color("#f4eee2"), "bill": Color("#e8d6c6"), "bill_tip": Color("#d8c0ac"),
					"cere": Color("#e8d6c6"), "claw": Color("#2e2622"), "disc": Color("#fbf8f2"), "disc_rim": Color("#b8864a") },
				"owl": "lechuza",
			}
		"buitre":
			return {
				"trunk": [[0.0, 13.0, 6.0, 7.0, 8.0], [-4.0, 24.0, 13.0, 16.0, 14.0], [-6.0, 39.0, 16.0, 20.0, 16.0], [-4.0, 54.0, 15.0, 18.0, 15.0],
					[-1.0, 65.0, 12.0, 12.0, 13.0], [2.0, 72.0, 8.0, 8.0, 9.0]],
				"neck": [[5.0, 72.0, 4.6, 4.6, 4.6], [10.0, 79.0, 3.4, 3.4, 3.4], [15.0, 82.5, 3.0, 3.0, 3.0], [20.0, 83.5, 2.9, 2.9, 2.9]],
				"head": [[20.0, 84.5, 3.4, 3.2, 3.4], [25.0, 86.0, 4.0, 3.4, 3.6], [30.0, 85.8, 3.2, 2.9, 3.0]],
				"bill": [[31.0, 86.8, 2.4], [35.5, 86.8, 2.0], [38.5, 85.2, 1.5], [40.0, 82.6, 0.8], [39.7, 80.2, 0.2]],
				"eye": [28.2, 85.4, 1.3, Color("#c29a5a")], "brow": 0.4,
				"tail": [Vector3(-20, 31, 0), Vector3(-44, 21, 0), 9.0, 10.0, 1.8], "tail_bands": 0,
				"wing": { "shoulder": Vector3(-3, 72, 0), "tip": Vector3(-44, 14, 0), "chord": 24.0, "arm": 55.0, "hand": 62.0, "sec": 46.0, "prim": 60.0,
					"tip_kind": "pluma_dedo" },
				"leg": { "z": 7.0, "knee": Vector3(-2, 24, 0), "ankle": Vector3(-0.5, 16, 0), "mtp": Vector3(1.5, 3.0, 0), "tarsus_r": 1.9, "bare": true,
					"trouser_r": 6.5, "toes": [6.0, 7.2, 10.5, 8.0], "toe_r": 1.45 },
				"colors": { "body": Color("#7d5c3a"), "breast": Color("#9a7650"), "head": Color("#e4ddd2"), "head_hi": Color("#f0ebe2"), "band": Color("#3a2c20"),
					"wing": Color("#5a4028"), "covert": Color("#a07a4e"), "prim": Color("#241b15"), "tail": Color("#2a221c"), "tail_bar": Color("#2a221c"),
					"leg": Color("#8c8f94"), "toe": Color("#90939a"), "trouser": Color("#b08a5a"), "bill": Color("#d4c7aa"), "bill_tip": Color("#7a6e5e"),
					"cere": Color("#9a9ca8"), "claw": Color("#24201c"), "ruff": Color("#ece0c6") },
				"vulture": true,
			}
	# águila real (por defecto)
	return {
		"trunk": [[-2.0, 13.0, 5.0, 6.0, 6.0], [-3.0, 22.0, 11.0, 13.0, 11.0], [-2.0, 34.0, 13.0, 17.0, 12.5], [0.0, 46.0, 12.0, 17.0, 12.0],
			[2.0, 56.0, 10.0, 13.0, 10.0], [4.0, 63.0, 7.0, 8.0, 7.5]],
		"neck": [[4.0, 61.0, 7.5, 8.0, 7.5], [7.0, 68.0, 6.5, 7.0, 6.5]],
		"head": [[2.0, 73.0, 5.5, 5.5, 5.5], [8.0, 75.0, 7.5, 6.6, 7.0], [14.0, 75.0, 7.0, 6.0, 6.5], [19.0, 73.5, 4.6, 4.6, 4.4]],
		"bill": [[19.5, 74.4, 2.4], [23.5, 74.8, 1.9], [26.6, 73.4, 1.4], [28.4, 71.1, 0.8], [28.7, 69.1, 0.2]],
		"eye": [17.2, 74.2, 1.75, Color("#a1622a")], "brow": 1.0,
		"tail": [Vector3(-6, 24, 0), Vector3(-37, 4, 0), 7.0, 9.5, 1.4], "tail_bands": 4,
		"wing": { "shoulder": Vector3(3, 60, 0), "tip": Vector3(-31, 6, 0), "chord": 18.0, "arm": 38.0, "hand": 58.0, "sec": 30.0, "prim": 50.0,
			"tip_kind": "pluma_dedo" },
		"leg": { "z": 5.5, "knee": Vector3(-1, 24, 0), "ankle": Vector3(3, 15.5, 0), "mtp": Vector3(4, 3.0, 0), "tarsus_r": 2.0, "bare": false,
			"trouser_r": 6.0, "toes": [6.2, 6.5, 8.6, 7.2], "toe_r": 1.25 },
		"colors": { "body": Color("#3e2a1c"), "breast": Color("#4a3322"), "head": Color("#4e3726"), "head_hi": Color("#d9a858"), "band": Color("#24170f"),
			"wing": Color("#34261b"), "covert": Color("#6a4c31"), "prim": Color("#17110d"), "tail": Color("#2a211b"), "tail_bar": Color("#6c6258"),
			"leg": Color("#6c4f35"), "toe": Color("#e6b530"), "trouser": Color("#5a412c"), "bill": Color("#8c93a2"), "bill_tip": Color("#15151a"),
			"cere": Color("#e8bc3c"), "claw": Color("#191513") },
		"golden_nape": true,
	}


## El modelo de una rapaz (lo que se guarda en la caché).
static func make(id: String, mobile: bool, cache: Dictionary) -> Dictionary:
	var P := species(id)
	var c: Dictionary = P.colors
	var m := Rig3D.Model.new(0.0 if mobile else 1.0)
	var px := 64 if mobile else 128
	var pat := _pattern(id, P, mobile, cache)
	m.mats["pluma"] = Mats3D.surface("pluma", mobile, cache, { "pattern": pat, "wobble": 0.003 })
	m.mats["plumon"] = Mats3D.surface("plumon", mobile, cache, { "rough": 0.9, "wobble": 0.004 })
	m.mats["escama"] = Mats3D.surface("escudo", mobile, cache, { "rough": 0.5, "spec": 0.45 })
	m.mats["queratina"] = Mats3D.surface("queratina", mobile, cache, { "rough": 0.28, "spec": 0.6 })
	m.mats["piel"] = Mats3D.surface("piel", mobile, cache, { "rough": 0.6 })
	m.mats["ojo"] = Mats3D.eye(P.eye[3], { "iris_r": 0.92 if P.has("owl") else 0.88, "pupil_r": 0.36 if P.has("owl") else 0.42,
		"sclera": (P.eye[3] as Color).darkened(0.3) })
	m.mats["garra"] = Mats3D.claw(mobile, cache)
	m.mats["primaria"] = Mats3D.cards(Tex3D.card_tex(String(P.wing.tip_kind), px * 2, cache), { "raise": 0.0, "wobble": 0.01 })
	m.mats["secundaria"] = Mats3D.cards(Tex3D.card_tex("rectriz", px * 2, cache), { "raise": 0.0, "wobble": 0.008 })
	m.mats["cobertera"] = Mats3D.cards(Tex3D.card_tex("cobertera", px, cache), { "raise": 0.025, "wobble": 0.006 })
	var made := 1
	for k: String in m.mats:
		made += int(m.mats[k].get("made", 0))
	m.bone("postura", "", Vector3.ZERO)
	var hip: Vector3 = (P.leg.knee as Vector3) + Vector3(0, 2, 0)
	m.bone("cuerpo", "postura", hip)
	m.bone("torso", "cuerpo", hip)
	m.bone("erizado", "torso", hip)
	m.fit_skip.append("erizado")
	var tr: Array = P.trunk
	var nk: Array = P.neck
	var neck_base := Vector3(float(nk[0][0]), float(nk[0][1]), 0)
	m.bone("cuello", "cuerpo", neck_base)
	var hd: Array = P.head
	var head_piv := Vector3(float(hd[0][0]) + 2.0, float(hd[0][1]), 0)
	m.bone("cabeza", "cuello", head_piv)
	_trunk(m, P)
	_head(m, P)
	_folded_wings(m, P)
	_tail(m, P)
	for s: float in [1.0, -1.0]:
		_leg(m, P, s, id)
	_open_wings(m, P)
	_ruffle(m, P)
	m.postures["plegadas"] = {}
	m.postures["abiertas"] = {}
	# las lechuzas y los búhos miran a quien los mira
	if P.has("owl"):
		m.postures["plegadas"]["cabeza"] = Vector3(0, -0.85, 0)
		m.postures["abiertas"]["cabeza"] = Vector3(0, -0.85, 0)
	var wing: Dictionary = P.wing
	m.info = { "kind": "ave", "ref_posture": "plegadas", "claw_natural": c.claw, "textures": made,
		"wing": { "len": float(wing.arm) + float(wing.prim), "body_half": float(tr[2][4]) * 0.8 } }
	var data := m.finish()
	data.fit = Rig3D.posed_box(data, Rig3D.globals(data, {}), m.fit_skip)
	return data


## El mapa del patrón de la especie (512 × 1024 en el escritorio): el tronco arriba (x alrededor: 0 y 1 el pecho, 0,5 la
## espalda; y de la cloaca al cuello), la cola abajo a la izquierda (y de la base a la punta) y el manto del ala abajo a la
## derecha (y del hombro a la punta). Negro o blanco sobre blanco: multiplica el color de los vértices.
static func _pattern(id: String, P: Dictionary, mobile: bool, cache: Dictionary) -> ImageTexture:
	var w := 256 if mobile else 512
	var k := float(w) / 512.0
	var b := PackedStringArray()
	var c: Dictionary = P.colors
	var ink := Tex3D.hex(Color(0.12, 0.1, 0.09))
	match id:
		"halcon":
			# barras en punta de flecha en el vientre y los pantalones; barras en la espalda
			for row in 9:
				var y := (40.0 + 28.0 * float(row)) * k
				for col in 7:
					var x := (float(col) - 3.0) * 26.0 * k
					for cx: float in [0.0, 512.0]:
						var xx := cx * k + x + (13.0 * k if row % 2 == 0 else 0.0)
						b.append(Tex3D.spindle(Vector2(xx - 9.0 * k, y + 2.0 * k), Vector2(xx + 9.0 * k, y), 4.0 * k, ink, 0.15))
			for row in 10:
				var y := (60.0 + 40.0 * float(row)) * k
				b.append(Tex3D.spindle(Vector2(150.0 * k, y), Vector2(362.0 * k, y + 6.0 * k), 6.0 * k, Tex3D.hex(Color(0.45, 0.48, 0.52))))
		"buho":
			# listas gruesas en el pecho y finas en el vientre, con barritas
			var rng_s := Rng.new(Rng.seed_of("buho:listas"))
			for i in 26:
				var x := (rng_s.next() * 120.0 - 60.0) * k
				var y := (250.0 + rng_s.next() * 200.0) * k
				for cx: float in [0.0, 512.0]:
					b.append(Tex3D.spindle(Vector2(cx * k + x, y), Vector2(cx * k + x + 3.0 * k, y + 34.0 * k), 9.0 * k, ink))
			for row in 7:
				var y := (40.0 + 28.0 * float(row)) * k
				b.append(Tex3D.spindle(Vector2(-10.0 * k, y), Vector2(110.0 * k, y + 4.0 * k), 3.0 * k, Tex3D.hex(Color(0.35, 0.25, 0.15))))
				b.append(Tex3D.spindle(Vector2(402.0 * k, y), Vector2(522.0 * k, y + 4.0 * k), 3.0 * k, Tex3D.hex(Color(0.35, 0.25, 0.15))))
		"lechuza":
			var rng_l := Rng.new(Rng.seed_of("lechuza:motas"))
			for i in 60:
				var x := (170.0 + rng_l.next() * 172.0) * k
				var y := (40.0 + rng_l.next() * 440.0) * k
				b.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Tex3D._n(x), Tex3D._n(y), Tex3D._n(2.4 * k), "#ffffff" if i % 2 == 0 else ink])
		"buitre":
			var rng_v := Rng.new(Rng.seed_of("buitre:listas"))
			for i in 40:
				var x := (130.0 + rng_v.next() * 252.0) * k
				var y := (60.0 + rng_v.next() * 400.0) * k
				b.append(Tex3D.spindle(Vector2(x, y), Vector2(x + 2.0 * k, y + 26.0 * k), 5.0 * k, Tex3D.hex(Color(1.0, 0.96, 0.86))))
	# la cola: sus bandas (de la base a la punta)
	var bands := int(P.get("tail_bands", 0))
	var bar := Tex3D.hex((c.tail_bar as Color) * 2.6 if (c.tail_bar as Color).v < 0.4 and id != "buitre" else Color(0.75, 0.75, 0.75))
	for i in bands:
		var y := (512.0 + (60.0 + 380.0 * float(i) / float(maxi(bands, 1))) * 1.0) * k
		b.append("<rect x=\"0\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\"/>" % [Tex3D._n(y), Tex3D._n(256.0 * k), Tex3D._n(28.0 * k), bar])
	# el manto del ala: barras (halcón, búhos) o motas (lechuza)
	if id == "halcon" or id == "buho" or id == "lechuza":
		for i in 12:
			var y := (530.0 + 40.0 * float(i)) * k
			b.append(Tex3D.spindle(Vector2(256.0 * k, y), Vector2(512.0 * k, y + 8.0 * k), 7.0 * k, Tex3D.hex(Color(0.45, 0.4, 0.38))))
	return Tex3D.pattern("rapaz|%s|%d" % [id, w], w, w * 2, "".join(b), cache)


## El tronco: un huevo inclinado, el pecho más lleno que la espalda; colores por zonas (pecho, espalda, banda pectoral).
static func _trunk(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var st: Array = []
	for e: Array in P.trunk:
		st.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var harpy := c.has("band") and P.has("crest")
	var paint := func(s01: float, u: float, _p: Vector3) -> Color:
		var front := 1.0 - smoothstep(0.12, 0.3, minf(u, 1.0 - u))  # 1 el pecho
		var col := (c.body as Color).lerp(c.breast, front)
		if harpy:
			col = col.lerp(c.band, front * smoothstep(0.62, 0.7, s01) * (1.0 - smoothstep(0.84, 0.92, s01)))
			col = col.lerp(c.head, front * smoothstep(0.9, 0.98, s01))
		if P.has("falcon"):
			col = col.lerp(Color("#f6f1e8"), front * smoothstep(0.7, 0.85, s01))
		return Color(col, 0.45 + 0.4 * (1.0 - front))
	m.loft("torso", "pluma", st, { "segs": 24, "rings": 16, "paint": paint, "tile": 2.4, "uv_rect": Rect2(0, 0, 1, 0.5), "flip_v": true })
	if P.has("vulture"):
		# el collar de plumas lanceoladas claras en la base del cuello
		var ruff := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(c.ruff, 0.9)
		m.loft("torso", "plumon", [[Vector3(-2, 66, 0), 10.0, 10.0, 11.0], [Vector3(1, 72, 0), 11.5, 11.5, 12.0], [Vector3(4, 77, 0), 7.0, 7.0, 7.5]],
			{ "segs": 20, "rings": 5, "paint": ruff, "tile": 2.0 })


## El cuello y la cabeza: el cráneo, el pico ganchudo con la cera, la ceja (las águilas), los ojos con su párpado; el disco
## facial y los penachos de los búhos; el penacho doble de la arpía; el cuello largo de plumón del buitre.
static func _head(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var nst: Array = []
	for e: Array in P.neck:
		nst.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var neck_paint := func(s01: float, _u: float, _p: Vector3) -> Color: return Color((c.body as Color).lerp(c.head, s01), 0.5)
	if P.has("vulture"):
		neck_paint = func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(c.head, 0.3)
	m.loft("cuello", "plumon", nst, { "segs": 18, "rings": 8, "paint": neck_paint, "tile": 1.6 })
	var hst: Array = []
	for e: Array in P.head:
		hst.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var gold := bool(P.get("golden_nape", false))
	var head_paint := func(s01: float, u: float, _p: Vector3) -> Color:
		var col: Color = c.head
		var top := 1.0 - smoothstep(0.0, 0.32, absf(u - 0.5))
		if gold:
			col = col.lerp(c.head_hi, top * (1.0 - smoothstep(0.55, 0.85, s01)))
		elif P.has("falcon"):
			# la capucha negra arriba y detrás; la garganta y la mejilla blancas, con la bigotera negra bajo el ojo
			var side := minf(u, 1.0 - u)  # 0 la garganta · 0,25 los lados · 0,5 la coronilla
			var throat := 1.0 - smoothstep(0.1, 0.16, side)
			var cheek := (1.0 - smoothstep(0.16, 0.22, side)) * smoothstep(0.2, 0.35, s01) * (1.0 - smoothstep(0.62, 0.72, s01))
			var moustache := (1.0 - smoothstep(0.03, 0.07, absf(s01 - 0.62))) * (1.0 - smoothstep(0.1, 0.22, side))
			col = (c.head as Color).lerp(Color("#f4efe6"), clampf(throat + cheek, 0.0, 1.0) * (1.0 - moustache))
		else:
			col = col.lerp(c.head_hi, 0.4 * top)
		return Color(col, 0.35)
	m.loft("cabeza", "plumon", hst, { "segs": 20, "rings": 10, "paint": head_paint, "tile": 1.2, "cap_len1": 1.0 if P.has("owl") else -1.0 })
	# el pico: la mandíbula de arriba en gancho (de la cera a la punta) y la de abajo
	var bl: Array = P.bill
	var bst: Array = []
	for e: Array in bl:
		bst.append([Vector3(e[0], e[1], 0), float(e[2]) * 0.95, float(e[2]) * 1.05, float(e[2]) * 0.82])
	var bill := func(s01: float, _u: float, _p: Vector3) -> Color:
		var cere := 1.0 - smoothstep(0.12, 0.22, s01)
		return (c.bill as Color).lerp(c.bill_tip, smoothstep(0.35, 0.95, s01)).lerp(c.cere, cere)
	m.loft("cabeza", "queratina", bst, { "segs": 14, "rings": 10, "paint": bill, "cap0": "round", "cap1": "point", "tile": 1.0 })
	var b0: Array = bl[0]
	var b1: Array = bl[1]
	var lower := Vector3(b0[0], float(b0[1]) - float(b0[2]) * 1.15, 0)
	var lower_end := Vector3(lerpf(b0[0], b1[0], 1.6), float(b1[1]) - float(b1[2]) * 1.6, 0)
	m.loft("cabeza", "queratina", [[lower, float(b0[2]) * 0.6, float(b0[2]) * 0.55, float(b0[2]) * 0.7], [lower_end, 0.12, 0.12, 0.12]],
		{ "segs": 12, "rings": 5, "col": (c.bill as Color).darkened(0.25), "cap1": "point", "tile": 1.0 })
	# los ojos y la ceja; en los búhos, el disco facial y los ojos hacia delante
	var eye: Array = P.eye
	var er := float(eye[2])
	var owl := P.has("owl")
	if owl:
		_owl_face(m, P)
	else:
		for s: float in [1.0, -1.0]:
			var hs := _section_at(hst, float(eye[0]))
			var ez := hs.w * sqrt(maxf(1.0 - pow((float(eye[1]) - hs.x) / maxf(hs.y, 0.1), 2.0), 0.05)) * 0.9
			var c0 := Vector3(eye[0], eye[1], ez * s)
			var look := Vector3(0.45, 0.02, 0.89 * s).normalized()
			Mammals3D._eye(m, "cabeza", c0, look, er, c.head)
			if P.has("eye_ring"):
				m.loft("cabeza", "piel", [[c0 - look * er * 0.1, er * 1.32, er * 1.32, er * 1.32], [c0 + look * er * 0.25, er * 1.12, er * 1.12, er * 1.12]],
					{ "segs": 14, "rings": 2, "side": Vector3.UP.cross(look).normalized(), "cap0": "none", "cap1": "none", "col": P.eye_ring })
			var brow := float(P.get("brow", 0.0))
			if brow > 0.0:
				m.blob("cabeza", "plumon", c0 + Vector3(-0.3, er * 1.1, -0.15 * s * er), Vector3(1, -0.15, 0), er * 2.2, er * 0.45 * brow, er * 0.35 * brow, er * 0.7,
					{ "col": Color(c.head, 0.2) })
	if P.has("crest"):
		# el penacho doble de la arpía: dos plumas oscuras que se levantan desde la nuca
		var h0: Array = hst[0]
		for s: float in [1.0, -1.0]:
			var base: Vector3 = (h0[0] as Vector3) + Vector3(3.0, 6.0, 2.2 * s)
			m.loft("cabeza", "pluma", [[base, 1.8, 1.8, 1.2], [base + Vector3(-3.0, 6.0, 0.6 * s), 1.6, 1.4, 0.9], [base + Vector3(-5.2, 12.0, 1.0 * s), 0.3, 0.3, 0.3]],
				{ "segs": 10, "rings": 5, "col": Color(c.band, 0.8), "cap1": "point", "uv_rect": BLANK_UV })
	m.anchors["eye"] = ["cabeza", Vector3(eye[0], eye[1], 0)]
	m.anchors["neck"] = ["cuello", Vector3(float(P.neck[0][0]), float(P.neck[0][1]), 0)]
	m.anchors["tail"] = ["cola", P.tail[0]]
	m.anchors["hip"] = ["cuerpo", (P.leg.knee as Vector3) + Vector3(0, 2, 0)]


## Sección de un loft de estaciones [Vector3, arriba, abajo, lado] a lo largo de x.
static func _section_at(st: Array, x: float) -> Vector4:
	return Rig3D.section_of(st, x)


## El disco facial de los búhos y las lechuzas (una concha llana delante de la cara, con el borde oscuro), los ojos hacia
## delante sobre él, las cejas claras y, en el búho real, los penachos.
static func _owl_face(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var hst: Array = P.head
	var e3: Array = hst[3]
	var e2: Array = hst[2]
	var fx := float(e3[0]) - 0.5
	var fy := float(e3[1]) + 0.6
	var rad := float(e2[4]) * 0.86
	var heart := String(P.owl) == "lechuza"
	var disc := func(_s01: float, u: float, p: Vector3) -> Color:
		var r := Vector2(p.y - fy, p.z).length() / rad
		return (c.disc as Color).lerp(c.disc_rim, smoothstep(0.78, 0.98, r))
	m.loft("cabeza", "plumon", [[Vector3(fx - 1.6, fy, 0), rad * 1.02, rad * (1.12 if heart else 1.0), rad * 1.05, 2.2],
		[Vector3(fx + 0.4, fy, 0), rad * 0.98, rad * (1.08 if heart else 0.96), rad, 2.2], [Vector3(fx + 0.9, fy, 0), rad * 0.85, rad * 0.9, rad * 0.86, 2.0]],
		{ "segs": 22, "rings": 4, "paint": disc, "side": Vector3.BACK, "tile": 1.4, "cap_len1": rad * 0.12 })
	var eye: Array = P.eye
	var er := float(eye[2])
	for s: float in [1.0, -1.0]:
		var c0 := Vector3(fx + 1.0 + er * 0.35, float(eye[1]), rad * 0.42 * s)
		Mammals3D._eye(m, "cabeza", c0, Vector3(0.95, 0.02, 0.3 * s).normalized(), er, c.disc)
	if String(P.owl) == "buho":
		var h1: Array = hst[1]
		for s: float in [1.0, -1.0]:
			var base := Vector3(float(h1[0]) - 1.0, float(h1[1]) + float(h1[2]) * 0.75, float(h1[4]) * 0.55 * s)
			m.loft("cabeza", "pluma", [[base, 1.8, 1.6, 1.0], [base + Vector3(-1.4, 4.0, 0.8 * s), 1.4, 1.2, 0.8], [base + Vector3(-2.6, 8.0, 1.4 * s), 0.25, 0.25, 0.25]],
				{ "segs": 10, "rings": 5, "col": Color(c.band, 0.8), "cap1": "point", "uv_rect": BLANK_UV })


## Las alas plegadas: un manto de plumas en cada costado, del hombro a la punta de las primarias (cerca de la punta de la
## cola), pegado al tronco; las primarias, unas tarjetas escalonadas en la punta.
static func _folded_wings(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var w: Dictionary = P.wing
	var sh: Vector3 = w.shoulder
	var tip: Vector3 = w.tip
	var ch := float(w.chord)
	var tr: Array = []
	for e: Array in P.trunk:
		tr.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		m.bone("ala_plegada" + sf, "torso", sh)
		var st: Array = []
		for i in 6:
			var f := float(i) / 5.0
			var p := sh.lerp(tip, f) + Vector3(0, 0, 0)
			# pegada al costado del tronco a esa altura (por encima de la cloaca, el ancho del tronco; debajo, el de la cola)
			var e := Rig3D.section_of_y(tr, p.y)
			var zz := maxf(e.w * 0.92, float(P.tail[2]) * 0.55) + 0.6 - 0.8 * f
			p.z = zz * s
			var chord := ch * (0.55 + 0.45 * sin(PI * minf(f * 1.3, 1.0))) * (1.0 - 0.75 * f)
			st.append([p, chord * 0.55, chord * 0.45, maxf(ch * 0.09 * (1.0 - 0.6 * f), 0.35)])
		var wpaint := func(s01: float, _u: float, _p: Vector3) -> Color:
			return Color((c.covert as Color).lerp(c.wing, smoothstep(0.05, 0.4, s01)).lerp(c.prim, smoothstep(0.45, 0.8, s01)), 0.6)
		m.loft("ala_plegada" + sf, "pluma", st, { "segs": 14, "rings": 14, "paint": wpaint, "tile": 3.0, "uv_rect": Rect2(0.5, 0.5, 0.5, 0.5),
			"cap0": "round", "cap1": "round" })
		# las primarias: tarjetas escalonadas hacia la punta, sobre el manto
		var n := 5
		var d := (tip - sh).normalized()
		for k in n:
			var f0 := 0.42 + 0.1 * float(k)
			var base := sh.lerp(tip, f0)
			var e := Rig3D.section_of_y(tr, base.y)
			base.z = (maxf(e.w * 0.92, float(P.tail[2]) * 0.55) + 1.0 - 0.5 * f0) * s
			var l := tip.distance_to(base) * (1.0 - 0.06 * float(k))
			var ax := (d + Vector3(0, 0, -0.05 * s)).normalized() * l
			var wv := Vector3(0, 0, 1).cross(d).normalized() * ch * 0.22
			_card(m, "ala_plegada" + sf, "primaria", base + Vector3(0, ch * (0.08 - 0.04 * float(k)), 0), ax, wv, Vector3(0, 0.15, s).normalized(),
				(c.prim as Color).lerp(c.wing, 0.15 * float(k)))


## La cola: un abanico de rectrices (una pieza plana, ancha y fina) con sus bandas, y tarjetas en la punta para el borde.
static func _tail(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var t: Array = P.tail
	var base: Vector3 = t[0]
	var tip: Vector3 = t[1]
	var w0 := float(t[2])
	var w1 := float(t[3])
	var th := float(t[4])
	m.bone("cola", "cuerpo", base)
	var tpaint := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(c.tail, 0.8)
	m.loft("cola", "pluma", [[base, th, th, w0 * 0.5], [base.lerp(tip, 0.5), th * 0.8, th * 0.8, lerpf(w0, w1, 0.5) * 0.5], [tip, th * 0.5, th * 0.5, w1 * 0.5]],
		{ "segs": 14, "rings": 8, "paint": tpaint, "tile": 3.0, "uv_rect": Rect2(0, 0.5, 0.5, 0.5), "side": Vector3.FORWARD, "cap1": "round", "cap_len1": w1 * 0.18 })
	var d := (tip - base).normalized()
	for k in 5:
		var f := (float(k) - 2.0) / 2.0
		var at := tip - d * (tip.distance_to(base) * 0.25) + Vector3(0, 0, f * w1 * 0.36)
		var ax := (d + Vector3(0, 0, f * 0.12)).normalized() * tip.distance_to(base) * 0.32
		_card(m, "cola", "secundaria", at, ax, Vector3(0, 0, 1) * w1 * 0.26, d.cross(Vector3(0, 0, 1)).normalized(), (c.tail as Color).darkened(0.1))


## Una pata (s = +1 la de quien mira): los pantalones de plumas, el tarso (desnudo con escamas o emplumado), los cuatro
## dedos (el pulgar detrás) en dos falanges cada uno, que se cierran al agarrarse, y sus talones.
static func _leg(m: Rig3D.Model, P: Dictionary, s: float, id: String) -> void:
	var c: Dictionary = P.colors
	var L: Dictionary = P.leg
	var sf := "_n" if s > 0.0 else "_f"
	var z := float(L.z) * s
	var knee: Vector3 = (L.knee as Vector3) + Vector3(0, 0, z)
	var ankle: Vector3 = (L.ankle as Vector3) + Vector3(0, 0, z * 0.95)
	var mtp: Vector3 = (L.mtp as Vector3) + Vector3(0, 0, z * 0.9)
	m.bone("tibia" + sf, "cuerpo", knee)
	m.bone("tarso" + sf, "tibia" + sf, ankle)
	m.bone("pie" + sf, "tarso" + sf, mtp)
	var tr := float(L.trouser_r)
	var trouser := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(c.trouser, 0.9)
	m.loft("tibia" + sf, "plumon", [[knee + Vector3(0, 3, 0), tr, tr, tr * 0.9], [knee.lerp(ankle, 0.55), tr * 0.85, tr * 0.8, tr * 0.75],
		[ankle + Vector3(0, -0.3, 0), tr * 0.55, tr * 0.5, tr * 0.5]], { "segs": 16, "rings": 6, "paint": trouser, "tile": 2.0 })
	var rr := float(L.tarsus_r)
	var bare := bool(L.bare)
	var tcol: Color = c.leg
	m.loft("tarso" + sf, "escama" if bare else "plumon", [[ankle, rr * 1.15, rr * 1.1, rr * 1.1], [ankle.lerp(mtp, 0.5), rr, rr * 0.95, rr * 0.95],
		[mtp, rr * 1.15, rr * 1.0, rr * 1.3]], { "segs": 14, "rings": 7, "col": Color(tcol, 0.5), "tile": rr * 1.4 })
	# los dedos: el pulgar (I) detrás; el II por dentro; el III delante; el IV por fuera (en búhos y lechuzas, algo atrás)
	var toes: Array = L.toes
	var tr2 := float(L.toe_r)
	var owl := P.has("owl")
	var yaws := [180.0 - 10.0 * s, -22.0 * s, 4.0 * s, (70.0 if owl else 26.0) * s]
	var cl := Mammals3D.claw_of(id)
	var lens := [1.0, 1.0, 0.8, 0.7]
	for i in 4:
		var name := "dedo%d%s" % [i + 1, sf]
		var yaw := deg_to_rad(float(yaws[i]))
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var l := float(toes[i])
		var r := tr2 * (1.15 if i == 0 else 1.0)
		var p0 := mtp + dir * r * 0.6
		var p1 := p0 + dir * l * 0.5 + Vector3(0, -(mtp.y - r) * 0.85, 0)
		var p2 := p0 + dir * l + Vector3(0, -(mtp.y - r * 0.8), 0)
		m.bone(name + "_0", "pie" + sf, mtp)
		m.bone(name + "_1", name + "_0", p1)
		var toe_paint := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(c.toe, 0.2)
		m.loft(name + "_0", "escama" if bare or i > 0 else "escama", [[p0, r, r * 1.1, r * 1.1], [p1, r * 0.85, r * 1.0, r]],
			{ "segs": 10, "rings": 4, "paint": toe_paint, "tile": r * 1.6 })
		m.loft(name + "_1", "escama", [[p1, r * 0.85, r, r], [p2, r * 0.6, r * 0.7, r * 0.7]], { "segs": 10, "rings": 4, "paint": toe_paint, "tile": r * 1.6 })
		# el talón: sale de la punta del dedo, curvado hacia abajo
		m.claw(name + "_1", "talon%d%s" % [i + 1, sf], p2 + dir * r * 0.2 + Vector3(0, r * 0.2, 0), dir + Vector3(0, 0.25, 0), Vector3.UP,
			cl.x * float(lens[i]), r * 1.25, r * 0.8, cl.y, s < 0.0)


## El ala abierta: el brazo (del hombro a la muñeca, con las coberteras) y la mano, con las secundarias y las primarias en
## tarjetas que se abren en abanico. En reposo, extendida hacia fuera (z) y horizontal; la pose la pliega y la levanta.
static func _open_wings(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var w: Dictionary = P.wing
	var sh: Vector3 = w.shoulder
	var arm := float(w.arm)
	var hand := float(w.hand)
	var sec := float(w.sec)
	var prim := float(w.prim)
	var half := float(P.trunk[2][4])
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var root := sh + Vector3(0, 0, half * 0.8 * s)
		var wrist := root + Vector3(0, 0, arm * s)
		m.bone("ala" + sf, "cuerpo", root)
		m.bone("mano" + sf, "ala" + sf, wrist)
		m.fit_skip.append("ala" + sf)
		m.fit_skip.append("mano" + sf)
		# el brazo: un perfil aplastado (el borde de ataque grueso delante), con las coberteras
		var arm_paint := func(s01: float, _u: float, _p: Vector3) -> Color: return Color((c.covert as Color).lerp(c.wing, s01 * 0.5), 0.5)
		m.loft("ala" + sf, "pluma", [[root, sec * 0.12, sec * 0.2, 1.6], [root.lerp(wrist, 0.5) + Vector3(0.5, 0, 0), sec * 0.1, sec * 0.2, 1.3],
			[wrist, sec * 0.08, sec * 0.13, 1.0]], { "segs": 12, "rings": 6, "paint": arm_paint, "tile": 3.0, "side": Vector3.UP if s > 0.0 else Vector3.DOWN,
			"uv_rect": BLANK_UV })
		# las secundarias: hacia atrás desde el brazo
		var ns := 7
		for k in ns:
			var f := (float(k) + 0.5) / float(ns)
			var at := root.lerp(wrist, f) + Vector3(-sec * 0.1, 0.02 * float(k), 0)
			var ax := Vector3(-1, 0, 0.1 * s).normalized() * sec * (0.95 - 0.05 * f)
			_card(m, "ala" + sf, "secundaria", at, ax, Vector3(0, 0, s) * (arm / float(ns)) * 2.1, Vector3(0, 1, 0), (c.wing as Color).lerp(c.prim, 0.3 * f))
		# las primarias: en abanico desde la mano (la exterior delante); el abanico lo cierra la pose
		var np := 8
		for k in np:
			var f := float(k) / float(np - 1)  # 0 la exterior · 1 la interior
			var ang := deg_to_rad(lerpf(-8.0, 58.0, f))
			var dir := Vector3(-sin(ang), 0, cos(ang) * s)
			var l := prim * lerpf(1.0, 0.68, f) * (0.88 if k == 0 and String(w.tip_kind) == "pluma_dedo" else 1.0)
			_card(m, "mano" + sf, "primaria", wrist + Vector3(0, -0.05 * float(k), 0), dir * l, Vector3(0, 1, 0).cross(dir).normalized() * prim * 0.18,
				Vector3(0, 1, 0), (c.prim as Color).lerp(c.wing, 0.3 * f))
		# la mano: la base de las primarias
		m.loft("mano" + sf, "pluma", [[wrist, sec * 0.08, sec * 0.13, 1.0], [wrist + Vector3(-hand * 0.08, 0, hand * 0.3 * s), sec * 0.06, sec * 0.09, 0.8]],
			{ "segs": 10, "rings": 3, "col": Color(c.wing, 0.4), "side": Vector3.UP if s > 0.0 else Vector3.DOWN, "uv_rect": BLANK_UV })


## Plumas que se erizan: tarjetas sobre la nuca y la espalda (escondidas si no hay miedo ni viento fuerte).
static func _ruffle(m: Rig3D.Model, P: Dictionary) -> void:
	var c: Dictionary = P.colors
	var st: Array = []
	for e: Array in P.trunk:
		st.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4]])
	var n := 9
	for k in n:
		var f := 0.3 + 0.65 * float(k) / float(n - 1)
		var y := lerpf((st[0][0] as Vector3).y, (st[st.size() - 1][0] as Vector3).y, f)
		var e := Rig3D.section_of_y(st, y)
		for s: float in [1.0, -1.0]:
			for th: float in [0.35, 0.8]:
				var p := Vector3(e.x - e.y * cos(th) * 0.95, y, s * e.w * sin(th) * 0.95)
				var out := Vector3(-cos(th), 0.15, s * sin(th)).normalized()
				var ax := Vector3(-0.35, -1.0, 0).normalized() * (e.y * 0.45)
				_card(m, "erizado", "cobertera", p, ax, out.cross(ax.normalized()).normalized() * e.y * 0.32, out, (c.body as Color).lerp(c.covert, 0.4))


## Una tarjeta (pluma): base at, eje ax (largo), ancho wv, normal out (la luz); la punta, suelta (alfa del color 1).
static func _card(m: Rig3D.Model, b: String, mat: String, at: Vector3, ax: Vector3, wv: Vector3, out: Vector3, col: Color) -> void:
	Mammals3D._card(m, b, mat, at, ax, wv, out, col)


## La pose de cada fotograma: respiración, la cabeza que mira, el parpadeo, la cola con el viento, el cuerpo que se agacha
## contra el aire, el plumaje erizado (y ahuecado), el pie que se cierra con miedo y las alas (abiertas en abanico y
## levantadas con la sustentación).
static func pose(a: RefCounted, p: Dictionary) -> void:
	var t: float = a.get("_t")
	var open := clampf(float(p.get("wing_open", 0.0)), 0.0, 1.0)
	var lift := clampf(float(p.get("wing_lift", 0.5)), 0.0, 1.0)
	var bristle := clampf(maxf(float(p.get("bristle", 0.0)), float(p.get("scared", 0.0)) * 0.6), 0.0, 1.0)
	var flutter := clampf(float(p.get("flutter", 0.0)), 0.0, 1.0)
	var scared := clampf(float(p.get("scared", 0.0)), 0.0, 1.0)
	a.call("rot_add", "postura", Vector3(0, 0, -float(p.get("lean", 0.0))))
	var br := 1.0 + 0.008 * sin(TAU * t / 2.6)
	var puff := 1.0 + 0.06 * bristle
	a.call("scale_bone", "torso", Vector3(puff, br * puff, puff))
	var air_t: float = a.get("_air_t")
	a.call("rot_add", "cola", Vector3(0, 0.05 * flutter * sin(air_t * 23.0), 0.04 * flutter * sin(air_t * 37.0)))
	a.call("rot_add", "cabeza", Vector3(0, 0.08 * _wob(t, 0.7, 1.3), -(0.05 * _wob(t, 0.6, 2.1) + 0.03 * flutter * sin(air_t * 17.0))))
	a.call("show_bone", "erizado", bristle > 0.02)
	# el pie se cierra (agarrado con miedo: los talones se clavan)
	var grip := 0.35 * scared
	for side: String in ["_n", "_f"]:
		for i in 4:
			a.call("rot_add", "dedo%d%s_0" % [i + 1, side], Vector3(0, 0, -0.35 * grip if i > 0 else 0.35 * grip))
			a.call("rot_add", "dedo%d%s_1" % [i + 1, side], Vector3(0, 0, -0.6 * grip if i > 0 else 0.6 * grip))
	# las alas: plegadas (el manto) o abiertas (el brazo sale del costado, el abanico se abre y se levanta)
	a.call("show_bone", "ala_plegada_n", open < 0.45)
	a.call("show_bone", "ala_plegada_f", open < 0.45)
	var theta := deg_to_rad(lerpf(8.0, 70.0, lift)) * open
	for side: String in ["_n", "_f"]:
		var sg := 1.0 if side == "_n" else -1.0
		a.call("show_bone", "ala" + side, open > 0.05)
		# plegada: el brazo hacia atrás y abajo, pegado al cuerpo; abierta: hacia fuera, levantada theta
		var fold := 1.0 - open
		a.call("rot_add", "ala" + side, Vector3(-theta * sg, -sg * fold * 1.25, -fold * 0.5))
		a.call("rot_add", "mano" + side, Vector3(0, sg * fold * 2.2, 0))
	a.call("show_shadow", 1.0 - 0.6 * open)
	a.call("blink")


static func _wob(t: float, f: float, seed: float) -> float:
	return 0.6 * sin(t * f + seed) + 0.4 * sin(t * f * 2.13 + seed * 1.7)
