## Estado del banco (core/lab/lab_state.gd): port de packages/core/test/labState.test.js. El reloj simulado de
## node:test (mock.timers.tick) es aquí advance(ms); cubren los dos fallos de temporizadores que tenía la interfaz.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")

const RUN_MS := LabState.RUN_MS

var sounds: Array[String] = []
var volumes: Array[float] = []
var changes := 0
var lab: RefCounted


func before_each() -> void:
	sounds = []
	volumes = []
	changes = 0
	lab = LabState.new(_play, _sfx_stub)
	lab.model = Physics.MODEL_V1  # port de los tests de la 1.x: con la física del motor 1.x
	lab.changed.connect(_on_changed)  # un método, no una lambda: la lambda retendría el test (ciclo de referencias)


func _play(id: String, volume: float) -> void:
	sounds.append(id)
	volumes.append(volume)


func _on_changed() -> void:
	changes += 1


## Doble de sfx_for_result (core/lab/sfx.gd, de la unidad de sonido): solo distingue lo que miran estos tests.
static func _sfx_stub(res: Dictionary, _target: Dictionary) -> String:
	if res.puncture:
		return "inject" if res.get("inject") else "pierce-solid"
	return "scratch-soft"


static func T(id: String) -> Dictionary:
	return Data.find_by_id(Data.TARGETS, id)


static func K(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


func _car_ids() -> Array:
	return lab.dual_cars().map(func(t: Dictionary) -> String: return t.id)


func test_modo_dual_activarlo_no_borra_el_ensayo_y_cambiar_un_coche_si() -> void:
	assert_eq(lab.dual, false)
	assert_eq(_car_ids(), Lab.DUEL_DEFAULT)
	lab.run()
	lab.advance(RUN_MS)
	assert_eq(lab.phase, "done")
	lab.set_dual(true)
	assert_eq(lab.dual, true)
	assert_eq(lab.phase, "done", "activar el modo dual no debe borrar el ensayo")
	lab.set_dual_car(1, "cochealu")
	assert_eq(_car_ids(), [Lab.DUEL_DEFAULT[0], "cochealu"])
	assert_eq(lab.phase, "idle", "cambiar un coche de la pareja resetea el banco")
	assert_true(sounds.has("on"), "activar el modo dual suena")
	assert_eq(Lab.DUEL_DEFAULT, ["cocheclasico", "coche"], "la pareja por defecto no cambia al elegir otro coche")


func test_valores_iniciales_y_ensayo_completo() -> void:
	# por valor: GDScript pliega las constantes de otro script en copias (Data.GEOMS[3] no es el mismo objeto en
	# lab_state.gd que en data.gd), y == compara diccionarios por contenido
	assert_eq(lab.geom, LabState.LAB_DEFAULTS.geom)
	assert_eq(lab.geom.id, "almendra")
	assert_eq(lab.phase, "idle")
	assert_eq(lab.res, null)
	lab.run()
	assert_eq(lab.phase, "running")
	var p: Dictionary = lab.params()
	p.claw = null
	p.tear = false
	assert_eq(oracle_diff(lab.res, Physics.compute(p)).size(), 0, "el banco no hace física propia")
	lab.advance(RUN_MS - 1)
	assert_eq(lab.phase, "running")
	lab.advance(1)
	assert_eq(lab.phase, "done")
	assert_true(changes >= 2, "el banco avisa de cada cambio (ensayo y fin de la animación)")


func test_regresion_cambiar_un_parametro_a_mitad_no_deja_la_tarjeta_vacia() -> void:
	lab.run()
	lab.advance(300)
	lab.set_target(T("movil"))
	lab.advance(RUN_MS)  # el temporizador viejo ya habría disparado
	assert_eq(lab.phase, "idle")
	assert_eq(lab.res, null)


func test_regresion_un_ensayo_viejo_no_termina_antes_de_tiempo_el_nuevo() -> void:
	lab.run()  # A: t = 0
	lab.advance(500)
	lab.set_target(T("vidrio"))
	lab.advance(100)
	lab.run()  # B: t = 600
	lab.advance(700)  # t = 1300 (A habría terminado a 1150)
	assert_eq(lab.phase, "running")
	lab.advance(RUN_MS - 700)
	assert_eq(lab.phase, "done")


func test_sonidos_la_puncion_suena_al_impactar_y_un_reset_cancela_los_pendientes() -> void:
	lab.set_claw(K("vibora"))
	lab.set_target(T("piel"))
	lab.set_method("puncion")
	sounds.clear()
	lab.run()
	assert_eq(sounds, [], "no suena antes del impacto")
	lab.advance(RUN_MS * 0.78)
	assert_eq(sounds[0] if sounds.size() > 0 else "", "inject")
	# nuevo ensayo y cambio inmediato: el impacto pendiente no debe sonar
	sounds.clear()
	lab.run()
	lab.set_force(2.0)  # deslizador: resetea sin clic
	lab.advance(RUN_MS * 2)
	assert_eq(sounds.filter(func(x: String) -> bool: return x != "badge"), [])
	assert_eq(lab.pending_timers(), 0)


func test_el_rayado_suena_al_momento_y_los_clics_de_la_interfaz() -> void:
	lab.run()
	assert_eq(sounds, ["scratch-soft"], "el rayado suena mientras la punta avanza")
	sounds.clear()
	lab.set_geom(Data.GEOMS[0])
	lab.set_wet(true)
	lab.set_wet(false)
	lab.set_length(10.0)
	lab.set_passes_slider(3.0)
	lab.set_passes(2.0)
	lab.set_dual(true)
	lab.set_dual(false)
	assert_eq(sounds, ["tap", "drip", "tap", "tap", "on", "off"], "los deslizadores no hacen clic")
	assert_eq(lab.length, 10.0)
	assert_eq(lab.passes, 2.0)


func test_logros_con_fanfarria_diferida_y_cuaderno_limitado() -> void:
	lab.set_claw(K("gato"))  # «depredador» al primer ensayo con garra
	sounds.clear()
	volumes.clear()
	lab.run()
	lab.advance(RUN_MS + 149)
	assert_false(sounds.has("badge"), "la fanfarria espera a que acabe la animación")
	lab.advance(1)
	assert_true(sounds.has("badge"))
	assert_eq(volumes[sounds.find("badge")], 0.5, "la fanfarria suena a media voz")
	assert_eq(volumes[sounds.find("scratch-soft")], LabState.DEFAULT_VOLUME, "el resto, al volumen por defecto de la 1.x")
	assert_eq(LabState.DEFAULT_VOLUME, 0.7)
	assert_true(lab.badges.has("depredador"))
	for k in LabState.LOG_SIZE + 3:
		lab.run()
		lab.advance(RUN_MS)
	var book: Array = lab.notebook
	assert_eq(book.size(), LabState.LOG_SIZE)
	var ids := {}
	for e: Dictionary in book:
		ids[e.id] = true
	assert_eq(ids.size(), LabState.LOG_SIZE, "ids únicos en el cuaderno")
	assert_eq(book[0].id, LabState.LOG_SIZE + 4, "el más reciente primero")
	assert_eq(book[0].tool, "Garra de gato")
	assert_eq(book[0].tgt, "Uña ajena")
	assert_true(lab.badges.has("fisico"), "a los %d ensayos, «Físico de bata»" % Lab.BADGE_RUNS)


func test_al_desmontar_no_queda_ningun_temporizador_vivo() -> void:
	lab.run()
	lab.dispose()
	sounds.clear()
	lab.advance(RUN_MS * 3)
	assert_eq(sounds, [])
	assert_eq(lab.pending_timers(), 0)
	assert_eq(lab.phase, "done", "un ensayo a medio animar no se queda en «running» para siempre")
	assert_true(lab.res != null, "y conserva su resultado")


func test_herramienta_fuerza_maxima_y_golpe() -> void:
	assert_eq(lab.max_f().label, "humana")
	assert_eq(lab.strike_j(), 0.5 * Data.HUMAN.strike.m * Data.HUMAN.strike.v * Data.HUMAN.strike.v)
	lab.set_claw(K("casuario"))
	assert_eq(lab.max_f().force, K("casuario").force)
	assert_eq(lab.tool().reach, K("casuario").reach)
	assert_eq(lab.strike_j(), 0.5 * 5.0 * 8.0 * 8.0)
	lab.set_claw(null)
	assert_eq(lab.tool().useClaw, false)
