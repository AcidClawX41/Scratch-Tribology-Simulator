## Coche en marcha · las garras en los cristales (unidad 4v; petición de Eric del 18-10-2026; docs/fisica/coche-en-marcha.md
## §24). Lo que les pasa al parabrisas, a la luneta y a las ventanillas cuando un animal pone las garras encima:
##   - rayar: el mismo criterio que la lente de la cetrería y el banco, una garra raya el vidrio solo si es al menos 1,25 veces
##     más dura (ClawCareReaction.R_SCRATCH; Richardson 1968; Pintaude); la hondura y la anchura las da el motor
##     (Physics.compute, lo que hace MovingCar._marks con el vidrio). Por debajo, la queratina deja una mancha y un metal
##     blando (oro, acero, titanio) el trazo de su metal, que se limpia: no es una raya;
##   - el parabrisas laminado se agrieta (el peso o una garra dura, MovingCar.windshield_load) pero el PVB lo sujeta: no cae;
##     lo que trae es que el conductor ve peor (view_loss, estimación) y, en un golpe, el riesgo de que lo atraviese
##     (penetrationRisk de Glazing.laminated_result);
##   - la luneta y las ventanillas templadas aguantan enteras o estallan en trocitos, nunca a medias
##     (Glazing.tempered_result): si estalla bajo el animal, pierde ese apoyo y caen trocitos dentro del coche.
## Puras y deterministas, sin nodos. Las que necesitan el animal o la garra reciben ya resuelto lo que sale de MovingCar
## (la punta: MovingCar.claw_tip; el peso de cada apoyo; el radio del apoyo), para no precargar moving_car.gd (que precarga
## este módulo).
## Uso: const CarGlass = preload("res://core/lab/car_glass.gd").
extends RefCounted

const Physics = preload("res://core/lab/physics.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")

## El umbral de la raya de verdad: el de la lente de la cetrería (r ≥ 1,25, Richardson 1968; el criterio de Pintaude).
## Va escrito aquí y no leído de ClawCareReaction: precargarla cerraba el ciclo ClawsV2 → MovingCar → CarGlass →
## ClawCareReaction → Catalog, y Catalog construía CLAWS antes de que ClawsV2 tuviera sus correcciones de la 2.0 (el
## test de la 4v comprueba que los dos umbrales son el mismo).
const R_SCRATCH := 1.25
const R_SCRATCH_SOURCE := {
	"quality": "secondary",
	"source": "una punta raya un vidrio solo si es al menos 1,25 veces más dura que él (Richardson 1968, el criterio de Pintaude; el mismo umbral que la lente de la cetrería y que la marca de verdad del banco)",
}

## La luneta trasera: vidrio templado como las ventanillas (Glazing.SIDE_WINDOW: la misma resistencia, el mismo temple),
## más grande. Espesor de 4 mm y una luneta de ~1,1 × 0,5 m (radio equivalente de una placa redonda de su área, ~420 mm):
## ESTIMACIÓN.
const REAR_WINDOW_PANE := { "t": 4.0, "a": 420.0, "fgk": 120.0, "nu": 0.22 }
const REAR_WINDOW_SOURCE := {
	"quality": "estimate",
	"source": "luneta de vidrio templado como las ventanillas (resistencia a flexión 120 MPa, EN 12150-1, el del templado del banco): espesor de 4 mm, el de las ventanillas de Europa (just-auto), y una luneta de ~1,1 × 0,5 m de una berlina media (radio equivalente ~420 mm, el de una placa redonda de su área): ESTIMACIÓN, sin medición publicada de la luneta",
}

## El parabrisas de una berlina media (m²) y lo que agrieta cada apoyo que lo parte (una estrella de grietas radiales de
## ~0,2 m de radio) o cada garra dura que lo agrieta al rayarlo (una franja de ~2 cm a lo largo del surco): ESTIMACIÓN.
const WINDSCREEN_M2 := 1.1
const STAR_RADIUS_M := 0.2
const GROOVE_BAND_M := 0.02
const VIEW_LOSS_SOURCE := {
	"quality": "estimate",
	"source": "parabrisas de ~1,1 m² de una berlina media; cada apoyo que lo parte abre una estrella de grietas radiales de ~0,2 m de radio y cada garra dura que lo agrieta al rayarlo, una franja de ~2 cm a lo largo del surco (caso medido más parecido: las grietas radiales y en telaraña de los ensayos de impacto de cabeza contra parabrisas laminados, de decenas de centímetros; Xu J, Li Y et al. 2013, Int. J. Impact Eng.): ESTIMACIÓN; lo que tapa a la vista del conductor depende de dónde caiga (la zona A de la CEPE R43 está delante de él)",
}


## ¿La raya? r = dureza de la punta / dureza del vidrio ≥ R_SCRATCH.
static func scratches(tip_hv: float, glass_hv: float) -> bool:
	return glass_hv > 0.0 and tip_hv / glass_hv >= R_SCRATCH


## Lo que deja una garra que no raya el vidrio: «mancha» (la queratina, o un material frágil más blando que el vidrio) o
## «trazo» (un metal blando: el oro, el acero, el titanio dejan el trazo de su metal, que se limpia). «raya» si lo raya.
static func trace_kind(inlay_id: String, tip_hv: float, glass_hv: float) -> String:
	if scratches(tip_hv, glass_hv):
		return "raya"
	return "trazo" if ClawFracture.DUCTILE.has(inlay_id) else "mancha"


## El resumen de la marca de una garra en el vidrio (el de MovingCar._marks) con el criterio de la raya: por debajo de
## R_SCRATCH no hay surco aunque el motor dé una hondura de pulido mutuo («MARCA TENUE»). summary: el de _scratch_summary;
## lo devuelve corregido (copia) con { verdict, scratched, depthUm, widthUm, trace, ratio }.
static func glass_scratch(summary: Dictionary, inlay_id: String, tip_hv: float, glass_hv: float) -> Dictionary:
	var out := summary.duplicate()
	var kind := trace_kind(inlay_id, tip_hv, glass_hv)
	out["trace"] = kind
	out["ratio"] = tip_hv / glass_hv if glass_hv > 0.0 else 0.0
	if kind != "raya":
		out["depthUm"] = 0.0
		out["residualUm"] = 0.0
		out["widthUm"] = 0.0
		out["scratched"] = false
		out["verdict"] = "NO RAYA"
		return out
	out["scratched"] = float(out.get("depthUm", 0.0)) > 0.0
	out["verdict"] = "RAYA" if bool(out.scratched) else "NO RAYA"
	return out


## La luneta templada para Glazing.tempered_result: la de las ventanillas con la hoja de la luneta.
static func rear_window() -> Dictionary:
	var w: Dictionary = Glazing.SIDE_WINDOW.duplicate(true)
	w.id = "luneta"
	w.name = "Luneta"
	w.pane = REAR_WINDOW_PANE.duplicate()
	w.source = REAR_WINDOW_SOURCE.source
	return w


## Un templado (la luneta o una ventanilla) con un animal encima: el peso de cada apoyo (patch_n) contra la fuerza que la
## parte al flexar (Physics.pane_break con el radio del apoyo) y la carga de cada garra (claw_n) contra la que abre la grieta
## que atraviesa la capa comprimida, solo si la punta es al menos tan dura como el vidrio (tip: MovingCar.claw_tip, con hv y
## tanA). Entera o estallada, nunca a medias. { glass (id), kind «templado», shattered, cause («flexión», «grieta» o null),
## bendN, pierceN, loadN, clawN, hardTip, fragmentMm, fragments25, losesSupport, shardsInside, quality, source }.
static func tempered_hold(w: Dictionary, patch_n: float, claw_n: float, contact_mm: float, tip: Dictionary) -> Dictionary:
	var pb := Physics.pane_break(w.pane, float(w.E), contact_mm)
	var hard := float(tip.hv) / float(w.hv) >= 1.0
	var tr := Glazing.tempered_result(w, patch_n, float(pb.F), hard, claw_n, float(tip.tanA))
	var out := {
		"glass": String(w.id), "kind": "templado", "shattered": bool(tr.shattered), "cause": tr.cause, "bendN": float(pb.F),
		"pierceN": float(tr.pierceN), "loadN": patch_n, "clawN": claw_n, "hardTip": hard, "fragmentMm": float(tr.fragmentMm),
		"fragments25": float(tr.fragments25), "losesSupport": bool(tr.shattered), "shardsInside": bool(tr.shattered),
		"quality": "estimate", "source": String(w.source),
	}
	return out


## Lo que tapa a la vista un parabrisas agrietado (0-1 del parabrisas): cada apoyo que lo parte (cause «flexión»: patches
## estrellas de STAR_RADIUS_M) o cada garra dura que lo agrieta al rayarlo (cause «grieta»: claws franjas de GROOVE_BAND_M
## a lo largo del surco de length_m). 0 si no se agrieta. { frac, cause, quality, source }.
static func view_loss(cracked: bool, by_contact: bool, patches: int, claws: int, length_m: float) -> Dictionary:
	var frac := 0.0
	var cause: Variant = null
	if cracked:
		if by_contact:
			cause = "grieta"
			frac = float(claws) * GROOVE_BAND_M * length_m / WINDSCREEN_M2
		else:
			cause = "flexión"
			frac = float(patches) * PI * STAR_RADIUS_M * STAR_RADIUS_M / WINDSCREEN_M2
	return { "frac": clampf(frac, 0.0, 1.0), "cause": cause, "quality": VIEW_LOSS_SOURCE.quality, "source": VIEW_LOSS_SOURCE.source }


# ════════ Textos (unidad 4v) ════════

## El nombre de las garras en los textos: «sus garras de queratina», «sus garras de diamante».
static func claws_noun(inlay_id: String) -> String:
	if inlay_id == "none" or inlay_id == "":
		return "sus garras de queratina"
	return "sus garras de %s" % String(ClawFracture.NOUNS.get(inlay_id, inlay_id))


## El veredicto del animal quieto encima de una luneta que estalla (rear: tempered_hold con shattered): pierde el apoyo y cae
## dentro del coche con los trocitos. o: la terminación de los adjetivos del animal («o» o «a»). { verdict, vsub }.
static func rear_verdict(rear: Dictionary, inlay_id: String, o: String) -> Dictionary:
	var frag := CarFormat.fmt_long(float(rear.fragmentMm) * 1000.0)
	var after := "la luneta templada estalla entera en trocitos de ~%s: pierde el apoyo y se cae dentro del coche, con los trocitos" % frag
	if rear.cause == "grieta":
		return {
			"verdict": "ESTALLA LA LUNETA BAJO SUS GARRAS",
			"vsub": "%s, al menos tan duras como el vidrio, aprietan ~%s cada una y bastan ~%s para abrir la grieta que atraviesa la capa comprimida: %s" % [
				claws_noun(inlay_id), CarFormat.fmt_n(float(rear.clawN)), CarFormat.fmt_n(float(rear.pierceN)), after],
		}
	return {
		"verdict": "ESTALLA LA LUNETA BAJO SU PESO",
		"vsub": "cada apoyo carga ~%s y la luneta se parte al flexar desde ~%s: %s (sentad%s ahí no se queda nadie)" % [
			CarFormat.fmt_n(float(rear.loadN)), CarFormat.fmt_n(float(rear.bendN)), after, o],
	}


## La luneta en una fila del informe: «aguanta entera · ~489 N por apoyo (se parte al flexar desde ~1118 N)» o «estalla en
## trocitos de ~5.6 mm (…): pierde el apoyo y caen dentro».
static func rear_row(rear: Dictionary) -> String:
	if bool(rear.shattered):
		var why := ("las garras abren la grieta del temple (~%s cada una; bastan ~%s)" % [CarFormat.fmt_n(float(rear.clawN)), CarFormat.fmt_n(float(rear.pierceN))]) \
			if rear.cause == "grieta" else ("su peso la parte al flexar (~%s por apoyo; desde ~%s)" % [CarFormat.fmt_n(float(rear.loadN)), CarFormat.fmt_n(float(rear.bendN))])
		return "estalla en trocitos de ~%s: %s; pierde el apoyo y caen trocitos dentro del coche" % [
			CarFormat.fmt_long(float(rear.fragmentMm) * 1000.0), why]
	var txt := "aguanta entera · ~%s por apoyo (se parte al flexar desde ~%s)" % [CarFormat.fmt_n(float(rear.loadN)), CarFormat.fmt_n(float(rear.bendN))]
	if bool(rear.hardTip):
		txt += "; cada garra aprieta ~%s y abrir la grieta del temple pide ~%s" % [CarFormat.fmt_n(float(rear.clawN)), CarFormat.fmt_n(float(rear.pierceN))]
	else:
		txt += "; sus garras, más blandas que el vidrio, no pueden abrir la grieta del temple"
	return txt


## Lo que tapa al conductor la grieta del parabrisas (vl: view_loss), en palabras: «tapa ~13 % del parabrisas (estimación;
## si cae delante del conductor, ve peor)». "" si no tapa nada.
static func view_txt(vl: Variant) -> String:
	if vl == null or float(vl.frac) <= 0.0:
		return ""
	var how := "las estrellas de grietas bajo sus apoyos" if vl.cause == "flexión" else "las grietas a lo largo de los surcos de sus garras"
	return "%s tapan ~%s del parabrisas al conductor (estimación: depende de dónde caigan)" % [how, CarFormat.fmt_share(float(vl.frac))]


## Lo que deja una garra en el vidrio, en palabras (trace: trace_kind; ratio: dureza de la punta / la del vidrio): «raya el
## vidrio (r = 18.2)», «deja un trazo de su metal, que se limpia (r = 0.36)», «deja una mancha (r = 0.05)».
static func trace_txt(trace: String, ratio: float) -> String:
	var r := ("r = %s, y rayarlo pide 1.25" % Js.to_fixed(ratio, 2)) if trace != "raya" else ("r = %s" % Js.to_fixed(ratio, 2))
	match trace:
		"raya":
			return "raya el vidrio (%s)" % r
		"trazo":
			return "no raya el vidrio: deja un trazo de su metal, que se limpia (%s)" % r
	return "no raya el vidrio: deja una mancha (%s)" % r


# ════════ El corte del vidrio (unidad 4v) ════════

## Colores del corte del vidrio (dibujo): el vidrio del parabrisas y de la ventanilla (Glazing), la lámina de PVB y el
## núcleo en tracción del templado, un poco más oscuro.
const CUT_COLS := { "laminado": "#7FA9BF", "pvb": "#D8CFA8", "templado": "#8FB8C8", "nucleo": "#5F8796" }


## Las capas del vidrio de una zona con lo que les pasa: el laminado (vidrio, PVB y vidrio: Glazing.WINDSCREEN.laminated) o
## el templado (capa comprimida, núcleo en tracción y capa comprimida: el 21 % del espesor, Glazing.compression_depth_mm). Como
## CarTear.cutaway: [{ id, name, col, from, to (µm), state }], con state «intacta», «cortada», «marcada» (el surco), «agrietada»
## (el laminado que se parte, sujeto por el PVB: por contacto, la hoja de fuera; al flexar, las dos) o «estallada» (el templado
## en trocitos).
static func cutaway(kind: String, depth_um: float, cracked: bool, shattered: bool, pane: Dictionary, by_contact := false) -> Array:
	var layers: Array = []
	if kind == "laminado":
		var lam: Dictionary = Glazing.WINDSCREEN.laminated
		var p0 := float(lam.plies[0]) * 1000.0
		var pvb := float(lam.pvbMm) * 1000.0
		var p1 := float(lam.plies[1]) * 1000.0
		layers = [
			{ "id": "vidrio_ext", "name": "Vidrio de fuera", "col": CUT_COLS.laminado, "from": 0.0, "to": p0 },
			{ "id": "pvb", "name": "Lámina de PVB", "col": CUT_COLS.pvb, "from": p0, "to": p0 + pvb },
			{ "id": "vidrio_int", "name": "Vidrio de dentro", "col": CUT_COLS.laminado, "from": p0 + pvb, "to": p0 + pvb + p1 },
		]
	else:
		var t := float(pane.t) * 1000.0
		var d := Glazing.compression_depth_mm(float(pane.t)) * 1000.0
		layers = [
			{ "id": "comprimida_ext", "name": "Cara comprimida", "col": CUT_COLS.templado, "from": 0.0, "to": d },
			{ "id": "nucleo", "name": "Núcleo en tracción", "col": CUT_COLS.nucleo, "from": d, "to": t - d },
			{ "id": "comprimida_int", "name": "Cara de dentro", "col": CUT_COLS.templado, "from": t - d, "to": t },
		]
	for l: Dictionary in layers:
		var state := "intacta"
		if shattered:
			state = "estallada"
		elif depth_um >= float(l.to) - 1e-6:
			state = "cortada"
		elif depth_um > float(l.from) + 1e-6:
			state = "marcada"
		elif cracked and String(l.id) != "pvb" and not (by_contact and String(l.id) == "vidrio_int"):
			state = "agrietada"
		l["state"] = state
	return layers


## Lo que se ve en el corte del vidrio y su escalón, como CarTear.assess (para la ficha «Hasta dónde llega» y el corte del
## primer plano). o: { kind («laminado» o «templado»), name (el cristal: «el parabrisas», «la luneta», «la ventanilla»),
## depthUm, trace, ratio, cracked, shattered, fragmentMm, pane, viewLoss }. → { level (1), id («mancha», «raya_vidrio»,
## «agrieta» o «estalla»), glass: true, layers, text, why, quality, source }.
static func glass_cut(o: Dictionary) -> Dictionary:
	var kind := String(o.get("kind", "laminado"))
	var depth := float(o.get("depthUm", 0.0))
	var cracked := bool(o.get("cracked", false))
	var shattered := bool(o.get("shattered", false))
	var pane: Dictionary = o.get("pane", Glazing.SIDE_WINDOW.pane)
	var vl: Variant = o.get("viewLoss")
	var layers := cutaway(kind, depth, cracked, shattered, pane, vl != null and vl.cause == "grieta")
	var out := { "level": 1, "id": "mancha", "glass": true, "lengthMm": 0.0, "layers": layers,
		"text": "", "why": "", "quality": R_SCRATCH_SOURCE.quality, "source": R_SCRATCH_SOURCE.source }
	var name := String(o.get("name", "el vidrio"))
	out.text = trace_txt(String(o.get("trace", "mancha")), float(o.get("ratio", 0.0)))
	if depth > 0.0:
		out.id = "raya_vidrio"
		out.text = "raya %s: ~%s de hondo en %s de vidrio" % [name, Format.fmt_len(depth), CarFormat.fmt_long(float(out.layers[0].to))]
	if cracked:
		out.id = "agrieta"
		out.text = "%s se agrieta, pero la lámina de PVB sujeta los trozos: no cae" % name
		out.why = view_txt(o.get("viewLoss"))
		out.quality = "secondary"
		out.source = String(Glazing.WINDSCREEN.source)
	if shattered:
		out.id = "estalla"
		out.text = "%s estalla entera en trocitos de ~%s: un templado no se agrieta a medias" % [name,
			CarFormat.fmt_long(float(o.get("fragmentMm", 5.6)) * 1000.0)]
		out.quality = "estimate"
		out.source = String(Glazing.SIDE_WINDOW.source)
	return out
