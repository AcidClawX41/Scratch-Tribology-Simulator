## Tribología biológica · coche en marcha: el daño según la velocidad y la fuerza del agarre, y la rotura de cada material
## de garra (modelo 2.0, unidad 4s). Funciones puras, deterministas y seguras para hilos. Guía y fuentes:
## docs/fisica/coche-en-marcha.md, §19.
##
##   1. La carga de cada garra a cada velocidad la da MovingCar.marks_at_speed (CLAW_HOOK): la fuerza que el animal tiene que
##      hacer para no soltarse (needN), repartida entre las garras que agarran, y lo que aprieta contra el panel; la punta
##      toma la resultante y con ella el motor de siempre da el surco (capa a capa) y la punción estática (si la punta se
##      clava y si atraviesa el panel).
##   2. La rotura: la garra es la viga en voladizo de la unidad 4d (ClawFracture.peak y broken_length_mm) con la carga de
##      lado que tira de ella a lo largo del panel (tangN) donde la empuja la pintura o la chapa (MovingCar.load_point_mm).
##      Cada material con su resistencia: los reforjados, la de ClawFracture.strength (medida o estimada, §11.3); la
##      queratina, la de la cetrería (ClawCare.keratin_strength_k: la garra de avestruz de Taylor et al. 2004, con su
##      tenacidad), sin copiarla. Los frágiles (vidrio, gemas, metal duro, la queratina natural) se mellan o se parten; los
##      dúctiles (oro, acero, titanio, la queratina húmeda) se doblan; la hematites no tiene medición y se dice.
##      ClawSharpness.evaluate dice además si la sección más cargada es más pequeña que la distancia crítica de Taylor
##      (sizeEffect: el modelo se queda del lado seguro).
##   3. Después de romperse: las garras de un animal son iguales y reciben la misma carga, así que se rompen todas a la vez
##      (clawsBroken). Sin punta no hay gancho ni garra clavada: si el anclaje era el de las garras (clavadas en la chapa o
##      arando la pintura, holdCtx.clawAnchored), queda solo la fricción de su peso (holdsAfter), y si con ella no aguanta,
##      el despegue llega con la rotura (detachKmh).
##   4. La curva (curve): SAMPLES puntos de 0 al tope del deslizador con el caso central y BAND_SAMPLES con todo en contra
##      (lo: la fuerza necesaria máxima, la defensa máxima y la resistencia mínima de la garra) y todo a favor (hi); los
##      hitos (events: raya el barniz, llega a cada capa, a la chapa, atraviesa, raja, se rompen las garras, se suelta) se
##      interpolan entre muestras. Se calcula una vez por ensayo (en el hilo de lo caro del estado), nunca en cada
##      fotograma; at(curve, v) interpola sin compute().
## Unidades: fuerza N · hondura µm · velocidad km/h · tensión MPa.
## Uso: const CarSpeedMarks = preload("res://core/lab/car_speed_marks.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Contact = preload("res://core/shared/contact.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const CarGlass = preload("res://core/lab/car_glass.gd")

## Muestras de la curva (el caso central) y de cada lado de la banda.
const SAMPLES := 20
const BAND_SAMPLES := 8
## La queratina de la garra encima del coche: en su estado natural (55 % de humedad relativa, Taylor et al. 2004), la
## misma referencia de la dureza del banco (CareData.SIGMA_REF_MPA). Húmeda sería dúctil y se doblaría en vez de astillarse.
const KERATIN_HUMIDITY := "natural"
## Nombre de la queratina en los textos («la garra de queratina»).
const KERATIN_NOUN := "queratina"


# ════════ La resistencia de cada material ════════

## La resistencia de la queratina de la cetrería (ClawCare.keratin_strength_k), con su tenacidad.
static func keratin_strength() -> Dictionary:
	return ClawCare.keratin_strength_k(KERATIN_HUMIDITY)


## La resistencia del material de la garra: la de la unidad 4d (ClawFracture.strength) en los reforjados y la de la cetrería
## en la queratina (inlay «none»). null sin medición (la hematites).
static func strength_of(inlay: Dictionary) -> Variant:
	if String(inlay.id) == "none":
		return keratin_strength()
	return ClawFracture.strength(inlay)


## Nombre del material en los textos.
static func noun_of(inlay: Dictionary) -> String:
	if String(inlay.id) == "none":
		return KERATIN_NOUN
	return String(ClawFracture.NOUNS.get(inlay.id, String(inlay.name).to_lower()))


# ════════ Una velocidad ════════

## ¿Se rompe (o se dobla) la garra con la carga de un instante? h: scen.holdCtx; m: MovingCar.marks_at_speed; which: el
## extremo de la resistencia («value», «lo» = la mínima, «hi» = la máxima). La viga en voladizo de ClawFracture con la carga
## de lado tangN donde la empuja el panel (load_point_mm con la punta a la hondura mayor del surco y de la punción).
## { material, name, behavior, strengthMPa, strengthKind, kic, lateralN, normalN, loadXmm, depthMm, limitN, limitMinN,
##   limitMaxN, stressMPa, peakXmm, fails, breaks, bends, mode («intacta» | «mella» | «parte» | «dobla» | «sin_datos»),
##   brokenMm, atBase, sizeEffect, criticalUm, verdict, vsub, reason, quality, source }.
static func fracture(h: Dictionary, m: Dictionary, which: String = "value") -> Dictionary:
	var claw: Dictionary = h.claw
	var inlay: Dictionary = h.inlay
	var target: Dictionary = h.target
	var tip := MovingCar.claw_tip(claw, inlay, h.model)
	var reach: float = tip.reach
	var depth_um := float(m.marks.tipUm)
	if m.puncture != null:
		depth_um = maxf(depth_um, float(m.puncture.depthUm))
	var depth_mm := depth_um / 1000.0
	var sheet: Variant = Physics.sheet_of(target)
	var x0: float = MovingCar.load_point_mm(sheet, depth_mm) if sheet != null else 0.0
	# lo que tira de la garra a lo largo del panel; pero una garra que solo ara la pintura no puede tomar de lado más de lo
	# que la pintura (y la chapa) que tiene delante resiste (el arado de Bowden y Tabor, MovingCar.plough_n, el mismo de
	# rake_n): con más tirón, resbala por su surco y el resto lo lleva la fricción de las almohadillas. Una garra clavada en el
	# panel (embedded) sí recibe toda su parte: la sujeta el borde del agujero
	var tang := maxf(float(m.tangN), 0.0)
	var plough := INF
	if not Js.truthy(h.embedded) and target.get("body") != null and Js.truthy(target.get("layers")):
		plough = MovingCar.plough_n(target, float(m.marks.depthUm), float(m.marks.widthUm))
	var lateral := minf(tang, plough)
	var s: Variant = strength_of(inlay)
	var id := String(inlay.id)
	var out := {
		"material": id, "name": noun_of(inlay), "behavior": "sin_datos", "strengthMPa": null, "strengthKind": null,
		"kic": null, "lateralN": lateral, "tangN": tang, "ploughN": plough if is_finite(plough) else null,
		"slips": tang > plough, "normalN": float(m.pressN), "loadXmm": x0, "depthMm": depth_mm, "limitN": null,
		"limitMinN": null, "limitMaxN": null, "stressMPa": null, "peakXmm": null, "fails": false, "breaks": false,
		"bends": false, "mode": "sin_datos", "brokenMm": 0.0, "atBase": false, "sizeEffect": false, "criticalUm": null,
		"verdict": "", "vsub": "", "reason": "", "quality": null, "source": null,
	}
	if s == null:
		var why := String(ClawFracture.UNKNOWN.get(id, "sin medición de la resistencia de este material"))
		out.reason = why
		out.verdict = "SIN DATOS DE ROTURA"
		out.vsub = why
		return out
	var brittle: bool = String(s.kind) == "flexion"
	var sv := float(s.get("min" if which == "lo" else ("max" if which == "hi" else "value"), s.value))
	var pk := ClawFracture.peak(tip, reach, x0)
	var f: float = pk.factor
	var limit := sv / f if f > 0.0 else INF
	var fails := lateral > 0.0 and lateral >= limit
	var broken := ClawFracture.broken_length_mm(tip, reach, sv, lateral, x0) if fails else 0.0
	var at_base := fails and broken >= reach
	# la prueba de la punta de la cetrería: la sección más cargada frente a la distancia crítica de Taylor
	var tipchk := ClawSharpness.evaluate(tip, s, lateral, x0)
	out.merge({
		"behavior": "fragil" if brittle else "ductil", "strengthMPa": sv, "strengthKind": s.kind, "kic": s.get("kic"),
		"limitN": limit, "limitMinN": float(s.min) / f if f > 0.0 else INF, "limitMaxN": float(s.max) / f if f > 0.0 else INF,
		"stressMPa": lateral * f, "peakXmm": pk.xMm, "fails": fails, "breaks": brittle and fails, "bends": not brittle and fails,
		"mode": ("parte" if at_base else "mella") if (fails and brittle) else ("dobla" if fails else "intacta"),
		"brokenMm": broken, "atBase": at_base, "sizeEffect": Js.truthy(tipchk.sizeEffect), "criticalUm": tipchk.criticalUm,
		"quality": s.quality, "source": s.source,
	}, true)
	var v := ClawFracture.verdict_of(out)
	out.verdict = v.verdict
	out.vsub = v.vsub
	return out


## Las marcas, la punción y la rotura con el coche a v_kmh (MovingCar.marks_at_speed más fracture), y lo que pasa después de
## romperse: clawsBroken (todas, que son iguales y van igual de cargadas), anchorLost (el anclaje era el de las garras y se
## pierde) y holdsAfter (aguanta con la fricción de su peso sola). Cuesta dos compute(): para la curva, no para cada
## fotograma.
static func sample(scen: Dictionary, v_kmh: float, which: String = "value") -> Dictionary:
	var m := MovingCar.marks_at_speed(scen, v_kmh, which)
	var h: Dictionary = scen.holdCtx
	var fr := fracture(h, m, which)
	m["fracture"] = fr
	var fails := Js.truthy(fr.fails)
	m["clawsBroken"] = int(h.nContact) if fails else 0
	var lost: bool = fails and Js.truthy(h.clawAnchored)
	m["anchorLost"] = lost
	var holds_after: bool = m.holds
	if lost:
		holds_after = float(m.needN) <= float(scen.mu) * maxf(float(m.normalN), 0.0)
	m["holdsAfter"] = holds_after
	return m


# ════════ La curva ════════

## La curva del daño frente a la velocidad: { vKmh, depthUm, residualUm, tipUm, widthUm, punctUm, tipN, tangN, pressN,
## limitN (PackedFloat64Array), samples (los sample() enteros del caso central), lo y hi ({ vKmh, depthUm, tipUm, punctUm,
## tangN, limitN, through, punctThrough, breaks }), events (hitos), breakAt ({ kmh, minKmh, maxKmh, mode, verdict, vsub } o
## null), detach (MovingCar.detach), detachKmh (el despegue contando la rotura: si al romperse pierde el anclaje y la
## fricción no basta, el de la rotura), rest (la muestra a 0 km/h), panelUm, layers (Data.car_layers), quality, source }.
## {} si el ensayo no vale (scen.ok false) o no tiene holdCtx. v_max_kmh: el tope del deslizador (el del estado).
static func curve(scen: Dictionary, v_max_kmh: float = MovingCar.SLIDER_MAX_KMH, n: int = SAMPLES, band_n: int = BAND_SAMPLES) -> Dictionary:
	if not Js.truthy(scen.get("ok")) or not scen.has("holdCtx"):
		return {}
	var h: Dictionary = scen.holdCtx
	var target: Dictionary = h.target
	var count := maxi(n, 2)
	var samples: Array = []
	for i in count:
		samples.append(sample(scen, v_max_kmh * float(i) / float(count - 1), "value"))
	rear_cumulative(scen, samples)  # unidad 4v
	var out := _pack(samples)
	out["samples"] = samples
	out["lo"] = _pack(_band(scen, v_max_kmh, maxi(band_n, 2), "lo"))
	out["hi"] = _pack(_band(scen, v_max_kmh, maxi(band_n, 2), "hi"))
	out["panelUm"] = MovingCar.panel_um(target)
	out["target"] = target
	out["slideMm"] = float(h.slideMm)
	var layers: Variant = Data.car_layers(target) if not h.glass else null
	out["layers"] = layers if layers != null else []
	out["glass"] = h.glass
	out["vMaxKmh"] = v_max_kmh
	var det := MovingCar.detach(scen)
	out["detach"] = det
	out["events"] = events(out, det)
	out["breakAt"] = _break_at(out)
	out["detachKmh"] = _detach_with_break(out, det)
	_rear_events(out)  # unidad 4v: la luneta que estalla (el hito y el despegue)
	out["rest"] = samples[0]
	out["quality"] = MovingCar.CLAW_HOOK.quality
	out["source"] = MovingCar.CLAW_HOOK.source
	return out


## La curva de unos parámetros de MovingCar.setup (el aire incluido) hasta el tope del deslizador: la llama el hilo de lo
## caro del estado. {} si el ensayo no vale.
static func curve_for(p: Dictionary, v_max_kmh: float) -> Dictionary:
	var s := MovingCar.setup(p)
	return curve(s, v_max_kmh) if Js.truthy(s.get("ok")) else {}


static func _band(scen: Dictionary, v_max: float, n: int, which: String) -> Array:
	var out: Array = []
	for i in n:
		out.append(sample(scen, v_max * float(i) / float(n - 1), which))
	rear_cumulative(scen, out)  # unidad 4v
	return out


## Las series de unas muestras (PackedFloat64Array; los booleanos como 0/1).
static func _pack(samples: Array) -> Dictionary:
	var keys := ["vKmh", "depthUm", "residualUm", "tipUm", "widthUm", "punctUm", "tipN", "tangN", "pressN", "lateralN", "limitN", "through",
		"punctThrough", "breaks", "holds", "holdsAfter", "shatter"]
	var out := {}
	for k: String in keys:
		out[k] = PackedFloat64Array()
	for m: Dictionary in samples:
		var mk: Dictionary = m.marks
		var pn: Variant = m.puncture
		var fr: Dictionary = m.fracture
		out.vKmh.append(float(m.vKmh))
		out.depthUm.append(float(mk.depthUm))
		out.residualUm.append(float(mk.residualUm))
		out.tipUm.append(float(mk.tipUm))
		out.widthUm.append(float(mk.widthUm))
		out.punctUm.append(float(pn.depthUm) if pn != null else 0.0)
		out.tipN.append(float(m.tipN))
		out.tangN.append(float(m.tangN))
		out.lateralN.append(float(fr.lateralN))
		out.pressN.append(float(m.pressN))
		out.limitN.append(float(fr.limitN) if fr.limitN != null else INF)
		out.through.append(1.0 if Js.truthy(mk.through) else 0.0)
		out.punctThrough.append(1.0 if pn != null and Js.truthy(pn.through) else 0.0)
		out.breaks.append(1.0 if Js.truthy(fr.fails) else 0.0)
		out.holds.append(1.0 if Js.truthy(m.holds) else 0.0)
		out.holdsAfter.append(1.0 if Js.truthy(m.holdsAfter) else 0.0)
		out.shatter.append(1.0 if Js.truthy(m.get("rearShattered")) else 0.0)  # unidad 4v
	return out


## Primera velocidad (km/h) en la que ys pasa de thr (interpolando entre muestras; la primera muestra, si ya pasa); null si
## no pasa en ninguna.
static func first_cross(vs: PackedFloat64Array, ys: PackedFloat64Array, thr: float) -> Variant:
	for i in ys.size():
		if ys[i] > thr:
			if i == 0:
				return vs[0]
			var y0 := ys[i - 1]
			var y1 := ys[i]
			if not is_finite(y0) or not is_finite(y1) or y1 <= y0:
				return vs[i]
			return vs[i - 1] + (vs[i] - vs[i - 1]) * ((thr - y0) / (y1 - y0))
	return null


## Primera velocidad (km/h) en la que la carga de lado de la garra llega a lo que aguanta (lateralN − limitN cruza 0); null si
## no llega.
static func first_break(vs: PackedFloat64Array, tang: PackedFloat64Array, limit: PackedFloat64Array) -> Variant:
	var d := PackedFloat64Array()
	for i in vs.size():
		d.append(tang[i] - limit[i] if is_finite(limit[i]) else -INF)
	return first_cross(vs, d, -1e-12)


## Los hitos del daño con la velocidad, en orden: las capas de la pintura («raya el barniz», «llega al color»…), la carrocería
## («llega a la chapa»), «atraviesa» (la punta clavada sale por detrás del panel), «raja» (el surco de lado a lado), «se rompen
## las garras» y «se suelta» (el despegue). Cada uno { id, label, kmh, minKmh, maxKmh (null si no llega en el deslizador),
## kind («capa», «cuerpo», «atraviesa», «raja», «rompe» o «suelta») }.
static func events(c: Dictionary, det: Dictionary) -> Array:
	var out: Array = []
	var layers: Array = c.layers
	for i in layers.size():
		var l: Dictionary = layers[i]
		var from := float(l.from)
		var name := String(l.name)
		var label := "raya el barniz" if i == 0 else "llega %s" % _to(name)
		var kind := "cuerpo" if i == layers.size() - 1 else "capa"
		if kind == "cuerpo":
			label = "llega %s" % _to(String(l.cede))
		out.append(_event(String(l.id), label, kind, _cross3(c, "depthUm", from), String(l.col)))
	if not Js.truthy(c.glass) and float(c.panelUm) > 0.0:
		var panel := float(c.panelUm) - 1e-6
		out.append(_event("atraviesa", "atraviesa", "atraviesa", _cross3(c, "punctUm", panel), ""))
		out.append(_event("raja", "raja", "raja", _cross3(c, "tipUm", panel), ""))
	var br := {
		"value": first_break(c.vKmh, c.lateralN, c.limitN), "lo": first_break(c.lo.vKmh, c.lo.lateralN, c.lo.limitN),
		"hi": first_break(c.hi.vKmh, c.hi.lateralN, c.hi.limitN),
	}
	out.append(_event("rompe", "se rompen las garras", "rompe", br, ""))
	var dk: Variant = null
	if det.atRest and is_finite(float(det.kmh)):
		dk = float(det.kmh)
	elif det.get("holdToKmh") != null and is_finite(float(det.holdToKmh)):
		dk = float(det.holdToKmh)
	var dmin: Variant = float(det.minKmh) if is_finite(float(det.minKmh)) else null
	var dmax: Variant = float(det.maxKmh) if is_finite(float(det.maxKmh)) else null
	# fuera del deslizador no es un hito de la gráfica (el despegue entero sigue en detach)
	var top := float(c.vMaxKmh)
	out.append(_event("suelta", "se suelta", "suelta", {
		"value": dk if dk != null and float(dk) <= top else null, "lo": dmin if dmin != null and float(dmin) <= top else null,
		"hi": dmax if dmax != null and float(dmax) <= top else null,
	}, ""))
	return out


static func _cross3(c: Dictionary, key: String, thr: float) -> Dictionary:
	return {
		"value": first_cross(c.vKmh, c[key], thr), "lo": first_cross(c.lo.vKmh, c.lo[key], thr),
		"hi": first_cross(c.hi.vKmh, c.hi[key], thr),
	}


static func _event(id: String, label: String, kind: String, k: Dictionary, col: String) -> Dictionary:
	return { "id": id, "label": label, "kind": kind, "kmh": k.value, "minKmh": k.lo, "maxKmh": k.hi, "col": col }


## «a la chapa», «al color», «a la imprimación»…
static func _to(name: String) -> String:
	var n := name.to_lower()
	if n.begins_with("el "):
		return "al " + n.substr(3)
	if n.begins_with("la "):
		return "a " + n
	var fem := n.ends_with("a") or n.ends_with("ción") or n.ends_with("sión")
	return "%s %s" % ["a la" if fem else "al", n]


## «el anticorrosivo», «la imprimación», «el acero BH»: con su artículo (y sin cambiar las mayúsculas de una sigla).
static func _the(name: String) -> String:
	var n := name.substr(0, 1).to_lower() + name.substr(1)
	if n.begins_with("el ") or n.begins_with("la "):
		return n
	var low := n.to_lower()
	var fem := low.ends_with("a") or low.ends_with("ción") or low.ends_with("sión")
	return "%s %s" % ["la" if fem else "el", n]


## La rotura de las garras: la velocidad a la que llega (con su banda) y cómo se rompen en ese punto, o null si no se rompen
## en el deslizador ni con todo en contra.
static func _break_at(c: Dictionary) -> Variant:
	var ev: Dictionary = {}
	for e: Dictionary in c.events:
		if e.id == "rompe":
			ev = e
	if ev.is_empty() or (ev.kmh == null and ev.minKmh == null):
		return null
	var samples: Array = c.samples
	var fr: Dictionary = samples[-1].fracture
	if ev.kmh != null:
		for m: Dictionary in samples:
			if Js.truthy(m.fracture.fails):
				fr = m.fracture
				break
	return {
		"kmh": ev.kmh, "minKmh": ev.minKmh, "maxKmh": ev.maxKmh, "mode": fr.mode, "verdict": fr.verdict, "vsub": fr.vsub,
		"behavior": fr.behavior, "material": fr.material, "name": fr.name, "brokenMm": fr.brokenMm, "atBase": fr.atBase,
		"quality": fr.quality, "source": fr.source, "sizeEffect": fr.sizeEffect,
	}


## El despegue contando la rotura (km/h): el de MovingCar.detach o, si antes se rompen las garras, pierde su anclaje y con
## la fricción de su peso no aguanta, la velocidad de la rotura. INF si no se suelta en el deslizador.
static func _detach_with_break(c: Dictionary, det: Dictionary) -> float:
	var dk := INF
	if det.atRest and is_finite(float(det.kmh)):
		dk = float(det.kmh)
	elif det.get("holdToKmh") != null and is_finite(float(det.holdToKmh)):
		dk = float(det.holdToKmh)
	var br: Variant = c.breakAt
	if br == null or br.kmh == null:
		return dk
	var bk := float(br.kmh)
	# ¿aguanta sin las garras justo después de romperse? La primera muestra rota lo dice
	var samples: Array = c.samples
	for m: Dictionary in samples:
		if Js.truthy(m.fracture.fails):
			if Js.truthy(m.anchorLost) and not Js.truthy(m.holdsAfter):
				return minf(dk, bk)
			return dk
	return dk


# ════════ Leer la curva a cualquier velocidad (sin compute) ════════

## Lo que hay a v_kmh, interpolando entre las muestras del caso central (lo numérico) y con los campos discretos de la muestra
## más cercana; las capas, de la hondura interpolada. {} si no hay curva. { vKmh, depthUm, residualUm, tipUm, widthUm,
## punctUm, punctThrough, through, reachesBody, scratched, layers (nombres), layerCount, tipN, tangN, pressN, limitN, verdict,
## layer, broken (las garras ya se han roto a esa velocidad), fracMode, fracture (de la muestra más cercana), holds, holdsAfter,
## anchorLost, marks (un resumen como scen.scratch, con lengthMm), puncture }.
static func at(c: Dictionary, v_kmh: float) -> Dictionary:
	if c.is_empty():
		return {}
	var vs: PackedFloat64Array = c.vKmh
	var n := vs.size()
	var v := clampf(v_kmh, vs[0], vs[n - 1])
	var i := 0
	while i < n - 2 and vs[i + 1] < v:
		i += 1
	var t := 0.0 if vs[i + 1] <= vs[i] else clampf((v - vs[i]) / (vs[i + 1] - vs[i]), 0.0, 1.0)
	var near: int = i if t < 0.5 else i + 1
	var samples: Array = c.samples
	var s: Dictionary = samples[near]
	var lerp_k := func(key: String) -> float: return float(c[key][i]) + (float(c[key][i + 1]) - float(c[key][i])) * t
	var depth: float = lerp_k.call("depthUm")
	var tip_um: float = lerp_k.call("tipUm")
	var punct_um: float = lerp_k.call("punctUm")
	var panel := float(c.panelUm)
	var through := panel > 0.0 and tip_um >= panel - 1e-6
	var punct_through := panel > 0.0 and punct_um >= panel - 1e-6
	var target: Dictionary = c.target
	var layers: Array = []
	for l: Dictionary in c.layers:
		if depth > float(l.from) + 1e-6:
			var nm: String = l.name
			layers.append(nm.substr(0, 1).to_lower() + nm.substr(1))
	var br: Variant = c.breakAt
	var broken: bool = br != null and br.kmh != null and v >= float(br.kmh) - 1e-9
	var mk: Dictionary = s.marks
	var marks := mk.duplicate()
	marks.depthUm = depth
	marks.residualUm = lerp_k.call("residualUm")
	marks.tipUm = tip_um
	marks.widthUm = lerp_k.call("widthUm")
	marks.layers = layers
	marks.reachesBody = depth > MovingCar.PAINT_UM - 1e-6
	marks.through = through
	marks.scratched = depth > 0.0 or Js.truthy(mk.scratched)
	marks.belowMm = maxf(tip_um - panel, 0.0) / 1000.0 if through else 0.0
	marks["lengthMm"] = float(c.get("slideMm", 0.0))
	var punct: Variant = null
	if s.puncture != null:
		punct = (s.puncture as Dictionary).duplicate()
		punct.depthUm = punct_um
		punct.through = punct_through
		punct.layers = MovingCar.layers_crossed(target, punct_um) if target.get("body") != null else []
		punct.belowMm = maxf(punct_um - panel, 0.0) / 1000.0 if punct_through else 0.0
	return {
		"vKmh": v, "depthUm": depth, "residualUm": marks.residualUm, "tipUm": tip_um, "widthUm": marks.widthUm,
		"punctUm": punct_um, "punctThrough": punct_through, "through": through, "reachesBody": marks.reachesBody,
		"scratched": marks.scratched, "layers": layers, "layerCount": layers.size(), "tipN": lerp_k.call("tipN"),
		"tangN": lerp_k.call("tangN"), "pressN": lerp_k.call("pressN"), "limitN": float(c.limitN[near]),
		"verdict": mk.verdict, "layer": mk.get("layer"), "broken": broken, "fracMode": String(br.mode) if broken else "intacta",
		"fracture": s.fracture, "holds": Js.truthy(s.holds), "holdsAfter": Js.truthy(s.holdsAfter),
		"anchorLost": Js.truthy(s.anchorLost) and broken, "marks": marks, "puncture": punct, "clawsBroken": int(c.samples[0].claws) if broken else 0,
		# unidad 4v: la luneta templada (null si no está encima de ella) y si ya ha estallado a esa velocidad
		"rearWindow": s.get("rearWindow"), "rearShattered": rear_shattered_at(c, v),
	}


# ════════ Textos ════════

## Por qué no atraviesa el panel con ese material (o cómo sí): «La queratina (30 HV) es más blanda que el acero de la
## carrocería (101 HV): raya la pintura, pero resbala o se suelta antes de perforar la chapa». "" si atraviesa en el
## deslizador o no hay chapa (el vidrio).
static func no_through_note(c: Dictionary, scen: Dictionary) -> String:
	if c.is_empty() or Js.truthy(c.glass):
		return ""
	var h: Dictionary = scen.holdCtx
	var target: Dictionary = h.target
	var inlay: Dictionary = h.inlay
	var claw: Dictionary = h.claw
	var body: Dictionary = target.body
	var tip := MovingCar.claw_tip(claw, inlay, h.model)
	var what := "La %s" % noun_of(inlay) if inlay.id == "none" else "Las garras de %s" % noun_of(inlay)
	var hv := Js.js_num_str(Js.js_round(float(tip.hv)))
	var ev := _event_of(c, "atraviesa")
	var last: Dictionary = c.samples[-1]
	var top := CarFormat.fmt_kmh(float(c.vMaxKmh))
	if ev.kmh != null or _event_of(c, "raja").kmh != null:
		return ""
	var one: bool = inlay.id == "none"
	if not MovingCar.can_cut_body(inlay, target, claw):
		return "%s (%s HV) %s que el %s de la carrocería (%s HV): %s la pintura, pero %s antes de perforar %s." % [
			what, hv, "es más blanda" if one else "son más blandas", body.long, Js.js_num_str(float(body.hv)),
			"raya" if one else "rayan", "resbala o se suelta" if one else "resbalan o se sueltan", body.noun]
	var pn: Variant = last.puncture
	var depth := Format.fmt_len(float(pn.depthUm)) if pn != null else "nada"
	var cortan := "corta" if one else "cortan"
	return "%s (%s HV) %s el %s (%s HV), pero hasta %s la punta solo se clava ~%s: atravesar %s (%s con la pintura) pide más fuerza de la que tira de la garra." % [
		what, hv, cortan, body.long, Js.js_num_str(float(body.hv)), top, depth, body.noun, CarFormat.fmt_panel(float(c.panelUm))]


static func _event_of(c: Dictionary, id: String) -> Dictionary:
	for e: Dictionary in c.events:
		if e.id == id:
			return e
	return { "kmh": null, "minKmh": null, "maxKmh": null }


## La rotura en palabras: «a partir de ~85 km/h, una garra de vidrio se parte antes de soltarse (de 60 a 120 km/h según los
## datos)»; «sus garras de carburo de tungsteno no se rompen en el deslizador (ni con los datos más desfavorables)»; «sin
## medición de la resistencia de la hematites: no se puede decir si se rompe».
static func break_txt(c: Dictionary, detach_kmh: float = INF) -> String:
	if c.is_empty():
		return ""
	var last: Dictionary = c.samples[-1]
	var fr: Dictionary = last.fracture
	var noun := String(fr.name)
	var plural := "la garra de %s" % noun
	if fr.mode == "sin_datos":
		return "sin medición de la resistencia de la %s: no se puede decir si sus garras se rompen" % noun
	var br: Variant = c.breakAt
	var top := CarFormat.fmt_kmh(float(c.vMaxKmh))
	if br == null:
		return "sus garras de %s aguantan hasta %s (ni con los datos más desfavorables se rompen)" % [noun, top]
	var how: String = { "mella": "se mella", "parte": "se parte", "dobla": "se dobla" }.get(String(br.mode), "se rompe")
	if br.kmh == null:
		return "sus garras de %s aguantan hasta %s (con los datos más desfavorables, %s desde ~%s)" % [
			noun, top, how, CarFormat.fmt_kmh(float(br.minKmh))]
	var when := "a partir de ~%s" % CarFormat.fmt_kmh(float(br.kmh))
	if float(br.kmh) < MovingCar.REST_KMH:
		when = "ya con el coche parado"
	var before := ""
	if is_finite(detach_kmh) and float(br.kmh) <= detach_kmh + 1e-9:
		before = " antes de soltarse"
	elif is_finite(detach_kmh):
		before = ", ya suelto"
	var band := ""
	if (br.minKmh != null or br.maxKmh != null) and not (float(br.kmh) < MovingCar.REST_KMH and br.maxKmh != null and float(br.maxKmh) < MovingCar.REST_KMH):
		var lo := CarFormat.fmt_kmh(float(br.minKmh)) if br.minKmh != null else "0 km/h"
		var hi := ("~%s" % CarFormat.fmt_kmh(float(br.maxKmh))) if br.maxKmh != null else "más de %s" % top
		band = " (de %s a %s según los datos)" % [lo, hi]
	var what := "por la base" if Js.truthy(br.atBase) else "los últimos ~%s" % Format.fmt_len(float(br.brokenMm) * 1000.0)
	if br.mode == "mella":
		what = "se le desprenden ~%s de la punta" % Format.fmt_len(float(br.brokenMm) * 1000.0)
		return "%s, %s se mella%s: %s%s" % [when, plural, before, what, band]
	return "%s, %s %s %s%s%s" % [when, plural, how, what, before, band]


## Las marcas a una velocidad, en palabras: «raya hasta la imprimación: 72 µm (quedan 60 µm al soltar) · carga en la punta
## ~38 N (tira ~21 N)». m: at(c, v).
static func marks_txt(m: Dictionary, target: Dictionary) -> String:
	if m.is_empty():
		return ""
	var mk: Dictionary = m.marks
	var txt := ""
	if Js.truthy(mk.through):
		txt = "%s de lado a lado (%s con la pintura)" % [String(mk.verdict).to_lower(), CarFormat.fmt_panel(float(mk.depthUm))]
	elif float(mk.depthUm) > 0.0:
		var layers: Array = mk.layers
		var where: String = ("hasta %s" % _the(String(layers[-1]))) if not layers.is_empty() else ""
		if where == "" and mk.has("trace"):
			where = "el vidrio"  # unidad 4v: en el vidrio no hay capas de pintura
		txt = "raya %s: %s" % [where, Format.fmt_len(float(mk.depthUm))]
		if float(mk.residualUm) < float(mk.depthUm) - 0.5:
			txt += " (quedan %s al soltar)" % Format.fmt_len(float(mk.residualUm))
	elif mk.has("trace"):
		txt = CarGlass.trace_txt(String(mk.trace), float(mk.get("ratio", 0.0)))  # unidad 4v: en el vidrio, mancha o trazo
	else:
		txt = "no raya: %s" % String(mk.verdict).to_lower()
	var pn: Variant = m.puncture
	if pn != null and Js.truthy(m.punctThrough):
		var noun := String(target.body.noun) if target.get("body") != null else "el panel"
		txt += " · la punta atraviesa %s (agujeros de Ø %s)" % [noun, Format.fmt_len(float(pn.holeUm))]
	elif pn != null and float(m.punctUm) > float(mk.depthUm) + 0.5:
		txt += " · la punta se clava ~%s" % Format.fmt_len(float(m.punctUm))
	return txt


## La carga de cada garra en palabras: «~38 N en la punta: aprieta ~32 N y tira ~21 N a lo largo del panel».
static func load_txt(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	return "~%s en la punta: aprieta ~%s y tira ~%s a lo largo del panel" % [
		CarFormat.fmt_n_small(float(m.tipN)), CarFormat.fmt_n_small(float(m.pressN)), CarFormat.fmt_n_small(float(m.tangN))]


# ════════ Cristales (unidad 4v) ════════

## La luneta templada no se recompone: estalla con el coche parado (scen.rearWindow) o a una velocidad, y sigue estallada a
## todas las de encima (el coche ha acelerado hasta ahí). Solo estalla bajo el animal mientras sigue encima (holds: más allá
## del despegue, las cargas de la muestra son hipotéticas). Marca rearShattered en las muestras (en orden de velocidad) y, sin
## apoyo, holdsAfter = false. La luneta de cada muestra pasa a ser la primera que estalla.
static func rear_cumulative(scen: Dictionary, samples: Array) -> void:
	var first: Variant = scen.get("rearWindow")
	if first != null and not bool(first.shattered):
		first = null
	for m: Dictionary in samples:
		var rw: Variant = m.get("rearWindow")
		if rw == null:
			continue
		if first == null and bool(rw.shattered) and Js.truthy(m.holds):
			first = rw
		m["rearShattered"] = first != null
		if first != null:
			m["rearWindow"] = first
			m["holdsAfter"] = false


## El hito «estalla la luneta» (con su banda) y el despegue: sin apoyo se suelta en ese momento, si no se había soltado ya.
static func _rear_events(c: Dictionary) -> void:
	var samples: Array = c.samples
	if samples.is_empty() or samples[0].get("rearWindow") == null:
		return
	var k := _cross3(c, "shatter", 0.5)
	var ev := _event("estalla", "estalla la luneta", "estalla", k, "")
	(c.events as Array).append(ev)
	c["rearAt"] = ev
	if k.value != null:
		c["detachKmh"] = minf(float(c.detachKmh), float(k.value))


## ¿Ha estallado ya la luneta a v_kmh? (la primera muestra estallada de la curva).
static func rear_shattered_at(c: Dictionary, v_kmh: float) -> bool:
	var ev: Variant = c.get("rearAt")
	return ev != null and ev.kmh != null and v_kmh >= float(ev.kmh) - 1e-9
