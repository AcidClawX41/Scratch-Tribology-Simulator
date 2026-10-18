## Tribología biológica · reforja experimental de garras: el tutorial del horno y de cada receta (unidad 5d). Sin estado.
##
## steps("horno"): el tutorial general, antes de la primera receta: qué es el horno-fundidor (ficción en conjunto), qué
## hace cada mando (ForgeData.CONTROLS), cómo se mete cada carga en su máquina, el tiempo de verdad y la velocidad (5m) y la
## regla de oro de la garra viva.
## steps(receta): la receta paso a paso (5m): en los metales y el vidrio, primero la cera perdida (el modelo de cera de la
## garra, el revestimiento y el quemado de la cera); pesar y cargar el crisol, poner el modo (que elige la máquina), meter la
## carga en ella, los parámetros (con el tiempo de verdad), arrancar y vigilar con el reloj, enfriar (y romper el molde), comprobar; tallar
## por pasadas con las herramientas del lapidario (la sierra, las muelas gruesa y fina y la fresa; lo colado, cortar el
## bebedero y limar; lo sinterizado, repasar), proteger la carne viva, recubrir (opcional), pulir, probar el ajuste y pasar a
## la cetrería, donde se coloca y se acaba a mano (petición 43: el laboratorio no pega la funda).
## steps("piedra"): una piedra comprada (cuarzo, circonita, moissanita, hematites…): no calentarla ni colarla, tallarla por
## pasadas, pulirla, probar el ajuste y pasarla a la cetrería.
## steps("garra_viva"): FICCIÓN, recubrir la garra en el animal: el recubrimiento frío, la barrera sobre la carne viva, poco
## tiempo y solo la punta, y pulir.
## steps("acrilico"): la prótesis de verdad de una garra rota (unidad 5j): parar la sangre, mezclar el acrílico dental,
## aplicarlo sobre lo que queda y limarlo en la cetrería, y rehacerlo cuando la garra crece.
## steps("soldadura"): soldar dos piezas de metal de la funda en la mesa de soldar (unidad 5r; petición 44): la protección de
## los ojos, el método y sus mandos, colocar y alinear las piezas, los puntos a lo largo de la costura, limar el cordón con
## la muela fina, pulir y pasar a la cetrería. Vale para una pieza de metal (o de metal duro) ya hecha y fría, de cualquier
## receta: no cambia el proceso.
## Cada paso es { id, title, text, check, action, source, mistake }:
##   - check: la condición de ClawForge.check() que lo da por hecho («» si es solo informativo);
##   - action: la llamada de ClawForge que lo hace («mix», «fire», «cool», «carve», «protect», «bond», «polish»,
##     «check_load» o «»), con los argumentos recomendados de ClawForge.recommended();
##   - mistake: qué pasa si te equivocas (el defecto que da el motor).
## Uso: const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd"); ForgeTutorial.steps("zafiro").
extends RefCounted

const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Js = preload("res://core/shared/js.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")

const GENERAL := "horno"
const LIVE := "garra_viva"
const STONE := "piedra"
## La prótesis de verdad de una garra rota (unidad 5j): el acrílico dental (ForgeData.PROSTHESIS).
const ACRYLIC := "acrilico"
## Soldar piezas de metal de la funda en la mesa de soldar (unidad 5r).
const WELD := "soldadura"
## La piedra del tutorial de las piedras compradas: la moissanita (SiC), la más dura de las que no hace el horno.
const STONE_DEFAULT := "moissanita"
const PROCESS_NAMES := {
	"horno": "El horno y sus mandos", "garra_viva": "Recubrir la garra viva (ficción)", "piedra": "Piedra comprada",
	"acrilico": "Acrílico dental (la prótesis de verdad)", "soldadura": "Soldar piezas de metal",
	"zafiro": "Zafiro", "rubi": "Rubí", "metal_duro": "Metal duro", "alumina": "Alúmina sinterizada", "acero": "Acero",
	"oro": "Oro colado", "titanio": "Titanio", "vidrio": "Vidrio colado", "diamante_hpht": "Diamante HPHT",
	"diamante_cvd": "Diamante CVD",
}


## Los pasos de un tutorial: «horno» o el id de una receta (ForgeData.RECIPE_IDS). [] si no existe.
static func steps(id: String) -> Array:
	if id == GENERAL:
		return _general()
	if id == LIVE:
		return _live()
	if id == STONE:
		return _stone()
	if id == ACRYLIC:
		return _acrylic()
	if id == WELD:
		return _weld()
	var r := ForgeData.recipe(id)
	if r.is_empty():
		return []
	var out: Array = []
	var pw: Array = []
	for p: Dictionary in r.powders:
		var d: Dictionary = ForgeData.POWDERS[p.id]
		pw.append("%s (%s) %s" % [String(d.name), String(d.formula), _pct(float(p.value))])
	var prod: Variant = ForgeData.inlay_entry(String(r.product))
	var prod_name := String(r.variety) if String(r.variety) != "" else (String(prod.name).to_lower() if prod != null else String(r.product))
	var td: Dictionary = r.temp_c
	var at: Dictionary = r.atmosphere
	var mode_name: String = _option("modo", String(r.mode))
	var atm_name: String = _option("atmosphere", String(at.value))
	var colada := String(r.form) == "colada"
	# 0. la cera perdida de los metales y el vidrio (5m): el modelo de cera con la forma de la garra, el revestimiento y el
	# quemado de la cera, antes de fundir
	if colada:
		_lost_wax_steps(out, r)
	# 1. elegir y pesar
	var mix_text := "Para %s: %s. Pésalo en la balanza: la proporción es en peso." % [prod_name, ", ".join(pw)]
	if r.has("methane"):
		mix_text += " En el gas, un %s de metano en hidrógeno (entre %s y %s)." % [_pct(float(r.methane.value)), _pct(float(r.methane.min)), _pct(float(r.methane.max))]
	if colada:
		mix_text += " Con la cera perdida, que haya bastante para llenar el molde con su bebedero."
	out.append(_s("pesar", "Elegir, pesar y cargar el crisol", mix_text + " Después, «Cargar el crisol».", "mezcla_ok", "mix", String(r.source), _mix_mistake(r)))
	# 2. el modo (la máquina) y los parámetros
	var par := "Modo: %s. Temperatura: %s °C (bien entre %s y %s °C). Atmósfera: %s." % [mode_name, Js.to_fixed(float(td.value), 0), Js.to_fixed(float(td.min), 0), Js.to_fixed(float(td.max), 0), atm_name.to_lower()]
	var pd: Dictionary = r.pressure_mpa
	if String(r.method) == "hpht":
		par += " Presión: %s GPa, por encima de la línea de Kennedy (P = 19,4 + T/40 kbar)." % Js.to_fixed(float(pd.value) / 1000.0, 1)
	elif String(r.method) == "cvd":
		par += " Presión: una fracción de la del aire, para el plasma."
	elif String(at.value) == "vacio":
		par += " En vacío, sin presión."
	else:
		par += " A la presión del aire."
	if r.has("mold"):
		par += " Molde: %s." % _option("mold", String(r.mold.value)).to_lower()
	par += " " + _time_text(r) + " El dial programa el tiempo de verdad; la marcha va a la velocidad que elijas (×60 a ×36 000)."
	out.append(_s("modo", "Poner el modo", "Gira el dial del modo a «%s»: %s" % [mode_name, String(ForgeData.MATERIALS[String(r.product)].route_text)], "modo_ok", "", String(r.source), "Con otro modo no sale: cada material se hace de una forma."))
	# 3. meter la carga en la máquina del modo (5m): el modo elige la máquina
	var mid := _machine_of(r)
	var m: Dictionary = ForgeData.MACHINES[mid]
	out.append(_s("meter", "Meter la carga en su máquina", "%s, en %s: %s; %s. Sin la carga dentro, «Arrancar» no deja." % [String(m.charge_name), String(m.name).to_lower(), String(m.where), String(m.close)], "dentro", "load_machine", String(m.source), "Con la máquina vacía no se arranca; y si la metes en otra máquina, no es la del modo: sácala y métela en la suya."))
	out.append(_s("parametros", "Ajustar los parámetros y arrancar", par, "parametros_ok", "fire", String(td.source), "%s %s %s" % [String(td.low.text), String(td.high.text), String(r.time_s.low.text)]))
	out.append(_s("vigilar", "Vigilar con el reloj", _watch_text(r) + " El reloj dice cuánto lleva y cuánto falta de verdad: en la vida real tardaría lo que marca el dial; aquí, a la velocidad elegida, y se puede cambiar con la marcha en curso sin que cambie lo que sale.", "", "", String(r.source), "Si cambias un parámetro a medias, el cristal o la pieza salen con defectos."))
	# 4. enfriar, romper el molde y comprobar
	var cool_name: String = _option("cool", String(r.cool.value))
	var cool_text := "Enfría: %s." % cool_name.to_lower()
	if String(r.product) == "vidrio":
		cool_text += " El vidrio se recuece en el horno: ~4 h a ~640 °C, 6 h a 482 °C y luego baja a 7-40 °C por hora; en la vida real, más de día y medio."
	elif String(r.form) == "bola":
		cool_text += " La bola sale con tensión interna: en la fábrica se parte a lo largo antes de tallarla."
	elif String(ForgeData.MATERIALS[String(r.product)].family) == "metal":
		cool_text += " Un metal no se agrieta por el salto de temperatura: cede en vez de romperse."
	else:
		cool_text += " Despacio: una pieza frágil se agrieta si el salto de temperatura pasa del que aguanta."
	out.append(_s("enfriar", "Enfriar", cool_text, "enfriada", "cool", String(r.cool.source) + ("; " + ForgeData.SRC_BULLSEYE_TS8 if String(r.product) == "vidrio" else ""), "Un salto brusco agrieta lo frágil (choque térmico); el vidrio sin recocer se rompe solo."))
	if colada:
		out.append(_s("romper", "Romper el molde", "Rompe el molde y saca la pieza: sale con la forma de la garra y su bebedero. El vidrio, un día después, con herramientas de madera o de plástico.", "desmoldada", "divest", ForgeData.SRC_KERR + "; " + ForgeData.SRC_BULLSEYE_TS8, "Con el molde aún caliente no se puede: primero se enfría."))
	out.append(_s("comprobar_pieza", "Comprobar la pieza", "Mira la pieza: %s sin poros ni grietas, del tamaño que pide la funda." % prod_name, "enfriada", "", String(r.source), "Si sale porosa, quemada o pequeña, vuelve a la receta: el motor dice qué parámetro falló."))
	# 5. tallar por pasadas (5m), con las herramientas que tocan
	_carve_steps(out, String(r.product), String(r.form))
	_append_finish(out, String(r.product))
	return out


## La máquina que trabaja con el modo de la receta (la de ClawForge.machine_for, sin cargar el motor).
static func _machine_of(r: Dictionary) -> String:
	match String(r.mode):
		"sintetizar":
			return String(r.method) if String(r.method) in ["verneuil", "hpht", "cvd"] else "verneuil"
		"sinterizar":
			return "sinterizado"
		"induccion":
			return "induccion"
		"fundir_colar":
			return "colada"
	return "calentar"


## La cera perdida de una receta de colada (5m): el modelo de cera de la funda de la garra de su dedo con su bebedero, el
## revestimiento y el quemado de la cera en el horno.
static func _lost_wax_steps(out: Array, r: Dictionary) -> void:
	var prod := String(r.product)
	var mold := String(r.mold.value)
	var cast: Dictionary = ForgeData.CAST[prod]
	var inv: Dictionary = ForgeData.GLASS_INVESTMENT if prod == "vidrio" and mold == "yeso" else ForgeData.INVESTMENTS[mold]
	var b: Dictionary = ForgeData.BURNOUT["vidrio" if prod == "vidrio" and mold == "yeso" else mold]
	out.append(_s("cera", "El modelo de cera de la garra", "La cera perdida: primero, el modelo de cera de la funda con la forma de la garra de su dedo, y su bebedero, más grueso que la pared para que solidifique el último y alimente la pieza mientras encoge. El %s encoge un %s al colarse: la cera se hace a la medida de esa contracción." % [String(ForgeData.inlay_entry(prod).name).to_lower(), _pct(float(cast.shrink.value))], "cera", "wax", String(cast.shrink.source) + "; " + ForgeData.SRC_CAMPBELL + "; " + ForgeData.SRC_SABAU, "Sin compensar la contracción, la funda sale más pequeña que la garra y puede no entrar."))
	out.append(_s("revestir", "Revestir la cera", "%s alrededor de la cera (el selector «Molde»): fragua %s antes de quemarlo y se dilata un %s, que compensa lo que encoge el metal. El yeso vale para el oro y el vidrio; para el acero y el titanio, el de fosfato." % [String(inv.name), _dur(float(inv.set_s.value)), _pct(float(inv.expansion.value))], "revestido", "invest", String(inv.expansion.source) + "; " + String(inv.set_s.source) + "; " + ForgeData.SRC_GYPSUM, "El yeso no aguanta el acero ni el titanio fundidos: se descompone y la pieza sale porosa."))
	out.append(_s("quemar", "Quemar la cera en el horno", "Mete el molde en el horno, el modo «Calentar», y programa arriba %s durante %s: es el %s. En la vida real son horas (con las subidas y las bajadas); el molde queda caliente para colar." % [_c(float(b.top_c)), _dur(float(b.top_hold_s)), String(b.name)], "quemada", "burnout", String(b.source), "Más frío o más corto, la cera no se quema del todo: la colada sale con poros y no llena; el yeso por encima de ~816 °C se descompone."))


## Tallar por pasadas (5m): según lo que sale del horno, con las herramientas del lapidario que tocan.
static func _carve_steps(out: Array, product: String, form: String) -> void:
	var prod: Variant = ForgeData.inlay_entry(product)
	var nm := String(prod.name).to_lower() if prod != null else product
	var hv := float(prod.hv) if prod != null else 0.0
	var ferrous := bool(ForgeData.MATERIALS.get(product, {}).get("ferrous", false))
	var abr := "CBN o corindón (el diamante y el carburo de silicio reaccionan con el hierro y se gastan)" if ferrous else "diamante"
	var src := ForgeData.SRC_ABRASIVES + "; " + ForgeData.SRC_CHAI_LAWN + "; " + ForgeData.SRC_LAPIDARY
	var mistake := "Con una herramienta más blanda no muerde; apretando un borde fino de una pieza frágil, se desconcha; en seco, el vidrio y el cuarzo se agrietan y la muela de diamante se quema."
	match form:
		"colada":
			out.append(_step_args(_s("cortar_bebedero", "Cortar el bebedero", "Corta el bebedero con la sierra de disco, con agua: deja un muñón de ~0,5 mm para limarlo. Herramienta: %s." % abr, "tocho", "carve_to", ForgeData.SRC_HITECH_SAW + "; " + ForgeData.SRC_BULLSEYE_TS8, mistake), { "tool": "sierra" }))
			out.append(_step_args(_s("limar", "Limar el muñón y la piel", "Con la muela fina, pasada a pasada, hasta la silueta de la garra: el muñón del bebedero y la piel de la colada. Sin pasarte: una pasada de más se come la pared.", "tallada", "carve_to", ForgeData.SRC_GENIE + "; " + src, mistake), { "tool": "muela_fina" }))
		"sinterizada", "capa":
			out.append(_step_args(_s("repasar", "Repasar la piel", "La pieza ya sale casi con su forma (sinterizada o crecida sobre su molde): solo se repasa la piel con la muela fina de %s, con agua, hasta la silueta." % abr, "tallada", "carve_to", ForgeData.SRC_GENIE + "; " + src, mistake), { "tool": "muela_fina" }))
		_:
			out.append(_step_args(_s("tocho", "Sacar el tocho", "Pega la pieza en el palo con cera de lapidario y saca el tocho con la sierra de disco de diamante, con agua: un corte por cada extremo de la bola o del cristal, o uno del bloque.", "tocho", "carve_to", ForgeData.SRC_HITECH_SAW + "; " + ForgeData.SRC_DOP, mistake), { "tool": "sierra" }))
			out.append(_step_args(_s("desbastar", "Desbastar con la muela gruesa", "Desbasta con la muela de diamante gruesa (grano 80), con su goteo de agua, pasada a pasada hacia la silueta de la garra. Para cuando sobre menos de una pasada: la gruesa no sigue la línea y se pasaría. %s es de %s HV: la muela tiene que ser más dura." % [nm.substr(0, 1).to_upper() + nm.substr(1), Js.to_fixed(hv, 0)], "desbastada", "carve_to", ForgeData.SRC_GENIE + "; " + ForgeData.SRC_HAEFELI + "; " + src, mistake), { "tool": "muela_gruesa" }))
			out.append(_step_args(_s("vaciar", "Vaciar la funda por dentro", "Con la fresa de diamante del eje flexible, vacía la funda por dentro hasta que entre la garra.", "vaciada", "carve_to", ForgeData.SRC_FOREDOM + "; " + src, mistake), { "tool": "fresa" }))
			out.append(_step_args(_s("forma", "Dar la forma con la muela fina", "Con la muela fina (grano 220), pasada a pasada hasta la silueta de la garra: sigue la línea. Si te pasas, la pared queda más fina; si llega a cero, la funda se agujerea.", "tallada", "carve_to", ForgeData.SRC_GENIE + "; " + src, mistake), { "tool": "muela_fina" }))


## Un paso con sus argumentos propios encima de los recomendados (la herramienta de cada pasada).
static func _step_args(st: Dictionary, args: Dictionary) -> Dictionary:
	st["step_args"] = args
	return st


## Proteger, recubrir, pulir, probar el ajuste y pasar a la cetrería: igual en todas las recetas. Desde la 5m (petición 43) el
## laboratorio no pega la funda ni la prueba con la carga: eso se hace en la cetrería, sobre el animal.
static func _append_finish(out: Array, product: String) -> void:
	var char_c: float = CareData.THERMAL.char_c.value
	out.append(_s("proteger", "Proteger la carne viva", "La garra viva no aguanta el calor: la queratina se quema a ~%s °C y la carne viva duele desde ~43 °C. La funda se hace aparte y se pegará en frío, así que no le llega calor; aun así, cubre la parte viva con una barrera térmica (manta de aerogel, silicona o gel de agua) por si algo caliente la toca. La barrera solo protege lo que tapa: una capa caliente sobre la punta la quema igual." % Js.to_fixed(char_c, 0), "protegida", "protect", String(CareData.THERMAL.char_c.source) + "; " + ForgeData.SRC_PYROGEL + "; " + ForgeData.SRC_WATER, "Sin barrera, cualquier recubrimiento caliente sobre la garra viva la quema (ficción en todo caso: en la realidad no se hace)."))
	out.append(_s("recubrir", "Recubrir la funda (opcional)", "Si quieres una capa aún más dura, recubre la funda aparte, nunca la garra: alúmina por capas atómicas o por pulverización (frías, de nanómetros o micras), nitruro de titanio por PVD (250-400 °C) sobre metal, cromo duro galvánico (baño a 50-65 °C, con pintura conductora si la funda no conduce), alúmina por plasma (capa porosa de ~300 µm), diamante CVD (700-1300 °C) sobre metal duro o titanio, o esmalte vítreo (750-850 °C) sobre metal. Una capa depositada no es zafiro: sale amorfa o policristalina.", "", "", ForgeData.SRC_GRONER + "; " + ForgeData.SRC_SCHNEIDER + "; " + ForgeData.SRC_BALINIT_A + "; " + ForgeData.SRC_HARD_CHROME + "; " + ForgeData.SRC_APS + "; " + ForgeData.SRC_BALMER + "; " + ForgeData.SRC_ENAMEL, "Un recubrimiento sobre un sustrato que no lo admite no agarra (el diamante CVD no crece sobre acero) y uno más caliente de lo que aguanta la funda la deforma o la quema."))
	var e: Variant = ForgeData.inlay_entry(product)
	var hv := float(e.hv) if e != null else 0.0
	out.append(_s("pulir", "Pulir en la pulidora", "Pule en la pulidora (el disco de fieltro o de cuero con pasta) con un abrasivo más duro que la funda (%s HV): para el zafiro, el diamante y el metal duro, pasta de diamante (45 → 9 µm). Una lima de acero (~700 HV) solo pule lo más blando. Pulir deja la superficie lisa sin cambiar la punta; afilarla es de la cetrería." % Js.to_fixed(hv, 0), "pulida", "polish", ForgeData.SRC_FILE_TEST + "; " + ForgeData.SRC_DMT, "Un abrasivo más blando resbala y no pule."))
	out.append(_s("ajuste", "Probar el ajuste", "Prueba la funda en la garra, sin pegarla: tiene que entrar con la holgura que llena el adhesivo (el epoxi, de 0,10 a 0,15 mm y hasta 3,2; el cianoacrilato, hasta 0,15 mm). Una colada que no compensó la contracción sale más estrecha.", "ajuste", "fit", ForgeData.SRC_LOCTITE_GUIDE + "; " + ForgeData.SRC_LOCTITE_401, "Si no entra, la funda no se puede pegar: hay que rehacerla o abrir el hueco."))
	out.append(_s("pasar", "Pasar a la cetrería", "La funda está terminada. «Pasar a la cetrería»: allí, sobre el animal, se coloca a mano (se prepara la garra, se pega con su adhesivo y se sujeta el tiempo que tarda en fijar), se quita lo que rebosa y se acaba a mano: limar las rebabas, dar la forma y afilar. La prueba con la carga se hace allí, ya pegada.", "", "", ForgeData.SRC_LOCTITE_GUIDE + "; " + CareData.SRC_SAMOUR + "; " + ForgeData.SRC_FERREIRA, "Sin terminar (sin la forma, sin pulir o sin que entre en la garra), la cetrería no tiene una funda que colocar."))


## Una piedra comprada: se talla, no se calienta, se pega en frío y se pule.
static func _stone() -> Array:
	var out: Array = []
	var names: Array = []
	for id: String in ["cuarzo", "circonita", "moissanita", "hematites", "swarovski"]:
		var e: Variant = ForgeData.inlay_entry(id)
		names.append("%s (%s HV)" % [String(e.name).to_lower(), Js.to_fixed(float(e.hv), 0)])
	out.append(_s("elegir", "Elegir la piedra", "Elige la piedra: %s. Se compran naturales o cultivadas en fábrica: el horno del taller no llega a hacerlas (la circonita funde a ~2750 °C y la moissanita crece por sublimación a 2300-2500 °C)." % ", ".join(names), "pieza_ok", "choose", ForgeData.SRC_NASSAU_CZ + "; " + ForgeData.SRC_SIC_PVT, "Una piedra más blanda que la lima de diamante se talla deprisa, pero también se raya antes."))
	out.append(_s("no_calentar", "No calentarla ni colarla", "Una piedra comprada no necesita horno, y el calor la estropea: el cuarzo se agrieta al cruzar 573 °C si se enfría deprisa, el diamante se quema al aire desde ~600 °C y el vidrio se comba desde ~726 °C (para verlo, el modo «Calentar»). Tampoco se cuela: un mineral duro no se funde en un taller; se talla.", "", "", ForgeData.SRC_QUARTZ_INV + "; " + ForgeData.SRC_KAPP + "; " + ForgeData.SRC_ABRISA + "; " + ForgeData.NO_CAST_SOURCE, "Calentada y enfriada deprisa, una piedra frágil se agrieta (choque térmico)."))
	_carve_steps(out, STONE_DEFAULT, "bloque")
	_append_finish(out, STONE_DEFAULT)
	return out


## La prótesis de verdad de una garra rota (unidad 5j): el acrílico dental sobre lo que queda de la garra, limado en el
## animal (la técnica del pico de las aves; en una garra, la misma: estimación).
static func _acrylic() -> Array:
	var out: Array = []
	var pe: Dictionary = ForgeData.PROSTHESIS[ACRYLIC]
	# la dureza de las garras de las rapaces (las de la cetrería), para compararla con la del acrílico
	var hv_lo := INF
	var hv_hi := 0.0
	for cid: String in CareData.ANIMALS.rapaz.claws:
		var hv := float(CareData.claw_entry(cid).hv)
		hv_lo = minf(hv_lo, hv)
		hv_hi = maxf(hv_hi, hv)
	var regrow: Dictionary = CareData.ANIMALS.rapaz.regrow_days
	out.append(_s("real", "La prótesis de verdad", "Así se repara de verdad una garra rota: con acrílico dental autopolimerizable (polvo de PMMA y líquido de metacrilato), sin horno ni funda aparte. Los veterinarios reparan así el pico de las aves; en una garra, la misma técnica (estimación: el caso documentado más parecido es el pico). Las otras recetas de este laboratorio son de fantasía.", "", "", String(pe.use_source), ""))
	out.append(_s("sangre", "Parar la sangre y secar", "Primero, en la cetrería, para la sangre (polvo hemostático o lápiz de nitrato de plata, y presión) y deja el muñón limpio y seco: el acrílico no agarra sobre una herida que sangra.", "", "", ForgeData.SRC_SAMOUR_REPAIR + "; " + CareData.SRC_VCA, ""))
	out.append(_s("mezclar", "Llevar el acrílico a la cetrería", "El laboratorio no lo mezcla ni lo aplica: el polvo y el líquido van con la garra a la cetrería (tecla L o el estuche del acrílico), donde se mezclan sobre lo que queda de ella. Fragua en unos minutos sin horno; la reacción desprende algo de calor, pero no el del acrílico que se cuece en caliente, que dañaría el tejido. Queda un bloque con algo de sobra alrededor y delante del largo natural de la garra, para limarlo.", "pieza_ok", "choose", ForgeData.SRC_MATTA + "; " + ForgeData.SRC_ZAFAR_PMMA, "Si la garra aún sangra, la cetrería no deja ponerlo: primero hay que parar la sangre."))
	out.append(_s("pasar", "Aplicarlo y limarlo en la cetrería", "«Pasar a la cetrería»: allí, sobre el animal, el acrílico se aplica sobre lo que queda de la garra y se lima hasta la forma de la natural, con la lima o con la amoladora. Es más blando que la garra (~%s HV contra %s-%s HV la de una rapaz): se lima deprisa y se gasta antes; y conduce el calor tan mal como la queratina." % [Js.to_fixed(float(pe.hv), 0), Js.to_fixed(hv_lo, 0), Js.to_fixed(hv_hi, 0)], "", "", ForgeData.SRC_MATTA + "; " + ForgeData.SRC_ZAFAR_PMMA + "; " + ForgeData.SRC_ASSAEL_PMMA, ""))
	out.append(_s("rehacer", "Rehacerla cuando crezca", "La garra sigue creciendo por debajo y empuja la prótesis: en el pico se rehace cada 8-12 semanas, y una garra arrancada tarda %s-%s meses en volver a crecer." % [Js.to_fixed(float(regrow.min) / 30.0, 0), Js.to_fixed(float(regrow.max) / 30.0, 0)], "", "", ForgeData.SRC_SAMOUR_REPAIR + "; " + String(regrow.source), ""))
	return out


## FICCIÓN: recubrir la garra en el animal, con lo que pasaría de verdad en cada paso.
static func _live() -> Array:
	var out: Array = []
	var char_c: float = CareData.THERMAL.char_c.value
	out.append(_s("ficcion", "Esto es ficción", "Nadie recubre la garra de un animal vivo: en la realidad se hace una funda aparte y se pega en frío, como una corona dental. Aquí el simulador calcula qué le pasaría a la garra.", "", "", String(ForgeData.COATINGS.fundido.source), ""))
	out.append(_s("frio", "Un recubrimiento frío", "La queratina se quema a ~%s °C: solo valen recubrimientos más fríos, como la alúmina por capas atómicas (desde 33 °C) o por pulverización, o la proyección por plasma con la pieza a ~150 °C. El oro fundido (1064 °C) o el zafiro (2053 °C) la queman al tocarla. Y lo que sale es alúmina amorfa o porosa, no zafiro." % Js.to_fixed(char_c, 0), "", "", ForgeData.SRC_GRONER + "; " + ForgeData.SRC_APS + "; " + String(CareData.THERMAL.char_c.source), "Con un recubrimiento caliente, la punta se quema y la capa se funde con la queratina carbonizada."))
	out.append(_s("proteger", "Tapar la carne viva", "Cubre la parte de la garra que tiene carne viva debajo con una barrera térmica: la manta de aerogel conduce unas 8 veces menos que la queratina y aguanta 650 °C; el gel de agua no pasa de 100 °C mientras le queda agua.", "protegida", "protect", ForgeData.SRC_PYROGEL + "; " + ForgeData.SRC_WATER + "; " + ForgeData.SRC_SHINETSU, "Sin barrera, el calor de la capa llega a la carne viva por la pared de la garra, que es fina."))
	out.append(_s("poco", "Poco tiempo y solo la punta", "La capa toca la queratina de la punta y el calor viaja por dentro hasta la carne viva: cuanto más lejos esté y menos dure, menos llega (en la queratina, el calor avanza ~1,7 mm en 30 s y ~8 mm en 10 min).", "", "", CareData.SRC_DIAS + "; " + ForgeData.SRC_INCROPERA, "Con minutos de calor la carne viva pasa de ~43 °C y se lesiona, aunque la queratina no llegue a quemarse."))
	out.append(_s("recubrir", "Recubrir", "Proyecta la alúmina con la garra a ~150 °C unos 30 s: deja una capa porosa de ~300 µm y ~950 HV.", "recubierta", "coat", ForgeData.SRC_APS, "Si la queratina pasa de ~230 °C se quema; si la carne viva se calienta demasiado tiempo, se lesiona."))
	out.append(_s("pulir", "Pulir la capa", "Pule la capa con pasta de diamante: la alúmina (~950 HV) solo la muerde un abrasivo más duro.", "pulida", "polish", ForgeData.SRC_FILE_TEST + "; " + ForgeData.SRC_DMT, "La lima de acero (~700 HV) resbala sobre la alúmina."))
	return out


## Soldar piezas de metal de la funda (5r; petición 44): en la mesa de soldar, con una pieza de metal ya hecha y fría.
static func _weld() -> Array:
	var out: Array = []
	var laser: Dictionary = ClawWeld.METHODS.laser
	var tig: Dictionary = ClawWeld.METHODS.tig
	var braze: Dictionary = ClawWeld.METHODS.braze
	var dn: Dictionary = ClawWeld.DENSITY
	var bz: Dictionary = ClawWeld.BRAZE
	out.append(_s("ojos", "La protección de los ojos", "Léelo y pulsa «Siguiente (N)». Antes de nada, lo que no se ve: %s %s %s Sobre la queratina no se suelda nada (no conduce, se quema a ~%s °C): lo que se suelda es metal con metal, aquí, antes de colocar la pieza." % [String(laser.safety), String(tig.safety), String(braze.safety), Js.to_fixed(float(CareData.THERMAL.char_c.value), 0)], "", "", String(laser.source) + "; " + String(tig.source), ""))
	out.append(_s("preparar", "El método, sus mandos y las piezas en la mesa", "Pulsa «Poner lo recomendado (P)» y después «Colocar en la mesa (Q)»: los mandos quedan en lo que suelda este metal sin perforar la pared (si quieres, cámbialos antes). Qué hace cada método: el láser pulsado (la energía de cada pulso, su duración y el diámetro del punto: por debajo de ~%s MW/cm² el baño es ancho y poco hondo, en conducción; por encima de ~%s, el ojo de cerradura, estrecho y hondo), el micro-TIG (la corriente, el tiempo y el argón) o la soldadura fuerte de plata (la temperatura del soplete y la holgura, para el metal duro y para metales distintos). El mismo metal se funde en un solo baño; dos metales distintos forman intermetálicos frágiles; el titanio, siempre con argón. Al colocar, la punta queda junto a la funda, con la costura alrededor." % [Js.to_fixed(float(dn.conduction), 1), Js.to_fixed(float(dn.keyhole), 1)], "soldadura_lista", "weld_setup", String(laser.source) + "; " + String(tig.source) + "; " + String(braze.source), "Un metal con otro por fusión no sale (intermetálicos); el metal duro no se funde: solo con plata; una gema o la queratina, nunca."))
	out.append(_s("alinear", "Alinear las piezas", "Pulsa «Alinear (I)» o arrastra la punta en la vista. Las piezas se colocan a ojo y quedan desalineadas: el baño no cierra un hueco mayor que el 10 %% de la pared (~%s mm con 1 mm). Alinéalas bajo el microscopio hasta que la junta quede dentro." % Js.to_fixed(0.1, 2), "alineada", "weld_align", String(laser.source), "Con las piezas desalineadas, los pulsos no cuentan: el baño cae en el hueco."))
	out.append(_s("soldar", "Los puntos a lo largo de la costura", "Mantén pulsado el ratón sobre la costura y recórrela entera (o mantén «Un punto (J)»): cada pulso deja un punto y la barra dice cuántos lleva de los que hacen falta (el solape manda: del 60-70 %% para resistencia, del 80-90 %% para que sea estanca). Si vas deprisa quedan huecos: vuelve sobre ellos. Con el soplete, cada tramo tarda ~%s s de verdad. Al cerrar la vuelta, el motor dice qué ha salido: la hondura frente a la pared, el color de la zona soldada y lo que aguanta la unión frente al metal base (nunca más)." % Js.to_fixed(ClawWeld.pulse_period_s("braze"), 0), "soldada", "weld_pulse", String(laser.source) + "; " + ClawWeld.SRC_WATANABE + "; " + ClawWeld.SRC_LI, "Demasiada energía en una pared fina la perfora; poca, falta de fusión; el titanio sin argón sale azul y frágil; la plata fría no moja, y por encima de ~%s °C el fundente se agota." % Js.to_fixed(float(bz.flux_max_c), 0)))
	out.append(_step_args(_s("limar_costura", "Limar el cordón", "Elige la muela fina (G) y da pasadas (T). La costura deja un cordón que sobresale: límalo pasada a pasada, hasta la silueta de la garra (el indicador de la forma lo enseña).", "costura_limada", "carve_to", ForgeData.SRC_GENIE + "; " + ForgeData.SRC_ABRASIVES, "Con la muela gruesa te pasas de la silueta; sin limar, la funda no entra en la garra."), { "tool": "muela_fina" }))
	out.append(_s("pulir_soldada", "Pulir", "Pulsa «Pulir (O)». Pule otra vez la funda entera en la pulidora: la zona soldada queda del color que dio el motor (el titanio con argón, plateado).", "pulida", "polish", ForgeData.SRC_FILE_TEST + "; " + ForgeData.SRC_DMT, "Un abrasivo más blando resbala y no pule."))
	out.append(_s("pasar", "Pasar a la cetrería", "La funda soldada, limada y pulida pasa a la cetrería como siempre, con lo que aguanta su unión: allí se coloca y se pega en frío sobre el animal.", "", "", ForgeData.SRC_LOCTITE_GUIDE + "; " + CareData.SRC_SAMOUR, "Sin limar el cordón ni pulir, la cetrería no tiene una funda que colocar."))
	return out


## El tutorial general: el horno, sus mandos y la regla de oro.
static func _general() -> Array:
	var out: Array = []
	out.append(_s("horno", "El horno-fundidor del taller", "Este horno es de ficción en conjunto: junta en una caja lo que en la industria hacen varias máquinas (un horno de mufla o de vacío, una bobina de inducción, el soplete de Verneuil, una prensa de alta presión y un reactor de plasma). Cada modo usa las temperaturas, presiones y atmósferas de la máquina real.", "", "", String(ForgeData.FURNACE.source), ""))
	for c: Dictionary in ForgeData.CONTROLS:
		var rng := ""
		if c.has("min"):
			rng = " Rango: de %s a %s %s." % [Js.to_fixed(float(c.min), 0), Js.to_fixed(float(c.max), 0), String(c.unit)]
		elif c.has("options"):
			var names: Array = []
			for o: String in c.options:
				names.append(String(c.option_names[o]))
			rng = " Opciones: %s." % ", ".join(names)
		out.append(_s("mando_" + String(c.id), String(c.name), "%s%s %s" % [String(c.what), rng, String(c.why)], "", "", String(c.source), ""))
	# 5m · meter la carga en su máquina y el tiempo de verdad
	var where: Array = []
	for mid: String in ["verneuil", "hpht", "cvd", "sinterizado", "induccion"]:
		var m: Dictionary = ForgeData.MACHINES[mid]
		where.append("%s, %s" % [String(m.charge_name).to_lower(), String(m.where).split(":")[0]])
	var wtxt := "; ".join(where)
	out.append(_s("maquinas", "Cada carga en su máquina", "Lo pesado no arranca en la balanza: hay que meterlo en la máquina del modo y cerrarla. %s. El molde de la cera perdida se mete en el horno para quemar la cera. Sin la carga dentro, «Arrancar» no deja, y dice por qué." % (wtxt.substr(0, 1).to_upper() + wtxt.substr(1)), "", "", ForgeData.SRC_VERNEUIL + "; " + ForgeData.SRC_SUMIYA + "; " + ForgeData.SRC_BALMER + "; " + ForgeData.SRC_GC_GUIDE + "; " + ForgeData.SRC_STEEL_POUR, ""))
	out.append(_s("reloj", "El tiempo de verdad y la velocidad", "El dial del tiempo programa lo que tardaría de verdad (minutos al fundir, horas al sinterizar o al quemar la cera, días en la prensa del diamante). La marcha va a cámara rápida, a la velocidad que elijas (×60, ×600, ×3600, ×36 000 o lo más rápido), y el reloj enseña lo que lleva y lo que falta de verdad. Cambiar la velocidad no cambia lo que sale.", "", "", "las duraciones de cada receta y de cada paso, con su fuente: " + ForgeData.SRC_VERNEUIL + "; " + ForgeData.SRC_SUMIYA + "; " + ForgeData.SRC_COBLE + "; " + ForgeData.SRC_KERR + "; " + ForgeData.SRC_BULLSEYE_TS8, ""))
	out.append(_s("regla", "La regla de oro", "La garra viva no entra en el horno: lo caliente se hace aparte, como una funda, y se pega en frío en la cetrería. Recubrir la garra viva es ficción: el simulador calcula qué pasaría con una barrera sobre la carne viva.", "", "", String(CareData.THERMAL.char_c.source), ""))
	return out


## El nombre visible de una opción de un mando (ForgeData.CONTROLS, por id); la propia opción si no está.
static func _option(control_id: String, option: String) -> String:
	for c: Dictionary in ForgeData.CONTROLS:
		if String(c.id) == control_id:
			return String((c.get("option_names", {}) as Dictionary).get(option, option))
	return option


static func _s(id: String, title: String, text: String, check: String, action: String, source: String, mistake: String) -> Dictionary:
	return { "id": id, "title": title, "text": text, "check": check, "action": action, "source": source, "mistake": mistake }


static func _pct(f: float) -> String:
	var p := f * 100.0
	return "%s %%" % Js.to_fixed(p, 2 if p < 1.0 else (1 if p < 10.0 else 0))


static func _mix_mistake(r: Dictionary) -> String:
	var t: Array = []
	for p: Dictionary in r.powders:
		if p.has("low"):
			t.append(String(p.low.text))
		if p.has("high"):
			t.append(String(p.high.text))
	if r.has("methane"):
		t.append(String(r.methane.low.text))
		t.append(String(r.methane.high.text))
	return " ".join(t) if not t.is_empty() else "Cualquier otro polvo en el crisol contamina el material."


static func _time_text(r: Dictionary) -> String:
	var g: Dictionary = r.get("growth", {})
	if not g.is_empty():
		match String(g.kind):
			"mm_h":
				return "Tiempo: lo que tarda la bola en crecer el largo de la funda, a ~%s mm/h." % Js.to_fixed(float(g.value), 0)
			"mg_h":
				return "Tiempo: lo que tarda el cristal en pesar lo que pide la funda, a ~%s mg/h (días)." % Js.to_fixed(float(g.value), 0)
			"um_h":
				return "Tiempo: lo que tarda la capa en llegar al espesor de la pared, a ~%s µm/h." % Js.to_fixed(float(g.value), 0)
	if String(r.id) == "alumina":
		return "Tiempo: 24 h a 1700 °C, 6-8 h a 1900 °C."
	return "Tiempo: al menos %s." % _dur(float(r.time_s.min))


static func _dur(s: float) -> String:
	if s >= 3600.0:
		return "%s h" % Js.to_fixed(s / 3600.0, 0 if s >= 36000.0 else 1).trim_suffix(".0")
	return "%s min" % Js.to_fixed(s / 60.0, 0)


static func _c(t: float) -> String:
	return "%s °C" % Js.to_fixed(t, 0)


static func _watch_text(r: Dictionary) -> String:
	match String(r.method):
		"verneuil":
			return "Mira la bola: crece hacia abajo con un casquete fundido brillante arriba. Si gotea, la llama está demasiado caliente; si se queda una costra blanca, demasiado fría."
		"hpht":
			return "La prensa mantiene presión y temperatura durante días; el cristal crece dentro de la cápsula sin que se vea."
		"cvd":
			return "El plasma brilla sobre el molde; la capa crece micras por hora."
		"sinterizado":
			return "La pieza encoge mientras se cierran los poros: el metal duro, hasta un 20 %."
	return "Cuando la carga está toda líquida y a su temperatura, cuela de una vez."
