## Tribología biológica · cetrería: el guiado del tutorial (unidad 5y), sin nodos y determinista.
##
## Con «Tutorial activado» y el interruptor «Guiado» encendido, cada paso del tutorial (claw_care_tutorial.gd) y, dentro de él,
## cada acción que falta apuntan a un objetivo con id estable, con su valor exacto y un aviso corto para la pantalla del juego:
## la herramienta que hay que coger de la bandeja, la garra y su zona en la vista 3D o un mando del panel (la sujeción, la
## pausa, «Siguiente», el interruptor del torno, el ángulo…). El objetivo sale del estado de ahora, no de una lista fija: si
## sangra, parar la sangre; si se estresa, la pausa; si se ha soltado, recogerla; si hay que corregir algo (una grieta, una
## punta demasiado fina, el calor que llega a la carne viva), el aviso lo dice y señala lo que lo arregla.
##
## El formato es el común de la reforja (la 5x, guide_target.gd): { id, where («scene» | «panel»), view, label, hint, value }.
## Lo propio de la cetrería va al lado:
##   kind      «herramienta» (la de la bandeja), «garra» (una zona de la garra que se trabaja), «pata» (otra garra) o «mando»;
##   tool      la herramienta que se resalta en la bandeja (también en «garra», la que se usa); zone, s_mm, paw y digit;
##   act       lo que es «pulsar» el objetivo: una orden del estado { op, args } (pick, set_angle, rest, recapture…), un gesto
##             sobre la garra { op: «gesto», kind, s_mm, along_mm, secs } o { op: «esperar», args: [s] } (para los tests y
##             la demo, que juegan pulsando solo lo señalado);
##   tone      «bien» | «aviso» | «mal»; reason: «paso», «sangra», «estres», «suelta», «corrige», «parada» o «fin»; step
##             (proceso/paso) y key (cambia cuando cambia lo que se enseña).
## Los ids: «bandeja:<herramienta>», «garra:<zona>», «pata:<pata>|<dedo>» y los del panel: «sedacion:<id>», «humedad:<id>»,
## «vista:<id>», «reloj:<×>», «rpm:<i>», «mano:angulo», «mano:presion», «pieza:<id>» y «boton:<id>» (BUTTONS).
## La carne viva de una garra oscura no se revela: el guiado solo dice lo que se ve (la señal del corte, la banda de la
## población); en una garra clara (el tigre) da su distancia.
## Los números del guiado que no son física (cuánto cortar de cada vez, la pasada corta, el toque del torno…) son elecciones
## del juego, marcadas «juego» (GAME); los de la física, del motor y de sus fichas.
## Uso: const Guide = preload("res://core/lab/claw_care_guide.gd"); Guide.target(state, snapshot, tutorial_view).
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")

## Las zonas de la garra que la escena sabe enseñar (las de ClawCareState.STEP_HINTS, más «herida»).
const ZONES := ["punta", "sobrante", "herida", "pasada", "angulo", "garra", "base", "banda", "carne_viva"]
## Los botones del panel que puede señalar el guiado.
const BUTTONS := ["siguiente", "terminar", "probar", "pausa", "calmar", "recoger", "empezar", "seguir", "torno", "informe", "tienda"]
## Las vistas de la cámara (las de la página).
const VIEWS := ["garra", "general", "seccion", "animal"]
## Números del guiado que son elecciones del juego, no física: el trozo que se corta de cada vez («poco a poco», como pide
## el tutorial), lo que se deja para la lima, el trozo más pequeño, la pasada larga y la corta, la punta a partir de la cual
## se desbasta con la gruesa (× la natural), el toque de la herramienta giratoria (s y N, «toques cortos, sin apretar»), el
## toque ligero de frente que le deja una cara diminuta a una punta de aguja (N y mm), cómo se acorta la pasada con la fina
## al acercarse a la punta buena (mm por cada × de más desde fine_from), el margen del ángulo (°) y de la presión (×), y desde
## cuántos grados por debajo del umbral del dolor se avisa del calor.
const GAME := {
	"cut_step_mm": 2.0, "keep_mm": 0.3, "min_cut_mm": 0.3, "long_mm": 100.0, "short_mm": 10.0, "rough_ratio": 4.0,
	"touch_s": 0.5, "touch_n": 0.5, "light_n": 0.3, "light_mm": 1.0, "fine_k_mm": 25.0, "fine_from": 1.6, "angle_tol": 3.0, "force_tol": 1.3, "heat_warn_c": 2.0,
	"quality": "juego",
}
## Cómo se nombra cada herramienta en el aviso corto (con su artículo y su tecla, si la tiene).
const TOOL_PHRASE := {
	"lima_bastarda": "la lima gruesa (1)", "lima_fina": "la lima fina (2)", "torno": "el torno (3)",
	"guillotina": "el cortaúñas de guillotina (4)", "amoladora": "la amoladora (5)", "lima_entrefina": "la lima entrefina",
	"lima_diamante_gruesa": "la lima de diamante gruesa", "lima_diamante_fina": "la lima de diamante fina",
	"lija_p180": "la lija P180", "lija_p240": "la lija P240", "tijera": "el cortaúñas de tijera", "tenaza": "las tenazas",
	"agua": "el agua tibia", "presion": "la gasa", "hemostatico": "el polvo hemostático", "nitrato_plata": "el nitrato de plata",
	"clorhexidina": "la clorhexidina", "crema": "la crema", "metacrilato": "el metacrilato", "alcohol": "el alcohol",
	"espatula": "la espátula",
}
## Las herramientas de desbastar y de afinar, por orden de preferencia (la primera que muerda el material).
const ROUGH_TOOLS := ["lima_bastarda", "lima_diamante_gruesa"]
const FINE_TOOLS := ["lima_fina", "lima_diamante_fina", "lima_entrefina"]
## Lo que se acepta en la mano para cada papel (si ya se tiene una, no se pide otra).
const ROUGH_OK := ["lima_bastarda", "lima_diamante_gruesa"]
const FINE_OK := ["lima_fina", "lima_entrefina", "lima_diamante_fina", "lija_p180", "lija_p240"]
const STOP_OK := ["hemostatico", "nitrato_plata"]


## El formato común del objetivo (el de la 5x, guide_target.gd): id, dónde (escena o panel), la vista de la cámara, la etiqueta
## junto al resaltado, el aviso corto y su valor.
static func make(id: String, where: String, view: String, label: String, hint: String, value: String = "") -> Dictionary:
	return { "id": id, "where": where, "view": view, "label": label, "hint": hint, "value": value }


## El objetivo de ahora, o {} si no hay guiado (sin tutorial, con «Guiado» apagado o sin nada que hacer). st: el
## ClawCareState; sn: su snapshot (el de view()); tv: su tutorial_view.
static func target(st: Object, sn: Dictionary, tv: Dictionary) -> Dictionary:
	var g := _resolve(st, sn, tv)
	if g.is_empty():
		return {}
	for k: String in ["kind", "tool", "zone", "tone", "reason", "step"]:
		if not g.has(k):
			g[k] = ""
	if not g.has("act"):
		g["act"] = {}
	if not g.has("s_mm"):
		g["s_mm"] = -1.0
	g["paw"] = String(g.get("paw", st.paw))
	g["digit"] = String(g.get("digit", st.digit))
	g["key"] = "%s|%s|%s|%s|%s" % [String(g.id), String(g.hint), String(g.value), String(g.view), String(g.tool)]
	return g


static func _resolve(st: Object, sn: Dictionary, tv: Dictionary) -> Dictionary:
	var pid := String(tv.get("process", ""))
	var step: Dictionary = tv.get("step", {})
	var sid := String(step.get("id", ""))
	var where := "%s/%s" % [pid, sid]
	# la sesión parada: la rapaz que se ha soltado se recoge; lo demás, de nuevo
	var halted: Dictionary = st.halted
	if not halted.is_empty():
		if bool(halted.get("recoverable", false)):
			var ch := float(Reaction.RECAPTURE.chance)
			return _panel("boton:recoger", "Recogerla", "Recógela con la toalla y encapúchala",
				"%s %% de zarpazo (juego)" % Js.to_fixed(ch * 100.0, 0), { "op": "recapture" }, "mal", "suelta", where)
		return _panel("boton:empezar", "Empezar de nuevo", "Sesión parada: empieza de nuevo (R)", "", { "op": "restart" }, "mal", "parada", where)
	if bool(st.finished):
		if bool(tv.get("done", false)):
			return _panel("boton:informe", "El informe", "Mira el informe: la nota y los consejos", "", {}, "bien", "fin", where)
		return _panel("boton:seguir", "Seguir", "Sigue con esta garra", "", { "op": "resume" }, "aviso", "paso", where)
	if bool(st.paused):
		return _panel("boton:pausa", "Quitar la pausa", "Quita la pausa (Espacio)", "", { "op": "set_paused", "args": [false] }, "aviso", "paso", where)
	var R: Dictionary = CareData.ANIMAL_RISK
	var p: Object = st.patient
	var aid := String(st.setup.animal)
	# a punto de revolverse: parar y calmarlo (lo primero, antes que la herida)
	if bool(p.reaction_warning) and not bool(p.resting):
		return _calm_target(st, where, "¡Va a revolverse! Para y cálmalo")
	# la sangre: coger el polvo hemostático y apretar sobre la herida
	var bl: Dictionary = sn.bleeding
	if bool(bl.active):
		return _bleed_target(st, sn, where)
	# otra garra del animal que sangra (sigue su reloj aunque no se vea): ir a ella
	var other: Array = st.bleeding_elsewhere()
	if not other.is_empty():
		var op := String(other[0])
		var od := String(other[1])
		var g := _base("pata:%s|%s" % [op, od], "scene", "animal", "Sangra",
			"Sangra la %s: ve a ella" % String(st.claw_label(aid, op, od)), "", "pata", "mal", "sangra", where)
		g["paw"] = op
		g["digit"] = od
		g["act"] = { "op": "select_claw", "args": [op, od] }
		return g
	# el estrés: sujetarlo como pide su especie, la pausa para calmarlo y esperar a que baje
	var restrained := bool(p.restrained())
	if aid == "rapaz" and not restrained and bool(p.handled) and float(p.stress) >= float(R.restless):
		return _panel("sedacion:sujecion", "Capucha y toalla", "Encapúchala y envuélvela en la toalla",
			"estrés %s %%" % Js.to_fixed(float(p.stress) * 100.0, 0), { "op": "set_sedation", "args": ["sujecion"] }, "mal", "estres", where)
	# sin la sujeción que pide su especie no se le tocan las garras (aunque se haya saltado «Preparar al animal»)
	if not restrained and pid != "preparar":
		return _sedation(st, "sujecion" if aid == "rapaz" else "anestesia",
			"Antes de tocarla: capucha y toalla" if aid == "rapaz" else "Antes de tocarle las garras: anestésialo", where, "corrige")
	if bool(p.resting):
		return _rest_target(st, where)
	if restrained and bool(p.handled) and float(p.stress) >= float(R.stressed):
		return _calm_target(st, where, "Se está estresando: pausa para calmarlo")
	# lo que hay que corregir (lo dice el aviso y se señala lo que lo arregla)
	var fix := _fix_target(st, sn, pid, where)
	if not fix.is_empty():
		return fix
	# el paso del tutorial
	if bool(tv.get("done", false)) or step.is_empty():
		return _panel("boton:terminar", "Terminar", "Termina y mira el informe", "", { "op": "finish" }, "bien", "fin", where)
	if pid == Tutorial.BOND_PROCESS:
		return _bond_target(st, sn, step, tv, where)
	return _step_target(st, sn, tv, step, where)


# ─────────────────────────────── Lo que manda el estado ───────────────────────────────

static func _bleed_target(st: Object, sn: Dictionary, where: String) -> Dictionary:
	if not STOP_OK.has(String(st.tool)):
		var g := _tool_target(st, "hemostatico", "Sangra: coge el polvo hemostático", "", where)
		g["tone"] = "mal"
		g["reason"] = "sangra"
		return g
	var bl: Dictionary = sn.bleeding
	var agent := float(CareData.HEMOSTASIS.agent_s.value)
	var left := float(bl.needS) if String(bl.agent) != "" else agent
	var g := _claw_target(st, sn, "herida", "Pon el polvo hemostático y aprieta", "faltan %s s" % Js.to_fixed(ceilf(maxf(left, 0.0)), 0),
		{ "op": "gesto", "kind": "presion", "secs": left + 0.5 }, where)
	g["tone"] = "mal"
	g["reason"] = "sangra"
	return g


static func _calm_target(st: Object, where: String, hint: String) -> Dictionary:
	return _panel("boton:calmar", "Pausa para calmarlo", hint, "estrés %s %%" % Js.to_fixed(float(st.patient.stress) * 100.0, 0),
		{ "op": "rest", "args": [true] }, "mal", "estres", where)


## En la pausa: esperar a que baje de «inquieto» (con el reloj acelerado si va a ×1) y seguir.
static func _rest_target(st: Object, where: String) -> Dictionary:
	var p: Object = st.patient
	var low := float(CareData.ANIMAL_RISK.restless)
	var val := "estrés %s %% (sigue por debajo de %s %%)" % [Js.to_fixed(float(p.stress) * 100.0, 0), Js.to_fixed(low * 100.0, 0)]
	if float(p.stress) < low:
		return _panel("boton:calmar", "Seguir trabajando", "Ya está tranquilo: sigue trabajando", val, { "op": "rest", "args": [false] }, "bien", "estres", where)
	if float(st.time_scale) < 10.0:
		return _panel("reloj:10", "Reloj ×10", "Espera a que se calme: acelera el reloj", val, { "op": "set_time_scale", "args": [10.0] }, "aviso", "estres", where)
	return _panel("boton:calmar", "Esperando", "Espera a que se calme, sin tocarlo", val, { "op": "esperar", "args": [1.0] }, "aviso", "estres", where)


## Lo que hay que corregir antes de seguir: una grieta que dejó el cortaúñas, una punta demasiado fina, el calor que llega a
## la carne viva o la carne viva que ya está cerca (la señal del corte, o su distancia si se ve).
static func _fix_target(st: Object, sn: Dictionary, pid: String, where: String) -> Dictionary:
	var th: Dictionary = sn.thermal
	var pain := float(th.painC)
	var q := float(th.quickC)
	var warn := float(GAME.heat_warn_c)
	if not bool(st.is_reforged()) or sn.claw.get("block") != null:
		if bool(st.rotary_on) and st.is_rotary(String(st.tool)) and q >= pain - warn:
			var g := _panel("boton:torno", "Apagar", "Para: la carne viva está a %s °C" % Js.to_fixed(q, 1), "duele desde %s °C" % Js.to_fixed(pain, 0),
				{ "op": "set_rotary", "args": [false] }, "mal", "corrige", where)
			return g
		var face := float(th.get("faceC", q))
		if not bool(st.rotary_on) and face > q + 1.0 and q >= pain - 2.0 * warn:
			var wg := _claw_target(st, sn, "punta", "Espera: el calor sigue llegando a la carne viva", "%s °C ↑" % Js.to_fixed(q, 1),
				{ "op": "esperar", "args": [1.0] }, where)
			wg["reason"] = "corrige"
			return wg
	if pid in ["sangrado", "reconstruir", Tutorial.ATTACK_PROCESS]:
		return {}
	var dmg: Dictionary = sn.damage
	var shape: Dictionary = sn.shape
	# la carne viva, cerca: no se quita más largo (ni para quitar una grieta de frente); se sigue con la punta
	if bool(shape.sign) and pid in ["recortar", "limar"]:
		var cover: Variant = shape.quickCoverMm
		var hint := "Para: la carne viva está a %s mm" % Js.to_fixed(float(cover), 1) if cover != null else "Para: el centro del corte se oscurece"
		return _panel("boton:siguiente", "Siguiente", hint, "%s mm" % Js.to_fixed(float(cover), 1) if cover != null else "la carne viva, cerca",
			{ "op": "tutorial_next" }, "mal", "corrige", where)
	var splits: Array = (dmg.splits as Array).filter(func(sp: Dictionary) -> bool: return not bool(sp.reaches_quick))
	if not splits.is_empty() and not bool(dmg.broken) and not bool(shape.sign):
		var apex := float(sn.claw.lengthMm)
		var deep := 0.0
		for sp: Dictionary in splits:
			deep = maxf(deep, apex - float(sp.from_s))
		var w := _work(st, sn, {
			"accept": ROUGH_OK, "tool": _biting(st, sn, ROUGH_TOOLS), "angle": 90.0, "zone": "punta",
			"why": "Grieta", "hint": "Grieta: lima la cara del corte de frente (90°)", "value": "faltan %s mm" % Js.to_fixed(maxf(deep, 0.0), 1),
			"gesture": "lima", "along": float(GAME.long_mm) }, where)
		w["reason"] = "corrige"
		w["tone"] = "aviso"
		return w
	# con el torno o la amoladora, la punta se rehace al acabar sus toques (al terminar), no después de cada uno
	if pid == "torno":
		return _mistake_fix(st, where)
	if String(shape.verdict) == "fina":
		var sr: Variant = shape.strengthRatio
		var w := _work(st, sn, {
			"accept": FINE_OK, "tool": _biting(st, sn, FINE_TOOLS), "angle": 90.0, "force": float(GAME.light_n), "zone": "punta",
			"why": "Demasiado fina", "hint": "Demasiado fina: un toque ligero de frente (90°)",
			"value": "aguanta el %s %%" % Js.to_fixed(float(sr) * 100.0, 0) if sr != null else "",
			"gesture": "lima", "along": float(GAME.light_mm), "s_back": 0.3 }, where)
		w["reason"] = "corrige"
		w["tone"] = "aviso"
		return w
	# al terminar, la punta tiene que seguir buena: si ha quedado roma, se vuelve a afilar
	if pid == "terminar" and String(shape.verdict) == "roma":
		var w2 := _sharpen_target(st, sn, where, "Roma")
		w2["reason"] = "corrige"
		w2["tone"] = "aviso"
		return w2
	return _mistake_fix(st, where)


## Lo que avisa el motor y se arregla con otra herramienta o con la sujeción.
static func _mistake_fix(st: Object, where: String) -> Dictionary:
	var mk: Dictionary = st.mistake_view()
	match String(mk.get("code", "")):
		"no_cabe", "aplasta", "aplasta_punta":
			var tid := "tenaza" if String(st.setup.animal) != "rapaz" else "guillotina"
			# solo mientras se corta (con otro cortaúñas en la mano)
			if String(st.tool) in ["guillotina", "tijera", "tenaza"] and String(st.tool) != tid:
				var g := _tool_target(st, tid, "%s: coge %s" % [("No cabe" if String(mk.code) == "no_cabe" else "Aplasta"), String(TOOL_PHRASE.get(tid, tid))], "", where)
				g["reason"] = "corrige"
				g["tone"] = "aviso"
				return g
		"se_mueve":
			var want := "sujecion" if String(st.setup.animal) == "rapaz" else "anestesia"
			if String(st.patient.sedation) != want:
				return _sedation(st, want, "Se mueve de dolor: %s" % ("encapúchala" if want == "sujecion" else "anestésialo"), where, "corrige")
	return {}


# ─────────────────────────────── Cada paso del tutorial ───────────────────────────────

static func _step_target(st: Object, sn: Dictionary, tv: Dictionary, step: Dictionary, where: String) -> Dictionary:
	var sid := String(step.id)
	var goal := String(tv.get("goal", step.get("title", "")))
	var tip_zone := float(st.tip_zone_mm())
	var claw: Dictionary = sn.claw
	var good := _good_angle(sn)
	var good_txt := "%s°" % Js.to_fixed(good, 0)
	var ratio := float(sn.tip.ratio)
	match sid:
		"capucha", "toalla", "calma_capucha":
			return _sedation(st, "sujecion", "Pon la capucha y la toalla", where)
		"anestesia", "calma_sedar":
			return _sedation(st, "anestesia", "Anestésialo antes de tocarle las garras", where)
		"remojar":
			return _work(st, sn, { "accept": ["agua"], "tool": "agua", "zone": "garra", "hint": "Remoja la garra con agua tibia", "gesture": "remojar" }, where)
		"tenaza", "guillotina":
			return _tool_target(st, sid, "Coge %s" % String(TOOL_PHRASE[sid]), "", where)
		"poco":
			return _cut_target(st, sn, true, where)
		"cara":
			return _work(st, sn, { "accept": ROUGH_OK, "tool": _biting(st, sn, ROUGH_TOOLS), "angle": 90.0, "zone": "punta",
				"hint": "Lima la cara del corte de frente (90°)", "value": "90°", "gesture": "lima", "along": float(GAME.long_mm) }, where)
		"a_favor", "curva":
			return _work(st, sn, { "accept": ROUGH_OK, "tool": _biting(st, sn, ROUGH_TOOLS), "angle": good, "zone": "pasada",
				"hint": "Lima de la base a la punta a %s" % good_txt, "value": good_txt, "gesture": "lima", "along": float(GAME.long_mm) }, where)
		"grueso_fino":
			return _tool_target(st, _biting(st, sn, ROUGH_TOOLS), "Primero la gruesa: coge %s" % String(TOOL_PHRASE.get(_biting(st, sn, ROUGH_TOOLS), "")), "", where)
		"humedad":
			if String(claw.humidity) != "natural":
				return _panel("humedad:natural", "Natural", "Déjala orear: humedad natural para limar", String(claw.humidityName),
					{ "op": "set_humidity", "args": ["natural"] }, "aviso", "paso", where)
		"largo":
			return _length_target(st, sn, where)
		"faceta", "no_aguja", "lupa", "fragil":
			return _sharpen_target(st, sn, where)
		"lima_fina":
			var fine := _biting(st, sn, FINE_TOOLS)
			if not FINE_OK.has(String(st.tool)):
				return _tool_target(st, fine, "Coge %s" % String(TOOL_PHRASE.get(fine, fine)), "", where)
		"probar":
			return _panel("boton:probar", "Probar la punta", "Prueba la punta en una uña (T)", "punta ×%s" % Js.to_fixed(ratio, 1),
				{ "op": "probe_tip" }, "aviso", "paso", where)
		"lento":
			if String(st.tool) != "torno":
				return _tool_target(st, "torno", "Coge el torno (3)", "6500 rpm", where)
			if int(st.rpm_index) != 0:
				return _rpm(st, 0, where)
		"toques", "velocidades", "flanco":
			var rot := "amoladora" if sid == "velocidades" or (sid == "flanco" and String(st.tool) == "amoladora") else "torno"
			if sid == "flanco" and st.is_rotary(String(st.tool)):
				rot = String(st.tool)
			var done_txt := String(tv.get("progress", {}).get("step_text", ""))
			return _work(st, sn, { "accept": [rot], "tool": rot, "rpm": 0, "force": float(GAME.touch_n), "rotary": true,
				"angle": roundf(float(sn.tip.alphaDeg)), "zone": "punta",
				"hint": "Toques cortos en la punta: %s s y suelta" % Js.to_fixed(float(GAME.touch_s), 1),
				"value": "%s rpm · %s toques" % [st.grouped(float(st.rpm_steps_of(rot)[0])), done_txt] if done_txt != "" else "%s rpm" % st.grouped(float(st.rpm_steps_of(rot)[0])),
				"gesture": "torno", "secs": float(GAME.touch_s), "s_back": minf(1.0, tip_zone * 0.5) }, where)
		"protector":
			if String(st.tool) != "amoladora":
				return _tool_target(st, "amoladora", "Coge la amoladora (5): apoya la uña en su protector y síguele el ángulo a la garra", "", where)
		"angulo":
			# el semiángulo de la faceta que sigue la curva de la garra (el de la rúbrica de la forma, CareData.MARGINS)
			return _info(st, sn, step, tv, "", "", where, "Inclínala siguiendo la curva de la garra (%s°)" % Js.to_fixed(float(sn.tip.alphaDeg), 0))
		"desinfectar", "calma_curar":
			if not st.care.check("desinfectada"):
				return _work(st, sn, { "accept": ["clorhexidina"], "tool": "clorhexidina", "zone": "herida", "hint": "Pon clorhexidina en la herida",
					"value": "0.05 %", "gesture": "aplicar" }, where)
		"crema":
			return _work(st, sn, { "accept": ["crema"], "tool": "crema", "zone": "garra", "hint": "Pon un poco de crema en la garra", "gesture": "aplicar" }, where)
		"coger":
			return _tool_target(st, "hemostatico", "Coge el polvo hemostático", "", where)
		"hemostatico", "parar":
			return _bleed_target(st, sn, where)
		"metacrilato":
			return _work(st, sn, { "accept": ["metacrilato"], "tool": "metacrilato", "zone": "herida", "hint": "Reconstrúyela con metacrilato", "gesture": "aplicar" }, where)
		"percha", "despertar", "crecer":
			return _panel("boton:terminar", "Terminar", "Termina y mira el informe", "", { "op": "finish" }, "bien", "fin", where)
		"calma_pausa":
			return _calm_target(st, where, "Para y aparta las manos: pausa para calmarlo")
		"calma_espera", "calma_distancia":
			return _rest_target(st, where) if bool(st.patient.resting) else _calm_target(st, where, "Déjalo tranquilo: pausa para calmarlo")
		"calma_lente":
			return _info(st, sn, step, tv, "boton:tienda", "Tienda de lentes", where)
		"calma_seguir":
			if bool(st.patient.resting):
				return _panel("boton:calmar", "Seguir trabajando", "Sigue trabajando, con calma", "", { "op": "rest", "args": [false] }, "bien", "paso", where)
		"dureza":
			return _work(st, sn, { "accept": [], "tool": _biting(st, sn, ROUGH_TOOLS + FINE_TOOLS), "angle": good, "zone": "pasada",
				"hint": "Coge una lima más dura que ella y lima a %s" % good_txt, "value": good_txt, "gesture": "lima", "along": float(GAME.long_mm) }, where)
	# un paso que ya se cumple o que solo se lee: lo que enseña (la vista, la zona) y sigue solo
	return _info(st, sn, step, tv, "", "", where, goal)


## Un paso que solo se lee (o que ya se cumple): la vista que pide, la zona que resalta o «Siguiente»; sigue solo.
static func _info(st: Object, sn: Dictionary, step: Dictionary, tv: Dictionary, id: String, label: String, where: String, goal := "") -> Dictionary:
	var sid := String(step.id)
	var hint := goal if goal != "" else String(tv.get("goal", step.get("title", "")))
	var ui := String(tv.get("ui", ""))
	var left := float(st.read_left_s(step))
	var val := "sigue solo en %s s" % Js.to_fixed(ceilf(left), 0) if String(step.check) == "" else ""
	var wait := { "op": "esperar", "args": [maxf(left, 0.1) + 0.1] } if String(step.check) == "" else { "op": "tutorial_next" }
	if id != "":
		return _panel(id, label, hint, val, wait, "aviso", "paso", where)
	# la vista que pide el paso la pone la cámara sola (la del objetivo)
	var zone := String(tv.get("hint", ""))
	if zone == "bandeja" or ui == "vista:general":
		var g := _base("bandeja", "scene", "general", "La bandeja", hint, val, "herramienta", "aviso", "paso", where)
		g["act"] = wait
		return g
	if zone in ZONES:
		var g := _claw_target(st, sn, zone, hint, val, wait, where)
		if ui.begins_with("vista:"):
			g["view"] = ui.substr(6)
		return g
	if sid != "" and String(step.check) == "":
		return _panel("boton:siguiente", "Siguiente", hint, val, wait, "aviso", "paso", where)
	return _panel("boton:siguiente", "Siguiente", hint, val, { "op": "tutorial_next" }, "aviso", "paso", where)


## Cortar un trozo pequeño del sobrante (poco a poco), sin pasar del largo natural.
static func _cut_target(st: Object, sn: Dictionary, first: bool, where: String) -> Dictionary:
	var claw: Dictionary = sn.claw
	var apex := float(claw.lengthMm)
	var left := float(claw.overgrowthLeftMm) - float(GAME.keep_mm)
	var rem := clampf(left, float(GAME.min_cut_mm) if first else 0.0, float(GAME.cut_step_mm))
	var cutter := "tenaza" if String(st.setup.animal) != "rapaz" else "guillotina"
	var accept := ["tenaza"] if cutter == "tenaza" else ["guillotina", "tijera", "tenaza"]
	# seca, el cortaúñas la raja: antes de cortar, remojada (el paso «Ablandar antes de cortar»)
	if not (String(claw.humidity) in ["humeda", "empapada"]):
		return _work(st, sn, { "accept": ["agua"], "tool": "agua", "zone": "garra", "why": "Antes de cortar",
			"hint": "Antes de cortar: remoja la garra", "gesture": "remojar" }, where)
	return _work(st, sn, { "accept": accept, "tool": cutter, "zone": "sobrante", "s_mm": apex - rem,
		"hint": "Corta %s mm de la punta: mantén pulsado" % Js.to_fixed(rem, 1), "value": "%s mm" % Js.to_fixed(rem, 1),
		"gesture": "corte", "secs": 0.6 }, where)


## Hasta su largo: lo que sobra de más se corta a trozos y lo último se lima de frente.
static func _length_target(st: Object, sn: Dictionary, where: String) -> Dictionary:
	var left := float(sn.claw.overgrowthLeftMm)
	if left - float(GAME.keep_mm) >= float(GAME.cut_step_mm) * 0.5 and not bool(st.is_reforged()):
		return _cut_target(st, sn, false, where)
	return _work(st, sn, { "accept": ROUGH_OK, "tool": _biting(st, sn, ROUGH_TOOLS), "angle": 90.0, "zone": "sobrante",
		"hint": "Lima la punta de frente hasta su largo", "value": "quedan %s mm" % Js.to_fixed(maxf(left, 0.0), 1),
		"gesture": "lima", "along": float(GAME.long_mm), "s_back": 0.5 }, where)


## Dar la punta: con la gruesa mientras está muy roma (pasadas largas) y con la fina al acercarse (pasadas cortas), siempre al
## ángulo de la garra.
static func _sharpen_target(st: Object, sn: Dictionary, where: String, why := "") -> Dictionary:
	var ratio := float(sn.tip.ratio)
	var hi := float(CareData.MARGINS.tip_ratio_hi)
	var good := _good_angle(sn)
	var good_txt := "%s°" % Js.to_fixed(good, 0)
	var rough := ratio > float(GAME.rough_ratio)
	var val := "punta ×%s (buena hasta ×%s)" % [Js.to_fixed(ratio, 1), Js.to_fixed(hi, 1)]
	if st.care.check("punta"):
		return _panel("boton:siguiente", "Siguiente", "La punta ya está: sigue", val, { "op": "tutorial_next" }, "bien", "paso", where)
	if rough:
		return _work(st, sn, { "accept": ROUGH_OK, "tool": _biting(st, sn, ROUGH_TOOLS), "angle": good, "zone": "punta",
			"why": why, "hint": "Afila la punta a %s: pasadas largas" % good_txt, "value": val, "gesture": "lima", "along": float(GAME.long_mm), "s_back": 1.0 }, where)
	# cuanto más cerca de la punta buena, más corta la pasada (para no pasarse a una aguja)
	var along := clampf(float(GAME.fine_k_mm) * (ratio - float(GAME.fine_from)), float(GAME.short_mm), 0.6 * float(GAME.long_mm))
	return _work(st, sn, { "accept": FINE_OK, "tool": _biting(st, sn, FINE_TOOLS), "angle": good, "zone": "punta",
		"why": why, "hint": "Afila a %s con pasadas cortas: para a tiempo" % good_txt, "value": val, "gesture": "lima", "along": along, "s_back": 1.0 }, where)


## La colocación de la pieza de la reforja (unidad 5o): el botón de la tarjeta que pide el paso (STEP_UI «pieza:id» o el reloj).
static func _bond_target(st: Object, sn: Dictionary, step: Dictionary, tv: Dictionary, where: String) -> Dictionary:
	var ui := String(tv.get("ui", ""))
	var goal := String(tv.get("goal", step.get("title", "")))
	if ui.begins_with("pieza:"):
		var id := ui.substr(6)
		return _panel(ui, goal, goal, String(tv.get("progress", {}).get("step_text", "")), { "op": "pieza", "args": [id] }, "aviso", "paso", where)
	if ui.begins_with("reloj:"):
		return _panel(ui, "Reloj ×%s" % ui.substr(6), goal, String(tv.get("progress", {}).get("step_text", "")),
			{ "op": "set_time_scale", "args": [float(ui.substr(6))] }, "aviso", "paso", where)
	return _info(st, sn, step, tv, "", "", where, goal)


# ─────────────────────────────── Piezas ───────────────────────────────

## Una acción sobre la garra con lo que pide (en orden): la herramienta, la humedad para limar, las rpm, la presión, el
## ángulo y el interruptor; con todo listo, la zona de la garra con el gesto.
## spec: { accept (las que valen en la mano), tool (la que se pide), rpm, force, angle (−1: el que haya), rotary, zone, s_mm
## (o s_back: lo que se aparta del vértice), hint, value, gesture, along, secs }.
static func _work(st: Object, sn: Dictionary, spec: Dictionary, where: String) -> Dictionary:
	var held := String(st.tool)
	var want := String(spec.get("tool", ""))
	var accept: Array = spec.get("accept", [])
	var ok_tool := held == want or (accept.has(held) and held != "")
	var why := String(spec.get("why", ""))
	if want != "" and not ok_tool:
		return _why(_tool_target(st, want, "Coge %s" % String(TOOL_PHRASE.get(want, want)), String(spec.get("value", "")), where), why)
	var g0 := String(spec.get("gesture", ""))
	# limar, tornear o cortar con el reloj acelerado: cada pasada duraría más en el ensayo (y calentaría más); a ×1
	if g0 in ["lima", "torno", "corte"] and float(st.time_scale) != 1.0:
		return _panel("reloj:1", "Reloj ×1", "Vuelve el reloj a ×1 para trabajar", "×%s" % Js.to_fixed(float(st.time_scale), 0),
			{ "op": "set_time_scale", "args": [1.0] }, "aviso", "paso", where)
	if g0 in ["lima", "torno"] and String(sn.claw.humidity) in ["humeda", "empapada"]:
		return _panel("humedad:natural", "Natural", "Déjala orear: humedad natural para limar", String(sn.claw.humidityName),
			{ "op": "set_humidity", "args": ["natural"] }, "aviso", "paso", where)
	if int(spec.get("rpm", -1)) >= 0 and st.is_rotary(held) and int(st.rpm_index) != int(spec.rpm):
		return _rpm(st, int(spec.rpm), where)
	var f := float(spec.get("force", -1.0))
	if f > 0.0:
		var k := float(GAME.force_tol)
		if float(st.force_n) > f * k or float(st.force_n) < f / k:
			return _why(_panel("mano:presion", "Presión", "Ajusta la presión a %s N (W/S)" % Format.fmt_f(f), "%s N" % Format.fmt_f(f),
				{ "op": "set_force", "args": [f] }, "aviso", "paso", where), why)
	var a := float(spec.get("angle", -1.0))
	if a > 0.0 and not _angle_ok(float(st.angle_deg), a):
		var txt := "%s°" % Js.to_fixed(a, 0) + (" (de frente)" if a >= 80.0 else "")
		return _why(_panel("mano:angulo", "Ángulo", "Pon el ángulo a %s (A/D)" % txt, txt, { "op": "set_angle", "args": [a] }, "aviso", "paso", where), why)
	if bool(spec.get("rotary", false)) and not bool(st.rotary_on):
		var nm := "la amoladora" if held == "amoladora" else "el torno"
		return _panel("boton:torno", "Encender", "Enciende %s (E)" % nm, "%s rpm" % st.grouped(float(st.rpm())), { "op": "set_rotary", "args": [true] }, "aviso", "paso", where)
	var zone := String(spec.get("zone", "garra"))
	var act := { "op": "gesto", "kind": g0, "along_mm": float(spec.get("along", 0.0)), "secs": float(spec.get("secs", 0.0)) }
	var g := _claw_target(st, sn, zone, String(spec.get("hint", "")), String(spec.get("value", "")), act, where)
	if spec.has("s_mm"):
		g["s_mm"] = float(spec.s_mm)
	elif spec.has("s_back"):
		g["s_mm"] = maxf(float(sn.claw.lengthMm) - float(spec.s_back), 0.0)
	g["act"]["s_mm"] = float(g.s_mm)
	g["tool"] = held
	return g


## Lo que hay que corregir delante del aviso de lo que se pide para hacerlo («Grieta: coge la lima gruesa (1)»).
static func _why(g: Dictionary, why: String) -> Dictionary:
	if why != "":
		var h := String(g.hint)
		g["hint"] = "%s: %s" % [why, h.substr(0, 1).to_lower() + h.substr(1)]
	return g


## La herramienta que hay que coger: resaltada en la bandeja (la vista general la enseña entera).
static func _tool_target(st: Object, id: String, hint: String, value: String, where: String) -> Dictionary:
	var e: Dictionary = st.tray_entry(id)
	var key := int(e.get("key", 0))
	var label := String(e.get("short", id)) + (" (%d)" % key if key > 0 else "")
	var g := _base("bandeja:" + id, "scene", "general", label, hint, value, "herramienta", "aviso", "paso", where)
	g["tool"] = id
	g["act"] = { "op": "pick", "args": [id] }
	return g


## Una zona de la garra que se trabaja, en la vista de la garra, con dónde tocar (mm desde la base).
static func _claw_target(st: Object, sn: Dictionary, zone: String, hint: String, value: String, act: Dictionary, where: String) -> Dictionary:
	var claw: Dictionary = sn.claw
	var apex := float(claw.lengthMm)
	var tz := float(st.tip_zone_mm())
	var s := apex * 0.5
	match zone:
		"punta", "angulo", "herida":
			s = maxf(apex - minf(0.5, tz * 0.5), 0.0)
		"sobrante":
			s = maxf(apex - 0.5, float(claw.naturalMm))
		"pasada":
			s = maxf(apex - tz * 0.5, 0.0)
		"base":
			var qb: Array = st.quick_band_mm()
			s = float(qb[0]) * 0.5 if qb.size() == 2 else apex * 0.25
		"banda":
			var qb2: Array = st.quick_band_mm()
			s = 0.5 * (float(qb2[0]) + float(qb2[1])) if qb2.size() == 2 else apex * 0.75
		"carne_viva":
			if bool(st.quick_revealed(sn)) and claw.quickMm != null:
				s = float(claw.quickMm)
	var g := _base("garra:" + zone, "scene", "garra", _zone_label(zone), hint, value, "garra", "aviso", "paso", where)
	g["zone"] = zone
	g["s_mm"] = s
	g["act"] = act.duplicate()
	if String(act.get("op", "")) == "gesto":
		g["act"]["s_mm"] = s
	return g


static func _panel(id: String, label: String, hint: String, value: String, act: Dictionary, tone: String, reason: String, where: String) -> Dictionary:
	var g := _base(id, "panel", "", label, hint, value, "mando", tone, reason, where)
	g["act"] = act
	return g


static func _base(id: String, w: String, view: String, label: String, hint: String, value: String, kind: String, tone: String, reason: String, where: String) -> Dictionary:
	var g := make(id, w, view, label, hint, value)
	g.merge({ "kind": kind, "tone": tone, "reason": reason, "step": where }, true)
	return g


static func _sedation(st: Object, id: String, hint: String, where: String, reason := "paso") -> Dictionary:
	var label := String(st.sedation_label(String(st.setup.animal), id))
	return _panel("sedacion:" + id, label, hint, "", { "op": "set_sedation", "args": [id] }, "aviso", reason, where)


static func _rpm(st: Object, i: int, where: String) -> Dictionary:
	var rot := String(st.rotary_tool())
	var steps: Array = st.rpm_steps_of(rot)
	var v := "%s rpm" % st.grouped(float(steps[mini(i, steps.size() - 1)]))
	return _panel("rpm:%d" % i, v, "Pon %s a %s (Q)" % ["la amoladora" if rot == "amoladora" else "el torno", v], v,
		{ "op": "set_rpm_index", "args": [i] }, "aviso", "paso", where)


## El ángulo bueno de la faceta: el medio de la banda que sigue la curva de la garra (del semiángulo natural de la punta a
## ese más CareData.MARGINS.facet_deg), redondeado al grado (lo que da la tecla A/D).
static func _good_angle(sn: Dictionary) -> float:
	return roundf(float(sn.tip.naturalAlphaDeg) + 0.5 * float(CareData.MARGINS.facet_deg))


static func _angle_ok(now: float, want: float) -> bool:
	if want >= 80.0:
		return now >= 80.0
	return absf(now - want) <= float(GAME.angle_tol)


## La primera herramienta de la lista que muerde el material de la punta (la de acero no muerde una gema; unidad 5l).
static func _biting(st: Object, sn: Dictionary, ids: Array) -> String:
	var s := maxf(float(sn.claw.lengthMm) - 0.5, 0.0)
	for id: String in ids:
		if float(st.care.bites_at(id, s)) > 0.0:
			return id
	return String(ids.back()) if not ids.is_empty() else ""


static func _zone_label(zone: String) -> String:
	return String({
		"punta": "La punta", "sobrante": "El sobrante", "herida": "La herida", "pasada": "De la base a la punta",
		"angulo": "El ángulo", "garra": "La garra", "base": "La base", "banda": "La carne viva, aquí", "carne_viva": "La carne viva",
	}.get(zone, "La garra"))


## Todos los ids que puede dar el guiado para un animal (para los tests: cada uno existe en la escena o en la página).
static func ids_for(st: Object) -> Array:
	var out: Array = []
	for id: String in st.tray_ids():
		out.append("bandeja:" + id)
	out.append("bandeja")
	for z: String in ZONES:
		out.append("garra:" + z)
	for o: Dictionary in st.sedation_options(String(st.setup.animal)):
		out.append("sedacion:" + String(o.id))
	for h: String in ["seca", "natural", "humeda", "empapada"]:
		out.append("humedad:" + h)
	for v: String in VIEWS:
		out.append("vista:" + v)
	for b: String in BUTTONS:
		out.append("boton:" + b)
	out.append_array(["mano:angulo", "mano:presion", "reloj:1", "reloj:10", "reloj:60"])
	for i in (st.rpm_steps_of("amoladora") as Array).size():
		out.append("rpm:%d" % i)
	return out
