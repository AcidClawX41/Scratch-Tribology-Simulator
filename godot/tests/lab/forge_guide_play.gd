## Ayuda de los tests del guiado de la reforja (unidad 5x): jugar un tutorial pulsando solo lo que señala el guiado (la orden de
## su control, op y args, la misma que manda su botón), con el tiempo que pasa entre una pulsación y otra.
extends RefCounted

const State = preload("res://core/lab/claw_forge_state.gd")

const FRAME := 1.0 / 30.0
## Cuántas veces seguidas puede señalar lo mismo (las dosis de un polvo, las pasadas de una muela, los puntos de una costura).
const SAME_MAX := 400


static func new_state(animal: String, claw: String, process: String, shape := "funda") -> State:
	var st := State.new({ "animal": animal, "claw": claw })
	st.set_speed(State.SPEEDS.size() - 1)
	st.set_process(process)
	st.set_shape(shape)
	return st


## Deja que acabe lo que corre (la marcha, la animación del taller).
static func settle(st: State) -> void:
	for i in 9000:
		if not st.running() and (st.act.is_empty() or float(st.act.t) >= float(st.act.dur)):
			return
		st.tick(FRAME)


## Juega el tutorial tid pulsando solo lo que señala el guiado. { ok, why, seq (los objetivos, en orden) }.
static func play(st: State, tid: String, max_ops := 4000) -> Dictionary:
	if st.tut_id != tid:
		st.tutorial_goto(tid)
	var seq: Array = []
	var same := 0
	var last := ""
	for n in max_ops:
		if st.tutorial_done():
			return { "ok": true, "why": "", "seq": seq }
		var g := st.guide_view()
		if not bool(g.on):
			return { "ok": false, "why": "sin guiado en «%s»" % String(st.current_step().get("id", "")), "seq": seq }
		seq.append(g)
		var key := "%s|%s" % [String(g.step), String(g.id)]
		same = same + 1 if key == last else 0
		last = key
		if same > SAME_MAX:
			return { "ok": false, "why": "se queda en %s (%s) · %s" % [key, String(g.hint), st.notice], "seq": seq }
		st.callv(String(g.op), g.args)
		settle(st)
		if String(g.op) == "weld_pulse_next":
			st.tick(st.weld_period_s() + 1e-3)
	return { "ok": false, "why": "no acaba en %d pulsaciones" % max_ops, "seq": seq }
