## El casuario común (Casuarius casuarius) en 3D (unidad 4l), en centímetros de su anatomía: los pies en el origen, el
## pico hacia +x, la y hacia arriba y el lado de quien mira hacia +z. Proporciones (docs/fisica/coche-en-marcha.md
## §9.6.3, con sus fuentes):
##   - la pata: el tarsometatarso de ~32,5 cm (Saber & Hassanin 2014), grueso, con escudos por delante; la tibia (el
##     «muslo» de pollo) musculosa arriba, bajo el plumaje, y desnuda y escamosa abajo; el fémur, dentro del cuerpo;
##   - el pie: tres dedos hacia delante, sin dedo trasero (el I falta). El III (el del medio) es el mayor, con cuatro
##     falanges; el IV, más largo que el II, con cinco; el II, con tres y la daga: una garra casi recta de hasta 12 cm
##     (Saber & Hassanin 2014; Grzimek 2003), aquí 11 cm como el alcance del catálogo (110 mm). Los dedos son gruesos,
##     con escamas encima y almohadillas debajo que apoyan en el suelo (nada de suela plana);
##   - el plumaje: negro, lacio, como pelo (las barbas no se enganchan): un montículo más alto en la grupa cubierto de
##     mechones que caen en tejado, y las púas negras de las alas (Saber & Hassanin 2014: remeras sin barbas);
##   - el cuello desnudo, azul, con la nuca roja y las dos carúnculas rojas de la garganta; la cabeza pequeña con el pico
##     negro y el casco de queratina, alto, de canto redondeado y aplastado de lado;
##   - la hembra (más grande: la de por defecto) lleva el casco más alto, las carúnculas más largas y el azul más vivo.
## El tamaño total lo da el estado (MovingCar.BODIES: 1,6 m de alto y 1,3 m de largo): el modelo se escala entero.
## La patada (pose kick): salta echado hacia atrás, con las dos patas por delante, estiradas, los dedos abiertos y la daga
## delante. Solo dibujo.
extends RefCounted

const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Mats3D = preload("res://app/lab/animals/mats3d.gd")
const Tex3D = preload("res://app/lab/animals/tex3d.gd")

const PLUME := Color(0.062, 0.058, 0.072)
const PLUME_HI := Color(0.16, 0.17, 0.22)
const LEG := Color("#5f6a57")
const LEG_LO := Color("#3f473b")
const TOE := Color("#59634f")
const BILL := Color("#1f1b19")
const CASQUE := Color("#46362a")
const CASQUE_HI := Color("#8f7858")
const CLAW := Color("#3a3431")
const RED := Color("#d23325")
const WATTLE := Color("#c4231c")
## Articulaciones de la pata del lado de quien mira (cm; la del otro lado, con z cambiada). Tarsometatarso: del tobillo a
## la articulación de los dedos, ~32 cm (Saber & Hassanin 2014: 32,5 cm).
const HIP := Vector3(-6, 86, 10)
const KNEE := Vector3(8, 80, 11)
const ANKLE := Vector3(-4, 36, 9)
const MTP := Vector3(4, 5.8, 8.5)
const EYE := Vector3(45.5, 144.4, 3.25)
const NECK := Vector3(20, 110, 0)
const HEAD := Vector3(37, 140, 0)
## Largo de la daga (cm): el alcance de la garra del catálogo, 110 mm (Data.CLAWS «casuario»).
const DAGGER_CM := 11.0
## El montículo del plumaje, de la grupa al pecho: [x, y del eje, radio arriba, abajo, lado] (cm).
const BODY := [[-64.0, 92.0, 12.0, 16.0, 13.0], [-54.0, 97.0, 21.0, 27.0, 20.0], [-38.0, 99.0, 24.0, 32.0, 24.0], [-18.0, 97.0, 24.0, 33.0, 25.0],
	[2.0, 96.0, 22.0, 33.0, 24.0], [15.0, 98.0, 17.0, 30.0, 19.0], [24.0, 101.0, 10.0, 18.0, 13.0]]


## Colores de la piel azul: [base, claro, oscuro]; la hembra, más viva.
static func skin(female: bool) -> Array:
	if female:
		return [Color("#2f6fd2"), Color("#7fb2f3"), Color("#1c3f8a")]
	return [Color("#3a68b0"), Color("#86a6d8"), Color("#223d74")]


## El modelo (lo que se guarda en la caché): huesos, mallas, materiales, posturas y garras.
static func make(sex: String, mobile: bool, cache: Dictionary) -> Dictionary:
	var female := sex != "macho"
	var m := Rig3D.Model.new(0.0 if mobile else 1.0)
	var made := 0
	# ── materiales
	m.mats["plumaje"] = Mats3D.surface("pelo", mobile, cache, { "rough": 0.8, "spec": 0.22, "rim": 0.3, "rim_tint": 0.3, "sheen": 0.05,
		"detail_mix": 0.35, "normal_depth": 1.4 })
	m.mats["piel"] = Mats3D.surface("piel", mobile, cache)
	m.mats["queratina"] = Mats3D.surface("queratina", mobile, cache)
	m.mats["escudo"] = Mats3D.surface("escudo", mobile, cache, { "rough": 0.58 })
	m.mats["escama"] = Mats3D.surface("escama", mobile, cache, { "rough": 0.6 })
	m.mats["ojo"] = Mats3D.eye(Color("#6e3214"), { "iris_r": 0.8, "pupil_r": 0.3, "sclera": Color("#3e1c0c") })
	m.mats["garra"] = Mats3D.claw(mobile, cache)
	m.mats["flecos"] = Mats3D.cards(Tex3D.card_tex("mechon", 64 if mobile else 128, cache), { "rough": 0.45, "spec": 0.5, "rim": 0.45,
		"rim_tint": 0.35, "sheen": 0.05, "raise": 0.035, "wobble": 0.014 })
	for k: String in m.mats:
		made += int(m.mats[k].get("made", 0))
	# ── huesos: el cuerpo gira en la cadera (se echa atrás al patear); el plumaje respira en su propio hueso
	m.bone("cuerpo", "", Vector3(HIP.x, HIP.y, 0))
	m.bone("torso", "cuerpo", Vector3(HIP.x, HIP.y, 0))
	m.bone("flecos", "torso", Vector3(HIP.x, HIP.y, 0))
	m.fit_skip.append("flecos")
	m.bone("cuello", "cuerpo", NECK)
	m.bone("cabeza", "cuello", HEAD)
	for s: float in [1.0, -1.0]:
		_leg(m, s)
	_body(m)
	_neck_head(m, female)
	m.postures["de_pie"] = {}
	m.info = { "kind": "corredora", "ref_posture": "de_pie", "claw_natural": CLAW, "textures": made, "female": female }
	var data := m.finish()
	data.fit = Rig3D.posed_box(data, Rig3D.globals(data, {}), m.fit_skip)
	return data


## Una pata (s = +1 la de quien mira, −1 la otra): tibia, tarso con escudos, los tres dedos con sus falanges y las garras.
static func _leg(m: Rig3D.Model, s: float) -> void:
	var sf := "_n" if s > 0.0 else "_f"
	var hip := Vector3(HIP.x, HIP.y, HIP.z * s)
	var knee := Vector3(KNEE.x, KNEE.y, KNEE.z * s)
	var ankle := Vector3(ANKLE.x, ANKLE.y, ANKLE.z * s)
	var mtp := Vector3(MTP.x, MTP.y, MTP.z * s)
	m.bone("muslo" + sf, "cuerpo", hip)
	m.bone("tibia" + sf, "muslo" + sf, knee)
	m.bone("tarso" + sf, "tibia" + sf, ankle)
	m.bone("pie" + sf, "tarso" + sf, mtp)
	# la tibia: el músculo arriba (bajo el plumaje) y desnuda y escamosa abajo, hasta el tobillo
	var shin := func(s01: float, _u: float, _p: Vector3) -> Color: return LEG.lerp(PLUME, 1.0 - smoothstep(0.25, 0.45, s01))
	m.loft("tibia" + sf, "escama", [[knee, 8.2, 8.6, 7.6], [knee.lerp(ankle, 0.38), 7.2, 7.6, 6.6], [knee.lerp(ankle, 0.72), 5.4, 5.6, 5.0],
		[knee.lerp(ankle, 0.93), 4.7, 4.7, 4.5], [ankle, 5.0, 4.8, 4.7]], { "segs": 18, "rings": 10, "paint": shin, "tile": 3.0 })
	# el tarsometatarso (~32 cm): grueso, con los escudos por delante y la tróclea ancha abajo
	var tcol := func(_s01: float, u: float, _p: Vector3) -> Color: return LEG.lerp(LEG_LO, 0.4 * (1.0 - smoothstep(0.0, 0.3, absf(u - 0.5))))
	m.loft("tarso" + sf, "escudo", [[ankle, 4.6, 4.4, 4.4], [ankle.lerp(mtp, 0.25), 4.2, 3.9, 3.9], [ankle.lerp(mtp, 0.6), 4.1, 3.8, 3.9],
		[ankle.lerp(mtp, 0.88), 4.3, 3.8, 4.6], [mtp, 4.3, 3.6, 5.0]], { "segs": 18, "rings": 10, "paint": tcol, "tile": 2.4 })
	# los dedos: el III al frente (el mayor), el IV hacia fuera y el II hacia dentro, con la daga
	_toe(m, "III" + sf, "pie" + sf, mtp + Vector3(0.5, 0, 0), 3.0 * s, 19.0, 3.8, [0.4, 0.74], s, false)
	_toe(m, "IV" + sf, "pie" + sf, mtp + Vector3(-0.5, 0, 2.2 * s), 26.0 * s, 15.5, 3.4, [0.38, 0.72], s, false)
	_toe(m, "II" + sf, "pie" + sf, mtp + Vector3(-0.3, 0.2, -2.2 * s), -23.0 * s, 11.5, 3.5, [0.55], s, true)


## Un dedo que apoya: sale de la articulación (base, algo levantada) y baja hasta el suelo por su almohadilla; sus
## falanges (joints: fracciones del largo donde se dobla) son huesos, y en la punta, su garra (la daga en el II).
static func _toe(m: Rig3D.Model, name: String, parent: String, base: Vector3, yaw_deg: float, len: float, r: float, joints: Array, s: float,
		dagger: bool) -> void:
	var dir := Vector3(cos(deg_to_rad(yaw_deg)), 0, sin(deg_to_rad(yaw_deg)))
	var pts: Array = []
	var n := 7
	for i in n:
		var f := float(i) / float(n - 1)
		var rr := lerpf(r, r * 0.58, f)
		# la base, a la altura de la articulación; enseguida baja a apoyar la almohadilla (el centro a la altura del radio);
		# el II, algo levantado al final, que lleva la daga sin gastarla contra el suelo
		var y := lerpf(base.y, rr * 1.0 + (0.5 * f if dagger else 0.0), smoothstep(0.0, 0.32, f))
		pts.append(base + dir * (len * f) + Vector3(0, y - base.y, 0))
	var bones := [parent]
	var prev := parent
	var k := 0
	for jf: float in joints:
		var bn := "dedo%s_%d" % [name, k]
		m.bone(bn, prev, _along(pts, jf))
		bones.append(bn)
		prev = bn
		k += 1
	# cada falange, en su hueso: escamas encima y la almohadilla debajo, algo más ancha
	var cuts := [0.0] + joints + [1.0]
	var tcol := func(_s01: float, u: float, _p: Vector3) -> Color: return TOE.lerp(LEG_LO, 0.35 * (1.0 - smoothstep(0.0, 0.35, absf(u - 0.5))))
	for i in cuts.size() - 1:
		var f0: float = cuts[i]
		var f1: float = cuts[i + 1]
		var st: Array = []
		for q in 4:
			var f := lerpf(f0, f1, float(q) / 3.0)
			var rr := lerpf(r, r * 0.58, f)
			# un poco más gruesa en cada articulación
			var knuckle := 1.0 + 0.08 * cos(float(q) / 3.0 * TAU)
			st.append([_along(pts, f), rr * 0.86 * knuckle, rr * 1.0, rr * 1.12 * knuckle])
		m.loft(bones[i], "escama", st, { "segs": 12, "rings": 4, "paint": tcol, "tile": 1.6, "cap0": "round", "cap1": "round" })
	var tip: Vector3 = pts[n - 1]
	var tip_dir := ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
	var last: String = bones[bones.size() - 1]
	var far := s < 0.0
	if dagger:
		# la daga: casi recta, hacia delante y apenas hacia abajo, desde encima de la última falange
		m.claw(last, "daga" + name.substr(name.length() - 2), tip + Vector3(0, r * 0.3, 0) - tip_dir * 1.0, tip_dir + Vector3(0, 0.08, 0), Vector3.UP,
			DAGGER_CM, 2.7, 1.7, 14.0, far)
	else:
		m.claw(last, "una" + name, tip + Vector3(0, r * 0.2, 0) - tip_dir * 0.8, tip_dir + Vector3(0, 0.12, 0), Vector3.UP, 3.6, 1.9, 1.5, 40.0, far)


## Punto a una fracción f del largo de una polilínea.
static func _along(pts: Array, f: float) -> Vector3:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i + 1] as Vector3).distance_to(pts[i])
	var goal := total * clampf(f, 0.0, 1.0)
	var acc := 0.0
	for i in pts.size() - 1:
		var l := (pts[i + 1] as Vector3).distance_to(pts[i])
		if acc + l >= goal and l > 0.0:
			return (pts[i] as Vector3).lerp(pts[i + 1], (goal - acc) / l)
		acc += l
	return pts[pts.size() - 1]


## Sección del montículo en x: Vector4(y del eje, radio arriba, abajo, lado).
static func section(x: float) -> Vector4:
	for i in BODY.size() - 1:
		var a: Array = BODY[i]
		var b: Array = BODY[i + 1]
		if x >= float(a[0]) and x <= float(b[0]):
			var t := smoothstep(0.0, 1.0, (x - float(a[0])) / (float(b[0]) - float(a[0])))
			return Vector4(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t))
	var e: Array = BODY[0] if x < float(BODY[0][0]) else BODY[BODY.size() - 1]
	return Vector4(e[1], e[2], e[3], e[4])


## Punto de la superficie del montículo en x, a un ángulo th desde el dorso (0) hacia el lado s (±1) y el vientre (π):
## [punto, normal hacia fuera, tangente hacia abajo].
static func surface_at(x: float, th: float, s: float) -> Array:
	var e := section(x)
	var ry := e.y if cos(th) >= 0.0 else e.z
	var p := Vector3(x, e.x + ry * cos(th), s * e.w * sin(th))
	var nn := Vector3(0.0, cos(th) / maxf(ry, 0.1), s * sin(th) / maxf(e.w, 0.1)).normalized()
	var down := Vector3(0.0, -ry * sin(th), s * e.w * cos(th)).normalized()
	return [p, nn, down]


## El montículo del plumaje: más alto en la grupa, cubierto de mechones lacios que caen en tejado (de arriba abajo y hacia
## atrás), las púas de las alas y el cuello de plumas donde nace el cuello desnudo.
static func _body(m: Rig3D.Model) -> void:
	var st: Array = []
	for e: Array in BODY:
		st.append([Vector3(e[0], e[1], 0), e[2], e[3], e[4], 2.2])
	var plume := func(s01: float, u: float, _p: Vector3) -> Color:
		var top := smoothstep(0.25, 0.0, absf(u - 0.5))
		return Color(PLUME.lerp(PLUME_HI, 0.25 * top * smoothstep(0.1, 0.6, s01)), 0.6)
	m.loft("torso", "plumaje", st, { "segs": 26, "rings": 20, "paint": plume, "tile": 6.0, "flip_v": true, "cap_len1": 7.0 })
	# los mechones: filas desde el lomo hasta el borde de abajo, cada una tapando la base de la de debajo
	var step := 5.0 if m.detail > 0.5 else 8.5
	var rows := [0.08, 0.3, 0.52, 0.74, 0.96, 1.18, 1.4, 1.62, 1.84, 2.06] if m.detail > 0.5 else [0.12, 0.5, 0.9, 1.3, 1.7, 2.02]
	var ci := 0
	var x := -60.0
	while x <= 27.0:
		for s: float in [1.0, -1.0]:
			for r: float in rows:
				ci += 1
				var jit := sin(float(ci) * 12.9898) * 0.5
				var th: float = r + 0.06 * jit
				var xx := x + 1.8 * sin(float(ci) * 7.23)
				var srf := surface_at(xx, th, s)
				var p: Vector3 = srf[0]
				var nn: Vector3 = srf[1]
				var down: Vector3 = srf[2]
				var ax := (down + Vector3(-0.35, 0.0, 0.0)).normalized()
				var l := lerpf(13.0, 30.0, clampf(th / 2.06, 0.0, 1.0)) * (0.85 + 0.3 * absf(sin(float(ci) * 3.1)))
				var wv := nn.cross(ax).normalized() * lerpf(6.0, 8.5, absf(jit))
				var col := PLUME.lerp(PLUME_HI, 0.35 * absf(sin(float(ci) * 5.7)) * (1.0 - th / 2.0))
				_card(m, "flecos", "flecos", p - ax * 3.0 + nn * 0.4, ax * l, wv, nn, col)
		x += step
	# la pechera: mechones que cuelgan delante del pecho y tapan las rodillas
	for k in (12 if m.detail > 0.5 else 7):
		var a := deg_to_rad(lerpf(-75.0, 75.0, float(k) / (11.0 if m.detail > 0.5 else 6.0)))
		var p := Vector3(31.0 + 3.0 * cos(a), 94.0 - 6.0 * absf(sin(a)), 11.0 * sin(a))
		var nn := Vector3(0.85, -0.1, sin(a) * 0.7).normalized()
		var ax := Vector3(0.15, -1.0, sin(a) * 0.25).normalized() * 22.0
		_card(m, "flecos", "flecos", p, ax, nn.cross(ax.normalized()).normalized() * 8.0, nn, PLUME)
	# la grupa: mechones hacia atrás y abajo
	for k in 11:
		var a := deg_to_rad(lerpf(-80.0, 80.0, float(k) / 10.0))
		var e := section(-64.0)
		var p := Vector3(-66.0 - 4.0 * cos(a), e.x + 6.0 * cos(a) - 2.0, (e.w * 0.9) * sin(a))
		var nn := Vector3(-0.8, 0.25 * cos(a), sin(a) * 0.7).normalized()
		var ax := Vector3(-0.35, -1.0, sin(a) * 0.3).normalized() * 20.0
		_card(m, "flecos", "flecos", p, ax, nn.cross(ax.normalized()).normalized() * 8.0, nn, PLUME)
	# las púas de las alas: remeras sin barbas, negras y brillantes, que cuelgan del costado
	for s: float in [1.0, -1.0]:
		for k in 5:
			var base := Vector3(8.0 - 2.5 * float(k), 104.0 - 1.5 * float(k), s * (21.0 + 0.4 * float(k)))
			var dir := Vector3(-0.85, -0.5 + 0.06 * float(k), s * 0.12).normalized()
			var l := 24.0 + 3.0 * float(k % 3)
			m.loft("torso", "queratina", [[base, 0.6, 0.6, 0.5], [base + dir * l * 0.5, 0.4, 0.4, 0.33], [base + dir * l, 0.05, 0.05, 0.05]],
				{ "segs": 6, "rings": 4, "cap1": "point", "col": Color("#0e0e12") })


## Una tarjeta de mechón: base at, eje ax (largo), ancho wv, normal del cuerpo out (la luz); la punta, suelta.
static func _card(m: Rig3D.Model, b: String, mat: String, at: Vector3, ax: Vector3, wv: Vector3, out: Vector3, col: Color) -> void:
	var a := m.acc(b)
	var q := a.s(mat)
	var base := q.v.size()
	var xf := a.xf
	var nb := xf.basis.orthonormalized()
	var nn := (nb * out).normalized()
	var corners := [at - wv * 0.5, at + wv * 0.5, at + wv * 0.5 + ax, at - wv * 0.5 + ax]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var tw := (nb * wv).normalized()
	for k in 4:
		q.v.append(xf * (corners[k] as Vector3))
		q.n.append(nn)
		q.t.append_array(PackedFloat32Array([tw.x, tw.y, tw.z, 1.0]))
		q.c.append(Color(col, 0.0 if k < 2 else 1.0))
		q.uv.append(uvs[k])
		q.uv2.append(uvs[k])
	q.idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


## El cuello desnudo (azul, la nuca roja, la garganta morada), las carúnculas, la cabeza, el pico, el casco y los ojos.
static func _neck_head(m: Rig3D.Model, female: bool) -> void:
	var sk := skin(female)
	var blue: Color = sk[0]
	var neck := func(s01: float, u: float, _p: Vector3) -> Color:
		var dorsal := 1.0 - smoothstep(0.05, 0.3, absf(u - 0.5))
		var ventral := 1.0 - smoothstep(0.02, 0.22, minf(u, 1.0 - u))
		var c := blue.lerp(sk[1], 0.3 * smoothstep(0.55, 1.0, s01)).lerp(sk[2], 0.25 * (1.0 - s01))
		c = c.lerp(RED, dorsal * smoothstep(0.15, 0.45, s01) * (1.0 - smoothstep(0.8, 1.0, s01)))
		c = c.lerp(Color("#5a3ea8"), ventral * 0.5 * smoothstep(0.3, 0.8, s01))
		return c
	m.loft("cuello", "piel", [[Vector3(15, 104, 0), 7.5, 8.5, 7.5], [Vector3(21, 115, 0), 5.8, 6.4, 5.6], [Vector3(27, 125, 0), 4.9, 5.4, 4.7],
		[Vector3(32, 133, 0), 4.3, 4.7, 4.1], [Vector3(37, 139.5, 0), 4.1, 4.3, 4.0]], { "segs": 18, "rings": 12, "paint": neck, "tile": 2.2 })
	# el cuello de plumas donde el cuello desnudo sale del plumaje
	m.loft("cuello", "plumaje", [[Vector3(12, 100, 0), 10.0, 11.0, 10.5], [Vector3(18, 108, 0), 8.0, 9.0, 8.0], [Vector3(21, 113, 0), 6.6, 7.4, 6.4]],
		{ "segs": 18, "rings": 4, "col": Color(PLUME, 0.8), "tile": 4.0 })
	var collar := 16 if m.detail > 0.5 else 10
	for ring in 3:
		for k in collar:
			var a := TAU * (float(k) + 0.5 * float(ring)) / float(collar)
			var cy := 112.0 - 7.0 * float(ring)
			var rr := 7.0 + 3.2 * float(ring)
			var at := Vector3(18.0 + 1.5 * float(ring) - (4.0 + 2.0 * float(ring)) * cos(a), cy, rr * sin(a))
			var out := Vector3(-cos(a) * 0.6 + 0.3, 0.3, sin(a)).normalized()
			var ax := Vector3(-0.45 + 0.5 * cos(a), -1.0, sin(a) * 0.35).normalized() * (13.0 + 5.0 * float(ring))
			_card(m, "cuello", "flecos", at, ax, out.cross(ax.normalized()).normalized() * 6.5, out, PLUME)
	# las carúnculas rojas, que cuelgan de la garganta: dos lóbulos aplastados (la hembra, más largos)
	var drop := 15.0 if female else 10.0
	for s: float in [1.0, -1.0]:
		var top := Vector3(41.5, 131.0, 1.6 * s)
		var wat := func(s01: float, _u: float, _p: Vector3) -> Color: return WATTLE.lerp(Color("#ec4d3d"), s01 * 0.8)
		m.loft("cuello", "piel", [[top, 1.2, 1.2, 0.9], [top + Vector3(1.4, -drop * 0.35, 0.25 * s), 2.6, 2.4, 1.0],
			[top + Vector3(1.8, -drop * 0.75, 0.35 * s), 2.2, 2.0, 0.85], [top + Vector3(1.4, -drop, 0.35 * s), 0.5, 0.5, 0.4]],
			{ "segs": 12, "rings": 7, "paint": wat, "side": Vector3.BACK, "cap1": "round", "tile": 1.5 })
	# la cabeza: piel azul, pequeña, con la frente algo más clara
	var head_col := func(s01: float, u: float, _p: Vector3) -> Color:
		return blue.lerp(sk[1], 0.35 * (1.0 - smoothstep(0.05, 0.3, absf(u - 0.5))) * (1.0 - s01)).lerp(sk[2], 0.3 * (1.0 - smoothstep(0.0, 0.2, minf(u, 1.0 - u))))
	m.loft("cabeza", "piel", [[Vector3(34.0, 141.5, 0), 3.2, 3.4, 3.0], [Vector3(38.0, 143.2, 0), 4.5, 4.0, 3.6], [Vector3(43.0, 143.5, 0), 4.2, 3.6, 3.4],
		[Vector3(48.0, 142.8, 0), 3.2, 2.9, 2.6], [Vector3(51.0, 142.3, 0), 2.6, 2.4, 2.1]], { "segs": 18, "rings": 9, "paint": head_col, "tile": 1.6 })
	# el pico: negro, aplastado de lado, la punta algo curvada hacia abajo
	m.loft("cabeza", "queratina", [[Vector3(49.0, 142.5, 0), 2.6, 2.2, 2.0], [Vector3(54.0, 142.2, 0), 1.9, 1.7, 1.6], [Vector3(59.5, 141.2, 0), 1.15, 1.0, 1.0],
		[Vector3(64.0, 139.4, 0), 0.15, 0.15, 0.15]], { "segs": 12, "rings": 8, "cap1": "point", "col": BILL, "tile": 1.5 })
	# el casco: de canto (una hoja alta y estrecha) con el filo de arriba redondeado; queratina parda, más clara arriba (el
	# del macho, más bajo)
	var hk := 1.0 if female else 0.68
	var cq := func(_s01: float, _u: float, p: Vector3) -> Color: return CASQUE.lerp(CASQUE_HI, smoothstep(146.0, 146.0 + 12.0 * hk, p.y))
	var cy := 145.8
	m.loft("cabeza", "queratina", [[Vector3(49.5, cy - 0.2, 0), 1.2, 1.0, 0.9], [Vector3(47.5, cy, 0), 7.5 * hk, 1.4, 1.3],
		[Vector3(45.0, cy + 0.2, 0), 12.2 * hk, 1.5, 1.5], [Vector3(42.0, cy + 0.2, 0), 13.4 * hk, 1.5, 1.5], [Vector3(39.0, cy - 0.2, 0), 10.0 * hk, 1.5, 1.4],
		[Vector3(36.0, cy - 0.8, 0), 5.0 * hk, 1.4, 1.3], [Vector3(34.0, cy - 1.6, 0), 1.2, 1.2, 1.1]],
		{ "segs": 16, "rings": 12, "paint": cq, "tile": 2.0, "side": Vector3.FORWARD })
	# los ojos, con su párpado (un casquete de piel que se cierra al parpadear)
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var c := Vector3(EYE.x, EYE.y, EYE.z * s)
		var look := Vector3(0.3, 0.05, s).normalized()
		m.bone("ojo" + sf, "cabeza", c)
		m.loft("ojo" + sf, "ojo", [[c - look * 0.9, 0.85, 0.85, 0.85], [c, 1.25, 1.25, 1.25], [c + look * 0.5, 1.0, 1.0, 1.0]],
			{ "segs": 16, "rings": 4, "side": Vector3.UP.cross(look).normalized(), "cap0": "round", "cap1": "round" })
		m.bone("parpado" + sf, "cabeza", c)
		_lid(m, "parpado" + sf, c, look, 1.45, sk[2])
	m.anchors["eye"] = ["cabeza", Vector3(EYE.x, EYE.y, 0)]
	m.anchors["neck"] = ["cuello", NECK]
	m.anchors["hip"] = ["cuerpo", Vector3(HIP.x, HIP.y, 0)]
	m.anchors["casco"] = ["cabeza", Vector3(42.0, cy + 13.5 * hk, 0)]


## Párpado: medio casquete de piel (color col) delante del ojo; en reposo está escondido y al parpadear se abre en
## vertical (animal3d.gd, blink: los párpados se cierran desde arriba y desde abajo).
static func _lid(m: Rig3D.Model, b: String, c: Vector3, look: Vector3, r: float, col: Color) -> void:
	m.loft(b, "piel", [[c - look * 0.2, r, r, r], [c + look * r * 0.55, r * 0.84, r * 0.84, r * 0.84], [c + look * r * 0.9, r * 0.45, r * 0.45, r * 0.45],
		[c + look * r * 1.02, 0.02, 0.02, 0.02]], { "segs": 14, "rings": 4, "side": Vector3.UP.cross(look).normalized(), "cap0": "none",
		"cap1": "point", "col": col, "tile": 1.0 })


## La pose de cada fotograma (a: el animal de animal3d.gd): respiración, cabeza, parpadeo y la patada.
static func pose(a: RefCounted, p: Dictionary) -> void:
	var t: float = a.get("_t")
	var kick := clampf(float(p.get("kick", 0.0)), 0.0, 1.0)
	var breath := 1.0 + 0.008 * sin(TAU * t / 3.0)
	a.call("scale_bone", "torso", Vector3(1.0, breath, 1.0 + 0.5 * (breath - 1.0)))
	# la patada: se echa atrás en la cadera y las dos patas van por delante, estiradas (la de quien mira, más), con los
	# dedos abiertos y la daga delante; el cuello y la cabeza compensan
	var k := smoothstep(0.0, 1.0, kick)
	a.call("rot", "cuerpo", Vector3(0, 0, 0.3 * k))
	a.call("rot", "cuello", Vector3(0, 0, -0.3 * k - 0.04 * _wob(t, 0.6, 2.0)))
	a.call("rot", "cabeza", Vector3(0, 0, -0.18 * k - 0.05 * _wob(t, 0.7, 1.1)))
	for side: String in ["_n", "_f"]:
		var kk := k * (1.0 if side == "_n" else 0.85)
		a.call("rot", "muslo" + side, Vector3(0, 0, 0.45 * kk))
		a.call("rot", "tibia" + side, Vector3(0, 0, 0.1 * kk))
		a.call("rot", "tarso" + side, Vector3(0, 0, 0.95 * kk))
		a.call("rot", "pie" + side, Vector3(0, 0, -0.6 * kk))
		for toe: String in ["III", "IV", "II"]:
			a.call("rot", "dedo%s%s_0" % [toe, side], Vector3(0, 0, -0.2 * kk))
			a.call("rot", "dedo%s%s_1" % [toe, side], Vector3(0, 0, -0.15 * kk))
	a.call("show_shadow", 1.0 - k)
	a.call("blink")


static func _wob(t: float, f: float, seed: float) -> float:
	return 0.6 * sin(t * f + seed) + 0.4 * sin(t * f * 2.13 + seed * 1.7)
