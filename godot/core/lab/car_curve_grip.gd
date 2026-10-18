## Tribología biológica · coche en marcha en curva: el animal se agarra, se recoloca y puede caerse (modelo 2.0, unidad 4u,
## petición de Eric del 18-10: «si el coche en movimiento gira y zarandea, los animales tendrán que tener sus animaciones y
## movimientos, pudiendo dejar todavía más garras y marcas en el coche, intentándose agarrar para no caerse, y si pillas una
## curva cerrada muy rápida, este puede desequilibrarse y caer del coche también»).
##
## Va encima de la 4t (CarCurve: el equilibrio cuasiestático en la curva, at_speed y at_lateral, y el despegue, detach) y de
## la 4s (las marcas del motor de siempre, MovingCar._marks, capa a capa). No calcula equilibrio propio:
##   1. Lo cerca que está del límite: u = fuerza necesaria / fuerza que dan sus garras (loadRatio de at_speed). Con u ≥ 1 no
##      aguanta: se cae, y eso lo dice el mismo equilibrio que el despegue (detach), nunca otro criterio.
##   2. Recolocarse: cuando u pasa de SLIP_FROM (o la fuerza cambia de lado en la S y la del lado nuevo pasa de FLIP_FROM),
##      una o más garras del lado cargado resbalan SLIP_MM y vuelven a clavarse (suposición de juego: no hay medición
##      publicada de una garra que resbala por la pintura de un coche y se vuelve a clavar). Cada resbalón es un surco en la
##      dirección de la fuerza en el contacto (CarCurve.mark_deg, hacia fuera de la curva) con la fuerza de esa garra: las del
##      lado de fuera cargan más de la normal (CarCurve.side_shares) y tiran de su parte de la fuerza necesaria (CLAW_HOOK de
##      la 4s). Qué capas corta lo dice el motor de siempre (MovingCar._marks y CarTear), según el material de la garra.
##   3. Caerse: si no aguanta, resbala hacia fuera con todas sus garras arañando (FALL_SLIDE_MM, hasta el borde del panel:
##      juego), intenta agarrarse y cae por el lado de fuera (el dibujo es de la vista, determinista; no hay física de vuelo).
## Funciones puras, estáticas y deterministas; sin nodos (CONTRATOS.md). En recta (sin aceleración lateral) no hay nada:
## todo devuelve vacío y no se llama a nada más. Guía: docs/fisica/coche-en-marcha.md (§20, la 4u).
## Uso: const CarCurveGrip = preload("res://core/lab/car_curve_grip.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CarCurve = preload("res://core/lab/car_curve.gd")
const CarTear = preload("res://core/lab/car_tear.gd")
const CarFormat = preload("res://core/lab/car_format.gd")

const SRC_GAME := "suposición de juego: no hay medición publicada de un animal que se recoloca agarrado al techo de un coche en curva"

## Desde qué parte de su agarre (u = necesaria / disponible) empiezan a resbalar las garras del lado cargado y vuelven a
## clavarse.
const SLIP_FROM := { "value": 0.8, "min": 0.7, "max": 0.9, "quality": "estimate", "source": SRC_GAME + "; el caso medido más parecido: una garra enganchada aguanta hasta que la carga se acerca a su tope y entonces resbala de un punto de agarre al siguiente (Dai, Gorb y Schwarz 2002, J. Exp. Biol. 205:2479-2488); se toma el 80 % del agarre (del 70 al 90 %)" }
## En la S, al cambiar de lado: desde qué parte del agarre del lado nuevo se recolocan sus garras.
const FLIP_FROM := { "value": 0.55, "min": 0.4, "max": 0.7, "quality": "estimate", "source": SRC_GAME + "; al cambiar de lado la carga pasa a las garras del otro lado, que se recolocan antes de llegar al tope (del 40 al 70 % del agarre)" }
## Lo que resbala cada garra antes de volver a clavarse (mm): de la mitad al todo, según lo que pasa del umbral.
const SLIP_MM := { "value": 15.0, "min": 6.0, "max": 30.0, "quality": "estimate", "source": SRC_GAME + "; del orden del paso de la pata de un gato o de una rapaz al recolocarla (1-3 cm)" }
## Lo que resbala hacia fuera al caerse, arañando con todas las garras, hasta el borde del panel (mm).
const FALL_SLIDE_MM := { "value": 300.0, "min": 150.0, "max": 600.0, "quality": "estimate", "source": SRC_GAME + "; hasta el borde del techo o del capó por el lado de fuera (medio ancho de un techo de turismo, ~0,5-0,6 m)" }
## Solo dibujo: desde qué parte de su agarre se le nota el esfuerzo (la animación de cada especie).
const REACT_FROM := { "value": 0.35, "quality": "dibujo", "source": "solo dibujo: desde qué parte del agarre se le ve agarrarse con más fuerza; la física es la del equilibrio de siempre" }

## Tipos de recolocación en la S.
const KIND_SLIP := "resbala"
const KIND_FLIP := "cambio"
const KIND_FALL := "cae"
## Muestras de la S para buscar los instantes (s_events).
const S_SAMPLES := 97
## Solo dibujo: el miedo del animal (lo que se le nota que lucha por no soltarse, 0-1). Sale de lo cerca que está de soltarse
## (u, desde FEAR.from) y de lo deprisa que cambia la fuerza (el tirón de la S, jerk, hasta FEAR.jerk_ref m/s³, que añade
## hasta FEAR.jerk_k). No es una magnitud medida: es para la animación de cada especie.
const FEAR := { "from": 0.2, "jerk_ref": 3.0, "jerk_k": 0.35, "quality": "dibujo", "source": "solo dibujo: lo que el animal lucha por no soltarse sale del margen de su agarre (la física de siempre) y del tirón de la S; no es una magnitud medida" }


# ════════ Lo cerca del límite ════════

## Lo que le pide la curva de su agarre (u = necesaria / disponible: el loadRatio de at_speed). INF si no le queda agarre.
static func usage(a: Dictionary) -> float:
	var r: Variant = a.get("loadRatio", 0.0)
	return float(r) if r != null else 0.0


## Cuánto se le nota el esfuerzo (0-1, dibujo): de REACT_FROM a su tope.
static func effort(u: float) -> float:
	var f := float(REACT_FROM.value)
	if is_inf(u) or is_nan(u):
		return 1.0 if not is_nan(u) else 0.0
	return clampf((u - f) / (1.0 - f), 0.0, 1.0)


## El miedo del animal (0-1, dibujo, FEAR): 0 tranquilo (lejos de soltarse y sin tirones), 1 a punto de soltarse. u: lo que
## le pide la curva de su agarre (usage); jerk_ms3: el tirón de ahora (m/s³; el de la S, CarCurve.s_at), que solo asusta si ya
## está cargado. Nunca baja si sube u o el tirón. Sin agarre (u INF, o ≥ 1), 1.
static func fear(u: float, jerk_ms3: float = 0.0) -> float:
	if is_nan(u):
		return 0.0
	if is_inf(u) or u >= 1.0:
		return 1.0
	var f := float(FEAR.from)
	var base := clampf((u - f) / (1.0 - f), 0.0, 1.0)
	var j := clampf(absf(jerk_ms3) / float(FEAR.jerk_ref), 0.0, 1.0) * float(FEAR.jerk_k) * clampf(u / f, 0.0, 1.0)
	return clampf(base + j * (1.0 - base), 0.0, 1.0)


## La fracción de lo que pasa del umbral (0-1): de from a su tope.
static func _over(u: float, from: float) -> float:
	if u < from:
		return 0.0
	return clampf((u - from) / (1.0 - from), 0.0, 1.0)


## Cuántas garras resbalan y vuelven a clavarse con u: ninguna por debajo de SLIP_FROM; de una a todas las del lado cargado
## (la mitad, redondeando hacia arriba) según lo que pasa del umbral. Nunca baja si sube u. n: las que agarran.
static func slip_count(u: float, n: int) -> int:
	return _count(u, n, float(SLIP_FROM.value))


## Cuántas garras del lado nuevo se recolocan al cambiar de lado en la S (con la u del lado nuevo).
static func flip_count(u: float, n: int) -> int:
	return _count(u, n, float(FLIP_FROM.value))


static func _count(u: float, n: int, from: float) -> int:
	if n <= 0 or not (u >= from):
		return 0
	var side_n := ceili(float(n) / 2.0)
	return clampi(ceili(float(side_n) * _over(u, from)), 1, side_n)


## Lo que resbala cada garra (mm) con u: de la mitad de SLIP_MM (en el umbral) a todo (en el tope).
static func slip_len_mm(u: float) -> float:
	return float(SLIP_MM.value) * (0.5 + 0.5 * _over(u, float(SLIP_FROM.value)))


## La fuerza en la punta de una garra del lado cargado (N): la normal que le toca con el reparto entre lados (las de fuera,
## 2·share de la media) y su parte de la fuerza necesaria a lo largo del panel (CLAW_HOOK de la 4s: por igual entre las que
## agarran); la punta toma la resultante. Asustado, aprieta al menos con su defensa. a: at_speed o at_lateral (con curve).
static func claw_force(scen: Dictionary, a: Dictionary) -> float:
	var h: Dictionary = scen.holdCtx
	var n := float(maxi(int(h.nContact), 1))
	var c: Dictionary = a.get("curve", {})
	var share := 0.5
	if not c.is_empty():
		var sh: Dictionary = c.shares
		share = maxf(float(sh.right), float(sh.left))
	var press := maxf(float(a.normalN), 0.0) / n
	var dpc: Variant = h.get("defPerClaw")
	if dpc != null:
		press = maxf(press, float(dpc.value))
	var press_out := press * 2.0 * share
	var tang := maxf(float(a.needN), 0.0) / n
	return sqrt(press_out * press_out + tang * tang)


## El surco de una garra que resbala len_mm con la fuerza force_n en la punta: el motor de siempre (MovingCar._marks, el de
## la 4s: hondura, ancho, capas, si llega a la chapa o la atraviesa). { depthUm, residualUm, verdict, layers, reachesBody,
## through, widthUm, fab, … } (el resumen de _scratch_summary).
static func slip_marks(scen: Dictionary, force_n: float, len_mm: float) -> Dictionary:
	var h: Dictionary = scen.holdCtx
	var mk := MovingCar._marks(h.claw, h.target, bool(h.glass), force_n, len_mm, h.model, h.inlay, h.get("defPerClaw") != null,
		float(h.tipRoom))
	return mk.summary


# ════════ En una curva quieta ════════

## Lo que hace el animal en la curva con unas fuerzas a (CarCurve.at_speed o at_lateral, con su campo curve): { u, effort,
## holds, side (+1 empuja a la derecha), deg (hacia dónde resbala: grados desde «hacia atrás», + a la derecha), claws (las que
## agarran), slips (las que resbalan y vuelven a clavarse), lenMm, tipN, marks (el surco de cada resbalón; {} sin
## resbalones), falls (no aguanta: se cae), sideways (por el lado de fuera: el modo «lado»; si no, se va hacia atrás como en
## recta), mode, fallMm, fallMarks ({} si no se cae), quality, source }. {} en recta (sin aceleración lateral) o sin animal.
static func at(scen: Dictionary, a: Dictionary) -> Dictionary:
	if scen.is_empty() or not Js.truthy(scen.get("ok")) or not scen.has("holdCtx") or a.is_empty() or not a.has("curve"):
		return {}
	var c: Dictionary = a.curve
	if absf(float(c.latMs2)) <= 0.0:
		return {}
	var h: Dictionary = scen.holdCtx
	var n := int(h.nContact)
	var u := usage(a)
	var holds := bool(a.holds)
	var out := {
		"u": u, "effort": effort(u), "holds": holds, "side": float(c.side), "deg": float(c.markDeg), "claws": n, "slips": 0,
		"lenMm": 0.0, "tipN": 0.0, "marks": {}, "falls": not holds, "sideways": not holds and String(a.mode) == "lado",
		"mode": String(a.mode), "fallMm": 0.0, "fallMarks": {}, "quality": String(SLIP_FROM.quality), "source": String(SLIP_FROM.source),
	}
	var f := claw_force(scen, a)
	out.tipN = f
	if holds:
		var k := slip_count(u, n)
		if k > 0:
			out.slips = k
			out.lenMm = slip_len_mm(u)
			out.marks = slip_marks(scen, f, float(out.lenMm))
	else:
		out.slips = n
		out.lenMm = float(FALL_SLIDE_MM.value)
		out.fallMm = float(FALL_SLIDE_MM.value)
		out.fallMarks = slip_marks(scen, f, float(FALL_SLIDE_MM.value))
		out.marks = out.fallMarks
	return out


# ════════ En la S ════════

## Los momentos de la S en los que el animal se recoloca o se cae, con el coche a v_kmh (rd: CarCurve.road; grip_g: el tope
## del coche): { events: [{ tS, kind («resbala», «cambio» o «cae»), side, claws, lenMm, tipN, deg, u, marks }], peak
## ({ right, left }: la u más alta de cada lado), falls, fallT (s, INF si no se cae), durationS }. Cada lado: «resbala» cuando
## su u pasa de SLIP_FROM; al cambiar de lado, «cambio» si la u del lado nuevo pasa de FLIP_FROM; «cae» la primera vez que no
## aguanta (y ya no hay más). El surco de cada uno, con la fuerza del pico de su lado (un compute() por lado, y otro si se
## cae). {} parado o sin animal. Para cuando cambian la velocidad, el radio o el ensayo, nunca en cada fotograma.
static func s_events(scen: Dictionary, rd: Dictionary, v_kmh: float, grip_g: float, n_samples: int = S_SAMPLES) -> Dictionary:
	if scen.is_empty() or not Js.truthy(scen.get("ok")) or not scen.has("holdCtx") or v_kmh < CarCurve.REST_KMH:
		return {}
	var dur := CarCurve.s_duration(rd, v_kmh)
	if not is_finite(dur):
		return {}
	var r_m := float(rd.rM)
	var n := int(scen.holdCtx.nContact)
	var count := maxi(n_samples, 3)
	var peak := { 1.0: 0.0, -1.0: 0.0 }
	var peak_a := { 1.0: {}, -1.0: {} }
	var slip_t := { 1.0: INF, -1.0: INF }
	var fall_t := INF
	var fall_a := {}
	for i in count:
		var t := dur * float(i) / float(count - 1)
		var p := CarCurve.s_at(rd, v_kmh, t)
		var side := float(p.side)
		if side == 0.0:
			continue
		var a := CarCurve.at_lateral(scen, v_kmh, float(p.aMs2), r_m, grip_g)
		var u := usage(a)
		if not bool(a.holds):
			fall_t = t
			fall_a = a
			if u > float(peak[side]):
				peak[side] = u
				peak_a[side] = a
			break
		if u > float(peak[side]):
			peak[side] = u
			peak_a[side] = a
		if u >= float(SLIP_FROM.value) and is_inf(float(slip_t[side])):
			slip_t[side] = t
	var prof := CarCurve.s_profile(rd, v_kmh, 3)
	var flip := float(prof.flipS)
	var events: Array = []
	var marks_of := {}
	for side: float in [1.0, -1.0]:
		var u := float(peak[side])
		var a: Dictionary = peak_a[side]
		if a.is_empty():
			continue
		var len_mm := slip_len_mm(u)
		var k := slip_count(u, n)
		var kf := flip_count(u, n) if side == -1.0 else 0
		if (k > 0 and float(slip_t[side]) < fall_t) or (kf > 0 and flip < fall_t):
			marks_of[side] = slip_marks(scen, claw_force(scen, a), len_mm)
		if k > 0 and float(slip_t[side]) < fall_t:
			events.append(_event(float(slip_t[side]), KIND_SLIP, side, k, len_mm, scen, a, u, marks_of[side]))
		# la S cambia de la curva a la izquierda (empuja a la derecha) a la de la derecha: el lado nuevo es el izquierdo
		if kf > 0 and flip < fall_t:
			events.append(_event(flip, KIND_FLIP, side, kf, len_mm, scen, a, u, marks_of[side]))
	if is_finite(fall_t):
		var fu := usage(fall_a)
		var fe := _event(fall_t, KIND_FALL, float(fall_a.curve.side), n, float(FALL_SLIDE_MM.value), scen, fall_a, fu,
			slip_marks(scen, claw_force(scen, fall_a), float(FALL_SLIDE_MM.value)))
		fe["sideways"] = String(fall_a.mode) == "lado"
		events.append(fe)
	events.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.tS) < float(y.tS))
	return {
		"events": events, "peak": { "right": float(peak[1.0]), "left": float(peak[-1.0]) }, "falls": is_finite(fall_t),
		"fallT": fall_t, "durationS": dur,
	}


static func _event(t: float, kind: String, side: float, claws: int, len_mm: float, scen: Dictionary, a: Dictionary, u: float,
		marks: Dictionary) -> Dictionary:
	return {
		"tS": t, "kind": kind, "side": side, "claws": claws, "lenMm": len_mm, "tipN": claw_force(scen, a),
		"deg": float(a.curve.markDeg), "u": u, "marks": marks,
	}


## Cuántos surcos deja en total (las garras que resbalan o arañan al caerse): en una curva quieta, los de at(); en la S, la
## suma de sus momentos.
static func groove_count(g: Dictionary) -> int:
	if g.is_empty():
		return 0
	if g.has("events"):
		var k := 0
		for e: Dictionary in g.events:
			k += int(e.claws)
		return k
	return int(g.slips)


# ════════ Textos ════════

## Un surco en palabras: lo que corta (CarTear.layers_txt) o, en el vidrio, si lo raya.
static func marks_txt(marks: Dictionary, target: Dictionary, glass: bool) -> String:
	if marks.is_empty():
		return ""
	var depth := float(marks.get("depthUm", 0.0))
	if glass:
		return ("raya el vidrio (%s)" % Format.fmt_len(depth)) if depth > 0.0 else "no raya el vidrio"
	if depth <= 0.0 or not Js.truthy(marks.get("scratched", depth > 0.0)):
		return "no raya la pintura"
	return CarTear.layers_txt(target, depth, Js.truthy(marks.get("through")))


## «una garra» o «3 garras».
static func claws_txt(k: int) -> String:
	return "una garra" if k == 1 else "%s garras" % Js.js_num_str(float(k))


## Lo que hace en la curva en una frase (g: at()): «Al límite (usa el 86 % de su agarre): 2 garras del lado de fuera resbalan
## ~1.2 cm hacia fuera y vuelven a clavarse; cada resbalón corta …» o que se cae. animal: «el águila»; bird: es un ave (al
## soltarse abre las alas e intenta despegar, aunque el viento de la marcha la deja atrás). "" si no hace nada.
static func now_txt(g: Dictionary, animal: String, target: Dictionary, glass: bool, bird := false) -> String:
	if g.is_empty():
		return ""
	var pct := CarFormat.fmt_pct(minf(float(g.u), 9.99))
	var who := animal.substr(0, 1).to_upper() + animal.substr(1)
	if bool(g.falls):
		var cut := marks_txt(g.fallMarks, target, glass)
		if bird:
			return fall_bird_txt(g, who, cut)
		if not bool(g.sideways):
			return "Se cae: la curva y el viento le piden más de lo que dan sus garras. %s se suelta arañando el panel: cada surco %s." % [who, cut]
		return "Se cae: la curva le pide más de lo que dan sus garras. %s se desequilibra, resbala ~%s hacia fuera con todas sus garras arañando y cae por la %s del coche; cada surco %s." % [
			who, CarTear.len_txt(float(g.fallMm)), CarCurve.side_name(float(g.side)), cut]
	if int(g.slips) <= 0:
		if float(g.effort) > 0.0:
			return "Se agarra con más fuerza (usa el %s de su agarre), sin resbalar." % pct
		return ""
	var one := int(g.slips) == 1
	return "Al límite (usa el %s de su agarre): %s del lado de fuera %s ~%s hacia fuera y %s a clavarse; cada resbalón %s." % [
		pct, claws_txt(int(g.slips)), "resbala" if one else "resbalan", CarTear.len_txt(float(g.lenMm)), "vuelve" if one else "vuelven",
		marks_txt(g.marks, target, glass)]


## La caída de un ave en una frase (who: «La lechuza común»; cut: lo que corta cada surco): resbala arañando y, al soltarse,
## abre las alas e intenta despegar, pero no puede con el viento de la marcha y se queda atrás.
static func fall_bird_txt(g: Dictionary, who: String, cut: String) -> String:
	if not bool(g.sideways):
		return "Se suelta: la curva y el viento le piden más de lo que dan sus garras. %s se suelta arañando el panel, abre las alas e intenta despegar, pero no puede con el viento de la marcha y se queda atrás; cada surco %s." % [who, cut]
	return "Se suelta: la curva le pide más de lo que dan sus garras. %s se desequilibra, resbala ~%s hacia fuera con todas sus garras arañando y, al soltarse, abre las alas e intenta despegar por la %s del coche, pero no puede con el viento de la marcha y se queda atrás; cada surco %s." % [
		who, CarTear.len_txt(float(g.fallMm)), CarCurve.side_name(float(g.side)), cut]


## La S en una frase (s: s_events): cuántas veces se recoloca y si se cae, y cuándo (bird: un ave intenta despegar). "" si
## no hace nada.
static func s_txt(s: Dictionary, animal: String, target: Dictionary, glass: bool, bird := false) -> String:
	if s.is_empty() or (s.events as Array).is_empty():
		return ""
	var parts: Array = []
	for e: Dictionary in s.events:
		match String(e.kind):
			KIND_SLIP:
				parts.append("a los %s s, %s de la %s %s ~%s" % [Js.to_fixed(float(e.tS), 1), claws_txt(int(e.claws)),
					CarCurve.side_name(float(e.side)), "resbala" if int(e.claws) == 1 else "resbalan", CarTear.len_txt(float(e.lenMm))])
			KIND_FLIP:
				parts.append("al cambiar de lado (%s s) se %s %s de la %s" % [Js.to_fixed(float(e.tS), 1),
					"recoloca" if int(e.claws) == 1 else "recolocan", claws_txt(int(e.claws)), CarCurve.side_name(float(e.side))])
			KIND_FALL:
				parts.append("a los %s s no aguanta y %s por la %s" % [Js.to_fixed(float(e.tS), 1),
					"se suelta e intenta despegar" if bird else "se cae", CarCurve.side_name(float(e.side))])
	var mk: Dictionary = (s.events[0] as Dictionary).marks
	var head := "En la S %s se recoloca: %s" % [animal, "; ".join(PackedStringArray(parts))]
	return "%s. Cada resbalón %s." % [head, marks_txt(mk, target, glass)]
