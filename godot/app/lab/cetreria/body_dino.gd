## Cetrería · los dos velocirraptores en alta definición (unidad 5i, petición 37), hechos en código desde cero e
## independientes de los modelos del coche en marcha. Solo dibujo; el tamaño es el de su ficha (core/lab/care_anatomy.gd,
## que la lee de core/lab/velociraptor.gd y velociraptor_film.gd: el largo y los huesos de la pata de IGM 100/986, el fémur
## de 238 mm y la tibia de 255 mm de Norell y Makovicky 1999); las proporciones del cráneo, del cuello, del tronco y de la
## cola y todo el dibujo son de dibujo.
##   - La reconstrucción (Velociraptor mongoliensis), con plumas (las papilas de las secundarias en el cúbito, Turner et al.
##     2007): el cuerpo cubierto de plumas sencillas en capas (body_fur.gdshader: mechones que se juntan en punta, con
##     bandas difusas que se marcan en la cola), las alas de los brazos con sus rémiges y sus coberteras, el abanico de la
##     cola, plumas de contorno en el cuello y el lomo; escamas en el hocico (y en el pie, el de la 5h), labios escamosos
##     que tapan los dientes, ojos ámbar de pupila redonda. Desde la 5n, la cabeza es la del cráneo medido de GIN 100/25
##     (Barsbold y Osmólska 1999: largo y bajo, con el hocico estrecho y cóncavo y la punta algo levantada, la órbita grande
##     y la narina en su hoyo) con los labios que tapan los dientes (Cullen et al. 2023) y las plumas de la cabeza, cortas
##     (_head_recon).
##   - El de película (ficción, con el tamaño de Deinonychus): solo escamas, con las rayas del lomo, los dientes a la
##     vista sobre la mandíbula, la pupila en rendija y las manos de tres dedos con sus garras.
## Tumbado de lado como los demás (el lomo hacia −X, la cabeza hacia −Z, el lado derecho arriba), con las patas plegadas:
## el muslo y la tibia van de la cadera al talón de la pata de la 5h (su anclaje) con los largos medidos (resueltos como una
## pierna de dos huesos, con la rodilla hacia delante) y la tibia sigue por encima del metatarso de la pata (sin juntura).
## model() es puro (arrays y transformaciones): se puede llamar desde un hilo; su resultado va a la caché.
extends RefCounted

const BodyKit = preload("res://app/lab/cetreria/body_kit.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const Rng = preload("res://core/shared/rng.gd")

const MM := 0.001
## La forma de cada uno (dibujo; fracciones del largo total L): el cráneo, el cuello y el tronco (del hombro a la cadera; la
## cola es lo que queda, la mitad larga del animal), lo hondo y lo ancho del tronco, el grosor del cuello y de la raíz de la
## cola; el medio alto y el medio ancho de la cabeza (fracciones de su largo), lo cóncavo del hocico (el de Velociraptor,
## largo, bajo y algo levantado en la punta; el de película, más alto y recto) y el radio del ojo (m, para 2,07 m).
const SHAPE := {
	"velociraptor": { "head": 0.11, "neck": 0.13, "trunk": 0.23, "depth": 0.11, "width": 0.07, "neck_r": 0.021, "tail_r": 0.032,
		"hh": 0.17, "hw": 0.14, "dish": 1.0, "eye_r": 0.011,
		"top": [[0.0, 0.75], [0.15, 1.0], [0.33, 0.98], [0.5, 0.74], [0.7, 0.44], [0.88, 0.4], [1.0, 0.26]],
		"bot": [[0.0, 0.85], [0.18, 1.0], [0.4, 0.82], [0.65, 0.58], [0.88, 0.4], [1.0, 0.24]],
		"side": [[0.0, 0.85], [0.2, 1.0], [0.38, 0.96], [0.55, 0.7], [0.75, 0.52], [0.9, 0.44], [1.0, 0.3]] },
	"velociraptor_pelicula": { "head": 0.12, "neck": 0.12, "trunk": 0.24, "depth": 0.12, "width": 0.08, "neck_r": 0.025, "tail_r": 0.034,
		"hh": 0.21, "hw": 0.17, "dish": 0.2, "eye_r": 0.0105,
		"top": [[0.0, 0.78], [0.15, 1.0], [0.35, 0.98], [0.55, 0.84], [0.75, 0.72], [0.9, 0.64], [1.0, 0.5]],
		"bot": [[0.0, 0.88], [0.2, 1.0], [0.45, 0.88], [0.7, 0.72], [0.9, 0.6], [1.0, 0.46]],
		"side": [[0.0, 0.85], [0.2, 1.0], [0.4, 0.95], [0.6, 0.76], [0.8, 0.64], [0.92, 0.58], [1.0, 0.42]] },
}
## Los colores: la piel de escamas [clara, oscura] (las del pie de la 5h), las plumas [lomo, punta clara, oscuro, tripa], el
## ojo [iris, oscuro]; en el de película, las rayas, la tripa, los dientes [esmalte, raíz] y la encía.
const LOOK := {
	"velociraptor": { "skin": ["#6E5C46", "#33281E"], "face": ["#5A4834", "#261C14"], "feather": ["#4E3C2C", "#9C7C5C", "#21170F", "#C9B48E"],
		"iris": ["#C88A2A", "#5A3510"], "claw": ["#3A3026", "#141009"] },
	"velociraptor_pelicula": { "skin": ["#7A7656", "#363224"], "face": ["#7A7656", "#363224"], "stripe": "#3A3424", "belly": "#A49C78", "iris": ["#C9A23A", "#3E300C"],
		"teeth": ["#E8DFC6", "#A8966E"], "gum": "#5A2C2A", "claw": ["#2E2A22", "#0E0C09"] },
}


static func _c(hex: String) -> Color:
	return Color(hex)


## Los materiales de un velocirraptor: { id: { shader, params, shell? } } (care_body.gd los hace una vez por dibujo y calidad).
static func materials(art: String, mobile: bool) -> Dictionary:
	var film := art == "velociraptor_pelicula"
	var lk: Dictionary = LOOK.get(art, LOOK.velociraptor)
	var k := CareAnatomy.value(art, "length_m", 2.07) / 2.07
	var detail := 0.0 if mobile else 1.0
	var skin: Array = lk.skin
	var iris: Array = lk.iris
	var claw: Array = lk.claw
	var out := {
		"eye": { "shader": "eye", "params": { "iris_color": _c(String(iris[0])), "iris_dark": _c(String(iris[1])), "sclera_color": _c(String(iris[1])).darkened(0.2),
			"iris_r": 0.74, "pupil_r": 0.36 if not film else 0.42, "slit": 1.0 if film else 0.0 } },
		"lid": { "shader": "skin", "params": { "mode": 6, "color_a": _c(String(skin[0])), "color_b": _c(String(skin[1])).darkened(0.3), "rough": 0.6,
			"spec": 0.3, "rim_mm": 1.6 * k, "relief_mm": 0.05 } },
		"claw": { "shader": "skin", "params": { "mode": 0, "color_a": _c(String(claw[0])), "color_b": _c(String(claw[1])), "rough": 0.42, "spec": 0.4,
			"tip_from": 0.4, "len_mm": 30.0 * k, "relief_mm": 0.06, "detail": detail } },
		"scales_head": { "shader": "skin", "params": { "mode": 2, "color_a": _c(String((lk.face as Array)[0])), "color_b": _c(String((lk.face as Array)[1])), "scale_mm": 2.4 * k * (1.25 if film else 1.0),
			"relief_mm": 0.35 * k, "rough": 0.55, "spec": 0.28, "breath_mm": 0.0, "detail": detail } },
	}
	if film:
		out["skin_body"] = { "shader": "skin", "params": { "mode": 2, "color_a": _c(String(skin[0])), "color_b": _c(String(skin[1])),
			"stripe_color": _c(String(lk.stripe)), "stripes": 1.0, "stripe_n": 26.0, "scale_mm": 5.0 * k / 1.64, "relief_mm": 0.8, "rough": 0.6,
			"spec": 0.25, "breath_mm": 8.0 * k, "detail": detail } }
		out["teeth"] = { "shader": "skin", "params": { "mode": 0, "color_a": _c(String((lk.teeth as Array)[0])), "color_b": _c(String((lk.teeth as Array)[1])),
			"rough": 0.32, "spec": 0.5, "tip_from": 2.0, "len_mm": 20.0, "relief_mm": 0.02, "detail": detail } }
		out["gum"] = { "shader": "skin", "params": { "mode": 5, "color_a": _c(String(lk.gum)).darkened(0.35), "color_b": _c(String(lk.gum)).darkened(0.6), "rough": 0.35,
			"spec": 0.45, "relief_mm": 0.05, "detail": detail } }
	else:
		var fe: Array = lk.feather
		out["plume_body"] = { "shader": "fur", "params": { "root_color": _c(String(fe[0])).darkened(0.35), "tip_color": _c(String(fe[1])),
			"belly_color": _c(String(fe[3])), "dark_color": _c(String(fe[2])), "belly": 0.85, "fur_mm": 22.0 * k, "strand_mm": 0.5, "clump_mm": 4.5,
			"clump": 0.88, "thick": 1.15, "comb": 1.0, "droop": 0.12, "pattern": 5, "stripe_n": 22.0, "tail_from": 0.5, "tone_var": 0.16,
			"breath_mm": 6.0 * k, "rough": 0.82, "spec": 0.22 } }
		out["plume_head"] = { "shader": "fur", "params": { "root_color": _c(String(fe[0])).darkened(0.3), "tip_color": _c(String(fe[1])),
			"belly_color": _c(String(fe[3])), "dark_color": _c(String(fe[2])), "belly": 0.7, "fur_mm": 8.0 * k, "strand_mm": 0.35, "clump_mm": 2.6,
			"clump": 0.8, "thick": 1.0, "comb": 1.0, "droop": 0.1, "pattern": 0, "tone_var": 0.14, "breath_mm": 0.0, "rough": 0.82, "spec": 0.22 } }
		out["feather"] = { "shader": "feather", "params": { "bar_color": _c(String(fe[2])), "edge_color": _c(String(fe[1])),
			"down_color": _c(String(fe[3])), "shaft_color": _c(String(fe[1])), "barb_mm": 0.5 * k, "breath_mm": 6.0 * k } }
		out["lips"] = { "shader": "skin", "params": { "mode": 5, "color_a": _c(String(skin[0])).darkened(0.3), "color_b": _c(String(skin[1])), "rough": 0.45,
			"spec": 0.3, "relief_mm": 0.05, "detail": detail } }
	return out


## El modelo de un velocirraptor. anchors: { «derecha», «izquierda»: Transform3D en la raíz (el talón de la pata de la 5h) };
## claw: la garra del motor (da el grosor del metatarso de la pata); mobile: menos detalle. pose (unidad 4r: el coche en
## marcha; vacío en la cetrería, que lo dibuja como siempre): agazapado, no tumbado (lo coloca app/lab/animals/hd3d.gd con
## los pies en el suelo): hip_m (m, la cadera sobre el talón más alto; las patas, menos plegadas) o lift (m, lo que se
## aparta el tronco de los talones hacia el lomo), head_pitch (cuánto mira la cabeza hacia las patas; 0, al frente), sin la
## mesa que lo aplasta, con el tronco entre las dos patas y la cabeza, el cuello y la cola en su eje. → { parts, nodes,
## layout, box }
static func model(art: String, anchors: Dictionary, claw: Dictionary, mobile: bool, pose := {}) -> Dictionary:
	var car := not pose.is_empty()
	var film := art == "velociraptor_pelicula"
	var sh: Dictionary = SHAPE.get(art, SHAPE.velociraptor)
	var lk: Dictionary = LOOK.get(art, LOOK.velociraptor)
	var rng := Rng.new(Rng.seed_of("cuerpo|" + art))
	var L := CareAnatomy.value(art, "length_m", 2.07)
	var k := L / 2.07
	# los huesos medidos de la pata de la reconstrucción; el de película, a escala con su largo (dibujo)
	var femur := CareAnatomy.value("velociraptor", "femur_mm", 238.0) * MM * k
	var tibia := CareAnatomy.value("velociraptor", "tibia_mm", 255.0) * MM * k
	var s_paw := float(claw.get("base_r_mm", CarePaw.DINO_BASE_REF)) / CarePaw.DINO_BASE_REF
	var meta_r := 19.0 * MM * s_paw
	var meta_len := 106.0 * MM * s_paw
	var heel_r: Transform3D = anchors.get("derecha", Transform3D(Basis.IDENTITY, Vector3(-0.1 * k, 0.03 * k, -0.08 * k)))
	var heel_l: Transform3D = anchors.get("izquierda", Transform3D(Basis.IDENTITY, Vector3(-0.08 * k, 0.03 * k, 0.1 * k)))
	var ax := minf(heel_r.origin.x, heel_l.origin.x)
	var az := (heel_r.origin.z + heel_l.origin.z) * 0.5
	# la reconstrucción, con el cráneo medido de GIN 100/25 y su piel (5n); el de película, de dibujo
	var head_len := float(sh.head) * L if film else CareAnatomy.value(art, "skull_m", 0.23) * float(CareAnatomy.head_draw("velociraptor", "skin_k", 1.03))
	var neck_len := float(sh.neck) * L
	var trunk_len := float(sh.trunk) * L
	var tail_len := L - head_len - neck_len - trunk_len
	var depth := float(sh.depth) * L
	var width := float(sh.width) * L
	var neck_r := float(sh.neck_r) * L
	var tail_r := float(sh.tail_r) * L
	# en el coche (pose.hip_m), la cadera a hip_m del talón más alto (la cadera va a 0,45 de lo hondo del tronco por encima de la
	# tripa)
	var lift := float(pose.hip_m) - femur * 0.5 - depth * 0.45 if pose.has("hip_m") else float(pose.get("lift", 0.0))
	var x_v := ax - femur * 0.5 - lift
	var x_c := x_v - depth * 0.5
	var y_c := (heel_r.origin.y + heel_l.origin.y) * 0.5 if car else width * 0.5 * 0.92
	var z_hip := az - 0.03 * k
	var z_sh := z_hip - trunk_len
	var ring := 24 if mobile else 44
	var parts := {}
	var nodes := {}
	# ── la cabeza, primero (en su marco: x hacia el hocico, y arriba, z a la derecha), apoyada en la mesa ──
	var hh := float(sh.hh) * head_len
	var hw := float(sh.hw) * head_len
	var head: Dictionary
	if film:
		head = _head(art, sh, head_len, hh, hw, k, rng, mobile)
	else:
		head = _head_recon(art, head_len, mobile)
		hh = float(head.hh)
		hw = float(head.hw)
	var fwd := Vector3(float(pose.get("head_pitch", 0.1)), 0.0, -1.0).normalized() if car else Vector3(0.1, -0.03, -1.0).normalized()
	var dorsal := (Vector3(-1.0, 0.0, 0.0) - fwd * Vector3(-1.0, 0.0, 0.0).dot(fwd)).normalized()
	var right := fwd.cross(dorsal).normalized()
	var hbasis := Basis(fwd, dorsal, right)
	var head_c := Vector3(x_c - depth * 0.3, 0.0, z_sh - neck_len - head_len * 0.5)
	var low := INF
	for p: Vector3 in (head.grid as PackedVector3Array):
		low = minf(low, (hbasis * p).y)
	head_c.y = y_c if car else -low - 0.002
	var head_xf := Transform3D(hbasis, head_c)
	# ── el cuello, el tronco y la cola: un solo cuerpo de dentro de la cabeza a la punta de la cola, la cola en la mesa ──
	var n_st := 40 if mobile else 110
	var neck0 := head_xf * Vector3(-head_len * 0.25, -hh * 0.1, 0.0)
	var y_n := y_c if car else maxf(head_c.y, neck_r * 1.05)
	var sp_pts := PackedVector3Array([
		neck0,
		Vector3(x_c - depth * 0.5, y_n if car else y_n * 1.05, z_sh - neck_len * 0.55),
		Vector3(x_c - depth * 0.22, y_c if car else y_c * 0.96, z_sh - neck_len * 0.08),
		Vector3(x_c, y_c, z_sh + trunk_len * 0.35),
		Vector3(x_c - depth * 0.05, y_c, z_hip),
		Vector3(x_c - depth * 0.12, y_c if car else _tail_r(tail_r, 0.3) * 0.95, z_hip + tail_len * 0.3),
		Vector3(x_c - depth * 0.1, y_c if car else _tail_r(tail_r, 0.65) * 0.95, z_hip + tail_len * 0.65),
		Vector3(x_c - depth * 0.04, y_c if car else _tail_r(tail_r, 0.98) * 0.95, z_hip + tail_len * 0.99),
	])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, sp_pts.size()):
		cum.append(cum[i - 1] + sp_pts[i].distance_to(sp_pts[i - 1]))
	var tot := cum[cum.size() - 1]
	var u_sh := cum[2] / tot
	var u_hip := cum[4] / tot
	var u_out := clampf(head_len * 0.27 / tot, 0.005, 0.08)
	var u_nm := (cum[1]) / tot
	var ut := func(f: float) -> float: return lerpf(u_hip, 1.0, f)
	var sp := BodyKit.spine(sp_pts, n_st)
	var top_k := [[0.0, hh * 0.45], [u_out, neck_r * 0.92], [u_nm, neck_r * 0.98], [u_sh - 0.04, neck_r * 1.35], [u_sh + 0.01, depth * 0.38],
		[lerpf(u_sh, u_hip, 0.5), depth * 0.42], [u_hip, depth * 0.38], [ut.call(0.08), tail_r * 1.08], [ut.call(0.4), _tail_r(tail_r, 0.4)],
		[ut.call(0.75), _tail_r(tail_r, 0.75)], [1.0, _tail_r(tail_r, 1.0)]]
	var bot_k := [[0.0, hh * 0.5], [u_out, neck_r * 1.0], [u_nm, neck_r * 1.05], [u_sh - 0.04, neck_r * 1.5], [u_sh + 0.03, depth * 0.55],
		[lerpf(u_sh, u_hip, 0.45), depth * 0.6], [u_hip - 0.03, depth * 0.45], [ut.call(0.06), tail_r * 1.18], [ut.call(0.4), _tail_r(tail_r, 0.4) * 1.05],
		[ut.call(0.75), _tail_r(tail_r, 0.75)], [1.0, _tail_r(tail_r, 1.0)]]
	var side_k := [[0.0, hw * 0.5], [u_out, neck_r * 0.88], [u_nm, neck_r * 0.92], [u_sh - 0.04, neck_r * 1.3], [u_sh + 0.02, width * 0.45],
		[lerpf(u_sh, u_hip, 0.5), width * 0.5], [u_hip, width * 0.48], [ut.call(0.08), tail_r * 0.92], [ut.call(0.4), _tail_r(tail_r, 0.4) * 0.9],
		[ut.call(0.75), _tail_r(tail_r, 0.75) * 0.9], [1.0, _tail_r(tail_r, 1.0)]]
	var br_k := [[0.0, 0.0], [u_sh, 0.4], [lerpf(u_sh, u_hip, 0.4), 1.0], [lerpf(u_sh, u_hip, 0.8), 0.9], [u_hip + 0.03, 0.2], [ut.call(0.15), 0.0], [1.0, 0.0]]
	var zone_k := [[0.0, 0.75], [u_sh * 0.8, 0.75], [u_sh, 0.0], [u_hip, 0.0], [ut.call(0.05), 0.5], [1.0, 0.5]]
	# las plumas: largas en el cuerpo, más cortas en el cuello y hacia la punta de la cola (allí manda el abanico)
	var fur_k := [[0.0, 0.0], [u_out, 0.35], [u_sh, 0.7], [lerpf(u_sh, u_hip, 0.5), 1.0], [u_hip, 0.9], [ut.call(0.5), 0.5], [1.0, 0.25]]
	var bumps: Array = []
	# la paletilla, la cadera (el ilion) y el muslo que abulta en el costado de arriba; la tripa
	bumps.append({ "c": Vector3(x_c - depth * 0.3, y_c + width * 0.4, z_sh + 0.03 * k), "r": Vector3(depth * 0.22, width * 0.2, 0.08 * k), "amt": 0.008 * k })
	bumps.append({ "c": Vector3(x_c - depth * 0.28, y_c + width * 0.42, z_hip - 0.02 * k), "r": Vector3(depth * 0.25, width * 0.2, 0.1 * k), "amt": 0.012 * k })
	bumps.append({ "c": Vector3(x_v, y_c, lerpf(z_sh, z_hip, 0.55)), "r": Vector3(0.05 * k, width * 0.45, 0.12 * k), "amt": 0.01 * k, "dir": Vector3(1.0, -0.3, 0.0) })
	var body := BodyKit.loft({
		"spine": sp, "up": dorsal, "ring": ring, "top": BodyKit.profile(n_st, top_k), "bot": BodyKit.profile(n_st, bot_k),
		"sr": BodyKit.profile(n_st, side_k), "sl": BodyKit.profile(n_st, side_k), "nt": 2.2, "nb": 2.0,
		"breath": BodyKit.profile(n_st, br_k), "zone": BodyKit.profile(n_st, zone_k), "fur": BodyKit.profile(n_st, [[0.0, 0.0], [1.0, 0.0]] if film else fur_k),
		"s0": head_len * 0.75 / L, "s1": 1.0, "flow": 1.0, "cap_start": false, "cap_end": true, "cap_k": 1.2, "ao_under": 0.22,
		"bumps": bumps, "floor": {} if car else { "y0": 0.0, "band": width * 0.12 },
	})
	var lay := { "L": L, "x_c": x_c, "y_c": y_c, "z_sh": z_sh, "z_hip": z_hip, "trunk": body, "u_sh": u_sh, "u_hip": u_hip, "depth": depth,
		"width": width, "head_xf": head_xf, "head_len": head_len, "head_size": Vector3(head_len, hh * 2.0, hw * 2.0) }
	# ── las patas plegadas: de la cadera (dentro del tronco) a la rodilla y al talón, y la tibia sobre el metatarso ──
	# (unidad 5t-B: en la cetrería, la pata de arriba, la derecha, en su pivote de la cadera, y su manga sobre el metatarso,
	# partida en el talón con un solape, sigue a la pata)
	var rig := not car
	var rig_spec := {}
	var strike_leg: Array = []
	var legs: Array = []
	for e: Array in [[heel_r, 1.0], [heel_l, -1.0]]:
		var an: Transform3D = e[0]
		var up_side := float(e[1])
		var hip := Vector3(x_c + depth * 0.05, y_c + width * 0.16 * up_side, z_hip - 0.02 * k)
		var knee := _knee(hip, an.origin, femur, tibia, Vector3(1.0, 0.0, -0.7).normalized())
		if rig and up_side > 0.0:
			strike_leg = _leg(hip, knee, an, k, meta_r, meta_len * 0.4, mobile, ring / 2 + 6, not car, true)
			rig_spec["thigh"] = { "node": "thigh", "pivot": hip, "heel": an.origin, "paw": "derecha" }
			rig_spec["forearm"] = { "node": "forearm", "paw": "derecha" }
			continue
		legs.append(_leg(hip, knee, an, k, meta_r, meta_len * 0.4, mobile, ring / 2 + 6, not car))
	# ── los brazos plegados sobre el pecho (el de arriba se ve; el de abajo, entre el cuerpo y la mesa) ──
	var arms: Array = []
	var hands: Array = []
	var arm_info := {}
	for s: float in [1.0, -1.0]:
		var ai := _arm(body, s, u_sh, tot, k, mobile)
		arms.append(ai.arrays)
		arm_info[s] = ai
		if film:
			hands.append_array(_hand(ai, k, mobile))
	var body_mat := "skin_body" if film else "plume_body"
	if film:
		parts["Cuerpo"] = { "arrays": BodyKit.merge([body.arrays] + legs + arms), "mat": body_mat, "node": "" }
		parts["Manos"] = { "arrays": BodyKit.merge(hands), "mat": body_mat, "node": "" }
	else:
		parts["Cuerpo"] = { "arrays": BodyKit.merge([body.arrays] + legs + arms), "mat": body_mat, "node": "", "shells": 1, "fur_m": 0.03 * k }
	if rig and not strike_leg.is_empty():
		for pi in 2:
			var pe := { "arrays": strike_leg[pi], "mat": body_mat, "node": "thigh" if pi == 0 else "forearm" }
			if not film:
				pe["shells"] = 1
				pe["fur_m"] = 0.03 * k
			parts["PiernaGolpe" if pi == 0 else "MangaGolpe"] = pe
		nodes["thigh"] = { "parent": "", "xf": Transform3D.IDENTITY }
		nodes["forearm"] = { "parent": "", "xf": Transform3D.IDENTITY }
	# las garras de las manos: las del de película, al final de sus dedos; las de la reconstrucción asoman entre las plumas
	var claws: Array = []
	for s: float in [1.0, -1.0]:
		var ai: Dictionary = arm_info[s]
		claws.append_array(_hand_claws(ai, k, film, mobile))
	parts["GarrasManos"] = { "arrays": BodyKit.merge(claws), "mat": "claw", "node": "" }
	# ── las plumas de la reconstrucción: las alas de los brazos, el abanico de la cola y las de contorno ──
	if not film:
		var cards: Array = []
		_contour(cards, body, lay, lk, rng, mobile)
		_arm_wing(cards, arm_info[1.0] as Dictionary, lk, k, rng, mobile)
		_tail_fan(cards, body, lay, lk, k, rng, mobile)
		parts["Plumas"] = { "arrays": BodyKit.cards(cards, -INF if car else 0.0008), "mat": "feather", "node": "" }
	# ── la cabeza ──
	for pk: String in head.parts:
		parts[pk] = head.parts[pk]
	for nk: String in head.nodes:
		nodes[nk] = head.nodes[nk]
	nodes["head"] = { "parent": "", "xf": head_xf }
	lay["eyes"] = head.eyes
	lay["mouth"] = head.mouth
	lay["mask"] = head.mask
	if rig:
		rig_spec["neck"] = { "pivot": Vector3(-head_len * 0.38, 0.0, 0.0), "len": head_len }
		lay["rig"] = rig_spec
	var box := BodyKit.aabb_of([body.arrays] + legs + arms)
	box = box.merge(AABB(head_c - Vector3.ONE * head_len * 0.6, Vector3.ONE * head_len * 1.2))
	return { "parts": parts, "nodes": nodes, "layout": lay, "box": box }


## El radio de la cola en f (0 la raíz, 1 la punta): se afila despacio (las cola de los dromeosáuridos, larga y rígida).
static func _tail_r(r0: float, f: float) -> float:
	return lerpf(r0, r0 * 0.1, pow(clampf(f, 0.0, 1.0), 0.85))


## La rodilla de una pierna de dos huesos (fémur f, tibia t) de la cadera h al talón a, doblada hacia hint (hacia delante).
static func _knee(h: Vector3, a: Vector3, f: float, t: float, hint: Vector3) -> Vector3:
	var d := h.distance_to(a)
	var dir := (a - h) / maxf(d, 1e-6)
	if d >= f + t - 1e-4:
		return h + dir * d * f / (f + t)
	var x := (f * f - t * t + d * d) / (2.0 * d)
	var y := sqrt(maxf(f * f - x * x, 0.0))
	var perp := hint - dir * hint.dot(dir)
	perp = perp.normalized() if perp.length_squared() > 1e-8 else Vector3.UP
	return h + dir * x + perp * y


## Una pata del cuerpo: el muslo macizo de la cadera a la rodilla, la tibia hasta el talón (el anclaje de la pata de la 5h,
## que llega por −X de su marco) y una manga sobre el metatarso (sleeve m, a lo largo de +X) que acaba con su grosor.
## on_floor: tumbado, lo que baja de la mesa se aplasta contra ella.
## split (5t-B): dos piezas que se solapan en el talón, [la pierna hasta pasado el talón, la manga desde antes de él].
static func _leg(hip: Vector3, knee: Vector3, an: Transform3D, k: float, meta_r: float, sleeve: float, mobile: bool, ring: int,
		on_floor := true, split := false) -> Array:
	var heel := an.origin
	var dir := an.basis.x.normalized()
	var into := (knee - hip).normalized()
	# recta a lo largo del metatarso desde un poco antes del talón (la manga, con el mismo eje que la pata)
	var pts := PackedVector3Array([hip - into * 0.04 * k, hip, hip.lerp(knee, 0.55), knee, knee.lerp(heel - dir * 0.04 * k, 0.5), heel - dir * 0.04 * k,
		heel - dir * 0.01 * k, heel + dir * sleeve * 0.5, heel + dir * sleeve])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var tot := cum[cum.size() - 1]
	var u_k := cum[3] / tot
	var u_h := cum[6] / tot
	var sp := BodyKit.spine(pts, 18 if mobile else 36)
	var n := sp.size()
	var r_k := [[0.0, 0.05 * k], [cum[1] / tot, 0.055 * k], [cum[2] / tot, 0.042 * k], [u_k, 0.027 * k], [cum[4] / tot, 0.022 * k],
		[u_h, meta_r * 1.25], [1.0, meta_r * 1.08]]
	var lr := BodyKit.profile(n, r_k)
	var lz := BodyKit.profile(n, [[0.0, 0.045 * k], [cum[1] / tot, 0.05 * k], [cum[2] / tot, 0.038 * k], [u_k, 0.025 * k], [cum[4] / tot, 0.02 * k],
		[u_h, meta_r * 1.0], [1.0, meta_r * 0.9]])
	var fur := BodyKit.profile(n, [[0.0, 1.0], [u_k, 0.8], [u_h, 0.45], [1.0, 0.3]])
	if not split:
		return (BodyKit.loft({ "spine": sp, "up": Vector3.UP, "ring": ring, "top": lr, "bot": lr, "sr": lz, "sl": lz, "s0": 0.5, "s1": 0.55,
			"zone": 0.25, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.4, "ao_under": 0.25,
			"fur": fur, "floor": { "y0": 0.0, "band": 0.0025 * k } if on_floor else {} }) as Dictionary).arrays
	var cut := clampi(int(round(u_h * float(n - 1))), 2, n - 3)
	var ov := maxi(int(round(0.04 * float(n - 1))), 1)
	var out: Array = []
	for piece in 2:
		var a := 0 if piece == 0 else maxi(cut - ov, 0)
		var b := mini(cut + ov, n - 1) if piece == 0 else n - 1
		var slr := lr.slice(a, b + 1)
		var slz := lz.slice(a, b + 1)
		if piece == 0:
			for q in range(cut - ov, b - a + 1):
				var f := 1.0 - 0.06 * clampf(float(q - (cut - ov)) / float(maxi(2 * ov, 1)), 0.0, 1.0)
				slr[q] *= f
				slz[q] *= f
		out.append((BodyKit.loft({ "spine": sp.slice(a, b + 1), "up": Vector3.UP, "ring": ring, "top": slr, "bot": slr, "sr": slz, "sl": slz,
			"s0": lerpf(0.5, 0.55, float(a) / float(n - 1)), "s1": lerpf(0.5, 0.55, float(b) / float(n - 1)), "zone": 0.25, "flow": 1.0,
			"cap_start": true, "cap_end": true, "cap_k": 0.4, "ao_under": 0.25, "fur": fur.slice(a, b + 1),
			"floor": { "y0": 0.0, "band": 0.0025 * k } if on_floor else {} }) as Dictionary).arrays)
	return out


## Un brazo plegado como el ala de un ave, sobre el pecho (s: 1 el de arriba, el derecho; −1 el de abajo): el húmero hacia
## atrás, el antebrazo hacia delante y la mano hacia atrás, apoyados en la piel del tronco.
## → { arrays, pts: [hombro, codo, muñeca, punta de la mano], nrm (la normal del tronco en cada uno), r }
static func _arm(body: Dictionary, s: float, u_sh: float, tot: float, k: float, mobile: bool) -> Dictionary:
	var arc: PackedFloat32Array = body.arc
	var i0 := int(body.i0)
	var at := func(du: float, a: float, lift: float) -> Array:
		var along := arc[i0] + (u_sh + du / tot) * (arc[int(body.i1)] - arc[i0])
		var spt: Array = BodyKit.surface_point(body, BodyKit.station_at(body, along), a if s > 0.0 else 1.0 - a)
		return [(spt[0] as Vector3) + (spt[1] as Vector3) * lift, spt[1]]
	var r := 0.016 * k
	var sh: Array = at.call(0.015 * k, 0.68, -r * 0.6)
	var el: Array = at.call(0.12 * k, 0.64, r * 0.9)
	var wr: Array = at.call(0.035 * k, 0.6, r * 0.9)
	var tp: Array = at.call(0.17 * k, 0.62, r * 0.7)
	var pts := PackedVector3Array([sh[0], el[0], wr[0], tp[0]])
	var sp := BodyKit.spine(pts, 12 if mobile else 26)
	var n := sp.size()
	var rr := BodyKit.profile(n, [[0.0, r * 1.5], [0.3, r * 1.05], [0.62, r * 0.85], [1.0, r * 0.55]])
	var arrays: Array = (BodyKit.loft({ "spine": sp, "up": (sh[1] as Vector3), "ring": 14 if mobile else 20, "top": rr, "bot": rr, "sr": rr, "sl": rr,
		"s0": 0.3, "s1": 0.32, "zone": 0.25, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.6, "ao_under": 0.2,
		"fur": BodyKit.profile(n, [[0.0, 0.8], [0.6, 0.5], [1.0, 0.3]]) }) as Dictionary).arrays
	return { "arrays": arrays, "pts": pts, "nrm": [sh[1], el[1], wr[1], tp[1]], "r": r }


## La mano del de película: tres dedos largos desde la muñeca, hacia atrás sobre el pecho (sin las garras).
static func _hand(ai: Dictionary, k: float, mobile: bool) -> Array:
	var pts: PackedVector3Array = ai.pts
	var nr: Array = ai.nrm
	var w := pts[2]
	var t := pts[3]
	var nn: Vector3 = nr[2]
	var dir := (t - w).normalized()
	var side := dir.cross(nn).normalized()
	var out: Array = []
	for i in 3:
		var fl := float([0.055, 0.075, 0.065][i]) * k
		var off := side * (float(i) - 1.0) * 0.012 * k
		var a := t - dir * 0.02 * k + off
		var b := a + (dir + side * (float(i) - 1.0) * 0.15 - nn * 0.25).normalized() * fl
		var sp := BodyKit.spine(PackedVector3Array([a, a.lerp(b, 0.5) + nn * 0.004 * k, b]), 6 if mobile else 10)
		var rr := BodyKit.profile(sp.size(), [[0.0, 0.0075 * k], [1.0, 0.0045 * k]])
		out.append((BodyKit.tube(sp, rr, 8 if mobile else 10, { "zone": 0.25, "s0": 0.3, "s1": 0.31 }) as Dictionary).arrays)
	return out


## Las garras de las manos: al final de cada dedo (el de película) o asomando entre las plumas en la punta de la mano.
static func _hand_claws(ai: Dictionary, k: float, film: bool, mobile: bool) -> Array:
	var pts: PackedVector3Array = ai.pts
	var nr: Array = ai.nrm
	var t := pts[3]
	var w := pts[2]
	var nn: Vector3 = nr[3]
	var dir := (t - w).normalized()
	var side := dir.cross(nn).normalized()
	var out: Array = []
	for i in 3:
		var fl := float([0.055, 0.075, 0.065][i]) * k * (1.0 if film else 0.0)
		var off := side * (float(i) - 1.0) * 0.012 * k
		var a := t - dir * 0.02 * k + off
		var root := a + (dir + side * (float(i) - 1.0) * 0.15 - nn * 0.25).normalized() * fl if film else t + off + dir * 0.004 * k
		var cl := (0.03 if film else 0.022) * k
		var d2 := (dir - nn * 0.3).normalized()
		var p1 := root + d2 * cl * 0.55 + nn * cl * 0.08
		var p2 := root + d2 * cl - nn * cl * 0.35
		var sp := BodyKit.spine(PackedVector3Array([root - d2 * cl * 0.1, p1, p2]), 6 if mobile else 10)
		var rr := BodyKit.profile(sp.size(), [[0.0, 0.0055 * k], [0.6, 0.0035 * k], [1.0, 0.0004 * k]])
		out.append((BodyKit.tube(sp, rr, 8, { "cap_start": true, "cap_end": false }) as Dictionary).arrays)
	return out


## Las plumas de contorno de la reconstrucción: una cresta de plumas algo más largas a lo largo del cuello, el lomo y la
## raíz de la cola (la vuelta de arriba), echadas hacia atrás sobre las capas del cuerpo, del color del lomo.
static func _contour(out: Array, lo: Dictionary, lay: Dictionary, lk: Dictionary, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var total := arc[int(lo.i1)]
	var L := float(lay.L)
	var fe: Array = lk.feather
	var back := _c(String(fe[0]))
	var dark := _c(String(fe[2]))
	var along := total * 0.03
	var row := 0
	while along < total * lerpf(float(lay.u_hip), 1.0, 0.3):
		var u := along / total
		var fl := L * lerpf(0.022, 0.034, smoothstep(0.0, float(lay.u_sh), u)) * (1.4 if mobile else 1.0)
		var fi := BodyKit.station_at(lo, along)
		var n_around := 2 if mobile else 4
		for j in n_around:
			# de la vuelta 0,93 a la 0,07 (el lomo)
			var a := fposmod(0.93 + 0.14 * (float(j) + 0.5 * float(row % 2) + (rng.next() - 0.5) * 0.5) / float(n_around), 1.0)
			var fj := fi + (rng.next() - 0.5) * 0.5
			var spt: Array = BodyKit.surface_point(lo, fj, a)
			var len := fl * (0.85 + 0.3 * rng.next())
			var f := BodyKit.surface_path(lo, fj, a, 1.0, len, fl * 0.15, fl * 0.3, 3, (rng.next() - 0.5) * 0.02)
			out.append({ "p": spt[0], "nrm": spt[1], "path": f[0], "path_n": f[1], "len": len, "wid": fl * 0.42, "cup": 0.1,
				"col": back.lerp(dark, 0.35 * rng.next()) * (0.92 + 0.12 * rng.next()), "kind": 5, "pattern": 0, "param": 0.0, "seed": rng.next(),
				"breath": 1.0 if u > float(lay.u_sh) else 0.2, "shade": 0.92 + 0.08 * rng.next(), "segs": 3, "lat": 1, "smooth": 0.7 })
		along += fl * (0.6 if mobile else 0.38)
		row += 1


## El ala del brazo de arriba: las rémiges de la mano (primarias) y del antebrazo (secundarias; Turner et al. 2007 cuentan
## unas 14 papilas en el cúbito), echadas hacia atrás sobre el costado, y una fila de coberteras encima.
static func _arm_wing(out: Array, ai: Dictionary, lk: Dictionary, k: float, rng: Rng, mobile: bool) -> void:
	var pts: PackedVector3Array = ai.pts
	var nr: Array = ai.nrm
	var fe: Array = lk.feather
	var remex := _c(String(fe[0])).darkened(0.15)
	var covert := _c(String(fe[0]))
	var r := float(ai.r)
	# por encima de las capas del cuerpo (sus plumas miden unos 2 cm)
	var coat := 0.012 * k
	var layer := 0.0
	# primarias, de la punta de la mano a la muñeca (las de fuera, debajo)
	var n_p := 5 if mobile else 9
	for i in n_p:
		var f := float(i) / float(n_p - 1)
		var root := pts[3].lerp(pts[2], f)
		var nn: Vector3 = (nr[3] as Vector3).lerp(nr[2], f).normalized()
		var axis := (Vector3(0.12, 0.0, 1.0) - nn * Vector3(0.12, 0.0, 1.0).dot(nn)).normalized()
		out.append({ "p": root + nn * (r * 0.6 + coat + layer * 0.0012 * k), "axis": axis.rotated(nn, (rng.next() - 0.5) * 0.06), "nrm": nn,
			"len": (0.22 - 0.05 * f) * k, "wid": 0.024 * k, "bend": 0.2, "lift": 0.05, "cup": 0.06, "twist": (rng.next() - 0.5) * 0.08,
			"col": remex * (0.92 + 0.12 * rng.next()), "kind": 2, "pattern": 1, "param": 5.0, "seed": rng.next(), "breath": 0.5,
			"shade": 0.82 + 0.18 * f, "segs": 5 if not mobile else 3, "lat": 2, "smooth": 0.3 })
		layer += 1.0
	# secundarias, a lo largo del antebrazo (de la muñeca al codo)
	var n_s := 6 if mobile else 12
	for i in n_s:
		var f := float(i) / float(n_s - 1)
		var root := pts[2].lerp(pts[1], f)
		var nn: Vector3 = (nr[2] as Vector3).lerp(nr[1], f).normalized()
		var axis := (Vector3(0.2, 0.0, 1.0) - nn * Vector3(0.2, 0.0, 1.0).dot(nn)).normalized()
		out.append({ "p": root + nn * (r * 0.6 + coat + layer * 0.0012 * k), "axis": axis.rotated(nn, (rng.next() - 0.5) * 0.08), "nrm": nn,
			"len": (0.17 + 0.02 * f) * k, "wid": 0.028 * k, "bend": 0.24, "lift": 0.06, "cup": 0.07, "twist": (rng.next() - 0.5) * 0.1,
			"col": remex.lerp(covert, 0.3) * (0.92 + 0.12 * rng.next()), "kind": 2, "pattern": 5 if i % 3 == 0 else 1, "param": 4.0,
			"seed": rng.next(), "breath": 0.6, "shade": 0.86 + 0.14 * f, "segs": 4 if not mobile else 3, "lat": 2, "smooth": 0.35 })
		layer += 0.6
	# coberteras: tapan la base de las rémiges
	var n_c := 6 if mobile else 14
	for i in n_c:
		var f := (float(i) + 0.5 * rng.next()) / float(n_c)
		var root := pts[3].lerp(pts[1], f)
		var nn: Vector3 = (nr[3] as Vector3).lerp(nr[1], f).normalized()
		var axis := (Vector3(0.1, 0.0, 1.0) - nn * Vector3(0.1, 0.0, 1.0).dot(nn)).normalized()
		out.append({ "p": root + nn * (r * 0.9 + coat + layer * 0.0012 * k), "axis": axis, "nrm": nn, "len": 0.075 * k, "wid": 0.03 * k,
			"bend": 0.25, "lift": 0.08, "cup": 0.12, "twist": (rng.next() - 0.5) * 0.2, "col": covert.darkened(0.1) * (0.92 + 0.12 * rng.next()), "kind": 1,
			"pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.6, "shade": 0.95, "segs": 3, "lat": 1, "smooth": 0.6 })


## El abanico de la cola: timoneras a los dos lados de la mitad del final de la cola; las del lado de arriba se echan sobre
## la cola hacia atrás (tumbado, el abanico se cierra) y las de abajo quedan aplastadas en la mesa.
static func _tail_fan(out: Array, lo: Dictionary, lay: Dictionary, lk: Dictionary, k: float, rng: Rng, mobile: bool) -> void:
	var arc: PackedFloat32Array = lo.arc
	var i0 := int(lo.i0)
	var i1 := int(lo.i1)
	var u_hip := float(lay.u_hip)
	var fe: Array = lk.feather
	var col := _c(String(fe[0]))
	var n := 8 if mobile else 18
	for i in n:
		var f := lerpf(0.42, 0.96, float(i) / float(n - 1))
		var along := arc[i0] + lerpf(u_hip, 1.0, f) * (arc[i1] - arc[i0])
		var fi := BodyKit.station_at(lo, along)
		for a: float in [0.7, 0.8, 0.3]:
			if mobile and a > 0.75:
				continue
			var spt: Array = BodyKit.surface_point(lo, fi, a)
			var nn: Vector3 = spt[1]
			var t: Vector3 = spt[2]
			var len := (0.12 + 0.1 * smoothstep(0.42, 0.9, f)) * k
			var axis := (t + nn * 0.12).normalized()
			out.append({ "p": (spt[0] as Vector3) + nn * 0.002 * k, "axis": axis, "nrm": nn, "len": len, "wid": 0.03 * k, "bend": 0.1,
				"lift": 0.03, "cup": 0.04, "twist": 0.0, "col": col * (0.9 + 0.14 * rng.next()), "kind": 3, "pattern": 1, "param": 3.0,
				"seed": rng.next(), "breath": 0.0, "shade": 0.85 + 0.15 * f, "segs": 4 if not mobile else 2, "lat": 2, "smooth": 0.3 })


# ─────────────────────────────── la cabeza ───────────────────────────────

## La cabeza en su marco (x hacia el hocico, y arriba, z a la derecha; el origen en el centro): el cráneo largo y bajo con la
## órbita grande arriba y atrás, la ceja, el pómulo, la depresión delante del ojo, la narina en la punta y la línea de la
## boca hasta debajo del ojo; los labios escamosos (la reconstrucción) o los dientes sobre la mandíbula (el de película);
## los ojos con sus párpados (cierra el de abajo, como en las aves). Las plumas de la reconstrucción cubren la nuca y lo alto
## (el pelo del sombreador, sobre la piel de escamas); el hocico queda desnudo, con escamas.
## → { parts, nodes, eyes, mouth, grid, mask: [base, punta, radio de la base, radio de la punta] }
static func _head(art: String, sh: Dictionary, L: float, hh: float, hw: float, k: float, rng: Rng, mobile: bool) -> Dictionary:
	var film := art == "velociraptor_pelicula"
	var parts := {}
	var nodes := {}
	var ring := 20 if mobile else 40
	var n := 18 if mobile else 40
	var x0 := -L * 0.5
	var x1 := L * 0.5
	var dish := float(sh.dish)
	var c_pts := PackedVector3Array([Vector3(x0, hh * 0.05, 0.0), Vector3(-L * 0.1, hh * 0.05, 0.0), Vector3(L * 0.25, -hh * (0.1 + 0.06 * dish), 0.0),
		Vector3(x1, -hh * (0.1 - 0.14 * dish), 0.0)])
	var csp := BodyKit.spine(c_pts, n)
	var top_k := _knots(sh.top, hh)
	var bot_k := _knots(sh.bot, hh)
	var side_k := _knots(sh.side, hw)
	var spec := { "spine": csp, "up": Vector3.UP, "ring": ring, "top": BodyKit.profile(n, top_k), "bot": BodyKit.profile(n, bot_k),
		"sr": BodyKit.profile(n, side_k), "sl": BodyKit.profile(n, side_k), "nt": 2.3, "nb": 2.1, "cap_start": true, "cap_end": true,
		"cap_k": 0.6, "zone": 0.75, "s0": 0.0, "s1": 0.06, "flow": -1.0, "ao_under": 0.2, "fur": 1.0 }
	var pre := BodyKit.loft(spec)
	# ── el ojo, grande, arriba y atrás (mira de lado y algo hacia delante) ──
	var er := float(sh.eye_r) * k
	var f_e := _fi(pre, n, 0.32)
	var bumps: Array = []
	var eyes_at := {}
	for s: float in [1.0, -1.0]:
		var spe: Array = BodyKit.surface_point(pre, f_e, 0.165 if s > 0.0 else 0.835)
		var nrm: Vector3 = spe[1]
		var ec: Vector3 = (spe[0] as Vector3) - nrm * er * 0.72
		var gaze := (nrm * 0.75 + Vector3(1.0, 0.1, 0.0) * 0.25).normalized()
		eyes_at[s] = [ec, gaze]
		bumps.append({ "c": ec + gaze * er * 0.85, "r": er * 1.15, "amt": -er * 0.22 })
		# la ceja (el borde de la órbita) y el pómulo
		bumps.append({ "c": ec + Vector3(-er * 0.1, er * 1.15, s * er * 0.15), "r": Vector3(er * 1.8, er * 0.5, er * 1.2), "amt": er * 0.25 })
		bumps.append({ "c": ec + Vector3(-er * 0.3, -er * 1.6, s * er * 0.2), "r": Vector3(er * 2.4, er * 0.7, er * 1.2), "amt": er * 0.18 })
		# la depresión de delante del ojo y la narina
		var spa: Array = BodyKit.surface_point(pre, _fi(pre, n, 0.56), 0.21 if s > 0.0 else 0.79)
		bumps.append({ "c": spa[0], "r": Vector3(L * 0.09, hh * 0.22, hw * 0.25), "amt": -hh * 0.06 })
		var spn: Array = BodyKit.surface_point(pre, _fi(pre, n, 0.9), 0.17 if s > 0.0 else 0.83)
		bumps.append({ "c": spn[0], "r": Vector3(L * 0.03, hh * 0.1, hw * 0.12), "amt": -hh * 0.07 })
	# ── la línea de la boca: de la punta del hocico (abajo) hasta debajo del ojo ──
	var i1 := float(pre.i1)
	var jaw_uv := [[i1 + 3.5, 0.5], [i1 + 1.0, 0.42], [_fi(pre, n, 0.9), 0.38], [_fi(pre, n, 0.72), 0.37], [_fi(pre, n, 0.52), 0.36],
		[_fi(pre, n, 0.36), 0.355], [_fi(pre, n, 0.28), 0.355]]
	for s: float in [1.0, -1.0]:
		for e: Array in jaw_uv:
			var p: Vector3 = (BodyKit.surface_point(pre, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1])) as Array)[0]
			bumps.append({ "c": p, "r": Vector3(L * 0.035, hh * 0.05, hw * 0.08), "amt": -hh * 0.022 })
	spec["bumps"] = bumps
	var skull := BodyKit.loft(spec)
	# la línea de la boca sobre la piel ya modelada: los labios escamosos o la encía con los dientes
	var jaw: Array = []
	var line_pts: Array = []
	var teeth: Array = []
	var mouth := {}
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var nrs: Array = []
		for e: Array in jaw_uv:
			var spl: Array = BodyKit.surface_point(skull, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1]))
			pts.append((spl[0] as Vector3) + (spl[1] as Vector3) * 0.0004 * k)
			nrs.append(spl[1])
		line_pts.append_array(pts)
		var lsp := BodyKit.spine(pts, 12 if mobile else 26)
		var lr := BodyKit.profile(lsp.size(), [[0.0, hh * 0.022], [0.5, hh * 0.028], [1.0, hh * 0.02]])
		jaw.append((BodyKit.tube(lsp, lr, 6 if mobile else 8, { "cap_start": false }) as Dictionary).arrays)
		mouth[s] = pts[pts.size() - 1]
		if film:
			# los dientes de arriba, curvados hacia atrás, por fuera de la mandíbula; los de delante, más largos
			var nt := 8 if mobile else 15
			for i in nt:
				# separación y largo algo irregulares (se caen y se reponen); los de delante, más largos
				var f := clampf((float(i) + 0.5 + (rng.next() - 0.5) * 0.5) / float(nt) * 0.92, 0.0, 0.95)
				var q := clampf(f * float(lsp.size() - 1), 0.0, float(lsp.size() - 1) - 1e-3)
				var qi := int(floor(q))
				var p := lsp[qi].lerp(lsp[qi + 1], q - float(qi))
				var tg := (lsp[mini(qi + 1, lsp.size() - 1)] - lsp[qi]).normalized()
				var out_n := Vector3(0.0, 0.0, s)
				var down := (Vector3(0.0, -1.0, 0.0) - tg * Vector3(0.0, -1.0, 0.0).dot(tg)).normalized()
				var tl := L * (0.05 - 0.025 * f) * (0.7 + 0.5 * rng.next())
				# la raíz, dentro de la encía (bajo el labio): se ve la corona, curvada hacia atrás
				var root := p - out_n * hw * 0.02 + down * (-tl * 0.25)
				var tip := root + down * tl * 1.1 - tg * tl * (0.22 + 0.12 * rng.next()) + out_n * hw * 0.05
				var tsp := BodyKit.spine(PackedVector3Array([root, root.lerp(tip, 0.5) - tg * tl * 0.05, tip]), 5)
				var tr := BodyKit.profile(tsp.size(), [[0.0, tl * 0.2], [0.6, tl * 0.12], [1.0, tl * 0.015]])
				teeth.append((BodyKit.tube(tsp, tr, 6, { "cap_start": true, "cap_end": false }) as Dictionary).arrays)
	parts["Boca"] = { "arrays": BodyKit.merge(jaw), "mat": "gum" if film else "lips", "node": "head" }
	if film:
		parts["Dientes"] = { "arrays": BodyKit.merge(teeth), "mat": "teeth", "node": "head" }
	# las plumas de la cabeza (la reconstrucción): la nuca y lo alto; el hocico, los ojos y la boca, desnudos
	if not film:
		var va: PackedVector3Array = skull.arrays[Mesh.ARRAY_VERTEX]
		var ca: PackedColorArray = skull.arrays[Mesh.ARRAY_COLOR]
		var e_r: Vector3 = eyes_at[1.0][0]
		var e_l: Vector3 = eyes_at[-1.0][0]
		for i in va.size():
			var v := va[i]
			var q := Vector3(v.x / (L * 0.5), v.y / hh, absf(v.z) / hw)
			# de la nuca hacia delante, cada vez más cortas, hasta pasado el ojo; el hocico, desnudo (con escamas); la boca, sin
			var f := (1.0 - smoothstep(-0.7, 0.3, q.x)) * smoothstep(-0.75, -0.2, q.y + 0.45 * (1.0 - smoothstep(-0.8, -0.2, q.x)))
			f *= 0.85 + 0.3 * sin(q.z * 23.0 + q.y * 17.0) * smoothstep(-0.3, 0.2, q.x)
			f *= smoothstep(er * 1.15, er * 2.2, minf(v.distance_to(e_r), v.distance_to(e_l)))
			var col := ca[i]
			col.b = clampf(f, 0.0, 1.0)
			ca[i] = col
		skull.arrays[Mesh.ARRAY_COLOR] = ca
		parts["Cabeza"] = { "arrays": skull.arrays, "mat": "scales_head", "node": "head", "shells": 1, "shell_mat": "plume_head_capas", "fur_m": 0.012 * k }
	else:
		parts["Cabeza"] = { "arrays": skull.arrays, "mat": "scales_head", "node": "head" }
	# ── los ojos y sus párpados (cierra el de abajo, como en las aves) ──
	var eyes: Array = []
	for s: float in [1.0, -1.0]:
		var ec: Vector3 = eyes_at[s][0]
		var gaze: Vector3 = eyes_at[s][1]
		var eup := (Vector3.UP - gaze * Vector3.UP.dot(gaze)).normalized()
		var exf := Transform3D(Basis(eup.cross(gaze).normalized(), eup, gaze), ec)
		var tag := "d" if s > 0.0 else "i"
		nodes["eye_" + tag] = { "parent": "head", "xf": exf }
		parts["Ojo_" + tag] = { "arrays": BodyKit.ellipsoid(Vector3.ZERO, Vector3.ONE * er, Basis(Vector3.BACK, -PI * 0.5), 18 if mobile else 30, 12 if mobile else 22), "mat": "eye", "node": "eye_" + tag }
		parts["Parpado_" + tag + "_sup"] = { "arrays": BodyKit.eyelid(er * 1.06, true, 70.0, mobile, 18.0), "mat": "lid", "node": "lid_" + tag + "_sup" }
		parts["Parpado_" + tag + "_inf"] = { "arrays": BodyKit.eyelid(er * 1.06, false, 74.0, mobile, 18.0), "mat": "lid", "node": "lid_" + tag + "_inf" }
		nodes["lid_" + tag + "_sup"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 26.0 }
		nodes["lid_" + tag + "_inf"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 52.0 }
		eyes.append({ "tag": tag, "r": er, "kind": "teropodo" })
	# la mascarilla: del hocico (delante de los ojos) a la punta
	var cap_len := 0.6 * maxf(maxf(BodyKit.sample(top_k, 1.0), BodyKit.sample(bot_k, 1.0)), BodyKit.sample(side_k, 1.0))
	var mask := [Vector3(L * 0.02, -hh * 0.12, 0.0), Vector3(x1 + cap_len + 0.012 * k, -hh * 0.1 + hh * 0.14 * dish, 0.0), maxf(hh, hw) * 1.05, maxf(hh, hw) * 0.42]
	return { "parts": parts, "nodes": nodes, "eyes": eyes, "mouth": mouth, "grid": skull.grid, "mask": mask }


## La cabeza de la reconstrucción (unidad 5n), en su marco (x hacia el hocico, y arriba, z a la derecha; el origen en el
## centro de la nuca a la punta), con el cráneo medido de GIN 100/25 (Barsbold y Osmólska 1999, en care_anatomy.gd):
##   - largo y bajo: el hocico es el 60 % del cráneo (140 de 230 mm), estrecho (22 mm, un tercio del cráneo detrás de las
##     órbitas, 77 mm) y algo más bajo (45 mm frente a 66); con la mandíbula, baja y de borde convexo, debajo;
##   - el perfil del hocico, cóncavo: baja desde la frente a lo largo de los nasales, es más hondo justo detrás de la narina
##     y se levanta un poco sobre ella, hacia la punta;
##   - la órbita grande, arriba y atrás, mirando hacia delante y hacia fuera, con su ceja y el pómulo; la depresión
##     alargada de delante del ojo (la fosa anteorbitaria) y la narina, oval y en su hoyo, cerca de la punta;
##   - la boca cerrada con los labios escamosos que tapan los dientes (la hipótesis de Cullen et al. 2023: en los
##     terópodos, el tejido extraoral cubría los dientes con la boca cerrada), de la punta hasta debajo de la órbita;
##   - las plumas cortas de la cabeza (las de la nuca, la coronilla y los carrillos, más cortas que las del cuerpo) y el
##     hocico desnudo, con escamas.
## Las proporciones entre las medidas (dónde baja el perfil, lo que añade la piel) son de dibujo.
## → { parts, nodes, eyes, mouth, grid, mask: [base, punta, radio de la base, radio de la punta], hh, hw }
static func _head_recon(art: String, L: float, mobile: bool) -> Dictionary:
	var parts := {}
	var nodes := {}
	var ring := 20 if mobile else 40
	var n := 18 if mobile else 40
	var D := CareAnatomy.value(art, "skull_depth_m", 0.066)
	var Ds := CareAnatomy.value(art, "snout_depth_m", 0.045)
	var Dm := CareAnatomy.value(art, "mandible_depth_m", 0.023)
	var W := CareAnatomy.value(art, "skull_width_m", 0.077) * float(CareAnatomy.head_draw("velociraptor", "skin_w", 1.12))
	var Wl := CareAnatomy.value(art, "lacrimal_width_m", 0.052) * float(CareAnatomy.head_draw("velociraptor", "skin_w", 1.12))
	var Ws := CareAnatomy.value(art, "snout_width_m", 0.022) * float(CareAnatomy.head_draw("velociraptor", "skin_w", 1.12))
	var u_orb := 1.0 - CareAnatomy.value(art, "snout_m", 0.14) / CareAnatomy.value(art, "skull_m", 0.23)
	# el perfil de arriba (lo alto sobre la espina, m) y el alto entero con la mandíbula, de la nuca (0) a la punta (1)
	var top_k := [[0.0, 0.42 * D], [0.12, 0.56 * D], [0.25, 0.6 * D], [u_orb - 0.02, 0.54 * D], [0.5, 0.65 * Ds], [0.62, 0.52 * Ds], [0.74, 0.42 * Ds],
		[0.8, 0.39 * Ds], [0.88, 0.43 * Ds], [0.94, 0.41 * Ds], [1.0, 0.27 * Ds]]
	var tall_k := [[0.0, D + 0.4 * Dm], [0.15, D + 0.6 * Dm], [0.3, D + 0.55 * Dm], [u_orb + 0.01, Ds + 0.8 * Dm], [0.6, 0.8 * Ds + 0.66 * Dm],
		[0.75, 0.66 * Ds + 0.62 * Dm], [0.88, 0.55 * Ds + 0.58 * Dm], [0.96, 0.45 * Ds + 0.47 * Dm], [1.0, 0.3 * Ds + 0.3 * Dm]]
	var bot_k: Array = []
	for e: Array in tall_k:
		bot_k.append([float(e[0]), float(e[1]) - BodyKit.sample_smooth(top_k, float(e[0]))])
	var side_k := [[0.0, 0.45 * W], [0.15, 0.5 * W], [0.28, 0.47 * W], [u_orb + 0.01, 0.5 * Wl], [0.5, 0.25 * (Wl + Ws) * 1.05], [0.6, 0.59 * Ws],
		[0.8, 0.55 * Ws], [0.95, 0.5 * Ws], [1.0, 0.38 * Ws]]
	var hh := 0.5 * (D + 0.6 * Dm)
	var hw := 0.5 * W
	var r_end := maxf(maxf(BodyKit.sample_smooth(top_k, 1.0), BodyKit.sample_smooth(bot_k, 1.0)), BodyKit.sample_smooth(side_k, 1.0))
	var cap_len := 0.6 * r_end
	var x0 := -L * 0.5
	var x1 := L * 0.5 - cap_len * 0.9
	var csp := BodyKit.spine(PackedVector3Array([Vector3(x0, 0.0, 0.0), Vector3(x1, 0.0, 0.0)]), n)
	var spec := { "spine": csp, "up": Vector3.UP, "ring": ring, "top": BodyKit.profile_smooth(n, top_k), "bot": BodyKit.profile_smooth(n, bot_k),
		"sr": BodyKit.profile_smooth(n, side_k), "sl": BodyKit.profile_smooth(n, side_k), "nt": 2.3, "nb": 2.1, "cap_start": true, "cap_end": true,
		"cap_k": 0.6, "zone": 0.75, "s0": 0.0, "s1": 0.06, "flow": -1.0, "ao_under": 0.2, "fur": 1.0 }
	var pre := BodyKit.loft(spec)
	var fi_at := func(u: float) -> float: return float(pre.i0) + clampf(u, 0.0, 1.0) * float(int(pre.i1) - int(pre.i0))
	# ── el ojo, grande, en la órbita de arriba y atrás (mira hacia fuera y hacia delante) ──
	var er := float(CareAnatomy.head_draw("velociraptor", "eye_r_m", 0.0145))
	var u_e := u_orb - 0.42 * er * 2.0 / L
	var f_e := float(fi_at.call(u_e))
	var y_e := BodyKit.sample_smooth(top_k, u_e) - 1.55 * er
	var a_e := BodyKit.angle_at_y(pre, f_e, y_e, 0.02, 0.3)
	var bumps: Array = []
	var eyes_at := {}
	for s: float in [1.0, -1.0]:
		var spe: Array = BodyKit.surface_point(pre, f_e, a_e if s > 0.0 else 1.0 - a_e)
		var nrm: Vector3 = spe[1]
		var ec: Vector3 = (spe[0] as Vector3) - nrm * er * 0.58
		var gaze := (nrm * 0.68 + Vector3(1.0, 0.08, 0.0) * 0.32).normalized()
		eyes_at[s] = [ec, gaze]
		bumps.append({ "c": ec + gaze * er * 0.85, "r": er * 1.15, "amt": -er * 0.22 })
		# la ceja (el borde de arriba de la órbita: el lagrimal y el postorbital) y el pómulo (el yugal) por debajo
		bumps.append({ "c": ec + Vector3(-er * 0.1, er * 1.1, s * er * 0.2), "r": Vector3(er * 1.9, er * 0.5, er * 1.1), "amt": er * 0.26 })
		bumps.append({ "c": ec + Vector3(-er * 0.5, -er * 1.55, s * er * 0.25), "r": Vector3(er * 2.6, er * 0.6, er * 1.1), "amt": er * 0.16 })
		# la fosa anteorbitaria: una depresión larga y poco honda en la mitad de arriba del hocico, delante del ojo
		var spa: Array = BodyKit.surface_point(pre, float(fi_at.call(lerpf(u_orb, 1.0, 0.25))), 0.2 if s > 0.0 else 0.8)
		bumps.append({ "c": spa[0], "r": Vector3(L * 0.1, Ds * 0.16, Ws * 0.6), "amt": -Ds * 0.045 })
		# la narina, oval y en su hoyo, cerca de la punta, en la parte de arriba
		var spn: Array = BodyKit.surface_point(pre, float(fi_at.call(0.88)), 0.17 if s > 0.0 else 0.83)
		bumps.append({ "c": spn[0], "r": Vector3(L * 0.045, Ds * 0.13, Ws * 0.35), "amt": -Ds * 0.07 })
	# ── la boca: el surco de la punta hasta debajo de la órbita, con el labio de arriba que cae un poco sobre el de abajo ──
	var lip := [[0.18, -0.3 * D], [0.3, -0.21 * D], [u_orb + 0.03, -0.16 * D], [0.6, -0.26 * Ds], [0.75, -0.21 * Ds], [0.88, -0.13 * Ds], [0.96, -0.07 * Ds]]
	var lip_uv := BodyKit.lip_line(pre, int(pre.i0), lip, 1.0)
	for s: float in [1.0, -1.0]:
		for k in lip_uv.size():
			var e: Array = lip_uv[k]
			var p: Vector3 = (BodyKit.surface_point(pre, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1])) as Array)[0]
			bumps.append({ "c": p, "r": Vector3(L * 0.035, Ds * 0.06, Ws * 0.35), "amt": -Ds * 0.03 })
			if k > 0 and k < lip_uv.size() - 1:
				bumps.append({ "c": p + Vector3(0.0, Ds * 0.07, 0.0), "r": Vector3(L * 0.04, Ds * 0.06, Ws * 0.3), "amt": Ds * 0.018 })
	spec["bumps"] = bumps
	var skull := BodyKit.loft(spec)
	# los labios escamosos sobre la línea de la boca (tapan los dientes: no se ve ninguno)
	var jaw: Array = []
	var line_pts: Array = []
	var mouth := {}
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for e: Array in lip_uv:
			var spl: Array = BodyKit.surface_point(skull, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1]))
			pts.append((spl[0] as Vector3) + (spl[1] as Vector3) * 0.0004)
		line_pts.append_array(pts)
		var lsp := BodyKit.spine(pts, 12 if mobile else 26)
		var lr := BodyKit.profile(lsp.size(), [[0.0, Ds * 0.03], [0.4, Ds * 0.036], [1.0, Ds * 0.026]])
		jaw.append((BodyKit.tube(lsp, lr, 6 if mobile else 8, { "cap_start": false }) as Dictionary).arrays)
		mouth[s] = pts[0]
	parts["Boca"] = { "arrays": BodyKit.merge(jaw), "mat": "lips", "node": "head" }
	# la abertura de cada narina: una ranura oscura en la parte de delante de su hoyo
	var nares: Array = []
	for s: float in [1.0, -1.0]:
		var spn: Array = BodyKit.surface_point(skull, float(fi_at.call(0.9)), 0.17 if s > 0.0 else 0.83)
		var nn: Vector3 = spn[1]
		var t: Vector3 = spn[2]
		var nb := Basis(t.normalized(), nn.cross(t).normalized() * s, nn).orthonormalized()
		nares.append(BodyKit.ellipsoid((spn[0] as Vector3) - nn * Ds * 0.01, Vector3(L * 0.022, Ds * 0.05, Ds * 0.03), nb, 10 if mobile else 16, 6 if mobile else 10, { "zone": 0.0 }))
	parts["Narinas"] = { "arrays": BodyKit.merge(nares), "mat": "lips", "node": "head" }
	# las plumas cortas de la cabeza (las capas del sombreador): la nuca, la coronilla hasta pasado el ojo, los carrillos
	# y la garganta; el hocico, el borde del ojo y la boca, desnudos (escamas)
	var va: PackedVector3Array = skull.arrays[Mesh.ARRAY_VERTEX]
	var ca: PackedColorArray = skull.arrays[Mesh.ARRAY_COLOR]
	var e_r: Vector3 = eyes_at[1.0][0]
	var e_l: Vector3 = eyes_at[-1.0][0]
	var x_snout := lerpf(x0, x1, u_orb + 0.04)
	for i in va.size():
		var v := va[i]
		var f := 1.0 - smoothstep(x_snout - L * 0.16, x_snout + L * 0.05, v.x)
		# por arriba, las plumas llegan algo más lejos (la frente); por abajo, la garganta
		f = maxf(f, (1.0 - smoothstep(x_snout, x_snout + L * 0.1, v.x)) * smoothstep(0.4, 0.8, v.y / hh))
		f *= 0.85 + 0.3 * sin(v.z * 230.0 + v.y * 170.0) * (1.0 - smoothstep(x0, x_snout, v.x)) * 0.5
		f *= smoothstep(er * 1.15, er * 2.0, minf(v.distance_to(e_r), v.distance_to(e_l)))
		var dl := INF
		for lp: Vector3 in line_pts:
			dl = minf(dl, v.distance_to(lp))
		f *= smoothstep(Ds * 0.06, Ds * 0.2, dl)
		var col := ca[i]
		col.b = clampf(f, 0.0, 1.0)
		ca[i] = col
	skull.arrays[Mesh.ARRAY_COLOR] = ca
	parts["Cabeza"] = { "arrays": skull.arrays, "mat": "scales_head", "node": "head", "shells": 1, "shell_mat": "plume_head_capas", "fur_m": 0.012 }
	# ── los ojos y sus párpados (cierra el de abajo, como en las aves) ──
	var eyes: Array = []
	for s: float in [1.0, -1.0]:
		var ec: Vector3 = eyes_at[s][0]
		var gaze: Vector3 = eyes_at[s][1]
		var eup := (Vector3.UP - gaze * Vector3.UP.dot(gaze)).normalized()
		var exf := Transform3D(Basis(eup.cross(gaze).normalized(), eup, gaze), ec)
		var tag := "d" if s > 0.0 else "i"
		nodes["eye_" + tag] = { "parent": "head", "xf": exf }
		parts["Ojo_" + tag] = { "arrays": BodyKit.ellipsoid(Vector3.ZERO, Vector3.ONE * er, Basis(Vector3.BACK, -PI * 0.5), 18 if mobile else 30, 12 if mobile else 22), "mat": "eye", "node": "eye_" + tag }
		parts["Parpado_" + tag + "_sup"] = { "arrays": BodyKit.eyelid(er * 1.06, true, 70.0, mobile, 18.0), "mat": "lid", "node": "lid_" + tag + "_sup" }
		parts["Parpado_" + tag + "_inf"] = { "arrays": BodyKit.eyelid(er * 1.06, false, 74.0, mobile, 18.0), "mat": "lid", "node": "lid_" + tag + "_inf" }
		nodes["lid_" + tag + "_sup"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 26.0 }
		nodes["lid_" + tag + "_inf"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 52.0 }
		eyes.append({ "tag": tag, "r": er, "kind": "teropodo" })
	# la mascarilla: del hocico, delante de los ojos (con sus plumas), a pasada la punta
	var u_m := u_orb + 0.04
	var r_m := maxf(maxf(BodyKit.sample_smooth(top_k, u_m), BodyKit.sample_smooth(bot_k, u_m)), BodyKit.sample_smooth(side_k, u_m))
	var mask := [Vector3(lerpf(x0, x1, u_m), 0.0, 0.0), Vector3(x1 + cap_len + 0.014, 0.12 * Ds, 0.0), r_m * 1.3, 0.42 * maxf(hh, hw)]
	return { "parts": parts, "nodes": nodes, "eyes": eyes, "mouth": mouth, "grid": skull.grid, "mask": mask, "hh": hh, "hw": hw }


static func _knots(knots: Array, k: float) -> Array:
	var out: Array = []
	for e: Array in knots:
		out.append([float(e[0]), float(e[1]) * k])
	return out


## La estación fraccionaria de un loft de n estaciones (sin las tapas) en u (0-1).
static func _fi(lo: Dictionary, n: int, u: float) -> float:
	return float(lo.i0) + clampf(u, 0.0, 1.0) * float(n - 1)
