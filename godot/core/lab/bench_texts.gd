## Tribología biológica · textos del banco de ensayo para lo nuevo de la 2.0 (unidad 4n), sin nodos y sin física:
##   - la presión que de verdad soporta el contacto (pressure_rows, compare_pressure): la real del motor, min(F/A, la dureza
##     de la punta, la del objetivo), con quién pone el tope. La nominal F/A solo se enseña cuando es la real: por encima de
##     la dureza no tiene sentido (el contacto crece hasta que la presión media iguala la dureza de quien cede; Tabor). Con un
##     contacto elástico (unidad 4p), la media F/A y el pico de Hertz, con la frase que dice cuál es cuál (hertz_note);
##   - χ = P/H legible aunque la punta esté afilada al nanómetro (chi_text);
##   - la ficción del velocirraptor de cine en el resultado (fiction): la etiqueta y lo que haría la garra de verdad;
##   - «Fuentes y estimaciones» de un ensayo (sources, sources_summary): cada dato de la 2.0 que ha usado, con su valor, su
##     calidad y su fuente legible (autor y año, norma o ficha), como la lista del coche en marcha (MovingCarState.sources).
## Los números salen del resultado de compute() y de los catálogos con sus fuentes (zones.gd, attack.gd, claws_v2.gd,
## velociraptor.gd…); aquí solo se escriben, con js.gd y format.gd. Lo usan la tarjeta del resultado, la comparativa y
## LabState (trial_sources).
## Uso: const BenchTexts = preload("res://core/lab/bench_texts.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Contact = preload("res://core/shared/contact.gd")
const Lab = preload("res://core/lab/lab.gd")
## La fuente del contacto elástico de Hertz (unidad 4p): Physics.SRC_HERTZ.
const Physics = preload("res://core/lab/physics.gd")
const Insects = preload("res://core/lab/insects.gd")
const Zones = preload("res://core/lab/zones.gd")
const Attack = preload("res://core/lab/attack.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Penetration = preload("res://core/lab/penetration.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")

const HV_MPA := Contact.HV_MPA
## La presión nominal es la real si no pasa de ella más de un 1 % (el mismo margen con que la 1.x la pintaba en oro).
const CAP_MARGIN := 1.01
## Por encima de este χ el número ya no dice nada más: la presión que pide la punta pasa mil veces de la dureza (una punta
## afilada a decenas de nanómetros da χ de millones).
const CHI_MAX := 1000.0
## Qué dice la calidad de cada dato (las palabras de la lista del coche en marcha, MovingCarState.QUALITY_TEXT).
## «model»: no es un dato sino un modelo publicado (la abolladura, la recuperación, el afilado, el ángulo del deslizador).
const QUALITY_TEXT := {
	"primary": "dato medido", "secondary": "dato de un caso parecido", "estimate": "estimación", "ficcion": "ficción (película)",
	"model": "modelo publicado",
}

# ── Citas de los modelos de la 2.0 que no guardan su fuente en el resultado (las de docs/fisica/pulido-materiales.md §9) ──
const SRC_OLIVER_PHARR := "Oliver WC, Pharr GM (1992). An improved technique for determining hardness and elastic modulus using load and displacement sensing indentation experiments. J. Mater. Res. 7:1564-1583, doi:10.1557/JMR.1992.1564; Stilwell NA, Tabor D (1961). Elastic recovery of conical indentations. Proc. Phys. Soc. 78:169, doi:10.1088/0370-1328/78/2/302"
const SRC_DENT := "Jones N (1989). Structural Impact. Cambridge University Press (carga de colapso de una placa con una carga concentrada); calibrado con la abolladura medida por Nippon Steel (2013): Yonemura S et al., Advanced technologies related to simulation and evaluation for performance of automotive exterior panels, Nippon Steel Technical Report 103:11-17; se ve desde 0,1 mm (US 7 158 922 B2, Ispat Inland 2007)"


# ════════ La presión ════════

## Quién pone el tope a la presión real del ensayo: "" si la nominal F/A es la real (no pasa de ninguna dureza), "punta"
## si la limita la dureza de la herramienta (en la piel, siempre: la piel nunca aplasta la punta) u "objetivo" si la limita
## la del material que se raya. Se compara con las durezas que trae el resultado (tipHv con el esmalte de un colmillo; tHV).
static func pressure_cap(res: Dictionary) -> String:
	var real := float(res.pressure)
	if not (float(res.pNominal) > real * CAP_MARGIN):
		return ""
	if Js.truthy(res.get("skin")) or res.get("tHV") == null:
		return "punta"
	var h_target := float(res.tHV) * HV_MPA
	var tip_hv: Variant = res.get("tipHv")
	var h_tip := float(tip_hv if tip_hv != null else res.get("hvTool", 0.0)) * HV_MPA
	return "objetivo" if absf(real - h_target) <= absf(real - h_tip) else "punta"


## Las dos filas de la presión en la tarjeta del resultado ([etiqueta, símbolo, valor, color], las de ResultCard):
##   - «Presión real»: la del motor, con su tope (la dureza de la punta o la del objetivo) si lo tiene;
##   - «Presión nominal» F/A: su valor cuando es la real, como en la 1.x; si pasa de la dureza, no tiene sentido y se dice
##     (en oro, el color con que la 1.x la avisaba).
## Con un contacto elástico (res.p0MPa, unidad 4p) la presión del motor es F/A, la fuerza repartida por toda la punta, y la
## punta solo toca en el círculo de Hertz: las filas son la «Presión media» F/A y el «Pico de Hertz» en el centro de ese
## círculo (en oro y «cota alta» si la punta o el material ya ceden). hertz_note dice cuál es cuál.
static func pressure_rows(res: Dictionary) -> Array:
	var cap := pressure_cap(res)
	var sym := ""
	if cap == "punta":
		sym = "tope: dureza de la punta"
	elif cap == "objetivo":
		sym = "tope: dureza del objetivo"
	var p0: Variant = res.get("p0MPa")
	if p0 != null:
		var peak_sym := "p0, contacto de %s de radio" % Format.fmt_depth(float(res.hertzRadiusUm))
		var bound := res.get("hertzYield") != null
		if bound:
			peak_sym += " · cota alta"
		return [
			# «por toda la punta (F/A)» y no «F/A, por…»: en la ficha estrecha del teléfono la línea se partía por la barra
			["Presión media", sym if cap != "" else "por toda la punta (F/A)", "%s MPa" % Format.fmt_p(res.pressure), "dim"],
			["Pico de Hertz", peak_sym, "%s MPa" % Format.fmt_p(float(p0)), "gold" if bound else "text"],
		]
	var nominal := ("%s MPa" % Format.fmt_p(res.pNominal)) if cap == "" else "sin sentido: pasa de la dureza"
	return [
		["Presión real", sym, "%s MPa" % Format.fmt_p(res.pressure), "text"],
		["Presión nominal", "F/A", nominal, "gold" if cap != "" else "dim"],
	]


## La frase de la tarjeta que dice cuál es la presión media y cuál el pico de Hertz de un contacto elástico (unidad 4p): la
## media F/A reparte la fuerza por toda la punta, pero la punta solo toca en el círculo de Hertz, con el pico en su centro
## (y dos tercios de media en él). Si la punta o el material ya pasan de su límite elástico, el pico de verdad es menor y la
## presión media no pasa de la dureza de quien cede (la del resultado: tipHv con el esmalte de un colmillo; tHV). "" sin
## contacto elástico (res.p0MPa a null: plástico, en la piel, con pintura o laca, en un golpe o con la 1.x).
static func hertz_note(res: Dictionary) -> String:
	var p0: Variant = res.get("p0MPa")
	if p0 == null:
		return ""
	var txt := "Presión media y pico de Hertz: los %s MPa de F/A reparten la fuerza por toda la punta, como si tocara entera, pero solo toca en un círculo de %s de radio, y en su centro la presión llega a %s MPa (de media, dos tercios de eso)." % [
		Format.fmt_p(float(res.pressure)), Format.fmt_depth(float(res.hertzRadiusUm)), Format.fmt_p(float(p0))]
	var tip_hv: Variant = res.get("tipHv")
	var h_tip := float(tip_hv if tip_hv != null else res.get("hvTool", 0.0)) * HV_MPA
	var h_target := float(res.get("tHV", 0.0)) * HV_MPA
	match res.get("hertzYield"):
		"punta":
			txt += " Con ese pico la punta ya pasa de su límite elástico: se aplasta un poco, el pico de verdad es menor y la presión media no pasa de su dureza (%s MPa)." % Format.fmt_p(h_tip)
		"objetivo":
			txt += " Con ese pico el material ya pasa de su límite elástico y empieza a quedar huella: el pico de verdad es algo menor y la presión media no pasa de su dureza (%s MPa)." % Format.fmt_p(h_target)
		"las dos":
			txt += " Con ese pico la punta y el material ya pasan de su límite elástico: el pico de verdad es menor y la presión media no pasa de la dureza del más blando (%s MPa)." % Format.fmt_p(minf(h_tip, h_target))
		_:
			txt += " Ni la punta ni el material pasan de su límite elástico: al levantar la punta no queda huella."
			# un frágil que se agrieta sin ceder (Johnson 1985: la tracción radial en el borde del círculo, (1 − 2ν)·p0/3)
			var fr: Variant = res.get("fracture")
			if fr is Dictionary and String(fr.get("mode", "")) == "hertz":
				txt += " Las grietas de Hertz no son huella: las abre la tracción en el borde del círculo de contacto, sin que nada ceda."
	return txt


## La presión de una fila de la comparativa: la real, con «(tope)» si la limita una dureza («196 MPa (tope)»).
static func compare_pressure(res: Dictionary) -> String:
	return "%s MPa%s" % [Format.fmt_p(res.pressure), " (tope)" if pressure_cap(res) != "" else ""]


## Nota de la comparativa sobre la presión de cada fila.
const COMPARE_PRESSURE_NOTE := "MPa = presión real del contacto: la nominal F/A hasta la dureza de quien cede; por encima no tiene sentido (tope)"


## χ = P/H con tres decimales, como en la 1.x, hasta CHI_MAX; por encima, «> 1000» (la punta pide mil veces la dureza).
static func chi_text(chi: float) -> String:
	return Js.to_fixed(chi, 3) if chi < CHI_MAX else "> %s" % Js.js_num_str(CHI_MAX)


# ════════ La ficción ════════

## El velocirraptor de cine con su garra de película (sin reforjar en otro material, que ya es un dato): { tag, note } para
## el resultado, o {} con cualquier otra herramienta. La nota dice que la garra es de cine y qué haría la de verdad
## (VelociraptorFilm.SRC_REAL_CLAW). inlay: la entrada de Catalog.INLAYS (o null).
static func fiction(claw: Variant, inlay: Variant) -> Dictionary:
	if not VelociraptorFilm.is_film(claw):
		return {}
	if inlay is Dictionary and String(inlay.get("id", "none")) != "none":
		return {}
	return {
		"tag": "FICCIÓN",
		"note": "Ficción (película): la garra de cine es dura como la tachuela de acero del banco (%s HV), para jugar con Jurassic Park. %s." % [
			Js.js_num_str(float(claw.hv)), VelociraptorFilm.SRC_REAL_CLAW],
	}


# ════════ Fuentes y estimaciones de un ensayo ════════

## De dónde salen la velocidad y la masa del golpe de la herramienta, para la nota del golpe de los parámetros: la
## corrección de la 2.0 (la patada del casuario, el picado del halcón: ClawsV2), el salto de la reconstrucción del
## velocirraptor o la estimación de la 1.x. Las fuentes de las dos primeras están en «Fuentes y estimaciones».
static func strike_origin(claw: Variant) -> String:
	if claw == null:
		return "la estimación de la 1.x para el dedo"
	if Velociraptor.is_dino(claw):
		return "el salto con los dos pies de la reconstrucción, con su fuente en «Golpe» de las fuentes del ensayo"
	if ClawsV2.override_of(claw, "strike") != null:
		return "corregidas en la 2.0, con su fuente en «%s» de las fuentes del ensayo" % ("Patada" if claw.id == "casuario" else "Golpe")
	return "la estimación de la 1.x"


static func _row(label: String, value: String, quality: Variant, source: Variant) -> Dictionary:
	return { "label": label, "value": value, "quality": String(quality) if quality != null else "", "source": String(source) if source != null else "" }


## Un número con su banda: «100.9 N (de 65.4 a 298.8)».
static func _band(v: float, lo: float, hi: float, unit: String) -> String:
	if lo == v and hi == v:
		return "%s %s" % [Js.js_num_str(v), unit]
	return "%s %s (de %s a %s)" % [Js.js_num_str(v), unit, Js.js_num_str(lo), Js.js_num_str(hi)]


## Espesor legible de una capa (µm): «18 µm» o «2,2 mm» (el de la tabla de la piel, SkinTable.fmt_um).
static func fmt_um(um: float) -> String:
	return "%s mm" % Js.to_fixed(um / 1000.0, 1).replace(".", ",") if um >= 1000.0 else "%s µm" % Js.js_num_str(um)


## Los datos de la 2.0 que usa un ensayo, cada uno con su valor, su calidad y su fuente: [{ label, value, quality, source }]
## (quality: "primary" | "secondary" | "estimate" | "ficcion", o "" en las citas de un modelo). res: el resultado de
## compute() con el modelo 2.0; sel: la selección del banco con que se hizo, { claw, inlay, target }. Vacío con un resultado
## de la 1.x.
static func sources(res: Dictionary, sel: Dictionary) -> Array:
	var out: Array = []
	if res.get("residualDepthUm") == null:
		return out  # la 1.x: sin campos de la 2.0
	var claw: Variant = sel.get("claw")
	var inlay: Dictionary = sel.inlay
	var target: Dictionary = sel.target
	_tool_rows(out, res, claw, inlay)
	_target_rows(out, res, target)
	# unidad 4p: el contacto elástico de Hertz, con su pico y el radio del círculo donde se tocan
	var p0: Variant = res.get("p0MPa")
	if p0 != null:
		var bound := " (cota alta: ya cede %s)" % ("la punta" if res.hertzYield == "punta" else ("el material" if res.hertzYield == "objetivo"
			else "la punta y el material")) if res.get("hertzYield") != null else ""
		out.append(_row("Contacto elástico (Hertz)", "pico de %s MPa en un círculo de %s de radio%s" % [Format.fmt_p(float(p0)),
			Format.fmt_depth(float(res.hertzRadiusUm)), bound], "model", Physics.SRC_HERTZ))
	return out


## La herramienta: el aguijón, el velocirraptor (y su ficción), las correcciones de la 2.0 de las garras, la uña que cede,
## el material de una garra reforjada y su afilado, el esmalte de un colmillo y el ángulo de ataque.
static func _tool_rows(out: Array, res: Dictionary, claw: Variant, inlay: Dictionary) -> void:
	var reforged := String(inlay.get("id", "none")) != "none"
	if claw != null and Insects.is_stinger(claw):
		out.append(_row(String(claw.name), "aguijón: longitud, punta, púas, veneno y aleteo de la especie", claw.get("quality"), claw.get("source")))
	elif claw != null and Velociraptor.is_dino(claw):
		var d: Dictionary = claw.dino
		var film := VelociraptorFilm.is_film(claw)
		out.append(_row("Masa (%s)" % ("Deinonychus" if film else "por el fémur"), _band(float(d.mass.value), float(d.mass.min), float(d.mass.max), "kg"),
			d.mass.quality, d.mass.source))
		out.append(_row("Agarre de un pie", _band(float(d.forces.grip.value), float(d.forces.grip.min), float(d.forces.grip.max), "N"),
			d.forces.grip.quality, d.forces.grip.source))
		var tip: Dictionary = d.sickle.tipRadiusUm
		out.append(_row("Punta de la garra", "R %s · α %s° (sin medir)" % [Format.fmt_tip_um(float(tip.value)), Js.js_num_str(float(d.sickle.alphaDeg.value))],
			tip.quality, tip.source))
		var leap: Dictionary = d.locomotion.leapMs
		out.append(_row("Golpe (salto con los dos pies)", "%s m/s · %s kg por pie" % [Js.to_fixed(float(claw.strike.v), 2), Js.js_num_str(float(claw.strike.m))],
			leap.quality, leap.source))
		if film and not reforged:
			var fc: Dictionary = d.fiction.claw
			out.append(_row("Garra de película", "%s HV · %s GPa: corta como el acero" % [Js.js_num_str(float(fc.hv)), Js.js_num_str(float(fc.E))],
				fc.quality, "%s. %s" % [String(d.fiction.slash.source), VelociraptorFilm.SRC_REAL_CLAW]))
	elif claw != null:
		_claws_v2_rows(out, claw)
	var nail: Variant = res.get("nail")
	if nail is Dictionary:
		out.append(_row("Uña: cede por flexión", "%s N (se %s; uña libre de %s mm)" % [Format.fmt_f(nail.breakN), "parte" if nail.mode == "parte" else "dobla",
			Js.js_num_str(float(nail.lengthMm))], nail.get("quality"), nail.get("source")))
	var sh: Variant = res.get("sharpness")
	var chip: Variant = res.get("tipChip")
	if sh is Dictionary and sh.get("sigmaMPa") != null:
		var st: Variant = ClawSharpness.strength_of(inlay)  # la resistencia del material, con su calidad y su fuente
		out.append(_row("Resistencia de la garra de %s" % Lab.material_name(inlay), "%s MPa %s" % [Format.fmt_p(float(sh.sigmaMPa)),
			"a flexión" if sh.get("kind") == "flexion" else "de fluencia"], st.get("quality") if st is Dictionary else null,
			st.get("source") if st is Dictionary else null))
	elif chip is Dictionary:
		out.append(_row("Resistencia de la punta de %s" % Lab.material_name(inlay), "se mella con ~%s N de lado" % Format.fmt_f(float(chip.chipN)),
			chip.get("quality"), chip.get("source")))
	if sh is Dictionary and float(sh.sharpness) > 0.0:
		out.append(_row("Afilado de la punta", "R %s (la de la ficha, R %s)" % [Format.fmt_tip_um(float(sh.tipRadiusUm)), Format.fmt_tip_um(float(sh.naturalUm))],
			"model", "%s; %s" % [ClawSharpness.SRC_PATTRICK, ClawSharpness.SRC_JOHNSON]))
	var tip_hv: Variant = res.get("tipHv")
	if tip_hv != null and float(tip_hv) > float(res.get("hvTool", 0.0)):
		out.append(_row("Esmalte de la punta", "%s HV en el contacto (dentina %s HV)" % [Format.fmt_p(float(tip_hv)), Format.fmt_p(float(res.hvTool))],
			FangEnamel.ENAMEL.quality, FangEnamel.ENAMEL.source))
	var att: Variant = res.get("attackDeg")
	if att != null and (res.get("faceDeg") != null or nail is Dictionary):
		var d: Dictionary = Attack.DEFAULTS[Attack.kind_of(claw)]
		if float(att) == float(d.value):
			out.append(_row("Ángulo de ataque", "%s° (el de la herramienta)" % Js.js_num_str(float(att)), d.quality, d.source))
		else:
			out.append(_row("Ángulo de ataque", "%s° (el del deslizador): decide el modo de abrasión" % Js.js_num_str(float(att)), "model",
				"%s; %s" % [Attack.SRC_HK_1988, Attack.SRC_CHALLEN_1979]))


## Las correcciones de la 2.0 de una garra de la 1.x (claws_v2.gd): el agarre de las rapaces, el picado del halcón y la
## patada y la masa del casuario, con su banda.
static func _claws_v2_rows(out: Array, claw: Dictionary) -> void:
	var f: Variant = ClawsV2.override_of(claw, "force")
	if f != null:
		out.append(_row("Agarre de un pie", _band(float(f.value), float(f.get("min", f.value)), float(f.get("max", f.value)), "N"), f.quality, f.source))
	var m: Variant = ClawsV2.override_of(claw, "mass")
	if m != null:
		out.append(_row("Masa", _band(float(m.value), float(m.min), float(m.max), "kg"), m.quality, m.source))
	var s: Variant = ClawsV2.override_of(claw, "strike")
	if s != null:
		var v: Dictionary = s.value
		var txt := "%s m/s · %s kg" % [Js.to_fixed(float(v.v), 2), Js.to_fixed(float(v.m), 2)]
		var e: Variant = s.get("energyJ")
		if e is Dictionary:
			txt += " · ~%s J (hasta ~%s J)" % [Format.fmt_j(float(e.value)), Format.fmt_j(float(e.max))]
		out.append(_row("Patada" if claw.id == "casuario" else "Golpe", txt, s.quality, s.source))


## El material: la piel de la zona (cada capa con su espesor) y su hueso, el modelo de la punción por capas, el vidrio de
## coche, los datos de fractura de un frágil, la abolladura de la chapa y la recuperación.
static func _target_rows(out: Array, res: Dictionary, target: Dictionary) -> void:
	var pen: Variant = res.get("pen")
	if pen is Dictionary:
		var zone := Zones.resolve(res.get("zone"))
		for l: Dictionary in Zones.section_layers(String(zone.id)):
			if l.id == "hueso" or l.get("source") == null:
				continue
			out.append(_row("%s · %s" % [l.name, zone.short], fmt_um(float(l.to) - float(l.from)) if l.id != "cavidad" else "sin fondo",
				l.get("quality"), l.source))
		var bone: Variant = Zones.bone(String(zone.id))
		if bone != null:
			out.append(_row(String(bone.name), "a %s · cortical %s · %s HV" % [fmt_um(float(bone.fromUm)), fmt_um(float(bone.corticalUm)),
				Js.js_num_str(float(bone.hv))], bone.quality, bone.source))
		if pen.get("method") == "puncion" and pen.get("pierces") == true:
			out.append(_row("Punción por capas", "una grieta en cada capa y el roce en los flancos (μ %s, estimación)" % Js.js_num_str(float(Penetration.MODEL.flankFriction)),
				"estimate", "%s; %s; %s" % [Penetration.SRC_SHERGOLD_2005, Penetration.SRC_FREGONESE_2022, Penetration.SRC_SHERGOLD_2006]))
	if Js.truthy(target.get("tempered")) or Js.truthy(target.get("laminated")):
		out.append(_row(String(target.name), "templado, 4 mm" if Js.truthy(target.get("tempered")) else "laminado: vidrio, lámina de PVB y vidrio",
			target.get("quality"), target.get("source")))
	var fr: Variant = res.get("fracture")
	if fr is Dictionary:
		var p: Variant = Fracture.props(target)
		var kc := (" · K_c %s MPa·√m" % Js.js_num_str(float(p.Kc))) if p is Dictionary else ""
		out.append(_row("Fractura · %s" % String(target.name), "grietas de Hertz y astillado%s" % kc, fr.get("quality"), fr.get("source")))
	var dent: Variant = res.get("dent")
	if dent is Dictionary:
		out.append(_row("Abolladura de la chapa", "empieza a ~%s N" % Format.fmt_f(float(dent.collapseN)), "model", SRC_DENT))
	var rec: Variant = res.get("recovery")
	if rec is Dictionary and fr == null:
		out.append(_row("Huella al levantar la punta", "recupera el %s %%" % Js.to_fixed(float(rec.fraction) * 100.0, 0), "model", SRC_OLIVER_PHARR))


## Resumen de la lista (empieza plegada): «7 datos · 3 medidos · 2 de casos parecidos · 2 estimaciones».
static func sources_summary(rows: Array) -> String:
	if rows.is_empty():
		return ""
	var count := { "primary": 0, "secondary": 0, "estimate": 0, "ficcion": 0, "model": 0 }
	for r: Dictionary in rows:
		var q := String(r.quality)
		if count.has(q):
			count[q] += 1
	var parts: Array = ["%d %s" % [rows.size(), "dato" if rows.size() == 1 else "datos"]]
	var names := { "primary": ["medido", "medidos"], "secondary": ["de un caso parecido", "de casos parecidos"],
		"estimate": ["estimación", "estimaciones"], "ficcion": ["de ficción", "de ficción"], "model": ["modelo", "modelos"] }
	for q: String in ["primary", "secondary", "estimate", "model", "ficcion"]:
		var n: int = count[q]
		if n > 0:
			parts.append("%d %s" % [n, names[q][0] if n == 1 else names[q][1]])
	return " · ".join(PackedStringArray(parts))
