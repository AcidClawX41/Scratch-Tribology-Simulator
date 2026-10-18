## La frase de por qué un zarpazo no raya la lente (core/lab/care_reaction_text.gd, unidad 5t-B): el oso con queratina en
## el metacrilato la mancha y la raja pero no la raya, con las durezas de las fichas; si alguna garra raya, no hay frase; un
## metal más blando que el vidrio, «más blando».
extends "res://tests/case.gd"

const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const CareReactionText = preload("res://core/lab/care_reaction_text.gd")


func test_el_oso_mancha_y_raja_el_metacrilato() -> void:
	var hit := Reaction.lens_hit("plastico", { "animal": "oso", "claw": "oso", "inlay": "none", "intensity": 0.9 })
	assert_eq(int(hit.scratches), 0, "la queratina del oso no raya el metacrilato (r < 1,25)")
	var txt := CareReactionText.no_scratch(hit)
	var want := "la queratina del oso pardo (26 HV) es apenas más dura que el metacrilato (22 HV): lo mancha%s, pero no lo raya" % (" y lo raja" if bool(hit.cracked) else "")
	assert_eq(txt, want, "la frase con las durezas de las fichas")


func test_si_raya_no_hay_frase() -> void:
	var hit := Reaction.lens_hit("plastico", { "animal": "tigre", "claw": "tigre", "inlay": "diamante", "intensity": 0.9 })
	assert_true(int(hit.scratches) > 0, "el diamante raya el plástico")
	assert_eq(CareReactionText.no_scratch(hit), "", "sin frase")


func test_un_metal_mas_blando() -> void:
	var hit := Reaction.lens_hit("vidrio", { "animal": "rapaz", "claw": "aguila", "inlay": "oro", "intensity": 0.6 })
	if int(hit.scratches) == 0 and int(hit.marks) > 0:
		assert_true(CareReactionText.no_scratch(hit).begins_with("el oro"), "empieza por el material: %s" % CareReactionText.no_scratch(hit))
		assert_true(CareReactionText.no_scratch(hit).contains("más blando que el vidrio óptico crown"), "más blando que el vidrio")
