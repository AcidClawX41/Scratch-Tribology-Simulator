## Tribología biológica · los aguijones de insectos en el banco (modelo 2.0; no existen en el motor 1.x).
##
## Integra la física de core/lab/sting.gd (docs/fisica/aguijones.md, guía de integración del §7) en el laboratorio. No
## añade física nueva: junta la de sting.gd con el motor de siempre y escribe los textos.
##   - compute(p): el ensayo completo de un aguijón, con las MISMAS claves que un ensayo 1.x de su clase (punción de la
##     piel o sólido: las que pintan las tarjetas) más `sting`, el bloque del §7.3 (Sting.sting_report). Lo llama
##     Physics.compute cuando la herramienta es un aguijón y el modelo es el 2.0.
##       · Piel: un aguijón siempre pica (sin rayado, desgarro ni golpe, §7.2: el modelo de abrasión de la piel está
##         calibrado con uñas y un aguijón no golpea). Las claves salen de una punción de la 1.x con su herramienta y los
##         hechos, de sting.gd: perfora, profundidad (la longitud útil), capa, sangra, inyecta, severidad y anchura (su
##         diámetro).
##       · Sólidos: Sting.solid_params(p) y el motor de siempre (dureza a la escala de la punta y pandeo como límite de la
##         herramienta), con «SE DOBLA EL AGUIJÓN» en lugar de «SE ROMPE LA PUNTA» y «LA PUNTA SE APLASTA» cuando cede.
##   - adjust_tool(tool, claw, inlay): lo que cambia resolve_tool con un aguijón (§7.1).
##   - Para la interfaz: marcas del deslizador, ficha de la herramienta, fuerza máxima, moraleja, fundamentos y el guion
##     de la animación y de los sonidos del banco (timeline, venom_state), que comparten LabState y bench.gd.
## Unidades: fuerza N (los textos, en mN), longitud mm (µm donde se dice), tiempo ms en el guion y s en los datos.
## Uso: const StingLab = preload("res://core/lab/sting_lab.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Contact = preload("res://core/shared/contact.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")
const Zones = preload("res://core/lab/zones.gd")

const C := Data.C
## Duración del ensayo del banco (LabState.RUN_MS; aquí no se importa lab_state.gd para no cerrar otro ciclo).
const RUN_MS := 1150.0
## Guion de la animación y de sus sonidos (ms desde que se pulsa ARAÑAR). Las fracciones de RUN_MS son las del banco de
## la 1.x (la punción suena al 78 %); las duraciones reales salen de la especificación (§7.6): la inserción (insertionS,
## Zhao 2015), el bombeo del veneno (Schumacher 1994, enseñado ×10) y la retirada o la autotomía. Lo demás es ritmo de
## animación, no dato.
const ANIM := {
	"contact": 0.62,  # fracción de RUN_MS: la punta toca la superficie (antes, el vuelo de llegada)
	"pierce": 0.78,  # fracción de RUN_MS: perfora o cede (el sonido de la punción, LabState.run)
	"insertScale": 0.6,  # ms de pantalla por ms real de inserción: la abeja (1,5 s) tarda 0,9 s
	"solidInsertMs": 120.0,  # en un sólido la punta solo entra µm: un instante
	"holdMs": 250.0,  # quieto con el aguijón dentro
	"pullMs": 420.0,  # tirando (la abeja) o sacándolo (las demás)
	"flyMs": 900.0,  # vuelo de salida
	"pumpSpeedup": 10.0,  # el bombeo se enseña ×10: 1 min real en 6 s (docs/fisica/aguijones.md §7.6)
}
## Artículo de cada especie («la abeja», «el avispón»), para los textos.
const ARTICLE := {
	"abeja": "la", "avispa": "la", "papelera": "la", "avispon": "el", "velutina": "la", "abejorro": "el",
	"hormigabala": "la", "pepsis": "la",
}
## Cómo se nombra lo que la punta tiene que cortar en cada material (para «la punta cede frente a …»).
const TARGET_PHRASE := {
	"madera": "las paredes celulares del pino", "puertamadera": "la laca y las paredes celulares del roble",
	"puertametal": "el aluminio de la puerta", "una": "la uña", "plastico": "el ABS", "coche": "la pintura del coche",
	"cocheclasico": "la pintura del coche", "cochealu": "la pintura del coche", "cocheplastico": "la pintura del coche",
	"cobre": "el cobre", "vidrio": "el vidrio", "acero": "el acero inoxidable", "movil": "la pantalla",
	"cuarzo": "el cuarzo", "zafiro": "el zafiro", "diamante": "el diamante", "cuticula": "la cutícula",
}
## Qué calidad tienen los datos de la ficha (quality de insects.gd).
const QUALITY_TEXT := {
	"primary": "medidos en la especie", "secondary": "de una especie hermana o de revisiones",
	"estimate": "estimados (escalados desde la abeja)",
}
## Fundamento de la 2.0 para la hoja «Fundamentos» (resumen de docs/fisica/aguijones.md).
const FUNDAMENTOS := [
	["Aguijones (2.0)", "una punta de 1-5 µm no aplasta la piel: abre una grieta, F = 2·J·R (Shergold & Fleck 2005), unos 4 mN en la abeja. Después las lancetas lo llevan hasta el bulbo. Antes de perforar es una columna que pandea (Euler, K = 2): la abeja, a ~9 mN. Las púas se enganchan si la piel se cierra detrás (se estira un 54 %; la cutícula de un insecto, un 5 %): la abeja pierde el aguijón (autotomía) y el veneno sigue saliendo, 90 % en 20 s."],
]


## ¿Es un aguijón? (una garra con el bloque `stinger`)
static func is_stinger(tool: Variant) -> bool:
	return Insects.is_stinger(tool)


## El aguijón del catálogo (Insects.STINGERS) de un resultado, por la especie de su bloque `sting`; null si el resultado
## no es de un aguijón. Para pintar un resultado sin el estado del banco (el corte de la piel).
static func claw_of(res: Dictionary) -> Variant:
	var s: Variant = res.get("sting")
	if not (s is Dictionary):
		return null
	for c: Dictionary in Insects.STINGERS:
		if c.stinger.species == s.species:
			return c
	return null


# ════════ EL ENSAYO ════════

## El ensayo de un aguijón en el modelo 2.0. p: los parámetros de Physics.compute con claw = el aguijón.
static func compute(p: Dictionary) -> Dictionary:
	if Js.truthy(p.target.get("skin")):
		return _skin(p)
	return _solid(p)


## Pila de capas de la piel del ensayo: la de la zona del cuerpo (zones.gd; unidad 4b), la del brazo si no la trae.
## Sting.skin_sting la acepta tal cual (docs/fisica/pulido-biologia.md §9.9): la fuerza para perforar no cambia (la capa
## de arriba es la misma), pero el veneno acaba en otra capa. Una piel hecha a mano (target.tissue distinto del de la 1.x:
## la «piel tres veces más tenaz» de docs/fisica/aguijones.md §2.3) manda sobre la zona. p: los parámetros del ensayo.
static func _stack(p: Dictionary) -> Array:
	var target: Variant = p.get("target")
	if target is Dictionary and Js.truthy(target.get("tissue")) and target.tissue != Data.SKIN_LAYERS:
		return target.tissue
	return Zones.stack(Zones.resolve(p.get("zone")).id)


## Fin de la epidermis (µm) de una pila de capas: más allá, la herida sangra.
static func _epidermis_end(stack: Array) -> float:
	for l: Dictionary in stack:
		if l.id == "epidermis":
			return l.to
	return stack[0].to


static func _skin(p: Dictionary) -> Dictionary:
	var claw: Dictionary = p.claw
	var target: Dictionary = p.target
	# 2.0 · la zona del cuerpo (zones.gd): sus capas van al picotazo como las del objetivo (target.tissue)
	var zone: String = Zones.resolve(p.get("zone")).id
	var stack := _stack(p)
	var zoned := p.duplicate()
	var t := target.duplicate()
	t["tissue"] = stack
	zoned["target"] = t
	var s: Dictionary = Sting.sting_report(zoned)
	# Las claves de siempre: una punción de la 1.x con la herramienta del aguijón, sin golpe ni humedad (las fuerzas de
	# Davis que salen de ahí se sustituyen por las de sting.gd)
	var q := p.duplicate()
	q.merge({ "method": "puncion", "strike": false, "tear": false, "wet": false, "model": Physics.MODEL_V1 }, true)
	var r := Physics.compute(q)
	var pierces: bool = s.pierces
	var depth: float = s.depthUm
	r.merge(skin_verdict(s, claw), true)
	r.merge({
		"pierces": pierces, "depthUm": depth, "fPuncture": s.fPunctureN,
		"layer": Physics.skin_layer_at(depth, stack).name if pierces else null,
		"bleeds": pierces and depth > _epidermis_end(stack), "inject": true, "fullReach": pierces,
		# la severidad de una herida de piel en la zona (zones.gd; en el brazo, la de siempre: physics.gd → _skin_severity)
		"sev": maxf(0.3, Zones.severity(zone, depth)) if pierces else 0.08,
		"grooveWidthUm": float(Sting.sval(claw.stinger, "diameterUm")) if pierces else 0.0,
		"energyJ": 0.0, "toolBroken": s.buckled, "sting": s,
		# campos de los materiales de la 2.0 (physics.gd → V2_FIELDS): la piel no tiene fractura, recuperación ni abolladura
		"fracture": null, "nail": null, "recovery": null, "residualDepthUm": depth, "dent": null, "glazing": null,
		"tipChip": null,
		# y de la biología: la zona; un aguijón tiene su propio informe (sting), no el de penetration.gd, y solo pica
		"zone": zone, "pen": null, "tipHv": null, "DpEff": null, "faceDeg": null, "attackDeg": null,
	}, true)
	return r


static func _solid(p: Dictionary) -> Dictionary:
	var target: Dictionary = p.target
	var s: Dictionary = Sting.sting_report(p)
	var q := Sting.solid_params(p)
	q.tear = false  # un aguijón no hace palanca
	var r := Physics.compute(q)
	# campos de los materiales de la 2.0 (fractura, recuperación…): la carga en la punta no pasa de la de pandeo
	r.merge(Physics.materials_fields(q, r, minf(float(q.force), float(q.claw.fBreak))), true)
	# la herramienta del ensayo es el aguijón en su material: el cuaderno lo nombra «… de acero» (Lab.tool_label)
	r.hasGem = s.reforged
	if Js.truthy(r.get("toolBroken")):
		r.merge({
			"verdict": "SE DOBLA EL AGUIJÓN", "vcol": C.gold, "cede": "el aguijón (pandea)", "scratched": r.scratched,
			"vsub": _buckle_text(s, target, r.depthUm),
		}, true)
	elif s.tipCrushed:
		r.merge({
			"verdict": "LA PUNTA SE APLASTA", "vcol": C.mint, "cede": "la punta del aguijón", "scratched": false,
			"vsub": "la punta (%s HV) cede frente a %s (%s HV)" % [_hv(s.tipHv), _phrase(target), _hv(s.targetMicroHv)],
		}, true)
	elif r.depthUm > 1.0 and s.barbsKnown and float(s.barbStrain) > 0.0:
		r.vsub = "%s; no se queda clavado: %s no se cierra tras las púas (recupera un %s %%; la púa pide un %s %%)" % [
			r.vsub, _phrase(target), _pct(s.tissueStrain), _pct(s.barbStrain)]
	r["sting"] = s
	return r


## «el aguijón de acero pandea a ~728 mN tras entrar 73 µm» (§7.4), o sin llegar a entrar y por qué.
static func _buckle_text(s: Dictionary, target: Dictionary, depth_um: float) -> String:
	var head := "el aguijón de %s pandea a ~%s" % [String(s.material) if s.reforged else "quitina", fmt_force(s.fBuckleN)]
	if depth_um >= 0.05:
		return "%s tras entrar %s" % [head, _fmt_depth(depth_um)]
	if s.tipCrushed:
		return "%s sin llegar a entrar: la punta (%s HV) cede frente a %s (%s HV)" % [head, _hv(s.tipHv), _phrase(target), _hv(s.targetMicroHv)]
	return "%s sin llegar a entrar" % head


## Veredicto del picotazo en la piel: { verdict, vsub, vcol, cede, scratched } (los hechos de Sting.skin_verdict).
static func skin_verdict(s: Dictionary, claw: Dictionary) -> Dictionary:
	if s.buckled:
		return {
			"verdict": "SE DOBLA EL AGUIJÓN", "vcol": C.gold, "cede": "el aguijón (pandea)", "scratched": false,
			"vsub": "el aguijón de %s pandea a ~%s antes de romper la piel (hace falta ~%s)" % [
				String(s.material) if s.reforged else "quitina", fmt_force(s.fBuckleN), Sting.fmt_mn(s.fPunctureN)],
		}
	if not s.pierces:
		return {
			"verdict": "NO PERFORA", "vcol": C.mint, "cede": "nada", "scratched": false,
			"vsub": "la piel se hunde pero no se rompe (hace falta ~%s)" % Sting.fmt_mn(s.fPunctureN),
		}
	var mm := Js.to_fixed(float(s.depthUm) / 1000.0, 1)
	var where := _where(s.layerId)
	if s.autotomy:
		return {
			"verdict": "SE QUEDA CLAVADO", "vcol": C.coral, "cede": "la piel y el aparato del aguijón (autotomía)", "scratched": true,
			"vsub": "entra %s mm y deja el veneno %s; las púas se enganchan y %s se va sin su aguijón (arrancarlo cuesta %s veces lo que pesa)" % [
				mm, where, the(claw), Js.js_num_str(Js.js_round(s.pullToWeight))],
		}
	if s.stuck:
		return {
			"verdict": "SE QUEDA CLAVADO", "vcol": C.coral, "cede": "la piel (el aguijón se queda)", "scratched": true,
			"vsub": "entra %s mm, deja el veneno %s y las púas no lo sueltan" % [mm, where],
		}
	var sometimes := " (a veces lo deja si se la aparta a la fuerza)" if s.stuckRisk == "a veces" else ""
	return {
		"verdict": "PICA Y SE VA", "vcol": C.coral, "cede": "la piel (picadura)", "scratched": true,
		"vsub": "entra %s mm, deja el veneno %s y lo saca: puede repetir%s" % [mm, where, sometimes],
	}


static func _where(layer_id: Variant) -> String:
	match String(layer_id if layer_id != null else ""):
		"cornea", "epidermis":
			return "en la epidermis"
		"dermis":
			return "en la dermis"
		"grasa":
			return "en la grasa"
		"fascia":
			return "en la fascia"
		"musculo":
			return "en el músculo"
	return "bajo la piel"


static func _phrase(target: Dictionary) -> String:
	return TARGET_PHRASE.get(target.get("id"), String(target.get("name", "el material")).to_lower())


## Dureza legible (HV): 7.1 · 45.9 · 550.
static func _hv(hv: float) -> String:
	return Js.js_num_str(Js.js_round(hv * 10.0) / 10.0)


## Fuerza legible: en mN hasta 1 N (Sting.fmt_mn: «4.3 mN», «728 mN») y en N a partir de ahí («3.82 N», la abeja de
## diamante).
static func fmt_force(f_n: float) -> String:
	return Sting.fmt_mn(f_n) if f_n < 1.0 else "%s N" % Js.to_fixed(f_n, 2)


## Deformación en %: 0.089 → «8.9».
static func _pct(x: float) -> String:
	return Js.to_fixed(x * 100.0, 1)


static func _fmt_depth(um: float) -> String:
	if um >= 1000.0:
		return Js.to_fixed(um / 1000.0, 1) + " mm"
	return (Js.to_fixed(um, 1) if um < 10.0 else Js.to_fixed(um, 0)) + " µm"


# ════════ LA HERRAMIENTA ════════

## resolve_tool con un aguijón en el modelo 2.0 (§7.1): la cutícula no es queratina (el modo «húmeda» no la ablanda),
## su base es su radio real (diámetro/2, no 0,15 × alcance) y fBreak es su carga de pandeo, también reforjado (en las
## garras 1.x el material nuevo anula fBreak; aquí el pandeo depende del material). Cambia `tool` en su sitio.
static func adjust_tool(tool: Dictionary, claw: Dictionary, inlay: Variant) -> void:
	var mat: Dictionary = inlay if Sting.is_reforged(inlay) else claw
	tool.merge({
		"hv": float(mat.hv), "E": float(mat.E), "keratin": false, "wet": false,
		"baseR": float(Sting.sval(claw.stinger, "diameterUm")) / 2000.0, "fBreak": Sting.buckling(claw, inlay).F,
	}, true)


## Marcas del deslizador de fuerza (§7.5): la fuerza para perforar la piel (null en un sólido) y la carga de pandeo, en
## su material y en quitina. { puncture, buckle, buckleNatural } en N.
static func marks(claw: Dictionary, inlay: Variant, target: Dictionary) -> Dictionary:
	var skin := Js.truthy(target.get("skin"))
	return {
		"puncture": Sting.puncture_force(float(claw.area), _stack({ "target": target })) if skin else null,
		"buckle": Sting.buckling(claw, inlay).F, "buckleNatural": Sting.buckling(claw).F,
	}


# ════════ TEXTOS DE LA INTERFAZ ════════

## «la abeja melífera», «el avispón europeo».
static func the(claw: Dictionary) -> String:
	return "%s %s" % [ARTICLE.get(claw.id, "el"), String(claw.name).to_lower()]


## «de la abeja melífera», «del avispón europeo».
static func of_the(claw: Dictionary) -> String:
	var art: String = ARTICLE.get(claw.id, "el")
	return ("del " if art == "el" else "de la ") + String(claw.name).to_lower()


## Masa del insecto en mg: «70», «478».
static func mass_mg(claw: Dictionary) -> String:
	return Js.js_num_str(Js.js_round(float(claw.mass) * 1e6))


## Botón de fuerza máxima de un aguijón (§7.5): el empuje típico al picar y la masa en mg. { force, label, note }.
static func max_force_hint(claw: Dictionary) -> Dictionary:
	var st: Dictionary = claw.stinger
	var measured: Variant = st.insertionN.get("range")
	var how := "estimado (1,4 veces lo justo para perforar)"
	if measured is Array and measured.size() == 2:
		how = "medido: %s-%s mN" % [_mn_short(measured[0]), _mn_short(measured[1])]
	return {
		"force": claw.force, "label": of_the(claw),
		"note": "empuje típico al picar, %s · peso ~%s mg. El resto lo hacen las lancetas" % [how, mass_mg(claw)],
	}


## Fuerza (N) en mN con dos decimales como mucho y coma decimal: 0.00134 → «1,34»; 0.006 → «6».
static func _mn_short(f_n: Variant) -> String:
	return Js.js_num_str(Js.js_round(float(f_n) * 100000.0) / 100.0).replace(".", ",")


## Fuentes abreviadas de una cita larga («Ramirez-Esquivel F, Ravi S (2023). …; Zhao Z-L … (2015)…» → «Ramirez-Esquivel
## 2023 · Zhao 2015»): el primer autor sin iniciales y el año, o el principio del texto si no es un artículo.
static func short_sources(src: String, max_items := 4) -> String:
	var out: Array[String] = []
	var year_re := RegEx.create_from_string("\\((\\d{4})\\)")
	for part: String in src.split("; "):
		var cut := part.length()
		for sep: String in [",", " ("]:
			var at := part.find(sep)
			if at > 0:
				cut = mini(cut, at)
		var words := part.substr(0, cut).strip_edges().split(" ")
		while words.size() > 1 and _initials(words[-1]):
			words.remove_at(words.size() - 1)
		var who := " ".join(words)
		var m := year_re.search(part)
		var item := ("%s %s" % [who, m.get_string(1)]) if m != null else who
		if not out.has(item):
			out.append(item)
		if out.size() >= max_items:
			break
	return " · ".join(out)


## ¿Son iniciales de un nombre («F», «Z-L», «JO»)?
static func _initials(w: String) -> bool:
	if w.is_empty() or w.length() > 4:
		return false
	for i in w.length():
		var c := w.unicode_at(i)
		if not ((c >= 65 and c <= 90) or c == 45 or c == 46):
			return false
	return true


## Ficha de un aguijón en la tarjeta de la herramienta: pares [clave, valor] (masa en mg, púas, Schmidt, aleteo, fuente y
## calidad). tool: la herramienta resuelta (LabState.tool(), con adjust_tool).
static func spec_rows(claw: Dictionary, inlay: Variant, tool: Dictionary) -> Array:
	var st: Dictionary = claw.stinger
	var reforged := Sting.is_reforged(inlay)
	var base_hv: float = float(st.material.base.H) * 1000.0 / Contact.HV_MPA
	var hard := ("%s HV · Mohs %s" % [_hv(tool.hv), Js.template_str(inlay.get("mohs"))]) if reforged \
		else "%s HV en la punta (base %s HV)" % [_hv(tool.hv), Js.js_num_str(Js.js_round(base_hv))]
	var b: Dictionary = st.barbs
	var barbs := "sin datos"
	if b.get("perLancet") != null:
		var n := int(b.perLancet)
		barbs = "sin púas (lancetas lisas)" if n == 0 else "%d por lanceta · %s" % [n, "se enfundan" if Js.truthy(b.get("sheathable")) else "no se enfundan"]
	elif String(b.get("note", "")).contains("pequeñas"):
		barbs = "pequeñas, sin recuento"
	var sch: Variant = Sting.sval(st, "schmidt")
	var hz: Variant = st.wingbeat.get("hz")
	var wing := "sin medida"
	if hz != null:
		wing = "%s Hz" % Js.js_num_str(hz)
	elif String(st.wingbeat.get("note", "")).contains("no tienen alas"):
		wing = "sin alas"
	return [
		["quitina" if not reforged else String(inlay.short).to_lower(), hard],
		["punta", "R %s µm · α %s°" % [Js.to_fixed(tool.tipRadiusUm, 2), Js.js_num_str(tool.alpha)]],
		["aguijón", "%s mm, entran %s · Ø %s µm" % [Js.js_num_str(Sting.sval(st, "shaftMm")), Js.js_num_str(claw.reach),
			Js.js_num_str(Js.js_round(float(Sting.sval(st, "diameterUm"))))]],
		["púas", barbs],
		["peso", "~%s mg" % mass_mg(claw)],
		["empuje", "~%s" % Sting.fmt_mn(claw.force)],
		["pandea a", "~%s" % fmt_force(tool.fBreak)],
		["Schmidt", Js.js_num_str(sch) if sch != null else "sin valorar"],
		["aleteo", wing],
		["datos", QUALITY_TEXT.get(claw.get("quality"), "—")],
	]


## Moraleja con humor que no traiciona la física (§7.4), o "" si no hay una para este resultado.
static func moral(res: Dictionary, target: Dictionary) -> String:
	var s: Variant = res.get("sting")
	if not (s is Dictionary):
		return ""
	if s.get("pierces") == true:
		if s.autotomy and s.reforged:
			return "La abeja de %s muere igual: la autotomía es del abdomen, no de la aguja." % String(s.material)
		if s.autotomy:
			return "Arrancarlo cuesta %s veces lo que pesa la abeja: por eso lo deja. Cuanto antes lo quites, mejor; da igual cómo (Visscher 1996)." % Js.js_num_str(Js.js_round(s.pullToWeight))
		return "Un aguijón no es un clavo: empuja unos mN y el resto lo hacen las lancetas, que avanzan por turnos."
	if s.get("buckled") == true:
		if s.bucklingMode == "johnson":
			return "Más rígido no basta: con una columna tan corta para su material manda el límite elástico (Johnson), y el %s cede antes de pandear." % String(s.material)
		return "Una aguja tan esbelta pandea (Euler) mucho antes de romperse: la abeja pica cerca de ese límite y corrige el ángulo mientras entra."
	if s.get("tipCrushed") == true:
		if target.get("id") == "madera":
			return "El pino es blando por fuera y duro por dentro: sus paredes celulares son seis veces más duras que la punta."
		if target.get("id") == "cuticula":
			return "Contra otro insecto la abeja pica por las membranas blandas; aun así no se queda: la cutícula no se cierra tras las púas."
		return "Ningún aguijón natural raya nada: su punta (~7-9 HV) es más blanda que una uña."
	if s.get("pierces") == false:
		return "Un aguijón no es un clavo: con menos de ~%s la piel solo se hunde." % Sting.fmt_mn(s.fPunctureN)
	return ""


# ════════ GUION DE LA ANIMACIÓN Y DE LOS SONIDOS ════════

## Momentos del ensayo de un aguijón, en ms desde que se pulsa ARAÑAR: { contact, pierce, insertEnd, pullStart, tear
## (−1 si no hay autotomía), leave, leaveEnd, pumpEnd (−1 si no bombea después), end, entered, stuck, autotomy,
## pumpSpeedup }. `res` es un resultado de compute() con `sting`.
static func timeline(res: Dictionary, run_ms: float = RUN_MS) -> Dictionary:
	var s: Dictionary = res.sting
	var skin := Js.truthy(res.get("skin"))
	var contact: float = ANIM.contact * run_ms
	var pierce: float = ANIM.pierce * run_ms
	var entered: bool = (s.get("pierces") == true) if skin else float(res.get("depthUm", 0.0)) > 1.0
	var ins_s: float = float(s.insertionS) if s.get("insertionS") != null else 1.0
	var insert_ms: float = ins_s * 1000.0 * ANIM.insertScale if skin and entered else ANIM.solidInsertMs
	var insert_end: float = pierce + insert_ms
	var autotomy: bool = s.get("autotomy") == true
	var stuck: bool = s.get("stuck") == true
	var pull_start: float = insert_end + ANIM.holdMs
	var leave: float = pull_start + ANIM.pullMs if entered else maxf(insert_end, run_ms) + ANIM.holdMs
	var tear: float = pull_start + ANIM.pullMs if autotomy else -1.0
	var pump_end := -1.0
	if stuck and s.get("pumpTotalS") != null:
		pump_end = pierce + float(s.pumpTotalS) * 1000.0 / ANIM.pumpSpeedup
	var leave_end: float = leave + ANIM.flyMs
	return {
		"contact": contact, "pierce": pierce, "insertEnd": insert_end, "pullStart": pull_start, "tear": tear, "leave": leave,
		"leaveEnd": leave_end, "pumpEnd": pump_end, "end": maxf(leave_end, pump_end), "entered": entered, "stuck": stuck,
		"autotomy": autotomy, "pumpSpeedup": ANIM.pumpSpeedup,
	}


## Veneno a los ms del guion: { realS (s reales desde que perfora), fraction (0-1), ug (µg, o null sin dato) }. Clavado
## (la abeja), la bomba de válvulas sigue sola y se enseña ×pumpSpeedup; en los véspidos, el saco se exprime mientras
## dura la picadura, a tiempo real (Sting.venom_fraction).
static func venom_state(claw: Dictionary, res: Dictionary, ms: float, run_ms: float = RUN_MS) -> Dictionary:
	var tl := timeline(res, run_ms)
	var st: Dictionary = claw.stinger
	if not tl.entered or not Js.truthy(res.get("skin")) or ms <= float(tl.pierce):
		return { "realS": 0.0, "fraction": 0.0, "ug": 0.0 if st.venom.get("ug") != null else null }
	var real_s: float
	if tl.stuck:
		real_s = (ms - float(tl.pierce)) / 1000.0 * float(tl.pumpSpeedup)
	else:
		real_s = (minf(ms, float(tl.leave)) - float(tl.pierce)) / 1000.0
	return {
		"realS": real_s, "fraction": Sting.venom_fraction(st, real_s), "ug": Sting.venom_delivered_ug(st, real_s),
	}
