## Cetrería · el cuerpo de las rapaces en alta definición (unidad 5i, petición 37), hecho en código desde cero e
## independiente de los modelos del coche en marcha. Solo dibujo; el tamaño es el de su ficha (core/lab/care_anatomy.gd:
## el largo del pico a la cola, la envergadura con el ala plegada y la masa); las proporciones de la cabeza, del cuello y
## de cada pluma son de dibujo.
## Tumbada de lado sobre el banco (la izquierda abajo), con el lomo hacia −X, la cabeza hacia −Z y las patas hacia el borde
## (+X), enganchada a las patas de la 5h por sus anclajes (el talón: el tarso es de la pata). De cerca:
##   - el tronco y el cuello con las plumas de contorno montadas como tejas (tarjetas con raquis y barbas);
##   - el ala plegada de arriba con sus capas: diez primarias (con los «dedos» de las águilas y los buitres), las
##     secundarias, las terciarias, las coberteras mayores, medianas y menores, las escapulares y el álula; de la de abajo,
##     solo las puntas de las primarias;
##   - la cola: doce timoneras con sus coberteras de encima y de debajo;
##   - los muslos con sus calzones de plumas, que bajan hasta el talón y tapan donde empieza el tarso de la pata;
##   - la cabeza de cada tipo (águila, arpía con su doble cresta, halcón con la bigotera y el anillo del ojo, búho real con
##     su disco facial y sus penachos, lechuza con su corazón blanco, buitre con el cuello largo de plumón y la gorguera),
##     el pico ganchudo de queratina con su cera y sus narinas, la comisura y los ojos con brillo y párpados.
## model() es puro (solo arrays y transformaciones): se puede llamar desde un hilo y su resultado se guarda en la caché.
extends RefCounted

const BodyKit = preload("res://app/lab/cetreria/body_kit.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const Rng = preload("res://core/shared/rng.gd")

const MM := 0.001
## El plumaje de cada rapaz (dibujo, de las guías de campo): el color del lomo, de la tripa, de la cabeza, de la cola, de
## las rémiges y de las coberteras, el de las marcas y el claro; el dibujo de la tripa, de las coberteras, de las rémiges y
## de la cola (los de body_feather.gdshader) con sus barras; el pico [base, punta], la cera, el ojo [iris, oscuro], el
## anillo del ojo ("" sin anillo), la cara (body_plumage.gdshader) y el tipo de cabeza.
const PLUMAGE := {
	"aguila": { "back": "#33220F", "belly": "#3D2916", "c_head": "#B8853A", "tail": "#463829", "remex": "#18120D", "covert": "#4A321D",
		"mark": "#140E09", "pale": "#C9A467", "belly_pat": 0, "covert_pat": 4, "remex_pat": 1, "remex_bars": 5.0, "tail_pat": 1, "tail_bars": 4.0,
		"bill": ["#40444C", "#0E0F12"], "cere": "#E6B43A", "iris": ["#9A6524", "#3E230A"], "ring": "", "face": 0, "head": "aguila", "fingers": 1.0 },
	"arpia": { "back": "#2A2A2D", "belly": "#E9E7E1", "c_head": "#A3A3A6", "tail": "#2C2C2F", "remex": "#1B1B1E", "covert": "#323235",
		"mark": "#0E0E10", "pale": "#C9C9CB", "belly_pat": 0, "covert_pat": 0, "remex_pat": 1, "remex_bars": 4.0, "tail_pat": 1, "tail_bars": 3.0,
		"bill": ["#26262A", "#0B0B0C"], "cere": "#2A2A2E", "iris": ["#8A7A62", "#3A3024"], "ring": "", "face": 1, "head": "arpia", "fingers": 1.0 },
	"halcon": { "back": "#4F5967", "belly": "#EEE3CF", "c_head": "#1E2228", "tail": "#56606C", "remex": "#2E333B", "covert": "#56616F",
		"mark": "#17191D", "pale": "#F4ECDD", "belly_pat": 1, "covert_pat": 1, "remex_pat": 1, "remex_bars": 9.0, "tail_pat": 1, "tail_bars": 8.0,
		"bill": ["#62718A", "#14171C"], "cere": "#F2C930", "iris": ["#24170E", "#0B0705"], "ring": "#F2C930", "face": 2, "head": "halcon", "fingers": 0.0 },
	"buho": { "back": "#5B3F23", "belly": "#C9934F", "c_head": "#BE8A4F", "tail": "#6B4B2B", "remex": "#8A6236", "covert": "#6C4A29",
		"mark": "#1C130B", "pale": "#EEDFC6", "belly_pat": 2, "covert_pat": 2, "remex_pat": 1, "remex_bars": 6.0, "tail_pat": 1, "tail_bars": 6.0,
		"bill": ["#2A2622", "#0D0C0B"], "cere": "#3A332C", "iris": ["#F2780E", "#A63A06"], "ring": "", "face": 3, "head": "buho", "fingers": 0.0 },
	"lechuza": { "back": "#C99B5A", "belly": "#F6F1E8", "c_head": "#C68E4B", "tail": "#D6AC6C", "remex": "#DDB77E", "covert": "#C99C5E",
		"mark": "#4A3624", "pale": "#FFFEFA", "belly_pat": 0, "covert_pat": 3, "remex_pat": 1, "remex_bars": 4.0, "tail_pat": 1, "tail_bars": 4.0,
		"bill": ["#E9DAC4", "#B9A890"], "cere": "#E3D0B2", "iris": ["#120A06", "#040202"], "ring": "", "face": 4, "head": "lechuza", "fingers": 0.0 },
	"buitre": { "back": "#8C6C49", "belly": "#B4935F", "c_head": "#D9D2C6", "tail": "#2B221B", "remex": "#211A14", "covert": "#9E7C53",
		"mark": "#3B2B1D", "pale": "#F3EFE7", "belly_pat": 4, "covert_pat": 4, "remex_pat": 0, "remex_bars": 0.0, "tail_pat": 0, "tail_bars": 0.0,
		"bill": ["#DACBAA", "#8C7C62"], "cere": "#6C6C74", "iris": ["#B9872F", "#5B3B10"], "ring": "", "face": 5, "head": "buitre", "fingers": 1.0 },
}
## La cabeza de cada tipo (dibujo, en fracciones del largo de la cabeza con el pico): el cráneo [largo, alto, ancho], la
## ceja (cuánto vuela sobre el ojo), el pico [largo, alto, ancho, gancho], el ojo [radio, adelante, arriba, cuánto mira al
## frente (0 de lado, 1 de frente)], el disco facial (los búhos), el cuello [radio frente al ancho del cráneo] y los
## párpados [borde del de arriba y del de abajo cerrados (° desde arriba), lo que se abre cada uno (°)]: las aves cierran
## con el de abajo; los búhos, con el de arriba.
const HEADS := {
	"aguila": { "skull": [0.66, 0.5, 0.48], "brow": 1.0, "bill": [0.36, 0.25, 0.16, 1.15], "eye": [0.076, 0.16, 0.07, 0.32], "disc": 0.0, "neck": 0.72 },
	"arpia": { "skull": [0.68, 0.56, 0.54], "brow": 0.6, "bill": [0.34, 0.26, 0.17, 1.2], "eye": [0.074, 0.17, 0.07, 0.4], "disc": 0.35, "neck": 0.78 },
	"halcon": { "skull": [0.74, 0.62, 0.6], "brow": 0.45, "bill": [0.27, 0.26, 0.19, 1.3], "eye": [0.09, 0.18, 0.06, 0.34], "disc": 0.0, "neck": 0.72 },
	"buho": { "skull": [0.78, 0.86, 0.82], "brow": 0.0, "bill": [0.17, 0.2, 0.14, 1.3], "eye": [0.11, 0.3, 0.1, 0.92], "disc": 1.0, "neck": 1.0,
		"lids": [100.0, 104.0, 78.0, 12.0] },
	"lechuza": { "skull": [0.8, 0.84, 0.76], "brow": 0.0, "bill": [0.2, 0.17, 0.11, 1.2], "eye": [0.08, 0.3, 0.1, 0.95], "disc": 1.0, "neck": 0.95,
		"lids": [100.0, 104.0, 78.0, 12.0] },
	"buitre": { "skull": [0.5, 0.36, 0.34], "brow": 0.5, "bill": [0.5, 0.26, 0.15, 0.9], "eye": [0.06, 0.12, 0.08, 0.25], "disc": 0.0, "neck": 0.5 },
}


static func _c(hex: String) -> Color:
	return Color(hex)


## Los materiales de una rapaz: { id: { shader, params } } (care_body.gd los hace una vez por especie y calidad).
static func materials(art: String, mobile: bool) -> Dictionary:
	var pl: Dictionary = PLUMAGE.get(art, PLUMAGE.aguila)
	var L := CareAnatomy.draw_length_m(art)
	var hd: Dictionary = HEADS.get(String(pl.head), HEADS.aguila)
	var H := L * float((CareAnatomy.DRAW.get(art, CareAnatomy.DRAW.aguila) as Dictionary).head_k)
	var sk: Array = hd.skull
	var detail := 0.0 if mobile else 1.0
	var body_pat := int(pl.belly_pat)
	var feather_mm := 0.06 * L * 1000.0
	return {
		"plumage_body": { "shader": "plumage", "params": { "mode": 0, "back_color": _c(String(pl.back)), "belly_color": _c(String(pl.belly)),
			"head_color": _c(String(pl.c_head)), "tail_color": _c(String(pl.tail)), "mark_color": _c(String(pl.mark)), "pale_color": _c(String(pl.pale)),
			"s_head": 0.0, "s_tail": 2.0, "belly_from": 0.62, "body_pattern": body_pat, "feather_mm": feather_mm * 0.45, "relief_mm": feather_mm * 0.02,
			"breath_mm": L * 9.0, "detail": detail } },
		"plumage_head": { "shader": "plumage", "params": { "mode": 1, "face": int(pl.face), "back_color": _c(String(pl.back)), "belly_color": _c(String(pl.belly)),
			"head_color": _c(String(pl.c_head)), "tail_color": _c(String(pl.tail)), "mark_color": _c(String(pl.mark)), "pale_color": _c(String(pl.pale)),
			"s_head": 1.0, "s_tail": 2.0, "body_pattern": 0, "feather_mm": feather_mm * 0.16, "relief_mm": feather_mm * 0.012,
			"head_half": Vector3(float(sk[0]), float(sk[1]), float(sk[2])) * H * 0.5, "fluffy": 1.0 if String(pl.head) == "buitre" else 0.0, "detail": detail } },
		"plume_leg": { "shader": "fur", "params": { "root_color": _c(String((CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila) as Dictionary).plume[0])),
			"tip_color": _c(String((CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila) as Dictionary).plume[1])),
			"belly_color": _c(String((CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila) as Dictionary).plume[1])), "belly": 0.0,
			"fur_mm": 14.0 * L, "strand_mm": 0.45, "clump_mm": 3.5, "clump": 0.8, "thick": 1.2, "comb": 1.0, "droop": 0.25,
			"tone_var": 0.18, "breath_mm": 0.0, "rough": 0.85, "spec": 0.2 } },
		"feather": { "shader": "feather", "params": { "bar_color": _c(String(pl.mark)), "edge_color": _c(String(pl.pale)),
			"down_color": _c(String(pl.pale)).lerp(Color(0.8, 0.78, 0.74), 0.5), "shaft_color": _c(String(pl.pale)), "barb_mm": maxf(0.25, L * 0.5),
			"breath_mm": L * 9.0 } },
		"bill": { "shader": "skin", "params": { "mode": 0, "color_a": _c(String((pl.bill as Array)[0])), "color_b": _c(String((pl.bill as Array)[1])),
			"rough": 0.48, "spec": 0.32, "tip_from": 0.45, "len_mm": L * float((hd.bill as Array)[0]) * float((CareAnatomy.DRAW.get(art, CareAnatomy.DRAW.aguila) as Dictionary).head_k) * 1000.0,
			"relief_mm": 0.08, "detail": detail } },
		"cere": { "shader": "skin", "params": { "mode": 1, "color_a": _c(String(pl.cere)), "color_b": _c(String(pl.cere)).darkened(0.25), "rough": 0.5,
			"spec": 0.35, "relief_mm": 0.1, "detail": detail } },
		"ring": { "shader": "skin", "params": { "mode": 1, "color_a": _c(String(pl.ring if String(pl.ring) != "" else pl.cere)), "color_b": _c(String(pl.ring if String(pl.ring) != "" else pl.cere)).darkened(0.3),
			"rough": 0.45, "spec": 0.35, "relief_mm": 0.08, "detail": detail } },
		"eye": { "shader": "eye", "params": { "iris_color": _c(String((pl.iris as Array)[0])), "iris_dark": _c(String((pl.iris as Array)[1])),
			"sclera_color": _c(String((pl.iris as Array)[1])).darkened(0.3), "iris_r": 0.78, "pupil_r": 0.46 if String(pl.head) in ["buho", "lechuza"] else 0.38 } },
		"lid": { "shader": "skin", "params": { "mode": 6, "color_a": _c(String(pl.c_head if int(pl.face) in [1, 4, 5] else pl.back)).lerp(_c(String(pl.cere)), 0.25),
			"color_b": _c(String(pl.ring if String(pl.ring) != "" else pl.mark)), "rough": 0.6, "spec": 0.3, "rim_mm": maxf(H * 1000.0 * 0.012, 0.6), "relief_mm": 0.05 } },
		# 5t-B: el paladar oscuro (se ve al abrir el pico) y la membrana nictitante, translúcida
		"mouth": { "shader": "skin", "params": { "mode": 5, "color_a": Color("#7A4248"), "color_b": Color("#3A1A1E"), "rough": 0.45, "spec": 0.35, "relief_mm": 0.0, "detail": 0.0 } },
		"nict": { "shader": "std", "params": { "albedo": Color(0.86, 0.9, 0.95, 0.55), "rough": 0.22 } },
	}


## El modelo de una rapaz. art: la especie (la garra del banco); anchors: { «derecha», «izquierda»: Transform3D en la raíz
## (el talón) }; claw: { base_r_mm, length_mm } (la garra del motor: da el grosor del tarso de la pata); mobile: menos
## detalle. pose (unidad 4r: el coche en marcha; vacío en la cetrería, que la dibuja como siempre): posada, no tumbada (la
## coloca app/lab/animals/hd3d.gd con los pies en el suelo): lift (m, lo que se aparta el tronco de los talones hacia el
## lomo), head_pitch (cuánto mira la cabeza hacia las patas: con el cuerpo levantado, la cabeza mira al frente), sin la
## mesa que la aplasta, con el tronco entre las dos patas y la cabeza y el cuello en su eje.
## → { parts: { nombre: { arrays, mat, node } }, nodes: { nombre: { parent, xf } }, layout, box }
static func model(art: String, anchors: Dictionary, claw: Dictionary, mobile: bool, pose := {}) -> Dictionary:
	var car := not pose.is_empty()
	var pl: Dictionary = PLUMAGE.get(art, PLUMAGE.aguila)
	var hd: Dictionary = HEADS.get(String(pl.head), HEADS.aguila)
	var rng := Rng.new(Rng.seed_of("cuerpo|" + art))
	var L := CareAnatomy.draw_length_m(art)
	var dr: Dictionary = CareAnatomy.DRAW.get(art, CareAnatomy.DRAW.aguila)
	var head_len := L * float(dr.head_k)
	var tail_len := L * float(dr.tail_k)
	var girth := L * float(dr.girth_k)
	var depth := girth * 1.12
	var wing := CareAnatomy.folded_wing_m(art)
	var rest := L - head_len - tail_len
	var neck_share := 0.42 if art == "buitre" else 0.26
	var trunk_len := rest * (1.0 - neck_share)
	var neck_len := rest * neck_share
	# los talones (anclajes de la 5h) y el tarso de la pata, para taparlo
	var a_r: Transform3D = anchors.get("derecha", Transform3D(Basis.IDENTITY, Vector3(-0.09, 0.012, -0.05)))
	var a_l: Transform3D = anchors.get("izquierda", Transform3D(Basis.IDENTITY, Vector3(-0.08, 0.012, 0.055)))
	var hc := (a_r.origin + a_l.origin) * 0.5
	var rp: Dictionary = CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila)
	var tarsus_r := float((rp.tarsus as Array)[1]) * float(claw.get("base_r_mm", 5.25)) * MM
	# dónde va el tronco: la tripa por detrás de los talones; las caderas hacia el final del tronco
	var belly_x := hc.x - 0.085 * L - float(pose.get("lift", 0.0))
	var x_c := belly_x - depth * 0.5
	var y_c := (a_r.origin.y + a_l.origin.y) * 0.5 if car else girth * 0.5 * 0.9
	var z_front := hc.z - 0.6 * trunk_len
	var z_vent := z_front + trunk_len
	var lay := { "L": L, "head_len": head_len, "tail_len": tail_len, "girth": girth, "depth": depth, "wing": wing, "x_c": x_c,
		"y_c": y_c, "z_front": z_front, "z_vent": z_vent, "neck_len": neck_len, "trunk_len": trunk_len, "belly_x": belly_x }
	var ring := 24 if mobile else 44
	var parts := {}
	var nodes := {}
	var body_surf: Array = []
	var cards: Array = []
	# ── el tronco con el cuello: de dentro de la cabeza a la rabadilla ──
	var hx := float((hd.skull as Array)[0]) * head_len
	var hh := float((hd.skull as Array)[1]) * head_len
	var hw := float((hd.skull as Array)[2]) * head_len
	var head_c := Vector3(x_c - depth * 0.12, y_c if car else hw * 0.5 * 0.96 + 0.002, z_front - neck_len - hx * 0.28)
	var fwd := Vector3(0.22, 0.0, -1.0).normalized()
	if String(pl.head) in ["buho", "lechuza"]:
		fwd = Vector3(0.35, 0.0, -1.0).normalized()
	if car:
		fwd = Vector3(float(pose.get("head_pitch", 0.22)), 0.0, -1.0).normalized()
	var dorsal := (Vector3(-1.0, 0.0, 0.0) - fwd * Vector3(-1.0, 0.0, 0.0).dot(fwd)).normalized()
	var right := fwd.cross(dorsal).normalized()
	var head_xf := Transform3D(Basis(fwd, dorsal, right), head_c)
	lay["head_xf"] = head_xf
	lay["head_size"] = Vector3(hx, hh, hw)
	var n_st := 30 if mobile else 64
	var sp_pts := PackedVector3Array([
		head_c - fwd * hx * 0.1,
		Vector3(x_c - depth * 0.1, y_c if car else y_c * 0.86, z_front - neck_len * 0.45),
		Vector3(x_c - depth * 0.02, y_c if car else y_c * 0.97, z_front + trunk_len * 0.18),
		Vector3(x_c, y_c, z_front + trunk_len * 0.6),
		Vector3(x_c - depth * 0.14, y_c if car else y_c * 0.94, z_vent),
	])
	var sp := BodyKit.spine(sp_pts, n_st)
	var total_m := 0.0
	for i in range(1, sp.size()):
		total_m += sp[i].distance_to(sp[i - 1])
	var n_frac := clampf((neck_len + hx * 0.38) / maxf(total_m, 1e-6), 0.1, 0.6)
	var neck_r := float(hd.neck) * hw * 0.5
	var top_k := [[0.0, neck_r * 0.9], [n_frac * 0.7, neck_r * 1.05], [n_frac + 0.08, depth * 0.47], [0.55, depth * 0.5], [0.86, depth * 0.4], [1.0, depth * 0.24]]
	var bot_k := [[0.0, neck_r * 0.95], [n_frac * 0.7, neck_r * 1.15], [n_frac + 0.12, depth * 0.52], [0.5, depth * 0.5], [0.85, depth * 0.34], [1.0, depth * 0.2]]
	var side_k := [[0.0, neck_r], [n_frac * 0.7, neck_r * 1.15], [n_frac + 0.1, girth * 0.47], [0.55, girth * 0.5], [0.86, girth * 0.36], [1.0, girth * 0.22]]
	var br_k := [[0.0, 0.0], [n_frac, 0.15], [n_frac + 0.18, 1.0], [0.75, 1.0], [1.0, 0.25]]
	var zone_k := [[0.0, 0.75], [n_frac, 0.75], [n_frac + 0.06, 0.0], [1.0, 0.0]]
	var s_head := hx * 0.6 / L
	var s0 := s_head
	var s1 := (head_len + rest) / L
	var trunk := BodyKit.loft({
		"spine": sp, "up": dorsal, "ring": ring, "top": BodyKit.profile(n_st, top_k), "bot": BodyKit.profile(n_st, bot_k),
		"sr": BodyKit.profile(n_st, side_k), "sl": BodyKit.profile(n_st, side_k), "nt": 2.3, "nb": 2.1,
		"breath": BodyKit.profile(n_st, br_k), "zone": BodyKit.profile(n_st, zone_k), "s0": s0, "s1": s1, "flow": 1.0,
		"cap_start": false, "cap_end": true, "cap_k": 0.7, "ao_under": 0.35, "floor": {} if car else { "y0": 0.0, "band": girth * 0.12 },
	})
	body_surf.append(trunk.arrays)
	lay["trunk"] = trunk
	lay["n_frac"] = n_frac
	# ── los muslos con sus calzones: de dentro del flanco al talón, y un poco más (tapan el principio del tarso) ──
	# (unidad 5t-B, la reacción del animal: en la cetrería, la pata de arriba, la derecha, el ala de arriba, la cola y la
	# mandíbula de abajo van en sus pivotes, en el marco de la raíz y sin moverse en reposo: se ven igual)
	var rig := not car
	# unidad 4u: en el coche, con pose.rig, el ala de arriba, sus primarias y la cola en sus pivotes (el agarre en curva)
	var car_rig := car and bool(pose.get("rig", false))
	var rig_spec := {}
	var strike_leg: Array = []
	var legs: Array = []
	var leg_lofts: Array = []
	for side: String in ["derecha", "izquierda"]:
		var an: Transform3D = anchors.get(side, a_r if side == "derecha" else a_l)
		var heel := an.origin
		var dir := an.basis.x.normalized()
		var up_side := 1.0 if side == "derecha" else -1.0
		var knee := Vector3(belly_x - 0.035 * L, y_c + girth * 0.24 * up_side, heel.z - 0.035 * L)
		var mid := knee.lerp(heel, 0.55) + Vector3(0.0, 0.01 * L, 0.0)
		var l_pts := PackedVector3Array([knee - Vector3(0.03 * L, 0.0, 0.0), knee, mid, heel, heel + dir * 0.016 * L / 0.82])
		var l_sp := BodyKit.spine(l_pts, 12 if mobile else 22)
		var ln := l_sp.size()
		var r_k := [[0.0, 0.05 * L], [0.25, 0.042 * L], [0.75, tarsus_r * 1.9], [0.92, tarsus_r * 1.35], [1.0, tarsus_r * 1.12]]
		var lr := BodyKit.profile(ln, r_k)
		var fur := BodyKit.profile(ln, [[0.0, 1.0], [0.55, 0.9], [0.86, 0.4], [1.0, 0.2]])
		var leg := BodyKit.loft({ "spine": l_sp, "up": Vector3.UP, "ring": ring / 2 + 4, "top": lr, "bot": lr, "sr": lr, "sl": lr,
			"s0": 0.52, "s1": 0.58, "zone": 0.25, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.5, "ao_under": 0.25,
			"fur": fur, "floor": {} if car else { "y0": 0.0, "band": 0.006 } })
		if rig and side == "derecha":
			strike_leg = leg.arrays
			# el muslo de la pata que golpea gira en la rodilla (dentro del flanco) y llega al talón (el anclaje de la pata)
			rig_spec["thigh"] = { "node": "thigh", "pivot": knee, "heel": heel, "paw": side }
		else:
			legs.append(leg.arrays)
		leg_lofts.append(leg)
	parts["Cuerpo"] = { "arrays": BodyKit.merge(body_surf), "mat": "plumage_body", "node": "" }
	# los calzones: un plumón corto en capas (la misma técnica y el mismo color que las plumas del tarso de la pata de la 5h)
	# y encima las plumas largas y blandas del muslo, en filas que bajan hasta pasar el talón y tapan la juntura
	parts["Muslos"] = { "arrays": BodyKit.merge(legs), "mat": "plume_leg", "node": "", "shells": 1, "fur_m": 0.03 * L }
	var strike_cards: Array = []
	if rig:
		parts["MusloGolpe"] = { "arrays": strike_leg, "mat": "plume_leg", "node": "thigh", "shells": 1, "fur_m": 0.03 * L }
		nodes["thigh"] = { "parent": "", "xf": Transform3D.IDENTITY }
	for li in leg_lofts.size():
		_trousers(strike_cards if rig and li == 0 else cards, leg_lofts[li], pl, art, L, rng, mobile)
	# ── las plumas de contorno del tronco y del cuello (y la gorguera del buitre) ──
	_contour(cards, trunk, lay, pl, rng, mobile)
	if String(pl.head) == "buitre":
		_ruff(cards, trunk, lay, pl, rng, mobile)
	# ── el ala plegada de arriba (la derecha) y las puntas de la de abajo ──
	# (5t-B: en la cetrería, el ala de arriba en su pivote, con las primarias en el suyo, y la cola en el suyo)
	var wing_cards: Array = []
	var prim_cards: Array = []
	var tail_cards: Array = []
	if rig or car_rig:
		_wing(wing_cards, trunk, lay, pl, rng, mobile, true, prim_cards)
	else:
		_wing(cards, trunk, lay, pl, rng, mobile, true)
	_wing(cards, trunk, lay, pl, rng, mobile, false)
	# ── la cola ──
	_tail(tail_cards if rig or car_rig else cards, trunk, lay, pl, rng, mobile)
	parts["Plumas"] = { "arrays": BodyKit.cards(cards, -INF if car else 0.0008), "mat": "feather", "node": "" }
	if rig or car_rig:
		parts["Ala"] = { "arrays": BodyKit.cards(wing_cards, 0.0008), "mat": "feather", "node": "wing" }
		parts["AlaPrimarias"] = { "arrays": BodyKit.cards(prim_cards, 0.0008), "mat": "feather", "node": "wing_p" }
		parts["ColaPlumas"] = { "arrays": BodyKit.cards(tail_cards, 0.0008), "mat": "feather", "node": "tail" }
		if rig:
			parts["CalzonGolpe"] = { "arrays": BodyKit.cards(strike_cards, 0.0008), "mat": "feather", "node": "thigh" }
		# el ala gira en el hombro, en el borde del lomo, a lo largo del cuerpo (se levanta del flanco: el «mantling»); las
		# primarias, en el carpo, sobre la normal del flanco (se abren en abanico); la cola, en la rabadilla
		var sh: Array = _wing_point(trunk, lay, 0.12, 1.0, 0.0, true)
		var wr: Array = _wing_point(trunk, lay, 0.02, 0.5, 0.0, true)
		var tb: Array = BodyKit.surface_point(trunk, BodyKit.station_at(trunk, (trunk.arc as PackedFloat32Array)[int(trunk.i1)] * 0.985), 0.02)
		rig_spec["wing"] = { "node": "wing", "pivot": sh[0], "axis": (sh[2] as Vector3).normalized(), "normal": (sh[1] as Vector3).normalized() }
		rig_spec["wing_p"] = { "node": "wing_p", "pivot": wr[0], "axis": (wr[1] as Vector3).normalized(), "along": (wr[2] as Vector3).normalized() }
		rig_spec["tail"] = { "node": "tail", "pivot": tb[0], "axis": (tb[1] as Vector3).normalized(), "along": (tb[2] as Vector3).normalized() }
		nodes["wing"] = { "parent": "", "xf": Transform3D.IDENTITY }
		nodes["wing_p"] = { "parent": "wing", "xf": Transform3D.IDENTITY }
		nodes["tail"] = { "parent": "", "xf": Transform3D.IDENTITY }
	# ── la cabeza (en su marco: x hacia el pico, y hacia arriba, z hacia la derecha) ──
	var head := _head(pl, hd, lay, rng, mobile, rig)
	for k: String in head.parts:
		parts[k] = head.parts[k]
	for k: String in head.nodes:
		nodes[k] = head.nodes[k]
	nodes["head"] = { "parent": "", "xf": head_xf }
	lay["eyes"] = head.eyes
	if rig:
		# en el marco de la cabeza: la mandíbula de abajo gira en la comisura; el cuello entra en la nuca (de donde gira la cabeza)
		rig_spec["jaw"] = head.get("jaw", {})
		rig_spec["neck"] = { "pivot": Vector3(-hx * 0.42, -hh * 0.05, 0.0), "len": hx }
		rig_spec["nict"] = head.get("nict", [])
		lay["rig"] = rig_spec
	elif car_rig:
		lay["rig"] = rig_spec
	var all: Array = []
	for k: String in parts:
		if String((parts[k] as Dictionary).node) == "":
			all.append(parts[k].arrays)
	var box := BodyKit.aabb_of(all)
	box = box.merge(AABB(head_c - Vector3(hx, hx, hx), Vector3(hx, hx, hx) * 2.0))
	return { "parts": parts, "nodes": nodes, "layout": lay, "box": box }


# ─────────────────────────────── las plumas de contorno ───────────────────────────────

## Las coberteras del cuerpo como tejas sobre el tronco y el cuello: filas al tresbolillo a lo largo (apuntando a la cola)
## y alrededor, del tamaño de cada zona (pequeñas en el cuello, grandes en el pecho y en los flancos), con el color de su
## zona y su dibujo; bajo el ala de arriba casi no hay (la tapa).
static func _contour(out: Array, lo: Dictionary, lay: Dictionary, pl: Dictionary, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var total := arc[arc.size() - 1]
	var L := float(lay.L)
	var n_frac := float(lay.n_frac)
	var big := 0.058 * L * (1.4 if mobile else 1.0)
	var small := 0.03 * L * (1.4 if mobile else 1.0)
	var along := 0.0
	var row := 0
	var back := _c(String(pl.back))
	var belly := _c(String(pl.belly))
	var headc := _c(String(pl.c_head))
	var face := int(pl.face)
	while along < total - big * 0.15:
		var u := along / total
		var fl := lerpf(small, big, smoothstep(n_frac * 0.6, n_frac + 0.12, u))
		var fi := BodyKit.station_at(lo, along)
		var p0: Array = BodyKit.surface_point(lo, fi, 0.0)
		var circ := 0.0
		var prev: Vector3 = p0[0]
		for k in range(1, 13):
			var pk: Array = BodyKit.surface_point(lo, fi, float(k) / 12.0)
			circ += (pk[0] as Vector3).distance_to(prev)
			prev = pk[0]
		var n_around := maxi(int(circ / (fl * 0.52)), 6)
		for j in n_around:
			var a := (float(j) + 0.5 * float(row % 2) + (rng.next() - 0.5) * 0.3) / float(n_around)
			a = fposmod(a, 1.0)
			# el ala de arriba (la vuelta 0,62-0,92 del lado derecho) tapa el flanco: ahí, solo el borde
			var under_wing := a > 0.64 and a < 0.9 and u > n_frac + 0.04 and u < 0.97
			if under_wing:
				continue
			var fj := fi + (rng.next() - 0.5) * 0.4
			var sp: Array = BodyKit.surface_point(lo, fj, a)
			var p: Vector3 = sp[0]
			var nn: Vector3 = sp[1]
			var d := minf(a, 1.0 - a) * 2.0
			var col := back.lerp(belly, smoothstep(0.5, 0.75, d))
			if u < n_frac + 0.02:
				var nape := 1.0 - smoothstep(0.25, 0.55, d)
				col = col.lerp(headc, nape * (1.0 if face == 0 else 0.6) * (1.0 - smoothstep(n_frac * 0.5, n_frac + 0.03, u)) + (0.0 if face == 0 else 0.4 * (1.0 - smoothstep(0.0, n_frac, u))))
			col = col * (0.95 + 0.1 * rng.next())
			var pat := 0
			var par := 0.0
			if d > 0.55:
				pat = int(pl.belly_pat)
				par = 3.0
				if pat == 1:
					pat = 6
			# la pluma sigue la piel hacia la cola, algo separada (más en la punta: las de delante montan sobre las de detrás)
			var len := fl * (0.85 + 0.3 * rng.next())
			var f := BodyKit.surface_path(lo, fj, a, 1.0, len, fl * 0.015, fl * 0.07, 3, (rng.next() - 0.5) * 0.02)
			out.append({ "p": p, "nrm": nn, "path": f[0], "path_n": f[1], "len": len, "wid": fl * 0.66, "cup": 0.1,
				"col": col, "kind": 0, "pattern": pat, "param": par, "seed": rng.next(), "breath": 1.0 if u > n_frac else 0.2,
				"shade": 0.94 + 0.06 * rng.next(), "segs": 2, "lat": 1, "smooth": 0.82 })
		along += fl * (0.34 if not mobile else 0.5)
		row += 1


## La gorguera del buitre leonado: un collar de plumas largas, lanceoladas y claras en la base del cuello (el cuello y la
## cabeza, de plumón); el lado que da a la mesa, sin.
static func _ruff(out: Array, lo: Dictionary, lay: Dictionary, pl: Dictionary, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var total := arc[int(lo.i1)]
	var L := float(lay.L)
	var n_frac := float(lay.n_frac)
	var pale := _c(String(pl.c_head)).lerp(_c(String(pl.belly)), 0.35)
	var rows := 3 if mobile else 5
	for r in rows:
		var fi := BodyKit.station_at(lo, total * (n_frac - 0.04 + 0.025 * float(r)))
		var n_around := 10 if mobile else 22
		for j in n_around:
			var a := fposmod((float(j) + 0.5 * float(r % 2) + (rng.next() - 0.5) * 0.4) / float(n_around), 1.0)
			if a > 0.15 and a < 0.4:
				continue
			var fj := fi + (rng.next() - 0.5) * 0.4
			var spt: Array = BodyKit.surface_point(lo, fj, a)
			var fl := L * (0.075 + 0.025 * rng.next()) * (1.3 if mobile else 1.0)
			var f := BodyKit.surface_path(lo, fj, a, 1.0, fl, fl * 0.12, fl * 0.4, 3, (rng.next() - 0.5) * 0.04)
			out.append({ "p": spt[0], "nrm": spt[1], "path": f[0], "path_n": f[1], "len": fl, "wid": fl * 0.28, "cup": 0.1,
				"col": pale * (0.9 + 0.18 * rng.next()), "kind": 5, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.3,
				"shade": 0.95, "segs": 3, "lat": 1, "smooth": 0.6 })


## Las plumas de los calzones: filas de plumas blandas (de contorno y de plumón, con el borde deshilachado) alrededor del
## muslo, que siguen la piel hacia el talón y acaban más cortas sobre el tarso de la pata; del color de las plumas del tarso
## de la 5h (lo claro y lo oscuro mezclados) con el dibujo de la tripa de cada especie.
static func _trousers(out: Array, lo: Dictionary, pl: Dictionary, art: String, L: float, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var i0 := int(lo.i0)
	var i1 := int(lo.i1)
	var plume: Array = (CarePaw.RAPTOR.get(art, CarePaw.RAPTOR.aguila) as Dictionary).plume
	var c_dark := _c(String(plume[0]))
	var c_pale := _c(String(plume[1]))
	var pat := int(pl.belly_pat)
	if pat == 1:
		pat = 6
	var start := arc[i0] + (arc[i1] - arc[i0]) * 0.06
	var stop := arc[i1] - (arc[i1] - arc[i0]) * 0.02
	var along := start
	var row := 0
	while along < stop:
		var f := (along - arc[i0]) / maxf(arc[i1] - arc[i0], 1e-6)
		var fl := L * lerpf(0.055, 0.03, smoothstep(0.3, 1.0, f)) * (1.4 if mobile else 1.0)
		var fi := BodyKit.station_at(lo, along)
		var n_around := 7 if mobile else 12
		for j in n_around:
			var a := fposmod((float(j) + 0.5 * float(row % 2) + (rng.next() - 0.5) * 0.35) / float(n_around), 1.0)
			var fj := fi + (rng.next() - 0.5) * 0.4
			var spt: Array = BodyKit.surface_point(lo, fj, a)
			var len := fl * (0.85 + 0.3 * rng.next())
			var path := BodyKit.surface_path(lo, fj, a, 1.0, len, fl * 0.05, fl * 0.16, 3, (rng.next() - 0.5) * 0.03)
			out.append({ "p": spt[0], "nrm": spt[1], "path": path[0], "path_n": path[1], "len": len, "wid": fl * 0.62, "cup": 0.12,
				"col": c_pale.lerp(c_dark, 0.15 + 0.45 * rng.next()), "kind": 4 if rng.next() < 0.45 else 0, "pattern": pat if rng.next() < 0.7 else 0,
				"param": 3.0, "seed": rng.next(), "breath": 0.0, "shade": 0.9 + 0.1 * rng.next(), "segs": 2, "lat": 1, "smooth": 0.8 })
		along += fl * (0.5 if mobile else 0.3)
		row += 1


# ─────────────────────────────── el ala plegada ───────────────────────────────

## Un punto del ala plegada: u de 0 (el carpo, delante) a 1 (la punta de la primaria más larga), v de 0 (el borde de la
## tripa) a 1 (el del lomo); sobre el flanco de arriba (la vuelta 0,62 → 0,92) o el de abajo (0,38 → 0,08), separado de
## la piel lo que digan las capas (lift, m). Pasado el tronco sigue recto sobre la cola, algo caído.
static func _wing_point(lo: Dictionary, lay: Dictionary, u: float, v: float, lift: float, top: bool) -> Array:
	var arc: PackedFloat32Array = lo.arc
	var i1 := int(lo.i1)
	var body_end := arc[i1]
	var wing := float(lay.wing)
	var start := body_end * (float(lay.n_frac) - 0.04)
	var along := start + u * wing
	var a := lerpf(0.62, 0.9, v) if top else lerpf(0.38, 0.1, v)
	var end_along := body_end * 0.96
	if along <= end_along:
		var sp: Array = BodyKit.surface_point(lo, BodyKit.station_at(lo, along), a)
		return [(sp[0] as Vector3) + (sp[1] as Vector3) * lift, sp[1], sp[2]]
	# pasado el tronco: recto a lo largo de la espina, algo caído hacia la cola y hacia el banco
	var se: Array = BodyKit.surface_point(lo, BodyKit.station_at(lo, end_along), a)
	var pts: PackedVector3Array = lo.pts
	var t := (pts[i1] - pts[i1 - 1]).normalized()
	var nn: Vector3 = se[1]
	var over := along - end_along
	var p: Vector3 = (se[0] as Vector3) + nn * lift + t * over - nn * over * 0.16 + Vector3(0.0, -over * 0.06, 0.0)
	return [p, nn, t]


## El ala plegada en capas, de abajo arriba: las primarias, las secundarias, las terciarias, las coberteras mayores,
## medianas y menores, las escapulares y el álula. top: la de arriba (entera); la de abajo, solo las primarias.
## out_primaries (5t-B): si se da, las primarias van ahí (en su pivote); el orden del azar no cambia.
static func _wing(out: Array, lo: Dictionary, lay: Dictionary, pl: Dictionary, rng: Rng, mobile: bool, top: bool, out_primaries: Variant = null) -> void:
	var prim: Array = out_primaries if out_primaries is Array else out
	var wing := float(lay.wing)
	var remex := _c(String(pl.remex))
	var covert := _c(String(pl.covert))
	var back := _c(String(pl.back))
	var layer := 0.0
	var dz := wing * 0.0013
	var fingers := float(pl.fingers)
	var n_pts := 4 if mobile else 7
	# primarias: de la exterior (abajo del montón) a la interior; las puntas escalonadas
	var tips := [0.9, 1.0, 0.99, 0.95, 0.9, 0.84, 0.78, 0.72, 0.67, 0.62]
	var n_p := 6 if mobile else 10
	for i in n_p:
		var k := float(i) / float(n_p - 1)
		var ti := int(round(k * 9.0))
		var u0 := 0.02 + 0.1 * k
		var v0 := 0.42 + 0.1 * k
		var tip_u := float(tips[ti])
		var f := _feather_path(lo, lay, u0, v0, tip_u, v0 - 0.1 + 0.06 * k, dz * (1.0 + layer), dz * (1.6 + layer), top, n_pts)
		prim.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
			"wid": wing * 0.13, "cup": 0.05, "col": remex * (0.93 + 0.1 * rng.next()), "kind": 2, "pattern": int(pl.remex_pat),
			"param": float(pl.remex_bars) if int(pl.remex_pat) == 1 else fingers, "seed": rng.next(), "breath": 0.6,
			"shade": 0.8 + 0.2 * k, "segs": 6 if not mobile else 3, "lat": 2, "smooth": 0.35 })
		layer += 1.0
	if not top:
		return
	# secundarias: a lo largo del antebrazo, tapan la base de las primarias
	var n_s := 6 if mobile else 12
	for i in n_s:
		var k := float(i) / float(n_s - 1)
		var u0 := 0.02 + 0.3 * k
		var f := _feather_path(lo, lay, u0, 0.52 + 0.18 * k, u0 + 0.56 - 0.06 * k, 0.42 + 0.12 * k, dz * (1.0 + layer), dz * (1.5 + layer), top, n_pts)
		out.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
			"wid": wing * 0.15, "cup": 0.06, "col": remex.lerp(covert, 0.25) * (0.93 + 0.1 * rng.next()), "kind": 2,
			"pattern": int(pl.remex_pat), "param": float(pl.remex_bars) * 0.7 if int(pl.remex_pat) == 1 else 0.0, "seed": rng.next(),
			"breath": 0.6, "shade": 0.86 + 0.14 * k, "segs": 5 if not mobile else 3, "lat": 2, "smooth": 0.4 })
		layer += 0.6
	# terciarias
	for i in 3:
		var u0 := 0.33 + 0.04 * float(i)
		var f := _feather_path(lo, lay, u0, 0.78 + 0.05 * float(i), u0 + 0.46, 0.66, dz * (1.0 + layer), dz * (1.4 + layer), top, n_pts)
		out.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
			"wid": wing * 0.17, "cup": 0.08, "col": covert.lerp(remex, 0.3) * (0.93 + 0.1 * rng.next()), "kind": 1,
			"pattern": int(pl.covert_pat), "param": 2.0, "seed": rng.next(), "breath": 0.6, "shade": 0.95, "segs": 4, "lat": 2, "smooth": 0.5 })
		layer += 0.8
	# coberteras mayores, medianas y menores: filas que tapan la base de las de debajo
	var rows := [[0.28, 0.6, 12, 0.36, 4], [0.17, 0.74, 14, 0.4, 3], [0.1, 0.86, 22, 0.5, 2], [0.07, 0.97, 18, 0.55, 2]]
	if mobile:
		rows = [[0.28, 0.6, 6, 0.36, 3], [0.15, 0.8, 8, 0.45, 2]]
	for rw: Array in rows:
		var fl := float(rw[0]) * wing
		var n := int(rw[2])
		var v_row := float(rw[1])
		for i in n:
			var k := (float(i) + 0.5 * rng.next()) / float(n)
			var u0 := -0.02 + float(rw[3]) * k
			var v0 := v_row + (rng.next() - 0.5) * 0.04
			var f := _feather_path(lo, lay, u0, v0, u0 + fl / wing, v0 - 0.08, dz * (1.0 + layer), dz * (1.3 + layer), top, 3)
			out.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
				"wid": fl * 0.64, "cup": 0.12, "col": covert.lerp(back, 0.3 * rng.next()) * (0.92 + 0.12 * rng.next()),
				"kind": 1, "pattern": int(pl.covert_pat), "param": 2.0, "seed": rng.next(), "breath": 0.6,
				"shade": 0.9 + 0.1 * rng.next(), "segs": int(rw[4]), "lat": 1, "smooth": 0.65 })
		layer += 0.9
	# escapulares: tapan la juntura del ala con el lomo
	var n_sc := 4 if mobile else 9
	for i in n_sc:
		var k := float(i) / float(n_sc - 1)
		var u0 := -0.06 + 0.42 * k
		var v0 := 1.02 + 0.06 * rng.next()
		var f := _feather_path(lo, lay, u0, v0, u0 + 0.3, 0.97, dz * (1.0 + layer), dz * (1.3 + layer), top, 3)
		out.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
			"wid": 0.18 * wing, "cup": 0.12, "col": back * (0.92 + 0.12 * rng.next()), "kind": 1, "pattern": int(pl.covert_pat),
			"param": 2.0, "seed": rng.next(), "breath": 0.8, "shade": 0.95, "segs": 3, "lat": 1, "smooth": 0.65 })
	# el álula
	for i in 3:
		var f := _feather_path(lo, lay, -0.01, 0.55 + 0.04 * float(i), 0.13, 0.5, dz * (1.0 + layer), dz * (1.2 + layer), top, 3)
		out.append({ "p": (f[0] as PackedVector3Array)[0], "nrm": (f[1] as PackedVector3Array)[0], "path": f[0], "path_n": f[1], "len": 0.0,
			"wid": 0.05 * wing, "cup": 0.05, "col": remex, "kind": 2, "pattern": 0, "param": 0.0, "seed": rng.next(),
			"breath": 0.6, "shade": 1.0, "segs": 2, "lat": 1, "smooth": 0.5 })


## El raquis de una pluma del ala plegada que sigue el cuerpo: n puntos de (u0, v0) a (u1, v1), separados de la piel de lift0
## a lift1 (las capas). → [puntos, normales]
static func _feather_path(lo: Dictionary, lay: Dictionary, u0: float, v0: float, u1: float, v1: float, lift0: float, lift1: float, top: bool, n: int) -> Array:
	var path := PackedVector3Array()
	var pn := PackedVector3Array()
	for k in n:
		var t := float(k) / float(maxi(n - 1, 1))
		var w: Array = _wing_point(lo, lay, lerpf(u0, u1, t), lerpf(v0, v1, t), lerpf(lift0, lift1, t), top)
		path.append(w[0])
		pn.append(w[1])
	return [path, pn]


# ─────────────────────────────── la cola ───────────────────────────────

## La cola cerrada: doce timoneras casi paralelas que salen de la rabadilla (las de en medio, encima), algo giradas para
## apoyarse en el banco, con sus coberteras de encima (del color del lomo) y de debajo (claras).
static func _tail(out: Array, lo: Dictionary, lay: Dictionary, pl: Dictionary, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var tail_len := float(lay.tail_len)
	var sp: Array = BodyKit.surface_point(lo, BodyKit.station_at(lo, arc[int(lo.i1)] * 0.985), 0.02)
	var base: Vector3 = sp[0]
	var t: Vector3 = sp[2]
	var axis := (t + Vector3(0.0, -0.06, 0.0)).normalized()
	var nrm := (Vector3(-1.0, 0.0, 0.0) * 0.6 + Vector3(0.0, 1.0, 0.0) * 0.8).normalized()
	nrm = (nrm - axis * nrm.dot(axis)).normalized()
	var side := axis.cross(nrm).normalized()
	var col := _c(String(pl.tail))
	var n := 8 if mobile else 12
	var half := n / 2
	var w := tail_len * 0.24
	var spread := tail_len * 0.11
	# de fuera a dentro: las de fuera, debajo
	for r in half:
		for sgn: float in [-1.0, 1.0]:
			var k := float(half - 1 - r) / float(maxi(half - 1, 1))
			var off := side * sgn * (spread * k + w * 0.12)
			var ax := axis.rotated(nrm, sgn * deg_to_rad(4.0) * k).normalized()
			var lift := float(r) * tail_len * 0.004
			out.append({ "p": base + off + nrm * lift, "axis": ax, "nrm": nrm, "len": tail_len * (0.97 - 0.05 * k), "wid": w,
				"bend": 0.02, "lift": 0.0, "cup": 0.05, "twist": 0.0, "col": col * (0.92 + 0.12 * rng.next()), "kind": 3,
				"pattern": int(pl.tail_pat), "param": float(pl.tail_bars), "seed": rng.next(), "breath": 0.0, "shade": 0.85 + 0.15 * (1.0 - k),
				"segs": 4, "lat": 2 })
	# coberteras de encima y de debajo
	var back := _c(String(pl.back))
	var pale := _c(String(pl.pale))
	for i in (4 if mobile else 8):
		var k := float(i) / 7.0
		var up := i % 2 == 0
		var nn := nrm if up else -nrm
		var p := base - axis * tail_len * 0.08 + side * (k - 0.5) * w * 0.9 + nn * tail_len * 0.03
		out.append({ "p": p, "axis": axis, "nrm": nn, "len": tail_len * (0.36 if up else 0.42), "wid": w * 0.85, "bend": 0.12,
			"lift": 0.05, "cup": 0.12, "twist": (rng.next() - 0.5) * 0.2, "col": (back if up else pale.lerp(_c(String(pl.belly)), 0.4)) * (0.92 + 0.12 * rng.next()),
			"kind": 1, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0, "shade": 0.95, "segs": 3, "lat": 1 })


# ─────────────────────────────── la cabeza ───────────────────────────────

## La cabeza de cada tipo en su marco (x hacia el pico, y hacia arriba, z a la derecha; el origen en el centro del
## cráneo): el cráneo con la ceja, las mejillas y el disco facial de los búhos; el pico de dos piezas con la cera, las
## narinas y la comisura; los ojos y sus párpados (el de abajo cierra, como en las aves); las plumas de la cabeza (la
## nuca dorada del águila real, la doble cresta de la arpía, los penachos del búho real, el borde del disco y la gorguera
## del buitre). → { parts, nodes, eyes }
static func _head(pl: Dictionary, hd: Dictionary, lay: Dictionary, rng: Rng, mobile: bool, rig := false) -> Dictionary:
	var H := float(lay.head_len)
	var sk: Array = hd.skull
	var lx := float(sk[0]) * H
	var ly := float(sk[1]) * H
	var lz := float(sk[2]) * H
	var owl := float(hd.disc) > 0.5
	var ring := 20 if mobile else 36
	var n := 16 if mobile else 30
	var parts := {}
	var nodes := {}
	var bl: Array = hd.bill
	var blen := float(bl[0]) * H
	var bdep := float(bl[1]) * H
	var bwid := float(bl[2]) * H
	var hook := float(bl[3])
	var bx0 := lx * 0.42
	var by0 := -ly * 0.06
	# el cráneo: de la nuca (−x) a la frente (+x); delante acaba con el alto y el ancho de la base del pico (los búhos,
	# con la cara ancha del disco)
	var x_back := -lx * 0.62
	var x_front := lx * 0.52
	var c_pts := PackedVector3Array([Vector3(x_back, -ly * 0.05, 0.0), Vector3(-lx * 0.2, 0.0, 0.0), Vector3(lx * 0.25, ly * 0.02, 0.0), Vector3(x_front, by0 * 0.6, 0.0)])
	var csp := BodyKit.spine(c_pts, n)
	var f_top := bdep * 0.62 if not owl else ly * 0.42
	var f_bot := bdep * 0.55 if not owl else ly * 0.4
	var f_sd := bwid * 0.72 if not owl else lz * 0.42
	var top_k := [[0.0, ly * 0.3], [0.22, ly * 0.49], [0.58, ly * 0.5], [0.86, lerpf(ly * 0.5, f_top, 0.55)], [1.0, f_top]]
	var bot_k := [[0.0, ly * 0.3], [0.28, ly * 0.47], [0.62, ly * 0.45], [0.86, lerpf(ly * 0.45, f_bot, 0.55)], [1.0, f_bot]]
	var sd_k := [[0.0, lz * 0.3], [0.28, lz * 0.5], [0.6, lz * 0.5], [0.86, lerpf(lz * 0.5, f_sd, 0.55)], [1.0, f_sd]]
	var eye: Array = hd.eye
	var er := float(eye[0]) * H
	var ex := float(eye[1]) * H
	var ey := float(eye[2]) * H
	var front := float(eye[3])
	if owl:
		ex = lx * 0.28
		ey = ly * 0.08
	# dónde van los ojos: hundidos en su cuenca (lo que asoma, la córnea), de lado y algo al frente; en los búhos, de frente
	# en el disco
	var u_eye := clampf((ex - x_back) / (x_front - x_back), 0.0, 1.0)
	var half_w := BodyKit.sample(sd_k, u_eye)
	var e_pos := {}
	for s: float in [1.0, -1.0]:
		var ec := Vector3(ex, ey, s * (half_w * 0.97 - er * 0.95))
		if owl:
			ec = Vector3(ex, ey, s * lz * 0.24)
		e_pos[s] = ec
	var bumps: Array = []
	var brow := float(hd.brow)
	for s: float in [-1.0, 1.0]:
		var ec: Vector3 = e_pos[s]
		bumps.append({ "c": ec + Vector3(0.0, 0.0, s * er * 0.9), "r": Vector3(er * 1.2, er * 1.0, er * 0.8), "amt": -er * 0.1 })
		if brow > 0.0:
			# la ceja (el hueso supraorbitario de las rapaces) que vuela sobre el ojo
			bumps.append({ "c": ec + Vector3(-er * 0.05, er * 1.0, s * er * 0.55), "r": Vector3(er * 1.6, er * 0.5, er * 0.8), "amt": er * 0.45 * brow })
		bumps.append({ "c": Vector3(ex - er * 0.8, -ly * 0.22, s * lz * 0.4), "r": Vector3(lx * 0.3, ly * 0.28, lz * 0.2), "amt": lz * 0.04 })
	if owl:
		# el disco facial: la cara plana y algo hundida alrededor de los ojos y del pico
		bumps.append({ "c": Vector3(lx * 0.66, ly * 0.02, 0.0), "r": Vector3(lx * 0.24, ly * 0.4, lz * 0.4), "amt": -lx * 0.16, "dir": Vector3(-1.0, 0.0, 0.0) })
	var skull := BodyKit.loft({ "spine": csp, "up": Vector3.UP, "ring": ring, "top": BodyKit.profile(n, top_k), "bot": BodyKit.profile(n, bot_k),
		"sr": BodyKit.profile(n, sd_k), "sl": BodyKit.profile(n, sd_k), "nt": 2.2, "nb": 2.1, "cap_start": true, "cap_end": true,
		"cap_k": 0.45 if not owl else 0.25, "bumps": bumps, "zone": 0.75, "s0": 0.0, "s1": float(lay.head_len) / float(lay.L),
		"flow": -1.0, "ao_under": 0.2 })
	parts["Cabeza"] = { "arrays": skull.arrays, "mat": "plumage_head", "node": "head" }
	# el pico: la mandíbula de arriba, alta en la base, con el culmen en arco y el gancho que baja; la de abajo, más corta y
	# más estrecha (la de arriba la monta por los lados)
	var up_pts := PackedVector3Array([
		Vector3(bx0 - blen * 0.06, by0 + bdep * 0.06, 0.0), Vector3(bx0 + blen * 0.3, by0 + bdep * 0.02, 0.0),
		Vector3(bx0 + blen * 0.6, by0 - bdep * 0.1 * hook, 0.0), Vector3(bx0 + blen * 0.84, by0 - bdep * 0.4 * hook, 0.0),
		Vector3(bx0 + blen * 0.93, by0 - bdep * 0.78 * hook, 0.0), Vector3(bx0 + blen * 0.9, by0 - bdep * 1.02 * hook, 0.0),
	])
	var nb := 16 if mobile else 30
	var usp := BodyKit.spine(up_pts, nb)
	var u_top := BodyKit.profile(nb, [[0.0, bdep * 0.52], [0.35, bdep * 0.45], [0.65, bdep * 0.33], [0.85, bdep * 0.2], [1.0, bdep * 0.03]])
	var u_bot := BodyKit.profile(nb, [[0.0, bdep * 0.46], [0.35, bdep * 0.36], [0.65, bdep * 0.22], [0.85, bdep * 0.12], [1.0, bdep * 0.02]])
	var u_sd := BodyKit.profile(nb, [[0.0, bwid * 0.5], [0.4, bwid * 0.42], [0.7, bwid * 0.3], [0.9, bwid * 0.15], [1.0, bwid * 0.02]])
	var upper := BodyKit.loft({ "spine": usp, "up": Vector3.UP, "ring": ring / 2 + 8, "top": u_top, "bot": u_bot, "sr": u_sd, "sl": u_sd,
		"nt": 2.4, "nb": 2.8, "cap_start": true, "cap_end": true, "cap_k": 0.25, "zone": 0.0, "flow": 1.0 })
	var lo_pts := PackedVector3Array([Vector3(bx0 - blen * 0.04, by0 - bdep * 0.32, 0.0), Vector3(bx0 + blen * 0.28, by0 - bdep * 0.38, 0.0), Vector3(bx0 + blen * 0.55, by0 - bdep * 0.42, 0.0)])
	var lsp := BodyKit.spine(lo_pts, nb / 2 + 4)
	var nl := lsp.size()
	var l_top := BodyKit.profile(nl, [[0.0, bdep * 0.2], [1.0, bdep * 0.06]])
	var l_bot := BodyKit.profile(nl, [[0.0, bdep * 0.2], [1.0, bdep * 0.05]])
	var l_sd := BodyKit.profile(nl, [[0.0, bwid * 0.36], [1.0, bwid * 0.12]])
	var lower := BodyKit.loft({ "spine": lsp, "up": Vector3.UP, "ring": ring / 2 + 4, "top": l_top, "bot": l_bot, "sr": l_sd, "sl": l_sd,
		"nt": 2.0, "nb": 2.2, "cap_start": true, "cap_end": true, "cap_k": 0.4, "zone": 0.0, "flow": 1.0 })
	var jaw := {}
	if rig:
		# 5t-B: la mandíbula de abajo en su pivote (la comisura), para abrir el pico; la boca, oscura por dentro
		parts["Pico"] = { "arrays": upper.arrays, "mat": "bill", "node": "head" }
		parts["PicoInferior"] = { "arrays": lower.arrays, "mat": "bill", "node": "jaw" }
		nodes["jaw"] = { "parent": "head", "xf": Transform3D.IDENTITY }
		var gape := Vector3(bx0 - blen * 0.06, by0 - bdep * 0.3, 0.0)
		jaw = { "node": "jaw", "pivot": gape, "axis": Vector3(0.0, 0.0, 1.0), "len": blen }
		# el paladar: una lengua de piel oscura entre las dos mandíbulas (se ve al abrir)
		var mouth_pts := PackedVector3Array([gape + Vector3(blen * 0.02, 0.0, 0.0), gape + Vector3(blen * 0.3, -bdep * 0.04, 0.0), gape + Vector3(blen * 0.52, -bdep * 0.1, 0.0)])
		var msp := BodyKit.spine(mouth_pts, 8)
		var mr := BodyKit.profile(msp.size(), [[0.0, bdep * 0.16], [1.0, bdep * 0.05]])
		var mw := BodyKit.profile(msp.size(), [[0.0, bwid * 0.3], [1.0, bwid * 0.1]])
		parts["Boca"] = { "arrays": (BodyKit.loft({ "spine": msp, "up": Vector3.UP, "ring": 12, "top": mr, "bot": mr, "sr": mw, "sl": mw,
			"cap_start": true, "cap_end": true, "cap_k": 0.4, "zone": 0.0, "flow": 1.0 }) as Dictionary).arrays, "mat": "mouth", "node": "head" }
	else:
		parts["Pico"] = { "arrays": BodyKit.merge([upper.arrays, lower.arrays]), "mat": "bill", "node": "head" }
	# la cera (la piel de la base del pico) con las narinas, y la comisura fina que sigue hacia atrás bajo el ojo
	var c_len := blen * (0.26 if not owl else 0.3)
	var ce_pts := PackedVector3Array([Vector3(bx0 - blen * 0.08, by0 + bdep * 0.1, 0.0), Vector3(bx0 + c_len * 0.5, by0 + bdep * 0.07, 0.0), Vector3(bx0 + c_len, by0 + bdep * 0.03, 0.0)])
	var cesp := BodyKit.spine(ce_pts, 10)
	var cn := cesp.size()
	var c_top := BodyKit.profile(cn, [[0.0, bdep * 0.66], [1.0, bdep * 0.54]])
	var c_bot := BodyKit.profile(cn, [[0.0, bdep * 0.26], [1.0, bdep * 0.14]])
	var c_sd := BodyKit.profile(cn, [[0.0, bwid * 0.66], [1.0, bwid * 0.56]])
	var nostril: Array = []
	for s: float in [-1.0, 1.0]:
		nostril.append({ "c": Vector3(bx0 + c_len * 0.6, by0 + bdep * 0.28, s * bwid * 0.48), "r": Vector3(c_len * 0.16, bdep * 0.07, bwid * 0.18), "amt": -bwid * 0.1 })
	var cere := BodyKit.loft({ "spine": cesp, "up": Vector3.UP, "ring": ring / 2 + 4, "top": c_top, "bot": c_bot, "sr": c_sd, "sl": c_sd,
		"nt": 2.4, "nb": 1.6, "cap_start": true, "cap_end": false, "bumps": nostril, "zone": 0.0, "flow": 1.0 })
	var gape: Array = [cere.arrays]
	for s: float in [-1.0, 1.0]:
		var ec: Vector3 = e_pos[s]
		var g_pts := PackedVector3Array([Vector3(bx0 + blen * 0.04, by0 - bdep * 0.34, s * bwid * 0.4), Vector3(bx0 - blen * 0.22, by0 - bdep * 0.36, s * lz * 0.3), Vector3(ec.x - er * 0.4, ec.y - er * 1.25, s * (absf(ec.z) + er * 0.2))])
		var gsp := BodyKit.spine(g_pts, 10)
		var gr := BodyKit.profile(gsp.size(), [[0.0, bdep * 0.045], [1.0, bdep * 0.018]])
		gape.append((BodyKit.loft({ "spine": gsp, "up": Vector3.UP, "ring": 8, "top": gr, "bot": gr, "sr": gr, "sl": gr, "zone": 0.0 }) as Dictionary).arrays)
	parts["Cera"] = { "arrays": BodyKit.merge(gape), "mat": "cere", "node": "head" }
	# los ojos (el globo y sus párpados): cada uno en su nodo, mirando de lado y algo al frente
	var lids: Array = hd.get("lids", [64.0, 66.0, 12.0, 52.0])
	var eyes: Array = []
	var nict: Array = []
	for s: float in [1.0, -1.0]:
		var ec: Vector3 = e_pos[s]
		var gaze := (Vector3(0.0, 0.0, s) * (1.0 - front) + Vector3(1.0, 0.0, 0.0) * front).normalized()
		var eup := (Vector3.UP - gaze * Vector3.UP.dot(gaze)).normalized()
		var exf := Transform3D(Basis(eup.cross(gaze).normalized(), eup, gaze), ec)
		var tag := "d" if s > 0.0 else "i"
		nodes["eye_" + tag] = { "parent": "head", "xf": exf }
		parts["Ojo_" + tag] = { "arrays": BodyKit.ellipsoid(Vector3.ZERO, Vector3.ONE * er, Basis(Vector3.BACK, -PI * 0.5), 18 if mobile else 30, 12 if mobile else 22), "mat": "eye", "node": "eye_" + tag }
		parts["Parpado_" + tag + "_sup"] = { "arrays": BodyKit.eyelid(er * 1.07, true, float(lids[0]), mobile), "mat": "lid", "node": "lid_" + tag + "_sup" }
		parts["Parpado_" + tag + "_inf"] = { "arrays": BodyKit.eyelid(er * 1.07, false, float(lids[1]), mobile), "mat": "lid", "node": "lid_" + tag + "_inf" }
		nodes["lid_" + tag + "_sup"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": float(lids[2]) }
		nodes["lid_" + tag + "_inf"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": float(lids[3]) }
		eyes.append({ "tag": tag, "r": er, "kind": "ave" })
		if rig:
			# 5t-B: la membrana nictitante, una tela translúcida que barre el ojo de delante a atrás; en reposo, recogida detrás
			parts["Nictitante_" + tag] = { "arrays": _nict_cap(er * 1.035, mobile), "mat": "nict", "node": "nict_" + tag }
			# recogida en el rabillo de delante (el +X del marco del ojo derecho mira al pico; el del izquierdo, a la nuca)
			nodes["nict_" + tag] = { "parent": "eye_" + tag, "xf": Transform3D(Basis(Vector3.UP, NICT_HIDE * s), Vector3.ZERO) }
			nict.append({ "node": "nict_" + tag, "side": s })
		# el anillo de piel del ojo (el halcón, amarillo)
		if String(pl.ring) != "":
			var ring_pts := PackedVector3Array()
			for k in 25:
				var ang := float(k) / 24.0 * TAU
				ring_pts.append(exf * (Vector3(cos(ang) * 1.02, sin(ang) * 1.02, 0.42) * er))
			var rr := BodyKit.filled(ring_pts.size(), er * 0.14)
			parts["Anillo_" + tag] = { "arrays": (BodyKit.loft({ "spine": ring_pts, "up": exf.basis.z, "ring": 8, "top": rr, "bot": rr, "sr": rr, "sl": rr, "cap_start": false, "cap_end": false }) as Dictionary).arrays, "mat": "ring", "node": "head" }
	# las plumas de la cabeza (tarjetas): las pequeñas por todo el cráneo y las de cada especie
	var hc: Array = []
	if not mobile:
		_head_cards(hc, skull, pl, hd, Vector3(lx, ly, lz), e_pos, er, bx0 - blen * 0.1, rng)
	_head_feathers(hc, pl, hd, lx, ly, lz, rng, mobile)
	if not hc.is_empty():
		parts["PlumasCabeza"] = { "arrays": BodyKit.cards(hc), "mat": "feather", "node": "head" }
	return { "parts": parts, "nodes": nodes, "eyes": eyes, "jaw": jaw, "nict": nict }


## Lo que gira la membrana nictitante recogida (rad, sobre la vertical del ojo): detrás del globo, dentro de la cabeza.
const NICT_HIDE := 2.2


## La membrana nictitante (5t-B): un casquete de esfera de radio r delante del ojo (+Z), de ±70° de lado y ±58° de alto.
static func _nict_cap(r: float, mobile: bool) -> Array:
	var nu := 10 if mobile else 18
	var nv := 8 if mobile else 14
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for j in nv + 1:
		var ph := deg_to_rad(-58.0 + 116.0 * float(j) / float(nv))
		for i in nu + 1:
			var th := deg_to_rad(-70.0 + 140.0 * float(i) / float(nu))
			var d := Vector3(sin(th) * cos(ph), sin(ph), cos(th) * cos(ph))
			v.append(d * r)
			n.append(d)
			t.append_array([1.0, 0.0, 0.0, 1.0])
			uv.append(Vector2(float(i) / float(nu), float(j) / float(nv)))
			uv2.append(Vector2(0.0, 0.0))
			col.append(Color(1.0, 0.0, 0.0, 0.0))
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + nu + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	return BodyKit.pack(v, n, t, uv, uv2, col, idx)


## Las plumas pequeñas de la cabeza, como tejas por el cráneo (lo: el loft del cráneo, en el marco de la cabeza): apuntan
## hacia la nuca, pequeñas en la cara y más largas en la nuca, con el color del dibujo de la cara de cada especie; no hay
## en las cuencas de los ojos, delante de la cara (la cera y las cerdas) ni en el disco de los búhos.
static func _head_cards(out: Array, lo: Dictionary, pl: Dictionary, hd: Dictionary, half: Vector3, e_pos: Dictionary, er: float, x_face: float, rng: Rng) -> void:
	var arc: PackedFloat32Array = lo.arc
	var total := arc[arc.size() - 1]
	var owl := float(hd.disc) > 0.5
	var face := int(pl.face)
	var lx := half.x
	var along := total * 0.04
	var row := 0
	while along < total * 0.97:
		var u := along / total
		var fl := lerpf(0.22 * lx, 0.075 * lx, smoothstep(0.1, 0.85, u))
		if String(pl.head) == "aguila":
			fl *= lerpf(1.35, 1.0, smoothstep(0.1, 0.5, u))
		var fi := BodyKit.station_at(lo, along)
		var circ := 0.0
		var prev: Vector3 = (BodyKit.surface_point(lo, fi, 0.0) as Array)[0]
		for k in range(1, 13):
			var pk: Vector3 = (BodyKit.surface_point(lo, fi, float(k) / 12.0) as Array)[0]
			circ += pk.distance_to(prev)
			prev = pk
		var n_around := maxi(int(circ / (fl * 0.5)), 6)
		for j in n_around:
			var a := fposmod((float(j) + 0.5 * float(row % 2) + (rng.next() - 0.5) * 0.3) / float(n_around), 1.0)
			var sp: Array = BodyKit.surface_point(lo, fi, a)
			var p: Vector3 = sp[0]
			var nn: Vector3 = sp[1]
			var t: Vector3 = sp[2]
			if p.x > x_face:
				continue
			var near_eye := false
			for s: float in e_pos:
				if p.distance_to(e_pos[s] as Vector3) < er * 1.55:
					near_eye = true
			if near_eye:
				continue
			if owl and p.x > lx * 0.2 and absf(p.y) < half.y * 0.42 and absf(p.z) < half.z * 0.44:
				continue
			var q := Vector3(p.x / (half.x * 0.5), p.y / (half.y * 0.5), p.z / (half.z * 0.5))
			var col := _face_color(face, q, pl) * (0.95 + 0.1 * rng.next())
			var hackle := String(pl.head) == "aguila" and u < 0.4
			var len := fl * (0.85 + 0.3 * rng.next())
			var f := BodyKit.surface_path(lo, fi, a, -1.0, len, fl * 0.02, fl * 0.09, 3, (rng.next() - 0.5) * 0.03)
			out.append({ "p": p, "nrm": nn, "path": f[0], "path_n": f[1], "len": len, "wid": fl * (0.46 if hackle else 0.62), "cup": 0.1,
				"col": col, "kind": 5 if hackle else 0, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0,
				"shade": 0.95 + 0.05 * rng.next(), "segs": 2, "lat": 1, "smooth": 0.8 })
		along += fl * 0.32
		row += 1


## El color de la cara de cada especie en q (el marco de la cabeza, normalizado con su medio tamaño), el mismo dibujo que
## body_plumage.gdshader (face_color), para las tarjetas.
static func _face_color(face: int, q: Vector3, pl: Dictionary) -> Color:
	var back := _c(String(pl.back))
	var headc := _c(String(pl.c_head))
	var mark := _c(String(pl.mark))
	var pale := _c(String(pl.pale))
	var az := absf(q.z)
	match face:
		0:
			var nape := smoothstep(0.15, 0.45, q.y + (0.2 - q.x) * 0.6) * (1.0 - smoothstep(0.55, 0.75, q.x))
			return back.lerp(headc, nape)
		1:
			var c := headc.lerp(headc * 0.62, smoothstep(0.55, 0.85, q.y) * (1.0 - smoothstep(0.1, 0.4, q.x)))
			return c.lerp(pale, 1.0 - smoothstep(-0.55, -0.3, q.y))
		2:
			var hood := smoothstep(-0.05, 0.12, q.y) + (1.0 - smoothstep(-0.25, 0.05, q.x)) * smoothstep(-0.4, -0.2, q.y)
			var malar := (1.0 - smoothstep(0.08, 0.16, absf(q.x - 0.3 + (q.y + 0.1) * 0.25))) * smoothstep(-0.65, -0.45, q.y) * (1.0 if az > 0.35 else 0.0)
			return pale.lerp(mark, clampf(hood + malar, 0.0, 1.0))
		3:
			var disc_r := Vector2((q.x - 0.45) * 1.1, q.y * 0.95).length()
			var disc := (1.0 - smoothstep(0.62, 0.7, disc_r)) * (1.0 if q.x > 0.0 else 0.0)
			var c := back.lerp(headc, disc)
			return c.lerp(mark, (1.0 - smoothstep(0.03, 0.08, absf(disc_r - 0.68))) * (1.0 if q.x > 0.15 else 0.0) * 0.9)
		4:
			var heart := Vector2((q.x - 0.5) * 1.15, q.y * 0.9 + 0.08 - az * 0.15).length()
			var disc := (1.0 - smoothstep(0.6, 0.66, heart)) * (1.0 if q.x > 0.05 else 0.0)
			var c := back.lerp(pale, disc)
			return c.lerp(headc, (1.0 - smoothstep(0.02, 0.06, absf(heart - 0.64))) * (1.0 if q.x > 0.1 else 0.0))
		5:
			return pale.lerp(headc, 0.35)
	return back


## Las plumas de la cabeza: la nuca y la coronilla con plumas pequeñas (doradas y lanceoladas en el águila real), la
## doble cresta de la arpía, los penachos del búho real, el borde del disco facial de los búhos y las cerdas sobre el pico.
static func _head_feathers(out: Array, pl: Dictionary, hd: Dictionary, lx: float, ly: float, lz: float, rng: Rng, mobile: bool) -> void:
	var headc := _c(String(pl.c_head))
	var back := _c(String(pl.back))
	var mark := _c(String(pl.mark))
	var pale := _c(String(pl.pale))
	var owl := float(hd.disc) > 0.5
	var htype := String(pl.head)
	# la nuca: plumas que apuntan hacia atrás (−x)
	var n_nape := 0 if mobile else (26 if htype == "aguila" else 14)
	for i in n_nape:
		var a := (float(i) / float(maxi(n_nape - 1, 1))) * PI * 0.9 - PI * 0.45
		var p := Vector3(-lx * (0.15 + 0.3 * rng.next()), ly * 0.5 * cos(a) * 0.95, lz * 0.5 * sin(a) * 0.95)
		var nn := Vector3(0.0, cos(a), sin(a)).normalized()
		var fl := lx * (0.42 if htype == "aguila" else 0.3)
		out.append({ "p": p, "axis": Vector3(-1.0, -0.1, 0.0), "nrm": nn, "len": fl * (0.8 + 0.4 * rng.next()), "wid": fl * (0.3 if htype == "aguila" else 0.55),
			"bend": 0.3, "lift": 0.2, "cup": 0.1, "twist": 0.0, "col": (headc if htype in ["aguila", "arpia"] else back) * (0.9 + 0.2 * rng.next()),
			"kind": 5 if htype == "aguila" else 0, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0, "shade": 0.95, "segs": 2, "lat": 1 })
	if htype == "arpia":
		# la doble cresta: dos abanicos de plumas largas grises en la coronilla
		for s: float in [-1.0, 1.0]:
			for i in (3 if mobile else 6):
				var p := Vector3(-lx * 0.1 - lx * 0.06 * float(i), ly * 0.45, s * lz * 0.16)
				out.append({ "p": p, "axis": Vector3(-1.0, 0.55, s * 0.25).normalized(), "nrm": Vector3(0.0, 0.4, s).normalized(),
					"len": lx * (0.75 - 0.06 * float(i)), "wid": lx * 0.16, "bend": -0.15, "lift": 0.3, "cup": 0.08, "twist": 0.0,
					"col": headc * (0.6 + 0.15 * rng.next()), "kind": 5, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0,
					"shade": 1.0, "segs": 3, "lat": 1 })
	if htype == "buho":
		# los penachos: dos mechones de plumas oscuras levantados sobre los ojos
		for s: float in [-1.0, 1.0]:
			for i in (4 if mobile else 7):
				var p := Vector3(lx * 0.16 - lx * 0.045 * float(i), ly * 0.42, s * lz * (0.28 + 0.025 * float(i)))
				out.append({ "p": p, "axis": Vector3(-0.35 - 0.05 * float(i), 1.0, s * (0.3 + 0.04 * float(i))).normalized(), "nrm": Vector3(1.0, 0.2, s * 0.3).normalized(),
					"len": ly * (0.52 - 0.035 * float(i)), "wid": ly * 0.24, "bend": -0.25, "lift": 0.0, "cup": 0.12, "twist": s * 0.15,
					"col": mark.lerp(headc, 0.35 + 0.3 * rng.next()), "kind": 5, "pattern": 2, "param": 0.0, "seed": rng.next(), "breath": 0.0,
					"shade": 1.0, "segs": 3, "lat": 1 })
	if owl:
		# el borde del disco: una gorguera de plumas cortas y rizadas alrededor de la cara
		var n_rim := 14 if mobile else 30
		for i in n_rim:
			var a := float(i) / float(n_rim) * TAU
			var p := Vector3(lx * 0.42, ly * 0.4 * sin(a), lz * 0.42 * cos(a))
			var nn := Vector3(0.35, sin(a), cos(a)).normalized()
			out.append({ "p": p, "axis": Vector3(1.0, sin(a) * 0.4, cos(a) * 0.4).normalized(), "nrm": nn, "len": lx * 0.2, "wid": lx * 0.12,
				"bend": -0.3, "lift": 0.4, "cup": 0.1, "twist": 0.0, "col": (mark if htype == "buho" else headc) * (0.9 + 0.2 * rng.next()),
				"kind": 0, "pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0, "shade": 1.0, "segs": 2, "lat": 1 })
	# las cerdas sobre la base del pico (búhos y rapaces): finas, hacia delante
	if not mobile:
		for i in 8:
			var a := (float(i) / 7.0 - 0.5) * 1.2
			var p := Vector3(lx * 0.4, -ly * 0.02 + ly * 0.12 * cos(a), lz * 0.18 * sin(a))
			out.append({ "p": p, "axis": Vector3(1.0, 0.1, sin(a) * 0.3).normalized(), "nrm": Vector3(0.3, cos(a), sin(a)).normalized(),
				"len": lx * 0.16, "wid": lx * 0.03, "bend": 0.1, "lift": 0.15, "cup": 0.0, "twist": 0.0,
				"col": (pale if owl else mark) * (0.9 + 0.2 * rng.next()), "kind": 5, "pattern": 0, "param": 0.0, "seed": rng.next(),
				"breath": 0.0, "shade": 1.0, "segs": 2, "lat": 1 })
