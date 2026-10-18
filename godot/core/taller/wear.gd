## Taller · desgaste de la herramienta (fase 2): el desgaste de flanco VB con el tiempo de corte, su efecto en las
## fuerzas (Kver del Tabellenbuch) y en la rugosidad, y el fin de vida de ISO 3685 (VB_B = 0,3 mm). Lo usan el torno,
## la fresadora y el taladro; las fórmulas, fuentes y estimaciones están en docs/taller/pulido-taller.md.
##
## Modelo:
##   1. Vida T (min): Taylor, vc·T^n = C, con n del TZ (p. 215) y C de tool_materials.gd (Cutting.taylor_life,
##      ToolMaterials.taylor_params: estimación). T es el tiempo de corte hasta VB_B = 0,3 mm, el criterio de fin de
##      vida «más usado» de ISO 3685:1993 para metal duro (también VB_Bmax = 0,6 mm si el desgaste es irregular).
##   2. Forma de VB(t): la curva medida por Equeter et al. (2020) al tornear en seco AISI 1045 con metal duro recubierto
##      (fig. 8, digitalizada y hecha monótona: el desgaste no retrocede; las dos bajadas de la figura son dispersión de
##      medida). El tiempo se escala con la vida: τ = t/T, y la curva cruza 0,3 mm en τ = 1. Con otros materiales,
##      herramientas y velocidades se supone la misma forma (estimación): rodaje rápido, tramo estable y desgaste
##      acelerado, la evolución de siempre (Equeter et al. 2020, fig. 3, de Altintas 2012). Más allá de la curva medida
##      no se extrapola: VB se queda en su último valor (0,684 mm).
##   3. Condiciones variables (G96, cambios de vc): fracción de vida consumida D = Σ Δt/T(vc) (acumulación lineal:
##      estimación) y VB = curva(D).
##   4. Fuerzas: Kver del TZ, 1,2 a 1,5 (p. 208), repartido sobre su VB admisible, 0,2 a 0,8 mm (p. 214): Kver = 1 + VB
##      hasta 0,2 mm y 1,2 + 0,5·(VB − 0,2) hasta 0,8 mm (estimación: el TZ no une Kver con VB). Es un factor de diseño,
##      conservador: en el caso medido de Equeter (2019) Fc solo subió un 9 % de VB 0,075 a 0,684 mm, así que la banda
##      baja es 1 + 0,149·VB. Ff subió un 40 % y Fp un 10 % (factores medidos de un solo ensayo: estimación).
##   5. Rugosidad: Ra/Ra(filo nuevo) = 1 + (2,674/2,716)·VB, la recta de Ra frente a VB de la fig. 10 de Equeter et al.
##      (2020) (r = 0,95, el mismo coeficiente que publican). Se aplica a la Ra teórica del filo nuevo.
## Funciones puras, sin estado estático: seguras entre hilos (CONTRATOS.md → «Rendimiento y multinúcleo»).
## Unidades: VB en mm, vida en min, pasos de tiempo en s, vc en m/min, Ra en µm.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")

const SRC_ISO3685 := (
	"ISO 3685:1993, Tool-life testing with single-point turning tools: VB_B = 0,3 mm (desgaste regular) o VB_Bmax = "
	+ "0,6 mm (irregular), los criterios de fin de vida «más usados» para metal duro (citado por Equeter et al. 2020)"
)
const SRC_EQUETER_2020 := (
	"Equeter L., Devlamincq R., Ducobu F., Dutoit C., Dehombreux P. (2020), «Use of Longitudinal Roughness "
	+ "Measurements as Tool End-of-Life Indicator in AISI 1045 Dry Longitudinal Turning», Materials Science Forum "
	+ "986:93-101, doi:10.4028/www.scientific.net/MSF.986.93: AISI 1045 recocido (154 HV30), Seco CNMG120408-MF5 TP2500 "
	+ "(P10 recubierto), vc 365 m/min, f 0,4 mm, ap 0,7 mm, en seco; VB_B = 0,3 mm a los 25,35 min (figs. 8 y 10)"
)
const SRC_EQUETER_2019 := (
	"Equeter L. (2019), «Cutting Inserts Wear Monitoring in AISI 1045 Dry Longitudinal Turning through Cutting Forces: "
	+ "a Case Study», ASM MS&T 2019, Portland (diapositivas, UMONS ORBi): con el mismo ensayo, Fc +9 %, Ff +40 % y "
	+ "Fr +10 % del primer al último pase (RMS de cada pase)"
)
const SRC_TZ_KVER := (
	"Tabellenbuch Zerspantechnik (2015), p. 208: Kver = 1,2 bis 1,5 (el ejemplo usa 1,2 con «geringer Verschleiß»); "
	+ "p. 214: VBzul = 0,2 bis 0,8 mm; p. 215: recta de vida «z. B. für VB = 0,4 mm»"
)

## Fin de vida (ISO 3685:1993)
const VB_END_MM := 0.3
const VB_END_MAX_MM := 0.6
## Holgura de coma flotante al comparar con los umbrales (1 nm): en τ = 1 la curva da 0,29999999999999993 mm
const VB_EPS_MM := 1e-9
## VB admisible y Kver del TZ (pp. 214 y 208)
const VB_ALLOWED_TZ := [0.2, 0.8]
const KVER_TZ := [1.2, 1.5]
## Curva publicada (Equeter et al. 2020, fig. 8): tiempo de corte (min) y VB_B (mm), digitalizada a mano (±0,01 mm) y
## hecha monótona (media de los puntos que bajaban: 0,186/0,179 → 0,1825 y 0,200/0,192 → 0,196). Empieza en (0, 0).
const CURVE_T_MIN := [
	0.0, 0.95, 1.95, 2.81, 4.18, 5.01, 7.02, 8.94, 10.89, 12.89, 14.87, 16.85, 18.71, 20.63, 22.58, 24.53, 25.59,
	26.50, 27.48, 28.42, 29.37, 30.34,
]
const CURVE_VB_MM := [
	0.0, 0.075, 0.085, 0.100, 0.106, 0.121, 0.130, 0.139, 0.166, 0.1825, 0.1825, 0.196, 0.196, 0.201, 0.210, 0.252,
	0.312, 0.319, 0.425, 0.467, 0.635, 0.684,
]
## Tiempo en el que la curva digitalizada cruza VB = 0,3 mm (el texto del artículo dice 25,35 min)
const CURVE_T_END_MIN := 25.378
## Fin del rodaje (5,01 min) y del tramo estable (22,58 min), en fracción de vida
const STAGE_RUN_IN_END := 0.197
const STAGE_STEADY_END := 0.890
## Caso medido (Equeter 2019): F(VB) = F(0)·(1 + s·VB), con s tal que F(0,684)/F(0,075) (primer y último pase) sea el
## publicado: Fc 1,09, Ff 1,40 y Fp 1,10.
const FC_MEASURED_PER_MM := 0.149
const FF_MEASURED_PER_MM := 0.691
const FP_MEASURED_PER_MM := 0.166
## Recta de Ra frente a VB (Equeter et al. 2020, fig. 10, 16 puntos digitalizados; r = 0,95): Ra = 2,716 + 2,674·VB µm
const RA_FIT_A_UM := 2.716
const RA_FIT_B_UM_PER_MM := 2.674


# ─────────────────────────────── Vida ───────────────────────────────

## Vida de Taylor (min hasta VB_B = 0,3 mm) de una herramienta en un material a vc (m/min):
## { life_min (INF si vc ≤ 0, null si no hay datos), n, C, quality, source, reason }.
static func life(tool_id: String, work_id: String, vc: float) -> Dictionary:
	var out := { "life_min": null, "n": null, "C": null, "quality": "estimate", "source": "", "reason": "" }
	var tool := ToolMaterials.get_tool(tool_id)
	var work := WorkMaterials.get_material(work_id)
	if tool.is_empty() or work.is_empty():
		out["reason"] = "Material o herramienta desconocidos."
		return out
	if work["kc"] == null:
		out["reason"] = "Sin modelo de corte para %s: no se calcula su desgaste." % work["name"]
		return out
	var tp := ToolMaterials.taylor_params(tool, work["iso"])
	if tp.is_empty():
		out["reason"] = "Sin datos de vida de %s en el grupo ISO %s." % [tool["name"], work["iso"]]
		return out
	out["n"] = tp["n"]
	out["C"] = tp["C"]
	out["source"] = tp["source"]
	out["life_min"] = Cutting.taylor_life(vc, tp["n"], tp["C"]) if vc > 0.0 else INF
	return out


# ─────────────────────────────── Curva VB(τ) ───────────────────────────────

## VB_B (mm) cuando se ha consumido la fracción τ de la vida (τ = 1 → 0,3 mm). Más allá de la curva medida (τ ≈ 1,2) no
## se extrapola: VB se queda en el último valor medido, 0,684 mm (la herramienta está muerta desde τ = 1 y, en la
## realidad, acabaría rompiéndose; eso no se modela).
static func vb_at_fraction(tau: float) -> float:
	if tau <= 0.0:
		return 0.0
	var t := tau * CURVE_T_END_MIN
	var n := CURVE_T_MIN.size()
	for i in range(1, n):
		if t <= float(CURVE_T_MIN[i]):
			return _lerp_seg(t, i - 1, i)
	return float(CURVE_VB_MM[n - 1])


## Fracción de vida (τ) en la que la curva llega por primera vez a vb (mm). 0 si vb ≤ 0; INF por encima del último
## valor medido (0,684 mm), al que el modelo no llega.
static func fraction_at_vb(vb: float) -> float:
	if vb <= 0.0:
		return 0.0
	var n := CURVE_VB_MM.size()
	for i in range(1, n):
		var v1 := float(CURVE_VB_MM[i])
		if vb <= v1:
			var v0 := float(CURVE_VB_MM[i - 1])
			var t0 := float(CURVE_T_MIN[i - 1])
			var t1 := float(CURVE_T_MIN[i])
			var t := t0 + (vb - v0) / (v1 - v0) * (t1 - t0) if v1 > v0 else t0
			return t / CURVE_T_END_MIN
	return INF


## Etapa del desgaste para una fracción de vida: "rodaje" (desgaste inicial rápido), "estable" o "acelerado".
static func stage(tau: float) -> String:
	if tau < STAGE_RUN_IN_END:
		return "rodaje"
	if tau < STAGE_STEADY_END:
		return "estable"
	return "acelerado"


static func _lerp_seg(t: float, i0: int, i1: int) -> float:
	var t0 := float(CURVE_T_MIN[i0])
	var t1 := float(CURVE_T_MIN[i1])
	var v0 := float(CURVE_VB_MM[i0])
	var v1 := float(CURVE_VB_MM[i1])
	return v0 + (t - t0) / (t1 - t0) * (v1 - v0)


# ─────────────────────────────── Efectos ───────────────────────────────

## Kver del TZ para un VB (mm): 1 + VB hasta 0,2 mm; 1,2 + 0,5·(VB − 0,2) hasta 0,8 mm; 1,5 por encima.
static func kver_for_vb(vb: float) -> float:
	var v := maxf(vb, 0.0)
	var lo: float = VB_ALLOWED_TZ[0]
	var hi: float = VB_ALLOWED_TZ[1]
	var k0: float = KVER_TZ[0]
	var k1: float = KVER_TZ[1]
	if v <= lo:
		return 1.0 + (k0 - 1.0) * v / lo
	if v <= hi:
		return k0 + (k1 - k0) * (v - lo) / (hi - lo)
	return k1


## Factor de la rugosidad por el desgaste: Ra(VB)/Ra(filo nuevo) = 1 + (2,674/2,716)·VB.
static func ra_factor_for_vb(vb: float) -> float:
	return 1.0 + RA_FIT_B_UM_PER_MM / RA_FIT_A_UM * maxf(vb, 0.0)


## Lo que cambia en el corte con un desgaste VB (mm):
## { vb_mm, kver (TZ, el que se pasa a Cutting como `wear`), kver_band [caso medido, TZ], ff_factor, fp_factor,
##   ra_factor, end_of_life (VB ≥ 0,3), end_of_life_max (VB ≥ 0,6), quality, sources }.
static func effects(vb: float) -> Dictionary:
	var v := maxf(vb, 0.0)
	var k := kver_for_vb(v)
	return {
		"vb_mm": v,
		"kver": k,
		"kver_band": [minf(1.0 + FC_MEASURED_PER_MM * v, k), k],
		"ff_factor": 1.0 + FF_MEASURED_PER_MM * v,
		"fp_factor": 1.0 + FP_MEASURED_PER_MM * v,
		"ra_factor": ra_factor_for_vb(v),
		"end_of_life": v >= VB_END_MM - VB_EPS_MM,
		"end_of_life_max": v >= VB_END_MAX_MM - VB_EPS_MM,
		"quality": "estimate",
		"sources": [SRC_TZ_KVER, SRC_EQUETER_2019, SRC_EQUETER_2020, SRC_ISO3685],
	}


# ─────────────────────────────── Estado paso a paso ───────────────────────────────

## Filo nuevo: { used (fracción de vida consumida), cut_s (segundos cortando), vb_mm, stage, end_of_life }.
static func new_state() -> Dictionary:
	return { "used": 0.0, "cut_s": 0.0, "vb_mm": 0.0, "stage": "rodaje", "end_of_life": false }


## Un paso de dt_s segundos cortando a vc (m/min): devuelve un estado nuevo (no toca el que recibe) con
## { used, cut_s, vb_mm, stage, end_of_life, life_min (vida a esta vc), remaining_min (hasta VB 0,3 a esta vc; 0 si ya
##   pasó), kver, ra_factor, quality, warnings }. Sin giro o sin corte (vc ≤ 0 o dt ≤ 0) no se gasta. Sin datos de vida
## la herramienta no se gasta y se avisa. D = Σ Δt/T(vc): acumulación lineal (estimación).
static func step(state: Dictionary, dt_s: float, vc: float, tool_id: String, work_id: String) -> Dictionary:
	var used := float(state.get("used", 0.0))
	var cut_s := float(state.get("cut_s", 0.0))
	var warnings: Array[String] = []
	var lf := life(tool_id, work_id, vc)
	var life_min: Variant = lf["life_min"]
	if dt_s > 0.0 and vc > 0.0:
		cut_s += dt_s
		if life_min == null:
			warnings.append(String(lf["reason"]))
		elif is_finite(float(life_min)) and float(life_min) > 0.0:
			used += dt_s / 60.0 / float(life_min)
	var vb := vb_at_fraction(used)
	var remaining: Variant = null
	if life_min != null:
		remaining = maxf(1.0 - used, 0.0) * float(life_min) if is_finite(float(life_min)) else INF
	var dead := vb >= VB_END_MM - VB_EPS_MM
	if dead:
		warnings.append("Fin de vida: el desgaste de flanco llega a VB = %s mm (criterio de ISO 3685: 0,3 mm). Hay que girar o cambiar la plaquita." % [Js.to_fixed(vb, 2)])
	elif stage(used) == "acelerado":
		warnings.append("Desgaste acelerado (VB = %s mm): queda poco para el fin de vida." % [Js.to_fixed(vb, 2)])
	return {
		"used": used, "cut_s": cut_s, "vb_mm": vb, "stage": stage(used), "end_of_life": dead,
		"life_min": life_min, "remaining_min": remaining, "kver": kver_for_vb(vb), "ra_factor": ra_factor_for_vb(vb),
		"quality": "estimate", "warnings": warnings,
	}


## Estado tras t_min minutos de corte a vc constante (m/min).
static func after(t_min: float, vc: float, tool_id: String, work_id: String) -> Dictionary:
	return step(new_state(), t_min * 60.0, vc, tool_id, work_id)


## Minutos de corte a vc constante hasta llegar a un VB (mm); null si no hay datos de vida.
static func minutes_to_vb(vb: float, vc: float, tool_id: String, work_id: String) -> Variant:
	var lf := life(tool_id, work_id, vc)
	if lf["life_min"] == null:
		return null
	return fraction_at_vb(vb) * float(lf["life_min"])
