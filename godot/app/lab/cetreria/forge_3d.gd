## Laboratorio experimental de la reforja en 3D (unidad 5f): el taller de la reforja, hecho en código y sin descargas.
## - A la izquierda, el banco de los polvos: la balanza con su plato y su pantalla, los tarros de ForgeData.POWDERS (uno
##   por polvo, con su fórmula), el crisol o el alimentador que se llena con lo pesado, la caja de las piedras compradas y
##   el estuche del acrílico dental (el polvo y el líquido de la prótesis de verdad de una garra rota; unidad 5j).
## - En el centro, el horno-fundidor (FICCIÓN en conjunto: cada modo es una máquina real) con su cámara a la vista tras la
##   ventanilla y el panel de los ocho mandos de ClawForge.controls(): diales de la temperatura (con el margen de la
##   receta pintado en verde), del tiempo, de la presión y del metano; selectores del modo, de la atmósfera, del molde y
##   del enfriamiento; el botón rojo de arrancar y el amarillo de sacar y enfriar.
## - Dentro, lo de cada modo: la llama de oxígeno e hidrógeno y la bola que crece hacia abajo (Verneuil), la bobina de
##   inducción y el crisol al rojo, la prensa que se cierra (HPHT), el plasma violeta sobre el molde (CVD), la pieza que
##   encoge al sinterizar y la colada en el molde. Al lado, el cubo del temple, que hierve.
## - A la derecha, el taller: la muela con su agua, la pulidora, la garra en su soporte (la malla de la garra de la
##   cetrería, claw_mesh.gd) con la mitad que tiene carne viva marcada, la barrera, la funda que se pega, la pistola de
##   proyección, la campana de vacío, el baño de cromo, la jeringa del adhesivo, la pesa de la prueba y, en la ficción, el
##   termómetro de la carne viva con su rótulo FICCIÓN.
## La escena no calcula física: pinta la vista de ClawForgeState (core/lab/claw_forge_state.gd) que le pasa la página con
## show_view(), con las mallas de la garra y de la funda hechas en el hilo (forge_runner.gd). El color de lo caliente es el
## del cuerpo negro de core (la rampa de Incandescence que trae la vista); la escena solo lo interpola y lo pinta. Las
## piezas de la reforja (la bola, el cristal, la funda, la capa y la garra reforjada) llevan los materiales de la biblioteca
## común de las garras (ClawMaterial, unidad 5e: los datos ópticos de cada material con su acabado), sin materiales
## propios; el brillo del calor va encima, en una capa aditiva (material_overlay), para no tocar el material compartido.
## Mandos (la escena los convierte en gestos: señal gesture(op, args), que la página manda a su hilo):
##   izquierdo sobre un tarro          lo coge (otro clic lo deja); arrastrado hasta el plato de la balanza, o mantenido
##                                     sobre él, vierte (Mayús: gota a gota); al soltar, deja de verter
##   izquierdo sobre un dial           lo elige; arrastrar arriba o abajo lo gira (Mayús: paso fino); rueda: un paso
##   izquierdo sobre un selector       pasa a la opción siguiente (o arrastrar)
##   izquierdo sobre un botón o un     arrancar, sacar y enfriar, cargar el crisol, comprar la piedra, mezclar el acrílico,
##   sitio del taller                  tallar, proteger, recubrir, pegar, pulir o probar
##   derecho · central · rueda         girar la cámara · desplazarla · acercar
##   un dedo · dos dedos               tocar (coger, verter una dosis, elegir un dial, pulsar) · la cámara
## 5m (petición 42): la carga se mete en su máquina por la puerta del horno, que se abre y se cierra (un clic en ella, o
## arrastrar el crisol hasta ella: gesto insert_charge); dentro, cada máquina enseña su carga solo si está metida (la alúmina en
## la tolva de Verneuil, la cápsula entre los yunques, el sustrato bajo la campana, la pastilla prensada en la bandeja, el crisol
## en la bobina, el molde de la cera perdida en la bandeja o en la máquina de colar). La cera perdida en el banco de los polvos:
## el modelo de cera de la funda con su bebedero y el molde revestido; la pieza colada sale del molde con su bebedero. El tallado
## por pasadas: la pieza en su palo va a la sierra de disco con su bandeja de agua, a la máquina de muelas en fila con su goteo
## (la gruesa y la fina) o al eje flexible con su fresa, y su silueta va del tocho a la funda con lo que dice el motor.
## Rendimiento: todo se construye una vez por calidad; en cada fotograma solo se mueven transformaciones, colores y los
## búferes de los MultiMesh (nada se crea); las mallas de la garra y de la funda, solo con una forma nueva.
## En el teléfono, las vistas encuadran lo suyo a la izquierda del deslizador grande de la página (set_inset_right; unidad
## 5j): presentación, no física.
## La sala (5m; petición 45): el taller tiene ventanas al campo (la hierba hasta el horizonte, unas lomas, el cielo y el sol del
## entorno) y sus materiales tienen relieve (forge_looks.gd: madera, acero cepillado, hierro fundido, refractario, ladrillo,
## hormigón y vidrio); las mesas y el horno, volumen (el canto del tablero, el faldón, los travesaños, los pies, la peana y los
## tornillos, todos en un solo MultiMesh). Nada de eso cambia en los fotogramas.
## Unidades: metros (las piezas y la garra, en mm dentro de su nodo, con escala 0,001).
extends Node3D

signal gesture(op: String, args: Array)

const Props = preload("res://app/lab/cetreria/forge_props.gd")
const ForgeLooks = preload("res://app/lab/cetreria/forge_looks.gd")
const Palette = preload("res://app/theme/palette.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const ClawLook = preload("res://app/lab/cetreria/claw_look.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CareOrbit = preload("res://app/lab/cetreria/care_orbit.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Incandescence = preload("res://core/lab/incandescence.gd")
const Js = preload("res://core/shared/js.gd")
const KERATIN_SHADER = preload("res://app/lab/cetreria/keratin.gdshader")

const VIEWS := ["general", "banco", "horno", "dentro", "taller", "pieza", "soldar"]
const VIEW_NAMES := { "general": "General", "banco": "La balanza", "horno": "Horno", "dentro": "Dentro", "taller": "Taller", "pieza": "La pieza", "soldar": "Soldar" }
const MM := 0.001
const BENCH_H := 0.9
## El banco de los polvos.
const SCALE_POS := Vector3(-0.72, BENCH_H, 0.08)
const PAN_Y := 0.058
const CRUCIBLE_POS := Vector3(-0.45, BENCH_H, 0.13)
const STONE_POS := Vector3(-1.12, BENCH_H, 0.15)
## El estuche del acrílico dental (la prótesis de verdad de una garra rota; unidad 5j): el polvo y el líquido.
const ACRYLIC_POS := Vector3(-0.94, BENCH_H, 0.15)
const JAR_X0 := -1.18
const JAR_DX := 0.112
const JAR_Z := [-0.1, -0.22]
const JAR_R := 0.032
const JAR_H := 0.1
## El horno: la cara de delante en z = FRONT_Z; la cámara, tras la ventanilla.
const FRONT_Z := 0.02
const CHAMBER := Vector3(0.0, 0.93, -0.26)
const CAVITY := Vector3(0.42, 0.38, 0.52)
## Los mandos del panel: [id, x, y].
const PANEL := [["modo", -0.21, 0.61], ["temp_c", -0.07, 0.61], ["time_s", 0.07, 0.61], ["pressure_mpa", 0.21, 0.61],
	["atmosphere", -0.21, 0.45], ["methane", -0.07, 0.45], ["mold", 0.07, 0.45], ["cool", 0.21, 0.45]]
## La placa del panel de mandos (m) y la mitad de su ancho con su margen: lo que encuadra la vista «Horno».
const PANEL_SIZE := Vector2(0.58, 0.44)
const PANEL_HALF_W := 0.31
const START_POS := Vector3(-0.09, 0.31, FRONT_Z + 0.03)
const COOL_POS := Vector3(0.09, 0.31, FRONT_Z + 0.03)
const KNOB_R := 0.022
const BUCKET_POS := Vector3(0.48, 0.0, 0.34)
## El taller.
const GRINDER_POS := Vector3(0.78, BENCH_H, -0.08)
const WHEEL_R := 0.075
const POLISHER_POS := Vector3(0.99, BENCH_H, -0.16)
const CLAW_POS := Vector3(1.16, BENCH_H + 0.1, 0.08)
const BRICK_POS := Vector3(0.66, BENCH_H, 0.2)
const GUN_POS := Vector3(1.4, BENCH_H + 0.12, 0.16)
const BELL_POS := Vector3(0.98, BENCH_H, 0.2)
const BATH_POS := Vector3(1.38, BENCH_H, -0.13)
const SYRINGE_POS := Vector3(1.08, BENCH_H + 0.012, 0.26)
const THERMO_POS := Vector3(1.32, BENCH_H + 0.13, -0.02)
## 5m · la cera perdida en el banco de los polvos (el modelo de cera y el molde revestido), las herramientas del lapidario (la
## sierra de disco con su bandeja de agua y el eje flexible con su fresa) y las muelas en fila (x de cada una sobre su eje).
const WAX_POS := Vector3(-0.56, BENCH_H, 0.24)
const FLASK_R := 0.03
const FLASK_H := 0.07
const WAX_COLOR := Color(0.37, 0.61, 0.48)
const SAW_POS := Vector3(0.63, BENCH_H, -0.2)
const SAW_R := 0.076
const BURR_POS := Vector3(1.18, BENCH_H, -0.22)
const WHEEL_X := { "muela_gruesa": -0.034, "muela_fina": 0.0 }
## El color de dibujo de lo que se mete en cada máquina (la carga que entra por la puerta).
const CARRY_COLORS := { "crisol": "#47443F", "alimentador": "#F2F0EA", "capsula": "#C7B48C", "sustrato": "#8E949B", "pastilla": "#B9BCC0", "molde": "#EDE8DC", "pieza": "#C7CDD6" }
## Píxeles de arrastre por paso de un dial.
const DRAG_PX := 14.0
## Burbujas, vapor, gotas y polvo (dibujo): cuántas como mucho.
const BUBBLES := 48
const STEAM := 24
const DROPS := 14
const POWDER := 18
## Colores de dibujo de cada polvo en su tarro (no son datos).
const POWDER_COLORS := {
	"al2o3": "#F2F0EA", "cr2o3": "#3E7D3A", "mgo": "#F7F7F2", "wc": "#4A4D52", "co": "#9EA3AA", "grafito": "#1E1F22",
	"fe_co": "#55595F", "ch4_h2": "#D9DDE3", "oro": "#E2B13C", "acero": "#A8AEB5", "titanio": "#8C9198", "vidrio": "#CFE6EE",
}
## Color de dibujo de cada molde y de cada barrera.
const MOLD_COLORS := { "yeso": "#EDE8DC", "ceramico": "#C9A97A", "grafito": "#26272A" }
const BARRIER_COLORS := { "silicona": Color(0.85, 0.32, 0.22, 0.7), "aerogel": Color(0.86, 0.9, 0.96, 0.92), "gel": Color(0.35, 0.6, 0.95, 0.5) }
## Lo que se ilumina en el tutorial: el sitio de cada cosa (y su radio).
const HIGHLIGHT_R := { "balanza": 0.13, "crisol": 0.07, "horno": 0.45, "ventana": 0.26, "arrancar": 0.04, "sacar": 0.04,
	"pieza": 0.05, "muela": 0.11, "barrera": 0.06, "pistola": 0.08, "adhesivo": 0.06, "pulidora": 0.08, "carga": 0.06,
	"garra": 0.07, "tienda": 0.08, "acrilico": 0.07, "puerta": 0.26, "cera": 0.06, "sierra": 0.1, "fresa": 0.08, "soldadura": 0.12 }

## 5r · la mesa de soldar, a la derecha del taller: la mesa, el soporte con las dos piezas (la funda partida por la costura) y el
## aparato de cada método (la cabina del láser con su microscopio, el micro-TIG con su antorcha y la botella de argón, el soplete con
## la plata y el fundente). Las cuentas de la costura, cuántas como mucho (un MultiMesh), lo que tarda en enfriarse el punto
## incandescente y en apagarse el destello (dibujo), lo lejos que puede estar el puntero de la costura (px) y las muestras de la
## vuelta para buscarlo.
const WELD_POS := Vector3(2.32, BENCH_H, 0.0)
const WELD_FIX := Vector3(2.3, BENCH_H + 0.045, 0.07)
const WELD_BEADS := 200
const WELD_COOL_S := 0.6
const WELD_FLASH_S := 0.12
const WELD_PICK_PX := 48.0
const WELD_SAMPLES := 72

@export var auto_process := true
var quality := ""
var view_name := "general"
## Lo que tapan los mandos de la página sobre la vista por la derecha (fracción del ancho; set_inset_right) y la proporción
## de la vista entera (la de _apply_view).
var inset_right := 0.0
var _aspect := 1.0
var _built := false
var _rig: CareOrbit
var _sun: DirectionalLight3D
var _world: Node3D
var _v: Dictionary = {}
var _v_serial := -1
var _t := 0.0
var _targets: Array = []
var _ramp: Array = []
# el banco de los polvos
var _jars := {}
var _jar_rest := {}
var _pan: MeshInstance3D
var _heap: MeshInstance3D
var _heap_mat: StandardMaterial3D
var _scale_label: Label3D
var _crucible_bench: MeshInstance3D
var _crucible_fill: MeshInstance3D
var _crucible_fill_mat: StandardMaterial3D
var _stream: MeshInstance3D
var _stream_mat: StandardMaterial3D
# el horno
var _chamber: Node3D
var _cavity_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
var _controls := {}
var _start_mat: StandardMaterial3D
var _cool_mat: StandardMaterial3D
var _modes := {}
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _boule: Node3D
var _boule_body: MeshInstance3D
var _boule_cap: MeshInstance3D
var _boule_glow: StandardMaterial3D
var _pedestal: MeshInstance3D
var _coil_mat: StandardMaterial3D
var _melt_crucible: Node3D
var _melt: MeshInstance3D
var _melt_mat: StandardMaterial3D
var _pour: MeshInstance3D
var _pour_mat: StandardMaterial3D
var _mold: MeshInstance3D
var _mold_mat: StandardMaterial3D
var _anvil_top: MeshInstance3D
var _anvil_bottom: MeshInstance3D
var _capsule_mat: StandardMaterial3D
var _capsule: MeshInstance3D
var _gauge: Label3D
var _plasma: MeshInstance3D
var _plasma_mat: StandardMaterial3D
var _cvd_mold: MeshInstance3D
var _cvd_mat: StandardMaterial3D
var _heater_mat: StandardMaterial3D
var _tray: MeshInstance3D
var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
# la pieza (bola, cristal, bloque o funda), en mm
var _piece: Node3D
var _piece_shapes := {}
## Las piezas sueltas (la bola, el cristal, el bloque: otra malla) y todas (con la funda) para el brillo del calor.
var _piece_loose: Array = []
var _piece_mis: Array = []
var _piece_glow: StandardMaterial3D
## La máquina que enfoca la vista «Dentro» (se vuelve a enfocar si cambia).
var _dentro_mode := ""
## Clave de los materiales de la biblioteca puestos (se ponen solo cuando cambia), los de cada grupo ([frío, al rojo]:
## al rojo, el opaco de la biblioteca, sobre el que se ve la capa del calor) y si cada grupo brilla.
var _look_key := ""
var _looks := {}
var _hot := {}
var _piece_key := ""
## La superficie de la funda tallada o pulida (unidad 5j): su textura y la clave de lo que la cambia.
var _surface_key := ""
var _surface_tex: ImageTexture = null
var _sheath_mesh := ArrayMesh.new()
var _sheath_key := ""
var _sheath_center := Vector3.ZERO
# el taller
var _wheel: Node3D
var _polish_wheel: Node3D
var _claw: Node3D
var _claw_mesh := ArrayMesh.new()
var _claw_mat: ShaderMaterial
var _claw_key := ""
var _claw_k := 0.0
var _claw_sheath: MeshInstance3D
var _barrier: MeshInstance3D
var _barrier_mesh := ArrayMesh.new()
var _barrier_mat: StandardMaterial3D
var _coat_shell: MeshInstance3D
var _coat_mesh := ArrayMesh.new()
var _coat_key := ""
var _barrier_key := ""
var _gun_plume: MeshInstance3D
var _plume_mat: StandardMaterial3D
var _bell: Node3D
var _bell_glow_mat: StandardMaterial3D
var _bath_liquid_mat: StandardMaterial3D
var _weight: Node3D
var _weight_label: Label3D
var _thermo: Node3D
var _thermo_label: Label3D
var _thermo_fill: MeshInstance3D
var _thermo_fill_mat: StandardMaterial3D
var _fiction_label: Label3D
var _furnace_label: Label3D
# 5m · la puerta y la carga que entra, lo de cada máquina, la cera perdida y el tallado por pasadas
var _door: Node3D
var _carry: MeshInstance3D
var _carry_mat: StandardMaterial3D
var _carry_kind := ""
var _hopper_fill: MeshInstance3D
var _pellet: MeshInstance3D
var _pellet_mat: StandardMaterial3D
var _capsule_in := false
var _wax_model: Node3D
var _flask: MeshInstance3D
var _flask_mat: StandardMaterial3D
var _flask_oven: MeshInstance3D
var _flask_oven_mat: StandardMaterial3D
var _flask_cast: MeshInstance3D
var _cast_fill: MeshInstance3D
var _cast_fill_mat: StandardMaterial3D
var _sprue: MeshInstance3D
var _dop: MeshInstance3D
var _saw_disc: Node3D
var _burr: Node3D
var _burr_rest := Vector3.ZERO
var _carve_mesh := ArrayMesh.new()
var _carve_key := ""
var _dop_key := ""
var _lost_wax_on := false
## 5m · los tornillos de la sala (las mesas y el horno), que van en un solo MultiMesh.
var _bolt_xforms: Array = []
# resaltados
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _highlight_id := ""
var _selected_ring: MeshInstance3D
# partículas
var _bubbles_mmi: MultiMeshInstance3D
var _steam_mmi: MultiMeshInstance3D
var _drops_mmi: MultiMeshInstance3D
var _powder_mmi: MultiMeshInstance3D
var _bubbles_buf := PackedFloat32Array()
var _steam_buf := PackedFloat32Array()
var _drops_buf := PackedFloat32Array()
var _powder_buf := PackedFloat32Array()
# animación suavizada
var _boule_len := 0.0
var _anvil_gap := 1.0
var _tilt := 0.0
var _shrink := 0.0
var _needles := {}
var _labels_key := {}
var _arc_keys := {}
# el puntero
var _pointer := Vector2(-1.0, -1.0)
var _has_pointer := false
var _pressed := false
var _press_target := ""
var _press_pos := Vector2.ZERO
## El tarro que había en la mano al apretar (un clic sobre el mismo lo deja; el clic que lo coge, no).
var _press_held := ""
var _drag_acc := 0.0
var _dragged := false
var _shift := false
var _cam_drag := ""
var _touches := {}
var _pinch := 0.0
var _pouring := false
var _held_pos := Vector3.ZERO
# métricas
var _upd_n := 0
var _upd_sum := 0
var _upd_max := 0
var _mesh_builds := 0
var _glow_seen := {}
# 5r · la mesa de soldar
var _weld_root: Node3D
var _weld_work: Node3D
var _weld_base: MeshInstance3D
var _weld_tip: MeshInstance3D
var _weld_base_mesh := ArrayMesh.new()
var _weld_tip_mesh := ArrayMesh.new()
var _weld_mesh_key := ""
var _weld_devices := {}
var _weld_beads: MultiMeshInstance3D
var _weld_bead_mat: StandardMaterial3D
var _weld_hot: MeshInstance3D
var _weld_hot_mat: StandardMaterial3D
var _weld_flash: OmniLight3D
var _weld_aim: MeshInstance3D
var _weld_rod: MeshInstance3D
var _weld_jaw: Node3D
## Las piezas de la pinza de joyero que se ajustan al grosor de la funda: las dos mordazas, el puente de abajo, el tornillo y su
## pomo.
var _weld_jaw_parts: Dictionary = {}
var _weld_tip_mat_key := ""
## La costura en el marco de la pieza (mm): estación, radio por fuera y curvatura; el último efecto visto, cuánto hace del último
## punto (s), lo que hace el puntero apretado sobre la costura («soldar», «alinear» o «») y el último u mandado.
var _weld_s := 0.0
var _weld_r := 1.0
var _weld_k := 0.0
var _weld_fx_seen := -1
var _weld_hot_t := 99.0
var _weld_mode := ""
var _weld_last_u := -2.0


func _ready() -> void:
	_ensure_built()
	_apply_view(true)


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


# ───────────────────────────── API ─────────────────────────────

func set_quality(preset: String) -> void:
	quality = preset
	_ensure_built()
	_apply_quality()


func is_mobile() -> bool:
	return quality == "movil" or (quality == "" and OS.has_feature("mobile"))


## «general», «banco», «horno», «dentro», «taller» o «pieza».
func set_view(n: String, instant := false) -> void:
	if not VIEWS.has(n):
		push_warning("Vista desconocida: %s" % n)
		return
	view_name = n
	_ensure_built()
	_apply_view(instant)


func camera() -> Camera3D:
	return _rig.camera()


func node_count() -> int:
	return _count(self)


static func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c


## Datos para la interfaz y los tests.
func info() -> Dictionary:
	var rv: Dictionary = _v.get("run", {})
	return {
		"view": view_name, "frames": _upd_n, "update_ms_avg": float(_upd_sum) / float(maxi(_upd_n, 1)) / 1000.0,
		"update_ms_max": float(_upd_max) / 1000.0, "quality": "movil" if is_mobile() else "escritorio", "mesh_builds": _mesh_builds,
		"mode": _visible_mode(), "run_kind": String(rv.get("kind", "")), "boule_mm": _boule_len, "anvil_gap": _anvil_gap,
		"piece_at": String(_v.get("piece", {}).get("at", "")), "piece_shape": _piece_key, "held": String(_v.get("bench", {}).get("held", "")),
		"highlight": _highlight_id, "pressed": _pressed, "targets": _targets.size(), "surface": _surface_key,
		# 5m · la puerta, lo que entra, lo que hay en cada máquina, la cera perdida y el tallado
		"door": _door.position.y, "carry": _carry_kind if _carry.visible else "", "hopper": _hopper_fill.visible,
		"capsule": _capsule.visible, "pellet": _pellet.visible, "crucible": _melt_crucible.visible, "substrate": _cvd_mold.visible,
		"wax_model": _wax_model.visible, "flask": _flask.visible, "flask_oven": _flask_oven.visible, "flask_cast": _flask_cast.visible,
		"sprue": _sprue.visible, "dop": _dop.visible, "piece_pos": _piece.position,
		# 5r · la mesa de soldar: la pieza en el soporte, las cuentas de la costura y el aparato que se ve
		"weld_work": _weld_work.visible, "weld_beads": _weld_beads.multimesh.visible_instance_count,
		"weld_device": _weld_visible_device(),
	}


## Punto de la pantalla (px del visor) de un sitio de la escena (un mando, un tarro, un botón o un sitio del taller): para
## la demo y los tests, que mueven el ratón como una persona. (−1, −1) si queda detrás de la cámara.
func target_screen_point(id: String) -> Vector2:
	for t: Dictionary in _targets:
		if String(t.id) == id:
			var p := (t.aabb as AABB).get_center()
			if _rig.camera().is_position_behind(p):
				return Vector2(-1.0, -1.0)
			return _rig.camera().unproject_position(p)
	return Vector2(-1.0, -1.0)


## 5r · el punto de la pantalla de la costura en u (0-1 a lo largo de la vuelta), para la demo y los tests; (−1, −1) sin piezas
## en la mesa o detrás de la cámara.
func weld_seam_screen_point(u: float) -> Vector2:
	if _weld_work == null or not _weld_work.visible:
		return Vector2(-1.0, -1.0)
	var w := _weld_work.global_transform * ClawMesh.surface_point(_weld_s, _weld_r, _weld_k, u * TAU)
	if _rig.camera().is_position_behind(w):
		return Vector2(-1.0, -1.0)
	return _rig.camera().unproject_position(w)


## El sitio que hay bajo un punto de la pantalla («» si nada).
func hit_at(px: Vector2) -> String:
	if _rig == null:
		return ""
	var cam := _rig.camera()
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	var best := ""
	var best_t := INF
	for t: Dictionary in _targets:
		var hit: Variant = (t.aabb as AABB).intersects_ray(o, d)
		if hit != null:
			var dist := o.distance_to(hit as Vector3)
			if dist < best_t:
				best_t = dist
				best = String(t.id)
	return best


# ───────────────────────────── construcción ─────────────────────────────

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_environment()
	_world = Props.node(self, "Mundo")
	_build_room()
	_build_powder_bench()
	_build_lost_wax()
	_build_furnace()
	_build_bucket()
	_build_workshop()
	_build_weld_table()
	_build_piece()
	_build_fx()
	_build_highlight()
	_build_bolts()
	_rig = CareOrbit.new()
	add_child(_rig)
	_rig.min_distance = 0.03
	_rig.max_distance = 6.0
	_rig.camera().current = true
	_apply_quality()


## La luz y el entorno (5m; petición 45): el cielo de un día claro sobre el campo (ProceduralSkyMaterial: azul arriba, claro en el
## horizonte y verde por debajo, como la hierba que sigue hasta él), que se ve por las ventanas y se refleja en el acero, y el sol.
func _build_environment() -> void:
	# el cielo que se refleja (5q, petición 56): el de fuera, por las ventanas, con el campo abajo. Lo que refleja un metal
	# pulido en la mesa es sobre todo este cielo (la sala de ladrillo no está en el cielo): claro, no oscuro
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.56, 0.84)
	sky_mat.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.ground_horizon_color = Color(0.56, 0.63, 0.47)
	sky_mat.ground_bottom_color = Color(0.3, 0.38, 0.22)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.name = "Entorno"
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.light_energy = 1.1
	_sun.light_color = Color(1.0, 0.96, 0.9)
	_sun.basis = Basis.looking_at(Vector3(0.5, -1.4, -0.9), Vector3.UP)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 4.0
	add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Relleno"
	fill.light_energy = 0.35
	fill.light_color = Color(0.78, 0.84, 1.0)
	fill.light_specular = 0.25
	fill.basis = Basis.looking_at(Vector3(-0.8, -0.5, -0.9), Vector3.UP)
	add_child(fill)


## La sala del taller (5m; petición 45): el suelo de hormigón, la pared del fondo de ladrillo con dos ventanas al campo (el marco,
## el alféizar, el parteluz, el travesaño y el vidrio), las paredes de los lados y el techo con sus vigas, de una sola cara (desde
## fuera de la sala no tapan) y sin sombra (el sol entra por delante, por detrás de la cámara: dibujo); fuera, la hierba hasta el
## horizonte con unas lomas. Las mesas, con volumen; los tornillos de las mesas y del horno, en un solo MultiMesh.
func _build_room() -> void:
	var mob := is_mobile()
	var concrete := ForgeLooks.material("hormigon", mob)
	var brick := ForgeLooks.material("ladrillo", mob)
	var frame_mat := ForgeLooks.material("acero", mob, Color(0.2, 0.22, 0.25))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8.0, 6.0)
	Props.mi(_world, floor_mesh, concrete, "Suelo", Vector3(0.1, 0.0, -0.4))
	# la pared del fondo, con dos huecos de 1,4 × 1,2 m para las ventanas
	var walls := Props.node(_world, "Paredes")
	var wz := -1.16
	for piece: Array in [[Vector3(0.1, 0.525, wz), Vector3(8.0, 1.05, 0.12)], [Vector3(0.1, 2.725, wz), Vector3(8.0, 0.95, 0.12)],
			[Vector3(-3.05, 1.65, wz), Vector3(1.7, 1.2, 0.12)], [Vector3(0.1, 1.65, wz), Vector3(1.8, 1.2, 0.12)], [Vector3(3.25, 1.65, wz), Vector3(1.7, 1.2, 0.12)]]:
		var w := Props.mi(walls, Props.box(piece[1]), brick, "Pared", piece[0])
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for cx: float in [-1.5, 1.7]:
		_build_window(walls, Vector3(cx, 1.65, wz), Vector2(1.4, 1.2), frame_mat)
	# las paredes de los lados, la de delante y el techo: planos que miran hacia dentro
	for pl: Array in [[PlaneMesh.FACE_X, Vector2(3.8, 3.2), Vector3(-3.9, 1.6, 0.74), 0.0], [PlaneMesh.FACE_X, Vector2(3.8, 3.2), Vector3(4.1, 1.6, 0.74), PI],
			[PlaneMesh.FACE_Z, Vector2(8.0, 3.2), Vector3(0.1, 1.6, 2.64), PI]]:
		var pm := PlaneMesh.new()
		pm.orientation = pl[0]
		pm.size = pl[1]
		var side := Props.mi(walls, pm, concrete, "ParedLado", pl[2])
		side.rotation.y = float(pl[3])
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ceil := PlaneMesh.new()
	ceil.size = Vector2(8.0, 3.9)
	var roof := Props.mi(walls, ceil, concrete, "Techo", Vector3(0.1, 3.2, 0.74))
	roof.rotation.x = PI
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for bz: float in [-0.5, 0.75, 2.0]:
		var beam := Props.mi(walls, Props.box(Vector3(8.0, 0.2, 0.1)), frame_mat, "Viga", Vector3(0.1, 3.1, bz))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# fuera: la hierba hasta el horizonte y unas lomas
	var outside := Props.node(_world, "Campo")
	var grass := PlaneMesh.new()
	grass.size = Vector2(400.0, 200.0)
	var field := Props.mi(outside, grass, ForgeLooks.material("hierba", mob), "Hierba", Vector3(0.1, -0.01, -101.3))
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hill_mat := ForgeLooks.material("hierba", mob, Color(0.27, 0.42, 0.2))
	for hl: Array in [[Vector3(-45.0, -2.0, -80.0), Vector3(38.0, 7.0, 16.0)], [Vector3(20.0, -2.5, -110.0), Vector3(55.0, 9.0, 20.0)], [Vector3(70.0, -2.0, -70.0), Vector3(30.0, 6.0, 14.0)]]:
		var hill := Props.mi(outside, Props.sphere(1.0, 16), hill_mat, "Loma", hl[0])
		hill.scale = hl[1]
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# las mesas, con volumen, y sus rótulos
	var bolts: Array = []
	for b: Array in [[-0.8, 0.95], [1.03, 0.95]]:
		_build_table(float(b[0]), float(b[1]), mob, bolts)
	Props.label(_world, "BANCO DE LOS POLVOS", Vector3(-0.8, BENCH_H + 0.005, 0.29), 0.0005, Color(0.95, 0.85, 0.6)).rotation.x = -PI * 0.5
	Props.label(_world, "TALLER", Vector3(1.03, BENCH_H + 0.005, 0.29), 0.0005, Color(0.95, 0.85, 0.6)).rotation.x = -PI * 0.5
	_bolt_xforms = bolts


## Una ventana al campo en un hueco de la pared (5m): el marco, el alféizar (más ancho y más hondo), el parteluz, un travesaño y el
## vidrio.
func _build_window(parent: Node3D, c: Vector3, size: Vector2, mat: Material) -> void:
	var fw := 0.05
	var depth := 0.15
	for e: Array in [[Vector3(0, size.y * 0.5 - fw * 0.5, 0), Vector3(size.x, fw, depth)], [Vector3(0, -size.y * 0.5 + fw * 0.7, 0.02), Vector3(size.x + 0.1, fw * 1.4, depth + 0.08)],
			[Vector3(-size.x * 0.5 + fw * 0.5, 0, 0), Vector3(fw, size.y, depth)], [Vector3(size.x * 0.5 - fw * 0.5, 0, 0), Vector3(fw, size.y, depth)],
			[Vector3.ZERO, Vector3(0.035, size.y, 0.05)], [Vector3(0, size.y * 0.14, 0), Vector3(size.x, 0.03, 0.05)]]:
		Props.mi(parent, Props.box(e[1]), mat, "Marco", c + e[0])
	var g := Props.mi(parent, Props.box(Vector3(size.x - 2.0 * fw, size.y - 2.0 * fw, 0.006)), ForgeLooks.glass(), "Vidrio", c)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Una mesa con volumen (5m): el tablero de madera con su canto (una banda más oscura y metida debajo: el bisel, de dibujo), el
## faldón, las patas de tubo de acero con sus pies, los travesaños de abajo y los tornillos del faldón (en bolts, para el
## MultiMesh).
func _build_table(x: float, w: float, mob: bool, bolts: Array) -> void:
	var wood := ForgeLooks.material("madera", mob)
	var dark_wood := ForgeLooks.material("madera", mob, Color(0.33, 0.23, 0.15))
	var steel := ForgeLooks.material("acero", mob)
	var d := 0.62
	var root := Props.node(_world, "Mesa", Vector3(x, 0.0, 0.0))
	Props.mi(root, Props.box(Vector3(w, 0.04, d)), wood, "Tablero", Vector3(0, BENCH_H - 0.02, 0))
	Props.mi(root, Props.box(Vector3(w - 0.016, 0.012, d - 0.016)), dark_wood, "Canto", Vector3(0, BENCH_H - 0.046, 0))
	var ay := BENCH_H - 0.088
	for sz: float in [-1.0, 1.0]:
		Props.mi(root, Props.box(Vector3(w - 0.1, 0.07, 0.02)), dark_wood, "Faldon", Vector3(0, ay, sz * (d * 0.5 - 0.05)))
	for sx: float in [-1.0, 1.0]:
		Props.mi(root, Props.box(Vector3(0.02, 0.07, d - 0.1)), dark_wood, "Faldon", Vector3(sx * (w * 0.5 - 0.05), ay, 0))
	var leg_h := BENCH_H - 0.052
	for lx: float in [-(w * 0.5 - 0.05), w * 0.5 - 0.05]:
		for lz: float in [-0.26, 0.26]:
			Props.mi(root, Props.box(Vector3(0.035, leg_h, 0.035)), steel, "Pata", Vector3(lx, leg_h * 0.5, lz))
			Props.mi(root, Props.cyl(0.024, 0.028, 0.014, 12), steel, "Pie", Vector3(lx, 0.007, lz))
			# dos tornillos en el faldón, junto a la pata (en la cara de fuera)
			var out_z := signf(lz) * (d * 0.5 - 0.05 + 0.011)
			for dx: float in [-0.025, 0.025]:
				bolts.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x + lx - signf(lx) * 0.05 + dx, ay, out_z)))
	for lz: float in [-0.26, 0.26]:
		Props.mi(root, Props.box(Vector3(w - 0.1, 0.025, 0.02)), steel, "Travesano", Vector3(0, 0.16, lz))
	for sx: float in [-1.0, 1.0]:
		Props.mi(root, Props.box(Vector3(0.02, 0.025, 0.52)), steel, "Travesano", Vector3(sx * (w * 0.5 - 0.05), 0.16, 0))


## Los tornillos de las mesas y del horno (5m): un solo MultiMesh de cabezas de tornillo de acero (una llamada de dibujo).
func _build_bolts() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Props.cyl(0.0055, 0.0065, 0.006, 8)
	mm.instance_count = _bolt_xforms.size()
	for i in _bolt_xforms.size():
		mm.set_instance_transform(i, _bolt_xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tornillos"
	mmi.multimesh = mm
	mmi.material_override = ForgeLooks.material("acero", is_mobile(), Color(0.55, 0.57, 0.6))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mmi)


## Un sitio que se puede tocar: su id y su caja en el mundo.
func _target(id: String, center: Vector3, size: Vector3) -> void:
	_targets.append({ "id": id, "aabb": AABB(center - size * 0.5, size) })


func _build_powder_bench() -> void:
	var root := Props.node(_world, "BancoDeLosPolvos")
	# la balanza: cuerpo, plato, pantalla y el montón de lo pesado
	var body_mat := Props.mat(Color(0.86, 0.87, 0.88), 0.4)
	Props.mi(root, Props.box(Vector3(0.2, 0.045, 0.22)), body_mat, "Balanza", SCALE_POS + Vector3(0, 0.0225, 0))
	Props.mi(root, Props.cyl(0.012, 0.012, 0.01, 12), Props.mat(Color(0.3, 0.3, 0.32), 0.5, 0.6), "Eje", SCALE_POS + Vector3(0, 0.05, 0))
	_pan = Props.mi(root, Props.cyl(0.075, 0.07, 0.006, 32), Props.mat(Color(0.82, 0.84, 0.86), 0.25, 0.9), "Plato", SCALE_POS + Vector3(0, PAN_Y, 0))
	_heap_mat = Props.mat(Color(0.95, 0.94, 0.9), 0.95)
	_heap = Props.mi(root, Props.cyl(0.0, 0.05, 0.03, 20), _heap_mat, "Monton", SCALE_POS + Vector3(0, PAN_Y + 0.003, 0))
	_heap.visible = false
	Props.mi(root, Props.box(Vector3(0.12, 0.03, 0.012)), Props.mat(Color(0.08, 0.1, 0.09), 0.3), "Pantalla", SCALE_POS + Vector3(0, 0.025, 0.112))
	_scale_label = Props.label(root, "0.00 g", SCALE_POS + Vector3(0, 0.025, 0.119), 0.00042, Color(0.55, 1.0, 0.6), 40)
	_target("balanza", SCALE_POS + Vector3(0, 0.05, 0), Vector3(0.2, 0.08, 0.22))
	# los tarros
	var keys: Array = ForgeData.POWDERS.keys()
	for i in keys.size():
		var id := String(keys[i])
		var col := i % 6
		var row := i / 6
		var pos := Vector3(JAR_X0 + JAR_DX * float(col), BENCH_H, float(JAR_Z[row]))
		var jar := Props.node(root, "Tarro_" + id, pos)
		var gas := id == "ch4_h2"
		if gas:
			Props.mi(jar, Props.cyl(JAR_R * 0.8, JAR_R * 0.8, JAR_H * 1.3, 18), Props.mat(Color(0.82, 0.2, 0.18), 0.4, 0.5), "Botella", Vector3(0, JAR_H * 0.65, 0))
			Props.mi(jar, Props.cyl(0.008, 0.008, 0.025, 10), Props.mat(Color(0.7, 0.62, 0.3), 0.3, 0.9), "Valvula", Vector3(0, JAR_H * 1.3 + 0.012, 0))
		else:
			Props.mi(jar, Props.cyl(JAR_R * 0.9, JAR_R * 0.9, JAR_H * 0.62, 18), Props.mat(Color(POWDER_COLORS.get(id, "#CCCCCC")), 0.95), "Polvo", Vector3(0, JAR_H * 0.32, 0))
			Props.mi(jar, Props.cyl(JAR_R, JAR_R, JAR_H, 18, false), Props.glass_mat(Color(0.85, 0.92, 1.0, 0.22)), "Vidrio", Vector3(0, JAR_H * 0.5, 0))
			Props.mi(jar, Props.cyl(JAR_R * 1.05, JAR_R * 1.05, 0.014, 18), Props.mat(Color(0.18, 0.18, 0.2), 0.5), "Tapa", Vector3(0, JAR_H + 0.007, 0))
		var lab := Props.label(jar, String(ForgeData.POWDERS[id].formula), Vector3(0, JAR_H * 0.5, JAR_R + 0.002), 0.00034, Color(1.0, 0.95, 0.85), 32)
		lab.width = 260.0
		_jars[id] = jar
		_jar_rest[id] = pos
		_target("tarro:" + id, pos + Vector3(0, JAR_H * 0.55, 0), Vector3(JAR_R * 2.4, JAR_H * 1.2, JAR_R * 2.4))
	# el crisol del banco (o el alimentador del soplete): se llena con lo cargado
	var cru_mat := Props.mat(Color(0.28, 0.27, 0.26), 0.8)
	_crucible_bench = Props.mi(root, Props.cyl(0.04, 0.03, 0.06, 20, false), cru_mat, "Crisol", CRUCIBLE_POS + Vector3(0, 0.03, 0))
	Props.mi(root, Props.cyl(0.03, 0.03, 0.004, 20), cru_mat, "FondoCrisol", CRUCIBLE_POS + Vector3(0, 0.002, 0))
	_crucible_fill_mat = Props.mat(Color(0.95, 0.94, 0.9), 0.95)
	_crucible_fill = Props.mi(root, Props.cyl(0.036, 0.03, 0.03, 20), _crucible_fill_mat, "Carga", CRUCIBLE_POS + Vector3(0, 0.02, 0))
	_crucible_fill.visible = false
	Props.label(root, "CRISOL", CRUCIBLE_POS + Vector3(0, 0.075, 0.0), 0.0004)
	_target("crisol", CRUCIBLE_POS + Vector3(0, 0.035, 0), Vector3(0.1, 0.08, 0.1))
	# la caja de las piedras compradas
	Props.mi(root, Props.box(Vector3(0.16, 0.03, 0.1)), Props.mat(Color(0.36, 0.24, 0.16), 0.7), "CajaDePiedras", STONE_POS + Vector3(0, 0.015, 0))
	var gem_cols := [Color("#E8E3D8"), Color("#EAF2F7"), Color("#C9F1D5"), Color("#3B3434"), Color("#DCE9F5")]
	for i in State.STONES.size():
		var g := Props.mi(root, Props.sphere(0.009, 10), Props.mat(gem_cols[i], 0.08, 0.1), "Piedra", STONE_POS + Vector3(-0.06 + 0.03 * float(i), 0.036, 0))
		g.scale = Vector3(1.0, 0.7, 1.0)
	Props.label(root, "PIEDRAS", STONE_POS + Vector3(0, 0.06, 0.0), 0.0004)
	_target("tienda", STONE_POS + Vector3(0, 0.03, 0), Vector3(0.17, 0.07, 0.11))
	# el estuche del acrílico dental (unidad 5j): el bote del polvo y el frasco del líquido (dibujo)
	Props.mi(root, Props.box(Vector3(0.1, 0.012, 0.07)), Props.mat(Color(0.93, 0.93, 0.95), 0.5), "EstucheAcrilico", ACRYLIC_POS + Vector3(0, 0.006, 0))
	Props.mi(root, Props.cyl(0.014, 0.014, 0.034, 16), Props.mat(Color("#E6DCCF"), 0.7), "PolvoAcrilico", ACRYLIC_POS + Vector3(-0.022, 0.029, 0))
	Props.mi(root, Props.cyl(0.0105, 0.0105, 0.04, 16, false), Props.glass_mat(Color(0.9, 0.75, 0.45, 0.35)), "LiquidoAcrilico", ACRYLIC_POS + Vector3(0.022, 0.032, 0))
	Props.mi(root, Props.cyl(0.006, 0.0075, 0.012, 12), Props.mat(Color(0.2, 0.2, 0.22), 0.5), "TapaAcrilico", ACRYLIC_POS + Vector3(0.022, 0.058, 0))
	Props.label(root, "ACRÍLICO", ACRYLIC_POS + Vector3(0, 0.08, 0.0), 0.0004)
	_target("acrilico", ACRYLIC_POS + Vector3(0, 0.03, 0), Vector3(0.11, 0.07, 0.08))
	# el chorro de polvo del tarro al plato
	_stream_mat = Props.mat(Color(0.95, 0.94, 0.9, 0.8), 0.95)
	_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream = Props.mi(root, Props.cyl(0.0025, 0.0035, 1.0, 8), _stream_mat, "Chorro", Vector3.ZERO)
	_stream.visible = false


func _build_furnace() -> void:
	var root := Props.node(_world, "Horno")
	var shell := Props.mat(Color(0.23, 0.25, 0.28), 0.45, 0.65)
	var trim := Props.mat(Color(0.7, 0.72, 0.74), 0.3, 0.85)
	var w := 0.62
	var d := 0.62
	var zc := FRONT_Z - d * 0.5
	var cy := CHAMBER.y
	var y0 := cy - CAVITY.y * 0.5
	var y1 := cy + CAVITY.y * 0.5
	Props.mi(root, Props.box(Vector3(w, y0, d)), shell, "Bajo", Vector3(0, y0 * 0.5, zc))
	Props.mi(root, Props.box(Vector3(w, 1.42 - y1, d)), shell, "Alto", Vector3(0, (1.42 + y1) * 0.5, zc))
	var post := (w - CAVITY.x) * 0.5
	for sx: float in [-1.0, 1.0]:
		Props.mi(root, Props.box(Vector3(post, y1 - y0, d)), shell, "Poste", Vector3(sx * (CAVITY.x + post) * 0.5, cy, zc))
	Props.mi(root, Props.box(Vector3(CAVITY.x, y1 - y0, d - CAVITY.z)), shell, "Fondo", Vector3(0, cy, FRONT_Z - CAVITY.z - (d - CAVITY.z) * 0.5))
	# la peana de hierro fundido, las juntas de la chapa y los tornillos de las esquinas (5m: volumen)
	var mob := is_mobile()
	Props.mi(root, Props.box(Vector3(w + 0.06, 0.06, d + 0.06)), ForgeLooks.material("hierro", mob), "Peana", Vector3(0, 0.03, zc))
	var seam := Props.mat(Color(0.1, 0.11, 0.12), 0.6, 0.4)
	for sx: float in [-1.0, 1.0]:
		Props.mi(root, Props.box(Vector3(0.006, 1.36, 0.004)), seam, "Junta", Vector3(sx * (w * 0.5 - 0.035), 0.74, FRONT_Z + 0.001))
	Props.mi(root, Props.box(Vector3(w - 0.06, 0.006, 0.004)), seam, "Junta", Vector3(0, y1 + 0.06, FRONT_Z + 0.001))
	for cxy: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		_bolt_xforms.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cxy.x * (w * 0.5 - 0.018), 0.74 + cxy.y * 0.66, FRONT_Z + 0.003)))
		_bolt_xforms.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cxy.x * (PANEL_SIZE.x * 0.5 - 0.02), 0.47 + cxy.y * (PANEL_SIZE.y * 0.5 - 0.02), FRONT_Z + 0.013)))
	# la cámara por dentro (ladrillo refractario que brilla con la temperatura del horno; su relieve, de forge_looks.gd)
	_cavity_mat = ForgeLooks.material("refractario", mob).duplicate() as StandardMaterial3D
	_cavity_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_cavity_mat.emission_enabled = true
	_cavity_mat.emission = Color(0, 0, 0)
	Props.mi(root, Props.box(CAVITY - Vector3(0.006, 0.006, 0.006)), _cavity_mat, "Camara", Vector3(0, cy, FRONT_Z - CAVITY.z * 0.5 - 0.002))
	# la puerta: la ventanilla con su marco y su asa, que sube para meter la carga y baja al cerrarla (5m)
	_door = Props.node(root, "Puerta")
	_glass_mat = Props.glass_mat(Color(0.75, 0.82, 0.9, 0.14))
	Props.mi(_door, Props.box(Vector3(CAVITY.x, CAVITY.y, 0.004)), _glass_mat, "Ventanilla", Vector3(0, cy, FRONT_Z + 0.004))
	for f: Array in [[Vector3(0, y1 + 0.012, FRONT_Z + 0.008), Vector3(CAVITY.x + 0.05, 0.024, 0.012)], [Vector3(0, y0 - 0.012, FRONT_Z + 0.008), Vector3(CAVITY.x + 0.05, 0.024, 0.012)],
			[Vector3(-CAVITY.x * 0.5 - 0.012, cy, FRONT_Z + 0.008), Vector3(0.024, CAVITY.y, 0.012)], [Vector3(CAVITY.x * 0.5 + 0.012, cy, FRONT_Z + 0.008), Vector3(0.024, CAVITY.y, 0.012)]]:
		Props.mi(_door, Props.box(f[1]), trim, "Marco", f[0])
	var handle := Props.mi(_door, Props.cyl(0.007, 0.007, 0.12, 10), trim, "Asa", Vector3(0, y0 - 0.012, FRONT_Z + 0.03))
	handle.rotation.z = PI * 0.5
	_target("ventana", Vector3(0, cy, FRONT_Z), Vector3(CAVITY.x, CAVITY.y, 0.05))
	_target("horno", Vector3(0, 1.3, zc), Vector3(w, 0.2, d))
	_furnace_label = Props.label(root, "HORNO-FUNDIDOR DEL TALLER · FICCIÓN EN CONJUNTO", Vector3(0, 1.32, FRONT_Z + 0.003), 0.00042, Color(1.0, 0.75, 0.85))
	_furnace_label.width = 1000.0
	# el panel de mandos
	var panel := Props.node(root, "Panel")
	Props.mi(panel, Props.box(Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.012)), Props.mat(Color(0.12, 0.13, 0.15), 0.5, 0.3), "Placa", Vector3(0, 0.47, FRONT_Z + 0.006))
	for e: Array in PANEL:
		_build_control(panel, String(e[0]), Vector3(float(e[1]), float(e[2]), FRONT_Z + 0.013))
	# los botones
	_start_mat = Props.mat(Color(0.8, 0.12, 0.1), 0.35)
	_start_mat.emission_enabled = true
	_start_mat.emission = Color(0.6, 0.05, 0.03)
	_start_mat.emission_energy_multiplier = 0.0
	Props.mi(panel, Props.cyl(0.03, 0.03, 0.012, 24), Props.mat(Color(0.75, 0.7, 0.1), 0.4), "AroArrancar", START_POS + Vector3(0, 0, -0.012)).rotation.x = PI * 0.5
	var sb := Props.mi(panel, Props.cyl(0.022, 0.024, 0.022, 24), _start_mat, "Arrancar", START_POS)
	sb.rotation.x = PI * 0.5
	Props.label(panel, "ARRANCAR", START_POS + Vector3(0, -0.045, -0.014), 0.00036)
	_cool_mat = Props.mat(Color(0.88, 0.72, 0.12), 0.35)
	_cool_mat.emission_enabled = true
	_cool_mat.emission = Color(0.6, 0.45, 0.05)
	_cool_mat.emission_energy_multiplier = 0.0
	var cb := Props.mi(panel, Props.cyl(0.02, 0.022, 0.018, 24), _cool_mat, "Sacar", COOL_POS)
	cb.rotation.x = PI * 0.5
	Props.label(panel, "SACAR Y ENFRIAR", COOL_POS + Vector3(0, -0.045, -0.014), 0.00036)
	_target("arrancar", START_POS, Vector3(0.07, 0.07, 0.05))
	_target("sacar", COOL_POS, Vector3(0.07, 0.07, 0.05))
	_selected_ring = Props.mi(panel, Props.torus(0.041, 0.045, 32), Props.glow_mat(Color(0.95, 0.95, 1.0), 0.8, 0.6), "Elegido", Vector3.ZERO)
	_selected_ring.rotation.x = PI * 0.5
	# lo de dentro
	_chamber = Props.node(root, "Dentro", Vector3(0, y0, CHAMBER.z))
	_build_modes()


## Un mando del panel: el pomo y su aguja, la escala y el margen de la receta (los diales) o las posiciones de las opciones
## (los selectores), su nombre y su valor.
func _build_control(parent: Node3D, id: String, pos: Vector3) -> void:
	var c := State.control_data(id)
	var n := Props.node(parent, "Mando_" + id, pos)
	var dial := State.DIALS.has(id)
	var knob := Props.mi(n, Props.cyl(KNOB_R * 0.85, KNOB_R, 0.022, 24), Props.mat(Color(0.1, 0.1, 0.11), 0.4), "Pomo", Vector3(0, 0, 0.011))
	knob.rotation.x = PI * 0.5
	var needle_root := Props.node(n, "Aguja", Vector3(0, 0, 0.023))
	Props.mi(needle_root, Props.box(Vector3(0.003, KNOB_R * 0.9, 0.002)), Props.mat(Color(1.0, 0.95, 0.85), 0.3), "Raya", Vector3(0, KNOB_R * 0.45, 0))
	var arc_mesh := ArrayMesh.new()
	var tick_mat := Props.mat(Color(0.9, 0.9, 0.88), 0.5)
	tick_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arc_mat := Props.glow_mat(Color(0.25, 0.85, 0.45), 1.2)
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if dial:
		Props.mi(n, Props.array_mesh(Props.ticks_arrays(0.034, 0.04, 21, 5, 0.001, 0.0014)), tick_mat, "Escala", Vector3.ZERO)
		Props.mi(n, arc_mesh, arc_mat, "Margen", Vector3.ZERO)
	else:
		var opts: Array = c.options
		for i in opts.size():
			var a := _option_angle(i, opts.size())
			var p := Vector3(cos(a), sin(a), 0.0) * 0.036
			Props.mi(n, Props.cyl(0.0025, 0.0025, 0.002, 8), Props.mat(Color(0.9, 0.9, 0.88), 0.5), "Punto", p + Vector3(0, 0, 0.001)).rotation.x = PI * 0.5
		Props.mi(n, arc_mesh, arc_mat, "Margen", Vector3.ZERO)
	var name_l := Props.label(n, String(c.name).to_upper(), Vector3(0, 0.06, 0.002), 0.00032, Color(0.95, 0.85, 0.6))
	name_l.width = 360.0
	var value_l := Props.label(n, "", Vector3(0, -0.062, 0.002), 0.00034, Color(1.0, 1.0, 1.0))
	value_l.width = 390.0  # 0,13 m: menos que los 0,14 m entre mandos
	# un valor largo («Dentro del horno (lento, recociendo)») parte en dos líneas hacia abajo, sin pisar el del mando de al
	# lado («Revestimiento de yeso», en el molde)
	value_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_controls[id] = { "node": n, "needle": needle_root, "arc": arc_mesh, "value": value_l, "dial": dial, "pos": pos }
	_needles[id] = 0.0
	_target("mando:" + id, pos + Vector3(0, 0, 0.015), Vector3(0.085, 0.085, 0.05))


## Ángulo de la opción i de n de un selector: de 150° a 30°, por arriba.
static func _option_angle(i: int, n: int) -> float:
	var t := float(i) / float(maxi(n - 1, 1))
	return deg_to_rad(150.0 - 120.0 * t)


## Lo de dentro de la cámara, un nodo por máquina (se enseña el del modo que trabaja).
func _build_modes() -> void:
	var steel := Props.mat(Color(0.55, 0.57, 0.6), 0.35, 0.85)
	var ceramic := Props.mat(Color(0.86, 0.82, 0.74), 0.85)
	# Verneuil: el soplete arriba, la llama, la bola sobre su pedestal
	var vn := Props.node(_chamber, "Verneuil")
	Props.mi(vn, Props.cyl(0.03, 0.012, 0.05, 16), ceramic, "Tolva", Vector3(0, CAVITY.y - 0.03, 0))
	# la alúmina en la tolva (5m: solo si se ha metido) y el martillo que la golpea
	_hopper_fill = Props.mi(vn, Props.cyl(0.026, 0.014, 0.03, 16), Props.mat(Color(0.95, 0.94, 0.9), 0.95), "AluminaEnLaTolva", Vector3(0, CAVITY.y - 0.022, 0))
	_hopper_fill.visible = false
	Props.mi(vn, Props.box(Vector3(0.012, 0.02, 0.012)), steel, "Martillo", Vector3(0.036, CAVITY.y - 0.02, 0))
	Props.mi(vn, Props.cyl(0.008, 0.008, 0.1, 12), steel, "Soplete", Vector3(0, CAVITY.y - 0.1, 0))
	_flame_mat = Props.glow_mat(Color(0.55, 0.7, 1.0), 2.0, 0.35)
	_flame = Props.mi(vn, Props.cyl(0.004, 0.016, 0.07, 16, false), _flame_mat, "Llama", Vector3(0, CAVITY.y - 0.185, 0))
	_pedestal = Props.mi(vn, Props.cyl(0.004, 0.004, 0.2, 10), ceramic, "Pedestal", Vector3(0, 0.1, 0))
	_boule = Props.node(vn, "Bola", Vector3(0, CAVITY.y - 0.23, 0))
	_boule_glow = Props.heat_overlay()
	var growth: Dictionary = ForgeData.RECIPES.zafiro.growth
	var br := float(growth.diameter_mm) * 0.5 * MM
	# el material, de la biblioteca común (_apply_looks)
	_boule_body = Props.mi(_boule, Props.cyl(br, br, 1.0, 20), null, "Cuerpo", Vector3.ZERO)
	_boule_cap = Props.mi(_boule, Props.sphere(br, 16), null, "Casquete", Vector3.ZERO)
	_boule_cap.scale = Vector3(1.0, 0.55, 1.0)
	_modes["verneuil"] = vn
	# inducción y colada: el crisol con su metal, la bobina (solo en inducción), el molde y el chorro
	var ind := Props.node(_chamber, "Fundir")
	_melt_crucible = Props.node(ind, "Crisol", Vector3(0, 0.12, -0.04))
	_coil_mat = Props.mat(Color(0.78, 0.45, 0.25), 0.3, 0.9)
	_coil_mat.emission_enabled = true
	_coil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var coil := Props.mi(_melt_crucible, Props.array_mesh(Props.helix_arrays(0.055, 0.006, 5.0, 0.1, 28, 8)), _coil_mat, "Bobina", Vector3(0, 0.0, 0))
	coil.set_meta("induccion", true)
	var cru_mat := Props.mat(Color(0.3, 0.29, 0.28), 0.8)
	cru_mat.emission_enabled = true
	Props.mi(_melt_crucible, Props.cyl(0.04, 0.03, 0.09, 20, false), cru_mat, "Vaso", Vector3.ZERO)
	_melt_mat = Props.glow_mat(Color(1.0, 0.6, 0.2), 1.0)
	_melt = Props.mi(_melt_crucible, Props.cyl(0.037, 0.037, 0.004, 20), _melt_mat, "Metal", Vector3(0, 0.025, 0))
	_mold_mat = Props.mat(Color(MOLD_COLORS.yeso), 0.9)
	_mold = Props.mi(ind, Props.box(Vector3(0.07, 0.05, 0.07)), _mold_mat, "Molde", Vector3(0.11, 0.025, 0.06))
	# el molde de la cera perdida (5m): el cilindro revestido con su embudo arriba, y el metal que sube por el bebedero
	_flask_oven_mat = Props.mat(Color(MOLD_COLORS.yeso), 0.9)
	_flask_oven_mat.emission_enabled = true
	_flask_cast = Props.mi(ind, Props.cyl(FLASK_R, FLASK_R, FLASK_H, 20), _flask_oven_mat, "MoldeRevestido", Vector3(0.11, FLASK_H * 0.5, 0.06))
	_flask_cast.visible = false
	_cast_fill_mat = Props.glow_mat(Color(1.0, 0.6, 0.2), 1.2)
	_cast_fill = Props.mi(ind, Props.cyl(0.006, 0.006, 1.0, 10), _cast_fill_mat, "MetalEnElBebedero", Vector3(0.11, FLASK_H, 0.06))
	_cast_fill.visible = false
	_pour_mat = Props.glow_mat(Color(1.0, 0.6, 0.2), 1.5)
	_pour = Props.mi(ind, Props.cyl(0.0035, 0.004, 1.0, 10), _pour_mat, "Chorro", Vector3.ZERO)
	_pour.visible = false
	_modes["fundir"] = ind
	# HPHT: la prensa (dos yunques de acero) y la cápsula
	var hp := Props.node(_chamber, "Prensa")
	var anvil_mat := Props.mat(Color(0.5, 0.52, 0.56), 0.3, 0.9)
	_anvil_top = Props.mi(hp, Props.box(Vector3(0.16, 0.1, 0.16)), anvil_mat, "YunqueArriba", Vector3(0, 0.27, 0))
	_anvil_bottom = Props.mi(hp, Props.box(Vector3(0.16, 0.1, 0.16)), anvil_mat, "YunqueAbajo", Vector3(0, 0.07, 0))
	_capsule_mat = Props.mat(Color(0.78, 0.7, 0.55), 0.85)
	_capsule_mat.emission_enabled = true
	_capsule = Props.mi(hp, Props.box(Vector3(0.05, 0.05, 0.05)), _capsule_mat, "Capsula", Vector3(0, 0.17, 0))
	_gauge = Props.label(hp, "", Vector3(0, 0.35, 0.09), 0.0005, Color(0.6, 1.0, 0.7))
	_modes["hpht"] = hp
	# CVD: la campana, el plasma violeta y el molde con la forma de la funda
	var cv := Props.node(_chamber, "CVD")
	_heater_mat = Props.mat(Color(0.4, 0.38, 0.36), 0.6, 0.4)
	_heater_mat.emission_enabled = true
	Props.mi(cv, Props.cyl(0.06, 0.06, 0.01, 24), _heater_mat, "Calentador", Vector3(0, 0.05, 0))
	_cvd_mat = Props.mat(Color(0.42, 0.44, 0.47), 0.5, 0.8)
	_cvd_mat.emission_enabled = true
	_cvd_mold = Props.mi(cv, _sheath_mesh, _cvd_mat, "MoldeCVD", Vector3(0, 0.075, 0))
	_cvd_mold.scale = Vector3(MM, MM, MM)
	_plasma_mat = Props.glow_mat(Color(0.72, 0.35, 1.0), 2.5, 0.45)
	_plasma = Props.mi(cv, Props.sphere(0.04, 20), _plasma_mat, "Plasma", Vector3(0, 0.14, 0))
	Props.mi(cv, Props.cyl(0.09, 0.09, 0.24, 24, false), Props.glass_mat(Color(0.8, 0.9, 1.0, 0.12)), "Campana", Vector3(0, 0.17, 0))
	_modes["cvd"] = cv
	# sinterizar y calentar: la bandeja (la pieza va encima)
	var sn := Props.node(_chamber, "Bandeja")
	_tray = Props.mi(sn, Props.box(Vector3(0.18, 0.012, 0.14)), ceramic, "Placa", Vector3(0, 0.05, 0))
	# la pastilla prensada con la forma de la funda, más grande lo que encogerá (5m), y el molde de la cera perdida al quemarla
	_pellet_mat = Props.mat(Color(0.73, 0.74, 0.76), 0.95)
	_pellet = Props.mi(sn, _sheath_mesh, _pellet_mat, "Pastilla", Vector3(0, 0.062, 0))
	_pellet.visible = false
	_flask_oven = Props.mi(sn, Props.cyl(FLASK_R, FLASK_R, FLASK_H, 20), _flask_oven_mat, "MoldeAlHorno", Vector3(0, 0.056 + FLASK_H * 0.5, 0))
	_flask_oven.visible = false
	_modes["bandeja"] = sn


func _build_bucket() -> void:
	var root := Props.node(_world, "Cubo", BUCKET_POS)
	var steel := Props.mat(Color(0.6, 0.62, 0.65), 0.35, 0.85)
	var bucket_mat := Props.mat(Color(0.6, 0.62, 0.65), 0.35, 0.85)
	bucket_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Props.mi(root, Props.cyl(0.17, 0.15, 0.34, 28, false), bucket_mat, "Cubo", Vector3(0, 0.17, 0))
	Props.mi(root, Props.cyl(0.15, 0.15, 0.006, 28), steel, "FondoCubo", Vector3(0, 0.003, 0))
	_water_mat = Props.mat(Color(0.22, 0.38, 0.48, 0.75), 0.05)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water = Props.mi(root, Props.cyl(0.162, 0.162, 0.004, 28), _water_mat, "Agua", Vector3(0, 0.28, 0))
	Props.label(root, "TEMPLE", Vector3(0, 0.36, 0.17), 0.0005)


func _build_workshop() -> void:
	var root := Props.node(_world, "Taller")
	var steel := Props.mat(Color(0.58, 0.6, 0.63), 0.35, 0.85)
	var dark := Props.mat(Color(0.17, 0.18, 0.2), 0.5, 0.4)
	# la muela de lapidario con su agua
	Props.mi(root, Props.box(Vector3(0.2, 0.1, 0.16)), dark, "Motor", GRINDER_POS + Vector3(0, 0.05, 0))
	_wheel = Props.node(root, "Muela", GRINDER_POS + Vector3(0, 0.18, 0))
	# 5m · las muelas en fila de la máquina de lapidario: la gruesa (grano 80), la fina (grano 220) y una de resina para repasar
	var wheel_cols := [Color(0.24, 0.25, 0.27), Color(0.42, 0.44, 0.46), Color(0.55, 0.62, 0.7)]
	for i in 3:
		var wm := Props.mi(_wheel, Props.cyl(WHEEL_R, WHEEL_R, 0.024, 36), Props.mat(wheel_cols[i], 0.75, 0.3), "Disco%d" % i, Vector3(-0.034 + 0.034 * float(i), 0, 0))
		wm.rotation.z = PI * 0.5
	Props.mi(_wheel, Props.box(Vector3(0.1, 0.01, 0.004)), Props.mat(Color(0.8, 0.8, 0.82), 0.4), "Marca", Vector3(0, WHEEL_R * 0.7, 0))
	Props.mi(root, Props.cyl(0.03, 0.03, 0.02, 12), steel, "Deposito", GRINDER_POS + Vector3(0, 0.33, -0.03))
	Props.label(root, "MUELAS 80 · 220 · 600", GRINDER_POS + Vector3(0, 0.29, 0.06), 0.00042)
	# la sierra de disco de diamante con su bandeja de agua
	Props.mi(root, Props.box(Vector3(0.13, 0.05, 0.11)), dark, "MesaSierra", SAW_POS + Vector3(0, 0.025, 0))
	var tray_mat := Props.mat(Color(0.3, 0.55, 0.7, 0.55), 0.05)
	tray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Props.mi(root, Props.box(Vector3(0.12, 0.012, 0.1)), tray_mat, "BandejaDeAgua", SAW_POS + Vector3(0, 0.054, 0))
	_saw_disc = Props.node(root, "Sierra", SAW_POS + Vector3(0, 0.05, 0))
	var disc := Props.mi(_saw_disc, Props.cyl(SAW_R, SAW_R, 0.0015, 40), Props.mat(Color(0.74, 0.76, 0.79), 0.3, 0.9), "Disco", Vector3.ZERO)
	disc.rotation.z = PI * 0.5
	Props.mi(_saw_disc, Props.cyl(SAW_R * 1.002, SAW_R * 1.002, 0.002, 40, false), Props.mat(Color(0.35, 0.36, 0.38), 0.8), "Canto", Vector3.ZERO).rotation.z = PI * 0.5
	Props.label(root, "SIERRA", SAW_POS + Vector3(0, 0.16, 0.06), 0.00042)
	_target("sierra", SAW_POS + Vector3(0, 0.07, 0), Vector3(0.13, 0.14, 0.11))
	# el eje flexible con su fresa: el motor colgado de su pie, el cable y la pieza de mano
	Props.mi(root, Props.cyl(0.03, 0.035, 0.01, 16), dark, "PieFresa", BURR_POS + Vector3(0, 0.005, -0.04))
	Props.mi(root, Props.cyl(0.005, 0.005, 0.42, 8), steel, "Barra", BURR_POS + Vector3(0, 0.21, -0.04))
	Props.mi(root, Props.cyl(0.028, 0.028, 0.09, 16), dark, "MotorFresa", BURR_POS + Vector3(0, 0.38, -0.04))
	Props.mi(root, Props.cyl(0.004, 0.004, 0.32, 8), Props.mat(Color(0.12, 0.12, 0.13), 0.6), "Cable", BURR_POS + Vector3(0.0, 0.2, -0.01)).rotation.x = 0.18
	_burr_rest = BURR_POS + Vector3(0.0, 0.025, 0.03)
	_burr = Props.node(root, "PiezaDeMano", _burr_rest)
	var hand := Props.mi(_burr, Props.cyl(0.008, 0.009, 0.08, 12), steel, "Mango", Vector3.ZERO)
	hand.rotation.x = PI * 0.5
	Props.mi(_burr, Props.sphere(0.0035, 8), Props.mat(Color(0.8, 0.82, 0.84), 0.3, 0.9), "Fresa", Vector3(0, 0, 0.045))
	Props.label(root, "FRESA", BURR_POS + Vector3(0, 0.12, 0.06), 0.00042)
	_target("fresa", BURR_POS + Vector3(0, 0.05, 0.02), Vector3(0.08, 0.1, 0.1))
	_target("muela", GRINDER_POS + Vector3(0, 0.15, 0), Vector3(0.2, 0.3, 0.18))
	# la pulidora
	Props.mi(root, Props.box(Vector3(0.12, 0.07, 0.1)), dark, "MotorPulidora", POLISHER_POS + Vector3(0, 0.035, 0))
	_polish_wheel = Props.node(root, "Fieltro", POLISHER_POS + Vector3(0, 0.11, 0))
	var pw := Props.mi(_polish_wheel, Props.cyl(0.045, 0.045, 0.03, 28), Props.mat(Color(0.93, 0.92, 0.88), 0.95), "Disco", Vector3.ZERO)
	pw.rotation.z = PI * 0.5
	Props.label(root, "PULIDORA", POLISHER_POS + Vector3(0, 0.19, 0.03), 0.00042)
	_target("pulidora", POLISHER_POS + Vector3(0, 0.08, 0), Vector3(0.13, 0.17, 0.11))
	# el soporte de la garra y la garra (la malla de la cetrería)
	Props.mi(root, Props.cyl(0.035, 0.04, 0.012, 20), dark, "Base", CLAW_POS + Vector3(-0.03, -0.094, 0))
	Props.mi(root, Props.cyl(0.006, 0.006, 0.09, 10), steel, "Poste", CLAW_POS + Vector3(-0.03, -0.045, 0))
	Props.mi(root, Props.box(Vector3(0.02, 0.016, 0.022)), steel, "Pinza", CLAW_POS + Vector3(-0.01, 0.0, 0))
	_claw = Props.node(root, "Garra", CLAW_POS)
	_claw.scale = Vector3(MM, MM, MM)
	_claw_mat = ShaderMaterial.new()
	_claw_mat.shader = KERATIN_SHADER
	Props.mi(_claw, _claw_mesh, _claw_mat, "Estuche", Vector3.ZERO)
	_claw_sheath = Props.mi(_claw, _sheath_mesh, null, "Funda", Vector3.ZERO)
	_claw_sheath.visible = false
	_barrier_mat = Props.mat(Color(0.86, 0.9, 0.96, 0.92), 0.9)
	_barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_barrier = Props.mi(_claw, _barrier_mesh, _barrier_mat, "Barrera", Vector3.ZERO)
	_barrier.visible = false
	_coat_shell = Props.mi(_claw, _coat_mesh, null, "Capa", Vector3.ZERO)
	_coat_shell.visible = false
	Props.label(root, "GARRA", CLAW_POS + Vector3(0.0, 0.07, 0.03), 0.00042)
	_target("garra", CLAW_POS + Vector3(0.02, -0.01, 0), Vector3(0.07, 0.06, 0.04))
	_target("barrera", CLAW_POS + Vector3(0.008, 0.002, 0), Vector3(0.025, 0.025, 0.03))
	# la jeringa del adhesivo
	var syr := Props.mi(root, Props.cyl(0.008, 0.008, 0.08, 12), Props.glass_mat(Color(0.92, 0.95, 0.9, 0.5)), "Jeringa", SYRINGE_POS)
	syr.rotation.z = PI * 0.5
	Props.label(root, "ADHESIVO", SYRINGE_POS + Vector3(0, 0.03, 0.0), 0.0004)
	# el ladrillo donde se enfría la pieza
	Props.mi(root, Props.box(Vector3(0.12, 0.03, 0.08)), Props.mat(Color(0.82, 0.76, 0.66), 0.95), "Ladrillo", BRICK_POS + Vector3(0, 0.015, 0))
	_target("pieza", BRICK_POS + Vector3(0, 0.04, 0), Vector3(0.12, 0.06, 0.08))
	# la pistola de proyección y su chorro
	var gun := Props.node(root, "Pistola", GUN_POS)
	Props.mi(gun, Props.box(Vector3(0.07, 0.04, 0.03)), dark, "Cuerpo", Vector3.ZERO)
	var nz := Props.mi(gun, Props.cyl(0.006, 0.01, 0.05, 12), steel, "Boquilla", Vector3(-0.055, 0, 0))
	nz.rotation.z = PI * 0.5
	Props.mi(gun, Props.box(Vector3(0.02, 0.06, 0.02)), dark, "Mango", Vector3(0.015, -0.045, 0))
	_plume_mat = Props.glow_mat(Color(1.0, 0.85, 0.55), 2.5, 0.45)
	_gun_plume = Props.mi(gun, Props.cyl(0.004, 0.018, 1.0, 14, false), _plume_mat, "ChorroDePlasma", Vector3.ZERO)
	_gun_plume.visible = false
	Props.label(root, "PISTOLA", GUN_POS + Vector3(0, 0.06, 0.0), 0.0004)
	_target("pistola", GUN_POS, Vector3(0.1, 0.1, 0.06))
	# la campana de vacío (los recubrimientos en vacío de la funda) y el baño de cromo
	_bell = Props.node(root, "Campana", BELL_POS)
	Props.mi(_bell, Props.cyl(0.06, 0.06, 0.008, 24), dark, "BaseCampana", Vector3(0, 0.004, 0))
	Props.mi(_bell, Props.cyl(0.05, 0.05, 0.1, 24, false), Props.glass_mat(Color(0.85, 0.9, 1.0, 0.14)), "Vidrio", Vector3(0, 0.058, 0))
	_bell_glow_mat = Props.glow_mat(Color(0.7, 0.4, 1.0), 0.0, 0.3)
	Props.mi(_bell, Props.sphere(0.035, 14), _bell_glow_mat, "Plasma", Vector3(0, 0.06, 0))
	Props.label(root, "VACÍO", BELL_POS + Vector3(0, 0.13, 0.0), 0.0004)
	var tank_mat := Props.mat(Color(0.6, 0.62, 0.65, 0.5), 0.2, 0.3)
	tank_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Props.mi(root, Props.box(Vector3(0.1, 0.06, 0.08)), tank_mat, "Bano", BATH_POS + Vector3(0, 0.03, 0))
	_bath_liquid_mat = Props.mat(Color(0.65, 0.5, 0.15, 0.8), 0.1)
	_bath_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Props.mi(root, Props.box(Vector3(0.096, 0.045, 0.076)), _bath_liquid_mat, "Acido", BATH_POS + Vector3(0, 0.024, 0))
	Props.label(root, "BAÑO DE CROMO", BATH_POS + Vector3(0, 0.09, 0.0), 0.0004)
	# la pesa de la prueba (cuelga de la punta)
	_weight = Props.node(_claw, "Pesa", Vector3.ZERO)
	_weight.scale = Vector3(1000.0, 1000.0, 1000.0)
	Props.mi(_weight, Props.cyl(0.0006, 0.0006, 0.05, 6), steel, "Hilo", Vector3(0, -0.025, 0))
	Props.mi(_weight, Props.cyl(0.014, 0.014, 0.025, 18), Props.mat(Color(0.25, 0.26, 0.28), 0.4, 0.8), "Peso", Vector3(0, -0.062, 0))
	_weight_label = Props.label(_weight, "", Vector3(0.0, -0.09, 0.02), 0.00034)
	_weight.visible = false
	# el termómetro de la carne viva (FICCIÓN)
	_thermo = Props.node(root, "Termometro", THERMO_POS)
	Props.mi(_thermo, Props.box(Vector3(0.05, 0.11, 0.008)), Props.mat(Color(0.93, 0.93, 0.95), 0.6), "Placa", Vector3.ZERO)
	Props.mi(_thermo, Props.cyl(0.0035, 0.0035, 0.08, 8), Props.glass_mat(Color(0.95, 0.95, 1.0, 0.5)), "Tubo", Vector3(-0.012, 0.005, 0.006))
	_thermo_fill_mat = Props.glow_mat(Color(0.9, 0.15, 0.12), 0.8)
	_thermo_fill = Props.mi(_thermo, Props.cyl(0.0025, 0.0025, 1.0, 8), _thermo_fill_mat, "Columna", Vector3(-0.012, -0.035, 0.006))
	_thermo_label = Props.label(_thermo, "", Vector3(0.008, 0.0, 0.006), 0.00028, Color(0.1, 0.1, 0.12))
	_thermo_label.outline_size = 0
	_thermo_label.width = 120.0
	_thermo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fiction_label = Props.label(root, "FICCIÓN", THERMO_POS + Vector3(0, 0.085, 0.0), 0.0006, Color(1.0, 0.45, 0.7))
	_thermo.visible = false
	_fiction_label.visible = false


## La pieza suelta: la bola, el cristal, el bloque o la funda, en mm.
func _build_piece() -> void:
	_piece = Props.node(_world, "Pieza", BRICK_POS + Vector3(0, 0.04, 0))
	_piece.scale = Vector3(MM, MM, MM)
	_piece_glow = Props.heat_overlay()
	var growth: Dictionary = ForgeData.RECIPES.zafiro.growth
	var br := float(growth.diameter_mm) * 0.5
	var bola := Props.node(_piece, "Bola")
	var body := Props.mi(bola, Props.cyl(br, br, 1.0, 20), null, "Cuerpo", Vector3.ZERO)
	var cap := Props.mi(bola, Props.sphere(br, 16), null, "Casquete", Vector3.ZERO)
	cap.scale = Vector3(1.0, 0.55, 1.0)
	_piece_shapes["bola"] = bola
	_piece_shapes["cristal"] = Props.mi(_piece, Props.array_mesh(Props.octahedron_arrays(1.0)), null, "Cristal", Vector3.ZERO)
	_piece_shapes["bloque"] = Props.mi(_piece, Props.box(Vector3.ONE), null, "Bloque", Vector3.ZERO)
	_piece_shapes["funda"] = Props.mi(_piece, _sheath_mesh, null, "Funda", Vector3.ZERO)
	# 5m · la pieza que se talla por pasadas (su silueta del motor, del tocho a la funda), el bebedero de la colada y el palo
	_piece_shapes["tallando"] = Props.mi(_piece, _carve_mesh, null, "Tallando", Vector3.ZERO)
	_sprue = Props.mi(_piece, Props.cyl(1.0, 1.0, 1.0, 12), null, "Bebedero", Vector3.ZERO)
	_sprue.visible = false
	_dop = Props.mi(_piece, Props.cyl(2.2, 2.2, 34.0, 10), Props.mat(Color(0.55, 0.4, 0.25), 0.7), "Palo", Vector3.ZERO)
	_dop.visible = false
	_piece_loose = [body, cap, _piece_shapes.cristal, _piece_shapes.bloque]
	_piece_mis = _piece_loose + [_piece_shapes.funda, _piece_shapes.tallando, _sprue]
	for k: String in _piece_shapes:
		(_piece_shapes[k] as Node3D).visible = false


func _multimesh(n: String, cap: int, mesh: Mesh, m: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mmi)
	return mmi


func _build_fx() -> void:
	var white := Props.mat(Color(1, 1, 1, 0.5), 0.2)
	white.vertex_color_use_as_albedo = true
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubbles_mmi = _multimesh("Burbujas", BUBBLES, Props.sphere(0.006, 8), white)
	var steam := Props.mat(Color(1, 1, 1, 0.25), 1.0)
	steam.vertex_color_use_as_albedo = true
	steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_steam_mmi = _multimesh("Vapor", STEAM, Props.sphere(0.03, 10), steam)
	var water := Props.mat(Color(0.6, 0.75, 0.9, 0.7), 0.05)
	water.vertex_color_use_as_albedo = true
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drops_mmi = _multimesh("Gotas", DROPS, Props.sphere(0.0025, 6), water)
	var powder := Props.mat(Color(1, 1, 1), 0.95)
	powder.vertex_color_use_as_albedo = true
	_powder_mmi = _multimesh("Polvo", POWDER, Props.sphere(0.002, 6), powder)
	_bubbles_buf.resize(BUBBLES * 16)
	_steam_buf.resize(STEAM * 16)
	_drops_buf.resize(DROPS * 16)
	_powder_buf.resize(POWDER * 16)


## 5m · la cera perdida en el banco de los polvos: el modelo de cera de la funda (la malla de la funda, con su bebedero y su base
## de goma) y el molde revestido que lo envuelve (un cilindro del color del revestimiento); y lo que entra por la puerta.
func _build_lost_wax() -> void:
	var root := Props.node(_world, "CeraPerdida")
	_wax_model = Props.node(root, "ModeloDeCera", WAX_POS)
	Props.mi(_wax_model, Props.cyl(0.018, 0.022, 0.012, 16), Props.mat(Color(0.25, 0.25, 0.27), 0.8), "BaseDeGoma", Vector3(0, 0.006, 0))
	var wax_mat := Props.mat(WAX_COLOR, 0.45)
	Props.mi(_wax_model, Props.cyl(0.0012, 0.0012, 0.008, 8), wax_mat, "Bebedero", Vector3(0, 0.016, 0))
	var model := Props.mi(_wax_model, _sheath_mesh, wax_mat, "Funda", Vector3(0, 0.02, 0))
	model.scale = Vector3(MM, MM, MM)
	model.rotation.z = PI * 0.5
	_wax_model.visible = false
	_flask_mat = Props.mat(Color(MOLD_COLORS.yeso), 0.9)
	_flask = Props.mi(root, Props.cyl(FLASK_R, FLASK_R, FLASK_H, 20), _flask_mat, "Molde", WAX_POS + Vector3(0, FLASK_H * 0.5, 0))
	_flask.visible = false
	Props.label(root, "CERA PERDIDA", WAX_POS + Vector3(0, 0.1, 0.0), 0.0004)
	_target("cera", WAX_POS + Vector3(0, 0.04, 0), Vector3(0.09, 0.09, 0.08))
	_carry_mat = Props.mat(Color(0.3, 0.3, 0.3), 0.7)
	_carry = Props.mi(_world, Props.cyl(1.0, 1.0, 1.0, 16), _carry_mat, "LaCargaQueEntra", Vector3.ZERO)
	_carry.visible = false


func _build_highlight() -> void:
	_highlight_mat = Props.glow_mat(Color(1.0, 0.8, 0.3), 1.6, 0.85)
	_highlight = Props.mi(_world, Props.torus(0.92, 1.0, 40), _highlight_mat, "Resaltado", Vector3.ZERO)
	_highlight.visible = false


func _apply_quality() -> void:
	if _sun == null:
		return
	_sun.shadow_enabled = not is_mobile()


# ───────────────────────────── 5r · la mesa de soldar ─────────────────────────────

## La mesa de soldar (dibujo): la mesa, el soporte de la pieza, el aparato de cada método, las cuentas de la costura, el punto
## incandescente, el destello (una luz corta y suave: no ciega la pantalla) y el anillo de dónde apunta el haz.
func _build_weld_table() -> void:
	var mob := is_mobile()
	_build_table(WELD_POS.x, 0.72, mob, _bolt_xforms)
	Props.label(_world, "MESA DE SOLDAR", Vector3(WELD_POS.x, BENCH_H + 0.005, 0.29), 0.0005, Color(0.95, 0.85, 0.6)).rotation.x = -PI * 0.5
	_weld_root = Props.node(_world, "MesaDeSoldar")
	var steel := ForgeLooks.material("acero", mob)
	var dark := Props.mat(Color(0.16, 0.17, 0.19), 0.45, 0.6)
	# el soporte de joyero: la base, la varilla y la pinza que sujeta la base de la funda (_apply_weld las pone junto a ella)
	var fix_floor := Vector3(WELD_FIX.x, BENCH_H, WELD_FIX.z)
	Props.mi(_weld_root, Props.box(Vector3(0.06, 0.006, 0.04)), dark, "BaseDelSoporte", fix_floor + Vector3(-0.01, 0.003, 0))
	_weld_rod = Props.mi(_weld_root, Props.cyl(0.0022, 0.0022, 1.0, 10), steel, "Varilla", fix_floor)
	_build_weld_clamp(steel, dark)
	_target("soldadura", WELD_POS + Vector3(0.0, 0.14, -0.15), Vector3(0.38, 0.28, 0.17))
	# la pieza: la funda partida por la costura (las mallas del hilo), en mm
	_weld_work = Props.node(_weld_root, "Pieza", WELD_FIX)
	_weld_work.scale = Vector3(MM, MM, MM)
	_weld_base = Props.mi(_weld_work, _weld_base_mesh, null, "Base", Vector3.ZERO)
	_weld_tip = Props.mi(_weld_work, _weld_tip_mesh, null, "Punta", Vector3.ZERO)
	_weld_work.visible = false
	_target("costura", WELD_FIX, Vector3(0.07, 0.05, 0.07))
	# las cuentas de la costura (un MultiMesh con su color por cuenta) y el punto incandescente
	_weld_bead_mat = Props.mat(Color(1, 1, 1), 0.35, 0.8)
	_weld_bead_mat.vertex_color_use_as_albedo = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Props.sphere(1.0, 10)
	mm.instance_count = WELD_BEADS
	mm.visible_instance_count = 0
	_weld_beads = MultiMeshInstance3D.new()
	_weld_beads.name = "Cordon"
	_weld_beads.multimesh = mm
	_weld_beads.material_override = _weld_bead_mat
	_weld_beads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weld_work.add_child(_weld_beads)
	_weld_hot_mat = Props.glow_mat(Color(1.0, 0.8, 0.5), 0.0)
	_weld_hot = Props.mi(_weld_work, Props.sphere(1.0, 12), _weld_hot_mat, "PuntoIncandescente", Vector3.ZERO)
	_weld_hot.visible = false
	_weld_aim = Props.mi(_weld_work, Props.torus(0.7, 1.0, 20), Props.glow_mat(Color(0.4, 0.9, 1.0), 1.2, 0.8), "DondeApunta", Vector3.ZERO)
	_weld_aim.visible = false
	_weld_flash = OmniLight3D.new()
	_weld_flash.name = "Destello"
	_weld_flash.omni_range = 0.35
	_weld_flash.light_energy = 0.0
	_weld_flash.shadow_enabled = false
	_weld_root.add_child(_weld_flash)
	_weld_flash.position = WELD_FIX + Vector3(0, 0.03, 0.02)
	_build_weld_laser(mob)
	_build_weld_tig(mob)
	_build_weld_braze(mob)


## La pinza de joyero (dibujo): un puente en U con dos mordazas que cogen la base de la funda por delante y por detrás, y el
## tornillo que las aprieta con su pomo, por detrás; _fit_weld_clamp las ajusta al grosor de la funda.
func _build_weld_clamp(steel: Material, dark: Material) -> void:
	_weld_jaw = Props.node(_weld_root, "Pinza", WELD_FIX)
	_weld_jaw_parts = {
		"puente": Props.mi(_weld_jaw, Props.box(Vector3(1, 1, 1)), steel, "Puente", Vector3.ZERO),
		"delante": Props.mi(_weld_jaw, Props.box(Vector3(1, 1, 1)), steel, "MordazaDelante", Vector3.ZERO),
		"detras": Props.mi(_weld_jaw, Props.box(Vector3(1, 1, 1)), steel, "MordazaDetras", Vector3.ZERO),
		"tornillo": Props.mi(_weld_jaw, Props.cyl(0.0007, 0.0007, 1.0, 8), steel, "Tornillo", Vector3.ZERO),
		"pomo": Props.mi(_weld_jaw, Props.cyl(0.0021, 0.0021, 0.0022, 12), dark, "Pomo", Vector3.ZERO),
	}
	(_weld_jaw_parts.tornillo as Node3D).rotation.x = PI * 0.5
	(_weld_jaw_parts.pomo as Node3D).rotation.x = PI * 0.5
	_fit_weld_clamp(0.003)


## Las mordazas a los lados de la base de la funda (radio r_m, en m), el puente debajo y el tornillo por delante.
func _fit_weld_clamp(r_m: float) -> void:
	var r := clampf(r_m, 0.001, 0.012)
	var w := 0.006
	var g := r + 0.0008
	var bottom := -(r + 0.0012)
	var top := r * 0.55
	var jh := top - bottom
	(_weld_jaw_parts.puente as Node3D).scale = Vector3(w, 0.0016, 2.0 * g + 0.003)
	(_weld_jaw_parts.puente as Node3D).position = Vector3(0, bottom, 0)
	for k: String in ["delante", "detras"]:
		var j: Node3D = _weld_jaw_parts[k]
		j.scale = Vector3(w, jh, 0.0015)
		j.position = Vector3(0, bottom + jh * 0.5, g + 0.00075 if k == "delante" else -g - 0.00075)
	var sc: Node3D = _weld_jaw_parts.tornillo
	sc.scale = Vector3(1, 0.008, 1)
	# el tornillo y el pomo, por detrás (en la vista de cerca, el pomo no tapa la costura)
	sc.position = Vector3(0, top * 0.3, -g - 0.004)
	(_weld_jaw_parts.pomo as Node3D).position = Vector3(0, top * 0.3, -g - 0.0085)


## La soldadora láser de joyería (como la W150G de la ficha): la cabina con su ventana de filtro, el microscopio coaxial encima y
## la cabeza que baja hacia la pieza.
func _build_weld_laser(mob: bool) -> void:
	var root := Props.node(_weld_root, "Laser")
	var body := ForgeLooks.material("acero", mob, Color(0.86, 0.87, 0.89))
	var dark := Props.mat(Color(0.12, 0.13, 0.15), 0.4, 0.5)
	var c := WELD_POS + Vector3(0.0, 0.0, -0.15)
	Props.mi(root, Props.box(Vector3(0.34, 0.2, 0.16)), body, "Cabina", c + Vector3(0, 0.1, 0))
	Props.mi(root, Props.box(Vector3(0.22, 0.08, 0.004)), Props.glass_mat(Color(0.95, 0.55, 0.1, 0.55)), "FiltroDeLaVentana", c + Vector3(0, 0.12, 0.081))
	Props.mi(root, Props.box(Vector3(0.12, 0.06, 0.006)), dark, "Pantalla", c + Vector3(0.1, 0.17, 0.081))
	# el brazo con la cabeza del haz, encima de la pieza
	Props.mi(root, Props.box(Vector3(0.03, 0.03, 0.2)), body, "Brazo", Vector3(WELD_FIX.x, c.y + 0.2, c.z + 0.1))
	Props.mi(root, Props.cyl(0.008, 0.012, 0.06, 16), dark, "Cabeza", WELD_FIX + Vector3(0, 0.075, 0))
	# el microscopio: dos oculares inclinados hacia quien mira
	for dx: float in [-0.018, 0.018]:
		var eye := Props.mi(root, Props.cyl(0.007, 0.008, 0.06, 12), dark, "Ocular", Vector3(WELD_FIX.x + dx, c.y + 0.25, c.z + 0.17))
		eye.rotation.x = -0.6
	# el rótulo, arriba en el frente de la cabina (lejos de la pieza: en la vista de cerca no se cuela grande y cortado)
	Props.label(root, "LÁSER Nd:YAG", c + Vector3(-0.1, 0.185, 0.083), 0.00022, Color(0.1, 0.1, 0.12))
	_weld_devices["laser"] = root


## La soldadora de micro-TIG (como la PUK de la ficha): la fuente con su pantalla, la antorcha apuntando a la costura y la botella
## de argón.
func _build_weld_tig(mob: bool) -> void:
	var root := Props.node(_weld_root, "MicroTIG")
	var body := Props.mat(Color(0.18, 0.36, 0.62), 0.45, 0.3)
	var dark := Props.mat(Color(0.1, 0.1, 0.12), 0.4, 0.5)
	var c := WELD_POS + Vector3(-0.08, 0.0, -0.17)
	Props.mi(root, Props.box(Vector3(0.22, 0.13, 0.14)), body, "Fuente", c + Vector3(0, 0.065, 0))
	Props.mi(root, Props.box(Vector3(0.09, 0.04, 0.004)), dark, "Pantalla", c + Vector3(0.0, 0.09, 0.071))
	var torch := Props.mi(root, Props.cyl(0.006, 0.009, 0.09, 12), dark, "Antorcha", WELD_FIX + Vector3(0.035, 0.055, 0.0))
	torch.rotation.z = 0.6
	var cup := Props.mi(root, Props.cyl(0.004, 0.0065, 0.012, 12), Props.mat(Color(0.86, 0.62, 0.42), 0.6), "Tobera", WELD_FIX + Vector3(0.012, 0.022, 0.0))
	cup.rotation.z = 0.6
	var bottle := ForgeLooks.material("acero", mob, Color(0.42, 0.5, 0.45))
	Props.mi(root, Props.cyl(0.035, 0.035, 0.3, 20), bottle, "BotellaDeArgon", WELD_POS + Vector3(0.28, 0.15, -0.19))
	Props.mi(root, Props.cyl(0.012, 0.012, 0.03, 12), dark, "Valvula", WELD_POS + Vector3(0.28, 0.315, -0.19))
	Props.label(root, "ARGÓN", WELD_POS + Vector3(0.28, 0.17, -0.154), 0.00035, Color(0.95, 0.95, 0.9))
	Props.label(root, "MICRO-TIG", c + Vector3(0, 0.035, 0.073), 0.00035, Color(0.95, 0.95, 0.9))
	_weld_devices["tig"] = root


## La soldadura fuerte de plata: el soplete con su boquilla hacia la costura, la varilla de plata y el tarro del fundente.
func _build_weld_braze(mob: bool) -> void:
	var root := Props.node(_weld_root, "Soplete")
	var brass := ForgeLooks.material("acero", mob, Color(0.78, 0.62, 0.3))
	var red := Props.mat(Color(0.72, 0.12, 0.1), 0.5, 0.2)
	Props.mi(root, Props.cyl(0.016, 0.016, 0.12, 16), red, "Bombona", WELD_FIX + Vector3(0.1, 0.0, -0.02))
	var nozzle := Props.mi(root, Props.cyl(0.004, 0.006, 0.06, 12), brass, "Boquilla", WELD_FIX + Vector3(0.065, 0.05, -0.01))
	nozzle.rotation.z = 1.1
	var rod := Props.mi(root, Props.cyl(0.0012, 0.0012, 0.12, 6), Props.mat(Color(0.86, 0.86, 0.84), 0.3, 1.0), "VarillaDePlata", WELD_FIX + Vector3(-0.05, 0.02, 0.05))
	rod.rotation.x = 1.0
	Props.mi(root, Props.cyl(0.02, 0.02, 0.025, 16), Props.mat(Color(0.95, 0.95, 0.92), 0.8), "Fundente", WELD_POS + Vector3(-0.2, 0.0125, 0.12))
	Props.label(root, "FUNDENTE", WELD_POS + Vector3(-0.2, 0.027, 0.12), 0.0003, Color(0.2, 0.2, 0.22)).rotation.x = -PI * 0.5
	_weld_devices["braze"] = root


## La mesa de soldar con la vista del estado (5r): el aparato del método, la pieza partida (las mallas del hilo) con la punta
## desalineada lo que diga la mesa, las cuentas de la costura con el color de la zona soldada, el anillo del haz y, con un punto
## nuevo, el destello y el punto incandescente.
func _apply_weld(v: Dictionary) -> void:
	var wv: Dictionary = v.get("weld", {})
	if wv.is_empty():
		return
	var method := String(wv.method)
	for id: String in _weld_devices:
		(_weld_devices[id] as Node3D).visible = id == method
	var wm: Dictionary = v.get("weld_mesh", {})
	var on := bool(wv.get("at_bench", false)) and not wm.is_empty()
	_weld_work.visible = on
	if not on:
		_weld_beads.multimesh.visible_instance_count = 0
		_weld_aim.visible = false
		return
	# en la mesa: la pieza no está en el taller
	_piece.visible = false
	var key := String(wm.key)
	if key != _weld_mesh_key:
		_weld_mesh_key = key
		Props.set_arrays(_weld_base_mesh, wm.base)
		Props.set_arrays(_weld_tip_mesh, wm.tip)
		_mesh_builds += 1
		_weld_s = float(wm.s_mm)
		_weld_r = float(wm.r_mm)
		_weld_k = float(wm.k)
		# la costura en el sitio del soporte; la pinza, en la base de la funda, y la varilla de la mesa hasta ella
		# tumbada a lo largo de la mesa (la base a la izquierda, en la pinza; la punta a la derecha)
		var b := Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5).scaled(Vector3(MM, MM, MM))
		_weld_work.basis = b
		_weld_work.position = WELD_FIX - b * ClawMesh.point_at(_weld_s, _weld_k)
		var s0 := _nat_apex(v) - float(v.sheath.cover_mm) + 1.5
		var jaw := _weld_work.position + b * ClawMesh.point_at(s0, _weld_k)
		_weld_jaw.position = jaw
		var prof: Dictionary = v.get("profile", {})
		var rj := _weld_r * MM
		if prof.has("s") and prof.has("r"):
			rj = (ClawMesh.radius_at(prof.s, prof.r, s0) + float(v.sheath.wall_mm)) * MM
		_fit_weld_clamp(rj)
		var foot := jaw.y - (clampf(rj, 0.001, 0.012) + 0.0012)
		_weld_rod.position = Vector3(jaw.x, (BENCH_H + foot) * 0.5, jaw.z)
		_weld_rod.scale = Vector3(1.0, maxf(foot - BENCH_H, 0.001), 1.0)
	if not _looks.is_empty():
		_weld_base.material_override = _looks.funda[0]
	var tip_id := String(wv.material)
	var tk := "%s|%s" % [tip_id, str(is_mobile())]
	if tk != _weld_tip_mat_key:
		_weld_tip_mat_key = tk
		_weld_tip.material_override = ClawMaterial.material(tip_id, ClawOptics.finish_from_forge("tallado", null, tip_id), { "quality": "movil" if is_mobile() else "escritorio", "uv_mode": 1, "thick_mm": 2.0 })
	# la punta, desalineada lo que diga la mesa (de lado, sobre la normal de la garra)
	_weld_tip.position = ClawMesh.up_at(_weld_s, _weld_k) * float(wv.get("offset_mm", 0.0))
	_paint_weld_beads(wv)
	# un punto nuevo: el destello y el punto incandescente donde ha caído
	var n := int(v.get("fx_n", 0))
	if n > _weld_fx_seen:
		for e: Dictionary in v.get("fx", []):
			if int(e.get("n", 0)) > _weld_fx_seen and String(e.get("kind", "")) == "pulso":
				var segs: Array = wv.get("segments", [])
				var u := (float(e.get("segment", 0)) + 0.5) / float(maxi(segs.size(), 1))
				_weld_hot.position = ClawMesh.surface_point(_weld_s, _weld_r, _weld_k, u * TAU)
				_weld_hot.scale = Vector3.ONE * _bead_r(wv) * 1.25
				_weld_hot_t = 0.0
		_weld_fx_seen = n
	var u_now := float(wv.get("u", -1.0))
	_weld_aim.visible = u_now >= 0.0 and (bool(wv.get("hold", false)) or _weld_mode == "soldar")
	if _weld_aim.visible:
		var a := u_now * TAU
		_weld_aim.position = ClawMesh.surface_point(_weld_s, _weld_r + 0.15, _weld_k, a)
		_weld_aim.basis = _ring_basis(a).scaled(Vector3.ONE * _bead_r(wv) * 1.6)


## El aparato de la mesa de soldar que se ve («laser», «tig», «braze» o «»).
func _weld_visible_device() -> String:
	for id: String in _weld_devices:
		if (_weld_devices[id] as Node3D).visible:
			return id
	return ""


## El radio de dibujo de una cuenta (mm): lo que toca a cada tramo de la vuelta, algo solapado.
func _bead_r(wv: Dictionary) -> float:
	var segs: Array = wv.get("segments", [])
	var w := float((wv.get("spot", {}) as Dictionary).get("widthMm", 0.0))
	return clampf(maxf(w * 0.5, TAU * _weld_r / float(maxi(segs.size(), 1)) * 0.62), 0.12, 1.2)


## La base de una cuenta en el ángulo a de la vuelta: y por la normal de la superficie (hacia fuera), z a lo largo de la garra.
func _ring_basis(a: float) -> Basis:
	var y := ClawMesh.radial_at(_weld_s, _weld_k, a).normalized()
	var z := ClawMesh.tangent_at(_weld_s, _weld_k).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, x.cross(y).normalized())


## Las cuentas de la costura: una por tramo soldado, con el color de la zona soldada del motor (la del punto mientras se suelda y
## la de la unión al acabar; la plata, plateada); limada, a ras de la funda.
func _paint_weld_beads(wv: Dictionary) -> void:
	var segs: Array = wv.get("segments", [])
	var mm := _weld_beads.multimesh
	var col: Dictionary = wv.get("color", {})
	var c := Color(String(col.get("hex", "#C8C3B6"))) if col.has("hex") else Color(0.78, 0.76, 0.71)
	if String(wv.method) == "braze":
		c = Color(0.86, 0.86, 0.83)
	var flush := String(wv.get("next", "")) in ["pulir", "hecho"]
	var rb := _bead_r(wv)
	var k := 0
	for i in mini(segs.size(), WELD_BEADS):
		if int(segs[i]) <= 0:
			continue
		var a := (float(i) + 0.5) / float(segs.size()) * TAU
		var p := ClawMesh.surface_point(_weld_s, _weld_r - (0.05 if flush else 0.0), _weld_k, a)
		var b := _ring_basis(a).scaled(Vector3(rb, rb * (0.12 if flush else 0.45), rb * 0.9))
		mm.set_instance_transform(k, Transform3D(b, p))
		mm.set_instance_color(k, c)
		k += 1
	mm.visible_instance_count = k


## El punto incandescente que se enfría (del amarillo al rojo y a nada, con la rampa del cuerpo negro de core) y el destello del
## pulso: una luz corta y suave, nada de pantalla en blanco (la seguridad: el haz no se mira).
func _animate_weld(dt: float) -> void:
	if _weld_hot_t > WELD_COOL_S + WELD_FLASH_S:
		if _weld_hot.visible:
			_weld_hot.visible = false
			_weld_flash.light_energy = 0.0
		return
	_weld_hot_t += dt
	var u := clampf(_weld_hot_t / WELD_COOL_S, 0.0, 1.0)
	var t_c := 1700.0 * (1.0 - u) + 400.0 * u
	var col := Color(1.0, 0.7, 0.3)
	var strength := 1.0 - u
	if not _ramp.is_empty():
		var g := Incandescence.glow_at(_ramp, t_c)
		col = g.color
		strength = float(g.strength)
	_weld_hot.visible = u < 1.0
	_weld_hot_mat.emission = col
	_weld_hot_mat.albedo_color = Color(col.r, col.g, col.b, 1.0 - u)
	_weld_hot_mat.emission_energy_multiplier = 3.0 * strength * (1.0 - u)
	var f := clampf(1.0 - _weld_hot_t / WELD_FLASH_S, 0.0, 1.0)
	_weld_flash.light_color = Color(1.0, 0.6, 0.3) if String(_v.get("weld", {}).get("method", "")) == "braze" else Color(0.85, 0.92, 1.0)
	_weld_flash.light_energy = 1.6 * f * f


## El punto de la costura (u de 0 a 1) más cerca del puntero en la pantalla, o −1 si está a más de WELD_PICK_PX.
func _seam_u(px: Vector2) -> float:
	var cam := _rig.camera()
	var gt := _weld_work.global_transform
	var best := INF
	var best_u := -1.0
	for i in WELD_SAMPLES:
		var a := float(i) / float(WELD_SAMPLES) * TAU
		var w := gt * ClawMesh.surface_point(_weld_s, _weld_r, _weld_k, a)
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(px)
		if d < best:
			best = d
			best_u = a / TAU
	return best_u if best <= WELD_PICK_PX else -1.0


## Apretar sobre la costura: con las piezas alineadas, el pedal (y el haz donde está el puntero); desalineadas, arrastrar la punta
## la alinea; sin piezas o con la costura acabada, colocarlas.
func _weld_press() -> void:
	var wv: Dictionary = _v.get("weld", {})
	if not bool(wv.get("at_bench", false)) or not bool(wv.get("ready", false)) or bool(wv.get("done", false)):
		_weld_mode = ""
		gesture.emit("weld_prepare", [])
		return
	if not bool(wv.get("aligned", false)):
		_weld_mode = "alinear"
		return
	_weld_mode = "soldar"
	_weld_last_u = _seam_u(_pointer)
	gesture.emit("weld_aim", [_weld_last_u])
	gesture.emit("weld_set_hold", [true])


func _weld_drag(rel: Vector2) -> void:
	match _weld_mode:
		"soldar":
			var u := _seam_u(_pointer)
			if absf(u - _weld_last_u) > 0.004:
				_weld_last_u = u
				gesture.emit("weld_aim", [u])
		"alinear":
			# lo que el arrastre se mueve a lo largo de la normal de la garra en la pantalla, en mm
			var cam := _rig.camera()
			var gt := _weld_work.global_transform
			var c0 := ClawMesh.point_at(_weld_s, _weld_k)
			var p0 := cam.unproject_position(gt * c0)
			var p1 := cam.unproject_position(gt * (c0 + ClawMesh.up_at(_weld_s, _weld_k)))
			var dpx := p1 - p0
			if dpx.length_squared() > 1e-6:
				gesture.emit("weld_nudge", [rel.dot(dpx) / dpx.length_squared()])


func _weld_release() -> void:
	if _weld_mode == "soldar":
		gesture.emit("weld_set_hold", [false])
		gesture.emit("weld_aim", [-1.0])
	_weld_mode = ""
	_weld_last_u = -2.0


# ───────────────────────────── la vista ─────────────────────────────

## La vista del estado (ClawForgeState.view() con las mallas del hilo). Barata si no ha cambiado.
func show_view(v: Dictionary) -> void:
	_ensure_built()
	if v.is_empty() or int(v.get("serial", -1)) == _v_serial:
		return
	_v = v
	_v_serial = int(v.serial)
	if _ramp.is_empty() or not is_same(_ramp, v.get("glow_ramp")):
		_ramp = v.get("glow_ramp", [])
	_apply_meshes(v)
	_apply_bench(v)
	_apply_controls(v)
	_apply_furnace(v)
	_apply_piece(v)
	_apply_lost_wax(v)
	_apply_workshop(v)
	_apply_weld(v)
	_apply_highlight(v)
	if (view_name == "dentro" or (view_name == "pieza" and String(v.piece.get("at", "")) == "horno" and not _piece.visible)) and _visible_mode() != _dentro_mode:
		_apply_view(false)


## Las mallas de la garra y de la funda (hechas en el hilo), solo si han cambiado.
func _apply_meshes(v: Dictionary) -> void:
	var cm: Dictionary = v.get("claw_mesh", {})
	if not cm.is_empty() and String(cm.key) != _claw_key:
		_claw_key = String(cm.key)
		_claw_k = float(cm.k)
		Props.set_arrays(_claw_mesh, cm.arrays)
		_mesh_builds += 1
		var prof: Dictionary = v.profile
		var p := ClawLook.params("none", Color(String(prof.color)), { "light": false, "quality": "movil" if is_mobile() else "" })
		ClawLook.apply(_claw_mat, p)
		var ss: PackedFloat64Array = prof.s
		_claw_mat.set_shader_parameter("apex_mm", ss[ss.size() - 1])
		_barrier_key = ""
		_coat_key = ""
	var sm: Dictionary = v.get("sheath_mesh", {})
	if not sm.is_empty() and String(sm.key) != _sheath_key:
		_sheath_key = String(sm.key)
		Props.set_arrays(_sheath_mesh, sm.arrays)
		_mesh_builds += 1
		var sh: Dictionary = v.sheath
		_sheath_center = ClawMesh.point_at(_nat_apex(v) - float(sh.cover_mm) * 0.5, float(sm.k))


## El plato, el montón, la pantalla, el crisol y los tarros (el de la mano, levantado).
func _apply_bench(v: Dictionary) -> void:
	var b: Dictionary = v.bench
	var total := float(b.total)
	_scale_label.text = String(v.labels.scale)
	_heap.visible = total > 0.0
	if total > 0.0:
		var k := clampf(pow(total / 100.0, 1.0 / 3.0), 0.15, 1.3)
		_heap.scale = Vector3(k, k, k)
		_heap_mat.albedo_color = _mix_color(b.jars)
	var loaded := bool(b.loaded)
	_crucible_fill.visible = loaded
	if loaded:
		_crucible_fill_mat.albedo_color = _heap_mat.albedo_color


## El color de la mezcla (la media de los colores de dibujo de los polvos, por sus gramos).
static func _mix_color(jars: Array) -> Color:
	var c := Color(0, 0, 0)
	var t := 0.0
	for j: Dictionary in jars:
		var g := float(j.grams)
		if g > 0.0:
			var jc := Color(POWDER_COLORS.get(String(j.id), "#CCCCCC"))
			c += jc * g
			t += g
	return Color(c.r / t, c.g / t, c.b / t) if t > 0.0 else Color(0.9, 0.9, 0.9)


## Los mandos: las agujas (hacia su valor), el texto del valor, el margen de la receta y el mando elegido.
func _apply_controls(v: Dictionary) -> void:
	for c: Dictionary in v.controls:
		var id := String(c.id)
		var e: Dictionary = _controls.get(id, {})
		if e.is_empty():
			continue
		var txt := String(c.value_text)
		if String(_labels_key.get(id, "")) != txt:
			_labels_key[id] = txt
			(e.value as Label3D).text = txt
			(e.value as Label3D).modulate = Color(0.55, 1.0, 0.65) if bool(c.margin.has) and bool(c.margin.ok) else (Color(1.0, 0.75, 0.4) if bool(c.margin.has) else Color(1, 1, 1))
		var key := var_to_str([c.margin_t, c.margin.get("options", []), c.margin.has])
		if String(_arc_keys.get(id, "")) != key:
			_arc_keys[id] = key
			var arcs: Array = []
			if bool(e.dial):
				var mt: Array = c.margin_t
				if mt.size() == 2:
					arcs = Props.arc_arrays(0.043, 0.048, Props.dial_angle(float(mt[0])), Props.dial_angle(float(mt[1])), 0.0012, 24)
			elif bool(c.margin.has):
				var opts: Array = (State.control_data(id).options as Array)
				var good: Array = c.margin.options
				var v_all := PackedVector3Array()
				var n_all := PackedVector3Array()
				var i_all := PackedInt32Array()
				for i in opts.size():
					if good.has(String(opts[i])):
						var a := _option_angle(i, opts.size())
						var one := Props.arc_arrays(0.04, 0.046, a + 0.12, a - 0.12, 0.0012, 6)
						var base := v_all.size()
						v_all.append_array(one[Mesh.ARRAY_VERTEX])
						n_all.append_array(one[Mesh.ARRAY_NORMAL])
						for ix: int in (one[Mesh.ARRAY_INDEX] as PackedInt32Array):
							i_all.append(base + ix)
				if not v_all.is_empty():
					arcs = []
					arcs.resize(Mesh.ARRAY_MAX)
					arcs[Mesh.ARRAY_VERTEX] = v_all
					arcs[Mesh.ARRAY_NORMAL] = n_all
					arcs[Mesh.ARRAY_INDEX] = i_all
			Props.set_arrays(e.arc as ArrayMesh, arcs)
		if bool(c.selected):
			_selected_ring.position = (e.pos as Vector3) + Vector3(0, 0, 0.004)


## El ángulo que tiene que marcar la aguja de un mando con su valor.
func _needle_target(c: Dictionary) -> float:
	if bool(_controls[String(c.id)].dial):
		return Props.dial_angle(float(c.t)) - PI * 0.5
	var opts: Array = c.options
	var i := 0
	for k in opts.size():
		if String(opts[k].id) == String(c.value):
			i = k
	return _option_angle(i, opts.size()) - PI * 0.5


## Qué máquina se ve dentro del horno: la de la marcha o, si no ha arrancado, la del modo del dial (ClawForge.machine_for,
## la misma que suena).
func _visible_mode() -> String:
	if _v.is_empty():
		return "bandeja"
	var rv: Dictionary = _v.get("run", {})
	var kind := String(rv.get("kind", ""))
	if kind == "":
		kind = ClawForge.machine_for(String(_ctl(_v, "modo")), ForgeData.RECIPES.get(String(_v.get("process", "")), {}))
	match kind:
		"verneuil":
			return "verneuil"
		"hpht":
			return "hpht"
		"cvd":
			return "cvd"
		"induccion", "colada":
			return "fundir"
	return "bandeja"


## El valor de un mando de la vista, por su id.
static func _ctl(v: Dictionary, id: String) -> Variant:
	for c: Dictionary in v.get("controls", []):
		if String(c.id) == id:
			return c.value
	return null


func _apply_furnace(v: Dictionary) -> void:
	var mode := _visible_mode()
	for k: String in _modes:
		(_modes[k] as Node3D).visible = k == mode
	var rv: Dictionary = v.run
	var kind := String(rv.get("kind", ""))
	var coil := _melt_crucible.get_node("Bobina") as MeshInstance3D
	coil.visible = kind == "induccion" or (kind == "" and String(_ctl(v, "modo")) == "induccion")
	_mold_mat.albedo_color = Color(MOLD_COLORS.get(String(_ctl(v, "mold")), "#EDE8DC"))
	# 5m · cada máquina enseña su carga solo si está metida (o trabajando)
	var iv: Dictionary = v.get("inside", {})
	var ins := String(iv.get("inside", ""))
	var mach := String(iv.get("machine", ""))
	var active := bool(rv.get("active", false))
	_hopper_fill.visible = (mach == "verneuil" and ins == "alimentador") or (active and kind == "verneuil")
	_capsule_in = (mach == "hpht" and ins in ["capsula", "pieza"]) or (active and kind == "hpht")
	var pv0: Dictionary = v.piece
	_capsule.visible = (active and kind == "hpht") or (_capsule_in and not (bool(pv0.get("exists", false)) and String(pv0.get("at", "")) == "horno"))
	_cvd_mold.visible = (mach == "cvd" and ins in ["sustrato", "pieza"]) or (active and kind == "cvd")
	_melt_crucible.visible = (mach in ["induccion", "colada"] and ins in ["crisol", "pieza"]) or (active and kind in ["induccion", "colada"])
	_pellet.visible = mach == "sinterizado" and ins == "pastilla" and not active
	if _pellet.visible:
		var shr: Dictionary = ForgeData.RECIPES.get(String(v.process), {}).get("shrink", {})
		var big := MM / maxf(1.0 - float(shr.get("value", 0.0)), 0.5)
		_pellet.scale = Vector3(big, big, big)
		_pellet.position = Vector3(0, 0.062, 0) - _sheath_center * big
	_gauge.text = String(v.labels.gauge)
	_start_mat.emission_energy_multiplier = 1.5 if bool(rv.get("active", false)) else 0.0
	_cool_mat.emission_energy_multiplier = 1.0 if (not rv.is_empty() and not bool(rv.active) and String(v.stage) == "enfriar") else 0.0


## La pieza: su forma, su sitio y su aspecto (el material con su acabado; el brillo del calor, en advance).
func _apply_piece(v: Dictionary) -> void:
	var pv: Dictionary = v.piece
	var at := String(pv.at)
	var form := String(pv.form)
	var shape := ""
	var cs: Dictionary = v.get("carving", {}).get("state", {})
	if bool(pv.exists) and at != "garra" and at != "":
		if bool(pv.carved):
			shape = "funda"
		elif String(cs.get("kind", "")) == "bloque" and int(cs.get("cuts", 0)) > 0 and bool(pv.ok):
			# 5m · tallándose por pasadas: la silueta del motor, del tocho a la funda
			shape = "tallando"
		else:
			match form:
				"bola":
					shape = "bola"
				"cristal":
					shape = "cristal"
				"bloque", "lingote":
					shape = "bloque"
				_:
					shape = "funda"
	# la colada sigue dentro de su molde hasta que se rompe: se ve el molde, no la pieza (_apply_lost_wax)
	if bool(pv.get("in_mold", false)):
		shape = ""
	# en el horno, la pieza se ve en su máquina: la bola en su pedestal, la colada en el molde, la capa sobre el molde de
	# la CVD; el cristal del HPHT, cuando se abre la prensa
	var rv: Dictionary = v.run
	var mode := _visible_mode()
	if at == "horno" and (mode in ["verneuil", "fundir", "cvd"] or (mode == "hpht" and bool(rv.get("active", false)))):
		shape = ""
	_piece_key = shape
	for k: String in _piece_shapes:
		(_piece_shapes[k] as Node3D).visible = k == shape
	_piece.visible = shape != ""
	_apply_looks(v)
	# el tamaño de cada forma
	var sh: Dictionary = v.sheath
	match shape:
		"bola":
			var bl := maxf(float(rv.get("grown_final", 0.0)) if not rv.is_empty() else 0.0, 4.0)
			var bola := _piece_shapes.bola as Node3D
			(bola.get_node("Cuerpo") as Node3D).scale = Vector3(1, bl, 1)
			(bola.get_node("Cuerpo") as Node3D).position = Vector3(0, bl * 0.5, 0)
			(bola.get_node("Casquete") as Node3D).position = Vector3(0, bl, 0)
		"cristal":
			var mg := float(rv.get("grown_final", 0.0)) if not rv.is_empty() else 0.0
			var vol := maxf(mg / 3515.0, 20.0)  # mm³ con la densidad del diamante (3,515 g/cm³ = 3,515 mg/mm³)
			var r := pow(3.0 * vol / 4.0, 1.0 / 3.0)
			(_piece_shapes.cristal as Node3D).scale = Vector3(r, r, r)
			(_piece_shapes.cristal as Node3D).position = Vector3(0, r, 0)
		"bloque":
			var dmm := float(sh.raw_diameter_mm)
			(_piece_shapes.bloque as Node3D).scale = Vector3(float(sh.length_mm), dmm, dmm)
			(_piece_shapes.bloque as Node3D).position = Vector3(0, dmm * 0.5, 0)
		"funda", "tallando":
			(_piece_shapes.funda as Node3D).position = -_sheath_center + Vector3(0, float(sh.raw_diameter_mm) * 0.5, 0)
			(_piece_shapes.tallando as Node3D).position = (_piece_shapes.funda as Node3D).position
	if shape == "tallando":
		_apply_carve_mesh(v, cs)
	# el bebedero de la colada, hasta que la sierra lo corta; el palo, mientras se talla en una herramienta
	_sprue.visible = shape == "funda" and bool(pv.get("sprue", false))
	if _sprue.visible:
		_place_sprue(v)
	var tool := String(v.act.get("tool", v.get("tool", "")))
	_dop.visible = shape in ["funda", "tallando", "bloque"] and at in ["sierra", "muela", "fresa", "pulidora"]
	if _dop.visible:
		_place_dop(v)
	_piece.position = _piece_world(at, mode, tool)
	_claw_sheath.visible = bool(pv.exists) and at == "garra" and String(v.process) != State.LIVE


## Los materiales de las piezas, de la biblioteca común de las garras (ClawMaterial: los datos ópticos de cada material con
## su acabado, unidad 5e): la pieza suelta (otra malla), la funda (suelta o en la garra, con la malla de la garra: s en mm
## y la punta en apex_mm), la bola de Verneuil del horno (en bruto; la costra, alúmina sin fundir) y la capa de la garra
## viva (ficción: la capa que se ve, o la queratina quemada). Se piden solo cuando cambia lo que enseñan (la biblioteca
## los construye una vez por clave y los comparte: aquí no se toca ninguno; el brillo del calor va en su capa).
func _apply_looks(v: Dictionary) -> void:
	var pv: Dictionary = v.piece
	var lk: Dictionary = pv.get("look", {})
	var rv: Dictionary = v.run
	var coat: Dictionary = v.snap.coat
	var burnt := String(coat.get("defect", "")) == "garra_quemada"
	var crust := String(rv.get("kind", "")) == "verneuil" and String(rv.get("visual", "")) == "costra"
	var res: Dictionary = lk.get("result", {})
	var apex := _nat_apex(v)
	var key := "%d|%s|%s|%s|%s|%s|%s|%s" % [hash(lk), str(is_mobile()), str(apex), str(burnt), str(crust), str(coat.get("ok", false)),
		String(coat.get("material", "")), String(v.profile.color)]
	if key == _look_key or lk.is_empty():
		return
	_look_key = key
	var q := "movil" if is_mobile() else "escritorio"
	var optical := String(lk.optical)
	var grain: Variant = lk.get("grain_um")
	var fin := ClawOptics.finish_from_forge(String(lk.finish), grain, optical)
	var loose: Array = []
	var funda: Array = []
	var boule: Array = []
	var bo := "alumina" if crust else String(lk.boule)
	var bo_fin := ClawOptics.finish_from_forge("bruto", null, bo)
	var growth: Dictionary = ForgeData.RECIPES.zafiro.growth
	var mounted := bool(res.get("ok", false)) and String(res.get("inlay", "none")) != "none"
	# la superficie de la funda tallada o pulida (la de la última muela o el último grano, del motor; unidad 5j), con el
	# codificador de la biblioteca, como en la cetrería: s en mm a lo largo de la garra, hasta la punta de la funda
	var surf := _surface_opts(lk.get("surface", {}), apex + float(v.sheath.wall_mm))
	# un material que la biblioteca aún no tiene (el acrílico de la prótesis, unidad 5j): la queratina con su color de dibujo
	var tint := String(lk.get("tint", ""))
	# [frío, al rojo]: al rojo, el opaco de la biblioteca (el de las gemas lee la pantalla y taparía la capa del calor)
	for qq: String in [q, "movil"]:
		var lo := { "quality": qq, "uv_mode": 1, "thick_mm": float(lk.thick_mm) }
		var fo := { "quality": qq, "apex_mm": apex, "surface": surf }
		if tint != "":
			lo["color"] = Color(tint)
			fo["color"] = Color(tint)
		loose.append(ClawMaterial.material(optical, fin, lo))
		if mounted:
			funda.append(ClawMaterial.for_forge(res, { "quality": qq, "apex_mm": apex, "surface": surf }, String(lk.variety), grain))
		else:
			funda.append(ClawMaterial.material(optical, fin, fo))
		boule.append(ClawMaterial.material(bo, bo_fin, { "quality": qq, "uv_mode": 1, "thick_mm": float(growth.diameter_mm) }))
	_looks = { "loose": loose, "funda": funda, "boule": boule }
	_put_looks("pieza")
	_put_looks("bola")
	_claw_sheath.material_override = funda[0]
	var col := Color(String(v.profile.color))
	if burnt:
		_coat_shell.material_override = ClawMaterial.material("none", ClawOptics.finish("quemado"), { "quality": q, "apex_mm": apex, "color": col })
	elif bool(coat.get("ok", false)):
		_coat_shell.material_override = ClawMaterial.for_forge(res, { "quality": q, "apex_mm": apex, "color": col })


## La superficie de la pieza para la biblioteca (opts.surface de ClawMaterial.material: { id, tex, length_mm }) o {} si no
## la hay (en bruto, rota o con una capa sin pulir: la de su acabado). La textura (ClawMaterial.surface_image) se hace una
## vez por superficie, al tallar o pulir, nunca en cada fotograma; el id lleva lo que la cambia y el largo de la funda.
func _surface_opts(surf: Dictionary, length_mm: float) -> Dictionary:
	if not bool(surf.get("ok", false)):
		return {}
	var key := "forja|%s|%s|%s|%s" % [String(surf.by), var_to_str(float(surf.raUm)), var_to_str(float(surf.chip)), var_to_str(length_mm)]
	if key != _surface_key:
		_surface_key = key
		_surface_tex = ImageTexture.create_from_image(ClawMaterial.surface_image(surf.stations))
	return { "id": key, "tex": _surface_tex, "length_mm": length_mm }


## Los materiales de un grupo («pieza»: la suelta y la funda suelta; «bola»: la de Verneuil del horno), fríos o al rojo.
func _put_looks(group: String) -> void:
	if _looks.is_empty():
		return
	var i := 1 if bool(_hot.get(group, false)) else 0
	if group == "pieza":
		for mi: MeshInstance3D in _piece_loose:
			mi.material_override = _looks.loose[i]
		(_piece_shapes.funda as MeshInstance3D).material_override = _looks.funda[i]
		(_piece_shapes.tallando as MeshInstance3D).material_override = _looks.funda[i]
		_sprue.material_override = _looks.loose[i]
	else:
		_boule_body.material_override = _looks.boule[i]
		_boule_cap.material_override = _looks.boule[i]


## Dónde va la pieza suelta (en el horno, sobre la bandeja o, en la prensa, donde estaba la cápsula; en su palo, en la herramienta
## de la pasada: la sierra, la muela de su grano o el eje flexible).
func _piece_world(at: String, mode: String, tool := "") -> Vector3:
	match at:
		"horno":
			return _chamber.position + Vector3(0, 0.09 if mode == "hpht" else 0.056, 0)
		"cubo":
			return BUCKET_POS + Vector3(0, 0.2, 0)
		"muela":
			return GRINDER_POS + Vector3(float(WHEEL_X.get(tool, 0.0)), 0.17, WHEEL_R + 0.012)
		"sierra":
			return SAW_POS + Vector3(0.0, 0.07, SAW_R * 0.55)
		"fresa":
			return BURR_POS + Vector3(-0.05, 0.05, 0.07)
		"pulidora":
			return POLISHER_POS + Vector3(0, 0.1, 0.055)
		"pistola":
			return BELL_POS + Vector3(0, 0.03, 0)
	return BRICK_POS + Vector3(0, 0.03, 0)


## La silueta de la pieza que se talla (5m): un tubo con los radios de ahora del motor (carve_state().profile.now) en la curva de
## la garra; se rehace solo con una pasada que la cambia.
func _apply_carve_mesh(v: Dictionary, cs: Dictionary) -> void:
	var prof: Dictionary = cs.get("profile", {})
	if prof.is_empty():
		return
	var key := "%d|%s" % [prof.hash(), _claw_key]
	if key == _carve_key:
		return
	_carve_key = key
	var k := float((v.get("claw_mesh", {}) as Dictionary).get("k", _claw_k))
	Props.set_arrays(_carve_mesh, ClawMesh.tube_arrays(prof.s, prof.now, k, 20 if is_mobile() else 32, 0.0))
	_mesh_builds += 1


## El bebedero de la colada (5m): un cilindro del diámetro que dio el motor, pegado a la punta de la funda (dibujo).
func _place_sprue(v: Dictionary) -> void:
	var cast: Dictionary = v.snap.piece.get("cast", {})
	var d := float(cast.get("sprueDiameterMm", 2.0))
	var L := float(cast.get("sprueLengthMm", 8.0))
	var k := float((v.get("claw_mesh", {}) as Dictionary).get("k", _claw_k))
	var apex := _nat_apex(v) + float(v.sheath.wall_mm)
	var t := ClawMesh.tangent_at(apex, k)
	var base := ClawMesh.point_at(apex, k) + (_piece_shapes.funda as Node3D).position
	_sprue.basis = Basis(Quaternion(Vector3.UP, t.normalized())).scaled(Vector3(d * 0.5, L, d * 0.5))
	_sprue.position = base + t.normalized() * L * 0.5


## El palo de lapidario (5m; la pieza se talla pegada a él con cera): en la base de la funda, a lo largo de la garra (dibujo).
func _place_dop(v: Dictionary) -> void:
	var key := "%s|%s|%s" % [_sheath_key, str(_nat_apex(v)), str(float(v.sheath.cover_mm))]
	if key == _dop_key:
		return
	_dop_key = key
	var k := float((v.get("claw_mesh", {}) as Dictionary).get("k", _claw_k))
	var s0 := maxf(_nat_apex(v) - float(v.sheath.cover_mm), 0.0)
	var t := ClawMesh.tangent_at(s0, k).normalized()
	_dop.basis = Basis(Quaternion(Vector3.UP, t))
	_dop.position = ClawMesh.point_at(s0, k) - t * 17.0 + (_piece_shapes.funda as Node3D).position


## La cera perdida en el banco (5m): el modelo de cera hasta que se reviste; el molde revestido en el banco hasta que entra en el
## horno, y con la colada dentro, donde está la pieza hasta que se rompe; en el horno, en la bandeja (al quemar la cera) o en la
## máquina de colar.
func _apply_lost_wax(v: Dictionary) -> void:
	var lw: Dictionary = v.get("lost_wax", {})
	var on := bool(lw.get("on", false))
	_lost_wax_on = on
	var inv: Dictionary = lw.get("invest", {})
	var invested := on and bool(inv.get("ok", false))
	var pv: Dictionary = v.piece
	var in_mold := bool(pv.get("in_mold", false))
	var mold_in := bool(lw.get("mold_in", false))
	_wax_model.visible = on and bool((lw.get("wax", {}) as Dictionary).get("ok", false)) and not invested
	var col := Color(MOLD_COLORS.get(String(inv.get("mold", "yeso")), "#EDE8DC"))
	_flask_mat.albedo_color = col
	_flask_oven_mat.albedo_color = col
	_flask.visible = invested and not mold_in and (in_mold or not bool(pv.get("sprue", false)))
	_flask.position = (_piece_world(String(pv.at), _visible_mode()) + Vector3(0, FLASK_H * 0.5 - 0.03, 0)) if in_mold else WAX_POS + Vector3(0, FLASK_H * 0.5, 0)
	_flask_oven.visible = mold_in and not in_mold
	_flask_cast.visible = mold_in
	_mold.visible = not on


func _apply_workshop(v: Dictionary) -> void:
	var sn: Dictionary = v.snap
	var prof: Dictionary = v.profile
	var live: Dictionary = v.live
	# la barrera sobre la parte con carne viva (de la base al final de la carne viva)
	var bar: Dictionary = sn.barrier
	# la barrera está mientras hace falta: puesta y sin pegar ni recubrir aún, y durante el recubrimiento
	var act: Dictionary = v.act
	var coating := String(act.get("kind", "")) == "coat" and float(act.get("t", 0.0)) < float(act.get("dur", 0.0))
	var has_bar := bool(bar.get("ok", false))
	_barrier.visible = has_bar and (coating or ((sn.bond as Dictionary).is_empty() and (sn.coat as Dictionary).is_empty()))
	if has_bar:
		var apex := _nat_apex(v)
		var s_quick := apex - float(live.get("quickCoverMm", apex * 0.3))
		var th := minf(float(bar.thicknessMm), 6.0)
		var key := "%s|%s|%s" % [_claw_key, var_to_str(s_quick), var_to_str(th)]
		if key != _barrier_key:
			_barrier_key = key
			Props.set_arrays(_barrier_mesh, _shell_arrays(prof, 0.0, s_quick, th))
			_mesh_builds += 1
		_barrier_mat.albedo_color = BARRIER_COLORS.get(String(bar.barrier), Color(0.9, 0.9, 0.95, 0.9))
	# la capa de la garra viva (ficción)
	var coat: Dictionary = sn.coat
	var fiction_coat := bool(coat.get("fiction", false)) and bool(coat.get("ok", false))
	_coat_shell.visible = fiction_coat or (String(v.process) == State.LIVE and String(coat.get("defect", "")) == "garra_quemada")
	if _coat_shell.visible:
		var ss2: PackedFloat64Array = prof.s
		var apex2 := ss2[ss2.size() - 1]
		var cov := float(coat.get("coverMm", 5.0))
		var thick := maxf(float(coat.get("thicknessUm", 300.0)) * MM, 0.15)
		var ck := "%s|%s|%s" % [_claw_key, var_to_str(cov), var_to_str(thick)]
		if ck != _coat_key:
			_coat_key = ck
			Props.set_arrays(_coat_mesh, _shell_arrays(prof, apex2 - cov, apex2 + thick, thick))
			_mesh_builds += 1
	# el termómetro de la carne viva (ficción)
	var show_thermo := String(v.process) == State.LIVE or bool(coat.get("fiction", false))
	_thermo.visible = show_thermo
	_fiction_label.visible = show_thermo
	if show_thermo:
		var q := float(v.labels.thermo_c)
		_thermo_label.text = String(v.labels.thermo)
		var f := clampf((q - 20.0) / 60.0, 0.02, 1.0)
		_thermo_fill.scale = Vector3(1, 0.07 * f, 1)
		_thermo_fill.position = Vector3(-0.012, -0.035 + 0.035 * f, 0.006)
		# el color, el tono que da el estado con el motor (sin dolor, duele, se lesiona)
		_thermo_fill_mat.albedo_color = Palette.color(String({ "bien": "mint", "aviso": "gold", "mal": "coral" }.get(String(v.labels.get("thermo_tone", "bien")), "mint")))
		_thermo_fill_mat.emission = _thermo_fill_mat.albedo_color
	# la pesa
	var chk: Dictionary = sn.check
	_weight.visible = not chk.is_empty()
	if not chk.is_empty():
		var ss3: PackedFloat64Array = prof.s
		_weight.position = ClawMesh.point_at(_nat_apex(v) if _claw_sheath.visible else ss3[ss3.size() - 1], _claw_k)
		_weight_label.text = String(v.labels.weight)


## La punta natural de la garra (mm desde la base), la de su perfil sano (nat_s): hasta ahí llega la funda o la prótesis,
## que en una garra rota rehace lo que falta (unidad 5j).
static func _nat_apex(v: Dictionary) -> float:
	var prof: Dictionary = v.get("profile", {})
	var ss: PackedFloat64Array = prof.get("nat_s", prof.get("s", PackedFloat64Array([0.0])))
	return ss[ss.size() - 1] if not ss.is_empty() else 0.0


## Una cáscara alrededor de la garra de s0 a s1 (mm), con el radio de la garra más th: la barrera o la capa (dibujo).
func _shell_arrays(prof: Dictionary, s0: float, s1: float, th: float) -> Array:
	var ss: PackedFloat64Array = prof.s
	var rs: PackedFloat64Array = prof.r
	var apex := ss[ss.size() - 1]
	var out_s := PackedFloat64Array()
	var out_r := PackedFloat64Array()
	var n := 32
	for i in n:
		var s := s0 + (minf(s1, apex) - s0) * float(i) / float(n - 1)
		out_s.append(s)
		out_r.append(ClawMesh.radius_at(ss, rs, s) + th)
	if s1 > apex:
		for j in range(1, 5):
			var a := float(j) / 4.0 * PI * 0.5
			out_s.append(apex + (s1 - apex) * sin(a))
			out_r.append(maxf((ClawMesh.radius_at(ss, rs, apex) + th) * cos(a), 0.0))
	return ClawMesh.tube_arrays(out_s, out_r, _claw_k, 16, 0.0)


func _apply_highlight(v: Dictionary) -> void:
	var tv: Dictionary = v.tutorial
	var id := String(tv.get("highlight", "")) if bool(tv.get("on", true)) else ""
	if id == _highlight_id:
		return
	_highlight_id = id
	var center := Vector3.ZERO
	var r := float(HIGHLIGHT_R.get(id, 0.06))
	var facing := false
	if _controls.has(id):
		center = (_controls[id].pos as Vector3) + Vector3(0, 0, 0.01)
		r = 0.05
		facing = true
	else:
		var found := false
		for t: Dictionary in _targets:
			if String(t.id) == id:
				center = (t.aabb as AABB).get_center()
				found = true
		facing = id in ["arrancar", "sacar", "ventana"]
		if not found:
			_highlight.visible = false
			return
	_highlight.visible = id != ""
	_highlight.position = center
	_highlight.scale = Vector3(r, r * 0.15 if not facing else r, r)
	_highlight.rotation = Vector3(PI * 0.5, 0, 0) if facing else Vector3.ZERO


# ───────────────────────────── vistas de la cámara ─────────────────────────────

func _apply_view(instant: bool) -> void:
	if _rig == null:
		return
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1.0, 1.0)
	_aspect = clampf(vs.x / maxf(vs.y, 1.0), 0.4, 1.6)
	# lo que queda a la vista: sin lo que tapan los mandos de la página por la derecha (en el teléfono, el deslizador grande)
	var aspect := _aspect * (1.0 - inset_right)
	var far := 1.0 / pow(minf(aspect, 1.0), 0.8)
	match view_name:
		"general":
			_orbit(Vector3(0.12, 0.78, 0.0), 0.0, 16.0, _fit(2.75, 1.2, 40.0, aspect), 40.0, instant)
		"banco":
			# los tarros, la balanza, el crisol y la caja de las piedras caben de lado a lado (también en vertical)
			_orbit(Vector3(-0.81, 0.97, -0.02), 4.0, 38.0, _fit(0.95, 0.44, 38.0, aspect), 38.0, instant)
		"horno":
			# el panel de mandos de cerca (los rótulos de los diales se leen); la ventana, en «dentro»
			_orbit(Vector3(0.0, 0.47, FRONT_Z), 0.0, 4.0, _fit(0.85, PANEL_HALF_W, 40.0, aspect), 40.0, instant)
		"dentro":
			_frame_inside(far, instant)
		"taller":
			_orbit(Vector3(1.1, 1.0, 0.04), -4.0, 30.0, _fit(1.05, 0.4, 38.0, aspect), 38.0, instant)
		"soldar":
			# 5r · la mesa de soldar de cerca: las dos piezas en su soporte, la costura y el aparato detrás
			_orbit(WELD_FIX + Vector3(0.0, 0.002, 0.0), -14.0, 24.0, 0.06 * far, 34.0, instant)
		"pieza":
			var pv: Dictionary = _v.get("piece", {})
			if String(pv.get("at", "")) == "horno" and bool(pv.get("exists", false)) and not _piece.visible:
				# la pieza sigue en su máquina (la bola en su pedestal, la colada en el molde, la capa en el de la CVD)
				_frame_inside(far, instant)
			elif String(_v.get("process", "")) == State.LIVE:
				# la garra viva y su termómetro (ficción)
				_orbit((CLAW_POS + THERMO_POS) * 0.5 + Vector3(0, -0.01, 0), -6.0, 16.0, 0.34 * far, 36.0, instant)
			else:
				var p := _piece.position if _piece.visible else (CLAW_POS + Vector3(0.02, -0.01, 0))
				_orbit(p + Vector3(0, 0.005, 0), 10.0, 24.0, 0.16 * far, 34.0, instant)


## Lo que tapan los mandos de la página sobre la vista, por la derecha (fracción del ancho, 0-0,5; en el teléfono, el
## deslizador grande y los botones de arrancar y enfriar): las vistas encuadran lo suyo en lo que queda a la izquierda (la
## columna derecha del panel del horno ya no queda debajo del deslizador). Presentación, no física.
func set_inset_right(f: float) -> void:
	var v := clampf(f, 0.0, 0.5)
	if absf(v - inset_right) < 1e-4:
		return
	inset_right = v
	_apply_view(false)


## La órbita de una vista con lo que tapan los mandos por la derecha: el objetivo se corre a la derecha de la cámara la
## parte tapada de media pantalla a esa distancia, y así lo encuadrado queda en el centro de lo que se ve.
func _orbit(target: Vector3, yaw: float, pitch: float, dist: float, fov: float, instant: bool) -> void:
	var half_w := dist * tan(deg_to_rad(fov * 0.5)) * _aspect
	var az := deg_to_rad(yaw)
	_rig.set_orbit(target + Vector3(cos(az), 0.0, -sin(az)) * inset_right * half_w, yaw, pitch, dist, fov, instant)


## La distancia de la cámara para que quepa de lado a lado un ancho de 2·half_w (m) con el campo de fov grados (vertical) y
## esa proporción de la vista; como poco, base (la de escritorio).
static func _fit(base: float, half_w: float, fov: float, aspect: float) -> float:
	return maxf(base, half_w / (tan(deg_to_rad(fov * 0.5)) * aspect))


## La vista «Dentro»: de cerca, donde trabaja la máquina de ahora (las piezas son de unos centímetros).
func _frame_inside(far: float, instant: bool) -> void:
	var at := _chamber.position
	_dentro_mode = _visible_mode()
	match _dentro_mode:
		"verneuil":
			_orbit(at + Vector3(0, CAVITY.y - 0.2, 0.02), 0.0, 6.0, 0.3 * far, 40.0, instant)
		"fundir":
			_orbit(at + Vector3(0.05, 0.08, 0.02), -8.0, 18.0, 0.34 * far, 40.0, instant)
		"hpht":
			_orbit(at + Vector3(0, 0.17, 0.02), 0.0, 8.0, 0.36 * far, 40.0, instant)
		"cvd":
			_orbit(at + Vector3(0, 0.1, 0.02), 0.0, 12.0, 0.3 * far, 40.0, instant)
		_:
			_orbit(at + Vector3(0, 0.06, 0.0), 0.0, 30.0, 0.15 * far, 40.0, instant)


# ───────────────────────────── cada fotograma ─────────────────────────────

func advance(delta: float) -> void:
	_ensure_built()
	var t0 := Time.get_ticks_usec()
	var dt := maxf(delta, 0.0)
	_t += dt
	_rig.step(dt)
	if not _v.is_empty():
		_animate(dt)
	var us := Time.get_ticks_usec() - t0
	_upd_n += 1
	_upd_sum += us
	_upd_max = maxi(_upd_max, us)


## La temperatura de las paredes de la cámara (dibujo): al sinterizar, calentar o fundir en el horno, la de la carga; en
## Verneuil la llama está dentro de una mufla y las paredes se quedan en la mitad; la bobina de inducción calienta solo la
## carga, la prensa del HPHT calienta la cápsula por dentro y la CVD solo el molde: paredes frías.
static func _wall_temp(t_c: float, kind: String) -> float:
	match kind:
		"verneuil":
			return 20.0 + (t_c - 20.0) * 0.5
		"induccion", "hpht", "cvd":
			return 20.0
	return t_c


## Pone en un material el brillo de lo que está a t_c: el color de la rampa de core (cuerpo negro) y una energía de la
## emisión que crece con el brillo (esa compresión es dibujo). Solo si la temperatura ha cambiado (k: lo que brilla ese
## material frente a la pieza).
func _set_glow(m: BaseMaterial3D, t_c: float, k := 1.0) -> void:
	var id := m.get_instance_id()
	var key := t_c * 1000.0 + k
	if float(_glow_seen.get(id, -1.0)) == key:
		return
	_glow_seen[id] = key
	var g := Incandescence.glow_at(_ramp, t_c)
	var s := float(g.strength)
	m.emission = g.color
	m.emission_energy_multiplier = (s * s * 8.0 + (0.4 * s if s > 0.0 else 0.0)) * k


## El brillo del calor de una pieza encima de su material de la biblioteca (compartido: no se toca): la capa aditiva de
## Props.heat_overlay con el color de la rampa de core y su energía (dibujo, como _set_glow); al rojo, el grupo lleva el
## material opaco de la biblioteca (el de las gemas lee la pantalla y taparía la capa); fría, el suyo y sin capa (ni la
## pasada de más). Solo si la temperatura ha cambiado.
func _set_overlay(m: StandardMaterial3D, group: String, mis: Array, t_c: float, k := 1.0) -> void:
	var id := m.get_instance_id()
	var key := t_c * 1000.0 + k
	if float(_glow_seen.get(id, -1.0)) == key:
		return
	_glow_seen[id] = key
	var g := Incandescence.glow_at(_ramp, t_c)
	var s := float(g.strength)
	m.emission = g.color
	m.emission_energy_multiplier = (s * s * 8.0 + 0.4 * s) * k
	var on := s > 0.0
	if on != bool(_hot.get(group, false)):
		_hot[group] = on
		_put_looks(group)
	for mi: MeshInstance3D in mis:
		mi.material_overlay = m if on else null


func _animate(dt: float) -> void:
	var v := _v
	var k := 1.0 - exp(-10.0 * dt)
	# las agujas de los mandos
	for c: Dictionary in v.controls:
		var id := String(c.id)
		var e: Dictionary = _controls.get(id, {})
		if e.is_empty():
			continue
		var a := float(_needles[id])
		a += (_needle_target(c) - a) * k
		_needles[id] = a
		(e.needle as Node3D).rotation.z = a
	# el horno y lo que trabaja dentro: la temperatura de la marcha o la de la pieza que sigue dentro
	var rv: Dictionary = v.run
	var pv: Dictionary = v.piece
	var kind := String(rv.get("kind", ""))
	var active := bool(rv.get("active", false))
	var in_furnace := String(pv.get("at", "")) == "horno"
	var temp := 20.0
	if active:
		temp = float(rv.temp_c)
	elif in_furnace:
		temp = float(pv.get("temp_c", 20.0))
	_set_glow(_cavity_mat, _wall_temp(temp, kind if active else ""), 0.12)
	# Verneuil: la llama y la bola que crece hacia abajo (y se queda en su pedestal mientras sigue en el horno)
	if (_modes.verneuil as Node3D).visible:
		var visual := String(rv.get("visual", ""))
		var on := active and kind == "verneuil" and visual != "sin_llama"
		_flame.visible = on
		if on:
			var f := 1.0 + 0.08 * sin(_t * 31.0) + 0.05 * sin(_t * 17.3 + 1.0)
			_flame.scale = Vector3(f, 1.0 + 0.1 * sin(_t * 23.0), f)
			_flame_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.5) if visual == "hollin" else Color(0.45, 0.6, 1.0, 0.25)
		var grown := float(rv.get("grown", 0.0)) if kind == "verneuil" else 0.0
		_boule_len += (grown - _boule_len) * k
		var shown := minf(_boule_len, 80.0)
		var crust := kind == "verneuil" and visual == "costra"
		_boule.visible = kind == "verneuil" and (active or in_furnace) and (shown > 0.05 or crust or active)
		var len_m := maxf(shown, 1.5 if crust or active else 0.0) * MM
		_boule_body.scale = Vector3(1, maxf(len_m, 0.0005), 1)
		_boule_body.position = Vector3(0, -len_m * 0.5, 0)
		_pedestal.position = Vector3(0, CAVITY.y - 0.23 - len_m - 0.1, 0)
		_set_overlay(_boule_glow, "bola", [_boule_body, _boule_cap], temp)
	# fundir: el metal al rojo en el crisol, la bobina, la colada y el molde que guarda la pieza
	if (_modes.fundir as Node3D).visible:
		var melting := active and kind in ["induccion", "colada"]
		var pour := float(rv.get("pour", 0.0))
		_melt.visible = melting and pour < 0.5
		_set_glow(_melt_mat, temp if melting else 20.0)
		_melt_mat.albedo_color = _melt_mat.emission
		_coil_mat.emission = Color(1.0, 0.35, 0.1) if active and kind == "induccion" else Color(0, 0, 0)
		_coil_mat.emission_energy_multiplier = 0.3 + 0.2 * sin(_t * 6.0) if active and kind == "induccion" else 0.0
		var tilt_target := deg_to_rad(-70.0) * clampf(pour * 3.0, 0.0, 1.0) if pour > 0.0 and pour < 1.0 else 0.0
		_tilt += (tilt_target - _tilt) * k
		_melt_crucible.rotation.z = _tilt
		_pour.visible = pour > 0.05 and pour < 0.95
		if _pour.visible:
			var top := _melt_crucible.position + Vector3(0.05, 0.04, 0)
			var bottom := _mold.position + Vector3(0, 0.03, 0)
			_pour.position = (top + bottom) * 0.5
			_pour.scale = Vector3(1, maxf(top.y - bottom.y, 0.01), 1)
			_set_glow(_pour_mat, temp)
		_mold_mat.emission_enabled = true
		_set_glow(_mold_mat, float(pv.get("temp_c", 20.0)) if in_furnace and not melting else 20.0, 0.6)
	# HPHT: la prensa se cierra en la marcha y se abre al acabar
	if (_modes.hpht as Node3D).visible:
		var closed := active and kind == "hpht"
		_anvil_gap += ((0.0 if closed else 1.0) - _anvil_gap) * (1.0 - exp(-3.0 * dt))
		_anvil_top.position = Vector3(0, 0.25 + 0.05 * _anvil_gap, 0)
		_anvil_bottom.position = Vector3(0, 0.09 - 0.05 * _anvil_gap, 0)
		_set_glow(_capsule_mat, temp if closed else 20.0, 0.3)
		# acabada la marcha, la cápsula se abre y el cristal queda sobre el yunque de abajo
		_capsule.visible = closed or (_capsule_in and not (bool(pv.get("exists", false)) and in_furnace))
	# CVD: el plasma que late sobre el molde y la capa que crece
	if (_modes.cvd as Node3D).visible:
		var on2 := active and kind == "cvd" and String(rv.get("visual", "")) == "crece"
		_plasma.visible = on2
		if on2:
			var pulse := 1.0 + 0.06 * sin(_t * 9.0)
			_plasma.scale = Vector3(pulse, pulse * 0.85, pulse)
		_set_glow(_heater_mat, temp if (active and kind == "cvd") or in_furnace else 20.0)
		var layer := clampf(float(rv.get("grown", 0.0)) / maxf(float(rv.get("need", 1.0)), 1.0), 0.0, 1.0) if kind == "cvd" else 0.0
		_cvd_mat.albedo_color = Color(0.42, 0.44, 0.47).lerp(Color(0.18, 0.18, 0.2), layer)
		_set_glow(_cvd_mat, temp if in_furnace or active else 20.0, 0.5)
	# la pieza suelta: su brillo y, al sinterizar, lo que encoge
	if _piece.visible:
		_set_overlay(_piece_glow, "pieza", _piece_mis, temp if active else float(pv.get("temp_c", 20.0)))
		var shrink_target := 0.0
		if kind == "sinterizado" and String(rv.get("visual", "")) == "crece":
			var sh: Dictionary = ForgeData.RECIPES.get(String(v.process), {}).get("shrink", {})
			shrink_target = float(sh.get("value", 0.0)) - float(rv.get("shrink", 0.0))
		_shrink += (shrink_target - _shrink) * k
		var sc := MM / maxf(1.0 - _shrink, 0.5)
		_piece.scale = Vector3(sc, sc, sc)
	# el taller: la muela gira con su agua, la pulidora, el chorro de la pistola, la campana
	var act: Dictionary = v.act
	var acting := not act.is_empty() and float(act.t) < float(act.dur)
	var akind := String(act.get("kind", ""))
	# 5m · la puerta se abre y se cierra mientras entra la carga, que va del banco a su sitio en la máquina
	_animate_insert(v, act, acting and akind == "insert")
	# 5m · el molde de la cera perdida brilla con el horno al quemarla; el metal sube por el bebedero al colar
	if _flask_oven.visible or _flask_cast.visible:
		var hot := temp if active else (float(pv.get("temp_c", 20.0)) if in_furnace else 20.0)
		_set_glow(_flask_oven_mat, hot, 0.5)
	var pour2 := float(rv.get("pour", 0.0))
	_cast_fill.visible = _flask_cast.visible and pour2 > 0.0
	if _cast_fill.visible:
		var fill := float((v.snap.piece.get("cast", {}) as Dictionary).get("filled", 1.0)) * clampf(pour2 * 1.4, 0.0, 1.0)
		_cast_fill.scale = Vector3(1, maxf(0.012 * fill, 0.001), 1)
		_cast_fill.position = Vector3(0.11, FLASK_H + 0.006 * fill, 0.06)
		_set_glow(_cast_fill_mat, temp)
	# 5m · las pasadas: la sierra, las muelas o la fresa giran mientras trabajan, con su agua
	var ptool := String(act.get("tool", "")) if acting and akind == "pass" and bool(act.get("bites", false)) else ""
	if ptool == "sierra":
		_saw_disc.rotation.x += dt * 40.0
	if ptool in ["muela_gruesa", "muela_fina"]:
		_wheel.rotation.x += dt * 25.0
	var burr_goal := _burr_rest
	if ptool == "fresa":
		burr_goal = _piece.position + Vector3(0.045, 0.004 * sin(_t * 60.0), 0.0)
	_burr.position = _burr.position.lerp(burr_goal, k)
	if acting and akind == "carve":
		_wheel.rotation.x += dt * 25.0
	if acting and akind == "polish":
		_polish_wheel.rotation.x += dt * 30.0
	var method := String(act.get("method", ""))
	_gun_plume.visible = acting and akind == "coat" and method in ["plasma_alumina", "fundido"]
	if _gun_plume.visible:
		# en el marco de la pistola (que está en GUN_POS, sin girar)
		var target := (_piece.position if String(act.get("target", "funda")) == "funda" else CLAW_POS + Vector3(0.025, -0.008, 0.0)) - GUN_POS
		var nozzle := Vector3(-0.08, 0, 0)
		var d := target - nozzle
		_gun_plume.position = nozzle + d * 0.5
		_gun_plume.basis = Basis(Quaternion(Vector3.UP, d.normalized())).scaled(Vector3(1.0 + 0.1 * sin(_t * 40.0), d.length(), 1.0))
	var vacuum := acting and akind == "coat" and method in ["sputter_alumina", "pvd_tin", "cvd_diamante"]
	_bell_glow_mat.emission_energy_multiplier = (1.5 + 0.3 * sin(_t * 12.0)) if vacuum else 0.0
	_bell_glow_mat.albedo_color.a = 0.3 if vacuum else 0.0
	# partículas
	_fill_bubbles(acting and akind in ["cool_agua", "cool_aceite"], float(act.get("t", 0.0)) / maxf(float(act.get("dur", 1.0)), 1e-3))
	_fill_drops(acting and (akind == "carve" or ptool in ["muela_gruesa", "muela_fina"]) and bool(v.workshop.carve.get("coolant", true)))
	_fill_powder(String(v.bench.held), bool(v.bench.pouring))
	_water_mat.albedo_color = Color(0.45, 0.32, 0.1, 0.85) if String(act.get("medium", _ctl(v, "cool"))) == "aceite" else Color(0.22, 0.38, 0.48, 0.75)
	# el tarro en la mano sigue al puntero (por encima del banco)
	_move_held(String(v.bench.held), k)
	# el resaltado late
	if _highlight.visible:
		_highlight_mat.emission_energy_multiplier = 1.2 + 0.8 * sin(_t * 5.0)
	# 5r · la mesa de soldar: el punto incandescente que se enfría y el destello
	_animate_weld(dt)


## Meter la carga (5m; dibujo): la puerta sube y baja (abierta en medio de la animación) y lo que entra va del banco a su sitio
## en la máquina por un arco: el crisol, la alúmina, la cápsula, el sustrato o la pastilla desde el sitio del crisol; el molde
## desde la cera perdida; la pieza desde el ladrillo.
func _animate_insert(v: Dictionary, act: Dictionary, on: bool) -> void:
	var u := clampf(float(act.get("t", 0.0)) / maxf(float(act.get("dur", 1.0)), 1e-3), 0.0, 1.0) if on else 1.0
	_door.position.y = CAVITY.y * 0.92 * sin(PI * u) if on else 0.0
	var what := String(act.get("what", "")) if on else ""
	_carry.visible = on and what != "" and what != "pieza" and u > 0.05 and u < 0.85
	if not _carry.visible:
		return
	if what != _carry_kind:
		_carry_kind = what
		_carry_mat.albedo_color = Color(CARRY_COLORS.get(what, "#999999"))
		match what:
			"crisol":
				_carry.scale = Vector3(0.035, 0.055, 0.035)
			"capsula":
				_carry.scale = Vector3(0.025, 0.05, 0.025)
			"sustrato":
				_carry.scale = Vector3(0.04, 0.008, 0.04)
			"pastilla":
				_carry.scale = Vector3(0.02, 0.012, 0.02)
			"molde":
				_carry.scale = Vector3(FLASK_R, FLASK_H, FLASK_R)
				_carry_mat.albedo_color = Color(MOLD_COLORS.get(String(_ctl(v, "mold")), "#EDE8DC"))
			_:
				_carry.scale = Vector3(0.03, 0.03, 0.03)
	var from := WAX_POS + Vector3(0, FLASK_H * 0.5, 0) if what == "molde" else CRUCIBLE_POS + Vector3(0, 0.03, 0)
	var to := _chamber.position + Vector3(0, 0.08, -0.02)
	match String(act.get("machine", "")):
		"verneuil":
			to = _chamber.position + Vector3(0, CAVITY.y - 0.03, 0)
		"induccion", "colada":
			to = _chamber.position + Vector3(0, 0.12, -0.04)
		"hpht":
			to = _chamber.position + Vector3(0, 0.17, 0)
	var w := clampf((u - 0.05) / 0.8, 0.0, 1.0)
	var front := Vector3(to.x, to.y + 0.05, FRONT_Z + 0.08)
	var pos := from.lerp(front, minf(w / 0.6, 1.0)) if w < 0.6 else front.lerp(to, (w - 0.6) / 0.4)
	pos.y += 0.12 * sin(PI * minf(w / 0.6, 1.0)) if w < 0.6 else 0.0
	_carry.position = pos


## Las burbujas y el vapor del temple: alturas que suben en ciclo (deterministas, sin estado) y se apagan al final.
func _fill_bubbles(on: bool, u: float) -> void:
	var mm := _bubbles_mmi.multimesh
	var sm := _steam_mmi.multimesh
	if not on:
		mm.visible_instance_count = 0
		sm.visible_instance_count = 0
		return
	var strength := clampf(1.0 - u, 0.0, 1.0)
	var nb := int(float(BUBBLES) * strength)
	for i in nb:
		var fi := float(i)
		var a := fi * 2.399
		var r := 0.02 + 0.1 * fmod(fi * 0.618, 1.0)
		var cyc := fmod(_t * (0.6 + 0.4 * fmod(fi * 0.37, 1.0)) + fi * 0.13, 1.0)
		var p := BUCKET_POS + Vector3(cos(a) * r, 0.18 + 0.1 * cyc, sin(a) * r)
		_put(_bubbles_buf, i, p, 1.0 + 0.6 * cyc, Color(1, 1, 1, 0.6 * (1.0 - cyc)))
	mm.buffer = _bubbles_buf
	mm.visible_instance_count = nb
	var ns := int(float(STEAM) * strength)
	var cam_b := _rig.camera().global_basis
	for i in ns:
		var fi := float(i)
		var cyc := fmod(_t * 0.5 + fi * 0.21, 1.0)
		var p := BUCKET_POS + Vector3(0.06 * sin(fi * 1.7 + _t), 0.3 + 0.35 * cyc, 0.06 * cos(fi * 2.3))
		_put_basis(_steam_buf, i, cam_b.scaled(Vector3.ONE * (0.6 + 1.6 * cyc)), p, Color(1, 1, 1, 0.22 * (1.0 - cyc)))
	sm.buffer = _steam_buf
	sm.visible_instance_count = ns


## Las gotas del agua de la muela.
func _fill_drops(on: bool) -> void:
	var mm := _drops_mmi.multimesh
	if not on:
		mm.visible_instance_count = 0
		return
	for i in DROPS:
		var fi := float(i)
		var cyc := fmod(_t * 2.5 + fi / float(DROPS), 1.0)
		var p := GRINDER_POS + Vector3(0.004 * sin(fi), 0.33 - 0.16 * cyc * cyc, -0.03 + 0.03 * cyc)
		_put(_drops_buf, i, p, 1.0, Color(0.7, 0.85, 1.0, 0.8))
	mm.buffer = _drops_buf
	mm.visible_instance_count = DROPS


## El polvo que cae del tarro al plato mientras se vierte.
func _fill_powder(held: String, pouring: bool) -> void:
	var mm := _powder_mmi.multimesh
	_stream.visible = pouring and held != ""
	if not _stream.visible:
		mm.visible_instance_count = 0
		return
	var top := _held_pos
	var bottom := SCALE_POS + Vector3(0, PAN_Y + 0.01, 0)
	var col := Color(POWDER_COLORS.get(held, "#EEEEEE"))
	_stream.position = (top + bottom) * 0.5
	_stream.scale = Vector3(1, maxf(top.y - bottom.y, 0.005), 1)
	_stream_mat.albedo_color = Color(col.r, col.g, col.b, 0.7)
	for i in POWDER:
		var cyc := fmod(_t * 3.0 + float(i) / float(POWDER), 1.0)
		_put(_powder_buf, i, top.lerp(bottom, cyc) + Vector3(0.003 * sin(float(i) * 3.1), 0, 0.003 * cos(float(i) * 1.7)), 1.0, col)
	mm.buffer = _powder_buf
	mm.visible_instance_count = POWDER


static func _put(buf: PackedFloat32Array, i: int, p: Vector3, s: float, c: Color) -> void:
	var o := i * 16
	buf[o] = s
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = p.x
	buf[o + 4] = 0.0
	buf[o + 5] = s
	buf[o + 6] = 0.0
	buf[o + 7] = p.y
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = s
	buf[o + 11] = p.z
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = c.a


static func _put_basis(buf: PackedFloat32Array, i: int, b: Basis, p: Vector3, c: Color) -> void:
	var o := i * 16
	buf[o] = b.x.x
	buf[o + 1] = b.y.x
	buf[o + 2] = b.z.x
	buf[o + 3] = p.x
	buf[o + 4] = b.x.y
	buf[o + 5] = b.y.y
	buf[o + 6] = b.z.y
	buf[o + 7] = p.y
	buf[o + 8] = b.x.z
	buf[o + 9] = b.y.z
	buf[o + 10] = b.z.z
	buf[o + 11] = p.z
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = c.a


## El tarro de la mano: levantado y siguiendo al puntero sobre el banco (o encima del plato mientras vierte); los demás,
## en su sitio.
func _move_held(held: String, k: float) -> void:
	for id: String in _jars:
		var jar: Node3D = _jars[id]
		var rest: Vector3 = _jar_rest[id]
		var goal := rest
		if id == held:
			goal = rest + Vector3(0, 0.08, 0.04)
			if _has_pointer:
				var p: Variant = _pointer_on_plane(BENCH_H + 0.14)
				if p != null:
					goal = (p as Vector3) + Vector3(0, -0.06, 0)
		jar.position = jar.position.lerp(goal, k)
		jar.rotation.z = lerpf(jar.rotation.z, deg_to_rad(-55.0) if id == held and _pouring else 0.0, k)
	if held != "":
		_held_pos = (_jars[held] as Node3D).position + Vector3(-0.03, 0.05, 0.0)


## Donde el rayo del puntero corta el plano horizontal y = h (null si no lo corta delante de la cámara).
func _pointer_on_plane(h: float) -> Variant:
	var cam := _rig.camera()
	var o := cam.project_ray_origin(_pointer)
	var d := cam.project_ray_normal(_pointer)
	if absf(d.y) < 1e-4:
		return null
	var t := (h - o.y) / d.y
	if t <= 0.0:
		return null
	return o + d * t


# ───────────────────────────── el puntero ─────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(event):
		get_viewport().set_input_as_handled()


## Traduce un evento del puntero (ratón o dedo) en gestos y cámara. Devuelve si lo ha usado.
func handle_pointer(event: InputEvent) -> bool:
	_ensure_built()
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_pinch = _pinch_distance()
			_pressed = false
			return true
		return false
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			if sd.index == 0:
				_rig.orbit_by(sd.relative)
			var dd := _pinch_distance()
			if _pinch > 0.0 and dd > 0.0:
				_rig.zoom_by(_pinch / dd)
			_pinch = dd
			return true
		return false
	if _touches.size() >= 2:
		return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# lo que se ha movido: de la posición de antes (los eventos sintéticos de la demo y los tests no traen relative)
		var rel := mm.position - _pointer if _has_pointer else Vector2.ZERO
		_pointer = mm.position
		_has_pointer = true
		_shift = mm.shift_pressed
		match _cam_drag:
			"orbita":
				_rig.orbit_by(mm.relative)
				return true
			"pan":
				_rig.pan_by(mm.relative)
				return true
		if _pressed:
			_drag(rel)
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_pointer = mb.position
		_has_pointer = true
		_shift = mb.shift_pressed
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press()
				else:
					_release()
				return true
			MOUSE_BUTTON_RIGHT:
				_cam_drag = ("pan" if mb.shift_pressed else "orbita") if mb.pressed else ""
				return true
			MOUSE_BUTTON_MIDDLE:
				_cam_drag = "pan" if mb.pressed else ""
				return true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed:
					return true
				var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
				var over := hit_at(_pointer)
				if over.begins_with("mando:"):
					gesture.emit("turn_control", [over.substr(6), 1 if up else -1, mb.shift_pressed])
				else:
					_rig.zoom_by(0.88 if up else 1.0 / 0.88)
				return true
	if event is InputEventMagnifyGesture:
		_rig.zoom_by(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
		return true
	if event is InputEventPanGesture:
		_rig.orbit_by((event as InputEventPanGesture).delta * 6.0)
		return true
	return false


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


## Botón izquierdo (o un dedo): coger un tarro, empezar a girar un mando, pulsar un botón o un sitio del taller.
func _press() -> void:
	var id := hit_at(_pointer)
	_pressed = true
	_press_target = id
	_press_pos = _pointer
	_drag_acc = 0.0
	_dragged = false
	var held := String(_v.get("bench", {}).get("held", ""))
	_press_held = held
	if id.begins_with("tarro:"):
		var jid := id.substr(6)
		if jid != held:
			gesture.emit("pick_jar", [jid])
		return
	if id == "balanza" and held != "":
		_pouring = true
		gesture.emit("set_pouring", [true, _shift])
		return
	if id.begins_with("mando:"):
		gesture.emit("select_control", [id.substr(6)])
		return
	if id == "costura":
		_weld_press()
		return


func _drag(rel: Vector2) -> void:
	var id := _press_target
	if id == "costura":
		_weld_drag(rel)
		return
	if id.begins_with("mando:"):
		_drag_acc += -rel.y + rel.x * 0.5
		var steps := int(_drag_acc / DRAG_PX)
		if steps != 0:
			_drag_acc -= float(steps) * DRAG_PX
			_dragged = true
			gesture.emit("turn_control", [id.substr(6), steps, _shift])
		return
	# el tarro en la mano: verter mientras está sobre el plato
	var held := String(_v.get("bench", {}).get("held", ""))
	if held != "":
		var over := hit_at(_pointer) == "balanza"
		if over != _pouring:
			_pouring = over
			gesture.emit("set_pouring", [over, _shift])


func _release() -> void:
	if not _pressed:
		return
	_pressed = false
	var id := _press_target
	var held := String(_v.get("bench", {}).get("held", ""))
	if _pouring:
		_pouring = false
		gesture.emit("set_pouring", [false, false])
		return
	var here := hit_at(_pointer)
	if id == "costura":
		_weld_release()
		return
	if id.begins_with("tarro:"):
		# un clic sobre el tarro que ya estaba en la mano lo deja (el clic que lo coge, no)
		if id.substr(6) == _press_held and here == id:
			gesture.emit("drop_jar", [])
		return
	if id.begins_with("mando:"):
		if not _dragged and not bool(_controls[id.substr(6)].dial):
			gesture.emit("turn_control", [id.substr(6), 1, false])
		return
	# arrastrar el crisol hasta la puerta del horno: meter la carga (5m)
	if id == "crisol" and here == "ventana":
		gesture.emit("insert_charge", [])
		return
	if here != id:
		return
	match id:
		"balanza":
			if held != "":
				gesture.emit("add_powder", [held, 1.0])
		"crisol":
			gesture.emit("load_crucible", [])
		"tienda":
			gesture.emit("choose_stone", [""])
		"acrilico":
			gesture.emit("choose_stone", [State.ACRYLIC])
		"arrancar":
			gesture.emit("start", [])
		"sacar":
			gesture.emit("cool_piece", [])
		"ventana":
			gesture.emit("insert_charge", [])
		"cera":
			gesture.emit("lost_wax_next", [])
		"sierra":
			gesture.emit("set_carve_tool", ["sierra"])
			gesture.emit("carve_pass", [_shift])
		"muela":
			var cur := String(_v.get("tool", ""))
			gesture.emit("set_carve_tool", [cur if cur in ["muela_gruesa", "muela_fina"] else "muela_gruesa"])
			gesture.emit("carve_pass", [_shift])
		"fresa":
			gesture.emit("set_carve_tool", ["fresa"])
			gesture.emit("carve_pass", [_shift])
		"barrera":
			gesture.emit("protect", [])
		"pistola":
			gesture.emit("coat", [])
		"pulidora":
			gesture.emit("polish", [])
		"garra":
			gesture.emit("fit_test", [])
		"soldadura":
			# 5r · un clic en el aparato: las piezas a la mesa (o, con la costura acabada, otra vez)
			gesture.emit("weld_prepare", [])
