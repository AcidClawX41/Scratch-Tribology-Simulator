## Tribología biológica · cetrería: la frase corta que explica en la escena por qué un zarpazo no ha rayado la lente
## (unidad 5t-B). Sin nodos y determinista; los números, los del motor (ClawCareReaction.lens_hit) y los de las fichas.
## Rayar exige que la garra sea al menos 1,25 veces más dura que la lente (Reaction.R_SCRATCH, Richardson 1968; el criterio
## de Pintaude): una garra apenas más dura que la lente, o más blanda, solo la mancha (y, si el golpe basta, la raja).
## Uso: const CareReactionText = preload("res://core/lab/care_reaction_text.gd"); CareReactionText.no_scratch(hit).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")


## hit: el resultado de Reaction.lens_hit. Si alguna garra toca la lente y ninguna la raya: «la queratina del oso pardo
## (26 HV) es apenas más dura que el metacrilato (22 HV): lo mancha y lo raja, pero no lo raya». "" en otro caso.
static func no_scratch(hit: Dictionary) -> String:
	if int(hit.get("scratches", 0)) > 0 or int(hit.get("marks", 0)) <= 0:
		return ""
	var claws: Array = hit.get("claws", [])
	var mat := "none"
	for c: Variant in claws:
		if c is Dictionary and String((c as Dictionary).get("outcome", "nada")) != "nada":
			mat = String((c as Dictionary).get("material", "none"))
			break
	var L := Reaction.lens(String(hit.get("lens", "plastico")))
	var lens_hv := float(L.hv)
	var claw_hv := 0.0
	var who := ""
	if mat == "none":
		claw_hv = float(CareData.claw_entry(String(hit.get("claw", ""))).get("hv", 0.0))
		var an: Dictionary = CareData.ANIMALS.get(String(hit.get("animal", "")), {})
		who = "la queratina" + ((" del " + String(an.name).to_lower()) if an.has("name") else "")
	else:
		claw_hv = float(Reaction.material_entry(mat).get("hv", 0.0))
		who = Reaction.material_phrase(mat)
	if claw_hv <= 0.0 or lens_hv <= 0.0:
		return ""
	var fem := mat in Reaction.FEMININE
	var cmp := ("apenas más dura" if fem else "apenas más duro") if claw_hv >= lens_hv else ("más blanda" if fem else "más blando")
	var lens_mat := "el " + String(L.get("material", "vidrio")).get_slice(" (", 0)
	var does := "lo mancha y lo raja" if bool(hit.get("cracked", false)) else "lo mancha"
	return "%s (%s HV) es %s que %s (%s HV): %s, pero no lo raya" % [who, Js.to_fixed(claw_hv, 0), cmp, lens_mat,
		Js.to_fixed(lens_hv, 0), does]
