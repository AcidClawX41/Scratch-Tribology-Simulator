## El tigre y el oso pardo en 3D (unidad 4l), en centímetros de su anatomía: el origen en el suelo, entre las manos y los
## pies; el morro hacia +x, la y hacia arriba y el lado de quien mira hacia +z. De pie en reposo; las posturas
## (agazapado, el salto) salen de colocar las articulaciones (Rig3D.Model.pose_chain), así que es el mismo animal con los
## mismos centímetros. Proporciones (docs/fisica/coche-en-marcha.md §9.6.3, con sus fuentes):
##   - tigre: 1,9 m de cabeza y tronco y ~1 m a la cruz (el tamaño del estado), la cola ~0,95 m más, como la mitad del
##     cuerpo (Mazák 1981; Sunquist & Sunquist 2002); digitígrado, pecho hondo y vientre recogido; cabeza redonda con
##     la gorguera de las mejillas, orejas redondas negras por detrás con la mancha blanca; garras retráctiles (solo
##     asoman asustado, al golpear o reforjadas), de 4 cm de alcance (Data.CLAWS «tigre»); rayas negras en su sitio: del
##     lomo hacia el vientre en los costados, en horquilla algunas; anillos en las patas por fuera y en la cola, con la
##     punta negra; blanco en el vientre, la cara interna de las patas, el hocico, las mejillas y sobre los ojos;
##   - oso pardo: 2 m de cabeza y tronco y 1,2 m a la joroba (el estado); la joroba de músculo sobre los hombros, la
##     cabeza ancha con el perfil cóncavo y las orejas pequeñas y redondas; plantígrado (apoya la planta entera del pie);
##     las garras de la mano, largas (6 cm de alcance, Data.CLAWS «oso»; 5-10 cm, Pasitschniak-Arts 1993) y poco curvas,
##     siempre fuera; el pelo largo con las puntas claras (Pasitschniak-Arts 1993).
## Solo dibujo.
extends RefCounted

const Rig3D = preload("res://app/lab/animals/rig3d.gd")
const Mats3D = preload("res://app/lab/animals/mats3d.gd")
const Tex3D = preload("res://app/lab/animals/tex3d.gd")
const Catalog = preload("res://core/lab/catalog.gd")
## El arco medido de cada garra (unidad 5g): la misma fuente que la cetrería y la galería. No precarga el catálogo.
const CareData = preload("res://core/lab/claw_care_data.gd")

const T_ORANGE := Color("#d9782a")
const T_ORANGE_HI := Color("#ee9a48")
const T_WHITE := Color("#f1ebe2")
const T_BLACK := Color("#16110d")
const B_BROWN := Color("#5a3e29")
const B_BROWN_HI := Color("#8a6848")
const B_BROWN_LO := Color("#34231a")
const B_MUZZLE := Color("#8c6c4e")
const NOSE := Color("#1a1414")
## Un trozo del mapa de las rayas que siempre está en blanco (para las piezas sin rayas: zarpas, orejas, mandíbula).
const BLANK_UV := Rect2(0.005, 0.002, 0.03, 0.006)


## Largo (cm) y arco (grados) de las garras de un animal del catálogo: el alcance (reach, mm) que usa la física y el arco
## medido de su garra (CareData.claw_arc, unidad 5g: Fowler et al. 2009 en las rapaces, el tigre medido…), el mismo que la
## cetrería y la galería (unidad 5p; antes, 180°·curva^1,6).
static func claw_of(id: String) -> Vector2:
	var c: Variant = Catalog.find_by_id(Catalog.CLAWS, id)
	if c == null:
		return Vector2(3.0, 90.0)
	return Vector2(float(c.get("reach", 30.0)) / 10.0, float(CareData.claw_arc(id).arcDeg))


## El modelo de un mamífero («tigre» u «oso»).
static func make(id: String, mobile: bool, cache: Dictionary) -> Dictionary:
	return _bear(mobile, cache) if id == "oso" else _tiger(mobile, cache)


# ════════ Ayudantes ════════

## Un tramo de pata de a a b con radios [arriba (delante), abajo (detrás), lado] en cada extremo y en medio (mids:
## [[fracción, arriba, abajo, lado]]).
static func _limb(m: Rig3D.Model, b: String, mat: String, a: Vector3, e: Vector3, ra: Array, re: Array, mids: Array, paint: Callable,
		segs := 14, rings := 6) -> void:
	var st: Array = [[a, ra[0], ra[1], ra[2]]]
	for q: Array in mids:
		st.append([a.lerp(e, float(q[0])), q[1], q[2], q[3]])
	st.append([e, re[0], re[1], re[2]])
	m.loft(b, mat, st, { "segs": segs, "rings": rings, "paint": paint, "tile": 3.0 })


## Color de una pata: por fuera, el del pelo; por dentro (hacia la línea media), claro.
static func _leg_paint(base: Color, inner: Color, zc: float, dark_low := Color(0, 0, 0, 0)) -> Callable:
	return func(s01: float, _u: float, p: Vector3) -> Color:
		var side := (p.z - zc) * signf(zc)
		var c := base.lerp(inner, clampf(-side / 4.0, 0.0, 1.0) * 0.85)
		if dark_low.a > 0.0:
			c = c.lerp(dark_low, smoothstep(0.55, 1.0, s01) * dark_low.a)
		return Color(c, 0.6)


## Una mano o un pie: la masa de la zarpa de la muñeca (w) a la punta de los dedos (toe), con los dedos marcados, y sus
## garras (n, de largo y curva claw), hacia delante y abajo. z: el centro de la pata.
static func _paw(m: Rig3D.Model, b: String, w: Vector3, toe: Vector3, width: float, h: float, col: Color, n: int, claw: Vector2, retract: bool,
		prefix: String, far: bool) -> void:
	var d := toe - w
	var fwd := Vector3(d.x, 0, 0).normalized()
	var paint := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(col, 0.35)
	m.loft(b, "pelo", [[w, h * 0.9, h * 0.9, width * 0.42], [w.lerp(toe, 0.45), h, h * 0.95, width * 0.5], [toe - fwd * width * 0.15, h * 0.85,
		h * 0.9, width * 0.5]], { "segs": 16, "rings": 6, "paint": paint, "tile": 3.0, "cap1": "round", "uv_rect": BLANK_UV })
	# los dedos: bultos delante, en abanico
	for k in n:
		var f := (float(k) + 0.5) / float(n) - 0.5
		var tz := toe.z + f * width * 0.9
		var c := Vector3(toe.x - absf(f) * width * 0.25, h * 0.62, tz)
		m.blob(b, "pelo", c, fwd, h * 0.55, h * 0.55, h * 0.62, width / float(n) * 0.52, { "paint": paint, "segs": 10, "uv_rect": BLANK_UV })
		# la garra sale de la punta del dedo, hacia delante y abajo
		var base := c + fwd * h * 0.35 + Vector3(0, h * 0.12, 0)
		m.claw(b, "%s%d" % [prefix, k], base, fwd + Vector3(0, -0.1 if not retract else 0.05, 0), Vector3.UP, claw.x * (0.8 + 0.2 * (1.0 - absf(f) * 2.0)),
			h * 0.42, h * 0.26, claw.y, far)


## La cola: una cadena de huesos a lo largo de pts, con radios que menguan de r0 a r1; paint por fracción del largo.
static func _tail(m: Rig3D.Model, parent: String, pts: Array, r0: float, r1: float, paint: Callable) -> void:
	var prev := parent
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i + 1] as Vector3).distance_to(pts[i])
	var acc := 0.0
	for i in pts.size() - 1:
		var bn := "cola%d" % i
		m.bone(bn, prev, pts[i])
		var a: Vector3 = pts[i]
		var e: Vector3 = pts[i + 1]
		var l := a.distance_to(e)
		var f0 := acc / total
		var f1 := (acc + l) / total
		var ra := lerpf(r0, r1, f0)
		var re := lerpf(r0, r1, f1)
		var seg_paint := func(s01: float, u: float, p: Vector3) -> Color: return paint.call(lerpf(f0, f1, s01), u, p)
		m.loft(bn, "pelo", [[a, ra, ra, ra], [a.lerp(e, 0.5), (ra + re) * 0.5, (ra + re) * 0.5, (ra + re) * 0.5], [e, re, re, re]],
			{ "segs": 12, "rings": 4, "paint": seg_paint, "side": Vector3.FORWARD if e.x < a.x else Vector3.BACK, "tile": 3.0,
			"cap1": "round" if i == pts.size() - 2 else "none" })
		m.fit_skip.append(bn)
		acc += l
		prev = bn


## Ojo con su párpado (el casquete que se cierra al parpadear).
static func _eye(m: Rig3D.Model, head: String, c: Vector3, look: Vector3, r: float, lid_col: Color) -> void:
	var sf := "_n" if c.z > 0.0 else "_f"
	m.bone("ojo" + sf, head, c)
	var side := Vector3.UP.cross(look).normalized()
	m.loft("ojo" + sf, "ojo", [[c - look * r * 0.7, r * 0.7, r * 0.7, r * 0.7], [c, r, r, r], [c + look * r * 0.45, r * 0.8, r * 0.8, r * 0.8]],
		{ "segs": 16, "rings": 4, "side": side })
	m.bone("parpado" + sf, head, c)
	var lr := r * 1.18
	m.loft("parpado" + sf, "pelo", [[c - look * 0.1, lr, lr, lr], [c + look * lr * 0.55, lr * 0.84, lr * 0.84, lr * 0.84], [c + look * lr * 1.02, 0.02, 0.02, 0.02]],
		{ "segs": 12, "rings": 3, "side": side, "cap0": "none", "cap1": "point", "col": Color(lid_col, 0.2), "uv_rect": BLANK_UV })


## Mechones del lomo que se levantan erizados (tarjetas en el hueso «erizado»; escondidas si no hay miedo).
static func _hackles(m: Rig3D.Model, spine: Array, len: float, col: Color, n: int) -> void:
	for k in n:
		var f := (float(k) + 0.5) / float(n)
		var i := int(f * float(spine.size() - 1))
		var t := f * float(spine.size() - 1) - float(i)
		var a: Array = spine[mini(i, spine.size() - 2)]
		var b: Array = spine[mini(i + 1, spine.size() - 1)]
		var p: Vector3 = (a[0] as Vector3).lerp(b[0], t) + Vector3(0, lerpf(float(a[1]), float(b[1]), t) - 0.8, 0)
		for s: float in [-1.0, 1.0]:
			var out := Vector3(0, 1, s * 0.35).normalized()
			var ax := (Vector3(-0.9, 0.35, s * 0.2)).normalized() * len * (0.8 + 0.4 * absf(sin(float(k) * 2.7)))
			_card(m, "erizado", "mechon", p + Vector3(0, 0, s * 1.5), ax, Vector3(0, 0, 1).cross(ax.normalized()).normalized() * len * 0.5
				if absf(ax.normalized().z) < 0.9 else Vector3(1, 0, 0) * len * 0.5, out, col)


## Una tarjeta (mechón o pluma): base at, eje ax, ancho wv, normal del cuerpo out; la punta, suelta (alfa 1).
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


# ════════ Tigre (Panthera tigris) ════════

## Rayas del tigre en el mapa de la piel (512 × 1024 en el escritorio): el tronco arriba (x alrededor, 0,5 el lomo; y de
## la grupa al cuello), la cabeza abajo a la izquierda, las patas y la cola abajo a la derecha. Negro sobre blanco: el
## color lo dan los vértices (naranja y blanco).
static func _tiger_stripes(mobile: bool, cache: Dictionary) -> ImageTexture:
	var w := 256 if mobile else 512
	var h := w * 2
	var k := float(w) / 512.0
	var b := PackedStringArray()
	var ink := Tex3D.hex(Color(0.06, 0.05, 0.05))
	# el tronco: de la grupa (y = 0) al cuello (y = 512 k); cada raya baja del lomo (x = 256 k) por los dos costados
	var n := 14
	for i in n:
		var v := (0.05 + 0.9 * (float(i) + 0.5) / float(n)) * 512.0 * k
		var reach := 0.24 + 0.08 * sin(float(i) * 2.3)
		var wd := (13.0 + 4.0 * sin(float(i) * 1.7)) * k
		for s: float in [-1.0, 1.0]:
			var top := Vector2(256.0 * k + s * 6.0 * k, v)
			var bot := Vector2(256.0 * k + s * reach * 512.0 * k, v + 18.0 * k * sin(float(i) * 0.9) + 10.0 * k)
			b.append(Tex3D.spindle(top, bot, wd, ink, 0.04 * s))
			if i % 3 == 1:
				var mid := top.lerp(bot, 0.55)
				b.append(Tex3D.spindle(mid, mid + Vector2(s * 40.0 * k, -26.0 * k), wd * 0.55, ink, 0.05))
	# las ancas: rayas curvas sobre el muslo, más horizontales
	for i in 4:
		for s: float in [-1.0, 1.0]:
			var y0 := (40.0 + 26.0 * float(i)) * k
			b.append(Tex3D.spindle(Vector2(256.0 * k + s * 90.0 * k, y0), Vector2(256.0 * k + s * 175.0 * k, y0 + 30.0 * k), 9.0 * k, ink, -0.1 * s))
	# la cabeza (0..256, 512..1024): la frente (y del cogote al hocico), las mejillas y sobre los ojos
	var hy := 512.0 * k
	for i in 4:
		var x := (128.0 + (float(i) - 1.5) * 9.0) * k
		b.append(Tex3D.spindle(Vector2(x, hy + 150.0 * k), Vector2(x + (float(i) - 1.5) * 3.0 * k, hy + 300.0 * k), 5.0 * k, ink))
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var x0 := (128.0 + s * (52.0 + 10.0 * float(i))) * k
			b.append(Tex3D.spindle(Vector2(x0, hy + (170.0 + 34.0 * float(i)) * k), Vector2(x0 + s * 30.0 * k, hy + (230.0 + 30.0 * float(i)) * k), 7.0 * k, ink, 0.1 * s))
		b.append(Tex3D.spindle(Vector2((128.0 + s * 25.0) * k, hy + 120.0 * k), Vector2((128.0 + s * 40.0) * k, hy + 250.0 * k), 6.0 * k, ink))
	# las patas (256..512, 512..768): anillos por fuera (u = 0,25 y 0,75), no en la zarpa
	for i in 7:
		var y := hy + (18.0 + 30.0 * float(i)) * k
		for c: float in [0.25, 0.75]:
			var cx := (256.0 + c * 256.0) * k
			b.append(Tex3D.spindle(Vector2(cx - 44.0 * k, y), Vector2(cx + 44.0 * k, y + 6.0 * k), 9.0 * k, ink, 0.02))
	# la cola (256..512, 768..1024): anillos enteros y la punta negra
	for i in 8:
		var y := (768.0 + 12.0 + 24.0 * float(i)) * k
		b.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\"/>" % [Tex3D._n(256.0 * k), Tex3D._n(y), Tex3D._n(256.0 * k),
			Tex3D._n(9.0 * k), ink])
	b.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\"/>" % [Tex3D._n(256.0 * k), Tex3D._n(1000.0 * k), Tex3D._n(256.0 * k),
		Tex3D._n(24.0 * k), ink])
	return Tex3D.pattern("tigre|%d" % w, w, h, "".join(b), cache)


static func _tiger(mobile: bool, cache: Dictionary) -> Dictionary:
	var m := Rig3D.Model.new(0.0 if mobile else 1.0)
	var stripes := _tiger_stripes(mobile, cache)
	m.mats["pelo"] = Mats3D.fur(mobile, cache, 0.016, 4, { "pattern": stripes, "tip": Color(1.15, 1.1, 1.04), "strand_scale": 3.5, "rim": 0.55,
		"sheen": 0.25, "normal_depth": 1.2 })
	m.mats["piel"] = Mats3D.surface("piel", mobile, cache, { "rough": 0.45 })
	m.mats["ojo"] = Mats3D.eye(Color("#d9a12e"), { "iris_r": 0.85, "pupil_r": 0.3, "sclera": Color("#b88420") })
	m.mats["garra"] = Mats3D.claw(mobile, cache)
	m.mats["diente"] = Mats3D.surface("queratina", mobile, cache, { "rough": 0.35, "spec": 0.5 })
	m.mats["mechon"] = Mats3D.cards(Tex3D.card_tex("mechon", 64 if mobile else 128, cache), { "raise": 0.03, "rough": 0.85, "spec": 0.2 })
	var made := 0
	for k: String in m.mats:
		made += int(m.mats[k].get("made", 0))
	var claw := claw_of("tigre")
	# ── el tronco: de la grupa al cuello (uv del atlas: arriba)
	var body := [[Vector3(-88, 79, 0), 11.0, 13.0, 12.0], [Vector3(-78, 81, 0), 15.0, 17.0, 15.0], [Vector3(-62, 82, 0), 15.0, 19.0, 16.0],
		[Vector3(-42, 80, 0), 14.0, 16.5, 15.0], [Vector3(-18, 78, 0), 17.0, 21.0, 17.0], [Vector3(8, 76, 0), 20.0, 25.0, 18.0],
		[Vector3(30, 78, 0), 21.0, 26.0, 17.0], [Vector3(48, 82, 0), 19.0, 22.0, 15.0], [Vector3(62, 85, 0), 15.0, 17.0, 13.0]]
	m.bone("tronco", "", Vector3(-66, 78, 0))
	m.bone("torso", "tronco", Vector3(-66, 78, 0))
	m.bone("erizado", "torso", Vector3(-66, 78, 0))
	m.fit_skip.append("erizado")
	m.bone("cuello", "tronco", Vector3(60, 85, 0))
	m.bone("cabeza", "cuello", Vector3(80, 88, 0))
	m.bone("mandibula", "cabeza", Vector3(86, 81.5, 0))
	var body_paint := func(_s01: float, u: float, _p: Vector3) -> Color:
		var belly := 1.0 - smoothstep(0.07, 0.17, minf(u, 1.0 - u))
		return Color(T_ORANGE.lerp(T_ORANGE_HI, 0.3 * (1.0 - smoothstep(0.0, 0.25, absf(u - 0.5)))).lerp(T_WHITE, belly), 0.7)
	m.loft("torso", "pelo", body, { "segs": 26, "rings": 22, "paint": body_paint, "tile": 4.0, "uv_rect": Rect2(0, 0, 1, 0.5), "flip_v": true })
	m.loft("cuello", "pelo", [[Vector3(56, 85, 0), 16.0, 18.0, 14.0], [Vector3(70, 87, 0), 13.5, 15.5, 13.0], [Vector3(82, 88, 0), 12.0, 13.5, 12.5]],
		{ "segs": 22, "rings": 6, "paint": body_paint, "tile": 4.0, "uv_rect": Rect2(0, 0.46, 1, 0.04), "flip_v": true })
	_hackles(m, body, 5.0, T_ORANGE, 14 if not mobile else 8)
	# los omóplatos y su músculo: el bulto de la cruz, a cada lado
	for s: float in [1.0, -1.0]:
		m.blob("torso", "pelo", Vector3(40, 87, 9.0 * s), Vector3(0.45, -1, 0), 13.0, 6.0, 6.0, 4.6, { "paint": body_paint, "uv_rect": Rect2(0.45, 0.47, 0.1, 0.02) })
	_tiger_head(m)
	# ── las patas: de pie en reposo
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var zf := 12.0 * s
		var sh := Vector3(46, 74, zf)
		var el := Vector3(42, 45, zf + 1.0 * s)
		var wr := Vector3(49, 13, zf)
		m.bone("hombro" + sf, "tronco", sh)
		m.bone("codo" + sf, "hombro" + sf, el)
		m.bone("muneca" + sf, "codo" + sf, wr)
		var lp := _leg_paint(T_ORANGE, T_WHITE, zf)
		var legs_uv := Rect2(0.5, 0.5, 0.5, 0.25)
		m.loft("hombro" + sf, "pelo", [[sh, 11.0, 12.0, 9.0], [sh.lerp(el, 0.5), 9.5, 9.0, 8.0], [el, 7.0, 7.5, 7.0]],
			{ "segs": 16, "rings": 6, "paint": lp, "tile": 3.0, "uv_rect": legs_uv })
		m.loft("codo" + sf, "pelo", [[el, 7.5, 8.0, 7.0], [el.lerp(wr, 0.25), 7.3, 6.5, 6.4], [el.lerp(wr, 0.7), 5.2, 4.8, 5.0], [wr, 4.4, 4.2, 4.6]],
			{ "segs": 16, "rings": 8, "paint": lp, "tile": 3.0, "uv_rect": legs_uv })
		_paw(m, "muneca" + sf, wr, Vector3(64, 3.8, zf), 11.0, 4.3, T_ORANGE.lerp(T_WHITE, 0.25), 4, claw, true, "mano" + sf, s < 0.0)
		# la pata de atrás: muslo grande, la corva alta (digitígrado) y el pie
		var hp := Vector3(-66, 76, zf)
		var kn := Vector3(-50, 50, zf + 1.0 * s)
		var hk := Vector3(-80, 25, zf)
		var ball := Vector3(-73, 5.5, zf)
		m.bone("cadera" + sf, "tronco", hp)
		m.bone("rodilla" + sf, "cadera" + sf, kn)
		m.bone("corvejon" + sf, "rodilla" + sf, hk)
		m.bone("pie" + sf, "corvejon" + sf, ball)
		m.loft("cadera" + sf, "pelo", [[hp + Vector3(-4, 4, 0), 15.0, 16.0, 11.0], [hp.lerp(kn, 0.45), 13.0, 12.0, 10.0], [kn, 7.5, 7.5, 7.5]],
			{ "segs": 16, "rings": 6, "paint": lp, "tile": 3.0, "uv_rect": legs_uv })
		m.loft("rodilla" + sf, "pelo", [[kn, 8.0, 7.5, 7.5], [kn.lerp(hk, 0.3), 7.2, 6.3, 6.3], [kn.lerp(hk, 0.85), 4.2, 4.0, 4.3], [hk, 4.4, 4.2, 4.4]],
			{ "segs": 16, "rings": 8, "paint": lp, "tile": 3.0, "uv_rect": legs_uv })
		m.loft("corvejon" + sf, "pelo", [[hk, 4.4, 4.2, 4.2], [hk.lerp(ball, 0.5), 3.8, 3.8, 4.0], [ball, 4.0, 4.0, 4.6]],
			{ "segs": 14, "rings": 6, "paint": lp, "tile": 3.0, "uv_rect": legs_uv })
		_paw(m, "pie" + sf, ball, Vector3(-60, 3.6, zf), 10.0, 4.0, T_ORANGE.lerp(T_WHITE, 0.25), 4, claw * Vector2(0.8, 1.0), true, "pie" + sf, s < 0.0)
	# ── la cola: ~0,95 m, anillada, colgando con la punta curvada
	var tail_paint := func(f: float, _u: float, _p: Vector3) -> Color: return Color(T_ORANGE.lerp(T_ORANGE_HI, 0.2 * f), 0.6)
	var tail_uv_bone := [Vector3(-88, 90, 0), Vector3(-101, 82, 0), Vector3(-111, 69, 0), Vector3(-117, 53, 0), Vector3(-119, 37, 0),
		Vector3(-117, 23, 0), Vector3(-111, 13, 0), Vector3(-104, 9, 0)]
	_tail_uv(m, "tronco", tail_uv_bone, 4.6, 2.6, tail_paint, Rect2(0.5, 0.75, 0.5, 0.25))
	# ── posturas: de pie (reposo), agazapado y el salto
	m.postures["de_pie"] = {}
	_tiger_crouch(m, "tumbado")
	_tiger_leap(m, "salto")
	m.info = { "kind": "mamifero", "ref_posture": "de_pie", "claw_natural": Color("#e8dfce"), "textures": made + 1, "retract": true }
	var data := m.finish()
	data.fit = Rig3D.posed_box(data, Rig3D.globals(data, {}), m.fit_skip)
	return data


## La cola con su trozo del atlas de rayas (uv: y a lo largo de toda la cola).
static func _tail_uv(m: Rig3D.Model, parent: String, pts: Array, r0: float, r1: float, paint: Callable, uvr: Rect2) -> void:
	var prev := parent
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i + 1] as Vector3).distance_to(pts[i])
	var acc := 0.0
	for i in pts.size() - 1:
		var bn := "cola%d" % i
		m.bone(bn, prev, pts[i])
		var a: Vector3 = pts[i]
		var e: Vector3 = pts[i + 1]
		var l := a.distance_to(e)
		var f0 := acc / total
		var f1 := (acc + l) / total
		var ra := lerpf(r0, r1, f0)
		var re := lerpf(r0, r1, f1)
		var seg_paint := func(s01: float, u: float, p: Vector3) -> Color: return paint.call(lerpf(f0, f1, s01), u, p)
		m.loft(bn, "pelo", [[a, ra, ra, ra], [a.lerp(e, 0.5), (ra + re) * 0.5, (ra + re) * 0.5, (ra + re) * 0.5], [e, re, re, re]],
			{ "segs": 12, "rings": 4, "paint": seg_paint, "tile": 3.0, "cap1": "round" if i == pts.size() - 2 else "none",
			"uv_rect": Rect2(uvr.position.x, uvr.position.y + uvr.size.y * f0, uvr.size.x, uvr.size.y * (f1 - f0)) })
		m.fit_skip.append(bn)
		acc += l
		prev = bn


## La cabeza del tigre: redonda y grande, con la gorguera de las mejillas; el hocico corto, ancho y romo, la nariz rosa;
## las orejas redondas (negras por detrás, con la mancha blanca), los ojos ámbar hacia delante, la mandíbula y los
## colmillos. Blanco en el hocico, la barbilla, las mejillas y sobre los ojos; las rayas de la frente y de las mejillas,
## en el mapa (abajo a la izquierda).
static func _tiger_head(m: Rig3D.Model) -> void:
	var head_uv := Rect2(0, 0.5, 0.5, 0.5)
	var face := func(s01: float, u: float, _p: Vector3) -> Color:
		var side := minf(u, 1.0 - u)  # 0 la barbilla · 0,25 los lados · 0,5 la frente
		var chin := 1.0 - smoothstep(0.08, 0.2, side)
		var muzzle := smoothstep(0.66, 0.8, s01) * (1.0 - smoothstep(0.34, 0.46, side))
		var cheek := smoothstep(0.3, 0.45, s01) * (1.0 - smoothstep(0.62, 0.74, s01)) * (1.0 - smoothstep(0.1, 0.24, absf(side - 0.17)))
		var brow := (1.0 - smoothstep(0.03, 0.07, absf(s01 - 0.64))) * (1.0 - smoothstep(0.02, 0.06, absf(side - 0.37)))
		var c := T_ORANGE.lerp(T_ORANGE_HI, 0.25 * smoothstep(0.3, 0.5, side))
		return Color(c.lerp(T_WHITE, clampf(chin + muzzle * 0.95 + cheek * 0.9 + brow, 0.0, 1.0)), 0.45)
	var hs := [[Vector3(74, 90, 0), 9.5, 10.5, 10.5], [Vector3(80, 92, 0), 12.0, 13.0, 14.0], [Vector3(88, 92, 0), 12.5, 13.5, 15.5],
		[Vector3(95, 90.5, 0), 10.5, 11.5, 12.5], [Vector3(101, 88, 0), 8.0, 9.5, 9.8], [Vector3(106, 86, 0), 6.4, 8.0, 8.0],
		[Vector3(110, 85, 0), 5.0, 6.5, 6.6]]
	m.loft("cabeza", "pelo", hs, { "segs": 24, "rings": 14, "paint": face, "tile": 2.2, "uv_rect": head_uv, "cap_len1": 2.6 })
	# la nariz (rosa), ancha, en la punta del hocico
	m.blob("cabeza", "piel", Vector3(111.6, 88.0, 0), Vector3(0.6, -0.8, 0), 2.6, 1.5, 1.3, 2.8, { "col": Color("#c06a64") })
	var jaw := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(T_WHITE.lerp(T_ORANGE, 0.1), 0.35)
	m.loft("mandibula", "pelo", [[Vector3(86, 80.5, 0), 5.0, 4.5, 9.5], [Vector3(98, 78.5, 0), 4.0, 3.8, 7.5], [Vector3(107, 78.5, 0), 3.0, 3.0, 5.0]],
		{ "segs": 16, "rings": 6, "paint": jaw, "tile": 2.0, "uv_rect": BLANK_UV })
	# los colmillos: arriba (en la cabeza) y abajo (en la mandíbula); se ven con la boca abierta
	for s: float in [1.0, -1.0]:
		m.tooth("cabeza", Vector3(107.5, 80.8, 2.6 * s), Vector3(0.1, -1, 0), Vector3(1, 0, 0), 4.4, 1.4, 1.1, 10.0)
		m.tooth("mandibula", Vector3(106.0, 79.5, 2.2 * s), Vector3(0.05, 1, 0), Vector3(-1, 0, 0), 3.0, 1.2, 0.9, 10.0)
	# las orejas: redondas, en lo alto; negras por detrás con la mancha blanca
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var base := Vector3(82, 102, 9.0 * s)
		m.bone("oreja" + sf, "cabeza", base)
		var ear := func(_s01: float, _u: float, p: Vector3) -> Color:
			var back := smoothstep(-0.2, -1.2, p.x - base.x)
			var spot := 1.0 - smoothstep(1.2, 2.2, Vector2(p.y - base.y - 4.5, p.z - base.z).length())
			return T_ORANGE.lerp(T_BLACK, back).lerp(T_WHITE, back * spot)
		m.loft("oreja" + sf, "pelo", [[base, 4.4, 4.4, 1.8], [base + Vector3(-0.6, 4.0, 0.6 * s), 4.2, 4.0, 1.3], [base + Vector3(-1.2, 7.4, 1.0 * s), 2.0, 1.8, 0.8]],
			{ "segs": 12, "rings": 5, "paint": ear, "side": Vector3.BACK, "tile": 2.0, "uv_rect": BLANK_UV })
	# los ojos ámbar, hacia delante, donde el hocico se junta con la frente
	for s: float in [1.0, -1.0]:
		_eye(m, "cabeza", Vector3(99.6, 93.2, 7.9 * s), Vector3(0.72, 0.08, 0.69 * s).normalized(), 1.8, T_ORANGE)
	m.anchors["eye"] = ["cabeza", Vector3(99.6, 93.2, 0)]
	m.anchors["neck"] = ["cuello", Vector3(60, 85, 0)]
	m.anchors["hip"] = ["tronco", Vector3(-66, 78, 0)]
	m.anchors["tail"] = ["cola0", Vector3(-88, 90, 0)]


## Agazapado sobre el techo (acecho): el vientre casi en la chapa, las manos delante con los codos altos, los cuartos
## traseros recogidos y la cabeza baja; la cola, tendida detrás.
static func _tiger_crouch(m: Rig3D.Model, post: String) -> void:
	m.postures[post] = { "@tronco": Vector3(0, -40, 0) }
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var z := 12.0 * s
		m.pose_chain(post, ["hombro" + sf, "codo" + sf, "muneca" + sf], [Vector3(46, 34, z), Vector3(30, 26, z), Vector3(66, 8, z), Vector3(82, 5, z)],
			Vector3(64, 3.8, z))
		m.pose_chain(post, ["cadera" + sf, "rodilla" + sf, "corvejon" + sf, "pie" + sf], [Vector3(-66, 36, z), Vector3(-44, 22, z), Vector3(-80, 9, z),
			Vector3(-60, 6, z), Vector3(-47, 4.5, z)], Vector3(-60, 3.6, z))
	m.postures[post]["cuello"] = Vector3(0, 0, -0.22)
	m.postures[post]["cabeza"] = Vector3(0, 0, 0.18)
	m.pose_chain(post, ["cola0", "cola1", "cola2", "cola3"], [Vector3(-88, 50, 0), Vector3(-104, 42, 0), Vector3(-122, 34, 0), Vector3(-140, 28, 0),
		Vector3(-157, 24, 0)], Vector3(-119, 37, 0))


## El salto sobre la chapa: el cuerpo estirado, las manos por delante con las garras fuera y las patas de atrás empujando
## (se mezcla con la postura según pose.leap).
static func _tiger_leap(m: Rig3D.Model, post: String) -> void:
	m.postures[post] = { "tronco": Vector3(0, 0, 0.1) }
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var z := 12.0 * s
		m.pose_chain(post, ["hombro" + sf, "codo" + sf, "muneca" + sf], [Vector3(46, 74, z), Vector3(66, 70, z), Vector3(100, 66, z), Vector3(114, 58, z)],
			Vector3(64, 3.8, z))
		m.pose_chain(post, ["cadera" + sf, "rodilla" + sf, "corvejon" + sf, "pie" + sf], [Vector3(-66, 76, z), Vector3(-80, 56, z), Vector3(-108, 46, z),
			Vector3(-124, 36, z), Vector3(-134, 30, z)], Vector3(-60, 3.6, z))
	m.postures[post]["cabeza"] = Vector3(0, 0, -0.1)


# ════════ Oso pardo (Ursus arctos) ════════

static func _bear(mobile: bool, cache: Dictionary) -> Dictionary:
	var m := Rig3D.Model.new(0.0 if mobile else 1.0)
	m.mats["pelo"] = Mats3D.fur(mobile, cache, 0.045, 4, { "tip": Color(1.3, 1.2, 1.08), "strand_scale": 4.0, "rough": 0.92, "rim": 0.6, "sheen": 0.3,
		"normal_depth": 1.3 })
	m.mats["piel"] = Mats3D.surface("piel", mobile, cache, { "rough": 0.4 })
	m.mats["ojo"] = Mats3D.eye(Color("#3a2414"), { "iris_r": 0.9, "pupil_r": 0.4, "sclera": Color("#2a1a10") })
	m.mats["garra"] = Mats3D.claw(mobile, cache)
	m.mats["diente"] = Mats3D.surface("queratina", mobile, cache, { "rough": 0.35, "spec": 0.5 })
	m.mats["mechon"] = Mats3D.cards(Tex3D.card_tex("mechon", 64 if mobile else 128, cache), { "raise": 0.05, "rough": 0.9, "spec": 0.15, "rim": 0.55,
		"sheen": 0.25 })
	var made := 0
	for k: String in m.mats:
		made += int(m.mats[k].get("made", 0))
	var claw := claw_of("oso")
	var fur := func(_s01: float, u: float, p: Vector3) -> Color:
		var top := 1.0 - smoothstep(0.0, 0.3, absf(u - 0.5))
		var hump := 1.0 - smoothstep(0.0, 30.0, absf(p.x - 22.0))
		return Color(B_BROWN.lerp(B_BROWN_HI, 0.45 * top * (0.5 + 0.5 * hump)).lerp(B_BROWN_LO, 0.4 * (1.0 - smoothstep(0.05, 0.25, minf(u, 1.0 - u)))), 0.85)
	# ── el tronco, macizo, con la joroba de músculo sobre los hombros
	var body := [[Vector3(-86, 80, 0), 17.0, 19.0, 19.0], [Vector3(-72, 84, 0), 22.0, 25.0, 24.0], [Vector3(-46, 83, 0), 22.0, 29.0, 27.0],
		[Vector3(-14, 82, 0), 25.0, 33.0, 29.0], [Vector3(14, 86, 0), 32.0, 33.0, 27.0], [Vector3(34, 90, 0), 27.0, 27.0, 23.0],
		[Vector3(48, 90, 0), 20.0, 20.0, 18.0]]
	m.bone("tronco", "", Vector3(-68, 78, 0))
	m.bone("torso", "tronco", Vector3(-68, 78, 0))
	m.bone("erizado", "torso", Vector3(-68, 78, 0))
	m.bone("flecos", "torso", Vector3(-68, 78, 0))
	m.fit_skip.append("erizado")
	m.fit_skip.append("flecos")
	m.bone("cuello", "tronco", Vector3(46, 90, 0))
	m.bone("cabeza", "cuello", Vector3(62, 90, 0))
	m.bone("mandibula", "cabeza", Vector3(74, 80, 0))
	m.loft("torso", "pelo", body, { "segs": 28, "rings": 22, "paint": fur, "tile": 5.0, "flip_v": true })
	m.loft("cuello", "pelo", [[Vector3(42, 90, 0), 22.0, 22.0, 19.0], [Vector3(54, 90, 0), 18.0, 18.0, 16.5], [Vector3(64, 90, 0), 15.0, 15.0, 15.0]],
		{ "segs": 22, "rings": 6, "paint": fur, "tile": 4.0 })
	_hackles(m, body, 9.0, B_BROWN_HI, 18 if not mobile else 9)
	# flecos: el pelo largo y desgreñado que cuelga del vientre y de los costados, en la superficie del tronco
	var fx := 7.0 if not mobile else 12.0
	var x := -74.0
	var ci := 0
	while x <= 34.0:
		for s: float in [1.0, -1.0]:
			for th: float in [2.15, 2.5, 2.8]:
				ci += 1
				var srf := Rig3D.surface_of(body, x + 2.0 * sin(float(ci) * 7.1), th + 0.05 * sin(float(ci) * 3.3), s)
				var pp: Vector3 = srf[0]
				var nn: Vector3 = srf[1]
				var ax := (Vector3(-0.25, -1.0, 0.0) + nn * 0.3).normalized() * (9.0 + 5.0 * absf(sin(float(ci) * 2.3)))
				_card(m, "flecos", "mechon", pp - ax * 0.25, ax, nn.cross(ax.normalized()).normalized() * 8.0, nn, B_BROWN_LO.lerp(B_BROWN, 0.6 * absf(sin(float(ci)))))
		x += fx
	_bear_head(m)
	# ── las patas: columnas gruesas; las manos con las garras largas, y los pies plantígrados
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var zf := 16.0 * s
		var sh := Vector3(30, 72, zf)
		var el := Vector3(25, 42, zf + 1.0 * s)
		var wr := Vector3(31, 11, zf)
		m.bone("hombro" + sf, "tronco", sh)
		m.bone("codo" + sf, "hombro" + sf, el)
		m.bone("muneca" + sf, "codo" + sf, wr)
		var lp := _leg_paint(B_BROWN, B_BROWN_LO, zf, Color(B_BROWN_LO, 0.7))
		m.loft("hombro" + sf, "pelo", [[sh, 18.0, 18.0, 14.0], [sh.lerp(el, 0.5), 14.5, 14.5, 12.5], [el, 11.5, 12.0, 11.0]],
			{ "segs": 18, "rings": 6, "paint": lp, "tile": 3.5 })
		m.loft("codo" + sf, "pelo", [[el, 12.0, 12.5, 11.0], [el.lerp(wr, 0.35), 11.0, 10.0, 10.0], [el.lerp(wr, 0.8), 9.0, 8.5, 9.0], [wr, 8.0, 7.8, 9.0]],
			{ "segs": 18, "rings": 8, "paint": lp, "tile": 3.5 })
		_paw(m, "muneca" + sf, wr, Vector3(50, 5.6, zf), 18.0, 6.2, B_BROWN_LO, 5, claw, false, "mano" + sf, s < 0.0)
		var hp := Vector3(-66, 74, zf)
		var kn := Vector3(-54, 46, zf + 1.0 * s)
		var an := Vector3(-78, 13, zf)
		m.bone("cadera" + sf, "tronco", hp)
		m.bone("rodilla" + sf, "cadera" + sf, kn)
		m.bone("tobillo" + sf, "rodilla" + sf, an)
		m.loft("cadera" + sf, "pelo", [[hp + Vector3(-4, 6, 0), 21.0, 21.0, 16.0], [hp.lerp(kn, 0.5), 17.0, 16.0, 14.0], [kn, 12.0, 12.0, 11.0]],
			{ "segs": 18, "rings": 6, "paint": lp, "tile": 3.5 })
		m.loft("rodilla" + sf, "pelo", [[kn, 12.5, 12.0, 11.0], [kn.lerp(an, 0.4), 10.5, 9.5, 9.5], [an, 8.5, 8.5, 8.5]],
			{ "segs": 18, "rings": 8, "paint": lp, "tile": 3.5 })
		# el pie plantígrado: la planta entera en el suelo, del talón a los dedos
		_paw(m, "tobillo" + sf, Vector3(-86, 6.0, zf), Vector3(-55, 5.6, zf), 16.0, 6.0, B_BROWN_LO, 5, claw * Vector2(0.5, 0.8), false, "pie" + sf, s < 0.0)
	# ── la cola, corta
	_tail(m, "tronco", [Vector3(-100, 88, 0), Vector3(-106, 84, 0), Vector3(-109, 79, 0)], 5.5, 4.0, func(_f: float, _u: float, _p: Vector3) -> Color:
		return Color(B_BROWN, 0.9))
	m.postures["de_pie"] = {}
	_bear_lie(m, "tumbado")
	_bear_strike(m, "salto")
	m.info = { "kind": "mamifero", "ref_posture": "de_pie", "claw_natural": Color("#cdbfa6"), "textures": made, "retract": false }
	var data := m.finish()
	data.fit = Rig3D.posed_box(data, Rig3D.globals(data, {}), m.fit_skip)
	return data


## La cabeza del oso: ancha y redonda, con el perfil cóncavo entre la frente y el hocico; el hocico largo pero ancho y
## más claro, la nariz negra, las orejas pequeñas y redondas en lo alto y los ojos pequeños.
static func _bear_head(m: Rig3D.Model) -> void:
	var face := func(s01: float, u: float, _p: Vector3) -> Color:
		var c := B_BROWN.lerp(B_BROWN_HI, 0.35 * (1.0 - smoothstep(0.0, 0.3, absf(u - 0.5))) * (1.0 - s01))
		return Color(c.lerp(B_MUZZLE, smoothstep(0.58, 0.8, s01)), 0.6)
	m.loft("cabeza", "pelo", [[Vector3(60, 91, 0), 14.0, 14.0, 15.0], [Vector3(69, 93, 0), 14.5, 13.5, 16.5], [Vector3(77, 93.5, 0), 13.0, 12.0, 15.0],
		[Vector3(84, 89.5, 0), 9.0, 10.0, 10.5], [Vector3(91, 86.5, 0), 7.2, 8.0, 7.8], [Vector3(97, 84.5, 0), 6.0, 6.6, 6.4], [Vector3(101, 84, 0), 4.6, 5.2, 5.2]],
		{ "segs": 24, "rings": 14, "paint": face, "tile": 2.5, "cap_len1": 2.6 })
	m.blob("cabeza", "piel", Vector3(102.6, 86.0, 0), Vector3(0.7, -0.6, 0), 3.4, 2.4, 2.0, 3.2, { "col": NOSE })
	var jaw := func(_s01: float, _u: float, _p: Vector3) -> Color: return Color(B_MUZZLE.lerp(B_BROWN, 0.3), 0.5)
	m.loft("mandibula", "pelo", [[Vector3(74, 80, 0), 6.0, 5.5, 10.5], [Vector3(88, 78, 0), 4.6, 4.2, 7.0], [Vector3(98, 78.5, 0), 3.2, 3.2, 4.8]],
		{ "segs": 16, "rings": 6, "paint": jaw, "tile": 2.0 })
	for s: float in [1.0, -1.0]:
		m.tooth("cabeza", Vector3(98.0, 80.0, 2.6 * s), Vector3(0.1, -1, 0), Vector3(1, 0, 0), 3.4, 1.3, 1.0, 10.0)
		m.tooth("mandibula", Vector3(97.0, 79.2, 2.2 * s), Vector3(0.05, 1, 0), Vector3(-1, 0, 0), 2.6, 1.1, 0.9, 10.0)
		var sf := "_n" if s > 0.0 else "_f"
		var base := Vector3(68, 105, 11.0 * s)
		m.bone("oreja" + sf, "cabeza", base)
		m.loft("oreja" + sf, "pelo", [[base, 3.8, 3.8, 2.2], [base + Vector3(-0.4, 3.4, 0.6 * s), 3.6, 3.4, 1.8], [base + Vector3(-0.6, 5.6, 0.9 * s), 1.8, 1.6, 1.1]],
			{ "segs": 12, "rings": 4, "col": Color(B_BROWN_LO, 0.8), "side": Vector3.BACK, "tile": 2.0 })
		_eye(m, "cabeza", Vector3(83.0, 95.0, 7.6 * s), Vector3(0.62, 0.08, 0.78 * s).normalized(), 1.3, B_BROWN)
	m.anchors["eye"] = ["cabeza", Vector3(83.0, 95.0, 0)]
	m.anchors["neck"] = ["cuello", Vector3(46, 90, 0)]
	m.anchors["hip"] = ["tronco", Vector3(-68, 78, 0)]


## Tumbado sobre el techo: el vientre en la chapa, las manos delante, los pies atrás con las plantas a la vista y la cabeza
## levantada.
static func _bear_lie(m: Rig3D.Model, post: String) -> void:
	m.postures[post] = { "@tronco": Vector3(0, -37, 0) }
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var z := 16.0 * s
		m.pose_chain(post, ["hombro" + sf, "codo" + sf, "muneca" + sf], [Vector3(30, 35, z), Vector3(42, 30, z), Vector3(80, 13, z), Vector3(100, 9, z)],
			Vector3(50, 5.6, z))
		m.pose_chain(post, ["cadera" + sf, "rodilla" + sf, "tobillo" + sf], [Vector3(-66, 37, z), Vector3(-72, 42, z), Vector3(-112, 24, z),
			Vector3(-138, 29, z)], Vector3(-55, 5.6, z))
	m.postures[post]["cuello"] = Vector3(0, 0, -0.1)
	m.postures[post]["cabeza"] = Vector3(0, 0, 0.18)


## El golpe: se alza sobre las patas de atrás y descarga las manos por delante, con las garras.
static func _bear_strike(m: Rig3D.Model, post: String) -> void:
	m.postures[post] = { "tronco": Vector3(0, 0, 0.26) }
	for s: float in [1.0, -1.0]:
		var sf := "_n" if s > 0.0 else "_f"
		var z := 16.0 * s
		m.pose_chain(post, ["hombro" + sf, "codo" + sf, "muneca" + sf], [Vector3(26, 102, z), Vector3(48, 106, z), Vector3(80, 92, z), Vector3(94, 80, z)],
			Vector3(50, 5.6, z))
	m.postures[post]["cabeza"] = Vector3(0, 0, -0.22)


## La pose de cada fotograma: respiración, la cola, la cabeza, el miedo (orejas atrás, boca abierta, pelo erizado,
## temblor) y el salto o el golpe (pose.leap, mezclado con la postura).
static func pose(a: RefCounted, p: Dictionary) -> void:
	var t: float = a.get("_t")
	var scared := clampf(float(p.get("scared", 0.0)), 0.0, 1.0)
	var leap := smoothstep(0.0, 1.0, clampf(float(p.get("leap", 0.0)), 0.0, 1.0))
	var br := 1.0 + (0.01 + 0.008 * scared) * sin(TAU * t / (3.4 - 1.6 * scared))
	a.call("scale_bone", "torso", Vector3(1.0, br, 1.0 + 0.5 * (br - 1.0)))
	a.call("blend_post", "salto", leap)
	var sw := 0.10 * sin(t * 1.3) + 0.25 * scared * sin(t * 6.0)
	for i in 7:
		a.call("rot_add", "cola%d" % i, Vector3(0, sw * 0.4, sw * (0.3 + 0.1 * float(i)) + 0.05 * sin(t * 2.1 + float(i))))
	a.call("rot_add", "cabeza", Vector3(0, 0.05 * _wob(t, 0.5, 0.4), -0.035 * _wob(t, 0.4, 1.3)))
	a.call("rot_add", "mandibula", Vector3(0, 0, -0.42 * scared))
	for s: String in ["_n", "_f"]:
		a.call("rot_add", "oreja" + s, Vector3(0, 0, 0.9 * scared))
	a.call("show_bone", "erizado", scared > 0.02 or float(p.get("bristle", 0.0)) > 0.02)
	a.call("show_shadow", 1.0 - leap)
	a.call("blink")


static func _wob(t: float, f: float, seed: float) -> float:
	return 0.6 * sin(t * f + seed) + 0.4 * sin(t * f * 2.13 + seed * 1.7)
