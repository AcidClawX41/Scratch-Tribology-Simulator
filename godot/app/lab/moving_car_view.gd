## Dibujo del coche en marcha (docs/fisica/coche-en-marcha.md §9.6): un turismo en 3D con materiales físicos (pintura
## con barniz, lunas de vidrio de verdad con el interior detrás, cromados, goma, faros) sobre la carretera, con el animal a
## escala, el viento y la animación de la salida o del golpe. Solo pinta lo que le da el estado (core/lab/
## moving_car_state.gd, con sync()); los tamaños y las posiciones salen de MovingCar:
## - el animal en scen.draw.x y scen.draw.y (0-1 sobre la silueta: x desde el morro, y desde el suelo), con su tamaño
##   real (heightM, lengthM y, en las aves, spanM) contra un coche de ~4,5 m (la guía, §9.6), inclinado como su panel
##   (slopeDeg); el morro, a la derecha;
## - el viento (car3d/air_flow.gd, unidad 4k): partículas por las líneas de corriente alrededor del coche, a la velocidad
##   del aire respecto al coche (MovingCarState.air_flow(): la del coche más el viento de cara; el lateral las hace
##   derivar) y, junto a la chapa, a la local de cada zona (v·√(1 − Cp), con el Cp de MovingCar.ZONES); más deprisa, más
##   partículas y estelas más largas. Es una ilustración a la velocidad local del modelo, no una simulación del flujo;
##   la carretera y las ruedas, a la del coche; todo a cámara lenta (×10 más despacio) para que se vea. El ave eriza el
##   plumaje y el mamífero tiembla al acercarse la carga (loadRatio) a 1; las alas abiertas se levantan con la
##   sustentación frente al peso (liftN / weightN); si no aguanta, sale según mode (despega, hacia atrás, hacia delante,
##   por el panel o por el costado) y vuelve cuando vuelve a aguantar. Al animal se le pasa la velocidad del aire donde
##   está (wind_local_ms en la pose, m/s de verdad, y slowmo, la cámara lenta), para que mueva plumas y pelo;
## - el golpe: llega en la dirección de su velocidad respecto al coche (MovingCarState.arrival()) y deja sus daños en el
##   propio material del coche (car3d/car_damage.gd, unidad 4k): la abolladura de dent.depthMm hunde la malla y deforma el
##   reflejo, marks.count surcos de marks.lengthMm y marks.widthUm del color de la capa más honda que cortan (o ranuras y
##   tajos que la atraviesan, con lo de detrás oscuro), los agujeros de puncture.holeUm con sus pétalos, las grietas en
##   estrella y telaraña del parabrisas laminado (windshield.cracked: el PVB lo sujeta) y, quieto encima y asustado, los
##   desgarros de defense.tear; y acaba como dice impact(): se queda, resbala y cae, o sale volando (landing). Los daños
##   se acumulan en el ensayo (hasta DMG_KEEP golpes anteriores, algo desplazados) y se borran al cambiar de ensayo;
## - unidad 4d: el casuario salta y patea con los pies por delante (kick) y rebota; las garras, del color de su material
##   (Data.INLAYS), y sus trozos saltan si se mellan o se parten (clawFracture.mode); asustado, el ave eriza el plumaje,
##   el mamífero tiembla y las garras asoman;
## - unidad 4i-B2: los dos velocirraptores, cada uno con su variante y su tamaño (draw_size()); a un panel de arriba llegan
##   con el final de su salto (la parábola de leap.ux − v y leap.uz con la gravedad, leap_arc) y, contra un costado, con
##   la carrera; las rajas del de cine salen del informe, como todos los daños.
## Capas: detrás, el paisaje del atardecer con paralaje (_draw); en medio, el mundo 3D (car3d/car_scene.gd) en un
## SubViewport transparente con cámara ortográfica de perfil con algo de picado y de giro hacia el morro, con el coche, sus
## daños, el animal y el viento; encima, la lupa (unidad 4k): a su escala real un surco de 0,27 mm o un agujero de 12 mm
## no pasan de un píxel, y un círculo en la esquina de arriba enseña de cerca el daño más fino del último golpe, con la
## misma luz y el mismo material, mirando de frente a la chapa (una segunda cámara que no ve el animal ni el viento, en un
## SubViewport que comparte el mundo; se renderiza solo cuando cambian los daños o mientras crecen), con su aumento y su
## escala; y delante (_overlay), el marco de la lupa, los trozos de las garras, la flecha de la salida con movimiento
## reducido y el rótulo. Lo 2D usa la misma proyección que la cámara (_w2s = CarScene.project).
## Movimiento reducido: sin viento ni ruedas en marcha; la salida, quieta (el animal tenue y una flecha hacia donde se
## va) y el golpe, en su final. Con la escena quieta (coche parado o movimiento reducido) o fuera de la pantalla no se
## redibuja ni se renderiza; toda la geometría (el coche 3D, el animal, el viento) se construye una vez o al cambiar de
## animal, y los daños, al llegar un golpe nuevo: en cada fotograma solo se transforma y se cambian parámetros.
extends Control

## El golpe llega al panel: al pasar la animación por el contacto o, con movimiento reducido, al llegar un golpe nuevo
## (la tarjeta toca entonces su sonido). Mientras se arrastra un deslizador no suena.
signal contact

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const MovingCarState = preload("res://core/lab/moving_car_state.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const CarDamage = preload("res://app/lab/car3d/car_damage.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
## Unidad 4s: el primer plano de las garras (la ventana de la lupa de las garras o la vista entera).
const ClawCloseup = preload("res://app/lab/car3d/claw_closeup.gd")
const Animal3D = preload("res://app/lab/animals/animal3d.gd")
## Unidad 4r: los cuerpos de alta definición de la cetrería, de pie o agazapados en el coche.
const HdAnimal = preload("res://app/lab/animals/hd3d.gd")
## Unidad 4t: la curva (los números, del estado), la carretera en curva con el balanceo y el medidor de fuerza G.
const CarCurve = preload("res://core/lab/car_curve.gd")
const CarCurveGrip = preload("res://core/lab/car_curve_grip.gd")
const RoadCurve = preload("res://app/lab/car3d/road_curve.gd")
const GMeter = preload("res://app/lab/car3d/g_meter.gd")
const RoadMap = preload("res://app/lab/car3d/road_map.gd")

## Turismo del dibujo: ~4,5 m de largo (la guía, §9.6) y 1,45 m hasta las barras del techo (car3d/car_shape.gd). Solo
## para el dibujo: la física no usa la silueta.
const CAR_L := CarShape.CAR_L
const CAR_H := CarShape.CAR_H
const WHEEL_R := CarShape.WHEEL_R
## Lo que se ve alrededor (m): detrás, delante, la carretera y encima (el animal de pie y su vuelo).
const VIEW_BACK := 0.9
const VIEW_FRONT := 0.6
const VIEW_BELOW := 0.25
const VIEW_ABOVE := 1.45
## El viento, la carretera y las ruedas van a cámara lenta: ×10 más despacio que de verdad.
const SLOWMO := 0.1
## Alto de la vista: el 46 % de su ancho, entre estos dos (px). Con la página propia del coche, más grande en el escritorio.
const MIN_H := 150.0
const MAX_H := 440.0
## El golpe en la puerta, los paneles del golpe y la chapa lisa de los desgarros: car3d/car_shape.gd (los puntos de la
## física no se mueven).
const DOOR_DRAW := CarShape.DOOR_DRAW
const PANELS := CarShape.PANELS
const TEAR_ZONES := CarShape.TEAR_ZONES
## Duraciones (s): la salida del animal, su vuelta y las fases del golpe.
const EXIT_S := 1.3
const BACK_S := 0.45
const ARRIVE_S := 0.7
const CRUSH_S := 0.18
const SLIDE_MAX_S := 1.1
const FALL_S := 1.2
## Lo que tardan las alas en abrirse o cerrarse del todo (s).
const WING_S := 0.35
## Lo que tarda en estallar y caer una ventanilla templada (s).
const SHATTER_S := 0.9
## Lo que se ve del animal antes del golpe: los últimos APPROACH_M m de su camino respecto al coche.
const APPROACH_M := 2.2
## Paisaje del fondo: horizonte (m, sobre el suelo en la proyección de la cámara) y el periodo de las colinas (m).
const HORIZON_M := 0.52
const HILLS_PERIOD := 14.0
## Golpes anteriores del mismo ensayo que se quedan en la chapa (además del último), y cuánto se desplaza cada uno en su
## panel (m: a lo largo y a lo ancho) para que no caigan uno encima de otro (dibujo).
const DMG_KEEP := 3
const DMG_SHIFTS := [Vector2(0.0, 0.0), Vector2(-0.09, 0.035), Vector2(0.08, -0.045), Vector2(-0.05, -0.07)]
## La lupa: diámetro (fracción del alto de la vista, entre un mínimo y un máximo, px), su margen y los largos redondos de
## su barra de escala (m).
const LUPA_FRAC := 0.42
const LUPA_MIN := 64.0
const LUPA_MAX := 176.0
const LUPA_MARGIN := 10.0
## Vista estrecha (px): el rótulo, corto.
const NARROW := 480.0
const SCALE_BARS := [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5]
## Unidad 4s · la ventana del primer plano de las garras dentro de la vista del coche: su alto (fracción del de la vista,
## entre un mínimo y un máximo, px), su proporción (ancho/alto) y el alto de vista por debajo del cual no cabe (px). Dibujo.
const CLOSEUP_FRAC := 0.44
const CLOSEUP_MIN_H := 74.0
const CLOSEUP_MAX_H := 196.0
const CLOSEUP_ASPECT := 1.36
const CLOSEUP_MIN_VIEW := 120.0
## Una punta toca el panel si está a menos de esto (m): quieto encima (la chapa curva del techo deja alguna algo
## despegada) y en el golpe. Dibujo.
const CLOSEUP_TOUCH_HOLD := 0.05
const CLOSEUP_TOUCH_HIT := 0.03
## Las garras de la misma pata: a menos de esto de la que se encuadra (m). Dibujo.
const CLOSEUP_PAW_M := 0.07
## Con la vista entera en primer plano, el alto de la vista: el 62 % de su ancho (más alta que la del coche), entre estos dos.
const CLOSEUP_FULL_K := 0.62
const CLOSEUP_FULL_MAX := 520.0
## Giro de las ruedas por fotograma (en vueltas de un radio) desde el que los radios empiezan a emborronarse y desde el que
## ya solo se ve el disco borroso (con más, se vería el efecto estroboscópico).
const BLUR_FROM := 0.04
const BLUR_FULL := 0.3
## Lo que se pinta (sync() lo copia del estado).
var reduce_motion := false
var mode := MovingCarState.MODE_HOLD
var kind := ""
var claw_id := ""
var posture := ""
var animal_col := Color.WHITE
var car_col := Color.WHITE
## Color de las garras: oro (queratina) o el del material reforjado (Data.INLAYS[…].col).
var claw_col := Color.WHITE
var reforged_claws := false
var inlay_id := "none"
var claw_reach_mm := 50.0
var sex := ""
var kicker := false  # el casuario: patea
var leaper := false  # el velocirraptor: ataca saltando (MovingCar.is_leaper)
## Variante del dibujo (draw_size().variant: «pelicula» o «reconstruccion» en el velocirraptor; "" en los demás).
var variant := ""
var scared := false  # asustado, en defensa: plumaje erizado, cuerpo tenso y garras hundidas
## El golpe: qué les pasa a unas garras reforjadas (clawFracture.mode: «mella», «parte», «dobla», «intacta» o "").
var frac_mode := ""
var draw_pos := Vector2(0.55, 0.96)  # draw.x y draw.y del animal quieto encima
var hold_zone := ""  # zona en la que se agarra
var animal_size := Vector3(0.8, 0.85, 0.0)  # alto, largo y envergadura (m)
var slope_deg := 0.0
var v_kmh := 0.0
var air_kmh := 0.0
var local_kmh := 0.0
## El aire respecto al coche (km/h): a lo largo (+ de cara) y de lado (MovingCarState.air_flow()).
var air_along_kmh := 0.0
var air_cross_kmh := 0.0
var load := 0.0
var lift_ratio := 0.0
var holds := true
var exit_mode := ""
var braking := false
var active := false  # hay un animal con datos
## El golpe: el resultado de impact() y lo que hace falta para dibujarlo.
var hit: Dictionary = {}
var hit_zone := ""
var arrival := { "x": -1.0, "z": -1.0, "lateral": 0.0 }
## Calidad del render 3D: «escritorio» o «movil» (sin sombras; lo elige la vista según el dispositivo y el ancho).
var quality := ""
## Métricas: dibujos hechos, geometrías construidas (la escena quieta no se redibuja), daños puestos en el coche y lo que
## tardó el último dibujo en grabar sus órdenes y mover el 3D (µs).
var draws := 0
var builds := 0
var damage_sets := 0
var last_draw_us := 0

var _t := 0.0  # reloj (s)
var _road := 0.0  # recorrido de la carretera (m, a cámara lenta)
var _air := 0.0  # recorrido del aire libre respecto al coche (m, a cámara lenta; negativo si va de atrás adelante)
var _attach := 1.0  # 1 agarrado · 0 ya se ha ido
var _hit_t := -1.0  # tiempo del golpe (s); < 0: sin golpe
var _hit_version := -1
var _wheel_step := 0.0  # giro de las ruedas en el último paso (rad)
var _s := 1.0  # px por m
var _ox := 0.0  # px de x = 0 (la zaga)
var _oy := 0.0  # px de y = 0 (el suelo)
## La parte de arriba del coche en su eje (m): donde se apoya el animal y resbalan las marcas.
var _top := CarShape.top_curve()
## Escala de la carrocería del coche elegido (unidad 4r: el deportivo, draw_scale de su entrada del catálogo; el turismo,
## Vector3.ONE): la silueta (surface_y, draw_to_world, el medio ancho) y el coche 3D van con ella.
var _shape := Vector3.ONE
## Puertas por lado del coche elegido (draw_doors de su entrada del catálogo; 4 sin ella): el deportivo es un cupé.
var _doors := 4
## Colinas del paisaje: alto (m) en HILLS_PERIOD m, lejanas y cercanas.
var _hills_far := PackedFloat32Array()
var _hills_near := PackedFloat32Array()
## El animal 3D (animals/animal3d.gd): su montaje, su clave (especie, postura, tamaño, sexo y calidad), la caché de sus
## texturas (por especie y postura) y la pose que se le pasa en cada fotograma (el mismo diccionario, reutilizado).
var _rig: RefCounted = null
var _rig_key := ""
var _tex_cache := {}
var _pose := {}
## Alas: lo que se abren ahora (0-1) y lo que se quieren abrir (se abren y se cierran en WING_S s: el abanico).
var _wing_open := 0.0
var _wing_want := 0.0
## Las garras en el golpe: lo que queda de ellas (melladas), si se han partido o doblado; la patada del casuario (0-1).
var _claw_len := 1.0
var _claw_gone := false
var _claw_bend := 0.0
var _kick := 0.0
var _key := ""
var _layout_size := Vector2(-1.0, -1.0)
var _animating := false
## El mundo 3D: lo que enseña su render, su SubViewport, la escena, la capa 2D de encima y el lienzo en el que se pinta ahora.
var _container: TextureRect
var _vp: SubViewport
var _scene: Node3D
var _overlay: Control
var _ci: CanvasItem
var _paint_col := Color(-1, -1, -1)
var _style_key := ""
var _style_layers: Array = []
var _style_metal := true
## Unidad 4s: dónde acaba cada capa de la pintura y el panel entero (µm), para el relieve de las marcas (layer_depths_of).
var _layer_to := { "to": Vector4(45.0, 60.0, 85.0, 110.0), "panel": 810.0 }
var _style_id := "coche"
## Las zonas del aire (MovingCarState.air_flow().zones) para construir el viento cuando ya hay escena.
var _air_zones: Array = []
## Los daños del ensayo: su clave, los golpes anteriores (conjuntos de car_damage.gd), el último (y si es definitivo o el de
## un deslizador que se arrastra), los del animal quieto encima, el número del último golpe y si hay que ponerlos.
var _dmg_key := ""
var _dmg_hits: Array = []
var _dmg_cur: Dictionary = {}
var _dmg_cur_final := false
var _dmg_hold: Dictionary = {}
var _dmg_hold_version := -1
## Unidad 4s: las marcas del animal quieto encima a la velocidad del deslizador (MovingCarState.marks_now): su firma (se
## rehacen solo cuando cambian), el ensayo y el contexto de car_damage.gd, y si hay que rehacerlas en el próximo dibujo
## (con las puntas de las garras ya colocadas: cada surco sale de una punta).
var _hold_sig := ""
var _hold_scen: Dictionary = {}
var _hold_ctx: Dictionary = {}
var _hold_dirty := false
## Las puntas de las garras que tocan el panel (m, en el coche), del último dibujo del animal quieto encima.
var _contact_tips: Array = []
## Unidad 4s: cómo quedan las garras del animal quieto encima a la velocidad del deslizador (MovingCarState.marks_frac_mode:
## «intacta», «mella», «parte» o «dobla») y lo que pierden (mm).
var hold_frac := ""
var hold_broken_mm := 0.0
var _dmg_seq := 0
var _dmg_dirty := true
var _dmg_set: Dictionary = {}
var _shatter_seq := -1  # el golpe cuya ventanilla ya ha soltado sus trocitos
## La lupa: el círculo que recorta, su SubViewport y su cámara (se crean la primera vez que hacen falta), lo que enseña
## (CarDamage.lupa: on, focus, field_m, normal), su diámetro (px) y si hay que renderizarla otra vez.
var _lupa: Control = null
var _lupa_vp: SubViewport = null
var _lupa_cam: Camera3D = null
var _lupa_info := { "on": false }
var _lupa_left := false  # en la esquina de la izquierda (golpe en la mitad de delante)
var _lupa_d := 0.0
var _lupa_dirty := false
## Las fases del golpe en este fotograma (_phases): el contacto (m), si es en un costado y su z (m), el tiempo (s), lo
## que va de la abolladura, del resbalón y de la caída (0-1), el sentido (±1) y lo que resbala (m).
var _ph_contact := Vector2.ZERO
var _ph_side := false
var _ph_z := 0.0
var _ph_t := 0.0
var _ph_crush := 0.0
var _ph_slide := 0.0
var _ph_fall := 0.0
var _ph_dir := 1.0
var _ph_slide_m := 0.0
## Unidad 4s · el primer plano de las garras: la vista entera (lo elige la tarjeta) o la ventana dentro de la vista del
## coche; su texto (MovingCarState.closeup_caption), si se ve ahora, si va directo a su sitio (otro ensayo) y la clave del
## ensayo.
var closeup_full := false
## Unidad 4s (segunda ronda): con la vista entera, la marca de cerca (el surco de una garra a unos milímetros) en vez de las
## garras.
var closeup_marks := false
var closeup_lines: Array = ["", ""]
var closeup_cut: Dictionary = {}
var _closeup: ClawCloseup = null
var _closeup_on := false
var _closeup_snap := true
var _closeup_key := ""
var _near_fur_on := false
var _marks_look := false
## Las puntas de las garras del último fotograma (en la raíz del animal) y de qué animal y fotograma son.
var _pts: Array = []
var _pts_frame := -1
var _pts_rig: RefCounted = null
## Unidad 4t: en curva (el estado lo dice con curve_on), la carretera elegida, la curva, la aceleración lateral de ahora
## (g, + a la derecha) y, en la S, su reloj (s de la S de verdad), lo que dura y su carretera (CarCurve.road).
var curve_on := false
var road_id := ""
var lat_g := 0.0
var meter_ctl: GMeter
var map_ctl: RoadMap
var _map_key := ""
var _st: MovingCarState = null
var _curve_k := 0.0
var _s_t := 0.0
var _s_dur := INF
var _s_rd: Dictionary = {}
var _exit_side := 1.0
var _s_pos := 0.0  # metros de la S recorridos (los da el estado con cada instante)
## La vista de persecución en curva (la tarjeta elige: persecución o de lado), la curva que ya tiene la carretera y el
## destello del cambio de lado (1 al cambiar, baja a 0 en FLASH_S) con el lado nuevo.
var chase_pref := true
## El golpe en curva (la carretera y la cámara de la curva, sin medidor) y lo que se separa de la recta el camino del animal
## visto desde el coche (MovingCarState.impact_approach: x hacia delante, y hacia la derecha; de a = 0 a a = 1).
var hit_curve := false
var _approach := PackedVector2Array()
## El mismo camino en sus últimos APPROACH_LONG_M m: el que se dibuja a puntos (de 2,2 m, lo que se tuerce no se ve).
var _approach_long := PackedVector2Array()
const APPROACH_LONG_M := 9.0
var _bend_key := ""
var flash := 0.0
var flash_side := 0.0
const FLASH_S := 1.1
var _twist_deg := 0.0  # hacia dónde están torcidos los desgarros del animal quieto encima (grados desde «hacia atrás»)


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	accessibility_name = "Dibujo del coche en marcha con el animal a escala"
	resized.connect(_on_resized)
	# unidad 4s: el render 3D se enseña con un TextureRect y el SubViewport va a los píxeles de verdad de la pantalla
	# (ClawCloseup.render_size: ×2-×3 en un teléfono); con un SubViewportContainer se dibujaba a los píxeles de la interfaz y
	# la ventana lo ampliaba (el animal pixelado en el teléfono, que anotó la 4r)
	_vp = SubViewport.new()
	_vp.name = "Render3D"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.audio_listener_enable_3d = false
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_container = TextureRect.new()
	_container.name = "Imagen3D"
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_container.stretch_mode = TextureRect.STRETCH_SCALE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.texture = _vp.get_texture()
	add_child(_container)
	_overlay = Control.new()
	_overlay.name = "Encima"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_ci = _overlay
	meter_ctl = GMeter.new()  # unidad 4t: encima del 3D, en una esquina de arriba
	meter_ctl.visible = false
	add_child(meter_ctl)
	map_ctl = RoadMap.new()
	map_ctl.visible = false
	add_child(map_ctl)
	_hills_far = _hills(0.30, 3, "lejos")
	_hills_near = _hills(0.20, 5, "cerca")


func _on_resized() -> void:
	var want := clampf(size.x * 0.46, MIN_H, MAX_H)
	if closeup_full:
		want = clampf(size.x * CLOSEUP_FULL_K, MIN_H, maxf(MAX_H, CLOSEUP_FULL_MAX))
	want = _curve_min_h(want)  # unidad 4t: en un teléfono, en curva, más alta
	if absf(custom_minimum_size.y - want) > 1.0:
		custom_minimum_size.y = want
	_redraw()


## Colinas deterministas: alto (m) en 64 muestras a lo largo de HILLS_PERIOD (la suma de unos senos).
static func _hills(amp: float, waves: int, seed_text: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ph := float(seed_text.hash() % 997) / 997.0 * TAU
	for i in 64:
		var u := TAU * float(i) / 64.0
		var h := 0.0
		for k in waves:
			h += sin(u * float(k + 1) + ph * float(k + 1)) / float(k + 1)
		out.append(amp * (0.55 + 0.35 * h / 1.6))
	return out


# ════════ Lo que llega del estado ════════

## Copia del estado lo que se pinta. Un golpe nuevo (hit_version) se anima desde el principio, salvo si replay es false
## (mientras se arrastra un deslizador) o con movimiento reducido: entonces se enseña su final.
func sync(st: MovingCarState, replay := true) -> void:
	var hold_ok := Js.truthy(st.scen.get("ok"))
	mode = st.mode
	active = st.supported() and (hold_ok or mode == MovingCarState.MODE_IMPACT)
	car_col = Palette.color(String(st.target.col))
	_sync_style(st)
	if _air_zones.is_empty():
		_air_zones = st.air_flow().zones
	if _scene != null:
		_scene.build_wind(_air_zones)  # una vez (si la escena llegó antes que el estado)
	if not active:
		_dmg_reset("")
		_apply_paint()
		_build_animal()
		_redraw()
		return
	kind = st.kind()
	claw_id = st.claw.id
	posture = st.posture
	animal_col = Palette.color(String(st.claw.col))
	reforged_claws = st.reforged()
	inlay_id = st.inlay
	claw_reach_mm = float(st.claw.get("reach", 50.0))
	sex = st.sex
	claw_col = Palette.color(String(st.inlay_entry().col)) if reforged_claws else Palette.color("gold")
	kicker = st.is_kicker()
	leaper = st.is_leaper()
	scared = st.defense
	var size: Dictionary = st.draw_size()
	animal_size = Vector3(size.heightM, size.lengthM, size.spanM)
	variant = String(size.get("variant", ""))
	hold_zone = st.zone
	braking = st.accel_g < 0.0
	if hold_ok:
		var d: Dictionary = st.scen.draw
		draw_pos = Vector2(d.x, d.y)
		slope_deg = st.scen.slopeDeg
	var a: Dictionary = st.at
	if not a.is_empty():
		v_kmh = a.vKmh
		air_kmh = a.airKmh
		local_kmh = a.localKmh
		load = a.loadRatio if is_finite(a.loadRatio) else 2.0
		lift_ratio = float(a.liftN) / float(a.weightN) if float(a.weightN) > 0.0 else 0.0
		holds = a.holds
		if not holds:
			exit_mode = a.mode
	_sync_curve(st)  # unidad 4t
	_sync_grip(st)  # unidad 4u
	var air: Dictionary = st.air_flow()
	air_along_kmh = air.alongKmh
	air_cross_kmh = air.crossKmh
	var key := "%s|%s|%s|%s|%s|%s|%s" % [claw_id, posture, mode, st.zone, st.impact_zone, st.target.id, st.sex]
	if key != _key:
		_key = key
		_attach = 1.0  # otro animal u otra zona: empieza agarrado (y, si no aguanta, se le ve irse)
		_layout_size = Vector2(-1.0, -1.0)
	closeup_lines = st.closeup_caption()
	closeup_cut = st.tear_now()  # unidad 4s: el corte de la chapa en el primer plano
	var ck := "%s|%s|%s" % [key, st.inlay, st.hit_version if mode == MovingCarState.MODE_IMPACT else 0]
	if ck != _closeup_key:
		_closeup_key = ck
		_closeup_snap = true  # otro ensayo u otro golpe: el primer plano va directo a su sitio
	# los daños se acumulan en el mismo ensayo y se borran al cambiar de ensayo
	_dmg_reset("%s|%s|%s|%s" % [key, st.inlay, st.defense, mode])
	if mode == MovingCarState.MODE_IMPACT and Js.truthy(st.hit.get("ok")):
		hit = st.hit
		hit_zone = st.impact_zone
		arrival = st.arrival()
		var frac: Variant = st.hit.get("clawFracture")
		frac_mode = String(frac.mode) if frac != null else ""
		v_kmh = st.v_kmh
		if st.hit_version != _hit_version:
			_hit_version = st.hit_version
			_hit_t = 0.0 if (replay and not reduce_motion) else 1.0e6
			_dmg_new_hit(st, replay)
			if replay and reduce_motion:
				contact.emit()
	elif mode == MovingCarState.MODE_IMPACT:
		hit = {}
	if mode == MovingCarState.MODE_HOLD:
		# unidad 4s: las marcas a la velocidad del deslizador; se rehacen cuando cambian (en el próximo dibujo, con las
		# puntas de las garras), no en cada fotograma
		var now: Dictionary = st.marks_now()
		hold_frac = st.marks_frac_mode()
		hold_broken_mm = st.marks_broken_mm()
		var sig := hold_marks_sig(now) + "|%s" % Js.to_fixed(float(closeup_cut.get("lengthMm", 0.0)), 0)
		if st.setup_version != _dmg_hold_version or sig != _hold_sig:
			_dmg_hold_version = st.setup_version
			_hold_sig = sig
			_hold_scen = st.scen
			_hold_ctx = _dmg_ctx(st, hold_zone, 0, Vector2.ZERO)
			_hold_ctx["speed"] = now
			# unidad 4s (petición del 17-10): si la raja corre (el viento puede con las garras que atraviesan la chapa), los
			# surcos miden lo que corre (CarTear)
			_hold_ctx["tear_mm"] = float(closeup_cut.get("lengthMm", 0.0)) if String(closeup_cut.get("id", "")) in ["raja", "abre"] else 0.0
			_hold_dirty = true
			if _rig == null or _scene == null:
				_dmg_hold = _twisted(CarDamage.from_hold(_hold_scen, _hold_ctx))
				_dmg_dirty = true
	_twist_hold_marks(st)  # unidad 4t
	_sync_glass(st)  # unidad 4v
	_apply_paint()
	_apply_damage()
	_build_animal()
	_redraw()


## Aspecto de la carrocería del coche elegido (car3d/car_model.gd STYLES) y los colores de sus capas de pintura (las de
## Catalog.car_layers: del barniz a la carrocería).
func _sync_style(st: MovingCarState) -> void:
	var tid := String(st.target.id)
	if tid == _style_key:
		return
	_style_key = tid
	_style_id = tid
	var shape := shape_of(st.target)
	var n_doors := int((st.target as Dictionary).get("draw_doors", 4))
	if not shape.is_equal_approx(_shape) or n_doors != _doors:
		_shape = shape
		_doors = n_doors
		_top = CarShape.scaled_top(_shape)
		if _scene != null:
			_scene.rebuild_car(_paint_col, _shape, _air_zones, _doors)
			_scene.car.set_style(_style_id, _style_layers, _style_metal)
			_scene.car.set_layer_depths(_layer_to.to, _layer_to.panel)
			_dmg_dirty = true
	_style_layers = []
	var layers: Variant = Catalog.car_layers(st.target)
	if layers != null:
		for l: Dictionary in layers:
			_style_layers.append(Palette.color(String(l.col)))
	_style_metal = st.target.get("body") == null or bool(st.target.body.get("metal", true))
	_layer_to = layer_depths_of(layers)
	_paint_col = Color(-1, -1, -1)
	if _scene != null:
		_scene.car.set_style(_style_id, _style_layers, _style_metal)
		_scene.car.set_layer_depths(_layer_to.to, _layer_to.panel)


## Dónde acaba cada capa de la pintura (µm: barniz, color, imprimación y anticorrosivo o promotor) y el panel entero (µm), de
## las capas de un coche (Catalog.car_layers: from y to de cada una, la carrocería la última).
static func layer_depths_of(layers: Variant) -> Dictionary:
	var to := Vector4(45.0, 60.0, 85.0, 110.0)
	var panel := 810.0
	if layers is Array and (layers as Array).size() >= 5:
		var L: Array = layers
		to = Vector4(float(L[0].to), float(L[1].to), float(L[2].to), float(L[3].to))
		panel = float(L[-1].to)
	return { "to": to, "panel": panel }


## Color de la pintura del coche 3D: el del coche elegido o, sin animal con datos, un gris neutro.
func _apply_paint() -> void:
	var c := car_col if active else Palette.color("panel3")
	if c != _paint_col and _scene != null:
		_paint_col = c
		_scene.car.set_paint(c)
		_scene.car.set_style(_style_id, _style_layers, _style_metal)
		_scene.set_ground_paint(c)  # unidad 4w: las garras reflejan la pintura que pisan
		_relight()


# ── Los daños ──

## Borra los daños si el ensayo es otro (key).
func _dmg_reset(key: String) -> void:
	if key == _dmg_key:
		return
	_dmg_key = key
	_dmg_hits.clear()
	_dmg_cur = {}
	_dmg_cur_final = false
	_dmg_hold = {}
	_dmg_hold_version = -1
	_dmg_dirty = true


## Lo que car_damage.gd necesita saber del ensayo: la zona y su punto (zone_draw), el coche, el animal (tipo, tamaño, garras
## que tocan y el radio de su apoyo, de MovingCar.BODIES), hacia dónde resbala y el desplazamiento de este golpe en el panel.
func _dmg_ctx(st: MovingCarState, zone: String, seq: int, shift: Vector2) -> Dictionary:
	var body: Variant = MovingCar.BODIES.get(st.claw.id) if st.claw != null else null
	var zd: Variant = zone_draw(zone)
	var iz: Variant = MovingCar.IMPACT_ZONES.get(zone)
	var feet := Vector3.ZERO
	if zd != null:
		var w := car_point(Vector2(zd.x, zd.y))
		var side := CarDamage.side_zone(zone)
		feet = Vector3(w.x, w.y if side else surface_y(w.x), half_w() if side else zone_z(zone))
	return { "zone": zone, "draw": zd, "target": st.target, "kind": st.kind(), "kicker": st.is_kicker(),
		"size": animal_size, "claws": int(body.get("contact", 4)) if body != null else 4,
		"contact_mm": float(body.get("contact_mm", CarDamage.DEFAULT_CONTACT_MM)) if body != null else CarDamage.DEFAULT_CONTACT_MM,
		"dir": 1.0 if float(st.arrival().x) > 0.0 else -1.0, "hit": seq, "shift": shift, "top": _top, "claw_id": st.claw.id if st.claw != null else "",
		"glass": glass_zone(zone), "feet": feet }  # unidad 4v: también los cristales donde se agarra (la luneta)


## Un golpe nuevo: el definitivo (replay) se queda en la chapa y el anterior definitivo pasa a la lista de los que se
## acumulan; el de un deslizador que se arrastra sustituye al último sin acumularse.
func _dmg_new_hit(st: MovingCarState, replay: bool) -> void:
	if replay:
		if not _dmg_cur.is_empty() and _dmg_cur_final:
			_dmg_hits.append(_dmg_cur)
			while _dmg_hits.size() > DMG_KEEP:
				_dmg_hits.pop_front()
		_dmg_seq += 1
	elif _dmg_seq == 0:
		_dmg_seq = 1
	var shift: Vector2 = DMG_SHIFTS[_dmg_hits.size() % DMG_SHIFTS.size()]
	_dmg_cur = CarDamage.from_hit(st.hit, _dmg_ctx(st, st.impact_zone, _dmg_seq, shift))
	_dmg_cur_final = replay
	_dmg_dirty = true


## Firma de las marcas a una velocidad (CarSpeedMarks.at): cambian si cambia la hondura (de 0,5 en 0,5 µm), el ancho, la
## punta clavada, si raja o atraviesa el panel, o si las garras se rompen.
static func hold_marks_sig(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	return "%d|%d|%d|%s|%s|%s|%s" % [roundi(float(m.depthUm) * 2.0), roundi(float(m.widthUm)), roundi(float(m.punctUm) * 2.0),
		Js.truthy(m.through), Js.truthy(m.punctThrough), Js.truthy(m.broken), String(m.get("fracMode", ""))]


## Las puntas de las garras que tocan el panel ahora (m, en el coche, sobre la chapa): las n más cercanas a la chapa de la
## zona en la que se agarra (de claw_points() del animal, con su pose de este fotograma). [] sin animal.
func contact_tips(n: int) -> Array:
	var side := CarDamage.side_zone(hold_zone)
	var pts := _gripping(tips_by_gap(hold_zone))
	var out: Array = []
	for e: Array in pts.slice(0, maxi(n, 0)):
		var w: Vector3 = e[1]
		if side:
			w.z = half_w()
		else:
			w.y = surface_y(w.x)
		out.append(w)
	return out


## Unidad 4s (petición del 17-10: las marcas de cada animal, con sus garras): de las puntas [[hueco, punta]], las de las garras
## que agarran según MovingCar.BODIES (contact y su fuente): el tigre y el oso, las de las dos manos (4 + 4 y 5 + 5); una
## rapaz, las de un pie (3 + 1: el pie con las garras más cerca de la chapa); el velocirraptor, las de los dedos III y IV de
## los dos pies (la falciforme va levantada, Li et al. 2008). Sin esos datos (los modelos de la 4l), todas.
func _gripping(pts: Array) -> Array:
	if _rig == null or not _rig.has_method("claw_tags") or pts.is_empty():
		return pts
	var tags: Array = _rig.call("claw_tags")
	var raw: Array = _claw_points_now()
	if tags.size() != raw.size():
		return pts
	var root: Node3D = _rig.get("root")
	var keep := {}
	match kind:
		"mamifero":
			for i in tags.size():
				if String(tags[i][0]).begins_with("delantera"):
					keep[i] = true
		"teropodo":
			for i in tags.size():
				if String(tags[i][1]) in ["III", "IV"]:
					keep[i] = true
		"ave":
			# el pie más cerca de la chapa
			var gap := {}
			for i in tags.size():
				var w := root.transform * (raw[i] as Vector3)
				gap[tags[i][0]] = minf(float(gap.get(tags[i][0], INF)), absf(w.y - CarDamage.surf_y(_top, w.x)))
			var foot := ""
			for f: String in gap:
				if foot == "" or float(gap[f]) < float(gap[foot]):
					foot = f
			for i in tags.size():
				if String(tags[i][0]) == foot:
					keep[i] = true
	if keep.is_empty():
		return pts
	var out: Array = []
	for i in raw.size():
		if keep.has(i):
			var w := root.transform * (raw[i] as Vector3)
			for e: Array in pts:
				if (e[1] as Vector3).is_equal_approx(w):
					out.append(e)
					break
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out if not out.is_empty() else pts


## Las puntas de las garras del animal ahora (m, en el coche) con lo que las separa de la chapa de una zona (m), de la más
## cercana a la más lejana: [[hueco, punta]]. [] sin animal.
func tips_by_gap(zone: String) -> Array:
	if _rig == null or not _rig.has_method("claw_points"):
		return []
	var root: Node3D = _rig.get("root")
	if not root.visible:
		return []
	var side := CarDamage.side_zone(zone)
	var pts: Array = []
	for q: Vector3 in _claw_points_now():
		var w := root.transform * q
		var gap := (half_w() - w.z) if side else (w.y - CarDamage.surf_y(_top, w.x))
		pts.append([absf(gap), w])
	pts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return pts


## Las puntas de las garras en la raíz del animal (claw_points), una vez por fotograma y pose (las piden el apoyo en la chapa,
## las marcas y el primer plano).
func _claw_points_now() -> Array:
	var f := Engine.get_process_frames()
	if f != _pts_frame or _rig != _pts_rig:
		_pts_frame = f
		_pts_rig = _rig
		_pts = _rig.call("claw_points")
	return _pts


## Las puntas de las garras están en la chapa si la más cercana queda a menos de esto (m). Dibujo.
const HOLD_TIPS_MAX_GAP := 0.1


## Rehace las marcas del animal quieto encima con las puntas de sus garras (las del dibujo de ahora).
func _rebuild_hold_marks() -> void:
	# las puntas tienen que estar ya en la chapa (el animal colocado y a la vista): si no, se espera al próximo dibujo (con
	# las de su peso o sin puntas mientras tanto, para que no quede sin marcas)
	var near := tips_by_gap(hold_zone)
	if _rig != null and (near.is_empty() or float(near[0][0]) > HOLD_TIPS_MAX_GAP):
		if _dmg_hold.is_empty():
			_dmg_hold = _twisted(CarDamage.from_hold(_hold_scen, _hold_ctx))
			_dmg_dirty = true
			_apply_damage()
		return
	_hold_dirty = false
	_contact_tips = contact_tips(int(_hold_ctx.get("claws", 4)))
	_hold_ctx["tips"] = _contact_tips
	_dmg_hold = _twisted(CarDamage.from_hold(_hold_scen, _hold_ctx))
	_dmg_dirty = true
	_apply_damage()


## Pone en el coche los daños del ensayo (solo si han cambiado: nunca en cada fotograma).
func _apply_damage() -> void:
	if not _dmg_dirty or _scene == null:
		return
	_dmg_dirty = false
	var all := CarDamage.empty()
	for h: Dictionary in _dmg_hits:
		all = CarDamage.merge(all, h)
	if not _dmg_cur.is_empty():
		all = CarDamage.merge(all, _dmg_cur)
	if not _dmg_hold.is_empty() and mode == MovingCarState.MODE_HOLD:
		all = CarDamage.merge(all, _dmg_hold)
	if not _dmg_grip.is_empty() and mode == MovingCarState.MODE_HOLD:
		all = CarDamage.merge(all, _dmg_grip)  # unidad 4u: los resbalones y la caída en curva
	_dmg_set = all
	_scene.car.set_damage(all)
	_glass_after_damage()  # unidad 4v: la luneta que estalla se anima
	_scene.car.set_damage_progress(-1, 1.0, 1.0)
	damage_sets += 1
	_update_lupa()


## Los daños que se ven ahora (para las pruebas: el último conjunto puesto en el coche).
func damage() -> Dictionary:
	return _dmg_set


## La lupa: la crea la primera vez (un círculo que recorta lo de dentro, con un SubViewport que comparte el mundo 3D y
## una cámara ortográfica que no ve el animal ni el viento).
func _ensure_lupa() -> void:
	if _lupa != null or _scene == null:
		return
	_lupa = Control.new()
	_lupa.name = "Lupa"
	_lupa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lupa.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_lupa.draw.connect(func() -> void: _lupa.draw_circle(_lupa.size * 0.5, _lupa.size.x * 0.5, Color.WHITE, true, -1.0, true))
	var cont := TextureRect.new()
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cont.stretch_mode = TextureRect.STRETCH_SCALE
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lupa_vp = SubViewport.new()
	_lupa_vp.transparent_bg = true
	_lupa_vp.audio_listener_enable_3d = false
	_lupa_vp.handle_input_locally = false
	_lupa_vp.gui_disable_input = true
	_lupa_vp.msaa_3d = _vp.msaa_3d
	_lupa_vp.scaling_3d_scale = _vp.scaling_3d_scale
	_lupa_vp.world_3d = _vp.find_world_3d()
	_lupa_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_lupa_cam = Camera3D.new()
	_lupa_cam.name = "CamaraLupa"
	_lupa_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_lupa_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_lupa_cam.near = 0.05
	_lupa_cam.far = CarScene.CAM_DIST * 2.5
	_lupa_cam.cull_mask = CarScene.ALL_LAYERS & ~CarScene.ANIMAL_LAYER & ~CarScene.CLAW_LAYER & ~CarScene.AirFlow.WIND_LAYER
	_lupa_vp.add_child(_lupa_cam)
	_lupa_cam.current = true
	_lupa.add_child(_lupa_vp)
	cont.texture = _lupa_vp.get_texture()
	_lupa.add_child(cont)
	add_child(_lupa)
	move_child(_lupa, _overlay.get_index())


## La lupa enseña el daño más fino del último golpe (CarDamage.lupa) mirando de frente a la chapa: la cámara a lo largo de
## la normal del panel, con la x del coche hacia la derecha; o se esconde si no hay daño que ver.
func _update_lupa() -> void:
	_lupa_info = CarDamage.lupa(_dmg_set, _top) if active and _scene != null else { "on": false }
	if not bool(_lupa_info.on):
		if _lupa != null:
			_lupa.visible = false
		return
	_ensure_lupa()
	_lupa_d = clampf(size.y * LUPA_FRAC, LUPA_MIN, LUPA_MAX)
	# en la esquina de arriba del lado contrario al golpe: el animal está donde golpea (y su cabeza, hacia el morro)
	_lupa_left = float((_lupa_info.focus as Vector3).x) > CAR_L * 0.5
	_lupa.position = Vector2(LUPA_MARGIN if _lupa_left else size.x - _lupa_d - LUPA_MARGIN, LUPA_MARGIN)
	_lupa.size = Vector2(_lupa_d, _lupa_d)
	_lupa_vp.size = ClawCloseup.render_size(_lupa.size, ClawCloseup.pixel_scale(self))
	_lupa.visible = not chasing()  # unidad 4u: en persecución no sale ni un fotograma (los surcos de la S llegan en marcha)
	_lupa.queue_redraw()
	var n: Vector3 = (_lupa_info.normal as Vector3).normalized()
	var right := (Vector3.RIGHT - n * Vector3.RIGHT.dot(n)).normalized()
	var up := n.cross(right).normalized()
	_lupa_cam.basis = Basis(right, up, n)
	_lupa_cam.size = float(_lupa_info.field_m)
	_lupa_cam.position = (_lupa_info.focus as Vector3) + n * 2.0
	_lupa_dirty = true
	if curve_on:
		_layout_meter()  # unidad 4t: el medidor y el plano, en la esquina que deja la lupa


# ── Unidad 4s: el primer plano de las garras ──

## La vista entera en primer plano de las garras (on) o el coche entero con la ventana de las garras (lo elige la tarjeta).
## Con el primer plano, la vista es más alta (CLOSEUP_FULL_K).
func set_closeup_full(on: bool, marks := false) -> void:
	if on == closeup_full and marks == closeup_marks:
		return
	closeup_full = on
	closeup_marks = marks and on
	_closeup_snap = true
	_on_resized()
	_redraw()


## El primer plano: lo crea la primera vez que hace falta (comparte el mundo 3D; no ve el viento).
func _ensure_closeup() -> void:
	if _closeup != null or _scene == null:
		return
	_closeup = ClawCloseup.new()
	_closeup.visible = false
	add_child(_closeup)
	move_child(_closeup, _overlay.get_index())
	_closeup.setup(_vp.find_world_3d(), _vp.msaa_3d, CarScene.ALL_LAYERS & ~CarScene.AirFlow.WIND_LAYER)


## Unidad 4s: el pelo de cerca (hd3d.set_near_fur) con el primer plano en toda la vista; el de lejos, si no. Y, con la marca
## de cerca, el cuerpo oculto tampoco hace sombra (oscurecía el surco que pasa bajo la pata) y los labios de los surcos se
## exageran (LIP_BOOST: dibujo).
const LIP_BOOST := 4.0


func _sync_near_fur() -> void:
	var marks_on := closeup_full_on() and closeup_marks
	if marks_on != _marks_look and _scene != null:
		_marks_look = marks_on
		_scene.car.set_lip_boost(LIP_BOOST if marks_on else 1.0)
		_body_shadows(not marks_on)
	var want := closeup_full_on()
	if want == _near_fur_on or _rig == null or not _rig.has_method("set_near_fur"):
		return
	_near_fur_on = want
	_rig.call("set_near_fur", want)


## Las sombras del cuerpo del animal (no las de sus garras: capa CLAW_LAYER).
func _body_shadows(on: bool) -> void:
	if _rig == null:
		return
	var root: Node3D = _rig.get("root")
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.layers & CarScene.CLAW_LAYER != 0:
			continue
		if not on:
			if not g.has_meta("sombra_4s"):
				g.set_meta("sombra_4s", g.cast_shadow)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif g.has_meta("sombra_4s"):
			g.cast_shadow = g.get_meta("sombra_4s")
			g.remove_meta("sombra_4s")


## ¿Se ve ahora el primer plano en la vista entera?
func closeup_full_on() -> bool:
	return closeup_full and _closeup_on


## El primer plano de este fotograma: a qué apunta (las garras que tocan o, si aún no tocan, el daño), dónde va (la vista
## entera o la ventana) y su texto. Se esconde sin animal, sin nada que enseñar o si la vista es demasiado baja.
func _update_closeup() -> void:
	var aim := _closeup_aim() if active and _scene != null else {}
	# en una vista estrecha en curva no cabe la ventana con el medidor, el mapa y la lupa: «Garras de cerca» la enseña entera
	var want := not aim.is_empty() and (closeup_full or (size.y >= CLOSEUP_MIN_VIEW and not (curve_on and size.x < NARROW)))
	if not want:
		if _closeup != null and _closeup.visible:
			_closeup.visible = false
			_closeup.stop()
		if _closeup_on:
			_closeup_on = false
			queue_redraw()
			_sync_near_fur()
		return
	_ensure_closeup()
	var was := _closeup_on
	_closeup_on = true
	var rect := Rect2(Vector2.ZERO, size) if closeup_full else closeup_rect()
	_closeup.visible = true
	# en la vista entera, por encima de todo (también del medidor y del mapa de la curva); la ventana, bajo la capa 2D
	var want_idx := get_child_count() - 1 if closeup_full else _overlay.get_index() - (1 if _closeup.get_index() < _overlay.get_index() else 0)
	if _closeup.get_index() != want_idx:
		move_child(_closeup, want_idx)
	_closeup.place(rect, closeup_full)
	_closeup.aim(aim.focus, aim.normal, CarScene.view_basis().z, float(aim.field), _closeup_snap or not was or reduce_motion, float(aim.cam),
		float(aim.below), bool(aim.side), float(aim.get("elev", -1.0)), float(aim.get("field_min", ClawCloseup.FIELD_MIN)))
	_closeup_snap = false
	var zoom := (minf(rect.size.x, rect.size.y) / maxf(_closeup.field_m, 1e-6)) / maxf(_s, 1e-6)
	# en el golpe, el cuerpo se le pone delante a la cámara: el primer plano ve solo las garras (y lo dice)
	# (y en la marca de cerca: el cuerpo taparía el surco que pasa por debajo de la pata)
	var xray := mode == MovingCarState.MODE_IMPACT or (closeup_full and closeup_marks)
	_closeup.set_cull(CarScene.ALL_LAYERS & ~CarScene.AirFlow.WIND_LAYER & ~(CarScene.ANIMAL_LAYER if xray else 0))
	_closeup.set_text(closeup_lines, "×%s%s" % [Js.to_fixed(zoom, 0), " · sin el cuerpo" if xray else ""])
	_closeup.set_cut(closeup_cut)
	_sync_near_fur()
	if not was:
		queue_redraw()


## Dónde va la ventana del primer plano (px): arriba, en la esquina contraria a la lupa del daño; en una vista estrecha
## ocupa la esquina de la lupa (que entonces se esconde: no caben las dos); en curva, abajo a la derecha.
func closeup_rect() -> Rect2:
	var h := clampf(size.y * CLOSEUP_FRAC, CLOSEUP_MIN_H, CLOSEUP_MAX_H)
	var w := minf(h * CLOSEUP_ASPECT, size.x * 0.5 - LUPA_MARGIN * 1.5)
	if curve_on:
		# en curva, arriba van el medidor de fuerza G y el mapa de la carretera (unidad 4t): la ventana, abajo a la derecha,
		# sobre la carretera (el rótulo va a la izquierda)
		return Rect2(Vector2(size.x - w - LUPA_MARGIN, size.y - h - LUPA_MARGIN - 4.0), Vector2(w, h))
	var lupa_on := bool(_lupa_info.get("on", false))
	var right := not _lupa_left if size.x < NARROW else (lupa_on and _lupa_left)
	return Rect2(Vector2(size.x - w - LUPA_MARGIN if right else LUPA_MARGIN, LUPA_MARGIN), Vector2(w, h))


## ¿Esconde el primer plano la lupa del daño? (en la vista entera o en una vista estrecha)
func closeup_hides_lupa() -> bool:
	return _closeup_on and (closeup_full or (size.x < NARROW and not curve_on))


## A qué apunta el primer plano: { focus (m, en el coche), normal (la del panel), field (m, lo que se ve en el lado corto:
## FIELD_K veces el largo de la garra del catálogo), dir (±1: hacia dónde van los surcos a lo largo del coche), cam (±1:
## de qué lado mira la cámara: quieto encima, desde delante, porque las garras salen por delante de los dedos y el dedo
## taparía la garra desde atrás; en el golpe, desde donde van los surcos, que se ven delante de la garra), below (lo que
## está el foco por debajo de la chapa sin abollar, m) y side (un costado) } o {} si no hay nada que enseñar.
## Quieto encima, las garras que tocan el panel: la de la pata más cercana a quien mira (y la más adelantada) con las de su
## pata. En el golpe, el daño (la lupa) o, mientras llega, el punto del golpe: las marcas van donde dice el motor y las
## garras del dibujo del salto pueden caer en otra parte de la chapa.
func _closeup_aim() -> Dictionary:
	var hold := mode == MovingCarState.MODE_HOLD
	var zone := hold_zone if hold else hit_zone
	if zone == "" or (not hold and hit.is_empty()):
		return {}
	var side := CarDamage.side_zone(zone)
	var axis := CarDamage.AXIS_SIDE if side else CarDamage.AXIS_TOP
	var reach := claw_reach_mm / 1000.0
	var field := reach * ClawCloseup.FIELD_K
	var dir := -1.0 if hold else _ph_dir
	var near := tips_by_gap(zone)
	var touch := CLOSEUP_TOUCH_HOLD if hold else CLOSEUP_TOUCH_HIT
	var on: Array = near.filter(func(e: Array) -> bool: return float(e[0]) < touch)
	if hold and not _contact_tips.is_empty() and not on.is_empty():
		# quieto encima, las garras que dejan las marcas (las de _rebuild_hold_marks), para que el surco salga de la garra que
		# se ve; con la pose de ahora (la más cercana de cada una)
		var marked: Array = []
		for t: Vector3 in _contact_tips:
			var best_e: Array = on[0]
			for e: Array in on:
				if Vector2((e[1] as Vector3).x, (e[1] as Vector3).z).distance_to(Vector2(t.x, t.z)) < Vector2((best_e[1] as Vector3).x, (best_e[1] as Vector3).z).distance_to(Vector2(t.x, t.z)):
					best_e = e
			if Vector2((best_e[1] as Vector3).x, (best_e[1] as Vector3).z).distance_to(Vector2(t.x, t.z)) < 0.03:
				marked.append(best_e)
		if not marked.is_empty():
			on = marked
	# en el golpe, las marcas van donde dice el motor (car_damage.gd: el punto del golpe) y las garras del dibujo del salto
	# pueden caer en otra parte de la chapa (los pies que rozan el estribo): el primer plano enseña el daño
	var attached := _attach >= 1.0 if hold else false
	var focus := Vector3.INF
	if not on.is_empty() and attached:
		# la garra que se encuadra: la más cercana a quien mira (z) y, entre las de esa pata, la más adelantada (x)
		var best: Vector3 = on[0][1]
		var score := func(w: Vector3) -> float: return w.z * 3.0 + w.x
		for e: Array in on:
			var w: Vector3 = e[1]
			if float(score.call(w)) > float(score.call(best)):
				best = w
		var sum := Vector3.ZERO
		var n := 0
		for e: Array in on:
			var w: Vector3 = e[1]
			if w.distance_to(best) < CLOSEUP_PAW_M:
				sum += w
				n += 1
		focus = sum / float(maxi(n, 1))
	elif bool(_lupa_info.get("on", false)):
		focus = _lupa_info.focus
	elif not hold:
		var c := _impact_point(side)
		focus = Vector3(c.x, c.y, half_w() if side else 0.0)
	if focus == Vector3.INF:
		return _luneta_aim()  # unidad 4v: la luneta que estalla (o nada)
	if closeup_full and closeup_marks:
		var mk := _mark_aim(focus, axis)
		if not mk.is_empty():
			return mk
	var normal := CarDamage.surface_normal(focus, axis, _top)
	var below := maxf(half_w() - focus.z, 0.0) if side else maxf(surface_y(focus.x) - focus.y, 0.0)
	# el centro: por encima de la punta (la garra entera con su dedo) y, en el golpe, hacia donde va el surco
	focus += normal * reach * (0.5 if hold else 0.3) + Vector3(0.0 if hold else dir * reach * 0.25, 0.0, 0.0)
	return { "focus": focus, "normal": normal, "field": field, "dir": dir, "cam": 1.0 if hold else dir, "below": below, "side": side }


## La marca de cerca: el surco del conjunto de daños de ahora que empieza más cerca de near (m, las garras que se encuadran o
## el daño), a un tercio de su largo desde la garra, con lo que hay que ver: MARK_FIELD_K veces su ancho (entre
## ClawCloseup.MARK_FIELD_MIN y 3 cm), desde ClawCloseup.MARK_ELEV_DEG sobre el panel y mirando a lo largo del surco. Si no hay
## surcos, una punzada o un agujero. {} si no hay nada.
const MARK_FIELD_K := 25.0


func _mark_aim(near: Vector3, axis: int) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	var nv := Vector2(near.x, near.z if axis == CarDamage.AXIS_TOP else near.y)
	for g: Dictionary in _dmg_set.get("grooves", []):
		if int(g.axis) != axis:
			continue
		var d := (g.a as Vector2).distance_to(nv)
		if d < best_d:
			best_d = d
			best = g
	var c := Vector2.ZERO
	var w := 0.0
	var dir := -1.0
	if not best.is_empty():
		var a: Vector2 = best.a
		var b: Vector2 = best.b
		c = a + (b - a) * clampf(0.04 / maxf((b - a).length(), 1e-6), 0.2, 0.5)
		w = float(best.hw) * 2.0
		dir = 1.0 if b.x > a.x else -1.0
	else:
		for h: Dictionary in _dmg_set.get("holes", []):
			if int(h.axis) == axis and (h.c as Vector2).distance_to(nv) < best_d:
				best_d = (h.c as Vector2).distance_to(nv)
				best = h
		if best.is_empty():
			return {}
		c = best.c
		w = float(best.r) * 2.0
	var p := CarDamage.surface_point(c, axis, _top)
	return { "focus": p, "normal": CarDamage.surface_normal(p, axis, _top), "field": clampf(w * MARK_FIELD_K, ClawCloseup.MARK_FIELD_MIN, 0.03),
		"dir": dir, "cam": dir, "below": 0.0, "side": axis == CarDamage.AXIS_SIDE, "elev": ClawCloseup.MARK_ELEV_DEG,
		"field_min": ClawCloseup.MARK_FIELD_MIN }


## Un largo redondo (m) para la barra de escala de la lupa: el mayor de SCALE_BARS que no pasa de target.
static func nice_length(target: float) -> float:
	var out: float = SCALE_BARS[0]
	for l: float in SCALE_BARS:
		if l <= target:
			out = l
	return out


## El largo de la barra en texto (mm hasta 1 cm; cm después).
static func length_text(l: float) -> String:
	return "%s mm" % Js.to_fixed(l * 1000.0, 0) if l < 0.01 else "%s cm" % Js.to_fixed(l * 100.0, 0)


## ¿Queda algo por animar? (la escena quieta no se redibuja)
func is_animating() -> bool:
	return _animating


## ¿El golpe ha terminado de animarse (o no hay)?
func hit_done() -> bool:
	return hit.is_empty() or _hit_t >= _hit_end()


## Avanza ms milisegundos: viento, carretera, ruedas, la salida o la vuelta del animal y el golpe. Redibuja y renderiza
## solo si algo se mueve y se ve.
func step(ms: float) -> void:
	var dt := ms / 1000.0
	_t += dt
	var moving := false
	_wheel_step = 0.0
	if active and mode == MovingCarState.MODE_HOLD:
		if not reduce_motion and (v_kmh > 0.0 or air_kmh > 0.0):
			_advance(dt)
			moving = true
		if curve_on and road_id == CarCurve.ROAD_S and not reduce_motion and is_finite(_s_dur):
			_s_tick(dt)  # unidad 4t: la S avanza y la fuerza cambia de lado
			moving = true
		if _grip_tick(dt):  # unidad 4u: se recoloca o se cae
			moving = true
		var target := 1.0 if holds else 0.0
		if _attach != target:
			if reduce_motion:
				_attach = target
			elif holds:
				_attach = minf(1.0, _attach + dt / BACK_S)
			else:
				_attach = maxf(0.0, _attach - dt / EXIT_S)
			moving = true
		if not reduce_motion and holds and kind == "mamifero" and (load > 0.5 or scared):
			moving = true  # el mamífero tiembla (asustado, siempre); el plumaje erizado del ave no se mueve
	elif active and mode == MovingCarState.MODE_IMPACT and not hit.is_empty():
		if not reduce_motion and v_kmh > 0.0:
			_advance(dt)
			moving = true
		if _hit_t < _hit_end():
			var before := _hit_t
			_hit_t = _hit_end() if reduce_motion else minf(_hit_t + dt, _hit_end())
			moving = true
			if before < ARRIVE_S and _hit_t >= ARRIVE_S and not reduce_motion:
				contact.emit()
	if _wing_open != _wing_want:
		_wing_open = _wing_want if reduce_motion else move_toward(_wing_open, _wing_want, dt / WING_S)
		moving = true
	moving = _glass_step(dt) or moving  # unidad 4v
	_animating = moving
	# unidad 4s: la cámara del primer plano sigue a las garras (con suavidad; con movimiento reducido, directa)
	var cam_moving := _closeup_on and not reduce_motion and _closeup.advance(dt)
	if (moving or cam_moving) and _on_screen():
		_redraw()


## La carretera y las ruedas avanzan a la velocidad del coche, y el aire, a la del aire respecto al coche (a cámara lenta).
func _advance(dt: float) -> void:
	var road := v_kmh / MovingCar.KMH * SLOWMO * dt
	_road += road
	_wheel_step = road / WHEEL_R
	_air += air_along_kmh / MovingCar.KMH * SLOWMO * dt


func _on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().intersects(get_viewport().get_visible_rect())


## Pide un dibujo: el paisaje, la capa 2D de encima y un fotograma del 3D (solo uno si no se mueve nada).
func _redraw() -> void:
	queue_redraw()
	_overlay.queue_redraw()


## Duración total del golpe (s): llegada, abolladura, resbalón y final.
func _hit_end() -> float:
	return ARRIVE_S + CRUSH_S + _slide_s() + FALL_S


func _slide_s() -> float:
	if hit.is_empty():
		return 0.0
	return clampf(float(hit.slideM) / 1.6 * SLIDE_MAX_S, 0.15, SLIDE_MAX_S)


# ════════ Geometría ════════

## Del mundo (m; z: 0 en el eje del coche, CarShape.HALF_W en su costado) a la pantalla (px): la proyección de la cámara.
func _w2s(p: Vector2, z := 0.0) -> Vector2:
	return CarScene.project(Vector3(p.x, p.y, z), _s, _ox, _oy)


## Punto del dibujo (x desde el morro, y desde el suelo, 0-1) en metros, en la silueta del turismo.
static func draw_to_world(d: Vector2) -> Vector2:
	return Vector2(CAR_L * (1.0 - d.x), CAR_H * d.y)


## El mismo punto en la carrocería del coche elegido (_shape: el deportivo, más bajo y más ancho; unidad 4r).
func car_point(d: Vector2) -> Vector2:
	var w := draw_to_world(d)
	return Vector2(w.x * _shape.x, w.y * _shape.y)


## Escala de la carrocería de un coche del catálogo (draw_scale: { length, width, height }; sin ella, la del turismo).
static func shape_of(target: Variant) -> Vector3:
	if target is Dictionary and (target as Dictionary).get("draw_scale") is Dictionary:
		var d: Dictionary = (target as Dictionary).draw_scale
		return Vector3(float(d.get("length", 1.0)), float(d.get("height", 1.0)), float(d.get("width", 1.0)))
	return Vector3.ONE


## Medio ancho (m) de la carrocería del coche elegido.
func half_w() -> float:
	return CarShape.HALF_W * _shape.z


## Dónde está cada zona en z (m): en el eje del coche o en su costado (CarShape.ZONE_Z, a la anchura del coche elegido).
func zone_z(zone: String) -> float:
	return float(CarShape.ZONE_Z.get(zone, 0.0)) * _shape.z


## Dónde va el animal en z: en una zona del costado, algo por delante de la chapa (no se mete en ella).
func _animal_z(z: float) -> float:
	return z + 0.06 if z >= half_w() - 0.01 else z


## Escala y origen de la proyección: caben el coche entero (sus ocho esquinas) y, en su eje, lo que se ve alrededor (VIEW_*:
## el aire de delante y de detrás, la carretera y el vuelo del animal).
func _layout() -> void:
	_layout_size = size
	builds += 1
	var b := CarScene.view_basis()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var pts: Array[Vector3] = []
	for x: float in [0.0, CAR_L]:
		for y: float in [0.0, CAR_H]:
			for z: float in [-CarShape.HALF_W, CarShape.HALF_W]:
				pts.append(Vector3(x, y, z))
	for x: float in [-VIEW_BACK, CAR_L + VIEW_FRONT]:
		for y: float in [-VIEW_BELOW, CAR_H + VIEW_ABOVE]:
			pts.append(Vector3(x, y, 0.0))
	for p: Vector3 in pts:
		var q := Vector2(p.dot(b.x), p.dot(b.y))
		lo = lo.min(q)
		hi = hi.max(q)
	var ext := hi - lo
	_s = minf(size.x / ext.x, size.y / ext.y)
	_ox = (size.x - ext.x * _s) / 2.0 - lo.x * _s
	_oy = (size.y - ext.y * _s) / 2.0 + hi.y * _s
	_ensure_scene()
	_vp.size = ClawCloseup.render_size(size, ClawCloseup.pixel_scale(self))
	if _scene != null:
		_scene.frame(size, _s, _ox, _oy)
	_build_animal()
	if _lupa != null and _lupa.visible:
		_update_lupa()
	_layout_meter()  # unidad 4t


## El mundo 3D, una vez y solo dentro del árbol (en los tests sin ventana, las tarjetas sueltas no lo construyen).
func _ensure_scene() -> void:
	if _scene != null or not is_inside_tree():
		return
	if quality == "":
		quality = "movil" if OS.has_feature("mobile") or size.x < 480.0 else "escritorio"
	_vp.msaa_3d = Viewport.MSAA_2X if quality == "movil" else Viewport.MSAA_4X
	# unidad 4s: a los píxeles de verdad también en el teléfono (con el 0,7 de antes y la escala ×3 de la pantalla, el animal
	# se dibujaba a una cuarta parte de su resolución); ClawCloseup.render_size pone el tope de píxeles
	_vp.scaling_3d_scale = 1.0
	_scene = CarScene.new()
	_scene.name = "Mundo"
	_vp.add_child(_scene)
	_paint_col = car_col if active else Palette.color("panel3")
	_scene.build(_paint_col, quality, _shape, _doors)
	_scene.car.set_style(_style_id, _style_layers, _style_metal)
	_scene.car.set_layer_depths(_layer_to.to, _layer_to.panel)
	_scene.set_light(light_pref, sun_turn)  # unidad 4w
	if not _air_zones.is_empty():
		_scene.build_wind(_air_zones)
	builds += 1
	_dmg_dirty = true
	_apply_damage()


## Y (m) de la parte de arriba del coche en x (m), en su eje: los surcos y el animal que resbala siguen el panel.
func surface_y(x: float) -> float:
	var y := CurveKit.top_y(_top, x)
	return y if not is_nan(y) else CAR_H * _shape.y * 0.96


## El animal 3D: se construye al cambiar de especie, variante, postura, tamaño, sexo o, en las rapaces y los velocirraptores,
## de modo (no al cambiar el tamaño de la vista: vive en metros) y solo cuando ya hay mundo 3D. Sin animal con datos, se
## esconde. Desde la unidad 4r, con el cuerpo de la cetrería si lo tiene (uses_hd); si no, el modelo de la 4l.
func _build_animal() -> void:
	if _scene == null:
		return
	var art := art_id(claw_id)
	var post := ""
	if art != "":
		post = posture if Animal3D.AnimalArt.postures_of(art).has(posture) else String(Animal3D.AnimalArt.postures_of(art)[0])
	var hd := uses_hd(art, post, mode)
	var key := "%s|%s|%s|%s|%s|%s|%s" % [claw_id, variant, posture, animal_size, sex, quality, hd] if active else ""
	if key == _rig_key:
		return
	_rig_key = key
	if _rig != null:
		_rig.call("free_nodes")
		_rig = null
	if not active or art == "":
		return
	var opts := { "sex": sex, "quality": quality, "cache": _tex_cache, "pitch_deg": CarScene.PITCH_DEG, "variant": variant }
	_rig = HdAnimal.build(art, post, animal_size, opts) if hd else Animal3D.build(art, post, animal_size, opts)
	var root: Node3D = _rig.get("root")
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = CarScene.ANIMAL_LAYER
	_mark_claw_layer(_rig)
	(_scene.animal_root as Node3D).add_child(root)
	_near_fur_on = not closeup_full_on()  # que _sync_near_fur lo ponga (los materiales los comparten los animales de la caché)
	_marks_look = false  # el animal nuevo hace sombra: si la marca de cerca está puesta, _sync_near_fur se la quita
	_sync_near_fur()
	builds += 1
	_wing_open = 1.0 if posture == "abiertas" else 0.0
	_wing_want = _wing_open


## Unidad 4s: las mallas que son solo garra (las de la biblioteca de cada dedo) van también en CLAW_LAYER, para que el
## primer plano del golpe las vea sin el cuerpo que se le pone delante.
static func _mark_claw_layer(rig: RefCounted) -> void:
	for slot: Variant in rig.get("_claw_slots") as Array:
		var mi: MeshInstance3D = (slot[0] if slot is Array else slot) as MeshInstance3D
		if mi == null:
			continue
		var only_claw := true
		if slot is Array and int(slot[1]) >= 0 and mi.mesh != null:
			# una superficie de garra en una malla con más partes: solo si todas sus superficies son de garra
			var n := 0
			for s: Variant in rig.get("_claw_slots") as Array:
				if s is Array and s[0] == mi:
					n += 1
			only_claw = n == mi.mesh.get_surface_count()
		if only_claw:
			mi.layers = CarScene.ANIMAL_LAYER | CarScene.CLAW_LAYER


## Lo que se echa hacia delante (rad) una rapaz posada para que la punta de la cola (lo más bajo y más atrás de su caja,
## fit: m, el origen en los pies) quede TAIL_CLEAR_M sobre el suelo. Dibujo.
const TAIL_CLEAR_M := 0.01


static func tail_lean(fit: Rect2) -> float:
	var back := -fit.position.x
	var drop := -fit.position.y + TAIL_CLEAR_M
	if back <= 0.01 or drop <= 0.0:
		return 0.0
	return asin(clampf(drop / back, 0.0, 0.9))


## ¿El animal de ahora es el cuerpo de la cetrería (hd3d.gd)?
func _rig_hd() -> bool:
	return _rig != null and _rig.get_script() == HdAnimal


## ¿Se dibuja con el cuerpo de alta definición de la cetrería (animals/hd3d.gd, unidad 4r)? Quietos encima del coche: el
## tigre y el oso, las rapaces con las alas plegadas y los velocirraptores. El golpe (el salto del tigre contra la puerta, el
## vuelo de la rapaz, el salto del velocirraptor) y las alas abiertas, con los modelos de la 4l, que se mueven: el cuerpo de la
## cetrería es rígido y el tigre se acercaba agazapado, resbalando, y se metía en la abolladura. El casuario no tiene cuerpo
## de cetrería.
static func uses_hd(art: String, post: String, p_mode: String) -> bool:
	return HdAnimal.supports(art, post) and p_mode == MovingCarState.MODE_HOLD


## El dibujo de un animal (id de AnimalArt): el suyo o, si aún no lo tiene, el de otra variante del mismo animal
## (MovingCarState.VARIANTS: el velocirraptor de cine y la reconstrucción comparten dibujo, que cambia con la variante de
## las opciones); "" si no hay ninguno.
static func art_id(id: String) -> String:
	if id == "" or Animal3D.AnimalArt.has_art(id):
		return id
	var family: Variant = MovingCarState.VARIANTS.get(MovingCarState.animal_entry_id(id))
	if family != null:
		for v: String in family:
			if Animal3D.AnimalArt.has_art(v):
				return v
	return ""


# ════════ Dibujo ════════

## Detrás del 3D: el paisaje del atardecer (cielo, colinas lejanas y cercanas con paralaje).
func _draw() -> void:
	if _layout_size != size:
		_layout()
	var full := closeup_full_on()
	_container.visible = not full
	if full:
		# el primer plano en la vista entera: el render del coche no hace falta; detrás, el cielo del atardecer
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var sky_top := Color(Palette.color("bg"), 0.9)
		var sky_low := Color(Palette.color("panel2").lerp(Palette.color("rose"), 0.18), 0.95)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([sky_top, sky_top, sky_low, sky_low]))
		if _lupa != null:
			_lupa.visible = false
			_lupa_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_closeup.request(_animating and not reduce_motion)
		return
	var bg := Palette.color("bg")
	var hy := _chase_horizon() if chasing() else _w2s(Vector2(0.0, HORIZON_M)).y  # unidad 4t: la cámara de persecución
	var top := Color(bg, 0.55)
	var haze := Color(Palette.color("panel2").lerp(Palette.color("rose"), 0.12), 0.9)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, hy), Vector2(0, hy)]),
		PackedColorArray([top, top, haze, haze]))
	draw_rect(Rect2(0, hy, size.x, size.y - hy), Color(Palette.color("bg2"), 0.9))
	_draw_hills(_hills_far, 0.05, hy, Color(Palette.color("panel3"), 0.55))
	_draw_hills(_hills_near, 0.16, hy, Color(Palette.color("panel2").darkened(0.15), 0.85))
	# el render 3D se pide aquí: una vez si todo está quieto, en cada fotograma si algo se mueve
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _animating and not reduce_motion else SubViewport.UPDATE_ONCE
	if _lupa != null and bool(_lupa_info.on):
		# mientras el animal llega, la lupa aún no enseña el golpe: sale cuando toca el panel; en una vista estrecha, el
		# primer plano de las garras ocupa su sitio (unidad 4s)
		var arriving := mode == MovingCarState.MODE_IMPACT and not hit.is_empty() and not reduce_motion and _hit_t < ARRIVE_S
		_lupa.visible = not arriving and not closeup_hides_lupa() and not chasing()  # unidad 4t: la lupa es de la vista de lado
		if not _lupa.visible:
			_lupa_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_lupa_dirty = true
	if _lupa != null and _lupa.visible:
		# la lupa: en cada fotograma mientras crecen los daños del golpe; si no, una vez cuando cambian
		var growing := mode == MovingCarState.MODE_IMPACT and not hit.is_empty() and not reduce_motion and _hit_t >= ARRIVE_S \
			and _hit_t < ARRIVE_S + CRUSH_S + _slide_s()
		if growing:
			_lupa_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif _lupa_dirty or _lupa_vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_lupa_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_lupa_dirty = false
	if _closeup_on:
		_closeup.request(_animating and not reduce_motion)


## Una fila de colinas: su perfil (m) repetido cada HILLS_PERIOD, desplazado con la carretera por la paralaje k.
func _draw_hills(h: PackedFloat32Array, k: float, hy: float, col: Color) -> void:
	var off := fmod(_road * k, HILLS_PERIOD)
	var n := h.size()
	var pts := PackedVector2Array()
	var x0 := -VIEW_BACK - 1.0
	var x1 := size.x / _s
	var step := HILLS_PERIOD / float(n)
	var x := x0
	while x <= x1 + step:
		var u := fposmod(x + off, HILLS_PERIOD) / step
		var i := int(u) % n
		var f := u - floorf(u)
		var y := lerpf(h[i], h[(i + 1) % n], f)
		pts.append(Vector2(_ox + x * _s, hy - y * _s))
		x += step
	var line := pts.duplicate()
	pts.append(Vector2(pts[pts.size() - 1].x, hy + 2.0))
	pts.append(Vector2(pts[0].x, hy + 2.0))
	draw_colored_polygon(pts, col)
	draw_polyline(line, col, 1.2, true)


## Delante de todo (la capa _overlay): mueve el 3D (carretera, ruedas, viento, el animal y lo que va de los daños) y pinta
## los trozos de las garras, la flecha de la salida con movimiento reducido y el rótulo.
func _draw_overlay() -> void:
	var t0 := Time.get_ticks_usec()
	draws += 1
	if _layout_size != size:
		_layout()
	_ci = _overlay
	if _scene != null:
		var moving := active and not reduce_motion and (mode == MovingCarState.MODE_HOLD or not hit.is_empty())
		# el giro de las ruedas en este paso, en vueltas de un radio (cinco): desde BLUR_FULL solo se ve el disco borroso
		var per_spoke := absf(_wheel_step) / (TAU / 5.0)
		_scene.set_road(_road)
		_apply_curve()  # unidad 4t
		_scene.car.set_wheels(_road / WHEEL_R, smoothstep(BLUR_FROM, BLUR_FULL, per_spoke) if moving else 0.0)
		_scene.car.set_brake(braking and active and mode == MovingCarState.MODE_HOLD)
		_update_wind()
	if active:
		if mode == MovingCarState.MODE_HOLD:
			if _scene != null:
				_scene.car.set_damage_progress(-1, 1.0, 1.0)
			_draw_hold_animal()
		else:
			_draw_impact()
		_update_closeup()
		if closeup_full_on():
			last_draw_us = Time.get_ticks_usec() - t0
			return
		if _lupa != null and _lupa.visible:
			_draw_lupa_frame()
		_draw_flash()  # unidad 4t: el cambio de lado en la S
		_draw_glass_note()  # unidad 4v
		var caption := "movimiento reducido" if reduce_motion else ("cámara lenta ×10" if size.x < NARROW else "cámara lenta ×10 · el aire, a la velocidad local del modelo")
		# con un halo del fondo: la línea clara del borde de la carretera cruza justo por el rótulo (4q)
		var at := Vector2(8.0, size.y - 6.0)
		_ci.draw_string_outline(get_theme_default_font(), at, caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 10, 3,
			Color(Palette.color("bg"), 0.85))
		_ci.draw_string(get_theme_default_font(), at, caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 10, Palette.color("dimmer"))
	else:
		_update_closeup()
	last_draw_us = Time.get_ticks_usec() - t0


## El marco de la lupa, su barra de escala (un largo redondo) y su aumento respecto a la vista.
func _draw_lupa_frame() -> void:
	var r := _lupa_d * 0.5
	var c := _lupa.position + Vector2(r, r)
	var text := Palette.color("text")
	_ci.draw_arc(c, r + 1.5, 0.0, TAU, 72, Color(Palette.color("bg"), 0.85), 3.0, true)
	_ci.draw_arc(c, r, 0.0, TAU, 72, Color(text, 0.9), 1.5, true)
	var field := float(_lupa_info.field_m)
	var bar := nice_length(field * 0.35)
	var px := bar / field * _lupa_d
	var y := c.y + r * 0.72
	var x0 := c.x - px * 0.5
	var shade := Color(Palette.color("bg"), 0.7)
	_ci.draw_line(Vector2(x0, y + 1.0), Vector2(x0 + px, y + 1.0), shade, 3.0)
	_ci.draw_line(Vector2(x0, y), Vector2(x0 + px, y), text, 1.5)
	for x: float in [x0, x0 + px]:
		_ci.draw_line(Vector2(x, y - 3.0), Vector2(x, y + 3.0), text, 1.5)
	var zoom := (_lupa_d / field) / maxf(_s, 1e-6)
	var label := "lupa ×%s · %s" % [Js.to_fixed(zoom, 0), length_text(bar)]
	# al lado del círculo, arriba (hacia el centro de la vista): ahí está el cielo, no el coche
	var at := Vector2(_lupa.position.x + _lupa_d + 6.0 if _lupa_left else _lupa.position.x - 166.0, _lupa.position.y + 12.0)
	var align := HORIZONTAL_ALIGNMENT_LEFT if _lupa_left else HORIZONTAL_ALIGNMENT_RIGHT
	if curve_on and size.x < NARROW:
		# unidad 4s: en un teléfono en curva, al lado de la lupa están el medidor y el mapa: el rótulo, debajo del círculo
		at = Vector2(_lupa.position.x - 20.0, _lupa.position.y + _lupa_d + 12.0)
		align = HORIZONTAL_ALIGNMENT_CENTER
		_ci.draw_string_outline(get_theme_default_font(), at, label, align, _lupa_d + 40.0, 10, 3, Color(Palette.color("bg"), 0.85))
		_ci.draw_string(get_theme_default_font(), at, label, align, _lupa_d + 40.0, 10, Palette.color("dim"))
		return
	_ci.draw_string(get_theme_default_font(), at, label, align, 160.0, 10,
		Palette.color("dim"))


## El viento de este fotograma: el aire respecto al coche (a cámara lenta), cuántas partículas (más cuanto más deprisa),
## el grosor de un píxel y dónde está el animal (sus partículas, en rosa: el aire que le llega). Con movimiento reducido,
## parado o sin animal con datos, ninguna.
func _update_wind() -> void:
	if _scene.wind == null:
		return
	var air := sqrt(air_along_kmh * air_along_kmh + air_cross_kmh * air_cross_kmh)
	var on := active and not reduce_motion and air > MovingCar.REST_KMH
	var density := clampf(air / MovingCar.SLIDER_MAX_KMH, 0.15, 1.0) if on else 0.0
	var focus := Vector4(0.0, 0.0, 0.0, -1.0)
	if on and mode == MovingCarState.MODE_HOLD and (holds or _attach > 0.0):
		var w := car_point(draw_pos)
		focus = Vector4(w.x, w.y + animal_size.x * 0.5, zone_z(hold_zone), maxf(animal_size.x, 0.4) * 0.9)
	var dim := Palette.color("dim").lerp(Palette.color("text"), 0.3)
	_scene.wind.set_air(air_along_kmh, air_cross_kmh, _air, absf(air_along_kmh) / MovingCar.KMH * SLOWMO, 1.0 / maxf(_s, 1.0), focus, density,
		dim, Palette.color("text"), Palette.color("rose"))


# ── El animal quieto encima ──

func _draw_hold_animal() -> void:
	_claw_len = 1.0
	_claw_gone = false
	_claw_bend = 0.0
	# unidad 4s: las garras que se rompen a esta velocidad (la fuerza del agarre), melladas, partidas o dobladas
	match hold_frac:
		"mella":
			_claw_len = clampf(1.0 - hold_broken_mm / maxf(claw_reach_mm, 1.0), 0.2, 0.96)
		"parte":
			_claw_gone = true
		"dobla":
			_claw_bend = 1.0
	_kick = 0.0
	var base := car_point(draw_pos)
	var z := zone_z(hold_zone)
	if kind == "mamifero" and hold_zone == "ventanilla":
		base.y -= 0.45 * animal_size.x  # colgado del marco de la ventanilla: el cuerpo, no los pies, en su punto
	var p := 1.0 - _attach  # 0 agarrado · 1 ya se ha ido
	var rot := deg_to_rad(slope_deg)
	var wings := posture == "abiertas"
	if _grip_fall_draw(base, z, rot, wings):  # unidad 4u: en curva se cae por el lado de fuera
		return
	if reduce_motion and not holds:
		# quieto: su silueta en el sitio, tenue, y una flecha hacia donde se va
		_place_animal(base, _animal_z(z), rot, 1.0, 0.3, wings, 1.0)
		if not closeup_full_on():
			_exit_arrow(_w2s(base, z) + Vector2(0.0, -animal_size.x * 0.5 * _s))
		return
	var off := Vector2.ZERO
	var alpha := 1.0
	if p > 0.0:
		match exit_mode:
			"despega":
				off = Vector2(-1.6 * p, 1.3 * p)
				wings = kind == "ave"
			"delante":
				off = Vector2(2.4 * p * p, -1.0 * p * p)
				rot += p * (0.5 if _rig_hd() else 0.9)
			"abajo":
				var b := deg_to_rad(slope_deg)
				off = Vector2(1.3 * p * cos(b), -1.3 * p * sin(b) - 0.8 * p * p)
			"lado":
				off = Vector2(-0.4 * p, -1.1 * p * p)
			"dentro":
				off = Vector2(-0.12 * p, -LUNETA_SINK_M * p * p)  # unidad 4v: estalla la luneta y se cae dentro
			_:
				off = Vector2(-3.2 * p * p, -0.7 * p * p)
				# unidad 4s: el cuerpo de la cetrería no gira de una pieza: se va de espaldas, con las patas agitándose (flail)
				rot -= p * (0.55 if _rig_hd() else 1.2)
		alpha = clampf(1.25 - p, 0.0, 1.0) if exit_mode == "despega" else clampf(1.4 - p * 1.4, 0.0, 1.0)
		if exit_mode == "dentro":
			alpha = 1.0 - 0.35 * p  # unidad 4v: se queda en el agujero, medio dentro
	if curve_on and exit_mode == "lado" and p > 0.0:
		z += _exit_side * 1.6 * p  # unidad 4t: en curva sale por el lado de fuera
	if alpha <= 0.0:
		_place_animal(base, _animal_z(z), rot, 1.0, 0.0, wings, 1.0)
		return
	if not reduce_motion and holds and (load > 0.5 or scared) and kind == "mamifero":
		var j := 0.015 * maxf(clampf((load - 0.5) / 0.5, 0.0, 1.0), 0.4 if scared else 0.0)
		off += Vector2(sin(_t * 41.0) * j, cos(_t * 37.0) * j * 0.5)
	_place_animal(base + off, _animal_z(z), rot, 1.0, alpha, wings, clampf(lift_ratio, 0.0, 1.0) if holds else 1.0)
	if p <= 0.0:
		_rest_on_panel()
	if _hold_dirty and p <= 0.0:
		_rebuild_hold_marks()


## Unidad 4s: las puntas de las garras, sobre la chapa y no dentro. En un panel de arriba curvo (el techo baja hacia los
## lados y hacia las lunas) los talones de las rapaces posadas quedaban ~4 cm dentro del techo y el primer plano solo veía
## los dedos; se sube el animal lo que se mete la garra más honda (como mucho MAX_SINK_FIX). Dibujo.
const MAX_SINK_FIX := 0.08


func _rest_on_panel() -> void:
	if _rig == null or CarDamage.side_zone(hold_zone):
		return
	var root: Node3D = _rig.get("root")
	var sink := 0.0
	_pts_frame = -1  # la pose acaba de cambiar
	for q: Vector3 in _claw_points_now():
		var w := root.transform * q
		sink = maxf(sink, CarDamage.surf_y(_top, w.x) - w.y)
	if sink > 0.0:
		root.position.y += minf(sink, MAX_SINK_FIX)


## Flecha hacia donde se va el animal (con movimiento reducido).
func _exit_arrow(from: Vector2) -> void:
	var dir := Vector2(-1.0, 0.0)
	match exit_mode:
		"despega":
			dir = Vector2(-0.6, -1.0).normalized()
		"delante":
			dir = Vector2(1.0, 0.3).normalized()
		"abajo":
			dir = Vector2(cos(deg_to_rad(slope_deg)), sin(deg_to_rad(slope_deg)) + 0.3).normalized()
		"lado", "dentro":  # unidad 4v: «dentro», por el agujero de la luneta
			dir = Vector2(0.0, 1.0)
	var to := from + dir * 0.9 * _s
	var col := Palette.color("coral")
	_ci.draw_dashed_line(from, to, col, 2.0, 6.0)
	_ci.draw_line(to, to - dir.rotated(0.5) * 10.0, col, 2.0)
	_ci.draw_line(to, to - dir.rotated(-0.5) * 10.0, col, 2.0)


## Coloca el animal 3D con los pies en world (m) a la altura z (m) del mundo, girado rot (rad, como el dibujo: horario),
## a su escala por scale_k, con su opacidad, las alas abiertas o no (el abanico se abre en WING_S s) y levantadas según
## wing_lift (0 casi horizontales · 1 arriba), y su pose: erizado, temblor, garras, patada y el aire que le llega.
func _place_animal(world: Vector2, z: float, rot: float, scale_k: float, alpha: float, wings: bool, wing_lift: float) -> void:
	if _rig == null:
		return
	var root: Node3D = _rig.get("root")
	root.visible = alpha > 0.003
	root.scale = Vector3.ONE * scale_k
	_wing_want = 1.0 if wings else 0.0
	var bristle := clampf((load - 0.5) / 0.5, 0.0, 1.0) if holds and mode == MovingCarState.MODE_HOLD else 0.0
	if scared:
		bristle = maxf(bristle, 0.6)
	var live := not reduce_motion and _animating
	var claws_out := 1.0
	if kind == "mamifero":
		# unidad 4s: quieto encima se agarra con las garras (las marcas de cada garra lo dicen): fuera, también las del tigre
		claws_out = 1.0 if claw_id == "oso" or scared or mode == MovingCarState.MODE_IMPACT or reforged_claws or mode == MovingCarState.MODE_HOLD else 0.0
	# el aire donde está: quieto encima, el local de su zona (localKmh); en el golpe, el del coche (sin viento)
	var wind_ms := (local_kmh if mode == MovingCarState.MODE_HOLD else v_kmh) / MovingCar.KMH if live else 0.0
	_pose["t"] = _t
	_pose["live"] = live
	_pose["alpha"] = alpha
	_pose["wing_open"] = _wing_open
	_pose["wing_lift"] = wing_lift
	_pose["bristle"] = bristle if not reduce_motion else 0.0
	_pose["flutter"] = clampf(local_kmh / 120.0, 0.0, 1.0) if live and mode == MovingCarState.MODE_HOLD else 0.0
	_pose["wind_local_ms"] = wind_ms
	_pose["slowmo"] = SLOWMO
	_pose["scared"] = 1.0 if scared else 0.0
	_pose["claws_out"] = claws_out
	_pose["claw_len"] = _claw_len
	_pose["claw_gone"] = _claw_gone
	_pose["claw_bend"] = _claw_bend
	_pose["kick"] = _kick
	_pose["flail"] = (1.0 - _attach) if mode == MovingCarState.MODE_HOLD and not holds and not reduce_motion else 0.0
	_pose["lean"] = 0.12 * clampf(local_kmh / 150.0, 0.0, 1.0) if kind == "ave" and mode == MovingCarState.MODE_HOLD and holds else 0.0
	if kind == "ave" and mode == MovingCarState.MODE_HOLD and _rig_hd():
		# unidad 4s (lo que anotó la 4r: «la cola de las rapaces atraviesa el techo»): el cuerpo de la cetrería es rígido y
		# la cola cuelga por detrás de los talones; posada en el techo, la rapaz se echa hacia delante (como contra el viento)
		# lo justo para que la punta de la cola quede sobre la chapa
		_pose["lean"] = maxf(float(_pose["lean"]), tail_lean(_rig.get("fit_box")))
	# la pose puede mover la raíz (el ave se inclina con el aire; el velocirraptor de cine asustado da saltitos): se le
	# deja en el origen y lo que la mueva se suma a donde la pone la vista, que es la que la coloca
	root.position = Vector3.ZERO
	root.rotation = Vector3.ZERO
	_grip_pose()  # unidad 4u: se agarra con más fuerza cerca del límite
	_rig.call("pose", _pose)
	root.position = Vector3(world.x, world.y + root.position.y, z)
	# unidad 4t: en curva, agarrado, se inclina hacia dentro (contra la fuerza)
	var lean := RoadCurve.lean_rad(lat_g) if curve_on and mode == MovingCarState.MODE_HOLD and holds else 0.0
	root.rotation = Vector3(lean, 0.0, -rot + root.rotation.z)
	_grip_root(root)  # unidad 4u
	_rig.call("set_claws", not reforged_claws, inlay_id, claw_col)


# ── El golpe ──

## Punto del golpe en el dibujo (m): el de su zona (zone_draw) o, en la puerta, DOOR_DRAW. En los paneles de arriba, sobre
## la superficie de la silueta.
func _impact_point(side: bool) -> Vector2:
	var d: Variant = zone_draw(hit_zone)
	var w := car_point(DOOR_DRAW if d == null else Vector2(d.x, d.y))
	if not side:
		w.y = surface_y(w.x)
	return w


## Punto del dibujo de una zona (x desde el morro, y desde el suelo, 0-1): el de la zona del golpe si lo trae
## (MovingCar.IMPACT_ZONES[…].draw: la ventanilla de la unidad 4m, que no es una zona de MovingCar.ZONES) o el de la zona de
## MovingCar.ZONES con su nombre; null si no hay ninguno (la puerta: DOOR_DRAW).
static func zone_draw(zone: String) -> Variant:
	var iz: Variant = MovingCar.IMPACT_ZONES.get(zone)
	if iz != null and iz.get("draw") != null:
		return iz.draw
	var z: Variant = MovingCar.ZONES.get(zone)
	return z.draw if z != null else null


## El final del salto de un velocirraptor a un panel de arriba (leap de impact(), MovingCar.leap_block): Vector3(vx, vz,
## dt) con la velocidad con la que llega respecto al coche en el plano del costado (m/s: leap.ux menos la del coche, y
## leap.uz) y los segundos de vuelo que se ven: los de los últimos APPROACH_M m, sin pasar del despegue desde el asfalto
## hasta feet_y (m), el alto del panel en el dibujo. Su camino es la parábola de esa velocidad con la gravedad (el aire le
## quita menos de 0,1 km/h en el vuelo). Vector3.ZERO si no salta.
static func leap_arc(leap: Variant, car_kmh: float, feet_y: float) -> Vector3:
	if not leap is Dictionary or Js.truthy(leap.get("side")) or not Js.truthy(leap.get("reaches", true)):
		return Vector3.ZERO
	var vx := float(leap.get("ux", 0.0)) - car_kmh / MovingCar.KMH
	var vz := float(leap.get("uz", 0.0))
	var v := Vector2(vx, vz).length()
	if v <= 1e-6:
		return Vector3.ZERO
	var g := MovingCar.G
	var flight := (-vz + sqrt(vz * vz + 2.0 * g * maxf(feet_y, 0.0))) / g
	return Vector3(vx, vz, minf(APPROACH_M / v, flight))


## Las fases del golpe ahora (en los _ph_*).
func _phases() -> void:
	var iz: Dictionary = MovingCar.IMPACT_ZONES[hit_zone]
	_ph_side = iz.normal == "lado"
	_ph_z = half_w() if _ph_side else 0.0
	_ph_contact = _impact_point(_ph_side)
	_ph_t = _hit_t if _hit_t >= 0.0 else _hit_end()
	var t_crush := ARRIVE_S
	var t_slide := ARRIVE_S + CRUSH_S
	var t_fall := t_slide + _slide_s()
	_ph_crush = clampf((_ph_t - t_crush) / CRUSH_S, 0.0, 1.0)
	_ph_slide = clampf((_ph_t - t_slide) / maxf(_slide_s(), 0.001), 0.0, 1.0)
	_ph_fall = clampf((_ph_t - t_fall) / FALL_S, 0.0, 1.0)
	_ph_dir = 1.0 if float(arrival.x) > 0.0 else -1.0
	# lo que resbala, en la proporción de su panel (MovingCar: slideM de los slide_m del panel) sobre el panel dibujado,
	# desde el golpe hasta su borde en esa dirección
	var panel: Vector2 = PANELS.get(hit_zone, Vector2(0.0, CAR_L))
	var room := (panel.y - _ph_contact.x) if _ph_dir > 0.0 else (_ph_contact.x - panel.x)
	_ph_slide_m = clampf(float(hit.slideM) / maxf(float(iz.slide_m), 0.001), 0.0, 1.0) * maxf(room, 0.0)


## El animal en el golpe: llega, abolla, resbala y acaba (se queda, cae o sale volando); los daños crecen con la abolladura
## y el resbalón (en el material del coche); y los trozos de unas garras reforjadas que se mellan o se parten, que saltan
## del punto del golpe.
func _draw_impact() -> void:
	if hit.is_empty():
		if _rig != null:
			(_rig.get("root") as Node3D).visible = false
		return
	_phases()
	var contact_m := _ph_contact
	var side := _ph_side
	var zz := _ph_z
	var t := _ph_t
	var crush := _ph_crush
	var slide := _ph_slide
	var fall := _ph_fall
	var dir := _ph_dir
	var slide_m := _ph_slide_m
	var t_crush := ARRIVE_S
	var iz: Dictionary = MovingCar.IMPACT_ZONES[hit_zone]
	if _scene != null:
		_scene.car.set_damage_progress(_dmg_seq, crush, slide)
		var sh: Dictionary = _dmg_cur.get("shatter", {}) if not _dmg_cur.is_empty() else {}
		if float(sh.get("front", 0.0)) + float(sh.get("rear", 0.0)) > 0.0:
			# la ventanilla templada estalla: se cuartea, sus trocitos caen (los del marco se quedan) y se quedan atrás
			var s := clampf((t - ARRIVE_S) / SHATTER_S, 0.0, 1.0)
			_scene.car.set_shatter(s * float(sh.front), s * float(sh.rear), float(sh.frag_m))
			if t >= ARRIVE_S + SHATTER_S * 0.35:
				if _shatter_seq != _dmg_seq:
					_shatter_seq = _dmg_seq
					_scene.car.shatter_start(0 if float(sh.front) > 0.0 else 1, float(sh.frag_m), "%s|%d" % [claw_id, _dmg_seq])
				var road_ms := v_kmh / MovingCar.KMH * SLOWMO if not reduce_motion else 0.0
				_scene.car.shatter_step(t - ARRIVE_S - SHATTER_S * 0.35, road_ms)
	if (frac_mode == "mella" or frac_mode == "parte") and crush >= 1.0 and slide < 1.0 and not closeup_full_on():
		var fa := 1.0 - slide
		for k in 3:
			var q := contact_m + Vector2(dir * (0.12 + 0.08 * float(k)) * slide, 0.25 * slide - 0.45 * slide * slide + 0.03 * float(k))
			var sq := _proj(q, zz)  # unidad 4t: con la cámara de persecución, la suya
			_ci.draw_line(sq, sq + Vector2(4.0, -3.0).rotated(float(k) * 1.7 + slide * 6.0), Color(claw_col, fa), 2.0, true)
	# en un costado golpea con el cuerpo (hombro y cadera): su centro, no sus pies, va al punto del golpe; el casuario
	# patea: su pie, saltando
	var feet := contact_m - Vector2(0.0, 0.45 * animal_size.x) if side and not kicker else contact_m
	var start := feet - Vector2(float(arrival.x), float(arrival.z)) * APPROACH_M
	var arc := leap_arc(hit.get("leap"), v_kmh, feet.y) if leaper and not side else Vector3.ZERO
	if not _approach_long.is_empty():
		_draw_approach_path(feet, zz + (0.12 if side else 0.0), t)  # unidad 4t: el camino torcido, a puntos (dibujo)
	var pos := feet
	var rot := 0.0
	var scale_k := 1.0
	var alpha := 1.0
	var landing := kind == "ave" and Js.truthy(hit.get("landing"))
	var wings := landing
	_claw_len = 1.0
	_claw_gone = false
	_claw_bend = 0.0
	if crush >= 1.0:
		var frac: Variant = hit.get("clawFracture")
		match frac_mode:
			"mella":
				_claw_len = clampf(1.0 - float(frac.get("brokenMm", 0.0)) / maxf(claw_reach_mm, 1.0), 0.2, 1.0) if frac != null else 0.6
			"parte":
				_claw_gone = true
			"dobla":
				_claw_bend = 1.0
	_kick = 0.0
	if kicker or leaper:
		# la patada del casuario y el salto del velocirraptor, con los pies por delante (la pose «kick»)
		_kick = clampf(t / ARRIVE_S, 0.0, 1.0) if t < t_crush else clampf(1.0 - fall * 1.5, 0.0, 1.0)
	var zoff := 0.0
	if t < t_crush:
		var a := t / ARRIVE_S
		pos = start.lerp(feet, a)
		if not _approach.is_empty():
			# unidad 4t: en curva, el camino visto desde el coche que gira se tuerce (x a lo largo, y hacia quien mira); con la
			# cámara de persecución, en 3D de verdad (llega por el costado)
			var p3 := _approach_pos(start, feet, a, APPROACH_M, _approach)
			pos = Vector2(p3.x, p3.y)
			zoff = p3.z
			if chasing():
				scale_k = 1.0
		scale_k = 1.0 + 0.3 * float(arrival.lateral) * (1.0 - a)  # del lado de quien mira, hacia el coche
		wings = kind == "ave"
		rot = -0.25 * (1.0 - a)
		if kicker:
			pos.y += 0.35 * sin(PI * a)  # el salto, con los pies por delante: echado hacia atrás
			rot = -0.3 * a
		if arc.z > 0.0:
			# el velocirraptor cae sobre el panel desde su salto: el final de la parábola, con las garras por delante
			var dt := (a - 1.0) * arc.z
			pos = feet + Vector2(arc.x, arc.y) * dt - Vector2(0.0, 0.5 * MovingCar.G * dt * dt)
	else:
		pos = feet + Vector2(dir * slide_m * slide, 0.0)
		if not side:
			pos.y = surface_y(pos.x)
			rot = deg_to_rad(float(iz.slope_deg)) if hit_zone == "parabrisas" else 0.0
		if crush < 1.0:
			scale_k = 1.0 - 0.08 * sin(crush * PI)
		if kicker:
			rot = -0.3 * (1.0 - fall)  # patea echado hacia atrás y, al rebotar, se endereza
		if fall > 0.0:
			if hit.stays:
				var h: Variant = hit.get("hold")
				if h != null and not h.holds:
					pos += Vector2(-3.0 * fall * fall, -0.6 * fall * fall)  # se queda un instante, pero no aguanta
					alpha = clampf(1.3 - fall * 1.3, 0.0, 1.0)
			elif landing:
				pos += Vector2(dir * 1.2 * fall - 1.2 * fall, 1.1 * fall)  # sale volando
				wings = true
				alpha = clampf(1.3 - fall * 1.3, 0.0, 1.0)
			elif kicker and float(hit.groundKmh) < 1.0:
				pos.y = lerpf(pos.y, 0.0, minf(1.0, fall * 1.6))  # rebota y se queda junto al coche
			else:
				# sale del panel y cae al asfalto dando media vuelta, sin hundirse en él: la grupa (o la cabeza) que baja al
				# girar sobre los pies lo levanta
				var h0 := pos.y
				var spin := fall * 0.7 * dir
				pos += Vector2(dir * 1.4 * fall - 1.0 * fall * fall, -h0 * minf(1.0, fall * 1.6))
				pos.y = maxf(pos.y, 0.5 * animal_size.y * absf(sin(spin)))
				rot += spin
				alpha = clampf(1.5 - fall * 1.5, 0.0, 1.0)
	_place_animal(pos, zz + (0.12 if side else 0.0) + zoff, rot, scale_k, alpha, wings, 0.6)


# ════════ Curvas (unidad 4t) ════════

## Lo de la curva que llega del estado: si hay curva, su radio, la aceleración lateral de ahora y el medidor. En la S, el
## reloj de la S sigue donde iba (en la misma fracción si cambia la velocidad).
func _sync_curve(st: MovingCarState) -> void:
	_st = st
	var hold_on: bool = active and mode == MovingCarState.MODE_HOLD and st.curve_on() and not st.at.is_empty()
	# el golpe en curva: la carretera, la cámara y el camino del animal; su fuerza, la de siempre (sin medidor)
	hit_curve = active and mode == MovingCarState.MODE_IMPACT and st.impact_curve_on()
	var on := hold_on or hit_curve
	var road_now: String = CarCurve.ROAD_CURVE if hit_curve else st.road
	if on != curve_on or road_now != road_id:
		meter_ctl.clear_trail()
		_s_t = 0.0
	if on != curve_on:
		_on_resized.call_deferred()  # en un teléfono, la vista crece en curva (y vuelve en recta)
	curve_on = on
	road_id = road_now
	if _scene != null:
		_scene.set_curved(on)
	meter_ctl.visible = hold_on
	map_ctl.visible = on
	if not on:
		lat_g = 0.0
		_approach = PackedVector2Array()
		_approach_long = PackedVector2Array()
		return
	_curve_k = 1.0 / float(st.radius_m)
	var rd: Dictionary = st.curve_road()
	if hit_curve:
		lat_g = st.impact_lat_g()
		_approach = st.impact_approach(APPROACH_M)
		_approach_long = st.impact_approach(APPROACH_LONG_M, 32)
		_s_dur = INF
	var narrow := size.x < NARROW
	var mk := "%s|%s|%s|%s" % [road_id, st.radius_m, st.target.id, narrow]
	if mk != _map_key:
		_map_key = mk
		var path := CarCurve.path(rd, road_id, 48 if quality == "movil" else 96)
		map_ctl.set_path(path.pts, path.s, st.road_note(narrow))
	if road_id != CarCurve.ROAD_S:
		map_ctl.set_car(float(rd.leadM) + float(rd.clothoidM) + 0.25 * PI * float(rd.rM))
	if hit_curve:
		_layout_meter()
		return
	if road_id == CarCurve.ROAD_S:
		var dur: float = st.s_duration()
		if is_finite(dur) and is_finite(_s_dur) and _s_dur > 0.0:
			_s_t = fposmod(_s_t, _s_dur) / _s_dur * dur
		_s_dur = dur
		_s_rd = st.curve_road()
		if reduce_motion or not is_finite(dur):
			_s_show(st.at)  # quieto: el pico del lado peor (o, parado, nada)
		else:
			var f: Dictionary = st.s_frame(_s_t)
			_s_pos = float(f.s.sM)
			_s_show(f.at)
	else:
		_s_dur = INF
		_s_show(st.at)
	_layout_meter()


## Enseña unas fuerzas con su campo curve (las del deslizador o las de un instante de la S): el medidor, la aceleración
## lateral y si el animal aguanta (en la S, puede soltarse en el pico y volver).
func _s_show(a: Dictionary) -> void:
	if a.is_empty() or not a.has("curve"):
		return
	var c: Dictionary = a.curve
	lat_g = float(c.latG)
	if absf(lat_g) > 1e-6:
		_exit_side = signf(lat_g)
	holds = bool(a.holds) and not _grip_latched  # unidad 4u: en la S, si se ha caído, sigue caído hasta que vuelve a empezar
	load = a.loadRatio if is_finite(a.loadRatio) else 2.0
	if not bool(a.holds):
		exit_mode = a.mode
	var loop := RoadCurve.S_LOOP_S if road_id == CarCurve.ROAD_S and not reduce_motion else 0.0
	meter_ctl.set_meter(c.meter, _st.meter_note(c, loop, size.x < NARROW) if _st != null else "")


## Avanza el reloj de la S: dura RoadCurve.S_LOOP_S en la pantalla, sea cual sea lo que dura de verdad (lo dice la nota).
func _s_tick(dt: float) -> void:
	if _st == null or not is_finite(_s_dur) or _s_dur <= 0.0:
		return
	_s_t = fposmod(_s_t + dt * _s_dur / RoadCurve.S_LOOP_S, _s_dur)
	flash = maxf(0.0, flash - dt / FLASH_S)
	meter_ctl.flash = flash
	var f := _st.s_frame(_s_t)
	if not f.is_empty():
		_s_jerk = float(f.s.jerkMs3)  # unidad 4u: el tirón asusta
		var before := lat_g
		_s_show(f.at)
		# el cambio de lado: la fuerza cruza el cero en la clotoide de cambio (de un fotograma al siguiente)
		if String(f.s.phase) == "cambio" and before * lat_g < 0.0:
			flash = 1.0
			flash_side = signf(lat_g)
			meter_ctl.flash = flash
		meter_ctl.push_trail()
		_s_pos = float(f.s.sM)
		map_ctl.set_car(_s_pos)


## La carretera doblada, la cámara, el giro de las ruedas y el balanceo de este fotograma (dibujo). En la vista de lado, la
## carretera corta con la curva más cerrada que la de verdad; en la de persecución, la larga al radio de verdad y la cámara
## detrás del coche, sobre la propia carretera.
func _apply_curve() -> void:
	if _scene == null:
		return
	_scene.set_curved(curve_on)  # también si la escena se creó después de llegar la curva
	_scene.set_chase(curve_on and chasing())
	if not curve_on:
		_sun_straight()  # unidad 4w
		_straight_chase_tick()  # (4x)
		return
	var s_mode := road_id == CarCurve.ROAD_S and not _s_rd.is_empty()
	var rd := _s_rd
	var s_car := _s_pos
	# la curvatura de verdad (1/m, + a la izquierda) bajo el coche: la de la S donde va, o la de la curva
	var k_here := CarCurve.s_kappa(rd, s_car) if s_mode else _curve_k
	if chasing():
		var rl: RoadCurve = _scene.road_chase
		if rl != null:
			if s_mode:
				rl.set_kappa_fn(func(a: float) -> float: return RoadCurve.chase_kappa(CarCurve.s_kappa(rd, s_car + a)))
				rl.set_road(s_car)
			else:
				var key := "c%s" % _curve_k
				if key != _bend_key:
					_bend_key = key
					rl.set_kappa_const(RoadCurve.chase_kappa(_curve_k))
				rl.set_road(_road)
		_scene.update_chase()
	else:
		var rc: RoadCurve = _scene.road_curve
		if rc != null:
			if s_mode:
				rc.set_kappa_fn(func(a: float) -> float: return RoadCurve.vis_kappa(CarCurve.s_kappa(rd, s_car + a * RoadCurve.S_STRETCH)))
				_bend_key = ""
			else:
				var key := "l%s" % _curve_k
				if key != _bend_key:
					_bend_key = key
					rc.set_kappa_const(RoadCurve.vis_kappa(_curve_k))
	_scene.car.set_steer(RoadCurve.steer_rad(k_here))
	_scene.set_roll(RoadCurve.roll_rad(lat_g))
	_sun_tick(k_here, s_car if s_mode else _road)  # unidad 4w: el sol se queda quieto en el mundo


## Vista de persecución (on) o de lado en curva (la elige la tarjeta). Solo dibujo.
func set_chase_pref(on: bool) -> void:
	if on == chase_pref:
		return
	chase_pref = on
	_bend_key = ""
	_redraw()


## ¿Se ve con la cámara de persecución? (en curva y si no se ha elegido la vista de lado)
func chasing() -> bool:
	return (curve_on and chase_pref) or _straight_chase_on()  # (4x)


## La línea del horizonte (px) con la cámara de persecución: donde cae un punto muy lejano por delante, a ras de suelo.
func _chase_horizon() -> float:
	var cam: Camera3D = _scene.chase_cam if _scene != null else null
	if cam == null:
		return _w2s(Vector2(0.0, HORIZON_M)).y
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 1e-6:
		return size.y * 0.3
	var far := cam.global_position + fwd.normalized() * 2000.0
	far.y = 0.0
	return cam.unproject_position(far).y


## El medidor en una esquina de arriba, la de la izquierda (encima de la zaga, en el cielo), y el plano en la de la derecha
## (encima del morro): en un teléfono, juntos tapaban el animal. Si la lupa está en una de las dos esquinas, el plano va al
## lado del medidor, en la otra.
func _layout_meter() -> void:
	if meter_ctl == null:
		return
	# en un teléfono la vista mide ~150 px de alto: un medidor más pequeño y una sola línea de nota
	var narrow := size.x < NARROW
	var d := clampf(size.x * 0.26, 74.0, 96.0) if narrow else clampf(size.y * 0.42, 92.0, 150.0)
	var w := d + 56.0 if narrow else maxf(d + 56.0, 164.0)
	var text_h := GMeter.TEXT_H * 0.55 if narrow else GMeter.TEXT_H
	meter_ctl.size = Vector2(w, d + text_h)
	var mw := clampf(d * 0.75, 50.0, 120.0)
	map_ctl.size = Vector2(mw, d + text_h)
	var lupa := _lupa != null and _lupa.visible and not chasing()  # en persecución la lupa no sale
	if lupa and _lupa_left:
		meter_ctl.position = Vector2(size.x - w - 6.0, 6.0)
		map_ctl.position = Vector2(meter_ctl.position.x - mw - 4.0, 6.0)
	elif lupa:
		meter_ctl.position = Vector2(6.0, 6.0)
		map_ctl.position = Vector2(6.0 + w + 4.0, 6.0)
	else:
		meter_ctl.position = Vector2(6.0, 6.0)
		map_ctl.position = Vector2(size.x - mw - 6.0, 6.0)


## En curva, los desgarros del animal asustado quieto encima se tuercen hacia fuera: van en la dirección de la fuerza en el
## contacto (curve.markDeg: grados desde «hacia atrás», + hacia la derecha), no solo hacia atrás. Solo en los paneles de
## arriba (en un costado, la fuerza lateral empuja contra el panel o lo separa, no a lo largo). Se rehacen solo si cambia
## el ensayo o el ángulo en más de 2°.
func _twist_hold_marks(st: MovingCarState) -> void:
	# unidad 4s: las marcas del animal quieto encima son las de la velocidad del deslizador, desde las puntas de sus garras
	# (_hold_scen y _hold_ctx, que rehace _rebuild_hold_marks); aquí solo se tuercen
	if mode != MovingCarState.MODE_HOLD or _hold_ctx.is_empty():
		return
	var deg := float(st.curve_now().get("markDeg", 0.0)) if curve_on else 0.0
	if absf(deg - _twist_deg) < 2.0:
		return
	_twist_deg = deg
	_dmg_hold = _twisted(CarDamage.from_hold(_hold_scen, _hold_ctx))
	_dmg_dirty = true


## Unidad 4t con la 4s: las marcas del animal quieto encima torcidas _twist_deg grados hacia fuera de la curva (cada surco
## gira alrededor de su punta, en los paneles de arriba); en recta (_twist_deg 0), tal cual.
func _twisted(d: Dictionary) -> Dictionary:
	if absf(_twist_deg) < 1e-6 or (d.get("grooves", []) as Array).is_empty():
		return d
	var out := d.duplicate()
	var grooves: Array = []
	var turn := -deg_to_rad(_twist_deg)
	for g: Dictionary in d.grooves:
		var t := g.duplicate()
		if int(g.axis) == CarDamage.AXIS_TOP:
			var a: Vector2 = g.a
			t.b = a + (g.b - a).rotated(turn)
		grooves.append(t)
	out.grooves = grooves
	return out


## El destello del cambio de lado en la S: un rótulo arriba, en el centro, del color del lado nuevo, que se apaga en FLASH_S.
func _draw_flash() -> void:
	if flash <= 0.0 or not curve_on:
		return
	var font := get_theme_default_font()
	var narrow := size.x < NARROW
	var fs := 12 if narrow else 17
	# en un teléfono, corto y en la esquina de abajo (el lado nuevo lo dice la flecha del medidor, con su anillo)
	var text := "¡Cambia de lado!" if narrow else "¡Cambia de lado! Ahora tira %s" % CarCurve.side_txt(flash_side)
	var a := clampf(flash * 1.6, 0.0, 1.0)
	var col := Palette.color("gold")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(16.0, size.y - 24.0) if narrow else Vector2((size.x - w) * 0.5, maxf(size.y * 0.16, 30.0))
	if not narrow and map_ctl != null and map_ctl.visible:
		# que no lo tape el plano (o el medidor): debajo de ellos si se cruzan
		for c: Control in [map_ctl, meter_ctl]:
			var r := Rect2(c.position, c.size)
			if r.intersects(Rect2(at + Vector2(-10.0, -fs - 6.0), Vector2(w + 20.0, fs + 14.0))):
				at.y = r.end.y + fs + 14.0
	var box := Rect2(at + Vector2(-10.0, -fs - 6.0), Vector2(w + 20.0, fs + 14.0))
	_ci.draw_rect(box, Color(Palette.color("bg"), 0.78 * a))
	_ci.draw_rect(box, Color(col, a), false, 2.0)
	_ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))



## En un teléfono, en curva, la vista 3D crece hasta CURVE_PHONE_H del alto de la pantalla (~350 px en uno de 844): de
## ~150 px, el coche que gira y la curva se quedaban pequeños entre el medidor y el plano. base: el alto de siempre.
const CURVE_PHONE_H := 0.42


func _curve_min_h(base: float) -> float:
	if not curve_on or size.x >= NARROW or not is_inside_tree():
		return base
	return maxf(base, get_viewport_rect().size.y * CURVE_PHONE_H)


## Un punto del mundo (x a lo largo, y arriba; z) en la pantalla: con la cámara de persecución si es la que se ve, y si no
## con la proyección de la vista de lado (_w2s).
func _proj(p: Vector2, z := 0.0) -> Vector2:
	if chasing() and _scene != null and _scene.chase_cam != null:
		return _scene.chase_cam.unproject_position(Vector3(p.x, p.y, z))
	return _w2s(p, z)


## El camino del animal que se abalanza en la curva, visto desde el coche: a puntos sus últimos APPROACH_LONG_M m mientras
## llega y un momento después, con su rótulo. Solo dibujo: en 2,2 m lo que se tuerce son centímetros; en 9 m ya se ve.
const APPROACH_SHOW_S := 1.2


func _draw_approach_path(feet: Vector2, z: float, t: float) -> void:
	var fade := 1.0 - clampf((t - ARRIVE_S) / APPROACH_SHOW_S, 0.0, 1.0)
	if fade <= 0.0:
		return
	var start := feet - Vector2(float(arrival.x), float(arrival.z)) * APPROACH_LONG_M
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var p3 := _approach_pos(start, feet, float(i) / float(n - 1), APPROACH_LONG_M, _approach_long)
		pts.append(_proj(Vector2(p3.x, p3.y), z + p3.z))
	var col := Color(Palette.color("gold"), 0.9 * fade)
	for i in range(0, n - 1, 2):
		_ci.draw_line(pts[i], pts[i + 1], col, 2.5, true)
	var font := get_theme_default_font()
	var label := "camino visto desde el coche que gira (dibujo)" if size.x >= NARROW else "camino desde el coche (dibujo)"
	var at := pts[0] + Vector2(-60.0, -10.0)
	at.x = clampf(at.x, 6.0, maxf(size.x - 260.0, 6.0))
	at.y = clampf(at.y, 16.0, size.y - 20.0)
	_ci.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(Palette.color("bg"), 0.8 * fade))
	_ci.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


## Un punto del camino del animal en la curva (fracción a, 0-1, de los últimos dist m): la recta de llegada más lo que se
## tuerce (offsets: x a lo largo, y hacia quien mira). Con la cámara de persecución, la recta lleva su parte lateral
## (arrival.lateral: llega por el costado de quien mira); en la vista de lado, como siempre (se finge con la escala).
## Vector3(x, y, desplazamiento en z).
func _approach_pos(start: Vector2, feet: Vector2, a: float, dist: float, offsets: PackedVector2Array) -> Vector3:
	var off := _offset_at(offsets, a)
	if chasing():
		var lat := clampf(float(arrival.lateral), 0.0, 1.0)
		var c := sqrt(maxf(1.0 - lat * lat, 0.0))
		var d := Vector2(float(arrival.x), float(arrival.z)) * c
		var p := feet - d * dist * (1.0 - a)
		return Vector3(p.x + off.x, p.y, lat * dist * (1.0 - a) + off.y)
	var q := start.lerp(feet, a)
	return Vector3(q.x + off.x, q.y, off.y)


## Lo que se separa de la recta el camino en la fracción a (0-1), interpolado en offsets.
static func _offset_at(offsets: PackedVector2Array, a: float) -> Vector2:
	var n := offsets.size()
	if n < 2:
		return Vector2.ZERO
	var u := clampf(a, 0.0, 1.0) * float(n - 1)
	var i := mini(int(floorf(u)), n - 2)
	return offsets[i].lerp(offsets[i + 1], u - float(i))


# ════════ Agarre en curva (unidad 4u) ════════
# En curva, el animal se agarra con más fuerza cuanto más cerca está de su tope (dibujo, cada especie a su manera), las
# garras del lado de fuera resbalan y vuelven a clavarse dejando su surco (las medidas, de CarCurveGrip a través del estado;
# dónde va cada una, de las puntas de sus garras: dibujo) y, si no aguanta, resbala hacia fuera, intenta agarrarse y cae por
# el lado de fuera, rodando por la carretera y quedando atrás (dibujo determinista, sin física de vuelo). En recta no se hace
# nada: _grip queda vacío y no hay surcos ni pose nueva.

## Lo que dura el tirón de una garra que resbala y vuelve a clavarse (s), y las partes de la caída: resbala hasta el borde,
## se queda colgando un instante y cae rodando por la carretera (s). Dibujo.
const GRIP_PULSE_S := 0.55
const FALL_SLIDE_S := 0.6
const FALL_HANG_S := 0.4
const FALL_DROP_S := 1.5
## Lo que se queda atrás en la carretera mientras cae y rueda (m) y lo que se aparta del costado del coche (m). Dibujo.
const FALL_BACK_M := 3.5
const FALL_OUT_M := 1.3
## Separación entre los surcos de dos recolocaciones de la S que salen de la misma garra (m, a lo largo del resbalón). Dibujo.
const REGRIP_STEP_M := 0.004
## Cómo cae cada especie (dibujo, sin física de vuelo ni de caída): turn, el giro final sobre su eje largo (rad: TAU acaba
## de pie tras una vuelta, PI boca arriba, 0 sin girar); hop, el salto hacia arriba al soltarse (m); out, cuánto se aleja hacia
## fuera (× FALL_OUT_M); back, cuánto se queda atrás (× FALL_BACK_M); ahead, lo que se adelanta al coche (m; el de cine).
const FALL_STYLE := {
	"tigre": { "turn": TAU, "hop": 0.25, "out": 1.3, "back": 1.0, "ahead": 0.0 },
	"oso": { "turn": PI, "hop": 0.0, "out": 0.8, "back": 0.8, "ahead": 0.0 },
	"teropodo": { "turn": 0.0, "hop": 0.6, "out": 1.5, "back": 1.0, "ahead": 0.0 },
	"pelicula": { "turn": 0.0, "hop": 1.0, "out": 0.6, "back": 0.2, "ahead": 4.0 },
	"": { "turn": 6.0, "hop": 0.0, "out": 1.0, "back": 1.0, "ahead": 0.0 },
}

var _grip: Dictionary = {}
var _grip_sig := ""
var _dmg_grip: Dictionary = {}
var _grip_shown := {}
var _grip_pulse := 0.0
var _grip_fall_t := -1.0
var _grip_latched := false
var _grip_prev_s := 0.0
var _grip_fall_side := 1.0
var _grip_setup := -1
## Cuántos conjuntos de surcos de los resbalones se han puesto (para las pruebas).
var grip_sets := 0


## Lo que llega del estado: lo que hace el animal en la curva (CarCurveGrip a través de grip_now). Si cambia, se rehacen los
## surcos (en la curva quieta, ya; en la S, a medida que pasan sus momentos).
func _sync_grip(st: MovingCarState) -> void:
	var hold_on: bool = active and mode == MovingCarState.MODE_HOLD and curve_on and not hit_curve
	var g: Dictionary = st.grip_now() if hold_on else {}
	var sig := ""
	if not g.is_empty():
		sig = "%s|%s|%s|%s" % [JSON.stringify(g.get("u", g.get("peak", ""))), CarCurveGrip.groove_count(g), road_id, st.setup_version]
	if sig == _grip_sig:
		_grip = g
		return
	# en la curva quieta, si ya se estaba cayendo y sigue sin aguantar (más deprisa todavía), la caída sigue donde iba, con
	# los surcos que dejó al empezar (las puntas de ahora ya no están en el techo)
	var still_falls := not g.is_empty() and not g.has("events") and bool(g.falls) and st.setup_version == _grip_setup
	_grip_sig = sig
	_grip = g
	_grip_setup = st.setup_version
	if still_falls and _grip_fall_t >= 0.0:
		return
	_grip_shown = {}
	_grip_latched = false
	_grip_fall_t = -1.0
	_grip_prev_s = _s_t
	_dmg_grip = {}
	if not g.is_empty() and not g.has("events") and not bool(g.falls) and int(g.slips) > 0:
		# en la curva quieta, una vez: las garras de fuera resbalan y vuelven a clavarse
		_grip_shown[0] = true
		_grip_pulse = 1.0
		_rebuild_grip()
	_dmg_dirty = true


## El reloj del agarre: el tirón que se apaga, los momentos de la S que pasan (sus surcos, su tirón y la caída) y la caída.
## Devuelve si hay algo que animar.
func _grip_tick(dt: float) -> bool:
	var busy := false
	if curve_on:
		_layout_meter()  # la lupa puede aparecer o irse en cualquier fotograma: el medidor y el plano, en la esquina que deja
	if road_id != CarCurve.ROAD_S:
		_s_jerk = 0.0
	var want := _fear_target()
	if want != _fear_s:
		_fear_s = want if reduce_motion else want + (_fear_s - want) * exp(-dt / FEAR_TAU)
		if absf(_fear_s - want) < 1e-4:
			_fear_s = want
	if curve_on and mode == MovingCarState.MODE_HOLD:
		busy = true  # en curva siempre tiene vida
	if _grip_pulse > 0.0:
		_grip_pulse = maxf(0.0, _grip_pulse - dt / GRIP_PULSE_S)
		busy = true
	if curve_on and _grip.has("events") and is_finite(_s_dur):
		var wrapped := _s_t < _grip_prev_s
		if wrapped:
			_grip_latched = false  # la S vuelve a empezar: vuelve a estar agarrado
		var changed := false
		var events: Array = _grip.events
		for i in events.size():
			var e: Dictionary = events[i]
			var t := float(e.tS)
			var passed := (_grip_prev_s < t and t <= _s_t) if not wrapped else (t > _grip_prev_s or t <= _s_t)
			if not passed:
				continue
			if String(e.kind) == CarCurveGrip.KIND_FALL:
				_grip_latched = true
				holds = false
				exit_mode = "lado" if bool(e.get("sideways", true)) else "atras"
			else:
				_grip_pulse = 1.0
			_exit_side = float(e.side)
			if not _grip_shown.has(i):
				_grip_shown[i] = true
				changed = true
		_grip_prev_s = _s_t
		if changed:
			_rebuild_grip()
			_apply_damage()
	# la caída: empieza cuando deja de aguantar en curva y se aparta por el lado de fuera
	var falling := curve_on and mode == MovingCarState.MODE_HOLD and not holds and exit_mode == "lado"
	if falling and _grip_fall_t < 0.0:
		_grip_fall_t = 0.0
		_grip_fall_side = _exit_side
		if not _grip.has("events") and not _grip.is_empty() and not _grip_shown.has(0):
			_grip_shown[0] = true
			_rebuild_grip()
			_apply_damage()
	elif not falling:
		_grip_fall_t = -1.0
	if _grip_fall_t >= 0.0 and _grip_fall_t < _fall_total():
		_grip_fall_t = _fall_total() if reduce_motion else minf(_grip_fall_t + dt, _fall_total())
		busy = true
	return busy


static func _fall_total() -> float:
	return FALL_SLIDE_S + FALL_HANG_S + FALL_DROP_S


## Los surcos de lo que se ha recolocado (y de la caída), desde las puntas de las garras del lado de fuera, en la dirección de
## la fuerza (deg, hacia fuera de la curva), con las medidas del motor (hondura, ancho y capa).
func _rebuild_grip() -> void:
	var out := CarDamage.empty()
	if _grip.is_empty() or CarDamage.side_zone(hold_zone) or _hold_ctx.is_empty():
		_dmg_grip = {}
		return
	var grooves: Array = []
	if _grip.has("events"):
		var events: Array = _grip.events
		var k := 0
		for i in events.size():
			if not _grip_shown.has(i):
				continue
			var e: Dictionary = events[i]
			var fall := String(e.kind) == CarCurveGrip.KIND_FALL
			grooves.append_array(_grip_grooves(int(e.claws), float(e.lenMm), float(e.deg), e.marks, float(e.side), k, fall))
			k += 1
	elif _grip_shown.has(0):
		var fall2 := bool(_grip.falls)
		var mk: Dictionary = _grip.fallMarks if fall2 else _grip.marks
		grooves = _grip_grooves(int(_grip.slips), float(_grip.lenMm), float(_grip.deg), mk, float(_grip.side), 0, fall2)
	out.grooves = grooves.slice(maxi(0, grooves.size() - CarDamage.MAX_GROOVES))
	if not grooves.is_empty():
		var g0: Dictionary = grooves[-1]
		out.focus = CarDamage.surface_point(g0.a, CarDamage.AXIS_TOP, _top)
		out.focus_m = 0.08
	_dmg_grip = out
	_dmg_dirty = true
	grip_sets += 1


## Los surcos de n garras que resbalan len_mm en la dirección deg (grados desde «hacia atrás», + a la derecha, como
## CarCurve.mark_deg), de las puntas de las garras que tocan el panel, las del lado de fuera (side) primero; k: la
## recolocación (las de la S se apartan un poco a lo largo). fall: al caerse, todas, hasta el borde del panel.
func _grip_grooves(n: int, len_mm: float, deg: float, marks: Dictionary, side: float, k: int, fall: bool) -> Array:
	var out: Array = []
	if marks.is_empty() or n <= 0:
		return out
	var target: Dictionary = _hold_ctx.get("target", {})
	var glass := bool(_hold_ctx.get("glass", false))
	var layer := CarDamage.mark_layer(marks, target)
	var depth := float(marks.get("depthUm", 0.0))
	if glass:
		layer = 0 if depth > 0.0 else -1
	var hw := float(marks.get("widthUm", 0.0)) / 2.0e6
	if layer < 0 or hw <= 0.0 or not Js.truthy(marks.get("scratched", depth > 0.0)):
		return out
	var tips: Array = _contact_tips.duplicate() if not _contact_tips.is_empty() else contact_tips(int(_hold_ctx.get("claws", 4)))
	var want := tips.size() if fall else n
	if tips.size() < maxi(want, 1):
		# sin las puntas de la pose (sin animal en 3D), desde las patas, de dibujo, como las marcas de siempre
		tips = []
		var feet: Vector3 = _hold_ctx.get("feet", Vector3.ZERO)
		var claws := maxi(int(_hold_ctx.get("claws", 4)), n)
		for r: Dictionary in CarDamage.claw_rakes(feet, CarDamage.AXIS_TOP, claws, 1 if claws <= 2 else 2, kind, 0.0, -1.0,
				CarShape.PANELS.get(hold_zone, Vector2(0.0, CAR_L)), 0.0, 0, 0, _top, "%s|agarre" % hold_zone):
			var c: Vector2 = r.a
			tips.append(Vector3(c.x, 0.0, c.y))
	tips.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z * side > b.z * side)
	var th := deg_to_rad(deg)
	var d := Vector2(-cos(th), sin(th))
	var panel: Vector2 = CarShape.PANELS.get(hold_zone, Vector2(0.0, CAR_L))
	var edge := half_w() - 0.05
	var lip := CarDamage.lip_of(marks)
	var len_m := len_mm / 1000.0
	var count := tips.size() if fall else mini(n, tips.size())
	for t: Vector3 in tips.slice(0, count):
		var a := Vector2(t.x, t.z) + d * REGRIP_STEP_M * float(k)
		var b := a + d * len_m
		if fall and absf(d.y) > 1e-6:
			# hasta el borde del panel por el lado de fuera, como mucho lo que resbala
			var reach := (edge * signf(d.y) - a.y) / d.y
			b = a + d * clampf(reach, 0.0, len_m)
		b.x = clampf(b.x, panel.x, panel.y)
		b.y = clampf(b.y, -edge, edge)
		out.append({ "a": a, "b": b, "hw": hw, "layer": layer, "axis": CarDamage.AXIS_TOP, "hit": 0, "depth_um": depth, "lip": lip })
	return out


## El miedo (dibujo, CarCurveGrip.fear) se suaviza con esta constante de tiempo (s): el cuerpo pasa de un lado al otro en la S
## sin saltos.
const FEAR_TAU := 0.3

var _fear_s := 0.0
var _s_jerk := 0.0


## El miedo con su lado al que quiere ir ahora (de -1 a 1; + empuja a la derecha): en curva, agarrado, el de lo que le pide la
## curva de su agarre (la u del instante en la S) y del tirón de la S; 0 en recta. Cayéndose, todo.
func _fear_target() -> float:
	if not curve_on or mode != MovingCarState.MODE_HOLD:
		return 0.0
	if _grip_fall_t >= 0.0:
		return _grip_fall_side
	if not holds:
		return _fear_s
	return _exit_side * CarCurveGrip.fear(load, _s_jerk)


## Lo que se le nota el esfuerzo ahora (0-1).
func _grip_effort() -> float:
	return absf(_fear_s)


## Las claves de la pose del agarre en curva (el cuerpo de la cetrería las lee: hd3d.gd): si está en curva, el miedo con su lado
## y el tirón de la garra que se recoloca.
func _grip_pose() -> void:
	_pose["curve_on"] = curve_on and mode == MovingCarState.MODE_HOLD
	_pose["curve_fear"] = _fear_s
	_pose["curve_regrip"] = _grip_pulse if not reduce_motion else 0.0
	_pose["curve_fly"] = 1.0 if kind == "ave" and _grip_fall_t >= FALL_SLIDE_S and not reduce_motion else 0.0


## Lo que la vista mueve del animal entero con el agarre en curva (dibujo): al recolocar una garra, el cuerpo da un tirón hacia
## fuera y vuelve; la rapaz que se cae intenta despegar.
func _grip_root(root: Node3D) -> void:
	if _rig_hd() and curve_on and mode == MovingCarState.MODE_HOLD and holds:
		# el cuerpo de alta definición se inclina él (hd3d.gd: con el miedo, girando el cuerpo hacia dentro), con las patas
		# en el techo: la raíz no se inclina, o las patas de fuera se levantarían
		root.rotation.x -= RoadCurve.lean_rad(lat_g)
	var pulse := _grip_pulse if not reduce_motion and holds else 0.0
	if pulse <= 0.0:
		return
	var jerk := sin(pulse * PI)
	root.rotation.x += _exit_side * 0.07 * jerk
	root.position.z += _exit_side * 0.025 * jerk


## La caída en curva (dibujo determinista): resbala hacia fuera hasta el borde del panel con las garras arañando, se queda
## colgando un instante agitando las patas y cae por el lado de fuera, rodando por la carretera y quedando atrás. La rapaz y la
## lechuza, en cambio, abren las alas y aletean: intentan despegar, suben un poco y el aire se las lleva hacia atrás. Devuelve
## si la ha dibujado (si no, lo de siempre).
## Cómo cae este animal (FALL_STYLE): por la variante (el velocirraptor de cine), por la especie del dibujo de alta definición
## o, si no, la voltereta de siempre.
func _fall_style() -> Dictionary:
	if variant == "pelicula":
		return FALL_STYLE.pelicula
	var sp := String(_rig.get("kind")) if _rig != null and _rig.get("kind") != null else ""
	return FALL_STYLE.get(sp, FALL_STYLE[""])


func _grip_fall_draw(base: Vector2, z: float, rot: float, wings: bool) -> bool:
	if not curve_on or _grip_fall_t < 0.0 or reduce_motion:
		return false
	var t := _grip_fall_t
	var side := _grip_fall_side
	var z_edge := side * (half_w() - 0.05)
	var pos := base
	var zz := z
	var roll := 0.0
	var alpha := 1.0
	var bird := kind == "ave"
	if t < FALL_SLIDE_S:
		var f := t / FALL_SLIDE_S
		zz = lerpf(z, z_edge, f * f * (3.0 - 2.0 * f))
		roll = -side * 0.15 * f
	elif t < FALL_SLIDE_S + FALL_HANG_S:
		# colgando del borde: se agarra un instante (tiembla) y empieza a irse
		var f2 := (t - FALL_SLIDE_S) / FALL_HANG_S
		zz = z_edge + side * 0.04 * f2 + 0.01 * sin(_t * 38.0)
		pos.y -= (0.0 if bird else 0.08) * f2 * f2
		roll = -side * (0.15 + 0.35 * f2) * (0.4 if bird else 1.0)
	elif bird:
		# intenta despegar: sube un poco aleteando y el aire se la lleva hacia atrás y hacia fuera
		var fb := clampf((t - FALL_SLIDE_S - FALL_HANG_S) / FALL_DROP_S, 0.0, 1.0)
		zz = z_edge + side * (0.04 + 0.9 * fb)
		pos.y += 0.5 * sin(fb * PI * 0.8) - 0.3 * fb * fb
		pos.x -= FALL_BACK_M * 1.6 * fb * fb
		roll = -side * 0.25 * sin(fb * PI * 3.0)
		alpha = clampf((1.0 - fb) * 3.0, 0.0, 1.0)
	else:
		# cada especie cae a su manera (FALL_STYLE): el tigre gira en el aire y cae de pie, el oso se suelta como un saco y
		# acaba boca arriba, el velocirraptor salta fuera de pie y el de cine se abalanza hacia delante (ficción)
		var st: Dictionary = _fall_style()
		var f3 := clampf((t - FALL_SLIDE_S - FALL_HANG_S) / FALL_DROP_S, 0.0, 1.0)
		var drop := minf(1.0, f3 * 2.2)
		var turn_f := drop * drop * (3.0 - 2.0 * drop)
		zz = z_edge + side * (0.04 + FALL_OUT_M * float(st.out) * minf(1.0, f3 * 1.6))
		pos.y = lerpf(base.y - 0.08, 0.0, drop * drop) + float(st.hop) * sin(drop * PI)
		pos.x += (float(st.ahead) * minf(1.0, f3 * 2.0) - FALL_BACK_M * float(st.back)) * f3 * f3
		roll = -side * (0.5 * (1.0 - turn_f) + float(st.turn) * turn_f)
		# en el suelo: de lado o boca arriba, el cuerpo queda por encima de la calzada
		pos.y = maxf(pos.y, maxf(0.35 * absf(sin(roll)), 0.5 * (1.0 - cos(roll))) * animal_size.x)
		alpha = clampf((1.0 - f3) * 3.0, 0.0, 1.0)
	_place_animal(pos, zz, rot, 1.0, alpha, wings, 1.0)
	if _rig != null:
		var root: Node3D = _rig.get("root")
		root.rotation.x += roll
	return true


# ════════ Luz del sol (unidad 4w) ════════

## La luz elegida en la tarjeta (CarScene.LIGHTS) y el giro del sol (grados, el deslizador del rumbo). Solo dibujo.
var light_pref := CarScene.LIGHT_DEFAULT
var sun_turn := 0.0
## En curva, lo que ha girado el coche (rad, + a la izquierda): la curvatura de verdad bajo él por lo recorrido (en la curva,
## lo que avanza la carretera, a cámara lenta; en la S, su sitio en ella). El sol se queda en el mundo: respecto al coche
## gira al revés, y los reflejos corren por la chapa, los vidrios y las garras.
var _heading := 0.0
var _head_s := NAN


## Elige la luz y el giro del sol (lo pide la tarjeta).
func set_light(id: String, turn_deg := 0.0) -> void:
	if id == light_pref and is_equal_approx(turn_deg, sun_turn):
		return
	light_pref = id
	sun_turn = turn_deg
	if _scene != null:
		_scene.set_light(id, turn_deg)
	_relight()
	_redraw()


## Un fotograma en curva: el rumbo del coche sube con la curvatura k (1/m) por lo recorrido desde el anterior (s_now, m). Un
## salto grande (la S que vuelve a empezar, otra carretera) no cuenta.
func _sun_tick(k: float, s_now: float) -> void:
	if _scene == null:
		return
	var ds := 0.0 if is_nan(_head_s) else s_now - _head_s
	_head_s = s_now
	if absf(ds) > SUN_JUMP_M:
		ds = 0.0
	_heading = wrapf(_heading + k * ds, -PI, PI)
	_scene.set_car_heading(_heading)
	if light_pref != CarScene.LIGHT_DEFAULT and absf(k * ds) > 1e-6:
		_relight()


## En la recta, el sol vuelve a su rumbo.
func _sun_straight() -> void:
	_heading = 0.0
	_head_s = NAN
	if _scene != null:
		_scene.set_car_heading(0.0)


## Lo que se puede avanzar de un fotograma al siguiente sin que sea un salto (m).
const SUN_JUMP_M := 25.0


## Las garras del animal toman el cielo de la luz de ahora (sus copias del material: ClawMaterial.road_light).
func _relight() -> void:
	if _rig != null and _rig.has_method("relight_claws"):
		_rig.call("relight_claws")


# ════════ Cristales (unidad 4v) ════════
# La luneta templada que estalla bajo el animal (el cuarteado, los trozos que caen y los trocitos dentro del coche) y el rótulo
# de lo que tapa al conductor la grieta del parabrisas (o de la luneta que estalla). La física y los textos, del estado.

## Lo que dura el cuarteado y la caída de la luneta (s, a cámara lenta como la ventanilla del golpe) y lo que se hunde el
## animal por el agujero (m, hasta la banqueta de atrás). Dibujo.
const LUNETA_S := SHATTER_S
const LUNETA_SINK_M := 0.68
## El primer plano de la luneta que estalla: lo que se ve en el lado corto (m: el mayor campo del primer plano), lo alto que
## mira (grados sobre el panel) y adónde (m desde el pie de la luneta y del eje): su borde de abajo, con el marco.
const LUNETA_FIELD_M := ClawCloseup.FIELD_MAX
const LUNETA_AIM := Vector2(0.1, 0.3)
const LUNETA_ELEV_DEG := 55.0

## El rótulo de los cristales (MovingCarState.glass_view_note) y la clave del ensayo cuya luneta ha estallado.
var glass_note := ""
var _luneta_key := ""
## Lo que lleva estallada la luneta (s; −1, entera).
var _luneta_t := -1.0


## ¿Es un cristal la zona? (la del golpe con vidrio o una zona donde se agarra con la superficie de vidrio).
static func glass_zone(zone: String) -> bool:
	var iz: Variant = MovingCar.IMPACT_ZONES.get(zone)
	if iz != null:
		return bool(iz.glass)
	return String((MovingCar.ZONES.get(zone, {}) as Dictionary).get("surface", "")) == "vidrio"


func _sync_glass(st: MovingCarState) -> void:
	var rear: Variant = st.rear_now() if mode == MovingCarState.MODE_HOLD else null
	if rear != null and bool(rear.shattered):
		holds = false
		exit_mode = "dentro"  # sin la luneta debajo, se cae por el agujero
		# se va desde el primer fotograma, sin llegar a apoyar las garras (las marcas se rehacen con ellas al apoyarse): los
		# daños de la luneta, ya, sin las puntas
		if _dmg_hold.is_empty() and not _hold_ctx.is_empty():
			_dmg_hold = _twisted(CarDamage.from_hold(_hold_scen, _hold_ctx))
			_dmg_dirty = true
	var note := st.glass_view_note(size.x < NARROW)
	if note != glass_note:
		glass_note = note
		_redraw()


## Lo que ha estallado la luneta en este conjunto de daños (0 o 1).
func _luneta_target() -> float:
	if mode != MovingCarState.MODE_HOLD or _dmg_set.is_empty():
		return 0.0
	return float((_dmg_set.get("shatter", {}) as Dictionary).get("luneta", 0.0))


## Después de poner los daños: la luneta va por donde va su animación (set_damage la pone entera o caída).
func _glass_after_damage() -> void:
	if _scene == null:
		return
	var frag := float((_dmg_set.get("shatter", {}) as Dictionary).get("frag_m", 0.0056))
	if _luneta_target() <= 0.0:
		if _luneta_t >= 0.0:
			_luneta_t = -1.0
			_luneta_key = ""
			if _scene.car.shards != null and _scene.car.shard_floor > 0.0:
				_scene.car.shards.visible = false
		return
	if _luneta_key != _dmg_key:
		_scene.car.set_luneta_shatter(0.0, frag)  # empieza entera: la animación la hace estallar (_glass_step)
	else:
		_scene.car.set_luneta_shatter(clampf(_luneta_t / LUNETA_S, 0.0, 1.0), frag)


## Anima la luneta que estalla: se cuartea, caen los trozos y los trocitos quedan dentro. true mientras se mueve.
func _glass_step(dt: float) -> bool:
	if _scene == null or _luneta_target() <= 0.0:
		return false
	var frag := float((_dmg_set.get("shatter", {}) as Dictionary).get("frag_m", 0.0056))
	var end := LUNETA_S * 0.35 + CarScene.CarModel.SHARD_S
	if _luneta_key != _dmg_key:
		_luneta_key = _dmg_key
		_luneta_t = end if reduce_motion else 0.0
		_scene.car.luneta_shards_start(frag, "%s|luneta" % claw_id)
	elif _luneta_t >= end:
		return false
	else:
		_luneta_t = minf(_luneta_t + dt, end)
	_scene.car.set_luneta_shatter(clampf(_luneta_t / LUNETA_S, 0.0, 1.0), frag)
	_scene.car.shatter_step(maxf(_luneta_t - LUNETA_S * 0.35, 0.0), 0.0)
	return true


## El rótulo de los cristales, abajo, encima del de la cámara lenta (con el halo del fondo, como él).
func _draw_glass_note() -> void:
	if glass_note == "":
		return
	var font := get_theme_default_font()
	var fs := 11
	var at := Vector2(8.0, size.y - 26.0)  # encima del rótulo de la cámara lenta, sin pisarlo
	var w := size.x - 16.0
	_ci.draw_string_outline(font, at, glass_note, HORIZONTAL_ALIGNMENT_LEFT, w, fs, 3, Color(Palette.color("bg"), 0.85))
	_ci.draw_string(font, at, glass_note, HORIZONTAL_ALIGNMENT_LEFT, w, fs, Palette.color("coral"))


## Si la luneta ha estallado y no hay garras que enseñar (el animal ya se va por el agujero), el primer plano mira el agujero
## desde arriba: los trozos que quedan en el marco, el hueco y los trocitos dentro. {} si no.
func _luneta_aim() -> Dictionary:
	if _luneta_target() <= 0.0 or hold_zone != "luneta":
		return {}
	var x := (CarShape.LUNETA_PANEL.x + LUNETA_AIM.x) * _shape.x
	var focus := Vector3(x, surface_y(x), LUNETA_AIM.y)
	var normal := CarDamage.surface_normal(focus, CarDamage.AXIS_TOP, _top)
	return { "focus": focus, "normal": normal, "field": LUNETA_FIELD_M, "dir": -1.0, "cam": 1.0, "below": 0.0, "side": false,
		"elev": LUNETA_ELEV_DEG, "field_min": LUNETA_FIELD_M }


# ════════ Paisaje (unidad 4x) ════════

## La persecución en la recta (la elige la tarjeta; por defecto, la vista de lado de siempre) y el fondo de la persecución
## («campo», por defecto, o «liso»). Solo con el animal quieto encima: el golpe se pinta en la vista de lado.
var chase_straight := false
var scenery_pref := true


## ¿Persecución en la recta? (no en curva: allí manda chase_pref)
func _straight_chase_on() -> bool:
	return not curve_on and chase_straight and active and mode == MovingCarState.MODE_HOLD


## La persecución en la recta (on) o la vista de lado de siempre en la recta (lo pide la tarjeta).
func set_chase_straight(on: bool) -> void:
	if on == chase_straight:
		return
	chase_straight = on
	_redraw()


## «Fondo: campo» o «liso» (lo pide la tarjeta).
func set_scenery(on: bool) -> void:
	scenery_pref = on
	if _scene != null:
		_scene.set_scenery(on)
	_redraw()


## Un fotograma en la recta: la persecución si se ha elegido (la carretera larga sin curva, corriendo con lo recorrido).
func _straight_chase_tick() -> void:
	if _scene == null:
		return
	_scene.set_scenery(scenery_pref)
	var on := _straight_chase_on()
	_scene.set_straight_chase(on)
	if on and _scene.road_chase != null:
		_scene.road_chase.set_road(_road)
		_scene.car.set_steer(0.0)
		_scene.set_roll(0.0)
		_scene.update_chase()
