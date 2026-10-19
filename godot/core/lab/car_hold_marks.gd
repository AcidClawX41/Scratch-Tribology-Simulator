## Tribología biológica · coche en marcha: qué deja cada garra del animal quieto encima, según lo que hace (unidad 4y,
## petición de Eric del 18-10-2026: «las marcas tienen que salir de lo que hace cada animal en la animación y en la física:
## dónde apoya cada pata y cada garra, cuándo resbala, cuándo se recoloca, cuándo golpea o se clava»).
##
## No calcula marcas propias: decide cuáles de las que ya da el motor han pasado de verdad a esa velocidad
## (CarSpeedMarks.at: el surco y la punción de la 4s, con la carga de cada garra de CLAW_HOOK):
##   1. Apoyarse: cada garra que agarra (MovingCar.BODIES[…].contact) aprieta su punta contra el panel con su carga y deja
##      su huella, la punción estática del motor (Physics.compute «puncion» sin golpe: hondura y diámetro). Si la punta
##      atraviesa el panel (o las garras ya están clavadas tras un golpe), un agujero. En el vidrio, sin resbalar, no hay
##      huella: lo que hacen las garras duras al apoyarse son las grietas del parabrisas (las de siempre) o el estallido de
##      la luneta.
##   2. Moverse: solo entonces hay surcos, uno por garra, paralelos y en la dirección del movimiento:
##      - «resbala»: a esa velocidad no aguanta (at_speed.holds) y resbala por el panel que queda (slide_m de la zona) hacia
##        donde lo lleva la fuerza (el modo del despegue: atrás, de lado, delante o abajo); si despega, no araña;
##      - «raja»: las garras atraviesan el panel y la raja corre (CarTear: el viento puede con ellas);
##      - «dobla»: las garras de un material dúctil se doblan (CarSpeedMarks.fracture) y su punta rasca lo que se dobla.
##      Los resbalones de la curva y la caída por el lado de fuera son de la 4u (CarCurveGrip): aquí no se repiten.
##   Sin moverse no hay surcos: el surco del motor a esa velocidad es lo que rayaría si resbalara, y el texto lo dice así.
## Funciones puras, estáticas y deterministas, sin nodos. Guía: docs/fisica/coche-en-marcha.md (la 4y).
## Uso: const CarHoldMarks = preload("res://core/lab/car_hold_marks.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CarSpeedMarks = preload("res://core/lab/car_speed_marks.gd")
const CarGlass = preload("res://core/lab/car_glass.gd")
const CarTear = preload("res://core/lab/car_tear.gd")

## Lo que deja cada garra.
const PRINT := "huella"
const HOLE := "agujero"
## Por qué se mueven las garras (sin causa, no hay surcos).
const CAUSE_SLIDE := "resbala"
const CAUSE_TEAR := "raja"
const CAUSE_BEND := "dobla"
## La luneta estalla bajo sus garras: no queda vidrio en el que dejar raya ni huella (unidad 4y).
const CAUSE_SHATTER := "estalla"
## Dirección de los surcos (grados desde «hacia atrás», + hacia la derecha: la de CarCurve.mark_deg) según el modo del
## despegue (MovingCar._mode_of). «despega»: se levanta y no araña.
const SLIDE_DEG := { "atras": 0.0, "lado": 90.0, "delante": 180.0, "abajo": 180.0 }
const LIFT_MODE := "despega"

## La huella de cada garra al apoyarse: la punción estática del motor con la carga de esa garra.
const PRINT_SRC := {
	"quality": "estimate",
	"source": "la punción estática de la punta apretando contra el panel con la carga de cada garra (el motor de siempre, sin golpe: indentación de la punta, con la dureza de cada capa de la pintura y de la carrocería); la carga, la de la garra enganchada que tira con lo que el animal necesita para no soltarse (caso medido más parecido: Dai, Gorb y Schwarz 2002)",
}
## El surco del resbalón: el motor de siempre con la carga de cada garra, a lo largo del panel que queda.
const SLIDE_SRC := {
	"quality": "estimate",
	"source": "el surco del motor de siempre (Hokkirigawa y Kato 1988: arado o corte, capa a capa) con la carga de cada garra; el largo, el panel que queda por delante del animal en esa zona (de una berlina media como el DrivAer, estimación)",
}
## La punta de una garra que se dobla barre como mucho lo que se dobla.
const BEND_SCRAPE := {
	"quality": "estimate",
	"source": "la punta de una garra dúctil que se dobla (una viga en voladizo con la carga de lado que tira de ella a lo largo del panel) barre por la pintura como mucho el trozo que se dobla: suposición geométrica, sin medición publicada de una garra doblándose contra la pintura de un coche",
}


## Qué deja cada garra a esa velocidad. m: CarSpeedMarks.at(curva, v) (el surco, la punción, la rotura); o: { claws (las garras
## que agarran), holds (at_speed.holds: aguanta a esa velocidad), mode (el del despegue si no aguanta), side (±1: hacia
## dónde va de lado), slideMm (el panel que queda: holdCtx.slideMm), tearMm (lo que corre la raja; 0 si no corre), glass,
## embedded (garras clavadas tras un golpe), curve (en curva: la 4u ya dibuja la caída de lado), fracMode, brokenMm, shattered (la
## luneta ha estallado: CarGlass.rear_window, con su quality y su source en shatterQuality y shatterSource) }.
## → { claws, moves, cause, marks (garras que dejan marca), prints: { n, kind, depthUm, holeUm }, rakes: { n, lengthMm,
##     deg, depthUm, widthUm }, quality, source }. {} sin datos.
static func plan(m: Dictionary, o: Dictionary) -> Dictionary:
	if m.is_empty():
		return {}
	var n := maxi(int(o.get("claws", 1)), 1)
	var mk: Dictionary = m.get("marks", {})
	var glass := Js.truthy(o.get("glass"))
	if glass and Js.truthy(o.get("shattered")):
		# el templado estalla en trozos pequeños y se cae: ni surcos ni huellas en un vidrio que ya no está
		return {
			"claws": n, "moves": false, "cause": CAUSE_SHATTER, "marks": 0, "prints": { "n": 0, "kind": "", "depthUm": 0.0, "holeUm": 0.0 },
			"rakes": { "n": 0, "lengthMm": 0.0, "deg": 0.0, "depthUm": 0.0, "widthUm": 0.0 },
			"quality": String(o.get("shatterQuality", PRINT_SRC.quality)), "source": String(o.get("shatterSource", PRINT_SRC.source)),
		}
	var holds := Js.truthy(o.get("holds", true))
	var mode := String(o.get("mode", ""))
	var depth := float(mk.get("depthUm", 0.0))
	var scratches := depth > 0.0 and Js.truthy(mk.get("scratched", true))
	# 2. ¿se mueven las garras?
	var cause := ""
	var length := 0.0
	var deg := 0.0
	var tear := float(o.get("tearMm", 0.0))
	if not holds and mode != LIFT_MODE and not (Js.truthy(o.get("curve")) and mode == "lado"):
		cause = CAUSE_SLIDE
		length = float(o.get("slideMm", 0.0))
		deg = float(SLIDE_DEG.get(mode, 0.0))
		if mode == "lado":
			deg *= signf(float(o.get("side", 1.0))) if float(o.get("side", 1.0)) != 0.0 else 1.0
	elif tear > 0.0:
		cause = CAUSE_TEAR
		length = tear
	elif String(o.get("fracMode", m.get("fracMode", ""))) == "dobla" and float(o.get("brokenMm", 0.0)) > 0.0:
		cause = CAUSE_BEND
		length = float(o.brokenMm)
	var rakes := { "n": 0, "lengthMm": 0.0, "deg": deg, "depthUm": 0.0, "widthUm": 0.0 }
	if cause != "" and length > 0.0 and scratches:
		rakes = { "n": n, "lengthMm": length, "deg": deg, "depthUm": depth, "widthUm": float(mk.get("widthUm", 0.0)) }
	elif cause != "" and cause != CAUSE_TEAR:
		cause = ""  # se movería, pero no raya (la queratina en el vidrio): no hay surco
	# 1. la huella de cada garra al apoyarse
	var prints := { "n": 0, "kind": "", "depthUm": 0.0, "holeUm": 0.0 }
	var pn: Variant = m.get("puncture")
	if not glass and pn != null:
		var hole := float((pn as Dictionary).get("holeUm", 0.0))
		var through := Js.truthy(m.get("punctThrough")) or Js.truthy(o.get("embedded")) or (Js.truthy(m.get("through")) and cause != CAUSE_TEAR)
		var pit := float(m.get("punctUm", (pn as Dictionary).get("depthUm", 0.0)))
		if through and hole > 0.0:
			prints = { "n": n, "kind": HOLE, "depthUm": float(o.get("panelUm", pit)), "holeUm": hole }
		elif pit > 0.0 and hole > 0.0:
			prints = { "n": n, "kind": PRINT, "depthUm": pit, "holeUm": hole }
	var src: Dictionary = PRINT_SRC
	if cause == CAUSE_SLIDE:
		src = SLIDE_SRC
	elif cause == CAUSE_BEND:
		src = BEND_SCRAPE
	return {
		"claws": n, "moves": int(rakes.n) > 0, "cause": cause, "marks": n if int(prints.n) > 0 or int(rakes.n) > 0 else 0,
		"prints": prints, "rakes": rakes, "quality": src.quality, "source": src.source,
	}


## ¿Hay surcos (las garras se mueven y rayan)?
static func moves(p: Dictionary) -> bool:
	return not p.is_empty() and int(p.rakes.n) > 0


## La hondura de lo que se ve (µm): la de los surcos si se mueven; si no, la de las huellas.
static func visible_depth_um(p: Dictionary) -> float:
	if p.is_empty():
		return 0.0
	if moves(p):
		return float(p.rakes.depthUm)
	return float(p.prints.depthUm) if int(p.prints.n) > 0 else 0.0


## Lo que deja en palabras, de acuerdo con el dibujo: «sin resbalar: la huella de cada una de sus 4 garras, la punta se clava
## ~84 µm (Ø 218 µm), hasta la imprimación · si resbalara, rayaría hasta el anticorrosivo: 110 µm»; «resbala y sus 4 garras
## dejan 4 surcos paralelos de hasta 1.6 m: raya hasta…»; «se doblan y su punta rasca ~0.6 mm: …». short: sin el «si
## resbalara» (el primer plano). m: CarSpeedMarks.at.
static func txt(p: Dictionary, m: Dictionary, target: Dictionary, glass: bool, short := false) -> String:
	if p.is_empty() or m.is_empty():
		return ""
	var n := int(p.claws)
	var garras := "%d garras" % n if n != 1 else "su garra"
	var mk: Dictionary = m.marks
	if String(p.cause) == CAUSE_SHATTER:
		return "no queda vidrio que rayar" if short else "la luneta ha estallado: no queda vidrio que rayar"
	var would := CarSpeedMarks.marks_txt(m, target)
	if moves(p):
		var len_txt := CarTear.len_txt(float(p.rakes.lengthMm))
		match String(p.cause):
			CAUSE_SLIDE:
				return "resbala y sus %s dejan %s paralelos de hasta %s: %s" % [garras, ("%d surcos" % n) if n != 1 else "un surco", len_txt, would]
			CAUSE_BEND:
				return "sus %s se doblan y cada punta rasca ~%s bajo la pata: %s" % [garras, len_txt, would] if n != 1 \
					else "su garra se dobla y su punta rasca ~%s bajo la pata: %s" % [len_txt, would]
			CAUSE_TEAR:
				return "la raja corre %s con sus %s" % [len_txt, garras]
	var still := "sin resbalar"
	if glass:
		var trace := float(mk.get("depthUm", 0.0)) > 0.0
		var what := "no raya el vidrio" if trace else "no deja marca en el vidrio"
		if short:
			return "%s: %s" % [still, what]
		var alt := _would(would) if trace else CarGlass.trace_txt(String(mk.get("trace", "mancha")), float(mk.get("ratio", 0.0)))
		return "%s: %s · si resbalara, %s" % [still, what, alt]
	var pr: Dictionary = p.prints
	var out := ""
	if int(pr.n) <= 0:
		out = "%s: sus garras no se clavan en la pintura (no dejan marca)" % still
	elif String(pr.kind) == HOLE:
		var noun := String(target.body.noun) if target.get("body") != null else "el panel"
		out = "%s: sus %s atraviesan %s (%d agujeros de Ø %s)" % [still, garras, noun, n, Format.fmt_len(float(pr.holeUm))] if n != 1 \
			else "%s: su garra atraviesa %s (un agujero de Ø %s)" % [still, noun, Format.fmt_len(float(pr.holeUm))]
	else:
		var layers := MovingCar.layers_crossed(target, float(pr.depthUm)) if target.get("body") != null else []
		var to := (", hasta %s" % CarSpeedMarks._the(String(layers[-1]))) if not layers.is_empty() else ""
		out = "%s: la huella de cada una de sus %s, la punta se clava ~%s (Ø %s)%s" % [still, garras, Format.fmt_len(float(pr.depthUm)),
			Format.fmt_len(float(pr.holeUm)), to] if n != 1 \
			else "%s: la huella de su garra, la punta se clava ~%s (Ø %s)%s" % [still, Format.fmt_len(float(pr.depthUm)), Format.fmt_len(float(pr.holeUm)), to]
	if not short and float(mk.get("depthUm", 0.0)) > 0.0:
		out += " · si resbalara, %s" % _would(would)
	return out


## «raya hasta…» → «rayaría hasta…»; «raja la chapa…» → «rajaría la chapa…» (lo que haría si resbalara).
static func _would(t: String) -> String:
	for v: String in ["raya", "raja"]:
		if t.begins_with(v + " "):
			return v + "ría" + t.substr(v.length())
	return t
