## Taller · la radial en tus manos: el modo manual de la amoladora contra la chapa, paso a paso (sin nodos).
##
## Petición de Eric: que la radial no arranque sola al abrir su pestaña y que se pueda usar a mano: encenderla,
## acercarla y apartarla de la chapa, llevarla a lo largo del corte, inclinarla y girarla con el ratón o con los
## controles de la pantalla. Este objeto es el estado de esa sesión y su física en cada paso; la escena 3D y la página
## solo pintan su salida (`frame`) y le pasan lo que hace la mano.
##
## En cada paso (step):
##   1. Mano: la mano (el ratón, las teclas o los botones de la pantalla) mueve un objetivo; lo que va por delante del
##      disco es cuánto empuja (de 0 a Radial.PUSH_N).
##   2. Disco: lo sigue; dentro de la chapa solo avanza lo que puede arrancar en ese paso con ese empuje
##      (Radial.cut_capacity: la potencia útil de la radial y el empuje por Archard). Si la mano va más deprisa de lo
##      que arranca empujando a fondo, «demasiado avance».
##   3. Corte: lo que arranca el disco se apunta en un mapa del surco a lo largo de la línea de corte (profundidad,
##      anchura, inclinación, rebaba, pintura quemada, zona caliente y plástico fundido cada DU_MM), con los números de
##      Radial.cut_step: el mismo modelo que cut_panel con las rpm, la profundidad, el ángulo y el avance de ese instante.
##   4. Motor: gatillo, arranque con la corriente limitada, giro fijado con la rueda de velocidad (nunca por encima de
##      las rpm marcadas en el disco, EN 12413) y sostenido por la electrónica mientras la potencia alcanza; si el empuje
##      pide más potencia de la que hay, el balance de energía del rotor lo frena; parada por inercia al soltar el
##      gatillo y desconexión si el giro cae de golpe o el disco se pellizca en el surco (Bosch, «Rückschlagabschaltung»).
##   5. Avisos en directo, cada uno con su fuente, y la salida para la interfaz, la escena 3D y el sonido.
## Cada número lleva su fuente en su constante y en docs/taller/radial-manual.md; lo que no está medido es ESTIMACIÓN,
## con el caso medido más parecido y el supuesto escrito, y lo que es solo de la interfaz se dice.
## Determinista (sin azar ni reloj): la misma secuencia de entradas da la misma salida.
## Unidades: mm y mm/s (avance), rpm, m/s (velocidad periférica), grados, °C, kW (potencia), mm³ y mm³/s.
## Es un simulador educativo, no un procedimiento de taller ni de rescate.
## Uso: const RadialManual = preload("res://core/taller/radial_manual.gd"); var m := RadialManual.new()
##      m.set_trigger(true); m.move_hand(0.0, 2.0); var frame := m.step(1.0 / 60.0)
extends RefCounted

const Radial = preload("res://core/taller/radial.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Panels = preload("res://core/taller/panels.gd")
const Sparks = preload("res://core/taller/sparks.gd")

## Discos y chapas del modo manual: los de la escena 3D, los discos de metal duro y de CBN (unidad 1h) y las tres piezas
## de rescate de panels.gd.
const DISCS := ["fino_1mm", "grueso_3mm", "diamante", "laminas", "metal_duro", "cbn_1mm"]
const PANELS := ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria", "boro-22mnb5", "dp800", "perfil-aluminio"]

# ─────────────────────────────── La radial ───────────────────────────────
## Radial de hasta 125 mm: Bosch GWS 12-125 CIE, con rueda de velocidad de 6 posiciones (2.800, 4.500, 6.300, 8.200,
## 9.800 y 11.500 rpm en vacío, «valores orientativos»; para tronzar, la 6), 1.200 W de entrada y 640 W útiles,
## electrónica de giro constante («mantiene casi constante el giro en vacío y con carga»), limitación de la corriente de
## arranque, protección contra el rearranque y desconexión por rebote («si la radial rebota de golpe, p. ej. porque el
## disco se bloquea en el corte, se corta electrónicamente la corriente del motor»; para volver a arrancar hay que
## poner el interruptor en apagado y encenderlo otra vez). Sin freno: no consta en sus datos técnicos.
const SRC_BOSCH := "Bosch Power Tools, «GWS Professional», instrucciones de uso 1 609 92A 5RE (16-2-2022): datos técnicos de la GWS 12-125 CIE, «Drehzahlvorwahl», «Konstantelektronik», «Anlaufstrombegrenzung», «Wiederanlaufschutz», «Rückschlagabschaltung» e indicaciones de seguridad para tronzar de EN IEC 62841-2-3"
const CITE_BOSCH := "Bosch, instrucciones GWS Professional 1 609 92A 5RE (2022)"
const MACHINE_125 := {
	"id": "gws_12_125_cie", "name": "Bosch GWS 12-125 CIE", "max_diameter_mm": 125.0, "input_kw": 1.2, "power_kw": 0.64,
	"rpm_max": 11500.0, "dial_rpm": [2800.0, 4500.0, 6300.0, 8200.0, 9800.0, 11500.0], "constant_electronic": true,
	"soft_start": true, "kickback_stop": true, "restart_protection": true, "source": SRC_BOSCH, "quality": "primary",
}
## Para 178-230 mm: la radial de 230 mm de radial.gd (Radial.GRINDERS), de giro fijo. Sin rueda de velocidad, ni
## electrónica de giro constante, ni desconexión por rebote: no constan en los datos que tenemos de ella.

# ─────────────────────────────── El motor ───────────────────────────────
## Arranque: con la corriente de arranque limitada («limita la potencia al encender» para que funcione con un fusible
## de 16 A: Bosch) el giro sube hacia el fijado con una constante de tiempo SPINUP_S / 3 (llega al 95 % en SPINUP_S).
## Bosch no da el tiempo. ESTIMACIÓN con el caso más parecido publicado: un módulo de arranque suave para herramientas
## de motor de escobillas, que «gana la velocidad plena en poco tiempo tras encender (ca. 1-2 segundos)» (ULFATEC,
## módulo de arranque suave de hasta 20 A, descripción del fabricante); se toma el centro, 1,5 s.
const SPINUP_S := 1.5
const SPINUP_TAU_S := SPINUP_S / 3.0
## Parada al soltar el gatillo: sin freno (no consta en los datos técnicos de la GWS 12-125 CIE), el disco sigue
## girando y lo frenan sus pérdidas. Tiempo de parada medido en 11 radiales de cable para disco de 115 mm (Project Farm,
## «Best Corded Angle Grinder», 23-2-2023): 3,4 · 4,6 · 5,1 · 5,3 · 5,3 · 5,9 · 6,2 · 6,4 · 6,7 · 7,0 · 7,3 s.
## ESTIMACIÓN: la GWS 12-125 CIE no se midió; se toma la mediana (5,9 s) desde el giro máximo de cada radial, con un
## giro que cae exponencialmente (pérdidas proporcionales al giro, supuesto) hasta STOP_RPM. Las radiales con freno de
## Metabo paran el disco en 2 s como mucho (Hilsenbeck, Metabo, jornada de la DGUV de 20-6-2024).
const COAST_STOP_S := 5.9
## Por debajo de estas rpm (media vuelta por segundo) el disco se da por parado.
const STOP_RPM := 30.0
## Disco bloqueado en el corte: cae casi en seco. ESTIMACIÓN con el caso medido más parecido: la velocidad de la hoja de
## una sierra de mesa durante un rebote, registrada a 1 muestra por milisegundo (Bosch, patente US 11 571 831 B2,
## fig. 4): tras 100 ms de caída suave, una caída rápida de unos 150 ms. τ = 50 ms la baja al 5 % en esos 150 ms.
const JAM_TAU_S := 0.05
## Desconexión por rebote: corta la corriente cuando el giro cae de golpe (Bosch). El umbral de la radial no está
## publicado. ESTIMACIÓN con el umbral publicado más parecido, el de la sierra de mesa de la misma patente: la hoja por
## debajo del 98 % de su velocidad media en 10 de las 15 últimas muestras de 1 ms, es decir, caer más de un 2 % en
## unos 15 ms.
const KICKBACK_DROP := 0.02
const KICKBACK_WINDOW_S := 0.015
## Caída del giro a plena carga de un motor universal sin electrónica de giro constante: 0,30, la misma ESTIMACIÓN que
## core/taller/machine_sound.gd (motor universal, Chapman 2012). Con la electrónica de giro constante no cae mientras la
## potencia alcanza («mantiene el giro casi constante en vacío y con carga»: Bosch).
const DROOP_FULL_LOAD := 0.30
## Por debajo de esta profundidad metida en la chapa (mm) no se da el avance posible (sería dividir por casi cero).
## Guarda numérica, no un dato.
const ENGAGED_MIN_MM := 0.02
## «Arrancando» hasta el 95 % del giro fijado (el mismo 95 % de SPINUP_S); por debajo del 90 %, cortar es hacerlo sin
## que el disco haya llegado a su velocidad (umbral del aviso, elección de la interfaz).
const SPUN_UP_FRACTION := 0.95
const FULL_SPEED_FRACTION := 0.9

# ─────────────────────────────── La mano y el disco ───────────────────────────────
## Todo lo de este bloque es de la interfaz o del cálculo (resolución, recorridos, cómo se traduce la mano), no datos.
## Mapa del surco: una muestra cada DU_MM a lo largo de la línea de corte, de u = 0 a line_mm.
const DU_MM := 0.25
## Línea de corte por defecto: la chapa de la escena 3D mide 230 mm (app/taller/radial3d/panel_builder.gd, U_MAX).
const LINE_MM := 230.0
## La radial puede salir de la chapa por los dos extremos (para entrar por el canto).
const U_MARGIN_MM := 80.0
## Profundidad del punto más bajo del disco bajo la cara pintada: de apartada (DEPTH_MIN_MM, por encima de la chapa) a
## DEPTH_BELOW_MM por debajo de la cara interior (lo que se deja asomar el disco al tronzar de lado a lado).
const DEPTH_MIN_MM := -80.0
const DEPTH_BELOW_MM := 6.0
## Se da por tocando la chapa a menos de esta distancia (mm).
const TOUCH_MM := 0.05
## Reposo (apartada): encima del principio de la línea de corte, 30 mm por encima de la chapa, recta y alineada.
const REST_U_MM := 30.0
const REST_DEPTH_MM := -30.0
## Recorrido de la inclinación (el del deslizador del ángulo).
const TILT_MAX_DEG := 45.0
## Para meter el disco en la chapa tiene que ir alineado con la línea de corte: si le falta menos de esto, se alinea
## solo al entrar (la escena corta a lo largo de una línea marcada); si le falta más, no entra. Ayuda de la interfaz.
const ALIGN_SNAP_DEG := 6.0
## Empuje de la mano: lo que la mano va por delante del disco es cuánto empuja, como un muelle entre la mano y la radial:
## de 0 a Radial.PUSH_N (el empuje típico del operario del modelo de corte, ESTIMACIÓN de radial.gd) al llegar a
## LEAD_MAX_MM a lo largo o a LEAD_DEPTH_MAX_MM hacia dentro. Más allá la mano no puede adelantarse: lo que el ratón se
## mueve de más se pierde, como cuando la radial no deja empujar más.
const LEAD_MAX_MM := 3.0
const LEAD_DEPTH_MAX_MM := 1.0
## Por debajo de una micra de adelanto la mano ya no empuja (guarda numérica: sin ella el disco se acercaría a la mano
## sin llegar nunca, arrancando cantidades ínfimas).
const LEAD_EPS_MM := 0.001
## Velocidad de la mano: media móvil con esta constante de tiempo («avance pedido», para las lecturas y los avisos).
const HAND_TAU_S := 0.12
## Media móvil del avance real que se enseña.
const FEED_TAU_S := 0.2
## Un paso nunca simula más de esto (un fotograma lento no hace saltar el disco).
const MAX_DT := 0.1
## Pellizco: el disco roza las paredes del surco cuando se desplaza de lado más que la mitad de la holgura del surco
## (surco − espesor = Radial.KERF_EXTRA_MM, la holgura medida por Awan et al. 2022) y se bloquea cuando lo hace más que
## su propio espesor: tendría que cortar con la cara, y un disco de corte no corta de lado (EN 62841-2-3). Ese umbral es
## un supuesto geométrico, no una medida. Solo cuenta un surco de al menos PINCH_MIN_DEPTH_MM (guarda para no tomar por
## surco un roce de la superficie).
const PINCH_MIN_DEPTH_MM := 0.2

# ─────────────────────────────── Escenario de las chispas ───────────────────────────────
## EJEMPLO de dibujo para los avisos de las chispas, no un coche concreto (la hoja de rescate ISO 17840 de cada modelo
## dice dónde está cada cosa). En las piezas de rescate, el generador de gas del airbag de cortina va en el larguero
## del techo, más allá del extremo u = line_mm (el pilar B sube hasta el techo). Coordenadas de la chapa en mm: u a lo
## largo de la línea de corte, n hacia fuera de la cara pintada, l de lado; r_mm, el radio de la zona que se dibuja
## (el cilindro de la escena mide 2·r_mm de largo). Posición y tamaño son de dibujo.
const HAZARD_AIRBAG := { "u_mm": 380.0, "n_mm": 70.0, "l_mm": 0.0, "r_mm": 40.0 }

## Citas cortas de los avisos en directo (las completas, en docs/taller/radial-manual.md).
const CITE_SAFETY := "EN 62841-2-3, indicaciones para tronzar (" + CITE_BOSCH + ")"
const CITE_HOT_WORK := "DHS SAVER TechNote «Battery-Powered Rescue Tools» (2022); OSHA 4188 (2022); EN 62841-2-3"
const CITE_AIRBAG := "Moore R., Firehouse, 1-10-2005; ISO 17840-1:2022"
## Niveles de los avisos, del más grave al menos.
const LEVELS := ["peligro", "aviso", "nota"]
## Avisos del modelo (Radial) que se enseñan cuando el disco toca la chapa.
const CONTACT_CODES := ["sin_corte", "disco_no_corta", "disco_inadecuado", "diamante_ferrico", "sic_ferrico",
	"diamante_fundicion", "embotamiento", "polvo_aluminio"]

# ─────────────────────────────── Estado ───────────────────────────────
var disc_id := "fino_1mm"
var diameter_mm := 125.0
var panel_id := "acero-dulce"
var line_mm := LINE_MM
## rpm que se piden con la rueda de velocidad (o con el deslizador de la página).
var dial_request_rpm := 11500.0
## El dedo en el gatillo.
var trigger := false
## Desconectada por rebote (el disco se bloqueó): hasta que se suelte el gatillo no vuelve a arrancar.
var tripped := false
## Motor calado con el disco bloqueado (radial sin desconexión por rebote): hasta que se saca el disco de la chapa.
var stalled := false
## Giro real del disco (rpm).
var rpm := 0.0
## Pose real del disco: u (mm, su punto más bajo a lo largo de la línea de corte), profundidad de ese punto bajo la cara
## pintada (mm; negativa = apartado por encima), inclinación sobre la línea de corte (°, 0 = perpendicular a la chapa) y
## giro alrededor de la normal de la chapa (°, 0 o ±180 = alineada con la línea; 180 = dada la vuelta: el disco gira al
## revés respecto al corte).
var u_mm := REST_U_MM
var depth_mm := REST_DEPTH_MM
var tilt_deg := 0.0
var yaw_deg := 0.0
## Lo que pide la mano (la pose objetivo) y sus velocidades continuas (botones y teclas, mm/s).
var hand_u := REST_U_MM
var hand_depth := REST_DEPTH_MM
var hand_vu := 0.0
var hand_vdepth := 0.0
## Contadores de la sesión.
var jams := 0
var disc_wear_mm3 := 0.0
var removed_mm3 := 0.0
var cutting_time_s := 0.0
var time_s := 0.0
## Cambia cada vez que cambia el mapa del surco (la escena vuelve a subir su textura).
var map_version := 0
## Última salida de step().
var frame: Dictionary = {}
## Muestras del mapa del surco.
var n := 0

## Mapa del surco en el formato de la textura de la escena: 2 filas × n muestras × 4 floats.
##   fila 0: profundidad cortada (mm) · semiancho del surco en la cara pintada (mm) · tan(inclinación) · rebaba del lado −
##   (mm); fila 1: rebaba del lado + (mm) · pintura quemada (mm desde el borde del surco) · zona > 200 °C (mm) · fundido.
var _map := PackedFloat32Array()
var _clean := PackedFloat32Array()  # limpieza (0-10) de cada muestra atravesada; −1 si no lo está
var _through_count := 0
var _groove_count := 0
var _clean_sum := 0.0
var _clean_count := 0
var _panel: Dictionary = {}
var _machine: Dictionary = {}
var _t_total := 1.0
var _prev_hand_u := REST_U_MM
var _prev_hand_depth := REST_DEPTH_MM
var _hand_speed := 0.0  # mm/s, con signo (a lo largo)
var _hand_speed_depth := 0.0
var _feed_shown := 0.0
var _push_frac := 0.0  # empuje de la mano en este paso, de 0 a 1 (× Radial.PUSH_N)
var _overload_x := 0.0  # potencia que pide el empuje / potencia disponible (> 1: el motor pierde vueltas)
var _deficit_kw := 0.0  # lo que falta de potencia (kW; 0 si alcanza)
var _p_avail_kw := 0.0  # potencia útil al giro del principio del paso (kW)
var _plunge_cap := 0.0  # mm/s a los que puede bajar empujando a fondo (0 si no hay chapa bajo el disco)
var _push_limit := 30.0  # N · empuje a partir del que falta potencia (Radial.PUSH_N si nunca falta)
var _saturated := false  # la mano empuja a fondo y aun así va por delante del disco
var _last_power_kw := 0.0
var _spinup := false
var _start_in_cut_t := 0.0  # s que quedan del aviso de arranque dentro del corte
var _jam_t := 10.0  # s desde el último bloqueo
var _dial_attempt := false
var _setup_warnings: Array = []


func _init(p_disc: String = "fino_1mm", p_panel: String = "acero-dulce", p_diameter: float = 125.0) -> void:
	disc_id = p_disc if Abrasives.DISCS.has(p_disc) else "fino_1mm"
	panel_id = p_panel if Panels.PANELS.has(p_panel) else "acero-dulce"
	diameter_mm = p_diameter
	_machine = machine_for(diameter_mm)
	dial_request_rpm = float(_machine["rpm_max"])
	_load_panel()
	_refresh_setup()
	frame = step(0.0)


# ─────────────────────────────── Máquina y rueda de velocidad ───────────────────────────────
## Radial del modo manual para un diámetro de disco (MACHINE_125 hasta 125 mm; si no, la grande de Radial.GRINDERS).
static func machine_for(diameter: float) -> Dictionary:
	if diameter <= float(MACHINE_125["max_diameter_mm"]):
		return MACHINE_125
	var g: Dictionary = Radial.GRINDERS[Radial.GRINDERS.size() - 1]
	return {
		"id": "gws_22_230_p", "name": g["name"], "max_diameter_mm": g["max_diameter_mm"], "input_kw": g["input_kw"],
		"power_kw": g["power_kw"], "rpm_max": g["rpm"], "dial_rpm": [], "constant_electronic": false,
		"soft_start": false, "kickback_stop": false, "restart_protection": false,
		"source": "Radial.GRINDERS (radial.gd): Bosch, ficha GWS 22-230 P; potencia útil estimada con el rendimiento de la de 125 mm",
		"quality": g["quality"],
	}


## rpm de la rueda en una posición (de 1 al número de posiciones; entre dos, interpolada: los valores de Bosch son
## orientativos). Sin rueda, las rpm de la máquina.
static func dial_rpm_at(machine: Dictionary, pos: float) -> float:
	var table: Array = machine["dial_rpm"]
	if table.is_empty():
		return float(machine["rpm_max"])
	var x := clampf(pos, 1.0, float(table.size())) - 1.0
	var i := mini(int(floor(x)), table.size() - 2)
	return lerpf(float(table[i]), float(table[i + 1]), x - float(i))


## Posición de la rueda (de 1 a 6, con decimales) que da esas rpm; 0 si la máquina no tiene rueda.
static func dial_pos_of(machine: Dictionary, rpm_value: float) -> float:
	var table: Array = machine["dial_rpm"]
	if table.is_empty():
		return 0.0
	if rpm_value <= float(table[0]):
		return 1.0
	for i in range(1, table.size()):
		if rpm_value <= float(table[i]):
			var a := float(table[i - 1])
			var b := float(table[i])
			return float(i) + (rpm_value - a) / (b - a)
	return float(table.size())


## rpm pedidas tras mover la rueda k posiciones enteras (teclas + y −, Alt + rueda del ratón): desde una posición
## intermedia, la primera muesca lleva a la entera más próxima en ese sentido.
static func dial_step_rpm(machine: Dictionary, from_rpm: float, k: int) -> float:
	var table: Array = machine["dial_rpm"]
	if table.is_empty() or k == 0:
		return float(machine["rpm_max"]) if table.is_empty() else from_rpm
	var pos := dial_pos_of(machine, from_rpm)
	var base := floorf(pos + 1e-6) if k > 0 else ceilf(pos - 1e-6)
	return dial_rpm_at(machine, clampf(base + float(k), 1.0, float(table.size())))


## Límite del disco (rpm): las marcadas en el disco, las de la tabla de EN 12413 o las de la fórmula (Radial.disc_check).
func disc_limit_rpm() -> float:
	return float(Radial.disc_check({ "disc_id": disc_id, "diameter_mm": diameter_mm, "rpm": 0.0 })["limit_rpm"])


## Giro que fija la rueda (rpm en vacío): lo pedido dentro del recorrido de la rueda (o el giro fijo de la máquina) y
## nunca por encima de lo marcado en el disco.
func set_rpm() -> float:
	var table: Array = _machine["dial_rpm"]
	var n_set := float(_machine["rpm_max"])
	if not table.is_empty():
		n_set = clampf(dial_request_rpm, float(table[0]), float(table[table.size() - 1]))
	return minf(n_set, disc_limit_rpm())


## La radial que lleva el disco ahora.
func machine() -> Dictionary:
	return _machine


# ─────────────────────────────── Lo que hace la mano ───────────────────────────────
## Mueve la mano: mm a lo largo de la línea de corte y mm hacia dentro de la chapa (positivo acerca, negativo aparta).
func move_hand(du_mm: float, ddepth_mm: float) -> void:
	hand_u = clampf(hand_u + du_mm, -U_MARGIN_MM, line_mm + U_MARGIN_MM)
	hand_depth = clampf(hand_depth + ddepth_mm, DEPTH_MIN_MM, _t_total + DEPTH_BELOW_MM)


## Gira la mano: el giro de la radial alrededor de la normal de la chapa y la inclinación del disco (grados).
func turn_hand(dyaw_deg: float, dtilt_deg: float) -> void:
	set_yaw(yaw_deg + dyaw_deg)
	set_tilt(tilt_deg + dtilt_deg)


## Velocidad continua de la mano (botones que se mantienen pulsados y teclas): mm/s a lo largo y hacia dentro.
func set_hand_velocity(vu_mm_s: float, vdepth_mm_s: float) -> void:
	hand_vu = vu_mm_s
	hand_vdepth = vdepth_mm_s


func set_tilt(deg: float) -> void:
	tilt_deg = clampf(deg, -TILT_MAX_DEG, TILT_MAX_DEG)


## Giro de la radial, de −180 a 180°.
func set_yaw(deg: float) -> void:
	yaw_deg = fposmod(deg + 180.0, 360.0) - 180.0


## Da la vuelta a la radial (180°): el disco gira al revés respecto al corte y las chispas salen hacia el otro lado.
func flip() -> void:
	set_yaw(yaw_deg + 180.0)


func set_trigger(on: bool) -> void:
	if on and not trigger:
		if _touching(u_mm, depth_mm):
			_start_in_cut_t = 4.0
		_spinup = true
	trigger = on
	if not on:
		tripped = false  # tras la desconexión por rebote, para volver a arrancar hay que apagar el interruptor (Bosch)


func toggle_trigger() -> void:
	set_trigger(not trigger)


## rpm pedidas con la rueda de velocidad (la radial nunca pasará de las marcadas en el disco).
func set_dial_rpm(value: float) -> void:
	dial_request_rpm = maxf(value, 0.0)


## Otro disco. Para cambiarlo hay que parar la radial y sacarla: queda apagada y apartada, sobre el mismo punto de la
## línea. El corte hecho se queda y el disco nuevo empieza sin gastar.
func set_disc(id: String) -> void:
	if not Abrasives.DISCS.has(id) or id == disc_id:
		return
	disc_id = id
	disc_wear_mm3 = 0.0
	_stop_and_withdraw()
	_refresh_setup()


## Otro diámetro de disco (y la radial que lo lleva): también se para y se aparta. El corte hecho se queda.
func set_diameter(d: float) -> void:
	if d == diameter_mm:
		return
	diameter_mm = d
	_machine = machine_for(d)
	disc_wear_mm3 = 0.0
	_stop_and_withdraw()
	_refresh_setup()


## Otra chapa: una chapa nueva, sin cortar; la radial se aparta (si estaba en marcha, sigue en marcha).
func set_panel(id: String) -> void:
	if not Panels.PANELS.has(id) or id == panel_id:
		return
	panel_id = id
	_load_panel()
	_withdraw()
	_refresh_setup()


## Longitud de la línea de corte (mm): la de la chapa que dibuja la escena. Empieza una chapa nueva.
func set_line_mm(length: float) -> void:
	line_mm = maxf(length, 10.0)
	_load_panel()
	_withdraw()


## Chapa nueva, sin cortar (el botón «Reiniciar chapa»): la radial se aparta; el disco y su desgaste se quedan.
func reset_panel() -> void:
	_load_panel()
	_withdraw()


## Apaga la radial, la para y la aparta (al abrir la pestaña: nada arranca solo). El corte hecho se queda.
func park() -> void:
	trigger = false
	tripped = false
	stalled = false
	rpm = 0.0
	hand_vu = 0.0
	hand_vdepth = 0.0
	u_mm = REST_U_MM
	depth_mm = REST_DEPTH_MM
	tilt_deg = 0.0
	yaw_deg = 0.0
	hand_u = u_mm
	hand_depth = depth_mm
	_prev_hand_u = hand_u
	_prev_hand_depth = hand_depth
	_clear_load()
	_spinup = false
	_start_in_cut_t = 0.0
	_jam_t = 10.0
	frame = step(0.0)


## Aparta la radial de la chapa (sobre el mismo punto de la línea, recta): la pose y la mano, sin tocar el motor.
func _withdraw() -> void:
	depth_mm = REST_DEPTH_MM
	hand_depth = REST_DEPTH_MM
	hand_u = u_mm
	hand_vu = 0.0
	hand_vdepth = 0.0
	_prev_hand_u = hand_u
	_prev_hand_depth = hand_depth
	_clear_load()


## Olvida la velocidad de la mano, el empuje y la carga del motor (la radial queda en el aire, sin empujar).
func _clear_load() -> void:
	_hand_speed = 0.0
	_hand_speed_depth = 0.0
	_feed_shown = 0.0
	_push_frac = 0.0
	_overload_x = 0.0
	_deficit_kw = 0.0
	_saturated = false
	_plunge_cap = 0.0
	_last_power_kw = 0.0


## Para la radial y la aparta (para cambiar el disco o la radial hay que pararla y sacarla).
func _stop_and_withdraw() -> void:
	trigger = false
	tripped = false
	stalled = false
	rpm = 0.0
	_spinup = false
	_withdraw()


## Avisos fijos del montaje (disco, diámetro y chapa): los del modelo con las rpm que fija la rueda. De aquí sale el de
## disco para tronzadora fija, que vale aunque el disco no toque la chapa.
func _refresh_setup() -> void:
	_setup_warnings = Radial.cut_capacity({ "disc_id": disc_id, "diameter_mm": diameter_mm, "rpm": set_rpm(),
		"panel_id": panel_id })["warnings"]


func _load_panel() -> void:
	_panel = Panels.get_panel(panel_id)
	_t_total = Panels.total_thickness_mm(_panel)
	n = int(round(line_mm / DU_MM)) + 1
	_map = PackedFloat32Array()
	_map.resize(n * 8)
	_map.fill(0.0)
	_clean = PackedFloat32Array()
	_clean.resize(n)
	_clean.fill(-1.0)
	_through_count = 0
	_groove_count = 0
	_clean_sum = 0.0
	_clean_count = 0
	removed_mm3 = 0.0
	cutting_time_s = 0.0
	hand_depth = minf(hand_depth, _t_total + DEPTH_BELOW_MM)
	depth_mm = minf(depth_mm, _t_total + DEPTH_BELOW_MM)
	map_version += 1


# ─────────────────────────────── El paso ───────────────────────────────
## Avanza dt segundos y devuelve la salida (frame; ver _frame).
func step(dt: float) -> Dictionary:
	dt = clampf(dt, 0.0, MAX_DT)
	time_s += dt
	var disc: Dictionary = Abrasives.DISCS[disc_id]
	var limit := disc_limit_rpm()
	var n_set := set_rpm()
	_dial_attempt = dial_request_rpm > limit + 1e-9

	# 1. La mano: velocidades continuas y su media
	if hand_vu != 0.0 or hand_vdepth != 0.0:
		move_hand(hand_vu * dt, hand_vdepth * dt)
	if dt > 0.0:
		var k := 1.0 - exp(-dt / HAND_TAU_S)
		_hand_speed += ((hand_u - _prev_hand_u) / dt - _hand_speed) * k
		_hand_speed_depth += ((hand_depth - _prev_hand_depth) / dt - _hand_speed_depth) * k
	_prev_hand_u = hand_u
	_prev_hand_depth = hand_depth

	var powered := trigger and not tripped and not stalled
	var p_max := float(_machine["power_kw"])
	# Potencia útil: la nominal mientras tiene corriente, a cualquier giro, como en cut_panel (supuesto: un motor
	# universal no pierde potencia al bajar de vueltas, porque su par sube: Chapman 2012); sin corriente, ninguna
	var p_avail := p_max if powered else 0.0
	_p_avail_kw = p_avail
	_jam_t += dt
	_start_in_cut_t = maxf(_start_in_cut_t - dt, 0.0)

	# 2. El empuje de la mano (lo que va por delante del disco) y lo que el disco puede arrancar con él. Lejos de la chapa
	# no hace falta preguntarlo al modelo. Sin empuje se pregunta con el empuje entero, para las lecturas y los avisos,
	# pero el disco no arranca nada.
	var from_u := u_mm
	var from_d := depth_mm
	var want_u := hand_u
	var want_d := hand_depth
	var lead_u := absf(want_u - from_u)
	var lead_d := maxf(want_d - from_d, 0.0)
	_push_frac = 0.0
	if lead_u >= LEAD_EPS_MM or lead_d >= LEAD_EPS_MM:
		_push_frac = clampf(maxf(lead_u / LEAD_MAX_MM, lead_d / LEAD_DEPTH_MAX_MM), 0.0, 1.0)
	var cap: Dictionary
	if maxf(from_d, want_d) > -1.0:
		cap = Radial.cut_capacity({ "disc_id": disc_id, "diameter_mm": diameter_mm, "rpm": rpm, "angle_deg": tilt_deg,
			"panel_id": panel_id, "power_kw": maxf(p_avail, 1e-9),
			"push_n": Radial.PUSH_N * (_push_frac if _push_frac > 0.0 else 1.0) })
	else:
		cap = _air_capacity()
	var q_cap: float = cap["q_cap_mm3_s"] if _push_frac > 0.0 else 0.0
	# Lo que arrancaría empujando a fondo (el empuje de Archard es proporcional a la fuerza): la lectura «puede»
	var q_full: float = cap["q_cap_mm3_s"]
	var q_push_full := float(cap["q_push_mm3_s"]) / (_push_frac if _push_frac > 0.0 else 1.0)
	if _push_frac > 0.0 and is_finite(q_push_full):
		q_full = minf(float(cap["q_power_mm3_s"]), q_push_full)
	# Empuje a partir del que el motor pierde vueltas: el que arranca justo lo que da la potencia
	_push_limit = Radial.PUSH_N
	if is_finite(q_push_full) and q_push_full > 0.0:
		_push_limit = Radial.PUSH_N * clampf(float(cap["q_power_mm3_s"]) / q_push_full, 0.0, 1.0)
	var kerf: float = cap["kerf_mm"]
	var kerf_s: float = cap["kerf_surface_mm"]
	var cos_t := cos(deg_to_rad(tilt_deg))
	# Al entrar en la chapa, el disco se alinea con la línea de corte si le falta poco; si le falta mucho, no entra
	var yaw_off := rad_to_deg(asin(clampf(absf(sin(deg_to_rad(yaw_deg))), 0.0, 1.0)))
	if want_d > 0.0 and not _touching(from_u, from_d) and yaw_off > 0.0 and yaw_off < ALIGN_SNAP_DEG:
		set_yaw(0.0 if cos(deg_to_rad(yaw_deg)) >= 0.0 else 180.0)
		yaw_off = 0.0
	var misaligned := yaw_off >= ALIGN_SNAP_DEG and not _touching(from_u, from_d)
	var solid := kerf_s <= 0.0 or misaligned  # un disco que no corta (o torcido) no entra en la chapa: la toca
	if solid and want_u >= -TOUCH_MM and want_u <= line_mm + TOUCH_MM:
		want_d = minf(want_d, 0.0)
	var budget := q_cap * dt
	var s := 1.0
	if not solid and _removal(want_u, want_d, cos_t, kerf_s) > budget + 1e-12:
		s = _reach(from_u, from_d, want_u, want_d, cos_t, kerf_s, budget)
	u_mm = lerpf(from_u, want_u, s)
	depth_mm = lerpf(from_d, want_d, s)
	var blocked := s < 1.0 - 1e-9 or (solid and hand_depth > depth_mm + 1e-9)
	if blocked:
		hand_u = clampf(hand_u, u_mm - LEAD_MAX_MM, u_mm + LEAD_MAX_MM)
		hand_depth = minf(hand_depth, depth_mm + LEAD_DEPTH_MAX_MM)
		_prev_hand_u = hand_u
		_prev_hand_depth = hand_depth

	# 4. Lo que arranca, con el modelo de la radial, y el mapa del surco
	var removed := _removal(u_mm, depth_mm, cos_t, kerf_s) if not solid else 0.0
	var engaged := clampf(depth_mm, 0.0, _t_total)
	var q_act := removed / dt if dt > 0.0 else 0.0
	var du_step := u_mm - from_u
	var feed_dir := 0
	if absf(du_step) > 1e-6 and removed > 0.0:
		feed_dir = 1 if du_step > 0.0 else -1
	var res := {}
	if removed > 0.0 and engaged > 0.0 and kerf_s > 0.0 and dt > 0.0:
		res = Radial.cut_step({ "disc_id": disc_id, "diameter_mm": diameter_mm, "rpm": rpm, "angle_deg": tilt_deg,
			"panel_id": panel_id, "depth_mm": engaged, "feed_mm_s": q_act / (kerf_s * engaged),
			"power_kw": maxf(p_avail, 1e-9), "push_n": Radial.PUSH_N })
		if bool(res["cutting"]):
			_apply_cut(res, cos_t, kerf_s)
			removed_mm3 += removed
			disc_wear_mm3 += removed * float(res["wear_mm3_per_mm3"])
			cutting_time_s += dt
	var cutting := not res.is_empty() and bool(res["cutting"])
	_last_power_kw = float(res["power_kw"]) if cutting else 0.0

	# 5. Carga del motor: si la mano empuja y el disco no llega adonde va porque lo limita la potencia, el empuje pide
	# más potencia de la que hay (la que pediría arrancar lo que da ese empuje por Archard, con la energía específica de
	# Awan et al.): falta la diferencia
	var feed_cap := q_full / (kerf_s * engaged) if kerf_s > 0.0 and engaged > ENGAGED_MIN_MM else 0.0
	# Hacia dentro: lo que arranca por mm que baja es el surco × la parte de la cuerda que aún tiene chapa debajo
	var l_eff := _chord(depth_mm, cos_t) - (_chord(depth_mm - _t_total, cos_t) if depth_mm > _t_total else 0.0)
	_plunge_cap = q_full / (kerf_s * l_eff) if kerf_s > 0.0 and l_eff > 0.05 else 0.0
	var push_kw := float(cap["push_power_kw"]) if _push_frac > 0.0 else 0.0
	var power_limited := String(cap["limited_by"]) == "potencia"
	_overload_x = push_kw / maxf(p_avail, 1e-9) if push_kw > 0.0 and (blocked or cutting) else 0.0
	_deficit_kw = maxf(push_kw - p_avail, 0.0) if blocked and cutting and power_limited else 0.0
	_saturated = blocked and _push_frac >= 1.0 - 1e-9 and cutting

	# 6. El motor: con corriente, la electrónica lleva el giro al fijado (con la caída a plena carga si no tiene
	# electrónica de giro constante): sube como en el arranque y, si el fijado es menor (se baja la rueda), la electrónica
	# no frena: baja como en la parada por inercia. Si falta potencia, el balance de energía del rotor
	# J·ω·dω/dt = P_disponible − P_pedida lo frena. Sin corriente, se para por inercia (o casi en seco tras un bloqueo).
	var rpm_before := rpm
	if powered and _deficit_kw > 0.0 and dt > 0.0:
		var w := rpm * TAU / 60.0
		rpm = sqrt(maxf(w * w - 2.0 * _deficit_kw * 1000.0 * dt / _inertia(), 0.0)) * 60.0 / TAU
	elif dt > 0.0:
		var target := 0.0
		var tau := _coast_tau()
		if powered:
			var droop := 0.0
			if not bool(_machine["constant_electronic"]):
				droop = DROOP_FULL_LOAD * clampf(_last_power_kw / maxf(p_max, 1e-6), 0.0, 1.0)
			target = n_set * (1.0 - droop)
			if target > rpm:
				tau = SPINUP_TAU_S
		elif (tripped or stalled) and _jam_t < 0.5:
			tau = JAM_TAU_S
		rpm = target + (rpm - target) * exp(-dt / tau)
	if not powered and rpm < STOP_RPM:
		rpm = 0.0
	if not powered or rpm >= SPUN_UP_FRACTION * n_set:
		_spinup = false

	# 7. Bloqueos: el disco pellizcado en el surco (supuesto geométrico, ver PINCH_MIN_DEPTH_MM), el giro que cae de golpe
	# (la desconexión por rebote de Bosch salta) o el disco que se para dentro del corte (el motor se cala)
	var pinch := _pinch(cos_t, disc)
	if powered:
		if float(pinch["interference_mm"]) > float(disc["thickness_mm"]):
			_jam()
		elif _deficit_kw > 0.0 and dt > 0.0:
			var drop_rate := (rpm_before - rpm) / maxf(rpm_before, 1e-9) / dt
			if bool(_machine["kickback_stop"]) and drop_rate > KICKBACK_DROP / KICKBACK_WINDOW_S:
				_jam()
			elif rpm < STOP_RPM:
				_jam()
	if stalled and depth_mm <= 0.0:
		stalled = false

	var shown := absf(du_step) / dt if dt > 0.0 and cutting else 0.0
	if dt > 0.0:
		_feed_shown += (shown - _feed_shown) * (1.0 - exp(-dt / (FEED_TAU_S if cutting else 0.05)))
	frame = _frame(res, cap, n_set, limit, engaged, kerf, kerf_s, q_act, q_cap, feed_cap, feed_dir, cos_t, pinch,
		solid, blocked)
	return frame


## Constante de tiempo de la parada por inercia: la que para el disco (por debajo de STOP_RPM) en COAST_STOP_S desde el
## giro máximo de la radial.
func _coast_tau() -> float:
	return COAST_STOP_S / log(maxf(float(_machine["rpm_max"]), 2.0 * STOP_RPM) / STOP_RPM)


## Inercia del rotor y el disco (kg·m²), deducida del arranque: si el motor arranca con su par nominal (P / ω a su
## giro máximo: supuesto) y la constante de tiempo del arranque es SPINUP_TAU_S, J = P·τ/ω². En la GWS 12-125 CIE da
## 2,2·10⁻⁴ kg·m². ESTIMACIÓN: ni Bosch ni nadie publica la inercia de una radial.
func _inertia() -> float:
	var w := float(_machine["rpm_max"]) * TAU / 60.0
	return float(_machine["power_kw"]) * 1000.0 * SPINUP_TAU_S / maxf(w * w, 1e-9)


## Capacidad con el disco en el aire (lejos de la chapa): no arranca nada; el surco que abriría, para las lecturas (el
## mismo de Radial._engine: espesor del disco + holgura, en perpendicular al disco, y / cos θ en la cara).
func _air_capacity() -> Dictionary:
	var thick := float((Abrasives.DISCS[disc_id] as Dictionary)["thickness_mm"])
	var kerf := thick + Radial.KERF_EXTRA_MM if thick > 0.0 else 0.0
	return { "q_cap_mm3_s": 0.0, "limited_by": "", "kerf_mm": kerf,
		"kerf_surface_mm": kerf / cos(deg_to_rad(clampf(absf(tilt_deg), 0.0, 60.0))), "vs_ms": 0.0, "over_speed": false,
		"warnings": [], "q_power_mm3_s": 0.0, "q_push_mm3_s": 0.0, "push_power_kw": 0.0 }


## u (mm) de la muestra i del mapa.
static func u_of(i: int) -> float:
	return float(i) * DU_MM


## Profundidad cortada (mm) en la muestra i.
func depth_at(i: int) -> float:
	return _map[i * 4]


## Datos del mapa en el formato de la textura de la escena (2 filas × n × 4 floats; ver _map).
func texture_data() -> PackedFloat32Array:
	return _map


## Semicuerda (mm, a lo largo de la línea) del disco en la cara pintada, con su punto más bajo a esa profundidad.
func _half_chord_at(depth: float, cos_t: float) -> float:
	if depth <= 0.0:
		return 0.0
	var r := diameter_mm * 0.5
	var p := minf(depth / maxf(cos_t, 1e-6), 2.0 * r)
	return sqrt(maxf(r * r - (r - p) * (r - p), 0.0))


## Longitud de contacto del disco con la chapa (mm): la cuerda en la cara pintada.
func _chord(depth: float, cos_t: float) -> float:
	return 2.0 * _half_chord_at(depth, cos_t)


## ¿Toca el disco la chapa (o está metido en ella) con su punto más bajo en (u, d)?
func _touching(u: float, d: float) -> bool:
	if d <= -TOUCH_MM:
		return false
	var h := _half_chord_at(maxf(d, TOUCH_MM), 1.0)
	return u + h >= 0.0 and u - h <= line_mm


## Volumen (mm³) que arrancaría el disco con su punto más bajo en (u, d), sobre lo que ya está cortado: el surco se
## toma como un rectángulo (anchura en la cara × profundidad) en cada muestra.
func _removal(u: float, d: float, cos_t: float, kerf_s: float) -> float:
	if d <= 0.0 or kerf_s <= 0.0:
		return 0.0
	var r := diameter_mm * 0.5
	var p := d / maxf(cos_t, 1e-6)
	var half := _half_chord_at(d, cos_t)
	var i0 := maxi(int(ceil((u - half) / DU_MM)), 0)
	var i1 := mini(int(floor((u + half) / DU_MM)), n - 1)
	var r2 := r * r
	var t_total := _t_total
	var area := 0.0
	for i in range(i0, i1 + 1):
		var o := i * 4
		# el mapa guarda floats de 32 bits: una millonésima de mm de tolerancia para que el disco quieto en su surco no
		# «arranque» el redondeo
		var d_old: float = _map[o] + 1e-6
		var w_old: float = 2.0 * _map[o + 1] + 1e-6
		if d_old >= t_total and w_old >= kerf_s:
			continue  # ya atravesada con un surco igual o más ancho
		var x := float(i) * DU_MM - u
		var dd := minf((p - (r - sqrt(maxf(r2 - x * x, 0.0)))) * cos_t, t_total)
		if dd <= 0.0:
			continue
		var a := kerf_s * dd - minf(w_old, kerf_s) * minf(d_old, dd)
		if a > 0.0:
			area += a
	return area * DU_MM


## Fracción s (0-1) del camino de (u0, d0) a (u1, d1) hasta la que el disco arranca como mucho `budget` mm³ (el volumen
## crece a lo largo del camino). Bisección guiada por la secante, con tolerancia del 2 % del presupuesto.
func _reach(u0: float, d0: float, u1: float, d1: float, cos_t: float, kerf_s: float, budget: float) -> float:
	var v_lo := _removal(u0, d0, cos_t, kerf_s)
	if v_lo > budget:
		return 0.0  # ya pisa material sin cortar (otro disco u otro ángulo bajo él): no avanza más
	var v_hi := _removal(u1, d1, cos_t, kerf_s)
	var lo := 0.0
	var hi := 1.0
	var tol := budget * 0.02
	for k in 12:
		var frac := 0.5
		if k % 2 == 0 and v_hi > v_lo:
			frac = clampf((budget - v_lo) / (v_hi - v_lo), 0.1, 0.9)
		var s := lo + (hi - lo) * frac
		var v := _removal(lerpf(u0, u1, s), lerpf(d0, d1, s), cos_t, kerf_s)
		if v <= budget:
			lo = s
			v_lo = v
			if budget > 0.0 and budget - v <= tol:
				break
		else:
			hi = s
			v_hi = v
		if hi - lo < 1e-4:
			break
	return lo


## Apunta en el mapa lo que arranca el disco en su pose (profundidad, anchura, inclinación) y lo que deja (rebaba donde
## atraviesa, pintura quemada, zona caliente y fundido), con los números de Radial.cut_step de ese paso.
func _apply_cut(res: Dictionary, cos_t: float, kerf_s: float) -> void:
	var r := diameter_mm * 0.5
	var p := depth_mm / maxf(cos_t, 1e-6)
	var half := _half_chord_at(depth_mm, cos_t)
	var i0 := maxi(int(ceil((u_mm - half) / DU_MM)), 0)
	var i1 := mini(int(floor((u_mm + half) / DU_MM)), n - 1)
	var r2 := r * r
	var t_total := _t_total
	var tilt_tan := tan(deg_to_rad(tilt_deg))
	var sides: Dictionary = res["burr_sides_um"]
	var b_minus := float(sides["lado_menos"]) / 1000.0
	var b_plus := float(sides["lado_mas"]) / 1000.0
	var burn := float(res["paint_burn_mm"])
	var hz := float(res["haz_mm"])
	var mlt := float(res["melt"])
	var cln := float(res["cleanliness"])
	var through_now := bool(res["through"])
	var row1 := n * 4
	var first := -1
	var last := -1
	for i in range(i0, i1 + 1):
		var o := i * 4
		var x := float(i) * DU_MM - u_mm
		var dd := minf((p - (r - sqrt(maxf(r2 - x * x, 0.0)))) * cos_t, t_total)
		if dd <= 0.0:
			continue
		if first < 0:
			first = i
		last = i
		var d_old: float = _map[o]
		if dd > d_old:
			if d_old <= 0.005 and dd > 0.005:
				_groove_count += 1
			if d_old < t_total - 1e-6 and dd >= t_total - 1e-6:
				_through_count += 1
			_map[o] = dd
			_map[o + 2] = tilt_tan
		_map[o + 1] = maxf(_map[o + 1], 0.5 * kerf_s)
		_map[row1 + o + 1] = maxf(_map[row1 + o + 1], burn)
		_map[row1 + o + 2] = maxf(_map[row1 + o + 2], hz)
		_map[row1 + o + 3] = maxf(_map[row1 + o + 3], mlt)
		if through_now and dd >= t_total - 1e-6:
			_map[o + 3] = maxf(_map[o + 3], b_minus)
			_map[row1 + o] = maxf(_map[row1 + o], b_plus)
			var old_c: float = _clean[i]
			if old_c < 0.0:
				_clean_count += 1
				_clean_sum += cln
				_clean[i] = cln
			elif cln > old_c:
				_clean_sum += cln - old_c
				_clean[i] = cln
	# La pintura quemada y la zona caliente rodean los extremos del surco (un semicírculo de su anchura)
	if first >= 0:
		var k_max := int(ceil(maxf(burn, hz) / DU_MM))
		for side: int in [-1, 1]:
			var edge := first if side < 0 else last
			for k in range(1, k_max + 1):
				var i := edge + side * k
				if i < 0 or i >= n or _map[i * 4] > 0.0:
					continue
				var du := float(k) * DU_MM
				var o := row1 + i * 4
				if burn > du:
					_map[o + 1] = maxf(_map[o + 1], sqrt(burn * burn - du * du))
				if hz > du:
					_map[o + 2] = maxf(_map[o + 2], sqrt(hz * hz - du * du))
	map_version += 1


## Pellizco del disco en el surco que ya hay bajo él, por el giro respecto a la línea del surco (los extremos del arco
## de contacto se desplazan de lado ½·contacto·sen δ) o por la diferencia de inclinación (el fondo se desplaza
## profundidad·tan Δθ). → { interference_mm (lo que se mete en las paredes más allá de la holgura; > 0 = roza),
##   yaw_off_deg, tilt_off_deg, contact_mm (longitud de surco que abraza el disco) }
func _pinch(cos_t: float, disc: Dictionary) -> Dictionary:
	var out := { "interference_mm": 0.0, "yaw_off_deg": 0.0, "tilt_off_deg": 0.0, "contact_mm": 0.0 }
	if depth_mm <= PINCH_MIN_DEPTH_MM or float(disc["thickness_mm"]) <= 0.0:
		return out
	var r := diameter_mm * 0.5
	var p := depth_mm / maxf(cos_t, 1e-6)
	var half := _half_chord_at(depth_mm, cos_t)
	var i0 := maxi(int(ceil((u_mm - half) / DU_MM)), 0)
	var i1 := mini(int(floor((u_mm + half) / DU_MM)), n - 1)
	var r2 := r * r
	var count := 0
	var tilt_sum := 0.0
	var depth_max := 0.0
	var ia := -1
	var ib := -1
	for i in range(i0, i1 + 1):
		var o := i * 4
		var g: float = _map[o]
		if g < PINCH_MIN_DEPTH_MM:
			continue
		var x := float(i) * DU_MM - u_mm
		var dd := (p - (r - sqrt(maxf(r2 - x * x, 0.0)))) * cos_t
		if dd <= PINCH_MIN_DEPTH_MM:
			continue
		count += 1
		tilt_sum += _map[o + 2]
		depth_max = maxf(depth_max, minf(g, dd))
		if ia < 0:
			ia = i
		ib = i
	if count == 0:
		return out
	var contact := float(ib - ia) * DU_MM
	var yaw_off := asin(clampf(absf(sin(deg_to_rad(yaw_deg))), 0.0, 1.0))
	var tilt_off := absf(deg_to_rad(tilt_deg) - atan(tilt_sum / float(count)))
	var lateral := maxf(0.5 * contact * sin(yaw_off), depth_max * tan(minf(tilt_off, deg_to_rad(80.0))))
	out["interference_mm"] = lateral - 0.5 * Radial.KERF_EXTRA_MM
	out["yaw_off_deg"] = rad_to_deg(yaw_off)
	out["tilt_off_deg"] = rad_to_deg(tilt_off)
	out["contact_mm"] = contact
	return out


## El disco se bloquea en el corte: con desconexión por rebote, la radial corta la corriente (hay que soltar el gatillo);
## sin ella, el motor se cala mientras el disco siga metido.
func _jam() -> void:
	jams += 1
	_jam_t = 0.0
	_deficit_kw = 0.0
	if bool(_machine["kickback_stop"]):
		tripped = true
	else:
		stalled = true


# ─────────────────────────────── Salida ───────────────────────────────
## Dónde y hacia dónde salen las chispas: por donde el borde del disco sale del material, en su sentido de giro. Si la
## radial avanza a favor del giro (o baja), por la cara pintada, hacia delante y hacia arriba; si avanza en contra y el
## disco atraviesa la chapa, por la cara de abajo, hacia dentro del coche. dir en coordenadas de la chapa (u, n, l).
func _spark_exit(feed_dir: int, cos_t: float, through: bool) -> Dictionary:
	var ang := deg_to_rad(yaw_deg)
	var rot := Vector3(cos(ang), 0.0, sin(ang))  # sentido del borde del disco en su punto más bajo
	var s_rot := 1 if cos(ang) >= 0.0 else -1
	var r := diameter_mm * 0.5
	var p := depth_mm / maxf(cos_t, 1e-6)
	var tilt := deg_to_rad(tilt_deg)
	var up := Vector3(0.0, cos(tilt), -sin(tilt))
	if through and feed_dir != 0 and feed_dir == -s_rot:
		var hb := p - _t_total / maxf(cos_t, 1e-6)  # altura de la cara de abajo sobre el punto más bajo (en el disco)
		var phi_b := acos(clampf((r - hb) / r, -1.0, 1.0))
		var half_b := sqrt(maxf(r * r - (r - hb) * (r - hb), 0.0))
		return { "side": "abajo", "u_mm": u_mm - float(s_rot) * half_b, "depth_mm": _t_total,
			"dir": (rot * cos(phi_b) - up * sin(phi_b)).normalized() }
	var phi := acos(clampf((r - p) / r, -1.0, 1.0))
	return { "side": "arriba", "u_mm": u_mm + float(s_rot) * _half_chord_at(depth_mm, cos_t), "depth_mm": 0.0,
		"dir": (rot * cos(phi) + up * sin(phi)).normalized() }


## Salida de un paso: todo lo que pintan la página, la escena 3D y el sonido.
# gdlint:ignore = function-arguments-number
func _frame(res: Dictionary, cap: Dictionary, n_set: float, limit: float, engaged: float, kerf: float, kerf_s: float,
		q_act: float, q_cap: float, feed_cap: float, feed_dir: int, cos_t: float, pinch: Dictionary, solid: bool,
		blocked: bool) -> Dictionary:
	var cutting := not res.is_empty() and bool(res["cutting"])
	var contact := _touching(u_mm, depth_mm)
	var powered := trigger and not tripped and not stalled
	var state := "apagada"
	if tripped:
		state = "desconectada"
	elif stalled:
		state = "calada"
	elif powered:
		state = "arrancando" if _spinup else "en_marcha"
	elif rpm > 0.0:
		state = "parando"
	var zero_sides := { "lado_menos": 0.0, "lado_mas": 0.0 }
	var sparks: Dictionary = res["sparks"] if cutting else { "rate": 0.0 }
	var exit := {}
	if cutting and float(sparks.get("rate", 0.0)) > 0.0:
		exit = _spark_exit(feed_dir, cos_t, bool(res["through"]))
	var power := float(res["power_kw"]) if cutting else 0.0
	var p_max := float(_machine["power_kw"])
	var front_u := u_mm
	if feed_dir != 0:
		front_u = u_mm + float(feed_dir) * _half_chord_at(minf(depth_mm, _t_total), cos_t)
	return {
		"machine": _machine["name"], "machine_id": _machine["id"], "machine_power_kw": p_max,
		"dial": not (_machine["dial_rpm"] as Array).is_empty(), "dial_pos": dial_pos_of(_machine, n_set),
		"trigger": trigger, "powered": powered, "tripped": tripped, "stalled": stalled, "state": state,
		"rpm": rpm, "rpm_set": n_set, "rpm_request": dial_request_rpm, "rpm_limit": limit,
		"rpm_machine_max": float(_machine["rpm_max"]), "dial_attempt": _dial_attempt,
		"vs_ms": Radial.peripheral_speed(diameter_mm, rpm),
		"vs_max_ms": float((Abrasives.DISCS[disc_id] as Dictionary)["max_speed_ms"]),
		"u_mm": u_mm, "depth_mm": depth_mm, "tilt_deg": tilt_deg, "yaw_deg": yaw_deg,
		"hand_u_mm": hand_u, "hand_depth_mm": hand_depth,
		"gap_mm": maxf(-depth_mm, 0.0), "engaged_mm": engaged if contact else 0.0, "total_mm": _t_total,
		"contact": contact, "cutting": cutting, "through": cutting and bool(res["through"]), "blocked": blocked,
		"solid": solid,
		"feed_mm_s": _feed_shown, "feed_want_mm_s": absf(_hand_speed), "feed_cap_mm_s": feed_cap, "feed_dir": feed_dir,
		"plunge_cap_mm_s": _plunge_cap,
		"q_mm3_s": q_act if cutting else 0.0, "q_cap_mm3_s": q_cap, "limited_by": cap["limited_by"],
		"push_n": Radial.PUSH_N * _push_frac, "push_limit_n": _push_limit, "saturated": _saturated,
		"overload": _overload_x if _overload_x < 99.0 else 99.0, "power_deficit_kw": _deficit_kw,
		"power_kw": power, "power_avail_kw": _p_avail_kw,
		"load": power / maxf(p_max, 1e-6),
		"specific_energy_j_mm3": float(res["specific_energy_j_mm3"]) if cutting else 0.0,
		"kerf_mm": kerf, "kerf_surface_mm": kerf_s,
		"burr_um": float(res["burr_um"]) if cutting else 0.0,
		"burr_sides_um": res["burr_sides_um"] if cutting else zero_sides,
		"haz_mm": float(res["haz_mm"]) if cutting else 0.0,
		"heat_tint": res["heat_tint"] if cutting else {},
		"paint_burn_mm": float(res["paint_burn_mm"]) if cutting else 0.0,
		"melt": float(res["melt"]) if cutting else 0.0,
		"smoke": float(res["smoke"]) if cutting else 0.0,
		"front_temp_c": float(res["front_temp_c"]) if cutting else Radial.T_AMBIENT,
		"front_u_mm": front_u,
		"disc_loading": float(res["disc_loading"]) if cutting else 0.0,
		"glazing": cutting and bool(res["glazing"]),
		"sparks": sparks, "spark_exit": exit,
		"disc_wear_mm3": disc_wear_mm3, "removed_mm3": removed_mm3, "cutting_time_s": cutting_time_s,
		"cut_length_mm": float(_through_count) * DU_MM, "groove_length_mm": float(_groove_count) * DU_MM,
		"cleanliness": _clean_sum / float(_clean_count) if _clean_count > 0 else -1.0,
		"cleanliness_now": float(res["cleanliness"]) if cutting else -1.0,
		"pinch_mm": float(pinch["interference_mm"]), "jams": jams,
		"warnings": _warnings(res, cap, n_set, contact, cutting, pinch, exit, solid, blocked, feed_cap),
		"map_version": map_version,
		"sound": {
			"process": "grinder", "rpm": rpm, "speed_droop": 0.0, "pc_kw": power, "pmax_kw": p_max, "disc_id": disc_id,
			"work_kind": String(_panel.get("kind", "acero")), "sheet_mm": float(_panel.get("t_mm", 1.0)),
			"diameter_mm": diameter_mm, "coolant": false, "chatter": null, "tool_pos": Vector3.ZERO,
		},
		"panel_id": panel_id, "disc_id": disc_id, "diameter_mm": diameter_mm, "quality": "estimate",
	}


# ─────────────────────────────── Avisos en directo ───────────────────────────────
## Avisos del instante, del más grave al menos: { level: "peligro" | "aviso" | "nota", code, message, source }.
func _warnings(res: Dictionary, cap: Dictionary, n_set: float, contact: bool, cutting: bool, pinch: Dictionary,
		exit: Dictionary, solid: bool, blocked: bool, feed_cap: float) -> Array:
	var out: Array = []
	var disc: Dictionary = Abrasives.DISCS[disc_id]
	var touching := contact or blocked
	# Velocidad: la rueda pide más de lo marcado en el disco y la radial se queda en el límite
	if _dial_attempt:
		var chk := Radial.disc_check({ "disc_id": disc_id, "diameter_mm": diameter_mm, "rpm": dial_request_rpm })
		_add(out, "peligro", "exceso_velocidad", String(chk["warning"]) + " Aquí la rueda de velocidad se queda en %s rpm: nunca por encima de lo marcado en el disco." % Radial._fmt(n_set),
			Radial.CITE_EN12413 + "; " + Radial.CITE_EN62841)
	if bool(disc.get("stationary_only", false)):
		_copy(out, _setup_warnings, "disco_fijo", "peligro")
	if tripped:
		_add(out, "peligro", "desconexion_rebote", "El giro ha caído de golpe (el disco se ha frenado o bloqueado en el corte) y la radial ha cortado la corriente del motor (desconexión por rebote). Suelta el gatillo, saca la radial con el disco parado y no vuelvas a arrancar dentro del corte.", CITE_SAFETY)
	elif stalled:
		_add(out, "peligro", "rebote", "El disco se ha bloqueado y el motor se ha calado: en una radial sin desconexión por rebote, ese golpe la lanza hacia el operario. Suelta el gatillo y saca el disco parado.", CITE_SAFETY)
	if float(pinch["interference_mm"]) > 0.0 and touching:
		var what := "torcido %s° respecto al surco" % Radial._fmt(float(pinch["yaw_off_deg"]), 1)
		if float(pinch["tilt_off_deg"]) > 20.0 * float(pinch["yaw_off_deg"]):
			what = "inclinado %s° más que el surco" % Radial._fmt(float(pinch["tilt_off_deg"]), 0)
		_add(out, "peligro", "pellizco", "El disco va %s: roza las paredes y se pellizca (la holgura del surco es de %s mm). Así se frena, se calienta y puede bloquearse, romperse o rebotar." % [what, Radial._fmt(Radial.KERF_EXTRA_MM, 1)], CITE_SAFETY)
	if not exit.is_empty():
		if String(exit["side"]) == "abajo":
			_add(out, "peligro", "chispas_combustible", "Las chispas salen por debajo de la chapa, hacia dentro del coche y el suelo: ahí puede haber combustible derramado o sus vapores. Avanzando a favor del giro del disco salen por arriba.", CITE_HOT_WORK)
		elif String(_panel.get("group", "")) == "rescate" and _aims_at(exit, HAZARD_AIRBAG, float(res["sparks"].get("length_mm", 0.0))):
			_add(out, "peligro", "chispas_airbag", "Las chispas van hacia el generador de gas del airbag de cortina (en el techo, junto al pilar B; aquí, un ejemplo): el calor lo puede reventar. Da la vuelta a la radial o corta en el otro sentido.", CITE_AIRBAG)
	if _start_in_cut_t > 0.0:
		_add(out, "peligro", "arranque_en_corte", "No se arranca con el disco tocando la chapa o dentro del corte: puede engancharse, saltar del surco o rebotar. Apártalo, deja que llegue a toda su velocidad y vuelve a entrar con cuidado.", CITE_SAFETY)
	# Avance y potencia
	var running := not tripped and not stalled and rpm > STOP_RPM
	var lim := String(cap["limited_by"])
	var watts := Radial._fmt(float(_machine["power_kw"]) * 1000.0)
	if _saturated and running:
		var why := "la potencia (%s W útiles)" % watts
		if lim != "potencia":
			why = "el empuje (cuanto más dura la chapa, menos arranca: ley de Archard)"
		var kerf_s := float(cap["kerf_surface_mm"])
		var chord := _chord(depth_mm, cos(deg_to_rad(tilt_deg)))
		var msg := "Demasiado avance: la mano va a %s mm/s y, empujando a fondo (unos %s N), el disco solo corta a %s mm/s; lo limita %s." % [
			Radial._fmt(absf(_hand_speed), 1), Radial._fmt(Radial.PUSH_N), Radial._fmt(feed_cap, 1), why]
		if maxf(_hand_speed_depth, 0.0) * chord > absf(_hand_speed) * clampf(depth_mm, 0.0, _t_total) and kerf_s > 0.0 and chord > 0.0:
			msg = "Demasiado deprisa hacia dentro: la mano baja a %s mm/s y, empujando a fondo, el disco solo entra a %s mm/s; lo limita %s." % [
				Radial._fmt(_hand_speed_depth, 1), Radial._fmt(_plunge_cap, 1), why]
		if _deficit_kw > 0.0:
			msg += " Ese empuje pide más potencia de la que da el motor: pierde vueltas y, si caen de golpe, la radial se desconecta."
		_add(out, "aviso", "demasiado_avance", msg, (CITE_BOSCH + "; " + Radial.CITE_AWAN if lim == "potencia" else "Archard 1953") + "; EN 62841-2-3")
	elif _deficit_kw > 0.0 and running:
		_add(out, "aviso", "pierde_vueltas", "La radial no da para tanto empuje: arrancar lo que pide pediría %s W y el motor da %s W; pierde vueltas hasta que se equilibran. Empuja menos." % [
			Radial._fmt((_p_avail_kw + _deficit_kw) * 1000.0), Radial._fmt(_p_avail_kw * 1000.0)], CITE_BOSCH + "; " + Radial.CITE_AWAN)
	if cutting and _spinup and rpm < FULL_SPEED_FRACTION * n_set:
		_add(out, "aviso", "sin_plena_velocidad", "El disco corta sin haber llegado a toda su velocidad: deja que la alcance antes de entrar en la chapa.", CITE_SAFETY)
	# Disco y material, cuando toca la chapa
	if touching:
		for code in CONTACT_CODES:
			_copy(out, cap["warnings"], code, "aviso")
		if solid and float(disc["thickness_mm"]) > 0.0 and absf(sin(deg_to_rad(yaw_deg))) > sin(deg_to_rad(ALIGN_SNAP_DEG)):
			_add(out, "aviso", "alinear", "Alinea el disco con la línea de corte (giro de 0° o 180°) para meterlo en la chapa.", "")
	if cutting:
		_copy(out, cap["warnings"], "acunamiento", "aviso")
		for code in ["pintura_humo", "plastico_fundido", "pilar_boro"]:
			_copy(out, res["warnings"], code, "aviso")
	if not trigger and rpm > STOP_RPM:
		_add(out, "nota", "inercia", "El disco sigue girando por inercia (sin freno, unos segundos): no apoyes ni sueltes la radial hasta que se pare.", CITE_SAFETY)
	var sorted: Array = []
	for lv in LEVELS:
		for w in out:
			if w["level"] == lv:
				sorted.append(w)
	return sorted


## ¿Llega el haz de chispas (la salida exit) a una zona de la chapa (u, n, l y su radio r en mm)? Sí si la zona está a
## su alcance (la longitud de Sparks.stream_for) y dentro del abanico del haz: su semiapertura en el plano del disco
## (Sparks.SPREAD_IN_PLANE_DEG, la del emisor de la escena) más lo que abarca la zona vista desde la salida.
func _aims_at(exit: Dictionary, spot: Dictionary, length_mm: float) -> bool:
	var from := Vector3(float(exit["u_mm"]), -float(exit["depth_mm"]), 0.0)
	var to := Vector3(float(spot["u_mm"]), float(spot["n_mm"]), float(spot["l_mm"]))
	var d := to - from
	var dist := d.length()
	if dist <= 0.0 or dist > length_mm:
		return false
	var half := deg_to_rad(Sparks.SPREAD_IN_PLANE_DEG) + asin(clampf(float(spot.get("r_mm", 0.0)) / dist, 0.0, 1.0))
	var dir: Vector3 = exit["dir"]
	return dir.normalized().dot(d / dist) >= cos(minf(half, PI))


static func _add(list: Array, level: String, code: String, message: String, source: String) -> void:
	for w in list:
		if w["code"] == code:
			return
	list.append({ "level": level, "code": code, "message": message, "source": source })


## Copia a la lista un aviso del modelo (Radial) con ese código, si está.
static func _copy(list: Array, from: Array, code: String, level: String) -> void:
	for w in from:
		if String(w.get("code", "")) == code:
			_add(list, level, code, String(w.get("message", "")), String(w.get("source", "")))
			return
