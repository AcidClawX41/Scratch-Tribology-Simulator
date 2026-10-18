## La interfaz del laboratorio calcula siempre con el modelo de la física del banco (LabState.model: "2.0" en la
## aplicación). Dos vigilancias:
##   - en el código: nada en app/ llama a Physics.compute, Physics.resolve_tool ni Lab.duel directamente (tienen que
##     pasar por lab.compute(), lab.duel() y lab.tool(), que llevan el modelo), ni a las funciones de las notas de los
##     parámetros (lab.pass_factor() y lab.tear_lever()), y en lab_state.gd esas llamadas solo están en los _core_* que
##     espía el doble;
##   - en marcha: con un doble de LabState que apunta el modelo de cada cálculo que llega al core, un recorrido por la
##     interfaz (herramienta, material, modo dual, ensayo, comparativa y cambio de modelo) solo usa el del banco.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const Physics = preload("res://core/lab/physics.gd")
const Spy = preload("res://tests/app/lab_state_spy.gd")

const PHYSICS_PATH := "res://core/lab/physics.gd"
const LAB_PATH := "res://core/lab/lab.gd"


## Nombres con que un script importa otro (const X = preload("…")).
static func _aliases(code: String, path: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("const\\s+(\\w+)\\s*(?::\\s*\\w+\\s*)?:?=\\s*preload\\(\\s*\"%s\"\\s*\\)" % path.replace(".", "\\."))
	for m: RegExMatch in re.search_all(code):
		out.append(m.get_string(1))
	return out


## Llamadas prohibidas en un script de la interfaz: [texto de la llamada, qué usar en su lugar].
static func _forbidden_calls(raw: String) -> Array:
	# los alias se buscan en el código tal cual (la ruta es un texto); las llamadas, sin comentarios ni textos
	var out: Array = []
	for a in _aliases(raw, PHYSICS_PATH):
		out.append(["%s.compute(" % a, "lab.compute()"])
		out.append(["%s.resolve_tool(" % a, "lab.tool()"])
		out.append(["%s.pass_depth_factor(" % a, "lab.pass_factor()"])
		out.append(["%s.tear_leverage(" % a, "lab.tear_lever()"])
	for a in _aliases(raw, LAB_PATH):
		out.append(["%s.duel(" % a, "lab.duel()"])
	out.append(["physics.gd\").compute(", "lab.compute()"])
	out.append(["lab.gd\").duel(", "lab.duel()"])
	return out


func test_la_interfaz_no_llama_al_core_de_la_fisica_directamente() -> void:
	var files := gd_files("res://app")
	assert_true(files.size() > 20, "scripts de la interfaz: %d" % files.size())
	for f in files:
		var raw := FileAccess.get_file_as_string(f)
		var code := code_only(raw)
		for pair: Array in _forbidden_calls(raw):
			var call: String = pair[0]
			# los textos quedan en blanco en code_only: la llamada a preload("…").compute( se busca en el original
			var where := raw if call.begins_with("physics.gd") or call.begins_with("lab.gd") else code
			assert_false(where.contains(call), "%s llama a %s: tiene que usar %s, que lleva el modelo del banco" % [f, call, pair[1]])


func test_el_estado_del_banco_solo_llama_al_core_desde_sus_core() -> void:
	var raw := FileAccess.get_file_as_string("res://core/lab/lab_state.gd")
	var code := code_only(raw)
	for call: String in ["Physics.compute(", "Physics.resolve_tool(", "Lab.duel("]:
		assert_eq(code.count(call), 1, "lab_state.gd llama a %s una sola vez (en su _core_*)" % call)
	for fn: String in ["_core_compute", "_core_duel", "_core_tool"]:
		assert_true(code.contains("func %s(" % fn), "LabState.%s existe (lo espía el doble)" % fn)
	# y cada _core_* es la que hace su llamada: el cuerpo de la función contiene la llamada al core
	for pair: Array in [["_core_compute", "Physics.compute("], ["_core_duel", "Lab.duel("], ["_core_tool", "Physics.resolve_tool("]]:
		var at := code.find("func %s(" % pair[0])
		var next := code.find("\nfunc ", at + 1)
		var body := code.substr(at, (next if next > 0 else code.length()) - at)
		assert_true(body.contains(pair[1]), "%s llama a %s" % pair)


func test_el_estado_del_banco_lleva_su_modelo_al_core() -> void:
	var lab: RefCounted = Spy.new()
	assert_eq(lab.model, "2.0", "el banco de la aplicación usa la física 2.0")
	assert_eq(lab.params().model, "2.0", "params() lleva el modelo")
	lab.model = Physics.MODEL_V1
	lab.run()
	lab.duel()
	lab.tool()
	lab.strike_j()
	var p: Dictionary = lab.params()
	p.model = "2.0"  # un modelo que venga en los parámetros no manda: manda el del banco
	lab.compute(p)
	var sum: Dictionary = lab.summary()
	assert_eq(sum, { "compute": { "1.x": 2 }, "duel": { "1.x": 1 }, "tool": { "1.x": 2 } }, "todo con el modelo del banco")
	lab.set_model(Physics.MODEL_V2)
	assert_eq(lab.phase, "idle", "cambiar de modelo resetea el banco")
	lab.seen.clear()
	lab.run()
	assert_eq(lab.summary(), { "compute": { "2.0": 1 } }, "y el ensayo siguiente ya es con el nuevo")


## Pulsa un control de la sección y deja que se ponga al día.
func _click(s: Control, b: BaseButton) -> void:
	b.pressed.emit()
	s.step(0.0)


func test_toda_la_interfaz_usa_el_modelo_del_banco() -> void:
	var s: Control = LabSection.instantiate()
	s.state_script = Spy
	s.setup()
	s.art.threaded = false
	var lab: RefCounted = s.lab
	assert_true(lab.get_script() == Spy, "la sección usa el script de estado que se le da")
	assert_eq(lab.model, Physics.MODEL_V2, "la sección arranca con la física 2.0")
	for pass_i in 2:
		var model: String = [Physics.MODEL_V1, Physics.MODEL_V2][pass_i]
		lab.set_model(model)
		s.refresh_now()
		lab.seen.clear()
		# garra de tigre contra el coche moderno, modo dual, un ensayo y la comparativa; luego una uña
		_click(s, s.tool_card.kind_seg.buttons["garras"])
		_click(s, s.tool_card.claw_tiles["tigre" if pass_i == 0 else "oso"])
		_click(s, s.target_card.tiles["coche" if pass_i == 0 else "cochealu"])
		if not lab.dual:
			_click(s, s.dual_card.toggle)
		_click(s, s.run_button)
		s.step(LabState.RUN_MS + 50.0)
		s.refresh_now()
		# una fila por cada ficha de la familia que se ve en la tarjeta de la herramienta (garras y colmillos; los
		# aguijones tienen su propia comparativa)
		var shown := 0
		for id: String in s.tool_card.claw_tiles:
			shown += 1 if ((s.tool_card.claw_tiles[id] as Control).get_parent() as Control).visible else 0
		assert_eq(shown, 19, "fichas de garras y colmillos a la vista (con los dos velocirraptores de la 2.0: la reconstrucción y el de película)")
		assert_eq(s.compare_card.rows.size(), shown, "comparativa: una fila por garra")
		_click(s, s.tool_card.kind_seg.buttons["unas"])
		s.refresh_now()
		var sum: Dictionary = lab.summary()
		for what: String in ["compute", "duel", "tool"]:
			assert_true(sum.has(what), "%s: la interfaz calcula con %s()" % [model, what])
			assert_eq(sum.get(what, {}).keys(), [model], "%s: todo %s con el modelo del banco (%s)" % [model, what, sum])
		assert_true(int(sum.get("compute", {}).get(model, 0)) > 20, "el ensayo y las filas de la comparativa (%s)" % [sum])
	s.free()
