## Tribología biológica · estado de la tarjeta «Coche en marcha» (unidad 4c): lo que se ha elegido y lo que
## core/lab/moving_car.gd (MovingCar) calcula con ello. Sin nodos (RefCounted): lo usan la tarjeta
## (app/lab/moving_car_card.gd), su dibujo (moving_car_view.gd) y su gráfica (moving_car_chart.gd), que solo pintan.
##
## Qué guarda: el animal (una garra del catálogo), el coche (uno de los cuatro del catálogo), el modo («hold»: se agarra
## encima; «impact»: se abalanza), la zona y la postura, la velocidad del coche, el viento de frente y el lateral, la
## maniobra (MovingCar.MANEUVERS), la temperatura y la altitud del aire, las garras clavadas y los datos del golpe
## (velocidad y ángulo del animal, caída y masa del coche). De la unidad 4d (docs/fisica/coche-en-marcha.md §9.10): el
## material de las garras (inlay, un id de Data.INLAYS; «none» es la queratina), el animal asustado (defense) y el sexo
## del casuario (sex), que solo patea: no se queda encima (MovingCar.supports_hold, HOLD_NO_REASON).
##
## Qué calcula y cuándo (docs/fisica/coche-en-marcha.md §9.2):
##   - setup(p) al cambiar el animal, el coche, la zona, la postura, el viento o la maniobra (~0,4-1 ms), y con él la
##     gráfica: curve(scen) (~1,3 ms), que ya trae el despegue (detach) del que sale su veredicto (detach_verdict);
##   - with_air(scen, t, h) y curve sobre la copia al mover la temperatura o la altitud (sin volver a llamar a compute);
##   - at_speed(scen, v) al mover la velocidad (~20 µs): vale para cada fotograma de un deslizador;
##   - lo caro, hold_report(p) (~1-2 ms) e impact(p) (~2-10 ms), fuera del hilo principal: una tarea de
##     WorkerThreadPool (add_group_task con prioridad alta) al soltar el deslizador y, en el golpe, como mucho cada
##     DRAG_HEAVY_MS mientras se arrastra. step(ms) lanza y recoge esas tareas; finish() las espera. Son funciones
##     puras: con hilo sale lo mismo que sin hilo (threaded = false las hace en el acto). Un resultado que llega de otro
##     ensayo se descarta; si solo se han movido los deslizadores, se enseña mientras llega el bueno (heavy_fresh()).
## La señal `changed` avisa de cualquier cambio; setup_version, live_version y heavy_version dicen qué ha cambiado
## (la interfaz repinta solo lo necesario).
##
## Textos: todos los números visibles salen de MovingCar con los formatos de siempre (core/shared/js.gd y format.gd,
## como en MovingCar: N hasta 10 kN, kN después; energías en J y kJ; longitudes en µm, mm y cm, y m desde 1 m). Cada
## lectura lleva su calidad (dato medido, de un caso parecido o estimación) y su fuente, y sources() junta todas las del
## ensayo para enseñarlas. La banda (los datos más desfavorables y los más favorables) va siempre con el valor central.
##
## Para entenderlo (sin física nueva: frases con los números de MovingCar, de ClawsV2 y del catálogo):
##   - why_text(): el porqué del veredicto en una frase (qué lo suelta: el viento, la frenada, la sustentación, la curva
##     o la pendiente; en el golpe, por qué la queratina no raya el acero, por qué abolla o por qué se agrieta el
##     parabrisas);
##   - facts(): «¿sabías que…?», datos reales del ensayo con su fuente y su calidad;
##   - moral(): la moraleja, con el humor de las frases de la guía (§9.4) y los números del ensayo;
##   - EXPERIMENTS y load_experiment(): ensayos de un clic (un solo setup);
##   - impact_sfx(): el efecto de sonido del banco (los de la 1.x, core/lab/sfx.gd) que corresponde al golpe.
## Unidad 4i-B2: los dos velocirraptores (el de película, FICCIÓN, que sale por defecto al elegir «Velocirraptor», y la
## reconstrucción, a un clic: VARIANTS y variants()), la calidad «ficcion» («ficción (película)») y el afilado de unas garras
## reforjadas (sharpness, set_sharpness, sharpenable, sharpness_view).
## Uso: const MovingCarState = preload("res://core/lab/moving_car_state.gd"); var st := MovingCarState.new()
extends RefCounted

signal changed

const MovingCar = preload("res://core/lab/moving_car.gd")
const CarSpeedMarks = preload("res://core/lab/car_speed_marks.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Format = preload("res://core/shared/format.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const Glazing = preload("res://core/lab/glazing.gd")
## Unidad 4s: hasta dónde llega cada marca y si raja o abre el panel.
const CarTear = preload("res://core/lab/car_tear.gd")
const CarHoldMarks = preload("res://core/lab/car_hold_marks.gd")
## Unidad 4t: el coche en curva (la aceleración lateral v²/R, el tope del coche y la curva en S).
const CarCurve = preload("res://core/lab/car_curve.gd")
const CarCurveGrip = preload("res://core/lab/car_curve_grip.gd")

## El coche en marcha solo existe en la física 2.0 (no hay nada de él en el motor 1.x).
const MODEL := "2.0"
const MODE_HOLD := "hold"
const MODE_IMPACT := "impact"
const MODES := [
	{ "id": MODE_HOLD, "name": "Encima del coche", "title": "Se agarra encima: a qué velocidad se suelta y por qué" },
	{ "id": MODE_IMPACT, "name": "Se abalanza", "title": "Salta sobre el coche en marcha: el golpe, las marcas, la abolladura y la energía" },
]
## Los coches del catálogo (los de data.gd). La aleta de plástico es una aleta: con ella solo tiene sentido esa zona
## (docs/fisica/coche-en-marcha.md §4).
## El deportivo (core/lab/sports_car.gd, unidad 4r) llega a su velocidad máxima en el deslizador (slider_max_kmh).
const CARS := ["coche", "cocheclasico", "cochealu", "cocheplastico", "deportivo"]
const PLASTIC_CAR := "cocheplastico"
const PLASTIC_ZONE := "aleta"
const DEFAULT_ZONE := "techo"
const DEFAULT_MANEUVER := "crucero"
## Mientras se arrastra un deslizador del golpe, impact() se recalcula como mucho cada DRAG_HEAVY_MS (la guía §9.2:
## «al soltar el deslizador o unas pocas veces por segundo»).
const DRAG_HEAVY_MS := 200.0
## Por dónde se va el animal cuando no aguanta (MovingCar._mode_of; la guía §9.6).
const EXIT_TEXT := {
	"despega": "despega: sube y vuela",
	"atras": "sale despedid%s hacia atrás",
	"delante": "sale despedid%s hacia delante",
	"abajo": "resbala por el panel",
	"lado": "sale por el costado",
}
## Calidad de un dato (CONTRATOS.md: «primary» medido en la especie o el objeto; «secondary» medido en un caso cercano o
## escalado poco; «estimate» sin medición).
## «ficcion» (unidad 4i-B2): lo de película del velocirraptor de ficción; nunca un dato (la tarjeta la pinta aparte).
const QUALITY_TEXT := {
	"primary": "dato medido", "secondary": "dato de un caso parecido", "estimate": "estimación", "ficcion": "ficción (película)",
}
const QUALITY_RANK := { "": 0, "primary": 1, "secondary": 2, "estimate": 3, "ficcion": 4 }
## Ancho de la búsqueda del despegue (MovingCar.SCAN_MAX_KMH): la barra de la banda va de 0 a este tope.
const BAND_MAX_KMH := MovingCar.SCAN_MAX_KMH
## Fuentes que se enseñan (unidad 4j: legibles, con autor y año, norma o ficha; nunca rutas ni nombres de código).
const SRC_MASS := "la masa del catálogo del banco, la misma de la 1.x, sin cita propia"
const SRC_DOC_ESTIMATES := "estimación del modelo, sin medición publicada"
const SRC_HARDNESS := "dureza de la carrocería: la de su material en las fichas de los fabricantes (acero de horno: Nippon Steel 2013 y voestalpine 2022; acero dulce: ArcelorMittal; aluminio: Hirsch 2011; plástico: SABIC), pasada a HV con la relación de Tabor y el endurecimiento de Hollomon; de la pintura, 20 HV (un barniz de poliuretano); quién cede: con menos de 0,8 veces la dureza del panel, la punta (Tabor 1954, en Pintaude 2021; Richardson 1968)"
const SRC_KINEMATICS := MovingCar.SRC_KINEMATICS
const SRC_HUMOR := "frases con humor que no traicionan la física, con los números del ensayo"

## Experimentos de un clic: cada uno carga un ensayo entero, sin viento y con el aire de referencia; lo que no dice va
## con los valores por defecto de MovingCar.PARAMS (y garras de queratina, sin asustarse). Los de la unidad 4d son sus
## casos de referencia (tests/fixtures/spec/coche-en-marcha.json: tigre-zafiro-puerta, aguila-tungsteno-techo-clavada,
## casuario-puerta-hembra y lechuza-defensa-techo). «aire» no cambia el ensayo: le pone el aire de 35 °C a 2000 m, o se
## lo quita (docs/fisica/coche-en-marcha.md §1: «el aire cambia con la temperatura y la altitud»).
const EXPERIMENTS := [
	{ "id": "aguila_120", "name": "¿Aguanta el águila a 120 km/h?", "claw": "aguila", "car": "coche", "mode": MODE_HOLD,
		"zone": "techo", "posture": "plegadas", "v_kmh": 120.0, "maneuver": "crucero" },
	{ "id": "aguila_alas", "name": "¿Y si abre las alas?", "claw": "aguila", "car": "coche", "mode": MODE_HOLD,
		"zone": "techo", "posture": "abiertas", "v_kmh": 30.0, "maneuver": "crucero" },
	{ "id": "oso_frenada", "name": "El oso en una frenada de emergencia", "claw": "oso", "car": "coche", "mode": MODE_HOLD,
		"zone": "techo", "posture": "tumbado", "v_kmh": 90.0, "maneuver": "emergencia" },
	{ "id": "lechuza_asustada", "name": "La lechuza, asustada", "claw": "lechuza", "car": "coche", "mode": MODE_HOLD,
		"zone": "techo", "posture": "plegadas", "v_kmh": 90.0, "maneuver": "crucero", "defense": true },
	{ "id": "aguila_tungsteno", "name": "El águila con talones de tungsteno", "claw": "aguila", "car": "coche",
		"mode": MODE_HOLD, "zone": "techo", "posture": "plegadas", "v_kmh": 150.0, "maneuver": "crucero",
		"inlay": "tungsteno", "embedded": true },
	{ "id": "tigre_puerta", "name": "El tigre contra la puerta", "claw": "tigre", "car": "coche", "mode": MODE_IMPACT,
		"impact_zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0 },
	{ "id": "tigre_zafiro", "name": "El tigre con garras de zafiro", "claw": "tigre", "car": "coche", "mode": MODE_IMPACT,
		"impact_zone": "puerta", "v_kmh": 50.0, "animal_kmh": 40.0, "angle_deg": 90.0, "inlay": "zafiro" },
	{ "id": "casuario_puerta", "name": "La patada del casuario hembra", "claw": "casuario", "car": "coche", "mode": MODE_IMPACT,
		"impact_zone": "puerta", "v_kmh": 50.0, "animal_kmh": 0.0, "angle_deg": 90.0, "sex": "hembra" },
	# unidad 4i-B2: el velocirraptor de película (ficción) y, con el mismo salto, el de verdad (la reconstrucción)
	{ "id": "velocirraptor_pelicula", "name": "El velocirraptor de cine", "claw": "velociraptor_pelicula",
		"car": "coche", "mode": MODE_IMPACT, "impact_zone": "capo", "v_kmh": 50.0, "animal_kmh": 39.0, "angle_deg": 90.0 },
	{ "id": "velocirraptor_real", "name": "Y el de verdad, en el mismo salto", "claw": "velociraptor", "car": "coche",
		"mode": MODE_IMPACT, "impact_zone": "capo", "v_kmh": 50.0, "animal_kmh": 39.0, "angle_deg": 90.0 },
	# unidad 4m: la ventanilla templada. Con poca fuerza (el águila que cruza a 20 km/h no la parte al flexar) la revientan unas
	# garras de diamante, que abren la grieta que atraviesa la capa comprimida; con sus talones de queratina, aguanta
	{ "id": "ventanilla_diamante", "name": "La garra de diamante contra la ventanilla", "claw": "aguila", "car": "coche",
		"mode": MODE_IMPACT, "impact_zone": "luna", "v_kmh": 50.0, "animal_kmh": 20.0, "angle_deg": 90.0, "inlay": "diamante" },
	{ "id": "ventanilla_queratina", "name": "Y con sus talones de queratina", "claw": "aguila", "car": "coche",
		"mode": MODE_IMPACT, "impact_zone": "luna", "v_kmh": 50.0, "animal_kmh": 20.0, "angle_deg": 90.0 },
	{ "id": "aire", "name": "El mismo, a 35 °C y a 2000 m", "air": [35.0, 2000.0] },
]
## Datos del ensayo que pone un experimento (los que no dice, a su valor por defecto de MovingCar.PARAMS). El aire no:
## «aire» se suma a cualquier experimento. Para ver si lo que se ve es el experimento, solo cuentan los de su modo.
const _EXPERIMENT_KEYS := ["v_kmh", "wind_kmh", "crosswind_kmh", "animal_kmh", "angle_deg", "drop_m", "car_mass_kg"]
const _EXPERIMENT_KEYS_HOLD := ["v_kmh", "wind_kmh", "crosswind_kmh"]
const _EXPERIMENT_KEYS_IMPACT := ["v_kmh", "animal_kmh", "angle_deg", "drop_m", "car_mass_kg"]
## Material de las garras por defecto: la queratina (Data.INLAYS «none»).
const KERATIN := "none"
## Animales con dos aspectos en el selector (unidad 4i-B2): el velocirraptor es uno solo, con el de película (FICCIÓN) por
## defecto y la reconstrucción a un clic. Por id de BODIES: la lista de variantes, la primera la de por defecto.
const VARIANTS := { "velociraptor_pelicula": ["velociraptor_pelicula", "velociraptor"] }
const VARIANT_NAMES := { "velociraptor_pelicula": "De cine (ficción)", "velociraptor": "Reconstrucción (datos)" }
## Nombre del animal en el selector cuando tiene variantes.
const ANIMAL_NAMES := { "velociraptor_pelicula": "Velocirraptor" }
## Qué hace el animal asustado (docs/fisica/coche-en-marcha.md §12.1).
const DEFENSE_TIP := "Asustado aprieta con toda su fuerza: una rapaz, con su agarre máximo medido; el tigre y el oso, con la fuerza teórica de los flexores de sus garras; el casuario ya patea con toda la suya"
## Artículo y terminación de los adjetivos de cada animal (la tabla de MovingCar, que también la usan sus veredictos).
const GRAMMAR := MovingCar.GRAMMAR
## Cada zona con su artículo, para las frases («En el techo el aire va más deprisa…»).
const ZONE_ARTICLE := {
	"capo": "el capó", "limpiaparabrisas": "el limpiaparabrisas", "parabrisas": "el parabrisas", "techo": "el techo",
	"barras": "las barras de techo", "antena": "la antena", "retrovisor": "el retrovisor",
	"ventanilla": "el borde de la ventanilla", "maletero": "el maletero", "aleta": "la aleta", "puerta": "la puerta",
	"luna": "la ventanilla",  # unidad 4m: la ventanilla templada, zona del golpe (en ZONES, «ventanilla» es su borde)
	"luneta": "la luneta",  # unidad 4v: la luneta templada, donde puede quedarse
}

# ── Lo que se ha elegido ──
var claw: Variant = null  # garra del catálogo (Dictionary) o null (una uña)
var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, CARS[0])
var mode := MODE_HOLD
var zone := DEFAULT_ZONE
var impact_zone := DEFAULT_ZONE
var posture := ""
var embedded := false
var v_kmh: float = MovingCar.PARAMS.v_kmh.default
var wind_kmh: float = MovingCar.PARAMS.wind_kmh.default
var crosswind_kmh: float = MovingCar.PARAMS.crosswind_kmh.default
var maneuver := DEFAULT_MANEUVER
var accel_g: float = MovingCar.PARAMS.accel_g.default
var lateral_g: float = MovingCar.PARAMS.lateral_g.default
var temp_c: float = MovingCar.PARAMS.temp_c.default
var altitude_m: float = MovingCar.PARAMS.altitude_m.default
var animal_kmh: float = MovingCar.PARAMS.animal_kmh.default
var angle_deg: float = MovingCar.PARAMS.angle_deg.default
var drop_m: float = MovingCar.PARAMS.drop_m.default
var car_mass_kg: float = MovingCar.PARAMS.car_mass_kg.default
## Material de las garras (id de Data.INLAYS; «none», la queratina), animal asustado y sexo del casuario (unidad 4d).
var inlay := KERATIN
## Afilado de unas garras reforjadas (0-1, el de Physics.sharpness_of: MovingCar lo ignora con la queratina).
var sharpness := 0.0
var defense := false
## Unidad 4t: la carretera (CarCurve.ROADS: «recta», «curva» o «s») y el radio de la curva (m). En recta, nada cambia.
var road: String = CarCurve.ROAD_STRAIGHT
var radius_m: float = CarCurve.DEFAULT_R
## En la curva en S, el despegue de los dos lados (CarCurve.detach_s: worst, right, left); {} en recta o en curva.
var curve_sides: Dictionary = {}
var sex: String = MovingCar.SEXES[0]
## Se está arrastrando un deslizador (lo caro espera a soltarlo; el golpe, como mucho cada DRAG_HEAVY_MS).
var dragging := false
## Lo caro en hilos (false: en el acto; los tests comparan los dos caminos).
var threaded := true

# ── Lo que calcula MovingCar ──
## setup(p) con el aire elegido (la copia de with_air al mover la temperatura o la altitud).
var scen: Dictionary = {}
## Gráfica en directo: curve(scen) (61 puntos de 0 al tope del coche, slider_max_kmh, y el despegue).
var chart: Dictionary = {}
## Unidad 4s: la gráfica del daño frente a la velocidad (CarSpeedMarks.curve), que llega del hilo de lo caro una vez por
## ensayo (su clave, la del animal quieto encima sin la velocidad: _marks_key); {} mientras no llega.
var marks_chart: Dictionary = {}
var _marks_key: Array = []
## Velocidad de despegue con su banda (chart.detach) y su veredicto.
var det: Dictionary = {}
var verdict: Dictionary = {}
## Fuerzas a v_kmh (at_speed).
var at: Dictionary = {}
## Fuerzas donde se suelta (at_speed en det.kmh; con el coche parado si ni parado se sostiene; vacío si no se suelta ni
## a 400 km/h): los números del porqué.
var at_detach: Dictionary = {}
## Asustado, el despegue del mismo ensayo sin asustarse (para comparar: «de 115 a 167 km/h»); {} sin defensa.
var det_rest: Dictionary = {}
## El aire en palabras (MovingCar.air_txt).
var air_txt := ""
## Informe del animal quieto encima (hold_report) y golpe (impact): los caros, que llegan de los hilos.
var report: Dictionary = {}
var hit: Dictionary = {}
var setup_version := 0
var live_version := 0
var heavy_version := 0
## Cambia con cada golpe nuevo que llega (el dibujo lo anima desde el principio).
var hit_version := 0
## Métricas (µs): lo que ha tardado el último cálculo de cada clase en este hilo o en el de trabajo.
var last_setup_us := 0
var last_live_us := 0
var last_heavy_us := 0

var _base: Dictionary = {}  # setup(p) sin tocar (with_air trabaja sobre él)
var _base_rest: Dictionary = {}  # asustado: el mismo setup sin asustarse ({} sin defensa)
var _mode_choice := MODE_HOLD  # el modo que eligió la persona (el casuario solo tiene el golpe)
var _report_key: Array = []
var _hit_key: Array = []
var _tasks: Array = []  # [{ task, kind, key, out: [resultado, µs] }], en el orden en que se lanzaron
var _clock := 0.0
var _last_launch := -1.0e9


func _init(p_claw: Variant = null, p_target: Variant = null) -> void:
	if p_target is Dictionary and CARS.has(p_target.get("id")):
		target = p_target
	claw = p_claw
	_fit_selection()
	_rebuild()


func _notification(what: int) -> void:
	# ningún hilo puede quedar trabajando para un estado que ya no existe (aquí no se pueden llamar métodos: solo campos)
	if what == NOTIFICATION_PREDELETE:
		for t: Dictionary in _tasks:
			WorkerThreadPool.wait_for_group_task_completion(int(t.task))
		_tasks.clear()


# ════════ Lecturas de la selección ════════

## ¿Hay datos del animal elegido para el coche en marcha? (las seis rapaces, el tigre, el oso y el casuario)
func supported() -> bool:
	return claw != null and MovingCar.supports(claw)


## ¿Puede quedarse encima del coche? (todos menos el casuario, que solo patea: MovingCar.HOLD_NO_REASON)
func supports_hold() -> bool:
	return supported() and MovingCar.supports_hold(claw)


## ¿Ataca con una patada? (el casuario)
func is_kicker() -> bool:
	return supported() and MovingCar.is_kicker(MovingCar.body_of(claw))


## ¿Se abalanza saltando? (los velocirraptores, unidad 4i-B2: el salto ya da la caída, así que la tarjeta puede esconder el
## deslizador de la caída, como con la patada)
func is_leaper() -> bool:
	return supported() and MovingCar.is_leaper(MovingCar.body_of(claw))


## Sexos con datos propios del animal (el casuario: la hembra de 58 kg y el macho de 31,5 kg) o [].
func sexes() -> Array:
	return MovingCar.sexes_of(claw) if supported() else []


## «ave», «mamifero» o «corredora» (el casuario); "" sin datos.
func kind() -> String:
	var b: Variant = MovingCar.body_of(claw) if claw != null else null
	return String(b.kind) if b != null else ""


## Material de las garras (entrada de Data.INLAYS).
func inlay_entry() -> Dictionary:
	var e: Variant = Catalog.find_by_id(Catalog.INLAYS, inlay)
	return e if e != null else Catalog.INLAYS[0]


## El material para el motor (p.inlay): su id si es de Data.INLAYS, o la entrada entera si es uno de la 2.0 (el rubí y la
## alúmina de la reforja), que el motor no puede buscar por su id (MovingCar.inlay_of).
func inlay_param() -> Variant:
	if MovingCar.inlay_of({ "inlay": inlay }) != null:
		return inlay
	return inlay_entry()


## ¿Son garras reforjadas? (false con la queratina)
func reforged() -> bool:
	return inlay != KERATIN


## ¿Pueden quedar clavadas en el panel de esta zona? Como en MovingCar.setup: en un panel pintado (no en el parabrisas);
## en el plástico, siempre; en la chapa, solo unas garras que la cortan (MovingCar.can_cut_body: r ≥ 0,8).
func can_embed() -> bool:
	var z: Variant = MovingCar.ZONES.get(zone)
	return z != null and z.surface == "pintura" and MovingCar.can_cut_body(inlay_entry(), target, claw)


## Un material de las garras en pocas palabras (la ayuda de su botón): dureza del catálogo y cómo se rompe
## (ClawFracture: frágil con su resistencia a flexión, dúctil con su tensión de flujo, o sin datos).
static func inlay_tip(id: String) -> String:
	var e: Variant = Catalog.find_by_id(Catalog.INLAYS, id)
	if e == null:
		return ""
	if id == KERATIN:
		return "Queratina de las garras (la de siempre): %s" % String(ClawsV2.KERATIN_SOURCE.source)
	var txt := "%s · %s HV" % [e.name, num(float(e.hv))]
	var s: Variant = ClawFracture.strength(id)
	if s == null:
		var why := String(ClawFracture.UNKNOWN.get(id, ""))
		return txt + (" · " + why if why != "" else "")
	if s.kind == "flexion":
		return "%s · frágil: aguanta %s MPa a flexión · %s" % [txt, Format.fmt_p(float(s.value)), QUALITY_TEXT.get(String(s.quality), "")]
	return "%s · dúctil: fluye a %s MPa y se dobla · %s" % [txt, Format.fmt_p(float(s.value)), QUALITY_TEXT.get(String(s.quality), "")]


## Qué hacen las garras elegidas contra el panel de este coche: «Queratina, 30 HV: no corta el acero de horno (HC180B),
## de 101 HV» o «Zafiro, 2000 HV: corta el acero de horno (HC180B), de 101 HV; frágil».
func inlay_note() -> String:
	if not supported():
		return ""
	var body: Dictionary = target.body
	var name := "Queratina" if not reforged() else String(inlay_entry().name)
	if film() and not reforged():
		name = "Garra de película (ficción)"
	var cuts := MovingCar.can_cut_body(inlay_entry(), target, claw)
	var txt := "%s, %s HV: %s el %s, de %s HV" % [name, num(_claw_hv()), "corta" if cuts else "no corta", body.long, num(float(body.hv))]
	match ClawFracture.behavior(inlay):
		"fragil":
			txt += "; frágil: puede mellarse o partirse al resbalar"
		"ductil":
			txt += "; dúctil: se dobla antes de romperse" if cuts else ""
		"sin_datos":
			txt += "; sin datos de su rotura"
	return txt


func is_plastic() -> bool:
	return target.get("id") == PLASTIC_CAR


## Zonas en las que puede quedarse el animal (con la aleta de plástico, solo la aleta; el casuario, ninguna).
func zones() -> Array:
	if not supports_hold():
		return []
	return [PLASTIC_ZONE] if is_plastic() else MovingCar.zones_for(claw)


## Zonas del golpe del animal (MovingCar.impact_zones_for: el casuario, solo lo que tiene a la altura de las patas; con la
## aleta de plástico, solo la aleta).
func impact_zones() -> Array:
	var all: Array = MovingCar.impact_zones_for(claw) if supported() else MovingCar.IMPACT_ZONES.keys()
	if is_plastic():
		return [PLASTIC_ZONE] if all.has(PLASTIC_ZONE) else []
	return all


## Posturas del animal quieto encima ([] si no se queda encima: MovingCar.POSTURES no tiene las del casuario).
func postures() -> Array:
	return MovingCar.postures_of(claw) if supports_hold() else []


static func zone_name(id: String) -> String:
	var z: Variant = MovingCar.ZONES.get(id, MovingCar.IMPACT_ZONES.get(id))
	return String(z.name) if z != null else id


static func posture_name(id: String) -> String:
	return String(MovingCar.POSTURE_NAMES.get(id, id))


## Nombres de los animales con datos, en el orden de MovingCar.BODIES: [{ id, name }] (la especie, sin el latín). Uno con
## variantes (el velocirraptor) sale una sola vez, con el id de su variante por defecto (la de película) y su nombre de
## ANIMAL_NAMES: la otra se elige con variants() y set_variant().
static func supported_animals() -> Array:
	var out: Array = []
	for id: String in MovingCar.BODIES:
		if _is_other_variant(id):
			continue
		out.append({ "id": id, "name": String(ANIMAL_NAMES.get(id, species_name(id))) })
	return out


## ¿Es una variante que no es la de por defecto (la reconstrucción del velocirraptor)?
static func _is_other_variant(id: String) -> bool:
	for k: String in VARIANTS:
		if (VARIANTS[k] as Array).has(id) and k != id:
			return true
	return false


## La entrada del selector (supported_animals) de un animal: la de su variante por defecto si tiene variantes.
static func animal_entry_id(id: String) -> String:
	for k: String in VARIANTS:
		if (VARIANTS[k] as Array).has(id):
			return k
	return id


## Las variantes del animal elegido: [{ id, name }] (el de película y la reconstrucción del velocirraptor) o [].
func variants() -> Array:
	if claw == null:
		return []
	var list: Variant = VARIANTS.get(animal_entry_id(String(claw.id)))
	if list == null:
		return []
	return (list as Array).map(func(v: String) -> Dictionary: return { "id": v, "name": String(VARIANT_NAMES.get(v, species_name(v))) })


## Elige otra variante del mismo animal (un id de variants()): como elegir el animal (set_claw).
func set_variant(id: String) -> void:
	if variants().any(func(v: Dictionary) -> bool: return v.id == id):
		set_claw(Catalog.find_by_id(Catalog.CLAWS, id))


## ¿Es el velocirraptor de película (FICCIÓN)?
func film() -> bool:
	return supported() and MovingCar.is_film(claw)


## Nombre de la especie de un animal con datos, sin el latín («Águila real»); "" sin datos.
static func species_name(id: String) -> String:
	var b: Variant = MovingCar.BODIES.get(id)
	if b == null:
		return ""
	var sp: String = b.species
	return sp.substr(0, sp.find(" (")) if sp.contains(" (") else sp


## El animal elegido («Águila real»), o "" sin datos.
func animal_name() -> String:
	return species_name(String(claw.id)) if supported() else ""


func impact_zone_name() -> String:
	return zone_name(impact_zone)


## Maniobra elegida (entrada de MovingCar.MANEUVERS).
func maneuver_entry() -> Dictionary:
	for m: Dictionary in MovingCar.MANEUVERS:
		if m.id == maneuver:
			return m
	return MovingCar.MANEUVERS[0]


## Parámetros de hold_report (y de setup): docs/fisica/coche-en-marcha.md §9.1.
func hold_params() -> Dictionary:
	return {
		"claw": claw, "target": target, "zone": zone, "posture": posture, "wind_kmh": wind_kmh,
		"crosswind_kmh": crosswind_kmh, "accel_g": accel_g, "lateral_g": lateral_g, "temp_c": temp_c,
		"altitude_m": altitude_m, "embedded": embedded, "inlay": inlay_param(), "defense": defense, "model": MODEL, "v_kmh": v_kmh,
		"sharpness": sharpness,
	}


## Parámetros de impact.
func impact_params() -> Dictionary:
	return {
		"claw": claw, "target": target, "zone": impact_zone, "v_kmh": v_kmh, "animal_kmh": animal_kmh,
		"angle_deg": angle_deg, "drop_m": drop_m, "car_mass_kg": car_mass_kg, "temp_c": temp_c,
		"altitude_m": altitude_m, "inlay": inlay_param(), "sex": sex, "defense": defense, "model": MODEL, "sharpness": sharpness,
	}


## ¿El golpe es en un costado (puerta o aleta)? Allí no hay caída.
func impact_side() -> bool:
	var iz: Variant = MovingCar.IMPACT_ZONES.get(impact_zone)
	return iz != null and iz.normal == "lado"


# ════════ Cambios ════════

## Animal (garra del catálogo) o null. Si la zona o la postura no le sirven, pasa a las de por defecto.
func set_claw(c: Variant) -> void:
	if _same_id(c, claw):
		return
	claw = c
	_fit_selection()
	_rebuild()


## Coche (uno de CARS). Con la aleta de plástico, la zona es la aleta. Con un coche más lento que la velocidad puesta
## (del deportivo al turismo), la velocidad baja a su tope.
func set_target(t: Dictionary) -> void:
	if t.get("id") == target.get("id") or not CARS.has(t.get("id")):
		return
	target = t
	v_kmh = minf(v_kmh, slider_max_kmh())
	_fit_selection()
	_rebuild()


## Tope del deslizador de velocidad con el coche elegido (km/h): 230 en el turismo, la velocidad máxima del deportivo.
func slider_max_kmh() -> float:
	return MovingCar.slider_max_kmh(target)


## Modo («hold» o «impact»). Un animal que no se queda encima (el casuario) solo tiene el golpe; el modo elegido se
## recuerda y vuelve al pasar a un animal que sí se queda.
func set_mode(m: String) -> void:
	if not [MODE_HOLD, MODE_IMPACT].has(m) or (m == MODE_HOLD and supported() and not supports_hold()):
		return
	_mode_choice = m
	if m == mode:
		return
	mode = m
	_emit()


## Material de las garras (id de Data.INLAYS; «none», la queratina): cambian las marcas, la punción, el vidrio, lo que
## aguantan clavadas y si se rompen (un setup nuevo; el golpe, en su hilo).
func set_inlay(id: String) -> void:
	if id == inlay or Catalog.find_by_id(Catalog.INLAYS, id) == null:
		return
	inlay = id
	_fit_selection()
	_rebuild()


## Afilado de unas garras reforjadas (0-1; unidad 4i-B2): cambian las marcas, la punción, lo que aguantan clavadas y si se
## mellan (un setup nuevo; el golpe, en su hilo). Con la queratina (o la garra de película) no hace nada: MovingCar solo
## afila unas garras reforjadas, como el banco (Physics.sharpness_of).
func set_sharpness(s: float) -> void:
	s = clampf(s, MovingCar.PARAMS.sharpness.min, MovingCar.PARAMS.sharpness.max)
	if s == sharpness:
		return
	sharpness = s
	_rebuild()


## ¿Se pueden afilar las garras elegidas? Solo unas reforjadas (como en el banco).
func sharpenable() -> bool:
	return supported() and reforged()


## El deslizador «Afilado» con sus dos barras (DinoLab.sharpness_view, el mismo del banco) para las garras elegidas con la
## carga de cada garra quieta encima (MovingCar.sharpness_report), o {} si no se pueden afilar.
func sharpness_view() -> Dictionary:
	if not sharpenable():
		return {}
	var rep: Variant = MovingCar.sharpness_report(hold_params())
	if rep == null:
		return {}
	return DinoLab.sharpness_view(rep, String(ClawFracture.NOUNS.get(inlay, inlay)))


## Animal asustado, en defensa: aprieta con toda su fuerza (un setup nuevo; el golpe, en su hilo).
func set_defense(on: bool) -> void:
	if on == defense:
		return
	defense = on
	_rebuild()


## Sexo del casuario (MovingCar.SEXES): solo cambia el golpe.
func set_sex(s: String) -> void:
	if s == sex or not sexes().has(s):
		return
	sex = s
	_emit()


func set_zone(z: String) -> void:
	if z == zone or not zones().has(z):
		return
	zone = z
	if not can_embed():
		embedded = false  # en el parabrisas no se clavan (MovingCar.setup lo ignora): el interruptor tampoco
	_rebuild()


func set_impact_zone(z: String) -> void:
	if z == impact_zone or not impact_zones().has(z):
		return
	impact_zone = z
	_emit()


func set_posture(p: String) -> void:
	if p == posture or not postures().has(p):
		return
	posture = p
	_rebuild()


## Garras clavadas (tras un golpe que atraviesa el plástico o, con garras que cortan el metal, la chapa): la fricción
## pasa a ser un anclaje.
func set_embedded(v: bool) -> void:
	if v == embedded or (v and not can_embed()):
		return
	embedded = v
	_rebuild()


## Velocidad del coche (km/h): at_speed, lo único que se recalcula en cada fotograma.
func set_speed(v: float) -> void:
	v = clampf(v, MovingCar.PARAMS.v_kmh.min, slider_max_kmh())
	if v == v_kmh:
		return
	v_kmh = v
	_live()
	_emit()


## Viento de frente (+) o de cola (−) y lateral (km/h): un setup nuevo (el viento va en el ensayo).
func set_wind(head_kmh: float, cross_kmh: float) -> void:
	head_kmh = clampf(head_kmh, MovingCar.PARAMS.wind_kmh.min, MovingCar.PARAMS.wind_kmh.max)
	cross_kmh = clampf(cross_kmh, MovingCar.PARAMS.crosswind_kmh.min, MovingCar.PARAMS.crosswind_kmh.max)
	if head_kmh == wind_kmh and cross_kmh == crosswind_kmh:
		return
	wind_kmh = head_kmh
	crosswind_kmh = cross_kmh
	_rebuild()


## Maniobra de MovingCar.MANEUVERS: pone su aceleración y su curva (un setup nuevo).
func set_maneuver(id: String) -> void:
	var m: Variant = null
	for e: Dictionary in MovingCar.MANEUVERS:
		if e.id == id:
			m = e
	if m == null or (id == maneuver and accel_g == float(m.accel_g) and lateral_g == float(m.lateral_g)):
		return
	maneuver = id
	accel_g = m.accel_g
	lateral_g = m.lateral_g
	if lateral_g != 0.0:
		road = CarCurve.ROAD_STRAIGHT  # unidad 4t: la maniobra con curva y la carretera en curva no se suman
	_rebuild()


## Temperatura (°C) y altitud (m) del aire: with_air sobre el ensayo y la gráfica con esa copia, sin compute().
func set_air(t_c: float, alt_m: float) -> void:
	t_c = clampf(t_c, MovingCar.PARAMS.temp_c.min, MovingCar.PARAMS.temp_c.max)
	alt_m = clampf(alt_m, MovingCar.PARAMS.altitude_m.min, MovingCar.PARAMS.altitude_m.max)
	if t_c == temp_c and alt_m == altitude_m:
		return
	temp_c = t_c
	altitude_m = alt_m
	if _base.is_empty() or not Js.truthy(_base.get("ok")):
		_rebuild()
		return
	var t0 := Time.get_ticks_usec()
	scen = MovingCar.with_air(_base, temp_c, altitude_m)
	_derive()
	last_setup_us = Time.get_ticks_usec() - t0
	_emit()


## Datos del golpe: animal_kmh, angle_deg, drop_m o car_mass_kg (MovingCar.PARAMS). Solo cambian impact().
func set_impact(key: String, value: float) -> void:
	if not ["animal_kmh", "angle_deg", "drop_m", "car_mass_kg"].has(key):
		return
	var r: Dictionary = MovingCar.PARAMS[key]
	value = clampf(value, r.min, r.max)
	if value == float(get(key)):
		return
	set(key, value)
	_emit()


## Empieza o termina el arrastre de un deslizador: al soltarlo, lo caro se lanza en el siguiente step().
func set_dragging(on: bool) -> void:
	dragging = on


# ════════ Experimentos de un clic ════════

## Entrada de EXPERIMENTS ({} si no existe).
static func experiment(id: String) -> Dictionary:
	for e: Dictionary in EXPERIMENTS:
		if e.id == id:
			return e
	return {}


## Qué carga un experimento, en pocas palabras (la ayuda de su botón): «Águila real · encima del coche · techo · alas
## plegadas · 120 km/h · velocidad constante».
static func experiment_tip(id: String) -> String:
	var e := experiment(id)
	if e.is_empty():
		return ""
	if e.has("air"):
		return "El mismo ensayo con el aire a %s °C y %s m (pulsa otra vez para volver a 20 °C al nivel del mar)" % [
			num(float(e.air[0])), num(float(e.air[1]))]
	var parts: Array = [species_name(String(e.claw))]
	var t: Variant = Catalog.find_by_id(Catalog.TARGETS, String(e.get("car", CARS[0])))
	if t != null:
		parts.append(String(t.name).to_lower())
	parts.append(String(MODES[0].name if e.mode == MODE_HOLD else MODES[1].name).to_lower())
	if e.mode == MODE_HOLD:
		parts.append(zone_name(String(e.zone)).to_lower())
		parts.append(posture_name(String(e.posture)).to_lower())
	else:
		parts.append(zone_name(String(e.impact_zone)).to_lower())
	if e.has("sex"):
		parts.append(String(MovingCar.SEX_NAMES.get(String(e.sex), e.sex)).to_lower())
	parts.append("coche a %s" % fmt_kmh(float(e.get("v_kmh", MovingCar.PARAMS.v_kmh.default))))
	if e.mode == MODE_IMPACT:
		parts.append("animal a %s" % fmt_kmh(float(e.get("animal_kmh", MovingCar.PARAMS.animal_kmh.default))))
	else:
		parts.append(String(_maneuver(String(e.get("maneuver", DEFAULT_MANEUVER))).get("name", "")).to_lower())
	if e.has("inlay"):
		parts.append("garras de %s" % String(ClawFracture.NOUNS.get(String(e.inlay), e.inlay)))
	if bool(e.get("embedded", false)):
		parts.append("clavadas en la chapa")
	if bool(e.get("defense", false)):
		parts.append("asustad%s" % String(GRAMMAR.get(String(e.claw), ["el", "o"])[1]))
	return " · ".join(PackedStringArray(parts))


## ¿Se enseña en este modo? «aire» solo con el animal encima: en el golpe, el aire no cambia nada de lo que se ve.
func experiment_shown(id: String) -> bool:
	var e := experiment(id)
	return not e.is_empty() and (not e.has("air") or mode == MODE_HOLD)


## Carga un experimento de una vez (un solo setup): el animal y el coche del catálogo, el modo, la zona, la postura, la
## maniobra, las velocidades, el material de las garras, si están clavadas, si está asustado y el sexo; sin viento y con
## el aire de referencia. «aire» solo cambia el aire (y, si ya lo tenía, vuelve al de referencia). La tarjeta cambia
## también el animal del banco. false si no existe.
func load_experiment(id: String) -> bool:
	var e := experiment(id)
	if e.is_empty():
		return false
	if e.has("air"):
		var on := experiment_matches(id)
		set_air(float(MovingCar.PARAMS.temp_c.default) if on else float(e.air[0]),
			float(MovingCar.PARAMS.altitude_m.default) if on else float(e.air[1]))
		return true
	claw = Catalog.find_by_id(Catalog.CLAWS, e.claw)
	target = Catalog.find_by_id(Catalog.TARGETS, String(e.get("car", CARS[0])))
	mode = String(e.mode)
	_mode_choice = mode
	zone = String(e.get("zone", DEFAULT_ZONE))
	impact_zone = String(e.get("impact_zone", DEFAULT_ZONE))
	posture = String(e.get("posture", ""))
	inlay = String(e.get("inlay", KERATIN))
	sharpness = float(e.get("sharpness", 0.0))
	defense = bool(e.get("defense", false))
	embedded = bool(e.get("embedded", false))
	sex = String(e.get("sex", MovingCar.SEXES[0]))
	var man_id := String(e.get("maneuver", DEFAULT_MANEUVER))
	for m: Dictionary in MovingCar.MANEUVERS:
		if m.id == man_id:
			maneuver = man_id
			accel_g = m.accel_g
			lateral_g = m.lateral_g
	for k: String in _EXPERIMENT_KEYS:
		set(k, float(e.get(k, MovingCar.PARAMS[k].default)))
	temp_c = MovingCar.PARAMS.temp_c.default
	altitude_m = MovingCar.PARAMS.altitude_m.default
	road = CarCurve.ROAD_STRAIGHT  # unidad 4t: los experimentos van en recta
	_fit_selection()
	_rebuild()
	return true


## ¿Lo que se ve es ese experimento? (el aire no cuenta: «aire» se suma a cualquiera; «aire» mira solo el aire)
func experiment_matches(id: String) -> bool:
	var e := experiment(id)
	if e.is_empty():
		return false
	if e.has("air"):
		return temp_c == float(e.air[0]) and altitude_m == float(e.air[1])
	if not supported() or claw.id != e.claw or target.id != String(e.get("car", CARS[0])) or mode != e.mode:
		return false
	if inlay != String(e.get("inlay", KERATIN)) or defense != bool(e.get("defense", false)):
		return false
	if mode == MODE_HOLD and curve_on():
		return false  # unidad 4t: los experimentos van en recta
	# el afilado solo cuenta con unas garras reforjadas (con la queratina, MovingCar no lo usa)
	if (sharpness if reforged() else 0.0) != float(e.get("sharpness", 0.0)):
		return false
	var keys: Array = _EXPERIMENT_KEYS_HOLD if mode == MODE_HOLD else _EXPERIMENT_KEYS_IMPACT
	if mode == MODE_HOLD:
		if zone != e.zone or posture != e.posture or maneuver != String(e.get("maneuver", DEFAULT_MANEUVER)):
			return false
		if embedded != bool(e.get("embedded", false)):
			return false
	elif impact_zone != e.impact_zone or (not sexes().is_empty() and sex != String(e.get("sex", MovingCar.SEXES[0]))):
		return false
	for k: String in keys:
		if float(get(k)) != float(e.get(k, MovingCar.PARAMS[k].default)):
			return false
	return true


# ════════ Cálculo ════════

## Modo, zona, zona del golpe, postura, garras clavadas y sexo válidos para el animal, el coche y las garras elegidos.
func _fit_selection() -> void:
	if not supported():
		return
	mode = _mode_choice if supports_hold() else MODE_IMPACT
	var zs := zones()
	if not zs.is_empty() and not zs.has(zone):
		zone = PLASTIC_ZONE if is_plastic() else DEFAULT_ZONE
	var izs := impact_zones()
	if not izs.is_empty() and not izs.has(impact_zone):
		impact_zone = DEFAULT_ZONE if izs.has(DEFAULT_ZONE) else ("puerta" if izs.has("puerta") else String(izs[0]))
	var ps := postures()
	if not ps.is_empty() and not ps.has(posture):
		posture = ps[0]
	if not can_embed():
		embedded = false
	var sx := sexes()
	if not sx.is_empty() and not sx.has(sex):
		sex = sx[0]


## setup (lo del animal, el coche, la zona, la postura, el viento, la maniobra, las garras y el miedo) y lo que sale de
## él; asustado, también el mismo setup sin asustarse (para comparar el despegue).
func _rebuild() -> void:
	var t0 := Time.get_ticks_usec()
	if not supported():
		# sin datos: MovingCar lo dice sin calcular nada ({ ok: false, reason })
		_base = MovingCar.setup(hold_params()) if claw != null else {}
		_base_rest = {}
		scen = _base
		chart = {}
		det = {}
		verdict = {}
		at = {}
		at_detach = {}
		det_rest = {}
		air_txt = ""
	else:
		_base = MovingCar.setup(hold_params())
		_base_rest = {}
		if defense and Js.truthy(_base.get("ok")):
			var rest := hold_params()
			rest.defense = false
			_base_rest = MovingCar.setup(rest)
		scen = _base
		_derive()
	last_setup_us = Time.get_ticks_usec() - t0
	_emit()


func _derive() -> void:
	setup_version += 1
	if _marks_key != _marks_trial_key():
		marks_chart = {}  # de otro ensayo: no se enseña mientras llega la suya
	if not Js.truthy(scen.get("ok")):
		chart = {}
		det = {}
		verdict = {}
		at = {}
		at_detach = {}
		det_rest = {}
		air_txt = ""
		return
	curve_sides = {}
	if curve_on():
		_curve_derive()  # unidad 4t: en curva, el despegue y la gráfica con la aceleración lateral de cada velocidad
	else:
		chart = MovingCar.curve(scen)
		det = chart.detach
		verdict = MovingCar.detach_verdict(scen, det)
		_glass_verdict()  # unidad 4v
	air_txt = MovingCar.air_txt(scen.air)
	at_detach = {}
	if window_in_slider():
		at_detach = _at_speed(float(det.holdFromKmh))
	elif not det.atRest:
		at_detach = _at_speed(0.0)
	elif not det.never:
		at_detach = _at_speed(det.kmh)
	det_rest = {}
	if Js.truthy(_base_rest.get("ok")):
		var rest := MovingCar.with_air(_base_rest, temp_c, altitude_m)
		det_rest = CarCurve.detach(rest, radius_m, curve_grip(), curve_side()) if curve_on() else MovingCar.detach(rest)
	_live()


func _live() -> void:
	if scen.is_empty() or not Js.truthy(scen.get("ok")):
		return
	var t0 := Time.get_ticks_usec()
	at = _at_speed(v_kmh)
	last_live_us = Time.get_ticks_usec() - t0
	live_version += 1


func _emit() -> void:
	# un golpe de otro ensayo (otro animal, coche, zona, material de las garras, miedo o sexo) no se enseña mientras llega
	# el suyo: sus textos mezclarían dos animales. Uno del mismo ensayo con otros deslizadores, sí (heavy_fresh()).
	if not hit.is_empty() and not _same_trial(_hit_key, _impact_key()):
		hit = {}
		_hit_key = []
	changed.emit()


## Clave de lo caro del modo actual (los parámetros de los que depende; [] sin datos).
func _key() -> Array:
	return _hold_key() if mode == MODE_HOLD else _impact_key()


## Parámetros de hold_report; la velocidad, la última (el ensayo sin ella es el del setup).
func _hold_key() -> Array:
	if not supports_hold():
		return []
	return [MODE_HOLD, claw.id, target.id, zone, posture, wind_kmh, crosswind_kmh, accel_g, lateral_g, temp_c, altitude_m,
		embedded, inlay, defense, sharpness, v_kmh]


func _impact_key() -> Array:
	if not supported():
		return []
	return [MODE_IMPACT, claw.id, target.id, impact_zone, inlay, defense, sex, v_kmh, animal_kmh, angle_deg, drop_m,
		car_mass_kg, temp_c, altitude_m, sharpness]


## ¿El informe del animal quieto encima es del ensayo que se ve (aunque sea de otra velocidad del deslizador)?
func report_matches_setup() -> bool:
	var key := _hold_key()
	return not key.is_empty() and _report_key.size() == key.size() and _report_key.slice(0, -1) == key.slice(0, -1)


## ¿El informe del animal quieto encima (hold) o el golpe (impact) corresponde a lo que se ve ahora?
func heavy_fresh() -> bool:
	var key := _key()
	return not key.is_empty() and key == (_report_key if mode == MODE_HOLD else _hit_key)


## ¿Falta lanzar lo caro del modo actual? (no está al día ni en marcha)
func heavy_pending() -> bool:
	var key := _key()
	if key.is_empty() or heavy_fresh():
		return false
	for t: Dictionary in _tasks:
		if t.key == key:
			return false
	return true


## Avanza el reloj ms milisegundos: recoge lo caro que ha llegado de los hilos y lanza lo que falte (al soltar el
## deslizador; en el golpe, también mientras se arrastra, como mucho cada DRAG_HEAVY_MS). true si ha llegado algo.
func step(ms: float) -> bool:
	_clock += ms
	var fresh := poll()
	if _tasks.is_empty() and heavy_pending():
		if not dragging or (mode == MODE_IMPACT and _clock - _last_launch >= DRAG_HEAVY_MS):
			fresh = _launch() or fresh
	return fresh


## Recoge las tareas terminadas, en el orden en que se lanzaron. true si ha llegado un resultado de ahora.
func poll() -> bool:
	var fresh := false
	while not _tasks.is_empty() and WorkerThreadPool.is_group_task_completed(_tasks[0].task):
		fresh = _collect(_tasks.pop_front()) or fresh
	return fresh


## Espera lo caro: lanza lo que falte y espera a que acabe. true si ha llegado algo.
func finish() -> bool:
	var fresh := false
	while not _tasks.is_empty():
		fresh = _collect(_tasks.pop_front()) or fresh
	if heavy_pending():
		fresh = _launch() or fresh
		while not _tasks.is_empty():
			fresh = _collect(_tasks.pop_front()) or fresh
	return fresh


## Espera y descarta las tareas en marcha (al cerrar la tarjeta; también al liberarse el estado).
func dispose() -> void:
	for t: Dictionary in _tasks:
		WorkerThreadPool.wait_for_group_task_completion(t.task)
	_tasks.clear()


## Lanza lo caro del modo actual: en un hilo de WorkerThreadPool (prioridad alta) o, sin hilos, en el acto (y entonces
## devuelve true: ya ha llegado). La tarea solo toca sus propios parámetros (un diccionario nuevo) y su hueco de salida:
## nada del estado.
func _launch() -> bool:
	var key := _key()
	var hold := mode == MODE_HOLD
	var p := hold_params() if hold else impact_params()
	# [resultado, µs, la curva del daño frente a la velocidad (unidad 4s) o null]
	var out := [null, 0, null]
	_last_launch = _clock
	# unidad 4s: la gráfica del daño frente a la velocidad va con el informe del animal quieto encima, una vez por ensayo
	# (si solo ha cambiado la velocidad, la que ya hay vale); aparte del informe, que sigue siendo el de hold_report
	var want_marks: bool = hold and _marks_key != key.slice(0, -1)
	var top := top_kmh()
	if not threaded:
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = MovingCar.hold_report(p) if hold else MovingCar.impact(p)
		var mc: Variant = CarSpeedMarks.curve_for(p, top) if want_marks else null
		_apply(MODE_HOLD if hold else MODE_IMPACT, key, r, Time.get_ticks_usec() - t0, mc)
		return true
	var job := func(_i: int) -> void:
		var t0 := Time.get_ticks_usec()
		out[0] = MovingCar.hold_report(p) if hold else MovingCar.impact(p)
		if want_marks:
			out[2] = CarSpeedMarks.curve_for(p, top)
		out[1] = Time.get_ticks_usec() - t0
	var task := WorkerThreadPool.add_group_task(job, 1, -1, true, "coche en marcha")
	_tasks.append({ "task": task, "kind": MODE_HOLD if hold else MODE_IMPACT, "key": key, "out": out })
	return false


## Recoge una tarea. Si llega de otro ensayo (otro modo, animal, coche, zona, postura o maniobra) se descarta; si solo
## han cambiado los deslizadores (la velocidad, el aire, el viento o los datos del golpe) se enseña mientras llega la
## buena: es lo que da «unas pocas veces por segundo» al arrastrar, porque cada resultado llega cuando el deslizador ya
## se ha movido. heavy_fresh() dice si ya es la buena (su clave es la de sus propios parámetros).
func _collect(t: Dictionary) -> bool:
	WorkerThreadPool.wait_for_group_task_completion(t.task)
	var key := _key()
	if t.key != key and not _same_trial(t.key, key):
		return false
	_apply(t.kind, t.key, t.out[0], int(t.out[1]), t.out[2])
	return true


## Posiciones de la clave que no son deslizadores (hold: modo, animal, coche, zona, postura, aceleración, curva, garras
## clavadas, material de las garras y defensa; impact: modo, animal, coche, zona, material, defensa y sexo).
const _TRIAL_KEYS := { MODE_HOLD: [0, 1, 2, 3, 4, 7, 8, 11, 12, 13], MODE_IMPACT: [0, 1, 2, 3, 4, 5, 6] }


static func _same_trial(a: Array, b: Array) -> bool:
	if a.is_empty() or a.size() != b.size() or a[0] != b[0]:
		return false
	for i: int in _TRIAL_KEYS[a[0]]:
		if a[i] != b[i]:
			return false
	return true


func _apply(kind_id: String, key: Array, r: Dictionary, us: int, marks_curve_in: Variant = null) -> void:
	if kind_id == MODE_HOLD:
		report = r
		_report_key = key
		if marks_curve_in is Dictionary:
			marks_chart = marks_curve_in
			_marks_key = key.slice(0, -1)
			_glass_verdict()  # unidad 4v: la luneta que estalla a una velocidad
	else:
		hit = r
		_hit_key = key
		hit_version += 1
	last_heavy_us = us
	heavy_version += 1
	_emit()


static func _same_id(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == null and b == null
	return a.get("id") == b.get("id")


# ════════ Formatos (viven en core/lab/car_format.gd; estos nombres delegan allí) ════════

## Fuerza legible: N hasta 10 kN y kN con un decimal después; con su signo (CarFormat.fmt_n).
static func fmt_n(n: float) -> String:
	return CarFormat.fmt_n(n)


## Velocidad en km/h sin decimales; «∞» si no hay (CarFormat.fmt_kmh).
static func fmt_kmh(v: float) -> String:
	return CarFormat.fmt_kmh(v)


## Potencia: W hasta 1 kW y kW con un decimal después; con su signo (CarFormat.fmt_w).
static func fmt_w(w: float) -> String:
	return CarFormat.fmt_w(w)


## Proporción (0-1) en tanto por ciento sin decimales (CarFormat.fmt_pct).
static func fmt_pct(x: float) -> String:
	return CarFormat.fmt_pct(x)


## Aceleración en g con dos decimales (CarFormat.fmt_g).
static func fmt_g(g: float) -> String:
	return CarFormat.fmt_g(g)


## Número de un dato de MovingCar tal cual (CarFormat.num: String(n) de JavaScript).
static func num(v: float) -> String:
	return CarFormat.num(v)


## Banda de un dato { value, min, max }: «0.4 (0.24…0.6)» (CarFormat.fmt_band).
static func fmt_band(b: Dictionary, unit := "") -> String:
	return CarFormat.fmt_band(b, unit)


## Banda de dos fuerzas: «de 2.8 N a 17.6 N» (CarFormat.fmt_n_band).
static func fmt_n_band(lo: float, hi: float) -> String:
	return CarFormat.fmt_n_band(lo, hi)


## «a la chapa» · «al plástico» (body.noun de la carrocería).
static func _to(noun: String) -> String:
	return ("al " + noun.substr(3)) if noun.begins_with("el ") else ("a " + noun)


# ════════ Textos del animal quieto encima ════════

## La banda de la velocidad de despegue: { lo, hi, central, text, lo_txt, hi_txt }. lo: con todos los datos en contra;
## hi: con todos a favor (MovingCar.detach: minKmh y maxKmh). Siempre se enseña con el valor central. Con dos
## velocidades, «de 51 km/h (todo en contra) a 333 km/h (todo a favor)»; si un extremo no es una velocidad (ni parado se
## sostiene, o no se suelta en toda la búsqueda), con frases: «con todo en contra, ni parado se sostiene; con todo a
## favor, no se suelta ni a 400 km/h».
func band() -> Dictionary:
	if det.is_empty():
		return {}
	var lo: float = det.minKmh
	var hi: float = det.maxKmh
	var lo_txt := "ni parado" if lo <= 0.0 else fmt_kmh(lo)
	var hi_txt := "no se suelta ni a %s" % fmt_kmh(BAND_MAX_KMH) if is_inf(hi) else fmt_kmh(hi)
	if hi <= 0.0:
		hi_txt = "ni parado"
	var central := det_words(det, kind() == "ave")
	var text := "Banda de los datos: de %s (todo en contra) a %s (todo a favor)" % [lo_txt, hi_txt]
	if lo <= 0.0 or hi <= 0.0 or is_inf(hi):
		text = "Banda de los datos: con todo en contra, %s; con todo a favor, %s" % [_band_end(lo), _band_end(hi)]
	return { "lo": lo, "hi": hi, "central": central, "lo_txt": lo_txt, "hi_txt": hi_txt, "text": text }


## Un extremo de la banda en una frase: «ni parado se sostiene», «se suelta a 200 km/h», «no se suelta ni a 400 km/h».
static func _band_end(kmh: float) -> String:
	if kmh <= 0.0:
		return "ni parado se sostiene"
	if is_inf(kmh):
		return "no se suelta ni a %s" % fmt_kmh(BAND_MAX_KMH)
	return "se suelta a %s" % fmt_kmh(kmh)


## Color del veredicto (paleta): menta si aguanta en todo el deslizador, oro si el ave despega (vuela), coral si se
## suelta o ni parado se sostiene.
func verdict_color() -> String:
	if det.is_empty():
		return "dim"
	if String(verdict.get("verdict", "")).contains("ESTALLA LA LUNETA"):
		return "coral"  # unidad 4v
	if det.atRest and (det.never or det.beyond):
		return "mint"
	if det.atRest and det.mode == "despega" and kind() == "ave":
		return "gold"
	return "coral"


## El estado a la velocidad del deslizador: «A 90 km/h: aguanta» o «A 90 km/h: sale despedido hacia atrás».
func now_text() -> String:
	if at.is_empty():
		return ""
	var head := "A %s" % fmt_kmh(at.vKmh)
	if at.holds:
		return "%s: aguanta (carga %s)" % [head, fmt_pct(at.loadRatio)]
	if at.mode == "despega" and kind() == "ave":
		return "%s: despega, las alas ya %s sostienen" % [head, _pro()]
	return "%s: no aguanta, %s" % [head, exit_text(String(at.mode))]


## Por dónde se va, con la terminación del animal: «sale despedida hacia atrás» (el águila).
func exit_text(m: String) -> String:
	var t := String(EXIT_TEXT.get(m, m))
	return t % _grammar()[1] if t.contains("%s") else t


## Color del estado a esta velocidad, como el del veredicto: menta si aguanta, oro si el ave despega (vuela), coral si
## se suelta.
func now_color() -> String:
	if at.is_empty():
		return "dim"
	if at.holds:
		return "mint"
	if at.mode == "despega" and kind() == "ave":
		return "gold"
	return "coral"


## Despegue con el aire de referencia para la gráfica (km/h): INF si el aire elegido es el de referencia o si aún no ha
## llegado.
func ref_kmh() -> float:
	var ref: Variant = ref_detach()
	if not custom_air() or ref == null or not ref.atRest:
		return INF
	return float(ref.kmh)


## Leyenda del aire bajo la gráfica: airTxt y, con otro aire, el despegue con el de referencia.
func air_legend() -> String:
	var ref := ref_text()
	return "Aire: %s%s" % [air_txt, (" · con el de referencia, %s" % ref) if custom_air() and ref != "" else ""]


## La banda de las fuerzas a esa velocidad: con todos los datos en contra y con todos a favor.
func now_band_text() -> String:
	if at.is_empty():
		return ""
	# un ave que despega no se suelta: vuela (su veredicto lo dice así)
	var fails := "despega" if kind() == "ave" and String(at.get("mode", "")) == "despega" else "se suelta"
	var lo := "aguanta" if at.holdsLo else fails
	var hi := "aguanta" if at.holdsHi else fails
	if lo == hi:
		return "Con todos los datos, en contra o a favor, %s" % lo  # unidad 4o: sin repetir la misma palabra
	return "Con todos los datos en contra %s; con todos a favor %s" % [lo, hi]


## Lecturas en directo del animal quieto encima (at_speed a la velocidad del deslizador), con su formato, su calidad y
## su fuente: [{ id, label, value, sub, quality, source }].
func hold_readings() -> Array:
	if at.is_empty():
		return []
	var aero := _aero_info()
	var zq: Dictionary = MovingCar.ZONES[zone].cp
	var man := maneuver_entry()
	var out: Array = []
	out.append(_reading("aire", "Aire en el animal", fmt_kmh(at.localKmh),
		"aire relativo %s · q = %s Pa" % [fmt_kmh(at.airKmh), Js.to_fixed(at.qPa, 0)], zq.quality,
		"Cp de la zona %s: %s" % [zone_name(zone).to_lower(), zq.source]))
	out.append(_reading("resistencia", "Resistencia (D)", fmt_n(at.dragN), "q·Cd·A, horizontal", aero.quality, aero.source))
	out.append(_reading("sustentacion", "Sustentación (L)", fmt_n(at.liftN), "q·CL·S, vertical", aero.lift_quality, aero.lift_source))
	var ms := _mass_source()
	out.append(_reading("peso", "Peso (m·g)", fmt_n(at.weightN), "%s kg" % num(float(scen.mass)), ms.quality, ms.source))
	# a velocidad constante la inercia es cero, sin nada que medir ni estimar: sin etiqueta de calidad
	var steady := accel_g == 0.0 and lateral_g == 0.0
	out.append(_reading("inercia", "Inercia de la maniobra (m·a)", fmt_n(at.inertiaN),
		"%s: %s" % [String(man.name).to_lower(), fmt_g(accel_g)], "" if steady else man.quality, "" if steady else man.source))
	if curve_on():
		out.append_array(_curve_readings())  # unidad 4t
	if lateral_g > 0.0 or crosswind_kmh > 0.0:
		out.append(_reading("lateral", "Hacia el costado (m·a lateral)", fmt_n(at.lateralN),
			"curva de %s%s" % [fmt_g(lateral_g), (" y viento lateral de %s" % fmt_kmh(crosswind_kmh)) if crosswind_kmh > 0.0 else ""],
			man.quality, man.source))
	out.append(_reading("normal", "Normal contra el panel (R)", fmt_n(at.normalN),
		"la sustentación le quita el apoyo" if float(at.normalN) < 0.0 else "peso y viento contra el panel", "", ""))
	out.append(_reading("necesaria", "Fuerza necesaria", fmt_n(at.needN), _band_n_txt(at.needMinN, at.needMaxN), aero.quality, aero.source))
	out.append(_reading("disponible", "Fuerza disponible (μ·R + anclaje)", fmt_n(at.availN), _band_n_txt(at.availMinN, at.availMaxN),
		MovingCar.FRICTION.quality, MovingCar.FRICTION.source))
	out.append(_reading("margen", "Margen", fmt_n(at.marginN), "disponible menos necesaria", "", ""))
	out.append(_reading("carga", "Carga", fmt_pct(at.loadRatio), "necesaria / disponible: 100 % = a punto de soltarse", "", ""))
	out.append(_reading("potencia", "Potencia que roba al motor", fmt_w(at.powerW), "D·v", aero.quality, aero.source))
	# unidad 4o: sin aire (el coche parado y sin viento) no hay resistencia con la que comparar: no «0 % de los 0.0 N»
	var no_air: bool = float(at.carDragN) <= 0.0
	out.append(_reading("reparto", "Frente al coche entero", "sin aire" if no_air else fmt_pct(at.dragShare),
		"el coche tampoco tiene resistencia que comparar" if no_air else "de los %s de resistencia del coche" % fmt_n(at.carDragN), MovingCar.CAR_REF.quality,
		"coche de referencia: DrivAer fastback, Cd %s con %s m² a escala real. %s" % [
			num(MovingCar.CAR_REF.cd), num(MovingCar.CAR_REF.area_m2), MovingCar.CAR_REF.source]))
	# unidad 4d: asustado (la fuerza con su banda, el arado de más y el anclaje frente al de reposo) y garras reforjadas
	# clavadas (lo que aguantan de lado)
	var dfn: Variant = scen.get("defense")
	if dfn != null:
		out.append(_defense_reading(dfn))
		var rake: Variant = dfn.get("rakeN")
		if rake != null:
			out.append(_reading("arado", "Arado de más de sus garras", fmt_n(rake.value), "banda %s%s" % [
				fmt_n_band(rake.min, rake.max), " · con más, sus garras cederían" if Js.truthy(rake.get("limited")) else ""],
				String(rake.quality), String(rake.source)))
		elif float(dfn.anchorN.value) != float(dfn.restAnchorN.value):
			out.append(_reading("anclaje", "Anclaje asustado", fmt_n(dfn.anchorN.value), "sin asustarse, %s · banda %s" % [
				fmt_n(dfn.restAnchorN.value), fmt_n_band(dfn.anchorN.min, dfn.anchorN.max)], String(dfn.quality), String(dfn.source)))
	var hold_n: Variant = scen.get("clawHoldN")
	if hold_n != null:
		# unidad 4p: el menor de la flexión, el cortante de la garra y la chapa alrededor del agujero, y cuál manda
		out.append(_reading("clavadas", "Garras clavadas: aguantan de lado", fmt_n(hold_n.value), "%s · %s · banda %s (lo peor: la punta recién asomada)" % [
			"hundidas hasta la base" if Js.truthy(hold_n.get("atBase")) else "clavadas ~%s" % Format.fmt_len(float(hold_n.depthMm) * 1000.0),
			MovingCar.claws_hold_txt(hold_n), fmt_n_band(hold_n.min, hold_n.max)], String(hold_n.quality), String(hold_n.source)))
	out.append_array(marks_readings())  # unidad 4s
	out.append_array(glass_readings())  # unidad 4v
	return out


## La fuerza de defensa (quieto encima o en el golpe), con su banda y la presión en la punta.
func _defense_reading(d: Dictionary) -> Dictionary:
	var f: Dictionary = d.forceN
	return _reading("defensa", "Fuerza de defensa", fmt_n(f.value), "por %s · banda %s · ~%s MPa en la punta%s" % [
		String(d.per), fmt_n_band(f.min, f.max), Format.fmt_p(float(d.tipPressureMPa)),
		" (la punta se aplasta)" if Js.truthy(d.get("tipYields")) else ""], String(d.get("quality", "")), String(d.get("source", "")))


func _reading(id: String, label: String, value: String, sub: String, quality: String, source: String) -> Dictionary:
	return { "id": id, "label": label, "value": value, "sub": sub, "quality": quality, "source": source }


## «banda de 5.0 N a 31 N» o, si los dos extremos se escriben igual (parado no hay aire que cambie, o ninguno sujeta nada),
## «igual con todos los datos» en vez de «banda de 2648 N a 2648 N» (unidad 4o).
static func _band_n_txt(lo: float, hi: float) -> String:
	if fmt_n(lo) == fmt_n(hi):
		return "igual con todos los datos"
	return "banda %s" % fmt_n_band(lo, hi)


## Calidad y fuente de la aerodinámica del animal elegido (la peor de sus datos: una estimación manda).
func _aero_info() -> Dictionary:
	var body: Dictionary = MovingCar.body_of(claw)
	if body.kind == "mamifero":
		return {
			"quality": body.quality, "source": "%s: %s" % [body.species, body.source],
			"lift_quality": body.quality, "lift_source": "%s: %s" % [body.species, body.source],
		}
	var a: Dictionary = MovingCar.BIRD_AERO
	var q := _worst([a.frontal_quality, a.crouch.quality, a.cd_body.quality])
	var lq: String = a.cl_body.quality
	var lsrc: String = a.source
	if body.has("frontal"):
		# los velocirraptores: el cuerpo de un ave con su masa, extrapolado (MovingCar.THEROPOD_FRONTAL, unidad 4i-B2)
		q = _worst([q, body.frontal.quality])
		return { "quality": q, "source": "%s; %s" % [body.frontal.source, a.source], "lift_quality": _worst([lq, body.frontal.quality]), "lift_source": lsrc }
	if posture == "abiertas":
		# con el aire por detrás (viento de cola más fuerte que la velocidad del coche), el ala sustenta al revés: su CL es
		# el de un perfil al revés, una estimación (MovingCar.BIRD_AERO, unidad 4g)
		var w: Dictionary = a.wing.sustenta
		var behind: bool = not at.is_empty() and float(at.vKmh) + wind_kmh < 0.0
		lq = _worst([w.cl_rev_quality if behind else w.quality, body.wing_m2.quality])
		lsrc = "ala: %s; superficie alar: %s" % [w.cl_rev_source if behind else a.source, body.wing_m2.source]
	return { "quality": q, "source": a.source, "lift_quality": lq, "lift_source": lsrc }


static func _worst(list: Array) -> String:
	var w := ""
	for q: Variant in list:
		if int(QUALITY_RANK.get(String(q), 0)) > int(QUALITY_RANK.get(w, 0)):
			w = String(q)
	return w


## Informe del animal quieto encima: pares [etiqueta, valor] (marcas, capas, perforación, parabrisas, frenada máxima y
## el aire), con los datos de setup y de hold_report (este llega de un hilo; mientras no llega, sin la frenada).
func hold_rows() -> Array:
	if scen.is_empty() or not Js.truthy(scen.get("ok")):
		return []
	var out: Array = []
	var shp: Variant = scen.get("sharpness")
	if shp != null:
		out.append(["Punta afilada", MovingCar.sharp_tip_txt(shp)])
	var s: Dictionary = scen.scratch
	var body: Dictionary = target.body
	var cut: int = (s.layers as Array).size()
	var all: int = (Catalog.car_layers(target) as Array).size()
	if float(s.depthUm) > 0.0:
		out.append(["Marcas (resbalando con su peso)", _hold_depth_txt(s)])
		if cut > 0:
			var reach := (" · llega %s sin cortarla" % _to(String(body.noun))) if s.reachesBody and cut < all else ""
			out.append(["Capas que raya", " · ".join(PackedStringArray(s.layers)) + reach])
	else:
		out.append(["Marcas (resbalando con su peso)", glass_trace_txt(s) if on_glass() else "no raya: %s" % String(s.verdict).to_lower()])
	var dfn: Variant = scen.get("defense")
	if dfn != null:
		var tear: Dictionary = dfn.tear
		var tear_txt := String(tear.verdict).to_lower()
		if float(tear.depthUm) > 0.0:
			tear_txt = _hold_depth_txt(tear, false)
			if (tear.layers as Array).size() > 0:
				tear_txt += " · " + " · ".join(PackedStringArray(tear.layers))
		out.append(["Desgarros (asustad%s)" % _grammar()[1], tear_txt])
		out.append(["Defensa", "%s: %s" % [String(dfn.verdict).to_lower(), dfn.vsub]])
	var cl := _claws()
	var hv := num(_claw_hv())
	if on_glass():
		# unidad 4v: rayar el vidrio pide una punta al menos 1,25 veces más dura (CarGlass.R_SCRATCH)
		var glass_hv := float(Catalog.find_by_id(Catalog.TARGETS, "vidrio").hv)
		var scratches := CarGlass.scratches(_claw_hv(), glass_hv)
		out.append(["Perforación", "no: %s, de %s HV, %s el vidrio, de %s HV" % [cl.txt, hv,
			(_v(cl.pl, "puede rayar", "pueden rayar")) if scratches else ("no " + _v(cl.pl, "raya", "rayan")), num(glass_hv)]])
	elif Js.truthy(body.get("metal")):
		if MovingCar.can_cut_body(inlay_entry(), target, claw):
			out.append(["Perforación", "%s, de %s HV, sí %s el %s, de %s HV%s" % [cl.txt, hv, _v(cl.pl, "corta", "cortan"), body.long,
				num(float(body.hv)), ": se clavan si un golpe las hunde" if not embedded else ": clavadas"]])
		else:
			out.append(["Perforación", "no: %s, de %s HV, no %s el %s, de %s HV" % [cl.txt, hv, _v(cl.pl, "corta", "cortan"), body.long,
				num(float(body.hv))]])
	elif s.reachesBody:
		out.append(["Perforación", "el surco entra en %s, más blando que %s" % [body.noun, cl.txt]])
	out.append_array(marks_rows())  # unidad 4s: a la velocidad del deslizador
	out.append_array(grip_rows())  # unidad 4u: en curva, los resbalones y la caída
	var shield: Variant = scen.get("windshield")
	if shield != null:
		var txt := "aguanta su peso"
		if shield.cracked:
			txt = "sus garras lo agrietan al apoyarse (el laminado no cae)" if Js.truthy(shield.get("contactCracks")) else "se agrieta bajo su peso (el laminado no cae)"
		out.append(["Parabrisas", "%s · ~%s por apoyo; se agrieta desde ~%s" % [txt, fmt_n(shield.loadN), fmt_n(shield.bendN)]])
	out.append_array(glass_hold_rows())  # unidad 4v
	out.append(["Frenada máxima que aguanta", braking_text() if report_matches_setup() else "calculando…"])
	out.append(["Aire", air_txt])
	if custom_air() and ref_text() != "":
		out.append(["Con el aire de referencia", ref_text()])
	return out


## Unas marcas del animal quieto encima en palabras: su veredicto y lo hondas que son («hasta el metal · 110 µm (quedan …)»);
## si atraviesan el panel (unidad 4o), «raja la chapa de lado a lado (0.81 mm con la pintura)»: lo de detrás es el hueco.
## residual: decir lo que queda al soltar.
func _hold_depth_txt(s: Dictionary, residual := true) -> String:
	var v := String(s.verdict).to_lower()
	if Js.truthy(s.get("through")):
		return "%s de lado a lado (%s con la pintura)" % [v, CarFormat.fmt_panel(float(s.depthUm))]
	var depth := Format.fmt_len(s.depthUm)
	if residual and float(s.residualUm) < float(s.depthUm) - 0.5:
		depth += " (quedan %s al soltar)" % Format.fmt_len(s.residualUm)
	return "%s · %s" % [v, depth]


## Posiciones de la clave del animal quieto encima de las que depende el despegue con el aire de referencia: todas menos
## la temperatura, la altitud y la velocidad.
const _REF_KEYS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14]


## El despegue con el aire de referencia (20 °C al nivel del mar: hold_report.detachRef) del ensayo que se ve, o null si
## aún no ha llegado. No depende del aire elegido ni de la velocidad del deslizador.
func ref_detach() -> Variant:
	if curve_on():
		return null  # unidad 4t: la referencia del aire es la de la recta; en curva no se compara
	var key := _hold_key()
	if key.is_empty() or _report_key.size() != key.size() or not (report.get("detachRef") is Dictionary):
		return null
	for i: int in _REF_KEYS:
		if _report_key[i] != key[i]:
			return null
	return report.detachRef


## ¿El aire elegido es otro que el de referencia (20 °C al nivel del mar)?
func custom_air() -> bool:
	return temp_c != MovingCar.PARAMS.temp_c.default or altitude_m != MovingCar.PARAMS.altitude_m.default


## El despegue con el aire de referencia en palabras: «a 20 °C y al nivel del mar, se suelta a ~196 km/h» ("" si aún no
## ha llegado).
func ref_text() -> String:
	var ref: Variant = ref_detach()
	if ref == null:
		return ""
	return "a 20 °C y al nivel del mar, %s" % det_words(ref)


## Frenada máxima que aguanta (hold_report.brakingG, caso central) a la velocidad a la que se calculó.
func braking_text() -> String:
	if report.is_empty() or not report.has("brakingG"):
		return "…"
	var g: float = report.brakingG
	var v: float = float(report.at.vKmh) if report.get("at") is Dictionary else v_kmh
	if curve_on() and not at.is_empty():
		g = _curve_braking_g()  # unidad 4t: con la aceleración lateral de la curva
		v = v_kmh
	var emergency: float = 0.0
	for m: Dictionary in MovingCar.MANEUVERS:
		if m.id == "emergencia":
			emergency = -float(m.accel_g)
	if g <= 0.0:
		return "ni sin frenar aguanta a %s" % fmt_kmh(v)
	if g >= MovingCar.BRAKING_TOP_G:
		return "cualquiera a %s (más de %s; la de emergencia es de %s)" % [fmt_kmh(v), fmt_g(MovingCar.BRAKING_TOP_G), fmt_g(emergency)]
	# redondeada hacia abajo: 0.8966 g no es «0.90 g», la de emergencia, que no aguanta (unidad 4o)
	return "%s a %s (caso central; la de emergencia es de %s)" % [CarFormat.fmt_g_max(g), fmt_kmh(v), fmt_g(emergency)]


# ════════ El golpe ════════

## Lecturas del golpe (impact): [{ id, label, value, sub, quality, source }].
func impact_readings() -> Array:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return []
	var out: Array = []
	# unidad 4d: la patada del casuario (con su masa por sexo), la rotura de unas garras reforjadas y la defensa
	var k: Variant = hit.get("kick")
	if k != null:
		out.append(_reading("patada", "Patada", fmt_kmh(k.leapKmh), "salto con los pies por delante · la pata aguanta hasta %s (banda %s)" % [
			fmt_n(k.forceCapN), fmt_n_band(k.forceCapMinN, k.forceCapMaxN)], String(k.quality), String(k.source)))
		var body: Dictionary = MovingCar.body_of(claw)
		var ms: Dictionary = body.mass_kg[String(k.sex)] if k.sex != null and body.has("mass_kg") else {}
		if not ms.is_empty():
			out.append(_reading("masa", "Masa (%s)" % String(MovingCar.SEX_NAMES.get(String(k.sex), k.sex)).to_lower(), "%s kg" % num(float(k.massKg)),
				"banda de %s a %s kg" % [num(float(ms.min)), num(float(ms.max))], String(ms.quality), String(ms.source)))
	var frac: Variant = hit.get("clawFracture")
	if frac != null:
		var sub := String(frac.reason)
		if frac.limitN != null:
			sub = "~%s de lado · aguanta%s de %s a %s" % [fmt_n(frac.lateralN), "" if is_kicker() else "n", fmt_n(frac.limitMinN), fmt_n(frac.limitMaxN)]
		out.append(_reading("garras", "%s de %s" % ["Daga" if is_kicker() else "Garras", frac.name], String(frac.verdict).to_lower(), sub,
			String(frac.quality) if frac.quality != null else "", String(frac.source) if frac.source != null else ""))
	var dfi: Variant = hit.get("defense")
	if dfi != null:
		out.append(_defense_reading(dfi))
	var kin: Variant = hit.get("kinematics")
	var kin_ok: bool = kin != null and Js.truthy(kin.get("ok"))
	var bd: Variant = hit.get("band")
	out.append(_reading("vrel", "Velocidad relativa", fmt_kmh(hit.vRelKmh),
		"%s contra el panel · %s a lo largo" % [fmt_kmh(hit.vNormalKmh), fmt_kmh(hit.vTangKmh)], "", String(kin.source) if kin_ok else ""))
	if kin_ok:
		out.append(_components_reading(kin))
		if float(kin.flightS) > 0.0:
			out.append(_flight_reading(kin))
	out.append(_reading("energia", "Energía respecto al coche", MovingCar.fmt_energy(hit.energyJ), "½·m·v_rel²", "", ""))
	out.append(_reading("normal", "Energía contra el panel", MovingCar.fmt_energy(hit.normalJ),
		"½·μ_red·v_n² con μ_red = %s kg%s" % [Js.to_fixed(hit.reducedMassKg, 1), _band_sub(bd, "normalJ", "energy")], "secondary",
		"masa reducida con el coche, μ_red = m·M/(m + M): la energía que se pierde si el animal y el coche acaban moviéndose juntos contra el panel (choque plástico)"))
	out.append(_reading("friccion", "Fricción garra-panel (μ)", Js.to_fixed(hit.mu, 2), "banda de la fricción %s-%s" % [
		num(MovingCar.FRICTION.min), num(MovingCar.FRICTION.max)], MovingCar.FRICTION.quality, MovingCar.FRICTION.source))
	# unidad 4j: con las garras trabadas en el plástico, en lugar de resbalar lo raja (la 4g, hit.tear)
	var tear: Variant = hit.get("tear")
	var rips: bool = tear != null and Js.truthy(tear.holds) and float(tear.lengthMm) > 0.0
	var dn: Variant = hit.get("dent")
	# unidad 4o: de lado y sin abolladura, resbalón ni desgarro (la ventanilla; el plástico perforado, que no se abolla, si
	# se le sueltan las garras) el modelo no tiene un tiempo de contacto que dar: en vez de «0 ms», la lectura no sale
	if float(hit.contactS) > 0.0:
		out.append(_reading("contacto", "Contacto", CarFormat.fmt_ms(float(hit.contactS)), "%s y %s" % [
			"la abolladura" if dn != null and dn.applies else "el golpe", "el desgarro" if rips else "el resbalón"], "", ""))
	var leaves := "se queda encima" if hit.stays else "sale a %s del panel" % fmt_kmh(hit.exitKmh)
	if rips:
		out.append(_tear_reading(tear, bd))
	else:
		# unidad 4o: si no resbala (de lado no hay peso que lo apriete contra el panel), «nada» en vez de «0.0 µm»
		var slid: bool = float(hit.slideM) > 0.0
		out.append(_reading("resbala", "Resbala", MovingCar.fmt_long(float(hit.slideM) * 1e6) if slid else "nada",
			("%s" if slid or not impact_side() else "golpea de lado y %s") % leaves + _band_sub(bd, "slideM", "m"), "", ""))
		if tear != null:
			out.append(_tear_reading(tear, bd))
	if not hit.stays:
		out.append(_reading("suelo", "Respecto al suelo", fmt_kmh(hit.groundKmh), "al salir del coche", "", ""))
	var mk := _marks_reading(bd)
	if not mk.is_empty():
		out.append(mk)
	var dent: Variant = hit.get("dent")
	if dent != null and dent.applies:
		var iz: Dictionary = MovingCar.IMPACT_ZONES[impact_zone]
		out.append(_reading("abolladura", "Abolladura", MovingCar.fmt_long(float(dent.depthMm) * 1000.0),
			"%s · pico de %s por apoyo%s%s%s" % ["el pie" if int(dent.patches) == 1 else "%d apoyos" % int(dent.patches), fmt_n(dent.peakN),
				", llega al fondo" if dent.bottomsOut else "", ", la pata en su fuerza máxima" if Js.truthy(dent.get("capped")) else "",
				_band_sub(bd, "dentMm", "mm")],
			"estimate", "%s. Estimaciones: el recorrido de la pata (%s mm; %s), su rigidez (%s N/mm; %s) y el hueco bajo el panel (%s mm; %s)" % [
				MovingCar.SRC_DENT, num(MovingCar.LIMB_STROKE_MM), MovingCar.LIMB_STROKE.source, num(Physics.MODEL.limbStiffness),
				MovingCar.LIMB_STIFFNESS.source, num(float(iz.clearance_mm)), _clearance_source(iz).source]))
	var shield: Variant = hit.get("windshield")
	if shield != null:
		out.append(_reading("parabrisas", "Parabrisas", "se agrieta" if shield.cracked else "aguanta",
			"~%s por apoyo contra ~%s" % [fmt_n(shield.peakN), fmt_n(shield.bendN)], "secondary",
			"%s; la hoja flexa como una placa apoyada (Roark)" % String(Glazing.WINDSCREEN.source)))
	var sw: Variant = hit.get("sideWindow")
	if sw != null:
		out.append(_window_reading(sw))  # unidad 4m: la ventanilla templada
	out.append_array(glass_readings())  # unidad 4v
	var tr := tear_reading()  # unidad 4s
	if not tr.is_empty():
		out.append(tr)
	return out


## La lectura de la ventanilla templada (unidad 4m): si estalla y por qué, con la fuerza de cada apoyo y de cada garra.
func _window_reading(sw: Dictionary) -> Dictionary:
	var value := "aguanta"
	var sub := "~%s por apoyo; estalla al flexar desde ~%s" % [fmt_n(sw.peakN), fmt_n(sw.bendN)]
	if Js.truthy(sw.shattered) and sw.cause == "grieta":
		value = "estalla por una grieta"
		sub = "~%s por garra (bastan ~%s); al flexar, ~%s por apoyo contra ~%s" % [fmt_n(sw.perClawN), fmt_n(sw.pierceN), fmt_n(sw.peakN),
			fmt_n(sw.bendN)]
	elif Js.truthy(sw.shattered):
		value = "estalla"
		sub = "~%s por apoyo contra ~%s al flexar" % [fmt_n(sw.peakN), fmt_n(sw.bendN)]
	# unidad 4o: si aguanta, los trocitos son los que haría al estallar («si estalla, …»), no los que ha hecho
	return _reading("ventanilla", "Ventanilla", value, "%s · %strocitos de ~%s%s" % [sub, "" if Js.truthy(sw.shattered) else "si estalla, ",
		CarFormat.fmt_long(float(sw.fragmentMm) * 1000.0), _window_band_sub(hit.get("band"))], String(sw.quality), String(sw.source))


## Las componentes de la velocidad del animal respecto al coche (unidad 4j, MovingCar.kinematics: x hacia delante, y hacia el
## costado, z hacia arriba), en km/h y con palabras: «50 · 40 · 11 km/h», «hacia atrás · de lado · hacia abajo».
func _components_reading(kin: Dictionary) -> Dictionary:
	var r: Dictionary = kin.relKmh
	var x := float(r.x)
	var y := float(r.y)
	var z := float(r.z)
	var zero := func(v: float) -> bool: return CarFormat.kmh_txt(absf(v)) == "0"
	var wx := "ni adelante ni atrás" if zero.call(x) else ("hacia delante" if x > 0.0 else "hacia atrás")
	var wy := "nada de lado" if zero.call(y) else "de lado"
	var wz := "sin caída" if zero.call(z) else ("hacia abajo" if z < 0.0 else "hacia arriba")
	return _reading("componentes", "Respecto al coche", "%s · %s · %s km/h" % [CarFormat.kmh_txt(absf(x)), CarFormat.kmh_txt(absf(y)),
		CarFormat.kmh_txt(absf(z))], "%s · %s · %s" % [wx, wy, wz], "", String(kin.source))


## El vuelo antes de tocar el panel (unidad 4j): cuánto tarda, cuánto baja y a qué velocidad llega, y lo que avanza el coche
## mientras tanto. Saltando desde la carretera (un velocirraptor), el tiempo de su salto (leap.timeS).
func _flight_reading(kin: Dictionary) -> Dictionary:
	var sub := "cae %s y llega bajando a %s" % [CarFormat.fmt_m(float(kin.dropM), 2), fmt_kmh(float(kin.fallKmh))]
	if Js.truthy(kin.get("apex")):
		# unidad 4m: a la ventanilla salta para llegar y golpea en lo más alto del salto
		sub = "salta desde la carretera y golpea en lo más alto del salto, sin subir ni bajar"
	elif Js.truthy(kin.leap):
		sub = "salta desde la carretera y baja %s desde lo más alto, a %s" % [CarFormat.fmt_m(float(kin.dropM), 2), fmt_kmh(float(kin.fallKmh))]
	sub += " · el coche avanza %s" % CarFormat.fmt_m(float(kin.carFlightM), 1)
	return _reading("vuelo", "Vuelo", CarFormat.fmt_s(float(kin.flightS)), sub, "", String(kin.source))


## «Raja» (unidad 4j): las garras trabadas en el plástico lo rajan (la 4g, hit.tear), con el largo y su banda; o por qué no
## (no aguanta lo que pide rajarlo y se le sueltan, o no le queda velocidad a lo largo del panel).
func _tear_reading(t: Dictionary, bd: Variant) -> Dictionary:
	var q := String(t.get("quality", ""))
	var src := String(t.get("source", ""))
	if not Js.truthy(t.holds):
		var art := String(ZONE_ARTICLE.get(impact_zone, "la")).get_slice(" ", 0)
		var sub := "rajar%s pide ~%s y solo aguanta ~%s: se le sueltan las garras" % ["la" if art == "la" else "lo", fmt_n(float(t.forceN)),
			fmt_n(float(t.anchorN.value))]
		var tb: Variant = bd.get("tearMm") if bd != null else null
		if tb != null and float(tb.max) > 0.0:
			sub += "; con todo en contra, raja %s" % MovingCar.fmt_long(float(tb.max) * 1000.0)
		return _reading("raja", "Raja", "no", sub, q, src)
	if float(t.lengthMm) <= 0.0:
		return _reading("raja", "Raja", "no", "las garras quedan trabadas, pero no le queda velocidad a lo largo del panel", q, src)
	var how := "se para a su lado: el coche se lo lleva" if Js.truthy(t.stopped) else "sale a %s del panel" % fmt_kmh(float(t.vExitKmh))
	return _reading("raja", "Raja", MovingCar.fmt_long(float(t.lengthMm) * 1000.0), how + _band_sub(bd, "tearMm", "mm"), q, src)


## «Marcas» (unidad 4j): lo hondas que son, con su banda (la pintura más dura las deja menos hondas o ninguna). Sin marcas en
## toda la banda, {}.
func _marks_reading(bd: Variant) -> Dictionary:
	var m: Dictionary = hit.marks
	var n := int(m.count)
	var b: Variant = bd.get("marksDepthUm") if bd != null else null
	var src := String(bd.source) if bd != null else ""
	if n <= 0:
		if b == null or float(b.max) <= 0.0:
			return {}
		return _reading("marcas", "Marcas (profundidad)", "ninguna", "con todo en contra, %s" % Format.fmt_len(float(b.max)), "estimate", src)
	var sub := "%d %s" % [n, "surco" if n == 1 else "surcos"]
	if Js.truthy(m.get("through")):
		# unidad 4o: de lado a lado; su hondura es la del panel y la punta de la garra no pasa del hueco que hay detrás
		var mt: Variant = bd.get("marksThrough") if bd != null else null
		sub = "%s · %s" % [MovingCar.through_txt(m, target, impact_zone, n != 1), sub]
		if mt != null and not Js.truthy(mt.lo):
			sub += " · con todo a favor, no %s atraviesan" % ("la" if String(target.body.noun).begins_with("la") else "lo")
		var gap := _clearance_source(MovingCar.IMPACT_ZONES[impact_zone]) if Js.truthy(m.get("bottoms")) else {}
		return _reading("marcas", "Marcas (profundidad)", "de lado a lado", sub, String(gap.get("quality", "")), String(gap.get("source", "")))
	if b != null and float(b.min) <= 0.0:
		sub += " · con todo a favor, no raya"
	else:
		sub += _band_sub(bd, "marksDepthUm", "um")
	var varies: bool = b != null and float(b.min) != float(b.max)
	return _reading("marcas", "Marcas (profundidad)", Format.fmt_len(float(m.depthUm)), sub, "estimate" if varies else "", src if varies else "")


## « · banda de A a B» de una magnitud de la banda del golpe (hit.band[key]: { value, min, max }) si cambia con los datos;
## "" si no hay banda o no cambia. unit: «energy» (J), «m» (m), «mm» o «um» (longitudes).
static func _band_sub(bd: Variant, key: String, unit: String) -> String:
	if bd == null:
		return ""
	var b: Variant = bd.get(key)
	if b == null or float(b.min) == float(b.max):
		return ""
	if float(b.min) <= 0.0:
		return " · banda: hasta %s" % _band_val(float(b.max), unit)
	return " · banda de %s a %s" % [_band_val(float(b.min), unit), _band_val(float(b.max), unit)]


static func _band_val(v: float, unit: String) -> String:
	match unit:
		"energy":
			return MovingCar.fmt_energy(v)
		"n":
			return fmt_n(v)
		"m":
			return MovingCar.fmt_long(v * 1e6)
		"mm":
			return MovingCar.fmt_long(v * 1000.0)
	return Format.fmt_len(v)


## La fuente y la calidad del hueco bajo el panel de una zona del golpe (IMPACT_ZONES.sources.clearance_mm, de la 4g); si
## una zona no la trae, una estimación del modelo.
static func _clearance_source(iz: Dictionary) -> Dictionary:
	var fs: Variant = iz.get("sources")
	var c: Variant = fs.get("clearance_mm") if fs is Dictionary else null
	return c if c is Dictionary else { "quality": "estimate", "source": SRC_DOC_ESTIMATES }


## Capas del coche con lo que les pasa: [{ name, col, from, to, state: "intacta" | "rayada" | "atravesada" }]. Las
## rayadas son las que cruzan las marcas (marks.layers o scratch.layers, en orden desde el barniz); las atravesadas,
## las de una punción que atraviesa (puncture.through).
func layers_view() -> Array:
	var L: Variant = Catalog.car_layers(target)
	if L == null:
		return []
	var cut := 0
	var through := false
	if mode == MODE_IMPACT and not hit.is_empty() and Js.truthy(hit.get("ok")):
		cut = (hit.marks.layers as Array).size()
		var pn: Variant = hit.get("puncture")
		if pn != null:
			cut = maxi(cut, (pn.layers as Array).size())
			through = pn.through
	elif not scen.is_empty() and Js.truthy(scen.get("ok")):
		cut = hold_visible_layers().size()  # unidad 4y: lo que se ve (las huellas si no se mueven)
		through = embedded  # clavadas tras un golpe que ha atravesado el panel
		var now := marks_now()
		if not now.is_empty() and (Js.truthy(now.through) or Js.truthy(now.punctThrough)):
			through = true  # unidad 4s: a esta velocidad, de lado a lado
	var out: Array = []
	for i in (L as Array).size():
		var l: Dictionary = L[i]
		var state := "intacta"
		if through:
			state = "atravesada"
		elif i < cut:
			state = "rayada"
		out.append({ "name": l.name, "col": l.col, "from": l.from, "to": l.to, "state": state })
	return out


## Las marcas del animal quieto encima: desde la unidad 4s, las de la velocidad del deslizador (marks_now, cuando la curva
## ha llegado); si no, las de su peso al resbalar (scratch) o, asustado, sus desgarros (defense.tear).
func hold_marks() -> Dictionary:
	var now := marks_now()
	if not now.is_empty():
		return now.marks
	var dfn: Variant = scen.get("defense")
	return dfn.tear if dfn != null else scen.scratch


# ════════ Unidad 4s: el daño según la velocidad ════════

## El tope del deslizador de velocidad (km/h) con el coche elegido (slider_max_kmh, de la unidad 4r: 230 en el turismo, la
## velocidad máxima del deportivo): la gráfica del daño llega hasta él.
func top_kmh() -> float:
	return slider_max_kmh()


## Clave del ensayo de la gráfica del daño: la del animal quieto encima sin la velocidad.
func _marks_trial_key() -> Array:
	var k := _hold_key()
	return k.slice(0, -1) if not k.is_empty() else []


## La gráfica del daño frente a la velocidad del ensayo que se ve ({} mientras no llega del hilo).
func marks_curve() -> Dictionary:
	if marks_chart.is_empty() or _marks_key != _marks_trial_key():
		return {}
	return marks_chart


## Lo que hay a la velocidad del deslizador (CarSpeedMarks.at: interpola la curva, sin compute); {} sin curva.
func marks_now() -> Dictionary:
	return CarSpeedMarks.at(marks_curve(), v_kmh)


## Cómo quedan las garras a esta velocidad: «intacta», «mella», «parte», «dobla» o «» (sin curva o sin datos).
func marks_frac_mode() -> String:
	var m := marks_now()
	if m.is_empty():
		return ""
	return String(m.fracMode) if Js.truthy(m.broken) else "intacta"


## Lo que pierde la garra rota (mm), para el dibujo: brokenMm de la rotura de la muestra.
func marks_broken_mm() -> float:
	var m := marks_now()
	if m.is_empty() or not Js.truthy(m.broken):
		return 0.0
	return float(m.fracture.brokenMm)


## La nota bajo la gráfica: por qué no perfora con ese material (o nada) y la rotura de las garras. "" sin curva.
func marks_note() -> String:
	var c := marks_curve()
	if c.is_empty():
		return ""
	var parts: Array = []
	var note := CarSpeedMarks.no_through_note(c, scen)
	if note != "":
		parts.append(note)
	var b := CarSpeedMarks.break_txt(c, float(c.detachKmh))
	if b != "":
		parts.append(_cap(b) + ".")
	var m := marks_now()
	if not m.is_empty() and Js.truthy(m.broken) and Js.truthy(m.anchorLost):
		parts.append("Sin las garras no hay anclaje: %s." % ("aguanta solo con la fricción de su peso" if Js.truthy(m.holdsAfter) else "se suelta"))
	return " ".join(PackedStringArray(parts))


## Lecturas en directo del daño a esta velocidad (hold_readings las añade): las marcas, la carga de cada garra y la rotura.
func marks_readings() -> Array:
	var m := marks_now()
	if m.is_empty():
		return []
	var c := marks_curve()
	var out: Array = []
	var fr: Dictionary = m.fracture
	# unidad 4y: lo que deja de verdad (la huella de cada garra; surcos solo si se mueven), de acuerdo con el dibujo
	var plan := hold_plan()
	var shown := CarHoldMarks.visible_depth_um(plan) if not plan.is_empty() else float(m.depthUm)
	out.append(_reading("marcas_v", "Marcas a esta velocidad", Format.fmt_len(shown), hold_plan_txt() if not plan.is_empty() else CarSpeedMarks.marks_txt(m, target),
		String(plan.get("quality", c.quality)), String(c.source) + ("; " + String(plan.source) if not plan.is_empty() else "")))
	var load_sub := CarSpeedMarks.load_txt(m)
	var yields: bool = Js.truthy(c.samples[0].tipYields)
	if yields or Js.truthy(fr.get("slips", false)):
		load_sub += " · " + (("la punta se aplasta contra %s" % String(target.body.noun)) if yields else "resbala por su surco: solo toma de lado lo que ara")
	out.append(_reading("carga_garra", "Carga en cada garra", fmt_n(float(m.tipN)), load_sub, String(c.quality), String(c.source)))
	var how := "intacta"
	match String(fr.mode):
		"mella":
			how = "se mella la punta"
		"parte":
			how = "se parte por la base"
		"dobla":
			how = "se dobla"
		"sin_datos":
			how = "sin datos"
	var when := CarSpeedMarks.break_txt(c, float(c.detachKmh))
	if Js.truthy(fr.get("sizeEffect")):
		when += " · sección más pequeña que la distancia crítica del material: cota baja"
	out.append(_reading("rotura", "Garras de %s a esta velocidad" % CarSpeedMarks.noun_of(inlay_entry()), how, when, String(fr.quality) if fr.quality != null else "",
		String(fr.source) if fr.source != null else String(fr.reason)))
	var tr := tear_reading()
	if not tr.is_empty():
		out.append(tr)
	return out


## Filas del informe (hold_rows las añade): las marcas, la punción y las garras a la velocidad del deslizador.
func marks_rows() -> Array:
	var m := marks_now()
	if m.is_empty():
		return [["Marcas a %s" % fmt_kmh(v_kmh), "calculando…"]]
	var out: Array = []
	var plan := hold_plan()  # unidad 4y: lo que deja de verdad
	out.append(["Marcas a %s" % fmt_kmh(v_kmh), hold_plan_txt() if not plan.is_empty() else CarSpeedMarks.marks_txt(m, target)])
	var layers: Array = hold_visible_layers()
	if not layers.is_empty():
		var title := "Capas que raya a esa velocidad" if plan.is_empty() or CarHoldMarks.moves(plan) else "Capas que marca la punta a esa velocidad"
		out.append([title, " · ".join(PackedStringArray(layers))])
	var fr: Dictionary = m.fracture
	var verdict := String(fr.verdict).to_lower() if fr.verdict != "" else "sin datos"
	out.append(["Garras a %s" % fmt_kmh(v_kmh), ("%s: %s" % [verdict, fr.vsub]) if fr.vsub != "" else verdict])
	if Js.truthy(m.broken):
		var after := "no sujetaban: sigue con la fricción y el agarre de los dedos"
		if Js.truthy(m.anchorLost):
			after = "sin garras no hay anclaje: %s" % ("aguanta con la fricción de su peso" if Js.truthy(m.holdsAfter) else "se suelta")
		out.append(["Después de romperse", "%s garras rotas: %s" % [num(float(m.clawsBroken)), after]])
	return out


## Unidad 4s (petición de Eric del 13-10) · el radio de la punta de las garras del ensayo (µm): el de la herramienta del
## motor (Physics.resolve_tool: √(área/π) de la ficha, o la punta afilada de ClawSharpness si se afilan unas reforjadas).
## 0 sin animal.
func claw_tip_um() -> float:
	if not supported():
		return 0.0
	var inl: Variant = MovingCar.inlay_of({ "inlay": inlay_param() })
	var tool := Physics.resolve_tool(MovingCar._lab_params(ClawsV2.apply(claw), target, {
		"inlay": inl if inl != null else Catalog.INLAYS[0], "model": MODEL, "sharpness": sharpness }))
	return float(tool.tipRadiusUm)


## El texto del primer plano de las garras: [las garras (material y punta, del motor), lo que hacen ahora]. Quieto encima,
## las marcas a la velocidad del deslizador y la rotura (CarSpeedMarks); en el golpe, sus marcas y lo que les pasa a las
## garras (clawFracture). ["", ""] sin animal.
func closeup_caption() -> Array:
	if not supported():
		return ["", ""]
	var noun := CarSpeedMarks.noun_of(inlay_entry())
	var head := "Garras de %s · punta R %s" % [noun, Format.fmt_tip_um(claw_tip_um())]
	if sharpenable() and sharpness > 0.0:
		head += " (afiladas)"
	var now := ""
	if mode == MODE_HOLD:
		var m := marks_now()
		if not m.is_empty():
			now = "a %s: %s" % [fmt_kmh(v_kmh), closeup_marks_txt(m)]  # unidad 4v: el veredicto de CarTear
			match marks_frac_mode():
				"mella":
					now = "melladas · " + now
				"parte":
					now = "partidas · " + now
				"dobla":
					now = "dobladas · " + now
	elif not hit.is_empty() and Js.truthy(hit.get("ok")):
		var mk: Dictionary = hit.get("marks", {})
		var parts: Array = []
		if int(mk.get("count", 0)) > 0 and float(mk.get("depthUm", 0.0)) > 0.0:
			parts.append("%s %s de %s" % [num(float(mk.count)), "surcos" if int(mk.count) != 1 else "surco", Format.fmt_len(float(mk.depthUm))])
		var pn: Variant = hit.get("puncture")
		if pn != null and Js.truthy(pn.get("through")):
			parts.append("agujeros de Ø %s" % Format.fmt_len(float(pn.holeUm)))
		var dn: Variant = hit.get("dent")
		if dn != null and Js.truthy(dn.get("applies")) and float(dn.get("depthMm", 0.0)) > 0.0:
			parts.append("abolladura de %s" % Format.fmt_len(float(dn.depthMm) * 1000.0))
		var fr: Variant = hit.get("clawFracture")
		if fr != null:
			var how: String = { "mella": "se mellan", "parte": "se parten", "dobla": "se doblan" }.get(String(fr.get("mode", "")), "")
			if how != "":
				parts.append("las garras " + how)
		now = " · ".join(PackedStringArray(parts)) if not parts.is_empty() else "sin marcas"
		now = glass_closeup_impact(now)  # unidad 4v
	return [head, now]


## Unidad 4s (petición de Eric del 17-10) · hasta dónde llegan las marcas y si rajan o abren el panel (CarTear.assess):
## quieto encima, las marcas a la velocidad del deslizador (marks_now), con lo que tira el viento de las garras (needN); en
## el golpe, las del motor (marcas, punción y el desgarro del plástico). {} sin animal, sin coche pintado o mientras llega.
func tear_now() -> Dictionary:
	if not supported() or target.get("body") == null:
		return {}
	if glass_zone_now():
		return glass_cut()  # unidad 4v: el corte del vidrio
	var b: Variant = MovingCar.body_of(claw)
	var c: Dictionary = ClawsV2.apply(claw)
	var cuts := MovingCar.can_cut_body(inlay_entry(), target, c)
	var o := { "target": target, "cuts": cuts, "film": film() }
	if mode == MODE_IMPACT:
		if hit.is_empty() or not Js.truthy(hit.get("ok")):
			return {}
		var mk: Dictionary = hit.get("marks", {})
		var pn: Variant = hit.get("puncture")
		var panel := MovingCar.panel_um(target)
		var depth := float(mk.get("depthUm", 0.0))
		var through := Js.truthy(mk.get("through")) or (panel > 0.0 and depth >= panel - 1e-6)
		var tear: Variant = hit.get("tear")
		o.merge({ "zone": impact_zone, "hold": false, "depthUm": depth, "through": through,
			"punctThrough": pn != null and Js.truthy(pn.get("through")), "holeUm": float(pn.get("holeUm", 0.0)) if pn != null else 0.0,
			"cutMm": float(mk.get("lengthMm", 0.0)) if through else 0.0, "nClaws": maxi(int(mk.get("count", 0)), 1),
			"tearMm": float(tear.lengthMm) if tear is Dictionary and Js.truthy(tear.get("applies")) and Js.truthy(tear.get("holds")) else -1.0 })
		return CarTear.assess(o)
	var m := marks_now()
	if m.is_empty():
		return {}
	# unidad 4y: sin moverse, lo que se ve es la huella de cada garra (la punción), no el surco de si resbalara
	var p0 := _hold_plan_of(m, 0.0)
	var still := not CarHoldMarks.moves(p0)
	return _tear_hold(o, m, CarHoldMarks.visible_depth_um(p0) if still else float(m.depthUm), still, b)


## Unidad 4y: el escalón de CarTear quieto encima con la hondura de lo que se ve (still: sin moverse, la de las huellas).
func _tear_hold(o: Dictionary, m: Dictionary, depth_um: float, still: bool, b: Variant) -> Dictionary:
	var pn2: Variant = m.get("puncture")
	o.merge({ "zone": zone, "hold": true, "depthUm": depth_um, "through": Js.truthy(m.through),
		"punctThrough": Js.truthy(m.punctThrough), "holeUm": float(pn2.holeUm) if pn2 != null else 0.0,
		"cutMm": 0.0,  # quieto encima las garras no avanzan: solo corre la raja si el viento puede con ella (pullN)
		"nClaws": int(b.get("contact", 1)) if b != null else 1, "pullN": float(at.get("needN", 0.0)) if not at.is_empty() else 0.0,
		"pit": still })
	return CarTear.assess(o)


## La ficha de tear_now: el escalón («Marca», «Perfora», «Raja 35 cm», «Abre la puerta») con las capas y el porqué; {} sin datos.
func tear_reading() -> Dictionary:
	var t := tear_now()
	if t.is_empty() or int(t.level) <= 0:
		return {}
	var value := "Marca"
	if Js.truthy(t.get("glass")):
		value = GLASS_CUT_VALUE.get(String(t.id), value)  # unidad 4v
	match String(t.id):
		"perfora":
			value = "Perfora"
		"raja":
			value = "Raja %s" % CarTear.len_txt(float(t.lengthMm))
		"abre":
			value = "Abre la puerta"
	var sub := String(t.text)
	for k: String in ["why", "door", "roof"]:
		if String(t.get(k, "")) != "":
			sub += " · " + String(t[k])
	var q := String(t.quality) if String(t.quality) != "" else "secondary"
	var src := String(t.source) if String(t.source) != "" else "las marcas del motor de siempre con las capas de la pintura y de la carrocería del banco"
	if Js.truthy(t.get("glass")):
		sub = String(t.text) + ((" · " + String(t.why)) if String(t.why) != "" else "")  # unidad 4v
	if String(t.get("door", "")) != "":
		src += "; la cerradura: %s; los osos de Yosemite: %s" % [CarTear.LATCH.source, CarTear.NPS_BEAR.source]
	if String(t.get("roof", "")) != "":
		src += "; el techo: %s" % CarTear.ROOF.source
	return _reading("desgarro", "Hasta dónde llega", value, sub, q, src)


## Color del fondo de los surcos: el de la capa más honda que cortan (el metal, si llegan a él). "" si no hay surcos.
func groove_color() -> String:
	var marks: Variant = null
	if mode == MODE_IMPACT and not hit.is_empty() and Js.truthy(hit.get("ok")):
		marks = hit.marks
	elif not scen.is_empty() and Js.truthy(scen.get("ok")):
		marks = { "layers": hold_visible_layers() }  # unidad 4y: lo que se ve (las huellas si no se mueven)
	if marks == null:
		return ""
	var n: int = (marks.layers as Array).size()
	var L: Variant = Catalog.car_layers(target)
	if n <= 0 or L == null:
		return ""
	return String(L[mini(n, (L as Array).size()) - 1].col)


## Color del veredicto del golpe (paleta): coral si agrieta el parabrisas, perfora o abolla; oro si solo raya; menta si
## apenas deja marca o el parabrisas aguanta.
func impact_color() -> String:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return "dim"
	var sh: Variant = hit.get("windshield")
	if sh != null:
		return "coral" if sh.cracked else "mint"
	var sw: Variant = hit.get("sideWindow")
	if sw != null:
		return "coral" if Js.truthy(sw.shattered) else "mint"  # unidad 4m
	var pn: Variant = hit.get("puncture")
	var dn: Variant = hit.get("dent")
	if (pn != null and pn.through) or (dn != null and dn.applies and dn.visible):
		return "coral"
	return "gold" if int(hit.marks.count) > 0 else "mint"


## Balance de energía del golpe para la barra apilada: energy.terms en su orden, con short, share, quality y source.
func energy_terms() -> Array:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return []
	return hit.energy.terms


## Por dónde llega el animal en el dibujo lateral (solo para el dibujo): la dirección de su velocidad respecto al coche en
## el plano del costado (x hacia delante, z hacia arriba), unitaria, y cuánto viene de frente al costado (0-1). La calcula
## MovingCar.kinematics (unidad 4j: arrival): la del golpe que se ve o, mientras no ha llegado, la de los datos de ahora (la
## caída en los paneles de arriba, el salto de la patada del casuario o el vuelo de un velocirraptor).
func arrival() -> Dictionary:
	var k: Variant = hit.get("kinematics") if not hit.is_empty() and Js.truthy(hit.get("ok")) else null
	if k == null:
		k = MovingCar.kinematics(impact_params())
	if not Js.truthy(k.get("ok")):
		return { "x": 0.0, "z": -1.0, "lateral": 0.0 }
	return k.arrival


## La banda del golpe en una frase (unidad 4j; MovingCar.impact_band, hit.band), como la del animal quieto encima: de todo a
## favor del coche a todo en contra, las marcas (lo hondas que son), la abolladura, si perfora, la energía contra el panel y
## el desgarro del plástico. "" sin golpe.
func impact_band_text() -> String:
	if hit.is_empty() or not Js.truthy(hit.get("ok")) or hit.get("band") == null:
		return ""
	var b: Dictionary = hit.band
	var parts: Array = []
	var md: Dictionary = b.marksDepthUm
	var mt: Dictionary = b.get("marksThrough", {})
	if float(md.max) <= 0.0:
		parts.append("no raya")
	elif Js.truthy(mt.get("hi")) or Js.truthy(mt.get("value")):
		# unidad 4o: unas marcas que atraviesan el panel son tan hondas como él (lo de detrás es el hueco)
		var thr := "atraviesan %s (%s con la pintura)" % [String(target.body.noun), CarFormat.fmt_panel(MovingCar.panel_um(target))]
		if Js.truthy(mt.get("lo")):
			parts.append("marcas que " + thr)
		elif Js.truthy(mt.get("value")):
			parts.append("marcas que %s; con todo a favor, %s" % [thr, ("de %s de hondo" % Format.fmt_len(float(md.min))) if float(md.min) > 0.0 else "ninguna"])
		elif float(md.value) > 0.0:
			parts.append("marcas de %s de hondo; con todo en contra, %s" % [Format.fmt_len(float(md.value)), thr])
		else:
			parts.append("marcas solo con todo en contra, que " + thr)
	elif float(md.min) <= 0.0:
		parts.append("marcas de hasta %s de hondo, y ninguna con todo a favor" % Format.fmt_len(float(md.max)))
	else:
		parts.append("marcas %s de hondo" % _range_txt(md, "um", "de "))
	var dm: Variant = b.dentMm
	if dm != null:
		var lo_v: bool = b.lo.dentVisible
		var hi_v: bool = b.hi.dentVisible
		var mid_v := float(dm.value) >= MovingCar.Dent.VISIBLE_MM
		if not lo_v and not hi_v and not mid_v:
			parts.append("no abolla")
		elif not lo_v and not mid_v:
			parts.append("abolla solo con todo en contra, %s" % MovingCar.fmt_long(float(dm.max) * 1000.0))
		else:
			parts.append("abolladura %s" % _range_txt(dm, "mm", "de "))
	var th: Dictionary = b.through
	var shield: Variant = hit.get("windshield")
	if b.get("sideWindow") != null:
		parts.append(_window_band_txt(b.sideWindow))  # unidad 4m: la ventanilla templada no se perfora: estalla o aguanta
	elif shield != null:
		# unidad 4o: el parabrisas no lo perforan las garras (ni las raya la queratina): lo que dice es si se agrieta, como el
		# veredicto; la hoja de vidrio no tiene banda
		parts.append("el parabrisas %s" % (("se agrieta%s" % (" y puede atravesarlo" if Js.truthy(shield.penetrationRisk) else ""))
			if Js.truthy(shield.cracked) else "aguanta"))
	elif not Js.truthy(th.lo) and not Js.truthy(th.value) and not Js.truthy(th.hi):
		parts.append("no perfora")
	elif Js.truthy(th.lo) and Js.truthy(th.value) and Js.truthy(th.hi):
		parts.append("perfora")
	else:
		parts.append("perfora %s" % ("con todo en contra; con todo a favor, no" if Js.truthy(th.hi) else "con todo a favor; con todo en contra, no"))
	parts.append("%s contra el panel" % _range_txt(b.normalJ, "energy"))
	var tm: Variant = b.tearMm
	if tm != null and float(tm.max) > 0.0:
		parts.append(("raja hasta %s, y nada con todo a favor" % MovingCar.fmt_long(float(tm.max) * 1000.0)) if float(tm.min) <= 0.0 else (
			"raja %s" % _range_txt(tm, "mm")))
	return "Banda de los datos, de todo a favor del coche a todo en contra: %s." % "; ".join(PackedStringArray(parts))


## La ventanilla templada en la frase de la banda del golpe (unidad 4m; impact().band.sideWindow): si estalla o aguanta de todo
## a favor del coche a todo en contra (con todo a favor, la compresión más alta de las caras; en contra, la más baja) y con
## qué fuerza de pico en cada apoyo: «la ventanilla aguanta (con todo en contra, estalla): 1290 N de pico por apoyo».
static func _window_band_txt(sw: Dictionary) -> String:
	var sh: Dictionary = sw.shattered
	var how := "la ventanilla aguanta (con todo en contra, estalla)"
	if Js.truthy(sh.lo):
		how = "la ventanilla estalla"
	elif not Js.truthy(sh.hi):
		how = "la ventanilla aguanta"
	elif Js.truthy(sh.value):
		how = "la ventanilla estalla (con todo a favor, aguanta)"
	return "%s: %s de pico por apoyo" % [how, _range_txt(sw.peakN, "n")]


## La banda de la ventanilla en su lectura (unidad 4m; impact().band.sideWindow): si con todo a favor del coche aguanta y con
## todo en contra estalla, y la fuerza de pico de cada apoyo si cambia. "" si la banda no cambia nada.
static func _window_band_sub(bd: Variant) -> String:
	var b: Variant = bd.get("sideWindow") if bd != null else null
	if b == null:
		return ""
	var parts: Array = []
	var sh: Dictionary = b.shattered
	if Js.truthy(sh.lo) != Js.truthy(sh.hi):
		parts.append("con todo a favor, %s; con todo en contra, %s" % ["estalla" if Js.truthy(sh.lo) else "aguanta",
			"estalla" if Js.truthy(sh.hi) else "aguanta"])
	var pk: Dictionary = b.peakN
	if float(pk.min) != float(pk.max):
		parts.append("pico de %s a %s por apoyo" % [fmt_n(float(pk.min)), fmt_n(float(pk.max))])
	return (" · banda: " + "; ".join(PackedStringArray(parts))) if not parts.is_empty() else ""


## «de A a B» de una magnitud de la banda del golpe ({ value, min, max }) o, si no cambia, A (con single delante: «de A»).
static func _range_txt(r: Dictionary, unit: String, single := "") -> String:
	if float(r.min) == float(r.max):
		return single + _band_val(float(r.min), unit)
	return "de %s a %s" % [_band_val(float(r.min), unit), _band_val(float(r.max), unit)]


## El aire alrededor del coche para el dibujo del viento (unidad 4k), sin nada nuevo que calcular: la velocidad del aire
## respecto al coche a lo largo (km/h; + de cara, − cuando un viento de cola va más deprisa que el coche), de lado y en
## total, las mismas componentes que usa MovingCar.at_speed (v_x = v + viento de cara, v_lateral = viento lateral; el golpe
## no lleva viento: solo el coche), y, de cada zona de MovingCar.ZONES, su punto del dibujo (draw, 0-1) y su factor de
## velocidad local v_local/v = √(1 − Cp) (MovingCar.local_factor con el Cp de la zona), con la calidad y la fuente de ese
## Cp. { alongKmh, crossKmh, airKmh, zones: [{ id, x, y, cp, factor, quality, source }] }.
func air_flow() -> Dictionary:
	var v := maxf(v_kmh, 0.0)
	var along := v
	var cross := 0.0
	if mode == MODE_HOLD:
		along = v + wind_kmh
		cross = crosswind_kmh
	var zones: Array = []
	for id: String in MovingCar.ZONES:
		var z: Dictionary = MovingCar.ZONES[id]
		zones.append({ "id": id, "x": float(z.draw.x), "y": float(z.draw.y), "cp": float(z.cp.value),
			"factor": MovingCar.local_factor(float(z.cp.value)), "quality": z.cp.quality, "source": z.cp.source })
	return { "alongKmh": along, "crossKmh": cross, "airKmh": sqrt(along * along + cross * cross), "zones": zones }


# ════════ Para entenderlo: por qué, ¿sabías que…?, moraleja y sonido ════════
# Frases con los números de MovingCar (at_speed, detach, impact), de ClawsV2, de ClawFracture y del catálogo: ni un dato
# nuevo.

## «el águila real», «la lechuza común», «el tigre»: el animal elegido con su artículo.
func animal_the() -> String:
	return "%s %s" % [_grammar()[0], animal_name().to_lower()]


## «un águila real», «una lechuza común».
func animal_a() -> String:
	return "%s %s" % ["una" if _grammar()[0] == "la" else "un", animal_name().to_lower()]


## «al tigre», «a la lechuza común».
func _to_animal() -> String:
	return ("al %s" % animal_name().to_lower()) if _grammar()[0] == "el" else ("a la %s" % animal_name().to_lower())


func _grammar() -> Array:
	return GRAMMAR.get(String(claw.id) if claw != null else "", ["el", "o"])


## Pronombre del animal: «la suelta» (el águila, la lechuza) o «lo suelta».
func _pro() -> String:
	return "la" if _grammar()[1] == "a" else "lo"


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## La calidad de un dato para empezar una frase: «Dato medido», «Dato de un caso parecido», «Estimación» ("" sin calidad).
static func quality_title(q: String) -> String:
	return _cap(String(QUALITY_TEXT.get(q, "")))


## Lo que lo sujeta en su zona, con el verbo concordado: { txt, da } («el roce de sus dedos» da; «sus garras
## enganchadas» dan).
func _holder() -> Dictionary:
	if Js.truthy(scen.get("embedded")):
		return { "txt": "sus garras clavadas en %s" % ("la chapa" if Js.truthy(target.body.get("metal")) else "el plástico"), "da": "dan" }
	match String(scen.get("anchor", "friccion")):
		"agarre":
			return { "txt": "el agarre de sus dedos", "da": "da" }
		"gancho":
			return { "txt": "sus garras enganchadas", "da": "dan" }
	var rake: Variant = scen.get("defense").get("rakeN") if scen.get("defense") != null else null
	if rake != null and float(rake.value) > 0.0:
		return { "txt": "el roce de sus %s y el arado de sus garras" % _toes(), "da": "dan" }
	return { "txt": "el roce de sus %s" % _toes(), "da": "da" }


## Con qué toca el panel: los dedos de un ave o de un velocirraptor (sus pies son los de un ave); las patas de un mamífero.
func _toes() -> String:
	return "dedos" if kind() == "ave" or kind() == "teropodo" else "patas"


## Sus garras en una frase: { txt, pl } («la queratina de sus garras», «sus garras de zafiro», «su daga de diamante»; pl:
## el verbo en plural).
func _claws() -> Dictionary:
	var dagger := is_kicker()
	if not reforged():
		if film():
			return { "txt": "sus garras de película", "pl": true }
		return { "txt": "la queratina de su daga" if dagger else "la queratina de sus garras", "pl": false }
	var noun := String(ClawFracture.NOUNS.get(inlay, inlay))
	return { "txt": ("su daga de %s" if dagger else "sus garras de %s") % noun, "pl": not dagger }


## Dureza de las garras (HV): la del material reforjado o la de la queratina del catálogo.
func _claw_hv() -> float:
	return float(inlay_entry().hv) if reforged() else float(ClawsV2.apply(claw).hv)


## Verbo en singular o en plural.
static func _v(pl: bool, one: String, many: String) -> String:
	return many if pl else one


## Una parte con su decimal cuando es pequeña: «55 %», «3 %», «0.4 %», «<0.1 %» (CarFormat.fmt_share).
static func fmt_share(x: float) -> String:
	return CarFormat.fmt_share(x)


## El despegue en palabras cortas: «ni parado se sostiene», «no se suelta ni a 400 km/h», «se suelta a ~196 km/h» o, si
## solo aguanta más deprisa (una ventana), «solo aguanta por encima de ~63 km/h» o «solo aguanta entre ~150 y ~305 km/h».
## flies (unidad 4o): un ave con las alas abiertas que despega (d.mode «despega»): «despega a ~24 km/h», como su veredicto.
static func det_words(d: Dictionary, flies := false) -> String:
	if d.get("holdFromKmh") != null:
		var to: float = d.holdToKmh
		if is_inf(to):
			return "solo aguanta por encima de ~%s" % fmt_kmh(d.holdFromKmh)
		return "solo aguanta entre ~%s y ~%s" % [Js.to_fixed(float(d.holdFromKmh), 0), fmt_kmh(to)]
	if not d.atRest:
		return "ni parado se sostiene"
	if d.never:
		return "no se suelta ni a %s" % fmt_kmh(BAND_MAX_KMH)
	if flies and String(d.get("mode", "")) == "despega":
		return "despega a ~%s" % fmt_kmh(d.kmh)
	return "se suelta a ~%s" % fmt_kmh(d.kmh)


## ¿Por qué? Una frase clara con lo que lo suelta (el viento, la frenada, la sustentación, la curva o la pendiente) y
## los números de MovingCar en ese punto (at_detach: donde se suelta, o con el coche parado si ni parado se sostiene);
## asustado, con el despegue sin asustarse al lado. En el golpe: por qué agrieta o no el parabrisas, por qué atraviesa el
## plástico, por qué unas garras cortan o no el metal (y si se rompen), la patada del casuario y por qué abolla. "" sin
## datos.
func why_text() -> String:
	if not supported():
		return ""
	if mode == MODE_IMPACT:
		return _why_impact()
	if not Js.truthy(scen.get("ok")) or det.is_empty() or at.is_empty():
		return ""
	var txt := _curve_skid_why() if curve_on() and bool(det.get("skidsFirst", false)) else _why_hold()
	if glass_why() != "":
		txt = glass_why()  # unidad 4v: la luneta estalla bajo el animal
	if defense and not det_rest.is_empty():
		var now := det_words(det, kind() == "ave")
		var rest := det_words(det_rest, kind() == "ave")
		txt += (" Asustad%s, %s (sin asustarse, %s)." % [_grammar()[1], now, rest]) if now != rest else (
			" Asustad%s, lo mismo que sin asustarse: %s." % [_grammar()[1], now])
	return txt


func _why_hold() -> String:
	var h := _holder()
	var pro := _pro()
	if det.never:
		return "Nada %s suelta: ni a %s, el tope de la búsqueda, puede el aire con %s. A %s hacen falta %s para sujetar%s y %s %s %s." % [
			pro, fmt_kmh(BAND_MAX_KMH), h.txt, fmt_kmh(at.vKmh), fmt_n(at.needN), pro, h.txt, h.da, fmt_n(at.availN)]
	var a := at_detach
	# una ventana dentro del deslizador (solo aguanta más deprisa): lo que lo suelta es lo que pasa al bajar de
	# holdFromKmh. Si empieza más allá del deslizador, se explica como «ni parado» y se dice desde dónde aguantaría
	var window := window_in_slider()
	var at_rest: bool = not det.atRest and not window
	var edge: float = float(det.holdFromKmh) if window else float(det.kmh)
	# dónde: «a ~196 km/h» (o nada si ni parado se sostiene: la frase ya dice «aun con el coche parado»)
	var at_v := "" if at_rest else "a ~%s" % fmt_kmh(edge)
	var lead := "" if at_rest else at_v + " "
	var cause := ""
	var detail := ""
	match String(det.mode):
		"despega":
			if kind() == "ave":
				var wings := posture == "abiertas"
				cause = "su propia sustentación"
				# unidad 4o: despega cuando la sustentación ya sostiene la mitad de su peso; si aún no llega a todo el peso, le
				# queda algo de apoyo (el roce que se dice después), no se queda sin él
				var support := "se queda sin apoyo" if float(a.liftN) >= float(a.weightN) else "le queda muy poco apoyo"
				detail = "%s%s ya %s %s hacia arriba frente a %s de peso: %s y vuela" % [lead,
					"sus alas abiertas" if wings else "su cuerpo", "dan" if wings else "da", fmt_n(a.liftN), fmt_n(a.weightN), support]
			else:
				cause = "la sustentación de su lomo"
				detail = "%sya da %s hacia arriba y le quita el apoyo de sus %s de peso" % [lead, fmt_n(a.liftN), fmt_n(a.weightN)]
		"delante":
			if accel_g < 0.0:
				cause = "la frenada"
				detail = "frenar a %s %s empuja hacia delante con %s" % [fmt_g(-accel_g), pro, fmt_n(absf(a.inertiaN))]
				if not at_rest:
					detail += " y, %s, el aire solo le devuelve %s hacia atrás" % [at_v, fmt_n(a.dragN)]
			else:
				cause = "el viento de cola"
				detail = "%sel aire %s empuja hacia delante con %s" % [lead, pro, fmt_n(a.dragN)]
		"abajo":
			cause = "la pendiente de %s" % String(ZONE_ARTICLE.get(zone, zone_name(zone).to_lower()))
			detail = "en sus %s°, su peso y el aire tiran panel abajo con %s" % [num(float(scen.slopeDeg)), fmt_n(a.needN)]
		"lado":
			var curve := lateral_g > 0.0 or curve_on()
			var cross := crosswind_kmh > 0.0
			cause = "la curva y el viento lateral" if curve and cross else ("la curva" if curve else "el viento lateral")
			if curve:
				# unidad 4t: en curva, la aceleración lateral del despegue (v²/R, sin pasar del tope del coche)
				var lat_g := absf(float(a.curve.latG)) if a.has("curve") else lateral_g
				detail = "tomar la curva a %s %s empuja hacia fuera con %s" % [fmt_g(lat_g), pro, fmt_n(absf(a.lateralN))]
			else:
				detail = "%sel viento de %s %s empuja de lado" % [lead, fmt_kmh(crosswind_kmh), pro]
		_:
			if accel_g > 0.0:
				cause = "la aceleración"
				detail = "acelerar a %s %s empuja hacia atrás con %s" % [fmt_g(accel_g), pro, fmt_n(a.inertiaN)]
				if not at_rest:
					detail += " y, %s, el aire con %s más" % [at_v, fmt_n(a.dragN)]
			else:
				cause = "el viento"
				detail = "%sel aire le pasa a %s y %s empuja hacia atrás con %s" % [lead, fmt_kmh(a.localKmh), pro, fmt_n(a.dragN)]
				if String(scen.anchor) == "friccion" and float(a.liftN) >= 0.1 * float(a.weightN):
					detail += ", y su cuerpo sustenta %s que le quitan apoyo" % fmt_n(a.liftN)
	if at_rest:
		var txt := "%s tira %s, aun con el coche parado: %s; %s solo %s %s." % [_cap(pro), cause, detail, h.txt, h.da, fmt_n(a.availN)]
		if det.get("holdFromKmh") != null:
			txt += " Solo por encima de ~%s aguantaría: %s." % [fmt_kmh(det.holdFromKmh), MovingCar.window_saver(scen, det)]
		elif det.mode == "delante" and accel_g < 0.0 and at.holds and float(at.vKmh) > 0.0:
			txt += " A %s sí aguanta: el aire %s empuja hacia atrás con %s y compensa parte de la frenada." % [
				fmt_kmh(at.vKmh), pro, fmt_n(at.dragN)]
		return txt
	# unidad 4o: lo que despega no se suelta, lo levanta (como dicen sus veredictos: «despega», «lo levanta el aire»)
	var verb := "levanta" if String(det.mode) == "despega" else "suelta"
	if window:
		var below := "al bajar de" if det.mode == "delante" and accel_g < 0.0 else "por debajo de"
		return "%s %s %s %s ~%s: %s; %s ya no %s más (%s).%s" % [_cap(pro), verb, cause, below, fmt_kmh(edge), detail, h.txt,
			h.da, fmt_n(a.availN), _window_why()]
	var head := ("%s %s %s" % [_cap(pro), verb, cause]) if not det.beyond else (
		"Lo que acabaría %s es %s, fuera del deslizador" % [("levantándo" if verb == "levanta" else "soltándo") + pro, cause])
	return "%s: %s; %s ya no %s más (%s)." % [head, detail, h.txt, h.da, fmt_n(a.availN)]


## ¿Solo aguanta en una ventana que empieza dentro del deslizador (0-SLIDER_MAX_KMH)? (MovingCar.detach: holdFromKmh)
func window_in_slider() -> bool:
	return not det.is_empty() and det.get("holdFromKmh") != null and float(det.holdFromKmh) <= slider_max_kmh()


## Qué lo sujeta más deprisa cuando solo aguanta en una ventana (MovingCar.detach: holdFromKmh), y hasta dónde.
func _window_why() -> String:
	var to: float = det.holdToKmh
	var until := (": no se suelta ni a %s" % fmt_kmh(BAND_MAX_KMH)) if is_inf(to) else (
		" hasta ~%s, donde %s" % [fmt_kmh(to), MovingCar.window_end(scen, String(det.holdToMode))])
	return " Más deprisa, %s%s." % [MovingCar.window_saver(scen, det), until]


func _why_impact() -> String:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return ""
	var sw: Variant = hit.get("sideWindow")
	if sw != null:
		return _why_window(sw)  # unidad 4m: la ventanilla templada
	var sh: Variant = hit.get("windshield")
	if sh != null:
		if sh.cracked and float(sh.peakN) < float(sh.bendN):
			# lo agrietan por contacto unas garras reforjadas, antes de que la hoja se parta al flexar
			var cl := _claws()
			return "Se agrieta porque %s (%s HV) %s el vidrio y lo %s por contacto: cada apoyo solo llega con ~%s, menos de los ~%s que lo parten al flexar. La lámina de PVB sujeta los trozos: no cae." % [
				cl.txt, num(_claw_hv()), _v(cl.pl, "raya", "rayan"), _v(cl.pl, "agrieta", "agrietan"), fmt_n(sh.peakN), fmt_n(sh.bendN)]
		if sh.cracked:
			return "Se agrieta porque cada apoyo llega con ~%s y la hoja de vidrio se parte al flexar desde ~%s; la lámina de PVB sujeta los trozos: no cae." % [
				fmt_n(sh.peakN), fmt_n(sh.bendN)]
		return "Aguanta porque cada apoyo llega con ~%s, menos de los ~%s que parten la hoja al flexar." % [fmt_n(sh.peakN), fmt_n(sh.bendN)]
	var txt := ""
	var dn: Variant = hit.get("dent")
	var k: Variant = hit.get("kick")
	if k != null:
		txt = "Patea: salta con los pies por delante a ~%s y su pata no pasa de ~%s, %s veces su peso" % [
			fmt_kmh(k.leapKmh), fmt_n(k.forceCapN), num(float(k.forceBw))]
		if dn != null and dn.applies and dn.visible:
			txt += "; la chapa se abolla ~%s bajo el pie%s" % [Format.fmt_len(float(dn.depthMm) * 1000.0),
				" (la pata llega a su fuerza máxima)" if Js.truthy(dn.get("capped")) else ""]
		txt += ". "
	var lp: Variant = hit.get("leap")
	if lp != null:
		txt = _leap_why(lp)
	txt += _why_cut()
	if k == null and dn != null and dn.applies and dn.visible and dn.collapseN != null:
		txt += " Y abolla porque el golpe contra el panel lleva %s: cada apoyo empuja con ~%s y la chapa cede desde ~%s." % [
			MovingCar.fmt_energy(hit.normalJ), fmt_n(dn.peakN), fmt_n(dn.collapseN)]
	if kind() == "teropodo":
		txt += _raptor_contrast()
	return txt


## El porqué del golpe contra la ventanilla templada (unidad 4m; MovingCar.side_window_impact): cómo llega a ella y si
## estalla al flexar, por una grieta que atraviesa la capa comprimida o aguanta.
func _why_window(sw: Dictionary) -> String:
	var txt := ""
	var lp: Variant = hit.get("leap")
	if lp != null and Js.truthy(lp.get("window")):
		txt = "Salta para llegar: corre a ~%s y sus pies suben ~%s, por encima de la cintura del coche (~%s); golpea en lo alto del salto, con su carrera. " % [
			fmt_kmh(float(lp.runKmh)), CarFormat.fmt_m(float(lp.hitM), 2), CarFormat.fmt_m(float(lp.sillM), 2)]
	var temper := num(float(MovingCar.Glazing.SIDE_WINDOW.frac.sigmaS))
	var bits := CarFormat.fmt_long(float(sw.fragmentMm) * 1000.0)
	var cl := _claws()
	var hv := num(float(sw.tipHv))
	var glass_hv := num(float(sw.glassHv))
	if Js.truthy(sw.shattered) and sw.cause == "grieta":
		return txt + "Estalla porque %s (%s HV), al menos tan %s como el vidrio (%s HV), %s una grieta que atraviesa la capa comprimida (~%s) con ~%s por garra: bastan ~%s, y el golpe no la partiría al flexar (~%s por apoyo contra ~%s). Toda la tensión del temple (~%s MPa de compresión en las caras) se libera de golpe y la luna entera se deshace en trocitos de ~%s." % [
			cl.txt, hv, _v(cl.pl, "dura", "duras"), glass_hv, _v(cl.pl, "abre", "abren"), CarFormat.fmt_long(float(sw.compressionMm) * 1000.0), fmt_n(sw.perClawN),
			fmt_n(sw.pierceN), fmt_n(sw.peakN), fmt_n(sw.bendN), temper, bits]
	if Js.truthy(sw.shattered):
		return txt + "Estalla porque cada apoyo llega con ~%s y el templado se parte al flexar desde ~%s: en cuanto se rompe, la tensión del temple (~%s MPa de compresión en las caras) se libera de golpe y la luna entera se deshace en trocitos de ~%s, romos y sin filo." % [
			fmt_n(sw.peakN), fmt_n(sw.bendN), temper, bits]
	var tail: String
	if not Js.truthy(sw.hardTip):
		tail = ", y %s (%s HV), más %s que el vidrio (%s HV), no %s abrir la grieta que la reventaría" % [
			cl.txt, hv, _v(cl.pl, "blanda", "blandas"), glass_hv, _v(cl.pl, "puede", "pueden")]
	else:
		tail = ", y %s, aunque duras, no llegan a los ~%s por garra que abrirían la grieta que la reventaría (llevan ~%s)" % [
			cl.txt, fmt_n(sw.pierceN), fmt_n(sw.perClawN)]
	return txt + "Aguanta porque cada apoyo llega con ~%s, menos de los ~%s que parten el templado al flexar%s." % [fmt_n(sw.peakN), fmt_n(sw.bendN), tail]


## El salto de un velocirraptor en el porqué (MovingCar.leap_block): de dónde llega y a qué velocidad.
func _leap_why(lp: Dictionary) -> String:
	var run := "corre a ~%s" % fmt_kmh(float(lp.runKmh))
	if Js.truthy(lp.get("runCapped")) and CarFormat.kmh_txt(float(lp.runAskedKmh)) != CarFormat.kmh_txt(float(lp.runMaxKmh)):
		run = "corre como mucho a ~%s (lo más que corre; no a %s)" % [fmt_kmh(float(lp.runMaxKmh)), fmt_kmh(float(lp.runAskedKmh))]
	if Js.truthy(lp.side):
		return "Se abalanza: %s y choca contra %s, que está a la altura de su cuerpo. " % [run, String(ZONE_ARTICLE.get(impact_zone, impact_zone))]
	var air := "menos de 0.1 km/h" if float(lp.airLossKmh) < 0.05 else "~" + CarFormat.fmt_kmh1(float(lp.airLossKmh))
	return "Salta desde la carretera: %s, salta a %s, sube ~%s y cae sobre %s (a ~%s) a ~%s de bajada; el aire solo le quita %s en el vuelo. " % [
		run, CarFormat.fmt_mps(float(lp.leapMs), 2), CarFormat.fmt_m(float(lp.reachM), 2), String(ZONE_ARTICLE.get(impact_zone, impact_zone)),
		CarFormat.fmt_m(float(lp.panelM), 2), CarFormat.fmt_mps(-float(lp.uz), 1), air]


## El contraste de siempre en los velocirraptores (unidad 4i-B2): la película frente a la reconstrucción, con los datos de la
## reconstrucción del catálogo (su masa y su queratina) y de su réplica (Manning et al. 2006).
func _raptor_contrast() -> String:
	var real: Variant = Catalog.find_by_id(Catalog.CLAWS, "velociraptor")
	if real == null:
		return ""
	var rep: Dictionary = real.dino.function.replica
	if film():
		return " En la película sus garras rajan la chapa; el Velociraptor de verdad pesaba ~%s kg, del tamaño de un pavo, con plumas, y pinchaba y sujetaba a la presa con su peso (Manning 2006; Fowler 2011): su queratina, de %s HV, no corta el acero." % [
			num(float(real.mass)), num(float(real.hv))]
	return " Sus garras falciformes pinchan y sujetan, no rajan: una réplica robótica solo hizo punciones redondas de %s-%s cm, nunca un tajo (Manning 2006), y el animal sujetaba a la presa con su peso (Fowler 2011)." % [
		num(float(rep.punctureMm.min) / 10.0), num(float(rep.punctureMm.max) / 10.0)]


## Por qué las garras cortan o no el panel (y, reforjadas, si se rompen al resbalar).
func _why_cut() -> String:
	var body: Dictionary = target.body
	var cl := _claws()
	var hv := num(_claw_hv())
	var pn: Variant = hit.get("puncture")
	var marks: Dictionary = hit.marks
	if not Js.truthy(body.get("metal")):
		if pn != null and pn.through:
			return "Lo %s porque el %s de la aleta (%s HV) es más blando que %s (%s HV): %s como en la pintura." % [
				_v(cl.pl, "atraviesa", "atraviesan"), body.long, num(float(body.hv)), cl.txt, hv, _v(cl.pl, "entra", "entran")]
		return "%s (%s HV) %s más %s que el %s de la aleta (%s HV), pero este golpe no basta para atravesarlo." % [
			_cap(cl.txt), hv, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), body.long, num(float(body.hv))]
	if not MovingCar.can_cut_body(inlay_entry(), target, claw):
		var txt := "No perfora porque %s (%s HV) %s más %s que el %s de la chapa (%s HV): por debajo de %s veces la dureza del metal, cede la punta." % [
			cl.txt, hv, _v(cl.pl, "es", "son"), _v(cl.pl, "blanda", "blandas"), body.long, num(float(body.hv)),
			num(float(Physics.MODEL.rOff))]
		if int(marks.count) > 0:
			txt += " La pintura (%s HV), en cambio, sí se raya." % num(float(target.hv))
		return txt
	var how := "la %s al resbalar" % _v(cl.pl, "raja", "rajan") if String(marks.verdict).begins_with("RAJA") else (
		"la %s" % _v(cl.pl, "atraviesa", "atraviesan") if pn != null and pn.through else "%s en ella" % _v(cl.pl, "entra", "entran"))
	var txt := "%s (%s HV) sí %s el %s de la chapa (%s HV): con más de %s veces la dureza del metal, %s." % [
		_cap(cl.txt), hv, _v(cl.pl, "corta", "cortan"), body.long, num(float(body.hv)), num(float(Physics.MODEL.rOff)), how]
	var frac: Variant = hit.get("clawFracture")
	if frac != null and String(frac.vsub) != "":
		txt += " Pero la chapa también empuja: %s." % String(frac.vsub)
	return txt


## «¿Sabías que…?»: datos reales del ensayo que se ve, cada uno con su fuente y su calidad: [{ text, source, quality }].
## Los números salen de MovingCar, de ClawsV2, de ClawFracture y del catálogo; la tarjeta enseña uno y deja pasar al
## siguiente.
func facts() -> Array:
	if not supported():
		return []
	var out: Array = []
	var body: Dictionary = MovingCar.body_of(claw)
	var c2 := ClawsV2.apply(claw)
	if mode == MODE_HOLD:
		if Js.truthy(scen.get("ok")):
			_facts_hold(out, body, c2)
	elif not hit.is_empty() and Js.truthy(hit.get("ok")):
		_facts_impact(out, body, c2)
	return out


func _fact(text: String, source: String, quality: String) -> Dictionary:
	return { "text": text, "source": source, "quality": quality }


## Los del animal quieto encima, primero los que responden a lo que se acaba de cambiar (el aire, las alas, el miedo, el
## material de las garras).
func _facts_hold(out: Array, body: Dictionary, c2: Dictionary) -> void:
	var still := wind_kmh == 0.0 and crosswind_kmh == 0.0
	if curve_on():
		_curve_facts(out)  # unidad 4t
	if body.kind == "teropodo":
		_raptor_facts(out, c2)
	if custom_air():
		out.append(_fact("Con este aire (%s) todo lo que empuja el aire baja en la misma proporción: sin viento, la velocidad a la que se suelta se multiplica por %s." % [
			air_txt, Js.to_fixed(float(scen.air.speedFactor), 3)], scen.air.source, scen.air.quality))
	if body.kind == "ave" and posture == "abiertas" and not det.is_empty() and det.atRest and det.mode == "despega":
		var w: Dictionary = MovingCar.BIRD_AERO.wing.sustenta
		out.append(_fact("Con las alas abiertas, %s despega a ~%s de coche: con el coeficiente de sustentación más alto medido en planeo (CL %s), sus alas %s sostienen con muy poco viento." % [
			animal_the(), fmt_kmh(det.kmh), num(float(w.cl)), _pro()], MovingCar.SRC_TUCKER_HEINE, w.quality))
	var dfn: Variant = scen.get("defense")
	if dfn != null:
		out.append(_defense_fact(dfn))
	if reforged() and can_embed():
		out.append(_strength_fact())
	var mf := _marks_fact()
	if not mf.is_empty():
		out.append(mf)
	if not at.is_empty() and float(at.vKmh) > 0.0:
		var lf: float = scen.localFactor
		var cp: Dictionary = MovingCar.ZONES[zone].cp
		var where := String(ZONE_ARTICLE.get(zone, zone_name(zone).to_lower()))
		var ref := ("con el coche a %s" % fmt_kmh(at.vKmh)) if still else ("con el aire relativo a %s" % fmt_kmh(at.airKmh))
		if lf > 1.0:
			out.append(_fact("En %s el aire va más deprisa que el coche: %s, pasa a %s (Cp %s)." % [where, ref, fmt_kmh(at.localKmh), num(float(scen.cp))],
				cp.source, cp.quality))
		elif lf < 1.0:
			out.append(_fact("En %s el aire se remansa: %s, pasa a %s (Cp %s)." % [where, ref, fmt_kmh(at.localKmh), num(float(scen.cp))],
				cp.source, cp.quality))
		var aero := _aero_info()
		var power := ("le roba %s al motor" % fmt_w(at.powerW)) if float(at.powerW) >= 0.0 else (
			"hace de vela: le ahorra %s al motor" % fmt_w(absf(at.powerW)))
		out.append(_fact("A %s, %s añade %s de resistencia, el %s de la de todo el coche (%s), y %s." % [
			fmt_kmh(at.vKmh), animal_the(), fmt_n(at.dragN), fmt_share(at.dragShare), fmt_n(at.carDragN), power],
			"coche: %s; animal: %s" % [MovingCar.CAR_REF.source, aero.source], aero.quality))
	if (body.kind == "ave" or body.kind == "teropodo") and dfn == null:
		# el agarre de un pie: el de las rapaces corregido (ClawsV2) o el de la ficha de un velocirraptor (grip_band)
		var o: Variant = ClawsV2.override_of(c2, "force")
		if o != null or body.kind == "teropodo":
			var gb := MovingCar.grip_band(c2)
			var gs := MovingCar.grip_source(c2)
			out.append(_fact("Un pie de %s aprieta con ~%s (banda de %s a %s según los datos)." % [animal_name().to_lower(), fmt_n(gb.value),
				fmt_n(gb.min), fmt_n(gb.max)], gs.source, gs.quality))
	out.append(_hardness_fact(c2))
	if not custom_air():
		var high := MovingCar.air_of(float(MovingCar.PARAMS.temp_c.default), float(MovingCar.PARAMS.altitude_m.max))
		out.append(_fact("En la montaña el aire pesa menos: %s." % MovingCar.air_txt(high), high.source, high.quality))
	if scen.get("windshield") != null:
		out.append(_fact("El parabrisas es vidrio laminado: se agrieta con facilidad, pero la lámina de PVB sujeta los trozos y no cae.",
			String(Glazing.WINDSCREEN.source), "secondary"))
	out.append_array(glass_facts())  # unidad 4v
	var emer := _maneuver("emergencia")
	if not emer.is_empty():
		var hold_g := ""
		if report_matches_setup() and report.has("brakingG"):
			var g := float(report.brakingG)
			var at_v := fmt_kmh(float(report.at.vKmh))
			if curve_on() and not at.is_empty():
				g = _curve_braking_g()  # unidad 4t
				at_v = fmt_kmh(v_kmh)
			if g <= 0.0:
				hold_g = " A %s, %s ni sin frenar aguanta." % [at_v, animal_the()]
			elif g >= MovingCar.BRAKING_TOP_G:
				hold_g = " A %s, %s aguanta cualquiera (más de %s)." % [at_v, animal_the(), fmt_g(MovingCar.BRAKING_TOP_G)]
			else:
				hold_g = " A %s, %s aguanta hasta %s (caso central)." % [at_v, animal_the(), CarFormat.fmt_g_max(g)]
		out.append(_fact("Una frenada de emergencia son ~%s: lo que da el agarre de los neumáticos en asfalto seco.%s" % [
			fmt_g(-float(emer.accel_g)), hold_g], emer.source, emer.quality))
	if body.has("run_kmh"):
		var run: Dictionary = body.run_kmh
		out.append(_fact("%s corre a ~%s." % [_cap(animal_the()), fmt_kmh(float(run.value))], run.source, run.quality))


func _facts_impact(out: Array, body: Dictionary, c2: Dictionary) -> void:
	var swf: Variant = hit.get("sideWindow")
	if swf != null:
		_window_facts(out, swf)  # unidad 4m: lo primero, lo de la ventanilla templada
	var k: Variant = hit.get("kick")
	var lp: Variant = hit.get("leap")
	if lp != null:
		out.append(_fact("Salta a %s, con cualquier masa: el mismo salto que la patada del casuario (el trabajo por kilo de músculo de un ave y la masa muscular de la pata de un avestruz). Sube ~%s; al techo, a ~%s, no llega (con los datos más favorables, %s, subiría ~%s)." % [
			CarFormat.fmt_mps(float(lp.leapMs), 2), CarFormat.fmt_m(float(lp.reachM), 2), CarFormat.fmt_m(float(MovingCar.ROOF_M.value), 2),
			CarFormat.fmt_mps(float(lp.leapMaxMs), 2), CarFormat.fmt_m(float(lp.reachMaxM), 2)],
			String(MovingCar.KICK.work_j_per_kg.source) + "; " + String(MovingCar.KICK.muscle_fraction.source) + "; altura del techo: " + String(MovingCar.ROOF_M.source),
			MovingCar.KICK.work_j_per_kg.quality))
	if body.kind == "teropodo":
		_raptor_facts(out, c2)
	var tr: Variant = hit.get("tear")
	if tr != null:
		out.append(_tear_fact(tr))
	if k != null:
		out.append(_fact("Salta con los pies por delante a ~%s, con cualquier masa: el salto no depende del tamaño (el trabajo de sus músculos crece con su masa)." % [
			fmt_kmh(k.leapKmh)], String(MovingCar.KICK.work_j_per_kg.source) + "; " + String(MovingCar.KICK.muscle_fraction.source),
			MovingCar.KICK.work_j_per_kg.quality))
		var fb: Dictionary = MovingCar.KICK.force_bw
		out.append(_fact("Su pata aguanta ~%s: %s veces su peso (de %s a %s), lo que se ha medido en la patada del secretario." % [
			fmt_n(k.forceCapN), num(float(fb.value)), num(float(fb.min)), num(float(fb.max))], fb.source, fb.quality))
		if body.has("mass_kg"):
			var ms: Dictionary = body.mass_kg
			out.append(_fact("La hembra pesa %s kg (hasta %s) y el macho, %s kg (de %s a %s): la fuerza de su pata va con su peso." % [
				num(float(ms.hembra.value)), num(float(ms.hembra.max)), num(float(ms.macho.value)), num(float(ms.macho.min)),
				num(float(ms.macho.max))], "hembra: %s · macho: %s" % [ms.hembra.source, ms.macho.source], ms.macho.quality))
		# una observación, no una medida: sin etiqueta de calidad, con su fuente
		out.append(_fact("Patea puertas y persigue coches: asocia a sus ocupantes con comida.", MovingCar.SRC_NAISH + "; " + MovingCar.SRC_BORRELL, ""))
		out.append(_fact("Al revés, sí hay datos: los coches son la primera causa de muerte del casuario del sur.", MovingCar.SRC_KOFRON_CHAPMAN,
			"primary"))
	# primero, lo propio del experimento: el animal asustado y lo que aguanta el material de las garras (solo si corta el
	# panel: una garra más blanda que la chapa ni la corta ni se rompe)
	var dfi: Variant = hit.get("defense")
	if dfi != null and k == null:
		out.append(_defense_fact(dfi))
	if reforged() and MovingCar.can_cut_body(inlay_entry(), target):
		out.append(_strength_fact())
	var best: Dictionary = {}
	for t: Dictionary in hit.energy.terms:
		if best.is_empty() or float(t.share) > float(best.share):
			best = t
	if not best.is_empty() and float(hit.energy.totalJ) > 0.0:
		out.append(_fact("¿A dónde va la energía del golpe? La mayor parte, el %s de %s: %s." % [fmt_share(best.share),
			MovingCar.fmt_energy(hit.energy.totalJ), String(best.name).substr(0, 1).to_lower() + String(best.name).substr(1)], best.source, best.quality))
	if k == null:
		out.append(_fact("Lo que cuenta es la velocidad relativa: %s a %s contra un coche a %s llega a %s respecto a él, con %s." % [
			animal_the(), fmt_kmh(animal_kmh), fmt_kmh(v_kmh), fmt_kmh(hit.vRelKmh), MovingCar.fmt_energy(hit.energyJ)], SRC_KINEMATICS, ""))
	out.append(_hardness_fact(c2))
	var sh: Variant = hit.get("windshield")
	var iz: Dictionary = MovingCar.IMPACT_ZONES[impact_zone]
	if sh != null:
		out.append(_fact("La homologación del laminado solo garantiza que no lo atraviese un golpe de %s J; este lleva %s contra el cristal." % [
			Js.to_fixed(float(sh.penetrationJ), 1), MovingCar.fmt_energy(sh.energyJ)],
			"JIS R 3212 / CEPE R43: el ensayo de penetración del laminado, con una bola de 2260 g desde 4 m", "secondary"))
	elif not iz.glass:
		# unidad 4o: y la punta de unas garras que atraviesan el panel tampoco entra más
		var pn: Variant = hit.get("puncture")
		var through: bool = Js.truthy(hit.marks.get("through")) or (pn != null and Js.truthy(pn.get("through")))
		var dn: Variant = hit.get("dent")
		var dents: bool = dn != null and Js.truthy(dn.get("applies"))
		var pron := "la" if String(target.body.noun).begins_with("la") else "lo"
		var claw_txt := "la punta de unas garras que %s atraviesan no puede entrar más" % pron
		var why := "la abolladura no puede ser más honda"
		if through and dents:
			# unidad 4p: la punta y la abolladura comparten el hueco (las garras están en el apoyo que abolla la chapa)
			var dent_um := float(dn.depthMm) * 1000.0
			var noun := String(target.body.noun)
			why = "lo comparten la abolladura, que no puede ser más honda, y la punta de unas garras que atraviesan %s" % noun
			if dent_um >= 100.0:
				why += "; donde se apoya, con %s hundida ~%s, a la punta le quedan ~%s por debajo" % [noun, MovingCar.fmt_long(dent_um),
					MovingCar.fmt_long(maxf(float(iz.clearance_mm) * 1000.0 - dent_um, 0.0))]
		elif through:
			why = claw_txt  # el plástico no se abolla: se hunde y recupera
		if dents or through:
			out.append(_fact("%s %s hay ~%s mm de hueco: %s." % [
				"Bajo" if iz.normal == "arriba" else "Detrás de", String(ZONE_ARTICLE.get(impact_zone, impact_zone_name().to_lower())),
				num(float(iz.clearance_mm)), why], String(_clearance_source(iz).source), String(_clearance_source(iz).quality)))
	if body.has("run_kmh"):
		var run: Dictionary = body.run_kmh
		out.append(_fact("%s corre a ~%s." % [_cap(animal_the()), fmt_kmh(float(run.value))], run.source, run.quality))


## «¿Sabías que…?» de la ventanilla templada (unidad 4m), con los números del golpe (MovingCar.side_window_impact) y de la hoja
## del banco (Glazing.SIDE_WINDOW): el temple y sus trocitos, el punzón duro que la revienta con poca fuerza, hasta dónde llega
## el animal y la energía del temple que se libera al estallar.
func _window_facts(out: Array, sw: Dictionary) -> void:
	var W: Dictionary = MovingCar.Glazing.SIDE_WINDOW
	out.append(_fact("El templado guarda ~%s MPa de compresión en las caras y tracción en el centro: aguanta más que el vidrio normal, pero si una grieta atraviesa esa capa (~%s), estalla entero en %s." % [
		num(float(W.frac.sigmaS)), CarFormat.fmt_long(float(sw.compressionMm) * 1000.0), MovingCar.window_bits_txt(sw)], MovingCar.SRC_TEMPER, "estimate"))
	out.append(_fact("Un punzón duro y afilado lo revienta con poca fuerza: con la forma de estas garras, una punta al menos tan dura como el vidrio (%s HV) bastaría con ~%s, cuando partirlo al flexar pide ~%s por apoyo. Es el truco del martillo de emergencia." % [
		num(float(sw.glassHv)), fmt_n(sw.shapePierceN), fmt_n(sw.bendN)], MovingCar.SRC_PUNCH, "estimate"))
	var wr: Dictionary = MovingCar.window_reach(claw)
	match String(wr.how):
		"salta":
			out.append(_fact("Llega saltando: sus pies suben ~%s (con los datos más favorables, ~%s) y la ventanilla empieza a ~%s, en la cintura del coche." % [
				CarFormat.fmt_m(float(wr.hitM), 2), CarFormat.fmt_m(float(wr.hitMaxM), 2), CarFormat.fmt_m(float(wr.sillM), 2)], String(wr.source), String(wr.quality)))
		"cruz":
			var wh: Dictionary = MovingCar.WITHERS_M[claw.id]
			var txt := "A cuatro patas llega: su cruz está a ~%s (de %s a %s) y la ventanilla empieza a ~%s, en la cintura del coche." % [
				CarFormat.fmt_m(float(wh.value), 2), CarFormat.fmt_m(float(wh.min), 2), CarFormat.fmt_m(float(wh.max), 2), CarFormat.fmt_m(float(wr.sillM), 2)]
			var tiger: Dictionary = MovingCar.WITHERS_M.tigre
			if claw.id != "tigre":
				txt += " El tigre, con la cruz a ~%s (de %s a %s), se queda en la puerta." % [
					CarFormat.fmt_m(float(tiger.value), 2), CarFormat.fmt_m(float(tiger.min), 2), CarFormat.fmt_m(float(tiger.max), 2)]
			out.append(_fact(txt, String(wr.source), String(wr.quality)))
	if Js.truthy(sw.shattered):
		out.append(_fact("Al estallar se liberan ~%s guardados en el temple: no salen del golpe, y son los que lanzan los trocitos." % CarFormat.fmt_energy(float(sw.temperJ)),
			MovingCar.SRC_TEMPER + "; la hoja, de ~%s cm de radio equivalente (estimación)" % num(float(W.pane.a) / 10.0), "estimate"))


## Lo que cuesta rajar el plástico (unidad 4j, con el desgarro de la 4g): cada garra trabada abre una grieta de todo el
## espesor y pide F = R·t, la tenacidad del plástico por su espesor; y si aquí lo raja o se le sueltan las garras.
func _tear_fact(t: Dictionary) -> Dictionary:
	var n := int(t.claws)
	var txt := "Para rajar %s, cada garra trabada abre una grieta de todo el espesor y pide F = R·t = %s kJ/m² × %s ≈ %s: la energía por unidad de área que mide el péndulo de Charpy en el mismo plástico, por su espesor." % [
		String(ZONE_ARTICLE.get(impact_zone, impact_zone_name().to_lower())), num(float(t.toughnessKJm2.value)),
		Format.fmt_len(float(t.thicknessMm) * 1000.0), fmt_n(float(t.perClawN))]
	if not Js.truthy(t.holds):
		txt += " Con %d %s son ~%s, y %s solo aguanta ~%s: se le sueltan." % [n, "garra" if n == 1 else "garras", fmt_n(float(t.forceN)),
			animal_the(), fmt_n(float(t.anchorN.value))]
	elif float(t.lengthMm) > 0.0:
		var art := String(ZONE_ARTICLE.get(impact_zone, "la")).get_slice(" ", 0)
		txt += " Con %d %s, ~%s: aquí %s raja %s." % [n, "garra" if n == 1 else "garras", fmt_n(float(t.forceN)),
			"la" if art == "la" else "lo", MovingCar.fmt_long(float(t.lengthMm) * 1000.0)]
	return _fact(txt, String(t.source), String(t.quality))


## Los datos de los velocirraptores (unidad 4i-B2), con su fuente y su calidad: el de película, con lo que tiene de
## Deinonychus (dato) y lo que es de película (ficción); la reconstrucción, lo que hacía con la garra.
func _raptor_facts(out: Array, c2: Dictionary) -> void:
	var d: Variant = c2.get("dino")
	if not (d is Dictionary):
		return
	var mass: Dictionary = d.mass
	if film():
		out.append(_fact("Los raptores de la película tienen el tamaño de Deinonychus: Crichton basó en él los de la novela, y Gregory Paul lo metía en Velociraptor.",
			String(d.body.model.source), String(d.body.model.quality)))
		out.append(_fact("Su masa sale de su fémur, con el mismo escalado que la del de verdad: ~%s kg (de %s a %s según los datos)." % [
			num(float(mass.value)), num(float(mass.min)), num(float(mass.max))], String(mass.source), String(mass.quality)))
		var fc: Dictionary = d.fiction.claw
		out.append(_fact("Lo de película: su garra raja la chapa porque aquí es tan dura como la tachuela de acero del banco (%s HV). La de verdad, de queratina, no corta el acero de un coche." % num(float(fc.hv)),
			String(fc.source), String(fc.quality)))
		return
	var fn: Dictionary = d.function
	out.append(_fact("Una réplica robótica de su garra solo hizo punciones redondas de %s-%s cm en un cerdo, nunca un tajo: pinchaba y sujetaba." % [
		num(float(fn.replica.punctureMm.min) / 10.0), num(float(fn.replica.punctureMm.max) / 10.0)], String(fn.replica.source), String(fn.replica.quality)))
	var cm: Dictionary = d.forces.clawMuscle
	out.append(_fact("Su garra falciforme, movida solo por sus músculos, aprieta ~%s (hasta %s): lo que la clava es su peso, ~%s kg." % [
		fmt_n(cm.value), fmt_n(cm.max), num(float(mass.value))], String(cm.source), String(cm.quality)))


## Calidad y fuente de la masa del animal: la de su ficha si es un dinosaurio (dino.mass); si no, la del catálogo 1.x.
func _mass_source() -> Dictionary:
	var d: Variant = claw.get("dino") if claw != null else null
	if d is Dictionary and d.get("mass") is Dictionary:
		return { "quality": String(d.mass.quality), "source": String(d.mass.source) }
	return { "quality": "", "source": SRC_MASS }


## Asustado: con cuánta fuerza aprieta cada pie o mano (con su banda) y la presión en la punta de cada garra; en el tigre
## y el oso, de dónde sale (la sección de sus flexores por la tensión del músculo).
func _defense_fact(d: Dictionary) -> Dictionary:
	var f: Dictionary = d.forceN
	var txt := "Asustad%s, cada %s aprieta con ~%s (de %s a %s): ~%s MPa en la punta de cada garra" % [_grammar()[1], String(d.per),
		fmt_n(f.value), fmt_n(f.min), fmt_n(f.max), Format.fmt_p(float(d.tipPressureMPa))]
	txt += (", más de lo que aguanta la garra: la punta se aplasta y reparte." if Js.truthy(d.get("tipYields")) else ".")
	if String(d.get("kind", "")) == "flexores" and d.get("pcsaCm2") != null:
		txt += " Sale de la sección de sus flexores, %s cm², por la tensión del músculo, %s N/cm²." % [
			Js.to_fixed(float(d.pcsaCm2), 0), num(float(MovingCar.SPECIFIC_TENSION.value))]
	return _fact(txt, String(d.get("source", "")), String(d.get("quality", "")))


## Garras reforjadas: lo que aguanta su material antes de romperse (frágil) o de doblarse (dúctil), con su banda.
func _strength_fact() -> Dictionary:
	var s: Variant = ClawFracture.strength(inlay)
	var noun := String(ClawFracture.NOUNS.get(inlay, inlay))
	if s == null:
		var why := String(ClawFracture.UNKNOWN.get(inlay, ""))
		if why == "":
			return _fact("Las garras de %s no cortan la chapa: ceden por la punta, como la queratina." % noun,
				SRC_HARDNESS, "secondary")
		return _fact("De las garras de %s no se puede decir si se rompen: %s." % [noun, why], "sin un dato publicado de su resistencia: el modelo no lo predice", "")
	if s.kind == "fluencia":
		return _fact("El %s no estalla: fluye a ~%s MPa y se dobla antes de romperse." % [noun, Format.fmt_p(float(s.value))], s.source, s.quality)
	var band := "" if float(s.min) == float(s.max) else " (de %s a %s)" % [Format.fmt_p(float(s.min)), Format.fmt_p(float(s.max))]
	return _fact("El %s es frágil: aguanta ~%s MPa a flexión%s, con una tenacidad de %s MPa·√m, y se rompe sin doblarse. De frente no se rompe: lo rompe la carga de lado al resbalar." % [
		noun, Format.fmt_p(float(s.value)), band, num(float(s.kic))], s.source, s.quality)


## Unidad 4s: la rotura de las garras con la velocidad, como dato ({} sin curva o sin rotura en el deslizador).
func _marks_fact() -> Dictionary:
	var c := marks_curve()
	if c.is_empty() or c.breakAt == null or c.breakAt.kmh == null:
		return {}
	var br: Dictionary = c.breakAt
	var txt := "Las garras no las rompe lo que aprieta el animal, sino lo que tira de ellas de lado: %s (más fuerza de agarre, antes)." % CarSpeedMarks.break_txt(c, float(c.detachKmh))
	if Js.truthy(br.get("sizeEffect")):
		txt += " La sección más cargada es más pequeña que la distancia crítica del material: la punta real aguanta más de lo que dice la resistencia medida (el modelo se queda del lado seguro)."
	return _fact(txt, String(br.source), String(br.quality))


## Queratina (o el material reforjado) contra el panel: por qué corta o no el metal y por qué el plástico sí; en el
## parabrisas, contra el vidrio.
func _hardness_fact(_c2: Dictionary) -> Dictionary:
	var body: Dictionary = target.body
	var cl := _claws()
	var hv := _claw_hv()
	var k := num(hv)
	var src := ("queratina: %s" % ClawsV2.KERATIN_SOURCE.source) if not reforged() else "dureza del material: la del catálogo del banco"
	var q: String = ClawsV2.KERATIN_SOURCE.quality if not reforged() else "secondary"
	if film() and not reforged():
		var fc: Dictionary = claw.dino.fiction.claw
		src = String(fc.source)
		q = String(fc.quality)
	if mode == MODE_IMPACT and impact_zone == MovingCar.WINDOW_ZONE:
		# unidad 4m: contra la ventanilla templada, una punta al menos tan dura como el vidrio puede abrir la grieta que la revienta
		var glass_hv := float(MovingCar.Glazing.SIDE_WINDOW.hv)
		var wtxt := ("%s (%s HV) no %s el vidrio de la ventanilla (%s HV): no %s abrir la grieta que la reventaría; solo el golpe la parte, si la flexa más de lo que aguanta." % [
			_cap(cl.txt), k, _v(cl.pl, "raya", "rayan"), num(glass_hv), _v(cl.pl, "puede", "pueden")]) if hv < glass_hv else (
			"%s (%s HV) %s al menos tan %s como el vidrio de la ventanilla (%s HV): %s abrir la grieta que atraviesa la capa comprimida y reventarla con poca fuerza." % [
				_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), num(glass_hv), _v(cl.pl, "puede", "pueden")])
		return _fact(wtxt, "%s; vidrio templado de la ventanilla: %s HV, el sodocálcico del banco" % [src, num(glass_hv)], q)
	if mode == MODE_HOLD and zone == "luneta":
		return glass_hardness_fact(cl, hv, src, q)  # unidad 4v: la luneta templada
	var on_glass: bool = (mode == MODE_HOLD and zone == "parabrisas") or (mode == MODE_IMPACT and impact_zone == "parabrisas")
	if on_glass:
		# docs/fisica/coche-en-marcha.md §2.7 (la queratina no raya el vidrio) y §11.1 (unas garras al menos tan duras
		# como el vidrio lo rayan y lo agrietan por contacto)
		var glass: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "vidrio")
		# unidad 4v: rayarlo pide 1,25 veces su dureza (CarGlass.R_SCRATCH); agrietarlo por contacto, al menos la suya
		var txt := ("%s (%s HV) no %s el vidrio del parabrisas (%s HV): ahí no hay marcas y lo que decide es cuánto flexa la hoja." % [
			_cap(cl.txt), k, _v(cl.pl, "raya", "rayan"), num(float(glass.hv))]) if hv < float(glass.hv) else (
			("%s (%s HV) %s al menos tan %s como el vidrio del parabrisas (%s HV): %s agrietarlo por contacto, pero no rayarlo, que pide 1.25 veces su dureza." % [
				_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), num(float(glass.hv)), _v(cl.pl, "puede", "pueden")])
			if not CarGlass.scratches(hv, float(glass.hv)) else
			"%s (%s HV) %s más de 1.25 veces más %s que el vidrio del parabrisas (%s HV): %s rayarlo y agrietarlo por contacto." % [
				_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), num(float(glass.hv)), _v(cl.pl, "puede", "pueden")])
		return _fact(txt, "%s; vidrio: el sodocálcico del catálogo del banco; quién raya a quién: %s" % [src, CarGlass.R_SCRATCH_SOURCE.source], q)
	var txt: String
	if not Js.truthy(body.get("metal")):
		txt = "%s (%s HV) %s más %s que el %s de la aleta (%s HV): ahí sí %s entrar." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), body.long, num(float(body.hv)), _v(cl.pl, "puede", "pueden")]
	elif not MovingCar.can_cut_body(inlay_entry(), target, claw):
		txt = "%s (%s HV) %s más %s que el %s de la chapa (%s HV): no %s cortarlo; la pintura (%s HV), sí." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "blanda", "blandas"), body.long, num(float(body.hv)),
			_v(cl.pl, "puede", "pueden"), num(float(target.hv))]
	else:
		txt = "%s (%s HV) %s más %s que el %s de la chapa (%s HV): %s cortarlo." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), body.long, num(float(body.hv)), _v(cl.pl, "puede", "pueden")]
	return _fact(txt, "%s; %s" % [src, SRC_HARDNESS], q)


static func _maneuver(id: String) -> Dictionary:
	for m: Dictionary in MovingCar.MANEUVERS:
		if m.id == id:
			return m
	return {}


## La moraleja del ensayo: el humor del proyecto sin traicionar la física (las frases de la guía, §9.4, con los números
## del ensayo). "" sin datos.
func moral() -> String:
	if not supported():
		return ""
	if mode == MODE_HOLD:
		return _moral_hold() if Js.truthy(scen.get("ok")) else ""
	return _moral_impact()


func _moral_hold() -> String:
	if det.is_empty():
		return ""
	var k := kind()
	if k == "ave" and posture == "abiertas" and det.atRest and det.mode == "despega":
		return "%s con las alas abiertas sobre un coche a más de ~%s no está agarrad%s: está volando." % [
			_cap(animal_a()), fmt_kmh(det.kmh), _grammar()[1]]
	if reforged() and Js.truthy(scen.get("embedded")) and Js.truthy(target.body.get("metal")) and det.never:
		return "Con garras de %s clavadas en la chapa ya no es un pasajero: es parte de la carrocería." % String(ClawFracture.NOUNS.get(inlay, inlay))
	if defense and not det_rest.is_empty() and det.atRest and det_rest.atRest and float(det.kmh) > float(det_rest.kmh):
		return "El miedo agarra: asustad%s aguanta hasta %s en vez de ~%s." % [_grammar()[1],
			("~" + fmt_kmh(det.kmh)) if not det.never else "más de %s" % fmt_kmh(BAND_MAX_KMH), fmt_kmh(det_rest.kmh)]
	if glass_moral() != "":
		return glass_moral()  # unidad 4v: la luneta templada
	var shield: Variant = scen.get("windshield")
	if shield != null and shield.cracked:
		return "El parabrisas laminado se agrieta con facilidad, pero no cae: el PVB lo sujeta."
	if window_in_slider() and det.mode == "delante" and accel_g < 0.0:
		return "Al frenar, lo peligroso es el final: %s aguanta mientras el coche va deprisa y sale despedid%s al bajar de ~%s." % [
			animal_the(), _grammar()[1], fmt_kmh(det.holdFromKmh)]
	if k == "mamifero":
		if not at.is_empty() and float(at.vKmh) > 0.0 and float(at.dragShare) >= 0.5:
			return "%s %s en %s le añade al coche el %s de su resistencia: no es una baca homologada." % [
				_cap(animal_the()), posture_name(posture).to_lower(), String(ZONE_ARTICLE.get(zone, zone)), fmt_share(at.dragShare)]
		if accel_g < 0.0 and not at.is_empty() and not at.holds and at.mode == "delante":
			return "%s no %s tira el viento: %s tira la frenada." % [_cap(_to_animal()), _pro(), _pro()]
		if det.atRest and (det.beyond or det.never) and accel_g == 0.0 and lateral_g == 0.0 and not curve_on():
			var emer := -float(_maneuver("emergencia").get("accel_g", 0.0))
			if not report_matches_setup() or not report.has("brakingG"):
				return "%s no %s tira el viento: en todo el deslizador aguanta." % [_cap(_to_animal()), _pro()]
			var g := float(report.brakingG)
			if g < emer:
				return "%s no %s tira el viento, %s tira la frenada: aguanta hasta %s y una de emergencia es de %s." % [
					_cap(_to_animal()), _pro(), _pro(), CarFormat.fmt_g_max(g), fmt_g(emer)]
			return "%s no %s tiran ni el viento ni una frenada de emergencia (%s): aguanta hasta %s (caso central). Un pasajero que nadie quiere." % [
				_cap(_to_animal()), _pro(), fmt_g(emer), CarFormat.fmt_g_max(g)]
	if k == "ave" and zone == "techo":
		return "El techo es una pista de despegue: el aire pasa a %s veces la velocidad del coche." % Js.to_fixed(float(scen.localFactor), 2)
	if k == "teropodo" and shield == null:
		if film():
			return "Ficción con datos: el tamaño, el peso y el agarre son de Deinonychus; lo que se clava en la chapa es la garra de película."
		return "Un velocirraptor de verdad era del tamaño de un pavo (~%s kg): para el viento es un ave sin alas agazapada en %s." % [
			num(float(claw.mass)), String(ZONE_ARTICLE.get(zone, zone))]
	if shield != null:
		return "El parabrisas es una rampa lisa: vidrio a %s° con μ = %s, y nada a lo que agarrarse." % [num(float(scen.slopeDeg)), Js.to_fixed(float(scen.mu), 2)]
	return _moral_keratin(int((scen.scratch.layers as Array).size()) > 0)


func _moral_impact() -> String:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return ""
	var sw: Variant = hit.get("sideWindow")
	if sw != null:
		return _moral_window(sw)  # unidad 4m: la ventanilla templada
	var sh: Variant = hit.get("windshield")
	if sh != null:
		if sh.cracked:
			return "El parabrisas laminado se agrieta con facilidad, pero no cae: el PVB lo sujeta."
		return "Esta vez gana el parabrisas: el laminado aguanta el golpe sin agrietarse."
	if hit.get("kick") != null:
		return "El casuario no se sube al coche: le da una patada y rebota. En la carretera, el que sale perdiendo suele ser él."
	var frac: Variant = hit.get("clawFracture")
	if frac != null:
		var noun := String(frac.name)
		match String(frac.mode):
			"mella":
				return "Duro no es lo mismo que tenaz: el %s corta el acero, pero se mella." % noun
			"parte":
				return "Duro no es lo mismo que tenaz: el %s corta el acero, pero se parte." % noun
			"dobla":
				return "El %s corta la chapa, pero no estalla: se dobla." % noun
			"intacta":
				return "Garras de %s: cortan la chapa y aguantan. Unas garras de herramienta." % noun
	if kind() == "teropodo":
		return _moral_raptor()
	if kind() == "ave" and Js.truthy(hit.get("landing")) and not hit.stays and float(hit.slideM) > 0.0:
		return "Posarse en un coche a %s no es aterrizar: es patinar %s y salir volando." % [fmt_kmh(v_kmh), MovingCar.fmt_long(float(hit.slideM) * 1e6)]
	return _moral_keratin(int(hit.marks.count) > 0)


## La moraleja del golpe contra la ventanilla templada (unidad 4m): duro gana a fuerte; el templado no se agrieta, estalla; o
## esta vez gana la ventanilla.
func _moral_window(sw: Dictionary) -> String:
	if Js.truthy(sw.shattered) and sw.cause == "grieta":
		return "Duro gana a fuerte: a la ventanilla le basta una grieta de ~%s para estallar entera. Es el truco del martillo de emergencia." % CarFormat.fmt_long(float(sw.compressionMm) * 1000.0)
	if Js.truthy(sw.shattered):
		return "El templado no se agrieta: estalla. Por eso va en las ventanillas: trocitos romos de ~%s en vez de cuchillos de vidrio." % CarFormat.fmt_long(float(sw.fragmentMm) * 1000.0)
	if Js.truthy(sw.hardTip):
		return "Con garras duras bastaría una grieta, pero este golpe no llega a los ~%s por garra: esta vez gana la ventanilla." % fmt_n(sw.pierceN)
	var cl := _claws()
	return "Esta vez gana la ventanilla: el templado aguanta ~%s al flexar, y %s ni lo %s." % [fmt_n(sw.bendN), cl.txt, _v(cl.pl, "raya", "rayan")]


## La moraleja del golpe de un velocirraptor (unidad 4i-B2): el de película raja como en el cine; el de verdad pincha y
## sujeta, y contra el acero gana la chapa.
func _moral_raptor() -> String:
	var metal: bool = Js.truthy(target.body.get("metal"))
	if film() and not reforged():
		if metal:
			return "Parque Jurásico en la carretera: con garras de película raja la chapa como un abrelatas. El de verdad, con las suyas de queratina, no la corta: solo raya la pintura."
		return "Contra el plástico hasta el de verdad pincha: la ficción está en rajar el acero."
	if not metal:
		return "Pincha y sujeta: sus garras falciformes atraviesan la aleta, y lo que la raja es el coche, que se lo lleva."
	if MovingCar.can_cut_body(inlay_entry(), target, claw):
		return "Con garras de herramienta hasta un velocirraptor de verdad perfora la chapa; con las suyas, de queratina, no."
	return "Del tamaño de un pavo y con plumas: pincha y sujeta, pero contra el acero gana la chapa."


## Queratina contra la carrocería (la guía, §9.4): «gana la chapa; la pintura, en cambio, pierde». Con garras más blandas
## que la chapa (el oro), lo mismo.
func _moral_keratin(scratched: bool) -> String:
	var body: Dictionary = target.body
	if not Js.truthy(body.get("metal")):
		return "Contra la aleta de plástico sí ganan las garras: el plástico es más blando que %s." % (
			"la queratina" if not reforged() else "ellas")
	var metal := "aluminio" if String(body.id) == "aluminio" else "acero"
	if reforged() and not MovingCar.can_cut_body(inlay_entry(), target):
		return "El %s es precioso, pero blando: contra el %s, cede como la queratina." % [String(ClawFracture.NOUNS.get(inlay, inlay)), metal]
	return "Queratina contra %s: gana la chapa.%s" % [metal, " La pintura, en cambio, pierde." if scratched else ""]


## El efecto de sonido del golpe, de los del banco (core/lab/sfx.gd, los de la 1.x), con el criterio de
## Sfx.sfx_for_result: el parabrisas que se agrieta, una garra que se rompe, las garras que atraviesan el panel, los
## surcos hasta el metal o en la pintura, la chapa que se abolla o solo el roce. "" sin golpe.
func impact_sfx() -> String:
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return ""
	var sh: Variant = hit.get("windshield")
	if sh != null:
		return "pierce-brittle" if sh.cracked else "press"
	var sw: Variant = hit.get("sideWindow")
	if sw != null:
		return "shatter" if Js.truthy(sw.shattered) else "press"  # unidad 4m: el de la ventanilla que estalla en el banco
	var frac: Variant = hit.get("clawFracture")
	if frac != null and frac.breaks:
		return "snap"
	var pn: Variant = hit.get("puncture")
	if pn != null and pn.through:
		return "breakthrough"
	var marks: Dictionary = hit.marks
	if int(marks.count) > 0:
		if marks.reachesBody:
			return "scratch-metal" if Js.truthy(target.body.get("metal")) else "scratch-deep"
		return "scratch-soft"
	var dn: Variant = hit.get("dent")
	if dn != null and dn.applies and dn.visible:
		return "press"
	return "slide"


## Tamaño del animal para el dibujo (m): { heightM, lengthM, spanM } del ensayo (scen.draw) o, si no se queda encima (el
## casuario), de MovingCar.BODIES (height_m y length_m: solo para el dibujo).
func draw_size() -> Dictionary:
	if Js.truthy(scen.get("ok")):
		var d: Dictionary = scen.draw
		return { "heightM": float(d.heightM), "lengthM": float(d.lengthM), "spanM": float(d.get("spanM", 0.0)), "variant": String(d.get("variant", "")) }
	var b: Variant = MovingCar.body_of(claw)
	if b == null:
		return { "heightM": 0.8, "lengthM": 0.85, "spanM": 0.0, "variant": "" }
	return {
		"heightM": float(b.height_m), "lengthM": float(b.length_m), "spanM": float(b.span_m.value) if b.has("span_m") else 0.0,
		"variant": String(b.get("variant", "")),
	}


# ════════ Fuentes y estimaciones ════════

## Los datos del ensayo que se ve, con su valor (y su banda), su calidad y su fuente: [{ label, value, quality, source }].
## Salen tal cual de MovingCar (y de ClawsV2): la interfaz los enseña todos y marca las estimaciones.
func sources() -> Array:
	if not supported():
		return []
	var out: Array = []
	var body: Dictionary = MovingCar.body_of(claw)
	var c2 := ClawsV2.apply(claw)
	if body.has("mass_kg"):
		var ms: Dictionary = body.mass_kg[sex]
		out.append(_src("Masa (%s)" % String(MovingCar.SEX_NAMES.get(sex, sex)).to_lower(), "%s kg (de %s a %s)" % [
			num(float(ms.value)), num(float(ms.min)), num(float(ms.max))], String(ms.quality), String(ms.source)))
	elif c2.get("dino") is Dictionary:
		# los velocirraptores: la masa de su ficha, con su banda (por el fémur; unidad 4i-B2)
		var dm: Dictionary = c2.dino.mass
		out.append(_src("Masa", "%s kg (de %s a %s)" % [num(float(dm.value)), num(float(dm.min)), num(float(dm.max))], String(dm.quality),
			String(dm.source)))
	else:
		out.append(_src("Masa", "%s kg" % num(float(c2.mass)), "", SRC_MASS))
	if mode == MODE_HOLD and supports_hold():
		# unidad 4s: la carga de la garra a cada velocidad y la resistencia de la queratina de la cetrería
		out.append(_src("Carga de la garra con la velocidad", "la fuerza para no soltarse, repartida entre %s garras, y lo que aprieta contra el panel" % num(
			float(MovingCar.body_of(claw).contact)), String(MovingCar.CLAW_HOOK.quality), String(MovingCar.CLAW_HOOK.source)))
		if not reforged():
			var ks := CarSpeedMarks.keratin_strength()
			out.append(_src("Resistencia de la queratina", "%s MPa a flexión (%s), tenacidad ~%s MPa·√m" % [Format.fmt_p(float(ks.value)),
				CarSpeedMarks.KERATIN_HUMIDITY, num(float(ks.kic))], String(ks.quality), String(ks.source)))
	if film() and not reforged():
		var fc: Dictionary = c2.dino.fiction.claw
		out.append(_src("Garra de película", "%s HV · %s GPa: corta la chapa" % [num(float(fc.hv)), num(float(fc.E))], String(fc.quality), String(fc.source)))
	if reforged():
		var s: Variant = ClawFracture.strength(inlay)
		var noun := String(ClawFracture.NOUNS.get(inlay, inlay))
		if s != null:
			var band := "" if float(s.min) == float(s.max) else " (de %s a %s)" % [Format.fmt_p(float(s.min)), Format.fmt_p(float(s.max))]
			out.append(_src("Garras de %s" % noun, "%s HV · %s MPa %s%s" % [num(float(inlay_entry().hv)), Format.fmt_p(float(s.value)),
				"a flexión" if s.kind == "flexion" else "de fluencia", band], String(s.quality), String(s.source)))
		else:
			out.append(_src("Garras de %s" % noun, "%s HV" % num(float(inlay_entry().hv)), "", String(ClawFracture.UNKNOWN.get(inlay,
				"dureza del catálogo del banco"))))
	if mode == MODE_HOLD and Js.truthy(scen.get("ok")):
		_aero_sources(out, body, c2)
		var cp: Dictionary = MovingCar.ZONES[zone].cp
		out.append(_src("Cp de la zona (%s)" % zone_name(zone).to_lower(), fmt_band(cp), cp.quality, cp.source))
		_zone_sources(out, MovingCar.ZONES[zone], zone_name(zone))
		_body_sources(out, body)
		out.append(_src("Fricción de garras y almohadillas (μ)", "%s (%s-%s): el valor central lo da el motor del banco, acotado" % [
			Js.to_fixed(scen.mu, 2), num(MovingCar.FRICTION.min), num(MovingCar.FRICTION.max)], MovingCar.FRICTION.quality, MovingCar.FRICTION.source))
		_anchor_sources(out, body, c2)
		var dfn: Variant = scen.get("defense")
		if dfn != null:
			_defense_source(out, dfn)
			var rake: Variant = dfn.get("rakeN")
			if rake != null:
				out.append(_src("Arado de las garras hundidas", "%s (%s)" % [fmt_n(rake.value), fmt_n_band(rake.min, rake.max)],
					String(rake.quality), String(rake.source)))
		if curve_on():
			_curve_sources(out)  # unidad 4t
		var man := maneuver_entry()
		if float(man.accel_g) != 0.0 or float(man.lateral_g) != 0.0:
			out.append(_src("Maniobra: %s" % String(man.name).to_lower(), "%s de aceleración · %s de curva" % [
				fmt_g(float(man.accel_g)), fmt_g(float(man.lateral_g))], man.quality, man.source))
		out.append(_src("Aire", "%s kg/m³" % Js.to_fixed(scen.rho, 3), scen.air.quality, scen.air.source))
		out.append(_src("Coche de referencia", "Cd %s · %s m²" % [num(MovingCar.CAR_REF.cd), num(MovingCar.CAR_REF.area_m2)],
			MovingCar.CAR_REF.quality, MovingCar.CAR_REF.source))
	elif mode == MODE_IMPACT:
		var iz: Dictionary = MovingCar.IMPACT_ZONES[impact_zone]
		if MovingCar.is_leaper(body):
			var kl: Dictionary = MovingCar.KICK
			out.append(_src("Salto", "%s (hasta %s): los mismos w y f que la patada del casuario" % [
				CarFormat.fmt_mps(MovingCar.kick_leap_ms(), 2), Js.to_fixed(MovingCar.kick_leap_ms(true), 2)], String(kl.work_j_per_kg.quality),
				"%s; %s" % [kl.work_j_per_kg.source, kl.muscle_fraction.source]))
			out.append(_src("Altura de los paneles", "capó ~%s · parabrisas ~%s · techo ~%s" % [
				CarFormat.fmt_m(float(MovingCar.panel_height_m("capo")), 2), CarFormat.fmt_m(float(MovingCar.panel_height_m("parabrisas")), 2),
				CarFormat.fmt_m(float(MovingCar.panel_height_m("techo")), 2)], String(MovingCar.PANEL_HEIGHT_SOURCE.quality),
				"%s · %s · %s" % [MovingCar.HOOD_EDGE_M.source, MovingCar.ROOF_M.source, MovingCar.PANEL_HEIGHT_SOURCE.source]))
		if is_kicker():
			var kk: Dictionary = MovingCar.KICK
			out.append(_src("Salto de la patada", "%s J por kg de músculo (hasta %s) · %s de la masa en cada pata" % [
				num(float(kk.work_j_per_kg.value)), num(float(kk.work_j_per_kg.max)), fmt_share(float(kk.muscle_fraction.value))],
				String(kk.work_j_per_kg.quality), "%s; %s" % [kk.work_j_per_kg.source, kk.muscle_fraction.source]))
			out.append(_src("Fuerza máxima de la pata", "%s pesos (de %s a %s)" % [num(float(kk.force_bw.value)), num(float(kk.force_bw.min)),
				num(float(kk.force_bw.max))], String(kk.force_bw.quality), String(kk.force_bw.source)))
		var dfi: Variant = hit.get("defense") if not hit.is_empty() else null
		if dfi != null:
			_defense_source(out, dfi)
		out.append(_src("Recorrido de la pata al golpear", "%s mm" % num(MovingCar.LIMB_STROKE.value), MovingCar.LIMB_STROKE.quality,
			MovingCar.LIMB_STROKE.source))
		out.append(_src("Rigidez de la pata", "%s N/mm (la del motor del banco)" % num(Physics.MODEL.limbStiffness), String(MovingCar.LIMB_STIFFNESS.quality),
			String(MovingCar.LIMB_STIFFNESS.source)))
		if not iz.glass:
			# unidad 4o: el tope de la abolladura y de la punta de unas garras que atraviesan el panel; en el capó, con su banda
			var cl := _clearance_source(iz)
			var cb: Variant = MovingCar.CLEARANCE_BAND.get(impact_zone)
			var gap_src := String(cl.source)
			var gap := "%s mm" % num(float(iz.clearance_mm))
			if cb != null:
				gap = "%s mm (de %s a %s)" % [num(float(iz.clearance_mm)), num(float(cb.min)), num(float(cb.max))]
				gap_src += "; banda: " + String(cb.source)
			else:
				gap_src += "; sin banda: " + String(MovingCar.CLEARANCE_FIXED.get(impact_zone, "sin medición"))
			out.append(_src("Hueco bajo el panel (%s)" % String(iz.name).to_lower(), "%s: tope de la abolladura y de la punta de las garras que lo atraviesan" % gap,
				String(cl.quality), gap_src))
		if impact_zone == MovingCar.WINDOW_ZONE:
			_window_sources(out)  # unidad 4m: la ventanilla templada
		_zone_sources(out, iz, String(iz.name))
		_body_sources(out, body)
		var tr: Variant = hit.get("tear") if not hit.is_empty() else null
		if tr != null:
			var rt: Dictionary = tr.toughnessKJm2
			out.append(_src("Tenacidad del plástico (R)", "%s kJ/m² (de %s a %s) × %s de espesor: ~%s por garra" % [num(float(rt.value)),
				num(float(rt.min)), num(float(rt.max)), Format.fmt_len(float(tr.thicknessMm) * 1000.0), fmt_n(float(tr.perClawN))],
				String(tr.quality), String(tr.source)))
		out.append(_src("Fricción de garras y almohadillas (μ)", "banda %s-%s; el valor central lo da el motor del banco" % [
			num(MovingCar.FRICTION.min), num(MovingCar.FRICTION.max)], MovingCar.FRICTION.quality, MovingCar.FRICTION.source))
		if body.has("run_kmh"):
			var run: Dictionary = body.run_kmh
			out.append(_src("Carrera del %s" % String(c2.name).to_lower(), fmt_kmh(float(run.value)), run.quality, run.source))
		for t: Dictionary in energy_terms():
			out.append(_src("Energía: %s" % String(t.name).to_lower(), "%s (%s)" % [MovingCar.fmt_energy(t.j), fmt_pct(t.share)], t.quality, t.source))
		# unidad 4j: de dónde salen las velocidades del golpe y su banda
		if not hit.is_empty() and Js.truthy(hit.get("ok")):
			var kin: Variant = hit.get("kinematics")
			if kin != null and Js.truthy(kin.get("ok")):
				out.append(_src("Velocidades del golpe", "la del animal menos la del coche%s" % (", con el vuelo" if float(kin.flightS) > 0.0 else ""),
					String(kin.quality), String(kin.source)))
			var bd: Variant = hit.get("band")
			if bd != null:
				out.append(_src("Banda del golpe", "todo a favor del coche y todo en contra", String(bd.quality), String(bd.source)))
	_glass_sources(out)  # unidad 4v
	return out


## Resumen de «Fuentes y estimaciones» para la cabecera de la lista (que empieza plegada): cuántos datos hay y de qué calidad,
## «24 datos · 3 medidos · 8 de casos parecidos · 11 estimaciones». rows: las de sources() (vacío: las calcula).
func sources_summary(rows: Array = []) -> String:
	if rows.is_empty():
		rows = sources()
	if rows.is_empty():
		return ""
	var count := { "primary": 0, "secondary": 0, "estimate": 0, "ficcion": 0 }
	for r: Dictionary in rows:
		var q := String(r.quality)
		if count.has(q):
			count[q] += 1
	var parts: Array = ["%d %s" % [rows.size(), "dato" if rows.size() == 1 else "datos"]]
	var names := { "primary": ["medido", "medidos"], "secondary": ["de un caso parecido", "de casos parecidos"],
		"estimate": ["estimación", "estimaciones"], "ficcion": ["de ficción", "de ficción"] }
	for q: String in ["primary", "secondary", "estimate", "ficcion"]:
		var n: int = count[q]
		if n > 0:
			parts.append("%d %s" % [n, names[q][0] if n == 1 else names[q][1]])
	return " · ".join(PackedStringArray(parts))


## La geometría de la zona con su fuente campo a campo (ZONES o IMPACT_ZONES, sources de la unidad 4g): su inclinación y el
## panel que hay para resbalar. Nunca la posición del dibujo.
func _zone_sources(out: Array, z: Dictionary, zone_title: String) -> void:
	var fs: Variant = z.get("sources")
	if not (fs is Dictionary):
		return
	var n := zone_title.to_lower()
	var sl: Variant = fs.get("slope_deg")
	if sl is Dictionary:
		out.append(_src("Inclinación del panel (%s)" % n, "%s°" % num(float(z.slope_deg)), String(sl.quality), String(sl.source)))
	var sd: Variant = fs.get("slide_m")
	if sd is Dictionary:
		out.append(_src("Panel para resbalar (%s)" % n, CarFormat.fmt_m(float(z.slide_m), 1), String(sd.quality), String(sd.source)))


## Las fuentes campo a campo del cuerpo del animal (BODIES.sources, unidad 4g) que usa el ensayo que se ve: las garras que
## tocan el panel (o las que golpean), el radio del apoyo en el parabrisas y el ancho de la pata en un borde de chapa. Nunca
## las del dibujo (calidad «dibujo»).
func _body_sources(out: Array, body: Dictionary) -> void:
	var fs: Variant = body.get("sources")
	if not (fs is Dictionary):
		return
	var impact := mode == MODE_IMPACT
	var key := "strike_claws" if impact and body.has("strike_claws") else "contact"
	var f: Variant = fs.get(key)
	if f is Dictionary and String(f.quality) != "dibujo" and body.has(key):
		out.append(_src("Garras que %s" % ("golpean" if impact else "tocan el panel"), "%d" % int(body[key]), String(f.quality), String(f.source)))
	# el parabrisas y, en el golpe, la ventanilla templada (unidad 4m): el radio del apoyo decide la flexión de la hoja
	var glass := (impact_zone == "parabrisas" or impact_zone == MovingCar.WINDOW_ZONE) if impact else zone == "parabrisas"
	f = fs.get("contact_mm")
	if glass and f is Dictionary and body.has("contact_mm"):
		out.append(_src("Radio del apoyo de cada pie o mano", "%s mm" % num(float(body.contact_mm)), String(f.quality), String(f.source)))
	f = fs.get("paw_mm")
	if not impact and Js.truthy(MovingCar.ZONES[zone].get("edge")) and f is Dictionary and body.has("paw_mm"):
		out.append(_src("Ancho de la pata", "%s mm" % num(float(body.paw_mm)), String(f.quality), String(f.source)))


func _src(label: String, value: String, quality: String, source: String) -> Dictionary:
	return { "label": label, "value": value, "quality": quality, "source": source }


## Las fuentes de la ventanilla templada (unidad 4m), con nombres legibles: la hoja (Glazing.SIDE_WINDOW), la altura de la
## ventanilla y hasta dónde llega el animal (MovingCar.window_reach).
func _window_sources(out: Array) -> void:
	var W: Dictionary = MovingCar.Glazing.SIDE_WINDOW
	var sw: Variant = hit.get("sideWindow") if not hit.is_empty() else null
	var bits := (" · trocitos de ~%s" % CarFormat.fmt_long(float(sw.fragmentMm) * 1000.0)) if sw != null else ""
	out.append(_src("Ventanilla templada", "%s mm · %s MPa a flexión · ~%s MPa de compresión en las caras%s" % [
		num(float(W.pane.t)), num(float(W.pane.fgk)), num(float(W.frac.sigmaS)), bits], "estimate", MovingCar.side_window_source()))
	var tb: Dictionary = MovingCar.TEMPER_SIGMA_MPA
	out.append(_src("Compresión de las caras (banda)", "de %s a %s MPa" % [num(float(tb.min)), num(float(tb.max))], String(tb.quality),
		String(tb.source)))
	out.append(_src("Altura de la ventanilla", "de ~%s (de %s a %s) a ~%s" % [CarFormat.fmt_m(MovingCar.window_sill_m(), 2),
		CarFormat.fmt_m(MovingCar.window_sill_m("min"), 2), CarFormat.fmt_m(MovingCar.window_sill_m("max"), 2), CarFormat.fmt_m(MovingCar.window_top_m(), 2)],
		String(MovingCar.WINDOW_SILL_SOURCE.quality), String(MovingCar.WINDOW_SILL_SOURCE.source)))
	var wr: Dictionary = MovingCar.window_reach(claw)
	var reach := "vuela: a cualquier altura"
	match String(wr.how):
		"salta":
			reach = "saltando, los pies a ~%s (hasta %s)" % [CarFormat.fmt_m(float(wr.hitM), 2), CarFormat.fmt_m(float(wr.hitMaxM), 2)]
		"cruz":
			var wh: Dictionary = MovingCar.WITHERS_M[claw.id]
			reach = "a cuatro patas, la cruz a ~%s (de %s a %s)" % [CarFormat.fmt_m(float(wh.value), 2), CarFormat.fmt_m(float(wh.min), 2),
				CarFormat.fmt_m(float(wh.max), 2)]
	out.append(_src("Hasta dónde llega", reach, String(wr.quality), String(wr.source)))


func _defense_source(out: Array, d: Dictionary) -> void:
	var f: Dictionary = d.forceN
	out.append(_src("Fuerza de defensa (por %s)" % String(d.per), "%s (%s)" % [fmt_n(f.value), fmt_n_band(f.min, f.max)],
		String(d.get("quality", "")), String(d.get("source", ""))))


func _aero_sources(out: Array, body: Dictionary, c2: Dictionary) -> void:
	if body.kind == "mamifero":
		# unidad 4j: con la fuente de cada campo (BODIES.sources de la 4g), no la del cuerpo entero
		var names := { "frontal_m2": "Área frontal", "cd": "Cd del cuerpo", "cls_m2": "Sustentación del lomo (CL·S)" }
		var fs: Dictionary = body.get("sources", {})
		for k: String in names:
			var b: Dictionary = body[k][posture]
			var f: Dictionary = fs.get(k, { "quality": body.quality, "source": body.source })
			out.append(_src("%s (%s)" % [names[k], posture_name(posture).to_lower()], fmt_band(b, "m²" if k != "cd" else ""),
				String(f.quality), "%s: %s" % [body.species, f.source]))
		return
	var a: Dictionary = MovingCar.BIRD_AERO
	var fq: String = body.frontal.quality if body.has("frontal") else a.frontal_quality
	var fs: String = body.frontal.source if body.has("frontal") else MovingCar.SRC_PENNYCUICK
	out.append(_src("Área frontal del cuerpo (S_b)", "%s m² con %s kg" % [Js.to_fixed(MovingCar.bird_frontal_m2(float(c2.mass)), 4),
		num(float(c2.mass))], fq, fs))
	out.append(_src("Postura agazapada", "área ×%s" % fmt_band(a.crouch), a.crouch.quality, "estimación del modelo: posada y agazapada, con las patas y la cabeza alzada, enseña de %s a %s veces el área frontal del cuerpo en vuelo (%s); sin medición de un ave posada" % [
		num(float(a.crouch.min)), num(float(a.crouch.max)), MovingCar.SRC_PENNYCUICK]))
	out.append(_src("Cd del cuerpo posado", fmt_band(a.cd_body), a.cd_body.quality, MovingCar.SRC_TUCKER_1990 + "; " + MovingCar.SRC_PENNYCUICK))
	out.append(_src("Sustentación del cuerpo (CL·S / S_b)", fmt_band(a.cl_body), a.cl_body.quality, MovingCar.SRC_PONITZ))
	if posture == "abiertas":
		var w: Dictionary = body.wing_m2
		out.append(_src("Superficie alar", fmt_band(w, "m²"), w.quality, w.source))
		out.append(_src("Ala que sustenta", "CL %s · Cd %s" % [num(a.wing.sustenta.cl), num(a.wing.sustenta.cd)], a.wing.sustenta.quality,
			MovingCar.SRC_TUCKER_HEINE + " (el CL máximo; el Cd del ala, estimación)"))
		out.append(_src("Ala en pérdida (banda en contra)", "CL %s · Cd %s" % [num(a.wing.frena.cl), num(a.wing.frena.cd)], a.wing.frena.quality,
			MovingCar.SRC_HOERNER + " (placa plana inclinada ~45°)"))
		out.append(_src("Ala a poca incidencia (banda a favor)", "CL %s · Cd %s" % [num(a.wing.suave.cl), num(a.wing.suave.cd)], a.wing.suave.quality,
			String(a.wing.suave.source)))
		# unidad 4j: con viento de cola, a poca velocidad el aire llega por detrás y el ala lo recibe por el borde de salida
		# (cl_rev de la 4g, con su fuente)
		if wind_kmh < 0.0:
			var rev := { "sustenta": "que sustenta", "frena": "en pérdida (banda en contra)", "suave": "a poca incidencia (banda a favor)" }
			for k: String in rev:
				var w2: Dictionary = a.wing[k]
				out.append(_src("Ala %s con el aire por detrás" % rev[k], "CL %s" % num(float(w2.cl_rev)), String(w2.cl_rev_quality), String(w2.cl_rev_source)))


func _anchor_sources(out: Array, body: Dictionary, c2: Dictionary) -> void:
	var anchor := String(scen.get("anchor", "friccion"))
	if anchor == "friccion":
		return
	var n: Dictionary = scen.anchorN
	if body.kind == "ave" or body.kind == "teropodo":
		var g := MovingCar.grip_band(c2)
		var o: Variant = ClawsV2.override_of(c2, "force")
		var gs := MovingCar.grip_source(c2)
		out.append(_src("Agarre de un pie", fmt_band(g, "N"), gs.quality if o != null or body.kind == "teropodo" else "",
			gs.source if o != null or body.kind == "teropodo" else SRC_MASS))
		out.append(_src("Agarre alrededor de la barra (k)", fmt_band(MovingCar.GRASP_K), MovingCar.GRASP_K.quality, MovingCar.GRASP_K.source))
	else:
		out.append(_src("Gancho de cada pata delantera (× el peso)", fmt_band(MovingCar.HOOK_K), MovingCar.HOOK_K.quality, MovingCar.HOOK_K.source))
		if Js.truthy(MovingCar.ZONES[zone].get("edge")):
			var e: Dictionary = MovingCar.EDGE
			out.append(_src("Borde de chapa de la ventanilla", "brazo de %s mm · factor %s" % [num(e.lever_mm), fmt_band(e.factor)], e.quality, e.source))
	out.append(_src("Anclaje (%s)" % anchor, "%s (%s)" % [fmt_n(n.value), fmt_n_band(n.min, n.max)], "estimate",
		"estimación del modelo: se agarra con 2 pies (o 2 patas delanteras) a la vez, cada uno con los datos de arriba"))
	# unidad 4p: unas garras reforjadas clavadas no sujetan más de lo que aguanta la chapa alrededor de cada agujero
	var hold_n: Variant = scen.get("clawHoldN")
	if hold_n != null and hold_n.get("fuMPa") != null:
		var fu: Dictionary = MovingCar.SHEET_FU[String(target.body.id)]
		var fu_band := "" if float(fu.min) == float(fu.max) else " (de %s a %s)" % [num(float(fu.min)), num(float(fu.max))]
		out.append(_src("Chapa alrededor del agujero (aplastamiento)", "Rm %s MPa%s · 2,5·k_t·Rm·d·t con k_t %s y d %s: ~%s por garra" % [
			num(float(fu.value)), fu_band, Js.to_fixed(float(hold_n.kt), 2), Format.fmt_len(float(hold_n.dMm) * 1000.0),
			fmt_n(float(hold_n.perClaw.bearingN))], String(MovingCar.SHEET_BEARING.quality),
			"%s. Rm: %s" % [MovingCar.SHEET_BEARING.source, fu.source]))


# ════════ Curvas (unidad 4t) ════════
# La carretera recta, una curva a la izquierda o una curva en S (CarCurve.ROADS) con el radio del deslizador. En recta no
# se llama a nada de aquí: todo sale al bit como antes. En curva, la aceleración lateral la pone la curva (v²/R, sin
# pasar del tope del coche) y la de la maniobra no se suma: elegir una maniobra con curva vuelve a la recta, y elegir una
# curva quita la maniobra con curva. Solo el animal quieto encima: el golpe va siempre en recta.

## ¿Se calcula en curva? (la carretera no es recta y el animal se queda encima)
func curve_on() -> bool:
	return road != CarCurve.ROAD_STRAIGHT and supports_hold()


## La carretera elegida (entrada de CarCurve.ROADS).
func road_entry() -> Dictionary:
	for r: Dictionary in CarCurve.ROADS:
		if r.id == road:
			return r
	return CarCurve.ROADS[0]


## La curva con el radio y el coche elegidos (CarCurve.road: velocidad de proyecto, clotoides, tope del coche…).
func curve_road() -> Dictionary:
	return CarCurve.road(radius_m, target)


## Tope de agarre lateral del coche elegido (CarCurve.CAR_GRIP).
func curve_grip() -> Dictionary:
	return CarCurve.grip_of(target)


## Lado al que empuja la curva que se enseña: +1 (derecha) en la curva; en la S, el del lado peor (curve_sides).
func curve_side() -> float:
	if road == CarCurve.ROAD_S and not curve_sides.is_empty():
		return float(curve_sides.worst.side)
	return 1.0


## Las fuerzas a v (km/h): las de MovingCar en recta; en curva, las de CarCurve (con el campo curve).
func _at_speed(v: float) -> Dictionary:
	if curve_on():
		return CarCurve.at_speed(scen, v, radius_m, float(curve_grip().value), curve_side())
	return MovingCar.at_speed(scen, v)


func _curve_derive() -> void:
	var grip := curve_grip()
	if road == CarCurve.ROAD_S:
		curve_sides = CarCurve.detach_s(scen, radius_m, grip)
		det = curve_sides.worst
	else:
		det = CarCurve.detach(scen, radius_m, grip, 1.0)
	chart = CarCurve.chart(scen, radius_m, grip, float(det.side), det)
	verdict = CarCurve.verdict(scen, det, slider_max_kmh())


## Carretera recta, curva o curva en S. Elegir una curva quita una maniobra con curva (vuelve a velocidad constante).
func set_road(id: String) -> void:
	var ok := false
	for r: Dictionary in CarCurve.ROADS:
		ok = ok or r.id == id
	if not ok or id == road:
		return
	road = id
	if road != CarCurve.ROAD_STRAIGHT and lateral_g != 0.0:
		maneuver = DEFAULT_MANEUVER
		accel_g = 0.0
		lateral_g = 0.0
		_rebuild()
		return
	_recurve()


## Radio de la curva (m, entre CarCurve.R_MIN_M y R_MAX_M, redondeado al metro).
func set_radius(r: float) -> void:
	r = Js.js_round(clampf(r, CarCurve.R_MIN_M, CarCurve.R_MAX_M))
	if r == radius_m:
		return
	radius_m = r
	if curve_on():
		_recurve()
	else:
		_emit()


## Vuelve a calcular el despegue y la gráfica sin setup (la curva no cambia el ensayo, solo la aceleración lateral).
func _recurve() -> void:
	if scen.is_empty() or not Js.truthy(scen.get("ok")):
		_emit()
		return
	var t0 := Time.get_ticks_usec()
	_derive()
	last_setup_us = Time.get_ticks_usec() - t0
	_emit()


## Lo de la curva a la velocidad del deslizador (el campo curve de at; {} en recta).
func curve_now() -> Dictionary:
	return at.get("curve", {}) if curve_on() else {}


## La curva a esa velocidad en una frase y por qué aguanta o se suelta («En la curva de 130 m a 90 km/h tira hacia fuera
## con 0.49 g (4.8 m/s²), hacia la derecha. …»); "" en recta.
func curve_text() -> String:
	var c := curve_now()
	if c.is_empty():
		return ""
	var txt := CarCurve.now_txt(c, float(at.vKmh))
	var why := CarCurve.why_txt(at, animal_the())
	if why != "":
		txt += " " + why
	if road == CarCurve.ROAD_S and float(at.vKmh) >= CarCurve.REST_KMH:
		txt += " " + s_text()
	var gt := grip_text()  # unidad 4u
	if gt != "":
		txt += " " + gt
	return txt


## En la S: cuándo cambia de lado y con qué tirón, frente al de la norma.
func s_text() -> String:
	var rd := curve_road()
	var prof := CarCurve.s_profile(rd, v_kmh, 3)
	var j := CarCurve.s_jerk_ms3(rd, v_kmh)
	return "En la S cambia de lado a los %s s de empezar, con un tirón de %s m/s³ (la norma lo limita a %s m/s³ a la velocidad de proyecto de esa curva, %s)." % [
		Js.to_fixed(float(prof.flipS), 1), Js.to_fixed(j, 2), Js.to_fixed(float(rd.jerkNorm), 1), fmt_kmh(float(rd.designKmh))]


## Un instante de la S (t_s desde su principio) con el coche a la velocidad del deslizador: { s (CarCurve.s_at), at (las
## fuerzas con la aceleración lateral de ese instante, con su campo curve) }. Para la vista: ~30 µs.
func s_frame(t_s: float) -> Dictionary:
	if not curve_on() or road != CarCurve.ROAD_S:
		return {}
	var rd := curve_road()
	var p := CarCurve.s_at(rd, v_kmh, t_s)
	return { "s": p, "at": CarCurve.at_lateral(scen, v_kmh, float(p.aMs2), radius_m, float(curve_grip().value)) }


## Lo que dura la S a la velocidad del deslizador (s; INF parado).
func s_duration() -> float:
	return CarCurve.s_duration(curve_road(), v_kmh)


## El medidor de fuerza G a la velocidad del deslizador (el campo meter de curve; {} en recta).
func meter() -> Dictionary:
	var c := curve_now()
	return c.get("meter", {}) if not c.is_empty() else {}


## Lo que dice el medidor de fuerza G debajo del círculo (c: el campo curve de unas fuerzas), en dos líneas cortas:
## «0.49 g · derecha» (o que derrapa) y el tope del coche o, en la S que se enseña en loop_s segundos, lo que dura de verdad.
## short: una sola línea, con el lado abreviado («0.55 g · izq.»), para la vista de un teléfono.
func meter_note(c: Dictionary, loop_s := 0.0, short := false) -> String:
	if c.is_empty():
		return ""
	var side := CarCurve.side_name(float(c.side))
	if short and side != "":
		side = side.substr(0, 3) + "."
	var head := fmt_g(absf(float(c.latG))) + ((" · " + side) if side != "" else "")
	# derrapa solo si ahora está en el tope del coche (en la S, en el pico; no en el cambio de lado)
	var skids_now := bool(c.skids) and absf(float(c.latG)) >= float(c.gripG) - 1e-6
	if skids_now:
		head += " · derrapa"
	if short:
		# en un teléfono no cabe todo: si derrapa, eso (el lado ya lo dice la flecha)
		return fmt_g(absf(float(c.latG))) + " · derrapa" if skids_now else head
	var foot := "tope del coche %s" % fmt_g(float(c.gripG))
	var dur := s_duration()
	if road == CarCurve.ROAD_S and loop_s > 0.0 and is_finite(dur):
		foot = "la S: %s s (aquí, %s s)" % [Js.to_fixed(dur, 0), num(loop_s)]
	return head + "\n" + foot


## Lo que dice el plano de la carretera: «curva de 130 m» o «S de 130 m»; short (un teléfono): «130 m».
func road_note(short := false) -> String:
	if short:
		return CarCurve.r_txt(radius_m)
	return "%s de %s" % ["S" if road == CarCurve.ROAD_S else "curva", CarCurve.r_txt(radius_m)]


## El radio en el deslizador, con su velocidad de proyecto: «130 m · 60 km/h» (corto: cabe en un teléfono).
func radius_text() -> String:
	var rd := curve_road()
	var design := fmt_kmh(float(rd.designKmh))
	if radius_m < float(CarCurve.NORM_RADII[0].r_m):
		design = "~" + design
	return "%s · %s" % [CarCurve.r_txt(radius_m), design]


## Frenada máxima en la curva (g) a la velocidad del deslizador, con la aceleración lateral de ahora (caso central).
func _curve_braking_g() -> float:
	var c := curve_now()
	return MovingCar.max_braking_g(CarCurve.scen_at(scen, float(c.get("latMs2", 0.0))), v_kmh)


## Lecturas de la curva para hold_readings (en lugar de la de la maniobra con curva).
func _curve_readings() -> Array:
	var c := curve_now()
	if c.is_empty():
		return []
	var out: Array = []
	var grip := curve_grip()
	var sub := "curva de %s a %s: %s, %s" % [CarCurve.r_txt(radius_m), fmt_kmh(float(at.vKmh)), CarCurve.g_ms2_txt(float(c.latMs2)),
		CarCurve.side_txt(float(c.side))]
	if bool(c.skids):
		sub = "pediría %s: el coche derrapa con %s" % [CarCurve.g_ms2_txt(float(c.demandMs2)), fmt_g(float(c.gripG))]
	out.append(_reading("curva", "Hacia fuera de la curva (m·a)", fmt_n(absf(float(at.lateralN))), sub,
		"primary" if not bool(c.skids) else String(grip.quality), CarCurve.SRC_KINEMATICS if not bool(c.skids) else String(grip.source)))
	var sh: Dictionary = c.shares
	if float(sh.loaded) != 0.0:
		out.append(_reading("lados", "Garras del lado de fuera", fmt_pct(maxf(float(sh.right), float(sh.left))),
			"las de la %s · banda %s-%s del peso%s" % [CarCurve.side_name(float(sh.loaded)), fmt_pct(float(sh.lo)), fmt_pct(float(sh.hi)),
			" · las de dentro ya no apoyan" if bool(sh.lifts) else ""], String(CarCurve.LOAD_TRANSFER.quality), String(CarCurve.LOAD_TRANSFER.source)))
	out.append_array(_grip_readings())  # unidad 4u
	return out


## Fuentes de la curva (sources).
func _curve_sources(out: Array) -> void:
	var rd := curve_road()
	var grip: Dictionary = rd.grip
	out.append(_src("Aceleración lateral", "a = v²/R", "primary", CarCurve.SRC_KINEMATICS))
	if radius_m < float(CarCurve.NORM_RADII[0].r_m):
		out.append(_src("Radio de la glorieta", "%s (de %s a %s m)" % [CarCurve.r_txt(float(CarCurve.RING_R.value)), num(float(CarCurve.RING_R.min)),
			num(float(CarCurve.RING_R.max))], String(CarCurve.RING_R.quality), String(CarCurve.RING_R.source)))
	else:
		out.append(_src("Radio mínimo de la norma", "%s a %s de proyecto" % [CarCurve.r_txt(radius_m), fmt_kmh(float(rd.designKmh))],
			String(rd.quality), String(rd.source)))
	out.append(_src("Tope de agarre lateral del coche", "%s (de %s a %s)" % [fmt_g(float(grip.value)), fmt_g(float(grip.min)), fmt_g(float(grip.max))],
		String(grip.quality), String(grip.source)))
	out.append(_src("Reparto entre las garras de cada lado (h/b)", fmt_band(CarCurve.LOAD_TRANSFER), String(CarCurve.LOAD_TRANSFER.quality),
		String(CarCurve.LOAD_TRANSFER.source)))
	if road == CarCurve.ROAD_S:
		out.append(_src("Clotoide de la S", "J %s m/s³ a %s: %s m de cambio" % [Js.to_fixed(float(rd.jerkNorm), 1), fmt_kmh(float(rd.designKmh)),
			Js.to_fixed(float(rd.reverseM), 0)], "primary", CarCurve.SRC_JERK))
	_grip_sources(out)  # unidad 4u


## «¿Sabías que…?» de la curva (van primero en facts).
func _curve_facts(out: Array) -> void:
	var rd := curve_road()
	var design := float(rd.designKmh)
	var g_design := CarCurve.demand_g(design, radius_m)
	if radius_m >= float(CarCurve.NORM_RADII[0].r_m):
		var p := _norm_p(design)
		out.append(_fact("Con %s de radio, la norma deja proyectar la curva a %s. A esa velocidad pide %s; la norma cuenta con un peralte de hasta el %s %%, que se come unos %s, y lo demás lo da el rozamiento de los neumáticos (aquí la curva va sin peralte, el peor caso para %s)." % [
			CarCurve.r_txt(radius_m), fmt_kmh(design), fmt_g(g_design), num(p), fmt_g(p / 100.0), animal_the()], CarCurve.SRC_RADII, "primary"))
	else:
		out.append(_fact("En una glorieta urbana de un carril (de 30 a 40 m de diámetro exterior) el coche gira con unos %s de radio: a %s ya pide %s." % [
			CarCurve.r_txt(radius_m), fmt_kmh(design), fmt_g(g_design)], String(CarCurve.RING_R.source), String(CarCurve.RING_R.quality)))
	var grip: Dictionary = rd.grip
	out.append(_fact("Los neumáticos de %s dan de lado ~%s en asfalto seco: en la curva de %s, a más de ~%s el coche ya no gira, derrapa." % [
		"un deportivo" if String(target.id) == CarCurve.SportsCar.ID else "un turismo", fmt_g(float(grip.value)), CarCurve.r_txt(radius_m),
		fmt_kmh(float(rd.skidKmh))], String(grip.source), String(grip.quality)))
	if road == CarCurve.ROAD_S:
		out.append(_fact("En la S, la clotoide de cambio mide %s m: a %s el tirón es el de la norma, %s m/s³; al doble de velocidad, ocho veces más." % [
			Js.to_fixed(float(rd.reverseM), 0), fmt_kmh(design), Js.to_fixed(float(rd.jerkNorm), 1)], CarCurve.SRC_JERK, "primary"))


## El porqué cuando el coche derrapa antes de que se suelte el animal: la curva no puede tirar de él más que el tope del
## coche, y con eso y el viento, hasta dónde aguanta (ya con el coche derrapando).
func _curve_skid_why() -> String:
	var grip := float(det.gripG)
	var pull := fmt_n(float(scen.mass) * grip * MovingCar.G)
	var txt := "El coche llega antes a su tope: a más de ~%s los neumáticos no dan más de %s y derrapa, así que la curva nunca tira de %s con más de %s." % [
		fmt_kmh(float(det.skidKmh)), fmt_g(grip), _to_animal_obj(), pull]
	if det.never:
		return txt + " Con eso y el viento, %s no se suelta ni a %s." % [animal_the(), fmt_kmh(BAND_MAX_KMH)]
	if det.beyond:
		return txt + " Con eso y el viento, %s aguanta en todo el deslizador." % animal_the()
	return txt + " Con eso y el viento, %s aguantaría hasta ~%s, ya con el coche derrapando." % [animal_the(), fmt_kmh(float(det.kmh))]


## «él» o «ella» (el animal, tras una preposición).
func _to_animal_obj() -> String:
	return "ella" if _grammar()[1] == "a" else "él"


## ¿El golpe va en curva? (la carretera no es recta y se ve el golpe). La fuerza del golpe es la de siempre (impact, en
## recta); en curva cambia solo el camino del animal visto desde el coche y el dibujo. La S, en el golpe, es su primera curva.
func impact_curve_on() -> bool:
	return road != CarCurve.ROAD_STRAIGHT and mode == MODE_IMPACT and supported()


## La aceleración lateral del coche en el golpe en curva (g, + hacia la derecha): v²/R sin pasar del tope del coche.
func impact_lat_g() -> float:
	return CarCurve.felt_ms2(v_kmh, radius_m, float(curve_grip().value)) / MovingCar.G


## El camino del animal que se abalanza en la curva, visto desde el coche: lo que se separa de la recta en los últimos dist_m
## metros (CarCurve.approach_offsets; x hacia delante, y hacia la derecha), con su velocidad respecto al coche (kinematics).
## Llega por el costado de quien mira, la derecha del coche. Vacío en recta.
func impact_approach(dist_m: float, n := 16) -> PackedVector2Array:
	if not impact_curve_on():
		return PackedVector2Array()
	var k: Variant = hit.get("kinematics") if not hit.is_empty() and Js.truthy(hit.get("ok")) else null
	if k == null:
		k = MovingCar.kinematics(impact_params())
	if not Js.truthy(k.get("ok")):
		return PackedVector2Array()
	var rel: Dictionary = k.relKmh
	var omega := CarCurve.yaw_rate(v_kmh, radius_m, float(curve_grip().value), 1.0)
	return CarCurve.approach_offsets(float(rel.x) / MovingCar.KMH, -absf(float(rel.y)) / MovingCar.KMH, float(rel.z) / MovingCar.KMH,
		v_kmh, omega, dist_m, n)


## El golpe en curva en una frase: cuánto gira el coche y que la fuerza del golpe es la de siempre ("" en recta).
func impact_curve_text() -> String:
	if not impact_curve_on():
		return ""
	var w := CarCurve.yaw_rate(v_kmh, radius_m, float(curve_grip().value), 1.0)
	var c := CarCurve.at_lateral_kin(v_kmh, radius_m, float(curve_grip().value))
	var head := "En la curva de %s a %s el coche gira %s°/s y tira hacia fuera con %s" % [CarCurve.r_txt(radius_m), fmt_kmh(v_kmh),
		Js.to_fixed(w * 180.0 / PI, 1), CarCurve.g_ms2_txt(float(c.latMs2))]
	if bool(c.skids):
		head += " (derrapa: la curva pediría %s)" % CarCurve.g_ms2_txt(float(c.demandMs2))
	return head + ". Visto desde el coche que gira, el animal que se abalanza llega torciéndose; la fuerza del golpe es la de siempre: la que da su velocidad respecto al coche."


## Peralte máximo de la norma (%) a una velocidad de proyecto (tabla 4.4).
static func _norm_p(design: float) -> float:
	var p := 0.0
	for e: Dictionary in CarCurve.NORM_RADII:
		if float(e.v_kmh) <= design:
			p = float(e.p)
	return p


# ════════ Agarre en curva (unidad 4u) ════════
# En curva, cerca del límite, las garras del lado cargado resbalan y vuelven a clavarse, y si no aguanta se cae
# (CarCurveGrip, encima del equilibrio de la 4t y de las marcas de la 4s). En recta no se llama a nada de aquí: grip_now()
# devuelve {} y las filas, las lecturas y las fuentes no cambian.

var _grip_key: Array = []
var _grip: Dictionary = {}


## Lo que hace el animal en la curva a la velocidad del deslizador: en la curva, CarCurveGrip.at (los resbalones, el surco
## de cada uno y si se cae); en la S, CarCurveGrip.s_events (los momentos en que se recoloca o se cae). {} en recta. Se
## calcula una vez por ensayo, velocidad y radio (dos o tres compute() del motor de las marcas), nunca en cada fotograma.
func grip_now() -> Dictionary:
	if not curve_on() or at.is_empty() or scen.is_empty() or not Js.truthy(scen.get("ok")):
		return {}
	var key := [_hold_key(), road, radius_m, setup_version]
	if key == _grip_key:
		return _grip
	_grip_key = key
	if road == CarCurve.ROAD_S:
		_grip = CarCurveGrip.s_events(scen, curve_road(), v_kmh, float(curve_grip().value))
	else:
		_grip = CarCurveGrip.at(scen, at)
	return _grip


## ¿Las marcas son en un vidrio (el parabrisas)?
func _grip_glass() -> bool:
	return bool((scen.get("holdCtx", {}) as Dictionary).get("glass", false))


## Lo que hace en la curva en una frase ("" si nada).
func grip_text() -> String:
	var g := grip_now()
	if g.is_empty():
		return ""
	if road == CarCurve.ROAD_S:
		return CarCurveGrip.s_txt(g, animal_the(), target, _grip_glass(), kind() == "ave")
	return CarCurveGrip.now_txt(g, animal_the(), target, _grip_glass(), kind() == "ave")


## Lectura del agarre en la curva (va con las de la curva): cuánto de su agarre usa y lo que pasa.
func _grip_readings() -> Array:
	var g := grip_now()
	if g.is_empty():
		return []
	if road == CarCurve.ROAD_S:
		var pk: Dictionary = g.peak
		var u := maxf(float(pk.right), float(pk.left))
		var sub := "%s surcos en la S" % num(float(CarCurveGrip.groove_count(g)))
		if bool(g.falls):
			sub = "se cae a los %s s de empezar la S" % Js.to_fixed(float(g.fallT), 1)
		elif CarCurveGrip.groove_count(g) == 0:
			sub = "no resbala: lejos de su tope"
		return [_reading("agarre_curva", "Agarre que usa en el pico de la S", fmt_pct(minf(u, 9.99)), sub,
			String(CarCurveGrip.SLIP_FROM.quality), String(CarCurveGrip.SLIP_FROM.source))]
	var sub2 := "no resbala: lejos de su tope"
	if bool(g.falls):
		sub2 = "no aguanta: se cae por la %s" % CarCurve.side_name(float(g.side)) if bool(g.sideways) else "no aguanta: se suelta"
		if kind() == "ave":
			sub2 = "no aguanta: se suelta e intenta despegar"
	elif int(g.slips) > 0:
		sub2 = "%s resbalan ~%s y vuelven a clavarse" % [CarCurveGrip.claws_txt(int(g.slips)), CarTear.len_txt(float(g.lenMm))]
		if int(g.slips) == 1:
			sub2 = "una garra resbala ~%s y vuelve a clavarse" % CarTear.len_txt(float(g.lenMm))
	return [_reading("agarre_curva", "Agarre que usa en la curva", fmt_pct(minf(float(g.u), 9.99)), sub2,
		String(CarCurveGrip.SLIP_FROM.quality), String(CarCurveGrip.SLIP_FROM.source))]


## Filas del informe en curva: los resbalones (cuántos surcos y lo que corta cada uno) y la caída. [] en recta.
func grip_rows() -> Array:
	var g := grip_now()
	if g.is_empty():
		return []
	var glass := _grip_glass()
	if road == CarCurve.ROAD_S:
		var events: Array = g.events
		if events.is_empty():
			return [["Resbalones en la S", "ninguno: no se acerca a su tope"]]
		var out: Array = [["Resbalones en la S", "%s surcos · cada uno %s" % [num(float(CarCurveGrip.groove_count(g))),
			CarCurveGrip.marks_txt((events[0] as Dictionary).marks, target, glass)]]]
		if bool(g.falls):
			out.append(["En la S", "se cae a los %s s" % Js.to_fixed(float(g.fallT), 1)])
		return out
	if bool(g.falls):
		return [["Al caerse en la curva", "%s surcos de ~%s · %s" % [num(float(g.slips)), CarTear.len_txt(float(g.fallMm)),
			CarCurveGrip.marks_txt(g.fallMarks, target, glass)]]]
	if int(g.slips) <= 0:
		return [["Resbalones en la curva", "ninguno: usa el %s de su agarre" % fmt_pct(float(g.u))]]
	return [["Resbalones en la curva", "%s de ~%s · %s" % [CarCurveGrip.claws_txt(int(g.slips)), CarTear.len_txt(float(g.lenMm)),
		CarCurveGrip.marks_txt(g.marks, target, glass)]]]


## Fuentes del agarre en curva (van con las de la curva).
func _grip_sources(out: Array) -> void:
	var sf: Dictionary = CarCurveGrip.SLIP_FROM
	out.append(_src("Desde cuándo resbalan las garras (parte del agarre)", "%s (de %s a %s)" % [fmt_pct(float(sf.value)), fmt_pct(float(sf.min)),
		fmt_pct(float(sf.max))], String(sf.quality), String(sf.source)))
	var sm: Dictionary = CarCurveGrip.SLIP_MM
	out.append(_src("Lo que resbala cada garra antes de volver a clavarse", fmt_band(sm, "mm"), String(sm.quality), String(sm.source)))
	if road == CarCurve.ROAD_S:
		var ff: Dictionary = CarCurveGrip.FLIP_FROM
		out.append(_src("Al cambiar de lado, desde cuándo se recolocan", "%s (de %s a %s)" % [fmt_pct(float(ff.value)), fmt_pct(float(ff.min)),
			fmt_pct(float(ff.max))], String(ff.quality), String(ff.source)))
	var fs: Dictionary = CarCurveGrip.FALL_SLIDE_MM
	out.append(_src("Lo que resbala hacia fuera al caerse", fmt_band(fs, "mm"), String(fs.quality), String(fs.source)))


# ════════ Cristales (unidad 4v) ════════
# Las garras en el parabrisas, la luneta y la ventanilla (CarGlass): rayar el vidrio pide r ≥ 1,25; el laminado se agrieta y
# no cae (lo que tapa al conductor, estimación); el templado aguanta entero o estalla, y si estalla bajo el animal pierde el
# apoyo y caen trocitos dentro. Aquí solo los textos y el corte del vidrio: la física es la de MovingCar y CarGlass.

const CarGlass = preload("res://core/lab/car_glass.gd")
## El valor de la ficha «Hasta dónde llega» en un cristal.
const GLASS_CUT_VALUE := { "mancha": "No lo raya", "raya_vidrio": "Raya el vidrio", "agrieta": "Se agrieta (no cae)", "estalla": "Estalla" }


## ¿El animal está quieto encima de un cristal (el parabrisas o la luneta)?
func on_glass() -> bool:
	return mode == MODE_HOLD and String((MovingCar.ZONES.get(zone, {}) as Dictionary).get("surface", "")) == "vidrio"


## ¿Lo que se ve ahora (quieto encima o el golpe) es un cristal?
func glass_zone_now() -> bool:
	if mode == MODE_IMPACT:
		var iz: Variant = MovingCar.IMPACT_ZONES.get(impact_zone)
		return iz != null and Js.truthy(iz.glass)
	return on_glass()


## La luneta templada quieto encima (null si no está en ella): la de setup y, si estalla a la velocidad del deslizador, la de
## esa velocidad.
func rear_now() -> Variant:
	if not on_glass() or scen.is_empty() or not Js.truthy(scen.get("ok")):
		return null
	var rear: Variant = scen.get("rearWindow")
	var m := marks_now()
	if rear != null and not bool(rear.shattered) and not m.is_empty() and Js.truthy(m.get("rearShattered")) and m.get("rearWindow") != null:
		return m.rearWindow
	return rear


## Lo que deja una garra que no raya el vidrio (summary: scen.scratch o las marcas de una velocidad, con trace y ratio).
func glass_trace_txt(s: Dictionary) -> String:
	return CarGlass.trace_txt(String(s.get("trace", "mancha")), float(s.get("ratio", 0.0)))


## Las filas del informe del animal quieto encima de un cristal: la luneta (entera o estallada, y a qué velocidad) y lo que
## tapa al conductor el parabrisas agrietado.
func glass_hold_rows() -> Array:
	var out: Array = []
	if not on_glass():
		return out
	var rear: Variant = rear_now()
	if rear != null:
		var row := CarGlass.rear_row(rear)
		var at_v := _rear_shatter_kmh()
		if at_v > 0.0:
			row = "a partir de ~%s %s" % [fmt_kmh(at_v), row]
		out.append(["Luneta", row])
	var shield: Variant = scen.get("windshield")
	if shield != null:
		var vt := CarGlass.view_txt(shield.get("viewLoss"))
		if vt != "":
			out.append(["Vista del conductor", vt])
	return out


## La velocidad a la que estalla la luneta (km/h) si no ha estallado parado y estalla en el deslizador; 0 si no.
func _rear_shatter_kmh() -> float:
	var rear: Variant = scen.get("rearWindow")
	if rear == null or bool(rear.shattered):
		return 0.0
	var c := marks_curve()
	var ev: Variant = c.get("rearAt") if not c.is_empty() else null
	return float(ev.kmh) if ev != null and ev.kmh != null and float(ev.kmh) > 0.0 else 0.0


## Las lecturas en directo de los cristales: la luneta (quieto encima), lo que tapa el parabrisas agrietado (quieto encima o
## en el golpe) y lo que deja la garra en el vidrio del golpe.
func glass_readings() -> Array:
	var out: Array = []
	if mode == MODE_HOLD:
		var rear: Variant = rear_now()
		if rear != null:
			var w := CarGlass.rear_window()
			out.append(_reading("luneta", "Luneta templada", "estalla" if bool(rear.shattered) else "entera", CarGlass.rear_row(rear),
				"estimate", "%s; %s" % [CarGlass.REAR_WINDOW_SOURCE.source, String(w.frac.source)]))
		var shield: Variant = scen.get("windshield") if on_glass() else null
		if shield != null:
			out.append_array(_view_reading(shield))
		return out
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return out
	var sh: Variant = hit.get("windshield")
	if sh != null:
		out.append_array(_view_reading(sh))
	return out


func _view_reading(shield: Dictionary) -> Array:
	var vl: Variant = shield.get("viewLoss")
	if vl == null or float(vl.frac) <= 0.0:
		return []
	return [_reading("vista", "Vista del conductor", "tapa ~%s" % fmt_share(float(vl.frac)), CarGlass.view_txt(vl), String(vl.quality),
		String(vl.source))]


## Las marcas del primer plano quieto encima a una velocidad: en un cristal, lo que deja en el vidrio (y la luneta si estalla);
## en la chapa, si la marca atraviesa o la punta perfora, el escalón de CarTear (el mismo que el corte: «perfora» o «raja»), y
## si no, las marcas de siempre.
func closeup_marks_txt(m: Dictionary) -> String:
	if on_glass():
		var mk: Dictionary = m.get("marks", {})
		var txt := CarSpeedMarks.marks_txt(m, target) if float(mk.get("depthUm", 0.0)) > 0.0 else glass_trace_txt(mk)
		var gp := hold_plan()  # unidad 4y: sin resbalar no raya el vidrio (ni el que ha estallado)
		if not gp.is_empty() and not CarHoldMarks.moves(gp):
			txt = CarHoldMarks.txt(gp, m, target, true, String(gp.cause) == CarHoldMarks.CAUSE_SHATTER)
		var rear: Variant = rear_now()
		if rear != null and bool(rear.shattered):
			txt += " · estalla la luneta: pierde el apoyo"
		var shield: Variant = scen.get("windshield")
		if shield != null and bool(shield.cracked):
			txt += " · el parabrisas se agrieta (no cae)"
		return txt
	var t := tear_now()
	if not t.is_empty() and int(t.level) >= 2:
		return String(t.text)
	var p := hold_plan()  # unidad 4y: lo que deja de verdad
	return CarHoldMarks.txt(p, m, target, false, true) if not p.is_empty() else CarSpeedMarks.marks_txt(m, target)


## El primer plano en el golpe contra un cristal: lo que deja en el vidrio y si lo agrieta o lo revienta.
func glass_closeup_impact(now: String) -> String:
	if not glass_zone_now():
		return now
	var parts: Array = []
	var mk: Dictionary = hit.get("marks", {})
	if float(mk.get("depthUm", 0.0)) <= 0.0:
		parts.append("no raya el vidrio")
	else:
		parts.append(now)
	var sh: Variant = hit.get("windshield")
	if sh != null and bool(sh.cracked):
		parts.append("el parabrisas se agrieta (no cae)")
	var sw: Variant = hit.get("sideWindow")
	if sw != null and bool(sw.shattered):
		parts.append("la ventanilla estalla")
	return " · ".join(PackedStringArray(parts))


## El corte del vidrio de lo que se ve ahora (CarGlass.glass_cut): el parabrisas laminado, la luneta o la ventanilla templada.
func glass_cut() -> Dictionary:
	var o := {}
	if mode == MODE_IMPACT:
		if hit.is_empty() or not Js.truthy(hit.get("ok")):
			return {}
		var mk: Dictionary = hit.get("marks", {})
		var sh: Variant = hit.get("windshield")
		var sw: Variant = hit.get("sideWindow")
		var side := sw != null
		o = { "kind": "templado" if side else "laminado", "name": "la ventanilla" if side else "el parabrisas",
			"depthUm": float(mk.get("depthUm", 0.0)), "trace": "raya" if float(mk.get("depthUm", 0.0)) > 0.0 else "mancha",
			"ratio": _claw_hv() / float(MovingCar.Glazing.WINDSCREEN.hv), "cracked": sh != null and bool(sh.cracked),
			"shattered": side and bool(sw.shattered), "fragmentMm": float(sw.fragmentMm) if side else 0.0,
			"pane": MovingCar.Glazing.SIDE_WINDOW.pane, "viewLoss": sh.get("viewLoss") if sh != null else null }
		return CarGlass.glass_cut(o)
	if scen.is_empty() or not Js.truthy(scen.get("ok")):
		return {}
	var m := marks_now()
	var s: Dictionary = m.marks if not m.is_empty() else scen.scratch
	var rear: Variant = rear_now()
	var shield: Variant = scen.get("windshield")
	o = { "kind": "templado" if rear != null else "laminado", "name": "la luneta" if rear != null else "el parabrisas",
		"depthUm": float(s.get("depthUm", 0.0)), "trace": String(s.get("trace", "mancha")), "ratio": float(s.get("ratio", 0.0)),
		"cracked": shield != null and bool(shield.cracked), "shattered": rear != null and bool(rear.shattered),
		"fragmentMm": float(rear.fragmentMm) if rear != null else 0.0, "pane": CarGlass.REAR_WINDOW_PANE,
		"viewLoss": shield.get("viewLoss") if shield != null else null }
	return CarGlass.glass_cut(o)


## Lo que dice la dureza de las garras en la luneta templada (como _hardness_fact en el parabrisas).
func glass_hardness_fact(cl: Dictionary, hv: float, src: String, q: String) -> Dictionary:
	var glass_hv := float(CarGlass.rear_window().hv)
	var k := num(hv)
	var txt := ""
	if hv < glass_hv:
		txt = "%s (%s HV) %s más %s que el vidrio de la luneta (%s HV): no %s ni abrir la grieta que la reventaría; solo su peso la parte, si la flexa más de lo que aguanta." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "blanda", "blandas"), num(glass_hv), _v(cl.pl, "puede rayarla", "pueden rayarla")]
	elif not CarGlass.scratches(hv, glass_hv):
		txt = "%s (%s HV) %s al menos tan %s como el vidrio de la luneta (%s HV): %s abrir la grieta que atraviesa la capa comprimida y reventarla, pero no rayarla, que pide 1.25 veces su dureza." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), num(glass_hv), _v(cl.pl, "puede", "pueden")]
	else:
		txt = "%s (%s HV) %s más de 1.25 veces más %s que el vidrio de la luneta (%s HV): %s rayarla y abrir la grieta que la revienta." % [
			_cap(cl.txt), k, _v(cl.pl, "es", "son"), _v(cl.pl, "dura", "duras"), num(glass_hv), _v(cl.pl, "puede", "pueden")]
	return _fact(txt, "%s; vidrio templado de la luneta: %s HV, el sodocálcico del banco; quién raya a quién: %s" % [src, num(glass_hv),
		CarGlass.R_SCRATCH_SOURCE.source], q)


## La moraleja de la luneta (quieto encima): estallada o entera. "" fuera de ella.
func glass_moral() -> String:
	var rear: Variant = rear_now()
	if rear == null:
		return ""
	if bool(rear.shattered):
		return "La luneta templada no se agrieta: estalla entera. Con %s encima, el problema ya no es el viento, sino el agujero." % animal_a()
	return ""


## «¿Sabías que…?» de los cristales: la luneta templada y lo que tapa una grieta del parabrisas.
func glass_facts() -> Array:
	var out: Array = []
	if not on_glass():
		return out
	if scen.get("rearWindow") != null:
		var w := CarGlass.rear_window()
		out.append(_fact("La luneta es vidrio templado, como las ventanillas: aguanta entera o estalla en trocitos romos de ~%s, nunca a medias. Por eso no se pone en el parabrisas, que tiene que dejar ver aunque se rompa." % [
			CarFormat.fmt_long(float(Glazing.fragment_size_mm(float(w.frac.sigmaS), float(w.E), float(w.frac.nu))) * 1000.0)],
			"%s; %s" % [CarGlass.REAR_WINDOW_SOURCE.source, String(w.frac.source)], "estimate"))
	var shield: Variant = scen.get("windshield")
	if shield != null:
		out.append(_fact("Una grieta en el parabrisas no lo tira, pero tapa, y lo que más importa es dónde cae: la homologación (CEPE R43) marca delante del conductor su zona de visión, la A.",
			CarGlass.VIEW_LOSS_SOURCE.source, "estimate"))
	return out


## Las fuentes de los cristales: el criterio de la raya, la luneta y lo que tapa una grieta.
func _glass_sources(out: Array) -> void:
	if not glass_zone_now():
		return
	out.append(_src("Rayar el vidrio", "la punta tiene que ser al menos 1.25 veces más dura (%s HV)" % num(float(Glazing.WINDSCREEN.hv) * CarGlass.R_SCRATCH),
		String(CarGlass.R_SCRATCH_SOURCE.quality), String(CarGlass.R_SCRATCH_SOURCE.source)))
	if mode == MODE_HOLD and scen.get("rearWindow") != null:
		var p: Dictionary = CarGlass.REAR_WINDOW_PANE
		out.append(_src("Luneta templada", "%s mm · radio equivalente %s mm · %s MPa a flexión" % [num(float(p.t)), num(float(p.a)), num(float(p.fgk))],
			String(CarGlass.REAR_WINDOW_SOURCE.quality), String(CarGlass.REAR_WINDOW_SOURCE.source)))
	var shield: Variant = scen.get("windshield") if mode == MODE_HOLD else hit.get("windshield")
	if shield != null:
		out.append(_src("Lo que tapa una grieta", "parabrisas de %s m² · estrella de %s m de radio · franja de %s cm por surco" % [
			num(CarGlass.WINDSCREEN_M2), num(CarGlass.STAR_RADIUS_M), num(CarGlass.GROOVE_BAND_M * 100.0)],
			String(CarGlass.VIEW_LOSS_SOURCE.quality), String(CarGlass.VIEW_LOSS_SOURCE.source)))


## El rótulo de la vista para los cristales: la luneta que estalla bajo el animal, o lo que tapa al conductor la grieta del
## parabrisas (estimación). short: la corta, para un teléfono. "" si no hay nada que decir.
func glass_view_note(short := false) -> String:
	if not supported():
		return ""
	if mode == MODE_HOLD:
		if scen.is_empty() or not Js.truthy(scen.get("ok")):
			return ""
		var rear: Variant = rear_now()
		if rear != null and bool(rear.shattered):
			var at_v := _rear_shatter_kmh()
			var when := (" a ~%s" % fmt_kmh(at_v)) if at_v > 0.0 else ""
			return ("Estalla la luneta%s: se cae dentro" if short else "Estalla la luneta%s: pierde el apoyo y caen trocitos dentro") % when
		var shield: Variant = scen.get("windshield") if on_glass() else null
		return _view_note(shield, short)
	if hit.is_empty() or not Js.truthy(hit.get("ok")):
		return ""
	return _view_note(hit.get("windshield"), short)


func _view_note(shield: Variant, short := false) -> String:
	if shield == null or not bool(shield.cracked):
		return ""
	var vl: Variant = shield.get("viewLoss")
	if vl == null or float(vl.frac) <= 0.0:
		return "El parabrisas se agrieta: el PVB lo sujeta"
	if short:
		return "La grieta tapa ~%s (estimación)" % fmt_share(float(vl.frac))
	return "La grieta tapa ~%s del parabrisas al conductor (estimación)" % fmt_share(float(vl.frac))


## Por qué se va el animal cuando la luneta estalla bajo él: no lo tira el viento, se queda sin nada debajo. "" si no estalla.
func glass_why() -> String:
	var rear: Variant = scen.get("rearWindow") if on_glass() else null
	if rear == null or not bool(rear.shattered):
		return ""
	var how := "sus garras abren la grieta que atraviesa la capa comprimida del templado (~%s cada una; bastan ~%s)" % [
		fmt_n(float(rear.clawN)), fmt_n(float(rear.pierceN))] if rear.cause == "grieta" else "su peso la parte al flexar (~%s por apoyo; aguanta ~%s)" % [
		fmt_n(float(rear.loadN)), fmt_n(float(rear.bendN))]
	return "No %s tira el viento: %s, y un templado no se agrieta a medias, estalla entero. Sin la luneta debajo, %s se cae por el agujero." % [
		_pro(), how, animal_the()]


## Si la luneta estalla a una velocidad del deslizador antes de que el animal se suelte (el viento tira de las garras
## enganchadas: las rapaces con las alas abiertas, el oso de pie con garras duras), el veredicto lo dice: hasta ahí aguanta,
## y a esa velocidad se queda sin apoyo y se cae dentro. Necesita la gráfica del daño (llega del hilo de lo caro).
func _glass_verdict() -> void:
	if verdict.is_empty() or det.is_empty() or not on_glass() or String(verdict.get("verdict", "")).contains("ESTALLA"):
		return
	var at_v := _rear_shatter_kmh()
	if at_v <= 0.0:
		return
	if not bool(det.atRest):
		return  # ni parado se sostiene (o solo aguanta más deprisa): ya se ha ido antes
	var dk := float(det.kmh) if not bool(det.never) and is_finite(float(det.kmh)) else INF
	if at_v >= dk:
		return
	var rw: Variant = null
	for m: Dictionary in marks_curve().samples:
		if Js.truthy(m.get("rearShattered")):
			rw = m.rearWindow
			break
	if rw == null:
		return
	var v := CarGlass.rear_verdict(rw, inlay, _grammar()[1])
	verdict = {
		"verdict": String(v.verdict).replace("ESTALLA LA LUNETA", "A ~%s km/h ESTALLA LA LUNETA" % CarFormat.kmh_txt(at_v)),
		"vsub": "hasta ahí aguanta, pero el viento tira de sus garras enganchadas; a esa velocidad, %s" % String(v.vsub),
	}


# ════════ Marcas de cada garra (unidad 4y) ════════

## Qué deja cada garra del animal quieto encima a la velocidad del deslizador (CarHoldMarks.plan): la huella de cada garra al
## apoyarse y, solo si se mueven (resbala, la raja corre o se doblan), un surco por garra en la dirección del movimiento. Los
## resbalones de la curva son de grip_now (4u). {} en el golpe, sin animal o mientras llega la gráfica del daño.
func hold_plan() -> Dictionary:
	if mode != MODE_HOLD or scen.is_empty() or not Js.truthy(scen.get("ok")):
		return {}
	var m := marks_now()
	if m.is_empty():
		return {}
	var t := tear_now()
	var tear := float(t.lengthMm) if not t.is_empty() and String(t.get("id", "")) in ["raja", "abre"] else 0.0
	return _hold_plan_of(m, tear)


func _hold_plan_of(m: Dictionary, tear_mm: float) -> Dictionary:
	var h: Dictionary = scen.get("holdCtx", {})
	var lat := float(at.get("lateralN", 0.0)) if not at.is_empty() else 0.0
	var side := signf(lat) if lat != 0.0 else signf(float(scen.get("wc", 0.0)))
	# cómo se ha soltado: si el coche ya ha pasado de la velocidad del despegue, como se soltó allí (el modo del despegue:
	# resbala hacia atrás o despega); si no (una ventana que solo aguanta más deprisa), el de esta velocidad
	var how := String(at.get("mode", "")) if not at.is_empty() else ""
	if not det.is_empty() and bool(det.get("atRest", false)) and is_finite(float(det.get("kmh", INF))) and v_kmh >= float(det.kmh) \
			and String(det.get("mode", "")) != "":
		how = String(det.mode)
	var rear: Variant = rear_now()  # unidad 4y: la luneta que ha estallado ya no se raya
	var shattered := rear != null and Js.truthy((rear as Dictionary).get("shattered"))
	return CarHoldMarks.plan(m, {
		"shattered": shattered, "shatterQuality": String((rear as Dictionary).get("quality", "")) if shattered else "",
		"shatterSource": String((rear as Dictionary).get("source", "")) if shattered else "",
		"claws": int(h.get("nContact", 1)), "holds": Js.truthy(at.get("holds", true)) if not at.is_empty() else true,
		"mode": how, "side": side if side != 0.0 else 1.0,
		"slideMm": float(h.get("slideMm", 0.0)), "tearMm": tear_mm, "glass": on_glass(), "embedded": Js.truthy(scen.get("embedded")),
		"curve": curve_on(), "fracMode": marks_frac_mode(), "brokenMm": marks_broken_mm(), "panelUm": MovingCar.panel_um(target) })


## Lo que deja en palabras (CarHoldMarks.txt), de acuerdo con el dibujo; short: sin el «si resbalara» (el primer plano).
func hold_plan_txt(short := false) -> String:
	return CarHoldMarks.txt(hold_plan(), marks_now(), target, on_glass(), short)


## Las capas que corta lo que se ve quieto encima: las de los surcos si se mueven; si no, las de la huella de la punta.
func hold_visible_layers() -> Array:
	var p := hold_plan()
	var m := marks_now()
	if p.is_empty() or m.is_empty():
		return (hold_marks().get("layers", []) as Array)
	if CarHoldMarks.moves(p):
		return (m.get("layers", []) as Array)
	return MovingCar.layers_crossed(target, CarHoldMarks.visible_depth_um(p)) if target.get("body") != null and not on_glass() else []
