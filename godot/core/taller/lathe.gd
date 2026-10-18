## Taller · núcleo del torno (modelo sin gráficos): pieza axisimétrica, corte por estampado de la punta, cabezal,
## tiempos, potencia y alarmas. Lo leen la malla 3D, la vista 2D, la inspección y el intérprete Fagor (CONTRATOS.md).
##
## Pieza. Perfil r(z) en una rejilla uniforme: el anillo i es un disco de espesor dz centrado en z0 + i·dz. Z+ va hacia
## el contrapunto y Z = 0 es la cara acabada, así que la pieza queda en Z < 0. Un anillo con r = 0 ya no tiene material
## (por ejemplo, la creces de refrentado que se ha quitado).
##
## Corte. En avance (G01/G02/G03, avance automático o manivela con el cabezal en marcha) la herramienta estampa su
## envolvente de corte (el círculo de la punta, de radio rε y centro en la punta teórica + center: (rε, rε) en las de
## torneado, código de forma F3, y (0, rε) en la de roscar, F62; y sus dos filos rectos) UNA VEZ POR VUELTA del
## cabezal, a intervalos f a lo largo de la trayectoria: r_nuevo = min(r_viejo, borde).
## Es lo que ve una sección angular fija de la pieza: la herramienta pasa por ella una vez por vuelta. Así quedan las
## crestas de avance reales, con Rt = rε − √(rε² − f²/4) ≈ f²/(8·rε) mientras el filo secundario no las recorte
## (f ≤ 2·rε·sen κr'). Al acabar cada movimiento de avance se estampa también el punto final (la vuelta en curso llega
## al contorno programado).
## Roscado (movimientos «thread» del IR: G33 y las pasadas de G86). El avance por vuelta es el paso y el primer tramo de
## cada pasada espera a que el cabezal llegue a su posición angular (start_deg): así todas las pasadas cortan la misma
## hélice. La sección fija de la pieza ve pasar la herramienta una vez por vuelta, a un paso de distancia: el perfil r(z)
## es la sección axial de la rosca, con un diente en V cada paso (limitación del modelo axisimétrico: la hélice solo
## existe en el tiempo, no en la geometría). Al acabar un tramo de roscado no se estampa el punto final (no cae en la
## sección). El espesor de viruta es el del roscado, h = A/b, con A el área de la viruta de la vuelta y b el largo de
## filo que corta; ring_pass = 4.
## En rápido (G00) no se corta: antes de moverse se comprueba la envolvente barrida ENTERA del movimiento (cápsula del
## círculo de la punta y envolventes convexas de plaquita y portaherramientas) contra el material, el plato y el
## contrapunto. Si toca algo, la herramienta se detiene en el primer contacto con la alarma, por grande que sea el paso.
##
## Potencia. Volumen arrancado en cada vuelta ΔV = Σ π(r² − r'²)·dz y Pc = kc·ΔV/Δt con Δt = 60/n (una vuelta). kc sale
## del modelo de corte inyectado: Callable(work_id, tool_id, h_mm, b_mm, vc) -> { kc, fc_n }, con h = f·sen κr y
## b = ap/sen κr (κr efectivo, lathe_tools.kr_eff_deg). ap es la extensión del material arrancado en esa vuelta medida
## perpendicular al avance: radial al cilindrar y axial al refrentar.
##
## Tiempo. Ticks enteros de 1 ms: step(dt) acumula nanosegundos enteros y ejecuta los ticks completos, así que un paso
## de 10 s y mil pasos de 0,01 s dan el mismo resultado. Nada usa azar ni reloj: dos ejecuciones son idénticas.
##
## Rugosidad. ring_ra es el Ra medido sobre el perfil simulado: se reconstruyen las crestas exactas entre anillos (la
## intersección de las envolventes que dejó cada estampado), se ajusta la línea media por mínimos cuadrados y se integra
## |y| en una longitud de evaluación de un número entero de avances (≥ 4 y ≥ 0,8 mm) alrededor del anillo.
##
## Unidades: mm · mm/rev · mm/min · m/min · rpm · kW · N · s. X de los programas en diámetro; aquí dentro, r = X/2.
## Uso:
##   const Lathe = preload("res://core/taller/lathe.gd")
##   var lathe := Lathe.new(Lathe.STOCKS["A"], "cnc", modelo_de_corte)
##   lathe.load_moves(movimientos_ir); lathe.step(1.0 / 60.0); var p := lathe.profile()
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")

const DZ := 0.02  # paso de la rejilla (mm)
const TICK_NS := 1000000  # 1 ms
const TICK_S := 0.001
const BLK := 32  # anillos por bloque del índice de radios máximos (descarte rápido de colisiones)
const RA_BLOCK := 10  # anillos por bloque de rugosidad (0,2 mm)
const RA_HALF_MAX := 100  # semiventana máxima de Ra en anillos (2 mm)
const RA_SAMPLING_MM := 0.8  # longitud de muestreo mínima (ISO 4288, λc = 0,8 mm)
const RA_MIN_FEEDS := 4  # avances completos mínimos en la ventana de Ra
const JUMP_MM := 0.05  # salto entre anillos vecinos que corta la ventana de Ra (cara o escalón: pendiente > 68°)
const KINK_SLOPE := 0.08  # cambio de la pendiente media sobre un avance que corta la ventana de Ra (arista, ≈ 4,6°)
const AP_SUSTAINED_REVS := 2  # vueltas seguidas por encima de la ap máxima que rompen la plaquita (criterio del simulador)
const TOL := 0.001  # mm: penetración mínima que cuenta como contacto
const FINISH_AP_MAX := 1.0  # mm: hasta aquí una pasada cuenta como acabado (estimación)
const FINISH_F_MAX := 0.2  # mm/rev: ídem
const CIRCLE_STEP_DEG := 5.0  # polígono inscrito del círculo de la punta en las cápsulas (error < 0,1 % de rε)
const FEED_REV_LIMIT := 2.0  # avance por vuelta máximo, en múltiplos del máximo de catálogo de la plaquita: por encima
# el modelo de una sección por vuelta ya no vale (entre vuelta y vuelta la herramienta atravesaría material sin cortar)

const PASS_RAW := 0
const PASS_ROUGH := 1
const PASS_FINISH := 2
const PASS_POLISH := 3  # reservado: ninguna operación de este núcleo lo produce todavía
const PASS_THREAD := 4  # roscado (G33 y G86)

## Alarmas. halt: detiene el programa y el cabezal (como un choque o una rotura); si no, es un aviso.
const ALARMS := {
	"RAPID_IN_MATERIAL": { "halt": true, "title": "Rápido contra el material" },
	"AP_EXCEEDED": { "halt": true, "title": "Profundidad de pasada excesiva" },
	"AP_PEAK": { "halt": false, "title": "Pico de contacto breve" },
	"FLANK_RUB": { "halt": false, "title": "La herramienta talona" },
	"CHUCK_COLLISION": { "halt": true, "title": "Choque con el plato" },
	"TAILSTOCK_COLLISION": { "halt": true, "title": "Choque con el contrapunto" },
	"HOLDER_COLLISION": { "halt": true, "title": "Choque del portaherramientas" },
	"X_NEGATIVE": { "halt": true, "title": "X negativa" },
	"FEED_SPINDLE_STOPPED": { "halt": true, "title": "Avance con el cabezal parado" },
	"OVERLOAD": { "halt": true, "title": "Sobrecarga del cabezal" },
	"RPM_LIMIT": { "halt": false, "title": "Límite de revoluciones" },
	"TOOL_UNKNOWN": { "halt": true, "title": "Herramienta que no está en la torreta" },
}

## Máquinas. Los datos de catálogo son de fichas de venta (secondary); lo que no publican, estimación (ver fuentes-u3).
const MACHINES := {
	"cnc": {
		"name": "Torno CNC de formación con Fagor 8055 TC (tipo Pinacho Mustang 200)",
		"power_kw": 7.5, "rpm_max": 3000.0, "rapid_mm_min": 10000.0, "feed_max_mm_min": 7000.0,
		"chuck_d": 200.0, "jaw_len": 35.0, "jaw_h": 30.0, "speeds": [],
		"accel_rpm_s": 2000.0, "tool_change_s": 1.0, "jog_mm_min": 300.0,
		"source": "Pinacho Mustang 200 con Fagor 8055: 7,5 kW y 3000 rpm (ficha de Exapro); Mustang SK-200: 0–3000 rpm, rápidos de 10 m/min y plato hidráulico de 3 garras Ø200 (Maquinaria Colás); avances de 0 a 7000 mm/min (Pinacho Taurus 260 con Fagor 8055 TC, Corzosa). Según la versión, el motor va de 7,5 a 12 kW",
		"quality": "secondary",
		"estimates": ["jaw_len", "jaw_h", "accel_rpm_s", "tool_change_s", "jog_mm_min"],
	},
	"manual": {
		"name": "Torno paralelo (tipo Pinacho S90/200)",
		"power_kw": 4.0, "rpm_max": 2200.0, "rapid_mm_min": 2000.0, "feed_max_mm_min": 2000.0,
		"chuck_d": 200.0, "jaw_len": 30.0, "jaw_h": 25.0,
		"speeds": [40.0, 58.0, 83.0, 120.0, 173.0, 249.0, 359.0, 517.0, 745.0, 1074.0, 1548.0, 2200.0],
		"feeds_z": [0.05, 0.75], "feeds_x": [0.025, 0.375],
		"accel_rpm_s": 1500.0, "tool_change_s": 5.0, "jog_mm_min": 300.0,
		"source": "Pinacho S90/200 (ficha de Rastromáquinas): 4 kW, 12 velocidades de 40 a 2200 rpm, avances longitudinales 0,05–0,75 mm/rev y transversales 0,025–0,375 mm/rev",
		"quality": "secondary",
		"estimates": ["speeds (intermedias: serie geométrica entre 40 y 2200)", "rapid_mm_min", "chuck_d", "jaw_len", "jaw_h", "accel_rpm_s", "tool_change_s", "jog_mm_min"],
	},
}

## Brutos de las piezas de ejemplo (CONTRATOS.md). face_z: creces de refrentado (estimación: 1 mm).
const STOCKS := {
	"A": { "name": "Eje escalonado (pieza A)", "work_id": "c45e", "work_kind": "acero", "d": 50.0, "length": 85.0, "clamp": 25.0, "face_z": 1.0, "surface": "laminado", "tailstock": false },
	"B": { "name": "Bulón (pieza B)", "work_id": "al6082_t6", "work_kind": "aluminio", "d": 40.0, "length": 70.0, "clamp": 20.0, "face_z": 1.0, "surface": "estirado", "tailstock": false },
	"C": { "name": "Tornillo M20×2,5 (pieza C)", "work_id": "c45e", "work_kind": "acero", "d": 30.0, "length": 75.0, "clamp": 25.0, "face_z": 1.0, "surface": "laminado", "tailstock": false },
}

## Ra del bruto (µm) según su superficie: banda habitual de la tabla de rugosidad por proceso (ASME B46.1 / Machinery's
## Handbook, reproducida por ISO Finishing): laminado en caliente 12,5–25 µm, estirado en frío 0,4–1,6 µm.
const RAW_RA := { "laminado": 12.5, "estirado": 1.6 }

## Módulo de Young (GPa) y densidad (kg/m³) por tipo de material, para el modo de flexión de la pieza en chatter_risk
## (Callister, tabla 6.1: acero 207, aluminio 69, latón 97, titanio 107, níquel 207; inoxidable y fundición gris,
## valores típicos). Si el bruto trae e_gpa o density, mandan esos.
const E_GPA := { "acero": 207.0, "inox": 193.0, "fundicion": 100.0, "aluminio": 69.0, "laton": 97.0, "titanio": 107.0, "niquel": 207.0 }
const RHO := { "acero": 7850.0, "inox": 8000.0, "fundicion": 7200.0, "aluminio": 2700.0, "laton": 8500.0, "titanio": 4500.0, "niquel": 8900.0 }

## Contrapunto (punto giratorio): cono de 60° (norma de puntos de centrado) que entra por la cara, cuerpo y caña.
## Radios y longitudes, estimación.
const TAIL := { "r_tip": 3.35, "r_body": 12.5, "body_end": 45.0, "r_quill": 30.0 }

## Movimiento en curso: ninguno, trayectoria, espera (pausa, cambio de herramienta) o espera del cabezal
const MK_NONE := 0
const MK_PATH := 1
const MK_WAIT := 2
const MK_SPINDLE := 3
const PM_MMREV := 0
const PM_MMMIN := 1
const PM_RAPID := 2
## Modos de avance de una trayectoria
const GP := 10  # campos por geometría empaquetada: u_lo, u_hi, uM, eM, tM, um, em, tm, rε², rε

# ─── pieza ───
var _stock: Dictionary
var _dz: float
var _n: int
var _z0: float
var _z_face: float
var _z_end: float
var _z_jaw: float
var _r_stock: float
var _r := PackedFloat64Array()
var _ra := PackedFloat32Array()
var _pass := PackedByteArray()
var _src_cr := PackedFloat64Array()  # centro de la punta del estampado que dejó cada anillo
var _src_cz := PackedFloat64Array()
var _src_g := PackedInt32Array()  # geometría de herramienta de ese estampado (−1: bruto)
var _src_f := PackedFloat64Array()  # avance por vuelta de ese estampado
var _bmax := PackedFloat64Array()  # radio máximo por bloque (cota superior aunque esté desfasado)
var _bstale := PackedByteArray()
var _dirty_lo := -1
var _dirty_hi := -1
var _ra_lo := -1
var _ra_hi := -1
var _ra_margin := 30  # anillos alrededor de un cambio cuya Ra puede cambiar (crece con el avance más grueso visto)
var _raw_ra := 12.5
var _chuck_poly := PackedFloat64Array()  # perfiles superiores (z, r) del plato y del contrapunto como obstáculos
var _tail_poly := PackedFloat64Array()
var _vol0 := 0.0
var _removed := 0.0
var _tailstock := false

# ─── máquina y herramienta ───
var _m: Dictionary
var _rpm_max := 3000.0
var _rpm_clamped := false
var _rpm_asked := 0.0
var _spin_serial := 0  # cambia con cada orden de cabezal: el aviso de límite sale una vez por orden
var _rpm_warned := -1
var _feed_max := 7000.0
var _accel := 2000.0
var _power := 11.0
var _cut: Callable
var _tool: Dictionary = {}
var _g: Dictionary = {}
var _geos: Array[Dictionary] = []
var _geo_index := {}
var _gp := PackedFloat64Array()
var _gi := -1
var _re := 0.8
var _c_dz := 0.8  # centro de la punta respecto a la punta teórica (lathe_tools: center)
var _c_dr := 0.8
var _gu_lo := 0.0
var _gu_hi := 0.0
var _gu_maj := 0.0
var _ge_maj := 0.0
var _gt_maj := 0.0
var _gu_min := 0.0
var _ge_min := 0.0
var _gt_min := 0.0
var _gre2 := 0.0
var _holder_rel := PackedFloat64Array()  # polígonos relativos a la punta teórica, (dz, dr)
var _insert_rel := PackedFloat64Array()
var _holder_chain := PackedFloat64Array()  # cadenas inferiores relativas a la punta: portaherramientas, plaquita
var _insert_chain := PackedFloat64Array()
var _circle_chain := PackedFloat64Array()  # y círculo de la punta
var _tool_dz_min := 0.0
var _tool_dz_max := 0.0
var _tool_table := { "1": LatheTools.ROUGH, "2": LatheTools.FINISH, "3": "PVJNR2525M16HP/VNMG160404-PF" }

# ─── estado de la máquina ───
var _ticks := 0
var _pending_ns := 0
var _tip_r := 0.0
var _tip_z := 0.0
var _spin_dir := 0  # 0 parado · 1 horario (M3) · −1 antihorario (M4)
var _rpm := 0.0
var _rpm_cmd := 0.0
var _css_vc := 0.0
var _css_max := 0.0
var _phase := 0.0  # fracción de vuelta del cabezal
var _coolant := false
var _feed_mode := "mmrev"
var _feed_val := 0.0

# ─── movimiento ───
var _queue: Array = []
var _qi := 0
var _mk := MK_NONE  # movimiento en curso: ninguno, trayectoria, espera (pausa, cambio de herramienta) o cabezal
var _mtype := ""  # rapid, feed, arc, jog, manual, dwell, tool o spindle
var _wait_left := 0.0
var _wait_tool := ""
var _p_cut := false
var _p_arc := false
var _p_mode := PM_MMREV
var _p_f := 0.0
var _p_pass := 0  # tipo de pasada pedido por el IR (0: se decide aquí)
var _p_thread := false  # tramo de roscado (G33, G86): sincronizado con el cabezal
var _p_sync := false  # espera a la posición angular del cabezal antes de empezar
var _sync_phase := 0.0  # posición angular pedida (fracción de vuelta)
var _thread_info: Variant = null  # pasada de roscado en curso (para las lecturas) o null
var _p_kind := 0  # tipo decidido con las vueltas completas del movimiento
var _p_apmax := 0.0
var _p_last_s := 0.0  # abscisa del último estampado del movimiento (recorrido entre estampados)
var _p_axis := ""
var _p_r0 := 0.0
var _p_z0 := 0.0
var _p_r1 := 0.0
var _p_z1 := 0.0
var _p_ur := 0.0
var _p_uz := -1.0
var _p_ccr := 0.0
var _p_ccz := 0.0
var _p_rad := 0.0
var _p_a0 := 0.0
var _p_sgn := 1.0
var _p_len := 0.0
var _p_s := 0.0
var _p_stop := INF
var _p_hit := ""
var _program := false
var _halted := false
var _block_n := -1
var _line := 0
var _serial := 0
var _cur_serial := -1
var _alarms: Array[Dictionary] = []
var _alarm_keys := {}

# ─── corte ───
var _stamps := 0
var _cutting := false
var _over_revs := 0  # vueltas completas seguidas con la ap por encima de la máxima de la plaquita
var _cut_ok := true  # el modelo de corte tenía datos para el último corte (ok del contrato)
var _cut_reason := ""
var _pc_kw := 0.0
var _pc_peak := 0.0
var _fc_n := 0.0
var _kc := 0.0
var _h := 0.0
var _b := 0.0
var _ap := 0.0
var _contact := 0.0
var _vc := 0.0
var _energy_j := 0.0

# ─── temporales (sin reservar memoria en el bucle) ───
var _q_r := 0.0
var _q_z := 0.0
var _q_dr := 0.0
var _q_dz := -1.0
var _st_ap := 0.0
var _st_lo := -1
var _st_hi := -1
var _st_edge := 0.0  # largo de filo que ha cortado en el último estampado (solo al roscar)
var _fx_r := INF  # posición de la última comprobación de plato y contrapunto en avance
var _fx_z := INF


## stock: diccionario de bruto (claves de STOCKS; d, length, clamp y face_z en mm; opcionales dz, raw_ra_um, kc
## {kc11, mc}, e_gpa, density, tailstock). machine: "cnc", "manual" o un diccionario con las claves de MACHINES.
## cut_model: el modelo de corte inyectado; si no se da, Kienzle con el kc del bruto o, sin él, el de prueba.
func _init(stock: Dictionary = {}, machine: Variant = "cnc", cut_model: Callable = Callable()) -> void:
	var st: Dictionary = STOCKS["A"].duplicate(true)
	st.merge(stock, true)
	_stock = st
	var m: Dictionary = MACHINES["cnc"].duplicate(true)
	if machine is String and MACHINES.has(machine):
		m = MACHINES[machine].duplicate(true)
	elif machine is Dictionary:
		m.merge(machine, true)
	_m = m
	_rpm_max = float(m["rpm_max"])
	_feed_max = float(m["feed_max_mm_min"])
	_accel = float(m["accel_rpm_s"])
	_power = float(m["power_kw"])
	_dz = float(st.get("dz", DZ))
	_n = maxi(1, roundi(float(st["length"]) / _dz))
	_z_face = float(st["face_z"])
	_z_end = _z_face - _n * _dz
	_z0 = _z_end + 0.5 * _dz
	_z_jaw = _z_end + float(st["clamp"])
	_r_stock = 0.5 * float(st["d"])
	_tailstock = bool(st.get("tailstock", false))
	_raw_ra = float(st.get("raw_ra_um", RAW_RA.get(st.get("surface", "laminado"), 12.5)))
	_r.resize(_n)
	_r.fill(_r_stock)
	_ra.resize(_n)
	_ra.fill(_raw_ra)
	_pass.resize(_n)
	_pass.fill(PASS_RAW)
	_src_cr.resize(_n)
	_src_cz.resize(_n)
	_src_g.resize(_n)
	_src_g.fill(-1)
	_src_f.resize(_n)
	var nb := (_n + BLK - 1) / BLK
	_bmax.resize(nb)
	_bmax.fill(_r_stock)
	_bstale.resize(nb)
	_vol0 = volume_mm3()
	_chuck_poly = _chuck_top()
	_tail_poly = _tail_top()
	_tip_r = _r_stock + 40.0
	_tip_z = _z_face + 40.0
	set_tool(LatheTools.ROUGH)
	if cut_model.is_valid():
		_cut = cut_model
	else:
		var kc: Variant = st.get("kc", null)
		_cut = kienzle_model(kc["kc11"], kc["mc"]) if kc is Dictionary else kienzle_model(1700.0, 0.25)


# ════════════════════════════════════════ API ════════════════════════════════════════


## Modelo de corte de Kienzle: kc = kc1.1·h^(−mc) (N/mm²) y fc = kc·h·b (N). Es el sustituto mientras no se inyecte el
## de la unidad de corte; los tests del torno lo usan con kc1.1 = 1700 N/mm² y mc = 0,25.
static func kienzle_model(kc11: float, mc: float) -> Callable:
	return func(_work_id: String, _tool_id: String, h_mm: float, b_mm: float, _vc: float) -> Dictionary:
		var kc := kc11 * pow(maxf(h_mm, 1e-4), -mc)
		return { "kc": kc, "fc_n": kc * h_mm * b_mm }


## Monta una herramienta: un id del catálogo («PORTA/PLAQUITA», ver lathe_tools.gd) o un diccionario de herramienta.
func set_tool(t: Variant) -> bool:
	var tool: Dictionary = LatheTools.tool(t) if t is String else t
	if tool.is_empty():
		return false
	_tool = tool
	var id: String = tool["id"]
	if not _geo_index.has(id):
		var cg := LatheTools.cut_geometry(tool)
		_geos.append(cg)
		_geo_index[id] = _geos.size() - 1
		for k in ["u_lo", "u_hi", "uM", "eM", "tM", "um", "em", "tm", "re2", "re"]:
			_gp.append(float(cg[k]))
	_gi = _geo_index[id]
	_g = _geos[_gi]
	_re = _g["re"]
	_gu_lo = _g["u_lo"]
	_gu_hi = _g["u_hi"]
	_gu_maj = _g["uM"]
	_ge_maj = _g["eM"]
	_gt_maj = _g["tM"]
	_gu_min = _g["um"]
	_ge_min = _g["em"]
	_gt_min = _g["tm"]
	_gre2 = _g["re2"]
	_holder_rel = tool["holder_poly"]
	_insert_rel = tool["insert_poly"]
	var c: Array = tool.get("center", [_re, _re])
	_c_dz = float(c[0])
	_c_dr = float(c[1])
	_holder_chain = _lower_hull(_holder_rel)
	_insert_chain = _lower_hull(_insert_rel) if _insert_rel.size() > 0 else PackedFloat64Array()
	_circle_chain = _capsule_chain(_c_dz, _c_dr, _c_dz, _c_dr, _re)
	_tool_dz_min = minf(0.0, _c_dz - _re)
	_tool_dz_max = _c_dz + _re
	for poly in [_holder_rel, _insert_rel]:
		for k in range(0, poly.size(), 2):
			_tool_dz_min = minf(_tool_dz_min, poly[k])
			_tool_dz_max = maxf(_tool_dz_max, poly[k])
	return true


## Tabla de herramientas del programa: número de T («1», «T1»…) → id del catálogo.
func set_tool_table(table: Dictionary) -> void:
	_tool_table = table.duplicate()


## Coloca la punta teórica sin simular el movimiento (preparación de ensayos o de la escena, no un movimiento real).
func place_tool(r: float, z: float) -> void:
	_tip_r = r
	_tip_z = z


## Carga un programa: lista de movimientos IR del intérprete Fagor (CONTRATOS.md). Borra el estado de alarma.
func load_moves(moves: Array) -> void:
	_queue = moves.duplicate()
	_qi = 0
	_mk = MK_NONE
	_program = true
	_halted = false


## Avanza dt_s segundos. Devuelve { t_s, ticks, removed_mm3, stamps, alarms } (lo de este paso).
func step(dt_s: float) -> Dictionary:
	var a0 := _alarms.size()
	var v0 := _removed
	var s0 := _stamps
	var t0 := _ticks
	if dt_s > 0.0:
		_pending_ns += int(roundf(dt_s * 1e9))
		var n := floori(float(_pending_ns) / TICK_NS)
		_pending_ns -= n * TICK_NS
		for k in n:
			_tick()
	return { "t_s": (_ticks - t0) * TICK_S, "ticks": _ticks - t0, "removed_mm3": _removed - v0, "stamps": _stamps - s0, "alarms": _alarms.slice(a0) }


## Ejecuta hasta que el programa termina, se detiene por una alarma o pasan max_s segundos. Devuelve { t_s, done,
## halted, alarms }; t_s es el tiempo de ciclo.
func run_to_end(max_s: float = 3600.0) -> Dictionary:
	var t0 := _ticks
	var limit := t0 + floori(max_s / TICK_S)
	while _ticks < limit and not _halted and not _idle():
		_tick()
	return { "t_s": (_ticks - t0) * TICK_S, "done": _idle(), "halted": _halted, "alarms": _alarms.duplicate() }


## Manivela: desplaza un eje d_mm (X en diámetro, como el visualizador; Z en mm) a la velocidad de avance manual. Con
## el cabezal en marcha corta; parado, se detiene al tocar la pieza. No se admite con un programa en curso.
func jog(axis: String, d_mm: float) -> bool:
	if _halted or (_program and not _idle()):
		return false
	# cada clic parte del destino de la manivela anterior si aún está en cola o en marcha, no de la punta a medio camino
	var r0 := _tip_r
	var z0 := _tip_z
	if _qi < _queue.size() and _queue[-1].get("type", "") == "jog":
		r0 = _queue[-1]["to"]["r"]
		z0 = _queue[-1]["to"]["z"]
	elif _mk == MK_PATH and _mtype == "jog":
		r0 = _p_r1
		z0 = _p_z1
	var r1 := r0 + (0.5 * d_mm if axis == "x" else 0.0)
	var z1 := z0 + (d_mm if axis == "z" else 0.0)
	_queue.append({ "n": -1, "type": "jog", "to": { "r": r1, "z": z1 } })
	return true


## Cabezal a mano: rpm y sentido («cw», «ccw» o «stop»). En el torno paralelo se toma la velocidad de la caja más
## cercana. Anula la velocidad de corte constante.
func set_spindle(rpm: float, dir: String) -> void:
	_serial += 1
	_cur_serial = _serial
	_spin_serial += 1
	_block_n = -1
	_spin_dir = 1 if dir == "cw" else (-1 if dir == "ccw" else 0)
	_css_vc = 0.0
	var speeds: Array = _m.get("speeds", [])
	if speeds.size() > 0 and rpm > 0.0:
		var best: float = speeds[0]
		for s in speeds:
			if absf(float(s) - rpm) < absf(best - rpm):
				best = s
		if rpm > float(speeds[-1]) * 1.02:
			_alarm("RPM_LIMIT", "%s rpm pedidas; la caja del cabezal llega a %s rpm." % [_fmt(rpm, 0), _fmt(float(speeds[-1]), 0)])
		rpm = best
	_rpm_cmd = maxf(rpm, 0.0)


## Avance automático del carro: eje «z» (longitudinal) o «x» (transversal), f en mm/rev con signo (negativo: hacia el
## plato o hacia el eje), on/off. Sigue hasta que se desembraga, choca o llega al final del recorrido.
func set_feed(axis: String, f_mm_rev: float, on: bool) -> void:
	if not on:
		if _mk == MK_PATH and _mtype == "manual":
			_finish_path_here()
		return
	if _halted or (_program and not _idle()):
		return
	if _mk == MK_PATH and _mtype == "manual":
		_finish_path_here()
	var r1 := _tip_r
	var z1 := _tip_z
	if axis == "x":
		r1 = -_c_dr if f_mm_rev < 0.0 else _r_stock + 200.0
	else:
		z1 = _z_end - 50.0 if f_mm_rev < 0.0 else _z_face + 300.0
	_serial += 1
	_cur_serial = _serial
	_block_n = -1
	_start_path({ "n": -1, "type": "manual", "to": { "r": r1, "z": z1 }, "feed": { "mode": "mmrev", "value": absf(f_mm_rev) }, "axis": axis })


func set_coolant(on: bool) -> void:
	_coolant = on


## Sale del estado de alarma y vacía la cola (como RESET): la pieza y la posición se quedan como están.
func reset() -> void:
	_halted = false
	_mk = MK_NONE
	_queue = []
	_qi = 0
	_program = false
	_thread_info = null


func alarms() -> Array[Dictionary]:
	return _alarms.duplicate()


func clear_alarms() -> void:
	_alarms.clear()
	_alarm_keys.clear()


func is_halted() -> bool:
	return _halted


func is_done() -> bool:
	return _idle()


func tool() -> Dictionary:
	return _tool


func machine() -> Dictionary:
	return _m


func stock() -> Dictionary:
	return _stock


## Perfil del contrato: { z0, dz, r, ring_ra, ring_pass, dirty }. dirty es el rango de anillos cambiados (radio,
## rugosidad o tipo de pasada) desde la lectura anterior, o (−1, −1).
func profile() -> Dictionary:
	_update_ra()
	var d := Vector2i(-1, -1)
	if _dirty_lo >= 0:
		d = Vector2i(_dirty_lo, _dirty_hi)
	_dirty_lo = -1
	_dirty_hi = -1
	return { "z0": _z0, "dz": _dz, "r": _r, "ring_ra": _ra, "ring_pass": _pass, "dirty": d }


## Radio de la pieza en z (el del anillo más cercano; 0 fuera de la pieza).
func radius_at(z: float) -> float:
	var i := roundi((z - _z0) / _dz)
	return _r[i] if i >= 0 and i < _n else 0.0


## Volumen de la pieza (mm³): Σ π·r²·dz.
func volume_mm3() -> float:
	var s := 0.0
	for i in _n:
		s += _r[i] * _r[i]
	return PI * s * _dz


func removed_mm3() -> float:
	return _removed


func initial_volume_mm3() -> float:
	return _vol0


## Rugosidad medida entre z_from y z_to como la mediría un rugosímetro sobre el perfil simulado (crestas incluidas):
## { ra_um, rt_um, rz_um, points, crests, d_mm }. form «line» (línea media recta, ISO 4287) o «quad» (quita la forma
## curva de un radio o un cono con curvatura).
func measure_roughness(z_from: float, z_to: float, form: String = "line") -> Dictionary:
	var za := minf(z_from, z_to)
	var zb := maxf(z_from, z_to)
	var i0 := clampi(ceili((za - _z0) / _dz - 1e-9), 0, _n - 1)
	var i1 := clampi(floori((zb - _z0) / _dz + 1e-9), 0, _n - 1)
	if i1 - i0 < 2:
		return { "ra_um": 0.0, "rt_um": 0.0, "rz_um": 0.0, "points": 0, "crests": 0, "d_mm": 2.0 * radius_at(0.5 * (za + zb)) }
	return _measure(i0, i1, _z0 + i0 * _dz, _z0 + i1 * _dz, 2 if form == "quad" else 1)


func state() -> Dictionary:
	var css: Variant = null
	if _css_vc > 0.0:
		css = { "vc": _css_vc, "rpm_max": _css_max }
	return {
		"t_s": _ticks * TICK_S,
		"ticks": _ticks,
		"tip": { "r": _tip_r, "z": _tip_z },
		"x_diam": 2.0 * _tip_r,
		"tool_id": _tool.get("id", ""),
		"re_mm": _re,
		"nose_center": { "dz": _c_dz, "dr": _c_dr },  # centro de la punta respecto a la punta teórica
		"spindle": { "dir": "cw" if _spin_dir == 1 else ("ccw" if _spin_dir == -1 else "stop"), "rpm": _rpm, "rpm_goal": _rpm_want(), "css": css },
		"feed": { "mode": _feed_mode, "value": _feed_val },
		"coolant": _coolant,
		"block_n": _block_n,
		"line": _line,
		"motion": _mtype if _mk != MK_NONE else "",
		"program_done": _idle(),
		"halted": _halted,
		"cutting": _cutting,
		"cut_ok": _cut_ok,
		"cut_reason": _cut_reason,
		"pc_kw": _pc_kw,
		"pc_peak_kw": _pc_peak,
		"fc_n": _fc_n,
		"kc": _kc,
		"h_mm": _h,
		"b_mm": _b,
		"ap_mm": _ap,
		"contact_mm": _contact,
		"vc_m_min": _vc,
		"energy_kj": _energy_j / 1000.0,
		"removed_mm3": _removed,
		"volume_mm3": _vol0 - _removed,
		"stamps": _stamps,
		"alarms": _alarms.size(),
		# roscado en curso: { pitch, pass, passes, depth, total, kind, infeed_deg, start_deg } o null
		"thread": _thread_info,
	}


## Entrada de sonido de máquina (CONTRATOS.md). tool_pos: Vector3(z, r, 0) en mm, en coordenadas de la pieza.
func sound_input() -> Dictionary:
	var ch: Variant = null
	if _cutting:
		var c := chatter_now()
		ch = { "risk": c["risk"], "mode_hz": c["mode_hz"] }
	return {
		"process": "lathe", "rpm": _rpm, "teeth": 1, "jaws": 3, "pc_kw": _pc_kw, "pmax_kw": _power,
		"work_kind": _stock.get("work_kind", "acero"), "chatter": ch, "coolant": _coolant,
		"tool_pos": Vector3(_tip_z, _tip_r, 0.0),
	}


## Riesgo de vibración con el estado actual: voladizo desde las garras hasta la herramienta, diámetro mínimo en ese
## tramo, última ap, rε y κr de la herramienta montada.
func chatter_now() -> Dictionary:
	var over := maxf(_tip_z - _z_jaw, 0.0)
	var dmin := 2.0 * _r_stock
	var i0 := clampi(ceili((_z_jaw - _z0) / _dz), 0, _n - 1)
	var i1 := clampi(floori((_tip_z - _z0) / _dz), 0, _n - 1)
	for i in range(i0, i1 + 1):
		if _r[i] > 0.0:
			dmin = minf(dmin, 2.0 * _r[i])
	var kind: String = _stock.get("work_kind", "acero")
	var e := float(_stock.get("e_gpa", E_GPA.get(kind, 207.0)))
	var rho := float(_stock.get("density", RHO.get(kind, 7850.0)))
	return chatter_risk(over, dmin, _ap, _re, float(_tool.get("kr_deg", 95.0)), _tailstock, e, rho)


## Riesgo de vibración (chatter) · ESTIMACIÓN, no una medición. Combina:
##   - Esbeltez L/D de la pieza (reglas prácticas de amarre de CADEM: solo plato si L/D < 3, hasta 5 con parámetros
##     reducidos; con contrapunto 3–6, hasta 10).
##   - La componente radial de la fuerza: Sandvik recomienda ap mayor que rε y κr cercano a 90° para evitar vibraciones;
##     con ap < rε solo corta el arco de la punta y el ángulo efectivo baja.
## mode_hz: primer modo de flexión de la pieza (viga de Euler-Bernoulli maciza: voladizo, o empotrada-apoyada con
## contrapunto): f = λ²/(2π)·(D/4)·√(E/ρ)/L². Devuelve { risk (0–1), level, ld, mode_hz, quality, source, explanation }.
static func chatter_risk(overhang_mm: float, diameter_mm: float, ap_mm: float, re_mm: float, kr_deg: float = 95.0, tailstock: bool = false, e_gpa: float = 207.0, density: float = 7850.0) -> Dictionary:
	var ld := overhang_mm / maxf(diameter_mm, 1e-6)
	var ok := 6.0 if tailstock else 3.0
	var lim := 10.0 if tailstock else 5.0
	var ld_term := clampf((ld - ok) / (lim - ok), 0.0, 1.0)
	var kr_e := kr_deg
	if ap_mm > 0.0 and re_mm > 0.0 and ap_mm < re_mm * (1.0 - cos(deg_to_rad(kr_deg))):
		kr_e = rad_to_deg(acos(clampf(1.0 - ap_mm / re_mm, -1.0, 1.0)))
	var radial := absf(cos(deg_to_rad(kr_e))) if ap_mm > 0.0 else 0.0
	var risk := clampf(ld_term + 0.3 * radial * clampf(ld / ok, 0.0, 1.0), 0.0, 1.0)
	var lam := 3.9266 if tailstock else 1.8751
	var mode := 0.0
	if overhang_mm > 0.0 and diameter_mm > 0.0:
		var d_m := diameter_mm / 1000.0
		var l_m := overhang_mm / 1000.0
		mode = lam * lam / (2.0 * PI) * (d_m / 4.0) * sqrt(e_gpa * 1e9 / density) / (l_m * l_m)
	var level := "bajo" if risk < 0.33 else ("medio" if risk < 0.66 else "alto")
	var why := "L/D = %s (%s conviene por debajo de %s; hasta %s con parámetros reducidos)." % [_fmt(ld, 1), "con contrapunto" if tailstock else "solo con el plato", _fmt(ok, 0), _fmt(lim, 0)]
	if radial > 0.3:
		why += " Con ap = %s mm y rε = %s mm corta sobre todo la punta: más fuerza radial (Sandvik: ap mayor que rε)." % [_fmt(ap_mm, 2), _fmt(re_mm, 1)]
	why += " Primer modo de flexión de la pieza ≈ %s Hz." % _fmt(mode, 0)
	return {
		"risk": risk, "level": level, "ld": ld, "mode_hz": mode, "quality": "estimate",
		"source": "Reglas de amarre por L/D de CADEM Technologies; recomendaciones de Sandvik Coromant contra vibraciones (ap > rε, κr ≈ 90°); viga de Euler-Bernoulli. Los pesos del índice son una estimación.",
		"explanation": why,
	}


# ════════════════════════════════════════ tiempo ════════════════════════════════════════


func _idle() -> bool:
	return _mk == MK_NONE and _qi >= _queue.size()


func _tick() -> void:
	_ticks += 1
	var goal := _rpm_goal()
	var dv := _accel * TICK_S
	if _rpm < goal:
		_rpm = minf(goal, _rpm + dv)
	elif _rpm > goal:
		_rpm = maxf(goal, _rpm - dv)
	var budget := TICK_S
	var guard := 0
	while budget > 0.0 and not _halted and guard < 32:
		guard += 1
		if _mk == MK_NONE:
			if not _next_motion():
				break
			continue
		budget = _advance(budget)
	if budget > 0.0:
		_phase = _wrap(_phase + _rpm / 60.0 * budget)
	if _program and _idle():
		_program = false


static func _wrap(x: float) -> float:
	return x - floorf(x)


## rpm deseadas: G97 (fijas) o G96 (n = 1000·vc/(π·D) con D = 2·r en la punta y el tope G92), recortadas por la
## máquina. Deja en _rpm_clamped si ha recortado la máquina.
func _rpm_want() -> float:
	_rpm_clamped = false
	if _spin_dir == 0:
		return 0.0
	var want := _rpm_cmd
	if _css_vc > 0.0:
		want = 1000.0 * _css_vc / (PI * maxf(2.0 * absf(_tip_r), 0.001))
		if _css_max > 0.0 and want > _css_max:
			want = _css_max
	if want > _rpm_max:
		_rpm_clamped = true
		_rpm_asked = want
		return _rpm_max
	return want


func _rpm_goal() -> float:
	var w := _rpm_want()
	if _rpm_clamped and _rpm_warned != _spin_serial:
		_rpm_warned = _spin_serial
		_alarm("RPM_LIMIT", "N%d: %s rpm pedidas; el cabezal llega a %s rpm y se queda ahí." % [_block_n, _fmt(_rpm_asked, 0), _fmt(_rpm_max, 0)])
	return w


# ════════════════════════════════════════ movimientos ════════════════════════════════════════


func _next_motion() -> bool:
	if _qi >= _queue.size():
		return false
	var m: Dictionary = _queue[_qi]
	_qi += 1
	_serial += 1
	_cur_serial = _serial
	_block_n = int(m.get("n", -1))
	_line = int(m.get("line", 0))
	var type: String = m.get("type", "")
	match type:
		"rapid", "feed", "arc", "jog", "thread":
			_start_path(m)
		"dwell":
			_mk = MK_WAIT
			_mtype = "dwell"
			_wait_left = maxf(float(m.get("dwell_s", 0.0)), 0.0)
		"tool":
			var t: Dictionary = m.get("tool", {})
			_thread_info = null
			_mk = MK_WAIT
			_mtype = "tool"
			_wait_left = float(_m["tool_change_s"])
			_wait_tool = str(t.get("id", ""))
		"spindle":
			_apply_spindle(m.get("spindle", {}))
			_mk = MK_SPINDLE
			_mtype = "spindle"
		"coolant":
			_coolant = bool(m.get("coolant", false))
		"end":
			_spin_dir = 0
			_css_vc = 0.0
			_coolant = false
			_thread_info = null
			_qi = _queue.size()
	return true


func _apply_spindle(sp: Dictionary) -> void:
	_spin_serial += 1
	var dir: String = sp.get("dir", "cw")
	_spin_dir = 1 if dir == "cw" else (-1 if dir == "ccw" else 0)
	var css: Variant = sp.get("css", null)
	if css is Dictionary and float(css.get("vc", 0.0)) > 0.0:
		_css_vc = float(css["vc"])
		_css_max = float(css.get("rpm_max", 0.0))
	else:
		_css_vc = 0.0
		_rpm_cmd = maxf(float(sp.get("rpm", 0.0)), 0.0)


func _resolve_tool(id: String) -> String:
	if _tool_table.has(id):
		return _tool_table[id]
	if _tool_table.has("T" + id):
		return _tool_table["T" + id]
	if id.begins_with("T") and _tool_table.has(id.substr(1)):
		return _tool_table[id.substr(1)]
	return id


func _advance(dt: float) -> float:
	if _mk == MK_PATH:
		return _advance_path(dt)
	if _mk == MK_WAIT:
		var use := minf(dt, _wait_left)
		var done := _wait_left <= dt
		_phase = _wrap(_phase + _rpm / 60.0 * use)
		_wait_left -= use
		if done:
			if _mtype == "tool":
				var id := _resolve_tool(_wait_tool)
				if not set_tool(id):
					# como en un control real: una herramienta que no está en la torreta detiene el programa
					_alarm("TOOL_UNKNOWN", "N%d: la herramienta %s no está en la torreta; carga su corrector o cambia el T del programa." % [_block_n, _wait_tool])
					_mk = MK_NONE
					return 0.0
			_mk = MK_NONE
			return dt - use
		return 0.0
	# espera a que el cabezal llegue a la velocidad pedida (las rpm cambian al principio de cada tick)
	if absf(_rpm - _rpm_want()) < 0.5:
		_mk = MK_NONE
		return dt
	_phase = _wrap(_phase + _rpm / 60.0 * dt)
	return 0.0


## Prepara un movimiento de trayectoria (rápido, avance, arco, manivela o avance automático) desde la punta actual.
## Las coordenadas «from» del IR se ignoran: manda la posición real de la máquina.
func _start_path(m: Dictionary) -> void:
	var type: String = m.get("type", "feed")
	var to: Dictionary = m.get("to", {})
	var r1 := float(to.get("r", _tip_r))
	var z1 := float(to.get("z", _tip_z))
	_p_r0 = _tip_r
	_p_z0 = _tip_z
	_p_r1 = r1
	_p_z1 = z1
	_p_s = 0.0
	_p_stop = INF
	_p_hit = ""
	_p_cut = type != "rapid"
	_p_pass = int(m.get("pass", 0))
	_p_thread = type == "thread"
	_p_sync = false
	if _p_thread:
		var th: Dictionary = m.get("thread", {})
		_thread_info = th.duplicate()
		_p_pass = PASS_THREAD
		if bool(th.get("sync", true)):
			_p_sync = true
			_sync_phase = _wrap(float(th.get("start_deg", 0.0)) / 360.0)
	elif type != "rapid":
		_thread_info = null
	_p_kind = 0
	_p_apmax = 0.0
	_over_revs = 0
	_p_last_s = 0.0
	_p_axis = str(m.get("axis", ""))
	_p_arc = type == "arc"
	var rmin := minf(_tip_r, r1)
	if _p_arc:
		var arc: Dictionary = m.get("arc", {})
		var c: Dictionary = arc.get("center", {})
		_p_ccr = float(c.get("r", 0.0))
		_p_ccz = float(c.get("z", 0.0))
		_p_rad = sqrt((_tip_r - _p_ccr) * (_tip_r - _p_ccr) + (_tip_z - _p_ccz) * (_tip_z - _p_ccz))
		_p_a0 = atan2(_tip_r - _p_ccr, _tip_z - _p_ccz)
		var a1 := atan2(r1 - _p_ccr, z1 - _p_ccz)
		var cw := bool(arc.get("cw", false))
		# cw: horario visto con Z hacia la derecha y X hacia arriba (el ángulo baja)
		_p_sgn = -1.0 if cw else 1.0
		var sweep := fposmod((_p_a0 - a1) if cw else (a1 - _p_a0), TAU)
		if sweep < 1e-12:
			sweep = TAU  # círculo completo
		_p_len = _p_rad * sweep
		# punto más bajo del arco si el barrido pasa por él (ángulo −90°)
		var rel := fposmod((_p_a0 + PI / 2.0) if cw else (-PI / 2.0 - _p_a0), TAU)
		if rel <= sweep:
			rmin = minf(rmin, _p_ccr - _p_rad)
	else:
		var ddr := r1 - _tip_r
		var ddz := z1 - _tip_z
		_p_len = sqrt(ddr * ddr + ddz * ddz)
		_p_ur = ddr / _p_len if _p_len > 0.0 else 0.0
		_p_uz = ddz / _p_len if _p_len > 0.0 else -1.0
	if rmin < -_c_dr - 1e-9 and type != "manual":
		_alarm("X_NEGATIVE", "N%d: X%s: la punta pasaría el eje más de rε; el mínimo con esta herramienta es X−%s (−2·rε)." % [_block_n, _fmt(2.0 * rmin, 3), _fmt(2.0 * _c_dr, 1)])
		return
	if type == "feed" or type == "arc" or type == "manual" or type == "thread":
		var f: Dictionary = m.get("feed", {})
		if not f.is_empty():
			_feed_mode = str(f.get("mode", "mmrev"))
			_feed_val = float(f.get("value", 0.0))
		_p_mode = PM_MMREV if _feed_mode == "mmrev" else PM_MMMIN
		_p_f = _feed_val
		if _spin_dir == 0:
			_alarm("FEED_SPINDLE_STOPPED", "N%d: avance con el cabezal parado: la herramienta empujaría una pieza quieta. Arranca el cabezal (M3/M4) antes del G01." % _block_n)
			return
	elif type == "jog":
		_p_mode = PM_MMMIN
		_p_f = float(_m["jog_mm_min"])
		if _spin_dir == 0 or _mmmin_too_fast():
			_p_cut = false  # con el cabezal parado (o muy lento) la manivela solo posiciona y se para al tocar
	else:
		_p_mode = PM_RAPID
		_p_f = float(_m["rapid_mm_min"])
	if not _p_cut:
		var hit := _first_contact(_tip_r, _tip_z, r1, z1, _p_len)
		_p_stop = hit[0]
		_p_hit = hit[1]
	_mk = MK_PATH
	_mtype = type


## ¿El avance en mm/min daría ahora más de FEED_REV_LIMIT veces el avance por vuelta máximo de la plaquita?
func _mmmin_too_fast() -> bool:
	var f_max := float(_tool["fn_mm"][2]) * FEED_REV_LIMIT
	return _rpm <= 0.0 or minf(_p_f, _feed_max) / _rpm > f_max


## Velocidad sobre la trayectoria (mm/s) con las rpm actuales.
func _path_speed() -> float:
	if _p_mode == PM_MMREV:
		return _p_f * _rpm / 60.0
	if _p_mode == PM_RAPID:
		return _p_f / 60.0
	return minf(_p_f, _feed_max) / 60.0


## Avance por vuelta de la trayectoria actual (mm/rev): el paso entre estampados.
func _feed_per_rev() -> float:
	if _p_mode == PM_MMREV:
		return _p_f
	return minf(_p_f, _feed_max) / maxf(_rpm, 1e-9)


func _advance_path(dt: float) -> float:
	# el cabezal se para (o, en mm/min, gira ya demasiado despacio para el avance) a mitad de un movimiento de corte
	if _p_cut and ((_spin_dir == 0 and _rpm <= 0.0) or (_p_mode == PM_MMMIN and _mmmin_too_fast())):
		if _mtype == "jog":
			# la manivela sigue solo posicionando y se para al tocar la pieza; si el cabezal aún gira, la vuelta en curso
			# corta lo que la herramienta ya tiene delante
			if _rpm > 0.0:
				_stamp_path(_p_s, false)
				if _halted:
					return 0.0
			_p_cut = false
			var hit := _first_contact(_tip_r, _tip_z, _p_r1, _p_z1, _p_len - _p_s)
			_p_stop = _p_s + float(hit[0])
			_p_hit = hit[1]
		elif _mtype != "manual":
			_alarm("FEED_SPINDLE_STOPPED", "N%d: el cabezal está parado o gira demasiado despacio para este avance; la herramienta empujaría la pieza sin cortarla." % _block_n)
			return 0.0
	# roscado: el primer tramo de la pasada espera a que el cabezal llegue a su posición angular
	if _p_sync:
		var spin := _rpm / 60.0
		if spin <= 0.0:
			return 0.0
		var t_sync := _wrap(_sync_phase - _phase) / spin
		if t_sync > dt:
			_phase = _wrap(_phase + spin * dt)
			return 0.0
		_phase = _sync_phase
		_p_sync = false
		dt -= t_sync
	var v := _path_speed()
	var s := _p_s
	var end_s := minf(_p_len, _p_stop)
	var rate := _rpm / 60.0
	if end_s <= s:
		return _end_path(dt)
	if v <= 0.0:
		_phase = _wrap(_phase + rate * dt)
		return 0.0
	var t_need := (end_s - s) / v
	var finishing := t_need <= dt
	var use := t_need if finishing else dt
	var ds := (end_s - s) if finishing else v * use
	var dphi := rate * use
	if _p_cut and dphi > 0.0:
		var k := 1.0 - _phase
		while k <= dphi:
			_stamp_path(s + ds * (k / dphi), true)
			if _halted:
				return 0.0
			k += 1.0
	_phase = _wrap(_phase + dphi)
	_p_s = s + ds
	_pos_at(_p_s)
	_tip_r = _q_r
	_tip_z = _q_z
	# plato y contrapunto: cada vez que la punta avanza una celda de la rejilla (dz) y al final del movimiento
	if _p_cut and (finishing or absf(_tip_r - _fx_r) + absf(_tip_z - _fx_z) >= _dz):
		_fx_r = _tip_r
		_fx_z = _tip_z
		if _fixture_hit(_tip_r, _tip_z):
			return 0.0
	if finishing:
		return _end_path(dt - use)
	return 0.0


## Fin de una trayectoria (o parada en el primer contacto de un rápido). Devuelve el tiempo sobrante del tick.
func _end_path(left: float) -> float:
	if _p_stop < _p_len and _p_s >= _p_stop:
		match _p_hit:
			"material":
				if _mtype == "jog":
					_mk = MK_NONE  # la manivela con el cabezal parado se detiene al tocar: es el «toque» de referencia
					return left
				_alarm("RAPID_IN_MATERIAL", "N%d: G00 contra la pieza en X%s Z%s: en rápido la herramienta no corta, choca. Aproxima en rápido a 1–2 mm y entra en G01." % [_block_n, _fmt(2.0 * _tip_r, 3), _fmt(_tip_z, 3)])
			"chuck":
				_alarm("CHUCK_COLLISION", "N%d: la herramienta choca con las garras o el plato en Z%s (las garras empiezan en Z%s)." % [_block_n, _fmt(_tip_z, 3), _fmt(_z_jaw, 3)])
			"tailstock":
				_alarm("TAILSTOCK_COLLISION", "N%d: la herramienta choca con el contrapunto en X%s Z%s." % [_block_n, _fmt(2.0 * _tip_r, 3), _fmt(_tip_z, 3)])
		_mk = MK_NONE
		return 0.0
	if _p_cut and _rpm > 0.0 and not _p_thread:
		_stamp_path(_p_len, false)
		if _halted:
			return 0.0
	if _mtype == "manual" and _p_axis == "x" and _p_r1 < 0.0:
		_alarm("X_NEGATIVE", "Avance transversal hasta el eje: la punta llega a X−%s (−2·rε); desembraga el avance." % _fmt(2.0 * _re, 1))
	_mk = MK_NONE
	return left


## Termina la trayectoria en la posición actual (desembragar el avance automático).
func _finish_path_here() -> void:
	if _mk != MK_PATH:
		return
	if _p_cut and _rpm > 0.0:
		_stamp_path(_p_s, false)
	_mk = MK_NONE


## Posición y dirección unitaria sobre la trayectoria en la abscisa s (en _q_r, _q_z, _q_dr, _q_dz).
func _pos_at(s: float) -> void:
	if _p_arc:
		var a := _p_a0 + _p_sgn * s / maxf(_p_rad, 1e-12)
		if s >= _p_len:
			_q_r = _p_r1
			_q_z = _p_z1
		else:
			_q_r = _p_ccr + _p_rad * sin(a)
			_q_z = _p_ccz + _p_rad * cos(a)
		_q_dz = -_p_sgn * sin(a)
		_q_dr = _p_sgn * cos(a)
		return
	if s >= _p_len:
		_q_r = _p_r1
		_q_z = _p_z1
	else:
		_q_r = _p_r0 + s * _p_ur
		_q_z = _p_z0 + s * _p_uz
	_q_dr = _p_ur
	_q_dz = _p_uz


# ════════════════════════════════════════ corte ════════════════════════════════════════


## Estampa la herramienta en la abscisa s de la trayectoria. full: vuelta completa (cuenta para la potencia).
## La ap de trabajo es la equivalente por volumen: la profundidad de un cilindrado que arrancaría el mismo ΔV en el
## recorrido desde el estampado anterior, ap = √(r² + ΔV/(π·recorrido)) − r. En régimen es la ap programada; en una
## esquina, donde se limpia el redondeo que dejó la pasada anterior, no se infla como la extensión del contacto. Con ella
## h·b = f·ap cuadra con el volumen arrancado, y deciden el tipo de pasada y la alarma de ap.
func _stamp_path(s: float, full: bool) -> void:
	_pos_at(s)
	var f_rev := _feed_per_rev()
	var travel := s - _p_last_s
	_p_last_s = s
	var dv := _stamp(_q_r + _c_dr, _q_z + _c_dz, _q_dr, _q_dz, f_rev)
	_stamps += 1
	if dv <= 0.0:
		if full:
			_cutting = false
			_pc_kw = 0.0
		return
	_removed += dv
	var rin := maxf(_q_r, 0.0)
	var ap := sqrt(rin * rin + dv / (PI * maxf(travel, 1e-4))) - rin
	if _p_thread:
		ap = _st_ap  # al roscar, la profundidad de la pasada es la extensión radial de lo que corta la V
	# tipo de pasada del movimiento: con la mayor ap de sus vueltas completas (o la del estampado si aún no hay ninguna)
	var kind := _p_pass
	if kind <= 0:
		if full:
			_p_apmax = maxf(_p_apmax, ap)
			_p_kind = PASS_FINISH if (_p_apmax <= FINISH_AP_MAX and f_rev <= FINISH_F_MAX) else PASS_ROUGH
			kind = _p_kind
		elif _p_kind > 0:
			kind = _p_kind
		else:
			kind = PASS_FINISH if (ap <= FINISH_AP_MAX and f_rev <= FINISH_F_MAX) else PASS_ROUGH
	for i in range(_st_lo, _st_hi + 1):
		if _src_g[i] == _gi and _src_cr[i] == _q_r + _c_dr and _src_cz[i] == _q_z + _c_dz:
			_pass[i] = kind
	# modelo de corte: h = f·sen κr, b = ap/sen κr, vc en el diámetro de la punta
	var kr_e := LatheTools.kr_eff_deg(_tool, ap)
	var sk := maxf(sin(deg_to_rad(kr_e)), 1e-3)
	var h := f_rev * sk
	var b := ap / sk
	if _p_thread:
		# roscado: la viruta de una vuelta es el anillo de la V nueva menos la vieja, de sección A = ΔV/(2π·r); la corta
		# el largo de filo b que ha tocado, así que h = A/b (el paso no es el espesor de viruta)
		var r_mid := maxf(_q_r + 0.5 * _st_ap, 1e-3)
		b = maxf(_st_edge, 1e-4)
		h = dv / (TAU * r_mid) / b
	var vc := PI * 2.0 * absf(_q_r) * _rpm / 1000.0
	# el modelo de corte recibe el material de la pieza y el de la herramienta (ids de work_materials.gd y
	# tool_materials.gd); una herramienta sin tool_material pasa su id, como en los tests con un modelo de prueba
	var res: Dictionary = _cut.call(_stock.get("work_id", ""), _tool.get("tool_material", _tool.get("id", "")), h, b, vc)
	var kc := float(res.get("kc", 0.0))
	# sin datos de fuerza (madera, plástico, vidrio…) el modelo devuelve ok = false: se corta la geometría, pero la
	# potencia no es real y el estado lo dice con su motivo
	_cut_ok = res.get("ok", true) != false
	_cut_reason = "" if _cut_ok else String(res.get("reason", "sin datos de corte para este material"))
	_energy_j += kc * dv * 1e-3  # N/mm² · mm³ = N·mm = mJ
	if full and _rpm > 0.0:
		_cutting = true
		_kc = kc
		_h = h
		_b = b
		_ap = ap
		_contact = _st_ap
		_vc = vc
		_fc_n = float(res.get("fc_n", kc * h * b))
		_pc_kw = kc * dv / (60.0 / _rpm) * 1e-6  # N·mm/s → kW
		_pc_peak = maxf(_pc_peak, _pc_kw)
	# alarmas del corte
	# La ap máxima del catálogo es para un corte sostenido: rompe la plaquita si se pasa durante más de una vuelta
	# seguida. Una sola vuelta por encima es la llegada a un hombro o a un escalón con su creces en Z (≤ f): todo el filo
	# toca la cara un instante, que es la forma normal de acabar un hombro, y se avisa sin parar la máquina. Solo cuentan
	# las vueltas completas: en el estampado parcial del final de un movimiento, la ap equivalente se infla con el
	# volumen del frente de la punta dividido por un recorrido muy corto, y no es una pasada real.
	var ap_max: float = _tool["ap_max_mm"]
	if full:
		_over_revs = _over_revs + 1 if ap > ap_max + 1e-6 else 0
		if _over_revs >= AP_SUSTAINED_REVS:
			_alarm("AP_EXCEEDED", "N%d: profundidad de pasada de %s mm; la plaquita %s admite %s mm como máximo (Sandvik). Se rompe." % [_block_n, _fmt(ap, 2), _tool["insert"], _fmt(ap_max, 1)])
			return
		if _over_revs == 1:
			_alarm("AP_PEAK", "N%d: durante una vuelta el filo toca %s mm de altura (la plaquita %s admite %s mm en un corte sostenido): al llegar a un hombro con su creces es normal; si durara más vueltas, rompería." % [_block_n, _fmt(ap, 2), _tool["insert"], _fmt(ap_max, 1)])
	if _q_dz < -1e-9 and _q_dr < -1e-9:
		var alpha := rad_to_deg(atan2(-_q_dr, -_q_dz))
		var amax: float = _tool["copy_angle_max_deg"]
		if alpha > amax + 1e-6:
			_alarm("FLANK_RUB", "N%d: rampa de %s° hacia el plato; con κr' = %s° el filo secundario solo admite %s° (2° de ángulo libre, Sandvik): la herramienta talona y estropea la superficie." % [_block_n, _fmt(alpha, 1), _fmt(float(_tool["kr_minor_deg"]), 1), _fmt(amax, 1)])
	if _chain_hits_material(_holder_chain, _q_z, _q_r):
		_alarm("HOLDER_COLLISION", "N%d: el portaherramientas toca la pieza con la punta en X%s Z%s: la plaquita no llega ahí sin que choque la cabeza." % [_block_n, _fmt(2.0 * _q_r, 3), _fmt(_q_z, 3)])
		return
	if full and _pc_kw > _power:
		_alarm("OVERLOAD", "N%d: potencia de corte %s kW; el cabezal da %s kW. Baja ap, f o la velocidad de corte." % [_block_n, _fmt(_pc_kw, 1), _fmt(_power, 1)])


## Estampa la envolvente de corte con el centro de la punta en (cr, cz): r = min(r, envolvente). (dr, dzv): dirección
## de avance. Devuelve el volumen arrancado (mm³); deja en _st_ap la extensión del contacto perpendicular al avance y
## en _st_lo/_st_hi los anillos tocados. Va por bloques: la envolvente baja hasta la punta y vuelve a subir (su mínimo
## en un tramo está en un extremo o en la punta), así que los bloques que no puede alcanzar se saltan enteros; el
## filo secundario de 12 mm de una C 80° casi nunca toca y no se recorre.
func _stamp(cr: float, cz: float, dr: float, dzv: float, f_rev: float) -> float:
	var i0 := maxi(ceili((cz + _gu_lo - _z0) / _dz - 1e-9), 0)
	var i1 := mini(floori((cz + _gu_hi - _z0) / _dz + 1e-9), _n - 1)
	_st_ap = 0.0
	_st_lo = -1
	_st_hi = -1
	_st_edge = 0.0
	if i0 > i1:
		return 0.0
	var edge_i := -2  # roscado: último anillo cortado y su radio nuevo, para medir el filo que corta
	var edge_e := 0.0
	var nr := -dzv  # normal a la dirección de avance
	var nz := dr
	var pmin := INF
	var pmax := -INF
	var sum := 0.0
	var lo := -1
	var hi := -1
	for blk in range(floori(float(i0) / BLK), floori(float(i1) / BLK) + 1):
		var ia := maxi(i0, blk * BLK)
		var ib := mini(i1, blk * BLK + BLK - 1)
		var ua := _z0 + ia * _dz - cz
		var ub := _z0 + ib * _dz - cz
		var emin := -_re if (ua <= 0.0 and ub >= 0.0) else minf(_env_u(ua), _env_u(ub))
		if cr + emin >= _bmax[blk]:
			continue
		if _bstale[blk] == 1:
			_refresh_block(blk)
			if cr + emin >= _bmax[blk]:
				continue
		for i in range(ia, ib + 1):
			var z := _z0 + i * _dz
			var u := z - cz
			var e: float
			if u < _gu_maj:
				e = _ge_maj + (_gu_maj - u) * _gt_maj
			elif u <= _gu_min:
				e = -sqrt(maxf(_gre2 - u * u, 0.0))
			else:
				e = _ge_min + (u - _gu_min) * _gt_min
			e += cr
			var old := _r[i]
			if e < old:
				if e < 0.0:
					e = 0.0
					if old <= 0.0:
						continue
				sum += old * old - e * e
				_r[i] = e
				_src_cr[i] = cr
				_src_cz[i] = cz
				_src_g[i] = _gi
				_src_f[i] = f_rev
				var pz := nz * z
				var p1 := nr * e + pz
				var p2 := nr * old + pz
				pmin = minf(pmin, minf(p1, p2))
				pmax = maxf(pmax, maxf(p1, p2))
				if _p_thread and old - e > TOL:
					_st_edge += sqrt(_dz * _dz + (e - edge_e) * (e - edge_e)) if edge_i == i - 1 else _dz
					edge_i = i
					edge_e = e
				if lo < 0:
					lo = i
				hi = i
	if lo < 0:
		return 0.0
	_st_ap = pmax - pmin
	_st_lo = lo
	_st_hi = hi
	_mark_changed(lo, hi, f_rev)
	return PI * sum * _dz


## Envolvente de corte de la herramienta montada en u (relativa al centro de la punta), sin comprobar el rango.
func _env_u(u: float) -> float:
	if u < _gu_maj:
		return _ge_maj + (_gu_maj - u) * _gt_maj
	if u <= _gu_min:
		return -sqrt(maxf(_gre2 - u * u, 0.0))
	return _ge_min + (u - _gu_min) * _gt_min


func _mark_changed(lo: int, hi: int, f_rev: float) -> void:
	var half := 0.5 * _ra_span(f_rev)
	_ra_margin = maxi(_ra_margin, ceili(half / _dz) + RA_BLOCK + 1)
	var a := maxi(lo - _ra_margin, 0)
	var b := mini(hi + _ra_margin, _n - 1)
	_dirty_lo = a if _dirty_lo < 0 else mini(_dirty_lo, a)
	_dirty_hi = b if _dirty_hi < 0 else maxi(_dirty_hi, b)
	_ra_lo = lo if _ra_lo < 0 else mini(_ra_lo, lo)
	_ra_hi = hi if _ra_hi < 0 else maxi(_ra_hi, hi)
	for blk in range(floori(float(lo) / BLK), floori(float(hi) / BLK) + 1):
		_bstale[blk] = 1


func _refresh_block(blk: int) -> void:
	var m := 0.0
	for i in range(blk * BLK, mini(blk * BLK + BLK, _n)):
		m = maxf(m, _r[i])
	_bmax[blk] = m
	_bstale[blk] = 0


# ════════════════════════════════════════ colisiones ════════════════════════════════════════


## Primer contacto de la herramienta barrida de (ra, za) a (rb, zb): [abscisa s de parada (INF si no toca), qué toca].
## La envolvente barrida es convexa y crece con el recorrido, así que la bisección sobre la fracción es exacta.
## Si la herramienta ya está metida en el material al empezar (se detuvo a mitad de corte por una alarma), ese solape
## inicial no cuenta: solo penetrar más allá de él. Así, tras RESET, se puede retirar.
func _first_contact(ra: float, za: float, rb: float, zb: float, total: float) -> Array:
	var d0 := _static_depth(ra, za)
	var tm := TOL + d0[0]
	var tf := TOL + d0[1]
	var what := _sweep_hit(ra, za, rb, zb, tm, tf)
	if what == "":
		return [INF, ""]
	if _sweep_hit(ra, za, ra, za, tm, tf) != "":
		return [0.0, _sweep_hit(ra, za, ra, za, tm, tf)]
	var lo := 0.0
	var hi := 1.0
	for k in 40:
		var t := 0.5 * (lo + hi)
		if _sweep_hit(ra, za, ra + t * (rb - ra), za + t * (zb - za), tm, tf) != "":
			hi = t
		else:
			lo = t
	return [lo * total, _sweep_hit(ra, za, ra + hi * (rb - ra), za + hi * (zb - za), tm, tf)]


## Cuánto se meten ya en la herramienta, con la punta en (r, z), el material y el plato o el contrapunto:
## [penetración en el material, penetración en los amarres] (0 si no los toca).
func _static_depth(r: float, z: float) -> PackedFloat64Array:
	var dm := 0.0
	var df := 0.0
	for ch in [_circle_chain, _insert_chain, _holder_chain]:
		if ch.size() >= 2:
			dm = maxf(dm, _chain_depth(ch, z, r))
			df = maxf(df, _chain_top_depth(ch, z, r, _chuck_poly))
			if _tailstock:
				df = maxf(df, _chain_top_depth(ch, z, r, _tail_poly))
	return PackedFloat64Array([dm, df])


## Qué toca la herramienta barrida entre dos posiciones de la punta: «material», «chuck», «tailstock» o «».
func _sweep_hit(ra: float, za: float, rb: float, zb: float, tol_mat: float = TOL, tol_fix: float = TOL) -> String:
	var shapes: Array[PackedFloat64Array] = [_capsule_chain(za + _c_dz, ra + _c_dr, zb + _c_dz, rb + _c_dr, _re)]
	if _insert_rel.size() > 0:
		shapes.append(_swept_chain(_insert_rel, za, ra, zb, rb))
	shapes.append(_swept_chain(_holder_rel, za, ra, zb, rb))
	for ch in shapes:
		if _chain_hits_material(ch, 0.0, 0.0, tol_mat):
			return "material"
		if _chain_hits_top(ch, 0.0, 0.0, _chuck_poly, tol_fix):
			return "chuck"
		if _tailstock and _chain_hits_top(ch, 0.0, 0.0, _tail_poly, tol_fix):
			return "tailstock"
	return ""


## Choque con el plato o el contrapunto durante un avance, con la herramienta en la punta (r, z). Se comprueba cada vez
## que la punta avanza una celda de la rejilla, así que el choque se detecta con esa resolución (0,02 mm) o, a más de
## 1,2 m/min, con la de un tick. Lanza la alarma y devuelve true.
func _fixture_hit(r: float, z: float) -> bool:
	var near_chuck := z + _tool_dz_min < _z_jaw + 1.0
	var near_tail := _tailstock and z + _tool_dz_max > _z_face - 1.0
	if not near_chuck and not near_tail:
		return false
	for ch in [_circle_chain, _insert_chain, _holder_chain]:
		if ch.size() < 2:
			continue
		if near_chuck and _chain_hits_top(ch, z, r, _chuck_poly):
			_alarm("CHUCK_COLLISION", "N%d: la herramienta choca con las garras o el plato en Z%s (las garras empiezan en Z%s)." % [_block_n, _fmt(z, 3), _fmt(_z_jaw, 3)])
			return true
		if near_tail and _chain_hits_top(ch, z, r, _tail_poly):
			_alarm("TAILSTOCK_COLLISION", "N%d: la herramienta choca con el contrapunto en X%s Z%s." % [_block_n, _fmt(2.0 * r, 3), _fmt(z, 3)])
			return true
	return false


## Perfil superior del plato como obstáculo (z, r): cuerpo hasta las garras y garras sobre el bruto.
func _chuck_top() -> PackedFloat64Array:
	var jl: float = _m["jaw_len"]
	var body := 0.5 * float(_m["chuck_d"])
	var jaw := _r_stock + float(_m["jaw_h"])
	return PackedFloat64Array([-1e6, body, _z_jaw - jl, body, _z_jaw - jl, jaw, _z_jaw, jaw])


## Perfil superior del contrapunto: cono de 60° desde la cara, cuerpo del punto y caña.
func _tail_top() -> PackedFloat64Array:
	var zf := _z_face
	var cone := (float(TAIL["r_body"]) - float(TAIL["r_tip"])) / tan(deg_to_rad(30.0))
	var be: float = TAIL["body_end"]
	return PackedFloat64Array([zf, TAIL["r_tip"], zf + cone, TAIL["r_body"], zf + be, TAIL["r_body"], zf + be, TAIL["r_quill"], 1e6, TAIL["r_quill"]])


## Cadena inferior (z creciente) de la cápsula que barre el círculo de radio rad entre dos centros: envolvente convexa
## inferior de dos polígonos inscritos (error < 0,1 % del radio, por dentro: un contacto rasante no cuenta).
func _capsule_chain(za: float, ra: float, zb: float, rb: float, rad: float) -> PackedFloat64Array:
	var pts := PackedFloat64Array()
	var steps := roundi(180.0 / CIRCLE_STEP_DEG)
	for c in 2:
		var cz := za if c == 0 else zb
		var cr := ra if c == 0 else rb
		for k in steps + 1:
			var a := PI + PI * k / steps
			pts.append(cz + rad * cos(a))
			pts.append(cr + rad * sin(a))
	return _lower_hull(pts)


## Cadena inferior de un polígono convexo relativo a la punta, barrido entre dos posiciones de la punta.
func _swept_chain(poly: PackedFloat64Array, za: float, ra: float, zb: float, rb: float) -> PackedFloat64Array:
	var pts := PackedFloat64Array()
	for k in range(0, poly.size(), 2):
		pts.append(poly[k] + za)
		pts.append(poly[k + 1] + ra)
		pts.append(poly[k] + zb)
		pts.append(poly[k + 1] + rb)
	return _lower_hull(pts)


## Envolvente convexa inferior (cadena monótona de Andrew) de puntos (z, r): vértices con z creciente.
static func _lower_hull(flat: PackedFloat64Array) -> PackedFloat64Array:
	var n := flat.size() / 2
	var idx: Array[int] = []
	for i in n:
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool: return flat[2 * a] < flat[2 * b] or (flat[2 * a] == flat[2 * b] and flat[2 * a + 1] < flat[2 * b + 1]))
	var h: Array[int] = []
	for i in idx:
		while h.size() >= 2:
			var o := h[h.size() - 2]
			var a := h[h.size() - 1]
			var cross := (flat[2 * a] - flat[2 * o]) * (flat[2 * i + 1] - flat[2 * o + 1]) - (flat[2 * a + 1] - flat[2 * o + 1]) * (flat[2 * i] - flat[2 * o])
			if cross <= 0.0:
				h.pop_back()
			else:
				break
		h.append(i)
	var out := PackedFloat64Array()
	for i in h:
		out.append(flat[2 * i])
		out.append(flat[2 * i + 1])
	return out


## ¿La cadena inferior ch (desplazada oz, orr) entra en el material más de TOL? El material de cada anillo ocupa [0, r]:
## un anillo vacío (r = 0) no se toca aunque la herramienta pase del eje. Descarta bloques enteros con el índice de
## radios máximos.
func _chain_hits_material(ch: PackedFloat64Array, oz: float, orr: float, tol: float = TOL) -> bool:
	var m := ch.size() / 2
	if m < 1:
		return false
	var i0 := maxi(ceili((ch[0] + oz - _z0) / _dz), 0)
	var i1 := mini(floori((ch[2 * m - 2] + oz - _z0) / _dz), _n - 1)
	if i0 > i1:
		return false
	var cmin := INF
	for k in m:
		cmin = minf(cmin, ch[2 * k + 1])
	cmin += orr
	var seg := 0
	for blk in range(floori(float(i0) / BLK), floori(float(i1) / BLK) + 1):
		var floor_r := maxf(cmin, 0.0)
		if floor_r >= _bmax[blk] - tol:
			continue
		if _bstale[blk] == 1:
			_refresh_block(blk)
			if floor_r >= _bmax[blk] - tol:
				continue
		for i in range(maxi(i0, blk * BLK), mini(i1, blk * BLK + BLK - 1) + 1):
			var z := _z0 + i * _dz - oz
			while seg < m - 2 and ch[2 * seg + 2] < z:
				seg += 1
			var low := ch[2 * seg + 1]
			if m >= 2:
				var za := ch[2 * seg]
				var zb := ch[2 * seg + 2]
				if zb > za:
					low = ch[2 * seg + 1] + (ch[2 * seg + 3] - ch[2 * seg + 1]) * clampf((z - za) / (zb - za), 0.0, 1.0)
				else:
					low = minf(ch[2 * seg + 1], ch[2 * seg + 3])
			if _r[i] > maxf(low + orr, 0.0) + tol:
				return true
	return false


## Penetración máxima (mm) del material en la cadena inferior ch desplazada (oz, orr); 0 si no la toca.
func _chain_depth(ch: PackedFloat64Array, oz: float, orr: float) -> float:
	var m := ch.size() / 2
	var i0 := maxi(ceili((ch[0] + oz - _z0) / _dz), 0)
	var i1 := mini(floori((ch[2 * m - 2] + oz - _z0) / _dz), _n - 1)
	var d := 0.0
	var seg := 0
	for i in range(i0, i1 + 1):
		var z := _z0 + i * _dz - oz
		while seg < m - 2 and ch[2 * seg + 2] < z:
			seg += 1
		var za := ch[2 * seg]
		var zb := ch[2 * seg + 2]
		var low := ch[2 * seg + 1]
		if zb > za:
			low = ch[2 * seg + 1] + (ch[2 * seg + 3] - ch[2 * seg + 1]) * clampf((z - za) / (zb - za), 0.0, 1.0)
		d = maxf(d, _r[i] - maxf(low + orr, 0.0))
	return d


## ¿La cadena inferior ch (desplazada oz, orr) entra más de tol por debajo del perfil superior de un obstáculo (z, r)
## (plato, contrapunto)?
func _chain_hits_top(ch: PackedFloat64Array, oz: float, orr: float, top: PackedFloat64Array, tol: float = TOL) -> bool:
	return _chain_top_depth(ch, oz, orr, top) > tol


## Penetración máxima (mm) del obstáculo top en la cadena inferior ch desplazada (oz, orr); 0 si no la toca. Ambos son
## poligonales: basta mirar en los vértices de los dos dentro del tramo común.
func _chain_top_depth(ch: PackedFloat64Array, oz: float, orr: float, top: PackedFloat64Array) -> float:
	var za := maxf(ch[0] + oz, top[0])
	var zb := minf(ch[ch.size() - 2] + oz, top[top.size() - 2])
	if za > zb:
		return 0.0
	var d := maxf(_top_over(ch, oz, orr, top, za), _top_over(ch, oz, orr, top, zb))
	for k in range(0, ch.size(), 2):
		# en los vértices de la cadena su valor es el del propio vértice: solo hay que evaluar el obstáculo
		var zk := ch[k] + oz
		if zk > za and zk < zb:
			d = maxf(d, _poly_eval(top, zk, true) - maxf(ch[k + 1] + orr, 0.0))
	for k in range(0, top.size(), 2):
		if top[k] > za and top[k] < zb:
			d = maxf(d, _top_over(ch, oz, orr, top, top[k]))
	return maxf(d, 0.0)


func _top_over(ch: PackedFloat64Array, oz: float, orr: float, top: PackedFloat64Array, z: float) -> float:
	return _poly_eval(top, z, true) - maxf(_poly_eval(ch, z - oz, false) + orr, 0.0)


## Valor de una poligonal (z, r) en z; en un escalón vertical, el mayor (upper) o el menor de los dos lados.
static func _poly_eval(p: PackedFloat64Array, z: float, upper: bool) -> float:
	var m := p.size() / 2
	var best := -INF if upper else INF
	var found := false
	for k in m - 1:
		var za := p[2 * k]
		var zb := p[2 * k + 2]
		if z < za or z > zb:
			continue
		var v := p[2 * k + 1] if zb <= za else p[2 * k + 1] + (p[2 * k + 3] - p[2 * k + 1]) * (z - za) / (zb - za)
		if zb <= za:
			v = maxf(p[2 * k + 1], p[2 * k + 3]) if upper else minf(p[2 * k + 1], p[2 * k + 3])
		best = maxf(best, v) if upper else minf(best, v)
		found = true
	if not found:
		return -INF if upper else INF
	return best


# ════════════════════════════════════════ alarmas ════════════════════════════════════════


## Registra una alarma una sola vez por movimiento. Las que detienen paran el programa y el cabezal.
func _alarm(code: String, msg: String) -> void:
	var key := "%s:%d:%d" % [code, _block_n, _cur_serial]
	if _alarm_keys.has(key):
		return
	_alarm_keys[key] = true
	_alarms.append({ "code": code, "n": _block_n, "message": msg })
	if ALARMS[code]["halt"]:
		_halted = true
		_mk = MK_NONE
		_spin_dir = 0
		_css_vc = 0.0
		_cutting = false
		_pc_kw = 0.0


## Número con coma decimal y d decimales (toFixed de JavaScript).
static func _fmt(x: float, d: int) -> String:
	return Js.to_fixed(x, d).replace(".", ",")


# ════════════════════════════════════════ rugosidad ════════════════════════════════════════


func _update_ra() -> void:
	if _ra_lo < 0:
		return
	var b0 := floori(float(maxi(_ra_lo - _ra_margin, 0)) / RA_BLOCK)
	var b1 := floori(float(mini(_ra_hi + _ra_margin, _n - 1)) / RA_BLOCK)
	for blk in range(b0, b1 + 1):
		_ra_block(blk)
	_ra_lo = -1
	_ra_hi = -1


## Ra de un bloque de anillos: el del anillo mecanizado más cercano a su centro, medido en su ventana.
func _ra_block(blk: int) -> void:
	var s := blk * RA_BLOCK
	var e := mini(s + RA_BLOCK - 1, _n - 1)
	var mid := floori(float(s + e) / 2.0)
	var c := -1
	for k in RA_BLOCK:
		if mid - k >= s and _src_g[mid - k] >= 0:
			c = mid - k
			break
		if mid + k <= e and _src_g[mid + k] >= 0:
			c = mid + k
			break
	var ra := _raw_ra
	if c >= 0:
		ra = _ra_window(c)
	for i in range(s, e + 1):
		_ra[i] = ra if _src_g[i] >= 0 else _raw_ra


## Longitud de evaluación de Ra para un avance f: un número entero de avances, al menos 4 y al menos 0,8 mm.
func _ra_span(f: float) -> float:
	var span := RA_SAMPLING_MM
	if f > 1e-6:
		span = f * maxi(RA_MIN_FEEDS, ceili(RA_SAMPLING_MM / f - 1e-9))
	return minf(span, 2.0 * RA_HALF_MAX * _dz)


## Ra (µm) alrededor del anillo c: ventana de un número entero de avances (≥ 4 y ≥ 0,8 mm) que se corta en los
## escalones, en el material bruto y en las aristas (donde cambia la pendiente media sobre un avance, que no ve las
## crestas); línea media cuadrática (quita la forma de radios y conos suaves).
func _ra_window(c: int) -> float:
	var f: float = _src_f[c]
	var half := 0.5 * _ra_span(f)
	var p := maxi(1, roundi(f / _dz)) if f > 1e-6 else 1
	var s_c := _slope_over(c, p)
	var zc := _z0 + c * _dz
	var jl := c
	while jl > 0 and _src_g[jl - 1] >= 0 and absf(_r[jl - 1] - _r[jl]) <= JUMP_MM and zc - (_z0 + (jl - 1) * _dz) <= half + _dz and absf(_slope_over(jl - 1, p) - s_c) <= KINK_SLOPE:
		jl -= 1
	var jr := c
	while jr < _n - 1 and _src_g[jr + 1] >= 0 and absf(_r[jr + 1] - _r[jr]) <= JUMP_MM and (_z0 + (jr + 1) * _dz) - zc <= half + _dz and absf(_slope_over(jr + 1, p) - s_c) <= KINK_SLOPE:
		jr += 1
	var za := maxf(zc - half, _z0 + jl * _dz)
	var zb := minf(zc + half, _z0 + jr * _dz)
	if zb - za < 3.0 * _dz or _r[c] <= 0.0:
		# cara o anillo aislado: el perfil r(z) no lo mide; se da el Ra teórico de sus marcas de avance
		var re: float = _geos[_src_g[c]]["re"]
		return 1000.0 * 4.0 / (9.0 * sqrt(3.0)) * f * f / (8.0 * re)
	var m := _measure(jl, jr, za, zb, 2 if zb - za >= 3.0 * maxf(f, _dz) else 1)
	return m["ra_um"]


## Pendiente media dr/dz sobre p anillos (un avance) centrada en j: las crestas se repiten cada avance y no la cambian.
func _slope_over(j: int, p: int) -> float:
	var a := clampi(j - floori(p / 2.0), 0, _n - 1)
	var b := clampi(a + p, 0, _n - 1)
	if b <= a:
		return 0.0
	return (_r[b] - _r[a]) / ((b - a) * _dz)


## Envolvente del estampado que dejó el anillo j, evaluada en z (INF fuera de la herramienta; el bruto es plano).
func _env_src(j: int, z: float) -> float:
	var gi := _src_g[j]
	if gi < 0:
		return _r[j]
	var o := gi * GP
	var u := z - _src_cz[j]
	if u < _gp[o] or u > _gp[o + 1]:
		return INF
	if u < _gp[o + 2]:
		return _src_cr[j] + _gp[o + 3] + (_gp[o + 2] - u) * _gp[o + 4]
	if u <= _gp[o + 5]:
		return _src_cr[j] - sqrt(maxf(_gp[o + 8] - u * u, 0.0))
	return _src_cr[j] + _gp[o + 6] + (u - _gp[o + 5]) * _gp[o + 7]


## Cresta entre los anillos j y j + 1: el punto donde se cruzan las envolventes de sus dos estampados ([z, r] o vacío).
func _crest(j: int) -> PackedFloat64Array:
	if _src_g[j] == _src_g[j + 1] and _src_cr[j] == _src_cr[j + 1] and _src_cz[j] == _src_cz[j + 1]:
		return PackedFloat64Array()
	var a := _z0 + j * _dz
	var b := a + _dz
	if not (_env_src(j, a) <= _env_src(j + 1, a) and _env_src(j, b) >= _env_src(j + 1, b)):
		return PackedFloat64Array()
	var fast := _crest_arcs(j, a, b)
	if fast.size() == 2:
		return fast
	for k in 24:
		var mid := 0.5 * (a + b)
		if _env_src(j, mid) <= _env_src(j + 1, mid):
			a = mid
		else:
			b = mid
	var z := 0.5 * (a + b)
	var r := minf(_env_src(j, z), _env_src(j + 1, z))
	if not is_finite(r):
		return PackedFloat64Array()
	return PackedFloat64Array([z, maxf(r, 0.0)])


## Cresta exacta cuando las dos envolventes son arcos de punta (el caso normal): intersección inferior de los dos
## círculos, si cae entre los dos anillos y en la parte de arco de ambas herramientas. Si no, vacío (bisección).
func _crest_arcs(j: int, za: float, zb: float) -> PackedFloat64Array:
	var g1 := _src_g[j]
	var g2 := _src_g[j + 1]
	if g1 < 0 or g2 < 0:
		return PackedFloat64Array()
	var r1 := _gp[g1 * GP + 9]
	var r2 := _gp[g2 * GP + 9]
	var z1 := _src_cz[j]
	var c1 := _src_cr[j]
	var z2 := _src_cz[j + 1]
	var c2 := _src_cr[j + 1]
	var dzc := z2 - z1
	var drc := c2 - c1
	var d := sqrt(dzc * dzc + drc * drc)
	if d <= 1e-12 or d > r1 + r2 or d < absf(r1 - r2):
		return PackedFloat64Array()
	var a := (r1 * r1 - r2 * r2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(r1 * r1 - a * a, 0.0))
	var pz := z1 + a * dzc / d
	var pr := c1 + a * drc / d
	# de los dos cortes, el de menor r
	var qz := pz + h * drc / d
	var qr := pr - h * dzc / d
	var oz := pz - h * drc / d
	var orr := pr + h * dzc / d
	if orr < qr:
		qz = oz
		qr = orr
	if qz < za or qz > zb or qr > c1 or qr > c2:
		return PackedFloat64Array()
	var u1 := qz - z1
	var u2 := qz - z2
	if u1 < _gp[g1 * GP + 2] or u1 > _gp[g1 * GP + 5] or u2 < _gp[g2 * GP + 2] or u2 > _gp[g2 * GP + 5]:
		return PackedFloat64Array()
	return PackedFloat64Array([qz, maxf(qr, 0.0)])


## Ra, Rt y Rz (µm) del perfil entre za y zb (anillos jl..jr): muestras de los anillos más las crestas reconstruidas,
## línea media por mínimos cuadrados (order 1 recta, 2 parábola) e integral de |y| sobre la poligonal.
func _measure(jl: int, jr: int, za: float, zb: float, order: int) -> Dictionary:
	var pz := PackedFloat64Array()
	var pr := PackedFloat64Array()
	var crests := 0
	for j in range(jl, jr + 1):
		pz.append(_z0 + j * _dz)
		pr.append(_r[j])
		if j < jr:
			var c := _crest(j)
			if c.size() == 2:
				pz.append(c[0])
				pr.append(c[1])
				crests += 1
	# línea media: mínimos cuadrados sobre las muestras de los anillos (equiespaciadas), en x centrada y escalada
	var zm := 0.5 * (za + zb)
	var hw := maxf(0.5 * (zb - za), 1e-9)
	var y0 := _r[floori(float(jl + jr) / 2.0)]
	var s0 := 0.0
	var s1 := 0.0
	var s2 := 0.0
	var s3 := 0.0
	var s4 := 0.0
	var t0 := 0.0
	var t1 := 0.0
	var t2 := 0.0
	for j in range(jl, jr + 1):
		var x := (_z0 + j * _dz - zm) / hw
		var y := _r[j] - y0
		var x2 := x * x
		s0 += 1.0
		s1 += x
		s2 += x2
		s3 += x2 * x
		s4 += x2 * x2
		t0 += y
		t1 += x * y
		t2 += x2 * y
	var coef := _lsq(PackedFloat64Array([s0, s1, s2, s3, s4]), PackedFloat64Array([t0, t1, t2]), order)
	var c0 := coef[0]
	var c1 := coef[1]
	var c2 := coef[2]
	# residuos, área de |y| sobre la poligonal recortada a [za, zb], picos y valles (Rt y las 5 partes de Rz)
	var area := 0.0
	var ymax := -INF
	var ymin := INF
	var pmax := PackedFloat64Array([-INF, -INF, -INF, -INF, -INF])
	var pmin := PackedFloat64Array([INF, INF, INF, INF, INF])
	var span := zb - za
	var n := pz.size()
	var xa := (pz[0] - zm) / hw
	var ya := pr[0] - y0 - (c0 + c1 * xa + c2 * xa * xa)
	for k in range(1, n):
		var xb := (pz[k] - zm) / hw
		var yb := pr[k] - y0 - (c0 + c1 * xb + c2 * xb * xb)
		var z1 := pz[k - 1]
		var z2 := pz[k]
		var y1 := ya
		var y2 := yb
		ya = yb
		if z2 <= za or z1 >= zb or z2 <= z1:
			continue
		if z1 < za:
			y1 = y1 + (y2 - y1) * (za - z1) / (z2 - z1)
			z1 = za
		if z2 > zb:
			y2 = y1 + (y2 - y1) * (zb - z1) / (z2 - z1)
			z2 = zb
		var w := z2 - z1
		if (y1 >= 0.0) == (y2 >= 0.0):
			area += 0.5 * (absf(y1) + absf(y2)) * w
		else:
			area += 0.5 * (y1 * y1 + y2 * y2) / absf(y2 - y1) * w
		ymax = maxf(ymax, maxf(y1, y2))
		ymin = minf(ymin, minf(y1, y2))
		var q1 := clampi(floori((z1 - za) / span * 5.0), 0, 4)
		var q2 := clampi(floori((z2 - za) / span * 5.0), 0, 4)
		pmax[q1] = maxf(pmax[q1], y1)
		pmin[q1] = minf(pmin[q1], y1)
		pmax[q2] = maxf(pmax[q2], y2)
		pmin[q2] = minf(pmin[q2], y2)
	var rz := 0.0
	var cnt := 0
	for k in 5:
		if pmax[k] > -INF and pmin[k] < INF:
			rz += pmax[k] - pmin[k]
			cnt += 1
	var rt := (ymax - ymin) if ymax > -INF else 0.0
	var dsum := 0.0
	for j in range(jl, jr + 1):
		dsum += 2.0 * _r[j]
	return {
		"ra_um": 1000.0 * area / span, "rt_um": 1000.0 * rt, "rz_um": 1000.0 * rz / maxi(cnt, 1),
		"points": n, "crests": crests, "d_mm": dsum / (jr - jl + 1),
	}


## Mínimos cuadrados de grado 1 o 2 con las sumas de potencias sx[k] = Σxᵏ y sy[k] = Σxᵏ·y. Devuelve [c0, c1, c2].
static func _lsq(sx: PackedFloat64Array, sy: PackedFloat64Array, order: int) -> PackedFloat64Array:
	if order >= 2:
		# eliminación de Gauss con pivote parcial sobre la matriz ampliada 3 × 4 (en filas de un array plano)
		var a := PackedFloat64Array([sx[0], sx[1], sx[2], sy[0], sx[1], sx[2], sx[3], sy[1], sx[2], sx[3], sx[4], sy[2]])
		var ok := true
		for col in 3:
			var piv := col
			for row in range(col + 1, 3):
				if absf(a[row * 4 + col]) > absf(a[piv * 4 + col]):
					piv = row
			if piv != col:
				for k in 4:
					var tmp := a[col * 4 + k]
					a[col * 4 + k] = a[piv * 4 + k]
					a[piv * 4 + k] = tmp
			if absf(a[col * 4 + col]) < 1e-300:
				ok = false
				break
			for row in range(col + 1, 3):
				var fct := a[row * 4 + col] / a[col * 4 + col]
				for k in range(col, 4):
					a[row * 4 + k] -= fct * a[col * 4 + k]
		if ok:
			var q2 := a[11] / a[10]
			var q1 := (a[7] - a[6] * q2) / a[5]
			var q0 := (a[3] - a[1] * q1 - a[2] * q2) / a[0]
			return PackedFloat64Array([q0, q1, q2])
	var det := sx[0] * sx[2] - sx[1] * sx[1]
	if absf(det) < 1e-300:
		return PackedFloat64Array([sy[0] / maxf(sx[0], 1.0), 0.0, 0.0])
	return PackedFloat64Array([(sy[0] * sx[2] - sx[1] * sy[1]) / det, (sx[0] * sy[1] - sx[1] * sy[0]) / det, 0.0])
