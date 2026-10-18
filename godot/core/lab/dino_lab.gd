## Tribología biológica · el velocirraptor y el afilado de las garras en el banco (modelo 2.0; unidad 4i).
##
## Integra en el laboratorio lo de la unidad 4e (docs/fisica/velociraptor.md §10.1, §10.2 y §10.4) sin añadir física: la
## física es la de core/lab/velociraptor.gd, claw_sharpness.gd y Physics.compute; aquí se escriben los textos con esos
## números (como sting_lab.gd con los aguijones), para que la interfaz solo pinte.
##   - is_dino(claw): una garra de dinosaurio reconstruido (con el bloque `dino`).
##   - spec_rows(claw, material, hardness, tool): la ficha del velocirraptor en la tarjeta de la herramienta: dice
##     «reconstrucción», la banda de la masa, la garra (hueso fósil y estuche con su banda), la punta como pregunta abierta
##     (dino.sickle.tipRadiusUm.open), el agarre de un pie con su banda y el golpe.
##   - sources_line(claw): las fuentes abreviadas de la ficha.
##   - max_force_hint(claw): el botón de fuerza máxima, con el agarre de un pie (dino.forces.grip) y, en la nota, la garra
##     sola (Bishop 2019) y la réplica (Manning et al. 2006).
##   - sharpness_view(rep, s): el deslizador «Afilado» (sus marcas, ClawSharpness.REFERENCES) y sus dos barras (la presión,
##     que sube al afilar, y la carga que aguanta la punta de lado, que baja), con el campo `sharpness` de un ensayo
##     (Physics.sharpness_report o compute()).
##   - sharpness_row(res) y tip_size(res): la fila de la punta afilada en el resultado y el tamaño de la punta en la
##     comparativa (el radio si está afilada).
## Números visibles con js.gd y format.gd (como JavaScript). Colores: nombres de la paleta (core/shared/theme.gd).
## Uso: const DinoLab = preload("res://core/lab/dino_lab.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Contact = preload("res://core/shared/contact.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")

## Qué dice la calidad de los datos en la ficha. «ficcion»: lo de película (unidad 4i-B2), nunca un dato.
const QUALITY_TEXT := {
	"primary": "medido en la especie", "secondary": "medido en un pariente o recopilado", "estimate": "estimación con el caso medido más parecido",
	"ficcion": "ficción (película)",
}


## ¿Es un dinosaurio reconstruido? (Velociraptor.is_dino: una garra con el bloque `dino`)
static func is_dino(claw: Variant) -> bool:
	return Velociraptor.is_dino(claw)


# ════════ Formatos ════════

## Radio de una punta legible: 138 µm · 18.0 µm · 2.35 µm · 155 nm · 40 nm (Format.fmt_tip_um, el mismo del coche en
## marcha).
static func fmt_tip_um(um: float) -> String:
	return Format.fmt_tip_um(um)


## Fuerza legible de newtons a nanonewtons (la carga que aguanta de lado una punta afilada): Format.fmt_small_force,
## 45 N · 13 mN · 2.3 mN · 3.7 µN · 0.36 nN (el subtítulo del mellado de Physics usa el mismo formato).
static func fmt_small_force(f: float) -> String:
	return Format.fmt_small_force(f)


## Un número con su banda: «19.7 kg (14.1–24.6)».
static func _band(v: float, lo: float, hi: float, digits: int, unit: String) -> String:
	return "%s %s (%s–%s)" % [Js.to_fixed(v, digits), unit, Js.to_fixed(lo, digits), Js.to_fixed(hi, digits)]


# ════════ La ficha ════════

## ¿Es el velocirraptor de película? (VelociraptorFilm.is_film: ficción, con el tamaño de Deinonychus)
static func is_film(claw: Variant) -> bool:
	return VelociraptorFilm.is_film(claw)


## Pares [clave, valor] de la ficha del velocirraptor. tool: la herramienta resuelta (LabState.tool(): con un material, su
## dureza, y afilada, su punta). La dureza sale de Lab.claw_spec en la tarjeta (spec_material, spec_hardness).
static func spec_rows(claw: Dictionary, spec_material: String, spec_hardness: String, tool: Dictionary) -> Array:
	if is_film(claw):
		return _film_rows(claw, spec_material, spec_hardness, tool)
	var d: Dictionary = claw.dino
	var mass: Dictionary = d.mass
	var sk: Dictionary = d.sickle
	var grip: Dictionary = d.forces.grip
	var natural := Velociraptor.tip_radius_um(claw)
	var r: float = tool.tipRadiusUm
	var tip_txt := "R %s · α %s°" % [fmt_tip_um(r), Js.js_num_str(float(tool.alpha))]
	if r < natural * (1.0 - 1e-9):
		tip_txt += " · afilada"
	elif sk.tipRadiusUm.get("open") == true:
		tip_txt += " · sin medir"
	var ker: Dictionary = sk.keratinMm
	return [
		[spec_material, spec_hardness],
		["reconstrucción", "fósil + aves actuales"],
		["punta", tip_txt],
		["garra", _band(float(ker.value), float(ker.min), float(ker.max), 1, "mm")],
		["hueso fósil", "%s mm" % Js.js_num_str(float(sk.coreMm.value))],
		["peso", _band(float(mass.value), float(mass.min), float(mass.max), 1, "kg")],
		["agarre de un pie", "~%s" % _band(float(grip.value), float(grip.min), float(grip.max), 0, "N")],
		["golpe", "~%s J (cae con los dos pies)" % Format.fmt_j(tool.strikeJ)],
	]


## La ficha del velocirraptor de película: dice «ficción (película)» en la garra (su dureza de película, si no está
## reforjada) y enseña los datos de Deinonychus que sí son reales (su masa por el fémur con la banda, la garra de Ostrom y
## el agarre escalado).
static func _film_rows(claw: Dictionary, spec_material: String, spec_hardness: String, tool: Dictionary) -> Array:
	var d: Dictionary = claw.dino
	var mass: Dictionary = d.mass
	var grip: Dictionary = d.forces.grip
	var natural := Velociraptor.tip_radius_um(claw)
	var r: float = tool.tipRadiusUm
	var tip_txt := "R %s · α %s°" % [fmt_tip_um(r), Js.js_num_str(float(tool.alpha))]
	if r < natural * (1.0 - 1e-9):
		tip_txt += " · afilada"
	else:
		tip_txt += " · sin medir"
	var film_claw := not Js.truthy(tool.get("hasGem"))
	return [
		["garra de película" if film_claw else spec_material, (spec_hardness + " · ficción") if film_claw else spec_hardness],
		["ficción (película)", "tamaño de Deinonychus"],
		["punta", tip_txt],
		["garra", "%s mm (Deinonychus)" % Js.js_num_str(float(d.sickle.keratinMm.value))],
		["peso", _band(float(mass.value), float(mass.min), float(mass.max), 1, "kg")],
		["agarre de un pie", "~%s" % _band(float(grip.value), float(grip.min), float(grip.max), 0, "N")],
		["golpe", "~%s J (cae con los dos pies)" % Format.fmt_j(tool.strikeJ)],
	]


## La línea de las fuentes de la ficha: qué tipo de dato es, la punta como pregunta abierta y las fuentes abreviadas como
## las de los aguijones (StingLab.short_sources): «Norell 1999 · Campione 2014 · …».
static func sources_line(claw: Dictionary) -> String:
	if is_film(claw):
		return "Ficción (película): la garra que raja la chapa es de cine; la de verdad, de queratina (%s HV), no corta el acero de un coche. El tamaño, la masa, la garra, el agarre y el salto son de Deinonychus, en el que se basó la película (datos). Fuentes: %s" % [
			Js.js_num_str(float(Velociraptor.ENTRY.hv)), StingLab.short_sources(String(claw.get("source", "")))]
	return "Reconstrucción (%s). La punta no fosiliza: se ensaya con la de la arpía (pregunta abierta). Fuentes: %s" % [
		QUALITY_TEXT.get(claw.get("quality"), "—"), StingLab.short_sources(String(claw.get("source", "")))]


## Botón de fuerza máxima del velocirraptor: el agarre de un pie (escalado de los gavilanes) y, en la nota, lo que aprieta la
## garra sola y la carga de la réplica. { force, label, note }.
static func max_force_hint(claw: Dictionary) -> Dictionary:
	var f: Dictionary = claw.dino.forces
	return {
		"force": claw.force, "label": "del " + String(claw.name).to_lower(),
		"note": "agarre de un pie (escalado de los gavilanes: %s–%s N) · la garra sola, ~%s N; la réplica, %s N · peso ~%s kg" % [
			Js.to_fixed(float(f.grip.min), 0), Js.to_fixed(float(f.grip.max), 0), Js.to_fixed(float(f.clawMuscle.value), 0),
			Js.to_fixed(float(f.replica.value), 0), Js.js_num_str(float(claw.mass))],
	}


## La fila del resultado de un ensayo con la punta afilada (res.sharpness con s > 0): [clave, fórmula, texto, color] para
## la tarjeta del resultado, o null si la punta no está afilada.
static func sharpness_row(res: Dictionary) -> Variant:
	var sh: Variant = res.get("sharpness")
	if not (sh is Dictionary) or float(sh.sharpness) <= 0.0:
		return null
	var txt := "R %s" % fmt_tip_um(float(sh.tipRadiusUm))
	var color := "dim"
	if sh.get("chipN") == null:
		txt += " · sin resistencia medida: no se predice si aguanta"
	elif float(sh.lateralN) <= 0.0:
		txt += " · aguanta ~%s de lado; de frente no le llega carga lateral" % fmt_small_force(float(sh.chipN))
		color = "mint"
	else:
		var fails: bool = sh.fracture.fails
		var kind: String = sh.get("kind", "flexion")
		txt += " · aguanta ~%s de lado y le llegan ~%s: %s" % [fmt_small_force(float(sh.chipN)), fmt_small_force(float(sh.lateralN)),
			("se mella" if kind == "flexion" else "se dobla") if fails else "aguanta"]
		color = ("coral" if kind == "flexion" else "gold") if fails else "mint"
	return ["Punta afilada", "carga ∝ R²", txt, color]


## El tamaño de la punta en una fila de la comparativa: el área nominal («0.060 mm²») o, si la punta está afilada
## (res.sharpness con s > 0), su radio («R 2.35 µm»): su área ya no se lee con tres decimales.
static func tip_size(res: Dictionary) -> String:
	var sh: Variant = res.get("sharpness")
	if sh is Dictionary and float(sh.sharpness) > 0.0:
		return "R %s" % fmt_tip_um(float(sh.tipRadiusUm))
	return "%s mm²" % Js.to_fixed(float(res.area), 3)


# ════════ El deslizador «Afilado» ════════

## Color de cada marca: los filos (hoja de afeitar y cuchillos) y las puntas (aguijón, microagujas, Rockwell).
const MARK_COLORS := { "filo": "ice", "punta": "gold" }


## Las marcas del deslizador para una punta natural de r0_um: [{ t (el afilado que la lleva a ese radio), color, text }],
## de la más roma a la más fina; la primera, la punta de la ficha (t = 0). Las referencias más romas que la punta natural
## no se pueden alcanzar afilando y no se enseñan.
static func sharpness_marks(r0_um: float) -> Array:
	var out: Array = [{ "t": 0.0, "color": "dim", "text": "la de la ficha · %s" % fmt_tip_um(r0_um), "id": "ficha" }]
	var refs: Array = ClawSharpness.REFERENCES.duplicate()
	refs.reverse()
	for ref: Dictionary in refs:
		var r: float = ref.tipRadiusUm
		if r >= r0_um:
			continue
		out.append({
			"t": ClawSharpness.sharpness_for(r0_um, r), "color": MARK_COLORS.get(ref.kind, "gold"),
			"text": "%s · %s" % [String(ref.name).to_lower(), fmt_tip_um(r)], "id": ref.id,
		})
	return out


## El deslizador y sus dos barras con el compromiso rep (el campo `sharpness` de Physics.sharpness_report o de compute())
## de una garra reforjada en material_name («diamante», «acero»…). { display, spoken, marks, pressure, lateral, note };
## cada barra: { title, level (0-1), color, text }. Las dos barras van en la escala logarítmica del deslizador:
##   - la presión de pico con la misma fuerza sube como (R0/R)^(2/3) (Hertz): llena con el filo más fino medido (s = 1);
##   - la carga que aguanta de lado baja con R² (la viga en voladizo de claw_sharpness.gd): llena con la punta natural y
##     vacía con el filo más fino. Sin resistencia medida del material (hematites), vacía y sin predicción.
static func sharpness_view(rep: Dictionary, material_name: String) -> Dictionary:
	var r0: float = rep.naturalUm
	var r: float = rep.tipRadiusUm
	var s: float = rep.sharpness
	var gain: float = rep.pressureGain
	var solid: bool = rep.get("p0MPa") != null
	var fr: Dictionary = rep.fracture
	var chip: Variant = rep.get("chipN")
	var lateral: float = rep.lateralN
	var no_data := chip == null
	var p_text := "×%s la de la punta natural" % (Js.to_fixed(gain, 1) if gain < 100.0 else Js.to_fixed(gain, 0))
	if solid:
		p_text += " · el material cede desde ~%s" % fmt_small_force(float(rep.yieldOnsetN))
	var l_color := "dimmer"
	var l_text := "sin resistencia medida del material: no se predice"
	var verdict := ""
	if not no_data:
		var kind: String = rep.get("kind", "flexion")
		l_text = "~%s" % fmt_small_force(float(chip))
		if lateral <= 0.0:
			l_color = "mint"
			l_text += " · de frente no le llega carga lateral"
			verdict = "Punzando de frente no hay carga lateral: la punta afilada no se rompe (está en compresión)."
		elif bool(fr.fails):
			l_color = "coral" if kind == "flexion" else "gold"
			l_text += " · le llegan ~%s al rayar: se %s" % [fmt_small_force(lateral), "mella" if kind == "flexion" else "dobla"]
			var need: Variant = rep.get("sharpestSurvivingUm")
			verdict = "Con esta fuerza, la fricción empuja la punta de lado con ~%s y la de %s se %s: para aguantarla, la punta no puede bajar de R %s." % [
				fmt_small_force(lateral), material_name, "mella" if kind == "flexion" else "dobla",
				fmt_tip_um(float(need)) if need != null else "—"]
		else:
			l_color = "mint"
			l_text += " · le llegan ~%s al rayar: aguanta" % fmt_small_force(lateral)
			verdict = "Con esta fuerza, la fricción empuja la punta de lado con ~%s y la de %s aguanta." % [fmt_small_force(lateral), material_name]
		if bool(fr.get("sizeEffect", false)):
			verdict += " La punta es más fina que los defectos que rompen la probeta (%s): aguantaría algo más de lo que dice el modelo." % fmt_tip_um(float(fr.criticalUm))
	var how := "presión con la misma fuerza (Hertz) y la punta entra más" if solid else "presión con la misma fuerza (Hertz); en la piel, la hondura la da la grieta que abre"
	var from_to := ("de R %s a R %s" % [fmt_tip_um(r0), fmt_tip_um(r)]) if r < r0 * (1.0 - 1e-9) else ("ahora, la de la ficha: R %s" % fmt_tip_um(r0))
	var note := "Afilar la punta (%s) sube la %s, pero la carga que aguanta de lado baja con R²: afilada a la mitad, aguanta la cuarta parte (Pattrick et al. 2018). %s" % [
		from_to, how, verdict]
	var level_lat := 0.0 if no_data else Contact.clamp_js(1.0 - s, 0.0, 1.0)
	return {
		"display": "R %s" % fmt_tip_um(r), "spoken": "radio de la punta, %s" % fmt_tip_um(r).replace("µm", "micras").replace("nm", "nanómetros"),
		"marks": sharpness_marks(r0),
		"pressure": { "title": "Presión con la misma fuerza", "level": Contact.clamp_js(s, 0.0, 1.0), "color": "rose", "text": p_text },
		"lateral": { "title": "Carga que aguanta de lado", "level": level_lat, "color": l_color, "text": l_text },
		"note": note.strip_edges(),
	}
