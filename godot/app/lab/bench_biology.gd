## Biología de la 2.0 en el banco (bench.gd lo pinta): la herramienta inclinada con el ángulo de ataque del ensayo y la
## lupa de la punción que llega al hueso o a la cavidad del abdomen.
##
## La lupa de la punción (core/lab/art_biology.gd, a escala verdadera): aparece mientras la punta baja y, en el momento en
## que toca la piel del banco, la punta entra en la lupa, cruza las capas y topa con el hueso en PEN_MS (con el sonido del
## resultado, que suena al tocar: LabState lo programa a 0,78 × RUN_MS). Si no lo marca, rebota un pelo con un destello (un
## golpe seco); si entra, deja la muesca; si lo atraviesa, sigue por la cortical, que se agrieta, hasta la médula en
## BONE_MS; si el colmillo se rompe, la punta se queda clavada en el hueso y el resto da un respingo. En el abdomen, sin
## hueso, llega a la cavidad. Al levantar la punta (la retirada de bench.gd) sale de la lupa y queda la herida. Los ritmos
## son dibujo; las profundidades, la forma de la punta y lo que pasa, del resultado.
##
## La herramienta inclinada. El convenio es el de core/lab/attack.gd: el ángulo que forma el eje de la herramienta con la superficie, medido hacia
## donde avanza (en el banco, hacia la derecha): 90°, de punta; menos, tumbada y arrastrando, con la base por delante;
## más, «de gancho», con la base por detrás. En una uña, el de su placa.
## Los dibujos de la 1.x tienen su propio ángulo: la garra cuelga de punta (90°) y la uña de perfil sale de la losa a 35°
## con el dedo detrás de la punta (Art.nail_side_art): en este convenio, 145°, de gancho. Así que la uña con su ángulo
## por defecto de la 2.0 (45°, Attack.NAIL_DEG) se dibuja dada la vuelta, con el dedo por delante arrastrándola, y girada
## hasta su ángulo; y una garra, girada desde la vertical. Al punzar, la garra baja de punta (el ángulo solo cuenta al
## rayar: pulido-biologia.md §9.10); la uña se flexa con su ángulo también al apretar, así que se dibuja igual.
## Al empezar un ensayo, la herramienta pasa de la inclinación de la espera a la del resultado en TILT_MS (si se da la
## vuelta, se estrecha y se abre del otro lado, como una mano que gira).
## Funciones puras (sin nodos): los tests piden la inclinación de cualquier resultado.
## Uso: const BenchBiology = preload("res://app/lab/bench_biology.gd"); var t := BenchBiology.tool_tilt(res, tool, false)
extends RefCounted

const Physics = preload("res://core/lab/physics.gd")
const Attack = preload("res://core/lab/attack.gd")
const ArtBiology = preload("res://core/lab/art_biology.gd")
const BenchMaterials = preload("res://app/lab/bench_materials.gd")
const Ui = preload("res://app/common/ui.gd")

## El ángulo de ataque de los dibujos de la 1.x: la garra de punta y la uña de perfil de gancho (180° − 35°).
const CLAW_1X_DEG := 90.0
const NAIL_1X_DEG := 180.0 - BenchMaterials.NAIL_ATTACK_DEG
## Lo que tarda la herramienta en inclinarse al empezar el ensayo (dibujo).
const TILT_MS := 220.0
## La lupa de la punción (dibujo): aparece BONE_LEAD ms antes de tocar; la punta entra en su piel PEN_PRE ms antes (la
## bajada del banco acaba rapidísima), llega al hueso (o al fondo) en PEN_MS, atraviesa la cortical en BONE_MS (así acaba
## antes de que se levante la punta, a los 1150 ms) y el golpe dura HIT_MS.
const BONE_LEAD := 320.0
const PEN_PRE := 60.0
const PEN_MS := 100.0
const BONE_MS := 180.0
const HIT_MS := 160.0
## Unidades de la lupa: la punta, sobre la piel, cuando aparece; el rebote del golpe seco; el respingo del colmillo roto; y
## el trozo de punta que se queda en el hueso (una parte de la profundidad, con un mínimo: dibujo).
const HOVER := 8.0
const BOUNCE := 1.0
const RECOIL := 4.0
const FRAG := 0.1
const FRAG_MIN := 3.5
## Colores de la herida (el de los cortes), del agujero en el hueso y de la muesca.
const WOUND := Color("#7E1520")
const BONE_HOLE := Color("#2A1A10")
const BONE_INK := Color("#6B5A3E")


## Inclinación de la 1.x (el dibujo tal cual).
static func none() -> Dictionary:
	return { "sx": 1.0, "angle": 0.0, "attack": null, "lean": 0 }


## Cómo se dibuja la herramienta: { sx (1, o −1 si la uña se da la vuelta), angle (rad; positivo, horario en pantalla),
## attack (grados, o null con un resultado de la 1.x), lean (1 si la base va por delante de la punta, −1 si va por detrás,
## 0 si está de punta) }. res: el resultado (null en espera); tool: { claw, geom… }; puncture: el método; requested: el
## ángulo pedido en espera (null: el de la herramienta, Physics.attack_deg).
static func tool_tilt(res: Variant, tool: Dictionary, puncture: bool, requested: Variant = null) -> Dictionary:
	var claw: Variant = tool.get("claw")
	var att: float
	if res is Dictionary:
		if res.get("attackDeg") == null:
			return none()  # la 1.x: su dibujo
		att = float(res.attackDeg)
	else:
		att = Physics.attack_deg({ "claw": claw, "attack_deg": requested })
	if claw != null:
		if puncture:
			att = Attack.DEFAULT_DEG
		return { "sx": 1.0, "angle": deg_to_rad(CLAW_1X_DEG - att), "attack": att, "lean": _lean(att) }
	if att < 90.0:  # arrastrando: el dedo por delante de la punta (el dibujo, dado la vuelta)
		return { "sx": -1.0, "angle": deg_to_rad(BenchMaterials.NAIL_ATTACK_DEG - att), "attack": att, "lean": 1 }
	return { "sx": 1.0, "angle": deg_to_rad(NAIL_1X_DEG - att), "attack": att, "lean": _lean(att) }


static func _lean(att: float) -> int:
	if att < 90.0:
		return 1
	return -1 if att > 90.0 else 0


## La inclinación a mitad de camino (u, 0-1) entre dos: el ángulo, suavizado; si se da la vuelta, sx pasa por 0.
static func tilt_at(from: Dictionary, to: Dictionary, u: float) -> Dictionary:
	var k := clampf(u, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return {
		"sx": lerpf(float(from.sx), float(to.sx), k), "angle": lerpf(float(from.angle), float(to.angle), k), "attack": to.attack,
		"lean": to.lean,
	}


## Transformación del dibujo de la herramienta al banco: su punta (tip, en las coordenadas del dibujo) en at (unidades del
## banco), a k unidades del banco por unidad del dibujo, con la inclinación t, en píxeles (s: píxeles por unidad del banco).
static func tool_xform(at: Vector2, tip: Vector2, k: float, t: Dictionary, s: float) -> Transform2D:
	return Transform2D(float(t.angle), Vector2(float(t.sx) * k * s, k * s), 0.0, at * s) * Transform2D(0.0, Vector2.ONE, 0.0, -tip)


# ── La lupa de la punción que llega al hueso o a la cavidad ──

static func _smooth(u: float) -> float:
	var v := clampf(u, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## El guion de los materiales (BenchMaterials.plan, o {} si no había nada que animar) con la lupa de la biología
## (ArtBiology.lupa_kind), si los materiales no traen ya la suya. La de la punción que llega al hueso o a la cavidad, con
## su guion: bone = { kind, t_in (ms en que la punta entra en la piel de la lupa), hit (en que topa con el hueso o llega al
## fondo), full (en que llega al fondo), pierced, broken, marks }, y la lupa, que aparece BONE_LEAD ms antes de tocar. Las
## demás (el esmalte, el ataque, el callo) están quietas y aparecen cuando las de los materiales. Todas, lejos de la
## herramienta si se inclina hacia ellas (BenchMaterials.lupa_pos, con tool.lean).
static func with_biology(pl: Dictionary, res: Variant, tool: Dictionary, x2: float) -> Dictionary:
	var kind := ArtBiology.lupa_kind(res)
	if kind == "" or (not pl.is_empty() and pl.lupa != null):
		return pl
	var out: Dictionary = pl if not pl.is_empty() else BenchMaterials.blank(res, x2)
	var puncture: bool = out.puncture
	var pos := BenchMaterials.lupa_pos(puncture, x2, tool)
	var touch: float = out.touch
	if kind != "hueso" and kind != "cavidad":
		var at_l: float = touch + BenchMaterials.LUPA_DELAY if puncture else BenchMaterials.ms_at_eased(BenchMaterials.LUPA_E, false)
		out.lupa = { "kind": kind, "at": at_l, "pos": pos }
		out.end = maxf(float(out.end), at_l + BenchMaterials.LUPA_MS)
		if not puncture:
			out.end = minf(float(out.end), BenchMaterials.SCRATCH_MS)
		return out
	var pen: Dictionary = res.pen
	var t_in := touch - PEN_PRE
	var hit := t_in + PEN_MS
	var pierced: bool = pen.get("bonePierced") == true
	var full := hit + (BONE_MS if pierced else 0.0)
	var indent := float(pen.boneIndentUm) if pen.get("boneIndentUm") != null else 0.0
	out.lupa = { "kind": kind, "at": touch - BONE_LEAD, "pos": pos }
	out["bone"] = {
		"kind": kind, "t_in": t_in, "hit": hit, "full": full, "pierced": pierced, "broken": pen.get("toolBroken") == true,
		"marks": indent > 0.0,
	}
	out.end = maxf(float(out.end), maxf(full, hit + HIT_MS))
	return out


## Pose de la lupa de la punción a los ms del ensayo (lift: la retirada de la punta tras punzar, 0-1, la de bench.gd):
## { tip (dónde va la punta: por debajo de 0, sobre la piel, en partes de HOVER; de 0 a 1, de la superficie al hueso o, sin
## hueso, al fondo; de 1 a 2, del hueso al fondo si atraviesa la cortical), reached (lo más hondo que ha llegado, igual),
## flash (0-1, el destello del golpe en el hueso), bounce (0-1, el rebote del golpe seco), recoil (0-1, el respingo del
## colmillo roto), broken, crack (0-1, las grietas de la cortical que atraviesa), out (0-1, la punta que sale al levantarla) }.
static func bone_pose(pl: Dictionary, ms: float, lift := 0.0) -> Dictionary:
	var out := { "tip": -1.0, "reached": 0.0, "flash": 0.0, "bounce": 0.0, "recoil": 0.0, "broken": false, "crack": 0.0, "out": 0.0 }
	var b: Variant = pl.get("bone")
	if not (b is Dictionary):
		return out
	var t_in: float = b.t_in
	var hit: float = b.hit
	if ms < t_in:
		var at: float = pl.lupa.at
		out.tip = -(1.0 - _smooth((ms - at) / maxf(t_in - at, 1.0)))
	elif ms < hit:
		out.tip = (ms - t_in) / (hit - t_in)
		out.reached = out.tip
	else:
		var since := ms - hit
		var h := clampf(since / HIT_MS, 0.0, 1.0)
		out.tip = 1.0
		if bool(b.pierced):  # la cortical frena: entra cada vez más despacio hasta la médula
			var v := clampf(since / BONE_MS, 0.0, 1.0)
			out.tip = 2.0 - (1.0 - v) * (1.0 - v)
			out.crack = v
		out.reached = out.tip
		if b.kind == "hueso":
			out.flash = 1.0 - h
			if bool(b.broken):
				out.broken = true
				out.recoil = _smooth(h)
			elif not bool(b.pierced) and not bool(b.marks):
				out.bounce = sin(PI * h)
	if lift > 0.0:
		out.out = Ui.cubic_bezier(0.2, 0.8, 0.3, 1.0, clampf(lift, 0.0, 1.0))
	return out


## Profundidad bajo la piel de la lupa (unidades; negativa, por encima) de una etapa de la pose (bone_pose: tip, reached).
static func stage_depth(f: float, dyn: Dictionary) -> float:
	if f < 0.0:
		return f * HOVER
	var first: float = dyn.bone if bool(dyn.hit) else dyn.depth
	if f <= 1.0:
		return f * first
	return first + (f - 1.0) * (float(dyn.depth) - first)


## Semiancho de la punta del modelo (unidades de la lupa) a h de su extremo: casquete esférico y luego cono
## (Contact.contact_radius, con la geometría de dyn: R, at, ht, tanA).
static func tip_half_width(h: float, dyn: Dictionary) -> float:
	if h <= 0.0:
		return 0.0
	var R: float = dyn.R
	var ht: float = dyn.ht
	if h <= ht:
		return sqrt(maxf(2.0 * R * h - h * h, 0.0))
	return float(dyn.at) + (h - ht) * float(dyn.tanA)


## Semiancho de la lupa a la altura y (su círculo de radio lim, centrado).
static func _circle_half(y: float, lim: float) -> float:
	return sqrt(maxf(lim * lim - y * y, 0.0))


## Contorno de la punta cuyo extremo está a tip_d bajo la piel (ys), entre las profundidades d0 (arriba) y d1 (abajo),
## recortado al círculo de la lupa: primero el borde izquierdo de arriba abajo y luego el derecho de abajo arriba. o: el
## centro de la lupa; s: píxeles por unidad.
static func _profile(o: Vector2, ys: float, tip_d: float, d0: float, d1: float, dyn: Dictionary, lim: float, s: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var d := lerpf(d0, d1, float(i) / n)
		var y := ys + d
		var w := minf(tip_half_width(tip_d - d, dyn), _circle_half(y, lim))
		if w < 0.005:  # la punta: un solo vértice (dos iguales seguidos rompen la triangulación)
			left.append((o + Vector2(0.0, y)) * s)
			continue
		left.append((o + Vector2(-w, y)) * s)
		right.append((o + Vector2(w, y)) * s)
	right.reverse()
	left.append_array(right)
	return left


## La lupa de la punción, encima de su textura (ArtBiology.lupa_art, dyn): la herida que va abriendo la punta, lo que le
## pasa al hueso (el destello del golpe, la muesca, las grietas de la cortical, el trozo de punta clavado) y la punta, que
## nunca se sale del círculo. o: centro de la lupa (unidades del banco); bp: bone_pose; a: opacidad de la lupa; tool_col: el
## color de la herramienta; z: el aumento de la lupa (bench.gd, lupa_zoom).
static func draw_bone(ci: CanvasItem, o: Vector2, dyn: Dictionary, bp: Dictionary, a: float, s: float, tool_col: Color, z := 1.0) -> void:
	s *= z
	o /= z
	var r: float = dyn.r
	var ys: float = dyn.ys
	var lim := r * 0.97
	var reached := stage_depth(float(bp.reached), dyn)
	var tip_d := stage_depth(float(bp.tip), dyn) - BOUNCE * float(bp.bounce)
	var hit: bool = dyn.hit
	var bone_d: float = dyn.bone
	# 1 · la herida: el agujero que ha abierto la punta, de la superficie a lo más hondo (y, en el hueso, oscuro)
	if reached > 0.3:
		ci.draw_colored_polygon(_profile(o, ys, reached, 0.0, reached, dyn, lim, s), Color(WOUND, 0.92 * a))
		if hit and reached > bone_d + 0.05:
			ci.draw_colored_polygon(_profile(o, ys, reached, bone_d, reached, dyn, lim, s), Color(BONE_HOLE, 0.92 * a))
	# 2 · el hueso: la muesca de lo que entra, las grietas de la cortical que atraviesa y el trozo de punta que se queda
	var frag := 0.0
	var c := o + Vector2(0.0, ys + bone_d)
	if hit and float(bp.reached) >= 1.0:
		if float(dyn.indent) > 0.0 and not bool(dyn.pierced) and not bool(bp.broken):
			ci.draw_colored_polygon(PackedVector2Array([(c + Vector2(-1.3, 0.0)) * s, (c + Vector2(0.0, 1.2)) * s, (c + Vector2(1.3, 0.0)) * s]),
				Color(BONE_INK, a))
		if bool(dyn.pierced) and float(bp.crack) > 0.0:
			var wb := tip_half_width(reached - bone_d, dyn)
			var ce: float = dyn.boneEnd
			for i in 4:
				var side := -1.0 if i % 2 == 0 else 1.0
				var y0 := ys + bone_d + (ce - bone_d) * (0.25 + 0.35 * float(i >> 1))
				var p0 := o + Vector2(side * minf(wb, _circle_half(y0, lim)), y0)
				var p1 := p0 + Vector2(side * (2.0 + 1.5 * i), 1.0 + 0.6 * i) * float(bp.crack)
				ci.draw_line(p0 * s, p1 * s, Color(BONE_INK, 0.85 * a), maxf(1.0, 0.45 * s), true)
		if bool(bp.broken):  # la punta rota se queda clavada en el hueso, con el borde de la rotura claro
			frag = maxf(FRAG_MIN, FRAG * bone_d)
			var fp := _profile(o, ys, bone_d, bone_d - frag, bone_d, dyn, lim, s)
			if fp.size() >= 3:
				ci.draw_colored_polygon(fp, Color(tool_col, a))
				ci.draw_polyline(fp + PackedVector2Array([fp[0]]), Color(tool_col.darkened(0.6), a), maxf(1.2, 0.7 * s), true)
				var wf := tip_half_width(frag, dyn)
				var yf := ys + bone_d - frag
				ci.draw_polyline(PackedVector2Array([(o + Vector2(-wf, yf)) * s, (o + Vector2(-wf * 0.3, yf - 0.7)) * s,
					(o + Vector2(wf * 0.25, yf + 0.5)) * s, (o + Vector2(wf, yf - 0.4)) * s]), Color(1, 1, 1, 0.9 * a), maxf(1.0, 0.5 * s), true)
	# 3 · la punta: de su extremo hacia arriba hasta el borde de la lupa (sin el trozo si se ha roto), respingo y salida
	var tool_d := tip_d - RECOIL * float(bp.recoil)
	if float(bp.out) > 0.0:
		tool_d = lerpf(tool_d, -HOVER * 1.6, float(bp.out))
	var top := -sqrt(maxf(lim * lim - 1.0, 0.0)) - ys  # la profundidad (negativa) del borde de arriba de la lupa
	var low := tool_d - frag
	if low - top >= 0.4:
		var pts := _profile(o, ys, tool_d, top, low, dyn, lim, s)
		if pts.size() >= 3:
			ci.draw_colored_polygon(pts, Color(tool_col, a))
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(tool_col.darkened(0.45), a), maxf(1.0, 0.5 * s), true)
			# el brillo de un lado, para que se lea como una punta con volumen
			var hl := PackedVector2Array()
			for i in 9:
				var d := lerpf(top, low, float(i) / 8.0)
				var w := minf(tip_half_width(tool_d - d, dyn), _circle_half(ys + d, lim))
				hl.append((o + Vector2(-0.55 * w, ys + d)) * s)
			ci.draw_polyline(hl, Color(tool_col.lightened(0.5), 0.7 * a), maxf(1.0, 0.8 * s), true)
	# 4 · el golpe en el hueso: una onda que se abre desde el punto de contacto, por encima de todo
	var fl: float = bp.flash
	if hit and fl > 0.0:
		var rr := 1.5 + 5.5 * (1.0 - fl)
		ci.draw_arc(c * s, rr * s, 0.0, TAU, 32, Color(0, 0, 0, 0.45 * fl * a), maxf(2.0, 1.2 * s), true)
		ci.draw_arc(c * s, rr * s, 0.0, TAU, 32, Color(1, 1, 1, fl * a), maxf(1.0, 0.6 * s), true)
