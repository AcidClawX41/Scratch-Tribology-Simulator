## El encargo de la 5u «Soldar la punta de una funda» (VetProgress, soldar_punta) con la mesa de soldar de la 5r: con
## ClawForge.weld_setup ya existe, así que sale en la lista; una funda de acero soldada con el láser y su costura entera lo
## cumple con el informe de la reforja; el titanio soldado al aire (contaminado) no, y dice por qué.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const VetProgress = preload("res://core/lab/vet_progress.gd")
const WeldState = preload("res://tests/lab/test_claw_forge_weld_state.gd")


static func _has_weld() -> bool:
	return ClawForge.new().has_method("weld_setup")


static func _welded(process: String, gas: String) -> State:
	var st: State = WeldState._metal(process)
	# lo recomendado para esta pieza (el láser con la energía que atraviesa su pared), y el gas que toque
	st.set_weld_params(st.forge.weld_recommended().weld_setup)
	st.set_weld("method", "laser")
	st.set_weld("gas", gas)
	st.weld_prepare()
	st.weld_align_pieces()
	WeldState._sweep(st, 1.2)
	return st


func test_sale_en_la_lista_con_la_mesa_de_soldar() -> void:
	assert_true(_has_weld(), "la reforja tiene la mesa de soldar (weld_setup)")
	var p := VetProgress.new()
	p.best_level = 3
	var ids: Array = p.jobs_view(_has_weld()).map(func(e: Dictionary) -> String: return String(e.id))
	assert_true(ids.has("soldar_punta"), "el encargo de soldar sale en la lista: %s" % [ids])


func test_una_funda_de_acero_soldada_lo_cumple() -> void:
	var st := _welded("acero", "argon")
	var w: Dictionary = st.forge.weld_state()
	assert_true(bool(w.done) and bool(w.joint.ok), "la costura entera y la unión buena: %s" % String(w.joint.get("text", "")))
	var p := VetProgress.new()
	p.best_level = 3
	p.accept("soldar_punta")
	var r := p.on_forge_finished(VetProgress.forge_summary(st.view()))
	assert_true(bool(r.ok), "cumplido con el informe de la reforja: %s" % String(r.get("text", "")))
	assert_eq(p.job_state("soldar_punta"), "hecho", "hecho")


func test_el_titanio_al_aire_no_lo_cumple_y_dice_por_que() -> void:
	var st := _welded("titanio", "aire")
	var p := VetProgress.new()
	p.best_level = 3
	p.accept("soldar_punta")
	var r := p.on_forge_finished(VetProgress.forge_summary(st.view()))
	assert_false(bool(r.ok), "contaminado: no se cumple")
	assert_true(String(r.get("text", "")) != "", "y dice por qué: %s" % String(r.get("text", "")))
