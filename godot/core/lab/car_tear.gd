## Coche en marcha · hasta dónde llega cada marca y si raja o abre el panel (unidad 4s, petición de Eric del 17-10-2026:
## «las marcas y rajadas de garras de cada animal tienen que verse visibles, ver qué capas de la chapa del coche atraviesan,
## y si pueden rasgar y abrir la puerta o techo entero, dependiendo del tipo de garra que lleve cada animal, y la fuerza
## aplicada»). Pura y determinista; no calcula marcas: las toma del motor (CarSpeedMarks.at quieto encima, impact() en el
## golpe) y decide, en este orden:
##   1. «marca»: no atraviesa el panel. Qué capas corta (las de Data.car_layers: barniz, color, imprimación, anticorrosivo y
##      la carrocería) y si marca la carrocería sin perforarla.
##   2. «perfora»: la punta asoma por detrás (la punción del motor: indentación hasta romper la chapa y pétalos de
##      Wierzbicki 1999).
##   3. «raja X cm»: las garras pasan de lado a lado y la grieta corre a lo largo del panel. Cada garra abre una grieta de
##      todo el espesor y pide F = R·t (como en el desgarro del plástico, MovingCar.tear_run): con la chapa, R es su trabajo
##      esencial de fractura en tensión plana (SHEET_TEAR, estimación); con el plástico, PLASTIC_TEAR. Quieto encima, el
##      viento tira de las garras hacia atrás (needN de at_speed): si pasa de n·R·t, la raja corre hasta el borde del panel;
##      si no, mide lo que resbalan. En el golpe, lo que dice el motor (las marcas que atraviesan y su largo; el desgarro del
##      plástico).
##   4. «abre la puerta»: solo si la raja llega al canto de la puerta (slide_m de la zona, el panel que queda hasta el canto
##      de la cerradura): ahí va atornillada la cerradura y, suelta de la chapa, la puerta se abre (estimación). Tirar de la
##      puerta cerrada no basta: la cerradura aguanta al menos 8900 N de través (LATCH, FMVSS 206). Los osos que abren coches
##      aparcados (NPS_BEAR) doblan el marco por arriba con calma, no en un golpe.
##   5. «abre el techo entero»: nunca con un animal de verdad. Aunque cortar su contorno pida poca energía con unas garras
##      que corten el acero, los zarpazos solo cortan en la dirección en la que arrastran (tiras a lo largo) y el techo va
##      pegado a los largueros y a los arcos (ROOF): sin cortes de través, las tiras siguen sujetas por los dos extremos. Se
##      dice con los números.
## El velocirraptor «de cine» es ficción (MovingCarState.film) y se dice.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Data = preload("res://core/lab/data.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CarFormat = preload("res://core/lab/car_format.gd")

## Lo que tiene que hundirse en la carrocería una marca para decir que la marca (µm; menos, se queda en la pintura): el paso
## de 0,5 µm con el que ya se comparan las honduras (hold_marks_sig).
const MARK_MIN_UM := 0.5
## Los escalones del veredicto, de menos a más.
const LEVELS := ["nada", "marca", "perfora", "raja", "abre"]
## Trabajo esencial de fractura de una chapa metálica fina en tensión plana (kJ/m² = N/mm): R ≈ k·σ0·t, con σ0 la tensión de
## flujo de la chapa (la de Wierzbicki que ya usa el motor, Data.CAR_BODIES) y t su espesor.
const SHEET_TEAR := {
	"k": 1.0, "k_min": 0.5, "k_max": 2.0, "quality": "estimate",
	"source": "Caso medido más parecido: el trabajo esencial de fractura de chapas dúctiles finas en tensión plana, que crece con el espesor y la tensión de fluencia (Cotterell B, Reddel JK (1977). The essential work of plane stress ductile fracture. Int. J. Fract. 13:267-277; Atkins AG, Mai YW (1985). Elastic and Plastic Fracture, Ellis Horwood). Suposición: R ≈ σ0·t (la zona que se estrecha delante de la grieta mide del orden del espesor), con banda de ×0,5 a ×2; con el acero de horno de 0,7 mm, ~185 kJ/m². No se cuenta lo que cuesta doblar los labios de la raja: cota baja de la fuerza y alta del largo",
}
## La cerradura de una puerta lateral (N): lo que aguanta como mínimo, cerrada del todo.
const LATCH := {
	"transverse_n": 8900.0, "longitudinal_n": 11000.0, "quality": "primary",
	"source": "FMVSS 206 (49 CFR 571.206, S4.1.1): la cerradura de una puerta lateral, cerrada del todo, aguanta al menos 11 000 N a lo largo y 8900 N de través",
}
## Los osos que abren coches aparcados (caso documentado, sin fuerzas medidas).
const NPS_BEAR := {
	"quality": "secondary",
	"source": "Yosemite National Park (National Park Service), «Bears and cars» y la campaña «Keep Bears Wild»: los osos negros abren coches aparcados enganchando las garras en lo alto del marco de la puerta y doblándolo hacia fuera hasta sacar la puerta; tiran con calma, durante segundos o minutos, en un coche quieto",
}
## El techo de una berlina media: su largo es el panel del techo de la zona (MovingCar.IMPACT_ZONES.techo.slide_m) y su ancho,
## este (m).
const ROOF := {
	"width_m": 1.2, "quality": "estimate",
	"source": "del orden del techo de una berlina media como el DrivAer (1,8 m de ancho de carrocería; el techo, unos dos tercios): estimación. El techo va pegado y soldado a los largueros y a los arcos transversales",
}


## R (kJ/m²) de la carrocería de un coche: { value, min, max, quality, source } o null (sin carrocería o sin datos).
static func tear_toughness(target: Dictionary) -> Variant:
	var body: Variant = target.get("body")
	if body == null:
		return null
	if not Js.truthy(body.get("metal")):
		var r: Variant = MovingCar.PLASTIC_TEAR.get(String(body.id))
		if r == null:
			return null
		return { "value": float(r.value), "min": float(r.min), "max": float(r.max), "quality": r.quality, "source": r.source }
	var st := float(body.sigma0) * float(body.t) / 1000.0
	return {
		"value": st * float(SHEET_TEAR.k), "min": st * float(SHEET_TEAR.k_min), "max": st * float(SHEET_TEAR.k_max),
		"quality": SHEET_TEAR.quality, "source": SHEET_TEAR.source,
	}


## Las capas de un coche con lo que les pasa a una hondura (µm) y si el panel queda atravesado: [{ id, name, col, from, to,
## state («intacta», «cortada»: la marca la pasa entera, «marcada»: llega a ella sin pasarla, «atravesada») }].
static func cutaway(target: Dictionary, depth_um: float, through: bool) -> Array:
	var out: Array = []
	var L: Variant = Data.car_layers(target)
	if L == null:
		return out
	for l: Dictionary in L:
		var state := "intacta"
		if through:
			state = "atravesada"
		elif depth_um >= float(l.to) - 1e-6:
			state = "cortada"
		elif depth_um > float(l.from) + 1e-6:
			state = "marcada"
		out.append({ "id": l.id, "name": l.name, "col": l.col, "from": float(l.from), "to": float(l.to), "state": state })
	return out


## Las capas que corta una marca en palabras: «atraviesa el barniz, el color, la imprimación y el anticorrosivo; marca el acero
## sin perforarlo (120 µm de 700)», «raya el barniz y el color: no llega a la imprimación», «perfora la chapa de 0,7 mm».
static func layers_txt(target: Dictionary, depth_um: float, through: bool) -> String:
	var body: Variant = target.get("body")
	if body == null:
		return ""
	if through:
		return "atraviesa la pintura y %s de %s" % [String(body.noun), thick_txt(target)]
	var cut: Array = []
	var marked := ""
	for l: Dictionary in cutaway(target, depth_um, false):
		if l.id == "carroceria":
			if l.state != "intacta":
				marked = l.name
			continue
		if l.state == "cortada":
			cut.append(String(l.name).to_lower())
		elif l.state == "marcada":
			marked = String(l.name).to_lower()
	if depth_um <= 0.0:
		return "no raya la pintura"
	var paint_um: float = Data.PAINT_LAYERS[-1].to
	if depth_um >= paint_um - 1e-6:
		var into := depth_um - paint_um
		if into < MARK_MIN_UM:
			return "atraviesa la pintura (%s) hasta %s, sin marcarla" % [_list(cut), String(body.noun)]
		return "atraviesa la pintura (%s) y marca el %s sin perforarlo (%s de %s)" % [_list(cut), String(body.long), Format.fmt_len(into), thick_txt(target)]
	if cut.is_empty():
		return "raya %s sin pasarlo (%s)" % [_with_article(marked), Format.fmt_len(depth_um)]
	return "corta %s y raya %s (%s): no llega a %s" % [_list(cut), _with_article(marked), Format.fmt_len(depth_um), String(body.noun)]


## Unidad 4y: lo mismo para la huella de la punta de una garra que no se mueve (la punción quieto encima): «la huella de
## la punta corta el barniz y marca el color (52 µm): no llega a la chapa».
static func pit_txt(target: Dictionary, depth_um: float) -> String:
	var t := layers_txt(target, depth_um, false)
	if depth_um <= 0.0 or t == "":
		return t
	if t.begins_with("raya "):
		t = "marca " + t.substr(5)
	return "la huella de la punta " + t.replace(" y raya ", " y marca ")


## Un largo (mm) en palabras: «6.1 mm», «24.5 cm», «160 cm».
static func len_txt(mm: float) -> String:
	if mm < 10.0:
		return "%s mm" % Js.to_fixed(mm, 1)
	return "%s cm" % Js.to_fixed(mm / 10.0, 1 if mm < 100.0 else 0)


## «de la chapa», «del plástico».
static func _de(noun: String) -> String:
	return "del " + noun.substr(3) if noun.begins_with("el ") else "de " + noun


## El espesor de la carrocería en palabras: «0.7 mm».
static func thick_txt(target: Dictionary) -> String:
	var body: Variant = target.get("body")
	return "%s mm" % Js.js_num_str(float(body.t) / 1000.0) if body != null else ""


static func _list(names: Array) -> String:
	var items: Array = names.map(func(n: String) -> String: return _with_article(n))
	if items.size() <= 1:
		return "".join(PackedStringArray(items))
	return "%s y %s" % [", ".join(PackedStringArray(items.slice(0, -1))), items[-1]]


static func _with_article(n: String) -> String:
	var low := n.to_lower()
	if low == "":
		return ""
	return ("la " if low == "imprimación" else "el ") + low


## El veredicto. o: { target, zone, hold (quieto encima o golpe), depthUm (la marca más honda), through (las marcas atraviesan
## el panel), punctThrough (la punta asoma por detrás), holeUm, cutMm (lo que miden las marcas que atraviesan), nClaws,
## pullN (quieto encima: lo que tira de las garras a lo largo del panel), cuts (las garras pueden cortar la carrocería:
## MovingCar.can_cut_body), energyJ (en el golpe: la energía del golpe respecto al coche), film (garras de película),
## tearMm (el desgarro del plástico del motor, si lo hay; −1 si no) }.
## → { level (0-4), id, lengthMm, reachesEdge, opens (null, «puerta»), layers (cutaway), text, why, quality, source }.
static func assess(o: Dictionary) -> Dictionary:
	var target: Dictionary = o.target
	var zone := String(o.get("zone", ""))
	var iz: Variant = MovingCar.IMPACT_ZONES.get(zone)
	var room_m := float(iz.slide_m) if iz != null else float((MovingCar.ZONES.get(zone, {}) as Dictionary).get("slide_m", 1.0))
	var depth := float(o.get("depthUm", 0.0))
	var through := Js.truthy(o.get("through"))
	var punct := Js.truthy(o.get("punctThrough"))
	var n := maxi(int(o.get("nClaws", 1)), 1)
	var r: Variant = tear_toughness(target)
	var body: Variant = target.get("body")
	var out := { "level": 0, "id": "nada", "lengthMm": 0.0, "reachesEdge": false, "opens": null,
		"layers": cutaway(target, depth, through or punct), "text": "", "why": "", "quality": "", "source": "" }
	if body == null:
		return out
	var t_mm := float(body.t) / 1000.0
	if depth > 0.0:
		out.level = 1
		out.id = "marca"
		out.text = pit_txt(target, depth) if Js.truthy(o.get("pit")) else layers_txt(target, depth, false)
	if punct and not through:
		out.level = 2
		out.id = "perfora"
		out.text = "perfora %s de %s (agujeros de Ø %s)" % [String(body.noun), thick_txt(target), Format.fmt_len(float(o.get("holeUm", 0.0)))]
	if through:
		var length := float(o.get("cutMm", 0.0))
		var per := float(r.value) * t_mm if r != null else 0.0
		var force := per * float(n)
		if Js.truthy(o.get("hold")) and r != null and float(o.get("pullN", 0.0)) >= force and force > 0.0:
			length = maxf(length, room_m * 1000.0)  # el viento tira más de lo que frena la raja: corre hasta el borde
		var tear_mm := float(o.get("tearMm", -1.0))
		if tear_mm >= 0.0:
			length = maxf(length, tear_mm)
		length = minf(length, room_m * 1000.0)
		out.lengthMm = length
		out.reachesEdge = length >= room_m * 1000.0 - 1e-6
		out.level = 3 if length > 0.0 else 2
		out.id = "raja" if length > 0.0 else "perfora"
		out.text = "raja %s %s con %d %s" % [len_txt(length), _de(String(body.noun)), n, "garras" if n != 1 else "garra"] \
			if length > 0.0 else "las garras atraviesan %s de %s, pero la raja no corre" % [String(body.noun), thick_txt(target)]
		if r != null:
			out.why = "cada garra abre una grieta de todo el espesor y pide ~%s (%s kJ/m² × %s)" % [
				CarFormat.fmt_n_small(per), Js.js_num_str(Js.js_round(float(r.value))), thick_txt(target)]
			if Js.truthy(o.get("hold")):
				var pull := float(o.get("pullN", 0.0))
				out.why += ("; el viento tira con ~%s, más que las %d garras juntas (~%s): la raja corre hasta el borde del panel" if pull >= force else "; el viento tira con ~%s, menos que las %d garras juntas (~%s): la raja mide lo que resbalan") % [
					CarFormat.fmt_n_small(pull), n, CarFormat.fmt_n_small(force)]
			out.quality = r.quality
			out.source = r.source
		if zone == "puerta" and out.reachesEdge:
			out.level = 4
			out.id = "abre"
			out.opens = "puerta"
			out.text = "abre la puerta: la raja llega al canto de la cerradura"
			out.why += "; ahí va atornillada la cerradura y, suelta de la chapa, la puerta se abre (estimación)"
			out.quality = "estimate"
	out["door"] = door_txt(o, out) if zone == "puerta" else ""
	out["roof"] = roof_txt(o, out) if zone == "techo" else ""
	if Js.truthy(o.get("film")):
		out.text += " (ficción: garras de película)"
		out.quality = "ficcion"
	return out


## Por qué no abre la puerta (o cómo la abre), con los números: la cerradura (LATCH) y los osos de Yosemite (NPS_BEAR).
static func door_txt(_o: Dictionary, a: Dictionary) -> String:
	if a.opens == "puerta":
		return "la raja llega al canto donde va la cerradura (%s de puerta hasta él)" % len_txt(float(a.lengthMm))
	var latch := "abrirla tirando pide más de %s (lo que aguanta como poco la cerradura, FMVSS 206)" % CarFormat.fmt_n(float(LATCH.transverse_n))
	if a.id == "raja":
		return "no la abre: la raja no llega al canto de la cerradura, y %s" % latch
	return "no la abre: %s; los osos que abren coches aparcados doblan el marco por arriba con calma (NPS, Yosemite), no en un golpe" % latch


## Por qué no abre el techo entero, con los números: lo que costaría cortar su contorno (R·t·perímetro) y por qué los zarpazos
## no lo cortan.
static func roof_txt(o: Dictionary, _a: Dictionary) -> String:
	var target: Dictionary = o.target
	var r: Variant = tear_toughness(target)
	var body: Variant = target.get("body")
	if r == null or body == null:
		return ""
	var length_m := float(MovingCar.IMPACT_ZONES.techo.slide_m)
	var perim := 2.0 * (length_m + float(ROOF.width_m))
	var e_j := float(r.value) * float(body.t) / 1000.0 * perim  # kJ/m² × mm × m = J
	var txt := "no abre el techo entero: cortar su contorno (~%s m) pediría ~%s" % [Js.to_fixed(perim, 1), MovingCar.fmt_energy(e_j)]
	if not Js.truthy(o.get("cuts")):
		return txt + ", pero sus garras no cortan %s: solo la rayan" % String(body.long)
	return txt + ", y los zarpazos solo cortan hacia donde arrastran (tiras a lo largo); el techo va pegado a los largueros y a los arcos: sin cortes de través, las tiras siguen sujetas por los dos extremos"
