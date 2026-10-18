## Cetrería · el cuerpo del tigre y del oso en alta definición (unidad 5i, petición 37), hecho en código desde cero e
## independiente de los modelos del coche en marcha. Solo dibujo; el tamaño es el de su ficha (core/lab/care_anatomy.gd:
## la cabeza y el cuerpo, la cola, el alto a la cruz; el ojo, el pelo y el cráneo del tigre de Mazák 1981, el pelo y la
## cabeza del oso de Pasitschniak-Arts 1993); el modelado de la cabeza y de cada músculo es de dibujo.
## Tumbado de lado sobre la mesa de la clínica (el lado izquierdo abajo), con el lomo hacia −X, la cabeza hacia −Z y las
## cuatro patas hacia el borde (+X), enganchado a las patas de la 5h por sus anclajes (el codo y la rodilla: el antebrazo y
## la pierna son de la pata). De cerca:
##   - el tronco con la cruz y las paletillas, las costillas, la tripa que cuelga (el tigre) o la joroba de los hombros (el
##     oso), la grupa y las caderas; los brazos y los muslos llegan a cada anclaje y siguen por encima del antebrazo de la
##     pata como una manga que acaba con su grosor (el codo macizo, sin juntura);
##   - el pelo en capas (body_fur.gdshader: mechones que se juntan en punta, peinados hacia la cola y hacia las manos), corto
##     y con las rayas del tigre (las del cuerpo, las de la cara, los anillos de la cola y las orejas negras con su mancha
##     blanca); largo, con las puntas canosas, en el oso;
##   - la cabeza modelada (el cráneo abovedado y el hocico corto y ancho del tigre, con la gorguera de pelo largo que
##     enmarca la cara; el perfil cóncavo y el hocico largo del oso), los ojos con brillo y párpados (cierra el de arriba)
##     a lo separados que van las órbitas, la trufa (que desde arriba casi no se ve), los labios negros, los bigotes del
##     tigre y las orejas redondas;
##   - la cola del tigre, larga y apoyada en la mesa; la del oso, corta.
## model() es puro (arrays y transformaciones): se puede llamar desde un hilo; su resultado va a la caché.
extends RefCounted

const BodyKit = preload("res://app/lab/cetreria/body_kit.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const Rng = preload("res://core/shared/rng.gd")

const MM := 0.001
## El dibujo de cada uno: el pelo [raíz, punta] (los de las patas de la 5h, para que no se vea la costura), el claro de la
## tripa, el oscuro (rayas, labios, orejas), la trufa [piel, surco], el ojo [iris, oscuro], el largo del pelo (mm: lomo,
## tripa, la cabeza (la gorguera o la coronilla), las orejas, la cola), lo canoso de las puntas y el hocico del oso.
const LOOK := {
	"tigre": { "fur": ["#6E3A12", "#D8893A"], "belly": "#F1E6D0", "dark": "#0D0A09", "nose": ["#C98B7E", "#5A3A34"],
		"iris": ["#D6A12A", "#6B4510"], "hair": [12.0, 25.0, 45.0, 6.0, 14.0], "grizzle": 0.0, "muzzle": "#F1E6D0" },
	"oso": { "fur": ["#20140C", "#6A4A30"], "belly": "#3E2C1E", "dark": "#0E0B09", "nose": ["#1C1816", "#0A0908"],
		"iris": ["#4A2E18", "#1A0E06"], "hair": [80.0, 70.0, 50.0, 30.0, 50.0], "grizzle": 0.45, "muzzle": "#8A6A48" },
}
## La forma de la cabeza (dibujo, unidad 5n; el tamaño sale del cráneo medido de care_anatomy.gd): los nudos [u, k] (u: 0 la
## nuca → 1 la punta de la nariz, por una curva suave: BodyKit.profile_smooth) de lo alto (top) y de lo hondo (bot), en
## fracciones del medio alto hh, y del medio ancho (side), en fracciones de hw; lo cuadrada que es la sección arriba (nt) y
## abajo (nb); dónde acaba la frente y empieza el hocico (stop); el ojo [u, cuánto mira de frente, cuánto se hunde (en
## radios)]; las orejas [u, vuelta desde lo alto (0,25: el lado), cuánto mira el cuenco hacia fuera]; la línea de la boca
## [u, alto/hh] de la comisura hacia delante; lo que estrecha el caballete del hocico frente al labio (bridge) y la frente
## entre los ojos frente a los pómulos (brow_narrow); la tapa de la nariz (cap, en radios); dónde
## va la trufa (nose_at: lo que se mete detrás de la punta, en radios de la trufa; su alto, fracción de lo alto del hocico en
## la punta; y su fondo, fracción del ancho del hocico; el ancho y el alto, de HEAD_DRAW); y el largo del pelo de cada sitio
## (fur: fracciones del de la cabeza, LOOK.hair[2]): el hocico, la cara, la frente, la gorguera o los carrillos y la nariz.
## El oso (Pasitschniak-Arts 1993): la frente ancha y abombada que baja en curva cóncava hasta un hocico largo y más
## estrecho, con la trufa grande y negra; los pómulos anchos; los ojos pequeños y hundidos donde empieza el hocico; las
## orejas pequeñas y redondas, separadas en lo alto. El tigre (Mazák 1981): el cráneo abovedado, la frente convexa, el
## hocico corto y ancho con las almohadillas de los bigotes, la trufa pequeña y la barbilla; la gorguera en los carrillos.
const HEAD := {
	"tigre": {
		"top": [[0.0, 0.7], [0.14, 0.9], [0.32, 1.0], [0.48, 0.99], [0.6, 0.9], [0.68, 0.8], [0.78, 0.72], [0.88, 0.66], [0.95, 0.61], [1.0, 0.52]],
		"bot": [[0.0, 0.92], [0.24, 1.0], [0.44, 0.95], [0.58, 0.85], [0.7, 0.76], [0.8, 0.72], [0.9, 0.68], [0.96, 0.62], [1.0, 0.54]],
		"side": [[0.0, 0.84], [0.2, 0.98], [0.38, 1.03], [0.5, 1.0], [0.6, 0.86], [0.68, 0.72], [0.78, 0.66], [0.88, 0.62], [0.95, 0.56], [1.0, 0.44]],
		"nt": [[0.0, 2.2], [0.5, 2.3], [0.8, 2.6], [1.0, 2.5]], "nb": [[0.0, 2.0], [0.6, 2.2], [1.0, 2.4]],
		"stop": 0.68, "eye": [0.61, 0.4, 0.74], "ear": [0.25, 0.13, 0.25], "bridge": 0.16, "brow_narrow": 0.45, "cap": 0.34, "nose_at": [0.78, 0.5, 0.1],
		"lip": [[0.63, -0.44], [0.72, -0.48], [0.82, -0.5], [0.9, -0.48], [0.96, -0.42]],
		"fur": { "muzzle": 0.17, "face": 0.26, "brow": 0.3, "ruff": 1.0, "nose": 0.05 } },
	"oso": {
		"top": [[0.0, 0.64], [0.14, 0.86], [0.3, 0.98], [0.44, 1.0], [0.55, 0.94], [0.62, 0.8], [0.68, 0.64], [0.76, 0.56], [0.86, 0.52], [0.94, 0.5], [1.0, 0.42]],
		"bot": [[0.0, 0.9], [0.22, 1.0], [0.4, 0.98], [0.52, 0.9], [0.62, 0.78], [0.74, 0.67], [0.86, 0.6], [0.95, 0.54], [1.0, 0.46]],
		"side": [[0.0, 0.8], [0.2, 0.93], [0.4, 1.0], [0.52, 0.98], [0.6, 0.84], [0.66, 0.64], [0.72, 0.5], [0.82, 0.46], [0.92, 0.43], [1.0, 0.37]],
		"nt": [[0.0, 2.2], [0.45, 2.7], [0.6, 2.7], [0.75, 2.8], [1.0, 2.5]], "nb": [[0.0, 2.0], [0.6, 2.2], [1.0, 2.4]],
		"stop": 0.67, "eye": [0.64, 0.4, 0.66], "ear": [0.3, 0.11, 0.6], "bridge": 0.24, "brow_narrow": 0.18, "cap": 0.3, "nose_at": [0.12, 0.42, 0.24],
		"lip": [[0.66, -0.38], [0.74, -0.33], [0.84, -0.3], [0.93, -0.29], [0.98, -0.26]],
		"fur": { "muzzle": 0.13, "face": 0.3, "brow": 0.4, "ruff": 1.0, "nose": 0.05 } },
}


static func _c(hex: String) -> Color:
	return Color(hex)


## El tamaño de la cabeza (m): (largo, medio alto, medio ancho). El tigre, de su cráneo (Mazák 1981: el largo de un macho y
## su anchura cigomática), con la piel de la nariz y el pelo de la nuca (HEAD_DRAW: ×1,08 y ×1,09); el oso, el largo de su
## cabeza (los machos de Yellowstone, escalados) y el ancho de su cráneo (los machos de Kodiak) con la piel de los pómulos
## (×1,08). El alto, una proporción de dibujo del ancho.
static func head_dims(art: String) -> Vector3:
	if art == "tigre":
		var hw := CareAnatomy.value("tigre", "skull_width_m", 0.248) * 0.5 * float(CareAnatomy.head_draw("tigre", "skin_w", 1.09))
		return Vector3(CareAnatomy.value("tigre", "skull_m", 0.355) * float(CareAnatomy.head_draw("tigre", "skin_k", 1.08)), hw * 0.85, hw)
	var bw := CareAnatomy.value("oso", "skull_width_m", 0.284) * 0.5 * float(CareAnatomy.head_draw("oso", "skin_w", 1.08))
	return Vector3(CareAnatomy.value(art, "head_m", 0.48), bw * 0.84, bw)


## Los materiales del tigre o del oso: { id: { shader, params } } (care_body.gd los hace una vez por animal y calidad).
static func materials(art: String, mobile: bool) -> Dictionary:
	var lk: Dictionary = LOOK.get(art, LOOK.tigre)
	var tiger := art == "tigre"
	var hair: Array = lk.hair
	var fur: Array = lk.fur
	var detail := 0.0 if mobile else 1.0
	var dims := head_dims(art)
	var base := { "root_color": _c(String(fur[0])), "tip_color": _c(String(fur[1])), "belly_color": _c(String(lk.belly)),
		"dark_color": _c(String(lk.dark)), "belly": 1.0 if tiger else 0.35, "grizzle": float(lk.grizzle), "comb": 0.8 if tiger else 0.9,
		"droop": 0.12 if tiger else 0.35, "rough": 0.8, "spec": 0.3, "breath_mm": 14.0 if tiger else 18.0,
		"stripe_n": 34.0, "tail_from": 0.67 }
	var body := base.duplicate()
	body.merge({ "fur_mm": float(hair[0]) * (1.0 if tiger else 0.55), "strand_mm": 0.3 if tiger else 0.55, "clump_mm": 2.4 if tiger else 9.0,
		"clump": 0.5 if tiger else 0.85, "thick": 0.85 if tiger else 1.1, "pattern": 1 if tiger else 0, "tone_var": 0.1 if tiger else 0.2 }, true)
	var head := base.duplicate()
	head.merge({ "fur_mm": float(hair[2]), "strand_mm": 0.26 if tiger else 0.5, "clump_mm": 2.2 if tiger else 6.0,
		"clump": 0.5 if tiger else 0.8, "thick": 0.8 if tiger else 1.0, "pattern": 2 if tiger else 4, "tone_var": 0.1 if tiger else 0.18,
		"head_half": Vector3(dims.x * 0.5, dims.y, dims.z), "breath_mm": 0.0, "belly_color": _c(String(lk.muzzle)),
		"comb": 0.85 if tiger else 0.9, "droop": 0.25 if tiger else 0.3 }, true)
	var ear := base.duplicate()
	ear.merge({ "fur_mm": float(hair[3]), "strand_mm": 0.3, "clump_mm": 2.0, "clump": 0.5, "thick": 0.9, "pattern": 3 if tiger else 0,
		"tone_var": 0.1, "breath_mm": 0.0 }, true)
	var tail := base.duplicate()
	tail.merge({ "fur_mm": float(hair[4]), "strand_mm": 0.32, "clump_mm": 2.6, "clump": 0.55, "thick": 0.9, "pattern": 1 if tiger else 0,
		"tone_var": 0.1, "breath_mm": 0.0 }, true)
	return {
		"fur_body": { "shader": "fur", "params": body },
		# 5t-B: el brazo que golpea, con su propio material (el mismo pelo; el retraso del pelo al golpear va solo en él)
		"fur_arm": { "shader": "fur", "params": body.duplicate() },
		"fur_head": { "shader": "fur", "params": head },
		"fur_ear": { "shader": "fur", "params": ear },
		"fur_tail": { "shader": "fur", "params": tail },
		"nose": { "shader": "skin", "params": { "mode": 3, "color_a": _c(String((lk.nose as Array)[0])), "color_b": _c(String((lk.nose as Array)[1])),
			"relief_mm": 0.35, "detail": detail, "rough": 0.42 if tiger else 0.5, "spec": 0.4 } },
		"lips": { "shader": "skin", "params": { "mode": 5, "color_a": _c(String(lk.dark)).lightened(0.05), "color_b": _c(String(lk.dark)), "rough": 0.5,
			"spec": 0.2, "relief_mm": 0.1, "detail": detail } },
		"whisker": { "shader": "skin", "params": { "mode": 5, "color_a": Color(0.96, 0.95, 0.92), "color_b": Color(0.85, 0.83, 0.8), "rough": 0.3,
			"spec": 0.5, "relief_mm": 0.0, "detail": 0.0 } },
		"eye": { "shader": "eye", "params": { "iris_color": _c(String((lk.iris as Array)[0])), "iris_dark": _c(String((lk.iris as Array)[1])),
			"sclera_color": Color(0.85, 0.8, 0.72) if tiger else Color(0.55, 0.45, 0.4), "iris_r": 0.8 if tiger else 0.7, "pupil_r": 0.32 if tiger else 0.4 } },
		# el párpado, del color de la piel de alrededor (el blanco de alrededor del ojo del tigre, el pardo del oso), con su
		# borde negro
		"lid": { "shader": "skin", "params": { "mode": 6, "color_a": _c(String(lk.belly)).darkened(0.3) if tiger else _c(String(fur[1])).darkened(0.35),
			"color_b": _c(String(lk.dark)), "rough": 0.6, "spec": 0.3, "rim_mm": 2.5, "relief_mm": 0.05 } },
	}


## El modelo del tigre o del oso. anchors: { pata: Transform3D en la raíz (el codo o la rodilla) }; claw: la garra del motor
## (da el grosor del antebrazo de la pata); mobile: menos detalle. pose (unidad 4r: el coche en marcha; vacío en la
## cetrería, que lo dibuja como siempre): el animal no está tumbado en la mesa, sino de pie o agazapado (lo coloca
## app/lab/animals/hd3d.gd con las patas en el suelo): back_m (m, lo alto del lomo sobre el codo más alto; las patas lo
## alcanzan: de pie, más largas) o lift (m, lo que se aparta el tronco de los codos y las rodillas hacia el lomo),
## head_pitch (cuánto mira la cabeza hacia las patas; 0, al frente), sin la mesa que lo aplasta, con el tronco entre las
## patas de los dos lados, la cabeza, el cuello y la cola en su eje, y la cola del tigre colgando. → { parts, nodes,
## layout, box }
static func model(art: String, anchors: Dictionary, claw: Dictionary, mobile: bool, pose := {}) -> Dictionary:
	var car := not pose.is_empty()
	var tiger := art == "tigre"
	var rng := Rng.new(Rng.seed_of("cuerpo|" + art))
	var lk: Dictionary = LOOK.get(art, LOOK.tigre)
	var hb := CareAnatomy.value(art, "head_body_m", 1.9)
	var tail_len := CareAnatomy.value(art, "tail_m", 0.12)
	var shoulder := CareAnatomy.value(art, "shoulder_m", 1.0)
	var dims := head_dims(art)
	var head_len := dims.x
	var hh := dims.y
	var hw := dims.z
	var total := hb + tail_len
	var d: Dictionary = CarePaw.TIGER if tiger else CarePaw.BEAR
	var s_paw := float(claw.get("base_r_mm", float(d.base_ref))) / float(d.base_ref)
	var arm_r := float((d.arm as Array)[1]) * MM * s_paw
	var arm_len := float((d.arm as Array)[0]) * MM * s_paw
	# los codos y las rodillas (anclajes de la 5h)
	var fr: Transform3D = anchors.get("delantera_derecha", Transform3D(Basis.IDENTITY, Vector3(-0.22, 0.09, -0.43)))
	var fl: Transform3D = anchors.get("delantera_izquierda", Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.09, -0.24)))
	var hr: Transform3D = anchors.get("trasera_derecha", Transform3D(Basis.IDENTITY, Vector3(-0.25, 0.09, 0.25)))
	var hl: Transform3D = anchors.get("trasera_izquierda", Transform3D(Basis.IDENTITY, Vector3(-0.22, 0.09, 0.44)))
	var elbow_x := minf(fr.origin.x, fl.origin.x)
	# el pecho: la línea de la tripa junto a los codos; el lomo, a lo hondo del pecho (~0,45 del alto a la cruz)
	var depth := shoulder * (0.45 if tiger else 0.5)
	var width := shoulder * (0.36 if tiger else 0.46)
	# en el coche (pose.back_m), el lomo a back_m del codo más alto: la tripa a back_m − depth, y las patas que lo alcanzan
	var lift := float(pose.get("back_m", depth + 0.03)) - depth - 0.03 if pose.has("back_m") else float(pose.get("lift", 0.0))
	var x_v := elbow_x - 0.03 - lift
	var x_c := x_v - depth * 0.5
	# de lado en la mesa, el tronco a medio ancho de ella; en el coche, entre las patas de los dos lados
	var y_c := (fr.origin.y + fl.origin.y + hr.origin.y + hl.origin.y) * 0.25 if car else width * 0.5 * 0.88
	var z_sh := (fr.origin.z + fl.origin.z) * 0.5 - 0.06
	var z_hip := (hr.origin.z + hl.origin.z) * 0.5 + (0.1 if tiger else 0.06)
	var neck_len := 0.3 if tiger else 0.26
	var z_nose := z_sh - neck_len - head_len
	var z_tail := z_hip + (0.2 if tiger else 0.18)
	var lay := { "hb": hb, "depth": depth, "width": width, "x_c": x_c, "y_c": y_c, "z_sh": z_sh, "z_hip": z_hip, "total": total }
	var ring := 24 if mobile else 48
	var parts := {}
	var nodes := {}
	# 5t-B: en la cetrería (no en el coche), los pivotes de la reacción del animal
	var rig := not car
	# unidad 4u: en el coche, con pose.rig, la cola en su pivote (el agarre en curva)
	var car_rig := car and bool(pose.get("rig", false))
	var rig_spec := {}
	# ── la cabeza, primero (en su marco: x hacia la nariz, y hacia arriba, z a la derecha), para apoyarla en la mesa ──
	var head := _head(art, head_len, hw, hh, rng, mobile, rig)
	var fwd := Vector3(float(pose.get("head_pitch", 0.1)), 0.0, -1.0).normalized() if car else Vector3(0.12, -0.04, -1.0).normalized()
	var dorsal := (Vector3(-1.0, 0.0, 0.0) - fwd * Vector3(-1.0, 0.0, 0.0).dot(fwd)).normalized()
	var right := fwd.cross(dorsal).normalized()
	var hbasis := Basis(fwd, dorsal, right)
	var head_c := Vector3(x_c - depth * 0.08, 0.0, z_nose + head_len * 0.5)
	# la mejilla de abajo, apoyada en la tela (lo más bajo de la cabeza, 4 mm hundido)
	var low := INF
	for p: Vector3 in (head.grid as PackedVector3Array):
		low = minf(low, (hbasis * p).y)
	head_c.y = y_c if car else -low - 0.004
	var head_xf := Transform3D(hbasis, head_c)
	lay["head_xf"] = head_xf
	lay["head_size"] = Vector3(head_len, hh * 2.0, hw * 2.0)
	# ── el tronco con el cuello: de dentro de la cabeza (más fino que la nuca, que lo tapa) a la raíz de la cola ──
	var n_st := 30 if mobile else 72
	var neck0 := head_xf * Vector3(-head_len * 0.08, -hh * 0.12, 0.0)
	var sp_pts := PackedVector3Array([
		neck0,
		Vector3(x_c - depth * 0.12, y_c if car else y_c * 0.9, z_sh - neck_len * 0.55),
		Vector3(x_c - depth * 0.02, y_c, z_sh + 0.08),
		Vector3(x_c + depth * 0.02, y_c, (z_sh + z_hip) * 0.5),
		Vector3(x_c - depth * 0.02, y_c, z_hip - 0.04),
		Vector3(x_c - depth * 0.12, y_c if car else y_c * 0.92, z_tail),
	])
	var sp := BodyKit.spine(sp_pts, n_st)
	var arc_len := 0.0
	for i in range(1, sp.size()):
		arc_len += sp[i].distance_to(sp[i - 1])
	var u_sh := clampf(neck0.distance_to(Vector3(x_c, y_c, z_sh)) / arc_len, 0.15, 0.5)
	var u_hip := clampf(1.0 - (z_tail - z_hip) / arc_len, 0.6, 0.95)
	# dónde sale el cuello de la cabeza (por la nuca)
	var u_out := clampf(head_len * 0.45 / arc_len, 0.02, 0.2)
	var nr := 0.13 if tiger else 0.17
	# el pecho hondo, la cintura recogida (el tigre) y la grupa; el oso, redondo y con la tripa llena
	var top_k := [[0.0, hh * 0.4], [u_out, nr * 0.74], [u_out + 0.05, nr * 0.95], [u_sh * 0.65, nr * 1.08], [u_sh, depth * (0.5 if tiger else 0.56)],
		[lerpf(u_sh, u_hip, 0.55), depth * (0.38 if tiger else 0.46)], [u_hip, depth * 0.44], [0.95, depth * 0.32], [1.0, depth * 0.2]]
	var bot_k := [[0.0, hh * 0.45], [u_out, nr * 0.8], [u_out + 0.05, nr * 1.02], [u_sh * 0.65, nr * 1.18], [u_sh + 0.03, depth * 0.52],
		[lerpf(u_sh, u_hip, 0.35), depth * 0.5], [lerpf(u_sh, u_hip, 0.7), depth * (0.36 if tiger else 0.5)], [u_hip - 0.02, depth * 0.38],
		[0.95, depth * 0.3], [1.0, depth * 0.2]]
	var side_k := [[0.0, hw * 0.45], [u_out, nr * 0.8], [u_out + 0.05, nr * 0.98], [u_sh * 0.65, nr * 1.12], [u_sh + 0.04, width * 0.5],
		[lerpf(u_sh, u_hip, 0.6), width * (0.42 if tiger else 0.5)], [u_hip, width * 0.5], [0.95, width * 0.34], [1.0, width * 0.2]]
	var br_k := [[0.0, 0.0], [u_sh, 0.4], [lerpf(u_sh, u_hip, 0.4), 1.0], [lerpf(u_sh, u_hip, 0.75), 1.0], [u_hip, 0.3], [1.0, 0.0]]
	var zone_k := [[0.0, 0.75], [u_sh * 0.7, 0.75], [u_sh, 0.0], [1.0, 0.0]]
	var bumps: Array = []
	# la cruz y las paletillas (la de arriba, la derecha, se marca más), las caderas y, en el oso, la joroba
	var sh_c := Vector3(x_c - depth * 0.32, y_c + width * 0.38, z_sh + 0.02)
	bumps.append({ "c": sh_c, "r": Vector3(depth * 0.25, width * 0.2, 0.16), "amt": 0.018 if tiger else 0.025 })
	bumps.append({ "c": Vector3(x_c - depth * 0.3, y_c + width * 0.36, z_hip - 0.02), "r": Vector3(depth * 0.22, width * 0.18, 0.14), "amt": 0.015 })
	if not tiger:
		# la joroba de los hombros (los músculos que mueven las manos al cavar; Pasitschniak-Arts 1993: «a prominent shoulder
		# hump»), más alta que la grupa, y el lomo que baja detrás de ella (dibujo)
		bumps.append({ "c": Vector3(x_c - depth * 0.55, y_c, z_sh + 0.0), "r": Vector3(0.12, width * 0.5, 0.2), "amt": 0.1, "dir": Vector3(-1.0, 0.0, 0.0) })
		bumps.append({ "c": Vector3(x_c - depth * 0.55, y_c, lerpf(z_sh, z_hip, 0.5)), "r": Vector3(0.1, width * 0.5, 0.16), "amt": -0.018, "dir": Vector3(-1.0, 0.0, 0.0) })
	else:
		# la tripa que cuelga (la bolsa primordial de los felinos) y las costillas
		bumps.append({ "c": Vector3(x_v, y_c, lerpf(z_sh, z_hip, 0.62)), "r": Vector3(0.08, width * 0.45, 0.2), "amt": 0.03, "dir": Vector3(1.0, -0.2, 0.0) })
		for k in 5:
			bumps.append({ "c": Vector3(x_c + depth * 0.05, y_c + width * 0.45, lerpf(z_sh + 0.12, z_sh + 0.4, float(k) / 4.0)), "r": Vector3(depth * 0.3, 0.03, 0.025), "amt": 0.004 })
	var trunk := BodyKit.loft({
		"spine": sp, "up": dorsal, "ring": ring, "top": BodyKit.profile(n_st, top_k), "bot": BodyKit.profile(n_st, bot_k),
		"sr": BodyKit.profile(n_st, side_k), "sl": BodyKit.profile(n_st, side_k), "nt": 2.2, "nb": 2.0,
		"breath": BodyKit.profile(n_st, br_k), "zone": BodyKit.profile(n_st, zone_k), "fur": 1.0,
		"s0": (head_len * 0.8) / total, "s1": hb / total, "flow": 1.0, "cap_start": false, "cap_end": true, "cap_k": 0.5,
		"ao_under": 0.2, "bumps": bumps, "floor": {} if car else { "y0": 0.0, "band": width * 0.14 },
	})
	lay["trunk"] = trunk
	# ── los brazos y los muslos: del hombro o de la cadera (dentro del tronco) al codo o a la rodilla, con la manga ──
	# (unidad 5t-B, la reacción del animal: en la cetrería, el brazo de arriba, el derecho, va en su pivote del hombro, y su
	# manga, partida en el codo con un solape, sigue a la pata; en reposo, todo en su sitio)
	var limbs: Array = []
	var specs := [[fr, true, true], [fl, true, false], [hr, false, true], [hl, false, false]]
	for e: Array in specs:
		var fore := bool(e[1])
		var up_side := 1.0 if bool(e[2]) else -1.0
		var root_p := Vector3(x_c + depth * (0.12 if fore else 0.05), y_c + width * (0.22 if fore else 0.24) * up_side, z_sh + 0.02 if fore else z_hip)
		var r_root := (0.12 if fore else 0.15) * (1.0 if tiger else 1.2)
		if rig and fore and up_side > 0.0:
			var split := _limb(root_p, e[0] as Transform3D, r_root, arm_r, arm_len * 0.95, 0.55 if tiger else 0.35, mobile, ring / 2 + 8, not car, true)
			var fur_m := float((lk.hair as Array)[1]) * MM * 1.2
			parts["BrazoGolpe"] = { "arrays": split[0], "mat": "fur_arm", "node": "arm", "shells": 1, "fur_m": fur_m }
			parts["MangaGolpe"] = { "arrays": split[1], "mat": "fur_arm", "node": "forearm", "shells": 1, "fur_m": fur_m }
			nodes["arm"] = { "parent": "", "xf": Transform3D.IDENTITY }
			nodes["forearm"] = { "parent": "", "xf": Transform3D.IDENTITY }
			rig_spec["arm"] = { "node": "arm", "pivot": root_p, "elbow": (e[0] as Transform3D).origin, "paw": "delantera_derecha" }
			rig_spec["forearm"] = { "node": "forearm", "paw": "delantera_derecha" }
			continue
		limbs.append(_limb(root_p, e[0] as Transform3D, r_root, arm_r, arm_len * 0.95, 0.55 if tiger else 0.35, mobile, ring / 2 + 8, not car))
	parts["Cuerpo"] = { "arrays": BodyKit.merge([trunk.arrays] + limbs), "mat": "fur_body", "node": "", "shells": 1,
		"fur_m": float((lk.hair as Array)[1]) * MM * 1.2 }
	if rig:
		# la paletilla de arriba, por donde se desliza el músculo del hombro al golpear (body_fur.gdshader: bump_*)
		rig_spec["shoulder"] = { "c": sh_c, "r": maxf(depth * 0.25, 0.08) }
	# ── la cola: del final del tronco, apoyada en la mesa y curvada (en el coche, colgando: hacia +X, las patas) ──
	var t0 := Vector3(x_c - depth * 0.1, y_c if car else y_c * 0.8, z_tail - 0.04)
	var tail_pts := PackedVector3Array()
	var tn := 6
	for k in tn + 1:
		var t := float(k) / float(tn)
		if car:
			# hacia atrás y cayendo cada vez más, con la punta algo levantada (el tigre); la del oso, corta, casi recta
			var drop := (0.62 * pow(t, 1.4) - 0.1 * pow(t, 6.0)) if tiger else 0.15 * t
			tail_pts.append(Vector3(t0.x + drop * tail_len, y_c, t0.z + tail_len * t * (0.62 if tiger else 0.95)))
			continue
		var z := t0.z + tail_len * t * (0.85 if tiger else 1.0)
		var xoff := (sin(t * 2.6) * 0.18 if tiger else 0.0) * tail_len
		tail_pts.append(Vector3(t0.x + xoff * 0.5 + (0.12 * t * tail_len if tiger else 0.0), lerpf(t0.y, 0.035 if tiger else t0.y, smoothstep(0.0, 0.35, t)), z))
	var t_sp := BodyKit.spine(tail_pts, 12 if mobile else 36)
	var t_r := BodyKit.profile(t_sp.size(), [[0.0, 0.055 if tiger else 0.06], [0.2, 0.04 if tiger else 0.05], [1.0, 0.026 if tiger else 0.03]])
	var tail := BodyKit.loft({ "spine": t_sp, "up": dorsal, "ring": ring / 2 + 4, "top": t_r, "bot": t_r, "sr": t_r, "sl": t_r, "s0": hb / total,
		"s1": 1.0, "zone": 0.5, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.9, "ao_under": 0.3,
		"floor": {} if car else { "y0": 0.0, "band": 0.012 } })
	parts["Cola"] = { "arrays": tail.arrays, "mat": "fur_tail", "node": "tail" if rig or car_rig else "", "shells": 1, "fur_m": 0.06 }
	if rig or car_rig:
		nodes["tail"] = { "parent": "", "xf": Transform3D.IDENTITY }
		rig_spec["tail"] = { "node": "tail", "pivot": t0, "along": (tail_pts[1] - tail_pts[0]).normalized() }
	# ── la cabeza ──
	for k: String in head.parts:
		parts[k] = head.parts[k]
	for k: String in head.nodes:
		nodes[k] = head.nodes[k]
	nodes["head"] = { "parent": "", "xf": head_xf }
	if rig:
		rig_spec["neck"] = { "pivot": head_xf.affine_inverse() * neck0 + Vector3(-head_len * 0.12, 0.0, 0.0), "len": head_len }
		for k: String in ["ear_d", "ear_i", "whisk_d", "whisk_i", "jaw"]:
			if head.rig.has(k):
				rig_spec[k] = head.rig[k]
		lay["rig"] = rig_spec
	elif car_rig:
		lay["rig"] = rig_spec
	lay["eyes"] = head.eyes
	lay["eye_q"] = head.eye_q
	lay["face_q"] = head.face_q
	lay["mouth"] = head.mouth
	lay["head_len"] = head_len
	lay["mask"] = head.mask
	lay["nose"] = head.nose
	var box := BodyKit.aabb_of([trunk.arrays, tail.arrays] + limbs)
	box = box.merge(AABB(head_c - Vector3(head_len, head_len, head_len) * 0.6, Vector3(head_len, head_len, head_len) * 1.2))
	return { "parts": parts, "nodes": nodes, "layout": lay, "box": box }


## Un brazo o un muslo: del hombro o de la cadera (root_p, dentro del tronco) al codo o a la rodilla (el anclaje de la pata
## de la 5h, por −X de su marco), y una manga sobre el antebrazo o la pierna de la pata (sleeve m, a lo largo de +X): el
## codo macizo que adelgaza hasta el grosor de la pata, con el pelo cada vez más corto hasta el largo del de la pata
## (fur_end, fracción del pelo del cuerpo), sin juntura. on_floor: tumbado, lo que baja de la mesa se aplasta contra ella.
## split (5t-B): dos piezas que se solapan en el codo, [el brazo hasta pasado el codo, la manga desde antes del codo], para que
## el codo se doble; la del brazo, algo más fina en el solape (sin que las dos superficies coincidan).
static func _limb(root_p: Vector3, an: Transform3D, r_root: float, arm_r: float, sleeve: float, fur_end: float, mobile: bool, ring: int,
		on_floor := true, split := false) -> Array:
	var joint := an.origin
	var dir := an.basis.x.normalized()
	var pre := joint - dir * 0.04
	var mid := root_p.lerp(pre, 0.55)
	var pts := PackedVector3Array([root_p - Vector3(0.05, 0.0, 0.0), root_p, mid, pre, joint + dir * sleeve * 0.5, joint + dir * sleeve])
	var l_to_joint := 0.05 + root_p.distance_to(mid) + mid.distance_to(pre) + 0.04
	var l_all := l_to_joint + sleeve
	var u_j := l_to_joint / l_all
	var u_r := 0.05 / l_all
	var sp := BodyKit.spine(pts, 16 if mobile else 30)
	var n := sp.size()
	var r_k := [[0.0, r_root * 0.9], [u_r, r_root], [lerpf(u_r, u_j, 0.5), lerpf(r_root, arm_r * 1.9, 0.6)], [u_j - 0.04, arm_r * 1.8],
		[u_j, arm_r * 1.68], [lerpf(u_j, 1.0, 0.35), arm_r * 1.4], [lerpf(u_j, 1.0, 0.75), arm_r * 1.14], [1.0, arm_r * 1.06]]
	var v_k := [[0.0, r_root * 0.78], [u_r, r_root * 0.85], [lerpf(u_r, u_j, 0.5), lerpf(r_root * 0.85, arm_r * 1.7, 0.6)], [u_j, arm_r * 1.5],
		[lerpf(u_j, 1.0, 0.35), arm_r * 1.3], [lerpf(u_j, 1.0, 0.75), arm_r * 1.12], [1.0, arm_r * 1.06]]
	var lr := BodyKit.profile(n, v_k)
	var lz := BodyKit.profile(n, r_k)
	var fur := BodyKit.profile(n, [[0.0, 1.0], [u_j, lerpf(1.0, fur_end, 0.4)], [1.0, fur_end]])
	if not split:
		return (BodyKit.loft({ "spine": sp, "up": Vector3.UP, "ring": ring, "top": lr, "bot": lr, "sr": lz, "sl": lz,
			"s0": 0.3, "s1": 0.36, "zone": 0.25, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.3, "ao_under": 0.25,
			"fur": fur, "floor": { "y0": 0.0, "band": 0.012 } if on_floor else {} }) as Dictionary).arrays
	# las dos piezas: las estaciones hasta pasado el codo y desde antes de él (un solape de ~SPLIT_OVERLAP del largo)
	var cut := clampi(int(round(u_j * float(n - 1))), 2, n - 3)
	var ov := maxi(int(round(SPLIT_OVERLAP * float(n - 1))), 1)
	var out: Array = []
	for piece in 2:
		var a := 0 if piece == 0 else maxi(cut - ov, 0)
		var b := mini(cut + ov, n - 1) if piece == 0 else n - 1
		var ssp := sp.slice(a, b + 1)
		var slr := lr.slice(a, b + 1)
		var slz := lz.slice(a, b + 1)
		if piece == 0:
			# el brazo, un poco más fino donde se solapa con la manga
			for k in range(cut - ov, b - a + 1):
				var f := 1.0 - 0.06 * clampf(float(k - (cut - ov)) / float(maxi(2 * ov, 1)), 0.0, 1.0)
				slr[k] *= f
				slz[k] *= f
		var s_lo := lerpf(0.3, 0.36, float(a) / float(n - 1))
		var s_hi := lerpf(0.3, 0.36, float(b) / float(n - 1))
		out.append((BodyKit.loft({ "spine": ssp, "up": Vector3.UP, "ring": ring, "top": slr, "bot": slr, "sr": slz, "sl": slz,
			"s0": s_lo, "s1": s_hi, "zone": 0.25, "flow": 1.0, "cap_start": true, "cap_end": true, "cap_k": 0.3, "ao_under": 0.25,
			"fur": fur.slice(a, b + 1), "floor": { "y0": 0.0, "band": 0.012 } if on_floor else {} }) as Dictionary).arrays)
	return out


## El solape de las dos piezas del brazo que se parte en el codo (5t-B), en fracción de su largo, a cada lado.
const SPLIT_OVERLAP := 0.05


static func _knots(knots: Array, k: float) -> Array:
	var out: Array = []
	for e: Array in knots:
		out.append([float(e[0]), float(e[1]) * k])
	return out


## La estación fraccionaria de un loft de n estaciones (sin las tapas) en u (0-1).
static func _fi(lo: Dictionary, n: int, u: float) -> float:
	return float(lo.i0) + clampf(u, 0.0, 1.0) * float(n - 1)


## La cabeza en su marco (x hacia la nariz, y arriba, z a la derecha; el origen en el centro), unidad 5n: un barrido a lo
## largo de la cabeza con su sección en cada estación (la frente, el escalón, el caballete, los pómulos, el labio y la
## barbilla salen de los perfiles de HEAD, por una curva suave), el caballete del hocico más estrecho que el labio, y el
## modelado encima: las cuencas de los ojos y las cejas, los carrillos, las almohadillas de los bigotes del tigre, el surco
## de la boca con el labio de arriba que cae sobre el de abajo, y la barbilla. Encima van los labios negros, la trufa con
## sus orificios y el surco del labio, los ojos con sus párpados (cierra el de arriba), las orejas redondas con su cuenco y
## los bigotes del tigre; el pelo, corto en el hocico, alrededor de los ojos, de la trufa y de la boca, y largo en la
## gorguera del tigre y en los carrillos y la nuca del oso.
## Primero se hace sin el modelado para buscar en su superficie dónde van los ojos, la boca y las orejas.
## → { parts, nodes, eyes, eye_q, mouth, grid, mask: [base, punta, radio de la base, radio de la punta] }
static func _head(art: String, L: float, hw: float, hh: float, rng: Rng, mobile: bool, rig := false) -> Dictionary:
	var tiger := art == "tigre"
	# 5t-B: los pivotes de la cabeza (las orejas y los bigotes de cada lado), en el marco de la cabeza
	var hrig := {}
	var sh: Dictionary = HEAD.get(art, HEAD.tigre)
	var parts := {}
	var nodes := {}
	var ring := 24 if mobile else 48
	var n := 20 if mobile else 40
	var top_k := _knots(sh.top, hh)
	var bot_k := _knots(sh.bot, hh)
	var side_k := _knots(sh.side, hw)
	# la punta de la nariz llega a L/2 con la tapa de delante: la espina acaba antes
	var top_e := BodyKit.sample_smooth(top_k, 1.0)
	var bot_e := BodyKit.sample_smooth(bot_k, 1.0)
	var side_e := BodyKit.sample_smooth(side_k, 1.0)
	var cap_len := float(sh.cap) * maxf(maxf(top_e, bot_e), side_e)
	var x0 := -L * 0.5
	var x1 := L * 0.5 - cap_len * 0.9
	var csp := BodyKit.spine(PackedVector3Array([Vector3(x0, 0.0, 0.0), Vector3(x1, 0.0, 0.0)]), n)
	var spec := { "spine": csp, "up": Vector3.UP, "ring": ring, "top": BodyKit.profile_smooth(n, top_k), "bot": BodyKit.profile_smooth(n, bot_k),
		"sr": BodyKit.profile_smooth(n, side_k), "sl": BodyKit.profile_smooth(n, side_k), "nt": BodyKit.profile_smooth(n, sh.nt),
		"nb": BodyKit.profile_smooth(n, sh.nb), "cap_start": true, "cap_end": true, "cap_k": float(sh.cap), "zone": 0.75, "s0": 0.0, "s1": 0.15,
		"flow": -1.0, "ao_under": 0.25, "fur": 1.0 }
	var x_stop := lerpf(x0, x1, float(sh.stop))
	# el caballete del hocico, más estrecho que el labio, y la frente entre los ojos, más estrecha que los pómulos: la sección
	# se estrecha arriba (dibujo; así los ojos quedan en las esquinas de la frente, por debajo de ella)
	var bridge := float(sh.bridge)
	var brow_n := float(sh.brow_narrow)
	var x_eye := lerpf(x0, x1, float((sh.eye as Array)[0]))
	spec["warp"] = func(p: Vector3) -> Vector3:
		var k := smoothstep(x_stop - L * 0.06, x_stop + L * 0.1, p.x)
		var t := smoothstep(-0.25 * hh, 0.55 * hh, p.y)
		var g := exp(-pow((p.x - x_eye) / (L * 0.17), 2.0)) * smoothstep(0.05 * hh, 0.95 * hh, p.y)
		return Vector3(p.x, p.y, p.z * (1.0 - bridge * k * t) * (1.0 - brow_n * g))
	var pre := BodyKit.loft(spec)
	# ── los ojos: a lo separados que van las órbitas (el tigre, Mazák 1981; el oso, la frente de los machos de Siberia) ──
	var eye_cfg: Array = sh.eye
	var front := float(eye_cfg[1])
	var er := (CareAnatomy.value("tigre", "eye_mm", 37.5) * 0.5 * MM) if tiger else float(CareAnatomy.head_draw("oso", "eye_r_m", 0.0105))
	var z_eye := CareAnatomy.value(art, "interorbital_m", 0.08) * 0.5 + er
	var f_e := _fi(pre, n, float(eye_cfg[0]))
	var a_e := BodyKit.angle_at_z(pre, f_e, z_eye + er * 0.5)
	var bumps: Array = []
	var eyes_at := {}
	for s: float in [1.0, -1.0]:
		var spe: Array = BodyKit.surface_point(pre, f_e, a_e if s > 0.0 else 1.0 - a_e)
		var nrm: Vector3 = spe[1]
		# hundido: asoma la córnea y los bordes de los párpados quedan bajo la piel
		var ec: Vector3 = (spe[0] as Vector3) - nrm * er * float(eye_cfg[2])
		var gaze := (nrm * (1.0 - front) + Vector3(1.0, 0.12, 0.0) * front).normalized()
		eyes_at[s] = [ec, gaze]
		# la cuenca (la piel se aparta del ojo) y la ceja que lo cubre por arriba
		bumps.append({ "c": ec + gaze * er * 0.9, "r": er * 1.25, "amt": -er * 0.3 })
		bumps.append({ "c": ec + Vector3(-er * 0.2, er * 1.3, s * er * 0.15), "r": Vector3(er * 2.0, er * 0.65, er * 1.5), "amt": er * (0.22 if tiger else 0.2) })
		if tiger:
			# la gorguera: los pelos largos que enmarcan la cara detrás y debajo del ojo, abiertos hacia fuera
			bumps.append({ "c": Vector3(lerpf(x0, x1, 0.36), -hh * 0.3, s * hw * 0.9), "r": Vector3(L * 0.16, hh * 0.45, hw * 0.3), "amt": hw * 0.12 })
			# las almohadillas de los bigotes: dos bultos a los lados del hocico, bajo el caballete
			bumps.append({ "c": Vector3(lerpf(x0, x1, 0.85), -hh * 0.2, s * hw * 0.44), "r": Vector3(L * 0.08, hh * 0.22, hw * 0.2), "amt": hw * 0.09 })
			# el carrillo, entre el ojo y la almohadilla
			bumps.append({ "c": Vector3(lerpf(x0, x1, 0.68), -hh * 0.18, s * hw * 0.7), "r": Vector3(L * 0.08, hh * 0.25, hw * 0.2), "amt": hw * 0.035 })
		else:
			# los pómulos y el músculo de la mandíbula, anchos, detrás y debajo del ojo
			bumps.append({ "c": Vector3(lerpf(x0, x1, 0.48), -hh * 0.15, s * hw * 0.9), "r": Vector3(L * 0.14, hh * 0.4, hw * 0.28), "amt": hw * 0.07 })
			# el labio de arriba, carnoso, a los lados del hocico
			bumps.append({ "c": Vector3(lerpf(x0, x1, 0.86), -hh * 0.18, s * hw * 0.4), "r": Vector3(L * 0.1, hh * 0.16, hw * 0.16), "amt": hw * 0.03 })
	# la frente: el tigre, abombada; el oso, ancha, con el escalón de la nariz más marcado en medio
	if tiger:
		bumps.append({ "c": Vector3(lerpf(x0, x1, 0.5), hh * 0.9, 0.0), "r": Vector3(L * 0.16, hh * 0.25, hw * 0.4), "amt": hh * 0.04 })
	else:
		bumps.append({ "c": Vector3(x_stop, hh * 0.68, 0.0), "r": Vector3(L * 0.05, hh * 0.18, hw * 0.24), "amt": -hh * 0.035 })
	# la barbilla, bajo el labio de abajo
	bumps.append({ "c": Vector3(lerpf(x0, x1, 0.9), -hh * 0.62, 0.0), "r": Vector3(L * 0.06, hh * 0.14, hw * 0.24), "amt": hh * 0.04 })
	# ── la boca: el surco de la comisura hacia delante, y el labio de arriba que cae un poco sobre el de abajo ──
	var lip_uv := BodyKit.lip_line(pre, int(pre.i0), sh.lip as Array, hh)
	for s: float in [1.0, -1.0]:
		for k in lip_uv.size():
			var e: Array = lip_uv[k]
			var spl: Array = BodyKit.surface_point(pre, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1]))
			var p: Vector3 = spl[0]
			bumps.append({ "c": p, "r": Vector3(L * 0.04, hh * 0.045, hw * 0.07), "amt": -hh * 0.03 })
			if k > 0 and k < lip_uv.size() - 1:
				bumps.append({ "c": p + Vector3(0.0, hh * 0.07, 0.0), "r": Vector3(L * 0.045, hh * 0.05, hw * 0.06), "amt": hh * (0.012 if tiger else 0.022) })
	spec["bumps"] = bumps
	var skull := BodyKit.loft(spec)
	# los labios, sobre la piel ya modelada
	var lips: Array = []
	var lip_pts: Array = []
	var mouth := {}
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for e: Array in lip_uv:
			var spl: Array = BodyKit.surface_point(skull, float(e[0]), float(e[1]) if s > 0.0 else 1.0 - float(e[1]))
			pts.append((spl[0] as Vector3) + (spl[1] as Vector3) * 0.0006)
		lip_pts.append_array(pts)
		var lsp := BodyKit.spine(pts, 12 if mobile else 24)
		var lr := BodyKit.profile(lsp.size(), [[0.0, hh * 0.026], [0.3, hh * 0.03], [1.0, hh * 0.022]])
		lips.append((BodyKit.tube(lsp, lr, 6 if mobile else 8, { "cap_start": false }) as Dictionary).arrays)
		mouth[s] = pts[0]
	parts["Labios"] = { "arrays": BodyKit.merge(lips), "mat": "lips", "node": "head" }
	# ── la trufa: la piel desnuda de la punta de la nariz, con los orificios y el surco que baja al labio ──
	# el oso, grande y negra, delante y arriba del hocico; el tigre, pequeña y rosada, casi tapada por el pelo desde arriba
	# (Mazák 1981)
	var nose_k: Array = CareAnatomy.head_draw(art, "nose", [0.6, 0.4])
	var muzzle_w := 2.0 * side_e * (1.0 - bridge * 0.5)
	var n_at: Array = sh.nose_at
	var nose_r := Vector3(muzzle_w * float(n_at[2]), muzzle_w * float(nose_k[1]) * 0.5, muzzle_w * float(nose_k[0]) * 0.5)
	var nose_c := Vector3(x1 + cap_len - nose_r.x * float(n_at[0]), top_e * float(n_at[1]), 0.0)
	var nost := []
	for s: float in [1.0, -1.0]:
		nost.append({ "c": nose_c + Vector3(nose_r.x * 0.82, -nose_r.y * 0.15, s * nose_r.z * 0.52), "r": Vector3(nose_r.x * 0.45, nose_r.y * 0.32, nose_r.z * 0.24), "amt": -nose_r.x * 0.42 })
	nost.append({ "c": nose_c + Vector3(nose_r.x * 0.88, -nose_r.y * 0.85, 0.0), "r": Vector3(nose_r.x * 0.45, nose_r.y * 0.5, nose_r.z * 0.09), "amt": -nose_r.x * 0.24 })
	# la cara de arriba, que se mete bajo el pelo del caballete
	nost.append({ "c": nose_c + Vector3(-nose_r.x * 0.4, nose_r.y * 0.9, 0.0), "r": Vector3(nose_r.x * 0.8, nose_r.y * 0.5, nose_r.z * 0.9), "amt": -nose_r.y * 0.2 })
	if tiger:
		# la del tigre, un triángulo con la punta abajo: se recortan las esquinas de abajo
		for s: float in [1.0, -1.0]:
			nost.append({ "c": nose_c + Vector3(0.0, -nose_r.y * 0.9, s * nose_r.z * 0.85), "r": Vector3(nose_r.x * 1.2, nose_r.y * 0.6, nose_r.z * 0.5), "amt": -nose_r.y * 0.45 })
	parts["Trufa"] = { "arrays": BodyKit.ellipsoid(nose_c, nose_r, Basis.IDENTITY, 16 if mobile else 32, 10 if mobile else 18, { "zone": 0.0, "bumps": nost }),
		"mat": "nose", "node": "head" }
	# ── el largo del pelo: corto en el hocico, alrededor de los ojos, de la trufa y de la boca; largo en la gorguera ──
	var fk: Dictionary = sh.fur
	var va: PackedVector3Array = skull.arrays[Mesh.ARRAY_VERTEX]
	var ca: PackedColorArray = skull.arrays[Mesh.ARRAY_COLOR]
	var e_r: Vector3 = eyes_at[1.0][0]
	var e_l: Vector3 = eyes_at[-1.0][0]
	var nose_big := maxf(nose_r.y, nose_r.z)
	for k in va.size():
		var v := va[k]
		var qy := v.y / hh
		var qz := absf(v.z) / hw
		var muzzle := smoothstep(x_stop - L * 0.07, x_stop + L * 0.12, v.x)
		var f := lerpf(float(fk.face), float(fk.muzzle), muzzle)
		# la frente y la coronilla
		f = lerpf(f, float(fk.brow), smoothstep(0.35, 0.8, qy) * (1.0 - muzzle))
		# la gorguera o los carrillos: los lados de atrás y de abajo; el oso, también la nuca y la coronilla
		var ruff := smoothstep(0.55, 0.92, qz) * (1.0 - smoothstep(lerpf(x0, x1, 0.3), lerpf(x0, x1, 0.6), v.x)) * (1.0 - smoothstep(-0.05, 0.4, qy))
		if not tiger:
			ruff = maxf(ruff, (1.0 - smoothstep(lerpf(x0, x1, 0.1), lerpf(x0, x1, 0.32), v.x)))
			ruff = maxf(ruff, smoothstep(0.6, 0.95, qz) * (1.0 - smoothstep(lerpf(x0, x1, 0.32), lerpf(x0, x1, 0.55), v.x)))
		f = lerpf(f, float(fk.ruff), ruff)
		f *= smoothstep(er * 1.05, er * (2.2 if tiger else 4.2), minf(v.distance_to(e_r), v.distance_to(e_l)))
		f = minf(f, lerpf(float(fk.nose), 1.0, smoothstep(nose_big * 0.9, nose_big * 2.0, v.distance_to(nose_c))))
		var dl := INF
		for lp: Vector3 in lip_pts:
			dl = minf(dl, v.distance_to(lp))
		f *= smoothstep(hh * 0.035, hh * 0.13, dl)
		var col := ca[k]
		col.b = clampf(f, 0.0, 1.0)
		ca[k] = col
	skull.arrays[Mesh.ARRAY_COLOR] = ca
	var lk: Dictionary = LOOK.get(art, LOOK.tigre)
	parts["Cabeza"] = { "arrays": skull.arrays, "mat": "fur_head", "node": "head", "shells": 1, "fur_m": float((lk.hair as Array)[2]) * MM * 1.2 }
	# ── las orejas: redondas, de pie en lo alto hacia atrás, con el cuenco hacia delante y hacia fuera ──
	var ears: Array = []
	var e_cfg: Array = sh.ear
	var e_size := float(CareAnatomy.head_draw("tigre", "ear_m", 0.075)) if tiger else CareAnatomy.value("oso", "ear_m", 0.16) * float(CareAnatomy.head_draw("oso", "ear_show", 0.72))
	for s: float in [1.0, -1.0]:
		var spr: Array = BodyKit.surface_point(pre, _fi(pre, n, float(e_cfg[0])), float(e_cfg[1]) if s > 0.0 else 1.0 - float(e_cfg[1]))
		var pb: Vector3 = spr[0]
		var axis := ((spr[1] as Vector3) + Vector3(-0.4, 0.2, 0.0)).normalized()
		var out := Vector3(1.0, 0.0, s * float(e_cfg[2]))
		var fwd_e := (out - axis * out.dot(axis)).normalized()
		var e_pts := PackedVector3Array([pb - axis * e_size * 0.35, pb + axis * e_size * 0.3 - fwd_e * e_size * 0.05, pb + axis * e_size * 0.8 - fwd_e * e_size * 0.14])
		var esp := BodyKit.spine(e_pts, 14)
		# el pabellón redondo: ancho hasta arriba y la punta roma
		var e_w := BodyKit.profile_smooth(esp.size(), [[0.0, e_size * 0.42], [0.35, e_size * 0.5], [0.7, e_size * 0.46], [0.9, e_size * 0.32], [1.0, e_size * 0.08]])
		var e_t := BodyKit.profile_smooth(esp.size(), [[0.0, e_size * 0.22], [0.45, e_size * 0.12], [1.0, e_size * 0.06]])
		ears.append((BodyKit.loft({ "spine": esp, "up": -fwd_e, "ring": 16 if mobile else 24, "top": e_t, "bot": e_t, "sr": e_w, "sl": e_w,
			"nt": 2.0, "nb": 2.0, "cap_start": false, "cap_end": true, "cap_k": 0.8, "s0": 0.0, "s1": 1.0, "zone": 0.75,
			"bumps": [{ "c": pb + axis * e_size * 0.45 + fwd_e * e_size * 0.12, "r": Vector3.ONE * e_size * 0.32, "amt": -e_size * 0.16, "dir": -fwd_e }] }) as Dictionary).arrays)
		if rig:
			var tag := "d" if s > 0.0 else "i"
			# la oreja se aplasta hacia atrás girando en su base sobre el eje de través (el de su cuenco por su eje)
			hrig["ear_" + tag] = { "node": "ear_" + tag, "pivot": pb, "axis": axis.cross(fwd_e).normalized(), "up": axis, "fwd": fwd_e, "side": s }
	if rig:
		parts["Oreja_d"] = { "arrays": ears[0], "mat": "fur_ear", "node": "ear_d", "shells": 1, "fur_m": 0.03 }
		parts["Oreja_i"] = { "arrays": ears[1], "mat": "fur_ear", "node": "ear_i", "shells": 1, "fur_m": 0.03 }
		nodes["ear_d"] = { "parent": "head", "xf": Transform3D.IDENTITY }
		nodes["ear_i"] = { "parent": "head", "xf": Transform3D.IDENTITY }
	else:
		parts["Orejas"] = { "arrays": BodyKit.merge(ears), "mat": "fur_ear", "node": "head", "shells": 1, "fur_m": 0.03 }
	# ── los bigotes del tigre: blancos, largos y curvados hacia atrás, en filas desde las almohadillas ──
	if tiger and not mobile:
		var wh: Array = []
		# dónde sale cada bigote (estación y vuelta), una vez para los dos lados
		var roots: Array = []
		for k in 16:
			var fi := _fi(skull, n, 0.8 + 0.04 * float(k % 4) + 0.01 * (rng.next() - 0.5))
			roots.append([fi, BodyKit.angle_at_y(skull, fi, -hh * (0.1 + 0.075 * float(k / 4)))])
		var wh_side := { -1.0: [], 1.0: [] }
		var pad := { -1.0: Vector3.ZERO, 1.0: Vector3.ZERO }
		for s: float in [-1.0, 1.0]:
			for k in 16:
				var row := k / 4
				var fi := float((roots[k] as Array)[0])
				var a := float((roots[k] as Array)[1])
				var spw: Array = BodyKit.surface_point(skull, fi, a if s > 0.0 else 1.0 - a)
				var p0: Vector3 = spw[0]
				var wl := L * (0.26 + 0.16 * rng.next()) * (1.0 - 0.12 * float(row))
				var dirw := ((spw[1] as Vector3) * 0.75 + Vector3(-0.45, -0.08 - 0.07 * float(row), 0.0)).normalized()
				var w_pts := PackedVector3Array([p0 - (spw[1] as Vector3) * 0.002, p0 + dirw * wl * 0.5 + Vector3(-wl * 0.06, -wl * 0.03, 0.0), p0 + dirw * wl + Vector3(-wl * 0.2, -wl * 0.12, 0.0)])
				var wr := BodyKit.profile(8, [[0.0, 0.0009], [1.0, 0.00025]])
				var w_arr: Array = (BodyKit.tube(BodyKit.spine(w_pts, 8), wr, 5, { "cap_start": false }) as Dictionary).arrays
				wh.append(w_arr)
				(wh_side[s] as Array).append(w_arr)
				pad[s] = (pad[s] as Vector3) + p0 / 16.0
		if rig:
			# los bigotes de cada lado, en su pivote (la almohadilla): se echan hacia delante con la amenaza
			for s: float in [1.0, -1.0]:
				var tag := "d" if s > 0.0 else "i"
				parts["Bigotes_" + tag] = { "arrays": BodyKit.merge(wh_side[s]), "mat": "whisker", "node": "whisk_" + tag }
				nodes["whisk_" + tag] = { "parent": "head", "xf": Transform3D.IDENTITY }
				hrig["whisk_" + tag] = { "node": "whisk_" + tag, "pivot": pad[s], "axis": Vector3.UP, "side": s }
		else:
			parts["Bigotes"] = { "arrays": BodyKit.merge(wh), "mat": "whisker", "node": "head" }
	# ── los ojos y sus párpados (cierra el de arriba) ──
	var eyes: Array = []
	for s: float in [1.0, -1.0]:
		var ec: Vector3 = eyes_at[s][0]
		var gaze: Vector3 = eyes_at[s][1]
		var eup := (Vector3.UP - gaze * Vector3.UP.dot(gaze)).normalized()
		var exf := Transform3D(Basis(eup.cross(gaze).normalized(), eup, gaze), ec)
		var tag := "d" if s > 0.0 else "i"
		nodes["eye_" + tag] = { "parent": "head", "xf": exf }
		parts["Ojo_" + tag] = { "arrays": BodyKit.ellipsoid(Vector3.ZERO, Vector3.ONE * er, Basis(Vector3.BACK, -PI * 0.5), 20 if mobile else 32, 14 if mobile else 24), "mat": "eye", "node": "eye_" + tag }
		parts["Parpado_" + tag + "_sup"] = { "arrays": BodyKit.eyelid(er * 1.06, true, 100.0, mobile, 38.0), "mat": "lid", "node": "lid_" + tag + "_sup" }
		parts["Parpado_" + tag + "_inf"] = { "arrays": BodyKit.eyelid(er * 1.06, false, 104.0, mobile, 38.0), "mat": "lid", "node": "lid_" + tag + "_inf" }
		nodes["lid_" + tag + "_sup"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 56.0 if tiger else 46.0 }
		nodes["lid_" + tag + "_inf"] = { "parent": "eye_" + tag, "xf": Transform3D.IDENTITY, "open_deg": 18.0 if tiger else 16.0 }
		eyes.append({ "tag": tag, "r": er, "kind": "mamifero" })
	# la mascarilla: del hocico, delante de los ojos, a pasada la trufa (el hocico entero dentro, con su pelo)
	var u_m := float(sh.stop) + 0.04
	var r_m := maxf(maxf(BodyKit.sample_smooth(top_k, u_m), BodyKit.sample_smooth(bot_k, u_m)), BodyKit.sample_smooth(side_k, u_m))
	var fur_m := float((lk.hair as Array)[2]) * MM * float(fk.muzzle)
	var mask := [Vector3(lerpf(x0, x1, u_m), -hh * 0.06, 0.0), Vector3(nose_c.x + nose_r.x + L * 0.05, -hh * 0.04, 0.0), r_m * 1.12 + fur_m, L * 0.06]
	var corner: Vector3 = mouth[1.0]
	return { "parts": parts, "nodes": nodes, "eyes": eyes, "mouth": mouth, "grid": skull.grid, "mask": mask, "nose": [nose_c, nose_r], "rig": hrig,
		"eye_q": Vector3(e_r.x / (L * 0.5), e_r.y / hh, absf(e_r.z) / hw),
		"face_q": Vector3(x_stop / (L * 0.5), corner.y / hh, corner.x / (L * 0.5)) }
