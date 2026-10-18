## Cetrería 3D (unidades 5b y 5c): el animal entero tumbado sobre el banco de un centro de cetrería (la rapaz) o sobre la
## mesa de quirófano de una clínica veterinaria (el tigre, el oso y el velocirraptor), con sus patas hacia el borde y la
## garra que se trabaja, y el carro con las herramientas, con la luz, el entorno y la cámara orbital de la afiladora del
## taller (sharpen3d). El sitio (care_room.gd) y el animal (care_animal.gd, el modelo 3D de la 4l) se construyen una vez
## por animal y calidad; la garra elegida (pata y dedo del estado) lleva la malla del perfil de ClawCare y las demás
## garras de las patas, la suya (la forma de partida o, si se han trabajado, la de ahora).
##
## La escena no calcula física: pinta la vista de ClawCareState (core/lab/claw_care_state.gd) que le pasa la página con
## show_view() — la garra con el perfil de ClawCare (sus mallas llegan hechas en arrays desde el hilo, claw_mesh.gd, y se
## rehacen solo cuando cambia su forma), las grietas, las escamas, la sangre, el calor (como una cámara térmica), el
## hemostático, la crema y la reconstrucción de metacrilato, la carne viva a trasluz solo donde se ve, el resaltado del
## tutorial (la zona, la flecha de la pasada y la guía del ángulo bueno) y los efectos (lo que sale de cada pasada: polvo de
## queratina, limaduras de metal, polvo de vidrio o de cerámica y virutas de acrílico, del color de su material; esquirlas,
## gotas y las chispas de los metales que las dan, las de core/taller/sparks.gd; unidad 5l) y cómo va cada herramienta (la
## lima embotada y la banda vidriada, de ClawCareKit).
##
## Mandos (la escena los convierte en gestos: señal gesture(op, args), que la página manda a su hilo):
##   izquierdo sobre la garra      con la herramienta en la mano: limar (arrastrar: la pasada, a la velocidad del
##                                 arrastre), tocar con el torno, cerrar el cortaúñas (mantener), apretar la gasa o el
##                                 hemostático, poner la crema…; sobre la bandeja: coger esa herramienta; sobre otra garra
##                                 del animal: trabajar esa; en el aire con el torno o la amoladora: su interruptor
##   Mayús + izquierdo (arrastre)  girar la herramienta: el ángulo de la pasada
##   derecho · central · rueda     girar la cámara · desplazarla · acercar; Mayús + rueda: la presión
##   un dedo · dos dedos           la herramienta · la cámara (girar y pellizcar)
##   la pieza de la reforja (5o)   apretar sobre ella en la bandeja y arrastrarla (ratón o dedo) hasta el muñón: quieta ahí
##                                 DOCK_HOLD_S, se coloca y queda sujeta mientras siga pulsado; al soltar, se suelta. Soltada
##                                 lejos, se queda en la mano, y un toque mantenido sobre el muñón la coloca y la sujeta
## Rendimiento: nada se crea en cada fotograma (se mueven transformaciones, parámetros de shader y los búferes de los
## MultiMesh); las mallas de la garra, solo con una forma nueva; la pata y las herramientas, al cambiar de animal.
## Unidades: la escena en metros; la garra, en mm dentro de su nodo (escala 0,001).
extends Node3D

signal gesture(op: String, args: Array)
## Unidad 5t-B: un efecto de sonido de la reacción del animal (la página lo toca por el bus «Lab»).
signal reaction_sfx(id: String, volume: float, pitch: float)

const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const CareAnimal = preload("res://app/lab/cetreria/care_animal.gd")
const CarePaw = preload("res://app/lab/cetreria/care_paw.gd")
const CareRoom = preload("res://app/lab/cetreria/care_room.gd")
const ClawLook = preload("res://app/lab/cetreria/claw_look.gd")
const CareTools = preload("res://app/lab/cetreria/care_tools.gd")
const CareOrbit = preload("res://app/lab/cetreria/care_orbit.gd")
const CareFx = preload("res://app/lab/cetreria/care_fx.gd")
const CareStage = preload("res://app/lab/cetreria/care_stage.gd")
const CareGauge = preload("res://app/lab/cetreria/care_gauge.gd")
const CareBond3D = preload("res://app/lab/cetreria/care_bond3d.gd")
const ReactionController = preload("res://app/lab/cetreria/reaction/reaction_controller.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const GHOST_SHADER = preload("res://app/lab/cetreria/claw_ghost.gdshader")
const State = preload("res://core/lab/claw_care_state.gd")
const Sparks = preload("res://core/taller/sparks.gd")
const SfxCare = preload("res://core/lab/sfx_care.gd")
const Palette = preload("res://app/theme/palette.gd")
const KERATIN_SHADER = preload("res://app/lab/cetreria/keratin.gdshader")
const ACRYLIC_SHADER = preload("res://app/lab/cetreria/acrylic.gdshader")
const SPARK_SHADER = preload("res://app/taller/radial3d/chispa.gdshader")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

const VIEWS := ["general", "garra", "seccion", "animal"]
const MM := 0.001
## Capa de la vista de sección (solo la ve su cámara).
const SECTION_LAYER := 3
## Separación de la herramienta cuando no aprieta (m) y suavizado del acercamiento (s).
const HOVER_M := 0.004
const POSE_TAU := 0.05
## Margen (px) para tocar la garra con el ratón o el dedo cuando el rayo pasa justo al lado, y su tope (mm: de lejos, no
## se toca la garra pinchando en el dedo).
const GRACE_PX := 8.0
const GRACE_MAX_MM := 2.0
## Transparencia de la herramienta de la mano sobre la garra (0 opaca, 1 invisible).
const TOOL_FADE := 0.55
## Arrastrar la pieza de la reforja hasta el muñón (unidad 5o, el gesto del teléfono): quieta (menos de DOCK_STILL_PX) sobre
## él durante DOCK_HOLD_S, se coloca y se empieza a sujetar. Elección de la interfaz.
const DOCK_HOLD_S := 0.35
const DOCK_STILL_PX := 6.0
## Las chispas salen de lo que arranca la herramienta giratoria (unidad 5l): la firma de sparks.gd que da el motor con lo que
## sale de cada pasada (ClawCare.debris_for → CareData.SPARK_MATERIAL: el acero, el titanio y el metal duro; el oro y los no
## metales, no). Duran SPARK_HOLD_S después de la última pasada que arranca.
const SPARK_HOLD_S := 0.3
## Rozamiento con el aire más alto con el que se dibuja el polvo fino de los frágiles (1/s): con él baja a g/k ≈ 0,16 m/s, una
## nube que se ve caer junto a la punta (el de Stokes, de micras, flotaría casi quieto). Dibujo.
const FINE_DUST_DRAG := 60.0
## Motas por segundo que echa una giratoria por la raíz cúbica de lo que arranca por segundo (mm³/s): dibujo, para que se vea
## a la vez lo poco y lo mucho (de ~0,005 a ~15 mm³/s, de ~20 a ~300 motas por segundo).
const ROT_DUST_PPS := 120.0
## Una limadura es una lámina unas 5 veces más larga que gruesa: cae ~10 veces antes que la esfera de su grueso (la resistencia
## de Stokes de una lámina va con su largo y el peso con largo² por grueso). Dibujo: el rozamiento de Stokes de la viruta
## (debris.dragPerS) se divide entre FLAKE_K.
const FLAKE_K := 10.0
## Exposición de la cámara para las estelas de las chispas y el desenfoque del tambor (s).
const EXPOSURE_S := 1.0 / 60.0
## Giro que se enseña del tambor: por encima de 2 vueltas/s, como en el estroboscopio del taller.
const STROBE_APPARENT_RPS := 0.35
## La vista de la garra (dibujo): la distancia de la cámara por mm del largo de la garra (con su mínimo, m) y el campo de
## visión (°).
const GARRA_DIST_K := 0.0038
const GARRA_DIST_MIN := 0.05
const GARRA_FOV := 30.0
## Lo que se enfoca de la garra (fracción del largo, desde la base): el perfil entero, con la punta donde se lima. Al coger
## una herramienta la cámara no se mueve (se va a apuntar a la garra: un blanco que se mueve estorba); con la rueda se
## acerca a la punta al milímetro.
const GARRA_FOCUS := 0.6
## (cierre de la 5s) Las garras pequeñas (las rapaces), más de cerca y con la punta más al centro, para que se vea la punta al
## empezar (roma · natural · afilada · aguja): [lo que se enfoca, fracción del largo; la distancia, × la de siempre]. Dibujo.
const GARRA_TIP_FRAMING := { "rapaz": [0.72, 0.8] }
## De dónde se mira cada garra (dibujo): [hacia la punta, hacia su cara de arriba, de lado] y lo mínimo que se levanta la
## cámara sobre el horizonte (°).
## El tigre, de lado (las otras garras van recogidas); el oso, desde delante y desde arriba (sus cinco garras cuelgan en
## fila y de lado se taparían).
const GARRA_DIR := { "rapaz": Vector3(0.22, 0.3, 0.93), "tigre": Vector3(0.25, 0.22, 0.94), "oso": Vector3(0.55, 0.55, 0.62),
	"velociraptor": Vector3(0.25, 0.3, 0.92) }
## (unidad 5s) Para que otras garras no tapen la que se trabaja: los puntos de su largo que se miran, las esferas por garra de
## las demás, cuánto más de frente es el lado alternativo y lo que cuesta cada lado de menos en el orden de preferencia (en
## puntos tapados; dibujo).
const OCCLUSION_SAMPLES := [0.3, 0.5, 0.7, 0.85, 0.97]
const OCCLUSION_STEPS := 8
const OCCLUSION_FRONT := 0.45
const OCCLUSION_ORDER := 0.15
## El grueso (m) del tablero de la mesa y del carro que se cuenta como lo que tapa (bajo su cara de arriba, a la altura 0).
const OCCLUSION_SLAB_M := 0.04
## Los giros (grados, en torno a la vertical) del lado preferido que se prueban si a los cuatro primeros los tapan.
const OCCLUSION_RING := [35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0]
## La vista del animal entero: la mitad de su largo (o de su alto) que llena la mitad de la vista, y el margen (m).
const ANIMAL_FIT := 0.52
const ANIMAL_MARGIN_M := 0.1
## En una vista estrecha (el teléfono), más holgado: de cerca, la perspectiva agranda lo que queda más cerca de la cámara
## (la grupa del oso se salía por la izquierda).
const ANIMAL_FIT_NARROW := 0.64
const GARRA_MIN_PITCH := { "rapaz": 12.0, "tigre": 10.0, "oso": 30.0, "velociraptor": 16.0 }
## Por debajo de esta altura (m sobre la mesa), la cámara de la garra no se mete en la mesa ni encima del carro.
const FURNITURE_CLEAR_M := 0.03
## Lo del estado en el sombreador de la garra (keratin.gdshader: el calor, el resaltado, las heridas, la superficie…): lo
## que se copia del estuche al bloque reforjado (el aspecto de cada uno es el de su material).
const STATE_UNIFORMS := ["apex_mm", "flat_r", "heat_tex", "heat_range", "heat_on", "hi_band", "hi_color", "hi_on", "time",
	"blood", "blood_from", "powder", "cream", "wet", "disinfected", "cracks", "crack_n", "peels", "peel_n", "sign_k",
	"surface_tex", "surface_range"]
## El trozo que se separa al cortar o mellar la garra (dibujo): lo mínimo que tiene que medir (mm), lo que tarda en
## soltarse y lo que dura en la escena (s), y lo que salta (m/s): despacio, para que se vea separarse de cerca antes de
## caer (con la cámara a unos centímetros, un salto de verdad saldría de la vista en un par de fotogramas).
const PIECE_MIN_MM := 0.25
const PIECE_HOLD_S := 0.2
const PIECE_LIFE_S := 3.5
const PIECE_KICK_MS := 0.06
## Lo más cerca que se acerca la cámara (m: a 8 mm, la vista abarca ~4 mm: la punta, al milímetro) y cuánto se va lo que
## se enfoca hacia el puntero en cada paso de la rueda.
const ZOOM_MIN_M := 0.008
const ZOOM_FOCUS_PULL := 0.35
## Colores de las zonas del tutorial.
const HINT_COLORS := { "sobrante": "gold", "banda": "rose", "carne_viva": "coral", "punta": "ice", "angulo": "gold",
	"base": "coral", "herida": "coral", "pasada": "mint", "garra": "mint", "bandeja": "mint" }
## Cuánto entra la base de la garra en el dedo, en radios de su base (dibujo).
const BASE_TUCK := 0.6
## Herramientas que se apoyan de punta (el cuerpo sale hacia fuera de la garra).
const POINT_TOOLS := ["nitrato_plata", "clorhexidina", "crema", "metacrilato"]
## La mesa acaba en TABLE_EDGE_X (m) y el carro del instrumental va de CART_X0 a CART_X1; las garras cuelgan por el
## borde (lo que baja a menos de EDGE_LOW de la mesa queda a EDGE_CLEAR del borde).
const TABLE_EDGE_X := 0.03
## (unidad 5h: el carro, algo más lejos de la mesa, para que la cámara de la garra que cuelga tenga sitio en el hueco)
const CART_X0 := 0.26
const CART_X1 := 1.02
const EDGE_LOW := 0.004
const EDGE_CLEAR := 0.006
## Las bandejas del carro: la de las herramientas y la batea de lo de curar (posición en m, giro sobre Y en rad, ancho y
## fondo).
const TOOL_TRAY := { "pos": Vector3(0.66, 0.0, -0.04), "yaw": -0.12, "w": 0.56, "d": 0.46 }
const CARE_TRAY := { "pos": Vector3(0.5, 0.0, 0.42), "yaw": 0.06, "w": 0.34, "d": 0.17 }
## La bandeja de la colocación de la pieza de la reforja (unidad 5o): el alcohol, la espátula y lo demás (CareBond3D).
const BOND_TRAY := { "pos": Vector3(0.85, 0.0, 0.40), "yaw": -0.04, "w": 0.28, "d": 0.22 }
## Sitio de cada herramienta: [id, bandeja, x y z locales (m), giro sobre Y (rad; 0: a lo largo de X local)]. Las limas,
## el torno (con su base de carga delante) y la amoladora, a lo largo del fondo con el mango hacia delante; los
## cortaúñas, delante; las tenazas, a la derecha.
const SLOTS := [
	["lima_bastarda", "herramientas", -0.25, -0.045, PI * 0.5], ["lima_fina", "herramientas", -0.21, -0.045, PI * 0.5],
	["lima_entrefina", "herramientas", -0.17, -0.045, PI * 0.5],
	["lima_diamante_gruesa", "herramientas", -0.13, -0.045, PI * 0.5],
	["lima_diamante_fina", "herramientas", -0.09, -0.045, PI * 0.5], ["lija_p180", "herramientas", -0.05, -0.045, PI * 0.5],
	["lija_p240", "herramientas", -0.015, -0.045, PI * 0.5], ["torno", "herramientas", 0.04, -0.03, PI * 0.5],
	["amoladora", "herramientas", 0.105, -0.05, PI * 0.5], ["tenaza", "herramientas", 0.205, 0.0, PI * 0.5],
	["guillotina", "herramientas", -0.2, 0.18, 0.0], ["tijera", "herramientas", -0.06, 0.18, 0.0],
	["agua", "cura", -0.12, 0.0, 0.0], ["presion", "cura", -0.05, -0.04, 0.0], ["hemostatico", "cura", -0.05, 0.04, 0.0],
	["nitrato_plata", "cura", 0.0, 0.0, -PI * 0.5], ["clorhexidina", "cura", 0.045, 0.0, -PI * 0.5],
	["crema", "cura", 0.09, 0.0, -PI * 0.5], ["metacrilato", "cura", 0.13, 0.0, -PI * 0.5],
	["alcohol", "colocar", 0.0, -0.035, -PI * 0.5], ["espatula", "colocar", 0.03, 0.035, -PI * 0.5],
]

@export var quality := ""
## La escena avanza sola en _process; la página lo apaga y llama a advance() desde su paso.
@export var auto_process := true
## El renderizador para la luz y los efectos («forward_plus», «mobile» o «gl_compatibility»); «» el del programa (los
## tests fijan el del escritorio para comprobar sus efectos).
@export var render_method := ""

var view_name := "garra"
var hand: Dictionary = {}
var _built := false
var _world: Node3D
var _rig: CareOrbit
var _stage: RefCounted
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _fill: DirectionalLight3D
var _overlay: CanvasLayer
var _vignette: TextureRect
## Dónde mira la cámara en la vista de la garra: s (mm desde la base) del punto que se enfoca; < 0, el de siempre (el
## 60 % del largo, o hacia la punta con una herramienta en la mano). La rueda sobre la garra lo lleva hacia el puntero.
var _focus_s := -1.0
## ¿Ha encuadrado ya la cámara una garra? (la primera vez, de golpe)
var _framed := false
## El indicador de la forma en directo (sobre la vista) y la silueta fantasma de la forma natural sana.
var _gauge: CareGauge
var _ghost_on := false
var _healthy: MeshInstance3D
var _healthy_mesh := ArrayMesh.new()
var _healthy_mat: ShaderMaterial
var _healthy_key := ""
## La superficie de la garra (ClawCare.snapshot().surface, de la 5g): una textura a lo largo de s para su material.
var _surface_img: Image
var _surface_tex: ImageTexture
var _surface_key := ""
## Las roturas del motor ya vistas (de qué garra y cuántas), y de dónde a dónde iba el último trozo (mm desde la base).
var _break_key := ""
var _breaks_seen := 0
var _piece_span := Vector2.ZERO
## El trozo de garra que se separa y cae al cortarla o al partirse: el perfil de antes del corte y el estado del trozo.
var _prev_prof: Dictionary = {}
var _cur_prof: Dictionary = {}
var _piece: MeshInstance3D
var _piece_mesh := ArrayMesh.new()
var _piece_st: Dictionary = {}
var _pieces := 0
var _paw: Dictionary = {}
var _paw_key := ""
## El sitio de trabajo (care_room.gd) y su clave (sitio, tamaño del tablero y calidad).
var _room: Dictionary = {}
var _room_key := ""
var _cart: MeshInstance3D
## La caché de los modelos de Animal3D (se hacen una vez por especie y calidad) y de las texturas del sitio.
var _animal_cache := {}
## La pata y la garra que se ven ahora en la malla de ClawCare.
var _slot_key := ""
var _slot_shapes := {}
var _claw: Node3D
var _sheath: MeshInstance3D
var _sheath_mesh := ArrayMesh.new()
var _sheath_mat: ShaderMaterial
## El bloque reforjado en bruto sobre el muñón (la 5g: claw.block): su malla y su material (el de la biblioteca, con lo
## del estado copiado del estuche).
var _block: MeshInstance3D
var _block_mesh := ArrayMesh.new()
var _block_mat: ShaderMaterial
var _quick: MeshInstance3D
var _quick_mesh := ArrayMesh.new()
var _quick_mat: StandardMaterial3D
var _bone: MeshInstance3D
var _bone_mesh := ArrayMesh.new()
var _ghost: MeshInstance3D
var _ghost_mesh := ArrayMesh.new()
var _ghost_mat: ShaderMaterial
## Las demás garras de las patas: "pata|dedo" → MeshInstance3D (con la forma de partida o su propia malla).
var _others := {}
var _other_mesh := ArrayMesh.new()
## Las demás garras de las patas: la misma queratina (o el mismo material reforjado) que la que se trabaja, sin el calor,
## las heridas ni el resaltado.
var _other_mat: ShaderMaterial
## (unidad 5s) Cada garra de las patas con su copia del material, para su tono de queratina (CarePaw.claw_tone): «pata|dedo» →
## ShaderMaterial. Se hacen al construir el animal; en cada fotograma no se crea nada.
var _other_mats := {}
## (unidad 5s) El largo de la forma que lleva cada garra de las patas (mm): la punta de su material.
var _slot_len := {}
var _mesh_key := ""
var _ghost_key := ""
## La sección de la garra (claw_mesh.gd: la de su animal o la medida del motor): la de las mallas y la del rayo.
var _shape: Dictionary = ClawMesh.ROUND
## Qué garras están fuera de su vaina (el tigre): la clave de lo último que se ha pedido.
var _present_key := ""
## La línea media de la forma de ahora (para el rayo del puntero), hecha una vez por vista.
var _mid_cache: Dictionary = {}
## Las bandas del corte de la última forma, por subir (solo se suben con la vista del corte).
var _sec_pending: Dictionary = {}
var _mesh_builds := 0
## Las mallas de partida de las garras sin tocar, cada una con la forma de su dedo (unidad 5s).
var _slot_builds := 0
var _k := 0.0
var _heat_img: Image
var _heat_tex: ImageTexture
var _heat_key := ""
var _tray: Node3D
var _dish: Node3D
## La colocación de la pieza de la reforja (unidad 5o): su bandeja, lo que hay en ella, la pieza y lo que rebosa.
var _bond_tray: Node3D
var _bond3d: CareBond3D
var _bond_holding := false
var _aim_sent := -1.0
var _dock_sent := false
## La pieza de la reforja arrastrada desde la bandeja con el botón o el dedo pulsados (unidad 5o): dónde se quedó quieto el
## puntero y desde cuándo (s de la escena), para colocarla al dejarla quieta sobre el muñón.
var _bond_dragging := false
var _drag_anchor := Vector2.ZERO
var _drag_still := 0.0
var _tools := {}
var _slots := {}
## Caja de cada herramienta de la bandeja en su propio marco (para cogerla con el rayo del puntero).
var _slot_boxes := {}
var _tool_faded := false
var _trial := ""
## Materiales de la herramienta de la mano mientras se transparenta (para devolvérselos) y el de cristal.
var _saved_mats := {}
var _glass_tool_mat: StandardMaterial3D
var _hit_key: Array = []
var _held := ""
var _v: Dictionary = {}
var _v_serial := -1
var _fx_seen := 0
var _look_key := ""
var _sedation := ""
var _moved_seen := 0
var _flinch := 0.0
var _t := 0.0
var _upd_n := 0
var _upd_sum := 0
var _upd_max := 0
# puntero
var _pointer := Vector2(-1.0, -1.0)
var _has_pointer := false
var _pressed := false
var _rotating := false
var _cam_drag := ""
var _touches := {}
var _pinch := 0.0
var _hit: Dictionary = {}
var _press_hit: Dictionary = {}
var _plane_n := Vector3.FORWARD
var _plane_p := Vector3.ZERO
var _plane_prev := Vector3.ZERO
var _acc_along := 0.0
var _acc_travel := 0.0
var _slide := 0.0
var _pose_xf := Transform3D.IDENTITY
var _pose_ready := false
# efectos
var _dust: CareFx
var _drops: CareFx
## Las limaduras de los metales (unidad 5l): astillas brillantes, aparte del polvo
var _filings: CareFx
var _filings_mmi: MultiMeshInstance3D
var _dust_mmi: MultiMeshInstance3D
var _drops_mmi: MultiMeshInstance3D
var _pool: MeshInstance3D
var _pool_r := 0.0
var _drip_acc := 0.0
var _emitter: Sparks
var _sparks_mmi: MultiMeshInstance3D
var _spark_key := ""
var _sparking := false
## La firma de chispas de lo que arranca la última pasada (la da el motor) y hasta cuándo (s de la escena)
var _spark_mat := ""
var _spark_until := -1.0
# lo que se arranca con la giratoria, a ritmo (_spawn_debris): cuándo fue el último trozo y la fracción de mota que sobra
var _dust_t := -1.0
var _dust_carry := 0.0
## Cómo van las herramientas de la bandeja (la clave de lo último pintado)
var _wear_key := ""
# resaltado
var _arrow: MeshInstance3D
var _guide: Node3D
var _guide_lo: MeshInstance3D
var _guide_hi: MeshInstance3D
var _guide_now: MeshInstance3D
var _guide_mat: StandardMaterial3D
var _arrow_key := ""
var _guide_key := ""
## La marca de la herramienta que sugiere el tutorial en la bandeja (petición 51): un cono dorado que baja y sube sobre ella.
var _suggest_mark: MeshInstance3D
var _suggest_id := ""
var _suggest_base := Vector3.ZERO
# sección
var _sec: Dictionary = {}
## Unidad 5t-B: la reacción del animal estresado (el plano del zarpazo) y la lente de la cámara.
var _reaction: ReactionController
## El reloj de la respiración del animal (más lento en la pausa para calmarlo: ReactionController.breath_rate()).
var _breath_t := 0.0


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
	_gauge.set_compact(is_mobile())
	_place_gauge.call_deferred()


func is_mobile() -> bool:
	return quality == "movil" or (quality == "" and OS.has_feature("mobile"))


## La vista del estado (ClawCareState.view() con las mallas del hilo). Barata si no ha cambiado.
func show_view(v: Dictionary) -> void:
	_ensure_built()
	if v.is_empty() or int(v.get("serial", -1)) == _v_serial and is_same(_v.get("mesh"), v.get("mesh")):
		return
	_v = v
	_v_serial = int(v.serial)
	hand = v.hand
	var setup: Dictionary = v.setup
	# un ensayo nuevo (otra garra): sin la sangre, el polvo ni las chispas del anterior
	var trial := String(setup.get("seed", ""))
	if trial != _trial:
		_trial = trial
		_pool_r = 0.0
		for fx: CareFx in [_dust, _drops, _filings]:
			if fx != null:
				fx.clear()
		_spark_until = -1.0
		if _emitter != null:
			_emitter.reset()
	var sn: Dictionary = v.snap
	# el animal se rehace (y se vuelve a poner al borde de la mesa) si cambia, si cambia su garra, su dibujo o el largo de
	# partida de las garras
	var pkey := "%s|%s|%s|%s|%s" % [String(setup.animal), String(setup.claw), str(is_mobile()), var_to_str(float(sn.claw.startMm)), String(v.get("model", ""))]
	if pkey != _paw_key:
		_build_paw(String(setup.animal), String(setup.claw), sn, String(v.get("model", "")))
		_paw_key = pkey
		_slot_key = ""
		_mesh_key = ""
		_ghost_key = ""
		_look_key = ""
	var skey := "%s|%s" % [String(v.get("paw", "")), String(v.get("digit", ""))]
	var reframe := skey != _slot_key
	if reframe:
		_attach_claw(String(v.get("paw", "")), String(v.get("digit", "")), sn)
		_slot_key = skey
		_mesh_key = ""
		# las roturas de antes de elegir esta garra ya no sueltan su trozo
		_break_piece(sn, false)
	var mesh: Dictionary = v.get("mesh", {})
	if not mesh.is_empty() and String(mesh.key) != _mesh_key:
		_apply_mesh(mesh)
	# (unidad 5s) las demás garras, antes de encuadrar: la vista mira cuáles se ven y cuáles tapan la elegida
	_apply_slots(v)
	if reframe:
		# la cámara va a la garra elegida: de golpe la primera vez; después, con una transición suave
		_apply_view(not _framed)
		_framed = true
	_apply_look(v)
	_apply_state(v)
	_apply_held(String(hand.tool))
	_apply_tool_wear(v)
	_apply_fx(v)
	_bond3d.apply(v, _claw, _k)
	# la bandeja de la colocación y lo suyo, solo con una pieza de la reforja que colocar (la que se tiene en la mano, siempre)
	var has_bond := not (v.get("bond", {}) as Dictionary).is_empty()
	for id: String in ["alcohol", "espatula"]:
		if _tools.has(id):
			(_tools[id].root as Node3D).visible = has_bond or _held == id
	_bond_tray.visible = has_bond
	_apply_suggest(v)
	# 5t-B: la reacción del animal y la lente puesta
	_reaction.show_view(v)


## «general» (la pata y la bandeja), «garra» (la garra de cerca, que la sigue) o «seccion» (el corte a lo largo de la
## garra a escala: estuche, carne viva y hueso).
func set_view(n: String, instant := false) -> void:
	var v := n.to_lower()
	if not VIEWS.has(v):
		push_warning("Vista desconocida: %s" % n)
		return
	view_name = v
	_ensure_built()
	_focus_s = -1.0
	_apply_view(instant)


## La silueta fantasma de la forma natural sana (la de la ficha del animal), para comparar con la de ahora: encendida o
## apagada (tecla F y el botón del indicador de la forma).
func set_ghost(on: bool) -> void:
	_ensure_built()
	_ghost_on = on
	_gauge.set_ghost(on)
	_healthy.visible = on and view_name != "seccion" and _healthy_mesh.get_surface_count() > 0


func toggle_ghost() -> void:
	set_ghost(not _ghost_on)


## Datos para la interfaz y los tests.
func info() -> Dictionary:
	return {
		"view": view_name, "held": _held, "mesh_builds": _mesh_builds, "slot_builds": _slot_builds, "frames": _upd_n,
		"update_ms_avg": float(_upd_sum) / float(maxi(_upd_n, 1)) / 1000.0, "update_ms_max": float(_upd_max) / 1000.0,
		"dust": _dust.count if _dust != null else 0, "drops": _drops.count if _drops != null else 0,
		"filings": _filings.count if _filings != null else 0, "spark_mat": _spark_mat, "wear_key": _wear_key,
		"sparks": _emitter.count() if _emitter != null else 0, "pressed": _pressed, "hit": not _hit.is_empty(),
		"hit_s": float(_hit.get("s", -1.0)), "quality": "movil" if is_mobile() else "escritorio", "animal": _paw.get("animal", ""),
		"pool_r_m": _pool_r, "venue": _room.get("venue", ""), "slot": _slot_key, "art": _paw.get("art", ""),
		"ghost": _healthy.visible, "pieces": _pieces, "piece_falling": bool(_piece_st.get("on", false)), "piece_span": _piece_span,
		"block": _block.visible,
		# la pieza de la reforja (unidad 5o): si se ve, si está acoplada al muñón y lo que rebosa
		"bond_piece": _bond3d.piece.visible if _bond3d != null else false, "bond_docked": _bond3d.docked if _bond3d != null else false,
		"bond_flash": _bond3d.flash.visible if _bond3d != null else false, "bond_dragging": _bond_dragging,
		"suggested": _suggest_id,
		"bond_holding": _bond_holding,
		"surface_px": _surface_img.get_width() if _surface_img != null else 0,
	}


## Punto de la pantalla (px del visor) de la pieza de la reforja que espera en la bandeja (unidad 5o; para la demo y los
## tests), o (−1, −1) si no hay.
func bond_piece_screen_point() -> Vector2:
	if _bond3d == null or not _bond3d.piece.visible:
		return Vector2(-1.0, -1.0)
	return _rig.camera().unproject_position(_bond3d.piece.global_transform * _bond3d.piece_mesh.get_aabb().get_center())


## Punto de la pantalla (px del visor) de un punto de la garra: s mm desde la base, en la vuelta a (0 arriba). Para la
## demo y los tests (que mueven el ratón como una persona).
func claw_screen_point(s_mm: float, a: float = 0.0, r_scale: float = 1.0) -> Vector2:
	var cam := _rig.camera()
	var mesh: Dictionary = _v.get("mesh", {})
	var ss: PackedFloat64Array = _v.snap.profile.s if not _v.is_empty() else PackedFloat64Array()
	var rs: PackedFloat64Array = _v.snap.profile.r if not _v.is_empty() else PackedFloat64Array()
	var r := ClawMesh.radius_at(ss, rs, s_mm) * r_scale
	var local := ClawMesh.surface_point(s_mm, r, float(mesh.get("k", _k)), a, _shape)
	return cam.unproject_position(_claw.global_transform * local)


## Punto de la pantalla de una herramienta de la bandeja (el centro de lo alto de su caja); (−1, −1) si queda detrás de
## la cámara.
func tray_screen_point(id: String) -> Vector2:
	if not _slot_boxes.has(id):
		return Vector2(-1.0, -1.0)
	var world: AABB = (_slots[id] as Transform3D) * (_slot_boxes[id] as AABB)
	var p := world.get_center() + Vector3(0.0, world.size.y * 0.5, 0.0)
	if _rig.camera().is_position_behind(p):
		return Vector2(-1.0, -1.0)
	return _rig.camera().unproject_position(p)


## La reacción del animal y su lente (unidad 5t-B), para la página, la demo y los tests.
func reaction() -> ReactionController:
	_ensure_built()
	return _reaction


## La cámara (para los tests).
func camera() -> Camera3D:
	return _rig.camera()


## Contadores para los tests: nodos del árbol de la escena.
func node_count() -> int:
	return _count(self)


static func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c


# ───────────────────────────── construcción ─────────────────────────────

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_environment()
	_world = Node3D.new()
	_world.name = "Mundo"
	add_child(_world)
	_build_table()
	_claw = Node3D.new()
	_claw.name = "Garra"
	_world.add_child(_claw)
	_sheath_mat = ShaderMaterial.new()
	_sheath_mat.shader = KERATIN_SHADER
	_sheath = _mesh_instance(_claw, _sheath_mesh, _sheath_mat, "Estuche")
	_block_mat = ShaderMaterial.new()
	_block_mat.shader = KERATIN_SHADER
	_block = _mesh_instance(_claw, _block_mesh, _block_mat, "BloqueEnBruto")
	_block.visible = false
	_quick_mat = StandardMaterial3D.new()
	_quick_mat.albedo_color = Color("#E0707A")
	_quick_mat.roughness = 0.45
	_quick_mat.emission_enabled = true
	_quick_mat.emission = Color("#7A1A22")
	_quick_mat.emission_energy_multiplier = 0.4
	_quick = _mesh_instance(_claw, _quick_mesh, _quick_mat, "CarneViva")
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color("#EDE3CC")
	bone_mat.roughness = 0.7
	_bone = _mesh_instance(_claw, _bone_mesh, bone_mat, "Hueso")
	_bone.visible = false
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = ACRYLIC_SHADER
	_ghost = _mesh_instance(_claw, _ghost_mesh, _ghost_mat, "Metacrilato")
	_ghost.visible = false
	_other_mat = ShaderMaterial.new()
	_other_mat.shader = KERATIN_SHADER
	_heat_img = Image.create(64, 1, false, Image.FORMAT_RF)
	_heat_img.fill(Color(0, 0, 0))
	_heat_tex = ImageTexture.create_from_image(_heat_img)
	_sheath_mat.set_shader_parameter("heat_tex", _heat_tex)
	_healthy_mat = ShaderMaterial.new()
	_healthy_mat.shader = GHOST_SHADER
	_healthy_mat.set_shader_parameter("color", Palette.color("mint"))
	# la última de lo translúcido: la queratina oscura (opacidad 0,97) también lo es y, según cómo queden las dos al
	# ordenarse por distancia (cambia al limar), la tapaba
	_healthy_mat.render_priority = Material.RENDER_PRIORITY_MAX
	_healthy = _mesh_instance(_claw, _healthy_mesh, _healthy_mat, "FormaSana")
	_healthy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_healthy.visible = false
	_surface_img = ClawMaterial.surface_image([])
	_surface_tex = ImageTexture.create_from_image(_surface_img)
	ClawMaterial.clear_surface(_sheath_mat)
	_piece = _mesh_instance(_world, _piece_mesh, _other_mat, "Trozo")
	_piece.visible = false
	for mi: MeshInstance3D in [_sheath, _block, _quick, _bone, _ghost, _piece]:
		_focus_layer_on(mi)
	_gauge = CareGauge.new()
	_overlay.add_child(_gauge)
	# la página pone la calidad antes de añadir la escena (sin set_quality): el teléfono, compacto desde el principio
	_gauge.set_compact(is_mobile())
	_place_gauge()
	_gauge.ghost_toggled.connect(set_ghost)
	_build_tray()
	_bond3d = CareBond3D.new()
	_bond3d.build(_world, _bond_tray, is_mobile())
	_build_fx()
	_build_hints()
	_build_section()
	_rig = CareOrbit.new()
	add_child(_rig)
	_rig.min_distance = ZOOM_MIN_M
	_rig.camera().current = true
	# 5t-B: la reacción del animal y la lente (sus rayones van al estado como la orden lens_record)
	_reaction = ReactionController.new()
	add_child(_reaction)
	_reaction.set_camera(_rig.camera())
	_reaction.caption_avoid = _gauge  # el rótulo de la cámara lenta, sin tapar el medidor
	_reaction.lens_record.connect(func(seq: int, traces: Dictionary) -> void: gesture.emit("lens_record", [seq, traces]))
	_reaction.sfx.connect(func(id: String, vol: float, pitch: float) -> void: reaction_sfx.emit(id, vol, pitch))
	_apply_quality()


func _mesh_instance(parent: Node, mesh: Mesh, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Pone en la capa de lo que se enfoca (la de la luz de tres puntos, CareStage.FOCUS_LAYER) todo lo que se dibuja bajo
## root: la garra, el animal y las herramientas. Una vez, al construirlo.
static func _focus_layer_on(root: Node) -> void:
	var bit := 1 << (CareStage.FOCUS_LAYER - 1)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers |= bit
		stack.append_array(n.get_children())


## La luz y la profundidad (care_stage.gd): el entorno de la sala, el sol de la ventana con las sombras y la luz de tres
## puntos de la garra, con los efectos de cada renderizador; encima de la vista, el viñeteado.
func _build_environment() -> void:
	_stage = CareStage.build(self, _render_method(), is_mobile())
	_sun = _stage.get("sun")
	_fill = _stage.get("fill")
	_sky_mat = _stage.get("sky_mat")
	_overlay = CanvasLayer.new()
	_overlay.name = "SobreLaVista"
	# 5t-B: por encima de la lente (capa 1): el indicador de la forma no se ve a través de los rayones
	_overlay.layer = 2
	add_child(_overlay)
	_vignette = TextureRect.new()
	_vignette.name = "Vineteado"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_vignette)
	_apply_vignette()


## El renderizador de la escena: el del programa, o el que fija un test (render_method).
func _render_method() -> String:
	return render_method if render_method != "" else CareStage.current_method()


## El viñeteado: un degradado radial oscuro en los bordes de la vista (el sustituto barato de la profundidad de campo;
## más fuerte en Mobile y Compatibility).
func _apply_vignette() -> void:
	var k := float(_stage.get("settings").get("vignette", 0.0))
	_vignette.visible = k > 0.0
	if not _vignette.visible:
		return
	var g := Gradient.new()
	var edge := Color(0.03, 0.015, 0.04, k)
	g.colors = PackedColorArray([Color(edge, 0.0), Color(edge, 0.0), Color(edge, k * 0.45), edge])
	g.offsets = PackedFloat32Array([0.0, 0.52, 0.8, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 128
	tex.height = 128
	_vignette.texture = tex


## El carro del instrumental, pasado un hueco desde el borde de la mesa (de acero en la clínica, de madera en el centro de
## cetrería: su material lo pone el sitio).
func _build_table() -> void:
	var cart := BoxMesh.new()
	cart.size = Vector3(CART_X1 - CART_X0, 0.03, 0.9)
	_cart = _mesh_instance(_world, cart, _steel_mat(), "Carro")
	_cart.position = Vector3(0.5 * (CART_X0 + CART_X1), -0.015, 0.12)
	var legs := CylinderMesh.new()
	legs.top_radius = 0.012
	legs.bottom_radius = 0.012
	legs.height = CareRoom.TABLE_H - 0.03
	var leg_mat := _steel_mat()
	for lx: float in [CART_X0 + 0.04, CART_X1 - 0.04]:
		for lz: float in [-0.29, 0.53]:
			var leg := _mesh_instance(_world, legs, leg_mat, "PataDelCarro")
			leg.position = Vector3(lx, -CareRoom.TABLE_H * 0.5 - 0.015, lz)


func _steel_mat() -> StandardMaterial3D:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#B9C0C6")
	steel.metallic = 0.75
	steel.roughness = 0.32
	return steel


## El animal entero (care_animal.gd): se rehace al cambiar de animal, de garra del banco o de dibujo, y se pone al borde
## de la mesa; después, el sitio de trabajo a su medida (care_room.gd: el banco de cetrería de la rapaz o la mesa de la
## clínica de los grandes).
func _build_paw(animal: String, claw_id: String, sn: Dictionary, model := "") -> void:
	if not _paw.is_empty():
		var old: Node3D = _paw.root
		if _claw.get_parent() != null:
			_claw.get_parent().remove_child(_claw)
		old.get_parent().remove_child(old)
		old.queue_free()
	_others.clear()
	_other_mats.clear()
	_slot_len.clear()
	_slot_shapes.clear()
	_present_key = ""
	if _claw.get_parent() != null:
		_claw.get_parent().remove_child(_claw)
	_world.add_child(_claw)
	var claw := { "base_r_mm": float(sn.claw.baseRadiusMm), "length_mm": float(sn.claw.naturalMm), "curve": float(sn.claw.curve) }
	_paw = CareAnimal.build(_world, animal, claw_id, { "mobile": is_mobile(), "cache": _animal_cache, "model": model, "claw": claw,
		"claw_mat": _other_mat })
	var base_r_mm := float(sn.claw.baseRadiusMm)
	# las garras que se trabajan: la del modelo, escondida; aquí, la del perfil de ClawCare (la de partida)
	for key: String in _paw.slots:
		var e: Dictionary = _paw.slots[key]
		var om := _other_mat.duplicate() as ShaderMaterial
		_other_mats[key] = om
		var mi := _mesh_instance(e.node as Node3D, _other_mesh, om, "Garra_" + key.replace("|", "_"))
		mi.transform = _slot_xf(e, base_r_mm)
		_others[key] = mi
	_focus_layer_on(_paw.root as Node)
	_place_paw(sn)
	_build_room(animal)
	_sedation = ""
	_moved_seen = 0
	if _reaction != null:
		_reaction.bind(_paw)


## El marco de la garra de ClawCare en el nodo de la base de la garra del modelo: en mm, y con la base algo metida en el
## dedo (el pliegue de piel que la cubre; dibujo).
static func _slot_xf(e: Dictionary, base_r_mm: float) -> Transform3D:
	return (e.xf as Transform3D).scaled_local(Vector3.ONE * float(e.mm_scale)).translated_local(Vector3(-BASE_TUCK * base_r_mm, 0.0, 0.0))


## Cuelga la garra de ClawCare de la pata y el dedo elegidos (y devuelve la otra garra que había ahí a su sitio).
func _attach_claw(paw: String, digit: String, sn: Dictionary) -> void:
	var key := "%s|%s" % [paw, digit]
	for k: String in _others:
		(_others[k] as MeshInstance3D).visible = k != key
	if not (_paw.get("slots", {}) as Dictionary).has(key):
		return
	var e: Dictionary = _paw.slots[key]
	if _claw.get_parent() != null:
		_claw.get_parent().remove_child(_claw)
	(e.node as Node3D).add_child(_claw)
	_claw.transform = _slot_xf(e, float(sn.claw.baseRadiusMm))
	_pose_ready = false


## Pone el animal al borde de la mesa: lo que de las garras de las patas (con su largo de partida) baja hasta la mesa cuelga
## libre por el borde, como cuando se presenta la pata para cortarlas, y la tela de debajo acaba en el borde.
func _place_paw(sn: Dictionary) -> void:
	var k := ClawMesh.claw_curvature(sn.claw)
	var ss: PackedFloat64Array = sn.profile.s
	var rs: PackedFloat64Array = sn.profile.r
	var root: Node3D = _paw.root
	var frames: Array = []
	for key: String in _others:
		frames.append(CareAnimal.rel_xf(_others[key] as MeshInstance3D, root))
	var dx := 0.0
	var found := false
	for xf: Transform3D in frames:
		var sc := xf.basis.get_scale().x
		for i in mini(ss.size(), rs.size()):
			var p := xf * ClawMesh.point_at(ss[i], k)
			if p.y - rs[i] * sc < EDGE_LOW:
				var need := TABLE_EDGE_X + EDGE_CLEAR + rs[i] * sc - p.x
				dx = need if not found else maxf(dx, need)
				found = true
	_paw["offset"] = Vector3(dx, 0.0, 0.0)
	root.position = _paw.offset
	# la tela de debajo acaba en el borde
	var under: MeshInstance3D = _paw.get("under")
	if under != null and under.mesh is PlaneMesh:
		var pm := under.mesh as PlaneMesh
		var x0 := under.position.x - pm.size.x * 0.5
		var x1 := minf(under.position.x + pm.size.x * 0.5, TABLE_EDGE_X - dx - 0.002)
		under.visible = x1 > x0 + 0.01
		if under.visible:
			pm.size = Vector2(x1 - x0, pm.size.y)
			under.position.x = 0.5 * (x0 + x1)


## El sitio de trabajo a la medida del animal (se rehace solo si cambia el sitio, el tamaño del tablero o la calidad).
func _build_room(animal: String) -> void:
	var venue := "cetreria" if animal == "rapaz" else "clinica"
	var box: AABB = _paw.box
	var off: Vector3 = _paw.offset
	var x0 := minf(box.position.x + off.x - 0.12, TABLE_EDGE_X - 0.6)
	var z0 := minf(box.position.z - 0.15, -0.45)
	var z1 := maxf(box.end.z + 0.15, 0.6)
	var key := "%s|%s|%s|%s|%s" % [venue, snappedf(x0, 0.05), snappedf(z0, 0.05), snappedf(z1, 0.05), str(is_mobile())]
	if key == _room_key:
		return
	_room_key = key
	if not _room.is_empty():
		var old: Node3D = _room.root
		old.get_parent().remove_child(old)
		old.queue_free()
	_room = CareRoom.build(_world, venue, TABLE_EDGE_X, snappedf(x0, 0.05), snappedf(z0, 0.05), snappedf(z1, 0.05), is_mobile(), _animal_cache)
	if _cart != null:
		var m := _cart.material_override as StandardMaterial3D
		m.albedo_color = Color("#B9C0C6") if venue == "clinica" else Color("#8A6A48")
		m.metallic = 0.75 if venue == "clinica" else 0.0
		m.roughness = 0.32 if venue == "clinica" else 0.7
	_apply_venue_light(venue)


## Las dos bandejas del carro, a escala real (cada herramienta descansa tal como se coge): la de acero con las limas, el
## torno, los cortaúñas y las tenazas, al fondo, y delante una batea con lo de curar.
func _build_tray() -> void:
	_tray = CareTools.tray(_world, float(TOOL_TRAY.w), float(TOOL_TRAY.d))
	_tray.transform = Transform3D(Basis(Vector3.UP, float(TOOL_TRAY.yaw)), TOOL_TRAY.pos)
	_dish = CareTools.tray(_world, float(CARE_TRAY.w), float(CARE_TRAY.d))
	_dish.transform = Transform3D(Basis(Vector3.UP, float(CARE_TRAY.yaw)), CARE_TRAY.pos)
	_bond_tray = CareTools.tray(_world, float(BOND_TRAY.w), float(BOND_TRAY.d))
	_bond_tray.name = "BandejaDeLaColocacion"
	_bond_tray.transform = Transform3D(Basis(Vector3.UP, float(BOND_TRAY.yaw)), BOND_TRAY.pos)
	var ids: Array = State.TRAY.map(func(t: Dictionary) -> String: return String(t.id))
	for slot: Array in SLOTS:
		var id := String(slot[0])
		if not ids.has(id):
			continue
		var t := CareTools.build(_world, id, is_mobile())
		t["meshes"] = _meshes_of(t.root as Node3D)
		# lo que se transparenta sobre la garra: todo menos el tambor y el protector (se tienen que ver girar y trabajar)
		var keep: Array = []
		for k: String in ["drum", "guard"]:
			if t.get(k) != null:
				keep.append_array(_meshes_of(t[k] as Node3D))
		t["fade_meshes"] = (t.meshes as Array).filter(func(mi: MeshInstance3D) -> bool: return not keep.has(mi))
		_tools[id] = t
		_focus_layer_on(t.root as Node)
		var holder: Node3D = _tray if String(slot[1]) == "herramientas" else (_bond_tray if String(slot[1]) == "colocar" else _dish)
		var rot := _rest_basis(id, float(slot[4]))
		var box := _tool_aabb(t.root as Node3D)
		# tumbada sobre el fondo de la bandeja y con el centro de su caja en el sitio
		var rb := Transform3D(rot, Vector3.ZERO) * box
		var at := Vector3(float(slot[2]), 0.0025 - rb.position.y, float(slot[3])) - Vector3(rb.get_center().x, 0.0, rb.get_center().z)
		var xf := holder.transform * Transform3D(rot, at)
		_slots[id] = xf
		_slot_boxes[id] = box
		(t.root as Node3D).transform = xf
	# la base de carga del torno, delante de él en la bandeja (se queda ahí al cogerlo)
	if not is_mobile():
		var base := CareTools.charger(_tray)
		base.position = Vector3(0.04, 0.0025, 0.13)


## Cómo descansa cada herramienta: tumbada con la cara que corta hacia arriba, girada yaw sobre la vertical; los
## cortaúñas y las tenazas, de canto sobre la bandeja; el cuenco y el bote, de pie.
static func _rest_basis(id: String, yaw: float) -> Basis:
	var b := Basis.IDENTITY
	if id in ["guillotina", "tijera", "tenaza"]:
		b = Basis(Vector3.RIGHT, PI * 0.5)
	return Basis(Vector3.UP, yaw) * b


## Las mallas de una herramienta (para transparentarla sobre la garra).
static func _meshes_of(root: Node3D) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out


## Transparenta (o no) la herramienta de la mano: sobre la garra, para que se vea lo que lima. Cambia el material de
## cada malla por uno de cristal (las de sombreador propio no se transparentan solas) y luego se lo devuelve.
func _fade_tool(id: String, on: bool) -> void:
	if not _tools.has(id):
		return
	if _glass_tool_mat == null:
		_glass_tool_mat = StandardMaterial3D.new()
		_glass_tool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_tool_mat.albedo_color = Color(0.86, 0.9, 0.95, 1.0 - TOOL_FADE)
		_glass_tool_mat.roughness = 0.35
		_glass_tool_mat.metallic = 0.3
	for mi: MeshInstance3D in _tools[id].fade_meshes:
		if on:
			if not _saved_mats.has(mi):
				_saved_mats[mi] = mi.material_override
			mi.material_override = _glass_tool_mat
		elif _saved_mats.has(mi):
			mi.material_override = _saved_mats[mi]
			_saved_mats.erase(mi)


## Caja (en el marco de la herramienta) de todas sus mallas.
static func _tool_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			if not (c is Node3D):
				continue
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var bb := cx * (c as MeshInstance3D).get_aabb()
				out = bb if first else out.merge(bb)
				first = false
			stack.append([c, cx])
	return out



func _build_fx() -> void:
	_dust = CareFx.new(320, "cetreria-polvo")
	_drops = CareFx.new(64, "cetreria-gotas")
	_drops.drag = 0.6
	_filings = CareFx.new(160, "cetreria-limaduras")
	# las limaduras pesan más que el polvo: frenan menos en el aire (dibujo)
	_filings.drag = 1.6
	# entre la mesa y el carro no hay nada: lo que cae por el borde sigue hasta el suelo
	for fx: CareFx in [_dust, _drops, _filings]:
		fx.gap_x = Vector2(TABLE_EDGE_X, CART_X0)
	_dust_mmi = _multimesh("Polvo", 320, _flake_mesh(), _particle_mat())
	_filings_mmi = _multimesh("Limaduras", 160, _sliver_mesh(), _filing_mat())
	_drops_mmi = _multimesh("Gotas", 64, _drop_mesh(), _blood_mat())
	var pool := CylinderMesh.new()
	pool.top_radius = 1.0
	pool.bottom_radius = 1.0
	pool.height = 0.0005
	pool.radial_segments = 28
	_pool = _mesh_instance(_world, pool, _blood_mat(), "Charco")
	_pool.visible = false
	_emitter = Sparks.new("cetreria-chispas")
	_emitter.set_exposure(EXPOSURE_S)
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, -0.5, 0), Vector3(1.0, -0.5, 0), Vector3(1.0, 0.5, 0), Vector3(0, 0.5, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sm := ShaderMaterial.new()
	sm.shader = SPARK_SHADER
	quad.surface_set_material(0, sm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = Sparks.MAX_SPARKS
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	_sparks_mmi = MultiMeshInstance3D.new()
	_sparks_mmi.name = "Chispas"
	_sparks_mmi.multimesh = mm
	_sparks_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks_mmi)


func _multimesh(n: String, cap: int, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _flake_mesh() -> ArrayMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.7)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, q.get_mesh_arrays())
	return m


## Una limadura (dibujo): una astilla fina y alargada.
func _sliver_mesh() -> ArrayMesh:
	var b := BoxMesh.new()
	b.size = Vector3(1.0, 0.22, 0.12)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.get_mesh_arrays())
	return m


## Las limaduras brillan como su metal: el color de cada una, metálico y pulido.
func _filing_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# metálicas, pero que se vea su color (con 0,9 reflejaban el techo oscuro y se perdían)
	m.metallic = 0.6
	m.roughness = 0.3
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _drop_mesh() -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.2
	s.radial_segments = 8
	s.rings = 4
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s.get_mesh_arrays())
	return m


func _particle_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _blood_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#7A0A12")
	m.roughness = 0.08
	m.metallic_specular = 0.8
	m.vertex_color_use_as_albedo = false
	return m


## La flecha de la pasada (de la base a la punta) y la guía del ángulo bueno de la faceta.
func _build_hints() -> void:
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(Palette.color("mint"), 0.75)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.no_depth_test = true
	_arrow = _mesh_instance(_claw, ArrayMesh.new(), am, "FlechaDeLaPasada")
	_arrow.visible = false
	_guide = Node3D.new()
	_guide.name = "GuiaDelAngulo"
	_claw.add_child(_guide)
	_guide_mat = StandardMaterial3D.new()
	_guide_mat.albedo_color = Color(Palette.color("gold"), 0.3)
	_guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_guide_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_guide_mat.no_depth_test = true
	var line_mat := _guide_mat.duplicate() as StandardMaterial3D
	line_mat.albedo_color = Color(Palette.color("gold"), 0.9)
	var now_mat := _guide_mat.duplicate() as StandardMaterial3D
	now_mat.albedo_color = Color(Palette.color("ice"), 0.95)
	_guide_lo = _mesh_instance(_guide, ArrayMesh.new(), line_mat, "Menor")
	_guide_hi = _mesh_instance(_guide, ArrayMesh.new(), line_mat, "Mayor")
	_guide_now = _mesh_instance(_guide, ArrayMesh.new(), now_mat, "Ahora")
	_guide.visible = false
	# la herramienta que sugiere el tutorial, señalada en la bandeja (dibujo)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.009
	cone.bottom_radius = 0.0
	cone.height = 0.022
	cone.radial_segments = 12
	cone.rings = 1
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Palette.color("gold")
	cm.no_depth_test = true
	cm.render_priority = Material.RENDER_PRIORITY_MAX
	_suggest_mark = _mesh_instance(_world, cone, cm, "Sugerida")
	_suggest_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_suggest_mark.visible = false


## La vista de sección: las bandas del corte (estuche, carne viva, hueso), un fondo y rótulos; solo en SECTION_LAYER.
func _build_section() -> void:
	var bit := 1 << (SECTION_LAYER - 1)
	var root := Node3D.new()
	root.name = "Seccion"
	_claw.add_child(root)
	var mats := {}
	for layer: Array in [["sheath", "#8A6E52"], ["quick", "#E0707A"], ["bone", "#EDE3CC"]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(String(layer[1]))
		mats[layer[0]] = m
	var bands := {}
	for key: String in ["sheath", "quick", "bone"]:
		var mi := _mesh_instance(root, ArrayMesh.new(), mats[key], "Corte_" + key)
		mi.layers = bit
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bands[key] = mi
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Palette.color("bg2")
	var bg := _mesh_instance(root, QuadMesh.new(), bg_mat, "Fondo")
	bg.layers = bit
	var labels := {}
	for k: String in ["sheath", "quick", "bone", "band", "scale"]:
		var l := Label3D.new()
		l.name = "Rotulo_" + k
		l.font = FONT
		l.font_size = 48
		l.outline_size = 10
		l.outline_modulate = Color(0.09, 0.05, 0.11, 0.9)
		l.no_depth_test = true
		l.layers = bit
		l.modulate = Palette.color("text")
		root.add_child(l)
		labels[k] = l
	var bar := _mesh_instance(root, BoxMesh.new(), mats["bone"], "Escala")
	bar.layers = bit
	# la franja donde acaba la carne viva en la población (garras oscuras, antes de terminar)
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	band_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	band_mat.albedo_color = Color(Palette.color("rose"), 0.45)
	var band := _mesh_instance(root, ArrayMesh.new(), band_mat, "Franja")
	band.layers = bit
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sec = { "root": root, "bands": bands, "bg": bg, "labels": labels, "bar": bar, "mats": mats, "band": band, "band_key": "" }
	root.visible = false


# ───────────────────────────── la vista del estado ─────────────────────────────

func _apply_mesh(mesh: Dictionary) -> void:
	_mesh_key = String(mesh.key)
	_k = float(mesh.k)
	_shape = mesh.get("shape", ClawMesh.ROUND)
	# el perfil de antes (para el trozo que se separa si esta forma nueva sale de un corte)
	_prev_prof = _cur_prof
	_cur_prof = { "prof": mesh.get("profile", {}), "k": _k, "apex": float(mesh.get("apex", 0.0)), "slot": _slot_key }
	var hk := "%s|%s|%s" % [_paw_key, _slot_key, str(mesh.ring)]
	if hk != _healthy_key and mesh.has("healthy"):
		_healthy_key = hk
		_set_surface(_healthy_mesh, mesh.healthy)
		var hp: Dictionary = mesh.get("healthy_profile", {})
		var hs: PackedFloat64Array = hp.get("s", PackedFloat64Array())
		_healthy_mat.set_shader_parameter("apex_mm", hs[hs.size() - 1] if hs.size() > 0 else 0.0)
		# lo que queda dentro del dedo (la base metida en el pliegue de piel) no se dibuja
		_healthy_mat.set_shader_parameter("from_mm", BASE_TUCK * float(_v.snap.claw.baseRadiusMm) * 1.6 if not _v.is_empty() else 0.0)
		_healthy.visible = _ghost_on and view_name != "seccion"
	_mesh_builds += 1
	_set_surface(_sheath_mesh, mesh.sheath)
	_set_surface(_block_mesh, mesh.get("block", []))
	_block.visible = _block_mesh.get_surface_count() > 0
	_set_surface(_quick_mesh, mesh.quick)
	_set_surface(_bone_mesh, mesh.bone)
	# las bandas del corte, solo si se ve el corte (si no, al entrar en él)
	_sec_pending = mesh.section
	if view_name == "seccion":
		_upload_section_bands()
	var gk := "%s|%s" % [_paw_key, str(mesh.ring)]
	if gk != _ghost_key and mesh.has("ghost"):
		_ghost_key = gk
		_set_surface(_ghost_mesh, mesh.ghost)
		_set_surface(_other_mesh, mesh.ghost)


func _upload_section_bands() -> void:
	if _sec_pending.is_empty():
		return
	for key: String in ["sheath", "quick", "bone"]:
		var mi: MeshInstance3D = _sec.bands[key]
		_set_surface(mi.mesh as ArrayMesh, _sec_pending.get(key, []))
	_sec_pending = {}


## Las demás garras de las patas: la forma de partida o, si se han trabajado, su malla (del hilo del estado); las del
## tigre que no se trabajan, recogidas (el tigre retrae las garras: solo asoman al apretar el dedo).
func _apply_slots(v: Dictionary) -> void:
	var om: Dictionary = v.get("others_mesh", {})
	var tiger := String(v.setup.animal) == "tigre"
	# el tigre saca de su vaina la garra que se trabaja (y deja fuera las ya trabajadas, para ver su forma)
	var sel := "%s|%s" % [String(v.get("paw", "")), String(v.get("digit", ""))]
	var worked: Array = []
	for e: Dictionary in v.get("slots", []):
		if bool(e.worked):
			worked.append(String(e.key))
	var pkey := "%s|%s" % [sel, ",".join(PackedStringArray(worked))]
	if pkey != _present_key:
		CareAnimal.present(_paw, sel, worked, _present_key == "")
		_present_key = pkey
	for e: Dictionary in v.get("slots", []):
		var key := String(e.key)
		var mi: MeshInstance3D = _others.get(key)
		if mi == null:
			continue
		mi.visible = not bool(e.selected) and (bool(e.worked) or not tiger)
		if om.has(key):
			var gk := String(om[key].key)
			var have: Dictionary = _slot_shapes.get(key, {})
			if String(have.get("key", "")) != gk:
				var am := ArrayMesh.new()
				_set_surface(am, om[key].arrays)
				_slot_shapes[key] = { "key": gk, "mesh": am }
				# (unidad 5s) las de partida de las garras sin tocar se hacen una vez al cargar: no son formas nuevas
				if bool(e.worked):
					_mesh_builds += 1
				else:
					_slot_builds += 1
			mi.mesh = (_slot_shapes[key] as Dictionary).mesh
			var ln := float(om[key].get("lengthMm", -1.0))
			if ln > 0.0 and absf(float(_slot_len.get(key, -1.0)) - ln) > 1e-6:
				_slot_len[key] = ln
				if _other_mats.has(key):
					(_other_mats[key] as ShaderMaterial).set_shader_parameter("apex_mm", ln)
		elif mi.mesh != _other_mesh:
			mi.mesh = _other_mesh


static func _set_surface(m: ArrayMesh, arrays: Variant) -> void:
	m.clear_surfaces()
	if arrays is Array and ClawMesh.has_triangles(arrays):
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## El bloque reforjado lleva lo mismo del estado que el estuche (el calor, la sangre, la superficie…), con su material.
func _mirror_block_state() -> void:
	if not _block.visible:
		return
	for u: String in STATE_UNIFORMS:
		_block_mat.set_shader_parameter(u, _sheath_mat.get_shader_parameter(u))


## El aspecto de la garra (queratina de su color, o el material reforjado): solo al cambiar de garra, de material o si
## se revela la carne viva.
func _apply_look(v: Dictionary) -> void:
	var sn: Dictionary = v.snap
	var inlay := String(sn.inlay)
	var revealed := bool(v.hints.revealed)
	var q := "movil" if is_mobile() else "escritorio"
	var block: Variant = sn.claw.get("block")
	var bm := String((block as Dictionary).get("material", "")) if block is Dictionary else ""
	# con sonda de reflexión en la sala (Forward+), los metales no suman dos veces la sala (claw_look.gd, unidad 5q)
	var probe := _stage != null and bool((_stage.get("settings") as Dictionary).get("probe", false))
	# las demás garras y las del modelo: el material del animal (el de los ajustes), no el de la funda pegada a esta garra
	# (unidad 5o: una funda de acero en un dedo no vuelve de acero los demás)
	var other_inlay := String((v.get("setup", {}) as Dictionary).get("inlay", inlay))
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [String(sn.claw_id), inlay, str(revealed), str(bool(sn.claw.quickVisible)), str(bool(v.finished)), q, bm, str(probe), _slot_key, other_inlay]
	if key == _look_key:
		return
	_look_key = key
	# el bloque en bruto, con el aspecto de su material (sin tallar: el acabado en bruto lo pone la superficie del motor)
	if bm != "":
		ClawLook.apply(_block_mat, ClawLook.params(bm, Color(String((block as Dictionary).get("color", "#C7CDD6"))), { "quality": q, "probe": probe }))
	# el aspecto de cada material, en un solo sitio (claw_look.gd): la garra que se trabaja, las demás de las patas y las
	# del modelo 3D
	var col := Color(String(sn.claw.color))
	var light := bool(sn.claw.quickVisible) and not bool(v.reforged)
	# (unidad 5s) la queratina de cada garra, con su tono (CarePaw.claw_tone; dibujo): la que se trabaja, también
	var art := String(_paw.get("art", ""))
	var sel_key := "%s|%s" % [String(v.get("paw", "")), String(v.get("digit", ""))]
	var sheath_col := CarePaw.claw_tone(col, art, sel_key) if inlay == "none" else col
	var len_mm := float(sn.claw.startMm)  # las facetas de una talla, como mucho de ClawLook.FACET_MAX_MM (la hoz del velocirraptor)
	var sheath_finish := { "light": light, "finished": bool(v.finished), "quality": q, "probe": probe, "length_mm": len_mm }
	# la hoz del velocirraptor, comprimida de lado (18,7 × 7,1 mm): una gema absorbe a lo largo de su ancho (claw_look.gd);
	# las demás, 1 (lo de siempre; se pone siempre para que no se quede el de la hoz al cambiar de animal)
	var raptor := String(_paw.get("animal", "")) == "velociraptor"
	sheath_finish["section_k"] = float(sn.claw.get("sectionRatio", 1.0)) if raptor else 1.0
	ClawLook.apply(_sheath_mat, ClawLook.params(inlay, sheath_col, sheath_finish))
	var other_light := bool(sn.claw.quickVisible) and other_inlay == "none"
	var other_col := col if other_inlay == inlay else Color(String(sn.claw.get("keratinColor", sn.claw.color)))
	var po := ClawLook.params(other_inlay, other_col, { "light": other_light, "other": true, "quality": q, "probe": probe, "length_mm": len_mm })
	ClawLook.apply(_other_mat, po)
	_other_mat.set_shader_parameter("apex_mm", float(sn.claw.startMm))
	for k: String in _other_mats:
		var om: ShaderMaterial = _other_mats[k]
		var pk := po if other_inlay != "none" else ClawLook.params(other_inlay, CarePaw.claw_tone(other_col, art, k),
			{ "light": other_light, "other": true, "quality": q, "probe": probe })
		ClawLook.apply(om, pk)
		om.set_shader_parameter("apex_mm", float(_slot_len.get(k, sn.claw.startMm)))
	ClawLook.apply_model(_paw.get("a3d"), po)
	_quick.visible = revealed


func _apply_state(v: Dictionary) -> void:
	var sn: Dictionary = v.snap
	var m := _sheath_mat
	var apex := float(sn.claw.lengthMm)
	m.set_shader_parameter("apex_mm", apex)
	m.set_shader_parameter("flat_r", float(sn.tip.flatMm))
	# daños: grietas y escamas
	var cracks: Array = sn.damage.splits
	var cv := PackedVector4Array()
	for i in 4:
		if i < cracks.size():
			var c: Dictionary = cracks[i]
			cv.append(Vector4(float(c.from_s), float(c.to_s), 1.0 if bool(c.reaches_quick) else 0.0, 0.0))
		else:
			cv.append(Vector4.ZERO)
	m.set_shader_parameter("cracks", cv)
	m.set_shader_parameter("crack_n", mini(cracks.size(), 4))
	var peels: Array = sn.damage.peels
	var pv := PackedVector4Array()
	for i in 4:
		if i < peels.size():
			pv.append(Vector4(float(peels[i].from_s), float(peels[i].to_s), 0.0, 0.0))
		else:
			pv.append(Vector4.ZERO)
	m.set_shader_parameter("peels", pv)
	m.set_shader_parameter("peel_n", mini(peels.size(), 4))
	# sangre, hemostático, crema, humedad, desinfección y la señal del corte
	var bl: Dictionary = sn.bleeding
	m.set_shader_parameter("blood", 1.0 if bool(bl.active) else (0.45 if bool(bl.bled) else 0.0))
	m.set_shader_parameter("blood_from", apex - 2.5)
	var used := _tools_used(v)
	m.set_shader_parameter("powder", 1.0 if (used.has("hemostatico") or used.has("nitrato_plata")) and bool(bl.bled) else 0.0)
	m.set_shader_parameter("cream", 1.0 if used.has("crema") else 0.0)
	m.set_shader_parameter("disinfected", 1.0 if used.has("clorhexidina") else 0.0)
	m.set_shader_parameter("wet", 1.0 if String(sn.claw.humidity) in ["humeda", "empapada"] else 0.0)
	m.set_shader_parameter("sign_k", 1.0 if bool(sn.claw.sign) else 0.0)
	# la reconstrucción: el acrílico con la forma de partida, desde donde se rompió
	_ghost.visible = bool(sn.damage.repaired)
	_ghost_mat.set_shader_parameter("from_s", apex)
	_apply_heat(v)
	_apply_surface(v)
	_apply_hints(v)
	_apply_section(v)
	_mirror_block_state()
	_break_piece(sn)
	_gauge.show_view(v)
	# la sedación y el respingo de dolor
	var sed := String(sn.animal.sedation)
	if sed != _sedation:
		_sedation = sed
		CareAnimal.set_sedation(_paw, sed)
	var moved := int(sn.animal.moved)
	if moved > _moved_seen:
		_flinch = 1.0
	_moved_seen = moved


## Herramientas que se han usado en el ensayo (de las llamadas registradas no: de lo que ha pasado en la vista).
func _tools_used(v: Dictionary) -> Dictionary:
	var out := {}
	for e: Dictionary in v.get("fx", []):
		if String(e.get("kind", "")) == "apply":
			out[String(e.tool)] = true
	var la: Dictionary = v.get("last_action", {})
	if String(la.get("kind", "")) == "hemostasis":
		out[String(la.params.tool) if String(la.params.tool) != "" else "presion"] = true
	if String(v.snap.bleeding.agent) != "":
		out[String(v.snap.bleeding.agent)] = true
	return out


## El calor, como una cámara térmica: de los nodos del modelo térmico (thermal.cells, del extremo vivo a la cara que se
## trabaja: en la punta, cada ClawCare.THERMAL_DX_MM hacia atrás desde el vértice) o, en el flanco, una mancha en el
## contacto con la temperatura de la cara. Solo se pinta si algo pasa de 33 °C.
func _apply_heat(v: Dictionary) -> void:
	var th: Dictionary = v.snap.thermal
	var cells: PackedFloat64Array = th.cells
	var face := float(th.faceC)
	var apex := float(v.snap.claw.lengthMm)
	var on := face > 33.0 and not bool(v.reforged)
	var la: Dictionary = v.get("last_action", {})
	var zone := String(la.get("params", {}).get("zone", "punta"))
	var at := float(la.get("params", {}).get("at_mm", 0.0))
	var key := "%s|%s|%s|%s" % [var_to_str(face), zone, var_to_str(apex), str(cells.size())]
	if key == _heat_key:
		return
	_heat_key = key
	_sheath_mat.set_shader_parameter("heat_on", 1.0 if on else 0.0)
	if not on:
		return
	var s0: float
	var s1: float
	if zone == "flanco":
		var sc := apex - at
		s0 = sc - 4.0
		s1 = sc + 4.0
		for x in 64:
			var s := lerpf(s0, s1, (float(x) + 0.5) / 64.0)
			var w := exp(-pow((s - sc) / 1.5, 2.0))
			_heat_img.set_pixel(x, 0, Color(clampf((face - 32.0) / 40.0 * w, 0.0, 1.0), 0, 0))
	else:
		var n := cells.size()
		var span := maxf(float(n - 1) * 0.1, 0.5)
		s0 = apex - span
		s1 = apex
		for x in 64:
			var f := (float(x) + 0.5) / 64.0
			var ci := clampi(int(round(f * float(n - 1))), 0, maxi(n - 1, 0))
			var t := cells[ci] if n > 0 else 32.0
			_heat_img.set_pixel(x, 0, Color(clampf((t - 32.0) / 40.0, 0.0, 1.0), 0, 0))
	_heat_tex.update(_heat_img)
	_sheath_mat.set_shader_parameter("heat_range", Vector2(s0, s1))


func _apply_hints(v: Dictionary) -> void:
	var h: Dictionary = v.hints
	var hl := String(h.highlight)
	var sn: Dictionary = v.snap
	var apex := float(sn.claw.lengthMm)
	var band := Vector2.ZERO
	match hl:
		"sobrante":
			var og: Array = h.overgrowth
			if og.size() == 2:
				band = Vector2(float(og[0]), float(og[1]))
		"banda":
			var qb: Array = h.quick_band
			if qb.size() == 2:
				band = Vector2(float(qb[0]), float(qb[1]))
		"carne_viva":
			if bool(h.revealed) and sn.claw.quickMm != null:
				band = Vector2(float(sn.claw.quickMm) - 1.0, float(sn.claw.quickMm) + 0.5)
		"punta", "herida", "angulo":
			band = Vector2(apex - float(h.tip_zone_mm), apex + 0.1)
		"base":
			var qb2: Array = h.quick_band
			band = Vector2(0.0, float(qb2[0]) if qb2.size() == 2 else apex * 0.5)
		"garra", "pasada":
			band = Vector2(0.0, apex + 0.1)
	_sheath_mat.set_shader_parameter("hi_on", 1.0 if band.y > band.x else 0.0)
	_sheath_mat.set_shader_parameter("hi_band", band)
	_sheath_mat.set_shader_parameter("hi_color", Palette.color(String(HINT_COLORS.get(hl, "gold"))))
	_arrow.visible = hl == "pasada"
	var akey := "%s|%s" % [_mesh_key, var_to_str(apex)]
	if _arrow.visible and akey != _arrow_key:
		_arrow_key = akey
		_rebuild_arrow(apex)
	_guide.visible = hl == "angulo"
	if _guide.visible:
		var ga: Array = h.good_angle
		var gkey := "%s|%s|%s" % [_mesh_key, var_to_str(apex), var_to_str(float(v.hand.angle_deg))]
		if gkey != _guide_key:
			_guide_key = gkey
			_rebuild_guide(apex, float(ga[0]), float(ga[1]), float(v.hand.angle_deg))


## La flecha de la pasada, sobre la cara dorsal, de la base hacia la punta (en mm, en el marco de la garra).
func _rebuild_arrow(apex: float) -> void:
	var n := 24
	var am := _arrow.mesh as ArrayMesh
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var ss_prof: PackedFloat64Array = _v.snap.profile.s
	var rs_prof: PackedFloat64Array = _v.snap.profile.r
	var w := maxf(ClawMesh.radius_at(ss_prof, rs_prof, 0.0) * 0.35, 0.4)
	for i in n + 1:
		var s := lerpf(apex * 0.15, apex * 0.85, float(i) / float(n))
		var r := ClawMesh.radius_at(ss_prof, rs_prof, s) + 0.8
		var c := ClawMesh.surface_point(s, r, _k, 0.0, _shape)
		var lat := ClawMesh.LATERAL * w
		verts.append(c - lat)
		verts.append(c + lat)
	for i in n:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	# la punta de flecha
	var s_end := apex * 0.85
	var tip := ClawMesh.surface_point(s_end + w * 3.0, ClawMesh.radius_at(ss_prof, rs_prof, s_end) + 0.8, _k, 0.0, _shape)
	var base_i := verts.size()
	var cb := ClawMesh.surface_point(s_end, ClawMesh.radius_at(ss_prof, rs_prof, s_end) + 0.8, _k, 0.0, _shape)
	verts.append(cb - ClawMesh.LATERAL * w * 2.2)
	verts.append(cb + ClawMesh.LATERAL * w * 2.2)
	verts.append(tip)
	idx.append_array([base_i, base_i + 2, base_i + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## La guía del ángulo: las dos líneas de la banda buena de la faceta ([lo, hi]° con el eje de la punta) y la de la
## herramienta ahora, en el plano de la curva, desde el vértice hacia atrás.
func _rebuild_guide(apex: float, lo: float, hi: float, now: float) -> void:
	var tip := ClawMesh.point_at(apex, _k)
	var t := ClawMesh.tangent_at(apex, _k)
	var u := ClawMesh.up_at(apex, _k)
	var L := maxf(apex * 0.35, 6.0)
	for pair: Array in [[_guide_lo, lo, 0.25], [_guide_hi, hi, 0.25], [_guide_now, now, 0.4]]:
		var mi: MeshInstance3D = pair[0]
		var ang := deg_to_rad(float(pair[1]))
		var d := (-t * cos(ang) + u * sin(ang)).normalized()
		var side := d.cross(ClawMesh.LATERAL).normalized() * float(pair[2])
		var verts := PackedVector3Array([tip - side, tip + side, tip + d * L + side, tip + d * L - side])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var am := mi.mesh as ArrayMesh
		am.clear_surfaces()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## La vista de sección: fondo, rótulos y escala en el plano de la curva.
func _apply_section(v: Dictionary) -> void:
	var root: Node3D = _sec.root
	root.visible = view_name == "seccion"
	if not root.visible:
		return
	var sn: Dictionary = v.snap
	var apex := float(sn.claw.lengthMm)
	var start := float(sn.claw.startMm)
	var base_r := float(sn.claw.baseRadiusMm)
	var mid := ClawMesh.point_at(apex * 0.5, _k)
	var span := maxf(start, base_r * 4.0) * 1.5
	var bg: MeshInstance3D = _sec.bg
	bg.transform = Transform3D(Basis.from_scale(Vector3(span * 1.6, span * 1.2, 1.0)), mid + Vector3(0.0, 0.0, -0.1))
	var labels: Dictionary = _sec.labels
	var text_px := span * 0.03 / 48.0
	for k: String in labels:
		(labels[k] as Label3D).pixel_size = text_px
	var ss: PackedFloat64Array = sn.profile.s
	var rs: PackedFloat64Array = sn.profile.r
	var s_mid := apex * 0.35
	(labels.sheath as Label3D).text = "estuche de queratina"
	(labels.sheath as Label3D).position = ClawMesh.point_at(s_mid, _k) + ClawMesh.up_at(s_mid, _k) * (ClawMesh.radius_at(ss, rs, s_mid) + span * 0.06) + Vector3(0, 0, 0.2)
	var revealed := bool(v.hints.revealed)
	(labels.quick as Label3D).visible = revealed
	(labels.bone as Label3D).visible = revealed
	if revealed:
		(labels.quick as Label3D).text = "carne viva"
		(labels.quick as Label3D).position = ClawMesh.point_at(s_mid * 0.6, _k) - ClawMesh.up_at(s_mid * 0.6, _k) * (ClawMesh.radius_at(ss, rs, s_mid * 0.6) + span * 0.06) + Vector3(0, 0, 0.2)
		(labels.bone as Label3D).text = "hueso (dibujo)"
		(labels.bone as Label3D).position = ClawMesh.point_at(s_mid * 0.3, _k) + Vector3(0, 0, 0.2)
	var qb: Array = v.hints.quick_band
	(labels.band as Label3D).visible = not revealed and qb.size() == 2
	(_sec.band as MeshInstance3D).visible = (labels.band as Label3D).visible
	if (labels.band as Label3D).visible:
		var sb := 0.5 * (float(qb[0]) + float(qb[1]))
		(labels.band as Label3D).text = "aquí acaba la carne viva\n(en la población)"
		(labels.band as Label3D).position = ClawMesh.point_at(sb, _k) - ClawMesh.up_at(sb, _k) * (ClawMesh.radius_at(ss, rs, sb) + span * 0.08) + Vector3(0, 0, 0.2)
		var bkey := "%s|%s|%s|%s" % [var_to_str(float(qb[0])), var_to_str(float(qb[1])), var_to_str(_k), var_to_str(apex)]
		if bkey != String(_sec.band_key):
			_sec["band_key"] = bkey
			_section_band((_sec.band as MeshInstance3D).mesh as ArrayMesh, float(qb[0]), minf(float(qb[1]), apex), ss, rs, span)
	# escala: 5 mm (1 mm en las garras pequeñas)
	var bar_mm := 5.0 if start > 25.0 else 1.0
	var corner := mid + Vector3(-span * 0.6, -span * 0.45, 0.15)
	(_sec.bar as MeshInstance3D).transform = Transform3D(Basis.from_scale(Vector3(bar_mm, span * 0.006, 0.01)), corner + Vector3(bar_mm * 0.5, 0.0, 0.0))
	(labels.scale as Label3D).text = "%d mm" % int(bar_mm)
	(labels.scale as Label3D).position = corner + Vector3(bar_mm * 0.5, span * 0.03, 0.0)


## La franja [lo, hi] (mm desde la base) de lado a lado de la garra en el corte, un poco por delante de él.
func _section_band(am: ArrayMesh, lo: float, hi: float, ss: PackedFloat64Array, rs: PackedFloat64Array, span: float) -> void:
	am.clear_surfaces()
	if hi <= lo:
		return
	var verts := PackedVector3Array()
	var steps := 8
	for j in steps:
		var pts: Array = []
		for e in 2:
			var sj := lerpf(lo, hi, float(j + e) / float(steps))
			var c := ClawMesh.point_at(sj, _k)
			var u := ClawMesh.up_at(sj, _k)
			var r := ClawMesh.radius_at(ss, rs, sj) + span * 0.01
			pts.append([c - u * r + Vector3(0, 0, 0.05), c + u * r + Vector3(0, 0, 0.05)])
		verts.append_array(PackedVector3Array([pts[0][0], pts[1][0], pts[1][1], pts[0][0], pts[1][1], pts[0][1]]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## La superficie de la garra (petición 37; la pone en el motor la 5g: ClawCare.snapshot().surface, por estación): la
## textura de una fila (una columna por estación) que lee el material, codificada por la biblioteca de materiales
## (ClawMaterial.surface_image y set_surface: el reparto del contrato «La cetrería en alta definición y la superficie de
## la garra»). Sin datos del motor, la del acabado (clear_surface). Solo cambia cuando cambia la instantánea.
func _apply_surface(v: Dictionary) -> void:
	var sn: Dictionary = v.snap
	var length := float(sn.claw.lengthMm)
	# la que trae la vista (hecha en el hilo del estado, con la lista del motor): solo si es otra imagen o cambia el largo
	var img: Variant = v.get("surface_img")
	if img is Image:
		var ikey := "img|%d|%s" % [(img as Image).get_instance_id(), var_to_str(length)]
		if ikey != _surface_key:
			_surface_key = ikey
			_set_surface_image(img as Image, length)
		return
	# si no (una vista hecha a mano), la de la instantánea, con el codificador de la biblioteca; solo si cambia
	var surf: Variant = sn.get("surface")
	var has := surf is Dictionary or surf is Array
	var key := "%d|%s|%s" % [hash(surf) if has else 0, str(has), var_to_str(length)]
	if key == _surface_key:
		return
	_surface_key = key
	var stations := surface_stations(surf) if has else []
	if stations.is_empty():
		ClawMaterial.clear_surface(_sheath_mat)
		return
	_set_surface_image(ClawMaterial.surface_image(stations), length)


## Pone la textura de la superficie en la queratina (y en el material reforjado, que es el mismo): la reutiliza si tiene
## el mismo tamaño.
func _set_surface_image(img: Image, length: float) -> void:
	var same := _surface_img != null and _surface_img.get_size() == img.get_size() and _surface_img.get_format() == img.get_format()
	_surface_img = img
	if same:
		_surface_tex.update(img)
	else:
		_surface_tex.set_image(img)
	ClawMaterial.set_surface(_sheath_mat, _surface_tex, length)


## Las estaciones de la superficie del motor como las pide la biblioteca ([{ ra_um, burn, chip, scratch_deg }], de la base
## a la punta): acepta esa lista o un diccionario con un array por campo.
static func surface_stations(surf: Variant) -> Array:
	if surf is Array:
		return surf
	var out: Array = []
	if not (surf is Dictionary):
		return out
	var d: Dictionary = surf
	var fields := ["ra_um", "burn", "chip", "scratch_deg"]
	var n := 0
	for f: String in fields:
		var arr0: Variant = d.get(f)
		if arr0 is Array or arr0 is PackedFloat64Array or arr0 is PackedFloat32Array:
			n = maxi(n, int(arr0.size()))
	for i in n:
		var e := {}
		for f: String in fields:
			var arr: Variant = d.get(f)
			if (arr is Array or arr is PackedFloat64Array or arr is PackedFloat32Array) and i < int(arr.size()):
				e[f] = float(arr[i])
		out.append(e)
	return out


## El trozo que se separa: al cortar la garra (o al mellarse la punta), lo que había del perfil de antes entre la punta
## nueva y la de antes se separa y cae (dibujo de lo que dice el motor: el perfil antes y después). Un solo nodo, que se
## reutiliza: su malla se rehace en el momento del corte, no en cada fotograma.
func _spawn_piece() -> void:
	if _prev_prof.is_empty() or _cur_prof.is_empty() or String(_prev_prof.get("slot", "")) != _slot_key:
		return
	var old_apex := float(_prev_prof.apex)
	var new_apex := float(_cur_prof.apex)
	if old_apex - new_apex < PIECE_MIN_MM:
		return
	var prof: Dictionary = _prev_prof.prof
	if not prof.has("s"):
		return
	_drop_piece(prof.s, prof.r, new_apex, float(_prev_prof.k))


## Las roturas que apunta el motor (la 5g: damage.breaks, cada una con su sitio y, si se va, el trozo con su perfil): el
## trozo se separa por donde dice y cae. Cada rotura, una vez; las de antes de elegir esta garra (o este ensayo) ya no
## sueltan nada (drop false: solo se apuntan como vistas). Un solo trozo a la vez: el último que se va. true si el motor
## da la lista.
func _break_piece(sn: Dictionary, drop := true) -> bool:
	var breaks: Variant = (sn.get("damage", {}) as Dictionary).get("breaks")
	if not (breaks is Array):
		return false
	var arr: Array = breaks
	var slot := "%s|%s" % [_trial, _slot_key]
	if slot != _break_key or arr.size() < _breaks_seen:
		_break_key = slot
		_breaks_seen = arr.size()
		return true
	var last := {}
	for i in range(_breaks_seen, arr.size()):
		var b: Dictionary = arr[i]
		var bp: Dictionary = b.get("profile", {})
		if bool(b.get("falls", false)) and float(b.get("pieceMm", 0.0)) >= PIECE_MIN_MM and (bp.get("s", []) as Variant).size() >= 2:
			last = b
	_breaks_seen = arr.size()
	if drop and not last.is_empty():
		var pp: Dictionary = last.profile
		_drop_piece(pp.s, pp.r, float(last.get("fromS", (pp.s as PackedFloat64Array)[0])), _k)
	return true


## Separa el trozo del perfil (ss, rs) que va de s_from a su punta y lo deja caer: salta del corte hacia delante y algo
## hacia arriba, girando. Su malla se hace aquí, en el momento de la rotura.
func _drop_piece(ss: PackedFloat64Array, rs: PackedFloat64Array, s_from: float, k: float) -> void:
	var pc := ClawMesh.piece_arrays(ss, rs, k, maxi(int(ClawMesh.RING / 2), 12), _shape, s_from)
	if pc.is_empty():
		return
	_set_surface(_piece_mesh, pc.arrays)
	_piece_span = Vector2(s_from, ss[ss.size() - 1])
	var gx := _claw.global_transform
	var at: Transform3D = gx * Transform3D(Basis.IDENTITY, pc.center as Vector3)
	_piece.global_transform = at
	var t := (gx.basis * ClawMesh.tangent_at(s_from, k)).normalized()
	# salta del corte hacia delante y algo hacia arriba (como un recorte de uña) y cae girando
	var side := t.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-8 else Vector3.BACK
	_piece_st = { "on": true, "t": 0.0, "vel": t * PIECE_KICK_MS + Vector3.UP * PIECE_KICK_MS * 1.4, "spin": side * 14.0, "xf": at }
	_piece.visible = true
	_pieces += 1


## El trozo, en cada fotograma: se suelta (un instante), cae girando con la gravedad y se queda en la mesa o se pierde por
## el borde; luego desaparece. Solo mueve su transformación.
func _update_piece(dt: float) -> void:
	if not bool(_piece_st.get("on", false)) or dt <= 0.0:
		return
	var st := _piece_st
	st["t"] = float(st.t) + dt
	var xf: Transform3D = st.xf
	var v: Vector3 = st.vel
	# un instante sin gravedad (se suelta) y después cae
	if float(st.t) > PIECE_HOLD_S:
		v += Vector3(0.0, -9.81, 0.0) * dt
	var floor_y := 0.0005 if xf.origin.x < TABLE_EDGE_X else -CareRoom.TABLE_H
	var p := xf.origin + v * dt
	if p.y <= floor_y:
		p.y = floor_y
		v = Vector3.ZERO
		st["spin"] = Vector3.ZERO
	var spin: Vector3 = st.spin
	var b := xf.basis
	if spin.length_squared() > 1e-8:
		b = Basis(spin.normalized(), spin.length() * dt) * b
	xf = Transform3D(b.orthonormalized() * Basis.from_scale(xf.basis.get_scale()), p)
	st["vel"] = v
	st["xf"] = xf
	_piece.global_transform = xf
	if float(st.t) > PIECE_LIFE_S:
		st["on"] = false
		_piece.visible = false


# ───────────────────────────── efectos ─────────────────────────────

## Los efectos nuevos de la vista (los de n mayor que el último visto): lo que sale de cada pasada, esquirlas, gotas.
func _apply_fx(v: Dictionary) -> void:
	var n := int(v.get("fx_n", 0))
	if n <= _fx_seen:
		return
	var sn: Dictionary = v.snap
	var col := Color(String(sn.claw.color)).lightened(0.35)
	for e: Dictionary in v.fx:
		if int(e.n) <= _fx_seen:
			continue
		match String(e.kind):
			"dust":
				_spawn_debris(e, col)
			"chip":
				_dust.spawn(_tip_world(), Vector3.UP, 0.8, 0.5, 6, 0.0012, Color(col, 1.0), 1.4)
				if not _break_piece(sn):
					_spawn_piece()
			"clip":
				_dust.spawn(_tip_world(), Vector3.DOWN, 0.6, 0.3, 3, 0.002, Color(col, 1.0), 1.6)
				if not _break_piece(sn):
					_spawn_piece()
			"bleed":
				_drip_acc = 1.0
	_fx_seen = n


## Lo que sale de una pasada (unidad 5l; ClawCare.debris_for): polvo (la queratina y los frágiles) del color de su material,
## más claro (el polvo dispersa la luz), limaduras brillantes de los metales y virutas del acrílico; cuantas más cuanto más
## arranca y más grandes cuanto más hondo corta cada filo (dibujo: lo de verdad mide micras). Sin arrancar nada (la
## herramienta resbala o roza), nada. Si chispea (el acero, el titanio, el metal duro), las chispas de su firma.
func _spawn_debris(e: Dictionary, keratin_col: Color) -> void:
	var mm3 := float(e.mm3)
	if not (mm3 > 0.0):
		return
	var db: Dictionary = e.get("debris", {})
	var kind := String(db.get("kind", "polvo"))
	var col := keratin_col
	if db.has("color") and String(db.get("material", "none")) != "none":
		col = Color(String(db.color))
	var at := _contact_world(e)
	# el tamaño de dibujo: de 0,4 a 1,4 mm según la hondura del surco de cada filo (de 1 a 100 µm, en escala logarítmica)
	var size_k := clampf(log(maxf(float(db.get("sizeUm", 10.0)), 1.0)) / log(100.0), 0.0, 1.0)
	# cuántas (dibujo): más cuanto más arranca. A mano, por tramo de pasada, en escala logarítmica: de una diezmilésima de mm³
	# (la lima de diamante en el zafiro: así también se ve que muerde) a un mm³, de 4 a 36. Las giratorias arrancan a trozos
	# seguidos: tantas por segundo como ROT_DUST_PPS por la raíz cúbica del ritmo (mm³/s), con lo que sobra para el siguiente;
	# así la queratina (~15 mm³/s) echa unas 300 por segundo y el zafiro con el tambor vidriado (~0,005), unas 20
	var rot := State.is_rotary(String(e.get("tool", "")))
	var count := 0
	if rot:
		var dt_ev := clampf(_t - _dust_t, 1.0 / 120.0, 0.25)
		_dust_t = _t
		_dust_carry += ROT_DUST_PPS * pow(mm3 / dt_ev, 1.0 / 3.0) * dt_ev
		count = mini(int(_dust_carry), 40)
		_dust_carry = minf(_dust_carry - float(int(_dust_carry)), 1.0)
	else:
		var decades := log(maxf(mm3, 1.0e-6) / 1.0e-4) / log(10.0)
		count = clampi(int(round(4.0 + 8.0 * decades)), 4, 40)
	if count > 0:
		match kind:
			"limaduras":
				# láminas finas: caen antes que el polvo, pero no como piedras (Stokes con el grueso, entre FLAKE_K: dibujo)
				var fk := clampf(float(db.get("dragPerS", _filings.drag)) / FLAKE_K, _filings.drag, FINE_DUST_DRAG)
				_filings.spawn(at, Vector3.UP + _cam_right() * 0.4, 1.1, 0.4, mini(count, 24), 0.0006 + 0.0008 * size_k, Color(col, 1.0), 1.6, fk)
			"virutas":
				_dust.spawn(at, Vector3.UP + _cam_right() * 0.4, 0.8, 0.16, mini(count, 24), 0.0009 + 0.0009 * size_k, Color(col, 0.95), 1.6)
			_:
				var fine := String(db.get("material", "none")) != "none"
				if fine:
					# el polvo de un frágil es de micras y flota (Stokes: debris.dragPerS; ClawCare.debris_for): se abre en una nube
					# de ~1 cm junto a la punta, frena enseguida y baja despacio (dibujo: el rozamiento, hasta FINE_DUST_DRAG; más
					# motas y algo mayores que las de queratina para que se vea lo poco que sale)
					var dk := clampf(float(db.get("dragPerS", _dust.drag)), _dust.drag, FINE_DUST_DRAG)
					_dust.spawn(at, Vector3.UP + _cam_right() * 0.4, 1.2, 0.6, mini(int(count * 1.5), 48), 0.00065 + 0.0005 * size_k,
						Color(col.lightened(0.2), 0.85), 1.8, dk)
				else:
					_dust.spawn(at, Vector3.UP + _cam_right() * 0.4, 0.9, 0.18, count, 0.0004 + 0.0004 * size_k, Color(col.lightened(0.2), 0.9), 1.2)
	var sp := String(db.get("sparks", ""))
	if sp != "" and rot:
		_spark_mat = sp
		_spark_until = _t + SPARK_HOLD_S


## Cómo van las herramientas (unidad 5l; ClawCareState.view().tools): la banda de la cara que ha trabajado se ve gastada, la
## lima embotada (las crestas de los dientes, romas y brillantes) y el grano vidriado (las puntas planas que brillan). glaze:
## el ancho de la plataforma de los filos frente a su tamaño o lo que ha perdido de filo (dull: 1 con el doble de radio, ya
## «gastada»), lo que más; la banda, del ancho que ha trabajado (stripMm), a lo largo de la lima o alrededor del tambor.
func _apply_tool_wear(v: Dictionary) -> void:
	var tw: Dictionary = v.get("tools", {})
	var key := ""
	for id: String in tw:
		key += "%s:%s;" % [id, var_to_str(float(tw[id].get("flatUm", 0.0)))]
	if key == _wear_key:
		return
	_wear_key = key
	for id: String in tw:
		if not _tools.has(id) or _tools[id].get("face_mat") == null:
			continue
		var st: Dictionary = tw[id]
		var t := State.tool_data(id)
		var size_um := float(t.get("grain_um", 0.0)) if String(t.get("element", "")) == "grano" else 10000.0 / maxf(float(t.get("teeth_cm", 10.0)), 1.0)
		var glaze := clampf(maxf(float(st.get("flatUm", 0.0)) / maxf(size_um, 1.0), float(st.get("dull", 0.0))), 0.0, 1.0)
		var fm: ShaderMaterial = _tools[id].face_mat
		fm.set_shader_parameter("glaze", glaze)
		fm.set_shader_parameter("glaze_width", clampf(float(st.get("stripMm", 2.0)), 0.8, 12.7))


func _contact_world(e: Dictionary) -> Vector3:
	var apex := float(_v.snap.claw.lengthMm)
	var s := apex - float(e.get("at_mm", 0.0)) if String(e.get("zone", "punta")) == "flanco" else apex
	var ss: PackedFloat64Array = _v.snap.profile.s
	var rs: PackedFloat64Array = _v.snap.profile.r
	return _claw.global_transform * ClawMesh.surface_point(s, ClawMesh.radius_at(ss, rs, s), _k, 0.0, _shape)


func _tip_world() -> Vector3:
	return _claw.global_transform * ClawMesh.point_at(float(_v.snap.claw.lengthMm) if not _v.is_empty() else 0.0, _k)


func _cam_right() -> Vector3:
	return _rig.camera().global_transform.basis.x


# ───────────────────────────── cada fotograma ─────────────────────────────

## Un fotograma (lo llama _process o la página; los tests, sin ventana).
func advance(delta: float) -> void:
	_ensure_built()
	var t0 := Time.get_ticks_usec()
	var dt := maxf(delta, 0.0)
	_t += dt
	_sheath_mat.set_shader_parameter("time", _t)
	if _block.visible:
		_block_mat.set_shader_parameter("time", _t)
	_update_pointer_hit()
	_emit_drag(dt)
	_update_tool_pose(dt)
	# la pieza de la reforja en la mano (unidad 5o): sigue al puntero y dice cuánto se aparta del centro del muñón (sin pieza
	# que colocar, nada: ni la cámara ni el tamaño del píxel)
	if not _bond3d.bv.is_empty():
		var aim := _bond3d.update(_rig.camera(), _pointer, _claw, _k, _mm_per_px())
		if aim >= 0.0 and (absf(aim - _aim_sent) > 0.05 or _bond3d.docked != _dock_sent):
			_aim_sent = aim
			_dock_sent = _bond3d.docked
			gesture.emit("bond_aim", [aim, _bond3d.docked])
		_update_bond_drag(dt, aim)
	elif _bond3d.docked:
		_bond3d.docked = false
	_update_tool_anim(dt)
	if _suggest_mark.visible:
		_suggest_mark.position = _suggest_base + Vector3(0.0, 0.006 * (0.5 + 0.5 * sin(_t * 5.0)), 0.0)
	_update_particles(dt)
	_update_sparks(dt)
	_update_piece(dt)
	_flinch = maxf(_flinch - dt * 2.5, 0.0)
	_breath_t += dt * (_reaction.breath_rate() if _reaction != null else 1.0)
	CareAnimal.animate(_paw, _breath_t, _sedation, _flinch, String(_v.get("paw", "")))
	# 5t-B: la reacción manda sobre la pose de reposo mientras dura
	_reaction.advance(dt)
	_update_camera(dt)
	var us := Time.get_ticks_usec() - t0
	_upd_n += 1
	_upd_sum += us
	_upd_max = maxi(_upd_max, us)


## La pieza arrastrada desde la bandeja (el botón o el dedo pulsados): acoplada al muñón y quieta DOCK_HOLD_S, se coloca y se
## empieza a sujetar (la misma orden que un toque mantenido sobre el muñón con la pieza en la mano).
func _update_bond_drag(dt: float, aim: float) -> void:
	if not _bond_dragging:
		return
	if _pointer.distance_to(_drag_anchor) > DOCK_STILL_PX:
		_drag_anchor = _pointer
		_drag_still = 0.0
		return
	if not _bond3d.docked or not bool((_v.get("bond", {}) as Dictionary).get("held", false)):
		_drag_still = 0.0
		return
	_drag_still += dt
	if _drag_still >= DOCK_HOLD_S:
		_bond_dragging = false
		_bond_holding = true
		gesture.emit("bond_hold", [true, aim if aim >= 0.0 else _bond3d.aim_mm])


func _update_pointer_hit() -> void:
	if not _has_pointer:
		_hit = {}
		return
	# solo si algo ha cambiado: el puntero, la cámara, la garra (con la pata) o su forma (no en cada tic del estado)
	var key := [_pointer, _rig.camera().global_transform, _claw.global_transform, _mesh_key, view_name]
	if key == _hit_key:
		return
	_hit_key = key
	_hit = hit_at(_pointer)


## Dónde toca la garra el rayo de un punto de la pantalla (px del visor): { s (mm desde la base), point, normal, t } en
## el marco de la garra, o {} si no la toca (en la vista del corte, nunca). Si no da en la garra por poco (GRACE_PX), la
## toca igual: la punta mide décimas de milímetro. No cambia nada (también para la demo).
func hit_at(px: Vector2) -> Dictionary:
	if _v.is_empty() or view_name == "seccion":
		return {}
	var cam := _rig.camera()
	var inv := _claw.global_transform.affine_inverse()
	var lo := inv * cam.project_ray_origin(px)
	var ld := (inv.basis * cam.project_ray_normal(px)).normalized()
	var ss: PackedFloat64Array = _v.snap.profile.s
	var rs: PackedFloat64Array = _v.snap.profile.r
	# la línea media de esta forma, una vez (el rayo se lanza en cada fotograma que se mueve el puntero o la cámara)
	if String(_mid_cache.get("key", "")) != _mesh_key or (_mid_cache.get("pts", PackedVector3Array()) as PackedVector3Array).size() != ss.size():
		_mid_cache = { "key": _mesh_key, "pts": ClawMesh.midline(ss, _k) }
	var mid: PackedVector3Array = _mid_cache.pts
	var h := ClawMesh.ray_hit(ss, rs, _k, lo, ld, 0.0, _shape, mid)
	if not bool(h.hit):
		h = ClawMesh.ray_hit(ss, rs, _k, lo, ld, minf(GRACE_PX * _mm_per_px(), GRACE_MAX_MM), _shape, mid)
	return h if bool(h.hit) else {}


## Milímetros por píxel del visor a la distancia de la garra (la cámara en perspectiva).
func _mm_per_px() -> float:
	var cam := _rig.camera()
	var h := maxf(float(get_viewport().get_visible_rect().size.y), 1.0)
	var dist := cam.global_position.distance_to(_claw_mid_world())
	return 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / h / MM


## Un arrastre por fotograma con lo que se ha movido el puntero (la pasada o el contacto).
func _emit_drag(_dt: float) -> void:
	if not _pressed or _rotating:
		return
	var s := float(_hit.get("s", -1.0))
	gesture.emit("drag", [_acc_along, _acc_travel, s, _dt])
	_slide += _acc_along
	_acc_along = 0.0
	_acc_travel = 0.0


## Dónde va la herramienta de la mano: apoyada en la garra (o a HOVER_M si no aprieta) con la cara hacia ella y el
## ángulo de la pasada; si el puntero no está sobre la garra, flotando donde apunta, sobre la mesa.
func _update_tool_pose(dt: float) -> void:
	if _held == "" or not _tools.has(_held):
		return
	var t: Dictionary = _tools[_held]
	var root: Node3D = t.root
	var want: Transform3D
	var src: Dictionary = _press_hit if _pressed and String(hand.get("gesture", "")) == "lima" else _hit
	if not src.is_empty():
		want = _contact_xf(t, src, _pressed)
	else:
		# fuera de la garra, la herramienta flota donde apunta el ratón, a la distancia de la punta (en un plano de cara a
		# la cámara por la punta, un poco más allá): no se pega a la cámara ni tapa la vista
		var cam := _rig.camera()
		var fwd := -cam.global_transform.basis.z
		var p := _plane_point(cam, _pointer, fwd, _tip_world() + fwd * 0.01) if _has_pointer else _tip_world() + Vector3(0.05, 0.05, 0.08)
		want = Transform3D(Basis(Vector3.UP, PI * 0.35), p)
	# sobre la garra, la herramienta se transparenta: así se ve la garra que lima o corta (del torno y de la amoladora,
	# solo el cuerpo: el tambor y el protector se tienen que ver girar y trabajar)
	var fade := not src.is_empty()
	if fade != _tool_faded:
		_tool_faded = fade
		_fade_tool(_held, fade)
	if not _pose_ready:
		_pose_xf = want
		_pose_ready = true
	else:
		var k := 1.0 - exp(-dt / POSE_TAU) if dt > 0.0 else 1.0
		_pose_xf = _pose_xf.interpolate_with(want, k)
	root.transform = _pose_xf


## El marco de la herramienta en un contacto: la cara que corta contra la garra, girada con el ángulo de la pasada.
func _contact_xf(t: Dictionary, h: Dictionary, pressed: bool) -> Transform3D:
	var gx := _claw.global_transform
	var s := float(h.s)
	var tangent := (gx.basis * ClawMesh.tangent_at(s, _k)).normalized()
	var n := (gx.basis * (h.normal as Vector3)).normalized()
	var p := gx * (h.point as Vector3)
	var kind := String(t.kind)
	if kind == "cortaunas":
		# el cortaúñas rodea la garra: su boca en la línea media, la hoja por arriba
		var c := gx * ClawMesh.point_at(s, _k)
		var up := (gx.basis * ClawMesh.up_at(s, _k)).normalized()
		return Transform3D(Basis(tangent, up, tangent.cross(up)).orthonormalized(), c)
	var radial := (n - tangent * n.dot(tangent)).normalized()
	var ang := deg_to_rad(float(hand.get("angle_deg", 45.0)))
	var face_n := radial
	var along := tangent
	var lift := 0.0 if pressed else HOVER_M
	if String(t.id) in POINT_TOOLS:
		# lápiz, frasco, bastoncillo y aplicador: la punta contra la garra y el cuerpo hacia fuera
		var px := -radial
		var py := tangent
		var pz := px.cross(py).normalized()
		return Transform3D(Basis(px, pz.cross(px).normalized(), pz), p + radial * lift)
	if _near_tip(s) and kind in ["lima", "torno"]:
		face_n = (tangent * sin(ang) + radial * cos(ang)).normalized()
		along = (tangent * cos(ang) - radial * sin(ang)).normalized()
	var y := -face_n
	var x := along
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	var slide := 0.0
	if kind == "lima" and pressed:
		slide = clampf(_slide * MM, -float(t.half_mm) * MM, float(t.half_mm) * MM)
	return Transform3D(Basis(x, y, z), p + face_n * lift - x * slide)


func _near_tip(s: float) -> bool:
	if _v.is_empty():
		return false
	return float(_v.snap.claw.lengthMm) - s <= float(_v.hints.tip_zone_mm)


## El tambor gira (con el giro aparente del estroboscopio; arranca y se para con la inercia del motor, como en el sonido),
## los pilotos de la velocidad, la vibración y la hoja del cortaúñas.
func _update_tool_anim(dt: float) -> void:
	for id: String in ["torno", "amoladora"]:
		if not _tools.has(id):
			continue
		var t: Dictionary = _tools[id]
		var on := bool(hand.get("rotary_on", false)) and _held == id
		var rpm_goal := float(hand.get("rpm", 6500.0)) if on else 0.0
		# el giro sube y baja con las constantes del arranque y de la parada del sonido (SfxCare)
		var tau := SfxCare.SPIN_UP_TAU if rpm_goal > float(t.get("rpm_now", 0.0)) else SfxCare.SPIN_DOWN_TAU
		var rpm_now := lerpf(float(t.get("rpm_now", 0.0)), rpm_goal, 1.0 - exp(-dt / tau) if dt > 0.0 else 0.0)
		if rpm_now < 1.0 and rpm_goal == 0.0:
			rpm_now = 0.0
		t["rpm_now"] = rpm_now
		var rps := rpm_now / 60.0
		var shown := rps if rps < 2.0 else STROBE_APPARENT_RPS
		var ang := fposmod(float(t.get("angle", 0.0)) + shown * TAU * dt, TAU)
		t["angle"] = ang
		var circ := PI * float(t.get("drum_mm", 12.7))
		var fm: ShaderMaterial = t.face_mat
		fm.set_shader_parameter("spin", ang / TAU * circ)
		fm.set_shader_parameter("blur", rps * EXPOSURE_S * circ)
		var leds: Array = t.get("led_mats", [t.led_mat])
		var lit := int(hand.get("rpm_index", 0)) + 1 if on else 0
		for i in leds.size():
			(leds[i] as StandardMaterial3D).emission_energy_multiplier = 2.5 if i < lit or (leds.size() == 1 and on) else 0.0
		if t.has("slider"):
			# el botón del interruptor deslizante en la posición de su velocidad
			var sl: Node3D = t.slider
			var want_x := float(CareTools.GRINDER_SLIDE[clampi(int(hand.get("rpm_index", 0)), 0, 3)]) * CareTools.MM if _held == id else float(CareTools.GRINDER_SLIDE[0]) * CareTools.MM
			sl.position.x = lerpf(sl.position.x, want_x, 1.0 - exp(-dt / 0.06) if dt > 0.0 else 1.0)
		if rpm_now > 0.0:
			# vibración en marcha (dibujo): más con más vueltas
			var amp := 0.00012 * clampf(rpm_now / 8000.0, 0.0, 2.0)
			(t.root as Node3D).position += Vector3(sin(_t * 377.0), cos(_t * 311.0), sin(_t * 293.0)) * amp
	for id: String in ["guillotina", "tijera", "tenaza"]:
		if not _tools.has(id):
			continue
		var c: Dictionary = _tools[id]
		var closing := float(hand.get("closing", 0.0)) if _held == id else 0.0
		(c.blade as Node3D).position = (c.blade_open as Vector3).lerp(c.blade_closed as Vector3, closing)


func _update_particles(dt: float) -> void:
	var cam_b := _rig.camera().global_transform.basis
	# gotas de sangre mientras sangra (dibujo: unas por segundo) y el charco en la mesa
	if not _v.is_empty() and bool(_v.snap.bleeding.active):
		_drip_acc += dt * 1.6
		while _drip_acc >= 1.0:
			_drip_acc -= 1.0
			_drops.spawn(_tip_world(), Vector3.DOWN, 0.2, 0.05, 1, 0.0022, Color("#7A0A12"), 3.0)
	var landed_before := _drops.landed
	_dust.step(dt)
	_drops.step(dt)
	_filings.step(dt)
	# el charco, en la mesa solo si la punta queda encima de ella (por el borde, la sangre cae al suelo)
	var tip := _tip_world()
	var over_table := tip.x < TABLE_EDGE_X
	if _drops.landed > landed_before and over_table:
		_pool_r = minf(_pool_r + 0.0015 * float(_drops.landed - landed_before), 0.02)
	_pool.visible = _pool_r > 0.0 and over_table
	if _pool.visible:
		_pool.transform = Transform3D(Basis.from_scale(Vector3(_pool_r, 1.0, _pool_r * 0.8)), Vector3(tip.x, 0.0006, tip.z))
	for pair: Array in [[_dust, _dust_mmi], [_drops, _drops_mmi], [_filings, _filings_mmi]]:
		var fx: CareFx = pair[0]
		var mmi: MultiMeshInstance3D = pair[1]
		if fx.count > 0:
			mmi.multimesh.buffer = fx.fill(cam_b)
		mmi.multimesh.visible_instance_count = fx.count


## Chispas: solo con la herramienta giratoria encendida tocando la garra y arrancando de un metal que las da (la firma que
## da el motor con lo que sale de la pasada: el acero, el titanio, el metal duro; sparks.gd); con la velocidad del tambor que
## da el estado (ClawCare.surface_speed_ms). Lo que roza sin morder no echa chispas.
func _update_sparks(dt: float) -> void:
	var mat := _spark_mat if _t <= _spark_until else ""
	var on := mat != "" and State.is_rotary(_held) and bool(hand.get("rotary_on", false)) and _pressed and not _hit.is_empty()
	var vs := float(hand.get("drum_ms", 0.0))
	var key := "%s|%s|%s" % [mat, str(on), var_to_str(vs)]
	if key != _spark_key:
		_spark_key = key
		_emitter.configure(mat if mat != "" else "vidrio", {} if on else { "rate": 0.0 }, vs if on else 0.0)
	if on:
		var t: Dictionary = _tools[_held]
		var drum: Node3D = t.drum
		var c := drum.global_position
		var ax := (drum.global_transform.basis.x).normalized()
		var p := _claw.global_transform * (_hit.point as Vector3)
		var n := (_claw.global_transform.basis * (_hit.normal as Vector3)).normalized()
		_emitter.set_pose({ "center": c, "axis": ax, "radius": 12.7 * 0.5 * MM, "contact": p, "normal": n, "spin": 1.0, "kerf": 0.001 })
	_emitter.step(dt)
	var mm := _sparks_mmi.multimesh
	if _emitter.count() > 0:
		mm.buffer = _emitter.buffer(EXPOSURE_S, 0.00025, Sparks.MAX_SPARKS)
	mm.visible_instance_count = mini(_emitter.count(), 400 if is_mobile() else Sparks.MAX_SPARKS)
	_sparking = on


# ───────────────────────────── herramienta en la mano ─────────────────────────────

## La herramienta que sugiere el paso del tutorial (si no se tiene ya en la mano), señalada en la bandeja con la marca.
func _apply_suggest(v: Dictionary) -> void:
	var tv: Dictionary = v.get("tutorial", {})
	var id := String(tv.get("suggest", "")) if bool(tv.get("on", false)) else ""
	if id == _held or not _slots.has(id) or not _slot_boxes.has(id):
		id = ""
	if id == _suggest_id:
		return
	_suggest_id = id
	_suggest_mark.visible = id != ""
	if id == "":
		return
	var world: AABB = (_slots[id] as Transform3D) * (_slot_boxes[id] as AABB)
	_suggest_base = world.get_center() + Vector3(0.0, world.size.y * 0.5 + 0.018, 0.0)
	_suggest_mark.position = _suggest_base


func _apply_held(id: String) -> void:
	if id == _held:
		return
	if _held != "" and _tools.has(_held):
		(_tools[_held].root as Node3D).transform = _slots[_held]
		_fade_tool(_held, false)
	_tool_faded = false
	_held = id
	_pose_ready = false
	_slide = 0.0


# ───────────────────────────── ratón y táctil ─────────────────────────────

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
			if _pressed or _bond_dragging:
				_release()
			return true
		return false
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			if sd.index == 0:
				_rig.orbit_by(sd.relative)
			var d := _pinch_distance()
			if _pinch > 0.0 and d > 0.0:
				_pinch_zoom(_pinch / d)
			_pinch = d
			return true
		return false
	if _touches.size() >= 2:
		return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_set_pointer(mm.position)
		match _cam_drag:
			"orbita":
				_rig.orbit_by(mm.relative)
				return true
			"pan":
				_rig.pan_by(mm.relative)
				return true
		if _bond_holding:
			# la mano que sujeta la pieza: lo que se mueve (mm de la garra); quieta, nada
			if mm.relative.length() > 0.0:
				gesture.emit("bond_move", [mm.relative.length() * _mm_per_px()])
			return true
		if _rotating:
			gesture.emit("nudge_angle", [mm.relative.x * 0.25])
			return true
		if _pressed:
			_accumulate_drag()
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_set_pointer(mb.position)
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press(mb.shift_pressed)
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
				if mb.shift_pressed:
					gesture.emit("wheel_force", [1 if up else -1])
				else:
					_wheel_zoom(0.88 if up else 1.0 / 0.88)
				return true
	if event is InputEventMagnifyGesture:
		_wheel_zoom(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
		return true
	if event is InputEventPanGesture:
		_rig.orbit_by((event as InputEventPanGesture).delta * 6.0)
		return true
	return false


func _set_pointer(p: Vector2) -> void:
	_pointer = p
	_has_pointer = true


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


## El pellizco de dos dedos: acerca hacia lo que hay entre ellos (como la rueda con el puntero).
func _pinch_zoom(f: float) -> void:
	var pts: Array = _touches.values()
	if pts.size() >= 2:
		_hit = hit_at(((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5)
	_wheel_zoom(f)


## Botón izquierdo (o un dedo): sobre la garra con una herramienta, aprieta; sobre la bandeja, coge esa herramienta;
## con Mayús, gira la herramienta.
func _press(shift: bool) -> void:
	_update_pointer_hit()
	# la pieza de la reforja (unidad 5o): en la mano, se aprieta sobre el muñón y se sujeta mientras se mantiene el botón (o el
	# dedo); en la bandeja, se coge
	var bvv: Dictionary = _v.get("bond", {})
	if not bvv.is_empty() and not shift:
		if bool(bvv.held):
			# donde se aprieta (con el dedo no hay puntero que siga antes de tocar): lo que se aparta del centro del muñón ahí.
			# Sobre el muñón, se coloca y se sujeta; lejos, no (el estado lo dice)
			var aim := _bond3d.update(_rig.camera(), _pointer, _claw, _k, _mm_per_px())
			if _bond3d.docked:
				_bond_holding = true
				gesture.emit("bond_hold", [true, aim if aim >= 0.0 else _bond3d.aim_mm])
			else:
				_aim_sent = aim
				_dock_sent = false
				gesture.emit("bond_aim", [maxf(aim, 0.0), false])
				gesture.emit("bond_hold", [true, -1.0])
			return
		if _bond3d.points_at_piece(_rig.camera(), _pointer):
			# se coge y, sin soltar, se arrastra hasta el muñón (el gesto del teléfono; con el ratón, igual)
			gesture.emit("bond_grab", [true])
			_bond_dragging = true
			_drag_anchor = _pointer
			_drag_still = 0.0
			return
	# la bandeja solo si está más cerca que la garra (detrás de la garra, la bandeja no se toca)
	var claw_t := INF
	if not _hit.is_empty():
		claw_t = (_claw.global_transform * (_hit.point as Vector3)).distance_to(_rig.camera().project_ray_origin(_pointer))
	var tray_id := _tray_pick(claw_t)
	if tray_id != "":
		gesture.emit("pick", [tray_id])
		return
	if _hit.is_empty():
		# otra garra del animal: se trabaja esa; en el aire, con el torno o la amoladora en la mano: su interruptor (el
		# pulgar en el interruptor, como al sostenerla)
		var other := _claw_pick()
		if other != "":
			gesture.emit("select_claw", Array(other.split("|")))
		elif State.is_rotary(_held) and not shift:
			gesture.emit("toggle_rotary", [])
		return
	if _held == "":
		return
	if shift:
		_rotating = true
		return
	_pressed = true
	_press_hit = _hit.duplicate()
	_slide = 0.0
	_acc_along = 0.0
	_acc_travel = 0.0
	var cam := _rig.camera()
	_plane_n = -cam.global_transform.basis.z
	_plane_p = _claw.global_transform * (_hit.point as Vector3)
	_plane_prev = _plane_point(cam, _pointer, _plane_n, _plane_p)
	gesture.emit("press_on", [float(_hit.s)])


func _release() -> void:
	_rotating = false
	if _bond_dragging:
		# soltada lejos del muñón (o antes de dejarla quieta): se queda en la mano, siguiendo al puntero
		_bond_dragging = false
		return
	if _bond_holding:
		_bond_holding = false
		gesture.emit("bond_hold", [false])
		return
	if not _pressed:
		return
	_pressed = false
	_emit_drag(0.0)
	gesture.emit("release", [])
	_press_hit = {}
	_slide = 0.0


## Lo que se ha movido el puntero en el plano del contacto (de cara a la cámara): a lo largo de la garra (+ hacia la
## punta, en mm) y en total.
func _accumulate_drag() -> void:
	var cam := _rig.camera()
	var p := _plane_point(cam, _pointer, _plane_n, _plane_p)
	var d := p - _plane_prev
	_plane_prev = p
	var s0 := float(_press_hit.get("s", 0.0))
	var tangent := (_claw.global_transform.basis * ClawMesh.tangent_at(s0, _k)).normalized()
	_acc_along += d.dot(tangent) / MM
	_acc_travel += d.length() / MM


## Punto del rayo del puntero en el plano (normal n, por p0).
static func _plane_point(cam: Camera3D, px: Vector2, n: Vector3, p0: Vector3) -> Vector3:
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	var den := d.dot(n)
	if absf(den) < 1e-6:
		return p0
	var t := (p0 - o).dot(n) / den
	return o + d * maxf(t, 0.0)


## ¿Apunta el puntero a otra garra de las patas (no la elegida)? Su clave («pata|dedo») o «»: el rayo contra su perfil (la
## forma de partida o la de ahora), con el margen de la punta.
func _claw_pick() -> String:
	if not _has_pointer or _v.is_empty() or view_name == "seccion":
		return ""
	var cam := _rig.camera()
	var o := cam.project_ray_origin(_pointer)
	var d := cam.project_ray_normal(_pointer)
	var k := ClawMesh.claw_curvature(_v.snap.claw)
	var init: Dictionary = _v.get("initial_profile", {})
	var best := ""
	var best_t := INF
	for e: Dictionary in _v.get("slots", []):
		var key := String(e.key)
		var mi: MeshInstance3D = _others.get(key)
		if mi == null or not mi.is_visible_in_tree() or bool(e.selected):
			continue
		var prof: Dictionary = e.profile if not (e.profile as Dictionary).is_empty() else init
		if not prof.has("s"):
			continue
		var inv := mi.global_transform.affine_inverse()
		var lo := inv * o
		var ld := (inv.basis * d).normalized()
		var h := ClawMesh.ray_hit(prof.s, prof.r, k, lo, ld, minf(GRACE_PX * _mm_per_px(), GRACE_MAX_MM), _shape)
		if bool(h.hit):
			var t := (mi.global_transform * (h.point as Vector3)).distance_to(o)
			if t < best_t:
				best_t = t
				best = key
	return best


## ¿Apunta el puntero a una herramienta de la bandeja más cerca que max_t (m)? Su id o «».
func _tray_pick(max_t := INF) -> String:
	if not _has_pointer:
		return ""
	var cam := _rig.camera()
	var o := cam.project_ray_origin(_pointer)
	var d := cam.project_ray_normal(_pointer)
	var best := ""
	var best_t := max_t
	var px_m := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(float(get_viewport().get_visible_rect().size.y), 1.0)
	for id: String in _slot_boxes:
		if id == _held:
			continue
		# la caja de la herramienta en su marco (ajustada aunque esté girada), con un margen para el dedo: 4 mm o
		# GRACE_PX píxeles a su distancia, lo que sea más
		var xf: Transform3D = _slots[id]
		var inv := xf.affine_inverse()
		var grace := maxf(0.004, GRACE_PX * px_m * o.distance_to(xf.origin))
		var box: AABB = (_slot_boxes[id] as AABB).grow(grace)
		var hit: Variant = box.intersects_ray(inv * o, inv.basis * d)
		if hit != null:
			var t := (xf * (hit as Vector3)).distance_to(o)
			if t < best_t:
				best_t = t
				best = id
	return best


# ───────────────────────────── cámara y vistas ─────────────────────────────

func _apply_view(instant: bool) -> void:
	if _rig == null:
		return
	var mask := 0xFFFFF & ~(1 << (SECTION_LAYER - 1))
	(_sec.root as Node3D).visible = view_name == "seccion"
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1.0, 1.0)
	var aspect := clampf(vs.x / maxf(vs.y, 1.0), 0.4, 1.0)
	if not instant:
		# una vista pedida (o la garra nueva) se impone a lo que el usuario haya movido la cámara, y llega con suavidad
		_rig.reset_user()
	match view_name:
		"general":
			# la pata elegida al borde de la mesa y el carro con las bandejas, desde donde se trabaja (delante y desde
			# arriba); en una vista estrecha (el teléfono), más lejos para que quepa de lado a lado
			var paw := _paw_world()
			var tray := Vector3(0.6, 0.0, 0.16)
			var target := paw.lerp(tray, 0.5)
			var span := maxf(paw.distance_to(tray), 0.5)
			_rig.min_distance = 0.05
			_rig.set_orbit(target, 12.0 + 40.0 * clampf((paw.z - tray.z) / 1.5, -1.0, 1.0), 50.0, clampf(1.55 * span + 0.35, 1.0, 2.6) / pow(aspect, 0.8), 38.0, instant)
			_rig.set_mask(mask)
		"garra":
			# la garra que se trabaja, de cerca y de lado (su perfil, en tres cuartos hacia la punta, con la cara que se
			# lima): ocupa media vista. En una vista estrecha (el teléfono), más lejos para que quepa de lado a lado.
			var L := float(_v.snap.claw.startMm) if not _v.is_empty() else 40.0
			var dist := clampf(L * GARRA_DIST_K * float(_garra_framing()[1]), GARRA_DIST_MIN, 0.4) / pow(aspect, 0.75)
			_focus_s = -1.0
			# (unidad 5s) de los lados posibles, el primero desde el que las otras garras no tapan esta (el dedo II del águila,
			# con el I y el III delante desde fuera de la pata)
			var d := Vector3.ZERO
			var best := INF
			var cands := _claw_side_dirs()
			for i in cands.size():
				var dc: Vector3 = cands[i]
				var pc := clampf(rad_to_deg(asin(clampf(dc.y, -1.0, 1.0))), 6.0, 70.0)
				var yc := rad_to_deg(atan2(dc.x, dc.z))
				# por debajo de la mesa y del carro, la cámara mira desde el hueco que hay entre ellos (a lo largo del borde):
				# así ni el canto de la mesa ni el carro tapan la garra que cuelga
				dc = _clear_of_furniture(_claw_focus_world(), Vector3(cos(deg_to_rad(pc)) * sin(deg_to_rad(yc)), sin(deg_to_rad(pc)), cos(deg_to_rad(pc)) * cos(deg_to_rad(yc))), dist)
				var sc := _occlusion(dc, dist) + OCCLUSION_ORDER * float(i)
				if sc < best - 1e-9:
					best = sc
					d = dc
			var yaw := rad_to_deg(atan2(d.x, d.z))
			var pitch := rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
			_rig.min_distance = ZOOM_MIN_M
			_rig.set_orbit(_claw_focus_world(), yaw, pitch, dist, GARRA_FOV, instant)
			_rig.set_mask(mask)
		"seccion":
			_upload_section_bands()
			_update_section_camera()
		"animal":
			# el animal entero en el banco o en la mesa, desde delante y desde arriba: a la distancia a la que cabe de lado a
			# lado (su largo, a lo ancho de la vista: el campo horizontal depende del aspecto) y de arriba abajo
			var box: AABB = _paw.get("box", AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 0.4, 1)))
			var off: Vector3 = _paw.get("offset", Vector3.ZERO)
			var c := box.get_center() + off + Vector3(0.15, -0.05, 0.0)
			var pitch := 46.0
			var fov := 40.0
			var half_v := tan(deg_to_rad(fov) * 0.5)
			var tall := box.size.x * sin(deg_to_rad(pitch)) + box.size.y * cos(deg_to_rad(pitch))
			# (vuelta de pulido de la 5s) ajustado, sin el margen de 20 cm de antes: las garras, a su escala (de la pata: la del
			# oso, ~13 cm de ancho y 6-8 cm de garra), se ven algo más grandes (un 10-15 %)
			# en una vista estrecha (el teléfono), más holgado y con el margen de antes (ANIMAL_FIT_NARROW)
			var fit := ANIMAL_FIT if aspect >= 1.0 else ANIMAL_FIT_NARROW
			var dist := maxf(box.size.z * fit / (half_v * minf(aspect, 1.0)), tall * fit / half_v) + (ANIMAL_MARGIN_M if aspect >= 1.0 else 0.2)
			_rig.min_distance = 0.05
			_rig.set_orbit(c, 70.0, pitch, clampf(dist, 0.8, 7.0), fov, instant)
			_rig.set_mask(mask)
	if not _v.is_empty():
		_apply_section(_v)
	# el indicador de la forma, con la garra (no en el animal entero); la silueta sana, fuera del corte
	_gauge.visible = view_name in ["garra", "general", "seccion"]
	_healthy.visible = _ghost_on and view_name != "seccion" and _healthy_mesh.get_surface_count() > 0


## Desde dónde se ve la garra: de lado (su perfil), en tres cuartos hacia la punta y desde algo por encima (GARRA_DIR:
## [hacia la punta, hacia su cara de arriba, de lado], en el marco de la garra a media altura), por el lado de fuera de
## la pata (donde no hay otros dedos que la tapen) y nunca desde debajo del horizonte. Los grandes, más desde arriba y
## desde delante: sus dedos van juntos.
##
## (unidad 5s) Devuelve, por orden de preferencia, ese lado, el otro, los dos algo más de frente (OCCLUSION_FRONT) y una
## vuelta alrededor (OCCLUSION_RING), a su altura y desde más arriba: la vista elige el primero desde el que no la tapan
## otras garras (_occlusion).
func _claw_side_dirs() -> Array:
	var gx := _claw.global_transform
	var b := gx.basis.orthonormalized()
	var apex := float(_v.snap.claw.lengthMm) if not _v.is_empty() else 30.0
	var t := (b * ClawMesh.tangent_at(apex * 0.5, _k)).normalized()
	var up := (b * ClawMesh.up_at(apex * 0.5, _k)).normalized()
	var z := b.z.normalized()
	var kind := String(_paw.get("animal", "rapaz"))
	# de lado: por donde no está la pata más cercana (si no hay otra, hacia fuera de la pata)
	var away := gx.origin - _paw_world()
	var nearest := INF
	var me := String(_v.get("paw", ""))
	var root: Node3D = _paw.get("root")
	for p: String in (_paw.get("paws", {}) as Dictionary):
		if p == me or root == null:
			continue
		var o: Vector3 = root.transform * (_paw.paws[p] as Vector3)
		var dz := absf(o.z - gx.origin.z)
		if dz < nearest:
			nearest = dz
			away = gx.origin - o
	away.y = 0.0
	var score := z.dot(away.normalized() if away.length_squared() > 1e-10 else Vector3.RIGHT) + 0.05 * z.y
	var k: Vector3 = GARRA_DIR.get(kind, GARRA_DIR.rapaz)
	var side := 1.0 if score >= 0.0 else -1.0
	var min_y := sin(deg_to_rad(float(GARRA_MIN_PITCH.get(kind, 14.0))))
	var raw: Array = []
	for c: Vector2 in [Vector2(side, 0.0), Vector2(-side, 0.0), Vector2(side, 1.0), Vector2(-side, 1.0)]:
		var kk := Vector3(k.x + OCCLUSION_FRONT * c.y, k.y, k.z * (1.0 - 0.5 * c.y))
		raw.append((t * kk.x + up * kk.y + z * (kk.z * c.x)).normalized())
	# y, si todas esas las tapan, alrededor (girando en torno a la vertical) y desde más arriba
	for deg: float in OCCLUSION_RING:
		var r := (raw[0] as Vector3).rotated(Vector3.UP, deg_to_rad(deg))
		raw.append(r)
		raw.append((r + Vector3.UP * 0.6).normalized())
	var out: Array = []
	for d: Vector3 in raw:
		if d.y < min_y:
			var h := Vector3(d.x, 0.0, d.z).normalized() if Vector3(d.x, 0.0, d.z).length_squared() > 1e-8 else Vector3.RIGHT
			d = (h * sqrt(1.0 - min_y * min_y) + Vector3.UP * min_y).normalized()
		out.append(d)
	return out


## (unidad 5s) Cuánto tapan las otras garras de las patas (o el tablero de la mesa o del carro) a la que se trabaja vista
## desde target + d·dist: los puntos de su línea media (más peso hacia la punta) cuyo rayo a la cámara pasa por una de las
## otras garras (cada una, unas esferas a lo largo de su línea media, del grueso de su perfil) o por un tablero. 0 = se ve
## entera.
func _occlusion(d: Vector3, dist: float) -> float:
	if _v.is_empty():
		return 0.0
	var cam := _claw_focus_world() + d * dist
	var apex := float(_v.snap.claw.lengthMm)
	var start := float(_v.snap.claw.startMm)
	var base_r := float(_v.snap.claw.baseRadiusMm)
	var gx := _claw.global_transform
	var targets: Array = []
	for f: float in OCCLUSION_SAMPLES:
		targets.append(gx * ClawMesh.point_at(apex * f, _k))
	var spheres: Array = []
	for key: String in _others:
		var mi: MeshInstance3D = _others[key]
		if not mi.is_visible_in_tree():
			continue
		var xf := mi.global_transform
		var sc := xf.basis.get_scale().x
		var ln := float(_slot_len.get(key, start))
		for i in OCCLUSION_STEPS + 1:
			var u := float(i) / float(OCCLUSION_STEPS)
			var q := xf * ClawMesh.point_at(ln * u, _k)
			spheres.append(Vector4(q.x, q.y, q.z, base_r * sc * (1.0 - 0.8 * u)))
	# y la mesa y el carro: el tablero de cada uno (hasta su borde, de OCCLUSION_SLAB_M de grueso bajo su cara de arriba)
	var boards := [AABB(Vector3(-5.0, -OCCLUSION_SLAB_M, -5.0), Vector3(5.0 + TABLE_EDGE_X, OCCLUSION_SLAB_M, 10.0)),
		AABB(Vector3(CART_X0, -OCCLUSION_SLAB_M, -5.0), Vector3(CART_X1 - CART_X0, OCCLUSION_SLAB_M, 10.0))]
	var hidden := 0.0
	for j in targets.size():
		var p: Vector3 = targets[j]
		var seg := cam - p
		var l2 := maxf(seg.length_squared(), 1e-12)
		var blocked := false
		for bx: AABB in boards:
			if not bx.has_point(p) and bx.intersects_segment(p + seg * 0.02, cam) != null:
				blocked = true
		if blocked:
			hidden += 1.0 + float(j) / float(targets.size())
			continue
		for sp: Vector4 in spheres:
			var q := Vector3(sp.x, sp.y, sp.z)
			var t := (q - p).dot(seg) / l2
			if t <= 0.02 or t >= 1.0:
				continue
			if (p + seg * t).distance_to(q) < sp.w:
				hidden += 1.0 + float(j) / float(targets.size())
				break
	return hidden


## La dirección de la cámara (desde target, a dist m) corregida para que, si queda por debajo de lo alto de la mesa y del
## carro, quede en el hueco que hay entre los dos: mira a lo largo del borde, de lado a la garra que cuelga.
static func _clear_of_furniture(target: Vector3, d: Vector3, dist: float) -> Vector3:
	var p := target + d * dist
	if p.y >= FURNITURE_CLEAR_M:
		return d
	var lo := TABLE_EDGE_X + 0.012
	var hi := CART_X0 - 0.012
	if p.x >= lo and p.x <= hi:
		return d
	var dx := clampf((clampf(p.x, lo, hi) - target.x) / dist, -0.95, 0.95)
	var hz := sqrt(maxf(1.0 - d.y * d.y - dx * dx, 0.0))
	var out := Vector3(dx, d.y, (1.0 if d.z >= 0.0 else -1.0) * hz)
	return out.normalized()


## El centro de la pata elegida (m, en el mundo).
func _paw_world() -> Vector3:
	if _paw.is_empty():
		return Vector3.ZERO
	var p := String(_v.get("paw", ""))
	var paws: Dictionary = _paw.get("paws", {})
	var local: Vector3 = paws.get(p, Vector3.ZERO)
	return (_paw.root as Node3D).transform * local


## El punto de la garra al que mira la vista de la garra (GARRA_FOCUS, o el de GARRA_TIP_FRAMING en las rapaces).
func _claw_mid_world() -> Vector3:
	var apex := float(_v.snap.claw.lengthMm) if not _v.is_empty() else 30.0
	return _claw.global_transform * ClawMesh.point_at(apex * float(_garra_framing()[0]), _k)


## Lo que enfoca la cámara en la vista de la garra: el punto de la línea media en _focus_s (el que ha elegido la rueda) o
## en GARRA_FOCUS del largo.
func _claw_focus_world() -> Vector3:
	var apex := float(_v.snap.claw.lengthMm) if not _v.is_empty() else 30.0
	var s := _focus_s if _focus_s >= 0.0 else apex * float(_garra_framing()[0])
	return _claw.global_transform * ClawMesh.point_at(clampf(s, 0.0, apex), _k)


## [lo que se enfoca (fracción del largo), × la distancia] de la vista de la garra del animal de ahora (GARRA_TIP_FRAMING).
## Con una pieza de la reforja que colocar, la de siempre (hay que ver el muñón, cerca de la base).
func _garra_framing() -> Array:
	if not (_v.get("bond", {}) as Dictionary).is_empty():
		return [GARRA_FOCUS, 1.0]
	return GARRA_TIP_FRAMING.get(String(_paw.get("animal", "")), [GARRA_FOCUS, 1.0])


func _update_section_camera() -> void:
	var gx := _claw.global_transform
	var z := gx.basis.z.normalized()
	var start := float(_v.snap.claw.startMm) if not _v.is_empty() else 40.0
	var base_r := float(_v.snap.claw.baseRadiusMm) if not _v.is_empty() else 5.0
	var span := maxf(start, base_r * 4.0) * 1.5 * MM
	var mid := gx * ClawMesh.point_at((float(_v.snap.claw.lengthMm) if not _v.is_empty() else 30.0) * 0.5, _k)
	var up := (gx.basis.y).normalized()
	_rig.set_ortho(mid + z * 0.3, -z, up, span * 1.2, 1 << (SECTION_LAYER - 1))


func _update_camera(dt: float) -> void:
	if view_name == "garra" and not _v.is_empty():
		_rig.follow(_claw_focus_world())
	elif view_name == "seccion":
		_update_section_camera()
	_rig.step(dt)
	# 5t-B: el plano del zarpazo manda en la cámara mientras dura
	_reaction.camera_override(_rig.camera())
	# la luz de tres puntos gira con la cámara; el desenfoque, la niebla y las sombras siguen a su distancia
	var focus_m := _rig.camera().global_position.distance_to(_rig.target) if view_name != "seccion" else 0.3
	_stage.call("frame", _rig.camera(), view_name if view_name != "seccion" else "", focus_m)


## Acerca la cámara con la rueda (f < 1) o la aleja; en la vista de la garra, al acercar con el puntero sobre la garra,
## lo que se enfoca va hacia ese punto (así se llega a la punta al milímetro) y, al alejar, vuelve al de siempre.
func _wheel_zoom(f: float) -> void:
	if view_name == "garra" and not _v.is_empty():
		var apex := float(_v.snap.claw.lengthMm)
		var base := apex * float(_garra_framing()[0])
		var cur := _focus_s if _focus_s >= 0.0 else base
		if f < 1.0 and not _hit.is_empty():
			_focus_s = lerpf(cur, float(_hit.s), ZOOM_FOCUS_PULL)
		elif f > 1.0 and _focus_s >= 0.0:
			_focus_s = lerpf(cur, base, ZOOM_FOCUS_PULL)
	_rig.zoom_by(f)


func _apply_quality() -> void:
	if _stage == null:
		return
	if _reaction != null:
		_reaction.mobile = is_mobile()
		_reaction.lens.set_simple(is_mobile())
	_stage.call("set_quality", _render_method(), is_mobile())
	_apply_vignette()
	var lamp: Variant = _room.get("lamp")
	if lamp != null and is_instance_valid(lamp):
		(lamp as Light3D).visible = not is_mobile()


## La luz de cada sitio (care_stage.gd): el sol de la ventana, el color de las paredes que se reflejan, la penumbra del
## fondo y la sonda de reflexión, centrada en la pata.
func _apply_venue_light(venue: String) -> void:
	_stage.call("set_venue", venue, _paw_world())
	_apply_quality()


## El indicador de la forma, abajo a la izquierda y del tamaño de lo que enseña (encoge al pasar al teléfono).
func _place_gauge() -> void:
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_gauge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gauge.offset_left = 10.0
	_gauge.offset_bottom = -10.0

## Lo que está encendido de la luz y los efectos (para los tests y el informe).
func stage_info() -> Dictionary:
	_ensure_built()
	return _stage.call("info")
